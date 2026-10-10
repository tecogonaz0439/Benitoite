# Benitoite 言語リファレンス

> この文書は、`docs/reference/benitoite.md` の日本語の訳である。訳した元は、Benitoite 0.0.2 の版の英語の版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

<!--
このファイルのコードの例の検査の方法（crates/benitoite/tests/reference_examples.rs）:
- `benitoite` のブロックは実行し、その標準出力を直後の `output` のブロックと比べる。
  `output` のブロックの最後の行が `exit N` なら、それが期待する終了コードである（ないときは 0）。
  `output` のブロックの後の `stderr` のブロックは、期待する標準エラー出力である（ないときは空）。
- `benitoite check` のブロックは検査だけを行う。誤りも警告もあってはならない。
- `benitoite test` のブロックは `benitoite test` で実行する。そのテストはすべて通らなければならない。
- `benitoite error` のブロックは `benitoite check` で失敗しなければならず、直後の `diagnostic` のブロックの各行が報告に現れなければならない。
- 例の前の `files` のブロックは、スクリプトの隣にファイルを作る。最初の行は `name: <ファイル名>`、残りが中身である。
  名前に `/` を含むときは、途中のディレクトリを作る。
- ほかの情報文字列（`text` や `sh` など）のブロックは検査しない。
この訳のコードの例は検査しない。検査するのは英語の版である。
-->

このリファレンスは、Benitoite `0.0.2` を説明する。言語は、最初のリリースである `0.0.1` と同じである。Benitoite のスクリプトの書き方と実行の仕方を、例を添えて説明する。このファイルでプログラムとして印を付けた例は、すべてリポジトリのテストが `benitoite` で確かめている。

`benitoite` のインストールは、[Benitoite のインストール](install.md)を参照する。以前の最小の実装（`0.0.0`）は [benitoite-minimal.md](../../reference/benitoite-minimal.md) を参照する。両者の違いは [CHANGELOG](../../../CHANGELOG.md) に挙げてある。

Benitoite は、静的に型付けされた関数型のスクリプト言語である。スクリプトは `.bnt` のファイルである。何かを実行する前に、`benitoite` はスクリプトの型と、スクリプトが使うエフェクト（ファイルの書き込みやコマンドの起動など、各関数がプログラムの外で行ってよいこと）を検査する。検査が保証するのは、スクリプトがこれらの規則に従っていることだけである。スクリプトが意図どおりに動くこと、外部の操作が成功すること、スクリプトが終わることは保証しない。

## 目次

1. 最初のスクリプト
2. コマンドライン
3. プログラムの構造
4. 基本型とリテラル
5. 演算子
6. 関数とラムダ
7. データ型、レコード、パターンマッチ
8. 定数と型の別名
9. エラー: `Option`、`Result`、`try`
10. エフェクト
11. エフェクトハンドラ
12. モジュール
13. 型クラス
14. 明示遅延
15. 可変のセル、リソース、タスク
16. テスト
17. 整形
18. 診断
19. 標準ライブラリ
20. 互換性

## 1. 最初のスクリプト

次の内容を `hello.bnt` として保存する。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  Console.writeLine("Hello, world!")
end function
```

```output
Hello, world!
```

検査してから実行する。

```sh
benitoite check hello.bnt
benitoite run hello.bnt
```

`check` は、スクリプトに誤りも警告もなければ何も出力しない。`run` はスクリプトをもう一度検査してから `main` を呼ぶ。

最初の行は、モジュール `Console` を取り込む。`main` のシグネチャは、`uses` の後で、`main` がコンソールに書くこと（`Console.Write`）を示す。プログラムの外で何かを行う関数は、このようにそれを挙げなければならず、その関数を呼ぶすべての関数も同じである。`main` の `uses` を読めば、スクリプトが行いうることがすべてわかる。

## 2. コマンドライン

```text
benitoite [options] <script> [script arguments...]
benitoite run   [options] <script> [script arguments...]
benitoite check [options] <script>
benitoite test  [options] <path>...
benitoite fmt   [options] <path>...
benitoite skill install|uninstall [--user | --project] [--agent <name>]...
benitoite --help
benitoite --version
benitoite --licenses
```

| コマンド | 行うこと |
|---|---|
| `run` | スクリプトを検査し、その `main` を呼ぶ。スクリプトのパスの後の引数は、`-` で始まるときも、スクリプトに渡す（`Process.arguments()`）。 |
| `check` | スクリプトを実行せずに検査する。 |
| `test` | 指定したファイルの中、または指定したディレクトリの下のすべての `.bnt` ファイルの中のテストの関数を実行する。「16. テスト」を参照する。 |
| `fmt` | 指定したファイル、または指定したディレクトリの下のすべての `.bnt` ファイルを、標準の配置に書き換える。「17. 整形」を参照する。 |
| `skill` | 同梱の Agent Skill を、コーディングエージェントがスキルを読む場所に書き出す、または取り除く。[Benitoite のインストール](install.md)の「Agent Skill のインストール」の節を参照する。 |
| `--help` | 使い方を出力する。 |
| `--version` | 1 行目に `benitoite` の版（`benitoite 0.0.2`）を、2 行目に文字の関数が使う Unicode の版（`Unicode 17.0.0`）を出力する。 |
| `--licenses` | 実行ファイルに含まれる第三者のソフトウェアのライセンスを出力する。ソースからのビルドはこの一覧を含まず、そのことを出力する。 |

`<script>` は、ファイルか、`main.bnt` を含むディレクトリである。ファイル名と拡張子は確かめない。スクリプトのディレクトリが*根のディレクトリ*である。スクリプトは、根のディレクトリとその下、および標準ライブラリからモジュールを取り込める（「12. モジュール」）。`benitoite` は設定ファイルを読まない。

コマンドのない `benitoite script.bnt` は、`benitoite run script.bnt` を意味する。名前がコマンドと同じファイル（`check` など）は、`benitoite ./check` として実行する。名前 `server`、`mcp`、`sign`、`verify`、`repl`、`lsp`、`package`、`agent` は後の版のために予約してある。`benitoite server` は使い方の誤りである。

スクリプトを直接実行するには、ファイルを実行可能にし、先頭に次の行を置く。

```text
#!/usr/bin/env benitoite
```

Linux では `#!/usr/bin/env benitoite run` と書かない。Linux はインタプリタの名前より後をすべて一つの引数として渡すからである。オプションを渡すには、`#!/usr/bin/env -S benitoite --max-call-stack=2GiB` のように `env -S` を使う。

### オプション

オプションは、コマンドの後、スクリプトのパスの前に置く。

| オプション | 意味 | 既定 |
|---|---|---|
| `--diagnostics=text` または `--diagnostics=json` | 診断と、実行時エラーなどの報告の形式。`test` では、テストの結果の形式でもある。 | `text` |
| `--max-call-stack=<size>` | `run` と `test`（`test` ではテストごと）での入れ子の呼び出しの上限。`512MiB` のように、整数に `KiB`、`MiB`、`GiB` を付けて書く。 | `1GiB` |
| `--deny-warnings` | `check`、`run`、`test` で警告を誤りとして扱う。 | オフ |
| `--check` | `fmt` だけ。ファイルを書き換えずに、変わるはずのファイルを報告する。 | オフ |

### `run` と `check` の終了状態

| 状態 | 意味 |
|---:|---|
| 0 | `check` が誤りを見つけなかった。または `main` が `()` か `Result.Ok(())` を返した。 |
| 1 | `main` が `Result.Error` を返した。プログラムが実行時エラーで止まった、または資源の不足で止まった。またはコマンドラインの引数が正しい UTF-8 でない。 |
| 2 | スクリプトに検査の誤りがある（`--deny-warnings` のときは警告も）、`benitoite` の制限のために実行できない、または読めない。またはコマンドラインが誤っている。 |
| 3 | `benitoite` の処理系の不具合。報告してほしい。 |
| 130 | `run` が `SIGINT` か `SIGTERM` を受けた。終わる前に、すべてのタスクを取り消し、リソースを解放し、出力を書き出した。 |

`Process.exit(n)` を呼んだスクリプトは `n`（0〜255）で終わる。1、2、3 は `Process.exit` からも生じうるので、スクリプトを実行する道具は、標準エラー出力に `benitoite` の形式の報告があるかどうかでこれらを区別できる。

診断、実行時エラー、`main` が返した `Result.Error` のメッセージ、使い方の誤りは、標準エラー出力に出る。標準出力には、スクリプトが書いたものだけが出る。標準出力か標準エラー出力の読み手がいなくなると（閉じたパイプ）、プログラムは実行時エラーで止まり、終了状態は 1 になる。

`benitoite` はメモリに上限を設けない。上限を設けるには、`benitoite` を起動する道具（`ulimit`、コンテナ、エージェントのハーネス）を使う。

## 3. プログラムの構造

プログラムは、スクリプトのファイルの関数 `main` から始まる。`main` は引数を取らず、`Unit` か `Result[Unit, String]` を返す。`Result.Error(message)` を返すと、メッセージを標準エラー出力に書き、終了状態は 1 になる。

ファイルのトップレベルには、`import` の宣言、その後に宣言（関数、定数、データ型、型の別名、レコード、型クラス、実装、エフェクト）をこの順に置く。実行するコードは関数の中にだけ書く。

ブロックは、`end` とブロックを開いたキーワードで閉じる。`end function`、`end if`、`end match`、`end lambda`、`end data`、`end record`、`end trait`、`end implement`、`end effect`、`end handle`、`end with`、`end lazy` である。波括弧はなく、字下げに意味はない。文は改行で区切る。セミコロンはない。

ブロックの中では次のように書く。

- `bind name <- expression` は値に名前を付ける。名前に再び代入することはできない。
- `shadow name <- expression` は、既に見えている局所の名前を隠す名前を束縛する。既に局所の名前として見えている名前での `bind` は誤りなので、隠すことは常に明示する。
- `return expression` は関数を終え、値を返す。
- 1 行に単独で書いた式は文である。その値は `Unit` でなければならない。ほかの値を捨てるには `bind _ <- expression` と書く。

戻り値の型が `Unit` でない関数は、`return` で終わらなければならない（またはすべての分岐が値を返す `if` か `match` で終わる）。`if` の値、`match` の分岐の値、ハンドラの節の値、`with`・`handle`・`lazy` の本体の値は、その最後の式である。これらの中の `return` は、それを含む関数から抜ける。

`//` は行末までのコメントを始める。宣言の前の `///` はその宣言の説明であり、ファイルの先頭の `//!` はモジュールの説明である。識別子には ASCII の英字、数字、`_` を使う。関数、値、引数の名前は小文字で始め、型、構成子、モジュール、エフェクトの名前は大文字で始める。

```benitoite
//! Prints a short report.

import Benitoite.Unofficial.IO.Console

/// Returns the larger of two integers.
function larger(a: Integer, b: Integer) -> Integer
  if a > b then
    return a
  end if
  return b
end function

function main() -> Unit uses Console.Write
  bind total <- 10
  shadow total <- total + larger(3, 7)
  bind label <- if total > 15 then "big" else "small" end if
  Console.writeLine("${label}: ${total}")
end function
```

```output
big: 17
```

ループの文、`null`、例外はない。ループの代わりに再帰かリストの関数を、`null` の代わりに `Option` を、例外の代わりに `Result` と `try` を使う。

## 4. 基本型とリテラル

| 型 | 値 | リテラル |
|---|---|---|
| `Integer` | 符号付き 64 ビット整数 | `42`, `-7`, `1_000_000`, `0xff`, `0o755`, `0b1010` |
| `Float` | IEEE 754 binary64 | `3.14`, `1e10`, `1.2e-3` |
| `Decimal` | 128 ビットの十進小数。金額など、正確な十進の値のためのもの | `12m`, `1.25m`, `1_000.50m` |
| `Byte` | 0 から 255 までの整数 | なし。`Byte.fromInteger` を使う |
| `Character` | 一つの Unicode スカラー値 | `'a'`, `'あ'`, `'\n'` |
| `String` | Unicode スカラー値の変更できない列 | `"text"`, `"""…"""`, `r"…"` |
| `Boolean` | `true` と `false` | `true`, `false` |
| `Unit` | `()` だけ | `()` |

暗黙の変換はない。`Integer.toFloat`、`Integer.toString`、`Decimal.fromInteger`、`Integer.parse`（`Option[Integer]` を返す）などの変換の関数を使う。

`Integer` の桁あふれと、0 による `div` や `mod` は、実行時エラーでプログラムを止める。`Float` の除算は IEEE 754 に従い、0 で割ると無限大か NaN になる。`Float` のリテラルは小数点の両側に数字が要る（`1.` や `.5` ではなく `1.0`）。

### 文字列

文字列のリテラルは 1 行に収める。エスケープは `\n`、`\r`、`\t`、`\\`、`\"`、`\$`、`\u{H}`（十六進で書いた Unicode スカラー値）である。文字列の中の `${expression}` は式の値を埋め込む（文字列補間）。`{` が続く `$` そのものを書くには `\$` と書く。基本型の値は直接埋め込める。ほかの型は、先に `String` に変換する。

複数行の文字列は、行末の `"""` で始まり、単独の行の `"""` で終わる。閉じる `"""` の前の字下げを、各行から取り除く。生の文字列 `r"…"`（または `r"""…"""`）は、エスケープも `${…}` も処理しないので、正規表現に便利である。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind name <- "Ada"
  bind price <- 1.25m
  bind page <- """
    <p>Hello, ${name}</p>
    <p>Total: ${price * 3m}</p>
    """
  Console.write(page)
  Console.writeLine(r"\d+ and ${not interpolated}")
  Console.writeLine("${String.characterCount("héllo")} characters, ${String.byteLength("héllo")} bytes")
  Console.writeLine(Decimal.toString(Decimal.round(2.675m, 2, RoundingMode.HalfToEven)))
end function
```

```output
<p>Hello, Ada</p>
<p>Total: 3.75</p>
\d+ and ${not interpolated}
5 characters, 6 bytes
2.68
```

`String.length` はない。`String.characterCount`（Unicode スカラー値の数）か `String.byteLength`（UTF-8 のバイト数）を選ぶ。文字列の比較は Unicode スカラー値による比較であり、テキストを正規化しない。

## 5. 演算子

優先順位の低いものから順に挙げる。

| 演算子 | 意味 | 結合 |
|---|---|---|
| `|>` | パイプ: `x |> f(a)` は `f(x, a)` | 左 |
| `or` | 論理和（短絡） | 左 |
| `and` | 論理積（短絡） | 左 |
| `=` `<>` `<` `<=` `>` `>=` | 比較 | なし（`a < b < c` は誤り） |
| `+` `-` | 加算、減算。`+` は文字列の連結にも使う | 左 |
| `*` `/` `div` `mod` | 乗算。`/` は `Float` と `Decimal` に、`div` と `mod` は `Integer` に使う | 左 |
| `-` `not` | 符号の反転、否定 | 前置 |
| `f(...)` | 呼び出し | 後置 |

`==`、`!=`、`&&`、`||`、`!`、`%` はない。`div` は 0 の方向に丸め、`mod` の符号は被除数に従う。`-7 div 2` は `-3`、`-7 mod 2` は `-1` である。負の無限大の方向に丸めるには `Integer.floorDivide` と `Integer.floorModulo` を使う。`Integer` に `/` はない。

`=` と `<>` は、*等値の型*の値を比べる。等値の型は、関数の型も中身を見せない型（`IOError`、`NetworkError`、`Reference`、`Lazy`、`Task`、リソース、`Regex.Pattern` など）も含まない型である。リスト、マップ、集合、オプション、結果、レコード、データ型は、中身で比べる。`<`、`<=`、`>`、`>=` は `Integer`・`Float`・`Decimal`・`Byte`・`Character`・`String` にだけ使える。`Float` の比較は IEEE 754 に従う。NaN は何とも、自分自身とも等しくないので、検出には `Float.isNaN` を使う。

演算の対象は左から右へ評価する。

## 6. 関数とラムダ

関数は、引数の型と、`->` の後に戻り値の型を宣言する。`uses` のない関数は純粋である。

```text
function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2
  ...
end function
```

呼び出しはカリー化しない。すべての引数を与える。*ラムダ*は関数の値であり、引数と戻り値の型を省いてよい。関数と同じく、ラムダは `return` で値を返す。`Unit` を返すラムダは、代わりに文で終わってよい。

呼び出しの直接の引数としての `_` は、欠けた引数を受け取る関数を作る。`Integer.maximum(_, 0)` は `lambda(x) return Integer.maximum(x, 0) end lambda` である。パイプ `x |> f(a, b)` は、`x` を第 1 引数として渡し、`f(x, a, b)` となる。右の呼び出しに `_` があるときは、パイプは代わりにその位置を埋める。

型パラメータは、名前の後の角括弧に書く。`function first[T](xs: List[T]) -> Option[T]` のように書く。型引数も角括弧を使う。`List[Integer]`、`Map[String, Integer]` のように書く。*エフェクト変数*は、エフェクトの集合を表す型パラメータである。エフェクト変数を使うと、関数は任意のエフェクトを持つ関数を引数に取り、そのエフェクトをそのまま自分のエフェクトにできる。

```benitoite
import Benitoite.Unofficial.IO.Console

function between(low: Integer, value: Integer, high: Integer) -> Boolean
  return low <= value and value <= high
end function

function twice[T, effect E](x: T, f: function(T) -> T uses E) -> T uses E
  return f(f(x))
end function

function main() -> Unit uses Console.Write
  bind text <- [1, 2, 3, 4, 5]
    |> List.filter(_, between(2, _, 4))
    |> List.map(_, Integer.toString)
    |> String.join(_, ",")
  Console.writeLine(text)
  Console.writeLine(Integer.toString(twice(5, lambda(n) return n * 3 end lambda)))
  bind shout <- lambda(s: String) -> String
    Console.writeLine("shouting ${s}")
    return String.toUppercase(s)
  end lambda
  Console.writeLine(twice("hi", shout))
end function
```

```output
2,3,4
45
shouting hi
shouting HI
HI
```

`twice` はエフェクト変数 `E` を持つ。純粋なラムダを渡して呼ぶと純粋であり、コンソールに書く `shout` を渡して呼ぶと `Console.Write` を使う。`main` はこのエフェクトを宣言している。

末尾位置の呼び出し（`return f(...)`）は、異なる関数の間でも、呼び出しのスタックを伸ばさない。ループは、この形の再帰の関数として書くか、`List.map`、`List.fold`、`List.forEach` を使う。末尾位置にない深い再帰は、`--max-call-stack` で制限される。

## 7. データ型、レコード、パターンマッチ

### データ型

データ型は、その構成子を 1 行に一つずつ挙げる。構成子は、式でもパターンでも、常に型の名前を付けて書く。`Shape.Circle(1.0)`、`Option.Some(x)`、`Result.Error(e)` のように書く。`Pair` や `Triple` のように、唯一の構成子が型と同じ名前を持つ型は、型の名前を付けずに書く。`Pair(1, "one")` のように書く。

### レコード

レコードは名前の付いたフィールドを持つ。名前付きの引数で作り、フィールドを `Type.field(value)` で読み、一部のフィールドを変えた写しを `Type(..value, field: newValue)` で作る。`value.field` は正しくない。

### パターンマッチ

`match value with` の後に、分岐ごとに一つの `case pattern -> body` を置き、`end match` で閉じる。分岐は順に試す。検査器は、すべての値を網羅しない `match` と、決して選ばれない分岐を報告する。

パターンには次のものがある。

- `_`（何でも）、名前（値を束縛する）、`Integer`、`String`、`Character`、`Boolean` のリテラル。
- 構成子 `Shape.Circle(r)` と、レコード `Person(name: n, ..)`。
- 両端を含む範囲 `0..9` と `'a'..'z'`。
- リスト `[]`、`[x]`、`[first, ..rest]`、`[.., last]`。
- コンマで区切った複数の選択肢 `case 1, 2 ->`。
- ガードを後に続けたもの `case n if n > 0 ->`。

リストのリテラルは、別のリストの要素を差し込む展開 `[first, ..rest]` を一つ含められる。`bind` と `shadow` は、`bind Pair(a, b) <- pair` のように、必ず照合するパターンを受け付ける。

```benitoite
import Benitoite.Unofficial.IO.Console

data Shape
  Circle(Float)
  Rectangle(Float, Float)
end data

record Item
  name: String
  price: Integer
  quantity: Integer
end record

function area(shape: Shape) -> Float
  return match shape with
    case Shape.Circle(r) -> 3.0 * r * r
    case Shape.Rectangle(w, h) -> w * h
  end match
end function

function describe(xs: List[Integer]) -> String
  return match xs with
    case [] -> "empty"
    case [x] -> "one: ${x}"
    case [first, ..rest] if first < 0 -> "starts negative, ${List.length(rest)} more"
    case [first, ..] -> "starts with ${first}"
  end match
end function

function grade(score: Integer) -> String
  return match score with
    case 90..100 -> "A"
    case 70..89 -> "B"
    case 0, 1 -> "almost nothing"
    case _ -> "C"
  end match
end function

function main() -> Unit uses Console.Write
  List.forEach([Shape.Circle(1.0), Shape.Rectangle(2.0, 3.5)], lambda(s)
    Console.writeLine(Float.toString(area(s)))
  end lambda)
  bind item <- Item(name: "pen", price: 120, quantity: 3)
  bind more <- Item(..item, quantity: 10)
  Console.writeLine("${Item.name(more)}: ${Item.price(more) * Item.quantity(more)}")
  bind Pair(low, high) <- Pair(1, 9)
  Console.writeLine(describe([low, ..[high, 4]]))
  Console.writeLine(describe([-1, 2, 3]))
  Console.writeLine("${grade(95)} ${grade(75)} ${grade(1)} ${grade(50)}")
end function
```

```output
3.0
7.0
pen: 1200
starts with 1
starts negative, 2 more
A B almost nothing C
```

データ型とレコードは型パラメータを持てる。たとえば、構成子 `Leaf` と `Node(Tree[T], T, Tree[T])` を持つ `data Tree[T]` である。

## 8. 定数と型の別名

`const` は、トップレベルで定数を宣言する。型は必須であり、値はプログラムの実行の前に計算できなければならない。使えるのは、リテラル、ほかの定数、構成子、レコード、リスト、演算子、定数の文字列補間、`Map.fromList`、`Set.fromList`、`Map.empty()`、`Set.empty()` である。定数は、括弧を付けずに名前で参照する。

`type Name = Type` は、型の別の名前を宣言する。新しい型は作らない。

```benitoite
import Benitoite.Unofficial.IO.Console

type UserId = Integer

const defaultPort: Integer = 8000 + 80
const banner: String = "listening on ${defaultPort}"
const statusNames: Map[Integer, String] = Map.fromList([Pair(200, "OK"), Pair(404, "Not Found")])

function lookup(id: UserId) -> String
  return Option.unwrapOr(Map.get(statusNames, id), "unknown")
end function

function main() -> Unit uses Console.Write
  Console.writeLine(banner)
  Console.writeLine(lookup(404))
end function
```

```output
listening on 8080
Not Found
```

## 9. エラー: `Option`、`Result`、`try`

値がないことがある操作は `Option[T]`（`Option.Some(x)` か `Option.None`）を返す。失敗することがある操作は `Result[T, E]`（`Result.Ok(x)` か `Result.Error(e)`）を返す。IO の操作は `Result[T, IOError]` を返す。ファイルがないことは値であり、異常終了ではない。

`try e` は `e` を評価する。それが `Result.Error`（または `Option.None`）なら、関数は直ちにそれを返す。そうでなければ、`try` は中の値を与える。`try` は、パイプを含め、右側の式の全体に掛かり、`Result`（または `Option`）を返す関数の中でだけ使える。エラーの型が違うときは、先に変換する。ふつうは `Result.mapError` を使う。

```benitoite
import Benitoite.Unofficial.IO.Console

function parsePort(text: String) -> Result[Integer, String]
  return match Integer.parse(text) with
    case Option.Some(n) if n > 0 and n < 65536 -> Result.Ok(n)
    case _ -> Result.Error("not a port: ${text}")
  end match
end function

function main() -> Result[Unit, String] uses Console.Write
  bind port <- try parsePort("8080")
  Console.writeLine("port ${port}")
  bind other <- try parsePort("http")
  Console.writeLine("never printed ${other}")
  return Result.Ok(())
end function
```

```output
port 8080
exit 1
```

```stderr
not a port: http
```

値にならない失敗もある。`Integer` の桁あふれ、0 による除算、大きすぎて作れない値、呼び出しのスタックの使い果たしは、実行時エラーでプログラムを*止め*、終了状態は 1 になる。`match` はこれらを捕えられない。報告は、その場所と、そこに至った呼び出しを示す。

## 10. エフェクト

*エフェクト*は、関数が純粋な計算の外で行ってよい操作の種類を名指す。関数は、直接に、または呼ぶ関数を通じて行うすべてのエフェクトを、`uses` の後に挙げる。`uses` のない関数は純粋である。ラムダは、そのエフェクトを本体から推論する。

組み込みのエフェクトは次のとおりである。

| エフェクト | 許すこと |
|---|---|
| `Console.Write` | 標準出力と標準エラー出力への書き込み |
| `Console.Read` | 標準入力の読み込み |
| `File.Read` | ファイルとディレクトリの読み込み |
| `File.Write` | ファイルとディレクトリの作成、変更、移動、削除 |
| `Process.Run` | 外部のコマンドの起動 |
| `Process.Exit` | 選んだ終了コードでのプログラムの終了 |
| `Process.Environment` | コマンドラインの引数、環境変数、作業ディレクトリ、スクリプトのディレクトリの読み込み |
| `Clock.Time` | 時計の読み込みと待つこと |
| `Random.Generate` | 乱数の生成 |
| `Http.Listen` | HTTP のサーバとしての接続の受け付け |
| `Http.Connect` | HTTP のサーバへの接続 |
| `State` | プログラムの中の可変のセルと並行のタスク |
| `Assert.Check` | テストでの期待の確かめ |
| `IO.All` | `Console`、`File`、`Process`、`Clock`、`Random`、`State` のすべて（ネットワークのエフェクトは含まない） |

エフェクトが示すのは、関数が行ってよい操作の*種類*であり、どのファイル、コマンド、ホストかではない。`check` を通ったスクリプトは、`main` の `uses` の外の組み込みの操作を行わない。この版は、スクリプトの実行中に操作を制限しない。信頼しないスクリプトはサンドボックスの中で実行する。`main` の読み手がスクリプトの行うことを見てとれるように、`IO.All` よりも個々のエフェクトを挙げるほうを選ぶ。

```benitoite error
import Benitoite.Unofficial.IO.Console

function greet(name: String) -> Unit
  Console.writeLine("Hello, ${name}")
end function

function main() -> Unit uses Console.Write
  greet("Ada")
end function
```

```diagnostic
error[E0501]
```

`greet` に `uses Console.Write` を加えると、誤りは直る。

エフェクトは関数の値の型の一部である。`function(String) -> Unit uses Console.Write` のように書く。

## 11. エフェクトハンドラ

エフェクトは自分で宣言できる。`effect` の宣言はその操作を挙げ、操作は関数と同じように呼ぶ。`handle body with case operation(arguments) -> clause end handle` は `body` を実行し、本体が挙げた操作のどれかを呼ぶたびに、代わりに節を実行する。節の中の `resume(value)` は、`value` を操作の結果として本体を続ける。`resume` を呼ばない節は、自分の値で `handle` を終える。

```benitoite
import Benitoite.Unofficial.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function sumPrices(items: List[Integer]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(items, 0, lambda(acc, x) return acc + x end lambda)
end function

function main() -> Unit uses Console.Write
  bind total <- handle
    sumPrices([120, 300, 80])
  with
    case write(message) ->
      Console.writeLine("log: ${message}")
      resume(())
  end handle
  Console.writeLine("total: ${total}")
end function
```

```output
log: items: 3
total: 500
```

`File.readText` や `Process.run` などの組み込みのエフェクトの操作も、同じように処理できる。テストはこの方法で外の世界を置き換える（「16. テスト」）。エフェクトの操作の一部だけを処理するハンドラは、そのエフェクトを型から取り除かない。エフェクトに `State` を含む関数（`Reference`、`TaskGroup`、`Task.await`、`close…` の関数）は処理できない。

`uses` と `case` では、同じモジュールで宣言したエフェクトや操作はモジュールの名前を付けずに書き（`Log`、`write`）、別のモジュールのものは付けて書く（`Logging.Log`、`Logging.write`、`Console.writeLine`）。

## 12. モジュール

各ファイルは一つのモジュールである。モジュールの名前は、根のディレクトリからのパスの `/` を `.` に置き換え、`.bnt` を除いたものである。ファイル `Lib/Text.bnt` はモジュール `Lib.Text` である。`import Lib.Text` はそれを `Text` として使えるようにし、`import Lib.Text as T` は `T` として使えるようにする。ほかのモジュールから使えるのは、`public` を付けた宣言だけである。取り込みは循環してはならない。

```files
name: Lib/Text.bnt
/// Turns "Hello World" into "hello-world".
public function slug(text: String) -> String
  return String.toLowercase(String.replace(String.trim(text), " ", "-"))
end function
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Lib.Text

function main() -> Unit uses Console.Write
  Console.writeLine(Text.slug(" Hello World "))
end function
```

```output
hello-world
```

### 標準のモジュールと非公式のモジュール

標準ライブラリのモジュールの名前は `Benitoite.<Name>` である。中核のモジュール（`Integer`、`String`、`List`、`Map`、`Option`、`Result` など）の大半は *prelude* にあり、`import` なしで使える。

この版では、IO とネットワークのモジュール、およびテキストとデータのモジュールは*非公式*である。そのインターフェースはまだ変わることがあるので、`Benitoite.Unofficial` の下で取り込む。`import Benitoite.Unofficial.IO.Console` と書き、モジュールを `Console` として参照する。この版では `import Benitoite.IO.Console` は誤りである。後のマイナー版で非公式のモジュールが標準になると、その取り込みの名前は `Benitoite.<Name>` に変わり、スクリプトは取り込みを変えなければならない。

prelude の外のモジュールは、`uses` にだけ現れるときも、すべて取り込まなければならない。一覧は「19. 標準ライブラリ」を参照する。

## 13. 型クラス

*型クラス*（`trait`）は、複数の型が実装する関数を宣言する。`implement` は一つの型についての実装を与える。型パラメータは `[T: Show]` で制約でき、複数の制約は `&` でつなぐ。組み込みの制約 `equality`（値を `=` で比べられる）と `key`（値を `Map` のキーと `Set` の要素にできる）も、同じ場所で使える。メソッドはクラスの名前を通して呼ぶ。`Describe.describe(x)` のように書く。

```benitoite
import Benitoite.Unofficial.IO.Console

trait Describe[T]
  function describe(x: T) -> String
end trait

implement Describe[Integer]
  function describe(x: Integer) -> String
    return "the number ${x}"
  end function
end implement

implement[T: Describe] Describe[List[T]]
  function describe(xs: List[T]) -> String
    return "[" + String.join(List.map(xs, Describe.describe), ", ") + "]"
  end function
end implement

function describeIfSame[T: Describe & equality](a: T, b: T) -> String
  return if a = b then Describe.describe(a) else "different" end if
end function

function main() -> Unit uses Console.Write
  Console.writeLine(Describe.describe([1, 2]))
  Console.writeLine(describeIfSame(3, 3))
end function
```

```output
[the number 1, the number 2]
the number 3
```

実装はプログラムの全体に適用される。実装は、クラスのモジュールか型のモジュールに置かなければならず、二つの実装が重なってはならない。`Show`、`Order`、`Monoid`、`Functor`、`Monad` などの標準のクラスは、モジュール `Benitoite.Trait` にある。

## 14. 明示遅延

`lazy ... end lazy` は、本体を評価せずに `Lazy[T]` の型の値を作る。`Lazy.force(value)` は、最初に本体を評価し、その後は保存した結果を返す。本体は純粋でなければならない。

```benitoite
import Benitoite.Unofficial.IO.Console

function choose(useFirst: Boolean, first: Lazy[Integer], second: Lazy[Integer]) -> Integer
  return if useFirst then Lazy.force(first) else Lazy.force(second) end if
end function

function main() -> Unit uses Console.Write
  bind result <- choose(true, lazy 42 end lazy, lazy 100 div String.characterCount("") end lazy)
  Console.writeLine("${result}")
end function
```

```output
42
```

0 による除算は評価されない。

## 15. 可変のセル、リソース、タスク

### 可変のセル

`Reference` は可変のセルである。`Reference.new`、`Reference.get`、`Reference.set` はエフェクト `State` を要する。値そのものは決して変わらない。リスト、マップ、集合は永続的であり、その関数は新しいコレクションを返す。

### リソースと `with`

`with name = expression do ... end with` は、HTTP のリスナーやタスクの集まりなどのリソースを束縛し、ブロックが終わるとき（`return`、`try`、実行時エラーで終わるときも）に解放する。複数のリソースはコンマで区切り、逆の順に解放する。解放はエフェクト `State` を持つので、`with` を使う関数は `uses` に `State` を並べる。

### タスク

タスクは、一つのプログラムの中で並行に動く。`TaskGroup.open()` は集まりをリソースとして開く。`TaskGroup.spawn(group, lambda() ... end lambda)` はその中でタスクを起動し、`Task.await(task)` はその結果を待つ。`end with` で集まりを解放すると、そのすべてのタスクを待つ。`Task.all` は関数のリストをタスクとして実行し、その結果を順に返す。`Task.withTimeout` と `Task.race` は、時間が経つか最初の結果が出ると待つのをやめる。ファイルの読み込み、HTTP の要求、`Clock.sleep` など、待つ操作の間は、ほかのタスクが動ける。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write, State
  bind counter <- Reference.new(0)
  bind squares <- with group = TaskGroup.open() do
    bind tasks <- List.map([1, 2, 3], lambda(n)
      return TaskGroup.spawn(group, lambda()
        Reference.set(counter, Reference.get(counter) + 1)
        return n * n
      end lambda)
    end lambda)
    List.map(tasks, lambda(task) return Task.await(task) end lambda)
  end with
  Console.writeLine("${String.join(List.map(squares, Integer.toString), " ")} after ${Reference.get(counter)} tasks")
  Console.writeLine(String.join(List.map(Task.all([lambda() return "a" end lambda, lambda() return "b" end lambda]), lambda(s) return s end lambda), ""))
end function
```

```output
1 4 9 after 3 tasks
ab
```

タスクが実行時エラーで止まると、プログラムが止まる。プログラムが中断されると、すべてのタスクを取り消し、リソースを解放する。

## 16. テスト

テストは、属性 `@test("description")` を付け、引数がなく、戻り値の型が `Unit` か `Result[Unit, String]` の関数である。値は `Assert.equal(actual, expected)` と `Assert.isTrue(condition, message)` で確かめる。これらはエフェクト `Assert.Check` を要する。確かめが失敗すると、そのテストは止まる。`Result.Error(message)` を返しても失敗する。各テストは単独で動くので、一つのテストの失敗や実行時エラーはほかのテストを止めない。

```benitoite test
import Benitoite.Unofficial.IO.File

function countWords(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Result.Ok(List.length(List.filter(String.split(text, " "), lambda(w) return w <> "" end lambda)))
end function

@test("countWords counts words separated by spaces")
function countWordsCounts() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    countWords("notes.txt")
  with
    case File.readText(path) ->
      Assert.equal(path, "notes.txt")
      resume(Result.Ok("one two  three"))
  end handle
  Assert.equal(result, Result.Ok(3))
end function
```

ハンドラが `File.readText` を置き換えるので、テストはファイルを読まない。操作を処理してもそのエフェクトは型から取り除かれないので、テストは `File.Read` を挙げたままである。

テストは `benitoite test` で実行する。通るテストを一つと、`Assert.equal(double(2), 5)` を確かめるテストを一つ含むファイル `t.bnt` では、報告は次のようになる。

```sh
benitoite test t.bnt
```

```text
test t.bnt: "double doubles" ... ok
test t.bnt: "fails" ... FAILED

failures:

---- t.bnt: "fails" ----
assertion failed: Assert.equal
  left:  4
  right: 5
  --> t.bnt:12:3
   = note: call trace (innermost first):
             fails
   = note: functions left by tail calls are not shown

test result: FAILED. 1 passed; 1 failed
```

検査の誤りがあるファイルは実行しない。その診断は標準エラー出力に出て、ほかのファイルのテストは実行する。`benitoite check` は `main` のないファイルに誤りを報告するので、テストのファイルには `check` ではなく `test` を使う。

`--diagnostics=json` のとき、`test` は標準出力に 1 行に一つずつ JSON のオブジェクトを書く。テストごとに `"kind": "test"` のオブジェクトを一つ書き、その欄は `file`、`name`、`function`、`location`、`outcome`（`"passed"` か `"failed"`）、`failure`、`stdout`、`stderr` である。最後に、`"kind": "testSummary"` と、数 `passed`、`failed`、`filesNotRun`、および `interrupted` を持つオブジェクトを一つ書く。`failure` は `reason` と `message` を持つ。理由は、`"assert"`（確かめの失敗。`primary`、`trace`、および `Assert.equal` と `Assert.notEqual` では値 `left` と `right` を持つ）、`"error"`（テストが `Result.Error` を返した）、`"runtime"`（実行時エラー。実行時エラーの報告の欄を持つ）、`"exit"`（テストが `Process.exit` を呼んだ。`exitCode` を持つ）のどれかである。理由が `"assert"`、`"runtime"`、`"exit"` の失敗は、`notes` も持つ。`notes` は文字列の配列であり、止まる途中のリソースの解放の失敗を含む。

`test` の終了状態は、すべてのテストが通れば 0、テストが失敗すれば 1、検査の誤り、読めないファイル、使い方の誤りでは 2、処理系の不具合では 3、中断されたときは 130 である。複数が当てはまるときは、130、3、2、1 の順で最初のものを使う。

## 17. 整形

`benitoite fmt` は、ファイルを標準の配置に書き換える。変えるのは空白（行の中の空白、字下げ、空行、行末の空白）だけである。改行とコメントを保ち、字句を加えも除きもせず、設定を持たない。`fmt` は構文だけを検査するので、型の誤りがあるファイルも整形できる。字句の誤りか構文の誤り（コード `E01nn` と `E02nn`）があるファイルは変えずに残し、その診断を報告する。ほかのファイルは整形する。ファイルを読む間に見つかるほかの誤り（誤った属性など）は、整形を止めない。

`fmt --check` は何も書き換えず、変わるはずのファイルを標準エラー出力に挙げる。`fmt` は標準出力に何も書かない。ファイルは新しい中身を書き終えた後にだけ置き換えるので、中断された `fmt` が壊れたファイルを残すことはない。

`fmt` の終了状態は、成功では 0、`--check` が変わるはずのファイルを見つけたときは 1、構文の誤り、読めないか書けないファイル、使い方の誤りでは 2、処理系の不具合では 3 である。

## 18. 診断

診断はコードを持つ。誤りは `E`、警告は `W`、`benitoite` の制限は `L` で始まる（`L` は `run` と `test` だけが報告するので、`check` を通ったスクリプトでも、`run` が状態 2 で終わることがある）。テキストの形式は、コード、ソースの中の場所、そしてしばしば修正案を示す `= help:` を示す。

```benitoite error
function main() -> Unit
  let total = 1 + 2
end function
```

```diagnostic
error[E0230]: `let` is not used to bind names
   = help: write `bind total <- 1 + 2`
```

警告は、`check`、`run`、`test` が報告するが、`--deny-warnings` を与えない限り、それらを失敗させない。

`--diagnostics=json` のとき、各診断は標準エラー出力の 1 行ずつに一つの JSON のオブジェクトとして出る。その欄は `kind`、`severity`、`code`、`message`、`primary`、`secondary`、`notes`、`helps` である。`primary` は主な場所（ないときは `null`）であり、`file`、`start`、`end`（それぞれ `line`、`column`、`offset` を持つ）、`label` を持つ。`helps` の各要素は、`message` と、置き換えの配列 `edits` を持つオブジェクトである。各置き換えは `file`、`start`、`end`、および `replacement` のテキストを持つ。機械的な修正のない修正案の `edits` は空である。

診断は、メッセージではなく `code` と JSON の欄で区別する。メッセージと修正案の中身は、パッチ版でも変わることがある。取り除いたコードを、別の意味で再び使うことはない。

各コードの意味は、同梱の Agent Skill（`references/diagnostics.md`。`benitoite skill install` でインストールされる）に挙げてある。

## 19. 標準ライブラリ

prelude のモジュールは取り込みが要らない。ほかのモジュールは、表の名前で取り込む。各モジュールの関数の完全な一覧は、同梱の Agent Skill（`references/stdlib/`）にある。

| モジュール | 取り込み | 内容 |
|---|---|---|
| `Integer`, `Float`, `Decimal`, `RoundingMode`, `Byte`, `Character`, `String`, `Boolean` | prelude | 基本型の関数 |
| `List`, `Map`, `Set` | prelude | 永続的なコレクション。マップと集合はキーの順に並ぶ |
| `Option`, `Result`, `Pair`, `Triple` | prelude | ないことがある値、結果、組 |
| `Bytes`, `ByteOrder` | prelude | 変更できないバイト列 |
| `IOError`, `IOErrorKind`, `NetworkError`, `NetworkErrorKind` | prelude | IO とネットワークの操作の失敗 |
| `Reference`, `Lazy`, `Task`, `TaskGroup` | prelude | 可変のセル、明示遅延、タスク |
| `Assert` | prelude | テストでの確かめ |
| `IO` | prelude | エフェクト `IO.All` |
| `Trait` | `import Benitoite.Trait` | 標準の型クラス |
| `IO.Console` | `import Benitoite.Unofficial.IO.Console` | 標準入力と標準出力 |
| `IO.File` | `import Benitoite.Unofficial.IO.File` | ファイルとディレクトリ |
| `IO.Process` | `import Benitoite.Unofficial.IO.Process` | 引数、環境、外部のコマンド、終了 |
| `IO.Clock` | `import Benitoite.Unofficial.IO.Clock` | 時計と待つこと |
| `IO.Random` | `import Benitoite.Unofficial.IO.Random` | 乱数 |
| `Time` | `import Benitoite.Unofficial.Time` | 時点と暦の日付 |
| `Path` | `import Benitoite.Unofficial.Path` | パスの結合と分割 |
| `Json` | `import Benitoite.Unofficial.Json` | JSON |
| `Csv` | `import Benitoite.Unofficial.Csv` | CSV（RFC 4180） |
| `Regex` | `import Benitoite.Unofficial.Regex` | 照合の時間が入力に対して線形の正規表現 |
| `Encoding` | `import Benitoite.Unofficial.Encoding` | Base64 |
| `Hash` | `import Benitoite.Unofficial.Hash` | バイト列の SHA-256 のハッシュ値 |
| `Network.Http` | `import Benitoite.Unofficial.Network.Http` | TLS のない HTTP/1.1 のサーバと、`http` と `https` のクライアント |

知っておくとよい振る舞いをいくつか挙げる。

- 相対のファイルのパスは、作業ディレクトリを基準に解決する。スクリプトの隣のファイルには `Process.scriptDirectory()` を使う。
- `Process.run` は、シェルを介さず、引数のリストでプログラムを起動する。0 でない終了コードは誤りではなく、結果から読む。コマンドが与えた `input` をすべては読まないとき（`head` のように）も、誤りではない。
- `Process.shell` は、コマンドラインを `/bin/sh -c` で実行する。POSIX sh だけを書く。
- `Http.get` と `Http.send` は、標準のメソッド（大文字の `GET`、`HEAD`、`POST`、`PUT`、`DELETE`、`CONNECT`、`OPTIONS`、`TRACE`、`PATCH`）だけを受け付ける。ほかのメソッド、または `GET`、`HEAD`、`CONNECT` での本文は、何も送らずに `NetworkErrorKind.InvalidInput` を与える。解決できないホスト名は `NetworkErrorKind.HostNotFound` を与える。

次の例は、JSON のファイルを読み、分類ごとに金額を合計する。

```files
name: orders.json
[
  {"category": "book", "amount": 1200},
  {"category": "food", "amount": 300},
  {"category": "book", "amount": 800}
]
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Json

function amountOf(order: Json.Value) -> Option[Pair[String, Integer]]
  bind category <- try Option.andThen(Json.get(order, "category"), Json.asString)
  bind amount <- try Option.andThen(Json.get(order, "amount"), Json.asInteger)
  return Option.Some(Pair(category, amount))
end function

function main() -> Result[Unit, String] uses File.Read, Console.Write
  bind text <- try File.readText("orders.json") |> Result.mapError(_, IOError.message)
  bind value <- try Json.parse(text) |> Result.mapError(_, Json.ParseError.message)
  bind orders <- try Option.okOr(Json.asArray(value), "orders.json is not an array")
  bind totals <- List.fold(orders, Map.empty(), lambda(m, order)
    return match amountOf(order) with
      case Option.Some(Pair(category, amount)) ->
        Map.set(m, category, Option.unwrapOr(Map.get(m, category), 0) + amount)
      case Option.None -> m
    end match
  end lambda)
  Map.forEach(totals, lambda(category, total)
    Console.writeLine("${category}: ${total}")
  end lambda)
  return Result.Ok(())
end function
```

```output
book: 2000
food: 300
```

## 20. 互換性

メジャー版が 0 の間は、次のとおりとする。

- マイナー版（`0.1.0` から `0.2.0`）は、言語、標準ライブラリ、コマンドライン、診断を、互換性のない形で変えることがある。互換性のない変更は、それぞれ移行の方法とともに [CHANGELOG](../../../CHANGELOG.md) に挙げる。
- パッチ版（`0.1.0` から `0.1.1`）は、不具合（`benitoite` の振る舞いのうち、その仕様と異なるもの）だけを直す。言語、標準ライブラリ（非公式のモジュールを含む）、コマンドライン、診断のコード、JSON の形式は変えない。診断のメッセージと修正案は変わることがある。
- 非公式のモジュールを標準ライブラリへ移すと、その取り込みの名前が変わる。これはマイナー版でだけ行う。
- 同梱の Agent Skill は、一緒に配られた版の `benitoite` だけを説明する。更新した後は `benitoite skill install` を再び実行する。

> 注記: `0.0.2` は、`0.0.1` と同じく、ソースコードだけのリリースであり、実行ファイルは配らない。実行ファイルは `0.1.0` から配り、それまではどのリリースも互換性のない変更を含むことがある。
