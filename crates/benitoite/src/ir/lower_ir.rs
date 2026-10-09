//! 下位 IR（設計書 02-06「判定の木への変換」「下位 IR からコード生成へ渡すもの」）。

use crate::base::{BindingId, Span};
use crate::types::{EffectSet, Ty};

use super::core_ir::{BodyId, Const, Def, DictVal, Handle, MethodCall, Program, Val, Var, VarId};

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
        dicts: Vec<DictVal>,
        args: Vec<Val<LComp>>,
    },
    Method(Box<MethodCall<LComp>>),
    If {
        cond: Val<LComp>,
        then_branch: Box<LComp>,
        else_branch: Box<LComp>,
    },
    /// 構成子で分岐する `case`。`arms` はタグの昇順。`default` は並べていない構成子のとき
    CaseCtor {
        scrutinee: Val<LComp>,
        adt: BindingId,
        arms: Vec<CtorArm>,
        default: Option<Box<LComp>>,
    },
    /// 定数と区間で分岐する `case`。区間は互いに交わらない。`Integer` と `Character` の `case` では、
    /// `arms` を区間の下端（`Eq` は定数そのもの）の昇順に並べる（02-06「パターンの拡張」の手順 6 が値の範囲を分けて作る区間の順）。
    /// ほかの型の定数の `case` では、`arms` はパターンに最初に現れた順
    CaseConst {
        scrutinee: Val<LComp>,
        arms: Vec<ConstArm>,
        default: Option<Box<LComp>>,
    },
    /// リストの長さで分岐する `case length V of { =k ⇒ M | … | ≥m ⇒ M }`
    CaseLength {
        scrutinee: Val<LComp>,
        /// 長さがちょうど `len` のとき（`len` の昇順。どれも `at_least` より小さい）
        exact: Vec<LengthArm>,
        at_least: u32,
        /// 長さが `at_least` 以上のとき
        otherwise: Box<LComp>,
    },
    /// リストの要素の取り出し。長さの分け方で、要素があることを確かめた後にだけ置く
    ListGet {
        list: Val<LComp>,
        from: ListEnd,
        /// `from` の端から 0 で数えた位置
        index: u32,
    },
    /// リストの前の `drop_front` 個と後の `drop_back` 個を除いた部分（`..rest` の変数の値）
    ListSlice {
        list: Val<LComp>,
        drop_front: u32,
        drop_back: u32,
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
    Escape(Val<LComp>),
    Use {
        resource: Val<LComp>,
        body: Box<LComp>,
    },
    Lazy {
        id: BodyId,
        body: Box<LComp>,
    },
    Handle(Box<Handle<LComp>>),
    Resume {
        cont: VarId,
        value: Val<LComp>,
    },
}

#[derive(Clone, PartialEq, Debug)]
pub struct CtorArm {
    pub tag: u32,
    /// 構成子の引数を束縛する変数
    pub fields: Vec<Var>,
    pub body: LComp,
}

/// 定数の `case` の判定。
#[derive(Clone, PartialEq, Debug)]
pub enum ConstTest {
    /// 定数と等しい
    Eq(Const),
    /// 区間（両端を含む）に入る。`Integer` と `Character` だけ
    Range(Const, Const),
}

#[derive(Clone, PartialEq, Debug)]
pub struct ConstArm {
    pub test: ConstTest,
    pub body: LComp,
}

#[derive(Clone, PartialEq, Debug)]
pub struct LengthArm {
    pub len: u32,
    pub body: LComp,
}

/// リストのどちらの端から数えるか。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ListEnd {
    Front,
    Back,
}

pub type LowVal = Val<LComp>;
pub type LowerDef = Def<LComp>;
pub type LowerProgram = Program<LComp>;
