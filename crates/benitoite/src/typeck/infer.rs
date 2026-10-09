//! 推論の中の型と制約（設計書 02-05「型とエフェクトの表現」「制約の種類」）。
//! 型変数と制約は本体の検査ごとに作って捨てる（02-05「検査の単位と手順」、ADR 0015）。

use crate::base::{BindingId, NodeId, Span};
use crate::syntax::ast::{BinOp, UnOp};
use crate::types::{EffectSet, TyCon, TySet};

/// 型変数。union-find の要素の番号。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct TyVar(pub u32);

/// まだ決まっていないエフェクトの変数。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct EffInfer(pub u32);

/// 推論の中の型構成子の頭（`F[A]` の F）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum IHead {
    /// 型構成子を表す型パラメータ
    Param(u32),
    /// 型構成子の変数（型構成子を表す型パラメータを置き換えた変数）
    Var(TyVar),
}

#[derive(Clone, PartialEq, Debug)]
pub enum ITy {
    /// 値の型の変数
    Var(TyVar),
    Con(TyCon, Vec<ITy>),
    Fn(Box<IFnTy>),
    /// 検査している定義の型パラメータ。ほかの何とも等しくない
    Param(u32),
    /// 型構成子の適用 `F[A]`（02-05「型とエフェクトの表現」の単一化の規則）
    App(IHead, Vec<ITy>),
    /// `handle` の節の中の操作の型パラメータ
    Rigid {
        clause: NodeId,
        index: u32,
    },
    /// 誤りの型。どの型とも等しいものとして扱う（ADR 0024）
    Error,
}

#[derive(Clone, PartialEq, Debug)]
pub struct IFnTy {
    pub params: Vec<ITy>,
    pub ret: ITy,
    pub effect: IEffect,
}

/// 確定した要素と、高々一つのまだ決まっていない変数の組。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct IEffect {
    pub fixed: EffectSet,
    pub var: Option<EffInfer>,
}

/// 型クラスの制約の引数（値の型、または型構成子）。
#[derive(Clone, PartialEq, Debug)]
pub enum IClassArg {
    Ty(ITy),
    /// 型構成子。`Con` の型引数は空
    Con(TyCon),
    Head(IHead),
}

/// 型クラスの制約を解いた結果を書く先（02-05「出力」の「辞書の解決」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DictSite {
    /// 名前を使う箇所のノードと、その名前の宣言の型の制約の番号
    Use { node: NodeId, constraint: u32 },
    /// 実装の宣言のノードと、型クラスの上位の型クラスの番号（`TraitDef::supers` の位置）
    ImplSuper { impl_decl: NodeId, index: u32 },
}

/// 演算子の名前。診断の `{op}` に使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum OpName {
    Bin(BinOp),
    Un(UnOp),
}

/// 制約が生じた事情（02-05「制約の種類」の「理由」）。
#[derive(Clone, PartialEq, Debug)]
pub enum ReasonKind {
    /// 呼び出しの i 番目（1 から数える）の引数
    CallArg {
        index: u32,
    },
    /// 呼び出される式が関数の型であること
    Call,
    IfCondition,
    IfBranches,
    IfNoElse,
    MatchArms,
    MatchGuard,
    Pattern,
    /// 一つの分岐の選択肢が同じ名前で束縛する変数の型（F10 の P2）
    Alternatives,
    ListElement,
    /// リストリテラルの展開の要素
    ListSpread,
    /// 束縛の文の型注釈
    BindAnnotation,
    LambdaReturn,
    /// ラムダの `uses`（含まれる制約）
    LambdaUses,
    /// `return` の式と戻り値の型
    Return,
    /// 関数の本体と宣言した戻り値の型
    FnBody,
    /// 関数の本体のエフェクトと宣言した `uses`（含まれる制約）
    FnUses,
    /// 最後でない式文は `Unit`
    ExprStmt,
    /// 二項演算の二つのオペランドの型が等しいこと、単項演算のオペランド
    Operands {
        op: OpName,
    },
    /// `and`・`or`・`not` のオペランドが `Boolean` であること
    Logic {
        op: OpName,
    },
    /// 演算子の集まりの制約と等値の制約
    Operator {
        op: OpName,
    },
    /// 文字列補間の集まりの制約
    Interp,
    /// 呼び出しのエフェクトが本体のエフェクトに含まれること
    CallEffect,
    /// 標準ライブラリの関数の型パラメータの組み込みの制約（`equality`・`key`・`ordered`）。
    /// `name` は修飾した名前
    BuiltinParam {
        name: String,
    },
    /// 型パラメータの組み込みの制約を持つ利用者の関数の呼び出し
    ParamBound {
        name: String,
    },
    /// レコードの構築と更新のフィールドの式
    RecordField {
        field: BindingId,
    },
    /// レコードの更新の元の式
    RecordBase,
    /// 型クラスの制約（メソッドか制約を持つ関数を使った）
    ClassUse {
        class: BindingId,
    },
    /// 実装の上位の型クラスの制約
    ImplSuper {
        class: BindingId,
    },
    /// `try` の対象と戻り値の型
    Try,
    /// `with` の束縛の式がリソースの型であること
    WithResource,
    /// `with` の解放のエフェクト `State`
    WithState,
    /// `lazy` の本体が純粋であること
    LazyBody,
    /// `handle` の本体の型とエフェクト
    HandleBody,
    /// `handle` の節の本体
    HandleClause,
    /// `resume` の引数と節の操作の戻り値の型
    Resume,
    /// 定数式と宣言の型
    ConstValue,
}

/// 解く順序の区分（02-05「制約の解決」の手順 1 と 2）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Priority {
    /// 宣言と型注釈から生じた流れ込む制約。先に解く
    Declared,
    Normal,
}

/// 制約の理由。
#[derive(Clone, PartialEq, Debug)]
pub struct Reason {
    /// 主な位置（型を求められた式、呼び出しなど）
    pub span: Span,
    pub kind: ReasonKind,
    /// 関連する位置（引数の型を宣言した箇所、`uses` を書いた箇所など）
    pub related: Option<Span>,
    pub priority: Priority,
    /// 型を求められた式が整数リテラルのとき、その字面（`Float` の位置の修正案に使う）
    pub int_literal: Option<String>,
}

/// 制約（02-05「制約の種類」）。
#[derive(Clone, PartialEq, Debug)]
pub enum Constraint {
    /// 等しい(A, B)。`expected` が期待した型、`found` が実際の型として診断に示す
    Equal {
        expected: ITy,
        found: ITy,
        reason: Reason,
    },
    /// 流れ込む(A, B)。値の型 `from` を、型 `to` が求められる位置に使う
    Flow { from: ITy, to: ITy, reason: Reason },
    /// 集まり(A, S)
    OneOf { ty: ITy, set: TySet, reason: Reason },
    /// 等値(A)
    Equality { ty: ITy, reason: Reason },
    /// 鍵(A)
    Key { ty: ITy, reason: Reason },
    /// 型クラス(C, τ)。解いた辞書の求め方を `site` に記録する
    Class {
        class: BindingId,
        arg: IClassArg,
        site: DictSite,
        reason: Reason,
    },
    /// 試行(A, R, τ)。`target` が `try` の対象の型、`ret` が最も内側の関数かラムダの戻り値の型、
    /// `result` が `try` の式の型。判定の結果を `node`（`TryExpr`）の「`try` の種類」に記録する
    Try {
        target: ITy,
        ret: ITy,
        result: ITy,
        node: NodeId,
        reason: Reason,
    },
    /// リソース(A)
    Resource { ty: ITy, reason: Reason },
    /// 含まれる(X, Y)
    EffSub {
        sub: IEffect,
        sup: IEffect,
        reason: Reason,
    },
}
