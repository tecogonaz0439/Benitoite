//! 式の解析（設計書 02-03「構文解析の方式」「構文の規則に伴う次の診断」「AST」「入れ子の深さ」、
//! 01-02「文法」の式の規則）。
//!
//! 演算子は、02-03 の演算子の表の左右の強さを使う Pratt 法（Pratt parsing）で読む（ADR 0020）。
//! 一つの繰り返し（`parse_bp`）が、中置の演算子と、後置の演算子として扱う呼び出し `(...)` を読む。
//! 前置の `-` と `!` は、右の強さ 70 でオペランドを読む。
//!
//! パイプ、プレースホルダを含む呼び出し、括弧の式、`else if` の連なりは、書かれた形のまま AST に残す
//! （02-03「AST」）。展開は型検査器と脱糖の段が行う。
//!
//! 入れ子の深さ: 左結合の演算子の連なりと呼び出しの連なりは繰り返しで読むが、できる木は左に深くなる
//! （02-03「入れ子の深さ」）。演算子を一つ重ねるたびに、それまでに作った木のノードがすべて 1 段深くなる。
//! そこで、木の中で最も深いノードの深さ（`height`）を持ち歩き、演算子と呼び出しを一つ作るたびに
//! 上限を確かめる。オペランドの中の深さは、`Parser::enter` が記録する最大の深さ（`Parser::deepest`）で測る。
//! 作った演算子の数だけを足すと、最初のオペランドの中の入れ子の深さと、その後に重ねた演算子の数とが
//! 足し合わされず、実際の木の深さが上限を超えても見逃すからである（`((a + b) + c) + d` の形を
//! 何段も重ねると、どの繰り返しの演算子の数も小さいまま、木はいくらでも深くなる）。
//!
//! スタックの使い方（`parser` の「スタックの使い方」）: 再帰の経路にある関数は、式を `Box<Expr>` で
//! 受け渡し、大きなノードの組み立てを別の関数（`finish_*`）に分ける。`Result` に `?` を使わず
//! `let ... else` で書くのも、最適化しないビルドで一時の値を減らすためである。

use super::pattern::{self, PatternCounter};
use super::text;
use super::{
    CommaList, Fail, PResult, Parser, child, comma_list, line_list, literal_of, name_of, stmt,
    types,
};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{
    Arg, BinOp, BinaryExpr, Block, CallExpr, ElseBranch, Expr, IfExpr, LambdaExpr, ListExpr,
    LitExpr, MatchArm, MatchExpr, NameExpr, Param, ParenExpr, Pattern, PipeExpr, PlaceholderArg,
    TypeExpr, UnOp, UnaryExpr, UnitExpr, UsesList,
};
use crate::syntax::token::TokenKind;

// ---------------- 演算子の表（02-03「構文解析の方式」） ----------------

/// 中置の演算子の種類。`|>` は二項演算ではなくパイプのノードにする（02-03「AST」）。
#[derive(Clone, Copy, Debug)]
enum Infix {
    Bin(BinOp),
    Pipe,
}

/// 中置の演算子の表。字句、演算子、左の強さ、右の強さ。数が大きいほど強く結合する。
/// 右の強さを左の強さより 1 大きくして、左結合にする。比較演算子は結合しないが、表の上では
/// 左結合と同じ強さにし、連なりを `check_chained_comparison` で診断する。
const INFIX_OPS: &[(TokenKind, Infix, u8, u8)] = &[
    (TokenKind::PipeGt, Infix::Pipe, 10, 11),
    (TokenKind::OrOr, Infix::Bin(BinOp::Or), 20, 21),
    (TokenKind::AndAnd, Infix::Bin(BinOp::And), 30, 31),
    (TokenKind::EqEq, Infix::Bin(BinOp::Eq), 40, 41),
    (TokenKind::BangEq, Infix::Bin(BinOp::Ne), 40, 41),
    (TokenKind::Lt, Infix::Bin(BinOp::Lt), 40, 41),
    (TokenKind::Le, Infix::Bin(BinOp::Le), 40, 41),
    (TokenKind::Gt, Infix::Bin(BinOp::Gt), 40, 41),
    (TokenKind::Ge, Infix::Bin(BinOp::Ge), 40, 41),
    (TokenKind::Plus, Infix::Bin(BinOp::Add), 50, 51),
    (TokenKind::Minus, Infix::Bin(BinOp::Sub), 50, 51),
    (TokenKind::Star, Infix::Bin(BinOp::Mul), 60, 61),
    (TokenKind::Slash, Infix::Bin(BinOp::Div), 60, 61),
    (TokenKind::Percent, Infix::Bin(BinOp::Rem), 60, 61),
];

/// 前置の `-` と `!` の右の強さ。
const PREFIX_BP: u8 = 70;

/// 後置の演算子（呼び出し）の左の強さ。値に続けたドットの検出も、同じ強さの後置の位置で行う。
const CALL_BP: u8 = 80;

fn infix_of(kind: TokenKind) -> Option<(Infix, u8, u8)> {
    INFIX_OPS
        .iter()
        .find(|(k, _, _, _)| *k == kind)
        .map(|(_, infix, lbp, rbp)| (*infix, *lbp, *rbp))
}

fn is_comparison_op(op: BinOp) -> bool {
    matches!(
        op,
        BinOp::Eq | BinOp::Ne | BinOp::Lt | BinOp::Le | BinOp::Gt | BinOp::Ge
    )
}

// ---------------- 入口 ----------------

/// 式を一つ読む。`depth` は式のノードの深さである。
///
/// 構文エラーのときは、報告して誤りの式を返す（回復は文などの並びの解析に任せる）。
/// 打ち切ったときも誤りの式を返すので、呼び出し側は `Parser::aborted` を確かめる。
///
/// 一次式だけからなる式（ブロックの文に書いたブロックなど）は、演算子の繰り返し（`continue_bp`）を
/// 通さずに返す。ブロックの入れ子の再帰の経路から繰り返しの関数の枠を除き、スタックを節約するためである
/// （`parser` の「スタックの使い方」）。
pub(super) fn parse_expr(p: &mut Parser, depth: u32) -> Expr {
    let outer = p.deepest;
    p.deepest = 0;
    let start = p.pos;
    let Ok(lhs) = parse_primary(p, depth) else {
        p.deepest = outer;
        return error_expr(p, start);
    };
    if next_step(p, 0).is_none() {
        p.deepest = p.deepest.max(depth).max(outer);
        return unbox(lhs);
    }
    let Ok(expr) = continue_bp(p, depth, 0, start, outer, lhs) else {
        return error_expr(p, start);
    };
    unbox(expr)
}

// 次の関数は、式の値を呼び出し元の枠に直接作るためのものである（`parser` の「スタックの使い方」）。
fn unbox(expr: Box<Expr>) -> Expr {
    *expr
}

fn error_expr(p: &mut Parser, start: usize) -> Expr {
    Expr::Error(p.error_node_from(start))
}

/// 期待どおりの字句を一つ読み、その位置を返す。字句の値を再帰の経路の関数の枠に置かないために分ける。
fn bump_span(p: &mut Parser) -> Span {
    p.bump().span
}

/// 次の字句が `kind` なら読み進める。そうでなければ E0201 を報告して失敗する。
fn expect_kind(p: &mut Parser, kind: TokenKind) -> PResult<()> {
    p.expect(kind).map(|_| ())
}

// ---------------- Pratt 法 ----------------

/// 繰り返しの一歩で読む後置・中置の演算子。
#[derive(Clone, Copy, Debug)]
enum Step {
    /// 呼び出し `(...)`
    Call,
    /// 値に続けたドット（E0203）
    Dot,
    /// 中置の演算子と右の強さ
    Infix(Infix, u8),
}

/// 今の字句が、強さ `min_bp` の繰り返しで読む演算子なら、その一歩を返す。
fn next_step(p: &Parser, min_bp: u8) -> Option<Step> {
    let kind = p.peek_kind();
    if kind == TokenKind::LParen {
        return (CALL_BP >= min_bp).then_some(Step::Call);
    }
    if kind == TokenKind::Dot {
        return (CALL_BP >= min_bp).then_some(Step::Dot);
    }
    let (infix, lbp, rbp) = infix_of(kind)?;
    (lbp >= min_bp).then_some(Step::Infix(infix, rbp))
}

/// 左の強さが `min_bp` 以上の演算子を読む間、式を読む。`depth` は、でき上がる式の根のノードの深さである。
///
/// 読み始めのオペランドは深さ `depth` として読み、演算子や呼び出しを重ねるたびに、木の中で最も深い
/// ノードの深さ `height` を 1 増やして上限を確かめる（モジュールの先頭の「入れ子の深さ」）。
/// 終わるときに、呼び出し元が測っている最大の深さ（`Parser::deepest`）に `height` を合わせる。
fn parse_bp(p: &mut Parser, depth: u32, min_bp: u8) -> PResult<Box<Expr>> {
    let outer = p.deepest;
    p.deepest = 0;
    let start = p.pos;
    let Ok(lhs) = parse_primary(p, depth) else {
        p.deepest = outer;
        return Err(Fail);
    };
    continue_bp(p, depth, min_bp, start, outer, lhs)
}

/// `parse_bp` の、読み始めのオペランド `lhs` を読んだ後の繰り返し。`start` は `lhs` の始まりの字句の位置、
/// `outer` は呼び出し元が測っていた最大の深さ。`Parser::deepest` は `lhs` の中の最大の深さを持っている。
fn continue_bp(
    p: &mut Parser,
    depth: u32,
    min_bp: u8,
    start: usize,
    outer: u32,
    mut lhs: Box<Expr>,
) -> PResult<Box<Expr>> {
    let mut height = p.deepest.max(depth);
    while let Some(step) = next_step(p, min_bp) {
        p.deepest = 0;
        let Ok(next) = apply_step(p, start, depth, step, lhs) else {
            p.deepest = outer;
            return Err(Fail);
        };
        lhs = next;
        let Some(next_height) = after_step(p, step, height) else {
            p.deepest = outer;
            return Err(Fail);
        };
        height = next_height;
    }
    p.deepest = height.max(outer);
    Ok(lhs)
}

/// 演算子か呼び出しを一つ重ねた後の処理。重ねた後の木の中で最も深いノードの深さを返し、
/// 上限を超えたら `None` を返す。
fn after_step(p: &mut Parser, step: Step, height: u32) -> Option<u32> {
    match step {
        // 木の形は変わらない。
        Step::Dot => Some(height.max(p.deepest)),
        Step::Call | Step::Infix(..) => {
            // 重ねる前の木は 1 段深くなる。新しいオペランド（引数）の深さは、根を `depth` として測ってある。
            let height = child(height).max(p.deepest);
            p.enter(height).ok()?;
            if let Step::Infix(Infix::Bin(op), _) = step {
                check_chained_comparison(p, op);
            }
            Some(height)
        }
    }
}

/// 演算子か呼び出しを一つ読み、`lhs` に重ねた式を返す。`start` は `lhs` の始まりの字句の位置。
fn apply_step(
    p: &mut Parser,
    start: usize,
    depth: u32,
    step: Step,
    lhs: Box<Expr>,
) -> PResult<Box<Expr>> {
    match step {
        Step::Call => apply_call(p, start, depth, lhs),
        Step::Infix(infix, rbp) => apply_infix(p, start, depth, infix, rbp, lhs),
        Step::Dot => Ok(skip_dot(p, start, lhs)),
    }
}

fn apply_call(p: &mut Parser, start: usize, depth: u32, callee: Box<Expr>) -> PResult<Box<Expr>> {
    let Ok(args) = parse_args(p, depth) else {
        return Err(Fail);
    };
    Ok(finish_call(p, start, callee, args))
}

fn apply_infix(
    p: &mut Parser,
    start: usize,
    depth: u32,
    infix: Infix,
    rbp: u8,
    lhs: Box<Expr>,
) -> PResult<Box<Expr>> {
    let op_span = bump_span(p);
    let Ok(rhs) = parse_bp(p, child(depth), rbp) else {
        return Err(Fail);
    };
    Ok(finish_infix(p, start, infix, op_span, lhs, rhs))
}

fn finish_call(p: &mut Parser, start: usize, callee: Box<Expr>, args: Vec<Arg>) -> Box<Expr> {
    Box::new(Expr::Call(CallExpr {
        id: p.node_id(),
        span: p.span_from(start),
        callee,
        args,
    }))
}

fn finish_infix(
    p: &mut Parser,
    start: usize,
    infix: Infix,
    op_span: Span,
    lhs: Box<Expr>,
    rhs: Box<Expr>,
) -> Box<Expr> {
    let id = p.node_id();
    let span = p.span_from(start);
    Box::new(match infix {
        Infix::Bin(op) => Expr::Binary(BinaryExpr {
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

/// 比較の右のオペランドを読んだ直後に、また比較演算子が来たら、その演算子の位置に E0202 を報告する
/// （02-03「構文解析の方式」）。回復として、呼び出し元は左結合として読み続ける（実装プラン T12 の決定）。
fn check_chained_comparison(p: &mut Parser, op: BinOp) {
    if !is_comparison_op(op) {
        return;
    }
    let next_is_comparison = matches!(
        infix_of(p.peek_kind()),
        Some((Infix::Bin(next), _, _)) if is_comparison_op(next)
    );
    if !next_is_comparison {
        return;
    }
    let diagnostic = DiagBuilder::new(DiagCode::E0202)
        .primary(p.peek().span)
        .help("and")
        .build();
    p.report(diagnostic);
}

/// 値に続けたドット（`xs.map(f)`、`s.length`）を E0203 で報告し、`.` とその後の識別子を読み飛ばす
/// （01-02「ドット記法」）。主な位置は `.` から名前の終わりまでである。
///
/// 読み飛ばした範囲は誤りのノードで表す（02-03「誤りからの回復」）。AST には値とドットの後の名前を
/// 並べて置く場所がないので、値 `lhs` とドットと名前をまとめて一つの誤りの式に置き換える
/// （`start` は `lhs` の始まりの字句の位置）。続く `(...)` は、呼び出し元の繰り返しがこの誤りの式の
/// 呼び出しとして読む（`xs.map(f)` は `Call(Error(xs.map), f)` になる）。
fn skip_dot(p: &mut Parser, start: usize, lhs: Box<Expr>) -> Box<Expr> {
    drop(lhs);
    let dot = p.peek().span;
    // 期待どおりの字句ではないので、報告の抑制を解かずに読む。
    p.advance();
    let span = if matches!(p.peek_kind(), TokenKind::LowerIdent | TokenKind::UpperIdent) {
        let name = p.advance().span;
        dot.to(name)
    } else {
        dot
    };
    let diagnostic = DiagBuilder::new(DiagCode::E0203)
        .primary(span)
        .help("pipe")
        .build();
    p.report(diagnostic);
    Box::new(Expr::Error(p.error_node_from(start)))
}

// ---------------- 呼び出しの引数 ----------------

/// `"(" CommaList(Arg) ")"`。i 番目の引数は、呼び出しの深さに `i + 1` を加えた深さで解析する
/// （02-03「入れ子の深さ」）。
fn parse_args(p: &mut Parser, depth: u32) -> PResult<Vec<Arg>> {
    let _: Span = bump_span(p);
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
        parse_arg,
        |out, node| out.push(Arg::Expr(Expr::Error(node))),
    )
}

/// `Arg = Expr | "_"`。呼び出しの直接の引数に書いた `_` だけがプレースホルダである
/// （01-02「部分適用のプレースホルダ」）。`_ + 1` のように `_` の後に式が続けば式として読み、
/// その `_` は一次式の位置の `_` として E0204 になる。読んだ引数を `out` に加える。
fn parse_arg(p: &mut Parser, depth: u32, out: &mut Vec<Arg>) -> PResult<()> {
    if p.at(TokenKind::Underscore)
        && matches!(p.peek_nth_kind(1), TokenKind::Comma | TokenKind::RParen)
    {
        if p.enter(depth).is_err() {
            return Err(Fail);
        }
        push_placeholder(p, out);
        return Ok(());
    }
    let Ok(expr) = parse_bp(p, depth, 0) else {
        return Err(Fail);
    };
    push_arg(out, expr);
    Ok(())
}

fn push_arg(out: &mut Vec<Arg>, expr: Box<Expr>) {
    out.push(Arg::Expr(*expr));
}

fn push_placeholder(p: &mut Parser, out: &mut Vec<Arg>) {
    let span = bump_span(p);
    out.push(Arg::Placeholder(PlaceholderArg {
        id: p.node_id(),
        span,
    }));
}

// ---------------- 一次式と前置の演算子 ----------------

/// 01-02 の `Primary` と、前置の演算子の付いた式。深さ `depth` のノードを作る。
fn parse_primary(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    if p.enter(depth).is_err() {
        return Err(Fail);
    }
    let kind = p.peek_kind();
    if kind == TokenKind::Minus || kind == TokenKind::Bang {
        parse_unary(p, depth)
    } else if kind == TokenKind::LParen && p.peek_nth_kind(1) != TokenKind::RParen {
        parse_paren(p, depth)
    } else if kind == TokenKind::LBracket {
        parse_list(p, depth)
    } else if kind == TokenKind::LBrace {
        parse_block_expr(p, depth)
    } else if kind == TokenKind::KwIf {
        parse_if_expr(p, depth)
    } else if kind == TokenKind::KwMatch {
        parse_match(p, depth)
    } else if kind == TokenKind::KwFn {
        parse_lambda(p, depth)
    } else {
        parse_leaf(p)
    }
}

/// 前置の `-` と `!`。オペランドは右の強さ 70 で読む。`-` の直後の整数リテラルも
/// `UnaryExpr(Neg, LitExpr)` のまま残す（値の範囲は型検査器が判定する。02-03「字句」）。
fn parse_unary(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let op = if p.at(TokenKind::Minus) {
        UnOp::Neg
    } else {
        UnOp::Not
    };
    let op_span = bump_span(p);
    let Ok(operand) = parse_bp(p, child(depth), PREFIX_BP) else {
        return Err(Fail);
    };
    Ok(finish_unary(p, start, op, op_span, operand))
}

fn finish_unary(
    p: &mut Parser,
    start: usize,
    op: UnOp,
    op_span: Span,
    operand: Box<Expr>,
) -> Box<Expr> {
    Box::new(Expr::Unary(UnaryExpr {
        id: p.node_id(),
        span: p.span_from(start),
        op,
        op_span,
        operand,
    }))
}

/// `"(" Expr ")"`。`()` は `parse_leaf` が読む。
fn parse_paren(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let _: Span = bump_span(p);
    let Ok(inner) = parse_bp(p, child(depth), 0) else {
        return Err(Fail);
    };
    if expect_kind(p, TokenKind::RParen).is_err() {
        return Err(Fail);
    }
    Ok(finish_paren(p, start, inner))
}

fn finish_paren(p: &mut Parser, start: usize, inner: Box<Expr>) -> Box<Expr> {
    Box::new(Expr::Paren(ParenExpr {
        id: p.node_id(),
        span: p.span_from(start),
        inner,
    }))
}

/// `"[" CommaList(Expr) "]"`。i 番目の要素は、リストの深さに `i + 1` を加えた深さで解析する。
fn parse_list(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let _: Span = bump_span(p);
    let Ok(elems) = comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RBracket,
            element: text::EXPRESSION,
            separator: text::COMMA_OR_RBRACKET,
            allow_empty: true,
            indexed: true,
        },
        parse_list_elem,
        |out, node| out.push(Expr::Error(node)),
    ) else {
        return Err(Fail);
    };
    Ok(finish_list(p, start, elems))
}

fn parse_list_elem(p: &mut Parser, depth: u32, out: &mut Vec<Expr>) -> PResult<()> {
    let Ok(expr) = parse_bp(p, depth, 0) else {
        return Err(Fail);
    };
    push_expr(out, expr);
    Ok(())
}

fn push_expr(out: &mut Vec<Expr>, expr: Box<Expr>) {
    out.push(*expr);
}

fn finish_list(p: &mut Parser, start: usize, elems: Vec<Expr>) -> Box<Expr> {
    Box::new(Expr::List(ListExpr {
        id: p.node_id(),
        span: p.span_from(start),
        elems,
    }))
}

fn parse_block_expr(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    stmt::parse_block(p, depth).map(block_to_expr)
}

fn block_to_expr(block: Block) -> Box<Expr> {
    Box::new(Expr::Block(block))
}

/// 入れ子を持たない一次式: リテラル、名前（修飾を含む）、`()`、置けない位置の `_`、誤りの字句。
fn parse_leaf(p: &mut Parser) -> PResult<Box<Expr>> {
    let start = p.pos;
    let kind = p.peek_kind();
    if let Some(lit) = literal_of(p.peek()) {
        p.bump();
        return Ok(Box::new(Expr::Lit(LitExpr {
            id: p.node_id(),
            span: p.span_from(start),
            lit,
        })));
    }
    if kind == TokenKind::LowerIdent || kind == TokenKind::UpperIdent {
        return Ok(parse_name(p));
    }
    if kind == TokenKind::LParen && p.peek_nth_kind(1) == TokenKind::RParen {
        p.bump();
        p.bump();
        return Ok(Box::new(Expr::Unit(UnitExpr {
            id: p.node_id(),
            span: p.span_from(start),
        })));
    }
    if kind == TokenKind::Underscore {
        return Ok(misplaced_placeholder(p));
    }
    if kind == TokenKind::Error {
        return Ok(Box::new(Expr::Error(p.error_token_node())));
    }
    Err(p.unexpected(text::EXPRESSION))
}

/// `Name = LowerIdent | UpperIdent | UpperIdent "." ( LowerIdent | UpperIdent )`。
/// 大文字の識別子の後の `.` と名前は、修飾した名前として読む。それ以外の `.` は値に続けたドットであり、
/// `parse_bp` が報告する。
fn parse_name(p: &mut Parser) -> Box<Expr> {
    let start = p.pos;
    let is_upper = p.at(TokenKind::UpperIdent);
    let first = name_of(&p.bump());
    let qualified = is_upper
        && p.at(TokenKind::Dot)
        && matches!(
            p.peek_nth_kind(1),
            TokenKind::LowerIdent | TokenKind::UpperIdent
        );
    let (qualifier, name) = if qualified {
        p.bump();
        (Some(first), name_of(&p.bump()))
    } else {
        (None, first)
    };
    Box::new(Expr::Name(NameExpr {
        id: p.node_id(),
        span: p.span_from(start),
        qualifier,
        name,
    }))
}

/// 呼び出しの直接の引数でない位置の `_`（01-02「部分適用のプレースホルダ」）。E0204 を報告し、
/// 誤りの式にする。式の解析は続ける。
fn misplaced_placeholder(p: &mut Parser) -> Box<Expr> {
    let start = p.pos;
    let diagnostic = DiagBuilder::new(DiagCode::E0204)
        .primary(p.peek().span)
        .build();
    p.report(diagnostic);
    // 期待どおりの字句ではないので、報告の抑制を解かずに読む。
    p.advance();
    Box::new(Expr::Error(p.error_node_from(start)))
}

// ---------------- if ----------------

fn parse_if_expr(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let Ok(expr) = parse_if(p, depth) else {
        return Err(Fail);
    };
    Ok(if_to_expr(expr))
}

fn if_to_expr(expr: IfExpr) -> Box<Expr> {
    Box::new(Expr::If(expr))
}

/// `IfExpr = "if" Expr Block [ "else" ( Block | IfExpr ) ]`。条件の式は、一次式としてブロックを許す
/// 文法どおりに読む。`if x {` の `{` は中置の演算子ではないので、条件の式の終わりになる。
/// `else if` の連なりの各 `if` は 1 段と数える（02-03「入れ子の深さ」）。
fn parse_if(p: &mut Parser, depth: u32) -> PResult<IfExpr> {
    if p.enter(depth).is_err() {
        return Err(Fail);
    }
    let start = p.pos;
    let _: Span = bump_span(p);
    let Ok(cond) = parse_bp(p, child(depth), 0) else {
        return Err(Fail);
    };
    let Ok(then_block) = stmt::parse_block(p, child(depth)) else {
        return Err(Fail);
    };
    let Ok(else_branch) = parse_else(p, depth) else {
        return Err(Fail);
    };
    Ok(finish_if(p, start, cond, then_block, else_branch))
}

/// `else` の後。`depth` は `if` の深さで、`else` の後のブロックと `if` はその子である。
fn parse_else(p: &mut Parser, depth: u32) -> PResult<Option<ElseBranch>> {
    if !p.eat(TokenKind::KwElse) {
        return Ok(None);
    }
    if p.at(TokenKind::KwIf) {
        let Ok(inner) = parse_if(p, child(depth)) else {
            return Err(Fail);
        };
        return Ok(Some(ElseBranch::If(Box::new(inner))));
    }
    let Ok(block) = stmt::parse_block(p, child(depth)) else {
        return Err(Fail);
    };
    Ok(Some(ElseBranch::Block(block)))
}

fn finish_if(
    p: &mut Parser,
    start: usize,
    cond: Box<Expr>,
    then_block: Block,
    else_branch: Option<ElseBranch>,
) -> IfExpr {
    IfExpr {
        id: p.node_id(),
        span: p.span_from(start),
        cond,
        then_block,
        else_branch,
    }
}

// ---------------- match ----------------

/// `MatchExpr = "match" Expr "{" LineList(Arm) "}"`。
///
/// i 番目の分岐は `match` の深さに `i + 1` を加えた深さで解析する（02-03「入れ子の深さ」）。
/// 分岐のパターンの節は、すべての分岐で一つの数え手を共有し、基準の深さを `match` の深さにする
/// （ADR 0086）。分岐の回復は、同じ波括弧の中の次の NEWLINE か `}` まで読み飛ばす
/// （02-03「誤りからの回復」）。分岐には誤りの変種がないので、読み飛ばした分岐は並びに置かない
/// （診断は報告済みなので、この AST は名前解決へ渡らない。ADR 0019）。
fn parse_match(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let _: Span = bump_span(p);
    let Ok(scrutinee) = parse_bp(p, child(depth), 0) else {
        return Err(Fail);
    };
    if expect_kind(p, TokenKind::LBrace).is_err() {
        return Err(Fail);
    }
    let mut counter = PatternCounter::new(depth);
    let Ok(arms) = line_list(
        p,
        depth,
        true,
        |p, d, out| parse_arm(p, d, &mut counter, out),
        |_, _| {},
    ) else {
        return Err(Fail);
    };
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

/// `Arm = Pattern "=>" Expr`。`depth` は分岐の深さで、本体はその子である。分岐の後の NEWLINE か `}` は
/// `line_list` が求める。読んだ分岐を `out` に加える。
fn parse_arm(
    p: &mut Parser,
    depth: u32,
    counter: &mut PatternCounter,
    out: &mut Vec<MatchArm>,
) -> PResult<()> {
    if p.enter(depth).is_err() {
        return Err(Fail);
    }
    let start = p.pos;
    let Ok(pattern) = pattern::parse_pattern(p, counter) else {
        return Err(Fail);
    };
    if expect_kind(p, TokenKind::FatArrow).is_err() {
        return Err(Fail);
    }
    let Ok(body) = parse_bp(p, child(depth), 0) else {
        return Err(Fail);
    };
    push_arm(p, start, pattern, body, out);
    Ok(())
}

fn push_arm(
    p: &mut Parser,
    start: usize,
    pattern: Pattern,
    body: Box<Expr>,
    out: &mut Vec<MatchArm>,
) {
    out.push(MatchArm {
        id: p.node_id(),
        span: p.span_from(start),
        pattern,
        body: *body,
    });
}

// ---------------- ラムダ ----------------

/// ラムダの、本体の前までの部分。
struct LambdaHead {
    params: Vec<Param>,
    ret: Option<TypeExpr>,
    uses: Option<UsesList>,
}

/// `Lambda = "fn" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ] Block`。
fn parse_lambda(p: &mut Parser, depth: u32) -> PResult<Box<Expr>> {
    let start = p.pos;
    let Ok(head) = parse_lambda_head(p, depth) else {
        return Err(Fail);
    };
    let Ok(body) = stmt::parse_block(p, child(depth)) else {
        return Err(Fail);
    };
    Ok(finish_lambda(p, start, head, body))
}

/// `"fn" "(" CommaList(LambdaParam) ")" [ "->" Type [ Uses ] ]`。
/// 戻り値の型が関数の型なら、その解析が先に `uses` を読む。ここに `uses` が残るのは、戻り値の型が
/// 関数の型でないか、括弧で囲んだ関数の型のときである（02-03「型の解析」）。
/// ラムダの本体の解析が始まる前に戻るので、再帰の経路には載らない。
fn parse_lambda_head(p: &mut Parser, depth: u32) -> PResult<LambdaHead> {
    let _: Span = bump_span(p);
    expect_kind(p, TokenKind::LParen)?;
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
        parse_lambda_param,
        // 引数の並びには誤りのノードを置く場所がない（関数の宣言の引数と同じ）。
        |_, _| {},
    )?;
    let (ret, uses) = if p.eat(TokenKind::Arrow) {
        let ret = types::parse_type(p, child(depth))?;
        let uses = if p.at(TokenKind::KwUses) {
            Some(types::parse_uses(p, depth)?)
        } else {
            None
        };
        (Some(ret), uses)
    } else {
        (None, None)
    };
    Ok(LambdaHead { params, ret, uses })
}

/// `LambdaParam = LowerIdent [ ":" Type ]`。読んだ引数を `out` に加える。
///
/// `_` は引数に書けない（01-02「ラムダ」）。E0210 を報告し、その引数（型注釈があれば型注釈も）を
/// 読み飛ばして並びを続ける。
fn parse_lambda_param(p: &mut Parser, depth: u32, out: &mut Vec<Param>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    if p.at(TokenKind::Underscore) {
        let diagnostic = DiagBuilder::new(DiagCode::E0210)
            .primary(p.peek().span)
            .help("name")
            .build();
        p.report(diagnostic);
        // 期待どおりの字句ではないので、報告の抑制を解かずに読む。
        p.advance();
        if p.eat(TokenKind::Colon) {
            let _: TypeExpr = types::parse_type(p, child(depth))?;
        }
        return Ok(());
    }
    let name = p.expect_name(TokenKind::LowerIdent, text::PARAMETER)?;
    let ty = if p.eat(TokenKind::Colon) {
        Some(types::parse_type(p, child(depth))?)
    } else {
        None
    };
    out.push(Param {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        ty,
    });
    Ok(())
}

fn finish_lambda(p: &mut Parser, start: usize, head: LambdaHead, body: Block) -> Box<Expr> {
    Box::new(Expr::Lambda(LambdaExpr {
        id: p.node_id(),
        span: p.span_from(start),
        params: head.params,
        ret: head.ret,
        uses: head.uses,
        body,
    }))
}

#[cfg(test)]
// テストの失敗は panic で表す（07-03）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::super::MAX_DEPTH;
    use super::super::tests::{body_stmts, codes, offset, parse_user, primary_start};
    use crate::diag::DiagCode;
    use crate::syntax::ast::{
        Arg, BinOp, ElseBranch, Expr, Literal, Pattern, Stmt, TypeExpr, UnOp,
    };

    /// 式の木を S 式の形の文字列にする。構造だけを比べるためのもので、span とノード番号は含めない。
    fn sexp(expr: &Expr) -> String {
        match expr {
            Expr::Lit(e) => match &e.lit {
                Literal::Int { digits, .. } => digits.clone(),
                Literal::Float(text) => text.clone(),
                Literal::Str(text) => format!("{text:?}"),
                Literal::Char(c) => format!("{c:?}"),
                Literal::Bool(b) => b.to_string(),
            },
            Expr::Name(e) => match &e.qualifier {
                Some(q) => format!("{}.{}", q.text, e.name.text),
                None => e.name.text.clone(),
            },
            Expr::Unit(_) => "()".to_string(),
            Expr::Paren(e) => format!("(paren {})", sexp(&e.inner)),
            Expr::List(e) => {
                let elems: Vec<String> = e.elems.iter().map(sexp).collect();
                format!("[{}]", elems.join(" "))
            }
            Expr::Call(e) => {
                let mut parts = vec!["call".to_string(), sexp(&e.callee)];
                parts.extend(e.args.iter().map(|arg| match arg {
                    Arg::Expr(e) => sexp(e),
                    Arg::Placeholder(_) => "_".to_string(),
                }));
                format!("({})", parts.join(" "))
            }
            Expr::Binary(e) => {
                let op = match e.op {
                    BinOp::Add => "+",
                    BinOp::Sub => "-",
                    BinOp::Mul => "*",
                    BinOp::Div => "/",
                    BinOp::Rem => "%",
                    BinOp::Eq => "==",
                    BinOp::Ne => "!=",
                    BinOp::Lt => "<",
                    BinOp::Le => "<=",
                    BinOp::Gt => ">",
                    BinOp::Ge => ">=",
                    BinOp::And => "&&",
                    BinOp::Or => "||",
                };
                format!("({op} {} {})", sexp(&e.lhs), sexp(&e.rhs))
            }
            Expr::Unary(e) => {
                let op = match e.op {
                    UnOp::Neg => "neg",
                    UnOp::Not => "not",
                };
                format!("({op} {})", sexp(&e.operand))
            }
            Expr::Pipe(e) => format!("(|> {} {})", sexp(&e.lhs), sexp(&e.rhs)),
            Expr::Block(b) => format!("(block {})", b.stmts.len()),
            Expr::If(_) => "(if)".to_string(),
            Expr::Match(m) => format!("(match {})", m.arms.len()),
            Expr::Lambda(l) => format!("(fn {})", l.params.len()),
            Expr::Error(_) => "error".to_string(),
        }
    }

    /// 関数の本体に `expr` を一つの文として置いたソース。文の深さは 3 である
    /// （プログラム 0、関数の宣言 1、本体 2、本体の 0 番目の文 3）。
    fn in_body(expr: &str) -> String {
        format!("fn f() -> Unit {{\n  {expr}\n}}")
    }

    /// 本体の唯一の文の式。
    fn only_expr(out: &crate::syntax::parser::ParseOutput) -> &Expr {
        match body_stmts(out) {
            [Stmt::Expr(e)] => e,
            other => panic!("expected one expression statement, got {other:?}"),
        }
    }

    #[test]
    fn expressions_are_parsed_into_the_written_shape() {
        let cases = [
            // 優先順位と左結合
            ("a + b * c - d", "(- (+ a (* b c)) d)"),
            ("a - b - c", "(- (- a b) c)"),
            ("x |> f |> g", "(|> (|> x f) g)"),
            ("a || b && c == d + e", "(|| a (&& b (== c (+ d e))))"),
            ("a * (b + c) % d", "(% (* a (paren (+ b c))) d)"),
            // 前置の演算子と呼び出し
            ("-f(x)", "(neg (call f x))"),
            ("!a && b", "(&& (not a) b)"),
            ("- -1", "(neg (neg 1))"),
            ("f(a)(b)", "(call (call f a) b)"),
            ("f()", "(call f)"),
            // 修飾した名前
            ("List.map(xs, f)", "(call List.map xs f)"),
            ("Shape.Circle(1.0)", "(call Shape.Circle 1.0)"),
            // プレースホルダ
            ("clamp(0, _, 100)", "(call clamp 0 _ 100)"),
            ("f(g(_))", "(call f (call g _))"),
            // パイプの右辺（ADR 0050）
            (
                "x |> (makeHandler(c))",
                "(|> x (paren (call makeHandler c)))",
            ),
            ("x |> fn(v) { v * 2 }", "(|> x (fn 1))"),
            ("x |> clamp(0, _, 100)", "(|> x (call clamp 0 _ 100))"),
            // そのほかの一次式
            ("[1, \"a\", 'c', true, ()]", "[1 \"a\" 'c' true ()]"),
            ("[]", "[]"),
            ("{ 1 } + 2", "(+ (block 1) 2)"),
        ];
        for (src, expected) in cases {
            let out = parse_user(&in_body(src));
            assert_eq!(codes(&out), vec![], "{src:?}");
            assert_eq!(sexp(only_expr(&out)), expected, "{src:?}");
        }
    }

    #[test]
    fn chained_comparison_is_reported_once_at_the_second_operator() {
        for (src, second) in [("a < b < c", "< c"), ("a == b == c", "== c")] {
            let full = in_body(src);
            let out = parse_user(&full);
            assert_eq!(codes(&out), vec![DiagCode::E0202], "{src:?}");
            assert_eq!(primary_start(&out, 0), offset(&full, second), "{src:?}");
            assert!(!out.diagnostics[0].helps.is_empty());
        }
        // 回復として左結合で読み続ける。
        let out = parse_user(&in_body("a < b < c"));
        assert_eq!(sexp(only_expr(&out)), "(< (< a b) c)");
        // 論理演算子で分けた比較は連なりではない。
        assert_eq!(codes(&parse_user(&in_body("a < b && b < c"))), vec![]);
    }

    #[test]
    fn dot_after_a_value_is_reported() {
        let cases = [
            // 入力、診断の主な位置、回復した後の木、誤りのノードの範囲
            ("xs.map(f)", ".map", "(call error f)", "xs.map"),
            ("s.length", ".length", "error", "s.length"),
            ("List.map.x", ".x", "error", "List.map.x"),
            ("f().g", ".g", "error", "f().g"),
            ("-a.b", ".b", "(neg error)", "a.b"),
        ];
        for (src, dot, tree, skipped) in cases {
            let full = in_body(src);
            let out = parse_user(&full);
            assert_eq!(codes(&out), vec![DiagCode::E0203], "{src:?}");
            let primary = out.diagnostics[0].primary.as_ref().unwrap();
            let start = offset(&full, dot);
            let end = start + u32::try_from(dot.len()).unwrap();
            assert_eq!((primary.span.start.0, primary.span.end.0), (start, end));
            assert!(!out.diagnostics[0].helps.is_empty(), "{src:?}");
            // 値と `.` とその後の名前を一つの誤りのノードにして続ける。
            assert_eq!(sexp(only_expr(&out)), tree, "{src:?}");
            let error = find_error(only_expr(&out)).expect(src);
            let start = offset(&full, skipped);
            let end = start + u32::try_from(skipped.len()).unwrap();
            assert_eq!((error.start.0, error.end.0), (start, end), "{src:?}");
        }
    }

    /// 呼び出される式と前置の演算子のオペランドを辿って、最初の誤りの式の span を返す。
    fn find_error(expr: &Expr) -> Option<crate::base::Span> {
        match expr {
            Expr::Error(e) => Some(e.span),
            Expr::Call(c) => find_error(&c.callee),
            Expr::Unary(u) => find_error(&u.operand),
            Expr::Lit(_)
            | Expr::Name(_)
            | Expr::Unit(_)
            | Expr::Paren(_)
            | Expr::List(_)
            | Expr::Binary(_)
            | Expr::Pipe(_)
            | Expr::Block(_)
            | Expr::If(_)
            | Expr::Match(_)
            | Expr::Lambda(_) => None,
        }
    }

    #[test]
    fn misplaced_underscore_is_reported() {
        for src in ["_ + 1", "[_]", "f(_ + 1)", "f(-_)", "let y = _"] {
            let full = in_body(src);
            let out = parse_user(&full);
            assert_eq!(codes(&out), vec![DiagCode::E0204], "{src:?}");
            assert_eq!(primary_start(&out, 0), offset(&full, "_"), "{src:?}");
        }
    }

    #[test]
    fn lambdas_keep_annotations_and_uses() {
        let cases = [
            ("fn(x) { x + 1 }", vec![false], false, false),
            ("fn(x: Int) -> Int { x }", vec![true], true, false),
            (
                "fn(l: String) -> Unit uses IO { Console.println(l) }",
                vec![true],
                true,
                true,
            ),
            ("fn(a, b: Int) { a }", vec![false, true], false, false),
        ];
        for (src, typed, has_ret, has_uses) in cases {
            let out = parse_user(&in_body(src));
            assert_eq!(codes(&out), vec![], "{src:?}");
            let Expr::Lambda(lambda) = only_expr(&out) else {
                panic!("{src:?}");
            };
            let params: Vec<bool> = lambda.params.iter().map(|p| p.ty.is_some()).collect();
            assert_eq!(params, typed, "{src:?}");
            assert_eq!(lambda.ret.is_some(), has_ret, "{src:?}");
            assert_eq!(lambda.uses.is_some(), has_uses, "{src:?}");
        }
        // 戻り値の型が関数の型なら、`uses` はその型に付く（02-03「型の解析」）。
        let out = parse_user(&in_body("fn() -> fn() -> Unit uses IO { f }"));
        assert_eq!(codes(&out), vec![]);
        let Expr::Lambda(lambda) = only_expr(&out) else {
            panic!();
        };
        assert_eq!(lambda.uses, None);
        let Some(TypeExpr::Fn(ret)) = &lambda.ret else {
            panic!("{:?}", lambda.ret);
        };
        let effects: Vec<&str> = ret
            .uses
            .iter()
            .flat_map(|u| u.effects.iter().map(|e| e.name.text.as_str()))
            .collect();
        assert_eq!(effects, vec!["IO"]);
    }

    #[test]
    fn underscore_lambda_parameter_is_reported_and_skipped() {
        let full = in_body("fn(_, x) { x }");
        let out = parse_user(&full);
        assert_eq!(codes(&out), vec![DiagCode::E0210]);
        assert_eq!(primary_start(&out, 0), offset(&full, "_"));
        assert!(!out.diagnostics[0].helps.is_empty());
        let Expr::Lambda(lambda) = only_expr(&out) else {
            panic!();
        };
        let names: Vec<&str> = lambda.params.iter().map(|p| p.name.text.as_str()).collect();
        assert_eq!(names, vec!["x"]);
    }

    #[test]
    fn else_if_chain() {
        let out = parse_user(&in_body("if a { 1 } else if b { 2 } else { 3 }"));
        assert_eq!(codes(&out), vec![]);
        let Expr::If(first) = only_expr(&out) else {
            panic!();
        };
        assert_eq!(sexp(&first.cond), "a");
        let Some(ElseBranch::If(second)) = &first.else_branch else {
            panic!("{:?}", first.else_branch);
        };
        assert_eq!(sexp(&second.cond), "b");
        assert!(matches!(second.else_branch, Some(ElseBranch::Block(_))));

        let out = parse_user(&in_body("if a { 1 }"));
        let Expr::If(alone) = only_expr(&out) else {
            panic!();
        };
        assert_eq!(alone.else_branch, None);
    }

    #[test]
    fn match_example_from_the_spec() {
        // 01-02「パターンマッチ」の例。
        let src = "match shape {\n  Shape.Circle(r) => 3.14159 * r * r\n  Shape.Rect(w, h) => {\n    let area = w * h\n    area\n  }\n}";
        let out = parse_user(&in_body(src));
        assert_eq!(codes(&out), vec![]);
        let Expr::Match(m) = only_expr(&out) else {
            panic!();
        };
        assert_eq!(sexp(&m.scrutinee), "shape");
        let [first, second] = m.arms.as_slice() else {
            panic!("{:?}", m.arms);
        };
        assert!(matches!(&first.pattern, Pattern::Ctor(c) if c.name.text == "Circle"));
        assert_eq!(sexp(&first.body), "(* (* 3.14159 r) r)");
        assert!(matches!(&second.pattern, Pattern::Ctor(c) if c.args.len() == 2));
        assert_eq!(sexp(&second.body), "(block 2)");
    }

    #[test]
    fn broken_match_arm_is_skipped_to_the_next_line() {
        // `=>` の直後の改行は空白になるので、改行を飲み込まない字句 `)` で分岐の本体を壊す。
        let src = "match x {\n  1 => )\n  2 => b\n}";
        let full = in_body(src);
        let out = parse_user(&full);
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        assert_eq!(primary_start(&out, 0), offset(&full, ")\n  2"));
        let Expr::Match(m) = only_expr(&out) else {
            panic!();
        };
        let [arm] = m.arms.as_slice() else {
            panic!("{:?}", m.arms);
        };
        assert_eq!(sexp(&arm.body), "b");
    }

    #[test]
    fn one_mistake_reports_one_error() {
        // 構文エラーの後、派生した構文エラーを出さない（02-03「誤りからの回復」）。
        for src in [
            "a + )",
            "f(a b)",
            "(a b)",
            "[1 2]",
            "if a 1",
            "match x { 1 }",
            "fn(x y) { x }",
            "f(a, +, b)",
        ] {
            let out = parse_user(&format!("{}\nfn g() -> Unit {{ () }}", in_body(src)));
            assert_eq!(
                codes(&out),
                vec![DiagCode::E0201],
                "{src:?}: {:?}",
                out.diagnostics
            );
            // 後の宣言は解析される。
            assert_eq!(out.program.items.len(), 2, "{src:?}");
        }
    }

    #[test]
    fn expressions_spanning_lines() {
        // 01-01「改行による区切り」の三つの例。
        for src in [
            "let total = price\n  * quantity",
            "let n = lines\n  |> List.filter(fn(l) { l != \"\" })\n  |> List.length",
            "if ready {\n  start()\n} else {\n  wait()\n}",
        ] {
            let out = parse_user(&in_body(src));
            assert_eq!(codes(&out), vec![], "{src:?}");
            assert_eq!(body_stmts(&out).len(), 1, "{src:?}");
        }
    }

    #[test]
    fn example_program_from_the_spec() {
        // 01-02「例」のプログラム全体。
        let src = r#"type Shape {
  Circle(Float)
  Rect(Float, Float)
}

fn area(s: Shape) -> Float {
  match s {
    Shape.Circle(r) => 3.14159 * r * r
    Shape.Rect(w, h) => w * h
  }
}

fn totalArea(shapes: List[Shape]) -> Float {
  shapes
    |> List.map(area)
    |> List.fold(0.0, fn(acc, a) { acc + a })
}

fn main() -> Unit uses IO {
  let shapes = [Shape.Circle(1.0), Shape.Rect(2.0, 3.0)]
  Console.println(Float.toString(totalArea(shapes)))
}
"#;
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![]);
        assert_eq!(out.program.items.len(), 4);
        let [_, _, _, crate::syntax::ast::Item::Fn(main)] = out.program.items.as_slice() else {
            panic!();
        };
        assert_eq!(main.name.text, "main");
        assert_eq!(main.body.stmts.len(), 2);
    }

    /// 場合の名前、段数から式を作る関数、上限に収まる最大の段数。
    type NestingCase = (&'static str, fn(usize) -> String, usize);

    /// 入れ子の深さの上限の確かめに使う、文の深さ 3 に置く式の作り方と、上限に収まる最大の段数。
    /// 段数を 1 増やすと上限（1000）を超える。
    fn nesting_cases() -> Vec<NestingCase> {
        let limit = usize::try_from(MAX_DEPTH).unwrap();
        vec![
            // 一番内側の `x` の深さは 3 + n
            (
                "parens",
                |n| format!("{}x{}", "(".repeat(n), ")".repeat(n)),
                limit - 3,
            ),
            (
                "lists",
                |n| format!("{}x{}", "[".repeat(n), "]".repeat(n)),
                limit - 3,
            ),
            (
                "call args",
                |n| format!("{}x{}", "f(".repeat(n), ")".repeat(n)),
                limit - 3,
            ),
            ("prefix ops", |n| format!("{}x", "-".repeat(n)), limit - 3),
            // 左に深くなる連なりも、演算子と呼び出しの一つ一つを 1 段と数える
            (
                "operator chain",
                |n| format!("x{}", " + x".repeat(n)),
                limit - 3,
            ),
            ("call chain", |n| format!("f{}", "(x)".repeat(n)), limit - 3),
            // 連なりの最初のオペランドの中の入れ子の深さと、連なりの長さとを足して数える
            (
                "chain after nested operand",
                |n| {
                    format!(
                        "{}x{}{}",
                        "(".repeat(500),
                        ")".repeat(500),
                        " * x".repeat(n)
                    )
                },
                limit - 3 - 500,
            ),
            (
                "chain inside operand",
                |n| format!("(x{}) - x", " - x".repeat(n)),
                limit - 3 - 2,
            ),
            // 最後の `else if` の本体の文の深さは 3 + n + 2
            (
                "else if",
                |n| format!("if a {{ x }}{}", " else if a { x }".repeat(n)),
                limit - 5,
            ),
            // 一段ごとに 2 段深くなる（ブロックと文、分岐と本体）。一番内側の `x` の深さは 3 + 2n
            (
                "if",
                |n| format!("{}x{}", "if a { ".repeat(n), " }".repeat(n)),
                (limit - 3) / 2,
            ),
            (
                "lambda",
                |n| format!("{}x{}", "fn() { ".repeat(n), " }".repeat(n)),
                (limit - 3) / 2,
            ),
            (
                "match",
                |n| format!("{}x{}", "match a { _ => ".repeat(n), " }".repeat(n)),
                (limit - 3) / 2,
            ),
        ]
    }

    #[test]
    fn nesting_up_to_the_limit_is_accepted_and_beyond_is_reported() {
        // 上限までの入れ子を、テストのスレッドの既定のスタックで解析できることも確かめる。
        for (name, make, max) in nesting_cases() {
            let out = parse_user(&in_body(&make(max)));
            assert_eq!(codes(&out), vec![], "{name}: {max}");
            let out = parse_user(&format!(
                "fn g() -> Unit {{ () }}\n{}\n)",
                in_body(&make(max + 1))
            ));
            // E0208 は一つだけで、打ち切った後の字句（最後の `)`）について診断を出さない。
            assert_eq!(codes(&out), vec![DiagCode::E0208], "{name}: {}", max + 1);
            assert!(
                matches!(out.program.items.first(), Some(crate::syntax::ast::Item::Fn(g)) if g.name.text == "g"),
                "{name}"
            );
        }
    }

    #[test]
    fn list_elements_and_call_arguments_count_by_position() {
        // 並びの i 番目の要素は、親の深さに i + 1 を加えて数える（02-03「入れ子の深さ」）。
        let limit = usize::try_from(MAX_DEPTH).unwrap();
        for (open, close) in [("[", "]"), ("f(", ")")] {
            let elems = |n: usize| format!("{open}{}{close}", vec!["1"; n].join(", "));
            assert_eq!(
                codes(&parse_user(&in_body(&elems(limit - 3)))),
                vec![],
                "{open}"
            );
            assert_eq!(
                codes(&parse_user(&in_body(&elems(limit - 2)))),
                vec![DiagCode::E0208],
                "{open}"
            );
        }
    }
}
