//! ファイルの仕事、完了、資源の登録と解放をつなぐ（実装プラン R29）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::super::runtime_test_support::*;
use super::*;
use crate::builtins::iface::CallCtx;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::io::resources::{LendResult, ResourceState, ResourceTable};
use crate::runtime::io::services::IoView;
use crate::runtime::sched::testing::ScheduleHandle;
use crate::runtime::sched::{ExtOpId, Scheduler};
use crate::vm::state::Stage1StateServices;
use crate::vm::{ExecMode, TaskId};
// 関門: 作業用の仕事が相対パスで書き、完了が成功・OS の失敗を Result にする契約。
// readText の既存のテストは書き込みや追記を呼ばない。本体を直接呼ぶ指示は R29 に従う。
#[test]
fn write_and_append_round_trip_and_classify_os_errors() {
    let dir = TempDir::new();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut services = IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (append, text, expected) in [
            (false, "古い", "古い"),
            (false, "a\n", "a\n"),
            (true, "b\r\n", "a\nb\r\n"),
        ] {
            let call = CallCtx::new(ctx, Some(&mut services), None, None);
            let mut call = call;
            let reply = if append {
                append_text(call.io_ctx().unwrap(), "text", text)
            } else {
                write_text(call.io_ctx().unwrap(), "text", text)
            };
            let work = worker(reply.unwrap());
            assert_eq!(work.lend(), Lend::Nothing);
            let done = work.run(Lent::Nothing);
            let result = done
                .complete(
                    &mut CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    &[],
                )
                .unwrap();
            assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
            let work = worker(
                read_text(
                    CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    "text",
                )
                .unwrap(),
            );
            let done = work.run(Lent::Nothing);
            let result = done
                .complete(
                    &mut CallCtx::new(ctx, Some(&mut services), None, None)
                        .io_ctx()
                        .unwrap(),
                    &[],
                )
                .unwrap();
            assert_eq!(
                ctx.str(payload(ctx, result, tags::RESULT_OK)),
                Some(expected)
            );
        }
        // append も存在しないファイルを作る。
        let work = worker(
            append_text(
                CallCtx::new(ctx, Some(&mut services), None, None)
                    .io_ctx()
                    .unwrap(),
                "new",
                "new",
            )
            .unwrap(),
        );
        let result = work
            .run(Lent::Nothing)
            .complete(
                &mut CallCtx::new(ctx, Some(&mut services), None, None)
                    .io_ctx()
                    .unwrap(),
                &[],
            )
            .unwrap();
        assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
        assert_eq!(std::fs::read_to_string(dir.0.join("new")).unwrap(), "new");
        for append in [false, true] {
            for (path, kind) in [
                ("missing/text", tags::IO_ERROR_KIND_NOT_FOUND),
                (".", tags::IO_ERROR_KIND_IS_DIRECTORY),
                ("text/child", tags::IO_ERROR_KIND_NOT_DIRECTORY),
                ("bad\0path", tags::IO_ERROR_KIND_INVALID_INPUT),
            ] {
                let mut call = CallCtx::new(ctx, Some(&mut services), None, None);
                let reply = if append {
                    append_text(call.io_ctx().unwrap(), path, "x")
                } else {
                    write_text(call.io_ctx().unwrap(), path, "x")
                };
                let result = worker(reply.unwrap())
                    .run(Lent::Nothing)
                    .complete(
                        &mut CallCtx::new(ctx, Some(&mut services), None, None)
                            .io_ctx()
                            .unwrap(),
                        &[],
                    )
                    .unwrap();
                assert_eq!(error_kind(ctx, result), kind, "{path:?}, append={append}");
            }
        }
    });
}
// 関門: BufReader の位置、UTF-8、開いた位置の登録、借りた資源の close の待ちと二度の close。
// 個別の ResourceTable のテストでは openReader と readLine の本体を呼ばない。
#[test]
fn reader_preserves_lines_registers_site_and_close_is_idempotent() {
    let dir = TempDir::new();
    let script = ScheduleHandle::new([], false);
    let (mut rt, _) = runtime(&dir.0, ExecMode::Direct, &script);
    let mut resources = ResourceTable::default();
    let mut scheduler = Scheduler::default();
    let site = Some(crate::vm::InstrRef {
        proto: crate::bytecode::program::ProtoIdx(0),
        pc: 7,
    });
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for &(bytes, expected) in LINE_CASES {
            std::fs::write(dir.0.join("lines"), bytes).unwrap();
            let reader = {
                let mut io = IoView {rt: &mut rt, resources: &mut resources};
                let work = worker(open_reader(CallCtx::new(ctx, Some(&mut io), None, site).io_ctx().unwrap(), "lines").unwrap());
                assert_eq!(work.lend(), Lend::Nothing);
                let result = work.run(Lent::Nothing).complete(&mut CallCtx::new(ctx, Some(&mut io), None, site).io_ctx().unwrap(), &[]).unwrap();
                payload(ctx, result, tags::RESULT_OK).as_resource().unwrap()
            };
            assert_eq!(resources.entries[&reader].opened_at, site);
            assert_eq!(resources.entries[&reader].kind, ResourceKind::FileReader);
            for &expected in expected {
                let work = {
                    let mut io = IoView {rt: &mut rt, resources: &mut resources};
                    worker(read_line(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), reader).unwrap())
                };
                assert_eq!(work.lend(), Lend::Resource(reader));
                let LendResult::Lent(mut handle) = resources.lend(reader, ExtOpId(100), TaskId {index: 0, generation: 0}) else {panic!("not lent")};
                let done = work.run(Lent::Resource(handle.as_mut()));
                assert!(!resources.give_back(reader, handle));
                let mut io = IoView {rt: &mut rt, resources: &mut resources};
                let result = done.complete(&mut CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), &[]).unwrap();
                assert_eq!(line(ctx, result).as_deref(), expected);
            }
            // 読み取り中の close は待ち、返った資源の解放後に再実行する。
            let LendResult::Lent(handle) = resources.lend(reader, ExtOpId(101), TaskId {index: 0, generation: 0}) else {panic!("not lent")};
            {
                let mut state = Stage1StateServices {resources: &mut resources, scheduler: &mut scheduler};
                assert!(matches!(close_reader(CallCtx::new(ctx, None, Some(&mut state), None).state_ctx().unwrap(), reader).unwrap(), StateReply::Wait(crate::builtins::iface::StateWait::Resource(r)) if r == reader));
            }
            assert!(resources.give_back(reader, handle));
            for _ in 0..2 {
                let mut state = Stage1StateServices {resources: &mut resources, scheduler: &mut scheduler};
                let StateReply::Done(result) = close_reader(CallCtx::new(ctx, None, Some(&mut state), None).state_ctx().unwrap(), reader).unwrap() else {panic!("close waited after return")};
                assert!(matches!(payload(ctx, result, tags::RESULT_OK), Value::Unit));
            }
            assert_eq!(resources.state(reader), Some(ResourceState::Released));
        }
        std::fs::write(dir.0.join("invalid"), b"\xff\n").unwrap();
        let mut io = IoView {rt: &mut rt, resources: &mut resources};
        let work = worker(open_reader(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), "invalid").unwrap());
        let result = work.run(Lent::Nothing).complete(&mut CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), &[]).unwrap();
        let reader = payload(ctx, result, tags::RESULT_OK).as_resource().unwrap();
        let work = worker(read_line(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), reader).unwrap());
        let LendResult::Lent(mut handle) = resources.lend(reader, ExtOpId(102), TaskId {index: 0, generation: 0}) else {panic!("not lent")};
        let done = work.run(Lent::Resource(handle.as_mut()));
        resources.give_back(reader, handle);
        let mut io = IoView {rt: &mut rt, resources: &mut resources};
        let result = done.complete(&mut CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), &[]).unwrap();
        assert_eq!(error_kind(ctx, result), tags::IO_ERROR_KIND_INVALID_UTF8);
        let work = worker(open_reader(CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), "missing").unwrap());
        let result = work.run(Lent::Nothing).complete(&mut CallCtx::new(ctx, Some(&mut io), None, None).io_ctx().unwrap(), &[]).unwrap();
        assert_eq!(error_kind(ctx, result), tags::IO_ERROR_KIND_NOT_FOUND);
        let mut state = Stage1StateServices {resources: &mut resources, scheduler: &mut scheduler};
        assert!(matches!(close_reader(CallCtx::new(ctx, None, Some(&mut state), None).state_ctx().unwrap(), reader).unwrap(), StateReply::Done(_)));
    });
}

use crate::vm::{MainOutcome, StopEnd, StopReason, Vm, VmConfig, VmStep};
use std::sync::{Arc, Mutex};

#[derive(Debug)]
struct CountRelease {
    inner: Box<dyn OsResource>,
    count: Arc<Mutex<usize>>,
}
impl OsResource for CountRelease {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self.inner.as_any_mut()
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        *self.count.lock().unwrap() += 1;
        self.inner.release()
    }
}
const IMPORTS: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\nimport Benitoite.Unofficial.IO.Clock\n";
// OS の資源だけを包んで release を数える。VM の状態や関数の公開範囲を変えない。
#[derive(Debug)]
struct CountingWorkers {
    inner: Box<dyn crate::runtime::sched::parts::WorkerExec>,
    script: ScheduleHandle,
    count: Arc<Mutex<usize>>,
    hold_reads: bool,
    pending: Vec<ExtOpId>,
    delayed: Arc<Mutex<bool>>,
}
impl crate::runtime::sched::parts::WorkerExec for CountingWorkers {
    fn wakeup(&self) -> Option<crate::runtime::io::event::Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: crate::runtime::io::ops::WorkerJob) {
        if self.hold_reads && matches!(job.lent, crate::runtime::io::ops::LentOwned::Resource(_, _))
        {
            self.pending.push(job.op);
        } else {
            self.script.allow_worker(job.op);
        }
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<crate::runtime::io::ops::Completion> {
        use crate::runtime::io::ops::LentOwned;
        let mut done = self.inner.try_recv()?;
        if matches!(done.returned, LentOwned::Resource(_, _))
            && let LentOwned::Resource(id, inner) =
                std::mem::replace(&mut done.returned, LentOwned::Nothing)
        {
            done.returned = LentOwned::Resource(
                id,
                Box::new(CountRelease {
                    inner,
                    count: Arc::clone(&self.count),
                }),
            );
        }
        Some(done)
    }
    fn idle(&mut self, deadline: Option<u64>) -> crate::runtime::sched::parts::IdleWake {
        if let Some(op) = self.pending.pop() {
            assert_eq!(
                *self.count.lock().unwrap(),
                0,
                "released before the read ran"
            );
            *self.delayed.lock().unwrap() = true;
            self.script.allow_worker(op);
        }
        self.inner.idle(deadline)
    }
}
fn count_releases(
    rt: &mut crate::runtime::io::services::IoRuntime,
    script: &ScheduleHandle,
    hold_reads: bool,
) -> (Arc<Mutex<usize>>, Arc<Mutex<bool>>) {
    let count = Arc::new(Mutex::new(0));
    let delayed = Arc::new(Mutex::new(false));
    let inner = std::mem::replace(&mut rt.parts.workers, script.parts().workers);
    rt.parts.workers = Box::new(CountingWorkers {
        inner,
        script: script.clone(),
        count: Arc::clone(&count),
        hold_reads,
        pending: vec![],
        delayed: Arc::clone(&delayed),
    });
    (count, delayed)
}
// 関門: 実物の openReader・readLine から with の正常終了・エラー・exit の解放へつなぐ。
// 外部の資源の返却時に解放だけを計数する。既存の VM の解放テストは本体を呼ばない。
#[test]
fn with_releases_the_opened_reader_once_on_return_error_and_exit() {
    let dir = TempDir::new();
    std::fs::write(dir.0.join("text"), "line\n").unwrap();
    for (body, outcome) in [
        ("return Result.Ok(())", 0),
        (
            "bind zero <- 0\n bind _ <- 1 div zero\n return Result.Ok(())",
            1,
        ),
        ("return Process.exit(3)", 3),
    ] {
        let program = compile(&format!(
            "{IMPORTS}\nfunction main() -> Result[Unit,String] uses File.Read,State,Console.Write,Process.Exit\n with reader = try File.openReader(\"text\") |> Result.mapError(_,IOError.message) do\n bind _ <- try File.readLine(reader) |> Result.mapError(_,IOError.message)\n Console.write(\"before\")\n {body}\n end with\nend function\n"
        ));
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let script = ScheduleHandle::new([], false);
            let (mut rt, output) = runtime(&dir.0, mode, &script);
            let (count, _) = count_releases(&mut rt, &script, false);
            let mut vm = Vm::new(
                &program,
                VmConfig::default(),
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let end = finish(&mut vm, &mut rt);
            match outcome {
                0 => assert_eq!(end, VmStep::Finished(MainOutcome::Ok)),
                1 => assert!(
                    matches!(end, VmStep::Stopped(StopEnd {reason: StopReason::Error(ref info), ..}) if info.stop == Stop::Runtime(crate::runtime::RuntimeError::DivisionByZero))
                ),
                3 => assert!(matches!(
                    end,
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Exit(3),
                        ..
                    })
                )),
                _ => unreachable!(),
            }
            assert_eq!(*count.lock().unwrap(), 1, "{mode:?}: {end:?}");
            assert_eq!(*output.lock().unwrap(), b"before");
            consumed(&script);
        }
    }
}
// 関門: 解放済みの使用の判定は R26 の貸し出し境界だけにある。本体の単体テストでは届かない。
#[test]
fn reading_a_closed_reader_stops_with_released_resource_used() {
    let dir = TempDir::new();
    std::fs::write(dir.0.join("text"), "line\n").unwrap();
    let program = compile(&format!(
        "{IMPORTS}\nfunction main() -> Result[Unit,String] uses File.Read,State\n with reader = try File.openReader(\"text\") |> Result.mapError(_,IOError.message) do\n bind _ <- try File.closeReader(reader) |> Result.mapError(_,IOError.message)\n bind _ <- try File.closeReader(reader) |> Result.mapError(_,IOError.message)\n bind _ <- try File.readLine(reader) |> Result.mapError(_,IOError.message)\n return Result.Ok(())\n end with\nend function\n"
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let (mut rt, _) = runtime(&dir.0, mode, &script);
        let jobs = permit_workers(&mut rt, &script);
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert!(
            matches!(finish(&mut vm, &mut rt), VmStep::Stopped(StopEnd {reason: StopReason::Error(ref info), ..}) if info.stop == Stop::Runtime(crate::runtime::RuntimeError::ReleasedResourceUsed {kind: ResourceKind::FileReader}))
        );
        assert!(jobs.borrow().is_empty());
        consumed(&script);
    }
}
// 関門: 本物の readLine の仕事を保留し、race の取り消しを先に行ってから実行する。
// 進められるタスクがなくなるまで読み取りを止め、資源の解放と取り消し後の出力を観察する。
#[test]
fn cancelled_read_returns_the_reader_before_releasing_it() {
    let dir = TempDir::new();
    std::fs::write(dir.0.join("text"), "line\n").unwrap();
    let program = compile(&format!(
        r#"{IMPORTS}
function main() -> Result[Unit,String] uses File.Read,State,Clock.Time,Console.Write
 bind continued <- Reference.new(false)
 bind winner <- Task.race([
  lambda()
   with reader = try File.openReader("text") do
    bind _ <- try File.readLine(reader)
    Reference.set(continued,true)
    Console.write("continued")
    return Result.Ok(1)
   end with
  end lambda,
  lambda()
   Console.write("winner")
   return Result.Ok(2)
  end lambda])
 bind value <- match winner with case Option.Some(Result.Ok(n)) -> n
 case _ -> 0 end match
 return if value = 2 and not Reference.get(continued) then Result.Ok(()) else Result.Error("cancelled reader continued") end if
end function
"#
    ));
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new(
            [
                crate::runtime::sched::testing::ScheduleStep::PickTask(1),
                crate::runtime::sched::testing::ScheduleStep::PickTask(1),
                crate::runtime::sched::testing::ScheduleStep::PickTask(2),
            ],
            false,
        );
        let (mut rt, output) = runtime(&dir.0, mode, &script);
        let (count, delayed) = count_releases(&mut rt, &script, true);
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert_eq!(finish(&mut vm, &mut rt), VmStep::Finished(MainOutcome::Ok));
        assert!(*delayed.lock().unwrap());
        assert_eq!(*count.lock().unwrap(), 1);
        assert_eq!(*output.lock().unwrap(), b"winner");
        assert!(rt.ops.records.is_empty());
        consumed(&script);
    }
}
