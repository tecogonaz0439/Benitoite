//! 改行の判定（設計書 02-03「処理の流れ」の工程 2、01-01「改行による区切り」）。
//!
//! 字句の切り出しが作った改行の印 `LineBreak` ごとに、文の区切り NEWLINE を置くか、
//! 空白として捨てるかを決める。構文解析器は、文の区切りを NEWLINE だけで知る。

use super::token::{Token, TokenKind, TokenValue};

/// 改行の印ごとに、NEWLINE を置くか空白として捨てるかを決める（01-01「改行による区切り」）。
/// 入力は `lex` の字句の列。出力は `LineBreak` を含まない。連続する NEWLINE は一つにまとめる。
pub fn resolve_newlines(tokens: Vec<Token>) -> Vec<Token> {
    let mut out: Vec<Token> = Vec::with_capacity(tokens.len());
    // 開いている括弧の種類の積み重ね。規則 1 は最も内側の括弧だけを見る（01-01）。
    let mut brackets: Vec<TokenKind> = Vec::new();
    // まとめている最中の改行の最初の印。連続する印は一つの改行として判定する
    // （01-01「コメントだけの行と空の行は、判定の上では存在しないものとして扱う」）。
    // span を最初の印に揃えるのは、`{` を次の行に書いた誤り（E0205）を改行の位置で示すため。
    let mut pending: Option<Token> = None;

    for token in tokens {
        if token.kind == TokenKind::LineBreak {
            if pending.is_none() {
                pending = Some(token);
            }
            continue;
        }
        if let Some(first_break) = pending.take() {
            // 直前の字句は出力の最後の字句である。NEWLINE を置いた直後には必ず字句を置くので、
            // 出力の最後が NEWLINE であることはなく、NEWLINE は連続しない。
            // 直前の字句がないもの（ファイルの先頭の改行）は捨てる。
            if let Some(prev) = out.last()
                && keeps_newline(brackets.last(), prev.kind, token.kind)
            {
                out.push(Token {
                    kind: TokenKind::Newline,
                    span: first_break.span,
                    value: TokenValue::None,
                });
            }
        }
        track_bracket(&mut brackets, token.kind);
        out.push(token);
    }
    // 入力は必ず Eof で終わる（10-03 の LexOutput）ので、まとめかけの改行は残らない。
    out
}

/// 括弧の積み重ねを更新する。対応しない閉じ括弧は無視する（対応の誤りは構文解析器が報告する）。
fn track_bracket(brackets: &mut Vec<TokenKind>, kind: TokenKind) {
    use TokenKind as K;
    if matches!(kind, K::LParen | K::LBracket | K::LBrace) {
        brackets.push(kind);
        return;
    }
    let open = if kind == K::RParen {
        K::LParen
    } else if kind == K::RBracket {
        K::LBracket
    } else if kind == K::RBrace {
        K::LBrace
    } else {
        return;
    };
    if brackets.last() == Some(&open) {
        brackets.pop();
    }
}

/// 01-01 の規則 1〜4 を順に当て、NEWLINE を置くなら true を返す。
fn keeps_newline(innermost: Option<&TokenKind>, prev: TokenKind, next: TokenKind) -> bool {
    // 規則 1: 丸括弧か角括弧の中では、改行は区切りにならない。
    if matches!(innermost, Some(TokenKind::LParen | TokenKind::LBracket)) {
        return false;
    }
    // 規則 2: 行が続きを要求する字句で終わっている。
    if continues_after(prev) {
        return false;
    }
    // 規則 3: 次の行が前の行に続く字句で始まっている。
    if continues_before(next) {
        return false;
    }
    // 規則 4
    true
}

/// 二項演算子（01-01 の規則 2・3 が共有する一覧。`-` を含む）。
fn is_binary_operator(kind: TokenKind) -> bool {
    use TokenKind as K;
    matches!(
        kind,
        K::Plus
            | K::Minus
            | K::Star
            | K::Slash
            | K::Percent
            | K::EqEq
            | K::BangEq
            | K::Lt
            | K::Le
            | K::Gt
            | K::Ge
            | K::AndAnd
            | K::OrOr
            | K::PipeGt
    )
}

/// 規則 2 の一覧。初回リリース版のキーワードは最小実行版の字句にないので含めない。
fn continues_after(kind: TokenKind) -> bool {
    use TokenKind as K;
    is_binary_operator(kind)
        || matches!(
            kind,
            K::Bang
                | K::Eq
                | K::Arrow
                | K::FatArrow
                | K::Colon
                | K::Comma
                | K::Dot
                | K::LParen
                | K::LBracket
                | K::LBrace
                | K::KwElse
                | K::KwFn
                | K::KwIf
                | K::KwLet
                | K::KwMatch
                | K::KwType
                | K::KwUses
        )
}

/// 規則 3 の一覧。`-` は単項の負号として行を始められるので除く（01-01）。
fn continues_before(kind: TokenKind) -> bool {
    use TokenKind as K;
    (is_binary_operator(kind) && kind != K::Minus)
        || matches!(kind, K::Dot | K::Arrow | K::FatArrow | K::KwElse)
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
    use super::*;
    use crate::base::FileId;
    use crate::syntax::lexer::lex;
    use TokenKind as K;

    fn run(src: &str) -> Vec<Token> {
        let out = resolve_newlines(lex(FileId(0), src.as_bytes()).tokens);
        // すべての入力で、LineBreak が残らず、Newline が連続しないことを確かめる。
        assert!(out.iter().all(|t| t.kind != K::LineBreak), "{src:?}");
        assert!(
            out.windows(2)
                .all(|w| !(w[0].kind == K::Newline && w[1].kind == K::Newline)),
            "{src:?}"
        );
        out
    }

    fn kinds(src: &str) -> Vec<TokenKind> {
        run(src).into_iter().map(|t| t.kind).collect()
    }

    #[test]
    fn places_newline_by_rules() {
        use K::*;
        let cases: &[(&str, Vec<TokenKind>)] = &[
            // 規則 3
            (
                "let total = price\n  * quantity",
                vec![KwLet, LowerIdent, Eq, LowerIdent, Star, LowerIdent, Eof],
            ),
            (
                "let n = lines\n  |> List.filter(fn(l) { l != \"\" })\n  |> List.length",
                vec![
                    KwLet, LowerIdent, Eq, LowerIdent, PipeGt, UpperIdent, Dot, LowerIdent, LParen,
                    KwFn, LParen, LowerIdent, RParen, LBrace, LowerIdent, BangEq, StringLit,
                    RBrace, RParen, PipeGt, UpperIdent, Dot, LowerIdent, Eof,
                ],
            ),
            // 規則 2（`{` の後）、規則 3（`else` の前）、規則 4（`start()` の後）
            (
                "if ready {\n  start()\n} else {\n  wait()\n}",
                vec![
                    KwIf, LowerIdent, LBrace, LowerIdent, LParen, RParen, Newline, RBrace, KwElse,
                    LBrace, LowerIdent, LParen, RParen, Newline, RBrace, Eof,
                ],
            ),
            // E0205 の元になる形
            (
                "fn double(x: Int) -> Int\n{",
                vec![
                    KwFn, LowerIdent, LParen, LowerIdent, Colon, UpperIdent, RParen, Arrow,
                    UpperIdent, Newline, LBrace, Eof,
                ],
            ),
            // 規則 1
            (
                "f(a,\n  b)",
                vec![
                    LowerIdent, LParen, LowerIdent, Comma, LowerIdent, RParen, Eof,
                ],
            ),
            (
                "[1,\n 2]",
                vec![LBracket, IntLit, Comma, IntLit, RBracket, Eof],
            ),
            // 規則 2・3 に当たらない位置でも、括弧の中なら捨てる
            ("[1\n 2]", vec![LBracket, IntLit, IntLit, RBracket, Eof]),
            (
                "{ f(a\n  b) }",
                vec![
                    LBrace, LowerIdent, LParen, LowerIdent, LowerIdent, RParen, RBrace, Eof,
                ],
            ),
            // `(` の中の `{` の中では規則 1 は当たらない
            (
                "(fn() { a\n b })",
                vec![
                    LParen, KwFn, LParen, RParen, LBrace, LowerIdent, Newline, LowerIdent, RBrace,
                    RParen, Eof,
                ],
            ),
            ("a +\n b", vec![LowerIdent, Plus, LowerIdent, Eof]),
            ("a\n- b", vec![LowerIdent, Newline, Minus, LowerIdent, Eof]),
            // 連続する改行は一つにまとめる
            (
                "a\n\n// comment\n\nb",
                vec![LowerIdent, Newline, LowerIdent, Eof],
            ),
            // ファイルの先頭の改行は捨て、終わりの改行は規則どおり置く
            ("\n// head\n\na\n", vec![LowerIdent, Newline, Eof]),
            // 対応しない閉じ括弧は積み重ねを変えない
            (
                "(a ]\n b)",
                vec![LParen, LowerIdent, RBracket, LowerIdent, RParen, Eof],
            ),
            (")\na", vec![RParen, Newline, LowerIdent, Eof]),
            // 誤りの字句（予約語）は普通の字句として残り、前後の改行は規則 4 で置く
            (
                "a\nwhile\nb",
                vec![LowerIdent, Newline, Error, Newline, LowerIdent, Eof],
            ),
        ];
        for (src, expected) in cases {
            assert_eq!(&kinds(src), expected, "{src:?}");
        }
    }

    #[test]
    fn newline_span_is_first_line_break() {
        let toks = run("a\n\n\nb");
        let nl = toks.iter().find(|t| t.kind == K::Newline).unwrap();
        assert_eq!(
            nl.span,
            crate::base::Span {
                file: FileId(0),
                start: crate::base::BytePos(1),
                end: crate::base::BytePos(2),
            }
        );
    }
}
