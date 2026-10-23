//! タスクの待ちと完了の順序を変え、IO の方式の同等性を公開の実行経路で確かめる
//! （設計書 07-03「IO の方式のテスト」「順序を与えるスケジューラと仮想の時間（初回リリース版）」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use benitoite::diag::Diagnostic;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::ops::{Completion, JobWork, LentOwned, Outcome, WorkerJob};
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{IdleWake, TaskPicker, WorkerExec};
use benitoite::runtime::sched::testing::{ScheduleHandle, ScheduleStep};
use benitoite::vm::{ExecMode, TaskId, VmConfig};
use std::collections::VecDeque;
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex, mpsc};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const LIMIT: Duration = Duration::from_secs(30);
const IMPORTS: &str = "import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Clock\n";

#[derive(Debug, PartialEq)]
struct Observation {
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    end: EndKind,
    exit_code: u8,
    main_error: Option<String>,
    reports: Vec<Diagnostic>,
    files: Vec<(String, Vec<u8>)>,
}

#[derive(Clone, Copy, Debug)]
enum Order {
    Real,
    Forward,
    Reverse,
}

#[derive(Debug)]
struct ChildOrderPicker {
    scripted: Box<dyn TaskPicker>,
    children_ready: bool,
}
impl TaskPicker for ChildOrderPicker {
    fn spawned(&mut self, serial: u64, task: TaskId) {
        self.scripted.spawned(serial, task);
        self.children_ready |= serial >= 2;
    }
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize> {
        // main がリソースを開く待ちは、子の選択の指示を消費しない。
        if self.children_ready {
            self.scripted.pick(ready)
        } else if ready.is_empty() {
            None
        } else {
            Some(0)
        }
    }
}

type PromptOutputs = (&'static [u8], &'static [u8]);

// 外部の仕事はすべて本物を行う。完了を idle まで保留すると、同時に待つ仕事を
// 前後どちらから返すかを決められ、スレッドの偶然の順序に頼らない（設計書 07-03）。
#[derive(Debug)]
struct OrderedWorkers {
    waiting: Box<dyn WorkerExec>,
    jobs: VecDeque<WorkerJob>,
    done: VecDeque<Completion>,
    reverse: bool,
    stdout: Arc<Mutex<Vec<u8>>>,
    stderr: Arc<Mutex<Vec<u8>>>,
    prompts: Arc<Mutex<VecDeque<PromptOutputs>>>,
}

impl WorkerExec for OrderedWorkers {
    fn wakeup(&self) -> Option<Wakeup> {
        self.waiting.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        if matches!(job.lent, LentOwned::Stdin(_)) {
            let (out, err) = self
                .prompts
                .lock()
                .unwrap()
                .pop_front()
                .expect("unexpected stdin operation");
            assert_eq!(
                *self.stdout.try_lock().expect("stdout still transferring"),
                out,
                "stdout prompt before stdin"
            );
            assert_eq!(
                *self.stderr.try_lock().expect("stderr still transferring"),
                err,
                "stderr prompt before stdin"
            );
        }
        self.jobs.push_back(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.done.pop_front().or_else(|| {
            // 逆順では仕事を先に返し、正順ではタイマーを先に満了させる。
            if self.reverse && !self.jobs.is_empty() {
                None
            } else {
                self.waiting.try_recv()
            }
        })
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        let next = if self.reverse {
            self.jobs.pop_back()
        } else {
            self.jobs.pop_front()
        };
        if let Some(job) = next {
            let JobWork::Builtin(work) = job.work else {
                panic!("U2 Reader release must not submit blocking work")
            };
            let mut lent = job.lent;
            use benitoite::builtins::iface::Lent;
            let result = work.run(match &mut lent {
                LentOwned::Nothing => Lent::Nothing,
                LentOwned::Resource(_, handle) => Lent::Resource(handle.as_mut()),
                LentOwned::Stdin(reader) => Lent::Stdin(reader.as_mut()),
            });
            self.done.push_back(Completion {
                op: job.op,
                outcome: Outcome::Worker(result),
                returned: lent,
            });
            IdleWake::Progress
        } else {
            self.waiting.idle(deadline)
        }
    }
}

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let mut attempt = 0_u64;
        loop {
            // 作業ディレクトリの外へは書かない。時刻が重なる場合も作成で名前を予約し、
            // 並行するテストのファイルを共有しない。
            let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!(
                "../../target/r31-io-{}-{stamp}-{attempt}",
                std::process::id()
            ));
            match fs::create_dir(&path) {
                Ok(()) => return Self(path.canonicalize().unwrap()),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {
                    attempt = attempt.checked_add(1).unwrap();
                }
                Err(error) => panic!("cannot create test directory: {error}"),
            }
        }
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _removed = fs::remove_dir_all(&self.0);
    }
}

fn observe(source: &str, mode: ExecMode, order: Order, stdin: &[u8], timed: bool) -> Observation {
    observe_files(source, &[], mode, order, stdin, timed)
}

fn observe_files(
    source: &str,
    modules: &[(&str, &str)],
    mode: ExecMode,
    order: Order,
    stdin: &[u8],
    timed: bool,
) -> Observation {
    let source = format!("{IMPORTS}{source}");
    let modules: Vec<_> = modules
        .iter()
        .map(|(name, text)| (name.to_string(), text.to_string()))
        .collect();
    let stdin = stdin.to_vec();
    let (send, receive) = mpsc::channel();
    // 筋書きの Rc は実行のスレッド内で作る。受信側の上限は停止したテストの検出にだけ使う。
    let worker = std::thread::spawn(move || {
        let directory = Directory::new();
        fs::write(directory.0.join("input.txt"), b"first\nsecond\n").unwrap();
        let mut files = vec![("io-modes.bnt", source.as_bytes())];
        files.extend(
            modules
                .iter()
                .map(|(name, text)| (name.as_str(), text.as_bytes())),
        );
        let checked = pipeline::check_files(
            &files,
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        let program = pipeline::compile(&core, checked.sources).unwrap();
        let stdout = Arc::new(Mutex::new(Vec::new()));
        let stderr = Arc::new(Mutex::new(Vec::new()));
        let script = match order {
            Order::Real => None,
            Order::Forward => Some(ScheduleHandle::new([ScheduleStep::PickTask(1)], false)),
            Order::Reverse => Some(ScheduleHandle::new([ScheduleStep::PickTask(2)], false)),
        };
        // 時間の指示は子が二つとも待った後に消費する。タイマー以外のテストには不要である。
        let script = if timed && script.is_some() {
            Some(ScheduleHandle::new(
                [
                    ScheduleStep::PickTask(if matches!(order, Order::Reverse) {
                        2
                    } else {
                        1
                    }),
                    ScheduleStep::PickTask(if matches!(order, Order::Reverse) {
                        1
                    } else {
                        2
                    }),
                    ScheduleStep::Advance(20),
                ],
                false,
            ))
        } else {
            script
        };
        let prompts = Arc::new(Mutex::new(if stdin.is_empty() {
            VecDeque::new()
        } else {
            VecDeque::from([
                (b"line> ".as_slice(), b"err> ".as_slice()),
                (b"line> rest> ".as_slice(), b"err> ".as_slice()),
            ])
        }));
        let parts = script.as_ref().map(|script| {
            let mut parts = script.parts();
            parts.picker = Box::new(ChildOrderPicker {
                scripted: parts.picker,
                children_ready: false,
            });
            parts.workers = Box::new(OrderedWorkers {
                waiting: parts.workers,
                jobs: VecDeque::new(),
                done: VecDeque::new(),
                reverse: matches!(order, Order::Reverse),
                stdout: Arc::clone(&stdout),
                stderr: Arc::clone(&stderr),
                prompts: Arc::clone(&prompts),
            });
            parts
        });
        let end = run::run_program(
            &program,
            RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: directory.0.clone(),
                    script_directory: directory.0.clone(),
                },
                stdin: StdinSource::Bytes(stdin),
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                interrupt: Box::new(NoInterrupt),
                parts,
                mode,
                vm: VmConfig::default(),
                heap: HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                dev_panic_after_first_write: false,
            },
        );
        if let Some(script) = script {
            // submit を一度も通らない退行も検出する（設計書 07-03「IO の方式のテスト」）。
            assert!(
                prompts.lock().unwrap().is_empty(),
                "{mode:?}/{order:?}: stdin prompt checks were not consumed"
            );
            let record = script.record();
            assert!(record.error.is_none(), "{mode:?}/{order:?}: {record:?}");
            assert_eq!(record.remaining, 0, "{record:?}");
        }
        let mut files: Vec<_> = fs::read_dir(&directory.0)
            .unwrap()
            .map(|entry| {
                let entry = entry.unwrap();
                (
                    entry.file_name().into_string().unwrap(),
                    fs::read(entry.path()).unwrap(),
                )
            })
            .collect();
        files.sort();
        let observation = Observation {
            stdout: stdout.lock().unwrap().clone(),
            stderr: stderr.lock().unwrap().clone(),
            end: end.end,
            exit_code: end.exit_code,
            main_error: end.main_error,
            reports: end.reports,
            files,
        };
        let _sent = send.send(observation);
    });
    let result = receive
        .recv_timeout(LIMIT)
        .unwrap_or_else(|error| panic!("{mode:?}/{order:?} did not finish: {error}"));
    worker.join().unwrap();
    result
}

fn compare(
    source: &str,
    stdin: &[u8],
    timed: bool,
    output: &[u8],
    error_output: &[u8],
    stopped: bool,
) -> Observation {
    let mut reference = None;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for order in [Order::Forward, Order::Reverse, Order::Real] {
            let result = observe(source, mode, order, stdin, timed);
            assert_eq!(result.stdout, output, "{mode:?}/{order:?}: {result:?}");
            assert_eq!(result.stderr, error_output);
            assert_eq!(
                result.end,
                if stopped {
                    EndKind::Stopped
                } else {
                    EndKind::Returned
                },
                "{result:?}"
            );
            assert_eq!(result.exit_code, u8::from(stopped));
            assert!(result.main_error.is_none(), "{result:?}");
            if stopped {
                assert_eq!(result.reports.len(), 1, "{result:?}");
                assert_eq!(
                    result.reports.first().unwrap().code,
                    Some(benitoite::diag::codes::DiagCode::R0101)
                );
            } else {
                assert!(result.reports.is_empty(), "{result:?}");
            }
            if let Some(expected) = &reference {
                assert_eq!(&result, expected, "{mode:?}/{order:?}");
            } else {
                reference = Some(result);
            }
        }
    }
    reference.unwrap()
}

// 関門: 固定入力のゴールデンでは、待つ仕事の完了順を変えられない。
// 順序を逆転しても Task.all の結果・外部のファイル・終了結果が一致する契約を守る。
#[test]
fn concurrent_file_operations_collect_results_in_action_order() {
    let result = compare(
        r#"
function fileWork(path: String, text: String) -> Result[String,String] uses File.Write,File.Read
 bind _ <- try File.writeText(path: path,text: text) |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
 bind _ <- try File.appendText(path: path,text: "!") |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
 return File.readText(path) |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
end function
function main() -> Result[Unit,String] uses File.Write,File.Read,Console.Write
 bind values <- Task.all([lambda() return fileWork(path: "a.txt",text: "A") end lambda,
                          lambda() return fileWork(path: "b.txt",text: "B") end lambda])
 if values <> [Result.Ok("A!"),Result.Ok("B!")] then return Result.Error("values") end if
 Console.writeLine("A!,B!")
 return Result.Ok(())
end function
"#,
        b"",
        false,
        b"A!,B!\n",
        b"",
        false,
    );
    assert!(result.files.contains(&("a.txt".into(), b"A!".to_vec())));
    assert!(result.files.contains(&("b.txt".into(), b"B!".to_vec())));
}

#[test]
fn reader_waits_alongside_computation() {
    compare(
        r#"
function sum(n: Integer, total: Integer) -> Integer
 return if n = 0 then total else sum(n: n - 1,total: total + n) end if
end function
function read() -> Result[String,String] uses File.Read,State
 with reader = try File.openReader("input.txt") |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda) do
  bind a <- try File.readLine(reader) |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
  bind b <- try File.readLine(reader) |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
  return Result.Ok(if a = Option.Some("first") and b = Option.Some("second") then "lines" else "bad" end if)
 end with
end function
function main() -> Result[Unit,String] uses File.Read,State,Console.Write
 bind values <- Task.all([lambda() return read() end lambda,
                          lambda() return Result.Ok(Integer.toString(sum(n: 100,total: 0))) end lambda])
 if values <> [Result.Ok("lines"),Result.Ok("5050")] then return Result.Error("values") end if
 Console.writeLine("lines,5050")
 return Result.Ok(())
end function
"#,
        b"",
        false,
        b"lines,5050\n",
        b"",
        false,
    );
}

#[test]
fn stdin_prompts_are_transferred_before_each_read() {
    // 最初の選択を二通りにするため、標準入力を読む子と純粋な子を並べる。
    compare(
        r#"
function read() -> Result[String,String] uses Console.Read,Console.Write
 Console.write("line> ")
 Console.writeError("err> ")
 bind line <- try Console.readLine() |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
 Console.write("rest> ")
 bind rest <- try Console.readAll() |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
 return Result.Ok(if line = Option.Some("Ada") and rest = "remaining\n" then "input" else "bad" end if)
end function
function main() -> Result[Unit,String] uses Console.Read,Console.Write
 bind values <- Task.all([lambda() return read() end lambda,lambda() return Result.Ok("pure") end lambda])
 return if values = [Result.Ok("input"),Result.Ok("pure")] then Result.Ok(()) else Result.Error("values") end if
end function
"#,
        b"Ada\nremaining\n",
        false,
        b"line> rest> ",
        b"err> ",
        false,
    );
}

#[test]
fn virtual_sleep_and_file_write_complete_in_either_order() {
    let result = compare(
        r#"
function main() -> Result[Unit,String] uses Clock.Time,File.Write,Console.Write
 bind values <- Task.all([lambda()
 Clock.sleep(10)
                          return Result.Ok("slept") end lambda,
                          lambda() return File.writeText(path: "timer.txt",text: "written") |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda) |> Result.map(r: _,f: lambda(value) return "written" end lambda) end lambda])
 if values <> [Result.Ok("slept"),Result.Ok("written")] then return Result.Error("values") end if
 Console.writeLine("slept,written")
 return Result.Ok(())
end function
"#,
        b"",
        true,
        b"slept,written\n",
        b"",
        false,
    );
    assert!(
        result
            .files
            .contains(&("timer.txt".into(), b"written".to_vec()))
    );
}

#[test]
fn runtime_error_during_reader_io_has_the_same_stop_report() {
    // Reader の解放は外から観測できないので、終わり方と完全な診断の比較に留める。
    compare(
        r#"
function main() -> Result[Unit,String] uses File.Read,State
 with reader = try File.openReader("input.txt") |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda) do
  bind _ <- Task.all([lambda()
 bind _ <- File.readLine(reader)
                             return 1 end lambda,
                     lambda() return 1 div 0 end lambda])
  return Result.Ok(())
 end with
end function
"#,
        b"",
        false,
        b"",
        b"",
        true,
    );
}

#[test]
fn inherited_handlers_intercept_or_pass_through_builtin_operations() {
    for (handler, output) in [
        ("case Console.writeLine(_) -> resume(())", b"".as_slice()),
        ("case ask() -> resume(())", b"visible\n".as_slice()),
    ] {
        compare(
            &format!(
                r#"
effect Probe
 function ask() -> Unit
end effect
function main() -> Unit uses Console.Write
 handle
  bind _ <- Task.all([lambda()
 Console.writeLine("visible")
                      return () end lambda,lambda() return () end lambda])
  ()
 with
  {handler}
 end handle
end function
"#
            ),
            b"",
            false,
            output,
            b"",
            false,
        );
    }
}

// 関門: 子の内側で変換しても、実物の IO の完了順と結果の順序を混同しない。
#[test]
fn typed_failure_converted_in_children_keeps_io_and_action_order() {
    compare(
        r#"
import Benitoite.Unofficial.Failure
function read(fail: Boolean) -> Result[String, String] uses File.Read
 return Failure.toResult(body: lambda()
  bind text <- Failure.fromResult(File.readText("input.txt") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda))
  return if fail then Failure.raise(error: text) else text end if
 end lambda)
end function
function main() -> Result[Unit, String] uses File.Read, Console.Write
 bind values <- Task.all([lambda() return read(true) end lambda, lambda() return read(false) end lambda])
 if values <> [Result.Error("first\nsecond\n"), Result.Ok("first\nsecond\n")] then return Result.Error("values") end if
 Console.writeLine("converted children")
 return Result.Ok(())
end function
"#,
        b"",
        false,
        b"converted children\n",
        b"",
        false,
    );
}

// 関門: Logの既定書式・水準・属性順は実IOの入口で守る。各層の私有関数は呼ばない。
#[test]
fn log_default_output_is_ordered_escaped_and_filtered_in_both_modes() {
    let source = r#"
function main() -> Unit uses Log, Console.Write
 bind location <- SourceLocation.Location(file: "app/あ\"\n.bnt", line: 12, column: 3)
 Console.writeError("before\n")
 Log.debug(message: "hidden", attributes: [], location: location)
 Console.writeLine("${Log.enabled(Log.Level.Debug)},${Log.enabled(Log.Level.Info)},${Log.enabled(Log.Level.Warn)},${Log.enabled(Log.Level.Error)}")
 Log.info(message: "done\n\"\\\t\u{0}", attributes: [
   Log.attribute(key: "dup", value: "a\nb"),
   Log.attribute(key: "dup", value: true),
   Log.attribute(key: "i", value: -9223372036854775808),
   Log.attribute(key: "u", value: 18446744073709551615u64),
   Log.attribute(key: "f", value: 1.25),
   Log.attribute(key: "f", value: 0.0 / 0.0),
   Log.attribute(key: "f", value: 1.0 / 0.0),
   Log.attribute(key: "f", value: -1.0 / 0.0),
   Log.attribute(key: "key\"\r", value: false)], location: location)
 Log.warn(message: "warn", attributes: [], location: location)
 Log.error(message: "error", attributes: [], location: location)
 Console.writeError("after\n")
end function
"#;
    let expected = concat!(
        "before\n",
        "level=INFO source=\"app/あ\\\"\\n.bnt:12:3\" message=\"done\\n\\\"\\\\\\t\\u0000\"",
        " attr.\"dup\"=\"a\\nb\" attr.\"dup\"=true attr.\"i\"=-9223372036854775808",
        " attr.\"u\"=18446744073709551615 attr.\"f\"=1.25 attr.\"f\"=nan attr.\"f\"=inf attr.\"f\"=-inf attr.\"key\\\"\\r\"=false\n",
        "level=WARN source=\"app/あ\\\"\\n.bnt:12:3\" message=\"warn\"\n",
        "level=ERROR source=\"app/あ\\\"\\n.bnt:12:3\" message=\"error\"\n",
        "after\n"
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let actual = observe(source, mode, Order::Real, b"", false);
        assert_eq!(actual.end, EndKind::Returned, "{actual:?}");
        assert_eq!(actual.exit_code, 0);
        assert_eq!(actual.stdout, b"false,true,true,true\n");
        assert_eq!(actual.stderr, expected.as_bytes());
        assert!(actual.reports.is_empty(), "{actual:?}");
    }
}

// 関門: 捕捉の一回性、節からの外側への送り直し、sinkの列順とenabledの論理和。
#[test]
fn log_standard_handlers_preserve_order_attributes_and_outer_effects() {
    let source = r#"
function event(level: Log.Level) -> Unit uses Log
 Log.emit(record: Log.Record(level: level, message: "event", attributes: [Log.attribute(key: "dup", value: 2)], location: SourceLocation.Location(file: "app", line: 7, column: 4)))
end function
function main() -> Unit uses Log, Console.Write
 handle event(Log.Level.Error) with
  case Log.emit(record) -> resume(())
  case Log.enabled(level) -> resume(false)
 end handle
 Log.withAttributes(attributes: [Log.attribute(key: "dup", value: 1)], body: lambda()
   event(Log.Level.Info)
   Console.writeLine("forward:${Log.enabled(Log.Level.Debug)}")
 end lambda)
 Log.withTextLogger(minimum: Log.Level.Debug, body: lambda()
   event(Log.Level.Debug)
   Console.writeLine("text:${Log.enabled(Log.Level.Debug)}")
 end lambda)
 Log.withTextLogger(minimum: Log.Level.Error, body: lambda()
   event(Log.Level.Warn)
   event(Log.Level.Error)
   Console.writeLine("text:${Log.enabled(Log.Level.Info)},${Log.enabled(Log.Level.Error)}")
 end lambda)
 Log.withSinks(sinks: [Pair(Log.Level.Debug, lambda(record: Log.Record)
   Console.writeLine("A:${Log.Record.message(record)}")
 end lambda), Pair(Log.Level.Error, lambda(record: Log.Record)
   Console.writeLine("B:${Log.Record.message(record)}")
 end lambda)], body: lambda()
   Console.writeLine("sinks:${Log.enabled(Log.Level.Info)}")
   event(Log.Level.Info)
   event(Log.Level.Error)
 end lambda)
 Log.withSinks(sinks: [], body: lambda()
   Console.writeLine("empty:${Log.enabled(Log.Level.Error)}")
   event(Log.Level.Error)
 end lambda)
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let actual = observe(source, mode, Order::Real, b"", false);
        assert_eq!(actual.end, EndKind::Returned, "{actual:?}");
        assert_eq!(actual.exit_code, 0);
        assert_eq!(actual.stdout, b"forward:false\ntext:true\ntext:false,true\nsinks:true\nA:event\nA:event\nB:event\nempty:false\n");
        assert_eq!(
            actual.stderr,
            concat!(
                "level=INFO source=\"app:7:4\" message=\"event\" attr.\"dup\"=1 attr.\"dup\"=2\n",
                "level=DEBUG source=\"app:7:4\" message=\"event\" attr.\"dup\"=2\n",
                "level=ERROR source=\"app:7:4\" message=\"event\" attr.\"dup\"=2\n"
            )
            .as_bytes()
        );
        assert!(actual.reports.is_empty(), "{actual:?}");
    }
}

// 関門: sinkがFailを送出したら後続を呼ばず、Logを処理した外側にFailが残る。
#[test]
fn log_sink_failure_stops_before_the_next_sink() {
    let source = r#"
import Benitoite.Unofficial.Failure
function main() -> Unit uses Console.Write
 bind result: Result[Unit, String] <- Failure.toResult(body: lambda()
   Log.withSinks(sinks: [Pair(Log.Level.Debug, lambda(record: Log.Record)
     Console.writeLine("first")
     Failure.raise(error: "sink failed")
   end lambda), Pair(Log.Level.Debug, lambda(record: Log.Record)
     Console.writeLine("wrong")
   end lambda)], body: lambda()
     Log.info(message: "event", attributes: [], location: SourceLocation.here())
     Console.writeLine("wrong continuation")
   end lambda)
 end lambda)
 Console.writeLine(match result with
   case Result.Error(error) -> error
   case Result.Ok(_) -> "wrong result"
 end match)
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let actual = observe(source, mode, Order::Real, b"", false);
        assert_eq!(actual.end, EndKind::Returned, "{actual:?}");
        assert_eq!(actual.stdout, b"first\nsink failed\n");
        assert!(actual.stderr.is_empty(), "{actual:?}");
        assert!(actual.reports.is_empty(), "{actual:?}");
    }
}

// 関門: 別ファイルの追加Failを実IOとNoFailの具体化へ接続し、両実行方式と完了順を照合する。
#[test]
fn file_uses_failure_contract_connects_to_io_handlers() {
    let library = "import Benitoite.Unofficial.Failure\nuses Failure.Fail[String]\npublic function load[effect E](body: function() -> Result[String, String] uses E) -> String uses E\n return Failure.fromResult(body())\nend function\n";
    let source = r#"
import Load
import Benitoite.Unofficial.Failure
uses File.Read, Console.Write
function main() -> Unit
 bind values <- Task.all([lambda()
  return Failure.toResult(body: lambda()
   return Load.load(body: lambda()
    return File.readText("input.txt") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
   end lambda)
  end lambda)
 end lambda, lambda()
  return Failure.toResult(body: lambda() return Load.load(body: lambda() return Result.Error("failed") end lambda) end lambda)
 end lambda])
 Console.writeLine(if values = [Result.Ok("first\nsecond\n"), Result.Error("failed")] then "ok" else "wrong" end if)
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for order in [Order::Forward, Order::Reverse, Order::Real] {
            let result = observe_files(source, &[("Load.bnt", library)], mode, order, b"", false);
            assert_eq!(
                result.end,
                EndKind::Returned,
                "{mode:?}/{order:?}: {result:?}"
            );
            assert_eq!(result.exit_code, 0, "{result:?}");
            assert_eq!(result.stdout, b"ok\n");
            assert!(
                result.stderr.is_empty() && result.reports.is_empty(),
                "{result:?}"
            );
        }
    }
}
