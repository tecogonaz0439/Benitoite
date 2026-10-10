# モジュールと名前解決

本章は、読み込みの段（モジュールの探索と読み込み、モジュールの表、依存グラフと循環の検出）と、名前解決の出力の表（束縛の表、参照の表、公開の表、prelude を隠した参照の表）と関数のシグネチャを定める。設計書の対応する章は[名前解決とモジュール読込](../../2026-10-09-design-first-release/02-impl/02-04-resolver.md)と[ソース管理と位置情報](../../2026-10-09-design-first-release/02-impl/02-02-source-and-spans.md)であり、規則は[名前・スコープ・モジュール](../../2026-10-09-design-first-release/01-spec/01-03-names-modules.md)で定める。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

- 置く作業: C02

本章のコードは C02 が置く。U2 第 1 段はモジュールの表と名前解決の表を使わないので、C01 は本章を置かない。

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/modules/mod.rs` | 加える（`file=` と `sig=`） | F05 |
| `src/resolve/mod.rs` | 置く（`file=` と `sig=`） | F06 |

「置く」のファイルは、C04 が最小実行版の同じパスのファイルを `src/legacy/` へ移して空けたパスに、新しく置く（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」）。最小実行版の `resolve` の子のモジュール（`src/legacy/resolve/` の `collect.rs`・`lookup.rs`・`walk.rs`・`suggest.rs`・`text.rs`）は、F06 が写して新しい AST と表に合わせて書き直す。綴りの近い名前を探す `suggest.rs` と、種類の呼び名を集めた `text.rs` は、写してそのまま使ってよい。

## 読み込みの段

読み込みの段は、実行を始めるファイルから import を辿ってファイルを読み、読むたびに字句解析と構文解析を行う（02-01「段と段の間のデータ」、ADR 0156）。作業の一覧の進め方とファイル ID の振り方は 02-02「ソースとファイル ID」の 4 手順に、モジュールの探し方は 02-04「モジュールの探し方」に、循環の検出は 02-04「依存グラフと循環の検出」に従う。

ファイルシステムは `ModuleFs` を通して読む。テストは、ファイルシステムを使わずにディレクトリの項目と内容を与える実装を作り、大文字と小文字を区別しないファイルシステムの振る舞い（ADR 0244）とシンボリックリンクの解決を再現できる。本番の実装は `RealFs` である。

標準ライブラリのソースは、ファイルシステムから読まず、処理系に埋め込んだ表（`StdlibModuleSource` の並び）から引く（02-04「標準ライブラリのソースの持ち方」）。表は prelude と標準ライブラリのソースの章（10-14）が `prelude` モジュールに `include_str!` で置き、パイプライン（10-13）が `load_program` に渡す。本章は表の要素の型だけを定める。

モジュールの ID はファイル ID と同じ値である（[基本の型](10-01-base.md)の `ModuleId`）。ファイル一つがモジュール一つなので、ソースの表に加えたファイルはどれもモジュールの表に項目を持ち、`LoadOutput::asts` の添字はモジュールの ID の値と一致する。読めなかったファイルはソースの表に加えないので、ID の対応は崩れない。

```rust file=src/modules/mod.rs needs=10-02
//! 読み込みの段: モジュールの探索と読み込み、モジュールの表、依存グラフと循環の検出
//! （設計書 02-04「モジュールの表」「モジュールの探し方」「依存グラフと循環の検出」「標準ライブラリのソースの持ち方」、
//! 02-02「ソースとファイル ID」、ADR 0126・0127・0156・0244）。

use std::path::PathBuf;

use crate::base::{ModuleId, NodeId, SourceTable};
use crate::diag::Diagnostic;
use crate::syntax::ast;
use crate::syntax::token::Comment;

/// 一つの検査で読むすべてのソース（標準ライブラリのソースを含む）の大きさの和の上限（512 MiB）。
/// 超えたら読み込みの誤り E0101 とする。ノード番号と束縛の番号を u32 に収めるための処理系の制限である
/// （ノードと束縛は字句に対応して作るので、数はソースの大きさの和の定数倍に収まる）。
/// ファイル一つの上限は `base::source::MAX_SOURCE_BYTES`（最小実行版のまま）。
pub const MAX_TOTAL_SOURCE_BYTES: usize = 512 * 1024 * 1024;

/// モジュールの名前の各段。利用者のモジュールは根のディレクトリからの名前（`["Lib", "Text"]`）、
/// 標準ライブラリのモジュールは `Benitoite` から始まる名前（`["Benitoite", "IO", "Console"]`）。
#[derive(Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ModulePath(pub Vec<String>);

impl ModulePath {
    /// 段をドットでつないだ形（`Lib.Text`）。診断に示す。
    pub fn dotted(&self) -> String {
        self.0.join(".")
    }
}

/// モジュールの種類（02-04「モジュールの表」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ModuleKind {
    /// 実行を始めるモジュール
    Entry,
    /// import で読み込んだ利用者のモジュール
    User,
    /// prelude のモジュール（標準ライブラリのうち import なしで使える部分）
    Prelude,
    /// prelude でない標準ライブラリのモジュール
    Stdlib,
}

/// import の宣言一つと、取り込むモジュール。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ImportLink {
    /// import の宣言のノード番号
    pub decl: NodeId,
    /// 取り込むモジュール。読み込みの誤りで決まらなかったときは `None`
    pub target: Option<ModuleId>,
}

/// モジュールの表の項目一つ。
#[derive(Clone, PartialEq, Debug)]
pub struct ModuleInfo {
    pub id: ModuleId,
    pub name: ModulePath,
    pub kind: ModuleKind,
    /// import の宣言を書いた順に並べた取り込み先（依存グラフの辺）
    pub imports: Vec<ImportLink>,
}

/// モジュールの表。モジュールの ID の値の順に並べる。読み込みを終えた後は変更しない（02-04）。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct ModuleTable {
    pub modules: Vec<ModuleInfo>,
}

/// 処理系に埋め込んだ標準ライブラリのモジュール一つ（02-04「標準ライブラリのソースの持ち方」）。
/// 表は 10-14 が `prelude` モジュールに置く。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct StdlibModuleSource {
    /// `Benitoite` を除いたモジュールの名前の段（`&["IO", "Console"]`）。ソースは標準ライブラリの根の下の
    /// `IO/Console.bnt` であり、表示名は `<benitoite>/IO/Console.bnt` とする
    pub path: &'static [&'static str],
    /// prelude に入るか
    pub prelude: bool,
    /// 非公式のモジュールか（設計書 03-06「標準のモジュールと非公式のモジュール（初回リリース版）」、ADR 0286）。
    /// 真なら `import Benitoite.Unofficial.<path>` で取り込み、偽なら `import Benitoite.<path>` で取り込む。
    /// `path` は、どちらでも標準に加えた後の名前の段である
    pub unofficial: bool,
    pub text: &'static str,
}

/// 実行を始めるファイル（02-02「ソースとファイル ID」、ADR 0127）。
/// ディレクトリを指定したときの `main.bnt` の補いと表示名の組み立ては、呼び出し側（パイプライン）が行う。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct EntrySpec {
    /// 読むファイルのパス
    pub path: PathBuf,
    /// 表示名（コマンドラインで与えたパス、またはディレクトリのパスに `main.bnt` を続けた名前）
    pub display_name: String,
    /// 根のディレクトリ。通常は `path` のあるディレクトリ。`test` でディレクトリを指定したときは
    /// そのディレクトリ（01-03「実行を始めるモジュール（初回リリース版）」）
    pub root: PathBuf,
}

/// ディレクトリの項目一つ（ADR 0244 の照合に使う）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct DirEntryName {
    /// ファイルシステムに保存された名前
    pub name: String,
    pub is_dir: bool,
}

/// 読み込みの段の結果。
#[derive(Debug, Default)]
pub struct LoadOutput {
    pub sources: SourceTable,
    pub modules: ModuleTable,
    /// モジュールごとの AST。添字はモジュールの ID の値
    pub asts: Vec<ast::Module>,
    /// モジュールごとのコメントの一覧。添字はモジュールの ID の値
    pub comments: Vec<Vec<Comment>>,
    /// 読み込みの誤り、字句の切り出しの誤り、構文解析の誤り、循環する import の誤り。
    /// ファイル ID の順に、各ファイルの中では字句の誤りを構文の誤りより先に並べる
    pub diagnostics: Vec<Diagnostic>,
}
```

`ModuleFs` と `load_program` の中身は F05 が書く。

```rust sig=src/modules/mod.rs needs=10-02
use std::io;
use std::path::Path;

use crate::base::IdGen;

/// 読み込みの段がファイルシステムを読むための操作。テストはファイルシステムを使わない実装を作る。
pub trait ModuleFs {
    /// ファイルの内容を読む。
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>>;
    /// ディレクトリの項目の一覧を読む。名前はファイルシステムに保存された形で返す（ADR 0244）。
    fn list_dir(&self, dir: &Path) -> io::Result<Vec<DirEntryName>>;
    /// シンボリックリンクを解決した絶対パス（02-04「モジュールの探し方」の手順 3）。
    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf>;
}

/// 本番のファイルシステム（`std::fs`）。
#[derive(Clone, Copy, Debug, Default)]
pub struct RealFs;

impl ModuleFs for RealFs {
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>>;
    fn list_dir(&self, dir: &Path) -> io::Result<Vec<DirEntryName>>;
    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf>;
}

impl ModuleTable {
    pub fn get(&self, id: ModuleId) -> Option<&ModuleInfo>;
    /// 名前でモジュールを引く。
    pub fn find(&self, name: &ModulePath) -> Option<&ModuleInfo>;
    pub fn iter(&self) -> impl Iterator<Item = &ModuleInfo>;
}

/// 実行を始めるファイルから import を辿ってすべてのモジュールを読み、字句解析と構文解析を行う
/// （02-02「ソースとファイル ID」の 4 手順）。作業の一覧の最初に実行を始めるファイルを、続けて
/// `stdlib` のうち prelude のモジュールを表の順に置く。`stdlib` の prelude でないモジュールは、
/// import で辿れたものだけを読む（ADR 0156）。
/// すべてのファイルを読み終えた後、依存グラフの循環を明示の積み重ねで調べる（02-04「依存グラフと循環の検出」）。
/// 誤りがあっても読めたものは結果に入れる。呼び出し側は、診断に誤りが一つでもあれば名前解決に進まない。
pub fn load_program(entry: &EntrySpec, stdlib: &[StdlibModuleSource], fs: &dyn ModuleFs, ids: &mut IdGen) -> LoadOutput;
```

- 読んだファイルごとに、10-03 の `lex` と `resolve_newlines` と `parse` を続けて呼ぶ。`parse` には、`lex` に渡したのと同じソースのバイト列を渡す（10-03「構文解析」）。
- ファイルの大きさの上限（[基本の型](10-01-base.md)の `MAX_SOURCE_BYTES`）と、すべてのソースの大きさの和の上限（本章の `MAX_TOTAL_SOURCE_BYTES`）を超えたファイルは、読み込みの誤り E0101 とし、ソースの表に加えない。
- import の誤り（ファイルがない、根の外を指す、実行を始めるファイルを取り込む、根の直下の `Benitoite` を取り込む、大文字と小文字だけが違う項目しかない）の診断は、import の宣言のモジュールの名前の span を主な位置とする（02-04「モジュールの探し方」）。
- `as Benitoite`、同じ名前の二つの import、同じモジュールを二度取り込むことなどの誤りは、名前解決が報告する（02-04「import の宣言の誤り」）。読み込みの段は、同じモジュールを二度読まないだけである。

## 名前解決の表

名前解決は、すべてのモジュールの AST とモジュールの表を受け取り、AST を変更せずに表を出力する（02-04「束縛と表」、ADR 0022）。

束縛の種類は 02-04「束縛と表」の束縛の種類の表と一対一に対応する。次の点を補う。

- 型パラメータとエフェクト変数の束縛は、それを並べた宣言のノード番号（`owner`）と、その宣言の型パラメータの並びの中の位置（`index`。エフェクト変数は数えない。エフェクト変数の `index` はエフェクト変数だけを数えた位置）を持つ。`owner` は、関数・メソッド・操作・実装・型クラス・型の宣言・レコード・型の別名の宣言のノードである。実装の中の関数では、`implement` の直後の型パラメータの `owner` は実装の宣言、関数自身の型パラメータの `owner` は関数の宣言である。型検査は、この二つから宣言の型の型パラメータの番号を決める（[型と型検査](10-05-types.md)の「型パラメータの番号」）。
- 標準ライブラリのソースで宣言した `effect`（`Console.Write` など）の束縛は、利用者のエフェクトと同じく `Effect` である。組み込みのエフェクトであることは、型検査が、宣言したモジュールの名前とエフェクトの名前から組み込みのエフェクトの表（10-05 の `types::builtin`）を引いて決める（ADR 0128）。ソースに宣言のない `State` と `IO.All` だけが、`BuiltinEffect` の束縛を持つ。
- 組み込みの型（ソースに宣言の構文がない型）は、組み込みの型の表（10-05）の項目ごとに、属するモジュールのトップレベルの型として `BuiltinType` の束縛を作る（02-04「標準ライブラリのソースの持ち方」）。
- 標準ライブラリのソースで宣言した組み込みのエフェクトの操作（`Console.writeLine` など）の束縛は、利用者の操作と同じく `Op` である。どのハンドラも処理しない操作は処理系が行い（02-04「標準ライブラリのソースの持ち方」）、脱糖はその呼び出しを組み込みの関数 `b[T̄; Ē]` の適用に移す（02-06「脱糖」）。そのために、名前解決は、組み込みのエフェクトの操作の束縛ごとに、操作の `Benitoite` の名前空間の名前（`Benitoite.IO.Console.writeLine`）で組み込みの関数の表（10-12）を引き、見つけた番号を `builtin_ops` の表に載せる。表にない操作は、標準ライブラリのソースの誤り（処理系の不具合）として報告する。
- `@builtin("名前")` を付けた関数の束縛は `BuiltinFn` であり、組み込みの関数の表の項目の番号を持つ。番号は、組み込みの関数の表の章（10-12）の `builtins::lookup_builtin` で名前から引く。表にない名前は、標準ライブラリのソースの誤り（処理系の不具合）として報告する。
- 名前空間の根 `Benitoite` は `NamespaceRoot` の束縛を一つだけ持つ。prelude のモジュールと、import で取り込んだモジュールに付けた名前は、`Module` の束縛を持つ。prelude のモジュールの `Module` の束縛の宣言した場所は `DeclSite::Table` である。

参照の表の鍵は、[字句と構文木](10-03-syntax.md)の「AST」の表の「名前を使うノード」である。修飾した名前は、最後の段が指す束縛を参照の表に載せる。途中の段の解決の結果は、診断のためにだけ使うので表にしない。鍵ごとの値は次のとおりである。

| 名前を使うノード | 参照の表の値 |
|---|---|
| `NameExpr` | 値（局所の束縛、関数、組み込みの関数、定数、構成子、操作、メソッド、フィールドを取り出す関数） |
| `NamedType` | 型（`Data`・`BuiltinType`・`Record`・`Alias`、型パラメータ） |
| `EffectRef` | エフェクト（`Effect`・`BuiltinEffect`、エフェクト変数） |
| `CtorPat` | 構成子 |
| `RecordExpr`・`RecordPat` | レコード |
| `FieldArg`・`FieldPat` | フィールド |
| `OpRef` | `handle` の節に書いた名前が指す値。操作であるかは型検査が判定する（02-04「誤りと修正案」） |
| `ClassRef` | 型クラス |
| `ImplFn` | 型クラスのメソッド |
| `ImportDecl` | 取り込んだモジュールに付けた名前の `Module` の束縛（`decls` にも同じ番号を載せる） |

選択肢で同じ名前を束縛する `match` の分岐では、最初の選択肢の `VarPat` が束縛を宣言し、ほかの選択肢の同じ名前の `VarPat` は参照の表でその束縛を指す（02-04「名前の引き方」）。したがって、`VarPat` のノード番号は `decls` か `refs` のどちらか一方に載る。

```rust file=src/resolve/mod.rs needs=10-02,10-12
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
    ImplFn { impl_decl: NodeId },
    Const,
    /// `data` の型
    Data,
    /// 組み込みの型（ソースに宣言の構文がない型）
    BuiltinType(BuiltinTypeId),
    /// 型の別名
    Alias,
    Record,
    /// レコードのフィールド（フィールドを取り出す関数を兼ねる）。`index` は宣言の順の位置
    Field { record: BindingId, index: u32 },
    /// データ構成子。`tag` は型の宣言の中で 0 から数えた番号
    Ctor { data: BindingId, tag: u32 },
    Trait,
    /// 型クラスのメソッド。`index` は宣言の順の位置
    Method { trait_: BindingId, index: u32 },
    /// ソースで宣言したエフェクト（標準ライブラリのソースの組み込みのエフェクトを含む）
    Effect,
    /// ソースに宣言のないエフェクト（`State`・`IO.All`）
    BuiltinEffect(BuiltinEffectId),
    /// エフェクトの操作。`index` は宣言の順の位置
    Op { effect: BindingId, index: u32 },
    /// モジュール（import で付けた名前、prelude のモジュール）
    Module(ModuleId),
    /// 名前空間の根 `Benitoite`
    NamespaceRoot,
    /// 型パラメータ（型構成子を表すものを含む）。`owner` はそれを並べた宣言のノード番号、
    /// `index` はその宣言の型パラメータの並び（エフェクト変数を除く）の中の位置
    TypeParam { owner: NodeId, index: u32 },
    /// エフェクト変数。`index` はその宣言のエフェクト変数の並びの中の位置
    EffectVar { owner: NodeId, index: u32 },
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
```

名前解決の関数と、標準ライブラリの名前を引く関数の中身は F06 が書く。

```rust sig=src/resolve/mod.rs needs=10-02,10-12
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
) -> ResolveOutput;

impl ResolveOutput {
    /// 標準ライブラリの名前を完全な名前（`"Benitoite.Option.Some"`）で引く。読んでいないモジュールの名前は `None`。
    pub fn stdlib(&self, full_name: &str) -> Option<BindingId>;
    /// 名前を使う箇所のノードが指す束縛。
    pub fn binding_of_ref(&self, node: NodeId) -> Option<&Binding>;
}
```

- 手順 6 の定数の検査は、定数の循環（E0437）だけを判定する。定数式の形（E0433）は、型検査（F07）が定数の検査の最初に判定し、定数式に書ける関数（`Map.fromList`・`Set.fromList`・`Map.empty`・`Set.empty`）を、`stdlib` で引いた束縛の番号と比べる（02-05「定数の検査と評価」）。
- `@deprecated` の警告は、属性を付けたトップレベルの宣言の外（その宣言の本体とシグネチャの外）からの参照ごとに出す。警告の診断は、10-02 の警告の重大度で作る。
- `bind` と `shadow` の書き分け、キーワードを書けない束縛による隠し、選択肢の名前の集まり、パターンの変数と定数の名前の検査は、02-04「名前の引き方」のとおりに行う。これらの誤りの診断コードは 10-02 で割り当てる。
