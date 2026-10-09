//! 要求と完了の競合を本番の VM と筋書きの部品で確かめる（実装プラン R26）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::super::tests::{compile, services};
use super::*;
use crate::builtins::iface::{IoCtx, IoReply, Lent, OsResource, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{FieldsKind, HeapConfig, ResourceId};
use crate::runtime::io::resources::ResourceContent;
use crate::runtime::sched::ExtOpId;
use crate::runtime::sched::parts::{IdleWake, WorkerExec};
use crate::runtime::sched::testing::{ScheduleEvent, ScheduleHandle, ScheduleStep};
use crate::runtime::{ResourceKind, Stream};
use crate::vm::Vm;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::{Arc, Mutex};

builtin! {
    name = "Benitoite.IO.File.readText",
    io fn fake_read(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx=ctx;
        ctx.services().write_output(Stream::Stdout,path)?;
        if path.starts_with("exit") { return Ok(IoReply::Exit(crate::builtins::iface::ExitStatus(17))); }
        let lend=if path.starts_with("resource") || path.starts_with("panic") { Lend::Resource(*ctx.services().runtime_view().unwrap().resources.entries.keys().next().unwrap()) }
            else if path.starts_with("stdin") { Lend::Stdin } else { Lend::Nothing };
        let panic=path.starts_with("panic");
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(lend,move |lent| {
            assert!(!panic,"fake job panic");
            match lent {
                Lent::Stdin(reader) => {let mut line=String::new(); reader.read_line(&mut line).unwrap(); line},
                Lent::Nothing | Lent::Resource(_) => "job".to_owned(),
            }
        }, read_done))))
    }
}
fn read_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: String,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let path = ctx.str(args[0]).unwrap();
    let value = ctx.alloc_str(&format!("{path}:{output}"), "fake read")?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}
builtin! {
    name = "Benitoite.IO.Console.writeLine",
    io fn fake_sleep(ctx, text: &'c str) -> IoReply<'e> {
        let _=(ctx,text);
        Ok(IoReply::Wait(IoWait::Sleep{millis:10}))
    }
}
#[derive(Debug)]
struct FakeResource {
    fail: bool,
    released: Arc<Mutex<usize>>,
}
impl OsResource for FakeResource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        *self.released.lock().unwrap() += 1;
        if self.fail {
            Err("fake release failed".into())
        } else {
            Ok(())
        }
    }
}
#[derive(Clone, Copy, Debug)]
struct Submission {
    op: ExtOpId,
    release: bool,
}
#[derive(Debug)]
struct RecordingWorkers {
    inner: Box<dyn WorkerExec>,
    submissions: Rc<RefCell<Vec<Submission>>>,
    followup: Option<ScheduleHandle>,
}
impl WorkerExec for RecordingWorkers {
    fn submit(&mut self, job: WorkerJob) {
        self.submissions.borrow_mut().push(Submission {
            op: job.op,
            release: matches!(job.work, JobWork::Release(_)),
        });
        if self.submissions.borrow().len() > 1
            && let Some(script) = &self.followup
        {
            script.allow_worker(job.op);
        }
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<ops::Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        self.inner.idle(deadline)
    }
}
fn runtime(
    script: &ScheduleHandle,
    followup: bool,
) -> (
    crate::vm::dispatch::test_support::TestIo,
    Rc<RefCell<Vec<Submission>>>,
) {
    let mut io = services();
    io.rt.parts = script.parts();
    let submissions = Rc::new(RefCell::new(Vec::new()));
    let old = std::mem::replace(&mut io.rt.parts.workers, script.parts().workers);
    io.rt.parts.workers = Box::new(RecordingWorkers {
        inner: old,
        submissions: Rc::clone(&submissions),
        followup: followup.then(|| script.clone()),
    });
    io.rt.builtin_overrides.insert(
        crate::builtins::lookup_builtin("Benitoite.IO.File.readText").unwrap(),
        &fake_read::DECL,
    );
    (io, submissions)
}
pub(super) fn finish(
    vm: &mut Vm<'_>,
    io: &mut crate::vm::dispatch::test_support::TestIo,
    mode: ExecMode,
) -> VmStep {
    loop {
        match vm.run(io.runtime(mode)) {
            VmStep::Requests(ids) => {
                vm.heap.collect(&vm.state);
                for id in ids {
                    vm.serve_request(&mut io.rt, id)
                }
            }
            result @ (VmStep::Finished(_) | VmStep::Stopped(_)) => return result,
        }
    }
}
pub(super) fn consumed(script: &ScheduleHandle) {
    let record = script.record();
    assert_eq!(record.remaining, 0, "{record:?}");
    assert!(record.error.is_none(), "{record:?}");
    assert!(
        record
            .events
            .iter()
            .any(|e| matches!(e, ScheduleEvent::Spawned { serial: 0, .. }))
    );
}
pub(super) const IMPORTS: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Clock\n";
// 関門: 一タスクの IO のテストでは、別タスクの計算中の送り出し・配送と
// 引数の根の漏れを捕まえられない。筋書きで両者を進め、本番の回収を強制する。
#[test]
fn queued_work_and_completion_progress_while_another_task_computes() {
    let source = format!(
        r#"{IMPORTS}
function spin(n:Integer) -> Result[String, IOError]
 if n = 0 then return Result.Ok("B") else return spin(n - 1) end if
end function
function main() -> Result[Unit,String] uses File.Read
 bind values <- Task.all([lambda() return File.readText("heap" + " arg") end lambda,lambda() return spin(40) end lambda])
 bind texts <- List.map(values, lambda(r) return match r with case Result.Ok(t) -> t
 case Result.Error(_) -> "error" end match end lambda)
 if texts = ["heap arg:job","B"] then return Result.Ok(()) else return Result.Error("delivery") end if
end function
"#
    );
    let program = compile(&source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &program,
            VmConfig {
                call_budget: 1,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let script = ScheduleHandle::new(
            [
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2),
                ScheduleStep::RunWorker(ExtOpId(0)),
                ScheduleStep::PickTask(1),
            ],
            false,
        );
        let (mut io, submissions) = runtime(&script, false);
        let observed = Rc::new(RefCell::new((false, false)));
        let watch = Rc::clone(&observed);
        let jobs = Rc::clone(&submissions);
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            let b = TaskId {
                index: 2,
                generation: 0,
            };
            if state.tasks.get(ctx, b).is_some() {
                if !jobs.borrow().is_empty() {
                    watch.borrow_mut().0 = true;
                }
                if state.scheduler.ready.iter().any(|t| t.index == 1) {
                    watch.borrow_mut().1 = true;
                }
            }
            Ok(())
        }));
        if mode == ExecMode::Request {
            let VmStep::Requests(ids) = vm.run(io.runtime(mode)) else {
                panic!("request not returned")
            };
            assert_eq!(ids.len(), 1);
            assert!(submissions.borrow().is_empty());
            vm.heap.epoch(|ctx| {
                assert!(
                    vm.state
                        .tasks
                        .get(
                            ctx,
                            TaskId {
                                index: 2,
                                generation: 0
                            }
                        )
                        .is_some()
                )
            });
            vm.heap.collect(&vm.state);
            for id in ids {
                vm.serve_request(&mut io.rt, id);
            }
        }
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(*observed.borrow(), (true, true));
        assert_eq!(submissions.borrow().len(), 1);
        assert!(vm.heap_stats().collections > 0);
        assert!(vm.heap.take_fault().is_none());
        consumed(&script);
        let events = script.record().events;
        let ran = events
            .iter()
            .position(|e| matches!(e, ScheduleEvent::WorkerRan(ExtOpId(0))))
            .unwrap();
        assert!(matches!(
            events[ran - 1],
            ScheduleEvent::Picked {
                task: TaskId { index: 2, .. },
                ..
            }
        ));
    }
}
// 関門: 返却待ちの再開で raw を呼び直すと副作用を重ね、引数と site の対応を失う。
// 標準入力と通常の資源を同じ VM の入口で比べ、待つ間の回収も通す。
#[test]
fn lend_wait_restarts_without_reinvoking_and_stdin_preserves_fifo() {
    for stdin in [false, true] {
        let prefix = if stdin { "stdin" } else { "resource" };
        let suffix1 = if stdin { "first\\n" } else { "job" };
        let suffix2 = if stdin { "second\\n" } else { "job" };
        let source = format!(
            r#"{IMPORTS}
function busy(n:Integer) -> Result[String,IOError]
 if n = 0 then return Result.Ok("busy") else return busy(n - 1) end if
end function
function main() -> Result[Unit,String] uses File.Read
 bind values <- Task.all([lambda() return File.readText("{prefix}" + " one") end lambda,lambda() return File.readText("{prefix}" + " two") end lambda,lambda() return busy(20) end lambda])
 bind texts <- List.map(values, lambda(r) return match r with case Result.Ok(t) -> t
 case Result.Error(_) -> "error" end match end lambda)
 if texts = ["{prefix} one:{suffix1}","{prefix} two:{suffix2}","busy"] then return Result.Ok(()) else return Result.Error("lend results") end if
end function
"#
        );
        let program = compile(&source);
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(
                &program,
                VmConfig {
                    call_budget: 1,
                    ..VmConfig::default()
                },
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let released = Arc::new(Mutex::new(0));
            if !stdin {
                vm.state.resources.insert(
                    ResourceKind::FileReader,
                    ResourceContent::Os(Some(Box::new(FakeResource {
                        fail: false,
                        released,
                    }))),
                    None,
                );
            }
            let second = if stdin { 1 } else { 2 };
            let script = ScheduleHandle::new(
                [
                    ScheduleStep::PickTask(1),
                    ScheduleStep::PickTask(2),
                    ScheduleStep::PickTask(3),
                    ScheduleStep::RunWorker(ExtOpId(0)),
                ],
                false,
            );
            let (mut io, submissions) = runtime(&script, true);
            io.rt.stdin = Some(Box::new(std::io::Cursor::new(b"first\nsecond\n".to_vec())));
            let waiting = Rc::new(RefCell::new(false));
            let watch = Rc::clone(&waiting);
            vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
                if state
                    .scheduler
                    .waiting
                    .values()
                    .any(|w| matches!(w.reason, WaitReason::Lend(_)))
                {
                    *watch.borrow_mut() = true;
                }
                Ok(())
            }));
            assert_eq!(
                finish(&mut vm, &mut io, mode),
                VmStep::Finished(MainOutcome::Ok)
            );
            assert!(*waiting.borrow());
            assert_eq!(
                submissions
                    .borrow()
                    .iter()
                    .map(|s| s.op)
                    .collect::<Vec<_>>(),
                [ExtOpId(0), ExtOpId(second)]
            );
            assert_eq!(
                io.take_output(),
                vec![
                    (Stream::Stdout, format!("{prefix} one").into_bytes()),
                    (Stream::Stdout, format!("{prefix} two").into_bytes())
                ]
            );
            assert!(vm.heap.take_fault().is_none());
            consumed(&script);
        }
    }
}
#[test]
fn sleep_reparks_at_io_and_virtual_deadline_writes_unit() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Result[Unit,String] uses Console.Write
 bind text <- "heap" + " sleep"
 bind result <- Console.writeLine(text)
 if result = () then return Result.Ok(()) else return Result.Error(text) end if
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let script = ScheduleHandle::new([], false);
        let (mut io, _) = runtime(&script, false);
        io.rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin("Benitoite.IO.Console.writeLine").unwrap(),
            &fake_sleep::DECL,
        );
        if mode == ExecMode::Request {
            let VmStep::Requests(ids) = vm.run(io.runtime(mode)) else {
                panic!("request missing")
            };
            for id in ids {
                vm.serve_request(&mut io.rt, id);
            }
        }
        script.allow_time(9);
        script.allow_time(1);
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(script.clock().monotonic_millis(), 10);
        consumed(&script);
    }
    let mut scheduler = crate::runtime::sched::Scheduler::default();
    let task = TaskId {
        index: 0,
        generation: 0,
    };
    assert!(
        scheduler
            .repark(
                task,
                WaitReason::Response,
                WaitReason::Timer(crate::runtime::sched::TimerId(0))
            )
            .is_err()
    );
    scheduler.park(task, WaitReason::Response);
    assert!(
        scheduler
            .repark(task, WaitReason::Lazy, WaitReason::Response)
            .is_err()
    );
    scheduler
        .repark(task, WaitReason::Response, WaitReason::Worker(ExtOpId(0)))
        .unwrap();
    assert!(!scheduler.wake_if(task, WaitReason::Response));
    assert!(scheduler.wake_if(task, WaitReason::Worker(ExtOpId(0))));
}

// 関門: Outstanding を失効させても外側は古い番号を保持する。生きた要求の
// 経路だけのテストでは、失効した番号で raw を呼ぶ副作用の退行を捕まえられない。
#[test]
fn outstanding_request_cancelled_by_race_is_never_invoked() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Result[Unit,String] uses File.Read,Clock.Time,State
 bind result <- Task.race([lambda() return File.readText("never") end lambda,lambda() return Result.Ok("winner") end lambda])
 return match result with
 case Option.Some(Result.Ok("winner")) -> Result.Ok(())
 case _ -> Result.Error("race")
 end match
end function
"#
    ));
    let mut vm = Vm::new(
        &program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let script = ScheduleHandle::new(
        [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
        false,
    );
    let (mut io, submissions) = runtime(&script, false);
    let VmStep::Requests(ids) = vm.run(io.runtime(ExecMode::Request)) else {
        panic!("request missing")
    };
    assert_eq!(ids.len(), 1);
    assert!(
        vm.state
            .scheduler
            .waiting
            .values()
            .any(|w| w.reason == WaitReason::Response)
    );
    assert_eq!(
        finish(&mut vm, &mut io, ExecMode::Request),
        VmStep::Finished(MainOutcome::Ok)
    );
    vm.serve_request(&mut io.rt, ids[0]);
    assert!(submissions.borrow().is_empty());
    assert!(io.take_output().is_empty());
    consumed(&script);
}
#[derive(Debug)]
struct BatchDispatcher(ExecMode);
impl crate::runtime::io::Dispatcher for BatchDispatcher {
    fn on_wait_point(
        &mut self,
        queue: &mut crate::runtime::io::DispatchQueue,
        at: WaitPoint,
    ) -> DispatchAction {
        if queue.queued.len() < 2 {
            DispatchAction::Nothing
        } else {
            match self.0 {
                ExecMode::Direct => crate::runtime::io::DirectDispatcher.on_wait_point(queue, at),
                ExecMode::Request => crate::runtime::io::RequestDispatcher.on_wait_point(queue, at),
            }
        }
    }
}
#[test]
fn stopping_during_a_batch_expires_the_remaining_request() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Unit uses File.Read
 bind _ <- Task.all([lambda() return File.readText("exit") end lambda,lambda() return File.readText("never") end lambda])
 return ()
end function
"#
    ));
    let mut vm = Vm::new(
        &program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let script = ScheduleHandle::new(
        [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
        false,
    );
    let (mut io, submissions) = runtime(&script, false);
    io.rt.dispatcher = Box::new(BatchDispatcher(ExecMode::Direct));
    assert!(matches!(
        vm.run(&mut io.rt),
        VmStep::Stopped(StopEnd {
            reason: StopReason::Exit(17),
            ..
        })
    ));
    assert_eq!(io.take_output(), [(Stream::Stdout, b"exit".to_vec())]);
    assert!(submissions.borrow().is_empty());
    assert!(io.rt.queue.live.is_empty());
    consumed(&script);
}

// 関門: 外側がまだ応答していないときも VM は戻る。新しい要求の送り出しだけでは
// Outstanding だけになった後に idle を繰り返す退行を捕まえられない（10-10）。
#[test]
fn outstanding_response_without_ready_tasks_returns_to_executor() {
    let program = compile(&format!(
        "{IMPORTS}\nfunction main() -> Unit uses File.Read\n bind _ <- File.readText(\"one\")\n return ()\nend function\n"
    ));
    let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
    vm.start_main().unwrap();
    let script = ScheduleHandle::new([], false);
    let (mut io, submissions) = runtime(&script, false);
    let VmStep::Requests(ids) = vm.run(io.runtime(ExecMode::Request)) else {
        panic!("expected initial request");
    };
    assert_eq!(ids.len(), 1);
    assert!(vm.state.scheduler.ready.is_empty());
    for _ in 0..2 {
        vm.heap.collect(&vm.state);
        assert_eq!(
            vm.run(io.runtime(ExecMode::Request)),
            VmStep::Requests(Vec::new())
        );
        assert!(io.take_output().is_empty());
        assert!(submissions.borrow().is_empty());
        assert!(script.record().error.is_none());
    }
    vm.serve_request(&mut io.rt, ids[0]);
    script.allow_worker(ExtOpId(0));
    assert_eq!(
        finish(&mut vm, &mut io, ExecMode::Request),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(io.take_output(), [(Stream::Stdout, b"one".to_vec())]);
    assert_eq!(submissions.borrow().len(), 1);
    consumed(&script);
}

// 関門: 外側が一括で処理する途中の最初の停止理由と、不正な要求で停止した後の
// 副作用の抑止を守る。直接方式の一括処理は serve_io の Err の経路を通らない。
#[test]
fn request_batch_preserves_first_stop_and_expires_after_serve_failure() {
    let program = compile(&format!(
        "{IMPORTS}\nfunction main() -> Unit uses File.Read\n bind _ <- Task.all([lambda() return File.readText(\"exit\") end lambda,lambda() return File.readText(\"never\") end lambda])\n return ()\nend function\n"
    ));
    for invalid_request in [false, true] {
        let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
        vm.start_main().unwrap();
        let script = ScheduleHandle::new(
            [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
            false,
        );
        let (mut io, submissions) = runtime(&script, false);
        io.rt.dispatcher = Box::new(BatchDispatcher(ExecMode::Request));
        let VmStep::Requests(ids) = vm.run(&mut io.rt) else {
            panic!("expected request batch");
        };
        assert_eq!(ids.len(), 2);
        if invalid_request {
            // 外側の要求の不変条件の破れを、本番の実行中の検査に渡す。
            let req = &mut io.rt.queue.live.get_mut(&ids[0]).unwrap().req;
            req.task.generation = req.task.generation.wrapping_add(1);
        } else {
            vm.state.stopping = Some(StopReason::Exit(9));
        }
        vm.serve_request(&mut io.rt, ids[0]);
        let reason = vm.state.stopping.clone().unwrap();
        if invalid_request {
            assert!(
                matches!(&reason, StopReason::Error(info) if matches!(info.stop, Stop::Internal(_)))
            );
        } else {
            assert_eq!(reason, StopReason::Exit(9));
        }
        vm.serve_request(&mut io.rt, ids[1]);
        assert!(io.rt.queue.live.is_empty());
        assert!(submissions.borrow().is_empty());
        assert_eq!(
            io.take_output(),
            if invalid_request {
                Vec::new()
            } else {
                vec![(Stream::Stdout, b"exit".to_vec())]
            }
        );
        assert_eq!(
            vm.run(io.runtime(ExecMode::Request)),
            VmStep::Stopped(StopEnd {
                reason,
                release_failures: vec![]
            })
        );
        consumed(&script);
    }
}
#[test]
fn cancellation_of_lend_wait_discards_the_saved_work_for_resource_and_stdin() {
    for stdin in [false, true] {
        let prefix = if stdin { "stdin" } else { "resource" };
        let program = compile(&format!(
            r#"{IMPORTS}
function main() -> Result[Unit,String] uses File.Read,Clock.Time,State
 bind values <- Task.all([
 lambda() bind _ <- File.readText("{prefix} first")
 return 1 end lambda,
 lambda()
  bind answer <- Task.race([lambda() bind _ <- File.readText("{prefix} cancelled")
 return 2 end lambda,lambda() return 42 end lambda])
  return match answer with case Option.Some(x) -> x
  case Option.None -> 0 end match
 end lambda])
 if values = [1,42] then return Result.Ok(()) else return Result.Error("cancelled lend") end if
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(
                &program,
                VmConfig::default(),
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            if !stdin {
                vm.state.resources.insert(
                    ResourceKind::FileReader,
                    ResourceContent::Os(Some(Box::new(FakeResource {
                        fail: false,
                        released: Arc::new(Mutex::new(0)),
                    }))),
                    None,
                );
            }
            let script = ScheduleHandle::new(
                [
                    ScheduleStep::PickTask(1),
                    ScheduleStep::PickTask(2),
                    ScheduleStep::PickTask(3),
                    ScheduleStep::PickTask(4),
                    ScheduleStep::PickTask(3),
                    ScheduleStep::RunWorker(ExtOpId(0)),
                ],
                false,
            );
            let (mut io, submissions) = runtime(&script, false);
            io.rt.stdin = Some(Box::new(std::io::Cursor::new(b"first\n".to_vec())));
            assert_eq!(
                finish(&mut vm, &mut io, mode),
                VmStep::Finished(MainOutcome::Ok)
            );
            assert_eq!(submissions.borrow().len(), 1);
            assert_eq!(io.take_output().len(), 2);
            assert!(io.rt.queue.live.is_empty());
            assert!(vm.heap.take_fault().is_none());
            consumed(&script);
        }
    }
}
#[test]
fn detached_unfinished_stdin_does_not_delay_ending_or_mask_a_later_deadlock() {
    for deadlock in [false, true] {
        let rest = if deadlock {
            r#"
 bind a <- Reference.new(Option.None)
 bind b <- Reference.new(Option.None)
 with group = TaskGroup.open() do
  bind ta <- TaskGroup.spawn(group,lambda()
   match Reference.get(b) with case Option.Some(t) -> Task.await(t)
   case Option.None -> () end match
   return ()
  end lambda)
  bind tb <- TaskGroup.spawn(group,lambda()
   match Reference.get(a) with case Option.Some(t) -> Task.await(t)
   case Option.None -> () end match
   return ()
  end lambda)
  Reference.set(a,Option.Some(ta))
  Reference.set(b,Option.Some(tb))
 end with
"#
        } else {
            ""
        };
        let program = compile(&format!(
            r#"{IMPORTS}
function main() -> Unit uses File.Read,State,Clock.Time
 bind _ <- Task.race([lambda() bind _ <- File.readText("stdin unfinished")
 return () end lambda,lambda() return () end lambda])
 {rest}
 return ()
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(
                &program,
                VmConfig::default(),
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let mut steps = vec![ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)];
            if deadlock {
                steps.extend([
                    ScheduleStep::PickTask(1),
                    ScheduleStep::PickTask(0),
                    ScheduleStep::PickTask(3),
                    ScheduleStep::PickTask(4),
                ]);
            }
            let script = ScheduleHandle::new(steps, false);
            let (mut io, submissions) = runtime(&script, false);
            let step = finish(&mut vm, &mut io, mode);
            if deadlock {
                let VmStep::Stopped(StopEnd {
                    reason: StopReason::Error(info),
                    ..
                }) = step
                else {
                    panic!("deadlock missing")
                };
                assert_eq!(info.stop, Stop::Runtime(RuntimeError::TaskDeadlock));
                let awaiting: Vec<_> = info
                    .deadlock
                    .iter()
                    .filter(|w| w.kind == crate::vm::DeadlockWaitKind::Builtin("Task.await"))
                    .collect();
                assert_eq!(awaiting.len(), 2);
                assert!(info.deadlock.iter().all(|w| {
                    !w.spawns
                        .iter()
                        .any(|s| s.spawned_at == io.rt.ops.records[&ExtOpId(0)].site.unwrap())
                }));
            } else {
                assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
            }
            assert_eq!(submissions.borrow().len(), 1);
            assert_eq!(io.rt.ops.records.len(), 1);
            assert!(io.rt.ops.records[&ExtOpId(0)].deliver_to.is_none());
            assert!(io.rt.stdin.is_none());
            assert!(
                !script
                    .record()
                    .events
                    .iter()
                    .any(|e| matches!(e, ScheduleEvent::WorkerRan(_)))
            );
            consumed(&script);
        }
    }
}
// 関門: USE/RETURN から WorkerExec へ解放を渡す本番の経路は、表の単体テストと
// R25 の補助による完了では届かない。待つ枠、失敗の開いた位置、停止中の返却を確かめる。
#[test]
fn blocking_release_keeps_the_frame_until_worker_completion_and_preserves_failure_site() {
    for fail in [false, true] {
        let program = compile(
            "function checkpoint() -> Unit\n return ()\nend function\nfunction main() -> Unit uses State\n with resource = TaskGroup.open() do\n checkpoint()\n checkpoint()\n checkpoint()\n return ()\n end with\nend function\n",
        );
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(
                &program,
                VmConfig {
                    call_budget: 1,
                    ..VmConfig::default()
                },
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let script = ScheduleHandle::new([], false);
            let (mut io, submissions) = runtime(&script, false);
            let released = Arc::new(Mutex::new(0));
            let record = Arc::clone(&released);
            let observed = Rc::new(RefCell::new(None));
            let watch = Rc::clone(&observed);
            let jobs = Rc::clone(&submissions);
            let work_script = script.clone();
            let mut permitted = false;
            vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
                for entry in state.resources.entries.values_mut() {
                    if entry.kind == ResourceKind::TaskGroup {
                        entry.kind = ResourceKind::FileWriter;
                        entry.content = ResourceContent::Os(Some(Box::new(FakeResource {
                            fail,
                            released: Arc::clone(&record),
                        })));
                    }
                }
                if let Some(submission) = jobs.borrow().first().copied()
                    && !permitted
                {
                    assert!(submission.release);
                    assert_eq!(*record.lock().unwrap(), 0);
                    let task = ctx
                        .host::<TaskObj>(state.tasks.get(ctx, state.current_task).unwrap())
                        .unwrap();
                    assert!(
                        matches!(&task.state, TaskState::Waiting(WaitReason::Release(_)))
                            || matches!(&task.state,TaskState::Unwinding(work) if matches!(work.waiting,Some(WaitReason::Release(_))))
                    );
                    assert!(task.returning.is_some());
                    *watch.borrow_mut() =
                        state.resources.entries.values().next().unwrap().opened_at;
                    work_script.allow_worker(submission.op);
                    permitted = true;
                }
                Ok(())
            }));
            let step = finish(&mut vm, &mut io, mode);
            if fail {
                let VmStep::Stopped(StopEnd {
                    reason: StopReason::Error(info),
                    ..
                }) = step
                else {
                    panic!("failure missing")
                };
                let Stop::Runtime(RuntimeError::ReleaseFailed(failures)) = info.stop else {
                    panic!("release failure missing")
                };
                assert_eq!(failures.len(), 1);
                assert_eq!(failures[0].opened_at, *observed.borrow());
                assert!(observed.borrow().is_some());
            } else {
                assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
            }
            assert_eq!(*released.lock().unwrap(), 1);
            assert_eq!(
                vm.state.resources.state(ResourceId(4)),
                Some(crate::runtime::io::resources::ResourceState::Released)
            );
            assert_eq!(vm.state.tasks.live_count(), 0);
            consumed(&script);
        }
    }
}
#[test]
fn worker_panic_returns_the_lent_resource_and_stops_as_an_internal_bug() {
    crate::runtime::panic::install_hook();
    let program = compile(&format!(
        "{IMPORTS}\nfunction main() -> Unit uses File.Read\n bind _ <- File.readText(\"panic\")\n return ()\nend function\n"
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        vm.state.resources.insert(
            ResourceKind::FileReader,
            ResourceContent::Os(Some(Box::new(FakeResource {
                fail: false,
                released: Arc::new(Mutex::new(0)),
            }))),
            None,
        );
        let script = ScheduleHandle::new([], false);
        let (mut io, _) = runtime(&script, false);
        if mode == ExecMode::Request {
            let VmStep::Requests(ids) = vm.run(io.runtime(mode)) else {
                panic!("request missing")
            };
            for id in ids {
                vm.serve_request(&mut io.rt, id);
            }
        }
        script.allow_worker(ExtOpId(0));
        assert!(matches!(
            finish(&mut vm, &mut io, mode),
            VmStep::Stopped(StopEnd {
                reason: StopReason::Error(crate::vm::StopInfo {
                    stop: Stop::Internal(_),
                    ..
                }),
                ..
            })
        ));
        assert_eq!(
            vm.state.resources.state(ResourceId(0)),
            Some(crate::runtime::io::resources::ResourceState::Open)
        );
        assert_eq!(io.rt.worker_bug.as_ref().unwrap().message, "fake job panic");
        assert!(io.rt.ops.records.is_empty());
        consumed(&script);
    }
}

#[test]
fn return_then_blocking_release_keeps_cancelled_owner_and_preserves_global_stop() {
    use crate::runtime::io::resources::ResourceState;
    for (stopping, fail) in [(false, false), (false, true), (true, false)] {
        let ending = if stopping {
            "bind zero <- 0\n return 1 div zero"
        } else {
            "return 42"
        };
        let program = compile(&format!(
            r#"{IMPORTS}
function pause(n:Integer) -> Unit
 if n = 0 then return () else return pause(n - 1) end if
end function
function main() -> Result[Unit,String] uses File.Read,State,Clock.Time
 bind changed <- Reference.new(false)
 bind answer <- Task.race([
 lambda()
  with resource = TaskGroup.open() do
   pause(2)
   bind _ <- File.readText("resource" + " owner")
   Reference.set(changed,true)
   return 1
  end with
 end lambda,
 lambda() bind _ <- File.readText("resource borrower")
  return 2
 end lambda,
 lambda() pause(20)
  {ending}
 end lambda])
 if answer = Option.Some(42) and not Reference.get(changed) then return Result.Ok(()) else return Result.Error("cancelled owner continued") end if
end function
"#
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(
                &program,
                VmConfig {
                    call_budget: 1,
                    ..VmConfig::default()
                },
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let script = ScheduleHandle::new([], false);
            let (mut io, submissions) = runtime(&script, false);
            let released = Arc::new(Mutex::new(0));
            let record = Arc::clone(&released);
            let observed = Rc::new(RefCell::new(0_u8));
            let watch = Rc::clone(&observed);
            let work_script = script.clone();
            let jobs = Rc::clone(&submissions);
            let mut sent = false;
            let mut sent_release = false;
            vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
                for entry in state.resources.entries.values_mut() {
                    if entry.kind == ResourceKind::TaskGroup && entry.state == ResourceState::Open {
                        entry.kind = ResourceKind::FileWriter;
                        entry.content = ResourceContent::Os(Some(Box::new(FakeResource {
                            fail,
                            released: Arc::clone(&record),
                        })));
                    }
                }
                if state
                    .scheduler
                    .waiting
                    .values()
                    .any(|w| w.reason == WaitReason::Lend(ResourceId(4)))
                {
                    *watch.borrow_mut() |= 1;
                }
                if state.resources.state(ResourceId(4))
                    == Some(ResourceState::Lent(ExtOpId(0), true))
                    && state.scheduler.ready.is_empty()
                    && !sent
                {
                    let task = ctx
                        .host::<TaskObj>(
                            state
                                .tasks
                                .get(
                                    ctx,
                                    TaskId {
                                        index: 1,
                                        generation: 0,
                                    },
                                )
                                .unwrap(),
                        )
                        .unwrap();
                    assert!(
                        matches!(&task.state,TaskState::Unwinding(work) if work.waiting==Some(WaitReason::Release(ResourceId(4))))
                    );
                    assert!(matches!(task.result, TaskResult::Pending));
                    *watch.borrow_mut() |= 2;
                    work_script.allow_worker(ExtOpId(0));
                    sent = true;
                }
                if let Some(submission) = jobs.borrow().iter().find(|s| s.release).copied()
                    && state.scheduler.ready.is_empty()
                    && !sent_release
                {
                    assert!(matches!(
                        state.resources.state(ResourceId(4)),
                        Some(ResourceState::Releasing(_))
                    ));
                    let task = ctx
                        .host::<TaskObj>(
                            state
                                .tasks
                                .get(
                                    ctx,
                                    TaskId {
                                        index: 1,
                                        generation: 0,
                                    },
                                )
                                .unwrap(),
                        )
                        .unwrap();
                    assert!(matches!(task.result, TaskResult::Pending));
                    assert!(
                        matches!(&task.state,TaskState::Unwinding(work) if work.waiting==Some(WaitReason::Release(ResourceId(4))))
                    );
                    assert_eq!(*record.lock().unwrap(), 0);
                    *watch.borrow_mut() |= 4;
                    work_script.allow_worker(submission.op);
                    sent_release = true;
                }
                Ok(())
            }));
            let step = finish(&mut vm, &mut io, mode);
            if stopping || fail {
                let VmStep::Stopped(StopEnd {
                    reason: StopReason::Error(ref info),
                    ..
                }) = step
                else {
                    panic!("expected stopping: {step:?}")
                };
                if stopping {
                    assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
                } else {
                    assert!(
                        matches!(info.stop,Stop::Runtime(RuntimeError::ReleaseFailed(ref failures)) if failures.len()==1 && failures[0].reason=="fake release failed")
                    );
                }
            } else {
                assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
            }
            assert_eq!(
                *observed.borrow(),
                7,
                "{mode:?}, stopping={stopping}, {step:?}"
            );
            assert_eq!(*released.lock().unwrap(), 1);
            assert_eq!(submissions.borrow().len(), 2);
            assert!(submissions.borrow()[1].release);
            assert_eq!(
                vm.state.resources.state(ResourceId(4)),
                Some(ResourceState::Released)
            );
            assert!(vm.heap.take_fault().is_none());
            consumed(&script);
        }
    }
}
#[test]
fn synchronous_output_parks_and_wakes_without_overwriting_the_wait() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Unit uses Console.Write
 bind values <- Task.all([lambda() return Console.writeLine("first") end lambda,lambda() return Console.writeLine("second") end lambda])
 return ()
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let script = ScheduleHandle::new(
            [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
            false,
        );
        let (mut io, _) = runtime(&script, false);
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(
            io.take_output(),
            [
                (Stream::Stdout, b"first\n".to_vec()),
                (Stream::Stdout, b"second\n".to_vec())
            ]
        );
        assert!(vm.state.scheduler.waiting.is_empty());
        consumed(&script);
    }
}

#[test]
fn timer_arguments_survive_collection_by_another_task_before_the_deadline() {
    let program = compile(&format!(
        r#"{IMPORTS}
function busy(n:Integer) -> String
 if n = 0 then return "busy" else return busy(n - 1) end if
end function
function main() -> Result[Unit,String] uses Console.Write
 bind texts <- Task.all([
 lambda()
  bind text <- "heap" + " timer"
  bind result <- Console.writeLine(text)
  if result = () then return text else return "wrong unit" end if
 end lambda,
 lambda() return busy(20) end lambda])
 if texts = ["heap timer","busy"] then return Result.Ok(()) else return Result.Error("timer roots") end if
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
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
        let mut vm = Vm::new(
            &program,
            VmConfig {
                call_budget: 1,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let script = ScheduleHandle::new(
            [
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2),
                ScheduleStep::Advance(9),
                ScheduleStep::PickTask(2),
                ScheduleStep::Advance(1),
            ],
            false,
        );
        let (mut io, _) = runtime(&script, false);
        io.rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin("Benitoite.IO.Console.writeLine").unwrap(),
            &fake_sleep::DECL,
        );
        let observed = Rc::new(RefCell::new(false));
        let watch = Rc::clone(&observed);
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            if state
                .scheduler
                .waiting
                .values()
                .any(|w| matches!(w.reason, WaitReason::Timer(_)))
            {
                let task = TaskId {
                    index: 1,
                    generation: 0,
                };
                let value = ctx
                    .host::<TaskObj>(state.tasks.get(ctx, task).unwrap())
                    .unwrap();
                let frame = value.stack.segments.last().unwrap().calls.last().unwrap();
                assert!(io_sites.contains(&InstrRef {
                    proto: frame.proto,
                    pc: frame.pc
                }));
                assert!(
                    value
                        .stack
                        .segments
                        .iter()
                        .flat_map(|s| &s.regs)
                        .any(|slot| ctx.str(ctx.load(slot)) == Some("heap timer"))
                );
                *watch.borrow_mut() = true;
            }
            Ok(())
        }));
        assert_eq!(
            finish(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert!(*observed.borrow());
        assert!(vm.heap_stats().collections > 0);
        assert!(vm.heap.take_fault().is_none());
        consumed(&script);
    }
}

#[test]
fn waiting_work_prevents_deadlock_until_its_completion_is_taken() {
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Unit uses State,File.Read
 bind a <- Reference.new(Option.None)
 bind b <- Reference.new(Option.None)
 with group = TaskGroup.open() do
  bind _ <- TaskGroup.spawn(group,lambda()
   bind _ <- File.readText("work")
   return ()
  end lambda)
  bind ta <- TaskGroup.spawn(group,lambda()
   match Reference.get(b) with case Option.Some(t) -> Task.await(t)
   case Option.None -> () end match
   return ()
  end lambda)
  bind tb <- TaskGroup.spawn(group,lambda()
   match Reference.get(a) with case Option.Some(t) -> Task.await(t)
   case Option.None -> () end match
   return ()
  end lambda)
  Reference.set(a,Option.Some(ta))
  Reference.set(b,Option.Some(tb))
 end with
 return ()
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let script = ScheduleHandle::new(
            [
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2),
                ScheduleStep::PickTask(3),
            ],
            false,
        );
        let (mut io, _) = runtime(&script, false);
        let worker = script.clone();
        let observed = Rc::new(RefCell::new(false));
        let watch = Rc::clone(&observed);
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
            if state.scheduler.ready.is_empty()
                && let Some(op) = state.scheduler.waiting.values().find_map(|w| {
                    if let WaitReason::Worker(op) = w.reason {
                        Some(op)
                    } else {
                        None
                    }
                })
            {
                assert_eq!(
                    state
                        .scheduler
                        .waiting
                        .values()
                        .filter(|w| matches!(w.reason, WaitReason::TaskEnd(TaskEndWait::Await(_))))
                        .count(),
                    2
                );
                assert!(!state.scheduler.is_deadlocked());
                assert!(state.stopping.is_none());
                *watch.borrow_mut() = true;
                worker.allow_worker(op);
            }
            Ok(())
        }));
        let VmStep::Stopped(StopEnd {
            reason: StopReason::Error(info),
            ..
        }) = finish(&mut vm, &mut io, mode)
        else {
            panic!("deadlock missing")
        };
        assert_eq!(info.stop, Stop::Runtime(RuntimeError::TaskDeadlock));
        assert!(*observed.borrow());
        assert!(io.rt.ops.records.is_empty());
        consumed(&script);
        assert!(
            script
                .record()
                .events
                .iter()
                .any(|e| matches!(e, ScheduleEvent::WorkerRan(_)))
        );
    }
}

// 関門: 同じ待ちへの二つの準備と配送後の古い準備を完了の記録の入口で除く（L30）。
// check_completion 自体は記録のない操作を Internal にするため、その前の選別が要る。
#[test]
fn readiness_deduplicates_live_operations_and_discards_stale_tokens() {
    let program =
        compile("function main() -> Result[Unit,String]\n return Result.Ok(())\nend function");
    let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
    let mut io = services();
    let task = TaskId {
        index: 0,
        generation: 0,
    };

    for cancelled in [false, true] {
        let op = ExtOpId(if cancelled { 8 } else { 7 });
        io.rt.ops.insert(
            op,
            OpRecord {
                kind: OpKind::Readiness,
                deliver_to: Some(task),
                lent: None,
                site: None,
            },
        );
        io.rt.readiness.tokens.insert(2, [op].into());
        io.rt.readiness.tokens.insert(3, [op].into());
        assert_eq!(
            ready_for_tokens(&vm.state, &io.rt, [2, 3, 2, 99]),
            [op].into()
        );
        if cancelled {
            let timer = vm.state.scheduler.new_timer_id();
            vm.state.scheduler.add_timer(5, timer, task);
            io.rt.readiness.retries.insert(timer, op);
            io.rt.readiness.op_timers.insert(op, timer);
            vm.state.scheduling.cancelled_io.push(task);
            reflect_cancellation(&mut vm.state, &mut io.rt);
            assert!(io.rt.readiness.retries.is_empty());
            assert!(vm.state.scheduler.timers.is_empty());
            assert!(io.rt.ops.records.contains_key(&op));
            assert_eq!(io.rt.ops.records[&op].deliver_to, None);
        }
        let completion = Completion {
            op,
            outcome: Outcome::Ready,
            returned: LentOwned::Nothing,
        };
        ops::check_completion(&io.rt.ops, &vm.state.resources, &completion).unwrap();
        let result = ops::accept_completion(
            &mut io.rt.ops,
            &mut vm.state.resources,
            &mut io.rt.stdin,
            completion,
        );
        if cancelled {
            assert!(matches!(result.as_slice(), [Accepted::Dropped]));
        } else {
            assert!(matches!(
                result.as_slice(),
                [Accepted::Deliver {
                    outcome: Outcome::Ready,
                    ..
                }]
            ));
        }
        assert!(ready_for_tokens(&vm.state, &io.rt, [2, 3]).is_empty());
    }
}
