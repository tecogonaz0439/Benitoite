# -*- coding: utf-8 -*-
# 設計書の 01-spec の例が、01-02 の「初回リリース版の文法の全体」で読めるかを確かめる。
# 読めた例（プログラムと文の並び）は、局所の束縛の規則（01-03「シャドーイング」）も確かめる。
# 使い方は README.md を参照。
import re, sys, glob, os
sys.setrecursionlimit(100000)
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'design', '01-spec') + os.sep

# 字句解析器・EBNF の読み込み・照合器は syntax_engine.py に、局所の束縛の検査は scope_check.py に置く
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from syntax_engine import LexError, baseline_rules, check as _check, lex  # noqa: E402
from scope_check import ScopeError, check_scopes  # noqa: E402

rules = baseline_rules(D)

def blocks(path):
    s = open(path, encoding='utf-8').read()
    return [(m.start(), m.group(1)) for m in re.finditer(r'```text\n(.*?)```', s, re.S)]

def check(src):
    r, err = _check(src, rules)
    if r in ('Program', 'Stmts'):
        try:
            # 文の並びの断片では、断片の外で束縛した名前を shadow してよい
            check_scopes(lex(src), fragment=(r == 'Stmts'))
        except ScopeError as e:
            return None, ('scope', e.category, e.message, 'offset %d' % e.token.start)
    return r, err

# 文法で読めなくて正しい例（字句の一覧、誤りの例、本体を省略したシグネチャなど）。
# 例の先頭の行で指定する。
EXPECTED = {
    ('01-01-lexical.md', 'and  bind  case  data  div  effect  else  end  false  function  if  lambda  match'): '字句の一覧',
    ('01-01-lexical.md', 'handle  implement  import  lazy  public  resume  trait'): '予約語の一覧',
    ('01-01-lexical.md', '+   -   *   /'): '記号の一覧',
    ('01-01-lexical.md', '..  &'): '記号の一覧',
    ('01-02-syntax.md', 'function((function() -> Unit uses Console.Write), Integer) -> Unit        // function(function() -> Unit uses Console.Write, Integer) -> Unit は誤り'): '型と、本体を省略した宣言',
    ('01-03-names-modules.md', 'function total(items: List[Integer]) -> Integer'): '誤りの例（ラムダの引数が局所の名前を隠す）',
    ('01-06-type-system.md', 'function map[T, U, effect E](xs: List[T], f: function(T) -> U uses E) -> List[U] uses E   // 本体は省略'): '本体を省略した宣言',
    ('01-06-type-system.md', 'function runAll(actions: List[function() -> Unit uses Console.Write]) -> Unit uses Console.Write   // 本体は省略'): '本体を省略した宣言',
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
