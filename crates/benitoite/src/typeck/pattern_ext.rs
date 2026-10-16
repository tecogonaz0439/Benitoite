//! 範囲・リスト・選択肢・ガードの型付けと後検査（設計書 02-05「制約の生成」「本体の後の検査」）。
use super::{
    context::{Body, fixed, reason},
    generate::{basic, equal},
    infer::{Constraint, ITy, Reason, ReasonKind},
    patterns::{self, ArmPats, MatchIssue, Pat},
};
use crate::base::{NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, Edit};
use crate::resolve::BindingKind;
use crate::syntax::ast::{Expr, Literal, MatchArm, Pattern, RangeEnd};
use crate::types::{ConstValue, EffectSet, TyCon, builtin::BuiltinTypeId as B};

pub(super) fn pattern(ctx: &mut Body<'_, '_>, p: &Pattern) -> ITy {
    match p {
        Pattern::Range(p) => {
            let integer = matches!(
                (&p.lo.lit, &p.hi.lit),
                (Literal::Int { .. }, Literal::Int { .. })
            );
            let character = matches!((&p.lo.lit, &p.hi.lit), (Literal::Char(_), Literal::Char(_)))
                && !p.lo.negative
                && !p.hi.negative;
            if !integer && !character {
                ctx.diagnostic(DiagBuilder::new(DiagCode::E0606).primary(p.span).build());
                return ITy::Error;
            }
            let lo = range_end(ctx, &p.lo);
            let hi = range_end(ctx, &p.hi);
            if let (Some(lo), Some(hi)) = (lo, hi) {
                let reversed = match (&lo, &hi) {
                    (ConstValue::Integer(a), ConstValue::Integer(b)) => a > b,
                    (ConstValue::Character(a), ConstValue::Character(b)) => a > b,
                    _ => false,
                };
                if reversed {
                    let low = end_text(&lo);
                    let high = end_text(&hi);
                    ctx.diagnostic(
                        DiagBuilder::new(DiagCode::E0605)
                            .arg("low", &low)
                            .arg("high", &high)
                            .primary(p.span)
                            .help_edits(
                                "swap",
                                vec![Edit {
                                    span: p.span,
                                    replacement: format!("{high}..{low}"),
                                }],
                            )
                            .build(),
                    );
                } else {
                    ctx.decls.out.range_bounds.insert(p.id, (lo, hi));
                }
            }
            basic(if integer { B::INTEGER } else { B::CHARACTER })
        }
        Pattern::List(p) => {
            let elem = ctx.fresh_ty();
            let list = ITy::Con(TyCon::Builtin(B::LIST), vec![elem.clone()]);
            for child in p.before.iter().chain(&p.after) {
                let found = ctx.pattern(child);
                equal(ctx, elem.clone(), found, child.span(), ReasonKind::Pattern);
            }
            if let Some(rest) = &p.rest {
                if let Some(id) = ctx.decls.binding(rest.id) {
                    ctx.locals.insert(id, list.clone());
                }
                ctx.record_type(rest.id, list.clone());
            }
            list
        }
        Pattern::Wildcard(_)
        | Pattern::Var(_)
        | Pattern::Lit(_)
        | Pattern::Unit(_)
        | Pattern::Ctor(_)
        | Pattern::Record(_)
        | Pattern::Error(_) => ITy::Error,
    }
}
fn range_end(ctx: &mut Body<'_, '_>, end: &RangeEnd) -> Option<ConstValue> {
    match &end.lit {
        Literal::Int { radix, digits } => {
            let value = u64::from_str_radix(digits, *radix).ok().and_then(|n| {
                if end.negative {
                    if n == 1_u64.checked_shl(63).unwrap_or(0) {
                        Some(i64::MIN)
                    } else {
                        i64::try_from(n).ok().and_then(i64::checked_neg)
                    }
                } else {
                    i64::try_from(n).ok()
                }
            });
            if value.is_none() {
                ctx.diagnostic(
                    DiagBuilder::new(DiagCode::E0408)
                        .primary(end.span)
                        .note("range")
                        .build(),
                );
            }
            value.map(ConstValue::Integer)
        }
        Literal::Char(c) => Some(ConstValue::Character(*c)),
        Literal::WidthInt { .. }
        | Literal::WidthFloat { .. }
        | Literal::Float(_)
        | Literal::Decimal(_)
        | Literal::Str(_)
        | Literal::Bool(_) => None,
    }
}
fn end_text(v: &ConstValue) -> String {
    match v {
        ConstValue::Integer(n) => n.to_string(),
        ConstValue::Character(c) => format!("'{}'", c.escape_default()),
        ConstValue::Integer8(_)
        | ConstValue::Integer16(_)
        | ConstValue::Integer32(_)
        | ConstValue::UnsignedInteger16(_)
        | ConstValue::UnsignedInteger32(_)
        | ConstValue::UnsignedInteger64(_)
        | ConstValue::Float32(_)
        | ConstValue::Float(_)
        | ConstValue::String(_)
        | ConstValue::Boolean(_)
        | ConstValue::Unit
        | ConstValue::Byte(_)
        | ConstValue::Decimal(_)
        | ConstValue::Ctor { .. }
        | ConstValue::List(_)
        | ConstValue::Map(_)
        | ConstValue::Set(_) => String::new(),
    }
}
pub(super) fn alternatives(ctx: &mut Body<'_, '_>, arm: &MatchArm) {
    for p in arm.patterns.iter().skip(1) {
        let mut pending = vec![p];
        while let Some(p) = pending.pop() {
            match p {
                Pattern::Var(v) => alternative_binding(ctx, v.id, v.span),
                Pattern::Ctor(c) => pending.extend(&c.args),
                Pattern::Record(r) => pending.extend(r.fields.iter().map(|f| &f.pattern)),
                Pattern::List(l) => {
                    pending.extend(l.before.iter().chain(&l.after));
                    if let Some(rest) = &l.rest
                        && rest.name.is_some()
                    {
                        alternative_binding(ctx, rest.id, rest.span);
                    }
                }
                Pattern::Wildcard(_)
                | Pattern::Lit(_)
                | Pattern::Unit(_)
                | Pattern::Range(_)
                | Pattern::Error(_) => {}
            }
        }
    }
}
fn alternative_binding(ctx: &mut Body<'_, '_>, node: NodeId, span: Span) {
    if let Some(binding) = ctx.decls.reference(node)
        && let Some(expected) = ctx.locals.get(binding).cloned()
        && let Some(found) = ctx.expr_types.get(node).cloned()
    {
        // 対象とパターンの制約より後に解き、対象の誤りの理由を選択肢で上書きしない。
        equal(ctx, expected, found, span, ReasonKind::Alternatives);
    }
}
pub(super) fn guard(ctx: &mut Body<'_, '_>, g: &Expr) {
    let effect = ctx.fresh_effect();
    // ガードは外側の継続を使えないが、内側の handle は新しい節を加えられる。
    let clauses = std::mem::take(&mut ctx.clauses);
    let ty = ctx.expr_in(g, effect.clone(), None);
    ctx.clauses = clauses;
    ctx.add(Constraint::EffSub {
        sub: effect,
        sup: fixed(EffectSet::empty()),
        reason: reason(g.span(), ReasonKind::MatchGuard),
    });
    equal(ctx, basic(B::BOOLEAN), ty, g.span(), ReasonKind::MatchGuard);
}

// 移し替えに失敗したパターンは検査しない。finalize が Error を Unit にする前に調べる
// （設計書 02-05「誤りの報告と検査の継続」）。
#[inline(never)]
fn lower(ctx: &Body<'_, '_>, p: &Pattern) -> Option<Pat> {
    // 確定した型どうしの不一致には誤りにする型変数がない。パターンの位置の
    // E0401 も除外し、派生した網羅性の診断を出さない（設計書 02-05「誤りの報告と検査の継続」）。
    let span = p.span();
    if ctx.diagnostics.iter().any(|d| {
        d.code == Some(DiagCode::E0401)
            && d.primary.as_ref().is_some_and(|label| {
                label.span.file == span.file
                    && span.start <= label.span.start
                    && label.span.end <= span.end
            })
    }) {
        return None;
    }
    if ctx
        .expr_types
        .get(p.id())
        .is_some_and(|ty| ctx.solver.contains_error(ty))
    {
        return None;
    }
    match p {
        Pattern::Wildcard(_) | Pattern::Var(_) => Some(Pat::Wild),
        Pattern::Unit(_) => Some(Pat::Unit),
        Pattern::Lit(p) => match ctx.decls.out.lit_values.get(p.id)? {
            ConstValue::Integer(v) => Some(Pat::Integer(*v)),
            ConstValue::Character(v) => Some(Pat::Character(*v)),
            ConstValue::String(v) => Some(Pat::String(v.clone())),
            ConstValue::Boolean(v) => Some(Pat::Boolean(*v)),
            ConstValue::Integer8(_)
            | ConstValue::Integer16(_)
            | ConstValue::Integer32(_)
            | ConstValue::UnsignedInteger16(_)
            | ConstValue::UnsignedInteger32(_)
            | ConstValue::UnsignedInteger64(_)
            | ConstValue::Float32(_)
            | ConstValue::Float(_)
            | ConstValue::Unit
            | ConstValue::Byte(_)
            | ConstValue::Decimal(_)
            | ConstValue::Ctor { .. }
            | ConstValue::List(_)
            | ConstValue::Map(_)
            | ConstValue::Set(_) => None,
        },
        Pattern::Range(p) => match ctx.decls.out.range_bounds.get(p.id)? {
            (ConstValue::Integer(a), ConstValue::Integer(b)) => Some(Pat::IntegerRange(*a, *b)),
            (ConstValue::Character(a), ConstValue::Character(b)) => {
                Some(Pat::CharacterRange(*a, *b))
            }
            _ => None,
        },
        Pattern::Ctor(p) => lower_ctor(ctx, p),
        Pattern::Record(p) => {
            let adt = ctx.decls.reference(p.id)?;
            let fields = ctx.decls.out.adts.get(adt)?.record.as_ref()?;
            let mut seen = std::collections::BTreeSet::new();
            for f in &p.fields {
                if !seen.insert(&f.name.text) || !fields.iter().any(|decl| decl.name == f.name.text)
                {
                    return None;
                }
            }
            let args = fields
                .iter()
                .map(|decl| {
                    p.fields
                        .iter()
                        .find(|f| f.name.text == decl.name)
                        .map_or(Some(Pat::Wild), |f| lower(ctx, &f.pattern))
                })
                .collect::<Option<_>>()?;
            Some(Pat::Ctor { adt, tag: 0, args })
        }
        Pattern::List(p) => Some(Pat::List {
            before: p
                .before
                .iter()
                .map(|p| lower(ctx, p))
                .collect::<Option<_>>()?,
            rest: p.rest.is_some(),
            after: p
                .after
                .iter()
                .map(|p| lower(ctx, p))
                .collect::<Option<_>>()?,
        }),
        Pattern::Error(_) => None,
    }
}
// 再帰する移し替えでは collect のクロージャの枠を各段に重ねない。
#[inline(never)]
fn lower_ctor(ctx: &Body<'_, '_>, p: &crate::syntax::ast::CtorPat) -> Option<Pat> {
    let binding = ctx
        .decls
        .resolved
        .bindings
        .get(ctx.decls.reference(p.id)?)?;
    let BindingKind::Ctor { data, tag } = binding.kind else {
        return None;
    };
    let mut args = Vec::with_capacity(p.args.len());
    for arg in &p.args {
        args.push(lower(ctx, arg)?);
    }
    Some(Pat::Ctor {
        adt: data,
        tag,
        args,
    })
}
pub(super) fn check_body(ctx: &mut Body<'_, '_>) {
    let view = patterns::coverage_view(ctx.decls.modules, &ctx.decls.out.adts, ctx.module);
    for (m, ty) in std::mem::take(&mut ctx.matches) {
        if ctx.solver.contains_error(&ty) {
            continue;
        }
        let Some(arms) = m
            .arms
            .iter()
            .map(|arm| {
                Some(ArmPats {
                    alts: arm
                        .patterns
                        .iter()
                        .map(|p| lower(ctx, p))
                        .collect::<Option<_>>()?,
                    guarded: arm.guarded,
                })
            })
            .collect::<Option<Vec<_>>>()
        else {
            continue;
        };
        let ty = ctx.solver.finalize(&ty, ctx.decls.resolved);
        let Ok(checked) = patterns::check_match(&ty, &arms, &ctx.decls.out.adts, &view) else {
            ctx.diagnostic(coverage_stopped(
                m.scrutinee,
                super::text::COVERAGE_MATCH,
                "split",
            ));
            continue;
        };
        let issues = checked.issues;
        for (i, arm) in m.arms.iter().enumerate() {
            let unreachable = issues
                .iter()
                .filter_map(|issue| match issue {
                    MatchIssue::Unreachable { arm, alt, .. } if *arm == i => Some(*alt),
                    MatchIssue::Unreachable { .. } | MatchIssue::NonExhaustive { .. } => None,
                })
                .collect::<Vec<_>>();
            let whole = !unreachable.is_empty() && unreachable.len() == arm.patterns.len();
            let groups = if whole {
                vec![unreachable]
            } else {
                unreachable.into_iter().map(|alt| vec![alt]).collect()
            };
            for group in groups {
                let Some(first) = group.first().and_then(|alt| arm.patterns.get(*alt)) else {
                    continue;
                };
                let mut span = first.span();
                if whole && let Some(last) = arm.patterns.last() {
                    span.end = last.span().end;
                }
                let mut diag = DiagBuilder::new(if whole {
                    DiagCode::E0602
                } else {
                    DiagCode::E0608
                })
                .primary(span);
                let mut covering = vec![];
                for alt in group {
                    if let Some((_, positions)) = checked
                        .covering
                        .iter()
                        .find(|(position, _)| *position == (i, alt))
                    {
                        covering.extend_from_slice(positions);
                    }
                }
                covering.sort_unstable();
                covering.dedup();
                for (a, p) in covering {
                    if let Some(p) = m.arms.get(a).and_then(|a| a.patterns.get(p)) {
                        diag = diag.secondary(p.span(), "covering");
                    }
                }
                ctx.diagnostic(diag.build());
            }
        }
        for issue in issues {
            if let MatchIssue::NonExhaustive {
                witness,
                future_types,
            } = issue
            {
                let mut diag = DiagBuilder::new(DiagCode::E0601)
                    .arg("witness", witness)
                    .primary(m.scrutinee);
                if future_types.is_empty() {
                    diag = diag.help("add_arm");
                }
                ctx.diagnostic(with_future_diagnostics(ctx, diag.build(), &future_types));
            }
        }
    }
    for (pattern, ty) in std::mem::take(&mut ctx.bindings) {
        if matches!(pattern, Pattern::Var(_) | Pattern::Wildcard(_))
            || ctx.solver.contains_error(&ty)
        {
            continue;
        }
        let Some(pat) = lower(ctx, &pattern) else {
            continue;
        };
        let finalized = ctx.solver.finalize(&ty, ctx.decls.resolved);
        let Ok(checked) = patterns::check_binding(&finalized, &pat, &ctx.decls.out.adts, &view)
        else {
            ctx.diagnostic(coverage_stopped(
                pattern.span(),
                super::text::COVERAGE_PATTERN,
                "split_pattern",
            ));
            continue;
        };
        let Some(witness) = checked.witness else {
            continue;
        };
        let shown = ctx.show_type(&ty);
        let mut diag = DiagBuilder::new(DiagCode::E0607)
            .arg("witness", witness)
            .arg("ty", shown)
            .primary(pattern.span());
        if checked.future_types.is_empty() {
            diag = diag.help("match");
        }
        ctx.diagnostic(with_future_diagnostics(
            ctx,
            diag.build(),
            &checked.future_types,
        ));
    }
}
// 同名の型でも宣言の束縛で副位置を引く。複数の型の help は各型の引数で別々に作る。
fn with_future_diagnostics(
    ctx: &Body<'_, '_>,
    mut diagnostic: Diagnostic,
    future_types: &std::collections::BTreeSet<crate::base::BindingId>,
) -> Diagnostic {
    let Some(code) = diagnostic.code else {
        return diagnostic;
    };
    for id in future_types {
        let Some(adt) = ctx.decls.out.adts.get(*id) else {
            continue;
        };
        let mut extra = DiagBuilder::new(code)
            .arg("future_ty", &adt.name)
            .help("future");
        if let Some(span) = ctx.decls.resolved.bindings.get(*id).and_then(|b| b.span) {
            extra = extra.secondary(span, "extensible_decl");
        }
        let extra = extra.build();
        diagnostic.secondary.extend(extra.secondary);
        diagnostic.helps.extend(extra.helps);
    }
    diagnostic
}

fn coverage_stopped(span: Span, subject: &str, help: &'static str) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0609)
        .arg("subject", subject)
        .arg("limit", super::limits::MAX_COVERAGE_WORK.to_string())
        .primary(span)
        .help(help)
        .build()
}
pub(super) fn effect_failure(
    _: &mut Body<'_, '_>,
    _: &Reason,
    effect: &str,
    origin: Span,
) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0504)
        .arg("effect", effect)
        .primary(origin)
        .help("body")
        .build()
}

#[cfg(test)]
mod tests {
    // 型検査の公開の結果で、AST からの移し替え・制約の順序・診断位置を守る。
    // 判定 API だけのテストはこの接続の失敗を捕まえない。実際の読み込みと名前解決を使い、
    // 本番の差し込み口は増やさない（設計書 07-03「テストの設計の原則」）。
    #![allow(
        clippy::unwrap_used,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::diag::DiagCode as C;
    use crate::syntax::ast::{Item, Stmt};
    use crate::typeck::test_support::check_files;

    // 宣言の公開出力を設定し、同名の型と入れ子の反例を本体の型検査で区別する。
    // 新しい本番の差し込み口を作らず、診断の主文・位置・help と lowering の接続を確かめる。
    #[test]
    fn future_diagnostics_keep_declaration_identity_and_nested_witnesses() {
        for (decl, ty, known, future) in [
            (
                "data Failure\n Only\nend data",
                "Failure",
                "Failure.Only",
                "<future constructor of Failure>",
            ),
            (
                "record Failure\n detail: Unit\nend record",
                "Failure",
                "Failure(detail: _, ..)",
                "<future shape of Failure>",
            ),
        ] {
            for (nested, binding) in [(false, false), (false, true), (true, false), (true, true)] {
                let known = if nested {
                    format!("Envelope(detail: {known})")
                } else {
                    known.to_owned()
                };
                let ty = if nested { "Envelope" } else { ty };
                let nested_decl = if nested {
                    "record Envelope\n detail: Failure\nend record\n"
                } else {
                    ""
                };
                let body = if binding {
                    format!("bind {known} <- value")
                } else {
                    format!("match value with\ncase {known} -> ()\nend match")
                };
                let source = format!(
                    "{decl}\n{nested_decl}function f(value: {ty}) -> Unit\n{body}\nend function"
                );
                let (load, resolved, out, diagnostics) =
                    check_files(&[("main.bnt", &source)], false);
                assert!(diagnostics.is_empty(), "{diagnostics:#?}");
                let id = out
                    .adts
                    .adts
                    .iter()
                    .find(|(_, d)| d.name == "Failure")
                    .unwrap()
                    .0;
                for external in [false, true] {
                    let mut decls = super::super::decls::Decls::new(
                        &load.modules,
                        &load.asts,
                        &load.sources,
                        &resolved,
                    );
                    // 型表だけを使う。既存の式の結果・制約を準備データで与えない。
                    decls.out.adts = out.adts.clone();
                    decls.out.decl_types = out.decl_types.clone();
                    let mut def = decls.out.adts.get(id).unwrap().clone();
                    def.extensible = true;
                    if external {
                        def.module = resolved
                            .bindings
                            .iter()
                            .find(|(_, b)| b.name == "Benitoite")
                            .unwrap()
                            .1
                            .module;
                    }
                    decls.out.adts.adts.insert(id, def);
                    for ast in &load.asts {
                        for top in &ast.decls {
                            if let Item::Fn(f) = &top.item
                                && f.name.text == "f"
                            {
                                super::super::generate::check_function(&mut decls, f);
                            }
                        }
                    }
                    if !external {
                        assert!(decls.diagnostics.is_empty(), "{:?}", decls.diagnostics);
                        continue;
                    }
                    assert_eq!(decls.diagnostics.len(), 1, "{:?}", decls.diagnostics);
                    let d = &decls.diagnostics[0];
                    assert_eq!(d.code, Some(if binding { C::E0607 } else { C::E0601 }));
                    assert_eq!(
                        d.message,
                        if binding {
                            format!("this pattern does not match every value of `{ty}`")
                        } else {
                            "`match` does not cover every value".to_owned()
                        }
                    );
                    assert_eq!(
                        d.primary.as_ref().unwrap().text,
                        format!(
                            "`{}` is not matched",
                            if nested {
                                format!("Envelope(detail: {future})")
                            } else {
                                future.to_owned()
                            }
                        )
                    );
                    let needle = if binding {
                        known.as_str()
                    } else {
                        "value with"
                    };
                    let start = source.find(needle).unwrap();
                    let span = d.primary.as_ref().unwrap().span;
                    assert_eq!(
                        (span.start.0 as usize, span.end.0 as usize),
                        (
                            start,
                            start + if binding { known.len() } else { "value".len() }
                        )
                    );
                    assert_eq!(d.secondary.len(), 1);
                    assert_eq!(
                        d.secondary[0].span,
                        resolved.bindings.get(id).unwrap().span.unwrap()
                    );
                    assert_eq!(
                        d.secondary[0].text,
                        "this type permits future shapes outside its package"
                    );
                    let helps = d
                        .helps
                        .iter()
                        .map(|h| h.message.as_str())
                        .collect::<Vec<_>>();
                    let future_help = if binding {
                        "use `match ... with` and add an unguarded `case _ ->` branch to cover future values of `Failure`"
                    } else {
                        "add an unguarded variable or `_` pattern to cover future values of `Failure`"
                    };
                    assert_eq!(helps, vec![future_help]);
                    assert!(d.helps.iter().all(|h| h.edits.is_empty()));
                }
            }
        }
    }

    // 実際の属性・import・パッケージから view を作る境界を確かめる。
    // 判定 API の型表だけでは、別名の展開と内側の文脈への所属の受け渡しを守れない。
    // ジェネリックな型と欄の型引数の置換後も、型の束縛番号で指定を選ぶ。
    #[test]
    fn extensible_source_patterns_keep_package_and_nested_context() {
        let declarations = format!(
            "{}\n@extensible\npublic data Box[T]\n Wrap(T)\nend data\n",
            include_str!("../../testdata/packages/d8-extensible.files/dep/Types.bnt")
        );
        let cases = [
            (
                "known",
                "Types.Kind",
                "match n with\ncase Types.Kind.Known -> ()\ncase Types.Kind.Other -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "alias",
                "Alias",
                "match n with\ncase Types.Kind.Known -> ()\ncase Types.Kind.Other -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "generic",
                "Types.Box[Alias]",
                "match n with\ncase Types.Box.Wrap(_) -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Box"),
            ),
            (
                "generic-argument",
                "ContainerOf[Alias]",
                "match n with\ncase ContainerOf(value: Types.Kind.Known) -> ()\ncase ContainerOf(value: Types.Kind.Other) -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "other",
                "Alias",
                "match n with\ncase Types.Kind.Known -> ()\ncase Types.Kind.Other -> ()\ncase other -> ()\nend match",
                Some(C::E0602),
                None,
                None,
            ),
            (
                "result",
                "Result[Unit, Alias]",
                "match n with\ncase Result.Ok(_) -> ()\ncase Result.Error(Types.Kind.Known) -> ()\ncase Result.Error(Types.Kind.Other) -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "result-variable",
                "Result[Unit, Alias]",
                "match n with\ncase Result.Ok(_) -> ()\ncase Result.Error(error) -> ()\nend match",
                None,
                None,
                None,
            ),
            (
                "option",
                "Option[Alias]",
                "match n with\ncase Option.None -> ()\ncase Option.Some(Types.Kind.Known) -> ()\ncase Option.Some(Types.Kind.Other) -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "list",
                "List[Alias]",
                "match n with\ncase [] -> ()\ncase [Types.Kind.Known, ..] -> ()\ncase [Types.Kind.Other, ..] -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "record-field",
                "Envelope",
                "match n with\ncase Envelope(kind: Types.Kind.Known) -> ()\ncase Envelope(kind: Types.Kind.Other) -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "record",
                "Types.Detail",
                "match n with\ncase Types.Detail(value: _, ..) -> ()\nend match",
                None,
                Some(C::E0601),
                Some("Detail"),
            ),
            (
                "guard",
                "Alias",
                "match n with\ncase Types.Kind.Known -> ()\ncase Types.Kind.Other -> ()\ncase other if true -> ()\nend match",
                Some(C::E0602),
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "alternative",
                "Alias",
                "match n with\ncase Types.Kind.Known, Types.Kind.Other, _ -> ()\nend match",
                Some(C::E0608),
                None,
                None,
            ),
            (
                "duplicate-arm",
                "Alias",
                "match n with\ncase _ -> ()\ncase other -> ()\nend match",
                Some(C::E0602),
                Some(C::E0602),
                None,
            ),
            (
                "duplicate-alternative",
                "Alias",
                "match n with\ncase _, Types.Kind.Known -> ()\nend match",
                Some(C::E0608),
                Some(C::E0608),
                None,
            ),
            (
                "single-bind",
                "Types.Single",
                "bind Types.Single.Only(_) <- n",
                None,
                Some(C::E0607),
                Some("Single"),
            ),
            (
                "record-bind",
                "Types.Detail",
                "bind Types.Detail(value: _, ..) <- n",
                None,
                Some(C::E0607),
                Some("Detail"),
            ),
            (
                "nested-bind",
                "Container",
                "bind Container(value: Types.Single.Only(_)) <- n",
                None,
                Some(C::E0607),
                Some("Single"),
            ),
            (
                "variable-bind",
                "Types.Single",
                "bind value <- n",
                None,
                None,
                None,
            ),
            ("wild-bind", "Types.Detail", "bind _ <- n", None, None, None),
            (
                "lambda",
                "Alias",
                "bind action <- lambda() -> Unit\nmatch n with\ncase Types.Kind.Known -> ()\ncase Types.Kind.Other -> ()\nend match\nend lambda",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "lazy",
                "Alias",
                "bind delayed <- lazy\nmatch n with\ncase Types.Kind.Known -> ()\ncase Types.Kind.Other -> ()\nend match\nend lazy",
                None,
                Some(C::E0601),
                Some("Kind"),
            ),
            (
                "getter-update",
                "Types.Detail",
                "bind updated <- Types.Detail(..n, value: 1)\nbind _ <- Types.Detail.value(updated)",
                None,
                None,
                None,
            ),
            (
                "wrong-arity",
                "Types.Single",
                "bind Types.Single.Only() <- n",
                Some(C::E0412),
                Some(C::E0412),
                None,
            ),
            (
                "wrong-pattern-type",
                "Alias",
                "match n with\ncase true -> ()\nend match",
                Some(C::E0401),
                Some(C::E0401),
                None,
            ),
        ];
        for (name, ty, body, author, consumer, future_type) in cases {
            for external in [false, true] {
                let import = if external { "Dep.Types" } else { "Types" };
                let source = format!(
                    "import {import}\ntype Alias = Types.Kind\nrecord Envelope\n kind: Alias\nend record\nrecord Container\n value: Types.Single\nend record\nrecord ContainerOf[T]\n value: T\nend record\nfunction f(n: {ty}) -> Unit\n{body}\n()\nend function\n"
                );
                let declaration_path = if external {
                    "dep/Types.bnt"
                } else {
                    "Types.bnt"
                };
                let mut files = vec![
                    ("main.bnt", source.as_str()),
                    (declaration_path, declarations.as_str()),
                ];
                if external {
                    files.extend([
                        (
                            "package.bnt",
                            "language \"0.0.6\"\ndependency Dep\n path \"dep\"\nend dependency\n",
                        ),
                        (
                            "dep/package.bnt",
                            include_str!(
                                "../../testdata/packages/d8-extensible.files/dep/package.bnt"
                            ),
                        ),
                    ]);
                }
                let (_, resolved, _, diagnostics) = check_files(&files, false);
                let expected = if external { consumer } else { author };
                assert_eq!(
                    diagnostics
                        .iter()
                        .map(|d| d.code.unwrap())
                        .collect::<Vec<_>>(),
                    expected.into_iter().collect::<Vec<_>>(),
                    "{name}/{external}: {diagnostics:#?}"
                );
                if external && let Some(future_type) = future_type {
                    let diagnostic = &diagnostics[0];
                    let future = if future_type == "Detail" {
                        format!("<future shape of {future_type}>")
                    } else {
                        format!("<future constructor of {future_type}>")
                    };
                    let witness = match name {
                        "result" => format!("Result.Error({future})"),
                        "option" => format!("Option.Some({future})"),
                        "list" => format!("[{future}, ..]"),
                        "record-field" => format!("Envelope(kind: {future})"),
                        "nested-bind" => format!("Container(value: {future})"),
                        "generic-argument" => format!("ContainerOf(value: {future})"),
                        _ => future,
                    };
                    let primary = diagnostic.primary.as_ref().unwrap();
                    assert_eq!(
                        primary.text,
                        format!("`{witness}` is not matched"),
                        "{name}"
                    );
                    let (start, length) = if consumer == Some(C::E0607) {
                        let start = source.find("bind ").unwrap() + "bind ".len();
                        (start, source[start..].find(" <-").unwrap())
                    } else {
                        (source.find("match n with").unwrap() + "match ".len(), 1)
                    };
                    assert_eq!(
                        (primary.span.start.0 as usize, primary.span.end.0 as usize),
                        (start, start + length),
                        "{name}"
                    );
                    let declaration = resolved
                        .bindings
                        .iter()
                        .find(|(_, b)| {
                            b.name == future_type
                                && matches!(b.kind, BindingKind::Data | BindingKind::Record)
                        })
                        .unwrap()
                        .1;
                    assert_eq!(diagnostic.secondary.len(), 1, "{name}");
                    assert_eq!(
                        diagnostic.secondary[0].span,
                        declaration.span.unwrap(),
                        "{name}"
                    );
                    assert_eq!(
                        diagnostic.secondary[0].text,
                        "this type permits future shapes outside its package",
                        "{name}"
                    );
                    let future_help = if consumer == Some(C::E0607) {
                        format!(
                            "use `match ... with` and add an unguarded `case _ ->` branch to cover future values of `{future_type}`"
                        )
                    } else {
                        format!(
                            "add an unguarded variable or `_` pattern to cover future values of `{future_type}`"
                        )
                    };
                    let helps = vec![future_help];
                    assert_eq!(
                        diagnostic
                            .helps
                            .iter()
                            .map(|h| h.message.clone())
                            .collect::<Vec<_>>(),
                        helps,
                        "{name}"
                    );
                    assert!(diagnostic.helps.iter().all(|h| h.edits.is_empty()));
                }
            }
        }
    }

    fn check(s: &str) -> Vec<Diagnostic> {
        check_files(&[("main.bnt", s)], false).3
    }
    fn clean(s: &str) {
        let d = check(s);
        assert!(d.is_empty(), "{s}\n{d:#?}");
    }
    fn match_source(ty: &str, arms: &str) -> String {
        format!("function f(n: {ty}) -> Unit\n match n with\n{arms}\n end match\nend function\n")
    }
    fn expect(s: &str, expected: &[(C, &str, usize)]) -> Vec<Diagnostic> {
        let d = check(s);
        assert_eq!(
            d.iter().map(|d| d.code.unwrap()).collect::<Vec<_>>(),
            expected.iter().map(|e| e.0).collect::<Vec<_>>(),
            "{s}\n{d:#?}"
        );
        for (d, (_, needle, occurrence)) in d.iter().zip(expected) {
            let start = s.match_indices(needle).nth(*occurrence).unwrap().0;
            let span = d.primary.as_ref().unwrap().span;
            assert_eq!(
                (span.start.0 as usize, span.end.0 as usize),
                (start, start + needle.len()),
                "{s}\n{d:#?}"
            );
        }
        d
    }
    // 判定 API では捕まえられない、レコードの省略した欄の lowering と診断との接続を確かめる。
    #[test]
    fn repeated_boolean_groups_check_without_diagnostics() {
        let n = 12;
        let mut source = String::from("record Flags\n");
        for i in 0..4 * n + 1 {
            source.push_str(&format!(" f{i}: Boolean\n"));
        }
        source.push_str("end record\nfunction f(flags: Flags) -> Unit\n match flags with\n");
        for group in 0..n {
            let fields = (4 * group..4 * group + 4)
                .map(|i| format!("f{i}: false"))
                .collect::<Vec<_>>()
                .join(", ");
            source.push_str(&format!(" case Flags({fields}, ..) -> ()\n"));
        }
        for value in [true, false] {
            source.push_str(&format!(" case Flags(f{}: {value}, ..) -> ()\n", 4 * n));
        }
        source.push_str(" end match\nend function\n");
        clean(&source);
    }
    #[test]
    fn binding_budget_reports_only_coverage_stopped_at_the_pattern() {
        let mut source = String::from("record Units\n");
        for i in 0..1100 {
            source.push_str(&format!(" f{i}: Unit\n"));
        }
        let prefix = source;
        let tail_pattern = "Units(f1099: (), ..)";
        clean(&format!(
            "{prefix}end record\nfunction f(units: Units) -> Unit\n bind {tail_pattern} <- units\n ()\nend function\n"
        ));
        // 各欄を明示すれば構成子ごとの入力が異なり、記憶で行列の複製を省けない。
        let fields = (0..800)
            .map(|i| format!("f{i}: ()"))
            .collect::<Vec<_>>()
            .join(", ");
        let pattern = format!("Units({fields}, ..)");
        let source = format!(
            "{prefix}end record\nfunction f(units: Units) -> Unit\n bind {pattern} <- units\n ()\nend function\n"
        );
        expect(&source, &[(C::E0609, &pattern, 0)]);
    }
    #[test]
    fn range_and_list_outputs_feed_lowering() {
        let commands = include_str!("../../testdata/patterns/f04_commands.bnt");
        let (load, _, out, diagnostics) = check_files(&[("main.bnt", commands)], false);
        assert!(diagnostics.is_empty(), "{diagnostics:#?}");
        let dispatch = load.asts[0]
            .decls
            .iter()
            .find_map(|d| match &d.item {
                Item::Fn(f) if f.name.text == "dispatch" => Some(f),
                Item::Fn(_)
                | Item::Const(_)
                | Item::Data(_)
                | Item::Record(_)
                | Item::Alias(_)
                | Item::Trait(_)
                | Item::Impl(_)
                | Item::Effect(_)
                | Item::ExternalType(_)
                | Item::Error(_) => None,
            })
            .unwrap();
        let Stmt::Expr(Expr::Match(m)) = &dispatch.body.as_ref().unwrap().stmts[0] else {
            unreachable!()
        };
        let Pattern::List(list) = &m.arms[2].patterns[0] else {
            unreachable!()
        };
        assert_eq!(
            out.expr_types.get(list.rest.as_ref().unwrap().id),
            Some(&crate::types::Ty::Con(
                TyCon::Builtin(B::LIST),
                vec![crate::types::Ty::Con(TyCon::Builtin(B::STRING), vec![])]
            ))
        );
        let s = "function grade(score: Integer) -> String\n return match score with\n case n if n < 0 -> \"invalid\"\n case 90..100 -> \"A\"\n case 70..89 -> \"B\"\n case _ -> \"C\"\n end match\nend function";
        let (load, _, out, d) = check_files(&[("main.bnt", s)], false);
        assert!(d.is_empty(), "{d:#?}");
        let Item::Fn(f) = &load.asts[0].decls[0].item else {
            unreachable!()
        };
        let Stmt::Expr(Expr::Return(ret)) = &f.body.as_ref().unwrap().stmts[0] else {
            unreachable!()
        };
        let Expr::Match(m) = ret.value.as_ref() else {
            unreachable!()
        };
        for (i, lo, hi) in [(1, 90, 100), (2, 70, 89)] {
            let bounds = out.range_bounds.get(m.arms[i].patterns[0].id()).unwrap();
            assert!(
                matches!(bounds, (ConstValue::Integer(a),ConstValue::Integer(b)) if *a == lo && *b == hi)
            );
        }
    }
    #[test]
    fn exhaustive_and_irrefutable_examples() {
        for s in [
            match_source("List[Integer]", " case [] -> ()\n case [_, ..] -> ()"),
            match_source("Integer", " case x if x > 0 -> ()\n case _ -> ()"),
            "record Person\n name: String\n age: Integer\nend record\nfunction f(person: Person, xs: List[Integer]) -> Unit\n bind Pair(count, label) <- Pair(3, \"items\")\n bind Person(name: n, ..) <- person\n bind [..rest] <- xs\n bind [..] <- rest\n ()\nend function".into(),
            "data L\n Mk(L)\nend data\nfunction f(n: L) -> Unit\n match n with\n case L.Mk(_) -> ()\n end match\nend function".into(),
            match_source("Integer", " case -9223372036854775808..9223372036854775807 -> ()\n case _ -> ()"),
            match_source("Character", " case 'a'..'z' -> ()\n case _ -> ()"),
            match_source("List[Integer]", " case [x, 0, ..rest], [..rest, 0, x] if x > 0 -> ()\n case _ -> ()"),
        ] { clean(&s); }
    }
    #[test]
    fn nonexhaustive_witnesses_and_refutable_bindings() {
        for (s,code,needle,witness) in [
            ("data Tree\n Leaf\n Node(Tree, Integer, Tree)\nend data\nfunction f(n: Tree) -> Unit\n match n with\n case Tree.Leaf -> ()\n end match\nend function".into(), C::E0601, "n with", "Tree.Node(_, _, _)"),
            (match_source("List[Integer]", " case [] -> ()\n case [x] -> ()"), C::E0601, "n with", "[_, _, ..]"),
            (match_source("Integer", " case 0..9 -> ()\n case 10..100 -> ()\n case -100..-1 -> ()"), C::E0601, "n with", "_"),
            ("function f(text: String) -> Unit\n bind Option.Some(x) <- Integer.parse(text)\nend function".into(), C::E0607, "Option.Some(x)", "Option.None"),
            ("function f(xs: List[Integer]) -> Unit\n bind [x] <- xs\nend function".into(), C::E0607, "[x]", "[]"),
        ] {
            let d = check(&s);
            assert_eq!(d.iter().map(|d| d.code).collect::<Vec<_>>(), vec![Some(code)], "{s}\n{d:#?}");
            let primary = d[0].primary.as_ref().unwrap();
            let start = s.find(needle).unwrap();
            let len = if code == C::E0601 { 1 } else { needle.len() };
            assert_eq!((primary.span.start.0 as usize, primary.span.end.0 as usize), (start, start + len));
            assert_eq!(primary.text, format!("`{witness}` is not matched"));
            assert_eq!(d[0].helps.len(), 1);
        }
    }
    // spec: 01-05 選ばれない分岐の検査
    #[test]
    fn unreachable_diagnostics_identify_covering_alternatives() {
        for (ty, arms, code, needle, occurrence, cover) in [
            (
                "Integer",
                " case _ -> ()\n case 0 -> ()",
                C::E0602,
                "0",
                0,
                "_",
            ),
            (
                "Integer",
                " case 1, 1 -> ()\n case _ -> ()",
                C::E0608,
                "1",
                1,
                "1",
            ),
            (
                "Integer",
                " case 1, 1 if true -> ()\n case _ -> ()",
                C::E0608,
                "1",
                1,
                "1",
            ),
            (
                "Integer",
                " case 1..10 -> ()\n case 5 -> ()\n case _ -> ()",
                C::E0602,
                "5",
                0,
                "1..10",
            ),
            (
                "Integer",
                " case _ -> ()\n case x if x > 0 -> ()",
                C::E0602,
                "x",
                0,
                "_",
            ),
            (
                "Integer",
                " case 1..10 -> ()\n case 2, 3 -> ()\n case _ -> ()",
                C::E0602,
                "2, 3",
                0,
                "1..10",
            ),
            (
                "Integer",
                " case 1, 2 -> ()\n case 2, 3 -> ()\n case _ -> ()",
                C::E0608,
                "2",
                1,
                "2",
            ),
        ] {
            let s = match_source(ty, arms);
            let d = expect(&s, &[(code, needle, occurrence)]);
            assert_eq!(d[0].secondary.len(), 1);
            assert_eq!(
                d[0].secondary[0].span.start.0 as usize,
                s.find(cover).unwrap()
            );
            assert_eq!(
                d[0].secondary[0].span.end.0 as usize,
                s.find(cover).unwrap() + cover.len()
            );
        }
    }
    #[test]
    fn malformed_patterns_do_not_cascade_into_coverage_errors() {
        for (arms, code, needle) in [
            (" case 5..1 -> ()", C::E0605, "5..1"),
            (" case true -> ()", C::E0401, "true"),
            (" case 1..'z' -> ()", C::E0606, "1..'z'"),
            (
                " case 9223372036854775808..9223372036854775809 -> ()",
                C::E0408,
                "9223372036854775808",
            ),
            (
                " case 9223372036854775808 -> ()",
                C::E0408,
                "9223372036854775808",
            ),
        ] {
            let s = match_source("Integer", arms);
            if arms.contains("..9223372036854775809") {
                expect(&s, &[(code, needle, 0), (code, "9223372036854775809", 0)]);
            } else {
                expect(&s, &[(code, needle, 0)]);
            }
        }
        expect(
            "function f() -> Unit\n match Option.None() with\n case Option.Some(_) -> ()\n end match\nend function",
            &[(C::E0413, "Option.None()", 0)],
        );
        for (ty, arms, code, needle) in [
            (
                "Option[Integer]",
                " case Option.Some() -> ()",
                C::E0412,
                "Option.Some()",
            ),
            (
                "Option[Integer]",
                " case Option.None() -> ()",
                C::E0413,
                "Option.None()",
            ),
            ("Person", " case Person(no: _) -> ()", C::E0429, "no"),
            (
                "Person",
                " case Person(age: _, age: _) -> ()",
                C::E0430,
                "age",
            ),
        ] {
            let s = format!(
                "record Person\n age: Integer\nend record\n{}",
                match_source(ty, arms)
            );
            expect(&s, &[(code, needle, if code == C::E0430 { 2 } else { 0 })]);
        }
        let s = match_source("Character", " case 1..9 -> ()");
        expect(&s, &[(C::E0401, "1..9", 0)]);
        let s = match_source("Character", " case 'z'..'\\n' -> ()");
        let d = expect(&s, &[(C::E0605, "'z'..'\\n'", 0)]);
        assert_eq!(d[0].helps[0].edits[0].replacement, "'\\n'..'z'");
    }
    #[test]
    fn guards_and_alternative_bindings_use_their_own_reasons() {
        let s = match_source("Integer", " case x if x + 1 -> ()\n case _ -> ()");
        let d = expect(&s, &[(C::E0401, "x + 1", 0)]);
        assert_eq!(d[0].notes, ["a condition must have type `Boolean`"]);
        let s = "import Benitoite.Unofficial.IO.Console\nfunction ready() -> Boolean uses Console.Write\n Console.writeLine(\"ready\")\n return true\nend function\nfunction f(n: Integer) -> Unit\n match n with\n case x if ready() -> ()\n case _ -> ()\n end match\nend function";
        let d = expect(s, &[(C::E0504, "ready()", 1)]);
        assert_eq!(
            d[0].helps[0].message,
            "compute the condition in the branch body instead"
        );
        for (s, needle, occurrence) in [
            (
                match_source("Option[Integer]", " case Option.Some(x), x -> ()"),
                "x",
                1,
            ),
            (
                match_source(
                    "List[List[Integer]]",
                    " case [x, ..rest], [..x, rest] -> ()\n case _ -> ()",
                ),
                "..x",
                0,
            ),
        ] {
            let d = expect(&s, &[(C::E0401, needle, occurrence)]);
            assert!(
                d[0].notes
                    .iter()
                    .any(|n| n == "a variable bound in several alternatives must have one type")
            );
        }
        let s = match_source("Integer", " case Option.Some(x), x -> ()\n case _ -> ()");
        let d = expect(&s, &[(C::E0401, "Option.Some(x)", 0)]);
        assert!(!d[0].notes.iter().any(|n| n.contains("alternatives")));
    }
    // 型検査の入口で深い AST の検査結果まで確かめる。分岐を追加したときに
    // 再帰の枠が大きくなる退行を、既定のスレッドで捕まえる。
    #[test]
    fn deep_expressions_stay_within_the_normal_stack() {
        for (prefix, leaf, suffix, depth) in [
            ("(1 + ", "1", ")", 450),
            ("(", "1", ")", 900),
            ("lambda()\n bind _ <- ", "()", "\nend lambda", 300),
            ("if true then ", "1", " else 0 end if", 450),
            (
                "match true with\n case true -> ",
                "1",
                "\n case false -> 0\n end match",
                200,
            ),
            (
                "match ",
                "true",
                " with\n case true -> true\n case false -> false\n end match",
                450,
            ),
        ] {
            let nested = format!("{}{leaf}{}", prefix.repeat(depth), suffix.repeat(depth));
            clean(&format!(
                "function f() -> Unit\n bind _ <- {nested}\nend function"
            ));
        }
    }
    #[test]
    fn deep_list_patterns_stay_within_the_normal_stack() {
        let depth = 450;
        let ty = format!("{}Integer{}", "List[".repeat(depth), "]".repeat(depth));
        let pat = format!("{}_{}", "[".repeat(depth), "]".repeat(depth));
        clean(&match_source(
            &ty,
            &format!(" case {pat} -> ()\n case _ -> ()"),
        ));
    }
    #[test]
    fn deep_constructor_patterns_stay_within_the_normal_stack() {
        let nested = format!("{}_{suffix}", "L.Mk(".repeat(900), suffix = ")".repeat(900));
        let s = format!(
            "data L\n Mk(L)\nend data\n{}",
            match_source("L", &format!(" case {nested} -> ()"))
        );
        clean(&s);
    }
    #[test]
    fn specified_golden_examples_and_all_standard_modules_typecheck() {
        for s in [
            include_str!("../../testdata/patterns/f10_list_exhaustive.bnt"),
            include_str!("../../testdata/patterns/f10_guarded.bnt"),
            include_str!("../../testdata/patterns/f10_irrefutable.bnt"),
        ] {
            clean(s);
        }
        let imports = crate::prelude::STDLIB
            .iter()
            .filter(|m| !m.prelude)
            .map(|m| {
                format!(
                    "import Benitoite.{}{}",
                    if m.unofficial { "Unofficial." } else { "" },
                    m.path.join(".")
                )
            })
            .collect::<Vec<_>>()
            .join("\n");
        clean(&format!("{imports}\nfunction main() -> Unit\nend function"));
    }
}
