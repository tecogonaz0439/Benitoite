//! 型が決まった試行とリソースの制約を解く（設計書 02-05「制約の解決」、01-09・01-10）。
use super::super::{
    TryKind,
    context::{Body, ReturnOwner},
    infer::{Constraint, DictSite, IClassArg, ITy, Reason, TryConstraintAction},
};
use crate::base::NodeId;
use crate::diag::{DiagBuilder, DiagCode};
use crate::types::TyCon;
use crate::types::builtin::BuiltinTypeClass;

pub(super) fn solve(ctx: &mut Body<'_, '_>, final_pass: bool) {
    let mut pending = vec![];
    for c in std::mem::take(&mut ctx.constraints) {
        if matches!(c, Constraint::Try { .. } | Constraint::Resource { .. }) {
            pending.push(c);
        } else {
            ctx.add(c);
        }
    }
    // 外側の try が内側の try の型を待つ場合も、型が決まる限り解き直す
    // （設計書 02-05「制約の解決」の試行）。
    loop {
        let before = pending.len();
        let mut waiting = vec![];
        for c in pending {
            let target = match &c {
                Constraint::Try { target, .. } => target,
                Constraint::Resource { ty, .. } => ty,
                Constraint::Equal { .. }
                | Constraint::Flow { .. }
                | Constraint::OneOf { .. }
                | Constraint::Equality { .. }
                | Constraint::Key { .. }
                | Constraint::Class { .. }
                | Constraint::EffSub { .. } => continue,
            };
            if matches!(ctx.solver.zonk(target), ITy::Var(_)) {
                waiting.push(c);
                continue;
            }
            match c {
                Constraint::Try {
                    target,
                    action,
                    result,
                    node,
                    reason,
                } => {
                    solve_try(ctx, &target, &action, &result, node, &reason);
                }
                Constraint::Resource { ty, reason }
                    if !ctx.solver.contains_error(&ty)
                        && !matches!(ctx.solver.zonk(&ty),
                        ITy::Con(TyCon::Builtin(b), _, _) if b.def().is_some_and(|d| d.class == BuiltinTypeClass::Resource)) =>
                {
                    ctx.diagnostic(
                        DiagBuilder::new(DiagCode::E0443)
                            .arg("ty", ctx.show_type(&ty))
                            .primary(reason.span)
                            .help("resources")
                            .build(),
                    );
                    poison(ctx, &[ty], &reason);
                }
                Constraint::Resource { .. }
                | Constraint::Equal { .. }
                | Constraint::Flow { .. }
                | Constraint::OneOf { .. }
                | Constraint::Equality { .. }
                | Constraint::Key { .. }
                | Constraint::Class { .. }
                | Constraint::EffSub { .. } => {}
            }
        }
        if waiting.len() == before {
            if !final_pass {
                ctx.constraints.extend(waiting);
                break;
            }
            for c in waiting {
                match c {
                    Constraint::Try { target, reason, .. }
                    | Constraint::Resource { ty: target, reason } => {
                        ctx.require_type(target, reason);
                    }
                    Constraint::Equal { .. }
                    | Constraint::Flow { .. }
                    | Constraint::OneOf { .. }
                    | Constraint::Equality { .. }
                    | Constraint::Key { .. }
                    | Constraint::Class { .. }
                    | Constraint::EffSub { .. } => {}
                }
            }
            break;
        }
        pending = waiting;
    }
}
fn solve_try(
    ctx: &mut Body<'_, '_>,
    target: &ITy,
    action: &TryConstraintAction,
    result: &ITy,
    node: NodeId,
    r: &Reason,
) {
    if ctx.solver.contains_error(target)
        || matches!(action, TryConstraintAction::Return { ret } if ctx.solver.contains_error(ret))
    {
        poison(ctx, std::slice::from_ref(result), r);
        return;
    }
    let (kind, con, args) = match ctx.solver.zonk(target) {
        ITy::Con(TyCon::Adt(id), args, _)
            if Some(id) == ctx.decls.resolved.stdlib("Benitoite.Result.Result")
                && args.len() == 2 =>
        {
            (TryKind::Result, TyCon::Adt(id), args)
        }
        ITy::Con(TyCon::Adt(id), args, _)
            if Some(id) == ctx.decls.resolved.stdlib("Benitoite.Option.Option")
                && args.len() == 1 =>
        {
            (TryKind::Option, TyCon::Adt(id), args)
        }
        ITy::Var(_)
        | ITy::Con(..)
        | ITy::Fn(_)
        | ITy::Param(_)
        | ITy::App(..)
        | ITy::Rigid { .. }
        | ITy::Error => {
            ctx.diagnostic(
                DiagBuilder::new(DiagCode::E0440)
                    .arg("ty", ctx.show_type(target))
                    .primary(r.span)
                    .help("kinds")
                    .build(),
            );
            poison(ctx, &[target.clone(), result.clone()], r);
            return;
        }
    };
    let Some(value) = args.first() else {
        return;
    };
    ctx.unify(result, value, r);
    let TryConstraintAction::Return { ret } = action else {
        let TryConstraintAction::Die { span, .. } = action else {
            return;
        };
        if let Some(error) = args.get(1) {
            let Some(class) = ctx.decls.resolved.stdlib("Benitoite.Trait.Show") else {
                super::missing_standard(ctx, "Trait.Show");
                poison(ctx, std::slice::from_ref(result), r);
                return;
            };
            ctx.add(Constraint::Class {
                class,
                arg: IClassArg::Ty(error.clone()),
                site: DictSite::DieShow { node },
                reason: super::super::context::reason(*span, super::super::infer::ReasonKind::Try),
            });
        }
        ctx.try_kinds.insert(node, (kind, action.clone()));
        return;
    };
    let current_ret = ctx.solver.zonk(ret);
    if !matches!(&current_ret, ITy::Var(_))
        && !matches!(&current_ret, ITy::Con(c, a, _) if *c == con && a.len() == args.len())
    {
        let [target_name, return_name] = ctx.show_types([target, ret]);
        let d = DiagBuilder::new(DiagCode::E0441)
            .arg("ty", target_name)
            .arg(
                "needed",
                match kind {
                    TryKind::Result => text::RESULT,
                    TryKind::Option => text::OPTION,
                },
            )
            .arg("declared", return_name)
            .primary(r.span);
        ctx.diagnostic(return_note(ctx, node, d).help("convert").build());
        poison(ctx, &[ret.clone(), result.clone()], r);
        return;
    }
    // try は節の走査の後に解く。既知の戻り値の要素型はそのまま使い、未定なら戻り値の
    // 変数の範囲を引き継ぐ。節内のラムダが剛な型を返せるようにする（01-12 の Δ）。
    let beta = match &current_ret {
        ITy::Var(v) => ctx.solver.fresh_ty_like(*v),
        ITy::Con(_, returned, _) => returned.first().cloned().unwrap_or(ITy::Error),
        ITy::Fn(_) | ITy::Param(_) | ITy::App(..) | ITy::Rigid { .. } | ITy::Error => ITy::Error,
    };
    let mut wanted = vec![beta];
    if let Some(error) = args.get(1) {
        wanted.push(error.clone());
        if let ITy::Con(_, returned, _) = &current_ret
            && let Some(expected) = returned.get(1)
            && ctx.solver.equal(expected, error, r).is_err()
        {
            ctx.solver.clear_escape();
            let [expected_name, error_name, return_name] = ctx.show_types([expected, error, ret]);
            let d = DiagBuilder::new(DiagCode::E0442)
                .arg("expected", expected_name)
                .arg("found", error_name)
                .arg("declared", return_name)
                .primary(r.span);
            ctx.diagnostic(return_note(ctx, node, d).help("map_error").build());
            poison(ctx, &[ret.clone(), target.clone(), result.clone()], r);
            return;
        }
    }
    if ctx.unify(
        ret,
        &ITy::Con(con, wanted, crate::types::builtin::RangeIndex::TOP),
        r,
    ) {
        ctx.try_kinds.insert(node, (kind, action.clone()));
    }
}
#[cold]
#[inline(never)]
fn return_note(ctx: &Body<'_, '_>, node: NodeId, d: DiagBuilder) -> DiagBuilder {
    match ctx.try_owners.get(node) {
        Some(ReturnOwner::Lambda) => d.note("declared_lambda"),
        Some(ReturnOwner::Placeholder(span)) => d
            .secondary(*span, "placeholder_call")
            .note("declared_placeholder"),
        Some(ReturnOwner::Function) | None => d.note("declared"),
    }
}
fn poison(ctx: &mut Body<'_, '_>, tys: &[ITy], r: &Reason) {
    // 誤りの型との単一化が未確定の変数だけを誤りにする（02-05「誤りの報告と検査の継続」）。
    for ty in tys {
        let unified = ctx.solver.equal(ty, &ITy::Error, r).is_ok();
        debug_assert!(unified, "error type must unify");
    }
}
mod text {
    pub(super) const RESULT: &str = "Result";
    pub(super) const OPTION: &str = "Option";
}
