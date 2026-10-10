# パイプラインと CLI

本章は、段をつなぐ公開の関数（検査・脱糖・コンパイル）、実行の流れ（`runtime::run`）、止まったときの報告（`runtime::report`）、CLI の型と関数のシグネチャを定める。テストは、処理系を別のプロセスとして起動せず、本章の関数を直接呼ぶ（07-03「前提」）。設計書の対応する章は[パイプライン](../../2026-10-09-design-first-release/02-impl/02-01-pipeline.md)、[ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「中断の要求」「panic 境界」「プログラムの実行の流れ」、[スクリプト実行と埋め込み](../../2026-10-09-design-first-release/02-impl/02-11-embedding.md)、[診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「実行時エラーと資源の不足の報告」「解放の失敗の報告」「処理系の不具合と処理系の制限の報告」、[CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md)である。

最小実行版の章（最小実行版の実装プランの 10-09）からの主な変更は次のとおりである。

- 検査は、実行を始めるファイルから import を辿ってプログラム全体を読む（ADR 0156）。ディレクトリを指定した実行とシェバンによる実行を加える（ADR 0127・0135）。
- 警告と `--deny-warnings` を加える（ADR 0166）。
- 実行の流れは、新しい VM とランタイムの上に作り直す。第 1 段の一時的な実行の関数から、第 2 段の IO 実行器へ中身を移しても、シグネチャを変えない。
- CLI は、`test`・`fmt`・`skill` の名前と予約した名前を受け付け、その中身の入口を U4 のために空けておく。
- CLI の実行の本体（`cli::execute`）を、プロセスの標準入出力に結び付けずに呼べる形にする。ゴールデンテストの実行器が、CLI と同じ報告の順序と形を、同じ関数で確かめるためである。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

- 置く作業: C02

本章のコードは C02 が置く。C01 の `lib.rs`（10-01）は `pipeline` と `cli` を、`runtime/mod.rs`（10-08）は `report` と `run` を宣言するので、C01 の時点で道具が中身のないモジュールを作り、C02 がそれを埋める。最小実行版の `pipeline.rs`・`cli/`・`runtime/report.rs`・`runtime/run.rs` は、C04 が `src/legacy/` へ移す。

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/pipeline.rs` | 置く（`file=` と `sig=`） | F18 |
| `src/runtime/run.rs` | 置く（`file=` と `sig=`） | F18（第 1 段の実行の関数で書く）、R26（第 2 段の IO 実行器へ移す）、R40（イベントループを使う `Wakeup` を作る）、R28（中断の要求） |
| `src/runtime/report.rs` | 置く（`file=` と `sig=`） | R38 |
| `src/cli/mod.rs` | 置く（`file=` と `sig=`） | F18 |
| `src/cli/tools.rs` | 置く（`sig=`） | F18（仮の中身）、U4（`test`・`fmt`・`skill`・`--licenses`） |
| `src/main.rs` | 本章はブロックを置かない。C05 が改める | C05 |

`main.rs` は、C04 が `benitoite::legacy::cli::main()` を呼ぶ形にしてある。C05 が、次の形（初回リリース版の CLI の入口を呼ぶ形）に改める（[README](../README.md) の作業一覧の C05、[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」）。

```text
fn main() -> std::process::ExitCode {
    benitoite::cli::main()
}
```

## パイプライン

### 検査の状態

02-11「状態の分け方」の検査の状態を、`CheckedProgram`（誤りのないとき）と `CheckResult` で表す。ソースの表は、読み込みを終えた時点で `Arc` に移し、以後は変更しない（02-02「ソースとファイル ID」）。

```rust file=src/pipeline.rs needs=10-02,10-03,10-04,10-05,10-06
//! 段をつなぐ公開の関数（設計書 02-01「段と段の間のデータ」「検査と実行の経路」「誤りが見つかったときの段の進め方」
//! 「関数の呼び出しと処理系のスタック」、02-11「実行を始めるファイルとプログラムの読み込み」、ADR 0019・0087・0156・0166）。

use std::path::PathBuf;
use std::sync::Arc;

use crate::base::{FileId, SourceTable};
use crate::diag::Diagnostic;
use crate::ir::InternalError;
use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Module;
use crate::syntax::token::Comment;
use crate::typeck::TypeckOutput;

/// 検査・脱糖・コンパイルの段を動かすスレッドのスタックの大きさ（64 MiB。02-01、ADR 0087）。
pub const STAGE_STACK_BYTES: usize = 64 * 1024 * 1024;

/// ディレクトリを指定したときに実行を始めるファイルの名前（06-01「ディレクトリの指定」、ADR 0127）。
pub const ENTRY_FILE_NAME: &str = "main.bnt";

/// 検査の選択肢。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct CheckOptions {
    /// `main` の有無と形を検査する。`check`・`run` で真、`test` で偽（10-05 の `typecheck`）
    pub require_main: bool,
    /// `--deny-warnings`（02-01「誤りが見つかったときの段の進め方」、ADR 0166）
    pub deny_warnings: bool,
}

/// 型検査までを誤りなく通ったプログラム。
#[derive(Debug)]
pub struct CheckedProgram {
    pub modules: ModuleTable,
    /// モジュールごとの AST。添字はモジュールの ID の値（10-04 の `LoadOutput::asts`）
    pub asts: Vec<Module>,
    /// モジュールごとのコメントの一覧（フォーマッタは使わない。フォーマッタは `lex` と `parse` を直接呼ぶ）
    pub comments: Vec<Vec<Comment>>,
    pub resolved: ResolveOutput,
    pub types: TypeckOutput,
}

/// 検査の結果。
#[derive(Debug)]
pub struct CheckResult {
    pub sources: Arc<SourceTable>,
    /// 実行を始めるファイルのファイル ID。読めなかったときは `None`
    pub entry: Option<FileId>,
    /// 誤りと警告。段の順に、同じ段の中ではファイル ID の順に、同じファイルの中ではソース上の位置の順に並べる
    /// （02-10「文章の形式」）。標準ライブラリのソースの中の警告は含めない（02-10「警告の扱い」）
    pub diagnostics: Vec<Diagnostic>,
    /// 誤りがなければ `Some`。`deny_warnings` のときは、警告もなければ `Some`
    pub program: Option<CheckedProgram>,
}

impl CheckResult {
    /// 誤りの数（`--deny-warnings` で誤りにした警告を含む）。
    pub fn error_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.is_error()).count()
    }

    pub fn warning_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.is_warning()).count()
    }
}

/// コンパイルの失敗。
#[derive(Debug)]
pub enum CompileError {
    /// 処理系の制限（`L` のコード）。`run` は終了状態 2 で終える
    Limit(Vec<Diagnostic>),
    /// 処理系の不具合。`run` は終了状態 3 で終える
    Internal(InternalError),
}

/// 実行を始めるファイルを決められない（CLI の使い方の誤り。終了状態 2。06-01「ディレクトリの指定」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum EntryError {
    /// 指定したディレクトリに `main.bnt` がない
    NoMainFile { dir: PathBuf },
}
```

### 段をつなぐ関数

次の関数の中身は F18 が書く。

```rust sig=src/pipeline.rs needs=10-04,10-06,10-07
use std::path::Path;

use crate::bytecode::program::CompiledProgram;
use crate::ir::core_ir::CoreProgram;
use crate::modules::{EntrySpec, ModuleFs};

/// コマンドラインで与えたパスから、実行を始めるファイルを決める（06-01「ディレクトリの指定」、02-02「ソースとファイル ID」の表示名）。
/// ディレクトリなら、その下の `main.bnt` を読むファイルとし、表示名をディレクトリのパスに `main.bnt` を続けた名前にする。
/// ディレクトリに `main.bnt` がなければ `EntryError::NoMainFile`。ファイル（と、存在しないパス）はそのまま読むファイルとし、
/// 表示名はパスの文字列（`Path::display`）とする。存在しないパスの誤りは、読み込みの段が E0101 にする。
/// 根のディレクトリは、読むファイルのあるディレクトリ（パスに親がなければ `.`）とする。
pub fn entry_spec(path: &Path) -> Result<EntrySpec, EntryError>;

/// 実行を始めるファイルから、読み込み・字句解析・構文解析・名前解決・型検査（定数の評価を含む）を行う
/// （02-01「検査と実行の経路」の `check`）。標準ライブラリのソースは 10-14 の表から読み込みの段に渡す。
/// 段の中身は `STAGE_STACK_BYTES` のスタックを持つスレッドで行う（ADR 0087）。そのスレッドの panic は段のスレッドの
/// 中で捕らえ、報告の種類が `Internal` の診断（段は `check`、スレッドは `Stage`）にして `diagnostics` に入れて返す。
pub fn check(entry: &EntrySpec, fs: &(dyn ModuleFs + Sync), opts: CheckOptions) -> CheckResult;

/// `entry_spec` と本番のファイルシステム（`RealFs`）で `check` を行う。
pub fn check_path(path: &Path, opts: CheckOptions) -> Result<CheckResult, EntryError>;

/// ファイルシステムを使わずに検査する（テストで使う）。`files` はパスと内容の組で、最初の要素が実行を始めるファイルである。
/// パスは仮の根のディレクトリからの相対パス（`main.bnt`、`Lib/Text.bnt`）で、表示名はそのパスとする。
pub fn check_files(files: &[(&str, &[u8])], opts: CheckOptions) -> CheckResult;

/// 一つのファイルだけからなるプログラムを検査する（`check_files` の略記。テストで使う）。`name` は表示名。
pub fn check_text(name: &str, text: &[u8], opts: CheckOptions) -> CheckResult;

/// 脱糖してコア IR を作る（10-06 の `desugar`）。`STAGE_STACK_BYTES` のスタックを持つスレッドで行う。
pub fn desugar_checked(checked: &CheckedProgram) -> Result<CoreProgram, InternalError>;

/// 判定の木への変換（10-06 の `lower_program`）とコード生成（10-07 の `codegen`）を行う。
/// `STAGE_STACK_BYTES` のスタックを持つスレッドで行う。
pub fn compile(core: &CoreProgram, sources: Arc<SourceTable>) -> Result<CompiledProgram, CompileError>;
```

`check` の手順は次のとおりである。

1. 検査ごとに `IdGen` を一つ作り、10-04 の `modules::load_program` で読み込み・字句解析・構文解析を行う。どれか一つのファイルに誤りがあれば、名前解決に進まない（ADR 0156）。
2. 10-04 の `resolve::resolve` で名前を解決する（読み込みの段のソースの表を渡す）。誤りがあれば、型検査に進まない（ADR 0019）。
3. 10-05 の `typecheck::typecheck` で型を検査する（読み込みの段のソースの表と `require_main` を渡す）。
4. 警告は、次の段に進むことを妨げない。`deny_warnings` のときは、型検査まで進めた後、警告が一つでもあれば、すべての警告に `Diagnostic::deny_warning` を適用し、`program` を `None` にする（02-01「誤りが見つかったときの段の進め方」）。途中の段で誤りがあって止めたときも、それまでの警告に同じく適用する。この判定と適用は、手順 5 で標準ライブラリのソースの中の警告を除いた後の一覧に対して行う（手順 5 を手順 4 より先に行う）。標準ライブラリのソースの中の警告だけで `program` を `None` にしないためである。
5. 標準ライブラリのソースの中を主な位置とする警告は、一覧から除く（02-10「警告の扱い」）。手順 4 より先に行う。
6. 各段の診断を、段の中でファイル ID と開始の位置の順に並べ替えて（同じ位置の診断は段が出した順を保つ）、段の順につなぐ。読み込みの段の診断も同じく並べ替える（02-10「検査の診断の順」。10-04 の `load_program` の出力の順は並べ替える前の順である）。

脱糖・判定の木への変換・コード生成は、型検査を通ったプログラムだけを受け取る。これらの段の `InternalError` は処理系の不具合であり、利用者のプログラムの誤りとして報告しない（02-01）。

## 止まったときの報告

`runtime::report` は、止まったときの記録（10-09 の `StopInfo`）、止める途中の解放の失敗（10-08 の `ReleaseFailure`）、捕らえた panic（10-08 の `PanicReport`）から、[診断](10-02-diagnostics.md)の `Diagnostic` を作る。報告を標準エラー出力に書くのは呼び出し側である。

```rust file=src/runtime/report.rs
//! 止まったときの報告の組み立て（設計書 02-08「実行時エラーの情報の記録」、02-10「実行時エラーと資源の不足の報告」
//! 「解放の失敗の報告」「処理系の不具合と処理系の制限の報告」）。
//! 報告を標準エラー出力に書くのは呼び出し側である。ここでは `Diagnostic` を作るだけにする。

/// 処理系の不具合が起きたスレッド（02-10「処理系の不具合と処理系の制限の報告」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FaultThread {
    /// 検査・脱糖・コンパイルの段（`pipeline` の段のスレッド）
    Stage,
    /// VM のスレッド
    Vm,
    /// 作業用のスレッド（10-10）
    Worker,
    /// 書き出し用のスレッド（10-10）
    Writer,
}

/// `Process.exit` と中断の要求で止める途中の解放の失敗の報告（`"release"`）の、止めた理由（02-10「解放の失敗の報告」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReleaseCause {
    Exit(u8),
    Interrupted,
}

/// 報告の型板に埋める値の語（ADR 0033）。
pub mod text {
    /// `FaultThread` の呼び名（`codes::text::INTERNAL_THREAD` の `{thread}`）
    pub const THREAD_STAGE: &str = "compiler";
    pub const THREAD_VM: &str = "VM";
    pub const THREAD_WORKER: &str = "worker";
    pub const THREAD_WRITER: &str = "output writer";
    /// リソースの型の名前（`ResourceKind` の順。R0401・R0402 の `{resource}`）
    pub const RESOURCE_FILE_READER: &str = "File.Reader";
    pub const RESOURCE_FILE_WRITER: &str = "File.Writer";
    pub const RESOURCE_HTTP_LISTENER: &str = "Http.Listener";
    pub const RESOURCE_HTTP_EXCHANGE: &str = "Http.Exchange";
    pub const RESOURCE_TASK_GROUP: &str = "TaskGroup";
    /// 行き詰まりで待つ種類（組み込みの関数のほか。`WaitingTask::waits_for`）
    pub const WAIT_LAZY: &str = "Lazy evaluation";
    pub const WAIT_HANDLE_END: &str = "handle end";
    pub const WAIT_TASK_GROUP_RELEASE: &str = "TaskGroup release";
    /// 出力の呼び名（`codes::text::FLUSH_FAILED_NOTE` の `{stream}`）
    pub const STDOUT_NAME: &str = "standard output";
    pub const STDERR_NAME: &str = "standard error";
    /// R0902・R0903 の `{unit}`
    pub const UNIT_BYTES: &str = "bytes";
    pub const UNIT_ELEMENTS: &str = "elements";
    /// 位置が分からないときに `{location}` に埋める値
    pub const UNKNOWN_LOCATION: &str = "<unknown>";
}
```

次の関数の中身は R38 が書く。R38 は、最小実行版の `src/legacy/runtime/report.rs` を写し、初回リリース版の `Stop`・`StopInfo`・原型の由来の種類（10-07）に合わせて広げる。

```rust sig=src/runtime/report.rs needs=10-02,10-07,10-08,10-09
use crate::base::Span;
use crate::bytecode::program::{CompiledProgram, ProtoIdx};
use crate::diag::{Diagnostic, FrameName};
use crate::runtime::panic::PanicReport;
use crate::runtime::{ReleaseFailure, Stream};
use crate::vm::{InstrRef, StopInfo};

/// 実行時エラー・資源の不足の報告を作る。`Stop` の値ごとのコードは 10-02「実行時エラー、資源の不足、処理系の制限」の表に従う。
/// 主な位置、呼び出しの履歴、タスクの起動の履歴は 02-08「実行時エラーの情報の記録」の 1〜4 で作る。
/// 書き込みの失敗は主な位置と履歴を持たない。行き詰まり（R1001）は主な位置を持たず、段のない履歴と、待つタスクの並びを持つ。
/// `Stop::Internal` は処理系の不具合の報告（`internal_diagnostic` と同じ形。スレッドは VM）にする。
pub fn stop_diagnostic(program: &CompiledProgram, info: &StopInfo) -> Diagnostic;

/// 実行時エラーか資源の不足で止める途中の解放の失敗を、先の報告に注記として加える（02-10「解放の失敗の報告」、ADR 0068）。
/// 注記は `codes::text::RELEASE_WHILE_STOPPING` の形で、末尾呼び出しの注記の前に置く。
pub fn add_release_failures(report: &mut Diagnostic, program: &CompiledProgram, failures: &[ReleaseFailure]);

/// `Process.exit` と中断の要求で止める途中の解放の失敗一つの報告（R0401、報告の種類 `Release`）。
/// 解放の失敗を報告しないリソースの型（`Http.Exchange`。ADR 0149）の失敗は、呼び出し側が渡さない。
pub fn release_report(program: &CompiledProgram, failure: &ReleaseFailure, cause: ReleaseCause) -> Diagnostic;

/// 出力の最後の転送の失敗の報告（R0201・R0202。主な位置と履歴を持たない。02-09「プログラムの実行の流れ」）。
pub fn write_failed(stream: Stream, reason: &str) -> Diagnostic;

/// 出力の最後の転送の失敗を、先の実行時エラーの報告に注記（`codes::text::FLUSH_FAILED_NOTE`）として加える。
pub fn add_flush_failure(report: &mut Diagnostic, stream: Stream, reason: &str);

/// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）。コードを持たないので `DiagBuilder` を使わず、
/// `Diagnostic` を直接組み立てる（kind は `Internal`、文言は `codes::text::INTERNAL_*`）。版・段・スレッド・panic の内容・
/// 報告を求める文を注記に、バックトレースを `backtrace` に入れる。`stage` は段の名前、`message` は不具合の説明。
pub fn internal_diagnostic(stage: &str, message: &str, panic: Option<&PanicReport>, thread: FaultThread) -> Diagnostic;

/// 原型の名前と由来の種類から、履歴の段の名前を作る（02-10「実行時エラーと資源の不足の報告」の名前の規則）。
/// 標準ライブラリの補助の関数は `None`（履歴に含めない）。
pub fn frame_name(program: &CompiledProgram, proto: ProtoIdx) -> Option<FrameName>;

/// 命令の由来位置。位置なしの命令と、表にない命令は `None`。
pub fn instr_span(program: &CompiledProgram, at: InstrRef) -> Option<Span>;
```

## 実行の流れ

`runtime::run` は、コンパイル済みプログラムを受け取った後の実行の流れ（02-09「プログラムの実行の流れ」の手順 1〜5）を行い、終わり方と報告を返す。報告を標準エラー出力に書くのは呼び出し側である（CLI、テストの実行器、ゴールデンテストの実行器）。呼び出し側は、`main_error` があればその文字列と改行を、続けて `reports` を、この順に書く。

実行の環境（`RunEnv`）は、出力先・標準入力・中断の要求の読み口・テストで差し替える部品を、呼び出し側が実行ごとに与える形にする（02-11「後から加える実行の形」の最後の段落）。CLI はプロセスの標準入出力を、テストの実行器（U4）とゴールデンテストの実行器（C10）はメモリに捕らえる出力先と空の標準入力を与える（ADR 0165）。

```rust file=src/runtime/run.rs needs=10-02,10-08,10-09,10-10
//! プログラムの実行の流れ（設計書 02-09「プログラムの実行の流れ」「中断の要求」「panic 境界」、
//! 02-11「CLI の一回の実行」「実行の入力と結果」、06-01「終了状態」、ADR 0037・0163・0165）。
//! 報告を標準エラー出力に書くのは呼び出し側（CLI、テストの実行器、ゴールデンテストの実行器）である。

use std::sync::{Arc, Mutex};

use crate::diag::Diagnostic;
use crate::runtime::heap::{HeapConfig, HeapStats};
use crate::runtime::io::services::{InterruptSource, RunInput};
use crate::runtime::sched::parts::RuntimeParts;
use crate::vm::{ExecMode, VmConfig};

/// 終了状態（06-01「終了状態」、ADR 0037・0163）。`Process.exit(code)` では `code`。
pub const EXIT_OK: u8 = 0;
pub const EXIT_FAILURE: u8 = 1;
pub const EXIT_CHECK: u8 = 2;
pub const EXIT_INTERNAL: u8 = 3;
pub const EXIT_INTERRUPTED: u8 = 130;

/// 出力先（02-11「実行の入力と結果」）。
#[derive(Clone, Debug)]
pub enum OutputTarget {
    /// 処理系のプロセスの標準出力
    Stdout,
    /// 処理系のプロセスの標準エラー出力
    Stderr,
    /// メモリに捕らえる。端末でない出力先として扱う（10-10「実装プランで決める値」）
    Capture(Arc<Mutex<Vec<u8>>>),
}

/// 標準入力（02-11「実行の入力と結果」）。
#[derive(Clone, Debug)]
pub enum StdinSource {
    /// 処理系のプロセスの標準入力（CLI の `run`）
    Process,
    /// 空の入力（テストの実行器）
    Empty,
    /// 与えたバイト列（ゴールデンテストの実行器）
    Bytes(Vec<u8>),
}

/// 中断の要求を受けない読み口（テストと、`check` の経路）。
#[derive(Clone, Copy, Debug, Default)]
pub struct NoInterrupt;

impl InterruptSource for NoInterrupt {
    fn requested(&self) -> bool {
        false
    }
}

/// 一回の実行の環境（02-09「プログラムの実行の流れ」の手順 2、02-11「実行の入力と結果」）。
#[derive(Debug)]
pub struct RunEnv {
    pub input: RunInput,
    pub stdin: StdinSource,
    pub stdout: OutputTarget,
    pub stderr: OutputTarget,
    pub interrupt: Box<dyn InterruptSource>,
    /// テストで差し替える部品（ADR 0274）。`None` は実際の実装。CLI と `benitoite test` は `None` を渡す。
    /// 第 1 段の実行の関数はタスクを持たないので、この欄を使わない
    pub parts: Option<RuntimeParts>,
    /// IO の命令の実行の方式（06-01「開発用の設定」の `BENITOITE_DEV_IO_MODE`）
    pub mode: ExecMode,
    pub vm: VmConfig,
    pub heap: HeapConfig,
    /// 開発用: 最初の書き込みを出力のバッファに加えた直後に Rust の panic を起こす（`BENITOITE_DEV_PANIC=run`）。
    /// 出力のバッファを書き出してから処理系の不具合を報告する順序を、CLI の別プロセスのテストで確かめるためにある。
    /// デバッグのビルドの CLI だけが真にする
    pub dev_panic_after_first_write: bool,
}

/// 終わり方（02-11「実行の入力と結果」の結果の表）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum EndKind {
    /// `main` が `()` か `Result.Ok(())` を返した
    Returned,
    /// `main` が `Result.Error(msg)` を返した
    MainError,
    /// 実行時エラーか資源の不足で止まった
    Stopped,
    /// `Process.exit(code)` で止まった
    Exited(u8),
    /// 中断の要求で止まった
    Interrupted,
    /// テストの確認の失敗で止まった（テストの実行器だけ。U4）
    CheckFailed,
    /// 処理系の不具合
    Internal,
}

/// 実行の結果（02-11「実行の入力と結果」）。出力の最後の転送は済ませてある。
#[derive(Debug)]
pub struct RunEnd {
    pub exit_code: u8,
    pub end: EndKind,
    /// `main` が返した `Result.Error` の文字列
    pub main_error: Option<String>,
    /// 実行時エラー・資源の不足・解放の失敗・書き込みの失敗・処理系の不具合の報告
    pub reports: Vec<Diagnostic>,
    /// 実行を終えたときのヒープの記録（CLI の `BENITOITE_DEV_ALLOC_STATS` と性能の測定が使う）
    pub heap: HeapStats,
}
```

次の関数の中身は、F18 が第 1 段の実行の関数（10-09 の `Vm::run_stage1`・`serve_request_stage1` と、R08 の第 1 段の `IoServices` の一時的な実装）で書き、R26 が第 2 段の IO 実行器（10-10 の `IoRuntime`・`Vm::run`・`serve_request`）へ移す。`process_interrupt` は、F18 が `NoInterrupt` を返す仮の中身を書き、R28 がシグナルを受ける中身に書き換える。どの段階でも、シグネチャは変えない。

```rust sig=src/runtime/run.rs needs=10-02,10-04,10-07,10-10
use std::ffi::OsString;
use std::path::PathBuf;

use crate::bytecode::program::CompiledProgram;
use crate::modules::EntrySpec;

impl OutputTarget {
    /// 報告を書く（CLI が診断と `main` の `Result.Error` の文字列を書くときに使う）。
    /// `Stdout` はプロセスの標準出力に、`Stderr` は標準エラー出力に書き、書いた後に flush する。
    /// `Capture` はバイト列の末尾に加える。
    pub fn write_bytes(&self, bytes: &[u8]) -> std::io::Result<()>;
    /// 出力先が端末か。`Stdout`・`Stderr` はそれぞれのストリームを `std::io::IsTerminal` で調べる。
    /// `Capture` は偽（10-10「実装プランで決める値」）。
    pub fn is_terminal(&self) -> bool;
}

/// 02-09「プログラムの実行の流れ」の手順 1。コマンドライン引数が正しい UTF-8 でなければ、
/// 最初に見つけた引数の位置（1 から数える）を示す R0301 の報告を返す。呼び出し側は終了状態 1 で終える。
pub fn check_args(args: Vec<OsString>) -> Result<Vec<String>, Box<Diagnostic>>;

/// 実行の入力を作る（02-11「実行の入力と結果」）。実行を始めるスクリプトのディレクトリは、`entry.path` の
/// シンボリックリンクを解決した絶対パスの親とし、実行を始めるときに一度だけ求める（ADR 0131）。
/// `working_directory` は基準のディレクトリ（CLI では処理系を起動したときの作業ディレクトリ）。
pub fn run_input(entry: &EntrySpec, arguments: Vec<String>, working_directory: PathBuf) -> std::io::Result<RunInput>;

/// プロセス全体の中断の印を読む読み口を作り、`SIGINT`・`SIGTERM`（Windows では Ctrl-C と Ctrl-Break）を受ける設定をする
/// （02-09「中断の要求」、ADR 0163）。二度目の要求で OS の既定の振る舞いが起きるように、一度目の後に登録を戻す。
/// CLI の `run` と `test` が、コマンドラインを解釈した後、検査の前に一度だけ呼ぶ（02-11「CLI の一回の実行」の手順 2）。
pub fn process_interrupt() -> std::io::Result<Box<dyn InterruptSource>>;

/// 02-09「プログラムの実行の流れ」の手順 2〜5。実行ごとの状態を作り、`main` を最初のタスクとして実行し、
/// 出力の最後の転送を標準出力、標準エラー出力の順に行ってから、終わり方・終了状態・報告を返す。
/// VM の実行を `runtime::panic::catch` で囲み、捕らえた panic は処理系の不具合（終了状態 3）にする。
pub fn run_program(program: &CompiledProgram, env: RunEnv) -> RunEnd;
```

`run_program` の終わり方と報告は、02-09「プログラムの実行の流れ」の表と、転送に失敗したときの規則に従う。10-09 の `VmStep` と `StopEnd` から、次のように決める。

| VM の結果 | `end` | 報告（`reports`） | 終了状態 |
|---|---|---|---|
| `Finished(MainOutcome::Ok)` | `Returned` | なし | 0 |
| `Finished(MainOutcome::Error(msg))` | `MainError` | なし（`main_error` に `msg`） | 1 |
| `Stopped` で理由が `Error(info)`、`info.stop` が `Stop::Internal` でない | `Stopped` | `stop_diagnostic` に `add_release_failures` で解放の失敗を加えたもの | 1 |
| `Stopped` で理由が `Error(info)`、`info.stop` が `Stop::Internal` | `Internal` | `stop_diagnostic`（処理系の不具合の報告） | 3 |
| `Stopped` で理由が `Exit(code)` | `Exited(code)` | 解放の失敗ごとに `release_report` | `code` |
| `Stopped` で理由が `Interrupted` | `Interrupted` | 解放の失敗ごとに `release_report` | 130 |
| `Stopped` で理由が `CheckFailed` | `CheckFailed` | [10-18](10-18-test-runner.md)「テストの関数の実行」の表で定める | 同左 |
| 捕らえた panic | `Internal` | `internal_diagnostic`（スレッドは `Vm`、作業用のスレッドと書き出し用のスレッドの panic はそのスレッド） | 3 |

出力の最後の転送に失敗したときは、`Returned`・`MainError` では `write_failed` の報告を加えて終了状態を 1 にし、`Stopped` では先の報告に `add_flush_failure` で注記を加え、`Exited`・`Interrupted` では `write_failed` の報告を加えて終了状態を変えない。`Internal` では転送の失敗を報告しない。

U4 のテストの実行器は、`main` の代わりにテストの関数を最初のタスクとして呼ぶ関数（`runtime::run::run_test`）を、`RunEnv` と `RunEnd` をそのまま使って加える（02-11「テストの実行」）。その関数と、`Assert.Check` の処理と `EndKind::CheckFailed` の報告は、[10-18](10-18-test-runner.md) で定める。

## CLI

### コマンドライン

`cli::parse_args` は、06-01「コマンドラインの形」「`run` を省いた実行とシェバン」「予約したサブコマンドの名前」「オプション」の規則でコマンドラインを解釈する。

- 最初の引数が `--help`・`--version`・`--licenses` なら、それぞれ `Help`・`Version`・`Licenses` とする。
- オプション（`-` で始まる引数）を除いた最初の引数が `run`・`check` なら、そのサブコマンドとし、名前の前後のオプションとスクリプトのパスを読む。スクリプトのパスより後の引数は、`-` で始まるものも含めて、解釈せずにスクリプトの引数とする。
- オプションを除いた最初の引数が `test`・`fmt`・`skill` なら、`Tool` とし、名前の前のオプションと名前の後の引数を、この順に解釈せずに渡す。
- オプションを除いた最初の引数が予約した名前（`RESERVED_COMMANDS`）なら、その機能がまだないことを示す使い方の誤りとする（ADR 0209）。
- それ以外は `run` を省いた実行とし、オプションとスクリプトのパスを読む（ADR 0135）。シェバンによる実行はこの形で起動される。
- 知らないオプション、値の誤ったオプション、同じオプションの二度の指定、スクリプトのパスがない場合、`check` のスクリプトのパスより後の引数は、使い方の誤りとする。

```rust file=src/cli/mod.rs needs=10-08,10-09,10-10
//! CLI（設計書 06-01）。初回リリース版のサブコマンドは `run`・`check`・`test`・`fmt`・`skill`。
//! `test`・`fmt`・`skill` と `--licenses` の中身は U4 が `tools` に書く。

pub mod tools;

use std::ffi::OsString;
use std::path::PathBuf;

use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::InterruptSource;
use crate::runtime::run::{OutputTarget, StdinSource};
use crate::runtime::sched::parts::RuntimeParts;
use crate::vm::{DEFAULT_MAX_CALL_STACK, ExecMode};

/// 診断の形式（`--diagnostics`）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DiagFormat {
    Text,
    Json,
}

/// `run` と `check` の選択肢（06-01「オプション」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Options {
    pub diagnostics: DiagFormat,
    /// `--max-call-stack` の値（バイト）
    pub max_call_stack: u64,
    /// `--deny-warnings`
    pub deny_warnings: bool,
}

impl Default for Options {
    fn default() -> Options {
        Options {
            diagnostics: DiagFormat::Text,
            max_call_stack: DEFAULT_MAX_CALL_STACK,
            deny_warnings: false,
        }
    }
}

/// U4 が中身を書くサブコマンド。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ToolCommand {
    Test,
    Fmt,
    Skill,
}

/// 解釈したコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Command {
    /// `run`、`run` を省いた実行、シェバンによる実行
    Run {
        options: Options,
        script: PathBuf,
        args: Vec<OsString>,
    },
    Check {
        options: Options,
        script: PathBuf,
    },
    /// `test`・`fmt`・`skill`。名前の前のオプションと名前の後の引数を、解釈せずに渡す（`tools::run_tool` が解釈する）
    Tool {
        tool: ToolCommand,
        args: Vec<OsString>,
    },
    Help,
    Version,
    Licenses,
}

/// 予約したサブコマンドの名前（06-01「予約したサブコマンドの名前」、ADR 0209）。
pub const RESERVED_COMMANDS: &[&str] = &[
    "server", "mcp", "sign", "verify", "repl", "lsp", "package", "agent",
];

/// 開発用の panic の指定（`BENITOITE_DEV_PANIC`。デバッグのビルドでだけ読む）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DevPanic {
    None,
    /// 型検査の後、脱糖の前に panic を起こす
    Check,
    /// 最初の書き込みを出力のバッファに加えた直後に panic を起こす（`RunEnv::dev_panic_after_first_write`）
    Run,
}

/// CLI の一回の実行の環境。`main` はプロセスの標準入出力で作り、ゴールデンテストの実行器（C10）は
/// メモリに捕らえる出力先で作る。
#[derive(Debug)]
pub struct CliEnv {
    /// `--help`・`--version`・`--licenses` の出力と、スクリプトの標準出力
    pub stdout: OutputTarget,
    /// 診断と報告と、スクリプトの標準エラー出力
    pub stderr: OutputTarget,
    pub stdin: StdinSource,
    /// 基準のディレクトリ（`main` は処理系を起動したときの作業ディレクトリ）
    pub working_directory: PathBuf,
    /// 文章の形式に色を付けるか（標準エラー出力が端末で、`NO_COLOR` がないとき。02-10「文章の形式」）
    pub color: bool,
    /// `BENITOITE_DEV_IO_MODE`（06-01「開発用の設定」）
    pub mode: ExecMode,
    /// 中断の要求の読み口。`None` なら、`run` の実行の前に `runtime::run::process_interrupt` で作る
    pub interrupt: Option<Box<dyn InterruptSource>>,
    /// テストで差し替える部品（ADR 0274）。`main` は `None`
    pub parts: Option<RuntimeParts>,
    pub heap: HeapConfig,
    pub dev_panic: DevPanic,
    /// `run` の終わりに確保の統計を標準エラー出力に一行で書く（機能 `alloc-stats` のビルドの `BENITOITE_DEV_ALLOC_STATS=1`）
    pub dev_alloc_stats: bool,
}

/// 使い方の誤りの文と、`--help`・`--version` の文（ADR 0033 に従い英語で書き、ここにまとめる）。
pub mod text {
    pub const USAGE: &str = "\
Usage:
  benitoite [options] <script> [script arguments...]
  benitoite run   [options] <script> [script arguments...]
  benitoite check [options] <script>
  benitoite test  [options] <path>...
  benitoite fmt   [options] <path>...
  benitoite skill install|uninstall [--user | --project] [--agent <name>]...
  benitoite --help
  benitoite --version
  benitoite --licenses

<script> is a .bnt file, or a directory that contains main.bnt.

Options:
  --diagnostics=text|json   format of diagnostics and error reports (default: text)
  --max-call-stack=<size>   limit for nested calls, such as 512MiB or 2GiB (default: 1GiB)
  --deny-warnings           treat warnings as errors
  --check                   (fmt) report files that would change without rewriting them
";
    /// `--version` の出力。`{version}` は処理系の版、`{unicode}` は文字の分類と変換が従う Unicode の版
    /// （Rust の `char::UNICODE_VERSION`。03-06「Character」、ADR 0169）
    pub const VERSION: &str = "benitoite {version}\nUnicode {unicode}\n";
    /// 使い方の誤りの 1 行目。`{detail}` を置き換える
    pub const USAGE_ERROR: &str = "error: {detail}";
    pub const SEE_HELP: &str = "run `benitoite --help` for usage";
    pub const MISSING_COMMAND: &str = "missing subcommand or script path";
    pub const RESERVED_COMMAND: &str =
        "`{name}` is reserved for a later version; to run a file with this name, write `./{name}`";
    pub const UNKNOWN_OPTION: &str = "unknown option `{name}`";
    pub const BAD_VALUE: &str = "invalid value `{value}` for `{name}`";
    pub const DUPLICATE_OPTION: &str = "option `{name}` may only be specified once";
    pub const MISSING_SCRIPT: &str = "missing script path";
    pub const EXTRA_ARGUMENT: &str = "unexpected argument `{value}`";
    pub const NO_MAIN_FILE: &str = "directory `{dir}` has no `main.bnt`";
    /// U4 の中身を入れる前の `test`・`fmt`・`skill`・`--licenses`（`tools` の仮の中身）
    pub const TOOL_UNAVAILABLE: &str = "`{name}` is not available in this build";
    /// `BENITOITE_DEV_ALLOC_STATS` の行
    pub const ALLOC_STATS: &str = "alloc-stats: allocations={allocations} allocated_bytes={allocated_bytes} peak_heap_bytes={peak_heap_bytes} collections={collections}";
}
```

次の関数の中身は F18 が書く。最小実行版の `src/legacy/cli/mod.rs` を写して広げる。

```rust sig=src/cli/mod.rs needs=10-08,10-09,10-10
use std::process::ExitCode;

/// `benitoite` の後のコマンドライン引数を解釈する（本章「コマンドライン」）。
/// 使い方の誤りは、`text` の型板から作った 1 行の説明（`USAGE_ERROR` の `{detail}` の部分）を返す。
pub fn parse_args(args: Vec<OsString>) -> Result<Command, String>;

/// `--max-call-stack` の値（`512MiB` など）をバイト数にする。
pub fn parse_size(value: &str) -> Option<u64>;

/// 解釈したコマンドを実行し、終了状態を返す（本章「コマンドの実行」）。出力は `env` の出力先に書く。
/// panic hook は設定しない（呼び出し側が設定する）。
pub fn execute(command: Command, env: CliEnv) -> u8;

/// CLI の入口。panic hook を設定し（`runtime::panic::install_hook`）、コマンドラインを解釈し、
/// 環境変数（`BENITOITE_DEV_IO_MODE`、デバッグのビルドの `BENITOITE_DEV_PANIC`、機能 `alloc-stats` のビルドの
/// `BENITOITE_DEV_ALLOC_STATS`、`NO_COLOR`）を読んでプロセスの標準入出力の `CliEnv` を作り、`execute` を呼ぶ。
/// 使い方の誤りは、`USAGE_ERROR` と `SEE_HELP` の 2 行を標準エラー出力に書き、終了状態 2 で終える。
pub fn main() -> ExitCode;
```

`BENITOITE_DEV_IO_MODE` の値は `direct` か `request` で、既定は `direct` とする。それ以外の値と、`BENITOITE_DEV_PANIC` の `check`・`run` 以外の値は、使い方の誤りとする。開発用の環境変数は利用者向けの文書に載せない（06-01「開発用の設定」）。

### U4 のサブコマンドの入口

`test`・`fmt`・`skill` と `--licenses` の中身は U4 が書く。CLI の振り分けは本章で決めるので、入口の関数のシグネチャを本章で凍結する。F18 は、U4 が中身を書くまでの仮の中身として、`text::TOOL_UNAVAILABLE` の使い方の誤りを `env.stderr` に書いて終了状態 2 を返す形を書く。U4 の作業は、この仮の中身を置き換える。

```rust sig=src/cli/tools.rs needs=10-08,10-09,10-10
//! U4 のサブコマンド（`test`・`fmt`・`skill`）と `--licenses` の入口（設計書 06-01）。中身は U4 の作業が書く。

use std::ffi::OsString;

use super::{CliEnv, ToolCommand};

/// `benitoite test|fmt|skill` の後の引数を解釈して実行し、終了状態を返す（06-01 の「`test` のコマンドライン」
/// 「`fmt` のコマンドライン」「`skill` のコマンドライン」の終了状態）。
pub fn run_tool(tool: ToolCommand, args: Vec<OsString>, env: CliEnv) -> u8;

/// 埋め込んだ第三者のライセンスを `env.stdout` に書き、終了状態を返す（06-01「コマンドラインの形」、ADR 0235）。
pub fn print_licenses(env: &CliEnv) -> u8;
```

### コマンドの実行

`cli::execute` は、02-11「CLI の一回の実行」の順に処理する。どの報告も `env.stderr` に、`--diagnostics` の形式で書く。文章の形式は 10-02 の `render_check_text`（検査の診断）と `render_one_text`（そのほかの報告）で、JSON の形式は `render_json_line` に改行を続けて書く。

`check` と `run` の共通の手順は次のとおりである。

1. `pipeline::entry_spec` で実行を始めるファイルを決める。`EntryError` は使い方の誤り（`text::NO_MAIN_FILE`）として終了状態 2 で終える。
2. `run` では、`env.interrupt` が `None` なら `runtime::run::process_interrupt` で中断の要求の読み口を作る（02-11 の手順 2）。`check` は中断の要求を扱わない。
3. `pipeline::check` を行う（`require_main` は真）。段のスレッドの panic は、`check` が報告の種類が `Internal` の診断にして返すので、その診断を報告し、終了状態 3 で終える。`DevPanic::Check` のときは、誤りのない検査の結果を得た後に panic を起こす。
4. 検査の誤りのうち、主な位置が標準ライブラリのソース（`SourceKind::Prelude`）の中にあるものが一つでもあれば、処理系の不具合とする（02-04「標準ライブラリのソースの持ち方」は、標準ライブラリのソースの誤りを処理系の不具合とした）。検査の診断を書かずに、`internal_diagnostic`（段は `check`、スレッドは `Stage`、`message` は最初のその誤りの文言を `render_one_text` の文章の形式で書いたもの。色は付けない）を書き、終了状態 3 で終える（02-10「処理系の不具合と処理系の制限の報告」）。利用者のプログラムの誤りとして終了状態 2 にしないのは、利用者が直せる誤りではないからである。
5. 検査の診断があれば、`render_check_text`（`Verb::Run` か `Verb::Check`、実行を始めるファイルの表示名）で書く。誤りがあれば終了状態 2 で終える。警告だけなら、`check` は終了状態 0 で終え、`run` は次へ進む（ADR 0166）。

`run` は続けて次を行う。

6. `runtime::panic::catch` で囲んで `pipeline::desugar_checked` と `pipeline::compile` を行う。`CompileError::Limit` は診断を書いて終了状態 2 で、`InternalError` と捕らえた panic は処理系の不具合の報告を書いて終了状態 3 で終える。
7. `runtime::run::check_args` でスクリプトの引数を検査する。R0301 の報告を書いて終了状態 1 で終える。
8. `runtime::run::run_input` で実行の入力を作る。失敗は処理系の不具合（段は `run`）とする。
9. `RunEnv` を作り（`vm.max_call_stack_bytes` は `--max-call-stack` の値）、`runtime::run::run_program` を行う。`main_error` があればその文字列と改行を、続けて `reports` を書き、`exit_code` で終える。`dev_alloc_stats` のときは、最後に `text::ALLOC_STATS` の行を書く。

`Help`・`Version`・`Licenses` は `env.stdout` に書き、終了状態 0 で終える（`Licenses` は `tools::print_licenses` の終了状態）。`Tool` は `tools::run_tool` の終了状態で終える。

## テストの実行器とゴールデンテストの実行器が使う口

本章の関数のうち、テストの実行器（U4）とゴールデンテストの実行器（C10）が使うものは次のとおりである。

| 使う側 | 使う口 | 用途 |
|---|---|---|
| C10 の `check`・`run` の方式 | `cli::parse_args`（`.options` のオプションとスクリプトのパスから組み立てる）、`cli::execute`（`CliEnv` の出力先を `Capture`、標準入力を `Empty` か `Bytes`、`interrupt` を `NoInterrupt`、`color` を偽にする） | CLI と同じ手順で、終了状態・標準出力・標準エラー出力を得て期待値と比べる（ADR 0224） |
| C10 の回収の強制と部品の差し替え | `CliEnv::heap`・`CliEnv::parts` | 回収を強制した実行と、順序を与えるスケジューラと仮想の時間での実行（ADR 0274） |
| C10・C14 の差分テスト | `pipeline::check`・`desugar_checked`・`compile`、10-06 の `refinterp::run`、`runtime::run::run_program` | 同じプログラムを参照インタプリタと VM で実行して比べる |
| F18 より後の作業（C11、R20 以降など）のテスト | `pipeline::check_files`・`check_text` | ファイルシステムを使わずに複数のモジュールを検査する。二つの関数の中身は F18 が書くので、F18 より前の作業（F05〜F16）は使えない |
| F05〜F16 の単体テスト | 作業ごとのテスト用の補助の関数（各作業のテストのモジュールに置く。10-04 の `modules::load_program` を `ModuleFs` のメモリの実装で呼び、その作業までの段を順に呼ぶ） | ファイルシステムを使わずに、その作業の段までを検査する。後の作業の段の中身に依存しない |
| U4 の `test` | `pipeline::check`（`require_main` を偽にし、`EntrySpec::root` を指定したディレクトリにする）、`desugar_checked`・`compile`、`RunEnv`・`RunEnd`（U4 が加えるテストの関数の実行の関数） | テストの関数ごとに別の実行として動かす（02-11「テストの実行」） |
| U4 の `fmt` | 10-03 の `lex`・`parse` | 構文だけを扱う（02-01「検査と実行の経路」） |

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C02 | `pipeline.rs`・`runtime/report.rs`・`runtime/run.rs`・`cli/mod.rs` の `file=` と、`cli/tools.rs` の `sig=` の `todo!()` の仮置き（00-02）を置く |
| F18 | `pipeline` の関数、`runtime::run` の関数（第 1 段の実行の関数で書く。`process_interrupt` は `NoInterrupt` を返す仮の中身）、`cli` の関数、`cli::tools` の仮の中身 |
| R38 | `runtime::report` の関数 |
| R26 | `runtime::run::run_program` を第 2 段の IO 実行器（10-10）に移す。`RunEnv::parts` と `StdinSource` を使う |
| R40 | `run_program` が `mio` を使う `Wakeup` を作る形に改める（10-10 の「イベントループ」） |
| R27 | 出力の最後の転送と、転送の失敗の扱い（`run_program` の中の `OutputPort::finish` の呼び出し） |
| R28 | `runtime::run::process_interrupt` の中身と、中断の要求で止める手順と解放の失敗の報告 |
| C05 | `main.rs` を `cli::main` を呼ぶ形に改める。CLI のプロセスのテスト（`tests/cli_process.rs`）を初回リリース版の CLI に移す |
| U4 | `cli::tools` の中身、テストの関数を実行する関数（`runtime::run` に加える） |

## 未定のこと

- 中断の要求を受けるためのシグナルの登録のクレートは、`signal-hook` 0.4.4 と `signal-hook-mio` 0.3.0 に決めた（2026-09-30、設計者の判断。[02-09](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)「中断の要求」、[実装の規約](../00-common/00-02-conventions.md)の「依存するクレート」）。待ちの間の要求でイベントループを起こす方法と、二度目の要求で OS の既定の振る舞いに戻す方法（02-09 が実装プランに委ねたもの）は、R28 の作業の文書で定める。
- `--licenses` の中身（埋め込む第三者のライセンスの表示）は、配布の作業（U4）が作る（ADR 0235）。
