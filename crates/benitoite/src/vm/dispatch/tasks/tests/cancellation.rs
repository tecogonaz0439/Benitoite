//! 取り消しの観察できる結果と、待ち・解放・回収との組み合わせ（実装プラン R39）。
use super::*;

const PAUSE: &str = r#"
function pause(n: Integer) -> Unit
 if n = 0 then return () end if
 return pause(n - 1)
end function
"#;

fn picks(record: &crate::runtime::sched::testing::ScheduleRecord) -> Vec<u64> {
    record
        .events
        .iter()
        .filter_map(|e| match e {
            ScheduleEvent::Picked {
                task,
                scripted: true,
            } => Some(u64::from(task.index)),
            ScheduleEvent::Spawned { .. }
            | ScheduleEvent::Picked { .. }
            | ScheduleEvent::Advanced(_)
            | ScheduleEvent::WorkerRan(_) => None,
        })
        .collect()
}

// 関門: AllOk の結果の順と取り消す範囲は、All の順序のテストでは検査できない。
// 3 番目の失敗で前を取り消す退行と、取り消しを終える前の配送を捕まえる。
#[test]
fn all_ok_selects_the_first_error_in_input_order_and_cancels_only_later_children() {
    for (actions, expected, order) in [
        (
            "[lambda() return Result.Error(1) end lambda, lambda() pause(10000)
 return Result.Ok(2) end lambda, lambda() return Result.Error(3) end lambda]",
            "Result.Error(1)",
            vec![3, 1, 2, 0],
        ),
        (
            "[lambda() return Result.Ok(1) end lambda, lambda() return Result.Error(2) end lambda, lambda() return Result.Error(3) end lambda]",
            "Result.Error(2)",
            vec![3, 1, 2, 0],
        ),
        (
            "[lambda() return Result.Ok(1) end lambda, lambda() return Result.Ok(2) end lambda]",
            "Result.Ok([1,2])",
            vec![2, 1, 0],
        ),
    ] {
        let source = format!(
            "{PAUSE}\nfunction main() -> Result[Unit, String]\n bind result: Result[List[Integer], Integer] <- Task.allOk({actions})\n if result = {expected} then return Result.Ok(()) else return Result.Error(\"allOk\") end if\nend function\n"
        );
        for budget in [1, 1000] {
            let steps = if budget == 1000 {
                order.iter().map(|&id| ScheduleStep::PickTask(id)).collect()
            } else {
                vec![]
            };
            let (step, record) = run(&source, budget, steps);
            assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
            if budget == 1000 {
                assert_eq!(picks(&record), order);
            }
        }
    }
    assert_eq!(run("function main() -> Result[Unit, String]\n bind result: Result[List[Integer], String] <- Task.allOk([])\n if result = Result.Ok([]) then return Result.Ok(()) else return Result.Error(\"empty\") end if\nend function",1,vec![]).0,VmStep::Finished(MainOutcome::Ok));
}

// 関門: TaskGroup の返りの待ちを取り消しの辿りへ移し、子も止める契約。
#[test]
fn race_cancels_a_parent_already_waiting_for_group_release_before_delivering_the_winner() {
    let source = format!(
        r#"import Benitoite.Unofficial.IO.Clock
{PAUSE}
function main() -> Result[Unit, String] uses State, Clock.Time
 bind changed <- Reference.new(false)
 bind result <- Task.race([
  lambda()
   with group = TaskGroup.open() do
    bind _ <- TaskGroup.spawn(group, lambda() pause(10000)
 Reference.set(changed, true)
 return 9 end lambda)
    ()
   end with
   Reference.set(changed, true)
   return 1
  end lambda,
  lambda() return 42 end lambda
 ])
 if result = Option.Some(42) and not Reference.get(changed) then return Result.Ok(()) else return Result.Error("race") end if
end function"#
    );
    let order = vec![1, 2, 1, 3, 1, 0];
    let (step, record) = run(
        &source,
        1000,
        order.iter().map(|&id| ScheduleStep::PickTask(id)).collect(),
    );
    assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
    assert_eq!(picks(&record), order);
    assert_eq!(run("import Benitoite.Unofficial.IO.Clock\nfunction main() -> Result[Unit, String] uses Clock.Time, State\n bind result: Option[Integer] <- Task.race([])\n if result = Option.None then return Result.Ok(()) else return Result.Error(\"empty\") end if\nend function",1,vec![]).0,VmStep::Finished(MainOutcome::Ok));
}

// 関門: 取り消された SpawnWait の結果は積み重ねに書かず、子二つの終了を待つ。
// 一つ目の子の終了直後の境界でも親が待っていることを確かめる（R39 の個別の指示）。
#[test]
fn cancelling_a_spawn_wait_keeps_the_parent_parked_until_both_children_finish() {
    let source = format!(
        r#"import Benitoite.Unofficial.IO.Clock
{PAUSE}
function main() -> Result[Unit, String] uses Clock.Time, State
 bind result <- Task.race([
  lambda() bind _ <- Task.all([lambda() pause(10000)
 return 1 end lambda, lambda() pause(10000)
 return 2 end lambda])
 return 1 end lambda,
  lambda() return 42 end lambda
 ])
 if result = Option.Some(42) then return Result.Ok(()) else return Result.Error("parent") end if
end function"#
    );
    let program = compile(&source);
    let mut vm = Vm::new(
        &program,
        VmConfig {
            call_budget: 1000,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    let script = ScheduleHandle::new([1, 2, 3, 4, 1, 0].map(ScheduleStep::PickTask), false);
    vm.use_schedule(script.clone());
    let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let watched = std::sync::Arc::clone(&observed);
    vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
        let parent = state
            .tasks
            .entries
            .get(1)
            .and_then(|e| e.task.as_ref())
            .and_then(|s| ctx.host::<TaskObj>(ctx.load(s)));
        if let Some(parent) = parent
            && parent.cancel_requested
            && let Some(wait) = parent.spawn_wait.as_ref()
        {
            let pending = wait
                .children
                .iter()
                .filter(|s| {
                    matches!(
                        ctx.host::<TaskObj>(ctx.load(s)).unwrap().result,
                        TaskResult::Pending
                    )
                })
                .count();
            if pending == 1 {
                assert_eq!(
                    state.scheduler.waiting.get(&parent.id).unwrap().reason,
                    WaitReason::TaskEnd(TaskEndWait::Spawned)
                );
                assert!(!matches!(parent.state, TaskState::Unwinding(_)));
                assert!(!state.scheduling.deliveries.contains_key(&parent.id));
                watched.store(true, std::sync::atomic::Ordering::Relaxed);
            }
        }
        Ok(())
    }));
    vm.start_main().unwrap();
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert!(observed.load(std::sync::atomic::Ordering::Relaxed));
    assert_eq!(picks(&script.record()), [1, 2, 3, 4, 1, 0]);
    assert_eq!(script.record().remaining, 0);
    assert!(script.record().error.is_none());
    assert_eq!(vm.state.tasks.live_count(), 0);
    assert!(vm.state.scheduling.timed_out.is_empty());
}

// 関門: 期限前の完了、期限の満了、取り消された親のタイマーの除去を仮想時間で確かめる。
#[test]
fn timeouts_wait_for_cancellation_and_remove_obsolete_timers() {
    let check = |source: &str, steps: Vec<ScheduleStep>, order: &[u64], before_advance: bool| {
        let program = compile(source);
        let mut vm = Vm::new(
            &program,
            VmConfig {
                call_budget: 1000,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let script = ScheduleHandle::new(steps, false);
        vm.use_schedule(script.clone());
        let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let watched = std::sync::Arc::clone(&observed);
        let recorded = script.clone();
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
            // 子が終わって親を選ぶ境界は、次の予算切れで Advance を読むより前にある。
            // 最終的な finish_task による除去だけで通るテストにしない（R39 の受け入れテスト）。
            if before_advance
                && recorded.record().consumed == 1
                && recorded.next_step() == Some(ScheduleStep::PickTask(0))
            {
                assert_eq!(recorded.clock().monotonic_millis(), 0);
                assert!(state.scheduler.timers.is_empty());
                assert!(state.scheduling.timed_out.is_empty());
                watched.store(true, std::sync::atomic::Ordering::Relaxed);
            }
            Ok(())
        }));
        vm.start_main().unwrap();
        assert_eq!(
            vm.run(services().runtime(ExecMode::Direct)),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(picks(&script.record()), order);
        assert_eq!(script.record().remaining, 0);
        assert!(script.record().error.is_none());
        assert_eq!(
            observed.load(std::sync::atomic::Ordering::Relaxed),
            before_advance
        );
        assert!(vm.state.scheduler.timers.is_empty());
        assert!(vm.state.scheduling.timed_out.is_empty());
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert!(vm.heap.take_fault().is_none());
    };
    for (millis, action, expected, steps, order) in [
        (
            10,
            "return 42",
            "Option.Some(42)",
            vec![
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(0),
                ScheduleStep::Advance(100),
                ScheduleStep::PickTask(0),
            ],
            vec![1, 0, 0],
        ),
        (
            10,
            "pause(10000)
 return 42",
            "Option.None",
            vec![
                ScheduleStep::Advance(10),
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(0),
            ],
            vec![1, 0],
        ),
        (
            0,
            "return 42",
            "Option.None",
            vec![ScheduleStep::PickTask(1), ScheduleStep::PickTask(0)],
            vec![1, 0],
        ),
        (
            -1,
            "return 42",
            "Option.None",
            vec![ScheduleStep::PickTask(1), ScheduleStep::PickTask(0)],
            vec![1, 0],
        ),
    ] {
        let before_advance = expected == "Option.Some(42)";
        let after_result = if before_advance { "pause(10000)" } else { "" };
        let source = format!(
            "import Benitoite.Unofficial.IO.Clock\n{PAUSE}\nfunction main() -> Result[Unit, String] uses Clock.Time, State\n bind result <- Task.withTimeout({millis},lambda() {action} end lambda)\n {after_result}\n if result = {expected} then return Result.Ok(()) else return Result.Error(\"timeout\") end if\nend function"
        );
        check(&source, steps, &order, before_advance);
    }
    let source=format!("import Benitoite.Unofficial.IO.Clock\n{PAUSE}\nfunction main() -> Result[Unit, String] uses Clock.Time, State\n bind result <- Task.race([lambda() bind _ <- Task.withTimeout(10,lambda() pause(10000)
 return 1 end lambda)
 return 1 end lambda,lambda() return 42 end lambda])\n if result = Option.Some(42) then return Result.Ok(()) else return Result.Error(\"parent timeout\") end if\nend function");
    check(
        &source,
        vec![
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(2),
            ScheduleStep::Advance(100),
            ScheduleStep::PickTask(3),
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(0),
        ],
        &[1, 2, 3, 1, 0],
        false,
    );
}

// 関門: Await の停止位置は VM の PRIM。完了済みと待っている間の取り消しを同じ表で守る（設計書 01-11「取り消し」）。
#[test]
fn await_of_a_cancelled_task_stops_at_its_own_prim_even_after_waiting() {
    for waiting in [false, true] {
        let source = format!(
            r#"import Benitoite.Unofficial.IO.Clock
{PAUSE}
function waitSaved(saved: Reference[Option[Task[Integer]]]) -> Integer uses State
 return match Reference.get(saved) with
  case Option.Some(child) -> Task.await(child)
  case Option.None -> 1
 end match
end function
function main() -> Unit uses State, Clock.Time
 bind saved: Reference[Option[Task[Integer]]] <- Reference.new(Option.None)
 with outer = TaskGroup.open() do
  {before}
  bind _ <- Task.race([
   lambda()
    with group = TaskGroup.open() do
     bind child <- TaskGroup.spawn(group,lambda()
      pause(10000)
      return 7
     end lambda)
     Reference.set(saved,Option.Some(child))
     pause(10000)
    end with
    return 1
   end lambda,
   lambda() return 42 end lambda
  ])
  {after}
 end with
 return ()
end function"#,
            before = if waiting {
                "bind _ <- TaskGroup.spawn(outer,lambda() return waitSaved(saved) end lambda)"
            } else {
                ""
            },
            after = if waiting {
                "()"
            } else {
                "bind _ <- waitSaved(saved)\n ()"
            }
        );
        let steps = if waiting {
            vec![2, 1, 3, 2, 4, 1]
        } else {
            vec![1, 2, 1, 3, 1, 0]
        };
        let (step, record) = run(
            &source,
            1000,
            steps.iter().map(|&id| ScheduleStep::PickTask(id)).collect(),
        );
        let VmStep::Stopped(end) = step else {
            panic!("await did not stop")
        };
        let StopReason::Error(info) = end.reason else {
            panic!("not an error")
        };
        assert_eq!(info.stop, Stop::Runtime(RuntimeError::AwaitedTaskCancelled));
        let at = info.at.unwrap();
        let program = compile(&source);
        let instr = program.proto(at.proto).unwrap().code[at.pc as usize];
        assert_eq!(instr.opcode(), Some(Opcode::Prim));
        let reference = program
            .builtin(BuiltinRefIdx(u32::from(instr.b())))
            .unwrap();
        assert_eq!(builtin_decl(reference.id).unwrap().name, "Task.await");
        assert_eq!(picks(&record), steps);
    }
}

// 関門: Lazy の評価者と待つタスクの取り消しは異なる。Force の通常の待ちのテストは
// 評価のやり直しを通らない。実際に Lazy で待ったことを境界で確かめてから要求する。
#[test]
fn cancelling_the_lazy_evaluator_restarts_the_waiter_and_cancelling_the_waiter_leaves_the_evaluator_running()
 {
    for evaluator in [true, false] {
        let source = format!(
            r#"{PAUSE}
function main() -> Result[Unit, String] uses State
 bind value <- lazy
  pause(100)
  42
 end lazy
 with group = TaskGroup.open() do
  bind a <- TaskGroup.spawn(group,lambda() return Lazy.force(value) end lambda)
  bind b <- TaskGroup.spawn(group,lambda() return Lazy.force(value) end lambda)
  bind result <- Task.await({target})
  if result = 42 then return Result.Ok(()) else return Result.Error("lazy cancellation") end if
 end with
end function"#,
            target = if evaluator { "b" } else { "a" }
        );
        let program = compile(&source);
        let mut vm = Vm::new(
            &program,
            VmConfig {
                call_budget: 10,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let script = ScheduleHandle::new(
            [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
            false,
        );
        vm.use_schedule(script.clone());
        let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let watched = std::sync::Arc::clone(&observed);
        let mut sent = false;
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            if !sent
                && let Some((&id, _)) = state
                    .scheduler
                    .waiting
                    .iter()
                    .find(|(id, w)| id.index == 2 && w.reason == WaitReason::Lazy)
            {
                let target = if evaluator {
                    ctx.host::<TaskObj>(ctx.load(state.tasks.entries[1].task.as_ref().unwrap()))
                        .unwrap()
                        .id
                } else {
                    id
                };
                cancel::request(state, ctx, &[target])?;
                if !evaluator {
                    assert!(!state.scheduler.waiting.contains_key(&id));
                }
                sent = true;
                watched.store(true, std::sync::atomic::Ordering::Relaxed);
            }
            Ok(())
        }));
        vm.start_main().unwrap();
        assert_eq!(
            vm.run(services().runtime(ExecMode::Direct)),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert!(observed.load(std::sync::atomic::Ordering::Relaxed));
        assert_eq!(picks(&script.record()), [1, 2]);
        assert_eq!(script.record().remaining, 0);
        assert!(script.record().error.is_none());
        assert!(vm.heap.take_fault().is_none());
    }
}

// 関門: 取り消しの解放は内側から行い、失敗を集め終えるまで止まらない。
// E-DropRel に届いた要求は解放の待ちを保ち、戻りの値を使った通常の評価に戻らない。
#[test]
fn cancellation_preserves_release_waits_and_drop_traversal_and_releases_each_resource_once() {
    for (drop_rel, fail) in [(false, false), (false, true), (true, false)] {
        let body = if drop_rel {
            "bind _ <- handle\n with inner = TaskGroup.open() do\n pause(1000)\n bind _ <- ask(0)\n ()\n end with\n with case ask(n) -> () end handle\n Reference.set(changed,true)"
        } else {
            "with inner = TaskGroup.open() do\n pause(10000)\n end with\n Reference.set(changed,true)"
        };
        let source = format!(
            r#"import Benitoite.Unofficial.IO.Clock
{PROBE}
{PAUSE}
function main() -> Result[Unit, String] uses State, Clock.Time
 bind changed <- Reference.new(false)
 bind result <- Task.race([
  lambda()
   with outer = TaskGroup.open() do
    {body}
   end with
   Reference.set(changed,true)
   return 1
  end lambda,
  lambda() return 42 end lambda
 ])
 if result = Option.Some(42) and not Reference.get(changed) then return Result.Ok(()) else return Result.Error("continued") end if
end function"#
        );
        let program = compile(&source);
        let config = VmConfig {
            call_budget: 1000,
            ..VmConfig::default()
        };
        let mut vm = Vm::new(
            &program,
            config,
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let order = if drop_rel {
            vec![1, 1, 2, 1, 1, 0]
        } else if fail {
            vec![1, 2, 1, 1, 1]
        } else {
            vec![1, 2, 1, 1, 1, 0]
        };
        let script = ScheduleHandle::new(order.iter().copied().map(ScheduleStep::PickTask), false);
        vm.use_schedule(script.clone());
        let events = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
        let recorded = std::sync::Arc::clone(&events);
        let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let watched = std::sync::Arc::clone(&observed);
        let mut count = 0;
        let work_script = script.clone();
        let mut scheduled = std::collections::BTreeSet::new();
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            for entry in state.resources.entries.values_mut() {
                if entry.kind == crate::runtime::ResourceKind::TaskGroup
                    && entry.state == ResourceState::Open
                {
                    entry.kind = crate::runtime::ResourceKind::FileWriter;
                    entry.content = ResourceContent::Os(Some(Box::new(FakeResource {
                        name: if count == 0 { "outer" } else { "inner" },
                        fail,
                        events: std::sync::Arc::clone(&recorded),
                    })));
                    count += 1;
                }
            }
            let cancelled = state
                .tasks
                .entries
                .get(1)
                .and_then(|e| e.task.as_ref())
                .and_then(|s| ctx.host::<TaskObj>(ctx.load(s)))
                .is_some_and(|t| t.cancel_requested);
            if cancelled
                && let Some(slot) = state.tasks.entries[1].task.as_ref()
                && let Some(task) = ctx.host::<TaskObj>(ctx.load(slot))
                && let TaskState::Unwinding(work) = &task.state
                && let Some(WaitReason::Release(id)) = work.waiting
                && state.scheduler.waiting.contains_key(&task.id)
            {
                assert_eq!(
                    state.scheduler.waiting.get(&task.id).unwrap().reason,
                    WaitReason::Release(id)
                );
                if drop_rel && work.cause == crate::vm::unwind::UnwindCause::DropRel {
                    assert!(task.returning.is_some());
                    watched.store(true, std::sync::atomic::Ordering::Relaxed);
                } else if !drop_rel {
                    assert_eq!(work.cause, crate::vm::unwind::UnwindCause::Cancel);
                    watched.store(true, std::sync::atomic::Ordering::Relaxed);
                }
            }
            if cancelled {
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
        vm.start_main().unwrap();
        let step = vm.run(services().runtime(ExecMode::Direct));
        if fail {
            let VmStep::Stopped(end) = step else {
                panic!("release failures did not stop")
            };
            let StopReason::Error(info) = end.reason else {
                panic!("not error")
            };
            let Stop::Runtime(RuntimeError::ReleaseFailed(failures)) = info.stop else {
                panic!("not release failures")
            };
            assert_eq!(
                failures
                    .iter()
                    .map(|f| f.reason.as_str())
                    .collect::<Vec<_>>(),
                ["inner", "outer"]
            );
        } else {
            assert_eq!(
                step,
                VmStep::Finished(MainOutcome::Ok),
                "drop={drop_rel}, {:?}, {:?}",
                script.record(),
                events.lock().unwrap()
            );
        }
        assert!(observed.load(std::sync::atomic::Ordering::Relaxed));
        assert_eq!(*events.lock().unwrap(), ["inner", "outer"]);
        assert_eq!(picks(&script.record()), order);
        assert_eq!(script.record().remaining, 0);
        assert!(script.record().error.is_none());
        assert_eq!(vm.state.meter.bytes(), 0);
        assert!(vm.heap.take_fault().is_none());
    }
}

// 関門: Await の待ちを取り消した後に元の対象が完了しても、続きの副作用を実行しない。
#[test]
fn cancelling_an_awaiter_detaches_it_and_late_completion_cannot_resume_it() {
    let source = format!(
        r#"import Benitoite.Unofficial.IO.Clock
{PAUSE}
function main() -> Result[Unit, String] uses State, Clock.Time
 bind changed <- Reference.new(false)
 with outer = TaskGroup.open() do
  bind target <- TaskGroup.spawn(outer,lambda() pause(10000)
   return 7
  end lambda)
  bind result <- Task.race([
   lambda()
    with inner = TaskGroup.open() do
     bind _ <- TaskGroup.spawn(inner,lambda()
      bind _ <- Task.await(target)
      Reference.set(changed,true)
      return 1
     end lambda)
     pause(10000)
    end with
    return 1
   end lambda,
   lambda() return 42 end lambda
  ])
  bind _ <- Task.await(target)
  if result = Option.Some(42) and not Reference.get(changed) then return Result.Ok(()) else return Result.Error("late wake") end if
 end with
end function"#
    );
    let order = vec![2, 4, 3, 2, 4, 2, 0];
    let (step, record) = run(
        &source,
        1000,
        order.iter().copied().map(ScheduleStep::PickTask).collect(),
    );
    assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
    assert_eq!(picks(&record), order);
}

// 関門: タイマーが残る間は内部の循環した Await があっても行き詰まりではない。
// 満了で group の子を取り消した後の AwaitedTaskCancelled は独立した停止理由である。
#[test]
fn timeout_breaks_cyclic_awaits_instead_of_reporting_a_deadlock() {
    let source = r#"import Benitoite.Unofficial.IO.Clock
function waitSaved(saved: Reference[Option[Task[Integer]]]) -> Integer uses State
 return match Reference.get(saved) with
  case Option.Some(child) -> Task.await(child)
  case Option.None -> 1
 end match
end function
function main() -> Unit uses State, Clock.Time
 bind a: Reference[Option[Task[Integer]]] <- Reference.new(Option.None)
 bind b: Reference[Option[Task[Integer]]] <- Reference.new(Option.None)
 with outer = TaskGroup.open() do
  bind other <- TaskGroup.spawn(outer,lambda() return waitSaved(b) end lambda)
  Reference.set(a,Option.Some(other))
  bind result <- Task.withTimeout(10,lambda()
   with inner = TaskGroup.open() do
    bind child <- TaskGroup.spawn(inner,lambda() return waitSaved(a) end lambda)
    Reference.set(b,Option.Some(child))
    bind _ <- TaskGroup.spawn(inner,lambda() return 0 end lambda)
    return Task.await(child)
   end with
  end lambda)
  if result <> Option.None then bind _ <- 1 div 0 end if
 end with
 return ()
end function"#;
    let program = compile(source);
    let mut vm = Vm::new(
        &program,
        VmConfig {
            call_budget: 1000,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    let script = ScheduleHandle::new(
        [
            ScheduleStep::PickTask(2),
            ScheduleStep::PickTask(1),
            ScheduleStep::PickTask(3),
            ScheduleStep::PickTask(4),
            ScheduleStep::Advance(10),
            ScheduleStep::PickTask(2),
            ScheduleStep::PickTask(3),
            ScheduleStep::PickTask(2),
            ScheduleStep::PickTask(0),
            ScheduleStep::PickTask(1),
        ],
        false,
    );
    vm.use_schedule(script.clone());
    let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let watched = std::sync::Arc::clone(&observed);
    vm.state.scheduling.test_boundary = Some(Box::new(move |state, _| {
        if state
            .scheduler
            .waiting
            .values()
            .filter(|w| matches!(w.reason, WaitReason::TaskEnd(TaskEndWait::Await(_))))
            .count()
            == 3
            && !state.scheduler.timers.is_empty()
        {
            assert!(!state.scheduler.is_deadlocked());
            watched.store(true, std::sync::atomic::Ordering::Relaxed);
        }
        Ok(())
    }));
    vm.start_main().unwrap();
    let VmStep::Stopped(end) = vm.run(services().runtime(ExecMode::Direct)) else {
        panic!("cyclic await did not stop")
    };
    let StopReason::Error(info) = end.reason else {
        panic!("not error")
    };
    assert_eq!(info.stop, Stop::Runtime(RuntimeError::AwaitedTaskCancelled));
    assert!(observed.load(std::sync::atomic::Ordering::Relaxed));
    assert_eq!(picks(&script.record()), [2, 1, 3, 4, 2, 3, 2, 0, 1]);
    assert_eq!(script.record().remaining, 0);
    assert!(script.record().error.is_none());
    assert!(vm.state.scheduling.timed_out.is_empty());
}

// 関門: Lend の返却待ちは除き、Release の完了待ちは除かない（R39 の状態の表）。
// 作業用のスレッドの代わりに貸した資源をテストが保持し、同じ VM で取り消しを完了させる。
#[test]
fn cancellation_removes_lend_waiters_but_preserves_release_waits() {
    use crate::runtime::io::resources::{LendResult, ReleaseStart};
    use crate::runtime::sched::ExtOpId;
    for kind in 0..3 {
        let program = compile("function main() -> Unit\n return ()\nend function");
        let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
        vm.start_main().unwrap();
        let events = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
        let mut loan = None;
        let (id, resource, reason) = vm.heap.epoch(|ctx| {
            let id = vm
                .state
                .tasks
                .insert(ctx, |id| ctx.alloc_host(empty_task(id, 1)));
            let resource = vm.state.resources.insert(
                crate::runtime::ResourceKind::FileWriter,
                ResourceContent::Os(Some(Box::new(FakeResource {
                    name: "wait",
                    fail: false,
                    events: std::sync::Arc::clone(&events),
                }))),
                None,
            );
            let reason = if kind == 2 {
                assert!(matches!(
                    vm.state.resources.request_release(resource, ExtOpId(1)),
                    ReleaseStart::Blocking
                ));
                WaitReason::Release(resource)
            } else {
                let LendResult::Lent(handle) =
                    vm.state
                        .resources
                        .lend(resource, ExtOpId(1), vm.state.current_task)
                else {
                    panic!("lend failed")
                };
                loan = Some(handle);
                assert!(matches!(
                    vm.state.resources.lend(resource, ExtOpId(2), id),
                    LendResult::MustWait
                ));
                if kind == 1 {
                    vm.state.resources.entries.get_mut(&resource).unwrap().state =
                        ResourceState::Released;
                }
                WaitReason::Lend(resource)
            };
            let value = object(&vm.state, ctx, id).unwrap();
            ctx.host_mut::<TaskObj, _>(value, |task, _| task.state = TaskState::Waiting(reason))
                .unwrap();
            vm.state.scheduler.park(id, reason);
            cancel::request(
                &mut vm.state,
                ctx,
                &[
                    id,
                    id,
                    TaskId {
                        index: u32::MAX,
                        generation: 0,
                    },
                ],
            )
            .unwrap();
            assert!(ctx.host::<TaskObj>(value).unwrap().cancel_requested);
            (id, resource, reason)
        });
        if kind == 2 {
            assert_eq!(vm.state.scheduler.waiting.get(&id).unwrap().reason, reason);
            assert!(!vm.state.scheduler.ready.contains(&id));
            let (r, _, handle) = vm.state.resources.take_release_job().unwrap();
            assert_eq!(r, resource);
            vm.state.resources.finish_release(r, handle.release());
            vm.state.scheduler.wake_all(WaitReason::Release(r));
        } else {
            assert!(!vm.state.scheduler.waiting.contains_key(&id));
            assert!(
                vm.state
                    .resources
                    .entries
                    .get(&resource)
                    .is_none_or(|entry| !entry.waiters.contains(&id))
            );
            assert_eq!(
                vm.state
                    .scheduler
                    .ready
                    .iter()
                    .filter(|&&x| x == id)
                    .count(),
                1
            );
        }
        let script = ScheduleHandle::new([ScheduleStep::PickTask(0)], false);
        vm.use_schedule(script.clone());
        vm.state.scheduling.switch = Some(Switch::Yield);
        assert_eq!(
            vm.run(services().runtime(ExecMode::Direct)),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert!(vm.heap.take_fault().is_none());
        drop(loan);
    }
}

// 関門: 全体停止中の子の終了は、待ち方の結果を配らず元の停止理由を保つ。
// 既存の停止テストは All を使うため、三つの待ち方で子が親より先に終わる退行を捕まえない。
#[test]
fn global_stop_does_not_deliver_cancelling_spawn_results_before_the_parent_finishes() {
    let mut actual = Vec::new();
    let mut expected = Vec::new();
    for (name, expression, order, first_fifo) in [
        (
            "allOk",
            "Task.allOk([lambda() pause(10000)\n return Result.Ok(1) end lambda, lambda() return Result.Ok(1 div 0) end lambda])",
            vec![1, 2],
            1,
        ),
        (
            "race",
            "Task.race([lambda() pause(10000)\n return 1 end lambda, lambda() return 1 div 0 end lambda])",
            vec![1, 2],
            1,
        ),
        (
            "withTimeout",
            "Task.all([lambda() bind _ <- Task.withTimeout(10, lambda() pause(10000)\n return 1 end lambda)\n return 1 end lambda, lambda() return 1 div 0 end lambda])",
            vec![1, 3, 2],
            3,
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.IO.Clock\n{PAUSE}\nfunction main() -> Unit uses Clock.Time, State\n bind _ <- {expression}\n return ()\nend function"
        );
        let program = compile(&source);
        let mut vm = Vm::new(
            &program,
            VmConfig {
                call_budget: 1000,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let script = ScheduleHandle::new(order.iter().copied().map(ScheduleStep::PickTask), false);
        vm.use_schedule(script.clone());
        let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let watched = std::sync::Arc::clone(&observed);
        let delivery = std::sync::Arc::new(std::sync::Mutex::new(None));
        let checked_delivery = std::sync::Arc::clone(&delivery);
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            if state.scheduling.stopping && !watched.load(std::sync::atomic::Ordering::Relaxed) {
                assert_eq!(
                    state.scheduler.ready.front().map(|task| task.index),
                    Some(first_fifo)
                );
                watched.store(true, std::sync::atomic::Ordering::Relaxed);
            }
            // cleanup の再試行は配送の Err を吸収するため、実際に終わった子を持つ親で
            // 配送の入口も検査する。子の状態や結果はテストで作らない（R39 の確認の観点）。
            if state.scheduling.stopping && checked_delivery.lock().unwrap().is_none() {
                let parent = state.tasks.entries.iter().find_map(|entry| {
                    let task = ctx.host::<TaskObj>(ctx.load(entry.task.as_ref()?))?;
                    let wait = task.spawn_wait.as_ref()?;
                    let mode_matches = match wait.mode {
                        SpawnMode::AllOk => name == "allOk",
                        SpawnMode::Race => name == "race",
                        SpawnMode::WithTimeout { .. } => name == "withTimeout",
                        SpawnMode::All | SpawnMode::GroupSpawn { .. } => false,
                    };
                    (mode_matches
                        && wait.children.iter().all(|slot| {
                            !matches!(
                                ctx.host::<TaskObj>(ctx.load(slot)).unwrap().result,
                                TaskResult::Pending
                            )
                        }))
                    .then_some(task.id)
                });
                if let Some(parent) = parent {
                    *checked_delivery.lock().unwrap() = Some(deliver_all(state, ctx, parent));
                }
            }
            Ok(())
        }));
        vm.start_main().unwrap();
        let VmStep::Stopped(end) = vm.run(services().runtime(ExecMode::Direct)) else {
            panic!("global stop did not finish: {name}")
        };
        let StopReason::Error(info) = end.reason else {
            panic!("not an error: {name}")
        };
        let record = script.record();
        assert_eq!(picks(&record), order);
        assert_eq!(record.remaining, 0);
        assert!(record.error.is_none(), "{name}: {record:?}");
        assert!(
            observed.load(std::sync::atomic::Ordering::Relaxed),
            "{name}"
        );
        assert!(vm.heap.take_fault().is_none());
        actual.push((
            name,
            info.stop,
            vm.state.tasks.live_count(),
            vm.state.meter.bytes(),
            vm.state.scheduling.stop_error.take(),
            delivery.lock().unwrap().take().unwrap(),
        ));
        expected.push((
            name,
            Stop::Runtime(RuntimeError::DivisionByZero),
            0,
            0,
            None,
            Ok(()),
        ));
    }
    assert_eq!(actual, expected);
}

// 関門: 既に辿っている区画と解放の失敗を全体の停止へ移し、子の終わりを待たない。
// R25 の DropRel × Release に加え、Cancel × HandleEnd / Release と DropRel × HandleEnd を守る。
#[test]
fn global_stop_escalates_cancel_and_drop_waits_and_keeps_prior_release_failures() {
    use crate::runtime::sched::ExtOpId;
    use crate::vm::frame::{HandleFrame, OtherFrame};
    use crate::vm::handler::{ContState, LazyState};
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};
    for (cause, release_wait) in [
        (UnwindCause::Cancel, false),
        (UnwindCause::DropRel, false),
        (UnwindCause::Cancel, true),
    ] {
        let source = format!(
            r#"{PAUSE}
function main() -> Unit
 bind _ <- Task.all([lambda() pause(10000)
  return 1
 end lambda,lambda() return 1 div 0 end lambda,lambda() pause(10000)
  return 3
 end lambda])
 return ()
end function"#
        );
        let program = compile(&source);
        let mut vm = Vm::new(
            &program,
            VmConfig {
                call_budget: 1000,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let script = ScheduleHandle::new([ScheduleStep::PickTask(2)], false);
        vm.use_schedule(script.clone());
        let events = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
        let recorded = std::sync::Arc::clone(&events);
        let mut installed = false;
        let observed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let watched = std::sync::Arc::clone(&observed);
        let work_script = script.clone();
        let mut scheduled = std::collections::BTreeSet::new();
        vm.state.scheduling.test_boundary = Some(Box::new(move |state, ctx| {
            if !installed {
                let value = ctx.load(state.tasks.entries[1].task.as_ref().unwrap());
                let id = ctx.host::<TaskObj>(value).unwrap().id;
                let waiter_value = ctx.load(state.tasks.entries[3].task.as_ref().unwrap());
                let waiter = ctx.host::<TaskObj>(waiter_value).unwrap().id;
                state.scheduler.ready.retain(|&t| t != id && t != waiter);
                state.scheduler.park(waiter, WaitReason::Lazy);
                ctx.host_mut::<TaskObj, _>(waiter_value, |task, _| {
                    task.state = TaskState::Waiting(WaitReason::Lazy)
                })
                .unwrap();
                let at = ctx.host::<TaskObj>(value).unwrap().stack.segments[0].calls[0]
                    .call_site
                    .unwrap();
                let mut ids = Vec::new();
                for name in ["outer", "inner"] {
                    ids.push(state.resources.insert(
                        crate::runtime::ResourceKind::FileWriter,
                        ResourceContent::Os(Some(Box::new(FakeResource {
                            name,
                            fail: true,
                            events: std::sync::Arc::clone(&recorded),
                        }))),
                        Some(at),
                    ));
                }
                let lazy = ctx.alloc_host(LazyState::Evaluating {
                    body: ctx.new_slot(Value::Unit),
                    by: id,
                    waiters: vec![waiter],
                });
                state.roots.push(ctx, lazy);
                let cont = ctx.alloc_host(ContState::Captured(vec![Segment {
                    others: vec![OtherFrame {
                        depth: 0,
                        kind: OtherKind::Update {
                            lazy: ctx.new_slot(lazy),
                            at,
                        },
                    }],
                    ..Segment::default()
                }]));
                let record = ctx.alloc_host(HandlerRecord {
                    clauses: vec![],
                    desc: crate::bytecode::program::HandlerIdx(0),
                    evaluated_by: id,
                    members: vec![waiter],
                    body_finished: true,
                });
                state.scheduling.member_positions.insert(waiter, 0);
                let reason = if release_wait {
                    WaitReason::Release(ids[1])
                } else {
                    WaitReason::TaskEnd(TaskEndWait::HandleEnd)
                };
                if release_wait {
                    assert!(matches!(
                        state.resources.request_release(ids[1], ExtOpId(100)),
                        crate::runtime::io::resources::ReleaseStart::Blocking
                    ));
                }
                state.scheduler.park(id, reason);
                let cont_slot = ctx.new_slot(cont);
                let record_slot = ctx.new_slot(record);
                ctx.host_mut::<TaskObj, _>(value, |task, _| {
                    let mut stack = std::mem::take(&mut task.stack);
                    let segment = stack.segments.last_mut().unwrap();
                    segment.others.push(OtherFrame {
                        depth: 1,
                        kind: OtherKind::Release {
                            resource: ids[0],
                            at,
                        },
                    });
                    segment.others.push(OtherFrame {
                        depth: 1,
                        kind: OtherKind::Drop { cont: cont_slot },
                    });
                    let handle = OtherFrame {
                        depth: 1,
                        kind: OtherKind::Handle(HandleFrame {
                            record: record_slot,
                            ret: 0,
                            at,
                        }),
                    };
                    let release = OtherFrame {
                        depth: 1,
                        kind: OtherKind::Release {
                            resource: ids[1],
                            at,
                        },
                    };
                    if release_wait {
                        segment.others.extend([handle, release]);
                    } else {
                        segment.others.extend([release, handle]);
                    }
                    task.state = TaskState::Unwinding(UnwindWork {
                        cause,
                        segments: stack.segments.into_iter().map(|s| (s, cause)).collect(),
                        waiting: Some(reason),
                        log: ReleaseLog {
                            failures: vec![crate::runtime::ReleaseFailure {
                                kind: crate::runtime::ResourceKind::FileWriter,
                                opened_at: Some(at),
                                reason: "earlier".into(),
                            }],
                        },
                    });
                })
                .unwrap();
                state.meter.grow(5, 0);
                installed = true;
            }
            if state.stopping.is_some() {
                for entry in &state.tasks.entries {
                    if let Some(slot) = &entry.task
                        && let Some(task) = ctx.host::<TaskObj>(ctx.load(slot))
                        && let TaskState::Unwinding(work) = &task.state
                    {
                        assert_eq!(work.cause, UnwindCause::Stop);
                        if release_wait
                            && !watched.load(std::sync::atomic::Ordering::Relaxed)
                            && task.id.index == 1
                            && matches!(work.waiting, Some(WaitReason::Release(_)))
                        {
                            assert_eq!(
                                state.scheduler.waiting.get(&task.id).unwrap().reason,
                                work.waiting.unwrap()
                            );
                        }
                    }
                }
                watched.store(true, std::sync::atomic::Ordering::Relaxed);
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
        vm.start_main().unwrap();
        let VmStep::Stopped(end) = vm.run(services().runtime(ExecMode::Direct)) else {
            panic!("global stop did not finish")
        };
        let StopReason::Error(info) = end.reason else {
            panic!("not error")
        };
        assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
        assert_eq!(
            end.release_failures
                .iter()
                .map(|f| f.reason.as_str())
                .collect::<Vec<_>>(),
            ["earlier", "inner", "outer"]
        );
        assert_eq!(*events.lock().unwrap(), ["inner", "outer"]);
        assert!(observed.load(std::sync::atomic::Ordering::Relaxed));
        assert_eq!(script.record().remaining, 0);
        assert_eq!(picks(&script.record()), [2]);
        assert!(script.record().error.is_none());
        assert_eq!(vm.state.meter.bytes(), 0);
        assert!(vm.heap.take_fault().is_none());
    }
}

fn instruction_site(program: &CompiledProgram, opcode: Opcode) -> InstrRef {
    for (proto, p) in program.protos.iter().enumerate() {
        if let Some(pc) = p.code.iter().position(|i| i.opcode() == Some(opcode)) {
            return InstrRef {
                proto: ProtoIdx(u32::try_from(proto).unwrap()),
                pc: u32::try_from(pc).unwrap(),
            };
        }
    }
    panic!("instruction not present")
}

// 関門: UnwindWork の区画は空の stack の上にある。全体を実行して、待つ HANDLE / USE と
// 呼び出しの並びを診断で確かめる。自然なスクリプトで作れない待ちの組み合わせは R39 の指示で組み立てる。
#[test]
fn deadlock_reports_unwinding_handle_and_group_frames_and_both_segment_stacks() {
    use crate::vm::frame::{HandleFrame, OtherFrame};
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};
    let source = PROBE.to_owned()
        + r#"
function main() -> Unit uses State
 bind _ <- handle
  with group = TaskGroup.open() do
   ask(0)
  end with
 with case ask(n) -> resume(n) end handle
 return ()
end function"#;
    let program = compile(&source);
    for cause in [UnwindCause::DropRel, UnwindCause::Cancel] {
        for handle in [true, false] {
            let mut vm = Vm::new(
                &program,
                VmConfig::default(),
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let site =
                instruction_site(&program, if handle { Opcode::Handle } else { Opcode::Use });
            vm.heap.epoch(|ctx| {
                let id = vm.state.current_task;
                let task = object(&vm.state, ctx, id).unwrap();
                let resource = vm.state.resources.insert(
                    crate::runtime::ResourceKind::TaskGroup,
                    ResourceContent::TaskGroup(vec![]),
                    Some(site),
                );
                let reason = WaitReason::TaskEnd(if handle {
                    TaskEndWait::HandleEnd
                } else {
                    TaskEndWait::TaskGroupRelease(resource)
                });
                let record = ctx.alloc_host(HandlerRecord {
                    clauses: vec![],
                    desc: crate::bytecode::program::HandlerIdx(0),
                    evaluated_by: id,
                    members: vec![],
                    body_finished: true,
                });
                let other = OtherFrame {
                    depth: 1,
                    kind: if handle {
                        OtherKind::Handle(HandleFrame {
                            record: ctx.new_slot(record),
                            ret: 0,
                            at: site,
                        })
                    } else {
                        OtherKind::Release { resource, at: site }
                    },
                };
                let mut stack = std::mem::take(&mut vm.state.stack);
                stack.segments.last_mut().unwrap().others.push(other);
                vm.state.meter.grow(2, 0);
                let lower = Segment {
                    calls: vec![CallFrame {
                        func: Slot::default(),
                        proto: program.main.unwrap(),
                        pc: 0,
                        base: 0,
                        size: 0,
                        ret: None,
                        call_site: Some(site),
                        boundary: true,
                        chain_resume: None,
                    }],
                    ..Segment::default()
                };
                ctx.host_mut::<TaskObj, _>(task, |task, _| {
                    task.stack.segments.push(lower);
                    task.state = TaskState::Unwinding(UnwindWork {
                        cause,
                        segments: stack.segments.into_iter().map(|s| (s, cause)).collect(),
                        waiting: Some(reason),
                        log: ReleaseLog::default(),
                    });
                })
                .unwrap();
                vm.state.scheduling.active = false;
                vm.state.scheduling.switch = Some(Switch::Done);
                vm.state.scheduler.park(id, reason);
            });
            vm.heap.collect(&vm.state);
            let VmStep::Stopped(end) = vm.run(services().runtime(ExecMode::Direct)) else {
                panic!("deadlock did not stop")
            };
            let StopReason::Error(info) = end.reason else {
                panic!("not error")
            };
            assert_eq!(info.stop, Stop::Runtime(RuntimeError::TaskDeadlock));
            assert_eq!(info.deadlock.len(), 1);
            assert_eq!(info.deadlock[0].at, site);
            assert_eq!(
                info.deadlock[0].kind,
                if handle {
                    DeadlockWaitKind::HandleEnd
                } else {
                    DeadlockWaitKind::TaskGroupRelease
                }
            );
            assert_eq!(info.deadlock[0].call_sites, [None, Some(site)]);
            assert_eq!(vm.state.meter.bytes(), 0);
            assert!(vm.heap.take_fault().is_none());
        }
    }
}

// 関門: Spawned の待つ種類は AllOk と Race で異なる。All の行き詰まりでは見つからない。
#[test]
fn deadlock_names_the_cancelling_wait_mode() {
    for (mode, returned) in [("allOk", "Result.Ok(())"), ("race", "()")] {
        let source = format!(
            r#"import Benitoite.Unofficial.IO.Clock
function main() -> Unit uses State, Clock.Time
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
  bind _ <- Task.{mode}([lambda()
   Task.await(ta)
   return {returned}
  end lambda])
 end with
 return ()
end function"#
        );
        let (step, record) = run(
            &source,
            1000,
            vec![
                ScheduleStep::PickTask(2),
                ScheduleStep::PickTask(1),
                ScheduleStep::PickTask(3),
            ],
        );
        let VmStep::Stopped(end) = step else {
            panic!("not stopped")
        };
        let StopReason::Error(info) = end.reason else {
            panic!("not error")
        };
        assert_eq!(info.stop, Stop::Runtime(RuntimeError::TaskDeadlock));
        assert_eq!(
            info.deadlock[0].kind,
            DeadlockWaitKind::Builtin(if mode == "allOk" {
                "Task.allOk"
            } else {
                "Task.race"
            })
        );
        assert_eq!(picks(&record), [2, 1, 3]);
    }
}

// 関門: resume しない節の終了は、handle の本体で起動したタスクも取り消して待つ（01-11）。
#[test]
fn a_non_resuming_clause_cancels_handler_members_before_returning() {
    let source = format!(
        r#"{PROBE}
{PAUSE}
function main() -> Result[Unit, String] uses State
 bind changed <- Reference.new(false)
 with group = TaskGroup.open() do
  bind result <- handle
   bind _ <- TaskGroup.spawn(group,lambda()
    pause(10000)
    Reference.set(changed,true)
    return ()
   end lambda)
   ask(0)
  with case ask(n) -> 42 end handle
  if result = 42 and not Reference.get(changed) then return Result.Ok(()) else return Result.Error("handle cancellation") end if
 end with
end function"#
    );
    for budget in [1, 1000] {
        let steps = if budget == 1000 {
            vec![ScheduleStep::PickTask(1), ScheduleStep::PickTask(0)]
        } else {
            vec![]
        };
        let (step, record) = run(&source, budget, steps);
        assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
        if budget == 1000 {
            assert_eq!(picks(&record), [1, 0]);
        }
    }
}

// 関門: 終わった子の TaskResult の文字列は SpawnWait だけから、解放待ちの文字列は
// UnwindWork だけから辿れる。回収後に VM が配送・取り消しを完了して正しい値を返す。
#[test]
fn collection_preserves_spawn_results_and_unwind_segments_while_cancellation_waits_for_release() {
    use crate::runtime::sched::ExtOpId;
    use crate::vm::frame::OtherFrame;
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};
    let source = r#"import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit, String] uses Clock.Time, State
 bind result <- Task.race([lambda() return "ignored" end lambda])
 if result = Option.Some("winner kept") then return Result.Ok(()) else return Result.Error("root") end if
end function"#;
    let program = compile(source);
    let at = instruction_site(&program, Opcode::Prim);
    let instruction = program.proto(at.proto).unwrap().code[at.pc as usize];
    assert_eq!(
        builtin_decl(
            program
                .builtin(BuiltinRefIdx(u32::from(instruction.b())))
                .unwrap()
                .id
        )
        .unwrap()
        .name,
        "Task.race"
    );
    let mut vm = Vm::new(
        &program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let events = std::sync::Arc::new(std::sync::Mutex::new(vec![]));
    let (child, resource) = vm.heap.epoch(|ctx| {
        let parent = vm.state.current_task;
        let resource = vm.state.resources.insert(
            crate::runtime::ResourceKind::FileWriter,
            ResourceContent::Os(Some(Box::new(FakeResource {
                name: "blocked",
                fail: false,
                events: std::sync::Arc::clone(&events),
            }))),
            Some(at),
        );
        assert!(matches!(
            vm.state.resources.request_release(resource, ExtOpId(1)),
            crate::runtime::io::resources::ReleaseStart::Blocking
        ));
        let winner_text = ctx.alloc_str("winner kept", "test").unwrap();
        let mut winner = empty_task(
            TaskId {
                index: 99,
                generation: 0,
            },
            1,
        );
        winner.state = TaskState::Done;
        winner.result = TaskResult::Value(ctx.new_slot(winner_text));
        let winner = ctx.alloc_host(winner);
        let root = ctx.alloc_str("unwind root", "test").unwrap();
        let mut child_value = Value::Unit;
        let child = vm.state.tasks.insert(ctx, |id| {
            let mut task = empty_task(id, 1);
            task.cancel_requested = true;
            task.spawner = Some((parent, at));
            task.state = TaskState::Unwinding(UnwindWork {
                cause: UnwindCause::Cancel,
                segments: vec![(
                    Segment {
                        regs: vec![ctx.new_slot(root)],
                        calls: vec![CallFrame {
                            func: Slot::default(),
                            proto: at.proto,
                            pc: at.pc,
                            base: 0,
                            size: 1,
                            ret: None,
                            call_site: Some(at),
                            boundary: true,
                            chain_resume: None,
                        }],
                        others: vec![OtherFrame {
                            depth: 1,
                            kind: OtherKind::Release { resource, at },
                        }],
                    },
                    UnwindCause::Cancel,
                )],
                waiting: Some(WaitReason::Release(resource)),
                log: ReleaseLog::default(),
            });
            child_value = ctx.alloc_host(task);
            child_value
        });
        vm.state.meter.grow(2, 1);
        vm.state
            .stack
            .segments
            .last_mut()
            .unwrap()
            .calls
            .last_mut()
            .unwrap()
            .pc = at.pc;
        let stack = std::mem::take(&mut vm.state.stack);
        let children = vec![ctx.new_slot(winner), ctx.new_slot(child_value)];
        ctx.host_mut::<TaskObj, _>(object(&vm.state, ctx, parent).unwrap(), |task, _| {
            task.stack = stack;
            task.state = TaskState::Waiting(WaitReason::TaskEnd(TaskEndWait::Spawned));
            task.spawn_wait = Some(SpawnWait {
                mode: SpawnMode::Race,
                children,
                timer: None,
            });
            task.spawned.push(child);
        })
        .unwrap();
        vm.state.scheduling.child_positions.insert(child, 0);
        vm.state.scheduling.active = false;
        vm.state.scheduling.switch = Some(Switch::Done);
        vm.state
            .scheduling
            .deliveries
            .insert(parent, instruction.a());
        vm.state
            .scheduler
            .park(parent, WaitReason::TaskEnd(TaskEndWait::Spawned));
        vm.state
            .scheduler
            .park(child, WaitReason::Release(resource));
        (child, resource)
    });
    vm.heap.collect(&vm.state);
    vm.heap.epoch(|ctx| {
        let task = ctx
            .host::<TaskObj>(object(&vm.state, ctx, child).unwrap())
            .unwrap();
        let TaskState::Unwinding(work) = &task.state else {
            panic!("not unwinding")
        };
        assert_eq!(
            ctx.str(ctx.load(&work.segments[0].0.regs[0])),
            Some("unwind root")
        );
        let parent = ctx
            .host::<TaskObj>(object(&vm.state, ctx, vm.state.current_task).unwrap())
            .unwrap();
        let winner = ctx
            .host::<TaskObj>(ctx.load(&parent.spawn_wait.as_ref().unwrap().children[0]))
            .unwrap();
        let TaskResult::Value(slot) = &winner.result else {
            panic!("winner result missing")
        };
        assert_eq!(ctx.str(ctx.load(slot)), Some("winner kept"));
    });
    let (id, _, handle) = vm.state.resources.take_release_job().unwrap();
    assert_eq!(id, resource);
    vm.state.resources.finish_release(id, handle.release());
    vm.state.scheduler.wake_all(WaitReason::Release(id));
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(*events.lock().unwrap(), ["blocked"]);
    assert_eq!(vm.state.tasks.live_count(), 0);
    assert_eq!(vm.state.meter.bytes(), 0);
    assert!(vm.heap.take_fault().is_none());
}
