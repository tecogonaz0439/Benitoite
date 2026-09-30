# 型と型検査

本章は、型とエフェクトの表現、組み込みの型とエフェクトの表、宣言の情報（代数的データ型、レコード、型クラス、実装、エフェクト）、辞書の求め方、定数の値、型検査の出力の表と関数のシグネチャ、型検査の内部で作業を分けるためのインターフェース（推論の型と制約、パターンの検査）を定める。最後の節で、`Decimal` の算術を自作するときに守る規則を示す。

設計書の対応する章は[型検査器](../../design/02-impl/02-05-typechecker.md)であり、規則は[型システム](../../design/01-spec/01-06-type-system.md)、[エフェクト](../../design/01-spec/01-07-effects.md)、[代数的データ型とパターンマッチ](../../design/01-spec/01-05-data-types.md)、[基本型の意味論](../../design/01-spec/01-04-types-basic.md)で定める。脱糖（中間表現の章 10-06）は、本章の「型検査の出力」の表だけを読んで AST をコア IR に移す。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

- 置く作業: C02

本章のコードは C02 が置く。U2 第 1 段は型検査の出力を使わないので、C01 は本章を置かない。共有の章のうち本章の型を使うのは 10-06（`Ty`・`EffectSet`）であり、10-06 は C02 が置く。10-07 の C01 の部分は本章の型を使わない（定数の記述 `ConstDesc` は `ConstValue` を使わずに値を持つ。10-07「置く作業と既存のファイル」）。したがって、本章のファイルを C01 に移すものはない。

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/types/mod.rs` | 置く（`file=` と `sig=`） | F07（表示と置き換え） |
| `src/types/builtin.rs` | 加える（`file=`） | — |
| `src/typeck/mod.rs` | 置く（`file=` と `sig=`） | F07 |
| `src/typeck/infer.rs` | 置く（`file=`） | — |
| `src/typeck/patterns.rs` | 置く（`file=` と `sig=`） | F10 |

型検査の作業は、機能ごとに F07（レコード、型の別名、定数、`Byte`・`Decimal`）、F08（型クラス）、F09（エフェクトとハンドラ、`lazy`・`with`・`try`、可変状態）、F10（パターン）に分ける。制約の生成（`generate.rs`）と制約を解く部分（`solve.rs`）は、どの作業も触れる。本章は、作業の間で共有する型（`infer.rs` の推論の型と制約）と、脱糖が読む出力を凍結し、`generate.rs`・`solve.rs`・`decls.rs` とそれを分けた子のモジュールの中は作業の文書に任せる。「置く」のファイルは、C04 が最小実行版の同じパスのファイルを `src/legacy/` へ移して空けたパスに、新しく置く（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」）。最小実行版の `generate.rs`・`solve.rs`・`decls.rs`（`src/legacy/typeck/`）は、作業が写して広げてよい。

## 型パラメータの番号

型パラメータ `Ty::Param(i)` とエフェクト変数 `EffVar(i)` は、それを宣言した定義の中の番号で表す。定義ごとの番号の振り方を次に定める。名前解決の束縛（[モジュールと名前解決](10-04-modules-and-resolve.md)の `BindingKind::TypeParam { owner, index }`）から番号へは、この表で移す。

| 定義 | 型パラメータの番号 | エフェクト変数の番号 |
|---|---|---|
| トップレベルの関数、組み込みの関数、エフェクトの操作 | 宣言の型パラメータの並び（エフェクト変数を除く）の順 | 宣言のエフェクト変数の並びの順 |
| 型の宣言、レコード、型の別名、構成子、レコードの構築、フィールドを取り出す関数 | 型の宣言の型パラメータの順 | なし |
| 型クラスのメソッド（`Method` の束縛の宣言の型） | 0 番が型クラスの引数、1 番から後がメソッドの型パラメータの順 | メソッドのエフェクト変数の順 |
| 実装の頭部 | `implement` の直後の型パラメータの順 | なし |
| 実装の中の関数（`ImplFn` の束縛の宣言の型） | 0 番から k − 1 番が実装の型パラメータ（k 個）、k 番から後が関数自身の型パラメータの順 | 関数自身のエフェクト変数の順 |

関数の本体の中の式の型では、その本体を持つ定義の番号を使う。ラムダは型パラメータを持たないので、ラムダの本体の中も外側の定義の番号を使う。`handle` の節の中の操作の型パラメータは、ほかの何とも等しくない型（02-05「制約の生成」の `handle`）であり、`Ty::Rigid { clause, index }` で表す。`clause` は節のノード番号、`index` は操作の型パラメータの番号である。

型クラスの制約の番号（辞書の引数の順）も、定義ごとに `Scheme::class_constraints` の並びの順とする。型クラスのメソッドの宣言の型では、0 番の制約が「型クラスの引数は型クラスを実装している」であり、その後にメソッド自身の制約が続く。実装の中の関数の宣言の型では、実装の型パラメータの制約が先に、関数自身の制約が後に並ぶ。脱糖は、この順に辞書の引数を値の引数の前に置く（02-06「辞書の引数」）。ただし、次の二つは番号の読み方が違う。

- メソッドを使う箇所（`Cl.m(e1, …, en)`）: 型検査の「辞書の解決」の表（後述の `dicts`）の 0 番は、メソッドを呼ぶ辞書 V（`V.m[S̄; Ē](Ū, x̄)` の V）であり、1 番から後がメソッド自身の制約の辞書 Ū である。型の引数（`type_args`）の 0 番は型クラスの引数に与えた型、1 番から後が S̄ である。
- 実装の中の関数の本体: 実装の型パラメータの制約（k' 個。番号 0 から k' − 1）の辞書は、実装の定義の辞書の引数 d̄ であり、関数の辞書の引数ではない（02-06「辞書の引数」の `impl I[β̄](d̄ : …)`）。関数の辞書の引数は、番号 k' から後の関数自身の制約だけである。本体の中の `DictExpr::Param { constraint }` は、`constraint` が k' より小さければ d̄ の要素を、そうでなければ関数の辞書の引数を指す。

## 型の表現

型検査を終えた後の型（表に書く型、コア IR の型）を `Ty` で表す。推論に使う型変数を含まない（02-05「出力」）。型の別名は展開してあるので現れない。

型構成子 `TyCon` は、組み込みの型（組み込みの型の表の項目）と、ソースで宣言した代数的データ型とレコード（標準ライブラリのソースの `Option`・`Result`・`Pair`・`Triple`・`Ordering` などを含む）の二つである。組み込みの型は、ソースで同じ綴りの型を宣言しても区別できるように、綴りではなく表の番号で指す（ADR 0128）。ソースの型は宣言の束縛の番号で指す。

エフェクトの名前 `EffectName` は、組み込みのエフェクト（組み込みのエフェクトの表の項目）と、利用者が宣言したエフェクト（宣言の束縛の番号）の二つである。標準ライブラリのソースで宣言した `Console.Write` などは、宣言したモジュールの名前とエフェクトの名前で組み込みのエフェクトの表を引き、`Builtin` として表す。こうすると、`IO.All` を展開した集合（どの標準ライブラリのモジュールを読んだかによらない。02-05「型とエフェクトの表現」）と、ソースの宣言から得たエフェクトの名前が同じ値で比べられる。

型構成子を表す型パラメータの適用 `F[A]` は `Ty::App` で表す。多相な名前の型の引数（`TypeArgs`）では、型構成子を表す型パラメータに与える引数は型ではなく型構成子なので、`TypeArg::Head` で表す。

```rust file=src/types/mod.rs
//! 型とエフェクトの表現、宣言の情報、辞書の求め方、定数の値
//! （設計書 01-06、02-05「型とエフェクトの表現」「出力」、02-06「辞書の引数」）。
//! 型パラメータの番号の振り方は実装プラン 10-05「型パラメータの番号」に従う。

pub mod builtin;

use crate::base::{BindingId, BindingMap, Decimal, ModuleId, NodeId};
pub use crate::syntax::ast::BuiltinConstraint;
use builtin::{BuiltinEffectId, BuiltinTypeId};

/// 型構成子。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum TyCon {
    /// 組み込みの型（基本型、`List`・`Map`・`Set`・`Bytes`、中身を見せない型、リソースの型）
    Builtin(BuiltinTypeId),
    /// ソースで宣言した代数的データ型とレコード。宣言の束縛の番号で指す
    Adt(BindingId),
}

/// 値の型を書く位置の型構成子の頭（型構成子そのもの、または型構成子を表す型パラメータ）。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum TyHead {
    Con(TyCon),
    /// 型構成子を表す型パラメータの番号
    Param(u32),
}

/// エフェクトの名前（02-05「型とエフェクトの表現」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum EffectName {
    /// 組み込みのエフェクト（`State`、`Console.Write` など）
    Builtin(BuiltinEffectId),
    /// 利用者が宣言したエフェクト。宣言の束縛の番号で指す
    User(BindingId),
}

/// エフェクト変数。定義の中の番号（10-05「型パラメータの番号」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct EffVar(pub u32);

/// 確定したエフェクトの集合。`names` と `vars` は昇順で重複を持たない。`IO.All` は展開してある。
#[derive(Clone, PartialEq, Eq, Hash, Debug, Default)]
pub struct EffectSet {
    pub names: Vec<EffectName>,
    pub vars: Vec<EffVar>,
}

impl EffectSet {
    pub fn empty() -> EffectSet {
        EffectSet::default()
    }

    pub fn is_empty(&self) -> bool {
        self.names.is_empty() && self.vars.is_empty()
    }

    pub fn insert_name(&mut self, n: EffectName) {
        if let Err(pos) = self.names.binary_search(&n) {
            self.names.insert(pos, n);
        }
    }

    pub fn insert_var(&mut self, v: EffVar) {
        if let Err(pos) = self.vars.binary_search(&v) {
            self.vars.insert(pos, v);
        }
    }

    pub fn union(&self, other: &EffectSet) -> EffectSet {
        let mut out = self.clone();
        for n in &other.names {
            out.insert_name(*n);
        }
        for v in &other.vars {
            out.insert_var(*v);
        }
        out
    }

    /// self ⊆ other
    pub fn is_subset(&self, other: &EffectSet) -> bool {
        self.names.iter().all(|n| other.names.binary_search(n).is_ok())
            && self.vars.iter().all(|v| other.vars.binary_search(v).is_ok())
    }
}

/// 型検査を終えた後の型。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum Ty {
    Con(TyCon, Vec<Ty>),
    Fn(Box<FnTy>),
    /// 型パラメータ（値の型を表すもの）
    Param(u32),
    /// 型構成子を表す型パラメータの適用 `F[A]`（01-06「高カインド型（初回リリース版）」）
    App(u32, Vec<Ty>),
    /// `handle` の節の中の操作の型パラメータ。ほかの何とも等しくない（02-05「制約の生成」の `handle`）
    Rigid { clause: NodeId, index: u32 },
}

#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct FnTy {
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
}

/// 多相な名前の型パラメータに与える引数一つ。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum TypeArg {
    /// 値の型を表す型パラメータへの引数
    Ty(Ty),
    /// 型構成子を表す型パラメータへの引数（`Option`、または外側の定義の型構成子を表す型パラメータ）
    Head(TyHead),
}

/// 多相な名前を使う箇所の、型パラメータとエフェクト変数を置き換えたもの（01-12 の `[T̄; Ē]`）。
/// `tys` は型パラメータの番号の順、`effects` はエフェクト変数の番号の順。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct TypeArgs {
    pub tys: Vec<TypeArg>,
    pub effects: Vec<EffectSet>,
}

/// 型パラメータの形（01-06「高カインド型（初回リリース版）」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ParamKind {
    /// 値の型
    Value,
    /// 型引数を `arity` 個とる型構成子（初回リリース版では 1 だけを書ける）
    Ctor { arity: u32 },
}

/// 型パラメータの情報。
#[derive(Clone, PartialEq, Debug)]
pub struct TypeParamInfo {
    pub name: String,
    pub kind: ParamKind,
    /// 組み込みの制約（`equality`・`key`・`ordered`）。`key` は `equality` を含む。
    /// 二つ以上書いたときは強いほう（`key`）を持つ
    pub builtin: Option<BuiltinConstraint>,
}

/// 型クラスの制約一つ（`[T: Show]`）。辞書の引数一つに当たる。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ClassConstraint {
    /// 制約を付けた型パラメータの番号
    pub param: u32,
    /// 型クラスの束縛の番号
    pub class: BindingId,
}

/// 多相な名前の宣言の型（02-05「出力」の「宣言の型」）。
#[derive(Clone, PartialEq, Debug)]
pub struct Scheme {
    pub type_params: Vec<TypeParamInfo>,
    /// エフェクト変数の名前（番号の順）
    pub effect_params: Vec<String>,
    /// 型クラスの制約。並びの順が制約の番号であり、辞書の引数の順である（10-05「型パラメータの番号」）
    pub class_constraints: Vec<ClassConstraint>,
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
    /// `uses` に `IO.All` を書いたか（警告と診断のため。02-05「型とエフェクトの表現」）
    pub wrote_io_all: bool,
}

impl Scheme {
    /// 関数の型として見た型（型パラメータは置き換えない）。
    pub fn fn_ty(&self) -> Ty {
        Ty::Fn(Box::new(FnTy {
            params: self.params.clone(),
            ret: self.ret.clone(),
            effects: self.effects.clone(),
        }))
    }
}

/// 型が関数の型または中身を見せない型（鍵の要約では `Float`）を含むかの要約（01-06「等値の型」、ADR 0082）。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct TypeSummary {
    /// 型引数によらず含む
    pub always: bool,
    /// 含むかどうかが型引数に依存する型パラメータの番号（昇順）
    pub depends_on: Vec<u32>,
}

/// データ構成子の定義。
#[derive(Clone, PartialEq, Debug)]
pub struct CtorDef {
    pub name: String,
    /// 構成子の束縛の番号
    pub binding: BindingId,
    /// 型の宣言の中で 0 から数えた番号（宣言の順）。レコードの構成子は 0
    pub tag: u32,
    /// 引数の型。型の宣言の型パラメータを `Ty::Param` で表す。レコードではフィールドの型を宣言の順に並べる
    pub fields: Vec<Ty>,
}

/// レコードのフィールドの情報。
#[derive(Clone, PartialEq, Debug)]
pub struct FieldInfo {
    pub name: String,
    /// フィールド（フィールドを取り出す関数を兼ねる）の束縛の番号
    pub binding: BindingId,
}

/// 代数的データ型とレコードの定義。レコードは構成子が一つの代数的データ型として扱う（02-06「脱糖」）。
#[derive(Clone, PartialEq, Debug)]
pub struct AdtDef {
    /// 型の宣言（`data` か `record`）の束縛の番号
    pub binding: BindingId,
    pub name: String,
    pub module: ModuleId,
    pub type_params: Vec<String>,
    /// タグの順（宣言の順）。レコードでは一つ
    pub ctors: Vec<CtorDef>,
    /// レコードなら、フィールドを宣言の順に並べたもの。`data` なら `None`
    pub record: Option<Vec<FieldInfo>>,
    /// 等値の型の要約
    pub eq_summary: TypeSummary,
    /// 鍵の型の要約（`Float` だけを無条件に含むものとした要約。02-05「宣言の検査」）
    pub key_summary: TypeSummary,
}

/// 代数的データ型とレコードの表。すべてのモジュール（標準ライブラリのソースを含む）の型を持つ。
#[derive(Clone, Debug, Default)]
pub struct AdtTable {
    pub adts: BindingMap<AdtDef>,
}

/// 型クラスの定義。
#[derive(Clone, PartialEq, Debug)]
pub struct TraitDef {
    pub binding: BindingId,
    pub name: String,
    pub module: ModuleId,
    /// 型クラスの引数の形
    pub param_kind: ParamKind,
    /// 上位の型クラスの束縛の番号（宣言の順）。実装の辞書の上位の型クラスの辞書 Ū の順
    pub supers: Vec<BindingId>,
    /// メソッドの束縛の番号（宣言の順）。辞書のメソッドの並びの順
    pub methods: Vec<BindingId>,
}

/// 実装の定義。実装の宣言のノード番号で指す（02-04「束縛と表」）。
#[derive(Clone, PartialEq, Debug)]
pub struct ImplDef {
    pub decl: NodeId,
    pub module: ModuleId,
    /// 型クラスの束縛の番号
    pub class: BindingId,
    /// 対象。値の型を引数にとる型クラスでは `TypeArg::Ty`（`Option[T]` は型パラメータ 0 番を引数にした型）、
    /// 型構成子を引数にとる型クラスでは `TypeArg::Head`
    pub target: TypeArg,
    /// 対象の最も外側の型構成子（重なりの検査と、制約を解くときの実装の表の鍵）
    pub target_con: TyCon,
    pub type_params: Vec<TypeParamInfo>,
    /// 実装の型パラメータの制約。並びの順が実装の辞書の引数 d̄ の順
    pub class_constraints: Vec<ClassConstraint>,
    /// 実装の中の関数の束縛の番号を、型クラスのメソッドの宣言の順に並べたもの
    pub methods: Vec<BindingId>,
    /// 上位の型クラスの辞書の求め方を、`TraitDef::supers` の順に並べたもの（02-05「実装の検査」）
    pub supers: Vec<DictExpr>,
}

/// エフェクトの定義（ソースで宣言したもの。組み込みのエフェクトの宣言を含む）。
#[derive(Clone, PartialEq, Debug)]
pub struct EffectDef {
    /// エフェクトの宣言の束縛の番号
    pub binding: BindingId,
    pub name: EffectName,
    /// 操作の束縛の番号（宣言の順）
    pub ops: Vec<BindingId>,
}

/// 辞書の求め方（02-05「型クラスの制約の解決」）。
#[derive(Clone, PartialEq, Debug)]
pub enum DictExpr {
    /// 実装 I の辞書 `I[T̄](V̄)`。`type_args` は I の型パラメータに与える引数、
    /// `args` は I の型パラメータの制約ごとの辞書の求め方（`ImplDef::class_constraints` の順）
    Impl {
        impl_decl: NodeId,
        type_args: Vec<TypeArg>,
        args: Vec<DictExpr>,
    },
    /// いま検査している定義が受け取った辞書。`constraint` はその定義の制約の番号、
    /// `supers` はそこから辿る上位の型クラスの並び（辿らなければ空。`d↑Monoid↑Semigroup` の Monoid・Semigroup）
    Param { constraint: u32, supers: Vec<BindingId> },
}

/// 定数の値（02-05「定数の検査と評価」）。定数の評価器が求め、脱糖とコード生成が読む。
/// `Float` を含むので `PartialEq` を導出しない。
#[derive(Clone, Debug)]
pub enum ConstValue {
    Integer(i64),
    Float(f64),
    String(String),
    Character(char),
    Boolean(bool),
    Unit,
    Byte(u8),
    Decimal(Decimal),
    /// 構成子を適用した値（レコード、`Pair`・`Triple` を含む）。`adt` は型の宣言の束縛の番号
    Ctor {
        adt: BindingId,
        tag: u32,
        args: Vec<ConstValue>,
    },
    List(Vec<ConstValue>),
    /// 鍵の順に並べた組。同じ鍵は現れない
    Map(Vec<(ConstValue, ConstValue)>),
    /// 鍵の順に並べた要素。同じ要素は現れない
    Set(Vec<ConstValue>),
}

/// 演算子の型の集まり（01-06「演算子の型付け」）と、文字列補間の集まり。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TySet(pub &'static [BuiltinTypeId]);

impl TySet {
    /// `+`
    pub const ADD: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::STRING,
        BuiltinTypeId::DECIMAL,
    ]);
    /// `-`・`*`・単項の `-`
    pub const ARITH: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::DECIMAL,
    ]);
    /// `/`
    pub const DIV: TySet = TySet(&[BuiltinTypeId::FLOAT, BuiltinTypeId::DECIMAL]);
    /// `<`・`<=`・`>`・`>=` と、標準ライブラリの制約 `ordered`
    pub const ORD: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::STRING,
        BuiltinTypeId::CHARACTER,
        BuiltinTypeId::BYTE,
        BuiltinTypeId::DECIMAL,
    ]);
    /// 文字列補間の `${e}` の e（01-06「演算子の型付け」、ADR 0058）
    pub const INTERP: TySet = TySet(&[
        BuiltinTypeId::STRING,
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::CHARACTER,
        BuiltinTypeId::BOOLEAN,
        BuiltinTypeId::BYTE,
        BuiltinTypeId::DECIMAL,
    ]);

    pub fn contains(self, t: BuiltinTypeId) -> bool {
        self.0.contains(&t)
    }
}
```

`Ty` の置き換えと表示、表の引き方の中身は F07 が書く。

```rust sig=src/types/mod.rs
impl Ty {
    /// 型パラメータを `tys` で、エフェクト変数を `effs` で置き換える（`Ty::App(i, args)` の i が
    /// `TypeArg::Head(TyHead::Con(c))` に置き換わるときは `Ty::Con(c, args)` にする）。
    /// `tys`・`effs` にない番号はそのまま残す。`Ty::Rigid` は置き換えない。
    pub fn subst(&self, tys: &[TypeArg], effs: &[EffectSet]) -> Ty;
    /// 型を診断に示す形にする（`List[Integer]`、`function(Integer) -> Integer uses Console.Write`）。
    pub fn show(&self, names: &TyNames<'_>) -> String;
}

impl EffectSet {
    /// エフェクト変数を集合で置き換える（01-12「ε[E/ρ]」）。`effs` にない変数はそのまま残す。
    pub fn subst(&self, effs: &[EffectSet]) -> EffectSet;
}

/// 型を表示するための名前の表。
#[derive(Clone, Copy, Debug)]
pub struct TyNames<'a> {
    pub adts: &'a AdtTable,
    /// エフェクトの名前の表示に使う（利用者のエフェクトの名前）
    pub effects: &'a BindingMap<EffectDef>,
    /// 表示している文脈の型パラメータの名前（番号の順）
    pub type_params: &'a [String],
    /// 表示している文脈のエフェクト変数の名前（番号の順）
    pub effect_params: &'a [String],
}

impl AdtTable {
    pub fn get(&self, adt: BindingId) -> Option<&AdtDef>;
    /// 構成子の引数の型を、型引数 `args` で置き換えて返す。
    pub fn field_types(&self, adt: BindingId, tag: u32, args: &[Ty]) -> Option<Vec<Ty>>;
}
```

## 組み込みの型とエフェクトの表

組み込みの型の表は、ソースに宣言の構文がない型（基本型、`List`・`Map`・`Set`・`Bytes`、中身を見せない型、リソースの型）の、名前・属するモジュール・型引数の個数・種類を持つ（02-04「標準ライブラリのソースの持ち方」）。組み込みのエフェクトの表は、組み込みのエフェクトの名前・属するモジュール・`IO.All` に含むかを持つ（01-07「組み込みのエフェクト」、ADR 0130・0140）。どちらも初期化の後に変更しないので、`const` の表として持つ（ADR 0015）。

表の番号は、表の中の位置である。型検査と脱糖が名指しする項目（基本型、`List`・`Map`・`Set`・`Bytes`・`Lazy`・`Reference`・`TaskGroup`、`State`）は、`BuiltinTypeId` と `BuiltinEffectId` の定数で指す。U2（R29）と U3 がランタイムに結び付いた型とリソースの型を加えるときは、表の末尾に項目を加える。途中に挿入せず、既存の項目の位置を変えない。

モジュールの段 `module` は `Benitoite` を除いた名前である。空の並びは、prelude の名前として `Benitoite` の直下に置くこと（`Unit` と `State`）を表す。

```rust file=src/types/builtin.rs
//! 組み込みの型とエフェクトの表（設計書 02-04「標準ライブラリのソースの持ち方」、01-07「組み込みのエフェクト」、
//! ADR 0128・0130・0140・0157・0168）。
//! 初期化の後に変更しないので `const` の表にする（ADR 0015）。項目は末尾にだけ加える。

/// 組み込みの型の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinTypeId(pub u16);

/// 組み込みの型の種類。等値の型と鍵の型の判定（01-06）と、`with` のリソースの判定（01-10）に使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BuiltinTypeClass {
    /// 基本型（01-04）。`Float` は鍵の型でない
    Basic,
    /// `List`・`Map`・`Set`・`Bytes`。等値かどうかは要素の型で決まる（`Bytes` は常に等値）
    Collection,
    /// 中身を見せない型。等値の型でない
    Opaque,
    /// リソースの型。中身を見せない型であり、`with` で束縛できる
    Resource,
}

/// 組み込みの型の表の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinTypeDef {
    /// 属する標準ライブラリのモジュールの、`Benitoite` を除いた名前の段。空は `Benitoite` の直下
    pub module: &'static [&'static str],
    pub name: &'static str,
    /// 型引数の個数
    pub arity: u8,
    pub class: BuiltinTypeClass,
}

impl BuiltinTypeId {
    pub const INTEGER: BuiltinTypeId = BuiltinTypeId(0);
    pub const FLOAT: BuiltinTypeId = BuiltinTypeId(1);
    pub const STRING: BuiltinTypeId = BuiltinTypeId(2);
    pub const CHARACTER: BuiltinTypeId = BuiltinTypeId(3);
    pub const BOOLEAN: BuiltinTypeId = BuiltinTypeId(4);
    pub const UNIT: BuiltinTypeId = BuiltinTypeId(5);
    pub const BYTE: BuiltinTypeId = BuiltinTypeId(6);
    pub const DECIMAL: BuiltinTypeId = BuiltinTypeId(7);
    pub const LIST: BuiltinTypeId = BuiltinTypeId(8);
    pub const MAP: BuiltinTypeId = BuiltinTypeId(9);
    pub const SET: BuiltinTypeId = BuiltinTypeId(10);
    pub const BYTES: BuiltinTypeId = BuiltinTypeId(11);
    pub const REFERENCE: BuiltinTypeId = BuiltinTypeId(12);
    pub const LAZY: BuiltinTypeId = BuiltinTypeId(13);
    pub const TASK: BuiltinTypeId = BuiltinTypeId(14);
    pub const TASK_GROUP: BuiltinTypeId = BuiltinTypeId(15);
    pub const IO_ERROR: BuiltinTypeId = BuiltinTypeId(16);
    pub const NETWORK_ERROR: BuiltinTypeId = BuiltinTypeId(17);

    /// 表の項目。
    pub fn def(self) -> Option<&'static BuiltinTypeDef> {
        BUILTIN_TYPES.get(usize::from(self.0))
    }
}

/// 組み込みの型の表。位置が番号である。
pub const BUILTIN_TYPES: &[BuiltinTypeDef] = &[
    BuiltinTypeDef { module: &["Integer"], name: "Integer", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["Float"], name: "Float", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["String"], name: "String", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["Character"], name: "Character", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["Boolean"], name: "Boolean", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &[], name: "Unit", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["Byte"], name: "Byte", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["Decimal"], name: "Decimal", arity: 0, class: BuiltinTypeClass::Basic },
    BuiltinTypeDef { module: &["List"], name: "List", arity: 1, class: BuiltinTypeClass::Collection },
    BuiltinTypeDef { module: &["Map"], name: "Map", arity: 2, class: BuiltinTypeClass::Collection },
    BuiltinTypeDef { module: &["Set"], name: "Set", arity: 1, class: BuiltinTypeClass::Collection },
    BuiltinTypeDef { module: &["Bytes"], name: "Bytes", arity: 0, class: BuiltinTypeClass::Collection },
    BuiltinTypeDef { module: &["Reference"], name: "Reference", arity: 1, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["Lazy"], name: "Lazy", arity: 1, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["Task"], name: "Task", arity: 1, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["TaskGroup"], name: "TaskGroup", arity: 0, class: BuiltinTypeClass::Resource },
    BuiltinTypeDef { module: &["IOError"], name: "IOError", arity: 0, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["NetworkError"], name: "NetworkError", arity: 0, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["IO", "File"], name: "Reader", arity: 0, class: BuiltinTypeClass::Resource },
    BuiltinTypeDef { module: &["IO", "File"], name: "Writer", arity: 0, class: BuiltinTypeClass::Resource },
    BuiltinTypeDef { module: &["IO", "Random"], name: "Generator", arity: 0, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["Regex"], name: "Pattern", arity: 0, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["Regex"], name: "Match", arity: 0, class: BuiltinTypeClass::Opaque },
    BuiltinTypeDef { module: &["Network", "Http"], name: "Listener", arity: 0, class: BuiltinTypeClass::Resource },
    BuiltinTypeDef { module: &["Network", "Http"], name: "Exchange", arity: 0, class: BuiltinTypeClass::Resource },
];

/// 組み込みのエフェクトの表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinEffectId(pub u16);

/// 組み込みのエフェクトの表の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinEffectDef {
    /// 宣言したモジュールの、`Benitoite` を除いた名前の段。空は `Benitoite` の直下（`State`）
    pub module: &'static [&'static str],
    pub name: &'static str,
    /// `IO.All` に含むか（01-07「組み込みのエフェクト」）
    pub in_io_all: bool,
    /// ソースに宣言があるか。`false` の項目（`State`・`IO.All`）は名前解決が表から束縛を作る
    pub declared_in_source: bool,
}

impl BuiltinEffectId {
    pub const STATE: BuiltinEffectId = BuiltinEffectId(0);
    /// `IO.All`。型検査が宣言の型と型注釈を内部の型に移すときに、`in_io_all` の項目の集合に置き換える。
    /// `EffectSet` には現れない
    pub const IO_ALL: BuiltinEffectId = BuiltinEffectId(1);

    /// 表の項目。
    pub fn def(self) -> Option<&'static BuiltinEffectDef> {
        BUILTIN_EFFECTS.get(usize::from(self.0))
    }
}

/// 組み込みのエフェクトの表。位置が番号である。
pub const BUILTIN_EFFECTS: &[BuiltinEffectDef] = &[
    BuiltinEffectDef { module: &[], name: "State", in_io_all: true, declared_in_source: false },
    BuiltinEffectDef { module: &["IO"], name: "All", in_io_all: false, declared_in_source: false },
    BuiltinEffectDef { module: &["IO", "Console"], name: "Write", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "Console"], name: "Read", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "File"], name: "Read", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "File"], name: "Write", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "Process"], name: "Run", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "Process"], name: "Exit", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "Process"], name: "Environment", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "Clock"], name: "Time", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["IO", "Random"], name: "Generate", in_io_all: true, declared_in_source: true },
    BuiltinEffectDef { module: &["Network", "Http"], name: "Listen", in_io_all: false, declared_in_source: true },
    BuiltinEffectDef { module: &["Network", "Http"], name: "Connect", in_io_all: false, declared_in_source: true },
    BuiltinEffectDef { module: &["Assert"], name: "Check", in_io_all: false, declared_in_source: true },
];

/// モジュールの名前の段（`Benitoite` を除く）と名前から、組み込みの型を引く。
pub fn find_builtin_type(module: &[&str], name: &str) -> Option<BuiltinTypeId> {
    let index = BUILTIN_TYPES
        .iter()
        .position(|d| d.module == module && d.name == name)?;
    u16::try_from(index).ok().map(BuiltinTypeId)
}

/// モジュールの名前の段（`Benitoite` を除く）と名前から、組み込みのエフェクトを引く。
/// 標準ライブラリのソースで宣言したエフェクトを `EffectName::Builtin` にするときに使う。
pub fn find_builtin_effect(module: &[&str], name: &str) -> Option<BuiltinEffectId> {
    let index = BUILTIN_EFFECTS
        .iter()
        .position(|d| d.module == module && d.name == name)?;
    u16::try_from(index).ok().map(BuiltinEffectId)
}
```

表の項目のうち、`File.Reader`・`File.Writer`・`Random.Generator`・`Regex.Pattern`・`Regex.Match`・`Http.Listener`・`Http.Exchange` と、ネットワークのエフェクトは U3 の、`Assert.Check` は U3・U4（テストの実行器）の標準ライブラリのモジュールに属する。U1 の時点では、これらのモジュールのソースがないので束縛は作られないが、`IO.All` の展開（どのモジュールを読んだかによらない）と、表の番号を後から変えないために、いま表に置く。

## 型検査の出力

02-05「出力」の表に、宣言の情報（代数的データ型、型クラス、実装、エフェクト）と `main` の情報を加える。表の鍵と値を次に示す。脱糖は、名前を使う箇所のノード番号から名前解決の参照の表で束縛の番号を得て、`decl_types` などを引く。

| 欄 | 鍵 | 値 |
|---|---|---|
| `expr_types` | 式、パターン、束縛の文（束縛した値の型。型注釈があればその型）、引数（`Param`）、プレースホルダ（展開したラムダのその引数の型）、展開の要素（`SpreadElem`。`List[T]`）、`with` の束縛、`handle` の節の引数、リストのパターンの残り（`ListRest`。`List[T]`）、ブロック | 型 |
| `type_args` | 多相な名前を使う箇所: `NameExpr`（関数、組み込みの関数、構成子、操作、メソッド、フィールドを取り出す関数）、`CtorPat`、`RecordExpr`、`RecordPat`、`OpRef` | 置き換え（`TypeArgs`） |
| `operand_types` | `BinaryExpr`・`UnaryExpr` | オペランドの型 |
| `interp_types` | 文字列補間の各 `${e}` の e（`InterpSegment::expr`）のノード番号 | e の型 |
| `lambda_effects` | `LambdaExpr`、プレースホルダを含む `CallExpr` | ラムダの型のエフェクト |
| `dicts` | 型クラスの制約を持つ名前を使う箇所（`NameExpr`） | 使った名前の宣言の型の制約ごとの辞書の求め方（制約の番号の順） |
| `try_kinds` | `TryExpr` | `Result` か `Option` かと、最も内側の関数かラムダの戻り値の型 |
| `handlers` | `HandleExpr` | 節ごとの操作と末尾で再開するか、handled(H) |
| `lit_values` | 数値・文字・文字列・真偽値のリテラルの `LitExpr`、単項の `-` を整数・浮動小数・`Decimal` のリテラルに直接適用した `UnaryExpr`、`LitPat` | 範囲を検査した値 |
| `range_bounds` | `RangePat` | 下端と上端の値 |
| `decl_types` | 関数、組み込みの関数、実装の中の関数、構成子、定数、操作、メソッド、レコード（構築の型）、フィールド（取り出す関数の型）の束縛 | 宣言の型 |
| `consts` | 定数の束縛 | 定数の値 |
| `adts`・`traits`・`impls`・`effects` | 型・レコード・型クラスの束縛、実装の宣言のノード番号、エフェクトの束縛 | 宣言の情報 |

- レコードの束縛の宣言の型は、フィールドの型を宣言の順に引数とし、`R[T̄]` を戻り値の型とする関数の型である。フィールドの束縛の宣言の型は `function(R[T̄]) -> フィールドの型` である。構成子の宣言の型は、型の宣言の型パラメータを型パラメータとし、引数の型を引数、`D[T̄]` を戻り値の型、空集合をエフェクトとする。
- 定数の宣言の型は、型パラメータを持たない `Scheme` で、`params` を空、`ret` を定数の型とする。
- 構成子と定数を使う箇所にも `type_args` を載せる（定数では空）。脱糖は、`NameExpr` が指す束縛の種類で、値 `C[T̄]`・`f[T̄; Ē]`・`k` を選ぶ。
- 表に書く型には型変数を残さない。決まらなかった型変数の置き換えは 02-05「出力」のとおりである（値の型は `Unit`、型構成子は `Option`、エフェクトは空集合）。

```rust file=src/typeck/mod.rs
//! 型検査（設計書 02-05）。
//! infer.rs: 推論の型と制約、patterns.rs: パターンの検査。
//! 制約の生成、制約の解決、宣言の検査、定数の評価の子のモジュールは F07〜F10 の作業の文書で分ける。

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
    /// 末尾で再開する節か（02-05「書く位置の検査」、ADR 0151）
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
```

型検査の関数の中身は F07 が書き、F08〜F10 が広げる。

```rust sig=src/typeck/mod.rs needs=10-02
use crate::diag::Diagnostic;
use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Module;

/// プログラム全体の型を検査する（02-05「検査の単位と手順」の手順 1〜5）。`asts` の添字はモジュールの ID の値。
/// `require_main` は `check` と `run` の経路で真、`test` の経路で偽（02-05「宣言の検査」の `main`）。
/// 誤りと警告を診断として返す。誤りがあっても出力を返す。
/// 呼び出し側は、診断に誤りが一つでもあれば出力を使わない（ADR 0019）。
pub fn typecheck(modules: &ModuleTable, asts: &[Module], resolved: &ResolveOutput, require_main: bool) -> (TypeckOutput, Vec<Diagnostic>);
```

## 推論の型と制約（F07〜F10 の境界）

推論の中の型 `ITy` は、`Ty` に型変数と誤りの型を加えたものである（02-05「型とエフェクトの表現」）。型変数には、値の型の変数と、型構成子の変数がある。エフェクト `IEffect` は、確定した要素の集合と、まだ決まっていないエフェクトの変数（高々一つ）の組である。制約の種類は 02-05「制約の種類」の表と一対一に対応する。

F07〜F10 は、機能ごとに制約の生成と解き方を加える。制約の種類と理由の種類を本節で凍結し、作業ごとに新しい種類を加えないで済むようにする。理由の種類が足りないときは、作業を止めて報告する（[作業の進め方](../00-common/00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。

```rust file=src/typeck/infer.rs
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
    Rigid { clause: NodeId, index: u32 },
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
    CallArg { index: u32 },
    /// 呼び出される式が関数の型であること
    Call,
    IfCondition,
    IfBranches,
    IfNoElse,
    MatchArms,
    MatchGuard,
    Pattern,
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
    Operands { op: OpName },
    /// `and`・`or`・`not` のオペランドが `Boolean` であること
    Logic { op: OpName },
    /// 演算子の集まりの制約と等値の制約
    Operator { op: OpName },
    /// 文字列補間の集まりの制約
    Interp,
    /// 呼び出しのエフェクトが本体のエフェクトに含まれること
    CallEffect,
    /// 標準ライブラリの関数の型パラメータの組み込みの制約（`equality`・`key`・`ordered`）。
    /// `name` は修飾した名前
    BuiltinParam { name: String },
    /// 型パラメータの組み込みの制約を持つ利用者の関数の呼び出し
    ParamBound { name: String },
    /// レコードの構築と更新のフィールドの式
    RecordField { field: BindingId },
    /// レコードの更新の元の式
    RecordBase,
    /// 型クラスの制約（メソッドか制約を持つ関数を使った）
    ClassUse { class: BindingId },
    /// 実装の上位の型クラスの制約
    ImplSuper { class: BindingId },
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
    Equal { expected: ITy, found: ITy, reason: Reason },
    /// 流れ込む(A, B)。値の型 `from` を、型 `to` が求められる位置に使う
    Flow { from: ITy, to: ITy, reason: Reason },
    /// 集まり(A, S)
    OneOf { ty: ITy, set: TySet, reason: Reason },
    /// 等値(A)
    Equality { ty: ITy, reason: Reason },
    /// 鍵(A)
    Key { ty: ITy, reason: Reason },
    /// 型クラス(C, τ)。解いた辞書の求め方を `site` に記録する
    Class { class: BindingId, arg: IClassArg, site: DictSite, reason: Reason },
    /// 試行(A, R, τ)。`target` が `try` の対象の型、`ret` が最も内側の関数かラムダの戻り値の型、
    /// `result` が `try` の式の型。判定の結果を `node`（`TryExpr`）の「`try` の種類」に記録する
    Try { target: ITy, ret: ITy, result: ITy, node: NodeId, reason: Reason },
    /// リソース(A)
    Resource { ty: ITy, reason: Reason },
    /// 含まれる(X, Y)
    EffSub { sub: IEffect, sup: IEffect, reason: Reason },
}
```

制約を解く部分（`Solver`）の形は、最小実行版の `typeck/solve.rs` の関数（`fresh_ty`・`solve`・`zonk`・`finalize` など）を引き継ぎ、F07 が上の型に合わせて改める。型構成子の変数、鍵・型クラス・試行・リソースの制約、エフェクトの最小の解（02-05「制約の解決」）を解く関数は、F08・F09 が同じファイルに加える。F07〜F10 は同じファイルに触れるので、並行して進めるときは、機能ごとの子のモジュール（型クラスの解決、ハンドラ、定数の評価など）に分け、`solve.rs` と `generate.rs` の共通の部分の変更を一つの作業に寄せる（作業の文書で定める）。

## パターンの検査（F10 の境界）

パターンの検査は、型検査を終えた型（`Ty`）と、構成子をタグで表したパターン（`Pat`）の上で行う（02-05「本体の後の検査」）。制約の生成の側が、AST のパターンを `Pat` に移す。移し方は次のとおりである。

- 変数のパターンと、リストのパターンの `..rest` の変数は `Wild` にする。
- レコードのパターンは、フィールドを宣言の順に並べた構成子のパターン（タグ 0）にし、書かないフィールドは `Wild` にする。
- `-n` の形のリテラルは負の値にする。範囲の両端は、型検査が範囲を検査した値にする。
- 対象の型が誤りの型を含む `match` と束縛の文は渡さない（02-05「誤りの報告と検査の継続」）。

```rust file=src/typeck/patterns.rs
//! パターンの検査: 網羅性、選ばれない分岐、必ず照合するパターン（設計書 02-05「本体の後の検査」、01-05）。

use crate::base::BindingId;

/// 検査に使うパターン。
#[derive(Clone, PartialEq, Debug)]
pub enum Pat {
    /// ワイルドカードと変数のパターン（どちらもすべての値に照合する）
    Wild,
    /// 構成子のパターン（レコードを含む）。`adt` は型の宣言の束縛の番号
    Ctor { adt: BindingId, tag: u32, args: Vec<Pat> },
    Integer(i64),
    Character(char),
    String(String),
    Boolean(bool),
    Unit,
    /// 範囲のパターン（両端を含む）
    IntegerRange(i64, i64),
    CharacterRange(char, char),
    /// リストのパターン。`rest` は `..` を書いたか
    List { before: Vec<Pat>, rest: bool, after: Vec<Pat> },
}

/// `match` の分岐一つ。
#[derive(Clone, PartialEq, Debug)]
pub struct ArmPats {
    /// コンマで並べた選択肢
    pub alts: Vec<Pat>,
    /// ガードを持つか。ガードの付いた分岐の行は、後の行を覆うものに数えない（02-05「本体の後の検査」）
    pub guarded: bool,
}

/// 検査の結果。
#[derive(Clone, PartialEq, Debug)]
pub enum MatchIssue {
    /// 網羅していない。`witness` はどの分岐にも照合しない値の形（`Tree.Node(Tree.Leaf, _, _)` など）
    NonExhaustive { witness: String },
    /// `arm` 番目の分岐の `alt` 番目の選択肢（どちらも 0 から数える）は選ばれない。
    /// `covered_by` は覆っている前の分岐の番号（昇順。02-05「本体の後の検査」の選び方）
    Unreachable { arm: usize, alt: usize, covered_by: Vec<usize> },
}
```

```rust sig=src/typeck/patterns.rs
use crate::types::{AdtTable, Ty};

/// 一つの `match` を検査する。選ばれない選択肢を分岐と選択肢の順に、その後に網羅していないこと（あれば一つ）を返す。
/// 構成子の名前の表示は、型名で修飾した名前（`Tree.Leaf`、`Option.Some`）とし、型の名前と同じ名前の
/// 構成子（`Pair`）とレコードは修飾しない。
pub fn check_match(scrutinee: &Ty, arms: &[ArmPats], adts: &AdtTable) -> Vec<MatchIssue>;

/// 束縛の文の左辺のパターンが必ず照合するか（01-05「必ず照合するパターン（初回リリース版）」）。
pub fn is_irrefutable(ty: &Ty, pat: &Pat, adts: &AdtTable) -> bool;
```

## `Decimal` の算術

`Decimal` の算術は、既存のクレートを使わずに自作する（[ADR 0275](../../design/decisions/0275-self-made-decimal-arithmetic.md)）。表現は[基本の型](10-01-base.md)の `base::decimal::Decimal`（`i128` の仮数と `u8` の桁数）であり、算術は `base::decimal` の関数の中に閉じる。作業 F07 が、01-04「Decimal（初回リリース版）」の次の規則どおりに書く。

1. 値の範囲: −2^96 < m < 2^96、0 ≤ e ≤ 28。範囲の外を作らない。
2. 小数の桁数を保つ: `1.0m` と `1.00m` を別の表現として保ち、比較では等しくする。和と差は大きいほうの桁数、積は桁数の和。
3. 丸め: 結果が表せないときは、最大の桁数まで減らして最近接偶数丸め。0 桁でも表せなければ失敗。
4. 除算の桁数: 正確に表せるときは、`max(ea − eb, 0)` 以上で最小の桁数。表せないときは最大の桁数で最近接偶数丸め。
5. 溢れと 0 による除算は、panic せずに失敗として返す。

積の中間値は 192 bit になるので、`u128` 二つによる多倍長の掛け算と割り算を書く。テストには、01-04 の表の例（`1.00m / 4m` は `0.25m`、`6m / 2.0m` は `3m`、`1m / 3m` は小数 28 桁）と、溢れの境界を含める。

候補として調べたクレート（`rust_decimal` 1.43.0、`bigdecimal` 0.4.11、`fastnum` 0.7.5、`decimal-rs` 0.2.0。2026-09-30 に crates.io で版とライセンスを確かめた）は、ADR 0275 の検討した代替案の材料である。
