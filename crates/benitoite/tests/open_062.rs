//! OPEN-062 の反例を公開のパイプラインと実行器で確かめる（設計書 01-07・01-11・07-03）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::arithmetic_side_effects
)]
use benitoite::builtins::iface::OsResource;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::Stream;
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::ops::{Completion, JobWork, LentOwned, WorkerJob};
use benitoite::runtime::io::output::OutputPort;
use benitoite::runtime::io::services::{InterruptSource, IoRuntime, RunInput};
use benitoite::runtime::run::{self, EndKind, OutputTarget, RunEnd, RunEnv, StdinSource};
use benitoite::runtime::sched::ExtOpId;
use benitoite::runtime::sched::parts::{IdleWake, TaskPicker, WorkerExec};
use benitoite::runtime::sched::testing::{
    ScheduleEvent, ScheduleHandle, ScheduleRecord, ScheduleStep,
};
use benitoite::vm::{ExecMode, MainOutcome, StopEnd, StopReason, Vm, VmConfig, VmStep};
use std::collections::{BTreeSet, VecDeque};
use std::io::{Cursor, Write};
use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
    mpsc,
};
use std::time::Duration;
use std::{cell::RefCell, rc::Rc};

#[derive(Debug)]
struct Interrupt(Arc<AtomicBool>);
impl InterruptSource for Interrupt {
    fn requested(&self) -> bool {
        self.0.load(Ordering::Relaxed)
    }
    fn flag(&self) -> Option<&AtomicBool> {
        Some(&self.0)
    }
}
fn compile(source: &str) -> benitoite::bytecode::program::CompiledProgram {
    let checked = pipeline::check_text(
        "open-062.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}
fn env(
    mode: ExecMode,
    budget: u32,
    flag: Arc<AtomicBool>,
    out: Arc<Mutex<Vec<u8>>>,
    err: Arc<Mutex<Vec<u8>>>,
) -> RunEnv {
    RunEnv {
        input: RunInput {
            arguments: vec![],
            working_directory: env!("CARGO_MANIFEST_DIR").into(),
            script_directory: env!("CARGO_MANIFEST_DIR").into(),
        },
        stdin: StdinSource::Bytes(b"Ada\n".to_vec()),
        stdout: OutputTarget::Capture(out),
        stderr: OutputTarget::Capture(err),
        interrupt: Box::new(Interrupt(flag)),
        parts: None,
        mode,
        vm: VmConfig {
            call_budget: budget,
            ..VmConfig::default()
        },
        heap: HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
        dev_panic_after_first_write: false,
    }
}
// 待つ側の上限は停止の検出だけに使い、筋書きや期待値を実時間から決めない（R30）。
// 負荷のもとでも通知と後始末を待てるよう、実行全体と各通知の待ちに余裕を持たせる。
const STALL_TIMEOUT: Duration = Duration::from_secs(120);
fn receive<T>(receiver: &mpsc::Receiver<T>, flag: &AtomicBool, waiting_for: &str) -> T {
    receiver
        .recv_timeout(STALL_TIMEOUT)
        .unwrap_or_else(|error| {
            flag.store(true, Ordering::Relaxed);
            panic!("hang detected while waiting for {waiting_for}: {error}");
        })
}
fn bounded<T: Send + 'static>(f: impl FnOnce(Arc<AtomicBool>) -> T + Send + 'static) -> T {
    let flag = Arc::new(AtomicBool::new(false));
    let interrupt = Arc::clone(&flag);
    let (send, recv) = mpsc::channel();
    // VM とヒープは Send ではないため、コンパイルから実行までをこのスレッド内で行う。
    let thread = std::thread::spawn(move || {
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| f(interrupt)));
        let _sent = send.send(result);
    });
    let result = receive(&recv, &flag, "run completion");
    thread.join().unwrap();
    result.unwrap_or_else(|panic| std::panic::resume_unwind(panic))
}
fn execute(
    source: &str,
    mode: ExecMode,
    budget: u32,
    steps: Vec<ScheduleStep>,
) -> (RunEnd, ScheduleRecord, Vec<u8>, Observations) {
    let source = source.to_owned();
    bounded(move |flag| {
        let program = compile(&source);
        let (environment, script, output, observations) = prepare(mode, budget, steps, None, flag);
        let end = run::run_program(&program, environment);
        let bytes = output.lock().unwrap().clone();
        let observations = observations.lock().unwrap().clone();
        (end, script.record(), bytes, observations)
    })
}
fn execute_observed(
    source: &str,
    mode: ExecMode,
    budget: u32,
    steps: Vec<ScheduleStep>,
    snapshot_at: usize,
) -> (VmStep, ScheduleRecord, Vec<u8>, Observations) {
    let source = source.to_owned();
    bounded(move |flag| {
        let program = compile(&source);
        let output = Arc::new(Mutex::new(vec![]));
        let (sink, arrived) = capture_sink(Arc::clone(&output));
        let (environment, script, _, observations) = prepare(
            mode,
            budget,
            steps,
            Some(Snapshot {
                at: snapshot_at,
                output: Arc::clone(&output),
                arrived,
            }),
            flag,
        );
        let (stderr, _) = capture_sink(Arc::new(Mutex::new(vec![])));
        let end = run_observed(&program, environment, sink, stderr);
        let bytes = output.lock().unwrap().clone();
        let observations = observations.lock().unwrap().clone();
        (end, script.record(), bytes, observations)
    })
}
type Prepared = (
    RunEnv,
    ScheduleHandle,
    Arc<Mutex<Vec<u8>>>,
    Arc<Mutex<Observations>>,
);
struct Snapshot {
    at: usize,
    output: Arc<Mutex<Vec<u8>>>,
    arrived: mpsc::Receiver<Vec<u8>>,
}
fn prepare(
    mode: ExecMode,
    budget: u32,
    steps: Vec<ScheduleStep>,
    snapshot: Option<Snapshot>,
    flag: Arc<AtomicBool>,
) -> Prepared {
    // 反例の判定に使う選択・完了・時間はすべて指示する。使い切った後の既定の選択は後始末だけに使う。
    let script = ScheduleHandle::new(steps, false);
    let (at, output, arrived) = match snapshot {
        Some(Snapshot {
            at,
            output,
            arrived,
        }) => (at, output, Some(arrived)),
        None => (usize::MAX, Arc::new(Mutex::new(vec![])), None),
    };
    let mut env = env(
        mode,
        budget,
        Arc::clone(&flag),
        Arc::clone(&output),
        Arc::new(Mutex::new(vec![])),
    );
    let obs = Arc::new(Mutex::new(Observations::default()));
    let mut parts = script.parts();
    parts.workers = Box::new(Workers {
        inner: parts.workers,
        observations: Arc::clone(&obs),
        wrapped: BTreeSet::new(),
        output: Arc::clone(&output),
        picker: None,
    });
    parts.picker = Box::new(Picker {
        inner: parts.picker,
        script: script.clone(),
        observations: Arc::clone(&obs),
        arrived,
        snapshot_at: at,
        blocked: None,
        flag: Arc::clone(&flag),
    });
    env.parts = Some(parts);
    (env, script, output, obs)
}
// 出力先だけを置き換える。本物の writer が書いた後に知らせ、VM の次の選択を
// その知らせまで待たせる。到着の判定に実時間を使わない（ADR 0274、設計書 07-03）。
struct CaptureSink {
    bytes: Arc<Mutex<Vec<u8>>>,
    arrived: mpsc::Sender<Vec<u8>>,
}
impl Write for CaptureSink {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        let mut capture = self.bytes.lock().unwrap();
        capture.extend_from_slice(bytes);
        let _observed = self.arrived.send(capture.clone());
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
fn capture_sink(bytes: Arc<Mutex<Vec<u8>>>) -> (Box<dyn Write + Send>, mpsc::Receiver<Vec<u8>>) {
    let (arrived, receive) = mpsc::channel();
    (Box::new(CaptureSink { bytes, arrived }), receive)
}
// run_program のメモリの出力先 Capture は通知を持たないため、出力の順序は
// 公開の VM・IoRuntime・OutputPort の境界で確かめる。診断の試験は execute に残す。
fn run_observed(
    program: &benitoite::bytecode::program::CompiledProgram,
    env: RunEnv,
    stdout: Box<dyn Write + Send>,
    stderr: Box<dyn Write + Send>,
) -> VmStep {
    let parts = env.parts.unwrap();
    let wakeup = parts.workers.wakeup().unwrap();
    let mut rt = IoRuntime::new(
        env.input,
        env.mode,
        (
            OutputPort::start(Stream::Stdout, stdout, false, wakeup.clone()),
            OutputPort::start(Stream::Stderr, stderr, false, wakeup.clone()),
        ),
        Box::new(Cursor::new(b"Ada\n".to_vec())),
        parts,
        env.interrupt,
        wakeup,
    );
    let mut vm = Vm::new(program, env.vm, env.heap);
    vm.start_main().unwrap();
    let end = loop {
        match vm.run(&mut rt) {
            VmStep::Requests(ids) => {
                for id in ids {
                    vm.serve_request(&mut rt, id);
                }
            }
            end @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break end,
        }
    };
    rt.stdout.finish().unwrap();
    rt.stderr.finish().unwrap();
    end
}
fn trace(record: &ScheduleRecord) -> Vec<String> {
    let mut tasks = std::collections::BTreeMap::new();
    record
        .events
        .iter()
        .map(|e| match e {
            ScheduleEvent::Spawned { serial, task, .. } => {
                tasks.insert(*task, *serial);
                format!("spawn {serial}")
            }
            ScheduleEvent::Picked { task, scripted } => format!(
                "pick {} {scripted}",
                *tasks.get(task).expect("spawn serial was recorded")
            ),
            ScheduleEvent::Advanced(n) => format!("time {n}"),
            ScheduleEvent::WorkerRan(op) => format!("work {}", op.0),
        })
        .collect()
}
#[derive(Clone, Debug, Default)]
struct Observations {
    jobs: Vec<(ExtOpId, &'static str)>,
    released: usize,
    returned: usize,
    ready_at: Vec<(usize, Vec<u64>)>,
    prompt: Option<Vec<u8>>,
    snapshot: Option<Vec<u8>>,
    interrupted_while_held: bool,
    released_while_held: bool,
}
#[derive(Debug)]
struct CountRelease {
    inner: Box<dyn OsResource>,
    observations: Arc<Mutex<Observations>>,
}
impl OsResource for CountRelease {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self.inner.as_any_mut()
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        self.observations.lock().unwrap().released += 1;
        self.inner.release()
    }
}
#[derive(Debug)]
struct Workers {
    inner: Box<dyn WorkerExec>,
    observations: Arc<Mutex<Observations>>,
    wrapped: BTreeSet<benitoite::runtime::heap::ResourceId>,
    output: Arc<Mutex<Vec<u8>>>,
    picker: Option<Rc<RefCell<Picker>>>,
}
impl WorkerExec for Workers {
    fn wakeup(&self) -> Option<Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        let kind = match (&job.work, &job.lent) {
            (JobWork::Release(_), _) => "release",
            (JobWork::Builtin(_), LentOwned::Resource(..)) => "read",
            (JobWork::Builtin(_), LentOwned::Stdin(_)) => "stdin",
            (JobWork::Builtin(_), LentOwned::Nothing) => "file",
        };
        if kind == "stdin" {
            self.observations.lock().unwrap().prompt = Some(self.output.lock().unwrap().clone());
        }
        self.observations.lock().unwrap().jobs.push((job.op, kind));
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        if let Some(picker) = &self.picker {
            picker.borrow_mut().release_when_stopping();
        }
        let mut done = self.inner.try_recv()?;
        let returned = std::mem::replace(&mut done.returned, LentOwned::Nothing);
        if let LentOwned::Resource(id, reader) = returned {
            self.observations.lock().unwrap().returned += 1;
            done.returned = LentOwned::Resource(
                id,
                if self.wrapped.insert(id) {
                    Box::new(CountRelease {
                        inner: reader,
                        observations: Arc::clone(&self.observations),
                    })
                } else {
                    reader
                },
            );
        } else {
            done.returned = returned;
        }
        Some(done)
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        if let Some(picker) = &self.picker {
            picker.borrow_mut().release_when_stopping();
        }
        self.inner.idle(deadline)
    }
}

fn planned(record: &ScheduleRecord, steps: &[ScheduleStep]) {
    assert!(
        record.error.is_none(),
        "{:?} {:?}",
        record.error,
        trace(record)
    );
    assert_eq!(record.remaining, 0, "{:?}", trace(record));
    assert_eq!(record.consumed, steps.len());
    let mut tasks = std::collections::BTreeMap::new();
    let actual: Vec<_> = record
        .events
        .iter()
        .filter_map(|event| match event {
            ScheduleEvent::Spawned { serial, task, .. } => {
                tasks.insert(*task, *serial);
                None
            }
            ScheduleEvent::Picked {
                task,
                scripted: true,
            } => Some(ScheduleStep::PickTask(
                *tasks.get(task).expect("spawn serial was recorded"),
            )),
            ScheduleEvent::Picked {
                scripted: false, ..
            } => None,
            ScheduleEvent::Advanced(n) => Some(ScheduleStep::Advance(*n)),
            ScheduleEvent::WorkerRan(op) => Some(ScheduleStep::RunWorker(*op)),
        })
        .collect();
    assert_eq!(actual, steps);
}
fn matrix() -> impl Iterator<Item = (ExecMode, u32)> {
    [ExecMode::Direct, ExecMode::Request]
        .into_iter()
        .flat_map(|m| {
            [1, VmConfig::default().call_budget]
                .into_iter()
                .map(move |b| (m, b))
        })
}
fn picks(serials: &[u64]) -> Vec<ScheduleStep> {
    serials
        .iter()
        .copied()
        .map(ScheduleStep::PickTask)
        .collect()
}
fn normal(end: &RunEnd) {
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert_eq!(end.exit_code, 0);
    assert!(end.reports.is_empty());
    assert!(end.main_error.is_none());
}
// OPEN-062 R01: 切り替えの順序によって、Result.Error か実行時エラーかが変わる。
// どちらも値を返したなら同じ値であり、止まる場合の実行時エラーは問わない（ADR 0319 決定 1・2）。
// 関門: 組み込み単体では、起動・取り消し・停止の組み合わせをこの公開の境界で確かめられない。
#[test]
fn open_062_r01_pure_all_values_agree_and_stops_are_runtime_errors() {
    let allok = r#"function main() -> Result[Unit,String]
 bind result <- Task.allOk([lambda() return Result.Error("first") end lambda,lambda() return Result.Ok(1 div 0) end lambda])
 return Result.map(result,lambda(_values) return () end lambda)
end function"#;
    let all = r#"function main() -> Unit
 bind _ <- Task.all([lambda() return 1 div 0 end lambda,lambda() return 9223372036854775807 + 1 end lambda])
end function"#;
    // 値の比較が空のまま通らないよう、実行時エラーのない二つの順序でも結果を確かめる。
    let allok_values = r#"function main() -> Result[Unit,String]
 bind result <- Task.allOk([lambda() return Result.Error("first") end lambda,lambda() return Result.Error("second") end lambda])
 return Result.map(result,lambda(_values) return () end lambda)
end function"#;
    let all_values = r#"function main() -> Result[Unit,String]
 bind values <- Task.all([lambda() return 11 end lambda,lambda() return 22 end lambda])
 return Result.Error(if values = [11,22] then "11,22" else "unexpected order" end if)
end function"#;
    for (mode, budget) in matrix() {
        for (label, source, expected_value, may_stop) in [
            ("allOk/runtime", allok, Some("first"), true),
            ("all/runtime", all, None, true),
            ("allOk/values", allok_values, Some("first"), false),
            ("all/values", all_values, Some("11,22"), false),
        ] {
            let mut values = vec![];
            for first in [1, 2] {
                let steps = picks(&[first]);
                let (end, record, _, _) = execute(source, mode, budget, steps.clone());
                planned(&record, &steps);
                match end.end {
                    EndKind::MainError => {
                        assert!(expected_value.is_some(), "{label}: {end:?}");
                        assert_eq!(end.main_error.as_deref(), expected_value);
                        assert!(end.reports.is_empty());
                        values.push(end.main_error.unwrap());
                    }
                    EndKind::Stopped => {
                        assert!(may_stop, "{label}: {end:?}");
                        assert!(end.main_error.is_none());
                        assert!(!end.reports.is_empty());
                        assert!(
                            end.reports.iter().all(|report| {
                                report.kind == benitoite::diag::ReportKind::Runtime
                                    && report.severity == benitoite::diag::Severity::Error
                                    && report.code.is_some()
                            }),
                            "{label}: {end:?}"
                        );
                    }
                    EndKind::Returned
                    | EndKind::Exited(_)
                    | EndKind::Interrupted
                    | EndKind::CheckFailed
                    | EndKind::Internal => {
                        panic!("{mode:?}/{budget}/{label}/first={first}: {end:?}")
                    }
                }
            }
            if !may_stop {
                assert_eq!(values.len(), 2);
            }
            for pair in values.windows(2) {
                assert_eq!(pair.first(), pair.get(1), "{mode:?}/{budget}/{label}");
            }
        }
    }
}
// OPEN-062 R01 の穴: Clock.Time を handle で除くと、純粋な Task.race の結果が順序に依存する。
// Clock.Time を除いても State は残り、uses のない関数は型検査で拒否される（ADR 0319 決定 3）。
#[test]
fn open_062_r01_handled_race_requires_state() {
    let source = r#"
import Benitoite.Unofficial.IO.Clock
import Benitoite.Unofficial.Time
function pure() -> Option[Integer]
 return handle
 Task.race([lambda() return 11 end lambda,lambda() return 22 end lambda])
 with
 case Clock.sleep(_milliseconds) -> resume(())
 case Clock.monotonicMilliseconds() -> resume(0)
 case Clock.now() -> resume(Time.Instant(unixNanoseconds: 0))
 case Clock.localOffsetMinutes() -> resume(0)
 end handle
end function
function main() -> Unit
 bind _ <- pure()
end function
"#;
    let check = |source: &str| {
        pipeline::check_text(
            "open-062.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        )
    };
    // State を宣言すれば通る対照例で、構文や別の型の誤りによる拒否を区別する。
    let declared = source
        .replace(
            "function pure() -> Option[Integer]",
            "function pure() -> Option[Integer] uses State",
        )
        .replace(
            "function main() -> Unit",
            "function main() -> Unit uses State",
        );
    let accepted = check(&declared);
    assert_eq!(accepted.error_count(), 0, "{:?}", accepted.diagnostics);
    assert!(accepted.program.is_some());
    let rejected = check(source);
    let errors: Vec<_> = rejected
        .diagnostics
        .iter()
        .filter(|d| d.is_error())
        .collect();
    assert_eq!(errors.len(), 1, "{:?}", rejected.diagnostics);
    let error = errors.first().unwrap();
    assert_eq!(error.code, Some(benitoite::diag::codes::DiagCode::E0501));
    assert_eq!(
        error.message,
        "this function performs `State` but does not declare it"
    );
    assert!(rejected.program.is_none());
}
// OPEN-062 R02: A が readText 後にセルを書き、B が末尾再帰で読み続けると要求方式だけ止まる。
// B の二巡目の予算の境界で仕事を実行し、両方式が終わることを期待する（ADR 0264 決定 4・5）。
#[test]
fn open_062_r02_request_mode_starts_io_while_another_task_computes() {
    // 関門: 要求方式の VM から外側の実行器への配線を含むため、送り出しの部品だけの試験では足りない。
    let source = r#"
import Benitoite.Unofficial.IO.File
function wait(done: Reference[Boolean]) -> Unit uses State
 if Reference.get(done) then return () end if
 return wait(done)
end function
function main() -> Result[Unit,String] uses State,File.Read
 bind done <- Reference.new(false)
 bind results <- Task.all([
 lambda()
 bind result <- File.readText("Cargo.toml")
 Reference.set(done,true)
 return result
 end lambda,
 lambda()
 wait(done)
 return Result.Ok("")
 end lambda])
 return match results with
 case [Result.Ok(_text),Result.Ok(_empty)] -> Result.Ok(())
 case _ -> Result.Error("read failed")
 end match
end function
"#;
    // 読み取りの成功は A の返す Result を main が確かめる。

    for (mode, budget) in matrix() {
        let mut steps = picks(&[1, 2, 2]);
        steps.push(ScheduleStep::RunWorker(ExtOpId(0)));
        steps.extend(picks(&[1]));
        let (end, record, _, obs) = execute(source, mode, budget, steps.clone());
        planned(&record, &steps);
        normal(&end);
        assert_eq!(obs.jobs, [(ExtOpId(0), "file")]);
    }
}

// OPEN-062 R03: 外側の集まりで A が B を起動すると、handle が孫 B を待たないか取り消さない。
// 正常終了は B の出力が after より前、継続の破棄は B の出力がないことを期待する（01-11「タスクとハンドラ」、ADR 0266 決定 6・7）。
#[test]
fn open_062_r03_handle_waits_for_or_cancels_grandchildren() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
effect Test
 function leave() -> Unit
end effect
function main() -> Result[Unit,String] uses State,Console.Write,File.Read
 with group = TaskGroup.open() do
 bind _ <- TaskGroup.spawn(group,lambda() return () end lambda)
 bind _ <- handle
 bind parent <- TaskGroup.spawn(group,lambda()
  bind _ <- TaskGroup.spawn(group,lambda()
   bind _ <- File.readText("Cargo.toml")
   Console.write("B")
  end lambda)
 end lambda)
 BODY
 with
 case leave() -> ()
 end handle
 Console.write("after")
 return Result.Ok(())
 end with
end function
"#;
    for (mode, budget) in matrix() {
        for discard in [false, true] {
            let body = if discard {
                "Task.await(parent)\n leave()"
            } else {
                "()"
            };
            // 2 は A、3 は B。1 は handle の外の短いタスクで、要求を外へ渡した後の境界を確保する。
            let mut steps = if discard {
                picks(&[2, 3, 1, 0])
            } else {
                picks(&[2, 3, 1])
            };
            if discard && budget == 1 {
                steps.extend(picks(&[0]));
            }
            steps.push(ScheduleStep::RunWorker(ExtOpId(0)));
            steps.extend(picks(&[3]));
            let (end, record, output, obs) =
                execute(&source.replace("BODY", body), mode, budget, steps.clone());
            assert_eq!(obs.jobs, [(ExtOpId(0), "file")]);
            if !discard {
                assert!(
                    !obs.ready_at
                        .iter()
                        .find(|(at, _)| *at == 1)
                        .unwrap()
                        .1
                        .contains(&0),
                    "handle finished before B"
                );
            }
            planned(&record, &steps);
            normal(&end);
            assert_eq!(
                output,
                if discard {
                    b"after".to_vec()
                } else {
                    b"Bafter".to_vec()
                }
            );
        }
    }
}
// OPEN-062 R05: 取り消した readLine の完了を捨てると、貸した Reader も戻らない。
// 取り消しと実行の両順序で、with の解放が一度だけ行われ、main が進むことを期待する（ADR 0266 決定 4・5）。
#[test]
fn open_062_r05_cancelled_read_returns_and_releases_the_reader_once() {
    let source = r#"
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit,String] uses State,File.Read,Clock.Time,Console.Write
 with group = TaskGroup.open() do
 bind _ <- TaskGroup.spawn(group,lambda() return () end lambda)
 bind continued <- Reference.new(false)
 bind winner <- Task.race([
 lambda()
 with reader = try File.openReader("Cargo.toml") do
 bind _ <- try File.readLine(reader)
 Reference.set(continued,true)
 Clock.sleep(10)
 return Result.Ok(1)
 end with
 end lambda,
 lambda()
 Console.write("")
 Clock.sleep(1)
 return Result.Ok(2)
 end lambda])
 Console.write("after")
 return match winner with case Option.Some(Result.Ok(2)) -> if Reference.get(continued) = BEFORE then Result.Ok(()) else Result.Error("cancelled task continued") end if
 case _ -> Result.Error("wrong winner") end match
 end with
end function
"#;
    for (mode, budget) in matrix() {
        for before in [false, true] {
            // 2 が Reader、3 が勝つタスク。1 の選択は sleep の要求の処理より後に時間を進めるための境界。
            let mut steps = picks(&[2, 3]);
            steps.push(ScheduleStep::RunWorker(ExtOpId(0)));
            steps.extend(picks(&[2, 3]));
            if before {
                steps.push(ScheduleStep::RunWorker(ExtOpId(1)));
                steps.extend(picks(&[2]));
            }
            steps.extend(picks(&[1]));
            steps.push(ScheduleStep::Advance(1));
            steps.extend(picks(&[3, 2]));
            if !before {
                steps.push(ScheduleStep::RunWorker(ExtOpId(1)));
            }
            let (end, record, output, obs) = execute(
                &source.replace("BEFORE", if before { "true" } else { "false" }),
                mode,
                budget,
                steps.clone(),
            );
            assert_eq!(obs.jobs, [(ExtOpId(0), "file"), (ExtOpId(1), "read")]);
            planned(&record, &steps);
            normal(&end);
            assert_eq!(output, b"after");
            assert_eq!(obs.released, 1);
            assert_eq!(obs.returned, 1);
        }
    }

    // 同じリソースを外側の with で保持し、取り消し後に別のタスクが使う場合も確かめる。
    let shared = r#"
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit,String] uses State,File.Read,Clock.Time,Console.Write
 with group = TaskGroup.open() do
 bind _ <- TaskGroup.spawn(group,lambda() Console.write("") end lambda)
 with reader = try File.openReader("Cargo.toml") |> Result.mapError(_,IOError.message) do
 bind _ <- TaskGroup.spawn(group,lambda() Console.write("") end lambda)
 bind winner <- Task.race([
 lambda()
 bind _ <- File.readLine(reader)
 Clock.sleep(10)
 return 1
 end lambda,
 lambda()
 Console.write("")
 Clock.sleep(1)
 return 2
 end lambda])
 bind next <- TaskGroup.spawn(group,lambda() return File.readLine(reader) end lambda)
 bind line <- Task.await(next)
 Console.write("reused")
 return match line with
 case Result.Ok(Option.Some(_line)) -> if winner = Option.Some(2) then Result.Ok(()) else Result.Error("wrong winner") end if
 case _ -> Result.Error("reader did not return")
 end match
 end with
 end with
end function
"#;
    for (mode, budget) in matrix() {
        for before in [false, true] {
            let mut steps = picks(&[1]);
            steps.push(ScheduleStep::RunWorker(ExtOpId(0)));
            steps.extend(picks(&[0]));
            if budget == 1 {
                steps.extend(picks(&[0]));
            }
            steps.extend(picks(&[3, 4, 4]));
            if before {
                steps.push(ScheduleStep::RunWorker(ExtOpId(1)));
                steps.extend(picks(&[3]));
            }
            steps.extend(picks(&[1]));
            steps.push(ScheduleStep::Advance(1));
            steps.extend(picks(&[4, 3, 0, 5, 2]));
            if !before {
                steps.push(ScheduleStep::RunWorker(ExtOpId(1)));
                steps.extend(picks(&[2]));
            }
            // 貸し出し中の要求は返却後に新しい番号でやり直す。submit の記録で実際の読み取りの番号を確かめる。
            let read = ExtOpId(if before { 2 } else { 3 });
            steps.push(ScheduleStep::RunWorker(read));
            steps.extend(picks(&[5]));
            let (end, record, output, obs) = execute(shared, mode, budget, steps.clone());
            planned(&record, &steps);
            normal(&end);
            assert_eq!(output, b"reused");
            assert_eq!(obs.released, 1);
            assert_eq!(obs.returned, 2);
            assert_eq!(
                obs.jobs,
                [(ExtOpId(0), "file"), (ExtOpId(1), "read"), (read, "read")]
            );
        }
    }
}

#[derive(Debug)]
struct Picker {
    inner: Box<dyn TaskPicker>,
    script: ScheduleHandle,
    observations: Arc<Mutex<Observations>>,
    arrived: Option<mpsc::Receiver<Vec<u8>>>,
    snapshot_at: usize,
    blocked: Option<mpsc::Sender<()>>,
    flag: Arc<AtomicBool>,
}
impl TaskPicker for Picker {
    fn spawned(&mut self, serial: u64, task: benitoite::vm::TaskId) {
        self.inner.spawned(serial, task);
    }
    fn pick(&mut self, ready: &VecDeque<benitoite::vm::TaskId>) -> Option<usize> {
        if matches!(self.script.next_step(), Some(ScheduleStep::PickTask(_))) {
            let record = self.script.record();
            let serials = ready
                .iter()
                .map(|task| {
                    record
                        .events
                        .iter()
                        .find_map(|event| match event {
                            ScheduleEvent::Spawned {
                                serial,
                                task: spawned,
                                ..
                            } if task == spawned => Some(*serial),
                            ScheduleEvent::Spawned { .. }
                            | ScheduleEvent::Picked { .. }
                            | ScheduleEvent::Advanced(_)
                            | ScheduleEvent::WorkerRan(_) => None,
                        })
                        .unwrap()
                })
                .collect();
            self.observations
                .lock()
                .unwrap()
                .ready_at
                .push((record.consumed, serials));
        }
        if self.snapshot_at != usize::MAX
            && self.observations.lock().unwrap().snapshot.is_none()
            && self.script.record().consumed == self.snapshot_at
        {
            let bytes = receive(
                self.arrived.as_ref().unwrap(),
                &self.flag,
                "output notification",
            );
            let mut obs = self.observations.lock().unwrap();
            if self.blocked.is_some() && !bytes.is_empty() {
                self.flag.store(true, Ordering::Relaxed);
                obs.interrupted_while_held = true;
            }
            obs.snapshot = Some(bytes);
        }
        self.release_when_stopping();
        self.inner.pick(ready)
    }
}
impl Picker {
    // VM の停止中は次の pick がない場合がある。その場合は出力の完了の取り込みで
    // 同じ picker に観測を依頼し、Reader の解放後にだけ保持を放す（R30 の停止の観測）。
    fn release_when_stopping(&mut self) {
        if self.blocked.is_some()
            && self.flag.load(Ordering::Relaxed)
            && self.observations.lock().unwrap().released > 0
        {
            self.observations.lock().unwrap().released_while_held = true;
            if let Some(release) = self.blocked.take() {
                let _sent = release.send(());
            }
        }
    }
}
#[derive(Debug)]
struct SharedPicker(Rc<RefCell<Picker>>);
impl TaskPicker for SharedPicker {
    fn spawned(&mut self, serial: u64, task: benitoite::vm::TaskId) {
        self.0.borrow_mut().spawned(serial, task);
    }
    fn pick(&mut self, ready: &VecDeque<benitoite::vm::TaskId>) -> Option<usize> {
        self.0.borrow_mut().pick(ready)
    }
}
// OPEN-062 R13（プロンプト）: Console.write の後の readLine を待つ間に Name: が出ない。
// stdin の仕事を submit した時点で既に出力済みであることを期待する（ADR 0265 決定 3）。
// 関門: R29 の配線の試験とは重なるが、R30 の個別指示により項目の試験を同じファイルに置く。
#[test]
fn open_062_r13_prompt_arrives_before_stdin_work_starts() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
function marker(n: Integer) -> Unit
 if n = 0 then return () end if
 return marker(n - 1)
end function
function main() -> Result[Unit,String] uses State,Console.Write,Console.Read
 with group = TaskGroup.open() do
 bind _ <- TaskGroup.spawn(group,lambda() marker(COMPUTE) end lambda)
 Console.write("Name: ")
 bind name <- try Console.readLine() |> Result.mapError(_,IOError.message)
 return if name = Option.Some("Ada") then Result.Ok(()) else Result.Error("unexpected input") end if
 end with
end function
"#;
    for (mode, budget) in matrix() {
        // 子が予算を越えて残ることだけが必要であり、後始末の計算量は予算に合わせる。
        let source = source.replace("COMPUTE", &(budget + 1).to_string());
        // writer の非同期の完了を先に観測し、二つの予算の境界を経てから stdin の仕事を実行する。
        let mut steps = picks(&[0, 1, 1]);
        steps.push(ScheduleStep::RunWorker(ExtOpId(0)));
        let (end, record, output, obs) = execute_observed(&source, mode, budget, steps.clone(), 1);
        planned(&record, &steps);
        assert_eq!(end, VmStep::Finished(MainOutcome::Ok));
        assert_eq!(obs.jobs, [(ExtOpId(0), "stdin")]);
        assert_eq!(obs.snapshot, Some(b"Name: ".to_vec()));
        assert_eq!(obs.prompt, Some(b"Name: ".to_vec()));
        assert_eq!(output, b"Name: ");
    }
}
// OPEN-062 R13（準備の行）: パイプへ準備の行を書き、A が待った後に B が計算を続けると行が届かない。
// B の二巡目を選ぶ前、まだ計算が終わらない時点で ready の行が届くことを期待する（02-09「出力のバッファ」）。
#[test]
fn open_062_r13_ready_line_arrives_while_another_task_computes() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
function compute(n: Integer) -> Unit
 if n = 0 then return () end if
 return compute(n - 1)
end function
function main() -> Result[Unit,String] uses Console.Write,Clock.Time
 bind _ <- Task.all([
 lambda()
 Console.writeLine("ready")
 Clock.sleep(10)
 end lambda,
 lambda() compute(COMPUTE) end lambda])
 return Result.Ok(())
end function
"#;
    let mut failures = vec![];
    for (mode, budget) in matrix() {
        // B の一巡目の予算を確実に越える。観測後に 30000 回の再帰を終える必要はない。
        let source = source.replace("COMPUTE", &(budget + 1).to_string());
        let mut steps = picks(&[1, 1, 2, 2]);
        steps.push(ScheduleStep::Advance(10));
        steps.extend(picks(&[1]));
        let (end, record, output, obs) = execute_observed(&source, mode, budget, steps.clone(), 3);
        planned(&record, &steps);
        assert_eq!(end, VmStep::Finished(MainOutcome::Ok));
        assert!(
            obs.ready_at
                .iter()
                .find(|(at, _)| *at == 3)
                .unwrap()
                .1
                .contains(&2),
            "B finished before the output observation"
        );
        assert_eq!(output, b"ready\n");
        if obs.snapshot != Some(b"ready\n".to_vec()) {
            failures.push(format!("{mode:?}/{budget}: {:?}", obs.snapshot));
        }
    }
    assert!(
        failures.is_empty(),
        "OPEN-062 R13 ready: {}",
        failures.join("\n")
    );
}
// OPEN-062 R04: 出力先が詰まると、ほかのタスク・タイマー・標準エラー出力・中断の検査も止まる。
// 1 MiB を超える出力と容量待ちの間に、タイマー後の stderr を観測して中断し、
// stdout を放す前の Reader の解放で停止の手順に入ったことを確かめる（ADR 0265 決定 2〜4）。
#[test]
fn open_062_r04_blocked_stdout_does_not_block_timers_stderr_or_interrupts() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
import Benitoite.Unofficial.IO.File
function spin() -> Unit
 return spin()
end function
function main() -> Result[Unit,String] uses State,File.Read,Console.Write,Clock.Time
 bind _ <- Task.all([
 lambda()
 with reader = try File.openReader("Cargo.toml") do
 bind _ <- try File.readLine(reader)
 Console.write(String.repeat("x",1048577))
 Console.write("capacity")
 return Result.Ok(())
 end with
 end lambda,
 lambda()
 Clock.sleep(10)
 Console.writeError(String.repeat("t",65537))
 spin()
 return Result.Ok(())
 end lambda,
 lambda()
 Console.write("")
 return Result.Ok(())
 end lambda])
 return Result.Ok(())
end function
"#;
    for (mode, budget) in matrix() {
        let source = source.to_owned();
        let (end, record, steps, obs, released_by_signal, output) = bounded(move |flag| {
            let program = compile(&source);
            let output = Arc::new(Mutex::new(vec![]));
            let stderr = Arc::new(Mutex::new(vec![]));
            let held = Arc::clone(&output);
            let (send_release, receive_release) = mpsc::channel();
            let (send_ready, receive_ready) = mpsc::channel();
            let gate_flag = Arc::clone(&flag);
            let gate = std::thread::spawn(move || {
                let guard = held.lock().unwrap();
                send_ready.send(()).unwrap();
                let released = receive_release.recv_timeout(STALL_TIMEOUT);
                drop(guard);
                released.unwrap_or_else(|error| {
                    gate_flag.store(true, Ordering::Relaxed);
                    panic!("hang detected while waiting for stdout gate release: {error}");
                });
                true
            });
            receive(&receive_ready, &flag, "stdout gate readiness");
            let (stdout_sink, _) = capture_sink(Arc::clone(&output));
            let (stderr_sink, arrived) = capture_sink(Arc::clone(&stderr));
            let mut steps = picks(&[1, 2, 3]);
            steps.push(ScheduleStep::RunWorker(ExtOpId(0)));
            steps.extend(picks(&[1, 3]));
            steps.push(ScheduleStep::RunWorker(ExtOpId(1)));
            steps.extend(picks(&[1, 1]));
            steps.push(ScheduleStep::Advance(10));
            steps.extend(picks(&[2, 2]));
            let script = ScheduleHandle::new(steps.clone(), false);
            let observations = Arc::new(Mutex::new(Observations::default()));
            let mut parts = script.parts();
            let picker = Rc::new(RefCell::new(Picker {
                inner: parts.picker,
                script: script.clone(),
                observations: Arc::clone(&observations),
                arrived: Some(arrived),
                snapshot_at: 11,
                blocked: Some(send_release.clone()),
                flag: Arc::clone(&flag),
            }));
            parts.workers = Box::new(Workers {
                inner: parts.workers,
                observations: Arc::clone(&observations),
                wrapped: BTreeSet::new(),
                output: Arc::clone(&output),
                picker: Some(Rc::clone(&picker)),
            });
            parts.picker = Box::new(SharedPicker(picker));
            let mut environment = env(mode, budget, flag, Arc::clone(&output), stderr);
            environment.parts = Some(parts);
            let end = run_observed(&program, environment, stdout_sink, stderr_sink);
            let _sent = send_release.send(());
            let released_by_signal = gate.join().unwrap();
            let obs = observations.lock().unwrap().clone();
            let bytes = output.lock().unwrap().clone();
            (end, script.record(), steps, obs, released_by_signal, bytes)
        });
        planned(&record, &steps);
        assert_eq!(
            end,
            VmStep::Stopped(StopEnd {
                reason: StopReason::Interrupted,
                release_failures: vec![],
            })
        );
        assert!(
            !obs.ready_at
                .iter()
                .find(|(at, _)| *at == 10)
                .unwrap()
                .1
                .contains(&1),
            "writer was not waiting for capacity"
        );
        assert!(released_by_signal);
        assert!(obs.interrupted_while_held);
        assert!(obs.released_while_held);
        assert_eq!(obs.released, 1);
        assert_eq!(obs.snapshot, Some(vec![b't'; 65537]));
        assert_eq!(obs.jobs, [(ExtOpId(0), "file"), (ExtOpId(1), "read")]);
        assert_eq!(output, vec![b'x'; 1048577]);
    }
}
