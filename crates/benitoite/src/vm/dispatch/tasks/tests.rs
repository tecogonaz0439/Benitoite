//! タスクの観察できる結果と、切り替え・待ちをまたぐ根を確かめる（実装プラン R25）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::*;
use crate::pipeline::{self, CheckOptions};
use crate::runtime::heap::HeapConfig;
use crate::runtime::io::resources::ResourceContent;
use crate::runtime::io::services::RunInput;
use crate::runtime::sched::testing::{ScheduleEvent, ScheduleHandle, ScheduleStep};
use crate::vm::Vm;
use crate::vm::dispatch::test_support::TestIo;

pub(super) fn compile(source: &str) -> CompiledProgram {
    let checked = pipeline::check_text(
        "r25.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}
pub(super) fn services() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}
fn run(
    source: &str,
    budget: u32,
    steps: Vec<ScheduleStep>,
) -> (VmStep, crate::runtime::sched::testing::ScheduleRecord) {
    let program = compile(source);
    let mut vm = Vm::new(
        &program,
        VmConfig {
            call_budget: budget,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    let script = ScheduleHandle::new(steps, false);
    vm.use_schedule(script.clone());
    vm.start_main().unwrap();
    let step = vm.run(services().runtime(ExecMode::Direct));
    assert!(vm.heap.take_fault().is_none());
    assert_eq!(vm.state.tasks.live_count(), 0);
    let record = script.record();
    assert_eq!(record.remaining, 0, "{record:?}");
    assert!(record.error.is_none(), "{record:?}");
    (step, record)
}
// 関門: 結果の順序は完了順と異なる。既存の一タスクのテストは、子への配送と
// SpawnWait の根を通らないため、スクリプトから結果を観察する。
#[test]
fn all_returns_spawn_order_under_reversed_completion_and_empty_input() {
    let source = "function main() -> Result[Unit, String]\n bind values <- Task.all([lambda() return 11 end lambda, lambda() return 22 end lambda, lambda() return 33 end lambda])\n if values = [11, 22, 33] then return Result.Ok(()) else return Result.Error(\"order\") end if\nend function\n";
    for (budget, steps) in [
        (1, vec![]),
        (
            1000,
            vec![
                ScheduleStep::PickTask(3),
                ScheduleStep::PickTask(2),
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(0),
            ],
        ),
    ] {
        let (step, record) = run(source, budget, steps);
        assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
        if budget == 1000 {
            assert_eq!(record.consumed, 4);
            let picked: Vec<_> = record
                .events
                .iter()
                .filter_map(|e| {
                    if let ScheduleEvent::Picked {
                        task,
                        scripted: true,
                    } = e
                    {
                        Some(task.index)
                    } else {
                        None
                    }
                })
                .collect();
            assert_eq!(picked, [3, 2, 1, 0]);
        }
    }
    assert_eq!(run("function main() -> Result[Unit, String]\n bind values: List[Integer] <- Task.all([])\n if values = [] then return Result.Ok(()) else return Result.Error(\"empty\") end if\nend function\n", 1, vec![]).0, VmStep::Finished(MainOutcome::Ok));
}

// 関門: TaskGroup の解放と await は異なる待ちを持つ。表の単体テストでは、
// 終わった Task の値から結果を読むことと、解放後の使用を検査できない。
#[test]
fn group_release_await_and_released_spawn_follow_resource_contract() {
    let source = r#"
function work() -> String
 return "child" + " result"
end function
function checkpoint() -> Unit
 return ()
end function
function main() -> Result[Unit, String] uses State
 bind task <- with group = TaskGroup.open() do
  TaskGroup.spawn(group, work)
 end with
 checkpoint()
 bind text <- Task.await(task)
 if text = "child result" then return Result.Ok(()) else return Result.Error(text) end if
end function
"#;
    for budget in [1, 1000] {
        assert_eq!(
            run(source, budget, vec![]).0,
            VmStep::Finished(MainOutcome::Ok)
        );
    }
    let closed = r#"
function main() -> Unit uses State
 bind closed <- with group = TaskGroup.open() do group end with
 bind _ <- TaskGroup.spawn(closed, lambda() return () end lambda)
 return ()
end function
"#;
    let VmStep::Stopped(StopEnd {
        reason: StopReason::Error(info),
        ..
    }) = run(closed, 1, vec![]).0
    else {
        panic!("expected error")
    };
    assert_eq!(
        info.stop,
        Stop::Runtime(RuntimeError::ReleasedResourceUsed {
            kind: crate::runtime::ResourceKind::TaskGroup
        })
    );
}
const PROBE: &str = "effect Probe\n function ask(n: Integer) -> Integer\nend effect\n";
// 関門: 引き継いだ記録は親が終わっても孫を所有し、handle の戻り値と戻り先を
// 保存する。R20 の一タスクの resume のテストでは、待ちの間の別の RETURN に届かない。
#[test]
fn inherited_handler_waits_for_grandchild_and_preserves_wrapped_return() {
    let source = PROBE.to_owned(); // 以下で本番の構文をつなぐ。
    let source = source
        + r#"
function wrapped() -> Integer
 return handle ask(2) with case ask(n) -> resume(n) end handle
end function
function main() -> Result[Unit, String] uses State
 bind r <- Reference.new(0)
 with group = TaskGroup.open() do
  bind text <- handle
   bind first <- TaskGroup.spawn(group, lambda()
    bind second <- TaskGroup.spawn(group, lambda()
     Reference.set(r, ask(wrapped()))
     return ()
    end lambda)
    Reference.set(r, ask(1))
    return ()
   end lambda)
   "saved" + " return"
  with case ask(n) -> resume(n + 10) end handle
  bind n <- Reference.get(r)
  if text = "saved return" and n = 12 then return Result.Ok(()) else return Result.Error(text) end if
 end with
end function
"#;
    for (budget, steps) in [
        (1, vec![]),
        (
            1000,
            vec![
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2),
                ScheduleStep::PickTask(0),
            ],
        ),
    ] {
        assert_eq!(
            run(&source, budget, steps).0,
            VmStep::Finished(MainOutcome::Ok)
        );
    }
}
#[test]
fn inherited_non_tail_clause_stops_before_executing_it() {
    let source = PROBE.to_owned()
        + r#"
function main() -> Unit uses State
 with group = TaskGroup.open() do
  bind _ <- handle
   bind child <- TaskGroup.spawn(group, lambda() return ask(1) end lambda)
   0
  with case ask(n) -> n end handle
 end with
 return ()
end function
"#;
    let VmStep::Stopped(StopEnd {
        reason: StopReason::Error(info),
        ..
    }) = run(&source, 1, vec![]).0
    else {
        panic!("expected error")
    };
    assert!(matches!(
        info.stop,
        Stop::Runtime(RuntimeError::InheritedHandlerClause { .. })
    ));
    assert_eq!(info.spawns.len(), 1);
}
// 関門: 予算による切り替えと Lazy の内部の待ちは、単独の FORCE と異なる。
// 二度評価した場合にはセルの計数が変わり、入口の引数を消した場合には結果を得られない。
#[test]
fn lazy_waits_and_retries_without_evaluating_twice() {
    let source = r#"
function pause(n: Integer) -> Integer
 if n = 0 then return 42 end if
 return pause(n - 1)
end function
function main() -> Result[Unit, String]
 bind value <- lazy pause(8) end lazy
 bind values <- Task.all([lambda() return Lazy.force(value) end lambda, lambda() return Lazy.force(value) end lambda])
 if values = [42, 42] then return Result.Ok(()) else return Result.Error("lazy") end if
end function
"#;
    let observed = std::sync::Arc::new(std::sync::atomic::AtomicU8::new(0));
    let seen = std::sync::Arc::clone(&observed);
    let program = compile(source);
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
    let script = ScheduleHandle::new(
        [
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(2),
        ],
        false,
    );
    vm.use_schedule(script.clone());
    vm.start_main().unwrap();
    vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
        for entry in &state.tasks.entries {
            if let Some(slot) = &entry.task {
                let task = ctx.host::<TaskObj>(ctx.load(slot)).unwrap();
                for slot in task.stack.segments.iter().flat_map(|s| &s.regs) {
                    match ctx.host::<crate::vm::handler::LazyState>(ctx.load(slot)) {
                        Some(crate::vm::handler::LazyState::Evaluating { waiters, .. })
                            if !waiters.is_empty() =>
                        {
                            seen.fetch_or(1, std::sync::atomic::Ordering::Relaxed);
                        }
                        Some(crate::vm::handler::LazyState::Done { value })
                            if task.id.index == 2 =>
                        {
                            assert_eq!(ctx.load(value).as_int(), Some(42));
                            seen.fetch_or(2, std::sync::atomic::Ordering::Relaxed);
                        }
                        _ => {}
                    }
                }
            }
        }
        Ok(())
    }));
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(observed.load(std::sync::atomic::Ordering::Relaxed), 3);
    assert_eq!(script.record().remaining, 0);
    assert_eq!(script.record().consumed, 3);
    assert!(script.record().error.is_none());
}

#[test]
fn update_retries_after_another_task_sets_the_cell() {
    let source = r#"
function pause(n: Integer) -> Integer
 if n = 0 then return 1 end if
 return pause(n - 1)
end function
function main() -> Result[Unit, String] uses State
 bind r <- Reference.new(0)
 bind _ <- Task.all([lambda() return Reference.update(r, lambda(n: Integer) return n + pause(5) end lambda) end lambda, lambda() return Reference.set(r, 100) end lambda])
 bind n <- Reference.get(r)
 if n = 101 then return Result.Ok(()) else return Result.Error(Integer.toString(n)) end if
end function
"#;
    assert_eq!(
        run(
            source,
            1,
            vec![
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(2)
            ]
        )
        .0,
        VmStep::Finished(MainOutcome::Ok)
    );
}
#[test]
fn cyclic_await_reports_waiters_in_spawn_order() {
    let source = r#"
function main() -> Unit uses State
 bind a <- Reference.new(Option.None)
 bind b <- Reference.new(Option.None)
 with group = TaskGroup.open() do
  bind ta <- TaskGroup.spawn(group, lambda()
   bind other <- Reference.get(b)
   match other with case Option.Some(t) -> Task.await(t) 
   case Option.None -> () end match
   return ()
  end lambda)
  bind tb <- TaskGroup.spawn(group, lambda()
   bind other <- Reference.get(a)
   match other with case Option.Some(t) -> Task.await(t) 
   case Option.None -> () end match
   return ()
  end lambda)
  Reference.set(a, Option.Some(ta))
  Reference.set(b, Option.Some(tb))
 end with
 return ()
end function
"#;
    let VmStep::Stopped(StopEnd {
        reason: StopReason::Error(info),
        ..
    }) = run(
        source,
        1000,
        vec![ScheduleStep::PickTask(2), ScheduleStep::PickTask(1)],
    )
    .0
    else {
        panic!("expected deadlock")
    };
    assert_eq!(info.stop, Stop::Runtime(RuntimeError::TaskDeadlock));
    assert!(info.at.is_none());
    assert!(info.frames.is_empty());
    let awaits: Vec<_> = info
        .deadlock
        .iter()
        .filter(|w| w.kind == DeadlockWaitKind::Builtin("Task.await"))
        .collect();
    assert_eq!(awaits.len(), 2);
    assert!(awaits[0].spawns[0].spawned_at.pc < awaits[1].spawns[0].spawned_at.pc);
}

// 関門: 回収だけの遅い経路でタイマーを満了させると、その後に起動する子との
// 選択順が変わる。予算 1 ではこの違いが消えるため、複数の呼び出しを続ける。
#[test]
fn budget_switches_are_fair_and_collection_does_not_change_the_schedule() {
    let source = r"
function checkpoint() -> Unit
 return ()
end function
function count(n: Integer) -> Integer
 if n = 0 then return 42 end if
 return count(n - 1)
end function
function main() -> Result[Unit, String] uses State
 with group = TaskGroup.open() do
  bind first <- TaskGroup.spawn(group, lambda()
   checkpoint()
   bind _ <- TaskGroup.spawn(group, lambda() return count(6) end lambda)
   return count(6)
  end lambda)
  bind second <- TaskGroup.spawn(group, lambda() return count(6) end lambda)
  bind _ <- Task.await(first)
 end with
 return Result.Ok(())
end function
";
    let program = compile(source);
    for budget in 3..=5 {
        let mut sequences = Vec::new();
        for stress in [false, true] {
            let mut vm = Vm::new(
                &program,
                VmConfig {
                    call_budget: budget,
                    ..VmConfig::default()
                },
                HeapConfig {
                    stress,
                    ..HeapConfig::default()
                },
            );
            let script = ScheduleHandle::new(
                [ScheduleStep::PickTask(1), ScheduleStep::Advance(10)],
                false,
            );
            vm.use_schedule(script.clone());
            // Clock.sleep の組み込みは L10 が書く。VM の待ちの境界で第二の子を
            // タイマーに登録し、満了と第三の子の起動が競合する状況を作る。
            let mut installed = false;
            vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
                if !installed {
                    let id = *state
                        .scheduler
                        .ready
                        .iter()
                        .find(|id| id.index == 2)
                        .unwrap();
                    let timer = state.scheduler.new_timer_id();
                    state.scheduler.ready.retain(|ready| *ready != id);
                    state.scheduler.park(id, WaitReason::Timer(timer));
                    state.scheduler.add_timer(10, timer, id);
                    let value = object(state, ctx, id)?;
                    ctx.host_mut::<TaskObj, _>(value, |task, _| {
                        task.state = TaskState::Waiting(WaitReason::Timer(timer));
                    })
                    .unwrap();
                    installed = true;
                }
                Ok(())
            }));
            vm.start_main().unwrap();
            assert_eq!(
                vm.run(services().runtime(ExecMode::Direct)),
                VmStep::Finished(MainOutcome::Ok)
            );
            let record = script.record();
            assert_eq!(record.remaining, 0);
            assert_eq!(record.consumed, 2);
            assert!(record.error.is_none(), "{record:?}");
            let events: Vec<_> = record
                .events
                .into_iter()
                .filter(|event| {
                    matches!(
                        event,
                        ScheduleEvent::Picked { .. } | ScheduleEvent::Advanced { .. }
                    )
                })
                .collect();
            assert!(
                events
                    .iter()
                    .any(|event| matches!(event, ScheduleEvent::Advanced { .. }))
            );
            for child in 1..=3 {
                assert!(events.iter().any(|event| matches!(event, ScheduleEvent::Picked { task, .. } if task.index == child)));
            }
            sequences.push(events);
        }
        assert_eq!(sequences[0], sequences[1], "budget={budget}");
    }
}
#[test]
#[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
fn a_million_inherited_tail_resumes_fit_a_small_stack() {
    let count = 1_000_000;
    let source = PROBE.to_owned()
        + &format!(
            r#"
function repeat(n: Integer) -> Integer uses Probe
 if n = 0 then return 42 end if
 bind step <- ask(1)
 return repeat(n - step)
end function
function main() -> Result[Unit, String] uses State
 with group = TaskGroup.open() do
  bind task <- handle
   TaskGroup.spawn(group, lambda() return repeat({count}) end lambda)
  with case ask(n) -> resume(n) end handle
  bind n <- Task.await(task)
  if n = 42 then return Result.Ok(()) else return Result.Error("resume") end if
 end with
end function
"#
        );
    let program = compile(&source);
    let mut vm = Vm::new(
        &program,
        VmConfig {
            max_call_stack_bytes: 1024 * 1024,
            ..VmConfig::default()
        },
        HeapConfig::default(),
    );
    vm.start_main().unwrap();
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(vm.state.meter.bytes(), 0);
}
// 関門: 最初の停止理由を保ち、子の終わりを待たず全タスクの解放を行う。
#[test]
fn child_failure_stops_all_tasks_and_preserves_spawn_history() {
    let source = PROBE.to_owned()
        + r#"
function busy(n: Integer) -> Integer
 if n = 0 then return 42 end if
 return busy(n - 1)
end function
function main() -> Unit uses State
 with group = TaskGroup.open() do
  bind _ <- handle
   bind first <- TaskGroup.spawn(group, lambda() return 1 div 0 end lambda)
   bind second <- TaskGroup.spawn(group, lambda() return busy(100000) end lambda)
   ()
  with case ask(n) -> resume(n) end handle
 end with
 return ()
end function
"#;
    let (step, record) = run(&source, 1000, vec![ScheduleStep::PickTask(1)]);
    let VmStep::Stopped(StopEnd {
        reason: StopReason::Error(info),
        release_failures,
    }) = step
    else {
        panic!("expected stop")
    };
    assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
    assert_eq!(info.spawns.len(), 1);
    assert!(!info.spawns[0].spawner_frames.is_empty());
    assert!(release_failures.is_empty());
    assert_eq!(record.consumed, 1);
}
#[test]
fn timer_wakes_only_at_the_virtual_deadline() {
    let program = compile("function main() -> Unit\n return ()\nend function\n");
    let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
    let script = ScheduleHandle::new(
        [
            ScheduleStep::Advance(9),
            ScheduleStep::PickTask(0),
            ScheduleStep::Advance(1),
        ],
        false,
    );
    vm.use_schedule(script.clone());
    let mut prepared = services();
    let runtime = &mut prepared.rt;
    if let Some(parts) = vm.state.scheduling.test_parts.take() {
        runtime.parts = parts;
    }
    vm.start_main().unwrap();
    runtime.parts.picker.spawned(0, vm.state.current_task);
    assert!(matches!(
        test_timer(&mut vm.state, 10).unwrap(),
        Control::Return
    ));
    let timer = *vm.state.scheduler.timers.keys().next().unwrap();
    vm.heap.epoch(|ctx| {
        boundary(
            &program,
            &mut vm.state,
            ctx,
            runtime,
            crate::runtime::io::WaitPoint::Park,
        )
        .unwrap()
    });
    assert_eq!(script.clock().monotonic_millis(), 9);
    assert!(vm.state.scheduler.ready.is_empty());
    assert_eq!(
        vm.state
            .scheduler
            .waiting
            .get(&vm.state.current_task)
            .unwrap()
            .reason,
        WaitReason::Timer(timer.1)
    );
    assert_eq!(
        script
            .picker()
            .pick(&std::collections::VecDeque::from([vm.state.current_task])),
        Some(0)
    );
    vm.heap.epoch(|ctx| {
        boundary(
            &program,
            &mut vm.state,
            ctx,
            runtime,
            crate::runtime::io::WaitPoint::Park,
        )
        .unwrap()
    });
    assert_eq!(script.clock().monotonic_millis(), 10);
    assert!(vm.state.scheduler.waiting.is_empty());
    assert_eq!(
        vm.state.scheduler.ready.front(),
        Some(&vm.state.current_task)
    );
    assert_eq!(script.record().consumed, 3);
    assert_eq!(script.record().remaining, 0);
}
#[test]
fn cleanup_terminates_when_a_traversal_error_does_not_advance() {
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};
    let program = compile("function main() -> Unit\n return ()\nend function\n");
    let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
    let mut prepared = services();
    let runtime = &mut prepared.rt;
    if let Some(parts) = vm.state.scheduling.test_parts.take() {
        runtime.parts = parts;
    }
    vm.start_main().unwrap();
    let reason = StopReason::Error(
        vm.state
            .stop_info(Stop::Runtime(RuntimeError::DivisionByZero), None),
    );
    vm.state.stopping = Some(reason.clone());
    vm.state.scheduling.stopping = true;
    let wait = WaitReason::Release(crate::runtime::heap::ResourceId(99));
    let rest = std::mem::take(&mut vm.state.stack);
    vm.state.unwinding = Some(UnwindWork {
        cause: UnwindCause::Stop,
        segments: rest
            .segments
            .into_iter()
            .map(|s| (s, UnwindCause::Stop))
            .collect(),
        waiting: Some(wait),
        log: ReleaseLog::default(),
    });
    // 二重に待たせる不整合は、枠を降ろす前に Err になる。停止の理由は置き換えない。
    vm.state.scheduler.park(vm.state.current_task, wait);
    vm.heap.epoch(|ctx| {
        assert_eq!(
            super::super::unwinding::cleanup(&mut vm.state, ctx),
            LoopExit::Return
        );
    });
    // 第 2 段の切り替えは回収を先に返すことがある。実行の入口でその再開も通す（設計書 02-08「タスクの切り替え」）。
    assert_eq!(
        vm.run(runtime),
        VmStep::Stopped(StopEnd {
            reason,
            release_failures: vec![]
        })
    );
    assert_eq!(vm.state.tasks.live_count(), 0);
    assert_eq!(vm.state.meter.bytes(), 0);
}

// 関門: 各置き場だけに残る値は、別の根を残すスクリプトだけでは漏れを検出できない。
// R03/R25 の指定どおり実際の RunState を回収の根にし、一つずつ孤立させる。
#[test]
fn every_task_owned_root_survives_collection_in_isolation() {
    use crate::runtime::heap::Heap;
    use crate::vm::unwind::{
        ReleaseLog, ReturnDest, ReturnStage, ReturnWork, UnwindCause, UnwindWork,
    };
    for place in 0..7 {
        let mut heap = Heap::new(HeapConfig {
            stress: true,
            ..HeapConfig::default()
        });
        let mut state = RunState::new(VmConfig::default(), 0);
        let id = heap.epoch(|ctx| {
            let text = ctx.alloc_str("sole task root", "test").unwrap();
            state.tasks.insert(ctx, |id| {
                let mut task = empty_task(id, 1);
                task.state = TaskState::Waiting(WaitReason::Lazy);
                match place {
                    0 => task.stack.segments.push(Segment {
                        regs: vec![ctx.new_slot(text)],
                        ..Segment::default()
                    }),
                    1 | 2 => {
                        let record = ctx.alloc_host(HandlerRecord {
                            clauses: vec![ctx.new_slot(text)],
                            desc: crate::bytecode::program::HandlerIdx(0),
                            evaluated_by: id,
                            members: vec![id],
                            body_finished: false,
                        });
                        if place == 1 {
                            task.inherited.push(ctx.new_slot(record));
                        } else {
                            task.handle = Some(ctx.new_slot(record));
                        }
                    }
                    3 => {
                        task.state = TaskState::Done;
                        task.result = TaskResult::Value(ctx.new_slot(text));
                    }
                    4 => {
                        let mut child = empty_task(
                            TaskId {
                                index: 99,
                                generation: 0,
                            },
                            1,
                        );
                        child.state = TaskState::Done;
                        child.result = TaskResult::Value(ctx.new_slot(text));
                        let child = ctx.alloc_host(child);
                        task.spawn_wait = Some(SpawnWait {
                            mode: SpawnMode::All,
                            children: vec![ctx.new_slot(child)],
                            timer: None,
                        });
                    }
                    5 => {
                        task.returning = Some(ReturnWork {
                            value: ctx.new_slot(text),
                            dest: ReturnDest::TaskResult,
                            stage: ReturnStage::Wrapping,
                            at: InstrRef {
                                proto: ProtoIdx(0),
                                pc: 0,
                            },
                        })
                    }
                    6 => {
                        task.state = TaskState::Unwinding(UnwindWork {
                            cause: UnwindCause::DropRel,
                            segments: vec![(
                                Segment {
                                    regs: vec![ctx.new_slot(text)],
                                    ..Segment::default()
                                },
                                UnwindCause::DropRel,
                            )],
                            waiting: Some(WaitReason::Release(crate::runtime::heap::ResourceId(0))),
                            log: ReleaseLog::default(),
                        })
                    }
                    _ => panic!("unknown root place"),
                }
                ctx.alloc_host(task)
            })
        });
        // Done の対象はタスクの値だけが所有する。表から外しても結果を辿れることを確かめる。
        let done_root = if place == 3 {
            Some(heap.epoch(|ctx| {
                let value = state.tasks.get(ctx, id).unwrap();
                let root = state.roots.push(ctx, value);
                state.tasks.remove(ctx, id);
                root
            }))
        } else {
            None
        };
        heap.collect(&state);
        assert!(heap.take_fault().is_none());
        heap.epoch(|ctx| {
            let value = done_root.map_or_else(
                || state.tasks.get(ctx, id).unwrap(),
                |root| state.roots.get(ctx, root).unwrap(),
            );
            let task = ctx.host::<TaskObj>(value).unwrap();
            let text = match place {
                0 => ctx.load(&task.stack.segments[0].regs[0]),
                1 => ctx.load(
                    &ctx.host::<HandlerRecord>(ctx.load(&task.inherited[0]))
                        .unwrap()
                        .clauses[0],
                ),
                2 => ctx.load(
                    &ctx.host::<HandlerRecord>(ctx.load(task.handle.as_ref().unwrap()))
                        .unwrap()
                        .clauses[0],
                ),
                3 => {
                    let TaskResult::Value(slot) = &task.result else {
                        panic!("result missing")
                    };
                    ctx.load(slot)
                }
                4 => {
                    let child = ctx
                        .host::<TaskObj>(ctx.load(&task.spawn_wait.as_ref().unwrap().children[0]))
                        .unwrap();
                    let TaskResult::Value(slot) = &child.result else {
                        panic!("child result missing")
                    };
                    ctx.load(slot)
                }
                5 => ctx.load(&task.returning.as_ref().unwrap().value),
                6 => {
                    let TaskState::Unwinding(work) = &task.state else {
                        panic!("work missing")
                    };
                    ctx.load(&work.segments[0].0.regs[0])
                }
                _ => panic!("unknown root place"),
            };
            assert_eq!(ctx.str(text), Some("sole task root"));
        });
        assert!(heap.take_fault().is_none());
    }
}
#[test]
fn lazy_unwind_wakes_all_matching_waiters_except_while_stopping() {
    use crate::runtime::heap::Heap;
    use crate::vm::handler::LazyState;
    use crate::vm::unwind::{self, UnwindCause, UnwindStep};
    for cause in [UnwindCause::DropRel, UnwindCause::Cancel, UnwindCause::Stop] {
        let mut heap = Heap::new(HeapConfig::default());
        let mut state = RunState::new(VmConfig::default(), 0);
        let a = TaskId {
            index: 1,
            generation: 0,
        };
        let b = TaskId {
            index: 2,
            generation: 0,
        };
        state.scheduler.park(a, WaitReason::Lazy);
        state.scheduler.park(b, WaitReason::Lazy);
        heap.epoch(|ctx| {
            let lazy = ctx.alloc_host(LazyState::Evaluating {
                body: ctx.new_slot(Value::Unit),
                by: state.current_task,
                waiters: vec![a, b],
            });
            let slot = ctx.new_slot(lazy);
            let id = state.current_task;
            assert!(matches!(
                unwind::unwind_update(ctx, &mut state, id, &slot, cause).unwrap(),
                UnwindStep::Popped
            ));
            assert!(matches!(
                ctx.host::<LazyState>(lazy),
                Some(LazyState::Before { .. })
            ));
            ctx.discard(slot);
        });
        assert_eq!(
            state.scheduler.ready.len(),
            if cause == UnwindCause::Stop { 0 } else { 2 }
        );
        assert_eq!(
            state.scheduler.waiting.len(),
            if cause == UnwindCause::Stop { 2 } else { 0 }
        );
    }
}

#[derive(Debug)]
struct FakeResource {
    name: &'static str,
    fail: bool,
    events: std::sync::Arc<std::sync::Mutex<Vec<&'static str>>>,
}
impl crate::builtins::iface::OsResource for FakeResource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        self.events.lock().unwrap().push(self.name);
        if self.fail {
            Err(self.name.to_owned())
        } else {
            Ok(())
        }
    }
}
// 関門: E-DropRel は節の値と辿りを同時に保存する。偽の外部の資源をテスト用の
// 境界で置き、解放の完了を別のタスクの RETURN / 停止より後にする（R21/R24/R25）。
#[test]
fn blocking_drop_release_preserves_clause_return_while_another_task_returns() {
    let source = PROBE.to_owned()
        + r#"
function pause(n: Integer) -> Unit
 if n = 0 then return () end if
 return pause(n - 1)
end function
function main() -> Result[Unit, String] uses State
 bind results <- Task.all([
  lambda()
   bind value <- handle
    with fake = TaskGroup.open() do
     bind n <- ask(0)
     Integer.toString(n)
    end with
   with case ask(n) -> "kept" + " return" end handle
   return value
  end lambda,
  lambda()
   pause(20)
   bind n <- handle ask(2) with case ask(n) -> resume(n + 40) end handle
   return Integer.toString(n)
  end lambda
 ])
 if results = ["kept return", "42"] then return Result.Ok(()) else return Result.Error("return") end if
end function
"#;
    let events = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
    let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let watched = std::sync::Arc::clone(&observed);
    let recorded = std::sync::Arc::clone(&events);
    let program = compile(&source);
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
    let script = ScheduleHandle::new([ScheduleStep::PickTask(1)], false);
    vm.use_schedule(script.clone());
    vm.start_main().unwrap();
    let work_script = script.clone();
    let mut scheduled = std::collections::BTreeSet::new();
    vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
        for entry in state.resources.entries.values_mut() {
            if entry.kind == crate::runtime::ResourceKind::TaskGroup
                && entry.state == ResourceState::Open
            {
                entry.kind = crate::runtime::ResourceKind::FileWriter;
                entry.content = ResourceContent::Os(Some(Box::new(FakeResource {
                    name: "blocking",
                    fail: false,
                    events: std::sync::Arc::clone(&recorded),
                })));
            }
        }
        let mut other_done = true;
        for entry in &state.tasks.entries {
            if let Some(slot) = &entry.task {
                let t = ctx.host::<TaskObj>(ctx.load(slot)).unwrap();
                if t.id.index == 2 {
                    other_done = false;
                }
                if let TaskState::Unwinding(work) = &t.state
                    && work.cause == crate::vm::unwind::UnwindCause::DropRel
                    && matches!(work.waiting, Some(WaitReason::Release(_)))
                {
                    let returning = t.returning.as_ref().unwrap();
                    assert_eq!(ctx.str(ctx.load(&returning.value)), Some("kept return"));
                    watched.store(true, std::sync::atomic::Ordering::Relaxed);
                }
            }
        }
        if other_done {
            for entry in state.resources.entries.values() {
                if let ResourceState::Releasing(op) = entry.state
                    && matches!(entry.content, ResourceContent::Os(None))
                    && scheduled.insert(op)
                {
                    work_script.allow_worker(op);
                }
            }
        }
        Ok(())
    }));
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert!(observed.load(std::sync::atomic::Ordering::Relaxed));
    assert_eq!(*events.lock().unwrap(), ["blocking"]);
    assert_eq!(vm.state.meter.bytes(), 0);
    assert_eq!(script.record().consumed, 2);
    assert_eq!(script.record().remaining, 0);
    assert!(script.record().error.is_none());
}
#[test]
fn stopping_escalates_a_blocked_drop_traversal_and_keeps_earlier_release_failures() {
    let source = PROBE.to_owned()
        + r#"
function pause(n: Integer) -> Unit
 if n = 0 then return () end if
 return pause(n - 1)
end function
function main() -> Unit uses State
 bind saved <- Reference.new(Option.None)
 bind _ <- handle
  Task.all([
   lambda()
    bind n <- handle
     with blocking = TaskGroup.open() do
      with first = TaskGroup.open() do
       bind value <- lazy
        pause(50)
        0
       end lazy
       Reference.set(saved, Option.Some(value))
       bind _ <- Lazy.force(value)
       ask(0)
      end with
     end with
    with case ask(n) -> n + 10 end handle
    return n
   end lambda,
   lambda()
    pause(200)
    return 1 div 0
   end lambda,
   lambda()
    pause(1000)
    bind value <- Reference.get(saved)
    return match value with
     case Option.Some(v) -> Lazy.force(v)
     case Option.None -> 0
    end match
   end lambda
  ])
 with case ask(n) -> resume(n) end handle
 return ()
end function
"#;
    let events = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
    let recorded = std::sync::Arc::clone(&events);
    let observed = std::sync::Arc::new(std::sync::atomic::AtomicU8::new(0));
    let watched = std::sync::Arc::clone(&observed);
    let program = compile(&source);
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
    let script = ScheduleHandle::new([ScheduleStep::PickTask(1)], false);
    vm.use_schedule(script.clone());
    vm.start_main().unwrap();
    let mut injected = false;
    let work_script = script.clone();
    let mut scheduled = std::collections::BTreeSet::new();
    vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
        for (&id, entry) in &mut state.resources.entries {
            if entry.kind == crate::runtime::ResourceKind::TaskGroup
                && entry.state == ResourceState::Open
            {
                let (kind, name) = if id.0 == 4 {
                    (crate::runtime::ResourceKind::FileWriter, "blocking")
                } else {
                    (crate::runtime::ResourceKind::FileReader, "before")
                };
                entry.kind = kind;
                entry.content = ResourceContent::Os(Some(Box::new(FakeResource {
                    name,
                    fail: true,
                    events: std::sync::Arc::clone(&recorded),
                })));
            }
        }
        // Lazy の本体は純粋なので、この捕捉済み update と待つ側の組み合わせは
        // スクリプトだけでは作れない。R25 が指定した停止の組み合わせを、
        // 実際の辿りとスケジューラに準備する。言語の規則は変えない。
        if !injected {
            let values: Vec<_> = state
                .tasks
                .entries
                .iter()
                .filter_map(|e| e.task.as_ref().map(|s| ctx.load(s)))
                .collect();
            let a = values.iter().copied().find(|&v| ctx.host::<TaskObj>(v).is_some_and(|t| t.id.index == 1 && matches!(&t.state, TaskState::Unwinding(w) if matches!(w.waiting, Some(WaitReason::Release(_))))));
            let c = values
                .iter()
                .copied()
                .find(|&v| ctx.host::<TaskObj>(v).is_some_and(|t| t.id.index == 3));
            if let (Some(a), Some(c)) = (a, c) {
                let aid = ctx.host::<TaskObj>(a).unwrap().id;
                let cid = ctx.host::<TaskObj>(c).unwrap().id;
                let lazy = ctx.alloc_host(crate::vm::handler::LazyState::Evaluating {
                    body: ctx.new_slot(Value::Unit),
                    by: aid,
                    waiters: vec![cid],
                });
                state.constants.push(Some(ctx.new_slot(lazy)));
                ctx.host_mut::<TaskObj, _>(a, |task, slots| {
                    let TaskState::Unwinding(work) = &mut task.state else {
                        panic!("work missing")
                    };
                    work.segments.last_mut().unwrap().0.others.insert(
                        0,
                        crate::vm::frame::OtherFrame {
                            depth: 0,
                            kind: OtherKind::Update {
                                lazy: slots.new_slot(lazy),
                                at: InstrRef {
                                    proto: ProtoIdx(0),
                                    pc: 0,
                                },
                            },
                        },
                    );
                })
                .unwrap();
                state.meter.grow(1, 0);
                state.scheduler.ready.retain(|&id| id != cid);
                state.scheduler.park(cid, WaitReason::Lazy);
                ctx.host_mut::<TaskObj, _>(c, |task, _| {
                    task.state = TaskState::Waiting(WaitReason::Lazy)
                })
                .unwrap();
                injected = true;
            }
        }
        for entry in &state.tasks.entries {
            if let Some(slot) = &entry.task {
                let task = ctx.host::<TaskObj>(ctx.load(slot)).unwrap();
                if let TaskState::Unwinding(work) = &task.state
                    && matches!(work.waiting, Some(WaitReason::Release(_)))
                {
                    assert_eq!(work.log.failures.len(), 1);
                    assert_eq!(work.log.failures[0].reason, "before");
                    if work.cause == crate::vm::unwind::UnwindCause::DropRel {
                        watched.fetch_or(1, std::sync::atomic::Ordering::Relaxed);
                    }
                    if work.cause == crate::vm::unwind::UnwindCause::Stop {
                        watched.fetch_or(2, std::sync::atomic::Ordering::Relaxed);
                    }
                }
            }
        }
        if state
            .scheduler
            .waiting
            .values()
            .any(|w| w.reason == WaitReason::Lazy)
        {
            watched.fetch_or(4, std::sync::atomic::Ordering::Relaxed);
        }
        if state.stopping.is_some() {
            for entry in state.resources.entries.values() {
                if let ResourceState::Releasing(op) = entry.state
                    && matches!(entry.content, ResourceContent::Os(None))
                    && scheduled.insert(op)
                {
                    work_script.allow_worker(op);
                }
            }
        }
        Ok(())
    }));
    let VmStep::Stopped(StopEnd {
        reason: StopReason::Error(info),
        release_failures,
    }) = vm.run(services().runtime(ExecMode::Direct))
    else {
        panic!("expected stopped")
    };
    assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
    assert!(!info.spawns.is_empty());
    assert_eq!(observed.load(std::sync::atomic::Ordering::Relaxed), 7);
    assert_eq!(*events.lock().unwrap(), ["before", "blocking"]);
    assert_eq!(
        release_failures
            .iter()
            .map(|f| f.reason.as_str())
            .collect::<Vec<_>>(),
        ["before", "blocking"]
    );
    vm.heap.collect(&vm.state);
    vm.heap.epoch(|ctx| {
        let value = ctx.load(vm.state.constants.last().unwrap().as_ref().unwrap());
        assert!(matches!(
            ctx.host::<crate::vm::handler::LazyState>(value),
            Some(crate::vm::handler::LazyState::Before { .. })
        ));
    });
    assert_eq!(vm.state.tasks.live_count(), 0);
    assert_eq!(vm.state.meter.bytes(), 0);
    assert!(vm.heap.take_fault().is_none());
    assert_eq!(script.record().consumed, 2);
    assert_eq!(script.record().remaining, 0);
    assert!(script.record().error.is_none());
}

#[test]
fn invalid_script_selection_stops_instead_of_repeating_cleanup() {
    let program = compile(
        "function main() -> Unit\n bind _ <- Task.all([lambda() return () end lambda])\n return ()\nend function\n",
    );
    // 関門: 選べるタスクがある場合だけでなく、タイマーの待ちの間に行えない指示も
    // 記録し、元の指示を消費せず停止する（実装プラン R25「テスト用の部品」）。
    for external_wait in [false, true] {
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let step = if external_wait {
            ScheduleStep::PickTask(99)
        } else {
            ScheduleStep::PickIndex(99)
        };
        let script = ScheduleHandle::new([step], false);
        vm.use_schedule(script.clone());
        vm.start_main().unwrap();
        if external_wait {
            test_timer(&mut vm.state, 10).unwrap();
        }
        let VmStep::Stopped(StopEnd {
            reason: StopReason::Error(info),
            ..
        }) = vm.run(services().runtime(ExecMode::Direct))
        else {
            panic!("expected script error")
        };
        assert!(matches!(info.stop, Stop::Internal(_)));
        assert!(script.record().error.is_some());
        assert_eq!(script.record().remaining, 1);
        assert_eq!(script.record().consumed, 0);
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert_eq!(vm.state.meter.bytes(), 0);
    }
}

#[test]
fn await_reexecutes_prim_after_completion_and_keeps_the_result_through_collection() {
    let source = r#"
function checkpoint() -> Unit
 return ()
end function
function main() -> Result[Unit, String] uses State
 with group = TaskGroup.open() do
  bind task <- TaskGroup.spawn(group, lambda() return "await" + " result" end lambda)
  bind value <- Task.await(task)
  checkpoint()
  if value = "await result" then return Result.Ok(()) else return Result.Error(value) end if
 end with
end function
"#;
    for budget in [1, 1000] {
        assert_eq!(
            run(source, budget, vec![]).0,
            VmStep::Finished(MainOutcome::Ok)
        );
    }
}
#[test]
fn task_table_reuses_entries_without_accepting_old_generations() {
    let mut heap = crate::runtime::heap::Heap::new(HeapConfig::default());
    let mut table = crate::vm::task::TaskTable::default();
    heap.epoch(|ctx| {
        table.check_insert().unwrap();
        let old = table.insert(ctx, |id| ctx.alloc_host(empty_task(id, 1)));
        assert_eq!(table.live_count(), 1);
        table.check_remove(old).unwrap();
        table.remove(ctx, old);
        assert!(table.check_remove(old).is_err());
        let new = table.insert(ctx, |id| ctx.alloc_host(empty_task(id, 1)));
        assert_eq!(old.index, new.index);
        assert_eq!(new.generation, old.generation.wrapping_add(1));
        assert!(table.get(ctx, old).is_none());
        assert!(table.get(ctx, new).is_some());
        assert_eq!(table.live_count(), 1);
        table.free.push(new.index);
        assert!(table.check_insert().is_err());
    });
}

// 関門: 停止中に外部の完了を受け取れないと、切り替えの同じ Err を繰り返す。
// 完了を記録する既存のテストでは、この行き止まりを通らない。
#[test]
fn stopping_finishes_when_switching_cannot_make_progress() {
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};
    let program = compile("function main() -> Unit\n return ()\nend function\n");
    for case in 0..3 {
        let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
        if case == 1 {
            vm.use_schedule(ScheduleHandle::new([], false));
        }
        let mut prepared = services();
        prepared.rt.parts = ScheduleHandle::new([], false).parts();
        let runtime = &mut prepared.rt;
        if let Some(parts) = vm.state.scheduling.test_parts.take() {
            runtime.parts = parts;
        }
        vm.start_main().unwrap();
        let reason = StopReason::Error(
            vm.state
                .stop_info(Stop::Runtime(RuntimeError::DivisionByZero), None),
        );
        vm.state.stopping = Some(reason.clone());
        vm.state.scheduling.stopping = true;
        let wait = if case == 2 {
            WaitReason::Lazy
        } else {
            WaitReason::Release(crate::runtime::heap::ResourceId(99))
        };
        let earlier = crate::runtime::ReleaseFailure {
            kind: crate::runtime::ResourceKind::FileWriter,
            opened_at: None,
            reason: "earlier release".into(),
        };
        vm.state.scheduling.failures.push(earlier.clone());
        let mut log = ReleaseLog::default();
        let during = crate::runtime::ReleaseFailure {
            reason: "during traversal".into(),
            ..earlier.clone()
        };
        log.failures.push(during.clone());
        let rest = std::mem::take(&mut vm.state.stack);
        vm.state.unwinding = Some(UnwindWork {
            cause: UnwindCause::Stop,
            segments: rest
                .segments
                .into_iter()
                .map(|s| (s, UnwindCause::Stop))
                .collect(),
            waiting: Some(wait),
            log,
        });
        park(&mut vm.state, wait).unwrap();
        if case == 0 {
            // 修正前はここが Err で失敗する。残りは VM の入口から終了まで辿る。
            vm.heap
                .epoch(|ctx| switch(&program, &mut vm.state, ctx, runtime).unwrap());
        }
        assert_eq!(
            vm.run(runtime),
            VmStep::Stopped(StopEnd {
                reason,
                release_failures: vec![earlier, during]
            })
        );
        assert!(matches!(
            vm.state.scheduling.stop_error,
            Some(Stop::Internal(_))
        ));
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert_eq!(vm.state.meter.bytes(), 0);
    }
}

// 関門: 一つの集まりで要求ごとに spawn/await を繰り返しても、終わった子の
// 番号を走査し続けない。Task の結果を所有する欄はこの除去の対象にしない。
#[test]
fn completed_children_do_not_accumulate_in_groups_or_spawners() {
    let mut source = String::from(
        "function main() -> Result[Unit, String] uses State\n with group = TaskGroup.open() do\n",
    );
    for n in 0..64 {
        source.push_str(&format!("  bind task{n} <- TaskGroup.spawn(group, lambda() return 42 end lambda)\n  bind value{n} <- Task.await(task{n})\n  if value{n} <> 42 then return Result.Error(\"result\") end if\n"));
    }
    source.push_str(" end with\n return Result.Ok(())\nend function\n");
    let program = compile(&source);
    let mut vm = Vm::new(
        &program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.state.scheduling.test_boundary = Some(Box::new(|state, ctx| {
        for entry in &state.tasks.entries {
            if let Some(slot) = &entry.task {
                let task = ctx.host::<TaskObj>(ctx.load(slot)).unwrap();
                assert!(
                    task.spawned
                        .iter()
                        .all(|id| state.tasks.get(ctx, *id).is_some())
                );
            }
        }
        for entry in state.resources.entries.values() {
            if let ResourceContent::TaskGroup(children) = &entry.content {
                assert!(
                    children
                        .iter()
                        .all(|id| state.tasks.get(ctx, *id).is_some())
                );
                assert!(children.len() <= 1);
            }
        }
        Ok(())
    }));
    vm.start_main().unwrap();
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(vm.state.tasks.live_count(), 0);
}

mod cancellation;

// 旧 sleep の直接呼び出しで組んだ、スケジューラ自身のタイマーの準備を保つ（実装プラン R26）。
fn test_timer(state: &mut RunState, millis: u64) -> Result<Control, Stop> {
    let timer = state.scheduler.new_timer_id();
    state.scheduler.add_timer(millis, timer, state.current_task);
    park(state, WaitReason::Timer(timer))
}

mod interrupt;
