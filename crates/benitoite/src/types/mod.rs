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
        self.names
            .iter()
            .all(|n| other.names.binary_search(n).is_ok())
            && self
                .vars
                .iter()
                .all(|v| other.vars.binary_search(v).is_ok())
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
    Rigid {
        clause: NodeId,
        index: u32,
    },
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
    /// いま検査している定義が受け取った辞書。`constraint` はその定義の制約の番号、
    /// `supers` はそこから辿る上位の型クラスの並び（辿らなければ空。`d↑Monoid↑Semigroup` の Monoid・Semigroup）
    Param {
        constraint: u32,
        supers: Vec<BindingId>,
    },
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

impl Ty {
    /// 型パラメータを `tys` で、エフェクト変数を `effs` で置き換える（`Ty::App(i, args)` の i が
    /// `TypeArg::Head(TyHead::Con(c))` に置き換わるときは `Ty::Con(c, args)` にする）。
    /// `tys`・`effs` にない番号はそのまま残す。`Ty::Rigid` は置き換えない。
    pub fn subst(&self, tys: &[TypeArg], effs: &[EffectSet]) -> Ty {
        let arg = |i: u32| usize::try_from(i).ok().and_then(|i| tys.get(i));
        match self {
            Ty::Con(con, args) => Ty::Con(*con, args.iter().map(|t| t.subst(tys, effs)).collect()),
            Ty::Fn(f) => Ty::Fn(Box::new(FnTy {
                params: f.params.iter().map(|t| t.subst(tys, effs)).collect(),
                ret: f.ret.subst(tys, effs),
                effects: f.effects.subst(effs),
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
    /// 型を診断に示す形にする（`List[Integer]`、`function(Integer) -> Integer uses Console.Write`）。
    pub fn show(&self, names: &TyNames<'_>) -> String {
        let mut out = String::new();
        show_ty(self, names, &mut out);
        out
    }
}

impl EffectSet {
    /// エフェクト変数を集合で置き換える（01-12「ε[E/ρ]」）。`effs` にない変数はそのまま残す。
    pub fn subst(&self, effs: &[EffectSet]) -> EffectSet {
        let mut out = EffectSet {
            names: self.names.clone(),
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
fn show_ty(ty: &Ty, names: &TyNames<'_>, out: &mut String) {
    match ty {
        Ty::Con(con, args) => {
            match con {
                TyCon::Builtin(id) => {
                    if let Some(d) = id.def() {
                        if let Some(module) = d.module.last()
                            && *module != d.name
                        {
                            out.push_str(module);
                            out.push('.');
                        }
                        out.push_str(d.name);
                    } else {
                        out.push('_');
                    }
                }
                TyCon::Adt(id) => {
                    out.push_str(names.adts.get(*id).map_or("_", |d| d.name.as_str()))
                }
            }
            show_args(args, names, out);
        }
        Ty::Param(i) => out.push_str(param_name(*i, names.type_params)),
        Ty::App(i, args) => {
            out.push_str(param_name(*i, names.type_params));
            show_args(args, names, out);
        }
        Ty::Rigid { index, .. } => out.push_str(param_name(*index, names.type_params)),
        Ty::Fn(f) => {
            out.push_str("function(");
            for (i, ty) in f.params.iter().enumerate() {
                if i != 0 {
                    out.push_str(", ");
                }
                show_ty(ty, names, out);
            }
            out.push_str(") -> ");
            show_ty(&f.ret, names, out);
            if !f.effects.is_empty() {
                out.push_str(" uses ");
                let mut effects = Vec::new();
                for name in &f.effects.names {
                    let text = match name {
                        EffectName::Builtin(id) => id
                            .def()
                            .map(|d| {
                                let mut parts = Vec::new();
                                if let Some(last) = d.module.last() {
                                    parts.push(*last);
                                }
                                parts.push(d.name);
                                parts.join(".")
                            })
                            .unwrap_or_else(|| "_".into()),
                        EffectName::User(id) => names
                            .effects
                            .get(*id)
                            .map_or_else(|| "_".into(), |d| d.display_name.clone()),
                    };
                    effects.push(text);
                }
                for v in &f.effects.vars {
                    effects.push(param_name(v.0, names.effect_params).into());
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

fn show_args(args: &[Ty], names: &TyNames<'_>, out: &mut String) {
    if !args.is_empty() {
        out.push('[');
        for (i, arg) in args.iter().enumerate() {
            if i != 0 {
                out.push_str(", ");
            }
            show_ty(arg, names, out);
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
    fn substitution_is_simultaneous_and_preserves_unbound_parameters() {
        let console = EffectName::Builtin(BuiltinEffectId(2));
        let state = EffectName::Builtin(BuiltinEffectId::STATE);
        let effects = EffectSet {
            names: vec![state],
            vars: vec![EffVar(0), EffVar(1), EffVar(3)],
        };
        let effs = vec![
            EffectSet {
                names: vec![console],
                vars: vec![EffVar(1)],
            },
            EffectSet {
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
    fn constructor_fields_are_instantiated_and_missing_entries_return_none() {
        let binding = BindingId(7);
        let mut table = AdtTable::default();
        table.adts.insert(
            binding,
            AdtDef {
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
