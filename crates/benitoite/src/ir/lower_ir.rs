//! 下位 IR（設計書 02-06「判定の木への変換」）。

use crate::base::Span;
use crate::types::{EffectSet, Ty};

use super::core_ir::{Const, Def, Program, Val, Var};

/// `join` の印の番号。定義ごとに 0 から振る。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct JoinId(pub u32);

#[derive(Clone, PartialEq, Debug)]
pub struct LComp {
    pub kind: LCompKind,
    pub ty: Ty,
    pub eff: EffectSet,
    pub origin: Span,
}

#[derive(Clone, PartialEq, Debug)]
pub enum LCompKind {
    Return(Val<LComp>),
    Let {
        var: Var,
        bound: Box<LComp>,
        body: Box<LComp>,
    },
    App {
        func: Val<LComp>,
        args: Vec<Val<LComp>>,
    },
    If {
        cond: Val<LComp>,
        then_branch: Box<LComp>,
        else_branch: Box<LComp>,
    },
    /// 構成子で分岐する `case`。`arms` はタグの昇順。`default` は並べていない構成子のとき
    CaseCtor {
        scrutinee: Val<LComp>,
        arms: Vec<CtorArm>,
        default: Option<Box<LComp>>,
    },
    /// 定数で分岐する `case`。`arms` は最初に現れた順
    CaseConst {
        scrutinee: Val<LComp>,
        arms: Vec<ConstArm>,
        default: Option<Box<LComp>>,
    },
    /// `join k(x̄) = handler in body`
    Join {
        label: JoinId,
        params: Vec<Var>,
        handler: Box<LComp>,
        body: Box<LComp>,
    },
    /// `jump k(V̄)`
    Jump {
        label: JoinId,
        args: Vec<Val<LComp>>,
    },
}

#[derive(Clone, PartialEq, Debug)]
pub struct CtorArm {
    pub tag: u32,
    /// 構成子の引数を束縛する変数
    pub fields: Vec<Var>,
    pub body: LComp,
}

#[derive(Clone, PartialEq, Debug)]
pub struct ConstArm {
    pub value: Const,
    pub body: LComp,
}

pub type LowVal = Val<LComp>;
pub type LowerDef = Def<LComp>;
pub type LowerProgram = Program<LComp>;
