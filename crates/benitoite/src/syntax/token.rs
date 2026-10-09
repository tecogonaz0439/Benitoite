//! 字句（設計書 02-03「字句」、01-01）。

use crate::base::Span;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum TokenKind {
    LowerIdent,
    UpperIdent,
    IntLit,
    FloatLit,
    /// `Decimal` のリテラル（`1.25m`）
    DecimalLit,
    /// 文字列補間を含まない文字列リテラル（複数行の文字列と raw 文字列を含む）
    StringLit,
    /// 補間の開始: 開きの引用符から最初の `${` まで
    StrStart,
    /// 補間の中間: 式の後の `}` から次の `${` まで
    StrMid,
    /// 補間の終わり: 最後の式の後の `}` から閉じの引用符まで
    StrEnd,
    CharLit,
    // キーワード（02-03「字句」のキーワードの表）
    KwAnd,
    KwBind,
    KwCase,
    KwConst,
    KwData,
    KwDiv,
    KwDo,
    KwEffect,
    KwElse,
    KwEnd,
    KwFalse,
    KwFunction,
    KwHandle,
    KwIf,
    KwImplement,
    KwImport,
    KwLambda,
    KwLazy,
    KwMatch,
    KwMod,
    KwNot,
    KwOr,
    KwPublic,
    KwRecord,
    KwResume,
    KwReturn,
    KwShadow,
    KwThen,
    KwTrait,
    KwTrue,
    KwTry,
    KwType,
    KwUses,
    KwWith,
    // 演算子と区切り記号（01-01「演算子と区切り記号」）
    /// `+`
    Plus,
    /// `-`
    Minus,
    /// `*`
    Star,
    /// `/`
    Slash,
    /// `=`
    Eq,
    /// `<>`
    NotEq,
    /// `<`
    Lt,
    /// `<=`
    Le,
    /// `>`
    Gt,
    /// `>=`
    Ge,
    /// `|>`
    PipeGt,
    /// `->`
    Arrow,
    /// `<-`
    LeftArrow,
    /// `:`
    Colon,
    /// `,`
    Comma,
    /// `.`
    Dot,
    /// `..`
    DotDot,
    /// `&`
    Amp,
    /// `@`
    At,
    LParen,
    RParen,
    LBracket,
    RBracket,
    /// `_` 一文字
    Underscore,
    /// 改行の印。字句の切り出しの工程だけが作る
    LineBreak,
    /// 改行の判定で残った改行字句（NEWLINE）
    Newline,
    /// 字句を切り出す工程が誤りを報告済みの字句（許されない文字、誤りを含むリテラルなど）。
    /// 構文解析器は、期待していた構文の誤りのノードにし、新たな構文エラーを報告しない
    Error,
    /// 字句に使えない記号（`;`・`{`・`}`・`==`・`!=`・`&&`・`||`・`!`・`=>`・`%`・`?`・`#`・`|` など）。
    /// 値は `TokenValue::Symbol`。構文解析器が文脈で修正案を選んで報告する（02-03「字句の誤り」）
    BadSymbol,
    /// ファイルの終わり。span の長さは 0
    Eof,
}

/// 字句が持つ値（02-03「字句」の表）。
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
    /// `_` と接尾辞 `m` を除いた字面
    Decimal(String),
    /// エスケープを解いた後の文字列。複数行の文字列は字下げを除き行末の `\` を処理した後、
    /// raw 文字列は書いた文字の並びそのもの。`StrStart`・`StrMid`・`StrEnd` はその部分の文字列
    Str(String),
    /// エスケープを解いた後のスカラー値
    Char(char),
    /// `BadSymbol` の記号の字面
    Symbol(String),
}

#[derive(Clone, PartialEq, Debug)]
pub struct Token {
    pub kind: TokenKind,
    pub span: Span,
    pub value: TokenValue,
}

/// コメントの種類（02-03「コメントとドキュメントコメント」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum CommentKind {
    /// `//`（`////` 以上を含む）
    Plain,
    /// `///`: 直後の宣言の説明
    Doc,
    /// `//!`: ファイルのモジュールの説明
    ModuleDoc,
}

/// コメント一つ。本文は `//`・`///`・`//!` の後から行末まで（改行を含まない）。
#[derive(Clone, PartialEq, Debug)]
pub struct Comment {
    pub span: Span,
    pub kind: CommentKind,
    pub text: String,
}
