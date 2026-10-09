//! 差し替えた時計と sleep の応答（実装プラン R29）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]
use super::super::runtime_test_support::*;
use super::*;
use crate::builtins::iface::{CallCtx, IoWait};
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::sched::testing::{ScheduleHandle, ScheduleStep};
// 関門: 正の長さだけを待ちにし、時計を直接読まず IoServices を使う契約。タイマーのテストは本体を差し替えていた。
#[test]
fn sleep_normalizes_nonpositive_durations_and_monotonic_time_uses_services() {
    let script = ScheduleHandle::new([ScheduleStep::Advance(123)], false);
    let (mut rt, _) = runtime(
        std::path::Path::new("/"),
        crate::vm::ExecMode::Direct,
        &script,
    );
    let mut resources = crate::runtime::io::resources::ResourceTable::default();
    let mut services = crate::runtime::io::services::IoView {
        rt: &mut rt,
        resources: &mut resources,
    };
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for millis in [i64::MIN, -1, 0, 1, i64::MAX] {
            let reply = sleep(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap(), millis).unwrap();
            if millis <= 0 { assert!(matches!(reply, IoReply::Done(Value::Unit))); }
            else { assert!(matches!(reply, IoReply::Wait(IoWait::Sleep {millis: n}) if n == u64::try_from(millis).unwrap())); }
        }
        let IoReply::Done(before) = monotonic_milliseconds(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap()).unwrap() else {panic!("clock waited")};
        assert_eq!(before.as_int(), Some(0));
        script.advance_time().unwrap();
        let IoReply::Done(after) = monotonic_milliseconds(CallCtx::new(ctx, Some(&mut services), None, None).io_ctx().unwrap()).unwrap() else {panic!("clock waited")};
        assert_eq!(after.as_int(), Some(123));
    });
}

#[derive(Debug)]
struct AdvanceAtIdle {
    inner: Box<dyn crate::runtime::sched::parts::WorkerExec>,
    script: ScheduleHandle,
    advances: Vec<u64>,
}
impl crate::runtime::sched::parts::WorkerExec for AdvanceAtIdle {
    fn wakeup(&self) -> Option<crate::runtime::io::event::Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: crate::runtime::io::ops::WorkerJob) {
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<crate::runtime::io::ops::Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> crate::runtime::sched::parts::IdleWake {
        let now = self.script.clock().monotonic_millis();
        let amount = self.advances.pop().unwrap();
        assert_eq!(deadline, now.checked_add(amount));
        self.script.allow_time(amount);
        self.inner.idle(deadline)
    }
}
// 関門: sleep の本体とタイマーをつなぎ、待つ間の他のタスクの進行と期限前に起きないことを確かめる。
// 仮想の時計は実行可能なタスクが尽きた位置でだけ進め、実時間の待ちを使わない。
#[test]
fn sleeping_task_waits_for_virtual_time_while_another_task_progresses() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit,String] uses Clock.Time,State
 bind progressed <- Reference.new(false)
 bind times <- Task.all([
 lambda()
  Clock.sleep(10)
  return if Reference.get(progressed) then Clock.monotonicMilliseconds() else -1 end if
 end lambda,
 lambda()
  Reference.set(progressed,true)
  bind started <- Clock.monotonicMilliseconds()
  Clock.sleep(9)
  return if started = 0 then Clock.monotonicMilliseconds() else -1 end if
 end lambda])
 return if times = [10,9] then Result.Ok(()) else Result.Error("sleep timing or progress") end if
end function
"#,
    );
    for mode in [crate::vm::ExecMode::Direct, crate::vm::ExecMode::Request] {
        let script = ScheduleHandle::new(
            [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
            false,
        );
        let (mut rt, _) = runtime(std::path::Path::new("/"), mode, &script);
        let inner = std::mem::replace(&mut rt.parts.workers, script.parts().workers);
        rt.parts.workers = Box::new(AdvanceAtIdle {
            inner,
            script: script.clone(),
            advances: vec![1, 9],
        });
        let mut vm = crate::vm::Vm::new(
            &program,
            crate::vm::VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert_eq!(
            finish(&mut vm, &mut rt),
            crate::vm::VmStep::Finished(crate::vm::MainOutcome::Ok)
        );
        consumed(&script);
        assert_eq!(script.clock().monotonic_millis(), 10);
        assert_eq!(
            script
                .record()
                .events
                .iter()
                .filter_map(|e| match e {
                    crate::runtime::sched::testing::ScheduleEvent::Advanced(n) => Some(*n),
                    crate::runtime::sched::testing::ScheduleEvent::Spawned { .. }
                    | crate::runtime::sched::testing::ScheduleEvent::Picked { .. }
                    | crate::runtime::sched::testing::ScheduleEvent::WorkerRan(_) => None,
                })
                .collect::<Vec<_>>(),
            [9, 1]
        );
    }
}

// 関門: 新しい本体がミリ秒を正負ともにナノ秒へ変換し、上下端の溢れを検査する。
// スケジューラの時計のテストは、このレコードの構築と整数の演算を通さない。
#[test]
fn now_and_local_offset_use_the_supplied_clock_and_check_overflow() {
    for (millis, expected) in [
        (0, Some(0)),
        (123, Some(123_000_000)),
        (-123, Some(-123_000_000)),
        (9_223_372_036_854, Some(9_223_372_036_854_000_000)),
        (-9_223_372_036_854, Some(-9_223_372_036_854_000_000)),
        (9_223_372_036_855, None),
        (-9_223_372_036_855, None),
        (i64::MAX, None),
        (i64::MIN, None),
    ] {
        let script = ScheduleHandle::new([], false).with_clock(millis, -330);
        let (mut rt, _) = runtime(
            std::path::Path::new("/"),
            crate::vm::ExecMode::Direct,
            &script,
        );
        let mut resources = crate::runtime::io::resources::ResourceTable::default();
        let mut services = crate::runtime::io::services::IoView {
            rt: &mut rt,
            resources: &mut resources,
        };
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let reply = now(CallCtx::new(ctx, Some(&mut services), None, None)
                .io_ctx()
                .unwrap());
            if let Some(expected) = expected {
                let IoReply::Done(value) = reply.unwrap() else {
                    panic!("now waited")
                };
                assert_eq!(
                    ctx.fields_header(value),
                    Some((FieldsKind::Ctor, tags::RECORD))
                );
                assert_eq!(ctx.fields_len(value), Some(1));
                assert_eq!(ctx.field(value, 0).unwrap().as_int(), Some(expected));
            } else {
                assert!(matches!(
                    reply,
                    Err(Stop::Runtime(crate::runtime::RuntimeError::IntegerOverflow))
                ));
            }
            let IoReply::Done(value) = local_offset_minutes(
                CallCtx::new(ctx, Some(&mut services), None, None)
                    .io_ctx()
                    .unwrap(),
            )
            .unwrap() else {
                panic!("offset waited")
            };
            assert_eq!(value.as_int(), Some(-330));
        });
    }
}
