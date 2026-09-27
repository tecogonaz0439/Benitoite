# 構文

- 状態: 草稿
- 関連ADR: [0004](../decisions/0004-surface-syntax-skeleton.md), [0005](../decisions/0005-direct-style-effects.md), [0007](../decisions/0007-constructors-and-list.md), [0008](../decisions/0008-effect-variables.md), [0013](../decisions/0013-evaluation-order-and-tail-calls.md), [0047](../decisions/0047-parenthesized-types-and-uses-binding.md), [0050](../decisions/0050-pipe-with-parenthesized-rhs.md), [0052](../decisions/0052-file-modules-and-named-import.md), [0053](../decisions/0053-private-by-default-with-pub.md), [0055](../decisions/0055-top-level-functions-and-types-only.md), [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0057](../decisions/0057-record-declaration-construction-update.md), [0058](../decisions/0058-string-interpolation-of-base-types.md), [0060](../decisions/0060-trait-and-impl-syntax.md), [0061](../decisions/0061-trait-coherence-orphan-and-overlap.md), [0066](../decisions/0066-explicit-laziness-pure-body.md), [0067](../decisions/0067-with-resource-scope.md), [0071](../decisions/0071-permission-declaration-and-runtime-denial.md)
- 未決事項: [OPEN-011](../open-issues.md#open-011), [OPEN-012](../open-issues.md#open-012), [OPEN-029](../open-issues.md#open-029)
- 移行元: [設計メモ](../sources/fp-language-design.md) 2.3, 23.1

## 目的と範囲

字句の並びから、プログラム・宣言・式・パターン・型の構造を組み立てる規則を定める。対象は、文法（EBNF）、演算子の優先順位と結合性、ブロックと文、ドット記法とパイプ、部分適用のプレースホルダである。

構文が表す意味（型付けと評価）は、それぞれの章で定める。本章が定めるのは、正しく構造を組み立てられる字句の並びと、構文上の糖衣をどう展開するかだけである。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲と、v1 で加える構文（モジュールと import、レコード、文字列補間、型クラス、`?`、明示遅延、リソーススコープ、権限の宣言）を定める。v1 の構文は、見出しに「（v1）」を付けた節に書く。本章に含めない構文は、節末の「最小実行版に含めない構文」に挙げる。

## 前提

字句は[字句構造](01-01-lexical.md)に従う。文法の中の `NL` は、字句構造の「改行による区切り」で置かれる改行字句 NEWLINE を表す。

表層構文の骨格は [ADR 0004](../decisions/0004-surface-syntax-skeleton.md) と [ADR 0005](../decisions/0005-direct-style-effects.md) に従う。骨格の四点（ドット記法、シグネチャ、改行による区切り、括弧による適用）とエフェクトの書き方は【決定】である。最小実行版のそれ以外の具体的な文法は【方針】である。v1 で加える構文のうち、ADR 0052〜0071 で決めた書き方は【決定】とし、その節で ADR を示す。どれも、構文ごとの LLM の生成精度の測定（[OPEN-012](../open-issues.md#open-012)）の結果によって見直すことがある。

## 仕様

### EBNF の表記

文法は次の表記で書く。

| 表記 | 意味 |
|---|---|
| `"fn"` | その字句 |
| `A B` | A の後に B が続く |
| `A \| B` | A または B |
| `[ A ]` | A を省略できる |
| `{ A }` | A の 0 回以上の繰り返し |
| `( A )` | まとめ |
| `LowerIdent`・`UpperIdent`・`IntLit`・`FloatLit`・`StringLit`・`CharLit` | [字句構造](01-01-lexical.md)の小文字識別子・大文字識別子・整数リテラル・浮動小数リテラル・文字列リテラル・文字リテラル。`StringLit` は、文字列補間を含まない文字列リテラルである |
| `NL` | [字句構造](01-01-lexical.md)の改行字句（NEWLINE） |
| `StrStart`・`StrMid`・`StrEnd` | [字句構造](01-01-lexical.md)の、文字列補間を含む文字列リテラルを分けた字句（補間の開始・中間・終わり）。v1 |
| `(* … *)` | 文法の中の注釈。規則の一部ではない |
| `X = ... \| A` | v1 の節で使う。それまでに定めた `X` の選択肢をすべて残し、選択肢 `A` を加える |

v1 の節で `...` を含まずに書いた規則は、同じ名前の規則を置き換える。v1 の文法の全体は、後述の「v1 の文法の全体」にまとめる。

リスト状の構文には、次の二つの補助規則を使う。丸括弧・角括弧の中の要素はコンマで区切り、末尾のコンマを許す。波括弧の中の要素は改行で区切る。

```text
CommaList(X) = [ X { "," X } [ "," ] ] .
LineList(X)  = [ NL ] [ X { NL X } [ NL ] ] .
```

### 文法

【方針】最小実行版の文法は次のとおりである。v1 の文法は、この文法に v1 の各節の規則を加えたものであり、全体を後述の「v1 の文法の全体」に示す。

```text
Program     = LineList(TopItem) .
TopItem     = FnDecl | TypeDecl .

(* 関数の宣言 *)
FnDecl      = "fn" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              "->" Type [ Uses ] Block .
FnTypeParams = "[" FnTypeParam { "," FnTypeParam } [ "," ] "]" .
FnTypeParam = [ "effect" ] UpperIdent .
TypeParams  = "[" UpperIdent { "," UpperIdent } [ "," ] "]" .
Param       = LowerIdent ":" Type .
Uses        = "uses" UpperIdent { "," UpperIdent } .

(* 型の宣言 *)
TypeDecl    = "type" UpperIdent [ TypeParams ] "{" LineList(Variant) "}" .
Variant     = UpperIdent [ "(" CommaList(Type) ")" ] .

(* 型 *)
Type        = UpperIdent [ "[" Type { "," Type } [ "," ] "]" ]
            | "fn" "(" CommaList(Type) ")" "->" Type [ Uses ]
            | "(" Type ")" .

(* ブロックと文 *)
Block       = "{" LineList(Stmt) "}" .
Stmt        = LetStmt | Expr .
LetStmt     = "let" ( LowerIdent | "_" ) [ ":" Type ] "=" Expr .

(* 式 *)
Expr        = OrExpr { "|>" OrExpr } .
OrExpr      = AndExpr { "||" AndExpr } .
AndExpr     = CmpExpr { "&&" CmpExpr } .
CmpExpr     = AddExpr [ CmpOp AddExpr ] .
CmpOp       = "==" | "!=" | "<" | "<=" | ">" | ">=" .
AddExpr     = MulExpr { ( "+" | "-" ) MulExpr } .
MulExpr     = UnaryExpr { ( "*" | "/" | "%" ) UnaryExpr } .
UnaryExpr   = ( "-" | "!" ) UnaryExpr | CallExpr .
CallExpr    = Primary { "(" CommaList(Arg) ")" } .
Arg         = Expr | "_" .
Primary     = Literal
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "[" CommaList(Expr) "]"
            | Block
            | IfExpr
            | MatchExpr
            | Lambda .
Literal     = IntLit | FloatLit | StringLit | CharLit | "true" | "false" .
Name        = LowerIdent
            | UpperIdent
            | UpperIdent "." ( LowerIdent | UpperIdent ) .

IfExpr      = "if" Expr Block [ "else" ( Block | IfExpr ) ] .
MatchExpr   = "match" Expr "{" LineList(Arm) "}" .
Arm         = Pattern "=>" Expr .
Lambda      = "fn" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] Block .
LambdaParam = LowerIdent [ ":" Type ] .

(* パターン *)
Pattern     = "_"
            | LowerIdent
            | [ "-" ] IntLit
            | StringLit
            | CharLit
            | "true" | "false"
            | "(" ")"
            | UpperIdent [ "." UpperIdent ] [ "(" CommaList(Pattern) ")" ] .
```

`Uses` に書く `UpperIdent` は、エフェクトの名前か、関数の型パラメータの並びで `effect` を付けて宣言したエフェクト変数である（[ADR 0008](../decisions/0008-effect-variables.md)）。最小実行版で書けるエフェクトの名前は `IO` だけである（[エフェクト](01-07-effects.md)）。型の宣言の型パラメータには `effect` を付けられない。エフェクト変数の規則は[型システム](01-06-type-system.md)で定める。

【決定】型は括弧で囲める。括弧で囲んだ型は、囲まない型と同じ型を表す。`uses` は、その直前にある最も内側の関数の型に付き、`uses` の後のコンマ区切りの並びはできるだけ長く読む（最長一致、longest match）。この並びにエフェクトでない名前（`Int` など）が来たときは、構文エラーではなく名前解決の誤りとし、診断は関数の型を括弧で囲む書き方を修正案として示す（[ADR 0047](../decisions/0047-parenthesized-types-and-uses-binding.md)）。

```text
fn((fn() -> Unit uses IO), Int) -> Unit        // fn(fn() -> Unit uses IO, Int) -> Unit は誤り
fn f() -> (fn() -> Int uses IO) uses IO { ... } // 戻り値の型が uses を持つ関数の型のとき
```

1 行目の括弧を外すと、`Int` を `uses` の並びの一部として読む。2 行目の戻り値の型の括弧を外すと、`fn f() -> fn() -> Int uses IO { ... }` の `uses IO` は戻り値の型（内側の関数の型）に付き、`f` 自身は純粋な関数になる。

### プログラムと宣言

【方針】最小実行版のプログラムは一つのソースファイルであり、トップレベルには関数の宣言と型の宣言だけを置ける。v1 で複数のファイルからなるプログラムを書く構文は、後述の「モジュールと import（v1）」で定める。トップレベルに式や `let` を置くことはできない。プログラムの実行を始める関数（エントリポイント）は[評価意味論](01-08-evaluation.md)で定める。名前の有効範囲（トップレベルの宣言どうしの参照、局所束縛のシャドーイングなど）は[名前・スコープ・モジュール](01-03-names-modules.md)で定める。

【決定】トップレベルの関数の宣言は、すべての引数の型と戻り値の型を書かなければならない（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)）。戻り値がない関数も `-> Unit` と書く。外部に作用する関数は、戻り値の型の後に `uses` とエフェクトの名前を書く。`uses` を書かない関数は純粋である（[ADR 0005](../decisions/0005-direct-style-effects.md)）。

```text
fn double(x: Int) -> Int {
  x * 2
}

fn greet(name: String) -> Unit uses IO {
  let message = "Hello, " + name
  Console.println(message)
}
```

本章の例で使うライブラリの名前（`Console.println` など）は構文を示すための仮のものであり、実際の API は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

型パラメータを持つ関数は、関数名の後の `[ ]` に型パラメータを並べる。型パラメータは大文字識別子で書く。エフェクト変数は、同じ並びに `effect` を付けて書く（[型システム](01-06-type-system.md)）。

```text
fn getOr[A](opt: Option[A], default: A) -> A {
  match opt {
    Some(x) => x
    None => default
  }
}
```

型の宣言は、データ構成子を一行に一つずつ並べる。データ構成子の引数は位置で区別し、名前を付けない。名前付きのフィールドは v1 のレコードで扱う。

```text
type Shape {
  Circle(Float)
  Rect(Float, Float)
}

type Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
}
```

引数を持たない構成子は、括弧を付けずに宣言する。宣言の中で空の括弧を付けた構成子（`Leaf()`）は誤りとする（[代数的データ型とパターンマッチ](01-05-data-types.md)）。

### ブロックと文

【方針】ブロックは、波括弧で囲んだ文の並びである。文は `let` による束縛か、式である。文は改行で区切る。

- ブロックの最後の文が式であれば、その式の値がブロックの値になる。最後の文が `let` であるか、ブロックが空であれば、ブロックの値は Unit である。
- 最後の文以外の位置に置いた式（式文）は、Unit 型でなければならない。これは型検査で検査する（[型システム](01-06-type-system.md)）。値を捨てるときは `let _ = 式` と書く。

式文を Unit 型に限るのは、計算した値を気付かずに捨てる誤りと、改行の位置の誤り（[字句構造](01-01-lexical.md)の「改行による区切り」）を、実行前に検出するためである。

`let` は、名前か `_` に式の値を束縛する。型注釈は省略でき、省略すると推論する。`let` の左辺にパターンは書けない。パターンで分解するときは `match` を使う。

### 条件分岐

【方針】`if` の条件は括弧で囲まない。各分岐はブロックである。`else if` を連ねて分岐を増やせる。

`else` を省略した `if` は、Unit 型の式である。`else` のない `if` の分岐は Unit 型でなければならない。これも型検査で検査する。

### パターンマッチ

【方針】`match` は、対象の式と、改行で区切った分岐の並びからなる。分岐は「パターン `=>` 式」の形であり、分岐の本体を複数の文にするときはブロックを書く。

```text
match shape {
  Shape.Circle(r) => 3.14159 * r * r
  Shape.Rect(w, h) => {
    let area = w * h
    area
  }
}
```

パターンの中の小文字識別子は新しい変数の束縛であり、大文字識別子はデータ構成子との照合である。データ構成子は、式の中と同じく型名で修飾して書く（[ADR 0007](../decisions/0007-constructors-and-list.md)）。浮動小数のリテラルはパターンに書けない。パターンの意味と、網羅性・到達不能の検査は[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

### ラムダ

【方針】ラムダ（無名関数）は、`fn` の後に引数の並びとブロックを書く。関数の宣言と違い、引数の型と戻り値の型は省略でき、省略すると推論する。`uses` は、戻り値の型を書いたときだけ、その後に書ける。`uses` を書かなければ、エフェクトを本体から推論する（[型システム](01-06-type-system.md)）。

ラムダの引数には `_` を書けない（`fn(_, x) { x }` は構文エラー）。使わない引数には、`_unused` のように `_` で始まる名前を付ける（[字句構造](01-01-lexical.md)）。

```text
fn(x) { x + 1 }
fn(x: Int) -> Int { x + 1 }
fn(line: String) -> Unit uses IO { Console.println(line) }
```

### 演算子の優先順位と結合性

【方針】演算子の優先順位と結合性は次のとおりである。上の行ほど優先順位が低い。

| 優先順位 | 演算子 | 結合性 |
|---|---|---|
| 1 | `\|>` | 左結合 |
| 2 | `\|\|` | 左結合 |
| 3 | `&&` | 左結合 |
| 4 | `==` `!=` `<` `<=` `>` `>=` | 結合しない |
| 5 | `+` `-` | 左結合 |
| 6 | `*` `/` `%` | 左結合 |
| 7 | 単項の `-` `!` | 前置 |
| 8 | 関数の呼び出し `f(...)`、v1 の `?` | 後置 |

v1 の `?`（後述の「`Err` を呼び出し元へ返す構文（v1）」）は、関数の呼び出しと同じ順位の後置の演算子である。`f(x)?` は `f(x)` に、`f(x)?(y)` は `f(x)?` の結果に `(y)` を適用する。`-f(x)?` は `-(f(x)?)` である。

比較演算子は結合しない。`a < b < c` は構文エラーであり、`a < b && b < c` と書くよう診断で示す。

各演算子の型と意味は、[基本型の意味論](01-04-types-basic.md)と[型システム](01-06-type-system.md)で定める。

### ドット記法

【決定】ドット `.` は、モジュールの修飾と、型名によるデータ構成子の修飾にだけ使う（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)、[ADR 0007](../decisions/0007-constructors-and-list.md)）。`.` の左には大文字識別子で書いたモジュール名か型名を、右にはそのモジュールが定める名前か、その型の構成子の名前を書く（`List.map`、`String.lines`、`Shape.Circle`）。prelude の `Option` と `Result` の構成子（`Some`・`None`・`Ok`・`Err`）は修飾せずに書く（[代数的データ型とパターンマッチ](01-05-data-types.md)）。

最小実行版で修飾に使えるモジュールは、処理系に組み込んだモジュールだけである。利用者が定義するモジュールと import は v1 で加える（[名前・スコープ・モジュール](01-03-names-modules.md)）。

値に続けてドットを書く形（`xs.map(f)`、`s.length`）は構文エラーである。このとき、診断は `|>` を使った書き方（`xs |> List.map(f)`）を修正案として示さなければならない。v1 のレコードのフィールドも、ドットではなく型のモジュールの関数で取り出す（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。

### パイプ

【決定】パイプ `x |> e` は、左の値を右の関数に渡す糖衣である（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)）。

【方針】`x |> e` は、右辺 `e` の形によって次のように展開する。

1. `e` が関数の呼び出し `f(a1, ..., an)` であり、その直接の引数 `a1, ..., an` のどれもプレースホルダ `_` でなければ、`x` を第 1 引数に加えた `f(x, a1, ..., an)` に展開する。引数の中に入れ子になった呼び出しのプレースホルダは数えない（`x |> f(g(_))` は `f(x, g(_))` に展開する）。`e` が呼び出しを重ねた形（`g(a)(b)`）であれば、最も外側（最後）の呼び出しに加える。
2. それ以外であれば、`e` を関数として `x` に適用した `e(x)` に展開する。`e` の直接の引数にプレースホルダを含む呼び出しの場合もこの規則による。次節の展開によって `e` は関数になるので、`x` はプレースホルダの位置に入る。

【決定】右辺 `e` が括弧で囲んだ式であれば、中身によらず規則 2 により `e(x)` に展開する（[ADR 0050](../decisions/0050-pipe-with-parenthesized-rhs.md)）。`x |> (f(a))` は `(f(a))(x)` になる。関数を返す呼び出しの結果に `x` を渡すときは、このように右辺を括弧で囲む。

```text
lines |> List.filter(nonEmpty)    // List.filter(lines, nonEmpty)
lines |> List.length              // List.length(lines)
x |> clamp(0, _, 100)             // clamp(0, x, 100)
x |> fn(v) { v * 2 }              // (fn(v) { v * 2 })(x)
x |> (makeHandler(config))        // (makeHandler(config))(x)
```

【方針】v1 では、右辺 `e` の最も外側が後置の `?` を付けた式 `e'?` であれば、`?` を外した `x |> e'` を規則 1・2 と括弧の規則で展開し、その結果に `?` を付け直す。この規則は、`e'` の中のプレースホルダの展開より先に当てる。`?` が二つ以上並ぶときは、すべてを外して展開し、同じ数だけ付け直す。この規則は `?` の方針（[OPEN-029](../open-issues.md#open-029)）に従う。

```text
x |> f(a)?          // f(x, a)?
x |> g(_, b)?       // g(x, b)?
x |> f?             // f(x)?
x |> f? |> g        // g(f(x)?)
```

`x` と `e` をどの順に評価するかは[評価意味論](01-08-evaluation.md)で定める（[ADR 0013](../decisions/0013-evaluation-order-and-tail-calls.md)）。

### 部分適用のプレースホルダ

【決定】部分適用は、プレースホルダ `_` を使って明示する（[ADR 0004](../decisions/0004-surface-syntax-skeleton.md)）。関数はカリー化しないので、引数が足りない呼び出しは部分適用にならず、型検査の誤りになる。

【方針】関数の呼び出し `f(a1, ..., an)` の引数のうち、`_` そのものであるものをプレースホルダと呼ぶ。プレースホルダを一つ以上含む呼び出しは、プレースホルダを左から順に新しい引数に置き換えたラムダに展開する。展開で使う引数の名前は、ソースのどこにも現れない新しい名前である。下の例の `p1`・`p2` は説明のための表記であり、`f(_, p1)` のようにソースに同じ名前があっても、その名前と取り違えることはない。

```text
clamp(0, _, 100)    // fn(p1) { clamp(0, p1, 100) }
between(_, lo, _)   // fn(p1, p2) { between(p1, lo, p2) }
```

- プレースホルダが属するのは、それを直接の引数とする呼び出しだけである。`f(g(_))` は `f(fn(p1) { g(p1) })` と展開する。
- 呼び出しの直接の引数以外の位置（`_ + 1` など）に `_` を書くと、構文エラーとする。
- 展開後のラムダの本体には、呼び出される関数 `f` と、プレースホルダでない引数の式がそのまま入る。これらの式を評価する時期は、展開後のラムダに従う（[評価意味論](01-08-evaluation.md)）。

### モジュールと import（v1）

【決定】v1 では、一つのソースファイルを一つのモジュールとする。ほかのモジュールは `import` の宣言で取り込み、取り込む側がモジュールに大文字の名前を付ける（[ADR 0052](../decisions/0052-file-modules-and-named-import.md)）。トップレベルの関数と型の宣言に `pub` を付けると、取り込んだ側から使える（[ADR 0053](../decisions/0053-private-by-default-with-pub.md)）。トップレベルには値の定義を置けない（[ADR 0055](../decisions/0055-top-level-functions-and-types-only.md)）。v1 のトップレベルに置けるのは、import の宣言、`permissions` の宣言、関数の宣言、型の宣言、レコードの宣言、型クラスの宣言、実装の宣言である。

v1 では、文法の次の規則を改める。ほかの規則は最小実行版と同じである。

```text
TopItem     = ImportDecl | [ "pub" ] FnDecl | [ "pub" ] TypeDecl .
ImportDecl  = "import" UpperIdent "from" StringLit .

Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "fn" "(" CommaList(Type) ")" "->" Type [ Uses ]
            | "(" Type ")" .
QualUpper   = UpperIdent [ "." UpperIdent ] .
Name        = LowerIdent
            | UpperIdent
            | UpperIdent "." ( LowerIdent | UpperIdent )
            | UpperIdent "." UpperIdent "." UpperIdent .
Pattern     = ...
            | UpperIdent [ "." UpperIdent [ "." UpperIdent ] ] [ "(" CommaList(Pattern) ")" ] .
```

- import の宣言は、ファイルの中で、ほかのすべてのトップレベルの宣言（`permissions` の宣言を含む）より前に置く。ほかの宣言の後に import の宣言を書くと、構文エラーとする。
- `from` の後の文字列リテラルは、取り込むファイルのパスである。エスケープと文字列補間を含まない文字列リテラルでなければならない。パスの形と探し方は[名前・スコープ・モジュール](01-03-names-modules.md)で定める。例の拡張子 `.bnt` は仮のものである（[OPEN-011](../open-issues.md#open-011)）。
- `QualUpper` の `M.T` は、取り込んだモジュール `M` の型 `T` を表す。三つの大文字の名前を並べた `M.T.C` は、取り込んだモジュール `M` の型 `T` の構成子 `C` を表す。

```text
import Geo from "./geo.bnt"

pub fn area(s: Geo.Shape) -> Float {
  match s {
    Geo.Shape.Circle(r) => Geo.pi() * r * r
    Geo.Shape.Rect(w, h) => w * h
  }
}
```

### レコード（v1）

【決定】レコードは `record` で宣言し、フィールドを「名前: 型」の形で一行に一つずつ並べる。値は名前付きの引数で作り、一部のフィールドを変えた値は `..` で作る（[ADR 0057](../decisions/0057-record-declaration-construction-update.md)）。フィールドの値は、型のモジュールの関数で取り出す（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。

v1 では、文法に次の規則を加える。

```text
TopItem     = ... | [ "pub" ] RecordDecl .
RecordDecl  = "record" UpperIdent [ TypeParams ] "{" LineList(Field) "}" .
Field       = LowerIdent ":" Type .

Primary     = ... | RecordExpr .
RecordExpr  = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")" .
FieldArg    = LowerIdent ":" Expr .

Pattern     = ... | QualUpper "(" FieldPat { "," FieldPat } [ "," ".." ] [ "," ] ")" .
FieldPat    = LowerIdent ":" Pattern .

Name        = ... | UpperIdent "." UpperIdent "." LowerIdent .
```

```text
record Person {
  name: String
  age: Int
}

fn birthday(p: Person) -> Person {
  Person(..p, age: Person.age(p) + 1)
}

fn greeting(p: Person) -> String {
  match p {
    Person(name: n, age: 0) => "Welcome, ${n}"
    Person(name: n, ..) => "Hello, ${n}"
  }
}
```

- 構文解析は、`QualUpper` の直後の `(` の次が「小文字の名前 `:`」か `..` であれば、レコードの構築（パターンではレコードのパターン）として読む。そうでなければ、構成子の呼び出しと構成子のパターンとして読む。
- 【方針】一部のフィールドを変えた値を作るときは、変えるフィールドを一つ以上書かなければならない。`Person(..p)` のように一つも書かない形は構文エラーとし、診断は `p` をそのまま使う書き方を修正案として示す。
- 【方針】レコードのパターンにも、フィールドを一つ以上書かなければならない。`Person(..)` のように一つも書かない形は構文エラーとし、診断はワイルドカード `_` を使う書き方を修正案として示す。
- レコードの構築の中には、部分適用のプレースホルダ `_` を書けない。
- `M.T.f`（三つ目が小文字の名前）は、取り込んだモジュール `M` のレコード `T` のフィールド `f` を取り出す関数である。
- 値に続けてドットを書く形（`p.name`）は、最小実行版と同じく構文エラーとする。診断は `Person.name(p)` と `p |> Person.name` を修正案として示す（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。

### 文字列補間（v1）

【決定】文字列リテラルの中の `${e}` は、式 `e` の値を文字列にして埋め込む（[ADR 0058](../decisions/0058-string-interpolation-of-base-types.md)）。字句の規則は[字句構造](01-01-lexical.md)で、`e` の型は[型システム](01-06-type-system.md)で定める。

v1 では、文法に次の規則を加える。文字列補間を含む文字列リテラルは、[字句構造](01-01-lexical.md)の規則で補間の開始・中間・終わりの字句と式の字句に分かれ、構文解析はそれを次の規則で読む。

```text
Primary     = ... | InterpString .
InterpString = StrStart Expr { StrMid Expr } StrEnd .
```

パターン、import の宣言のパス、権限の宣言には `StringLit` だけを書けるので、文字列補間は書けない。

```text
Console.println("${name} is ${age} years old")
```

### 型クラス（v1）

【決定】型クラスは `trait` で宣言し、`impl` で実装する。関数の型パラメータには `[T: Show]` の形で制約を付ける（[ADR 0060](../decisions/0060-trait-and-impl-syntax.md)）。型クラスの規則は[型システム](01-06-type-system.md)で定める。

v1 では、文法に次の規則を加え、`FnTypeParam` を改める。

```text
TopItem     = ... | [ "pub" ] TraitDecl | ImplDecl .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl "]" "{" LineList(MethodSig) "}" .
MethodSig   = "fn" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] .
ImplDecl    = "impl" [ FnTypeParams ] QualUpper "[" Type "]" "{" LineList(FnDecl) "}" .

FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" QualUpper { "+" QualUpper } ] .
TypeParamDecl = UpperIdent [ "[" "_" { "," "_" } "]" ] .
```

- `F[_]` は、型構成子を表す型パラメータを宣言する。`_` の個数が、型構成子がとる引数の個数である。
- `impl` の中の関数の宣言には、`pub` を付けない。`impl` にも `pub` を付けない。
- 【方針】実装は、プログラム全体で有効である。どのモジュールで型クラスの制約を解くときも、プログラムを構成するすべてのモジュールの実装から探す。孤立した実装と重なる実装を誤りとするので、使える実装は一つに決まる（[ADR 0061](../decisions/0061-trait-coherence-orphan-and-overlap.md)、[型システム](01-06-type-system.md)）。
- `M.C.m`（三つ目が小文字の名前）は、取り込んだモジュール `M` の型クラス `C` のメソッド `m` を表す。
- `impl Person { ... }` のように、型クラスの名前を書かない `impl` は構文エラーとする。診断は、トップレベルの関数として書く方法を修正案として示す（[ADR 0060](../decisions/0060-trait-and-impl-syntax.md)）。

### `Err` を呼び出し元へ返す構文（v1）

【方針】v1 では、後置の `?` を設ける。意味と、パイプの右辺の末尾に書いたときの扱いは[エラー処理](01-09-errors.md)で定める。この方針は [OPEN-029](../open-issues.md#open-029) で確定する。文法の規則は次のように改める。

```text
CallExpr    = Primary { "(" CommaList(Arg) ")" | "?" } .
```

### 明示遅延（v1）

【決定】`lazy { ... }` は、ブロックを評価せずに `Lazy[T]` の値を作る（[ADR 0066](../decisions/0066-explicit-laziness-pure-body.md)）。意味は[評価意味論](01-08-evaluation.md)で定める。

```text
Primary     = ... | "lazy" Block .
```

### リソーススコープ（v1）

【決定】`with x = e { ... }` は、`e` の値のリソースを `x` に束縛してブロックを評価し、ブロックを抜けるときに解放する（[ADR 0067](../decisions/0067-with-resource-scope.md)）。意味は[リソース管理](01-10-resources.md)で定める。

```text
Primary     = ... | WithExpr .
WithExpr    = "with" WithBind { "," WithBind } Block .
WithBind    = LowerIdent "=" Expr .
```

`with` の並びのコンマの後では改行してよい（コンマの直後の改行は、[字句構造](01-01-lexical.md)の「改行による区切り」の規則 2 で空白として扱う）。`with` の後の `e` の直後の `{` は、`if` の条件の直後の `{` と同じく、`with` のブロックの始まりとして読む。

### 権限の宣言（v1）

【決定】実行を始めるモジュールには、`permissions` の宣言を書ける（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)）。意味と書ける権限は[エフェクト](01-07-effects.md)で定める。

```text
TopItem     = ... | PermDecl .
PermDecl    = "permissions" "{" LineList(Perm) "}" .
Perm        = LowerIdent [ StringLit ] .
```

`permissions` の宣言は、import の宣言の後、ほかのトップレベルの宣言の前に置く。`permissions` をキーワードにする。

【方針】`Perm` の規則は次のとおりである。

- 小文字の名前は、`read`・`write`・`run`・`shell`・`env`・`exit` のどれかでなければならない。
- `read`・`write`・`run`・`env` には文字列リテラルを一つ書かなければならない。`shell` と `exit` には文字列リテラルを書けない。
- 文字列リテラルは、エスケープと文字列補間を含んではならない。
- 同じ名前と同じ文字列の権限を二度書くと誤りとする。

### v1 の文法の全体

【方針】v1 の文法の全体は次のとおりである。最小実行版の文法（前述の「文法」）に、v1 の各節で加えた規則と置き換えた規則を反映したものであり、各規則の意味と、決定の確度は各節に従う。トップレベルの宣言の順序（import の宣言、`permissions` の宣言、ほかの宣言の順）も、この文法で表す。

```text
(* プログラム *)
Program     = [ NL ] [ Items [ NL ] ] .
Items       = ImportDecl [ NL Items ]
            | PermDecl [ NL Decls ]
            | Decls .
Decls       = Decl { NL Decl } .
Decl        = [ "pub" ] FnDecl
            | [ "pub" ] TypeDecl
            | [ "pub" ] RecordDecl
            | [ "pub" ] TraitDecl
            | ImplDecl .

(* import と権限の宣言 *)
ImportDecl  = "import" UpperIdent "from" StringLit .
PermDecl    = "permissions" "{" LineList(Perm) "}" .
Perm        = LowerIdent [ StringLit ] .

(* 関数の宣言 *)
FnDecl      = "fn" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              "->" Type [ Uses ] Block .
FnTypeParams = "[" FnTypeParam { "," FnTypeParam } [ "," ] "]" .
FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" QualUpper { "+" QualUpper } ] .
TypeParamDecl = UpperIdent [ "[" "_" { "," "_" } "]" ] .
Param       = LowerIdent ":" Type .
Uses        = "uses" UpperIdent { "," UpperIdent } .

(* 型・レコード・型クラスの宣言 *)
TypeDecl    = "type" UpperIdent [ TypeParams ] "{" LineList(Variant) "}" .
TypeParams  = "[" UpperIdent { "," UpperIdent } [ "," ] "]" .
Variant     = UpperIdent [ "(" CommaList(Type) ")" ] .
RecordDecl  = "record" UpperIdent [ TypeParams ] "{" LineList(Field) "}" .
Field       = LowerIdent ":" Type .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl "]" "{" LineList(MethodSig) "}" .
MethodSig   = "fn" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] .
ImplDecl    = "impl" [ FnTypeParams ] QualUpper "[" Type "]" "{" LineList(FnDecl) "}" .

(* 型 *)
Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "fn" "(" CommaList(Type) ")" "->" Type [ Uses ]
            | "(" Type ")" .
QualUpper   = UpperIdent [ "." UpperIdent ] .

(* ブロックと文 *)
Block       = "{" LineList(Stmt) "}" .
Stmt        = LetStmt | Expr .
LetStmt     = "let" ( LowerIdent | "_" ) [ ":" Type ] "=" Expr .

(* 式 *)
Expr        = OrExpr { "|>" OrExpr } .
OrExpr      = AndExpr { "||" AndExpr } .
AndExpr     = CmpExpr { "&&" CmpExpr } .
CmpExpr     = AddExpr [ CmpOp AddExpr ] .
CmpOp       = "==" | "!=" | "<" | "<=" | ">" | ">=" .
AddExpr     = MulExpr { ( "+" | "-" ) MulExpr } .
MulExpr     = UnaryExpr { ( "*" | "/" | "%" ) UnaryExpr } .
UnaryExpr   = ( "-" | "!" ) UnaryExpr | CallExpr .
CallExpr    = Primary { "(" CommaList(Arg) ")" | "?" } .
Arg         = Expr | "_" .
Primary     = Literal
            | InterpString
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "[" CommaList(Expr) "]"
            | Block
            | IfExpr
            | MatchExpr
            | Lambda
            | RecordExpr
            | "lazy" Block
            | WithExpr .
Literal     = IntLit | FloatLit | StringLit | CharLit | "true" | "false" .
InterpString = StrStart Expr { StrMid Expr } StrEnd .
Name        = LowerIdent
            | UpperIdent
            | UpperIdent "." ( LowerIdent | UpperIdent )
            | UpperIdent "." UpperIdent "." ( LowerIdent | UpperIdent ) .
RecordExpr  = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")" .
FieldArg    = LowerIdent ":" Expr .
IfExpr      = "if" Expr Block [ "else" ( Block | IfExpr ) ] .
MatchExpr   = "match" Expr "{" LineList(Arm) "}" .
Arm         = Pattern "=>" Expr .
Lambda      = "fn" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] Block .
LambdaParam = LowerIdent [ ":" Type ] .
WithExpr    = "with" WithBind { "," WithBind } Block .
WithBind    = LowerIdent "=" Expr .

(* パターン *)
Pattern     = "_"
            | LowerIdent
            | [ "-" ] IntLit
            | StringLit
            | CharLit
            | "true" | "false"
            | "(" ")"
            | UpperIdent [ "." UpperIdent [ "." UpperIdent ] ] [ "(" CommaList(Pattern) ")" ]
            | QualUpper "(" FieldPat { "," FieldPat } [ "," ".." ] [ "," ] ")" .
FieldPat    = LowerIdent ":" Pattern .
```

この文法だけでは決まらない規則は、次のとおりである。いずれも、この文法で読める並びのうちの一部を誤りとするか、読み方を一つに決めるものである。

| 規則 | 定める箇所 |
|---|---|
| 字句の分け方、キーワードと予約語、`NL` を置く位置 | [字句構造](01-01-lexical.md) |
| `uses` の後の並びを最長一致で読むこと | 本章の「文法」の後の【決定】（[ADR 0047](../decisions/0047-parenthesized-types-and-uses-binding.md)） |
| `QualUpper` の直後の `(` の次の字句で、レコードの構築・パターンと、構成子の呼び出し・パターンを見分けること | 本章の「レコード（v1）」 |
| `with` と `if` の条件の直後の `{` を、ブロックの始まりとして読むこと | 本章の「リソーススコープ（v1）」 |
| import の宣言のパスと、権限の宣言の文字列に、エスケープを書けないこと | 本章の「モジュールと import（v1）」「権限の宣言（v1）」 |
| 権限の名前、文字列の有無、同じ権限の重複 | 本章の「権限の宣言（v1）」 |
| `permissions` の宣言を、実行を始めるモジュールにだけ書けること | [エフェクト](01-07-effects.md)の「権限の宣言（v1）」 |
| 型クラスの名前を書かない `impl` への診断 | 本章の「型クラス（v1）」 |
| パイプとプレースホルダと `?` の展開 | 本章の「パイプ」「部分適用のプレースホルダ」、[コア計算と脱糖](01-12-core-calculus.md) |

### 最小実行版に含めない構文

次の構文は最小実行版に含めない。v1 以降で、それぞれの機能を設計するときに本章へ加える。

| 構文 | 加える時期 | 関連する章・未決事項 |
|---|---|---|
| パターンのガード、or パターン、リストのパターン | 未定 | [代数的データ型とパターンマッチ](01-05-data-types.md) |
| タプル | 未定 | [代数的データ型とパターンマッチ](01-05-data-types.md) |


### 例

最小実行版の構文で書いたプログラムの例を示す。ライブラリの名前は仮のものである。

```text
type Shape {
  Circle(Float)
  Rect(Float, Float)
}

fn area(s: Shape) -> Float {
  match s {
    Shape.Circle(r) => 3.14159 * r * r
    Shape.Rect(w, h) => w * h
  }
}

fn totalArea(shapes: List[Shape]) -> Float {
  shapes
    |> List.map(area)
    |> List.fold(0.0, fn(acc, a) { acc + a })
}

fn main() -> Unit uses IO {
  let shapes = [Shape.Circle(1.0), Shape.Rect(2.0, 3.0)]
  Console.println(Float.toString(totalArea(shapes)))
}
```

## 未決事項

- [OPEN-029](../open-issues.md#open-029): エラーを呼び出し元へ伝える構文（方針は `?`）
- [OPEN-011](../open-issues.md#open-011): 言語の正式名称（例の拡張子 `.bnt` は仮のもの）
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度
