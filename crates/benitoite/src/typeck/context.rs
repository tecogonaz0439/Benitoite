//! 本体ごとに作って捨てる推論の文脈（設計書 02-05「検査の単位と手順」、ADR 0015）。
use super::decls::{Decls, Scope};
use super::infer::*;
use super::solve::Solver;
use super::{HandleInfo, TryKind};
use crate::base::{BindingId, BindingMap, NodeId, NodeMap, Span};
use crate::diag::Diagnostic;
use crate::syntax::ast::{BindStmt, Block, Expr, MatchExpr, Pattern};
use crate::types::*;

/// 型構成子の引数も値の型と区別して覚え、finalize の後にだけ出力へ移す。
#[derive(Clone)]
pub(super) enum IArg {
    Ty(ITy),
    Head(IHead),
}
/// 囲むハンドラの節の情報（F09 の E3 が積み降ろしする）。
pub(super) struct ClauseContext {
    pub node: NodeId,
    pub op_ret: ITy,
    pub handle_ty: ITy,
}
/// 一つの本体の推論と後検査の記録。子の走査はエフェクトと戻り値を差し替えられる。
pub(super) struct Body<'a, 'd> {
    pub owner: Option<NodeId>,
    pub decls: &'a mut Decls<'d>,
    pub scope: Scope,
    pub scheme: Scheme,
    pub solver: Solver,
    pub constraints: Vec<Constraint>,
    pub locals: BindingMap<ITy>,
    pub expr_types: NodeMap<ITy>,
    pub type_args: NodeMap<(Vec<IArg>, Vec<IEffect>)>,
    pub operand_types: NodeMap<ITy>,
    pub interp_types: NodeMap<ITy>,
    pub lambda_effects: NodeMap<IEffect>,
    pub try_kinds: NodeMap<(TryKind, ITy)>,
    pub handlers: NodeMap<HandleInfo>,
    pub clauses: Vec<ClauseContext>,
    /// 節を辿り終えた後の制約の解決でも、操作が宣言した組み込みの制約を引く
    /// （設計書 02-05「型とエフェクトの表現」、ADR 0312）。
    pub clause_params: NodeMap<Vec<TypeParamInfo>>,
    pub matches: Vec<(MatchExpr, ITy)>,
    pub lambda_returns: Vec<(Block, ITy)>,
    pub bindings: Vec<(BindStmt, ITy)>,
    pub effect: IEffect,
    pub ret: Option<ITy>,
    pub body_effect: IEffect,
    pub diagnostics: Vec<Diagnostic>,
    pub return_annotation: Option<Span>,
    pub expr_stmts: NodeMap<Expr>,
}
impl<'a, 'd> Body<'a, 'd> {
    pub fn new(decls: &'a mut Decls<'d>, scope: Scope, scheme: Scheme) -> Self {
        let mut solver = Solver::default();
        let effect = solver.fresh_effect();
        let ret = Some(lift(&scheme.ret));
        Self {
            owner: None,
            decls,
            scope,
            scheme,
            solver,
            constraints: vec![],
            locals: BindingMap::default(),
            expr_types: NodeMap::default(),
            type_args: NodeMap::default(),
            operand_types: NodeMap::default(),
            interp_types: NodeMap::default(),
            lambda_effects: NodeMap::default(),
            try_kinds: NodeMap::default(),
            handlers: NodeMap::default(),
            clauses: vec![],
            clause_params: NodeMap::default(),
            matches: vec![],
            lambda_returns: vec![],
            bindings: vec![],
            body_effect: effect.clone(),
            effect,
            ret,
            diagnostics: vec![],
            return_annotation: None,
            expr_stmts: NodeMap::default(),
        }
    }
    pub fn fresh_ty(&mut self) -> ITy {
        self.solver.fresh_ty()
    }
    pub fn fresh_head(&mut self) -> IHead {
        self.solver.fresh_head()
    }
    pub fn fresh_effect(&mut self) -> IEffect {
        self.solver.fresh_effect()
    }
    pub fn add(&mut self, c: Constraint) {
        self.constraints.push(c);
    }
    pub fn diagnostic(&mut self, d: Diagnostic) {
        self.diagnostics.push(d);
    }
    pub fn expr(&mut self, e: &Expr) -> ITy {
        super::generate::expr(self, e)
    }
    pub fn block(&mut self, b: &Block) -> ITy {
        super::generate::block(self, b)
    }
    pub fn pattern(&mut self, p: &Pattern) -> ITy {
        super::generate::pattern(self, p)
    }
    pub fn expr_in(&mut self, e: &Expr, effect: IEffect, ret: Option<ITy>) -> ITy {
        let old_e = std::mem::replace(&mut self.effect, effect);
        let old_r = std::mem::replace(&mut self.ret, ret);
        let ty = self.expr(e);
        self.effect = old_e;
        self.ret = old_r;
        ty
    }
    pub fn block_in(&mut self, b: &Block, effect: IEffect, ret: Option<ITy>) -> ITy {
        let old_e = std::mem::replace(&mut self.effect, effect);
        let old_r = std::mem::replace(&mut self.ret, ret);
        let ty = self.block(b);
        self.effect = old_e;
        self.ret = old_r;
        ty
    }
    /// 子のパターンの走査中だけ文脈を差し替える（F10 の P1）。
    pub fn pattern_in(&mut self, p: &Pattern, effect: IEffect, ret: Option<ITy>) -> ITy {
        let old_e = std::mem::replace(&mut self.effect, effect);
        let old_r = std::mem::replace(&mut self.ret, ret);
        let ty = self.pattern(p);
        self.effect = old_e;
        self.ret = old_r;
        ty
    }
    /// フックが確定した型どうしを単一化し、失敗には通常の診断を付ける。
    pub fn unify(&mut self, expected: &ITy, found: &ITy, r: &Reason) -> bool {
        let mut solver = std::mem::take(&mut self.solver);
        let result = solver.equal(expected, found, r);
        if let Err(code) = result {
            solver.failure(self, code, expected, found, r);
        }
        self.solver = solver;
        result.is_ok()
    }
    /// 試行・リソースの型変数を本体の後の E0407 の検査に含める（フック E5）。
    pub fn require_type(&mut self, ty: ITy, r: Reason) {
        self.solver.require_type(ty, r);
    }
    pub fn record_type(&mut self, node: NodeId, ty: ITy) {
        self.expr_types.insert(node, ty);
    }
    pub fn annotation(&mut self, t: &crate::syntax::ast::TypeExpr) -> ITy {
        let before = self.decls.diagnostics.len();
        let ty = self.decls.ty(t, &self.scope);
        if before != self.decls.diagnostics.len() {
            ITy::Error
        } else {
            lift(&ty)
        }
    }
    pub fn solve(&mut self) {
        let mut solver = std::mem::take(&mut self.solver);
        let constraints = std::mem::take(&mut self.constraints);
        solver.solve(self, constraints);
        self.solver = solver;
        super::traits::solve_classes(self);
        super::pattern_ext::check_body(self);
        super::effects::check_body(self);
    }
    pub fn actual_effects(&self) -> EffectSet {
        self.solver.finalize_effect(&self.body_effect)
    }
    pub fn check_type_limits(&mut self, span: Span) {
        // 後から子の変数が決まると、以前検査した親の型も大きくなる。出力へ
        // 移す全ての型を再検査し、単一化の場で使わなかった親も拒否する（02-03）。
        let types = self
            .expr_types
            .iter()
            .map(|(_, t)| t)
            .chain(self.operand_types.iter().map(|(_, t)| t))
            .chain(self.interp_types.iter().map(|(_, t)| t))
            .chain(self.try_kinds.iter().map(|(_, (_, t))| t))
            .chain(self.type_args.iter().flat_map(|(_, (args, _))| {
                args.iter().filter_map(|a| match a {
                    IArg::Ty(t) => Some(t),
                    IArg::Head(_) => None,
                })
            }));
        for ty in types {
            if let Err(limit) = self.solver.zonk_checked(ty) {
                self.diagnostics.push(limit.diagnostic(span));
                break;
            }
        }
    }
    pub fn finish(&mut self) {
        if self
            .diagnostics
            .iter()
            .any(|d| d.code == Some(crate::diag::DiagCode::E0208))
        {
            self.decls.diagnostics.append(&mut self.diagnostics);
            return;
        }
        for (node, t) in self.expr_types.iter() {
            self.decls
                .out
                .expr_types
                .insert(node, self.solver.finalize(t, self.decls.resolved));
        }
        for (node, t) in self.operand_types.iter() {
            self.decls
                .out
                .operand_types
                .insert(node, self.solver.finalize(t, self.decls.resolved));
        }
        for (node, t) in self.interp_types.iter() {
            self.decls
                .out
                .interp_types
                .insert(node, self.solver.finalize(t, self.decls.resolved));
        }
        for (node, e) in self.lambda_effects.iter() {
            self.decls
                .out
                .lambda_effects
                .insert(node, self.solver.finalize_effect(e));
        }
        for (node, (args, effects)) in self.type_args.iter() {
            let tys = args
                .iter()
                .map(|a| match a {
                    IArg::Ty(t) => TypeArg::Ty(self.solver.finalize(t, self.decls.resolved)),
                    IArg::Head(h) => {
                        TypeArg::Head(self.solver.finalize_head(*h, self.decls.resolved))
                    }
                })
                .collect();
            let effects = effects
                .iter()
                .map(|e| self.solver.finalize_effect(e))
                .collect();
            self.decls
                .out
                .type_args
                .insert(node, TypeArgs { tys, effects });
        }
        for (node, (kind, t)) in self.try_kinds.iter() {
            self.decls.out.try_kinds.insert(
                node,
                super::TryInfo {
                    kind: *kind,
                    ret: self.solver.finalize(t, self.decls.resolved),
                },
            );
        }
        for (node, h) in self.handlers.iter() {
            self.decls.out.handlers.insert(node, h.clone());
        }
        self.decls.diagnostics.append(&mut self.diagnostics);
    }
    pub fn instantiate(
        &mut self,
        node: NodeId,
        span: Span,
        binding: BindingId,
    ) -> (ITy, Vec<ITy>, ITy) {
        let Some(s) = self.decls.out.decl_types.get(binding).cloned() else {
            return (ITy::Error, vec![], ITy::Error);
        };
        if self.decls.invalid.contains(&binding) {
            return (ITy::Error, vec![], ITy::Error);
        }
        let args: Vec<_> = s
            .type_params
            .iter()
            .map(|p| match p.kind {
                ParamKind::Value => IArg::Ty(self.fresh_ty()),
                ParamKind::Ctor { .. } => IArg::Head(self.fresh_head()),
            })
            .collect();
        let effs: Vec<_> = s
            .effect_params
            .iter()
            .map(|_| self.fresh_effect())
            .collect();
        self.type_args.insert(node, (args.clone(), effs.clone()));
        for (p, a) in s.type_params.iter().zip(&args) {
            if let (Some(bound), IArg::Ty(t)) = (p.builtin, a) {
                let definition = self.decls.resolved.bindings.get(binding);
                let builtin = definition
                    .is_some_and(|b| matches!(b.kind, crate::resolve::BindingKind::BuiltinFn(_)));
                let name = definition.map_or_else(String::new, |b| {
                    if builtin {
                        self.decls.modules.get(b.module).map_or_else(
                            || b.name.clone(),
                            |m| {
                                format!("{}.{}", m.name.0.last().map_or("", String::as_str), b.name)
                            },
                        )
                    } else {
                        b.name.clone()
                    }
                });
                let reason = reason(
                    span,
                    if builtin {
                        ReasonKind::BuiltinParam { name }
                    } else {
                        ReasonKind::ParamBound { name }
                    },
                );
                self.add(match bound {
                    BuiltinConstraint::Equality => Constraint::Equality {
                        ty: t.clone(),
                        reason,
                    },
                    BuiltinConstraint::Key => Constraint::Key {
                        ty: t.clone(),
                        reason,
                    },
                    BuiltinConstraint::Ordered => Constraint::OneOf {
                        ty: t.clone(),
                        set: TySet::ORD,
                        reason,
                    },
                });
            }
        }
        if !s.class_constraints.is_empty() {
            super::traits::instantiate(self, node, span, &s, &args, &effs);
        }
        let params = s
            .params
            .iter()
            .map(|t| substitute(t, &args, &effs))
            .collect::<Vec<_>>();
        let ret = substitute(&s.ret, &args, &effs);
        let effect = substitute_effect(&s.effects, &effs);
        (
            ITy::Fn(Box::new(IFnTy {
                params: params.clone(),
                ret: ret.clone(),
                effect,
            })),
            params,
            ret,
        )
    }
}
pub(super) fn reason(span: Span, kind: ReasonKind) -> Reason {
    Reason {
        span,
        kind,
        related: None,
        priority: Priority::Normal,
        int_literal: None,
    }
}
pub(super) fn fixed(effects: EffectSet) -> IEffect {
    IEffect {
        fixed: effects,
        var: None,
    }
}
pub(super) fn lift(t: &Ty) -> ITy {
    substitute(t, &[], &[])
}
pub(super) fn substitute(t: &Ty, args: &[IArg], effs: &[IEffect]) -> ITy {
    let arg = |i: u32| usize::try_from(i).ok().and_then(|i| args.get(i));
    match t {
        Ty::Param(i) => match arg(*i) {
            Some(IArg::Ty(t)) => t.clone(),
            _ => ITy::Param(*i),
        },
        Ty::App(i, ts) => ITy::App(
            match arg(*i) {
                Some(IArg::Head(h)) => *h,
                _ => IHead::Param(*i),
            },
            ts.iter().map(|t| substitute(t, args, effs)).collect(),
        ),
        Ty::Con(c, ts) => ITy::Con(*c, ts.iter().map(|t| substitute(t, args, effs)).collect()),
        Ty::Fn(f) => ITy::Fn(Box::new(IFnTy {
            params: f.params.iter().map(|t| substitute(t, args, effs)).collect(),
            ret: substitute(&f.ret, args, effs),
            effect: substitute_effect(&f.effects, effs),
        })),
        Ty::Rigid { clause, index } => ITy::Rigid {
            clause: *clause,
            index: *index,
        },
    }
}
fn substitute_effect(e: &EffectSet, effs: &[IEffect]) -> IEffect {
    let mut out = IEffect {
        fixed: EffectSet {
            names: e.names.clone(),
            vars: vec![],
        },
        var: None,
    };
    for v in &e.vars {
        if let Some(e) = usize::try_from(v.0).ok().and_then(|i| effs.get(i)) {
            out.fixed = out.fixed.union(&e.fixed);
            out.var = e.var;
        } else {
            out.fixed.insert_var(*v);
        }
    }
    out
}

/// 含まれる制約の失敗の共通の診断。E7・P5 は必要なコードと修正案で置き換える。
pub(super) fn effect_diagnostic(
    code: crate::diag::DiagCode,
    r: &Reason,
    effect: &str,
    origin: Span,
) -> Diagnostic {
    use crate::diag::{DiagBuilder, DiagCode};
    let mut d = DiagBuilder::new(code).arg("effect", effect).primary(origin);
    if code == DiagCode::E0501 {
        d = d.help("add_uses");
    }
    if let Some(span) = r.related {
        d = d.secondary(span, "declared");
    }
    d.build()
}
