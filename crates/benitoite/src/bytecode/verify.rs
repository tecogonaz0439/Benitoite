//! 読み込みのときの範囲と生存の情報の検証（設計書 02-08「実行の手順」、
//! 実装プラン 10-07「読み込みのときの検証器」）。値の種類と実行中の枠は保証しない。

use crate::builtins::builtin_decl;

use super::instr::Opcode;
use super::liveness::{LiveItem, compute_liveness, reg_use};
use super::program::{
    BuiltinRefIdx, CaptureSource, ConstDesc, CtorIdx, DictRecipe, ImplIdx, OpIdx, Proto,
};

use super::program::{CompiledProgram, ProtoIdx};

/// 検証器が受け付けなかった箇所。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct VerifyError {
    pub proto: ProtoIdx,
    /// 命令の位置。原型の表の不整合では `None`
    pub pc: Option<u32>,
    pub message: String,
}

/// コンパイル済みプログラムを検証する（設計書 02-08「実行の手順」）。R32 の評価に使う。
pub fn verify(program: &CompiledProgram) -> Result<(), VerifyError> {
    verify_tables(program)?;
    for (index, proto) in program.protos.iter().enumerate() {
        let id = ProtoIdx(
            u32::try_from(index)
                .map_err(|_| error(ProtoIdx(0), None, "prototype table is too large"))?,
        );
        verify_proto(program, id, proto)?;
    }
    Ok(())
}

fn error(proto: ProtoIdx, pc: Option<u32>, message: &str) -> VerifyError {
    VerifyError {
        proto,
        pc,
        message: message.to_owned(),
    }
}

fn require(
    valid: bool,
    proto: ProtoIdx,
    pc: Option<u32>,
    message: &str,
) -> Result<(), VerifyError> {
    if valid {
        Ok(())
    } else {
        Err(error(proto, pc, message))
    }
}

fn in_table(index: u32, len: usize) -> bool {
    usize::try_from(index).is_ok_and(|i| i < len)
}

fn verify_tables(p: &CompiledProgram) -> Result<(), VerifyError> {
    // 全体の表に属する違反には main（なければ 0）を記録し、命令の位置は付けない。
    let id = p.main.unwrap_or(ProtoIdx(0));
    let check = |valid, message| require(valid, id, None, message);
    check(
        p.main.is_none_or(|main| p.proto(main).is_some()),
        "main prototype is missing",
    )?;
    for (_, proto) in &p.top_fns {
        check(p.proto(*proto).is_some(), "top-level prototype is missing")?;
    }
    for (index, desc) in p.consts.iter().enumerate() {
        let child = |k: &super::program::ConstIdx| {
            check(
                usize::try_from(k.0).is_ok_and(|i| i < index),
                "constant child must precede its parent",
            )
        };
        match desc {
            ConstDesc::Ctor { ctor, args } => {
                let info = p
                    .ctor(*ctor)
                    .ok_or_else(|| error(id, None, "constant constructor is missing"))?;
                check(
                    args.len() == usize::from(info.arity),
                    "constant constructor arity mismatch",
                )?;
                for k in args {
                    child(k)?;
                }
            }
            ConstDesc::List(items) | ConstDesc::Set(items) => {
                for k in items {
                    child(k)?;
                }
            }
            ConstDesc::Map(items) => {
                for (key, value) in items {
                    child(key)?;
                    child(value)?;
                }
            }
            ConstDesc::Func(proto) => {
                let target = p
                    .proto(*proto)
                    .ok_or_else(|| error(id, None, "constant prototype is missing"))?;
                check(
                    target.captures.is_empty(),
                    "constant function requires captures",
                )?;
            }
            ConstDesc::Dict(imp) => {
                let info = p
                    .impl_info(*imp)
                    .ok_or_else(|| error(id, None, "constant implementation is missing"))?;
                check(
                    info.dict_arity == 0,
                    "constant dictionary requires parameters",
                )?;
            }
            ConstDesc::Int(_)
            | ConstDesc::Float(_)
            | ConstDesc::Str(_)
            | ConstDesc::Char(_)
            | ConstDesc::Bool(_)
            | ConstDesc::Unit
            | ConstDesc::Byte(_)
            | ConstDesc::Decimal { .. } => {}
        }
    }
    for info in &p.traits {
        for parent in &info.supers {
            check(p.trait_info(*parent).is_some(), "supertrait is missing")?;
        }
    }
    for info in &p.impls {
        let trait_info = p
            .trait_info(info.trait_)
            .ok_or_else(|| error(id, None, "implementation trait is missing"))?;
        check(
            info.methods.len() == trait_info.methods.len(),
            "implementation method count mismatch",
        )?;
        check(
            info.supers.len() == trait_info.supers.len(),
            "implementation supertrait count mismatch",
        )?;
        for method in &info.methods {
            check(p.proto(*method).is_some(), "method prototype is missing")?;
        }
        // 辞書の式は入れ子になりうるので、Rust の再帰を使わない（実装プラン R32）。
        let mut pending: Vec<_> = info.supers.iter().collect();
        while let Some(recipe) = pending.pop() {
            match recipe {
                DictRecipe::Impl { imp, args } => {
                    let target = p.impl_info(*imp).ok_or_else(|| {
                        error(id, None, "dictionary recipe implementation is missing")
                    })?;
                    check(
                        args.len() == usize::from(target.dict_arity),
                        "dictionary recipe arity mismatch",
                    )?;
                    pending.extend(args);
                }
                DictRecipe::Param(index) => check(
                    *index < info.dict_arity,
                    "dictionary recipe parameter is missing",
                )?,
                // Param の型クラスはこの表にない。上位の位置は値の辞書で実行中に確かめる。
                DictRecipe::Super { of, index: _ } => pending.push(of),
            }
        }
    }
    for op in &p.ops {
        check(
            op.builtin.is_none_or(|idx| p.builtin(idx).is_some()),
            "operation builtin reference is missing",
        )?;
    }
    for reference in &p.builtins {
        let decl = builtin_decl(reference.id)
            .ok_or_else(|| error(id, None, "builtin declaration is missing"))?;
        check(reference.arity == decl.arity, "builtin arity mismatch")?;
        check(
            reference.capability == decl.capability,
            "builtin capability mismatch",
        )?;
        check(
            reference.op.is_none_or(|idx| p.op(idx).is_some()),
            "builtin operation is missing",
        )?;
    }
    for handler in &p.handlers {
        for clause in &handler.clauses {
            check(p.op(clause.op).is_some(), "handler operation is missing")?;
        }
    }
    Ok(())
}

fn verify_proto(p: &CompiledProgram, id: ProtoIdx, proto: &Proto) -> Result<(), VerifyError> {
    let check = |valid, message| require(valid, id, None, message);
    check(!proto.code.is_empty(), "empty prototype")?;
    check(u32::try_from(proto.code.len()).is_ok(), "code is too long")?;
    check(
        proto.num_params <= proto.num_regs,
        "parameters exceed the register window",
    )?;
    check(
        proto.positions.len() == proto.code.len(),
        "position table length mismatch",
    )?;
    check(
        proto.method_traits.len() == proto.code.len(),
        "method trait table length mismatch",
    )?;
    for constant in &proto.consts {
        check(
            p.constant(*constant).is_some(),
            "prototype constant is missing",
        )?;
    }
    for handler in &proto.handlers {
        check(
            p.handler(*handler).is_some(),
            "prototype handler is missing",
        )?;
    }
    for (index, instr) in proto.code.iter().enumerate() {
        let pc = u32::try_from(index).map_err(|_| error(id, None, "code is too long"))?;
        let check = |valid, message| require(valid, id, Some(pc), message);
        let opcode = instr
            .opcode()
            .ok_or_else(|| error(id, Some(pc), "unknown opcode"))?;
        let method = proto.method_traits.get(index).copied().flatten();
        check(
            (opcode == Opcode::Method || opcode == Opcode::TailMethod) == method.is_some(),
            "unexpected or missing method trait",
        )?;
        // 空の並びでも始点が窓の終端を越えないことを別に確かめる。
        // reg_use が空の reads に番号を加えない場合にも、スライスの範囲を保証する。
        let range = match opcode {
            Opcode::Prim | Opcode::Io => p
                .builtin(BuiltinRefIdx(u32::from(instr.b())))
                .map(|info| (instr.c(), info.arity)),
            Opcode::Con | Opcode::ConR => p
                .ctor(CtorIdx(u32::from(instr.b())))
                .map(|info| (instr.c(), info.arity)),
            Opcode::Dict => p
                .impl_info(ImplIdx(u32::from(instr.b())))
                .map(|info| (instr.c(), info.dict_arity)),
            Opcode::Perform => p
                .op(OpIdx(u32::from(instr.b())))
                .map(|info| (instr.c(), info.arity)),
            Opcode::List => Some((instr.b(), instr.c())),
            Opcode::Move
            | Opcode::LoadK
            | Opcode::GetCap
            | Opcode::Closure
            | Opcode::Call
            | Opcode::TailCall
            | Opcode::Return
            | Opcode::Escape
            | Opcode::GetDict
            | Opcode::Super
            | Opcode::Method
            | Opcode::TailMethod
            | Opcode::AddI
            | Opcode::SubI
            | Opcode::MulI
            | Opcode::DivI
            | Opcode::ModI
            | Opcode::NegI
            | Opcode::AddF
            | Opcode::SubF
            | Opcode::MulF
            | Opcode::DivF
            | Opcode::NegF
            | Opcode::AddD
            | Opcode::SubD
            | Opcode::MulD
            | Opcode::DivD
            | Opcode::NegD
            | Opcode::Concat
            | Opcode::EqI
            | Opcode::LtI
            | Opcode::LeI
            | Opcode::EqF
            | Opcode::LtF
            | Opcode::LeF
            | Opcode::EqD
            | Opcode::LtD
            | Opcode::LeD
            | Opcode::EqS
            | Opcode::LtS
            | Opcode::LeS
            | Opcode::EqC
            | Opcode::LtC
            | Opcode::LeC
            | Opcode::EqBt
            | Opcode::LtBt
            | Opcode::LeBt
            | Opcode::EqB
            | Opcode::EqV
            | Opcode::Not
            | Opcode::Field
            | Opcode::Jmp
            | Opcode::JmpF
            | Opcode::Switch
            | Opcode::Lazy
            | Opcode::Force
            | Opcode::Update
            | Opcode::Use
            | Opcode::Release
            | Opcode::Handle
            | Opcode::Resume => None,
        };
        if let Some((start, count)) = range {
            check(
                u32::from(start).saturating_add(u32::from(count)) <= u32::from(proto.num_regs),
                "argument range outside window",
            )?;
        }
        // reg_use は全命令の読み書きと、表の arity に従う引数の並びを検査する。
        // 実行器と検証器で引数の数を別々に定義しない（10-07「生存の情報」）。
        reg_use(p, id, pc).map_err(|e| error(e.proto, Some(e.pc), &e.message))?;
        match opcode {
            Opcode::LoadK => check(
                proto.constant(instr.bx()).is_some(),
                "local constant index is missing",
            )?,
            Opcode::GetCap => check(
                usize::from(instr.b()) < proto.captures.len(),
                "capture index is missing",
            )?,
            Opcode::Closure | Opcode::Lazy => {
                let target = p
                    .proto(ProtoIdx(instr.bx()))
                    .ok_or_else(|| error(id, Some(pc), "closure prototype is missing"))?;
                for source in &target.captures {
                    check(
                        match source {
                            CaptureSource::Reg(reg) => *reg < proto.num_regs,
                            CaptureSource::Capture(capture) => {
                                usize::from(*capture) < proto.captures.len()
                            }
                        },
                        "closure capture source is missing",
                    )?;
                }
            }
            Opcode::Switch => {
                let table = proto
                    .switch_table(instr.bx())
                    .ok_or_else(|| error(id, Some(pc), "switch table is missing"))?;
                for offset in table.targets.iter().chain([&table.default]).flatten() {
                    check(
                        jump_in_code(pc, *offset, proto.code.len()),
                        "switch target is outside the code",
                    )?;
                }
            }
            Opcode::Jmp | Opcode::JmpF => check(
                jump_in_code(pc, instr.sbx(), proto.code.len()),
                "jump target is outside the code",
            )?,
            Opcode::Method | Opcode::TailMethod => {
                check(
                    method.is_some_and(|idx| p.trait_info(idx).is_some()),
                    "method trait is missing",
                )?;
            }
            Opcode::Move
            | Opcode::Call
            | Opcode::TailCall
            | Opcode::Return
            | Opcode::Prim
            | Opcode::Io
            | Opcode::Escape
            | Opcode::GetDict
            | Opcode::Dict
            | Opcode::Super
            | Opcode::AddI
            | Opcode::SubI
            | Opcode::MulI
            | Opcode::DivI
            | Opcode::ModI
            | Opcode::NegI
            | Opcode::AddF
            | Opcode::SubF
            | Opcode::MulF
            | Opcode::DivF
            | Opcode::NegF
            | Opcode::AddD
            | Opcode::SubD
            | Opcode::MulD
            | Opcode::DivD
            | Opcode::NegD
            | Opcode::Concat
            | Opcode::EqI
            | Opcode::LtI
            | Opcode::LeI
            | Opcode::EqF
            | Opcode::LtF
            | Opcode::LeF
            | Opcode::EqD
            | Opcode::LtD
            | Opcode::LeD
            | Opcode::EqS
            | Opcode::LtS
            | Opcode::LeS
            | Opcode::EqC
            | Opcode::LtC
            | Opcode::LeC
            | Opcode::EqBt
            | Opcode::LtBt
            | Opcode::LeBt
            | Opcode::EqB
            | Opcode::EqV
            | Opcode::Not
            | Opcode::Con
            | Opcode::List
            | Opcode::Field
            | Opcode::ConR
            | Opcode::Force
            | Opcode::Update
            | Opcode::Use
            | Opcode::Release
            | Opcode::Handle
            | Opcode::Perform
            | Opcode::Resume => {}
        }
        if index.saturating_add(1) == proto.code.len() {
            check(
                matches!(
                    opcode,
                    Opcode::Return
                        | Opcode::TailCall
                        | Opcode::TailMethod
                        | Opcode::Escape
                        | Opcode::Jmp
                        | Opcode::Switch
                ),
                "last instruction falls through",
            )?;
        }
    }
    verify_live(id, proto)?;
    let computed = compute_liveness(p, id).map_err(|e| error(e.proto, Some(e.pc), &e.message))?;
    require(
        proto.live == computed,
        id,
        None,
        "liveness does not match the code",
    )?;
    require(
        proto
            .live
            .live_in_at(0)
            .is_some_and(|regs| regs.iter().all(|reg| *reg < proto.num_params)),
        id,
        Some(0),
        "entry reads a non-parameter register",
    )
}

fn jump_in_code(pc: u32, offset: i32, len: usize) -> bool {
    i64::from(pc)
        .checked_add(1)
        .and_then(|n| n.checked_add(i64::from(offset)))
        .and_then(|n| usize::try_from(n).ok())
        .is_some_and(|n| n < len)
}

fn verify_live(id: ProtoIdx, proto: &Proto) -> Result<(), VerifyError> {
    let live = &proto.live;
    let check = |valid, message| require(valid, id, None, message);
    for (starts, len) in [
        (&live.starts, live.items.len()),
        (&live.live_in_starts, live.live_in.len()),
    ] {
        check(
            starts.len() == proto.code.len().saturating_add(1),
            "liveness starts length mismatch",
        )?;
        check(
            starts.first() == Some(&0)
                && starts
                    .last()
                    .is_some_and(|last| usize::try_from(*last) == Ok(len)),
            "liveness endpoints mismatch",
        )?;
        check(
            starts.windows(2).all(|pair| pair.first() <= pair.get(1)),
            "liveness starts are not monotonic",
        )?;
    }
    check(
        live.call_writes.len() == proto.code.len(),
        "call writes length mismatch",
    )?;
    check(
        live.call_writes
            .iter()
            .flatten()
            .all(|reg| *reg < proto.num_regs),
        "call write register outside window",
    )?;
    check(
        live.items.iter().all(|item| match item {
            LiveItem::Dead { reg } | LiveItem::LastUse { reg, .. } => *reg < proto.num_regs,
        }),
        "liveness item outside window",
    )?;
    for index in 0..proto.code.len() {
        let pc = u32::try_from(index).map_err(|_| error(id, None, "code is too long"))?;
        let regs = live
            .live_in_at(pc)
            .ok_or_else(|| error(id, Some(pc), "live-in range is missing"))?;
        require(
            regs.iter().all(|reg| *reg < proto.num_regs)
                && regs.windows(2).all(|pair| pair.first() < pair.get(1)),
            id,
            Some(pc),
            "live-in registers are outside window or unordered",
        )?;
    }
    Ok(())
}

#[cfg(test)]
// 検証器の公開の結果を確かめる。壊した表と位置を直接指定する準備には添字と panic を使う。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::{BindingId, SourceTable};
    use crate::builtins::iface::Capability;
    use crate::builtins::{BuiltinId, lookup_builtin};
    use crate::bytecode::instr::Instr;
    use crate::bytecode::liveness::LiveInfo;
    use crate::bytecode::program::*;
    use std::sync::Arc;

    fn proto(code: Vec<Instr>, params: u16, regs: u16) -> Proto {
        Proto {
            name: "fixture".into(),
            origin: ProtoOrigin::UserFn,
            span: None,
            boundary: true,
            positions: vec![None; code.len()],
            method_traits: vec![None; code.len()],
            code,
            consts: vec![ConstIdx(0)],
            switch_tables: vec![SwitchTable {
                targets: vec![Some(0)],
                default: Some(0),
            }],
            handlers: vec![HandlerIdx(0)],
            num_regs: regs,
            num_params: params,
            captures: vec![CaptureSource::Reg(0)],
            live: LiveInfo::default(),
        }
    }

    fn refresh(p: &mut CompiledProgram) {
        for index in 0..p.protos.len() {
            p.protos[index].live =
                compute_liveness(p, ProtoIdx(u32::try_from(index).unwrap())).unwrap();
        }
    }

    fn fixture(instr: Instr) -> CompiledProgram {
        let mut main = proto(vec![instr, Instr::abc(Opcode::Return, 0, 0, 0)], 16, 16);
        if matches!(instr.opcode(), Some(Opcode::Method | Opcode::TailMethod)) {
            main.method_traits[0] = Some(TraitIdx(0));
        }
        let mut captured = proto(
            vec![
                Instr::abc(Opcode::GetCap, 0, 0, 0),
                Instr::abc(Opcode::Return, 0, 0, 0),
            ],
            0,
            1,
        );
        captured.captures = vec![CaptureSource::Reg(0), CaptureSource::Capture(0)];
        let mut method = proto(vec![Instr::abc(Opcode::Return, 0, 0, 0)], 1, 1);
        method.captures.clear();
        let mut p = CompiledProgram {
            protos: vec![main, captured, method],
            consts: vec![ConstDesc::Unit],
            top_fns: vec![(BindingId(0), ProtoIdx(2))],
            ctors: vec![CtorInfo {
                type_name: "T".into(),
                ctor_name: "C".into(),
                tag: 0,
                arity: 1,
            }],
            traits: vec![TraitInfo {
                name: "T".into(),
                methods: vec![MethodInfo {
                    name: "m".into(),
                    arity: 1,
                }],
                supers: vec![TraitIdx(0)],
            }],
            impls: vec![ImplInfo {
                name: "T[Unit]".into(),
                trait_: TraitIdx(0),
                dict_arity: 1,
                methods: vec![ProtoIdx(2)],
                supers: vec![DictRecipe::Param(0)],
            }],
            ops: vec![OpInfo {
                name: "Console.writeLine".into(),
                effect: "Console.Write".into(),
                arity: 1,
                builtin: Some(BuiltinRefIdx(1)),
            }],
            builtins: vec![
                BuiltinRef {
                    id: lookup_builtin("String.byteLength").unwrap(),
                    arity: 1,
                    capability: Capability::Pure,
                    op: None,
                },
                BuiltinRef {
                    id: lookup_builtin("Benitoite.IO.Console.writeLine").unwrap(),
                    arity: 1,
                    capability: Capability::Io,
                    op: Some(OpIdx(0)),
                },
            ],
            handlers: vec![HandlerDesc {
                clauses: vec![ClauseDesc {
                    op: OpIdx(0),
                    tail_resumptive: false,
                }],
            }],
            main: Some(ProtoIdx(0)),
            main_kind: MainKind::Unit,
            sources: Arc::new(SourceTable::new()),
        };
        refresh(&mut p);
        p
    }

    // 関門: 68 命令の読み書きと表から求める引数の数の契約を verify の境界で守る。
    // 生存解析のテストは検証器の受理・拒否、VerifyError の位置を確かめていない。
    #[test]
    fn every_opcode_accepts_valid_operands_and_rejects_outside_registers() {
        let mut tested = 0;
        for byte in 0..=u8::MAX {
            let Some(op) = Instr(u64::from(byte)).opcode() else {
                continue;
            };
            let instr = if op == Opcode::Closure || op == Opcode::Lazy {
                Instr::abx(op, 1, 1)
            } else if op == Opcode::Io {
                Instr::abc(op, 1, 1, 0)
            } else if op == Opcode::Jmp || op == Opcode::JmpF {
                Instr::asbx(op, 0, 0)
            } else if op == Opcode::LoadK || op == Opcode::Switch {
                Instr::abx(op, 1, 0)
            } else {
                Instr::abc(op, 1, 0, 0)
            };
            let p = fixture(instr);
            assert_eq!(verify(&p), Ok(()), "{op:?}");
            let usage = reg_use(&p, ProtoIdx(0), 0).unwrap();
            if usage.write.is_some()
                || matches!(
                    op,
                    Opcode::Return | Opcode::Escape | Opcode::JmpF | Opcode::Switch | Opcode::Use
                )
            {
                let mut broken = fixture(instr);
                broken.protos[0].code[0] = Instr((instr.0 & !(0xffff << 8)) | (16 << 8));
                let err = verify(&broken).unwrap_err();
                assert_eq!((err.proto, err.pc), (ProtoIdx(0), Some(0)), "{op:?}");
                assert!(err.message.contains("window"), "{op:?}: {err:?}");
            }
            tested += 1;
        }
        assert_eq!(tested, 68);
        // 空の引数の並びは窓の終端から始めてよい。
        let p = fixture(Instr::abc(Opcode::List, 1, 16, 0));
        assert_eq!(verify(&p), Ok(()));
    }

    type Mutation = (&'static str, Option<u32>, fn(&mut CompiledProgram));

    // 関門: 範囲を省く根拠となる各表と生存の情報を一か所ずつ壊す。別の検査に
    // 拒まれても通らないように、違反の種類と命令の位置も確認する（実装プラン R32）。
    #[test]
    fn rejects_table_and_liveness_contract_violations_at_the_right_site() {
        let cases: &[Mutation] = &[
            ("main prototype", None, |p| p.main = Some(ProtoIdx(99))),
            ("top-level prototype", None, |p| {
                p.top_fns[0].1 = ProtoIdx(99)
            }),
            ("parameters", None, |p| p.protos[0].num_params = 17),
            ("position table", None, |p| {
                p.protos[0].positions.pop();
            }),
            ("method trait table", None, |p| {
                p.protos[0].method_traits.pop();
            }),
            ("empty prototype", None, |p| p.protos[0].code.clear()),
            ("prototype constant", None, |p| {
                p.protos[0].consts[0] = ConstIdx(99)
            }),
            ("prototype handler", None, |p| {
                p.protos[0].handlers[0] = HandlerIdx(99)
            }),
            ("unknown opcode", Some(0), |p| {
                p.protos[0].code[0] = Instr(255)
            }),
            ("local constant", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::LoadK, 1, 99)
            }),
            ("capture index", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::GetCap, 1, 99, 0)
            }),
            ("captured prototype", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::Closure, 1, 99)
            }),
            ("closure capture", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::Closure, 1, 1);
                p.protos[1].captures[1] = CaptureSource::Capture(99);
            }),
            ("window", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::Closure, 1, 1);
                p.protos[1].captures[0] = CaptureSource::Reg(99);
            }),
            ("jump target", Some(0), |p| {
                p.protos[0].code[0] = Instr::asbx(Opcode::Jmp, 0, -2)
            }),
            ("jump target", Some(0), |p| {
                p.protos[0].code[0] = Instr::asbx(Opcode::JmpF, 0, i32::MAX)
            }),
            ("switch table", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::Switch, 0, 99)
            }),
            ("switch target", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::Switch, 0, 0);
                p.protos[0].switch_tables[0].targets[0] = Some(-2);
            }),
            ("switch target", Some(0), |p| {
                p.protos[0].code[0] = Instr::abx(Opcode::Switch, 0, 0);
                p.protos[0].switch_tables[0].default = Some(i32::MAX);
            }),
            ("falls through", Some(1), |p| {
                p.protos[0].code[1] = Instr::abc(Opcode::Move, 0, 1, 0)
            }),
            ("unexpected or missing method", Some(0), |p| {
                p.protos[0].method_traits[0] = Some(TraitIdx(0))
            }),
            ("unexpected or missing method", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Method, 1, 0, 0)
            }),
            ("trait or method", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Method, 1, 0, 99);
                p.protos[0].method_traits[0] = Some(TraitIdx(0));
            }),
            ("trait or method", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::TailMethod, 0, 0, 0);
                p.protos[0].method_traits[0] = Some(TraitIdx(99));
            }),
            ("constructor is missing", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Con, 1, 99, 0)
            }),
            ("implementation is missing", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Dict, 1, 99, 0)
            }),
            ("operation is missing", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Perform, 1, 99, 0)
            }),
            ("builtin reference is missing", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Prim, 1, 99, 0)
            }),
            ("handler descriptor", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Handle, 1, 0, 99)
            }),
            ("argument range", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::List, 1, 17, 0)
            }),
            ("window", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Call, 1, 15, 1)
            }),
            ("argument range", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Con, 1, 0, 16)
            }),
            ("window", Some(0), |p| {
                p.protos[0].code[0] = Instr::abc(Opcode::Handle, 1, 15, 0)
            }),
            ("liveness starts length", None, |p| {
                p.protos[0].live.starts.pop();
            }),
            ("liveness endpoints", None, |p| {
                p.protos[0].live.starts[0] = 1
            }),
            ("liveness endpoints", None, |p| {
                p.protos[0].live.live_in_starts[2] = u32::MAX
            }),
            ("not monotonic", None, |p| {
                p.protos[0].live.starts[1] = u32::MAX
            }),
            ("liveness item", None, |p| {
                p.protos[0].live.items[0] = LiveItem::Dead { reg: 16 }
            }),
            ("call writes length", None, |p| {
                p.protos[0].live.call_writes.clear()
            }),
            ("call write register", None, |p| {
                p.protos[0].live.call_writes[0] = Some(16)
            }),
            ("live-in registers", Some(0), |p| {
                p.protos[0].live.live_in[0] = 16
            }),
            ("liveness does not match", None, |p| {
                p.protos[0].live.call_writes[0] = Some(1)
            }),
            ("supertrait is missing", None, |p| {
                p.traits[0].supers[0] = TraitIdx(99)
            }),
            ("implementation trait", None, |p| {
                p.impls[0].trait_ = TraitIdx(99)
            }),
            ("method count", None, |p| p.impls[0].methods.clear()),
            ("supertrait count", None, |p| p.impls[0].supers.clear()),
            ("method prototype", None, |p| {
                p.impls[0].methods[0] = ProtoIdx(99)
            }),
            ("recipe implementation", None, |p| {
                p.impls[0].supers[0] = DictRecipe::Impl {
                    imp: ImplIdx(99),
                    args: vec![],
                }
            }),
            ("recipe arity", None, |p| {
                p.impls[0].supers[0] = DictRecipe::Impl {
                    imp: ImplIdx(0),
                    args: vec![],
                }
            }),
            ("recipe parameter", None, |p| {
                p.impls[0].supers[0] = DictRecipe::Super {
                    of: Box::new(DictRecipe::Param(1)),
                    index: 0,
                }
            }),
            ("operation builtin", None, |p| {
                p.ops[0].builtin = Some(BuiltinRefIdx(99))
            }),
            ("builtin declaration", None, |p| {
                p.builtins[0].id = BuiltinId(u16::MAX)
            }),
            ("builtin arity", None, |p| p.builtins[0].arity = 2),
            ("builtin capability", None, |p| {
                p.builtins[0].capability = Capability::Io
            }),
            ("builtin operation", None, |p| {
                p.builtins[0].op = Some(OpIdx(99))
            }),
            ("handler operation", None, |p| {
                p.handlers[0].clauses[0].op = OpIdx(99)
            }),
        ];
        for (message, pc, mutate) in cases {
            let mut p = fixture(Instr::abc(Opcode::Move, 1, 0, 0));
            assert_eq!(verify(&p), Ok(()));
            mutate(&mut p);
            let err = verify(&p).unwrap_err();
            assert_eq!(
                (err.proto, err.pc),
                (p.main.unwrap_or(ProtoIdx(0)), *pc),
                "{message}: {err:?}"
            );
            assert!(err.message.contains(message), "expected {message}: {err:?}");
        }
        for desc in [
            ConstDesc::Ctor {
                ctor: CtorIdx(99),
                args: vec![],
            },
            ConstDesc::Ctor {
                ctor: CtorIdx(0),
                args: vec![],
            },
            ConstDesc::Ctor {
                ctor: CtorIdx(0),
                args: vec![ConstIdx(1)],
            },
            ConstDesc::List(vec![ConstIdx(1)]),
            ConstDesc::Set(vec![ConstIdx(1)]),
            ConstDesc::Map(vec![(ConstIdx(0), ConstIdx(1))]),
            ConstDesc::Map(vec![(ConstIdx(1), ConstIdx(0))]),
            ConstDesc::Func(ProtoIdx(99)),
            ConstDesc::Func(ProtoIdx(1)),
            ConstDesc::Dict(ImplIdx(99)),
            ConstDesc::Dict(ImplIdx(0)),
        ] {
            let mut p = fixture(Instr::abc(Opcode::Move, 1, 0, 0));
            p.consts.push(desc);
            let err = verify(&p).unwrap_err();
            assert_eq!(err.pc, None);
            assert!(err.message.starts_with("constant"), "{err:?}");
        }
        let mut p = fixture(Instr::abc(Opcode::Move, 1, 0, 0));
        p.protos[0].num_params = 0;
        refresh(&mut p);
        let err = verify(&p).unwrap_err();
        assert_eq!((err.proto, err.pc), (ProtoIdx(0), Some(0)));
        assert!(err.message.contains("entry reads"));

        let mut p = fixture(Instr::abc(Opcode::AddI, 1, 0, 2));
        assert_eq!(verify(&p), Ok(()));
        assert_eq!(p.protos[0].live.live_in_at(0), Some([0, 2].as_slice()));
        p.protos[0].live.live_in.swap(0, 1);
        let err = verify(&p).unwrap_err();
        assert_eq!((err.proto, err.pc), (ProtoIdx(0), Some(0)));
        assert!(err.message.contains("unordered"));
    }
}
