//! 改行の判定（設計書 01-01「改行による区切り」、02-03「処理の流れ」の工程 2）。
//! 閉じ方の誤りでは一致する開きまで戻し、診断は構文解析器に委ねる。

use super::token::{Token, TokenKind};

#[derive(Clone, Copy)]
struct Opening {
    kind: TokenKind,
    depth: usize,
    /// 分岐の頭の括弧の深さ。内側の式の `if` とガードを区別する。
    guard: Option<usize>,
}

/// 改行の印ごとに、NEWLINE を置くか空白として捨てるかを決める（01-01「改行による区切り」）。
/// 入力は `lex` の字句の列。出力は `LineBreak` を含まない。連続する NEWLINE は一つにまとめる。
pub fn resolve_newlines(tokens: Vec<Token>) -> Vec<Token> {
    use TokenKind as K;
    let mut output: Vec<Token> = Vec::with_capacity(tokens.len());
    let mut stack: Vec<Opening> = Vec::new();
    let mut previous = None;
    let mut previous_is_end_word = false;
    let mut depth = 0usize;
    let mut input = tokens.iter().peekable();
    while let Some(token) = input.next() {
        let mut token = token.clone();
        let kind = token.kind;
        if kind == K::LineBreak {
            while input.peek().is_some_and(|t| t.kind == K::LineBreak) {
                input.next();
            }
            let next = input.peek().map(|t| t.kind);
            let in_parens = stack
                .last()
                .is_some_and(|o| matches!(o.kind, K::LParen | K::LBracket));
            let keep = previous.is_some()
                && !in_parens
                && (previous_is_end_word || !previous.is_some_and(continues_after))
                && !next.is_some_and(continues_before);
            if keep && output.last().is_none_or(|t| t.kind != K::Newline) {
                token.kind = K::Newline;
                output.push(token);
            }
            continue;
        }
        let end_word = previous == Some(K::KwEnd) && is_keyword(kind);
        if end_word {
            close(&mut stack, kind, &mut depth);
        } else {
            if matches!(kind, K::LParen | K::LBracket) {
                depth = depth.saturating_add(1);
                stack.push(Opening {
                    kind,
                    depth,
                    guard: None,
                });
            } else if kind == K::RParen {
                close(&mut stack, K::LParen, &mut depth);
            } else if kind == K::RBracket {
                close(&mut stack, K::LBracket, &mut depth);
            } else if kind == K::KwCase {
                if let Some(top) = stack
                    .last_mut()
                    .filter(|o| matches!(o.kind, K::KwMatch | K::KwHandle))
                {
                    top.guard = Some(depth);
                }
            } else if kind == K::Arrow {
                if let Some(top) = stack.last_mut().filter(|o| o.guard == Some(depth)) {
                    top.guard = None;
                }
            } else if kind == K::KwIf {
                let guard = stack.last().is_some_and(|o| o.guard == Some(depth));
                if previous != Some(K::KwElse) && !guard {
                    stack.push(Opening {
                        kind,
                        depth,
                        guard: None,
                    });
                }
            } else if kind == K::KwWith {
                let next = input
                    .clone()
                    .find(|t| t.kind != K::LineBreak)
                    .map(|t| t.kind);
                if next != Some(K::KwCase) {
                    stack.push(Opening {
                        kind,
                        depth,
                        guard: None,
                    });
                }
            } else if matches!(kind, K::KwLambda | K::KwMatch | K::KwLazy | K::KwHandle) {
                stack.push(Opening {
                    kind,
                    depth,
                    guard: None,
                });
            }
        }
        previous = Some(kind);
        previous_is_end_word = end_word;
        output.push(token);
    }
    output
}

fn is_keyword(kind: TokenKind) -> bool {
    use TokenKind as K;
    matches!(
        kind,
        K::KwAnd
            | K::KwBind
            | K::KwCase
            | K::KwConst
            | K::KwData
            | K::KwDiv
            | K::KwDo
            | K::KwEffect
            | K::KwElse
            | K::KwEnd
            | K::KwFalse
            | K::KwFunction
            | K::KwHandle
            | K::KwIf
            | K::KwImplement
            | K::KwImport
            | K::KwLambda
            | K::KwLazy
            | K::KwMatch
            | K::KwMod
            | K::KwNot
            | K::KwOr
            | K::KwPublic
            | K::KwRecord
            | K::KwResume
            | K::KwReturn
            | K::KwShadow
            | K::KwThen
            | K::KwTrait
            | K::KwTrue
            | K::KwTry
            | K::KwType
            | K::KwUses
            | K::KwWith
    )
}

fn close(stack: &mut Vec<Opening>, kind: TokenKind, depth: &mut usize) {
    if let Some(index) = stack.iter().rposition(|o| o.kind == kind) {
        stack.truncate(index);
        *depth = stack.last().map_or(0, |o| o.depth);
    }
}

fn continues_after(kind: TokenKind) -> bool {
    use TokenKind as K;
    matches!(
        kind,
        K::Plus
            | K::Minus
            | K::Star
            | K::Slash
            | K::KwDiv
            | K::KwMod
            | K::Eq
            | K::NotEq
            | K::Lt
            | K::Le
            | K::Gt
            | K::Ge
            | K::KwAnd
            | K::KwOr
            | K::PipeGt
            | K::KwNot
            | K::Arrow
            | K::LeftArrow
            | K::Colon
            | K::Comma
            | K::Dot
            | K::LParen
            | K::LBracket
            | K::Amp
            | K::KwBind
            | K::KwCase
            | K::KwConst
            | K::KwData
            | K::KwDo
            | K::KwEffect
            | K::KwElse
            | K::KwFunction
            | K::KwHandle
            | K::KwIf
            | K::KwImplement
            | K::KwImport
            | K::KwLambda
            | K::KwLazy
            | K::KwMatch
            | K::KwPublic
            | K::KwRecord
            | K::KwReturn
            | K::KwShadow
            | K::KwThen
            | K::KwTrait
            | K::KwTry
            | K::KwType
            | K::KwUses
            | K::KwWith
    )
}

fn continues_before(kind: TokenKind) -> bool {
    use TokenKind as K;
    matches!(
        kind,
        K::Plus
            | K::Star
            | K::Slash
            | K::KwDiv
            | K::KwMod
            | K::Eq
            | K::NotEq
            | K::Lt
            | K::Le
            | K::Gt
            | K::Ge
            | K::KwAnd
            | K::KwOr
            | K::PipeGt
            | K::Dot
            | K::Arrow
            | K::LeftArrow
            | K::KwThen
            | K::KwElse
            | K::KwDo
    )
}

#[cfg(test)]
// テストの失敗は panic で表す（実装プラン 00-02「`#[allow]` を書いてよい箇所」）。
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

    /// 物理的な行の番号で残す改行を指定し、公開の二つの工程をつないで確かめる。
    fn assert_newlines(src: &str, lines: &[usize]) -> Vec<Token> {
        let lexed = lex(FileId(7), src.as_bytes());
        assert_eq!(lexed.diagnostics, [], "{src}");
        let breaks: Vec<_> = lexed
            .tokens
            .iter()
            .filter(|t| t.kind == K::LineBreak)
            .map(|t| t.span)
            .collect();
        let expected: Vec<_> = lines.iter().map(|line| breaks[line - 1]).collect();
        let output = resolve_newlines(lexed.tokens);
        assert_eq!(
            output
                .iter()
                .filter(|t| t.kind == K::Newline)
                .map(|t| t.span)
                .collect::<Vec<_>>(),
            expected,
            "{src}"
        );
        assert!(output.iter().all(|t| t.kind != K::LineBreak));
        assert!(
            output
                .windows(2)
                .all(|w| w[0].kind != K::Newline || w[1].kind != K::Newline)
        );
        assert_eq!(output.last().unwrap().kind, K::Eof);
        output
    }

    #[test]
    fn continuation_and_new_statement_boundaries() {
        for src in [
            "bind total <- price\n  * quantity",
            "lines\n  |> f",
            "return\n  x",
            "a,\n b",
            "T: A &\nB",
            "f(\na,\nb\n)",
            "[\na,\nb\n]",
        ] {
            assert_newlines(src, &[]);
        }
        for (src, lines) in [
            ("x\n-y", vec![1]),
            ("x\nnot y", vec![1]),
            ("x\nwith", vec![1]),
            ("x\n+ y", vec![]),
            ("x +\ny", vec![]),
            ("x -\ny", vec![]),
            ("x\ndo", vec![]),
            ("match x\nwith", vec![1]),
            ("end if\nfoo()", vec![1]),
            ("end function\nfoo()", vec![1]),
        ] {
            assert_newlines(src, &lines);
        }
        let out = assert_newlines("\n// c\na\n\n// d\n b\n", &[3, 6]);
        assert_eq!(
            out.iter().map(|t| t.kind).collect::<Vec<_>>(),
            [K::LowerIdent, K::Newline, K::LowerIdent, K::Newline, K::Eof]
        );
    }

    #[test]
    fn lexical_spec_examples() {
        let cases: &[(&str, &[usize])] = &[
            ("bind total <- price\n  * quantity\n", &[2]),
            (
                "bind n <- lines\n  |> List.filter(lambda(l) return l <> \"\" end lambda)\n  |> List.length\n",
                &[3],
            ),
            (
                "if ready then\n  start()\nelse\n  wait()\nend if\n",
                &[4, 5],
            ),
            (
                "match response with\n  case Result.Ok(body) -> body\n  case Result.Error(message) ->\n    Console.writeLine(message)\n    \"\"\nend match\n",
                &[2, 4, 5, 6],
            ),
            (
                "List.forEach(items, lambda(item)\n  bind name <- Item.name(item)\n  Console.writeLine(name)\nend lambda)\n",
                &[1, 2, 3, 4],
            ),
            (
                "function double(x: Integer)\n  -> Integer\n  return x * 2\nend function\n",
                &[2, 3, 4],
            ),
        ];
        for (src, expected) in cases {
            assert_newlines(src, expected);
        }
    }

    #[test]
    fn with_scopes_and_handler_arms() {
        let cases: &[(&str, &[usize])] = &[
            (
                "(match x with\n case a -> f()\n case b -> g()\nend match)\nnext",
                &[2, 3, 4],
            ),
            (
                "(handle\n f()\nwith\n case E.op(x) ->\n  f(x)\n  g(x)\nend handle)\nnext",
                &[2, 5, 6, 7],
            ),
            (
                "(with r = open() do\n f(r)\n g(r)\nend with)\nnext",
                &[2, 3, 4],
            ),
            ("(lazy\n f()\n g()\nend lazy)\nnext", &[2, 3, 4]),
            (
                "match x with\n// comment\n case a -> a\nend match\nnext",
                &[3, 4],
            ),
        ];
        for (src, expected) in cases {
            assert_newlines(src, expected);
        }
    }

    #[test]
    fn guards_parenthesized_if_and_else_if() {
        let cases: &[(&str, &[usize])] = &[
            (
                "(match x with\n case n if n > 0 ->\n  f(n)\n end match)\nnext",
                &[3, 4],
            ),
            (
                "match x with\n case n if (if a then\n  b\n else\n  c\n end if) ->\n f(n)\nend match",
                &[5, 7],
            ),
            (
                "(if a then\n f()\nelse if b then\n g()\nelse\n h()\nend if)\nnext",
                &[6, 7],
            ),
            (
                "match x with\n case n if f(lambda(x)\n  bind y <- x\n  return y\n end lambda) ->\n f(n)\nend match",
                &[2, 3, 4, 6],
            ),
        ];
        for (src, expected) in cases {
            assert_newlines(src, expected);
        }
    }

    #[test]
    fn malformed_closings_and_lexical_errors_do_not_break_resolution() {
        for (src, expected) in [
            (
                "(lazy\n f()\nend if\n g()\nend lazy)\nnext",
                vec![2, 3, 4, 5],
            ),
            ("(if a then\n [x\nend if\ny)\nnext", vec![4]),
            ("(a\n]\nb)\nnext", vec![3]),
            ("a)\nb]\nc\nend lambda\nd", vec![1, 2, 3, 4]),
            ("a ==\nb\n{\nc", vec![1, 2, 3]),
        ] {
            assert_newlines(src, &expected);
        }
        let out = resolve_newlines(lex(FileId(0), b"007\nx").tokens);
        assert_eq!(
            out.iter().map(|t| t.kind).collect::<Vec<_>>(),
            [K::Error, K::Newline, K::LowerIdent, K::Eof]
        );
        let out = assert_newlines("\"${x}\"\ny", &[1]);
        assert_eq!(
            out.iter().map(|t| t.kind).collect::<Vec<_>>(),
            [
                K::StrStart,
                K::LowerIdent,
                K::StrEnd,
                K::Newline,
                K::LowerIdent,
                K::Eof
            ]
        );
    }
}
