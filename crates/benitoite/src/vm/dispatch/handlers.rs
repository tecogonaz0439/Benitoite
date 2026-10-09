//! ハンドラ、区画の所有の移動、包む枠のある戻り（設計書 02-08「ハンドラと継続」「実行の手順」）。

use super::*;
use crate::bytecode::program::OpIdx;
use crate::vm::frame::{HandleFrame, OtherFrame, OtherKind, Segment};
use crate::vm::handler::{ContState, HandlerRecord};
use crate::vm::unwind::{
    self, ReleaseLog, ReturnDest, ReturnStage, ReturnWork, UnwindCause, UnwindStep,
};

// 遅い命令の経路を一か所から呼び、通常のループで同時に生きる参照を減らす
// （ADR 0313 の決定 2）。窓の読み直しもこの関数内に閉じ込める。
#[cold]
#[inline(never)]
pub(super) fn dispatch<'p>(
    program: &'p CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &mut Cursor<'p>,
    instr: Instr,
    services: BuiltinServices<'_>,
) -> Result<Control, Stop> {
    let opcode = instr
        .opcode()
        .ok_or_else(|| missing("unknown slow instruction"))?;
    if opcode == Opcode::Handle {
        handle(program, config, state, ctx, cursor, instr)
    } else if opcode == Opcode::Perform {
        perform(program, config, state, ctx, cursor, instr)
    } else if opcode == Opcode::Resume {
        resume(program, state, ctx, cursor, instr)
    } else if opcode == Opcode::Return {
        let segment = state.segment()?;
        if segment.others.last().is_some_and(|other| {
            usize::try_from(other.depth).is_ok_and(|depth| {
                depth == segment.calls.len()
                    || (depth.checked_add(1) == Some(segment.calls.len())
                        && other.kind.is_wrapping())
            })
        }) {
            begin_return(program, state, ctx, cursor, instr)
        } else {
            return_plain(program, state, ctx, cursor, instr)
        }
    } else if opcode == Opcode::Escape {
        super::unwinding::begin_escape(program, state, ctx, cursor, instr)
    } else if opcode == Opcode::Io {
        let reference = program
            .builtin(BuiltinRefIdx(u32::from(instr.b())))
            .ok_or_else(|| missing("builtin reference missing"))?;
        let op = reference
            .op
            .ok_or_else(|| missing("IO operation missing"))?;
        if let Some(control) = io(program, config, state, ctx, cursor, instr, op)? {
            return Ok(control);
        }
        // どの言語のハンドラも処理しなかった `Assert` の操作は、送り出しの列に置かずにその場で確かめる
        // （実装プラン 10-18「`Assert.Check` の処理」の手順 2）。両方の IO の方式がここを通る。
        if let Some(table) = &state.assert
            && let Some(assert_op) = table.op_of(reference.id)
        {
            let table = std::sync::Arc::clone(table);
            return assert_check(program, state, ctx, cursor, instr, &table, assert_op);
        }
        let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
        let end = execute_builtin(program, ctx, window, &cursor.locals, instr, services)?;
        let control = finish_builtin(state, ctx, &mut cursor.locals, end)?;
        if matches!(control, Control::Next) {
            save_next(state, cursor)?;
            Ok(Control::Reload)
        } else {
            Ok(control)
        }
    } else {
        Err(missing("unexpected slow instruction"))
    }
}

// 10-18「`Assert.Check` の処理」の手順 2〜5。要求を作らない。
#[cold]
#[inline(never)]
fn assert_check(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
    table: &crate::runtime::assert::AssertTable,
    op: crate::runtime::assert::AssertOp,
) -> Result<Control, Stop> {
    use crate::runtime::assert::{AssertVerdict, CheckFailure};
    let reference = program
        .builtin(BuiltinRefIdx(u32::from(instr.b())))
        .ok_or_else(|| missing("builtin reference missing"))?;
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    reg_ref(window, instr.a())?;
    let args = read_range(ctx, window, &reg_range(instr.c(), reference.arity)?)?;
    let site = crate::runtime::report::instr_span(program, at);
    // 失敗の値は区間の中で文字列に書き出す。ヒープの値を区間の外へ持ち出さない（10-18）。
    match crate::runtime::assert::evaluate(ctx, table, op, &args, site)? {
        AssertVerdict::Passed => {
            write(ctx, window, instr.a(), Value::Unit)?;
            save_next(state, cursor)?;
            Ok(Control::Reload)
        }
        AssertVerdict::Failed {
            message,
            left,
            right,
        } => {
            if state.stopping.is_none() {
                // 枠を一つも降ろさないうちに、`StopInfo` と同じ方法で枠と起動の履歴を集める（手順 4）。
                let info = state.stop_info(missing("assertion failed"), Some(at));
                state.check_failure = Some(Box::new(CheckFailure {
                    op,
                    message,
                    left,
                    right,
                    at,
                    frames: info.frames,
                    spawns: info.spawns,
                }));
                cursor.locals.save(state.frame_mut()?);
                state.stopping = Some(StopReason::CheckFailed(op.name().to_owned()));
            }
            Ok(Control::Reload)
        }
    }
}

#[cold]
#[inline(never)]
pub(super) fn resume_return(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    interrupt: Option<&AtomicBool>,
) -> Option<LoopExit> {
    match continue_return(program, state, ctx, interrupt) {
        Ok(Control::Reload) => state.stopping.is_some().then(|| cleanup(state, ctx)),
        Ok(Control::Collect) => Some(LoopExit::Collect),
        Ok(Control::Return) => Some(LoopExit::Return),
        Ok(_) => {
            state.fail(missing("invalid return continuation"), None);
            Some(cleanup(state, ctx))
        }
        Err(stop) => {
            let at = state.returning.as_ref().map(|work| work.at);
            state.fail(stop, at);
            Some(cleanup(state, ctx))
        }
    }
}

#[cold]
#[inline(never)]
pub(super) fn fail_instruction(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    at: InstrRef,
    stop: Stop,
) -> LoopExit {
    let at = state.returning.as_ref().map_or(at, |work| work.at);
    if state.returning.is_none()
        && let Ok(frame) = state.frame_mut()
        && frame.proto == cursor.locals.proto
        && frame.base == cursor.locals.base
    {
        cursor.locals.save(frame);
    }
    state.fail(stop, Some(at));
    cleanup(state, ctx)
}

// 普通の CALL の引数の並びや速い経路を変えず、暗黙の呼び出しだけが使う（ADR 0313）。
fn target<'p, 'e>(
    program: &'p CompiledProgram,
    ctx: &NoGcCtx<'e>,
    value: Value<'e>,
    arity: u16,
) -> Result<CallTarget<'p, 'e>, Stop> {
    let index = ProtoIdx(require_func(ctx, value)?);
    let proto = program
        .proto(index)
        .ok_or_else(|| missing("handler prototype missing"))?;
    if proto.num_params != arity || arity > proto.num_regs {
        return Err(missing("handler argument count mismatch"));
    }
    Ok(CallTarget {
        value,
        index,
        proto,
        arity,
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

fn precall(
    config: VmConfig,
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    cursor: &Cursor<'_>,
) -> Result<bool, Stop> {
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    if cursor
        .interrupt
        .is_some_and(|flag| flag.load(Ordering::Relaxed))
    {
        interrupt_call(state, Some(&cursor.locals))?;
        return Ok(false);
    }
    if state.precall_done != Some(at) && !state.budget.tick() {
        if ctx.collect_requested() {
            state.precall_done = Some(at);
            cursor.locals.save(state.frame_mut()?);
            return Ok(false);
        }
        if tasks::slow_path_end(state, config.call_budget)? {
            state.precall_done = Some(at);
            cursor.locals.save(state.frame_mut()?);
            return Ok(false);
        }
    }
    state.precall_done = None;
    Ok(true)
}

fn save_next(state: &mut RunState, cursor: &Cursor<'_>) -> Result<(), Stop> {
    // 移動の後は Reload で読み直すので、呼び出し側の局所の値は書き換えない。
    // 遅い経路へ渡す共有の参照は、普通の命令の局所を変更できない（ADR 0313・0263）。
    let pc = cursor
        .locals
        .pc
        .checked_add(1)
        .ok_or_else(|| missing("pc overflow"))?;
    state.frame_mut()?.pc = pc;
    Ok(())
}

fn frame<'e>(
    ctx: &NoGcCtx<'e>,
    called: CallTarget<'_, 'e>,
    base: u32,
    ret: Option<u32>,
    at: InstrRef,
    chain_resume: Option<u32>,
) -> CallFrame {
    CallFrame {
        func: ctx.new_slot(called.value),
        proto: called.index,
        pc: 0,
        base,
        size: u32::from(called.proto.num_regs),
        ret,
        call_site: Some(at),
        boundary: called.proto.boundary,
        chain_resume,
    }
}

#[cold]
#[inline(never)]
pub(super) fn handle(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let desc = cursor
        .active
        .proto
        .handler(instr.c())
        .ok_or_else(|| missing("handler description index missing"))?;
    let handler = program
        .handler(desc)
        .ok_or_else(|| missing("handler description missing"))?;
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    let ret = cursor
        .locals
        .base
        .checked_add(u32::from(instr.a()))
        .ok_or_else(|| missing("handler return overflow"))?;
    reg_ref(window, instr.a())?;
    let called = target(program, ctx, read_one(ctx, window, instr.b())?, 0)?;
    let begin = usize::from(instr.b())
        .checked_add(1)
        .ok_or_else(|| missing("handler range overflow"))?;
    let end = begin
        .checked_add(handler.clauses.len())
        .ok_or_else(|| missing("handler range overflow"))?;
    let clauses = window
        .get(begin..end)
        .ok_or_else(|| missing("handler clause range missing"))?;
    // 節の窓の範囲も、安全点を通る前に確かめる（実装プラン R20「HANDLE」）。
    for (slot, clause) in clauses.iter().zip(&handler.clauses) {
        let op = program
            .op(clause.op)
            .ok_or_else(|| missing("handler operation missing"))?;
        let arity = op
            .arity
            .checked_add(1)
            .ok_or_else(|| missing("clause arity overflow"))?;
        target(program, ctx, ctx.load(slot), arity)?;
    }
    fits(state, 2, called.proto.num_regs)?;
    if !precall(config, state, ctx, cursor)? {
        return Ok(if state.stopping.is_some() {
            Control::Reload
        } else {
            Control::Collect
        });
    }
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    let clauses = window
        .get(begin..end)
        .ok_or_else(|| missing("handler clause range missing"))?
        .iter()
        .map(|slot| ctx.new_slot(ctx.load(slot)))
        .collect();
    let record = ctx.alloc_host(HandlerRecord {
        clauses,
        desc,
        evaluated_by: state.current_task,
        members: Vec::new(),
        body_finished: false,
    });
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    let regs = called.proto.num_regs;
    let mut segment = Segment {
        regs: std::iter::repeat_with(Slot::default)
            .take(usize::from(regs))
            .collect(),
        ..Segment::default()
    };
    segment.others.push(OtherFrame {
        depth: 0,
        kind: OtherKind::Handle(HandleFrame {
            record: ctx.new_slot(record),
            ret,
            at,
        }),
    });
    segment.calls.push(frame(ctx, called, 0, None, at, None));
    save_next(state, cursor)?;
    state.stack.segments.push(segment);
    state.meter.grow(2, u64::from(regs));
    notify_collect(state, ctx);
    Ok(Control::Reload)
}

struct Found<'e> {
    op: OpIdx,
    record: Value<'e>,
    clause: usize,
    segment: Option<usize>,
    inherited: Option<u32>,
}

fn clause<'e>(
    program: &CompiledProgram,
    ctx: &NoGcCtx<'e>,
    record: Value<'e>,
    op: OpIdx,
) -> Result<Option<usize>, Stop> {
    let record = ctx
        .host::<HandlerRecord>(record)
        .ok_or_else(|| missing("handler record required"))?;
    let desc = program
        .handler(record.desc)
        .ok_or_else(|| missing("handler description missing"))?;
    Ok(desc.clauses.iter().position(|clause| clause.op == op))
}

#[cold]
#[inline(never)]
fn find<'e>(
    program: &CompiledProgram,
    state: &RunState,
    ctx: &NoGcCtx<'e>,
    op: OpIdx,
) -> Result<Option<Found<'e>>, Stop> {
    let mut inherited_start = 0;
    'segments: for (index, segment) in state.stack.segments.iter().enumerate().rev() {
        // 区画の底の handle より先に、節の枠の連鎖の切り替えを調べる。
        // 節より内側で始めた handle は、上の区画で既に探索している（ADR 0151）。
        // chain_resume は継承した節だけが作る。空の連鎖なら通常の呼び出しの深さに
        // 比例する走査をせず、区画の handle だけを調べる（ADR 0151）。
        if !state.inherited.is_empty() {
            for call in segment.calls.iter().rev() {
                if let Some(start) = call.chain_resume {
                    inherited_start = start;
                    break 'segments;
                }
            }
        }
        if let Some(OtherFrame {
            kind: OtherKind::Handle(h),
            ..
        }) = segment.others.first()
        {
            let record = ctx.load(&h.record);
            if let Some(clause) = clause(program, ctx, record, op)? {
                return Ok(Some(Found {
                    op,
                    record,
                    clause,
                    segment: Some(index),
                    inherited: None,
                }));
            }
        }
    }
    for (index, slot) in state
        .inherited
        .iter()
        .enumerate()
        .skip(index(inherited_start)?)
    {
        let record = ctx.load(slot);
        if let Some(clause) = clause(program, ctx, record, op)? {
            let start = u32::try_from(index)
                .ok()
                .and_then(|n| n.checked_add(1))
                .ok_or_else(|| missing("inherited chain overflow"))?;
            return Ok(Some(Found {
                op,
                record,
                clause,
                segment: None,
                inherited: Some(start),
            }));
        }
    }
    Ok(None)
}

#[cold]
#[inline(never)]
pub(super) fn perform(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let op = OpIdx(u32::from(instr.b()));
    let found =
        find(program, state, ctx, op)?.ok_or_else(|| missing("unhandled user operation"))?;
    invoke_clause(program, config, state, ctx, cursor, instr, found)
}

#[cold]
#[inline(never)]
pub(super) fn io(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
    op: OpIdx,
) -> Result<Option<Control>, Stop> {
    let Some(found) = find(program, state, ctx, op)? else {
        return Ok(None);
    };
    invoke_clause(program, config, state, ctx, cursor, instr, found).map(Some)
}

#[cold]
#[inline(never)]
fn invoke_clause<'e>(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    cursor: &Cursor<'_>,
    instr: Instr,
    found: Found<'e>,
) -> Result<Control, Stop> {
    let operation = program
        .op(found.op)
        .ok_or_else(|| missing("operation missing"))?;
    let record = ctx
        .host::<HandlerRecord>(found.record)
        .ok_or_else(|| missing("handler record required"))?;
    let local = found.segment.is_some();
    if local != (record.evaluated_by == state.current_task) {
        return Err(missing("handler owner does not match its chain"));
    }
    if !local {
        let desc = program
            .handler(record.desc)
            .and_then(|desc| desc.clauses.get(found.clause))
            .ok_or_else(|| missing("clause description missing"))?;
        if !desc.tail_resumptive {
            return Err(Stop::Runtime(RuntimeError::InheritedHandlerClause {
                operation: operation.name.clone(),
            }));
        }
    }
    let arity = operation
        .arity
        .checked_add(1)
        .ok_or_else(|| missing("clause arity overflow"))?;
    let called = target(
        program,
        ctx,
        ctx.load(
            record
                .clauses
                .get(found.clause)
                .ok_or_else(|| missing("clause function missing"))?,
        ),
        arity,
    )?;
    fits(state, if local { 2 } else { 1 }, called.proto.num_regs)?;
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    reg_ref(window, instr.a())?;
    let range = reg_range(instr.c(), operation.arity)?;
    window
        .get(range.clone())
        .ok_or_else(|| missing("operation arguments missing"))?;
    let current = state
        .stack
        .segments
        .len()
        .checked_sub(1)
        .ok_or_else(|| missing("operation segment missing"))?;
    let destination = if local {
        found
            .segment
            .and_then(|n| n.checked_sub(1))
            .ok_or_else(|| missing("local handler has no enclosing segment"))?
    } else {
        current
    };
    let segment = state
        .stack
        .segments
        .get(destination)
        .ok_or_else(|| missing("clause destination missing"))?;
    let base =
        u32::try_from(segment.regs.len()).map_err(|_| missing("clause register count overflow"))?;
    let end = base
        .checked_add(u32::from(called.proto.num_regs))
        .ok_or_else(|| missing("clause window overflow"))?;
    let depth = u32::try_from(segment.calls.len()).map_err(|_| missing("clause depth overflow"))?;
    let ret = if local {
        let segment = state
            .stack
            .segments
            .get(destination.saturating_add(1))
            .ok_or_else(|| missing("captured handle missing"))?;
        match segment.others.first().map(|f| &f.kind) {
            Some(OtherKind::Handle(h)) => h.ret,
            _ => return Err(missing("captured segment has no handle")),
        }
    } else {
        cursor
            .locals
            .base
            .checked_add(u32::from(instr.a()))
            .ok_or_else(|| missing("clause result overflow"))?
    };
    // 切り離す前に、停止しうる検査をすべて済ませる。安全点の後は探索からやり直す（R20）。
    if !precall(config, state, ctx, cursor)? {
        return Ok(if state.stopping.is_some() {
            Control::Reload
        } else {
            Control::Collect
        });
    }
    let args = read_range(
        ctx,
        active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
        &range,
    )?;
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    save_next(state, cursor)?;
    let new_size = called.proto.num_regs;
    let segment = state
        .stack
        .segments
        .get_mut(destination)
        .ok_or_else(|| missing("clause destination missing"))?;
    segment.regs.resize_with(index(end)?, Slot::default);
    for (arg, slot) in args.iter().zip(
        segment
            .regs
            .get_mut(index(base)?..index(end)?)
            .ok_or_else(|| missing("clause window missing"))?,
    ) {
        ctx.store(slot, *arg);
    }
    let cont = if local {
        let start = destination.saturating_add(1);
        for segment in state.stack.segments.iter_mut().skip(start) {
            clear_captured(program, segment, ctx);
        }
        // この所有の移動から drop の枠まで、失敗する処理を挟まない（R20 手順 4.4）。
        let segments = state.stack.segments.split_off(start);
        let cont = ctx.alloc_host(ContState::Captured(segments));
        if let Some(segment) = state.stack.segments.last_mut() {
            segment.others.push(OtherFrame {
                depth,
                kind: OtherKind::Drop {
                    cont: ctx.new_slot(cont),
                },
            });
        }
        cont
    } else {
        ctx.alloc_host(ContState::Direct)
    };
    // 所有を移した後に不整合があっても、drop の枠から継続を辿れる（R20）。
    let segment = state.segment_mut()?;
    let cont_index = base
        .checked_add(u32::from(operation.arity))
        .ok_or_else(|| missing("continuation register overflow"))?;
    ctx.store(
        segment
            .regs
            .get_mut(index(cont_index)?)
            .ok_or_else(|| missing("continuation register missing"))?,
        cont,
    );
    segment.calls.push(frame(
        ctx,
        called,
        base,
        Some(ret),
        at,
        if local { None } else { found.inherited },
    ));
    state
        .meter
        .grow(if local { 2 } else { 1 }, u64::from(new_size));
    notify_collect(state, ctx);
    Ok(Control::Reload)
}

fn clear_captured(program: &CompiledProgram, segment: &mut Segment, ctx: &NoGcCtx<'_>) {
    for frame in &segment.calls {
        // 継続の最上位の枠も操作の結果をまだ待つ。情報を引けない枠は保存する（ADR 0314、R20）。
        let Ok((live, dest)) = frame_live_registers(program, frame, false) else {
            continue;
        };
        let Some(end) = frame.base.checked_add(frame.size) else {
            continue;
        };
        let (Ok(base), Ok(end)) = (index(frame.base), index(end)) else {
            continue;
        };
        let Some(window) = segment.regs.get_mut(base..end) else {
            continue;
        };
        for (reg, slot) in window.iter_mut().enumerate() {
            let Ok(reg) = u16::try_from(reg) else {
                continue;
            };
            if live.binary_search(&reg).is_err() || dest == Some(reg) {
                ctx.clear(slot);
            }
        }
    }
}

#[cold]
#[inline(never)]
pub(super) fn resume(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let window = active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?;
    let cont = read_one(ctx, window, instr.b())?;
    let value = read_one(ctx, window, instr.c())?;
    reg_ref(window, instr.a())?;
    let dest = cursor
        .locals
        .base
        .checked_add(u32::from(instr.a()))
        .ok_or_else(|| missing("resume result overflow"))?;
    let captured = match ctx
        .host::<ContState>(cont)
        .ok_or_else(|| missing("continuation required"))?
    {
        ContState::Used => return Err(Stop::Runtime(RuntimeError::ContinuationResumedTwice)),
        ContState::Direct => {
            write(ctx, window, instr.a(), value)?;
            return Ok(Control::Next);
        }
        ContState::Captured(segments) => segments,
    };
    if !matches!(
        captured
            .first()
            .and_then(|s| s.others.first())
            .map(|f| &f.kind),
        Some(OtherKind::Handle(_))
    ) {
        return Err(missing("continuation bottom handle missing"));
    }
    let segment = captured
        .last()
        .ok_or_else(|| missing("captured segment missing"))?;
    let call = segment
        .calls
        .last()
        .ok_or_else(|| missing("captured call missing"))?;
    let proto = program
        .proto(call.proto)
        .ok_or_else(|| missing("captured prototype missing"))?;
    let operation = call
        .pc
        .checked_sub(1)
        .and_then(|pc| proto.code.get(index(pc).ok()?))
        .ok_or_else(|| missing("captured operation missing"))?;
    if !matches!(operation.opcode(), Some(Opcode::Perform | Opcode::Io)) {
        return Err(missing("captured call is not at an operation"));
    }
    let result = call
        .base
        .checked_add(u32::from(operation.a()))
        .ok_or_else(|| missing("resume register overflow"))?;
    segment
        .regs
        .get(index(result)?)
        .ok_or_else(|| missing("resume register missing"))?;
    save_next(state, cursor)?;
    let segments = ctx
        .host_mut::<ContState, _>(cont, |state, ops| {
            let ContState::Captured(mut segments) = std::mem::replace(state, ContState::Used)
            else {
                return None;
            };
            if let Some(OtherFrame {
                kind: OtherKind::Handle(h),
                ..
            }) = segments.first_mut().and_then(|s| s.others.first_mut())
            {
                h.ret = dest;
            }
            if let Some(slot) = segments
                .last_mut()
                .and_then(|s| s.regs.get_mut(usize::try_from(result).ok()?))
            {
                ops.store(slot, value);
            }
            Some(segments)
        })
        .flatten()
        .ok_or_else(|| missing("continuation changed during resume"))?;
    // 深さ、窓、ret は区画内の位置なので、呼び出し元の深さに合わせて直さない（ADR 0262）。
    state.stack.segments.extend(segments);
    Ok(Control::Reload)
}

#[cold]
#[inline(never)]
pub(super) fn begin_return(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let value = read_one(
        ctx,
        active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
        instr.a(),
    )?;
    cursor.locals.save(state.frame_mut()?);
    state.returning = Some(ReturnWork {
        value: ctx.new_slot(value),
        dest: ReturnDest::Pending,
        stage: ReturnStage::OwnReleases,
        at: InstrRef {
            proto: cursor.locals.proto,
            pc: cursor.locals.pc,
        },
    });
    continue_return(program, state, ctx, cursor.interrupt)
}

// 値を取り出した枠は、成功なら discard、待ちや失敗なら元へ戻す。枠の Slot の受け持ちはここ一つ（10-09）。
#[cold]
#[inline(never)]
pub(super) fn unwind_top(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> Result<UnwindStep, Stop> {
    state
        .returning
        .as_ref()
        .ok_or_else(|| missing("return work missing"))?;
    let handle_dest = match state.segment()?.others.last().map(|o| &o.kind) {
        Some(OtherKind::Handle(h)) => {
            let segment = state
                .stack
                .segments
                .len()
                .checked_sub(2)
                .and_then(|n| u32::try_from(n).ok())
                .ok_or_else(|| missing("handle enclosing segment missing"))?;
            Some(ReturnDest::Reg {
                segment,
                reg: h.ret,
            })
        }
        _ => None,
    };
    let other = state
        .segment_mut()?
        .others
        .pop()
        .ok_or_else(|| missing("return wrapping frame missing"))?;
    let at = state.current_task;
    let cause = UnwindCause::Return;
    let result = match &other.kind {
        OtherKind::Handle(h) => unwind::unwind_handle(ctx, state, at, h, cause),
        OtherKind::Drop { cont } => unwind::unwind_drop(ctx, state, at, cont, cause),
        OtherKind::Release {
            resource,
            at: opened,
        } => unwind::unwind_release(
            ctx,
            state,
            at,
            *resource,
            *opened,
            cause,
            &mut ReleaseLog::default(),
        ),
        OtherKind::Update { lazy, .. } => unwind::unwind_update(ctx, state, at, lazy, cause),
        OtherKind::CellUpdate(c) => unwind::unwind_cell_update(ctx, state, at, c, cause),
    };
    match result {
        Ok(UnwindStep::Popped) => {
            if let Some(dest) = handle_dest
                && let Some(work) = state.returning.as_mut()
                && work.stage == ReturnStage::Wrapping
            {
                work.dest = dest;
            }
            ctx.discard(other);
            state.meter.shrink(1, 0);
            Ok(UnwindStep::Popped)
        }
        Ok(UnwindStep::Traverse { segments, cause }) => {
            ctx.discard(other);
            state.meter.shrink(1, 0);
            Ok(UnwindStep::Traverse { segments, cause })
        }
        result => {
            state.segment_mut()?.others.push(other);
            result
        }
    }
}

#[cold]
#[inline(never)]
pub(super) fn continue_return(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    interrupt: Option<&AtomicBool>,
) -> Result<Control, Stop> {
    loop {
        if state.unwinding.is_some() {
            match super::unwinding::traverse(state, ctx)? {
                Control::Reload => {}
                control
                @ (Control::Jumped | Control::Next | Control::Collect | Control::Return) => {
                    return Ok(control);
                }
            }
        }
        let stage = state
            .returning
            .as_ref()
            .ok_or_else(|| missing("return work missing"))?
            .stage;
        if stage == ReturnStage::OwnReleases {
            let segment = state.segment()?;
            let depth =
                u32::try_from(segment.calls.len()).map_err(|_| missing("return depth overflow"))?;
            if segment
                .others
                .last()
                .is_some_and(|o| o.depth == depth && matches!(o.kind, OtherKind::Release { .. }))
            {
                match unwind_top(state, ctx)? {
                    UnwindStep::Popped => {}
                    UnwindStep::Wait(reason) => return tasks::park(state, reason),
                    UnwindStep::Retry | UnwindStep::Traverse { .. } => {
                        return Err(missing("invalid release unwind result"));
                    }
                }
                if ctx.collect_requested() {
                    return Ok(Control::Collect);
                }
                continue;
            }
            let call = state.frame()?;
            let dest = if let Some(reg) = call.ret {
                let segment = u32::try_from(state.stack.segments.len().saturating_sub(1))
                    .map_err(|_| missing("return segment overflow"))?;
                ReturnDest::Reg { segment, reg }
            } else if state.stack.segments.len() == 1 {
                ReturnDest::TaskResult
            } else {
                ReturnDest::Pending
            };
            pop_call(state, ctx)?;
            let work = state
                .returning
                .as_mut()
                .ok_or_else(|| missing("return work missing"))?;
            work.dest = dest;
            work.stage = ReturnStage::Wrapping;
        } else if stage == ReturnStage::Escaping {
            match super::unwinding::escape_one(state, ctx)? {
                Control::Reload => continue,
                control
                @ (Control::Jumped | Control::Next | Control::Collect | Control::Return) => {
                    return Ok(control);
                }
            }
        }
        let segment = state.segment()?;
        let depth =
            u32::try_from(segment.calls.len()).map_err(|_| missing("return depth overflow"))?;
        if segment
            .others
            .last()
            .is_some_and(|o| o.depth == depth && o.kind.is_wrapping())
        {
            match unwind_top(state, ctx)? {
                UnwindStep::Popped => {}
                UnwindStep::Wait(reason) => return tasks::park(state, reason),
                UnwindStep::Traverse { segments, cause } => {
                    super::unwinding::begin_traverse(state, segments, cause);
                    continue;
                }
                UnwindStep::Retry => {
                    return super::cell::retry(program, state, ctx, interrupt);
                }
            }
            if state.segment()?.is_empty() {
                if let Some(segment) = state.stack.segments.pop() {
                    ctx.discard(segment);
                }
                // 区画を降ろした後は、新しい区画の同じ深さの包む枠へ進まない。
                // 戻り先の呼び出しに値を入れる段に進む（設計書 02-08「実行の手順」）。
                if ctx.collect_requested() {
                    return Ok(Control::Collect);
                }
                return finish_return(program, state, ctx);
            }
            if ctx.collect_requested() {
                return Ok(Control::Collect);
            }
            continue;
        }
        return finish_return(program, state, ctx);
    }
}

#[cold]
#[inline(never)]
fn finish_return(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
) -> Result<Control, Stop> {
    let work = state
        .returning
        .as_ref()
        .ok_or_else(|| missing("return work missing"))?;
    let value = ctx.load(&work.value);
    let control = match work.dest {
        ReturnDest::Reg { segment, reg } => {
            let slot = state
                .stack
                .segments
                .get_mut(index(segment)?)
                .and_then(|s| s.regs.get_mut(index(reg).ok()?))
                .ok_or_else(|| missing("return destination missing"))?;
            ctx.store(slot, value);
            if ctx.collect_requested() {
                Control::Collect
            } else {
                Control::Reload
            }
        }
        ReturnDest::TaskResult => tasks::finish(program, state, ctx, value)?,
        ReturnDest::Pending => return Err(missing("return destination unresolved")),
    };
    if let Some(work) = state.returning.take() {
        ctx.discard(work);
    }
    Ok(control)
}

#[cfg(test)]
pub(super) mod tests;
