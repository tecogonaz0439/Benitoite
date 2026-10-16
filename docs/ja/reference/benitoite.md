# Benitoite 言語リファレンス

> この文書は、`docs/reference/benitoite.md` の日本語の訳である。翻訳元は Benitoite 0.0.6 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

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

このリファレンスは、[第 21 節](#21-実験的な機能-パッケージと外部の関数)の実験的な機能を含めて、Benitoite `0.0.6` を説明する。Benitoite のスクリプトの書き方と実行の仕方を、例を添えて説明する。このファイルでプログラムとして印を付けた例は、すべてリポジトリのテストが `benitoite` で確かめている。

`benitoite` のインストールは、[Benitoite のインストール](install.md)を参照する。

Benitoite は、静的に型付けされた関数型のスクリプト言語である。スクリプトは `.bnt` のファイルである。何かを実行する前に、`benitoite` はスクリプトの型と、スクリプトが使うエフェクト（ファイルの書き込みやコマンドの起動など、各関数がプログラムの外で行ってよいこと）を検査する。検査が保証するのは、スクリプトがこれらの規則に従っていることだけである。スクリプトが意図どおりに動くこと、外部の操作が成功すること、スクリプトが終わることは保証しない。

## 目次

1. [最初のスクリプト](#1-最初のスクリプト)
2. [コマンドライン](#2-コマンドライン)
3. [プログラムの構造](#3-プログラムの構造)
4. [基本型とリテラル](#4-基本型とリテラル)
5. [演算子](#5-演算子)
6. [関数とラムダ](#6-関数とラムダ)
7. [データ型、レコード、パターンマッチ](#7-データ型レコードパターンマッチ)
8. [定数と型の別名](#8-定数と型の別名)
9. [エラー: `Option`、`Result`、`try`](#9-エラー-optionresulttry)
10. [エフェクト](#10-エフェクト)
11. [エフェクトハンドラ](#11-エフェクトハンドラ)
12. [モジュール](#12-モジュール)
13. [型クラス](#13-型クラス)
14. [明示遅延](#14-明示遅延)
15. [可変のセル、リソース、タスク](#15-可変のセルリソースタスク)
16. [テスト](#16-テスト)
17. [整形](#17-整形)
18. [診断](#18-診断)
19. [標準ライブラリ](#19-標準ライブラリ)
20. [互換性](#20-互換性)
21. [実験的な機能: パッケージと外部の関数](#21-実験的な機能-パッケージと外部の関数)

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
benitoite package add|update|move ...
benitoite --help
benitoite --version
benitoite --licenses
```

| コマンド | 行うこと |
|---|---|
| `run` | スクリプトを検査し、その `main` を呼ぶ。スクリプトのパスの後の引数は、`-` で始まるときも、スクリプトに渡す（`Process.arguments()`）。 |
| `check` | スクリプトを実行せずに検査する。 |
| `test` | 指定したファイルの中、または指定したディレクトリの下のすべての `.bnt` ファイルの中のテストの関数を実行する。ただし、`package.bnt` と入れ子のパッケージは除く。[16. テスト](#16-テスト)を参照する。 |
| `fmt` | 指定したファイル、または指定したディレクトリの下のすべての `.bnt` ファイルを、標準の配置に書き換える。[17. 整形](#17-整形)を参照する。 |
| `skill` | 同梱の Agent Skill を、コーディングエージェントがスキルを読む場所に書き出す、または取り除く。[Benitoite のインストール](install.md#3-agent-skill-をインストールする)を参照する。 |
| `package` | 実験的な機能。局所の依存の宣言を追加・更新・移動する。[パッケージのコマンド](#パッケージのコマンド)を参照する。 |
| `--help` | 使い方を出力する。 |
| `--version` | 1 行目に `benitoite` の版（`benitoite 0.0.6`）を、2 行目に文字の関数が使う Unicode の版（`Unicode 17.0.0`）を出力する。 |
| `--licenses` | 実行ファイルに含まれる第三者のソフトウェアのライセンスを出力する。ソースからのビルドはこの一覧を含まず、そのことを出力する。 |

`<script>` は、ファイルか、`main.bnt` を含むディレクトリである。ファイル名と拡張子は確かめない。ただし、`package.bnt` は設定ファイルであり、起点のファイルにはできない。スクリプトのディレクトリが*根のディレクトリ*である。スクリプトは、根のディレクトリとその下、標準ライブラリ（[モジュール](#12-モジュール)）、宣言した局所の依存からモジュールを取り込める（[第 21 節](#21-実験的な機能-パッケージと外部の関数)）。`benitoite` は、根のディレクトリそのものにある `package.bnt` を設定ファイルとして読む。親のディレクトリや作業ディレクトリは探さない。

スクリプトとそのモジュールは、通常のファイルでなければならない。パイプを指すパス（パイプにつながった `/dev/stdin` や、シェルの `<(...)` など）は読めず、`E0101` として報告する。そうしたスクリプトは一時ファイルに書き出し、そのパスを渡す。

コマンドのない `benitoite script.bnt` は、`benitoite run script.bnt` を意味する。名前がコマンドと同じファイル（`check` など）は、`benitoite ./check` として実行する。名前 `server`、`mcp`、`sign`、`verify`、`repl`、`lsp`、`agent` は後の版のために予約してある。`benitoite server` は使い方の誤りである。

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

短いラムダ（[関数とラムダ](#6-関数とラムダ)を参照する）を除き、ブロックは、`end` とブロックを開いたキーワードで閉じる。`end function`、`end if`、`end match`、`end lambda`、`end data`、`end record`、`end trait`、`end implement`、`end effect`、`end handle`、`end with`、`end lazy` である。波括弧はなく、字下げに意味はない。文は改行で区切る。セミコロンはない。`return` の直後の物理改行は、括弧の中でも、次の行の先頭が継続用の演算子でも、常に文を終える。コメントや空行を挟んでも、この規則は変わらない。

ブロックの中では次のように書く。

- `bind name <- expression` は値に名前を付ける。名前に再び代入することはできない。
- `shadow name <- expression` は、既に見えている局所の名前を隠す名前を束縛する。既に局所の名前として見えている名前での `bind` は誤りなので、隠すことは常に明示する。`shadow` は有効な構文だが、推奨しない。意図して古い名前を隠す場合も、新しい値の意味を表す別の名前を使う。これは文書上の助言であり、警告は加えない。
- `return expression` は関数を終え、値を返す。値は `return` と同じ物理行で書き始める。値がなければ誤り（E0201）である。書き始めた後は、通常の継続の規則で複数行にできる。例えば、`return x +` の演算子の後、`return (` の括弧の中、`return f(` の引数の中、`return if condition then` の `then` の後で継続できる。短いラムダは、全体を一つの物理行に収める必要がある。
- 1 行に単独で書いた式は文である。その文がブロックの最後の文でないとき、または関数かラムダの本体の最後の文であるときは、その値は `Unit` でなければならない。ほかの値を捨てるには `bind _ <- expression` と書く。

戻り値の型が `Unit` でない関数は、`return` で終わらなければならない（またはすべての分岐が値を返す `if` か `match` で終わる）。`if` の値、`match` の分岐の値、ハンドラの節の値、`with`・`handle`・`lazy` の本体の値は、その最後の式である。`if`、`match` の分岐、ハンドラの節、`with` か `handle` の本体の中の `return` は、それを含む関数から抜ける。`lazy` の本体と `match` のガードは、`return` も `try` も含められない。ただし、そこに書いた `lambda ... end lambda` の中は除く。プレースホルダ `_` を持つ呼び出しの引数は、この除外に当たらない。

`//` は行末までのコメントを始める。宣言の前の `///` はその宣言の説明であり、ファイルの先頭の `//!` はモジュールの説明である。識別子には ASCII の英字、数字、`_` を使う。関数、値、引数の名前は小文字で始め、型、構成子、モジュール、エフェクトの名前は大文字で始める。

`die` は予約語であり、引数のラベル、フィールド、取り込みの別名、ドットの後の名前を含め、名前に使えない。`try e or die` と `try e or die(message)` の中でだけ受理し、単独の式にはできない。

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
  bind increased <- total + larger(a: 3, b: 7)
  bind label <- match increased > 15 with
    case true -> "big"
    case false -> "small"
  end match
  Console.writeLine("${label}: ${increased}")
end function
```

```output
big: 17
```

ループの文、`null`、例外はない。ループの代わりに再帰かリストの関数を、`null` の代わりに `Option` を、例外の代わりに `Result` と `try` を使う。

値や処理の選択には `match` を推奨する。条件成立時だけの処理や早期リターンには、上の `larger` のように `else` のない `if` を使う。`else` と `else if` は有効な構文だが、推奨しない。検査器はこれらに警告を加えない。選択を書き換えるときは、条件の評価回数と順序を保ち、選ばれた分岐だけを評価し、`return` の作用先を同じ関数かラムダに保つ。エフェクトを含む条件は match のガードにできないので、その真偽値に対する match を入れ子にする。

この例は、最初の条件が偽のときにだけ二つ目の条件を評価する。各 `return` は `choose` を終え、選ばれた結果だけを返す。

```benitoite
import Benitoite.Unofficial.IO.Console

function condition(label: String, value: Boolean) -> Boolean uses Console.Write
  Console.writeLine(label)
  return value
end function

function choose(first: Boolean, second: Boolean) -> String uses Console.Write
  match condition(label: "first", value: first) with
    case true -> return "first selected"
    case false ->
      match condition(label: "second", value: second) with
        case true -> return "second selected"
        case false -> return "neither selected"
      end match
  end match
end function

function main() -> Unit uses Console.Write
  Console.writeLine(choose(first: true, second: true))
  Console.writeLine(choose(first: false, second: true))
  Console.writeLine(choose(first: false, second: false))
end function
```

```output
first
first selected
first
second
second selected
first
second
neither selected
```

## 4. 基本型とリテラル

| 型 | 値 | リテラル |
|---|---|---|
| `Integer` | 符号付き 64 ビット整数 | `42`, `-7`, `1_000_000`, `0xff`, `0o755`, `0b1010` |
| `Float` | IEEE 754 binary64 | `3.14`, `1e10`, `1.2e-3` |
| `Decimal` | 128 ビットの十進小数。金額など、正確な十進の値のためのもの | `12m`, `1.25m`, `1_000.50m` |
| `Byte` | 0 から 255 までの整数。算術演算はない | `255u8`、または `Byte.fromInteger` |
| `Integer8`, `Integer16`, `Integer32` | 符号付き 8・16・32 ビット整数 | `-128s8`, `42s16`, `0xffs32` |
| `UnsignedInteger16`, `UnsignedInteger32`, `UnsignedInteger64` | 符号なし 16・32・64 ビット整数 | `42u16`, `0xffffu32`, `18446744073709551615u64` |
| `Float32` | IEEE 754 binary32 | `1.5f32`, `1e-3f32` |
| `Character` | 一つの Unicode スカラー値 | `'a'`, `'あ'`, `'\n'` |
| `String` | Unicode スカラー値の変更できない列 | `"text"`, `"""…"""`, `r"…"` |
| `Boolean` | `true` と `false` | `true`, `false` |
| `Unit` | `()` だけ | `()` |

暗黙の変換はない。`Integer.toFloat`、`Integer.toString`、`Decimal.fromInteger`、`Integer.parse`（`Option[Integer]` を返す）などの変換の関数を使う。

算術演算を持つすべての整数型は、桁あふれと、0 による `div` や `mod` のときに実行時エラーで止まる。符号なし整数の減算で 0 より小さくなる場合も桁あふれになる。符号付き整数の最小値の `div -1` は桁あふれになるが、最小値の `mod -1` は 0 になる。`Byte` には比較、ビット演算、変換があるが、算術演算はない。`Float` と `Float32` の除算は IEEE 754 に従い、0 で割ると無限大か NaN になる。浮動小数点のリテラルは小数点の両側に数字が要る（`1.` や `.5` ではなく `1.0`）。

### 数値型の名前と接尾辞

ビット幅を含む名前が正式な名前である。このリファレンス、診断、表示するシグネチャでは、別名の `Integer`、`Float`、`Byte` を主に使う。次の表の各行の名前は同じ型を表し、名前を使い分けるための変換は要らない。これらの型と標準のモジュールは、すべて prelude にある。

| 正式な名前 | 別名 | 既定の表示 | 整数の範囲または浮動小数点の形式 |
|---|---|---|---|
| `Integer8` | — | `Integer8` | −128 から 127 |
| `Integer16` | — | `Integer16` | −32768 から 32767 |
| `Integer32` | — | `Integer32` | −2^31 から 2^31−1 |
| `Integer64` | `Integer` | `Integer` | −2^63 から 2^63−1 |
| `UnsignedInteger8` | `Byte` | `Byte` | 0 から 255。算術演算はない |
| `UnsignedInteger16` | — | `UnsignedInteger16` | 0 から 65535 |
| `UnsignedInteger32` | — | `UnsignedInteger32` | 0 から 2^32−1 |
| `UnsignedInteger64` | `UnsignedInteger` | `UnsignedInteger64` | 0 から 2^64−1 |
| `Float32` | — | `Float32` | binary32 |
| `Float64` | `Float` | `Float` | binary64 |

`Integer8`、`Integer16`、`Integer32`、`UnsignedInteger16`、`UnsignedInteger32`、`UnsignedInteger64`、`Float32` は、それぞれ異なる七つの型である。接尾辞のないリテラルの型は固定である。周囲のコードが別のビット幅を期待していても、`1` は常に `Integer`、`1.0` は常に `Float` である。二項の算術演算、等値の比較、大小の比較では、別名を展開した後の両辺の型が同じでなければならない。`Integer32` の算術演算には `1s32 + 2s32` を使い、計算で得た値には明示的な変換を使う。

整数の接尾辞は小文字の `s8`、`s16`、`s32`、`s64`、`u8`、`u16`、`u32`、`u64`、浮動小数点の接尾辞は `f32` と `f64` である。**この接尾辞の構文は暫定であり、言語の構文を見直すときに変わることがある。**通常の互換性の方針は引き続き適用される。`1s64` は `Integer`、`1.0f64` は `Float`、`255u8` は `Byte` である。整数の接尾辞は、十六進・八進・二進の表記と数字の間のアンダースコアを保つ。`0xffu8`、`0o177s8`、`0b1010u16`、`1_000s32` のように書ける。浮動小数点の接尾辞には小数点か指数が要る。`1f32` ではなく `1.0f32` と書く。十六進の `0xfff32` は、`f32` が十六進の数字からなるため、接尾辞のない整数のままである。`Decimal` の接尾辞 `m` は、ほかの接尾辞と組み合わせられない。

範囲外のリテラルは静的な誤りである。符号付きのリテラルに直接付けた負号は、範囲の検査に符号を含めるので、`-128s8` は有効である。一方、`-(128s8)` は範囲外の正のリテラルを含む。符号なしの型では、`-0u16` や `-1u8` を含めて、単項の負号を使えない。`Integer8`、`Integer16`、`Integer32`、符号なし整数の型、`Byte`、`Float32` は、定数のパターンも範囲のパターンも使えない。代わりに値を束縛し、ガードで比べる。定数の桁あふれと 0 による除算は、`const` の式では誤り、通常の式では警告になる。

`Float32` は、値を作るときと各算術演算の後に、最も近い binary32 の値へ丸める。ちょうど中間なら偶数側に丸める。演算を融合積和演算にまとめることはない。無限大、NaN、符号付きの 0、比較は `Float` に従う。NaN のペイロードのビットは、契約として保存を保証しない。`toString`、文字列補間、`Trait.Show` は、整数には十進の表記を、浮動小数点には同じビット幅で読み直したときに同じ値になる最短の十進の表記を使い、接尾辞は付けない。整数の型はすべて、等値の比較、`ordered`、マップと集合のキーに対応する。`Float32` は等値の比較と `ordered` に対応するが、キーにはできない。七つの型すべてに `Trait.Show` と `Trait.Order` の標準の実装がある。`Trait.Order` は、すべての NaN を互いに等しく、ほかの値より大きいものとして扱い、正と負の 0 を等しいものとして扱う。

### 数値の変換と標準の関数

値が変換先の範囲を外れる可能性がある変換の関数は、`Option` を返す。算術演算の桁あふれは実行を止め、`Option.None` は返さない。ビット幅のすべての組の間に直接の変換があるわけではない。途中の型として `Integer` を使い、符号なし 64 ビット整数の全範囲には `Decimal` を使う。

| モジュール | 関数 | 契約 |
|---|---|---|
| `Integer8`, `Integer16`, `Integer32`, `UnsignedInteger16`, `UnsignedInteger32` | `fromInteger`, `toInteger` | `fromInteger` は `Option[T]` を返す。`toInteger` は正確に変換し、`Integer` を返す |
| `UnsignedInteger64` | `fromInteger`, `toInteger` | 両方とも `Option` を返す。入力が負か、結果が `Integer` の最大値を超えると `None` になる |
| `UnsignedInteger64` | `fromDecimal`, `toDecimal` | 全範囲で正確に変換する。`fromDecimal` は、範囲内で小数部分が 0 の値（`1.0m` を含む）だけを受け取り、`Option` を返す |
| 符号付き 8/16/32 ビットと符号なし 16/32/64 ビットの整数のモジュール | `parse`, `toString`, `toFloat` | 十進の解析は `Option` を返し、空白、基数の接頭辞、アンダースコア、範囲外の値、符号なしの型の負の値を拒む。`toFloat` は binary64 に丸める |
| 符号付き 8/16/32 ビットと符号なし 16/32/64 ビットの整数のモジュール | `absolute`, `minimum`, `maximum`, `floorDivide`, `floorModulo` | 結果は同じビット幅である。符号付きの最小値の `absolute` は桁あふれになり、符号なしの `absolute` は元の値を返す |
| 符号付き 8/16/32 ビットと符号なし 16/32/64 ビットの整数のモジュール | `bitwiseAnd`, `bitwiseOr`, `bitwiseExclusiveOr`, `bitwiseNot`, `shiftLeft`, `shiftRight` | シフトの量は 0 からビット幅−1 までの `Integer` である。左シフトはビット幅を超えたビットを捨てる。符号付きの右シフトは符号を拡張し、符号なしの右シフトは 0 で埋める |
| `Integer8`, `Integer16`, `Integer32` | `shiftRightUnsigned` | 0 で埋める右シフト |
| `Float32` | `fromFloat`, `toFloat` | `fromFloat` は `Option` を返し、binary32 に丸め、有限の値が無限大になる場合は拒む。無限大や NaN の入力は `Some` になる。`toFloat` は有限の値を正確に広い型へ変換する |
| `Float32` | `parse`, `toString`, `truncate` | `Float` の十進の表記を直接 binary32 として解析し、有限の値だけ `Some` を返す。`truncate` は 0 の方向に丸めて `Option[Integer]` を返し、NaN、無限大、範囲外の値を拒む |
| `Float32` | `absolute`, `floor`, `ceiling`, `round`, `squareRoot`, `isNaN`, `isInfinite` | binary32 の精度で `Float` と同じように動く。`round` はちょうど中間の値を 0 から遠い側に丸める。負の数の平方根は NaN になる |

`Float32` から狭い整数への変換には、`truncate` と `fromInteger` を組み合わせる。`Float` から `UnsignedInteger64` の範囲の上半分への直接の変換はない。リテラル、`parse`、正確な `Decimal` を使う。`Decimal.fromFloat` は十進の書式化を使い、二進の整数としての正確な変換ではない。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind small <- Option.unwrapOr(o: Integer8.fromInteger(42), fallback: 0s8)
  bind maximum <- 18446744073709551615u64
  bind narrowed <- Option.unwrapOr(o: Float32.fromFloat(0.1), fallback: 0.0f32)
  bind same: Integer64 <- Integer8.toInteger(small)
  Console.writeLine("${small + 1s8} ${same} ${Integer8.fromInteger(128) = Option.None}")
  Console.writeLine("${UnsignedInteger64.toInteger(maximum) = Option.None} ${UnsignedInteger64.toDecimal(maximum)}")
  Console.writeLine("${narrowed} ${Float32.toFloat(narrowed) = 0.1}")
end function
```

```output
43 42 true
true 18446744073709551615
0.1 false
```

### 文字列

文字列のリテラルは 1 行に収める。エスケープは `\n`、`\r`、`\t`、`\\`、`\"`、`\$`、`\u{H}`（十六進で書いた Unicode スカラー値）である。文字列の中の `${expression}` は式の値を埋め込む（文字列補間）。`{` が続く `$` そのものを書くには `\$` と書く。`Unit` を除く基本型の値は直接埋め込める。ほかの型は、先に `String` に変換する。

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
  Console.writeLine(Decimal.toString(Decimal.round(x: 2.675m, places: 2, mode: RoundingMode.HalfToEven)))
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
| `|>` | パイプ: `xs |> List.map(f: action)` のように最初のパラメータを満たす | 左 |
| `or` | 論理和（短絡） | 左 |
| `and` | 論理積（短絡） | 左 |
| `=` `<>` `<` `<=` `>` `>=` | 比較 | なし（`a < b < c` は誤り） |
| `+` `-` | 加算、減算。`+` は文字列の連結にも使う | 左 |
| `*` `/` `div` `mod` | 乗算。`/` は `Float`・`Float32`・`Decimal` に、`div` と `mod` は算術演算を持つ整数型に使う | 左 |
| `-` `not` | 符号の反転、否定 | 前置 |
| `f(...)` | 呼び出し | 後置 |

`==`、`!=`、`&&`、`||`、`!`、`%` はない。`div` は 0 の方向に丸め、`mod` の符号は被除数に従う。`-7 div 2` は `-3`、`-7 mod 2` は `-1` である。負の無限大の方向に丸めるには `Integer.floorDivide` と `Integer.floorModulo` を使う。整数型に `/` はない。小数部分を持つ結果には、浮動小数点か十進小数への変換を使う。

`=` と `<>` は、*等値の型*の値を比べる。等値の型は、関数の型も中身を見せない型（`IOError`、`NetworkError`、`Reference`、`Lazy`、`Task`、リソース、外部の型、`Regex.Pattern` など）も含まない型である。リスト、マップ、集合、オプション、結果、レコード、データ型は、中身で比べる。`<`、`<=`、`>`、`>=` は、すべての数値型と `Character`、`String` にだけ使える。`Float` と `Float32` の比較は IEEE 754 に従う。NaN は何とも、自分自身とも等しくないので、検出にはそれぞれの `isNaN` の関数を使う。

演算の対象は左から右へ評価する。

## 6. 関数とラムダ

関数は、引数の型と、`->` の後に戻り値の型を宣言する。`uses` のない関数は純粋である。

```text
function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2
  ...
end function
```

呼び出しはカリー化されない。引数をすべて渡す。二つ以上のパラメータを持つ通常の関数では、各引数にパラメータ名を付けて `between(low: 2, value: 3, high: 4)` と書く。一引数の関数は名前を付けても省いても呼べる。引数がゼロなら `f()` と書く。名前付き引数と位置引数を混在させない。名前付き引数は任意の順に書けるが、各パラメータをちょうど一度ずつ指定する。ラベルは局所変数ではなくパラメータの名前である。`value: input` は局所の値 `input` をパラメータ `value` へ渡す。ラベルの記述順が宣言順と違っていても、呼ぶ関数の式を最初に評価し、次に引数の式をソースの記述順に一度ずつ評価する。

この呼び出しの規則は、宣言した関数、組み込みの関数、関数値、ラムダ、型クラスのメソッド、エフェクトの操作、外部の関数に適用する。直接のデータ構築とデータのパターンは、`Pair(1, "one")` のような位置フィールドを使う。レコードは名前付きのフィールドを使う（[データ型とレコード](#7-データ型レコードパターンマッチ)を参照）。属性、ハンドラの節の束縛、`resume(value)` には、それぞれ専用の構文がある。

*ラムダ*は関数値であり、パラメータと戻り値の型を省いてよい。関数と同じく `return` で値を返す。`Unit` を返すラムダは、代わりに文で終えてもよい。

本体が一文なら短いラムダを推奨する。明示の終端も有効であり、フォーマッタは選んだ形を保つ。見出しと本体の全体が同じ物理行に収まる一文のラムダは、`lambda(x) return x + 1` のように `end lambda` を省ける。本体を見出しの最後の行に始める場合は、その同じ物理行の `end lambda` だけがそのラムダを閉じる。後の行の `end lambda` は外側のラムダを閉じることがあり、空行を挟んでもこの対応は変わらない。複数行のラムダは、見出しの次の行に本体を始め、`end lambda` で閉じる。

短いラムダも、`Unit` 以外の値を返すには `return` を要する。`lambda(x) return x + 1 |> increment` のパイプは本体に属する。ラムダ自体を呼ぶには `(lambda(x) return x + 1)(3)` と書く。直接に入れ子になった二つのラムダのどちらかで終端を省く場合は、内側のラムダ全体を括弧で囲み、`lambda(x) return (lambda(y) return x + y)` と書く。呼び出しの引数と束縛文は、それぞれ独立した区切りとなる。短い本体に二文目を加える前に、本体を見出しの次の行へ移し、`end lambda` を加える。

### 関数の契約とコールバック

関数型は、`function(value: Integer) -> Integer` や `function(acc: Integer, value: Integer) -> Integer` のように、各パラメータに名前を付けて書く。型の中の名前は局所の値を束縛しない。パラメータ名とその順序は、型とエフェクトとともに契約の一部である。一引数のコールバックでも、各位置で名前が一致しなければならない。検査器は期待する型に合わせてラムダを改名しない。呼び出しでラベルを別の順に書いても、契約の順序は変わらない。

`List.map` が期待する型は `function(value: T) -> U` なので、`List.map(xs: xs, f: lambda(value) return value * 2)` と書く。主なコールバックの契約と宣言全体については、[標準ライブラリ](#19-標準ライブラリ)を参照する。パラメータが未使用でも期待する名前を保ち、`_unused` などに置き換えない。意味を表す局所名を使いたい場合は、複数行の本体に `bind` を加える。

異なる契約を持つ関数を渡すには、必要な名前のラムダで包む。例えば、`Integer.toString` は `n` を取るので、`List.map` へは `lambda(value) return Integer.toString(value)` を渡す。構成子の関数値とレコードの取り出す関数も、パラメータ名を含む契約がある。[データ型とレコード](#7-データ型レコードパターンマッチ)で説明する。

型注釈のない関数パラメータを呼ぶとき、そのラベルから契約順を決めることはしない。同じ関数の本体内の制約で契約が確定しなければ、`g: function(a: Integer, b: Integer) -> Integer` などの型注釈を加える。注釈がなければ検査器は `E0455` を報告する。未使用のラムダや、一つの位置引数を渡す呼び出しでも同じである。検査済みの関数で不足している契約を、呼び出し元から後で補うことはできない。

### 穴とパイプ

呼び出しの直接の引数の `_` は、不足する引数を取る関数を作る。`Integer.maximum(a: _, b: 0)` の型は `function(a: Integer) -> Integer` である。各穴は対応するパラメータ名を引き継ぎ、複数の穴は記述順に並ぶ。`between(high: _, value: 3, low: _)` は `low, high` ではなく `high, low` を取る。位置構成子の直接の穴は、元の位置の名前を引き継ぐ。`Pair(_, "one")` は `arg1` を取る。呼ぶ関数の式と固定した引数の式を評価するのは、生成した関数を作るときではなく、その関数を呼ぶときである。これらの式の中の `return` と `try` は生成した関数に作用する。`resume` はこの境界を越えられない。

直接の穴がない場合、パイプの右辺の呼び出しは、左の値を宣言上の最初のパラメータとして受け取る。`xs |> List.map(f: action)` がその例である。関数のパラメータが二つ以上なら、残りの明示引数すべてにラベルを付ける。最初のパラメータを明示的に再び指定すると重複となる。パイプが別の空いたパラメータを探すことはない。評価順は、左辺を一度、次に右辺の呼ぶ関数の式、次に明示引数をソースの記述順である。

`xs |> List.map(xs: _, f: action)` のように直接の穴がある場合は、パイプは生成した関数を一引数で呼ぶ。括弧で囲んだ右辺も、関数値として一引数を受け取る。二つの穴には二つの引数が必要であり、パイプがその関数を自動で再び部分適用することはない。

### 型とエフェクトのパラメータ

型パラメータは、名前の後の角括弧に書く。`function first[T](xs: List[T]) -> Option[T]` のように書く。型引数も角括弧を使う。`List[Integer]`、`Map[String, Integer]` のように書く。*エフェクト変数*は、エフェクトの集合を表す型パラメータである。エフェクト変数を使うと、関数は任意のエフェクトを持つ関数を引数に取り、そのエフェクトをそのまま自分のエフェクトにできる。

```benitoite
import Benitoite.Unofficial.IO.Console

function between(low: Integer, value: Integer, high: Integer) -> Boolean
  return low <= value and value <= high
end function

function twice[T, effect E](x: T, f: function(value: T) -> T uses E) -> T uses E
  return f(f(x))
end function

function main() -> Unit uses Console.Write
  bind text <- [1, 2, 3, 4, 5]
    |> List.filter(p: between(low: 2, value: _, high: 4))
    |> List.map(f: lambda(value) return Integer.toString(value))
    |> String.join(separator: ",")
  Console.writeLine(text)
  Console.writeLine(Integer.toString(twice(x: 5, f: lambda(value) return value * 3)))
  bind shout <- lambda(value: String) -> String
    Console.writeLine("shouting ${value}")
    return String.toUppercase(value)
  end lambda
  Console.writeLine(twice(x: "hi", f: shout))
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

フィールドを持つ構成子は、関数値としても使える。そのパラメータはフィールド順に `arg1`、`arg2`、…となる。`bind make <- Pair` の後は、`make(arg1: 1, arg2: "one")` と呼ぶ。`Pair(1, "one")` のような直接の構成子の呼び出しは位置フィールドを使い、そこでラベルを付けると `E0456` になる。

### レコード

レコードは名前の付いたフィールドを持つ。名前付きの引数で作り、フィールドを `Type.field(value)` で読み、一部のフィールドを変えた写しを `Type(..value, field: newValue)` で作る。`value.field` は正しくない。

`Item.price` などのレコードの取り出す関数のパラメータ名は `value` である。レコード構成子を関数値として使うときは、宣言順のフィールド名を取る。これらの名前も、[関数の契約とコールバック](#関数の契約とコールバック)で説明した、期待するコールバックの契約と一致しなければならない。

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

包括的な最後の分岐には、`case other ->` や `case otherCode ->` のような通常の名前を推奨する。これらの名前は照合した値を束縛し、予約語ではない。外側の局所名や見えている定数と衝突しない名前を選び、ガードのない包括的な分岐の後に到達しない分岐を置かない。`case _ ->` も有効であり、警告は出ない。この推奨は、構成子パターン内の `_`、捨てる束縛、部分適用のプレースホルダには適用しない。

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
    case otherScore -> "C"
  end match
end function

function main() -> Unit uses Console.Write
  List.forEach(xs: [Shape.Circle(1.0), Shape.Rectangle(2.0, 3.5)], f: lambda(value)
    Console.writeLine(Float.toString(area(value)))
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

### 拡張可能な型

引数のない属性 `@extensible` を `data` か `record` の宣言の前に置く。`public` または `public(package)` があれば、その前に置く。非公開の宣言にも使え、`@deprecated` と併用できる。`@extensible()` も同じ属性として受理し、フォーマッタは括弧を保つ。引数があれば `E0817`（文字列でない引数は `E0220`）、重複は `E0803`、ほかの種類の宣言への指定は `E0802` を報告する。個々の構成子の前には属性を置けない（`E0201`）。

定義したパッケージの中では、宣言済みの構成子をすべて覆うパターンを網羅的と判定できる。外では、ソースに書く `match` に、ガードのない変数か `_` のパターンで将来の形も覆う分岐を要する。`Other` という名前の構成子も既知の構成子であり、将来の形を覆わない。ガード付きの分岐は網羅性に数えない。この規則は、`Result`、`Option`、リスト、レコードのフィールドの中や、型の別名を通した位置にも適用する。全既知構成子の後でも将来の形の分岐は有効である。ガードのない `_` の後の分岐は、引き続き到達不能である。

パッケージの境界は `public(package)` と同じである。起点のスクリプトと根のモジュールは一つのパッケージ、標準ライブラリと prelude は別の一つのパッケージを成し、各依存の内部モジュールはその依存に属する。同じパッケージの別のモジュールへ型を取り込んでも、外部からの使用にはならない。

標準ライブラリは、四つの失敗型 `IOErrorKind`、`NetworkErrorKind`、`Json.ParseError`、`Csv.ParseError` を拡張可能と指定する。`Result` と `Option` 自体は閉じた型のままである。中身を変数で束縛する `Result.Ok(value)` と `Result.Error(error)` で、両方の場合を覆える。`String` の失敗値には通常の文字列パターンの規則を保つ。不透明な `IOError` と `NetworkError` には、照合できる構成子がない。

拡張可能なレコードでは、`ParseError(message: text, ..)` は既知のレコードの形だけを覆う。`..` は現在のフィールドの省略である。パッケージの外では、`match` に変数か `_` の分岐を加える。分解する `bind` や `shadow` は常に一致しなければならないので、そのレコードパターンだけを使うと `E0607` を報告する。取り出す関数か、将来の形の分岐を持つ `match` を使う。構築・更新・フィールドの取り出しは、宣言したフィールドの契約を保つ。この属性は、レコードのフィールドを追加・変更したときの互換性を保証しない。

次の例は、既知の JSON の失敗の形を処理し、将来の形の分岐を残す。既存の API でレコードを構築・更新する例も含む。

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.Json

function describe(result: Result[Json.Value, Json.ParseError]) -> String
  return match result with
    case Result.Ok(_) -> "parsed"
    case Result.Error(Json.ParseError(message: text, ..)) -> text
    case Result.Error(otherError) -> "another JSON error"
  end match
end function

function main() -> Unit uses Console.Write
  bind original <- Json.ParseError(line: 1, column: 2, message: "expected a value")
  bind revised <- Json.ParseError(..original, message: "invalid input")
  Console.writeLine(describe(Result.Error(original)))
  Console.writeLine(Json.ParseError.message(revised))
end function
```

```output
expected a value
invalid input
```

将来の形が残ると、`match` では `E0601`、束縛のパターンでは `E0607` を報告し、型の宣言を副位置に示す。反例は `<future constructor of TypeName>`、レコードなら `<future shape of TypeName>` と表示する。これらは診断の説明であり、ソースに書ける構成子名ではない。`E0601` はガードのない変数か `_` を提案する。`E0607` は、束縛をガードのない `case _ ->` の分岐を持つ `match` に書き直すよう提案する。

閉じた型に `@extensible` を加えると、以前は受理した外部の照合や分解の束縛を拒否することがある。拡張可能なデータ型への構成子の追加は、外部のソースのパターンの網羅性を保つ。ただし、以前 `Other` と分類した値に新しい構成子を割り当てる場合など、同じ結果を保証するものではない。構成子の削除・改名・フィールドの変更は、この保証の範囲外である。属性を取り除くと、構成子の集合を閉じたものとする契約になり、将来の形の分岐が到達不能になることがある。この属性によって、呼び出し側が構成子を追加できるようにはならない。実行時の構成子のタグ、ABI、等価性、キーの制約は従来の規則を保つ。[WIT の構造の照合](#wasm-を通じた外部の関数と型)は別の契約であり、引き続き厳密な一致を要する。

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
  return Option.unwrapOr(o: Map.get(m: statusNames, k: id), fallback: "unknown")
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

`try e` と `try e or return` は `e` を一度評価する。`Result.Error`（または `Option.None`）なら、最も内側の関数かラムダはその失敗をすぐに返す。それ以外なら、式は中身の値を取り出す。これらの失敗を返す形では、囲む関数の戻り値の型を、同じエラー型の `Result`、または対応する `Option` にする必要がある。裸の `try e` は、この失敗を返す意味に固定する。戻り値の型や書く位置によって終了へ切り替わることはなく、Show の制約や終了のエフェクトを加えない。`try` はパイプを含めた右側の式全体に、同じ深さの処置まで作用する。エラーの型が異なるときは、先に `Result.mapError` で変換する。例えば、関数が `Result[T, String]` を返し、`result` が `IOError` を含む場合は、`Result.mapError(r: result, f: lambda(error) return IOError.message(error))` と書く。コールバックのパラメータ名は `error` である。

失敗を返すパイプでは、`try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return` と書く。この `try` は、パイプ全体の結果を取り出す。ラムダ内で失敗を返す `try` は、そのラムダから戻る。`_` の穴を持つ呼び出しの、呼ぶ関数の式や固定した引数の中では、生成した関数から戻り、周囲の関数からは戻らない。[穴とパイプ](#穴とパイプ)を参照する。

新しいコードでは処置を明示する。再利用する関数・ライブラリ・コールバックには `or return`、失敗を報告して実行を終える入口には `or die` を使う。`Result.Error` を返す契約の入口や、`Process.Exit` を使えない入口でも `or return` を使える。次の例は、`main` から失敗を返す場合である。

```benitoite
import Benitoite.Unofficial.IO.Console

function parsePort(text: String) -> Result[Integer, String]
  return match Integer.parse(text) with
    case Option.Some(n) if n > 0 and n < 65536 -> Result.Ok(n)
    case otherPort -> Result.Error("not a port: ${text}")
  end match
end function

function main() -> Result[Unit, String] uses Console.Write
  bind port <- try parsePort("8080") or return
  Console.writeLine("port ${port}")
  bind other <- try parsePort("http") or return
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

値にならない失敗もある。整数の桁あふれ、0 による除算、大きすぎて作れない値、呼び出しのスタックの使い果たしは、実行時エラーでプログラムを*止め*、終了状態は 1 になる。`match` はこれらを捕えられない。報告は、その場所と、そこに至った呼び出しを示す。

`try e or die` と `try e or die(message)` は、標準の `Result[T, E]` か `Option[T]` を受け取り、成功時は `T` を取り出す。囲む関数の戻り値の型は制限しない。`Process.Exit` を加えるので、`uses` に名前を書くために `Benitoite.Unofficial.IO.Process` を取り込む。このモジュールは `as` で改名できない（E0339）ため、`uses Process.Exit` と書く。コンパイラは標準の Show と終了の参照を内部で接続するが、名前を利用者のスコープに取り込むことはない。ホストによる失敗の報告に `Console.Write` のエフェクトは不要である。

| 処置 | 囲む関数の戻り値の型 | 表示の要件 | 追加のエフェクト |
|---|---|---|---|
| 裸の try または `or return` | 入力に対応する `Result[U, E]` か `Option[U]` | なし | なし |
| `or die` または `or die(message)` | 任意 | Result のエラー型には `Trait.Show`。Option には不要 | `Process.Exit` |

入力は一度だけ評価する。成功時は説明も Show も評価しない。失敗時は、任意の純粋な `String` の説明を一度、エラーの Show を一度、この順に評価し、標準の終了操作を状態 1 で呼ぶ。説明の中でエラーに名前を暗黙に束縛することはない。説明には直接の `return`、`try`、外側の `resume` を書けない。そこに書くラムダは、独自の return の境界を持つ。`IOError`、`NetworkError`、`Json.ParseError`、`Csv.ParseError` は、`message` の文字列をそのまま返す Show を既に実装している。ほかのエラー型では Show を実装するか、`Result.mapError` で Show のある型へ変換する。失敗を返す形には Show は不要である。

String の原因には、Show が付ける引用符とエスケープを保つ。Option.None の原因は、固定の `expected a value, got Option.None` である。説明は通常のテキストとして表示し、空の説明と説明なしを区別する。どちらも原因を消さない。説明か Show が実行時エラーや資源の不足で止まると、die の報告の代わりにその停止を採る。純粋性と静的検査は、停止性、意図した結果、外部操作の成功を保証しない。

既定の終了は、子タスクから呼んだ場合も、実行全体を終える。残るタスクを取り消し、リソースを解放し、バッファにある出力を転送する。その後、CLI は `error: explicit failure exit`、ソースの位置、任意の `message: ...`、`cause: ...` を標準エラー出力へ一度報告する。解放と最後の出力の失敗は補足の報告として後に続き、状態 1 を保つ。`--diagnostics=json` では、die の報告は `kind: "die"`、`code: null` と、同じ位置と notes を持つ。タスクを取り消しても、既に始めた外部の作業を元に戻すことはできない。競合する終了、中断、処理系の不具合は通常の停止規則に従い、採用した die の情報だけを報告する。

言語のハンドラは、既存の `Process.Exit` の操作を置き換えられる。受け取るのは通常の終了コードだけであり、処理した呼び出しの報告は破棄し、後の終了には付けない。`benitoite test` では、die はそのテストを失敗にし、実行器は次のテストへ続く。テキストと JSON の両方で原因・説明・位置を保ち、捕えた出力へ同じ報告を重ねない。任意の終了状態には `Process.exit(code)` を使う。

入力は、同じ深さの `or return` または `or die` までのパイプを含む。通常の真偽値の `or` は演算子のままである。明示形の try に演算子や呼び出しを続けるときは、`(try parsePort(text) or die) + 1` のように括弧で囲む。`or return` は値を取らない。その `return` の直後の物理改行は文を終える。説明の `(` は `die` と同じ物理行で始める。括弧の外では、`die` またはその説明の後の改行は文を終える。短いラムダは、処置と説明の全体を一つの物理行に含める必要がある。フォーマッタは裸の形と明示形を保つ。

```files
name: input.txt
ready
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function load(path: String) -> Result[String, IOError] uses File.Read
  return Result.Ok(try File.readText(path) or return)
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try load("input.txt") or die("could not read input.txt")
  Console.write(text)
end function
```

```output
ready
```

`load` は元の IOError を呼び出し元へそのまま返す。読み込みに失敗すると、`main` は標準の Show の実装を使うので、表示だけのための変換は不要である。Process.Exit の追加は関数の契約を変えるため、処置・戻り値の型・エフェクトを一緒に確認する。

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
| `Process.Exit` | 選んだ終了コードで実行を終える。`or die` は原因と任意の説明を標準エラー出力に報告し、終了状態 1 で終える |
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

エフェクトは関数の値の型の一部である。`function(text: String) -> Unit uses Console.Write` のように書く。

## 11. エフェクトハンドラ

エフェクトは自分で宣言できる。`effect` の宣言はその操作を挙げ、操作は関数と同じように呼ぶ。`handle body with case operation(arguments) -> clause end handle` は `body` を実行し、本体が挙げた操作のどれかを呼ぶたびに、代わりに節を実行する。節の中の `resume(value)` は、`value` を操作の結果として本体を続ける。`resume` を呼ばない節は、自分の値で `handle` を終える。`resume` は節の中に直接書く。ラムダ、`lazy` の本体、`match` のガード、プレースホルダ `_` を持つ呼び出しの引数の中には書けない（そこに書いた `handle` は、自分の節で `resume` できる）。

```benitoite
import Benitoite.Unofficial.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function sumPrices(items: List[Integer]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(xs: items, initial: 0, f: lambda(acc, value) return acc + value)
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

`File.readText` や `Process.run` などの組み込みのエフェクトの操作も、同じように処理できる。テストはこの方法で外の世界を置き換える（[16. テスト](#16-テスト)）。エフェクトの操作の一部だけを処理するハンドラは、そのエフェクトを型から取り除かない。エフェクトに `State` を含む関数（`Reference`、`TaskGroup`、`Task.await`、`close…` の関数）は処理できない。

`uses` と `case` では、同じモジュールで宣言したエフェクトや操作はモジュールの名前を付けずに書き（`Log`、`write`）、別のモジュールのものは付けて書く（`Logging.Log`、`Logging.write`、`Console.writeLine`）。

## 12. モジュール

各ファイルは一つのモジュールである。モジュールの名前は、根のディレクトリからのパスの `/` を `.` に置き換え、`.bnt` を除いたものである。ファイル `Lib/Text.bnt` はモジュール `Lib.Text` である。`import Lib.Text` はそれを `Text` として使えるようにし、`import Lib.Text as T` は `T` として使えるようにする。`public` を付けた宣言は、それを取り込むどのモジュールからも使える。`public(package)` を付けた宣言は、同じパッケージのモジュールからだけ使える。依存のパッケージは、その根の下のモジュールからなる。起点のファイルと起点の根の下のモジュールも、一つのパッケージとして数える。何も付けない宣言は、そのモジュールの中でだけ使える。取り込みは循環してはならない。

```files
name: Lib/Text.bnt
/// Turns "Hello World" into "hello-world".
public function slug(text: String) -> String
  return String.toLowercase(String.replace(s: String.trim(text), old: " ", new: "-"))
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

可視性には、非公開 < `public(package)` < `public` の三段階がある。宣言の契約で使う型、型クラス、エフェクトは、その宣言以上の可視性を持たなければならない。入れ子の関数の型、制約、`uses` もこれに含む。`public` な関数は、別のモジュールの `public(package)` な型も公開できない。構成子、レコードのフィールド、型クラスのメソッド、エフェクトの操作は、それらを囲む宣言の可視性を引き継ぐ。`public(package)` は定数と型の別名にも付けられる。`public` も `public(package)` も、`implement` とその関数には付けられない。

括弧の中には `package` だけを書ける（ほかの語は `E0253`）。`(` の前の空白は受け付けるが、`fmt` が取り除く。`public` と `(` の間の改行は受け付ける。`public(package)` の後の改行は、後に続く宣言から切り離すので誤りになる。`package` は引き続き識別子として使える。`benitoite package` のエフェクトの報告は、`public` な契約だけを数える。

### 標準のモジュールと非公式のモジュール

標準ライブラリのモジュールの名前は `Benitoite.<Name>` である。中核のモジュール（`Integer`、`String`、`List`、`Map`、`Option`、`Result` など）の大半は *prelude* にあり、`import` なしで使える。

この版では、IO とネットワークのモジュール、およびテキストとデータのモジュールは*非公式*である。そのインターフェースはまだ変わることがあるので、`Benitoite.Unofficial` の下で取り込む。`import Benitoite.Unofficial.IO.Console` と書き、モジュールを `Console` として参照する。この版では `import Benitoite.IO.Console` は誤りである。後のマイナー版で非公式のモジュールが標準になると、その取り込みの名前は `Benitoite.<Name>` に変わり、スクリプトは取り込みを変えなければならない。

prelude の外のモジュールは、`uses` にだけ現れるときも、すべて取り込まなければならない。一覧は[19. 標準ライブラリ](#19-標準ライブラリ)を参照する。

組み込みのエフェクトを宣言するモジュール（`IO.Console`、`IO.File`、`IO.Process`、`IO.Clock`、`IO.Random`、`Network.Http`、`IO`、`Assert`）は、`as` で名前を変えられない。名前を変えると誤り `E0339` になり、新しい名前が元の名前と同じときも誤りになる。これにより、`uses` の中のエフェクトの名前が正しく保たれる。`uses Console.Write` は、常にコンソールへの書き込みを意味する。自分で取り込んだモジュールがこれらのモジュールと同じ名前を持つときは、自分のモジュールの名前を `as` で変える。

局所の依存からモジュールを取り込む方法は、[実験的な機能: パッケージと外部の関数](#21-実験的な機能-パッケージと外部の関数)を参照する。

## 13. 型クラス

*型クラス*（`trait`）は、複数の型が実装する関数を宣言する。`implement` は一つの型についての実装を与える。型パラメータは `[T: Show]` で制約でき、複数の制約は `&` でつなぐ。組み込みの制約 `equality`（値を `=` で比べられる）と `key`（値を `Map` のキーと `Set` の要素にできる）も、同じ場所で使える。

メソッドはクラスの名前を通して呼ぶ。`Describe.describe(x)` のように書く。二つ以上のパラメータを持つメソッドでは、名前付き引数が必須である。

各実装は、入れ子の関数型の名前も含め、クラスが宣言したパラメータ名と順序を使わなければならず、不一致は `E0454` になる。標準のメソッドにも同じ規則を適用する。`Functor.map` のコールバックは `value`、`Foldable.fold` のコールバックは `acc, value` を取る。

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
  function describe(x: List[T]) -> String
    return "[" + String.join(xs: List.map(xs: x, f: lambda(value) return Describe.describe(value)), separator: ", ") + "]"
  end function
end implement

function describeIfSame[T: Describe & equality](a: T, b: T) -> String
  return match a = b with
    case true -> Describe.describe(a)
    case false -> "different"
  end match
end function

function main() -> Unit uses Console.Write
  Console.writeLine(Describe.describe([1, 2]))
  Console.writeLine(describeIfSame(a: 3, b: 3))
end function
```

```output
[the number 1, the number 2]
the number 3
```

実装はプログラムの全体に適用される。実装は、クラスのモジュールか型のモジュールに置かなければならず、二つの実装が重なってはならない。`Show`、`Order`、`Monoid`、`Functor`、`Monad` などの標準のクラスは、モジュール `Benitoite.Trait` にある。

`IOError`、`NetworkError`、`Json.ParseError`、`Csv.ParseError` は、標準の `Trait.Show` の実装を持つ。それぞれの型の `message` の文字列をそのまま返し、引用符、行番号、列番号、ほかの位置の情報を加えない。IOError と NetworkError の実装は `Benitoite.Trait`、ParseError の実装は Json と Csv にある。明示的に `Trait.Show.show` を呼ぶには、`import Benitoite.Trait` を要する。`or die` は Show の参照を内部で接続する。通常の `Show[String]` は、引き続き引用符とエスケープを加える。

## 14. 明示遅延

`lazy ... end lazy` は、本体を評価せずに `Lazy[T]` の型の値を作る。`Lazy.force(value)` は、最初に本体を評価し、その後は保存した結果を返す。本体は純粋でなければならない。

```benitoite
import Benitoite.Unofficial.IO.Console

function choose(useFirst: Boolean, first: Lazy[Integer], second: Lazy[Integer]) -> Integer
  return match useFirst with
    case true -> Lazy.force(first)
    case false -> Lazy.force(second)
  end match
end function

function main() -> Unit uses Console.Write
  bind result <- choose(useFirst: true, first: lazy 42 end lazy, second: lazy 100 div String.characterCount("") end lazy)
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

タスクは、一つのプログラムの中で並行に動く。`TaskGroup.open()` は集まりをリソースとして開く。`TaskGroup.spawn(group: group, action: lambda() ...)` はその中でタスクを起動し、`Task.await(task)` はその結果を待つ。`end with` で集まりを解放すると、そのすべてのタスクを待つ。`Task.all` は関数のリストをタスクとして実行し、その結果を順に返す。`Task.race` は最初の結果を返し、ほかのタスクを取り消す。`Task.withTimeout(milliseconds: milliseconds, action: action)` は、時間が経つ前にタスクが終われば、その結果を持つ `Option.Some` を返し、そうでなければタスクを取り消して `Option.None` を返す。期限は `benitoite` が次にタスクを切り替えるときに確かめるので、期限の直前に終わったタスクでも `Option.None` になることがある。ファイルの読み込み、HTTP の要求、`Clock.sleep` など、待つ操作の間は、ほかのタスクが動ける。

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write, State
  bind counter <- Reference.new(0)
  bind squares <- with group = TaskGroup.open() do
    bind tasks <- List.map(xs: [1, 2, 3], f: lambda(value)
      return TaskGroup.spawn(group: group, action: lambda()
        Reference.set(reference: counter, value: Reference.get(counter) + 1)
        return value * value
      end lambda)
    end lambda)
    List.map(xs: tasks, f: lambda(value) return Task.await(value))
  end with
  Console.writeLine("${String.join(xs: List.map(xs: squares, f: lambda(value) return Integer.toString(value)), separator: " ")} after ${Reference.get(counter)} tasks")
  Console.writeLine(String.join(xs: List.map(xs: Task.all([lambda() return "a", lambda() return "b"]), f: lambda(value) return value), separator: ""))
end function
```

```output
1 4 9 after 3 tasks
ab
```

タスクが実行時エラーで止まると、プログラムが止まる。プログラムが中断されると、すべてのタスクを取り消し、リソースを解放する。

## 16. テスト

テストは、属性 `@test("description")` を付け、引数がなく、戻り値の型が `Unit` か `Result[Unit, String]` の関数である。値は `Assert.equal(actual: actual, expected: expected)` と `Assert.isTrue(condition: condition, message: message)` で確かめる。これらはエフェクト `Assert.Check` を要する。確かめが失敗すると、そのテストは止まる。`Result.Error(message)` を返しても失敗する。各テストは単独で動くので、一つのテストの失敗や実行時エラーはほかのテストを止めない。

```benitoite test
import Benitoite.Unofficial.IO.File

function countWords(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(List.length(List.filter(xs: String.split(s: text, separator: " "), p: lambda(value) return value <> "")))
end function

@test("countWords counts words separated by spaces")
function countWordsCounts() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    countWords("notes.txt")
  with
    case File.readText(path) ->
      Assert.equal(actual: path, expected: "notes.txt")
      resume(Result.Ok("one two  three"))
  end handle
  Assert.equal(actual: result, expected: Result.Ok(3))
end function
```

ハンドラが `File.readText` を置き換えるので、テストはファイルを読まない。それでもテストは `File.Read` を挙げる。ハンドラが処理するのは `File.Read` の操作の一つである `File.readText` だけであり、エフェクトは、その操作をすべて処理したときにだけ取り除かれるからである。

テストは `benitoite test` で実行する。通るテストを一つと、`Assert.equal(actual: double(2), expected: 5)` を確かめるテストを一つ含むファイル `t.bnt` では、報告は次のようになる。

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

失敗した `Assert.equal` と `Assert.notEqual` の確かめの報告では、`left` と `right` はそれぞれ、末尾の `…`（U+2026）を含めて最大 4 KiB（4,096 バイト）である。それより長い表示は、4,093 バイト以内の最後の文字の境界で切り、`…` で終える。残りの値は辿らない。切る位置は、`\u{202e}` のようなエスケープの途中になることがある。テキストの報告と JSON Lines の報告は、同じ表示の文字列を使う。

型パラメータを持つ補助の関数の本体に直接書いた確かめは、直接の呼び出し元の型引数から構成子の名前を復元する。具体的な型を持つ呼び出し元からの末尾呼び出しも、これに含む。復元は末尾呼び出しの後で止まる。同じ関数の外側の呼び出しがまだ実行中であっても止まる。ラムダの本体、ハンドラの本体と節の中の確かめは、どの呼び出しがそれらを作ったかを推し量らず、それを囲む関数がプログラムの中で使われる型を使う。実装のメソッドの中の確かめは、呼び出し元から型を復元しない。

型パラメータを持つ補助の関数が別の補助の関数を末尾呼び出しで呼ぶと、その呼び出しからは呼び出し元の型引数を得られなくなる。この場合、または型パラメータを持つ関数を値として渡した場合、報告が型を使うのは、その関数のすべての使用での型を決められ、かつ比べる二つの値の形が一つの型を特定するときだけである。再帰する型パラメータを持つ補助の関数でも、型が不明のまま残ることがある。

型が不明のまま残る位置では、構成子は `<constructor #n of an unknown type>` と表示する。`n` は、型の宣言の中での構成子の位置（0 から数える）である。比べる型が具体的な確かめは、構成子を名前で表示する。型のうち分かっている部分（`Option[T]` の `Option` など）は、`T` を復元できないときも名前を保つ。

検査の誤りがあるファイルは実行しない。その診断は標準エラー出力に出て、ほかのファイルのテストは実行する。`benitoite check` は `main` のないファイルに誤りを報告するので、テストのファイルには `check` ではなく `test` を使う。

`--diagnostics=json` のとき、`test` は標準出力に 1 行に一つずつ JSON のオブジェクトを書く。テストごとに `"kind": "test"` のオブジェクトを一つ書き、その欄は `file`、`name`、`function`、`location`、`outcome`（`"passed"` か `"failed"`）、`failure`、`stdout`、`stderr` である。最後に、`"kind": "testSummary"` と、数 `passed`、`failed`、`filesNotRun`、および `interrupted` を持つオブジェクトを一つ書く。`failure` は `reason` と `message` を持つ。理由は、`"assert"`（確かめの失敗。`primary`、`trace`、および `Assert.equal` と `Assert.notEqual` では値 `left` と `right` を持つ）、`"error"`（テストが `Result.Error` を返した）、`"runtime"`（実行時エラー。実行時エラーの報告の欄を持つ）、`"exit"`（テストが `Process.exit` を呼んだ。`exitCode` を持つ）のどれかである。理由が `"assert"`、`"runtime"`、`"exit"` の失敗は、`notes` も持つ。`notes` は文字列の配列であり、止まる途中のリソースの解放の失敗を含む。

`test` の終了状態は、すべてのテストが通れば 0、テストが失敗すれば 1、検査の誤り、読めないファイル、使い方の誤りでは 2、処理系の不具合では 3、中断されたときは 130 である。複数が当てはまるときは、130、3、2、1 の順で最初のものを使う。

## 17. 整形

`benitoite fmt` は、ファイルを標準の配置に書き換える。変えるのは空白（行の中の空白、字下げ、空行、行末の空白）だけである。改行とコメントを保ち、字句を加えも除きもせず、設定を持たない。`fmt` は構文だけを検査するので、型の誤りがあるファイルも整形できる。字句の誤りか構文の誤り（コード `E01nn` と `E02nn`）があるファイルは変えずに残し、その診断を報告する。ほかのファイルは整形する。ファイルを読む間に見つかるほかの誤り（誤った属性など）は、整形を止めない。

`fmt --check` は何も書き換えず、変わるはずのファイルを標準エラー出力に挙げる。`fmt` は標準出力に何も書かない。ファイルは新しい中身を書き終えた後にだけ置き換えるので、中断された `fmt` が壊れたファイルを残すことはない。新しい中身は、まず同じディレクトリの一時ファイルに書く。一時ファイルは所有者だけが読める。

`fmt` は、所有者に書き込みの許可がないファイル（モード `0444` など）、ハードリンクが二つ以上あるファイル、ほかの利用者が所有するファイルを置き換えない。理由を添えて `E0125` を報告し、ファイルを変えずに残す。そうしたファイルを整形するには、所有者が書けるようにするか、ほかのハードリンクを取り除くか、所有者として `fmt` を実行する。`fmt --check` は、これらのファイルもふつうどおり確かめる。`fmt` は通常のファイルだけを読む。

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

### 呼び出し、関数の契約、ラムダ

| コード | 意味と修正 |
|---|---|
| `E0254` | `end lambda` を省いたラムダが物理行をまたいでいる。複数行の本体は見出しの次の行に始め、`end lambda` を加える。 |
| `E0256` | 直接に入れ子になったラムダのどちらかで `end lambda` を省く場合は、内側のラムダを括弧で囲む。 |
| `E0257` | 関数型のパラメータに名前がない。期待する契約の名前を使い、各パラメータを `name: Type` と書く。 |
| `E0449` | 二つ以上のパラメータを持つ関数には名前付き引数が必要である。式の順序を保って、宣言された名前を使う。 |
| `E0450` | 名前付き引数と位置引数が混在している。一つの呼び出しで形式を揃える。 |
| `E0451` | ラベルがパラメータの名前ではない。宣言順に示された、使える名前を読む。 |
| `E0452` | パラメータが複数回指定されている。パイプが暗黙に渡す最初の引数も含む。一度だけ指定する。 |
| `E0453` | 名前付き引数で必須のパラメータが抜けている。診断に挙げた不足名を指定する。 |
| `E0454` | 関数のパラメータ名か順序が期待する契約と異なる。実装のメソッドも含む。契約に合わせるか、必要な名前のラムダで包む。 |
| `E0455` | 関数のパラメータ名と順序を決められない。名前付きの関数型の注釈を加える。呼び出しのラベル順からは契約を決めない。 |
| `E0456` | 直接のデータ構成子の呼び出しにラベルがある。位置フィールドを使うか、構成子を関数値として束縛し、その値のパラメータ名を使う。 |

`E0402` は、直接の構成子の呼び出しを含む、位置引数の個数の誤りを報告する。`E0453` は、名前付き引数の不足を呼び出し位置で報告し、不足する名前を挙げる。修正案は対象の宣言を確認してから適用する。エフェクトを持つ式の順序を変えると、プログラムの振る舞いも変わることがある。

各コードの意味は、同梱の Agent Skill（`references/diagnostics.md`。`benitoite skill install` でインストールされる）に挙げてある。

## 19. 標準ライブラリ

prelude のモジュールは取り込みが要らない。ほかのモジュールは、表の名前で取り込む。各モジュールの関数の完全な一覧は、同梱の Agent Skill（`references/stdlib/`）にある。

| モジュール | 取り込み | 内容 |
|---|---|---|
| `Integer`, `Float`, `Decimal`, `RoundingMode`, `Byte`, `Character`, `String`, `Boolean`、[第 4 節](#数値型の名前と接尾辞)のすべての数値型のビット幅と別名 | prelude | 基本型の関数 |
| `List`, `Map`, `Set` | prelude | 永続的なコレクション。マップと集合はキーの順に並ぶ |
| `Option`, `Result`, `Pair`, `Triple` | prelude | ないことがある値、結果、組 |
| `Bytes`, `ByteOrder` | prelude | 変更できないバイト列 |
| `IOError`, `IOErrorKind`, `NetworkError`, `NetworkErrorKind` | prelude | IO とネットワークの操作の失敗 |
| `Reference`, `Lazy`, `Task`, `TaskGroup`, `State` | prelude | 可変のセル、明示遅延、タスク、エフェクト `State` |
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
| `Regex` | `import Benitoite.Unofficial.Regex` | 正規表現。一つの一致を探す時間は、入力の長さと正規表現の大きさの積に比例し、すべての一致を探す時間は、入力の長さの 2 乗に比例することがある |
| `Encoding` | `import Benitoite.Unofficial.Encoding` | Base64 |
| `Hash` | `import Benitoite.Unofficial.Hash` | バイト列の SHA-256 のハッシュ値 |
| `Network.Http` | `import Benitoite.Unofficial.Network.Http` | TLS のない HTTP/1.1 のサーバと、`http` と `https` のクライアント |

### ライブラリの呼び出しのパラメータ名

パラメータ名は、[標準ライブラリのリファレンス](../../../crates/benitoite/skill/references/stdlib/index.md)の宣言で調べる。例えば、`List.map` の外側の引数は `xs, f` であり、引数 `f` の契約は `function(value: T) -> U uses E` である。この二組の名前を区別し、`List.map(xs: items, f: lambda(value) return value * 2)` と書く。

主なコールバックの契約は次のとおりである。

| 関数 | コールバックのパラメータ名（順序どおり） |
|---|---|
| `List.map`, `List.filter`, `List.forEach`, `Set.map`, `Set.filter`, `Set.forEach`, `Option.map`, `Result.map` | `value` |
| `List.fold`, `Set.fold` | `acc, value` |
| `Map.map`, `Map.filter`, `Map.forEach` | `key, value` |
| `Map.fold` | `acc, key, value` |
| `Result.mapError` | `error` |
| `Trait.Functor.map` | `value` |
| `Trait.Foldable.fold` | `acc, value` |

パラメータを使わない場合も、これらの名前を保つ。異なるパラメータ名を持つ関数を渡すときは、[関数の契約とコールバック](#関数の契約とコールバック)で説明した、ラムダで包む方法を使う。

### IO とネットワークの振る舞い

知っておくとよい振る舞いをいくつか挙げる。

- `File.Writer` への書き込み（バッファを書き出す書き込みを含む）が失敗すると、その書き手はバッファの中のデータを捨て、エラーを保持する。その後の `File.write`、`File.writeLine`、`File.writeChunk` は、何も書かずに同じエラーを返す。`File.closeWriter` は、何も書かずに閉じ、同じメッセージを `IOErrorKind.Other` とともに返す。書き手を保持する `with` のブロックを抜けると、書き込みのエラーを処理していても、解放の失敗（実行時エラー）になる。解放のエラーを処理するには、ブロックの終わりで `File.closeWriter` を呼び、その結果を確かめる。最初のエラーで書くのをやめ、やり直すときはファイルを開き直す。
- `Process.run` と `Process.shell` は、コマンドの標準出力と標準エラー出力が閉じるまで待つ。どちらかの出力を開いたままにする背景のプロセスをコマンドが起動すると、コマンドが終わっても戻らない。待つ時間を限るには、呼び出しを `Task.withTimeout` で包む。時間切れは、起動したプロセスを止めない。
- 相対のファイルのパスは、作業ディレクトリを基準に解決する。スクリプトの隣のファイルには `Process.scriptDirectory()` を使う。
- `Process.run` は、シェルを介さず、引数のリストでプログラムを起動する。0 でない終了コードは誤りではなく、結果から読む。コマンドが与えた `input` をすべては読まないとき（`head` のように）も、誤りではない。
- `Process.shell` は、コマンドラインを `/bin/sh -c` で実行する。POSIX sh だけを書く。
- `Http.respond` は 200 から 599 までの状態を受け付ける。ほかの状態は、`1xx` の状態も含め、実行時エラーである。`benitoite` は `content-length` と `connection: close` を設定し、利用者が与えた `content-length`、`connection`、`transfer-encoding`、`trailer`、`keep-alive`、`proxy-connection`、`te`、`upgrade` のヘッダと、利用者が与えた `connection` の値のどれかで名指されたヘッダを捨てる。名前は大文字と小文字を区別せずに比べる。`connection` の値はコンマで分け、前後の空白とタブを取り除き、空の要素を飛ばす。`HEAD` の要求への応答、状態 204・205・304、`CONNECT` の要求への `2xx` の応答には本文を送らない。これらの場合に与えた本文は捨てる。
- HTTP のサーバは、`/` で始まる対象（`//a` を含む）、`http://` か `https://` で始まる絶対形式の対象（大文字と小文字を区別しない）、大文字の `OPTIONS` のときだけ `*`、大文字の `CONNECT` のときだけ authority 形式の対象を受け付ける。`CONNECT` の対象は、ASCII の英字、数字、`-._~!$&'()*+,;=:[]%` からなる空でないホストの後に、`:` と、値が 0 から 65535 までの一つ以上の ASCII の数字を続けたものでなければならない。`/path` や絶対形式の対象を含め、ほかの形は `CONNECT` では拒む。ほかの形の対象と、`"`、`<`、`>`、ASCII でない文字をそのまま含む対象には、ハンドラを呼ばずに 400 を返す。これらの文字はパーセント符号化する。`[`、`]`、`\`、`^`、`` ` ``、`{`、`|`、`}` は、パスとクエリにそのまま書いても受け付ける。後に 2 桁の十六進数が続かない `%` は、受け付けてそのまま残す。
- HTTP のサーバは、`#` を含む要求の対象には 400 を返し、ハンドラに渡さない。フラグメントを省くか、`#` そのものは `%23` と符号化する。`path` はパーセント符号化を保つ。大文字の `OPTIONS` の要求では、パスもクエリも持たない絶対形式の対象（`OPTIONS http://host`）は、`path` が `*`、`query` が空になる。`OPTIONS http://host/`、`OPTIONS http://host?x=1`、`OPTIONS http://host?` は、`path` が `/` になる。`GET http://host` や `options http://host` などのほかのメソッドでは、絶対形式の空のパスは `path` が `/` になる。
- `Http.get` と `Http.send` は、標準のメソッド（大文字の `GET`、`HEAD`、`POST`、`PUT`、`DELETE`、`CONNECT`、`OPTIONS`、`TRACE`、`PATCH`）だけを受け付ける。ほかのメソッド、または `GET`、`HEAD`、`CONNECT` での空でない本文は、何も送らずに `NetworkErrorKind.InvalidInput` を与える。解決できないホスト名は `NetworkErrorKind.HostNotFound` を与える。

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
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.Json

function amountOf(order: Json.Value) -> Option[Pair[String, Integer]]
  bind category <- try Option.andThen(o: Json.get(value: order, k: "category"), f: Json.asString) or return
  bind amount <- try Option.andThen(o: Json.get(value: order, k: "amount"), f: Json.asInteger) or return
  return Option.Some(Pair(category, amount))
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try File.readText("orders.json") or die
  bind parsed <- try Json.parse(text) or die
  bind orders <- try Option.okOr(o: Json.asArray(parsed), error: "orders.json is not an array") or die
  bind totals <- List.fold(xs: orders, initial: Map.empty(), f: lambda(acc, value)
    return match amountOf(value) with
      case Option.Some(Pair(category, amount)) ->
        Map.set(m: acc, k: category, value: Option.unwrapOr(o: Map.get(m: acc, k: category), fallback: 0) + amount)
      case Option.None -> acc
    end match
  end lambda)
  Map.forEach(m: totals, f: lambda(key, value)
    Console.writeLine("${key}: ${value}")
  end lambda)
  return ()
end function
```

```output
book: 2000
food: 300
```

## 20. 互換性

### 版の方針

メジャー版が 0 の間は、次のとおりとする。

- マイナー版（`0.1.0` から `0.2.0`）は、言語、標準ライブラリ、コマンドライン、診断を、互換性のない形で変えることがある。互換性のない変更は、それぞれ移行の方法とともに [CHANGELOG](../../../CHANGELOG.md) に挙げる。
- パッチ版（`0.1.0` から `0.1.1`）は、不具合（`benitoite` の振る舞いのうち、その仕様と異なるもの）だけを直す。言語、標準ライブラリ（非公式のモジュールを含む）、コマンドライン、診断のコード、JSON の形式は変えない。診断のメッセージと修正案は変わることがある。
- 非公式のモジュールを標準ライブラリへ移すと、その取り込みの名前が変わる。これはマイナー版でだけ行う。
- 同梱の Agent Skill は、一緒に配られた版の `benitoite` だけを説明する。更新した後は `benitoite skill install` を再び実行する。

> 注記: `0.0.1` から `0.0.6` までのリリースはソースコードだけを配り、実行ファイルは配らない。実行ファイルは `0.1.0` から配り、それまではどのリリースも互換性のない変更を含むことがある。

## 21. 実験的な機能: パッケージと外部の関数

パッケージと外部の関数は実験的な機能である。構文を見直すときに、その表記が変わることがある。言語のほかの部分と同じ[互換性の方針](#20-互換性)に従い、実験的な機能もこの方針の例外にはならない。

### 局所の依存

パッケージは、設定ファイル `package.bnt` と、ほかのスクリプトが取り込めるモジュールを持つディレクトリである。例えば、`packages/textkit` の下に次の二つのファイルを作る。

```files
name: packages/textkit/package.bnt
language "0.0.6"

package Textkit
  license "MIT"
end package
```

```files
name: packages/textkit/Slug.bnt
public function slug(text: String) -> String
  return String.toLowercase(String.replace(s: String.trim(text), old: " ", new: "-"))
end function
```

起点のスクリプトの、取り込みと宣言の前に依存を宣言する。

```benitoite
// spec: 01-03 依存のパッケージの取り込み
language "0.0.6"

dependency Textkit
  path "packages/textkit"
end dependency

import Benitoite.Unofficial.IO.Console
import Textkit.Slug

function main() -> Unit uses Console.Write
  Console.writeLine(Slug.slug(" Hello Packages "))
end function
```

```output
hello-packages
```

`dependency Textkit` の `Textkit` は依存の別名であり、`Benitoite` 以外の大文字で始まる識別子である。パッケージの `package` ブロックの名前と異なっていてもよい。`import Textkit.Slug` は、この別名とパッケージの根からのパスを使うので、`packages/textkit` の `Slug.bnt` を読む。パッケージの中の取り込みは、そのパッケージ自身の根からのパスを使い、呼び出し元の根のモジュールを取り込めない。呼び出し元が使えるのは `public` な宣言だけである。

依存の `path` は、作業ディレクトリではなく、起点のスクリプトの根のディレクトリからの相対パスである。根の外を指してよく、絶対パスも受け付ける。各パッケージには、`package` ブロックと `language` の宣言を持つ独自の `package.bnt` が要る。この版では、依存自身は依存を宣言できない。Git のソース、版の選択、パッケージのダウンロードには対応しておらず、`source`、`version`、`commit` の欄は拒む。

前述の小文字の `packages/textkit` のように、依存のディレクトリは根のモジュールの名前と区別する。一つの取り込みが根と依存の両方で異なるモジュールを見つけると、誤りになる。宣言した依存の中のファイルは、その別名を通して取り込まなければならない。依存の根は、起点の根を含められず、別の依存の根と等しくもなれず、互いに含められない。取り込んだパッケージのモジュールは、通常の名前と型の検査を受ける。誤りは報告するが、警告は `--deny-warnings` のときも抑える。

### ファイルのヘッダ、設定、言語の版

ファイルのヘッダには、先頭の `//!` の説明の後、取り込みや宣言の前に、`language` と `dependency` の項目を書く。取り込むモジュールには、これらの設定を書けない。代わりに、根のディレクトリそのものにある `package.bnt` に設定を置いてもよい。Benitoite は親のディレクトリからこのファイルを探さない。

例えば、根の設定ファイルに言語の版を記録し、起点のスクリプトには宣言だけを書くことができる。

```files
name: package.bnt
language "0.0.6"
```

```benitoite check
// spec: 01-03 依存の記述と `package.bnt`
function main() -> Unit
end function
```

依存のブロックも、その根の設定ファイルへ移せる。依存は一か所にまとめる。起点のスクリプトと `package.bnt` の両方で依存を宣言すると誤りになる。両方で `language` を宣言しても誤りになる。

`language "MAJOR.MINOR.PATCH"` は、三つの十進整数で、そのファイルを書くときに使った言語の版を記録する。Benitoite `0.0.6` では、`0.0.6` の宣言は互換性の検査を通り、それより後の版は `E0907`、前の版は `E0908` になる。起点のスクリプトと根の設定ではこの宣言を省いてよいが、パッケージの設定では必須である。宣言の有無にかかわらず、処理系は同じ言語の規則を使う。根の版と依存の版は、それぞれ独立に検査する。互換性の保証は[版の方針](#版の方針)、各リリースの変更は [CHANGELOG](../../../CHANGELOG.md) に記す。

`package.bnt` には、設定（`language`、`dependency`、`package` のブロック）だけを書き、取り込みや宣言は書かない。`package` ブロックはこのファイルにだけ書け、依存と組み合わせられない。その名前は大文字で始まる識別子であり、メタデータの欄は、省略可能な `license` だけである。欄の値は通常の文字列リテラルであり、文字列補間は使えない。欄の順序は自由だが、重複する欄や未知の欄は誤りになる。

`package.bnt` は、`run`、`check`、`test` の起点のファイルにできない。`benitoite test <directory>` は、このファイルと、独自の `package.bnt` を持つ入れ子のディレクトリを飛ばす。パッケージをテストするには、そのパッケージの根を指定する。`fmt` は、スクリプトに加えて設定ファイルも整形する。

### 内容のハッシュとエフェクトの記録

局所の依存の `hash` は省略可能である。指定したときは、そのパッケージのモジュールを一つも取り込まなくても、読み込むたびに Benitoite が対象のパスとファイルの内容を検査する。不一致のときは、期待する値と計算した値を報告する。`hash` がなければ、内容の検査も、ハッシュがないことの警告も行わない。パッケージの開発中に役立つ。

次の例は欄の構文を示す。すべて 0 のハッシュは説明用であり、実際の値は `package add` か `package update` で計算する。

```text
dependency Textkit
  path "packages/textkit"
  hash "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  effects ""
end dependency
```

ハッシュの対象は、`.bnt` と `.wasm` のファイル、および名前が `LICENSE`、`COPYING`、`README` で始まるファイルである（後者の名前は ASCII の大文字と小文字を区別しない）。`package.bnt` も含む。名前が ASCII の大文字で始まるディレクトリと、根の `wasm/` の下の隠しディレクトリ以外のすべてのディレクトリを辿る。隠し項目と、名前が正しい UTF-8 でない項目は除く。根の `rust/`、`wit/`、`target/` などのディレクトリは辿らない。ハッシュは相対パスとファイルのバイト列で決まり、ファイルの権限と空のディレクトリには依存しない。

ハッシュの計算は、辿った隠し項目以外の項目のシンボリックリンク、小文字にしたときに衝突する対象のパス、改行を含む対象のパス、読めない対象のファイルを拒む。上限は、対象のファイル 10,000 個、辿る項目 100,000 個、対象のファイルの内容 128 MiB である。ハッシュは、計算から読み込みまでの間に別のプロセスがファイルを変えることを防がない。

`effects` は、パッケージのコマンドが書く記録であり、例えば `effects "Console.Write, File.Read"` と書き、空集合なら `effects ""` と書く。読み込みでは形式を検査するが、パッケージとは照合しない。実際のエフェクトの検査は関数の型を使い、`main` から到達できる操作は、ハンドラの処理を考慮したうえで、その `uses` に現れなければならない。この記録は依存の変更を確認するためのものであり、権限を与えるものでも、スクリプトが接続できるホストや読み書きできるファイルを制限するものでもない。

### パッケージのコマンド

```text
benitoite package add <alias> --path <directory> [<root or entry>]
benitoite package update [<alias>] [<root or entry>]
benitoite package move <entry>
```

`add` は、新しい依存を宣言し、そのハッシュを計算し、公開された組み込みのエフェクトを記録し、コンポーネントを報告する。`--path` の値は、選んだ根からの相対パス（または絶対パス）であり、書いたとおりに宣言へ写す。既存の別名は誤りになる。`add` は、既に依存がある場所へ書く。依存がなければ既存の `package.bnt` を使い、設定ファイルもなければ起点のファイルを使う。編集する設定ファイルか起点のファイルが必要である。

`update` は、ハッシュとエフェクトの記録を計算し直す。別名を指定しなければ、既にハッシュを持つ依存だけを更新する。別名を指定すれば、ハッシュがなかった場合にも加える。保存した `effects` の欄と比べ、加わったエフェクトを `+`、取り除かれたエフェクトを `-` で示す。記録がないか形式が誤っていれば、`(not recorded)` と現在のエフェクトを報告する。形式が誤った `hash` や `effects` の欄は、明示的な更新で修復できる。ハッシュが変わらずエフェクトだけを更新した場合は、ハッシュを一度だけ示す。ハッシュを持つ依存が一つもない場合、一括の更新は `no dependencies with hash to update` と報告する。両方の記録が変わらなければ、`unchanged` と報告し、ファイルを置き換えない。

`add` と `update` で対象を省くと、作業ディレクトリを選ぶ。ディレクトリを指定すると、その `main.bnt` があれば使い、ファイルを指定すると、それを起点のファイルとして選ぶ。既存の `package.bnt` を渡すと、そのディレクトリを根として選ぶ。明示的に指定した `package.bnt` が存在しない場合は、`E0101` を報告し、起点のファイルを編集しない。`update` の引数が大文字で始まる識別子一つだけなら、別名として扱う。識別子の形をしたディレクトリのパスは、区別するために `./Name` と書く。

前述の純粋な Textkit パッケージについて、`main.bnt` がまだ `Textkit` を宣言していなければ、追加すると次のように出力する（`<computed-hash>` は実際の `sha256:` の値を表す）。

```text
benitoite package add Textkit --path packages/textkit main.bnt

added dependency Textkit (package Textkit) to main.bnt
  hash: <computed-hash>
  effects: (none)
  components: (none)
```

コマンドは、公開された関数と型クラスのメソッドの宣言、公開された型の別名の右辺、公開されたレコードのフィールドの型、公開された `data` の構成子のフィールドの型から、組み込みのエフェクトを報告する。入れ子の関数の型のエフェクトも含む。ライブラリのモジュールは、`Benitoite.Unofficial.IO.Console` のような正式な取り込みの名前で識別する。`State` と `IO.All` に取り込みは要らない。標準ライブラリの表にない取り込みの名前を通じて参照したエフェクトは数えない。この報告のためにパッケージを型検査することはなく、利用者が定義したエフェクトとエフェクト変数は含めず、`IO.All` も展開しない。コンポーネントの報告は、`(no imports)` を添えるか、失敗の理由を示す。コンポーネントの失敗だけでは編集を止めない。`benitoite check` は引き続き、スクリプトが実際に使うパス、公開された名前、型を検査する。

`move` は、起点のファイルのヘッダの設定と関連するコメントを、その隣の `package.bnt` へ移す。対象にはファイルが必要であり、ディレクトリは使い方の誤りになる。空のヘッダや、既に `language` か依存を含む移動先は拒む。例えば次のようになる。

```text
benitoite package move main.bnt
moved language, dependency Textkit from main.bnt to package.bnt
```

これらのコマンドは、ソースの本体とそのコメントを保ちながらヘッダを編集する。コメントだけの設定ファイルへ移す場合は、そのコメントの後に加え、コメントのバイト列と行末を保つ。新しく作る設定ファイルは、起点のファイルの権限を写し、実行のビットを外す。編集した設定を整形し、一時ファイルを通してファイルを置き換える。`move` は、起点のファイルへの書き込みが失敗した場合、設定の復元を試みる。検証は対象の依存の宣言と設定を検査し、関係のない依存の設定の誤りを理由に編集を拒まない。提案中の編集を指す診断には、まだ書き込んでいないことを示す。変更は標準出力、診断は標準エラー出力に報告し、成功なら 0、不正な入力や読み書きの失敗なら 2 を返す（処理系の不具合なら 3）。三つのコマンドすべてが `--diagnostics=text|json` を受け付けるが、変更の報告はテキストのままであり、報告用の `--json` オプションはない。

### WASM を通じた外部の関数と型

外部の関数は、バイナリの WebAssembly Component Model のコンポーネントから本体を得る。コンポーネントは取り込みを持ってはならず、Benitoite はホストの関数も WASI も提供しない。コアの Wasm モジュールとテキスト形式のファイルは受け付けない。本体も `end function` も付けずに、トップレベルの関数を宣言する。

<!-- WASM のバイナリは files ブロックで置けないため、以下は text の例とする。照合・実行は testdata/external/ のゴールデンが確かめる。 -->

```text
@external("wasm", "wasm/fuzzy.wasm", "distance")
public function distance(a: String, b: String) -> Integer
```

対応する WIT の契約は、world から関数を直接公開する。

```text
package example:fuzzy;

world fuzzy {
  export distance: func(a: string, b: string) -> s64;
}
```

宣言には、具体的な引数と戻り値の型を与えなければならない。型パラメータ、制約、エフェクト変数は持てない。展開した引数か戻り値の型に外部の型を含む関数は、`uses State` を宣言しなければならない。それ以外の外部の関数はすべて純粋であり、`uses` を宣言できない。`public`、`public(package)`、`@deprecated` は使えるが、`@test` と `@builtin` は使えない。属性の第 3 引数は、world で直接公開された関数か、公開されたインターフェースの中の関数を `interface#function` の形で指定する（例: `bnt:test/api@1.2.0#add`）。文字列に `#` があれば、最後の `#` がインターフェースの公開名と関数名を区切り、どちらも空にはできない（`E0815`）。インターフェースの名前は、版も含めて公開名と正確に一致しなければならず、互換の版を代わりに使うことはない。`check`、`run`、`test` は、実行の前に引数の数、位置ごとの型、戻り値の型を検査する。引数の名前は一致しなくてよい。関数がない場合の診断（`E1006`）は、直接の公開名と `interface#function` の公開名の両方を列挙する。シグネチャの不一致（`E1007`–`E1009`）では、すべての WIT 型に対応する Benitoite の表現があれば、宣言を提案する。WIT の `byte-start` のような引数名は `byteStart`、`list<u8>` は `Bytes`、省略された結果は `Unit` になる。

コンポーネントのパスは、入れ子のモジュールの宣言でも、その宣言が属する根からの相対パスである。`/` を使い、`.wasm` で終わり、空の区間、`.`、`..`、隠し区間、バックスラッシュを含められない。名前は、大文字と小文字を含めて、ディレクトリの項目と正確に一致しなければならない。解決したパスは根の下に収まらなければならない。依存の場合、または根の `package.bnt` がパッケージを宣言する場合は、コンポーネントは `wasm/` の下にも収まらなければならない。

| Benitoite の型 | WIT の型 |
|---|---|
| `Integer8`, `Integer16`, `Integer32`, `Integer` (`Integer64`) | それぞれ `s8`, `s16`, `s32`, `s64` |
| `Byte` (`UnsignedInteger8`), `UnsignedInteger16`, `UnsignedInteger32`, `UnsignedInteger64` (`UnsignedInteger`) | それぞれ `u8`, `u16`, `u32`, `u64` |
| `Float32`, `Float` (`Float64`), `Boolean`, `Character`, `String` | それぞれ `f32`, `f64`, `bool`, `char`, `string` |
| `Bytes`, `List[Byte]` | `list<u8>` |
| `List[T]`, `Option[T]`, `Result[T, E]` | `list<T>`, `option<T>`, `result<T, E>`。中の型にも同じ対応を再帰的に適用する |
| `Pair[A, B]`, `Triple[A, B, C]` | `tuple<A, B>`, `tuple<A, B, C>` |
| 具体的な型引数を持つレコード | 型引数を置き換えた後のフィールドが一致する `record` |
| 具体的な型引数を持つ `data` | ケースが一致する `variant`。引数が 0 個ならペイロードなし、1 個ならその型、2 個以上なら平らなタプル一つをペイロードとする |
| 引数のない構成子だけを持つ `data` | `enum`、またはペイロードのない `variant` |
| ほかの、引数を一つ以上持つ単一の構成子の `data` | WIT の型がタプルなら `tuple`。構成子の名前は無視し、引数を位置で照合する |
| `Set[D]`。D は引数のない構成子を 1〜32 個持つ具体的な `data` | 数、順序、名前が一致する `flags` |
| `Map[K, V]` | `map<K, V>`。K は `Boolean`、整数型（`Byte` を含む）、`Character`、`String` のいずれかでなければならない |
| 外部の型 | 引数では `borrow<R>`、戻り値では `own<R>` |
| 関数の戻り値としての `Unit` | 結果なし |

型の別名は展開する。`Option`、`Result`、`Pair`、`Triple` は標準ライブラリの型でなければならない。`Result` の片側が `Unit` なら、WIT ではその側を省く。`Result[Unit, String]` は `result<_, string>`、`Result[Unit, Unit]` は `result` に対応する。要素が 0 個のタプルを含め、ほかの入れ子や引数での `Unit` の使用には対応しない。利用者のモジュールと標準ライブラリのレコードと `data` の型には、同じ構造の規則を使う。型名は WIT の型名と一致しなくてよい。フィールドとケースの数、宣言の順序、名前、型、ペイロードの有無は一致しなければならない。名前は `-` を除き、ASCII の英字を小文字にして比べる。`byte-start` は `byteStart`、`not-found` は `NotFound` と一致する。アンダースコアは保ち、WIT の名前とは一致しない。レコード、variant、enum、flags の型のどちら側でも、この正規化後の名前の重複は拒む。

`@extensible` は、`enum`、`variant`、`record` のこれらの検査を緩めず、未知の外部のタグを許さない。構成子やフィールドを追加したときも、WIT の宣言は現在の Benitoite の宣言と厳密に一致しなければならない。

具体的な型引数はフィールドと構成子の引数に代入するので、`Box[T]` が型 T のフィールドを持つ場合は `Box[Box[Integer]]` を受け付ける。外部の関数自身は単相のままである。未解決の型変数とエフェクト変数、宣言の依存の再帰（`List` や `Option` を通じた再帰も含む）は、`E1010` を報告する。型の展開の上限は、深さ 100、根の型ごとに 100,000 ノード、検査ごとに 1,000,000 ノードである。同じ階層のフィールドで一つの型を共有してよい。構造の不一致は `E1008` か `E1009` を報告し、WIT の形と、最初の不一致を `reason` の注記に示す。シグネチャに利用者が定義したレコード、variant、enum、flags の要素型、リソースのハンドルが必要な場合は、Benitoite の型名を推測できないため、宣言の提案は省く。

flags 型には 1〜32 個の項目が必要だが、何も選択しない値は許される。戻り値のうち、宣言した項目を超えるビットは捨てる。マップの引数はキーの順に送る。戻り値の各項目は、キーの重複の正規化で後から捨てる項目も含め、元の順序ですべて検査する。各キーの最後の値を採用し、最終的なマップはキーの順に並ぶ。`Decimal`、`Bytes`、レコード、`data` など、対応しないキーの型は、Benitoite の中では有効なマップのキーであっても `E1010` を報告する。`Set` は flags としてだけ対応する。関数、`Decimal`、`with` で使うリソース型、タスクは、この境界を越えて渡せない。外部の型は、後述の別の規則を使う。

例えば、次の宣言は、リポジトリの実行可能な例 `external/wit-docs-values` と同じコンポーネントと公開名を使う。

```text
record Box[T]
  value: T
end record
@external("wasm", "generic.wasm", "box")
function box(v: Box[Integer]) -> Box[Integer]
@external("wasm", "generic.wasm", "nested")
function nested(v: Box[Box[Integer]]) -> Box[Box[Integer]]

data D1
  F1
end data
@external("wasm", "flags.wasm", "f1")
function f1(v: Set[D1]) -> Pair[Set[D1], Integer]

@external("wasm", "maps.wasm", "result")
function result(v: Map[String, Integer]) -> Map[String, Integer]

data Four
  Item(Integer, Integer, Integer, Integer)
end data
@external("wasm", "tuples.wasm", "tuple4")
function tuple4(v: Four) -> Four

data Two
  Value(Integer, Integer)
  Empty
end data
@external("wasm", "variants.wasm", "fields")
function two(v: Two) -> Two
```

対応する WIT の形は、`value: s64` を持つレコード、入れ子のレコード、結果が `tuple<flags-type, s64>` の `flags { f1 }`、`map<string, s64>`、`tuple<s64, s64, s64, s64>`、`variant { value(tuple<s64, s64>), empty }` である。例のゲストは、`box(Box(value: 35))` から `42`、`nested(Box(value: Box(value: -7)))` の内側の値として `0`、`f1(Set.empty())` から `Pair(Set.fromList([D1.F1]), 0)`、`Map.toList(result(Map.empty()))` から `[Pair("a", 2), Pair("z", 3)]`、`tuple4(Four.Item(1, 2, 3, 4))` から `Four.Item(12, 14, 16, 18)`、`two(Two.Value(3, 7))` から `Two.Value(14, 29)` を返す。これらの出力は例のゲストの動作を示すものであり、任意の外部の関数に課す変換ではない。

#### 外部の型とインスタンスの寿命

外部の型は、`@external` 属性と、`=` も右辺も持たない `type` の宣言で宣言する。公開された WIT のリソースを指定し、型パラメータは持たない。`public`、`public(package)`、`@deprecated` は使えるが、`@test` と `@builtin` は使えない。公開名がないかリソースでない場合は、リソースの公開名を列挙して `E1012` を報告する。

```text
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#cell")
public type Cell
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#[constructor]cell")
public function newCell(start: Integer) -> Cell uses State
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#[method]cell.bump")
public function bump(self: Cell, by: Integer) -> Integer uses State
```

外部の型は、引数では `borrow<R>`、戻り値では `own<R>` に対応する。この規則は、リスト、オプション、結果、タプル、レコード、variant の中にも適用する。型の宣言と関数は、同じコンポーネントファイルの同じリソースを参照しなければならない。所有権を受け取る引数（`own<R>`）は拒む（`E1008`）。外部の値は中身を見せず、等値の比較、マップのキーや集合の要素としての使用、`Assert.equal` への受け渡しはできない。既定の `Show` の実装はなく、利用者の実装は利用者の型の通常の規則に従う。`with` が管理するリソース型とは別であり、`with` では使えない。外部の型を渡す関数で `uses State` を省くと、挿入の修正案を添えて `E0816` を報告する。ほかのエフェクトの宣言は `E0812` で拒み、外部の型を持つ関数には、宣言を `uses State` に置き換える修正案を添える。エフェクトの検査は、コンポーネントの照合より前の型検査で行うので、対応しない型（`E1010`）やリソースの不足（`E1012`）より先に `E0816` や `E0812` が出ることがある。

外部の値を回収すると、そのハンドルを、状態を持つインスタンスへの次の呼び出しの前に破棄するための列に入れる。破棄の時点は回収に依存する。そのため、ゲストの共有状態を調べるメソッドの結果と資源の消費量は、回収の時点に依存することがある。明示的な破棄の関数はない。破棄は回収を待つので、外部の値以外の値を多数保持すると、外部の値を繰り返し作って捨てるうちに、状態を持つインスタンスのメモリの上限（既定で 64 MiB）に達することがある。`[static]` の関数を含め、シグネチャに外部の型がない関数は、新しいインスタンスを作り、状態を持つインスタンスを調べられない。外部の値を返す呼び出し中のゲストのメモリの増加は、回収を促すヒープの使用量の計数に加える。最初に変換した外部の値に、増加分全体を計上する。実行の終了、中断、呼び出しの失敗では、状態を持つインスタンスを捨てる。状態を持つ呼び出しは、参照インタプリタとの比較から除く。

#### 実行の上限と統計

外部呼び出しは同期的に実行する。外部の型を渡す関数は、実行ごと、コンポーネントごとに、状態を持つ一つのコンポーネントのインスタンスを共有する。それ以外の関数は、呼び出しのたびに新しいインスタンスを作る。呼び出し中はほかの Benitoite のタスクは動かず、`Task.withTimeout` では取り消せない。`SIGINT` と `SIGTERM` は Wasm の実行を中断し、プロセスを終了状態 130 で終えられる。既定では、各呼び出しの燃料の上限は 10^10、線形メモリの合計の上限は 64 MiB（状態を持つインスタンスでは寿命全体）、値の転送量の上限は方向ごとに 256 MiB である。燃料は計算量を制限し、経過時間は制限しない。各呼び出しは、コアのインスタンス、メモリ、テーブルもそれぞれ 16 個、ゲストの各テーブルは 10,000 要素までに制限する。メモリ自身が宣言した最大値を超える `memory.grow` は、Wasm と同じく -1 を返す。

検査器は実行前に転送の経路を選ぶ。元のゲストの関数は一度だけ呼び、失敗の後に別の経路で試し直すことはない。

| 統計の経路 | 使う場合 | 転送量の数え方 |
|---|---|---|
| `stateful` | 引数か戻り値に外部のリソース型を含む | 動的な WIT の値を使い、コンポーネントのインスタンスを保持する |
| `typed` | リソースを含まず、引数が 0〜3 個、結果が一つで、すべての型が `Integer`、`Float`、`String`、`Bytes`、`List[Byte]`、`List[Integer]`、`List[Float]` のいずれか。数値のリストを引数に持つ場合は引数が最大二つ | 数値は 0、バイト列は要素ごとに 1、数値のリストは要素ごとに 8、引数の文字列は UTF-8 のバイト数 |
| `adapter` | `typed` の経路に含まれないビット幅の数値、入れ子のリスト、マップ、flags、一般のタプル、variant、結果のない関数など、ほかの対応する再帰のない値 | 詰めて格納した実際のバイト数。32 バイトのヘッダと詰め物も含む。別の構築量の上限にも同じ設定値を使う |
| `dynamic` | アダプタが生成コードの上限 16 MiB、memory32 の配置の範囲、または保守的に見積もったコアのインスタンス数（アダプタの三つのインスタンスを含む）の上限 16 を超える場合 | 動的な WIT の値を使う。ゲストを呼ぶ前に決める |

別名は経路の選択を変えない。`Integer64`、`Float64`、`UnsignedInteger8` は、`Integer`、`Float`、`Byte` と同じ型を表す。アダプタは関数ごとに組み合わせるので、別の関数の宣言を加えても、その組み合わせとインスタンス数の見積もりは変わらない。コンパイル済みのコンポーネントと生成したアダプタは、一回の検査または実行の中で再利用する。永続的なキャッシュはない。アダプタのメモリ、コアのインスタンス、テーブルは、ゲストと同じ Store の上限に数え、その命令は同じ燃料を消費し、同じ中断の要求に応じる。各アダプタは、メモリ、変換、融合のために、コアのインスタンスを三つ加える。アダプタに合わせて既定の上限を増やすことはない。複数の写しにより、アダプタの線形メモリの使用量が転送量の約 3〜4 倍になることがある。そのため、転送量の上限より小さい値でも、既定のメモリの上限 64 MiB に達することがある。UTF-16 を含む元のゲストの文字列の符号化は Component Model が扱い、アダプタが詰めて格納する文字列は UTF-8 である。値を写した後、ゲストの戻り後の片付けは Component Model を通して実行し、ホストから二度目に呼ぶことはない。

アダプタの経路では、転送量の上限は、詰めて格納した引数と結果のバイト列全体を、それぞれ独立に制限する。第二の上限は、方向ごとの論理的な構築量を、同じ `--wasm-transfer` の値に制限する。Benitoite の値が現れるごとに 16 バイトを数え、文字列と `Bytes` の内容を加える。リストの要素、構成子のフィールド、マップのすべてのキーと値、選択した flags の構成子も、それぞれ値が現れる箇所として数える。`Bytes` の要素には別の 16 バイトを加えないが、`List[Byte]` の要素には加える。ABI のためだけの根のレコード、マップの項目のタプル、構成子の引数をまとめるタプルは、Benitoite の値を加えない。重複するマップの項目は、正規化の前に数えて検証する。ABI 上の大きさが 0 の値も、構築量に数える。これは論理的な構築量であり、確保したヒープのバイト数やプロセスのメモリ全体ではない。

動的な経路では、`Bytes` の各バイトを含め、リストの各要素をホストの `Val`（対応するプラットフォームでは 40 バイト）として数える。マップはキーと値の両方の表現を数える。レコードのフィールドは WIT の名前と子の表現を含み、variant は選択した名前と、ペイロードがあればその表現を含む。enum と選択した flags は名前のバイト数を含む。子はそれぞれ自身の量を加える。スカラー値とリソースのハンドルは 0 と数える。`typed` の経路では、戻り値の文字列はゲストの値をホスト側の表現へ変換するときに、ゲストの符号化でのバイト数を計上するが、統計では UTF-8 のバイト数を報告する。このため、同じ値でもシグネチャと経路によって転送量の上限への達し方が異なる。`Bytes` と `List[Byte]` は、Benitoite の戻り値の型として区別を保つ。引数は、実行時のコンパイルやインスタンス化の前に検査し、準備する。戻り値のリストは小さな葉に直接構築し、リスト全体の Benitoite の値の中間配列は作らない。

値の大きさの上限は、構築の前に適用する。文字列と `Bytes` は最大 2^30 バイト、リストは最大 2^24 要素である。Map と Set には、言語全体の要素数の上限はない。転送量と構築量の上限、燃料、Store の上限は、統計を取らない場合も検査する。

`run` と `test` は、これらの上限を変えるために `--wasm-memory=<size>`、`--wasm-fuel=<count>`、`--wasm-transfer=<size>` を受け付ける。大きさはバイト数、または整数に `KiB`、`MiB`、`GiB` の接尾辞を付けた値であり、範囲は 1 MiB から 4 GiB である。燃料は 1 から 2^64−1 までの十進整数である。不正な設定や重複した設定は、使い方の誤りになる（終了状態 2）。`run` では、これらのオプションをスクリプトのパスの前に置く。`test` はパスの間でも受け付ける。各テストの関数は、同じ設定の上限を使う。

`--wasm-stats` は、終了時に標準エラー出力へ JSON を一行書き、設定した `limits`、明示的な `overrides`、`calls`、`functions`、`fuel`、`memory`、`arguments_transfer`、`results_transfer`、`stateful_instances`、`reached_limits` を含める。`routes`（`typed`、`adapter`、`dynamic`、`stateful` の呼び出し回数）、`fallback_reasons`、アダプタだけの `construction_bytes`、および数値の `code`、`requested`、`limit`、`calls` を持つ `adapter_failures` も含む。各消費量のオブジェクトは、`total`、`maximum`、`incomplete_calls` を持つ。`construction_bytes` は引数と結果の論理的な量を合計するので、その最大値は一回の呼び出しの合計の最大値であり、詰めて格納した転送のバイト数とは別である。`typed`、`dynamic`、`stateful` の呼び出しは、`construction_bytes` もその `incomplete_calls` も増やさない。構築量全体を測る前に止まったアダプタの呼び出しだけが、その欄を増やす。メモリの合計は増加を一度だけ数え、最大値は呼び出し全体か、状態を持つインスタンスの寿命全体を数える。引数の検証で拒んだ呼び出しも、呼び出し回数に含む。転送量の合計は、値を数えられた呼び出しだけを含み、消費量を得られなかった場合は `incomplete_calls` を増やす。動的な経路と `typed` の文字列の統計は、ホストの UTF-8 のバイト数を数える。これはゲストの値をホスト側の表現へ変換するときに計上したバイト数と異なることがある。アダプタの転送の統計は、詰めて格納したバイト列を数える。`test` は、すべてのテストの実行を一つの報告に集計し、テストごとの内訳は示さない。このオプションがなければ、出力は変わらない。公開の埋め込み API と参照インタプリタは、既定の上限を保つ。

資源の上限の失敗以外のトラップ、ABI 違反、インスタンス化の失敗は、`R0601` で実行を止める。燃料の枯渇は `R0904`、メモリ・転送量・構築量の上限は `R0905` を報告する。後者には、達した上限と、分かる場合はアダプタの失敗した段階を示す注記を添える。テーブルの大きさとコアの対象数の上限は、資源の種類と必要数を添えて `R0906`、戻り値の大きさの上限は `R0902` を報告する。診断コードと失敗の分類は経路間で一致するが、トラップの文言は異なることがある。ゲストの ABI 違反は、アダプタが値をゲストに渡す形式へ変換するときやゲストを呼ぶときに現れることがある。これらの失敗は `Result.Error` に変換しない。宣言した `Result` を通してエラーを返すコンポーネントは、通常の値を返す。

引数と結果は、ホストのメモリに同時に存在しうる。動的な WIT の表現、型付きの配列、詰めて格納したアダプタのバッファ、ゲストとアダプタの線形メモリ、Benitoite の値は、すべてメモリを使う。設定した転送量とメモリの上限は、この消費の異なる部分を制限し、プロセスのメモリ全体は制限しない。

これらの検査は、コンポーネントの結果が正しいことも、正常に戻ることも保証しない。コンポーネントのコンパイルは、実行時だけでなく検査時にも行う。入力のコンポーネントは 256 MiB に制限するが、検査の時間とホストのメモリには上限がない。信頼できないコンポーネントの検査も含め、処理系の隔離は引き続きハーネスか OS の責任であり、スクリプトには実行時の権限制御がない。
