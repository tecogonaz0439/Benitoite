//! 振り分けのループ（設計書 02-08「実行の手順」、ADR 0263）。命令ごとの処理は 10-07 の命令に従う。

mod cell;
mod collections;
mod handlers;
pub(super) mod lazy;
mod numeric;
pub(super) mod resource;
pub(super) mod tasks;
mod traits;
mod unwinding;

use crate::bytecode::instr::Instr;
use crate::bytecode::program::ProtoIdx;

/// 振り分けのループの局所の状態。
#[derive(Clone, Copy, Debug)]
pub struct LoopLocals<'p> {
    pub proto: ProtoIdx,
    /// 実行中の原型の命令の並び（10-07 の `Instr`）
    pub code: &'p [Instr],
    /// 次に実行する命令の位置
    pub pc: u32,
    /// 窓の先頭（実行中の区画の `regs` の中の位置）
    pub base: u32,
}

/// 振り分けのループが区間を閉じて出る理由。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum LoopExit {
    /// 回収のために区間を閉じる。局所の状態は書き戻してある
    Collect,
    /// 実行を終えた、止まった、要求を返すなど、実行関数から戻る
    Return,
}

use crate::bytecode::program::CompiledProgram;
use crate::runtime::Stop;

use super::frame::CallFrame;

impl<'p> LoopLocals<'p> {
    /// 呼び出しの枠から局所の状態を読む。原型の番号が表にないときは `Stop::Internal`。
    pub fn load(program: &'p CompiledProgram, frame: &CallFrame) -> Result<LoopLocals<'p>, Stop> {
        let proto = program
            .proto(frame.proto)
            .ok_or_else(|| missing("prototype missing"))?;
        Ok(LoopLocals {
            proto: frame.proto,
            code: &proto.code,
            pc: frame.pc,
            base: frame.base,
        })
    }
    /// 局所の状態を呼び出しの枠に書き戻す（`pc` を書く）。
    pub fn save(&self, frame: &mut CallFrame) {
        frame.pc = self.pc;
    }
}

use crate::builtins::iface::{CallCtx, Capability, Reply, WaitRequest};
use crate::builtins::table::tags;
use crate::builtins::{builtin_decl, funcs::operators};
use crate::bytecode::instr::Opcode;
use crate::bytecode::program::{
    BuiltinRefIdx, CaptureSource, ConstDesc, ConstIdx, CtorIdx, MainKind, Proto,
};
use crate::runtime::heap::{CtorTag, FieldsKind, NoGcCtx, Slot, Value};
use crate::runtime::{ResourceError, RuntimeError, equal, list};

#[cfg(test)]
use super::ExecMode;
use super::budget::SlowPathEnd;
use super::state::{RunState, internal};
use super::{InstrRef, MainOutcome, StopEnd, StopReason, Vm, VmConfig, VmStep};
use crate::runtime::io::services::IoRuntime;
use std::sync::atomic::{AtomicBool, Ordering};

// 失敗の説明の確保を、命令ごとの正常な経路へ展開しない（ADR 0313 の決定 2）。
#[cold]
#[inline(never)]
fn missing(message: &'static str) -> Stop {
    internal(message)
}

// 原型と窓の大きさは、呼び出しなどの境目でだけ読み直す（ADR 0313 の決定 2）。
struct ActiveProto<'p> {
    proto: &'p Proto,
    size: u32,
}

// 凍結した LoopLocals を変えず、原型への参照と窓の大きさを一緒に切り替える（ADR 0313）。
struct Cursor<'p> {
    locals: LoopLocals<'p>,
    active: ActiveProto<'p>,
    interrupt: Option<&'p AtomicBool>,
}
impl<'p> Cursor<'p> {
    fn load(
        program: &'p CompiledProgram,
        frame: &CallFrame,
        interrupt: Option<&'p AtomicBool>,
    ) -> Result<Self, Stop> {
        let proto = program
            .proto(frame.proto)
            .ok_or_else(|| missing("prototype missing"))?;
        Ok(Self {
            locals: LoopLocals {
                proto: frame.proto,
                code: &proto.code,
                pc: frame.pc,
                base: frame.base,
            },
            interrupt,
            active: ActiveProto {
                proto,
                size: frame.size,
            },
        })
    }
}

struct CallTarget<'p, 'e> {
    value: Value<'e>,
    index: ProtoIdx,
    proto: &'p Proto,
    arity: u16,
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn active_window(
    segment: &mut super::frame::Segment,
    base: u32,
    size: u32,
) -> Result<&mut [Slot], Stop> {
    let end = base
        .checked_add(size)
        .ok_or_else(|| missing("window overflow"))?;
    segment
        .regs
        .get_mut(index(base)?..index(end)?)
        .ok_or_else(|| missing("window missing"))
}

#[derive(Clone, Copy)]
enum Control {
    Jumped,
    Next,
    Reload,
    Collect,
    Return,
}

// 印への参照と IO の可変の借用を分け、panic の巻き戻しでも読み口を戻す。
// 最後の出力の転送を終えるまでシグナルの登録を保つ（実装プラン R28）。
struct InterruptLease<'a> {
    rt: &'a mut IoRuntime,
    source: Box<dyn crate::runtime::io::services::InterruptSource>,
}

impl Drop for InterruptLease<'_> {
    fn drop(&mut self) {
        std::mem::swap(&mut self.rt.interrupt, &mut self.source);
    }
}

// 区間の外側は回収と不具合の取り出しだけを受け持つ。命令の振り分けはここ一つに置く
// （設計書 02-08「実行の手順」、ADR 0263）。
pub(super) fn run_epoch(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
) -> LoopExit {
    loop {
        if state.scheduling.switch.is_some() || !state.scheduling.active {
            if let Err(stop) = tasks::switch(program, state, ctx, rt) {
                if state.scheduling.stopping {
                    tasks::stop_without_progress(state, ctx, stop);
                    return LoopExit::Return;
                }
                state.fail(stop, None);
                if !state.scheduling.active {
                    if let Err(stop) = tasks::begin_stop_all(state, ctx) {
                        state.fail(stop, None);
                    }
                    state.scheduling.switch = Some(super::state::Switch::Done);
                    continue;
                }
            }
            if state.step.is_some() {
                return LoopExit::Return;
            }
            if !state.scheduling.active && ctx.collect_requested() {
                if let Err(stop) = clear_dead_registers(program, state, ctx) {
                    state.fail(stop, None);
                }
                return LoopExit::Collect;
            }
        }
        // 待ちの処理はこの呼び出しの外で行う。計算中だけ読み口を別に所有して、
        // 印への参照と IO の可変の借用を両立させる（実装プラン R28「性能」）。
        let exit = {
            let source = std::mem::replace(
                &mut rt.interrupt,
                Box::new(crate::runtime::run::NoInterrupt),
            );
            let lease = InterruptLease { rt, source };
            run_until_exit(program, config, state, ctx, lease.rt, lease.source.flag())
        };
        if state.scheduling.switch.is_some() {
            continue;
        }
        if exit != LoopExit::Collect {
            return exit;
        }
        // 呼び出しの前・戻りの後・停止の途中の出口をここに集め、区間を閉じる前に
        // 回収済みの対象を指す Slot が窓に残らないようにする（ADR 0314 の決定 2・3）。
        match clear_dead_registers(program, state, ctx) {
            Ok(()) => return LoopExit::Collect,
            Err(stop) => state.fail(stop, None),
        }
        // 不整合を見つけた検証用の構成では、次の周回で停止の手順へ進む。
        // その途中の回収も同じ出口を通す（設計書 02-08「止める手順」）。
    }
}

fn run_until_exit(
    program: &CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    interrupt: Option<&AtomicBool>,
) -> LoopExit {
    if state.stopping.is_some() {
        return cleanup(state, ctx);
    }
    if (state.unwinding.is_some() || state.returning.is_some())
        && let Some(exit) = unwinding::resume(program, state, ctx, interrupt)
    {
        return exit;
    }
    let mut cursor = match state
        .frame()
        .and_then(|f| Cursor::load(program, f, interrupt))
    {
        Ok(cursor) => cursor,
        Err(stop) => {
            state.fail(stop, None);
            return cleanup(state, ctx);
        }
    };
    loop {
        let at = InstrRef {
            proto: cursor.locals.proto,
            pc: cursor.locals.pc,
        };
        let result = execute(program, config, state, ctx, rt, &mut cursor);
        match result {
            Ok(Control::Next) => match cursor.locals.pc.checked_add(1) {
                Some(pc) => cursor.locals.pc = pc,
                None => {
                    state.fail(missing("pc overflow"), Some(at));
                    return cleanup(state, ctx);
                }
            },
            Ok(Control::Reload) => {
                if state.stopping.is_some() {
                    return cleanup(state, ctx);
                }
                match state
                    .frame()
                    .and_then(|f| Cursor::load(program, f, interrupt))
                {
                    Ok(next) => cursor = next,
                    Err(stop) => {
                        state.fail(stop, Some(at));
                        return cleanup(state, ctx);
                    }
                }
            }
            Ok(Control::Jumped) => {}
            Ok(Control::Collect) => return LoopExit::Collect,
            Ok(Control::Return) => return LoopExit::Return,
            Err(stop) => return handlers::fail_instruction(state, ctx, &cursor, at, stop),
        }
    }
}

// 中断の停止処理を通常の呼び出しへ展開しない（設計書 02-08「タスクの切り替え」）。
#[cold]
#[inline(never)]
fn interrupt_call(state: &mut RunState, locals: Option<&LoopLocals<'_>>) -> Result<Control, Stop> {
    if state.stopping.is_none() {
        if let Some(locals) = locals {
            locals.save(state.frame_mut()?);
        }
        state.stopping = Some(StopReason::Interrupted);
    }
    Ok(Control::Reload)
}

// 窓以外の根（枠の func、包む枠、根の保存領域）は触れない（ADR 0314 の決定 5）。
fn clear_dead_registers(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
) -> Result<(), Stop> {
    clear_stack(
        program,
        &mut state.stack,
        state.returning.as_ref(),
        |slot| ctx.clear(slot),
    )?;
    let tasks: Vec<_> = state
        .tasks
        .entries
        .iter()
        .filter_map(|e| e.task.as_ref().map(|slot| ctx.load(slot)))
        .collect();
    for value in tasks {
        ctx.host_mut::<super::task::TaskObj, _>(value, |task, slots| {
            clear_stack(program, &mut task.stack, task.returning.as_ref(), |slot| {
                slots.clear(slot)
            })
        })
        .ok_or_else(|| missing("collection task missing"))??;
    }
    Ok(())
}

fn clear_stack(
    program: &CompiledProgram,
    stack: &mut super::frame::TaskStack,
    returning: Option<&super::unwind::ReturnWork>,
    mut clear: impl FnMut(&mut Slot),
) -> Result<(), Stop> {
    let top_segment = stack.segments.len().checked_sub(1);
    // 呼び出しの枠を降ろした後は、最内の呼び出し元も ReturnWork の値をまだ待つ。
    // RETURN 自身の解放の枠を処理中なら、最内の枠は RETURN の入口である（ADR 0314）。
    // Escaping の最内の枠は ESCAPE の入口か、降ろす途中の呼び出し元である。
    // 区画を抜けた直後には結果を書く予定がなく、分類できないので窓を保つ（ADR 0314）。
    if returning.is_some_and(|work| work.stage == super::unwind::ReturnStage::Escaping) {
        return Ok(());
    }
    // UnwindWork の区画は通常の再開をせず、ここでは整理せずに保つ（実装プラン R21）。
    let wrapping_return =
        returning.is_some_and(|work| work.stage == super::unwind::ReturnStage::Wrapping);
    for (segment_index, segment) in stack.segments.iter_mut().enumerate() {
        let top_call = segment.calls.len().checked_sub(1);
        for (call_index, frame) in segment.calls.iter().enumerate() {
            let innermost = !wrapping_return
                && Some(segment_index) == top_segment
                && Some(call_index) == top_call;
            let info = frame_live_registers(program, frame, innermost).and_then(|(live, dest)| {
                let end = frame
                    .base
                    .checked_add(frame.size)
                    .ok_or_else(|| missing("window overflow"))?;
                let window = segment
                    .regs
                    .get_mut(index(frame.base)?..index(end)?)
                    .ok_or_else(|| missing("collection window missing"))?;
                Ok((window, live, dest))
            });
            let (window, live, dest) = match info {
                Ok(info) => info,
                Err(stop) => {
                    // 未検証の情報で途中まで消さない。通常の構成は窓全体を保存する
                    // （実装プラン R16「回収の前に空にする」）。
                    if cfg!(feature = "heap-verify") {
                        return Err(stop);
                    }
                    continue;
                }
            };
            let mut remaining = live.iter().copied().peekable();
            for (reg, slot) in window.iter_mut().enumerate() {
                let keep = remaining
                    .peek()
                    .is_some_and(|next| usize::from(*next) == reg);
                if keep {
                    remaining.next();
                }
                if !keep || dest.is_some_and(|dest| usize::from(dest) == reg) {
                    clear(slot);
                }
            }
        }
    }
    Ok(())
}

fn frame_live_registers<'p>(
    program: &'p CompiledProgram,
    frame: &CallFrame,
    innermost: bool,
) -> Result<(&'p [u16], Option<u16>), Stop> {
    let proto = program
        .proto(frame.proto)
        .ok_or_else(|| missing("collection prototype missing"))?;
    if index(frame.pc)? >= proto.code.len() {
        return Err(missing("collection pc outside code"));
    }
    let live = proto
        .live
        .live_in_at(frame.pc)
        .ok_or_else(|| missing("live-in information missing"))?;
    let dest = if innermost {
        None
    } else {
        Some(
            frame
                .pc
                .checked_sub(1)
                .and_then(|pc| proto.live.call_write(pc))
                .ok_or_else(|| missing("suspended frame has no call result"))?,
        )
    };
    // 番号は窓の相対位置であり、ret の区画内の位置とは異なる。集合全体を先に
    // 確かめ、異常な番号の前にあるレジスタも保存する（ADR 0314、実装プラン R16）。
    if live.iter().any(|reg| u32::from(*reg) >= frame.size)
        || live.iter().zip(live.iter().skip(1)).any(|(a, b)| a >= b)
        || dest.is_some_and(|reg| u32::from(reg) >= frame.size)
    {
        return Err(missing("invalid live-in register order or range"));
    }
    Ok((live, dest))
}

// 検証器のあるデバッグ構成へ強制展開すると一時変数の保存領域が増えるため、
// 強制展開は最適化した構成に限る（ADR 0313 の決定 2）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn execute<'p, 'e>(
    program: &'p CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    rt: &mut IoRuntime,
    cursor: &mut Cursor<'p>,
) -> Result<Control, Stop> {
    let instr = *cursor
        .locals
        .code
        .get(index(cursor.locals.pc)?)
        .ok_or_else(|| missing("pc outside code"))?;
    let opcode = instr.opcode().ok_or_else(|| missing("unknown opcode"))?;
    let Cursor { locals, active, .. } = cursor;
    let proto = active.proto;
    let segment = state
        .stack
        .segments
        .last_mut()
        .ok_or_else(|| missing("no active segment"))?;
    let end = locals
        .base
        .checked_add(active.size)
        .ok_or_else(|| missing("window overflow"))?;
    let window = segment
        .regs
        .get_mut(index(locals.base)?..index(end)?)
        .ok_or_else(|| missing("window missing"))?;
    let calls = &mut segment.calls;
    // 引数は使う分岐で復号し、通常のループで state と同時に保持する値を減らす
    // （ADR 0313 の決定 2）。命令はこの match で一度だけ判定する（R15 手順 6）。
    macro_rules! binary_values {
        ($decode:expr, $operation:expr) => {{
            let [left, right] = read_pair(ctx, window, instr.b(), instr.c())?;
            let value = ($operation)(($decode)(left)?, ($decode)(right)?)?;
            write(ctx, window, instr.a(), value)?;
        }};
    }
    'fast: {
        match opcode {
            Opcode::GetDict => traits::get_dict(window, calls, ctx, instr)?,
            Opcode::Dict => {
                traits::dict(program, window, ctx, instr)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::Super => {
                traits::super_dict(program, window, ctx, instr)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::Method | Opcode::TailMethod => {
                return traits::method(program, config, state, ctx, cursor, instr);
            }
            Opcode::Move => {
                let v = read_one(ctx, window, instr.b())?;
                write(ctx, window, instr.a(), v)?;
            }
            Opcode::LoadK => {
                let k = proto
                    .constant(instr.bx())
                    .ok_or_else(|| missing("constant index missing"))?;
                let cached = state
                    .constants
                    .get(index(k.0)?)
                    .ok_or_else(|| missing("constant cache index missing"))?;
                if let Some(slot) = cached {
                    write(ctx, window, instr.a(), ctx.load(slot))?;
                    // 作り終えた定数は確保しない（10-07「定数の記述」、R17）。
                    return Ok(Control::Next);
                }
                let desc = program
                    .constant(k)
                    .ok_or_else(|| missing("constant description missing"))?;
                if let Some(v) = immediate_constant(program, desc)? {
                    write(ctx, window, instr.a(), v)?;
                    // 即値は確保しないので、回収の要求の知らせも調べない（10-09）。
                    return Ok(Control::Next);
                }
                let v = constant(program, &mut state.constants, ctx, k)?;
                write(ctx, window, instr.a(), v)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::GetCap => {
                let func = ctx.load(
                    &calls
                        .last()
                        .ok_or_else(|| missing("call frame missing"))?
                        .func,
                );
                require_func(ctx, func)?;
                let value = ctx
                    .field(func, u32::from(instr.b()))
                    .ok_or_else(|| missing("capture missing"))?;
                write(ctx, window, instr.a(), value)?;
            }
            Opcode::Closure => {
                build_closure(program, ctx, window, calls, instr)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::Call | Opcode::TailCall => {
                let func = ctx.load(reg_ref(window, instr.b())?);
                let target = ProtoIdx(require_func(ctx, func)?);
                let called = program
                    .proto(target)
                    .ok_or_else(|| missing("called prototype missing"))?;
                if called.num_params != instr.c() || instr.c() > called.num_regs {
                    return Err(missing("call argument count mismatch"));
                }
                let target = CallTarget {
                    value: func,
                    index: target,
                    proto: called,
                    arity: instr.c(),
                };
                return if opcode == Opcode::TailCall {
                    call::<true>(config, state, ctx, cursor, instr, target)
                } else {
                    call::<false>(config, state, ctx, cursor, instr, target)
                };
            }
            Opcode::Handle | Opcode::Perform | Opcode::Resume | Opcode::Escape => break 'fast,
            Opcode::Return => {
                if !segment.others.is_empty() {
                    break 'fast;
                }
                return return_plain(program, state, ctx, cursor, instr);
            }
            Opcode::Prim | Opcode::Io => {
                let reference = program
                    .builtin(BuiltinRefIdx(u32::from(instr.b())))
                    .ok_or_else(|| missing("builtin reference missing"))?;
                match reference.capability {
                    Capability::State if opcode == Opcode::Prim => {
                        return builtin_slow(
                            state,
                            ctx,
                            BuiltinSlow::State {
                                program,
                                cursor,
                                instr,
                                rt,
                            },
                        );
                    }
                    Capability::Io if opcode == Opcode::Io => {}
                    Capability::Pure if opcode == Opcode::Prim => {}
                    Capability::Pure | Capability::State | Capability::Io => {
                        return Err(missing("builtin capability does not match instruction"));
                    }
                }
                if opcode == Opcode::Io && reference.op.is_some() {
                    break 'fast;
                }
                let end =
                    execute_builtin(program, ctx, window, locals, instr, BuiltinServices { rt })?;
                return finish_builtin(state, ctx, locals, end);
            }
            Opcode::Con | Opcode::ConR => {
                if !build_constructor(program, ctx, window, instr, opcode == Opcode::ConR)? {
                    return Ok(Control::Next);
                }
                return Ok(after_alloc(state, ctx));
            }
            Opcode::List => {
                build_list(ctx, window, instr)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::Field => {
                let v = read_one(ctx, window, instr.b())?;
                if !matches!(ctx.fields_header(v), Some((FieldsKind::Ctor, _))) {
                    return Err(missing("FIELD requires constructor"));
                }
                let value = ctx
                    .field(v, u32::from(instr.c()))
                    .ok_or_else(|| missing("constructor field missing"))?;
                write(ctx, window, instr.a(), value)?;
            }
            Opcode::Jmp | Opcode::JmpF => {
                let jump = if opcode == Opcode::JmpF {
                    !read_one(ctx, window, instr.a())?
                        .as_bool()
                        .ok_or_else(|| missing("JMPF requires Boolean"))?
                } else {
                    true
                };
                if jump {
                    locals.pc = jump_target(locals, instr.sbx())?;
                    return Ok(Control::Jumped);
                }
            }
            Opcode::Switch => {
                let v = read_one(ctx, window, instr.a())?;
                let tag = match v.as_tag() {
                    Some(tag) => tag.0,
                    None => match ctx.fields_header(v) {
                        Some((FieldsKind::Ctor, tag)) => tag,
                        _ => return Err(missing("SWITCH requires constructor")),
                    },
                };
                let table = proto
                    .switch_table(instr.bx())
                    .ok_or_else(|| missing("switch table missing"))?;
                let offset = table
                    .targets
                    .get(index(tag)?)
                    .copied()
                    .flatten()
                    .or(table.default)
                    .ok_or_else(|| missing("switch has no matching branch"))?;
                locals.pc = jump_target(locals, offset)?;
                return Ok(Control::Jumped);
            }
            Opcode::NegI => {
                let v = integer_value(read_one(ctx, window, instr.b())?)?;
                write(ctx, window, instr.a(), integer_result(v.checked_neg())?)?;
            }
            Opcode::NegF => {
                let v = float_value(read_one(ctx, window, instr.b())?)?;
                write(ctx, window, instr.a(), Value::Float(-v))?;
            }
            Opcode::Not => {
                let v = boolean_value(read_one(ctx, window, instr.b())?)?;
                write(ctx, window, instr.a(), Value::Bool(!v))?;
            }
            Opcode::AddI => binary_values!(integer_value, |x: i64, y: i64| integer_result(
                x.checked_add(y)
            )),
            Opcode::SubI => binary_values!(integer_value, |x: i64, y: i64| integer_result(
                x.checked_sub(y)
            )),
            Opcode::MulI => binary_values!(integer_value, |x: i64, y: i64| integer_result(
                x.checked_mul(y)
            )),
            Opcode::DivI => binary_values!(integer_value, |x, y| operators::int_divide(x, y)
                .map(Value::Int)),
            Opcode::ModI => binary_values!(integer_value, |x, y| operators::int_modulo(x, y)
                .map(Value::Int)),
            Opcode::EqI => binary_values!(integer_value, |x: i64, y: i64| Ok::<_, Stop>(
                Value::Bool(x == y)
            )),
            Opcode::LtI => binary_values!(integer_value, |x: i64, y: i64| Ok::<_, Stop>(
                Value::Bool(x < y)
            )),
            Opcode::LeI => binary_values!(integer_value, |x: i64, y: i64| Ok::<_, Stop>(
                Value::Bool(x <= y)
            )),
            Opcode::EqF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Bool(x == y)
            )),
            Opcode::LtF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Bool(x < y)
            )),
            Opcode::LeF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Bool(x <= y)
            )),
            Opcode::EqC => binary_values!(character_value, |x: char, y: char| Ok::<_, Stop>(
                Value::Bool(x == y)
            )),
            Opcode::LtC => binary_values!(character_value, |x: char, y: char| Ok::<_, Stop>(
                Value::Bool(x < y)
            )),
            Opcode::LeC => binary_values!(character_value, |x: char, y: char| Ok::<_, Stop>(
                Value::Bool(x <= y)
            )),
            Opcode::AddF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Float(std::ops::Add::add(x, y))
            )),
            Opcode::SubF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Float(std::ops::Sub::sub(x, y))
            )),
            Opcode::MulF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Float(std::ops::Mul::mul(x, y))
            )),
            Opcode::DivF => binary_values!(float_value, |x: f64, y: f64| Ok::<_, Stop>(
                Value::Float(std::ops::Div::div(x, y))
            )),
            Opcode::EqS => cold_binary(
                ctx,
                window,
                instr,
                |v| ctx.str(v).ok_or_else(|| missing("string operand required")),
                |x: &str, y: &str| Ok::<_, Stop>(Value::Bool(x == y)),
            )?,
            Opcode::LtS => cold_binary(
                ctx,
                window,
                instr,
                |v| ctx.str(v).ok_or_else(|| missing("string operand required")),
                |x: &str, y: &str| Ok::<_, Stop>(Value::Bool(x < y)),
            )?,
            Opcode::LeS => cold_binary(
                ctx,
                window,
                instr,
                |v| ctx.str(v).ok_or_else(|| missing("string operand required")),
                |x: &str, y: &str| Ok::<_, Stop>(Value::Bool(x <= y)),
            )?,
            Opcode::Concat => {
                cold_binary(
                    ctx,
                    window,
                    instr,
                    |v| ctx.str(v).ok_or_else(|| missing("string operand required")),
                    |x, y| ctx.alloc_str_parts(&[x, y], "+"),
                )?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::EqB => binary_values!(boolean_value, |x, y| Ok::<_, Stop>(Value::Bool(x == y))),
            Opcode::EqV => cold_binary(ctx, window, instr, Ok::<_, Stop>, |x, y| {
                equal::values_equal(ctx, x, y).map(Value::Bool)
            })?,
            Opcode::AddD => {
                let v = numeric::arithmetic(window, ctx, instr, |x, y| x.checked_add(y))?;
                write(ctx, window, instr.a(), v)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::SubD => {
                let v = numeric::arithmetic(window, ctx, instr, |x, y| x.checked_sub(y))?;
                write(ctx, window, instr.a(), v)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::MulD => {
                let v = numeric::arithmetic(window, ctx, instr, |x, y| x.checked_mul(y))?;
                write(ctx, window, instr.a(), v)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::DivD => {
                let v = numeric::arithmetic(window, ctx, instr, |x, y| x.checked_div(y))?;
                write(ctx, window, instr.a(), v)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::NegD => {
                let v = numeric::negate(window, ctx, instr)?;
                write(ctx, window, instr.a(), v)?;
                return Ok(after_alloc(state, ctx));
            }
            Opcode::EqD => {
                let v = numeric::compare(window, ctx, instr, |order| order.is_eq())?;
                write(ctx, window, instr.a(), v)?;
            }
            Opcode::LtD => {
                let v = numeric::compare(window, ctx, instr, |order| order.is_lt())?;
                write(ctx, window, instr.a(), v)?;
            }
            Opcode::LeD => {
                let v = numeric::compare(window, ctx, instr, |order| order.is_le())?;
                write(ctx, window, instr.a(), v)?;
            }
            Opcode::EqBt => binary_values!(byte_value, |x: u8, y: u8| Ok::<_, Stop>(Value::Bool(
                x == y
            ))),
            Opcode::LtBt => {
                binary_values!(byte_value, |x: u8, y: u8| Ok::<_, Stop>(Value::Bool(x < y)))
            }
            Opcode::LeBt => binary_values!(byte_value, |x: u8, y: u8| Ok::<_, Stop>(Value::Bool(
                x <= y
            ))),
            // 第 2 段の命令の分岐は、並行して書く作業（R22・R23・R24）ごとに分けて置く。
            Opcode::Lazy | Opcode::Force => {
                return lazy::dispatch(program, config, state, ctx, cursor, instr);
            }
            Opcode::Update => {
                return cell::update(program, state, ctx, cursor, instr);
            }
            Opcode::Use | Opcode::Release => {
                return resource::dispatch(state, ctx, cursor, instr);
            }
        }
        return Ok(Control::Next);
    }
    handlers::dispatch(
        program,
        config,
        state,
        ctx,
        cursor,
        instr,
        BuiltinServices { rt },
    )
}

// 包む枠のない戻りは ReturnWork を作らない（ADR 0313 の決定 3）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn return_plain<'p>(
    program: &'p CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &mut Cursor<'p>,
    instr: Instr,
) -> Result<Control, Stop> {
    let Cursor { locals, active, .. } = cursor;
    let segment = state.segment_mut()?;
    let window = active_window(segment, locals.base, active.size)?;
    let a = instr.a();
    let value = read_one(ctx, window, a)?;
    let calls = &mut segment.calls;
    let frame = calls
        .last_mut()
        .ok_or_else(|| missing("call frame missing"))?;
    locals.save(frame);
    let ret = frame.ret;
    pop_call(state, ctx)?;
    if let Some(ret) = ret {
        let slot = state
            .segment_mut()?
            .regs
            .get_mut(index(ret)?)
            .ok_or_else(|| missing("return register missing"))?;
        ctx.store(slot, value);
        let frame = state.frame()?;
        let proto = program
            .proto(frame.proto)
            .ok_or_else(|| missing("return prototype missing"))?;
        *locals = LoopLocals {
            proto: frame.proto,
            code: &proto.code,
            pc: frame.pc,
            base: frame.base,
        };
        *active = ActiveProto {
            proto,
            size: frame.size,
        };
        if ctx.collect_requested() {
            return Ok(Control::Collect);
        }
        return Ok(Control::Jumped);
    }
    tasks::finish(program, state, ctx, value)
}

struct BuiltinServices<'a> {
    rt: &'a mut IoRuntime,
}

enum BuiltinEnd<'a> {
    Value,
    Request {
        rt: &'a mut IoRuntime,
        op: &'static crate::builtins::iface::BuiltinDecl,
        #[cfg(test)]
        id: crate::builtins::BuiltinId,
    },
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn execute_builtin<'a>(
    program: &CompiledProgram,
    ctx: &mut NoGcCtx<'_>,
    window: &mut [Slot],
    locals: &LoopLocals<'_>,
    instr: Instr,
    services: BuiltinServices<'a>,
) -> Result<BuiltinEnd<'a>, Stop> {
    let reference = program
        .builtin(BuiltinRefIdx(u32::from(instr.b())))
        .ok_or_else(|| missing("builtin reference missing"))?;
    reg_ref(window, instr.a())?;
    let regs = reg_range(instr.c(), reference.arity)?;
    if reference.capability == Capability::Io {
        window
            .get(regs)
            .ok_or_else(|| missing("builtin argument range missing"))?;
        let decl =
            builtin_decl(reference.id).ok_or_else(|| missing("builtin declaration missing"))?;
        if decl.arity != reference.arity || decl.capability != reference.capability {
            return Err(missing("builtin reference does not match declaration"));
        }
        return Ok(BuiltinEnd::Request {
            rt: services.rt,
            op: decl,
            #[cfg(test)]
            id: reference.id,
        });
    }
    let args = read_range(ctx, window, &regs)?;
    let value = invoke_pure(
        program,
        ctx,
        instr,
        InstrRef {
            proto: locals.proto,
            pc: locals.pc,
        },
        &args,
    )?;
    write(ctx, window, instr.a(), value)?;
    Ok(BuiltinEnd::Value)
}

// 第 1 段でも invoke はループの外にあった。応答の片付けをループへ展開しない（ADR 0313）。
#[inline(never)]
fn invoke_pure<'e>(
    program: &CompiledProgram,
    ctx: &mut NoGcCtx<'e>,
    instr: Instr,
    at: InstrRef,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let reference = program
        .builtin(BuiltinRefIdx(u32::from(instr.b())))
        .ok_or_else(|| missing("builtin reference missing"))?;
    let decl = builtin_decl(reference.id).ok_or_else(|| missing("builtin declaration missing"))?;
    if decl.arity != reference.arity || decl.capability != Capability::Pure {
        return Err(missing("builtin reference does not match declaration"));
    }
    let reply = (decl.raw)(&mut CallCtx::new(ctx, None, None, Some(at)), args)?;
    match reply {
        Reply::Done(value) => Ok(value),
        Reply::Wait(_) | Reply::SpawnTasks(_) | Reply::Exit(_) => {
            Err(missing("pure builtin returned effectful reply"))
        }
    }
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn finish_builtin(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    locals: &mut LoopLocals<'_>,
    end: BuiltinEnd<'_>,
) -> Result<Control, Stop> {
    match end {
        BuiltinEnd::Request {
            rt,
            op,
            #[cfg(test)]
            id,
        } => tasks::io::publish(
            state,
            ctx,
            locals,
            rt,
            op,
            #[cfg(test)]
            id,
        ),
        BuiltinEnd::Value => Ok(after_alloc(state, ctx)),
    }
}

// State の操作はタスクを切り替えうるため、窓の借用を終えた後に
// 同じ冷たい関数へ出す。通常の PRIM の振り分けには展開しない（ADR 0313）。
enum BuiltinSlow<'a, 'p> {
    State {
        program: &'p CompiledProgram,
        cursor: &'a Cursor<'p>,
        instr: Instr,
        rt: &'a mut IoRuntime,
    },
}
#[cold]
#[inline(never)]
fn builtin_slow(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    action: BuiltinSlow<'_, '_>,
) -> Result<Control, Stop> {
    match action {
        BuiltinSlow::State {
            program,
            cursor,
            instr,
            rt,
        } => tasks::dispatch(program, state, ctx, cursor, instr, rt),
    }
}

// 構築と構造の比較はループの外で行い、数値・跳躍・呼び出しの命令の経路を
// 小さく保つ。振り分けの match は execute の一つだけである（ADR 0313 の決定 2）。
#[inline(never)]
fn build_closure<'e>(
    program: &CompiledProgram,
    ctx: &NoGcCtx<'e>,
    window: &mut [Slot],
    calls: &[CallFrame],
    instr: Instr,
) -> Result<(), Stop> {
    let value = closure_value(program, ctx, window, calls, ProtoIdx(instr.bx()))?;
    write(ctx, window, instr.a(), value)
}

// LAZY も同じ捕捉の表から関数を作る。保存先は呼び出し側が決める
// （設計書 02-08「明示遅延」、実装プラン R22「LAZY」）。
#[inline(never)]
fn closure_value<'e>(
    program: &CompiledProgram,
    ctx: &NoGcCtx<'e>,
    window: &[Slot],
    calls: &[CallFrame],
    target: ProtoIdx,
) -> Result<Value<'e>, Stop> {
    let called = program
        .proto(target)
        .ok_or_else(|| missing("closure prototype missing"))?;
    let func = ctx.load(
        &calls
            .last()
            .ok_or_else(|| missing("call frame missing"))?
            .func,
    );
    let mut values = Operands::new(called.captures.len());
    for (dst, capture) in values.as_mut_slice().iter_mut().zip(&called.captures) {
        *dst = match capture {
            CaptureSource::Reg(reg) => ctx.load(reg_ref(window, *reg)?),
            CaptureSource::Capture(i) => {
                require_func(ctx, func)?;
                ctx.field(func, u32::from(*i))
                    .ok_or_else(|| missing("outer capture missing"))?
            }
        };
    }
    ctx.alloc_fields(FieldsKind::Func, target.0, &values)
}

#[inline(never)]
fn build_constructor<'e>(
    program: &CompiledProgram,
    ctx: &mut NoGcCtx<'e>,
    window: &mut [Slot],
    instr: Instr,
    reuse: bool,
) -> Result<bool, Stop> {
    let (a, b, c) = (instr.a(), instr.b(), instr.c());

    let ctor = program
        .ctor(CtorIdx(u32::from(b)))
        .ok_or_else(|| missing("constructor missing"))?;
    if ctor.arity == 0 {
        if reuse {
            return Err(missing("CONR requires a heap constructor"));
        }
        write(ctx, window, a, Value::Tag(CtorTag(ctor.tag)))?;
        return Ok(false);
    }
    let regs = reg_range(c, ctor.arity)?;
    let args = read_range(ctx, window, &regs)?;
    if reuse {
        if regs.contains(&usize::from(a)) {
            return Err(missing("reuse candidate overlaps arguments"));
        }
        let candidate = ctx.load(reg_ref(window, a)?);
        if !matches!(ctx.fields_header(candidate), Some((FieldsKind::Ctor, _)))
            || ctx.fields_len(candidate) != Some(u32::from(ctor.arity))
        {
            return Err(missing("invalid reuse candidate"));
        }
    }
    // マーク・スイープでは再利用しない。候補の形だけを確かめて新しく作る（10-07、ADR 0314）。
    let value = ctx.alloc_fields(FieldsKind::Ctor, ctor.tag, &args)?;
    write(ctx, window, a, value)?;

    Ok(true)
}

#[inline(never)]
fn build_list<'e>(ctx: &NoGcCtx<'e>, window: &mut [Slot], instr: Instr) -> Result<(), Stop> {
    let (a, b, c) = (instr.a(), instr.b(), instr.c());

    let regs = reg_range(b, c)?;
    let args = read_range(ctx, window, &regs)?;
    let value = list::from_values(ctx, &args, "LIST")?;
    write(ctx, window, a, value)?;

    Ok(())
}

#[inline(never)]
fn cold_binary<'e, T>(
    ctx: &NoGcCtx<'e>,
    window: &mut [Slot],
    instr: Instr,
    mut decode: impl FnMut(Value<'e>) -> Result<T, Stop>,
    operation: impl FnOnce(T, T) -> Result<Value<'e>, Stop>,
) -> Result<(), Stop> {
    let [x, y] = read_pair(ctx, window, instr.b(), instr.c())?;
    let value = operation(decode(x)?, decode(y)?)?;
    write(ctx, window, instr.a(), value)
}

// 引数は窓から窓へ直接写す。末尾では写し元が写し先より後ろなので、先頭から
// 写せば未読の引数を壊さない（ADR 0313 の決定 3、ADR 0314）。
// 通常と末尾の選択は命令の分岐で確定し、手順の途中で繰り返し判定しない（実装プラン R17）。
#[inline]
fn call<'p, 'e, const TAIL: bool>(
    config: VmConfig,
    state: &mut RunState,
    ctx: &NoGcCtx<'e>,
    cursor: &mut Cursor<'p>,
    instr: Instr,
    called: CallTarget<'p, 'e>,
) -> Result<Control, Stop> {
    let Cursor {
        locals,
        active,
        interrupt,
    } = cursor;
    let CallTarget {
        value: func,
        index: target,
        proto: called,
        arity,
    } = called;
    let old_size = active.size;
    let new_size = u32::from(called.num_regs);
    let added_regs = if TAIL {
        new_size.saturating_sub(old_size)
    } else {
        new_size
    };
    if !state.meter.fits(u64::from(!TAIL), u64::from(added_regs)) {
        return Err(Stop::Resource(ResourceError::CallStackTooDeep {
            frames: state.meter.frames(),
        }));
    }
    let at = InstrRef {
        proto: locals.proto,
        pc: locals.pc,
    };
    if interrupt.is_some_and(|flag| flag.load(Ordering::Relaxed)) {
        return interrupt_call(state, Some(locals));
    }
    // 回収から再開した命令は tick を繰り返さず、引数をまだ根に残す（10-09「呼び出しの前の安全点」）。
    if state.precall_done != Some(at)
        && !state.budget.tick()
        && let Some(control) = call_slow_path(state, ctx, locals, at, config.call_budget)?
    {
        return Ok(control);
    }
    state.precall_done = None;
    let source = instr
        .b()
        .checked_add(1)
        .ok_or_else(|| missing("call range overflow"))?;
    let range = reg_range(source, arity)?;
    let old_base = locals.base;
    let segment = state.segment_mut()?;
    let old_end = old_base
        .checked_add(old_size)
        .ok_or_else(|| missing("window overflow"))?;
    let old_base_index = index(old_base)?;
    let old_end_index = index(old_end)?;
    let ret = if TAIL {
        // 最も上の枠の終わりが regs.len() である形を使う（ADR 0313 の決定 3）。
        debug_assert_eq!(old_end_index, segment.regs.len());
        None
    } else {
        reg_ref(active_window(segment, old_base, old_size)?, instr.a())?;
        Some(
            old_base
                .checked_add(u32::from(instr.a()))
                .ok_or_else(|| missing("register index overflow"))?,
        )
    };
    let base = if TAIL {
        old_base
    } else {
        u32::try_from(segment.regs.len()).map_err(|_| missing("register count overflow"))?
    };
    let end = base
        .checked_add(new_size)
        .ok_or_else(|| missing("window overflow"))?;
    let base_index = index(base)?;
    let end_index = index(end)?;
    // 末尾の縮小は、写し元を読む前に行わない。
    if end_index > segment.regs.len() {
        segment.regs.resize_with(end_index, Slot::default);
    }
    if TAIL {
        let caller = segment
            .regs
            .get_mut(old_base_index..old_end_index)
            .ok_or_else(|| missing("window missing"))?;
        copy_tail_arguments(ctx, caller, range)?;
    } else {
        let (before, callee) = segment
            .regs
            .split_at_mut_checked(base_index)
            .ok_or_else(|| missing("call destination missing"))?;
        let caller = before
            .get_mut(old_base_index..old_end_index)
            .ok_or_else(|| missing("window missing"))?;
        let args = caller
            .get(range.clone())
            .ok_or_else(|| missing("call argument range missing"))?;
        let destinations = callee
            .get_mut(..usize::from(arity))
            .ok_or_else(|| missing("call destination missing"))?;
        for (src, dst) in args.iter().zip(destinations) {
            ctx.store(dst, ctx.load(src));
        }
    }
    if TAIL {
        // 拡張前の最上位の枠の終わりは regs.len()。拡張後は旧窓と新窓の大きい方になる
        // （ADR 0313 の決定 3）。窓の内部の旧値は回収の前に生存集合で空にする。
        // コード生成した原型の入口では引数だけが生きている（R18、ADR 0314 の決定 2・3）。
        debug_assert_eq!(old_end_index.max(end_index), segment.regs.len());
        // 窓の外になる場所だけを必ず空にしてから縮める（10-08「コード生成から受け取る生存の情報」）。
        if new_size < old_size {
            shrink_tail_window(ctx, &mut segment.regs, end_index, old_end_index)?;
        }
        let frame = segment
            .calls
            .last_mut()
            .ok_or_else(|| missing("call frame missing"))?;
        locals.save(frame);
        ctx.store(&mut frame.func, func);
        frame.proto = target;
        frame.pc = 0;
        frame.size = new_size;
        frame.call_site = Some(at);
        frame.boundary = true;
        frame.chain_resume = None;
        if new_size > old_size {
            state.meter.grow(0, u64::from(added_regs));
        } else if new_size < old_size {
            state
                .meter
                .shrink(0, u64::from(old_size.saturating_sub(new_size)));
        }
    } else {
        locals.pc = locals
            .pc
            .checked_add(1)
            .ok_or_else(|| missing("pc overflow"))?;
        locals.save(
            segment
                .calls
                .last_mut()
                .ok_or_else(|| missing("call frame missing"))?,
        );
        segment.calls.push(CallFrame {
            func: ctx.new_slot(func),
            proto: target,
            pc: 0,
            base,
            size: new_size,
            ret,
            call_site: Some(at),
            boundary: called.boundary,
            chain_resume: None,
        });
        state.meter.grow(1, u64::from(new_size));
    }
    *locals = LoopLocals {
        proto: target,
        code: &called.code,
        pc: 0,
        base,
    };
    *active = ActiveProto {
        proto: called,
        size: new_size,
    };
    Ok(Control::Jumped)
}

// 保存して回収か切り替えへ出る二つの枝をまとめ、CALL/TAILCALL の機械語に
// 枠の保存を二度展開しない（ADR 0313、実装プラン R25「切り替えの位置の集約」）。
#[cold]
#[inline(never)]
fn call_slow_path(
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    locals: &LoopLocals<'_>,
    at: InstrRef,
    initial: u32,
) -> Result<Option<Control>, Stop> {
    let control = if ctx.collect_requested() {
        Control::Collect
    } else if tasks::slow_path_end(state, initial)? {
        Control::Return
    } else {
        return Ok(None);
    };
    state.precall_done = Some(at);
    locals.save(state.frame_mut()?);
    Ok(Some(control))
}

// 窓が同じ大きさの末尾再帰では使わない片付けを、呼び出しの経路へ展開しない（R18）。
#[inline(never)]
fn shrink_tail_window(
    ctx: &NoGcCtx<'_>,
    regs: &mut Vec<Slot>,
    end: usize,
    old_end: usize,
) -> Result<(), Stop> {
    for slot in regs
        .get_mut(end..old_end)
        .ok_or_else(|| missing("tail cleanup range missing"))?
    {
        ctx.clear(slot);
    }
    regs.truncate(end);
    Ok(())
}

// 写し元は写し先より後ろにあり、先頭から写しても未読の引数に重ならない。
// 最後の使用の移動はせず、写し終えた後に call が窓の外になった場所だけを空にする（ADR 0313・0314）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn copy_tail_arguments(
    ctx: &NoGcCtx<'_>,
    window: &mut [Slot],
    range: std::ops::Range<usize>,
) -> Result<(), Stop> {
    if range.start == 0 {
        return Err(missing("tail argument overlaps unread source"));
    }
    // 確かめた引数の終端をコピーでも使い、同じ窓の範囲を引き直さない（実装プラン R17）。
    let window = window
        .get_mut(..range.end)
        .ok_or_else(|| missing("call argument range missing"))?;
    for (dst, src) in range.enumerate() {
        let value = ctx.load(
            window
                .get(src)
                .ok_or_else(|| missing("call argument missing"))?,
        );
        ctx.store(
            window
                .get_mut(dst)
                .ok_or_else(|| missing("call destination missing"))?,
            value,
        );
    }
    Ok(())
}

// 確保の結果を保存してから通知する。opcode を振り分けの後まで保持しない
// （10-09「呼び出しの前の安全点」、ADR 0263 の決定 4）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn after_alloc(state: &mut RunState, ctx: &NoGcCtx<'_>) -> Control {
    notify_collect(state, ctx);
    Control::Next
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn notify_collect(state: &mut RunState, ctx: &NoGcCtx<'_>) {
    if ctx.take_collect_signal() {
        state.budget.interrupt();
    }
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn index(n: u32) -> Result<usize, Stop> {
    usize::try_from(n).map_err(|_| missing("index exceeds usize"))
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn reg_ref(window: &[Slot], reg: u16) -> Result<&Slot, Stop> {
    window
        .get(usize::from(reg))
        .ok_or_else(|| missing("register outside current window"))
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn reg_mut(window: &mut [Slot], reg: u16) -> Result<&mut Slot, Stop> {
    window
        .get_mut(usize::from(reg))
        .ok_or_else(|| missing("register outside current window"))
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn write<'e>(ctx: &NoGcCtx<'e>, window: &mut [Slot], reg: u16, v: Value<'e>) -> Result<(), Stop> {
    ctx.store(reg_mut(window, reg)?, v);
    Ok(())
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn reg_range(start: u16, count: u16) -> Result<std::ops::Range<usize>, Stop> {
    let end = u32::from(start)
        .checked_add(u32::from(count))
        .ok_or_else(|| missing("register range overflow"))?;
    if end > u32::from(u16::MAX).saturating_add(1) {
        return Err(missing("register range overflow"));
    }
    Ok(usize::from(start)..index(end)?)
}

// 組み込みの引数の上限は表のテストで確かめる。大きな構築は Vec に退避する（R15 手順 2）。
const INLINE_OPERANDS: usize = 8;
enum Operands<'e> {
    Inline {
        values: [Value<'e>; INLINE_OPERANDS],
        len: usize,
    },
    Many(Vec<Value<'e>>),
}
impl<'e> Operands<'e> {
    fn new(len: usize) -> Self {
        if len <= INLINE_OPERANDS {
            Self::Inline {
                values: [Value::Unit; INLINE_OPERANDS],
                len,
            }
        } else {
            Self::Many(vec![Value::Unit; len])
        }
    }
    fn as_mut_slice(&mut self) -> &mut [Value<'e>] {
        match self {
            Self::Inline { values, len } => values.get_mut(..*len).unwrap_or_default(),
            Self::Many(values) => values,
        }
    }
}
impl<'e> std::ops::Deref for Operands<'e> {
    type Target = [Value<'e>];
    fn deref(&self) -> &Self::Target {
        match self {
            Self::Inline { values, len } => values.get(..*len).unwrap_or_default(),
            Self::Many(values) => values,
        }
    }
}

fn read_range<'e>(
    ctx: &NoGcCtx<'e>,
    window: &mut [Slot],
    range: &std::ops::Range<usize>,
) -> Result<Operands<'e>, Stop> {
    let slots = window
        .get(range.clone())
        .ok_or_else(|| missing("operand range missing"))?;
    let mut values = Operands::new(slots.len());
    for (dst, src) in values.as_mut_slice().iter_mut().zip(slots) {
        *dst = ctx.load(src);
    }
    Ok(values)
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn read_one<'e>(ctx: &NoGcCtx<'e>, window: &[Slot], reg: u16) -> Result<Value<'e>, Stop> {
    Ok(ctx.load(reg_ref(window, reg)?))
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn require_func<'e>(ctx: &NoGcCtx<'e>, value: Value<'e>) -> Result<u32, Stop> {
    match ctx.fields_header(value) {
        Some((FieldsKind::Func, proto)) => Ok(proto),
        _ => Err(missing("function value required")),
    }
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn jump_target(locals: &LoopLocals<'_>, offset: i32) -> Result<u32, Stop> {
    let target = i64::from(locals.pc)
        .checked_add(1)
        .and_then(|pc| pc.checked_add(i64::from(offset)))
        .ok_or_else(|| missing("jump overflow"))?;
    let target = u32::try_from(target).map_err(|_| missing("negative jump target"))?;
    if index(target)? >= locals.code.len() {
        return Err(missing("jump outside code"));
    }
    Ok(target)
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn integer_value(value: Value<'_>) -> Result<i64, Stop> {
    value
        .as_int()
        .ok_or_else(|| missing("integer operand required"))
}
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn float_value(value: Value<'_>) -> Result<f64, Stop> {
    value
        .as_float()
        .ok_or_else(|| missing("float operand required"))
}
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn character_value(value: Value<'_>) -> Result<char, Stop> {
    value
        .as_char()
        .ok_or_else(|| missing("character operand required"))
}
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn boolean_value(value: Value<'_>) -> Result<bool, Stop> {
    value
        .as_bool()
        .ok_or_else(|| missing("Boolean operand required"))
}
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn byte_value(value: Value<'_>) -> Result<u8, Stop> {
    value
        .as_byte()
        .ok_or_else(|| missing("Byte operand required"))
}
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn integer_result<'e>(value: Option<i64>) -> Result<Value<'e>, Stop> {
    value.map(Value::Int).ok_or_else(integer_overflow)
}

// 成功のたびに RuntimeError の後始末をしない（R17 の手順 2）。
#[cold]
#[inline(never)]
fn integer_overflow() -> Stop {
    Stop::Runtime(RuntimeError::IntegerOverflow)
}

// 同じレジスタを二度使う命令でも、書き込みの前に両方を読む（10-07、ADR 0314）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn read_pair<'e>(
    ctx: &NoGcCtx<'e>,
    window: &mut [Slot],
    a: u16,
    b: u16,
) -> Result<[Value<'e>; 2], Stop> {
    let values = [ctx.load(reg_ref(window, a)?), ctx.load(reg_ref(window, b)?)];
    Ok(values)
}

// 子を持たない即値は根の表を使わずに作る（実装プラン 10-07「定数の記述」）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn immediate_constant<'e>(
    program: &CompiledProgram,
    desc: &ConstDesc,
) -> Result<Option<Value<'e>>, Stop> {
    Ok(match desc {
        ConstDesc::Int(n) => Some(Value::Int(*n)),
        ConstDesc::Float(n) => Some(Value::Float(*n)),
        ConstDesc::Char(c) => Some(Value::Char(*c)),
        ConstDesc::Bool(b) => Some(Value::Bool(*b)),
        ConstDesc::Unit => Some(Value::Unit),
        ConstDesc::Byte(b) => Some(Value::Byte(*b)),
        ConstDesc::Ctor { ctor, args } => {
            if args.is_empty() {
                let ctor = program
                    .ctor(*ctor)
                    .ok_or_else(|| missing("constant constructor missing"))?;
                if ctor.arity != 0 {
                    return Err(missing("constant constructor arity mismatch"));
                }
                Some(Value::Tag(CtorTag(ctor.tag)))
            } else {
                None
            }
        }
        ConstDesc::List(args) => args.is_empty().then_some(Value::EmptyList),
        ConstDesc::Str(_)
        | ConstDesc::Func(_)
        | ConstDesc::Decimal { .. }
        | ConstDesc::Map(_)
        | ConstDesc::Set(_)
        | ConstDesc::Dict(_) => None,
    })
}

// ヒープの値だけを根の表へ置き、組み立て中の子は局所の積み重ねに残す。
// 区間の中では回収が起きず、深い定数でも Rust の再帰を使わない
// （設計書 02-07「定数表」、実装プラン 10-07「定数の記述」）。
fn constant<'e>(
    program: &CompiledProgram,
    constants: &mut [Option<Slot>],
    ctx: &NoGcCtx<'e>,
    wanted: ConstIdx,
) -> Result<Value<'e>, Stop> {
    let desc = program
        .constant(wanted)
        .ok_or_else(|| missing("constant description missing"))?;
    if let Some(value) = immediate_constant(program, desc)? {
        return Ok(value);
    }
    if let Some(slot) = constants
        .get(index(wanted.0)?)
        .ok_or_else(|| missing("constant cache index missing"))?
    {
        return Ok(ctx.load(slot));
    }
    let mut work = vec![(wanted, false)];
    let mut values = Vec::new();
    while let Some((idx, ready)) = work.pop() {
        if let Some(slot) = constants
            .get(index(idx.0)?)
            .ok_or_else(|| missing("constant cache index missing"))?
        {
            values.push(ctx.load(slot));
            continue;
        }
        let desc = program
            .constant(idx)
            .ok_or_else(|| missing("constant description missing"))?;
        if let Some(value) = immediate_constant(program, desc)? {
            values.push(value);
            continue;
        }
        let children = match desc {
            ConstDesc::Ctor { args, .. } | ConstDesc::List(args) | ConstDesc::Set(args) => {
                args.clone()
            }
            ConstDesc::Map(pairs) => pairs.iter().flat_map(|&(k, v)| [k, v]).collect(),
            ConstDesc::Int(_)
            | ConstDesc::Float(_)
            | ConstDesc::Str(_)
            | ConstDesc::Char(_)
            | ConstDesc::Bool(_)
            | ConstDesc::Unit
            | ConstDesc::Byte(_)
            | ConstDesc::Func(_)
            | ConstDesc::Decimal { .. }
            | ConstDesc::Dict(_) => Vec::new(),
        };
        if !ready && !children.is_empty() {
            work.push((idx, true));
            for &child in children.iter().rev() {
                if child.0 >= idx.0 {
                    return Err(missing("constant child is not before parent"));
                }
                work.push((child, false));
            }
            continue;
        }
        let start = values
            .len()
            .checked_sub(children.len())
            .ok_or_else(|| missing("constant child missing"))?;
        let args = values.split_off(start);
        let value = match desc {
            ConstDesc::Str(s) => ctx.alloc_str(s, "LOADK")?,
            ConstDesc::Func(p) => {
                let proto = program
                    .proto(*p)
                    .ok_or_else(|| missing("constant prototype missing"))?;
                if !proto.captures.is_empty() {
                    return Err(missing("constant function requires captures"));
                }
                ctx.alloc_fields(FieldsKind::Func, p.0, &[])?
            }
            ConstDesc::Ctor { ctor, .. } => {
                let ctor = program
                    .ctor(*ctor)
                    .ok_or_else(|| missing("constant constructor missing"))?;
                if args.len() != usize::from(ctor.arity) {
                    return Err(missing("constant constructor arity mismatch"));
                }
                ctx.alloc_fields(FieldsKind::Ctor, ctor.tag, &args)?
            }
            ConstDesc::List(_) => list::from_values(ctx, &args, "LOADK")?,
            ConstDesc::Dict(imp) => traits::alloc_dict(program, ctx, *imp, &[])?,
            ConstDesc::Int(_)
            | ConstDesc::Float(_)
            | ConstDesc::Char(_)
            | ConstDesc::Bool(_)
            | ConstDesc::Unit
            | ConstDesc::Byte(_) => {
                return Err(missing("immediate constant reached heap construction"));
            }
            ConstDesc::Decimal { mantissa, scale } => numeric::constant(ctx, *mantissa, *scale)?,
            ConstDesc::Map(_) => collections::map_constant(ctx, &args)?,
            ConstDesc::Set(_) => collections::set_constant(ctx, &args)?,
        };
        *constants
            .get_mut(index(idx.0)?)
            .ok_or_else(|| missing("constant cache index missing"))? = Some(ctx.new_slot(value));
        values.push(value);
    }
    values
        .pop()
        .ok_or_else(|| missing("built constant missing"))
}

fn main_outcome<'e>(
    kind: MainKind,
    ctx: &NoGcCtx<'e>,
    value: Value<'e>,
) -> Result<MainOutcome, Stop> {
    match kind {
        MainKind::Unit => {
            if matches!(value, Value::Unit) {
                Ok(MainOutcome::Ok)
            } else {
                Err(missing("main did not return Unit"))
            }
        }
        MainKind::Result => {
            if ctx.fields_len(value) != Some(1) {
                return Err(missing("main result arity mismatch"));
            }
            let arg = ctx
                .field(value, 0)
                .ok_or_else(|| missing("main result argument missing"))?;
            match ctx.fields_header(value) {
                Some((FieldsKind::Ctor, tags::RESULT_OK)) if matches!(arg, Value::Unit) => {
                    Ok(MainOutcome::Ok)
                }
                Some((FieldsKind::Ctor, tags::RESULT_ERROR)) => ctx
                    .str(arg)
                    .map(|s| MainOutcome::Error(s.to_owned()))
                    .ok_or_else(|| missing("main error is not String")),
                _ => Err(missing("main did not return Result[Unit, String]")),
            }
        }
    }
}

#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn pop_call(state: &mut RunState, ctx: &NoGcCtx<'_>) -> Result<(), Stop> {
    let segment = state.segment_mut()?;
    let frame = segment
        .calls
        .pop()
        .ok_or_else(|| missing("call frame missing"))?;
    let base = index(frame.base)?;
    let size = frame.size;
    let end = base
        .checked_add(index(size)?)
        .ok_or_else(|| missing("window overflow"))?;
    for slot in segment
        .regs
        .get_mut(base..end)
        .ok_or_else(|| missing("return window missing"))?
    {
        ctx.clear(slot);
    }
    segment.regs.truncate(base);
    ctx.discard(frame);
    state.meter.shrink(1, u64::from(size));
    Ok(())
}

#[cold]
#[inline(never)]
fn cleanup(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> LoopExit {
    unwinding::cleanup(state, ctx)
}

#[cfg(test)]
// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::bytecode::asm::ProgramBuilder;
    use crate::runtime::heap::HeapConfig;
    use crate::runtime::io::services::RunInput;
    use crate::vm::Vm;
    use crate::vm::dispatch::test_support::TestIo;

    // R09 が明示的に認める、まだ本体のない Process.exit の代わりの組み込み宣言。
    crate::builtins::iface::builtin! {
        /// 止める手順へ終了状態を引き渡す受け入れテスト用の宣言。
        name = "R09.exit",
        io fn exit(ctx, _status: i64) -> crate::builtins::iface::IoReply<'e> {
            let _ = ctx;
            Ok(crate::builtins::iface::IoReply::Exit(crate::builtins::iface::ExitStatus(17)))
        }
    }

    // 関門: 宣言の引数がスタック上の保存領域に収まる契約を守る（R15 手順 2）。
    // 一覧の複写ではなく、本番の登録の表を上限に照らす。範囲を超えても VM は Vec に退避する。
    #[test]
    fn registered_builtin_arguments_fit_inline_operands() {
        for decl in crate::builtins::funcs::PARTS
            .iter()
            .flat_map(|part| part.iter())
        {
            assert!(usize::from(decl.arity) <= INLINE_OPERANDS, "{}", decl.name);
        }
    }

    #[test]
    fn builtin_exit_finishes_the_stop_procedure_with_its_status() {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        let exit_ref = b
            .named_builtin("Benitoite.IO.Process.exit", 1, Capability::Io, None)
            .unwrap();
        b.loadk(main, 0, ConstDesc::Int(17)).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 1, u16::try_from(exit_ref.0).unwrap(), 0);
        b.code(main).unwrap().ret(1);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut services = TestIo::new(RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        });
        services
            .rt
            .builtin_overrides
            .insert(p.builtin(exit_ref).unwrap().id, &exit::DECL);
        assert_eq!(
            vm.run(services.runtime(ExecMode::Direct)),
            VmStep::Stopped(StopEnd {
                reason: StopReason::Exit(17),
                release_failures: vec![]
            })
        );
        assert!(vm.state.stack.segments.is_empty());
        assert!(services.take_output().is_empty());
        vm.heap.collect(&vm.state);
        assert!(vm.heap.object_ids().is_empty());
        assert!(vm.heap.take_fault().is_none());
    }
}

#[cfg(test)]
pub(crate) mod test_support;

impl<'p> Vm<'p> {
    /// 最初のタスクを実行する。直接呼び出しの方式では `VmStep::Requests` を返さない。
    pub(crate) fn run_io(&mut self, rt: &mut IoRuntime) -> VmStep {
        if let Some(step) = &self.state.step
            && !matches!(step, VmStep::Requests(_))
        {
            return step.clone();
        }
        self.state.step = None;
        #[cfg(test)]
        if let Some(parts) = self.state.scheduling.test_parts.take() {
            rt.parts = parts;
        }
        if !rt.main_announced
            && let Some(main) = self.state.scheduling.main
        {
            rt.parts.picker.spawned(0, main);
            rt.main_announced = true;
        }
        if !self.state.started {
            self.state
                .fail(super::state::internal("VM has not started"), None);
        }
        loop {
            if let Some(fault) = self.heap.take_fault() {
                let at = self.state.frame().ok().map(|f| super::InstrRef {
                    proto: f.proto,
                    pc: f.pc,
                });
                self.state
                    .fail(crate::runtime::Stop::Internal(fault.detail), at);
            }
            let exit = self.heap.epoch(|ctx| {
                super::dispatch::run_epoch(self.program, self.config, &mut self.state, ctx, rt)
            });
            if let Some(fault) = self.heap.take_fault() {
                self.state
                    .fail(crate::runtime::Stop::Internal(fault.detail), None);
                self.state.step = None;
                continue;
            }
            match exit {
                super::dispatch::LoopExit::Collect => {
                    self.heap.collect(&self.state);
                    if let Some(fault) = self.heap.take_fault() {
                        self.state.fail(
                            crate::runtime::Stop::Internal(fault.detail),
                            self.state.precall_done,
                        );
                    } else if self.state.precall_done.is_some() {
                        // 呼び出しの遅い経路は回収後に終える。戻りと止める手順の回収では
                        // 予算を数えない（実装プラン R09「予算と要求の知らせ」）。
                        if let Err(stop) = super::dispatch::tasks::slow_path_end(
                            &mut self.state,
                            self.config.call_budget,
                        ) {
                            self.state.fail(stop, self.state.precall_done);
                        }
                    }
                }
                super::dispatch::LoopExit::Return => {
                    if let Some(step) = &self.state.step {
                        return step.clone();
                    }
                    self.state.fail(
                        super::state::internal("dispatch returned without result"),
                        None,
                    );
                }
            }
        }
    }

    #[cold]
    #[inline(never)]
    pub(crate) fn serve_io(&mut self, rt: &mut IoRuntime, id: super::RequestId) {
        let result = self
            .heap
            .epoch(|ctx| tasks::io::serve(self.program, &mut self.state, ctx, rt, id));
        if let Err(stop) = result {
            self.state.fail(stop, None);
            // 外側は同じ一括の次の番号も処理する。次の serve より先に失効を反映する（10-10）。
            self.state.scheduling.expire_io = true;
        }
        if let Some(fault) = self.heap.take_fault() {
            self.state.fail(Stop::Internal(fault.detail), None);
            self.state.scheduling.expire_io = true;
        }
    }
}
