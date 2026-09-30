# -*- coding: utf-8 -*-
"""局所束縛の有効範囲を字句の並びで辿る。

二つの用途がある。
- check_scopes: V06・V15 の検査。`bind x <- e` は、有効範囲にまだない名前を束縛しなければならず、
  `shadow x <- e` は、外側の有効範囲（関数とラムダの引数、パターンの変数、同じか外側のブロックの
  それまでの束縛）にある名前を束縛し直さなければならない。パターンを書いたときは、パターンの
  すべての変数にこの規則を当てる（bind のパターンは新しい名前だけ、shadow のパターンは既にある名前だけ）。
  トップレベルの関数と定数の名前は局所束縛ではないので数えない。
- decide_lets: 基準の構文（V00）の `let` を、bind と shadow のどちらに書き換えるかを決める（convert.py）。

照合を通った字句の並びだけを入力にするので、構造の誤りは考えない。
"""


class ScopeError(Exception):
    def __init__(self, message, token, category):
        Exception.__init__(self, message)
        self.message = message
        self.token = token
        self.category = category


class Style:
    """案の書き方のうち、有効範囲を辿るのに要る語。"""

    def __init__(self, fn='function', let_kws=('let',), let_eq='=', case_kw='case', arm_kw='when', arm_end=':'):
        self.fn = fn
        self.let_kws = let_kws
        self.let_eq = let_eq
        self.case_kw = case_kw
        self.arm_kw = arm_kw
        self.arm_end = arm_end


def style_of(v):
    m = 'match_with' in v.features
    return Style(fn=v.kw('function'), let_kws=('bind', 'shadow'), let_eq='<-', case_kw='match' if m else 'case',
                 arm_kw='case' if m else 'when', arm_end='->' if m else ':')


BASE_STYLE = Style()


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
    """toks[i] から、深さ 0 で stops のどれかの字句が現れる位置を探す。"""
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


class Walker:
    def __init__(self, toks, style, mode):
        self.t = toks
        self.s = style
        self.mode = mode  # 'check' か 'decide'
        self.frames = []  # [kind, names(set), closer]
        self.decisions = {}

    def visible(self):
        out = set()
        for f in self.frames:
            out |= f[1]
        return out

    def decl_level(self):
        return all(f[0] == 'implement' for f in self.frames)

    def pop_to(self, closer):
        if not any(f[2] == closer for f in self.frames):
            return
        while self.frames:
            f = self.frames.pop()
            if f[2] == closer:
                return

    def run(self):
        t = self.t
        s = self.s
        i = 0
        n = len(t)
        pending_with = []
        while i < n:
            tok = t[i]
            kt = (tok.kind, tok.text)
            prev = t[i - 1] if i > 0 else None
            if kt == ('kw', 'end') and i + 1 < n:
                self.pop_to(t[i + 1].text)
                i += 2
                continue
            if tok.kind == 'kw' and tok.text in ('trait', 'effect') and self.decl_level() and (
                    prev is None or prev.kind == 'NL' or prev.text in ('public', 'pub')):
                # 型クラスとエフェクトの宣言は本体を持たないシグネチャだけを並べる
                while i < n and not (t[i].kt() == ('kw', 'end') and i + 1 < n and t[i + 1].text == tok.text):
                    i += 1
                i += 2
                continue
            if kt == ('kw', 'implement') or kt == ('kw', 'impl'):
                self.frames.append(['implement', set(), tok.text])
            elif kt == ('kw', s.fn) and i + 1 < n and t[i + 1].kind == 'LowerIdent' and self.decl_level():
                k = i + 2
                if k < n and t[k].text == '[':
                    k = _match(t, k) + 1
                j = _match(t, k)
                self.frames.append(['function', {p.text for p in _params(t, k, j)}, s.fn])
                i = j + 1
                continue
            elif kt == ('kw', 'lambda'):
                j = _match(t, i + 1)
                self.frames.append(['lambda', {p.text for p in _params(t, i + 1, j)}, 'lambda'])
                i = j + 1
                continue
            elif kt == ('kw', 'if'):
                in_header = self.frames and self.frames[-1][0] == 'armhead'
                if not in_header and not (prev is not None and prev.kt() == ('kw', 'else')):
                    self.frames.append(['if', set(), 'if'])
            elif tok.kind == 'kw' and tok.text in ('then', 'else') and self.frames and self.frames[-1][0] == 'if':
                self.frames[-1][1] = set()  # 分岐ごとに新しい有効範囲
            elif kt == ('kw', s.case_kw):
                self.frames.append(['case', set(), s.case_kw])
                if s.case_kw == 'match':
                    # match e with の with は、リソーススコープの with ではない
                    i = _scan_to(t, i + 1, ('with',)) + 1
                    continue
            elif kt == ('kw', s.arm_kw) and self.frames and self.frames[-1][0] in ('case', 'arm'):
                if self.frames[-1][0] == 'arm':
                    self.frames.pop()
                j = _scan_to(t, i + 1, (s.arm_end,))
                g = _scan_to(t, i + 1, ('if',))
                names = {p.text for p in pattern_vars(t, i + 1, min(g, j))}
                self.frames.append(['arm', names, None])
                i = j + 1
                continue
            elif kt == ('kw', 'handle'):
                self.frames.append(['handle', set(), 'handle'])
            elif kt == ('kw', 'when') and self.frames and self.frames[-1][0] in ('handle', 'harm'):
                if self.frames[-1][0] == 'harm':
                    self.frames.pop()
                j = _scan_to(t, i + 1, (':',))
                names = {t[k].text for k in range(i + 1, j) if t[k].kind == 'LowerIdent' and t[k - 1].text in ('(', ',')}
                self.frames.append(['harm', names, None])
                i = j + 1
                continue
            elif kt == ('kw', 'with'):
                j = _scan_to(t, i + 1, ('do',))
                names = set()
                for k in range(i + 1, j):
                    if t[k].kind == 'LowerIdent' and t[k - 1].text in ('with', ',') and t[k + 1].text == '=':
                        names.add(t[k].text)
                pending_with.append(names)
                self.frames.append(['withhead', set(), None])
            elif kt == ('kw', 'do') and self.frames and self.frames[-1][0] == 'withhead':
                self.frames.pop()
                self.frames.append(['with', pending_with.pop(), 'with'])
            elif kt == ('kw', 'lazy'):
                self.frames.append(['lazy', set(), 'lazy'])
            elif tok.kind == 'kw' and tok.text in s.let_kws:
                j = _scan_to(t, i + 1, (s.let_eq, ':'))
                vars_ = pattern_vars(t, i + 1, j)
                vis = self.visible()
                if self.mode == 'decide':
                    bound = [x for x in vars_ if x.text in vis]
                    if bound and len(bound) != len(vars_):
                        raise ScopeError('a pattern mixes new and existing names', tok, 'mixed-pattern')
                    self.decisions[i] = 'shadow' if bound else 'bind'
                elif tok.text == 'bind':
                    for x in vars_:
                        if x.text in vis:
                            raise ScopeError('`%s` is already bound; write `shadow %s <- ...` to bind the name '
                                             'again' % (x.text, x.text), x, 'bind-rebound')
                else:
                    for x in vars_:
                        if x.text not in vis:
                            raise ScopeError('`%s` is not bound yet; write `bind %s <- ...` for the first binding '
                                             'of a name' % (x.text, x.text), x, 'shadow-unbound')
                if self.frames:
                    self.frames[-1][1] |= {x.text for x in vars_}
                else:
                    self.frames.append(['block', {x.text for x in vars_}, None])
            i += 1
        return self.decisions


def check_scopes(toks, v):
    Walker(toks, style_of(v), 'check').run()


def decide_lets(toks):
    """V00 の字句の並びの各 let の添字 -> 'bind' か 'shadow'。"""
    return Walker(toks, BASE_STYLE, 'decide').run()
