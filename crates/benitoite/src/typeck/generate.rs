//! 式と基本パターンから制約を作る（設計書 02-05「制約の生成」）。
use super::{
    context::{Body, fixed, lift, reason},
    decls::Decls,
    infer::*,
};
use crate::base::decimal::Decimal;
use crate::base::{NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::types::builtin::BuiltinTypeId as B;
use crate::types::{ConstValue, TyCon, TyNames, TySet};

pub(super) fn basic(b: B) -> ITy {
    ITy::Con(TyCon::Builtin(b), vec![])
}
pub(super) fn equal(
    ctx: &mut Body<'_, '_>,
    expected: ITy,
    found: ITy,
    span: Span,
    kind: ReasonKind,
) {
    ctx.add(Constraint::Equal {
        expected,
        found,
        reason: reason(span, kind),
    });
}
pub(super) fn flow(
    ctx: &mut Body<'_, '_>,
    from: ITy,
    to: ITy,
    e: &Expr,
    kind: ReasonKind,
    related: Option<Span>,
    declared: bool,
) {
    let mut r = reason(e.span(), kind);
    r.related = related;
    if declared {
        r.priority = Priority::Declared;
    }
    r.int_literal = integer_literal(ctx, e);
    ctx.add(Constraint::Flow {
        from,
        to,
        reason: r,
    });
}
pub(super) fn integer_literal(ctx: &Body<'_, '_>, e: &Expr) -> Option<String> {
    match e {
        Expr::Lit(LitExpr {
            lit: Literal::Int { .. },
            ..
        })
        | Expr::Unary(UnaryExpr { op: UnOp::Neg, .. }) => {
            match ctx.decls.out.lit_values.get(e.id()) {
                Some(ConstValue::Integer(n)) => Some(n.to_string()),
                _ => None,
            }
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
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => None,
    }
}
pub(super) fn check_function(d: &mut Decls<'_>, f: &FnDecl) {
    let Some(block) = &f.body else {
        return;
    };
    let Some(id) = d.binding(f.id) else {
        return;
    };
    if d.invalid.contains(&id) {
        return;
    }
    let Some(s) = d.out.decl_types.get(id).cloned() else {
        return;
    };
    let scope = d.scopes.get(&f.id).cloned().unwrap_or_default();
    let before = d.diagnostics.len();
    let mut ctx = Body::new(d, scope, s);
    ctx.owner = Some(f.id);
    ctx.return_annotation = Some(f.ret.span());
    for (p, t) in f.params.iter().zip(ctx.scheme.params.clone()) {
        let t = lift(&t);
        if let Some(id) = ctx.decls.binding(p.id) {
            ctx.locals.insert(id, t.clone());
        }
        ctx.record_type(p.id, t);
    }
    let ty = ctx.block(block);
    equal(&mut ctx, basic(B::UNIT), ty, block.span, ReasonKind::FnBody);
    let mut r = reason(f.name.span, ReasonKind::FnUses);
    r.related = Some(f.name.span);
    ctx.add(Constraint::EffSub {
        sub: ctx.body_effect.clone(),
        sup: fixed(ctx.scheme.effects.clone()),
        reason: r,
    });
    ctx.solve();
    ctx.check_type_limits(f.name.span);
    let ret = lift(&ctx.scheme.ret);
    reachability(&mut ctx, block, Some(ret));
    for (block, ret) in std::mem::take(&mut ctx.lambda_returns) {
        reachability(&mut ctx, &block, Some(ret));
    }
    let valid = !ctx
        .diagnostics
        .iter()
        .any(crate::diag::Diagnostic::is_error)
        && ctx.decls.diagnostics.len() == before;
    if valid {
        super::consts::warnings(&mut ctx, block);
    }
    ctx.finish();
}

#[inline(never)]
pub(super) fn expr(ctx: &mut Body<'_, '_>, e: &Expr) -> ITy {
    let ty = match e {
        Expr::Lit(e) => literal(ctx, e.id, e.span, &e.lit, false),
        Expr::Unit(_) => basic(B::UNIT),
        Expr::Paren(e) => ctx.expr(&e.inner),
        Expr::Name(e) => name(ctx, e, false),
        Expr::Interp(e) => interp(ctx, e),
        Expr::List(e) => list(ctx, e),
        Expr::Call(e) => call(ctx, e, None),
        Expr::Record(e) => super::records::expr(ctx, e),
        Expr::Binary(e) => binary(ctx, e),
        Expr::Unary(e) => unary(ctx, e),
        Expr::Pipe(p) => pipe(ctx, p),
        Expr::If(e) => if_expr(ctx, e),
        Expr::Match(e) => match_expr(ctx, e),
        Expr::Lambda(e) => lambda(ctx, e),
        Expr::Return(e) => return_expr(ctx, e),
        Expr::Try(_) | Expr::Lazy(_) | Expr::With(_) | Expr::Handle(_) | Expr::Resume(_) => {
            super::effects::expr(ctx, e)
        }
        Expr::Error(_) => ITy::Error,
    };
    ctx.record_type(e.id(), ty.clone());
    ty
}
pub(super) fn name(ctx: &mut Body<'_, '_>, e: &NameExpr, direct_with: bool) -> ITy {
    super::effects::name(ctx, e, direct_with);
    let Some(id) = ctx.decls.reference(e.id) else {
        return ITy::Error;
    };
    let Some(kind) = ctx.decls.resolved.bindings.get(id).map(|b| b.kind) else {
        return ITy::Error;
    };
    match kind {
        BindingKind::Local(_) => ctx.locals.get(id).cloned().unwrap_or(ITy::Error),
        BindingKind::Method { .. } => super::traits::method(ctx, e),
        BindingKind::Const => {
            let (_, _, ret) = ctx.instantiate(e.id, e.span, id);
            ret
        }
        BindingKind::Ctor { .. } => {
            let (f, params, ret) = ctx.instantiate(e.id, e.span, id);
            if params.is_empty() { ret } else { f }
        }
        BindingKind::Fn
        | BindingKind::BuiltinFn(_)
        | BindingKind::ImplFn { .. }
        | BindingKind::Data
        | BindingKind::BuiltinType(_)
        | BindingKind::Alias
        | BindingKind::Record
        | BindingKind::Field { .. }
        | BindingKind::Trait
        | BindingKind::Effect
        | BindingKind::BuiltinEffect(_)
        | BindingKind::Op { .. }
        | BindingKind::Module(_)
        | BindingKind::NamespaceRoot
        | BindingKind::TypeParam { .. }
        | BindingKind::EffectVar { .. } => ctx.instantiate(e.id, e.span, id).0,
    }
}
pub(super) fn call(ctx: &mut Body<'_, '_>, e: &CallExpr, insert: Option<&Expr>) -> ITy {
    if let Expr::Name(n) = e.callee.as_ref()
        && let Some(id) = ctx.decls.reference(n.id)
    {
        let kind = ctx.decls.resolved.bindings.get(id).map(|b| b.kind);
        if matches!(kind, Some(BindingKind::Const))
            || matches!(kind, Some(BindingKind::Ctor { .. }))
                && !ctx.decls.invalid.contains(&id)
                && e.args.is_empty()
                && insert.is_none()
                && ctx
                    .decls
                    .out
                    .decl_types
                    .get(id)
                    .is_some_and(|s| s.params.is_empty())
        {
            let t = ctx.expr(&e.callee);
            let code = if kind == Some(BindingKind::Const) {
                DiagCode::E0403
            } else {
                DiagCode::E0413
            };
            let name = n
                .path
                .iter()
                .map(|n| n.text.as_str())
                .collect::<Vec<_>>()
                .join(".");
            let mut d = DiagBuilder::new(code).primary(e.span).arg("name", name);
            if code == DiagCode::E0403 {
                let t = ctx.solver.finalize(&t, ctx.decls.resolved);
                d = d.arg(
                    "found",
                    t.show(&TyNames {
                        adts: &ctx.decls.out.adts,
                        effects: &ctx.decls.out.effects,
                        type_params: &[],
                        effect_params: &[],
                    }),
                );
            }
            let mut span = e.span;
            span.start = n.span.end;
            ctx.diagnostic(
                d.help_edits(
                    if code == DiagCode::E0403 {
                        "constant"
                    } else {
                        "remove"
                    },
                    vec![Edit {
                        span,
                        replacement: String::new(),
                    }],
                )
                .build(),
            );
            for a in &e.args {
                if let Arg::Expr(a) = a {
                    ctx.expr(a);
                }
            }
            return ITy::Error;
        }
    }
    let partial = e.args.iter().any(|a| matches!(a, Arg::Placeholder(_)));
    let old = if partial {
        let eff = ctx.fresh_effect();
        Some(std::mem::replace(&mut ctx.effect, eff))
    } else {
        None
    };
    let callee = ctx.expr(&e.callee);
    let mut args = vec![];
    let mut slots = vec![];
    if let Some(e) = insert {
        args.push((ctx.expr(e), Some(e)));
    }
    for arg in &e.args {
        match arg {
            Arg::Expr(e) => args.push((ctx.expr(e), Some(e))),
            Arg::Placeholder(p) => {
                let t = ctx.fresh_ty();
                ctx.record_type(p.id, t.clone());
                slots.push(t.clone());
                args.push((t, None));
            }
        }
    }
    let params = (0..args.len()).map(|_| ctx.fresh_ty()).collect::<Vec<_>>();
    let ret = ctx.fresh_ty();
    let eff = ctx.fresh_effect();
    let expected = ITy::Fn(Box::new(IFnTy {
        params: params.clone(),
        ret: ret.clone(),
        effect: eff.clone(),
    }));
    let mut r = reason(e.span, ReasonKind::Call);
    if let Expr::Name(n) = e.callee.as_ref() {
        r.related = ctx.decls.resolved.binding_of_ref(n.id).and_then(|b| b.span);
    }
    ctx.add(Constraint::Equal {
        expected,
        found: callee,
        reason: r,
    });
    let parameter_spans = declaration_params(ctx, &e.callee);
    for (i, ((t, arg), p)) in args.into_iter().zip(params).enumerate() {
        let rkind = ReasonKind::CallArg {
            index: u32::try_from(i).unwrap_or(u32::MAX).saturating_add(1),
        };
        if let Some(arg) = arg {
            flow(
                ctx,
                t,
                p,
                arg,
                rkind,
                parameter_spans.get(i).copied().flatten(),
                false,
            );
        } else {
            equal(ctx, p, t, e.span, rkind);
        }
    }
    ctx.add(Constraint::EffSub {
        sub: eff,
        sup: ctx.effect.clone(),
        reason: reason(e.span, ReasonKind::CallEffect),
    });
    if let Some(old) = old {
        let latent = std::mem::replace(&mut ctx.effect, old);
        ctx.lambda_effects.insert(e.id, latent.clone());
        ITy::Fn(Box::new(IFnTy {
            params: slots,
            ret,
            effect: latent,
        }))
    } else {
        ret
    }
}
fn declaration_params(ctx: &Body<'_, '_>, callee: &Expr) -> Vec<Option<Span>> {
    let Expr::Name(n) = callee else {
        return vec![];
    };
    let Some(id) = ctx.decls.reference(n.id) else {
        return vec![];
    };
    for m in ctx.decls.asts {
        for top in &m.decls {
            match &top.item {
                Item::Fn(f) if ctx.decls.binding(f.id) == Some(id) => {
                    return f
                        .params
                        .iter()
                        .map(|p| p.ty.as_ref().map(TypeExpr::span))
                        .collect();
                }
                Item::Effect(e) => {
                    for op in &e.ops {
                        if ctx.decls.binding(op.id) == Some(id) {
                            return op
                                .params
                                .iter()
                                .map(|p| p.ty.as_ref().map(TypeExpr::span))
                                .collect();
                        }
                    }
                }
                Item::Data(d) => {
                    if let Some(c) = d
                        .variants
                        .iter()
                        .find(|c| ctx.decls.binding(c.id) == Some(id))
                    {
                        return c.fields.iter().map(|t| Some(t.span())).collect();
                    }
                }
                Item::Impl(i) => {
                    if let Some(f) = i
                        .fns
                        .iter()
                        .find(|f| ctx.decls.binding(f.decl.id) == Some(id))
                    {
                        return f
                            .decl
                            .params
                            .iter()
                            .map(|p| p.ty.as_ref().map(TypeExpr::span))
                            .collect();
                    }
                }
                Item::Fn(_)
                | Item::Const(_)
                | Item::Alias(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Error(_) => {}
            }
        }
    }
    vec![]
}
fn apply(
    ctx: &mut Body<'_, '_>,
    callee: ITy,
    args: Vec<(ITy, &Expr)>,
    span: Span,
    _: Option<Span>,
) -> ITy {
    let params = (0..args.len()).map(|_| ctx.fresh_ty()).collect::<Vec<_>>();
    let ret = ctx.fresh_ty();
    let effect = ctx.fresh_effect();
    equal(
        ctx,
        ITy::Fn(Box::new(IFnTy {
            params: params.clone(),
            ret: ret.clone(),
            effect: effect.clone(),
        })),
        callee,
        span,
        ReasonKind::Call,
    );
    for (i, ((t, e), p)) in args.into_iter().zip(params).enumerate() {
        flow(
            ctx,
            t,
            p,
            e,
            ReasonKind::CallArg {
                index: u32::try_from(i).unwrap_or(u32::MAX).saturating_add(1),
            },
            None,
            false,
        );
    }
    ctx.add(Constraint::EffSub {
        sub: effect,
        sup: ctx.effect.clone(),
        reason: reason(span, ReasonKind::CallEffect),
    });
    ret
}
#[inline(never)]
fn binary(ctx: &mut Body<'_, '_>, e: &BinaryExpr) -> ITy {
    let a = ctx.expr(&e.lhs);
    let b = ctx.expr(&e.rhs);
    binary_constraints(ctx, e, a, b)
}
#[inline(never)]
fn binary_constraints(ctx: &mut Body<'_, '_>, e: &BinaryExpr, a: ITy, b: ITy) -> ITy {
    let t = ctx.fresh_ty();
    let op = OpName::Bin(e.op);
    for (found, expr) in [(a, &e.lhs), (b, &e.rhs)] {
        let mut r = reason(expr.span(), ReasonKind::Operands { op });
        r.int_literal = integer_literal(ctx, expr);
        ctx.add(Constraint::Equal {
            expected: t.clone(),
            found,
            reason: r,
        });
    }
    let mut r = reason(e.span, ReasonKind::Operator { op });
    if e.op == BinOp::Div {
        // 主な位置は式全体だが、div への修正案は演算子だけを置き換える。
        r.related = Some(e.op_span);
    }
    let result = match e.op {
        BinOp::Add => {
            ctx.add(Constraint::OneOf {
                ty: t.clone(),
                set: TySet::ADD,
                reason: r,
            });
            t.clone()
        }
        BinOp::Sub | BinOp::Mul => {
            ctx.add(Constraint::OneOf {
                ty: t.clone(),
                set: TySet::ARITH,
                reason: r,
            });
            t.clone()
        }
        BinOp::Div => {
            ctx.add(Constraint::OneOf {
                ty: t.clone(),
                set: TySet::DIV,
                reason: r,
            });
            t.clone()
        }
        BinOp::IntDiv | BinOp::Mod => {
            equal(
                ctx,
                basic(B::INTEGER),
                t.clone(),
                e.op_span,
                ReasonKind::Operator { op },
            );
            basic(B::INTEGER)
        }
        BinOp::Eq | BinOp::Ne => {
            ctx.add(Constraint::Equality {
                ty: t.clone(),
                reason: r,
            });
            basic(B::BOOLEAN)
        }
        BinOp::Lt | BinOp::Le | BinOp::Gt | BinOp::Ge => {
            ctx.add(Constraint::OneOf {
                ty: t.clone(),
                set: TySet::ORD,
                reason: r,
            });
            basic(B::BOOLEAN)
        }
        BinOp::And | BinOp::Or => {
            equal(
                ctx,
                basic(B::BOOLEAN),
                t.clone(),
                e.op_span,
                ReasonKind::Logic { op },
            );
            basic(B::BOOLEAN)
        }
    };
    ctx.operand_types.insert(e.id, t);
    result
}
#[inline(never)]
fn if_expr(ctx: &mut Body<'_, '_>, e: &IfExpr) -> ITy {
    let c = ctx.expr(&e.cond);
    equal(
        ctx,
        basic(B::BOOLEAN),
        c,
        e.cond.span(),
        ReasonKind::IfCondition,
    );
    let a = ctx.block(&e.then_block);
    match &e.else_branch {
        None => {
            equal(
                ctx,
                basic(B::UNIT),
                a,
                e.then_block.span,
                ReasonKind::IfNoElse,
            );
            basic(B::UNIT)
        }
        Some(branch) => {
            let (b, else_reason) = match branch {
                ElseBranch::Block(b) => (ctx.block(b), branch_reason(ctx, b)),
                ElseBranch::If(i) => {
                    let t = if_expr(ctx, i);
                    ctx.record_type(i.id, t.clone());
                    (t, reason(i.span, ReasonKind::IfBranches))
                }
            };
            let result = ctx.fresh_ty();
            let then_reason = branch_reason(ctx, &e.then_block);
            ctx.add(Constraint::Flow {
                from: a,
                to: result.clone(),
                reason: then_reason,
            });
            ctx.add(Constraint::Flow {
                from: b,
                to: result.clone(),
                reason: else_reason,
            });
            result
        }
    }
}
// 分岐の不一致は結果の式を指し、整数から Float への修正案もその式に付ける
// （設計書 02-05「制約の生成」「診断の修正案」）。
fn branch_reason(ctx: &Body<'_, '_>, block: &Block) -> Reason {
    match block.stmts.last() {
        Some(Stmt::Expr(expr)) => {
            let mut r = reason(expr.span(), ReasonKind::IfBranches);
            r.int_literal = integer_literal(ctx, expr);
            r
        }
        Some(Stmt::Bind(_) | Stmt::Error(_)) | None => reason(block.span, ReasonKind::IfBranches),
    }
}
#[inline(never)]
fn lambda(ctx: &mut Body<'_, '_>, e: &LambdaExpr) -> ITy {
    let ret = match &e.ret {
        Some(t) => {
            let ty = ctx.annotation(t);
            ctx.solver.known(ty)
        }
        None => ctx.fresh_ty(),
    };
    let effect = ctx.fresh_effect();
    let mut params = vec![];
    for p in &e.params {
        let t = match &p.ty {
            Some(t) => ctx.annotation(t),
            None => ctx.fresh_ty(),
        };
        if let Some(id) = ctx.decls.binding(p.id) {
            ctx.locals.insert(id, t.clone());
        }
        ctx.record_type(p.id, t.clone());
        params.push(t);
    }
    let old_annotation = std::mem::replace(
        &mut ctx.return_annotation,
        e.ret.as_ref().map(TypeExpr::span),
    );
    let body = ctx.block_in(&e.body, effect.clone(), Some(ret.clone()));
    ctx.return_annotation = old_annotation;
    lambda_result(ctx, e, ret, effect, params, body)
}
// 本体から戻った後の制約・AST の複製を、ラムダの各段の枠から分ける
// （設計書 02-03「入れ子の深さ」）。
#[inline(never)]
fn lambda_result(
    ctx: &mut Body<'_, '_>,
    e: &LambdaExpr,
    ret: ITy,
    effect: IEffect,
    params: Vec<ITy>,
    body: ITy,
) -> ITy {
    equal(ctx, basic(B::UNIT), body, e.body.span, ReasonKind::FnBody);
    let exposed = if let Some(u) = &e.uses {
        let (uses, _) = ctx.decls.uses(Some(u), &ctx.scope);
        let fixed = fixed(uses);
        let mut r = reason(e.span, ReasonKind::LambdaUses);
        r.related = Some(u.span);
        ctx.add(Constraint::EffSub {
            sub: effect.clone(),
            sup: fixed.clone(),
            reason: r,
        });
        fixed
    } else {
        effect.clone()
    };
    ctx.lambda_effects.insert(e.id, exposed.clone());
    // 戻り値の変数は解決後に判定する。本体の走査はここですでに終わっている。
    if !always_block(&e.body) {
        let mut r = reason(e.body.span, ReasonKind::LambdaReturn);
        r.related = e.ret.as_ref().map(TypeExpr::span);
        ctx.add(Constraint::Equal {
            expected: ret.clone(),
            found: basic(B::UNIT),
            reason: r,
        });
    }
    ctx.lambda_returns.push((e.body.clone(), ret.clone()));
    ITy::Fn(Box::new(IFnTy {
        params,
        ret,
        effect: exposed,
    }))
}
#[inline(never)]
pub(super) fn block(ctx: &mut Body<'_, '_>, b: &Block) -> ITy {
    let mut result = basic(B::UNIT);
    for (i, s) in b.stmts.iter().enumerate() {
        match s {
            Stmt::Bind(bind) => {
                bind_stmt(ctx, bind);
                result = basic(B::UNIT);
            }
            Stmt::Expr(e) => {
                result = ctx.expr(e);
                ctx.expr_stmts.insert(e.id(), e.clone());
                if i.saturating_add(1) != b.stmts.len() {
                    equal(
                        ctx,
                        basic(B::UNIT),
                        result.clone(),
                        e.span(),
                        ReasonKind::ExprStmt,
                    );
                }
            }
            Stmt::Error(_) => result = ITy::Error,
        }
    }
    ctx.record_type(b.id, result.clone());
    result
}
#[inline(never)]
pub(super) fn pattern(ctx: &mut Body<'_, '_>, p: &Pattern) -> ITy {
    let t = match p {
        Pattern::Var(p) => {
            let t = ctx.fresh_ty();
            if let Some(id) = ctx.decls.binding(p.id) {
                ctx.locals.insert(id, t.clone());
            }
            t
        }
        Pattern::Wildcard(_) => ctx.fresh_ty(),
        Pattern::Unit(_) => basic(B::UNIT),
        Pattern::Lit(p) => literal(ctx, p.id, p.span, &p.lit, p.negative),
        Pattern::Ctor(p) => ctor_pattern(ctx, p),
        Pattern::Record(p) => super::records::pattern(ctx, p),
        Pattern::Range(_) | Pattern::List(_) => super::pattern_ext::pattern(ctx, p),
        Pattern::Error(_) => ITy::Error,
    };
    ctx.record_type(p.id(), t.clone());
    t
}
fn poison_pattern(ctx: &mut Body<'_, '_>, pattern: &Pattern) {
    let mut pending = vec![pattern];
    while let Some(p) = pending.pop() {
        ctx.record_type(p.id(), ITy::Error);
        match p {
            Pattern::Var(v) => {
                if let Some(id) = ctx.decls.binding(v.id) {
                    ctx.locals.insert(id, ITy::Error);
                }
            }
            Pattern::Ctor(c) => pending.extend(&c.args),
            Pattern::Record(r) => pending.extend(r.fields.iter().map(|f| &f.pattern)),
            Pattern::Wildcard(_)
            | Pattern::Unit(_)
            | Pattern::Lit(_)
            | Pattern::Range(_)
            | Pattern::List(_)
            | Pattern::Error(_) => {}
        }
    }
}
pub(super) fn literal(
    ctx: &mut Body<'_, '_>,
    id: NodeId,
    span: Span,
    l: &Literal,
    negative: bool,
) -> ITy {
    let (ty, value, error) = match l {
        Literal::Int { radix, digits } => {
            let v = u64::from_str_radix(digits, *radix).ok().and_then(|n| {
                if negative {
                    if n == 1_u64.checked_shl(63).unwrap_or(0) {
                        Some(i64::MIN)
                    } else {
                        i64::try_from(n).ok().and_then(i64::checked_neg)
                    }
                } else {
                    i64::try_from(n).ok()
                }
            });
            (
                B::INTEGER,
                v.map(ConstValue::Integer),
                Some(DiagCode::E0408),
            )
        }
        Literal::Float(s) => {
            let v = s
                .parse::<f64>()
                .ok()
                .filter(|v| v.is_finite())
                .map(|v| if negative { -v } else { v });
            (B::FLOAT, v.map(ConstValue::Float), Some(DiagCode::E0409))
        }
        Literal::Decimal(s) => {
            let v = Decimal::parse_literal(s).map(|v| if negative { v.negate() } else { v });
            let code = if s.split_once('.').is_some_and(|(_, f)| f.len() > 28) {
                DiagCode::E0420
            } else {
                DiagCode::E0421
            };
            (B::DECIMAL, v.map(ConstValue::Decimal), Some(code))
        }
        Literal::Str(s) => (B::STRING, Some(ConstValue::String(s.clone())), None),
        Literal::Char(c) => (B::CHARACTER, Some(ConstValue::Character(*c)), None),
        Literal::Bool(b) => (B::BOOLEAN, Some(ConstValue::Boolean(*b)), None),
    };
    if let Some(v) = value {
        ctx.decls.out.lit_values.insert(id, v);
    } else if let Some(code) = error {
        let mut d = DiagBuilder::new(code).primary(span);
        if code == DiagCode::E0408 {
            d = d.note("range");
        }
        ctx.diagnostic(d.build());
    }
    basic(ty)
}
fn always_expr(e: &Expr) -> bool {
    match e {
        Expr::Return(_) => true,
        Expr::Paren(p) => always_expr(&p.inner),
        Expr::If(i) => {
            always_block(&i.then_block)
                && i.else_branch.as_ref().is_some_and(|b| match b {
                    ElseBranch::Block(b) => always_block(b),
                    ElseBranch::If(i) => always_expr(&Expr::If(i.as_ref().clone())),
                })
        }
        Expr::Match(m) => !m.arms.is_empty() && m.arms.iter().all(|a| always_block(&a.body)),
        Expr::With(w) => always_block(&w.body),
        Expr::Lit(_)
        | Expr::Interp(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::List(_)
        | Expr::Call(_)
        | Expr::Record(_)
        | Expr::Binary(_)
        | Expr::Unary(_)
        | Expr::Pipe(_)
        | Expr::Lambda(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => false,
    }
}
fn always_block(b: &Block) -> bool {
    b.stmts
        .iter()
        .any(|s| matches!(s,Stmt::Expr(e) if always_expr(e)))
}
pub(super) fn reachability(ctx: &mut Body<'_, '_>, b: &Block, ret: Option<ITy>) {
    if let Some(ret) = ret
        && !ctx.solver.contains_error(&ret)
        && ctx.solver.finalize(&ret, ctx.decls.resolved) != super::decls::unit()
        && !always_block(b)
    {
        let shown = ctx
            .solver
            .finalize(&ret, ctx.decls.resolved)
            .show(&TyNames {
                adts: &ctx.decls.out.adts,
                effects: &ctx.decls.out.effects,
                type_params: &ctx
                    .scheme
                    .type_params
                    .iter()
                    .map(|p| p.name.clone())
                    .collect::<Vec<_>>(),
                effect_params: &ctx.scheme.effect_params,
            });
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0438)
                .arg("expected", shown)
                .primary(b.span)
                .help("add")
                .build(),
        );
    }
    let mut exit = None;
    for s in &b.stmts {
        if let Some(span) = exit {
            ctx.diagnostic(
                DiagBuilder::new(DiagCode::E0439)
                    .primary(s.span())
                    .secondary(span, "exit")
                    .build(),
            );
        }
        if let Stmt::Expr(e) = s {
            if always_expr(e) {
                exit = Some(e.span());
            }
            reach_expr(ctx, e);
        }
        if let Stmt::Bind(b) = s {
            reach_expr(ctx, &b.value);
        }
    }
}
fn reach_expr(ctx: &mut Body<'_, '_>, e: &Expr) {
    match e {
        Expr::If(i) => {
            reach_expr(ctx, &i.cond);
            reachability(ctx, &i.then_block, None);
            if let Some(b) = &i.else_branch {
                match b {
                    ElseBranch::Block(b) => reachability(ctx, b, None),
                    ElseBranch::If(i) => reach_expr(ctx, &Expr::If(i.as_ref().clone())),
                }
            }
        }
        Expr::Match(m) => {
            reach_expr(ctx, &m.scrutinee);
            for a in &m.arms {
                reachability(ctx, &a.body, None);
            }
        }
        Expr::Paren(e) => reach_expr(ctx, &e.inner),
        Expr::Interp(i) => {
            for s in &i.segments {
                reach_expr(ctx, &s.expr);
            }
        }
        Expr::List(l) => {
            for e in &l.elems {
                match e {
                    ListElem::Expr(e) => reach_expr(ctx, e),
                    ListElem::Spread(s) => reach_expr(ctx, &s.expr),
                }
            }
        }
        Expr::Call(c) => {
            reach_expr(ctx, &c.callee);
            for a in &c.args {
                if let Arg::Expr(e) = a {
                    reach_expr(ctx, e);
                }
            }
        }
        Expr::Record(r) => {
            if let Some(b) = &r.base {
                reach_expr(ctx, b);
            }
            for f in &r.fields {
                reach_expr(ctx, &f.value);
            }
        }
        Expr::Binary(b) => {
            reach_expr(ctx, &b.lhs);
            reach_expr(ctx, &b.rhs);
        }
        Expr::Unary(u) => reach_expr(ctx, &u.operand),
        Expr::Pipe(p) => {
            reach_expr(ctx, &p.lhs);
            reach_expr(ctx, &p.rhs);
        }
        Expr::Return(r) => reach_expr(ctx, &r.value),
        Expr::With(w) => {
            for b in &w.binds {
                reach_expr(ctx, &b.value);
            }
            reachability(ctx, &w.body, None);
        }
        // ラムダは固有の戻り値の検査とともに別に辿る。E3 の残りの式は仮の本体が子を辿らない。
        Expr::Lit(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::Lambda(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => {}
    }
}

// 大きい分岐を再帰する入口から分け、構文の上限内で枠が積み重なる量を抑える
// （実装プラン F10「型検査の再帰の深さ」）。展開すると再び枠が大きくなる。
#[inline(never)]
fn interp(ctx: &mut Body<'_, '_>, e: &InterpExpr) -> ITy {
    for s in &e.segments {
        let t = ctx.expr(&s.expr);
        ctx.interp_types.insert(s.expr.id(), t.clone());
        ctx.add(Constraint::OneOf {
            ty: t,
            set: TySet::INTERP,
            reason: reason(s.expr.span(), ReasonKind::Interp),
        });
    }
    basic(B::STRING)
}

#[inline(never)]
fn list(ctx: &mut Body<'_, '_>, e: &ListExpr) -> ITy {
    let elem = ctx.fresh_ty();
    let list = ITy::Con(TyCon::Builtin(B::LIST), vec![elem.clone()]);
    for item in &e.elems {
        match item {
            ListElem::Expr(e) => {
                let ty = ctx.expr(e);
                flow(
                    ctx,
                    ty,
                    elem.clone(),
                    e,
                    ReasonKind::ListElement,
                    None,
                    false,
                );
            }
            ListElem::Spread(s) => {
                let ty = ctx.expr(&s.expr);
                flow(
                    ctx,
                    ty,
                    list.clone(),
                    &s.expr,
                    ReasonKind::ListSpread,
                    None,
                    false,
                );
                ctx.record_type(s.id, list.clone());
            }
        }
    }
    list
}

#[inline(never)]
fn unary(ctx: &mut Body<'_, '_>, e: &UnaryExpr) -> ITy {
    if e.op == UnOp::Neg
        && let Expr::Lit(l) = e.operand.as_ref()
        && matches!(
            l.lit,
            Literal::Int { .. } | Literal::Float(_) | Literal::Decimal(_)
        )
    {
        let ty = literal(ctx, e.id, e.span, &l.lit, true);
        // 符号を含めて読んだ MIN を、正のリテラルとして再び検査しない（設計書 02-05「リテラル」）。
        ctx.record_type(l.id, ty.clone());
        let positive = match ctx.decls.out.lit_values.get(e.id) {
            Some(ConstValue::Integer(n)) => n.checked_neg().map(ConstValue::Integer),
            Some(ConstValue::Float(n)) => Some(ConstValue::Float(-n)),
            Some(ConstValue::Decimal(n)) => Some(ConstValue::Decimal(n.negate())),
            _ => None,
        };
        if let Some(value) = positive {
            ctx.decls.out.lit_values.insert(l.id, value);
        }
        ctx.operand_types.insert(e.id, ty.clone());
        ty
    } else {
        let t = ctx.expr(&e.operand);
        ctx.operand_types.insert(e.id, t.clone());
        if e.op == UnOp::Not {
            equal(
                ctx,
                basic(B::BOOLEAN),
                t,
                e.operand.span(),
                ReasonKind::Logic {
                    op: OpName::Un(e.op),
                },
            );
            basic(B::BOOLEAN)
        } else {
            ctx.add(Constraint::OneOf {
                ty: t.clone(),
                set: TySet::ARITH,
                reason: reason(
                    e.span,
                    ReasonKind::Operator {
                        op: OpName::Un(e.op),
                    },
                ),
            });
            t
        }
    }
}

#[inline(never)]
fn pipe(ctx: &mut Body<'_, '_>, p: &PipeExpr) -> ITy {
    if let Expr::Call(c) = p.rhs.as_ref()
        && !c.args.iter().any(|a| matches!(a, Arg::Placeholder(_)))
    {
        let ty = call(ctx, c, Some(&p.lhs));
        ctx.record_type(c.id, ty.clone());
        ty
    } else {
        let callee = ctx.expr(&p.rhs);
        let arg = ctx.expr(&p.lhs);
        apply(ctx, callee, vec![(arg, p.lhs.as_ref())], p.span, None)
    }
}

#[inline(never)]
fn match_expr(ctx: &mut Body<'_, '_>, e: &MatchExpr) -> ITy {
    let scrutinee = ctx.expr(&e.scrutinee);
    let result = ctx.fresh_ty();
    for arm in &e.arms {
        for p in &arm.patterns {
            let t = ctx.pattern(p);
            equal(ctx, scrutinee.clone(), t, p.span(), ReasonKind::Pattern);
        }
        if arm.patterns.len() > 1 {
            super::pattern_ext::alternatives(ctx, arm);
        }
        if let Some(g) = &arm.guard {
            super::pattern_ext::guard(ctx, g);
        }
        let t = ctx.block(&arm.body);
        ctx.add(Constraint::Flow {
            from: t,
            to: result.clone(),
            reason: reason(arm.body.span, ReasonKind::MatchArms),
        });
    }
    ctx.matches.push((e.clone(), scrutinee));
    result
}

#[inline(never)]
fn return_expr(ctx: &mut Body<'_, '_>, e: &ReturnExpr) -> ITy {
    let t = ctx.expr(&e.value);
    if let Some(ret) = ctx.ret.clone() {
        flow(
            ctx,
            t,
            ret,
            &e.value,
            ReasonKind::Return,
            ctx.return_annotation,
            true,
        );
    }
    ctx.fresh_ty()
}

#[inline(never)]
fn ctor_pattern(ctx: &mut Body<'_, '_>, p: &CtorPat) -> ITy {
    let Some(id) = ctx.decls.reference(p.id) else {
        return ITy::Error;
    };
    let (_, params, ret) = ctx.instantiate(p.id, p.span, id);
    if matches!(ret, ITy::Error)
        || params.len() != p.args.len()
        || params.is_empty() && p.has_parens
    {
        return invalid_ctor_pattern(ctx, p, params.len(), ret);
    }
    for (arg, t) in p.args.iter().zip(params) {
        let a = ctx.pattern(arg);
        equal(ctx, t, a, arg.span(), ReasonKind::Pattern);
    }
    ret
}
#[inline(never)]
fn invalid_ctor_pattern(ctx: &mut Body<'_, '_>, p: &CtorPat, count: usize, ret: ITy) -> ITy {
    if matches!(ret, ITy::Error) {
        for arg in &p.args {
            ctx.pattern(arg);
            poison_pattern(ctx, arg);
        }
    } else if count == 0 && p.args.is_empty() && p.has_parens {
        let mut span = p.span;
        if let Some(last) = p.path.last() {
            span.start = last.span.end;
        }
        let name = p
            .path
            .iter()
            .map(|n| n.text.as_str())
            .collect::<Vec<_>>()
            .join(".");
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0413)
                .arg("name", name)
                .primary(p.span)
                .help_edits(
                    "remove",
                    vec![Edit {
                        span,
                        replacement: String::new(),
                    }],
                )
                .build(),
        );
    } else {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0412)
                .arg("name", p.path.last().map_or("", |n| &n.text))
                .arg("expected", count.to_string())
                .arg("found", p.args.len().to_string())
                .primary(p.span)
                .build(),
        );
        for arg in &p.args {
            let a = ctx.pattern(arg);
            equal(ctx, ITy::Error, a, arg.span(), ReasonKind::Pattern);
            poison_pattern(ctx, arg);
        }
    }
    ITy::Error
}

#[inline(never)]
fn bind_stmt(ctx: &mut Body<'_, '_>, bind: &BindStmt) {
    let t = ctx.expr(&bind.value);
    let target = if let Some(ann) = &bind.ty {
        let annotation = ctx.annotation(ann);
        let a = ctx.solver.known(annotation);
        flow(
            ctx,
            t.clone(),
            a.clone(),
            &bind.value,
            ReasonKind::BindAnnotation,
            Some(ann.span()),
            true,
        );
        a
    } else {
        t.clone()
    };
    let p = ctx.pattern(&bind.pattern);
    equal(
        ctx,
        target.clone(),
        p,
        bind.pattern.span(),
        ReasonKind::Pattern,
    );
    ctx.record_type(bind.id, target.clone());
    ctx.bindings.push((bind.clone(), target));
}
