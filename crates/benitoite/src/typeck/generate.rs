//! 式と基本パターンから制約を作る（設計書 02-05「制約の生成」）。
use super::{
    context::{Body, BodyReturn, ReturnOwner, fixed, lift, reason},
    decls::Decls,
    infer::*,
};
use crate::base::decimal::Decimal;
use crate::base::{NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::syntax::token::{FloatSuffix, IntegerSuffix};
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
            lit:
                Literal::Int { .. }
                | Literal::WidthInt {
                    suffix: IntegerSuffix::S64,
                    ..
                },
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
        | Expr::Block(_)
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
    let Some(module) = d.resolved.bindings.get(id).map(|binding| binding.module) else {
        return;
    };
    let before = d.diagnostics.len();
    let mut ctx = Body::new(d, module, scope, s);
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
    let end = body_end(block);
    ctx.body_returns.insert(
        end,
        BodyReturn {
            annotated: true,
            ty: lift(&ctx.scheme.ret),
            owner: ReturnOwner::Function,
        },
    );
    equal(&mut ctx, basic(B::UNIT), ty, end, ReasonKind::FnBody);
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
        .any(super::consts::prevents_evaluation)
        && ctx.decls.diagnostics.len() == before;
    if valid {
        super::consts::warnings(&mut ctx, block);
    }
    ctx.finish();
    if !d
        .diagnostics
        .iter()
        .skip(before)
        .any(super::consts::prevents_evaluation)
    {
        super::checked_args::check(d, block);
    }
}

#[inline(never)]
pub(super) fn expr(ctx: &mut Body<'_, '_>, e: &Expr) -> ITy {
    // 解決後の契約の診断でも、囲む関数の名前ではなく元の式を示す（設計書 02-10「診断の内部の表現」）。
    ctx.expr_spans.insert(e.id(), e.span());
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
        Expr::Block(e) => ctx.block(&e.body),
        Expr::Lambda(e) => lambda(ctx, e),
        Expr::Return(e) => return_expr(ctx, e),
        Expr::Try(_) | Expr::Lazy(_) | Expr::With(_) | Expr::Handle(_) | Expr::Resume(_) => {
            super::effects::expr(ctx, e)
        }
        Expr::Error(_) => ITy::Error,
    };
    if ctx
        .decls
        .resolved
        .stdlib("Benitoite.Failure.raise")
        .is_some()
    {
        ctx.source_effects.insert(e.id(), ctx.effect.clone());
    }
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
        | BindingKind::ExternalType
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
// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
pub(super) fn call(ctx: &mut Body<'_, '_>, e: &CallExpr, insert: Option<&Expr>) -> ITy {
    if let Some(call) = ctx.decls.resolved.builder_calls.get(e.id).copied() {
        return super::builders::operation(ctx, e, call);
    }
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
            report_value_call(ctx, e, n, kind, t);
            for a in &e.args {
                if let Some(a) = a.expr() {
                    ctx.expr(a);
                }
            }
            return ITy::Error;
        }
    }
    let partial = e.args.iter().any(|a| a.placeholder().is_some());
    if !partial {
        return call_body(ctx, e, insert, None);
    }
    let ret = ctx.fresh_ty();
    let effect = ctx.fresh_effect();
    let old_effect = std::mem::replace(&mut ctx.effect, effect);
    let old_ret = ctx.ret.replace(ret.clone());
    let old_clauses = std::mem::take(&mut ctx.clauses);
    let old_annotation = ctx.return_annotation.take();
    let old_boundary = std::mem::replace(&mut ctx.placeholder_boundary, true);
    let old_owner = std::mem::replace(&mut ctx.return_owner, ReturnOwner::Placeholder(e.span));
    // 子の検査で誤りが起きても、call_body から戻ってから文脈を復元する。
    let ty = call_body(ctx, e, insert, Some(ret));
    ctx.effect = old_effect;
    ctx.ret = old_ret;
    ctx.clauses = old_clauses;
    ctx.return_annotation = old_annotation;
    ctx.placeholder_boundary = old_boundary;
    ctx.return_owner = old_owner;
    ty
}
// 値を関数として呼んだ診断は誤りの場合だけ作る（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[cold]
#[inline(never)]
fn report_value_call(
    ctx: &mut Body<'_, '_>,
    e: &CallExpr,
    n: &NameExpr,
    kind: Option<BindingKind>,
    t: ITy,
) {
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
                bindings: &ctx.decls.resolved.bindings,
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
}

// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
fn call_body(
    ctx: &mut Body<'_, '_>,
    e: &CallExpr,
    insert: Option<&Expr>,
    partial_ret: Option<ITy>,
) -> ITy {
    super::calls::generate(ctx, e, insert, partial_ret, None)
}
pub(super) fn declaration_params(ctx: &Body<'_, '_>, callee: &Expr) -> Vec<Option<Span>> {
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
                | Item::ExternalType(_)
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
    let contract = if params.is_empty() {
        IContract::Known(vec![])
    } else {
        ctx.solver.fresh_contract()
    };
    ctx.call_contracts.push((callee.clone(), span, span));
    equal(
        ctx,
        ITy::Fn(Box::new(IFnTy {
            contract,
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
            r.span = e.op_span;
            ctx.add(Constraint::OneOf {
                ty: t.clone(),
                set: TySet::INT_DIV,
                reason: r,
            });
            t.clone()
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
// （設計書 02-05「制約の生成」「誤りの報告と検査の継続」）。
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
    let old_owner = std::mem::replace(&mut ctx.return_owner, ReturnOwner::Lambda);
    let body = ctx.block_in(&e.body, effect.clone(), Some(ret.clone()));
    ctx.return_owner = old_owner;
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
    let end = body_end(&e.body);
    ctx.body_returns.insert(
        end,
        BodyReturn {
            annotated: e.ret.is_some(),
            ty: ret.clone(),
            owner: ReturnOwner::Lambda,
        },
    );
    ctx.lambda_body_ends.insert(e.body.span, end);
    equal(ctx, basic(B::UNIT), body, end, ReasonKind::FnBody);
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
    // Body は AST の寿命を持たず、後検査は本体全体を辿るため複製を残す。
    // 本体の走査中に後検査を移すと、制約の解決後に出す診断の順序が変わる。
    ctx.lambda_returns.push((e.body.clone(), ret.clone()));
    ITy::Fn(Box::new(IFnTy {
        contract: IContract::Known(e.params.iter().map(|p| p.name.text.clone()).collect()),
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
                if let Expr::Binary(b) = e
                    && b.op == BinOp::Eq
                    && let Expr::Name(n) = b.lhs.as_ref()
                {
                    ctx.expr_stmts.insert(e.span(), (n.span, b.rhs.span()));
                }
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
            Pattern::List(list) => {
                pending.extend(list.before.iter().chain(&list.after));
                if let Some(rest) = &list.rest {
                    ctx.record_type(rest.id, ITy::Error);
                    if let Some(id) = ctx.decls.binding(rest.id) {
                        ctx.locals.insert(id, ITy::Error);
                    }
                }
            }
            Pattern::Wildcard(_)
            | Pattern::Unit(_)
            | Pattern::Lit(_)
            | Pattern::Range(_)
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
        Literal::Int { radix, digits }
        | Literal::WidthInt {
            radix,
            digits,
            suffix: IntegerSuffix::S64,
        } => {
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
        Literal::Float(s)
        | Literal::WidthFloat {
            text: s,
            suffix: FloatSuffix::F64,
        } => {
            let v = s
                .parse::<f64>()
                .ok()
                .filter(|v| v.is_finite())
                .map(|v| if negative { -v } else { v });
            (B::FLOAT, v.map(ConstValue::Float), Some(DiagCode::E0409))
        }
        Literal::WidthInt {
            radix,
            digits,
            suffix: IntegerSuffix::U8,
        } => {
            if negative {
                invalid_negation(ctx, span, B::BYTE);
                return basic(B::BYTE);
            }
            let value = u64::from_str_radix(digits, *radix)
                .ok()
                .and_then(|n| u8::try_from(n).ok());
            (B::BYTE, value.map(ConstValue::Byte), Some(DiagCode::E0446))
        }
        Literal::WidthInt {
            radix,
            digits,
            suffix,
        } => {
            let ty = match suffix {
                IntegerSuffix::S8 => B::INTEGER8,
                IntegerSuffix::S16 => B::INTEGER16,
                IntegerSuffix::S32 => B::INTEGER32,
                IntegerSuffix::U16 => B::UNSIGNED_INTEGER16,
                IntegerSuffix::U32 => B::UNSIGNED_INTEGER32,
                IntegerSuffix::U64 => B::UNSIGNED_INTEGER64,
                IntegerSuffix::S64 => B::INTEGER,
                IntegerSuffix::U8 => B::BYTE,
            };
            if negative
                && matches!(
                    suffix,
                    IntegerSuffix::U16 | IntegerSuffix::U32 | IntegerSuffix::U64
                )
            {
                invalid_negation(ctx, span, ty);
                return basic(ty);
            }
            // 大きさを u64 で読み、負号はより広い整数で適用してから目的の幅へ検査する。
            // 符号付きの最小値と u64 の上半分を、正の i64 に収める必要がない。
            let magnitude = u64::from_str_radix(digits, *radix).ok();
            let signed = magnitude.and_then(|n| {
                let n = i128::from(n);
                if negative { n.checked_neg() } else { Some(n) }
            });
            let value = match suffix {
                IntegerSuffix::S8 => signed
                    .and_then(|n| i8::try_from(n).ok())
                    .map(ConstValue::Integer8),
                IntegerSuffix::S16 => signed
                    .and_then(|n| i16::try_from(n).ok())
                    .map(ConstValue::Integer16),
                IntegerSuffix::S32 => signed
                    .and_then(|n| i32::try_from(n).ok())
                    .map(ConstValue::Integer32),
                IntegerSuffix::U16 => magnitude
                    .and_then(|n| u16::try_from(n).ok())
                    .map(ConstValue::UnsignedInteger16),
                IntegerSuffix::U32 => magnitude
                    .and_then(|n| u32::try_from(n).ok())
                    .map(ConstValue::UnsignedInteger32),
                IntegerSuffix::U64 => magnitude.map(ConstValue::UnsignedInteger64),
                IntegerSuffix::S64 | IntegerSuffix::U8 => None,
            };
            (ty, value, Some(DiagCode::E0447))
        }
        Literal::WidthFloat {
            suffix: FloatSuffix::F32,
            text,
        } => {
            let value = text
                .parse::<f32>()
                .ok()
                .filter(|v| v.is_finite())
                .map(|v| ConstValue::Float32(if negative { -v } else { v }));
            (B::FLOAT32, value, Some(DiagCode::E0448))
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
        if matches!(code, DiagCode::E0408 | DiagCode::E0446) {
            d = d.note("range");
        }
        if code == DiagCode::E0447 {
            let (minimum, maximum) = integer_range(ty);
            d = d
                .arg("ty", ty.display_name().unwrap_or_default())
                .arg("minimum", minimum)
                .arg("maximum", maximum)
                .note("range");
        }
        ctx.diagnostic(d.build());
    }
    basic(ty)
}

fn integer_range(ty: B) -> (String, String) {
    match ty {
        B::INTEGER8 => (i8::MIN.to_string(), i8::MAX.to_string()),
        B::INTEGER16 => (i16::MIN.to_string(), i16::MAX.to_string()),
        B::INTEGER32 => (i32::MIN.to_string(), i32::MAX.to_string()),
        B::UNSIGNED_INTEGER16 => (u16::MIN.to_string(), u16::MAX.to_string()),
        B::UNSIGNED_INTEGER32 => (u32::MIN.to_string(), u32::MAX.to_string()),
        B::UNSIGNED_INTEGER64 => (u64::MIN.to_string(), u64::MAX.to_string()),
        _ => (String::new(), String::new()),
    }
}

fn invalid_negation(ctx: &mut Body<'_, '_>, span: Span, ty: B) {
    ctx.diagnostic(
        DiagBuilder::new(DiagCode::E0405)
            .arg("ty", ty.display_name().unwrap_or_default())
            .arg("op", super::text::operator_spelling(OpName::Un(UnOp::Neg)))
            .primary(span)
            .build(),
    );
}

fn always_expr(e: &Expr) -> bool {
    match e {
        Expr::Return(_) => true,
        Expr::Paren(p) => always_expr(&p.inner),
        Expr::If(i) => always_if(i),
        Expr::Match(m) => !m.arms.is_empty() && m.arms.iter().all(|a| always_block(&a.body)),
        Expr::Block(e) => always_block(&e.body),
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
fn always_if(i: &IfExpr) -> bool {
    always_block(&i.then_block)
        && i.else_branch.as_ref().is_some_and(|b| match b {
            ElseBranch::Block(b) => always_block(b),
            ElseBranch::If(i) => always_if(i),
        })
}
fn always_block(b: &Block) -> bool {
    b.stmts
        .iter()
        .any(|s| matches!(s,Stmt::Expr(e) if always_expr(e)))
}
fn body_end(b: &Block) -> Span {
    match b.stmts.last() {
        Some(Stmt::Expr(e)) => e.span(),
        Some(Stmt::Bind(_) | Stmt::Error(_)) | None => b.span,
    }
}
pub(super) fn reachability(ctx: &mut Body<'_, '_>, b: &Block, ret: Option<ITy>) {
    if let Some(ret) = ret
        && !ctx.solver.contains_error(&ret)
        && ctx.solver.finalize(&ret, ctx.decls.resolved) != super::decls::unit()
        && !always_block(b)
        && !ctx.reported_body_values.contains(&body_end(b))
    {
        let shown = ctx.show_type(&ret);
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0438)
                .arg("expected", shown)
                .primary(body_end(b))
                .help("add")
                .build(),
        );
    }
    let mut exit = None;
    let mut reported = false;
    for s in &b.stmts {
        if let Some(span) = exit
            && !reported
        {
            ctx.diagnostic(
                DiagBuilder::new(DiagCode::E0439)
                    .primary(s.span())
                    .secondary(span, "exit")
                    .build(),
            );
            // 同じ必ず抜ける文に由来する誤りは一度だけ報告する。後続文の子の
            // ブロックは独立に検査するため、走査は続ける（設計書 01-06「必ず抜ける文」）。
            reported = true;
        }
        if let Stmt::Expr(e) = s {
            if exit.is_none() && always_expr(e) {
                exit = Some(e.span());
            }
            reach_expr(ctx, e);
        }
        if let Stmt::Bind(b) = s {
            reach_expr(ctx, &b.value);
        }
    }
}
fn reach_if(ctx: &mut Body<'_, '_>, i: &IfExpr) {
    reach_expr(ctx, &i.cond);
    reachability(ctx, &i.then_block, None);
    if let Some(b) = &i.else_branch {
        match b {
            ElseBranch::Block(b) => reachability(ctx, b, None),
            ElseBranch::If(i) => reach_if(ctx, i),
        }
    }
}
// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
fn reach_expr(ctx: &mut Body<'_, '_>, e: &Expr) {
    match e {
        Expr::If(i) => reach_if(ctx, i),
        Expr::Match(m) => {
            reach_expr(ctx, &m.scrutinee);
            for a in &m.arms {
                if let Some(guard) = &a.guard {
                    reach_expr(ctx, guard);
                }
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
                if let Some(e) = a.expr() {
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
        Expr::Try(t) => {
            reach_expr(ctx, &t.value);
            if let crate::syntax::ast::TryAction::Die {
                message: Some(message),
                ..
            } = &t.action
            {
                reach_expr(ctx, message);
            }
        }
        Expr::Block(e) => reachability(ctx, &e.body, None),
        Expr::Lazy(l) => reachability(ctx, &l.body, None),
        Expr::Handle(h) => {
            reachability(ctx, &h.body, None);
            for clause in &h.clauses {
                reachability(ctx, &clause.body, None);
            }
        }
        Expr::Resume(r) => reach_expr(ctx, &r.value),
        // ラムダは固有の戻り値の検査とともに別に辿るため、ここでは二重に検査しない。
        Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Lambda(_) | Expr::Error(_) => {}
    }
}

// 大きい分岐を再帰する入口から分け、構文の上限内で枠が積み重なる量を抑える。
// 展開すると再び枠が大きくなる。
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
            Literal::Int { .. }
                | Literal::WidthInt { .. }
                | Literal::WidthFloat { .. }
                | Literal::Float(_)
                | Literal::Decimal(_)
        )
    {
        let ty = literal(ctx, e.id, e.span, &l.lit, true);
        // 符号を含めて読んだ MIN を、正のリテラルとして再び検査しない（設計書 02-05「制約の生成」）。
        ctx.record_type(l.id, ty.clone());
        let positive = match ctx.decls.out.lit_values.get(e.id) {
            Some(ConstValue::Integer(n)) => n.checked_neg().map(ConstValue::Integer),
            Some(ConstValue::Float(n)) => Some(ConstValue::Float(-n)),
            Some(ConstValue::Decimal(n)) => Some(ConstValue::Decimal(n.negate())),
            Some(ConstValue::Integer8(n)) => n.checked_neg().map(ConstValue::Integer8),
            Some(ConstValue::Integer16(n)) => n.checked_neg().map(ConstValue::Integer16),
            Some(ConstValue::Integer32(n)) => n.checked_neg().map(ConstValue::Integer32),
            Some(ConstValue::Float32(n)) => Some(ConstValue::Float32(-n)),
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
                set: TySet::NEG,
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
        && !c.args.iter().any(|a| a.placeholder().is_some())
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
    ctx.matches.push((
        super::context::MatchInfo {
            arms: e
                .arms
                .iter()
                .map(|arm| super::context::MatchArmInfo {
                    patterns: arm.patterns.clone(),
                    guarded: arm.guard.is_some(),
                })
                .collect(),
            scrutinee: e.scrutinee.span(),
        },
        scrutinee,
    ));
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
        let name = pattern_path(p);
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
                .arg("name", pattern_path(p))
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

fn pattern_path(p: &CtorPat) -> String {
    p.path
        .iter()
        .map(|n| n.text.as_str())
        .collect::<Vec<_>>()
        .join(".")
}

#[inline(never)]
fn bind_stmt(ctx: &mut Body<'_, '_>, bind: &BindStmt) {
    if let Some(id) = ctx.decls.resolved.builder_binds.get(bind.id).copied() {
        super::builders::declaration(ctx, bind, id);
        return;
    }
    let annotation = bind.ty.as_ref().map(|ann| ctx.annotation(ann));
    let t = ctx.expr(&bind.value);
    let target = if let Some(ann) = &bind.ty {
        let annotation = annotation.unwrap_or(ITy::Error);
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
    ctx.bindings.push((bind.pattern.clone(), target));
}
