//! 構文の誤り（E0201）の `{expected}` と `{found}` に埋める語句（実装プラン 00-02「文言」）。
//!
//! 診断の型板そのものは `diag::codes` の表にある。ここに置くのは、型板に埋める字句と構文の
//! 呼び名である。処理を書く関数の中に英語の語句を直接書かないために、一か所にまとめる（ADR 0033）。

use crate::syntax::token::TokenKind;

/// キーワード・演算子・区切り記号の字句の呼び名。字面をバッククォートで囲む。
pub(super) const TOKEN_SPELLINGS: &[(TokenKind, &str)] = &[
    (TokenKind::KwEffect, "`effect`"),
    (TokenKind::KwElse, "`else`"),
    (TokenKind::KwFalse, "`false`"),
    (TokenKind::KwFn, "`fn`"),
    (TokenKind::KwIf, "`if`"),
    (TokenKind::KwLet, "`let`"),
    (TokenKind::KwMatch, "`match`"),
    (TokenKind::KwTrue, "`true`"),
    (TokenKind::KwType, "`type`"),
    (TokenKind::KwUses, "`uses`"),
    (TokenKind::Plus, "`+`"),
    (TokenKind::Minus, "`-`"),
    (TokenKind::Star, "`*`"),
    (TokenKind::Slash, "`/`"),
    (TokenKind::Percent, "`%`"),
    (TokenKind::EqEq, "`==`"),
    (TokenKind::BangEq, "`!=`"),
    (TokenKind::Lt, "`<`"),
    (TokenKind::Le, "`<=`"),
    (TokenKind::Gt, "`>`"),
    (TokenKind::Ge, "`>=`"),
    (TokenKind::AndAnd, "`&&`"),
    (TokenKind::OrOr, "`||`"),
    (TokenKind::Bang, "`!`"),
    (TokenKind::PipeGt, "`|>`"),
    (TokenKind::Arrow, "`->`"),
    (TokenKind::FatArrow, "`=>`"),
    (TokenKind::Eq, "`=`"),
    (TokenKind::Colon, "`:`"),
    (TokenKind::Comma, "`,`"),
    (TokenKind::Dot, "`.`"),
    (TokenKind::LParen, "`(`"),
    (TokenKind::RParen, "`)`"),
    (TokenKind::LBracket, "`[`"),
    (TokenKind::RBracket, "`]`"),
    (TokenKind::LBrace, "`{`"),
    (TokenKind::RBrace, "`}`"),
    (TokenKind::Underscore, "`_`"),
    (TokenKind::IntLit, "integer literal"),
    (TokenKind::FloatLit, "floating-point literal"),
    (TokenKind::StringLit, "string literal"),
    (TokenKind::CharLit, "character literal"),
    (TokenKind::Newline, "a newline"),
    // 構文解析器は `LineBreak` を受け取らない（10-03）。表を欠けなくするために置く。
    (TokenKind::LineBreak, "a newline"),
    (TokenKind::Eof, "end of file"),
    // 誤りの字句について構文エラーは報告しない（02-03「字句」）。表を欠けなくするために置く。
    (TokenKind::Error, "an invalid token"),
];

/// 識別子の字句の呼び名の前に置く語。`identifier `x`` の形にする。
pub(super) const IDENTIFIER: &str = "identifier";

// ---- 期待する構文の呼び名 ----

pub(super) const DECLARATION: &str = "a declaration (`fn` or `type`)";
pub(super) const TYPE: &str = "a type";
pub(super) const PATTERN: &str = "a pattern";
pub(super) const EXPRESSION: &str = "an expression";
pub(super) const NAME: &str = "a name";
pub(super) const PARAMETER: &str = "a parameter";
pub(super) const TYPE_PARAMETER: &str = "a type parameter";
pub(super) const CONSTRUCTOR: &str = "a constructor";
pub(super) const EFFECT: &str = "an effect name";
pub(super) const NEWLINE_OR_RBRACE: &str = "a newline or `}`";
pub(super) const NEWLINE_OR_EOF: &str = "a newline or end of file";
pub(super) const COMMA_OR_RPAREN: &str = "`,` or `)`";
pub(super) const COMMA_OR_RBRACKET: &str = "`,` or `]`";
