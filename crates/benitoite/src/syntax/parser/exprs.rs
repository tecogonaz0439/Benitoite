//! 式・文・ブロックの解析（設計書 02-03「構文解析の方式」「入れ子の深さ」、01-02）。
//! 再帰の経路は箱を受け渡し、大きいノードは finish_* で組み立てる。
use super::{
    ClauseContext, CommaList, EscapeContext, Fail, PResult, Parser, Recovery, child, comma_list,
    decls, effects, foreign, interp, literal_of, nth_child,
    patterns::{self, PatternCounter},
    patterns_ext, records, spread, text, types,
};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{ast::*, token::TokenKind};

#[derive(Clone, Copy)]
enum Infix {
    Binary(BinOp),
    Pipe,
}
const OPERATORS: &[(TokenKind, Infix, u8)] = &[
    (TokenKind::PipeGt, Infix::Pipe, 10),
    (TokenKind::KwOr, Infix::Binary(BinOp::Or), 20),
    (TokenKind::KwAnd, Infix::Binary(BinOp::And), 30),
    (TokenKind::Eq, Infix::Binary(BinOp::Eq), 40),
    (TokenKind::NotEq, Infix::Binary(BinOp::Ne), 40),
    (TokenKind::Lt, Infix::Binary(BinOp::Lt), 40),
    (TokenKind::Le, Infix::Binary(BinOp::Le), 40),
    (TokenKind::Gt, Infix::Binary(BinOp::Gt), 40),
    (TokenKind::Ge, Infix::Binary(BinOp::Ge), 40),
    (TokenKind::Plus, Infix::Binary(BinOp::Add), 50),
    (TokenKind::Minus, Infix::Binary(BinOp::Sub), 50),
    (TokenKind::Star, Infix::Binary(BinOp::Mul), 60),
    (TokenKind::Slash, Infix::Binary(BinOp::Div), 60),
    (TokenKind::KwDiv, Infix::Binary(BinOp::IntDiv), 60),
    (TokenKind::KwMod, Infix::Binary(BinOp::Mod), 60),
];
fn infix(p: &Parser) -> Option<(Infix, u8)> {
    let kind = if p.symbol("==") {
        TokenKind::Eq
    } else if p.symbol("!=") {
        TokenKind::NotEq
    } else if p.symbol("&&") {
        TokenKind::KwAnd
    } else if p.symbol("||") {
        TokenKind::KwOr
    } else if p.symbol("%") {
        TokenKind::KwMod
    } else {
        p.peek_kind()
    };
    OPERATORS
        .iter()
        .find(|(k, _, _)| *k == kind)
        .map(|(_, op, power)| (*op, *power))
}
fn take_operator(p: &mut Parser) -> Span {
    if p.symbol("==") {
        foreign::operator(p, "equal", Some("="));
    } else if p.symbol("!=") {
        foreign::operator(p, "not_equal", Some("<>"));
    } else if p.symbol("&&") {
        foreign::operator(p, "and", Some("and"));
    } else if p.symbol("||") {
        foreign::operator(p, "or", Some("or"));
    } else if p.symbol("%") {
        foreign::operator(p, "remainder", Some("mod"));
    }
    p.bump().span
}
fn next_step(p: &Parser, min: u8) -> bool {
    ((p.at(TokenKind::LParen) || p.at(TokenKind::Dot) || p.symbol("?")) && min <= 80)
        || infix(p).is_some_and(|(_, power)| power >= min)
}

pub(super) fn parse_expr(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    parse_bp(p, depth, 0)
}
fn parse_bp(p: &mut Parser, depth: u32, min: u8) -> PResult<Box<Expr>> {
    // return と try は Expr の先頭だけにあり、二項・単項のオペランドには括弧が要る
    // （設計書 01-02「初回リリース版の文法の全体」の Expr と UnaryExpr）。
    if min > 0 && matches!(p.peek_kind(), TokenKind::KwReturn | TokenKind::KwTry) {
        return Err(p.unexpected(text::EXPRESSION));
    }
    let outer = p.deepest;
    p.deepest = 0;
    let Ok(lhs) = parse_primary(p, depth) else {
        p.deepest = outer;
        return Err(Fail);
    };
    if !next_step(p, min) {
        p.deepest = p.deepest.max(outer);
        return Ok(lhs);
    }
    continue_bp(p, depth, min, outer, lhs)
}
fn continue_bp(
    p: &mut Parser,
    depth: u32,
    min: u8,
    outer: u32,
    mut lhs: Box<Expr>,
) -> PResult<Box<Expr>> {
    let mut height = p.deepest.max(depth);
    while next_step(p, min) && !p.aborted {
        if p.at(TokenKind::Dot) {
            lhs = skip_dot(p, depth, lhs)?;
            continue;
        }
        if p.symbol("?") {
            foreign::operator(p, "question", None);
            p.bump();
            continue;
        }
        p.deepest = 0;
        if p.at(TokenKind::LParen) {
            let Ok(args) = parse_args(p, depth) else {
                p.deepest = outer;
                return Err(Fail);
            };
            lhs = finish_call(p, lhs, args);
        } else {
            let Some((op, power)) = infix(p) else {
                break;
            };
            let op_span = take_operator(p);
            let Ok(rhs) = parse_bp(p, child(depth), power.saturating_add(1)) else {
                p.deepest = outer;
                return Err(Fail);
            };
            let middle = span_of(&rhs);
            lhs = finish_binary(p, op, op_span, lhs, rhs);
            if power == 40 && infix(p).is_some_and(|(_, next)| next == 40) {
                report_chain(p, middle);
                while infix(p).is_some_and(|(_, next)| next == 40) {
                    take_operator(p);
                    drop(parse_bp(p, child(depth), 41)?);
                }
            }
        }
        height = child(height).max(p.deepest);
        p.enter(height)?;
    }
    p.deepest = height.max(outer);
    Ok(lhs)
}
fn finish_binary(
    p: &mut Parser,
    op: Infix,
    op_span: Span,
    lhs: Box<Expr>,
    rhs: Box<Expr>,
) -> Box<Expr> {
    let id = p.node_id();
    let span = span_of(&lhs).to(span_of(&rhs));
    Box::new(match op {
        Infix::Binary(op) => Expr::Binary(BinaryExpr {
            id,
            span,
            op,
            op_span,
            lhs,
            rhs,
        }),
        Infix::Pipe => Expr::Pipe(PipeExpr { id, span, lhs, rhs }),
    })
}
fn finish_call(p: &mut Parser, callee: Box<Expr>, args: Vec<Arg>) -> Box<Expr> {
    let span = span_of(&callee).to(p.span_from(p.pos.saturating_sub(1)));
    Box::new(Expr::Call(CallExpr {
        id: p.node_id(),
        span,
        callee,
        args,
    }))
}
fn report_chain(p: &mut Parser, middle: Span) {
    let operator = p.peek().span;
    // 演算子の前の空白も挿入点まで含め、直した行の空白が重複しないようにする。
    let insertion = Span {
        start: middle.end,
        end: operator.start,
        ..operator
    };
    let replacement = format!(" and {} ", p.snippet(middle));
    p.report(
        DiagBuilder::new(DiagCode::E0202)
            .primary(operator)
            .help_edits(
                "and",
                vec![Edit {
                    span: insertion,
                    replacement,
                }],
            )
            .build(),
    );
}
fn skip_dot(p: &mut Parser, depth: u32, lhs: Box<Expr>) -> PResult<Box<Expr>> {
    let from = p.pos;
    let start = span_of(&lhs);
    p.advance();
    let field = p.at(TokenKind::LowerIdent);
    if matches!(p.peek_kind(), TokenKind::LowerIdent | TokenKind::UpperIdent) {
        p.advance();
    }
    let primary = p.span_from(from);
    let mut diagnostic = DiagBuilder::new(DiagCode::E0203)
        .primary(primary)
        .help("pipe");
    if field {
        diagnostic = diagnostic.help("field");
    }
    p.report(diagnostic.build());
    if p.at(TokenKind::LParen) {
        drop(parse_args(p, depth)?);
    }
    let mut error = p.error_node_from(from);
    error.span = start.to(error.span);
    Ok(Box::new(Expr::Error(error)))
}

pub(super) fn record_ahead(p: &Parser) -> bool {
    p.at(TokenKind::LParen)
        && (p.peek_nth_kind(1) == TokenKind::DotDot
            || p.peek_nth_kind(1) == TokenKind::LowerIdent
                && p.peek_nth_kind(2) == TokenKind::Colon)
}
fn parse_primary(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    if p.at(TokenKind::KwReturn) {
        return parse_return(p, depth);
    }
    if p.at(TokenKind::KwTry) {
        return effects::parse_try(p, depth);
    }
    if p.at(TokenKind::KwNot) || p.at(TokenKind::Minus) || p.symbol("!") {
        return parse_unary(p, depth);
    }
    match p.peek_kind() {
        TokenKind::LParen => parse_paren(p, depth),
        TokenKind::LBracket => parse_list(p, depth),
        TokenKind::KwIf if p.ctx.in_arm_head => Err(p.unexpected(text::EXPRESSION)),
        TokenKind::KwIf => parse_if(p, depth, true),
        TokenKind::KwMatch => parse_match(p, depth),
        TokenKind::KwLambda => parse_lambda(p, depth),
        TokenKind::StrStart => interp::parse_interp(p, depth),
        TokenKind::KwLazy => effects::parse_lazy(p, depth),
        TokenKind::KwWith => effects::parse_with(p, depth),
        TokenKind::KwHandle => effects::parse_handle(p, depth),
        TokenKind::KwResume => effects::parse_resume(p, depth),
        TokenKind::KwCase => foreign_case(p, depth),
        TokenKind::LowerIdent
        | TokenKind::UpperIdent
        | TokenKind::IntLit
        | TokenKind::FloatLit
        | TokenKind::DecimalLit
        | TokenKind::StringLit
        | TokenKind::StrMid
        | TokenKind::StrEnd
        | TokenKind::CharLit
        | TokenKind::KwAnd
        | TokenKind::KwBind
        | TokenKind::KwConst
        | TokenKind::KwData
        | TokenKind::KwDiv
        | TokenKind::KwDo
        | TokenKind::KwEffect
        | TokenKind::KwElse
        | TokenKind::KwEnd
        | TokenKind::KwFalse
        | TokenKind::KwFunction
        | TokenKind::KwImplement
        | TokenKind::KwImport
        | TokenKind::KwMod
        | TokenKind::KwNot
        | TokenKind::KwOr
        | TokenKind::KwPublic
        | TokenKind::KwRecord
        | TokenKind::KwReturn
        | TokenKind::KwShadow
        | TokenKind::KwThen
        | TokenKind::KwTrait
        | TokenKind::KwTrue
        | TokenKind::KwTry
        | TokenKind::KwType
        | TokenKind::KwUses
        | TokenKind::Plus
        | TokenKind::Minus
        | TokenKind::Star
        | TokenKind::Slash
        | TokenKind::Eq
        | TokenKind::NotEq
        | TokenKind::Lt
        | TokenKind::Le
        | TokenKind::Gt
        | TokenKind::Ge
        | TokenKind::PipeGt
        | TokenKind::Arrow
        | TokenKind::LeftArrow
        | TokenKind::Colon
        | TokenKind::Comma
        | TokenKind::Dot
        | TokenKind::DotDot
        | TokenKind::Amp
        | TokenKind::At
        | TokenKind::RParen
        | TokenKind::RBracket
        | TokenKind::Underscore
        | TokenKind::LineBreak
        | TokenKind::Newline
        | TokenKind::Error
        | TokenKind::BadSymbol
        | TokenKind::Eof => parse_leaf(p, depth),
    }
}
fn parse_leaf(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    // レコードの更新元は深さの上限まで再帰する。リテラルや診断の組み立てを
    // 同じ枠に置くと、上限内でもスタックを使い切る（設計書 02-03「入れ子の深さ」）。
    if matches!(p.peek_kind(), TokenKind::LowerIdent | TokenKind::UpperIdent) {
        if foreign::fn_lambda_ahead(p) {
            return parse_foreign_lambda(p);
        }
        return parse_name(p, depth);
    }
    parse_literal_or_error(p)
}
fn parse_literal_or_error(p: &mut Parser) -> PResult<Box<Expr>> {
    if p.at(TokenKind::Error) {
        return Ok(Box::new(Expr::Error(p.error_token_node())));
    }
    if p.at(TokenKind::Underscore) {
        let start = p.pos;
        let span = p.bump().span;
        p.report(DiagBuilder::new(DiagCode::E0204).primary(span).build());
        return Ok(Box::new(Expr::Error(p.error_node_from(start))));
    }
    if let Some(lit) = literal_of(p.peek()) {
        let span = p.bump().span;
        return Ok(Box::new(Expr::Lit(LitExpr {
            id: p.node_id(),
            span,
            lit,
        })));
    }
    Err(p.unexpected(text::EXPRESSION))
}
fn parse_foreign_lambda(p: &mut Parser) -> PResult<Box<Expr>> {
    let start = p.pos;
    foreign::fn_form(p, "lambda");
    Ok(Box::new(Expr::Error(p.error_node_from(start))))
}
fn parse_name(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let upper = p.at(TokenKind::UpperIdent);
    let path = p.qual_name(false)?;
    if upper
        && path
            .last()
            .is_some_and(|n| n.text.starts_with(char::is_uppercase))
        && record_ahead(p)
    {
        return records::parse_record_expr(p, path, p.span_from(start), depth);
    }
    Ok(finish_name(p, start, path))
}
fn finish_name(p: &mut Parser, start: usize, path: Vec<Name>) -> Box<Expr> {
    Box::new(Expr::Name(NameExpr {
        id: p.node_id(),
        span: p.span_from(start),
        path,
    }))
}
fn parse_return(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let span = p.bump().span;
    effects::check_escape(p, TokenKind::KwReturn, span);
    let Ok(value) = parse_expr(p, child(depth)) else {
        return Err(Fail);
    };
    Ok(Box::new(Expr::Return(ReturnExpr {
        id: p.node_id(),
        span: p.span_from(start),
        value,
    })))
}
fn parse_unary(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let op = if p.at(TokenKind::Minus) {
        UnOp::Neg
    } else {
        UnOp::Not
    };
    if p.symbol("!") {
        foreign::operator(p, "not", Some("not "));
    }
    let op_span = p.bump().span;
    let Ok(operand) = parse_bp(p, child(depth), 70) else {
        return Err(Fail);
    };
    Ok(Box::new(Expr::Unary(UnaryExpr {
        id: p.node_id(),
        span: p.span_from(start),
        op,
        op_span,
        operand,
    })))
}
fn parse_paren(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    p.bump();
    if p.eat(TokenKind::RParen) {
        return Ok(Box::new(Expr::Unit(UnitExpr {
            id: p.node_id(),
            span: p.span_from(start),
        })));
    }
    // ガードの中の if の式は括弧内でだけ読める（設計書 01-02「パターンの拡張（初回リリース版）」）。
    let saved_head = p.ctx.in_arm_head;
    p.ctx.in_arm_head = false;
    let inner = parse_expr(p, child(depth));
    p.ctx.in_arm_head = saved_head;
    let Ok(inner) = inner else {
        return Err(Fail);
    };
    if p.at(TokenKind::Comma) {
        read_tuple_expr(p, child(depth))?;
    }
    p.expect(TokenKind::RParen)?;
    Ok(finish_paren(p, start, inner))
}
fn finish_paren(p: &mut Parser, start: usize, inner: Box<Expr>) -> Box<Expr> {
    Box::new(Expr::Paren(ParenExpr {
        id: p.node_id(),
        span: p.span_from(start),
        inner,
    }))
}
fn read_tuple_expr(p: &mut Parser, depth: u32) -> PResult<()> {
    let span = p.peek().span;
    let mut count = 1_usize;
    while p.eat(TokenKind::Comma) {
        if p.at(TokenKind::RParen) {
            break;
        }
        drop(parse_expr(p, depth)?);
        count = count.saturating_add(1);
    }
    patterns_ext::report_tuple(p, count, span);
    Ok(())
}
fn parse_args(p: &mut Parser, depth: u32) -> PResult<Vec<Arg>> {
    p.bump();
    comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RParen,
            element: text::EXPRESSION,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: true,
        },
        push_arg,
        |out, node| out.push(Arg::Expr(Expr::Error(node))),
    )
}
fn push_arg(p: &mut Parser, depth: u32, out: &mut Vec<Arg>) -> PResult<()> {
    p.enter(depth)?;
    if p.at(TokenKind::Underscore)
        && matches!(p.peek_nth_kind(1), TokenKind::Comma | TokenKind::RParen)
    {
        let span = p.bump().span;
        out.push(Arg::Placeholder(PlaceholderArg {
            id: p.node_id(),
            span,
        }));
    } else {
        let Ok(expr) = parse_expr(p, depth) else {
            return Err(Fail);
        };
        out.push(Arg::Expr(*expr));
    }
    Ok(())
}
fn parse_list(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    p.bump();
    let elems = comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RBracket,
            element: text::EXPRESSION,
            separator: text::COMMA_OR_RBRACKET,
            allow_empty: true,
            indexed: true,
        },
        push_list_elem,
        |out, e| out.push(ListElem::Expr(Expr::Error(e))),
    )?;
    Ok(finish_list(p, start, elems))
}
fn push_list_elem(p: &mut Parser, depth: u32, out: &mut Vec<ListElem>) -> PResult<()> {
    if p.at(TokenKind::DotDot) || p.at(TokenKind::Star) {
        return spread::parse_spread_elem(p, depth, out);
    }
    let Ok(expr) = parse_expr(p, depth) else {
        return Err(Fail);
    };
    out.push(ListElem::Expr(*expr));
    Ok(())
}
fn finish_list(p: &mut Parser, start: usize, elems: Vec<ListElem>) -> Box<Expr> {
    let list = ListExpr {
        id: p.node_id(),
        span: p.span_from(start),
        elems,
    };
    spread::check_list_spreads(p, &list);
    Box::new(Expr::List(list))
}

/// ブロックを終える語。`WithCase` は F04 の `handle` の本体で使う。
#[derive(Clone, Copy)]
pub(super) enum BlockEnd {
    End,
    Else,
    Arm,
    WithCase,
}
fn block_end(p: &Parser, end: BlockEnd) -> bool {
    if p.at(TokenKind::KwEnd) || p.at(TokenKind::Eof) || p.symbol("}") {
        return true;
    }
    match end {
        BlockEnd::End => false,
        BlockEnd::Else => p.at(TokenKind::KwElse),
        BlockEnd::Arm => {
            p.at(TokenKind::KwCase)
                || foreign::when_ahead(p)
                || p.word("default") && p.peek_nth_kind(1) == TokenKind::Colon
                || p.at(TokenKind::Comma)
        }
        BlockEnd::WithCase => {
            p.at(TokenKind::KwWith)
                && (p.peek_nth_kind(1) == TokenKind::KwCase
                    || p.peek_nth_kind(1) == TokenKind::Newline
                    || legacy_clause_after_with(p))
        }
    }
}
fn legacy_clause_after_with(p: &Parser) -> bool {
    // F04 の旧式の節を診断するため、foreign::when_ahead と同じく括弧の外の ':'
    // まで確かめる。リソースの束縛や when の呼び出しとは区別する（実装プラン F04）。
    if !p.tokens.get(p.pos.saturating_add(1)).is_some_and(
        |t| matches!(&t.value, crate::syntax::token::TokenValue::Ident(s) if s == "when"),
    ) {
        return false;
    }
    let mut nesting = 0_u32;
    for token in p.tokens.get(p.pos.saturating_add(2)..).unwrap_or_default() {
        if nesting == 0 && token.kind == TokenKind::Colon {
            return true;
        }
        if nesting == 0
            && matches!(
                token.kind,
                TokenKind::Newline
                    | TokenKind::KwEnd
                    | TokenKind::Eof
                    | TokenKind::Arrow
                    | TokenKind::Eq
            )
        {
            return false;
        }
        if matches!(token.kind, TokenKind::LParen | TokenKind::LBracket) {
            nesting = nesting.saturating_add(1);
        } else if matches!(token.kind, TokenKind::RParen | TokenKind::RBracket) {
            nesting = nesting.saturating_sub(1);
        }
    }
    false
}
pub(super) fn parse_block(p: &mut Parser, depth: u32, end: BlockEnd) -> PResult<Box<Block>> {
    p.enter(depth)?;
    p.skip_newlines();
    let start = p.pos;
    let mut stmts = Vec::new();
    let mut index = 0_usize;
    while !block_end(p, end) && !p.aborted {
        let from = p.pos;
        let saved = p.ctx;
        let open = p.blocks.len();
        if matches!(end, BlockEnd::Arm)
            && p.word("break")
            && matches!(
                p.peek_nth_kind(1),
                TokenKind::Newline | TokenKind::KwEnd | TokenKind::Eof
            )
        {
            consume_break(p);
        } else if push_stmt(p, nth_child(depth, index), &mut stmts).is_err() {
            if p.aborted {
                return Err(Fail);
            }
            recover_statement(p, from, &mut stmts);
            p.blocks.truncate(open);
        }
        p.ctx = saved;
        index = index.saturating_add(1);
        if p.pos == from {
            p.advance();
        }
        if p.symbol(";") {
            p.bump();
        } else if !p.at(TokenKind::Newline) && !block_end(p, end) {
            p.unexpected(text::NEWLINE_OR_END);
            p.recover(p.pos, Recovery::Line);
        }
        p.skip_newlines();
    }
    Ok(finish_block(p, start, stmts))
}
fn push_stmt(p: &mut Parser, depth: u32, out: &mut Vec<Stmt>) -> PResult<()> {
    p.enter(depth)?;
    if p.at(TokenKind::KwBind)
        || p.at(TokenKind::KwShadow)
        || p.word("let")
            && matches!(
                p.peek_nth_kind(1),
                TokenKind::LowerIdent | TokenKind::Underscore | TokenKind::UpperIdent
            )
    {
        return push_bind(p, depth, out);
    }
    if p.word("switch")
        && !matches!(
            p.peek_nth_kind(1),
            TokenKind::LParen | TokenKind::Newline | TokenKind::KwEnd
        )
    {
        push_switch(p, depth, out);
        return Ok(());
    }
    push_expr_statement(p, depth, out)
}
fn push_expr_statement(p: &mut Parser, depth: u32, out: &mut Vec<Stmt>) -> PResult<()> {
    let Ok(expr) = parse_expr(p, depth) else {
        return Err(Fail);
    };
    push_expr(out, expr);
    Ok(())
}
fn push_expr(out: &mut Vec<Stmt>, expr: Box<Expr>) {
    out.push(Stmt::Expr(*expr));
}
fn recover_statement(p: &mut Parser, start: usize, out: &mut Vec<Stmt>) {
    p.recover(start, Recovery::Line);
    out.push(Stmt::Error(p.error_node_from(start)));
}
fn finish_block(p: &mut Parser, start: usize, stmts: Vec<Stmt>) -> Box<Block> {
    let span = stmts.first().zip(stmts.last()).map_or_else(
        || p.empty_span(),
        |(first, last)| first.span().to(last.span()),
    );
    let _ = start;
    Box::new(Block {
        id: p.node_id(),
        span,
        stmts,
    })
}
fn consume_break(p: &mut Parser) {
    let span = p.bump().span;
    p.report(
        DiagBuilder::new(DiagCode::E0240)
            .primary(span)
            .help_edits(
                "remove",
                vec![Edit {
                    span,
                    replacement: String::new(),
                }],
            )
            .build(),
    );
}
fn push_switch(p: &mut Parser, depth: u32, out: &mut Vec<Stmt>) {
    let start = p.pos;
    let span = p.bump().span;
    let value = parse_expr(p, child(depth)).ok();
    p.report(
        DiagBuilder::new(DiagCode::E0239)
            .arg("word", p.snippet(span))
            .arg(
                "value",
                value
                    .as_ref()
                    .map_or_else(String::new, |e| p.snippet(e.span())),
            )
            .primary(span)
            .help("switch")
            .build(),
    );
    recover_statement(p, start, out);
}
fn push_bind(p: &mut Parser, depth: u32, out: &mut Vec<Stmt>) -> PResult<()> {
    let start = p.pos;
    let old = p.word("let");
    let mode = if p.at(TokenKind::KwShadow) {
        BindMode::Shadow
    } else {
        BindMode::Bind
    };
    let keyword_span = p.bump().span;
    let mut counter = PatternCounter::new(depth);
    let pattern = patterns::parse_pattern(p, &mut counter)?;
    let ty = if p.eat(TokenKind::Colon) {
        Some(types::parse_type(p, child(depth))?)
    } else {
        None
    };
    p.expect(if old {
        TokenKind::Eq
    } else {
        TokenKind::LeftArrow
    })?;
    let value = parse_expr(p, child(depth))?;
    if old {
        p.report(
            DiagBuilder::new(DiagCode::E0230)
                .arg("name", p.snippet(pattern_span(&pattern)))
                .arg("value", p.snippet(span_of(&value)))
                .primary(keyword_span)
                .help("bind")
                .help("shadow")
                .build(),
        );
    }
    finish_bind(p, start, (mode, keyword_span), *pattern, ty, value, out);
    Ok(())
}
fn finish_bind(
    p: &mut Parser,
    start: usize,
    header: (BindMode, Span),
    pattern: Pattern,
    ty: Option<Box<TypeExpr>>,
    value: Box<Expr>,
    out: &mut Vec<Stmt>,
) {
    out.push(Stmt::Bind(Box::new(BindStmt {
        id: p.node_id(),
        span: p.span_from(start),
        mode: header.0,
        keyword_span: header.1,
        pattern,
        ty: ty.map(|t| *t),
        value: *value,
    })));
}

fn parse_if(p: &mut Parser, depth: u32, close: bool) -> PResult<Box<Expr>> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    if close {
        p.open_block(TokenKind::KwIf, opened);
    }
    let Ok(cond) = parse_expr(p, child(depth)) else {
        return Err(Fail);
    };
    let braces = p.symbol("{");
    if braces {
        p.bump();
    } else {
        p.expect(TokenKind::KwThen)?;
    }
    let Ok(then_block) = parse_block(p, child(depth), BlockEnd::Else) else {
        return Err(Fail);
    };
    if braces && p.symbol("}") && p.peek_nth_kind(1) == TokenKind::KwElse {
        p.bump();
    }
    let Ok(else_branch) = parse_else(p, depth) else {
        return Err(Fail);
    };
    if close {
        p.close_block(TokenKind::KwIf);
    }
    Ok(finish_if(p, start, cond, *then_block, else_branch))
}
fn parse_else(p: &mut Parser, depth: u32) -> PResult<Option<Box<ElseBranch>>> {
    if !p.eat(TokenKind::KwElse) {
        return Ok(None);
    }
    if p.at(TokenKind::KwIf) {
        let Ok(branch) = parse_if(p, child(depth), false) else {
            return Err(Fail);
        };
        return Ok(Some(finish_else_if(branch)?));
    }
    if p.symbol("{") {
        p.bump();
    }
    let Ok(block) = parse_block(p, child(depth), BlockEnd::End) else {
        return Err(Fail);
    };
    Ok(Some(Box::new(ElseBranch::Block(*block))))
}
fn finish_else_if(expr: Box<Expr>) -> PResult<Box<ElseBranch>> {
    let Expr::If(branch) = *expr else {
        return Err(Fail);
    };
    Ok(Box::new(ElseBranch::If(Box::new(branch))))
}
fn finish_if(
    p: &mut Parser,
    start: usize,
    cond: Box<Expr>,
    then_block: Block,
    else_branch: Option<Box<ElseBranch>>,
) -> Box<Expr> {
    Box::new(Expr::If(IfExpr {
        id: p.node_id(),
        span: p.span_from(start),
        cond,
        then_block,
        else_branch: else_branch.map(|b| *b),
    }))
}
fn parse_lambda(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let opened = p.bump().span;
    if p.at(TokenKind::LowerIdent) {
        return foreign_lambda(p, start, depth);
    }
    let params = decls::parse_params(p, depth, true)?;
    let ret = if p.at(TokenKind::Arrow) || p.at(TokenKind::Colon) {
        foreign::return_arrow(p)?;
        Some(types::parse_type(p, child(depth))?)
    } else {
        None
    };
    let uses = if ret.is_some() {
        types::parse_uses(p, depth)?
    } else {
        None
    };
    let saved = p.ctx;
    if p.ctx.clause == ClauseContext::Direct {
        p.ctx.clause = ClauseContext::Blocked;
    }
    p.ctx.escape = EscapeContext::Allowed;
    p.ctx.in_arm_head = false;
    p.open_block(TokenKind::KwLambda, opened);
    let body = parse_block(p, child(depth), BlockEnd::End);
    p.ctx = saved;
    let Ok(body) = body else {
        return Err(Fail);
    };
    p.close_block(TokenKind::KwLambda);
    Ok(finish_lambda(p, start, params, ret, uses, *body))
}
fn finish_lambda(
    p: &mut Parser,
    start: usize,
    params: Vec<Param>,
    ret: Option<Box<TypeExpr>>,
    uses: Option<UsesList>,
    body: Block,
) -> Box<Expr> {
    Box::new(Expr::Lambda(LambdaExpr {
        id: p.node_id(),
        span: p.span_from(start),
        params,
        ret: ret.map(|t| *t),
        uses,
        body,
    }))
}
fn parse_match(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let opened = p.bump().span;
    p.open_block(TokenKind::KwMatch, opened);
    let Ok(scrutinee) = parse_expr(p, child(depth)) else {
        return Err(Fail);
    };
    if p.at(TokenKind::Newline) && p.peek_nth_kind(1) == TokenKind::KwWith {
        let gap = Span {
            start: span_of(&scrutinee).end,
            end: p
                .tokens
                .get(p.pos.saturating_add(1))
                .map_or(p.peek().span.start, |t| t.span.start),
            file: p.file,
        };
        let primary = p
            .tokens
            .get(p.pos.saturating_add(1))
            .map_or(p.peek().span, |t| t.span);
        p.report(
            DiagBuilder::new(DiagCode::E0215)
                .primary(primary)
                .help_edits(
                    "same_line",
                    vec![Edit {
                        span: gap,
                        replacement: " ".to_owned(),
                    }],
                )
                .build(),
        );
        p.advance();
    }
    let braces = p.symbol("{");
    if braces {
        p.bump();
    } else {
        p.expect(TokenKind::KwWith)?;
    }
    let mut arms = Vec::new();
    let mut counter = PatternCounter::new(depth);
    let mut index = 0_usize;
    p.skip_newlines();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.symbol("}") && !p.aborted {
        if index > 0 && !braces && !p.at_line_start() {
            p.unexpected(text::NEWLINE_OR_END);
        }
        let from = p.pos;
        let saved = p.ctx;
        let open = p.blocks.len();
        if push_arm(p, nth_child(depth, index), &mut counter, &mut arms).is_err() {
            if p.aborted {
                return Err(Fail);
            }
            p.recover(from, Recovery::Line);
            p.blocks.truncate(open);
        }
        p.ctx = saved;
        if p.pos == from {
            p.advance();
        }
        index = index.saturating_add(1);
        if p.at(TokenKind::Comma) {
            p.bump();
        }
        p.skip_newlines();
    }
    if arms.is_empty() && index == 0 && !p.aborted {
        p.unexpected(text::ARM);
    }
    p.close_block(TokenKind::KwMatch);
    Ok(finish_match(p, start, scrutinee, arms))
}
fn finish_match(
    p: &mut Parser,
    start: usize,
    scrutinee: Box<Expr>,
    arms: Vec<MatchArm>,
) -> Box<Expr> {
    Box::new(Expr::Match(MatchExpr {
        id: p.node_id(),
        span: p.span_from(start),
        scrutinee,
        arms,
    }))
}
fn push_arm(
    p: &mut Parser,
    depth: u32,
    counter: &mut PatternCounter,
    out: &mut Vec<MatchArm>,
) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let saved = p.ctx;
    p.ctx.in_arm_head = true;
    let when = foreign::take_when(p);
    let default = p.word("default") && p.peek_nth_kind(1) == TokenKind::Colon;
    let case = when.is_some() || p.eat(TokenKind::KwCase);
    let pattern_start = p.pos;
    let first = if default {
        let span = p.bump().span;
        p.report(
            DiagBuilder::new(DiagCode::E0239)
                .arg("word", p.snippet(span))
                .primary(span)
                .help("default")
                .build(),
        );
        Box::new(Pattern::Wildcard(WildcardPat {
            id: p.node_id(),
            span,
        }))
    } else {
        patterns::parse_pattern(p, counter)?
    };
    let pattern_span = p.span_from(pattern_start);
    if let Some(span) = when {
        foreign::report_when(p, span, pattern_span);
    } else if !case && !default {
        p.report(
            DiagBuilder::new(DiagCode::E0238)
                .arg("pattern", p.snippet(pattern_span))
                .primary(pattern_span)
                .help("case")
                .build(),
        );
    }
    let (patterns, guard) = patterns_ext::parse_arm_head_rest(p, *first, counter, depth)?;
    if p.symbol("=>") {
        foreign::operator(p, "fat_arrow", None);
        p.bump();
    } else if (when.is_some() || default) && p.at(TokenKind::Colon) {
        p.bump();
    } else if p.at(TokenKind::Comma) {
        // F04 の仮の本体がまだ読まない選択肢は、矢印まで回復して一つの誤りで続ける。
        p.unexpected(text::token_name(TokenKind::Arrow));
        while !p.at(TokenKind::Arrow)
            && !p.at(TokenKind::Newline)
            && !p.at(TokenKind::KwEnd)
            && !p.at(TokenKind::Eof)
        {
            p.advance();
        }
        if p.at(TokenKind::Arrow) {
            p.advance();
        }
    } else {
        p.expect(TokenKind::Arrow)?;
    }
    p.ctx.in_arm_head = false;
    p.skip_newlines();
    if block_end(p, BlockEnd::Arm) {
        p.unexpected(text::STATEMENT);
    }
    let body = parse_block(p, child(depth), BlockEnd::Arm);
    p.ctx = saved;
    let Ok(body) = body else {
        return Err(Fail);
    };
    finish_arm(p, start, patterns, guard, *body, out);
    Ok(())
}
fn finish_arm(
    p: &mut Parser,
    start: usize,
    patterns: Vec<Pattern>,
    guard: Option<Box<Expr>>,
    body: Block,
    out: &mut Vec<MatchArm>,
) {
    let span = p
        .tokens
        .get(start)
        .map_or(body.span, |t| t.span.to(body.span));
    out.push(MatchArm {
        id: p.node_id(),
        span,
        patterns,
        guard,
        body,
    });
}
fn foreign_case(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let keyword = p.bump().span;
    let value = parse_expr(p, child(depth))?;
    if !p.word("of") {
        return Err(p.unexpected(text::EXPRESSION));
    }
    p.report(
        DiagBuilder::new(DiagCode::E0231)
            .arg("value", p.snippet(span_of(&value)))
            .primary(keyword)
            .help("match_with")
            .build(),
    );
    // 同じブロックの end case がある場合だけそこまで飛ばす。外側の end は消費しない。
    let close = foreign_case_end(p);
    if let Some(close) = close {
        while p.pos < close.saturating_add(2) && !p.at(TokenKind::Eof) {
            p.advance();
        }
    } else {
        p.recover(p.pos, Recovery::Line);
    }
    Ok(Box::new(Expr::Error(p.error_node_from(start))))
}
fn foreign_case_end(p: &Parser) -> Option<usize> {
    let mut nesting = Vec::new();
    let mut previous = TokenKind::Eof;
    for (offset, token) in p.tokens.get(p.pos..).unwrap_or_default().iter().enumerate() {
        if nesting.is_empty() && token.kind == TokenKind::KwEnd {
            let index = p.pos.saturating_add(offset);
            return (p
                .tokens
                .get(index.saturating_add(1))
                .is_some_and(|t| t.kind == TokenKind::KwCase))
            .then_some(index);
        }
        super::recovery_nesting(&mut nesting, token.kind, previous);
        previous = token.kind;
    }
    None
}
fn foreign_lambda(p: &mut Parser, start: usize, depth: u32) -> PResult<Box<Expr>> {
    let param_start = p.pos;
    let mut params = Vec::new();
    loop {
        let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
        params.push(Param {
            id: p.node_id(),
            span: name.span,
            name,
            ty: None,
        });
        if !p.eat(TokenKind::Comma) {
            break;
        }
    }
    let params_span = p.span_from(param_start);
    p.expect(TokenKind::Colon)?;
    let value = parse_expr(p, child(depth))?;
    p.report(
        DiagBuilder::new(DiagCode::E0243)
            .arg("params", p.snippet(params_span))
            .arg("body", p.snippet(span_of(&value)))
            .primary(p.span_from(start))
            .help("lambda")
            .build(),
    );
    let body = foreign_lambda_body(p, value);
    Ok(finish_lambda(p, start, params, None, None, *body))
}
fn foreign_lambda_body(p: &mut Parser, value: Box<Expr>) -> Box<Block> {
    let span = span_of(&value);
    let ret = Expr::Return(ReturnExpr {
        id: p.node_id(),
        span,
        value,
    });
    Box::new(Block {
        id: p.node_id(),
        span,
        stmts: vec![Stmt::Expr(ret)],
    })
}

pub(super) fn span_of(expr: &Expr) -> Span {
    match expr {
        Expr::Lit(e) => e.span,
        Expr::Interp(e) => e.span,
        Expr::Name(e) => e.span,
        Expr::Unit(e) => e.span,
        Expr::Paren(e) => e.span,
        Expr::List(e) => e.span,
        Expr::Call(e) => e.span,
        Expr::Record(e) => e.span,
        Expr::Binary(e) => e.span,
        Expr::Unary(e) => e.span,
        Expr::Pipe(e) => e.span,
        Expr::If(e) => e.span,
        Expr::Match(e) => e.span,
        Expr::Lambda(e) => e.span,
        Expr::Return(e) => e.span,
        Expr::Try(e) => e.span,
        Expr::Lazy(e) => e.span,
        Expr::With(e) => e.span,
        Expr::Handle(e) => e.span,
        Expr::Resume(e) => e.span,
        Expr::Error(e) => e.span,
    }
}
pub(super) fn pattern_span(pattern: &Pattern) -> Span {
    match pattern {
        Pattern::Wildcard(p) => p.span,
        Pattern::Var(p) => p.span,
        Pattern::Lit(p) => p.span,
        Pattern::Unit(p) => p.span,
        Pattern::Ctor(p) => p.span,
        Pattern::Record(p) => p.span,
        Pattern::Range(p) => p.span,
        Pattern::List(p) => p.span,
        Pattern::Error(p) => p.span,
    }
}
