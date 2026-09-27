//! コア IR（設計書 02-06「コア IR」、01-12「構文」）。

use crate::base::{BindingId, Span};
use crate::builtins::{BuiltinId, PreludeModule};
use crate::types::{AdtTable, EffectSet, Ty, TyCon};

/// 定義の中の変数の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct VarId(pub u32);

/// プログラム全体で重ならないラムダの番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct LambdaId(pub u32);

/// 変数。`name` はソースの名前（脱糖で作った変数では `None`）。診断と読みやすさのためだけに持つ。
#[derive(Clone, PartialEq, Debug)]
pub struct Var {
    pub id: VarId,
    pub name: Option<String>,
    pub ty: Ty,
}

/// 定数（01-12 の `c`。IoError の値は実行中にだけ現れるので含めない）。
#[derive(Clone, PartialEq, Debug)]
pub enum Const {
    Int(i64),
    Float(f64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
}

/// 値。
#[derive(Clone, PartialEq, Debug)]
pub struct Val<C> {
    pub kind: ValKind<C>,
    pub ty: Ty,
    pub origin: Span,
}

#[derive(Clone, PartialEq, Debug)]
pub enum ValKind<C> {
    Var(VarId),
    Const(Const),
    /// トップレベルの関数 `f[T̄; Ē]`。関数は束縛の番号で指す
    TopFn {
        def: BindingId,
        tys: Vec<Ty>,
        effs: Vec<EffectSet>,
    },
    /// 組み込みの関数 `b[T̄; Ē]`。演算子（`⊕_T`）もこれで表す（02-06「コア IR」）
    Builtin {
        id: BuiltinId,
        tys: Vec<Ty>,
        effs: Vec<EffectSet>,
    },
    /// 関数 `λ(x̄:Ā). M`
    Lambda(Box<Lambda<C>>),
    /// 構成子を適用した値 `C[T̄](V̄)`
    Ctor {
        con: TyCon,
        tag: u32,
        tys: Vec<Ty>,
        args: Vec<Val<C>>,
    },
    /// リスト `[V̄]`
    List(Vec<Val<C>>),
}

#[derive(Clone, PartialEq, Debug)]
pub struct Lambda<C> {
    pub id: LambdaId,
    pub params: Vec<Var>,
    pub body: C,
    /// ラムダを書いた位置（プレースホルダの展開では、プレースホルダを含む呼び出しの式の位置）
    pub span: Span,
}

/// 計算。
#[derive(Clone, PartialEq, Debug)]
pub struct Comp {
    pub kind: CompKind,
    pub ty: Ty,
    pub eff: EffectSet,
    pub origin: Span,
}

#[derive(Clone, PartialEq, Debug)]
pub enum CompKind {
    Return(Val<Comp>),
    Let {
        var: Var,
        bound: Box<Comp>,
        body: Box<Comp>,
    },
    App {
        func: Val<Comp>,
        args: Vec<Val<Comp>>,
    },
    If {
        cond: Val<Comp>,
        then_branch: Box<Comp>,
        else_branch: Box<Comp>,
    },
    Match {
        scrutinee: Val<Comp>,
        arms: Vec<Arm>,
    },
}

#[derive(Clone, PartialEq, Debug)]
pub struct Arm {
    pub pattern: CorePat,
    pub body: Comp,
}

/// パターン（01-12 の `p`）。構成子の型名の修飾は除き、`-n` は負の定数にしてある。
#[derive(Clone, PartialEq, Debug)]
pub enum CorePat {
    Wild,
    Var(Var),
    Const(Const),
    Ctor {
        con: TyCon,
        tag: u32,
        args: Vec<CorePat>,
    },
}

/// 定義の由来。原型の名前と由来の種類（02-07）を決めるのに使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DefOrigin {
    /// 利用者のトップレベルの関数
    User,
    /// prelude の公開の関数（モジュールの名前で修飾した関数）
    PreludePublic { module: PreludeModule },
    /// prelude の補助の関数
    PreludeHelper,
}

/// 定義 `fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = M`。
#[derive(Clone, PartialEq, Debug)]
pub struct Def<C> {
    pub binding: BindingId,
    /// 表示のための名前（prelude の公開の関数は `List.map` の形）
    pub name: String,
    pub origin: DefOrigin,
    pub type_params: Vec<String>,
    pub effect_params: Vec<String>,
    pub params: Vec<Var>,
    pub ret: Ty,
    pub eff: EffectSet,
    pub body: C,
    /// 関数の宣言の位置
    pub span: Span,
    pub var_count: u32,
}

/// プログラム。定義の並びは、prelude のソースの定義（ファイルの名前の順、ファイルの中の順）の後に、
/// 利用者の定義（ソースの順）を置く。
#[derive(Clone, PartialEq, Debug)]
pub struct Program<C> {
    pub defs: Vec<Def<C>>,
    pub adts: AdtTable,
    pub main: BindingId,
    pub main_returns_result: bool,
    pub lambda_count: u32,
}

pub type CoreVal = Val<Comp>;
pub type CoreDef = Def<Comp>;
pub type CoreProgram = Program<Comp>;
