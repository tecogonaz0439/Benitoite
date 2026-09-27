//! コア IR の検査器（設計書 02-06「コア IR の検査器」、01-12「型付け規則」）。
//!
//! 脱糖の結果に 01-12 の型付け規則で型が付くかを調べる。テストだけで使い、型が付かなければ
//! 処理系の不具合とする（01-12「確かめる性質」の 1、脱糖の型の保存の反例を探す手段）。
//! 包含（V-Sub・C-Sub）は、型が求められる位置でだけ使う（02-06、ADR 0081）。

use std::collections::{BTreeMap, BTreeSet};

use super::core_ir::{
    Arm, Comp, CompKind, Const, CoreDef, CorePat, CoreProgram, CoreVal, Lambda, ValKind, Var, VarId,
};
use crate::base::{BindingId, Span};
use crate::builtins::table::scheme;
use crate::types::{AdtTable, EffectSet, ParamConstraint, Ty, TyCon};

/// コア IR の検査器が見つけた、型の付かない箇所（処理系の不具合）。
#[derive(Clone, PartialEq, Debug)]
pub struct CoreTypeError {
    /// 定義の名前
    pub def: String,
    pub origin: Span,
    pub message: String,
}

/// コア IR に 01-12 の型付け規則で型が付くかを調べる（02-06「コア IR の検査器」）。テストだけで使う。
/// 型が付けば空の並びを返す。
pub fn check_program(program: &CoreProgram) -> Vec<CoreTypeError> {
    // TopFn の型を求めるため、束縛の番号から定義を引く表を先に作る。
    let defs: BTreeMap<BindingId, &CoreDef> = program.defs.iter().map(|d| (d.binding, d)).collect();
    let mut checker = Checker {
        adts: &program.adts,
        defs,
        errors: Vec::new(),
        def_name: String::new(),
        env: Vec::new(),
    };
    // 誤りを見つけても、ほかの定義の検査を続ける。
    for def in &program.defs {
        checker.check_def(def);
    }
    checker.errors
}

/// 定数の型（01-12 の `type(c)`）。
fn const_ty(c: &Const) -> Ty {
    match c {
        Const::Int(_) => Ty::int(),
        Const::Float(_) => Ty::float(),
        Const::Str(_) => Ty::string(),
        Const::Char(_) => Ty::char(),
        Const::Bool(_) => Ty::bool(),
        Const::Unit => Ty::unit(),
    }
}

/// 型が求められる位置で、型 `actual` の値を型 `expected` として使えるか（01-12 の `≤`）。
/// `≤` は最も外側の関数の型のエフェクトにだけ働くので、引数と戻り値の型は等しさで比べる。
fn fits(actual: &Ty, expected: &Ty) -> bool {
    if let (Ty::Fn(a), Ty::Fn(e)) = (actual, expected) {
        a.params == e.params && a.ret == e.ret && a.effects.is_subset(&e.effects)
    } else {
        actual == expected
    }
}

/// 等値の型か（01-06「等値の型」）。関数の型・`IoError`・型パラメータは等値の型でない。
/// 定義の中の型パラメータは、ほかの何とも等しくないものとして扱う（01-12「定義」）ので、
/// 制約を満たすとは言えない。
fn is_equality_ty(adts: &AdtTable, ty: &Ty) -> bool {
    match ty {
        Ty::Fn(_) | Ty::Param(_) | Ty::Con(TyCon::IoError, _) => false,
        Ty::Con(TyCon::List, args) => args.iter().all(|a| is_equality_ty(adts, a)),
        Ty::Con(c, args) => match adts.get(*c) {
            // 代数的データ型は要約で判定する（ADR 0082）。
            Some(def) => {
                !def.eq_summary.always
                    && def.eq_summary.depends_on.iter().all(|i| {
                        usize::try_from(*i)
                            .ok()
                            .and_then(|i| args.get(i))
                            .is_some_and(|a| is_equality_ty(adts, a))
                    })
            }
            None => args.iter().all(|a| is_equality_ty(adts, a)),
        },
    }
}

/// 説明の文に埋める型の表記。テストで不具合を調べるためだけの文なので、`Debug` の形で足りる。
fn show(ty: &Ty) -> String {
    format!("{ty:?}")
}

struct Checker<'p> {
    adts: &'p AdtTable,
    defs: BTreeMap<BindingId, &'p CoreDef>,
    errors: Vec<CoreTypeError>,
    /// 検査している定義の名前
    def_name: String,
    /// 型の環境。後から加えたものを先に引く。スコープを出るときに切り詰める
    env: Vec<(VarId, Ty)>,
}

impl Checker<'_> {
    fn error(&mut self, origin: Span, message: String) {
        self.errors.push(CoreTypeError {
            def: self.def_name.clone(),
            origin,
            message,
        });
    }

    fn lookup(&self, id: VarId) -> Option<&Ty> {
        self.env
            .iter()
            .rev()
            .find(|(v, _)| *v == id)
            .map(|(_, t)| t)
    }

    /// 定義: 本体の型が宣言の戻り値の型を受け入れ、エフェクトが宣言に含まれること（01-12「定義」）。
    /// 型パラメータとエフェクト変数は `Ty::Param`・`EffVar` のまま比べるので、
    /// ほかの何とも等しくないものとして扱われる。
    fn check_def(&mut self, def: &CoreDef) {
        self.def_name = def.name.clone();
        self.env.clear();
        for p in &def.params {
            self.env.push((p.id, p.ty.clone()));
        }
        self.check_comp(&def.body);
        self.expect_comp(
            &def.body,
            &def.ret,
            &def.eff,
            def.body.origin,
            "definition body",
        );
    }

    /// 型が求められる位置の計算を確かめる（C-Sub）。
    fn expect_comp(&mut self, c: &Comp, ty: &Ty, eff: &EffectSet, origin: Span, what: &str) {
        if !fits(&c.ty, ty) {
            self.error(
                origin,
                format!("{what}: expected type {}, found {}", show(ty), show(&c.ty)),
            );
        }
        if !c.eff.is_subset(eff) {
            self.error(
                origin,
                format!("{what}: effects {:?} are not included in {eff:?}", c.eff),
            );
        }
    }

    /// 型が求められる位置の値を確かめる（V-Sub）。
    fn expect_val(&mut self, actual: &Ty, expected: &Ty, origin: Span, what: &str) {
        if !fits(actual, expected) {
            self.error(
                origin,
                format!(
                    "{what}: expected type {}, found {}",
                    show(expected),
                    show(actual)
                ),
            );
        }
    }

    /// 値を検査し、規則で導いた型が欄 `ty` と等しいことを確かめる。
    fn check_val(&mut self, v: &CoreVal) {
        let derived = match &v.kind {
            ValKind::Var(id) => {
                let found = self.lookup(*id).cloned();
                if found.is_none() {
                    self.error(v.origin, format!("unbound variable {id:?}"));
                }
                found
            }
            ValKind::Const(c) => Some(const_ty(c)),
            ValKind::TopFn { def, tys, effs } => self.top_fn_ty(*def, tys, effs, v.origin),
            ValKind::Builtin { id, tys, effs } => {
                let s = scheme(*id);
                if s.type_params.len() != tys.len() || s.effect_params.len() != effs.len() {
                    self.error(
                        v.origin,
                        format!("builtin {id:?}: wrong number of type or effect arguments"),
                    );
                    None
                } else {
                    // V-Prim: 型引数が型パラメータの制約を満たすこと。
                    for (info, t) in s.type_params.iter().zip(tys) {
                        let ok = match info.constraint {
                            ParamConstraint::None => true,
                            ParamConstraint::Equality => is_equality_ty(self.adts, t),
                            ParamConstraint::OneOf(set) => {
                                matches!(t, Ty::Con(c, args) if args.is_empty() && set.contains(*c))
                            }
                        };
                        if !ok {
                            self.error(
                                v.origin,
                                format!(
                                    "builtin {id:?}: type argument {} violates constraint {:?}",
                                    show(t),
                                    info.constraint
                                ),
                            );
                        }
                    }
                    Some(s.fn_ty().subst(tys, effs))
                }
            }
            ValKind::Lambda(lam) => {
                self.check_lambda(lam, &v.ty, v.origin);
                None
            }
            ValKind::Ctor {
                con,
                tag,
                tys,
                args,
            } => {
                match self.adts.field_types(*con, *tag, tys) {
                    Some(fields) if fields.len() == args.len() => {
                        for (a, f) in args.iter().zip(&fields) {
                            self.check_val(a);
                            self.expect_val(&a.ty, f, a.origin, "constructor argument");
                        }
                    }
                    Some(_) => self.error(
                        v.origin,
                        format!("constructor {con:?}/{tag}: wrong number of arguments"),
                    ),
                    None => self.error(v.origin, format!("unknown constructor {con:?}/{tag}")),
                }
                Some(Ty::Con(*con, tys.clone()))
            }
            ValKind::List(elems) => {
                if let Ty::Con(TyCon::List, targs) = &v.ty
                    && let [elem_ty] = targs.as_slice()
                {
                    for e in elems {
                        self.check_val(e);
                        self.expect_val(&e.ty, elem_ty, e.origin, "list element");
                    }
                } else {
                    self.error(
                        v.origin,
                        format!("list literal has non-list type {}", show(&v.ty)),
                    );
                }
                None
            }
        };
        if let Some(d) = derived
            && d != v.ty
        {
            self.error(
                v.origin,
                format!(
                    "value node type mismatch: derived {}, annotated {}",
                    show(&d),
                    show(&v.ty)
                ),
            );
        }
    }

    /// V-Fun: 定義の型を型引数とエフェクト引数で置き換えた型。
    fn top_fn_ty(
        &mut self,
        binding: BindingId,
        tys: &[Ty],
        effs: &[EffectSet],
        origin: Span,
    ) -> Option<Ty> {
        let Some(def) = self.defs.get(&binding).copied() else {
            self.error(origin, format!("unknown top-level function {binding:?}"));
            return None;
        };
        if def.type_params.len() != tys.len() || def.effect_params.len() != effs.len() {
            self.error(
                origin,
                format!(
                    "function {}: wrong number of type or effect arguments",
                    def.name
                ),
            );
            return None;
        }
        let params = def.params.iter().map(|p| p.ty.clone()).collect();
        Some(Ty::func(params, def.ret.clone(), def.eff.clone()).subst(tys, effs))
    }

    /// V-Lam: ノードの型 `(Ā) → B ! ε` について、引数の型が等しく、本体が B と ε を受け入れること。
    /// ラムダの本体と戻り値の型は包含を使う位置である（02-06）。
    fn check_lambda(&mut self, lam: &Lambda<Comp>, ty: &Ty, origin: Span) {
        let saved = self.env.len();
        for p in &lam.params {
            self.env.push((p.id, p.ty.clone()));
        }
        self.check_comp(&lam.body);
        self.env.truncate(saved);
        let Ty::Fn(f) = ty else {
            self.error(origin, format!("lambda has non-function type {}", show(ty)));
            return;
        };
        let same_params = lam.params.len() == f.params.len()
            && lam.params.iter().zip(&f.params).all(|(p, t)| &p.ty == t);
        if !same_params {
            self.error(
                origin,
                "lambda parameter types differ from its type".to_string(),
            );
        }
        self.expect_comp(&lam.body, &f.ret, &f.effects, origin, "lambda body");
    }

    /// 計算を検査し、導いた型が欄 `ty` と等しく、導いたエフェクトが欄 `eff` に含まれることを確かめる。
    /// `if`・`match` は分岐が包含を使う位置なので、分岐ごとにノードの型とエフェクトと比べる。
    fn check_comp(&mut self, c: &Comp) {
        let (derived_ty, derived_eff) = match &c.kind {
            CompKind::Return(v) => {
                self.check_val(v);
                (Some(v.ty.clone()), EffectSet::empty())
            }
            CompKind::Let { var, bound, body } => {
                self.check_comp(bound);
                // let の右側と束縛した変数の型は、包含を使う位置である。
                self.expect_comp(bound, &var.ty, &c.eff, c.origin, "let-bound computation");
                let saved = self.env.len();
                self.env.push((var.id, var.ty.clone()));
                self.check_comp(body);
                self.env.truncate(saved);
                (Some(body.ty.clone()), bound.eff.union(&body.eff))
            }
            CompKind::App { func, args } => self.check_app(func, args, c.origin),
            CompKind::If {
                cond,
                then_branch,
                else_branch,
            } => {
                self.check_val(cond);
                if cond.ty != Ty::bool() {
                    self.error(
                        cond.origin,
                        format!("if condition has type {}", show(&cond.ty)),
                    );
                }
                for b in [then_branch, else_branch] {
                    self.check_comp(b);
                    self.expect_comp(b, &c.ty, &c.eff, b.origin, "if branch");
                }
                (None, EffectSet::empty())
            }
            CompKind::Match { scrutinee, arms } => {
                self.check_val(scrutinee);
                for arm in arms {
                    self.check_arm(arm, &scrutinee.ty, c);
                }
                (None, EffectSet::empty())
            }
        };
        if let Some(t) = derived_ty
            && t != c.ty
        {
            self.error(
                c.origin,
                format!(
                    "computation node type mismatch: derived {}, annotated {}",
                    show(&t),
                    show(&c.ty)
                ),
            );
        }
        if !derived_eff.is_subset(&c.eff) {
            self.error(
                c.origin,
                format!(
                    "computation effects {derived_eff:?} are not included in annotated {:?}",
                    c.eff
                ),
            );
        }
    }

    /// C-App。関数の型そのものは等しさで比べ、引数の位置でだけ包含を使う。
    fn check_app(
        &mut self,
        func: &CoreVal,
        args: &[CoreVal],
        origin: Span,
    ) -> (Option<Ty>, EffectSet) {
        self.check_val(func);
        for a in args {
            self.check_val(a);
        }
        let Ty::Fn(f) = &func.ty else {
            self.error(
                origin,
                format!("applied value has non-function type {}", show(&func.ty)),
            );
            return (None, EffectSet::empty());
        };
        if f.params.len() != args.len() {
            self.error(
                origin,
                format!(
                    "function expects {} arguments, found {}",
                    f.params.len(),
                    args.len()
                ),
            );
        } else {
            for (a, p) in args.iter().zip(&f.params) {
                self.expect_val(&a.ty, p, origin, "function argument");
            }
        }
        (Some(f.ret.clone()), f.effects.clone())
    }

    /// C-Match の一つの分岐。網羅性は調べない（02-06「コア IR の検査器」）。
    fn check_arm(&mut self, arm: &Arm, scrutinee_ty: &Ty, node: &Comp) {
        let saved = self.env.len();
        let mut seen = BTreeSet::new();
        self.check_pat(&arm.pattern, scrutinee_ty, &mut seen, node.origin);
        self.check_comp(&arm.body);
        self.env.truncate(saved);
        self.expect_comp(&arm.body, &node.ty, &node.eff, arm.body.origin, "match arm");
    }

    /// `⊢p p : A ⊣ Δ`（01-12「パターン」）。パターンの型は等しさで比べ、束縛した変数を環境に加える。
    fn check_pat(&mut self, p: &CorePat, ty: &Ty, seen: &mut BTreeSet<VarId>, origin: Span) {
        match p {
            CorePat::Wild => {}
            CorePat::Var(Var { id, ty: vty, .. }) => {
                if !seen.insert(*id) {
                    self.error(origin, format!("pattern binds {id:?} twice"));
                }
                if vty != ty {
                    self.error(
                        origin,
                        format!(
                            "pattern variable has type {}, scrutinee has {}",
                            show(vty),
                            show(ty)
                        ),
                    );
                }
                self.env.push((*id, vty.clone()));
            }
            CorePat::Const(c) => {
                // P-Const: Float の定数はパターンに書けない。
                if matches!(c, Const::Float(_)) {
                    self.error(origin, "Float constant in pattern".to_string());
                }
                let cty = const_ty(c);
                if &cty != ty {
                    self.error(
                        origin,
                        format!(
                            "constant pattern has type {}, scrutinee has {}",
                            show(&cty),
                            show(ty)
                        ),
                    );
                }
            }
            CorePat::Ctor { con, tag, args } => {
                let fields = if let Ty::Con(c, targs) = ty
                    && c == con
                {
                    self.adts.field_types(*con, *tag, targs)
                } else {
                    None
                };
                match fields {
                    Some(fields) if fields.len() == args.len() => {
                        for (a, f) in args.iter().zip(&fields) {
                            self.check_pat(a, f, seen, origin);
                        }
                    }
                    _ => self.error(
                        origin,
                        format!(
                            "constructor pattern {con:?}/{tag} does not match type {}",
                            show(ty)
                        ),
                    ),
                }
            }
        }
    }
}

#[cfg(test)]
// テストの失敗は panic で表す（設計書 07-03「実装の規約と静的な検査」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::{BytePos, FileId};
    use crate::builtins::BuiltinId;
    use crate::ir::core_ir::{DefOrigin, LambdaId, Program};
    use crate::types::{AdtDef, CtorDef, EffVar, EqSummary};

    fn sp(n: u32) -> Span {
        Span {
            file: FileId(0),
            start: BytePos(n),
            end: BytePos(n),
        }
    }

    fn var(id: u32, ty: Ty) -> Var {
        Var {
            id: VarId(id),
            name: None,
            ty,
        }
    }

    fn val(kind: ValKind<Comp>, ty: Ty) -> CoreVal {
        CoreVal {
            kind,
            ty,
            origin: sp(0),
        }
    }

    fn v(x: &Var) -> CoreVal {
        val(ValKind::Var(x.id), x.ty.clone())
    }

    fn int_const(n: i64) -> CoreVal {
        val(ValKind::Const(Const::Int(n)), Ty::int())
    }

    fn str_const(s: &str) -> CoreVal {
        val(ValKind::Const(Const::Str(s.to_string())), Ty::string())
    }

    fn unit_const() -> CoreVal {
        val(ValKind::Const(Const::Unit), Ty::unit())
    }

    fn builtin(id: BuiltinId, tys: Vec<Ty>) -> CoreVal {
        let ty = scheme(id).fn_ty().subst(&tys, &[]);
        val(
            ValKind::Builtin {
                id,
                tys,
                effs: Vec::new(),
            },
            ty,
        )
    }

    fn comp(kind: CompKind, ty: Ty, eff: EffectSet) -> Comp {
        Comp {
            kind,
            ty,
            eff,
            origin: sp(0),
        }
    }

    fn ret(x: CoreVal) -> Comp {
        let ty = x.ty.clone();
        comp(CompKind::Return(x), ty, EffectSet::empty())
    }

    fn app(func: CoreVal, args: Vec<CoreVal>, ty: Ty, eff: EffectSet) -> Comp {
        comp(CompKind::App { func, args }, ty, eff)
    }

    fn let_(x: Var, bound: Comp, body: Comp) -> Comp {
        let ty = body.ty.clone();
        let eff = bound.eff.union(&body.eff);
        comp(
            CompKind::Let {
                var: x,
                bound: Box::new(bound),
                body: Box::new(body),
            },
            ty,
            eff,
        )
    }

    fn lambda(params: Vec<Var>, body: Comp, ty: Ty) -> CoreVal {
        val(
            ValKind::Lambda(Box::new(Lambda {
                id: LambdaId(0),
                params,
                body,
                span: sp(0),
            })),
            ty,
        )
    }

    fn fn_ty(params: Vec<Ty>, ret: Ty, eff: EffectSet) -> Ty {
        Ty::func(params, ret, eff)
    }

    fn eff_var(i: u32) -> EffectSet {
        EffectSet {
            io: false,
            vars: vec![EffVar(i)],
        }
    }

    fn def(
        binding: u32,
        name: &str,
        (type_params, effect_params): (usize, usize),
        params: Vec<Var>,
        ret: Ty,
        eff: EffectSet,
        body: Comp,
    ) -> CoreDef {
        CoreDef {
            binding: BindingId(binding),
            name: name.to_string(),
            origin: DefOrigin::User,
            type_params: (0..type_params).map(|i| format!("T{i}")).collect(),
            effect_params: (0..effect_params).map(|i| format!("E{i}")).collect(),
            params,
            ret,
            eff,
            body,
            span: sp(0),
            var_count: 100,
        }
    }

    /// `main` を一つだけ持つ定義。宣言の戻り値の型とエフェクトは本体のものにする。
    fn main_def(params: Vec<Var>, body: Comp) -> CoreDef {
        let (ty, eff) = (body.ty.clone(), body.eff.clone());
        def(0, "main", (0, 0), params, ty, eff, body)
    }

    fn option_adt() -> AdtTable {
        AdtTable {
            adts: vec![AdtDef {
                con: TyCon::Option,
                name: "Option".to_string(),
                type_params: vec!["T".to_string()],
                ctors: vec![
                    CtorDef {
                        name: "Some".to_string(),
                        binding: BindingId(1000),
                        tag: 0,
                        fields: vec![Ty::Param(0)],
                    },
                    CtorDef {
                        name: "None".to_string(),
                        binding: BindingId(1001),
                        tag: 1,
                        fields: vec![],
                    },
                ],
                eq_summary: EqSummary {
                    always: false,
                    depends_on: vec![0],
                },
            }],
        }
    }

    fn check(defs: Vec<CoreDef>) -> Vec<CoreTypeError> {
        check_program(&Program {
            defs,
            adts: option_adt(),
            main: BindingId(0),
            main_returns_result: false,
            lambda_count: 1,
        })
    }

    #[test]
    fn polymorphic_identity_and_its_instance_check() {
        let x = var(0, Ty::Param(0));
        let id = def(
            1,
            "id",
            (1, 0),
            vec![x.clone()],
            Ty::Param(0),
            EffectSet::empty(),
            ret(v(&x)),
        );
        let id_int = val(
            ValKind::TopFn {
                def: BindingId(1),
                tys: vec![Ty::int()],
                effs: vec![],
            },
            fn_ty(vec![Ty::int()], Ty::int(), EffectSet::empty()),
        );
        let main = main_def(
            vec![],
            app(id_int, vec![int_const(1)], Ty::int(), EffectSet::empty()),
        );
        assert_eq!(check(vec![id, main]), vec![]);
    }

    #[test]
    fn higher_order_map_into_checks() {
        // fn mapInto[T, U; E](xs: List[T], f: (T) -> U ! E, acc: List[U]) : List[U] ! E
        let (t, u, e) = (Ty::Param(0), Ty::Param(1), eff_var(0));
        let xs = var(0, Ty::list(t.clone()));
        let f = var(1, fn_ty(vec![t.clone()], u.clone(), e.clone()));
        let acc = var(2, Ty::list(u.clone()));
        let h = var(3, Ty::option(t.clone()));
        let x = var(4, t.clone());
        let y = var(5, u.clone());
        let rest = var(6, Ty::list(t.clone()));
        let acc2 = var(7, Ty::list(u.clone()));
        let self_ref = val(
            ValKind::TopFn {
                def: BindingId(3),
                tys: vec![t.clone(), u.clone()],
                effs: vec![e.clone()],
            },
            fn_ty(
                vec![xs.ty.clone(), f.ty.clone(), acc.ty.clone()],
                acc.ty.clone(),
                e.clone(),
            ),
        );
        let some_arm = let_(
            y.clone(),
            app(v(&f), vec![v(&x)], u.clone(), e.clone()),
            let_(
                rest.clone(),
                app(
                    builtin(BuiltinId::ListDrop, vec![t.clone()]),
                    vec![v(&xs), int_const(1)],
                    rest.ty.clone(),
                    EffectSet::empty(),
                ),
                let_(
                    acc2.clone(),
                    app(
                        builtin(BuiltinId::ListPrepend, vec![u.clone()]),
                        vec![v(&acc), v(&y)],
                        acc2.ty.clone(),
                        EffectSet::empty(),
                    ),
                    app(
                        self_ref,
                        vec![v(&rest), v(&f), v(&acc2)],
                        acc.ty.clone(),
                        e.clone(),
                    ),
                ),
            ),
        );
        let body = let_(
            h.clone(),
            app(
                builtin(BuiltinId::ListHead, vec![t.clone()]),
                vec![v(&xs)],
                h.ty.clone(),
                EffectSet::empty(),
            ),
            comp(
                CompKind::Match {
                    scrutinee: v(&h),
                    arms: vec![
                        Arm {
                            pattern: CorePat::Ctor {
                                con: TyCon::Option,
                                tag: 1,
                                args: vec![],
                            },
                            body: ret(v(&acc)),
                        },
                        Arm {
                            pattern: CorePat::Ctor {
                                con: TyCon::Option,
                                tag: 0,
                                args: vec![CorePat::Var(x.clone())],
                            },
                            body: some_arm,
                        },
                    ],
                },
                acc.ty.clone(),
                e.clone(),
            ),
        );
        let map_into = def(
            3,
            "mapInto",
            (2, 1),
            vec![xs.clone(), f.clone(), acc.clone()],
            acc.ty.clone(),
            e,
            body,
        );
        assert_eq!(check(vec![map_into]), vec![]);
    }

    #[test]
    fn wrong_argument_type_is_reported_at_the_application() {
        let mut call = app(
            builtin(BuiltinId::IntToString, vec![]),
            vec![str_const("a")],
            Ty::string(),
            EffectSet::empty(),
        );
        call.origin = sp(7);
        let errors = check(vec![main_def(vec![], call)]);
        assert_eq!(errors.len(), 1, "{errors:?}");
        assert_eq!(errors[0].origin, sp(7));
        assert_eq!(errors[0].def, "main");
    }

    /// 型の付かない入力の表。どれも誤りが一つ以上報告される。
    #[test]
    fn ill_typed_programs_are_rejected() {
        let pure_thunk = fn_ty(vec![], Ty::unit(), EffectSet::empty());
        let io_thunk = fn_ty(vec![], Ty::unit(), EffectSet::io());
        let p = var(0, pure_thunk.clone());

        // ノードの欄の食い違い: Return(Const(Int)) の ty を String にしたもの。
        let mut mislabeled = ret(int_const(1));
        mislabeled.ty = Ty::string();

        // エフェクトが宣言を超える: 宣言が空集合の定義で ConsolePrintln を呼ぶ。
        let println = app(
            builtin(BuiltinId::ConsolePrintln, vec![]),
            vec![str_const("hi")],
            Ty::unit(),
            EffectSet::io(),
        );
        let over_effect = def(
            0,
            "main",
            (0, 0),
            vec![],
            Ty::unit(),
            EffectSet::empty(),
            println,
        );

        // 最も外側だけの包含: List[() → Unit ! {}] を List[() → Unit ! {IO}] の引数に渡す。
        let fs = var(1, Ty::list(io_thunk.clone()));
        let take = def(
            1,
            "take",
            (0, 0),
            vec![fs],
            Ty::unit(),
            EffectSet::empty(),
            ret(unit_const()),
        );
        let take_ref = val(
            ValKind::TopFn {
                def: BindingId(1),
                tys: vec![],
                effs: vec![],
            },
            fn_ty(
                vec![Ty::list(io_thunk.clone())],
                Ty::unit(),
                EffectSet::empty(),
            ),
        );
        let pure_list = val(ValKind::List(vec![]), Ty::list(pure_thunk.clone()));
        let nested = main_def(
            vec![],
            app(take_ref, vec![pure_list], Ty::unit(), EffectSet::empty()),
        );

        // 組み込みの制約: Eq を関数の型で、ListSort を Bool で使う。
        let eq_fn = main_def(
            vec![p.clone()],
            app(
                builtin(BuiltinId::Eq, vec![pure_thunk.clone()]),
                vec![v(&p), v(&p)],
                Ty::bool(),
                EffectSet::empty(),
            ),
        );
        let sort_bool = main_def(
            vec![],
            app(
                builtin(BuiltinId::ListSort, vec![Ty::bool()]),
                vec![val(ValKind::List(vec![]), Ty::list(Ty::bool()))],
                Ty::list(Ty::bool()),
                EffectSet::empty(),
            ),
        );

        // Float の定数のパターン。
        let float_pat = main_def(
            vec![],
            comp(
                CompKind::Match {
                    scrutinee: val(ValKind::Const(Const::Float(1.0)), Ty::float()),
                    arms: vec![
                        Arm {
                            pattern: CorePat::Const(Const::Float(1.0)),
                            body: ret(unit_const()),
                        },
                        Arm {
                            pattern: CorePat::Wild,
                            body: ret(unit_const()),
                        },
                    ],
                },
                Ty::unit(),
                EffectSet::empty(),
            ),
        );

        // 構成子の引数: Some[Int]("a")。
        let bad_ctor = main_def(
            vec![],
            ret(val(
                ValKind::Ctor {
                    con: TyCon::Option,
                    tag: 0,
                    tys: vec![Ty::int()],
                    args: vec![str_const("a")],
                },
                Ty::option(Ty::int()),
            )),
        );

        // 未定義の変数。
        let unbound = main_def(vec![], ret(val(ValKind::Var(VarId(99)), Ty::int())));

        let cases: Vec<(&str, Vec<CoreDef>)> = vec![
            ("node label mismatch", vec![main_def(vec![], mislabeled)]),
            ("effect exceeds declaration", vec![over_effect]),
            ("subsumption only outermost", vec![take, nested]),
            ("Eq on function type", vec![eq_fn]),
            ("sort on Bool", vec![sort_bool]),
            ("Float constant pattern", vec![float_pat]),
            ("constructor argument", vec![bad_ctor]),
            ("unbound variable", vec![unbound]),
        ];
        for (name, defs) in cases {
            assert!(!check(defs).is_empty(), "{name}: expected an error");
        }
    }

    /// 包含と制約の検査が厳しすぎないこと。
    #[test]
    fn well_typed_uses_of_subsumption_and_constraints_are_accepted() {
        // fn run(f: () → Unit ! {IO}) に純粋なラムダを渡す。
        let io_thunk = fn_ty(vec![], Ty::unit(), EffectSet::io());
        let pure_thunk = fn_ty(vec![], Ty::unit(), EffectSet::empty());
        let f = var(0, io_thunk.clone());
        let run = def(
            1,
            "run",
            (0, 0),
            vec![f.clone()],
            Ty::unit(),
            EffectSet::io(),
            app(v(&f), vec![], Ty::unit(), EffectSet::io()),
        );
        let run_ref = val(
            ValKind::TopFn {
                def: BindingId(1),
                tys: vec![],
                effs: vec![],
            },
            fn_ty(vec![io_thunk], Ty::unit(), EffectSet::io()),
        );
        let pure_lambda = lambda(vec![], ret(unit_const()), pure_thunk);
        let main = main_def(
            vec![],
            app(run_ref, vec![pure_lambda], Ty::unit(), EffectSet::io()),
        );
        assert_eq!(check(vec![run, main]), vec![]);

        // C-Sub で計算の結果の型を広げる（ADR 0081 の make と widen）。
        // make の呼び出しのノードは純粋な関数の型で、widen の宣言は IO の関数の型を返す。
        let pure_thunk2 = fn_ty(vec![], Ty::unit(), EffectSet::empty());
        let make = def(
            2,
            "make",
            (0, 0),
            vec![],
            pure_thunk2.clone(),
            EffectSet::empty(),
            ret(lambda(vec![], ret(unit_const()), pure_thunk2.clone())),
        );
        let make_ref = val(
            ValKind::TopFn {
                def: BindingId(2),
                tys: vec![],
                effs: vec![],
            },
            fn_ty(vec![], pure_thunk2.clone(), EffectSet::empty()),
        );
        let widen = def(
            3,
            "widen",
            (0, 0),
            vec![],
            fn_ty(vec![], Ty::unit(), EffectSet::io()),
            EffectSet::empty(),
            app(make_ref, vec![], pure_thunk2, EffectSet::empty()),
        );
        assert_eq!(check(vec![make, widen]), vec![]);

        // Eq を Option[Int] で、ListSort を Int で使う。
        let o = var(0, Ty::option(Ty::int()));
        let eq_opt = main_def(
            vec![o.clone()],
            app(
                builtin(BuiltinId::Eq, vec![o.ty.clone()]),
                vec![v(&o), v(&o)],
                Ty::bool(),
                EffectSet::empty(),
            ),
        );
        assert_eq!(check(vec![eq_opt]), vec![]);
        let sort_int = main_def(
            vec![],
            app(
                builtin(BuiltinId::ListSort, vec![Ty::int()]),
                vec![val(ValKind::List(vec![int_const(2)]), Ty::list(Ty::int()))],
                Ty::list(Ty::int()),
                EffectSet::empty(),
            ),
        );
        assert_eq!(check(vec![sort_int]), vec![]);
    }
}
