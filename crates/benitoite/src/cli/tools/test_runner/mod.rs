//! `benitoite test`（設計書 06-04「テストの実行」「結果の報告」、06-01「`test` のコマンドライン（初回リリース版）」、
//! 02-11「テストの実行」）。テストは一つずつ別の実行として順に動かす。

pub mod report;

use crate::base::{BindingId, Span};
use crate::bytecode::program::MainKind;
use crate::diag::render;
use crate::diag::{CallTrace, Diagnostic, TraceFrame};
use crate::runtime::assert::AssertOp;
use crate::runtime::report::FaultThread;

/// テストの関数一つ（06-04「テストの関数」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TestFn {
    /// 関数の名前
    pub function: String,
    /// `@test("…")` の説明。省いたときは `None`
    pub description: Option<String>,
    /// 関数の名前の span（JSON の `location`）
    pub location: Span,
    pub binding: BindingId,
    /// 戻り値の型
    pub kind: MainKind,
}

/// 失敗の理由と詳細（06-04「結果の報告」の表）。
#[derive(Clone, PartialEq, Debug)]
pub enum Failure {
    /// `Assert` の確認の失敗
    Assert {
        op: AssertOp,
        message: String,
        left: Option<String>,
        right: Option<String>,
        /// 失敗した確認の位置（操作を呼んだ命令の由来位置）
        primary: Option<Span>,
        trace: CallTrace,
        task_origins: Vec<TraceFrame>,
        /// 止める途中の解放の失敗の注記
        notes: Vec<String>,
    },
    /// `Result.Error(message)` を返した
    Error { message: String },
    /// 実行時エラーか資源の不足（解放の失敗の注記を加えた報告）
    Runtime { report: Box<Diagnostic> },
    /// `Process.exit` で止まった。`reports` は止める途中の解放の失敗の報告
    Exit {
        code: u8,
        die_failure: Option<crate::vm::DieFailure>,
        reports: Vec<Diagnostic>,
    },
}

/// テスト一つの結果。
#[derive(Clone, PartialEq, Debug)]
pub struct TestResult {
    pub test: TestFn,
    /// 成功なら `None`
    pub failure: Option<Failure>,
    /// 捕らえた標準出力と標準エラー出力
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
}

/// 集計（06-04「結果の報告」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct Summary {
    pub passed: u32,
    pub failed: u32,
    /// 検査の誤りか処理系の制限で実行しなかったファイルの数
    pub files_not_run: u32,
    /// 中断の要求で終えたか
    pub interrupted: bool,
}

/// 報告の文（02-10「文言の言語」、06-04「結果の報告」）。`{名前}` は埋める値。
pub mod text {
    pub const TEST_LINE: &str = "test {file}: {name} ... {outcome}";
    pub const OUTCOME_OK: &str = "ok";
    pub const OUTCOME_FAILED: &str = "FAILED";
    pub const FAILURES: &str = "failures:";
    pub const FAILURE_HEADER: &str = "---- {file}: {name} ----";
    /// `{operation}` は `Assert.equal` など
    pub const ASSERT_FAILED: &str = "assertion failed: {operation}";
    pub const LEFT: &str = "  left:  {value}";
    pub const RIGHT: &str = "  right: {value}";
    pub const MESSAGE: &str = "  message: {value}";
    pub const RETURNED_ERROR: &str = "returned `Result.Error`: {message}";
    pub const EXITED: &str = "called `Process.exit` with status {code}";
    pub const CAPTURED_STDOUT: &str = "---- captured stdout ----";
    pub const CAPTURED_STDERR: &str = "---- captured stderr ----";
    /// `{outcome}` は `OUTCOME_OK` か `OUTCOME_FAILED`
    pub const RESULT: &str = "test result: {outcome}. {passed} passed; {failed} failed";
    pub const FILES_NOT_RUN: &str = "; {count} files not run due to errors";
    pub const INTERRUPTED: &str = "; interrupted";
    /// 処理系の不具合の報告（`internal_diagnostic`）の段の名前
    pub const STAGE_TEST: &str = "test";
    /// `"exit"` の JSON の注記の前に付ける語（`codes::text::RELEASE_WHILE_STOPPING` と同じ文にする）
    pub(super) const RELEASE_STOPPING_PREFIX: &str = "while stopping, ";
    /// `"exit"` の JSON の注記で、報告の文と失敗の理由の間に置く語
    pub(super) const RELEASE_STOPPING_REASON_SEPARATOR: &str = ": ";
}

use std::path::PathBuf;

use super::args::PathArgs;
use crate::base::FileId;
use crate::cli::CliEnv;
use crate::modules::EntrySpec;
use crate::pipeline::CheckedProgram;

/// `benitoite test` を実行し、終了状態を返す（本章「結果の報告」）。
pub fn run_test_command(args: PathArgs, env: CliEnv) -> u8 {
    run_test_with_externals(args, env, Default::default())
}
pub(super) fn run_test_with_externals(
    args: PathArgs,
    env: CliEnv,
    externals: crate::external::stats::ExecutionOptions,
) -> u8 {
    let mut env = env;
    let format = args.diagnostics;
    let entries = match test_entries(&args.paths) {
        Ok(entries) => entries,
        Err((path, error)) => {
            // 読めないディレクトリはテストを一つも実行せずに終える。
            let diag = DiagBuilder::new(DiagCode::E0101)
                .arg("path", path.display().to_string())
                .arg("reason", error.to_string())
                .note("reason")
                .build();
            write_report(&env, format, &SourceTable::new(), &diag);
            return EXIT_CHECK;
        }
    };
    // 読み口はコマンドラインを解釈した後、最初の検査の前に一度だけ作る。
    let interrupt = match env.interrupt.take() {
        Some(interrupt) => interrupt,
        None => match run::process_interrupt() {
            Ok(interrupt) => interrupt,
            Err(error) => {
                return write_internal(
                    &env,
                    format,
                    &SourceTable::new(),
                    text::STAGE_TEST,
                    &error.to_string(),
                    None,
                    FaultThread::Stage,
                );
            }
        },
    };
    let mut runner = Runner {
        env,
        format,
        max_call_stack: args.max_call_stack.unwrap_or(DEFAULT_MAX_CALL_STACK),
        deny_warnings: args.deny_warnings,
        interrupt: SharedInterrupt(Rc::new(interrupt)),
        summary: Summary::default(),
        failures: Vec::new(),
        wrote_test_line: false,
        externals,
    };
    for entry in &entries {
        if runner.interrupt.requested() {
            runner.summary.interrupted = true;
            break;
        }
        match runner.run_file(entry) {
            Flow::Continue => {}
            Flow::Interrupted => {
                runner.summary.interrupted = true;
                break;
            }
            Flow::Exit(code) => return code,
        }
    }
    runner.finish()
}

/// 与えたパスから、テストするファイルの並びを作る（本章「ファイルごとの手順」の 1）。
/// 読めないディレクトリがあれば、そのパスと理由を返す。
pub fn test_entries(paths: &[PathBuf]) -> Result<Vec<EntrySpec>, (PathBuf, std::io::Error)> {
    let mut entries = Vec::new();
    for path in paths {
        if path.is_dir() {
            // 根のディレクトリを指定したディレクトリにし、表示名はディレクトリのパスに相対パスを続ける（06-04「テストの実行」）。
            for file in test_files(path)? {
                let relative = file.strip_prefix(path).unwrap_or(&file);
                entries.push(EntrySpec {
                    display_name: path.join(relative).display().to_string(),
                    path: file.clone(),
                    root: path.clone(),
                });
            }
        } else {
            match pipeline::entry_spec(path) {
                Ok(entry) => entries.push(entry),
                // ディレクトリでないパスでは起きない。起きたら読めないパスとして扱う。
                Err(EntryError::NoMainFile { dir }) => {
                    return Err((dir, std::io::Error::from(std::io::ErrorKind::NotFound)));
                }
            }
        }
    }
    Ok(entries)
}

// パッケージの中のソースは、そのパッケージを根として検査する。走査の段で枝を除き、
// そこにある読めないディレクトリも入口の探索には含めない（設計書 06-04「テストの実行」）。
fn test_files(root: &std::path::Path) -> Result<Vec<PathBuf>, (PathBuf, std::io::Error)> {
    super::args::collect_bnt_files(root, true)
}

/// 実行を始めるファイル `entry` のトップレベルの `@test` の関数を、宣言の順に集める（06-04「テストの実行」の
/// 「取り込むモジュールのテストの関数は実行しない」）。
pub fn collect_tests(checked: &CheckedProgram, entry: FileId) -> Vec<TestFn> {
    let mut tests = Vec::new();
    let Some(module) = checked.asts.iter().find(|module| module.file == entry) else {
        return tests;
    };
    for top in &module.decls {
        let Item::Fn(function) = &top.item else {
            continue;
        };
        let Some(attr) = top.attrs.iter().find(|attr| attr.name.text == "test") else {
            continue;
        };
        // 束縛か型がないのは検査を通ったプログラムでは起きない。呼び出し側が原型を引けずに処理系の不具合にする。
        let Some(&binding) = checked.resolved.decls.get(function.id) else {
            continue;
        };
        let kind = match checked.types.decl_types.get(binding) {
            Some(scheme) if scheme.ret == Ty::Con(TyCon::Builtin(BuiltinTy::UNIT), vec![]) => {
                MainKind::Unit
            }
            // 型検査（E0806）を通ったテストの関数の戻り値は `Unit` か `Result[Unit, String]` である。
            _ => MainKind::Result,
        };
        tests.push(TestFn {
            function: function.name.text.clone(),
            description: attr.args.first().map(|arg| arg.value.clone()),
            location: function.name.span,
            binding,
            kind,
        });
    }
    tests
}

use std::rc::Rc;
use std::sync::{Arc, Mutex};

use crate::base::SourceTable;
use crate::bytecode::program::CompiledProgram;
use crate::cli::{DiagFormat, prelude_error, report_check, write_internal, write_report};
use crate::diag::render::{TextOptions, Verb};
use crate::diag::{DiagBuilder, DiagCode, FrameName};
use crate::pipeline::{self, CheckOptions, CheckResult, CompileError, EntryError};
use crate::runtime::assert::AssertTable;
use crate::runtime::io::event::{InterruptGuard, Wakeup};
use crate::runtime::io::services::InterruptSource;
use crate::runtime::run::{
    self as run, EXIT_CHECK, EXIT_FAILURE, EXIT_INTERNAL, EXIT_INTERRUPTED, EXIT_OK, EndKind,
    OutputTarget, RunEnv, StdinSource, TestEnd, TestTarget,
};
use crate::runtime::{RuntimeError, Stop, panic as panic_boundary, report as runtime_report};
use crate::syntax::ast::Item;
use crate::types::builtin::BuiltinTypeId as BuiltinTy;
use crate::types::{Ty, TyCon};
use crate::vm::{DEFAULT_MAX_CALL_STACK, StopInfo};

// 一回の `test` の実行で作った中断の要求の読み口を、テストごとの `RunEnv` で共有する包み（設計書 02-11「テストの実行」）。
// 待ちを起こす読み口と Wasm の見張りに使う共有の印も渡し、どちらの実行中も中断できるようにする。
#[derive(Debug, Clone)]
struct SharedInterrupt(Rc<Box<dyn InterruptSource>>);

impl InterruptSource for SharedInterrupt {
    fn requested(&self) -> bool {
        self.0.requested()
    }
    fn attach(&self, wakeup: &Wakeup) -> std::io::Result<Option<InterruptGuard>> {
        self.0.attach(wakeup)
    }
    fn flag(&self) -> Option<&std::sync::atomic::AtomicBool> {
        self.0.flag()
    }
    fn shared_flag(&self) -> Option<std::sync::Arc<std::sync::atomic::AtomicBool>> {
        self.0.shared_flag()
    }
}

enum Flow {
    Continue,
    Interrupted,
    Exit(u8),
}

// 大きなスタックのスレッドで作り、呼び出し側へ返すもの。検査の AST はそのスレッドで捨てる。
struct Prepared {
    result: CheckResult,
    compiled: Option<Result<Compiled, PrepareError>>,
}

struct Compiled {
    program: CompiledProgram,
    tests: Vec<TestFn>,
    assert: Arc<AssertTable>,
}

enum PrepareError {
    Limit(Vec<Diagnostic>),
    Internal {
        stage: &'static str,
        message: String,
    },
}

struct Runner {
    env: CliEnv,
    format: DiagFormat,
    max_call_stack: u64,
    deny_warnings: bool,
    interrupt: SharedInterrupt,
    summary: Summary,
    /// 文章の形の失敗の詳細。ソースの表が使えるうちに文字列にして溜める。
    failures: Vec<String>,
    wrote_test_line: bool,
    externals: crate::external::stats::ExecutionOptions,
}

impl Runner {
    fn internal(&self, sources: &SourceTable, stage: &str, message: &str) -> Flow {
        Flow::Exit(write_internal(
            &self.env,
            self.format,
            sources,
            stage,
            message,
            None,
            FaultThread::Stage,
        ))
    }

    fn run_file(&mut self, entry: &EntrySpec) -> Flow {
        let deny_warnings = self.deny_warnings;
        let prepared = panic_boundary::catch(|| {
            pipeline::on_large_stack(|| panic_boundary::catch(|| prepare(entry, deny_warnings)))
        });
        let prepared = match prepared {
            Ok(Ok(Ok(prepared))) => prepared,
            Ok(Ok(Err(panic))) => {
                return Flow::Exit(write_internal(
                    &self.env,
                    self.format,
                    &SourceTable::new(),
                    "check",
                    &panic.message,
                    Some(&panic),
                    FaultThread::Stage,
                ));
            }
            Err(panic) => {
                return Flow::Exit(write_internal(
                    &self.env,
                    self.format,
                    &SourceTable::new(),
                    "check",
                    &panic.message,
                    Some(&panic),
                    FaultThread::Main,
                ));
            }
            Ok(Err(error)) => {
                return self.internal(&SourceTable::new(), "check", &error.to_string());
            }
        };
        let sources = Arc::clone(&prepared.result.sources);
        match report_check(
            &prepared.result,
            &self.env,
            self.format,
            Verb::Test,
            &entry.display_name,
        ) {
            Some(EXIT_CHECK) => {
                self.summary.files_not_run = self.summary.files_not_run.saturating_add(1);
                return Flow::Continue;
            }
            Some(code) => return Flow::Exit(code),
            None => {}
        }
        let compiled = match prepared.compiled {
            Some(Ok(compiled)) => compiled,
            Some(Err(PrepareError::Limit(diags))) => {
                match self.format {
                    DiagFormat::Text => {
                        let text = render::render_check_text(
                            &diags,
                            &sources,
                            Verb::Test,
                            &entry.display_name,
                            TextOptions {
                                color: self.env.color,
                            },
                        );
                        let _result = self.env.stderr.write_bytes(text.as_bytes());
                    }
                    DiagFormat::Json => {
                        for diag in &diags {
                            write_report(&self.env, self.format, &sources, diag);
                        }
                    }
                }
                self.summary.files_not_run = self.summary.files_not_run.saturating_add(1);
                return Flow::Continue;
            }
            Some(Err(PrepareError::Internal { stage, message })) => {
                return self.internal(&sources, stage, &message);
            }
            None => return self.internal(&sources, "check", "missing compilation result"),
        };
        let input = match run::run_input(entry, Vec::new(), self.env.working_directory.clone()) {
            Ok(input) => input,
            Err(error) => return self.internal(&sources, text::STAGE_TEST, &error.to_string()),
        };
        for test in compiled.tests {
            if self.interrupt.requested() {
                return Flow::Interrupted;
            }
            let Some(&(_, proto)) = compiled
                .program
                .top_fns
                .iter()
                .find(|(binding, _)| *binding == test.binding)
            else {
                return self.internal(
                    &sources,
                    text::STAGE_TEST,
                    "test function prototype missing",
                );
            };
            let stdout = Arc::new(Mutex::new(Vec::new()));
            let stderr = Arc::new(Mutex::new(Vec::new()));
            let end = run::run_test_with_externals(
                &compiled.program,
                TestTarget {
                    proto,
                    kind: test.kind,
                    assert: Arc::clone(&compiled.assert),
                },
                RunEnv {
                    input: input.clone(),
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                    stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                    interrupt: Box::new(self.interrupt.clone()),
                    // `RuntimeParts` は Clone できないので、テストごとの `RunEnv` には常に実際の実装を使う
                    // （設計書 02-11「テストの実行」）。
                    parts: None,
                    mode: self.env.mode,
                    vm: crate::vm::VmConfig {
                        max_call_stack_bytes: self.max_call_stack,
                        ..crate::vm::VmConfig::default()
                    },
                    heap: self.env.heap,
                    dev_panic_after_first_write: false,
                },
                self.externals.clone(),
            );
            match end.run.end {
                EndKind::Interrupted => {
                    for diag in &end.run.reports {
                        write_report(&self.env, self.format, &sources, diag);
                    }
                    return Flow::Interrupted;
                }
                EndKind::Internal => {
                    for diag in &end.run.reports {
                        write_report(&self.env, self.format, &sources, diag);
                    }
                    return Flow::Exit(EXIT_INTERNAL);
                }
                EndKind::Returned
                | EndKind::MainError
                | EndKind::Stopped
                | EndKind::Exited(_)
                | EndKind::CheckFailed => {}
            }
            let failure = match failure_of(&compiled.program, &test, end) {
                Ok(failure) => failure,
                Err(message) => return self.internal(&sources, text::STAGE_TEST, message),
            };
            let result = TestResult {
                test,
                failure,
                stdout: take_bytes(&stdout),
                stderr: take_bytes(&stderr),
            };
            if result.failure.is_some() {
                self.summary.failed = self.summary.failed.saturating_add(1);
            } else {
                self.summary.passed = self.summary.passed.saturating_add(1);
            }
            self.write_result(&entry.display_name, &result, &sources);
        }
        Flow::Continue
    }

    fn write_result(&mut self, file: &str, result: &TestResult, sources: &SourceTable) {
        let line = match self.format {
            DiagFormat::Text => {
                if result.failure.is_some() {
                    self.failures.push(report::text_failure(
                        file,
                        result,
                        sources,
                        self.stdout_options(),
                    ));
                }
                report::text_line(file, result)
            }
            DiagFormat::Json => format!("{}\n", report::json_test(file, result, sources)),
        };
        self.wrote_test_line = true;
        let _result = self.env.stdout.write_bytes(line.as_bytes());
    }

    // 報告は標準出力に書くので、色は標準出力も端末のときだけ付ける。
    fn stdout_options(&self) -> TextOptions {
        TextOptions {
            color: self.env.color && self.env.stdout.is_terminal(),
        }
    }

    fn finish(self) -> u8 {
        let mut output = String::new();
        match self.format {
            DiagFormat::Text => {
                if self.wrote_test_line {
                    output.push('\n');
                }
                if !self.failures.is_empty() {
                    output.push_str(text::FAILURES);
                    output.push_str("\n\n");
                    for failure in &self.failures {
                        output.push_str(failure);
                        output.push('\n');
                    }
                }
                output.push_str(&report::text_summary(&self.summary));
            }
            DiagFormat::Json => {
                output.push_str(&report::json_summary(&self.summary));
                output.push('\n');
            }
        }
        let _result = self.env.stdout.write_bytes(output.as_bytes());
        // 06-01「`test` のコマンドライン（初回リリース版）」の終了状態の表の、当たる行のうち最も上の行。
        if self.summary.interrupted {
            EXIT_INTERRUPTED
        } else if self.summary.files_not_run > 0 {
            EXIT_CHECK
        } else if self.summary.failed > 0 {
            EXIT_FAILURE
        } else {
            EXIT_OK
        }
    }
}

// 検査からコンパイルまで（設計書 06-04「テストの実行」）。大きなスタックのスレッドで行う。
fn prepare(entry: &EntrySpec, deny_warnings: bool) -> Prepared {
    let checked = pipeline::check(
        entry,
        &crate::modules::RealFs,
        CheckOptions {
            require_main: false,
            deny_warnings,
        },
    );
    let mut compiled = None;
    if let (Some(program), Some(file), None) = (
        checked.program.as_ref(),
        checked.entry,
        prelude_error(&checked),
    ) {
        compiled = Some(compile_tests(program, file, &checked.sources));
    }
    Prepared {
        result: CheckResult {
            sources: checked.sources,
            entry: checked.entry,
            diagnostics: checked.diagnostics,
            program: None,
        },
        compiled,
    }
}

fn compile_tests(
    program: &CheckedProgram,
    file: FileId,
    sources: &Arc<SourceTable>,
) -> Result<Compiled, PrepareError> {
    let tests = collect_tests(program, file);
    let assert = AssertTable::build(program).map_err(|message| PrepareError::Internal {
        stage: text::STAGE_TEST,
        message,
    })?;
    let core = pipeline::desugar_checked(program).map_err(|error| PrepareError::Internal {
        stage: error.stage,
        message: error.message,
    })?;
    let program = pipeline::compile(&core, Arc::clone(sources)).map_err(|error| match error {
        CompileError::Limit(diags) => PrepareError::Limit(diags),
        CompileError::Internal(error) => PrepareError::Internal {
            stage: error.stage,
            message: error.message,
        },
    })?;
    Ok(Compiled {
        program,
        tests,
        assert: Arc::new(assert),
    })
}

fn take_bytes(bytes: &Arc<Mutex<Vec<u8>>>) -> Vec<u8> {
    bytes
        .lock()
        .map(|mut bytes| std::mem::take(&mut *bytes))
        .unwrap_or_default()
}

// 実行の結果から失敗の詳細を作る。`Interrupted`・`Internal` は呼び出し側が扱う。
fn failure_of(
    program: &CompiledProgram,
    test: &TestFn,
    end: TestEnd,
) -> Result<Option<Failure>, &'static str> {
    let run = end.run;
    // 捕らえる出力先が失敗するのはミューテックスが毒されたときだけであり、
    // 書き出し用のスレッドの panic は先に処理系の不具合になる（設計書 02-09「panic 境界」）。
    if matches!(run.end, EndKind::Returned | EndKind::MainError) && !run.reports.is_empty() {
        return Err("output capture failed");
    }
    let failure = match run.end {
        EndKind::Returned => return Ok(None),
        EndKind::MainError => {
            let Some(message) = run.main_error else {
                return Err("main error message missing");
            };
            Failure::Error { message }
        }
        EndKind::Exited(code) => Failure::Exit {
            code,
            die_failure: run.die_failure,
            reports: run.reports,
        },
        EndKind::Stopped => {
            let Some(mut report) = run.reports.into_iter().next() else {
                return Err("runtime error report missing");
            };
            rename_main_task(&mut report.task_origins, &test.function);
            for waiting in &mut report.waiting {
                if is_main_frame(&waiting.task) {
                    waiting.task.name = FrameName::Named(test.function.clone());
                }
            }
            Failure::Runtime {
                report: Box::new(report),
            }
        }
        EndKind::CheckFailed => {
            let Some(check) = end.check_failure else {
                return Err("check failure record missing");
            };
            // 位置と履歴は実行時エラーの報告と同じ規則で作る。規則を書き写さず、位置と履歴を持つ任意の実行時エラーの
            // 報告から取り出す。
            let info = StopInfo {
                stop: Stop::Runtime(RuntimeError::DivisionByZero),
                at: Some(check.at),
                frames: check.frames,
                spawns: check.spawns,
                deadlock: Vec::new(),
            };
            let located = runtime_report::stop_diagnostic(program, &info);
            let Some(trace) = located.trace.clone() else {
                return Err("cannot build check failure trace");
            };
            let mut task_origins = located.task_origins;
            rename_main_task(&mut task_origins, &test.function);
            // 止める途中の解放の失敗は、中身のない報告に加えた注記の文を使う。
            let mut notes_holder = DiagBuilder::new(DiagCode::R0101).build();
            notes_holder.notes.clear();
            runtime_report::add_release_failures(&mut notes_holder, program, &end.release_failures);
            Failure::Assert {
                op: check.op,
                message: check.message,
                left: check.left,
                right: check.right,
                primary: located.primary.map(|label| label.span),
                trace,
                task_origins,
                notes: notes_holder.notes,
            }
        }
        EndKind::Interrupted | EndKind::Internal => return Err("unexpected test end"),
    };
    Ok(Some(failure))
}

// タスクの起動の履歴の最後の段（`main` の段）をテストの関数の名前にする（06-04「結果の報告」）。空の並びは空のまま。
fn rename_main_task(origins: &mut [TraceFrame], function: &str) {
    if let Some(last) = origins.last_mut() {
        last.name = FrameName::Named(function.to_owned());
    }
}

// `runtime::report` の `main_frame` が作る段（名前が `main` で位置なし）か。
fn is_main_frame(frame: &TraceFrame) -> bool {
    frame.call_site.is_none() && matches!(&frame.name, FrameName::Named(name) if name == "main")
}
