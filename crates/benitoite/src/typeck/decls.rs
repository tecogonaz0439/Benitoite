//! 宣言の検査と型の要約（設計書 02-05「検査の単位と手順」「宣言の検査」）。

use super::body_map::{BodyBindingMap, BodyNodeMap};
use super::limits::{MAX_TYPE_DEPTH, TypeBudget, TypeLimit};
use super::{MainInfo, TypeckOutput};
use crate::base::{BindingId, BindingMap, ModuleId, NodeId, SourceTable, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::modules::{ModuleKind, ModuleTable};
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::*;
use crate::types::builtin::{
    BUILTIN_EFFECTS, BuiltinEffectId, BuiltinTypeClass, BuiltinTypeId as B, find_builtin_effect,
    find_builtin_type,
};
use crate::types::*;
use std::collections::{BTreeMap, BTreeSet};

// parser の MAX_DEPTH=1000 に対し、容器・短絡などの追加段も数えるため4096とする。
// 交換では同じ fuel を明示入力にし、深さ停止を比較対象から区別する（設計書 02-05「区間解析の式の識別」）。
const INTERVAL_ANALYSIS_FUEL: u32 = 4096;

/// 定義の型パラメータの番号。囲む定義の分を先に置く（`types` のモジュールの説明）。
#[derive(Clone, Default)]
pub(super) struct Scope {
    pub params: BodyBindingMap<(u32, ParamKind)>,
    pub effects: BodyBindingMap<u32>,
}

/// 宣言の段の文脈。T1〜T3 が宣言を追加・検査するための共通の入口。
pub(super) struct Decls<'a> {
    pub modules: &'a ModuleTable,
    pub asts: &'a [Module],
    pub handler_syntax: BodyNodeMap<&'a HandleExpr>,
    pub sources: &'a SourceTable,
    pub resolved: &'a ResolveOutput,
    pub out: TypeckOutput,
    pub checked_args: super::checked_args::CheckedArgsState,
    pub interval: super::interval::AnalysisState<'a>,
    pub scope_inputs: super::scope::Inputs,
    pub scope_analyses: Vec<super::scoped_calls::ScopedCalls>,
    /// 宣言の検査を終えた後の本体間で共有する、読み取り専用の実装索引。
    pub impl_index: Option<std::rc::Rc<super::traits::ImplTable>>,
    pub const_origins: BindingMap<BTreeSet<BindingId>>,
    pub diagnostics: Vec<Diagnostic>,
    pub scopes: BTreeMap<NodeId, Scope>,
    pub invalid: BTreeSet<BindingId>,
    /// キャッシュ済みの誤った別名の使用も、宣言と本体の注釈を誤りの型にするために数える。
    pub invalid_alias_uses: usize,
    /// 型構成子のない対象への誤った実装から、同じ型クラスの E0705 を派生させない。
    pub invalid_impl_targets: BTreeSet<BindingId>,
    /// 型クラスの束縛から引数の種類を引く表。関数のシグネチャの検査は型クラスの表を作る前に走るので、`Decls::new` で全モジュールの宣言から一度だけ作る。
    pub trait_param_kinds: BindingMap<ParamKind>,
    aliases: BindingMap<AliasDecl>,
    alias_types: BindingMap<Ty>,
    expanding: BTreeSet<BindingId>,
    ty_recursion: usize,
    type_limit: bool,
    pub alias_spans: Vec<Span>,
}

pub(super) fn unit() -> Ty {
    Ty::Con(
        TyCon::Builtin(B::UNIT),
        vec![],
        crate::types::builtin::RangeIndex::TOP,
    )
}
pub(super) fn basic(id: B) -> Ty {
    Ty::Con(
        TyCon::Builtin(id),
        vec![],
        crate::types::builtin::RangeIndex::TOP,
    )
}
pub(super) fn scheme(params: Vec<Ty>, ret: Ty) -> Scheme {
    Scheme {
        no_fail: vec![],
        param_names: crate::base::parameter_names::positional_names(params.len()),
        type_params: vec![],
        effect_params: vec![],
        class_constraints: vec![],
        params,
        ret,
        effects: EffectSet::empty(),
        wrote_io_all: false,
    }
}

impl<'a> Decls<'a> {
    pub(super) fn new(
        modules: &'a ModuleTable,
        asts: &'a [Module],
        sources: &'a SourceTable,
        resolved: &'a ResolveOutput,
    ) -> Self {
        // 最初の check_parameters より前に、後方と別モジュールの宣言も引けるようにする。
        let mut trait_param_kinds = BindingMap::default();
        for top in asts.iter().flat_map(|ast| &ast.decls) {
            if let Item::Trait(t) = &top.item
                && let Some(binding) = resolved.decls.get(t.id)
            {
                trait_param_kinds.insert(*binding, super::traits::kind(&t.param));
            }
        }
        let mut handler_syntax = BodyNodeMap::default();
        let mut collect = |expression: &'a Expr| {
            if let Expr::Handle(handle) = expression {
                handler_syntax.insert(handle.id, handle);
            }
        };
        for top in asts.iter().flat_map(|ast| &ast.decls) {
            match &top.item {
                Item::Fn(function) => {
                    if let Some(body) = &function.body {
                        super::consts::visit_block(body, &mut collect);
                    }
                }
                Item::Impl(implementation) => {
                    for function in &implementation.fns {
                        if let Some(body) = &function.decl.body {
                            super::consts::visit_block(body, &mut collect);
                        }
                    }
                }
                Item::Const(constant) => super::consts::visit_expr(&constant.value, &mut collect),
                Item::Data(_)
                | Item::Alias(_)
                | Item::ExternalType(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Error(_) => {}
            }
        }
        Self {
            modules,
            asts,
            handler_syntax,
            sources,
            resolved,
            out: TypeckOutput::default(),
            checked_args: super::checked_args::CheckedArgsState::default(),
            interval: super::interval::AnalysisState::new(asts, modules, resolved),
            scope_inputs: super::scope::Inputs::default(),
            scope_analyses: Vec::new(),
            impl_index: None,
            const_origins: BindingMap::default(),
            diagnostics: vec![],
            scopes: BTreeMap::new(),
            invalid: BTreeSet::new(),
            invalid_alias_uses: 0,
            invalid_impl_targets: BTreeSet::new(),
            trait_param_kinds,
            aliases: BindingMap::default(),
            alias_types: BindingMap::default(),
            expanding: BTreeSet::new(),
            ty_recursion: 0,
            type_limit: false,
            alias_spans: Vec::new(),
        }
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
            return Some(EffectName::Builtin(
                e,
                crate::types::builtin::RangeIndex::TOP,
            ));
        }
        let module = self.modules.get(binding.module)?;
        if matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib) {
            let path: Vec<_> = module.name.0.iter().skip(1).map(String::as_str).collect();
            if let Some(e) = find_builtin_effect(&path, &binding.name) {
                return Some(EffectName::Builtin(
                    e,
                    crate::types::builtin::RangeIndex::TOP,
                ));
            }
        }
        Some(EffectName::User(id, crate::types::builtin::RangeIndex::TOP))
    }

    pub(super) fn shadowed_prelude_type(&self, id: BindingId, span: Span) -> Option<&str> {
        let binding = self.resolved.bindings.get(id)?;
        let name = binding.name.as_str();
        self.is_shadowed_prelude_type(binding.module, name, span)
            .then_some(name)
    }

    fn is_shadowed_prelude_type(&self, module: ModuleId, name: &str, span: Span) -> bool {
        // 修飾して書く別モジュールの型は、この位置の prelude を隠さない（設計書 02-04「名前の引き方」）。
        usize::try_from(module.0)
            .ok()
            .and_then(|index| self.asts.get(index))
            .is_some_and(|ast| ast.file == span.file)
            && self.modules.get(module).is_some_and(|m| {
                matches!(
                    m.kind,
                    ModuleKind::Entry | ModuleKind::User | ModuleKind::Package
                )
            })
            && (matches!(name, "Unit" | "State")
                || crate::prelude::STDLIB
                    .iter()
                    .any(|m| m.prelude && m.path == [name]))
    }

    pub(super) fn prelude_type_in<'a>(&'a self, types: &[&Ty], span: Span) -> Option<&'a str> {
        let (expected, found) = (types.first()?, types.get(1)?);
        for (user, standard) in [(expected, found), (found, expected)] {
            let mut pending = vec![*user];
            while let Some(ty) = pending.pop() {
                if let Ty::Con(TyCon::Adt(id), _, _) = ty
                    && let Some(adt) = self.out.adts.get(*id)
                    && self.is_shadowed_prelude_type(adt.module, &adt.name, span)
                    && self.contains_prelude_type(standard, &adt.name)
                {
                    return Some(&adt.name);
                }
                Self::push_type_children(ty, &mut pending);
            }
        }
        None
    }
    fn contains_prelude_type(&self, ty: &Ty, name: &str) -> bool {
        let mut pending = vec![ty];
        while let Some(ty) = pending.pop() {
            if let Ty::Con(con, _, _) = ty {
                let same = match con {
                    TyCon::External(_) => false,
                    TyCon::Builtin(id) => {
                        id.def().is_some_and(|def| def.name == name)
                            || find_builtin_type(&[name], name) == Some(*id)
                    }
                    TyCon::Adt(id) => self.out.adts.get(*id).is_some_and(|adt| {
                        adt.name == name
                            && self
                                .modules
                                .get(adt.module)
                                .is_some_and(|m| m.kind == ModuleKind::Prelude)
                    }),
                };
                if same {
                    return true;
                }
            }
            Self::push_type_children(ty, &mut pending);
        }
        false
    }
    fn push_type_children<'t>(ty: &'t Ty, pending: &mut Vec<&'t Ty>) {
        match ty {
            Ty::Con(_, args, _) | Ty::App(_, args) => pending.extend(args.iter().rev()),
            Ty::Fn(f) => {
                pending.extend(&f.effects.failures);
                pending.push(&f.ret);
                pending.extend(f.params.iter().rev());
            }
            Ty::Param(_) | Ty::Rigid { .. } => {}
        }
    }
    pub fn uses(&mut self, uses: Option<&UsesList>, scope: &Scope) -> (EffectSet, bool) {
        let declared = self.declared_uses(uses, scope, false);
        (declared.effects, declared.wrote_io_all)
    }
    fn declared_uses(
        &mut self,
        uses: Option<&UsesList>,
        scope: &Scope,
        file: bool,
    ) -> EffectiveEffects {
        let mut declared = EffectiveEffects::default();
        let mut result = EffectSet::empty();
        let mut all = false;
        let mut variables = 0_u32;
        if let Some(uses) = uses {
            super::effects::check_uses(self, uses, scope);
            for (i, e) in uses.effects.iter().enumerate() {
                let Some(id) = self.reference(e.id) else {
                    continue;
                };
                let failure = Some(id) == self.resolved.stdlib("Benitoite.Failure.Fail");
                let count = e.args.as_ref().map_or(0, Vec::len);
                if (failure && count != 1) || (!failure && e.args.is_some()) {
                    self.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0513)
                            .primary(e.span)
                            .arg(
                                "name",
                                e.path
                                    .iter()
                                    .map(|n| n.text.as_str())
                                    .collect::<Vec<_>>()
                                    .join("."),
                            )
                            .arg("count", if failure { "1" } else { "0" })
                            .build(),
                    );
                    continue;
                }
                let mut atom = EffectSet::empty();
                if failure {
                    if let Some(ty) = e.args.as_ref().and_then(|a| a.first()) {
                        let ty = self.ty(ty, scope);
                        if result.failures.contains(&ty) {
                            super::effects::duplicate_use(self, uses, i);
                        }
                        atom.insert_failure(ty);
                    }
                } else if let Some(index) = scope.effects.get(id) {
                    variables = variables.saturating_add(1);
                    atom.insert_var(EffVar(*index));
                } else if let Some(mut name) = self.effect_name(id) {
                    if let Some(range) = self.resolved.scopes.get(e.id) {
                        match &mut name {
                            EffectName::Builtin(_, scope) | EffectName::User(_, scope) => {
                                *scope = crate::types::builtin::RangeIndex::fixed(range.clone())
                            }
                        }
                    }
                    if name
                        == EffectName::Builtin(
                            BuiltinEffectId::IO_ALL,
                            crate::types::builtin::RangeIndex::TOP,
                        )
                    {
                        all = true;
                        for (i, e) in BUILTIN_EFFECTS.iter().enumerate() {
                            if e.in_io_all
                                && let Ok(i) = u16::try_from(i)
                            {
                                atom.insert_name(EffectName::Builtin(
                                    BuiltinEffectId(i),
                                    crate::types::builtin::RangeIndex::TOP,
                                ));
                            }
                        }
                    } else {
                        atom.insert_name(name);
                    }
                }
                result = result.union(&atom);
                declared.origins.push(EffectOrigin {
                    effects: atom,
                    name: e
                        .path
                        .iter()
                        .map(|n| n.text.as_str())
                        .collect::<Vec<_>>()
                        .join("."),
                    span: e.span,
                    file,
                });
            }
            if variables > 1 {
                self.diagnostic(DiagCode::E0417, uses.span);
            }
        }
        if let Some(uses) = uses {
            self.check_failure_types(&result, scope, uses.span, None);
        }
        declared.effects = result;
        declared.wrote_io_all = all;
        declared
    }
    fn check_failure_types(
        &mut self,
        result: &EffectSet,
        scope: &Scope,
        span: Span,
        individual: Option<Span>,
    ) {
        if result.failures.len() > 1 {
            let mut type_names = vec![String::new(); scope.params.iter().count()];
            for (id, (index, _)) in scope.params.iter() {
                if let Some(name) = self.resolved.bindings.get(id)
                    && let Some(slot) = usize::try_from(*index)
                        .ok()
                        .and_then(|i| type_names.get_mut(i))
                {
                    *slot = name.name.clone();
                }
            }
            let names = TyNames {
                bindings: &self.resolved.bindings,
                adts: &self.out.adts,
                effects: &self.out.effects,
                type_params: &type_names,
                effect_params: &[],
            };
            let expected = result
                .failures
                .first()
                .map(|t| t.show(&names))
                .unwrap_or_default();
            let found = result
                .failures
                .get(1)
                .map(|t| t.show(&names))
                .unwrap_or_default();
            let mut diagnostic = DiagBuilder::new(DiagCode::E0514)
                .primary(span)
                .arg("expected", expected)
                .arg("found", found)
                .help("convert");
            if let Some(span) = individual {
                diagnostic = diagnostic.secondary(span, "individual");
            }
            self.diagnostics.push(diagnostic.build());
        }
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
    #[inline(never)]
    fn ty_inner(&mut self, expr: &TypeExpr, scope: &Scope) -> Ty {
        match expr {
            TypeExpr::Paren(t) => self.ty(&t.inner, scope),
            TypeExpr::Error(_) => unit(),
            TypeExpr::Fn(f) => self.function_type(f, scope),
            TypeExpr::Named(t) => self.named(t, scope),
        }
    }
    // 関数型だけに要る効果と予算の枠を、名前付きの型の各再帰段に積まない
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn function_type(&mut self, f: &FnType, scope: &Scope) -> Ty {
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
        for error in &effects.failures {
            if let Err(limit) = budget.substituted(error, &[], 2) {
                self.type_limit(limit, f.span);
                return unit();
            }
        }
        Ty::Fn(Box::new(FnTy {
            param_names: f.param_names.iter().map(|n| n.text.clone()).collect(),
            params,
            ret,
            effects,
        }))
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
                id,
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
            BindingKind::ExternalType => (TyCon::External(id), 0),
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
                    id,
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
                    self.cache_alias(id, &alias);
                }
                self.expanding.remove(&id);
                if self.invalid.contains(&id) {
                    self.invalid_alias_uses = self.invalid_alias_uses.saturating_add(1);
                    return unit();
                }
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
        if !self.arity(id, &binding.name, arity, args.len(), t.span, true) {
            return unit();
        }
        Ty::Con(
            con,
            args,
            self.resolved.scopes.get(t.id).cloned().map_or(
                crate::types::builtin::RangeIndex::TOP,
                crate::types::builtin::RangeIndex::fixed,
            ),
        )
    }
    fn arity(
        &mut self,
        binding: BindingId,
        name: &str,
        expected: u32,
        found: usize,
        span: Span,
        ctor: bool,
    ) -> bool {
        if usize::try_from(expected).ok() == Some(found) {
            return true;
        }
        let code = if found == 0 && ctor {
            DiagCode::E0426
        } else {
            DiagCode::E0410
        };
        let mut d = DiagBuilder::new(code)
            .arg("name", name)
            .arg("expected", expected.to_string())
            .arg("found", found.to_string())
            .primary(span);
        if code == DiagCode::E0410
            && let Some(shadowed) = self.shadowed_prelude_type(binding, span)
        {
            d = d
                .arg("shadowed", shadowed)
                .note("shadowed")
                .help("prelude_type");
        }
        self.diagnostics.push(d.build());
        false
    }
    pub fn signature(&mut self, f: &FnDecl, scope: Scope, s: Scheme) -> Scheme {
        self.signature_with_file(f, scope, s, None)
    }
    fn signature_with_file(
        &mut self,
        f: &FnDecl,
        scope: Scope,
        s: Scheme,
        file: Option<&EffectiveEffects>,
    ) -> Scheme {
        let before_aliases = self.invalid_alias_uses;
        let (scope, mut s) = self.parameters(&f.type_params, scope, s, true);
        let mut budget = TypeBudget::default();
        if let Err(limit) = budget.enter(1) {
            self.type_limit(limit, f.name.span);
            return s;
        }
        s.params.clear();
        s.param_names.clear();
        // 個々の引数が上限以内でも、関数型として合わせると超えることがある。
        // 具体化で大きな関数型を作る前に、宣言の段で合計を制限する（02-03）。
        for p in &f.params {
            let ty = p.ty.as_ref().map_or_else(unit, |ty| self.ty(ty, &scope));
            if !self.type_child(&mut budget, &ty, p.span) {
                return s;
            }
            s.params.push(ty);
            s.param_names.push(p.name.text.clone());
        }
        s.ret = self.ty(&f.ret, &scope);
        if !self.type_child(&mut budget, &s.ret, f.ret.span()) {
            return s;
        }
        let mut effective = self.declared_uses(f.uses.as_ref(), &scope, false);
        if let Some(file) = file {
            let individual_valid = effective.effects.failures.len() <= 1;
            effective.effects = effective.effects.union(&file.effects);
            effective.wrote_io_all |= file.wrote_io_all;
            effective.origins.extend(file.origins.iter().cloned());
            if individual_valid
                && file.effects.failures.len() <= 1
                && let Some(origin) = file.origins.iter().find(|o| !o.effects.failures.is_empty())
            {
                self.check_failure_types(
                    &effective.effects,
                    &scope,
                    origin.span,
                    f.uses.as_ref().map(|u| u.span),
                );
            }
        }
        for error in &effective.effects.failures {
            if !self.type_child(&mut budget, error, f.name.span) {
                return s;
            }
        }
        s.effects = effective.effects.clone();
        s.wrote_io_all = effective.wrote_io_all;
        // NoFail と本体の行は、ファイル追加後の契約から作る（設計書 02-05「宣言の検査」）。
        s.no_fail = s.signature_no_fail();
        if file.is_some()
            && let Some(id) = self.binding(f.id)
        {
            self.out.effective_effects.insert(id, effective);
        }
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
        if before_aliases != self.invalid_alias_uses
            && let Some(id) = self.binding(f.id)
        {
            self.invalid.insert(id);
        }
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
    fn cache_alias(&mut self, id: BindingId, alias: &AliasDecl) {
        let before = self.diagnostics.len();
        let before_aliases = self.invalid_alias_uses;
        let scope = self.scopes.get(&alias.id).cloned().unwrap_or_default();
        let ty = self.ty(&alias.ty, &scope);
        // Ty は誤りの型を持たない。派生した別名にも印を残し、使用側の
        // 宣言や注釈を ITy::Error にする（設計書 02-05「誤りの報告と検査の継続」）。
        if before != self.diagnostics.len() || before_aliases != self.invalid_alias_uses {
            self.invalid.insert(id);
        }
        if !self.type_limit {
            self.alias_types.insert(id, ty);
        }
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
                    self.cache_alias(id, &alias);
                    self.expanding.remove(&id);
                    if self.type_limit {
                        return;
                    }
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
                            if let Some(uses) = &f.uses {
                                types.extend(
                                    uses.effects.iter().flat_map(|e| e.args.iter().flatten()),
                                );
                            }
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
            f.effects.failures.iter().any(|t| has_effect(t, index))
                || f.effects.vars.contains(&EffVar(index))
                || f.params.iter().any(|t| has_effect(t, index))
                || has_effect(&f.ret, index)
        }
        Ty::Con(_, a, _) | Ty::App(_, a) => a.iter().any(|t| has_effect(t, index)),
        Ty::Param(_) | Ty::Rigid { .. } => false,
    }
}
fn has_param(ty: &Ty, index: u32) -> bool {
    match ty {
        Ty::Param(i) => *i == index,
        Ty::App(i, a) => *i == index || a.iter().any(|t| has_param(t, index)),
        Ty::Con(_, a, _) => a.iter().any(|t| has_param(t, index)),
        Ty::Fn(f) => {
            f.effects.failures.iter().any(|t| has_param(t, index))
                || f.params.iter().any(|t| has_param(t, index))
                || has_param(&f.ret, index)
        }
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
    check_recorded(modules, asts, sources, resolved, require_main, None)
}

/// 検査の寿命内だけ記録先を借用し、既存の型検査の出力と診断の組を保つ。
pub(super) fn check_recorded(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
    require_main: bool,
    observations: Option<&mut Vec<serde_json::Value>>,
) -> (TypeckOutput, Vec<Diagnostic>) {
    let mut d = declaration_context(modules, asts, sources, resolved, require_main);
    if d.type_limit
        || d.diagnostics
            .iter()
            .any(|diag| diag.kind == crate::diag::ReportKind::Internal)
    {
        return (d.out, d.diagnostics);
    }
    // 宣言中の補助検査には可変の集合を使い、本体へ入る直前にだけ固定する
    // （設計書 02-05「型クラスの制約の解決」）。
    d.impl_index = Some(super::traits::shared_table(&d));
    d.scope_inputs =
        super::scope::Inputs::collect(asts, modules, resolved, &d.out.decl_types, &d.out.impls);
    d.out.scope_inputs = std::mem::take(&mut d.scope_inputs).finish();
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
                | Item::ExternalType(_)
                | Item::Error(_) => {}
            }
        }
    }
    d.out
        .scope_inputs
        .finish_interpolations(d.scope_inputs.interpolation_map());
    super::scoped_calls::accept_program(&mut d);
    let tables = super::interval::input::InputTables {
        resolved,
        constants: &d.out.consts,
        literals: &d.out.lit_values,
        range_bounds: &d.out.range_bounds,
        schemes: &d.out.decl_types,
    };
    d.out.interval = match observations {
        Some(sink) => d.interval.analyze_recorded(
            &tables,
            INTERVAL_ANALYSIS_FUEL,
            &mut d.diagnostics,
            Some(sink),
        ),
        None => d
            .interval
            .analyze(&tables, INTERVAL_ANALYSIS_FUEL, &mut d.diagnostics),
    };
    if d.diagnostics.iter().any(Diagnostic::is_error) {
        d.out.main = None;
    }
    (d.out, d.diagnostics)
}

fn declaration_context<'a>(
    modules: &'a ModuleTable,
    asts: &'a [Module],
    sources: &'a SourceTable,
    resolved: &'a ResolveOutput,
    require_main: bool,
) -> Decls<'a> {
    let mut d = Decls::new(modules, asts, sources, resolved);
    failure_declarations(&mut d);
    check_declarations(&mut d, require_main);
    d
}

// 型の構造と制約の検査を共用し、定数・関数本体の検査には入らない
// （設計書 02-01「宣言だけの収集」）。
pub(crate) fn declarations(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
) -> (TypeckOutput, Vec<Diagnostic>) {
    let d = declaration_context(modules, asts, sources, resolved, false);
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
                | Item::ExternalType(_)
                | Item::Error(_) => continue,
            };
            let extensible = top.attrs.iter().any(|attr| attr.name.text == "extensible");
            if extensible
                && ["Benitoite.Result.Result", "Benitoite.Option.Option"]
                    .iter()
                    .any(|name| d.resolved.stdlib(name) == Some(binding))
            {
                d.diagnostics
                    .push(crate::runtime::report::internal_diagnostic(
                        "check",
                        &format!(
                            "the standard `{}` type must not be `@extensible`",
                            name.text
                        ),
                        None,
                        crate::runtime::report::FaultThread::Stage,
                    ));
                return;
            }
            d.out.adts.adts.insert(
                binding,
                AdtDef {
                    extensible,
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
        // 具体型もファイルの空の型パラメータ環境で一度だけ検査する。
        // 各リストの重複はここで検査し、リスト間では集合として合併する（設計書 02-05「宣言の検査」）。
        let before_file = d.diagnostics.len();
        let before_file_aliases = d.invalid_alias_uses;
        let file = d.declared_uses(ast.file_uses.as_ref(), &Scope::default(), true);
        let invalid_file =
            d.diagnostics.len() != before_file || d.invalid_alias_uses != before_file_aliases;
        for top in &ast.decls {
            let Some(binding) = d.binding(top.item.id()) else {
                continue;
            };
            let before = d.diagnostics.len();
            let before_aliases = d.invalid_alias_uses;
            match &top.item {
                Item::Fn(f) => {
                    let s = d.signature_with_file(
                        f,
                        Scope::default(),
                        scheme(vec![], unit()),
                        Some(&file),
                    );
                    d.out.decl_types.insert(binding, s);
                    if invalid_file {
                        d.invalid.insert(binding);
                    }
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
                        crate::types::builtin::RangeIndex::TOP,
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
                            ctor.param_names =
                                crate::base::parameter_names::positional_names(fields.len());
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
                        crate::types::builtin::RangeIndex::TOP,
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
                            access.param_names = vec![crate::base::parameter_names::VALUE.into()];
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
                    s.param_names = fields.iter().map(|f| f.name.clone()).collect();
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
                        if d.invalid.contains(&binding) {
                            break;
                        }
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
                    let name = d.effect_name(binding).unwrap_or(EffectName::User(
                        binding,
                        crate::types::builtin::RangeIndex::TOP,
                    ));
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
                            s.effects.insert_name(name.clone());
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
                Item::Trait(_) | Item::Impl(_) | Item::ExternalType(_) | Item::Error(_) => {}
            }
            if d.type_limit {
                return;
            }
            if d.diagnostics.len() != before || d.invalid_alias_uses != before_aliases {
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
                    | Item::ExternalType(_)
                    | Item::Error(_) => {}
                }
            }
        }
    }
    check_range_signatures(d);
    super::external::check(d);
    super::traits::collect(d);
    summaries(&mut d.out.adts);
    check_entry(d, require_main);
    super::traits::check_impls(d);
}

// 分類は標準の組み込み表にだけ持たせ、解決済みの束縛へ対応を保存する
// （設計書 02-05「型とエフェクトの表現」）。
fn check_range_signatures(d: &mut Decls<'_>) {
    let resolved = d.resolved;
    let builtin = |binding| {
        resolved.bindings.get(binding).and_then(|b| {
            if let BindingKind::BuiltinFn(id) = b.kind {
                Some(id)
            } else {
                resolved.builtin_ops.get(binding).copied()
            }
        })
    };
    // 書き換えが必要な標準署名だけを複製し、利用者の宣言は参照のまま検査する。
    let parameterized = d
        .out
        .decl_types
        .iter()
        .filter_map(|(binding, scheme)| {
            let id = builtin(binding)?;
            let ranges = crate::builtins::table::builtin_range_signature(id)?;
            if ranges.range_count() == 0 {
                return None;
            }
            Some((
                binding,
                crate::builtins::table::parameterize_builtin_signature(id, scheme),
            ))
        })
        .collect::<Vec<_>>();
    let mut failed = BTreeSet::new();
    for (binding, scheme) in parameterized {
        if let Some(scheme) = scheme {
            d.out.decl_types.insert(binding, scheme);
        } else {
            failed.insert(binding);
        }
    }
    for (binding, scheme) in d.out.decl_types.iter() {
        if d.invalid.contains(&binding) {
            continue;
        }
        let valid = if let Some(id) = builtin(binding) {
            if let Some(ranges) = crate::builtins::table::builtin_range_signature(id) {
                d.out.range_signatures.insert(binding, ranges);
            }
            !failed.contains(&binding)
                && crate::builtins::table::builtin_signature_valid(id, scheme)
        } else {
            scheme.fn_ty().indices_valid(0)
        };
        if !valid {
            d.invalid.insert(binding);
            d.diagnostics
                .push(crate::runtime::report::internal_diagnostic(
                    "check",
                    "invalid scope indices or range metadata in a declaration signature",
                    None,
                    crate::runtime::report::FaultThread::Stage,
                ));
        }
    }
}

fn returns_result(d: &Decls<'_>, ty: &Ty) -> bool {
    match ty {
        Ty::Con(TyCon::Adt(id), args, _)
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
        Ty::Fn(_) | Ty::App(..) | Ty::Rigid { .. } | Ty::Con(TyCon::External(_), _, _) => {
            out.always = !key
        }
        Ty::Con(TyCon::Builtin(b), args, _) => {
            if key {
                out.always = matches!(*b, B::FLOAT | B::FLOAT32);
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
        Ty::Con(TyCon::Adt(id), args, _) => {
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

// 標準の同一性を名前解決の表から得る。利用者が同じ綴りを宣言しても一致しない
// （設計書 02-05「型とエフェクトの表現」）。
fn failure_declarations(d: &mut Decls<'_>) {
    let (Some(effect), Some(op)) = (
        d.resolved.stdlib("Benitoite.Failure.Fail"),
        d.resolved.stdlib("Benitoite.Failure.raise"),
    ) else {
        return;
    };
    let s = crate::types::builtin::FAILURE.scheme();
    d.out.decl_types.insert(op, s);
    d.out.effects.insert(
        effect,
        EffectDef {
            binding: effect,
            name: EffectName::User(effect, crate::types::builtin::RangeIndex::TOP),
            display_name: "Failure.Fail".into(),
            ops: vec![op],
        },
    );
}
