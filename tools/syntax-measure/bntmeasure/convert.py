# -*- coding: utf-8 -*-
"""基準の構文（V00）で書いたコードを、各案の構文に書き換える。

参照の文書（variants/<ID>/reference.md）は、V00 で書いた一つの雛形から作る。雛形のコードの例を
この変換で各案の構文にし、変換した例が案の検査を通ることを selftest で確かめる。

変換は字句の並びの上で行う。V00 の字句の並びから、ブロックの開きと閉じ、分岐の区切り、束縛の `=` などの
役割を調べ（analyze）、案ごとに「ソースの範囲をこの文字列に置き換える」編集の並びを作って当てる。
複数の案を合わせた案（V15）は、各案の編集を合わせて当てる。編集の範囲が重なれば誤りとする。
"""
from collections import defaultdict

from . import variants as V
from .scope import decide_lets
from .variants import E

BLOCK_OPEN = ('lambda', 'if', 'case', 'with', 'lazy', 'handle')


class ConvertError(Exception):
    pass


class Analysis:
    def __init__(self, src):
        self.src = src
        self.t = E.lex(src, E.BASELINE)
        self.n = len(self.t)
        self.fn_colon = set()        # 関数の宣言・シグネチャ・ラムダの戻り値の型の前の `:`
        self.body_open = set()       # この字句の後でブロックが始まる（波括弧の案で ` {` を置く）
        self.end_pairs = {}          # `end` の添字 -> 閉じるブロックの種類
        self.then_idx = set()
        self.else_idx = set()
        self.else_if_idx = set()
        self.case_idx = set()
        self.of_idx = set()
        self.arm_when = set()
        self.arm_colon = set()
        self.harm_when = {}          # handle の節の `when` -> 最初の節か
        self.with_do = set()
        self.bind_eq = set()         # 束縛の `=`（let・with・const・型の別名）
        self.let_idx = set()
        self.adt_type = set()
        self.adt_end = set()
        self.test_end = set()
        self.try_extent = {}         # try の添字 -> (式の最初の添字, 最後の添字)
        self.amp = set()
        self.tuple_ctor = set()
        self.tuple_type = {}         # Pair・Triple の添字 -> 対応する `]` の添字
        self.test_attr = {}          # `@` の添字 -> (シグネチャの最後の添字, 説明の文字列)
        self._run()
        self.lets = decide_lets(self.t)

    def tk(self, i):
        if 0 <= i < self.n:
            return self.t[i]
        return E.Token('EOF', '', len(self.src), len(self.src))

    def match(self, i):
        depth = 0
        for j in range(i, self.n):
            x = self.t[j]
            if x.kind == 'sym' and x.text in ('(', '['):
                depth += 1
            elif x.kind == 'sym' and x.text in (')', ']'):
                depth -= 1
                if depth == 0:
                    return j
        raise ConvertError('unbalanced bracket at %d' % i)

    def scan_to(self, i, stops):
        depth = 0
        for k in range(i, self.n):
            x = self.t[k]
            if x.kind == 'sym' and x.text in ('(', '['):
                depth += 1
            elif x.kind == 'sym' and x.text in (')', ']'):
                depth -= 1
            elif depth == 0 and x.text in stops and x.kind in ('sym', 'kw'):
                return k
        raise ConvertError('missing %s after %d' % (stops, i))

    def skip_qual(self, i):
        if self.tk(i).kind != 'UpperIdent':
            raise ConvertError('expected a capitalized name at %d' % i)
        i += 1
        while self.tk(i).text == '.' and self.tk(i + 1).kind == 'UpperIdent':
            i += 2
        return i

    def skip_type(self, i):
        x = self.tk(i)
        if x.kt() == ('kw', 'function'):
            j = self.match(i + 1)
            if self.tk(j + 1).text != '->':
                raise ConvertError('expected -> in a function type')
            e = self.skip_type(j + 2)
            if self.tk(e).kt() == ('kw', 'uses'):
                e = self.skip_uses(e)
            return e
        if x.text == '(':
            return self.match(i) + 1
        i = self.skip_qual(i)
        if self.tk(i).text == '[':
            i = self.match(i) + 1
        return i

    def skip_uses(self, i):
        i = self.skip_qual(i + 1)
        while self.tk(i).text == ',' and self.tk(i + 1).kind == 'UpperIdent':
            i = self.skip_qual(i + 1)
        return i

    def signature(self, close):
        """引数の並びの `)` の後の `: 型 [uses ...]` を読み、`:` の添字とシグネチャの最後の添字を返す。"""
        if self.tk(close + 1).text != ':':
            return None, close
        e = self.skip_type(close + 2)
        if self.tk(e).kt() == ('kw', 'uses'):
            e = self.skip_uses(e)
        return close + 1, e - 1

    def try_end(self, i):
        depth = 0
        k = i
        while k < self.n:
            x = self.t[k]
            if x.kind == 'sym' and x.text in ('(', '['):
                depth += 1
            elif x.kind == 'sym' and x.text in (')', ']'):
                if depth == 0:
                    break
                depth -= 1
            elif x.kind == 'kw' and x.text in BLOCK_OPEN and self.tk(k - 1).kt() != ('kw', 'end'):
                if not (x.text == 'if' and self.tk(k - 1).kt() == ('kw', 'else')):
                    depth += 1
            elif x.kt() == ('kw', 'end'):
                if depth == 0:
                    break
                depth -= 1
                k += 2
                continue
            elif depth == 0 and (x.kind == 'NL' or x.text == ',' or (x.kind == 'kw' and x.text in ('of', 'then', 'do', 'else', 'when'))):
                break
            k += 1
        return k - 1

    def _run(self):
        t = self.t
        frames = []
        pending_test = None
        guard_until = -1
        i = 0
        while i < self.n:
            x = t[i]
            kt = x.kt()
            prev = self.tk(i - 1)
            top = frames[-1][0] if frames else None
            if kt == ('kw', 'end'):
                name = self.tk(i + 1).text
                while frames and frames[-1][0] in ('arm', 'harm'):
                    frames.pop()
                if not frames or frames[-1][0] != name:
                    raise ConvertError('unmatched end %s' % name)
                f = frames.pop()
                self.end_pairs[i] = name
                if name == 'type':
                    self.adt_end.add(i)
                if name == 'function' and f[1]:
                    self.test_end.add(i)
                i += 2
                continue
            sig_only = top in ('trait', 'effect')
            if kt == ('kw', 'function') and self.tk(i + 1).kind == 'LowerIdent':
                k = i + 2
                if self.tk(k).text == '[':
                    k = self.match(k) + 1
                j = self.match(k)
                colon, last = self.signature(j)
                if colon is None:
                    raise ConvertError('function without a return type')
                self.fn_colon.add(colon)
                if not sig_only:
                    self.body_open.add(last)
                    frames.append(['function', pending_test])
                    if pending_test is not None:
                        at, desc = pending_test
                        self.test_attr[at] = (last, desc or '"%s"' % self.tk(i + 1).text)
                    pending_test = None
                i += 1  # シグネチャの中の字句（制約の &、Pair の型など）も調べる
                continue
            if kt == ('kw', 'type') and self.tk(i + 1).kind == 'UpperIdent':
                h = i + 2
                if self.tk(h).text == '[':
                    h = self.match(h) + 1
                if self.tk(h).text == '=':
                    self.bind_eq.add(h)
                else:
                    self.adt_type.add(i)
                    self.body_open.add(h - 1)
                    frames.append(['type', None])
                i = h
                continue
            if kt == ('kw', 'record'):
                h = i + 2
                if self.tk(h).text == '[':
                    h = self.match(h) + 1
                self.body_open.add(h - 1)
                frames.append(['record', None])
                i = h
                continue
            if kt == ('kw', 'trait'):
                h = self.match(i + 2) + 1
                self.body_open.add(h - 1)
                frames.append(['trait', None])
                i += 1
                continue
            if kt == ('kw', 'effect') and (prev.kind in ('NL', 'EOF') or prev.text == 'public'):
                self.body_open.add(i + 1)
                frames.append(['effect', None])
                i += 2
                continue
            if kt == ('kw', 'implement'):
                k = i + 1
                if self.tk(k).text == '[':
                    k = self.match(k) + 1
                k = self.skip_qual(k)
                k = self.match(k) + 1
                self.body_open.add(k - 1)
                frames.append(['implement', None])
                i += 1
                continue
            if kt == ('kw', 'const'):
                self.bind_eq.add(self.scan_to(i + 1, ('=',)))
            elif kt == ('kw', 'lambda'):
                j = self.match(i + 1)
                colon, last = self.signature(j)
                if colon is not None:
                    self.fn_colon.add(colon)
                self.body_open.add(last)
                frames.append(['lambda', None])
                i += 1
                continue
            elif kt == ('kw', 'if'):
                if i < guard_until:
                    pass  # 分岐のガード
                elif prev.kt() != ('kw', 'else'):
                    frames.append(['if', None])
            elif kt == ('kw', 'then'):
                self.then_idx.add(i)
            elif kt == ('kw', 'else'):
                if self.tk(i + 1).kt() == ('kw', 'if'):
                    self.else_if_idx.add(i)
                else:
                    self.else_idx.add(i)
            elif kt == ('kw', 'case'):
                frames.append(['case', None])
                self.case_idx.add(i)
            elif kt == ('kw', 'of'):
                self.of_idx.add(i)
            elif kt == ('kw', 'when') and top in ('case', 'arm'):
                if top == 'arm':
                    frames.pop()
                colon = self.scan_to(i + 1, (':',))
                self.arm_when.add(i)
                self.arm_colon.add(colon)
                guard_until = colon
                frames.append(['arm', None])
            elif kt == ('kw', 'when') and top in ('handle', 'harm'):
                self.harm_when[i] = top == 'handle'
                if top == 'harm':
                    frames.pop()
                frames.append(['harm', None])
            elif kt == ('kw', 'handle'):
                frames.append(['handle', None])
                self.body_open.add(i)
            elif kt == ('kw', 'with'):
                frames.append(['with', None])
                d = self.scan_to(i + 1, ('do',))
                for k in range(i + 1, d):
                    if t[k].kind == 'LowerIdent' and t[k - 1].text in ('with', ',') and t[k + 1].text == '=':
                        self.bind_eq.add(k + 1)
            elif kt == ('kw', 'do'):
                self.with_do.add(i)
            elif kt == ('kw', 'lazy'):
                frames.append(['lazy', None])
                self.body_open.add(i)
            elif kt == ('kw', 'let'):
                self.let_idx.add(i)
                self.bind_eq.add(self.scan_to(i + 1, ('=',)))
            elif kt == ('kw', 'try'):
                self.try_extent[i] = (i + 1, self.try_end(i + 1))
            elif kt == ('sym', '&'):
                self.amp.add(i)
            elif x.kind == 'UpperIdent' and x.text in ('Pair', 'Triple') and prev.text != '.':
                if self.tk(i + 1).text == '(':
                    self.tuple_ctor.add(i)
                elif self.tk(i + 1).text == '[':
                    self.tuple_type[i] = self.match(i + 1)
            elif kt == ('sym', '@') and self.tk(i + 1).text == 'test':
                desc = None
                if self.tk(i + 2).text == '(':
                    s = self.tk(i + 3)
                    desc = self.src[s.start:s.end]
                pending_test = (i, desc)
            i += 1
        if frames:
            raise ConvertError('unclosed blocks: %s' % [f[0] for f in frames])


def _line_indent(src, offset):
    ls = src.rfind('\n', 0, offset) + 1
    k = ls
    while k < len(src) and src[k] in ' \t':
        k += 1
    return src[ls:k]


def _after_spaces(src, offset):
    while offset < len(src) and src[offset] == ' ':
        offset += 1
    return offset


def edits_for(a, feature):
    """機能ごとの編集の並び [(開始, 終わり, 置き換える文字列)]。"""
    t = a.t
    src = a.src
    ed = []

    def rep(i, text):
        ed.append((t[i].start, t[i].end, text))

    def rep_end(i, text):
        ed.append((t[i].start, t[i + 1].end, text))

    if feature == 'braces':
        for i in a.body_open:
            ed.append((t[i].end, t[i].end, ' {'))
        for i in a.end_pairs:
            rep_end(i, '}')
        for i in a.then_idx:
            rep(i, '{')
        for i in a.else_idx:
            rep(i, '} else {')
        for i in a.else_if_idx:
            rep(i, '} else')
        for i in a.case_idx:
            rep(i, 'switch')
        for i in a.of_idx:
            rep(i, '{')
        for i in a.arm_when:
            rep(i, 'case')
        for i, first in a.harm_when.items():
            rep(i, '} with {\n%scase' % _line_indent(src, t[i].start) if first else 'case')
        for i in a.with_do:
            rep(i, '{')
    elif feature == 'abbrev_kw':
        names = {'function': 'fn', 'public': 'pub', 'implement': 'impl'}
        for i, x in enumerate(t):
            if x.kind == 'kw' and x.text in names:
                rep(i, names[x.text])
    elif feature == 'arrow_return':
        for i in a.fn_colon:
            rep(i, ' ->')
    elif feature == 'bind_shadow':
        for i in a.let_idx:
            rep(i, a.lets[i])
            j = a.scan_to(i + 1, ('=',))
            rep(j, '<-')
    elif feature == 'data_decl':
        for i in a.adt_type:
            rep(i, 'data')
        for i in a.adt_end:
            rep(i + 1, 'data')
    elif feature == 'match_with':
        for i in a.case_idx:
            rep(i, 'match')
        for i in a.of_idx:
            rep(i, 'with')
        for i in a.arm_when:
            rep(i, 'case')
        for i in a.arm_colon:
            rep(i, ' ->')
        for i, name in a.end_pairs.items():
            if name == 'case':
                rep(i + 1, 'match')
    elif feature == 'postfix_try':
        for i, (s, e) in a.try_extent.items():
            simple = t[s].kind in ('LowerIdent', 'UpperIdent')
            k = s + 1
            while simple and k <= e:
                if t[k].text == '.' and t[k + 1].kind in ('LowerIdent', 'UpperIdent'):
                    k += 2
                elif t[k].text == '(':
                    k = a.match(k) + 1
                else:
                    simple = False
            if simple:
                ed.append((t[i].start, _after_spaces(src, t[i].end), ''))
                ed.append((t[e].end, t[e].end, '?'))
            else:
                ed.append((t[i].start, _after_spaces(src, t[i].end), '('))
                ed.append((t[e].end, t[e].end, ')?'))
    elif feature == 'plus_constraints':
        for i in a.amp:
            rep(i, '+')
    elif feature == 'tuples':
        for i in a.tuple_ctor:
            ed.append((t[i].start, t[i].end, ''))
        for i, j in a.tuple_type.items():
            ed.append((t[i].start, t[i + 1].end, '('))
            rep(j, ')')
    elif feature == 'c_ops':
        for i, x in enumerate(t):
            if x.kt() == ('sym', '=') and i not in a.bind_eq:
                rep(i, '==')
            elif x.kt() == ('sym', '<>'):
                rep(i, '!=')
            elif x.kt() == ('kw', 'and'):
                rep(i, '&&')
            elif x.kt() == ('kw', 'or'):
                rep(i, '||')
            elif x.kt() == ('kw', 'not'):
                ed.append((x.start, _after_spaces(src, x.end), '!'))
    elif feature == 'c_div':
        for i, x in enumerate(t):
            if x.kt() == ('kw', 'div'):
                rep(i, '/')
            elif x.kt() == ('kw', 'mod'):
                rep(i, '%')
    elif feature == 'test_blocks':
        for at, (last, desc) in a.test_attr.items():
            ed.append((t[at].start, t[last].end, 'test %s' % desc))
        for i in a.test_end:
            rep(i + 1, 'test')
    elif feature in ('reserve_abbrev', 'reserve_absent'):
        pass
    else:
        raise ConvertError('unknown feature %s' % feature)
    return ed


def apply_edits(src, edits):
    edits = sorted(edits, key=lambda e: (e[0], e[1]))
    out = []
    pos = 0
    last_end = -1
    for s, e, text in edits:
        if s < last_end:
            raise ConvertError('overlapping edits at %d' % s)
        out.append(src[pos:s])
        out.append(text)
        pos = e
        last_end = e
    out.append(src[pos:])
    return ''.join(out)


def convert(src, vid):
    """V00 の src を案 vid の構文に書き換える。"""
    v = V.get(vid)
    if not v.features:
        return src
    a = Analysis(src)
    edits = []
    for f in sorted(v.features):
        edits += edits_for(a, f)
    return apply_edits(src, edits)
