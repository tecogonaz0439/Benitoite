//! レコードの構築・更新・パターン（設計書 02-05「制約の生成」）。
use super::{
    context::Body,
    generate::{equal, flow},
    infer::{ITy, ReasonKind},
};
use crate::base::{BindingId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::{RecordExpr, RecordPat};
use crate::types::FieldInfo;
use std::collections::BTreeMap;

fn fields(ctx: &Body<'_, '_>, id: BindingId) -> Option<(String, Vec<FieldInfo>)> {
    let adt = ctx.decls.out.adts.get(id)?;
    Some((adt.name.clone(), adt.record.clone()?))
}
fn check_field(
    ctx: &mut Body<'_, '_>,
    name: &str,
    record: &str,
    span: Span,
    declared: &[FieldInfo],
    seen: &mut BTreeMap<String, Span>,
) -> Option<usize> {
    if let Some(first) = seen.insert(name.into(), span) {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::E0430)
                .arg("field", name)
                .primary(span)
                .secondary(first, "first")
                .build(),
        );
    }
    if let Some(i) = declared.iter().position(|f| f.name == name) {
        Some(i)
    } else {
        let mut d = DiagBuilder::new(DiagCode::E0429)
            .arg("name", record)
            .arg("field", name)
            .primary(span);
        let candidates =
            crate::resolve::suggest::candidates(name, declared.iter().map(|f| f.name.as_str()));
        if !candidates.is_empty() {
            d = d.arg(
                "candidates",
                candidates
                    .iter()
                    .map(|n| format!("`{n}`"))
                    .collect::<Vec<_>>()
                    .join(", "),
            );
            d = if let [candidate] = candidates.as_slice() {
                d.help_edits(
                    "similar",
                    vec![Edit {
                        span,
                        replacement: candidate.clone(),
                    }],
                )
            } else {
                d.help("similar")
            };
        }
        ctx.diagnostic(d.build());
        None
    }
}
pub(super) fn expr(ctx: &mut Body<'_, '_>, e: &RecordExpr) -> ITy {
    let Some(id) = ctx.decls.reference(e.id) else {
        return ITy::Error;
    };
    let Some((name, fields)) = fields(ctx, id) else {
        return ITy::Error;
    };
    let (_, params, ret) = ctx.instantiate(e.id, e.span, id);
    let mut seen = BTreeMap::new();
    if let Some(base) = &e.base {
        let t = ctx.expr(base);
        equal(ctx, ret.clone(), t, base.span(), ReasonKind::RecordBase);
    }
    for f in &e.fields {
        let t = ctx.expr(&f.value);
        if let Some(i) = check_field(ctx, &f.name.text, &name, f.name.span, &fields, &mut seen)
            && let Some(p) = params.get(i)
            && let Some(field) = fields.get(i)
        {
            let related = ctx.decls.asts.iter().flat_map(|m| &m.decls).find_map(|d| {
                let crate::syntax::ast::Item::Record(r) = &d.item else {
                    return None;
                };
                r.fields
                    .iter()
                    .find(|f| ctx.decls.binding(f.id) == Some(field.binding))
                    .map(|f| f.ty.span())
            });
            flow(
                ctx,
                t,
                p.clone(),
                &f.value,
                ReasonKind::RecordField {
                    field: field.binding,
                },
                related,
                false,
            );
        }
    }
    if e.base.is_none() {
        let missing = fields
            .iter()
            .filter(|f| !seen.contains_key(&f.name))
            .map(|f| f.name.clone())
            .collect::<Vec<_>>();
        if !missing.is_empty() {
            let mut d = DiagBuilder::new(DiagCode::E0428)
                .arg("name", name)
                .arg("fields", missing.join(", "))
                .primary(e.span);
            if let Some(span) = ctx.decls.resolved.bindings.get(id).and_then(|b| b.span) {
                d = d.secondary(span, "declared");
            }
            ctx.diagnostic(d.build());
        }
    }
    ret
}
pub(super) fn pattern(ctx: &mut Body<'_, '_>, p: &RecordPat) -> ITy {
    let Some(id) = ctx.decls.reference(p.id) else {
        return ITy::Error;
    };
    let Some((name, fields)) = fields(ctx, id) else {
        return ITy::Error;
    };
    let (_, params, ret) = ctx.instantiate(p.id, p.span, id);
    let mut seen = BTreeMap::new();
    for f in &p.fields {
        let t = ctx.pattern(&f.pattern);
        if let Some(i) = check_field(ctx, &f.name.text, &name, f.name.span, &fields, &mut seen)
            && let Some(expected) = params.get(i)
        {
            equal(
                ctx,
                expected.clone(),
                t,
                f.pattern.span(),
                ReasonKind::Pattern,
            );
        }
    }
    ret
}
