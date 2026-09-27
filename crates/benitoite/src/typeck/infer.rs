//! 推論の中の型と制約（設計書 02-05「型とエフェクトの表現」「制約の種類」）。

use crate::base::Span;
use crate::syntax::ast::{BinOp, UnOp};
use crate::types::{EffectSet, TyCon, TyNames, TySet};

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

/// 型を表示するときの、まだ決まっていない型変数と誤りの型の字面（T14 で決めた。`List[_]` のように示す）。
const HOLE: &str = "_";

impl ITy {
    /// 型を診断に示す形にする（`Ty::show` と同じ形）。まだ決まっていない型変数と誤りの型は `_` と示す。
    /// エフェクトは確定した要素だけを示す。変数の要素まで示すときは、呼び出し側が先に変数の集合を
    /// 確定した要素へ移しておく（`Solver` の診断はそうする）。
    pub fn show(&self, names: &TyNames<'_>) -> String {
        let mut out = String::new();
        self.show_into(names, &mut out);
        out
    }

    /// `out` に型の表示を書き足す。型の入れ子の深さだけ再帰するので、各段で `String` を作って
    /// `format!` で継ぎ合わせずに、一つの `String` に書き足して 1 段あたりのスタックを小さく保つ
    /// （深さ 1000 の型を既定のスタックで表示できるようにする。ADR 0087）。
    fn show_into(&self, names: &TyNames<'_>, out: &mut String) {
        match self {
            ITy::Var(_) | ITy::Error => out.push_str(HOLE),
            ITy::Con(c, args) => {
                out.push_str(&names.con_name(*c));
                if !args.is_empty() {
                    out.push('[');
                    show_list(args, names, out);
                    out.push(']');
                }
            }
            ITy::Fn(f) => show_fn(f, names, out),
            ITy::Param(i) => out.push_str(&names.type_param_name(*i)),
        }
    }
}

/// 型の並びを `, ` で区切って書き足す。
fn show_list(tys: &[ITy], names: &TyNames<'_>, out: &mut String) {
    let mut first = true;
    for t in tys {
        if !first {
            out.push_str(", ");
        }
        first = false;
        t.show_into(names, out);
    }
}

/// `fn(引数) -> 戻り値 uses エフェクト` を書き足す。
fn show_fn(f: &IFnTy, names: &TyNames<'_>, out: &mut String) {
    out.push_str("fn(");
    show_list(&f.params, names, out);
    out.push_str(") -> ");
    f.ret.show_into(names, out);
    if !f.effect.fixed.is_empty() {
        out.push_str(" uses ");
        out.push_str(&names.show_effects(&f.effect.fixed));
    }
}
