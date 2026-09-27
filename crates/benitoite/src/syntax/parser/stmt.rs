//! ブロックと文の解析（設計書 01-02「ブロックと文」、01-02「文法」の `Block`・`Stmt`・`LetStmt`）。
//!
//! ブロックの入れ子は再帰の経路（ブロック → 文 → 式 → ブロック）を作るので、この経路の関数は
//! 大きな値を枠に置かないように書く（`parser` の「スタックの使い方」）。

use super::text;
use super::{Fail, PResult, Parser, child, describe_kind, expr, line_list, types};
use crate::syntax::ast::{Block, Expr, LetName, LetStmt, Stmt, TypeExpr};
use crate::syntax::token::TokenKind;

/// `Block = "{" LineList(Stmt) "}"`。
///
/// i 番目（0 から数える）の文は、ブロックの深さに `i + 1` を加えた深さで解析する。
/// ブロックは脱糖で `let` の入れ子になるので、文の一つ一つを 1 段と数える（02-03「入れ子の深さ」）。
pub(super) fn parse_block(p: &mut Parser, depth: u32) -> PResult<Block> {
    p.enter(depth)?;
    let start = p.pos;
    if !p.eat(TokenKind::LBrace) {
        return Err(p.unexpected(describe_kind(TokenKind::LBrace)));
    }
    let stmts = line_list(p, depth, true, parse_stmt, |out, node| {
        out.push(Stmt::Error(node));
    })?;
    finish_block(p, start, stmts)
}

fn finish_block(p: &mut Parser, start: usize, stmts: Vec<Stmt>) -> PResult<Block> {
    Ok(Block {
        id: p.node_id(),
        span: p.span_from(start),
        stmts,
    })
}

/// `Stmt = LetStmt | Expr`。`depth` はこの文の深さである。読んだ文を `out` に加える。
fn parse_stmt(p: &mut Parser, depth: u32, out: &mut Vec<Stmt>) -> PResult<()> {
    if p.at(TokenKind::KwLet) {
        return parse_let(p, depth, out);
    }
    let start = p.pos;
    let expr = expr::parse_expr(p, depth);
    push_expr_stmt(p, start, expr, out)
}

fn push_expr_stmt(p: &Parser, start: usize, expr: Expr, out: &mut Vec<Stmt>) -> PResult<()> {
    if p.aborted {
        return Err(Fail);
    }
    // 式の解析が字句を一つも読まずに失敗したら（報告済み）、文の回復に任せ、
    // 読み飛ばした範囲を一つの誤りの文にする（02-03「誤りからの回復」）。
    if matches!(expr, Expr::Error(_)) && p.pos == start {
        return Err(Fail);
    }
    out.push(Stmt::Expr(expr));
    Ok(())
}

/// `LetStmt = "let" ( LowerIdent | "_" ) [ ":" Type ] "=" Expr`。読んだ文を `out` に加える。
fn parse_let(p: &mut Parser, depth: u32, out: &mut Vec<Stmt>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    p.expect(TokenKind::KwLet)?;
    let name = if p.at(TokenKind::Underscore) {
        LetName::Wildcard(p.bump().span)
    } else {
        LetName::Var(p.expect_name(TokenKind::LowerIdent, text::NAME)?)
    };
    let ty = if p.eat(TokenKind::Colon) {
        Some(types::parse_type(p, child(depth))?)
    } else {
        None
    };
    p.expect(TokenKind::Eq)?;
    let value = expr::parse_expr(p, child(depth));
    push_let(p, start, name, ty, value, out)
}

fn push_let(
    p: &mut Parser,
    start: usize,
    name: LetName,
    ty: Option<TypeExpr>,
    value: Expr,
    out: &mut Vec<Stmt>,
) -> PResult<()> {
    if p.aborted {
        return Err(Fail);
    }
    out.push(Stmt::Let(LetStmt {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        ty,
        value,
    }));
    Ok(())
}
