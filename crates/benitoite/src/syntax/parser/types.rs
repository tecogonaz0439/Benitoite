//! 型と `uses` の並びの解析（設計書 02-03「型の解析」、01-02「文法」の `Type` と `Uses`、ADR 0047）。

use super::text;
use super::{CommaList, PResult, Parser, child, comma_list, is_close, is_open, push};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{EffectRef, FnType, NamedType, ParenType, TypeExpr, UsesList};
use crate::syntax::token::TokenKind;

/// `Type = UpperIdent [ "[" Type { "," Type } [ "," ] "]" ] | "fn" "(" CommaList(Type) ")" "->" Type [ Uses ] | "(" Type ")"`。
pub(super) fn parse_type(p: &mut Parser, depth: u32) -> PResult<TypeExpr> {
    p.enter(depth)?;
    let kind = p.peek_kind();
    if kind == TokenKind::UpperIdent {
        parse_named_type(p, depth).map(TypeExpr::Named)
    } else if kind == TokenKind::KwFn {
        parse_fn_type(p, depth).map(TypeExpr::Fn)
    } else if kind == TokenKind::LParen {
        parse_paren_type(p, depth)
    } else if kind == TokenKind::Error {
        Ok(TypeExpr::Error(p.error_token_node()))
    } else {
        Err(p.unexpected(text::TYPE))
    }
}

fn parse_named_type(p: &mut Parser, depth: u32) -> PResult<NamedType> {
    let start = p.pos;
    let name = p.expect_name(TokenKind::UpperIdent, text::TYPE)?;
    let args = if p.eat(TokenKind::LBracket) {
        comma_list(
            p,
            depth,
            CommaList {
                close: TokenKind::RBracket,
                element: text::TYPE,
                separator: text::COMMA_OR_RBRACKET,
                allow_empty: false,
                indexed: false,
            },
            |p, d, out| push(out, parse_type(p, d)),
            |out, node| out.push(TypeExpr::Error(node)),
        )?
    } else {
        Vec::new()
    };
    Ok(NamedType {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        args,
    })
}

/// 関数の型。戻り値の型の後の `uses` は、この関数の型に付く。戻り値の型が関数の型なら、
/// その解析が先に `uses` を読むので、`uses` は最も内側の関数の型に付く（02-03「型の解析」）。
fn parse_fn_type(p: &mut Parser, depth: u32) -> PResult<FnType> {
    let start = p.pos;
    p.expect(TokenKind::KwFn)?;
    p.expect(TokenKind::LParen)?;
    let params = comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RParen,
            element: text::TYPE,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: false,
        },
        |p, d, out| push(out, parse_type(p, d)),
        |out, node| out.push(TypeExpr::Error(node)),
    )?;
    p.expect(TokenKind::Arrow)?;
    let ret = parse_type(p, child(depth))?;
    let uses = if p.at(TokenKind::KwUses) {
        Some(parse_uses(p, depth)?)
    } else {
        None
    };
    Ok(FnType {
        id: p.node_id(),
        span: p.span_from(start),
        params,
        ret: Box::new(ret),
        uses,
    })
}

/// 括弧の型 `"(" Type ")"`。`()` は型ではないので E0201 を報告し、`()` を誤りのノードにする。
fn parse_paren_type(p: &mut Parser, depth: u32) -> PResult<TypeExpr> {
    let start = p.pos;
    p.expect(TokenKind::LParen)?;
    if p.at(TokenKind::RParen) {
        let _: super::Fail = p.unexpected(text::TYPE);
        // 期待どおりの字句ではないので、抑制を解かずに読む。
        p.advance();
        return Ok(TypeExpr::Error(p.error_node_from(start)));
    }
    let inner = parse_type(p, child(depth))?;
    p.expect(TokenKind::RParen)?;
    Ok(TypeExpr::Paren(ParenType {
        id: p.node_id(),
        span: p.span_from(start),
        inner: Box::new(inner),
    }))
}

/// `Uses = "uses" UpperIdent { "," UpperIdent }`。`owner_depth` は `uses` を持つノード
/// （関数の型、関数の宣言、ラムダ）の深さで、エフェクトの名前のノードはその子である。
///
/// 並びは最長一致で読む。`,` の次が大文字の識別子である間だけ読み進め、そうでなければ `,` を
/// 読まずに終える（その `,` は外側の並びの区切りになる。02-03「型の解析」）。
/// 並びに読んだ名前がエフェクトの名前であるかは判定しない（名前解決が報告する）。
pub(super) fn parse_uses(p: &mut Parser, owner_depth: u32) -> PResult<UsesList> {
    let start_span = p.peek().span;
    p.expect(TokenKind::KwUses)?;
    let depth = child(owner_depth);
    let mut effects = vec![parse_effect_ref(p, depth)?];
    while p.at(TokenKind::Comma) && p.peek_nth_kind(1) == TokenKind::UpperIdent {
        p.bump();
        let effect = parse_effect_ref(p, depth)?;
        let effect_span = effect.span;
        effects.push(effect);
        if p.at(TokenKind::LBracket) {
            // 2 番目以降の名前に型引数が続くのは、関数の型を括弧で囲み忘れた形である
            // （`fn(fn() -> Unit uses IO, List[Int]) -> Unit`）。報告して `[...]` を読み飛ばし、並びを終える。
            let bracket_start = p.pos;
            skip_bracketed(p);
            let span = effect_span.to(p.span_from(bracket_start));
            let diagnostic = DiagBuilder::new(DiagCode::E0209)
                .primary(span)
                .help("paren")
                .build();
            p.report(diagnostic);
            break;
        }
    }
    let end_span = effects.last().map_or(start_span, |e| e.span);
    Ok(UsesList {
        span: start_span.to(end_span),
        effects,
    })
}

fn parse_effect_ref(p: &mut Parser, depth: u32) -> PResult<EffectRef> {
    p.enter(depth)?;
    let name = p.expect_name(TokenKind::UpperIdent, text::EFFECT)?;
    Ok(EffectRef {
        id: p.node_id(),
        span: name.span,
        name,
    })
}

/// 今の開き括弧から、対応する閉じ括弧までを読み飛ばす。`Eof` に達したら止める。
fn skip_bracketed(p: &mut Parser) {
    let mut nesting: u32 = 0;
    loop {
        let kind = p.peek_kind();
        if kind == TokenKind::Eof {
            return;
        }
        p.advance();
        if is_open(kind) {
            nesting = nesting.saturating_add(1);
        } else if is_close(kind) {
            nesting = nesting.saturating_sub(1);
            if nesting == 0 {
                return;
            }
        }
    }
}
