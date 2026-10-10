//! 取り消しの要求・辿りへの移行と、取り消しを伴う待ち方（設計書 02-08「取り消し」）。

use super::*;
use crate::runtime::sched::TimerId;
use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};

/// 呼び出し元のタスクは対象に含めない。子の待ちの入れ子は Rust の再帰を使わず辿る（設計書 02-08）。
#[cold]
#[inline(never)]
pub(in crate::vm) fn request(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    ids: &[TaskId],
) -> Result<(), Stop> {
    let mut pending = ids.to_vec();
    while let Some(id) = pending.pop() {
        let Some(value) = state.tasks.get(ctx, id) else {
            continue;
        };
        let task = ctx
            .host::<TaskObj>(value)
            .ok_or_else(|| missing("cancelling task missing"))?;
        if task.cancel_requested
            || matches!(&task.state, TaskState::Unwinding(w) if matches!(w.cause, UnwindCause::Cancel | UnwindCause::Stop))
        {
            continue;
        }
        if id == state.current_task && state.scheduling.active {
            return Err(missing("cannot cancel the running task"));
        }
        let reason = state.scheduler.waiting.get(&id).map(|w| w.reason);
        let spawned = reason == Some(WaitReason::TaskEnd(TaskEndWait::Spawned));
        if spawned && task.spawn_wait.is_none() {
            return Err(missing("spawned wait without children"));
        }
        let (children, timer) = if spawned {
            let wait = task
                .spawn_wait
                .as_ref()
                .ok_or_else(|| missing("spawn wait missing"))?;
            (pending_children(ctx, wait)?, wait.timer)
        } else {
            (Vec::new(), None)
        };
        state.scheduling.cancelled_io.push(id);
        ctx.host_mut::<TaskObj, _>(value, |task, _| {
            task.cancel_requested = true;
            task.budget.interrupt();
        })
        .ok_or_else(|| missing("cancelling task missing"))?;
        if spawned {
            state.scheduling.deliveries.remove(&id);
            remove_timer(state, id, timer);
            pending.extend(children);
            // 子が既に全員終わっている場合も、結果を書かず親を起こす（実装プラン R39）。
            discard_cancelled_parent(state, ctx, id)?;
        } else if !matches!(reason, Some(WaitReason::Release(_))) {
            if let Some(WaitReason::TaskEnd(TaskEndWait::Await(target))) = reason
                && let Some(target) = state.tasks.get(ctx, target)
            {
                ctx.host_mut::<TaskObj, _>(target, |task, _| {
                    task.awaiters.retain(|&waiter| waiter != id)
                })
                .ok_or_else(|| missing("awaited task missing"))?;
            }
            state.scheduler.remove_task_timers(id);
            state.scheduler.wake(id);
            state.resources.remove_waiter(id);
        }
    }
    Ok(())
}

fn pending_children(ctx: &NoGcCtx<'_>, wait: &SpawnWait) -> Result<Vec<TaskId>, Stop> {
    wait.children
        .iter()
        .filter_map(|slot| match ctx.host::<TaskObj>(ctx.load(slot)) {
            Some(task) if matches!(task.result, TaskResult::Pending) => Some(Ok(task.id)),
            Some(_) => None,
            None => Some(Err(missing("spawn child missing"))),
        })
        .collect()
}

fn remove_timer(state: &mut RunState, parent: TaskId, timer: Option<TimerId>) {
    if let Some(timer) = timer {
        state.scheduler.remove_timer(timer);
    }
    state.scheduling.timed_out.remove(&parent);
}

/// 選ばれたタスクの命令を実行する前に、要求を辿りへ移す（実装プラン R39）。
#[cold]
#[inline(never)]
pub(super) fn begin(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> Result<(), Stop> {
    if !checked_requested(ctx, state)? || state.unwinding.is_some() {
        return Ok(());
    }
    let value = object(state, ctx, state.current_task)?;
    if ctx
        .host::<TaskObj>(value)
        .is_some_and(|t| t.spawn_wait.is_some())
    {
        return Err(missing(
            "cancelled parent selected before children finished",
        ));
    }
    ctx.discard(state.returning.take());
    state.precall_done = None;
    state.unwinding = Some(UnwindWork {
        cause: UnwindCause::Cancel,
        segments: std::mem::take(&mut state.stack)
            .segments
            .into_iter()
            .map(|s| (s, UnwindCause::Cancel))
            .collect(),
        waiting: None,
        log: ReleaseLog::default(),
    });
    Ok(())
}

/// 凍結した bool の入口の前に、タスクの対象を引けることを確かめる（実装プラン R39）。
#[cold]
#[inline(never)]
pub(in crate::vm) fn checked_requested(ctx: &NoGcCtx<'_>, state: &RunState) -> Result<bool, Stop> {
    let value = object(state, ctx, state.current_task)?;
    ctx.host::<TaskObj>(value)
        .map(|t| t.cancel_requested)
        .ok_or_else(|| missing("task object missing"))
}

/// handle の記録の借用を終えてから、属するタスクへ要求を出す（設計書 02-08「枠を降ろす原因と処理」）。
#[cold]
#[inline(never)]
pub(in crate::vm) fn handle_members(
    ctx: &mut NoGcCtx<'_>,
    state: &mut RunState,
    at: TaskId,
    frame: &crate::vm::frame::HandleFrame,
) -> Result<(), Stop> {
    let ids: Vec<_> = ctx
        .host::<HandlerRecord>(ctx.load(&frame.record))
        .ok_or_else(|| missing("handler record required"))?
        .members
        .iter()
        .copied()
        .filter(|&id| id != at)
        .collect();
    request(state, ctx, &ids)
}

#[cold]
#[inline(never)]
pub(in crate::vm::dispatch) fn finish(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
) -> Result<Control, Stop> {
    finish_task(state, ctx, None)?;
    Ok(Control::Return)
}

// 結果だけが子の Task の値に残っている間も、SpawnWait が所有を続ける。
#[cold]
#[inline(never)]
pub(super) fn discard_cancelled_parent(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    parent: TaskId,
) -> Result<(), Stop> {
    let value = object(state, ctx, parent)?;
    let task = ctx
        .host::<TaskObj>(value)
        .ok_or_else(|| missing("spawner object missing"))?;
    let Some(wait) = &task.spawn_wait else {
        return Ok(());
    };
    if !pending_children(ctx, wait)?.is_empty() {
        return Ok(());
    }
    let timer = wait.timer;
    ctx.host_mut::<TaskObj, _>(value, |task, slots| {
        if let Some(wait) = task.spawn_wait.take() {
            slots.discard(wait.children);
        }
    })
    .ok_or_else(|| missing("spawner object missing"))?;
    remove_timer(state, parent, timer);
    state.scheduling.deliveries.remove(&parent);
    state
        .scheduler
        .wake_if(parent, WaitReason::TaskEnd(TaskEndWait::Spawned));
    Ok(())
}

/// 満了した番号を今の待ちと照合し、子の停止が済むまで親を待たせる（実装プラン R39）。
#[cold]
#[inline(never)]
pub(super) fn expire(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    parent: TaskId,
    timer: TimerId,
) -> Result<bool, Stop> {
    let Some(value) = state.tasks.get(ctx, parent) else {
        return Ok(false);
    };
    let task = ctx
        .host::<TaskObj>(value)
        .ok_or_else(|| missing("timer task missing"))?;
    let Some(wait) = &task.spawn_wait else {
        return Ok(false);
    };
    if wait.timer != Some(timer) || task.cancel_requested {
        return Ok(false);
    }
    if !matches!(wait.mode, SpawnMode::WithTimeout { .. }) {
        return Err(missing("spawn timer without timeout"));
    }
    let ids = pending_children(ctx, wait)?;
    state.scheduling.timed_out.insert(parent);
    request(state, ctx, &ids)?;
    deliver_all(state, ctx, parent)?;
    Ok(true)
}

/// 結果を決める前に、結果に影響しない未完了の子だけを取り消す（設計書 02-08「タスクの起動と待ち方」）。
#[cold]
#[inline(never)]
pub(super) fn deliver<'e>(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    parent: TaskId,
) -> Result<(), Stop> {
    let value = object(state, ctx, parent)?;
    let task = ctx
        .host::<TaskObj>(value)
        .ok_or_else(|| missing("spawner object missing"))?;
    let wait = task
        .spawn_wait
        .as_ref()
        .ok_or_else(|| missing("spawn wait missing"))?;
    let mode = wait.mode;
    let timer = wait.timer;
    let mut results = Vec::new();
    for slot in &wait.children {
        let child = ctx
            .host::<TaskObj>(ctx.load(slot))
            .ok_or_else(|| missing("spawn child missing"))?;
        results.push((
            child.id,
            match &child.result {
                TaskResult::Pending => None,
                TaskResult::Value(slot) => Some(Some(ctx.load(slot))),
                TaskResult::Cancelled => Some(None),
            },
        ));
    }
    let mut cancel_ids = Vec::new();
    let mut oks = Vec::new();
    let mut error = None;
    match mode {
        SpawnMode::AllOk => {
            for (id, result) in &results {
                if error.is_some() {
                    if result.is_none() {
                        cancel_ids.push(*id);
                    }
                    continue;
                }
                if let Some(Some(result)) = result {
                    match ctx.fields_header(*result) {
                        Some((FieldsKind::Ctor, tags::RESULT_ERROR)) => error = Some(*result),
                        Some((FieldsKind::Ctor, tags::RESULT_OK)) => oks.push(
                            ctx.field(*result, 0)
                                .ok_or_else(|| missing("Result.Ok payload missing"))?,
                        ),
                        _ => return Err(missing("Task.allOk requires Result values")),
                    }
                }
            }
        }
        SpawnMode::Race => {
            // finish_task が最初の完了と同じ区間でここを呼び、ほかの未完了の子へ要求を出す。
            // 以後の子は Cancelled で終わるため、勝った Value は一つだけ残る（設計書 01-11）。
            if results.iter().any(|(_, r)| matches!(r, Some(Some(_)))) {
                cancel_ids.extend(
                    results
                        .iter()
                        .filter_map(|(id, r)| r.is_none().then_some(*id)),
                );
            }
        }
        SpawnMode::WithTimeout { .. } => {
            if state.scheduling.timed_out.contains(&parent) {
                cancel_ids.extend(
                    results
                        .iter()
                        .filter_map(|(id, r)| r.is_none().then_some(*id)),
                );
            }
        }
        SpawnMode::All | SpawnMode::GroupSpawn { .. } => {
            return Err(missing("invalid cancelling wait mode"));
        }
    }
    request(state, ctx, &cancel_ids)?;
    if results.iter().any(|(_, r)| r.is_none()) {
        return Ok(());
    }
    let result = match mode {
        SpawnMode::AllOk => {
            if let Some(error) = error {
                error
            } else {
                // AllOk が子を取り消すのは Error を得た後だけで、その Error は children に残る。
                // 親の取り消しと全体停止は deliver_all が先に除くため、ここでは Error が必要である
                // （設計書 01-11「タスクを起動する関数」、実装プラン R39）。
                if results.iter().any(|(_, r)| matches!(r, Some(None))) {
                    return Err(missing("Task.allOk child cancelled without error"));
                }
                let list = list::from_values(ctx, &oks, "Task.allOk")?;
                ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[list])?
            }
        }
        SpawnMode::Race | SpawnMode::WithTimeout { .. } => {
            if state.scheduling.timed_out.contains(&parent) {
                Value::Tag(CtorTag(tags::OPTION_NONE))
            } else {
                // Race は勝者を得てからほかの子を取り消し、WithTimeout の取り消しは timed_out を記録する。
                // 親の取り消しと全体停止は既に除かれているので、この分岐には勝者が残る
                // （設計書 01-11「タスクを起動する関数」、実装プラン R39）。
                let result = results
                    .iter()
                    .find_map(|(_, r)| r.and_then(|v| v))
                    .ok_or_else(|| missing("winning task result missing"))?;
                ctx.alloc_fields(FieldsKind::Ctor, tags::OPTION_SOME, &[result])?
            }
        }
        SpawnMode::All | SpawnMode::GroupSpawn { .. } => {
            return Err(missing("invalid cancelling wait mode"));
        }
    };
    // 子の結果をそのまま返す Error と、即値の None は確保しない。
    let allocated = match mode {
        SpawnMode::AllOk => error.is_none(),
        SpawnMode::Race => true,
        SpawnMode::WithTimeout { .. } => !state.scheduling.timed_out.contains(&parent),
        SpawnMode::All | SpawnMode::GroupSpawn { .. } => false,
    };
    remove_timer(state, parent, timer);
    write_result(state, ctx, parent, value, result)?;
    if allocated {
        notify_collect(state, ctx);
    }
    Ok(())
}

fn write_result<'e>(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    parent: TaskId,
    value: Value<'e>,
    result: Value<'e>,
) -> Result<(), Stop> {
    let dest = state
        .scheduling
        .deliveries
        .remove(&parent)
        .ok_or_else(|| missing("spawn destination missing"))?;
    ctx.host_mut::<TaskObj, _>(value, |task, slots| -> Result<(), Stop> {
        let segment = task
            .stack
            .segments
            .last_mut()
            .ok_or_else(|| missing("spawner segment missing"))?;
        let frame = segment
            .calls
            .last_mut()
            .ok_or_else(|| missing("spawner frame missing"))?;
        let reg = frame
            .base
            .checked_add(u32::from(dest))
            .ok_or_else(|| missing("spawn result overflow"))?;
        slots.store(
            segment
                .regs
                .get_mut(index(reg)?)
                .ok_or_else(|| missing("spawn result register missing"))?,
            result,
        );
        frame.pc = frame
            .pc
            .checked_add(1)
            .ok_or_else(|| missing("spawn pc overflow"))?;
        let wait = task
            .spawn_wait
            .take()
            .ok_or_else(|| missing("spawn wait missing"))?;
        slots.discard(wait.children);
        Ok(())
    })
    .ok_or_else(|| missing("spawner object missing"))??;
    state
        .scheduler
        .wake_if(parent, WaitReason::TaskEnd(TaskEndWait::Spawned));
    Ok(())
}
