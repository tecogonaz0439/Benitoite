//! ハンドラの節を剛な型パラメータで検査する（設計書 01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」、02-05）。
use super::super::{
    ClauseInfo, HandleInfo,
    context::{Body, ClauseContext, IArg, reason, substitute},
    infer::{Constraint, IEffect, IFnTy, ITy, ReasonKind},
};
use crate::diag::{DiagBuilder, DiagCode};
use crate::modules::ModuleKind;
use crate::resolve::BindingKind;
use crate::syntax::ast::HandleExpr;
use crate::typeck::infer::IContract;
use crate::types::builtin::BuiltinEffectId;
use crate::types::{EffectName, EffectSet};
use std::collections::BTreeMap;

pub(super) fn check(ctx: &mut Body<'_, '_>, e: &HandleExpr) -> ITy {
    let ty = ctx.fresh_ty();
    let body_effect = ctx.fresh_effect();
    let clause_effect = ctx.fresh_effect();
    let body_ty = ctx.block_in(&e.body, body_effect.clone(), ctx.ret.clone());
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
        let signature = op
            .filter(|_| valid)
            .and_then(|op| ctx.decls.out.decl_types.get(op))
            .cloned();
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
                && op
                    .and_then(|op| ctx.decls.out.decl_types.get(op))
                    .is_some_and(|s| {
                        s.effects
                            .names
                            .contains(&EffectName::Builtin(BuiltinEffectId::STATE))
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
    let mut handled = EffectSet::empty();
    for (_, effect) in ctx.decls.out.effects.iter() {
        if !failure && !effect.ops.is_empty() && effect.ops.iter().all(|op| seen.contains_key(op)) {
            handled.insert_name(effect.name);
        }
    }
    if failure {
        let rest = ctx.fresh_effect();
        ctx.solver.require_no_fail(rest.clone(), e.span);
        ctx.failure_handles.push((e.id, error_ty.clone(), e.span));
        let mut upper = rest.clone();
        upper.failures.push(error_ty);
        ctx.add(Constraint::EffSub {
            sub: body_effect,
            sup: upper,
            reason: reason(e.span, ReasonKind::HandleBody),
        });
        ctx.add(Constraint::EffSub {
            sub: rest,
            sup: ctx.effect.clone(),
            reason: reason(e.span, ReasonKind::HandleBody),
        });
    } else {
        ctx.add(Constraint::EffSub {
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
        sub: clause_effect,
        sup: ctx.effect.clone(),
        reason: reason(e.span, ReasonKind::HandleClause),
    });
    ctx.handlers.insert(e.id, HandleInfo { clauses, handled });
    ty
}
