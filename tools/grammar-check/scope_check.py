# -*- coding: utf-8 -*-
"""局所の束縛の規則（設計書 01-03「シャドーイング」、ADR 0255）を、字句の並びを辿って確かめる。

文法の照合を通った例だけを入力にするので、構造の誤りは考えない。確かめる規則は次のとおりである。

- `bind` の左辺の変数は、その位置で局所の名前として見えていてはならない。
- `shadow` の左辺の変数は、局所の名前として見えていなければならない。変数を一つも束縛しない
  パターン（`_` やリテラル）は `shadow` で書けない。
- 左辺のパターンの変数は、すべて新しい名前か、すべて見えている局所の名前でなければならない。
- ラムダの引数、`match` と `handle` の節の変数、`with` の束縛は、見えている局所の名前を隠してはならない。
- `match` の分岐のパターンの変数に、トップレベルの定数と同じ名前を付けてはならない（ADR 0123）。

局所の名前は、関数とラムダの引数、先の `bind`・`shadow`、パターンの変数、`with` の束縛である。
トップレベルの関数と定数は数えない。`if` の分岐、`match` の分岐、`handle` の節は、それぞれ新しい有効範囲である。
`bind`・`shadow` の束縛は、その文の次の文から見える。

例の断片（文の並び）では、断片の外の束縛が分からないので、`shadow` した名前が断片の中で見えて
いなくても誤りにしない（fragment を真にする）。

tools/syntax-measure/bntmeasure/scope.py（構文の案 V06・V15 の検査）を元に、ADR 0255 の規則に合わせて書いた。
"""


class ScopeError(Exception):
    def __init__(self, message, token, category):
        Exception.__init__(self, message)
        self.message = message
        self.token = token
        self.category = category


def _is(t, kind, text=None):
    return t is not None and t.kind == kind and (text is None or t.text == text)


def _match(toks, i):
    """toks[i] の開き括弧に対応する閉じ括弧の添字。"""
    depth = 0
    for j in range(i, len(toks)):
        t = toks[j]
        if t.kind == 'sym' and t.text in ('(', '['):
            depth += 1
        elif t.kind == 'sym' and t.text in (')', ']'):
            depth -= 1
            if depth == 0:
                return j
    return len(toks) - 1


def _params(toks, i, j):
    """括弧 toks[i]..toks[j] の中の、引数の名前（`(` か `,` の直後の小文字の名前）。"""
    names = []
    depth = 0
    for k in range(i, j + 1):
        t = toks[k]
        if t.kind == 'sym' and t.text in ('(', '['):
            depth += 1
        elif t.kind == 'sym' and t.text in (')', ']'):
            depth -= 1
        elif t.kind == 'LowerIdent' and depth == 1 and toks[k - 1].text in ('(', ','):
            names.append(t)
    return names


def pattern_vars(toks, i, j):
    """toks[i:j] のパターンが束縛する変数の字句。"""
    out = []
    depth = 0
    for k in range(i, j):
        t = toks[k]
        if t.kind == 'sym' and t.text in ('(', '['):
            depth += 1
        elif t.kind == 'sym' and t.text in (')', ']'):
            depth -= 1
        elif t.kind == 'LowerIdent':
            nxt = toks[k + 1] if k + 1 < len(toks) else None
            prv = toks[k - 1] if k > 0 else None
            if prv is not None and prv.text == '.':
                continue
            if nxt is not None and nxt.kind == 'sym' and nxt.text in ('(', '.'):
                continue
            if nxt is not None and nxt.kind == 'sym' and nxt.text == ':' and depth > 0:
                continue  # レコードのパターンのフィールドの名前
            out.append(t)
    return out


def _scan_to(toks, i, stops):
    """toks[i] から、括弧の深さ 0 で stops のどれかの字句が現れる位置を探す。"""
    depth = 0
    for k in range(i, len(toks)):
        t = toks[k]
        if t.kind == 'sym' and t.text in ('(', '['):
            depth += 1
        elif t.kind == 'sym' and t.text in (')', ']'):
            depth -= 1
        elif depth == 0 and t.text in stops and t.kind in ('sym', 'kw'):
            return k
    return len(toks)


def _next_real(toks, i):
    """toks[i] から後の、改行字句でない最初の字句。"""
    for k in range(i, len(toks)):
        if toks[k].kind != 'NL':
            return toks[k]
    return None


class Walker:
    def __init__(self, toks, fragment):
        self.t = toks
        self.fragment = fragment
        # [種類, 名前の集合, 閉じる語]。最も外側は、断片の文を置く有効範囲
        self.frames = [['base', set(), None]]
        self.pending = []  # (有効範囲の深さ, 名前の集合): 文の終わりで有効範囲に加える束縛
        self.consts = set()

    def visible(self):
        out = set()
        for f in self.frames:
            out |= f[1]
        return out

    def decl_level(self):
        return all(f[0] in ('base', 'implement') for f in self.frames)

    def pop_to(self, closer):
        if not any(f[2] == closer for f in self.frames):
            return
        while len(self.frames) > 1:
            f = self.frames.pop()
            if f[2] == closer:
                break
        self.pending = [p for p in self.pending if p[0] <= len(self.frames)]

    def flush(self):
        depth = len(self.frames)
        rest = []
        for d, names in self.pending:
            if d == depth:
                self.frames[-1][1] |= names
            elif d < depth:
                rest.append((d, names))
        self.pending = rest

    def no_hiding(self, names, what, category):
        vis = self.visible()
        for x in names:
            if x.text in vis:
                raise ScopeError('%s `%s` hides a local name that is already visible; choose another name'
                                 % (what, x.text), x, category)

    def run(self):
        t = self.t
        n = len(t)
        # トップレベルの定数の名前（ADR 0123: match の分岐のパターンの変数に使えない）
        for i in range(n - 1):
            if _is(t[i], 'kw', 'const') and _is(t[i + 1], 'LowerIdent'):
                self.consts.add(t[i + 1].text)
        i = 0
        builtin = False
        pending_with = []
        while i < n:
            tok = t[i]
            kt = (tok.kind, tok.text)
            prev = t[i - 1] if i > 0 else None
            if tok.kind == 'NL':
                self.flush()
                i += 1
                continue
            if kt == ('kw', 'end') and i + 1 < n:
                self.flush()
                self.pop_to(t[i + 1].text)
                i += 2
                continue
            if kt == ('sym', '@') and i + 1 < n and t[i + 1].text == 'builtin':
                builtin = True  # 本体のない関数の宣言（01-02「属性」）
            if tok.kind == 'kw' and tok.text in ('trait', 'effect') and self.decl_level() and (
                    prev is None or prev.kind == 'NL' or prev.text == 'public'):
                # 型クラスとエフェクトの宣言は、本体を持たないシグネチャだけを並べる
                while i < n and not (t[i].kt() == ('kw', 'end') and i + 1 < n and t[i + 1].text == tok.text):
                    i += 1
                i += 2
                continue
            if kt == ('kw', 'implement'):
                self.frames.append(['implement', set(), 'implement'])
            elif kt == ('kw', 'function') and i + 1 < n and t[i + 1].kind == 'LowerIdent' and self.decl_level():
                k = i + 2
                if k < n and t[k].text == '[':
                    k = _match(t, k) + 1
                j = _match(t, k)
                if builtin:
                    builtin = False
                    while j < n and t[j].kind != 'NL':
                        j += 1
                    i = j
                    continue
                # 関数の引数は、その関数の最も外側の束縛である
                self.frames.append(['function', {p.text for p in _params(t, k, j)}, 'function'])
                i = j + 1
                continue
            elif kt == ('kw', 'lambda'):
                j = _match(t, i + 1)
                params = _params(t, i + 1, j)
                self.no_hiding(params, 'the lambda parameter', 'lambda-param-hides')
                self.frames.append(['lambda', {p.text for p in params}, 'lambda'])
                i = j + 1
                continue
            elif kt == ('kw', 'if'):
                if not _is(prev, 'kw', 'else'):
                    self.frames.append(['if', set(), 'if'])
            elif tok.kind == 'kw' and tok.text in ('then', 'else') and self.frames[-1][0] == 'if':
                self.flush()
                self.frames[-1][1] = set()  # 分岐ごとに新しい有効範囲
                self.pending = [p for p in self.pending if p[0] < len(self.frames)]
            elif kt == ('kw', 'match'):
                self.frames.append(['match', set(), 'match'])
            elif kt == ('kw', 'handle'):
                self.frames.append(['handle', set(), 'handle'])
            elif kt == ('kw', 'with') and _is(_next_real(t, i + 1), 'kw', 'case'):
                # match・handle の分岐の並びの始まり。handle の本体の束縛は、節からは見えない
                self.flush()
                if self.frames[-1][0] in ('match', 'handle'):
                    self.frames[-1][1] = set()
            elif kt == ('kw', 'case') and self.frames[-1][0] in ('match', 'marm', 'handle', 'harm'):
                self.flush()
                if self.frames[-1][0] in ('marm', 'harm'):
                    self.frames.pop()
                j = _scan_to(t, i + 1, ('->',))
                if self.frames[-1][0] == 'match':
                    g = _scan_to(t, i + 1, ('if',))
                    names = pattern_vars(t, i + 1, min(g, j))
                    for x in names:
                        if x.text in self.consts:
                            raise ScopeError('the pattern variable `%s` has the same name as a constant; compare '
                                             'with a guard instead (`case v if v = %s -> ...`)' % (x.text, x.text),
                                             x, 'pattern-const')
                    self.no_hiding(names, 'the pattern variable', 'pattern-hides')
                    self.frames.append(['marm', {x.text for x in names}, None])
                else:
                    p = _scan_to(t, i + 1, ('(',))
                    names = _params(t, p, _match(t, p)) if p < j else []
                    self.no_hiding(names, 'the handler parameter', 'handler-param-hides')
                    self.frames.append(['harm', {x.text for x in names}, None])
                i = j + 1
                continue
            elif kt == ('kw', 'with'):
                j = _scan_to(t, i + 1, ('do',))
                names = []
                for k in range(i + 1, j):
                    if t[k].kind == 'LowerIdent' and t[k - 1].text in ('with', ',') and t[k + 1].text == '=':
                        names.append(t[k])
                self.no_hiding(names, 'the `with` binding', 'with-hides')
                pending_with.append({x.text for x in names})
                self.frames.append(['withhead', set(), None])
            elif kt == ('kw', 'do') and self.frames[-1][0] == 'withhead':
                self.frames.pop()
                self.frames.append(['with', pending_with.pop(), 'with'])
            elif kt == ('kw', 'lazy'):
                self.frames.append(['lazy', set(), 'lazy'])
            elif tok.kind == 'kw' and tok.text in ('bind', 'shadow'):
                self.flush()
                j = _scan_to(t, i + 1, ('<-', ':'))
                vars_ = pattern_vars(t, i + 1, j)
                vis = self.visible()
                bound = [x for x in vars_ if x.text in vis]
                if tok.text == 'bind':
                    if bound and len(bound) < len(vars_):
                        raise ScopeError('the pattern mixes new names and visible local names (`%s`); split the '
                                         'binding' % bound[0].text, bound[0], 'mixed-pattern')
                    if bound:
                        x = bound[0]
                        raise ScopeError('`%s` is already visible as a local name; write `shadow %s <- ...` to hide '
                                         'it' % (x.text, x.text), x, 'bind-rebound')
                else:
                    if not vars_:
                        raise ScopeError('`shadow` must bind at least one visible local name; write `bind`',
                                         tok, 'shadow-nothing')
                    unbound = [x for x in vars_ if x.text not in vis]
                    if unbound and not self.fragment:
                        x = unbound[0]
                        if bound:
                            raise ScopeError('the pattern mixes new names (`%s`) and visible local names; split the '
                                             'binding' % x.text, x, 'mixed-pattern')
                        raise ScopeError('`%s` is not visible as a local name; write `bind %s <- ...`'
                                         % (x.text, x.text), x, 'shadow-unbound')
                self.pending.append((len(self.frames), {x.text for x in vars_}))
            i += 1


def check_scopes(toks, fragment=False):
    """toks（syntax_engine.lex の出力）の局所の束縛の規則を確かめる。誤りがあれば ScopeError を投げる。"""
    Walker(toks, fragment).run()
