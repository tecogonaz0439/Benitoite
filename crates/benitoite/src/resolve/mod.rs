//! 名前解決（設計書 02-04）。AST を変更せず、表を出力する（ADR 0022）。

use crate::base::{BindingId, BindingMap, NodeId, NodeMap, Span};
use crate::builtins::{BuiltinId, PreludeModule};
use crate::diag::Diagnostic;
use crate::types::TyCon;

/// 束縛の種類（02-04「束縛」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BindingKind {
    /// 利用者のトップレベルの関数
    TopFn,
    /// prelude のソースの関数。`module` が `None` なら補助の関数（修飾しない名前）
    PreludeFn { module: Option<PreludeModule> },
    /// 組み込みの関数
    Builtin(BuiltinId),
    /// データ構成子。`tag` は型の宣言の中で 0 から数えた番号
    Ctor { con: TyCon, tag: u32 },
    /// 関数の引数
    Param,
    /// `let` の束縛
    Let,
    /// ラムダの引数
    LambdaParam,
    /// パターンの変数
    PatternVar,
    /// 型（基本型、`List`・`Option`・`Result`・`IoError`、利用者の型）。型の名前はモジュールを兼ねる
    Type(TyCon),
    /// 型パラメータ。`index` は宣言の型パラメータの並び（`effect` を付けたものを除く）の中の位置
    TypeParam { index: u32 },
    /// エフェクト変数。`index` は宣言のエフェクト変数の並びの中の位置
    EffectVar { index: u32 },
    /// エフェクトの名前（最小実行版では `IO` だけ）
    Effect,
    /// 型を持たないモジュール（`Console`・`File`・`Process`）
    Module(PreludeModule),
}

/// 束縛を宣言した場所。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DeclSite {
    /// AST のノード（関数の宣言、型の宣言、データ構成子の宣言、型パラメータの宣言、引数、`let` 文、変数のパターン）
    Node(NodeId),
    /// 組み込みの表の項目（組み込みの関数、prelude の型・構成子・モジュール、`IO`）
    Prelude,
}

#[derive(Clone, PartialEq, Debug)]
pub struct Binding {
    pub kind: BindingKind,
    pub name: String,
    pub decl: DeclSite,
    /// 名前の位置。組み込みの表のものは `None`
    pub span: Option<Span>,
}

/// 名前解決の出力。
#[derive(Debug, Default)]
pub struct ResolveOutput {
    /// 束縛の表: 束縛の番号 → 束縛
    pub bindings: BindingMap<Binding>,
    /// 参照の表: 名前を使う箇所のノード番号 → 束縛の番号。
    /// 名前を使う箇所は NameExpr・NamedType・EffectRef・CtorPat。解決できなかった名前は載せない
    pub refs: NodeMap<BindingId>,
    /// 宣言したノードの番号 → 束縛の番号
    pub decls: NodeMap<BindingId>,
    /// prelude の型と構成子と組み込みの関数の束縛の番号。型検査と脱糖が引く
    pub prelude: PreludeBindings,
    pub diagnostics: Vec<Diagnostic>,
}

/// prelude の名前の束縛の番号（組み込みの表の項目ごとに一つ振る）。
#[derive(Debug, Default)]
pub struct PreludeBindings {
    /// 組み込みの関数ごとの束縛の番号
    pub builtins: Vec<(BuiltinId, BindingId)>,
    /// `Some`・`None`・`Ok`・`Err` の束縛の番号
    pub some: Option<BindingId>,
    pub none: Option<BindingId>,
    pub ok: Option<BindingId>,
    pub err: Option<BindingId>,
}

use crate::base::IdGen;
use crate::syntax::ast::Program;

mod collect;
mod lookup;
mod suggest;
mod text;
mod walk;

#[cfg(test)]
mod tests;

/// prelude のソース（ファイルの名前の順）と利用者のソースの名前を解決する。手順は 02-04「解決の手順」。
/// 束縛の番号は `ids` から振る。組み込みの表は `crate::builtins` から読む。
pub fn resolve(prelude: &[Program], user: &Program, ids: &mut IdGen) -> ResolveOutput {
    let mut r = collect::Resolver::new(ids);
    // 束縛の番号を振る順序は作業の文書 T13「束縛の番号を振る順序」に従う。
    // 1〜5: 組み込みの表の名前
    r.bind_builtin_table();
    // 6: prelude のソースの関数
    r.collect_prelude(prelude);
    // 7: 利用者のトップレベルの宣言（02-04「解決の手順」の手順 2）
    r.collect_user(user);
    // 8: 各宣言の中（手順 3・4）。prelude のソースを先に辿る
    for program in prelude {
        r.walk_program(collect::Src::Prelude, program);
    }
    r.walk_program(collect::Src::User, user);
    r.out
}
