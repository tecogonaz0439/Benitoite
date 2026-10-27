//! `benitoite test`（設計書 06-04「テストの実行」「結果の報告」、06-01「`test` のコマンドライン（初回リリース版）」、
//! 02-11「テストの実行」）。テストは一つずつ別の実行として順に動かす。

mod check_report;
mod docs;
pub mod report;
pub(super) use check_report::usage_error as check_usage_error;

#[cfg(test)]
mod tests;

use crate::base::{BindingId, Span};
use crate::bytecode::program::MainKind;
use crate::diag::render;
use crate::diag::{CallTrace, Diagnostic, TraceFrame};
use crate::ir::InternalError;
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
    /// 検査の拒否や中断などで実行しなかった入口の数
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
    pub const FILES_NOT_RUN: &str = "; {count} files not run";
    pub const INTERRUPTED: &str = "; interrupted";
    /// 処理系の不具合の報告（`internal_diagnostic`）の段の名前
    pub const STAGE_TEST: &str = "test";
    /// `"exit"` の JSON の注記の前に付ける語（`codes::text::RELEASE_WHILE_STOPPING` と同じ文にする）
    pub(super) const RELEASE_STOPPING_PREFIX: &str = "while stopping, ";
    /// `"exit"` の JSON の注記で、報告の文と失敗の理由の間に置く語
    pub(super) const RELEASE_STOPPING_REASON_SEPARATOR: &str = ": ";
}

use std::path::{Path, PathBuf};

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
    if args.doc {
        return docs::run(args, env, externals);
    }
    if args.report.is_some() {
        return check_report::run(args, env);
    }
    let mut env = env;
    let format = args.diagnostics;
    let selection = select_test_entries(&args.paths);
    let entries = match selection.completion {
        Ok(()) => selection.entries,
        Err(SelectionFailure { path, error, .. }) => {
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
    let mut externals = externals;
    externals.session = Some(Rc::new(crate::external::ExternalSession::new(
        interrupt.shared_flag(),
    )));
    let mut runner = Runner {
        env,
        format,
        max_call_stack: args.max_call_stack.unwrap_or(DEFAULT_MAX_CALL_STACK),
        deny_warnings: args.deny_warnings,
        mode: if args.check {
            PrepareMode::Inspect
        } else if let Some(allowed) = &args.allow_effects {
            PrepareMode::ExecuteLimited(allowed)
        } else {
            PrepareMode::Execute
        },
        interrupt: SharedInterrupt(Rc::new(interrupt)),
        summary: Summary::default(),
        failures: Vec::new(),
        wrote_test_line: false,
        externals,
    };
    if args.allow_effects.is_some() {
        return runner.run_limited(entries);
    }
    for selected in &entries {
        let entry = &selected.entry;
        if runner.interrupt.requested() {
            runner.summary.interrupted = true;
            break;
        }
        let prepared = match runner.prepare(entry) {
            Ok(prepared) => prepared,
            Err(code) => return code,
        };
        match runner.run_prepared(entry, prepared) {
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
    let selection = select_test_entries(paths);
    selection
        .completion
        .map_err(|failure| (failure.path, failure.error))?;
    Ok(selection
        .entries
        .into_iter()
        .map(|selected| selected.entry)
        .collect())
}

// 完了と失敗を一つの結果で表し、失敗前に選び終えた入口を呼び出し元へ渡す。
// 探索失敗時の部分結果を使って検査や実行を始めてはならない（設計書 06-04「テストの実行」）。
struct EntrySelection {
    entries: Vec<SelectedEntry>,
    completion: Result<(), SelectionFailure>,
}

struct SelectedEntry {
    request_index: usize,
    entry: EntrySpec,
}

struct SelectionFailure {
    request_index: usize,
    path: PathBuf,
    error: std::io::Error,
}

fn select_test_entries(paths: &[PathBuf]) -> EntrySelection {
    let mut entries = Vec::new();
    for (request_index, path) in paths.iter().enumerate() {
        if path.is_dir() {
            let files = match test_files(path) {
                Ok(files) => files,
                Err(failure) => {
                    return EntrySelection {
                        entries,
                        completion: Err(SelectionFailure {
                            request_index,
                            path: failure.0,
                            error: failure.1,
                        }),
                    };
                }
            };
            // 根のディレクトリを指定したディレクトリにし、表示名はディレクトリのパスに相対パスを続ける（06-04「テストの実行」）。
            for file in files {
                let relative = file.strip_prefix(path).unwrap_or(&file);
                entries.push(SelectedEntry {
                    request_index,
                    entry: EntrySpec {
                        display_name: path.join(relative).display().to_string(),
                        path: file.clone(),
                        root: path.clone(),
                    },
                });
            }
        } else {
            match pipeline::entry_spec(path) {
                Ok(entry) => entries.push(SelectedEntry {
                    request_index,
                    entry,
                }),
                // ディレクトリでないパスでは起きない。起きたら読めないパスとして扱う。
                Err(EntryError::NoMainFile { dir }) => {
                    return EntrySelection {
                        entries,
                        completion: Err(SelectionFailure {
                            request_index,
                            path: dir,
                            error: std::io::Error::from(std::io::ErrorKind::NotFound),
                        }),
                    };
                }
            }
        }
    }
    EntrySelection {
        entries,
        completion: Ok(()),
    }
}

// パッケージの中のソースは、そのパッケージを根として検査する。走査の段で枝を除き、
// そこにある読めないディレクトリも入口の探索には含めない（設計書 06-04「テストの実行」）。
fn test_files(root: &std::path::Path) -> Result<Vec<PathBuf>, (PathBuf, std::io::Error)> {
    super::args::collect_bnt_files(root, true)
}

/// 実行を始めるファイル `entry` のトップレベルの `@test` の関数を、宣言の順に集める（06-04「テストの実行」の
/// 「取り込むモジュールのテストの関数は実行しない」）。
/// 入口の AST、テストの束縛か型が欠けていれば、処理系の不具合を返す。
pub fn collect_tests(
    checked: &CheckedProgram,
    entry: FileId,
) -> Result<Vec<TestFn>, InternalError> {
    let mut tests = Vec::new();
    let module = checked
        .asts
        .iter()
        .find(|module| module.file == entry)
        .ok_or_else(|| InternalError {
            stage: text::STAGE_TEST,
            message: "test entry module missing from checked program".into(),
        })?;
    for top in &module.decls {
        let Item::Fn(function) = &top.item else {
            continue;
        };
        let Some(attr) = top.attrs.iter().find(|attr| attr.name.text == "test") else {
            continue;
        };
        // 検査成功後の欠落でテストを除外すると、未実行のまま成功として報告してしまう（設計書 06-04「テストの実行」）。
        let &binding = checked
            .resolved
            .decls
            .get(function.id)
            .ok_or_else(|| InternalError {
                stage: text::STAGE_TEST,
                message: "test function binding missing from checked program".into(),
            })?;
        let scheme = checked
            .types
            .decl_types
            .get(binding)
            .ok_or_else(|| InternalError {
                stage: text::STAGE_TEST,
                message: "test function scheme missing from checked program".into(),
            })?;
        let kind = if scheme.ret == Ty::Con(TyCon::Builtin(BuiltinTy::UNIT), vec![]) {
            MainKind::Unit
        } else {
            // 型検査（E0806）を通ったテストの関数の戻り値は `Unit` か `Result[Unit, String]` である。
            MainKind::Result
        };
        tests.push(TestFn {
            function: function.name.text.clone(),
            description: attr.args.first().map(|arg| arg.value.clone()),
            location: function.name.span,
            binding,
            kind,
        });
    }
    Ok(tests)
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
use crate::runtime::io::services::{InterruptSource, RunInput};
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
    declaration_compilations: u64,
    result: CheckResult,
    compiled: Option<Result<Compiled, PrepareError>>,
    inspection: Option<Result<TestInspection, InternalError>>,
}

struct TestInspection {
    program: crate::cli::inspection::ProgramInspection,
    tests: Vec<TestFn>,
}

// 非実行の検査は実行用の成果物を作らない（設計書 06-04「テストの非実行の検査」）。
#[derive(Clone, Copy, PartialEq, Eq)]
enum PrepareMode<'a> {
    Inspect,
    Execute,
    ExecuteLimited(&'a crate::cli::EffectLimit),
}

struct Compiled {
    program: CompiledProgram,
    tests: Vec<PreparedTest>,
    assert: Arc<AssertTable>,
    input: RunInput,
}

// 原型を全件確認した一覧だけを実行へ渡し、先のテストの後で欠落に気付くことを防ぐ
// （設計書 02-11「テストの実行」）。
struct PreparedTest {
    test: TestFn,
    proto: crate::bytecode::program::ProtoIdx,
}

enum PrepareError {
    Limit(Vec<Diagnostic>),
    Internal {
        stage: &'static str,
        message: String,
    },
}

struct Runner<'a> {
    env: CliEnv,
    format: DiagFormat,
    max_call_stack: u64,
    deny_warnings: bool,
    mode: PrepareMode<'a>,
    interrupt: SharedInterrupt,
    summary: Summary,
    /// 文章の形の失敗の詳細。ソースの表が使えるうちに文字列にして溜める。
    failures: Vec<String>,
    wrote_test_line: bool,
    externals: crate::external::stats::ExecutionOptions,
}

impl Runner<'_> {
    fn run_limited(mut self, entries: Vec<SelectedEntry>) -> u8 {
        let count = match u32::try_from(entries.len()) {
            Ok(count) => count,
            Err(_) => {
                return write_internal(
                    &self.env,
                    self.format,
                    &SourceTable::new(),
                    text::STAGE_TEST,
                    "test entry count exceeds u32",
                    None,
                    FaultThread::Stage,
                );
            }
        };
        let mut ready = Vec::new();
        let mut rejected = false;
        for selected in entries {
            if self.interrupt.requested() {
                return self.reject_all(count, EXIT_INTERRUPTED);
            }
            let entry = selected.entry;
            let prepared = match self.prepare(&entry) {
                Ok(prepared) => prepared,
                Err(code) => return self.reject_all(count, code),
            };
            match self.validate_prepared(&entry, &prepared) {
                Ok(true) => ready.push((entry, prepared)),
                Ok(false) => rejected = true,
                Err(code) => return self.reject_all(count, code),
            }
        }
        // 全入口の準備から最初のファイルの実行へ進む前にも確認する
        // （設計書 02-11「テストの実行」）。拒否の報告直前には読み直さない。
        if self.interrupt.requested() {
            return self.reject_all(count, EXIT_INTERRUPTED);
        }
        if rejected {
            return self.reject_all(count, EXIT_CHECK);
        }
        // 検査した成果物だけを消費する。再探索・再検査・再コンパイルを挟まない
        // （設計書 02-11「テストの実行」）。
        for (entry, prepared) in ready {
            match self.execute_prepared(&entry, prepared) {
                Flow::Continue => {}
                Flow::Interrupted => {
                    self.summary.interrupted = true;
                    break;
                }
                Flow::Exit(code) => return code,
            }
        }
        self.finish()
    }

    fn reject_all(mut self, count: u32, code: u8) -> u8 {
        self.summary.files_not_run = count;
        self.summary.interrupted = code == EXIT_INTERRUPTED;
        self.write_summary();
        code
    }

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

    fn prepare(&self, entry: &EntrySpec) -> Result<Prepared, u8> {
        prepare_entry(
            entry,
            self.deny_warnings,
            self.mode,
            &self.env.working_directory,
        )
        .map_err(|diagnostic| {
            write_report(&self.env, self.format, &SourceTable::new(), &diagnostic);
            EXIT_INTERNAL
        })
    }

    // 診断は準備時に一度だけ出し、上限付きでは全入口の開始条件として使う
    // （設計書 06-04「テストの実行」）。
    fn validate_prepared(&mut self, entry: &EntrySpec, prepared: &Prepared) -> Result<bool, u8> {
        if let Some(stats) = &self.externals.stats {
            stats.declarations_compiled(prepared.declaration_compilations);
        }
        let sources = &prepared.result.sources;
        match report_check(
            &prepared.result,
            &self.env,
            self.format,
            Verb::Test,
            &entry.display_name,
        ) {
            Some(EXIT_CHECK) => {
                self.record_not_run(sources)?;
                return Ok(false);
            }
            Some(code) => return Err(code),
            None => {}
        }
        if self.mode == PrepareMode::Inspect {
            return match &prepared.inspection {
                Some(Ok(_)) => Ok(true),
                Some(Err(error)) => Err(write_internal(
                    &self.env,
                    self.format,
                    sources,
                    error.stage,
                    &error.message,
                    None,
                    FaultThread::Stage,
                )),
                None => Err(write_internal(
                    &self.env,
                    self.format,
                    sources,
                    "check",
                    "missing inspection result",
                    None,
                    FaultThread::Stage,
                )),
            };
        }
        match &prepared.compiled {
            Some(Ok(_)) => {}
            Some(Err(PrepareError::Limit(diags))) => {
                match self.format {
                    DiagFormat::Text => {
                        let text = render::render_check_text(
                            diags,
                            sources,
                            Verb::Test,
                            &entry.display_name,
                            TextOptions {
                                color: self.env.color,
                            },
                        );
                        let _result = self.env.stderr.write_bytes(text.as_bytes());
                    }
                    DiagFormat::Json => {
                        for diag in diags {
                            write_report(&self.env, self.format, sources, diag);
                        }
                    }
                }
                self.record_not_run(sources)?;
                return Ok(false);
            }
            Some(Err(PrepareError::Internal { stage, message })) => {
                return Err(write_internal(
                    &self.env,
                    self.format,
                    sources,
                    stage,
                    message,
                    None,
                    FaultThread::Stage,
                ));
            }
            None => {
                return Err(write_internal(
                    &self.env,
                    self.format,
                    sources,
                    "check",
                    "missing compilation result",
                    None,
                    FaultThread::Stage,
                ));
            }
        };
        Ok(true)
    }

    fn record_not_run(&mut self, sources: &SourceTable) -> Result<(), u8> {
        let count = self.summary.files_not_run.checked_add(1).ok_or_else(|| {
            write_internal(
                &self.env,
                self.format,
                sources,
                text::STAGE_TEST,
                "test entry count exceeds u32",
                None,
                FaultThread::Stage,
            )
        })?;
        self.summary.files_not_run = count;
        Ok(())
    }

    // 準備した成果物を消費し、検査したソースを開き直さず実行する（設計書 02-11「テストの実行」）。
    fn run_prepared(&mut self, entry: &EntrySpec, prepared: Prepared) -> Flow {
        match self.validate_prepared(entry, &prepared) {
            Ok(true) if self.mode != PrepareMode::Inspect => self.execute_prepared(entry, prepared),
            Ok(_) => Flow::Continue,
            Err(code) => Flow::Exit(code),
        }
    }

    fn execute_prepared(&mut self, entry: &EntrySpec, prepared: Prepared) -> Flow {
        let sources = prepared.result.sources;
        let Some(Ok(mut compiled)) = prepared.compiled else {
            return self.internal(&sources, "check", "validated compilation result missing");
        };
        for PreparedTest { test, proto } in std::mem::take(&mut compiled.tests) {
            if self.interrupt.requested() {
                return Flow::Interrupted;
            }
            let result = match self.execute_test(&compiled, test, proto, &sources) {
                Ok(result) => result,
                Err(flow) => return flow,
            };
            let count = if result.failure.is_some() {
                &mut self.summary.failed
            } else {
                &mut self.summary.passed
            };
            // 形式1の整数へ収まらない実数を、飽和した件数の成功として報告しない
            // （設計書 06-04「結果の報告」）。
            let Some(next) = count.checked_add(1) else {
                return self.internal(&sources, text::STAGE_TEST, "test count exceeds u32");
            };
            *count = next;
            self.write_result(&entry.display_name, &result, &sources);
        }
        Flow::Continue
    }

    fn execute_test(
        &self,
        compiled: &Compiled,
        test: TestFn,
        proto: crate::bytecode::program::ProtoIdx,
        sources: &SourceTable,
    ) -> Result<TestResult, Flow> {
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
                input: compiled.input.clone(),
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
                    write_report(&self.env, self.format, sources, diag);
                }
                return Err(Flow::Interrupted);
            }
            EndKind::Internal => {
                for diag in &end.run.reports {
                    write_report(&self.env, self.format, sources, diag);
                }
                return Err(Flow::Exit(EXIT_INTERNAL));
            }
            EndKind::Returned
            | EndKind::MainError
            | EndKind::Stopped
            | EndKind::Exited(_)
            | EndKind::CheckFailed => {}
        }
        let failure = match failure_of(&compiled.program, &test, end) {
            Ok(failure) => failure,
            Err(message) => return Err(self.internal(sources, text::STAGE_TEST, message)),
        };
        Ok(TestResult {
            test,
            failure,
            stdout: take_bytes(&stdout),
            stderr: take_bytes(&stderr),
        })
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
        if self.mode != PrepareMode::Inspect {
            self.write_summary();
        }
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

    fn write_summary(&self) {
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
    }
}

// 報告の形式によらず、同じ段の境界と破棄の位置を使う（設計書 02-11「テストの実行」）。
fn prepare_entry(
    entry: &EntrySpec,
    deny_warnings: bool,
    mode: PrepareMode<'_>,
    working_directory: &Path,
) -> Result<Prepared, Box<Diagnostic>> {
    let prepared = panic_boundary::catch(|| {
        pipeline::on_large_stack(|| {
            panic_boundary::catch(|| prepare(entry, deny_warnings, mode, working_directory))
        })
    });
    let diagnostic = match prepared {
        Ok(Ok(Ok(prepared))) => return Ok(prepared),
        Ok(Ok(Err(panic))) => runtime_report::internal_diagnostic(
            "check",
            &panic.message,
            Some(&panic),
            FaultThread::Stage,
        ),
        Err(panic) => runtime_report::internal_diagnostic(
            "check",
            &panic.message,
            Some(&panic),
            FaultThread::Main,
        ),
        Ok(Err(error)) => runtime_report::internal_diagnostic(
            "check",
            &error.to_string(),
            None,
            FaultThread::Stage,
        ),
    };
    Err(Box::new(diagnostic))
}

// 検査からコンパイルまで（設計書 06-04「テストの実行」）。大きなスタックのスレッドで行う。
fn prepare(
    entry: &EntrySpec,
    deny_warnings: bool,
    mode: PrepareMode<'_>,
    working_directory: &Path,
) -> Prepared {
    let (checked, declaration_compilations) = pipeline::check_with_external_compilation_count(
        entry,
        &crate::modules::RealFs,
        CheckOptions {
            require_main: false,
            deny_warnings,
        },
    );
    let inspection = if mode == PrepareMode::Inspect {
        if let (Some(program), Some(file), None) = (
            checked.program.as_ref(),
            checked.entry,
            prelude_error(&checked),
        ) {
            Some(collect_tests(program, file).and_then(|tests| {
                crate::cli::inspection::inspect_tests(program, &tests)
                    .map(|program| TestInspection { program, tests })
            }))
        } else {
            None
        }
    } else {
        None
    };
    let mut compiled = None;
    if mode != PrepareMode::Inspect
        && let (Some(program), Some(file), None) = (
            checked.program.as_ref(),
            checked.entry,
            prelude_error(&checked),
        )
    {
        compiled = Some(compile_tests(
            program,
            file,
            &checked.sources,
            entry,
            working_directory,
            match mode {
                PrepareMode::ExecuteLimited(allowed) => Some(allowed),
                PrepareMode::Inspect | PrepareMode::Execute => None,
            },
        ));
    }
    Prepared {
        declaration_compilations,
        result: CheckResult {
            sources: checked.sources,
            entry: checked.entry,
            diagnostics: checked.diagnostics,
            interval_analysis: checked.interval_analysis,
            program: None,
        },
        compiled,
        inspection,
    }
}

fn compile_tests(
    program: &CheckedProgram,
    file: FileId,
    sources: &Arc<SourceTable>,
    entry: &EntrySpec,
    working_directory: &Path,
    allowed: Option<&crate::cli::EffectLimit>,
) -> Result<Compiled, PrepareError> {
    let tests = collect_tests(program, file).map_err(|error| PrepareError::Internal {
        stage: error.stage,
        message: error.message,
    })?;
    compile_selected(program, tests, sources, entry, working_directory, allowed)
}

fn compile_selected(
    program: &CheckedProgram,
    tests: Vec<TestFn>,
    sources: &Arc<SourceTable>,
    entry: &EntrySpec,
    working_directory: &Path,
    allowed: Option<&crate::cli::EffectLimit>,
) -> Result<Compiled, PrepareError> {
    if let Some(allowed) = allowed {
        let diagnostics = tests
            .iter()
            .map(|test| {
                crate::cli::inspection::function_contract(
                    program,
                    test.binding,
                    &test.function,
                    test.location,
                )
                .map(|contract| crate::cli::effect_limit::check(&contract, allowed))
                .map_err(|error| PrepareError::Internal {
                    stage: error.stage,
                    message: error.message,
                })
            })
            .collect::<Result<Vec<_>, _>>()?
            .into_iter()
            .flatten()
            .collect::<Vec<_>>();
        if !diagnostics.is_empty() {
            return Err(PrepareError::Limit(diagnostics));
        }
    }
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
    let input =
        run::run_input(entry, Vec::new(), working_directory.to_path_buf()).map_err(|error| {
            PrepareError::Internal {
                stage: text::STAGE_TEST,
                message: error.to_string(),
            }
        })?;
    let tests = tests
        .into_iter()
        .map(|test| {
            let proto = program
                .top_fns
                .iter()
                .find(|(binding, _)| *binding == test.binding)
                .map(|(_, proto)| *proto)
                .ok_or_else(|| PrepareError::Internal {
                    stage: text::STAGE_TEST,
                    message: "test function prototype missing".into(),
                })?;
            Ok(PreparedTest { test, proto })
        })
        .collect::<Result<Vec<_>, PrepareError>>()?;
    Ok(Compiled {
        program,
        tests,
        assert: Arc::new(assert),
        input,
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
