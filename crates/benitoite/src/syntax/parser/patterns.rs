//! 基本のパターンの解析（設計書 02-03「入れ子の深さ」、ADR 0086）。
use super::{
    CommaList, Fail, PResult, Parser, comma_list, literal_of, patterns_ext, records, text,
};
use crate::syntax::{ast::*, token::TokenKind};

/// 一つの `match` または束縛の左辺の、パターンの節の通し番号。
pub(super) struct PatternCounter {
    pub(super) base: u32,
    pub(super) count: u32,
}
impl PatternCounter {
    pub(super) fn new(base: u32) -> Self {
        Self { base, count: 0 }
    }
    pub(super) fn next_depth(&mut self) -> u32 {
        self.count = self.count.saturating_add(1);
        self.base.saturating_add(self.count)
    }
}
pub(super) fn parse_pattern(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Box<Pattern>> {
    p.enter(counter.next_depth())?;
    if p.at(TokenKind::Error) {
        return Ok(Box::new(Pattern::Error(p.error_token_node())));
    }
    if p.at(TokenKind::UpperIdent) {
        return parse_ctor(p, counter);
    }
    if p.at(TokenKind::LBracket) {
        return patterns_ext::parse_list_pattern(p, counter);
    }
    if p.at(TokenKind::LParen) {
        return parse_paren(p, counter);
    }
    parse_atom(p, counter)
}
fn parse_atom(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Box<Pattern>> {
    let start = p.pos;
    if p.at(TokenKind::Underscore) {
        let span = p.bump().span;
        return Ok(Box::new(Pattern::Wildcard(WildcardPat {
            id: p.node_id(),
            span,
        })));
    }
    if p.at(TokenKind::LowerIdent)
        || super::text::keyword(p.peek_kind()).is_some()
            && !matches!(p.peek_kind(), TokenKind::KwTrue | TokenKind::KwFalse)
    {
        let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
        return Ok(Box::new(Pattern::Var(VarPat {
            id: p.node_id(),
            span: name.span,
            name,
        })));
    }
    let negative = p.eat(TokenKind::Minus);
    if negative && !p.at(TokenKind::IntLit)
        || matches!(p.peek_kind(), TokenKind::FloatLit | TokenKind::DecimalLit)
    {
        return Err(p.unexpected(text::PATTERN));
    }
    let Some(lit) = literal_of(p.peek()) else {
        return Err(p.unexpected(text::PATTERN));
    };
    let range_end = matches!(p.peek_kind(), TokenKind::IntLit | TokenKind::CharLit);
    p.bump();
    let first = Box::new(Pattern::Lit(LitPat {
        id: p.node_id(),
        span: p.span_from(start),
        negative,
        lit,
    }));
    if range_end && p.at(TokenKind::DotDot) {
        patterns_ext::parse_range_rest(p, *first, counter)
    } else {
        Ok(first)
    }
}
fn parse_ctor(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Box<Pattern>> {
    let start = p.pos;
    let path = p.qual_name(true)?;
    if super::exprs::record_ahead(p) {
        return records::parse_record_pattern(p, path, p.span_from(start), counter);
    }
    let has_parens = p.eat(TokenKind::LParen);
    let args = if has_parens {
        comma_list(
            p,
            counter.base,
            CommaList {
                close: TokenKind::RParen,
                element: text::PATTERN,
                separator: text::COMMA_OR_RPAREN,
                allow_empty: true,
                indexed: false,
            },
            |p, _, out| push_pattern(p, counter, out),
            |out, error| out.push(Pattern::Error(error)),
        )?
    } else {
        Vec::new()
    };
    Ok(finish_ctor(p, start, path, has_parens, args))
}
fn finish_ctor(
    p: &mut Parser,
    start: usize,
    path: Vec<Name>,
    has_parens: bool,
    args: Vec<Pattern>,
) -> Box<Pattern> {
    Box::new(Pattern::Ctor(CtorPat {
        id: p.node_id(),
        span: p.span_from(start),
        path,
        has_parens,
        args,
    }))
}
fn push_pattern(
    p: &mut Parser,
    counter: &mut PatternCounter,
    out: &mut Vec<Pattern>,
) -> PResult<()> {
    let Ok(pattern) = parse_pattern(p, counter) else {
        return Err(Fail);
    };
    out.push(*pattern);
    Ok(())
}
fn parse_paren(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Box<Pattern>> {
    let start = p.pos;
    p.bump();
    if p.eat(TokenKind::RParen) {
        return Ok(Box::new(Pattern::Unit(UnitPat {
            id: p.node_id(),
            span: p.span_from(start),
        })));
    }
    drop(parse_pattern(p, counter)?);
    let mut count = 1_usize;
    let comma = p.peek().span;
    let tuple = p.at(TokenKind::Comma);
    while p.eat(TokenKind::Comma) {
        if p.at(TokenKind::RParen) {
            break;
        }
        drop(parse_pattern(p, counter)?);
        count = count.saturating_add(1);
    }
    if tuple {
        patterns_ext::report_tuple(p, count, comma);
    } else {
        p.unexpected(text::RPAREN);
    }
    p.expect(TokenKind::RParen)?;
    Ok(Box::new(Pattern::Error(p.error_node_from(start))))
}
