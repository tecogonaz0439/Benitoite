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

use std::ffi::OsString;
use std::path::PathBuf;

use crate::bytecode::program::CompiledProgram;
use crate::modules::EntrySpec;

impl OutputTarget {
    /// 報告を書く（CLI が診断と `main` の `Result.Error` の文字列を書くときに使う）。
    /// `Stdout` はプロセスの標準出力に、`Stderr` は標準エラー出力に書き、書いた後に flush する。
    /// `Capture` はバイト列の末尾に加える。
    pub fn write_bytes(&self, bytes: &[u8]) -> std::io::Result<()> {
        use std::io::Write;
        match self {
            Self::Stdout => {
                let mut out = std::io::stdout().lock();
                out.write_all(bytes)?;
                out.flush()
            }
            Self::Stderr => {
                let mut out = std::io::stderr().lock();
                out.write_all(bytes)?;
                out.flush()
            }
            Self::Capture(out) => {
                out.lock()
                    .map_err(|_| std::io::Error::from(std::io::ErrorKind::Other))?
                    .extend_from_slice(bytes);
                Ok(())
            }
        }
    }
    /// 出力先が端末か。`Stdout`・`Stderr` はそれぞれのストリームを `std::io::IsTerminal` で調べる。
    /// `Capture` は偽（10-10「実装プランで決める値」）。
    pub fn is_terminal(&self) -> bool {
        use std::io::IsTerminal;
        match self {
            Self::Stdout => std::io::stdout().is_terminal(),
            Self::Stderr => std::io::stderr().is_terminal(),
            Self::Capture(_) => false,
        }
    }
}

/// 02-09「プログラムの実行の流れ」の手順 1。コマンドライン引数が正しい UTF-8 でなければ、
/// 最初に見つけた引数の位置（1 から数える）を示す R0301 の報告を返す。呼び出し側は終了状態 1 で終える。
pub fn check_args(args: Vec<OsString>) -> Result<Vec<String>, Box<Diagnostic>> {
    args.into_iter()
        .enumerate()
        .map(|(index, arg)| {
            arg.into_string().map_err(|_| {
                Box::new(
                    crate::diag::DiagBuilder::new(crate::diag::DiagCode::R0301)
                        .arg("index", index.saturating_add(1).to_string())
                        .build(),
                )
            })
        })
        .collect()
}

/// 実行の入力を作る（02-11「実行の入力と結果」）。実行を始めるスクリプトのディレクトリは、`entry.path` の
/// シンボリックリンクを解決した絶対パスの親とし、実行を始めるときに一度だけ求める（ADR 0131）。
/// `working_directory` は基準のディレクトリ（CLI では処理系を起動したときの作業ディレクトリ）。
pub fn run_input(
    entry: &EntrySpec,
    arguments: Vec<String>,
    working_directory: PathBuf,
) -> std::io::Result<RunInput> {
    let path = std::fs::canonicalize(&entry.path)?;
    let script_directory = path
        .parent()
        .ok_or_else(|| std::io::Error::other("script has no parent"))?
        .to_path_buf();
    Ok(RunInput {
        arguments,
        working_directory,
        script_directory,
    })
}

/// プロセス全体の中断の印を読む読み口を作り、`SIGINT`・`SIGTERM`（Windows では Ctrl-C と Ctrl-Break）を受ける設定をする
/// （02-09「中断の要求」、ADR 0163）。二度目の要求で OS の既定の振る舞いが起きるように、一度目の後に登録を戻す。
/// CLI の `run` と `test` が、コマンドラインを解釈した後、検査の前に一度だけ呼ぶ（02-11「CLI の一回の実行」の手順 2）。
pub fn process_interrupt() -> std::io::Result<Box<dyn InterruptSource>> {
    interrupt::register()
}

mod interrupt;

/// 02-09「プログラムの実行の流れ」の手順 2〜5。実行ごとの状態を作り、`main` を最初のタスクとして実行し、
/// 出力の最後の転送を標準出力、標準エラー出力の順に行ってから、終わり方・終了状態・報告を返す。
/// VM の実行を `runtime::panic::catch` で囲み、捕らえた panic は処理系の不具合（終了状態 3）にする。
pub fn run_program(program: &CompiledProgram, env: RunEnv) -> RunEnd {
    run_entry(program, env, &Entry::Main).run
}

// 最初のタスクにする関数（`main` かテストの関数）。
enum Entry {
    Main,
    Test(TestTarget),
}

// `run_program` と `run_test` に共通の手順 2〜5（設計書 02-09「プログラムの実行の流れ」、02-11「テストの実行」）。
fn run_entry(program: &CompiledProgram, env: RunEnv, entry: &Entry) -> TestEnd {
    let wakeup = if let Some(parts) = &env.parts {
        parts
            .workers
            .wakeup()
            .unwrap_or_else(super::io::event::wakeup_without_poll)
    } else {
        match super::io::event::wakeup_with_poll() {
            Ok(wakeup) => wakeup,
            Err(error) => {
                return plain(internal_end(&format!("cannot create event loop: {error}")));
            }
        }
    };
    let _interrupt_guard = if env.parts.is_none() {
        match env.interrupt.attach(&wakeup) {
            Ok(guard) => guard,
            Err(error) => {
                return plain(internal_end(&format!("cannot attach interrupt: {error}")));
            }
        }
    } else {
        None
    };
    let outputs = (
        super::io::output::OutputPort::start(
            Stream::Stdout,
            output_sink(env.stdout.clone()),
            env.stdout.is_terminal(),
            wakeup.clone(),
        ),
        super::io::output::OutputPort::start(
            Stream::Stderr,
            output_sink(env.stderr.clone()),
            env.stderr.is_terminal(),
            wakeup.clone(),
        ),
    );
    // stdin を消費する前に、子へ継がせるストリームを個別に決める（実装プラン 10-16、ADR 0165）。
    let process_stdio = super::io::services::ProcessStdio {
        inherit_stdin: matches!(env.stdin, StdinSource::Process),
        inherit_stdout: matches!(env.stdout, OutputTarget::Stdout),
        inherit_stderr: matches!(env.stderr, OutputTarget::Stderr),
    };
    let stdin: Box<dyn super::io::ops::StdinReader> = match env.stdin {
        StdinSource::Process => Box::new(std::io::BufReader::new(std::io::stdin())),
        StdinSource::Empty => Box::new(std::io::Cursor::new(Vec::<u8>::new())),
        StdinSource::Bytes(bytes) => Box::new(std::io::Cursor::new(bytes)),
    };
    let parts = env
        .parts
        .unwrap_or_else(|| RuntimeParts::real(wakeup.clone()));
    let mut rt = super::io::services::IoRuntime::new(
        env.input,
        env.mode,
        outputs,
        stdin,
        parts,
        env.interrupt,
        wakeup,
    );
    if let Err(error) = seed_hidden_random(&mut rt) {
        return plain(internal_end(&format!(
            "cannot seed hidden random generator: {error}"
        )));
    }
    rt.process_stdio = process_stdio;
    rt.dev_panic_after_first_write = env.dev_panic_after_first_write;
    run_vm_entry(program, env.vm, env.heap, rt, entry)
}
// テスト用の部品を使う実行にも、OS の種を一度入れる（設計書 03-07「Random」、実装プラン 10-16）。
fn seed_hidden_random(rt: &mut super::io::services::IoRuntime) -> Result<(), getrandom::Error> {
    rt.random_state = crate::builtins::funcs::random::seeded_state(getrandom::u64()?);
    Ok(())
}

fn plain(run: RunEnd) -> TestEnd {
    TestEnd {
        run,
        check_failure: None,
        release_failures: Vec::new(),
    }
}
// 出力先を所有する IO 実行器で実行し、報告より先に最後の転送を終える（設計書 02-09）。
#[cfg(test)]
fn run_vm(
    program: &CompiledProgram,
    config: VmConfig,
    heap: HeapConfig,
    rt: super::io::services::IoRuntime,
) -> RunEnd {
    run_vm_entry(program, config, heap, rt, &Entry::Main).run
}
fn run_vm_entry(
    program: &CompiledProgram,
    config: VmConfig,
    heap: HeapConfig,
    mut rt: super::io::services::IoRuntime,
    entry: &Entry,
) -> TestEnd {
    let mut vm = crate::vm::Vm::new(program, config, heap);

    let mut end = match crate::runtime::panic::catch(|| {
        let started = match entry {
            Entry::Main => vm.start_main(),
            Entry::Test(target) => {
                vm.start_test(target.proto, target.kind, Arc::clone(&target.assert))
            }
        };
        if let Err(info) = started {
            return crate::vm::VmStep::Stopped(crate::vm::StopEnd {
                reason: crate::vm::StopReason::Error(*info),
                release_failures: Vec::new(),
            });
        }
        loop {
            match vm.run(&mut rt) {
                crate::vm::VmStep::Requests(ids) => {
                    for id in ids {
                        vm.serve_request(&mut rt, id);
                    }
                }
                finished @ (crate::vm::VmStep::Finished(_) | crate::vm::VmStep::Stopped(_)) => {
                    return finished;
                }
            }
        }
    }) {
        Ok(VmStep::Stopped(crate::vm::StopEnd {
            reason: StopReason::CheckFailed(_),
            release_failures,
        })) if matches!(entry, Entry::Test(_)) => match vm.take_check_failure() {
            // 確認の失敗の報告は実行器が記録から作る（10-18「テストの関数の実行」の表）。
            Some(failure) => TestEnd {
                run: RunEnd {
                    exit_code: EXIT_FAILURE,
                    end: EndKind::CheckFailed,
                    main_error: None,
                    reports: Vec::new(),
                    heap: HeapStats::default(),
                },
                check_failure: Some(failure),
                release_failures,
            },
            None => plain(internal_end("check failure record missing")),
        },
        Ok(step) => plain(step_end(program, step)),
        Err(panic) => plain(RunEnd {
            reports: vec![report::internal_diagnostic(
                "run",
                &panic.message,
                Some(&panic),
                report::FaultThread::Vm,
            )],
            ..internal_end_fields()
        }),
    };
    if let Some(panic) = rt.worker_bug.take() {
        end = plain(RunEnd {
            reports: vec![report::internal_diagnostic(
                "run",
                &panic.message,
                Some(&panic),
                report::FaultThread::Worker,
            )],
            ..internal_end_fields()
        });
    }
    // panic の場合も標準出力、標準エラー出力の順に最後の転送を終える（設計書 02-09）。
    for port in [&mut rt.stdout, &mut rt.stderr] {
        if let Err(failure) = port.finish() {
            match failure {
                super::io::output::WriteFailure::Io(reason) => {
                    flush_failure(&mut end.run, port.stream, &reason)
                }
                super::io::output::WriteFailure::Panicked(panic) => {
                    end = plain(RunEnd {
                        reports: vec![report::internal_diagnostic(
                            "run",
                            &panic.message,
                            Some(&panic),
                            report::FaultThread::Writer,
                        )],
                        ..internal_end_fields()
                    });
                }
            }
        }
    }
    end.run.heap = vm.heap_stats();
    end
}

use crate::runtime::report;
use crate::runtime::{Stop, Stream};
use crate::vm::{MainOutcome, StopReason, VmStep};

fn internal_end_fields() -> RunEnd {
    RunEnd {
        exit_code: EXIT_INTERNAL,
        end: EndKind::Internal,
        main_error: None,
        reports: Vec::new(),
        heap: HeapStats::default(),
    }
}
fn internal_end(message: &str) -> RunEnd {
    RunEnd {
        reports: vec![report::internal_diagnostic(
            "run",
            message,
            None,
            report::FaultThread::Vm,
        )],
        ..internal_end_fields()
    }
}
fn step_end(program: &CompiledProgram, step: VmStep) -> RunEnd {
    let mut end = RunEnd {
        exit_code: EXIT_OK,
        end: EndKind::Returned,
        main_error: None,
        reports: Vec::new(),
        heap: HeapStats::default(),
    };
    match step {
        VmStep::Finished(MainOutcome::Ok) => {}
        VmStep::Finished(MainOutcome::Error(message)) => {
            end.end = EndKind::MainError;
            end.exit_code = EXIT_FAILURE;
            end.main_error = Some(message);
        }
        VmStep::Requests(_) => {
            return internal_end("stage 1 execution ended with pending requests");
        }
        VmStep::Stopped(stopped) => match stopped.reason {
            StopReason::Error(info) => {
                let mut diagnostic = report::stop_diagnostic(program, &info);
                end.end = if matches!(info.stop, Stop::Internal(_)) {
                    EndKind::Internal
                } else {
                    report::add_release_failures(
                        &mut diagnostic,
                        program,
                        &stopped.release_failures,
                    );
                    EndKind::Stopped
                };
                end.exit_code = if end.end == EndKind::Internal {
                    EXIT_INTERNAL
                } else {
                    EXIT_FAILURE
                };
                end.reports.push(diagnostic);
            }
            StopReason::Exit(code) => {
                end.end = EndKind::Exited(code);
                end.exit_code = code;
                end.reports = stopped
                    .release_failures
                    .iter()
                    .map(|failure| {
                        report::release_report(program, failure, report::ReleaseCause::Exit(code))
                    })
                    .collect();
            }
            StopReason::Interrupted => {
                end.end = EndKind::Interrupted;
                end.exit_code = EXIT_INTERRUPTED;
                end.reports = stopped
                    .release_failures
                    .iter()
                    .map(|failure| {
                        report::release_report(program, failure, report::ReleaseCause::Interrupted)
                    })
                    .collect();
            }
            StopReason::CheckFailed(_) => return internal_end("main ended with CheckFailed"),
        },
    }
    end
}
fn flush_failure(end: &mut RunEnd, stream: Stream, reason: &str) {
    match end.end {
        EndKind::Returned | EndKind::MainError => {
            end.exit_code = EXIT_FAILURE;
            end.reports.push(report::write_failed(stream, reason));
        }
        EndKind::Stopped => {
            if let Some(diagnostic) = end.reports.first_mut() {
                report::add_flush_failure(diagnostic, stream, reason);
            }
        }
        EndKind::Exited(_) | EndKind::Interrupted => {
            end.reports.push(report::write_failed(stream, reason))
        }
        EndKind::Internal | EndKind::CheckFailed => {}
    }
}

// 出力先は書き出し用のスレッドが所有する。書き込みの失敗を最後の転送で報告する（設計書 02-09）。
struct TargetWriter(OutputTarget);
impl std::io::Write for TargetWriter {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        self.0.write_bytes(bytes)?;
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
fn output_sink(target: OutputTarget) -> Box<dyn std::io::Write + Send> {
    Box::new(TargetWriter(target))
}
impl super::io::ops::StdinReader for std::io::Cursor<Vec<u8>> {}
impl super::io::ops::StdinReader for std::io::BufReader<std::io::Stdin> {}

#[cfg(test)]
mod tests {
    // 関門: 出力の最終転送が失敗した場合の終了状態と報告、開始時の失敗を公開の run_program で確かめる。
    // VM と IO の単独のテストは、最後の転送で失敗した後の終わり方の分類を捕まえない（設計書 02-09）。
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    mod interrupt;
    mod test_entry;
    fn compiled(source: &str) -> CompiledProgram {
        crate::pipeline::on_large_stack(|| {
            let checked = crate::pipeline::check_text(
                "main.bnt",
                source.as_bytes(),
                crate::pipeline::CheckOptions {
                    require_main: true,
                    deny_warnings: false,
                },
            );
            assert!(checked.program.is_some(), "{:?}", checked.diagnostics);
            let core = crate::pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
            crate::pipeline::compile(&core, checked.sources).unwrap()
        })
        .unwrap()
    }
    fn environment() -> RunEnv {
        RunEnv {
            input: RunInput {
                arguments: vec![],
                working_directory: "/".into(),
                script_directory: "/".into(),
            },
            stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            stdin: StdinSource::Empty,
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode: ExecMode::Direct,
            vm: VmConfig::default(),
            heap: HeapConfig::default(),
            dev_panic_after_first_write: false,
        }
    }
    // 関門: VM で捕えた仕事の panic を VM のスレッドと報告する退行を、実行の結果で捕まえる（R26）。
    #[test]
    fn panicked_external_work_is_reported_as_worker_failure() {
        use super::super::io::ops::{Completion, JobWork, WorkerJob};
        use super::super::sched::parts::{IdleWake, WorkerExec};
        #[derive(Debug, Default)]
        struct PanickingWork(std::collections::VecDeque<Completion>);
        impl WorkerExec for PanickingWork {
            fn submit(&mut self, mut job: WorkerJob) {
                job.work = JobWork::Builtin(crate::builtins::iface::WorkerWait::new(
                    crate::builtins::iface::Lend::Nothing,
                    |_| panic!("external work panic"),
                    |_, _: (), _| Ok(crate::runtime::heap::Value::Unit),
                ));
                self.0.push_back(super::super::io::ops::execute_job(job));
            }
            fn try_recv(&mut self) -> Option<Completion> {
                self.0.pop_front()
            }
            fn idle(&mut self, _: Option<u64>) -> IdleWake {
                IdleWake::Progress
            }
        }
        crate::runtime::panic::install_hook();
        let program = compiled(
            "import Benitoite.Unofficial.IO.File\nfunction main() -> Unit uses File.Read\n bind _ <- File.readText(\"unused\")\n return ()\nend function\n",
        );
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut env = environment();
            env.mode = mode;
            let script = crate::runtime::sched::testing::ScheduleHandle::new([], false);
            let mut parts = script.parts();
            parts.workers = Box::<PanickingWork>::default();
            env.parts = Some(parts);
            let end = run_program(&program, env);
            assert_eq!(end.end, EndKind::Internal);
            assert_eq!(end.exit_code, EXIT_INTERNAL);
            assert_eq!(end.reports.len(), 1);
            assert!(
                end.reports[0]
                    .notes
                    .iter()
                    .any(|note| note.contains("worker")),
                "{:?}",
                end.reports
            );
        }
    }
    fn poisoned() -> OutputTarget {
        let out = Arc::new(Mutex::new(Vec::new()));
        assert!(
            std::panic::catch_unwind(|| {
                let _guard = out.lock().unwrap();
                panic!("external capture failed");
            })
            .is_err()
        );
        // 別の失敗を模擬するための panic の記録を、本体の panic 境界へ持ち越さない。
        drop(crate::runtime::panic::take_report());
        OutputTarget::Capture(out)
    }
    // 関門: writer の失敗と panic の分類を、run_program と同じ実行・最後の転送の経路で確かめる。
    // 出力先だけを置き換える。RunEnv の凍結した OutputTarget にテスト専用の種類を加えない。
    #[test]
    fn writer_failure_and_panic_finish_with_the_required_reports() {
        struct FaultyWriter(bool);
        impl std::io::Write for FaultyWriter {
            fn write(&mut self, _: &[u8]) -> std::io::Result<usize> {
                assert!(!self.0, "writer test panic");
                Err(std::io::ErrorKind::BrokenPipe.into())
            }
            fn flush(&mut self) -> std::io::Result<()> {
                Ok(())
            }
        }
        for (kind, body) in [
            (EndKind::Returned, "return ()"),
            (EndKind::MainError, "return Result.Error(\"bad\")"),
            (EndKind::Stopped, "bind _ <- 1 div 0\n return ()"),
        ] {
            let ty = if kind == EndKind::MainError {
                "Result[Unit,String]"
            } else {
                "Unit"
            };
            let program = compiled(&format!(
                "import Benitoite.Unofficial.IO.Console\nfunction main() -> {ty} uses Console.Write\n Console.write(\"last\")\n {body}\nend function\n"
            ));
            for mode in [ExecMode::Direct, ExecMode::Request] {
                for panic in [false, true] {
                    let env = environment();
                    let wakeup = super::super::io::event::wakeup_with_poll().unwrap();
                    let outputs = (
                        super::super::io::output::OutputPort::start(
                            Stream::Stdout,
                            Box::new(FaultyWriter(panic)),
                            false,
                            wakeup.clone(),
                        ),
                        super::super::io::output::OutputPort::start(
                            Stream::Stderr,
                            Box::new(std::io::sink()),
                            false,
                            wakeup.clone(),
                        ),
                    );
                    let rt = super::super::io::services::IoRuntime::new(
                        env.input,
                        mode,
                        outputs,
                        Box::new(std::io::Cursor::new(Vec::<u8>::new())),
                        RuntimeParts::real(wakeup.clone()),
                        env.interrupt,
                        wakeup,
                    );
                    let end = run_vm(&program, env.vm, env.heap, rt);
                    assert_eq!(
                        end.exit_code,
                        if panic { EXIT_INTERNAL } else { EXIT_FAILURE }
                    );
                    assert_eq!(end.reports.len(), 1);
                    if panic {
                        assert_eq!(end.end, EndKind::Internal);
                        assert!(
                            end.reports[0]
                                .notes
                                .iter()
                                .any(|n| n.contains("output writer"))
                        );
                    } else {
                        assert_eq!(end.end, kind);
                        assert_eq!(
                            end.reports[0].code,
                            Some(if kind == EndKind::Stopped {
                                crate::diag::DiagCode::R0101
                            } else {
                                crate::diag::DiagCode::R0201
                            })
                        );
                        if kind == EndKind::MainError {
                            assert_eq!(end.main_error.as_deref(), Some("bad"));
                        }
                        if kind == EndKind::Stopped {
                            assert!(
                                end.reports[0]
                                    .notes
                                    .iter()
                                    .any(|n| n.contains("standard output"))
                            );
                        }
                    }
                }
            }
        }
    }
    #[test]
    fn development_panic_returns_only_after_accepted_output_is_transferred() {
        let program = compiled(
            "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n Console.write(\"before panic\")\nend function\n",
        );
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut env = environment();
            let OutputTarget::Capture(bytes) = &env.stdout else {
                panic!("capture missing")
            };
            let bytes = Arc::clone(bytes);
            env.dev_panic_after_first_write = true;
            env.mode = mode;
            let end = run_program(&program, env);
            assert_eq!(end.end, EndKind::Internal);
            assert_eq!(end.exit_code, EXIT_INTERNAL);
            assert_eq!(end.reports.len(), 1);
            assert_eq!(bytes.lock().unwrap().as_slice(), b"before panic");
        }
    }
    #[test]
    fn final_output_failure_preserves_the_reason_for_ending_and_reports_once() {
        for (body, end_kind, code, report_code, note) in [
            (
                "()",
                EndKind::Returned,
                EXIT_FAILURE,
                crate::diag::DiagCode::R0201,
                false,
            ),
            (
                "return Result.Error(\"bad\")",
                EndKind::MainError,
                EXIT_FAILURE,
                crate::diag::DiagCode::R0201,
                false,
            ),
            (
                "bind _ <- 1 div 0",
                EndKind::Stopped,
                EXIT_FAILURE,
                crate::diag::DiagCode::R0101,
                true,
            ),
        ] {
            let result_type = if end_kind == EndKind::MainError {
                "Result[Unit, String]"
            } else {
                "Unit"
            };
            let source = format!(
                "import Benitoite.Unofficial.IO.Console\nfunction main() -> {result_type} uses Console.Write\n Console.writeLine(\"first\")\n Console.writeLine(\"second\")\n {body}\nend function\n"
            );
            let program = compiled(&source);
            let mut env = environment();
            env.stdout = poisoned();
            let end = run_program(&program, env);
            assert_eq!(end.end, end_kind);
            assert_eq!(end.exit_code, code);
            assert_eq!(end.reports.len(), 1);
            assert_eq!(end.reports[0].code, Some(report_code));
            if note {
                assert!(
                    end.reports[0]
                        .notes
                        .iter()
                        .any(|n| n.contains("standard output"))
                );
            }
            if end_kind == EndKind::MainError {
                assert_eq!(end.main_error.as_deref(), Some("bad"));
            }
        }
    }
    #[test]
    fn start_main_failure_invalid_targets_and_panic_are_internal() {
        let source = "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n Console.writeLine(\"before panic\")\nend function\n";
        let mut program = compiled(source);
        let mut env = environment();
        env.stdout = poisoned();
        env.dev_panic_after_first_write = true;
        let end = run_program(&program, env);
        assert_eq!(end.end, EndKind::Internal);
        assert_eq!(end.exit_code, EXIT_INTERNAL);
        assert_eq!(end.reports.len(), 1);
        assert_eq!(end.reports[0].kind, crate::diag::ReportKind::Internal);
        let mut env = environment();
        env.stdout = OutputTarget::Stdout;
        assert_eq!(run_program(&program, env).end, EndKind::Returned);
        program.main = None;
        let end = run_program(&program, environment());
        assert_eq!(end.end, EndKind::Internal);
        assert_eq!(end.exit_code, EXIT_INTERNAL);
        assert_eq!(end.reports[0].kind, crate::diag::ReportKind::Internal);
    }
}

use crate::bytecode::program::{MainKind, ProtoIdx};
use crate::runtime::ReleaseFailure;
use crate::runtime::assert::{AssertTable, CheckFailure};

/// テストの関数一つの実行の指定（02-11「テストの実行」）。
#[derive(Clone, Debug)]
pub struct TestTarget {
    /// テストの関数の原型（10-07 の `CompiledProgram::top_fns` から引く）
    pub proto: ProtoIdx,
    /// 戻り値の型（`Unit` か `Result[Unit, String]`）
    pub kind: MainKind,
    /// ファイル一つの検査の結果から作った表。そのファイルのテストで共有する
    pub assert: Arc<AssertTable>,
}

/// テストの関数一つの実行の結果。
#[derive(Debug)]
pub struct TestEnd {
    /// 終わり方と報告（本章「テストの関数の実行」の表）
    pub run: RunEnd,
    /// `run.end` が `EndKind::CheckFailed` のときの確認の失敗の記録
    pub check_failure: Option<CheckFailure>,
    /// `run.end` が `EndKind::CheckFailed` のときの、止める途中の解放の失敗
    pub release_failures: Vec<ReleaseFailure>,
}

/// テストの関数を、引数なしで最初のタスクとして実行する（本章「テストの関数の実行」）。
/// VM の実行を `runtime::panic::catch` で囲み、捕らえた panic は処理系の不具合（終了状態 3）にする。
pub fn run_test(program: &CompiledProgram, target: TestTarget, env: RunEnv) -> TestEnd {
    run_entry(program, env, &Entry::Test(target))
}
