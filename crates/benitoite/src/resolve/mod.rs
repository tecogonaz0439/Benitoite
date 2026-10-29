//! 名前解決（設計書 02-04）。AST を変更せず、表を出力する（02-01「段と段の間のデータ」）。
//! プログラム全体を一つの単位として解決する（02-01「段と段の間のデータ」）。

use std::collections::BTreeMap;

use crate::base::{BindingId, BindingMap, ModuleId, NodeId, NodeMap, Span};
use crate::builtins::BuiltinId;
use crate::diag::Diagnostic;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId};

/// 束縛の種類（02-04「束縛と表」の束縛の種類の表）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BindingKind {
    /// トップレベルの関数（外部の関数の宣言を含む）
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
    /// コンポーネントの resource に対応する外部の型
    ExternalType,
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
    /// AST のノード（設計書 02-03「AST」）
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
    /// `public` だけを付けたか。局所の束縛と型パラメータは `false`。構成子・フィールド・メソッド・操作は、
    /// それを含む宣言の `public` と同じ
    pub public: bool,
    /// `public(package)` を付けたか。構成子・欄・メソッド・操作は包む宣言の値を受け継ぐ
    pub package: bool,
    /// Data/Record自身だけが持つ `@opaque` の印。構成子・欄は親型から引く。
    pub opaque: bool,
    /// `@deprecated` の文字列
    pub deprecated: Option<String>,
}

/// 名前解決の出力（02-04「束縛と表」）。
#[derive(Debug, Default)]
pub struct ResolveOutput {
    /// 通常の型・値ではない局所宣言と直接操作（02-05「出力」）。
    pub builder_decls: BindingMap<builders::BuilderDecl>,
    pub builder_binds: NodeMap<BindingId>,
    pub builder_calls: NodeMap<builders::BuilderCall>,
    /// 束縛の表: 束縛の番号 → 束縛
    pub bindings: BindingMap<Binding>,
    /// 参照の表: 名前を使う箇所のノード番号 → 束縛の番号。解決できなかった名前は載せない
    pub refs: NodeMap<BindingId>,
    /// 名前の種類を確認し正規化した閉じた範囲。非 Top の注釈だけを載せる。
    pub scopes: NodeMap<crate::types::scope::Range>,
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
    /// 型・関数・エフェクトを綴りでなく名前空間の名前で照合するために使う（02-04「標準ライブラリのソースの持ち方」）
    pub stdlib_names: BTreeMap<String, BindingId>,
    /// 組み込みのエフェクトの操作の束縛 → 組み込みの関数の表の項目（設計書 02-04「束縛と表」）。
    /// 利用者のエフェクトの操作は載せない
    pub builtin_ops: BindingMap<BuiltinId>,
    /// 外部の関数の束縛 → 属性と照合の結果（設計書 03-10「照合」）。
    /// 名前解決が属性を入れ、外部の関数の照合が spec を埋める。
    pub externals: BindingMap<crate::external::ExternalDecl>,
    /// プログラムの入口: 実行を始めるモジュールのトップレベルの関数 `main`。なければ `None`
    /// （02-04「宣言の検査」の `main` の位置）
    pub main: Option<BindingId>,
    /// 誤りと警告（`@deprecated` の参照）
    pub diagnostics: Vec<Diagnostic>,
}

use crate::base::{IdGen, SourceTable};
use crate::modules::{ModuleKind, ModuleTable};
use crate::syntax::ast::Module;

/// 二つのモジュールが同じパッケージに属するか（02-04「名前の引き方」）。
/// 根、標準、依存の範囲を区別し、設定ファイルと存在しない ID は同じパッケージとみなさない。
pub fn same_package(modules: &ModuleTable, a: ModuleId, b: ModuleId) -> bool {
    let (Some(a), Some(b)) = (modules.get(a), modules.get(b)) else {
        return false;
    };
    match (a.kind, b.kind) {
        // 依存の依存を許さないため、先頭の依存別名で識別できる。
        (ModuleKind::Package, ModuleKind::Package) => a
            .name
            .0
            .first()
            .is_some_and(|name| Some(name) == b.name.0.first()),
        (ModuleKind::Entry | ModuleKind::User, ModuleKind::Entry | ModuleKind::User)
        | (ModuleKind::Prelude | ModuleKind::Stdlib, ModuleKind::Prelude | ModuleKind::Stdlib) => {
            true
        }
        _ => false,
    }
}

/// プログラム全体の名前を解決する（02-04「解決の手順」の手順 1〜6）。`asts` の添字はモジュールの ID の値。
/// 束縛の番号は `ids` から、トップレベルの宣言にはモジュールの ID の順に、各モジュールの中では宣言の順に振る。
/// 組み込みの型とエフェクトの束縛は、組み込みの表（`types::builtin`）から作る。
/// `sources` は読み込みの段のソースの表（`LoadOutput::sources`）。修正案の位置（行の先頭、行末の改行）を
/// 字句の span から求めるために、ソースの本文を読む。
/// 誤りがあっても出力を返す。呼び出し側は、診断に誤りが一つでもあれば型検査に進まない（02-01「誤りが見つかったときの段の進め方」）。
pub fn resolve(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    ids: &mut IdGen,
) -> ResolveOutput {
    let mut resolver = collect::Resolver::new(modules, asts, sources, ids);
    resolver.declarations();
    resolver.bodies();
    resolver.check_constants();
    resolver.out
}

// 宣言を読む道具も通常の名前解決と同じ import・可視性・循環の検査を使う
// （設計書 02-01「宣言だけの収集」）。本体の参照と定数の依存は辿らない。
pub(crate) fn resolve_declarations(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    ids: &mut IdGen,
) -> ResolveOutput {
    let mut resolver = collect::Resolver::new(modules, asts, sources, ids);
    resolver.declarations();
    resolver.out
}

impl collect::Resolver<'_> {
    fn declarations(&mut self) {
        self.collect();
        self.imports();
        self.signatures();
        self.check_declarations();
    }
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

// 段階を一つの値で渡し、公開の印の組み合わせを取り違えない
// （設計書 02-04「束縛と表」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum Level {
    Private,
    Package,
    Public,
}
impl Level {
    fn of(public: bool, package: bool) -> Self {
        if public {
            Self::Public
        } else if package {
            Self::Package
        } else {
            Self::Private
        }
    }
}

pub mod builders;
mod checks;
mod collect;
mod imports;
mod lookup;
pub(crate) mod renames;
mod shadow;
pub(crate) mod suggest;
mod text;
mod walk;

#[cfg(test)]
pub(crate) mod test_support;
#[cfg(test)]
mod tests;

mod scope;
