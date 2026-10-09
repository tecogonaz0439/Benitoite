//! 他の言語の記号と書き方への診断（設計書 02-03「他の言語の書き方への診断」）。
use super::{Parser, text};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::token::TokenKind;

/// `fn` は予約語でないので、普通の呼び出しと区別する（設計書 02-03「他の言語の書き方への診断」）。
pub(super) fn fn_lambda_ahead(p: &Parser) -> bool {
    if !p.word("fn") || p.peek_nth_kind(1) != TokenKind::LParen {
        return false;
    }
    let mut parens = 0_u32;
    for (offset, token) in p.tokens.iter().skip(p.pos.saturating_add(1)).enumerate() {
        if token.kind == TokenKind::LParen {
            parens = parens.saturating_add(1);
        } else if token.kind == TokenKind::RParen {
            parens = parens.saturating_sub(1);
            if parens == 0 {
                return p
                    .tokens
                    .get(p.pos.saturating_add(offset).saturating_add(2))
                    .is_some_and(|t| p.snippet(t.span) == "{");
            }
        } else if token.kind == TokenKind::Eof {
            break;
        }
    }
    false
}

/// 対応する閉じ括弧まで一つの旧式として読み飛ばし、派生した E0212 を抑える
/// （設計書 02-03「他の言語の書き方への診断」、07-03「派生した診断が出ないことのテスト」）。
pub(super) fn fn_form(p: &mut Parser, key: &'static str) {
    let keyword = p.bump().span;
    let header = p.pos;
    while !p.at(TokenKind::Eof) && !p.symbol("{") {
        if p.at_line_start() && super::is_decl_start(p.peek_kind()) {
            break;
        }
        p.advance();
    }
    let signature = p.snippet(p.span_from(header)).trim().to_owned();
    if p.symbol("{") {
        p.reported_symbols.insert(p.pos);
        p.advance();
        let mut braces = 1_u32;
        while !p.at(TokenKind::Eof) {
            // 閉じ波括弧が欠けても、後の宣言の独立した誤りを報告できるようにする
            // （設計書 02-03「誤りからの回復」）。
            if p.at_line_start() && super::is_decl_start(p.peek_kind()) {
                break;
            }
            if p.symbol("{") {
                braces = braces.saturating_add(1);
                p.reported_symbols.insert(p.pos);
            } else if p.symbol("}") {
                braces = braces.saturating_sub(1);
                p.reported_symbols.insert(p.pos);
                if braces == 0 {
                    p.advance();
                    break;
                }
            }
            p.advance();
        }
    }
    p.report(
        DiagBuilder::new(DiagCode::E0251)
            .arg("signature", signature)
            .primary(keyword)
            .help(key)
            .build(),
    );
}

/// 文脈で選んだ診断を、同じ記号には一度だけ出す。抑制の対象にしない（02-03）。
pub(super) fn report_symbol(p: &mut Parser, diagnostic: crate::diag::Diagnostic) {
    if !p.aborted && p.reported_symbols.insert(p.pos) {
        p.diagnostics.push(diagnostic);
    }
}

pub(super) fn operator(p: &mut Parser, key: &'static str, replacement: Option<&str>) {
    let mut d = DiagBuilder::new(DiagCode::E0211)
        .arg("symbol", p.snippet(p.peek().span))
        .primary(p.peek().span);
    d = if let Some(replacement) = replacement {
        d.help_edits(
            key,
            vec![Edit {
                span: p.peek().span,
                replacement: operator_replacement(p, replacement),
            }],
        )
    } else {
        d.help(key)
    };
    report_symbol(p, d.build());
}

fn operator_replacement(p: &Parser, replacement: &str) -> String {
    let span = p.peek().span;
    let before = usize::try_from(span.start.0)
        .ok()
        .and_then(|start| start.checked_sub(1))
        .and_then(|index| p.text.get(index));
    let after = usize::try_from(span.end.0)
        .ok()
        .and_then(|index| p.text.get(index));
    let name_char = |byte: &u8| byte.is_ascii_alphanumeric() || *byte == b'_';
    // 記号の前後には空白がなくてもよい。語に置き換えるときは隣の識別子や数字と
    // 結合させず、修正案を当てた後も別の字句として読めるようにする
    // （設計書 01-01「字句の種類」「数値リテラルの直後の文字」、02-10「修正案」）。
    let prefix =
        if replacement.as_bytes().first().is_some_and(name_char) && before.is_some_and(name_char) {
            " "
        } else {
            ""
        };
    let suffix =
        if replacement.as_bytes().last().is_some_and(name_char) && after.is_some_and(name_char) {
            " "
        } else {
            ""
        };
    format!("{prefix}{replacement}{suffix}")
}

/// 読み飛ばす場合も未報告の記号をここで報告する（02-03「誤りからの回復」）。
pub(super) fn report_unclaimed(p: &mut Parser) {
    if !p.at(crate::syntax::token::TokenKind::BadSymbol) || p.reported_symbols.contains(&p.pos) {
        return;
    }
    let symbol = p.snippet(p.peek().span);
    let span = p.peek().span;
    let d = match symbol.as_str() {
        ";" => {
            let end = usize::try_from(span.end.0).unwrap_or(usize::MAX);
            let rest = p.text.get(end..).unwrap_or_default();
            let trimmed = rest
                .iter()
                .position(|b| !matches!(b, b' ' | b'\t' | b'\r'))
                .and_then(|i| rest.get(i..))
                .unwrap_or_default();
            let replacement =
                if trimmed.is_empty() || trimmed.starts_with(b"\n") || trimmed.starts_with(b"//") {
                    ""
                } else {
                    "\n"
                };
            DiagBuilder::new(DiagCode::E0106)
                .primary(span)
                .help_edits(
                    "newline",
                    vec![Edit {
                        span,
                        replacement: replacement.to_owned(),
                    }],
                )
                .build()
        }
        "{" => DiagBuilder::new(DiagCode::E0212)
            .primary(span)
            .help("open")
            .build(),
        "}" if !p.blocks.is_empty() => DiagBuilder::new(DiagCode::E0212)
            .arg(
                "construct",
                p.blocks
                    .last()
                    .and_then(|b| text::keyword(b.kind))
                    .unwrap_or_default(),
            )
            .primary(span)
            .help("end")
            .build(),
        "}" => DiagBuilder::new(DiagCode::E0212).primary(span).build(),
        "==" | "!=" | "&&" | "||" | "!" | "=>" | "%" | "?" => DiagBuilder::new(DiagCode::E0211)
            .arg("symbol", &symbol)
            .primary(span)
            .help(match symbol.as_str() {
                "==" => "equal",
                "!=" => "not_equal",
                "&&" => "and",
                "||" => "or",
                "!" => "not",
                "=>" => "fat_arrow",
                "%" => "remainder",
                _ => "question",
            })
            .build(),
        _ => DiagBuilder::new(DiagCode::E0105)
            .arg("symbol", symbol)
            .primary(span)
            .build(),
    };
    report_symbol(p, d);
}

/// F04 のハンドラも同じ位置で旧式の `when` を検出する。
pub(super) fn take_when(p: &mut Parser) -> Option<Span> {
    if when_ahead(p) {
        Some(p.bump().span)
    } else {
        None
    }
}

/// `when` は予約しないので、本体の名前や呼び出しを旧式の分岐と取り違えない。
/// 括弧の外の `:` まである形だけを分岐の始まりとする（設計書 01-02「パターンマッチ」）。
pub(super) fn when_ahead(p: &Parser) -> bool {
    use crate::syntax::token::TokenKind;
    if !p.word("when") {
        return false;
    }
    let mut nesting = 0_u32;
    for token in p.tokens.get(p.pos.saturating_add(1)..).unwrap_or_default() {
        if nesting == 0 && token.kind == TokenKind::Colon {
            return true;
        }
        if nesting == 0
            && matches!(
                token.kind,
                TokenKind::Newline | TokenKind::KwEnd | TokenKind::Eof | TokenKind::Arrow
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

pub(super) fn report_when(p: &mut Parser, span: Span, pattern: Span) {
    p.report(
        DiagBuilder::new(DiagCode::E0232)
            .arg("pattern", p.snippet(pattern))
            .primary(span)
            .help("case")
            .build(),
    );
}

pub(super) fn return_arrow(p: &mut Parser) -> super::PResult<()> {
    use crate::syntax::token::TokenKind;
    if p.at(TokenKind::Colon) {
        let span = p.bump().span;
        p.report(
            DiagBuilder::new(DiagCode::E0234)
                .primary(span)
                .help_edits(
                    "arrow",
                    vec![Edit {
                        span,
                        replacement: "->".to_owned(),
                    }],
                )
                .build(),
        );
        Ok(())
    } else {
        p.expect(TokenKind::Arrow).map(|_| ())
    }
}
