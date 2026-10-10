//! 型検査（設計書 02-05）。
//! infer.rs: 推論の型と制約、patterns.rs: パターンの検査。
//! 制約の生成、制約の解決、宣言の検査、定数の評価の子のモジュールは F07〜F10 の作業の文書で分ける。
//!
//! フックは次の表の関数として固定する。Decls は宣言の情報、Body は本体の可変の文脈である。
//! 表の入力の Decls と Body はいずれも可変の参照で、戻り値の — は () を表す。
//!
//! | 番号・関数 | 呼ぶ位置 | 入力 | 戻り値 | 仮の本体 | 中身を書く作業 |
//! |---|---|---|---|---|---|
//! | T1 traits::collect | 宣言の収集の後 | Decls | — | 受け付ける | F08 |
//! | T2 traits::check_parameters | 型パラメータを移すとき | Decls、宣言の並び、Scope、Scheme、制約を書けるか | — | 受け付ける | F08 |
//! | T3 traits::check_impls | 宣言の要約の後 | Decls | — | 受け付ける | F08 |
//! | T4 traits::instantiate | クラスの制約を持つ名前の具体化 | Body、NodeId、Span、Scheme、型引数 IArg の並び、IEffect の並び | — | 受け付ける | F08 |
//! | T5 traits::method | メソッドの名前 | Body、NameExpr | ITy | Error を返す | F08 |
//! | T6 traits::solve_classes | エフェクトの解決の後 | Body（constraints の Class） | — | 受け付ける | F08 |
//! | T7 traits::check_bound | Param に対する組み込みの制約 | Body、パラメータの番号、区分（0: 集まり、1: 等値、2: 鍵）、Option<TySet>、Reason | — | 満たすものとする | F08 |
//! | E1 effects::check_uses | uses を移すとき | Decls、UsesList、Scope | — | 受け付ける | F09 |
//! | E2 effects::check_entries | main と @test の署名の検査の後 | Decls | — | 受け付ける | F09 |
//! | E3 effects::expr | lazy、with、try、handle、resume | Body、Expr | ITy | 子を辿らず Error を返す | F09 |
//! | E4 effects::name | 名前を使うとき | Body、NameExpr、with の束縛の直接の呼び出しか | — | 受け付ける | F09 |
//! | E5 effects::solve_special | 型の制約の解決の後、エフェクトの解決の前 | Body（constraints の Try と Resource） | — | 満たすものとする | F09 |
//! | E6 effects::check_body | 本体の後の検査 | Body（owner、scheme、actual_effects を参照） | — | 受け付ける | F09 |
//! | E7 effects::effect_failure | LazyBody のエフェクトの失敗 | Body、Reason、示すエフェクトの文字列、呼び出しの Span | Diagnostic | E0501 を作る | F09 |
//! | P1 pattern_ext::pattern | 範囲・リストのパターン | Body、Pattern | ITy | Error を返す | F10 |
//! | P2 pattern_ext::alternatives | 二つ以上の選択肢を辿った後 | Body、MatchArm | — | 受け付ける | F10 |
//! | P3 pattern_ext::guard | ガード | Body、Expr | — | 子を辿らない | F10 |
//! | P4 pattern_ext::check_body | 本体の後の検査 | Body（matches と bindings） | — | 受け付ける | F10 |
//! | P5 pattern_ext::effect_failure | MatchGuard のエフェクトの失敗 | Body、Reason、示すエフェクトの文字列、呼び出しの Span | Diagnostic | E0501 を作る | F10 |
//!
//! Body::expr_in、block_in、pattern_in は E と R を差し替え、終了後に元へ戻す。
//! Body::unify はフックが生成した型の一致を解き、失敗を通常の診断にする。
//! E5 は決まる必要のある型を Body::require_type で登録し、Solver::zonk で判定する。
//! constraints の Class は T6 が、Try と Resource は E5 が取り出す。
//! 含まれる制約は Body::add で加え、E5 の後に共通の Solver が解く。
//! 出力の表は本体の文脈に記録し、Body::finish で型を確定してから TypeckOutput へ移す。

pub mod infer;
pub mod patterns;

use crate::base::{BindingId, BindingMap, NodeMap};
use crate::types::{
    AdtTable, ConstValue, DictExpr, EffectDef, EffectSet, ImplDef, Scheme, TraitDef, Ty, TypeArgs,
};

/// `main` の情報（01-07「プログラムの入口」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct MainInfo {
    pub binding: BindingId,
    /// 戻り値の型が `Result[Unit, String]` か（そうでなければ `Unit`）
    pub returns_result: bool,
}

/// `try` の対象の種類（01-09）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TryKind {
    Result,
    Option,
}

/// `try` の型検査の結果（02-05「出力」の「`try` の種類」）。
#[derive(Clone, PartialEq, Debug)]
pub struct TryInfo {
    pub kind: TryKind,
    /// 最も内側の関数かラムダの戻り値の型（`Result[U, E]` か `Option[U]`）。
    /// 脱糖は、`escape` に渡す構成子の型引数をここから読む
    pub ret: Ty,
}

/// `handle` の節一つの型検査の結果。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ClauseInfo {
    /// 節の操作の束縛の番号（`Op` の束縛。組み込みのエフェクトの操作は、名前解決の `builtin_ops` で組み込みの関数の項目を引ける）
    pub op: BindingId,
    /// 末尾で再開する節か（02-05「書く位置の検査」）
    pub tail_resumptive: bool,
}

/// `handle` の型検査の結果（02-05「出力」の「ハンドラの節」）。
#[derive(Clone, PartialEq, Debug)]
pub struct HandleInfo {
    /// 節の順
    pub clauses: Vec<ClauseInfo>,
    /// handled(H): すべての操作の節を持つエフェクトの集合
    pub handled: EffectSet,
}

/// 型検査の出力（02-05「出力」）。表に書く型は型変数を含まない。鍵と値は実装プラン 10-05「型検査の出力」の表。
#[derive(Debug, Default)]
pub struct TypeckOutput {
    pub expr_types: NodeMap<Ty>,
    pub type_args: NodeMap<TypeArgs>,
    pub operand_types: NodeMap<Ty>,
    pub interp_types: NodeMap<Ty>,
    pub lambda_effects: NodeMap<EffectSet>,
    pub dicts: NodeMap<Vec<DictExpr>>,
    pub try_kinds: NodeMap<TryInfo>,
    pub handlers: NodeMap<HandleInfo>,
    pub lit_values: NodeMap<ConstValue>,
    pub range_bounds: NodeMap<(ConstValue, ConstValue)>,
    pub decl_types: BindingMap<Scheme>,
    pub consts: BindingMap<ConstValue>,
    pub adts: AdtTable,
    pub traits: BindingMap<TraitDef>,
    pub impls: NodeMap<ImplDef>,
    pub effects: BindingMap<EffectDef>,
    /// `require_main` が真で誤りがなければ `Some`
    pub main: Option<MainInfo>,
}

use crate::base::SourceTable;
use crate::diag::Diagnostic;
use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Module;

/// プログラム全体の型を検査する（02-05「検査の単位と手順」の手順 1〜5）。`asts` の添字はモジュールの ID の値。
/// `require_main` は `check` と `run` の経路で真、`test` の経路で偽（02-05「宣言の検査」の `main`）。
/// 誤りと警告を診断として返す。誤りがあっても出力を返す。
/// `sources` は読み込みの段のソースの表（`LoadOutput::sources`）。診断に型注釈の綴りを示すのに使う。
/// 呼び出し側は、診断に誤りが一つでもあれば出力を使わない（02-01「誤りが見つかったときの段の進め方」）。
pub fn typecheck(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
    require_main: bool,
) -> (TypeckOutput, Vec<Diagnostic>) {
    decls::check(modules, asts, sources, resolved, require_main)
}

mod consts;
mod context;
mod decls;
mod effects;
mod generate;
mod limits;
mod pattern_ext;
mod records;
mod solve;
#[cfg(test)]
pub(crate) mod test_support;
#[cfg(test)]
mod tests;
mod text;
mod traits;
