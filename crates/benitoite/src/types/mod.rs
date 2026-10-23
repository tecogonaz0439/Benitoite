//! 型とエフェクトの表現、宣言の情報、辞書の求め方、定数の値
//! （設計書 01-06、02-05「型とエフェクトの表現」「出力」、02-06「辞書の引数」）。
//! 型パラメータとエフェクト変数の番号は、定義ごとにそれぞれの宣言の順で振る。
//! 型クラスのメソッドは 0 番が型クラスの引数で、1 番からメソッド自身の型パラメータを並べる。
//! 実装の中の関数は実装の型パラメータを先に、関数自身の型パラメータを後に並べる。
//! ラムダの本体も外側の定義の番号を使い、操作の節の型パラメータは `Ty::Rigid` で区別する。
//! 型クラスの制約の番号も、定義ごとに宣言の順で振る。メソッドは 0 番が自己のクラスである。
//! 実装の中の関数は実装の制約を先に、関数自身の制約を後に並べる。

pub mod builtin;

mod text {
    pub const EXCLUDES_FAILURE: &str = "excludes Failure.Fail";
}

use crate::base::{BindingId, BindingMap, Decimal, ModuleId, NodeId, Span};
pub use crate::syntax::ast::BuiltinConstraint;
use builtin::{BuiltinEffectId, BuiltinTypeId};

/// 型構成子。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum TyCon {
    /// 組み込みの型（基本型、`List`・`Map`・`Set`・`Bytes`、不透明型、リソースの型）
    Builtin(BuiltinTypeId),
    /// ソースで宣言した代数的データ型とレコード。宣言の束縛の番号で指す
    Adt(BindingId),
    /// コンポーネントの resource に対応する、中身を見せない外部の型
    External(BindingId),
}

/// 値の型を書く位置の型構成子の頭（型構成子そのもの、または型構成子を表す型パラメータ）。
#[derive(Clone, PartialEq, Eq, Hash, Debug, PartialOrd, Ord)]
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

/// エフェクト変数。定義の中の番号（`types` のモジュールの説明）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct EffVar(pub u32);

/// 確定したエフェクトの集合。`names` と `vars` は昇順で重複を持たない。`IO.All` は展開してある。
#[derive(Clone, PartialEq, Eq, Hash, Debug, Default, PartialOrd, Ord)]
pub struct EffectSet {
    /// 型付きの失敗。型の固定順序で整列し、重複を持たない。
    pub failures: Vec<Ty>,
    pub names: Vec<EffectName>,
    pub vars: Vec<EffVar>,
}

/// 一つの元宣言が加えた効果と、そのソース上の位置（設計書 02-05「出力」）。
#[derive(Clone, Debug)]
pub struct EffectOrigin {
    /// IO.All は展開済み、Fail の別名は展開済みである。
    pub effects: EffectSet,
    /// 診断で使う元の修飾名。
    pub name: String,
    pub span: Span,
    /// ファイル単位の宣言なら真。共通宣言を一関数の編集範囲に使わない。
    pub file: bool,
}

/// 関数の最外側の有効な効果行と個別・ファイルの追加元。
#[derive(Clone, Debug, Default)]
pub struct EffectiveEffects {
    pub effects: EffectSet,
    /// 同じ効果を両リストに書いた場合も、それぞれの元位置を残す。
    pub origins: Vec<EffectOrigin>,
    pub wrote_io_all: bool,
}

impl EffectSet {
    pub fn empty() -> EffectSet {
        EffectSet::default()
    }

    pub fn is_empty(&self) -> bool {
        self.names.is_empty() && self.vars.is_empty() && self.failures.is_empty()
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

    /// 正規化した失敗型を集合へ挿入する。
    pub fn insert_failure(&mut self, ty: Ty) {
        if let Err(pos) = self.failures.binary_search(&ty) {
            self.failures.insert(pos, ty);
        }
    }

    pub fn union(&self, other: &EffectSet) -> EffectSet {
        let mut out = self.clone();
        for ty in &other.failures {
            out.insert_failure(ty.clone());
        }
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
        self.failures.iter().all(|ty| other.failures.contains(ty))
            && self
                .names
                .iter()
                .all(|n| other.names.binary_search(n).is_ok())
            && self
                .vars
                .iter()
                .all(|v| other.vars.binary_search(v).is_ok())
    }
}

/// 型検査を終えた後の型。
#[derive(Clone, PartialEq, Eq, Hash, Debug, PartialOrd, Ord)]
pub enum Ty {
    Con(TyCon, Vec<Ty>),
    Fn(Box<FnTy>),
    /// 型パラメータ（値の型を表すもの）
    Param(u32),
    /// 型構成子を表す型パラメータの適用 `F[A]`（01-06「高カインド型（初回リリース版）」）
    App(u32, Vec<Ty>),
    /// `handle` の節の中の操作の型パラメータ。ほかの何とも等しくない（02-05「制約の生成」の `handle`）
    Rigid {
        clause: NodeId,
        index: u32,
    },
}

#[derive(Clone, PartialEq, Eq, Hash, Debug, PartialOrd, Ord)]
pub struct FnTy {
    /// params と同じ長さで、一意な契約名を宣言順に並べる。
    pub param_names: Vec<String>,
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
}

impl FnTy {
    pub(crate) fn valid_contract(&self) -> bool {
        self.param_names.len() == self.params.len()
            && self
                .param_names
                .iter()
                .collect::<std::collections::BTreeSet<_>>()
                .len()
                == self.param_names.len()
    }
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
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum ParamKind {
    /// 値の型
    Value,
    /// 型引数を `arity` 個とる型構成子（初回リリース版では 1 だけを書ける）
    Ctor { arity: u32 },
}

/// 型パラメータの情報。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct TypeParamInfo {
    pub name: String,
    pub kind: ParamKind,
    /// 組み込みの制約（`equality`・`key`・`ordered`）。`key` は `equality` を含む。
    /// 二つ以上書いたときは強いほう（`key`）を持つ
    pub builtin: Option<BuiltinConstraint>,
}

/// 型クラスの制約一つ（`[T: Show]`）。辞書の引数一つに当たる。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct ClassConstraint {
    /// 制約を付けた型パラメータの番号
    pub param: u32,
    /// 型クラスの束縛の番号
    pub class: BindingId,
}

/// 多相な名前の宣言の型（02-05「出力」の「宣言の型」）。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct Scheme {
    /// params と同じ長さで、一意な契約名を宣言順に並べる。
    pub param_names: Vec<String>,
    pub type_params: Vec<TypeParamInfo>,
    /// エフェクト変数の名前（番号の順）
    pub effect_params: Vec<String>,
    /// シグネチャの同じ uses で Fail と並ぶ行。
    pub no_fail: Vec<EffVar>,
    /// 型クラスの制約。並びの順が制約の番号であり、辞書の引数の順である（設計書 02-06「辞書の引数」）
    pub class_constraints: Vec<ClassConstraint>,
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
    /// `uses` に `IO.All` を書いたか（警告と診断のため。02-05「型とエフェクトの表現」）
    pub wrote_io_all: bool,
}

impl Scheme {
    /// シグネチャ全体から行の条件を集める。
    pub fn signature_no_fail(&self) -> Vec<EffVar> {
        let mut out = std::collections::BTreeSet::new();
        if !self.effects.failures.is_empty() {
            out.extend(self.effects.vars.iter().copied());
        }
        let mut pending = self
            .params
            .iter()
            .chain(std::iter::once(&self.ret))
            .chain(&self.effects.failures)
            .collect::<Vec<_>>();
        while let Some(t) = pending.pop() {
            match t {
                Ty::Fn(f) => {
                    if !f.effects.failures.is_empty() {
                        out.extend(f.effects.vars.iter().copied());
                    }
                    pending.extend(&f.params);
                    pending.push(&f.ret);
                    pending.extend(&f.effects.failures);
                }
                Ty::Con(_, ts) | Ty::App(_, ts) => pending.extend(ts),
                Ty::Param(_) | Ty::Rigid { .. } => {}
            }
        }
        out.into_iter().collect()
    }
    /// 関数の型として見た型（型パラメータは置き換えない）。
    pub fn fn_ty(&self) -> Ty {
        Ty::Fn(Box::new(FnTy {
            param_names: self.param_names.clone(),
            params: self.params.clone(),
            ret: self.ret.clone(),
            effects: self.effects.clone(),
        }))
    }
}

/// 型が関数の型または等値を持たない組み込みの不透明型（鍵の要約では `Float`・`Float32`）を含むかの要約（01-06「等値の型」）。
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
    /// パッケージ外のソース照合で将来の形を考慮する指定。宣言の `@extensible` を反映する。
    pub extensible: bool,
    pub type_params: Vec<String>,
    /// タグの順（宣言の順）。レコードでは一つ
    pub ctors: Vec<CtorDef>,
    /// レコードなら、フィールドを宣言の順に並べたもの。`data` なら `None`
    pub record: Option<Vec<FieldInfo>>,
    /// 等値の型の要約
    pub eq_summary: TypeSummary,
    /// 鍵の型の要約（`Float`・`Float32` を無条件に含むものとした要約。02-05「宣言の検査」）
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

/// エフェクトの定義。ソースの宣言と、標準専用の Fail の宣言を含む。
#[derive(Clone, PartialEq, Debug)]
pub struct EffectDef {
    /// エフェクトの宣言の束縛の番号
    pub binding: BindingId,
    pub name: EffectName,
    /// 診断に示す名前（宣言に書いた名前。`Log`）。`Ty::show` が利用者のエフェクトを示すのに使う
    pub display_name: String,
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
    /// 操作の節が受け取った辞書。節の所属を外側の定義の制約番号と区別する。
    Clause {
        clause: NodeId,
        constraint: u32,
        supers: Vec<BindingId>,
    },
    /// いま検査している定義が受け取った辞書。`constraint` はその定義の制約の番号、
    /// `supers` はそこから辿る上位の型クラスの並び（辿らなければ空。`d↑Monoid↑Semigroup` の Monoid・Semigroup）
    Param {
        constraint: u32,
        supers: Vec<BindingId>,
    },
}

/// 定数の値（02-05「定数の検査と評価」）。定数の評価器が求め、脱糖とコード生成が読む。
/// `Float`・`Float32` を含むので `PartialEq` を導出しない。
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
    Integer8(i8),
    Integer16(i16),
    Integer32(i32),
    UnsignedInteger16(u16),
    UnsignedInteger32(u32),
    UnsignedInteger64(u64),
    Float32(f32),
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
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
        BuiltinTypeId::FLOAT32,
    ]);
    /// 二項の `-`・`*`
    pub const ARITH: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::DECIMAL,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
        BuiltinTypeId::FLOAT32,
    ]);
    /// 単項の `-`。符号なし整数と Byte は含まない。
    pub const NEG: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::DECIMAL,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::FLOAT32,
    ]);
    /// `div`・`mod`。Byte は含まない。
    pub const INT_DIV: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
    ]);
    /// `/`
    pub const DIV: TySet = TySet(&[
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::DECIMAL,
        BuiltinTypeId::FLOAT32,
    ]);
    /// `<`・`<=`・`>`・`>=` と、標準ライブラリの制約 `ordered`
    pub const ORD: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::STRING,
        BuiltinTypeId::CHARACTER,
        BuiltinTypeId::BYTE,
        BuiltinTypeId::DECIMAL,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
        BuiltinTypeId::FLOAT32,
    ]);
    /// 文字列補間の `${e}` の e（01-06「演算子の型付け」）
    pub const INTERP: TySet = TySet(&[
        BuiltinTypeId::STRING,
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::CHARACTER,
        BuiltinTypeId::BOOLEAN,
        BuiltinTypeId::BYTE,
        BuiltinTypeId::DECIMAL,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
        BuiltinTypeId::FLOAT32,
    ]);

    /// 整数の書式 d/b/o/x/X。算術と異なり Byte も受理する。
    pub const FORMAT_INT: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::BYTE,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
    ]);
    /// f の三型。精度の省略でも集合は変わらない。
    pub const FORMAT_FIXED: TySet = Self::DIV;
    /// 種類省略で符号かゼロ埋めを指定した場合の数の集合。
    pub const FORMAT_NUMBER: TySet = TySet(&[
        BuiltinTypeId::INTEGER,
        BuiltinTypeId::INTEGER8,
        BuiltinTypeId::INTEGER16,
        BuiltinTypeId::INTEGER32,
        BuiltinTypeId::BYTE,
        BuiltinTypeId::UNSIGNED_INTEGER16,
        BuiltinTypeId::UNSIGNED_INTEGER32,
        BuiltinTypeId::UNSIGNED_INTEGER64,
        BuiltinTypeId::FLOAT,
        BuiltinTypeId::FLOAT32,
        BuiltinTypeId::DECIMAL,
    ]);

    pub fn contains(self, t: BuiltinTypeId) -> bool {
        self.0.contains(&t)
    }
}

impl Ty {
    /// 型パラメータを `tys` で、エフェクト変数を `effs` で置き換える（`Ty::App(i, args)` の i が
    /// `TypeArg::Head(TyHead::Con(c))` に置き換わるときは `Ty::Con(c, args)` にする）。
    /// `tys`・`effs` にない番号はそのまま残す。`Ty::Rigid` は置き換えない。
    pub fn subst(&self, tys: &[TypeArg], effs: &[EffectSet]) -> Ty {
        let arg = |i: u32| usize::try_from(i).ok().and_then(|i| tys.get(i));
        match self {
            Ty::Con(con, args) => Ty::Con(*con, args.iter().map(|t| t.subst(tys, effs)).collect()),
            Ty::Fn(f) => Ty::Fn(Box::new(FnTy {
                param_names: f.param_names.clone(),
                params: f.params.iter().map(|t| t.subst(tys, effs)).collect(),
                ret: f.ret.subst(tys, effs),
                effects: f.effects.subst_types(tys, effs),
            })),
            // 同時置換なので、置換先に含まれるパラメータを再び置き換えない（設計書 01-12「型付け規則」）。
            Ty::Param(i) => match arg(*i) {
                Some(TypeArg::Ty(t)) => t.clone(),
                Some(TypeArg::Head(_)) | None => self.clone(),
            },
            Ty::App(i, args) => {
                let args = args.iter().map(|t| t.subst(tys, effs)).collect();
                match arg(*i) {
                    Some(TypeArg::Head(TyHead::Con(con))) => Ty::Con(*con, args),
                    Some(TypeArg::Head(TyHead::Param(j))) => Ty::App(*j, args),
                    Some(TypeArg::Ty(_)) | None => Ty::App(*i, args),
                }
            }
            Ty::Rigid { .. } => self.clone(),
        }
    }
    /// 表層の具体化後にだけ課す単一 Fail の検査。内部の上限には用いない。
    pub fn single_failure(&self) -> bool {
        let mut pending = vec![self];
        while let Some(t) = pending.pop() {
            match t {
                Ty::Fn(f) => {
                    if f.effects.failures.len() > 1 {
                        return false;
                    }
                    pending.extend(&f.params);
                    pending.push(&f.ret);
                    pending.extend(&f.effects.failures);
                }
                Ty::Con(_, ts) | Ty::App(_, ts) => pending.extend(ts),
                Ty::Param(_) | Ty::Rigid { .. } => {}
            }
        }
        true
    }
    /// Fail と同じ位置に残る行は宣言由来の NoFail を持たなければならない。
    pub fn failure_rows_valid(&self, no_fail: &[EffVar]) -> bool {
        let mut pending = vec![self];
        while let Some(t) = pending.pop() {
            match t {
                Ty::Fn(f) => {
                    if !f.effects.failures.is_empty()
                        && f.effects.vars.iter().any(|v| !no_fail.contains(v))
                    {
                        return false;
                    }
                    pending.extend(&f.params);
                    pending.push(&f.ret);
                    pending.extend(&f.effects.failures);
                }
                Ty::Con(_, ts) | Ty::App(_, ts) => pending.extend(ts),
                Ty::Param(_) | Ty::Rigid { .. } => {}
            }
        }
        true
    }
    /// 型を診断に示す形にする（`List[Integer]`、`function(value: Integer) -> Integer uses Console.Write`）。
    pub fn show(&self, names: &TyNames<'_>) -> String {
        let mut out = String::new();
        show_ty(self, names, &std::collections::BTreeMap::new(), &mut out);
        out
    }
    /// 一つの診断で決めた型構成子の表示名を、入れ子と Fail の型にも適用する。
    pub(crate) fn show_qualified(
        &self,
        names: &TyNames<'_>,
        qualified: &std::collections::BTreeMap<TyCon, String>,
    ) -> String {
        let mut out = String::new();
        show_ty(self, names, qualified, &mut out);
        out
    }
}

impl EffectSet {
    /// エフェクト変数を集合で置き換える（01-12「構文」の `ε[E/ρ]`）。`effs` にない変数はそのまま残す。
    pub fn subst(&self, effs: &[EffectSet]) -> EffectSet {
        self.subst_types(&[], effs)
    }
    /// Fail 内の型と行を同時に置換する。
    pub fn subst_types(&self, tys: &[TypeArg], effs: &[EffectSet]) -> EffectSet {
        let mut out = EffectSet {
            failures: vec![],
            names: self.names.clone(),
            vars: Vec::new(),
        };
        for ty in &self.failures {
            out.insert_failure(ty.subst(tys, effs));
        }
        for v in &self.vars {
            match usize::try_from(v.0).ok().and_then(|i| effs.get(i)) {
                Some(set) => out = out.union(set),
                None => out.insert_var(*v),
            }
        }
        out
    }
}

/// 型を表示するための名前の表。
#[derive(Clone, Copy, Debug)]
pub struct TyNames<'a> {
    /// 外部の型の名前を引く束縛の表
    pub bindings: &'a BindingMap<crate::resolve::Binding>,
    pub adts: &'a AdtTable,
    /// エフェクトの名前の表示に使う（利用者のエフェクトの名前）
    pub effects: &'a BindingMap<EffectDef>,
    /// 表示している文脈の型パラメータの名前（番号の順）
    pub type_params: &'a [String],
    /// 表示している文脈のエフェクト変数の名前（番号の順）
    pub effect_params: &'a [String],
}

impl AdtTable {
    pub fn get(&self, adt: BindingId) -> Option<&AdtDef> {
        self.adts.get(adt)
    }
    /// 構成子の引数の型を、型引数 `args` で置き換えて返す。
    pub fn field_types(&self, adt: BindingId, tag: u32, args: &[Ty]) -> Option<Vec<Ty>> {
        let def = self.get(adt)?;
        if def.type_params.len() != args.len() {
            return None;
        }
        let ctor = def.ctors.iter().find(|c| c.tag == tag)?;
        let tys: Vec<_> = args.iter().cloned().map(TypeArg::Ty).collect();
        Some(ctor.fields.iter().map(|t| t.subst(&tys, &[])).collect())
    }
}

// 型の各段で文字列を作らず、深い型でも一つの出力に書き足す（設計書 02-05「出力」）。
fn show_ty(
    ty: &Ty,
    names: &TyNames<'_>,
    qualified: &std::collections::BTreeMap<TyCon, String>,
    out: &mut String,
) {
    match ty {
        Ty::Con(con, args) => {
            if let Some(name) = qualified.get(con) {
                out.push_str(name);
            } else {
                match con {
                    TyCon::Builtin(id) => {
                        if let Some(d) = id.def()
                            && let Some(name) = id.display_name()
                        {
                            if let Some(module) = d.module.last()
                                && *module != d.name
                            {
                                out.push_str(module);
                                out.push('.');
                            }
                            out.push_str(name);
                        } else {
                            out.push('_');
                        }
                    }
                    TyCon::External(id) => {
                        out.push_str(names.bindings.get(*id).map_or("_", |b| b.name.as_str()))
                    }
                    TyCon::Adt(id) => {
                        out.push_str(names.adts.get(*id).map_or("_", |d| d.name.as_str()))
                    }
                }
            }
            show_args(args, names, qualified, out);
        }
        Ty::Param(i) => out.push_str(param_name(*i, names.type_params)),
        Ty::App(i, args) => {
            out.push_str(param_name(*i, names.type_params));
            show_args(args, names, qualified, out);
        }
        Ty::Rigid { index, .. } => out.push_str(param_name(*index, names.type_params)),
        Ty::Fn(f) => {
            out.push_str("function(");
            for (i, ty) in f.params.iter().enumerate() {
                if i != 0 {
                    out.push_str(", ");
                }
                out.push_str(f.param_names.get(i).map_or("_", String::as_str));
                out.push_str(": ");
                show_ty(ty, names, qualified, out);
            }
            out.push_str(") -> ");
            show_ty(&f.ret, names, qualified, out);
            if !f.effects.is_empty() {
                out.push_str(" uses ");
                let mut effects = Vec::new();
                let io_all = builtin::BUILTIN_EFFECTS
                    .iter()
                    .enumerate()
                    .filter(|(_, d)| d.in_io_all)
                    .all(|(i, _)| {
                        u16::try_from(i).ok().is_some_and(|i| {
                            f.effects
                                .names
                                .contains(&EffectName::Builtin(BuiltinEffectId(i)))
                        })
                    });
                if io_all {
                    effects.push("IO.All".into());
                }
                for name in &f.effects.names {
                    if io_all
                        && matches!(name, EffectName::Builtin(id) if id.def().is_some_and(|d| d.in_io_all))
                    {
                        continue;
                    }
                    let text = match name {
                        EffectName::Builtin(id) => {
                            builtin::effect_name(*id).unwrap_or_else(|| "_".into())
                        }
                        EffectName::User(id) => names
                            .effects
                            .get(*id)
                            .map_or_else(|| "_".into(), |d| d.display_name.clone()),
                    };
                    effects.push(text);
                }
                for ty in &f.effects.failures {
                    effects.push(format!(
                        "Failure.Fail[{}]",
                        ty.show_qualified(names, qualified)
                    ));
                }
                for v in &f.effects.vars {
                    let row = param_name(v.0, names.effect_params);
                    effects.push(if f.effects.failures.is_empty() {
                        row.into()
                    } else {
                        format!("{row} ({row} {})", text::EXCLUDES_FAILURE)
                    });
                }
                out.push_str(&effects.join(", "));
            }
        }
    }
}

fn param_name(index: u32, names: &[String]) -> &str {
    usize::try_from(index)
        .ok()
        .and_then(|i| names.get(i))
        .map_or("_", String::as_str)
}

fn show_args(
    args: &[Ty],
    names: &TyNames<'_>,
    qualified: &std::collections::BTreeMap<TyCon, String>,
    out: &mut String,
) {
    if !args.is_empty() {
        out.push('[');
        for (i, arg) in args.iter().enumerate() {
            if i != 0 {
                out.push_str(", ");
            }
            show_ty(arg, names, qualified, out);
        }
        out.push(']');
    }
}

#[cfg(test)]
mod tests {
    // 公開の置換 API の契約を確かめる。型構成子・関数内のエフェクトの置換漏れと、
    // 同時置換を逐次置換に変える退行は判定の木のテストだけでは捕まらない。
    // 本番の差し込み口を増やさずに確かめる（設計書 07-03「テストの設計の原則」）。
    #![allow(clippy::unwrap_used)]
    use super::*;

    fn integer() -> Ty {
        Ty::Con(TyCon::Builtin(BuiltinTypeId::INTEGER), vec![])
    }

    #[test]
    fn width_type_display_preserves_legacy_names() {
        // 同じ型でも名前の表の正の名前で診断を改名してしまう退行を、公開の表示で捕まえる。
        let bindings = BindingMap::default();
        let effects = BindingMap::default();
        let adts = AdtTable::default();
        let names = TyNames {
            bindings: &bindings,
            adts: &adts,
            effects: &effects,
            type_params: &[],
            effect_params: &[],
        };
        for (ty, expected) in [
            (BuiltinTypeId::INTEGER64, "Integer"),
            (BuiltinTypeId::FLOAT64, "Float"),
            (BuiltinTypeId::UNSIGNED_INTEGER8, "Byte"),
            (BuiltinTypeId::UNSIGNED_INTEGER, "UnsignedInteger64"),
            (BuiltinTypeId::INTEGER8, "Integer8"),
            (BuiltinTypeId::INTEGER16, "Integer16"),
            (BuiltinTypeId::INTEGER32, "Integer32"),
            (BuiltinTypeId::UNSIGNED_INTEGER16, "UnsignedInteger16"),
            (BuiltinTypeId::UNSIGNED_INTEGER32, "UnsignedInteger32"),
            (BuiltinTypeId::FLOAT32, "Float32"),
        ] {
            let ty = Ty::Con(TyCon::Builtin(ty), vec![]);
            assert_eq!(ty.show(&names), expected);
            assert_eq!(
                Ty::Con(TyCon::Builtin(BuiltinTypeId::LIST), vec![ty]).show(&names),
                format!("List[{expected}]")
            );
        }
    }

    #[test]
    fn function_type_display_groups_all_io_effects_and_keeps_other_effects() {
        let mut effects = io_all_for_display();
        effects.insert_name(EffectName::Builtin(BuiltinEffectId(12)));
        effects.insert_var(EffVar(0));
        assert_eq!(
            show_effects(effects),
            "function() -> Integer uses IO.All, Http.Connect, E"
        );
    }

    #[test]
    fn function_type_display_keeps_nine_io_effects_separate() {
        let mut effects = io_all_for_display();
        effects.names.pop();
        assert_eq!(
            show_effects(effects),
            "function() -> Integer uses State, Console.Write, Console.Read, File.Read, File.Write, Process.Run, Process.Exit, Process.Environment, Clock.Time"
        );
    }

    fn io_all_for_display() -> EffectSet {
        EffectSet {
            failures: vec![],
            names: builtin::BUILTIN_EFFECTS
                .iter()
                .enumerate()
                .filter(|(_, d)| d.in_io_all)
                .map(|(i, _)| EffectName::Builtin(BuiltinEffectId(u16::try_from(i).unwrap())))
                .collect(),
            vars: vec![],
        }
    }

    fn show_effects(effects: EffectSet) -> String {
        Ty::Fn(Box::new(FnTy {
            param_names: Vec::new(),
            params: vec![],
            ret: integer(),
            effects,
        }))
        .show(&TyNames {
            bindings: &BindingMap::default(),
            adts: &AdtTable::default(),
            effects: &BindingMap::default(),
            type_params: &[],
            effect_params: &["E".into()],
        })
    }

    #[test]
    fn substitution_is_simultaneous_and_preserves_unbound_parameters() {
        let console = EffectName::Builtin(BuiltinEffectId(2));
        let state = EffectName::Builtin(BuiltinEffectId::STATE);
        let effects = EffectSet {
            failures: vec![],
            names: vec![state],
            vars: vec![EffVar(0), EffVar(1), EffVar(3)],
        };
        let effs = vec![
            EffectSet {
                failures: vec![],
                names: vec![console],
                vars: vec![EffVar(1)],
            },
            EffectSet {
                failures: vec![],
                names: vec![state],
                vars: vec![EffVar(2)],
            },
        ];
        let mut expected = EffectSet::empty();
        for name in [state, console] {
            expected.insert_name(name);
        }
        for v in [1, 2, 3] {
            expected.insert_var(EffVar(v));
        }
        assert_eq!(effects.subst(&effs), expected);
        let ty = Ty::Fn(Box::new(FnTy {
            param_names: vec!["value".into(), "items".into(), "extra".into()],
            params: vec![
                Ty::Param(0),
                Ty::App(1, vec![Ty::Param(2)]),
                Ty::App(4, vec![Ty::Param(0)]),
            ],
            ret: Ty::Rigid {
                clause: NodeId(8),
                index: 0,
            },
            effects,
        }));
        for (head, applied) in [
            (
                TyHead::Con(TyCon::Builtin(BuiltinTypeId::LIST)),
                Ty::Con(TyCon::Builtin(BuiltinTypeId::LIST), vec![integer()]),
            ),
            (TyHead::Param(7), Ty::App(7, vec![integer()])),
        ] {
            let result = ty.subst(
                &[
                    TypeArg::Ty(Ty::Param(2)),
                    TypeArg::Head(head),
                    TypeArg::Ty(integer()),
                ],
                &effs,
            );
            assert_eq!(
                result,
                Ty::Fn(Box::new(FnTy {
                    param_names: vec!["value".into(), "items".into(), "extra".into()],
                    params: vec![Ty::Param(2), applied, Ty::App(4, vec![Ty::Param(2)])],
                    ret: Ty::Rigid {
                        clause: NodeId(8),
                        index: 0
                    },
                    effects: expected.clone(),
                }))
            );
        }
        assert_eq!(Ty::Param(9).subst(&[], &[]), Ty::Param(9));
    }

    #[test]
    fn function_contracts_affect_structure_hash_and_display() {
        use std::collections::HashSet;
        let f = FnTy {
            param_names: vec!["left".into(), "right".into()],
            params: vec![integer(), integer()],
            ret: integer(),
            effects: EffectSet::empty(),
        };
        let mut reversed = f.clone();
        reversed.param_names.reverse();
        let mut third = f.clone();
        third.param_names = vec!["left".into(), "other".into()];
        let mut renamed = third.clone();
        renamed.param_names = vec!["a".into(), "b".into()];
        let types: HashSet<_> = [f.clone(), reversed, third, renamed]
            .into_iter()
            .map(|f| Ty::Fn(Box::new(f)))
            .collect();
        assert_eq!(types.len(), 4);
        let bindings = BindingMap::default();
        let effects = BindingMap::default();
        let adts = AdtTable::default();
        let names = TyNames {
            bindings: &bindings,
            effects: &effects,
            adts: &adts,
            type_params: &[],
            effect_params: &[],
        };
        assert_eq!(
            Ty::Fn(Box::new(f)).show(&names),
            "function(left: Integer, right: Integer) -> Integer"
        );
    }

    #[test]
    fn constructor_fields_are_instantiated_and_missing_entries_return_none() {
        let binding = BindingId(7);
        let mut table = AdtTable::default();
        table.adts.insert(
            binding,
            AdtDef {
                extensible: false,
                binding,
                name: "Box".into(),
                module: ModuleId(0),
                type_params: vec!["T".into()],
                ctors: vec![CtorDef {
                    name: "Box".into(),
                    binding: BindingId(8),
                    tag: 0,
                    fields: vec![Ty::Con(
                        TyCon::Builtin(BuiltinTypeId::LIST),
                        vec![Ty::Param(0)],
                    )],
                }],
                record: None,
                eq_summary: TypeSummary::default(),
                key_summary: TypeSummary::default(),
            },
        );
        assert_eq!(table.get(binding).unwrap().name, "Box");
        assert_eq!(
            table.field_types(binding, 0, &[integer()]),
            Some(vec![Ty::Con(
                TyCon::Builtin(BuiltinTypeId::LIST),
                vec![integer()]
            )])
        );
        assert!(table.get(BindingId(99)).is_none());
        assert!(table.field_types(BindingId(99), 0, &[]).is_none());
        assert!(table.field_types(binding, 1, &[integer()]).is_none());
        assert!(table.field_types(binding, 0, &[]).is_none());
    }
}
