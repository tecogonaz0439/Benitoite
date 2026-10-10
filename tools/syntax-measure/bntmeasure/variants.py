# -*- coding: utf-8 -*-
"""構文の案（V00〜V15）の定義。

各案は、基準の文法（V00。2026-09-29 の構文の変更の前の、設計書 01-01 の字句の規則と
01-02「初回リリース版の文法の全体」。syntax_engine.py と variants/V00/baseline-syntax.md に凍結した）に
「差分」（PATCHES）を当てたものとして、データで表す。差分が変えるのは、キーワードの集合、記号の集合、
改行による区切りの規則の字句の集合、ブロックを開く語、EBNF の規則の置き換えと追加、
予約語の診断の表である。V01（C 系の構文の全体）だけは、EBNF を別のファイル（variants/V01/grammar.ebnf）に置く。
V15 は V05・V06・V07・V08 の差分を順に当てる。
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
REPO = os.path.normpath(os.path.join(ROOT, '..', '..'))

# 基準の文法は、この道具の中の凍結した写しから読む（設計書の現在の文法と grammar-check には依存しない）
from . import syntax_engine as E  # noqa: E402

# 案の一覧。title は README とレポートで使う短い説明（日本語）
VARIANTS = [
    ('V00', '基準（現在の文法）', []),
    ('V01', 'C 系の構文の全体（波括弧のブロック、switch、==・&&、/・%）', ['V01']),
    ('V02', '省略形のキーワード fn・pub・impl', ['V02']),
    ('V03', '基準＋fn・pub・impl を予約し、専用の診断を出す', ['V03']),
    ('V04', '基準＋ほかの言語の制御構文などの語を予約し、専用の診断を出す', ['V04']),
    ('V05', '戻り値の型を -> T で書く', ['V05']),
    ('V06', '局所束縛を bind x <- e（初回）と shadow x <- e（再束縛）で書く', ['V06']),
    ('V07', '代数的データ型を data … end data で宣言する', ['V07']),
    ('V08', 'パターンマッチを match e with case p -> e … end match で書く', ['V08']),
    ('V09', '後置の ? （前置の try の代わり）', ['V09']),
    ('V10', '型クラスの制約を + でつなぐ', ['V10']),
    ('V11', '括弧のタプル (a, b)（Pair・Triple の代わり）', ['V11']),
    ('V12', '演算子 ==・!=・&&・||・!', ['V12']),
    ('V13', '整数の除算を /、剰余を % で書く', ['V13']),
    ('V14', 'テストを test "名前" … end test のブロックで書く', ['V14']),
    ('V15', '設計者の案（V05＋V06＋V07＋V08）', ['V05', 'V06', 'V07', 'V08']),
]
VARIANT_IDS = [v[0] for v in VARIANTS]
TITLES = {v[0]: v[1] for v in VARIANTS}

# 差分。キーの意味は apply_patch を参照
PATCHES = {
    'V01': dict(
        features={'braces', 'c_ops', 'c_div'},
        grammar_file='V01/grammar.ebnf',
        add_keywords={'switch'},
        remove_keywords={'end', 'then', 'of', 'when', 'do', 'and', 'or', 'not', 'div', 'mod'},
        add_symbols={'==', '!=', '&&', '||', '!', '%', '{', '}'},
        remove_symbols={'<>'},
        add_rule2={'==', '!=', '&&', '||', '!', '%', '{', 'switch'},
        remove_rule2={'and', 'or', 'not', 'div', 'mod', 'of', 'then', 'when', 'do', '<>'},
        add_rule3={'==', '!=', '&&', '||', '%', '}'},
        remove_rule3={'and', 'or', 'div', 'mod', 'then', 'of', 'do', '<>'},
        block_keywords=set(),
        arm_rules=(),
    ),
    'V02': dict(
        features={'abbrev_kw'},
        rename={'function': 'fn', 'public': 'pub', 'implement': 'impl'},
    ),
    'V03': dict(
        features={'reserve_abbrev'},
        add_keywords={'fn', 'pub', 'impl'},
        word_hints={
            'fn': ('`fn` is not a keyword in Benitoite; write `function`', 'reserved-abbrev'),
            'pub': ('`pub` is not a keyword in Benitoite; write `public`', 'reserved-abbrev'),
            'impl': ('`impl` is not a keyword in Benitoite; write `implement`', 'reserved-abbrev'),
        },
    ),
    'V04': dict(
        features={'reserve_absent'},
        add_keywords=set('for while loop break continue as where async await spawn select'.split()),
        word_hints=dict(
            [(w, ('Benitoite has no `%s` loop; use recursion, or List functions such as List.map, '
                  'List.filter, List.fold and List.forEach' % w, 'reserved-loop')) for w in ('for', 'while', 'loop')]
            + [(w, ('Benitoite has no loops, so there is no `%s`; use recursion (return the result with '
                    '`return`) or List functions such as List.map and List.fold' % w, 'reserved-loop'))
               for w in ('break', 'continue')]
            + [('as', ('`as` can only be used in an import declaration; Benitoite has no casts, use a '
                       'conversion function such as Integer.toFloat or Integer.toString', 'reserved-as')),
               ('where', ('Benitoite has no `where` clause; bind the values with `let` inside the body',
                          'reserved-where'))]
            + [(w, ('Benitoite has no `%s`; start tasks with Task.all, Task.race or TaskGroup.spawn, wait with '
                    'Task.await, and declare the effects with `uses`' % w, 'reserved-async'))
               for w in ('async', 'await', 'spawn', 'select')]),
    ),
    'V05': dict(
        features={'arrow_return'},
        rules='''
FnDecl      = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              "->" Type [ Uses ] Body "end" "function" .
MethodSig   = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] .
OpSig       = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type .
Lambda      = "lambda" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] Body "end" "lambda" .
''',
    ),
    'V06': dict(
        features={'bind_shadow'},
        add_keywords={'bind', 'shadow'},
        remove_keywords={'let'},
        add_symbols={'<-'},
        add_rule2={'bind', 'shadow', '<-'},
        remove_rule2={'let'},
        add_rule3={'<-'},
        rules='''
LetStmt     = ( "bind" | "shadow" ) Pattern [ ":" Type ] "<-" Expr .
''',
    ),
    'V07': dict(
        features={'data_decl'},
        add_keywords={'data'},
        add_rule2={'data'},
        rules='''
TypeDecl    = "data" UpperIdent [ TypeParams ] LineList(Variant) "end" "data" .
''',
    ),
    'V08': dict(
        features={'match_with'},
        add_keywords={'match'},
        remove_keywords={'of'},
        add_rule2={'match'},
        remove_rule2={'of'},
        remove_rule3={'of'},
        block_keywords={'lambda', 'if', 'match', 'with', 'lazy', 'handle'},
        arm_rules=(('case', 'match', '->'), ('when', 'handle', ':')),
        rules='''
CaseExpr    = "match" Expr "with" [ NL ] Arm { NL Arm } [ NL ] "end" "match" .
Arm         = "case" Pattern { "," Pattern } [ "if" Expr ] "->" ArmBody .
''',
    ),
    'V09': dict(
        features={'postfix_try'},
        remove_keywords={'try'},
        add_symbols={'?'},
        remove_rule2={'try'},
        rules='''
Expr        = "return" Expr
            | PipeExpr .
CallExpr    = Primary { "(" CommaList(Arg) ")" | "?" } .
''',
    ),
    'V10': dict(
        features={'plus_constraints'},
        remove_symbols={'&'},
        remove_rule2={'&'},
        rules='''
FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" Constraint { "+" Constraint } ] .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl [ ":" QualUpper { "+" QualUpper } ] "]"
              LineList(MethodSig) "end" "trait" .
''',
    ),
    'V11': dict(
        features={'tuples'},
        rules='''
Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(Type) ")" "->" Type [ Uses ]
            | "(" Type ")"
            | "(" Type "," Type { "," Type } [ "," ] ")" .
Primary     = Literal
            | InterpString
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "(" Expr "," Expr { "," Expr } [ "," ] ")"
            | "[" CommaList(Expr) "]"
            | IfExpr
            | CaseExpr
            | Lambda
            | RecordExpr
            | "lazy" Body "end" "lazy"
            | WithExpr
            | HandleExpr
            | "resume" "(" Expr ")" .
Pattern     = "_"
            | LowerIdent
            | [ "-" ] IntLit
            | StringLit
            | CharLit
            | "true" | "false"
            | "(" ")"
            | "(" Pattern "," Pattern { "," Pattern } [ "," ] ")"
            | QualUpper [ "(" CommaList(Pattern) ")" ]
            | QualUpper "(" FieldPat { "," FieldPat } [ "," ".." ] [ "," ] ")"
            | RangeEnd ".." RangeEnd
            | "[" [ ListPatElem { "," ListPatElem } [ "," ] ] "]" .
''',
    ),
    'V12': dict(
        features={'c_ops'},
        remove_keywords={'and', 'or', 'not'},
        add_symbols={'==', '!=', '&&', '||', '!'},
        remove_symbols={'<>'},
        add_rule2={'==', '!=', '&&', '||', '!'},
        remove_rule2={'and', 'or', 'not', '<>'},
        add_rule3={'==', '!=', '&&', '||'},
        remove_rule3={'and', 'or', '<>'},
        rules='''
OrExpr      = AndExpr { "||" AndExpr } .
AndExpr     = CmpExpr { "&&" CmpExpr } .
CmpOp       = "==" | "!=" | "<" | "<=" | ">" | ">=" .
UnaryExpr   = ( "-" | "!" ) UnaryExpr | CallExpr .
''',
    ),
    'V13': dict(
        features={'c_div'},
        remove_keywords={'div', 'mod'},
        add_symbols={'%'},
        add_rule2={'%'},
        remove_rule2={'div', 'mod'},
        add_rule3={'%'},
        remove_rule3={'div', 'mod'},
        rules='''
MulExpr     = UnaryExpr { ( "*" | "/" | "%" ) UnaryExpr } .
''',
    ),
    'V14': dict(
        features={'test_blocks'},
        add_keywords={'test'},
        add_rule2={'test'},
        attributes={'deprecated'},
        rules='''
Decl        = [ "public" ] FnDecl
            | [ "public" ] ConstDecl
            | [ "public" ] TypeDecl
            | [ "public" ] AliasDecl
            | [ "public" ] RecordDecl
            | [ "public" ] TraitDecl
            | [ "public" ] EffectDecl
            | ImplDecl
            | TestDecl .
TestDecl    = "test" StringLit Body "end" "test" .
''',
    ),
}

# 設計書の EBNF の注釈（日本語）を、参照の文書（英語）に載せるときの訳
COMMENT_EN = {
    'プログラム': 'program',
    'import の宣言': 'import declaration',
    '関数の宣言': 'function declaration',
    '定数の宣言': 'constant declaration',
    '型・型の別名・レコード・型クラスの宣言': 'type, type alias, record, trait, implementation and effect declarations',
    '型': 'types',
    '文の並びと文': 'blocks and statements',
    '式': 'expressions',
    'パターン': 'patterns',
}


def split_rules(text):
    """EBNF の文字列を、注釈と規則の並び [('comment', 文) | ('rule', 名前, 文)] に分ける。"""
    items = []
    cur = None
    for line in text.split('\n'):
        m = re.match(r'^\(\*\s*(.*?)\s*\*\)\s*$', line)
        if m:
            items.append(('comment', m.group(1)))
            cur = None
            continue
        m = re.match(r'^([A-Z][A-Za-z]*)(\([A-Z]\))?\s*=', line)
        if m:
            cur = ['rule', m.group(1), line]
            items.append(cur)
            continue
        if line.strip() == '':
            if items and items[-1] != ('blank',):
                items.append(('blank',))
            cur = None
            continue
        if cur is None:
            raise ValueError('EBNF の行を規則に結び付けられない: %r' % line)
        cur[2] += '\n' + line
    return [tuple(x) for x in items]


def join_rules(items):
    out = []
    for it in items:
        if it[0] == 'comment':
            out.append('(* %s *)' % it[1])
        elif it[0] == 'blank':
            out.append('')
        else:
            out.append(it[2])
    return '\n'.join(out).strip() + '\n'


class Variant:
    """一つの案。字句の規則（lex）、EBNF の規則（rules）、表示用の EBNF（ebnf）などを持つ。"""

    def __init__(self, vid):
        self.id = vid
        self.title = TITLES[vid]
        self.patches = dict((v[0], v[2]) for v in VARIANTS)[vid]
        self.features = set()
        self.keywords = set(E.BASELINE_KEYWORDS)
        self.symbols = list(E.BASELINE_SYMBOLS)
        # 変更前の 01-01「改行による区切り」の規則 2 に挙がる const と effect は、変更前の grammar_check.py の表にはないので加える
        self.rule2 = set(E.BASELINE_RULE2) | {'const', 'effect'}
        self.rule3 = set(E.BASELINE_RULE3)
        self.block_keywords = set(E.BASELINE_BLOCK_KEYWORDS)
        self.arm_rules = tuple(E.BASELINE_ARM_RULES)
        self.word_hints = {}
        self.attributes = {'test', 'deprecated'}
        self.rename = {}
        helpers, full = E.baseline_grammar_text()
        self.helpers = helpers
        self.items = split_rules(full)
        for pid in self.patches:
            self._apply(PATCHES[pid])
        self._finish()

    def _apply(self, p):
        self.features |= p.get('features', set())
        if 'grammar_file' in p:
            self.items = split_rules(open(os.path.join(ROOT, 'variants', p['grammar_file']), encoding='utf-8').read())
        self.keywords |= p.get('add_keywords', set())
        self.keywords -= p.get('remove_keywords', set())
        for s in p.get('add_symbols', ()):
            if s not in self.symbols:
                self.symbols.append(s)
        self.symbols = [s for s in self.symbols if s not in p.get('remove_symbols', set())]
        self.rule2 |= p.get('add_rule2', set())
        self.rule2 -= p.get('remove_rule2', set())
        self.rule3 |= p.get('add_rule3', set())
        self.rule3 -= p.get('remove_rule3', set())
        if 'block_keywords' in p:
            self.block_keywords = set(p['block_keywords'])
        if 'arm_rules' in p:
            self.arm_rules = tuple(p['arm_rules'])
        self.word_hints.update(p.get('word_hints', {}))
        if 'attributes' in p:
            self.attributes = set(p['attributes'])
        self.rename.update(p.get('rename', {}))
        if 'rules' in p:
            new = [it for it in split_rules(p['rules']) if it[0] == 'rule']
            names = [it[1] for it in self.items if it[0] == 'rule']
            last = None
            for it in new:
                if it[1] in names:
                    idx = [k for k, x in enumerate(self.items) if x[0] == 'rule' and x[1] == it[1]][0]
                    self.items[idx] = it
                else:
                    # 新しい規則は、同じ差分の直前の規則の後に置く
                    idx = [k for k, x in enumerate(self.items) if x[0] == 'rule' and x[1] == last][0] if last else len(self.items) - 1
                    self.items.insert(idx + 1, it)
                last = it[1]

    def _finish(self):
        # 省略形のキーワードへの改名（V02）。EBNF の字句、キーワード、改行の規則の集合に当てる
        for old, new in self.rename.items():
            self.items = [(it[0], it[1], it[2].replace('"%s"' % old, '"%s"' % new)) if it[0] == 'rule' else it
                          for it in self.items]
            for attr in ('keywords', 'rule2', 'rule3', 'block_keywords'):
                s = getattr(self, attr)
                if old in s:
                    s.discard(old)
                    s.add(new)
        self.ebnf = join_rules([(it[0], COMMENT_EN.get(it[1], it[1])) if it[0] == 'comment' else it for it in self.items])
        self.rules = E.parse_grammar(self.helpers + '\n' + self.ebnf)
        self.rules['Stmts'] = (None, ('call', 'LineList', 'Stmt'))
        self.lex = E.LexConfig(keywords=self.keywords, symbols=sorted(self.symbols, key=lambda s: (-len(s), s)),
                               rule2=self.rule2, rule3=self.rule3, block_keywords=self.block_keywords,
                               arm_rules=self.arm_rules, braces='braces' in self.features,
                               symbol_hints=symbol_hints(self),
                               member_words=self.keywords - E.BASELINE_KEYWORDS)

    # 案の書き方を表す語。診断の文と参照の文書で使う
    def kw(self, word):
        return self.rename.get(word, word)

    @property
    def braces(self):
        return 'braces' in self.features

    def arm_form(self):
        if self.braces:
            return '`case pattern: expression`'
        if 'match_with' in self.features:
            return '`case pattern -> expression`'
        return '`when pattern: expression`'

    def reserved_words(self):
        return sorted(self.word_hints)

    def keyword_list(self):
        return sorted(self.keywords - set(self.word_hints))


def symbol_hints(v):
    """他の言語の記号を書いたときの字句の誤りの診断（設計書 01-01「演算子と区切り記号」の修正案）。

    案がその記号を正しい字句にしたときは、表から除く。
    """
    f = v.features
    arm = v.arm_form()
    h = {
        ';': ('`;` is not used in Benitoite; separate statements with line breaks', 'semicolon'),
        '=>': ('`=>` is not used in Benitoite; write a case arm as %s' % arm, 'fat-arrow'),
        '|': ('`|` is not used in Benitoite; separate alternative patterns with commas, and write the '
              'constructors of a type one per line', 'pipe-alternative'),
        '..=': ('a range pattern is written `low..high` and includes both ends', 'range-syntax'),
        '..<': ('a range pattern is written `low..high` and includes both ends', 'range-syntax'),
        '...': ('a range pattern is written `low..high` and includes both ends', 'range-syntax'),
        '#': ('`#` is not used in Benitoite; comments start with `//` and attributes are written like `@test`',
              'hash'),
    }
    if 'braces' not in f:
        closing = ', '.join('`end %s`' % v.kw(w) for w in ('function', 'if'))
        for s in ('{', '}'):
            h[s] = ('Benitoite does not use braces for blocks; close each block with `end` and the name of '
                    'the construct, e.g. %s' % closing, 'brace-block')
    if 'c_ops' not in f:
        h['=='] = ('`==` is not an operator in Benitoite; write `=` for equality', 'c-equality')
        h['!='] = ('`!=` is not an operator in Benitoite; write `<>` for inequality', 'c-equality')
        h['&&'] = ('`&&` is not an operator in Benitoite; write `and`', 'c-logic')
        h['||'] = ('`||` is not an operator in Benitoite; write `or`', 'c-logic')
        h['!'] = ('`!` is not an operator in Benitoite; write `not`', 'c-logic')
    if 'c_div' not in f:
        h['%'] = ('`%` is not an operator in Benitoite; write `mod` for the remainder (and `div` for integer '
                  'division)', 'percent-remainder')
    if 'postfix_try' not in f:
        h['?'] = ('`?` is not an operator in Benitoite; to return early from `Result.Error` or `Option.None`, '
                  'write `try` before the expression', 'question-mark')
    return h


_CACHE = {}


def get(vid):
    if vid not in _CACHE:
        if vid not in TITLES:
            raise KeyError('unknown variant %s (known: %s)' % (vid, ', '.join(VARIANT_IDS)))
        _CACHE[vid] = Variant(vid)
    return _CACHE[vid]
