//! 呼び出しの対応表と既知の契約への制約（設計書 02-05「出力」「制約の生成」）。
use super::CallPlan;
use super::context::{Body, reason};
use super::generate::{declaration_params, integer_literal};
use super::infer::*;
use super::solve::Solver;
use crate::base::{BindingId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::resolve::BindingKind;
use crate::syntax::ast::{CallExpr, Expr};
use std::collections::BTreeSet;

struct CallArgument {
    ty: ITy,
    name: Option<(String, Span)>,
    reason: Reason,
    hole: bool,
}
/// 式を一度だけ辿った結果を保存し、宣言・注釈の制約を解いてから対応を決める。
pub(super) struct PendingCall {
    node: NodeId,
    span: Span,
    callee_span: Span,
    declaration_span: Option<Span>,
    callee: ITy,
    value_signature: Option<Box<IFnTy>>,
    ret: ITy,
    effect: IEffect,
    args: Vec<CallArgument>,
    parameter_spans: Vec<Option<Span>>,
    direct_ctor: bool,
    direct_callee: Option<BindingId>,
    inserted: Option<CallArgument>,
    partial_signature: Option<IFnTy>,
    positional_params: Option<Vec<ITy>>,
}

impl PendingCall {
    pub(super) fn result_var(&self) -> Option<TyVar> {
        if self.partial_signature.is_none()
            && let ITy::Var(v) = &self.ret
        {
            Some(*v)
        } else {
            None
        }
    }

    fn inference_help(&self) -> &'static str {
        if self.inserted.is_some() || self.partial_signature.is_some() {
            "bind"
        } else {
            "annotation"
        }
    }
}

/// 引数の並びをまだ対応させず、戻り値・個数・エフェクトだけを接続する。
/// 呼び出しのラベルから契約順を作らない（設計書 02-05「制約の生成」）。
pub(super) fn prepare(solver: &mut Solver, call: &PendingCall) -> Option<Vec<Constraint>> {
    if call.direct_ctor || matches!(solver.zonk(&call.callee), ITy::Error) {
        return None;
    }
    let (contract, params) = match solver.zonk(&call.callee) {
        ITy::Var(v) => (
            solver.fresh_contract(),
            call.positional_params.clone().unwrap_or_else(|| {
                (0..call
                    .args
                    .len()
                    .saturating_add(usize::from(call.inserted.is_some())))
                    .map(|_| solver.fresh_ty_like(v))
                    .collect()
            }),
        ),
        ITy::Fn(f) if matches!(solver.resolve_contract(&f.contract), IContract::Var(_)) => {
            (f.contract, f.params)
        }
        ITy::Con(..)
        | ITy::Fn(_)
        | ITy::Param(_)
        | ITy::App(..)
        | ITy::Rigid { .. }
        | ITy::Error => {
            return None;
        }
    };
    let positional_argument = call
        .args
        .first()
        .filter(|a| {
            call.args.len() == 1
                && a.name.is_none()
                && call.inserted.is_none()
                && call.partial_signature.is_none()
        })
        .map(|a| (a.ty.clone(), params.first().cloned(), a.reason.clone()));
    let mut constraints = vec![Constraint::Equal {
        expected: ITy::Fn(Box::new(IFnTy {
            contract,
            params,
            ret: call.ret.clone(),
            effect: call.effect.clone(),
        })),
        found: call.callee.clone(),
        reason: reason(call.span, ReasonKind::Call),
    }];
    // 位置が一意な一引数の型だけを結び、契約名の変数は未確定のまま保つ。
    // 自己適用の無限型を未確定契約の診断で隠さない（設計書 02-05「制約の解決」）。
    if let Some((from, Some(to), reason)) = positional_argument {
        constraints.push(Constraint::Flow { from, to, reason });
    }
    Some(constraints)
}

pub(super) fn ready(solver: &Solver, call: &PendingCall) -> bool {
    if call.direct_ctor || matches!(solver.zonk(&call.callee), ITy::Error) {
        return true;
    }
    match solver.zonk(&call.callee) {
        ITy::Fn(f) => !matches!(solver.resolve_contract(&f.contract), IContract::Var(_)),
        ITy::Var(_) => false,
        ITy::Con(..) | ITy::Param(_) | ITy::App(..) | ITy::Rigid { .. } | ITy::Error => true,
    }
}

/// 子の独立した誤りに推論失敗を重ねず、未確定の関数型は誤りとして回復する。
pub(super) fn unresolved(ctx: &mut Body<'_, '_>, solver: &mut Solver, call: PendingCall) {
    if !matches!(solver.zonk(&call.callee), ITy::Error)
        && !call.args.iter().any(|a| solver.contains_error(&a.ty))
        && !has_child_error(ctx, call.span)
    {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0455)
                .primary(call.callee_span)
                .help(call.inference_help())
                .build(),
        );
    }
    // 契約を決められない関数全体を無効にする。部分の Error との単一化は
    // 正常な部分を保つため、この報告済みの関数を無効にする代わりにはならない。
    solver.poison(&[call.callee, call.ret.clone()]);
    solver.resolved_result(&call.ret);
}

/// 型が既知でも辞書の失敗などで子が不正な場合は、派生する推論診断を抑える。
/// 名前の対応の独立した誤りには使わない（設計書 02-05「誤りの報告と検査の継続」）。
pub(super) fn has_child_error(ctx: &Body<'_, '_>, span: Span) -> bool {
    ctx.diagnostics.iter().any(|d| {
        d.is_error()
            && d.primary.as_ref().is_some_and(|p| {
                p.span.file == span.file && p.span.start >= span.start && p.span.end <= span.end
            })
    })
}

pub(super) fn generate(
    ctx: &mut Body<'_, '_>,
    e: &CallExpr,
    insert: Option<&Expr>,
    partial_ret: Option<ITy>,
    callee: Option<ITy>,
) -> ITy {
    // 左辺は呼ぶ式より先に一度だけ検査する。部分適用では呼ぶ式・固定引数も
    // 生成ラムダの文脈で検査する（設計書 01-02「部分適用のプレースホルダ」）。
    let inserted = insert.map(|value| CallArgument {
        ty: ctx.expr(value),
        name: None,
        reason: reason(value.span(), ReasonKind::CallArg { index: 1 }),
        hole: false,
    });
    let callee = callee.unwrap_or_else(|| ctx.expr(&e.callee));
    if let Some(ret) = &partial_ret
        && let ITy::Fn(f) = ctx.solver.zonk(&callee)
    {
        // return の Flow より先に生成ラムダの戻り値を結び、誤りを返す値で報告する。
        // 名前の対応・個数は、この等しさから推測しない（設計書 02-05「制約の生成」）。
        let mut r = reason(e.span, ReasonKind::Call);
        r.priority = Priority::Declared;
        ctx.add(Constraint::Equal {
            expected: f.ret,
            found: ret.clone(),
            reason: r,
        });
    }
    let mut args = vec![];
    let mut slots = vec![];
    for arg in &e.args {
        let (ty, mut r, hole) = if let Some(value) = arg.expr() {
            let ty = ctx.expr(value);
            let mut r = reason(value.span(), ReasonKind::CallArg { index: 0 });
            r.int_literal = integer_literal(ctx, value);
            (ty, r, false)
        } else if let Some(p) = arg.placeholder() {
            let ty = ctx.fresh_ty();
            ctx.record_type(p.id, ty.clone());
            slots.push(ty.clone());
            (ty, reason(p.span, ReasonKind::CallArg { index: 0 }), true)
        } else {
            return ITy::Error;
        };
        r.priority = if partial_ret.is_some() {
            Priority::Declared
        } else {
            r.priority
        };
        args.push(CallArgument {
            ty,
            name: match arg {
                crate::syntax::ast::Arg::Named(a) => Some((a.name.text.clone(), a.name.span)),
                crate::syntax::ast::Arg::Expr(_) | crate::syntax::ast::Arg::Placeholder(_) => None,
            },
            reason: r,
            hole,
        });
    }
    let partial = partial_ret.is_some();
    let ret = partial_ret.unwrap_or_else(|| ctx.fresh_ty());
    let effect = ctx.fresh_effect();
    ctx.add(Constraint::EffSub {
        sub: effect.clone(),
        sup: ctx.effect.clone(),
        reason: reason(e.span, ReasonKind::CallEffect),
    });
    let partial_signature = partial.then(|| {
        let latent = ctx.effect.clone();
        ctx.lambda_effects.insert(e.id, latent.clone());
        IFnTy {
            contract: ctx.solver.fresh_contract(),
            params: slots,
            ret: ret.clone(),
            effect: latent,
        }
    });
    let output = partial_signature
        .as_ref()
        .map_or_else(|| ret.clone(), |f| ITy::Fn(Box::new(f.clone())));
    let direct_ctor = matches!(e.callee.as_ref(), Expr::Name(n) if ctx.decls.resolved.binding_of_ref(n.id).is_some_and(|b| matches!(b.kind, BindingKind::Ctor { .. })));
    let positional_params = (args.iter().all(|a| a.name.is_none())
        && inserted.is_none()
        && partial_signature.is_none())
    .then(|| (0..args.len()).map(|_| ctx.fresh_ty()).collect());
    let declaration_span = if let Expr::Name(n) = e.callee.as_ref() {
        ctx.decls.resolved.binding_of_ref(n.id).and_then(|b| b.span)
    } else {
        None
    };
    let call = PendingCall {
        node: e.id,
        span: e.span,
        callee_span: e.callee.span(),
        declaration_span,
        value_signature: match &callee {
            ITy::Fn(_) => None,
            ITy::Var(_) => match ctx.solver.value_shape(&callee) {
                ITy::Fn(f) => Some(f),
                ITy::Var(_)
                | ITy::Con(..)
                | ITy::Param(_)
                | ITy::App(..)
                | ITy::Rigid { .. }
                | ITy::Error => None,
            },
            ITy::Con(..) | ITy::Param(_) | ITy::App(..) | ITy::Rigid { .. } | ITy::Error => None,
        },
        callee,
        ret,
        effect,
        args,
        direct_ctor,
        direct_callee: if let Expr::Name(n) = e.callee.as_ref()
            && inserted.is_none()
            && !partial
        {
            ctx.decls.reference(n.id).filter(|id| {
                ctx.decls.resolved.bindings.get(*id).is_some_and(|b| {
                    matches!(
                        b.kind,
                        BindingKind::Fn | BindingKind::BuiltinFn(_) | BindingKind::ImplFn { .. }
                    )
                })
            })
        } else {
            None
        },
        inserted,
        partial_signature,
        positional_params,
        parameter_spans: declaration_params(ctx, &e.callee),
    };
    // 対応が確定した位置指定はその場で同じ検査へ渡し、戻り値や剛な型の
    // 制約の生成順を保つ（設計書 02-05「制約の生成」「制約の解決」）。
    if call.args.iter().all(|a| a.name.is_none()) && ready(&ctx.solver, &call) {
        let mut solver = std::mem::take(&mut ctx.solver);
        let constraints = resolve(ctx, &mut solver, call);
        ctx.solver = solver;
        for constraint in constraints {
            ctx.add(constraint);
        }
    } else {
        ctx.solver.pending_result(&call.ret);
        ctx.named_calls.push(call);
    }
    output
}

/// 対応の誤りから不足と型不一致を派生させない（設計書 02-05「誤りの報告と検査の継続」）。
pub(super) fn resolve(
    ctx: &mut Body<'_, '_>,
    solver: &mut Solver,
    call: PendingCall,
) -> Vec<Constraint> {
    let ret = call.ret.clone();
    let slots = call
        .partial_signature
        .as_ref()
        .map(|f| f.params.clone())
        .unwrap_or_default();
    let span = call.span;
    let inherited_cause = solver.diagnosed_cause(&call.callee);
    let constraints = resolve_arguments(ctx, solver, call);
    if constraints.is_empty() {
        // 呼び出しの範囲に一次位置が収まる最後の誤りを原因にする。
        // 引数内の誤りも含むが、回復させるのは未確定な結果と穴の型だけである。
        let cause = inherited_cause.or_else(|| {
            ctx.diagnostics
                .iter()
                .rev()
                .filter(|d| d.is_error())
                .find_map(|d| {
                    let primary = d.primary.as_ref()?.span;
                    (primary.file == span.file
                        && primary.start >= span.start
                        && primary.end <= span.end)
                        .then_some(primary)
                })
        });
        // 対応の誤りから型の曖昧さを派生させない（設計書 02-05「誤りの報告と検査の継続」）。
        for ty in std::iter::once(&ret).chain(&slots) {
            if let Some(cause) = cause {
                solver.diagnose_result(ty, cause);
            }
            let _recovered = solver.equal(ty, &ITy::Error, &reason(span, ReasonKind::Call));
        }
    }
    solver.resolved_result(&ret);
    solver.refresh_diagnosed();
    constraints
}

fn resolve_arguments(
    ctx: &mut Body<'_, '_>,
    solver: &mut Solver,
    call: PendingCall,
) -> Vec<Constraint> {
    if matches!(solver.zonk(&call.callee), ITy::Error) {
        return vec![];
    }
    if call.direct_ctor
        && let Some((_, span)) = call.args.iter().find_map(|a| a.name.as_ref())
    {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0456)
                .primary(*span)
                .help("bind")
                .build(),
        );
        return vec![];
    }
    let callee = solver.zonk(&call.callee);
    let ITy::Fn(f) = callee else {
        let code = if matches!(callee, ITy::Var(_)) {
            DiagCode::E0455
        } else {
            DiagCode::E0403
        };
        let mut d = DiagBuilder::new(code).primary(
            if code == DiagCode::E0403 && call.args.iter().all(|a| a.name.is_none()) {
                call.span
            } else {
                call.callee_span
            },
        );
        if code == DiagCode::E0403 {
            d = d.arg("found", ctx.show_type_with(solver, &callee));
        } else {
            d = d.help(call.inference_help());
        }
        ctx.diagnostic(d.build());
        return vec![];
    };
    let IContract::Known(names) = solver.resolve_contract(&f.contract) else {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0455)
                .primary(call.callee_span)
                .help(call.inference_help())
                .build(),
        );
        return vec![];
    };
    if names.len() != f.params.len() || names.iter().collect::<BTreeSet<_>>().len() != names.len() {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0455)
                .primary(call.callee_span)
                .help(call.inference_help())
                .build(),
        );
        return vec![];
    }
    if let Some(first) = call.args.first()
        && let Some(changed) = call
            .args
            .iter()
            .find(|a| a.name.is_some() != first.name.is_some())
    {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0450)
                .primary(
                    changed
                        .name
                        .as_ref()
                        .map_or(changed.reason.span, |(_, s)| *s),
                )
                .secondary(
                    first.name.as_ref().map_or(first.reason.span, |(_, s)| *s),
                    "first",
                )
                .build(),
        );
        return vec![];
    }
    let positional = call.args.first().is_some_and(|a| a.name.is_none());
    let supplied = call
        .args
        .len()
        .saturating_add(usize::from(call.inserted.is_some()));
    if positional && !call.direct_ctor && names.len() > 1 {
        let mut diagnostic = DiagBuilder::new(DiagCode::E0449)
            .arg("names", super::text::parameter_names(&names))
            .primary(call.args.first().map_or(call.span, |a| a.reason.span))
            .note("available");
        if supplied == names.len() && call.args.iter().all(|a| !a.hole) {
            let offset = usize::from(call.inserted.is_some());
            let edits = call
                .args
                .iter()
                .zip(names.iter().skip(offset))
                .map(|(arg, name)| {
                    let mut span = arg.reason.span;
                    span.end = span.start;
                    Edit {
                        span,
                        replacement: format!("{name}: "),
                    }
                })
                .collect();
            diagnostic = diagnostic.help_edits("named", edits);
        }
        ctx.diagnostic(diagnostic.build());
        return vec![];
    }
    if (positional || call.args.is_empty()) && supplied != names.len() {
        let mut diagnostic = DiagBuilder::new(DiagCode::E0402)
            .arg("expected", names.len().to_string())
            .arg("found", supplied.to_string())
            .primary(call.span);
        if let Some(span) = call.declaration_span {
            diagnostic = diagnostic.secondary(span, "declared");
        }
        ctx.diagnostic(diagnostic.build());
        return vec![];
    }
    let mut occupied = vec![None; names.len()];
    if let Some(inserted) = &call.inserted
        && let Some(slot) = occupied.first_mut()
    {
        *slot = Some(inserted.reason.span);
    }
    let mut positions = vec![];
    let mut invalid = false;
    for (source, a) in call.args.iter().enumerate() {
        let Some((name, span)) = &a.name else {
            positions.push(
                u32::try_from(source)
                    .unwrap_or(u32::MAX)
                    .saturating_add(u32::from(call.inserted.is_some())),
            );
            if let Some(slot) =
                occupied.get_mut(source.saturating_add(usize::from(call.inserted.is_some())))
            {
                *slot = Some(a.reason.span);
            }
            continue;
        };
        let Some(i) = names.iter().position(|n| n == name) else {
            ctx.diagnostic(
                DiagBuilder::new(DiagCode::E0451)
                    .arg("name", name)
                    .arg("names", super::text::parameter_names(&names))
                    .primary(*span)
                    .note("available")
                    .build(),
            );
            invalid = true;
            continue;
        };
        if let Some(first) = occupied.get(i).copied().flatten() {
            ctx.diagnostic(
                DiagBuilder::new(DiagCode::E0452)
                    .arg("name", name)
                    .primary(*span)
                    .secondary(first, "first")
                    .build(),
            );
            invalid = true;
        } else if let Some(slot) = occupied.get_mut(i) {
            *slot = Some(*span);
        }
        positions.push(u32::try_from(i).unwrap_or(u32::MAX));
    }
    if invalid {
        return vec![];
    }
    let missing: Vec<_> = names
        .iter()
        .zip(&occupied)
        .filter(|(_, slot)| slot.is_none())
        .map(|(n, _)| n.clone())
        .collect();
    if !missing.is_empty() {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0453)
                .arg("names", super::text::parameter_names(&missing))
                .primary(call.span)
                .build(),
        );
        return vec![];
    }
    let Ok(arity) = u32::try_from(names.len()) else {
        return vec![];
    };
    let hole_names: Vec<_> = call
        .args
        .iter()
        .zip(&positions)
        .filter(|(a, _)| a.hole)
        .filter_map(|(_, i)| names.get(usize::try_from(*i).ok()?).cloned())
        .collect();
    ctx.call_plans.insert(
        call.node,
        CallPlan {
            direct_callee: call.direct_callee,
            arity,
            source_to_param: positions.clone(),
            inserted_first: call.inserted.is_some(),
            hole_names: hole_names.clone(),
        },
    );
    // 型変数は呼び出し位置の節の範囲で作ったものを使い、遅延中に範囲を失わない
    // （設計書 02-05「型とエフェクトの表現」）。
    // 正常な宣言の結果は引数の誤りに依存しない。汎用の型変数だけは
    // 構成子の型引数として値から結果へ伝わる（02-05「誤りの報告と検査の継続」）。
    let value_signature = match &call.callee {
        ITy::Fn(original) => original.as_ref(),
        ITy::Var(_)
        | ITy::Con(..)
        | ITy::Param(_)
        | ITy::App(..)
        | ITy::Rigid { .. }
        | ITy::Error => call.value_signature.as_deref().unwrap_or(&f),
    };
    solver.record_value(&call.ret, &value_signature.ret);
    for (arg, position) in call.args.iter().zip(&positions) {
        if let Some(param) = usize::try_from(*position)
            .ok()
            .and_then(|i| value_signature.params.get(i))
        {
            solver.record_value(param, &arg.ty);
        }
    }
    let params = call.positional_params.unwrap_or_else(|| f.params.clone());
    let mut call_reason = reason(call.span, ReasonKind::Call);
    call_reason.related = call.declaration_span;
    let mut constraints = vec![Constraint::Equal {
        expected: ITy::Fn(Box::new(IFnTy {
            contract: f.contract.clone(),
            params: params.clone(),
            ret: call.ret,
            effect: call.effect,
        })),
        found: call.callee,
        reason: call_reason,
    }];
    if let Some(signature) = call.partial_signature {
        let mut expected = signature.clone();
        expected.contract = IContract::Known(hole_names);
        constraints.push(Constraint::Equal {
            expected: ITy::Fn(Box::new(expected)),
            found: ITy::Fn(Box::new(signature)),
            reason: reason(call.span, ReasonKind::Call),
        });
    }
    let mut arguments: Vec<_> = call.args.into_iter().zip(positions).collect();
    if let Some(a) = call.inserted {
        arguments.insert(0, (a, 0));
    }
    for (mut a, position) in arguments {
        let Some(i) = usize::try_from(position).ok() else {
            continue;
        };
        let Some(param) = params.get(i) else {
            continue;
        };
        a.reason.kind = ReasonKind::CallArg {
            index: position.saturating_add(1),
        };
        a.reason.related = call.parameter_spans.get(i).copied().flatten();
        constraints.push(Constraint::Flow {
            from: a.ty,
            to: param.clone(),
            reason: a.reason,
        });
    }
    constraints
}

// 専用操作の対象は普通の式として検査しない。Unit の内部スロットはラベル・個数を
// 既存の検査へ渡す印であり、対象の式や局所束縛の型の表には書かない
// （設計書 02-05「出力」「制約の生成」）。
pub(super) fn builder(
    ctx: &mut Body<'_, '_>,
    e: &CallExpr,
    class: crate::resolve::builders::BuilderClass,
    kind: Option<&super::BuilderKind>,
    op: Option<crate::resolve::builders::BuilderOp>,
    ret: ITy,
) {
    use crate::resolve::builders::{BuilderClass, BuilderOp};
    use crate::syntax::ast::Arg;
    use crate::types::{TyCon, builtin::BuiltinTypeId as B};
    let names = class
        .operations()
        .iter()
        .find(|contract| contract.op == op)
        .map(|contract| {
            contract
                .labels
                .iter()
                .map(|n| (*n).to_owned())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let unit = super::generate::basic(B::UNIT);
    let mut params = if op.is_some() {
        vec![unit.clone()]
    } else {
        vec![]
    };
    let element = match kind {
        Some(super::BuilderKind::List(t)) => super::context::lift(t),
        None if class == BuilderClass::List => ctx.fresh_ty(),
        Some(super::BuilderKind::String | super::BuilderKind::Bytes) | None => unit.clone(),
    };
    match op {
        Some(BuilderOp::Append) => params.push(match class {
            BuilderClass::String => super::generate::basic(B::STRING),
            BuilderClass::List => element,
            BuilderClass::Bytes => super::generate::basic(B::BYTE),
        }),
        Some(BuilderOp::AppendAll) => params.push(match class {
            BuilderClass::String => ITy::Con(
                TyCon::Builtin(B::LIST),
                vec![super::generate::basic(B::STRING)],
            ),
            BuilderClass::List => ITy::Con(TyCon::Builtin(B::LIST), vec![element]),
            BuilderClass::Bytes => super::generate::basic(B::BYTES),
        }),
        None | Some(BuilderOp::Copy | BuilderOp::Length) => {}
    }
    let mut args = Vec::new();
    for (index, arg) in e.args.iter().enumerate() {
        let Some(value) = arg.expr() else { continue };
        let target = op.is_some()
            && match arg {
                Arg::Named(a) => a.name.text == "builder",
                Arg::Expr(_) => index == 0,
                Arg::Placeholder(_) => false,
            };
        let ty = if target {
            unit.clone()
        } else {
            ctx.expr(value)
        };
        args.push(CallArgument {
            ty,
            name: match arg {
                Arg::Named(a) => Some((a.name.text.clone(), a.name.span)),
                Arg::Expr(_) | Arg::Placeholder(_) => None,
            },
            reason: reason(value.span(), ReasonKind::CallArg { index: 0 }),
            hole: false,
        });
    }
    let effect = super::context::fixed(crate::types::EffectSet::empty());
    let callee = ITy::Fn(Box::new(IFnTy {
        contract: IContract::Known(names),
        params,
        ret: ret.clone(),
        effect: effect.clone(),
    }));
    let pending = PendingCall {
        node: e.id,
        span: e.span,
        callee_span: e.callee.span(),
        declaration_span: None,
        value_signature: match &callee {
            ITy::Fn(_) => None,
            ITy::Var(_) => match ctx.solver.value_shape(&callee) {
                ITy::Fn(f) => Some(f),
                ITy::Var(_)
                | ITy::Con(..)
                | ITy::Param(_)
                | ITy::App(..)
                | ITy::Rigid { .. }
                | ITy::Error => None,
            },
            ITy::Con(..) | ITy::Param(_) | ITy::App(..) | ITy::Rigid { .. } | ITy::Error => None,
        },
        callee,
        ret,
        effect: effect.clone(),
        args,
        parameter_spans: vec![],
        direct_ctor: false,
        direct_callee: None,
        inserted: None,
        partial_signature: None,
        positional_params: None,
    };
    let mut solver = std::mem::take(&mut ctx.solver);
    let constraints = resolve(ctx, &mut solver, pending);
    ctx.solver = solver;
    for constraint in constraints {
        ctx.add(constraint);
    }
    ctx.add(Constraint::EffSub {
        sub: effect,
        sup: ctx.effect.clone(),
        reason: reason(e.span, ReasonKind::CallEffect),
    });
}
