//! 選択肢・ガード・範囲・リストのパターンと組の診断（設計書 01-02、01-05、02-03）。
use super::{
    CommaList, EscapeContext, Fail, PResult, Parser, child, comma_list, exprs, literal_of,
    patterns::{self, PatternCounter},
    text,
};
use crate::base::{BytePos, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_arm_head_rest(
    p: &mut Parser,
    first: Pattern,
    counter: &mut PatternCounter,
    depth: u32,
) -> PResult<(Vec<Pattern>, Option<Box<Expr>>)> {
    let mut alternatives = vec![first];
    while p.at(TokenKind::Comma) || p.symbol("|") {
        let invalid = p.symbol("|");
        let marker_pos = p.pos;
        let marker = p.peek().span;
        // 右のパターンの断片を得るまで、記号の汎用診断を出さない（02-03）。
        if invalid {
            p.reported_symbols.insert(marker_pos);
        }
        p.bump();
        let next = patterns::parse_pattern(p, counter)?;
        if invalid {
            let prev = alternatives.last().map_or(marker, Pattern::span);
            p.suppressed = false;
            p.report(
                DiagBuilder::new(DiagCode::E0236)
                    .arg("first", p.snippet(prev))
                    .arg("second", p.snippet(next.span()))
                    .primary(marker)
                    .help_edits(
                        "comma",
                        vec![Edit {
                            span: marker,
                            replacement: ",".to_owned(),
                        }],
                    )
                    .build(),
            );
        }
        alternatives.push(*next);
    }
    let invalid = p.word("when") || p.word("where");
    let guard = if p.at(TokenKind::KwIf) || invalid {
        let keyword = p.bump().span;
        let saved = p.ctx;
        p.ctx.escape = EscapeContext::InGuard;
        // 分岐の頭にある if はガード。式の if は括弧内でだけ受け付ける（01-02）。
        p.ctx.in_arm_head = true;
        let guard = parse_guard(p, child(depth));
        p.ctx = saved;
        let guard = guard?;
        if invalid {
            p.report(
                DiagBuilder::new(DiagCode::E0241)
                    .arg(
                        "pattern",
                        alternatives
                            .first()
                            .zip(alternatives.last())
                            .map_or_else(String::new, |(a, b)| p.snippet(a.span().to(b.span()))),
                    )
                    .arg("condition", p.snippet(guard.span()))
                    .primary(keyword)
                    .help_edits(
                        "if",
                        vec![Edit {
                            span: keyword,
                            replacement: "if".to_owned(),
                        }],
                    )
                    .build(),
            );
        }
        Some(guard)
    } else {
        None
    };
    Ok((alternatives, guard))
}
fn parse_guard(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    if !p.at(TokenKind::KwIf) {
        return exprs::parse_expr(p, depth);
    }
    // 括弧のない if は誤りだが、対応する end if まで読んで分岐の矢印へ戻る。
    // ガードの if をブロックの開始に数えた回復では、外側の end まで捨ててしまう（02-03）。
    let start = p.pos;
    p.unexpected(text::EXPRESSION);
    let saved = p.ctx.in_arm_head;
    p.ctx.in_arm_head = false;
    let result = exprs::parse_expr(p, depth);
    p.ctx.in_arm_head = saved;
    drop(result?);
    Ok(Box::new(Expr::Error(p.error_node_from(start))))
}

pub(super) fn parse_range_rest(
    p: &mut Parser,
    first: Pattern,
    _counter: &mut PatternCounter,
) -> PResult<Box<Pattern>> {
    let Pattern::Lit(first) = first else {
        return Err(Fail);
    };
    let marker = p.expect(TokenKind::DotDot)?.span;
    let invalid = marker.end == p.peek().span.start
        && matches!(
            p.peek_kind(),
            TokenKind::Eq | TokenKind::Lt | TokenKind::Dot | TokenKind::LeftArrow
        );
    let mut extra = if invalid { Some(p.bump()) } else { None };
    // '..<-1' の '<-' は字句の最長一致で一つになる。範囲の文脈では '<' と
    // 上端の負号に分ける（設計書 01-01「演算子と区切り記号」、02-03「他の言語の書き方への診断」）。
    let negative = if let Some(token) = &mut extra
        && token.kind == TokenKind::LeftArrow
    {
        token.kind = TokenKind::Lt;
        token.span.end = BytePos(token.span.end.0.saturating_sub(1));
        Some(Span {
            start: token.span.end,
            end: BytePos(token.span.end.0.saturating_add(1)),
            ..token.span
        })
    } else {
        None
    };
    let hi = parse_range_end(p, negative)?;
    let lo = RangeEnd {
        span: first.span,
        negative: first.negative,
        lit: first.lit,
    };
    if let Some(extra) = extra {
        let exclusive = extra.kind == TokenKind::Lt;
        let high = if exclusive {
            preceding(&hi)
        } else {
            Some(p.snippet(hi.span))
        };
        let mut d = DiagBuilder::new(DiagCode::E0242)
            .arg("low", p.snippet(lo.span))
            .arg("high", high.as_deref().unwrap_or(&p.snippet(hi.span)))
            .primary(marker.to(extra.span));
        if let Some(high) = high {
            let edit = if exclusive {
                Edit {
                    span: marker.to(hi.span),
                    replacement: format!("..{high}"),
                }
            } else {
                Edit {
                    span: extra.span,
                    replacement: String::new(),
                }
            };
            d = d.help_edits("range", vec![edit]);
        } else {
            d = d.help("range");
        }
        p.report(d.build());
    }
    let span = lo.span.to(hi.span);
    Ok(Box::new(Pattern::Range(RangePat {
        id: first.id,
        span,
        lo,
        hi,
    })))
}
fn parse_range_end(p: &mut Parser, prefix: Option<Span>) -> PResult<RangeEnd> {
    let start = p.pos;
    let negative = prefix.is_some() || p.eat(TokenKind::Minus);
    if !(p.at(TokenKind::IntLit) || !negative && p.at(TokenKind::CharLit)) {
        return Err(p.unexpected(text::RANGE));
    }
    let lit = literal_of(&p.bump()).ok_or(Fail)?;
    let span = prefix.map_or_else(
        || p.span_from(start),
        |prefix| prefix.to(p.span_from(start)),
    );
    Ok(RangeEnd {
        span,
        negative,
        lit,
    })
}
fn preceding(end: &RangeEnd) -> Option<String> {
    match &end.lit {
        Literal::Int { radix, digits } => {
            let magnitude = i128::from_str_radix(&digits.replace('_', ""), *radix).ok()?;
            let value = if end.negative {
                magnitude.checked_neg()?
            } else {
                magnitude
            };
            let value = i64::try_from(value).ok()?.checked_sub(1)?;
            Some(value.to_string())
        }
        Literal::Char(c) => {
            let mut scalar = u32::from(*c).checked_sub(1)?;
            // サロゲートはスカラー値でないので、境界では直前のスカラー値まで戻す。
            if scalar == 0xDFFF {
                scalar = 0xD7FF;
            }
            let c = char::from_u32(scalar)?;
            let escaped = match c {
                '\0' => "\\u{0}".to_owned(),
                '\n' => "\\n".to_owned(),
                '\r' => "\\r".to_owned(),
                '\t' => "\\t".to_owned(),
                '\\' => "\\\\".to_owned(),
                '\'' => "\\'".to_owned(),
                c if c.is_control() => format!("\\u{{{:x}}}", u32::from(c)),
                c => c.to_string(),
            };
            Some(format!("'{escaped}'"))
        }
        Literal::Float(_) | Literal::Decimal(_) | Literal::Str(_) | Literal::Bool(_) => None,
    }
}

enum ListPart {
    Pattern(Box<Pattern>),
    Rest(ListRest),
}
pub(super) fn parse_list_pattern(
    p: &mut Parser,
    counter: &mut PatternCounter,
) -> PResult<Box<Pattern>> {
    let start = p.pos;
    p.expect(TokenKind::LBracket)?;
    let parts = comma_list(
        p,
        counter.base,
        CommaList {
            close: TokenKind::RBracket,
            element: text::LIST_PATTERN,
            separator: text::COMMA_OR_RBRACKET,
            allow_empty: true,
            indexed: false,
        },
        |p, _, out| push_list_part(p, counter, out),
        |out, error| out.push(ListPart::Pattern(Box::new(Pattern::Error(error)))),
    )?;
    Ok(finish_list_pattern(p, start, parts))
}
fn push_list_part(
    p: &mut Parser,
    counter: &mut PatternCounter,
    out: &mut Vec<ListPart>,
) -> PResult<()> {
    if p.at(TokenKind::DotDot) {
        return push_list_rest(p, counter, out);
    }
    let pattern = patterns::parse_pattern(p, counter)?;
    out.push(ListPart::Pattern(pattern));
    Ok(())
}
fn push_list_rest(
    p: &mut Parser,
    counter: &mut PatternCounter,
    out: &mut Vec<ListPart>,
) -> PResult<()> {
    p.enter(counter.next_depth())?;
    let start = p.pos;
    p.bump();
    let name = if p.at(TokenKind::LowerIdent) {
        Some(p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?)
    } else {
        None
    };
    out.push(ListPart::Rest(ListRest {
        id: p.node_id(),
        span: p.span_from(start),
        name,
    }));
    Ok(())
}
fn finish_list_pattern(p: &mut Parser, start: usize, parts: Vec<ListPart>) -> Box<Pattern> {
    let mut before = Vec::new();
    let mut after = Vec::new();
    let mut rest: Option<ListRest> = None;
    for part in parts {
        match part {
            ListPart::Pattern(pattern) => {
                if rest.is_some() {
                    after.push(*pattern);
                } else {
                    before.push(*pattern);
                }
            }
            ListPart::Rest(next) => {
                if let Some(first) = &rest {
                    p.suppressed = false;
                    p.report(
                        DiagBuilder::new(DiagCode::E0250)
                            .primary(next.span)
                            .secondary(first.span, "first")
                            .build(),
                    );
                } else {
                    rest = Some(next);
                }
            }
        }
    }
    Box::new(Pattern::List(ListPat {
        id: p.node_id(),
        span: p.span_from(start),
        before,
        rest,
        after,
    }))
}
pub(super) fn report_tuple(p: &mut Parser, count: usize, span: Span) {
    let key = match count {
        2 => "pair",
        3 => "triple",
        _ => "record",
    };
    p.report(
        DiagBuilder::new(DiagCode::E0217)
            .primary(span)
            .help(key)
            .build(),
    );
}

#[cfg(test)]
// 公開の parse でパターンの区切り・文脈・修正後の意味を確かめる。仮の本体の回復テストを
// 置き換え、本番用の差し込み口は足さない（設計書 07-03、test-audit）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::super::{
        ParseOutput,
        test_support::{assert_recovers, codes, parse_source, position},
    };
    use super::*;
    use crate::base::SourceKind;
    fn source(head: &str) -> String {
        format!("function f() -> Unit\nmatch x with\ncase {head} -> ()\nend match\nend function")
    }
    fn user(src: &str) -> ParseOutput {
        let (out, lex) = parse_source(src, SourceKind::User);
        assert!(lex.is_empty(), "{src}: {lex:?}");
        out
    }
    fn arm(out: &ParseOutput) -> &MatchArm {
        let Item::Fn(f) = &out.module.decls[0].item else {
            panic!()
        };
        let Stmt::Expr(Expr::Match(m)) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        &m.arms[0]
    }
    fn fixed(src: &str, edits: &[Edit]) -> String {
        let mut result = src.to_owned();
        for e in edits.iter().rev() {
            result.replace_range(
                e.span.start.0 as usize..e.span.end.0 as usize,
                &e.replacement,
            );
        }
        result
    }
    #[test]
    fn alternatives_respect_constructor_parentheses_and_fix_foreign_separator() {
        for (head, expected) in [
            ("1, 2", None),
            ("Option.Some(1), Option.None", None),
            ("C(1, 2), D", None),
            ("1 | 2", Some(DiagCode::E0236)),
        ] {
            let src = source(head);
            let out = user(&src);
            assert_eq!(
                codes(&out),
                expected.into_iter().collect::<Vec<_>>(),
                "{:?}",
                out.diagnostics
            );
            assert_eq!(arm(&out).patterns.len(), 2);
            if head.starts_with("C(") {
                assert!(matches!(&arm(&out).patterns[0], Pattern::Ctor(c) if c.args.len() == 2));
            }
            if expected.is_some() {
                let d = &out.diagnostics[0];
                let edit = &d.helps[0].edits[0];
                assert_eq!(
                    d.primary.as_ref().unwrap().span.start,
                    position(&src, "|").unwrap()
                );
                assert_eq!(edit.span, d.primary.as_ref().unwrap().span);
                assert_eq!(edit.replacement, ",");
                assert_eq!(fixed(&src, &d.helps[0].edits), source("1 , 2"));
            }
        }
    }
    #[test]
    fn guard_context_requires_parenthesized_if_and_restores_escape() {
        for (head, expected) in [
            ("n if n > 0", None),
            ("n if (if a then true else false end if)", None),
            ("n if return 1", Some(DiagCode::E0218)),
            ("n if try f()", Some(DiagCode::E0218)),
            ("n when n > 0", Some(DiagCode::E0241)),
            ("n where n > 0", Some(DiagCode::E0241)),
        ] {
            let src = source(head);
            let out = user(&src);
            assert_eq!(
                codes(&out),
                expected.into_iter().collect::<Vec<_>>(),
                "{src}: {:?}",
                out.diagnostics
            );
            assert!(arm(&out).guard.is_some());
            if expected == Some(DiagCode::E0218) {
                assert!(
                    out.diagnostics[0].helps[0]
                        .message
                        .contains("a guard is a condition")
                );
                assert!(
                    out.diagnostics[0].helps[1]
                        .message
                        .contains("inside a lambda")
                );
            }
            if expected == Some(DiagCode::E0241) {
                let d = &out.diagnostics[0];
                let edit = &d.helps[0].edits[0];
                assert_eq!(edit.replacement, "if");
                assert_eq!(edit.span, d.primary.as_ref().unwrap().span);
                assert!(user(&fixed(&src, &d.helps[0].edits)).diagnostics.is_empty());
            }
        }
        let out = user(&source("n if if a then true else false end if"));
        assert_eq!(codes(&out), [DiagCode::E0201]);
        let src = "function f() -> Unit\nmatch x with\ncase n if (lambda() return true end lambda)() -> return 1\nend match\nreturn 2\nend function";
        assert!(user(src).diagnostics.is_empty());
        assert_recovers(
            "function before() -> Unit\nmatch x with\ncase n if ) -> ()\ncase _ -> return 1\nend match\nreturn 2\nend function",
            &[DiagCode::E0201],
        );
    }
    #[test]
    fn ranges_preserve_endpoints_and_offer_inclusive_replacements() {
        for (head, expected, replacement) in [
            ("1..9", None, ""),
            ("-5..-1", None, ""),
            ("'a'..'z'", None, ""),
            ("1..=9", Some(DiagCode::E0242), "1..9"),
            ("1..<10", Some(DiagCode::E0242), "1..9"),
            ("1...9", Some(DiagCode::E0242), "1..9"),
            ("'a'..<'z'", Some(DiagCode::E0242), "'a'..'y'"),
            ("-5..<-1", Some(DiagCode::E0242), "-5..-2"),
            ("0..<0xA", Some(DiagCode::E0242), "0..9"),
            (
                "'a'..<'\\u{e000}'",
                Some(DiagCode::E0242),
                "'a'..'\u{d7ff}'",
            ),
        ] {
            let src = source(head);
            let out = user(&src);
            assert_eq!(
                codes(&out),
                expected.into_iter().collect::<Vec<_>>(),
                "{src}: {:?}",
                out.diagnostics
            );
            let Pattern::Range(r) = &arm(&out).patterns[0] else {
                panic!()
            };
            assert_eq!(r.span, r.lo.span.to(r.hi.span));
            if head.starts_with('-') {
                assert!(r.lo.negative && r.hi.negative);
            }
            if expected.is_some() {
                let d = &out.diagnostics[0];
                assert_eq!(
                    d.primary.as_ref().unwrap().span.start,
                    position(&src, "..").unwrap()
                );
                let corrected = fixed(&src, &d.helps[0].edits);
                assert_eq!(corrected, source(replacement));
                assert!(user(&corrected).diagnostics.is_empty());
            }
        }
        for head in ["0..<-9223372036854775808", "'a'..<'\\u{0}'"] {
            let out = user(&source(head));
            assert_eq!(codes(&out), [DiagCode::E0242]);
            assert!(out.diagnostics[0].helps[0].edits.is_empty());
        }
    }
    #[test]
    fn list_pattern_rest_splits_before_and_after_and_reports_each_duplicate() {
        for (head, before, rest, after, expected) in [
            ("[]", 0, None, 0, None),
            ("[x, 0]", 2, None, 0, None),
            ("[first, ..rest]", 1, Some(Some("rest")), 0, None),
            ("[first, .., last]", 1, Some(None), 1, None),
            ("[..]", 0, Some(None), 0, None),
            (
                "[a, ..b, ..c]",
                1,
                Some(Some("b")),
                0,
                Some(DiagCode::E0250),
            ),
        ] {
            let src = source(head);
            let out = user(&src);
            assert_eq!(codes(&out), expected.into_iter().collect::<Vec<_>>());
            let Pattern::List(l) = &arm(&out).patterns[0] else {
                panic!()
            };
            assert_eq!(l.before.len(), before);
            assert_eq!(l.after.len(), after);
            assert_eq!(
                l.rest
                    .as_ref()
                    .map(|r| r.name.as_ref().map(|n| n.text.as_str())),
                rest
            );
            if expected.is_some() {
                assert_eq!(
                    out.diagnostics[0].primary.as_ref().unwrap().span.start,
                    position(&src, "..c").unwrap()
                );
                assert_eq!(
                    out.diagnostics[0].secondary[0].span.start,
                    position(&src, "..b").unwrap()
                );
            }
        }
        let out = user(&source("[..a, ..b, ..c]"));
        assert_eq!(codes(&out), [DiagCode::E0250; 2]);
        assert_recovers(&source("[a, ..b, ..c]"), &[DiagCode::E0250]);
    }
    #[test]
    fn tuple_diagnostics_choose_pair_triple_or_record_in_all_positions() {
        for (src, expected) in [
            ("function f() -> Unit\n(1, \"one\")\nend function", "Pair"),
            (
                "function f() -> Unit\nbind (a, b) <- p\nend function",
                "Pair",
            ),
            (
                "function f(x: (Integer, String, Boolean)) -> Unit\n()\nend function",
                "Triple",
            ),
            ("function f() -> Unit\n(1, 2, 3, 4)\nend function", "record"),
        ] {
            let out = user(src);
            assert_eq!(codes(&out), [DiagCode::E0217]);
            assert!(out.diagnostics[0].helps[0].message.contains(expected));
            assert_eq!(
                out.diagnostics[0].primary.as_ref().unwrap().span.start,
                position(src, ",").unwrap()
            );
        }
    }
    #[test]
    fn alternatives_and_nested_lists_count_pattern_nodes() {
        for (inside, outside) in [
            (
                source(&vec!["_"; 997].join(",")),
                source(&vec!["_"; 1001].join(",")),
            ),
            (
                source(&format!("{}x{}", "[".repeat(996), "]".repeat(996))),
                source(&format!("{}x{}", "[".repeat(1001), "]".repeat(1001))),
            ),
        ] {
            let out = user(&inside);
            assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
            let out = user(&outside);
            assert_eq!(codes(&out), [DiagCode::E0208]);
        }
    }
}
