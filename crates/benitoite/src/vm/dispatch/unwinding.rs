//! 継続の破棄・取り消し・停止の共通の辿りと ESCAPE（設計書 02-08「枠を降ろす原因と処理」「止める手順」）。

use super::*;
use crate::vm::frame::{FrameAt, OtherKind, Segment};
use crate::vm::unwind::{
    self, ReleaseLog, ReturnDest, ReturnStage, ReturnWork, UnwindCause, UnwindStep, UnwindWork,
};

#[cold]
#[inline(never)]
pub(super) fn resume(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    interrupt: Option<&AtomicBool>,
) -> Option<LoopExit> {
    // 命令の局所を読む前に辿りを再開する。戻りへの接続も一つの冷たい呼び出しに閉じる（実装プラン R21）。
    handlers::resume_return(program, state, ctx, interrupt)
}

pub(super) fn begin_traverse(state: &mut RunState, segments: Vec<Segment>, cause: UnwindCause) {
    state.unwinding = Some(UnwindWork {
        cause,
        segments: segments
            .into_iter()
            .map(|segment| (segment, cause))
            .collect(),
        waiting: None,
        log: ReleaseLog::default(),
    });
}

#[cold]
#[inline(never)]
pub(super) fn begin_escape(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    cursor.locals.save(state.frame_mut()?);
    let value = read_one(
        ctx,
        active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
        instr.a(),
    )?;
    state.returning = Some(ReturnWork {
        value: ctx.new_slot(value),
        dest: ReturnDest::Pending,
        stage: ReturnStage::Escaping,
        at: InstrRef {
            proto: cursor.locals.proto,
            pc: cursor.locals.pc,
        },
    });
    handlers::continue_return(program, state, ctx, cursor.interrupt)
}

// 同じ Segment::top_frame を使い、関数の境界だけで戻りの段へ移る（02-08「実行の手順」）。
#[cold]
#[inline(never)]
pub(super) fn escape_one(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> Result<Control, Stop> {
    match state.segment()?.top_frame() {
        Some(FrameAt::Call(_)) => {
            let call = state.frame()?;
            let boundary = call.boundary;
            let dest = if let Some(reg) = call.ret {
                ReturnDest::Reg {
                    segment: u32::try_from(state.stack.segments.len().saturating_sub(1))
                        .map_err(|_| missing("escape segment overflow"))?,
                    reg,
                }
            } else if state.stack.segments.len() == 1 {
                ReturnDest::TaskResult
            } else {
                ReturnDest::Pending
            };
            pop_call(state, ctx)?;
            if boundary {
                let work = state
                    .returning
                    .as_mut()
                    .ok_or_else(|| missing("escape work missing"))?;
                work.stage = ReturnStage::Wrapping;
                work.dest = dest;
            }
        }
        Some(FrameAt::Other(_)) => match handlers::unwind_top(state, ctx)? {
            UnwindStep::Popped => {}
            UnwindStep::Traverse { segments, cause } => {
                begin_traverse(state, segments, cause);
            }
            UnwindStep::Wait(reason) => return tasks::park(state, reason),
            UnwindStep::Retry => return Err(missing("escape retry is invalid")),
        },
        None => {
            if let Some(segment) = state.stack.segments.pop() {
                ctx.discard(segment);
            }
            if state.stack.segments.is_empty() {
                return Err(missing("escape has no function boundary"));
            }
        }
    }
    Ok(if ctx.collect_requested() {
        Control::Collect
    } else {
        Control::Reload
    })
}

fn pop_traversed_call(
    segment: &mut Segment,
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
) -> Result<(), Stop> {
    let call = segment
        .calls
        .pop()
        .ok_or_else(|| missing("unwind call missing"))?;
    let range = index(call.base).and_then(|base| {
        let end = call
            .base
            .checked_add(call.size)
            .ok_or_else(|| missing("unwind window overflow"))?;
        Ok(base..index(end)?)
    });
    let valid = if let Ok(range) = &range {
        if let Some(window) = segment.regs.get_mut(range.clone()) {
            for slot in window {
                ctx.clear(slot);
            }
            segment.regs.truncate(range.start);
            true
        } else {
            false
        }
    } else {
        false
    };
    state.meter.shrink(1, u64::from(call.size));
    ctx.discard(call);
    if valid {
        Ok(())
    } else {
        Err(missing("unwind window missing"))
    }
}

// 取り出すのはこの一歩の間だけであり、回収・待ちの出口より前に必ず RunState へ戻す。
// Rust の再帰を使わず、入れ子の継続も work.segments の末尾で先に処理する（ADR 0262）。
#[cold]
#[inline(never)]
fn advance(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> Result<bool, Stop> {
    let mut work = state
        .unwinding
        .take()
        .ok_or_else(|| missing("unwind work missing"))?;
    let result = advance_work(&mut work, state, ctx);
    state.unwinding = Some(work);
    result
}

// 位置を選ぶ部分と枠の種類ごとの処理を分ける（ADR 0262 の決定 4）。
fn next_frame(work: &UnwindWork) -> Option<FrameAt> {
    work.segments
        .last()
        .and_then(|(segment, _)| segment.top_frame())
}

fn advance_work(
    work: &mut UnwindWork,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
) -> Result<bool, Stop> {
    let position = next_frame(work);
    let Some((segment, cause)) = work.segments.last_mut() else {
        return Ok(true);
    };
    let cause = *cause;
    match position {
        Some(FrameAt::Call(_)) => pop_traversed_call(segment, state, ctx)?,
        Some(FrameAt::Other(_)) => {
            let other = segment
                .others
                .pop()
                .ok_or_else(|| missing("unwind wrapping frame missing"))?;
            let at = state.current_task;
            let result = match &other.kind {
                OtherKind::Handle(h) => unwind::unwind_handle(ctx, state, at, h, cause),
                OtherKind::Drop { cont } => unwind::unwind_drop(ctx, state, at, cont, cause),
                OtherKind::Release {
                    resource,
                    at: opened,
                } => {
                    unwind::unwind_release(ctx, state, at, *resource, *opened, cause, &mut work.log)
                }
                OtherKind::Update { lazy, .. } => {
                    unwind::unwind_update(ctx, state, at, lazy, cause)
                }
                OtherKind::CellUpdate(c) => unwind::unwind_cell_update(ctx, state, at, c, cause),
            };
            let step = match result {
                Ok(step) => step,
                Err(stop) if cause == UnwindCause::Stop => {
                    // 元の停止理由を保つ。不具合の説明は StopEnd に置けない（実装プラン R21）。
                    if let Stop::Runtime(RuntimeError::ReleaseFailed(failures)) = stop {
                        work.log.failures.extend(failures);
                    }
                    UnwindStep::Popped
                }
                Err(stop) => {
                    segment.others.push(other);
                    return Err(stop);
                }
            };
            match step {
                UnwindStep::Popped => {
                    ctx.discard(other);
                    state.meter.shrink(1, 0);
                }
                UnwindStep::Traverse { segments, cause } => {
                    ctx.discard(other);
                    state.meter.shrink(1, 0);
                    work.segments
                        .extend(segments.into_iter().map(|segment| (segment, cause)));
                }
                UnwindStep::Wait(reason) => {
                    segment.others.push(other);
                    work.waiting = Some(reason);
                }
                UnwindStep::Retry => {
                    if cause == UnwindCause::Stop {
                        ctx.discard(other);
                        state.meter.shrink(1, 0);
                    } else {
                        segment.others.push(other);
                    }
                    return Err(missing("retry while traversing frames"));
                }
            }
        }
        None => {
            if let Some((segment, _)) = work.segments.pop() {
                // 枠ごとに計数を減らし終えた空の区画を除き、一つ下の区画へ進む（実装プラン R21）。
                ctx.discard(segment);
            }
        }
    }
    Ok(false)
}

#[cold]
#[inline(never)]
pub(super) fn traverse(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> Result<Control, Stop> {
    loop {
        if state
            .unwinding
            .as_ref()
            .is_some_and(|work| work.waiting.is_some())
        {
            let reason = state
                .unwinding
                .as_ref()
                .and_then(|w| w.waiting)
                .ok_or_else(|| missing("unwind wait missing"))?;
            return tasks::park(state, reason);
        }
        let complete = advance(state, ctx)?;
        if complete {
            let work = state
                .unwinding
                .as_mut()
                .ok_or_else(|| missing("unwind work missing"))?;
            if work.cause != UnwindCause::Stop && !work.log.failures.is_empty() {
                return Err(Stop::Runtime(RuntimeError::ReleaseFailed(std::mem::take(
                    &mut work.log.failures,
                ))));
            }
            match work.cause {
                UnwindCause::DropRel => {
                    tasks::cancel::checked_requested(ctx, state)?;
                    if unwind::cancel_requested(ctx, state) {
                        if let Some(work) = state.returning.take() {
                            ctx.discard(work);
                        }
                        let rest = std::mem::take(&mut state.stack);
                        state
                            .unwinding
                            .as_mut()
                            .ok_or_else(|| missing("unwind work missing"))?
                            .escalate(rest, UnwindCause::Cancel);
                        continue;
                    }
                    state.unwinding = None;
                    return Ok(Control::Reload);
                }
                UnwindCause::Stop => {
                    let failures = std::mem::take(&mut work.log.failures);
                    state.unwinding = None;
                    return tasks::finish_stop(state, ctx, failures);
                }
                UnwindCause::Cancel => {
                    state.unwinding = None;
                    return tasks::cancel::finish(state, ctx);
                }
                UnwindCause::Return => return Err(missing("return cause in unwind work")),
            }
        }
        if state
            .unwinding
            .as_ref()
            .is_some_and(|work| work.waiting.is_some())
        {
            continue;
        }
        if ctx.collect_requested() {
            return Ok(Control::Collect);
        }
    }
}

#[cold]
#[inline(never)]
fn begin_stop(state: &mut RunState, ctx: &NoGcCtx<'_>, reason: StopReason) {
    state.stopping = Some(reason);
    state.precall_done = None;
    if let Some(work) = state.returning.take() {
        ctx.discard(work);
    }
    ctx.discard(std::mem::take(&mut state.inherited));
    let rest = std::mem::take(&mut state.stack);
    if let Some(work) = &mut state.unwinding {
        work.escalate(rest, UnwindCause::Stop);
    } else {
        begin_traverse(state, rest.segments, UnwindCause::Stop);
    }
}

#[cold]
#[inline(never)]
pub(super) fn cleanup(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> LoopExit {
    if state
        .unwinding
        .as_ref()
        .is_none_or(|work| work.cause != UnwindCause::Stop)
        && let Some(reason) = state.stopping.take()
    {
        state.stopping = Some(reason);
        if let Err(stop) = tasks::begin_stop_all(state, ctx) {
            state.fail(stop, None);
        }
        if state.unwinding.is_none()
            && let Some(reason) = state.stopping.take()
        {
            begin_stop(state, ctx, reason);
        }
    }
    loop {
        let before = state.unwinding.as_ref().map(|w| {
            (
                w.segments.len(),
                w.segments.iter().map(|(s, _)| s.frame_count()).sum::<u64>(),
            )
        });
        match traverse(state, ctx) {
            Ok(Control::Collect) => return LoopExit::Collect,
            Ok(Control::Return) => return LoopExit::Return,
            Ok(_) => return LoopExit::Return,
            Err(_) => {
                let after = state.unwinding.as_ref().map(|w| {
                    (
                        w.segments.len(),
                        w.segments.iter().map(|(s, _)| s.frame_count()).sum::<u64>(),
                    )
                });
                if before == after {
                    if let Some(work) = state.unwinding.as_mut()
                        && let Some((segment, _)) = work.segments.pop()
                    {
                        state
                            .meter
                            .shrink(segment.frame_count(), segment.reg_count());
                        ctx.discard(segment);
                    } else {
                        // 進む枠も辿りも失った不整合では、同じ Err を繰り返さず終える
                        // （実装プラン R25「cleanup の抜ける条件」）。
                        let failures = state
                            .unwinding
                            .take()
                            .map_or_else(Vec::new, |work| work.log.failures);
                        if let Err(stop) = tasks::finish_stop(state, ctx, failures) {
                            state.fail(stop, None);
                        }
                        return LoopExit::Return;
                    }
                }
                // 不整合な呼び出しも advance が所有を手放した後に失敗を返すので、残りの枠へ進める。
                // 停止中に起きた不具合で最初の理由を置き換えない（02-08「止める手順」）。
            }
        }
    }
}

#[cfg(test)]
mod tests;
