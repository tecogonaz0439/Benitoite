//! 型クラスの辞書とメソッドの呼び出し（設計書 02-07「辞書とメソッドの呼び出し」、02-08「実行の手順」）。

use crate::bytecode::program::{DictRecipe, ImplIdx, ImplInfo};

use super::{
    CallFrame, CompiledProgram, Control, Cursor, FieldsKind, Instr, NoGcCtx, Opcode, RunState,
    Slot, Stop, Value, VmConfig, active_window, index, missing, read_one, reg_range, reg_ref,
    write,
};

fn dict_info<'p, 'e>(
    program: &'p CompiledProgram,
    ctx: &NoGcCtx<'e>,
    value: Value<'e>,
) -> Result<&'p ImplInfo, Stop> {
    let Some((FieldsKind::Dict, imp)) = ctx.fields_header(value) else {
        return Err(missing("dictionary value required"));
    };
    let info = program
        .impl_info(ImplIdx(imp))
        .ok_or_else(|| missing("dictionary implementation missing"))?;
    if ctx.fields_len(value) != Some(u32::from(info.dict_arity)) {
        return Err(missing("dictionary constraint count mismatch"));
    }
    Ok(info)
}

/// 定数と辞書の式も、DICT と同じ実装の制約の数を確かめて作る。
pub(super) fn alloc_dict<'e>(
    program: &CompiledProgram,
    ctx: &NoGcCtx<'e>,
    imp: ImplIdx,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let info = program
        .impl_info(imp)
        .ok_or_else(|| missing("dictionary implementation missing"))?;
    if args.len() != usize::from(info.dict_arity) {
        return Err(missing("dictionary constraint count mismatch"));
    }
    for &arg in args {
        dict_info(program, ctx, arg)?;
    }
    ctx.alloc_fields(FieldsKind::Dict, imp.0, args)
}

/// メソッドの枠が持つ辞書から、実装の制約の辞書を読む。
#[inline(never)]
pub(super) fn get_dict(
    window: &mut [Slot],
    calls: &[CallFrame],
    ctx: &NoGcCtx<'_>,
    instr: Instr,
) -> Result<(), Stop> {
    let dict = ctx.load(
        &calls
            .last()
            .ok_or_else(|| missing("call frame missing"))?
            .func,
    );
    if !matches!(ctx.fields_header(dict), Some((FieldsKind::Dict, _))) {
        return Err(missing("GETDICT requires a dictionary call frame"));
    }
    let value = ctx
        .field(dict, u32::from(instr.b()))
        .ok_or_else(|| missing("implementation constraint missing"))?;
    if !matches!(ctx.fields_header(value), Some((FieldsKind::Dict, _))) {
        return Err(missing("implementation constraint is not a dictionary"));
    }
    write(ctx, window, instr.a(), value)
}

/// 連続したレジスタの制約の辞書で、実装の辞書を作る。
#[inline(never)]
pub(super) fn dict(
    program: &CompiledProgram,
    window: &mut [Slot],
    ctx: &NoGcCtx<'_>,
    instr: Instr,
) -> Result<(), Stop> {
    let imp = ImplIdx(u32::from(instr.b()));
    let info = program
        .impl_info(imp)
        .ok_or_else(|| missing("dictionary implementation missing"))?;
    let regs = reg_range(instr.c(), info.dict_arity)?;
    let args = super::read_range(ctx, window, &regs)?;
    let value = alloc_dict(program, ctx, imp, &args)?;
    write(ctx, window, instr.a(), value)
}

/// 上位の型クラスの辞書の式を、一つの回収しない区間の中で計算する。
#[inline(never)]
pub(super) fn super_dict(
    program: &CompiledProgram,
    window: &mut [Slot],
    ctx: &NoGcCtx<'_>,
    instr: Instr,
) -> Result<(), Stop> {
    let dict = read_one(ctx, window, instr.b())?;
    let value = project_super(program, ctx, dict, instr.c())?;
    write(ctx, window, instr.a(), value)
}

fn project_super<'e>(
    program: &CompiledProgram,
    ctx: &NoGcCtx<'e>,
    dict: Value<'e>,
    index: u16,
) -> Result<Value<'e>, Stop> {
    let info = dict_info(program, ctx, dict)?;
    let recipe = info
        .supers
        .get(usize::from(index))
        .ok_or_else(|| missing("superclass dictionary recipe missing"))?;
    recipe_value(program, ctx, dict, recipe)
}

// 辞書の式はコンパイル済みプログラムの構造であり、再帰で辿ってよい。
// 計算の途中では区間を閉じないので、子の辞書を局所に保ったまま次の辞書を確保できる
// （設計書 02-07「辞書とメソッドの呼び出し」、実装プラン R34「手順の要点」）。
fn recipe_value<'e>(
    program: &CompiledProgram,
    ctx: &NoGcCtx<'e>,
    dict: Value<'e>,
    recipe: &DictRecipe,
) -> Result<Value<'e>, Stop> {
    match recipe {
        DictRecipe::Impl { imp, args } => {
            let values = args
                .iter()
                .map(|arg| recipe_value(program, ctx, dict, arg))
                .collect::<Result<Vec<_>, _>>()?;
            alloc_dict(program, ctx, *imp, &values)
        }
        DictRecipe::Param(i) => {
            dict_info(program, ctx, dict)?;
            let value = ctx
                .field(dict, u32::from(*i))
                .ok_or_else(|| missing("dictionary recipe parameter missing"))?;
            dict_info(program, ctx, value)?;
            Ok(value)
        }
        DictRecipe::Super { of, index } => {
            let value = recipe_value(program, ctx, dict, of)?;
            project_super(program, ctx, value, *index)
        }
    }
}

/// 辞書から原型を引き、切り替えの位置を通って通常または末尾の呼び出しを行う。
pub(super) fn method<'p>(
    program: &'p CompiledProgram,
    config: VmConfig,
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    cursor: &mut Cursor<'p>,
    instr: Instr,
) -> Result<Control, Stop> {
    let super::Cursor { locals, active, .. } = cursor;
    let dict = ctx.load(reg_ref(
        active_window(state.segment_mut()?, locals.base, active.size)?,
        instr.b(),
    )?);
    let info = dict_info(program, ctx, dict)?;
    let caller = active.proto;
    let trait_ = caller
        .method_traits
        .get(index(locals.pc)?)
        .copied()
        .flatten()
        .ok_or_else(|| missing("method trait annotation missing"))?;
    if info.trait_ != trait_ {
        return Err(missing("method dictionary trait mismatch"));
    }
    let arity = program
        .trait_info(trait_)
        .and_then(|t| t.methods.get(usize::from(instr.c())))
        .ok_or_else(|| missing("method trait entry missing"))?
        .arity;
    let target = *info
        .methods
        .get(usize::from(instr.c()))
        .ok_or_else(|| missing("implementation method missing"))?;
    let called = program
        .proto(target)
        .ok_or_else(|| missing("method prototype missing"))?;
    if called.num_params != arity || arity > called.num_regs || !called.captures.is_empty() {
        return Err(missing("method argument count or captures mismatch"));
    }
    let target = super::CallTarget {
        value: dict,
        index: target,
        proto: called,
        arity,
    };
    if instr.opcode() == Some(Opcode::TailMethod) {
        super::call::<true>(config, state, ctx, cursor, instr, target)
    } else {
        super::call::<false>(config, state, ctx, cursor, instr, target)
    }
}

#[cfg(test)]
mod tests;
