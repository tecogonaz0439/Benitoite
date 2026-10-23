//! 文字列補間の解析と由来位置（設計書 01-02「文字列補間（初回リリース版）」、02-02「合成ノードの由来位置」）。
use super::{Fail, PResult, Parser, exprs, nth_child, text};
use crate::base::{BytePos, Span};
use crate::syntax::{
    ast::{Expr, FormatSpec, InterpExpr, InterpSegment},
    lexer::InterpolationId,
    token::{TokenKind, TokenValue},
};

// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
pub(super) fn parse_interp(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let token = p.bump();
    let head = string_value(token.value);
    let mut opening = token.span;
    let mut segments = Vec::new();
    loop {
        let owner = InterpolationId {
            file: p.file,
            start: BytePos(opening.end.0.saturating_sub(2)),
        };
        let saved = p.interpolation.replace(owner);
        let parsed = exprs::parse_expr(p, nth_child(depth, segments.len()));
        p.interpolation = saved;
        let expr = match parsed {
            Ok(expr) => expr,
            Err(_) if p.aborted => return Err(Fail),
            Err(_) => {
                skip_to_end(p);
                return Ok(Box::new(Expr::Error(p.error_node_from(start))));
            }
        };
        let format = if p.at(TokenKind::Colon) {
            super::format::parse_format(p, owner)
        } else {
            None
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
        push_segment(
            &mut segments,
            span,
            *expr,
            format,
            string_value(closing.value),
        );
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
#[inline(never)]
fn push_segment(
    out: &mut Vec<InterpSegment>,
    span: Span,
    expr: Expr,
    format: Option<Box<FormatSpec>>,
    tail: String,
) {
    out.push(InterpSegment {
        span,
        expr,
        format,
        tail,
    });
}
// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
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
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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
    // 外側の旧構文の先読みは内側のコロンを飛ばし、本物の区切りは報告する。
    #[test]
    fn legacy_lookahead_skips_nested_strings_but_keeps_outer_colons() {
        for expr in ["when + \"${n:>3}\"", "when + \"${\"${n:>3}\"}\""] {
            let src = body(&format!("match k with case _ -> {expr} end match"));
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty());
            assert!(out.diagnostics.is_empty(), "{src}: {:?}", out.diagnostics);
        }
        for expr in [
            "match k with when 1: 2 end match",
            "match k with when x if \"${n}\" = \"\": x end match",
            "match k with when x if \"${n:>3}\" = \"\": x end match",
            "handle x with when E.op(x): x end handle",
        ] {
            let (out, _) = parse_source(&body(expr), SourceKind::User);
            assert!(codes(&out).contains(&DiagCode::E0232), "{expr}");
        }
        for expr in [
            "\"${match k with case _ -> when end match}${n}\"",
            "\"${match k with case _ -> when end match}${f(x: 1)}\"",
            "lambda() \"${end lambda}\" end lambda",
            "lambda() \"${n}\" + 1 end lambda",
        ] {
            let (out, lex) = parse_source(&body(expr), SourceKind::User);
            // 最初の二例は値の when を次の補間のコロンで旧構文にしない。
            // 後の例は内側の end lambda を外側の候補に使わない。
            if expr.contains("${end lambda}") {
                assert!(!codes(&out).contains(&DiagCode::E0214), "{expr}");
            } else {
                assert!(lex.is_empty());
                assert!(out.diagnostics.is_empty(), "{expr}: {:?}", out.diagnostics);
            }
        }
    }

    // 公開の三工程をつなぎ、所有者・元位置・未確定時の復帰を一つの境界で確かめる。
    // 式の再解析や診断コードの一括除外では、入れ子・中断後の保存が壊れる。
    #[test]
    fn pending_diagnostics_keep_owners_and_restore_without_format_confirmation() {
        use crate::base::{FileId, IdGen};
        use crate::syntax::{
            lexer::{PendingKind, lex},
            newline::resolve_newlines,
            parser::parse,
        };

        let src = body("\"あ${12abc}い${\"${1.2M}\" + 1f32}う${# ^}\"");
        let lexed = lex(FileId(7), src.as_bytes());
        assert!(lexed.diagnostics.is_empty());
        assert_eq!(lexed.pending.len(), 5);
        for (pending, (fragment, owner)) in lexed.pending.iter().zip([
            ("12abc", "${12abc}"),
            ("1.2M", "${1.2M}"),
            ("1f32", "${\"${1.2M}\""),
            ("#", "${# ^}"),
            ("^", "${# ^}"),
        ]) {
            assert_eq!(pending.interpolation.file, FileId(7));
            assert_eq!(
                pending.interpolation.start.0 as usize,
                src.find(owner).unwrap()
            );
            assert_eq!(slice(&src, pending.span), fragment);
        }
        let out = parse(
            FileId(7),
            SourceKind::User,
            src.as_bytes(),
            resolve_newlines(lexed.tokens),
            lexed.comments,
            lexed.pending,
            &mut IdGen::new(),
        );
        for (fragment, code) in [
            ("12abc", DiagCode::E0115),
            ("1.2M", DiagCode::E0124),
            ("1f32", DiagCode::E0127),
            ("#", DiagCode::E0105),
            ("^", DiagCode::E0105),
        ] {
            assert_eq!(
                out.diagnostics
                    .iter()
                    .filter(|d| d.code == Some(code)
                        && d.primary
                            .as_ref()
                            .is_some_and(|label| slice(&src, label.span) == fragment))
                    .count(),
                1
            );
        }

        for expr in ["\"${f(:8.2f}\"", "\"${12abc}\\q\""] {
            let src = body(expr);
            let lexed = lex(FileId(0), src.as_bytes());
            if expr.contains("\\q") {
                assert_eq!(
                    lexed
                        .diagnostics
                        .iter()
                        .filter_map(|d| d.code)
                        .collect::<Vec<_>>(),
                    [DiagCode::E0110]
                );
            }
            assert!(
                lexed
                    .pending
                    .iter()
                    .any(|pending| matches!(pending.kind, PendingKind::Number(_)))
            );
            let out = parse(
                FileId(0),
                SourceKind::User,
                src.as_bytes(),
                resolve_newlines(lexed.tokens),
                lexed.comments,
                lexed.pending,
                &mut IdGen::new(),
            );
            assert!(
                out.diagnostics
                    .iter()
                    .any(|d| matches!(d.code, Some(DiagCode::E0115 | DiagCode::E0116))),
                "{src}"
            );
        }
        for (source, code) in [
            (b"\"${8.2f \xff}\"".as_slice(), DiagCode::E0102),
            (b"\"${8.2f \xe2\x80\xae}\"".as_slice(), DiagCode::E0104),
            (b"\"${8.2f \xe3\x80\x80}\"".as_slice(), DiagCode::E0103),
            (b"\"${8.2f \r}\"".as_slice(), DiagCode::E0107),
            (b"\"${8.2f //}\"".as_slice(), DiagCode::E0120),
            (b"\"${8.2f\n}\"".as_slice(), DiagCode::E0119),
        ] {
            let lexed = lex(FileId(0), source);
            assert!(
                lexed.diagnostics.iter().any(|d| d.code == Some(code)),
                "{code:?}"
            );
            assert!(
                lexed
                    .pending
                    .iter()
                    .any(|p| matches!(p.kind, PendingKind::Number(_)))
            );
            assert!(lexed.pending.iter().all(|p| match &p.kind {
                PendingKind::Number(d) => d.code == Some(DiagCode::E0116),
                PendingKind::BadSymbol => true,
            }));
        }
        let src = body(&format!("\"{}\"", "${8.2f}".repeat(1001)));
        let (out, immediate) = parse_source(&src, SourceKind::User);
        assert!(immediate.is_empty());
        assert_eq!(
            codes(&out)
                .iter()
                .filter(|code| **code == DiagCode::E0116)
                .count(),
            1001
        );
        assert_eq!(
            codes(&out)
                .iter()
                .filter(|code| **code == DiagCode::E0208)
                .count(),
            1
        );
        let src = body(&format!("\"{}${{#}}\"", "${x}".repeat(1001)));
        let (out, immediate) = parse_source(&src, SourceKind::User);
        assert!(immediate.is_empty());
        assert_eq!(codes(&out), [DiagCode::E0208, DiagCode::E0105]);
    }

    #[test]
    fn formatted_interpolation_preserves_expression_boundaries_and_source_spans() {
        use crate::syntax::ast::{FormatAlign, FormatKind, FormatSign};
        for expr in [
            "x",
            "f(value: x)",
            "Person(name: x)",
            "match x with case Person(name: n) -> n end match",
            "block bind y: Integer <- x end block",
            "lambda(y) y",
            "lambda(y) -> Integer y",
            "lambda(y) y end lambda",
            "lambda() bind y: Integer <- x end lambda",
            "\"内${n:#08x}\"",
        ] {
            let src = body(&format!("\"あ${{{expr} :>65535}}い${{z:+08.28f}}う\""));
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty(), "{src}: {lex:?}");
            assert!(out.diagnostics.is_empty(), "{src}: {:?}", out.diagnostics);
            let Item::Fn(f) = &out.module.decls[0].item else {
                panic!()
            };
            let Stmt::Expr(Expr::Interp(i)) = &f.body.as_ref().unwrap().stmts[0] else {
                panic!()
            };
            assert_eq!(slice(&src, i.segments[0].expr.span()), expr);
            let first = i.segments[0].format.as_ref().unwrap();
            assert_eq!(first.align, FormatAlign::Right);
            assert_eq!(first.width, Some(65535));
            assert_eq!(first.precision, None);
            assert_eq!(slice(&src, first.span), ":>65535");
            assert_eq!(slice(&src, first.spans.align.unwrap()), ">");
            assert_eq!(slice(&src, first.spans.width.unwrap()), "65535");
            let second = i.segments[1].format.as_ref().unwrap();
            assert_eq!(second.kind, FormatKind::F);
            assert_eq!(second.sign, FormatSign::Plus);
            assert!(second.zero);
            assert_eq!(second.width, Some(8));
            assert_eq!(second.precision, Some(28));
            assert_eq!(slice(&src, second.spans.precision.unwrap()), ".28");
            assert_eq!(i.segments[0].tail, "い");
        }
        for spec in [
            "d", "b", "o", "x", "X", "f", "s", "c", "1", "^8", "<8", "+", "#08x", ".0f", ".00028f",
        ] {
            let src = body(&format!("\"${{n:{spec}}}\""));
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty());
            assert!(out.diagnostics.is_empty(), "{spec}: {:?}", out.diagnostics);
        }
        for literal in ["r\"${n:>8}\"", "r\"\"\"\r\n  ${n:>8}\r\n  \"\"\""] {
            let (out, lex) = parse_source(&body(literal), SourceKind::User);
            assert!(lex.is_empty());
            assert!(
                out.diagnostics.is_empty(),
                "{literal}: {:?}",
                out.diagnostics
            );
            let Item::Fn(f) = &out.module.decls[0].item else {
                panic!()
            };
            assert!(matches!(
                &f.body.as_ref().unwrap().stmts[0],
                Stmt::Expr(Expr::Lit(_))
            ));
        }
        let src = body("\"\"\"\r\n  あ${n:#08x}\r\n  \"\"\"");
        let (out, lex) = parse_source(&src, SourceKind::User);
        assert!(lex.is_empty());
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let Item::Fn(f) = &out.module.decls[0].item else {
            panic!()
        };
        let Stmt::Expr(Expr::Interp(i)) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        assert_eq!(slice(&src, i.segments[0].span), "${n:#08x}");
        assert_eq!(
            slice(&src, i.segments[0].format.as_ref().unwrap().span),
            ":#08x"
        );
    }

    #[test]
    fn invalid_formats_report_the_part_and_keep_expression_diagnostics() {
        for (spec, part) in [
            ("", ":"),
            ("8.2q", "q"),
            (" .2f", " "),
            ("8 ", " "),
            ("\t8", "\t"),
            ("-8", "-"),
            ("<-8", "-"),
            (".2", ".2"),
            (".f", ""),
            (".29f", "29"),
            ("65536", "65536"),
            ("0008", "008"),
            ("0", "0"),
            (">", ">"),
            (">08.2f", "0"),
            ("#d", "#"),
            ("8q", "q"),
            ("end lambda", " "),
            ("8.2f+", "+"),
            ("\"é\"", "\""),
            ("\"　\"", "　"),
        ] {
            let src = body(&format!("\"あ${{n:{spec}}}い\""));
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty(), "{spec}: {lex:?}");
            assert_eq!(
                codes(&out),
                [DiagCode::E0262],
                "{spec}: {:?}",
                out.diagnostics
            );
            assert_eq!(
                slice(&src, out.diagnostics[0].primary.as_ref().unwrap().span),
                part,
                "{spec}"
            );
        }
        for (spec, part) in [
            ("9".repeat(10000), "9".repeat(10000)),
            (format!(".{}f", "9".repeat(10000)), "9".repeat(10000)),
        ] {
            let src = body(&format!("\"${{n:{spec}}}\""));
            let (out, _) = parse_source(&src, SourceKind::User);
            assert_eq!(codes(&out), [DiagCode::E0262]);
            assert_eq!(
                slice(&src, out.diagnostics[0].primary.as_ref().unwrap().span),
                part
            );
        }
        for (spec, replacement) in [
            ("", ""),
            (" .2f", ":.2f"),
            ("-8", ":8"),
            (".2", ":.2f"),
            (" 8 ", ":8"),
            ("\t .2f \t", ":.2f"),
        ] {
            let src = body(&format!("\"あ${{n:{spec}}}い\""));
            let (out, _) = parse_source(&src, SourceKind::User);
            let edit = &out.diagnostics[0].helps[0].edits[0];
            let mut fixed = src.clone();
            fixed.replace_range(
                edit.span.start.0 as usize..edit.span.end.0 as usize,
                &edit.replacement,
            );
            assert_eq!(fixed, body(&format!("\"あ${{n{replacement}}}い\"")));
            let (out, lex) = parse_source(&fixed, SourceKind::User);
            assert!(lex.is_empty());
            assert!(out.diagnostics.is_empty(), "{fixed}: {:?}", out.diagnostics);
        }
        for spec in ["end lambda", "-", "#.2", " #d "] {
            let (out, _) = parse_source(&body(&format!("\"${{n:{spec}}}\"")), SourceKind::User);
            assert_eq!(codes(&out), [DiagCode::E0262]);
            assert!(
                out.diagnostics[0].helps.iter().all(|h| h.edits.is_empty()),
                "{spec}"
            );
        }
        for expr in ["12abc", "1f32", "1.2M"] {
            let src = body(&format!("\"${{{expr}:#08x}}${{\"${{n:^8}}\":s}}\""));
            let (out, lex) = parse_source(&src, SourceKind::User);
            assert!(lex.is_empty());
            assert!(
                out.diagnostics.iter().any(|d| matches!(
                    d.code,
                    Some(DiagCode::E0115 | DiagCode::E0124 | DiagCode::E0127)
                )),
                "{expr}: {:?}",
                out.diagnostics
            );
            assert!(!codes(&out).contains(&DiagCode::E0105));
        }
        let (out, _) = parse_source(&body("\"${lambda() x:end lambda}\""), SourceKind::User);
        assert_eq!(codes(&out), [DiagCode::E0262]);
        let (out, _) = parse_source(
            &body("\"${lambda() bind x <- 1; x:end lambda}\""),
            SourceKind::User,
        );
        assert!(codes(&out).contains(&DiagCode::E0201));
        let (out, _) = parse_source(&body("\"${lambda():Integer x:>8}\""), SourceKind::User);
        assert!(codes(&out).contains(&DiagCode::E0234));
        let (out, _) = parse_source(&body("\"${f(:8.2f}\""), SourceKind::User);
        assert!(codes(&out).contains(&DiagCode::E0116));
        let (_, lex) = parse_source(&body("\"${n:８}\""), SourceKind::User);
        assert!(lex.iter().any(|d| d.code == Some(DiagCode::E0103)));
    }

    // 書式内の字句エラーを重ねて報告せず、元のバイト位置を保つ。
    #[test]
    fn malformed_format_bytes_keep_only_lexical_diagnostics() {
        use crate::base::{FileId, IdGen};
        use crate::syntax::{lexer::lex, newline::resolve_newlines, parser::parse};
        let mut failures = Vec::new();
        for (source, expected) in [
            (b"\"${x:\xff .2f}\"".as_slice(), DiagCode::E0102),
            (b"\"${x:\xff8q}\"".as_slice(), DiagCode::E0102),
            ("\"${x:８}\"".as_bytes(), DiagCode::E0103),
            ("\"${x:　8}\"".as_bytes(), DiagCode::E0103),
        ] {
            let source = [
                b"function f() -> Unit\n".as_slice(),
                source,
                b"\nend function",
            ]
            .concat();
            let source = source.as_slice();
            let lexed = lex(FileId(0), source);
            assert_eq!(
                lexed
                    .diagnostics
                    .iter()
                    .filter_map(|d| d.code)
                    .collect::<Vec<_>>(),
                [expected]
            );
            let out = parse(
                FileId(0),
                SourceKind::User,
                source,
                resolve_newlines(lexed.tokens),
                lexed.comments,
                lexed.pending,
                &mut IdGen::new(),
            );
            if !out.diagnostics.is_empty() {
                failures.push(format!("{source:?}: {:?}", out.diagnostics));
            }
        }
        assert!(failures.is_empty(), "{}", failures.join("\n"));
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
