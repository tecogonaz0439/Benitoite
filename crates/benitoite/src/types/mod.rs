//! 型の表現（設計書 01-06、02-05「型とエフェクトの表現」）。

use crate::base::BindingId;

/// 型の名前（型構成子）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum TyCon {
    Int,
    Float,
    String,
    Char,
    Bool,
    Unit,
    List,
    Option,
    Result,
    /// 中身を見せない prelude の型（ADR 0048）
    IoError,
    /// 利用者の型。型の宣言の束縛の番号で識別する
    Adt(BindingId),
}

impl TyCon {
    /// 型引数の個数（利用者の型は `AdtDef` を見る）。
    pub fn builtin_arity(self) -> Option<usize> {
        match self {
            TyCon::Int
            | TyCon::Float
            | TyCon::String
            | TyCon::Char
            | TyCon::Bool
            | TyCon::Unit
            | TyCon::IoError => Some(0),
            TyCon::List | TyCon::Option => Some(1),
            TyCon::Result => Some(2),
            TyCon::Adt(_) => None,
        }
    }

    /// 基本型か（01-04）。
    pub fn is_basic(self) -> bool {
        matches!(
            self,
            TyCon::Int | TyCon::Float | TyCon::String | TyCon::Char | TyCon::Bool | TyCon::Unit
        )
    }
}

/// エフェクト変数。宣言の中の位置で表す（本章の冒頭）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct EffVar(pub u32);

/// 確定したエフェクトの集合。`vars` は昇順で重複を持たない。
#[derive(Clone, PartialEq, Eq, Hash, Debug, Default)]
pub struct EffectSet {
    pub io: bool,
    pub vars: Vec<EffVar>,
}

impl EffectSet {
    pub fn empty() -> EffectSet {
        EffectSet::default()
    }

    pub fn io() -> EffectSet {
        EffectSet {
            io: true,
            vars: Vec::new(),
        }
    }

    pub fn is_empty(&self) -> bool {
        !self.io && self.vars.is_empty()
    }

    pub fn insert_var(&mut self, v: EffVar) {
        if let Err(pos) = self.vars.binary_search(&v) {
            self.vars.insert(pos, v);
        }
    }

    pub fn union(&self, other: &EffectSet) -> EffectSet {
        let mut out = self.clone();
        out.io = out.io || other.io;
        for v in &other.vars {
            out.insert_var(*v);
        }
        out
    }

    /// self ⊆ other
    pub fn is_subset(&self, other: &EffectSet) -> bool {
        (!self.io || other.io)
            && self
                .vars
                .iter()
                .all(|v| other.vars.binary_search(v).is_ok())
    }

    /// エフェクト変数を集合で置き換える（01-12「ε[E/ρ]」）。`effs` にない変数はそのまま残す。
    pub fn subst(&self, effs: &[EffectSet]) -> EffectSet {
        let mut out = EffectSet {
            io: self.io,
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

/// 型検査を終えた後の型。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub enum Ty {
    Con(TyCon, Vec<Ty>),
    Fn(Box<FnTy>),
    /// 型パラメータ（本章の冒頭）
    Param(u32),
}

#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct FnTy {
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
}

impl Ty {
    pub fn con(c: TyCon) -> Ty {
        Ty::Con(c, Vec::new())
    }

    pub fn int() -> Ty {
        Ty::con(TyCon::Int)
    }

    pub fn float() -> Ty {
        Ty::con(TyCon::Float)
    }

    pub fn string() -> Ty {
        Ty::con(TyCon::String)
    }

    pub fn char() -> Ty {
        Ty::con(TyCon::Char)
    }

    pub fn bool() -> Ty {
        Ty::con(TyCon::Bool)
    }

    pub fn unit() -> Ty {
        Ty::con(TyCon::Unit)
    }

    pub fn list(elem: Ty) -> Ty {
        Ty::Con(TyCon::List, vec![elem])
    }

    pub fn option(t: Ty) -> Ty {
        Ty::Con(TyCon::Option, vec![t])
    }

    pub fn result(t: Ty, e: Ty) -> Ty {
        Ty::Con(TyCon::Result, vec![t, e])
    }

    pub fn func(params: Vec<Ty>, ret: Ty, effects: EffectSet) -> Ty {
        Ty::Fn(Box::new(FnTy {
            params,
            ret,
            effects,
        }))
    }

    /// 型パラメータを `tys` で、エフェクト変数を `effs` で置き換える。
    /// `tys`・`effs` にない番号はそのまま残す。
    pub fn subst(&self, tys: &[Ty], effs: &[EffectSet]) -> Ty {
        match self {
            Ty::Con(c, args) => Ty::Con(*c, args.iter().map(|a| a.subst(tys, effs)).collect()),
            Ty::Fn(f) => Ty::Fn(Box::new(FnTy {
                params: f.params.iter().map(|p| p.subst(tys, effs)).collect(),
                ret: f.ret.subst(tys, effs),
                effects: f.effects.subst(effs),
            })),
            Ty::Param(i) => match usize::try_from(*i).ok().and_then(|i| tys.get(i)) {
                Some(t) => t.clone(),
                None => Ty::Param(*i),
            },
        }
    }

    /// 型を診断に示す形にする（`List[Int]`、`fn(Int) -> Int uses IO`、`Tree[T]`）。
    pub fn show(&self, names: &TyNames<'_>) -> String {
        match self {
            Ty::Con(c, args) => {
                let head = names.con_name(*c);
                if args.is_empty() {
                    head
                } else {
                    let inner: Vec<String> = args.iter().map(|a| a.show(names)).collect();
                    format!("{head}[{}]", inner.join(", "))
                }
            }
            Ty::Fn(f) => {
                let params: Vec<String> = f.params.iter().map(|p| p.show(names)).collect();
                let mut s = format!("fn({}) -> {}", params.join(", "), f.ret.show(names));
                if !f.effects.is_empty() {
                    s.push_str(" uses ");
                    s.push_str(&names.show_effects(&f.effects));
                }
                s
            }
            Ty::Param(i) => names.type_param_name(*i),
        }
    }
}

/// 型を表示するための名前の表。
#[derive(Clone, Copy, Debug)]
pub struct TyNames<'a> {
    pub adts: &'a AdtTable,
    /// 表示している文脈の型パラメータの名前
    pub type_params: &'a [String],
    /// 表示している文脈のエフェクト変数の名前
    pub effect_params: &'a [String],
}

impl TyNames<'_> {
    pub fn con_name(&self, c: TyCon) -> String {
        match c {
            TyCon::Int => "Int".to_string(),
            TyCon::Float => "Float".to_string(),
            TyCon::String => "String".to_string(),
            TyCon::Char => "Char".to_string(),
            TyCon::Bool => "Bool".to_string(),
            TyCon::Unit => "Unit".to_string(),
            TyCon::List => "List".to_string(),
            TyCon::Option => "Option".to_string(),
            TyCon::Result => "Result".to_string(),
            TyCon::IoError => "IoError".to_string(),
            TyCon::Adt(_) => self
                .adts
                .get(c)
                .map_or_else(|| "?".to_string(), |d| d.name.clone()),
        }
    }

    pub fn type_param_name(&self, i: u32) -> String {
        usize::try_from(i)
            .ok()
            .and_then(|i| self.type_params.get(i))
            .cloned()
            .unwrap_or_else(|| format!("T{i}"))
    }

    /// `IO, E` の形。`IO` を先に、エフェクト変数を宣言の順に並べる。
    pub fn show_effects(&self, e: &EffectSet) -> String {
        let mut parts = Vec::new();
        if e.io {
            parts.push("IO".to_string());
        }
        for v in &e.vars {
            let name = usize::try_from(v.0)
                .ok()
                .and_then(|i| self.effect_params.get(i))
                .cloned()
                .unwrap_or_else(|| format!("E{}", v.0));
            parts.push(name);
        }
        parts.join(", ")
    }
}

/// 型パラメータに付ける制約。prelude の関数の型だけが持つ（01-06「prelude の関数の型」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ParamConstraint {
    None,
    /// 等値の型であること
    Equality,
    /// 型の集まりのどれかであること
    OneOf(TySet),
}

/// 演算子の型の集まり（01-06「演算子の型付け」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TySet(pub &'static [TyCon]);

impl TySet {
    /// `+`
    pub const ADD: TySet = TySet(&[TyCon::Int, TyCon::Float, TyCon::String]);
    /// `-`・`*`・`/`・単項の `-`
    pub const ARITH: TySet = TySet(&[TyCon::Int, TyCon::Float]);
    /// `<`・`<=`・`>`・`>=`、`List.sort`
    pub const ORD: TySet = TySet(&[TyCon::Int, TyCon::Float, TyCon::String, TyCon::Char]);

    pub fn contains(self, c: TyCon) -> bool {
        self.0.contains(&c)
    }

    /// 共通部分。三つの集まりは ARITH ⊆ ADD ⊆ ORD の包含の関係にあるので、小さいほうになる。
    pub fn intersect(self, other: TySet) -> TySet {
        if self.0.iter().all(|c| other.contains(*c)) {
            self
        } else if other.0.iter().all(|c| self.contains(*c)) {
            other
        } else {
            TySet(&[])
        }
    }
}

/// 型パラメータの情報。
#[derive(Clone, PartialEq, Debug)]
pub struct TypeParamInfo {
    pub name: String,
    pub constraint: ParamConstraint,
}

/// 多相な名前の宣言の型（02-05「出力」の「宣言の型」）。
#[derive(Clone, PartialEq, Debug)]
pub struct Scheme {
    pub type_params: Vec<TypeParamInfo>,
    pub effect_params: Vec<String>,
    pub params: Vec<Ty>,
    pub ret: Ty,
    pub effects: EffectSet,
}

impl Scheme {
    /// 関数の型として見た型（型パラメータは置き換えない）。
    pub fn fn_ty(&self) -> Ty {
        Ty::func(self.params.clone(), self.ret.clone(), self.effects.clone())
    }
}

/// 等値の型の要約（01-06「等値の型」、ADR 0082）。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct EqSummary {
    /// 型引数によらず、関数の型か中身を見せない prelude の型を含む
    pub always: bool,
    /// 含むかどうかが型引数に依存する型パラメータの位置（昇順）
    pub depends_on: Vec<u32>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct CtorDef {
    pub name: String,
    /// 構成子の束縛の番号
    pub binding: BindingId,
    pub tag: u32,
    /// 引数の型。型の宣言の型パラメータを `Ty::Param` で表す
    pub fields: Vec<Ty>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct AdtDef {
    pub con: TyCon,
    pub name: String,
    pub type_params: Vec<String>,
    /// タグの順（宣言の順）
    pub ctors: Vec<CtorDef>,
    pub eq_summary: EqSummary,
}

/// 代数的データ型の表。`Option`・`Result` と利用者の型を持つ。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct AdtTable {
    pub adts: Vec<AdtDef>,
}

impl AdtTable {
    pub fn get(&self, con: TyCon) -> Option<&AdtDef> {
        self.adts.iter().find(|d| d.con == con)
    }

    /// 構成子の引数の型を、型引数 `args` で置き換えて返す。
    pub fn field_types(&self, con: TyCon, tag: u32, args: &[Ty]) -> Option<Vec<Ty>> {
        let def = self.get(con)?;
        let ctor = def.ctors.iter().find(|c| c.tag == tag)?;
        Some(ctor.fields.iter().map(|f| f.subst(args, &[])).collect())
    }
}
