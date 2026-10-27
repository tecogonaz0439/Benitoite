# 構文

## 目的と範囲

字句の並びから、プログラム・宣言・式・パターン・型の構造を組み立てる規則を定める。対象は、文法（EBNF）、演算子の優先順位と結合性、ブロックと文、ドット記法とパイプ、部分適用のプレースホルダである。

構文が表す意味（型付けと評価）は、それぞれの章で定める。本章が定めるのは、正しく構造を組み立てられる字句の並びと、構文上の糖衣をどう展開するかだけである。

本章は、初回リリース版の構文を定める。基本の文法を「文法」の節に示し、そこに加える構文（モジュールと import、レコード、文字列補間、型クラス、`try`、明示遅延、リソーススコープ、エフェクトの宣言とハンドラ、属性、パターンの拡張、定数、型の別名、ドキュメントコメント）を、見出しに「（初回リリース版）」を付けた節に書く。全体の文法は「初回リリース版の文法の全体」にまとめる。本章で定めない構文は、初回リリース版に含めない（後述の「初回リリース版に含めない構文」）。

## 前提

字句は[字句構造](01-01-lexical.md)に従う。文法の中の `NL` は、字句構造の「改行による区切り」で置かれる改行字句 NEWLINE を表す。

表層構文の骨格の四点は【決定】である。ドットはモジュールと型名による修飾に限り、値に続くドットを認めない。トップレベルの関数は型シグネチャを必ず書く。文は改行で区切る。関数は `f(x: x, y: y)` の形で適用し、カリー化しない。外部に作用する処理を直接形式で書き、関数の型に `uses` でエフェクトを書くことも【決定】である。ブロックを `end` と構文の名前で閉じる形、`lambda`、`if … then`、演算子の書き方、戻り値の型の `->`、`bind` と `shadow`、`data`、`match … with` も【決定】である。基本の文法のそれ以外の具体的な規則は【方針】である。見出しに「（初回リリース版）」を付けた節の書き方は、各節に付けた確度に従う。

## 仕様

### EBNF の表記

文法は次の表記で書く。

| 表記 | 意味 |
|---|---|
| `"function"` | その字句 |
| `A B` | A の後に B が続く |
| `A \| B` | A または B |
| `[ A ]` | A を省略できる |
| `{ A }` | A の 0 回以上の繰り返し |
| `( A )` | まとめ |
| `LowerIdent`・`UpperIdent`・`IntLit`・`FloatLit`・`DecimalLit`・`StringLit`・`CharLit` | [字句構造](01-01-lexical.md)の小文字識別子・大文字識別子・整数リテラル・浮動小数リテラル・`Decimal` のリテラル・文字列リテラル・文字リテラル。`StringLit` は、文字列補間を含まない文字列リテラルである |
| `NL` | [字句構造](01-01-lexical.md)の改行字句（NEWLINE） |
| `StrStart`・`StrMid`・`StrEnd` | [字句構造](01-01-lexical.md)の、文字列補間を含む文字列リテラルを分けた字句（補間の開始・中間・終わり） |
| `(* … *)` | 文法の中の注釈。規則の一部ではない |
| `X = ... \| A` | 見出しに「（初回リリース版）」を付けた節で使う。それまでに定めた `X` の選択肢をすべて残し、選択肢 `A` を加える |

それらの節で `...` を含まずに書いた規則は、同じ名前の規則を置き換える。文法の全体は、後述の「初回リリース版の文法の全体」にまとめる。

`LowerIdent` と `UpperIdent` は、[字句構造](01-01-lexical.md)の 35 のキーワードを含まない。`die` はキーワードであり、`try` の失敗時の処置にだけ使える。名前や単独の式には使えない。`fn`・`pub`・`impl`・`mut` は通常の識別子であり、宣言やラムダのキーワードの省略形としては使えない。

リスト状の構文には、次の二つの補助規則を使う。丸括弧・角括弧の中の要素はコンマで区切り、末尾のコンマを許す。ブロックの中の要素（文、型の宣言の構成子、レコードのフィールドなど）は改行で区切る。

```text
CommaList(X) = [ X { "," X } [ "," ] ] .
LineList(X)  = [ NL ] [ X { NL X } [ NL ] ] .
```

### 文法

【方針】基本の文法は次のとおりである。初回リリース版の文法は、この文法に、見出しに「（初回リリース版）」を付けた各節の規則を加えたものであり、全体を後述の「初回リリース版の文法の全体」に示す。

```text
Program     = LineList(TopItem) .
TopItem     = FnDecl | DataDecl .

(* 関数の宣言 *)
FnDecl      = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              "->" Type [ Uses ] Body "end" "function" .
FnTypeParams = "[" FnTypeParam { "," FnTypeParam } [ "," ] "]" .
FnTypeParam = [ "effect" ] UpperIdent .
TypeParams  = "[" UpperIdent { "," UpperIdent } [ "," ] "]" .
Param       = LowerIdent ":" Type .
Uses        = "uses" UpperIdent { "," UpperIdent } .

(* 型の宣言 *)
DataDecl    = "data" UpperIdent [ TypeParams ] LineList(Variant) "end" "data" .
Variant     = UpperIdent [ "(" CommaList(Type) ")" ] .

(* 型 *)
Type        = UpperIdent [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(NamedType) ")" "->" Type [ Uses ]
            | "(" Type ")" .

(* 文の並びと文 *)
Body        = LineList(Stmt) .
Stmt        = BindStmt | Expr .
BindStmt    = ( "bind" | "shadow" ) ( LowerIdent | "_" ) [ ":" Type ] "<-" Expr .

(* 式 *)
Expr        = "return" Expr
            | PipeExpr .
PipeExpr    = OrExpr { "|>" OrExpr } .
OrExpr      = AndExpr { "or" AndExpr } .
AndExpr     = CmpExpr { "and" CmpExpr } .
CmpExpr     = AddExpr [ CmpOp AddExpr ] .
CmpOp       = "=" | "<>" | "<" | "<=" | ">" | ">=" .
AddExpr     = MulExpr { ( "+" | "-" ) MulExpr } .
MulExpr     = UnaryExpr { ( "*" | "/" | "div" | "mod" ) UnaryExpr } .
UnaryExpr   = ( "-" | "not" ) UnaryExpr | CallExpr .
CallExpr    = Primary { "(" CommaList(Arg) ")" } .
Arg         = [ LowerIdent ":" ] ( Expr | "_" ) .
NamedType   = LowerIdent ":" Type .
Primary     = Literal
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "[" CommaList(Expr) "]"
            | IfExpr
            | MatchExpr
            | Lambda
            | "block" Body "end" "block" .
Literal     = IntLit | FloatLit | StringLit | CharLit | "true" | "false" .
Name        = LowerIdent
            | UpperIdent
            | UpperIdent "." ( LowerIdent | UpperIdent ) .

IfExpr      = "if" Expr "then" Body { "else" "if" Expr "then" Body } [ "else" Body ] "end" "if" .
MatchExpr   = "match" Expr "with" [ NL ] Arm { NL Arm } [ NL ] "end" "match" .
Arm         = "case" Pattern "->" ArmBody .
ArmBody     = Stmt { NL Stmt } .
Lambda      = LambdaHeader ( Body "end" "lambda" | ShortBody ) .
LambdaHeader = "lambda" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] .
ShortBody   = Stmt . (* ラムダ全体を同じ物理行に収め、外側の区切りを残す *)
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

`Uses` に書く `UpperIdent` は、エフェクトの名前か、関数の型パラメータの並びで `effect` を付けて宣言したエフェクト変数である。エフェクトの名前は[エフェクト](01-07-effects.md)で定める。型の宣言の型パラメータには `effect` を付けられない。エフェクト変数の規則は[型システム](01-06-type-system.md)で定める。

【決定】型は括弧で囲める。括弧で囲んだ型は、囲まない型と同じ型を表す。`uses` は、その直前にある最も内側の関数の型に付き、`uses` の後のコンマ区切りの並びはできるだけ長く読む（最長一致、longest match）。この並びにエフェクトでない大文字の名前が来たときは、名前解決の誤りとする。関数型の次のパラメータの小文字名の前では `uses` の並びを閉じる。並びの 2 番目以降の名前の直後に `[` が続くとき（`List[Integer]` など、型引数を伴う名前）は、`uses` の並びに書けない形なので構文エラーとし、診断は同じく関数の型を括弧で囲む書き方を修正案として示す。

```text
function(action: (function() -> Unit uses Console.Write), count: Integer) -> Unit // 関数型の例
function f() -> (function() -> Integer uses Console.Write) uses Console.Write ... end function // 戻り値の型が uses を持つ関数の型のとき
```

1 行目は関数型のパラメータに名前を付け、内側の関数型を括弧で示した例である。2 行目の戻り値の型の括弧を外すと、`function f() -> function() -> Integer uses Console.Write ... end function` の `uses Console.Write` は戻り値の型（内側の関数の型）に付き、`f` 自身は純粋な関数になる。

### プログラムと宣言

【方針】基本の文法では、プログラムは一つのソースファイルであり、トップレベルには関数の宣言と型の宣言を置く。複数のファイルからなるプログラムを書く構文と、トップレベルに置けるほかの宣言は、後述の「モジュールと import（初回リリース版）」以降の節で定める。トップレベルに式や `bind`・`shadow` を置くことはできない。プログラムの実行を始める関数（エントリポイント）は[評価意味論](01-08-evaluation.md)で定める。名前の有効範囲（トップレベルの宣言どうしの参照、局所束縛のシャドーイングなど）は[名前・スコープ・モジュール](01-03-names-modules.md)で定める。

【決定】トップレベルの関数の宣言は、すべての引数の型と戻り値の型を書かなければならない。戻り値の型は、引数の並びの後の `->` に続けて書く。戻り値がない関数も `-> Unit` と書く。関数の型も、同じく `->` の後に戻り値の型を書く（`function(x: Integer) -> Integer`）。戻り値の型を `:` の後に書いた宣言（`function double(x: Integer): Integer`）は構文エラーとし、診断は `->` と書く修正案を示す。外部に作用する関数は、戻り値の型の後に `uses` とエフェクトの名前を書く。`uses` を書かない関数は純粋である。

【方針】C 系の波括弧の書き方 `fn f(x: Integer) -> Integer { … }` で書いた関数の宣言は構文エラーとし、診断は `function f(x: Integer) -> Integer … end function` の形を修正案として示す（ラムダの `fn(x) { … }` は「ラムダ」）。

【方針】関数の宣言の名前をモジュールの名前で修飾した形（`function List.map(…)`）は構文エラーとし、診断は修飾を取り除く修正案を示す。メソッドと操作の宣言の名前も同じである。関数が属するモジュールは、宣言を書いたファイルで決まる（後述の「モジュールと import（初回リリース版）」）。

```text
function double(x: Integer) -> Integer
  return x * 2
end function

function greet(name: String) -> Unit uses IO
  bind message <- "Hello, " + name
  Console.writeLine(message)
end function
```

`greet` の `uses IO` は、エフェクトを簡略に示した書き方である。`IO` はエフェクトの名前ではないので、実際のスクリプトでは `uses IO` は誤りになる（[エフェクト](01-07-effects.md)の「組み込みのエフェクト」）。`import Benitoite.Unofficial.IO.Console` を書き、`uses IO` を `uses Console.Write` と書く。本章の例のうち `uses IO` を書いたものは、どれも同じように書き換えて読む。

本章の例で使うライブラリの名前（`Console.writeLine` など）は構文を示すための仮のものであり、実際の API は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

型パラメータを持つ関数は、関数名の後の `[ ]` に型パラメータを並べる。型パラメータは大文字識別子で書く。エフェクト変数は、同じ並びに `effect` を付けて書く（[型システム](01-06-type-system.md)）。

```text
function getOr[A](opt: Option[A], default: A) -> A
  return match opt with
    case Option.Some(x) -> x
    case Option.None -> default
  end match
end function
```

【決定】代数的データ型の宣言（型の宣言）は、`data 名前` で始め、`end data` で閉じる。`type` は型の別名（後述の「型の別名（初回リリース版）」）だけに使う。型の宣言は、データ構成子を一行に一つずつ並べる。データ構成子の引数は位置で区別し、名前を付けない。名前付きのフィールドはレコードで扱う。

```text
data Shape
  Circle(Float)
  Rect(Float, Float)
end data

data Tree[T]
  Leaf
  Node(Tree[T], T, Tree[T])
end data
```

引数を持たない構成子は、括弧を付けずに宣言する。宣言の中で空の括弧を付けた構成子（`Leaf()`）は誤りとする（[代数的データ型とパターンマッチ](01-05-data-types.md)）。

### ブロックと文

【決定】ブロックは、改行で区切った文の並びである。関数の宣言とラムダの本体、`if` と `match` の分岐、`with` と `lazy` と `handle` と `block` の本体、`handle` の節がブロックである。ブロックを波括弧で囲まない。ブロックを持つ構文は、キーワードで始まり、`end` とその構文の名前（`end function`・`end lambda`・`end if`・`end match` など）で閉じる。文は `bind` か `shadow` による束縛（束縛の文）か、式である。`return` 直後の改行は、括弧や次行の字句によらず文の区切りになる（[字句構造](01-01-lexical.md)の「改行による区切り」）。

閉じる語が、閉じる構文と一致しないとき（`if` を `end match` で閉じたなど）は、構文エラーとし、診断は、どの構文を閉じるべきかを示す。LLM が波括弧でブロックを書いたとき（`{`・`}` は字句として受け付けない記号。[字句構造](01-01-lexical.md)の「演算子と区切り記号」）は、`end` と構文の名前で閉じる書き方を修正案として示す。

- ブロックの最後の文が式であれば、その式の値がブロックの値になる。最後の文が束縛の文であるか、ブロックが空であれば、ブロックの値は Unit である。
- 最後の文以外の位置に置いた式（式文）は、Unit 型でなければならない。これは型検査で検査する（[型システム](01-06-type-system.md)）。値を捨てるときは `bind _ <- 式` と書く。
- 関数の宣言とラムダの本体のブロックは、値を `return` で返す（後述の「`return`」）。本体のブロックの最後の文も式文として扱い、`return` でない式は Unit 型でなければならない。

式文を Unit 型に限るのは、計算した値を気付かずに捨てる誤りと、改行の位置の誤り（[字句構造](01-01-lexical.md)の「改行による区切り」）を、実行前に検出するためである。

【決定】束縛の文は、名前か `_` に、`<-` の右の式の値を束縛する。その位置で局所の名前として見えていない名前を束縛するときは `bind x <- e` と書き、見えている局所の名前を隠すときは `shadow x <- e` と書く。どちらを書けるかの規則は[名前・スコープ・モジュール](01-03-names-modules.md)の「シャドーイング」で定める。型注釈は `bind x: Integer <- e` の形で書け、省略すると推論する。束縛の文の左辺には、名前と `_` のほかに、必ず照合するパターンを書ける（後述の「組と `bind`・`shadow` のパターン（初回リリース版）」）。値によって分岐するときは `match` を使う。

【決定】`Benitoite.StringBuilder`・`Benitoite.ListBuilder`・`Benitoite.BytesBuilder`を明示importしたとき、`bind b: StringBuilder <- StringBuilder.new()`、`bind xs: ListBuilder[T] <- ListBuilder.new()`、`bind bs: BytesBuilder <- BytesBuilder.new()`は専用の局所宣言である。注釈と直接の `new()` の組を必須とし、通常の型推論による束縛にしない。最後の文に書いた場合もブロックの値はUnitであり、専用宣言自体はStateを持たない。専用操作の値化・穴・パイプは認めない。詳しい契約は[型システム](01-06-type-system.md#関数内の構築器)で定める。

文の頭に他の言語の束縛の書き方 `let x = e` を書いたときは、構文エラーとし、診断は `bind x <- e`（名前が局所の名前として見えていれば `shadow x <- e`）を修正案として示す。`let` はキーワードではない。

### ブロック式

【決定】`block 文の並び end block` は式であり、束縛の右辺・引数・リストの要素・分岐・return の右辺など、式を置ける位置に書ける。呼び出しと演算子の優先順位は他の primary と同じである。文の区切り、最後の式の値、空と末尾の束縛の Unit、途中の式文に Unit を要求する規則は「ブロックと文」に従う。局所の関数宣言は書けない。

```text
function greeting(loud: Boolean) -> String
  bind text <- block
    bind word <- "hello"
    if loud then word + "!" else word end if
  end block
  return text
end function
```

【決定】block の内部は新しい名前の範囲であり、外側の名前を読める。内側の名前は外から参照できず、見えている名前を隠すときは `shadow` を使う。構築器の捕捉境界にはならず、外側の構築器へ専用操作で追記できる。構築器を最後の値として持ち出すことと、lambda・lazy・ハンドラの節等へ捕捉することは、既存の E0464・E0465 で拒否する。

【決定】block 内の `return` と try の return 処置は、囲む最も内側の関数かラムダを作用先とする。block は return の作用先を作らず、lazy とガードの return・try の禁止も引き継ぐ。必ず抜ける block の後に同じ文列の文があれば E0439 で拒否する。理由: 文列を式位置でも評価できるようにし、制御の境界は既存の関数とラムダに揃えるためである。

【決定】block の型は最後の値の型、効果は中で評価する式の効果の和である。専用構築器の操作は同じ局所規則に従い、通常 Reference の State や他の効果は外に残る。閉じる語の不一致は E0213、未閉鎖は E0214、名前の位置の `block` は E0216 とし、開始位置も診断に示す。

### `return`

【決定】関数の宣言とラムダの本体は、`return 式` で値を返す。

- `return e` は、`e` を評価し、`return` を含む最も内側の関数の宣言かラムダの呼び出しを終えて、`e` の値を返す。本体の途中にも書ける。
- `return` の後には、必ず式を書き、`return` と同じ物理行で値を書き始めなければならない。直後の改行は括弧内でも文末になり、値の欠落を E0201 で報告する。主位置は改行、補足の位置は `return` とし、値を同じ物理行で書き始めるよう案内する。行末のコメント・空行・コメントだけの行を挟んでも同じである。値を書き始めた後は、通常の改行の規則で複数行に続けられる（`return x +` の次行の値、`return (` の括弧内、`return f(` の引数、`return if condition then` の次行の分岐など）。短いラムダの全体を一物理行に収める条件は変わらない。戻り値の型が Unit の関数から途中で抜けるときは `return ()` と書く。
- `return e` は式であり、どの型の式が書ける位置にも書ける（`match` の分岐の本体など）。`return` は右の式全体にかかる。`return x |> f` は `return f(x)` である。
- 本体の終わりに達したときは、`()` を返す。戻り値の型が Unit でない関数とラムダは、本体のどの道筋でも `return` で抜けなければならない。抜けない道筋があれば誤りとし、診断は `return` を書き足す箇所を示す。
- 必ず抜ける文（`return e`、両方の分岐が必ず抜ける `if`、すべての分岐が必ず抜ける `match` など。[型システム](01-06-type-system.md)で定める）の後に、同じブロックの文を続けると誤りとする。その文は実行されないからである。
- `lazy` のブロックと `match` のガードの中には、内側の `lambda … end lambda` の本体の中を除き、`return` を書けない。その中のプレースホルダを含む呼び出しの呼ぶ関数と引数は、この例外に当たらない（後述の「明示遅延（初回リリース版）」、[代数的データ型とパターンマッチ](01-05-data-types.md)の「パターンの拡張（初回リリース版）」）。

```text
function sign(x: Integer) -> Integer
  if x < 0 then
    return -1
  end if
  return match x = 0 with
    case true -> 0
    case false -> 1
  end match
end function
```

`if` と `match` の分岐は、最後の式の値を値とする。`return` を書くのは、関数の宣言とラムダの本体から抜けるときだけである。

### 条件分岐

【決定】`if` は `if 条件 then 文の並び else 文の並び end if` の形で書き、いつも `end if` で閉じる。条件は括弧で囲まない。

- 分岐には、一つの式も、改行で区切った複数の文も書ける（`return if x = 0 then 0 else 1 end if`）。
- `else` の直後の `if` は、同じ `if` の続きの分岐として読み、`end if` は一つで閉じる（`if a then … else if b then … else … end if`）。`else` の分岐に別の `if` を入れ子にしたいときは、`else` の後で改行してから `if` を書いても同じく続きとして読むので、入れ子の `if` を括弧で囲む（`else (if b then … end if)`）。
- `then` の直後と `else` の前後の改行は空白として扱う（[字句構造](01-01-lexical.md)の「改行による区切り」の規則 2・3）。

【方針】値や処理の選択には `match` を推奨する。条件成立時だけの処理や早期リターンには、`else` のない `if` を推奨する。`else`・`else if` は有効だが非推奨とし、使っても警告は出さない。理由: 選択を分岐の並びで示し、条件成立時だけの処理と区別できるためである。

`if` から `match` へ書き直すときは、条件の評価回数と順序、選ばれた分岐だけを評価すること、`return` の作用先を保つ。作用を持つ条件はガードに移さず、真偽値の `match` を入れ子にする。例えば次の形は、`first()` が偽のときだけ `second()` を評価する。

```text
match first() with
  case true -> onFirst()
  case false ->
    match second() with
      case true -> onSecond()
      case false -> onNeither()
    end match
end match
```

`else` を省略した `if` は、Unit 型の式である。`else` のない `if` の分岐は Unit 型でなければならない。これも型検査で検査する。

### パターンマッチ

【決定】パターンで分岐する式は、`match 対象 with` で始め、`end match` で閉じる。分岐は `case パターン ->` で始める。分岐の本体には、一つの式も、改行で区切った複数の文も書ける。本体は、次の `case` か `end match` までであり、本体の値は最後の式の値である。`->` の直後の改行は空白として扱う（[字句構造](01-01-lexical.md)の「改行による区切り」の規則 2）ので、本体が複数の文からなるときは、`->` の後で改行し、次の行から本体を書く。`with` は `match 対象` と同じ行に書く。`with` は改行による区切りの規則 3 の字句ではないので、行頭に書いた `with` は前の行の続きにならず、構文エラーになる。

```text
match shape with
  case Shape.Circle(r) -> 3.14159 * r * r
  case Shape.Rect(w, h) ->
    bind area <- w * h
    area
end match
```

分岐は次の分岐へ続かない（C 系の言語の `switch` のような fallthrough はない）。他の言語の書き方を持ち込んだ次の形は構文エラーとし、修正案を示す。

- `switch` と書いた場合。`match 対象 with` の形を示す。
- `case 対象 of` と書いた場合（Pascal・Haskell の書き方）。`match 対象 with` の形を示す。`of` と `when` はキーワードではない。
- `default:` と書いた場合。`case _ ->` と書くよう示す。
- 分岐の本体の後に `break` を書いた場合。`break` は要らないことを示す。
- `パターン => 式`（Rust・Scala）や、`case` を付けない `パターン -> 式`（Haskell）の形で書いた場合。`case パターン -> 式` の形を示す。

パターンの中の小文字識別子は新しい変数の束縛であり、大文字識別子はデータ構成子との照合である。データ構成子は、式の中と同じく型名で修飾して書く。浮動小数のリテラルはパターンに書けない。接尾辞付きの整数では `s64` だけを定数・範囲パターンに使える。`s8`・`s16`・`s32` と `u8`・`u16`・`u32`・`u64` は使えず、束縛・ワイルドカードとガードで分岐する。パターンの意味と、網羅性・到達不能の検査は[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

【方針】最後の包括的な分岐には、`case other ->` や `case otherCode ->` のような、外側の局所名や見えている定数と衝突しない通常の名前を推奨する。これらは予約語ではなく、対象の値を束縛する変数である。ガードのない包括的な分岐の後には、到達しない分岐を置かない。`case _ ->` も有効で、警告は出さない。この推奨は、構成子内の `_`、捨てる束縛の `_`、部分適用の `_` には適用しない。

### 名前付き引数と関数型

【決定】二つ以上のパラメータを持つ通常の関数では、すべての明示引数を名前付きにしなければならない。複数の位置指定は E0449、位置指定と名前指定の混在は E0450 とする。一引数の位置指定でも、渡す関数値の契約名の一致を検査する。既定値、引数の展開、引数不足からの自動の部分適用は加えない。

【決定】呼び出しの引数には `f(b: readB(), a: readA())` のようにパラメータ名を付けられる。指定順は宣言順と異なってよい。呼ぶ値の関数型の名前で対応付け、未知の名前、同じ位置の重複、指定漏れ、位置指定と名前指定の混在は誤りとする。引数がなければ `f()`、一つなら `f(e)` と `f(value: e)` のどちらも使える。名前付き引数のラベルは通常のパラメータと同じ小文字識別子であり、`record` は名前として使える。`_`・それ以外の予約語・修飾名は書けない。ラベルは局所の値への参照ではない。

【決定】関数型は `function(a: Integer, b: Integer) -> Integer` のように、すべてのパラメータに名前を書く。名前のない旧表記は E0257 とし、名前を持つ型注釈への移行を案内する。名前は型の契約の一部であり、型内で重複させない。型内の名前は局所の値を束縛しない。名前の検査と推論は[型システム](01-06-type-system.md)に従う。

【決定】関数の宣言、組み込み、ラムダ、局所の関数値、型クラスのメソッド、エフェクトの操作、外部の関数は、関数型の名前で対応付ける。データ構成子の直接の構築とパターンは位置指定であり、直接の構築に名前を付けると E0456 となる。レコードの構築・更新・パターンはフィールドの規則に従い、関数の引数の展開に `..base` は使えない。属性、ハンドラの節の引数束縛、`resume` はそれぞれの専用の構文を使う。

### ラムダ

【決定】ラムダ（無名関数）は、`lambda` の後に引数の並びと本体を書く。終端付きの形は `end lambda` で閉じる。短い形は、ラムダ全体を一物理行に収め、本体を一文に限るときに終端を省略できる。`function` は、関数の宣言と関数の型に使う。関数の宣言と違い、引数の型と戻り値の型は省略でき、省略すると推論する。戻り値の型は、関数の宣言と同じく `->` の後に書く。`uses` は、戻り値の型を書いたときだけ、その後に書ける。`uses` を書かなければ、エフェクトを本体から推論する（[型システム](01-06-type-system.md)）。本体は、関数の宣言と同じく `return` で値を返す。

【方針】一文で済むラムダは短い形を推奨する。終端付きの形も有効であり、整形器は終端を自動で増減しない。次の例では、最初は短い形、次は同じ行で閉じた終端付き、最後は次の行から本体を始める終端付きである。

```text
bind doubled <- List.map(xs: [1, 2, 3], f: lambda(value) return value * 2)
bind tripled <- List.map(xs: [1, 2, 3], f: lambda(value) return value * 3 end lambda)
bind makeAdder: function(x: Integer) -> function(y: Integer) -> Integer <- lambda(x)
  bind add <- lambda(y) return x + y
  return add
end lambda
```

外側の最後の文で短いラムダを作る場合も、次の行の終端は外側を閉じる。空行やコメント行を挟んでも対応は変わらない。

```text
bind wrap: function(x: Integer) -> Unit <- lambda(x)
  bind add <- lambda(y: Integer) return x + y
end lambda
```

ラムダの引数には `_` を書けない（`lambda(_, x) return x end lambda` は構文エラー）。使わない引数には、`_unused` のように `_` で始まる名前を付ける（[字句構造](01-01-lexical.md)）。

本体を見出しの最後の字句より後の物理行から始めるときは、対応する `end lambda` が必要である。本体の文を複数の行に書くときも、`lambda` のブロックの中の改行は文の区切りとして働く。関数の呼び出しの丸括弧の中に書いたときも同じである（[字句構造](01-01-lexical.md)の「改行による区切り」）。LLM が Python の形で `lambda x: x + 1` と書いたときは、`lambda(x) return x + 1` の短い形を修正案として示す。全体を同じ物理行に収めるか、本体を見出しの次の行から始めて `end lambda` を付けるよう案内する。C 系の波括弧の書き方 `fn(x) { … }` で書いたときは、`lambda(x) … end lambda` の形を修正案として示す。

【決定】見出しと同じ行に本体を始めたときは、その一文の直後の同じ物理行に対応する `end lambda` がある場合だけ終端付きとする。次の行以降の終端、外側の区切りを越えた終端は取らない。候補がなければ一行で完結する短いラムダとして読む。空行は終端の対応に影響しない。複数文・継続行・複数行のブロックを含む本体は、見出しの次の行から始める。理由: 外側の終端を内側の短いラムダが取ることを防ぎ、空行の追加や除去で本体の範囲が変わらないようにするためである。

見出しの行に本体を書き、次の行にそのラムダを閉じるつもりで `end lambda` を置く二行の形は受け付けない。本体を見出しの次の行へ移すか、終端まで同じ行へまとめる。外側に対応するラムダがない終端には、終端の不一致や予期しない字句の診断と、この直し方を示す。

【決定】短い形の一行条件は、`lambda` の先頭から本体の最後の字句の末尾までに適用する。LF と CRLF、文字列・コメント・補間・型注釈内の改行、空白として捨てた改行も数える。末尾の行コメントと、その後の改行は本体の外側である。本体の式は通常の優先順位で読み、内側の呼び出し・リスト・型・ブロックを消費し、外側のコンマ・閉じ括弧・分岐境界・ブロック境界・行末・EOF を残す。`lambda(x) return x + 1 |> increment` のパイプは本体に入る。ラムダ自体の呼び出しは `(lambda(x) return x + 1)(3)` とする。一行で閉じた `if` や、一分岐の `match` も一つの式として書ける。複数分岐の `match` は、従来どおり分岐の間に改行が必要である。

短い形も通常の文として型検査する。暗黙の戻り値は加えず、`return`・`try` の作用先、Unit の本体の終わりの扱い、`resume`・ガード・`lazy` の制限を維持する。正常な短い形の後の独立した行は外側の文である。本体に文を追加するときは、先に本体の開始を次の行へ移し、終端を付ける。改行を越える省略候補は E0254、同じ行の二文の並置は従来の文の区切りの診断になる。

【決定】直接の入れ子で外側か内側が短い形なら、内側のラムダ全体を括弧で囲まなければならない。直接の入れ子は、外側の式文の `return`・演算などに裸のラムダが含まれ、括弧・呼び出しの引数・束縛文などの独立した区切りで隔てられていない形である。両方が終端付きなら裸の入れ子を認める。違反は E0256 とし、内側へ括弧を付ける修正案を示す。理由: 終端の属するラムダを、括弧によって明示するためである。

```text
lambda(x) return x + 1 end lambda
lambda(x: Integer) -> Integer return x + 1 end lambda
lambda(line: String) -> Unit uses IO Console.writeLine(line) end lambda
```

3 行目の `uses IO` は、前述の「プログラムと宣言」と同じく簡略な書き方である。実際のスクリプトでは、`Console` のモジュールの import が要り、`uses IO` を `uses Console.Write` と書く。

### 演算子の優先順位と結合性

【方針】演算子の優先順位と結合性は次のとおりである。上の行ほど優先順位が低い。

| 優先順位 | 演算子 | 結合性 |
|---|---|---|
| 1 | `\|>` | 左結合 |
| 2 | `or` | 左結合 |
| 3 | `and` | 左結合 |
| 4 | `=` `<>` `<` `<=` `>` `>=` | 結合しない |
| 5 | `+` `-` | 左結合 |
| 6 | `*` `/` `div` `mod` | 左結合 |
| 7 | 単項の `-` `not` | 前置 |
| 8 | 関数の呼び出し `f(...)` | 後置 |

`return` と `try`（後述の「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」）は、式の先頭に書き、右の式全体（パイプを含む）にかかる。`try` の入力は同じ深さの `or return` / `or die` の手前で終わる。どの演算子よりも弱く結び付く。ただし、`return` の値は同じ物理行で書き始めなければならず、直後の改行を越えて右の式を読まない。値を書き始めた後の改行には通常の継続の規則を使う。

比較演算子は結合しない。`a < b < c` は構文エラーであり、`a < b and b < c` と書くよう診断で示す。

【決定】等しいを `=`、等しくないを `<>`、論理演算子を `and`・`or`・`not` と書く。`=` は、`with` の束縛、定数の宣言、型の別名の宣言にも使う。これらの `=` は名前（と型）の直後にだけ現れるので、比較の `=` と一通りに読み分けられる。局所の束縛の文は `<-` で書くので、比較の結果を束縛する文（`bind ok <- a = b`）は括弧なしで読める。書き換えのつもりで `x = 5` と書いた式文は、値が `Boolean` の式文として型検査の誤りになり、診断は変数を書き換えられないことと、`shadow x <- 5` で同じ名前を束縛し直す書き方を示す。

【決定】整数の除算を `div`、剰余を `mod` と書く。`/` のオペランドは、`Float`・`Float32`・`Decimal` に限る（[型システム](01-06-type-system.md)の演算子の型の表）。

各演算子の型と意味は、[基本型の意味論](01-04-types-basic.md)と[型システム](01-06-type-system.md)で定める。

【決定】数の接尾辞は、整数リテラルと浮動小数リテラルの字句の一部であり、文法に新しい式を加えない。負号は単項演算である。符号付きリテラルに直接付く負号だけは、符号込みで範囲検査する（`-128s8`）。括弧を挟む `-(128s8)` は一般の負号であり、内側の範囲外のリテラルを拒否する。符号なしの負号は `-0u16` も誤りである。理由: 最小値を表せるようにしつつ、一般の式に対する負号の型の規則を保つ。

### ドット記法

【決定】ドット `.` は、モジュールの修飾と、型名によるデータ構成子の修飾にだけ使う。`.` の左には大文字識別子で書いたモジュール名か型名を、右にはそのモジュールが定める名前か、その型の構成子の名前を書く（`List.map`、`String.lines`、`Shape.Circle`）。prelude の `Option` と `Result` の構成子も、型名で修飾して書く（`Option.Some`、`Result.Error`）。

修飾に使えるモジュールは、標準ライブラリのモジュールと、import で取り込んだモジュールである（後述の「モジュールと import（初回リリース版）」、[名前・スコープ・モジュール](01-03-names-modules.md)）。

値に続けてドットを書く形（`xs.map(f)`、`s.length`）は構文エラーである。このとき、診断は `|>` を使った書き方（`xs |> List.map(f: f)`）を修正案として示さなければならない。レコードのフィールドも、ドットではなく型のモジュールの関数で取り出す。

### パイプ

【決定】パイプ `x |> e` は、左の値を右の関数に渡す糖衣である。

【方針】`x |> e` は、右辺 `e` の形によって次のように展開する。

1. `e` が関数の呼び出しであり、その直接の引数のどれもプレースホルダ `_` でなければ、`x` を宣言位置 0 に補う。引数の中に入れ子になった呼び出しのプレースホルダは数えない。例えば `x |> f(action: g(_))` は `f` の位置 0 に `x` を渡し、`action` には `g(_)` から作る関数を渡す。`e` が呼び出しを重ねた形（`g(a)(b)`）であれば、最も外側（最後）の呼び出しに加える。
2. それ以外であれば、`e` を関数として `x` に適用した `e(x)` に展開する。`e` の直接の引数にプレースホルダを含む呼び出しの場合もこの規則による。次節の展開によって `e` は関数になるので、`x` はプレースホルダの位置に入る。

【決定】右辺 `e` が括弧で囲んだ式であれば、中身によらず規則 2 により `e(x)` に展開する。`x |> (f(a))` は `(f(a))(x)` になる。関数を返す呼び出しの結果に `x` を渡すときは、このように右辺を括弧で囲む。

```text
lines |> List.filter(p: nonEmpty)    // List.filter(xs: lines, p: nonEmpty)
lines |> List.length              // List.length(lines)
x |> clamp(lo: 0, value: _, hi: 100) // clamp(lo: 0, value: x, hi: 100)
x |> lambda(v) return v * 2 end lambda              // (lambda(v) return v * 2 end lambda)(x)
x |> (makeHandler(config))        // (makeHandler(config))(x)
```

`try` は右の式全体にかかるので、パイプの結果にかけるときは、パイプの先頭に書く（`try x |> f(next: a) or return` は、`x` を位置 0 に補う呼び出し全体に `try` を適用する）。

`x` と `e` をどの順に評価するかは[評価意味論](01-08-evaluation.md)で定める。

【決定】直接の穴がない通常の関数呼び出しへのパイプは、左辺を宣言位置 0 に補う。残りの明示引数は名前で指定する。`xs |> List.map(f: action)` は位置 0 の `xs` と `f` を渡し、`xs |> List.map(xs: ys, f: action)` は位置 0 の重複となる。空いている位置を探索しない。直接の穴がある右辺と括弧で囲んだ右辺は、先に作る関数へ一引数で適用する。穴が二つあっても自動で再部分適用しない。直接のデータ構成子への挿入は位置指定を保つ。

### 部分適用のプレースホルダ

【決定】部分適用は、プレースホルダ `_` を使って明示する。関数はカリー化しないので、引数が足りない呼び出しは部分適用にならず、型検査の誤りになる。

【方針】関数の呼び出し `f(a1: e1, ..., an: en)` の引数のうち、`_` そのものであるものをプレースホルダと呼ぶ。プレースホルダを一つ以上含む呼び出しは、プレースホルダを左から順に新しい引数に置き換えたラムダに展開する。展開で使う局所変数の名前は、ソースのどこにも現れない新しい名前である。生成する関数型の契約名は元のパラメータ名を穴のソース順に並べる。局所変数の名前と契約名は区別する。合成した局所変数は既存の束縛を捕獲しない。

```text
clamp(lo: 0, value: _, hi: 100) // function(value: Integer) -> Integer
between(value: _, lo: lo, hi: _) // 穴の契約名は value, hi の順
```

- プレースホルダが属するのは、それを直接の引数とする呼び出しだけである。`f(g(_))` で関数になるのは内側の `g(_)` だけであり、その契約名は `g` の元のパラメータから取る。
- 呼び出しの直接の引数以外の位置（`_ + 1` など）に `_` を書くと、構文エラーとする。
- 展開後のラムダの本体には、呼び出される関数 `f` と、プレースホルダでない引数の式がそのまま入る。これらの式を評価する時期は、展開後のラムダに従う（[評価意味論](01-08-evaluation.md)）。これらの式の中の `return` と `try` は展開後のラムダから抜け、その戻り値の型で検査する。ただし、`lazy` の本体と `match` のガードの中（内側の `lambda … end lambda` の本体の中を除く）に書いたプレースホルダを含む呼び出しでは、これらの式の中に `return` と `try` を書けない（本章の「`return`」、[エラー処理](01-09-errors.md)の「`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`」）。これらの式の中には、外側の `handle` の節の続きを再開する `resume` を書けない（ラムダの本体の中と同じ）。

【決定】`f(b: _, a: _)` の関数型は、元の契約が `a: A, b: B` なら `function(b: B, a: A) -> R` となる。穴の順を元の宣言順へ並べ直さない。直接の位置フィールドの構成子の穴は、元のフィールド位置から `arg1`、`arg2`、… の契約名を作る。

### モジュールと import（初回リリース版）

【決定】一つのソースファイルを一つのモジュールとする。モジュールの名前は根のディレクトリからのパスで決まり、ほかのモジュールは `import` の宣言に名前を書いて取り込む。トップレベルの宣言に `public` を付けると、取り込んだ側から使える。`public(package)` を付けると、同じパッケージのモジュールからだけ使える。`public` と `(` の間には空白と改行を置いてよい。`public(package)` の後の改行は `)` の後の区切りになるため、宣言との間には置けない。括弧の中に書ける語は `package` だけであり、予約語にはしない。トップレベルには値の定義を置けない。ただし、定数式に限った定数は置ける（後述の「定数（初回リリース版）」）。トップレベルに置けるのは、import の宣言、関数の宣言、定数の宣言、型の宣言、型の別名の宣言、レコードの宣言、型クラスの宣言、エフェクトの宣言、実装の宣言である。

文法の次の規則を改める。ほかの規則は「文法」と同じである。

```text
Visibility  = "public" [ "(" "package" ")" ] .
TopItem     = ImportDecl | [ Visibility ] FnDecl | [ Visibility ] DataDecl .
ImportDecl  = "import" UpperIdent { "." UpperIdent } [ "as" UpperIdent ] .

Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(NamedType) ")" "->" Type [ Uses ]
            | "(" Type ")" .
QualUpper   = UpperIdent { "." UpperIdent } .
Name        = { UpperIdent "." } ( LowerIdent | UpperIdent ) .
Pattern     = ...
            | QualUpper [ "(" CommaList(Pattern) ")" ] .
```

- import の宣言は、ファイルの中で、ほかのすべてのトップレベルの宣言より前に置く。ほかの宣言の後に import の宣言を書くと、構文エラーとする。
- `import` の後には、取り込むモジュールの名前を、大文字の名前をドットで区切って書く（`import Lib.Text`、`import Benitoite.Unofficial.IO.Console`）。名前に当たるファイルの探し方は[名前・スコープ・モジュール](01-03-names-modules.md)で定める。
- `as` は、import の宣言の中でだけ意味を持つ語であり、キーワードではない。`as` の後の大文字の名前で、取り込んだモジュールを使う。`as` を書かなければ、名前の最後の要素で使う。
- 修飾した名前（`QualUpper` と `Name`）は、大文字の名前をドットでいくつでも並べられる。段の数は文法で制限しない。各段が何を指すか（名前空間、モジュール、型、構成子など）は、名前解決で左から順に決める（[名前・スコープ・モジュール](01-03-names-modules.md)の「修飾された名前の解決」）。
- LLM がパスの文字列で取り込んだとき（`import Text from "./lib/text.bnt"`、`import "./text.bnt"`）は、名前で取り込む書き方を修正案として示す。

```text
import Lib.Geo

public function area(s: Geo.Shape) -> Float
  return match s with
    case Geo.Shape.Circle(r) -> Geo.pi() * r * r
    case Geo.Shape.Rect(w, h) -> w * h
  end match
end function
```

### ファイルの先頭の部分

【決定】ファイルの先頭の `//!` の後、最初の import か宣言の前に、言語の版、依存の記述、パッケージの名前を書ける。項目の順序は問わない。`language`・`dependency`・`package` と欄の名前は、予約語ではなく、この位置で意味を持つ語である。理由: 通常の識別子としての用途を保ち、同じ設定を入口と設定ファイルで同じ構文で書くためである。

```text
language "0.0.12"

dependency Textkit
  path "../packages/textkit"
end dependency

import Textkit.Slug

function main() -> Unit
  ()
end function
```

【決定】各項目の形は次のとおりとする。値は、補間を含まない文字列リテラルに限る。

| 項目 | 形と欄 |
|---|---|
| 言語の版 | `language "MAJOR.MINOR.PATCH"` の一行。各部は ASCII の数字の並びで、`u64` に収まり、`0` 以外は `0` で始めない |
| 依存の記述 | `dependency 別名` から `end dependency` まで。別名は大文字で始まる識別子で、`Benitoite` は使えない。欄は `path`（必須）、`hash`・`effects`（任意）。`source`・`version`・`commit` は欄として読むが、この版では使えない誤りとする |
| パッケージの名前 | `package 名前` から `end package` まで。名前は大文字で始まる識別子。欄は `license` だけで、任意である。使用許諾の文字列の中身は検査せず、空の文字列も許す |

【決定】ブロックの欄は、一行に名前と文字列を一つずつ書く。欄の順序は問わない。同じ欄を二度書くこと、知らない欄を書くこと、同じ別名の依存・言語の版・パッケージのブロックを二度書くことは誤りとする。`hash` は `sha256:` の後に小文字の 16 進数字を 64 文字続けた形に限る。理由: 設定が一意に決まり、知らない欄の診断で書ける欄の一覧を示せるようにするためである。

【決定】`effects` は空の文字列か、カンマで区切ったエフェクトの名前の並びとする。各名前の前後の空白を除き、ドットで区切った各段は ASCII の大文字で始まり、ASCII の英数字と `_` だけを含む。形が合わなければ誤りとする（診断は[字句解析器と構文解析器](../02-impl/02-03-frontend.md)）。これはパッケージの命令が最後に報告した組み込みのエフェクトの記録であり、読み込み時にパッケージの中身と照合しない。理由: 更新前のエフェクトを記録に残し、変更の差を示せるようにするためである。

【決定】最初の import か宣言の後で、`language` の次が文字列、または `dependency`・`package` の次が大文字の名前である行は、先頭に書くべき項目として誤りにする。構文の形の検査と、ファイルの種類に応じた置き場所の検査を区別する。置き場所と版の意味は、[名前・スコープ・モジュール](01-03-names-modules.md)の「依存の記述と `package.bnt`」で定める。

【決定】ファイル単位のエフェクトの宣言は、先頭のメタデータと import 群の後、通常の宣言の前に `uses` と空でないエフェクト参照の並びを一回だけ書く。省略で空集合を表し、`uses` だけ、`uses []`、二度目の宣言、通常の宣言の後の宣言は誤りとする。宣言の後には import やメタデータを置けない。理由: 宣言の位置と回数を固定し、効力が途中で変わると解釈される形を避けるためである。

【決定】ファイルの宣言は NEWLINE かファイルの末尾で終わる。コンマ後の改行は通常の継続規則に従い、末尾のコンマも許す。個別の関数型の `uses` と異なり、二番目以降にも `Fail[MyError]` のような型引数付きの参照を書ける。関数のシグネチャに属する `uses` は、戻り値の型と同じ物理行で書き始める。本体なしの `@builtin`・`@external` の次行の `uses` も、遅いファイルの宣言として報告する。

現在の処理系はファイルの宣言の構文と元位置を保持し、検査と実行には合併後の契約を使う。package の集計・整形器・derive と try-actions の inventory は元の宣言を読む（[パッケージ](../06-tooling/06-09-packages.md)、[フォーマッタ](../06-tooling/06-03-formatter.md)、[標準ライブラリ](../03-interop/03-06-stdlib.md)、[try-actions の移行器](../../../tools/try-actions-migrate/README.md)）。`package.bnt` にはファイルの宣言を書けない。

### レコード（初回リリース版）

【決定】レコードは `record` で宣言し、フィールドを「名前: 型」の形で一行に一つずつ並べる。値は名前付きの引数で作り、一部のフィールドを変えた値は `..` で作る。フィールドの値は、型のモジュールの関数で取り出す。レコードの宣言は、フィールドごとに同じ名前の取り出す関数をその型のモジュールに加える。レコードの型と値の意味は[代数的データ型とパターンマッチ](01-05-data-types.md)の「レコード（初回リリース版）」で定める。

文法に次の規則を加える。

```text
TopItem     = ... | [ Visibility ] RecordDecl .
RecordDecl  = "record" [ NL ] UpperIdent [ TypeParams ] LineList(Field) "end" "record" .
Field       = LowerIdent ":" Type .

Primary     = ... | RecordExpr .
RecordExpr  = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")" .
FieldArg    = LowerIdent ":" Expr .

Pattern     = ... | QualUpper "(" FieldPat { "," FieldPat } [ "," ".." ] [ "," ] ")" .
FieldPat    = LowerIdent ":" Pattern .
```

```text
record Person
  name: String
  age: Integer
end record

function birthday(p: Person) -> Person
  return Person(..p, age: Person.age(p) + 1)
end function

function greeting(p: Person) -> String
  return match p with
    case Person(name: n, age: 0) -> "Welcome, ${n}"
    case Person(name: n, ..) -> "Hello, ${n}"
  end match
end function
```

- レコードの宣言には、フィールドを一つ以上書かなければならない。`LineList(Field)` は 0 個の並びも読めるが、フィールドが一つもない宣言（`record Empty` の直後に `end record`）は構文エラーとする。
- 構文解析は、`QualUpper` の直後の `(` の次が「小文字の名前 `:`」か `..` であれば、レコードの構築（パターンではレコードのパターン）として読む。そうでなければ、構成子の呼び出しと構成子のパターンとして読む。
- 【方針】一部のフィールドを変えた値を作るときは、変えるフィールドを一つ以上書かなければならない。`Person(..p)` のように一つも書かない形は構文エラーとし、診断は `p` をそのまま使う書き方を修正案として示す。
- 【方針】レコードのパターンにも、フィールドを一つ以上書かなければならない。`Person(..)` のように一つも書かない形は構文エラーとし、診断はワイルドカード `_` を使う書き方を修正案として示す。
- レコードの構築の中には、部分適用のプレースホルダ `_` を書けない。
- フィールドを取り出す関数は、レコードの名前で修飾した小文字の名前で書く（`Person.age`、取り込んだモジュール `Geo` のレコード `Point` では `Geo.Point.x`）。前述の「モジュールと import（初回リリース版）」の `Name` の規則がこの形を読む。修飾した名前の各段が何を指すかは[名前・スコープ・モジュール](01-03-names-modules.md)の「修飾された名前の解決」で定める。
- 値に続けてドットを書く形（`p.name`）は、構文エラーとする。診断は `Person.name(p)` と `p |> Person.name` を修正案として示す。

### 組と `bind`・`shadow` のパターン（初回リリース版）

【決定】組の型 `Pair` と `Triple` を prelude に設け、括弧のタプルは設けない。`Pair` と `Triple` はレコードではなく、構成子が一つだけの代数的データ型である。組の型と値の意味は[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

```text
bind p <- Pair(1, "one")
bind Pair(n, name) <- p

match p with
  case Pair(0, label) -> label
  case Pair(k, _) -> Integer.toString(k)
end match
```

- 構成子は型名で修飾して書くが、構成子が一つだけで、その名前が型の名前と同じ型（`Pair`、`Triple`、利用者の同じ形の型）は例外とし、構成子を型の名前で修飾せずに書く（`Pair(1, "one")`）。文法の `Name` と `Pattern` の、段が一つの名前がこの形を読む。
- 束縛の文の左辺に、必ず照合するパターンを書ける。文法の規則は次のように改める。必ず照合するかの判定は[代数的データ型とパターンマッチ](01-05-data-types.md)の「必ず照合するパターン（初回リリース版）」で定める。パターンの変数は、すべて新しい名前（`bind`）か、すべて見えている局所の名前（`shadow`）でなければならない（[名前・スコープ・モジュール](01-03-names-modules.md)の「シャドーイング」）。

```text
BindStmt    = ( "bind" | "shadow" ) Pattern [ ":" Type ] "<-" Expr .
```

- 括弧で囲んだ式・型・パターンをコンマで並べる形（`(1, "one")`、`(Integer, String)`、`(a, b)`）は、構文エラーとする。診断は、要素が 2 個なら `Pair`、3 個なら `Triple`、4 個以上なら `record` の宣言を修正案として示す。

### 文字列補間（初回リリース版）

【決定】文字列リテラルの中の `${e}` は、式 `e` の値を文字列にして埋め込む。字句の規則は[字句構造](01-01-lexical.md)で、`e` の型は[型システム](01-06-type-system.md)で定める。

文法に次の規則を加える。文字列補間を含む文字列リテラルは、[字句構造](01-01-lexical.md)の規則で補間の開始・中間・終わりの字句と式の字句に分かれ、構文解析はそれを次の規則で読む。

```text
Primary     = ... | InterpString .
InterpString = StrStart Expr [ ":" FormatSpec ] { StrMid Expr [ ":" FormatSpec ] } StrEnd .
FormatSpec  = [ Align ] [ Sign ] [ "#" ] [ "0" ] [ Width ] [ Precision ] [ Kind ] .
Align       = "<" | ">" | "^" .
Sign        = "+" .
Width       = NonZeroDigit { Digit } .
Precision   = "." Digit { Digit } .
Kind        = "d" | "b" | "o" | "x" | "X" | "f" | "s" | "c" .
NonZeroDigit = "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" .
Digit       = "0" | NonZeroDigit .
```

【決定】`${e:spec}` は書式付きの補間である。通常の完全な式 `e` を一度解析し、その直後に残るコロンから、同じ補間の `}` の直前までを元のソースの書式として読む。名前付き引数、レコードとパターンの欄、ブロック内の型注釈のコロンは式の一部である。短いラムダの本体の式に続くコロンは、ラムダ全体の後の書式の区切りとする。式の末尾とコロンの間には通常の空白を置ける。理由: 式の文法を重ねずに、式内のコロンと書式の区切りを区別するためである。

【決定】書式内の数字は ASCII とする。幅は1〜65535、精度は0〜28とし、省略と明示した精度0を区別する。空書式、書式内の空白、符号の `-`、未知の種類、順序の違反を拒否する。精度には種類 `f`、寄せとゼロ埋めには幅が必要であり、ゼロ埋めと明示の寄せは併用できない。`#` は `b`・`o`・`x`・`X` に限る。型との適合は構文の検査と区別する。

【決定】書式の構文・範囲・指定の組み合わせと型の適合を実行前に検査する。適合した書式は定数式と実行時の補間で使え、書式なしの型と実行の規則も保つ。`fmt` は有効な書式を保持する。

パターンには `StringLit` だけを書けるので、文字列補間は書けない。

```text
Console.writeLine("${name} is ${age} years old")
```

### 型クラス（初回リリース版）

【決定】型クラスは `trait` で宣言し、`implement` で実装する。関数の型パラメータには `[T: Show]` の形で制約を付ける。一つの型パラメータに複数の制約を付けるときは、`&` でつなぐ（`[T: Show & equality]`）。型クラスの規則は[型システム](01-06-type-system.md)で定める。

【決定】制約の位置には、型クラスの名前のほかに、組み込みの制約 `equality`（等値の型である）と `key`（鍵の型である）を書ける。型クラスは、`trait Monoid[T: Semigroup]` の形で上位の型クラスを持てる。

文法に次の規則を加え、`FnTypeParam` を改める。

```text
TopItem     = ... | [ Visibility ] TraitDecl | ImplDecl .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl [ ":" QualUpper { "&" QualUpper } ] "]"
              LineList(MethodSig) "end" "trait" .
MethodSig   = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] .
ImplDecl    = "implement" [ FnTypeParams ] QualUpper "[" Type "]" LineList(FnDecl) "end" "implement" .

FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" Constraint { "&" Constraint } ] .
Constraint  = QualUpper | LowerIdent .
TypeParamDecl = UpperIdent [ "[" "_" { "," "_" } "]" ] .
```

- `F[_]` は、型構成子を表す型パラメータを宣言する。`_` の個数が、型構成子がとる引数の個数である。
- 利用者のソースでは、`Constraint` の `LowerIdent` は、組み込みの制約 `equality` か `key` でなければならない。それ以外の小文字の名前を書くと構文エラーとする。標準ライブラリのソースでは、組み込みの制約 `ordered` も書ける（[標準ライブラリ](../03-interop/03-06-stdlib.md)の「標準ライブラリのソースの書き方」）。利用者のソースに `ordered` を書いたときの診断は、標準ライブラリでだけ使える制約であることを示す。`equality` と `key` はキーワードではなく、制約の位置でだけこの意味を持つ。ほかの位置では、変数などの名前に使える。型クラスの名前は大文字で始まるので、制約の位置の小文字の名前と取り違えることはない。組み込みの制約を書ける型パラメータの規則は[型システム](01-06-type-system.md)で定める。
- `trait` の型パラメータの後の `:` に続く名前は、上位の型クラスである。上位の型クラスの位置には、組み込みの制約を書けない。
- 一つの `trait` の中で、二つのメソッドに同じ名前を付けると誤りとする。違う型クラスのメソッドどうしは、同じ名前でもよい。
- `implement` の中の関数の宣言には、`public` と `public(package)` を付けない。`implement` にも付けない。
- 【方針】実装は、プログラム全体で有効である。どのモジュールで型クラスの制約を解くときも、プログラムを構成するすべてのモジュールの実装から探す。孤立した実装と重なる実装を誤りとするので、使える実装は一つに決まる（[型システム](01-06-type-system.md)）。
- `M.C.m`（三つ目が小文字の名前）は、取り込んだモジュール `M` の型クラス `C` のメソッド `m` を表す。
- `implement Person ... end implement` のように、型クラスの名前を書かない `implement` は構文エラーとする。診断は、トップレベルの関数として書く方法を修正案として示す。

### `Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）

【決定】失敗を呼び出し元へ返すか、終了する処置を選ぶ前置の `try` を設ける。意味は[エラー処理](01-09-errors.md)で定める。文法の規則は次のように改める。

```text
Expr        = "return" Expr
            | "try" TryOperand [ "or" TryAction ]
            | PipeExpr .
TryOperand  = Expr . (* 同じ深さの or return / or die の手前で終える。詳細は try の節。 *)
TryAction   = "return" | "die" [ "(" Expr ")" ] .
```

- `try` は右の式全体（パイプを含む）にかかる。`try e |> f(_) or return` は `try f(e) or return` である。同じ深さの `or return` / `or die` は入力の終わりとし、失敗時の処置として読む。`or return` は値を取らない。`try r or return` と裸の `try r` は、型と評価の意味が同じである。
- `or` の後が `return` / `die` でなければ通常の Boolean の演算子として読む。`try r or flag or return` は `try (r or flag) or return` である。括弧・引数・ラムダ・ブロックの内側では、その範囲の式を読む。内側の `try` が処置を先に取り、`try try r or return or return` は内外それぞれの処置になる。
- 処置の解析は、外側の閉じ括弧・コンマ・`then`・`do`・`with case`・`case`・`else`・`end` を消費しない。内側の `match` のガードは、その内側の式として読む。ガードに直接書いた `try` は裸と明示形のどちらも E0218 とし、ガード内のラムダの本体には書ける。
- 明示形の後に演算子・呼び出し・型適用を続けるときは、`(try r or return) + 1` のように明示形を括弧で囲む。囲まず続ければ E0259、`try r or return extra` のように処置へ値を付ければ E0258 とする。外側の `try` が待つ処置は E0259 にしない。
- `or` の前後の改行は式の継続となる。`return` 直後の改行は、普通の `return` と同じく、括弧内でも次の字句によらず文を終える。この処置は値を取らないため、普通の `return` の値の欠落とは区別する。引数では `or return,`、括弧の式では `or return)` のように区切りを同じ行に書く。短いラムダは処置を含めて一物理行に収める。
- `or die` は失敗時に終了操作を行い、`or die(message)` は純粋な String の説明を付ける。型と評価は[エラー処理](01-09-errors.md#失敗時に終了する処置)に従う。`die()` と `die(a, b)` は E0258 とする。単独の `die` は E0201 とし、`try` の処置を案内する。
- `die` の説明の開き括弧は、`die` と同じ物理行で始める。括弧の外では、処置の `die` と説明の閉じ括弧の後の改行で文を終え、次行の括弧や演算子を取り込まない。説明の括弧内は通常の継続規則に従う。短いラムダは説明の閉じ括弧まで一物理行に収める。説明から直接の `return`・`try` は E0218 とし、内側のラムダには通常の関数境界を作る。
- フォーマッタは裸・明示 return・die と説明の選択を保ち、裸の形へ `or return` を足さない。
- LLM が例外を捕らえる構文のつもりで `try { … } catch` と書いたとき（`{` は字句として受け付けない記号）は、例外を捕らえる構文がないこと（[エラー処理](01-09-errors.md)の「例外」）と、`Result` か `Option` を返す式に `try` を付けることを示す。

### 明示遅延（初回リリース版）

【決定】`lazy ... end lazy` は、ブロックを評価せずに `Lazy[T]` の値を作る。意味は[評価意味論](01-08-evaluation.md)で定める。

```text
Primary     = ... | "lazy" Body "end" "lazy" .
```

### リソーススコープ（初回リリース版）

【決定】`with x = e do ... end with` は、`e` の値のリソースを `x` に束縛してブロックを評価し、ブロックを抜けるときに解放する。意味は[リソース管理](01-10-resources.md)で定める。

```text
Primary     = ... | WithExpr .
WithExpr    = "with" WithBind { "," WithBind } "do" Body "end" "with" .
WithBind    = LowerIdent "=" Expr .
```

`with` の並びのコンマの後では改行してよい（コンマの直後の改行は、[字句構造](01-01-lexical.md)の「改行による区切り」の規則 2 で空白として扱う）。束縛の並びの後に `do` を書き、本体を続け、`end with` で閉じる。`do` は、束縛の式と本体の区切りを字句で示す。

`with` は、`match` と `handle` の分岐の並びの始まりにも使う。文法の上では、`match 対象` と `handle 本体` の後の `with` は分岐の並びの始まりであり、それ以外の位置の `with` はリソーススコープである。分岐の並びの `with` の次の字句は `case`、リソーススコープの `with` の次の字句は束縛する名前なので、字句の上でも見分けられる（[字句構造](01-01-lexical.md)の「改行による区切り」）。

### パターンの拡張（初回リリース版）

【決定】`match` の分岐には、コンマで区切って複数のパターン（選択肢）を並べ、パターンの後に `if 条件` のガードを書ける（`case 1, 2 -> …`、`case n if n > 0 -> …`）。パターンには、範囲とリストのパターンを書ける。意味と網羅性の規則は[代数的データ型とパターンマッチ](01-05-data-types.md)の「パターンの拡張（初回リリース版）」で定める。文字の全域を覆う範囲は、`bind`・`shadow` の必ず照合するパターンの一部にも書ける。束縛の文にコンマの選択肢は書けない。

```text
Arm         = "case" Pattern { "," Pattern } [ "if" Expr ] "->" ArmBody .
Pattern     = ...
            | RangeEnd ".." RangeEnd
            | "[" [ ListPatElem { "," ListPatElem } [ "," ] ] "]" .
RangeEnd    = [ "-" ] IntLit | CharLit .
ListPatElem = Pattern | ".." [ LowerIdent ] .
```

- 分岐の最も外側のコンマは、選択肢の区切りである。構成子のパターンの引数の中のコンマは、括弧の中にあるので選択肢の区切りにならない。
- ガードの `if` は、`end if` で閉じない。`case` の後、分岐の `->` までに現れる `if` はガードであり、`if` の式として読まない。ガードの中に `if` の式を書くときは、括弧で囲む。
- 範囲の `..` の前後には、同じ種類のリテラルを書く。
- LLM が選択肢を `|` で書いたとき（`case 1 | 2 ->`）、ガードを `when` や `where` で書いたとき、範囲を `..=`・`..<`・`...` で書いたときは、Benitoite の書き方を修正案として示す。

### リストの展開（初回リリース版）

【決定】リストリテラルの要素の一つを、展開 `..e` にできる。展開は、`e` の値のリストの要素を、その位置に並べる。展開を書ける位置と数は、リストのパターンの `..` と同じである。一つのリストリテラルに一つまで、どの位置にも書ける。型は[型システム](01-06-type-system.md)で、評価の順序と大きさの上限は[評価意味論](01-08-evaluation.md)で定める。

```text
Primary     = ... | "[" [ ListElem { "," ListElem } [ "," ] ] "]" .
ListElem    = Expr | ".." Expr .
```

```text
function insertByCount(pair: Pair[String, Integer], xs: List[Pair[String, Integer]]) -> List[Pair[String, Integer]]
  match xs with
    case [] -> return [pair]
    case [first, ..rest] if Pair.second(first) >= Pair.second(pair) ->
      return [first, ..insertByCount(pair: pair, xs: rest)]
    case _ -> return [pair, ..xs]
  end match
end function
```

- 一つのリストリテラルに展開を二つ以上書いたとき（`[..xs, ..ys]`）は構文エラーとし、診断は `List.concatenate` で書く修正案を示す。
- JavaScript の `...xs` や Python の `*xs` の形で要素を書いたときは、`..xs` を修正案として示す。
- 展開の `..` の後には式を書く。パターンと違い、`..` だけの要素（`[x, ..]`）は書けない。

### エフェクトの宣言とハンドラ（初回リリース版）

【決定】利用者が定義するエフェクトは、モジュールのトップレベルで `effect 名前 … end effect` と宣言し、操作を `function` の形で並べる。操作は、エフェクトを宣言したモジュールの関数である。ハンドラは `handle 本体 with case 操作(引数) -> 節 … end handle` と書き、節の中で `resume(値)` によって本体の続きを再開する。意味は[エフェクト](01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」で、型付けは[型システム](01-06-type-system.md)で定める。

```text
TopItem     = ... | [ Visibility ] EffectDecl .
EffectDecl  = "effect" UpperIdent LineList(OpSig) "end" "effect" .
OpSig       = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type .
Primary     = ... | HandleExpr | "resume" "(" Expr ")" .
HandleExpr  = "handle" Body "with" [ NL ] HandleArm { NL HandleArm } [ NL ] "end" "handle" .
HandleArm   = "case" OpName "(" CommaList(OpParam) ")" "->" ArmBody .
OpName      = { UpperIdent "." } LowerIdent .
OpParam     = LowerIdent | "_" .
Uses        = "uses" EffectRef { "," EffectRef } .
EffectRef   = QualUpper [ "[" CommaList(Type) "]" ] .
```

- 標準の `Failure.Fail[E]` だけが値の型引数を一つ取る。`import Benitoite.Unofficial.Failure` で明示的に取り込み、`uses Failure.Fail[E]` と書く。一般の `effect L[E]` は宣言できない。他のエフェクトへの型引数と、Fail の型引数の省略・過不足は E0513 とする。
- 二つ目以降の型引数付きエフェクト参照は、モジュール名で修飾する。修飾のない `uses A, List[Integer]` は、従来どおり関数型を括弧で囲む E0209 の修正案を出す。
- Fail の節は `case Failure.raise(error) -> ...` と書く。節から handle 全体の結果を返し、`resume` は書けない（E0516）。普通の操作の節と混ぜた場合は E0518 とし、handle を入れ子にする修正案を示す。
- 操作の宣言には `uses` を書けない。操作の型パラメータの並びに、エフェクト変数と型構成子を表す型パラメータ（`F[_]`）は宣言できない。操作の値の型パラメータには、組み込みの制約（`equality`・`key`）と型クラスの制約を書ける。複数の制約は関数と同じく `&` でつなぐ。
- `handle` の本体は、節の並びを始める `with` までである。節の本体は、`match` の分岐と同じく、次の `case` か `end handle` までであり、節の値は最後の式の値である。
- `case` の後には、操作の名前を、式の中で操作を呼ぶときと同じ形で書く。同じモジュールで宣言したエフェクトの操作は修飾せずに（`case write(message) ->`）、ほかのモジュールの操作はモジュールの名前で修飾して（`case Logging.write(message) ->`、`case Console.writeLine(s) ->`）書く。続けて、引数の数だけ名前か `_` を並べる。パターンは書けない。一つの `handle` に、同じ操作の節を二つ書くと誤りとする。
- `resume` は、`handle` の節の中に直接書く。節の中のラムダの中、`lazy` の本体の中、`match` のガードの中、プレースホルダを含む呼び出しの呼ばれる関数とプレースホルダでない引数の中、節の外に書くと誤りとする。ガードやプレースホルダの引数の中に書いた `handle` の節の中には、その節の `resume` を書ける。
- `uses` には、ほかのモジュールのエフェクトを、モジュールの名前で修飾して書く（`Logging.Log`、`Console.Write`）。同じモジュールで宣言したエフェクトは修飾せずに書く。
- エフェクトの名前を、宣言したモジュールと同じ名前にすると誤りとする。操作の名前が、同じモジュールのトップレベルの関数や定数の名前と同じときも誤りとする。
- ハンドラを他の言語の書き方（`with handler do …` など、式を読む位置の先頭に `with` を書いてハンドラを付けようとした形）で書いたとき、節を `when 操作(引数):` と書いたときは、`handle … with case … -> … end handle` の形を修正案として示す。

```text
effect Log
  function write(message: String) -> Unit
end effect

function sumPrices(items: List[Integer]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(xs: items, initial: 0, f: lambda(acc, value) return acc + value end lambda)
end function

function total(items: List[Integer]) -> Integer uses Console.Write
  return handle
    sumPrices(items)
  with
    case write(message) ->
      Console.writeErrorLine(message)
      resume(())
  end handle
end function
```

この例は、`import Benitoite.Unofficial.IO.Console` を書いたモジュールの中にあるとする。

### 属性（初回リリース版）

【決定】トップレベルの宣言の前に、属性を書ける。評価の意味を変える属性は `@builtin` と `@external` だけであり、`@builtin` は本体のない関数、`@external` は本体のない関数と右辺のない型の宣言に付ける。`@extensible` は型検査での使用条件を変え、`@opaque` は名前解決で内部表現の使用を宣言モジュールに限る。ほかの属性は、型付けと評価の意味を変えず、処理系や道具が宣言をどう扱うかを表す。理由: 本体を別の実装から与える宣言を属性で表し、予約語を増やさないためである。

文法の `TopItem` を次のように改める。それまでの節で定めた `TopItem` の選択肢のうち、import の宣言以外を `Decl` にまとめ、その前に属性を書けるようにする。後の節は、`Decl` に選択肢を加える。

```text
TopItem     = ImportDecl | AttrDecl .
AttrDecl    = { Attribute [ NL ] } Decl .
Attribute   = "@" LowerIdent [ "(" CommaList(StringLit) ")" ] .
Visibility  = "public" [ "(" "package" ")" ] .
Decl        = [ Visibility ] FnDecl
            | [ Visibility ] DataDecl
            | [ Visibility ] RecordDecl
            | [ Visibility ] TraitDecl
            | [ Visibility ] EffectDecl
            | ImplDecl .
```

- 属性は、宣言の前の行か、同じ行の宣言の前に書く。一つの宣言に複数の属性を書ける。
- 属性の引数は、文字列補間を含まない文字列リテラルに限る。
- 属性の名前は小文字識別子であり、`external`・`test`・`deprecated`・`builtin`・`extensible`・`opaque` 自体は予約しない。
- 利用者のソースに書ける属性は次の五つに限る。ほかの名前の属性は誤りとし、診断は書ける属性の一覧を示す。一つの宣言に同じ属性を二度書くと誤りとする。
- 標準ライブラリのソースでは、組み込みの関数を宣言する属性 `@builtin("名前")` も書ける。`@builtin` を付けた関数の宣言は、`Body "end" "function"` を書かず、シグネチャ（`Uses` まで）で終える（[標準ライブラリ](../03-interop/03-06-stdlib.md)の「標準ライブラリのソースの書き方」）。利用者のソースに書くと誤りとする。

| 属性 | 付けられる宣言 | 意味 |
|---|---|---|
| `@external("wasm", "パス", "名前")` | 型パラメータを持たないトップレベルの関数（外部の型を含む場合だけ `uses State`）と、右辺のない `type` | コンポーネントが関数の本体か型の実体を与える。`public` または `public(package)` と `@deprecated` を併用でき、`@test`・`@builtin` は併用できない |
| `@opaque` | `public`・`public(package)` の `data`・レコード | 型名と値の受け渡しを公開し、構成子・欄・更新・内部表現のパターンの使用を宣言モジュールに限る |
| `@extensible` | `data`・レコード | 定義したパッケージの外から照合するとき、将来の形を覆うガードのない変数か `_` を必要とする（[代数的データ型とパターンマッチ](01-05-data-types.md#拡張可能な型)） |
| `@test`、`@test("説明")` | 関数 | テストの関数である（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)） |
| `@deprecated("理由と移行先")` | 関数・定数・型・型の別名・レコード・型クラス・エフェクト | 非推奨である。文字列は一つだけ書き、省略できない。空の文字列（`@deprecated("")`）は誤りとする |

【決定】`@extensible` は引数を取らない。`@extensible()` も引数 0 個として受理し、フォーマッタは括弧を維持する。文字列引数を付けると E0817、文字列以外の引数は E0220、重複は E0803、`data`・レコード以外の宣言への指定は E0802 とする。同じ属性に引数と適用先の誤りがあれば、先に検出する引数の誤りだけを報告する。構成子の前の属性は認めず、E0201 とする。`@deprecated` と併用できる。

【決定】`@opaque` は引数を取らず、`@opaque()` も引数0個として受理して括弧を維持する。引数があればE0818（文字列以外はE0220）、重複はE0803、`data`・レコード以外への指定はE0802、非公開宣言への指定はE0820とする。引数と適用先の誤りが重なれば、引数の誤りを先に報告する。`@extensible`・`@external` との併用は後の属性の位置でE0819とし、`@deprecated` との併用は認める。

【方針】`@deprecated` を付けた宣言を、その宣言の外から名前で参照すると、処理系は警告を出し、属性の文字列を示す。警告は検査と実行を止めない。標準ライブラリの宣言も `@deprecated` を使う。警告の診断コードは[診断エンジン](../02-impl/02-10-diagnostics.md)で定める。

```text
@deprecated("use String.split instead")
public function splitWords(s: String) -> List[String]
  return String.split(s: s, separator: " ")
end function
```

LLM が他の言語の属性の書き方（`#[test]`、`[<Test>]`、`@Test` など）で書いたときは、Benitoite の書き方を修正案として示す。

### 外部の関数の宣言

【決定】`@external` を付けた関数は、本体と `end function` を書かず、戻り値の型で宣言を終える。引数と戻り値には具体的な型を書く。型パラメータ（エフェクト変数と制約を含む）は書けない。型に外部の型を含む場合は `uses State` を書き、それ以外の場合は `uses` を書けない。属性の三つの引数は、種類（`"wasm"` だけ）、コンポーネントの相対パス、書き出した関数の名前である。[外部の関数](../03-interop/03-10-external-functions.md)が、パスと型の照合を定める。

【決定】第 3 引数に `#` があれば、最後の `#` より前をインターフェースの書き出しの名前、後をその中の関数の名前とする。前半と後半は空にできない。`#` がなければ world の直下の関数の名前とする。理由: 同じ属性の形で、関数をまとめたインターフェースの書き出しも指定できるようにするためである。

【決定】`@external("wasm", "パス", "書き出しの名前") type 名前` は、右辺のない外部の型の宣言である。型パラメータを持たず、`public`・`public(package)` と `@deprecated` を付けられる。`@test`・`@builtin` は付けられない。第 3 引数は、関数と同じ区切りの規則で resource を指す。`@external` のない右辺のない `type` は誤りとする。理由: 外部の型の実体をコンポーネントが与えることを宣言に示し、通常の型の別名と区別するためである。

### 定数（初回リリース版）

【決定】トップレベルに `const` で定数を宣言できる。定数の値は、プログラムを実行する前に定まる定数式に限る。

```text
Decl        = ... | [ Visibility ] ConstDecl .
ConstDecl   = "const" LowerIdent ":" Type "=" Expr .
```

```text
const maxRetries: Integer = 3
public const defaultPort: Integer = 8000 + 80
const greeting: String = "hello, ${defaultPort}"
const primaryColors: List[Color] = [Color.Red, Color.Green, Color.Blue]
const statusNames: Map[Integer, String] = Map.fromList([Pair(200, "OK"), Pair(404, "Not Found")])
```

- 型の注釈は省略できない。定数は型パラメータを持たない。
- `=` の右辺の式は、定数式でなければならない。定数式に書けるのは、基本型（`Decimal` を含む）のリテラル、ほかの定数の名前、構成子の適用、レコードの構築、リストのリテラル、`Pair`・`Triple` の構築、基本型の演算子（算術、比較、論理、`div`・`mod`）、定数式だけを埋め込んだ文字列補間、`Map.fromList`・`Set.fromList`・`Map.empty()`・`Set.empty()` の呼び出し（引数は定数式に限る）である。それら以外の関数の呼び出し、ラムダ、`if`、`match`、`block`、`lazy`、`with`、`handle`、`try` は書けない。定数式でない式を書くと誤りとし、診断は、引数のない関数として書く方法を修正案として示す。
- 定数式の `Map.fromList` の引数に同じ鍵の組が二つ以上あるとき、`Set.fromList` の引数に同じ要素が二つ以上あるときは誤りとする。`Map` と `Set` のリテラルの構文はない。
- 定数は、名前で参照する。関数として呼ぶ書き方（`maxRetries()`）は型の誤りになり、診断は括弧を外す書き方を示す。
- 定数の値の計算、宣言の順序と循環、名前の衝突は[名前・スコープ・モジュール](01-03-names-modules.md)と[評価意味論](01-08-evaluation.md)で定める。パターンの変数と定数の名前の規則は[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

【決定】関数本体の `Regex.compile` の直接呼び出しでは、同じ定数式の範囲で得られる `source` を追加検査し、不正な正規表現を拒否する。Scopeの `checkHost`・`checkPath`・`checkEndpoint` も既知の引数を追加検査する。これらの関数と `Regex.compile` 自体はトップレベルの定数式に加えない。追加検査の型と予算の扱いは[型システム](01-06-type-system.md)の「定数の型（初回リリース版）」で定める。

### 型の別名（初回リリース版）

【決定】トップレベルに `type 名前 = 型` で型の別名を宣言できる。別名は、右辺の型と同じ型を表す。

```text
Decl        = ... | [ Visibility ] AliasDecl .
AliasDecl   = "type" UpperIdent [ TypeParams ] "=" Type .
```

```text
type UserId = Integer
type Validator[T] = function(value: T) -> Result[T, String]
```

- `type` は型の別名だけに使う。代数的データ型は `data` で宣言する。`type 名前` の後に `=` を書かずに構成子を並べたとき（`type Shape … end type`）は、構文エラーとし、診断は `data` と書く修正案を示す。
- 別名は、型を書く位置でだけ使える。別名で修飾して構成子や関数を参照すること（`UserId.toString`）はできない。
- 別名の型付けの規則（再帰の禁止、型パラメータ、公開）は[型システム](01-06-type-system.md)の「型の別名（初回リリース版）」で定める。
- LLM が他の言語の形（Haskell や OCaml の `type T = A | B`、Elm の `type alias`、Kotlin や Swift の `typealias`）で書いたときは、Benitoite の書き方を修正案として示す。`type T = A | B` の `|` は字句として受け付けない記号である（[字句構造](01-01-lexical.md)の「演算子と区切り記号」）ので、診断は、`data` の宣言に構成子を一行に一つずつ並べる書き方を示す。

### ドキュメントコメント（初回リリース版）

【決定】宣言の説明を `///` のドキュメントコメントで、モジュールの説明を `//!` のドキュメントコメントで書く。ドキュメントコメントの字句は[字句構造](01-01-lexical.md)の「コメント」で定める。

```text
//! Utilities for reading the application config.

import Benitoite.Unofficial.IO.File

/// Reads the port number from the config file.
///
/// Returns `Result.Error` when the file does not contain a number.
public function readPort(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Integer.parse(String.trim(text)) |> Option.okOr(o: _, error: "not a number")
end function

record Server
  /// The TCP port to listen on.
  port: Integer
end record
```

- 連続する `///` の行を一つの説明とし、その直後の宣言に結び付ける。説明と宣言の間には、空の行と普通のコメントの行を置けない。属性を付けた宣言では、説明、属性、宣言の順に書く。
- `///` を付けられる宣言は、トップレベルの宣言（関数、定数、型、型の別名、レコード、型クラス、エフェクト）と、型の構成子、レコードのフィールド、型クラスのメソッド、エフェクトの操作である。`implement` の中の関数にも付けられる。ファイル単位の `uses` には付けられず、その前の説明を後の関数へ引き継がない。
- `//!` は、ファイルの 1 行目から書き始める。ファイルの先頭の U+FEFF とシェバンの行（[字句構造](01-01-lexical.md)の「シェバンの行（初回リリース版）」）があるときは、その次の行から書き始める。`//!` の前には空白とタブだけを置ける。空の行や普通のコメントを前に置くと、import の宣言より前でも、上の位置以外の `//!` として扱う。空の行を挟まずに続く `//!` の行を、一つの説明とする。空の行を挟んだ後の `//!` は、上の位置以外の `//!` として扱う。
- ファイルが `//!` の説明だけからなり、import の宣言もほかの宣言も持たないときは、誤りとせず、宣言のない空のモジュールとする。
- 上の位置以外（関数の本体の中、ファイルの最後の `///`、ファイルの先頭の外の `//!` など）にドキュメントコメントを書くと、構文エラーとする。診断は、普通のコメント `//` に書き換えることを修正案として示す。
- 説明の中身は Markdown として扱い、通常の構文解析では本文の形式を検査しない。処理系は、説明を宣言に結び付けて保持する。説明を宣言の型とともに示す MCP サーバと LSP サーバは、初回リリース版に含めない。
- LLM が他の言語の書き方（`/** … */`、`{-| … -}`、`(** … *)`、`@doc`）で説明を書いたときは、`///` の書き方を修正案として示す。
- 説明の例を抽出する読み取り用APIは、行頭の空白に続く三連バッククォートのフェンスを読み取る。`benitoite test`・`benitoite check`・`benitoite error`、および直後に`output`を伴う`benitoite`を例とする。無印・`text`などのフェンスは対象外として数える。本文は接頭辞直後の一空白だけを除き、残る字下げと空行を保つ。
- `benitoite error`の直後には`diagnostic`を必須とし、各非空行を診断報告に含むことを期待する。コメントの例では、少なくとも一行を実在するEコードだけの行とする。`output`は最終改行を含む標準出力の期待であり、その直後の`stderr`を省いた場合は空の標準エラー出力を期待する。コメント内の`files`と非零の`exit`期待は認めない。未知の`benitoite`の印、閉じ忘れ、期待の欠落などは明示的な抽出時にE0260とする。
- 通常の`test`は説明を実行用として抽出しない。読み取りAPIはコード・期待・元位置の一覧を返し、実行は行わない。

### 初回リリース版の文法の全体

【方針】次の文法は、前述の「文法」に、見出しに「（初回リリース版）」を付けた各節で加えた規則と置き換えた規則を反映したものに、初回リリース版の後に加えた「ファイルの先頭の部分」と「外部の関数の宣言」の規則を加えたものである。各規則の意味と、決定の確度は各節に従う。トップレベルの宣言の順序（先頭のメタデータ、import の宣言、ファイル単位のエフェクトの宣言、ほかの宣言の順）も、この文法で表す。

`@external` を付けた宣言は、関数なら `FnDecl` の代わりに `ExternalFnDecl`、外部の型なら `ExternalTypeDecl` で書く。`Uses` の条件は「外部の関数の宣言」に従う。

```text
(* プログラム *)
Program     = [ NL ] [ ProgramBody [ NL ] ] .
ProgramBody = Header [ NL Items ]
            | Items .
Header      = HeaderItem { NL HeaderItem } .
HeaderItem  = "language" StringLit
            | "dependency" UpperIdent NL { HeaderField NL } "end" "dependency"
            | "package" UpperIdent NL { HeaderField NL } "end" "package" .
HeaderField = LowerIdent StringLit .
Items       = ImportDecl [ NL Items ]
            | FileUses [ NL Decls ]
            | Decls .
FileUses    = "uses" EffectRef { "," EffectRef } [ "," ] .
Decls       = AttrDecl { NL AttrDecl } .
AttrDecl    = { Attribute [ NL ] } Decl .
Attribute   = "@" LowerIdent [ "(" CommaList(StringLit) ")" ] .
Visibility  = "public" [ "(" "package" ")" ] .
Decl        = [ Visibility ] FnDecl
            | [ Visibility ] ExternalFnDecl
            | [ Visibility ] ExternalTypeDecl
            | [ Visibility ] ConstDecl
            | [ Visibility ] DataDecl
            | [ Visibility ] AliasDecl
            | [ Visibility ] RecordDecl
            | [ Visibility ] TraitDecl
            | [ Visibility ] EffectDecl
            | ImplDecl .

(* import の宣言 *)
ImportDecl  = "import" UpperIdent { "." UpperIdent } [ "as" UpperIdent ] .

(* 関数の宣言 *)
FnDecl      = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              "->" Type [ Uses ] Body "end" "function" .
ExternalFnDecl = "function" LowerIdent "(" CommaList(Param) ")" "->" Type [ Uses ] .
ExternalTypeDecl = "type" UpperIdent .
FnTypeParams = "[" FnTypeParam { "," FnTypeParam } [ "," ] "]" .
FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" Constraint { "&" Constraint } ] .
Constraint  = QualUpper | LowerIdent .
TypeParamDecl = UpperIdent [ "[" "_" { "," "_" } "]" ] .
Param       = LowerIdent ":" Type .
Uses        = "uses" EffectRef { "," EffectRef } .
EffectRef   = QualUpper [ "[" CommaList(Type) "]" ] .

(* 定数の宣言 *)
ConstDecl   = "const" LowerIdent ":" Type "=" Expr .

(* 型・型の別名・レコード・型クラスの宣言 *)
DataDecl    = "data" UpperIdent [ TypeParams ] LineList(Variant) "end" "data" .
AliasDecl   = "type" UpperIdent [ TypeParams ] "=" Type .
TypeParams  = "[" UpperIdent { "," UpperIdent } [ "," ] "]" .
Variant     = UpperIdent [ "(" CommaList(Type) ")" ] .
RecordDecl  = "record" [ NL ] UpperIdent [ TypeParams ] LineList(Field) "end" "record" .
Field       = LowerIdent ":" Type .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl [ ":" QualUpper { "&" QualUpper } ] "]"
              LineList(MethodSig) "end" "trait" .
MethodSig   = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] .
ImplDecl    = "implement" [ FnTypeParams ] QualUpper "[" Type "]" LineList(FnDecl) "end" "implement" .
EffectDecl  = "effect" UpperIdent LineList(OpSig) "end" "effect" .
OpSig       = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type .

(* 型 *)
Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(NamedType) ")" "->" Type [ Uses ]
            | "(" Type ")" .
QualUpper   = UpperIdent { "." UpperIdent } .

(* 文の並びと文 *)
Body        = LineList(Stmt) .
Stmt        = BindStmt | Expr .
BindStmt    = ( "bind" | "shadow" ) Pattern [ ":" Type ] "<-" Expr .

(* 式 *)
Expr        = "return" Expr
            | "try" TryOperand [ "or" TryAction ]
            | PipeExpr .
TryOperand  = Expr . (* 同じ深さの or return / or die の手前で終える。詳細は try の節。 *)
TryAction   = "return" | "die" [ "(" Expr ")" ] .
PipeExpr    = OrExpr { "|>" OrExpr } .
OrExpr      = AndExpr { "or" AndExpr } .
AndExpr     = CmpExpr { "and" CmpExpr } .
CmpExpr     = AddExpr [ CmpOp AddExpr ] .
CmpOp       = "=" | "<>" | "<" | "<=" | ">" | ">=" .
AddExpr     = MulExpr { ( "+" | "-" ) MulExpr } .
MulExpr     = UnaryExpr { ( "*" | "/" | "div" | "mod" ) UnaryExpr } .
UnaryExpr   = ( "-" | "not" ) UnaryExpr | CallExpr .
CallExpr    = Primary { "(" CommaList(Arg) ")" } .
Arg         = [ LowerIdent ":" ] ( Expr | "_" ) .
NamedType   = LowerIdent ":" Type .
Primary     = Literal
            | InterpString
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "[" [ ListElem { "," ListElem } [ "," ] ] "]"
            | IfExpr
            | MatchExpr
            | Lambda
            | RecordExpr
            | "block" Body "end" "block"
            | "lazy" Body "end" "lazy"
            | WithExpr
            | HandleExpr
            | "resume" "(" Expr ")" .
Literal     = IntLit | FloatLit | DecimalLit | StringLit | CharLit | "true" | "false" .
InterpString = StrStart Expr [ ":" FormatSpec ] { StrMid Expr [ ":" FormatSpec ] } StrEnd .
FormatSpec  = [ Align ] [ Sign ] [ "#" ] [ "0" ] [ Width ] [ Precision ] [ Kind ] .
Align       = "<" | ">" | "^" .
Sign        = "+" .
Width       = NonZeroDigit { Digit } .
Precision   = "." Digit { Digit } .
Kind        = "d" | "b" | "o" | "x" | "X" | "f" | "s" | "c" .
NonZeroDigit = "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" .
Digit       = "0" | NonZeroDigit .
ListElem    = Expr | ".." Expr .
Name        = { UpperIdent "." } ( LowerIdent | UpperIdent ) .
RecordExpr  = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")" .
FieldArg    = LowerIdent ":" Expr .
IfExpr      = "if" Expr "then" Body { "else" "if" Expr "then" Body } [ "else" Body ] "end" "if" .
MatchExpr   = "match" Expr "with" [ NL ] Arm { NL Arm } [ NL ] "end" "match" .
Arm         = "case" Pattern { "," Pattern } [ "if" Expr ] "->" ArmBody .
ArmBody     = Stmt { NL Stmt } .
Lambda      = LambdaHeader ( Body "end" "lambda" | ShortBody ) .
LambdaHeader = "lambda" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] .
ShortBody   = Stmt . (* ラムダ全体を同じ物理行に収め、外側の区切りを残す *)
LambdaParam = LowerIdent [ ":" Type ] .
WithExpr    = "with" WithBind { "," WithBind } "do" Body "end" "with" .
WithBind    = LowerIdent "=" Expr .
HandleExpr  = "handle" Body "with" [ NL ] HandleArm { NL HandleArm } [ NL ] "end" "handle" .
HandleArm   = "case" OpName "(" CommaList(OpParam) ")" "->" ArmBody .
OpName      = { UpperIdent "." } LowerIdent .
OpParam     = LowerIdent | "_" .

(* パターン *)
Pattern     = "_"
            | LowerIdent
            | [ "-" ] IntLit
            | StringLit
            | CharLit
            | "true" | "false"
            | "(" ")"
            | QualUpper [ "(" CommaList(Pattern) ")" ]
            | QualUpper "(" FieldPat { "," FieldPat } [ "," ".." ] [ "," ] ")"
            | RangeEnd ".." RangeEnd
            | "[" [ ListPatElem { "," ListPatElem } [ "," ] ] "]" .
FieldPat    = LowerIdent ":" Pattern .
RangeEnd    = [ "-" ] IntLit | CharLit .
ListPatElem = Pattern | ".." [ LowerIdent ] .
```

この文法だけでは決まらない規則は、次のとおりである。いずれも、この文法で読める並びのうちの一部を誤りとするか、読み方を一つに決めるものである。

| 規則 | 定める箇所 |
|---|---|
| 字句の分け方、キーワードと予約語、`NL` を置く位置 | [字句構造](01-01-lexical.md) |
| `uses` の後の並びを最長一致で読むこと | 本章の「文法」の後の【決定】 |
| `QualUpper` の直後の `(` の次の字句で、レコードの構築・パターンと、構成子の呼び出し・パターンを見分けること | 本章の「レコード（初回リリース版）」 |
| `end` の後の構文の名前が、閉じるブロックの構文と一致すること | 本章の「ブロックと文」 |
| `bind` と `shadow` を書ける条件、束縛が見えている局所の名前を隠さないこと | 本章の「ブロックと文」、[名前・スコープ・モジュール](01-03-names-modules.md)の「シャドーイング」 |
| `with` の次の字句で、分岐の並びの始まりとリソーススコープを見分けること | 本章の「リソーススコープ（初回リリース版）」、[字句構造](01-01-lexical.md)の「改行による区切り」 |
| `else` の直後の `if` を、同じ `if` の続きとして読むこと | 本章の「条件分岐」 |
| import の名前に当たるファイル、`as` の要否、修飾した名前の各段が指すもの | 本章の「モジュールと import（初回リリース版）」、[名前・スコープ・モジュール](01-03-names-modules.md) |
| 型クラスの名前を書かない `implement` への診断 | 本章の「型クラス（初回リリース版）」 |
| 操作の宣言の `uses` とエフェクト変数、`resume` を書く位置、同じ操作の節の重複、エフェクトと操作の名前の衝突 | 本章の「エフェクトの宣言とハンドラ（初回リリース版）」 |
| 属性の名前、属性を付けられる宣言、属性の引数の文字列、同じ属性の重複 | 本章の「属性（初回リリース版）」 |
| 定数の右辺を定数式に限ること | 本章の「定数（初回リリース版）」 |
| ドキュメントコメントを書ける位置 | 本章の「ドキュメントコメント（初回リリース版）」 |
| レコードの宣言にフィールドが一つ以上あること（構文エラー） | 本章の「レコード（初回リリース版）」 |
| ガードの `if` の読み方、選択肢の変数の束縛、範囲の両端の種類、リストのパターンの `..` の数 | 本章の「パターンの拡張（初回リリース版）」、[代数的データ型とパターンマッチ](01-05-data-types.md) |
| `return` を書く位置と、`return` で抜けない道筋、`return` の後の文 | 本章の「`return`」、[型システム](01-06-type-system.md) |
| パイプとプレースホルダの展開 | 本章の「パイプ」「部分適用のプレースホルダ」、[コア計算と脱糖](01-12-core-calculus.md) |

### 初回リリース版に含めない構文

初回リリース版の構文は、「文法」と、見出しに「（初回リリース版）」を付けた本章の各節で定めたものですべてである。その後、「ファイルの先頭の部分」と「外部の関数の宣言」の構文と、数のリテラルの接尾辞を加えた。本章に定めていない構文は、初回リリース版に含めない。たとえば、繰り返しの構文（`for`・`while`・`loop`）、例外を捕らえる構文、括弧のタプル、`Map` と `Set` のリテラルは持たない。

### 例

「文法」の範囲の構文で書いたプログラムの例を示す。ライブラリの名前と `uses IO` は、前述の「プログラムと宣言」と同じく仮の書き方である。

```text
data Shape
  Circle(Float)
  Rect(Float, Float)
end data

function area(s: Shape) -> Float
  return match s with
    case Shape.Circle(r) -> 3.14159 * r * r
    case Shape.Rect(w, h) -> w * h
  end match
end function

function totalArea(shapes: List[Shape]) -> Float
  return shapes
    |> List.map(f: lambda(value) return area(value))
    |> List.fold(initial: 0.0, f: lambda(acc, value) return acc + value end lambda)
end function

function main() -> Unit uses IO
  bind shapes <- [Shape.Circle(1.0), Shape.Rect(2.0, 3.0)]
  Console.writeLine(Float.toString(totalArea(shapes)))
end function
```
