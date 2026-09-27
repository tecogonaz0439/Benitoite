//! 字句（設計書 02-03「字句」）。

use crate::base::Span;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum TokenKind {
    LowerIdent,
    UpperIdent,
    IntLit,
    FloatLit,
    StringLit,
    CharLit,
    // キーワード（01-01「キーワード」）
    KwEffect,
    KwElse,
    KwFalse,
    KwFn,
    KwIf,
    KwLet,
    KwMatch,
    KwTrue,
    KwType,
    KwUses,
    // 演算子と区切り記号（01-01「演算子と区切り記号」）
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    EqEq,
    BangEq,
    Lt,
    Le,
    Gt,
    Ge,
    AndAnd,
    OrOr,
    Bang,
    PipeGt,
    Arrow,
    FatArrow,
    Eq,
    Colon,
    Comma,
    Dot,
    LParen,
    RParen,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
    Underscore,
    /// 改行の印。字句の切り出しの工程だけが作る
    LineBreak,
    /// 改行の判定で残った改行字句（NEWLINE）
    Newline,
    /// 誤りの字句（予約語、誤りを含むリテラル）。構文解析器は、期待していた構文の誤りのノードにする
    Error,
    /// ファイルの終わり。span の長さは 0
    Eof,
}

/// リテラルの字句が持つ値（02-03「字句」の表）。
#[derive(Clone, PartialEq, Debug)]
pub enum TokenValue {
    None,
    /// 識別子の綴り
    Ident(String),
    /// 基数（2・8・10・16）と、接頭辞と `_` を除いた数字列
    Int {
        radix: u32,
        digits: String,
    },
    /// `_` を除いた字面
    Float(String),
    /// エスケープを解いた後の文字列
    Str(String),
    /// エスケープを解いた後のスカラー値
    Char(char),
}

#[derive(Clone, PartialEq, Debug)]
pub struct Token {
    pub kind: TokenKind,
    pub span: Span,
    pub value: TokenValue,
}

/// コメント一つ。本文は `//` の後から行末まで（改行を含まない）。
#[derive(Clone, PartialEq, Debug)]
pub struct Comment {
    pub span: Span,
    pub text: String,
}
