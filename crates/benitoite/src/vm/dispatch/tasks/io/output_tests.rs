//! 出力の待ちを本物の VM・IO 実行器と筋書きで確かめる（実装プラン R27、ADR 0265・0283・0314）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::super::tests::compile;
use super::tests::{IMPORTS, consumed, finish};
use super::*;
use crate::builtins::iface::{IoCtx, IoReply, Lent, builtin};
use crate::runtime::heap::{FieldsKind, HeapConfig};
use crate::runtime::io::output::{OutputPort, testing::gated};
use crate::runtime::io::services::RunInput;
use crate::runtime::run::NoInterrupt;
use crate::runtime::sched::testing::{ScheduleHandle, ScheduleStep};
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::{ExecMode, Vm};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::{Arc, Mutex};

fn runtime(
    script: &ScheduleHandle,
    stdout: Box<dyn std::io::Write + Send>,
    stderr: Box<dyn std::io::Write + Send>,
) -> TestIo {
    let wakeup = script.wakeup();
    TestIo {
        rt: IoRuntime::new(
            RunInput {
                arguments: vec![],
                working_directory: "/".into(),
                script_directory: "/".into(),
            },
            ExecMode::Direct,
            (
                OutputPort::start(Stream::Stdout, stdout, false, wakeup.clone()),
                OutputPort::start(Stream::Stderr, stderr, false, wakeup.clone()),
            ),
            Box::new(std::io::Cursor::new(Vec::<u8>::new())),
            script.parts(),
            Box::new(NoInterrupt),
            wakeup,
        ),
    }
}
fn vm(program: &CompiledProgram) -> Vm<'_> {
    let mut vm = Vm::new(
        program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    vm
}
// 関門: 小さい非端末出力は、ほかのタスクが走っている間の予算切り替えでも届く。
// OutputPort 単体では VM の切り替えとの接続を確かめられない。出力先からの通知で
// 到着を待ち、実時間を切り替えの順序に使わない（設計書 02-09「出力のバッファ」、ADR 0320）。
#[test]
fn budget_switch_transfers_both_short_outputs_while_another_task_computes() {
    let program = compile(&format!(
        r#"{IMPORTS}
function compute(n: Integer) -> Unit
 if n = 0 then return () end if
 return compute(n - 1)
end function
function main() -> Unit uses Console.Write,Clock.Time
 bind _ <- Task.all([
 lambda()
  Console.write("ready")
  Console.writeError("progress")
  Clock.sleep(10)
 end lambda,
 lambda() return compute(30000) end lambda])
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new(
            [1, 1, 1, 2, 2]
                .into_iter()
                .map(ScheduleStep::PickTask)
                .chain([ScheduleStep::Advance(10), ScheduleStep::PickTask(1)]),
            false,
        );
        let (out_send, out_recv) = std::sync::mpsc::channel();
        let (err_send, err_recv) = std::sync::mpsc::channel();
        let mut io = runtime(
            &script,
            Box::new(ArrivalRecorder(out_send)),
            Box::new(ArrivalRecorder(err_send)),
        );
        let mut vm = vm(&program);
        let observed = Rc::new(RefCell::new(false));
        let watch = Rc::clone(&observed);
        let schedule = script.clone();
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
            if schedule.record().consumed == 4 && !*watch.borrow() {
                // A は時間を待ち、B は一巡だけ計算を進めた。終了前の到着を確かめる。
                assert_eq!(state.tasks.live_count(), 3);
                assert!(!state.scheduler.ready.is_empty());
                let timeout = std::time::Duration::from_secs(1);
                assert_eq!(out_recv.recv_timeout(timeout).unwrap(), b"ready");
                assert_eq!(err_recv.recv_timeout(timeout).unwrap(), b"progress");
                *watch.borrow_mut() = true;
            }
            Ok(())
        }));
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert!(*observed.borrow());
        assert_eq!(io.rt.stdout.finish(), Ok(()));
        assert_eq!(io.rt.stderr.finish(), Ok(()));
        consumed(&script);
    }
}
#[derive(Debug)]
struct ArrivalRecorder(std::sync::mpsc::Sender<Vec<u8>>);
impl std::io::Write for ArrivalRecorder {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        self.0.send(bytes.to_vec()).unwrap();
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
const CHUNKS: &str = r#"
function chunk(n: Integer, text: String) -> String
 if n = 0 then return text else return chunk(n - 1, text + text) end if
end function
function writes(n: Integer, text: String) -> Unit uses Console.Write
 if n > 0 then
  Console.write(text)
  writes(n - 1, text)
 end if
end function
"#;
// 関門: OutputPort の単体テストでは、待つ IO の pc と根、別のタスクの進行は検査できない。
#[test]
fn stalled_stdout_preserves_capacity_frame_and_allows_stderr_and_virtual_timer() {
    let program = compile(&format!(
        r#"{IMPORTS}{CHUNKS}
function main() -> Unit uses Console.Write,Clock.Time
 bind _ <- Task.all([
 lambda() return writes(32, chunk(16, "x")) end lambda,
 lambda()
  Clock.sleep(10)
  Console.writeError("other")
  return ()
 end lambda])
 return ()
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new(std::iter::repeat_n(ScheduleStep::PickTask(1), 17), false);
        let (sink, gate) = gated(false, false);
        let stdout = Arc::clone(&gate.bytes);
        let stderr = Arc::new(Mutex::new(Vec::new()));
        let mut io = runtime(&script, sink, Box::new(Recorder(Arc::clone(&stderr))));
        io.rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin("Benitoite.IO.Clock.sleep").unwrap(),
            &sleep::DECL,
        );
        let io_sites: Vec<_> = program
            .protos
            .iter()
            .enumerate()
            .flat_map(|(proto, p)| {
                p.code.iter().enumerate().filter_map(move |(pc, instr)| {
                    (instr.opcode() == Some(Opcode::Io)).then_some(InstrRef {
                        proto: ProtoIdx(u32::try_from(proto).unwrap()),
                        pc: u32::try_from(pc).unwrap(),
                    })
                })
            })
            .collect();
        let mut vm = vm(&program);
        let observed = Rc::new(RefCell::new(0u8));
        let watch = Rc::clone(&observed);
        let time = script.clone();
        let mut released = false;
        let mut advanced = false;
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            if let Some((&task, _)) = state.scheduler.waiting.iter().find(|(_, w)| {
                w.reason == WaitReason::Output(Stream::Stdout, OutputWaitKind::Capacity)
            }) {
                assert!(!state.scheduler.is_deadlocked());
                let task = ctx
                    .host::<TaskObj>(state.tasks.get(ctx, task).unwrap())
                    .unwrap();
                let segment = task.stack.segments.last().unwrap();
                let frame = segment.calls.last().unwrap();
                assert!(
                    segment
                        .regs
                        .iter()
                        .any(|s| ctx.str(ctx.load(s)).is_some_and(|s| s.len() == 65536))
                );
                assert!(io_sites.contains(&InstrRef {
                    proto: frame.proto,
                    pc: frame.pc
                }));
                *watch.borrow_mut() |= 1;
                if !advanced
                    && state
                        .scheduler
                        .waiting
                        .values()
                        .any(|w| matches!(w.reason, WaitReason::Timer(_)))
                {
                    time.allow_time(10);
                    advanced = true;
                }
                if state.tasks.live_count() == 2 && state.scheduler.ready.is_empty() && !released {
                    released = true;
                    assert_eq!(gate.entered(), 65536);
                    // B の完了を観察してからだけ、A の出力先を動かす。
                    *watch.borrow_mut() |= 2;
                    for _ in 0..32 {
                        gate.release();
                    }
                }
            }
            Ok(())
        }));
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(*observed.borrow(), 3);
        assert_eq!(io.rt.stdout.finish(), Ok(()));
        assert_eq!(io.rt.stderr.finish(), Ok(()));
        assert_eq!(stdout.lock().unwrap().as_slice(), vec![b'x'; 2097152]);
        assert_eq!(*stderr.lock().unwrap(), b"other");
        assert!(vm.state.scheduler.waiting.is_empty());
        assert!(vm.heap.take_fault().is_none());
        consumed(&script);
    }
}
#[derive(Debug)]
struct Recorder(Arc<Mutex<Vec<u8>>>);
impl std::io::Write for Recorder {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        self.0.lock().unwrap().extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
builtin! {
    name = "Benitoite.IO.File.readText",
    io fn flush_read(ctx, path: &'c str) -> IoReply<'e> {
        let _=(ctx,path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Stdin, |lent| {
            let Lent::Stdin(reader) = lent else { panic!("missing reader") };
            let mut text=String::new();
            reader.read_line(&mut text).unwrap();
            text
        }, flush_done).after_output_flush())))
    }
}
fn flush_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    text: String,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    assert!(matches!(
        ctx.str(args[0]),
        Some("input" | "again" | "first" | "second")
    ));
    let text = ctx.alloc_str(&text, "flush test")?;
    ctx.alloc_fields(
        FieldsKind::Ctor,
        crate::builtins::table::tags::RESULT_OK,
        &[text],
    )
}
#[derive(Debug)]
struct SnapshotReader {
    outputs: [Arc<Mutex<Vec<u8>>>; 2],
    read: Arc<Mutex<bool>>,
}
impl std::io::Read for SnapshotReader {
    fn read(&mut self, _: &mut [u8]) -> std::io::Result<usize> {
        panic!("use read_line")
    }
}
impl std::io::BufRead for SnapshotReader {
    fn fill_buf(&mut self) -> std::io::Result<&[u8]> {
        panic!("use read_line")
    }
    fn consume(&mut self, _: usize) {
        panic!("use read_line")
    }
    fn read_line(&mut self, text: &mut String) -> std::io::Result<usize> {
        assert_eq!(self.outputs[0].lock().unwrap().as_slice(), b"out");
        assert_eq!(self.outputs[1].lock().unwrap().as_slice(), b"err");
        *self.read.lock().unwrap() = true;
        text.push_str("read");
        Ok(4)
    }
}
impl crate::runtime::io::ops::StdinReader for SnapshotReader {}
fn override_flush(io: &mut TestIo) {
    io.rt.builtin_overrides.insert(
        crate::builtins::lookup_builtin("Benitoite.IO.File.readText").unwrap(),
        &flush_read::DECL,
    );
}
// 関門: 仕事の実行時に両出力が届く契約と、Flush の再開で pc を進めない契約を同時に守る。
#[test]
fn work_waits_for_stdout_then_stderr_while_other_tasks_progress() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Result[Unit,String] uses Console.Write,File.Read
 Console.write("out")
 Console.writeError("err")
 bind values <- Task.all([lambda()
 bind read <- File.readText("in" + "put")
 return match read with case Result.Ok(text) -> text
 case Result.Error(_) -> "error" end match
 end lambda,lambda() return "oth" + "er" end lambda])
 bind again <- File.readText("again")
 return match again with
 case Result.Ok(text) -> if text = "read" and values = ["read","other"] then Result.Ok(()) else Result.Error("lost IO result") end if
 case Result.Error(_) -> Result.Error("second read failed")
 end match
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new(
            [
                ScheduleStep::PickTask(0),
                ScheduleStep::PickTask(0),
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2),
            ],
            false,
        );
        let (out, out_gate) = gated(false, false);
        let (err, err_gate) = gated(false, false);
        let outputs = [Arc::clone(&out_gate.bytes), Arc::clone(&err_gate.bytes)];
        let stdout_bytes = Arc::clone(&outputs[0]);
        let mut io = runtime(&script, out, err);
        override_flush(&mut io);
        let read = Arc::new(Mutex::new(false));
        io.rt.stdin = Some(Box::new(SnapshotReader {
            outputs,
            read: Arc::clone(&read),
        }));
        let mut vm = vm(&program);
        let observed = Rc::new(RefCell::new(0u8));
        let watch = Rc::clone(&observed);
        let worker = script.clone();
        let mut gates = [Some(out_gate), Some(err_gate)];
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
            for (index, stream) in [Stream::Stdout, Stream::Stderr].into_iter().enumerate() {
                if state
                    .scheduler
                    .waiting
                    .values()
                    .any(|w| w.reason == WaitReason::Output(stream, OutputWaitKind::Flush))
                {
                    assert!(!state.scheduler.is_deadlocked());
                    if state.tasks.live_count() == 2
                        && let Some(gate) = gates[index].take()
                    {
                        if index == 0 {
                            // 進められるタスクがないと両出力を転送するため、転送を始めた順序ではなく
                            // 完了を待つ順序を確かめる（実装プラン R27「転送を依頼する時点」「完了の待ち」）。
                            assert!(!state.scheduler.waiting.values().any(|w| {
                                w.reason
                                    == WaitReason::Output(Stream::Stderr, OutputWaitKind::Flush)
                            }));
                        } else {
                            assert_eq!(*watch.borrow(), 1);
                            assert_eq!(stdout_bytes.lock().unwrap().as_slice(), b"out");
                        }
                        assert_eq!(gate.entered(), 3);
                        gate.release();
                        *watch.borrow_mut() |= 1 << index;
                    }
                }
            }
            if let Some(op) = state.scheduler.waiting.values().find_map(|w| {
                if let WaitReason::Worker(op) = w.reason {
                    Some(op)
                } else {
                    None
                }
            }) {
                worker.allow_worker(op);
            }
            Ok(())
        }));
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(*observed.borrow(), 3);
        assert!(*read.lock().unwrap());
        assert!(io.rt.queue.live.is_empty());
        assert!(vm.state.scheduler.waiting.is_empty());
        consumed(&script);
    }
}

builtin! {
 name = "Benitoite.IO.Clock.sleep",
 io fn sleep(ctx, millis: i64) -> IoReply<'e> {
  let _=ctx;
  Ok(IoReply::Wait(IoWait::Sleep { millis: u64::try_from(millis).unwrap() }))
 }
}
// 関門: 待つタスクのない転送を外部の待ちに数えると、循環した await が止まり続ける。
// Flush の待ちがある場合だけ、書き出しの完了を待ってから行き詰まりを報告する。
#[test]
fn transfer_only_prevents_deadlock_when_a_task_waits_for_it() {
    for flush in [false, true] {
        let second_output = if flush {
            ""
        } else {
            "Console.writeError(\"err\")"
        };
        let third = if flush {
            "bind _ <- TaskGroup.spawn(group,lambda() bind _ <- File.readText(\"input\")\n return () end lambda)"
        } else {
            ""
        };
        let program = compile(&format!(
            r#"{IMPORTS}
function main() -> Unit uses State,Console.Write,File.Read
 bind a <- Reference.new(Option.None)
 bind b <- Reference.new(Option.None)
 with group = TaskGroup.open() do
  bind ta <- TaskGroup.spawn(group,lambda()
   Console.write("one")
   match Reference.get(b) with case Option.Some(t) -> Task.await(t)
   case Option.None -> () end match
   return ()
  end lambda)
  bind tb <- TaskGroup.spawn(group,lambda()
   Console.write("two")
   {second_output}
   match Reference.get(a) with case Option.Some(t) -> Task.await(t)
   case Option.None -> () end match
   return ()
  end lambda)
  {third}
  Reference.set(a,Option.Some(ta))
  Reference.set(b,Option.Some(tb))
 end with
 return ()
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let script = ScheduleHandle::new([], false);
            let (sink, gate) = gated(false, false);
            let recorded = Arc::clone(&gate.bytes);
            let (stderr_sink, stderr_gate) = gated(false, false);
            let mut io = runtime(&script, sink, stderr_sink);
            override_flush(&mut io);
            let mut vm = vm(&program);
            let observed = Rc::new(RefCell::new(false));
            let watch = Rc::clone(&observed);
            if flush {
                let worker = script.clone();
                let mut released = false;
                vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
                    if !released
                        && state.scheduler.ready.is_empty()
                        && state.scheduler.waiting.values().any(|w| {
                            w.reason == WaitReason::Output(Stream::Stdout, OutputWaitKind::Flush)
                        })
                    {
                        assert_eq!(
                            state
                                .scheduler
                                .waiting
                                .values()
                                .filter(|w| matches!(
                                    w.reason,
                                    WaitReason::TaskEnd(TaskEndWait::Await(_))
                                ))
                                .count(),
                            2
                        );
                        assert!(!state.scheduler.is_deadlocked());
                        assert!(state.stopping.is_none());
                        assert_eq!(gate.entered(), 6);
                        gate.release();
                        released = true;
                        *watch.borrow_mut() = true;
                    }
                    if let Some(op) = state.scheduler.waiting.values().find_map(|w| {
                        if let WaitReason::Worker(op) = w.reason {
                            Some(op)
                        } else {
                            None
                        }
                    }) {
                        worker.allow_worker(op);
                    }
                    Ok(())
                }));
            } else {
                // run の戻りより先に出力を動かすと、このテストは退行を捕まえない。
                let step = finish(&mut vm, &mut io, mode);
                assert!(
                    matches!(step,VmStep::Stopped(StopEnd { reason:StopReason::Error(ref info),.. }) if info.stop==Stop::Runtime(RuntimeError::TaskDeadlock)),
                    "{step:?}"
                );
                assert_eq!(gate.entered(), 6);
                assert_eq!(stderr_gate.entered(), 3);
                gate.release();
                stderr_gate.release();
                assert_eq!(io.rt.stdout.finish(), Ok(()));
                assert_eq!(*recorded.lock().unwrap(), b"onetwo");
                assert_eq!(io.rt.stderr.finish(), Ok(()));
                assert_eq!(*stderr_gate.bytes.lock().unwrap(), b"err");
                consumed(&script);
                continue;
            }
            let step = finish(&mut vm, &mut io, mode);
            assert!(
                matches!(step,VmStep::Stopped(StopEnd { reason:StopReason::Error(ref info),.. }) if info.stop==Stop::Runtime(RuntimeError::TaskDeadlock)),
                "{step:?}"
            );
            assert!(*observed.borrow());
            assert_eq!(io.rt.stdout.finish(), Ok(()));
            assert_eq!(*recorded.lock().unwrap(), b"onetwo");
            consumed(&script);
        }
    }
}
// 関門: 容量と完了の待ちを止める処理は、単体のポートでは命令の位置と診断を検査できない。
#[test]
fn writer_failure_or_panic_stops_capacity_and_flush_waiters_without_delivering_deferred_bytes() {
    for capacity in [true, false] {
        let count = if capacity { 17 } else { 1 };
        let program = compile(
            &format!(
                r#"{IMPORTS}{CHUNKS}
function main() -> Unit uses Console.Write,File.Read
 bind _ <- Task.all([lambda() writes({count},chunk(16,"x")) return () end lambda,
 lambda() bind _ <- File.readText("input") return () end lambda])
 return ()
end function
"#
            )
            .replace(")) return", "))\n return")
            .replace("(\"input\") return", "(\"input\")\n return"),
        );
        for panic in [false, true] {
            for mode in [ExecMode::Direct, ExecMode::Request] {
                let script = ScheduleHandle::new(
                    std::iter::repeat_n(ScheduleStep::PickTask(1), count),
                    false,
                );
                let (sink, gate) = gated(!panic, panic);
                let bytes = Arc::clone(&gate.bytes);
                let mut io = runtime(&script, sink, Box::new(std::io::sink()));
                override_flush(&mut io);
                let mut vm = vm(&program);
                let observed = Rc::new(RefCell::new(false));
                let watch = Rc::clone(&observed);
                let mut released = false;
                vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
                    let output_waits = state
                        .scheduler
                        .waiting
                        .values()
                        .filter(|w| matches!(w.reason, WaitReason::Output(..)))
                        .count();
                    if output_waits == (if capacity { 2 } else { 1 }) && !released {
                        assert_eq!(gate.entered(), 65536);
                        gate.release();
                        released = true;
                        *watch.borrow_mut() = true;
                    }
                    Ok(())
                }));
                let step = finish(&mut vm, &mut io, mode);
                let VmStep::Stopped(StopEnd {
                    reason: StopReason::Error(info),
                    ..
                }) = step
                else {
                    panic!("missing failure: {step:?}")
                };
                assert!(*observed.borrow());
                assert!(info.at.is_some());
                let diagnostic = crate::runtime::report::stop_diagnostic(&program, &info);
                if panic {
                    assert!(matches!(info.stop, Stop::Internal(_)));
                    assert!(matches!(
                        io.rt.stdout.finish(),
                        Err(WriteFailure::Panicked(_))
                    ));
                } else {
                    assert!(matches!(
                        info.stop,
                        Stop::Runtime(RuntimeError::WriteFailed {
                            stream: Stream::Stdout,
                            ..
                        })
                    ));
                    assert_eq!(diagnostic.code, Some(crate::diag::DiagCode::R0201));
                    assert!(diagnostic.primary.is_none());
                    assert!(diagnostic.trace.is_none());
                    assert!(diagnostic.task_origins.is_empty());
                    assert!(matches!(io.rt.stdout.finish(), Err(WriteFailure::Io(_))));
                }
                assert!(bytes.lock().unwrap().is_empty());
                assert!(vm.state.scheduler.waiting.is_empty());
                assert!(io.rt.output_sites.is_empty());
                assert!(io.rt.queue.live.is_empty());
                consumed(&script);
            }
        }
    }
}
#[test]
fn recorded_writer_failure_is_seen_by_the_next_write_instruction() {
    let program = compile(&format!(
        r#"{IMPORTS}{CHUNKS}
function main() -> Unit uses Console.Write
 Console.write(chunk(16,"x"))
 Console.write("later")
 return ()
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (sink, gate) = gated(true, false);
        let mut io = runtime(&script, sink, Box::new(std::io::sink()));
        let wakeup = script.wakeup();
        let mut vm = vm(&program);
        let mut synchronized = false;
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
            if !synchronized && !state.scheduler.ready.is_empty() {
                assert_eq!(gate.entered(), 65536);
                gate.release();
                assert!(crate::runtime::io::event::wait_counted(&wakeup, 0).is_some());
                synchronized = true;
            }
            Ok(())
        }));
        let step = finish(&mut vm, &mut io, mode);
        let VmStep::Stopped(StopEnd {
            reason: StopReason::Error(info),
            ..
        }) = step
        else {
            panic!("missing failure: {step:?}")
        };
        assert!(matches!(
            info.stop,
            Stop::Runtime(RuntimeError::WriteFailed { .. })
        ));
        let site = info.at.unwrap();
        let span = crate::runtime::report::instr_span(&program, site).unwrap();
        let source = program.sources.get(span.file).unwrap().text();
        assert_eq!(
            &source[usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()],
            b"Console.write(\"later\")"
        );
        assert!(vm.state.scheduler.waiting.is_empty());
        consumed(&script);
    }
}
// 関門: タスクの取り消しが IO の預かりを外し忘れると、race の後に出力または仕事が実行される。
#[test]
fn cancelling_output_wait_keeps_accepted_bytes_and_discards_pending_write_or_work() {
    for capacity in [true, false] {
        let action = if capacity {
            "writes(17,chunk(16,\"x\"))"
        } else {
            "Console.write(\"accepted\")\n bind _ <- File.readText(\"input\")"
        };
        let program = compile(&format!(
            r#"{IMPORTS}{CHUNKS}
function main() -> Result[Unit,String] uses Console.Write,File.Read,Clock.Time,State
 bind winner <- Task.race([lambda()
  {action}
  return 1
 end lambda,lambda() return 2 end lambda])
 if winner = Option.Some(2) then return Result.Ok(()) else return Result.Error("cancellation") end if
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let count = if capacity { 17 } else { 2 };
            let script =
                ScheduleHandle::new(std::iter::repeat_n(ScheduleStep::PickTask(1), count), false);
            let (sink, gate) = gated(false, false);
            let mut io = runtime(&script, sink, Box::new(std::io::sink()));
            override_flush(&mut io);
            let mut vm = vm(&program);
            let observed = Rc::new(RefCell::new(false));
            let watch = Rc::clone(&observed);
            vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
                if state
                    .scheduler
                    .waiting
                    .values()
                    .any(|w| matches!(w.reason, WaitReason::Output(..)))
                {
                    *watch.borrow_mut() = true;
                }
                Ok(())
            }));
            assert_eq!(
                finish(&mut vm, &mut io, mode),
                VmStep::Finished(MainOutcome::Ok)
            );
            assert!(*observed.borrow());
            assert!(io.rt.queue.live.is_empty());
            assert!(io.rt.ops.records.is_empty());
            assert!(io.rt.output_sites.is_empty());
            assert!(vm.state.scheduler.waiting.is_empty());
            let expected = if capacity { 1048576 } else { 8 };
            assert_eq!(gate.entered(), if capacity { 65536 } else { 8 });
            for _ in 0..count {
                gate.release();
            }
            assert_eq!(io.rt.stdout.finish(), Ok(()));
            assert_eq!(gate.bytes.lock().unwrap().len(), expected);
            consumed(&script);
        }
    }
}
#[test]
fn work_with_empty_output_does_not_enter_a_flush_wait() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Unit uses File.Read
 bind _ <- File.readText("first")
 bind _ <- File.readText("second")
 return ()
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let mut io = runtime(
            &script,
            Box::new(std::io::sink()),
            Box::new(std::io::sink()),
        );
        override_flush(&mut io);
        let mut vm = vm(&program);
        let worker = script.clone();
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
            assert!(
                !state
                    .scheduler
                    .waiting
                    .values()
                    .any(|w| matches!(w.reason, WaitReason::Output(..)))
            );
            if let Some(op) = state.scheduler.waiting.values().find_map(|w| {
                if let WaitReason::Worker(op) = w.reason {
                    Some(op)
                } else {
                    None
                }
            }) {
                worker.allow_worker(op);
            }
            Ok(())
        }));
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        consumed(&script);
    }
}
