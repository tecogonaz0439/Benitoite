# T24 パイプライン API と CLI

- 依存する作業: [T05](T05-diag-render.md), [T13](T13-resolver.md), [T15](T15-typeck-generate.md), [T17](T17-desugar.md), [T20](T20-decision-tree.md), [T21](T21-codegen.md), [T23](T23-runtime.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T24-pipeline-cli

## 目的

各段をつなぐ公開の関数（検査・脱糖・コンパイル）と、`benitoite` コマンド（`run` と `check`）を実装する。この作業で、読み込みから実行までのすべての段が一つにつながり、スクリプトを実行できるようになる。あわせて、作業の途中のために置いていた `dead_code` の許可を外す。

## 読む設計書の節

- [パイプライン](../../2026-09-27-design-initial/02-impl/02-01-pipeline.md)の「段と段の間のデータ」「検査と実行の経路」「誤りが見つかったときの段の進め方」
- [ソース管理と位置情報](../../2026-09-27-design-initial/02-impl/02-02-source-and-spans.md)の「ソースとファイル ID」
- [名前解決とモジュール読込](../../2026-09-27-design-initial/02-impl/02-04-resolver.md)の「prelude」（prelude のソースの読み込みの順と表示名）
- [診断エンジン](../../2026-09-27-design-initial/02-impl/02-10-diagnostics.md)の「文章の形式」（診断の順序、色）「JSON の形式」
- [スクリプト実行と埋め込み](../../2026-09-27-design-initial/02-impl/02-11-embedding.md)の「CLI の一回の実行」
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「panic 境界」（hook の設定の時期、検査の段の panic）「プログラムの実行の流れ」
- [CLI](../../2026-09-27-design-initial/06-tooling/06-01-cli.md)の全体
- [パイプライン API と CLI](../10-interfaces/10-09-pipeline-api.md)の全体
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「IO 実行器と panic 境界」「報告の組み立てと実行の流れ」
- [基本の型とクレートの骨組み](../10-interfaces/10-01-base.md)の「クレートの骨組み」

## 作るもの

- `src/pipeline.rs`: 10-09 の `sig=src/pipeline.rs` の関数（`check_path`・`check_text`・`parse_source`・`desugar_checked`・`compile`）。
- `src/main.rs`: 10-01 の `sig=src/main.rs` のとおり。
- `src/cli/mod.rs`: `parse_args`・`parse_size`・`main`。
- `src/lib.rs`: `#![allow(dead_code)]` とその前のコメントを削除する。削除して出る `dead_code` の警告は、使われていない欄や関数を作った作業に戻さず、この作業で直す（使う予定のない非公開の要素なら削除し、10-interfaces の型の欄なら完了の報告に挙げる）。
- 上のファイルの中のテスト。

## 手順の要点

### 検査（`check_path`・`check_text`）

1. `SourceTable` を作り、`prelude::SOURCES` の各ファイルを、表示名 `DISPLAY_PREFIX + ファイルの名前`・`SourceKind::Prelude` で加える。続けて利用者のソースを `SourceKind::User` で加える。`check_path` はファイルを読み、読めないとき・`MAX_SOURCE_BYTES` を超えるときは E0101 の診断（`path` と、注記 `reason` に `std::io::Error` の表示または `text::FILE_TOO_LARGE`（`"file is larger than 256 MiB"`）。`pipeline.rs` の中に `pub mod text { pub const FILE_TOO_LARGE: &str = "file is larger than 256 MiB"; }` の形のモジュールを置いて定める（00-02「文言」））を作り、`user_file: None` で返す。表示名は `path.display().to_string()`。
2. ソースの表を `Arc` に移す。
3. `IdGen` を一つ作り、prelude のソースをファイルの順に、続けて利用者のソースを `parse_source` で解析する。診断に誤りがあれば、ここで返す。
4. `resolve(&prelude, &user, &mut ids)`。誤りがあれば返す。
5. `typecheck(&prelude, &user, &resolved)`。誤りがあれば返す。なければ `CheckedProgram` を作って返す。

各段の診断は、段の中で `(primary の span の file, start)` の順に安定に並べ替える（02-10「文章の形式」の順序）。位置を持たない診断は、その段の先頭に置く。

`parse_source` は `lex` → `resolve_newlines` → `parse` を行い、字句の診断を先に、構文の診断を後に並べる。

### 大きなスタックのスレッド（ADR 0087）

- `check_path`・`check_text`・`desugar_checked`・`compile` は、中身の処理を `pipeline.rs` の非公開の補助の関数（例 `on_large_stack`）に渡して実行する。補助の関数は `std::thread::scope` の中で `std::thread::Builder::new().stack_size(STACK_BYTES)` のスレッドを作り（`STACK_BYTES` は `pipeline.rs` の非公開の定数 `64 * 1024 * 1024`）、`join` して結果を返す。借用した引数をそのまま渡せるように、スコープ付きのスレッドを使う。
- `join` が `Err`（スレッドの中の panic）を返したら、`std::panic::resume_unwind` で呼び出し側のスレッドで panic を再び起こす。呼び出し側の panic 境界（T23 の `runtime::panic::catch`）が処理系の不具合として報告する。
- スレッドを作れなかった（`spawn_scoped` が `Err`）ときは、処理系の不具合として扱う。`check_*` は `internal_diagnostic` の報告を一件持つ `CheckResult`（`program: None`）を、`desugar_checked` と `compile` は `InternalError`（`stage` に `"pipeline"`）を返す。
- 段の結果の型が `Send` でなくスレッドの間で受け渡せない場合は、型を変えずに止まって報告する（00-03「型やシグネチャを変える必要が生じたとき」）。
- `run_with`（実行）はスレッドを作らずに呼び出し側で行う。

### 脱糖とコンパイル

- `desugar_checked` は `ir::desugar::desugar` を呼ぶだけである。
- `compile` は `ir::decision::lower_program` と `bytecode::codegen::codegen` を続けて呼び、`CodegenError::Limit` を `CompileError::Limit` に、`InternalError` を `CompileError::Internal` に移す。

### コマンドラインの解釈（06-01「コマンドラインの形」「オプション」）

- 最初の引数が `--help` か `--version` なら、それぞれ `Command::Help`・`Command::Version`（後ろに引数があれば使い方の誤り）。`run`・`check` でなければ使い方の誤り（`MISSING_COMMAND` か `UNKNOWN_COMMAND`）。
- サブコマンドの後、`-` で始まる引数をスクリプトのパスが現れるまでオプションとして読む。`--diagnostics=text|json`、`--max-call-stack=<大きさ>`。知らないオプション、値の誤り、同じオプションの二度目の指定は使い方の誤り（10-09 の「開発用の設定」の段落で定めてある）。
- 最初の `-` で始まらない引数がスクリプトのパス。`run` では、それより後の引数を、`-` で始まるものも含めて、すべてスクリプトの引数にする。`check` では、パスより後に引数があれば使い方の誤り（`EXTRA_ARGUMENT`）。パスがなければ `MISSING_SCRIPT`。
- 引数は `OsString` のまま受け取る。オプションとサブコマンドの判定には `to_str()` を使い、正しい UTF-8 でないオプションは使い方の誤りにする。スクリプトの引数は `OsString` のまま `check_args`（T23）に渡す。
- 使い方の誤りの文は `text` の型板から作る（`diag::codes::fill_template` を使ってよい）。
- `parse_size(value)`: 10 進の整数に `KiB`・`MiB`・`GiB` のどれかを続けた形だけを受け付け、`checked_mul` でバイト数にする。単位のない数、`0`、溢れは `None`。

### `main`

1. `runtime::panic::install_hook()` を最初に呼ぶ。
2. `parse_args(std::env::args_os().skip(1).collect())`。使い方の誤りは、`USAGE_ERROR` と `SEE_HELP` の二行を標準エラー出力に文章で書き、終了状態 2。`Help` は `USAGE` を標準出力に書いて 0。`Version` は `benitoite <版>`（`env!("CARGO_PKG_VERSION")`）と改行を標準出力に書いて 0。
3. 環境変数 `BENITOITE_DEV_IO_MODE` を読む。ないか `direct` なら `ExecMode::Direct`、`request` なら `Request`、それ以外は使い方の誤り（`BAD_VALUE`）として終了状態 2。
4. 検査: `runtime::panic::catch(|| pipeline::check_path(&script))`。panic なら `internal_diagnostic("check", "", Some(&p))` を書いて終了状態 3。誤りがあれば、文章の形式では `render_check_text(&diags, &sources, verb, 表示名, opts)` を、JSON の形式では一件ずつ `render_json_line` と改行を標準エラー出力に書き、終了状態 2。`verb` は `run` か `check`。`check` は、誤りがなければ何も書かずに 0。
5. デバッグビルドで `BENITOITE_DEV_PANIC` が `check` なら、ここで `panic!` を起こす（`catch` の中で起こし、4 と同じく報告する）。`#[allow(clippy::panic)]` と理由のコメントを書く（[実装の規約](../00-common/00-02-conventions.md)の `#[allow]` の表）。
6. `run` の続き: `desugar_checked` と `compile` も `catch` の中で行う。`InternalError` と panic は `internal_diagnostic(段の名前, message, ..)` を書いて 3、`CompileError::Limit` は診断を 4 と同じ形式で書いて 2。
7. `check_args(args)`。誤り（`Box<Diagnostic>`）なら報告を一件書いて 1。
8. `RealIo::new(args)` を作り、`run_with(&program, &mut io, ExecOptions { mode, max_call_stack_bytes })`。返った `RunEnd` の `main_error` があればその文字列と改行を、続けて `reports` を、文章の形式なら `render_one_text` で、JSON の形式なら一件ずつ一行で、標準エラー出力に直接書く。報告の書き込みの失敗は無視する（02-09）。
   続けて、機能 `alloc-stats` を有効にしたビルド（`#[cfg(feature = "alloc-stats")]`）で環境変数 `BENITOITE_DEV_ALLOC_STATS` が `1` なら、`alloc-stats allocations=<n> bytes=<n> freed=<n>` の一行を標準エラー出力に書く。`allocations` と `bytes` は `RunEnd` の `alloc`、`freed` は `runtime::heap::freed_count()` の値である（10-09「開発用の設定」）。その後に `exit_code` で終わる。
9. 文章の形式の色は、標準エラー出力が端末（`std::io::IsTerminal`）で、環境変数 `NO_COLOR` がないときに付ける（02-10）。

## 受け入れテスト

- `parse_args` の表: `["run", "a.bnt", "-x", "y"]` → `Run { script: "a.bnt", args: ["-x", "y"], 既定のオプション }`。`["check", "--diagnostics=json", "a.bnt"]` → `Check` で `Json`。`["run", "--max-call-stack=512MiB", "a.bnt"]` → 536870912。`["--help"]` → `Help`、`["--version"]` → `Version`。誤り: `[]`、`["build", "a.bnt"]`、`["run"]`、`["run", "--color", "a.bnt"]`、`["run", "--diagnostics=xml", "a.bnt"]`、`["check", "a.bnt", "b.bnt"]`、`["run", "--diagnostics=json", "--diagnostics=text", "a.bnt"]`。
- `parse_size` の表: `"1KiB"` → 1024、`"2GiB"` → 2147483648、`"10"`・`"0MiB"`・`"1TiB"`・`"-1KiB"`・`"99999999999999999999GiB"` → `None`。
- `check_text`: `fn main() -> Unit uses IO { Console.println("hi") }` で診断なし・`program` が `Some`。型の合わないスクリプトで E0401 が一件・`program` が `None`。字句の誤りと構文の誤りが両方あるスクリプトで、字句の診断が先に並ぶ。名前の誤りのあるスクリプトで、型検査の診断が出ない（段を進めない）。
- `check_path` に存在しないパス → E0101 の診断で `user_file: None`。
- `check_text` から `desugar_checked`・`compile`・`run_with`（`TestIo`）までを続けて、`Console.println("hi")` のスクリプトの `stdout` が `"hi\n"`、終了状態 0。

- 大きなスタック: 構文解析器の上限いっぱいの入れ子（ブロック、括弧、`match`、パターン、型注釈の型の入れ子）のスクリプトを、テストのスレッドの既定のスタックのまま `check_text` → `desugar_checked` → `compile` に通し、溢れずに終わる。型の合わない深い型（995 段の `Some` のパターンを `Int` の対象に当てるなど）で E0401 が一件出る。
- スレッドの中の panic: 補助の関数に panic する処理を渡すと、呼び出し側で panic として捕まえられる（`std::panic::catch_unwind` で確かめる）。

CLI を別のプロセスとして起動するテスト（終了状態、標準エラー出力の順序、`BENITOITE_DEV_PANIC`）は T25 が書く。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- `src/lib.rs` に `#![allow(dead_code)]` がない
- `cargo run -- run <ファイル>` で、`fn main() -> Unit uses IO { Console.println("hello") }` のスクリプトが `hello` を出力して終了状態 0 で終わる（手で確かめ、完了の報告に書く）

## 難易度の理由

既存の段の公開の関数を順に呼ぶ作業が中心で、アルゴリズムは含まない。注意が要るのは、段の進め方と診断の順序、終了状態の選び方、報告を書く順序（出力の書き出しの後）、panic を捕らえる範囲、コマンドラインの細かな規則であり、どれも 06-01・02-09・02-10 に定めがある。`dead_code` の許可を外したときに出る警告の始末の量は、前の作業の出来に左右される。
