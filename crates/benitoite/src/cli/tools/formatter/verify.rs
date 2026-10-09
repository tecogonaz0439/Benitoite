//! 整形後の検証（設計書 06-03「整形後の検証」、ADR 0227）。

use super::is_syntax_error;
use crate::base::SourceKind;
use crate::base::{FileId, IdGen};
use crate::syntax::lexer::{LexOutput, lex};
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::parse;
use crate::syntax::token::{Token, TokenKind, TokenValue};

/// 整形の前のソース `before` と後のソース `after` を比べる。一致して `after` に構文の誤りがなければ `Ok(())`、
/// そうでなければ、最初に見つけた食い違い（字句の添字と両方の字句、またはコメント、または構文の誤りの文言）を
/// 説明する文字列を返す。
pub fn verify(before: &[u8], after: &[u8], kind: SourceKind) -> Result<(), String> {
    let lexed_before = lex(FileId(0), before);
    let lexed_after = lex(FileId(0), after);
    let tokens_before = resolve_newlines(lexed_before.tokens);
    let tokens_after = resolve_newlines(lexed_after.tokens.clone());
    compare_tokens(
        before,
        without_final_newline(&tokens_before),
        after,
        without_final_newline(&tokens_after),
    )?;
    // コメントの並び（種類と、行末の空白を除いた本文）。
    let count = lexed_before.comments.len().max(lexed_after.comments.len());
    for i in 0..count {
        let b = lexed_before.comments.get(i);
        let a = lexed_after.comments.get(i);
        let same = match (b, a) {
            (Some(b), Some(a)) => {
                b.kind == a.kind
                    && b.text.trim_end_matches([' ', '\t']) == a.text.trim_end_matches([' ', '\t'])
            }
            _ => false,
        };
        if !same {
            return Err(format!(
                "comment {i} differs: before {:?}, after {:?}",
                b.map(|c| (c.kind, &c.text)),
                a.map(|c| (c.kind, &c.text))
            ));
        }
    }
    // ドキュメントコメントと宣言の結び付きは行の隣り合いで決まるので、構文解析で確かめる。
    check_syntax(after, kind, lexed_after, tokens_after)
}

fn check_syntax(
    after: &[u8],
    kind: SourceKind,
    lexed: LexOutput,
    tokens: Vec<Token>,
) -> Result<(), String> {
    // 字句と構文の誤り（E01nn・E02nn）だけを失敗にする。そのほかの診断は整形の前のソースにもあったもの
    // である（10-17「整形後の検証」、ADR 0333 の決定 1）。
    if let Some(d) = lexed.diagnostics.iter().find(|d| is_syntax_error(d)) {
        return Err(format!("lexical error after formatting: {}", d.message));
    }
    let parsed = parse(
        FileId(0),
        kind,
        after,
        tokens,
        lexed.comments,
        &mut IdGen::new(),
    );
    match parsed.diagnostics.iter().find(|d| is_syntax_error(d)) {
        Some(d) => Err(format!("syntax error after formatting: {}", d.message)),
        None => Ok(()),
    }
}

/// `Eof` の直前の NEWLINE を除いた列。整形はファイルを改行一つで終える（06-03「行末と文字」）ので、最後の行に
/// 改行のなかったソースでは `Eof` の直前に NEWLINE が加わる。この NEWLINE は文を区切らないので比べない。
fn without_final_newline(tokens: &[Token]) -> Vec<&Token> {
    let mut list: Vec<&Token> = tokens.iter().collect();
    let len = list.len();
    if len >= 2
        && list
            .get(len.saturating_sub(2))
            .is_some_and(|t| t.kind == TokenKind::Newline)
        && list.last().is_some_and(|t| t.kind == TokenKind::Eof)
    {
        list.remove(len.saturating_sub(2));
    }
    list
}

/// 比べる字句の鍵。文字列の字句は値、NEWLINE と `Eof` は種類だけ、ほかは字面（06-03「整形後の検証」）。
#[derive(PartialEq, Debug)]
enum Key<'a> {
    Value(&'a TokenValue),
    KindOnly,
    Text(&'a [u8]),
}

fn key<'a>(text: &'a [u8], token: &'a Token) -> Key<'a> {
    if matches!(
        token.kind,
        TokenKind::StringLit | TokenKind::StrStart | TokenKind::StrMid | TokenKind::StrEnd
    ) {
        Key::Value(&token.value)
    } else if matches!(
        token.kind,
        TokenKind::Newline | TokenKind::LineBreak | TokenKind::Eof
    ) {
        Key::KindOnly
    } else {
        Key::Text(slice(text, token))
    }
}

fn slice<'a>(text: &'a [u8], token: &Token) -> &'a [u8] {
    let start = usize::try_from(token.span.start.0).unwrap_or(usize::MAX);
    let end = usize::try_from(token.span.end.0).unwrap_or(usize::MAX);
    text.get(start..end).unwrap_or(&[])
}

fn compare_tokens(
    before: &[u8],
    tokens_before: Vec<&Token>,
    after: &[u8],
    tokens_after: Vec<&Token>,
) -> Result<(), String> {
    let count = tokens_before.len().max(tokens_after.len());
    for i in 0..count {
        let b = tokens_before.get(i).copied();
        let a = tokens_after.get(i).copied();
        let same = match (b, a) {
            (Some(b), Some(a)) => b.kind == a.kind && key(before, b) == key(after, a),
            _ => false,
        };
        if !same {
            let prev = i.checked_sub(1);
            return Err(format!(
                "token {i} differs: before {} (previous {}), after {} (previous {})",
                describe(before, b),
                describe(before, prev.and_then(|p| tokens_before.get(p).copied())),
                describe(after, a),
                describe(after, prev.and_then(|p| tokens_after.get(p).copied())),
            ));
        }
    }
    Ok(())
}

fn describe(text: &[u8], token: Option<&Token>) -> String {
    match token {
        Some(t) => format!("{:?} {:?}", t.kind, String::from_utf8_lossy(slice(text, t))),
        None => "none".to_owned(),
    }
}

#[cfg(test)]
mod tests;
