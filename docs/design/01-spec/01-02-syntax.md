# 構文

## 目的と範囲

字句の並びから、プログラム・宣言・式・パターン・型の構造を組み立てる規則を定める。対象は、文法（EBNF）、演算子の優先順位と結合性、ブロックと文、ドット記法とパイプ、部分適用のプレースホルダである。

構文が表す意味（型付けと評価）は、それぞれの章で定める。本章が定めるのは、正しく構造を組み立てられる字句の並びと、構文上の糖衣をどう展開するかだけである。

本章は、初回リリース版の構文を定める。基本の文法を「文法」の節に示し、そこに加える構文（モジュールと import、レコード、文字列補間、型クラス、`try`、明示遅延、リソーススコープ、エフェクトの宣言とハンドラ、属性、パターンの拡張、定数、型の別名、ドキュメントコメント）を、見出しに「（初回リリース版）」を付けた節に書く。全体の文法は「初回リリース版の文法の全体」にまとめる。本章で定めない構文は、初回リリース版に含めない（後述の「初回リリース版に含めない構文」）。

## 前提

字句は[字句構造](01-01-lexical.md)に従う。文法の中の `NL` は、字句構造の「改行による区切り」で置かれる改行字句 NEWLINE を表す。

表層構文の骨格の四点は【決定】である。ドットはモジュールと型名による修飾に限り、値に続くドットを認めない。トップレベルの関数は型シグネチャを必ず書く。文は改行で区切る。関数は `f(x, y)` の形で適用し、カリー化しない。外部に作用する処理を直接形式で書き、関数の型に `uses` でエフェクトを書くことも【決定】である。ブロックを `end` と構文の名前で閉じる形、`lambda`、`if … then`、演算子の書き方、戻り値の型の `->`、`bind` と `shadow`、`data`、`match … with` も【決定】である。基本の文法のそれ以外の具体的な規則は【方針】である。見出しに「（初回リリース版）」を付けた節の書き方は、各節に付けた確度に従う。

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
            | "function" "(" CommaList(Type) ")" "->" Type [ Uses ]
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
Arg         = Expr | "_" .
Primary     = Literal
            | Name
            | "(" ")"
            | "(" Expr ")"
            | "[" CommaList(Expr) "]"
            | IfExpr
            | MatchExpr
            | Lambda .
Literal     = IntLit | FloatLit | StringLit | CharLit | "true" | "false" .
Name        = LowerIdent
            | UpperIdent
            | UpperIdent "." ( LowerIdent | UpperIdent ) .

IfExpr      = "if" Expr "then" Body { "else" "if" Expr "then" Body } [ "else" Body ] "end" "if" .
MatchExpr   = "match" Expr "with" [ NL ] Arm { NL Arm } [ NL ] "end" "match" .
Arm         = "case" Pattern "->" ArmBody .
ArmBody     = Stmt { NL Stmt } .
Lambda      = "lambda" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] Body "end" "lambda" .
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

【決定】型は括弧で囲める。括弧で囲んだ型は、囲まない型と同じ型を表す。`uses` は、その直前にある最も内側の関数の型に付き、`uses` の後のコンマ区切りの並びはできるだけ長く読む（最長一致、longest match）。この並びにエフェクトでない名前（`Integer` など）が来たときは、構文エラーではなく名前解決の誤りとし、診断は関数の型を括弧で囲む書き方を修正案として示す。並びの 2 番目以降の名前の直後に `[` が続くとき（`List[Integer]` など、型引数を伴う名前）は、`uses` の並びに書けない形なので構文エラーとし、診断は同じく関数の型を括弧で囲む書き方を修正案として示す。

```text
function((function() -> Unit uses Console.Write), Integer) -> Unit        // function(function() -> Unit uses Console.Write, Integer) -> Unit は誤り
function f() -> (function() -> Integer uses Console.Write) uses Console.Write ... end function // 戻り値の型が uses を持つ関数の型のとき
```

1 行目の括弧を外すと、`Integer` を `uses` の並びの一部として読む。2 行目の戻り値の型の括弧を外すと、`function f() -> function() -> Integer uses Console.Write ... end function` の `uses Console.Write` は戻り値の型（内側の関数の型）に付き、`f` 自身は純粋な関数になる。

### プログラムと宣言

【方針】基本の文法では、プログラムは一つのソースファイルであり、トップレベルには関数の宣言と型の宣言を置く。複数のファイルからなるプログラムを書く構文と、トップレベルに置けるほかの宣言は、後述の「モジュールと import（初回リリース版）」以降の節で定める。トップレベルに式や `bind`・`shadow` を置くことはできない。プログラムの実行を始める関数（エントリポイント）は[評価意味論](01-08-evaluation.md)で定める。名前の有効範囲（トップレベルの宣言どうしの参照、局所束縛のシャドーイングなど）は[名前・スコープ・モジュール](01-03-names-modules.md)で定める。

【決定】トップレベルの関数の宣言は、すべての引数の型と戻り値の型を書かなければならない。戻り値の型は、引数の並びの後の `->` に続けて書く。戻り値がない関数も `-> Unit` と書く。関数の型も、同じく `->` の後に戻り値の型を書く（`function(Integer) -> Integer`）。戻り値の型を `:` の後に書いた宣言（`function double(x: Integer): Integer`）は構文エラーとし、診断は `->` と書く修正案を示す。外部に作用する関数は、戻り値の型の後に `uses` とエフェクトの名前を書く。`uses` を書かない関数は純粋である。

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

【決定】ブロックは、改行で区切った文の並びである。関数の宣言とラムダの本体、`if` と `match` の分岐、`with` と `lazy` と `handle` の本体、`handle` の節がブロックである。ブロックを波括弧で囲まない。ブロックを持つ構文は、キーワードで始まり、`end` とその構文の名前（`end function`・`end lambda`・`end if`・`end match` など）で閉じる。文は `bind` か `shadow` による束縛（束縛の文）か、式である。

閉じる語が、閉じる構文と一致しないとき（`if` を `end match` で閉じたなど）は、構文エラーとし、診断は、どの構文を閉じるべきかを示す。LLM が波括弧でブロックを書いたとき（`{`・`}` は字句として受け付けない記号。[字句構造](01-01-lexical.md)の「演算子と区切り記号」）は、`end` と構文の名前で閉じる書き方を修正案として示す。

- ブロックの最後の文が式であれば、その式の値がブロックの値になる。最後の文が束縛の文であるか、ブロックが空であれば、ブロックの値は Unit である。
- 最後の文以外の位置に置いた式（式文）は、Unit 型でなければならない。これは型検査で検査する（[型システム](01-06-type-system.md)）。値を捨てるときは `bind _ <- 式` と書く。
- 関数の宣言とラムダの本体のブロックは、値を `return` で返す（後述の「`return`」）。本体のブロックの最後の文も式文として扱い、`return` でない式は Unit 型でなければならない。

式文を Unit 型に限るのは、計算した値を気付かずに捨てる誤りと、改行の位置の誤り（[字句構造](01-01-lexical.md)の「改行による区切り」）を、実行前に検出するためである。

【決定】束縛の文は、名前か `_` に、`<-` の右の式の値を束縛する。その位置で局所の名前として見えていない名前を束縛するときは `bind x <- e` と書き、見えている局所の名前を隠すときは `shadow x <- e` と書く。どちらを書けるかの規則は[名前・スコープ・モジュール](01-03-names-modules.md)の「シャドーイング」で定める。型注釈は `bind x: Integer <- e` の形で書け、省略すると推論する。束縛の文の左辺には、名前と `_` のほかに、必ず照合するパターンを書ける（後述の「組と `bind`・`shadow` のパターン（初回リリース版）」）。値によって分岐するときは `match` を使う。

文の頭に他の言語の束縛の書き方 `let x = e` を書いたときは、構文エラーとし、診断は `bind x <- e`（名前が局所の名前として見えていれば `shadow x <- e`）を修正案として示す。`let` はキーワードではない。

### `return`

【決定】関数の宣言とラムダの本体は、`return 式` で値を返す。

- `return e` は、`e` を評価し、`return` を含む最も内側の関数の宣言かラムダの呼び出しを終えて、`e` の値を返す。本体の途中にも書ける。
- `return` の後には、必ず式を書く。`return` の直後の改行は空白として扱う（[字句構造](01-01-lexical.md)の「改行による区切り」の規則 2）ので、`return` だけの行の次の行は、`return` の式として読む。戻り値の型が Unit の関数から途中で抜けるときは `return ()` と書く。
- `return e` は式であり、どの型の式が書ける位置にも書ける（`match` の分岐の本体など）。`return` は右の式全体にかかる。`return x |> f` は `return f(x)` である。
- 本体の終わりに達したときは、`()` を返す。戻り値の型が Unit でない関数とラムダは、本体のどの道筋でも `return` で抜けなければならない。抜けない道筋があれば誤りとし、診断は `return` を書き足す箇所を示す。
- 必ず抜ける文（`return e`、両方の分岐が必ず抜ける `if`、すべての分岐が必ず抜ける `match` など。[型システム](01-06-type-system.md)で定める）の後に、同じブロックの文を続けると誤りとする。その文は実行されないからである。
- `lazy` のブロックの中には、内側のラムダの中を除き、`return` を書けない（後述の「明示遅延（初回リリース版）」）。

```text
function sign(x: Integer) -> Integer
  if x < 0 then
    return -1
  end if
  return if x = 0 then 0 else 1 end if
end function
```

`if` と `match` の分岐は、最後の式の値を値とする。`return` を書くのは、関数の宣言とラムダの本体から抜けるときだけである。

### 条件分岐

【決定】`if` は `if 条件 then 文の並び else 文の並び end if` の形で書き、いつも `end if` で閉じる。条件は括弧で囲まない。

- 分岐には、一つの式も、改行で区切った複数の文も書ける（`return if x = 0 then 0 else 1 end if`）。
- `else` の直後の `if` は、同じ `if` の続きの分岐として読み、`end if` は一つで閉じる（`if a then … else if b then … else … end if`）。`else` の分岐に別の `if` を入れ子にしたいときは、`else` の後で改行してから `if` を書いても同じく続きとして読むので、入れ子の `if` を括弧で囲む（`else (if b then … end if)`）。
- `then` の直後と `else` の前後の改行は空白として扱う（[字句構造](01-01-lexical.md)の「改行による区切り」の規則 2・3）。

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

パターンの中の小文字識別子は新しい変数の束縛であり、大文字識別子はデータ構成子との照合である。データ構成子は、式の中と同じく型名で修飾して書く。浮動小数のリテラルはパターンに書けない。パターンの意味と、網羅性・到達不能の検査は[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

### ラムダ

【決定】ラムダ（無名関数）は、`lambda` の後に引数の並びと本体を書き、`end lambda` で閉じる。`function` は、関数の宣言と関数の型に使う。関数の宣言と違い、引数の型と戻り値の型は省略でき、省略すると推論する。戻り値の型は、関数の宣言と同じく `->` の後に書く。`uses` は、戻り値の型を書いたときだけ、その後に書ける。`uses` を書かなければ、エフェクトを本体から推論する（[型システム](01-06-type-system.md)）。本体は、関数の宣言と同じく `return` で値を返す。

ラムダの引数には `_` を書けない（`lambda(_, x) return x end lambda` は構文エラー）。使わない引数には、`_unused` のように `_` で始まる名前を付ける（[字句構造](01-01-lexical.md)）。

本体の文を複数の行に書くときも、`lambda` のブロックの中の改行は文の区切りとして働く。関数の呼び出しの丸括弧の中に書いたときも同じである（[字句構造](01-01-lexical.md)の「改行による区切り」）。LLM が Python の形で `lambda x: x + 1` と書いたときは、`lambda(x) return x + 1 end lambda` の形を修正案として示す。C 系の波括弧の書き方 `fn(x) { … }` で書いたときは、`lambda(x) … end lambda` の形を修正案として示す。

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

`return` と `try`（後述の「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」）は、式の先頭に書き、右の式全体（パイプを含む）にかかる。どの演算子よりも弱く結び付く。

比較演算子は結合しない。`a < b < c` は構文エラーであり、`a < b and b < c` と書くよう診断で示す。

【決定】等しいを `=`、等しくないを `<>`、論理演算子を `and`・`or`・`not` と書く。`=` は、`with` の束縛、定数の宣言、型の別名の宣言にも使う。これらの `=` は名前（と型）の直後にだけ現れるので、比較の `=` と一通りに読み分けられる。局所の束縛の文は `<-` で書くので、比較の結果を束縛する文（`bind ok <- a = b`）は括弧なしで読める。書き換えのつもりで `x = 5` と書いた式文は、値が `Boolean` の式文として型検査の誤りになり、診断は変数を書き換えられないことと、`shadow x <- 5` で同じ名前を束縛し直す書き方を示す。

【決定】整数の除算を `div`、剰余を `mod` と書く。`/` のオペランドは、`Float` と `Decimal` に限る（[型システム](01-06-type-system.md)の演算子の型の表）。

各演算子の型と意味は、[基本型の意味論](01-04-types-basic.md)と[型システム](01-06-type-system.md)で定める。

### ドット記法

【決定】ドット `.` は、モジュールの修飾と、型名によるデータ構成子の修飾にだけ使う。`.` の左には大文字識別子で書いたモジュール名か型名を、右にはそのモジュールが定める名前か、その型の構成子の名前を書く（`List.map`、`String.lines`、`Shape.Circle`）。prelude の `Option` と `Result` の構成子も、型名で修飾して書く（`Option.Some`、`Result.Error`）。

修飾に使えるモジュールは、標準ライブラリのモジュールと、import で取り込んだモジュールである（後述の「モジュールと import（初回リリース版）」、[名前・スコープ・モジュール](01-03-names-modules.md)）。

値に続けてドットを書く形（`xs.map(f)`、`s.length`）は構文エラーである。このとき、診断は `|>` を使った書き方（`xs |> List.map(f)`）を修正案として示さなければならない。レコードのフィールドも、ドットではなく型のモジュールの関数で取り出す。

### パイプ

【決定】パイプ `x |> e` は、左の値を右の関数に渡す糖衣である。

【方針】`x |> e` は、右辺 `e` の形によって次のように展開する。

1. `e` が関数の呼び出し `f(a1, ..., an)` であり、その直接の引数 `a1, ..., an` のどれもプレースホルダ `_` でなければ、`x` を第 1 引数に加えた `f(x, a1, ..., an)` に展開する。引数の中に入れ子になった呼び出しのプレースホルダは数えない（`x |> f(g(_))` は `f(x, g(_))` に展開する）。`e` が呼び出しを重ねた形（`g(a)(b)`）であれば、最も外側（最後）の呼び出しに加える。
2. それ以外であれば、`e` を関数として `x` に適用した `e(x)` に展開する。`e` の直接の引数にプレースホルダを含む呼び出しの場合もこの規則による。次節の展開によって `e` は関数になるので、`x` はプレースホルダの位置に入る。

【決定】右辺 `e` が括弧で囲んだ式であれば、中身によらず規則 2 により `e(x)` に展開する。`x |> (f(a))` は `(f(a))(x)` になる。関数を返す呼び出しの結果に `x` を渡すときは、このように右辺を括弧で囲む。

```text
lines |> List.filter(nonEmpty)    // List.filter(lines, nonEmpty)
lines |> List.length              // List.length(lines)
x |> clamp(0, _, 100)             // clamp(0, x, 100)
x |> lambda(v) return v * 2 end lambda              // (lambda(v) return v * 2 end lambda)(x)
x |> (makeHandler(config))        // (makeHandler(config))(x)
```

`try` は右の式全体にかかるので、パイプの結果にかけるときは、パイプの先頭に書く（`try x |> f(a)` は `try f(x, a)`）。

`x` と `e` をどの順に評価するかは[評価意味論](01-08-evaluation.md)で定める。

### 部分適用のプレースホルダ

【決定】部分適用は、プレースホルダ `_` を使って明示する。関数はカリー化しないので、引数が足りない呼び出しは部分適用にならず、型検査の誤りになる。

【方針】関数の呼び出し `f(a1, ..., an)` の引数のうち、`_` そのものであるものをプレースホルダと呼ぶ。プレースホルダを一つ以上含む呼び出しは、プレースホルダを左から順に新しい引数に置き換えたラムダに展開する。展開で使う引数の名前は、ソースのどこにも現れない新しい名前である。下の例の `p1`・`p2` は説明のための表記であり、`f(_, p1)` のようにソースに同じ名前があっても、その名前と取り違えることはない。

```text
clamp(0, _, 100)    // lambda(p1) return clamp(0, p1, 100) end lambda
between(_, lo, _)   // lambda(p1, p2) return between(p1, lo, p2) end lambda
```

- プレースホルダが属するのは、それを直接の引数とする呼び出しだけである。`f(g(_))` は `f(lambda(p1) return g(p1) end lambda)` と展開する。
- 呼び出しの直接の引数以外の位置（`_ + 1` など）に `_` を書くと、構文エラーとする。
- 展開後のラムダの本体には、呼び出される関数 `f` と、プレースホルダでない引数の式がそのまま入る。これらの式を評価する時期は、展開後のラムダに従う（[評価意味論](01-08-evaluation.md)）。

### モジュールと import（初回リリース版）

【決定】一つのソースファイルを一つのモジュールとする。モジュールの名前は根のディレクトリからのパスで決まり、ほかのモジュールは `import` の宣言に名前を書いて取り込む。トップレベルの宣言に `public` を付けると、取り込んだ側から使える。トップレベルには値の定義を置けない。ただし、定数式に限った定数は置ける（後述の「定数（初回リリース版）」）。トップレベルに置けるのは、import の宣言、関数の宣言、定数の宣言、型の宣言、型の別名の宣言、レコードの宣言、型クラスの宣言、エフェクトの宣言、実装の宣言である。

文法の次の規則を改める。ほかの規則は「文法」と同じである。

```text
TopItem     = ImportDecl | [ "public" ] FnDecl | [ "public" ] DataDecl .
ImportDecl  = "import" UpperIdent { "." UpperIdent } [ "as" UpperIdent ] .

Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(Type) ")" "->" Type [ Uses ]
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

### レコード（初回リリース版）

【決定】レコードは `record` で宣言し、フィールドを「名前: 型」の形で一行に一つずつ並べる。値は名前付きの引数で作り、一部のフィールドを変えた値は `..` で作る。フィールドの値は、型のモジュールの関数で取り出す。レコードの宣言は、フィールドごとに同じ名前の取り出す関数をその型のモジュールに加える。レコードの型と値の意味は[代数的データ型とパターンマッチ](01-05-data-types.md)の「レコード（初回リリース版）」で定める。

文法に次の規則を加える。

```text
TopItem     = ... | [ "public" ] RecordDecl .
RecordDecl  = "record" UpperIdent [ TypeParams ] LineList(Field) "end" "record" .
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
InterpString = StrStart Expr { StrMid Expr } StrEnd .
```

パターンには `StringLit` だけを書けるので、文字列補間は書けない。

```text
Console.writeLine("${name} is ${age} years old")
```

### 型クラス（初回リリース版）

【決定】型クラスは `trait` で宣言し、`implement` で実装する。関数の型パラメータには `[T: Show]` の形で制約を付ける。一つの型パラメータに複数の制約を付けるときは、`&` でつなぐ（`[T: Show & equality]`）。型クラスの規則は[型システム](01-06-type-system.md)で定める。

【決定】制約の位置には、型クラスの名前のほかに、組み込みの制約 `equality`（等値の型である）と `key`（鍵の型である）を書ける。型クラスは、`trait Monoid[T: Semigroup]` の形で上位の型クラスを持てる。

文法に次の規則を加え、`FnTypeParam` を改める。

```text
TopItem     = ... | [ "public" ] TraitDecl | ImplDecl .
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
- `implement` の中の関数の宣言には、`public` を付けない。`implement` にも `public` を付けない。
- 【方針】実装は、プログラム全体で有効である。どのモジュールで型クラスの制約を解くときも、プログラムを構成するすべてのモジュールの実装から探す。孤立した実装と重なる実装を誤りとするので、使える実装は一つに決まる（[型システム](01-06-type-system.md)）。
- `M.C.m`（三つ目が小文字の名前）は、取り込んだモジュール `M` の型クラス `C` のメソッド `m` を表す。
- `implement Person ... end implement` のように、型クラスの名前を書かない `implement` は構文エラーとする。診断は、トップレベルの関数として書く方法を修正案として示す。

### `Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）

【決定】前置の `try` を設ける。意味は[エラー処理](01-09-errors.md)で定める。文法の規則は次のように改める。

```text
Expr        = "return" Expr
            | "try" Expr
            | PipeExpr .
```

- `try` は右の式全体（パイプを含む）にかかる。`try e |> f(_)` は `try f(e)` である。
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

【決定】`match` の分岐には、コンマで区切って複数のパターン（選択肢）を並べ、パターンの後に `if 条件` のガードを書ける（`case 1, 2 -> …`、`case n if n > 0 -> …`）。パターンには、範囲とリストのパターンを書ける。意味と網羅性の規則は[代数的データ型とパターンマッチ](01-05-data-types.md)の「パターンの拡張（初回リリース版）」で定める。

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
      return [first, ..insertByCount(pair, rest)]
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
TopItem     = ... | [ "public" ] EffectDecl .
EffectDecl  = "effect" UpperIdent LineList(OpSig) "end" "effect" .
OpSig       = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type .
Primary     = ... | HandleExpr | "resume" "(" Expr ")" .
HandleExpr  = "handle" Body "with" [ NL ] HandleArm { NL HandleArm } [ NL ] "end" "handle" .
HandleArm   = "case" OpName "(" CommaList(OpParam) ")" "->" ArmBody .
OpName      = { UpperIdent "." } LowerIdent .
OpParam     = LowerIdent | "_" .
Uses        = "uses" QualUpper { "," QualUpper } .
```

- 操作の宣言には `uses` を書けない。操作の型パラメータの並びに、エフェクト変数と型構成子を表す型パラメータ（`F[_]`）は宣言できない。操作の型パラメータの制約には、組み込みの制約（`equality`・`key`）だけを書ける。
- `handle` の本体は、節の並びを始める `with` までである。節の本体は、`match` の分岐と同じく、次の `case` か `end handle` までであり、節の値は最後の式の値である。
- `case` の後には、操作の名前を、式の中で操作を呼ぶときと同じ形で書く。同じモジュールで宣言したエフェクトの操作は修飾せずに（`case write(message) ->`）、ほかのモジュールの操作はモジュールの名前で修飾して（`case Logging.write(message) ->`、`case Console.writeLine(s) ->`）書く。続けて、引数の数だけ名前か `_` を並べる。パターンは書けない。一つの `handle` に、同じ操作の節を二つ書くと誤りとする。
- `resume` は、`handle` の節の中に直接書く。節の中のラムダの中と `lazy` の本体の中、節の外に書くと誤りとする。
- `uses` には、ほかのモジュールのエフェクトを、モジュールの名前で修飾して書く（`Logging.Log`、`Console.Write`）。同じモジュールで宣言したエフェクトは修飾せずに書く。
- エフェクトの名前を、宣言したモジュールと同じ名前にすると誤りとする。操作の名前が、同じモジュールのトップレベルの関数や定数の名前と同じときも誤りとする。
- ハンドラを他の言語の書き方（`with handler do …` など、式を読む位置の先頭に `with` を書いてハンドラを付けようとした形）で書いたとき、節を `when 操作(引数):` と書いたときは、`handle … with case … -> … end handle` の形を修正案として示す。

```text
effect Log
  function write(message: String) -> Unit
end effect

function sumPrices(items: List[Integer]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(items, 0, lambda(acc, x) return acc + x end lambda)
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

【決定】トップレベルの宣言の前に、属性を書ける。属性は、宣言の型付けと評価の意味を変えず、処理系や道具がその宣言をどう扱うかを表す。宣言の意味を変えるものは、キーワードで表す。

文法の `TopItem` を次のように改める。それまでの節で定めた `TopItem` の選択肢のうち、import の宣言以外を `Decl` にまとめ、その前に属性を書けるようにする。後の節は、`Decl` に選択肢を加える。

```text
TopItem     = ImportDecl | AttrDecl .
AttrDecl    = { Attribute [ NL ] } Decl .
Attribute   = "@" LowerIdent [ "(" CommaList(StringLit) ")" ] .
Decl        = [ "public" ] FnDecl
            | [ "public" ] DataDecl
            | [ "public" ] RecordDecl
            | [ "public" ] TraitDecl
            | [ "public" ] EffectDecl
            | ImplDecl .
```

- 属性は、宣言の前の行か、同じ行の宣言の前に書く。一つの宣言に複数の属性を書ける。
- 属性の引数は、文字列補間を含まない文字列リテラルに限る。
- 利用者のソースに書ける属性は次の二つに限る。ほかの名前の属性は誤りとし、診断は書ける属性の一覧を示す。一つの宣言に同じ属性を二度書くと誤りとする。
- 標準ライブラリのソースでは、組み込みの関数を宣言する属性 `@builtin("名前")` も書ける。`@builtin` を付けた関数の宣言は、`Body "end" "function"` を書かず、シグネチャ（`Uses` まで）で終える（[標準ライブラリ](../03-interop/03-06-stdlib.md)の「標準ライブラリのソースの書き方」）。利用者のソースに書くと誤りとする。

| 属性 | 付けられる宣言 | 意味 |
|---|---|---|
| `@test`、`@test("説明")` | 関数 | テストの関数である（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)） |
| `@deprecated("理由と移行先")` | 関数・定数・型・型の別名・レコード・型クラス・エフェクト | 非推奨である。文字列は一つだけ書き、省略できない。空の文字列（`@deprecated("")`）は誤りとする |

【方針】`@deprecated` を付けた宣言を、その宣言の外から名前で参照すると、処理系は警告を出し、属性の文字列を示す。警告は検査と実行を止めない。標準ライブラリの宣言も `@deprecated` を使う。警告の診断コードは[診断エンジン](../02-impl/02-10-diagnostics.md)で定める。

```text
@deprecated("use String.split instead")
public function splitWords(s: String) -> List[String]
  return String.split(s, " ")
end function
```

LLM が他の言語の属性の書き方（`#[test]`、`[<Test>]`、`@Test` など）で書いたときは、Benitoite の書き方を修正案として示す。

### 定数（初回リリース版）

【決定】トップレベルに `const` で定数を宣言できる。定数の値は、プログラムを実行する前に定まる定数式に限る。

```text
Decl        = ... | [ "public" ] ConstDecl .
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
- `=` の右辺の式は、定数式でなければならない。定数式に書けるのは、基本型（`Decimal` を含む）のリテラル、ほかの定数の名前、構成子の適用、レコードの構築、リストのリテラル、`Pair`・`Triple` の構築、基本型の演算子（算術、比較、論理、`div`・`mod`）、定数式だけを埋め込んだ文字列補間、`Map.fromList`・`Set.fromList`・`Map.empty()`・`Set.empty()` の呼び出し（引数は定数式に限る）である。それら以外の関数の呼び出し、ラムダ、`if`、`match`、`lazy`、`with`、`handle`、`try` は書けない。定数式でない式を書くと誤りとし、診断は、引数のない関数として書く方法を修正案として示す。
- 定数式の `Map.fromList` の引数に同じ鍵の組が二つ以上あるとき、`Set.fromList` の引数に同じ要素が二つ以上あるときは誤りとする。`Map` と `Set` のリテラルの構文はない。
- 定数は、名前で参照する。関数として呼ぶ書き方（`maxRetries()`）は型の誤りになり、診断は括弧を外す書き方を示す。
- 定数の値の計算、宣言の順序と循環、名前の衝突は[名前・スコープ・モジュール](01-03-names-modules.md)と[評価意味論](01-08-evaluation.md)で定める。パターンの変数と定数の名前の規則は[代数的データ型とパターンマッチ](01-05-data-types.md)で定める。

### 型の別名（初回リリース版）

【決定】トップレベルに `type 名前 = 型` で型の別名を宣言できる。別名は、右辺の型と同じ型を表す。

```text
Decl        = ... | [ "public" ] AliasDecl .
AliasDecl   = "type" UpperIdent [ TypeParams ] "=" Type .
```

```text
type UserId = Integer
type Validator[T] = function(T) -> Result[T, String]
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
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Integer.parse(String.trim(text)) |> Option.okOr(_, "not a number")
end function

record Server
  /// The TCP port to listen on.
  port: Integer
end record
```

- 連続する `///` の行を一つの説明とし、その直後の宣言に結び付ける。説明と宣言の間には、空の行と普通のコメントの行を置けない。属性を付けた宣言では、説明、属性、宣言の順に書く。
- `///` を付けられる宣言は、トップレベルの宣言（関数、定数、型、型の別名、レコード、型クラス、エフェクト）と、型の構成子、レコードのフィールド、型クラスのメソッド、エフェクトの操作である。`implement` の中の関数にも付けられる。
- `//!` は、ファイルの 1 行目から書き始める。ファイルの先頭の U+FEFF とシェバンの行（[字句構造](01-01-lexical.md)の「シェバンの行（初回リリース版）」）があるときは、その次の行から書き始める。`//!` の前には空白とタブだけを置ける。空の行や普通のコメントを前に置くと、import の宣言より前でも、上の位置以外の `//!` として扱う。空の行を挟まずに続く `//!` の行を、一つの説明とする。空の行を挟んだ後の `//!` は、上の位置以外の `//!` として扱う。
- ファイルが `//!` の説明だけからなり、import の宣言もほかの宣言も持たないときは、誤りとせず、宣言のない空のモジュールとする。
- 上の位置以外（関数の本体の中、ファイルの最後の `///`、ファイルの先頭の外の `//!` など）にドキュメントコメントを書くと、構文エラーとする。診断は、普通のコメント `//` に書き換えることを修正案として示す。
- 説明の中身は Markdown として扱い、処理系は検査しない。処理系は、説明を宣言に結び付けて保持する。説明を宣言の型とともに示す MCP サーバと LSP サーバは、初回リリース版に含めない。
- LLM が他の言語の書き方（`/** … */`、`{-| … -}`、`(** … *)`、`@doc`）で説明を書いたときは、`///` の書き方を修正案として示す。
- 説明に書いた例を実行する仕組みは設けない。

### 初回リリース版の文法の全体

【方針】初回リリース版の文法の全体は次のとおりである。前述の「文法」に、見出しに「（初回リリース版）」を付けた各節で加えた規則と置き換えた規則を反映したものであり、各規則の意味と、決定の確度は各節に従う。トップレベルの宣言の順序（import の宣言、ほかの宣言の順）も、この文法で表す。

```text
(* プログラム *)
Program     = [ NL ] [ Items [ NL ] ] .
Items       = ImportDecl [ NL Items ]
            | Decls .
Decls       = AttrDecl { NL AttrDecl } .
AttrDecl    = { Attribute [ NL ] } Decl .
Attribute   = "@" LowerIdent [ "(" CommaList(StringLit) ")" ] .
Decl        = [ "public" ] FnDecl
            | [ "public" ] ConstDecl
            | [ "public" ] DataDecl
            | [ "public" ] AliasDecl
            | [ "public" ] RecordDecl
            | [ "public" ] TraitDecl
            | [ "public" ] EffectDecl
            | ImplDecl .

(* import の宣言 *)
ImportDecl  = "import" UpperIdent { "." UpperIdent } [ "as" UpperIdent ] .

(* 関数の宣言 *)
FnDecl      = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")"
              "->" Type [ Uses ] Body "end" "function" .
FnTypeParams = "[" FnTypeParam { "," FnTypeParam } [ "," ] "]" .
FnTypeParam = "effect" UpperIdent
            | TypeParamDecl [ ":" Constraint { "&" Constraint } ] .
Constraint  = QualUpper | LowerIdent .
TypeParamDecl = UpperIdent [ "[" "_" { "," "_" } "]" ] .
Param       = LowerIdent ":" Type .
Uses        = "uses" QualUpper { "," QualUpper } .

(* 定数の宣言 *)
ConstDecl   = "const" LowerIdent ":" Type "=" Expr .

(* 型・型の別名・レコード・型クラスの宣言 *)
DataDecl    = "data" UpperIdent [ TypeParams ] LineList(Variant) "end" "data" .
AliasDecl   = "type" UpperIdent [ TypeParams ] "=" Type .
TypeParams  = "[" UpperIdent { "," UpperIdent } [ "," ] "]" .
Variant     = UpperIdent [ "(" CommaList(Type) ")" ] .
RecordDecl  = "record" UpperIdent [ TypeParams ] LineList(Field) "end" "record" .
Field       = LowerIdent ":" Type .
TraitDecl   = "trait" UpperIdent "[" TypeParamDecl [ ":" QualUpper { "&" QualUpper } ] "]"
              LineList(MethodSig) "end" "trait" .
MethodSig   = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] .
ImplDecl    = "implement" [ FnTypeParams ] QualUpper "[" Type "]" LineList(FnDecl) "end" "implement" .
EffectDecl  = "effect" UpperIdent LineList(OpSig) "end" "effect" .
OpSig       = "function" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type .

(* 型 *)
Type        = QualUpper [ "[" Type { "," Type } [ "," ] "]" ]
            | "function" "(" CommaList(Type) ")" "->" Type [ Uses ]
            | "(" Type ")" .
QualUpper   = UpperIdent { "." UpperIdent } .

(* 文の並びと文 *)
Body        = LineList(Stmt) .
Stmt        = BindStmt | Expr .
BindStmt    = ( "bind" | "shadow" ) Pattern [ ":" Type ] "<-" Expr .

(* 式 *)
Expr        = "return" Expr
            | "try" Expr
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
Arg         = Expr | "_" .
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
            | "lazy" Body "end" "lazy"
            | WithExpr
            | HandleExpr
            | "resume" "(" Expr ")" .
Literal     = IntLit | FloatLit | DecimalLit | StringLit | CharLit | "true" | "false" .
InterpString = StrStart Expr { StrMid Expr } StrEnd .
ListElem    = Expr | ".." Expr .
Name        = { UpperIdent "." } ( LowerIdent | UpperIdent ) .
RecordExpr  = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")" .
FieldArg    = LowerIdent ":" Expr .
IfExpr      = "if" Expr "then" Body { "else" "if" Expr "then" Body } [ "else" Body ] "end" "if" .
MatchExpr   = "match" Expr "with" [ NL ] Arm { NL Arm } [ NL ] "end" "match" .
Arm         = "case" Pattern { "," Pattern } [ "if" Expr ] "->" ArmBody .
ArmBody     = Stmt { NL Stmt } .
Lambda      = "lambda" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] Body "end" "lambda" .
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

初回リリース版の構文は、「文法」と、見出しに「（初回リリース版）」を付けた本章の各節で定めたものですべてである。本章に定めていない構文は、初回リリース版に含めない。たとえば、繰り返しの構文（`for`・`while`・`loop`）、例外を捕らえる構文、括弧のタプル、`Map` と `Set` のリテラルは持たない。

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
    |> List.map(area)
    |> List.fold(0.0, lambda(acc, a) return acc + a end lambda)
end function

function main() -> Unit uses IO
  bind shapes <- [Shape.Circle(1.0), Shape.Rect(2.0, 3.0)]
  Console.writeLine(Float.toString(totalArea(shapes)))
end function
```
