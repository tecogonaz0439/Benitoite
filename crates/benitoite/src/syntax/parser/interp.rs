//! 文字列補間の解析と由来位置（設計書 01-02「文字列補間」、02-02「合成ノードの由来位置」）。
use super::{Fail, PResult, Parser, exprs, nth_child, text};
use crate::base::{BytePos, Span};
use crate::syntax::{
    ast::{Expr, InterpExpr, InterpSegment},
    token::{TokenKind, TokenValue},
};

pub(super) fn parse_interp(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let token = p.bump();
    let head = string_value(token.value);
    let mut opening = token.span;
    let mut segments = Vec::new();
    loop {
        let expr = match exprs::parse_expr(p, nth_child(depth, segments.len())) {
            Ok(expr) => expr,
            Err(_) if p.aborted => return Err(Fail),
            Err(_) => {
                skip_to_end(p);
                return Ok(Box::new(Expr::Error(p.error_node_from(start))));
            }
        };
        if !matches!(p.peek_kind(), TokenKind::StrMid | TokenKind::StrEnd) {
            p.unexpected(text::token_name(TokenKind::StrEnd));
            // 読んだ式の中の入れ子は閉じている。残る補間を対応する終わりまで捨てる。
            skip_to_end(p);
            return Ok(Box::new(Expr::Error(p.error_node_from(start))));
        }
        let closing = p.bump();
        let end = closing.kind == TokenKind::StrEnd;
        let span = Span {
            file: p.file,
            start: BytePos(opening.end.0.saturating_sub(2)),
            end: BytePos(closing.span.start.0.saturating_add(1)),
        };
        opening = closing.span;
        push_segment(&mut segments, span, expr, string_value(closing.value));
        if end {
            break;
        }
    }
    Ok(finish_interp(p, start, head, segments))
}
fn string_value(value: TokenValue) -> String {
    if let TokenValue::Str(value) = value {
        value
    } else {
        String::new()
    }
}
fn push_segment(out: &mut Vec<InterpSegment>, span: Span, expr: Box<Expr>, tail: String) {
    out.push(InterpSegment {
        span,
        expr: *expr,
        tail,
    });
}
fn finish_interp(
    p: &mut Parser,
    start: usize,
    head: String,
    segments: Vec<InterpSegment>,
) -> Box<Expr> {
    Box::new(Expr::Interp(InterpExpr {
        id: p.node_id(),
        span: p.span_from(start),
        head,
        segments,
    }))
}
fn skip_to_end(p: &mut Parser) {
    let mut nesting = 0_u32;
    while !p.at(TokenKind::Eof) {
        if p.at(TokenKind::StrStart) {
            nesting = nesting.saturating_add(1);
        }
        if p.at(TokenKind::StrEnd) {
            p.advance();
            if nesting == 0 {
                break;
            }
            nesting = nesting.saturating_sub(1);
        } else {
            p.advance();
        }
    }
}

#[cfg(test)]
// 補間ノードの断片と由来位置は後の段が使う契約である。公開の parse を通し、文字列の
// エスケープ後の値とソース上の span を別に確かめる（設計書 07-03、test-audit）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::super::test_support::{assert_recovers, codes, parse_source};
    use super::*;
    use crate::{
        base::SourceKind,
        diag::DiagCode,
        syntax::ast::{Item, Stmt},
    };
    fn body(expr: &str) -> String {
        format!("function f() -> Unit\n{expr}\nend function")
    }
    fn slice(src: &str, span: Span) -> &str {
        &src[span.start.0 as usize..span.end.0 as usize]
    }
    #[test]
    fn interpolation_parts_and_nested_spans_cover_dollar_to_brace() {
        for (text, head, tails, segments) in [
            (
                "\"a${x}b${f(y)}c\"",
                "a",
                vec!["b", "c"],
                vec!["${x}", "${f(y)}"],
            ),
            (
                "\"あ\\n${x}い${f(y)}う\"",
                "あ\n",
                vec!["い", "う"],
                vec!["${x}", "${f(y)}"],
            ),
            (
                "\"a${g(\"b${x}\")}\"",
                "a",
                vec![""],
                vec!["${g(\"b${x}\")}"],
            ),
        ] {
            let src = body(text);
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty());
            assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
            let Item::Fn(f) = &out.module.decls[0].item else {
                panic!()
            };
            let Stmt::Expr(Expr::Interp(i)) = &f.body.as_ref().unwrap().stmts[0] else {
                panic!()
            };
            assert_eq!(i.head, head);
            assert_eq!(slice(&src, i.span), text);
            assert_eq!(
                i.segments
                    .iter()
                    .map(|s| s.tail.as_str())
                    .collect::<Vec<_>>(),
                tails
            );
            assert_eq!(
                i.segments
                    .iter()
                    .map(|s| slice(&src, s.span))
                    .collect::<Vec<_>>(),
                segments
            );
            if i.segments.len() == 1 {
                let Expr::Call(c) = &i.segments[0].expr else {
                    panic!()
                };
                let crate::syntax::ast::Arg::Expr(Expr::Interp(inner)) = &c.args[0] else {
                    panic!()
                };
                assert_eq!(inner.head, "b");
                assert_eq!(slice(&src, inner.segments[0].span), "${x}");
            }
        }
        assert_recovers(&body("\"a${x y}\""), &[DiagCode::E0201]);
        assert_recovers(&body("\"a${)}\""), &[DiagCode::E0201]);
    }
    #[test]
    fn interpolation_sequence_and_nesting_limits_use_default_stack() {
        for (inside, outside) in [
            (
                format!("\"{}\"", "${x}".repeat(997)),
                format!("\"{}\"", "${x}".repeat(1001)),
            ),
            (
                format!("{}x{}", "\"${".repeat(997), "}\"".repeat(997)),
                format!("{}x{}", "\"${".repeat(1001), "}\"".repeat(1001)),
            ),
        ] {
            let (out, lex) = parse_source(&body(&inside), SourceKind::User);
            assert!(lex.is_empty());
            assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
            let (out, lex) = parse_source(&body(&outside), SourceKind::User);
            assert!(lex.is_empty());
            assert_eq!(codes(&out), [DiagCode::E0208]);
        }
    }
}
