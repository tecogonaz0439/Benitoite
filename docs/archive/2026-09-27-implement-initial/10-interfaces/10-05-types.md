# 型と型検査

本章は、型の表現、代数的データ型の表、型検査の出力の表、型検査の内部で作業を分けるためのインターフェース（推論の型・制約・解く部分・パターンの検査）を定める。設計書の対応する章は[型検査器](../../2026-09-27-design-initial/02-impl/02-05-typechecker.md)であり、規則は[型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md)と[代数的データ型とパターンマッチ](../../2026-09-27-design-initial/01-spec/01-05-data-types.md)で定める。

型検査は三つの作業に分ける。T14 が推論の型と制約を解く部分（`typeck/infer.rs`・`typeck/solve.rs`）、T16 がパターンの検査（`typeck/patterns.rs`）、T15 が制約の生成と全体の手順（`typeck/mod.rs`・`typeck/generate.rs`・`typeck/decls.rs`）を書く。T14 と T16 は本章の型だけに依存するので、T15 より先に、または並行して進められる。

## 型の表現

型検査を終えた後の型（表に書く型、コア IR の型）を `Ty` で表す。推論に使う型変数を含まない（02-05「出力」）。

型パラメータ `Ty::Param(i)` とエフェクト変数 `EffVar(i)` は、それを宣言した宣言の中の位置で表す。

- 関数の宣言の型（`Scheme`）の中では、その関数の型パラメータの並び（`effect` を付けたものを除く）の i 番目と、エフェクト変数の並びの i 番目を表す。
- 関数の本体の中の式の型では、その本体を持つ関数の型パラメータとエフェクト変数を表す。ラムダは型パラメータを持たないので、ラムダの本体の中でも外側の関数のものを表す。
- 代数的データ型の宣言（`AdtDef`）の構成子の引数の型の中では、その型の宣言の型パラメータを表す。

```rust file=src/types/mod.rs
//! 型の表現（設計書 01-06、02-05「型とエフェクトの表現」）。

use crate::base::BindingId;

/// 型の名前（型構成子）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum TyCon {
    Int,
    Float,
    String,
    Char,
    Bool,
    Unit,
    List,
    Option,
    Result,
    /// 中身を見せない prelude の型（ADR 0048）
    IoError,
    /// 利用者の型。型の宣言の束縛の番号で識別する
    Adt(BindingId),
}

impl TyCon {
    /// 型引数の個数（利用者の型は `AdtDef` を見る）。
    pub fn builtin_arity(self) -> Option<usize> {
        match self {
            TyCon::Int
            | TyCon::Float
            | TyCon::String
            | TyCon::Char
            | TyCon::Bool
            | TyCon::Unit
            | TyCon::IoError => Some(0),
            TyCon::List | TyCon::Option => Some(1),
            TyCon::Result => Some(2),
            TyCon::Adt(_) => None,
        }
    }

    /// 基本型か（01-04）。
    pub fn is_basic(self) -> bool {
        matches!(
            self,
            TyCon::Int | TyCon::Float | TyCon::String | TyCon::Char | TyCon::Bool | TyCon::Unit
        )
    }
}

/// エフェクト変数。宣言の中の位置で表す（本章の冒頭）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct EffVar(pub u32);

/// 確定したエフェクトの集合。`vars` は昇順で重複を持たない。
#[derive(Clone, PartialEq, Eq, Hash, Debug, Default)]
pub struct EffectSet {
    pub io: bool,
    pub vars: Vec<EffVar>,
}

impl EffectSet {
    pub fn empty() -> EffectSet {
        EffectSet::default()
    }

    pub fn io() -> EffectSet {
        EffectSet {
            io: true,
            vars: Vec::new(),
        }
    }

    pub fn is_empty(&self) -> bool {
        !self.io && self.vars.is_empty()
    }

    pub fn insert_var(&mut self, v: EffVar) {
        if let Err(pos) = self.vars.binary_search(&v) {
            self.vars.insert(pos, v);
        }
    }

    pub fn union(&self, other: &EffectSet) -> EffectSet {
        let mut out = self.clone();
        out.io = out.io || other.io;
        for v in &other.vars {
            out.insert_var(*v);
        }
        out
    }

    /// self ⊆ other
    pub fn is_subset(&self, other: &EffectSet) -> bool {
        (!self.io || other.io)
            && self
                .vars
                .iter()
                .all(|v| other.vars.binary_search(v).is_ok())
    }

    /// エフェクト変数を集合で置き換える（01-12「ε[E/ρ]」）。`effs` にない変数はそのまま残す。
    pub fn subst(&self, effs: &[EffectSet]) -> EffectSet {
        let mut out = EffectSet {
            io: self.io,
            vars: Vec::new(),
        };
        for v in &self.vars {
            match usize::try_from(v.0).ok().and_then(|i| effs.get(i)) {
                Some(set) => out = out.union(set),
                None => out.insert_var(*v),
            }
        }
        out
    }
}

/// 型検査を終えた後の型。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum Ty {
    Con(TyCon, Vec<Ty>),
    Fn(Box<FnTy>),
    /// 型パラメータ（本章の冒頭）
    Param(u32),
}

#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct FnTy {
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
}

impl Ty {
    pub fn con(c: TyCon) -> Ty {
        Ty::Con(c, Vec::new())
    }

    pub fn int() -> Ty {
        Ty::con(TyCon::Int)
    }

    pub fn float() -> Ty {
        Ty::con(TyCon::Float)
    }

    pub fn string() -> Ty {
        Ty::con(TyCon::String)
    }

    pub fn char() -> Ty {
        Ty::con(TyCon::Char)
    }

    pub fn bool() -> Ty {
        Ty::con(TyCon::Bool)
    }

    pub fn unit() -> Ty {
        Ty::con(TyCon::Unit)
    }

    pub fn list(elem: Ty) -> Ty {
        Ty::Con(TyCon::List, vec![elem])
    }

    pub fn option(t: Ty) -> Ty {
        Ty::Con(TyCon::Option, vec![t])
    }

    pub fn result(t: Ty, e: Ty) -> Ty {
        Ty::Con(TyCon::Result, vec![t, e])
    }

    pub fn func(params: Vec<Ty>, ret: Ty, effects: EffectSet) -> Ty {
        Ty::Fn(Box::new(FnTy {
            params,
            ret,
            effects,
        }))
    }

    /// 型パラメータを `tys` で、エフェクト変数を `effs` で置き換える。
    /// `tys`・`effs` にない番号はそのまま残す。
    pub fn subst(&self, tys: &[Ty], effs: &[EffectSet]) -> Ty {
        match self {
            Ty::Con(c, args) => Ty::Con(*c, args.iter().map(|a| a.subst(tys, effs)).collect()),
            Ty::Fn(f) => Ty::Fn(Box::new(FnTy {
                params: f.params.iter().map(|p| p.subst(tys, effs)).collect(),
                ret: f.ret.subst(tys, effs),
                effects: f.effects.subst(effs),
            })),
            Ty::Param(i) => match usize::try_from(*i).ok().and_then(|i| tys.get(i)) {
                Some(t) => t.clone(),
                None => Ty::Param(*i),
            },
        }
    }

    /// 型を診断に示す形にする（`List[Int]`、`fn(Int) -> Int uses IO`、`Tree[T]`）。
    pub fn show(&self, names: &TyNames<'_>) -> String {
        match self {
            Ty::Con(c, args) => {
                let head = names.con_name(*c);
                if args.is_empty() {
                    head
                } else {
                    let inner: Vec<String> = args.iter().map(|a| a.show(names)).collect();
                    format!("{head}[{}]", inner.join(", "))
                }
            }
            Ty::Fn(f) => {
                let params: Vec<String> = f.params.iter().map(|p| p.show(names)).collect();
                let mut s = format!("fn({}) -> {}", params.join(", "), f.ret.show(names));
                if !f.effects.is_empty() {
                    s.push_str(" uses ");
                    s.push_str(&names.show_effects(&f.effects));
                }
                s
            }
            Ty::Param(i) => names.type_param_name(*i),
        }
    }
}

/// 型を表示するための名前の表。
#[derive(Clone, Copy, Debug)]
pub struct TyNames<'a> {
    pub adts: &'a AdtTable,
    /// 表示している文脈の型パラメータの名前
    pub type_params: &'a [String],
    /// 表示している文脈のエフェクト変数の名前
    pub effect_params: &'a [String],
}

impl TyNames<'_> {
    pub fn con_name(&self, c: TyCon) -> String {
        match c {
            TyCon::Int => "Int".to_string(),
            TyCon::Float => "Float".to_string(),
            TyCon::String => "String".to_string(),
            TyCon::Char => "Char".to_string(),
            TyCon::Bool => "Bool".to_string(),
            TyCon::Unit => "Unit".to_string(),
            TyCon::List => "List".to_string(),
            TyCon::Option => "Option".to_string(),
            TyCon::Result => "Result".to_string(),
            TyCon::IoError => "IoError".to_string(),
            TyCon::Adt(_) => self
                .adts
                .get(c)
                .map_or_else(|| "?".to_string(), |d| d.name.clone()),
        }
    }

    pub fn type_param_name(&self, i: u32) -> String {
        usize::try_from(i)
            .ok()
            .and_then(|i| self.type_params.get(i))
            .cloned()
            .unwrap_or_else(|| format!("T{i}"))
    }

    /// `IO, E` の形。`IO` を先に、エフェクト変数を宣言の順に並べる。
    pub fn show_effects(&self, e: &EffectSet) -> String {
        let mut parts = Vec::new();
        if e.io {
            parts.push("IO".to_string());
        }
        for v in &e.vars {
            let name = usize::try_from(v.0)
                .ok()
                .and_then(|i| self.effect_params.get(i))
                .cloned()
                .unwrap_or_else(|| format!("E{}", v.0));
            parts.push(name);
        }
        parts.join(", ")
    }
}

/// 型パラメータに付ける制約。prelude の関数の型だけが持つ（01-06「prelude の関数の型」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ParamConstraint {
    None,
    /// 等値の型であること
    Equality,
    /// 型の集まりのどれかであること
    OneOf(TySet),
}

/// 演算子の型の集まり（01-06「演算子の型付け」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TySet(pub &'static [TyCon]);

impl TySet {
    /// `+`
    pub const ADD: TySet = TySet(&[TyCon::Int, TyCon::Float, TyCon::String]);
    /// `-`・`*`・`/`・単項の `-`
    pub const ARITH: TySet = TySet(&[TyCon::Int, TyCon::Float]);
    /// `<`・`<=`・`>`・`>=`、`List.sort`
    pub const ORD: TySet = TySet(&[TyCon::Int, TyCon::Float, TyCon::String, TyCon::Char]);

    pub fn contains(self, c: TyCon) -> bool {
        self.0.contains(&c)
    }

    /// 共通部分。三つの集まりは ARITH ⊆ ADD ⊆ ORD の包含の関係にあるので、小さいほうになる。
    pub fn intersect(self, other: TySet) -> TySet {
        if self.0.iter().all(|c| other.contains(*c)) {
            self
        } else if other.0.iter().all(|c| self.contains(*c)) {
            other
        } else {
            TySet(&[])
        }
    }
}

/// 型パラメータの情報。
#[derive(Clone, PartialEq, Debug)]
pub struct TypeParamInfo {
    pub name: String,
    pub constraint: ParamConstraint,
}

/// 多相な名前の宣言の型（02-05「出力」の「宣言の型」）。
#[derive(Clone, PartialEq, Debug)]
pub struct Scheme {
    pub type_params: Vec<TypeParamInfo>,
    pub effect_params: Vec<String>,
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
}

impl Scheme {
    /// 関数の型として見た型（型パラメータは置き換えない）。
    pub fn fn_ty(&self) -> Ty {
        Ty::func(self.params.clone(), self.ret.clone(), self.effects.clone())
    }
}

/// 等値の型の要約（01-06「等値の型」、ADR 0082）。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct EqSummary {
    /// 型引数によらず、関数の型か中身を見せない prelude の型を含む
    pub always: bool,
    /// 含むかどうかが型引数に依存する型パラメータの位置（昇順）
    pub depends_on: Vec<u32>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct CtorDef {
    pub name: String,
    /// 構成子の束縛の番号
    pub binding: BindingId,
    pub tag: u32,
    /// 引数の型。型の宣言の型パラメータを `Ty::Param` で表す
    pub fields: Vec<Ty>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct AdtDef {
    pub con: TyCon,
    pub name: String,
    pub type_params: Vec<String>,
    /// タグの順（宣言の順）
    pub ctors: Vec<CtorDef>,
    pub eq_summary: EqSummary,
}

/// 代数的データ型の表。`Option`・`Result` と利用者の型を持つ。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct AdtTable {
    pub adts: Vec<AdtDef>,
}

impl AdtTable {
    pub fn get(&self, con: TyCon) -> Option<&AdtDef> {
        self.adts.iter().find(|d| d.con == con)
    }

    /// 構成子の引数の型を、型引数 `args` で置き換えて返す。
    pub fn field_types(&self, con: TyCon, tag: u32, args: &[Ty]) -> Option<Vec<Ty>> {
        let def = self.get(con)?;
        let ctor = def.ctors.iter().find(|c| c.tag == tag)?;
        Some(ctor.fields.iter().map(|f| f.subst(args, &[])).collect())
    }
}
```

`Option` と `Result` の `AdtDef` は、型検査器が宣言の検査の最初に表に加える。タグは `Some` が 0、`None` が 1、`Ok` が 0、`Err` が 1 である（02-07「コンパイル済みプログラム」）。構成子の束縛の番号は、名前解決の `PreludeBindings` から取る。

## 型検査の出力

02-05「出力」の五つの表に、代数的データ型の表と `main` の情報を加える。

```rust file=src/typeck/mod.rs
//! 型検査（設計書 02-05）。
//! infer.rs: 推論の型と制約、solve.rs: 制約を解く部分、patterns.rs: パターンの検査、
//! generate.rs: 制約の生成、decls.rs: 宣言の検査。

pub mod decls;
pub mod generate;
pub mod infer;
pub mod patterns;
pub mod solve;

use crate::base::{BindingMap, NodeMap};
use crate::types::{AdtTable, EffectSet, Scheme, Ty};

/// 多相な名前を使う箇所の、型パラメータとエフェクト変数を置き換えた型とエフェクトの集合
/// （01-12 の `[T̄; Ē]`）。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct TypeArgs {
    pub tys: Vec<Ty>,
    pub effects: Vec<EffectSet>,
}

/// `main` の情報（01-07「プログラムの入口」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct MainInfo {
    pub binding: crate::base::BindingId,
    /// 戻り値の型が `Result[Unit, String]` か（そうでなければ `Unit`）
    pub returns_result: bool,
}

/// 型検査の出力（02-05「出力」）。表に書く型は型変数を含まない。
#[derive(Debug, Default)]
pub struct TypeckOutput {
    /// 式・パターン・`let` 文・引数・プレースホルダのノード番号 → 型
    pub expr_types: NodeMap<Ty>,
    /// 多相な名前を使う箇所（NameExpr・CtorPat）のノード番号 → 置き換え
    pub type_args: NodeMap<TypeArgs>,
    /// 二項演算・単項演算のノード番号 → オペランドの型
    pub operand_types: NodeMap<Ty>,
    /// ラムダとプレースホルダを含む呼び出しのノード番号 → ラムダの型のエフェクト
    pub lambda_effects: NodeMap<EffectSet>,
    /// トップレベルの関数・prelude のソースの関数・構成子の束縛の番号 → 宣言の型
    pub decl_types: BindingMap<Scheme>,
    pub adts: AdtTable,
    /// 誤りがなければ `Some`
    pub main: Option<MainInfo>,
}
```

`expr_types` の `let` 文の型は束縛した変数の型（型注釈があればその型）、引数の型はその引数の型、プレースホルダの型は展開したラムダのその引数の型である。構成子の宣言の型（`decl_types` の構成子の項目）は、型の宣言の型パラメータを型パラメータとし、引数の型を引数、`D[T̄]` を戻り値の型、空集合をエフェクトとする。

## 型検査の関数

```rust sig=src/typeck/mod.rs
use crate::diag::Diagnostic;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Program;

/// 宣言の検査と本体の検査を行う（02-05「検査の手順」）。誤りがあっても出力を返す。
/// 呼び出し側は、診断に誤りが一つでもあれば出力を使わない（ADR 0019）。
pub fn typecheck(prelude: &[Program], user: &Program, resolved: &ResolveOutput) -> (TypeckOutput, Vec<Diagnostic>);
```

## 推論の型と制約（T14 と T15 の境界）

推論の中の型 `ITy` は、`Ty` に型変数と誤りの型を加えたものである（02-05「型とエフェクトの表現」）。エフェクト `IEffect` は、確定した要素の集合と、まだ決まっていないエフェクトの変数（高々一つ）の組である。

制約は 02-05「制約の種類」の五種類である。各制約は理由 `Reason` を持つ。理由の種類 `ReasonKind` は、制約が解けなかったときの診断の注記（E0401 の `because_*` の鍵）を選ぶために使う。

```rust file=src/typeck/infer.rs
//! 推論の中の型と制約（設計書 02-05「型とエフェクトの表現」「制約の種類」）。

use crate::base::Span;
use crate::syntax::ast::{BinOp, UnOp};
use crate::types::{EffectSet, TyCon, TySet};

/// 型変数。union-find の要素の番号。本体の検査ごとに作って捨てる。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct TyVar(pub u32);

/// まだ決まっていないエフェクトの変数。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct EffInfer(pub u32);

#[derive(Clone, PartialEq, Debug)]
pub enum ITy {
    Var(TyVar),
    Con(TyCon, Vec<ITy>),
    Fn(Box<IFnTy>),
    /// 検査している関数の型パラメータ。ほかの何とも等しくない
    Param(u32),
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

/// 演算子の名前。診断の `{op}` に使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum OpName {
    Bin(BinOp),
    Un(UnOp),
}

impl OpName {
    pub fn symbol(self) -> &'static str {
        match self {
            OpName::Bin(BinOp::Add) => "+",
            OpName::Bin(BinOp::Sub) => "-",
            OpName::Bin(BinOp::Mul) => "*",
            OpName::Bin(BinOp::Div) => "/",
            OpName::Bin(BinOp::Rem) => "%",
            OpName::Bin(BinOp::Eq) => "==",
            OpName::Bin(BinOp::Ne) => "!=",
            OpName::Bin(BinOp::Lt) => "<",
            OpName::Bin(BinOp::Le) => "<=",
            OpName::Bin(BinOp::Gt) => ">",
            OpName::Bin(BinOp::Ge) => ">=",
            OpName::Bin(BinOp::And) => "&&",
            OpName::Bin(BinOp::Or) => "||",
            OpName::Un(UnOp::Neg) => "-",
            OpName::Un(UnOp::Not) => "!",
        }
    }
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
    Pattern,
    ListElement,
    LetAnnotation,
    LambdaReturn,
    /// ラムダの `uses`（含まれる制約）
    LambdaUses,
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
    /// `&&`・`||`・`!` のオペランドが `Bool` であること
    Logic {
        op: OpName,
    },
    /// 集まりの制約と等値の制約
    Operator {
        op: OpName,
    },
    /// 呼び出しのエフェクトが本体のエフェクトに含まれること（含まれる制約）。
    /// `sup` が固定の集合（宣言した `uses`）のときに解けなければ E0501 とする
    CallEffect,
    /// 組み込みの関数の型パラメータの制約（`List.contains` の等値、`List.sort` の集まり）。
    /// `name` は修飾した名前で、E0405・E0406 の `{op}` に埋める
    BuiltinParam {
        name: String,
    },
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
    /// 型を求められた式が整数リテラルのとき、その字面（E0401 の `float_literal` の修正案に使う）
    pub int_literal: Option<String>,
}

/// 制約（02-05「制約の種類」）。
#[derive(Clone, PartialEq, Debug)]
pub enum Constraint {
    /// 等しい(A, B)。`a` が期待した型、`b` が実際の型として診断に示す
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
    /// 含まれる(X, Y)
    EffSub {
        sub: IEffect,
        sup: IEffect,
        reason: Reason,
    },
}
```

制約を解く部分（T14）は次のシグネチャを持つ。解き方は 02-05「制約の解決」に従う。

```rust sig=src/typeck/solve.rs
use crate::diag::Diagnostic;
use crate::types::{AdtTable, EffectSet, Ty, TySet};
use super::infer::{Constraint, EffInfer, IEffect, ITy, Reason, TyVar};

/// 一つの本体の検査で使う、型変数と制約を解く状態。本体ごとに作って捨てる（02-05「検査の手順」）。
#[derive(Debug)]
pub struct Solver { /* 中身は T14 が決める（非公開の欄だけにする） */ }

/// 解くときに参照する情報。
#[derive(Clone, Copy, Debug)]
pub struct SolveEnv<'a> {
    pub adts: &'a AdtTable,
    /// 検査している関数の型パラメータとエフェクト変数の名前（診断の型の表示に使う）
    pub type_params: &'a [String],
    pub effect_params: &'a [String],
}

impl Solver {
    pub fn new() -> Solver;
    /// 新しい型変数。
    pub fn fresh_ty(&mut self) -> ITy;
    pub fn fresh_ty_var(&mut self) -> TyVar;
    /// 新しいエフェクトの変数だけからなるエフェクト。
    pub fn fresh_effect(&mut self) -> IEffect;
    pub fn fresh_eff_var(&mut self) -> EffInfer;
    /// 型変数に集まりの制約を直接付ける（組み込みの関数の型パラメータの制約を移すときに使う）。
    pub fn constrain_one_of(&mut self, v: TyVar, set: TySet, reason: Reason);
    pub fn constrain_equality(&mut self, v: TyVar, reason: Reason);
    /// 制約をすべて解く。手順 1（Priority::Declared の流れ込む制約）、手順 2（残りの型の制約）、
    /// 手順 3（含まれる制約）の順。解けなかった制約の診断を返す。
    pub fn solve(&mut self, constraints: Vec<Constraint>, env: &SolveEnv<'_>) -> Vec<Diagnostic>;
    /// 現在の単一化の状態で型変数を置き換えた型。
    pub fn zonk(&self, ty: &ITy) -> ITy;
    /// 型が誤りの型を含むか（置き換えた後で判定する）。
    pub fn contains_error(&self, ty: &ITy) -> bool;
    /// 表に書く型にする。制約を持たない決まっていない型変数は `Unit`、決まっていないエフェクトの変数は空集合。
    /// 誤りの型は `Unit` にする（誤りがあれば表は使われない）。
    pub fn finalize(&self, ty: &ITy) -> Ty;
    pub fn finalize_effect(&self, e: &IEffect) -> EffectSet;
    /// 制約（集まり・等値）を持ち、決まらなかった型変数の制約の理由の位置（E0407 に使う。02-05「本体の後の検査」）。
    /// 誤りの型になった型変数は含めない。
    pub fn undetermined(&self) -> Vec<Reason>;
}
```

`Solver` の構造体の欄は T14 が決める。ほかの作業は欄に触れず、上の関数だけを使う。組み込みの関数の型パラメータに制約を移すときは、`fresh_ty_var` で型変数を作り、`constrain_one_of` か `constrain_equality` で制約を付けてから、`ITy::Var(v)` として使う。

## パターンの検査（T16 と T15 の境界）

パターンの検査は、型検査を終えた型（`Ty`）と、構成子をタグで表したパターン（`Pat`）の上で行う。T15 が AST のパターンを `Pat` に移し、対象の型が誤りの型を含む `match` は渡さない（02-05「誤りの報告と検査の継続」）。

```rust file=src/typeck/patterns.rs
//! パターンの検査: 網羅性と選ばれない分岐（設計書 02-05「本体の後の検査」、01-05）。

use crate::types::TyCon;

/// 検査に使うパターン。変数のパターンは `Wild` にする（どちらもすべての値に照合する）。
#[derive(Clone, PartialEq, Debug)]
pub enum Pat {
    Wild,
    Ctor {
        con: TyCon,
        tag: u32,
        args: Vec<Pat>,
    },
    Int(i64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
}

/// 検査の結果。
#[derive(Clone, PartialEq, Debug)]
pub enum MatchIssue {
    /// 網羅していない。`witness` はどの分岐にも照合しない値の形（`Tree.Node(Tree.Leaf, _, _)` など）
    NonExhaustive { witness: String },
    /// `arm` 番目（0 から数える）の分岐は選ばれない。`covered_by` は覆っている前の分岐の番号（昇順）
    Unreachable { arm: usize, covered_by: Vec<usize> },
}
```

```rust sig=src/typeck/patterns.rs
use crate::types::{AdtTable, Ty};

/// 一つの `match` を検査する。`arms` は分岐のパターンを順に並べたもの。
/// 選ばれない分岐を分岐の順に、その後に網羅していないこと（あれば一つ）を返す。
/// 構成子の名前の表示は、利用者の型は `型名.構成子名`、`Option`・`Result` は `Some` などの修飾しない名前とする。
pub fn check_match(scrutinee: &Ty, arms: &[Pat], adts: &AdtTable) -> Vec<MatchIssue>;
```
