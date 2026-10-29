//! ハンドラの節を剛な型パラメータで検査する（設計書 01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」、02-05）。
use super::super::{
    ClauseInfo, HandleInfo,
    context::{Body, ClauseContext, IArg, reason, substitute},
    infer::{Constraint, IEffect, IFnTy, ITy, ReasonKind},
};
use crate::base::BindingId;
use crate::diag::{DiagBuilder, DiagCode};
use crate::modules::ModuleKind;
use crate::resolve::BindingKind;
use crate::syntax::ast::HandleExpr;
use crate::typeck::infer::IContract;
use crate::types::builtin::BuiltinEffectId;
use crate::types::scope::Range;
use crate::types::{EffectName, EffectSet};
use std::collections::BTreeMap;

/// 選択の入力は保護本体の効果だけであり、前の推論の型変数は持ち越さない。
#[derive(Clone, PartialEq, Eq)]
pub(in crate::typeck) struct Selection {
    ranges: BTreeMap<BindingId, Vec<Range>>,
    handled: EffectSet,
}

pub(in crate::typeck) struct CheckedHandle<'a> {
    expression: &'a HandleExpr,
    body_effect: IEffect,
    selected: Selection,
}

fn select(ctx: &Body<'_, '_>, e: &HandleExpr, body: &EffectSet) -> Selection {
    let mut ranges = BTreeMap::new();
    let mut seen = BTreeMap::new();
    for clause in &e.clauses {
        let Some(op) = ctx.decls.reference(clause.op.id).filter(|op| {
            ctx.decls
                .resolved
                .bindings
                .get(*op)
                .is_some_and(|b| matches!(b.kind, BindingKind::Op { .. }))
        }) else {
            continue;
        };
        seen.insert(op, ());
        if let Some(signature) = ctx.decls.out.range_signatures.get(op)
            && signature.range_count() != 0
            && let Some(scheme) = ctx.decls.out.decl_types.get(op)
        {
            ranges.insert(op, signature.clause_ranges(scheme, body));
        }
    }
    let failure_op = ctx.decls.resolved.stdlib("Benitoite.Failure.raise");
    let failure = failure_op.is_some_and(|op| seen.contains_key(&op));
    let mut handled = EffectSet::empty();
    for (_, effect) in ctx.decls.out.effects.iter() {
        if !failure && !effect.ops.is_empty() && effect.ops.iter().all(|op| seen.contains_key(op)) {
            handled.insert_name(effect.name.clone());
            for atom in &body.names {
                if same_name(atom, &effect.name) {
                    handled.insert_name(atom.clone());
                }
            }
        }
    }
    Selection { ranges, handled }
}

/// 全ての節からの制約も解いた後、暫定値との一致を必ず確認する。
/// 関数の呼び出し元は不一致の選択だけを更新して本体を作り直す。
/// それ以外の入口でも、不一致の推論結果を受理しない。
pub(in crate::typeck) fn recheck(ctx: &mut Body<'_, '_>) {
    let mut changed_at = None;
    for checked in &ctx.checked_handlers {
        let body = ctx.solver.finalize_effect(&checked.body_effect);
        let selected = select(ctx, checked.expression, &body);
        if selected != checked.selected {
            changed_at.get_or_insert(checked.expression.span);
            ctx.handler_revisions
                .insert(checked.expression.id, selected);
        }
    }
    if let Some(span) = changed_at {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0521)
                .primary(span)
                .help("annotation")
                .build(),
        );
    }
}

/// 節の走査を後へ回す間も、書いた位置の局所と境界を保つ。
pub(in crate::typeck) struct PendingHandle<'a> {
    expression: &'a HandleExpr,
    ty: ITy,
    body_ty: ITy,
    body_effect: IEffect,
    clause_effect: IEffect,
    environment: Environment,
}

impl PendingHandle<'_> {
    pub(in crate::typeck) fn body_effect(&self) -> &IEffect {
        &self.body_effect
    }
}

struct Environment {
    effect: IEffect,
    ret: Option<ITy>,
    clauses: Vec<ClauseContext>,
    rigid_clauses: Vec<crate::base::NodeId>,
    placeholder_boundary: bool,
    return_owner: crate::typeck::context::ReturnOwner,
    return_annotation: Option<crate::base::Span>,
    die_message_boundary: bool,
}
impl Environment {
    fn capture(ctx: &Body<'_, '_>) -> Self {
        Self {
            effect: ctx.effect.clone(),
            ret: ctx.ret.clone(),
            clauses: ctx.clauses.clone(),
            rigid_clauses: ctx.solver.clause_context().to_vec(),
            placeholder_boundary: ctx.placeholder_boundary,
            return_owner: ctx.return_owner,
            return_annotation: ctx.return_annotation,
            die_message_boundary: ctx.die_message_boundary,
        }
    }
    fn restore(self, ctx: &mut Body<'_, '_>) {
        ctx.effect = self.effect;
        ctx.ret = self.ret;
        ctx.clauses = self.clauses;
        ctx.solver.set_clause_context(self.rigid_clauses);
        ctx.placeholder_boundary = self.placeholder_boundary;
        ctx.return_owner = self.return_owner;
        ctx.return_annotation = self.return_annotation;
        ctx.die_message_boundary = self.die_message_boundary;
    }
}

pub(super) fn check(ctx: &mut Body<'_, '_>, e: &HandleExpr) -> ITy {
    let ty = ctx.fresh_ty();
    let body_effect = ctx.fresh_effect();
    let clause_effect = ctx.fresh_effect();
    let body_ty = ctx.block_in(&e.body, body_effect.clone(), ctx.ret.clone());
    let Some(expression) = ctx.decls.handler_syntax.get(e.id).copied() else {
        ctx.diagnostic(crate::runtime::report::internal_diagnostic(
            "check",
            "handler syntax is missing",
            None,
            crate::runtime::report::FaultThread::Stage,
        ));
        return ITy::Error;
    };
    ctx.pending_handlers.push_back(PendingHandle {
        expression,
        ty: ty.clone(),
        body_ty,
        body_effect,
        clause_effect,
        environment: Environment::capture(ctx),
    });
    ty
}

/// 囲む本体の制約を使い切った後、暫定の添字で節を生成する。
pub(in crate::typeck) fn finish_next(ctx: &mut Body<'_, '_>) -> bool {
    let Some(pending) = ctx.pending_handlers.pop_front() else {
        return false;
    };
    let saved = Environment::capture(ctx);
    let mut waiting = std::mem::take(&mut ctx.pending_handlers);
    pending.environment.restore(ctx);
    finish(
        ctx,
        pending.expression,
        pending.ty,
        pending.body_ty,
        pending.body_effect,
        pending.clause_effect,
    );
    ctx.pending_handlers.append(&mut waiting);
    saved.restore(ctx);
    true
}

fn finish<'d>(
    ctx: &mut Body<'_, 'd>,
    e: &'d HandleExpr,
    ty: ITy,
    body_ty: ITy,
    body_effect: IEffect,
    clause_effect: IEffect,
) {
    let inferred_body = ctx.solver.finalize_effect(&body_effect);
    let selected = ctx
        .handler_overrides
        .get(&e.id)
        .cloned()
        .unwrap_or_else(|| select(ctx, e, &inferred_body));
    ctx.add(Constraint::Flow {
        from: body_ty,
        to: ty.clone(),
        reason: reason(e.body.span, ReasonKind::HandleBody),
    });
    let failure_op = ctx.decls.resolved.stdlib("Benitoite.Failure.raise");
    let failure = e
        .clauses
        .iter()
        .any(|c| ctx.decls.reference(c.op.id) == failure_op && failure_op.is_some());
    if failure && e.clauses.len() != 1 {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0518)
                .primary(e.span)
                .help("nest")
                .build(),
        );
    }
    let error_ty = ctx.fresh_ty();
    let mut seen = BTreeMap::new();
    let mut clauses = vec![];
    for clause in &e.clauses {
        let op = ctx.decls.reference(clause.op.id);
        let valid = op.is_some_and(|op| {
            ctx.decls
                .resolved
                .bindings
                .get(op)
                .is_some_and(|b| matches!(b.kind, BindingKind::Op { .. }))
        });
        let signature = op.filter(|_| valid).and_then(|op| {
            if let Some(ranges) = ctx.decls.out.range_signatures.get(op)
                && ranges.range_count() != 0
            {
                let scheme = ctx.decls.out.decl_types.get(op)?;
                let closed = selected
                    .ranges
                    .get(&op)
                    .and_then(|selection| ranges.instantiate(scheme, selection, true));
                if closed.is_none() {
                    ctx.diagnostic(crate::runtime::report::internal_diagnostic(
                        "check",
                        "handler signature scope instantiation failed",
                        None,
                        crate::runtime::report::FaultThread::Stage,
                    ));
                }
                closed
            } else {
                ctx.signature_at_top(op)
            }
        });
        if !valid {
            let mut d = DiagBuilder::new(DiagCode::E0507)
                .primary(clause.op.span)
                .arg(
                    "name",
                    clause
                        .op
                        .path
                        .iter()
                        .map(|n| n.text.as_str())
                        .collect::<Vec<_>>()
                        .join("."),
                );
            if op
                .and_then(|op| ctx.decls.resolved.bindings.get(op))
                .and_then(|b| ctx.decls.modules.get(b.module))
                .is_some_and(|m| matches!(m.kind, ModuleKind::Prelude | ModuleKind::Stdlib))
                && op.and_then(|op| ctx.signature_at_top(op)).is_some_and(|s| {
                    s.effects.names.contains(&EffectName::Builtin(
                        BuiltinEffectId::STATE,
                        crate::types::builtin::RangeIndex::TOP,
                    ))
                })
            {
                d = d.note("state");
            }
            ctx.diagnostic(d.build());
        }
        if let Some(op) = op.filter(|_| valid) {
            if let Some(first) = seen.insert(op, clause.op.span) {
                ctx.diagnostic(
                    DiagBuilder::new(DiagCode::E0508)
                        .primary(clause.op.span)
                        .secondary(first, "first")
                        .arg(
                            "name",
                            clause
                                .op
                                .path
                                .iter()
                                .map(|n| n.text.as_str())
                                .collect::<Vec<_>>()
                                .join("."),
                        )
                        .build(),
                );
                seen.insert(op, first);
            }
            clauses.push(ClauseInfo {
                failure_type: None,
                op,
                tail_resumptive: super::tail::resumptive(&clause.body),
            });
        }
        let (params, ret) = if let Some(s) = signature {
            let args: Vec<_> = s
                .type_params
                .iter()
                .enumerate()
                .map(|(i, _)| {
                    if failure && i == 1 {
                        return IArg::Ty(error_ty.clone());
                    }
                    IArg::Ty(ITy::Rigid {
                        clause: clause.id,
                        index: u32::try_from(i).unwrap_or(u32::MAX),
                    })
                })
                .collect();
            ctx.clause_params.insert(clause.id, s.type_params.clone());
            ctx.solver
                .clause_constraints
                .insert(clause.id, s.class_constraints.clone());
            ctx.clause_ops.insert(
                clause.id,
                (
                    clause
                        .op
                        .path
                        .iter()
                        .map(|n| n.text.as_str())
                        .collect::<Vec<_>>()
                        .join("."),
                    clause.op.span,
                ),
            );
            (
                s.params
                    .iter()
                    .map(|t| substitute(t, &args, &[]))
                    .collect::<Vec<_>>(),
                substitute(&s.ret, &args, &[]),
            )
        } else {
            (vec![ITy::Error; clause.params.len()], ITy::Error)
        };
        let arity_ok = params.len() == clause.params.len();
        if !arity_ok {
            // 誤りの型を含むと単一化は個数の検査も省くため、個数だけを示す関数の型で検査する
            // （設計書 02-05「誤りの報告と検査の継続」）。
            let unit = super::super::generate::basic(crate::types::builtin::BuiltinTypeId::UNIT);
            ctx.unify(
                &ITy::Fn(Box::new(IFnTy {
                    contract: IContract::Known(crate::base::parameter_names::positional_names(
                        params.len(),
                    )),
                    params: vec![unit.clone(); params.len()],
                    ret: unit.clone(),
                    effect: IEffect::default(),
                })),
                &ITy::Fn(Box::new(IFnTy {
                    contract: IContract::Known(crate::base::parameter_names::positional_names(
                        clause.params.len(),
                    )),
                    params: vec![unit.clone(); clause.params.len()],
                    ret: unit,
                    effect: IEffect::default(),
                })),
                &reason(clause.op.span, ReasonKind::HandleClause),
            );
        }
        for (i, param) in clause.params.iter().enumerate() {
            let t = if arity_ok {
                params.get(i).cloned().unwrap_or(ITy::Error)
            } else {
                ITy::Error
            };
            if let Some(id) = ctx.decls.binding(param.id) {
                ctx.locals.insert(id, t.clone());
            }
            ctx.record_type(param.id, t);
        }
        ctx.clauses.push(ClauseContext {
            failure,
            op_ret: ret,
            handle_ty: ty.clone(),
        });
        ctx.solver.enter_clause(clause.id);
        let t = ctx.block_in(&clause.body, clause_effect.clone(), ctx.ret.clone());
        ctx.solver.leave_clause();
        ctx.clauses.pop();
        ctx.add(Constraint::Flow {
            from: t,
            to: ty.clone(),
            reason: reason(clause.body.span, ReasonKind::HandleClause),
        });
    }
    let handled = selected.handled.clone();
    ctx.checked_handlers.push(CheckedHandle {
        expression: e,
        body_effect: body_effect.clone(),
        selected,
    });
    if failure {
        let rest = ctx.fresh_effect();
        ctx.solver.require_no_fail(rest.clone(), e.span);
        ctx.failure_handles.push((e.id, error_ty.clone(), e.span));
        let mut upper = rest.clone();
        upper.failures.push(error_ty);
        ctx.add(Constraint::EffSub {
            relation: crate::typeck::infer::EffectRelation::Structural,
            sub: body_effect,
            sup: upper,
            reason: reason(e.span, ReasonKind::HandleBody),
        });
        ctx.add(Constraint::EffSub {
            relation: crate::typeck::infer::EffectRelation::Structural,
            sub: rest,
            sup: ctx.effect.clone(),
            reason: reason(e.span, ReasonKind::HandleBody),
        });
    } else {
        ctx.add(Constraint::EffSub {
            relation: crate::typeck::infer::EffectRelation::Structural,
            sub: body_effect,
            sup: IEffect {
                failures: vec![],
                fixed: handled.clone(),
                var: clause_effect.var,
            },
            reason: reason(e.span, ReasonKind::HandleBody),
        });
    }
    ctx.add(Constraint::EffSub {
        relation: crate::typeck::infer::EffectRelation::Structural,
        sub: clause_effect,
        sup: ctx.effect.clone(),
        reason: reason(e.span, ReasonKind::HandleClause),
    });
    ctx.handlers.insert(e.id, HandleInfo { clauses, handled });
}

fn same_name(left: &EffectName, right: &EffectName) -> bool {
    match (left, right) {
        (EffectName::Builtin(left, _), EffectName::Builtin(right, _)) => left == right,
        (EffectName::User(left, _), EffectName::User(right, _)) => left == right,
        (EffectName::Builtin(_, _), EffectName::User(_, _))
        | (EffectName::User(_, _), EffectName::Builtin(_, _)) => false,
    }
}
