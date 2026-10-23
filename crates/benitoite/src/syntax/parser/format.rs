//! 補間の元ソースからの静的な書式の解析（設計書 01-02「文字列補間（初回リリース版）」、02-03「補間の入れ子」）。
use super::Parser;
use crate::base::{BytePos, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::{FormatAlign, FormatKind, FormatSign, FormatSpans, FormatSpec};
use crate::syntax::lexer::InterpolationId;
use crate::syntax::token::TokenKind;

/// 完全な式の直後のコロンと同じ補間の閉じがそろった範囲だけを確定する。
pub(super) fn parse_format(p: &mut Parser, owner: InterpolationId) -> Option<Box<FormatSpec>> {
    let start = p.peek().span.start;
    let mut nesting = 0_usize;
    let mut close = None;
    for (index, token) in p.tokens.iter().enumerate().skip(p.pos.saturating_add(1)) {
        if token.kind == TokenKind::StrStart {
            nesting = nesting.saturating_add(1);
        } else if matches!(token.kind, TokenKind::StrMid | TokenKind::StrEnd) && nesting == 0 {
            close = Some((index, token.span.start));
            break;
        } else if token.kind == TokenKind::StrEnd {
            nesting = nesting.saturating_sub(1);
        } else if token.kind == TokenKind::Eof {
            break;
        }
    }
    let (index, end) = close?;
    let span = Span {
        file: p.file,
        start,
        end,
    };
    p.formats.insert(owner, span);
    // BadSymbol の通常の診断や <- の束縛の診断を発生させず、生の範囲を専用解析へ渡す。
    let first = p.pos.saturating_add(1);
    p.pos = index;
    let begin = usize::try_from(start.0).ok()?.saturating_add(1);
    let end = usize::try_from(end.0).ok()?;
    // 置換文字を挿入すると元のバイト位置とずれる。E0102 は字句解析の報告を残す。
    let raw = std::str::from_utf8(p.text.get(begin..end)?).ok()?;
    if !raw.is_ascii() {
        // 字句にならなかった非 ASCII 文字は字句解析が報告済みである（02-03「字句」）。
        // リテラル内の非 ASCII 文字は字句の範囲に入るため、書式の誤りとして検査する。
        let mut previous = begin;
        for token in p.tokens.get(first..index).unwrap_or_default() {
            let next = usize::try_from(token.span.start.0).ok()?;
            if !p.text.get(previous..next)?.is_ascii() {
                return None;
            }
            previous = usize::try_from(token.span.end.0).ok()?;
        }
        if !p.text.get(previous..end)?.is_ascii() {
            return None;
        }
    }
    match read_spec(raw, span) {
        Ok(spec) => Some(Box::new(spec)),
        Err(error) => {
            let mut diagnostic = DiagBuilder::new(DiagCode::E0262).primary(error.span);
            diagnostic = if let Some(edit) = error.edit {
                diagnostic.help_edits(error.reason, vec![edit])
            } else {
                diagnostic.help(error.reason)
            };
            p.report(diagnostic.build());
            None
        }
    }
}

struct Invalid {
    span: Span,
    reason: &'static str,
    edit: Option<Edit>,
}
struct Reader<'a> {
    text: &'a str,
    span: Span,
    pos: usize,
}
impl Reader<'_> {
    fn span(&self, start: usize, end: usize) -> Span {
        let offset = self.span.start.0.saturating_add(1);
        Span {
            file: self.span.file,
            start: BytePos(offset.saturating_add(u32::try_from(start).unwrap_or(u32::MAX))),
            end: BytePos(offset.saturating_add(u32::try_from(end).unwrap_or(u32::MAX))),
        }
    }
    fn invalid(&self, reason: &'static str, start: usize, end: usize) -> Invalid {
        Invalid {
            span: self.span(start, end),
            reason,
            edit: None,
        }
    }
    fn take(&mut self, byte: u8) -> Option<Span> {
        if self.text.as_bytes().get(self.pos) != Some(&byte) {
            return None;
        }
        let start = self.pos;
        self.pos = self.pos.saturating_add(1);
        Some(self.span(start, self.pos))
    }
    fn byte(&self) -> Option<u8> {
        self.text.as_bytes().get(self.pos).copied()
    }
    fn digits(&mut self, limit: &str, reason: &'static str) -> Result<(u16, Span), Invalid> {
        let start = self.pos;
        while self.byte().is_some_and(|c| c.is_ascii_digit()) {
            self.pos = self.pos.saturating_add(1);
        }
        let digits = self.text.get(start..self.pos).unwrap_or("");
        let significant = digits.trim_start_matches('0');
        // ホスト整数へ変換する前に数字列で上限を比べる。先頭の零も仕事量を増幅しない。
        if digits.is_empty()
            || significant.len() > limit.len()
            || significant.len() == limit.len() && significant > limit
        {
            return Err(self.invalid(reason, start, self.pos));
        }
        let value = significant.bytes().fold(0_u16, |n, d| {
            n.saturating_mul(10)
                .saturating_add(u16::from(d.saturating_sub(b'0')))
        });
        Ok((value, self.span(start, self.pos)))
    }
}

fn read_spec(text: &str, span: Span) -> Result<FormatSpec, Invalid> {
    read_spec_inner(text, span).map_err(|mut error| {
        // 空書式ではコロンごと消す。それ以外の編集は、一度の再検査で有効になるものに限る。
        if !text.is_empty()
            && let Some(edit) = &error.edit
        {
            let offset = span.start.0.saturating_add(1);
            let range = usize::try_from(edit.span.start.0.saturating_sub(offset))
                .ok()
                .zip(usize::try_from(edit.span.end.0.saturating_sub(offset)).ok());
            let fixed = range.and_then(|(start, end)| {
                Some(format!(
                    "{}{}{}",
                    text.get(..start)?,
                    edit.replacement,
                    text.get(end..)?
                ))
            });
            if fixed.is_none_or(|fixed| read_spec_inner(&fixed, span).is_err()) {
                error.edit = None;
            }
        }
        error
    })
}

fn read_spec_inner(text: &str, span: Span) -> Result<FormatSpec, Invalid> {
    let mut r = Reader { text, span, pos: 0 };
    if text.is_empty() {
        return Err(Invalid {
            span,
            reason: "empty",
            edit: Some(Edit {
                span,
                replacement: String::new(),
            }),
        });
    }
    // 普通の字句では失われる空白を、元の UTF-8 の位置で報告する。
    if let Some((start, ch)) = text
        .char_indices()
        .find(|(_, c)| c.is_whitespace() || *c == '-')
    {
        let end = start.saturating_add(ch.len_utf8());
        let span = r.span(start, end);
        return Err(Invalid {
            span,
            reason: if ch == '-' { "minus" } else { "whitespace" },
            edit: Some(Edit {
                span: r.span(0, text.len()),
                replacement: text
                    .chars()
                    .filter(|c| !c.is_whitespace() && *c != '-')
                    .collect(),
            }),
        });
    }
    let mut spec = FormatSpec {
        span,
        kind: FormatKind::Default,
        align: FormatAlign::Default,
        sign: FormatSign::Default,
        alternate: false,
        zero: false,
        width: None,
        precision: None,
        spans: FormatSpans::default(),
    };
    if let Some((byte, align)) = match r.byte() {
        Some(b'<') => Some((b'<', FormatAlign::Left)),
        Some(b'>') => Some((b'>', FormatAlign::Right)),
        Some(b'^') => Some((b'^', FormatAlign::Center)),
        _ => None,
    } {
        spec.align = align;
        spec.spans.align = r.take(byte);
    }
    spec.spans.sign = r.take(b'+');
    if spec.spans.sign.is_some() {
        spec.sign = FormatSign::Plus;
    }
    spec.spans.alternate = r.take(b'#');
    spec.alternate = spec.spans.alternate.is_some();
    spec.spans.zero = r.take(b'0');
    spec.zero = spec.spans.zero.is_some();
    if r.byte().is_some_and(|c| c.is_ascii_digit()) {
        let starts_with_zero = r.byte() == Some(b'0');
        let (width, at) = r.digits("65535", "width")?;
        if starts_with_zero || width == 0 {
            return Err(Invalid {
                span: at,
                reason: "width",
                edit: None,
            });
        }
        spec.width = Some(width);
        spec.spans.width = Some(at);
    }
    if let Some(dot) = r.take(b'.') {
        let (precision, at) = r.digits("28", "precision")?;
        spec.precision = Some(u8::try_from(precision).unwrap_or(u8::MAX));
        spec.spans.precision = Some(dot.to(at));
    }
    if let Some(byte) = r.byte() {
        spec.kind = match byte {
            b'd' => FormatKind::D,
            b'b' => FormatKind::B,
            b'o' => FormatKind::O,
            b'x' => FormatKind::X,
            b'X' => FormatKind::UpperX,
            b'f' => FormatKind::F,
            b's' => FormatKind::S,
            b'c' => FormatKind::C,
            _ => {
                return Err(r.invalid(
                    "kind",
                    r.pos,
                    r.pos.saturating_add(
                        text.get(r.pos..)
                            .and_then(|s| s.chars().next())
                            .map_or(0, char::len_utf8),
                    ),
                ));
            }
        };
        spec.spans.kind = r.take(byte);
    }
    if r.pos != text.len() {
        return Err(r.invalid("kind", r.pos, text.len()));
    }
    if spec.precision.is_some() && spec.kind != FormatKind::F {
        let at = spec.spans.kind.or(spec.spans.precision).unwrap_or(span);
        return Err(Invalid {
            span: at,
            reason: "fixed",
            edit: (spec.kind == FormatKind::Default).then(|| Edit {
                span: Span {
                    start: span.end,
                    ..span
                },
                replacement: "f".into(),
            }),
        });
    }
    for (invalid, at, reason) in [
        (
            spec.align != FormatAlign::Default && spec.width.is_none(),
            spec.spans.align,
            "align_width",
        ),
        (
            spec.zero && spec.width.is_none(),
            spec.spans.zero,
            "zero_width",
        ),
        (
            spec.zero && spec.align != FormatAlign::Default,
            spec.spans.zero,
            "zero_align",
        ),
        (
            spec.alternate
                && !matches!(
                    spec.kind,
                    FormatKind::B | FormatKind::O | FormatKind::X | FormatKind::UpperX
                ),
            spec.spans.alternate,
            "alternate",
        ),
    ] {
        if invalid {
            return Err(Invalid {
                span: at.unwrap_or(span),
                reason,
                edit: None,
            });
        }
    }
    Ok(spec)
}
