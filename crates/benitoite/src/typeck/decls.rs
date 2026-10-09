//! 宣言の検査と型の要約（設計書 02-05「検査の単位と手順」「宣言の検査」）。

use super::limits::{MAX_TYPE_DEPTH, TypeBudget, TypeLimit};
use super::{MainInfo, TypeckOutput};
use crate::base::{BindingId, BindingMap, ModuleId, NodeId, SourceTable, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::modules::{ModuleKind, ModuleTable};
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::*;
use crate::types::builtin::{
    BUILTIN_EFFECTS, BuiltinEffectId, BuiltinTypeClass, BuiltinTypeId as B, find_builtin_effect,
};
use crate::types::*;
use std::collections::{BTreeMap, BTreeSet};

/// 定義の型パラメータの番号。囲む定義の分を先に置く（実装プラン 10-05）。
#[derive(Clone, Default)]
pub(super) struct Scope {
    pub params: BindingMap<(u32, ParamKind)>,
    pub effects: BindingMap<u32>,
}

/// 宣言の段の文脈。T1〜T3 が宣言を追加・検査するための共通の入口。
pub(super) struct Decls<'a> {
    pub modules: &'a ModuleTable,
    pub asts: &'a [Module],
    pub sources: &'a SourceTable,
    pub resolved: &'a ResolveOutput,
    pub out: TypeckOutput,
    pub diagnostics: Vec<Diagnostic>,
    pub scopes: BTreeMap<NodeId, Scope>,
    pub invalid: BTreeSet<BindingId>,
    aliases: BindingMap<AliasDecl>,
    alias_types: BindingMap<Ty>,
    expanding: BTreeSet<BindingId>,
    ty_recursion: usize,
    type_limit: bool,
    pub alias_spans: Vec<Span>,
}

pub(super) fn unit() -> Ty {
    Ty::Con(TyCon::Builtin(B::UNIT), vec![])
}
pub(super) fn basic(id: B) -> Ty {
    Ty::Con(TyCon::Builtin(id), vec![])
}
pub(super) fn scheme(params: Vec<Ty>, ret: Ty) -> Scheme {
    Scheme {
        type_params: vec![],
        effect_params: vec![],
        class_constraints: vec![],
        params,
        ret,
        effects: EffectSet::empty(),
        wrote_io_all: false,
    }
}

impl Decls<'_> {
    pub fn binding(&self, node: NodeId) -> Option<BindingId> {
        self.resolved.decls.get(node).copied()
    }
    pub fn reference(&self, node: NodeId) -> Option<BindingId> {
        self.resolved.refs.get(node).copied()
    }
    pub fn diagnostic(&mut self, code: DiagCode, span: Span) {
        self.diagnostics
            .push(DiagBuilder::new(code).primary(span).build());
    }
    pub fn parameters(
        &mut self,
        params: &[TypeParamDecl],
        mut scope: Scope,
        mut s: Scheme,
        allowed: bool,
    ) -> (Scope, Scheme) {
        for p in params {
            let Some(id) = self.binding(p.id) else {
                continue;
            };
            match p.kind {
                TypeParamKind::Effect => {
                    let i = u32::try_from(s.effect_params.len()).unwrap_or(u32::MAX);
                    scope.effects.insert(id, i);
                    s.effect_params.push(p.name.text.clone());
                }
                TypeParamKind::Value | TypeParamKind::Ctor { .. } => {
                    let i = u32::try_from(s.type_params.len()).unwrap_or(u32::MAX);
                    let kind = match p.kind {
                        TypeParamKind::Ctor { arity } => ParamKind::Ctor { arity },
                        TypeParamKind::Value | TypeParamKind::Effect => ParamKind::Value,
                    };
                    let mut builtin = None;
                    for c in &p.constraints {
                        match c {
                            ConstraintRef::Builtin { kind, .. } => {
                                if builtin != Some(BuiltinConstraint::Key) {
                                    builtin = Some(*kind);
                                }
                            }
                            ConstraintRef::Class(c) => {
                                if let Some(class) = self.reference(c.id) {
                                    s.class_constraints
                                        .push(ClassConstraint { param: i, class });
                                }
                            }
                        }
                    }
                    scope.params.insert(id, (i, kind));
                    s.type_params.push(TypeParamInfo {
                        name: p.name.text.clone(),
                        kind,
                        builtin,
                    });
                }
            }
        }
        super::traits::check_parameters(self, params, &scope, &s, allowed);
        (scope, s)
    }
    pub fn effect_name(&self, id: BindingId) -> Option<EffectName> {
        let binding = self.resolved.bindings.get(id)?;
        if let BindingKind::BuiltinEffect(e) = binding.kind {
            return Some(EffectName::Builtin(e));
        }
        let module = self.modules.get(binding.module)?;
        if matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib) {
            let path: Vec<_> = module.name.0.iter().skip(1).map(String::as_str).collect();
            if let Some(e) = find_builtin_effect(&path, &binding.name) {
                return Some(EffectName::Builtin(e));
            }
        }
        Some(EffectName::User(id))
    }
    pub fn uses(&mut self, uses: Option<&UsesList>, scope: &Scope) -> (EffectSet, bool) {
        let mut result = EffectSet::empty();
        let mut all = false;
        let mut variables = 0_u32;
        if let Some(uses) = uses {
            super::effects::check_uses(self, uses, scope);
            for e in &uses.effects {
                let Some(id) = self.reference(e.id) else {
                    continue;
                };
                if let Some(index) = scope.effects.get(id) {
                    variables = variables.saturating_add(1);
                    result.insert_var(EffVar(*index));
                } else if let Some(name) = self.effect_name(id) {
                    if name == EffectName::Builtin(BuiltinEffectId::IO_ALL) {
                        all = true;
                        for (i, e) in BUILTIN_EFFECTS.iter().enumerate() {
                            if e.in_io_all
                                && let Ok(i) = u16::try_from(i)
                            {
                                result.insert_name(EffectName::Builtin(BuiltinEffectId(i)));
                            }
                        }
                    } else {
                        result.insert_name(name);
                    }
                }
            }
            if variables > 1 {
                self.diagnostic(DiagCode::E0417, uses.span);
            }
        }
        (result, all)
    }
    pub fn ty(&mut self, expr: &TypeExpr, scope: &Scope) -> Ty {
        if self.type_limit {
            return unit();
        }
        // 型の構文を辿る再帰も制限する。別名の依存は先に繰り返しで辿り、
        // キャッシュを作るので、宣言の数には比例しない（02-03「入れ子の深さ」）。
        if self.ty_recursion == MAX_TYPE_DEPTH {
            self.type_limit(TypeLimit::Depth, expr.span());
            return unit();
        }
        self.ty_recursion = self.ty_recursion.saturating_add(1);
        let ty = self.ty_inner(expr, scope);
        self.ty_recursion = self.ty_recursion.saturating_sub(1);
        if self.type_limit { unit() } else { ty }
    }
    fn type_limit(&mut self, limit: TypeLimit, span: Span) {
        if !self.type_limit {
            self.diagnostics.push(limit.diagnostic(span));
            self.type_limit = true;
        }
    }
    fn ty_inner(&mut self, expr: &TypeExpr, scope: &Scope) -> Ty {
        match expr {
            TypeExpr::Paren(t) => self.ty(&t.inner, scope),
            TypeExpr::Error(_) => unit(),
            TypeExpr::Fn(f) => {
                let mut budget = TypeBudget::default();
                if let Err(limit) = budget.enter(1) {
                    self.type_limit(limit, f.span);
                    return unit();
                }
                let mut params = Vec::new();
                for t in &f.params {
                    let ty = self.ty(t, scope);
                    if self.type_limit {
                        return unit();
                    }
                    if let Err(limit) = budget.substituted(&ty, &[], 2) {
                        self.type_limit(limit, t.span());
                        return unit();
                    }
                    params.push(ty);
                }
                let ret = self.ty(&f.ret, scope);
                if self.type_limit {
                    return unit();
                }
                if let Err(limit) = budget.substituted(&ret, &[], 2) {
                    self.type_limit(limit, f.ret.span());
                    return unit();
                }
                let (effects, _) = self.uses(f.uses.as_ref(), scope);
                Ty::Fn(Box::new(FnTy {
                    params,
                    ret,
                    effects,
                }))
            }
            TypeExpr::Named(t) => self.named(t, scope),
        }
    }
    fn named(&mut self, t: &NamedType, scope: &Scope) -> Ty {
        let Some(id) = self.reference(t.id) else {
            return unit();
        };
        let Some(binding) = self.resolved.bindings.get(id) else {
            return unit();
        };
        let alias = matches!(binding.kind, BindingKind::Alias);
        let mut budget = TypeBudget::default();
        if !alias && let Err(limit) = budget.enter(1) {
            self.type_limit(limit, t.span);
            return unit();
        }
        let mut args = Vec::new();
        for arg in &t.args {
            let ty = self.ty(arg, scope);
            if self.type_limit {
                return unit();
            }
            if let Err(limit) = budget.substituted(&ty, &[], if alias { 1 } else { 2 }) {
                self.type_limit(limit, arg.span());
                return unit();
            }
            args.push(ty);
        }
        if let Some((index, kind)) = scope.params.get(id) {
            let (index, kind) = (*index, *kind);
            let n = match kind {
                ParamKind::Value => 0,
                ParamKind::Ctor { arity } => arity,
            };
            if !self.arity(
                &binding.name,
                n,
                args.len(),
                t.span,
                matches!(kind, ParamKind::Ctor { .. }),
            ) {
                return unit();
            }
            return match kind {
                ParamKind::Value => Ty::Param(index),
                ParamKind::Ctor { .. } => Ty::App(index, args),
            };
        }
        let (con, arity) = match binding.kind {
            BindingKind::BuiltinType(b) => {
                (TyCon::Builtin(b), b.def().map_or(0, |d| u32::from(d.arity)))
            }
            BindingKind::Data | BindingKind::Record => (
                TyCon::Adt(id),
                self.out.adts.get(id).map_or(0, |d| {
                    u32::try_from(d.type_params.len()).unwrap_or(u32::MAX)
                }),
            ),
            BindingKind::TypeParam { index, .. } => return Ty::Param(index),
            BindingKind::Alias => {
                self.alias_spans.push(t.span);
                let Some(alias) = self.aliases.get(id).cloned() else {
                    return unit();
                };
                if !self.arity(
                    &binding.name,
                    u32::try_from(alias.type_params.len()).unwrap_or(u32::MAX),
                    args.len(),
                    t.span,
                    false,
                ) {
                    return unit();
                }
                if !self.expanding.insert(id) {
                    return unit();
                }
                if self.alias_types.get(id).is_none() {
                    let scope = self.scopes.get(&alias.id).cloned().unwrap_or_default();
                    let ty = self.ty(&alias.ty, &scope);
                    if !self.type_limit {
                        self.alias_types.insert(id, ty);
                    }
                }
                self.expanding.remove(&id);
                let Some(ty) = self.alias_types.get(id) else {
                    return unit();
                };
                // 置換で同じ引数が何度も複製される場合も、複製する前に上限を検査する。
                if let Err(limit) = TypeBudget::default().substituted(ty, &args, 1) {
                    self.type_limit(limit, t.span);
                    return unit();
                }
                return ty.subst(&args.into_iter().map(TypeArg::Ty).collect::<Vec<_>>(), &[]);
            }
            BindingKind::Fn
            | BindingKind::BuiltinFn(_)
            | BindingKind::ImplFn { .. }
            | BindingKind::Const
            | BindingKind::Field { .. }
            | BindingKind::Ctor { .. }
            | BindingKind::Trait
            | BindingKind::Method { .. }
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Op { .. }
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::EffectVar { .. }
            | BindingKind::Local(_) => return unit(),
        };
        if !self.arity(&binding.name, arity, args.len(), t.span, true) {
            return unit();
        }
        Ty::Con(con, args)
    }
    fn arity(&mut self, name: &str, expected: u32, found: usize, span: Span, ctor: bool) -> bool {
        if usize::try_from(expected).ok() == Some(found) {
            return true;
        }
        let code = if found == 0 && ctor {
            DiagCode::E0426
        } else {
            DiagCode::E0410
        };
        self.diagnostics.push(
            DiagBuilder::new(code)
                .arg("name", name)
                .arg("expected", expected.to_string())
                .arg("found", found.to_string())
                .primary(span)
                .build(),
        );
        false
    }
    pub fn signature(&mut self, f: &FnDecl, scope: Scope, s: Scheme) -> Scheme {
        let (scope, mut s) = self.parameters(&f.type_params, scope, s, true);
        let mut budget = TypeBudget::default();
        if let Err(limit) = budget.enter(1) {
            self.type_limit(limit, f.name.span);
            return s;
        }
        s.params.clear();
        // 個々の引数が上限以内でも、関数型として合わせると超えることがある。
        // 具体化で大きな関数型を作る前に、宣言の段で合計を制限する（02-03）。
        for p in &f.params {
            let ty = p.ty.as_ref().map_or_else(unit, |ty| self.ty(ty, &scope));
            if !self.type_child(&mut budget, &ty, p.span) {
                return s;
            }
            s.params.push(ty);
        }
        s.ret = self.ty(&f.ret, &scope);
        if !self.type_child(&mut budget, &s.ret, f.ret.span()) {
            return s;
        }
        let (effects, all) = self.uses(f.uses.as_ref(), &scope);
        s.effects = effects;
        s.wrote_io_all = all;
        for (i, name) in s.effect_params.iter().enumerate() {
            if !s
                .params
                .iter()
                .any(|ty| has_effect(ty, u32::try_from(i).unwrap_or(u32::MAX)))
            {
                self.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0418)
                        .arg("name", name)
                        .primary(
                            f.type_params
                                .iter()
                                .find(|p| p.kind == TypeParamKind::Effect && p.name.text == *name)
                                .map_or(f.name.span, |p| p.name.span),
                        )
                        .build(),
                );
            }
        }
        self.scopes.insert(f.id, scope);
        s
    }
    fn type_child(&mut self, budget: &mut TypeBudget, ty: &Ty, span: Span) -> bool {
        if self.type_limit {
            return false;
        }
        if let Err(limit) = budget.substituted(ty, &[], 2) {
            self.type_limit(limit, span);
            return false;
        }
        true
    }
    fn prepare_aliases(&mut self) {
        // 宣言の順に依存しない。前方の別名を参照する長い連鎖でも、Rust の
        // スタックを深くせず、依存先から上限以内の型を保存する（02-03）。
        let ids: Vec<_> = self.aliases.iter().map(|(id, _)| id).collect();
        for id in ids {
            let mut pending = vec![(id, false)];
            while let Some((id, ready)) = pending.pop() {
                if self.alias_types.get(id).is_some() {
                    continue;
                }
                let Some(alias) = self.aliases.get(id) else {
                    continue;
                };
                if ready {
                    let alias = alias.clone();
                    let scope = self.scopes.get(&alias.id).cloned().unwrap_or_default();
                    let ty = self.ty(&alias.ty, &scope);
                    self.expanding.remove(&id);
                    if self.type_limit {
                        return;
                    }
                    self.alias_types.insert(id, ty);
                    continue;
                }
                // 循環は名前解決が拒否するが、その前提が壊れてもここで再帰しない。
                if !self.expanding.insert(id) {
                    continue;
                }
                pending.push((id, true));
                let mut types = vec![&alias.ty];
                let mut dependencies = BTreeSet::new();
                while let Some(ty) = types.pop() {
                    match ty {
                        TypeExpr::Named(t) => {
                            if let Some(target) = self.reference(t.id)
                                && self.aliases.get(target).is_some()
                            {
                                dependencies.insert(target);
                            }
                            types.extend(&t.args);
                        }
                        TypeExpr::Fn(f) => {
                            types.extend(&f.params);
                            types.push(&f.ret);
                        }
                        TypeExpr::Paren(t) => types.push(&t.inner),
                        TypeExpr::Error(_) => {}
                    }
                }
                pending.extend(dependencies.into_iter().map(|id| (id, false)));
            }
        }
    }
}

fn has_effect(ty: &Ty, index: u32) -> bool {
    match ty {
        Ty::Fn(f) => {
            f.effects.vars.contains(&EffVar(index))
                || f.params.iter().any(|t| has_effect(t, index))
                || has_effect(&f.ret, index)
        }
        Ty::Con(_, a) | Ty::App(_, a) => a.iter().any(|t| has_effect(t, index)),
        Ty::Param(_) | Ty::Rigid { .. } => false,
    }
}
fn has_param(ty: &Ty, index: u32) -> bool {
    match ty {
        Ty::Param(i) => *i == index,
        Ty::App(i, a) => *i == index || a.iter().any(|t| has_param(t, index)),
        Ty::Con(_, a) => a.iter().any(|t| has_param(t, index)),
        Ty::Fn(f) => f.params.iter().any(|t| has_param(t, index)) || has_param(&f.ret, index),
        _ => false,
    }
}

pub(super) fn check(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
    require_main: bool,
) -> (TypeckOutput, Vec<Diagnostic>) {
    let mut d = Decls {
        modules,
        asts,
        sources,
        resolved,
        out: TypeckOutput::default(),
        diagnostics: vec![],
        scopes: BTreeMap::new(),
        invalid: BTreeSet::new(),
        aliases: BindingMap::default(),
        alias_types: BindingMap::default(),
        expanding: BTreeSet::new(),
        ty_recursion: 0,
        type_limit: false,
        alias_spans: Vec::new(),
    };
    check_declarations(&mut d, require_main);
    if d.type_limit {
        return (d.out, d.diagnostics);
    }
    super::consts::check(&mut d);
    for ast in asts {
        for top in &ast.decls {
            match &top.item {
                Item::Fn(f) => super::generate::check_function(&mut d, f),
                Item::Impl(i) => {
                    for f in &i.fns {
                        super::generate::check_function(&mut d, &f.decl);
                    }
                }
                Item::Const(_)
                | Item::Data(_)
                | Item::Alias(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Error(_) => {}
            }
        }
    }
    if d.diagnostics.iter().any(Diagnostic::is_error) {
        d.out.main = None;
    }
    (d.out, d.diagnostics)
}

// 宣言の検査の一時的な値を、本体の再帰走査中のスタックに残さない
// （設計書 02-03「入れ子の深さ」）。インライン展開で枠を再び合わせない。
#[inline(never)]
fn check_declarations(d: &mut Decls<'_>, require_main: bool) {
    // 相互再帰する宣言を型引数の個数で引けるよう、頭部をすべて先に置く（設計書 02-05「宣言の検査」）。
    for (module, ast) in d.asts.iter().enumerate() {
        for top in &ast.decls {
            let id = top.item.id();
            let Some(binding) = d.binding(id) else {
                continue;
            };
            let (name, params, record) = match &top.item {
                Item::Alias(a) => {
                    d.aliases.insert(binding, a.clone());
                    continue;
                }
                Item::Data(a) => (&a.name, &a.type_params, false),
                Item::Record(a) => (&a.name, &a.type_params, true),
                Item::Fn(_)
                | Item::Const(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Impl(_)
                | Item::Error(_) => continue,
            };
            d.out.adts.adts.insert(
                binding,
                AdtDef {
                    binding,
                    name: name.text.clone(),
                    module: ModuleId(u32::try_from(module).unwrap_or(u32::MAX)),
                    type_params: params.iter().map(|p| p.name.text.clone()).collect(),
                    ctors: vec![],
                    record: record.then(Vec::new),
                    eq_summary: TypeSummary::default(),
                    key_summary: TypeSummary::default(),
                },
            );
        }
    }
    // 別名を何度使っても宣言の制約を二度検査しない。全頭部の収集後に一度だけ移す（フック T2）。
    for ast in d.asts {
        for top in &ast.decls {
            if let Item::Alias(a) = &top.item {
                let (scope, _) = d.parameters(
                    &a.type_params,
                    Scope::default(),
                    scheme(vec![], unit()),
                    false,
                );
                d.scopes.insert(a.id, scope);
            }
        }
    }
    d.prepare_aliases();
    if d.type_limit {
        return;
    }
    for ast in d.asts {
        for top in &ast.decls {
            let Some(binding) = d.binding(top.item.id()) else {
                continue;
            };
            let before = d.diagnostics.len();
            match &top.item {
                Item::Fn(f) => {
                    let s = d.signature(f, Scope::default(), scheme(vec![], unit()));
                    d.out.decl_types.insert(binding, s);
                }
                Item::Const(c) => {
                    let ty = d.ty(&c.ty, &Scope::default());
                    d.out.decl_types.insert(binding, scheme(vec![], ty));
                }
                Item::Data(data) => {
                    let (scope, s) = d.parameters(
                        &data.type_params,
                        Scope::default(),
                        scheme(vec![], unit()),
                        false,
                    );
                    let ret = Ty::Con(
                        TyCon::Adt(binding),
                        (0..s.type_params.len())
                            .map(|i| Ty::Param(u32::try_from(i).unwrap_or(u32::MAX)))
                            .collect(),
                    );
                    let mut ctors = vec![];
                    if data.variants.is_empty() {
                        d.diagnostics.push(
                            DiagBuilder::new(DiagCode::E0411)
                                .arg("name", &data.name.text)
                                .primary(data.name.span)
                                .help("add")
                                .build(),
                        );
                    }
                    for (tag, v) in data.variants.iter().enumerate() {
                        if let Some(id) = d.binding(v.id) {
                            let mut budget = TypeBudget::default();
                            if let Err(limit) = budget.enter(1) {
                                d.type_limit(limit, v.span);
                            }
                            if !d.type_child(&mut budget, &ret, v.span) {
                                return;
                            }
                            let mut fields = Vec::new();
                            for t in &v.fields {
                                let ty = d.ty(t, &scope);
                                if !d.type_child(&mut budget, &ty, t.span()) {
                                    return;
                                }
                                fields.push(ty);
                            }
                            let mut ctor = s.clone();
                            ctor.params = fields.clone();
                            ctor.ret = ret.clone();
                            d.out.decl_types.insert(id, ctor);
                            ctors.push(CtorDef {
                                name: v.name.text.clone(),
                                binding: id,
                                tag: u32::try_from(tag).unwrap_or(u32::MAX),
                                fields,
                            });
                        }
                    }
                    if let Some(mut a) = d.out.adts.get(binding).cloned() {
                        a.ctors = ctors;
                        d.out.adts.adts.insert(binding, a);
                    }
                }
                Item::Record(record) => {
                    let (scope, mut s) = d.parameters(
                        &record.type_params,
                        Scope::default(),
                        scheme(vec![], unit()),
                        false,
                    );
                    let ret = Ty::Con(
                        TyCon::Adt(binding),
                        (0..s.type_params.len())
                            .map(|i| Ty::Param(u32::try_from(i).unwrap_or(u32::MAX)))
                            .collect(),
                    );
                    let mut budget = TypeBudget::default();
                    if let Err(limit) = budget.enter(1) {
                        d.type_limit(limit, record.span);
                    }
                    if !d.type_child(&mut budget, &ret, record.span) {
                        return;
                    }
                    let mut fields = vec![];
                    let mut tys = vec![];
                    for f in &record.fields {
                        if let Some(id) = d.binding(f.id) {
                            let ty = d.ty(&f.ty, &scope);
                            if !d.type_child(&mut budget, &ty, f.ty.span()) {
                                return;
                            }
                            let mut access = s.clone();
                            access.params = vec![ret.clone()];
                            access.ret = ty.clone();
                            d.out.decl_types.insert(id, access);
                            fields.push(FieldInfo {
                                name: f.name.text.clone(),
                                binding: id,
                            });
                            tys.push(ty);
                        }
                    }
                    s.params = tys.clone();
                    s.ret = ret;
                    d.out.decl_types.insert(binding, s);
                    if let Some(mut a) = d.out.adts.get(binding).cloned() {
                        a.record = Some(fields);
                        a.ctors = vec![CtorDef {
                            name: record.name.text.clone(),
                            binding,
                            tag: 0,
                            fields: tys,
                        }];
                        d.out.adts.adts.insert(binding, a);
                    }
                }
                Item::Alias(a) => {
                    let scope = d.scopes.get(&a.id).cloned().unwrap_or_default();
                    let ty = if let Some(ty) = d.alias_types.get(binding) {
                        ty.clone()
                    } else {
                        let ty = d.ty(&a.ty, &scope);
                        d.alias_types.insert(binding, ty.clone());
                        ty
                    };
                    if d.type_limit {
                        return;
                    }
                    for (i, p) in a.type_params.iter().enumerate() {
                        if !has_param(&ty, u32::try_from(i).unwrap_or(u32::MAX)) {
                            d.diagnostics.push(
                                DiagBuilder::new(DiagCode::E0432)
                                    .arg("param", &p.name.text)
                                    .arg("name", &a.name.text)
                                    .primary(a.name.span)
                                    .build(),
                            );
                        }
                    }
                }
                Item::Effect(e) => {
                    let name = d.effect_name(binding).unwrap_or(EffectName::User(binding));
                    let mut ops = vec![];
                    for op in &e.ops {
                        if let Some(id) = d.binding(op.id) {
                            let f = FnDecl {
                                id: op.id,
                                span: op.span,
                                name: op.name.clone(),
                                type_params: op.type_params.clone(),
                                params: op.params.clone(),
                                ret: op.ret.clone(),
                                uses: None,
                                body: None,
                            };
                            let mut s = d.signature(&f, Scope::default(), scheme(vec![], unit()));
                            s.effects.insert_name(name);
                            d.out.decl_types.insert(id, s);
                            ops.push(id);
                        }
                    }
                    d.out.effects.insert(
                        binding,
                        EffectDef {
                            binding,
                            name,
                            display_name: e.name.text.clone(),
                            ops,
                        },
                    );
                }
                Item::Trait(_) | Item::Impl(_) | Item::Error(_) => {}
            }
            if d.type_limit {
                return;
            }
            if d.diagnostics.len() != before {
                d.invalid.insert(binding);
                match &top.item {
                    Item::Data(a) => {
                        for v in &a.variants {
                            if let Some(id) = d.binding(v.id) {
                                d.invalid.insert(id);
                            }
                        }
                    }
                    Item::Record(a) => {
                        for f in &a.fields {
                            if let Some(id) = d.binding(f.id) {
                                d.invalid.insert(id);
                            }
                        }
                    }
                    Item::Effect(a) => {
                        for op in &a.ops {
                            if let Some(id) = d.binding(op.id) {
                                d.invalid.insert(id);
                            }
                        }
                    }
                    Item::Fn(_)
                    | Item::Const(_)
                    | Item::Alias(_)
                    | Item::Trait(_)
                    | Item::Impl(_)
                    | Item::Error(_) => {}
                }
            }
        }
    }
    super::traits::collect(d);
    summaries(&mut d.out.adts);
    check_entry(d, require_main);
    super::traits::check_impls(d);
}

fn returns_result(d: &Decls<'_>, ty: &Ty) -> bool {
    match ty {
        Ty::Con(TyCon::Adt(id), args)
            if Some(*id) == d.resolved.stdlib("Benitoite.Result.Result") =>
        {
            args == &vec![unit(), basic(B::STRING)]
        }
        Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => false,
    }
}
fn check_entry(d: &mut Decls<'_>, require_main: bool) {
    if let Some(id) = d.resolved.main {
        if let Some(s) = d.out.decl_types.get(id).cloned() {
            let mut diag = DiagBuilder::new(DiagCode::E0415);
            if let Some(span) = d.resolved.bindings.get(id).and_then(|b| b.span) {
                diag = diag.primary(span);
            }
            let mut bad = false;
            if !s.params.is_empty() {
                diag = diag.note("params");
                bad = true;
            }
            if !s.type_params.is_empty() || !s.effect_params.is_empty() {
                diag = diag.note("type_params");
                bad = true;
            }
            let result = returns_result(d, &s.ret);
            if s.ret != unit() && !result {
                diag = diag.note("ret");
                bad = true;
            }
            if bad {
                d.diagnostics.push(diag.build());
            } else {
                d.out.main = Some(MainInfo {
                    binding: id,
                    returns_result: result,
                });
            }
        }
    } else if require_main {
        d.diagnostics
            .push(DiagBuilder::new(DiagCode::E0414).help("define").build());
    }
    for ast in d.asts {
        for top in &ast.decls {
            if let Item::Fn(f) = &top.item
                && top.attrs.iter().any(|a| a.name.text == "test")
                && let Some(id) = d.binding(f.id)
                && let Some(s) = d.out.decl_types.get(id)
                && (!s.params.is_empty()
                    || !s.type_params.is_empty()
                    || !s.effect_params.is_empty()
                    || (s.ret != unit() && !returns_result(d, &s.ret)))
            {
                d.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0806)
                        .primary(f.name.span)
                        .build(),
                );
            }
        }
    }
    super::effects::check_entries(d);
}
fn summaries(adts: &mut AdtTable) {
    loop {
        let mut changed = false;
        let updates: Vec<_> = adts
            .adts
            .iter()
            .map(|(id, a)| {
                let mut eq = TypeSummary::default();
                let mut key = TypeSummary::default();
                for c in &a.ctors {
                    for t in &c.fields {
                        merge(&mut eq, summary(t, adts, false));
                        merge(&mut key, summary(t, adts, true));
                    }
                }
                (id, eq, key)
            })
            .collect();
        for (id, eq, key) in updates {
            if let Some(mut a) = adts.get(id).cloned() {
                changed |= a.eq_summary != eq || a.key_summary != key;
                a.eq_summary = eq;
                a.key_summary = key;
                adts.adts.insert(id, a);
            }
        }
        if !changed {
            break;
        }
    }
}
fn merge(a: &mut TypeSummary, b: TypeSummary) {
    a.always |= b.always;
    for i in b.depends_on {
        if let Err(p) = a.depends_on.binary_search(&i) {
            a.depends_on.insert(p, i);
        }
    }
}
fn summary(ty: &Ty, adts: &AdtTable, key: bool) -> TypeSummary {
    let mut out = TypeSummary::default();
    match ty {
        Ty::Param(i) => out.depends_on.push(*i),
        Ty::Fn(_) | Ty::App(..) | Ty::Rigid { .. } => out.always = !key,
        Ty::Con(TyCon::Builtin(b), args) => {
            if key {
                out.always = *b == B::FLOAT;
            } else {
                out.always = b.def().is_some_and(|d| {
                    matches!(
                        d.class,
                        BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource
                    )
                });
            }
            if b.def()
                .is_some_and(|d| d.class == BuiltinTypeClass::Collection)
            {
                for a in args {
                    merge(&mut out, summary(a, adts, key));
                }
            }
        }
        Ty::Con(TyCon::Adt(id), args) => {
            if let Some(a) = adts.get(*id) {
                let s = if key { &a.key_summary } else { &a.eq_summary };
                out.always = s.always;
                for i in &s.depends_on {
                    if let Some(arg) = usize::try_from(*i).ok().and_then(|i| args.get(i)) {
                        merge(&mut out, summary(arg, adts, key));
                    }
                }
            }
        }
    }
    out
}
