//! 中断の待ちと全タスクの解放（実装プラン R28、設計書 02-08「止める手順」）。
use super::*;
use crate::builtins::iface::{IoReply, OsResource, builtin};
use crate::runtime::io::ops::{Completion, WorkerJob, execute_job};
use crate::runtime::io::services::InterruptSource;
use crate::runtime::sched::parts::{IdleWake, WorkerExec};
use crate::runtime::{ResourceKind, RuntimeError};
use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
#[derive(Debug)]
struct Flag(Arc<AtomicBool>);
impl InterruptSource for Flag {
    fn requested(&self) -> bool {
        self.0.load(Ordering::Relaxed)
    }
    fn flag(&self) -> Option<&AtomicBool> {
        Some(&self.0)
    }
}
#[derive(Debug)]
struct InterruptWorkers {
    flag: Arc<AtomicBool>,
    interrupted: bool,
    jobs: VecDeque<WorkerJob>,
    done: VecDeque<Completion>,
}
impl InterruptWorkers {
    fn new(flag: Arc<AtomicBool>) -> Self {
        Self {
            flag,
            interrupted: false,
            jobs: VecDeque::new(),
            done: VecDeque::new(),
        }
    }
}
impl WorkerExec for InterruptWorkers {
    fn submit(&mut self, job: WorkerJob) {
        self.jobs.push_back(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.done.pop_front()
    }
    fn idle(&mut self, _: Option<u64>) -> IdleWake {
        if !self.interrupted {
            self.interrupted = true;
            self.flag.store(true, Ordering::Relaxed);
            return IdleWake::Interrupted;
        }
        if let Some(job) = self.jobs.pop_front() {
            self.done.push_back(execute_job(job));
            IdleWake::Progress
        } else {
            IdleWake::ScriptExhausted
        }
    }
}

builtin! {
    name = "Benitoite.IO.Console.writeLine",
    io fn timer(ctx, text: &'c str) -> IoReply<'e> {
        let _ = (ctx, text);
        Ok(IoReply::Wait(crate::builtins::iface::IoWait::Sleep { millis: 100 }))
    }
}

fn finish(vm: &mut Vm<'_>, io: &mut TestIo, mode: ExecMode) -> VmStep {
    loop {
        match vm.run(io.runtime(mode)) {
            VmStep::Requests(ids) => {
                for id in ids {
                    vm.serve_request(&mut io.rt, id);
                }
            }
            step @ (VmStep::Finished(_) | VmStep::Stopped(_)) => return step,
        }
    }
}

// 関門: 呼び出しの確認だけでは、タイマーを待つ VM を起こせない。
// 印を idle の中で立て、実行の結果と待ちの解消を観察する。
#[test]
fn idle_interrupt_stops_timer_waits_in_both_execution_modes() {
    let program = compile(
        "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n Console.writeLine(\"wait\")\n return ()\nend function\n",
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let flag = Arc::new(AtomicBool::new(false));
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut io = services();
        io.rt.parts = ScheduleHandle::new([], false).parts();
        io.rt.parts.workers = Box::new(InterruptWorkers::new(Arc::clone(&flag)));
        io.rt.interrupt = Box::new(Flag(flag));
        io.rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin("Benitoite.IO.Console.writeLine").unwrap(),
            &timer::DECL,
        );
        let step = finish(&mut vm, &mut io, mode);
        assert!(
            matches!(
                step,
                VmStep::Stopped(StopEnd {
                    reason: StopReason::Interrupted,
                    ..
                })
            ),
            "{step:?}"
        );
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert!(vm.state.scheduler.waiting.is_empty());
        assert!(vm.state.scheduler.timers.is_empty());
        assert!(io.rt.sleeps.is_empty());
    }
}

builtin! {
    name = "Benitoite.IO.Console.readLine",
    io fn pending_stdin(ctx) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(crate::builtins::iface::IoWait::Worker(
            crate::builtins::iface::WorkerWait::new(
                crate::builtins::iface::Lend::Stdin,
                |_| panic!("pending stdin must not run"),
                |_, _: (), _| panic!("pending stdin must not complete"),
            )
        )))
    }
}

// 関門: attach より前の要求ではイベントループへの通知がない。既存の idle の
// 中断テストは通知を返すため、この取りこぼしを捕まえない。VM の結果で確かめる
// （設計書 02-08「タスクの切り替え」の「この待ちでも中断の印を調べる」）。
#[test]
fn interrupt_requested_before_attach_stops_stdin_wait_without_a_notification() {
    let program = compile(
        "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Read\n bind _ <- Console.readLine()\n return ()\nend function\n",
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let mut io = services();
        io.rt.interrupt = Box::new(Flag(Arc::new(AtomicBool::new(true))));
        assert!(io.rt.interrupt.requested());
        let guard = io.rt.interrupt.attach(&io.rt.wakeup).unwrap();
        assert!(guard.is_none());
        // 仕事の完了も Interrupted の通知も与えない。印だけで待ちへ入る前に止める。
        io.rt.parts = ScheduleHandle::new([], false).parts();
        io.rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin("Benitoite.IO.Console.readLine").unwrap(),
            &pending_stdin::DECL,
        );
        vm.start_main().unwrap();
        let step = finish(&mut vm, &mut io, mode);
        assert!(
            matches!(
                step,
                VmStep::Stopped(StopEnd {
                    reason: StopReason::Interrupted,
                    ..
                })
            ),
            "{step:?}"
        );
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert!(vm.state.scheduler.waiting.is_empty());
    }
}

#[derive(Debug)]
struct Resource {
    id: u64,
    releases: Arc<Mutex<Vec<u64>>>,
}
impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        self.releases.lock().unwrap().push(self.id);
        Err(format!("release {} failed", self.id))
    }
}

// 関門: 中断の停止でも、各タスクの内側からの解放、ブロックする解放の待ち、
// 失敗の全件報告と元の終了状態を保つ。既存のエラー停止だけのテストでは中断を通らない。
#[test]
fn stopping_releases_every_task_inside_out_and_preserves_the_first_reason() {
    let program = compile(
        r#"
function loop(n: Integer) -> Unit
 if n = 0 then return () end if
 return loop(n - 1)
end function
function work() -> Unit uses State
 with outer = TaskGroup.open() do
  with inner = TaskGroup.open() do
   loop(100)
   return ()
  end with
 end with
end function
function main() -> Unit uses State
 bind _ <- Task.all([work, work])
 return ()
end function
"#,
    );
    for cause in [0, 1, 2, 3] {
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let flag = Arc::new(AtomicBool::new(false));
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
            let mut io = services();
            io.rt.parts = ScheduleHandle::new([], false).parts();
            io.rt.parts.workers = Box::new(InterruptWorkers::new(Arc::clone(&flag)));
            io.rt.interrupt = Box::new(Flag(Arc::clone(&flag)));
            let releases = Arc::new(Mutex::new(Vec::new()));
            let recorded = Arc::clone(&releases);
            let mut started = false;
            vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
                for (&id, entry) in &mut state.resources.entries {
                    if entry.kind == ResourceKind::TaskGroup {
                        entry.kind = if (id.0 >> 3) % 2 == 0 {
                            ResourceKind::FileReader
                        } else {
                            ResourceKind::FileWriter
                        };
                        entry.content = ResourceContent::Os(Some(Box::new(Resource {
                            id: id.0 >> 3,
                            releases: Arc::clone(&recorded),
                        })));
                    }
                }
                if !started && state.resources.entries.len() == 4 {
                    started = true;
                    match cause {
                        0 => flag.store(true, Ordering::Relaxed),
                        1 => state.stopping = Some(StopReason::Exit(3)),
                        2 => state.fail(Stop::Runtime(RuntimeError::DivisionByZero), None),
                        3 => state.fail(
                            Stop::Resource(crate::runtime::ResourceError::CallStackTooDeep {
                                frames: 10,
                            }),
                            None,
                        ),
                        _ => unreachable!(),
                    }
                }
                Ok(())
            }));
            let step = finish(&mut vm, &mut io, mode);
            let VmStep::Stopped(StopEnd {
                release_failures, ..
            }) = &step
            else {
                panic!("not stopped: {step:?}")
            };
            assert_eq!(release_failures.len(), 4);
            match (cause, &step) {
                (
                    0,
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Interrupted,
                        ..
                    }),
                )
                | (
                    1,
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Exit(3),
                        ..
                    }),
                ) => {}
                (
                    2,
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Error(info),
                        ..
                    }),
                ) => assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero)),
                (
                    3,
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Error(info),
                        ..
                    }),
                ) => assert!(matches!(
                    info.stop,
                    Stop::Resource(crate::runtime::ResourceError::CallStackTooDeep { frames: 10 })
                )),
                _ => panic!("wrong stop reason: {step:?}"),
            }
            let released = releases.lock().unwrap();
            assert_eq!(released.len(), 4);
            for outer in [0, 2] {
                assert!(
                    released.iter().position(|&id| id == outer + 1).unwrap()
                        < released.iter().position(|&id| id == outer).unwrap()
                );
            }
            assert!(
                vm.state
                    .resources
                    .entries
                    .values()
                    .all(|entry| entry.state == ResourceState::Released)
            );
            assert_eq!(vm.state.tasks.live_count(), 0);
            assert!(vm.heap.take_fault().is_none());
        }
    }
}

#[derive(Debug)]
struct PendingResource {
    started: std::sync::mpsc::Sender<()>,
    gate: std::sync::mpsc::Receiver<()>,
    dropped: std::sync::mpsc::Sender<()>,
}
impl OsResource for PendingResource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        panic!("a resource outside with must not be released")
    }
}
impl Drop for PendingResource {
    fn drop(&mut self) {
        let _sent = self.dropped.send(());
    }
}

builtin! {
    name = "Benitoite.IO.File.readText",
    io fn pending_read(ctx, path: &'c str) -> IoReply<'e> {
        let _ = (ctx, path);
        Ok(IoReply::Wait(crate::builtins::iface::IoWait::Worker(
            crate::builtins::iface::WorkerWait::new(
                crate::builtins::iface::Lend::Resource(crate::runtime::heap::ResourceId(0)),
                |lent| {
                    let crate::builtins::iface::Lent::Resource(handle) = lent else { panic!("resource missing") };
                    let resource = handle.as_any_mut().downcast_mut::<PendingResource>().unwrap();
                    resource.started.send(()).unwrap();
                    resource.gate.recv().unwrap();
                },
                |_, _: (), _| Ok(Value::Unit),
            )
        )))
    }
}

#[derive(Debug)]
struct InterruptRunningWorker {
    inner: Box<dyn WorkerExec>,
    started: std::sync::mpsc::Receiver<()>,
    flag: Arc<AtomicBool>,
}
impl WorkerExec for InterruptRunningWorker {
    fn submit(&mut self, job: WorkerJob) {
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, _: Option<u64>) -> IdleWake {
        self.started
            .recv_timeout(std::time::Duration::from_secs(10))
            .unwrap();
        self.flag.store(true, Ordering::Relaxed);
        IdleWake::Interrupted
    }
}

// 関門: 生きた作業用のスレッドを待たずに中断を終え、遅い完了で返す資源を
// 配送先なしで破棄する。表の失効のテストだけではスレッドと実行の寿命を通らない。
#[test]
fn interrupt_does_not_wait_for_running_work_and_late_resource_is_dropped() {
    let program = compile(
        "import Benitoite.Unofficial.IO.File\nfunction main() -> Unit uses File.Read\n bind _ <- File.readText(\"pending\")\n return ()\nend function\n",
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let (started, start) = std::sync::mpsc::channel();
        let (gate, wait) = std::sync::mpsc::channel();
        let (dropped, destruction) = std::sync::mpsc::channel();
        let flag = Arc::new(AtomicBool::new(false));
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let _resource = vm.state.resources.insert(
            ResourceKind::FileReader,
            ResourceContent::Os(Some(Box::new(PendingResource {
                started,
                gate: wait,
                dropped,
            }))),
            None,
        );
        let mut io = services();
        let workers = std::mem::replace(
            &mut io.rt.parts.workers,
            ScheduleHandle::new([], false).parts().workers,
        );
        io.rt.parts.workers = Box::new(InterruptRunningWorker {
            inner: workers,
            started: start,
            flag: Arc::clone(&flag),
        });
        io.rt.interrupt = Box::new(Flag(flag));
        io.rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin("Benitoite.IO.File.readText").unwrap(),
            &pending_read::DECL,
        );
        let step = finish(&mut vm, &mut io, mode);
        assert!(
            matches!(
                step,
                VmStep::Stopped(StopEnd {
                    reason: StopReason::Interrupted,
                    ..
                })
            ),
            "{step:?}"
        );
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert!(destruction.try_recv().is_err());
        drop(io);
        drop(vm);
        gate.send(()).unwrap();
        destruction
            .recv_timeout(std::time::Duration::from_secs(10))
            .unwrap();
    }
}
