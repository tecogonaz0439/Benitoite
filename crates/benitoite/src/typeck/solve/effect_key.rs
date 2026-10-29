//! 生の推論構造と理由を保つ制約の索引キー（設計書 02-05「制約の解決」）。
use super::EffectConstraint;
use crate::base::{BindingId, NodeId, Span};
use crate::syntax::ast::{BinOp, UnOp};
use crate::typeck::infer::*;
use crate::types::{EffectSet, TyCon};
use std::mem::{Discriminant, discriminant};

// 前置順の列に種類と子の個数を残すため、異なる木を同じキーにしない。
// 型変数・行・契約名を解決せず、登録後も変わらない構造だけを写す。
#[derive(PartialEq, Eq, Hash)]
enum Part {
    Var(TyVar),
    Con(TyCon, usize, crate::types::builtin::RangeIndex),
    Fn(IContract, usize),
    Param(u32),
    App(IHead, usize),
    Rigid(NodeId, u32),
    Error,
    // 原子の名前と範囲、Fail内の確定型も構造のEq/Hashへ含む。
    Effect(EffectSet, Option<EffInfer>, usize),
}
enum Pending<'a> {
    Ty(&'a ITy),
    Effect(&'a IEffect),
}
#[derive(PartialEq, Eq, Hash)]
enum Detail {
    Empty,
    Index(u32),
    Bin(BinOp),
    Un(UnOp),
    Name(String),
    Binding(BindingId),
}
#[derive(PartialEq, Eq, Hash)]
struct ReasonKey {
    kind: Discriminant<ReasonKind>,
    detail: Detail,
    span: Span,
    related: Option<Span>,
    declared: bool,
    int_literal: Option<String>,
}
impl ReasonKey {
    fn new(reason: &Reason) -> Self {
        let detail = match &reason.kind {
            ReasonKind::CallArg { index } => Detail::Index(*index),
            ReasonKind::Operands { op }
            | ReasonKind::Logic { op }
            | ReasonKind::Operator { op } => match op {
                OpName::Bin(op) => Detail::Bin(*op),
                OpName::Un(op) => Detail::Un(*op),
            },
            ReasonKind::BuiltinParam { name } | ReasonKind::ParamBound { name } => {
                Detail::Name(name.clone())
            }
            ReasonKind::RecordField { field } => Detail::Binding(*field),
            ReasonKind::ClassUse { class } | ReasonKind::ImplSuper { class } => {
                Detail::Binding(*class)
            }
            ReasonKind::ScopeResult
            | ReasonKind::Call
            | ReasonKind::IfCondition
            | ReasonKind::IfBranches
            | ReasonKind::IfNoElse
            | ReasonKind::MatchArms
            | ReasonKind::MatchGuard
            | ReasonKind::Pattern
            | ReasonKind::Alternatives
            | ReasonKind::ListElement
            | ReasonKind::ListSpread
            | ReasonKind::BindAnnotation
            | ReasonKind::LambdaReturn
            | ReasonKind::LambdaUses
            | ReasonKind::Return
            | ReasonKind::FnBody
            | ReasonKind::FnUses
            | ReasonKind::ExprStmt
            | ReasonKind::Interp
            | ReasonKind::InterpFormat
            | ReasonKind::CallEffect
            | ReasonKind::RecordBase
            | ReasonKind::Try
            | ReasonKind::WithResource
            | ReasonKind::WithState
            | ReasonKind::LazyBody
            | ReasonKind::DieMessage
            | ReasonKind::HandleBody
            | ReasonKind::HandleClause
            | ReasonKind::Resume
            | ReasonKind::ConstValue
            | ReasonKind::FailureType => Detail::Empty,
        };
        Self {
            kind: discriminant(&reason.kind),
            detail,
            span: reason.span,
            related: reason.related,
            declared: match reason.priority {
                Priority::Declared => true,
                Priority::Normal => false,
            },
            int_literal: reason.int_literal.clone(),
        }
    }
}

#[derive(PartialEq, Eq, Hash)]
pub(super) struct EffectConstraintKey {
    parts: Vec<Part>,
    reason: ReasonKey,
    has_pair: bool,
    relation: EffectRelation,
}
impl EffectConstraintKey {
    pub(super) fn new((sub, sup, reason, pair, relation): &EffectConstraint) -> Self {
        let mut pending = Vec::new();
        if let Some((a, b)) = pair {
            pending.push(Pending::Ty(b));
            pending.push(Pending::Ty(a));
        }
        pending.push(Pending::Effect(sup));
        pending.push(Pending::Effect(sub));
        let mut parts = Vec::new();
        while let Some(next) = pending.pop() {
            match next {
                Pending::Effect(e) => {
                    parts.push(Part::Effect(e.fixed.clone(), e.var, e.failures.len()));
                    pending.extend(e.failures.iter().rev().map(Pending::Ty));
                }
                Pending::Ty(t) => match t {
                    ITy::Var(v) => parts.push(Part::Var(*v)),
                    ITy::Con(c, args, ix) => {
                        parts.push(Part::Con(*c, args.len(), ix.clone()));
                        pending.extend(args.iter().rev().map(Pending::Ty));
                    }
                    ITy::App(h, args) => {
                        parts.push(Part::App(*h, args.len()));
                        pending.extend(args.iter().rev().map(Pending::Ty));
                    }
                    ITy::Fn(f) => {
                        parts.push(Part::Fn(f.contract.clone(), f.params.len()));
                        pending.push(Pending::Effect(&f.effect));
                        pending.push(Pending::Ty(&f.ret));
                        pending.extend(f.params.iter().rev().map(Pending::Ty));
                    }
                    ITy::Param(i) => parts.push(Part::Param(*i)),
                    ITy::Rigid { clause, index } => parts.push(Part::Rigid(*clause, *index)),
                    ITy::Error => parts.push(Part::Error),
                },
            }
        }
        Self {
            parts,
            reason: ReasonKey::new(reason),
            has_pair: pair.is_some(),
            relation: *relation,
        }
    }
}
