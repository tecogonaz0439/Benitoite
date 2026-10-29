//! 第二級の値である構築器と直接操作の検査（設計書 02-05「出力」「制約の生成」）。
use super::context::{Body, lift};
use super::generate::basic;
use super::infer::*;
use super::{BuilderDecl, BuilderKind, BuilderOperation};
use crate::base::BindingId;
use crate::diag::{DiagBuilder, DiagCode};
use crate::resolve::builders::{BuilderCall, BuilderClass, BuilderId, BuilderOp};
use crate::syntax::ast::{BindStmt, CallExpr};
use crate::types::builtin::BuiltinTypeId as B;

pub(super) fn declaration(ctx: &mut Body<'_, '_>, bind: &BindStmt, id: BindingId) {
    let Some(resolved) = ctx.decls.resolved.builder_decls.get(id) else {
        return;
    };
    let class = resolved.class;
    let kind = match class {
        BuilderClass::String => BuilderKind::String,
        BuilderClass::Bytes => BuilderKind::Bytes,
        BuilderClass::List => {
            let Some(crate::syntax::ast::TypeExpr::Named(t)) = &bind.ty else {
                return;
            };
            let Some(arg) = t.args.first() else { return };
            let ty = ctx.annotation(arg);
            BuilderKind::List(ctx.solver.finalize(&ty, ctx.decls.resolved))
        }
    };
    if let crate::syntax::ast::Expr::Call(call) = &bind.value {
        super::calls::builder(ctx, call, class, None, None, basic(B::UNIT));
    }
    ctx.decls.out.builders.insert(
        bind.id,
        BuilderDecl {
            id: BuilderId(id),
            kind,
            span: bind.span,
        },
    );
    // Γ のこの位置は通常の値の型を持たない。pattern/locals/expr_types へ加えない。
}

#[inline(never)]
pub(super) fn operation(ctx: &mut Body<'_, '_>, call: &CallExpr, info: BuilderCall) -> ITy {
    let decl = info
        .builder
        .and_then(|id| ctx.decls.resolved.builder_decls.get(id.0))
        .and_then(|d| ctx.decls.out.builders.get(d.bind))
        .cloned();
    let valid_target = info
        .builder
        .and_then(|id| ctx.decls.resolved.builder_decls.get(id.0))
        .is_some_and(|d| d.class == info.class);
    let kind = decl.as_ref().filter(|_| valid_target).map(|d| &d.kind);
    let contents = match kind {
        Some(BuilderKind::String) => basic(B::STRING),
        Some(BuilderKind::List(t)) => ITy::Con(
            crate::types::TyCon::Builtin(B::LIST),
            vec![lift(t)],
            crate::types::builtin::RangeIndex::TOP,
        ),
        Some(BuilderKind::Bytes) => basic(B::BYTES),
        // 対象の誤りはラベル・個数の後で診断する。ここで誤り型にすると
        // 呼び出しの計画自体が消えて対象の診断へ進めなくなる。
        None => match info.class {
            BuilderClass::String => basic(B::STRING),
            BuilderClass::List => ITy::Con(
                crate::types::TyCon::Builtin(B::LIST),
                vec![ctx.fresh_ty()],
                crate::types::builtin::RangeIndex::TOP,
            ),
            BuilderClass::Bytes => basic(B::BYTES),
        },
    };
    let result = match info.op {
        BuilderOp::Append | BuilderOp::AppendAll => basic(B::UNIT),
        BuilderOp::Copy => contents,
        BuilderOp::Length => basic(B::INTEGER),
    };
    super::calls::builder(ctx, call, info.class, kind, Some(info.op), result.clone());
    // 個数・ラベルの誤りを先に報告し、そこから対象や型の派生診断を作らない。
    let Some(plan) = ctx.call_plans.get(call.id).cloned() else {
        return result;
    };
    let Some(builder) = info.builder else {
        let span = call
            .args
            .iter()
            .zip(&plan.source_to_param)
            .find(|(_, p)| **p == 0)
            .and_then(|(a, _)| a.expr())
            .map_or(call.span, |e| e.span());
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0464)
                .primary(span)
                .help("copy")
                .build(),
        );
        return ITy::Error;
    };
    let Some(decl) = decl else { return ITy::Error };
    if !valid_target {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0464)
                .primary(call.span)
                .help("copy")
                .build(),
        );
        return ITy::Error;
    }
    ctx.decls.out.builder_ops.insert(
        call.id,
        BuilderOperation {
            builder,
            kind: decl.kind,
            op: info.op,
            args: call
                .args
                .iter()
                .zip(&plan.source_to_param)
                .filter(|(_, p)| **p != 0)
                .filter_map(|(a, _)| a.expr().map(|e| e.id()))
                .collect(),
        },
    );
    result
}
