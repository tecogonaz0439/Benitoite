//! 字句の位置ごとの役割の表（設計書 06-03「入力表現」「字句の間の空白」「字下げ」「空の行」）。
//! 字下げと空白の規則に要る構文の情報（開き・区切り・閉じの字句、並びの要素、呼び出しの括弧、単項の `-`）は
//! 字句の列だけでは決まらないので、AST を辿って字句ごとに決める。

/// 行の最初の字句のときの、その前の空の行の扱い（06-03「空の行」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub enum BlankBefore {
    /// 書き手の空の行を一つまでにまとめて保つ（ブロックの中と括弧の中、`case` の前）
    #[default]
    KeepOne,
    /// 空の行を除く（構文の中身の最初の行、閉じの字句・`else`・節の並びを始める `with` で始まる行、
    /// 属性の行と宣言の間、`///` の行と属性の間）
    Remove,
}

/// 字句一つの役割。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct TokenRole {
    /// 行の最初の字句のときの段（字下げの空白は `level * INDENT_WIDTH`）
    pub level: u32,
    /// 同じ行の直前の字句との間に空白を一つ置くか。行の最初の字句では使わない
    pub space_before: bool,
    /// 行の最初の字句のときの、その前の空の行の扱い
    pub blank_before: BlankBefore,
    /// 閉じの字句のとき、閉じる構文の中の行の段。ほかの字句では `None`
    pub inner_level: Option<u32>,
}

/// トップレベルの宣言の種類（06-03「空の行」の、宣言の間の空の行の規則）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TopKind {
    Import,
    Const,
    Other,
}

/// トップレベルの宣言一つの範囲。`first`・`last` は字句の列の添字である。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TopRange {
    /// 属性を含めた最初の字句
    pub first: usize,
    /// 最後の字句（`end` のある宣言は `end` の後の語）
    pub last: usize,
    pub kind: TopKind,
}

/// 役割の表。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct RoleTable {
    /// `lex` の字句の列と同じ添字。`LineBreak` と `Eof` の項目は既定の値のまま使わない
    pub roles: Vec<TokenRole>,
    /// トップレベルの宣言（import の宣言を含む）の範囲。ソースの順
    pub top: Vec<TopRange>,
}

use crate::syntax::ast::Module;
use crate::syntax::token::Token;

/// AST と `lex` の字句の列から役割の表を作る（本章「役割の表」）。`module` は誤りのノードを含まない。
/// `text` はソースのバイト列で、複数行の文字列の字句の行を数えるために読む。
pub fn build_roles(module: &Module, tokens: &[Token], text: &[u8]) -> RoleTable {
    // 複数行の文字列の字句は、字句の span がそのまま行をまたぐので、行の最初の字句は改行の印の
    // 直後の字句として決まる（10-17「役割の表」）。`text` は行を数え直すためには読まない。
    let _ = text;
    let mut walker = walk::Walker::new(tokens);
    walker.module(module);
    walker.finish()
}

mod walk;

#[cfg(test)]
pub(super) mod tests;
