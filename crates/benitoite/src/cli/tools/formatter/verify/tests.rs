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
        before.replace("return call", "return\n call"),
        before.replace("call(x, 1)", "call(x,\n 1)"),
        before.replace("lambda(x)", "lambda(\nx)"),
        before.replace("call(x, 1))", "call(x, 1) end lambda)"),
        before.replace("// tail", "// changed"),
    ] {
        assert!(
            verify(before.as_bytes(), after.as_bytes(), SourceKind::User).is_err(),
            "{after}"
        );
    }
}

#[test]
fn accepts_removed_blank_lines_before_outer_lambda_ending() {
    let before = "function f() -> Unit\n  bind f <- lambda()\n    bind g <- lambda(x) return x\n\n  end lambda\nend function\n";
    let after = before.replace("\n\n", "\n");
    assert!(verify(before.as_bytes(), after.as_bytes(), SourceKind::User).is_ok());
}
