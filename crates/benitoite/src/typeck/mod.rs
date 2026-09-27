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

use crate::diag::Diagnostic;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::{Item, Program};

/// 宣言の検査と本体の検査を行う（02-05「検査の手順」）。誤りがあっても出力を返す。
/// 呼び出し側は、診断に誤りが一つでもあれば出力を使わない（ADR 0019）。
pub fn typecheck(
    prelude: &[Program],
    user: &Program,
    resolved: &ResolveOutput,
) -> (TypeckOutput, Vec<Diagnostic>) {
    let mut diags = Vec::new();
    // 手順 1: 宣言の検査。宣言の型を本体より先に決める（01-06「型の推論と型注釈」）。
    let decls = decls::check_decls(prelude, user, resolved, &mut diags);

    // 手順 2: 本体の検査。prelude のソースの関数をファイルの順・宣言の順に、続けて利用者の関数を
    // 宣言の順に検査する。ある本体の誤りはほかの本体の検査を止めない（ADR 0024）。
    let mut tables = generate::Tables::default();
    {
        let global = generate::Global {
            resolved,
            decls: &decls,
        };
        for program in prelude.iter().chain(std::iter::once(user)) {
            for item in &program.items {
                if let Item::Fn(f) = item {
                    generate::check_fn(&global, f, &mut tables, &mut diags);
                }
            }
        }
    }

    // 手順 3: 表の組み立て。
    let out = TypeckOutput {
        expr_types: tables.expr_types,
        type_args: tables.type_args,
        operand_types: tables.operand_types,
        lambda_effects: tables.lambda_effects,
        decl_types: decls.decl_types,
        adts: decls.adts,
        main: decls.main,
    };
    (out, diags)
}

#[cfg(test)]
mod tests;
