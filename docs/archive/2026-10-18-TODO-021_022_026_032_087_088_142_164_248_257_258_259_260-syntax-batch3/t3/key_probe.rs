//! 索引の等号を既存の PartialEq と比較する一時的な実験。恒久テストには含めない。
use benitoite::{base, syntax, typeck, types};
use base::{BindingId, BytePos, FileId, NodeId, Span};
use typeck::infer::*;
use types::{EffectName, EffectSet, EffVar, Ty, TyCon, builtin::BuiltinTypeId as B};
use std::collections::HashSet;
use std::hash::{BuildHasherDefault, Hasher};
type EffectConstraint = (IEffect, IEffect, Reason, Option<(ITy, ITy)>);
#[path = "../../../crates/benitoite/src/typeck/solve/effect_key.rs"]
mod effect_key;
use effect_key::EffectConstraintKey;

#[derive(Default)]
struct Collision;
impl Hasher for Collision {
    fn finish(&self) -> u64 { 0 }
    fn write(&mut self, _: &[u8]) {}
}
fn main() {
    let integer = ITy::Con(TyCon::Builtin(B::INTEGER), vec![]);
    let string = ITy::Con(TyCon::Builtin(B::STRING), vec![]);
    let effect = IEffect { failures: vec![integer.clone(), string.clone()], fixed: EffectSet {
        failures: vec![Ty::Param(1), Ty::Param(2)], names: vec![EffectName::User(BindingId(3))], vars: vec![EffVar(2)]
    }, var: Some(EffInfer(7)) };
    let function = |contract| ITy::Fn(Box::new(IFnTy { contract, params: vec![integer.clone(), ITy::Var(TyVar(3))],
        ret: string.clone(), effect: effect.clone() }));
    let span = Span { file: FileId(1), start: BytePos(2), end: BytePos(3) };
    let reason = Reason { kind: ReasonKind::Call, span, related: Some(span), priority: Priority::Normal,
        int_literal: Some("01".into()) };
    let base = (effect.clone(), effect.clone(), reason.clone(), Some((function(IContract::Known(vec!["left".into(), "right".into()])), integer.clone())));
    let mut cases = vec![base.clone(), base.clone()];
    // 型の全種類、関数名・契約変数・引数・戻り値・潜在Fail・固定Failを変える。
    let tys = vec![ITy::Var(TyVar(1)), ITy::Var(TyVar(2)), integer.clone(), string.clone(),
        ITy::Con(TyCon::Adt(BindingId(1)), vec![integer.clone(), string.clone()]),
        ITy::Con(TyCon::External(BindingId(1)), vec![integer.clone()]),
        ITy::App(IHead::Param(1), vec![integer.clone()]), ITy::App(IHead::Var(TyVar(1)), vec![integer.clone()]),
        ITy::Param(1), ITy::Param(2), ITy::Rigid { clause: NodeId(1), index: 2 },
        ITy::Rigid { clause: NodeId(2), index: 2 }, ITy::Rigid { clause: NodeId(1), index: 3 }, ITy::Error,
        function(IContract::Known(vec!["right".into(), "left".into()])), function(IContract::Var(ContractId(1))),
        function(IContract::Var(ContractId(2)))];
    for ty in tys {
        for position in 0..4 {
            let mut item = base.clone();
            match position {
                0 => item.0.failures = vec![ty.clone()], 1 => item.1.failures = vec![ty.clone()],
                2 => item.3.as_mut().unwrap().0 = ty.clone(), _ => item.3.as_mut().unwrap().1 = ty.clone(),
            }
            cases.push(item);
        }
    }
    for slot in 0..2 {
        for change in 0..11 {
            let mut item = base.clone();
            let e = if slot == 0 { &mut item.0 } else { &mut item.1 };
            match change {
                0 => e.failures.reverse(), 1 => e.fixed.failures.reverse(),
                2 => e.fixed.names.push(EffectName::User(BindingId(4))),
                3 => e.fixed.vars.push(EffVar(4)), 4 => e.var = Some(EffInfer(8)), 5 => e.var = None,
                6 => e.failures.clear(), 7 => e.fixed.failures.clear(), 8 => e.fixed.names.clear(),
                9 => e.fixed.vars.clear(), _ => e.failures.push(ITy::Error),
            }
            cases.push(item);
        }
    }
    for change in 0..8 {
        let mut item = base.clone();
        match change {
            0 => item.2.span.file = FileId(2), 1 => item.2.span.start = BytePos(4),
            2 => item.2.span.end = BytePos(5), 3 => item.2.related = None,
            4 => item.2.related = Some(Span { end: BytePos(6), ..span }),
            5 => item.2.priority = Priority::Declared, 6 => item.2.int_literal = None,
            _ => item.2.int_literal = Some("1".into()),
        }
        cases.push(item);
    }
    use ReasonKind::*;
    let mut kinds = vec![CallArg { index: 1 }, CallArg { index: 2 }, Call, IfCondition, IfBranches, IfNoElse,
        MatchArms, MatchGuard, Pattern, Alternatives, ListElement, ListSpread, BindAnnotation, LambdaReturn,
        LambdaUses, Return, FnBody, FnUses, ExprStmt, Interp, CallEffect, RecordBase, Try, WithResource,
        WithState, LazyBody, DieMessage, HandleBody, HandleClause, Resume, ConstValue, FailureType];
    for op in [OpName::Bin(syntax::ast::BinOp::Add), OpName::Bin(syntax::ast::BinOp::Sub), OpName::Un(syntax::ast::UnOp::Not)] {
        kinds.extend([Operands { op }, Logic { op }, Operator { op }]);
    }
    for name in ["a", "b"] {
        kinds.extend([BuiltinParam { name: name.into() }, ParamBound { name: name.into() }]);
    }
    for id in [BindingId(1), BindingId(2)] {
        kinds.extend([RecordField { field: id }, ClassUse { class: id }, ImplSuper { class: id }]);
    }
    for kind in kinds { let mut item = base.clone(); item.2.kind = kind; cases.push(item); }
    let mut item = base.clone(); item.3 = None; cases.push(item);
    // 同じFail列を関数の引数、戻り値、潜在効果へ異なる木として配置する。
    for position in 0..4 {
        let mut item = base.clone();
        if let Some((ITy::Fn(f), _)) = &mut item.3 {
            match position {
                0 => f.params.reverse(), 1 => f.ret = integer.clone(),
                2 => f.effect.failures.reverse(), _ => f.effect.fixed.failures.reverse(),
            }
        }
        cases.push(item);
    }
    let keys: Vec<_> = cases.iter().map(EffectConstraintKey::new).collect();
    for (i, a) in cases.iter().enumerate() {
        for (j, b) in cases.iter().enumerate() { assert!((a == b) == (keys[i] == keys[j]), "{i}/{j}"); }
    }
    let ordinary: HashSet<_> = cases.iter().map(EffectConstraintKey::new).collect();
    let collisions: HashSet<_, BuildHasherDefault<Collision>> = cases.iter().map(EffectConstraintKey::new).collect();
    let unique = cases.iter().enumerate().filter(|(i, a)| !cases[..*i].contains(a)).count();
    assert_eq!(ordinary.len(), unique);
    assert_eq!(collisions.len(), unique);
    println!("{{\"variants\":{},\"pairwise_comparisons\":{},\"unique\":{},\"forced_hash_collisions\":true}}", cases.len(), cases.len()*cases.len(), unique);
}
