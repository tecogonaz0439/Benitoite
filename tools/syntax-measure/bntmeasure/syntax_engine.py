# -*- coding: utf-8 -*-
"""文法の照合の共通部分（字句解析器、EBNF の読み込み、照合器）。基準の案（V00）の凍結した写し。

tools/grammar-check/syntax_engine.py を、2026-09-29 の構文の変更（ADR 0254〜0257）の前の状態
（コミット c93ebf7 の時点）で写したものである。測定を再現できるように、この道具は設計書の現在の
01-01・01-02 と grammar-check の定数に依存しない。字句の規則は変更前の 01-01「字句構造」に、
文法は変更前の 01-02「初回リリース版の文法の全体」（variants/V00/baseline-syntax.md に写した）に従う。
案ごとに字句の規則を変えられるように、キーワード・記号・改行の規則を LexConfig にまとめる。
この写しの字句解析・照合の処理と BASELINE_* の値を変えない。変えると、記録済みの測定と結果が合わなくなる。
"""
import os
import re

# 01-01「キーワード」と、初回リリース版で加えるキーワード
BASELINE_KEYWORDS = frozenset(
    'and case div do effect else end false function if lambda let not of or return then true try '
    'type uses when lazy with trait implement record import public mod handle resume const'.split())
# 01-01「演算子と区切り記号」。長いものを先に照合する
BASELINE_SYMBOLS = ('..', '|>', '->', '<>', '<=', '>=',
                    '+', '-', '*', '/', '<', '>', '=', ':', ',', '.', '(', ')', '[', ']', '{', '}', '_', '&', '@')
# 01-01「改行による区切り」の規則 2（直前の字句）と規則 3（直後の字句）
BASELINE_RULE2 = frozenset('+ - * / = <> < <= > >= |> -> : , . ( [ &'.split()) | frozenset(
    'and or not div mod case else function if lambda let of return then type uses when do implement '
    'import lazy public record trait try with handle'.split())
BASELINE_RULE3 = frozenset('+ * / = <> < <= > >= and or div mod |> . -> else then of do'.split())
# ブロックを開くキーワード（01-01「改行による区切り」）
BASELINE_BLOCK_KEYWORDS = frozenset('lambda if case with lazy handle'.split())
# 分岐の語と、その分岐を持つブロックと、ガードを終える字句。
# when の後、同じ深さの : までの if はガードであり、ブロックを開かない（01-01、01-02「パターンの拡張」）
BASELINE_ARM_RULES = (('when', 'case', ':'), ('when', 'handle', ':'))

# 変更前の 01-02 の写し（git show c93ebf7:doc/design/01-spec/01-02-syntax.md と同じ内容）
BASELINE_SYNTAX = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'variants', 'V00',
                               'baseline-syntax.md')


class LexConfig:
    """字句解析の規則。案ごとに値を替える。"""

    def __init__(self, keywords=BASELINE_KEYWORDS, symbols=BASELINE_SYMBOLS, rule2=BASELINE_RULE2,
                 rule3=BASELINE_RULE3, block_keywords=BASELINE_BLOCK_KEYWORDS, arm_rules=BASELINE_ARM_RULES,
                 braces=False, symbol_hints=None, member_words=()):
        self.keywords = frozenset(keywords)
        self.symbols = tuple(symbols)
        self.rule2 = frozenset(rule2)
        self.rule3 = frozenset(rule3)
        self.block_keywords = frozenset(block_keywords)
        self.arm_rules = tuple(arm_rules)
        # braces が真なら { と } を区切り記号として読む（波括弧でブロックを書く案）。
        # 偽なら、文字列補間の外の { と } は字句の誤りである（01-01）
        self.braces = braces
        # 記号 -> (診断の文, 分類)。字句の誤りとし、他の言語の書き方への修正案を示す（01-01）
        self.symbol_hints = dict(symbol_hints or {})
        # `.` の直後では識別子として読むキーワード（案で加えたキーワードを TaskGroup.spawn などに使えるように）
        self.member_words = frozenset(member_words)
        cands = set(self.symbols) | set(self.symbol_hints)
        self._cands = sorted(cands, key=lambda s: (-len(s), s))


BASELINE = LexConfig()


class LexError(Exception):
    """字句の誤り。offset はソースの中の位置（文字の添字）。"""

    def __init__(self, message, offset=None, length=1, category=None):
        Exception.__init__(self, message)
        self.message = message
        self.offset = offset
        self.length = length
        self.category = category


class Token(tuple):
    """字句。(kind, text) を先頭に置き、照合器が t[0] と t[1] で読めるようにする。"""
    __slots__ = ()

    def __new__(cls, kind, text, start, end):
        return tuple.__new__(cls, (kind, text, start, end))

    kind = property(lambda self: self[0])
    text = property(lambda self: self[1])
    start = property(lambda self: self[2])
    end = property(lambda self: self[3])

    def kt(self):
        return (self[0], self[1])


def lex(src, cfg=BASELINE):
    """ソースを字句の並びにし、改行による区切りの規則で NL を置く。"""
    toks = []  # (kind, text, nl_before, nl_offset, start, end)
    i = 0
    n = len(src)
    nl = None  # 直前の字句の後に現れた最初の改行の位置
    # シェバンの行（設計書 01-01「シェバンの行（初回リリース版）」）: 先頭の #! から行末までを読み飛ばす
    if src.startswith('﻿'):
        i = 1
    if src.startswith('#!', i):
        while i < n and src[i] != '\n':
            i += 1
    modes = []  # 文字列補間の中の波括弧の深さの積み重ね

    def push(kind, text, start, end):
        nonlocal nl
        toks.append((kind, text, nl is not None, nl, start, end))
        nl = None

    def scan_string(i, start_kind, tok_start):
        # i は開きの '"' の直後か、補間の閉じの '}' の直後を指す
        buf = ''
        while True:
            if i >= n or src[i] == '\n':
                raise LexError('unterminated string literal', tok_start, max(1, i - tok_start), 'unterminated-string')
            c = src[i]
            if c == '\\':
                i += 2
                continue
            if c == '$' and i + 1 < n and src[i + 1] == '{':
                push('StrStart' if start_kind == 'start' else 'StrMid', buf, tok_start, i + 2)
                modes.append(0)
                return i + 2
            if c == '"':
                push('StringLit' if start_kind == 'start' else 'StrEnd', buf, tok_start, i + 1)
                return i + 1
            buf += c
            i += 1

    while i < n:
        c = src[i]
        if c == '\n':
            if modes:
                raise LexError('a string interpolation `${...}` must be on one line', i, 1, 'unterminated-string')
            if nl is None:
                nl = i
            i += 1
            continue
        if c in ' \t\r':
            i += 1
            continue
        if src.startswith('//', i):
            if modes:
                raise LexError('a comment cannot appear inside a string interpolation', i, 2, 'lex-other')
            while i < n and src[i] != '\n':
                i += 1
            continue
        # 初回リリース版の複数行の文字列と raw 文字列。文法の照合では一つの文字列リテラルとして扱う
        if src.startswith('r"""', i) or src.startswith('"""', i):
            start = i + (4 if src[i] == 'r' else 3)
            m = re.search(r'\n[ \t]*"""', src[start:])
            if not m:
                raise LexError('unterminated multi-line string literal', i, 3, 'unterminated-string')
            push('StringLit', src[start:start + m.start()], i, start + m.end())
            i = start + m.end()
            continue
        if src.startswith('r"', i):
            j = src.find('"', i + 2)
            if j < 0 or '\n' in src[i + 2:j]:
                raise LexError('unterminated raw string literal', i, 2, 'unterminated-string')
            push('StringLit', src[i + 2:j], i, j + 1)
            i = j + 1
            continue
        if c == '"':
            i = scan_string(i + 1, 'start', i)
            continue
        if c == "'":
            m = re.match(r"'(\\u\{[0-9a-fA-F]+\}|\\.|[^'\\])'", src[i:])
            if not m:
                raise LexError('invalid character literal', i, 1, 'bad-character')
            push('CharLit', m.group(0), i, i + len(m.group(0)))
            i += len(m.group(0))
            continue
        m = re.match(r'0x[0-9a-fA-F_]+|\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d+)?', src[i:])
        if m and c.isdigit():
            t = m.group(0)
            # 初回リリース版の Decimal のリテラル（10 進の数に接尾辞 m。指数部は持たない）
            if src.startswith('m', i + len(t)) and not t.startswith('0x') and 'e' not in t.lower():
                push('DecimalLit', t + 'm', i, i + len(t) + 1)
                i += len(t) + 1
                continue
            push('FloatLit' if ('.' in t or 'e' in t.lower() and not t.startswith('0x')) else 'IntLit', t, i, i + len(t))
            i += len(t)
            continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i:])
        if m and m.group(0) != '_':
            t = m.group(0)
            if t in cfg.keywords and not (t in cfg.member_words and toks and toks[-1][:2] == ('sym', '.')):
                push('kw', t, i, i + len(t))
            elif t[0].isupper():
                push('UpperIdent', t, i, i + len(t))
            else:
                push('LowerIdent', t, i, i + len(t))
            i += len(t)
            continue
        for s in cfg._cands:
            if not src.startswith(s, i):
                continue
            if modes and s == '{':
                modes[-1] += 1
            if modes and s == '}':
                if modes[-1] == 0:
                    modes.pop()
                    i = scan_string(i + 1, 'mid', i)
                    break
                modes[-1] -= 1
            if s not in cfg.symbols or (s in ('{', '}') and not modes and not cfg.braces):
                if s in cfg.symbol_hints:
                    msg, cat = cfg.symbol_hints[s]
                    raise LexError(msg, i, len(s), cat)
                raise LexError('unexpected character `%s`' % s, i, len(s), 'bad-character')
            push('sym', s, i, i + len(s))
            i += len(s)
            break
        else:
            raise LexError('unexpected character `%s`' % c, i, 1, 'bad-character')
    return _insert_newlines(toks, cfg)


def _insert_newlines(toks, cfg):
    # 改行による区切り（01-01）。開いている括弧とブロックを積み重ねで数える
    out = []
    stack = []
    guard_depth = None  # 分岐の語の後、ガードを終える字句までの間（ガードの if はブロックを開かない）
    guard_end = None
    arm_blocks = {}
    for arm_kw, block, gend in cfg.arm_rules:
        arm_blocks.setdefault(arm_kw, {})[block] = gend
    for kind, text, nlb, nlo, start, end in toks:
        if nlb and out:
            prev = out[-1]
            after_end = len(out) >= 2 and out[-2].kt() == ('kw', 'end')
            ws = (stack and stack[-1] in ('(', '[')) \
                or (prev[1] in cfg.rule2 and prev[0] in ('sym', 'kw') and not after_end) \
                or (text in cfg.rule3 and kind in ('sym', 'kw'))
            if not ws and out[-1][0] != 'NL':
                out.append(Token('NL', '\n', nlo, nlo + 1))
        elif nlb and not out:
            out.append(Token('NL', '\n', nlo, nlo + 1))
        out.append(Token(kind, text, start, end))
        if kind == 'sym' and text in ('(', '[', '{'):
            stack.append(text)
        if kind == 'sym' and text in (')', ']', '}') and stack:
            stack.pop()
        if kind == 'kw' and text in arm_blocks and stack and stack[-1] in arm_blocks[text]:
            guard_depth = len(stack)
            guard_end = arm_blocks[text][stack[-1]]
        if kind == 'sym' and text == guard_end and guard_depth == len(stack):
            guard_depth = None
        if kind == 'kw' and text in cfg.block_keywords:
            prevtok = out[-2] if len(out) >= 2 else None
            if prevtok is not None and prevtok.kt() == ('kw', 'end'):
                if stack and stack[-1] == text:
                    stack.pop()
            elif text == 'if' and guard_depth == len(stack):
                pass
            elif not (text == 'if' and prevtok is not None and prevtok.kt() == ('kw', 'else')):
                stack.append(text)
        if kind == 'StrStart':
            stack.append('{')
        if kind == 'StrEnd' and stack:
            stack.pop()
    return out


# ---------- EBNF ----------
def gtok(s):
    s = re.sub(r'\(\*.*?\*\)', ' ', s, flags=re.S)
    return re.findall(r'"[^"]*"|[A-Za-z_][A-Za-z0-9_]*|\.\.\.|[=|\[\]{}().,]', s)


def parse_grammar(text):
    t = gtok(text)
    p = 0
    rules = {}

    def peek():
        return t[p] if p < len(t) else None

    def eat(x=None):
        nonlocal p
        v = t[p]
        assert x is None or v == x, (x, v, t[p - 5:p + 5])
        p += 1
        return v

    def alt():
        xs = [seq()]
        while peek() == '|':
            eat()
            xs.append(seq())
        return ('alt', xs) if len(xs) > 1 else xs[0]

    def seq():
        xs = []
        while peek() not in ('|', ']', '}', ')', '.', None):
            xs.append(atom())
        return ('seq', xs)

    def atom():
        v = peek()
        if v == '[':
            eat(); a = alt(); eat(']'); return ('opt', a)
        if v == '{':
            eat(); a = alt(); eat('}'); return ('rep', a)
        if v == '(':
            eat(); a = alt(); eat(')'); return a
        if v.startswith('"'):
            eat()
            return ('lit', v[1:-1])
        eat()
        if peek() == '(' and p < len(t) and t[p + 1] not in ('"',) and re.match(r'[A-Z]', t[p + 1]) and t[p + 2] == ')':
            eat('('); a = eat(); eat(')')
            return ('call', v, a)
        return ('ref', v)

    while p < len(t):
        name = eat()
        params = None
        if peek() == '(':
            eat('('); params = eat(); eat(')')
        eat('=')
        body = alt()
        eat('.')
        rules[name] = (params, body)
    return rules


TERMS = {'LowerIdent', 'UpperIdent', 'IntLit', 'FloatLit', 'DecimalLit', 'StringLit', 'CharLit', 'NL',
         'StrStart', 'StrMid', 'StrEnd'}


class Matcher:
    """EBNF の規則で字句の並びを照合する。各位置から読める終わりの位置の集合を返す（全探索とメモ化）。

    track を真にすると、読めなかった位置のうち最も先のものと、そこで期待した字句を記録する。
    診断はこの記録から作る。described に挙げた規則が、その位置から一つも読めなかったときは、
    その規則の名前を期待したものとして記録する（「式」「型」など、字句の一覧より読みやすい）。
    """

    def __init__(self, rules, toks, track=False, described=()):
        self.r = rules
        self.t = toks
        self.memo = {}
        self.track = track
        self.described = frozenset(described)
        self.far = -1
        self.expected = set()
        self.ctx = []

    def _fail(self, pos, item):
        if pos < self.far:
            return
        if pos > self.far:
            self.far = pos
            self.expected = set()
        for name, start in self.ctx:
            if start == pos and name in self.described:
                item = ('rule', name)
                break
        self.expected.add(item)

    def m(self, node, pos, env):
        k = node[0]
        if k == 'lit':
            if pos < len(self.t) and self.t[pos][1] == node[1] and self.t[pos][0] not in ('StringLit', 'StrStart', 'StrMid', 'StrEnd', 'CharLit'):
                return {pos + 1}
            if self.track:
                self._fail(pos, ('lit', node[1]))
            return set()
        if k == 'seq':
            cur = {pos}
            for x in node[1]:
                nxt = set()
                for c in cur:
                    nxt |= self.m(x, c, env)
                cur = nxt
                if not cur:
                    break
            return cur
        if k == 'alt':
            r = set()
            for x in node[1]:
                r |= self.m(x, pos, env)
            return r
        if k == 'opt':
            return {pos} | self.m(node[1], pos, env)
        if k == 'rep':
            res = {pos}
            front = {pos}
            while front:
                nf = set()
                for f in front:
                    nf |= self.m(node[1], f, env)
                nf -= res
                res |= nf
                front = nf
            return res
        if k == 'ref':
            name = node[1]
            if name in env:
                return self.m(env[name], pos, {})
            if name in TERMS:
                if pos < len(self.t) and self.t[pos][0] == name:
                    return {pos + 1}
                if self.track:
                    self._fail(pos, ('term', name))
                return set()
            key = (name, pos)
            if key in self.memo:
                return self.memo[key]
            self.memo[key] = set()
            params, body = self.r[name]
            if self.track:
                self.ctx.append((name, pos))
            res = self.m(body, pos, {})
            if self.track:
                self.ctx.pop()
            self.memo[key] = res
            return res
        if k == 'call':
            params, body = self.r[node[1]]
            key = (node[1], node[2], pos)
            if key in self.memo:
                return self.memo[key]
            self.memo[key] = set()
            res = self.m(body, pos, {params: ('ref', node[2])})
            self.memo[key] = res
            return res
        raise Exception(node)


def baseline_grammar_text(path=BASELINE_SYNTAX):
    """変更前の 01-02 の写しから、補助規則（CommaList・LineList）と「初回リリース版の文法の全体」の EBNF を取り出す。"""
    syn = open(path, encoding='utf-8').read()
    helpers = re.search(r'```text\n(CommaList.*?)```', syn, re.S).group(1)
    full = re.search(r'### 初回リリース版の文法の全体.*?```text\n(.*?)```', syn, re.S).group(1)
    return helpers, full


def baseline_rules(path=BASELINE_SYNTAX):
    helpers, full = baseline_grammar_text(path)
    rules = parse_grammar(helpers + '\n' + full)
    # 例の断片（文の並び）を照合するための規則。01-02 にはない
    rules['Stmts'] = (None, ('call', 'LineList', 'Stmt'))
    return rules


def check(src, rules, cfg=BASELINE, starts=('Program', 'Stmts', 'Type', 'Pattern')):
    """src を starts の規則のどれかで読めるか確かめる。読めれば (規則の名前, None) を返す。"""
    toks = lex(src, cfg)
    last = None
    for start in starts:
        mt = Matcher(rules, toks)
        ends = mt.m(('ref', start), 0, {})
        if len(toks) in ends:
            return start, None
        last = max(ends) if ends else 0
    return None, (last, [t.kt() for t in toks[last:last + 6]])
