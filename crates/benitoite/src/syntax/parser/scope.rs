//! 範囲引数の字句と回復（設計書 02-03「型の解析」）。
use super::{PResult, Parser, text};
use crate::syntax::ast::{ScopeArg, ScopeArgKind, ScopeArgs};
use crate::syntax::token::{IntegerSuffix, Token, TokenKind, TokenValue};

pub(super) fn parse(p: &mut Parser, start: usize) -> PResult<ScopeArgs> {
    let mut items = Vec::new();
    while !p.at(TokenKind::RBracket) {
        let from = p.pos;
        let mut stack = Vec::new();
        let mut strings = 0_usize;
        loop {
            let kind = p.peek_kind();
            if matches!(kind, TokenKind::Eof | TokenKind::Newline) || p.aborted {
                return Err(p.unexpected(text::COMMA_OR_RBRACKET));
            }
            if strings == 0
                && stack.is_empty()
                && matches!(kind, TokenKind::Comma | TokenKind::RBracket)
            {
                break;
            }
            // 閉じ忘れで後続の宣言・本体まで読み込まない。式として拒否する候補だけを
            // 要素内に残し、構文の境界はその場で報告する（設計書 02-03「型の解析」）。
            if strings == 0
                && stack.is_empty()
                && p.pos > from
                && let (Some(previous), Some(next)) =
                    (p.tokens.get(p.pos.saturating_sub(1)), p.tokens.get(p.pos))
                && element_end(previous.kind)
                && next.start_line > previous.end_line
                && !matches!(kind, TokenKind::Comma | TokenKind::RBracket)
                && !binary_operator(kind)
            {
                return Err(p.unexpected(text::COMMA_OR_RBRACKET));
            }
            if strings == 0 && !element_token(kind) {
                return Err(p.unexpected(text::COMMA_OR_RBRACKET));
            }
            if strings == 0 && kind == TokenKind::LParen && p.pos > from {
                let previous = p.tokens.get(p.pos.saturating_sub(1)).map(|t| t.kind);
                if previous.is_some_and(|k| {
                    matches!(
                        k,
                        TokenKind::StringLit
                            | TokenKind::StrEnd
                            | TokenKind::IntLit
                            | TokenKind::FloatLit
                            | TokenKind::DecimalLit
                            | TokenKind::CharLit
                            | TokenKind::RParen
                            | TokenKind::RBracket
                    )
                }) {
                    return Err(p.unexpected(text::COMMA_OR_RBRACKET));
                }
            }
            if kind == TokenKind::StrStart {
                strings = strings.saturating_add(1);
            } else if kind == TokenKind::StrEnd {
                strings = strings.saturating_sub(1);
            } else if matches!(kind, TokenKind::LParen | TokenKind::LBracket) {
                stack.push(kind);
            } else if matches!(kind, TokenKind::RParen | TokenKind::RBracket) {
                let expected = if kind == TokenKind::RParen {
                    TokenKind::LParen
                } else {
                    TokenKind::LBracket
                };
                if stack.pop() != Some(expected) {
                    return Err(p.unexpected(text::COMMA_OR_RBRACKET));
                }
            }
            p.bump();
        }
        let kind = classify(p.tokens.get(from..p.pos).unwrap_or(&[]));
        items.push(ScopeArg {
            span: p.span_from(from),
            kind,
        });
        if !p.eat(TokenKind::Comma) {
            break;
        }
    }
    p.expect(TokenKind::RBracket)?;
    let len = items.len();
    Ok(ScopeArgs {
        span: p.span_from(start),
        items: items.into(),
        element: 0..len,
    })
}

fn element_token(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::StringLit
            | TokenKind::StrStart
            | TokenKind::StrMid
            | TokenKind::StrEnd
            | TokenKind::IntLit
            | TokenKind::FloatLit
            | TokenKind::DecimalLit
            | TokenKind::CharLit
            | TokenKind::KwTrue
            | TokenKind::KwFalse
            | TokenKind::LowerIdent
            | TokenKind::UpperIdent
            | TokenKind::Dot
            | TokenKind::DotDot
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
            | TokenKind::KwAnd
            | TokenKind::KwOr
            | TokenKind::KwDiv
            | TokenKind::KwMod
            | TokenKind::KwNot
            | TokenKind::Amp
            | TokenKind::At
            | TokenKind::Colon
            | TokenKind::Comma
            | TokenKind::Underscore
            | TokenKind::LParen
            | TokenKind::RParen
            | TokenKind::LBracket
            | TokenKind::RBracket
    )
}

// 物理行をまたいで次の要素や本体を飲み込まないための終端。
fn element_end(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::StringLit
            | TokenKind::StrEnd
            | TokenKind::IntLit
            | TokenKind::FloatLit
            | TokenKind::DecimalLit
            | TokenKind::CharLit
            | TokenKind::KwTrue
            | TokenKind::KwFalse
            | TokenKind::LowerIdent
            | TokenKind::UpperIdent
            | TokenKind::RParen
            | TokenKind::RBracket
    )
}
fn binary_operator(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::PipeGt
            | TokenKind::KwOr
            | TokenKind::KwAnd
            | TokenKind::Eq
            | TokenKind::NotEq
            | TokenKind::Lt
            | TokenKind::Le
            | TokenKind::Gt
            | TokenKind::Ge
            | TokenKind::Plus
            | TokenKind::Minus
            | TokenKind::Star
            | TokenKind::Slash
            | TokenKind::KwDiv
            | TokenKind::KwMod
    )
}

fn classify(tokens: &[Token]) -> ScopeArgKind {
    match tokens {
        [
            Token {
                kind: TokenKind::StringLit,
                value: TokenValue::Str(s),
                ..
            },
        ] => ScopeArgKind::String(s.clone()),
        [one] if one.kind == TokenKind::IntLit => {
            integer(one).map_or(ScopeArgKind::Invalid, |n| ScopeArgKind::Port(n, None))
        }
        [lo, dots, hi]
            if lo.kind == TokenKind::IntLit
                && dots.kind == TokenKind::DotDot
                && hi.kind == TokenKind::IntLit =>
        {
            match (integer(lo), integer(hi)) {
                (Some(lo), Some(hi)) => ScopeArgKind::Port(lo, Some(hi)),
                _ => ScopeArgKind::Invalid,
            }
        }
        _ => ScopeArgKind::Invalid,
    }
}
fn integer(token: &Token) -> Option<String> {
    let (radix, digits, maximum) = match &token.value {
        TokenValue::Int { radix, digits } => (*radix, digits, u64::try_from(i64::MAX).ok()?),
        TokenValue::WidthInt {
            radix,
            digits,
            suffix,
        } => {
            let maximum = match suffix {
                IntegerSuffix::S8 => u64::try_from(i8::MAX).ok()?,
                IntegerSuffix::S16 => u64::try_from(i16::MAX).ok()?,
                IntegerSuffix::S32 => u64::try_from(i32::MAX).ok()?,
                IntegerSuffix::S64 => u64::try_from(i64::MAX).ok()?,
                IntegerSuffix::U8 => u64::from(u8::MAX),
                IntegerSuffix::U16 => u64::from(u16::MAX),
                IntegerSuffix::U32 => u64::from(u32::MAX),
                IntegerSuffix::U64 => u64::MAX,
            };
            (*radix, digits, maximum)
        }
        TokenValue::None
        | TokenValue::Ident(_)
        | TokenValue::Float(_)
        | TokenValue::WidthFloat { .. }
        | TokenValue::Decimal(_)
        | TokenValue::Str(_)
        | TokenValue::Char(_)
        | TokenValue::Symbol(_) => return None,
    };
    let n = u64::from_str_radix(digits, radix).ok()?;
    (n <= maximum).then(|| n.to_string())
}
