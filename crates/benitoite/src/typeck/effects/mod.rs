//! エフェクトとハンドラ、遅延・リソース・試行の検査（設計書 02-05）。
mod declarations;
mod handle;
mod special;
mod tail;
#[cfg(test)]
mod tests;

use super::{
    context::{Body, fixed, reason},
    decls::{Decls, Scope},
    generate,
    infer::{Constraint, IFnTy, ITy, Reason, ReasonKind},
};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::ast::*;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId as B};
use crate::types::{EffectName, EffectSet, TyCon};

pub(super) fn check_uses(d: &mut Decls<'_>, uses: &UsesList, scope: &Scope) {
    declarations::check_uses(d, uses, scope);
}
pub(super) fn check_entries(d: &mut Decls<'_>) {
    declarations::check_entries(d);
}
pub(super) fn expr(ctx: &mut Body<'_, '_>, e: &Expr) -> ITy {
    match e {
        Expr::Lazy(e) => {
            let effect = ctx.fresh_effect();
            let ty = ctx.block_in(&e.body, effect.clone(), None);
            ctx.add(Constraint::EffSub {
                sub: effect,
                sup: fixed(EffectSet::empty()),
                reason: reason(e.span, ReasonKind::LazyBody),
            });
            ITy::Con(TyCon::Builtin(B::LAZY), vec![ty])
        }
        Expr::With(e) => with(ctx, e),
        Expr::Try(e) => {
            let target = ctx.expr(&e.value);
            let Some(ret) = ctx.ret.clone() else {
                debug_assert!(false, "try outside a function boundary");
                return ITy::Error;
            };
            let result = ctx.fresh_ty();
            ctx.add(Constraint::Try {
                target,
                ret,
                result: result.clone(),
                node: e.id,
                reason: reason(e.span, ReasonKind::Try),
            });
            result
        }
        Expr::Handle(e) => handle::check(ctx, e),
        Expr::Resume(e) => {
            let value = ctx.expr(&e.value);
            let Some(clause) = ctx.clauses.last() else {
                debug_assert!(false, "resume outside a handler clause");
                return ITy::Error;
            };
            let ty = clause.handle_ty.clone();
            ctx.add(Constraint::Flow {
                from: value,
                to: clause.op_ret.clone(),
                reason: reason(e.value.span(), ReasonKind::Resume),
            });
            ty
        }
        Expr::Lit(_)
        | Expr::Interp(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::Paren(_)
        | Expr::List(_)
        | Expr::Call(_)
        | Expr::Record(_)
        | Expr::Binary(_)
        | Expr::Unary(_)
        | Expr::Pipe(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Error(_) => {
            debug_assert!(false, "unexpected expression in effect hook");
            ITy::Error
        }
    }
}

fn with(ctx: &mut Body<'_, '_>, e: &WithExpr) -> ITy {
    for bind in &e.binds {
        let ty = if let Expr::Call(call) = &bind.value
            && let Expr::Name(name) = call.callee.as_ref()
            && ctx
                .decls
                .reference(name.id)
                .is_some_and(|id| Some(id) == ctx.decls.resolved.stdlib("Benitoite.TaskGroup.open"))
            && !call.args.iter().any(|a| matches!(a, Arg::Placeholder(_)))
        {
            direct_open(ctx, call, name)
        } else {
            ctx.expr(&bind.value)
        };
        ctx.add(Constraint::Resource {
            ty: ty.clone(),
            reason: reason(bind.value.span(), ReasonKind::WithResource),
        });
        if let Some(id) = ctx.decls.binding(bind.id) {
            ctx.locals.insert(id, ty.clone());
        }
        ctx.record_type(bind.id, ty);
    }
    ctx.add(Constraint::EffSub {
        sub: fixed(EffectSet {
            names: vec![EffectName::Builtin(BuiltinEffectId::STATE)],
            vars: vec![],
        }),
        sup: ctx.effect.clone(),
        reason: reason(e.span, ReasonKind::WithState),
    });
    ctx.block(&e.body)
}

fn direct_open(ctx: &mut Body<'_, '_>, call: &CallExpr, name: &NameExpr) -> ITy {
    // E3 が直接の呼び出しだけを E4 に許す。引数の中の参照には印を渡さない
    // （実装プラン F07「式の制約の生成」、設計書 02-05「書く位置の検査」）。
    let callee = generate::name(ctx, name, true);
    ctx.record_type(name.id, callee.clone());
    let params: Vec<_> = call.args.iter().map(|_| ctx.fresh_ty()).collect();
    let ret = ctx.fresh_ty();
    let effect = ctx.fresh_effect();
    generate::equal(
        ctx,
        ITy::Fn(Box::new(IFnTy {
            params: params.clone(),
            ret: ret.clone(),
            effect: effect.clone(),
        })),
        callee,
        call.span,
        ReasonKind::Call,
    );
    for (i, (arg, param)) in call.args.iter().zip(params).enumerate() {
        if let Arg::Expr(arg) = arg {
            let ty = ctx.expr(arg);
            generate::flow(
                ctx,
                ty,
                param,
                arg,
                ReasonKind::CallArg {
                    index: u32::try_from(i).unwrap_or(u32::MAX).saturating_add(1),
                },
                None,
                false,
            );
        }
    }
    ctx.add(Constraint::EffSub {
        sub: effect,
        sup: ctx.effect.clone(),
        reason: reason(call.span, ReasonKind::CallEffect),
    });
    ctx.record_type(call.id, ret.clone());
    ret
}

pub(super) fn name(ctx: &mut Body<'_, '_>, name: &NameExpr, direct_with: bool) {
    if !direct_with
        && ctx
            .decls
            .reference(name.id)
            .is_some_and(|id| Some(id) == ctx.decls.resolved.stdlib("Benitoite.TaskGroup.open"))
    {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0505)
                .primary(name.span)
                .help("with")
                .build(),
        );
    }
}
pub(super) fn solve_special(ctx: &mut Body<'_, '_>) {
    special::solve(ctx);
}
pub(super) fn check_body(ctx: &mut Body<'_, '_>) {
    declarations::check_body(ctx);
}
pub(super) fn effect_failure(
    _: &mut Body<'_, '_>,
    _: &Reason,
    effect: &str,
    origin: Span,
) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0503)
        .arg("effect", effect)
        .primary(origin)
        .help("lambda")
        .build()
}
