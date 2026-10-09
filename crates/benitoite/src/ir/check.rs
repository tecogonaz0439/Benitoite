//! コア IR の型とエフェクトを独立に検査する（設計書 01-12「型付け規則」、
//! 02-06「コア IR の検査器」）。辞書と継続は値の環境と分けて扱う。

use std::collections::BTreeMap;

use crate::base::{BindingId, NodeId, Span};
use crate::builtins::table::builtin_scheme;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeClass, BuiltinTypeId};
use crate::types::{
    BuiltinConstraint, ClassConstraint, EffectName, EffectSet, FnTy, ParamKind, Scheme, Ty, TyCon,
    TyHead, TySet, TypeArg, TypeArgs, TypeParamInfo,
};

use super::core_ir::*;

/// コア IR の検査器が見つけた、型の付かない箇所（処理系の不具合）。
#[derive(Clone, PartialEq, Debug)]
pub struct CoreTypeError {
    /// 定義の名前（`Def::name`、`ImplDef::name`、`ConstDef::name`）
    pub def: String,
    pub origin: Span,
    pub message: String,
}

/// コア IR に 01-12 の型付け規則で型が付くかを調べる（02-06「コア IR の検査器」）。テストだけで使う。
/// 型が付けば空の並びを返す。
pub fn check_program(program: &CoreProgram) -> Vec<CoreTypeError> {
    let mut checker = Checker {
        program,
        defs: program.defs.iter().map(|d| (d.binding, d)).collect(),
        impls: program.impls.iter().map(|d| (d.impl_decl, d)).collect(),
        consts: program.consts.iter().map(|d| (d.binding, d)).collect(),
        errors: Vec::new(),
        name: String::new(),
    };
    for def in &program.defs {
        checker.definition(def, None);
    }
    for def in &program.impls {
        checker.implementation(def);
    }
    for def in &program.consts {
        checker.constant_definition(def);
    }
    checker.errors
}

#[derive(Clone, Default)]
struct Env {
    vars: BTreeMap<VarId, Ty>,
    dicts: BTreeMap<VarId, ClassConstraint>,
    impl_dicts: Option<Vec<ClassConstraint>>,
    params: Vec<TypeParamInfo>,
    conts: Vec<(VarId, Ty, Ty, EffectSet)>,
    clauses: BTreeMap<NodeId, BindingId>,
    ret: Option<Ty>,
}

struct Checker<'a> {
    program: &'a CoreProgram,
    defs: BTreeMap<BindingId, &'a CoreDef>,
    impls: BTreeMap<NodeId, &'a ImplDef<Comp>>,
    consts: BTreeMap<BindingId, &'a ConstDef<Comp>>,
    errors: Vec<CoreTypeError>,
    name: String,
}

fn builtin(id: BuiltinTypeId, args: Vec<Ty>) -> Ty {
    Ty::Con(TyCon::Builtin(id), args)
}

/// V-Const の type(c)。P-Const でも定数の種類を同じ型に対応させる。
fn constant_type(c: &Const) -> Ty {
    let id = match c {
        Const::Int(_) => BuiltinTypeId::INTEGER,
        Const::Float(_) => BuiltinTypeId::FLOAT,
        Const::Str(_) => BuiltinTypeId::STRING,
        Const::Char(_) => BuiltinTypeId::CHARACTER,
        Const::Bool(_) => BuiltinTypeId::BOOLEAN,
        Const::Unit => BuiltinTypeId::UNIT,
        Const::Byte(_) => BuiltinTypeId::BYTE,
        Const::Decimal(_) => BuiltinTypeId::DECIMAL,
    };
    builtin(id, vec![])
}

/// V-Sub・C-Sub。関数の内側やコレクションの型引数には包含を適用しない。
fn accepts(actual: &Ty, expected: &Ty) -> bool {
    actual == expected
        || matches!((actual, expected), (Ty::Fn(a), Ty::Fn(b))
        if a.params == b.params && a.ret == b.ret && a.effects.is_subset(&b.effects))
}

/// V-Dict・C-Meth の同時置換。型構成子の頭も置き換える。
fn subst_arg(arg: &TypeArg, tys: &[TypeArg], effects: &[EffectSet]) -> TypeArg {
    match arg {
        TypeArg::Ty(t) => TypeArg::Ty(t.subst(tys, effects)),
        TypeArg::Head(TyHead::Con(_)) => arg.clone(),
        TypeArg::Head(TyHead::Param(i)) => at(tys, *i).cloned().unwrap_or_else(|| arg.clone()),
    }
}

fn at<T>(items: &[T], index: u32) -> Option<&T> {
    usize::try_from(index).ok().and_then(|i| items.get(i))
}

fn parameter_arg(index: u32, kind: ParamKind) -> TypeArg {
    match kind {
        ParamKind::Value => TypeArg::Ty(Ty::Param(index)),
        ParamKind::Ctor { .. } => TypeArg::Head(TyHead::Param(index)),
    }
}

impl Checker<'_> {
    fn error(&mut self, origin: Span, message: impl Into<String>) {
        self.errors.push(CoreTypeError {
            def: self.name.clone(),
            origin,
            message: message.into(),
        });
    }

    fn equal(&mut self, origin: Span, actual: &Ty, expected: &Ty) {
        if actual != expected {
            self.error(origin, format!("expected {expected:?}, found {actual:?}"));
        }
    }

    /// V-Sub・C-Sub を許す値と計算の結果の位置。
    fn flow(&mut self, origin: Span, actual: &Ty, expected: &Ty) {
        if !accepts(actual, expected) {
            self.error(
                origin,
                format!("expected a type accepted by {expected:?}, found {actual:?}"),
            );
        }
    }

    fn effects(&mut self, origin: Span, actual: &EffectSet, expected: &EffectSet) {
        if !actual.is_subset(expected) {
            self.error(
                origin,
                format!("expected effects within {expected:?}, found {actual:?}"),
            );
        }
    }

    fn count(&mut self, origin: Span, label: &str, actual: usize, expected: usize) {
        if actual != expected {
            self.error(
                origin,
                format!("expected {expected} {label}, found {actual}"),
            );
        }
    }

    /// 定義・D-Impl の本体。実装の制約はメソッド自身の辞書と区別する。
    fn definition(&mut self, def: &CoreDef, implementation: Option<&ImplDef<Comp>>) {
        self.name.clone_from(&def.name);
        let mut env = Env {
            ret: Some(def.ret.clone()),
            ..Env::default()
        };
        match self.program.schemes.get(def.binding) {
            Some(scheme) => {
                env.params.clone_from(&scheme.type_params);
                self.equal(
                    def.span,
                    &Ty::Fn(Box::new(FnTy {
                        params: def.params.iter().map(|v| v.ty.clone()).collect(),
                        ret: def.ret.clone(),
                        effects: def.eff.clone(),
                    })),
                    &scheme.fn_ty(),
                );
                self.count(
                    def.span,
                    "type parameters",
                    def.type_params.len(),
                    scheme.type_params.len(),
                );
                self.count(
                    def.span,
                    "effect parameters",
                    def.effect_params.len(),
                    scheme.effect_params.len(),
                );
                let skip = implementation.map_or(0, |i| i.dict_params.len());
                let expected = scheme.class_constraints.get(skip..).unwrap_or(&[]);
                if def
                    .dict_params
                    .iter()
                    .map(|d| d.constraint)
                    .collect::<Vec<_>>()
                    != expected
                {
                    self.error(
                        def.span,
                        "dictionary parameters differ from the declaration",
                    );
                }
            }
            None => self.error(def.span, "missing declaration scheme"),
        }
        if let Some(i) = implementation {
            env.impl_dicts = Some(i.dict_params.clone());
        }
        for p in &def.params {
            env.vars.insert(p.id, p.ty.clone());
        }
        for p in &def.dict_params {
            env.dicts.insert(p.var, p.constraint);
        }
        self.computation(&def.body, &env);
        self.flow(def.body.origin, &def.body.ty, &def.ret);
        self.effects(def.body.origin, &def.body.eff, &def.eff);
    }

    /// 定数の定義：空の環境、R なし、空のエフェクト。
    fn constant_definition(&mut self, def: &ConstDef<Comp>) {
        self.name.clone_from(&def.name);
        self.computation(&def.body, &Env::default());
        self.flow(def.body.origin, &def.body.ty, &def.ty);
        self.effects(def.body.origin, &def.body.eff, &EffectSet::empty());
    }

    /// V-Fun・V-Prim（操作を含む）。引数の数、カインド、組み込みの制約を検査する。
    fn instantiate(&mut self, scheme: &Scheme, targs: &TypeArgs, env: &Env, origin: Span) -> Ty {
        self.count(
            origin,
            "type arguments",
            targs.tys.len(),
            scheme.type_params.len(),
        );
        self.count(
            origin,
            "effect arguments",
            targs.effects.len(),
            scheme.effect_params.len(),
        );
        self.type_arguments(&scheme.type_params, &targs.tys, env, origin);
        scheme.fn_ty().subst(&targs.tys, &targs.effects)
    }

    /// V-Fun・V-Prim・V-Dict・C-Meth の型引数のカインドと組み込みの制約。
    fn type_arguments(
        &mut self,
        params: &[TypeParamInfo],
        args: &[TypeArg],
        env: &Env,
        origin: Span,
    ) {
        for (param, arg) in params.iter().zip(args) {
            self.kind(arg, param.kind, env, origin);
            if let Some(constraint) = param.builtin {
                let valid = match arg {
                    TypeArg::Ty(t) => self.satisfies(t, constraint, env),
                    TypeArg::Head(_) => false,
                };
                if !valid {
                    self.error(
                        origin,
                        format!("type argument {arg:?} does not satisfy {constraint:?}"),
                    );
                }
            }
        }
    }

    fn kind(&mut self, arg: &TypeArg, expected: ParamKind, env: &Env, origin: Span) {
        let actual = match arg {
            TypeArg::Ty(_) => Some(ParamKind::Value),
            TypeArg::Head(TyHead::Param(i)) => at(&env.params, *i).map(|p| p.kind),
            TypeArg::Head(TyHead::Con(TyCon::Builtin(b))) => b.def().map(|d| ParamKind::Ctor {
                arity: u32::from(d.arity),
            }),
            TypeArg::Head(TyHead::Con(TyCon::Adt(a))) => self
                .program
                .adts
                .get(*a)
                .and_then(|d| u32::try_from(d.type_params.len()).ok())
                .map(|arity| ParamKind::Ctor { arity }),
        };
        if actual != Some(expected) {
            self.error(
                origin,
                format!("expected kind {expected:?}, found {actual:?} for {arg:?}"),
            );
        }
    }

    /// V-Prim・V-Fun の equality・key・ordered。ADT は宣言の要約で判定する。
    fn satisfies(&self, ty: &Ty, constraint: BuiltinConstraint, env: &Env) -> bool {
        if constraint == BuiltinConstraint::Ordered {
            return matches!(ty, Ty::Con(TyCon::Builtin(b), args) if args.is_empty() && TySet::ORD.contains(*b));
        }
        match ty {
            Ty::Fn(_) | Ty::App(_, _) => false,
            Ty::Param(i) => at(&env.params, *i)
                .and_then(|p| p.builtin)
                .is_some_and(|c| c == BuiltinConstraint::Key || c == constraint),
            Ty::Rigid { clause, index } => env
                .clauses
                .get(clause)
                .and_then(|op| self.program.schemes.get(*op))
                .and_then(|s| at(&s.type_params, *index))
                .and_then(|p| p.builtin)
                .is_some_and(|c| c == BuiltinConstraint::Key || c == constraint),
            Ty::Con(TyCon::Builtin(b), args) => match b.def() {
                Some(d) if usize::from(d.arity) == args.len() => match d.class {
                    BuiltinTypeClass::Basic => {
                        constraint != BuiltinConstraint::Key || *b != BuiltinTypeId::FLOAT
                    }
                    BuiltinTypeClass::Collection => {
                        args.iter().all(|t| self.satisfies(t, constraint, env))
                    }
                    BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource => false,
                },
                Some(_) | None => false,
            },
            Ty::Con(TyCon::Adt(a), args) => self.program.adts.get(*a).is_some_and(|d| {
                let allowed = |summary: &crate::types::TypeSummary, c| {
                    !summary.always
                        && summary
                            .depends_on
                            .iter()
                            .all(|i| at(args, *i).is_some_and(|t| self.satisfies(t, c, env)))
                };
                args.len() == d.type_params.len()
                    && allowed(&d.eq_summary, BuiltinConstraint::Equality)
                    && (constraint != BuiltinConstraint::Key
                        || allowed(&d.key_summary, BuiltinConstraint::Key))
            }),
        }
    }

    /// V-Var・V-Const・V-Fun・V-Prim・V-Lam・V-Con・V-List・定数の参照。
    fn value(&mut self, val: &CoreVal, env: &Env) {
        self.rigid_scope(&val.ty, env, val.origin);
        let derived = match &val.kind {
            ValKind::Var(v) => match env.vars.get(v) {
                Some(t) => Some(t.clone()),
                None => {
                    self.error(val.origin, format!("unbound value variable {v:?}"));
                    None
                }
            },
            ValKind::Const(c) => Some(constant_type(c)),
            ValKind::TopFn { def, targs } => {
                if !self.defs.contains_key(def) {
                    self.error(val.origin, "unknown top-level function");
                    None
                } else if let Some(scheme) = self.program.schemes.get(*def) {
                    Some(self.instantiate(scheme, targs, env, val.origin))
                } else {
                    self.error(val.origin, "missing function scheme");
                    None
                }
            }
            ValKind::Builtin { id, targs, info } => {
                let scheme = match info.decl {
                    Some(decl) => self.program.schemes.get(decl).cloned(),
                    None => builtin_scheme(*id),
                };
                match scheme {
                    Some(s) => Some(self.instantiate(&s, targs, env, val.origin)),
                    None => {
                        self.error(val.origin, "missing builtin scheme");
                        None
                    }
                }
            }
            ValKind::Op { op, targs } => match self.program.schemes.get(*op) {
                Some(s) => Some(self.instantiate(s, targs, env, val.origin)),
                None => {
                    self.error(val.origin, "missing operation scheme");
                    None
                }
            },
            ValKind::Lambda(lam) => Some(self.lambda(lam, &val.ty, env)),
            ValKind::Ctor {
                adt,
                tag,
                tys,
                args,
            } => {
                let fields = self.program.adts.field_types(*adt, *tag, tys);
                self.arguments(args, fields.as_deref(), env, val.origin);
                if fields.is_none() {
                    self.error(
                        val.origin,
                        "unknown constructor or incorrect type argument count",
                    );
                }
                Some(Ty::Con(TyCon::Adt(*adt), tys.clone()))
            }
            ValKind::List(items) => {
                self.list(items, &val.ty, env, val.origin);
                None
            }
            ValKind::ConstRef(k) => match self.consts.get(k) {
                Some(d) => Some(d.ty.clone()),
                None => {
                    self.error(val.origin, "unknown constant");
                    None
                }
            },
        };
        if let Some(ty) = derived {
            self.equal(val.origin, &val.ty, &ty);
        }
    }

    /// C-Handle の剛体型は、見えている節の操作の型パラメータだけを指す。
    fn rigid_scope(&mut self, ty: &Ty, env: &Env, origin: Span) {
        match ty {
            Ty::Rigid { clause, index } => {
                if env
                    .clauses
                    .get(clause)
                    .and_then(|op| self.program.schemes.get(*op))
                    .and_then(|s| at(&s.type_params, *index))
                    .is_none()
                {
                    self.error(
                        origin,
                        format!("rigid parameter {ty:?} does not belong to a visible clause"),
                    );
                }
            }
            Ty::Con(_, args) | Ty::App(_, args) => {
                for t in args {
                    self.rigid_scope(t, env, origin);
                }
            }
            Ty::Fn(f) => {
                for t in &f.params {
                    self.rigid_scope(t, env, origin);
                }
                self.rigid_scope(&f.ret, env, origin);
            }
            Ty::Param(_) => {}
        }
    }

    /// V-Lam。継続を除き、本体の結果を新しい R にする。
    fn lambda(&mut self, lambda: &Lambda<Comp>, ty: &Ty, env: &Env) -> Ty {
        let mut inner = env.clone();
        inner.conts.clear();
        inner.ret = Some(lambda.body.ty.clone());
        for p in &lambda.params {
            inner.vars.insert(p.id, p.ty.clone());
        }
        self.computation(&lambda.body, &inner);
        // uses の注釈は、本体が使わないエフェクトも含んでよい
        // （設計書 02-06「コア IR の検査器」、実装プラン F11「F13 の検査器のラムダの検査」）。
        let effects = match ty {
            Ty::Fn(f) => {
                self.effects(lambda.body.origin, &lambda.body.eff, &f.effects);
                f.effects.clone()
            }
            Ty::Con(_, _) | Ty::Param(_) | Ty::App(_, _) | Ty::Rigid { .. } => {
                lambda.body.eff.clone()
            }
        };
        Ty::Fn(Box::new(FnTy {
            params: lambda.params.iter().map(|p| p.ty.clone()).collect(),
            ret: lambda.body.ty.clone(),
            effects,
        }))
    }

    /// V-List。要素の型の最も外側が関数である場合にだけ V-Sub を使う。
    fn list(&mut self, items: &[CoreVal], ty: &Ty, env: &Env, origin: Span) {
        let element = match ty {
            Ty::Con(TyCon::Builtin(b), args) if *b == BuiltinTypeId::LIST && args.len() == 1 => {
                args.first()
            }
            Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => None,
        };
        if element.is_none() {
            self.error(origin, "expected List with one type argument");
        }
        for v in items {
            self.value(v, env);
            if let Some(t) = element {
                self.flow(v.origin, &v.ty, t);
            }
        }
    }

    /// C-App・C-Meth・V-Con の値の引数。誤りの後もすべての引数を検査する。
    fn arguments(&mut self, args: &[CoreVal], expected: Option<&[Ty]>, env: &Env, origin: Span) {
        if let Some(types) = expected {
            self.count(origin, "value arguments", args.len(), types.len());
        }
        for (i, v) in args.iter().enumerate() {
            self.value(v, env);
            if let Some(t) = expected.and_then(|ts| ts.get(i)) {
                self.flow(v.origin, &v.ty, t);
            }
        }
    }

    /// 計算の規則の振り分け。再帰の段ごとに各規則の作業領域を保持しないよう、
    /// 型とエフェクトの検査は規則ごとの関数で行う（実装プラン F13「受け入れテスト」）。
    fn computation(&mut self, comp: &Comp, env: &Env) {
        match &comp.kind {
            CompKind::Return(v) => self.return_comp(v, comp, env),
            CompKind::Let { var, bound, body } => self.let_comp(var, bound, body, comp, env),
            CompKind::App { func, dicts, args } => self.app_comp(func, dicts, args, comp, env),
            CompKind::Method(call) => self.method_comp(call, comp, env),
            CompKind::If {
                cond,
                then_branch,
                else_branch,
            } => self.if_comp(cond, then_branch, else_branch, comp, env),
            CompKind::Match {
                scrutinee,
                rows,
                arms,
            } => self.match_comp(scrutinee, rows, arms, comp, env),
            CompKind::Escape(v) => self.escape_comp(v, comp, env),
            CompKind::Use { resource, body } => self.use_comp(resource, body, comp, env),
            CompKind::Lazy { body, .. } => self.lazy(body, comp, env),
            CompKind::Handle(handle) => self.handle(handle, comp, env),
            CompKind::Resume { cont, value } => self.resume(*cont, value, comp, env),
        }
    }

    /// C-Return。値の型は一致し、導くエフェクトは空集合である。
    fn return_comp(&mut self, value: &CoreVal, comp: &Comp, env: &Env) {
        self.value(value, env);
        self.equal(comp.origin, &comp.ty, &value.ty);
        self.effects(comp.origin, &EffectSet::empty(), &comp.eff);
    }

    /// C-If。条件は Boolean と一致し、分岐の結果には C-Sub を許す。
    fn if_comp(
        &mut self,
        cond: &CoreVal,
        then_branch: &Comp,
        else_branch: &Comp,
        comp: &Comp,
        env: &Env,
    ) {
        self.value(cond, env);
        self.equal(
            cond.origin,
            &cond.ty,
            &builtin(BuiltinTypeId::BOOLEAN, vec![]),
        );
        for branch in [then_branch, else_branch] {
            self.computation(branch, env);
            self.flow(branch.origin, &branch.ty, &comp.ty);
        }
        self.effects(
            comp.origin,
            &then_branch.eff.union(&else_branch.eff),
            &comp.eff,
        );
    }

    /// C-App の結果。ノード自身の結果の型には包含を使わない。
    fn app_comp(
        &mut self,
        func: &CoreVal,
        dicts: &[DictVal],
        args: &[CoreVal],
        comp: &Comp,
        env: &Env,
    ) {
        if let Some((ty, eff)) = self.application(func, dicts, args, env, comp.origin) {
            self.equal(comp.origin, &comp.ty, &ty);
            self.effects(comp.origin, &eff, &comp.eff);
        }
    }

    /// C-Meth の結果の型とエフェクト。
    fn method_comp(&mut self, call: &MethodCall<Comp>, comp: &Comp, env: &Env) {
        if let Some((ty, eff)) = self.method(call, env, comp.origin) {
            self.equal(comp.origin, &comp.ty, &ty);
            self.effects(comp.origin, &eff, &comp.eff);
        }
    }

    /// escape の結果の型は任意であり、導くエフェクトは空集合である。
    fn escape_comp(&mut self, value: &CoreVal, comp: &Comp, env: &Env) {
        self.escape(value, env);
        self.effects(comp.origin, &EffectSet::empty(), &comp.eff);
    }

    /// C-Let。右辺だけは束縛前の環境で検査する。
    fn let_comp(&mut self, var: &Var, bound: &Comp, body: &Comp, comp: &Comp, env: &Env) {
        self.computation(bound, env);
        self.flow(bound.origin, &bound.ty, &var.ty);
        let mut inner = env.clone();
        inner.vars.insert(var.id, var.ty.clone());
        self.computation(body, &inner);
        self.equal(comp.origin, &comp.ty, &body.ty);
        self.effects(comp.origin, &bound.eff.union(&body.eff), &comp.eff);
    }

    /// C-App。辞書は TopFn の宣言の制約にだけ対応する。
    fn application(
        &mut self,
        func: &CoreVal,
        dicts: &[DictVal],
        args: &[CoreVal],
        env: &Env,
        origin: Span,
    ) -> Option<(Ty, EffectSet)> {
        self.value(func, env);
        let expected = if let ValKind::TopFn { def, targs } = &func.kind {
            self.program
                .schemes
                .get(*def)
                .map(|s| (s.class_constraints.as_slice(), targs.tys.as_slice()))
        } else {
            None
        };
        self.dictionary_arguments(dicts, expected, env, origin);
        match &func.ty {
            Ty::Fn(f) => {
                self.arguments(args, Some(&f.params), env, origin);
                Some((f.ret.clone(), f.effects.clone()))
            }
            Ty::Con(..) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
                self.arguments(args, None, env, origin);
                self.error(func.origin, "application requires a function");
                None
            }
        }
    }

    /// escape の判断 Γ; R。R なしの区間からは脱出できない。
    fn escape(&mut self, value: &CoreVal, env: &Env) {
        self.value(value, env);
        match &env.ret {
            Some(ret) => self.flow(value.origin, &value.ty, ret),
            None => self.error(value.origin, "escape outside a function boundary"),
        }
    }

    /// C-Use。リソースの表を引き、解放の State を導く。
    fn use_comp(&mut self, resource: &CoreVal, body: &Comp, comp: &Comp, env: &Env) {
        self.value(resource, env);
        if !matches!(&resource.ty, Ty::Con(TyCon::Builtin(b), args)
            if b.def().is_some_and(|d| d.class == BuiltinTypeClass::Resource && usize::from(d.arity) == args.len()))
        {
            self.error(resource.origin, "use requires a resource type");
        }
        self.computation(body, env);
        let mut eff = body.eff.clone();
        eff.insert_name(EffectName::Builtin(BuiltinEffectId::STATE));
        self.equal(comp.origin, &comp.ty, &body.ty);
        self.effects(comp.origin, &eff, &comp.eff);
    }

    /// lazy M の規則。継続と R を除き、本体の純粋性を検査する。
    fn lazy(&mut self, body: &Comp, comp: &Comp, env: &Env) {
        let mut inner = env.clone();
        inner.conts.clear();
        inner.ret = None;
        self.computation(body, &inner);
        self.effects(body.origin, &body.eff, &EffectSet::empty());
        self.equal(
            comp.origin,
            &comp.ty,
            &builtin(BuiltinTypeId::LAZY, vec![body.ty.clone()]),
        );
        self.effects(comp.origin, &EffectSet::empty(), &comp.eff);
    }

    /// V-Dict・V-Super・辞書の引数の V-Var。辞書の型には包含を使わない。
    fn dictionary(&mut self, dict: &DictVal, env: &Env) {
        let derived = match &dict.kind {
            DictKind::Impl {
                impl_decl,
                tys,
                args,
            } => {
                let def = self.impls.get(impl_decl).copied();
                match def {
                    Some(i) => {
                        self.count(
                            dict.origin,
                            "implementation type arguments",
                            tys.len(),
                            i.type_params.len(),
                        );
                        // 実装の β の制約は、ImplFn の Scheme の先頭 k 個にも残る
                        // （設計書 01-12「型クラス」、実装プラン 10-05「型パラメータの番号」）。
                        if let Some(s) = i
                            .methods
                            .iter()
                            .find_map(|m| self.program.schemes.get(m.binding))
                        {
                            self.type_arguments(
                                s.type_params.get(..i.type_params.len()).unwrap_or(&[]),
                                tys,
                                env,
                                dict.origin,
                            );
                        }
                        self.dictionary_arguments(
                            args,
                            Some((&i.dict_params, tys)),
                            env,
                            dict.origin,
                        );
                        Some((i.class, subst_arg(&i.target, tys, &[])))
                    }
                    None => {
                        for d in args {
                            self.dictionary(d, env);
                        }
                        self.error(dict.origin, "unknown implementation");
                        None
                    }
                }
            }
            DictKind::Super { of, index } => {
                self.dictionary(of, env);
                match self
                    .program
                    .traits
                    .get(of.class)
                    .and_then(|t| at(&t.supers, *index))
                {
                    Some(class) => Some((*class, of.arg.clone())),
                    None => {
                        self.error(
                            dict.origin,
                            "unknown supertrait or supertrait index out of range",
                        );
                        None
                    }
                }
            }
            DictKind::Param(var) => match env.dicts.get(var) {
                Some(c) => self.constraint_type(*c, env, dict.origin),
                None => {
                    self.error(dict.origin, "unbound dictionary parameter");
                    None
                }
            },
            DictKind::ImplParam(index) => {
                match env.impl_dicts.as_ref().and_then(|cs| at(cs, *index)) {
                    Some(c) => self.constraint_type(*c, env, dict.origin),
                    None => {
                        self.error(
                            dict.origin,
                            "implementation dictionary parameter outside its scope or out of range",
                        );
                        None
                    }
                }
            }
        };
        if let Some((class, arg)) = derived {
            self.dictionary_type(dict, class, &arg);
        }
    }

    fn dictionary_type(&mut self, dict: &DictVal, class: BindingId, arg: &TypeArg) {
        if dict.class != class || dict.arg != *arg {
            self.error(
                dict.origin,
                format!(
                    "expected Dict[{class:?}, {arg:?}], found Dict[{:?}, {:?}]",
                    dict.class, dict.arg
                ),
            );
        }
    }

    /// 辞書の V-Var。宣言のカインドに従って α または型構成子 α を作る。
    fn constraint_type(
        &mut self,
        c: ClassConstraint,
        env: &Env,
        origin: Span,
    ) -> Option<(BindingId, TypeArg)> {
        match at(&env.params, c.param) {
            Some(p) => Some((c.class, parameter_arg(c.param, p.kind))),
            None => {
                self.error(origin, "constraint parameter out of range");
                None
            }
        }
    }

    /// C-App・C-Meth・V-Dict の辞書の引数。
    fn dictionary_arguments(
        &mut self,
        dicts: &[DictVal],
        expected: Option<(&[ClassConstraint], &[TypeArg])>,
        env: &Env,
        origin: Span,
    ) {
        self.count(
            origin,
            "dictionary arguments",
            dicts.len(),
            expected.map_or(0, |(cs, _)| cs.len()),
        );
        for (i, d) in dicts.iter().enumerate() {
            self.dictionary(d, env);
            if let Some((c, arg)) = expected
                .and_then(|(cs, ts)| cs.get(i).and_then(|c| at(ts, c.param).map(|t| (c, t))))
            {
                self.dictionary_type(d, c.class, arg);
            }
        }
    }

    /// C-Meth。0 番の型引数と制約を呼び出しの辞書に対応させる。
    fn method(
        &mut self,
        call: &MethodCall<Comp>,
        env: &Env,
        origin: Span,
    ) -> Option<(Ty, EffectSet)> {
        self.dictionary(&call.dict, env);
        let scheme = self
            .program
            .traits
            .get(call.dict.class)
            .and_then(|t| at(&t.methods, call.method))
            .and_then(|m| self.program.schemes.get(*m));
        let Some(s) = scheme else {
            self.error(origin, "unknown method or missing method scheme");
            self.dictionary_arguments(&call.dicts, None, env, origin);
            self.arguments(&call.args, None, env, origin);
            return None;
        };
        let mut targs = call.targs.clone();
        targs.tys.insert(0, call.dict.arg.clone());
        let ty = self.instantiate(s, &targs, env, origin);
        self.dictionary_arguments(
            &call.dicts,
            Some((s.class_constraints.get(1..).unwrap_or(&[]), &targs.tys)),
            env,
            origin,
        );
        match ty {
            Ty::Fn(f) => {
                self.arguments(&call.args, Some(&f.params), env, origin);
                Some((f.ret, f.effects))
            }
            Ty::Con(..) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => None,
        }
    }

    /// D-Impl。上位の辞書、メソッドの順、宣言から置換した契約を検査する。
    fn implementation(&mut self, def: &ImplDef<Comp>) {
        self.name.clone_from(&def.name);
        let mut env = Env {
            impl_dicts: Some(def.dict_params.clone()),
            ..Env::default()
        };
        // 頭部には Scheme がない。メソッドの Scheme の先頭 k 個が頭部の宣言の写しである
        // （実装プラン 10-05「型パラメータの番号」）。メソッドがない不正な IR でも上位の辞書は調べる。
        if let Some(s) = def
            .methods
            .iter()
            .find_map(|m| self.program.schemes.get(m.binding))
        {
            env.params = s
                .type_params
                .iter()
                .take(def.type_params.len())
                .cloned()
                .collect();
        } else {
            env.params = def
                .type_params
                .iter()
                .map(|name| TypeParamInfo {
                    name: name.clone(),
                    kind: ParamKind::Value,
                    builtin: None,
                })
                .collect();
        }
        let trait_def = self.program.traits.get(def.class);
        if let Some(t) = trait_def {
            self.kind(&def.target, t.param_kind, &env, def.span);
            self.count(
                def.span,
                "supertrait dictionaries",
                def.supers.len(),
                t.supers.len(),
            );
            self.count(
                def.span,
                "method definitions",
                def.methods.len(),
                t.methods.len(),
            );
        } else {
            self.error(def.span, "unknown implementation class");
        }
        for (j, d) in def.supers.iter().enumerate() {
            self.dictionary(d, &env);
            if let Some(class) = trait_def.and_then(|t| t.supers.get(j)) {
                self.dictionary_type(d, *class, &def.target);
            }
        }
        for (j, method) in def.methods.iter().enumerate() {
            // 型クラスの γ の番号を実装の β の後へ移す。同時置換なので対象 τ の β は移らない。
            if let Some(s) = trait_def
                .and_then(|t| t.methods.get(j))
                .and_then(|m| self.program.schemes.get(*m))
            {
                let mut tys = vec![def.target.clone()];
                for (offset, p) in s.type_params.iter().skip(1).enumerate() {
                    if let Some(index) = def
                        .type_params
                        .len()
                        .checked_add(offset)
                        .and_then(|n| u32::try_from(n).ok())
                    {
                        tys.push(parameter_arg(index, p.kind));
                    } else {
                        self.error(method.span, "method type parameter index overflow");
                    }
                }
                let expected = s.fn_ty().subst(&tys, &[]);
                if let Ty::Fn(f) = expected {
                    let actual_params: Vec<_> =
                        method.params.iter().map(|p| p.ty.clone()).collect();
                    if actual_params != f.params
                        || method.ret != f.ret
                        || !method.eff.is_subset(&f.effects)
                    {
                        self.error(
                            method.span,
                            format!("implementation method differs from trait contract {f:?}"),
                        );
                    }
                }
                self.count(
                    method.span,
                    "method type parameters",
                    method.type_params.len(),
                    def.type_params
                        .len()
                        .saturating_add(s.type_params.len().saturating_sub(1)),
                );
                self.count(
                    method.span,
                    "method effect parameters",
                    method.effect_params.len(),
                    s.effect_params.len(),
                );
                let expected_constraints: Vec<_> =
                    s.class_constraints
                        .iter()
                        .skip(1)
                        .filter_map(|c| match at(&tys, c.param) {
                            Some(TypeArg::Ty(Ty::Param(p)))
                            | Some(TypeArg::Head(TyHead::Param(p))) => Some(ClassConstraint {
                                param: *p,
                                class: c.class,
                            }),
                            _ => None,
                        })
                        .collect();
                if method
                    .dict_params
                    .iter()
                    .map(|d| d.constraint)
                    .collect::<Vec<_>>()
                    != expected_constraints
                {
                    self.error(
                        method.span,
                        "implementation method dictionary constraints differ from trait contract",
                    );
                }
            } else {
                self.error(method.span, "missing trait method declaration");
            }
            if method.kind
                != (DefKind::Method {
                    impl_decl: def.impl_decl,
                    index: u32::try_from(j).unwrap_or(u32::MAX),
                })
            {
                self.error(
                    method.span,
                    "implementation methods are not in trait declaration order",
                );
            }
            self.definition(method, Some(def));
            self.name.clone_from(&def.name);
        }
    }

    /// C-Handle。完全に処理するエフェクトだけを handled(H) に含める。
    fn handle(&mut self, handle: &Handle<Comp>, comp: &Comp, env: &Env) {
        self.computation(&handle.body, env);
        self.flow(handle.body.origin, &handle.body.ty, &comp.ty);
        self.effects(
            handle.body.origin,
            &handle.body.eff,
            &comp.eff.union(&handle.handled),
        );
        let mut handled = EffectSet::empty();
        for op in &self.program.ops {
            if op.effect != EffectName::Builtin(BuiltinEffectId::STATE)
                && self
                    .program
                    .ops
                    .iter()
                    .filter(|o| o.effect == op.effect)
                    .all(|o| handle.clauses.iter().any(|c| c.op == o.binding))
            {
                handled.insert_name(op.effect);
            }
        }
        if handled != handle.handled {
            self.error(
                comp.origin,
                format!(
                    "expected handled effects {handled:?}, found {:?}",
                    handle.handled
                ),
            );
        }
        for clause in &handle.clauses {
            self.clause(clause, comp, env);
        }
    }

    /// C-Handle の節。操作の型引数は節のノード番号で区別する剛体型である。
    fn clause(&mut self, clause: &Clause<Comp>, comp: &Comp, env: &Env) {
        let mut inner = env.clone();
        inner.clauses.insert(clause.node, clause.op);
        if let Some(s) = self.program.schemes.get(clause.op) {
            let tys: Vec<_> = s
                .type_params
                .iter()
                .enumerate()
                .filter_map(|(i, _)| {
                    u32::try_from(i).ok().map(|index| {
                        TypeArg::Ty(Ty::Rigid {
                            clause: clause.node,
                            index,
                        })
                    })
                })
                .collect();
            let expected = s.fn_ty().subst(&tys, &[]);
            if let Ty::Fn(f) = expected {
                self.count(
                    clause.span,
                    "clause parameters",
                    clause.params.len(),
                    f.params.len(),
                );
                for (p, t) in clause.params.iter().zip(&f.params) {
                    self.equal(clause.span, &p.ty, t);
                }
                self.equal(clause.span, &clause.cont.arg, &f.ret);
            }
        } else {
            self.error(clause.span, "missing clause operation scheme");
        }
        for p in &clause.params {
            inner.vars.insert(p.id, p.ty.clone());
        }
        inner.conts.push((
            clause.cont.id,
            clause.cont.arg.clone(),
            comp.ty.clone(),
            comp.eff.clone(),
        ));
        self.computation(&clause.body, &inner);
        self.flow(clause.body.origin, &clause.body.ty, &comp.ty);
        self.effects(clause.body.origin, &clause.body.eff, &comp.eff);
    }

    /// C-Resume。継続の結果の型とエフェクトは一致を求める。
    fn resume(&mut self, cont: VarId, value: &CoreVal, comp: &Comp, env: &Env) {
        self.value(value, env);
        match env.conts.iter().rev().find(|(v, _, _, _)| *v == cont) {
            Some((_, arg, ret, eff)) => {
                self.flow(value.origin, &value.ty, arg);
                self.equal(comp.origin, &comp.ty, ret);
                if comp.eff != *eff {
                    self.error(
                        comp.origin,
                        format!("resume requires effects {eff:?}, found {:?}", comp.eff),
                    );
                }
            }
            None => self.error(comp.origin, "continuation is not visible in this scope"),
        }
    }

    /// C-Match。各行の束縛と分岐の変数が一致すること、ガードの純粋性を検査する。
    fn match_comp(
        &mut self,
        value: &CoreVal,
        rows: &[MatchRow],
        arms: &[MatchArm],
        comp: &Comp,
        env: &Env,
    ) {
        self.value(value, env);
        for row in rows {
            let Some(arm) = at(arms, row.arm) else {
                self.error(comp.origin, "match arm index out of range");
                continue;
            };
            let mut vars = BTreeMap::new();
            let before = self.errors.len();
            self.pattern(&row.pattern, &value.ty, &mut vars, comp.origin);
            let expected: BTreeMap<_, _> = arm.vars.iter().map(|v| (v.id, v.ty.clone())).collect();
            // パターンの誤りから派生する束縛の不一致は重ねず、別の行の検査は続ける。
            if self.errors.len() == before && (vars != expected || expected.len() != arm.vars.len())
            {
                self.error(
                    comp.origin,
                    "pattern bindings differ from match arm variables",
                );
            }
        }
        let mut effects = EffectSet::empty();
        for arm in arms {
            let mut inner = env.clone();
            for p in &arm.vars {
                inner.vars.insert(p.id, p.ty.clone());
            }
            if let Some(guard) = &arm.guard {
                self.computation(guard, &inner);
                self.equal(
                    guard.origin,
                    &guard.ty,
                    &builtin(BuiltinTypeId::BOOLEAN, vec![]),
                );
                self.effects(guard.origin, &guard.eff, &EffectSet::empty());
                effects = effects.union(&guard.eff);
            }
            self.computation(&arm.body, &inner);
            self.flow(arm.body.origin, &arm.body.ty, &comp.ty);
            effects = effects.union(&arm.body.eff);
        }
        self.effects(comp.origin, &effects, &comp.eff);
    }

    /// P-Wild・P-Var・P-Const・P-Con と範囲・リストのパターン。
    fn pattern(&mut self, pat: &CorePat, ty: &Ty, vars: &mut BTreeMap<VarId, Ty>, origin: Span) {
        match pat {
            CorePat::Wild => {}
            CorePat::Var(v) => self.pattern_var(*v, ty, vars, origin),
            CorePat::Const(c) => {
                if matches!(c, Const::Float(_) | Const::Byte(_) | Const::Decimal(_)) {
                    self.error(origin, "constant type is not permitted in a pattern");
                } else {
                    self.equal(origin, ty, &constant_type(c));
                }
            }
            CorePat::Ctor { adt, tag, args } => match ty {
                Ty::Con(TyCon::Adt(a), tys) if a == adt => {
                    match self.program.adts.field_types(*adt, *tag, tys) {
                        Some(fields) => {
                            self.count(origin, "constructor patterns", args.len(), fields.len());
                            for (p, t) in args.iter().zip(&fields) {
                                self.pattern(p, t, vars, origin);
                            }
                        }
                        None => self.error(origin, "unknown pattern constructor"),
                    }
                }
                Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
                    self.error(origin, "constructor pattern does not match scrutinee type")
                }
            },
            CorePat::Range { lo, hi } => {
                if !matches!(
                    (lo, hi),
                    (Const::Int(_), Const::Int(_)) | (Const::Char(_), Const::Char(_))
                ) {
                    self.error(
                        origin,
                        "range endpoints must both be Integer or both be Character",
                    );
                } else {
                    self.equal(origin, ty, &constant_type(lo));
                }
            }
            CorePat::List {
                before,
                rest,
                after,
            } => match ty {
                Ty::Con(TyCon::Builtin(b), args)
                    if *b == BuiltinTypeId::LIST && args.len() == 1 =>
                {
                    if let Some(t) = args.first() {
                        for p in before.iter().chain(after) {
                            self.pattern(p, t, vars, origin);
                        }
                    }
                    if let Some(v) = rest.as_ref().and_then(|r| r.var) {
                        self.pattern_var(v, ty, vars, origin);
                    }
                }
                Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
                    self.error(origin, "list pattern requires List with one type argument")
                }
            },
        }
    }

    /// P-Var・P-Con の束縛の一意性。
    fn pattern_var(&mut self, var: VarId, ty: &Ty, vars: &mut BTreeMap<VarId, Ty>, origin: Span) {
        if vars.insert(var, ty.clone()).is_some() {
            self.error(origin, "variable bound twice in one pattern");
        }
    }
}

#[cfg(test)]
mod tests {
    // check_program の出力を境界に、各規則の受理と一か所の破損の拒否を対にする。
    // 検査器の仮置きにはこの契約を確かめるテストがなく、包含・環境・置換の検査漏れを
    // 捕まえる必要がある。準備を共有し、本番の差し込み口は増やさない
    // （設計書 07-03「テストの設計の原則」、実装プラン F13「受け入れテスト」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;
    use crate::base::{BindingMap, BytePos, Decimal, FileId, ModuleId};
    use crate::builtins::iface::Capability;
    use crate::builtins::table::{equality_builtin, operator_builtin};
    use crate::builtins::{BuiltinId, lookup_builtin};
    use crate::types::builtin::{find_builtin_effect, find_builtin_type};
    use crate::types::{AdtDef, AdtTable, ConstValue, CtorDef, FieldInfo, TraitDef, TypeSummary};

    const MAIN: BindingId = BindingId(0);
    const ID: BindingId = BindingId(1);
    const OPTION: BindingId = BindingId(10);
    const RECORD: BindingId = BindingId(11);
    const SHOW: BindingId = BindingId(20);
    const SUPER: BindingId = BindingId(21);
    const METHOD: BindingId = BindingId(22);
    const IMPL: NodeId = NodeId(30);
    const SUPER_IMPL: NodeId = NodeId(31);
    const OP: BindingId = BindingId(40);
    const CLAUSE: NodeId = NodeId(50);
    const DECL: BindingId = BindingId(60);
    const CONSTANT: BindingId = BindingId(70);

    fn span(n: u32) -> Span {
        Span {
            file: FileId(0),
            start: BytePos(n),
            end: BytePos(n + 1),
        }
    }
    fn int() -> Ty {
        builtin(BuiltinTypeId::INTEGER, vec![])
    }
    fn bool_ty() -> Ty {
        builtin(BuiltinTypeId::BOOLEAN, vec![])
    }
    fn list_ty(t: Ty) -> Ty {
        builtin(BuiltinTypeId::LIST, vec![t])
    }
    fn fn_ty(params: Vec<Ty>, ret: Ty, effects: EffectSet) -> Ty {
        Ty::Fn(Box::new(FnTy {
            params,
            ret,
            effects,
        }))
    }
    fn write() -> EffectSet {
        effect(EffectName::Builtin(
            find_builtin_effect(&["IO", "Console"], "Write").unwrap(),
        ))
    }
    fn effect(name: EffectName) -> EffectSet {
        let mut e = EffectSet::empty();
        e.insert_name(name);
        e
    }
    fn state() -> EffectSet {
        effect(EffectName::Builtin(BuiltinEffectId::STATE))
    }
    fn var(id: u32, ty: Ty) -> Var {
        Var {
            id: VarId(id),
            name: None,
            ty,
        }
    }
    fn val(kind: ValKind<Comp>, ty: Ty, pos: u32) -> CoreVal {
        Val {
            kind,
            ty,
            origin: span(pos),
        }
    }
    fn integer(pos: u32) -> CoreVal {
        val(ValKind::Const(Const::Int(1)), int(), pos)
    }
    fn boolean(pos: u32) -> CoreVal {
        val(ValKind::Const(Const::Bool(true)), bool_ty(), pos)
    }
    fn variable(id: u32, ty: Ty, pos: u32) -> CoreVal {
        val(ValKind::Var(VarId(id)), ty, pos)
    }
    fn comp(kind: CompKind, ty: Ty, eff: EffectSet, pos: u32) -> Comp {
        Comp {
            kind,
            ty,
            eff,
            origin: span(pos),
        }
    }
    fn ret(v: CoreVal) -> Comp {
        let ty = v.ty.clone();
        comp(CompKind::Return(v), ty, EffectSet::empty(), 100)
    }
    fn param(kind: ParamKind, constraint: Option<BuiltinConstraint>) -> TypeParamInfo {
        TypeParamInfo {
            name: "T".into(),
            kind,
            builtin: constraint,
        }
    }
    fn scheme(params: Vec<Ty>, ret: Ty, effects: EffectSet) -> Scheme {
        Scheme {
            type_params: vec![],
            effect_params: vec![],
            class_constraints: vec![],
            params,
            ret,
            effects,
            wrote_io_all: false,
        }
    }
    fn definition(
        binding: BindingId,
        params: Vec<Var>,
        ret: Ty,
        eff: EffectSet,
        body: Comp,
    ) -> CoreDef {
        Def {
            binding,
            name: format!("f{}", binding.0),
            origin: DefOrigin::User,
            kind: DefKind::Fn,
            type_params: vec![],
            effect_params: vec![],
            dict_params: vec![],
            params,
            ret,
            eff,
            body,
            span: span(200 + binding.0),
            var_count: 100,
        }
    }
    fn add_def(p: &mut CoreProgram, d: CoreDef) {
        p.schemes.insert(
            d.binding,
            Scheme {
                type_params: d
                    .type_params
                    .iter()
                    .map(|name| TypeParamInfo {
                        name: name.clone(),
                        kind: ParamKind::Value,
                        builtin: None,
                    })
                    .collect(),
                effect_params: d.effect_params.clone(),
                class_constraints: d.dict_params.iter().map(|d| d.constraint).collect(),
                ..scheme(
                    d.params.iter().map(|p| p.ty.clone()).collect(),
                    d.ret.clone(),
                    d.eff.clone(),
                )
            },
        );
        p.defs.push(d);
    }
    fn fixture() -> CoreProgram {
        let mut p = Program {
            defs: vec![],
            impls: vec![],
            consts: vec![],
            ops: vec![],
            adts: AdtTable::default(),
            traits: BindingMap::new(),
            schemes: BindingMap::new(),
            main: Some(MAIN),
            main_returns_result: false,
            body_count: 100,
        };
        p.adts.adts.insert(
            OPTION,
            AdtDef {
                binding: OPTION,
                name: "Option".into(),
                module: ModuleId(0),
                type_params: vec!["T".into()],
                ctors: vec![
                    CtorDef {
                        name: "None".into(),
                        binding: BindingId(12),
                        tag: 0,
                        fields: vec![],
                    },
                    CtorDef {
                        name: "Some".into(),
                        binding: BindingId(13),
                        tag: 1,
                        fields: vec![Ty::Param(0)],
                    },
                ],
                record: None,
                eq_summary: TypeSummary {
                    always: false,
                    depends_on: vec![0],
                },
                key_summary: TypeSummary {
                    always: false,
                    depends_on: vec![0],
                },
            },
        );
        p.adts.adts.insert(
            RECORD,
            AdtDef {
                binding: RECORD,
                name: "Record".into(),
                module: ModuleId(0),
                type_params: vec![],
                ctors: vec![CtorDef {
                    name: "Record".into(),
                    binding: BindingId(14),
                    tag: 0,
                    fields: vec![int()],
                }],
                record: Some(vec![FieldInfo {
                    name: "value".into(),
                    binding: BindingId(15),
                }]),
                eq_summary: TypeSummary::default(),
                key_summary: TypeSummary::default(),
            },
        );
        p
    }
    fn main_program(body: Comp, params: Vec<Var>, eff: EffectSet) -> CoreProgram {
        let mut p = fixture();
        add_def(&mut p, definition(MAIN, params, body.ty.clone(), eff, body));
        p
    }
    fn good(p: &CoreProgram) {
        assert_eq!(check_program(p), vec![]);
    }
    fn one(p: &CoreProgram, pos: u32, message: &str) {
        let errors = check_program(p);
        assert_eq!(errors.len(), 1, "{errors:#?}");
        assert_eq!(errors[0].origin, span(pos));
        assert!(errors[0].message.contains(message), "{errors:#?}");
        assert!(!errors[0].def.is_empty());
    }
    fn top(
        binding: BindingId,
        s: &Scheme,
        tys: Vec<TypeArg>,
        effects: Vec<EffectSet>,
        pos: u32,
    ) -> CoreVal {
        let ty = s.fn_ty().subst(&tys, &effects);
        val(
            ValKind::TopFn {
                def: binding,
                targs: TypeArgs { tys, effects },
            },
            ty,
            pos,
        )
    }
    fn builtin_val(
        id: BuiltinId,
        s: &Scheme,
        tys: Vec<TypeArg>,
        decl: Option<BindingId>,
        pos: u32,
    ) -> CoreVal {
        let ty = s.fn_ty().subst(&tys, &[]);
        val(
            ValKind::Builtin {
                id,
                targs: TypeArgs {
                    tys,
                    effects: vec![],
                },
                info: BuiltinInfo {
                    class: Capability::Pure,
                    op: None,
                    decl,
                    intrinsic: None,
                },
            },
            ty,
            pos,
        )
    }
    fn app(func: CoreVal, args: Vec<CoreVal>, dicts: Vec<DictVal>, pos: u32) -> Comp {
        let Ty::Fn(f) = &func.ty else {
            panic!("fixture function required")
        };
        let (ty, eff) = (f.ret.clone(), f.effects.clone());
        comp(CompKind::App { func, dicts, args }, ty, eff, pos)
    }
    fn lambda(body: Comp, params: Vec<Var>, pos: u32) -> CoreVal {
        let ty = fn_ty(
            params.iter().map(|p| p.ty.clone()).collect(),
            body.ty.clone(),
            body.eff.clone(),
        );
        val(
            ValKind::Lambda(Box::new(Lambda {
                id: BodyId(0),
                params,
                body,
                span: span(pos),
            })),
            ty,
            pos,
        )
    }

    #[test]
    fn polymorphic_values_applications_and_node_annotations() {
        let mut id = definition(
            ID,
            vec![var(0, Ty::Param(0))],
            Ty::Param(0),
            EffectSet::empty(),
            ret(variable(0, Ty::Param(0), 10)),
        );
        id.type_params.push("T".into());
        let mut p = fixture();
        add_def(&mut p, id);
        let s = p.schemes.get(ID).unwrap().clone();
        let body = app(
            top(ID, &s, vec![TypeArg::Ty(int())], vec![], 11),
            vec![integer(12)],
            vec![],
            13,
        );
        add_def(
            &mut p,
            definition(MAIN, vec![], int(), EffectSet::empty(), body),
        );
        good(&p);
        let mut broken = p.clone();
        let CompKind::App { args, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        args[0] = boolean(12);
        one(&broken, 12, "accepted");
        let mut broken = p.clone();
        let CompKind::App { func, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        func.ty = fn_ty(vec![int()], int(), write());
        broken.defs[1].body.eff = write();
        broken.defs[1].eff = write();
        broken.schemes.get(MAIN).unwrap();
        broken.schemes.insert(MAIN, scheme(vec![], int(), write()));
        one(&broken, 11, "expected");
        let mut broken = p.clone();
        let CompKind::App { func, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        let ValKind::TopFn { targs, .. } = &mut func.kind else {
            panic!()
        };
        targs.effects.push(EffectSet::empty());
        one(&broken, 11, "effect arguments");
        let mut broken = p.clone();
        let CompKind::App { func, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        let ValKind::TopFn { targs, .. } = &mut func.kind else {
            panic!()
        };
        targs.tys.push(TypeArg::Ty(bool_ty()));
        one(&broken, 11, "type arguments");
    }

    #[test]
    fn builtin_declarations_and_builtin_constraints() {
        let add = operator_builtin(OperatorKind::Add, BuiltinTypeId::INTEGER).unwrap();
        let s = builtin_scheme(add).unwrap();
        let p = main_program(
            app(
                builtin_val(add, &s, vec![], None, 10),
                vec![integer(11), integer(12)],
                vec![],
                13,
            ),
            vec![],
            EffectSet::empty(),
        );
        good(&p);
        let declared = lookup_builtin("Integer.toString").unwrap();
        let s = scheme(
            vec![int()],
            builtin(BuiltinTypeId::STRING, vec![]),
            EffectSet::empty(),
        );
        let mut p = main_program(
            app(
                builtin_val(declared, &s, vec![], Some(DECL), 20),
                vec![integer(21)],
                vec![],
                22,
            ),
            vec![],
            EffectSet::empty(),
        );
        p.schemes.insert(DECL, s);
        good(&p);
        let CompKind::App { func, .. } = &mut p.defs[0].body.kind else {
            panic!()
        };
        let ValKind::Builtin { info, .. } = &mut func.kind else {
            panic!()
        };
        info.decl = None;
        one(&p, 20, "missing builtin scheme");
        let eq = equality_builtin(false).unwrap();
        let s = builtin_scheme(eq).unwrap();
        let f = lambda(ret(integer(30)), vec![], 31);
        let p = main_program(
            app(
                builtin_val(eq, &s, vec![TypeArg::Ty(f.ty.clone())], None, 32),
                vec![f.clone(), f],
                vec![],
                33,
            ),
            vec![],
            EffectSet::empty(),
        );
        one(&p, 32, "Equality");
        let declared = lookup_builtin("List.sort").unwrap();
        let mut s = scheme(
            vec![list_ty(Ty::Param(0))],
            list_ty(Ty::Param(0)),
            EffectSet::empty(),
        );
        s.type_params
            .push(param(ParamKind::Value, Some(BuiltinConstraint::Ordered)));
        for (t, v, ok) in [(int(), integer(41), true), (bool_ty(), boolean(41), false)] {
            let items = val(ValKind::List(vec![v]), list_ty(t.clone()), 41);
            let mut p = main_program(
                app(
                    builtin_val(declared, &s, vec![TypeArg::Ty(t)], Some(DECL), 40),
                    vec![items],
                    vec![],
                    42,
                ),
                vec![],
                EffectSet::empty(),
            );
            p.schemes.insert(DECL, s.clone());
            if ok { good(&p) } else { one(&p, 40, "Ordered") }
        }
    }

    #[test]
    fn subsumption_only_widens_the_outer_function_effects() {
        let pure = fn_ty(vec![], int(), EffectSet::empty());
        let wide = fn_ty(vec![], int(), write());
        let f = lambda(ret(integer(10)), vec![], 11);
        let func = lambda(ret(integer(12)), vec![var(0, wide.clone())], 13);
        good(&main_program(
            app(func, vec![f.clone()], vec![], 14),
            vec![],
            EffectSet::empty(),
        ));
        let items = val(ValKind::List(vec![f.clone()]), list_ty(wide.clone()), 15);
        good(&main_program(
            ret(items.clone()),
            vec![],
            EffectSet::empty(),
        ));
        let nested = val(
            ValKind::List(vec![val(ValKind::List(vec![f]), list_ty(pure), 16)]),
            list_ty(list_ty(wide)),
            17,
        );
        one(
            &main_program(ret(nested), vec![], EffectSet::empty()),
            16,
            "accepted",
        );
        let body = comp(
            CompKind::Let {
                var: var(0, items.ty.clone()),
                bound: Box::new(ret(items)),
                body: Box::new(ret(integer(18))),
            },
            int(),
            EffectSet::empty(),
            19,
        );
        good(&main_program(body, vec![], EffectSet::empty()));
    }

    #[test]
    fn effect_contracts_and_escape_boundaries() {
        let f = variable(0, fn_ty(vec![], int(), write()), 10);
        let call = app(f, vec![], vec![], 11);
        let p = main_program(call, vec![var(0, fn_ty(vec![], int(), write()))], write());
        good(&p);
        let mut broken = p.clone();
        broken.defs[0].eff = EffectSet::empty();
        broken.schemes.insert(
            MAIN,
            scheme(
                vec![fn_ty(vec![], int(), write())],
                int(),
                EffectSet::empty(),
            ),
        );
        one(&broken, 11, "effects");
        let escape = comp(
            CompKind::Escape(integer(20)),
            bool_ty(),
            EffectSet::empty(),
            21,
        );
        let body = comp(
            CompKind::Let {
                var: var(1, bool_ty()),
                bound: Box::new(escape),
                body: Box::new(ret(integer(22))),
            },
            int(),
            EffectSet::empty(),
            23,
        );
        let p = main_program(body, vec![], EffectSet::empty());
        good(&p);
        let mut broken = p.clone();
        let CompKind::Let { bound, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        bound.kind = CompKind::Escape(boolean(20));
        one(&broken, 20, "accepted");
        let body = comp(
            CompKind::Lazy {
                id: BodyId(0),
                body: Box::new(comp(
                    CompKind::Escape(integer(30)),
                    int(),
                    EffectSet::empty(),
                    31,
                )),
            },
            builtin(BuiltinTypeId::LAZY, vec![int()]),
            EffectSet::empty(),
            32,
        );
        one(
            &main_program(body, vec![], EffectSet::empty()),
            30,
            "boundary",
        );
    }

    #[test]
    fn lazy_purity_and_resource_release_effects() {
        let body = comp(
            CompKind::Lazy {
                id: BodyId(0),
                body: Box::new(ret(integer(10))),
            },
            builtin(BuiltinTypeId::LAZY, vec![int()]),
            EffectSet::empty(),
            11,
        );
        good(&main_program(body, vec![], EffectSet::empty()));
        let body = comp(
            CompKind::Lazy {
                id: BodyId(0),
                body: Box::new(app(
                    variable(0, fn_ty(vec![], int(), write()), 12),
                    vec![],
                    vec![],
                    13,
                )),
            },
            builtin(BuiltinTypeId::LAZY, vec![int()]),
            EffectSet::empty(),
            14,
        );
        one(
            &main_program(
                body,
                vec![var(0, fn_ty(vec![], int(), write()))],
                EffectSet::empty(),
            ),
            13,
            "effects",
        );
        let resource = builtin(
            find_builtin_type(&["IO", "File"], "Reader").unwrap(),
            vec![],
        );
        let body = comp(
            CompKind::Use {
                resource: variable(0, resource.clone(), 20),
                body: Box::new(ret(integer(21))),
            },
            int(),
            state(),
            22,
        );
        let p = main_program(body, vec![var(0, resource)], state());
        good(&p);
        let mut broken = p.clone();
        let CompKind::Use { resource, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        *resource = integer(20);
        one(&broken, 20, "resource");
        let mut broken = p;
        broken.defs[0].body.eff = EffectSet::empty();
        one(&broken, 22, "effects");
    }

    #[test]
    fn lambda_effect_annotation_may_include_more_than_its_body() {
        let mut val = lambda(ret(integer(10)), vec![], 11);
        val.ty = fn_ty(vec![], int(), write());
        good(&main_program(ret(val), vec![], EffectSet::empty()));

        let mut val = lambda(
            app(
                variable(0, fn_ty(vec![], int(), write()), 12),
                vec![],
                vec![],
                13,
            ),
            vec![],
            14,
        );
        val.ty = fn_ty(vec![], int(), EffectSet::empty());
        let p = main_program(
            ret(val),
            vec![var(0, fn_ty(vec![], int(), write()))],
            EffectSet::empty(),
        );
        assert!(
            check_program(&p)
                .iter()
                .any(|e| e.message.contains("effects"))
        );
    }

    fn op_program(polymorphic: bool, constraint: Option<BuiltinConstraint>) -> CoreProgram {
        let mut p = fixture();
        let ty = if polymorphic { Ty::Param(0) } else { int() };
        let mut s = scheme(
            vec![ty.clone()],
            ty,
            effect(EffectName::User(BindingId(42))),
        );
        if polymorphic {
            s.type_params.push(param(ParamKind::Value, constraint));
        }
        p.schemes.insert(OP, s);
        p.ops.push(OpDef {
            binding: OP,
            effect: EffectName::User(BindingId(42)),
            name: "Log.echo".into(),
            arity: 1,
            builtin: None,
        });
        p
    }
    fn handled_program(polymorphic: bool) -> CoreProgram {
        let mut p = op_program(polymorphic, Some(BuiltinConstraint::Equality));
        let s = p.schemes.get(OP).unwrap();
        let ts = if polymorphic {
            vec![TypeArg::Ty(int())]
        } else {
            vec![]
        };
        let op = val(
            ValKind::Op {
                op: OP,
                targs: TypeArgs {
                    tys: ts.clone(),
                    effects: vec![],
                },
            },
            s.fn_ty().subst(&ts, &[]),
            10,
        );
        let body = app(op, vec![integer(11)], vec![], 12);
        let arg = if polymorphic {
            Ty::Rigid {
                clause: CLAUSE,
                index: 0,
            }
        } else {
            int()
        };
        let resume = comp(
            CompKind::Resume {
                cont: VarId(2),
                value: variable(1, arg.clone(), 13),
            },
            int(),
            EffectSet::empty(),
            14,
        );
        let clause = Clause {
            id: BodyId(1),
            node: CLAUSE,
            op: OP,
            params: vec![var(1, arg.clone())],
            cont: ContVar { id: VarId(2), arg },
            tail_resumptive: true,
            body: resume,
            span: span(15),
        };
        let handle = Handle {
            id: BodyId(2),
            body,
            clauses: vec![clause],
            handled: effect(EffectName::User(BindingId(42))),
        };
        add_def(
            &mut p,
            definition(
                MAIN,
                vec![],
                int(),
                EffectSet::empty(),
                comp(
                    CompKind::Handle(Box::new(handle)),
                    int(),
                    EffectSet::empty(),
                    16,
                ),
            ),
        );
        p
    }
    fn handler(p: &mut CoreProgram) -> &mut Handle<Comp> {
        let CompKind::Handle(h) = &mut p.defs[0].body.kind else {
            panic!()
        };
        h
    }

    #[test]
    fn operation_application_uses_its_declaration() {
        let mut p = op_program(false, None);
        let s = p.schemes.get(OP).unwrap().clone();
        let body = app(
            val(
                ValKind::Op {
                    op: OP,
                    targs: TypeArgs::default(),
                },
                s.fn_ty(),
                10,
            ),
            vec![integer(11)],
            vec![],
            12,
        );
        add_def(&mut p, definition(MAIN, vec![], int(), s.effects, body));
        good(&p);
        let CompKind::App { args, .. } = &mut p.defs[0].body.kind else {
            panic!()
        };
        args[0] = boolean(11);
        one(&p, 11, "accepted");
    }

    #[test]
    fn handlers_resume_and_rigid_clause_parameters() {
        for poly in [false, true] {
            good(&handled_program(poly));
        }
        let p = handled_program(false);
        let mut broken = p.clone();
        handler(&mut broken).clauses[0].body = ret(boolean(13));
        one(&broken, 100, "accepted");
        let mut broken = p.clone();
        handler(&mut broken).clauses[0].body.kind = CompKind::Resume {
            cont: VarId(2),
            value: boolean(13),
        };
        one(&broken, 13, "accepted");
        let mut broken = p.clone();
        handler(&mut broken).handled = EffectSet::empty();
        // 本体は εM ⊆ ε ∪ handled を満たすよう、ハンドラの許可する ε を広げる。
        broken.defs[0].body.eff = effect(EffectName::User(BindingId(42)));
        broken.defs[0].eff = broken.defs[0].body.eff.clone();
        handler(&mut broken).clauses[0].body.eff = broken.defs[0].eff.clone();
        broken
            .schemes
            .insert(MAIN, scheme(vec![], int(), broken.defs[0].eff.clone()));
        one(&broken, 16, "handled effects");
        let p = handled_program(true);
        let mut broken = p.clone();
        handler(&mut broken).clauses[0].cont.arg = int();
        handler(&mut broken).clauses[0].body.kind = CompKind::Resume {
            cont: VarId(2),
            value: integer(13),
        };
        one(&broken, 15, "expected");
        let mut broken = p;
        handler(&mut broken).clauses[0].params[0].ty = Ty::Rigid {
            clause: NodeId(999),
            index: 0,
        };
        handler(&mut broken).clauses[0].body = ret(integer(13));
        one(&broken, 15, "expected");
    }

    #[test]
    fn continuations_are_hidden_by_lambda_and_lazy_but_visible_in_nested_handlers() {
        let p = handled_program(false);
        for lazy_body in [false, true] {
            let mut broken = p.clone();
            let resume = handler(&mut broken).clauses[0].body.clone();
            let hidden = if lazy_body {
                comp(
                    CompKind::Lazy {
                        id: BodyId(8),
                        body: Box::new(resume),
                    },
                    builtin(BuiltinTypeId::LAZY, vec![int()]),
                    EffectSet::empty(),
                    20,
                )
            } else {
                ret(lambda(resume, vec![], 20))
            };
            handler(&mut broken).clauses[0].body = comp(
                CompKind::Let {
                    var: var(5, hidden.ty.clone()),
                    bound: Box::new(hidden),
                    body: Box::new(ret(integer(21))),
                },
                int(),
                EffectSet::empty(),
                22,
            );
            one(&broken, 14, "not visible");
        }
        let mut p = p;
        let outer_resume = handler(&mut p).clauses[0].body.clone();
        let nested = Handle {
            id: BodyId(8),
            body: outer_resume.clone(),
            clauses: vec![Clause {
                id: BodyId(9),
                node: NodeId(51),
                op: OP,
                params: vec![var(6, int())],
                cont: ContVar {
                    id: VarId(7),
                    arg: int(),
                },
                tail_resumptive: true,
                body: outer_resume,
                span: span(24),
            }],
            handled: effect(EffectName::User(BindingId(42))),
        };
        handler(&mut p).clauses[0].body = comp(
            CompKind::Handle(Box::new(nested)),
            int(),
            EffectSet::empty(),
            25,
        );
        good(&p);
    }

    #[test]
    fn rigid_parameters_use_the_operation_builtin_constraints() {
        let mut p = handled_program(true);
        let rigid = Ty::Rigid {
            clause: CLAUSE,
            index: 0,
        };
        let eq = equality_builtin(false).unwrap();
        let s = builtin_scheme(eq).unwrap();
        let equal = app(
            builtin_val(eq, &s, vec![TypeArg::Ty(rigid.clone())], None, 20),
            vec![variable(1, rigid.clone(), 21), variable(1, rigid, 22)],
            vec![],
            23,
        );
        let resume = handler(&mut p).clauses[0].body.clone();
        handler(&mut p).clauses[0].body = comp(
            CompKind::Let {
                var: var(4, bool_ty()),
                bound: Box::new(equal),
                body: Box::new(resume),
            },
            int(),
            EffectSet::empty(),
            24,
        );
        good(&p);
        p.schemes.insert(
            OP,
            Scheme {
                type_params: vec![param(ParamKind::Value, None)],
                ..p.schemes.get(OP).unwrap().clone()
            },
        );
        one(&p, 20, "Equality");
    }

    fn dict(kind: DictKind, class: BindingId, arg: TypeArg, pos: u32) -> DictVal {
        DictVal {
            kind,
            class,
            arg,
            origin: span(pos),
        }
    }
    fn concrete_dict(pos: u32) -> DictVal {
        dict(
            DictKind::Impl {
                impl_decl: SUPER_IMPL,
                tys: vec![],
                args: vec![],
            },
            SUPER,
            TypeArg::Ty(int()),
            pos,
        )
    }
    fn dictionary_program() -> CoreProgram {
        let mut p = fixture();
        p.traits.insert(
            SUPER,
            TraitDef {
                binding: SUPER,
                name: "Super".into(),
                module: ModuleId(0),
                param_kind: ParamKind::Value,
                supers: vec![],
                methods: vec![BindingId(24)],
            },
        );
        p.traits.insert(
            SHOW,
            TraitDef {
                binding: SHOW,
                name: "Show".into(),
                module: ModuleId(0),
                param_kind: ParamKind::Value,
                supers: vec![SUPER],
                methods: vec![METHOD],
            },
        );
        // Show の対象は 0 番、メソッド自身の U は 1 番。実装では β の後に U が来る。
        let mut method_scheme = scheme(
            vec![Ty::Param(0), Ty::Param(1)],
            Ty::Param(1),
            EffectSet::empty(),
        );
        method_scheme.type_params =
            vec![param(ParamKind::Value, None), param(ParamKind::Value, None)];
        method_scheme.class_constraints = vec![
            ClassConstraint {
                param: 0,
                class: SHOW,
            },
            ClassConstraint {
                param: 1,
                class: SUPER,
            },
        ];
        p.schemes.insert(METHOD, method_scheme);
        let constraint = ClassConstraint {
            param: 0,
            class: SUPER,
        };
        let own = ClassConstraint {
            param: 1,
            class: SUPER,
        };
        let target = Ty::Con(TyCon::Adt(OPTION), vec![Ty::Param(0)]);
        let helper_body = ret(variable(0, Ty::Param(0), 10));
        let mut helper = definition(
            ID,
            vec![var(0, Ty::Param(0))],
            Ty::Param(0),
            EffectSet::empty(),
            helper_body,
        );
        helper.type_params = vec!["T".into()];
        helper.dict_params = vec![DictParam {
            var: VarId(1),
            constraint,
        }];
        add_def(&mut p, helper);
        let helper_scheme = p.schemes.get(ID).unwrap();
        let bound = app(
            top(
                ID,
                helper_scheme,
                vec![TypeArg::Ty(Ty::Param(1))],
                vec![],
                11,
            ),
            vec![variable(1, Ty::Param(1), 12)],
            vec![dict(
                DictKind::Param(VarId(3)),
                SUPER,
                TypeArg::Ty(Ty::Param(1)),
                13,
            )],
            14,
        );
        let own_impl_dict = dict(DictKind::ImplParam(0), SUPER, TypeArg::Ty(Ty::Param(0)), 15);
        let bound_impl = app(
            top(
                ID,
                helper_scheme,
                vec![TypeArg::Ty(Ty::Param(0))],
                vec![],
                16,
            ),
            vec![variable(2, Ty::Param(0), 17)],
            vec![own_impl_dict],
            18,
        );
        let method_body = comp(
            CompKind::Let {
                var: var(4, Ty::Param(0)),
                bound: Box::new(bound_impl),
                body: Box::new(bound),
            },
            Ty::Param(1),
            EffectSet::empty(),
            19,
        );
        let mut method = definition(
            BindingId(23),
            vec![var(0, target.clone()), var(1, Ty::Param(1))],
            Ty::Param(1),
            EffectSet::empty(),
            method_body,
        );
        // Option のパターンで実装の β の値を取り出し、ImplParam で制約を渡す。
        let extract = comp(
            CompKind::Match {
                scrutinee: variable(0, target.clone(), 20),
                rows: vec![MatchRow {
                    pattern: CorePat::Ctor {
                        adt: OPTION,
                        tag: 1,
                        args: vec![CorePat::Var(VarId(2))],
                    },
                    arm: 0,
                }],
                arms: vec![MatchArm {
                    vars: vec![var(2, Ty::Param(0))],
                    guard: None,
                    body: method.body,
                }],
            },
            Ty::Param(1),
            EffectSet::empty(),
            21,
        );
        method.body = extract;
        method.type_params = vec!["T".into(), "U".into()];
        method.dict_params = vec![DictParam {
            var: VarId(3),
            constraint: own,
        }];
        method.kind = DefKind::Method {
            impl_decl: IMPL,
            index: 0,
        };
        p.schemes.insert(
            method.binding,
            Scheme {
                type_params: vec![param(ParamKind::Value, None), param(ParamKind::Value, None)],
                class_constraints: vec![constraint, own],
                ..scheme(
                    method.params.iter().map(|v| v.ty.clone()).collect(),
                    method.ret.clone(),
                    method.eff.clone(),
                )
            },
        );
        let mut super_scheme = scheme(vec![Ty::Param(0)], Ty::Param(0), EffectSet::empty());
        super_scheme.type_params = vec![param(ParamKind::Value, None)];
        super_scheme.class_constraints = vec![ClassConstraint {
            param: 0,
            class: SUPER,
        }];
        p.schemes.insert(BindingId(24), super_scheme);
        let mut super_int = definition(
            BindingId(25),
            vec![var(0, int())],
            int(),
            EffectSet::empty(),
            ret(variable(0, int(), 40)),
        );
        super_int.kind = DefKind::Method {
            impl_decl: SUPER_IMPL,
            index: 0,
        };
        p.schemes.insert(
            super_int.binding,
            scheme(vec![int()], int(), EffectSet::empty()),
        );
        let mut super_option = definition(
            BindingId(26),
            vec![var(0, Ty::Con(TyCon::Adt(OPTION), vec![Ty::Param(0)]))],
            Ty::Con(TyCon::Adt(OPTION), vec![Ty::Param(0)]),
            EffectSet::empty(),
            ret(variable(
                0,
                Ty::Con(TyCon::Adt(OPTION), vec![Ty::Param(0)]),
                41,
            )),
        );
        super_option.type_params = vec!["T".into()];
        super_option.kind = DefKind::Method {
            impl_decl: NodeId(32),
            index: 0,
        };
        p.schemes.insert(
            super_option.binding,
            Scheme {
                type_params: vec![param(ParamKind::Value, None)],
                class_constraints: vec![constraint],
                ..scheme(
                    super_option.params.iter().map(|v| v.ty.clone()).collect(),
                    super_option.ret.clone(),
                    EffectSet::empty(),
                )
            },
        );
        let generic_super = NodeId(32);
        p.impls.push(ImplDef {
            impl_decl: SUPER_IMPL,
            class: SUPER,
            name: "Super[Integer]".into(),
            origin: DefOrigin::User,
            type_params: vec![],
            target: TypeArg::Ty(int()),
            dict_params: vec![],
            supers: vec![],
            methods: vec![super_int],
            span: span(201),
        });
        p.impls.push(ImplDef {
            impl_decl: generic_super,
            class: SUPER,
            name: "Super[Option[T]]".into(),
            origin: DefOrigin::User,
            type_params: vec!["T".into()],
            target: TypeArg::Ty(target.clone()),
            dict_params: vec![constraint],
            supers: vec![],
            methods: vec![super_option],
            span: span(202),
        });
        p.impls.push(ImplDef {
            impl_decl: IMPL,
            class: SHOW,
            name: "Show[Option[T]]".into(),
            origin: DefOrigin::User,
            type_params: vec!["T".into()],
            target: TypeArg::Ty(target),
            dict_params: vec![constraint],
            supers: vec![dict(
                DictKind::Impl {
                    impl_decl: generic_super,
                    tys: vec![TypeArg::Ty(Ty::Param(0))],
                    args: vec![dict(
                        DictKind::ImplParam(0),
                        SUPER,
                        TypeArg::Ty(Ty::Param(0)),
                        22,
                    )],
                },
                SUPER,
                TypeArg::Ty(Ty::Con(TyCon::Adt(OPTION), vec![Ty::Param(0)])),
                23,
            )],
            methods: vec![method],
            span: span(203),
        });
        let target = Ty::Con(TyCon::Adt(OPTION), vec![int()]);
        let show = dict(
            DictKind::Impl {
                impl_decl: IMPL,
                tys: vec![TypeArg::Ty(int())],
                args: vec![concrete_dict(24)],
            },
            SHOW,
            TypeArg::Ty(target.clone()),
            25,
        );
        let option = val(
            ValKind::Ctor {
                adt: OPTION,
                tag: 1,
                tys: vec![int()],
                args: vec![integer(26)],
            },
            target.clone(),
            27,
        );
        let method_call = comp(
            CompKind::Method(Box::new(MethodCall {
                dict: show.clone(),
                method: 0,
                targs: TypeArgs {
                    tys: vec![TypeArg::Ty(int())],
                    effects: vec![],
                },
                dicts: vec![concrete_dict(28)],
                args: vec![option.clone(), integer(29)],
            })),
            int(),
            EffectSet::empty(),
            30,
        );
        let body = comp(
            CompKind::Let {
                var: var(0, int()),
                bound: Box::new(method_call),
                body: Box::new(app(
                    top(
                        ID,
                        p.schemes.get(ID).unwrap(),
                        vec![TypeArg::Ty(target.clone())],
                        vec![],
                        31,
                    ),
                    vec![option],
                    vec![dict(
                        DictKind::Super {
                            of: Box::new(show),
                            index: 0,
                        },
                        SUPER,
                        TypeArg::Ty(target),
                        32,
                    )],
                    33,
                )),
            },
            Ty::Con(TyCon::Adt(OPTION), vec![int()]),
            EffectSet::empty(),
            34,
        );
        add_def(
            &mut p,
            definition(MAIN, vec![], body.ty.clone(), EffectSet::empty(), body),
        );
        p
    }

    #[test]
    fn dictionary_types_supertraits_scope_and_method_contracts() {
        let p = dictionary_program();
        good(&p);
        let mut broken = p.clone();
        let CompKind::Let { bound, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        let CompKind::Method(call) = &mut bound.kind else {
            panic!()
        };
        call.dicts[0] = dict(
            DictKind::Impl {
                impl_decl: IMPL,
                tys: vec![TypeArg::Ty(int())],
                args: vec![concrete_dict(24)],
            },
            SHOW,
            TypeArg::Ty(Ty::Con(TyCon::Adt(OPTION), vec![int()])),
            28,
        );
        one(&broken, 28, "Dict");
        let mut broken = p.clone();
        let CompKind::Let { body, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        let CompKind::App { dicts, .. } = &mut body.kind else {
            panic!()
        };
        let DictKind::Super { index, .. } = &mut dicts[0].kind else {
            panic!()
        };
        *index = 99;
        one(&broken, 32, "index");
        let mut broken = p.clone();
        let CompKind::Let { bound, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        let CompKind::Method(call) = &mut bound.kind else {
            panic!()
        };
        call.dicts[0].kind = DictKind::ImplParam(0);
        one(&broken, 28, "scope");
        let mut broken = p.clone();
        let CompKind::Let { body, .. } = &mut broken.defs[1].body.kind else {
            panic!()
        };
        let CompKind::App { func, .. } = &mut body.kind else {
            panic!()
        };
        let ty = Ty::Con(TyCon::Adt(OPTION), vec![int()]);
        *func = lambda(ret(variable(10, ty.clone(), 35)), vec![var(10, ty)], 31);
        one(&broken, 33, "dictionary arguments");
        let mut broken = p.clone();
        let method = &mut broken.impls[2].methods[0];
        method.eff = write();
        let binding = method.binding;
        let mut s = broken.schemes.get(binding).unwrap().clone();
        s.effects = write();
        broken.schemes.insert(binding, s);
        one(&broken, 223, "trait contract");
        let mut broken = p;
        let method = &mut broken.impls[2].methods[0];
        method.ret = bool_ty();
        method.body = ret(boolean(50));
        let binding = method.binding;
        let mut s = broken.schemes.get(binding).unwrap().clone();
        s.ret = bool_ty();
        broken.schemes.insert(binding, s);
        one(&broken, 223, "trait contract");
    }

    #[test]
    fn higher_kinded_dictionaries_substitute_constructor_heads() {
        let class = BindingId(80);
        let method_id = BindingId(81);
        let method_binding = BindingId(82);
        let mut p = fixture();
        p.traits.insert(
            class,
            TraitDef {
                binding: class,
                name: "Functor".into(),
                module: ModuleId(0),
                param_kind: ParamKind::Ctor { arity: 1 },
                supers: vec![],
                methods: vec![method_id],
            },
        );
        let mut s = scheme(
            vec![Ty::App(0, vec![Ty::Param(1)])],
            Ty::App(0, vec![Ty::Param(1)]),
            EffectSet::empty(),
        );
        s.type_params = vec![
            param(ParamKind::Ctor { arity: 1 }, None),
            param(ParamKind::Value, None),
        ];
        s.class_constraints = vec![ClassConstraint { param: 0, class }];
        p.schemes.insert(method_id, s);
        let option = Ty::Con(TyCon::Adt(OPTION), vec![Ty::Param(0)]);
        let mut m = definition(
            method_binding,
            vec![var(0, option.clone())],
            option.clone(),
            EffectSet::empty(),
            ret(variable(0, option, 10)),
        );
        m.type_params = vec!["T".into()];
        m.kind = DefKind::Method {
            impl_decl: IMPL,
            index: 0,
        };
        p.schemes.insert(
            m.binding,
            Scheme {
                type_params: vec![param(ParamKind::Value, None)],
                ..scheme(
                    m.params.iter().map(|v| v.ty.clone()).collect(),
                    m.ret.clone(),
                    m.eff.clone(),
                )
            },
        );
        p.impls.push(ImplDef {
            impl_decl: IMPL,
            class,
            name: "Functor[Option]".into(),
            origin: DefOrigin::User,
            type_params: vec![],
            target: TypeArg::Head(TyHead::Con(TyCon::Adt(OPTION))),
            dict_params: vec![],
            supers: vec![],
            methods: vec![m],
            span: span(201),
        });
        let head = TypeArg::Head(TyHead::Con(TyCon::Adt(OPTION)));
        let option = Ty::Con(TyCon::Adt(OPTION), vec![int()]);
        let body = comp(
            CompKind::Method(Box::new(MethodCall {
                dict: dict(
                    DictKind::Impl {
                        impl_decl: IMPL,
                        tys: vec![],
                        args: vec![],
                    },
                    class,
                    head,
                    11,
                ),
                method: 0,
                targs: TypeArgs {
                    tys: vec![TypeArg::Ty(int())],
                    effects: vec![],
                },
                dicts: vec![],
                args: vec![val(
                    ValKind::Ctor {
                        adt: OPTION,
                        tag: 0,
                        tys: vec![int()],
                        args: vec![],
                    },
                    option.clone(),
                    12,
                )],
            })),
            option,
            EffectSet::empty(),
            13,
        );
        add_def(
            &mut p,
            definition(MAIN, vec![], body.ty.clone(), EffectSet::empty(), body),
        );
        good(&p);
        let CompKind::Method(call) = &mut p.defs[0].body.kind else {
            panic!()
        };
        call.dict.arg = TypeArg::Head(TyHead::Con(TyCon::Builtin(BuiltinTypeId::LIST)));
        // 呼び出しの型も List に合わせ、辞書自身の対象の誤りだけを残す。
        call.args = vec![val(ValKind::List(vec![]), list_ty(int()), 12)];
        p.defs[0].body.ty = list_ty(int());
        p.defs[0].ret = list_ty(int());
        p.schemes
            .insert(MAIN, scheme(vec![], list_ty(int()), EffectSet::empty()));
        one(&p, 11, "Dict");
    }

    fn match_program(ty: Ty, value: CoreVal, rows: Vec<CorePat>, vars: Vec<Var>) -> CoreProgram {
        let body = comp(
            CompKind::Match {
                scrutinee: value,
                rows: rows
                    .into_iter()
                    .map(|pattern| MatchRow { pattern, arm: 0 })
                    .collect(),
                arms: vec![MatchArm {
                    vars: vars.clone(),
                    guard: Some(ret(boolean(20))),
                    body: ret(integer(21)),
                }],
            },
            int(),
            EffectSet::empty(),
            22,
        );
        let p = main_program(body, vec![var(0, ty)], EffectSet::empty());
        good(&p);
        p
    }

    #[test]
    fn pattern_alternatives_ranges_lists_and_guards() {
        let ty = list_ty(int());
        let pat = CorePat::List {
            before: vec![CorePat::Var(VarId(1))],
            rest: Some(ListRest {
                var: Some(VarId(2)),
            }),
            after: vec![CorePat::Range {
                lo: Const::Int(0),
                hi: Const::Int(9),
            }],
        };
        let p = match_program(
            ty.clone(),
            variable(0, ty.clone(), 10),
            vec![pat.clone(), pat],
            vec![var(1, int()), var(2, ty)],
        );
        let mut broken = p.clone();
        let CompKind::Match { rows, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        rows[1].pattern = CorePat::Wild;
        one(&broken, 22, "bindings");
        let mut broken = p.clone();
        let CompKind::Match { arms, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        arms[0].vars[1].ty = int();
        // 一つの行だけで rest の型の規則を確かめる。
        let CompKind::Match { rows, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        rows.pop();
        one(&broken, 22, "bindings");
        let mut broken = p;
        let CompKind::Match { arms, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        arms[0].guard.as_mut().unwrap().eff = write();
        broken.defs[0].body.eff = write();
        broken.defs[0].eff = write();
        broken
            .schemes
            .insert(MAIN, scheme(vec![list_ty(int())], int(), write()));
        one(&broken, 100, "effects");
        let p = match_program(
            int(),
            integer(10),
            vec![CorePat::Range {
                lo: Const::Int(0),
                hi: Const::Int(10),
            }],
            vec![],
        );
        let mut broken = p;
        let CompKind::Match { rows, .. } = &mut broken.defs[0].body.kind else {
            panic!()
        };
        rows[0].pattern = CorePat::Range {
            lo: Const::Char('a'),
            hi: Const::Char('z'),
        };
        one(&broken, 22, "expected");
        for c in [
            Const::Float(1.0),
            Const::Decimal(Decimal::new(1, 0).unwrap()),
            Const::Byte(1),
        ] {
            let ty = constant_type(&c);
            let mut p = main_program(
                comp(
                    CompKind::Match {
                        scrutinee: val(ValKind::Const(c.clone()), ty, 10),
                        rows: vec![MatchRow {
                            pattern: CorePat::Const(c),
                            arm: 0,
                        }],
                        arms: vec![MatchArm {
                            vars: vec![],
                            guard: None,
                            body: ret(integer(21)),
                        }],
                    },
                    int(),
                    EffectSet::empty(),
                    22,
                ),
                vec![],
                EffectSet::empty(),
            );
            one(&p, 22, "not permitted");
            let CompKind::Match { rows, .. } = &mut p.defs[0].body.kind else {
                panic!()
            };
            rows[0].pattern = CorePat::Wild;
            good(&p);
        }
        let ty = Ty::Con(TyCon::Adt(RECORD), vec![]);
        let value = val(
            ValKind::Ctor {
                adt: RECORD,
                tag: 0,
                tys: vec![],
                args: vec![integer(10)],
            },
            ty.clone(),
            11,
        );
        good(&match_program(
            ty,
            value,
            vec![CorePat::Ctor {
                adt: RECORD,
                tag: 0,
                args: vec![CorePat::Var(VarId(1))],
            }],
            vec![var(1, int())],
        ));
    }

    #[test]
    fn constant_definitions_and_references_are_pure() {
        let mut p = main_program(
            ret(val(ValKind::ConstRef(CONSTANT), int(), 10)),
            vec![],
            EffectSet::empty(),
        );
        p.consts.push(ConstDef {
            binding: CONSTANT,
            name: "answer".into(),
            ty: int(),
            body: ret(integer(11)),
            value: ConstValue::Integer(1),
            span: span(12),
            var_count: 0,
        });
        good(&p);
        p.consts[0].body.eff = write();
        one(&p, 100, "effects");
        let errors = check_program(&p);
        assert_eq!(errors[0].def, "answer");
    }

    #[test]
    fn all_independent_errors_are_reported_across_branches_and_definitions() {
        let p = main_program(
            comp(
                CompKind::If {
                    cond: boolean(10),
                    then_branch: Box::new(ret(integer(11))),
                    else_branch: Box::new(ret(integer(12))),
                },
                int(),
                EffectSet::empty(),
                13,
            ),
            vec![],
            EffectSet::empty(),
        );
        good(&p);
        let mut broken = p;
        let CompKind::If {
            then_branch,
            else_branch,
            ..
        } = &mut broken.defs[0].body.kind
        else {
            panic!()
        };
        then_branch.kind = CompKind::Return(variable(99, int(), 11));
        else_branch.kind = CompKind::Return(variable(98, int(), 12));
        add_def(
            &mut broken,
            definition(
                ID,
                vec![],
                int(),
                EffectSet::empty(),
                ret(variable(97, int(), 14)),
            ),
        );
        let errors = check_program(&broken);
        assert_eq!(errors.len(), 3, "{errors:#?}");
        assert_eq!(
            errors.iter().map(|e| e.origin).collect::<Vec<_>>(),
            vec![span(11), span(12), span(14)]
        );
        assert_eq!(
            errors.iter().map(|e| e.def.as_str()).collect::<Vec<_>>(),
            vec!["f0", "f0", "f1"]
        );
    }

    #[test]
    fn constrained_top_functions_check_equality_key_and_declaration_summaries() {
        let plain_fn = fn_ty(vec![], int(), EffectSet::empty());
        let opaque = builtin(BuiltinTypeId::REFERENCE, vec![int()]);
        let float = builtin(BuiltinTypeId::FLOAT, vec![]);
        let option_float = Ty::Con(TyCon::Adt(OPTION), vec![float.clone()]);
        let option_fn = Ty::Con(TyCon::Adt(OPTION), vec![plain_fn.clone()]);
        for (constraint, ty, expected) in [
            (BuiltinConstraint::Equality, float, true),
            (BuiltinConstraint::Equality, plain_fn, false),
            (BuiltinConstraint::Equality, opaque, false),
            (BuiltinConstraint::Equality, option_fn, false),
            (BuiltinConstraint::Key, option_float, false),
            (BuiltinConstraint::Key, list_ty(int()), true),
            (
                BuiltinConstraint::Key,
                Ty::Con(TyCon::Adt(RECORD), vec![]),
                true,
            ),
            (
                BuiltinConstraint::Key,
                builtin(BuiltinTypeId::BYTES, vec![]),
                true,
            ),
        ] {
            let mut p = fixture();
            let mut d = definition(
                ID,
                vec![var(0, Ty::Param(0))],
                Ty::Param(0),
                EffectSet::empty(),
                ret(variable(0, Ty::Param(0), 10)),
            );
            d.type_params = vec!["T".into()];
            add_def(&mut p, d);
            let mut s = p.schemes.get(ID).unwrap().clone();
            s.type_params[0].builtin = Some(constraint);
            p.schemes.insert(ID, s.clone());
            let body = app(
                top(ID, &s, vec![TypeArg::Ty(ty.clone())], vec![], 11),
                vec![variable(0, ty.clone(), 12)],
                vec![],
                13,
            );
            add_def(
                &mut p,
                definition(MAIN, vec![var(0, ty.clone())], ty, EffectSet::empty(), body),
            );
            if expected {
                good(&p)
            } else {
                one(&p, 11, "satisfy")
            }
        }
        for own in [
            Some(BuiltinConstraint::Key),
            Some(BuiltinConstraint::Equality),
            None,
        ] {
            let eq = equality_builtin(false).unwrap();
            let s = builtin_scheme(eq).unwrap();
            let body = app(
                builtin_val(eq, &s, vec![TypeArg::Ty(Ty::Param(0))], None, 20),
                vec![variable(0, Ty::Param(0), 21), variable(0, Ty::Param(0), 22)],
                vec![],
                23,
            );
            let mut p = main_program(body, vec![var(0, Ty::Param(0))], EffectSet::empty());
            p.defs[0].type_params = vec!["T".into()];
            let mut s = p.schemes.get(MAIN).unwrap().clone();
            s.type_params = vec![param(ParamKind::Value, own)];
            p.schemes.insert(MAIN, s);
            if own.is_some() {
                good(&p)
            } else {
                one(&p, 20, "Equality")
            }
        }
    }

    #[test]
    fn effect_arguments_substitute_inside_function_types_and_remain_distinct() {
        let mut s = scheme(
            vec![fn_ty(
                vec![],
                int(),
                EffectSet {
                    names: vec![],
                    vars: vec![crate::types::EffVar(0)],
                },
            )],
            int(),
            EffectSet {
                names: vec![],
                vars: vec![crate::types::EffVar(0)],
            },
        );
        s.effect_params = vec!["E".into()];
        let mut p = fixture();
        let mut d = definition(
            ID,
            vec![var(0, s.params[0].clone())],
            int(),
            s.effects.clone(),
            app(variable(0, s.params[0].clone(), 10), vec![], vec![], 11),
        );
        d.effect_params = vec!["E".into()];
        add_def(&mut p, d);
        let callback = lambda(
            comp(CompKind::Return(integer(12)), int(), write(), 13),
            vec![],
            14,
        );
        let body = app(
            top(ID, &s, vec![], vec![write()], 15),
            vec![callback],
            vec![],
            16,
        );
        add_def(&mut p, definition(MAIN, vec![], int(), write(), body));
        good(&p);
        let mut broken = p;
        broken.defs[0].body.eff = EffectSet {
            names: vec![],
            vars: vec![crate::types::EffVar(1)],
        };
        // 宣言だけの変更なら本体との包含だけが破れる。ノードの規則の効果は E0 なので、
        // 別のエフェクト変数 E1 を追加し、本体の規則は保つ。
        broken.defs[0].body.eff.insert_var(crate::types::EffVar(0));
        one(&broken, 11, "effects");
    }

    #[test]
    fn handled_effects_require_every_operation_and_never_include_state() {
        let mut p = handled_program(false);
        let effect_name = EffectName::User(BindingId(42));
        p.ops.push(OpDef {
            binding: BindingId(41),
            effect: effect_name,
            name: "Log.other".into(),
            arity: 0,
            builtin: None,
        });
        p.schemes
            .insert(BindingId(41), scheme(vec![], int(), effect(effect_name)));
        handler(&mut p).handled = EffectSet::empty();
        p.defs[0].body.eff = effect(effect_name);
        p.defs[0].eff = effect(effect_name);
        handler(&mut p).clauses[0].body.eff = effect(effect_name);
        p.schemes
            .insert(MAIN, scheme(vec![], int(), effect(effect_name)));
        good(&p);
        handler(&mut p).handled = effect(effect_name);
        one(&p, 16, "handled effects");
        handler(&mut p).handled = state();
        one(&p, 16, "handled effects");
    }

    #[test]
    fn rigid_parameters_cannot_escape_their_clause_scope() {
        let ty = Ty::Rigid {
            clause: CLAUSE,
            index: 0,
        };
        let p = main_program(
            ret(variable(0, ty.clone(), 10)),
            vec![var(0, ty)],
            EffectSet::empty(),
        );
        one(&p, 10, "visible clause");
    }

    #[test]
    fn deep_ir_is_checked_without_changing_the_thread_stack() {
        // IR の再帰は許されるが、通常のテストのスレッドで入れ子を検査できる必要がある
        // （実装プラン F13「受け入れテスト」、設計書 07-03）。
        let mut body = ret(integer(10));
        for i in 0..1000 {
            body = comp(
                CompKind::Let {
                    var: var(i, int()),
                    bound: Box::new(ret(integer(11))),
                    body: Box::new(body),
                },
                int(),
                EffectSet::empty(),
                12,
            );
        }
        good(&main_program(body, vec![], EffectSet::empty()));
    }

    #[test]
    fn implementation_dictionary_type_arguments_satisfy_builtin_constraints() {
        let mut p = fixture();
        p.traits.insert(
            SHOW,
            TraitDef {
                binding: SHOW,
                name: "Show".into(),
                module: ModuleId(0),
                param_kind: ParamKind::Value,
                supers: vec![],
                methods: vec![METHOD],
            },
        );
        let mut s = scheme(vec![Ty::Param(0)], Ty::Param(0), EffectSet::empty());
        s.type_params = vec![param(ParamKind::Value, None)];
        s.class_constraints = vec![ClassConstraint {
            param: 0,
            class: SHOW,
        }];
        p.schemes.insert(METHOD, s);
        let target = list_ty(Ty::Param(0));
        let mut method = definition(
            BindingId(23),
            vec![var(0, target.clone())],
            target.clone(),
            EffectSet::empty(),
            ret(variable(0, target.clone(), 10)),
        );
        method.type_params = vec!["T".into()];
        method.kind = DefKind::Method {
            impl_decl: IMPL,
            index: 0,
        };
        p.schemes.insert(
            method.binding,
            Scheme {
                type_params: vec![param(ParamKind::Value, Some(BuiltinConstraint::Key))],
                ..scheme(vec![target.clone()], target.clone(), EffectSet::empty())
            },
        );
        p.impls.push(ImplDef {
            impl_decl: IMPL,
            class: SHOW,
            name: "Show[List[T]]".into(),
            origin: DefOrigin::User,
            type_params: vec!["T".into()],
            target: TypeArg::Ty(target),
            dict_params: vec![],
            supers: vec![],
            methods: vec![method],
            span: span(201),
        });
        for (ty, expected) in [
            (int(), true),
            (builtin(BuiltinTypeId::FLOAT, vec![]), false),
        ] {
            let mut program = p.clone();
            let list = list_ty(ty.clone());
            let body = comp(
                CompKind::Method(Box::new(MethodCall {
                    dict: dict(
                        DictKind::Impl {
                            impl_decl: IMPL,
                            tys: vec![TypeArg::Ty(ty)],
                            args: vec![],
                        },
                        SHOW,
                        TypeArg::Ty(list.clone()),
                        11,
                    ),
                    method: 0,
                    targs: TypeArgs::default(),
                    dicts: vec![],
                    args: vec![val(ValKind::List(vec![]), list.clone(), 12)],
                })),
                list,
                EffectSet::empty(),
                13,
            );
            add_def(
                &mut program,
                definition(MAIN, vec![], body.ty.clone(), EffectSet::empty(), body),
            );
            if expected {
                good(&program)
            } else {
                one(&program, 11, "Key")
            }
        }
    }
}
