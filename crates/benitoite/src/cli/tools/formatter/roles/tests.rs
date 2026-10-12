//! 役割の表のテスト（設計書 07-03「テストの種類（初回リリース版）」のフォーマッタ）。字下げと空白の結果は
//! `print` のテストが整形の結果で確かめるので、ここでは整形の結果に現れない欄（`top`・`blank_before`・
//! `inner_level`）を確かめる。出力の処理がこれらの欄を使って空の行とコメントを置く（設計書 06-03「入力表現」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::base::{FileId, IdGen, SourceKind};
use crate::cli::tools::formatter::print::{PrintInput, print};
use crate::syntax::lexer::lex;
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::parse;
use crate::syntax::token::TokenKind;

/// `lex`・`resolve_newlines`・`parse`・`build_roles` をつないだ結果。
pub(in crate::cli::tools::formatter) struct Pipeline {
    pub tokens: Vec<Token>,
    pub roles: RoleTable,
}

/// 本物の字句解析と構文解析から役割の表を作る。誤りのない入力だけを受け取る（設計書 06-03「入力表現」）。
pub(in crate::cli::tools::formatter) fn pipeline(src: &str) -> Pipeline {
    let lexed = lex(FileId(0), src.as_bytes());
    assert!(
        lexed.diagnostics.is_empty(),
        "{src}\n{:?}",
        lexed.diagnostics
    );
    let tokens = lexed.tokens.clone();
    let parsed = parse(
        FileId(0),
        SourceKind::User,
        src.as_bytes(),
        resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut IdGen::new(),
    );
    assert!(
        parsed.diagnostics.is_empty(),
        "{src}\n{:?}",
        parsed.diagnostics
    );
    let roles = build_roles(&parsed.module, &tokens, src.as_bytes());
    assert_eq!(roles.roles.len(), tokens.len());
    Pipeline { tokens, roles }
}

/// 整形の結果を文字列で返す。コメント・空の行・複数行の文字列を含まない入力だけを扱う。
pub(in crate::cli::tools::formatter) fn format(src: &str) -> String {
    let Pipeline { tokens, roles } = pipeline(src);
    let out = print(&PrintInput {
        text: src.as_bytes(),
        tokens: &tokens,
        comments: &[],
        roles: &roles,
    });
    String::from_utf8(out).unwrap()
}

/// 行（1 から数える）の最初の字句の役割。
fn line_role(p: &Pipeline, line: usize) -> TokenRole {
    let mut current = 1;
    let mut at_start = true;
    for (index, token) in p.tokens.iter().enumerate() {
        if token.kind == TokenKind::LineBreak {
            current += 1;
            at_start = true;
            continue;
        }
        if at_start && current == line {
            return p.roles.roles[index];
        }
        at_start = false;
    }
    panic!("line {line} has no token");
}

fn text_of<'s>(src: &'s str, token: &Token) -> &'s str {
    &src[token.span.start.0 as usize..token.span.end.0 as usize]
}

#[test]
fn top_ranges_cover_each_declaration_with_its_attributes() {
    let src = "import A.B\nconst x: Integer = 1\nfunction f() -> Unit\n  ()\nend function\n@test\nfunction t() -> Unit\n  ()\nend function\n";
    let p = pipeline(src);
    let ranges: Vec<(&str, TopKind)> = p
        .roles
        .top
        .iter()
        .map(|r| {
            let start = p.tokens[r.first].span.start.0 as usize;
            let end = p.tokens[r.last].span.end.0 as usize;
            (&src[start..end], r.kind)
        })
        .collect();
    assert_eq!(
        ranges,
        [
            ("import A.B", TopKind::Import),
            ("const x: Integer = 1", TopKind::Const),
            ("function f() -> Unit\n  ()\nend function", TopKind::Other),
            (
                "@test\nfunction t() -> Unit\n  ()\nend function",
                TopKind::Other
            ),
        ]
    );
}

#[test]
fn blank_line_handling_follows_the_kind_of_line() {
    let src = "\
/// doc
@test
@deprecated(\"x\")
function main() -> Unit
  bind a <- 1
  bind b <- 2
  if a then
    f()
  else
    g()
  end if
  match a with
    case 1 -> f()
    case _ ->
      g()
  end match
  handle
    f()
  with
    case Ask.ask() -> resume(1)
  end handle
  h(
    a,
    b
  )
end function
";
    let p = pipeline(src);
    let expected = [
        (2, (false, false)),  // `///` の後の行（空の行は置けない）
        (3, (true, false)),   // 属性の行と属性の間
        (4, (true, false)),   // 属性の行と宣言の間
        (5, (true, false)),   // 本体の最初の行
        (6, (false, false)),  // ブロックの中
        (7, (false, false)),  // ブロックの中
        (8, (true, false)),   // `if` の分岐の最初の行
        (9, (false, true)),   // `else`
        (10, (true, false)),  // `else` の分岐の最初の行
        (11, (false, true)),  // 閉じの字句
        (12, (false, false)), // ブロックの中
        (13, (true, false)),  // `match` の中身の最初の行
        (14, (false, false)), // 2 つ目の `case`
        (15, (true, false)),  // 分岐の本体の最初の行
        (16, (false, true)),  // 閉じの字句
        (17, (false, false)), // ブロックの中
        (18, (true, false)),  // `handle` の本体の最初の行
        (19, (false, true)),  // 節の並びを始める `with`
        (20, (false, false)), // 節の `case`
        (21, (false, true)),  // 閉じの字句
        (22, (false, false)), // ブロックの中
        (23, (true, false)),  // 括弧の中の最初の行
        (24, (false, false)), // 括弧の中
        (25, (false, true)),  // 閉じ括弧
        (26, (false, true)),  // 閉じの字句
    ];
    for (line, (leading, direct)) in expected {
        assert_eq!(
            line_role(&p, line).blank_before,
            BlankBefore { leading, direct },
            "line {line}"
        );
    }
}

/// `else if` の内側の `IfExpr` の span は外側の `end if` を含まない。連なりの途中と最後の分岐の本体の
/// 最初の行も、構文の中身の最初の行として空の行を除く（06-03「空の行」）。
#[test]
fn blank_lines_are_removed_at_the_start_of_each_branch_in_an_else_if_chain() {
    let src = "\
function main() -> Unit
  if a then
    f()
  else if b then

    g()
    g()
  else if c then

    h()
  else

    i()
    i()
  end if
end function
";
    let p = pipeline(src);
    let expected = [
        (3, (true, false)),   // `if` の分岐の最初の行
        (4, (false, true)),   // `else if`
        (6, (true, false)),   // 途中の `else if` の本体の最初の行
        (7, (false, false)),  // ブロックの中
        (8, (false, true)),   // 2 つ目の `else if`
        (10, (true, false)),  // 2 つ目の `else if` の本体の最初の行
        (11, (false, true)),  // `else`
        (13, (true, false)),  // 最後の `else` の本体の最初の行
        (14, (false, false)), // ブロックの中
        (15, (false, true)),  // 閉じの字句
    ];
    for (line, (leading, direct)) in expected {
        assert_eq!(
            line_role(&p, line).blank_before,
            BlankBefore { leading, direct },
            "line {line}"
        );
    }
}

#[test]
fn closing_tokens_carry_the_level_inside_the_construct() {
    let src = "\
function main() -> Unit
  if a then
    f(
      x
    )
  end if
end function
";
    let p = pipeline(src);
    let inner: Vec<(&str, Option<u32>)> = p
        .tokens
        .iter()
        .zip(&p.roles.roles)
        .filter(|(t, r)| {
            r.inner_level.is_some()
                || matches!(
                    t.kind,
                    TokenKind::KwEnd | TokenKind::RParen | TokenKind::RBracket
                )
        })
        .map(|(t, r)| (text_of(src, t), r.inner_level))
        .collect();
    // `main()` の `)`、`f(` の `)`、`end if`、`end function` の順。ほかの字句は `None`
    assert_eq!(
        inner,
        [
            (")", Some(1)),
            (")", Some(3)),
            ("end", Some(2)),
            ("end", Some(1)),
        ]
    );
}
