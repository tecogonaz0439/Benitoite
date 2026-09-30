# パイプライン API と CLI

本章は、段をつなぐ公開の関数（検査・脱糖・コンパイル）と、CLI の型と関数のシグネチャを定める。テストは、処理系を別のプロセスとして起動せず、本章の関数を直接呼ぶ（07-03「前提」）。設計書の対応する章は[パイプライン](../../2026-09-27-design-initial/02-impl/02-01-pipeline.md)、[スクリプト実行と埋め込み](../../2026-09-27-design-initial/02-impl/02-11-embedding.md)、[CLI](../../2026-09-27-design-initial/06-tooling/06-01-cli.md)である。

## 検査の状態とコンパイル

02-11「状態の分け方」の検査の状態を `CheckedProgram`（誤りのないとき）と `CheckResult` で表す。ソースの表は、読み込みを終えた時点で `Arc` に移し、以後は変更しない。

```rust file=src/pipeline.rs
//! 段をつなぐ公開の関数（設計書 02-01「段と段の間のデータ」「検査と実行の経路」）。

use std::sync::Arc;

use crate::base::{FileId, SourceTable};
use crate::diag::Diagnostic;
use crate::ir::InternalError;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Program;
use crate::syntax::token::Comment;
use crate::typeck::TypeckOutput;

/// 型検査までを誤りなく通ったプログラム。
#[derive(Debug)]
pub struct CheckedProgram {
    /// prelude のソースの AST（ファイルの名前の順）
    pub prelude: Vec<Program>,
    pub user: Program,
    /// 利用者のソースのコメントの一覧（v1 のフォーマッタが使う。最小実行版では使わない）
    pub comments: Vec<Comment>,
    pub resolved: ResolveOutput,
    pub types: TypeckOutput,
}

/// 検査の結果。
#[derive(Debug)]
pub struct CheckResult {
    pub sources: Arc<SourceTable>,
    /// 利用者のソースのファイル ID。読み込みに失敗したときは `None`
    pub user_file: Option<FileId>,
    /// 誤りがあった段の診断。段の中ではソース上の位置（ファイル ID、開始の位置）の順に並べる
    pub diagnostics: Vec<Diagnostic>,
    /// 誤りがなければ `Some`
    pub program: Option<CheckedProgram>,
}

/// コンパイルの失敗。
#[derive(Debug)]
pub enum CompileError {
    /// 処理系の制限（`L` のコード）。`run` は終了状態 2 で終える
    Limit(Vec<Diagnostic>),
    /// 処理系の不具合。`run` は終了状態 3 で終える
    Internal(InternalError),
}
```

```rust sig=src/pipeline.rs
use std::path::Path;

use crate::base::{IdGen, Source};
use crate::bytecode::program::CompiledProgram;
use crate::ir::core_ir::CoreProgram;
use crate::syntax::parser::ParseOutput;

/// 利用者のソースファイルを読み、読み込みから型検査までの段を行う（02-01「検査と実行の経路」の `check`）。
/// 読み込みの誤り（ファイルがない、読めない、MAX_SOURCE_BYTES を超える）は E0101 の診断にする。
/// 表示名はコマンドラインで与えたパスの文字列（`Path::display`）とする。
pub fn check_path(path: &Path) -> CheckResult;

/// ソースの内容を与えて検査する（テストで使う）。`name` は表示名。
pub fn check_text(name: &str, text: &[u8]) -> CheckResult;

/// 字句の切り出し（`lex(file, source.text())`）、改行の判定、構文解析を続けて行う。診断は字句の誤りを先に、構文の誤りを後に並べる。
pub fn parse_source(file: FileId, source: &Source, ids: &mut IdGen) -> ParseOutput;

/// 脱糖してコア IR を作る。
pub fn desugar_checked(checked: &CheckedProgram) -> Result<CoreProgram, InternalError>;

/// 判定の木への変換とコード生成を行う。
pub fn compile(core: &CoreProgram, sources: Arc<SourceTable>) -> Result<CompiledProgram, CompileError>;
```

`check_path` と `check_text` の段の順は、読み込み（prelude のソースの追加を含む）、字句と構文（prelude のソースを先に、利用者のソースを後に）、名前解決、型検査である。ある段で誤りの診断が一つでもあれば、次の段を行わない（ADR 0019）。prelude のソースの内容は `crate::prelude::SOURCES` から読む。

## CLI

```rust file=src/cli/mod.rs
//! CLI（設計書 06-01）。最小実行版のサブコマンドは `run` と `check`。

use std::ffi::OsString;
use std::path::PathBuf;

/// 診断の形式（`--diagnostics`）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DiagFormat {
    Text,
    Json,
}

/// `run` と `check` の選択肢。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Options {
    pub diagnostics: DiagFormat,
    /// `--max-call-stack` の値（バイト）
    pub max_call_stack: u64,
}

/// 解釈したコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Command {
    Run {
        options: Options,
        script: PathBuf,
        args: Vec<OsString>,
    },
    Check {
        options: Options,
        script: PathBuf,
    },
    Help,
    Version,
}

/// 使い方の誤りの文と、`--help` の文（ADR 0033 に従い英語で書き、ここにまとめる）。
pub mod text {
    pub const USAGE: &str = "\
Usage:
  benitoite run   [options] <script> [script arguments...]
  benitoite check [options] <script>
  benitoite --help
  benitoite --version

Options:
  --diagnostics=text|json   format of diagnostics and error reports (default: text)
  --max-call-stack=<size>   limit for nested calls, such as 512MiB or 2GiB (default: 1GiB)
";
    /// 使い方の誤りの 1 行目。`{detail}` を置き換える
    pub const USAGE_ERROR: &str = "error: {detail}";
    pub const SEE_HELP: &str = "run `benitoite --help` for usage";
    pub const MISSING_COMMAND: &str = "missing subcommand";
    pub const UNKNOWN_COMMAND: &str = "unknown subcommand `{name}`";
    pub const UNKNOWN_OPTION: &str = "unknown option `{name}`";
    pub const BAD_VALUE: &str = "invalid value `{value}` for `{name}`";
    pub const MISSING_SCRIPT: &str = "missing script path";
    pub const EXTRA_ARGUMENT: &str = "unexpected argument `{value}`";
}
```

```rust sig=src/cli/mod.rs
use std::process::ExitCode;

/// `benitoite` の後のコマンドライン引数を解釈する（06-01「コマンドラインの形」「オプション」）。
/// 使い方の誤りは、`text` の型板から作った 1 行の説明を返す。
pub fn parse_args(args: Vec<OsString>) -> Result<Command, String>;

/// `--max-call-stack` の値（`512MiB` など）をバイト数にする。
pub fn parse_size(value: &str) -> Option<u64>;

/// CLI の入口。panic hook を設定してから、コマンドを実行して終了状態を返す（06-01「終了状態」）。
pub fn main() -> ExitCode;
```

開発用の設定として、CLI は環境変数 `BENITOITE_DEV_IO_MODE`（`direct` か `request`。06-01「開発用の設定」）を読む。それ以外の値は使い方の誤り（終了状態 2）とする。同じオプションを二度書いたときも使い方の誤りとする。

機能 `alloc-stats` を有効にしたビルドでは、環境変数 `BENITOITE_DEV_ALLOC_STATS` が `1` のとき、`run` の終わりに確保の統計（`AllocStats` の二つの値と解放の回数）を標準エラー出力に一行で書く。性能の測定（T31）で使う。加えて、処理系の不具合の報告を CLI の別プロセスのテストで確かめるために（07-03「前提」の「そのテストで panic を起こす手段は、実装プランで定める」）、デバッグビルド（`cfg!(debug_assertions)` が真）でだけ環境変数 `BENITOITE_DEV_PANIC` を読む。値が `check` なら、型検査の後、脱糖の前に Rust の `panic!` を起こす。値が `run` なら、本番のハンドラ表が最初の `Console.println` の内容を出力のバッファに加えた直後に `panic!` を起こす（出力のバッファを書き出してから処理系の不具合を報告する順序を確かめるため）。リリースビルドでは読まない。どちらの環境変数も利用者向けの文書に載せない。
