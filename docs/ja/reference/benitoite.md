# Benitoite 言語リファレンス

> この文書は、`docs/reference/benitoite.md` の日本語の訳である。翻訳元は Benitoite 0.0.11 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

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

このリファレンスは、[第 21 節](#21-実験的な機能-パッケージと外部の関数)の実験的な機能を含めて、Benitoite `0.0.11` を説明する。Benitoite のスクリプトの書き方と実行の仕方を、例を添えて説明する。このファイルでプログラムとして印を付けた例は、すべてリポジトリのテストが `benitoite` で確かめている。

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

最初の行は、モジュール `Console` を取り込む。`main` のシグネチャは、`uses` の後で、`main` がコンソールに書くこと（`Console.Write`）を示す。プログラムの外で何かを行う関数は、このようにそれを挙げなければならず、その関数を呼ぶすべての関数も同じである。`main` の `uses` を読めば、スクリプトが行いうる操作の種類がわかる。ただし、その対象や結果はわからない。

## 2. コマンドライン

```text
benitoite [options] <script> [script arguments...]
benitoite run   [options] <script> [script arguments...]
benitoite check [options] <script>
benitoite test  [options] <path>...
benitoite fmt   [options] <path>...
benitoite skill install|uninstall [--user | --project] [--agent <name>]...
benitoite skill list [--format=text|json]
benitoite skill show [--format=text|json] <logical-name>
benitoite package add|update|move ...
benitoite --help
benitoite --version
benitoite --version=json
benitoite --licenses
```

| コマンド | 行うこと |
|---|---|
| `run` | スクリプトを検査し、その `main` を呼ぶ。スクリプトのパスの後の引数は、`-` で始まるときも、スクリプトに渡す（`Process.arguments()`）。 |
| `check` | スクリプトを実行せずに検査する。 |
| `test` | 指定したファイルの中、または指定したディレクトリの下のすべての `.bnt` ファイルの中のテストの関数を実行する。ただし、`package.bnt` と入れ子のパッケージは除く。[16. テスト](#16-テスト)を参照する。 |
| `fmt` | 指定したファイル、または指定したディレクトリの下のすべての `.bnt` ファイルを、標準の配置に書き換える。[17. 整形](#17-整形)を参照する。 |
| `skill` | 同梱の Agent Skill をインストール・削除する。または、インストールせずに埋め込み文書の一覧を取得し、本文を取り出す。[Benitoite のインストール](install.md#3-agent-skill-をインストールする)を参照する。 |
| `package` | 実験的な機能。局所の依存の宣言を追加・更新・移動する。[パッケージのコマンド](#パッケージのコマンド)を参照する。 |
| `--help` | 使い方を出力する。 |
| `--version` | 1 行目に `benitoite` の版（`benitoite 0.0.11`）を、2 行目に文字の関数が使う Unicode の版（`Unicode 17.0.0`）を出力する。 |
| `--version=json` | 版・ビルド・対応する形式の情報を一つの JSON オブジェクトとして出力する。最初の引数でなければならず、後続の引数は受け付けない。 |
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

`run` と `check` のオプションは、コマンドの後、スクリプトのパスの前に置く（`run` を省くときはスクリプトの前に置く）。`test` と `fmt` では、パスの後にも置ける。未知のオプション、重複したオプション、値の欠落や不正、そのコマンドが受け付けないオプションは、終了状態 2 の使い方の誤りになる。次の表の値を取るオプションには `=` が必要である。ただし、`--allow-effects` は分離した値も受け付ける。

| オプション | 意味 | 既定 |
|---|---|---|
| `--diagnostics=text` または `--diagnostics=json` | 診断と、実行時エラーなどの報告の形式。`test` では、テストの結果の形式でもある。 | `text` |
| `--max-call-stack=<size>` | `run` と `test`（`test` ではテストごと）での入れ子の呼び出しの上限。`512MiB` のように、整数に `KiB`、`MiB`、`GiB` を付けて書く。 | `1GiB` |
| `--deny-warnings` | `check`、`run`、`test` で警告を誤りとして扱う。 | オフ |
| `--report=json` | `check` と `test --check` で、一つの JSON の検査報告を標準出力に書く。[検査報告](#検査報告)を参照する。 | オフ |
| `--allow-effects=<names>` または `--allow-effects <names>` | `run` とテストを実行する `test` で、実行前に各入口の関数が宣言するエフェクトを許可集合と比べる。[実行前のエフェクトの上限](#実行前のエフェクトの上限)を参照する。 | 上限なし |
| `--doc` | `test` で[文書の例](#文書の例)も対象に含める。 | 無効 |
| `--check` | `test` ではテストを実行せずに検査する。`fmt` ではファイルを書き換えずに、変わるはずのファイルを報告する。 | オフ |

`run` とテストを実行する `test` の四つの `--wasm-*` オプションは、[実行の上限と統計](#実行の上限と統計)で説明する。

### `run` と `check` の終了状態

| 状態 | 意味 |
|---:|---|
| 0 | `check` が誤りを見つけなかった。または `main` が `()` か `Result.Ok(())` を返した。 |
| 1 | `main` が `Result.Error` を返した。プログラムが実行時エラーで止まった、または資源の不足で止まった。またはコマンドラインの引数が正しい UTF-8 でない。 |
| 2 | スクリプトに検査の誤りがある（`--deny-warnings` のときは警告も）、`--allow-effects` を超える（`E0512`）、`benitoite` の制限のために実行できない、または読めない。またはコマンドラインが誤っている。 |
| 3 | `benitoite` の処理系の不具合。報告してほしい。 |
| 130 | `run` が `SIGINT` か `SIGTERM` を受けた。終わる前に、すべてのタスクを取り消し、リソースを解放し、出力を書き出した。 |

`Process.exit(n)` を呼んだスクリプトは `n`（0〜255）で終わる。1、2、3 は `Process.exit` からも生じうるので、スクリプトを実行する道具は、標準エラー出力に `benitoite` の形式の報告があるかどうかでこれらを区別できる。

`--report=json` を指定しない `run` と `check` では、診断、実行時エラー、`main` が返した `Result.Error` のメッセージ、使い方の誤りは、標準エラー出力に出る。標準出力には、スクリプトが書いたものだけが出る。標準出力か標準エラー出力の読み手がいなくなると（閉じたパイプ）、プログラムは実行時エラーで止まり、終了状態は 1 になる。検査報告では、標準出力の単一 JSON オブジェクトの中に診断を含める。

`benitoite` はメモリに上限を設けない。上限を設けるには、`benitoite` を起動する道具（`ulimit`、コンテナ、エージェントのハーネス）を使う。

### 版と対応する形式

実行ファイルが対応する形式は、`benitoite --version=json` で調べる。必要な `formats` のキーと、使う道具が解釈できる整数の版の両方を確かめる。リリースの版だけから機能を推測しない。例えば、コミットと dirty の状態が不明なビルドは、次のように返すことがある。

```json
{
  "schemaVersion": 1,
  "kind": "version",
  "name": "benitoite",
  "version": "0.0.11",
  "unicodeVersion": "17.0.0",
  "displayWidthUnicodeVersion": "17.0.0",
  "build": {
    "commit": null,
    "dirty": null,
    "target": "aarch64-apple-darwin",
    "provenance": {"commit": "unknown", "dirty": "notCollected"}
  },
  "formats": {
    "version": [1],
    "diagnostics": [1],
    "testResults": [1, 2],
    "checkReport": [1],
    "testCheckReport": [1, 2],
    "effectLimit": [1],
    "loaderEnvironment": [1],
    "skillList": [1],
    "skillDocument": [1]
  },
  "loaderEnvironment": {
    "schemaVersion": 1,
    "mode": "always",
    "deniedPrefixes": ["DYLD_", "LD_"],
    "nameComparison": "asciiCaseInsensitive",
    "inherited": "unchanged",
    "errorKind": "InvalidInput"
  }
}
```

`unicodeVersion` は文字の分類と変換の版である。任意欄の `displayWidthUnicodeVersion` は表示の幅の版を別に示す。このビルドは常に `"17.0.0"` を出力するが、古い実行ファイルでは欠けることがある。人間向けの `--version` は二行を保つ。

`build.commit` は、Git オブジェクト ID の小文字の十六進文字列（省略しないもの）か `null` である。`build.dirty` は真偽値か `null` であり、`null` は不明を意味する。作業ツリーに変更がないという意味ではない。dirty の状態は自動では採取しない。ビルドの入力を省くと `provenance.dirty: "notCollected"` になる。不明を明示した場合を含め、入力を明示すると `"environment"` になる。コミットの由来は `"environment"`、`"git"`、`"unknown"` のいずれかである。これらはビルド時に埋め込んだ値であり、実行時の環境を観測した値ではない。入力・監視の限界・再ビルドの条件は、[ビルド情報](install.md#ビルド情報)を参照する。

`diagnostics: [1]` と `testResults` の版 1 は、`kind: "die"`、`code: null`、テストの `failure.die` を含む既存の JSON Lines 形式を指す。これらの行に `schemaVersion` や最初の版の行は追加しない。`checkReport` と `testCheckReport` は、後述する単一オブジェクトの報告を表す。`effectLimit` は、オプションの構文・集合の比較・`E0512` の契約の版であり、出力オブジェクトではない。`loaderEnvironment` は[明示した環境変数の制約](#io-とネットワークの振る舞い)を表す。`skillList` と `skillDocument` は、[埋め込み Skill の問い合わせ](install.md#インストールせずに-skill-を読む)を表す。

欄の削除、型・必須性・意味の変更、成功を判断するために新たな解釈を要する分類の追加では、該当する形式の版が変わる。無視しても意味が変わらない任意の欄は、同じ形式の版の中で追加されることがある。未知の形式・状態・エフェクト名は未対応として扱い、成功や空のエフェクト集合とは扱わない。

### 検査報告

報告する上限には、[ファイル単位のエフェクトの宣言](#ファイル単位のエフェクトの宣言)も含む。

次のコマンドは、利用者の関数を実行せずにスクリプトを検査する。

```sh
benitoite check --report=json main.bnt
benitoite test --check --report=json tests/
```

`check` には `main` が必要である。`test --check` は、テストを実行する `test` と同じ規則でファイルとテストを選び、`main` を必要としない。どちらも Benitoite のバイトコードを生成せず、VM を動かさない。既存のコンパイル時の定数評価と、外部宣言の静的な検査は行う。その静的な検査のために外部の WASM コンポーネントをコンパイルすることはあるが、インスタンス化も呼び出しも行わない。検査の成功は、後のコード生成でコンパイラの上限に収まることを保証しない。

`--report=json` はこの綴りだけを受け付け、分離した値は受け付けない。`--diagnostics=json` と併用でき、その場合も診断は報告の中にだけ現れる。`--diagnostics=text` の明示は使い方の誤りだが、診断の形式を省くことはできる。`--check` のない `test --report=json` は使い方の誤りであり、テストを実行しない。`test --check` は、指定値が既定値と同じでも、`--max-call-stack`、すべての `--wasm-*` オプション、`--allow-effects` を拒否する。`run` と `fmt` は報告を受け付けない。

コマンドのオプションの範囲内で有効な報告オプションを認識すると、それより前の誤りを含め、認識できる使い方の誤りも報告で返す。`check` の範囲はスクリプトのパスまでであり、`test` の範囲はパスの前後のオプションを含む。既知のオプションの分離した値は、その指定方法が不正な場合も走査中に消費する。このため、値がたまたま `--report=json` でも報告は有効にならない。報告オプションを認識しなければ、使い方の誤りは従来どおり標準エラー出力の文章になる。

各報告は UTF-8 の単一 JSON オブジェクトであり、末尾に LF を付けて標準出力に書く。警告、検査の誤り、使い方の誤り、捕捉した処理系の不具合を含め、標準エラー出力には重ねて書かない。テストの結果や集計の行も書かない。オブジェクトのキーの順序と JSON の空白は契約に含まれない。

| 共通の欄 | 意味 |
|---|---|
| `schemaVersion`, `kind` | `"checkReport"` と通常の `"testCheckReport"` は整数 `1`。`test --doc` の検査は整数 `2`。 |
| `producer` | `{name, version, build}`。版の問い合わせと同じ版・ビルド情報を持つ。 |
| `status` | `"ok"`、`"checkError"`、`"usageError"`、`"internalError"` のいずれか。テストの非実行の検査では `"interrupted"` も返すことがある。 |
| `complete` | 選択、すべての対象の検査、契約の抽出が成功したときだけ真。 |
| `targetsComplete` | 入口の選択やディレクトリの探索が完了したか。型検査の成否とは独立である。 |
| `executed` | 常に `false`。 |
| `requestedTargets` | `[{requestIndex, path}]`。引数の順に、0 から始まる番号と渡されたパスを、不正なものも含めて並べる。 |
| `targets` | 発見順の入口。明示した引数の順と、各ディレクトリ内のファイルの辞書順で並ぶ。 |
| `sources` | `[{sourceId, displayPath, kind, contentHash}]`。対象の順、その中ではソースファイル ID の順に並ぶ。`kind` は `"user"` か `"prelude"`。後者は埋め込まれた標準ライブラリのソースをすべて含む。 |
| `sourceSets` | `[{targetId, sourceIds}]`。対象ごとに一行あり、未検査の対象にも空のソース ID の配列を置く。 |
| `aggregateEffects` | 報告全体が完全なときだけ、`main` の Effects オブジェクト、または選んだすべてのテストのエフェクトの和集合を返す。それ以外は `null`。 |
| `diagnostics` | [診断](#18-診断)で説明する診断オブジェクトの配列。 |
| `diagnosticTargets` | 診断ごとに一つの `{diagnosticIndex, targetId}`。探索全体の誤りと使い方の誤りでは `targetId: null`。 |

すべての対象は、`targetId`、`requestIndex`、`entry`、`root`、`sourceId`、`kind`、`status`、`complete` を持つ。`entry` と `root` は表示用のパスである。入口のバイト列を保持していなければ、`sourceId` は `null` になる。main の対象は `kind: "main"` と `main` 欄を持つ。テストの対象は `kind: "tests"` と `tests` 欄を持ち、`main` 欄は持たない。

成功した `main` は `{symbol: "main", location, effects, processShellReference, shellReferenceScope}` である。`tests` の各要素は `{function, description, location, effects}` であり、宣言順に並ぶ。テストの説明を省いた場合は `null`、空の説明を明示した場合は `""` になる。`location` は `{file, start, end, label: ""}` で関数名の位置を示す。start と end は、1 から数える `line` と `column`、元のソースでの 0 から数えるバイト位置 `offset` を含む。

Effects オブジェクトは `{basis: "declaredUpperBound", expanded: [...]}` である。配列には組み込みの原子的なエフェクトの名前が、重複なく辞書順に並ぶ。本体で使わないものも含め、宣言した上限を報告する。`IO.All` は `Clock.Time`、`Console.Read`、`Console.Write`、`File.Read`、`File.Write`、`Process.Environment`、`Process.Exit`、`Process.Run`、`Random.Generate`、`State` へ展開し、Log も HTTP のどちらのエフェクトも `Assert.Check` も含まない。テストの各契約、集計、後のエフェクトの上限の比較では `Assert.Check` を保持する。`main` での `Assert.Check` の宣言は検査の誤り（`E0415`）になる。処理していない `or die` は `Process.Exit` を要する。これをすべて処理し、宣言した上限から取り除けば、報告からも取り除かれる。単独の `try` や `or return` は終了のエフェクトを加えない。

main かテストに未処理の `Failure.Fail[E]` があれば、test --check も含め、検査の誤り E0506 になる。入口の内部で処理するか、Failure.toResult で変換する。Fail は IO.All、expanded、--allow-effects が受け付ける名前に含めない。報告とエフェクト上限のスキーマの版は変わらない。

純粋な契約の検査が成功すれば `expanded: []` になる。不明なエフェクトは Effects の値全体を `null` として表し、空配列にはしない。対象の検査が失敗すれば、その `main` か `tests` は `null` になる。検査済みのファイルにテストがなければ `tests: []` になる。空のディレクトリは、`targets: []` と空の集計エフェクト集合を持つ完全な成功である。一つのファイルが失敗しても、成功した対象の契約は残るが、全体の `complete` は false、`aggregateEffects` は null になる。探索の失敗では、どの入口も検査せずに止まる。それまでに発見した対象は、`status: "checkError"`、`tests: null` の不完全な参考情報として残る。処理系の不具合や観測した中断では、後の入口が未検査のまま残ることがある。

`processShellReference` は、検査が成功したときは `"present"` か `"absent"`、未確認のテストの対象では `"unknown"` になる。main の対象では `main` の中に、テストの対象では対象そのものに、`shellReferenceScope: "checkedProgram"` とともに置く。main が `null` のときも shell の参照は未確認である。調べるのは、依存、標準ソース、関数の値、呼ばれない関数も含む検査済みプログラム全体での、標準の `IO.Process.shell` への式の参照である。`main` やテストからの到達性は調べない。取り込みだけ、ハンドラの操作名だけ、コメント、文字列、同名の利用者の関数は数えない。`"present"` はシェルが実行されることを意味せず、`"absent"` は任意のコマンドがシェルを起動できないことを意味しない。

`contentHash` は `{algorithm: "sha256", value: "<64 lowercase hexadecimal digits>"}` であり、検査が使ったものと同じソースの全バイト列を対象とする。BOM、改行、不正な UTF-8 を正規化しない。設定、依存、prelude のソースを含め、ソース表に読み込んだソースを対象にする。WASM のバイナリ、依存のハッシュの確認のためだけに読んだファイル、存在しない設定ファイル、ディレクトリの観測は含めない。全バイト列を保持していないソースには `sources` の要素を作らない。表示用のパスは、OS のパスに逆変換できる符号化ではなく、ファイルを開く指示でもない。

`t0` や `t0:s0` のような ID は、その報告の中だけで有効である。明示したパスの重複は別々の対象とソース集合になり、表示名やハッシュが同じでも統合しない。報告は後の実行のソースのバイト列を固定せず、そのハッシュも実行ファイルの信頼性の証明にはならない。

使い方の誤りでは、`complete: false`、`targetsComplete: false` とし、`targets`、`sources`、`sourceSets` は空、`aggregateEffects: null` とする。その診断は `kind: "check"`、`severity: "error"`、`code: null`、`primary: null` と、空の `secondary`、`notes`、`helps` を持つ。`kind: "check"` と `code: null` のこの組み合わせは、`status: "usageError"` の報告の中にだけ現れ、通常の診断の JSON Lines には加えない。例えば、`benitoite check --report=json` は、`requestedTargets: []` とメッセージ `"missing script path"` を返し、終了状態は 2 になる。

| 報告の状態 | 終了状態 |
|---|---:|
| `ok` | 0 |
| `checkError` または `usageError` | 2 |
| `internalError` | 3 |
| `interrupted`（テストの非実行の検査だけ） | 130 |

集計を確認済みの集合として使う前に、単一 JSON オブジェクトが完全に出力されていること、解釈できる `schemaVersion` と `kind` であること、`status: "ok"`、`complete: true`、終了状態 0 を確かめる。`--deny-warnings` で誤りにした警告があれば、報告は `checkError` になる。テストの非実行の検査で複数の失敗があれば、中断、処理系の不具合、使い方の誤り、検査の誤りの順に優先する。

出力を始める前に、報告の組み立てと直列化を終える。書き込みや flush の失敗を優先し、終了状態 1 で終える。別の報告を追記・再送しない。OS の書き込みが分割されない保証はない。初期化の失敗、報告の境界の外の失敗、失敗報告そのものの組み立て中の失敗、abort、強制終了、出力の切断では、完全な報告を保証しない。テストの非実行の検査は、各ファイルを始める前に中断を確認し、検査中は継続的に確認しない。最後のファイルの検査中の要求は、報告されないことがある。main の非実行の検査では、シグナルを OS の既定の動作に委ねる。

### 実行前のエフェクトの上限

比較には、[ファイル単位のエフェクトの宣言](#ファイル単位のエフェクトの宣言)で加わるエフェクトも含む。

スクリプトを検査して確認した後、エージェントやハーネスは、許可した原子的なエフェクトの名前を実行コマンドへ渡せる。

```sh
benitoite run --allow-effects=Console.Write,Process.Exit main.bnt
benitoite test --allow-effects=Assert.Check,File.Read tests/
benitoite --allow-effects= pure.bnt
```

最後のコマンドは空集合を許す。オプションは、[エフェクト](#10-エフェクト)にある 14 個の原子的な名前（`State` と `Assert.Check` を含む）を、任意の順にコンマで区切った一つの集合を受け付ける。名前の重複、空の要素、どの位置にある空白、未知の名前、利用者定義の名前、取り込みの別名、`IO.All`、`*` は拒否し、値の前後の空白を取り除かない。オプションは一度だけ指定できる。`check`、`test --check`、`fmt` は受け付けない。`run` のスクリプトのパスの後では、スクリプトの引数になる。

新たに検査した宣言上限は、渡した集合の部分集合でなければならない。余分な名前の許可は受け付ける。不足するエフェクトがあると、該当する関数ごとに一つの `E0512` を、その位置、不足するエフェクト、許可集合とともに出し、実行前に終了状態 2 で終える。`--diagnostics=json` では、標準エラー出力の通常の診断行になり、標準出力に承認のオブジェクトは出さない。不明な契約を比較する前に、それ以前の型やエフェクトの誤りを優先する。

`run` は、契約を比較したものと同じ検査済みプログラムをコンパイルする。エフェクトの上限を指定した `test` は、すべての入口を準備し、選んだすべてのテストの契約（`Assert.Check` を含む）を比較し、すべての入口のコンパイルと実行準備を終えてから、テストを開始する。一つでも準備に失敗すれば、どのテストも実行しない。その場合の集計は[テスト](#16-テスト)を参照する。このオプションがなければ、従来どおりファイルごとに準備して実行する。

これは静的な契約の比較である。検査後のソースを固定せず、実行時の操作も制限しない。`File.Write` を保ってパスや内容を変える変更や、`Process.Run` を保ってコマンドを変える変更は、同じ集合に収まる。入口を準備する間にファイルが変われば、テストの入口ごとに異なる依存の内容を読むこともある。すべての入力を一つのスナップショットにするわけではない。実際の操作と資源の制限には、ハーネスか OS のサンドボックスを使う。

## 3. プログラムの構造

プログラムは、スクリプトのファイルの関数 `main` から始まる。`main` は引数を取らず、`Unit` か `Result[Unit, String]` を返す。`Result.Error(message)` を返すと、メッセージを標準エラー出力に書き、終了状態は 1 になる。

ファイルのトップレベルには、`import` の宣言、省略可能な一回の[ファイル単位の `uses` 宣言](#ファイル単位のエフェクトの宣言)、その後に宣言（関数、定数、データ型、型の別名、レコード、型クラス、実装、エフェクト）をこの順に置く。実行するコードは関数の中にだけ書く。

短いラムダ（[関数とラムダ](#6-関数とラムダ)を参照する）を除き、ブロックは、`end` とブロックを開いたキーワードで閉じる。`end function`、`end if`、`end match`、`end lambda`、`end data`、`end record`、`end trait`、`end implement`、`end effect`、`end handle`、`end with`、`end lazy`、`end block` である。波括弧はなく、字下げに意味はない。文は改行で区切る。セミコロンはない。`return` の直後の物理改行は、括弧の中でも、次の行の先頭が継続用の演算子でも、常に文を終える。コメントや空行を挟んでも、この規則は変わらない。

ブロックの中では次のように書く。

- `bind name <- expression` は値に名前を付ける。名前に再び代入することはできない。
- `shadow name <- expression` は、既に見えている局所の名前を隠す名前を束縛する。既に局所の名前として見えている名前での `bind` は誤りなので、隠すことは常に明示する。`shadow` は有効な構文だが、推奨しない。意図して古い名前を隠す場合も、新しい値の意味を表す別の名前を使う。これは文書上の助言であり、警告は加えない。
- `return expression` は関数を終え、値を返す。値は `return` と同じ物理行で書き始める。値がなければ誤り（E0201）である。書き始めた後は、通常の継続の規則で複数行にできる。例えば、`return x +` の演算子の後、`return (` の括弧の中、`return f(` の引数の中、`return if condition then` の `then` の後で継続できる。短いラムダは、全体を一つの物理行に収める必要がある。
- 1 行に単独で書いた式は文である。その文がブロックの最後の文でないとき、または関数かラムダの本体の最後の文であるときは、その値は `Unit` でなければならない。ほかの値を捨てるには `bind _ <- expression` と書く。

戻り値の型が `Unit` でない関数は、`return` で終わらなければならない（またはすべての分岐が値を返す `if` か `match` で終わる）。`if` の値、`match` の分岐の値、ハンドラの節の値、`with`・`handle`・`lazy` の本体の値は、その最後の式である。`if`、`match` の分岐、ハンドラの節、`with` か `handle` の本体の中の `return` は、それを含む関数から抜ける。`lazy` の本体と `match` のガードは、`return` も `try` も含められない。ただし、そこに書いた `lambda ... end lambda` の中は除く。プレースホルダ `_` を持つ呼び出しの引数は、この除外に当たらない。

`//` は行末までのコメントを始める。宣言の前の `///` はその宣言の説明であり、ファイルの先頭の `//!` はモジュールの説明である。識別子には ASCII の英字、数字、`_` を使う。関数、値、引数の名前は小文字で始め、型、構成子、モジュール、エフェクトの名前は大文字で始める。

`record` は、引数、引数のラベル、束縛、値の参照など、小文字の名前を要する位置でも使える。宣言の位置では引き続きレコードの宣言を始める。

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

式全体の後に `${amount:.2f}`、`${number:#08x}`、`${label:>8s}` のような静的な書式を書く。名前付き引数、レコードのフィールド、パターン、ブロックの型注釈の中のコロンは式の一部であり、短いラムダの後のコロンはラムダ全体に対する書式になる。指定の順序は、任意の整列（`<`・`>`・`^`）、符号（`+`）、`#`、ゼロ埋め（`0`）、幅、精度、種別（`d`・`b`・`o`・`x`・`X`・`f`・`s`・`c`）である。幅は 1〜65535、精度は 0〜28 の ASCII 数字で書く。精度には `f`、整列とゼロ埋めには幅が必要であり、ゼロ埋めと明示的な整列は併用できない。`#` には `b`・`o`・`x`・`X` が必要である。空の書式、書式内の空白、`-` は E0262 になる。`fmt` は有効な指定を保ち、そのコロンの前の空白を取り除く。

整数の種別は Byte を含む八つの整数型、`f` は Float・Float32・Decimal、`s` は String、`c` は Character に適用する。符号とゼロ埋めには数値型が必要である。幅と整列だけなら通常の補間と同じ十四の基本型に適用できる。型の不適合は、書式と値の位置を持つ E0468 になる。ハーネスから書式付き補間を含むスクリプトを検査・実行でき、定数式も同じ規則を使う。すべての補間式を左から右へ一度ずつ評価した後、変換して連結する。

既定では数を右寄せ、ほかを左寄せにする。中央揃えで空白が余るときは右側に置く。幅には後述する既定の表示の幅を値ごとに用い、長い内容は切らない。ゼロ埋めは符号と基数の接頭辞の後に置く。負の整数は負号と絶対値の数字で表す。固定小数点の丸めは値から直接、最近接・偶数丸めで行う。精度のない `f` は Float・Float32 では小数点以下六桁、Decimal では元のスケールを保つ。`${1.5:f}` は `1.500000`、`${1.50m:f}` は `1.50` になる。精度 0 は小数点を出さない。Float 型は負のゼロを保つが、Decimal は丸めてゼロになれば符号を落とす。NaN に符号は付けず、非有限値にはゼロの代わりに空白を足す。数字は ASCII、小数点は `.`、符号と接頭辞は固定である。通常の補間と生の文字列の振る舞いは変わらない。

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

`String.displayWidth(s)` は Unicode 17.0.0 と [unicode-width 0.2.2](https://docs.rs/unicode-width/0.2.2/unicode_width/) に従う表示の幅を返す。`String.displayWidthCJK(s)` は文字列の並びの例外も含む CJK の規則を選ぶ。端末やロケールは調べない。既定では幅が曖昧な文字を通常 1 と数える。例えば `"猫"` は 2、`"e\u{301}"` は 1、`"·"` は既定で 1、CJK で 2 となる。表示の幅はスカラー値の数や UTF-8 のバイト数と異なる。

U+0000〜001F、U+007F〜009F、U+2028、U+2029 は幅 0 の境界とする。境界間の最大の部分ごとの幅を足し、どの文字列にも Integer を返す。したがって `"a\nb"` の幅は 2 になる。ANSI の列は解釈も除去もしない。`"\u{1b}[31m"` の幅は 4 である。結果はカーソルの移動や行の最大幅を表さない。列を揃えるときは制御文字のない一行を使う。

| 関数 | 純粋なシグネチャ | 振る舞い |
|---|---|---|
| `String.displayWidth` / `String.displayWidthCJK` | `function(s: String) -> Integer` | 既定 / CJK の表示の幅 |
| `String.displayWidthPadStart` / `String.displayWidthPadEnd` | `function(s: String, width: Integer) -> String` | 既定の表示の幅へ達するよう先頭 / 末尾に U+0020 の空白を足す |
| `String.displayWidthPadStartCJK` / `String.displayWidthPadEndCJK` | `function(s: String, width: Integer) -> String` | CJK の表示の幅を使って空白を足す |

四つの空白埋めの関数は内容を保ち、`width <= 0` または既に十分な幅があれば元の値を返す。確保に成功すれば、対応するモードで結果の幅は `max(元の幅, width)` になる。大きな動的指定は文字列のバイト上限を超え、確保の前にリソースの報告で停止しうる。この幅の契約は U+0020 の追加に対するものであり、任意の連結で幅が加法的になるとは限らない。

```benitoite
import Benitoite.Unofficial.IO.Console
function main() -> Unit uses Console.Write
  Console.writeLine("[" + String.displayWidthPadStart(s: "猫", width: 4) + "]")
  Console.writeLine("[" + String.displayWidthPadEndCJK(s: "·", width: 4) + "]")
end function
```

```output
[  猫]
[·  ]
```

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

`=` と `<>` は、*等値の型*の値を比較する。関数型、等値比較を持たない組み込みの不透明型（IOError、NetworkError、Reference、Lazy、Task、リソース、Regex.Pattern など）、外部の型を含む型は比較できない。リスト、マップ、集合、Option、Result、レコード、データ型は内容を比較する。`<`、`<=`、`>`、`>=` は数値型、Character、String で使える。Float と Float32 の比較は IEEE 754 に従う。NaN は自分自身を含めて何とも等しくないため、対応する isNaN 関数で検出する。

演算の対象は左から右へ評価する。

## 6. 関数とラムダ

関数は、引数の型と、`->` の後に戻り値の型を宣言する。個別の `uses` と適用されるファイル単位の `uses` の和が空のとき、関数は純粋である。

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

### ブロック式

`block ... end block` は文の並びを一つの式にする。最後の式が値となり、空のブロックと最後が束縛のブロックの型は Unit となる。局所束縛の範囲は内側に限られ、エフェクトは各文の和となる。return の境界は作らず、`return` と `try ... or return` は囲む関数かラムダを作用先とする。lazy の本体やガードでの return と try の禁止は、その内側の block にも適用する。構築器を内側で宣言して操作できるが、最後に返すのは copy などの通常値とする。

```benitoite
import Benitoite.StringBuilder
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind text <- block
    bind builder: StringBuilder <- StringBuilder.new()
    StringBuilder.appendAll(builder: builder, texts: ["hello", " world"])
    StringBuilder.copy(builder)
  end block
  Console.writeLine(text)
end function
```
```output
hello world
```

`block` は予約語であり、ドットの後の名前や引数ラベルにも使えない。既存の同名の識別子は改名する。

### 穴とパイプ

呼び出しの直接の引数の `_` は、不足する引数を取る関数を作る。`Integer.maximum(a: _, b: 0)` の型は `function(a: Integer) -> Integer` である。各穴は対応するパラメータ名を引き継ぎ、複数の穴は記述順に並ぶ。`between(high: _, value: 3, low: _)` は `low, high` ではなく `high, low` を取る。位置構成子の直接の穴は、元の位置の名前を引き継ぐ。`Pair(_, "one")` は `arg1` を取る。呼ぶ関数の式と固定した引数の式を評価するのは、生成した関数を作るときではなく、その関数を呼ぶときである。これらの式の中の `return` と `try` は生成した関数に作用する。`resume` はこの境界を越えられない。

直接の穴がない場合、パイプの右辺の呼び出しは、左の値を宣言上の最初のパラメータとして受け取る。`xs |> List.map(f: action)` がその例である。関数のパラメータが二つ以上なら、残りの明示引数すべてにラベルを付ける。最初のパラメータを明示的に再び指定すると重複となる。パイプが別の空いたパラメータを探すことはない。評価順は、左辺を一度、次に右辺の呼ぶ関数の式、次に明示引数をソースの記述順である。

`xs |> List.map(xs: _, f: action)` のように直接の穴がある場合は、パイプは生成した関数を一引数で呼ぶ。括弧で囲んだ右辺も、関数値として一引数を受け取る。二つの穴には二つの引数が必要であり、パイプがその関数を自動で再び部分適用することはない。

### 型付きの失敗

`Benitoite.Unofficial.Failure` を明示的に取り込む。`Failure.raise(error)` の型は `function(error: E) -> T uses Failure.Fail[E]` である。エラーには任意の値型を使え、Show も equality も要らない。型引数を取るエフェクトは標準の Fail だけである。uses の一覧には、`Failure.Fail[String]` のように修飾した名前と型引数を書き、ほかのエフェクトとコンマで区切る。

```benitoite
import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.Console

function recovered() -> Integer
  return handle Failure.raise(error: "bad") with
    case Failure.raise(error) -> String.characterCount(error)
  end handle
end function

function main() -> Unit uses Console.Write
  Console.writeLine(Integer.toString(recovered()))
end function
```

```output
3
```

失敗の節は、handle 全体の結果を返す。`resume` は使えず、一つの handle に失敗の節と通常の操作の節を混ぜられない。両方が要るときは handle を二重にする。最も近い失敗の節が捕捉し、実行時にエラーの型でハンドラを選ぶことはない。節で別の型の失敗を明示的に発生させ、外側の handle で捕捉することはできる。

一つのソースのエフェクト集合に含められる失敗型は高々一つであり、不変である。異なる失敗型の合流は E0514 を報告する。宣言したシグネチャで明示的な Fail と並ぶエフェクト行は、コールバックと戻り値の関数型の内部も含め、失敗を除外する。この内部の条件を `Rest excludes Failure.Fail` と表示し、関数値、高階の呼び出し、モジュールの境界を通して保つ。条件はシグネチャから求め、本体からは求めない。handle の残りの行にこの条件がなければ E0515 を報告する。List.map のような普通の行は失敗を伝播できる。失敗を捕捉しても、返す関数に残る潜在的なエフェクトは取り除かれない。main やテストが戻る前に失敗を処理する。

`Failure.fromResult(result)` は、Ok の値を返すか、Error の元の E を使って失敗を発生させる。`Failure.toResult(body)` は、失敗のハンドラの内側で body を一度呼び、正常な戻り値を Ok に包み、発生した失敗を Error として返す。コールバックの型は `function() -> T uses Failure.Fail[E], Rest`、結果は `Result[T, E]` である。残るエフェクトは、Fail を除外する Rest である。どちらの変換にも Show と equality は要らない。E を推論できなければ、束縛かコールバックの型に注釈を加える。呼び出しに明示的な型引数は書けない。

```benitoite
import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.Console

record Invalid
  value: Integer
end record

function convert(value: Integer) -> Integer uses Failure.Fail[Invalid]
  return Failure.fromResult(if value = 2 then Result.Error(Invalid(value: value)) else Result.Ok(value) end if)
end function

function main() -> Unit uses Console.Write
  bind result: Result[List[Integer], Invalid] <- Failure.toResult(body: lambda()
    return List.map(xs: [1, 2, 3], f: convert)
  end lambda)
  match result with
    case Result.Ok(_) -> Console.writeLine("all succeeded")
    case Result.Error(error) -> Console.writeLine("failed at " + Integer.toString(Invalid.value(error)))
  end match
end function
```

```output
failed at 2
```

最初の失敗で map は止まり、後の要素も処理しない。ほかのエフェクトと、既に終えた外部の作業は残る。入れ子の with は、toResult が戻る前に内側から外側へ一度ずつリソースを解放する。解放の失敗は実行時エラーとして止まり、Error には変換しない。body が return や try で Result を返した場合も、正常な戻り値は常に Ok に包む。

子タスクごとにその内側で失敗を変換し、既存の Task API を通じて Result を返す。親の非再開型の失敗ハンドラを使う子は、引き続き R0502 で止まる。lazy の本体は純粋でなければならない。本体の内部で toResult を使って失敗を処理すれば Result を記憶できる。エフェクトを持つ計算を遅らせる場合はラムダを使う。この変換は die、Process.Exit、実行時エラー、資源の上限、中断、取り消し、外部のトラップを捕捉しない。

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

Character の範囲は、Unicode スカラー値の全域を覆える。`case '\u{0}'..'\u{10ffff}' ->` 一つ、または `'\u{0}'..'\u{d7ff}'` と `'\u{e000}'..'\u{10ffff}'` の二つの範囲で、包括的な最後の分岐なしに網羅できる。レコード、構成子、リストの内部にも同じ規則を適用し、全域の範囲は bind のパターンにも使える。その後の包括的な分岐は E0602、コンマで並べた冗長な選択肢は E0608 で拒否する。ガード付きの分岐は網羅性を成立させない。Integer の -9223372036854775808 から 9223372036854775807 までを一つまたは隣接する複数の区間で覆う場合も網羅的となり、後続の包括的な分岐は E0602 となる。穴とガード付きの区間は別途覆う必要があり、E0601 は具体的な未被覆整数を示す。未被覆の文字に対して E0601 は具体的なスカラー値を示す。例えば `'a'` だけの match なら `'\u{0}'` となる。

```benitoite check
function scalarHalf(c: Character) -> Integer
  bind '\u{0}'..'\u{10ffff}' <- c
  return match c with
    case '\u{0}'..'\u{d7ff}' -> 0
    case '\u{e000}'..'\u{10ffff}' -> 1
  end match
end function

function main() -> Unit
  bind _ <- scalarHalf('\u{e000}')
end function
```

```benitoite check
function sign(n: Integer) -> Integer
  return match n with
    case -9223372036854775808..-1 -> -1
    case 0..9223372036854775807 -> 1
  end match
end function

function main() -> Unit
  bind _ <- sign(0)
end function
```

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

### 不透明型

不透明型（opaque type）は、その宣言モジュールだけが構成子を使える型である。@opaque のデータ型とレコード、IOError、NetworkError、Reference、Lazy、Task、リソース、Regex.Pattern などの組み込みの型、外部の型を含む。不透明であることだけでは等値比較を禁じない。@opaque のデータ型とレコードは、内容の等値比較の規則に従う。

`public data`、`public record`、またはパッケージ内の公開宣言の前に `@opaque` を置くと、型を公開し、表現を宣言モジュール内に隠す。`@opaque()` も使える。型パラメータと @deprecated にも対応する。引数は E0818（文字列以外は E0220）、重複は E0803、ほかの種類の宣言は E0802、非公開の宣言は E0820 となる。@extensible または @external との併用は、後の属性の位置で E0819 となる。

宣言モジュールの外では、同じパッケージの別モジュールでも、構成子の参照・呼び出し・値・部分適用・パターン、レコードの構築・更新・パターン、自動生成のフィールドアクセサを E0340 で拒否する。公開の作成関数と検査関数を使う。取り込みと型の別名を経由しても元の所有モジュールを保つ。型注釈、型引数、値の受け渡し、変数の束縛、ワイルドカードの照合は使える。

内部表現に非公開の補助型を使えるが、公開の関数とメソッドのシグネチャは通常の可視性の検査（E0329）に従う。この属性は公開の作成関数を検証せず、公開関数が内部表現を返すことも禁じない。等値とキーの制約は内部構造に従い、網羅性の判定には全構成子を使う。既存の公開型へ後から付けると、構築・更新・検査・パターン照合をする利用側を壊すことがある。

### 拡張可能な型

引数のない属性 `@extensible` を `data` か `record` の宣言の前に置く。`public` または `public(package)` があれば、その前に置く。非公開の宣言にも使え、`@deprecated` と併用できる。`@extensible()` も同じ属性として受理し、フォーマッタは括弧を保つ。引数があれば `E0817`（文字列でない引数は `E0220`）、重複は `E0803`、ほかの種類の宣言への指定は `E0802` を報告する。個々の構成子の前には属性を置けない（`E0201`）。

定義したパッケージの中では、宣言済みの構成子をすべて覆うパターンを網羅的と判定できる。外では、ソースに書く `match` に、ガードのない変数か `_` のパターンで将来の形も覆う分岐を要する。`Other` という名前の構成子も既知の構成子であり、将来の形を覆わない。ガード付きの分岐は網羅性に数えない。この規則は、`Result`、`Option`、リスト、レコードのフィールドの中や、型の別名を通した位置にも適用する。全既知構成子の後でも将来の形の分岐は有効である。ガードのない `_` の後の分岐は、引き続き到達不能である。

パッケージの境界は `public(package)` と同じである。起点のスクリプトと根のモジュールは一つのパッケージ、標準ライブラリと prelude は別の一つのパッケージを成し、各依存の内部モジュールはその依存に属する。同じパッケージの別のモジュールへ型を取り込んでも、外部からの使用にはならない。

標準ライブラリは、失敗型 `IOErrorKind`、`NetworkErrorKind`、`Json.ParseError`、`Json.Codec.ConversionError`、`Csv.ParseError` を拡張可能と指定する。`Result` と `Option` 自体は閉じた型のままである。中身を変数で束縛する `Result.Ok(value)` と `Result.Error(error)` で、両方の場合を覆える。`String` の失敗値には通常の文字列パターンの規則を保つ。不透明な `IOError` と `NetworkError` には、照合できる構成子がない。

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

トップレベルの定数評価は、評価した値だけでなく、直接参照する定数の情報を保持する領域も予算に数える。依存する定数が多い入力は、0.0.8 より早く評価上限（E0435）へ達する場合がある。

標準の Regex.compile の直接呼び出しでは、既知の定数の source も検査する。構文の不正は E0457、実行時と同じコンパイル制限は E0458 となる。取り込みの別名も標準の束縛を参照する。この検査によってトップレベルの const 内で Regex.compile を使えるようにはならない（E0433）。局所の bind の値を伝播したり、任意の純粋な関数を評価したりはしない。

Scope.checkHost、Scope.checkPath、Scope.checkEndpoint の直接呼び出しも、既知の不正な引数を拒否する。不正なパターンは E0459、対象は E0460、ポートの端点や 0〜65535 外のポートは E0461、条件に属さない対象は E0462 となる。ほかの引数が動的でも、既知の部分を検査する。Endpoint では文字列二つが既知ならホストの所属を、整数三つが既知ならポートの所属を検査する。拒否する呼び出しは、未知の引数がどの値でも Result.Error を返す。[Scope](#scope)に表記と保証を示す。

動的な引数、局所の関数値、部分適用、プレースホルダ、高階の呼び出し、パイプは実行時に検査する。追加検査の評価予算はプログラム全体で 64 MiB である。Regex のコンパイルの暫定予算は、パターンごとの source が 1 MiB、合計 8 MiB で、同じ入力の結果を再利用する。この検査予算を超えた場合は実行時の検査へ残し、E0458 にはしない。受理した呼び出しも Result[Regex.Pattern, String] を返し、実行時にコンパイルする。不正なパターンの Result.Error をテストなどで調べる場合は、通常の関数の引数を経由させる。

```benitoite
import Benitoite.Trait
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.Regex
function parse(source: String) -> Result[Regex.Pattern, String]
  return Regex.compile(source)
end function
function main() -> Unit uses Console.Write
  Console.writeLine(Trait.Show.show(Result.isError(parse("["))))
end function
```


```output
true
```



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

*エフェクト*は、関数が純粋な計算の外で行ってよい操作の種類を名指す。関数の有効な `uses` は、直接または呼ぶ関数を通じて行うすべてのエフェクトを挙げる。トップレベルの関数では、個別の `uses` と、存在する場合のファイル単位の宣言の和になる。ラムダは本体からエフェクトを推論する。

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
| `Log` | 構造化ログの事象。Console.Write と IO.All から独立 |
| `State` | プログラムの中の可変のセルと並行のタスク |
| `Assert.Check` | テストでの期待の確かめ |
| `IO.All` | `Console`、`File`、`Process`、`Clock`、`Random`、`State` のすべて（Log とネットワークのエフェクトは含まない） |

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

### ファイル単位のエフェクトの宣言

ファイルは、取り込みの後、ほかの宣言の前に、一回だけ `uses Console.Write, Log` のような宣言を置ける。本体が何も操作しなくても、main、@test、生成された関数を含むすべてのトップレベルの関数へ加える。関数型、ラムダ、trait/implement のメソッド、定数、ハンドラの節には加えない。純粋なコールバックと Property の補助は、この宣言のない別ファイルへ置く。doc の例は独立したモジュールであり、外側のファイルの宣言を継承しない。

ハーネスは、成功した `check --report=json` の `targets[0].main.effects.expanded` を合併済みの宣言上限として示す。単一の JSON オブジェクト全体、理解できる schemaVersion と kind、status: "ok"、complete: true、終了状態 0 を確認してから使う。失敗や不明を空集合とせず、報告だけで実行を許可しない。通常の check は標準出力に何も書かない。run --allow-effects とテストの同じオプションは合併済みの上限を比較し、E0512 は不足の原因となったファイルの宣言も示す。main 内のハンドラはファイルの宣言を取り除かないため、本体が全操作を処理しても利用者のエフェクトや Fail を加えれば入口の規則に違反する。宣言を外すか main を別ファイルへ移す。共有の IO.All の W0501 は関数ごとに出し、ファイルの宣言の自動編集は付けない。個別の IO.All の編集ではファイル由来の効果を考慮する。

### 構造化ログとソース位置

`Log` と `SourceLocation` は prelude に含む非公式のモジュールである。 明示的に取り込む場合は Benitoite.Unofficial.Log と Benitoite.Unofficial.SourceLocation を使う。`Log.debug`、`info`、`warn`、`error` は `message: String`、`attributes: List[Log.Attribute]`、`location: SourceLocation.Location` を明示的に取り、Unit を返し Log を使う。操作は `Log.emit(record: Log.Record)` と `Log.enabled(level: Log.Level)` の二つである。`Log.Level` は Debug、Info、Warn、Error の順である。Error のログも実行を終了させない。

```benitoite check
function main() -> Unit uses Log
  if Log.enabled(Log.Level.Debug) then
    Log.debug(message: "starting", attributes: [Log.attribute(key: "count", value: 3)], location: SourceLocation.here())
  end if
  Log.info(message: "ready", attributes: [], location: SourceLocation.here())
end function
```

`SourceLocation.here()` は純粋な零引数の直接呼び出しであり、書いた場所の位置へ展開する。行と列は 1 始まりの Unicode の位置、file は表示用のパスであり、絶対パスとは限らない。ラッパー内に書けばラッパーの位置となるため、呼び出し側の位置を保つには Location を明示的に受け取る。関数値、穴、パイプは E0467 となる。引数の個数やラベルの誤りは通常の呼び出しの診断を優先する。通常のレコード `Location(file: ..., line: ..., column: ...)` も作れる。SourceLocation の import 別名は使えるが、Log の as は E0339 となる。追加した prelude 名と衝突する利用者側の名前を確認する。

捨てるレベルであっても、引数をソース順に一度ずつ先に評価する。重いメッセージの作成は Log.enabled で囲む。属性の順序とキーの重複を保つ。Log.attribute は Log.ToLogValue を使い、String、Boolean、幅付きの整数と浮動小数点数に標準実装がある。任意のレコードやコレクションを Show で暗黙に変換しない。

未処理の Log は既定のロガーが受け、Info 以上を stderr へ `level=INFO source="app/Main.bnt:12:3" message="ready" attr."count"=3` と LF で出力する。制御文字、引用符、バックスラッシュはエスケープする。時刻、色、ソートは加えない。直接方式と要求方式は同じ書式と stderr のバッファを使い、出力・flush の失敗は通常の IO の失敗に従う。Log.enabled は選択したハンドラの閾値に従う。

Log.withAttributes は共通属性を先頭へ加え、両操作を外側へ送り直す。Log.withTextLogger は minimum と body を取り、Log を処理して Console.Write を要する。Log.withSinks は sinks と body を取り、両操作を処理し、条件に合う `(minimum, sink)` の組をリスト順に一度ずつ呼ぶ。失敗は後続の sink より前に伝播し、空のリストは全事象を捨てる。sink の引数名は record であり、そのエフェクトは結果に残る。独自ハンドラも Log を取り除くには両操作を処理する。

Log は IO.All、Console.Write、HTTP から独立している。宣言上限に残る場合は uses Log と、`--allow-effects` の正規名 Log を明記する。例は `benitoite run --allow-effects=Log script.bnt` である。完全なハンドラで Log を取り除いても、出力側の宣言エフェクトは残る。検査報告は未使用の宣言も含む上限を示し、レベルが無効であることから許可を推定しない。

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

操作の値型のパラメータには、型クラスと組み込みの制約を付けられる。例えば `function render[T: Trait.Show](value: T) -> String` と書く。呼び出し側が実装を選び、ハンドラの節では、呼び出し側のどの型に対しても宣言したメソッドを使える。上位の型クラスを含め、複数の制約は `&` でつなぐ。制約によって公開の引数が増えることはない。操作は型構築子パラメータ、エフェクト変数、独自の `uses` を宣言できない。

制約付きの操作は、関数値として保存し、`_` で部分適用し、`|>` の右辺に使える。関数型には宣言した公開のパラメータと操作のエフェクトだけを保つ。節内のラムダは、上位の型クラスを含む宣言した制約を捕捉できる。入れ子の節はそれぞれの制約を保つ。名前付き引数はソース順に一度ずつ評価し、その後で宣言順へ並べる。

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

Functor2、Applicative2、Monad2 は、`F[_, _]` と書く二引数の型構成子を受け取る。F[A, X] の第一の型を写し、第二の型 X を保つ。Applicative2 は Functor2 を、Monad2 は Applicative2 を含む。三クラスとも Result の標準実装を持ち、名前を使うには Benitoite.Trait を明示的に取り込む。

```benitoite
import Benitoite.Trait
import Benitoite.Unofficial.IO.Console

function twice[F[_, _]: Trait.Monad2, X](x: F[Integer, X]) -> F[Integer, X]
  return Trait.Functor2.map(x: x, f: lambda(value) return value * 2 end lambda)
end function

function main() -> Unit uses Console.Write
  bind result: Result[Integer, String] <- twice(Result.Ok(3))
  Console.writeLine(Integer.toString(Result.unwrapOr(r: result, fallback: 0)))
end function
```


```output
6
```


| クラス | メソッドのシグネチャ（Benitoite.Trait 内） |
|---|---|
| `Functor2[F[_, _]]` | `function map[A, B, X, effect E](x: F[A, X], f: function(value: A) -> B uses E) -> F[B, X] uses E` |
| `Applicative2[F[_, _]: Functor2]` | `function pure[A, X](x: A) -> F[A, X]`; `function apply[A, B, X, effect E](fs: F[(function(value: A) -> B uses E), X], x: F[A, X]) -> F[B, X] uses E` |
| `Monad2[F[_, _]: Applicative2]` | `function flatMap[A, B, X, effect E](x: F[A, X], f: function(value: A) -> F[B, X] uses E) -> F[B, X] uses E` |

Result の map は Result.map、flatMap は Result.andThen に委ね、pure は Ok を返す。X を推論できない pure には、`bind value: Result[Integer, String] <- Trait.Applicative2.pure(3)` のように結果の型を付ける。apply は fs の Error を優先し、次に x の Error を返す。両方 Ok のときだけ包まれた関数を一度呼ぶ。引数の式はソース順に評価する。`Result[(function(value: A) -> B uses E), X]` の関数型を囲む括弧は、効果行と第二の型引数を分けるもので、fmt も保つ。

成功値を第一の引数に置く利用者定義の二引数データ型も、同じクラスを実装できる。メソッドは値としても使え、継承したメソッドは上位クラスの辞書を使う。メソッドの型が一致するだけでは、任意の実装の法則は保証しない。完全適用した透明な別名は元の型へ展開する。裸の別名を型構成子として渡したり、独立した辞書を与えたりはできない。型構成子は部分適用できないため、Result を一引数の Monad や Traversable の関数へ渡せない。

具体的なコンテナが既知なら List.map/fold、Option.map/andThen、Result.map/andThen/mapError を使い、汎用関数には必要最小のクラスを要求する。andThen/flatMap は成功値から同じエラー型の計算を続ける。異なるエラー型は mapError でそろえる。try … or return は失敗を返し、or die は実行を終え、Failure.toResult は型付き Fail を捕捉して Result を返し、囲むエフェクト上限からその Fail を除く。表示と比較は意味で選ぶ。数値の toString と Show、組み込みの Float 比較と Order[Float] は置き換え可能ではない。

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

実行するのは、選んだ入口のファイルで宣言したテストだけである。取り込んだモジュールのテストは加えない。ファイルを直接指定すると、その親ディレクトリを取り込みの根にする。ディレクトリを指定して発見したファイルは、指定したディレクトリを共通の根とし、下位のパッケージの根は除く。重複して明示したパスは別々の入口のままにする。`test --check` の非実行の検査も同じ規則を使う。

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

検査の誤りがあるファイルは実行しない。その診断は標準エラー出力に出る。`--allow-effects` がなければ、ほかのファイルのテストは実行する。`benitoite check` は `main` のないファイルに誤りを報告する。テストのファイルを実行せずに調べるには、`benitoite test --check <path>...` を使う。成功時は標準出力に何も書かず、診断は選んだ形式で標準エラー出力に出す。`--report=json` を加えると、選んだテストの契約を含む[検査報告](#検査報告)になり、テストの結果や集計の行は出さない。

`--diagnostics=json` のとき、テストを実行する `test` は標準出力に 1 行に一つずつ JSON のオブジェクトを書く。テストごとに `"kind": "test"` のオブジェクトを一つ書き、その欄は `file`、`name`、`function`、`location`、`outcome`（`"passed"` か `"failed"`）、`failure`、`stdout`、`stderr` である。最後に、`"kind": "testSummary"` と、数 `passed`、`failed`、`filesNotRun`、および `interrupted` を持つオブジェクトを一つ書く。`failure` は `reason` と `message` を持つ。理由は、`"assert"`（確かめの失敗。`primary`、`trace`、および `Assert.equal` と `Assert.notEqual` では値 `left` と `right` を持つ）、`"error"`（テストが `Result.Error` を返した）、`"runtime"`（実行時エラー。実行時エラーの報告の欄を持つ）、`"exit"`（テストが `Process.exit` を呼んだ、または `or die` で止まった。`exitCode` を持ち、`or die` では診断オブジェクトを `die` にも含む）のどれかである。理由が `"assert"`、`"runtime"`、`"exit"` の失敗は、`notes` も持つ。`notes` は文字列の配列であり、止まる途中のリソースの解放の失敗を含む。検査の診断は標準エラー出力に出る。

`--allow-effects` があれば、すべての入口の準備を終えてからテストを開始する。検査の誤り、エフェクト集合の不足、コンパイルの上限に当たると、実行全体を終了状態 2 で拒否する。探索が完了していれば、JSON の出力には `kind: "test"` の行がなく、次のような集計だけになる。

```json
{"kind":"testSummary","passed":0,"failed":0,"filesNotRun":2,"interrupted":false}
```

この例では二つの入口を選び、どちらも開始しなかった。`filesNotRun` は、誤りのある入口だけでなく、拒否により実行しなかったすべての入口を数える。テストのない入口や、重複して明示したパスも含む。テキストの集計では `; 2 files not run` と書き、`FAILED` とする。準備が観測した中断か処理系の不具合で終わり、選んだ入口が分かっている場合も、集計は同じ非実行数を使う。中断なら終了状態 130 と `interrupted: true`、処理系の不具合なら終了状態 3 になる。探索の失敗、使い方の誤り、対象を確定できない外側の失敗では、集計を出さない。空の選択の成功では、0 passed、0 failed、`filesNotRun: 0` を返すことがある。読み手は `passed` と `failed` だけでなく、終了状態、集計の有無、`filesNotRun`、`interrupted` を確かめる必要がある。

テストを実行する `test` の終了状態は、すべてのテストが通れば 0、テストが失敗すれば 1、検査の誤り、エフェクト上限による拒否、コンパイルの上限、読めないファイル、使い方の誤りでは 2、処理系の不具合では 3、中断されたときは 130 である。複数が当てはまるときは、130、3、2、1 の順で最初のものを使う。出力の失敗では 1 になる。実行しない `test --check` は、JSON の報告の有無にかかわらず、[非実行の検査の状態](#検査報告)を使う。

### 文書の例

`benitoite test --doc <path>...` は、選択した入口ファイルの /// と //! の例も実行対象に含める。各入口では通常のテストを先に実行し、次に例をソース順に実行する。取り込んだモジュールや埋め込みの標準ライブラリの文書は再帰的に集めない。対象の選択、ディレクトリの根、パッケージ境界、明示した重複は通常のテストと同じである。

各例は独立したモジュールである。取り込み、宣言、main または @test、uses を明示する。入口の language/dependency の環境と取り込みの根は継承するが、取り込みと非公開の宣言は継承しない。通常のモジュールを取り込み、不透明型の境界も含めて公開 API を確かめる。main を持つ元ソースは、その例から取り込めない（E0320）。独立した例か、取り込めるライブラリのモジュールを使う。診断の位置は元コメントを指す。

| フェンスの指定 | 振る舞い |
|---|---|
| `benitoite test` | 例の @test 関数を検査・実行する。Assert は通常どおり使える。 |
| `benitoite check` | 関数を実行せず型とエフェクトを検査する。 |
| `benitoite error` | 静的な拒否と、直後の diagnostic フェンスを要求する。期待の各非空行が診断内に必要で、少なくとも一行は既知の E コードを含む。 |
| `benitoite` | main を検査・実行する。直後の output フェンスと UTF-8 の標準出力を末尾の改行まで一致させる。任意の stderr フェンスも完全一致で、省略時は空を要求する。 |

無指定と text のフェンスは無視する。未対応の Benitoite の印、期待の欠落、閉じないフェンスは E0260 となる。コメントの例は files ブロック、隠し行、プロンプト、非零の終了状態の期待に対応しない。通常の test はこれらを実行用に解析しない。

実行前に、全入口と実行する全例を準備し、--allow-effects も照合する。許す集合は通常のテストと test/run の例を覆う。check/error は実行の許可を追加しない。各実行はヒープ・タスク・リソースの新しい状態と空の標準入力を使い、標準出力と標準エラー出力を捕捉する。静的なエフェクト上限は OS の隔離を行わない。

`test --doc --check` は四モードを検査するが、テストや main を実行せず、出力も比較しない。--report=json を加えると testCheckReport の版 2 を返す。版 2 は通常の Target.tests を保ち、docExamples と ignoredDocBlocks を加える。各例は id（path:line:doc:index）、mode、元の location、仮想入力の sourceId、status、complete、effects、tests、expectedDiagnosticCodes、observedDiagnostics を持つ。不明な配列と効果は null、成功した空の値は空配列とする。期待した拒否は例の成功として observedDiagnostics だけに残す。想定外の拒否や診断の不一致は対象と報告を不完全にし、checkError と終了状態 2 にする。sourceSets は元コメントと仮想入力を含み、diagnosticTargets は docExampleId で例の診断を識別する。

--doc --diagnostics=json の実行は testResults の版 2 を使う。docExample 行は id/mode/location/outcome/stdout/stderr/failure/tests を持つ。続く docSummary は発見した test/run/check/error の数と ignoredBlocks を持ち、最後に testSummary を書く。最終の成功・失敗数は、通常のテスト関数と完了した例を合計する。複数のテストを含む例も一件と数える。診断や出力の不一致はその例を失敗として終了状態 1 に数え、後の例を続ける。例がない場合も、零件の成功として受け付ける。

formats.testCheckReport と formats.testResults に [1,2] の対応があるかを問い合わせる。--doc がない場合は、元の JSON Lines を含め版 1 を保つ。版 1 の読み手は --doc を付けない。JSON Lines に schemaVersion や先頭の版の行は加えない。--check は実行結果や集計の行を書かず、既存のオプションの競合も誤りのままである。

### 純粋な性質の試行

`Benitoite.Unofficial.Test.Property` を取り込むと、純粋な生成器、縮小器、上限付きの性質の試行を使える。これらは通常のライブラリ関数である。一つの @test から Property.check を呼び、結果を照合し、整形した String のエラーを返す。test --check は型とエフェクトだけを検査し、生成器も性質も実行しない。

```benitoite test
import Benitoite.Unofficial.Test.Property

@test("integer addition agrees with multiplication")
function addition() -> Result[Unit, String]
  bind gen <- try Property.integer(low: -100, high: 100)
  bind config <- Property.Config(seed: 17, trials: 100, size: 8, maxShrinks: 100, maxShrinkWork: 10000)
  bind result <- Property.check(config: config, gen: gen, shrinker: Property.shrinkInteger(), property: lambda(value)
    return if value + value = value * 2 then Result.Ok(()) else Result.Error("addition disagrees") end if
  end lambda)
  return match result with
    case Result.Ok(_) -> Result.Ok(())
    case Result.Error(failure) -> Result.Error(Property.formatFailure(failure: failure, show: lambda(value) return Integer.toString(value) end lambda))
  end match
end function
```

Gen[T] は、`run: function(generator: Random.Generator, size: Integer) -> Pair[T, Random.Generator]` を持つ公開レコードである。Shrinker[T] は `candidates: function(value: T) -> ShrinkStep[T]` を持つ。生成器を手で書く場合は Benitoite.Unofficial.IO.Random を取り込み、返された乱数の状態を次の抽選へ渡す。両コールバックと性質は純粋でなければならず、Assert、IO、型付き Fail、終了を実行できない。実行時エラーと中断はそのまま伝播し、反例には変換しない。

Config は、任意の Integer の seed、1〜10000 の trials、0〜10000 の size、0〜100000 の maxShrinks、0〜1000000 の maxShrinkWork を受け付ける。両端を含み、五つのフィールドをすべて指定する。小さな例の maxShrinkWork は暫定で 10000 を推す。最終の性能測定で確認する。不正な設定は、コールバックを一度も呼ばず CheckFailure.InvalidConfig(String) を返す。各試行には同じ size を渡す。Gen.run を直接呼ぶ場合は、保持する関数の size の契約に従う。組み込みの string、list、map の生成器には 0〜10000 の size を要する。

生成器には constant(value)、map(gen, f)、both(left, right)、integer(low, high)、boolean()、float()、string()、list(element)、option(element)、stringMap(value) がある。Result を返すのは integer だけである。境界が逆なら誤り、同じ境界なら乱数の状態を進めない。Integer の全域にわたる場合も両端を含む。整数の抽選は意図的にゼロと両端へ偏らせており、一様性を約束しない。Float は [-1, 1] の有限値で、ゼロと ±1 の分岐を持つ。文字列には有効な Unicode スカラー値を使う。文字列とリストの長さは 0〜size である。stringMap は 0〜size 回キーと値を生成し、重複キーでは最初の値を残して再試行しない。入れ子の生成器にも同じ size を渡すため、これは総確保量の絶対的な上限ではない。Option は確率 1/4 で None を選ぶ。

shrinkInteger、shrinkFloat、shrinkBoolean、shrinkString は引数を取らない。shrinkList(element)、shrinkOption(element)、shrinkStringMap(value) は要素の縮小器を取り、変化のない候補と重複する候補を除くため要素型に equality を要する。整数の候補はゼロから始め、ゼロへ向かって半分にした値を並べる。最小の Integer でも桁あふれしない。Float の候補はゼロと有限の半分である。文字列とリストは、空、幅を半分にしていく連続範囲の削除、要素一つずつの順に試す。Map はキー順に削除した後、キー順に値を縮小する。Option は None を試してから中身を縮小する。map した Gen には Shrinker を別に与える。逆写像は推測しない。手書きの Gen、Shrinker、check 自体には equality は不要であり、関数値も扱える。

ShrinkStep[T] は、純粋な一段を Done、Yield(T, function() -> ShrinkStep[T])、Skip(function() -> ShrinkStep[T]) で表す。続きへ進むときだけ保持した継続を呼ぶ。`mapSteps[A, B](steps: ShrinkStep[A], f: function(value: A) -> B) -> ShrinkStep[B]` は候補を写し、Skip を保ち、継続を遅延する。`appendSteps[T](left: ShrinkStep[T], right: function() -> ShrinkStep[T]) -> ShrinkStep[T]` は左の列の候補と Skip を保つ。左が Done なら Skip(right) を返し、その Skip を進めるときだけ right を呼ぶ。どちらも equality を要さず、列全体を辿ってから返すことはない。

組み込みの縮小器は、候補の生成と重複の除去を段ごとに行う。元の値または先に受け付けた候補との一回の比較を一段とし、途中の比較は Skip、最後の比較は Yield を返すことがある。等値と最初の出現順を保つ。公開の入口も要素の縮小器も、候補全体を List へ集めない。

性質の最初の Result.Error で縮小を始める。成功した候補は現在の継続へ進み、失敗した候補は入力と説明を更新して候補列をやり直す。候補に対する性質の呼び出しは、一回の縮小と一単位の仕事に数える。最初の candidates(value) と各継続の呼び出しも、呼ぶ直前に仕事を一単位数える。候補の生成、一回の比較、内部状態の前進、Done の取得は一段である。比較の後で Skip や Yield を返すこと自体は追加の仕事に数えない。通常の試行と最初の失敗は縮小予算を消費しない。両方の計数をやり直しの後も累積し、重複や循環も数える。

どちらかの予算が零なら縮小器を呼ばない。どちらかを使い切ったら、次の生成・比較・性質の呼び出しを始めない。既知の Done は上限と一致しても limitReached=false で完了する。未実行の継続が残る場合は true とし、終了確認だけのために呼ばない。試していない Yield を失敗入力として採用しない。予算は呼び出しを数え、コールバックや構造比較の内部の時間・確保を制限しない。コンテナの size は小さく保つ。これらの処理は依然として高費用になりえ、利用者のコールバックが停止するとも限らない。

CheckFailure.Falsified(Counterexample[T]) は、config、最初に失敗した 1 始まりの trial、original、reduced、originalMessage、message、shrinks、shrinkWork、limitReached、libraryVersion（現在は 2.0.0）を持つ。縮小後の入力も記録した説明とともに失敗するが、最小の反例とは限らない。formatFailure(failure, show) は、予算と再現の情報に加え、`show: function(value: T) -> String` による元と縮小後の具体的な入力を含める。同じ seed、config、ライブラリの規則、性質、手書きのコールバックで再現する。Random.fromSeed の版をまたぐ契約を、変更された Property の規則へ広げるものではない。同じ seed だけでは古い反例を再現できない。libraryVersion、生成コードの GENERATOR_VERSION、全 config、手書き関数のソース、具体的な反例を保存する。情報を省く show からの完全な復元は保証しない。必要な具体的な失敗は固定例として残す。[レコードの生成器と縮小器](#レコードの生成器と縮小器)も参照する。

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

`or die` の報告は `kind: "die"`、`severity: "error"`、`code: null` を持つ。ソースの位置と、表示した原因および任意の利用者のメッセージを含む notes を持ち、実行は終了状態 1 で終わる。実行時エラーとは別の報告である。使い方の誤りは通常、`--diagnostics=json` でも文章のままである。[検査報告](#検査報告)のモードでは、標準エラー出力ではなく `diagnostics` 配列に診断を置く。`kind: "check"` と `code: null` の組み合わせを使うのは、その `usageError` の診断だけである。

診断は、メッセージではなく `code` と JSON の欄で区別する。メッセージと修正案の中身は、パッチ版でも変わることがある。取り除いたコードを、別の意味で再び使うことはない。

E0506 は、入口に宣言した利用者エフェクトをその内部で処理する必要があることを示す。標準の `Failure.Fail[E]` は値へ戻すこともできる。

```benitoite error
import Benitoite.Unofficial.Failure

function main() -> Unit uses Failure.Fail[String]
  return Failure.raise("bad")
end function
```

```diagnostic
error[E0506]
handle `Failure.Fail` with `handle ... with` inside `main`
or convert the failure with Failure.toResult inside `main`
```

`Benitoite.Unofficial.Failure` を import し、`main` または `@test` 関数の内部で `Failure.toResult` を使って失敗を受け止める。受け止めた Fail は入口の `uses` から除き、ほかのエフェクトは残す。次の例では `Console.Write` を残す。失敗が `Result.Error` になるため、入口は検査を通り、実行できる。

```benitoite
import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind result: Result[Unit, String] <- Failure.toResult(body: lambda()
    return Failure.raise("bad")
  end lambda)
  match result with
    case Result.Ok(_) -> return ()
    case Result.Error(message) -> Console.writeLine("handled: ${message}")
  end match
end function
```

```output
handled: bad
```

`Result.andThen` / `flatMap` は既存の Result の値を連結する関数であり、Fail を捕捉しない。変換の案内は標準の Fail に限る。Log や利用者が定義した同名の Fail には、それぞれのハンドラが必要である。

幅付き整数の標準関数も、被除数が未知でも既知の零除算に W0401、既知のあふれに W0402 を出す。符号付き最小値の absolute と floorDivide(minimum, -1) は警告し、floorModulo(minimum, -1) = 0 は警告しない。実行時の Result と停止の意味は変えない。--deny-warnings を使う場合は追加の警告を確認する。宣言由来の制約による下流の重複診断を抑え、独立した誤りは残す。同名の別の型はモジュールを含めて区別する。

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
| `Log`, `SourceLocation` | prelude | 構造化ログと明示的な呼び出し位置 |
| `Assert` | prelude | テストでの確かめ |
| `IO` | prelude | エフェクト `IO.All` |
| `StringBuilder` | `import Benitoite.StringBuilder` | 局所の文字列の構築。専用操作は State を加えない。 |
| `ListBuilder`, `BytesBuilder` | 各モジュールを明示的に取り込む | 局所のリスト・バイト列の構築。専用操作は State を加えない。 |
| `Trait` | `import Benitoite.Trait` | 標準の型クラス |
| `IO.Console` | `import Benitoite.Unofficial.IO.Console` | 標準入力と標準出力 |
| `IO.File` | `import Benitoite.Unofficial.IO.File` | ファイルとディレクトリ |
| `IO.Process` | `import Benitoite.Unofficial.IO.Process` | 引数、環境、外部のコマンド、終了 |
| `IO.Clock` | `import Benitoite.Unofficial.IO.Clock` | 時計と待つこと |
| `IO.Random` | `import Benitoite.Unofficial.IO.Random` | 乱数 |
| `Time` | `import Benitoite.Unofficial.Time` | 時点と暦の日付 |
| `Path` | `import Benitoite.Unofficial.Path` | パスの結合と分割 |
| `Json` | `import Benitoite.Unofficial.Json` | JSON |
| `Failure` | `import Benitoite.Unofficial.Failure` | 型付きの失敗と Result との変換 |
| `Test.Property` | `import Benitoite.Unofficial.Test.Property` | 純粋な生成器・縮小器・性質の試行 |
| `Json.Codec` | `import Benitoite.Unofficial.Json.Codec` | 純粋な Result による JSON 変換 |
| `Csv` | `import Benitoite.Unofficial.Csv` | CSV（RFC 4180） |
| `Scope` | `import Benitoite.Unofficial.Scope` | 条件を保持する検査済みのホスト、絶対パス、ポートの閉区間。 |
| `Range` | `import Benitoite.Unofficial.Range` | 端点と値を保持する検査済みの Integer の閉区間。 |
| `NonEmptyList` | `import Benitoite.Unofficial.NonEmptyList` | 検査済みの非空リストと head/tail/map |
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
- `Process.run` と `Process.runAttached` は、明示した `Command.environment` の名前が `DYLD_` か `LD_` で始まる場合、ASCII の大文字と小文字を区別せずに拒否する。ビルドの道具が使う `LD_RUN_PATH`、小文字の綴り、空の値、継承する値と同じ値の再設定も含む。子の起動やパイプの準備の前に、`IOErrorKind.InvalidInput` の `Result.Error` を返す。既存の不正入力の検査（NUL、空の名前、名前の中の `=` など）を優先する。メッセージは元の名前の辞書順で最初の禁止変数の名前を示し、その値は出さない。
- この環境変数の規則は、すべての OS で常に適用するが、継承する変数は変えない。`Process.shell` も継承を続ける。`Process.Run` を許可すれば、`env` のようなコマンドやシェル自身が変数を設定することも許す。この規則は、初期の環境、`PATH`、コマンド固有の設定、孫プロセス、Windows のすべての DLL 探索の振る舞いを制御しない。サンドボックスではなく、隔離はハーネスと OS で行う必要がある。
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

### 関数内の構築器

Benitoite.StringBuilder を明示的に取り込み、種類の注釈を付けた局所 bind と直接の new() で宣言する。構築器は第二級の値であり、通常の値として格納・返却・ラムダや lazy への捕捉はできない。StringBuilder は通常の型ではなく構築器の種類を表す。宣言と専用操作は State を加えず、通常の引数のエフェクトだけを残す。

```benitoite
import Benitoite.StringBuilder

function main() -> Unit
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "a")
  bind before <- StringBuilder.copy(b)
  StringBuilder.appendAll(texts: ["b", "c"], builder: b)
  bind after <- StringBuilder.copy(b)
  bind size <- StringBuilder.byteLength(b)
end function
```

```output
exit 0
```

append は String、appendAll は List[String] を取り、順番に区切りなしで追加して Unit を返す。copy は現在の内容の不変な物理コピー、byteLength は UTF-8 のバイト数を返す。before は "a"、after は "abc"、size は 3 のまま保たれる。途中の copy を繰り返すと、その内容に比例する時間と容量を要する。通常の引数をソース順に一度ずつ評価してから内容を読み、上限検査と予約に成功してから更新する。上限超過は R0902、予約失敗は R0907 となり、途中まで更新した状態を残さない。

ListBuilder と BytesBuilder も各々明示的に取り込む。`bind xs: ListBuilder[T] <- ListBuilder.new()` は通常の要素型 T を要し、`bind bs: BytesBuilder <- BytesBuilder.new()` はバイト列の構築器を作る。どちらも空から始める。

| 直接の操作 | ListBuilder[T] | BytesBuilder |
|---|---|---|
| append(builder: b, value: value) | T を一つ追加 | Byte を一つ追加 |
| appendAll(builder: b, …) | values: List[T] | bytes: Bytes |
| copy(b) | 不変の List[T] | 不変の Bytes |
| length(b) | 要素数の Integer | バイト数の Integer |

```benitoite
import Benitoite.ListBuilder
import Benitoite.BytesBuilder

function main() -> Unit
  bind xs: ListBuilder[Integer] <- ListBuilder.new()
  ListBuilder.append(value: 1, builder: xs)
  bind before <- ListBuilder.copy(xs)
  ListBuilder.appendAll(builder: xs, values: [2, 3])
  bind bs: BytesBuilder <- BytesBuilder.new()
  BytesBuilder.append(builder: bs, value: 0xffu8)
  BytesBuilder.appendAll(bytes: Bytes.fromList([0x00u8]), builder: bs)
  bind bytes <- BytesBuilder.copy(bs)
end function
```
```output
exit 0
```

copy 後の追記は既存のコピーを変えない。ただし List[Reference[T]] の要素のセルは共有する。通常の関数への引数渡し、返却、格納、比較、文字列補間は E0464 となり、通常の型注釈・型引数・データの欄・Failure.Fail の引数にも使えない。ラムダ・lazy・部分適用・ハンドラ節は外側の構築器を捕捉できない（E0465）。部分適用は呼ぶ式と固定引数の両方が対象である。先に copy や length の通常値を束縛するか、その境界の内側で新しい構築器を宣言する。通常の分岐と handle の本体は外側の構築器を使える。ガード・die の説明・lazy の本体は純粋でなければならず、内側で宣言した構築器も通常の引数が純粋な場合に限り使える。

操作は直接呼び出しを要し、関数値・穴・パイプは E0466 となる。宣言には対応する注釈と直接の new を要する（E0463）。標準モジュールの import 別名は使える。最後の構築器の束縛は Unit となる。List.forEach のコールバックでは捕捉できないため、appendAll の前に断片のリストを作る。clear/reserve/finish はない。旧 uses State は受理するが、API を純粋へ変える場合は契約を明示的に変更する。Reference・タスク・IO・通常のリソースの解放のエフェクトは残る。

## 20. 互換性

### 0.0.11 への移行

language と依存ハッシュの更新前に、[0.0.11 の移行案内](../../../CHANGELOG.md#0011-san-benito)を読む。実行ファイルをビルドし、その埋め込み Skill を再インストールする。derive の inventory3・生成器3.1.0 には元本文とハッシュを検証する新しい preview と、その確認済み apply ハッシュが必要である。try-actions の inventory/manifest2 には候補の再生成と再確認が必要であり、有効契約が不明、またはファイルの宣言の元位置に対応付けられなければ保留する。個別の Log 宣言だけを持つ既存ソースも含め、package update の Log の記録と増減を確認する。その後に language を 0.0.11 へ、依存ハッシュを現在の内容へ更新する。

ファイル単位の uses は、使わないものもすべてのトップレベル関数の契約へ加える。実行前にハーネスを通じて合併済みの上限を確認し、純粋なコールバックは宣言のない別ファイルへ移す。新しい静的な書式と表示の幅の関数は[文字列](#文字列)を参照する。

### 0.0.10 への移行

language と依存のハッシュを更新する前に、[0.0.10 の移行案内](../../../CHANGELOG.md#0010-san-benito)を読む。block と同名の識別子、Integer 全域後の全体を覆う分岐、prelude の Log/SourceLocation との衝突を見直す。局所構築器は State を加えないため、公開契約を純粋へ変える場合は明示的に確認する。物理コピーの費用も考慮する。Log は IO.All と独立して宣言し、宣言上限に残るなら許可集合へ加える。幅付き整数の警告は --deny-warnings で拒否につながる。

開発用 derive は inventory 2、設定 1、生成規則・manifest・receipt・記録 3（3.0.0-syntax-batch4）となり、Property.libraryVersion は 2.0.0 を保つ。未完の旧適用は保存した旧道具で先に復旧する。旧管理本文と記録のハッシュを照合し、新しい preview と manifest の正確なハッシュを確認して apply/check する。依存ハッシュの変更も自動承認しない。[derive の移行](../../../tools/derive/README.md#markers-records-and-review-artifacts)と、保管した[名前付き引数の移行道具の復元手順](../../archive/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/historical-tools/named-arguments-migrate/README.md)を参照する。対応する実行ファイルをビルドし直し、Skill を再インストールする。

### 0.0.9 への移行

Regex/Scope の定数拒否、Range の Error、不透明な境界、構築器の制限、文書の報告の版、inventory・生成・Property の一括切り替えは、[0.0.9 の移行案内](../../../CHANGELOG.md#009-san-benito)を参照する。language 宣言とハッシュを更新する前にソースと依存を見直し、ビルドし直して対応する Skill を再インストールする。

### 版の方針

メジャー版が 0 の間は、次のとおりとする。

- マイナー版（`0.1.0` から `0.2.0`）は、言語、標準ライブラリ、コマンドライン、診断を、互換性のない形で変えることがある。互換性のない変更は、それぞれ移行の方法とともに [CHANGELOG](../../../CHANGELOG.md) に挙げる。
- パッチ版（`0.1.0` から `0.1.1`）は、不具合（`benitoite` の振る舞いのうち、その仕様と異なるもの）だけを直す。言語、標準ライブラリ（非公式のモジュールを含む）、コマンドライン、診断のコード、JSON の形式は変えない。診断のメッセージと修正案は変わることがある。
- 非公式のモジュールを標準ライブラリへ移すと、その取り込みの名前が変わる。これはマイナー版でだけ行う。
- 同梱の Agent Skill は、一緒に配られた版の `benitoite` だけを説明する。更新した後は `benitoite skill install` を再び実行する。

> 注記: `0.0.1` から `0.0.11` までのリリースはソースコードだけを配り、実行ファイルは配らない。実行ファイルは `0.1.0` から配り、それまではどのリリースも互換性のない変更を含むことがある。

## 21. 実験的な機能: パッケージと外部の関数

パッケージと外部の関数は実験的な機能である。構文を見直すときに、その表記が変わることがある。言語のほかの部分と同じ[互換性の方針](#20-互換性)に従い、実験的な機能もこの方針の例外にはならない。

### 局所の依存

パッケージは、設定ファイル `package.bnt` と、ほかのスクリプトが取り込めるモジュールを持つディレクトリである。例えば、`packages/textkit` の下に次の二つのファイルを作る。

```files
name: packages/textkit/package.bnt
language "0.0.11"

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
language "0.0.11"

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
language "0.0.11"
```

```benitoite check
// spec: 01-03 依存の記述と `package.bnt`
function main() -> Unit
end function
```

依存のブロックも、その根の設定ファイルへ移せる。依存は一か所にまとめる。起点のスクリプトと `package.bnt` の両方で依存を宣言すると誤りになる。両方で `language` を宣言しても誤りになる。

`language "MAJOR.MINOR.PATCH"` は、三つの十進整数で、そのファイルを書くときに使った言語の版を記録する。Benitoite `0.0.11` では、`0.0.11` の宣言は互換性の検査を通り、それより後の版は `E0907`、前の版は `E0908` になる。起点のスクリプトと根の設定ではこの宣言を省いてよいが、パッケージの設定では必須である。宣言の有無にかかわらず、処理系は同じ言語の規則を使う。根の版と依存の版は、それぞれ独立に検査する。ローダ環境変数の変更の移行案内は、スクリプトを見直した後に宣言を現在の処理系の版へ更新し、依存のハッシュを更新するよう促す。宣言の更新先を、その変更が入った版に固定しない。互換性の保証は[版の方針](#版の方針)、各リリースの変更は [CHANGELOG](../../../CHANGELOG.md) に記す。

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

コマンドは、公開された関数と型クラスのメソッドの宣言、公開された型の別名の右辺、公開されたレコードのフィールドの型、公開された `data` の構成子のフィールドの型から、組み込みのエフェクトを報告する。入れ子の関数の型のエフェクトも含む。ライブラリのモジュールは、`Benitoite.Unofficial.IO.Console` のような正式な取り込みの名前で識別する。`State`、`IO.All`、prelude の `Log` と `Benitoite.Log` に取り込みは要らない。トップレベルの宣言や別の取り込みが Log という名前を持てば裸の標準名を隠すが、Benitoite 自体が隠されなければ Benitoite.Log は識別できる。標準 Log モジュールの正式な取り込みとその別名経由の参照も Log と記録する。型検査を行わない集計なので、検査では拒否するエフェクトの取り込みの別名も構文どおりに数える。標準ライブラリの表にない取り込みの名前を通じて参照したエフェクトは数えない。この報告のためにパッケージを型検査することはなく、利用者が定義したエフェクトとエフェクト変数は含めず、`IO.All` も展開しない。コンポーネントの報告は、`(no imports)` を添えるか、失敗の理由を示す。コンポーネントの失敗だけでは編集を止めない。`benitoite check` は引き続き、スクリプトが実際に使うパス、公開された名前、型を検査する。

外部公開のトップレベル関数を一つ以上持つファイルでは、同じ組み込みの識別規則で、ファイル単位の uses も一度だけ集合へ加える。public(package) の関数、非公開関数、trait、型宣言しかないファイルからは加えない。trait メソッドや入れ子の関数型の明示的な効果は引き続き数える。ファイルの宣言だけの変更も保存記録と update の増減へ反映する。裸の Log の識別に対応したため、個別宣言しかない既存ソースでも Log が記録へ加わることがある。依存の更新時にハーネスでこれらの変更を確認する。

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

`--wasm-stats` は、終了時に標準エラー出力へ JSON を一行書き、設定した `limits`、明示的な `overrides`、`calls`、`functions`、`fuel`、`memory`、`arguments_transfer`、`results_transfer`、`stateful_instances`、`reached_limits` を含める。`routes`（`typed`、`adapter`、`dynamic`、`stateful` の呼び出し回数）、`fallback_reasons`、アダプタだけの `construction_bytes`、および数値の `code`、`requested`、`limit`、`calls` を持つ `adapter_failures` も含む。各消費量のオブジェクトは、`total`、`maximum`、`incomplete_calls` を持つ。`construction_bytes` は引数と結果の論理的な量を合計するので、その最大値は一回の呼び出しの合計の最大値であり、詰めて格納した転送のバイト数とは別である。`typed`、`dynamic`、`stateful` の呼び出しは、`construction_bytes` もその `incomplete_calls` も増やさない。構築量全体を測る前に止まったアダプタの呼び出しだけが、その欄を増やす。メモリの合計は増加を一度だけ数え、最大値は呼び出し全体か、状態を持つインスタンスの寿命全体を数える。引数の検証で拒んだ呼び出しも、呼び出し回数に含む。転送量の合計は、値を数えられた呼び出しだけを含み、消費量を得られなかった場合は `incomplete_calls` を増やす。動的な経路と `typed` の文字列の統計は、ホストの UTF-8 のバイト数を数える。これはゲストの値をホスト側の表現へ変換するときに計上したバイト数と異なることがある。アダプタの転送の統計は、詰めて格納したバイト列を数える。`test` は、すべてのテストの実行を一つの報告に集計し、テストごとの内訳は示さない。このオプションがなければ、出力は変わらない。公開の埋め込み API と参照インタプリタは、既定の上限を保つ。 `runtime_compilations.normal` と `runtime_compilations.adapter` は、それぞれの共有表へ実行用 Component を追加できた回数を数え、`test_declaration_compilations` は、テストの入口と文書の例の静的な宣言照合でコンパイルを試みた回数を別に数える。

資源の上限の失敗以外のトラップ、ABI 違反、インスタンス化の失敗は、`R0601` で実行を止める。燃料の枯渇は `R0904`、メモリ・転送量・構築量の上限は `R0905` を報告する。後者には、達した上限と、分かる場合はアダプタの失敗した段階を示す注記を添える。テーブルの大きさとコアの対象数の上限は、資源の種類と必要数を添えて `R0906`、戻り値の大きさの上限は `R0902` を報告する。診断コードと失敗の分類は経路間で一致するが、トラップの文言は異なることがある。ゲストの ABI 違反は、アダプタが値をゲストに渡す形式へ変換するときやゲストを呼ぶときに現れることがある。これらの失敗は `Result.Error` に変換しない。宣言した `Result` を通してエラーを返すコンポーネントは、通常の値を返す。

引数と結果は、ホストのメモリに同時に存在しうる。動的な WIT の表現、型付きの配列、詰めて格納したアダプタのバッファ、ゲストとアダプタの線形メモリ、Benitoite の値は、すべてメモリを使う。設定した転送量とメモリの上限は、この消費の異なる部分を制限し、プロセスのメモリ全体は制限しない。

これらの検査は、コンポーネントの結果が正しいことも、正常に戻ることも保証しない。コンポーネントのコンパイルは、実行時だけでなく検査時にも行う。入力のコンポーネントは 256 MiB に制限するが、検査の時間とホストのメモリには上限がない。信頼できないコンポーネントの検査も含め、処理系の隔離は引き続きハーネスか OS の責任であり、スクリプトには実行時の権限制御がない。

### JSON とレコードの変換

Benitoite.Unofficial.Json.Codec は、String、Boolean、Integer、有限の Float、List、String をキーとする Map、Option に対し、純粋な Result による変換を提供する。数値には正確な JSON の構成子を要し、Integer を Float へ暗黙に変換しない。NaN と無限大は両方向で失敗する。ConversionError は path、expected、found、reason を持つ拡張可能なレコードである。経路は Field、Index、Key からなり、外側のコンテナから最初の失敗へ並ぶ。Show は経路と種類を表示し、入力値の中身を自動では表示しない。

```benitoite
import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Json.Codec

function main() -> Result[Unit, String]
  bind encoded <- try Codec.encodeList(value: [1, 2, 3], encode: Codec.encodeInteger)
    |> Result.mapError(r: _, f: lambda(error) return Codec.ConversionError.reason(error) end lambda)
  bind decoded <- try Codec.decodeList(value: encoded, decode: Codec.decodeInteger)
    |> Result.mapError(r: _, f: lambda(error) return Codec.ConversionError.reason(error) end lambda)
  if decoded <> [1, 2, 3] then
    return Result.Error("JSON conversion roundtrip failed")
  end if
  return Result.Ok(())
end function
```

```output
```

開発用の [derive](../../../tools/derive/README.md) は、型パラメータがなく循環しないレコードについて、通常の encode/decode 関数を生成する。フィールドを宣言順に検査し、その後でキー順に最初の余分なキーを拒否する。自動の Option フィールドは、欠落と null を None に変換する。必須のフィールドに暗黙の既定値はない。json.keys でキーを改名する。入れ子の Option と非対応の型には、フィールド全体の独自の encode/decode を要する。任意の decodeMissing が欠落を扱う。独自の変換は純粋で、意図した往復則を満たさなければならない。

preview の差分と manifest を確認し、確認済み manifest のハッシュで apply した後、通常の check/test と derive check を行う。通常の check は生成記録を読まず、フィールドの追加による古いエンコーダをすべては検出できない。[二段のレコードの例](../../../tools/derive/examples/People.bnt) は、通常の @test、生成した Gen/Shrinker 関数、JSON の往復を試す性質、Failure.fromResult を使う明示的なアプリケーションの境界を含む。codec 自体には Fail は不要である。JSON の文字列の解析は、引き続き ParseError を持つ別の Result である。任意の JSON の綴りと parse/stringify をまたぐ表現は、変換の往復の保証に含めない。

### Show と Order の実装の生成

開発用の [derive](../../../tools/derive/README.md) は、対象ごとに独立した真偽値 show と order を受け付ける。レコードの宣言モジュールに通常の実装を生成する。Show は局所のレコード名とフィールドを宣言順で表示し、各値の引用とエスケープは対応する Show 辞書に委ねる。Order は同じ順に比較し、最初の非 Equal で止まる。すべて等しければ Equal を返す。Equal は組み込みの等値や key 制約を保証せず、Show の出力は直列化形式ではない。

対象は同じモジュール内の正則な自己・相互再帰と型パラメータを含められる。要求する辞書の制約を再帰する欄へ伝播し、phantom のパラメータには制約を足さない。各フィールドに要求した辞書が必要で、別の生成レコードもそのクラスを明示的に選ぶ。フィールドの型に手書きの実装を使える。認証済みの対象領域の外に既存実装があれば生成を拒否する。空のレコード宣言は引き続き構文エラーである。不透明なレコードも、所有モジュール内で Show/Order を明示的に要求できる。表示を了承する前に、提案する記録の opaque と選択したクラスを確認する。その不透明型の JSON/Property による自動構築は引き続き拒否する。

preview、差分の確認、正確な manifest ハッシュを指定した apply、通常の check/test、derive check を行う。同梱の People/Address は、生成記録の版 3 と Property ライブラリ 2.0.0 への一括移行を終えている。Person は Show、Address は Show と Order を要求する。

### レコードの生成器と縮小器

derive の property.generator と property.shrinker は独立して指定でき、同じモジュール内の正則な自己・相互再帰と型パラメータに対応する。使う型パラメータだけに宣言順の Gen/Shrinker 引数を加え、phantom には加えない。JSON は引き続き単相・非循環に限り、非対応の指定を黙って省かない。

生成器には有限の基底と正則な再帰の型引数を要する。size は枝ごとの深さではなく、生成するレコード節点の総予算である。Option や容器を通る辺は有限の基底になりうる。非正則な再帰、有限の基底のない必須の循環、閉じない制約は拒否する。乱数の状態は欄順に進め、再帰する factory は生成や候補の要求まで処理を遅らせる。

縮小器は再帰する容器の内容の削除を先行し、その後に欄順で一つの欄を縮小する。必須のレコード欄は自分自身を縮小し、親を子で置き換えない。標準の葉と容器は自己候補を除き、再帰節点数を増やさない。制約のない型パラメータに独自 Shrinker を渡す場合、その入力自身を候補から除く責任は呼び出し側にある。独自コールバックの停止と大域的な最小性は保証しない。Show/Order の制約は宣言グラフへ伝播し、Order は組み込みの等値を導かない。

独自の fields.gen/fields.shrink は対にし、完全修飾した純粋・単相・零引数の関数で欄全体を置き換える。版 3 の .generated.json（generatorVersion: 3.0.0-syntax-batch4）、config、libraryVersion 2.0.0、ソース、具体的な反例と独自関数を保存する。inventory は 2、設定は 1 のままである。旧本文のハッシュを照合してから新しい preview を確認し、旧 manifest で新版を適用しない。種だけでは生成規則の版をまたぐ分布を再現できない。[derive の手順](../../../tools/derive/README.md)に従う。

### Range

Benitoite.Unofficial.Range を取り込む。全関数は純粋である。CheckedInteger は minimum: Integer、maximum: Integer、value: Integer を保持する不透明なレコードである。公開関数を使う。外からの構築・更新・パターン・自動フィールドアクセサは E0340 となる。

| 関数 | 結果 |
|---|---|
| `checkInteger(minimum: Integer, maximum: Integer, value: Integer)` | `Result[CheckedInteger, RangeError]` |
| `minimum(value: CheckedInteger)` | 保持した下端（端点を含む） |
| `maximum(value: CheckedInteger)` | 保持した上端（端点を含む） |
| `value(value: CheckedInteger)` | 保持した Integer |

最初に端点の逆転を検査し、Result.Error(RangeError.InvalidBounds(minimum, maximum)) を返す。それ以外で値が閉区間の外なら Result.Error(RangeError.OutOfRange(minimum, maximum, value))、内側なら三入力すべてを保持した Result.Ok を返す。RangeError は二つの公開構成子を持つ閉じたデータ型である。Trait.Show は OutOfRange(0, 10, 11) のように構成子名と入力を表示する。

同じ端点は一つの値を表す。Integer の両端 -9223372036854775808 と 9223372036854775807 にも、上端へ 1 を加えず対応する。Integer への暗黙の変換や区間を追跡する演算はない。同じ CheckedInteger 型の値でも端点は異なりうる。端点を調べるか、必要な端点で checkInteger をやり直す。Option で足りるなら Result.ok を使う。

Range は不正な定数の引数にも通常の Result.Error を返し、Scope と Regex の追加の静的検査には含めない。トップレベルの const に書ける式は増えない。

```benitoite
import Benitoite.Trait
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  match Range.checkInteger(minimum: 0, maximum: 10, value: 10) with
    case Result.Ok(checked) ->
      Console.writeLine(Integer.toString(Range.minimum(checked)))
      Console.writeLine(Integer.toString(Range.maximum(checked)))
      Console.writeLine(Integer.toString(Range.value(checked)))
    case Result.Error(error) -> Console.writeLine(Trait.Show.show(error))
  end match
  match Range.checkInteger(minimum: 0, maximum: 10, value: 11) with
    case Result.Ok(_) -> Console.writeLine("unexpected success")
    case Result.Error(error) -> Console.writeLine(Trait.Show.show(error))
  end match
end function
```


```output
0
10
10
OutOfRange(0, 10, 11)
```


### 検査済みの長さ・添字・非空リスト

Benitoite.Unofficial.Range と Benitoite.Unofficial.NonEmptyList を明示的に取り込む。包む型は不透明であり、公開の検査関数と射影を使う。外部からの構築・更新・パターン・自動アクセサは E0340 となる。不正な定数入力も通常の Result.Error を返す。

| 検査 | 成功値と射影（各射影の引数名は value） | 失敗の優先順 |
|---|---|---|
| Range.checkLength(minimum, maximum, values) | CheckedLength[T]。lengthMinimum、lengthMaximum、checkedLength、lengthValues | minimum が負か上下逆なら LengthError.InvalidBounds(minimum, maximum)、その後 OutOfRange(minimum, maximum, actualLength) |
| Range.checkIndex(index, values) | CheckedIndex[T]。indexValue、indexValues、get | 負か長さ以上の零始まり添字は IndexError.OutOfBounds(index, length) |
| NonEmptyList.fromList(values) | NonEmptyList[T]。toList、head、tail | EmptyListError.EmptyList |

呼び出しでは複数引数にラベルを付ける。

```benitoite test
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.NonEmptyList

@test("checked lists retain their values")
function checkedLists() -> Unit uses Assert.Check
  match Range.checkLength(minimum: 2, maximum: 2, values: [10, 20]) with
    case Result.Ok(checked) ->
      Assert.equal(actual: Range.checkedLength(checked), expected: 2)
      Assert.equal(actual: Range.lengthValues(checked), expected: [10, 20])
    case Result.Error(_) -> Assert.fail("valid length was rejected")
  end match
  match Range.checkIndex(index: 1, values: [10, 20]) with
    case Result.Ok(checked) -> Assert.equal(actual: Range.get(checked), expected: 20)
    case Result.Error(_) -> Assert.fail("valid index was rejected")
  end match
  match NonEmptyList.fromList([10, 20]) with
    case Result.Ok(checked) ->
      Assert.equal(actual: NonEmptyList.head(checked), expected: 10)
      Assert.equal(actual: NonEmptyList.tail(checked), expected: [20])
    case Result.Error(_) -> Assert.fail("nonempty list was rejected")
  end match
end function
```

成功値は元の不変リストを保持する。get は検査済み添字だけを取り、リストや再検査を要さず保持した要素を返す。別のリストには再び検査を行う。要素の Reference は共有する。失敗は端点・個数・添字だけを保持し、リストは保持しない。エラー型には Show があるが、包む型にはない。要素型が許す場合、包む型の等値とキー順序は保存した内容に従う。

NonEmptyList.head は T、tail は空でもよい List[T] を返す。map(value: ..., f: ...) は先頭から各要素に f(value: T) を一度ずつ適用し、エフェクトと失敗を伝播し、成功時は非空の結果を返す。通常の List と IO の引数型は変えない。

### Scope

Benitoite.Unofficial.Scope を取り込む。全関数は純粋である。不透明なレコード CheckedHost、CheckedPath、CheckedEndpoint は通常の値として受け渡せる。構成子、更新、パターン、自動フィールドアクセサは Scope 内だけで使える（外では E0340）。公開の検査と射影を使う。

| 関数 | 契約 |
|---|---|
| `checkHost(pattern: String, host: String)` | `Result[CheckedHost, ScopeError]` |
| `checkPath(pattern: String, path: String)` | `Result[CheckedPath, ScopeError]` |
| `checkEndpoint(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer)` | `Result[CheckedEndpoint, ScopeError]` |
| `host(value: CheckedHost)`, `hostPattern(value: CheckedHost)` | `String` |
| `path(value: CheckedPath)`, `pathPattern(value: CheckedPath)` | `String` |
| `endpointHost(value: CheckedEndpoint)`, `endpointHostPattern(value: CheckedEndpoint)` | `String` |
| `endpointPort(value: CheckedEndpoint)`, `endpointMinimumPort(value: CheckedEndpoint)`, `endpointMaximumPort(value: CheckedEndpoint)` | `Integer` |

ホストは、ASCII の英数字とハイフンからなる非空のラベルをドットで区切る。ラベルの両端のハイフン、空のラベル、末尾のドット、URL、ポートの接尾辞、IPv6、非 ASCII、NUL は拒否する。数字だけの四ラベルは値の範囲にかかわらず IPv4 の形式として拒否する。localhost は受け付ける。パターンは完全一致、直前の一ラベルに一致する *.host、一つ以上に一致する **.host である。ワイルドカードはどちらも幹自体を含まない。成功したホスト検査はパターンと対象を小文字で保存する。DNS の長さの規格はこの契約に含めない。

パスはスラッシュ区切りの絶対表記を使う。/ は受け付け、ほかの末尾のスラッシュ、空の成分、. と ..、NUL、バックスラッシュを拒否する。ほかの Unicode 文字は表記を保つ。パターンは完全一致か末尾の /** であり、ほかの位置の星を拒否する。/data/reports/** は /data/reports とその子孫を含み、/data/reports-old は含まない。/** は根と受理できる全パスを含む。対象パス内の星は通常の文字である。成功した検査は両方の文字列をそのまま保存する。

Endpoint の端点は 0 <= minimumPort <= maximumPort <= 65535 を満たし、port は閉区間内でなければならない。同じ端点を許し、整数三つをすべて保つ。最初の失敗を、パターンの形式、対象の形式、端点、ポートの形式、ホストまたはパスの所属、ポートの所属の順に返す。ScopeError は元の入力を保持する六つの公開構成子を持つ。

- InvalidPattern(pattern, reason) と InvalidTarget(target, reason)。reason は英語である。
- InvalidPortRange(minimumPort, maximumPort) と InvalidPort(port)。
- OutsideScope(pattern, target) と PortOutsideScope(minimumPort, maximumPort, port)。

Trait.Show は文字列を引用・エスケープし、表示する入力と最終メッセージをそれぞれ 4096 UTF-8 バイトまでとし、切り詰めには ... を使う。保持した入力は省略しない。条件と対象を変えるときは検査をやり直す。型名だけでは特定のパターンや範囲は分からない。

```benitoite
import Benitoite.Trait
import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit, String] uses Console.Write
  bind checked <- try Scope.checkHost(pattern: "*.EXAMPLE.COM", host: "API.EXAMPLE.COM") |> Result.mapError(r: _, f: lambda(error) return Trait.Show.show(error) end lambda)
  Console.writeLine(Scope.host(checked))
  Console.writeLine(Scope.hostPattern(checked))
  return Result.Ok(())
end function
```
```output
api.example.com
*.example.com
```

既知の不正な直接の引数は、テスト内や match で Error を処理していても E0459〜E0462 で拒否する。動的な Error を調べる場合は、通常の関数の引数を経由させる。

```benitoite
import Benitoite.Trait
import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.Console
function inspect(pattern: String, host: String) -> Result[Scope.CheckedHost, Scope.ScopeError]
  return Scope.checkHost(pattern: pattern, host: host)
end function
function main() -> Unit uses Console.Write
  Console.writeLine(Trait.Show.show(Result.isError(inspect(pattern: "*.example.com", host: "a.b.example.com"))))
end function
```
```output
true
```

成功は、保存した対象の表記が保存した条件を満たすことを表す。権限の付与、DNS の解決先やファイル・リンクの実体の特定、隔離、後の変更の防止、URL とリダイレクトの検証、IO の成功は保証しない。既存の IO 関数は引き続き String と Integer を受け取る。検査済みの対象を使うときは射影した値を明示的に渡す。
