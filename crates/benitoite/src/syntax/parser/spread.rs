//! リスト展開の解析と診断（設計書 01-02「リストの展開」、ADR 0272）。
use super::{PResult, Parser, child, exprs};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{
    ast::{ListElem, ListExpr, SpreadElem},
    token::TokenKind,
};

pub(super) fn parse_spread_elem(
    p: &mut Parser,
    depth: u32,
    out: &mut Vec<ListElem>,
) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let marker = p.bump();
    let mut written = marker.span;
    let invalid = if marker.kind == TokenKind::Star {
        true
    } else if p.at(TokenKind::Dot) && marker.span.end == p.peek().span.start {
        written = marker.span.to(p.bump().span);
        true
    } else {
        false
    };
    let expr = exprs::parse_expr(p, child(depth))?;
    if invalid {
        p.report(
            DiagBuilder::new(DiagCode::E0227)
                .arg("written", p.snippet(written))
                .arg("name", p.snippet(expr.span()))
                .primary(written)
                .help_edits(
                    "spread",
                    vec![Edit {
                        span: written,
                        replacement: "..".to_owned(),
                    }],
                )
                .build(),
        );
    }
    out.push(ListElem::Spread(SpreadElem {
        id: p.node_id(),
        span: p.span_from(start),
        expr: *expr,
    }));
    Ok(())
}
pub(super) fn check_list_spreads(p: &mut Parser, list: &ListExpr) {
    let mut first = None;
    for elem in &list.elems {
        if let ListElem::Spread(spread) = elem {
            if let Some(first) = first {
                // リストを読み終わってから検査するため、個々の展開の独立した違反を報告する。
                // （設計書 02-03「誤りからの回復」、01-02「リストの展開」）。
                p.suppressed = false;
                p.report(
                    DiagBuilder::new(DiagCode::E0226)
                        .primary(spread.span)
                        .secondary(first, "first")
                        .help("concat")
                        .build(),
                );
            } else {
                first = Some(spread.span);
            }
        }
    }
}

#[cfg(test)]
// 公開の parse で展開の位置と診断・置き換えを確かめる。仮の本体は式を捨てるため、
// 展開の値や複数展開の診断の契約を守れない（設計書 07-03、test-audit）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::super::test_support::{assert_recovers, codes, parse_source, position};
    use super::*;
    use crate::{
        base::SourceKind,
        syntax::ast::{Expr, Item, Stmt},
    };
    #[test]
    fn spreads_preserve_elements_and_report_repair_locations() {
        for (text, expected, spread_index) in [
            ("[a, ..xs, b]", None, 1),
            ("[..xs, ..ys]", Some(DiagCode::E0226), 0),
            ("[...xs]", Some(DiagCode::E0227), 0),
            ("[*xs]", Some(DiagCode::E0227), 0),
            ("[x, ..]", Some(DiagCode::E0201), 0),
        ] {
            let src = format!("function f() -> Unit\n{text}\nend function");
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty());
            assert_eq!(codes(&out), expected.into_iter().collect::<Vec<_>>());
            let Item::Fn(f) = &out.module.decls[0].item else {
                panic!()
            };
            let Stmt::Expr(Expr::List(l)) = &f.body.as_ref().unwrap().stmts[0] else {
                panic!()
            };
            if expected != Some(DiagCode::E0201) {
                let ListElem::Spread(s) = &l.elems[spread_index] else {
                    panic!()
                };
                assert!(matches!(&s.expr, Expr::Name(n) if n.path[0].text == "xs"));
                assert_eq!(s.span.end, s.expr.span().end);
                let marker = if text.contains('*') { "*" } else { ".." };
                assert_eq!(s.span.start, position(&src, marker).unwrap());
            }
            if expected == Some(DiagCode::E0226) {
                let d = &out.diagnostics[0];
                assert_eq!(
                    d.primary.as_ref().unwrap().span.start,
                    position(&src, "..ys").unwrap()
                );
                assert_eq!(d.secondary[0].span.start, position(&src, "..xs").unwrap());
                assert!(d.helps[0].message.contains("List.concatenate"));
            }
            if expected == Some(DiagCode::E0227) {
                let edit = &out.diagnostics[0].helps[0].edits[0];
                assert_eq!(edit.span, out.diagnostics[0].primary.as_ref().unwrap().span);
                assert_eq!(edit.replacement, "..");
                let mut fixed = src.clone();
                fixed.replace_range(
                    edit.span.start.0 as usize..edit.span.end.0 as usize,
                    &edit.replacement,
                );
                assert!(fixed.contains("[..xs]"));
                assert!(
                    parse_source(&fixed, SourceKind::User)
                        .0
                        .diagnostics
                        .is_empty()
                );
            }
            if expected == Some(DiagCode::E0201) {
                assert_eq!(
                    out.diagnostics[0].primary.as_ref().unwrap().span.start,
                    position(&src, "]").unwrap()
                );
            }
        }
        assert_recovers(
            "function before() -> Unit\n[..xs, ..ys, ..zs]\nend function",
            &[DiagCode::E0226; 2],
        );
    }
}
