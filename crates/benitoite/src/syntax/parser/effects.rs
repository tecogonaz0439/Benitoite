//! エフェクト・ハンドラと脱出の文脈の解析（設計書 01-02、02-03「文脈の制限」）。
use super::{
    ClauseContext, CommaList, EscapeContext, Fail, PResult, Parser, Recovery, child, comma_list,
    decls,
    exprs::{self, BlockEnd},
    foreign, items, nth_child, text,
};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_effect_decl(p: &mut Parser, depth: u32) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    p.open_block(TokenKind::KwEffect, opened);
    let mut ops = Vec::new();
    p.skip_newlines();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.symbol("}") && !p.aborted {
        let from = p.pos;
        if push_op(p, child(depth), &mut ops).is_err() {
            if p.aborted {
                return Err(Fail);
            }
            p.recover(from, Recovery::Line);
        }
        if p.pos == from {
            p.advance();
        }
        if !matches!(
            p.peek_kind(),
            TokenKind::Newline | TokenKind::KwEnd | TokenKind::Eof
        ) && !p.symbol("}")
        {
            p.unexpected(text::NEWLINE_OR_END);
            p.recover(p.pos, Recovery::Line);
        }
        p.skip_newlines();
    }
    p.close_block(TokenKind::KwEffect);
    Ok(Item::Effect(EffectDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        ops,
    }))
}
fn push_op(p: &mut Parser, depth: u32, out: &mut Vec<OpSig>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let doc = p.docs.take_for(p.peek().span, &mut p.diagnostics);
    let mut sig = decls::parse_signature(p, depth)?;
    // シグネチャの終わりまで読んでから、不許可の欄だけを捨てる（ADR 0311・0312）。
    // 独立した違反はそれぞれ報告する（設計書 02-03「文脈の制限」）。
    sig.type_params.retain(|param| {
        let key = match param.kind {
            TypeParamKind::Value => return true,
            TypeParamKind::Effect => "effect_var",
            TypeParamKind::Ctor { .. } => "type_ctor",
        };
        p.suppressed = false;
        p.report(
            DiagBuilder::new(DiagCode::E0510)
                .primary(param.span)
                .help(key)
                .build(),
        );
        false
    });
    for param in &mut sig.type_params {
        param.constraints.retain(|constraint| {
            let ConstraintRef::Class(class) = constraint else {
                return true;
            };
            p.suppressed = false;
            p.report(
                DiagBuilder::new(DiagCode::E0510)
                    .primary(class.span)
                    .help("trait_constraint")
                    .build(),
            );
            false
        });
    }
    if let Some(uses) = sig.uses {
        p.suppressed = false;
        p.report(
            DiagBuilder::new(DiagCode::E0510)
                .primary(uses.span)
                .help("uses")
                .build(),
        );
    }
    out.push(OpSig {
        id: p.node_id(),
        span: p.span_from(start),
        doc,
        name: sig.name,
        type_params: sig.type_params,
        params: sig.params,
        ret: sig.ret,
    });
    Ok(())
}

pub(super) fn parse_handle(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    p.open_block(TokenKind::KwHandle, opened);
    // 外側の節の継続は内側の handle の本体からも使える（実装プラン F04）。
    let body = exprs::parse_block(p, child(depth), BlockEnd::WithCase)?;
    p.expect(TokenKind::KwWith)?;
    let clauses = parse_clauses(p, depth)?;
    p.close_block(TokenKind::KwHandle);
    Ok(finish_handle(p, start, *body, clauses))
}
fn parse_clauses(p: &mut Parser, depth: u32) -> PResult<Vec<HandleClause>> {
    let mut clauses = Vec::new();
    let mut index = 0_usize;
    p.skip_newlines();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.symbol("}") && !p.aborted {
        if index > 0 && !p.at_line_start() {
            p.unexpected(text::NEWLINE_OR_END);
        }
        let from = p.pos;
        let saved = p.ctx;
        let open = p.blocks.len();
        let result = push_clause(p, nth_child(depth, index), &mut clauses);
        p.ctx = saved;
        if result.is_err() {
            if p.aborted {
                return Err(Fail);
            }
            p.recover(from, Recovery::Line);
            p.blocks.truncate(open);
        }
        if p.pos == from {
            p.advance();
        }
        index = index.saturating_add(1);
        p.skip_newlines();
    }
    if index == 0 {
        p.unexpected(text::HANDLE_CLAUSE);
    }
    Ok(clauses)
}
fn push_clause(p: &mut Parser, depth: u32, out: &mut Vec<HandleClause>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let when = foreign::take_when(p);
    if when.is_none() {
        p.expect(TokenKind::KwCase)?;
    }
    let from = p.pos;
    let path = p.qual_name(false)?;
    if path
        .last()
        .is_none_or(|n| !n.text.starts_with(char::is_lowercase) && !n.text.starts_with('_'))
    {
        return Err(p.unexpected(text::OPERATION));
    }
    let op = OpRef {
        id: p.node_id(),
        span: p.span_from(from),
        path,
    };
    p.expect(TokenKind::LParen)?;
    let params = comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RParen,
            element: text::PARAMETER,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: false,
        },
        push_clause_param,
        |_, _| {},
    )?;
    if let Some(span) = when {
        foreign::report_when(p, span, p.span_from(from));
        p.expect(TokenKind::Colon)?;
    } else if p.symbol("=>") {
        foreign::operator(p, "fat_arrow", None);
        p.bump();
    } else {
        p.expect(TokenKind::Arrow)?;
    }
    let saved = p.ctx;
    p.ctx.clause = ClauseContext::Direct;
    p.ctx.in_arm_head = false;
    p.skip_newlines();
    if matches!(
        p.peek_kind(),
        TokenKind::KwEnd | TokenKind::KwCase | TokenKind::Eof
    ) {
        p.unexpected(text::STATEMENT);
    }
    let body = exprs::parse_block(p, child(depth), BlockEnd::Arm);
    p.ctx = saved;
    let body = body?;
    finish_clause(p, start, op, params, *body, out);
    Ok(())
}
fn push_clause_param(p: &mut Parser, depth: u32, out: &mut Vec<ClauseParam>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let name = if p.eat(TokenKind::Underscore) {
        None
    } else {
        Some(p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?)
    };
    out.push(ClauseParam {
        id: p.node_id(),
        span: p.span_from(start),
        name,
    });
    Ok(())
}
fn finish_clause(
    p: &mut Parser,
    start: usize,
    op: OpRef,
    params: Vec<ClauseParam>,
    body: Block,
    out: &mut Vec<HandleClause>,
) {
    let span = p
        .tokens
        .get(start)
        .map_or(body.span, |t| t.span.to(body.span));
    out.push(HandleClause {
        id: p.node_id(),
        span,
        op,
        params,
        body,
    });
}
fn finish_handle(
    p: &mut Parser,
    start: usize,
    body: Block,
    clauses: Vec<HandleClause>,
) -> Box<Expr> {
    Box::new(Expr::Handle(HandleExpr {
        id: p.node_id(),
        span: p.span_from(start),
        body,
        clauses,
    }))
}

pub(super) fn parse_resume(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let span = p.bump().span;
    check_resume(p, span);
    p.expect(TokenKind::LParen)?;
    let value = exprs::parse_expr(p, child(depth))?;
    p.expect(TokenKind::RParen)?;
    Ok(finish_resume(p, start, value))
}
fn check_resume(p: &mut Parser, span: Span) {
    if p.ctx.clause == ClauseContext::Direct {
        return;
    }
    let mut d = DiagBuilder::new(DiagCode::E0509).primary(span);
    if p.ctx.clause == ClauseContext::Blocked {
        d = d.help("lambda");
    }
    p.report(d.build());
}
fn finish_resume(p: &mut Parser, start: usize, value: Box<Expr>) -> Box<Expr> {
    Box::new(Expr::Resume(ResumeExpr {
        id: p.node_id(),
        span: p.span_from(start),
        value,
    }))
}

pub(super) fn parse_with(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    if !p.at(TokenKind::LowerIdent) || p.peek_nth_kind(1) != TokenKind::Eq {
        p.report(
            DiagBuilder::new(DiagCode::E0246)
                .primary(opened)
                .help("handle")
                .build(),
        );
        skip_foreign_with(p);
        return Ok(Box::new(Expr::Error(p.error_node_from(start))));
    }
    let mut binds = Vec::new();
    loop {
        push_with_bind(p, nth_child(depth, binds.len()), &mut binds)?;
        if !p.eat(TokenKind::Comma) {
            break;
        }
    }
    p.expect(TokenKind::KwDo)?;
    p.open_block(TokenKind::KwWith, opened);
    let body = exprs::parse_block(p, child(depth), BlockEnd::End)?;
    p.close_block(TokenKind::KwWith);
    Ok(finish_with(p, start, binds, *body))
}
fn push_with_bind(p: &mut Parser, depth: u32, out: &mut Vec<WithBind>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
    p.expect(TokenKind::Eq)?;
    let value = exprs::parse_expr(p, child(depth))?;
    out.push(WithBind {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        value: *value,
    });
    Ok(())
}
fn finish_with(p: &mut Parser, start: usize, binds: Vec<WithBind>, body: Block) -> Box<Expr> {
    Box::new(Expr::With(WithExpr {
        id: p.node_id(),
        span: p.span_from(start),
        binds,
        body,
    }))
}
fn skip_foreign_with(p: &mut Parser) {
    // 対応する end with があるときだけ全体を捨て、外側の終わりを消費しない（F04）。
    let mut nesting = 0_u32;
    let mut end = None;
    for (offset, token) in p.tokens.get(p.pos..).unwrap_or_default().iter().enumerate() {
        let index = p.pos.saturating_add(offset);
        if token.kind == TokenKind::KwEnd
            && p.tokens
                .get(index.saturating_add(1))
                .is_some_and(|t| t.kind == TokenKind::KwWith)
        {
            if nesting == 0 {
                end = Some(index.saturating_add(2));
                break;
            }
            nesting = nesting.saturating_sub(1);
        } else if token.kind == TokenKind::KwWith
            && p.tokens
                .get(index.saturating_sub(1))
                .is_none_or(|previous| previous.kind != TokenKind::KwEnd)
        {
            // 閉じる印の後半の with は、入れ子を開始しない（設計書 02-03「誤りからの回復」）。
            nesting = nesting.saturating_add(1);
        } else if nesting == 0 && token.kind == TokenKind::KwEnd {
            break;
        }
    }
    if let Some(end) = end {
        while p.pos < end && !p.at(TokenKind::Eof) {
            p.advance();
        }
    } else {
        p.recover(p.pos, Recovery::Line);
    }
}

pub(super) fn parse_lazy(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    let saved = p.ctx;
    p.ctx.escape = EscapeContext::InLazy;
    p.ctx.in_arm_head = false;
    if p.ctx.clause == ClauseContext::Direct {
        p.ctx.clause = ClauseContext::Blocked;
    }
    p.open_block(TokenKind::KwLazy, opened);
    let body = exprs::parse_block(p, child(depth), BlockEnd::End);
    p.ctx = saved;
    let body = body?;
    p.close_block(TokenKind::KwLazy);
    Ok(finish_lazy(p, start, *body))
}
fn finish_lazy(p: &mut Parser, start: usize, body: Block) -> Box<Expr> {
    Box::new(Expr::Lazy(LazyExpr {
        id: p.node_id(),
        span: p.span_from(start),
        body,
    }))
}

pub(super) fn parse_try(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let span = p.bump().span;
    check_escape(p, TokenKind::KwTry, span);
    if p.symbol("{") {
        foreign::report_symbol(
            p,
            DiagBuilder::new(DiagCode::E0235)
                .primary(span)
                .help("result")
                .build(),
        );
        skip_braces(p);
        while p.word("catch") {
            p.advance();
            if p.at(TokenKind::LParen) {
                items::skip_delimited(p);
            }
            if p.symbol("{") {
                skip_braces(p);
            } else {
                break;
            }
        }
        return Ok(Box::new(Expr::Error(p.error_node_from(start))));
    }
    let value = exprs::parse_expr(p, child(depth))?;
    Ok(Box::new(Expr::Try(TryExpr {
        id: p.node_id(),
        span: p.span_from(start),
        value,
    })))
}
fn skip_braces(p: &mut Parser) {
    let mut nesting = 0_u32;
    while !p.at(TokenKind::Eof) {
        if p.symbol("{") {
            nesting = nesting.saturating_add(1);
            p.reported_symbols.insert(p.pos);
        }
        let close = p.symbol("}");
        if close {
            nesting = nesting.saturating_sub(1);
            p.reported_symbols.insert(p.pos);
        }
        p.advance();
        if close && nesting == 0 {
            break;
        }
    }
}
pub(super) fn check_escape(p: &mut Parser, keyword: TokenKind, span: Span) {
    let (context, key) = match p.ctx.escape {
        EscapeContext::Allowed => return,
        EscapeContext::InLazy => (text::LAZY_BODY, "lazy_body"),
        EscapeContext::InGuard => (text::GUARD, "guard"),
    };
    p.report(
        DiagBuilder::new(DiagCode::E0218)
            .arg("keyword", text::keyword(keyword).unwrap_or_default())
            .arg("context", context)
            .primary(span)
            .help(key)
            .help("lambda")
            .build(),
    );
}

#[cfg(test)]
// 公開の parse で文脈と回復を確かめる。文脈の漏れと式の範囲の退行は、仮の本体の
// テストでは捕まらない。準備は F02 の共通関数を使う（設計書 07-03、test-audit）。
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
    fn user(src: &str) -> ParseOutput {
        let (out, lex) = parse_source(src, SourceKind::User);
        assert!(lex.is_empty(), "{src}: {lex:?}");
        out
    }
    fn body(expr: &str) -> String {
        format!("function f() -> Unit\n{expr}\nend function")
    }
    fn expr(out: &ParseOutput) -> &Expr {
        let Item::Fn(f) = &out.module.decls[0].item else {
            panic!()
        };
        let Stmt::Expr(e) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        e
    }
    #[test]
    fn operation_type_parameters_reject_constructors_and_traits_but_keep_builtin_bounds() {
        for (sig, key, location) in [
            ("make[F[_]]() -> F[Integer]", "type_ctor", "F[_]"),
            (
                "show[T: Trait.Show](x: T) -> String",
                "trait_constraint",
                "Trait.Show",
            ),
        ] {
            let src = format!(
                "effect Make\n function {sig}\n function next[T: key](x: T) -> T\nend effect\nfunction after() -> Unit\n ()\nend function\n"
            );
            let out = user(&src);
            assert_eq!(codes(&out), [DiagCode::E0510], "{:#?}", out.diagnostics);
            let d = &out.diagnostics[0];
            assert_eq!(
                d.primary.as_ref().unwrap().span.start,
                position(&src, location).unwrap()
            );
            assert!(d.helps[0].message.contains(if key == "type_ctor" {
                "type constructor parameters"
            } else {
                "not a trait"
            }));
            let Item::Effect(e) = &out.module.decls[0].item else {
                panic!()
            };
            assert_eq!(e.ops.len(), 2);
            if key == "type_ctor" {
                assert!(e.ops[0].type_params.is_empty());
            } else {
                assert!(e.ops[0].type_params[0].constraints.is_empty());
            }
            assert!(matches!(
                e.ops[1].type_params[0].constraints[0],
                ConstraintRef::Builtin {
                    kind: crate::types::BuiltinConstraint::Key,
                    ..
                }
            ));
            assert!(matches!(&out.module.decls[1].item, Item::Fn(f) if f.name.text == "after"));
        }
        let out = user(
            "effect Compare\n function same[T: equality & Trait.Show](a: T, b: T) -> Boolean\nend effect\n",
        );
        assert_eq!(codes(&out), [DiagCode::E0510]);
        let Item::Effect(e) = &out.module.decls[0].item else {
            panic!()
        };
        assert!(matches!(
            e.ops[0].type_params[0].constraints.as_slice(),
            [ConstraintRef::Builtin {
                kind: crate::types::BuiltinConstraint::Equality,
                ..
            }]
        ));
    }
    #[test]
    fn log_example_and_operation_restrictions() {
        let spec = include_str!("../../../../../docs/design/01-spec/01-02-syntax.md");
        let section = spec.split_once("### エフェクトの宣言とハンドラ").unwrap().1;
        let src = section
            .split_once("```text\neffect Log")
            .unwrap()
            .1
            .split_once("```")
            .unwrap()
            .0;
        let src = format!("effect Log{src}");
        let out = user(&src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let Item::Effect(e) = &out.module.decls[0].item else {
            panic!()
        };
        assert_eq!(e.name.text, "Log");
        assert_eq!(e.ops[0].params[0].name.text, "message");
        let Item::Fn(f) = &out.module.decls[2].item else {
            panic!()
        };
        let Stmt::Expr(Expr::Return(r)) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        let Expr::Handle(h) = r.value.as_ref() else {
            panic!()
        };
        assert_eq!(h.clauses.len(), 1);
        assert_eq!(h.clauses[0].params.len(), 1);
        assert!(matches!(
            &h.clauses[0].body.stmts[1],
            Stmt::Expr(Expr::Resume(_))
        ));
        for (sig, key, location) in [
            (
                "write(m: String) -> Unit uses Console.Write",
                "uses",
                "uses",
            ),
            ("f[effect E, T]() -> Unit", "effect_var", "effect E,"),
        ] {
            let src = format!("effect E\n/// operation documentation\nfunction {sig}\nend effect");
            let out = user(&src);
            assert_eq!(codes(&out), [DiagCode::E0510]);
            assert!(out.diagnostics[0].helps[0].message.contains(match key {
                "uses" => "cannot have `uses`",
                "effect_var" => "cannot have effect variables",
                "lazy_body" => "a `lazy` body",
                _ => panic!(),
            }));
            assert_eq!(
                out.diagnostics[0].primary.as_ref().unwrap().span.start,
                position(&src, location).unwrap()
            );
            let Item::Effect(e) = &out.module.decls[0].item else {
                panic!()
            };
            assert!(e.ops[0].doc.is_some());
            assert!(
                e.ops[0]
                    .type_params
                    .iter()
                    .all(|p| p.kind != TypeParamKind::Effect)
            );
        }
        let out = user(
            "effect E\nfunction op[effect A, effect B]() -> Unit uses Console.Write\nend effect",
        );
        assert_eq!(codes(&out), [DiagCode::E0510; 3]);
    }
    #[test]
    fn resume_context_follows_nested_handlers_and_restores_on_exit() {
        for (inside, expected, blocked) in [
            ("resume(())", None, false),
            (
                "handle resume(()) with case op() -> resume(()) end handle",
                None,
                false,
            ),
            (
                "lambda() resume(()) end lambda",
                Some(DiagCode::E0509),
                true,
            ),
            ("lazy resume(()) end lazy", Some(DiagCode::E0509), true),
        ] {
            let src = body(&format!(
                "handle () with case Log.write(_) ->\n{inside}\nend handle"
            ));
            let out = user(&src);
            assert_eq!(
                codes(&out),
                expected.into_iter().collect::<Vec<_>>(),
                "{src}: {:?}",
                out.diagnostics
            );
            let Expr::Handle(h) = expr(&out) else {
                panic!()
            };
            assert_eq!(h.clauses[0].op.path.len(), 2);
            assert!(h.clauses[0].params[0].name.is_none());
            if blocked {
                assert!(
                    out.diagnostics[0].helps[0]
                        .message
                        .contains("lambda or a `lazy` body")
                );
                assert_eq!(
                    out.diagnostics[0].primary.as_ref().unwrap().span.start,
                    position(&src, "resume").unwrap()
                );
            }
        }
        for source in [
            "resume(())",
            "handle resume(()) with case op() -> resume(()) end handle",
        ] {
            let src = body(source);
            let out = user(&src);
            assert_eq!(codes(&out), [DiagCode::E0509]);
            assert!(out.diagnostics[0].helps.is_empty());
        }
        let src = body(
            "handle () with case op() ->\nlazy () end lazy\nresume(())\nend handle\nresume(())",
        );
        let out = user(&src);
        assert_eq!(codes(&out), [DiagCode::E0509]);
        assert_eq!(
            out.diagnostics[0].primary.as_ref().unwrap().span.start.0 as usize,
            src.rfind("resume").unwrap()
        );
        assert_recovers(
            "function before() -> Unit\nhandle () with case op() ->\nlazy bind x <- ) end lazy\nresume(())\nend handle\nend function",
            &[DiagCode::E0201],
        );
    }
    #[test]
    fn legacy_handler_clause_is_reported_without_secondary_errors() {
        let src = body("handle () with when write(m): resume(()) end handle");
        let out = user(&src);
        assert_eq!(codes(&out), [DiagCode::E0232], "{:?}", out.diagnostics);
        assert_eq!(
            out.diagnostics[0].primary.as_ref().unwrap().span.start,
            position(&src, "when").unwrap()
        );
        let Expr::Handle(h) = expr(&out) else {
            panic!()
        };
        assert_eq!(h.clauses[0].params[0].name.as_ref().unwrap().text, "m");
    }
    #[test]
    fn resource_bindings_do_not_end_the_handler_body() {
        let src = body(
            "handle\nwith a = try f() |> g(_, x), b = h() do\n()\nend with\nwith case op() -> resume(())\nend handle",
        );
        let out = user(&src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let Expr::Handle(h) = expr(&out) else {
            panic!()
        };
        let Stmt::Expr(Expr::With(w)) = &h.body.stmts[0] else {
            panic!()
        };
        assert_eq!(w.binds.len(), 2);
        assert_eq!(w.binds[0].name.text, "a");
        assert!(
            matches!(&w.binds[0].value, Expr::Try(t) if matches!(t.value.as_ref(), Expr::Pipe(_)))
        );
        let src = body("with handler do\n()\nend with");
        let out = user(&src);
        assert_eq!(codes(&out), [DiagCode::E0246]);
        assert!(
            out.diagnostics[0].helps[0]
                .message
                .contains("handle ... with case")
        );
        assert_recovers(&src, &[DiagCode::E0246]);
        assert_recovers(
            &body("with handler do\nwith resource = f() do\n()\nend with\nend with"),
            &[DiagCode::E0246],
        );
    }
    #[test]
    fn lazy_escape_and_try_operand_extent() {
        for (source, expected, key) in [
            ("lazy\ncompute()\nend lazy", None, ""),
            ("lazy return 1 end lazy", Some(DiagCode::E0218), "lazy_body"),
            ("lazy try f() end lazy", Some(DiagCode::E0218), "lazy_body"),
            ("lazy lambda() return 1 end lambda end lazy", None, ""),
        ] {
            let src = body(source);
            let out = user(&src);
            assert_eq!(codes(&out), expected.into_iter().collect::<Vec<_>>());
            assert!(matches!(expr(&out), Expr::Lazy(_)));
            if expected.is_some() {
                assert!(out.diagnostics[0].helps[0].message.contains(match key {
                    "uses" => "cannot have `uses`",
                    "effect_var" => "cannot have effect variables",
                    "lazy_body" => "a `lazy` body",
                    _ => panic!(),
                }));
                assert!(
                    out.diagnostics[0].helps[1]
                        .message
                        .contains("allowed inside a lambda")
                );
            }
        }
        let out = user(&body("try parse(s) |> Result.mapError(_, f)"));
        assert!(out.diagnostics.is_empty());
        assert!(matches!(expr(&out), Expr::Try(t) if matches!(t.value.as_ref(), Expr::Pipe(_))));
        for source in [
            "try { f() } catch (e) { g() }",
            "try { { f() } } catch (e) { { g() } } catch (x) { h() }",
        ] {
            let src = body(source);
            let out = user(&src);
            assert_eq!(codes(&out), [DiagCode::E0235], "{:?}", out.diagnostics);
            assert!(
                out.diagnostics[0].helps[0]
                    .message
                    .contains("there are no exceptions")
            );
            assert_eq!(
                out.diagnostics[0].primary.as_ref().unwrap().span.start,
                position(&src, "try").unwrap()
            );
            assert_recovers(&src, &[DiagCode::E0235]);
        }
    }
    #[test]
    fn extension_sequence_and_nesting_limits_use_default_thread_stack() {
        for (name, inside, outside) in [
            (
                "with bindings",
                format!(
                    "with {} do () end with",
                    (0..995)
                        .map(|n| format!("r{n} = f()"))
                        .collect::<Vec<_>>()
                        .join(",")
                ),
                format!(
                    "with {} do () end with",
                    (0..1001)
                        .map(|n| format!("r{n} = f()"))
                        .collect::<Vec<_>>()
                        .join(",")
                ),
            ),
            (
                "handler clauses",
                format!(
                    "handle () with\n{}\nend handle",
                    vec!["case op() -> ()"; 995].join("\n")
                ),
                format!(
                    "handle () with\n{}\nend handle",
                    vec!["case op() -> ()"; 1001].join("\n")
                ),
            ),
            (
                "lazy nesting",
                format!("{}(){}", "lazy ".repeat(498), " end lazy".repeat(498)),
                format!("{}(){}", "lazy ".repeat(1001), " end lazy".repeat(1001)),
            ),
            (
                "try nesting",
                format!("{}x", "try ".repeat(997)),
                format!("{}x", "try ".repeat(1001)),
            ),
            (
                "resume nesting",
                format!(
                    "handle () with case op() -> {}(){} end handle",
                    "resume(".repeat(994),
                    ")".repeat(994)
                ),
                format!(
                    "handle () with case op() -> {}(){} end handle",
                    "resume(".repeat(1001),
                    ")".repeat(1001)
                ),
            ),
        ] {
            eprintln!("F04 depth: {name}");
            let out = user(&body(&inside));
            assert!(out.diagnostics.is_empty(), "{name}: {:?}", out.diagnostics);
            let out = user(&body(&outside));
            assert_eq!(
                codes(&out),
                [DiagCode::E0208],
                "{name}: {:?}",
                out.diagnostics
            );
        }
    }
}
