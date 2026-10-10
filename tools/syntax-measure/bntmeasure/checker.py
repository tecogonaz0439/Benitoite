# -*- coding: utf-8 -*-
"""案ごとの構文の検査と診断。

検査は次の順に行い、最初の誤りだけを報告する（二つ目以降の誤りは探さない）。
1. 字句解析（syntax_engine.lex）。他の言語の記号には、案ごとの修正案を示す（variants.symbol_hints）。
2. EBNF による照合。読めなかった位置のうち最も先の位置と、そこで期待した字句から診断を作る。
3. 照合を通った後の検査。属性の名前（設計書 01-02「属性」）と、V06・V15 の bind と shadow の有効範囲。
型・エフェクト・名前解決は検査しない（構文の測定の第一段階は構文だけを測る。docs/todo の TODO-017）。
"""
import sys
import threading

from . import variants as V
from .scope import ScopeError, check_scopes
from .variants import E

# 照合に失敗した位置で、字句の一覧の代わりに示す規則の呼び名
DESCRIBED = {
    'AttrDecl': 'a declaration',
    'Stmt': 'a statement',
    'Expr': 'an expression',
    'Type': 'a type',
    'Pattern': 'a pattern',
    'Param': 'a parameter',
}
TERM_NAMES = {
    'LowerIdent': 'a lowercase name',
    'UpperIdent': 'a capitalized name',
    'IntLit': 'an integer literal',
    'FloatLit': 'a float literal',
    'DecimalLit': 'a decimal literal',
    'StringLit': 'a string literal',
    'CharLit': 'a character literal',
    'NL': 'a line break',
    'StrStart': 'a string literal',
    'StrMid': 'the rest of the string',
    'StrEnd': 'the end of the string',
}
OPERATORS = {'+', '-', '*', '/', 'div', 'mod', '=', '<>', '<', '<=', '>', '>=', 'and', 'or', '|>', '(', '==',
             '!=', '&&', '||', '%', '?', '<-'}
# 他の言語のキーワード。案のキーワードでなければ、識別子として読まれて構文の誤りになる
FOREIGN = set('fn func fun def var val mut match switch default for while loop break continue elif elsif elseif '
              'unless class new null nil self this as where async await spawn select yield data bind shadow test '
              'impl pub private static let then of end when do try div mod and or not function public implement'.split())
BLOCK_CLOSERS = {'function', 'fn', 'type', 'data', 'record', 'trait', 'effect', 'implement', 'impl', 'lambda', 'if',
                 'case', 'match', 'with', 'lazy', 'handle', 'test'}
STACK_SIZE = 256 * 1024 * 1024
_STACK_LOCK = threading.Lock()


class Diagnostic:
    def __init__(self, message, start, end, category, help=None, found=None, expected=None, stage='parse'):
        self.message = message
        self.start = start
        self.end = end
        self.category = category
        self.help = help
        self.found = found
        self.expected = expected or []
        self.stage = stage

    def to_dict(self):
        return dict(message=self.message, start=self.start, end=self.end, category=self.category, help=self.help,
                    found=self.found, expected=self.expected, stage=self.stage)


class Result:
    def __init__(self, ok, diagnostic=None, start_rule=None, text=''):
        self.ok = ok
        self.diagnostic = diagnostic
        self.start_rule = start_rule
        self.text = text


def _run_big_stack(fn):
    # 照合器は再帰で書いてあるので、深い入れ子でも止まらないように大きなスタックのスレッドで動かす
    box = {}

    def target():
        try:
            box['v'] = fn()
        except BaseException as e:  # noqa: BLE001 呼び出し元で投げ直す
            box['e'] = e
    with _STACK_LOCK:  # threading.stack_size はプロセス全体の設定なので、並行の試行の間で守る
        old = threading.stack_size()
        threading.stack_size(STACK_SIZE)
        try:
            t = threading.Thread(target=target)
            t.start()
        finally:
            threading.stack_size(old)
    t.join()
    if 'e' in box:
        raise box['e']
    return box['v']


def check_source(variant, src, filename='main.bnt', starts=('Program',)):
    """src を案 variant の文法で検査する。Result を返す。"""
    if isinstance(variant, str):
        variant = V.get(variant)
    sys.setrecursionlimit(1000000)
    return _run_big_stack(lambda: _check(variant, src, filename, starts))


def _check(v, src, filename, starts):
    try:
        toks = E.lex(src, v.lex)
    except E.LexError as e:
        d = Diagnostic(e.message, e.offset or 0, (e.offset or 0) + (e.length or 1), e.category or 'lex-other',
                       found=src[e.offset:e.offset + (e.length or 1)] if e.offset is not None else None, stage='lex')
        return Result(False, d, text=format_diagnostic(d, src, filename))
    best = None
    for start in starts:
        mt = E.Matcher(v.rules, toks, track=True, described=DESCRIBED)
        ends = mt.m(('ref', start), 0, {})
        if len(toks) in ends:
            d = _post_checks(v, toks, src, start)
            if d:
                return Result(False, d, text=format_diagnostic(d, src, filename))
            return Result(True, start_rule=start, text='ok')
        if best is None or mt.far > best.far:
            best = mt
    d = _parse_diagnostic(v, toks, src, best)
    return Result(False, d, text=format_diagnostic(d, src, filename))


def _post_checks(v, toks, src, start):
    # 属性の名前（01-02「属性（初回リリース版）」: 利用者が書ける属性は @test と @deprecated だけ）
    for i, t in enumerate(toks[:-1]):
        if t.kt() == ('sym', '@') and toks[i + 1].kind == 'LowerIdent' and toks[i + 1].text not in v.attributes:
            name = toks[i + 1].text
            allowed = ', '.join('`@%s`' % a for a in sorted(v.attributes))
            return Diagnostic('unknown attribute `@%s`; the attributes you can write are %s' % (name, allowed),
                              t.start, toks[i + 1].end, 'unknown-attribute', found='@' + name, stage='attribute')
    if 'bind_shadow' in v.features:
        try:
            check_scopes(toks, v)
        except ScopeError as e:
            return Diagnostic(e.message, e.token.start, e.token.end, e.category, found=e.token.text, stage='scope')
    return None


def _desc_found(toks, pos):
    if pos >= len(toks):
        return 'end of file'
    t = toks[pos]
    if t.kind == 'NL':
        return 'end of line'
    if t.kind in ('StringLit', 'StrStart'):
        return 'a string literal'
    if t.kind == 'CharLit':
        return 'a character literal'
    if t.kt() == ('kw', 'end') and pos + 1 < len(toks) and toks[pos + 1].kind == 'kw':
        return '`end %s`' % toks[pos + 1].text
    return '`%s`' % t.text


def _item_text(item):
    kind, x = item
    if kind == 'lit':
        return '`%s`' % x
    if kind == 'rule':
        return DESCRIBED[x]
    return TERM_NAMES.get(x, x)


def _order(item):
    kind, x = item
    if kind == 'lit' and x in OPERATORS:
        return (5, x)
    if kind == 'lit':
        return (0, x)
    if kind == 'rule':
        return (1, x)
    if kind == 'term' and x == 'NL':
        return (4, x)
    return (3, x)


def _end_names(v, toks, far):
    # far の位置に end を補ったとき、その後に期待する構文の名前（end if の if など）を調べる
    s = toks[far].start if far < len(toks) else (toks[-1].end if toks else 0)
    toks2 = toks[:far] + [E.Token('kw', 'end', s, s)] + toks[far:]
    mt = E.Matcher(v.rules, toks2, track=True, described=())
    mt.m(('ref', 'Program'), 0, {})
    if mt.far == far + 1:
        return sorted(x for k, x in mt.expected if k == 'lit' and x in BLOCK_CLOSERS)
    return []


def _open_paren_before(toks, far):
    depth = 0
    for i in range(far - 1, -1, -1):
        t = toks[i]
        if t.kind != 'sym':
            continue
        if t.text in (')', ']', '}'):
            depth += 1
        elif t.text in ('(', '[', '{'):
            if depth == 0:
                return i
            depth -= 1
    return None


def _parse_diagnostic(v, toks, src, mt):
    far = max(mt.far, 0)
    expected = set(mt.expected)
    found_tok = toks[far] if far < len(toks) else None
    prev = toks[far - 1] if far > 0 else None
    eof = len(src.rstrip()) if found_tok is None else None
    start = found_tok.start if found_tok else eof
    end = found_tok.end if found_tok else eof + 1
    if found_tok is not None and found_tok.kt() == ('kw', 'end') and far + 1 < len(toks) and toks[far + 1].kind == 'kw':
        end = toks[far + 1].end
    found = _desc_found(toks, far)
    ftext = found_tok.text if found_tok else None
    fkind = found_tok.kind if found_tok else 'EOF'

    # 予約語（V03・V04）: その語を使ったこと自体を、専用の文で報告する
    if found_tok is not None and fkind == 'kw' and ftext in v.word_hints:
        msg, cat = v.word_hints[ftext]
        return Diagnostic(msg, start, end, cat, found=ftext)
    if prev is not None and prev.kind == 'kw' and prev.text in v.word_hints:
        msg, cat = v.word_hints[prev.text]
        return Diagnostic(msg, prev.start, prev.end, cat, found=prev.text)

    # テストのブロック（V14）で、@test の属性を書いた
    if 'test_blocks' in v.features and ftext == 'test' and prev is not None and prev.kt() == ('sym', '@'):
        return Diagnostic('`@test` is not an attribute; write a test as a block: `test "description" ... end test`',
                          prev.start, end, 'test-attribute', found='@test')

    # end の後の構文の名前が違う、または名前がない（01-02「ブロックと文」）
    if prev is not None and prev.kt() == ('kw', 'end'):
        names = sorted(x for k, x in expected if k == 'lit' and x in BLOCK_CLOSERS)
        if names:
            want = ' or '.join('`end %s`' % n for n in names)
            if found_tok is not None and fkind == 'kw' and ftext in BLOCK_CLOSERS:
                return Diagnostic('expected %s, found `end %s`' % (want, ftext), prev.start, end, 'end-mismatch',
                                  found='end ' + ftext, expected=[want])
            return Diagnostic('expected %s, found `end` without the name of the construct' % want, prev.start,
                              prev.end, 'bare-end', help='close a block with `end` followed by the name of the '
                              'construct, e.g. %s' % want, found='end', expected=[want])

    # 括弧で囲んでコンマで並べた組（01-02「組と let のパターン」）
    if 'tuples' not in v.features and ftext == ',' and fkind == 'sym':
        k = _open_paren_before(toks, far)
        if k is not None and toks[k].text == '(':
            before = toks[k - 1] if k > 0 else None
            if before is None or not (before.kind in ('LowerIdent', 'UpperIdent') or before.text in (')', ']')
                                      or (before.kind == 'kw' and before.text in (v.kw('function'), 'lambda', 'resume'))):
                return Diagnostic('Benitoite has no tuples in parentheses; use `Pair(a, b)` for two values, '
                                  '`Triple(a, b, c)` for three, or declare a `record`', start, end, 'tuple-parens',
                                  found=',')

    # 値の後のドット（01-02「ドット記法」）
    if ftext == '.' and fkind == 'sym' and prev is not None and (
            prev.kind in ('LowerIdent', 'StringLit', 'StrEnd') or prev.text in (')', ']')):
        return Diagnostic('a value cannot be followed by `.`; call the function of the module instead, e.g. '
                          '`xs |> List.map(f)` or `Person.name(p)`', start, end, 'value-dot', found='.')

    # 一般の診断: 期待した字句と見つけた字句
    items = set(expected)
    ops = [it for it in items if it[0] == 'lit' and it[1] in OPERATORS]
    if len(ops) >= 3:
        items -= set(ops)
        items.add(('op', 'an operator'))
    texts = []
    end_names = []
    if ('lit', 'end') in items:
        end_names = _end_names(v, toks, far)
    for it in sorted(items, key=lambda it: (6, '') if it[0] == 'op' else _order(it)):
        if it == ('lit', 'end') and end_names:
            texts.append(' or '.join('`end %s`' % n for n in end_names))
        elif it[0] == 'op':
            texts.append('an operator')
        else:
            texts.append(_item_text(it))
    texts = list(dict.fromkeys(texts))
    shown = texts[:4]
    if len(texts) > 4:
        shown.append('...')
    want = shown[0] if len(shown) == 1 else ', '.join(shown[:-1]) + ' or ' + shown[-1]
    if not texts:
        want = 'something else'
    msg = 'expected %s, found %s' % (want, found)
    cat = _category(v, toks, far, expected, found_tok, prev, end_names)
    return Diagnostic(msg, start, end, cat, found=found, expected=texts)


def _category(v, toks, far, expected, found_tok, prev, end_names):
    lits = {x for k, x in expected if k == 'lit'}
    ftext = found_tok.text if found_tok else None
    fkind = found_tok.kind if found_tok else 'EOF'
    if found_tok is not None and fkind == 'LowerIdent' and ftext in FOREIGN:
        return 'foreign-keyword:' + ftext
    if prev is not None and prev.kind == 'LowerIdent' and prev.text in FOREIGN and fkind != 'NL':
        return 'foreign-keyword:' + prev.text
    if fkind == 'kw' and ('term', 'LowerIdent') in expected:
        return 'keyword-as-name:' + ftext
    if (ftext == '->' and ':' in lits) or (ftext == ':' and '->' in lits):
        return 'return-type-syntax'
    if 'data_decl' in v.features and '=' in lits and far >= 2 and toks[far - 2].kt() == ('kw', 'type'):
        return 'type-for-data'
    if fkind in ('NL', 'EOF') and ('end' in lits or '}' in lits):
        return 'missing-end'
    for kw in ('then', 'of', 'do', 'with'):
        if kw in lits and fkind in ('NL', 'EOF', 'kw', 'sym') and kw in v.keywords:
            return 'missing-' + kw
    if fkind == 'EOF':
        return 'unexpected-eof'
    if fkind == 'NL':
        return 'unexpected-line-break'
    if fkind == 'kw':
        return 'unexpected-keyword:' + ftext
    if fkind == 'sym':
        return 'unexpected-symbol:' + ftext
    return 'unexpected-' + fkind


def _line_col(src, offset):
    line = src.count('\n', 0, offset) + 1
    ls = src.rfind('\n', 0, offset) + 1
    return line, offset - ls + 1, ls


def format_diagnostic(d, src, filename):
    """コンパイラの形の診断の文字列（error: 文 / --> ファイル:行:列 / 行とキャレット）。"""
    offset = min(max(d.start, 0), len(src))
    line, col, ls = _line_col(src, offset)
    le = src.find('\n', ls)
    if le < 0:
        le = len(src)
    text = src[ls:le].replace('\t', ' ')
    width = max(1, min(d.end, le) - offset)
    num = str(line)
    pad = ' ' * len(num)
    out = ['error: %s' % d.message,
           '%s--> %s:%d:%d' % (pad, filename, line, col),
           '%s |' % pad,
           '%s | %s' % (num, text),
           '%s | %s%s' % (pad, ' ' * (col - 1), '^' * width)]
    if d.help:
        out.append('%s = help: %s' % (pad, d.help))
    return '\n'.join(out)
