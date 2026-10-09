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
use crate::types::{ConstValue, EffectSet, TyCon, TyNames, builtin::BuiltinTypeId as B};

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
        Literal::Float(_) | Literal::Decimal(_) | Literal::Str(_) | Literal::Bool(_) => None,
    }
}
fn end_text(v: &ConstValue) -> String {
    match v {
        ConstValue::Integer(n) => n.to_string(),
        ConstValue::Character(c) => format!("'{}'", c.escape_default()),
        ConstValue::Float(_)
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
        // 対象とパターンの制約より後に解き、対象の誤りの理由を選択肢で上書きしない
        // （実装プラン F10「選択肢」）。
        equal(ctx, expected, found, span, ReasonKind::Alternatives);
    }
}
pub(super) fn guard(ctx: &mut Body<'_, '_>, g: &Expr) {
    let effect = ctx.fresh_effect();
    let ty = ctx.expr_in(g, effect.clone(), None);
    ctx.add(Constraint::EffSub {
        sub: effect,
        sup: fixed(EffectSet::empty()),
        reason: reason(g.span(), ReasonKind::MatchGuard),
    });
    equal(ctx, basic(B::BOOLEAN), ty, g.span(), ReasonKind::MatchGuard);
}

// 移し替えに失敗したパターンは検査しない。finalize が Error を Unit にする前に調べる
// （実装プラン F10「P4」、設計書 02-05「誤りの報告と検査の継続」）。
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
            ConstValue::Float(_)
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
// 再帰する移し替えでは collect のクロージャの枠を各段に重ねない（実装プラン F10）。
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
                    guarded: arm.guard.is_some(),
                })
            })
            .collect::<Option<Vec<_>>>()
        else {
            continue;
        };
        let ty = ctx.solver.finalize(&ty, ctx.decls.resolved);
        let issues = patterns::check_match(&ty, &arms, &ctx.decls.out.adts);
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
                    covering.extend(patterns::covering_alternatives(
                        &ty,
                        &arms,
                        i,
                        alt,
                        &ctx.decls.out.adts,
                    ));
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
            if let MatchIssue::NonExhaustive { witness } = issue {
                ctx.diagnostic(
                    DiagBuilder::new(DiagCode::E0601)
                        .arg("witness", witness)
                        .primary(m.scrutinee.span())
                        .help("add_arm")
                        .build(),
                );
            }
        }
    }
    for (bind, ty) in std::mem::take(&mut ctx.bindings) {
        if matches!(bind.pattern, Pattern::Var(_) | Pattern::Wildcard(_))
            || ctx.solver.contains_error(&ty)
        {
            continue;
        }
        let Some(pat) = lower(ctx, &bind.pattern) else {
            continue;
        };
        let ty = ctx.solver.finalize(&ty, ctx.decls.resolved);
        if patterns::is_irrefutable(&ty, &pat, &ctx.decls.out.adts) {
            continue;
        }
        let arms = [ArmPats {
            alts: vec![pat],
            guarded: false,
        }];
        let witness = patterns::check_match(&ty, &arms, &ctx.decls.out.adts)
            .into_iter()
            .find_map(|i| match i {
                MatchIssue::NonExhaustive { witness } => Some(witness),
                MatchIssue::Unreachable { .. } => None,
            })
            .unwrap_or_else(|| "_".into());
        let shown = ty.show(&TyNames {
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
            DiagBuilder::new(DiagCode::E0607)
                .arg("witness", witness)
                .arg("ty", shown)
                .primary(bind.pattern.span())
                .help("match")
                .build(),
        );
    }
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
    // 本番の差し込み口は増やさない（設計書 07-03「テストの設計の原則」、実装プラン F10）。
    #![allow(
        clippy::unwrap_used,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::diag::DiagCode as C;
    use crate::syntax::ast::{Item, Stmt};
    use crate::typeck::test_support::check_files;

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
            match_source("List[Integer]", " case [x, ..rest], [..rest, x] if x > 0 -> ()\n case _ -> ()"),
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
    // 再帰の枠が大きくなる退行を、既定のスレッドで捕まえる（実装プラン F10）。
    #[test]
    fn deep_expressions_stay_within_the_normal_stack() {
        for (prefix, leaf, suffix, depth) in [
            ("(1 + ", "1", ")", 450),
            ("(", "1", ")", 900),
            ("lambda() bind _ <- ", "()", "\nend lambda", 300),
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
