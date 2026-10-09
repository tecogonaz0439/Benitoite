//! レコードの式とパターン（設計書 01-02「レコード」、02-03「入れ子の深さ」）。
use super::{
    CommaList, PResult, Parser, child, comma_list_tail, exprs, nth_child,
    patterns::{self, PatternCounter},
    text,
};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_record_expr(
    p: &mut Parser,
    path: Vec<Name>,
    start: Span,
    depth: u32,
) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    open_record(p)?;
    let base = parse_base(p, depth)?;
    let empty_update = base.is_some() && p.at(TokenKind::RParen);
    let spec = field_list(text::FIELD_ARG);
    let mut fields = Vec::new();
    let mut index = 0_usize;
    // 共通の末尾の処理を使い、並び全体を読む関数の枠を再帰中に重ねない（設計書 02-03「入れ子の深さ」）。
    while !p.eat(TokenKind::RParen) {
        if p.aborted {
            return Err(super::Fail);
        }
        let from = p.pos;
        let failed = push_field_arg(p, nth_child(depth, index), &mut fields).is_err();
        index = index.saturating_add(comma_list_tail(
            p,
            spec,
            from,
            failed,
            &mut fields,
            &mut |_, _| {},
        )?);
    }
    Ok(finish_expr(p, path, start, base, fields, empty_update))
}
fn open_record(p: &mut Parser) -> PResult<()> {
    p.expect(TokenKind::LParen).map(|_| ())
}
fn parse_base(p: &mut Parser, depth: u32) -> PResult<Option<Box<Expr>>> {
    if !p.eat(TokenKind::DotDot) {
        return Ok(None);
    }
    let base = exprs::parse_expr(p, child(depth))?;
    if !p.at(TokenKind::RParen) {
        p.expect(TokenKind::Comma)?;
    }
    Ok(Some(base))
}
fn field_name(p: &mut Parser) -> PResult<Name> {
    let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
    p.expect(TokenKind::Colon)?;
    Ok(name)
}
fn record_placeholder(p: &mut Parser) -> Box<Expr> {
    let from = p.pos;
    let span = p.bump().span;
    p.report(
        DiagBuilder::new(DiagCode::E0204)
            .primary(span)
            .help("record")
            .build(),
    );
    Box::new(Expr::Error(p.error_node_from(from)))
}

fn field_list(element: &'static str) -> CommaList {
    CommaList {
        close: TokenKind::RParen,
        element,
        separator: text::COMMA_OR_RPAREN,
        allow_empty: true,
        indexed: true,
    }
}
fn push_field_arg(p: &mut Parser, depth: u32, out: &mut Vec<FieldArg>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let name = field_name(p)?;
    let value = if p.at(TokenKind::Underscore) {
        record_placeholder(p)
    } else {
        exprs::parse_expr(p, child(depth))?
    };
    finish_field_arg(p, start, name, value, out);
    Ok(())
}
fn finish_field_arg(
    p: &mut Parser,
    start: usize,
    name: Name,
    value: Box<Expr>,
    out: &mut Vec<FieldArg>,
) {
    // 大きな Expr を持つノードは再帰から戻った後に別の枠で組み立てる（設計書 02-03「入れ子の深さ」）。
    out.push(FieldArg {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        value: *value,
    });
}
fn finish_expr(
    p: &mut Parser,
    path: Vec<Name>,
    start: Span,
    base: Option<Box<Expr>>,
    fields: Vec<FieldArg>,
    empty_update: bool,
) -> Box<Expr> {
    let span = start.to(p.span_from(p.pos.saturating_sub(1)));
    if empty_update && let Some(base) = &base {
        let value = p.snippet(exprs::span_of(base));
        p.report(
            DiagBuilder::new(DiagCode::E0224)
                .arg("value", &value)
                .primary(span)
                .help_edits(
                    "use_value",
                    vec![Edit {
                        span,
                        replacement: value,
                    }],
                )
                .build(),
        );
    }
    Box::new(Expr::Record(RecordExpr {
        id: p.node_id(),
        span,
        path,
        base,
        fields,
    }))
}
pub(super) fn parse_record_pattern(
    p: &mut Parser,
    path: Vec<Name>,
    start: Span,
    counter: &mut PatternCounter,
) -> PResult<Box<Pattern>> {
    let depth = counter.base.saturating_add(counter.count);
    p.enter(depth)?;
    open_record(p)?;
    let empty_pattern = p.at(TokenKind::DotDot)
        && (p.peek_nth_kind(1) == TokenKind::RParen
            || p.peek_nth_kind(1) == TokenKind::Comma && p.peek_nth_kind(2) == TokenKind::RParen);
    let mut rest = false;
    let spec = field_list(text::FIELD_PAT);
    let mut fields = Vec::new();
    let mut index = 0_usize;
    while !p.eat(TokenKind::RParen) {
        if p.aborted {
            return Err(super::Fail);
        }
        let from = p.pos;
        let failed =
            push_pattern_field(p, nth_child(depth, index), counter, &mut rest, &mut fields)
                .is_err();
        index = index.saturating_add(comma_list_tail(
            p,
            spec,
            from,
            failed,
            &mut fields,
            &mut |_, _| {},
        )?);
    }
    Ok(finish_pattern(p, path, start, fields, rest, empty_pattern))
}
fn push_pattern_field(
    p: &mut Parser,
    depth: u32,
    counter: &mut PatternCounter,
    rest: &mut bool,
    out: &mut Vec<FieldPat>,
) -> PResult<()> {
    p.enter(depth)?;
    if p.at(TokenKind::DotDot) {
        *rest = true;
        return parse_rest(p);
    }
    if *rest {
        return Err(p.unexpected(text::RPAREN));
    }
    push_field_pat(p, counter, out)
}
fn parse_rest(p: &mut Parser) -> PResult<()> {
    p.bump();
    if p.at(TokenKind::Comma) && p.peek_nth_kind(1) == TokenKind::RParen {
        p.bump();
    }
    if !p.at(TokenKind::RParen) {
        p.unexpected(text::RPAREN);
        // `..` の後はフィールドを受け付けない。一つの誤りとして外側の閉じまで回復する。
        while !matches!(p.peek_kind(), TokenKind::RParen | TokenKind::Eof) && !p.aborted {
            if matches!(p.peek_kind(), TokenKind::LParen | TokenKind::LBracket) {
                super::items::skip_delimited(p);
            } else {
                p.advance();
            }
        }
    }
    if p.aborted { Err(super::Fail) } else { Ok(()) }
}

fn push_field_pat(
    p: &mut Parser,
    counter: &mut PatternCounter,
    out: &mut Vec<FieldPat>,
) -> PResult<()> {
    let start = p.pos;
    let name = field_name(p)?;
    let result = patterns::parse_pattern(p, counter);
    finish_field_pat(p, start, name, result, out)
}
fn finish_field_pat(
    p: &mut Parser,
    start: usize,
    name: Name,
    result: PResult<Box<Pattern>>,
    out: &mut Vec<FieldPat>,
) -> PResult<()> {
    // Pattern を含む FieldPat の組み立ても再帰の枠から分ける。
    let pattern = result?;
    out.push(FieldPat {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        pattern: *pattern,
    });
    Ok(())
}
fn finish_pattern(
    p: &mut Parser,
    path: Vec<Name>,
    start: Span,
    fields: Vec<FieldPat>,
    rest: bool,
    empty_pattern: bool,
) -> Box<Pattern> {
    let span = start.to(p.span_from(p.pos.saturating_sub(1)));
    if empty_pattern {
        p.report(
            DiagBuilder::new(DiagCode::E0225)
                .primary(span)
                .help_edits(
                    "wildcard",
                    vec![Edit {
                        span,
                        replacement: "_".to_owned(),
                    }],
                )
                .build(),
        );
    }
    Box::new(Pattern::Record(RecordPat {
        id: p.node_id(),
        span,
        path,
        fields,
        rest,
    }))
}

#[cfg(test)]
// レコードの構築・更新・照合の AST と診断は公開の parse の契約である。二字句での読み分け、
// 修正案、回復、深さの上限を本物の字句解析から確かめる。仮の本体のテストを置き換え、
// 非公開の判定を呼ばない（test-audit の作成時の関門、設計書 07-03）。失敗は panic で表す（00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::SourceKind;
    use crate::syntax::parser::{
        ParseOutput,
        test_support::{assert_recovers, codes, parse_source, position},
    };
    fn user(src: &str) -> ParseOutput {
        let (out, lex) = parse_source(src, SourceKind::User);
        assert!(lex.is_empty(), "{src}: {lex:?}");
        out
    }
    fn body(out: &ParseOutput) -> &Block {
        let Item::Fn(f) = &out.module.decls[0].item else {
            panic!()
        };
        f.body.as_ref().unwrap()
    }
    fn expression(out: &ParseOutput) -> &Expr {
        let Stmt::Expr(e) = &body(out).stmts[0] else {
            panic!()
        };
        e
    }
    fn function(expr: &str) -> String {
        format!("function f() -> Unit\n{expr}\nend function")
    }

    #[test]
    fn record_construction_update_and_patterns_preserve_fields() {
        let src = "record Person\nname: String\nage: Integer\nend record\nfunction birthday(p: Person) -> Person\nreturn Person(..p, age: Person.age(p) + 1)\nend function\nfunction greeting(p: Person) -> String\nreturn match p with\ncase Person(name: n, age: 0) -> \"Welcome\"\ncase Person(name: n, ..) -> \"Hello\"\nend match\nend function";
        let out = user(src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let Item::Fn(f) = &out.module.decls[1].item else {
            panic!()
        };
        let Stmt::Expr(Expr::Return(ret)) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        let Expr::Record(r) = ret.value.as_ref() else {
            panic!()
        };
        assert!(matches!(r.base.as_deref(), Some(Expr::Name(n)) if n.path[0].text == "p"));
        assert_eq!(r.fields[0].name.text, "age");
        assert!(matches!(r.fields[0].value, Expr::Binary(_)));
        let Item::Fn(f) = &out.module.decls[2].item else {
            panic!()
        };
        let Stmt::Expr(Expr::Return(ret)) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        let Expr::Match(m) = ret.value.as_ref() else {
            panic!()
        };
        let Pattern::Record(p) = &m.arms[0].patterns[0] else {
            panic!()
        };
        assert!(!p.rest);
        assert_eq!(p.fields.len(), 2);
        assert!(matches!(&p.fields[0].pattern, Pattern::Var(v) if v.name.text == "n"));
        assert!(
            matches!(&m.arms[1].patterns[0], Pattern::Record(p) if p.rest && p.fields.len() == 1)
        );
        let out = user(&function("Geo.Point(y: 2, x: f(1),)"));
        assert!(out.diagnostics.is_empty());
        let Expr::Record(r) = expression(&out) else {
            panic!()
        };
        assert_eq!(
            r.path.iter().map(|n| n.text.as_str()).collect::<Vec<_>>(),
            ["Geo", "Point"]
        );
        assert!(r.base.is_none());
        assert_eq!(
            r.fields
                .iter()
                .map(|f| f.name.text.as_str())
                .collect::<Vec<_>>(),
            ["y", "x"]
        );
        assert!(matches!(r.fields[1].value, Expr::Call(_)));
    }

    #[test]
    fn empty_updates_patterns_and_placeholders_report_exact_repairs() {
        for (expression, code, replacement) in [
            ("Person(..p)", DiagCode::E0224, "p"),
            (
                "match p with\ncase Person(..) -> ()\nend match",
                DiagCode::E0225,
                "_",
            ),
            ("Person(name: _)", DiagCode::E0204, ""),
            ("Person(.., name: n)", DiagCode::E0201, ""),
            (
                "match p with\ncase Person(name: n, .., age: _) -> ()\nend match",
                DiagCode::E0201,
                "",
            ),
        ] {
            let src = function(expression);
            assert_recovers(&src, &[code]);
            let out = user(&src);
            let d = &out.diagnostics[0];
            if !replacement.is_empty() {
                let edit = &d.helps[0].edits[0];
                assert_eq!(edit.replacement, replacement);
                assert_eq!(edit.span.start, position(&src, "Person(").unwrap());
                let end = src.find("Person(").unwrap()
                    + src[src.find("Person(").unwrap()..].find(')').unwrap()
                    + 1;
                assert_eq!(edit.span.end.0, u32::try_from(end).unwrap());
            }
            if code == DiagCode::E0204 {
                assert_eq!(
                    d.primary.as_ref().unwrap().span.start,
                    position(&src, "_").unwrap()
                );
                assert!(d.helps[0].message.contains("record construction"));
            }
        }
        // `p` が式でも修正案はソースの断片を保つ。
        let out = user(&function("Person(..choose(p))"));
        assert_eq!(codes(&out), [DiagCode::E0224]);
        assert_eq!(
            out.diagnostics[0].helps[0].edits[0].replacement,
            "choose(p)"
        );
        assert_recovers(&function("Person(..p, broken)"), &[DiagCode::E0201]);
    }

    #[test]
    fn constructor_calls_and_patterns_are_distinct_from_records() {
        for src in ["Shape.Circle(1.0)", "Pair(a, b)"] {
            let out = user(&function(src));
            assert!(out.diagnostics.is_empty());
            assert!(matches!(expression(&out), Expr::Call(_)));
        }
        for (pat, record) in [
            ("Shape.Circle(r)", false),
            ("Pair(a, b)", false),
            ("Geo.Point(x: x, y: y, ..,)", true),
        ] {
            let out = user(&function(&format!(
                "match v with\ncase {pat} -> ()\nend match"
            )));
            assert!(out.diagnostics.is_empty(), "{pat}: {:?}", out.diagnostics);
            let Expr::Match(m) = expression(&out) else {
                panic!()
            };
            assert_eq!(matches!(m.arms[0].patterns[0], Pattern::Record(_)), record);
            if !record {
                assert!(matches!(m.arms[0].patterns[0], Pattern::Ctor(_)));
            }
        }
    }

    #[test]
    fn records_obey_sequence_and_recursive_depth_limits() {
        // `RecordExpr` の深さは 3、フィールドの値は並びの位置にもう 1 を加える。
        for (count, valid) in [(996, true), (997, false)] {
            let fields = (0..count)
                .map(|i| format!("f{i}: 0"))
                .collect::<Vec<_>>()
                .join(",");
            let out = user(&function(&format!("R({fields})")));
            assert_eq!(
                codes(&out),
                if valid { vec![] } else { vec![DiagCode::E0208] }
            );
        }
        for (count, valid) in [(996, true), (997, false)] {
            let fields = (0..count)
                .map(|i| format!("f{i}: _"))
                .collect::<Vec<_>>()
                .join(",");
            let out = user(&function(&format!(
                "match v with\ncase R({fields}) -> ()\nend match"
            )));
            assert_eq!(
                codes(&out),
                if valid { vec![] } else { vec![DiagCode::E0208] }
            );
        }
        // 更新元の再帰は 1 段、フィールドを経る再帰は 2 段ずつ増える。
        // 上限内の更新元で起きたスタックの溢れと、上限を超えたときの打ち切りを守る。
        for (prefix, suffix, leaf, within, beyond) in [
            ("R(..", ", f: 0)", "x", 996, 997),
            ("R(f: ", ")", "0", 498, 499),
        ] {
            for (count, valid) in [(within, true), (beyond, false)] {
                let nested = format!("{}{leaf}{}", prefix.repeat(count), suffix.repeat(count));
                let out = user(&function(&nested));
                assert_eq!(
                    codes(&out),
                    if valid { vec![] } else { vec![DiagCode::E0208] }
                );
            }
        }
        for (count, valid) in [(996, true), (997, false)] {
            let nested = format!("{}_{}", "R(f: ".repeat(count), ")".repeat(count));
            let out = user(&function(&format!(
                "match v with\ncase {nested} -> ()\nend match"
            )));
            assert_eq!(
                codes(&out),
                if valid { vec![] } else { vec![DiagCode::E0208] }
            );
        }
    }
}
