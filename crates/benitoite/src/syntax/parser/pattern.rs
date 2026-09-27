//! パターンの解析（設計書 01-02「文法」の `Pattern`、01-05「パターン」）。
//!
//! パターンの節の深さは、入れ子の段数ではなく、行きがけ順に通して数えた番号で決める
//! （02-03「入れ子の深さ」、ADR 0086）。判定の木の深さは、一つの `match` のパターンが調べる位置の数に
//! 比例するからである。数え上げの状態は `PatternCounter` に持ち、一つの `match` のすべての分岐で
//! 共有する（T12）。

use super::text;
use super::{CommaList, Fail, PResult, Parser, comma_list, literal_of, push};
use crate::syntax::ast::{CtorPat, LitPat, Name, Pattern, UnitPat, VarPat, WildcardPat};
use crate::syntax::token::TokenKind;

/// パターンの節の数え手（ADR 0086）。
///
/// `k` 番目（0 から数える）の節の深さを、基準の深さに `k + 1` を加えたものとする。基準は `match` の深さ
/// （`match` の外のパターンでは、そのパターンを持つノードの深さ）である。
#[derive(Debug)]
pub(super) struct PatternCounter {
    base: u32,
    count: u32,
}

impl PatternCounter {
    /// 基準の深さ `base` で、節を 0 個数えた状態から始める。
    pub(super) fn new(base: u32) -> PatternCounter {
        PatternCounter { base, count: 0 }
    }

    /// 次の節の深さを返し、数えた節の数を 1 進める。溢れたら上限を超えたものとして扱う。
    fn next_depth(&mut self) -> u32 {
        let depth = self
            .count
            .checked_add(1)
            .and_then(|n| self.base.checked_add(n))
            .unwrap_or(u32::MAX);
        self.count = self.count.saturating_add(1);
        depth
    }
}

/// `Pattern = "_" | LowerIdent | [ "-" ] IntLit | StringLit | CharLit | "true" | "false" | "(" ")"
///          | UpperIdent [ "." UpperIdent ] [ "(" CommaList(Pattern) ")" ]`。
///
/// 節を行きがけ順に数える: この節を数えてから、構成子の引数の節を数える。
/// 浮動小数のリテラルはパターンに書けない（01-02「パターンマッチ」）ので、E0201 にする。
///
/// 構成子のパターンの入れ子は再帰の経路（この関数 → 構成子のパターン → 並び → この関数）を作るので、
/// 節を組み立てる処理を別の関数に分け、この関数の枠を小さく保つ（`parser` の「スタックの使い方」）。
pub(super) fn parse_pattern(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Pattern> {
    let depth = counter.next_depth();
    p.enter(depth)?;
    if p.at(TokenKind::UpperIdent) {
        return parse_ctor_pattern(p, counter);
    }
    parse_leaf_pattern(p)
}

/// 引数を持たないパターン（構成子のパターン以外）。
fn parse_leaf_pattern(p: &mut Parser) -> PResult<Pattern> {
    let start = p.pos;
    let kind = p.peek_kind();
    if kind == TokenKind::Underscore {
        p.bump();
        return Ok(Pattern::Wildcard(WildcardPat {
            id: p.node_id(),
            span: p.span_from(start),
        }));
    }
    if kind == TokenKind::LowerIdent {
        let name = p.expect_name(TokenKind::LowerIdent, text::PATTERN)?;
        return Ok(Pattern::Var(VarPat {
            id: p.node_id(),
            span: p.span_from(start),
            name,
        }));
    }
    // 前置の `-` は整数リテラルにだけ付けられる。値の範囲は型検査器が判定する（02-03「字句」）。
    if kind == TokenKind::Minus && p.peek_nth_kind(1) == TokenKind::IntLit {
        p.bump();
        return parse_lit_pattern(p, start, true);
    }
    if matches!(
        kind,
        TokenKind::IntLit
            | TokenKind::StringLit
            | TokenKind::CharLit
            | TokenKind::KwTrue
            | TokenKind::KwFalse
    ) {
        return parse_lit_pattern(p, start, false);
    }
    if kind == TokenKind::LParen && p.peek_nth_kind(1) == TokenKind::RParen {
        p.bump();
        p.bump();
        return Ok(Pattern::Unit(UnitPat {
            id: p.node_id(),
            span: p.span_from(start),
        }));
    }
    if kind == TokenKind::Error {
        return Ok(Pattern::Error(p.error_token_node()));
    }
    Err(p.unexpected(text::PATTERN))
}

/// リテラルのパターン。`start` は `-` を含めたパターンの始まりの位置。
fn parse_lit_pattern(p: &mut Parser, start: usize, negative: bool) -> PResult<Pattern> {
    let Some(lit) = literal_of(p.peek()) else {
        return Err(p.unexpected(text::PATTERN));
    };
    p.bump();
    Ok(Pattern::Lit(LitPat {
        id: p.node_id(),
        span: p.span_from(start),
        negative,
        lit,
    }))
}

/// 構成子のパターン。括弧を書いたかを `has_parens` に持つ（`Tree.Leaf()` の誤りは型検査器が報告する）。
/// 引数の節の深さは、数え手が決める（ADR 0086）。
///
/// 再帰の経路にあるので、名前の読み取り・引数の並び・節の組み立てを別の関数に分ける。
fn parse_ctor_pattern(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Pattern> {
    let start = p.pos;
    // `?` の代わりに `let ... else` で書くのは、最適化しないビルドで一時の値を減らすためである。
    let Ok(head) = parse_ctor_head(p) else {
        return Err(Fail);
    };
    let args = if head.has_parens {
        let Ok(args) = parse_ctor_args(p, counter) else {
            return Err(Fail);
        };
        args
    } else {
        Vec::new()
    };
    finish_ctor_pattern(p, start, head, args)
}

/// 構成子のパターンの、引数の前までの部分。
struct CtorHead {
    qualifier: Option<Name>,
    name: Name,
    has_parens: bool,
}

/// `UpperIdent [ "." UpperIdent ] [ "(" ]`。
fn parse_ctor_head(p: &mut Parser) -> PResult<CtorHead> {
    let first = p.expect_name(TokenKind::UpperIdent, text::CONSTRUCTOR)?;
    let (qualifier, name) = if p.eat(TokenKind::Dot) {
        let name = p.expect_name(TokenKind::UpperIdent, text::CONSTRUCTOR)?;
        (Some(first), name)
    } else {
        (None, first)
    };
    Ok(CtorHead {
        qualifier,
        name,
        has_parens: p.eat(TokenKind::LParen),
    })
}

/// `(` を読んだ後の、構成子のパターンの引数の並び。
fn parse_ctor_args(p: &mut Parser, counter: &mut PatternCounter) -> PResult<Vec<Pattern>> {
    // 並びの関数に渡す深さは使わない。引数の節の深さは数え手で決める。
    let base = counter.base;
    comma_list(
        p,
        base,
        CommaList {
            close: TokenKind::RParen,
            element: text::PATTERN,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: false,
        },
        |p, _, out| push(out, parse_pattern(p, counter)),
        |out, node| out.push(Pattern::Error(node)),
    )
}

fn finish_ctor_pattern(
    p: &mut Parser,
    start: usize,
    head: CtorHead,
    args: Vec<Pattern>,
) -> PResult<Pattern> {
    Ok(Pattern::Ctor(CtorPat {
        id: p.node_id(),
        span: p.span_from(start),
        qualifier: head.qualifier,
        name: head.name,
        has_parens: head.has_parens,
        args,
    }))
}
