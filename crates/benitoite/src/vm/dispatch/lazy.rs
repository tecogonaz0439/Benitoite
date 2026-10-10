//! 明示遅延の命令と update の枠の処理（設計書 02-08「明示遅延」「枠を降ろす原因と処理」）。

use super::*;
use crate::vm::TaskId;
use crate::vm::frame::{OtherFrame, OtherKind};
use crate::vm::handler::LazyState;
use crate::vm::task::WaitReason;
use crate::vm::unwind::{UnwindCause, UnwindStep};

// 通常の呼び出しの経路へ状態の判定と枠の確保を展開しない（実装プラン R22「性能」）。
#[cold]
#[inline(never)]
pub(super) fn dispatch(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    if instr.opcode() == Some(Opcode::Lazy) {
        let segment = state.segment_mut()?;
        let end = cursor
            .locals
            .base
            .checked_add(cursor.active.size)
            .ok_or_else(|| missing("lazy window overflow"))?;
        let window = segment
            .regs
            .get_mut(index(cursor.locals.base)?..index(end)?)
            .ok_or_else(|| missing("lazy window missing"))?;
        let body = closure_value(program, ctx, window, &segment.calls, ProtoIdx(instr.bx()))?;
        let lazy = ctx.alloc_host(LazyState::Before {
            body: ctx.new_slot(body),
        });
        write(ctx, window, instr.a(), lazy)?;
        return Ok(after_alloc(state, ctx));
    }
    force(program, config, state, ctx, cursor, instr)
}

fn force(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    reg_ref(window, instr.a())?;
    let lazy = read_one(ctx, window, instr.b())?;
    let body = match ctx
        .host::<LazyState>(lazy)
        .ok_or_else(|| missing("Lazy value required"))?
    {
        LazyState::Done { value } => {
            let value = ctx.load(value);
            state.precall_done = None;
            let window =
                active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
            write(ctx, window, instr.a(), value)?;
            return Ok(Control::Next);
        }
        LazyState::Before { body } => ctx.load(body),
        LazyState::Evaluating { by, .. } => {
            state.precall_done = None;
            if *by == state.current_task {
                return Err(missing("recursive force of evaluating Lazy"));
            }
            let task = state.current_task;
            ctx.host_mut::<LazyState, _>(lazy, |data, _| {
                if let LazyState::Evaluating { waiters, .. } = data {
                    waiters.push(task);
                }
            })
            .ok_or_else(|| missing("Lazy value required"))?;
            // 待ちの間は FORCE の入口を保つ。R[B] は再開後にも読む
            // （実装プラン 10-09「呼び出しの前の安全点」、設計書 02-08「枠を降ろす原因と処理」）。
            cursor.locals.save(state.frame_mut()?);
            return tasks::park(state, WaitReason::Lazy);
        }
    };
    let target = ProtoIdx(require_func(ctx, body)?);
    let called = program
        .proto(target)
        .ok_or_else(|| missing("lazy prototype missing"))?;
    if called.num_params != 0 {
        return Err(missing("Lazy body requires arguments"));
    }
    // 包む枠と本体の呼び出しの枠の両方を、状態を変える前に数える
    // （設計書 02-08「呼び出しの入れ子の上限」）。
    if !state.meter.fits(2, u64::from(called.num_regs)) {
        return Err(Stop::Resource(ResourceError::CallStackTooDeep {
            frames: state.meter.frames(),
        }));
    }
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    if cursor
        .interrupt
        .is_some_and(|flag| flag.load(Ordering::Relaxed))
    {
        return interrupt_call(state, Some(&cursor.locals));
    }
    if state.precall_done != Some(at) && !state.budget.tick() {
        if ctx.collect_requested() {
            state.precall_done = Some(at);
            cursor.locals.save(state.frame_mut()?);
            return Ok(Control::Collect);
        }
        if tasks::slow_path_end(state, config.call_budget)? {
            state.precall_done = Some(at);
            cursor.locals.save(state.frame_mut()?);
            return Ok(Control::Return);
        }
    }
    state.precall_done = None;
    let ret = cursor
        .locals
        .base
        .checked_add(u32::from(instr.a()))
        .ok_or_else(|| missing("lazy return register overflow"))?;
    let segment = state.segment_mut()?;
    let depth =
        u32::try_from(segment.calls.len()).map_err(|_| missing("lazy frame count overflow"))?;
    let base =
        u32::try_from(segment.regs.len()).map_err(|_| missing("lazy register count overflow"))?;
    let size = u32::from(called.num_regs);
    let end = base
        .checked_add(size)
        .ok_or_else(|| missing("lazy window overflow"))?;
    let next = cursor
        .locals
        .pc
        .checked_add(1)
        .ok_or_else(|| missing("pc overflow"))?;
    let task = state.current_task;
    ctx.host_mut::<LazyState, _>(lazy, |data, _| {
        let LazyState::Before { body } = data else {
            return Err(missing("Lazy changed before evaluation"));
        };
        *data = LazyState::Evaluating {
            body: std::mem::take(body),
            by: task,
            waiters: Vec::new(),
        };
        Ok(())
    })
    .ok_or_else(|| missing("Lazy value required"))??;
    let segment = state.segment_mut()?;
    // 結果がまだ書かれていない呼び出し元として整理できるよう、先に pc を進める。
    // この後、枠と窓を積み終えるまでは安全点を置かない（設計書 02-08「枠を降ろす原因と処理」）。
    segment
        .calls
        .last_mut()
        .ok_or_else(|| missing("call frame missing"))?
        .pc = next;
    segment.others.push(OtherFrame {
        depth,
        kind: OtherKind::Update {
            lazy: ctx.new_slot(lazy),
            at,
        },
    });
    segment.regs.resize_with(index(end)?, Slot::default);
    segment.calls.push(CallFrame {
        func: ctx.new_slot(body),
        proto: target,
        pc: 0,
        base,
        size,
        ret: Some(ret),
        call_site: Some(at),
        boundary: called.boundary,
        chain_resume: None,
    });
    state.meter.grow(2, u64::from(size));
    Ok(Control::Reload)
}

// 原因ごとの違いをこの一か所に置き、停止中の再評価を防ぐ（設計書 02-08「枠を降ろす原因と処理」）。
#[cold]
#[inline(never)]
pub(in crate::vm) fn finish<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut RunState,
    at: TaskId,
    lazy: &Slot,
    cause: UnwindCause,
) -> Result<UnwindStep, Stop> {
    let returned = if cause == UnwindCause::Return {
        Some(
            ctx.load(
                &rt.returning
                    .as_ref()
                    .ok_or_else(|| missing("Lazy return value missing"))?
                    .value,
            ),
        )
    } else {
        None
    };
    let waiters = ctx
        .host_mut::<LazyState, _>(ctx.load(lazy), |data, slots| {
            let LazyState::Evaluating { body, by, waiters } = data else {
                return Err(missing("update frame requires evaluating Lazy"));
            };
            if *by != at {
                return Err(missing("Lazy evaluator does not own update frame"));
            }
            let body = std::mem::take(body);
            let waiters = std::mem::take(waiters);
            *data = if let Some(value) = returned {
                slots.discard(body);
                LazyState::Done {
                    value: slots.new_slot(value),
                }
            } else {
                LazyState::Before { body }
            };
            Ok(waiters)
        })
        .ok_or_else(|| missing("Lazy value required"))??;
    if cause != UnwindCause::Stop {
        for task in waiters {
            // 世代を含む番号と現在の待ちの理由を確かめ、古い知らせで起こさない
            // （実装プラン R25「待つタスクを知らせで起こすとき」）。
            rt.scheduler.wake_if(task, WaitReason::Lazy);
        }
    }
    Ok(UnwindStep::Popped)
}

#[cfg(test)]
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
pub(super) mod tests;
