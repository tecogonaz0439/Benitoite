# -*- coding: utf-8 -*-
# 設計書の 01-spec の例が、01-02 の「v1 の文法の全体」で読めるかを確かめる。
# 使い方は README.md を参照。
import re, sys, glob, os
sys.setrecursionlimit(100000)
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'doc', 'design', '01-spec') + os.sep

KW = set('effect else false fn if let match true type uses permissions lazy with trait impl record import pub'.split())
RESERVED = set('as break class continue derive for handle instance loop module mut resume return var where while'.split())
SYMS = ['..', '|>', '->', '=>', '==', '!=', '<=', '>=', '&&', '||',
        '+', '-', '*', '/', '%', '<', '>', '!', '=', ':', ',', '.', '(', ')', '[', ']', '{', '}', '_', '?']
RULE2 = set('+ - * / % == != < <= > >= && || |> ! = -> => : , . ( [ {'.split()) | set('else fn if let match type uses impl import lazy permissions pub record trait with'.split())
RULE3 = set('+ * / % == != < <= > >= && || |> . -> => else'.split())

class LexError(Exception): pass

def lex(src):
    toks = []  # (kind, text, nl_before)
    i = 0; n = len(src); nl = False
    modes = []  # stack for interpolation: brace depth
    def push(kind, text):
        nonlocal nl
        toks.append((kind, text, nl)); nl = False
    def scan_string(i, start_kind):
        # i points just after opening '"' or after closing '}' of interp
        buf = ''
        while True:
            if i >= n or src[i] == '\n': raise LexError('unterminated string')
            c = src[i]
            if c == '\\':
                i += 2; continue
            if c == '$' and i + 1 < n and src[i+1] == '{':
                push('StrStart' if start_kind == 'start' else 'StrMid', buf)
                modes.append(0)
                return i + 2
            if c == '"':
                push('StringLit' if start_kind == 'start' else 'StrEnd', buf)
                return i + 1
            buf += c; i += 1
    while i < n:
        c = src[i]
        if c == '\n':
            if modes: raise LexError('newline in interpolation')
            nl = True; i += 1; continue
        if c in ' \t\r': i += 1; continue
        if src.startswith('//', i):
            if modes: raise LexError('comment in interpolation')
            while i < n and src[i] != '\n': i += 1
            continue
        if c == '"':
            i = scan_string(i + 1, 'start'); continue
        if c == "'":
            m = re.match(r"'(\\u\{[0-9a-fA-F]+\}|\\.|[^'\\])'", src[i:])
            if not m: raise LexError('bad char at %d' % i)
            push('CharLit', m.group(0)); i += len(m.group(0)); continue
        m = re.match(r'0x[0-9a-fA-F_]+|\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d+)?', src[i:])
        if m and c.isdigit():
            t = m.group(0)
            push('FloatLit' if ('.' in t or 'e' in t.lower() and not t.startswith('0x')) else 'IntLit', t)
            i += len(t); continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i:])
        if m and m.group(0) != '_':
            t = m.group(0)
            if t in KW: push('kw', t)
            elif t in RESERVED: raise LexError('reserved word ' + t)
            elif t[0].isupper(): push('UpperIdent', t)
            else: push('LowerIdent', t)
            i += len(t); continue
        for s in SYMS:
            if src.startswith(s, i):
                if modes and s == '{': modes[-1] += 1
                if modes and s == '}':
                    if modes[-1] == 0:
                        modes.pop(); i = scan_string(i + 1, 'mid'); break
                    modes[-1] -= 1
                push('sym', s); i += len(s); break
        else:
            raise LexError('bad char %r at %d' % (c, i))
    # newline insertion
    out = []; stack = []
    for k, (kind, text, nlb) in enumerate(toks):
        if nlb and out:
            prev = out[-1]
            ws = (stack and stack[-1] in '([') or (prev[1] in RULE2 and prev[0] in ('sym', 'kw')) \
                 or (text in RULE3 and kind in ('sym', 'kw'))
            if not ws and out[-1][0] != 'NL':
                out.append(('NL', '\n'))
        elif nlb and not out:
            out.append(('NL', '\n'))
        out.append((kind, text))
        if kind == 'sym' and text in '([{': stack.append(text)
        if kind == 'sym' and text in ')]}' and stack: stack.pop()
        if kind in ('StrStart',): stack.append('{')
        if kind in ('StrEnd',) and stack: stack.pop()
    return out

# ---------- EBNF ----------
def gtok(s):
    s = re.sub(r'\(\*.*?\*\)', ' ', s, flags=re.S)
    return re.findall(r'"[^"]*"|[A-Za-z_][A-Za-z0-9_]*|\.\.\.|[=|\[\]{}().,]', s)

def parse_grammar(text):
    t = gtok(text); p = 0; rules = {}
    def peek(): return t[p] if p < len(t) else None
    def eat(x=None):
        nonlocal p
        v = t[p]
        assert x is None or v == x, (x, v, t[p-5:p+5]); p += 1; return v
    def alt():
        xs = [seq()]
        while peek() == '|': eat(); xs.append(seq())
        return ('alt', xs) if len(xs) > 1 else xs[0]
    def seq():
        xs = []
        while peek() not in ('|', ']', '}', ')', '.', None) or (peek() == '.' and False):
            xs.append(atom())
        return ('seq', xs)
    def atom():
        v = peek()
        if v == '[': eat(); a = alt(); eat(']'); return ('opt', a)
        if v == '{': eat(); a = alt(); eat('}'); return ('rep', a)
        if v == '(': eat(); a = alt(); eat(')'); return a
        if v.startswith('"'): eat(); return ('lit', v[1:-1])
        eat()
        if peek() == '(' and p < len(t) and t[p+1] not in ('"',) and re.match(r'[A-Z]', t[p+1]) and t[p+2] == ')':
            eat('('); a = eat(); eat(')'); return ('call', v, a)
        return ('ref', v)
    while p < len(t):
        name = eat()
        params = None
        if peek() == '(':
            eat('('); params = eat(); eat(')')
        eat('=')
        body = alt(); eat('.')
        rules[name] = (params, body)
    return rules

TERMS = {'LowerIdent', 'UpperIdent', 'IntLit', 'FloatLit', 'StringLit', 'CharLit', 'NL', 'StrStart', 'StrMid', 'StrEnd'}

class Matcher:
    def __init__(self, rules, toks):
        self.r = rules; self.t = toks; self.memo = {}
    def m(self, node, pos, env):
        k = node[0]
        if k == 'lit':
            if pos < len(self.t) and self.t[pos][1] == node[1] and self.t[pos][0] not in ('StringLit','StrStart','StrMid','StrEnd','CharLit'):
                return {pos + 1}
            return set()
        if k == 'seq':
            cur = {pos}
            for x in node[1]:
                nxt = set()
                for c in cur: nxt |= self.m(x, c, env)
                cur = nxt
                if not cur: break
            return cur
        if k == 'alt':
            r = set()
            for x in node[1]: r |= self.m(x, pos, env)
            return r
        if k == 'opt':
            return {pos} | self.m(node[1], pos, env)
        if k == 'rep':
            res = {pos}; front = {pos}
            while front:
                nf = set()
                for f in front: nf |= self.m(node[1], f, env)
                nf -= res; res |= nf; front = nf
            return res
        if k == 'ref':
            name = node[1]
            if name in env: return self.m(env[name], pos, {})
            if name in TERMS:
                return {pos + 1} if pos < len(self.t) and self.t[pos][0] == name else set()
            key = (name, pos)
            if key in self.memo: return self.memo[key]
            self.memo[key] = set()
            params, body = self.r[name]
            res = self.m(body, pos, {})
            self.memo[key] = res; return res
        if k == 'call':
            params, body = self.r[node[1]]
            key = (node[1], node[2], pos)
            if key in self.memo: return self.memo[key]
            self.memo[key] = set()
            res = self.m(body, pos, {params: ('ref', node[2])})
            self.memo[key] = res; return res
        raise Exception(node)

def blocks(path):
    s = open(path, encoding='utf-8').read()
    return [(m.start(), m.group(1)) for m in re.finditer(r'```text\n(.*?)```', s, re.S)]

syn = open(D + '01-02-syntax.md', encoding='utf-8').read()
helpers = re.search(r'```text\n(CommaList.*?)```', syn, re.S).group(1)
full = re.search(r'### v1 の文法の全体.*?```text\n(.*?)```', syn, re.S).group(1)
rules = parse_grammar(helpers + '\n' + full)
rules['Stmts'] = (None, ('call', 'LineList', 'Stmt'))

def check(src):
    toks = lex(src)
    last = None
    for start in ('Program', 'Stmts', 'Type', 'Pattern'):
        mt = Matcher(rules, toks)
        ends = mt.m(('ref', start), 0, {})
        if len(toks) in ends: return start, None
        last = max(ends) if ends else 0
    return None, (last, toks[last:last+6])

# 文法で読めなくて正しい例（字句の一覧、誤りの例、本体を省略したシグネチャなど）。
# 例の先頭の行で指定する。
EXPECTED = {
    ('01-01-lexical.md', 'effect  else  false  fn  if  let  match  true  type  uses'): '字句の一覧',
    ('01-01-lexical.md', 'as  break  class  continue  derive  for  handle  impl'): '予約語の一覧',
    ('01-01-lexical.md', '+   -   *   /   %'): '記号の一覧',
    ('01-01-lexical.md', '..  ?'): '記号の一覧',
    ('01-01-lexical.md', 'fn double(x: Int) -> Int'): '誤りの例（{ を次の行に書く）',
    ('01-02-syntax.md', 'fn((fn() -> Unit uses IO), Int) -> Unit        // fn(fn() -> Unit uses IO, Int) -> Unit は誤り'): '型と、本体を省略した宣言',
    ('01-06-type-system.md', 'fn map[T, U, effect E](xs: List[T], f: fn(T) -> U uses E) -> List[U] uses E   // 本体は省略'): '本体を省略した宣言',
    ('01-06-type-system.md', 'fn runAll(actions: List[fn() -> Unit uses IO]) -> Unit uses IO   // 本体は省略'): '本体を省略した宣言',
}

def is_source(b):
    # 文字列リテラルとコメントを除いて ASCII でない文字が残るものは、数式などとみなして除く
    s = re.sub(r'"(\\.|[^"\\])*"', '', b)
    s = re.sub(r'//.*', '', s)
    return all(ord(c) < 128 for c in s)

if __name__ == '__main__':
    files = sys.argv[1:] or sorted(glob.glob(D + '*.md'))
    ok = bad = skip = expected = 0
    for f in files:
        text = open(f, encoding='utf-8').read()
        for off, b in blocks(f):
            if re.search(r'^\s*[A-Z][A-Za-z]*(\([A-Z]\))?\s+=\s', b, re.M) and b.rstrip().endswith('.'):
                skip += 1; continue  # EBNF の規則
            if not is_source(b):
                skip += 1; continue
            first = b.strip().split('\n')[0].strip()
            try:
                r, err = check(b)
            except LexError as e:
                r, err = None, ('lex', str(e))
            if r:
                ok += 1
            elif (os.path.basename(f), first) in EXPECTED:
                expected += 1
            else:
                bad += 1
                line = text[:off].count('\n') + 1
                print('FAIL %s:%d %s\n    %s' % (os.path.basename(f), line, err, b.strip().replace('\n', '\n    ')[:400]))
    print('ok %d, expected-fail %d, skipped %d, fail %d' % (ok, expected, skip, bad))
    sys.exit(1 if bad else 0)
