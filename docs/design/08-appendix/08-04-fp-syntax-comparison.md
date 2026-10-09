# 関数型言語の構文の比較


- 状態: 草稿
- 関連ADR: [0004](../decisions/0004-surface-syntax-skeleton.md), [0005](../decisions/0005-direct-style-effects.md), [0007](../decisions/0007-constructors-and-list.md), [0010](../decisions/0010-shared-namespace-and-shadowing.md), [0050](../decisions/0050-pipe-with-parenthesized-rhs.md), [0053](../decisions/0053-private-by-default-with-pub.md), [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0057](../decisions/0057-record-declaration-construction-update.md), [0060](../decisions/0060-trait-and-impl-syntax.md), [0092](../decisions/0092-unabbreviated-keywords.md), [0094](../decisions/0094-return-type-after-colon.md), [0096](../decisions/0096-explicit-return.md), [0097](../decisions/0097-prefix-try.md), [0099](../decisions/0099-qualified-option-result-constructors.md), [0102](../decisions/0102-pair-and-triple.md), [0108](../decisions/0108-keyword-blocks-closed-by-end.md), [0109](../decisions/0109-lambda-keyword.md), [0110](../decisions/0110-if-then-end-if.md), [0111](../decisions/0111-case-of-when.md), [0112](../decisions/0112-pascal-style-operators.md), [0118](../decisions/0118-effect-handlers.md), [0121](../decisions/0121-pattern-extensions.md), [0125](../decisions/0125-doc-comments.md), [0126](../decisions/0126-import-by-module-name.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0256](../decisions/0256-data-keyword-for-algebraic-types.md), [0257](../decisions/0257-match-with-case-arms.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-014](../open-issues.md#open-014)
- 移行元: なし

## 目的と範囲

Benitoite の基本の構文を、九つの関数型言語（OCaml、F#、Haskell、Elm、Gleam、Rust、Flix、Scala 3、Roc）の構文と並べて示す。読み手は、ほかの関数型言語を知っていて Benitoite の書き方を知りたい人と、Benitoite の構文の判断がほかの言語とどう違うかを確かめたい人である。

比べる構文は、関数の宣言、局所の束縛、条件分岐、パターンで分岐する式、ラムダ、パイプ、代数的データ型、レコード、`Option` と `Result`、エラーの伝播、型クラス、エフェクト、モジュールと import、ブロックの区切り、コメントの 15 項目である。各項目の節には、全言語を並べた表を一つと、同じ処理を各言語で書いた短い例を置く。最後の節で、Benitoite の構文の選択と、それを決めた ADR をまとめる。

本章は事実の比較だけを記録する。Benitoite の構文の判断の理由は、各 ADR に書く。Rust は関数型言語ではないが、Benitoite の処理系の実装言語であり、LLM がよく書く言語なので比較に含める。

## 前提

Benitoite の構文は、初回リリース版の言語仕様（[構文](../01-spec/01-02-syntax.md)、[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)、[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)、[型システム](../01-spec/01-06-type-system.md)、[エフェクト](../01-spec/01-07-effects.md)、[エラー処理](../01-spec/01-09-errors.md)）に従う。Benitoite の例は、どれも構文の章の「初回リリース版の文法の全体」で読めることを、処理系のテスト（処理系のクレートの `tests/spec_examples.rs`）で確かめている。例の中のライブラリの関数（`List.filter` など）と利用者の関数（`parse` など）は、構文を示すためのものである。

ほかの言語の事実は、2026-09-29 に、各言語の公式の文書（仕様書、マニュアル、公式サイトの入門、公式のリポジトリの文書とソース）で確かめた。各言語の例は、文書の例と文法に照らして書いたものであり、処理系で実行して確かめてはいない。一次資料で確かめられなかった事項には【要検証】を付け、末尾の「未決事項」にまとめる。

確かめた版と、主な出典は次のとおりである。

| 言語 | 確かめた版 | 読んだ文書 |
|---|---|---|
| OCaml | 5.5.1（2026-09-05） | OCaml マニュアル（latest。5.5） |
| F# | F# 10（.NET 10） | Microsoft Learn の F# 言語リファレンス、F# 言語仕様の草稿（F# 10 向け） |
| Haskell | Haskell 2010、GHC 9.14.1、base 4.22.0.0 | Haskell 2010 Report、GHC 9.14.1 User's Guide、base の Haddock、Haddock の記法の文書 |
| Elm | 0.19.2（2026-07-06。0.19.1 からの言語の変更はない）、elm/core 1.0.5 | elm-lang.org の構文の頁、公式ガイド、elm/core のソース、elm/compiler のヒントの頁 |
| Gleam | 1.18.0（2026-07-29）、gleam_stdlib 1.0.5 | Language Tour、公式のチートシート、gleam_stdlib の HexDocs |
| Rust | 1.98.1（2026-09-03） | The Rust Reference と The Rust Programming Language（リポジトリの開発中の版） |
| Flix | 0.77.0（2026-09-28） | Flix の本（doc.flix.dev。リポジトリ flix/book のコミット `bcc7968`）、v0.77.0 の標準ライブラリと字句解析器のソース |
| Scala 3 | 3.9.0（2026-09-03） | Scala 3 Book（docs.scala-lang のコミット `f9b365a`）、Scala 3 Reference と言語仕様（タグ 3.9.0） |
| Roc | 番号の付いた版はない（0.1 に達していない）。リポジトリ roc-lang/roc のコミット `b2b9541`（2026-09-29） | 新しいコンパイラ向けの入門（roc-lang.org/tutorial の転送先）、言語リファレンス（作成中と明記）、全構文のテストのファイル、組み込みのモジュールのソース |

Roc は構文を変えている途中であり、言語リファレンスも作成中と明記している。本章の Roc の例は、2026-09-29 の新しいコンパイラ向けの入門と全構文のテストのファイルの書き方に従う。以前の版の書き方（`\x ->` のラムダ、`when … is`、`Result`、ability）とは違う。

出典の URL は次のとおりである。

- OCaml: https://ocaml.org/releases 、https://ocaml.org/manual/latest/ の expr.html・names.html・core.html・coreexamples.html・moduleexamples.html・modules.html・effects.html・bindingops.html・lex.html・doccomments.html・ocamldoc.html・comp.html、api/Stdlib.html・api/Result.html・api/Result.Syntax.html・api/List.html
- F#: https://learn.microsoft.com/en-us/dotnet/fsharp/whats-new/fsharp-10 、https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/ の functions/・match-expressions・pattern-matching・conditional-expressions-if-then-else・discriminated-unions・records・options・results・computation-expressions・modules・import-declarations-the-open-keyword・verbose-syntax・xml-documentation・interfaces・generics/statically-resolved-type-parameters・symbol-and-operator-reference/、https://fsharp.github.io/fslang-spec/namespaces-and-modules/ 、https://fsharp.github.io/fslang-spec/lexical-analysis/
- Haskell: https://www.haskell.org/ghc/ 、https://www.haskell.org/onlinereport/haskell2010/ の haskellch2・3・4・5・9、https://downloads.haskell.org/ghc/latest/docs/users_guide/using-warnings.html 、同 exts/overloaded_record_dot.html・exts/control.html、https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Data-Function.html 、https://haskell-haddock.readthedocs.io/latest/markup.html
- Elm: https://github.com/elm/compiler/releases/tag/0.19.2 、https://elm-lang.org/docs/syntax 、https://guide.elm-lang.org 、https://github.com/elm/core 、https://github.com/elm/compiler/blob/master/hints/shadowing.md 、https://github.com/elm/compiler/blob/master/hints/missing-patterns.md
- Gleam: https://gleam.run/news/ 、https://tour.gleam.run/everything/ 、https://gleam.run/cheatsheets/gleam-for-elm-users/ 、https://gleam.run/cheatsheets/gleam-for-rust-users/ 、https://gleam.run/news/v0.33-exhaustive-gleam/ 、https://gleam.run/documentation/conventions-patterns-and-anti-patterns/ 、https://gleam-stdlib.hexdocs.pm/gleam/result.html
- Rust: https://blog.rust-lang.org/releases/ 、https://doc.rust-lang.org/reference/ （items/functions、statements、expressions/if-expr、match-expr、closure-expr、operator-expr、struct-expr、items/enumerations、items/traits、items/modules、items/use-declarations、comments、whitespace、names/preludes）、https://doc.rust-lang.org/book/ （3.1、3.3、5.1、6.1、6.2、7.5、9.2、10.2、13.1 章）
- Flix: https://github.com/flix/flix/releases 、https://doc.flix.dev/ （functions、if-then-else、pattern-matching、enums、records、traits、effects-and-handlers、primitive-effects、monadic-for-yield、modules、redundancy、quick-reference、for-llms）、https://github.com/flix/flix/blob/v0.77.0/main/src/ca/uwaterloo/flix/language/phase/Lexer.scala
- Scala 3: https://www.scala-lang.org/download/ 、https://docs.scala-lang.org/scala3/book/ （methods-most、control-structures、fun-anonymous-functions、types-adts-gadts、domain-modeling-tools、fp-functional-error-handling、ca-type-classes、packaging-imports）、https://docs.scala-lang.org/scala3/reference/ （contextual/givens、changed-features/imports、other-new-features/indentation、experimental/capture-checking）、Scala 3 の言語仕様（01、02、06、08 章）、https://www.scala-lang.org/api/current/scala/util/ChainingOps.html
- Roc: https://www.roc-lang.org/tutorial （転送先 https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md ）、https://github.com/roc-lang/roc/tree/b2b9541c425da4b15f82b2ba85fed0f8384a9ea5/docs/langref 、同コミットの test/echo/all_syntax_test.roc と src/build/roc/Builtin.roc

一部の事実は、[他の言語の調査記録](08-03-language-surveys.md)にも記録している（パターンの拡張、ドキュメントコメント、import の書き方、構成子の修飾、エフェクトハンドラ）。

## 仕様

各節の例は、同じ処理を各言語で書いたものである。表の中の「—」は、その言語に当たる構文がないことを表す。

### 関数の宣言と呼び出し

二つの整数の和を返す関数 `add` を宣言し、`1` と `2` に適用する。

| 言語 | 宣言の形 | 型注釈 | 戻り値の型の位置 | 呼び出し | 値の返し方 |
|---|---|---|---|---|---|
| OCaml | `let add (x : int) (y : int) : int = …` | 省略できる（推論する） | 引数の後の `:` | `add 1 2` | 本体の式の値 |
| F# | `let add (x: int) (y: int) : int = …` | 省略できる（推論する） | 引数の後の `:` | `add 1 2` | 本体の式の値 |
| Haskell | 型シグネチャ `add :: Int -> Int -> Int` と等式 `add x y = …` | 省略できる | シグネチャの最後の `->` の後 | `add 1 2` | 本体の式の値 |
| Elm | 型注釈 `add : Int -> Int -> Int` と定義 `add x y = …` | 省略できる（ガイドは書くことを勧める） | 注釈の最後の `->` の後 | `add 1 2` | 本体の式の値 |
| Gleam | `fn add(a: Int, b: Int) -> Int { … }` | 省略できる | `->` の後 | `add(1, 2)` | 最後の式の値（`return` はない） |
| Rust | `fn add(a: i32, b: i32) -> i32 { … }` | 引数の型は必須。戻り値の型を省くと `()` | `->` の後 | `add(1, 2)` | 末尾の式の値 |
| Flix | `def add(x: Int32, y: Int32): Int32 = …` | トップレベルでは必須 | 引数の後の `:` | `add(1, 2)` | 本体の式の値 |
| Scala 3 | `def add(x: Int, y: Int): Int = …` | 引数の型は必須。戻り値の型は省略できる | 引数の後の `:` | `add(1, 2)` | 本体の式の値 |
| Roc | 型注釈 `add : I64, I64 -> I64` と `add = \|a, b\| …` | 省略できる | 注釈の `->` の後 | `add(1, 2)` | 本体の式の値 |
| Benitoite | `function add(x: Integer, y: Integer) -> Integer … end function` | トップレベルでは必須 | `->` の後 | `add(1, 2)` | `return` |

- 引数を空白で並べて適用する言語は、ML 系（OCaml、F#）と Haskell 系（Haskell、Elm）である。ほかの言語は、括弧とコンマで引数を並べる。
- Roc は、関数をラムダを名前に束縛して定義する（言語リファレンスの functions）。
- Benitoite は、関数の宣言の戻り値の型を、関数の型（`function(Integer, Integer) -> Integer`）と同じく `->` の後に書く（[ADR 0254](../decisions/0254-return-type-after-arrow.md)）。宣言で `->` を使うのは、Gleam と Rust と同じである。
- Benitoite は、戻り値の型が Unit でない関数を、本体のどの道筋でも `return` で抜けなければならないとする（[構文](../01-spec/01-02-syntax.md)の「`return`」）。

**OCaml**

```ocaml
let add (x : int) (y : int) : int = x + y
let r = add 1 2
```

**F#**

```fsharp
let add (x: int) (y: int) : int = x + y
let r = add 1 2
```

**Haskell**

```haskell
add :: Int -> Int -> Int
add x y = x + y

r = add 1 2
```

**Elm**

```elm
add : Int -> Int -> Int
add x y =
  x + y

r = add 1 2
```

**Gleam**

```gleam
fn add(a: Int, b: Int) -> Int {
  a + b
}

add(1, 2)
```

**Rust**

```rust
fn add(a: i32, b: i32) -> i32 {
    a + b
}

add(1, 2)
```

**Flix**

```flix
def add(x: Int32, y: Int32): Int32 = x + y

add(1, 2)
```

**Scala 3**

```scala
def add(x: Int, y: Int): Int = x + y

add(1, 2)
```

**Roc**

```roc
add : I64, I64 -> I64
add = |a, b| a + b

add(1, 2)
```

**Benitoite**

```text
function add(x: Integer, y: Integer) -> Integer
  return x + y
end function

function three() -> Integer
  return add(1, 2)
end function
```

Benitoite のトップレベルには式と束縛の文を置けない（[構文](../01-spec/01-02-syntax.md)の「プログラムと宣言」）ので、呼び出しを関数 `three` の中に書いた。

### 局所の束縛とシャドーイング

`x` に `1` を束縛し、同じ範囲で `x + 1` を同じ名前 `x` に束縛し直す。

| 言語 | 束縛の形 | 同じ範囲での同じ名前の束縛 | 束縛の構文の種類 |
|---|---|---|---|
| OCaml | `let x = … in e` | できる（後の束縛が前の束縛を隠す） | 式 |
| F# | `let x = …`（軽量構文では `in` を字下げで表す） | 関数の中ではできる。モジュールのトップレベルでは名前が一意でなければならない | 式 |
| Haskell | `let … in e`、`where` | `let` の束縛は互いに再帰的なので、`let x = x + 1` の右辺の `x` は自分自身を指す。入れ子の `let` で外側の名前を隠すことはでき、GHC の `-Wname-shadowing`（`-Wall` に含む）が警告する | 式 |
| Elm | `let … in e` | できない（シャドーイングを禁じる） | 式 |
| Gleam | `let x = …`（ブロックの中に並べる） | できる | ブロックの中の並び |
| Rust | `let x = …;` | できる | 文 |
| Flix | `let x = e; 続きの式` | できない（シャドーイングはコンパイルの誤り） | 式 |
| Scala 3 | `val x = …` | 同じブロックではできない。内側の範囲では外側の名前を隠せる | ブロックの中の定義 |
| Roc | `x = …` | できるが、警告を出す | 文 |
| Benitoite | `bind x <- …`（見えている局所の名前を隠すときは `shadow x <- …`） | `shadow` と書いたときだけできる（`bind` と書くと誤り） | 文 |

- Roc は、書き換えられる変数を `var $x = …` で宣言する。Scala 3 の書き換えられる変数は `var` である。Benitoite には書き換えられる変数はなく、可変のセルを標準ライブラリの関数で扱う（[エフェクト](../01-spec/01-07-effects.md)の「可変のセル（初回リリース版）」）。
- 名前を隠す束縛を、初めての束縛と別の語で書くのは、比べた言語の中で Benitoite だけである。ほかの言語は、同じ語で束縛し直して名前を隠すか、シャドーイングを禁じる（Elm、Flix）。Benitoite では、ラムダの引数やパターンの変数が、見えている局所の名前を隠すことも誤りである（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)の「シャドーイング」、[ADR 0255](../decisions/0255-bind-and-shadow.md)）。
- Benitoite の `bind` と `shadow` は再帰的な束縛ではなく、`shadow x <- x + 1` の右辺の `x` は、隠される前の `x` を指す（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)の「局所の束縛の有効範囲」）。

**OCaml**

```ocaml
let x = 1 in
let x = x + 1 in
x
```

**F#**

```fsharp
let f () =
    let x = 1
    let x = x + 1
    x
```

**Haskell**

```haskell
-- let の束縛は再帰的なので、別の名前を使う
g = let x = 1 in let x' = x + 1 in x'
```

**Elm**

```elm
-- シャドーイングを禁じるので、別の名前を使う
let
  x = 1
  y = x + 1
in
y
```

**Gleam**

```gleam
let x = 1
let x = x + 1
```

**Rust**

```rust
let x = 1;
let x = x + 1;
```

**Flix**

```flix
// シャドーイングは誤りなので、別の名前を使う
let x = 1;
let y = x + 1;
y
```

**Scala 3**

```scala
// 同じブロックで同じ名前を二度定義できないので、別の名前を使う
val x = 1
val y = x + 1
```

**Roc**

```roc
x = 1
x = x + 1        # 警告を出す
```

**Benitoite**

```text
bind x <- 1
shadow x <- x + 1
```

### 条件分岐

`x` が負なら `"negative"`、そうでなければ `"non-negative"` を値とする式を書く。

| 言語 | 形 | `else` の省略 | 条件の括弧 | 閉じる語 |
|---|---|---|---|---|
| OCaml | `if c then a else b` | できる（`else ()` とみなす） | 要らない | ない |
| F# | `if c then a else b`（`elif` もある） | できる（全体が unit 型になる） | 要らない | ない |
| Haskell | `if c then a else b` | できない | 要らない | ない |
| Elm | `if c then a else b` | できない | 要らない | ない |
| Gleam | — （`case` で `True` と `False` を照合する） | — | — | — |
| Rust | `if c { a } else { b }` | できる（値は `()`） | 要らない。分岐は `{ }` のブロックに限る | ない |
| Flix | `if (c) a else b` | 【要検証】 | 文書の例はすべて括弧を書く（必須かは【要検証】） | ない |
| Scala 3 | `if c then a else b`（`if (c) a else b` も書ける） | できる（`else ()` とみなす） | `then` を書く形では要らない | `end if` を書いてもよい |
| Roc | `if c a else b` | 本体の値が `{}` の場合を除き、できない | 要らない（`then` もない） | ない |
| Benitoite | `if c then a else b end if` | できる（Unit 型の式になる） | 要らない | `end if`（必須） |

- `if` は、Gleam を除くどの言語でも式である。Gleam は `if` の式を持たない（公式のチートシート「Gleam for Elm users」）。
- Benitoite は `else` の直後の `if` を同じ `if` の続きとして読み、`end if` を一つだけ書く（[構文](../01-spec/01-02-syntax.md)の「条件分岐」）。

**OCaml**

```ocaml
if x < 0 then "negative" else "non-negative"
```

**F#**

```fsharp
if x < 0 then "negative" else "non-negative"
```

**Haskell**

```haskell
if x < 0 then "negative" else "non-negative"
```

**Elm**

```elm
if x < 0 then "negative" else "non-negative"
```

**Gleam**

```gleam
case x < 0 {
  True -> "negative"
  False -> "non-negative"
}
```

**Rust**

```rust
if x < 0 { "negative" } else { "non-negative" }
```

**Flix**

```flix
if (x < 0) "negative" else "non-negative"
```

**Scala 3**

```scala
if x < 0 then "negative" else "non-negative"
```

**Roc**

```roc
if x < 0 "negative" else "non-negative"
```

**Benitoite**

```text
bind sign <- if x < 0 then "negative" else "non-negative" end if
```

### パターンで分岐する式とガード

整数の `Option` の値 `opt` を調べ、正の整数なら `"positive"`、そのほかの整数なら `"non-positive"`、値がなければ `"none"` とする。最初の分岐にガードを付ける。

| 言語 | 形 | 分岐の書き方 | ガード | 網羅していない分岐 |
|---|---|---|---|---|
| OCaml | `match e with …` | `\| p -> e` | `when` | 警告 8（既定で有効） |
| F# | `match e with …` | `\| p -> e` | `when` | 警告 FS0025 |
| Haskell | `case e of …` | `p -> e`（レイアウト） | `\| 条件` | `-Wincomplete-patterns` の警告。既定では出ず、`-W`・`-Wall` で有効になる |
| Elm | `case e of …` | `p -> e`（字下げを揃える） | — （文書にない。分岐の中で `if` を使う） | 誤り |
| Gleam | `case e { … }` | `p -> e` | `if`（ガードの中で関数を呼べない） | 誤り |
| Rust | `match e { … }` | `p => e,` | `if` | 誤り |
| Flix | `match e { … }` | `case p => e` | `if` | 誤り |
| Scala 3 | `e match …` | `case p => e` | `if` | 警告（実行時には `MatchError`） |
| Roc | `match e { … }` | `p => e`（一行に一つ） | `if` | 誤り（誤りがあっても実行できる） |
| Benitoite | `match e with … end match` | `case p -> e` | `if` | 誤り |

- 分岐の先頭に語を置く言語は、Flix と Scala 3 と Benitoite であり、どれも `case` を置く。OCaml と F# は `|` を置く。
- 式の始めを `match 対象 with` と書くのは、OCaml・F# と Benitoite である。Benitoite が分岐のパターンと本体の間に書く `->` は、OCaml・F#・Haskell・Elm・Gleam と同じ記号である（[ADR 0257](../decisions/0257-match-with-case-arms.md)）。
- Benitoite のガードの `if` は `end if` で閉じない（[構文](../01-spec/01-02-syntax.md)の「パターンの拡張（初回リリース版）」）。ガードの付いた分岐は、網羅したかどうかの判定で覆うものに数えない（[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)の「網羅性の検査」）。Roc の入門も、ガードの付いた分岐を網羅に数えないとする。
- Roc には組み込みの `Option` の型がない。Roc の例の `Some` と `None` は、宣言なしに使える構造的なタグである（言語リファレンスの tag-unions）。

**OCaml**

```ocaml
match opt with
| Some n when n > 0 -> "positive"
| Some _ -> "non-positive"
| None -> "none"
```

**F#**

```fsharp
match opt with
| Some n when n > 0 -> "positive"
| Some _ -> "non-positive"
| None -> "none"
```

**Haskell**

```haskell
case opt of
  Just n | n > 0 -> "positive"
  Just _         -> "non-positive"
  Nothing        -> "none"
```

**Elm**

```elm
case opt of
  Just n ->
    if n > 0 then "positive" else "non-positive"

  Nothing ->
    "none"
```

**Gleam**

```gleam
case opt {
  Some(n) if n > 0 -> "positive"
  Some(_) -> "non-positive"
  None -> "none"
}
```

**Rust**

```rust
match opt {
    Some(n) if n > 0 => "positive",
    Some(_) => "non-positive",
    None => "none",
}
```

**Flix**

```flix
match opt {
    case Some(n) if n > 0 => "positive"
    case Some(_)          => "non-positive"
    case None             => "none"
}
```

**Scala 3**

```scala
opt match
  case Some(n) if n > 0 => "positive"
  case Some(_)          => "non-positive"
  case None             => "none"
```

**Roc**

```roc
match opt {
    Some(n) if n > 0 => "positive"
    Some(_) => "non-positive"
    None => "none"
}
```

**Benitoite**

```text
bind label <- match opt with
  case Option.Some(n) if n > 0 -> "positive"
  case Option.Some(_) -> "non-positive"
  case Option.None -> "none"
end match
```

### ラムダと部分適用

引数に 1 を足すラムダを書き、`add` の第 1 引数だけに `1` を与えた関数を作る。

| 言語 | ラムダ | 二つの引数のラムダ | カリー化 | 部分適用の書き方 |
|---|---|---|---|---|
| OCaml | `fun x -> x + 1` | `fun x y -> …` | する | `add 1` |
| F# | `fun x -> x + 1` | `fun x y -> …` | する | `add 1` |
| Haskell | `\x -> x + 1` | `\x y -> …` | する | `add 1`、演算子のセクション `(+ 1)` |
| Elm | `\x -> x + 1` | `\x y -> …` | する | `add 1` |
| Gleam | `fn(x) { x + 1 }` | `fn(x, y) { … }` | しない（【要検証】） | 関数の捕捉 `add(1, _)` |
| Rust | `\|x\| x + 1` | `\|a, b\| …` | しない（【要検証】） | クロージャで書く（`\|y\| add(1, y)`） |
| Flix | `x -> x + 1` | `(x, y) -> …` | する | `add(1)` |
| Scala 3 | `x => x + 1`（`_ + 1` とも書ける） | `(x, y) => …` | しない（複数の引数リストで宣言すればできる） | `add(1, _)` |
| Roc | `\|x\| x + 1` | `\|x, y\| …` | しない（【要検証】） | ラムダで書く（`\|y\| add(1, y)`） |
| Benitoite | `lambda(x) return x + 1 end lambda` | `lambda(x, y) … end lambda` | しない | プレースホルダ `add(1, _)` |

- Flix は、引数を括弧とコンマで並べる書き方でも、関数をカリー化する（Flix の本の functions）。
- Benitoite は、引数が足りない呼び出しを部分適用とせず、型検査の誤りとする。`_` は呼び出しの直接の引数にだけ書け、`_ + 1` は構文エラーである（[構文](../01-spec/01-02-syntax.md)の「部分適用のプレースホルダ」）。Gleam の関数の捕捉と Scala 3 の `add(1, _)` も、`_` の位置に引数をとる関数を作る。

**OCaml**

```ocaml
let inc = fun x -> x + 1
let add1 = add 1
```

**F#**

```fsharp
let inc = fun x -> x + 1
let add1 = add 1
```

**Haskell**

```haskell
inc = \x -> x + 1
add1 = add 1
```

**Elm**

```elm
inc = \x -> x + 1
add1 = add 1
```

**Gleam**

```gleam
let inc = fn(x) { x + 1 }
let add1 = add(1, _)
```

**Rust**

```rust
let inc = |x| x + 1;
let add1 = |y| add(1, y);
```

**Flix**

```flix
let inc = x -> x + 1;
let add1 = add(1);
```

**Scala 3**

```scala
val inc = (x: Int) => x + 1
val add1 = add(1, _)
```

**Roc**

```roc
inc = |x| x + 1
add1 = |y| add(1, y)
```

**Benitoite**

```text
bind inc <- lambda(x) return x + 1 end lambda
bind add1 <- add(1, _)
```

### パイプ

リスト `xs` から正の要素を選び、各要素を 2 倍にする。

| 言語 | 演算子 | 定める場所 | 左の値が入る位置 |
|---|---|---|---|
| OCaml | `\|>` | 標準ライブラリ（`Stdlib`）の関数 | 最後の引数（カリー化による） |
| F# | `\|>` | FSharp.Core の演算子 | 最後の引数（カリー化による） |
| Haskell | `&` | base の `Data.Function`（Prelude にはない） | 最後の引数（カリー化による） |
| Elm | `\|>` | elm/core の `Basics`（既定で取り込む） | 最後の引数（カリー化による） |
| Gleam | `\|>` | 言語 | 最初の引数。`_` の捕捉で位置を変えられる |
| Rust | — （イテレータのメソッドを連ねる） | — | — |
| Flix | `\|>` | 言語 | 最後の引数（カリー化と、コレクションを最後にとるライブラリによる） |
| Scala 3 | — （メソッドを連ねる。`scala.util.chaining` の `pipe` もある） | — | — |
| Roc | `\|>`（静的ディスパッチの `xs.method(…)` もある） | 【要検証】（言語リファレンスの演算子の頁にない） | 最初の引数 |
| Benitoite | `\|>` | 言語（糖衣） | 最初の引数。`_` で位置を変えられる |

- カリー化する言語のパイプは、`x |> f` を `f x` とする関数か演算子であり、ライブラリの関数がデータを最後の引数にとることで、連ねて書ける。カリー化しない Gleam・Roc・Benitoite のパイプは、呼び出しの第 1 引数に左の値を加える糖衣である。
- Benitoite は、右辺を括弧で囲むと、中身によらず `e(x)` に展開する（[構文](../01-spec/01-02-syntax.md)の「パイプ」、[ADR 0050](../decisions/0050-pipe-with-parenthesized-rhs.md)）。
- Benitoite は、値に続けてドットを書くメソッド呼び出しの形（`xs.map(f)`）を構文エラーとし、`|>` の書き方を修正案として示す（[構文](../01-spec/01-02-syntax.md)の「ドット記法」）。Rust・Scala 3・Roc はメソッド呼び出しの形を持つ。

**OCaml**

```ocaml
xs |> List.filter is_positive |> List.map double
```

**F#**

```fsharp
xs |> List.filter isPositive |> List.map double
```

**Haskell**

```haskell
import Data.Function ((&))

ys = xs & filter isPositive & map double
```

**Elm**

```elm
xs
  |> List.filter isPositive
  |> List.map double
```

**Gleam**

```gleam
xs
|> list.filter(is_positive)
|> list.map(double)
```

**Rust**

```rust
// パイプの演算子はない。イテレータのメソッドを連ねる
let ys: Vec<i32> = xs.into_iter().filter(|&x| is_positive(x)).map(double).collect();
```

**Flix**

```flix
xs |> List.filter(isPositive) |> List.map(double)
```

**Scala 3**

```scala
// パイプの演算子はない。メソッドを連ねる
xs.filter(isPositive).map(double)
```

**Roc**

```roc
xs |> List.keep_if(is_positive) |> List.map(double)
```

**Benitoite**

```text
bind ys <- xs |> List.filter(isPositive) |> List.map(double)
```

### 代数的データ型と構成子の修飾

円（半径）と長方形（幅と高さ）の二つの構成子を持つ型 `Shape` を宣言し、半径 `1.0` の円を作る。

| 言語 | 宣言 | 式の中の構成子 | パターンの中の構成子 |
|---|---|---|---|
| OCaml | `type shape = Circle of float \| Rect of float * float` | 修飾しない（ほかのモジュールの構成子は `M.Circle`） | 式と同じ |
| F# | `type Shape = \| Circle of float \| Rect of float * float` | 修飾しない（`[<RequireQualifiedAccess>]` で修飾を必須にできる） | 式と同じ |
| Haskell | `data Shape = Circle Double \| Rect Double Double` | 修飾しない | 式と同じ |
| Elm | `type Shape = Circle Float \| Rect Float Float` | 修飾しない（ほかのモジュールの構成子は修飾するか `exposing` で取り込む） | 式と同じ |
| Gleam | `pub type Shape { Circle(Float) Rect(Float, Float) }` | 定義したモジュールでは修飾しない。ほかのモジュールからは `shape.Circle` と修飾するか、import で取り込む | 式と同じ |
| Rust | `enum Shape { Circle(f64), Rect(f64, f64) }` | `Shape::Circle`（`use Shape::*;` で省ける） | 式と同じ |
| Flix | `enum Shape { case Circle(Float64), case Rect(Float64, Float64) }` | `Circle` も `Shape.Circle` も書ける。同じ名前の構成子が複数あるときは修飾が必要 | 式と同じ |
| Scala 3 | `enum Shape: case Circle(r: Double) …` | `Shape.Circle`（`import Shape.*` で省ける） | 式と同じ |
| Roc | `Shape := [Circle(F64), Rect(F64, F64)]` | `Shape.Circle`。期待される型が分かれば修飾しない `Circle` も書ける | 式と同じ |
| Benitoite | `data Shape … end data`（構成子を一行に一つ） | 常に `Shape.Circle` | 常に `Shape.Circle(r)` |

- 修飾しない構成子を期待される型から補う言語は、Flix と Roc である。OCaml は、型の決まらない構成子を最後に定義した型から選ぶ（[他の言語の調査記録](08-03-language-surveys.md)の「構成子の修飾と名前空間」）。
- Benitoite は、構成子が一つだけで、その名前が型の名前と同じ型（`Pair` など）に限り、構成子を修飾せずに書く（[ADR 0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md)）。
- 代数的データ型の宣言を `data` で始めるのは、Haskell と Benitoite である。OCaml・F#・Elm・Gleam は `type`、Rust・Flix・Scala 3 は `enum` で始める。Benitoite の `type` は、Haskell と同じく型の別名にだけ使う（[ADR 0256](../decisions/0256-data-keyword-for-algebraic-types.md)、[他の言語の調査記録](08-03-language-surveys.md)の「型の別名」）。

**OCaml**

```ocaml
type shape = Circle of float | Rect of float * float
let c = Circle 1.0
```

**F#**

```fsharp
type Shape =
    | Circle of float
    | Rect of float * float

let c = Circle 1.0
```

**Haskell**

```haskell
data Shape = Circle Double | Rect Double Double

c = Circle 1.0
```

**Elm**

```elm
type Shape
  = Circle Float
  | Rect Float Float

c = Circle 1.0
```

**Gleam**

```gleam
pub type Shape {
  Circle(Float)
  Rect(Float, Float)
}

let c = Circle(1.0)
```

**Rust**

```rust
enum Shape {
    Circle(f64),
    Rect(f64, f64),
}

let c = Shape::Circle(1.0);
```

**Flix**

```flix
enum Shape {
    case Circle(Float64),
    case Rect(Float64, Float64)
}

Shape.Circle(1.0)
```

**Scala 3**

```scala
enum Shape:
  case Circle(r: Double)
  case Rect(w: Double, h: Double)

val c = Shape.Circle(1.0)
```

**Roc**

```roc
Shape := [Circle(F64), Rect(F64, F64)]

c = Shape.Circle(1.0)
```

**Benitoite**

```text
data Shape
  Circle(Float)
  Rect(Float, Float)
end data

function unitCircle() -> Shape
  return Shape.Circle(1.0)
end function
```

### レコード

名前と年齢のフィールドを持つレコード `Person` を宣言し、値を作り、年齢を取り出し、年齢だけを 1 増やした値を作る。

| 言語 | 宣言 | 生成 | フィールドの参照 | 一部を変えた値 | 型の区別 |
|---|---|---|---|---|---|
| OCaml | `type person = { name : string; age : int }` | `{ name = …; age = … }` | `p.age` | `{ p with age = … }` | 宣言した型（名前的であることの明記は【要検証】） |
| F# | `type Person = { Name: string; Age: int }` | `{ Name = …; Age = … }` | `p.Age` | `{ p with Age = … }` | 宣言した型。型はラベルから推論する |
| Haskell | `data Person = Person { name :: String, age :: Int }` | `Person { name = …, age = … }` | `age p`（ラベルが取り出す関数になる） | `p { age = … }` | 名前的 |
| Elm | `type alias Person = { name : String, age : Int }` | `{ name = …, age = … }` | `p.age`、関数 `.age` | `{ p \| age = … }` | 構造的（別名は名前を付けるだけ） |
| Gleam | `pub type Person { Person(name: String, age: Int) }` | `Person(name: …, age: …)` | `p.age` | `Person(..p, age: …)` | 名前的（カスタム型の構成子） |
| Rust | `struct Person { name: String, age: i32 }` | `Person { name: …, age: … }` | `p.age` | `Person { age: …, ..p }` | 名前的 |
| Flix | `type alias Person = { name = String, age = Int32 }` | `{ name = …, age = … }` | `p#age` | `{ age = … \| p }` | 構造的（行多相） |
| Scala 3 | `case class Person(name: String, age: Int)` | `Person("Ada", 36)` | `p.age` | `p.copy(age = …)` | 名前的 |
| Roc | `Person : { name : Str, age : U64 }` | `{ name: …, age: … }` | `p.age` | `{ ..p, age: … }` | 構造的（`:=` で宣言すれば名前的） |
| Benitoite | `record Person … end record`（フィールドを一行に一つ） | `Person(name: …, age: …)` | `Person.age(p)` | `Person(..p, age: …)` | 名前的 |

- Benitoite は、フィールドを値に続けるドット（`p.age`）ではなく、レコードの名前のモジュールの関数（`Person.age`）で取り出す（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。`p.age` は構文エラーとし、`Person.age(p)` と `p |> Person.age` を修正案として示す。生成と更新の書き方は Gleam に近い（[ADR 0057](../decisions/0057-record-declaration-construction-update.md)）。
- Haskell は、GHC の拡張 `OverloadedRecordDot` で `p.age` と書ける。

**OCaml**

```ocaml
type person = { name : string; age : int }
let p = { name = "Ann"; age = 30 }
let a = p.age
let p2 = { p with age = p.age + 1 }
```

**F#**

```fsharp
type Person = { Name: string; Age: int }
let p = { Name = "Ann"; Age = 30 }
let a = p.Age
let p2 = { p with Age = p.Age + 1 }
```

**Haskell**

```haskell
data Person = Person { name :: String, age :: Int }

p  = Person { name = "Ann", age = 30 }
a  = age p
p2 = p { age = age p + 1 }
```

**Elm**

```elm
type alias Person =
  { name : String, age : Int }

p  = { name = "Ann", age = 30 }
a  = p.age
p2 = { p | age = p.age + 1 }
```

**Gleam**

```gleam
pub type Person {
  Person(name: String, age: Int)
}

let p = Person(name: "Ann", age: 30)
let a = p.age
let p2 = Person(..p, age: p.age + 1)
```

**Rust**

```rust
struct Person { name: String, age: i32 }

let p = Person { name: String::from("Ann"), age: 30 };
let a = p.age;
let p2 = Person { age: p.age + 1, ..p };
```

**Flix**

```flix
type alias Person = { name = String, age = Int32 }

let p = { name = "Ann", age = 30 };
let a = p#age;
let p2 = { age = p#age + 1 | p };
```

**Scala 3**

```scala
case class Person(name: String, age: Int)

val p = Person("Ann", 30)
val a = p.age
val p2 = p.copy(age = p.age + 1)
```

**Roc**

```roc
Person : { name : Str, age : U64 }

p : Person
p = { name: "Ann", age: 30 }
a = p.age
p2 = { ..p, age: p.age + 1 }
```

**Benitoite**

```text
record Person
  name: String
  age: Integer
end record

function older() -> Person
  bind p <- Person(name: "Ann", age: 30)
  bind a <- Person.age(p)
  return Person(..p, age: a + 1)
end function
```

### `Option` と `Result` の名前と構成子

値があるかないかを表す型と、成功か失敗かを表す型の名前と構成子を比べる。

| 言語 | 値の有無の型 | 構成子 | 成功か失敗かの型 | 構成子 | import |
|---|---|---|---|---|---|
| OCaml | `'a option` | `Some`・`None` | `('a, 'b) result` | `Ok`・`Error` | 要らない |
| F# | `'a option`（`Option<'a>`） | `Some`・`None` | `Result<'T, 'TError>` | `Ok`・`Error` | 要らない（FSharp.Core を既定で開く） |
| Haskell | `Maybe a` | `Just`・`Nothing` | `Either a b` | `Left`（慣習で失敗）・`Right` | 要らない（Prelude） |
| Elm | `Maybe a` | `Just`・`Nothing` | `Result error value` | `Ok`・`Err` | 要らない（既定の import） |
| Gleam | `Option(a)` | `Some`・`None` | `Result(value, error)` | `Ok`・`Error` | `Result` は組み込み。`Option` は `gleam/option` を import する |
| Rust | `Option<T>` | `Some`・`None` | `Result<T, E>` | `Ok`・`Err` | 要らない（prelude） |
| Flix | `Option[t]` | `Some`・`None` | `Result[e, t]`（失敗の型が先） | `Ok`・`Err` | 文書の例は import なしで使う（prelude に含むかは【要検証】） |
| Scala 3 | `Option[A]` | `Some`・`None` | `Either[A, B]` | `Left`・`Right`（右が成功） | 要らない |
| Roc | — | — | `Try(ok, err)` | `Ok`・`Err` | 要らない（組み込み） |
| Benitoite | `Option[T]` | `Option.Some`・`Option.None` | `Result[T, E]` | `Result.Ok`・`Result.Error` | 要らない（prelude） |

- 構成子を型名で修飾して書くのは、Benitoite だけである（[ADR 0099](../decisions/0099-qualified-option-result-constructors.md)）。Benitoite の失敗の構成子の名前 `Error` は、OCaml・F#・Gleam と同じである。
- Roc には値の有無の型がなく、`Try` か、その場で使うタグで表す（Roc の入門）。

**OCaml**

```ocaml
let a : int option = Some 1
let b : (int, string) result = Error "bad"
```

**F#**

```fsharp
let a : int option = Some 1
let b : Result<int, string> = Error "bad"
```

**Haskell**

```haskell
a :: Maybe Int
a = Just 1

b :: Either String Int
b = Left "bad"
```

**Elm**

```elm
a : Maybe Int
a = Just 1

b : Result String Int
b = Err "bad"
```

**Gleam**

```gleam
import gleam/option.{type Option, Some}

let a: Option(Int) = Some(1)
let b: Result(Int, String) = Error("bad")
```

**Rust**

```rust
let a: Option<i32> = Some(1);
let b: Result<i32, String> = Err(String::from("bad"));
```

**Flix**

```flix
let a: Option[Int32] = Some(1);
let b: Result[String, Int32] = Err("bad");
```

**Scala 3**

```scala
val a: Option[Int] = Some(1)
val b: Either[String, Int] = Left("bad")
```

**Roc**

```roc
b : Try(I64, Str)
b = Err("bad")
```

**Benitoite**

```text
bind a: Option[Integer] <- Option.Some(1)
bind b: Result[Integer, String] <- Result.Error("bad")
```

### エラーの伝播

文字列を整数に変える利用者の関数 `parse`（失敗すると誤りの文字列を返す）を使い、二つの文字列を整数に変えて和を返す関数 `addParsed` を書く。どちらかの変換が失敗したら、その誤りをそのまま返す。

| 言語 | 書き方 | 言語の構文か |
|---|---|---|
| OCaml | `let*`（束縛演算子）。`Result.Syntax` を開く | 束縛演算子は言語の構文（4.08 から）。`Result.Syntax` は標準ライブラリ（5.4 から） |
| F# | `Result.bind` を連ねる | ライブラリの関数。計算式の `let!` は言語の構文だが、`Result` の計算式のビルダーは FSharp.Core にない |
| Haskell | `do` 記法 | 言語の構文。`Either` の `Monad` のインスタンスは base が定める（Haskell 2010 の Prelude にはない） |
| Elm | `Result.andThen` を連ねる | ライブラリの関数（糖衣はない） |
| Gleam | `use x <- result.try(…)` | `use` は言語の構文、`result.try` は標準ライブラリ |
| Rust | 後置の `?` | 言語の構文。誤りの値を `From` で変換する |
| Flix | `forM (…) yield …` | 言語の構文 |
| Scala 3 | `for … yield …` | 言語の構文（`flatMap` と `map` に展開する） |
| Roc | 後置の `?` | 言語の構文 |
| Benitoite | 前置の `try` | 言語の構文。誤りの型を自動では変換しない |

- Benitoite の `try` は、式の先頭に書き、右の式全体（パイプを含む）にかかる。後置の `?` は設けず、`e?` と書いたときは `try e` を修正案として示す（[エラー処理](../01-spec/01-09-errors.md)、[ADR 0097](../decisions/0097-prefix-try.md)）。

**OCaml**

```ocaml
let add_parsed a b =
  let open Result.Syntax in
  let* x = parse a in
  let* y = parse b in
  Ok (x + y)
```

**F#**

```fsharp
let addParsed a b =
    parse a |> Result.bind (fun x ->
    parse b |> Result.bind (fun y -> Ok (x + y)))
```

**Haskell**

```haskell
addParsed :: String -> String -> Either String Int
addParsed a b = do
  x <- parse a
  y <- parse b
  return (x + y)
```

**Elm**

```elm
addParsed : String -> String -> Result String Int
addParsed a b =
  parse a
    |> Result.andThen (\x ->
         parse b
           |> Result.andThen (\y -> Ok (x + y)))
```

**Gleam**

```gleam
import gleam/result

pub fn add_parsed(a: String, b: String) -> Result(Int, String) {
  use x <- result.try(parse(a))
  use y <- result.try(parse(b))
  Ok(x + y)
}
```

**Rust**

```rust
fn add_parsed(a: &str, b: &str) -> Result<i32, String> {
    let x = parse(a)?;
    let y = parse(b)?;
    Ok(x + y)
}
```

**Flix**

```flix
def addParsed(a: String, b: String): Result[String, Int32] =
    forM (x <- parse(a); y <- parse(b)) yield x + y
```

**Scala 3**

```scala
def addParsed(a: String, b: String): Either[String, Int] =
  for
    x <- parse(a)
    y <- parse(b)
  yield x + y
```

**Roc**

```roc
add_parsed = |a, b| {
    x = parse(a)?
    y = parse(b)?
    Ok(x + y)
}
```

**Benitoite**

```text
function addParsed(a: String, b: String) -> Result[Integer, String]
  bind x <- try parse(a)
  bind y <- try parse(b)
  return Result.Ok(x + y)
end function
```

### 型クラスとトレイト

値を説明する文字列を返すメソッド `describe` を持つ型クラス `Describe` を宣言し、`Shape` に実装する。

| 言語 | 宣言 | 実装 | メソッドの呼び出し |
|---|---|---|---|
| OCaml | — （モジュールのシグネチャとモジュールで書く） | — | — |
| F# | — （.NET のインターフェースか、SRTP の制約で書く） | — | — |
| Haskell | `class Describe a where …` | `instance Describe Shape where …` | `describe s` |
| Elm | — （型ごとの関数を書く） | — | — |
| Gleam | — （関数を引数として渡す） | — | — |
| Rust | `trait Describe { fn describe(&self) -> String; }` | `impl Describe for Shape { … }` | `s.describe()` |
| Flix | `trait Describe[a] { … }` | `instance Describe[Shape] { … }` | 【要検証】 |
| Scala 3 | `trait Describe[A]:`（拡張メソッドを宣言する） | `given Describe[Shape]:` | `s.describe` |
| Roc | 宣言はない。名前的な型の `.{ … }` にメソッドを置き、`where` で要るメソッドを書く | 同左 | `s.describe()` |
| Benitoite | `trait Describe[T] … end trait` | `implement Describe[Shape] … end implement` | `Describe.describe(s)` |

- 型クラスを持たないことを、Gleam は文書に明記する（Language Tour の「Use」）。Elm は、利用者が型クラスを定義できず、組み込みの演算子のための制約付きの型変数（`number`・`comparable` など）だけを持つ（公式ガイド）。OCaml と F# が型クラスを持たないことは、言語リファレンスに型クラスの節がないことによる。
- 型クラスの代わりの書き方（OCaml のモジュール、F# のインターフェース）は、各言語の文書が型クラスの代わりとして示すものではない。
- Benitoite は、メソッドを型クラスの名前で修飾して呼ぶ（[ADR 0060](../decisions/0060-trait-and-impl-syntax.md)）。関数の型パラメータの制約は `[T: Describe]` と書き、複数の制約は `&` でつなぐ（[ADR 0098](../decisions/0098-constraints-joined-by-ampersand.md)）。

**OCaml**

```ocaml
(* 型クラスはない。モジュールのシグネチャとモジュールで書く *)
module type DESCRIBE = sig type t val describe : t -> string end
module Shape_describe : DESCRIBE with type t = shape = struct
  type t = shape
  let describe = function Circle _ -> "circle" | Rect _ -> "rect"
end
```

**F#**

```fsharp
// 型クラスはない。インターフェースで書く
type IDescribe =
    abstract Describe: unit -> string

type Shape =
    | Circle of float
    | Rect of float * float
    interface IDescribe with
        member this.Describe() =
            match this with Circle _ -> "circle" | Rect _ -> "rect"
```

**Haskell**

```haskell
class Describe a where
  describe :: a -> String

instance Describe Shape where
  describe (Circle _) = "circle"
  describe (Rect _ _) = "rect"
```

**Elm**

```elm
-- 型クラスはない。型ごとの関数を書く
describe : Shape -> String
describe shape =
  case shape of
    Circle _ -> "circle"
    Rect _ _ -> "rect"
```

**Gleam**

```gleam
// 型クラスはない。型ごとの関数を書き、必要なら関数を引数として渡す
pub fn describe(shape: Shape) -> String {
  case shape {
    Circle(_) -> "circle"
    Rect(_, _) -> "rect"
  }
}
```

**Rust**

```rust
trait Describe {
    fn describe(&self) -> String;
}

impl Describe for Shape {
    fn describe(&self) -> String {
        match self {
            Shape::Circle(_) => String::from("circle"),
            Shape::Rect(_, _) => String::from("rect"),
        }
    }
}
```

**Flix**

```flix
trait Describe[a] {
    pub def describe(x: a): String
}

instance Describe[Shape] {
    pub def describe(s: Shape): String = match s {
        case Shape.Circle(_)  => "circle"
        case Shape.Rect(_, _) => "rect"
    }
}
```

**Scala 3**

```scala
trait Describe[A]:
  extension (a: A) def describe: String

given Describe[Shape]:
  extension (s: Shape) def describe: String = s match
    case Shape.Circle(_)  => "circle"
    case Shape.Rect(_, _) => "rect"
```

**Roc**

```roc
Shape := [Circle(F64), Rect(F64, F64)].{
    describe : Shape -> Str
    describe = |s| match s {
        Circle(_) => "circle"
        Rect(_, _) => "rect"
    }
}
```

**Benitoite**

```text
trait Describe[T]
  function describe(x: T) -> String
end trait

implement Describe[Shape]
  function describe(x: Shape) -> String
    return match x with
      case Shape.Circle(_) -> "circle"
      case Shape.Rect(_, _) -> "rectangle"
    end match
  end function
end implement
```

### エフェクトとエフェクトハンドラ

一行を出力する関数を書き、その関数の型に副作用がどう表れるかを比べる。利用者がエフェクトを定義できる言語では、操作 `write` を持つエフェクト `Log` を宣言し、`write` を出力で処理するハンドラを書く。

| 言語 | 出力する関数の型 | 利用者が定義するエフェクト | ハンドラ | 継続の再開 |
|---|---|---|---|---|
| OCaml | 表れない（`print_endline : string -> unit`） | `type _ Effect.t += …`、`perform` | `match … with effect E, k -> …`（5.3 から） | 一度だけ（`continue`・`discontinue`） |
| F# | 表れない | — | — | — |
| Haskell | `IO` 型（`putStrLn :: String -> IO ()`） | — （言語にはない） | — | — |
| Elm | 出力する関数はない。エフェクトは `Cmd`・`Sub` の値としてランタイムに渡す | — （JavaScript との連携は `port`） | — | — |
| Gleam | 表れない（`io.println` は `-> Nil`） | — | — | — |
| Rust | 表れない | — | — | — |
| Flix | `\ IO` | `eff Log { def write(…): Unit }` | `run { … } with handler Log { … }` | 複数回できる |
| Scala 3 | 表れない（capture checking は実験的な機能） | — | — | — |
| Roc | 関数の型の `=>`（名前の末尾に `!` を付ける慣習がある） | — | — | — |
| Benitoite | `uses Console.Write` | `effect Log … end effect` | `handle … with case write(message) -> … end handle` | 一度だけ（`resume`） |

- OCaml は、処理しないエフェクトを静的に検査せず、実行時に `Effect.Unhandled` を起こす（OCaml マニュアルの effects）。Flix と Benitoite は、関数の型にエフェクトを書き、処理しないエフェクトを型で検査する。
- Flix の `IO` のような組み込みのエフェクトは、ハンドラで処理できない（Flix の本の primitive-effects）。Benitoite の組み込みのエフェクト（`Console.Write`、`File.Read` など）は、`State` を除きハンドラで処理でき、テストで操作を差し替えられる（[エフェクト](../01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」）。
- Roc の副作用は、すべてプラットフォームが与える。言語リファレンスは、代数的エフェクトを持つ言語のようなエフェクトの多相を持たないと書く。
- Benitoite のエフェクトは、モジュールの中で宣言し、その操作をモジュールの関数とする（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。ハンドラは深いハンドラであり、継続を一度だけ再開できる（[ADR 0118](../decisions/0118-effect-handlers.md)）。

**OCaml**

```ocaml
let greet () = print_endline "hello"

open Effect
open Effect.Deep
type _ Effect.t += Write : string -> unit t
let work () = perform (Write "hello")
let run f =
  match f () with
  | v -> v
  | effect (Write msg), k -> print_endline msg; continue k ()
```

**F#**

```fsharp
// 副作用は型に表れない。エフェクトハンドラはない
let greet () = printfn "%s" "hello"
```

**Haskell**

```haskell
-- 副作用は IO 型で表す。エフェクトハンドラは言語にない
greet :: IO ()
greet = putStrLn "hello"
```

**Elm**

```elm
-- 出力する関数はない。JavaScript との連携は port で宣言する
port time : Float -> Cmd msg
```

**Gleam**

```gleam
// 副作用は型に表れない。エフェクトハンドラはない
import gleam/io

pub fn greet() -> Nil {
  io.println("hello")
}
```

**Rust**

```rust
// 副作用は型に表れない。エフェクトハンドラはない
fn greet() {
    println!("hello");
}
```

**Flix**

```flix
def greet(): Unit \ IO = println("hello")

eff Log {
    def write(message: String): Unit
}

def work(): Unit \ Log = Log.write("hello")

def main(): Unit \ IO =
    run {
        work()
    } with handler Log {
        def write(msg, k) = { println(msg); k() }
    }
```

**Scala 3**

```scala
// 副作用は型に表れない。エフェクトハンドラはない
def greet(): Unit = println("hello")
```

**Roc**

```roc
# エフェクトのある関数は => で表す。エフェクトハンドラはない
greet! : Str => {}
greet! = |name| echo!("Hello, ${name}!")
```

**Benitoite**

```text
import Benitoite.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function greet(name: String) -> Unit uses Console.Write
  Console.writeLine("Hello, ${name}")
end function

function work(items: List[String]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.length(items)
end function

function main() -> Unit uses Console.Write
  bind count <- handle
    work(["a", "b"])
  with
    case write(message) ->
      Console.writeLine(message)
      resume(())
  end handle
  Console.writeLine(Integer.toString(count))
end function
```

### モジュールと import

ほかのモジュールを取り込み、修飾した名前で使い、別名を付ける。

| 言語 | 取り込み | 別名 | 修飾しない取り込み | ファイルとモジュール |
|---|---|---|---|---|
| OCaml | 取り込みの文はない（モジュールの名前で参照する） | `module L = List` | `open M`、`let open M in e`、`M.(e)` | ファイル `a.ml` がモジュール `A` |
| F# | `open`（名前空間とモジュール） | `module X = …`（名前空間には使えない） | `open` | 宣言のないファイルは、ファイル名のモジュールになる |
| Haskell | `import M`、`import qualified M` | `as` | `import M` は修飾せずに使える（修飾もできる） | Haskell 2010 Report は定めない |
| Elm | `import M` | `as` | `exposing (…)` | モジュールの名前とファイルのパスを一致させる |
| Gleam | `import gleam/io` | `as` | `.{…}` | ファイルがモジュール。名前はパスで決まる |
| Rust | `mod` の宣言でファイルを読み、`use` で名前を取り込む | `as` | `use`、`*` | `mod m;` が `m.rs` を読む |
| Flix | `mod` でモジュールを宣言し、`use` で名前を取り込む | `use M.{x => y}`（メンバーの改名） | `use M.x`（ワイルドカードはない） | 【要検証】 |
| Scala 3 | `import` | `as` | `import m.*` | ファイルはモジュールではない（`package` と `object`） |
| Roc | `import Color` | `as` | `exposing [...]` | `.roc` のファイルがモジュール |
| Benitoite | `import Lib.Text` | `as` | — （常に修飾する） | ファイルがモジュール。名前は根のディレクトリからのパスで決まる |

- 取り込んだモジュールの名前を修飾せずに使う取り込み方を持たないのは、比べた言語の中で Benitoite だけである（[名前・スコープ・モジュール](../01-spec/01-03-names-modules.md)の「モジュールと import（初回リリース版）」、[ADR 0126](../decisions/0126-import-by-module-name.md)）。
- Benitoite は、トップレベルの宣言を既定で非公開とし、`public` を付けたものだけを公開する（[ADR 0053](../decisions/0053-private-by-default-with-pub.md)）。Gleam（`pub`）と Rust（`pub`）と Flix（`pub`）も既定で非公開である。

**OCaml**

```ocaml
let ys = List.map double xs
module L = List
let zs = L.map double xs
open List
```

**F#**

```fsharp
open System.IO
let ys = List.map double xs
```

**Haskell**

```haskell
import qualified Data.Map as M   -- M.lookup と書く
import Data.List (sortBy)        -- sortBy を修飾せずに使う
```

**Elm**

```elm
import List as L                  -- L.map と書く
import Maybe exposing (Maybe(..)) -- Just を修飾せずに使う
```

**Gleam**

```gleam
import gleam/io
import gleam/string as text

io.println(text.reverse("abc"))
```

**Rust**

```rust
mod shapes;                     // shapes.rs をモジュール shapes として読む
use std::collections::HashMap;  // 名前を取り込む
use std::io as stdio;           // 別名
```

**Flix**

```flix
mod Math {
    pub def sum(x: Int32, y: Int32): Int32 = x + y
}

use Math.sum;
```

**Scala 3**

```scala
import scala.collection.mutable as mut   // mut.Map と書く
import scala.math.{max, min}             // 修飾せずに使う
```

**Roc**

```roc
import Color as CC                    # CC.to_str と書く
import Color exposing [to_str]        # 修飾せずに使う
```

**Benitoite**

```text
import Lib.Text
import Lib.Geometry.Shape as GShape
import Benitoite.IO.Console

function main() -> Unit uses Console.Write
  Console.writeLine(Text.slug("Hello World"))
end function
```

### ブロックの区切りと文の区切り

引数を 2 倍した値を局所の名前に束縛し、負なら `0`、そうでなければその値を返す関数を書き、ブロックと文の区切り方を比べる。

| 言語 | ブロックの区切り | 文・式の区切り | 字下げの意味 |
|---|---|---|---|
| OCaml | `let … in`、`begin … end`、括弧。`match` には閉じる語がない | `;`（式の並び） | 持たない |
| F# | 字下げ（冗長構文では `in`・`begin … end`・`done`） | 改行。一行に並べるときは `;` | 持つ（オフサイド規則） |
| Haskell | レイアウト（`where`・`let`・`do`・`of` の後）か `{ ; }` | 改行（レイアウト）か `;` | 持つ |
| Elm | 字下げ。`let` の定義と `case` の分岐の位置を揃える | 改行 | 持つ |
| Gleam | `{ }` | 【要検証】（文書の例は改行で並べ、`;` を使わない） | 【要検証】 |
| Rust | `{ }` | `;`。ブロックの値は `;` のない末尾の式 | 持たない |
| Flix | `{ }`。関数の本体は `=` の後の式 | `;` | 【要検証】 |
| Scala 3 | `{ }` か字下げ。`:` の後の字下げで範囲を始め、`end` で閉じてもよい | 改行（`;` を推論する） | 持つ（波括弧を省く書き方のとき） |
| Roc | `{ }` | 改行（規則の明記は【要検証】） | 【要検証】 |
| Benitoite | 構文の名前を添えた `end`（`end function`・`end if` など） | 改行 | 持たない |

- Benitoite は、ブロックを波括弧で囲まず、ブロックを持つ構文をキーワードで始め、`end` とその構文の名前で閉じる（[ADR 0108](../decisions/0108-keyword-blocks-closed-by-end.md)）。閉じる語が閉じる構文と合わないとき（`if` を `end match` で閉じたなど）は構文エラーとし、どの構文を閉じるべきかを診断で示す（[構文](../01-spec/01-02-syntax.md)の「ブロックと文」）。
- Benitoite の改行は、字句構造の規則で文の区切りになるかが決まり、字下げは意味を持たない（[字句構造](../01-spec/01-01-lexical.md)の「改行による区切り」）。

**OCaml**

```ocaml
let f x =
  let y = x * 2 in
  if y < 0 then 0 else y
```

**F#**

```fsharp
let f x =
    let y = x * 2
    if y < 0 then 0 else y
```

**Haskell**

```haskell
f x =
  let y = x * 2
  in if y < 0 then 0 else y
```

**Elm**

```elm
f x =
  let
    y = x * 2
  in
  if y < 0 then 0 else y
```

**Gleam**

```gleam
fn f(x: Int) -> Int {
  let y = x * 2
  case y < 0 {
    True -> 0
    False -> y
  }
}
```

**Rust**

```rust
fn f(x: i32) -> i32 {
    let y = x * 2;
    if y < 0 { 0 } else { y }
}
```

**Flix**

```flix
def f(x: Int32): Int32 =
    let y = x * 2;
    if (y < 0) 0 else y
```

**Scala 3**

```scala
def f(x: Int): Int =
  val y = x * 2
  if y < 0 then 0 else y
```

**Roc**

```roc
f = |x| {
    y = x * 2
    if y < 0 0 else y
}
```

**Benitoite**

```text
function f(x: Integer) -> Integer
  bind y <- x * 2
  return if y < 0 then 0 else y end if
end function
```

### コメントとドキュメントコメント

行のコメント、複数行のコメント、宣言とモジュールのドキュメントコメントを比べる。

| 言語 | 行のコメント | 複数行のコメント | 入れ子 | 宣言の説明 | モジュールの説明 |
|---|---|---|---|---|---|
| OCaml | — | `(* … *)` | できる | `(** … *)`（項目の直前か直後） | ファイルの最初の `(** … *)` |
| F# | `//` | `(* … *)` | できる | `///`（XML の説明） | `///` をモジュールの宣言の前に置く |
| Haskell | `--` | `{- … -}` | できる | `-- \|`（前）、`-- ^`（後） | `module` の前の `{-\| … -}` |
| Elm | `--` | `{- … -}` | できる | `{-\| … -}`（宣言の前） | `module` の行の後の `{-\| … -}`（`@docs` で項目を並べる） |
| Gleam | `//` | — | — | `///` | `////` |
| Rust | `//` | `/* … */` | できる | `///`、`/** … */` | `//!`、`/*! … */` |
| Flix | `//` | `/* … */` | できる | `///` | 【要検証】 |
| Scala 3 | `//` | `/* … */` | できる | `/** … */`（Scaladoc） | 【要検証】 |
| Roc | `#` | — | — | `##` | 【要検証】 |
| Benitoite | `//` | — | — | `///` | `//!` |

- Benitoite は、複数行のコメントの構文を設けない。同じ役割の構文を増やさないためである（[字句構造](../01-spec/01-01-lexical.md)の「コメント」）。ドキュメントコメントの書き方は Rust の `///` と `//!` と同じである（[ADR 0125](../decisions/0125-doc-comments.md)）。
- Gleam と Roc も、複数行のコメントを持たない（Gleam のチートシート、Roc の言語リファレンスの comments-and-docs）。

**OCaml**

```ocaml
(* comment (* nested *) *)

(** Adds two integers. *)
let add x y = x + y
```

**F#**

```fsharp
// line comment
(* block (* nested *) comment *)

/// Adds two integers.
let add x y = x + y
```

**Haskell**

```haskell
-- line comment
{- block comment {- nested -} -}

-- | Adds two integers.
add :: Int -> Int -> Int
add x y = x + y
```

**Elm**

```elm
-- line comment
{- block comment {- nested -} -}

{-| Adds two integers. -}
add : Int -> Int -> Int
add x y = x + y
```

**Gleam**

```gleam
//// Module documentation.

/// Adds two integers.
pub fn add(a: Int, b: Int) -> Int {
  // line comment
  a + b
}
```

**Rust**

```rust
//! Module documentation.

/// Adds two integers.
fn add(a: i32, b: i32) -> i32 {
    // line comment
    /* block comment /* nested */ */
    a + b
}
```

**Flix**

```flix
/// Adds two integers.
def add(x: Int32, y: Int32): Int32 =
    // line comment
    /* block comment /* nested */ */
    x + y
```

**Scala 3**

```scala
/** Adds two integers. */
def add(x: Int, y: Int): Int =
  // line comment
  /* block comment /* nested */ */
  x + y
```

**Roc**

```roc
## Adds two integers.
add = |a, b| {
    # line comment
    a + b
}
```

**Benitoite**

```text
//! Module description.

/// Adds two integers.
function add(x: Integer, y: Integer) -> Integer
  // A line comment.
  return x + y
end function
```

### Benitoite の構文の選択のまとめ

各節で比べた構文について、Benitoite の書き方と、同じか近い書き方の言語、それを決めた ADR を示す。

| 構文 | Benitoite の書き方 | 同じか近い書き方の言語 | 決めた ADR |
|---|---|---|---|
| キーワードの綴り | 省略しない英単語（`function`・`public`・`implement`・`lambda`） | — （比べた言語はどれも `fn`・`def`・`let` などの短い語を使う） | [0092](../decisions/0092-unabbreviated-keywords.md)、[0109](../decisions/0109-lambda-keyword.md) |
| 関数の型注釈 | トップレベルの関数では必須 | Flix | [0004](../decisions/0004-surface-syntax-skeleton.md) |
| 戻り値の型の位置 | `->` の後。関数の型も `->` | Gleam、Rust（Haskell・Elm・Roc は型注釈の最後の `->` の後） | [0254](../decisions/0254-return-type-after-arrow.md)（[0094](../decisions/0094-return-type-after-colon.md) の宣言とラムダの記号を置き換えた） |
| 値の返し方 | `return` を書く | — （比べた言語はどれも本体の式の値を返す） | [0096](../decisions/0096-explicit-return.md) |
| 関数の適用 | 括弧とコンマ。カリー化しない | Gleam、Rust、Scala 3、Roc | [0004](../decisions/0004-surface-syntax-skeleton.md) |
| 局所の束縛 | `bind x <- e`。見えている局所の名前を隠すときだけ `shadow x <- e` と書く | — （比べた言語は同じ語で束縛し直すか、シャドーイングを禁じる） | [0255](../decisions/0255-bind-and-shadow.md)（[0010](../decisions/0010-shared-namespace-and-shadowing.md) のシャドーイングの規則を改めた） |
| ブロック | 構文の名前を添えた `end` で閉じる | — （Scala 3 は `end` を任意で書ける） | [0108](../decisions/0108-keyword-blocks-closed-by-end.md) |
| 条件分岐 | `if … then … else … end if` | OCaml、F#、Haskell、Elm、Scala 3（`end if` を除く） | [0110](../decisions/0110-if-then-end-if.md) |
| パターンで分岐する式 | `match … with case パターン -> … end match` | OCaml・F#（`match … with`）、Flix・Scala 3（分岐の頭の `case`）、OCaml・F#・Haskell・Elm・Gleam（分岐の `->`） | [0257](../decisions/0257-match-with-case-arms.md)（[0111](../decisions/0111-case-of-when.md) を置き換えた） |
| ガード | 分岐のパターンの後の `if` | Gleam、Rust、Flix、Scala 3、Roc | [0121](../decisions/0121-pattern-extensions.md) |
| 演算子 | `=`・`<>`・`and`・`or`・`not`、`div`・`mod` | — （本章では比べていない。Pascal 系の言語の書き方は[他の言語の調査記録](08-03-language-surveys.md)の「Pascal 系の言語のパイプ・ドット記法と演算子」） | [0112](../decisions/0112-pascal-style-operators.md)、[0113](../decisions/0113-div-and-mod-operators.md) |
| ラムダ | `lambda(x) … end lambda` | — | [0109](../decisions/0109-lambda-keyword.md) |
| 部分適用 | プレースホルダ `_` | Gleam、Scala 3 | [0004](../decisions/0004-surface-syntax-skeleton.md) |
| パイプ | `\|>` が第 1 引数に加える。右辺を括弧で囲むと `e(x)` | Gleam、Roc | [0004](../decisions/0004-surface-syntax-skeleton.md)、[0050](../decisions/0050-pipe-with-parenthesized-rhs.md) |
| ドット | モジュールと型名の修飾に限る。値のメソッド呼び出しはない | OCaml、Haskell、Elm（値に続けたドットはレコードのフィールドに使う） | [0004](../decisions/0004-surface-syntax-skeleton.md) |
| 代数的データ型の宣言 | `data … end data`。`type` は型の別名に限る | Haskell | [0256](../decisions/0256-data-keyword-for-algebraic-types.md) |
| 構成子 | 型名で修飾する（`Shape.Circle`、`Option.Some`） | Rust・Scala 3（利用者の型の構成子） | [0007](../decisions/0007-constructors-and-list.md)、[0099](../decisions/0099-qualified-option-result-constructors.md)、[0148](../decisions/0148-keep-qualified-constructors-and-shared-namespace.md) |
| レコード | `record`。名前付きの引数で作り、`..` で更新し、関数で取り出す | Gleam（生成と更新） | [0056](../decisions/0056-record-fields-via-accessor-functions.md)、[0057](../decisions/0057-record-declaration-construction-update.md) |
| 組 | `Pair`・`Triple`。括弧のタプルはない | — | [0102](../decisions/0102-pair-and-triple.md) |
| エラーの伝播 | 前置の `try` | — （Rust と Roc は後置の `?`） | [0097](../decisions/0097-prefix-try.md) |
| 型クラス | `trait … end trait`、`implement … end implement`。メソッドを型クラスの名前で修飾して呼ぶ | Haskell、Rust、Flix、Scala 3 | [0060](../decisions/0060-trait-and-impl-syntax.md)、[0098](../decisions/0098-constraints-joined-by-ampersand.md) |
| エフェクト | 関数の型に `uses` で書く。直接形式で呼ぶ | Flix（`\ IO`） | [0005](../decisions/0005-direct-style-effects.md)、[0129](../decisions/0129-effects-declared-in-modules.md)、[0130](../decisions/0130-builtin-effect-names-and-placement.md) |
| エフェクトハンドラ | `handle … with case 操作(引数) -> … resume(値) … end handle`。一度だけ再開する | OCaml 5（一度だけ再開）、Flix（深いハンドラ） | [0118](../decisions/0118-effect-handlers.md)、[0257](../decisions/0257-match-with-case-arms.md) |
| import | 名前で取り込み、常に修飾する | Gleam・Elm（修飾を勧める） | [0126](../decisions/0126-import-by-module-name.md)、[0053](../decisions/0053-private-by-default-with-pub.md) |
| コメント | `//` だけ。説明は `///` と `//!` | Rust（ドキュメントコメント）、Gleam（複数行のコメントを持たない） | [0125](../decisions/0125-doc-comments.md) |

比べた言語との違いが大きい選択は、`return` を書くこと、ブロックを `end 構文の名前` で閉じること、名前を隠す束縛を `shadow` で書き分けること、構成子を常に修飾すること、import した名前を常に修飾すること、前置の `try` である。それぞれの理由は、表に挙げた ADR に書く。LLM がこれらの書き方をどれだけ正しく生成できるかは、[OPEN-012](../open-issues.md#open-012) の測定で確かめる。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（Benitoite の構文が、比べた言語の書き方と違う箇所の誤りの率）
- [OPEN-014](../open-issues.md#open-014): 参考にした言語に関する外部の事実の確認。本章の【要検証】の事項は次のとおりである。
  - Gleam・Rust・Roc が関数をカリー化しないこと。どの文書も明記しておらず、関数の型と部分適用の書き方から判断した。
  - Flix の `if` の `else` を省略できるか、条件の括弧が必須か。
  - Flix の `Option` と `Result` が prelude に含まれるか。Flix の型クラスのメソッドの呼び出し方。Flix のファイルとモジュールの関係。Flix の字下げの扱い。
  - Roc の `|>` の意味（言語リファレンスの演算子の頁になく、全構文のテストのファイルの例による）。Roc の文の区切りの規則。Roc の構文は変更の途中であり、本章の Roc の例はすべて 2026-09-29 の時点のものである。
  - Gleam の改行の扱いと `;` の有無。
  - OCaml のレコードが名前的であることの明記。
  - Elm の `case` にガードがないこと（公式の構文の頁とガイドにないことによる）。
  - Flix・Scala 3・Roc のモジュールの説明のドキュメントコメントの書き方。
  - 各言語の例を処理系で実行して確かめること。
