//! セルの更新の呼び出しと、版が変わったときの呼び直し（設計書 02-08「可変のセル」）。

use super::*;
use crate::vm::frame::{CellUpdate, OtherFrame, OtherKind};
use crate::vm::unwind::ReturnDest;

fn target<'p, 'e>(
    program: &'p CompiledProgram,
    ctx: &NoGcCtx<'e>,
    func: Value<'e>,
) -> Result<CallTarget<'p, 'e>, Stop> {
    let index = ProtoIdx(require_func(ctx, func)?);
    let proto = program
        .proto(index)
        .ok_or_else(|| missing("update prototype missing"))?;
    if proto.num_params != 1 || proto.num_regs == 0 {
        return Err(missing("update function argument count mismatch"));
    }
    Ok(CallTarget {
        value: func,
        index,
        proto,
        arity: 1,
    })
}

fn fits(state: &RunState, frames: u64, regs: u16) -> Result<(), Stop> {
    if state.meter.fits(frames, u64::from(regs)) {
        Ok(())
    } else {
        Err(Stop::Resource(ResourceError::CallStackTooDeep {
            frames: state.meter.frames(),
        }))
    }
}

// 命令のない呼び直しも同じ印を使い、回収からの再開で予算を二度数えない
// （実装プラン 10-09「呼び出しの前の安全点」、R23「Retry を受けたとき」）。
fn precall(
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    at: InstrRef,
    interrupt: Option<&AtomicBool>,
) -> Result<bool, Stop> {
    if interrupt.is_some_and(|flag| flag.load(Ordering::Relaxed)) {
        interrupt_call(state, None)?;
        return Ok(false);
    }
    if state.precall_done != Some(at) && !state.budget.tick() {
        if ctx.collect_requested() {
            state.precall_done = Some(at);
            return Ok(false);
        }
        if tasks::slow_path_end(state, state.call_budget)? {
            state.precall_done = Some(at);
            return Ok(false);
        }
    }
    state.precall_done = None;
    Ok(true)
}

fn push_call<'e>(
    state: &mut RunState,
    ctx: &NoGcCtx<'e>,
    called: CallTarget<'_, 'e>,
    value: Value<'e>,
    ret: u32,
    at: InstrRef,
) -> Result<(), Stop> {
    let size = u32::from(called.proto.num_regs);
    let segment = state.segment_mut()?;
    let base =
        u32::try_from(segment.regs.len()).map_err(|_| missing("update register count overflow"))?;
    let end = base
        .checked_add(size)
        .ok_or_else(|| missing("update window overflow"))?;
    segment.regs.resize_with(index(end)?, Slot::default);
    ctx.store(
        segment
            .regs
            .get_mut(index(base)?)
            .ok_or_else(|| missing("update argument missing"))?,
        value,
    );
    segment.calls.push(CallFrame {
        func: ctx.new_slot(called.value),
        proto: called.index,
        pc: 0,
        base,
        size,
        ret: Some(ret),
        call_site: Some(at),
        boundary: called.proto.boundary,
        chain_resume: None,
    });
    state.meter.grow(1, u64::from(size));
    Ok(())
}

#[cold]
#[inline(never)]
pub(super) fn update(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    reg_ref(window, instr.a())?;
    let func = read_one(ctx, window, instr.c())?;
    let called = target(program, ctx, func)?;
    fits(state, 2, called.proto.num_regs)?;
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    if !precall(state, ctx, at, cursor.interrupt)? {
        cursor.locals.save(state.frame_mut()?);
        return Ok(if state.stopping.is_some() {
            Control::Reload
        } else {
            Control::Collect
        });
    }
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    let cell = read_one(ctx, window, instr.b())?;
    let value = ctx
        .cell_get(cell)
        .ok_or_else(|| missing("UPDATE requires a cell"))?;
    let version = ctx
        .cell_version(cell)
        .ok_or_else(|| missing("UPDATE requires a cell version"))?;
    let ret = cursor
        .locals
        .base
        .checked_add(u32::from(instr.a()))
        .ok_or_else(|| missing("update result overflow"))?;
    let depth = u32::try_from(state.segment()?.calls.len())
        .map_err(|_| missing("update depth overflow"))?;
    // 回収時に call_write(pc - 1) が UPDATE の結果を指すよう、枠を積む前に保存する（設計書 02-08「枠を降ろす原因と処理」）。
    state.frame_mut()?.pc = cursor
        .locals
        .pc
        .checked_add(1)
        .ok_or_else(|| missing("update pc overflow"))?;
    state.segment_mut()?.others.push(OtherFrame {
        depth,
        kind: OtherKind::CellUpdate(CellUpdate {
            cell: ctx.new_slot(cell),
            version,
            func: ctx.new_slot(func),
        }),
    });
    state.meter.grow(1, 0);
    push_call(state, ctx, called, value, ret, at)?;
    notify_collect(state, ctx);
    Ok(Control::Reload)
}

#[cold]
#[inline(never)]
pub(super) fn retry(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    interrupt: Option<&AtomicBool>,
) -> Result<Control, Stop> {
    let work = state
        .returning
        .as_ref()
        .ok_or_else(|| missing("update retry return work missing"))?;
    let at = work.at;
    let ReturnDest::Reg { segment, reg: ret } = work.dest else {
        return Err(missing("update retry destination is not a register"));
    };
    if index(segment)? != state.stack.segments.len().saturating_sub(1) {
        return Err(missing("update retry destination segment mismatch"));
    }
    state
        .segment()?
        .regs
        .get(index(ret)?)
        .ok_or_else(|| missing("update retry destination missing"))?;
    let Some(OtherKind::CellUpdate(frame)) = state.segment()?.others.last().map(|o| &o.kind) else {
        return Err(missing("update retry frame missing"));
    };
    let called = target(program, ctx, ctx.load(&frame.func))?;
    // 更新の枠は残したままなので、呼び出しの枠一つだけを加える（設計書 02-08「可変のセル」）。
    fits(state, 1, called.proto.num_regs)?;
    if !precall(state, ctx, at, interrupt)? {
        return Ok(if state.stopping.is_some() {
            Control::Reload
        } else {
            Control::Collect
        });
    }
    let Some(OtherKind::CellUpdate(frame)) =
        state.segment_mut()?.others.last_mut().map(|o| &mut o.kind)
    else {
        return Err(missing("update retry frame missing"));
    };
    let cell = ctx.load(&frame.cell);
    let value = ctx
        .cell_get(cell)
        .ok_or_else(|| missing("update retry requires a cell"))?;
    frame.version = ctx
        .cell_version(cell)
        .ok_or_else(|| missing("update retry cell version missing"))?;
    push_call(state, ctx, called, value, ret, at)?;
    if let Some(work) = state.returning.take() {
        ctx.discard(work);
    }
    notify_collect(state, ctx);
    Ok(Control::Reload)
}

#[cfg(test)]
pub(super) mod tests;
