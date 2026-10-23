//! 整形後の検証のテスト（設計書 06-03「整形後の検証」「テスト」、07-03「ほかの章が求めるテスト（初回リリース版）」）。
//! 検証の関数に、字句・改行・コメントを変えた出力を与えて、食い違いを見つけることを確かめる。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;

const BEFORE: &str = "\
/// adds
function f(x: Integer) -> Integer
  // keep
  return inc(x) + 1 // tail
end function
";

fn assert_rejects(name: &str, after: &str) {
    assert!(
        verify(BEFORE.as_bytes(), after.as_bytes(), SourceKind::User).is_err(),
        "case: {name}"
    );
}

#[test]
fn accepts_whitespace_only_changes() {
    let after = "/// adds\r\nfunction f( x:Integer )->Integer\n\n// keep   \n\treturn inc( x )+1   // tail\nend function";
    verify(BEFORE.as_bytes(), after.as_bytes(), SourceKind::User).unwrap();
}

#[test]
fn rejects_changed_tokens() {
    assert_rejects("changed token", &BEFORE.replace("+ 1", "+ 2"));
    assert_rejects("removed token", &BEFORE.replace("+ 1", "1"));
    assert_rejects(
        "line break changes statement separation",
        &BEFORE.replace("inc(x)", "inc\n(x)"),
    );
}

#[test]
fn rejects_changed_comments() {
    assert_rejects("dropped comment", &BEFORE.replace("  // keep\n", ""));
    assert_rejects("changed body", &BEFORE.replace("// tail", "// tale"));
}

#[test]
fn rejects_syntax_errors_with_the_same_tokens() {
    assert_rejects(
        "blank line between doc comment and declaration",
        &BEFORE.replace("/// adds\n", "/// adds\n\n"),
    );
}

#[test]
fn preserves_lambda_layouts_across_whitespace_changes() {
    for body in [
        "bind f <- lambda(x) return call(x, 1)",
        "bind f <- lambda(x) return (lambda(y) return x + y) end lambda",
        "bind f <- lambda(x) return (lambda(y) return x + y end lambda)",
        "bind f <- lambda(x)\n    return x // body\n  end lambda",
        "bind f <- lambda()\n    bind g <- lambda(x) return x\n\n  end lambda",
        "bind f <- lambda()\n  end lambda",
        "bind f <- lambda() try r or return",
        "bind f <- lambda() try try r or return or return",
        "bind x <- try r // value\n or // action\n return // done",
        "bind x <- try if ready then try r or return else s end if or return",
        "bind x <- \"${try r or return}\"",
    ] {
        let before = format!("function f() -> Unit\n  {body}\n  ()\nend function");
        let after = before.replace("bind ", "bind   ").replace('\n', "\r\n");
        verify(before.as_bytes(), after.as_bytes(), SourceKind::User).unwrap();
    }
}

#[test]
fn rejects_changed_lambda_boundaries() {
    let before = "function f() -> Unit\n  use(lambda(x) return call(x, 1)) // tail\nend function\n";
    for after in [
        // return 直後の改行は字句の比較で拒否する。値を始めた後の改行も
        // 次の二件で拒否する（設計書 06-03「整形後の検証」）。
        before.replace("return call", "return\n call"),
        before.replace("return call(", "return call(\n "),
        before.replace("call(x, 1)", "call(x,\n 1)"),
        before.replace("lambda(x)", "lambda(\nx)"),
        before.replace("call(x, 1))", "call(x, 1) end lambda)"),
        before.replace("// tail", "// changed"),
    ] {
        let result = verify(before.as_bytes(), after.as_bytes(), SourceKind::User);
        assert!(result.is_err(), "{after}");
        if after.contains("return call(\n") {
            assert!(
                result
                    .unwrap_err()
                    .contains("a lambda without `end lambda` must fit on one physical line"),
                "{after}"
            );
        }
    }
}

#[test]
fn accepts_removed_blank_lines_before_outer_lambda_ending() {
    let before = "function f() -> Unit\n  bind f <- lambda()\n    bind g <- lambda(x) return x\n\n  end lambda\nend function\n";
    let after = before.replace("\n\n", "\n");
    assert!(verify(before.as_bytes(), after.as_bytes(), SourceKind::User).is_ok());
}

#[test]
fn rejects_changed_try_actions_and_short_lambda_lines() {
    let before =
        "function f() -> Unit\n  bind f <- lambda() try r |> convert or return\nend function\n";
    for after in [
        before.replace(" or return", ""),
        before.replace("or return", "or flag"),
        before.replace("or return", "or\n return"),
        before.replace("try r", "try\n r"),
    ] {
        assert!(
            verify(before.as_bytes(), after.as_bytes(), SourceKind::User).is_err(),
            "{after}"
        );
    }
}

#[test]
fn die_formatting_preserves_actions_messages_and_short_lambda_layout() {
    use crate::syntax::parser::parse;
    fn verify_die(before: &[u8], after: &[u8]) -> Result<(), String> {
        let before_lexed = lex(FileId(0), before);
        let after_lexed = lex(FileId(0), after);
        compare_tokens(
            before,
            without_final_newline(&resolve_newlines(before_lexed.tokens.clone())),
            after,
            without_final_newline(&resolve_newlines(after_lexed.tokens.clone())),
        )?;
        let mut layouts = Vec::new();
        for (text, lexed) in [(before, before_lexed), (after, after_lexed)] {
            let parsed = parse(
                FileId(0),
                SourceKind::User,
                text,
                resolve_newlines(lexed.tokens.clone()),
                lexed.comments,
                lexed.pending,
                &mut IdGen::new(),
            );
            if parsed.diagnostics.iter().any(|d| d.is_error()) {
                return Err("parse failed".into());
            }
            layouts.push(lambda_layouts(&parsed.module, &lexed.tokens, "test")?);
        }
        if layouts[0] != layouts[1] {
            return Err("lambda layout changed".into());
        }
        Ok(())
    }
    fn formatted(text: &[u8]) -> Vec<u8> {
        let lexed = lex(FileId(0), text);
        assert!(lexed.diagnostics.is_empty());
        let parsed = parse(
            FileId(0),
            SourceKind::User,
            text,
            resolve_newlines(lexed.tokens.clone()),
            lexed.comments.clone(),
            lexed.pending.clone(),
            &mut IdGen::new(),
        );
        assert!(parsed.diagnostics.is_empty(), "{:?}", parsed.diagnostics);
        let roles = super::super::roles::build_roles(&parsed.module, &lexed.tokens, text);
        let out = super::super::print::print(&super::super::print::PrintInput {
            text,
            tokens: &lexed.tokens,
            comments: &lexed.comments,
            roles: &roles,
        });
        verify_die(text, &out).unwrap();
        out
    }
    for (before, expected) in [
        (
            "function f()->Integer\ntry r |> convert or die ( \"context\" ) // keep\nend function\n",
            "function f() -> Integer\n  try r |> convert or die(\"context\") // keep\nend function\n",
        ),
        (
            "function f()->Integer\ntry r or die\nend function\n",
            "function f() -> Integer\n  try r or die\nend function\n",
        ),
        (
            "function f()->Integer\ntry r or die(\n\"context\" // keep\n)\nend function\n",
            "function f() -> Integer\n  try r or die(\n    \"context\" // keep\n  )\nend function\n",
        ),
        (
            "function f()->Unit\nbind f<-lambda(r) try r or die(\"context\")\nend function\n",
            "function f() -> Unit\n  bind f <- lambda(r) try r or die(\"context\")\nend function\n",
        ),
    ] {
        let out = formatted(before.as_bytes());
        assert_eq!(out, expected.as_bytes());
        assert_eq!(formatted(&out), out);
        assert!(verify_die(before.as_bytes(), &out).is_ok());
        if before.contains("context") {
            let changed = expected.replace("context", "changed");
            assert!(verify_die(before.as_bytes(), changed.as_bytes()).is_err());
        }
        let changed = expected.replace("or die", "or return");
        assert!(verify_die(before.as_bytes(), changed.as_bytes()).is_err());
    }
}
