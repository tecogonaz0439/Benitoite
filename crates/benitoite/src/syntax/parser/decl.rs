//! プログラムと宣言の解析（設計書 01-02「プログラムと宣言」、02-03「構文の規則に伴う次の診断」
//! 「prelude のソースの構文」）。
//!
//! 01-02 の文法の `Program`・`TopItem`・`FnDecl`・`FnTypeParams`・`FnTypeParam`・`TypeParams`・
//! `Param`・`TypeDecl`・`Variant` を、規則ごとに一つの関数で読む。

use super::text;
use super::{
    CommaList, Fail, PResult, Parser, Recovery, child, comma_list, line_list, push, stmt, types,
};
use crate::base::{SourceKind, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{
    FnDecl, Item, Name, Param, Program, TypeDecl, TypeExpr, TypeParam, Variant,
};
use crate::syntax::token::TokenKind;

/// `Program = LineList(TopItem)`。トップレベルの宣言の深さは 1 である（02-03「入れ子の深さ」）。
pub(super) fn parse_program(p: &mut Parser) -> Program {
    let first_span = p.peek().span;
    let mut items = Vec::new();
    loop {
        if p.aborted {
            break;
        }
        while p.eat(TokenKind::Newline) {}
        if p.at(TokenKind::Eof) {
            break;
        }
        let start = p.pos;
        let kind = p.peek_kind();
        let item = if kind == TokenKind::KwFn {
            parse_fn_decl(p, 1).map(|decl| Item::Fn(Box::new(decl)))
        } else if kind == TokenKind::KwType {
            parse_type_decl(p, 1).map(Item::Type)
        } else {
            Err(p.unexpected(text::DECLARATION))
        };
        match item {
            Ok(item) => items.push(item),
            Err(Fail) => {
                // 行の先頭の `fn` か `type` まで読み飛ばす（02-03「誤りからの回復」）。
                // 打ち切ったときは読み飛ばさず、それまでに読んだ範囲を誤りのノードにして終える。
                p.recover(start, Recovery::TopLevel);
                items.push(Item::Error(p.error_node_from(start)));
                continue;
            }
        }
        if matches!(p.peek_kind(), TokenKind::Newline | TokenKind::Eof) {
            continue;
        }
        // 宣言の後の同じ行の余分な字句。報告して、次の宣言まで読み飛ばす。
        let _: Fail = p.unexpected(text::NEWLINE_OR_EOF);
        let start = p.pos;
        p.recover(start, Recovery::TopLevel);
        items.push(Item::Error(p.error_node_from(start)));
    }
    let span = first_span.to(p.eof.span);
    Program {
        id: p.node_id(),
        span,
        file: p.file,
        items,
    }
}

/// `FnDecl = "fn" LowerIdent [ FnTypeParams ] "(" CommaList(Param) ")" "->" Type [ Uses ] Block`。
fn parse_fn_decl(p: &mut Parser, depth: u32) -> PResult<FnDecl> {
    p.enter(depth)?;
    let start = p.pos;
    p.expect(TokenKind::KwFn)?;
    let (module, name) = parse_fn_name(p)?;
    let type_params = if p.eat(TokenKind::LBracket) {
        comma_list(
            p,
            depth,
            CommaList {
                close: TokenKind::RBracket,
                element: text::TYPE_PARAMETER,
                separator: text::COMMA_OR_RBRACKET,
                allow_empty: false,
                indexed: false,
            },
            |p, d, out| push(out, parse_fn_type_param(p, d)),
            // 型パラメータの並びには誤りのノードを置く場所がない。診断は報告済みなので、
            // この AST は名前解決へ渡らない（ADR 0019）。
            |_, _| {},
        )?
    } else {
        Vec::new()
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
        |p, d, out| push(out, parse_param(p, d)),
        |_, _| {},
    )?;
    p.expect(TokenKind::Arrow)?;
    // 戻り値の型が関数の型なら、その解析が先に `uses` を読む（02-03「型の解析」）。
    // ここに `uses` が残るのは、戻り値の型が関数の型でないか、括弧で囲んだ関数の型のときである。
    let ret = types::parse_type(p, child(depth))?;
    let uses = if p.at(TokenKind::KwUses) {
        Some(types::parse_uses(p, depth)?)
    } else {
        None
    };
    check_brace_on_next_line(p);
    let body = stmt::parse_block(p, child(depth))?;
    Ok(FnDecl {
        id: p.node_id(),
        span: p.span_from(start),
        module,
        name,
        type_params,
        params,
        ret,
        uses,
        body,
    })
}

/// 関数の名前。`UpperIdent "." LowerIdent` の形は修飾した名前で、prelude のソースでだけ受け付ける
/// （02-03「prelude のソースの構文」）。利用者のソースでは E0207 を報告し、修飾を持ったまま続ける。
fn parse_fn_name(p: &mut Parser) -> PResult<(Option<Name>, Name)> {
    if p.at(TokenKind::UpperIdent)
        && p.peek_nth_kind(1) == TokenKind::Dot
        && p.peek_nth_kind(2) == TokenKind::LowerIdent
    {
        let module = super::name_of(&p.bump());
        let dot = p.bump();
        if p.kind == SourceKind::User {
            let diagnostic = DiagBuilder::new(DiagCode::E0207)
                .arg("module", module.text.clone())
                .primary(module.span.to(dot.span))
                .help("remove")
                .build();
            p.report(diagnostic);
        }
        let name = p.expect_name(TokenKind::LowerIdent, text::NAME)?;
        return Ok((Some(module), name));
    }
    let name = p.expect_name(TokenKind::LowerIdent, text::NAME)?;
    Ok((None, name))
}

/// 戻り値の型（と `uses`）の直後が NEWLINE で、次の字句が `{` なら E0205 を報告する
/// （01-01「改行による区切り」、02-03「構文の規則に伴う次の診断」）。
/// 報告の後は NEWLINE を読み飛ばして本体の解析を続ける（回復の方法は実装プラン T11 の決定）。
fn check_brace_on_next_line(p: &mut Parser) {
    if p.at(TokenKind::Newline) && p.peek_nth_kind(1) == TokenKind::LBrace {
        p.advance();
        let diagnostic = DiagBuilder::new(DiagCode::E0205)
            .primary(p.peek().span)
            .help("same_line")
            .build();
        p.report(diagnostic);
    }
}

/// `FnTypeParam = [ "effect" ] UpperIdent`。
fn parse_fn_type_param(p: &mut Parser, depth: u32) -> PResult<TypeParam> {
    p.enter(depth)?;
    let start = p.pos;
    let is_effect = p.eat(TokenKind::KwEffect);
    let name = p.expect_name(TokenKind::UpperIdent, text::TYPE_PARAMETER)?;
    Ok(TypeParam {
        id: p.node_id(),
        span: p.span_from(start),
        is_effect,
        name,
    })
}

/// 型の宣言の `TypeParams` の要素（`UpperIdent`）。型の宣言の型パラメータには `effect` を
/// 付けられない（01-02「文法」）ので、`effect` は期待しない字句として E0201 にする。
fn parse_type_param(p: &mut Parser, depth: u32) -> PResult<TypeParam> {
    p.enter(depth)?;
    let start = p.pos;
    let name = p.expect_name(TokenKind::UpperIdent, text::TYPE_PARAMETER)?;
    Ok(TypeParam {
        id: p.node_id(),
        span: p.span_from(start),
        is_effect: false,
        name,
    })
}

/// `Param = LowerIdent ":" Type`。
fn parse_param(p: &mut Parser, depth: u32) -> PResult<Param> {
    p.enter(depth)?;
    let start = p.pos;
    let name = p.expect_name(TokenKind::LowerIdent, text::PARAMETER)?;
    p.expect(TokenKind::Colon)?;
    let ty = types::parse_type(p, child(depth))?;
    Ok(Param {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        ty: Some(ty),
    })
}

/// `TypeDecl = "type" UpperIdent [ TypeParams ] "{" LineList(Variant) "}"`。
/// 構成子のない型の宣言（`type T {}`）は構文エラーにしない。型検査が E0411 を報告する。
fn parse_type_decl(p: &mut Parser, depth: u32) -> PResult<TypeDecl> {
    p.enter(depth)?;
    let start = p.pos;
    p.expect(TokenKind::KwType)?;
    let name = p.expect_name(TokenKind::UpperIdent, text::NAME)?;
    let type_params = if p.eat(TokenKind::LBracket) {
        comma_list(
            p,
            depth,
            CommaList {
                close: TokenKind::RBracket,
                element: text::TYPE_PARAMETER,
                separator: text::COMMA_OR_RBRACKET,
                allow_empty: false,
                indexed: false,
            },
            |p, d, out| push(out, parse_type_param(p, d)),
            |_, _| {},
        )?
    } else {
        Vec::new()
    };
    p.expect(TokenKind::LBrace)?;
    // 構成子の並びにも誤りのノードを置く場所がない（型パラメータの並びと同じ）。
    let variants = line_list(
        p,
        depth,
        false,
        |p, d, out| push(out, parse_variant(p, d)),
        |_, _| {},
    )?;
    Ok(TypeDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        type_params,
        variants,
    })
}

/// `Variant = UpperIdent [ "(" CommaList(Type) ")" ]`。
/// 空の括弧（`Leaf()`）は E0206 を報告し、引数のない構成子として続ける（01-05「型の宣言」）。
fn parse_variant(p: &mut Parser, depth: u32) -> PResult<Variant> {
    p.enter(depth)?;
    let start = p.pos;
    let name = p.expect_name(TokenKind::UpperIdent, text::CONSTRUCTOR)?;
    let fields = if p.at(TokenKind::LParen) && p.peek_nth_kind(1) == TokenKind::RParen {
        let open = p.bump();
        let close = p.bump();
        report_empty_parens(p, &name, open.span.to(close.span));
        Vec::new()
    } else if p.eat(TokenKind::LParen) {
        comma_list(
            p,
            depth,
            CommaList {
                close: TokenKind::RParen,
                element: text::TYPE,
                separator: text::COMMA_OR_RPAREN,
                allow_empty: true,
                indexed: false,
            },
            |p, d, out| push(out, types::parse_type(p, d)),
            |out, node| out.push(TypeExpr::Error(node)),
        )?
    } else {
        Vec::new()
    };
    Ok(Variant {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        fields,
    })
}

fn report_empty_parens(p: &mut Parser, name: &Name, span: Span) {
    let diagnostic = DiagBuilder::new(DiagCode::E0206)
        .arg("name", name.text.clone())
        .primary(span)
        .help("remove")
        .build();
    p.report(diagnostic);
}
