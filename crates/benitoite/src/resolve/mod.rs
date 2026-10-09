//! 名前解決（設計書 02-04）。AST を変更せず、表を出力する（ADR 0022）。
//! プログラム全体を一つの単位として解決する（ADR 0156）。

use std::collections::BTreeMap;

use crate::base::{BindingId, BindingMap, ModuleId, NodeId, NodeMap, Span};
use crate::builtins::BuiltinId;
use crate::diag::Diagnostic;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId};

/// 束縛の種類（02-04「束縛と表」の束縛の種類の表）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BindingKind {
    /// トップレベルの関数（本体を持つもの）
    Fn,
    /// `@builtin` を付けた本体のない関数。組み込みの関数の表の項目
    BuiltinFn(BuiltinId),
    /// 実装の中の関数。`impl_decl` は実装の宣言のノード番号
    ImplFn {
        impl_decl: NodeId,
    },
    Const,
    /// `data` の型
    Data,
    /// 組み込みの型（ソースに宣言の構文がない型）
    BuiltinType(BuiltinTypeId),
    /// 型の別名
    Alias,
    Record,
    /// レコードのフィールド（フィールドを取り出す関数を兼ねる）。`index` は宣言の順の位置
    Field {
        record: BindingId,
        index: u32,
    },
    /// データ構成子。`tag` は型の宣言の中で 0 から数えた番号
    Ctor {
        data: BindingId,
        tag: u32,
    },
    Trait,
    /// 型クラスのメソッド。`index` は宣言の順の位置
    Method {
        trait_: BindingId,
        index: u32,
    },
    /// ソースで宣言したエフェクト（標準ライブラリのソースの組み込みのエフェクトを含む）
    Effect,
    /// ソースに宣言のないエフェクト（`State`・`IO.All`）
    BuiltinEffect(BuiltinEffectId),
    /// エフェクトの操作。`index` は宣言の順の位置
    Op {
        effect: BindingId,
        index: u32,
    },
    /// モジュール（import で付けた名前、prelude のモジュール）
    Module(ModuleId),
    /// 名前空間の根 `Benitoite`
    NamespaceRoot,
    /// 型パラメータ（型構成子を表すものを含む）。`owner` はそれを並べた宣言のノード番号、
    /// `index` はその宣言の型パラメータの並び（エフェクト変数を除く）の中の位置
    TypeParam {
        owner: NodeId,
        index: u32,
    },
    /// エフェクト変数。`index` はその宣言のエフェクト変数の並びの中の位置
    EffectVar {
        owner: NodeId,
        index: u32,
    },
    /// 局所の束縛
    Local(LocalKind),
}

/// 局所の束縛の種類。シャドーイングの規則（01-03「シャドーイング」）と診断の文言に使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum LocalKind {
    /// 関数・メソッド・操作の引数
    Param,
    LambdaParam,
    /// 束縛の文の左辺の変数（`bind`・`shadow`）
    BindVar,
    /// `match` の分岐のパターンの変数（リストのパターンの残りの変数を含む）
    PatternVar,
    /// `with` の束縛
    WithVar,
    /// `handle` の節の引数
    ClauseParam,
}

/// 束縛を宣言した場所。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DeclSite {
    /// AST のノード（[字句と構文木](10-03-syntax.md)の「束縛を宣言したノード」）
    Node(NodeId),
    /// 組み込みの表の項目（組み込みの型、`State`・`IO.All`、prelude のモジュール、`Benitoite`）
    Table,
}

/// 束縛の表の項目（02-04「束縛と表」）。
#[derive(Clone, PartialEq, Debug)]
pub struct Binding {
    pub kind: BindingKind,
    pub name: String,
    /// 宣言したモジュール。`Benitoite` は標準ライブラリの根として prelude の最初のモジュールの ID を持つ
    pub module: ModuleId,
    pub decl: DeclSite,
    /// 名前の位置。組み込みの表のものは `None`
    pub span: Option<Span>,
    /// `public` を付けたか。局所の束縛と型パラメータは `false`。構成子・フィールド・メソッド・操作は、
    /// それを含む宣言の `public` と同じ
    pub public: bool,
    /// `@deprecated` の文字列
    pub deprecated: Option<String>,
}

/// 名前解決の出力（02-04「束縛と表」）。
#[derive(Debug, Default)]
pub struct ResolveOutput {
    /// 束縛の表: 束縛の番号 → 束縛
    pub bindings: BindingMap<Binding>,
    /// 参照の表: 名前を使う箇所のノード番号 → 束縛の番号。解決できなかった名前は載せない
    pub refs: NodeMap<BindingId>,
    /// 宣言したノードのノード番号 → 束縛の番号
    pub decls: NodeMap<BindingId>,
    /// 公開の表: モジュール → そのモジュールのトップレベルの名前 → 束縛の番号。
    /// `public` を付けたものだけを載せる。構成子・フィールド・メソッドは型・レコード・型クラスの中の名前なので
    /// 載せない（型検査と脱糖は AST と束縛の種類から引く）
    pub exports: BTreeMap<ModuleId, BTreeMap<String, BindingId>>,
    /// prelude を隠した参照の表: 利用者の名前が prelude の名前を隠した参照のノード番号 → 隠された prelude の束縛
    pub prelude_shadowed: NodeMap<BindingId>,
    /// 標準ライブラリの名前の索引: `Benitoite` から始まる完全な名前（`"Benitoite.Option.Some"`、
    /// `"Benitoite.Map.fromList"`、`"Benitoite.IO.Console.Write"`）→ 束縛の番号。読んだ標準ライブラリの
    /// モジュールの公開した名前と、その中の構成子・フィールド・メソッド・操作を載せる。処理系が組み込みの
    /// 型・関数・エフェクトを綴りでなく名前空間の名前で照合するために使う（ADR 0128）
    pub stdlib_names: BTreeMap<String, BindingId>,
    /// 組み込みのエフェクトの操作の束縛 → 組み込みの関数の表の項目（10-04「名前解決の表」）。
    /// 利用者のエフェクトの操作は載せない
    pub builtin_ops: BindingMap<BuiltinId>,
    /// プログラムの入口: 実行を始めるモジュールのトップレベルの関数 `main`。なければ `None`
    /// （02-04「宣言の検査」の `main` の位置）
    pub main: Option<BindingId>,
    /// 誤りと警告（`@deprecated` の参照）
    pub diagnostics: Vec<Diagnostic>,
}

use crate::base::{IdGen, SourceTable};
use crate::modules::ModuleTable;
use crate::syntax::ast::Module;

/// プログラム全体の名前を解決する（02-04「解決の手順」の手順 1〜6）。`asts` の添字はモジュールの ID の値。
/// 束縛の番号は `ids` から、トップレベルの宣言にはモジュールの ID の順に、各モジュールの中では宣言の順に振る。
/// 組み込みの型とエフェクトの束縛は、組み込みの表（10-05 の `types::builtin`）から作る。
/// `sources` は読み込みの段のソースの表（`LoadOutput::sources`）。修正案の位置（行の先頭、行末の改行）を
/// 字句の span から求めるために、ソースの本文を読む。
/// 誤りがあっても出力を返す。呼び出し側は、診断に誤りが一つでもあれば型検査に進まない（ADR 0019）。
pub fn resolve(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    ids: &mut IdGen,
) -> ResolveOutput {
    let mut resolver = collect::Resolver::new(modules, asts, sources, ids);
    resolver.collect();
    resolver.imports();
    resolver.signatures();
    resolver.check_declarations();
    resolver.bodies();
    resolver.check_constants();
    resolver.out
}

impl ResolveOutput {
    /// 標準ライブラリの名前を完全な名前（`"Benitoite.Option.Some"`）で引く。読んでいないモジュールの名前は `None`。
    pub fn stdlib(&self, full_name: &str) -> Option<BindingId> {
        self.stdlib_names.get(full_name).copied()
    }
    /// 名前を使う箇所のノードが指す束縛。
    pub fn binding_of_ref(&self, node: NodeId) -> Option<&Binding> {
        self.bindings.get(*self.refs.get(node)?)
    }
}

mod checks;
mod collect;
mod imports;
mod lookup;
mod shadow;
pub(crate) mod suggest;
mod text;
mod walk;

#[cfg(test)]
pub(crate) mod test_support;
#[cfg(test)]
mod tests;
