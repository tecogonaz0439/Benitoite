//! 一つのソースの整形（`format_source`）のテスト（設計書 06-03「コメント」「空の行」「行末と文字」
//! 「複数行の文字列」「整形の例」「構文の誤りがあるファイル」「標準ライブラリのソース」、07-03「ほかの章が求めるテスト
//! （初回リリース版）」）。本物の字句解析・構文解析・役割の表・書き出し・検証をつないで確かめる。
// テストの失敗は panic で表す（00-02「`#[allow]` を書いてよい箇所」）
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::prelude::STDLIB;
use crate::syntax::lexer::lex;
use crate::syntax::token::{TokenKind, TokenValue};

fn fmt_bytes(src: &[u8]) -> Vec<u8> {
    match format_source(FileId(0), SourceKind::User, src) {
        Ok(f) => f.text,
        Err(e) => panic!("{}\n{e:?}", String::from_utf8_lossy(src)),
    }
}

fn fmt(src: &str) -> String {
    String::from_utf8(fmt_bytes(src.as_bytes())).unwrap()
}

/// 整形の結果が期待どおりで、その結果を整形し直しても変わらない（冪等性）。
fn check(name: &str, input: &str, expected: &str) {
    assert_eq!(fmt(input), expected, "case: {name}");
    let again = format_source(FileId(0), SourceKind::User, expected.as_bytes()).unwrap();
    assert!(!again.changed, "case {name} is not a fixed point");
}

/// 06-03「整形の例」の前と後。
const EXAMPLE_BEFORE: &str = "\
import Benitoite.IO.Console
data Shape
    Circle(Float)
    Rect(Float,Float)
end data
function area(s: Shape)->Float
    return match s with
    case Shape.Circle(r)  ->  3.14159*r*r    // circle
    case Shape.Rect(w,h)->
    w*h
    end match
end function
function main() -> Unit uses Console.Write


    bind shapes<-[ Shape.Circle(1.0), Shape.Rect(2.0,3.0) ]
    // total area
    bind total <- shapes
    |> List.map(area)
    |> List.fold(0.0, lambda (acc, a) return acc+a end lambda)
    Console.writeLine(\"total: ${ total }\")
end function
";

const EXAMPLE_AFTER: &str = "\
import Benitoite.IO.Console

data Shape
  Circle(Float)
  Rect(Float, Float)
end data

function area(s: Shape) -> Float
  return match s with
    case Shape.Circle(r) -> 3.14159 * r * r // circle
    case Shape.Rect(w, h) ->
      w * h
  end match
end function

function main() -> Unit uses Console.Write
  bind shapes <- [Shape.Circle(1.0), Shape.Rect(2.0, 3.0)]
  // total area
  bind total <- shapes
    |> List.map(area)
    |> List.fold(0.0, lambda(acc, a) return acc + a end lambda)
  Console.writeLine(\"total: ${total}\")
end function
";

#[test]
fn formats_the_example_of_the_design() {
    check("example", EXAMPLE_BEFORE, EXAMPLE_AFTER);
    let first = format_source(FileId(0), SourceKind::User, EXAMPLE_BEFORE.as_bytes()).unwrap();
    assert!(first.changed);
}

#[test]
fn places_comments() {
    check(
        "trailing comment and comment-only lines",
        "\
function f(x: Boolean) -> Integer
if x then
return 1   // one
      // before else
else
return 2
    // before end if
end if
end function
    // end of file
",
        "\
function f(x: Boolean) -> Integer
  if x then
    return 1 // one
  // before else
  else
    return 2
    // before end if
  end if
end function

// end of file
",
    );
    check(
        "doc comments stay attached",
        "\
//! module doc
/// adds one
    function inc(x: Integer) -> Integer
return x + 1
end function
",
        "\
//! module doc
/// adds one
function inc(x: Integer) -> Integer
  return x + 1
end function
",
    );
    check(
        "doc comment after a declaration",
        "function a() -> Unit\n()\nend function\n/// b\n@test\nfunction b() -> Unit\n()\nend function\n",
        "function a() -> Unit\n  ()\nend function\n\n/// b\n@test\nfunction b() -> Unit\n  ()\nend function\n",
    );
    check(
        "comment body is kept but trailing blanks go",
        "function f() -> Unit\n//\tkeep  tab  \t\n()\nend function\n",
        "function f() -> Unit\n  //\tkeep  tab\n  ()\nend function\n",
    );
}

#[test]
fn normalizes_blank_lines() {
    check(
        "between declarations",
        "\n\nfunction a() -> Unit\n()\nend function\nfunction b() -> Unit\n()\nend function\n\n\n\nfunction c() -> Unit\n()\nend function\n\n\n",
        "function a() -> Unit\n  ()\nend function\n\nfunction b() -> Unit\n  ()\nend function\n\nfunction c() -> Unit\n  ()\nend function\n",
    );
    check(
        "imports and constants keep at most one",
        "import A.B\nimport A.C\n\n\nimport A.D\n// note\nimport A.E\nconst x: Integer = 1\nconst y: Integer = 2\n\n\n// c\nconst z: Integer = 3\n",
        "import A.B\nimport A.C\n\nimport A.D\n// note\nimport A.E\n\nconst x: Integer = 1\nconst y: Integer = 2\n\n// c\nconst z: Integer = 3\n",
    );
    check(
        "inside blocks",
        "\
function f(x: Integer) -> Integer

  bind a <- 1


  bind b <- 2

  return match x with

    case 1 -> a


    case _ -> b

  end match

end function
",
        "\
function f(x: Integer) -> Integer
  bind a <- 1

  bind b <- 2

  return match x with
    case 1 -> a

    case _ -> b
  end match
end function
",
    );
    check(
        "comment lines between a declaration and the next",
        "function a() -> Unit\n()\nend function\n// about b\n\n\nfunction b() -> Unit\n()\nend function\n",
        "function a() -> Unit\n  ()\nend function\n\n// about b\n\nfunction b() -> Unit\n  ()\nend function\n",
    );
    check(
        "comments before a first statement and before end",
        "function f() -> Unit\n\n// first\n\nf()\n\n// last\n\nend function\n",
        "function f() -> Unit\n  // first\n\n  f()\n\n  // last\nend function\n",
    );
}

#[test]
fn normalizes_line_ends_and_characters() {
    check(
        "CR LF, trailing blanks, tabs and the final newline",
        "function f() -> Unit\r\n\tbind s <-\t\"a\tb\"   \r\n\tg( s ,\t1 )\t\r\nend function",
        "function f() -> Unit\n  bind s <- \"a\tb\"\n  g(s, 1)\nend function\n",
    );
    check(
        "BOM and shebang",
        "\u{feff}#!/usr/bin/env benitoite  \n//! doc\n\n\nfunction main() -> Unit\n()\nend function\n",
        "\u{feff}#!/usr/bin/env benitoite  \n//! doc\n\nfunction main() -> Unit\n  ()\nend function\n",
    );
    check(
        "shebang with CR LF",
        "#!/bin/x \r\n\r\n\r\nfunction main() -> Unit\r\n()\r\nend function\r\n",
        "#!/bin/x \n\nfunction main() -> Unit\n  ()\nend function\n",
    );
}

fn string_values(src: &str) -> Vec<TokenValue> {
    lex(FileId(0), src.as_bytes())
        .tokens
        .into_iter()
        .filter(|t| t.kind == TokenKind::StringLit)
        .map(|t| t.value)
        .collect()
}

#[test]
fn moves_multiline_strings_with_their_opening_line() {
    let shallower = "\
function main() -> Unit
      bind s <- \"\"\"
        abc  
\t
          def
        \"\"\"
end function
";
    let shallower_expected = "\
function main() -> Unit
  bind s <- \"\"\"
    abc  

      def
    \"\"\"
end function
";
    let deeper = "\
function main() -> Unit
bind s <- \"\"\"
  abc
    def
  \"\"\"
end function
";
    let deeper_expected = "\
function main() -> Unit
  bind s <- \"\"\"
    abc
      def
    \"\"\"
end function
";
    let interpolated = "\
function main() -> Unit
bind s <- \"\"\"
  a ${x} b
  c
  \"\"\"
end function
";
    let interpolated_expected = "\
function main() -> Unit
  bind s <- \"\"\"
    a ${x} b
    c
    \"\"\"
end function
";
    // 深くするときに加える文字は、閉じの `"""` の前の空白の並びの最初の文字（ここではタブ）。
    let deeper_tab =
        "function main() -> Unit\nbind s <- \"\"\"\n\tabc\n\t\t def\n\t\"\"\"\nend function\n";
    let deeper_tab_expected = "function main() -> Unit\n  bind s <- \"\"\"\n\t\t\tabc\n\t\t\t\t def\n\t\t\t\"\"\"\nend function\n";
    // 複数行の文字列の中の CR LF も LF にする（06-03「行末と文字」）。
    let crlf = "function main() -> Unit\r\nbind s <- \"\"\"\r\n  abc\r\n\r\n  def\r\n  \"\"\"\r\nend function\r\n";
    let crlf_expected = "function main() -> Unit\n  bind s <- \"\"\"\n    abc\n\n    def\n    \"\"\"\nend function\n";
    check("interpolated", interpolated, interpolated_expected);
    for (name, input, expected) in [
        ("shallower", shallower, shallower_expected),
        ("deeper", deeper, deeper_expected),
        ("deeper with tabs", deeper_tab, deeper_tab_expected),
        ("CR LF inside", crlf, crlf_expected),
    ] {
        check(name, input, expected);
        assert_eq!(
            string_values(input),
            string_values(expected),
            "case: {name}"
        );
    }
}

/// 1 行に文字列が多い入力と、宣言とコメントの行が多い入力も整形でき、結果が冪等である。字句ごとに行の頭まで
/// 後ろへ走査する形と、行ごとに宣言を線形に探す形では、時間が二乗で増えていた（D02 の確認の直し）。時間の上限は付けない。
#[test]
fn large_inputs_are_formatted_idempotently() {
    let inner = format!("[{}]", vec!["\"a\""; 900].join(" , "));
    let strings = format!(
        "function main() -> Unit\nbind s <- [{}]\nend function\n",
        vec![inner; 23].join(", ")
    );
    let mut decls = String::new();
    for i in 0..3000 {
        decls.push_str(&format!(
            "// about f{i}\nfunction f{i}() -> Integer\nreturn {i}\nend function\n"
        ));
    }
    for (name, input) in [("strings", strings), ("declarations", decls)] {
        let once = fmt(&input);
        assert_ne!(once, input, "case {name} should change");
        let again = format_source(FileId(0), SourceKind::User, once.as_bytes()).unwrap();
        assert!(!again.changed, "case {name} is not a fixed point");
    }
}

#[test]
fn syntax_errors_are_reported_with_diagnostics() {
    for src in ["function f( -> Unit\nend function\n", "bind x <- \"open\n"] {
        match format_source(FileId(0), SourceKind::User, src.as_bytes()) {
            Err(FormatError::Syntax(diags)) => assert!(!diags.is_empty(), "{src}"),
            other => panic!("{src}: {other:?}"),
        }
    }
}

/// 構文解析器が出す字句・構文の誤り以外の診断（属性の E0801、`resume` の位置の E0509）だけなら整形し、
/// 構文の誤り（E02nn）なら断る（10-17「整形の流れ」の 2、ADR 0333 の決定 1）。
#[test]
fn only_lexical_and_syntax_errors_refuse_formatting() {
    for src in [
        "@memoize\nfunction main() -> Unit\n    ()\nend function\n",
        "function main() -> Unit\n    resume(())\nend function\n",
    ] {
        let formatted = format_source(FileId(0), SourceKind::User, src.as_bytes())
            .unwrap_or_else(|e| panic!("{src}: {e:?}"));
        assert!(formatted.changed, "{src}");
        assert!(
            String::from_utf8(formatted.text).unwrap().contains("\n  "),
            "{src}"
        );
    }
    match format_source(
        FileId(0),
        SourceKind::User,
        b"function f( -> Unit\nend function\n",
    ) {
        Err(FormatError::Syntax(diags)) => assert!(
            diags
                .iter()
                .any(|d| d.code.is_some_and(|c| c.info().id.starts_with("E02"))),
            "{diags:?}"
        ),
        other => panic!("{other:?}"),
    }
}

/// 同梱する標準ライブラリのソースは正規形である（06-03「標準ライブラリのソース」）。
#[test]
fn stdlib_sources_are_canonical() {
    let mut failures = Vec::new();
    for module in STDLIB {
        let name = module.path.join(".");
        match format_source(FileId(0), SourceKind::Prelude, module.text.as_bytes()) {
            Ok(f) if !f.changed => {}
            Ok(f) => {
                let after = String::from_utf8_lossy(&f.text).into_owned();
                let line = module
                    .text
                    .lines()
                    .zip(after.lines())
                    .position(|(a, b)| a != b)
                    .unwrap_or_else(|| module.text.lines().count().min(after.lines().count()));
                failures.push(format!(
                    "{name}: line {} changes: {:?} -> {:?}",
                    line + 1,
                    module.text.lines().nth(line),
                    after.lines().nth(line)
                ));
            }
            Err(e) => failures.push(format!("{name}: {e:?}")),
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

/// `run_fmt` の終了状態と `replace_file` のテスト（06-01「`fmt` のコマンドライン（初回リリース版）」、10-17「`fmt` の実行」）。
/// 検証の失敗と panic と一時ファイルの衝突は CLI のプロセスからは作れないので、ここで確かめる。
mod command {
    use super::super::*;
    use crate::cli::{DevPanic, DiagFormat};
    use crate::runtime::heap::HeapConfig;
    use crate::runtime::run::{self, OutputTarget, StdinSource};
    use crate::vm::ExecMode;
    use std::path::PathBuf;
    use std::sync::{Arc, Mutex};

    struct Scratch(PathBuf);

    impl Scratch {
        fn new(tag: &str) -> Scratch {
            let nanos = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_or(0, |d| d.as_nanos());
            let path = std::env::temp_dir().join(format!(
                "benitoite-fmt-{tag}-{}-{nanos}",
                std::process::id()
            ));
            std::fs::create_dir(&path).unwrap();
            Scratch(path)
        }
    }

    impl Drop for Scratch {
        fn drop(&mut self) {
            let _result = std::fs::remove_dir_all(&self.0);
        }
    }

    fn env_in(dir: &Path) -> (CliEnv, Arc<Mutex<Vec<u8>>>) {
        let err = Arc::new(Mutex::new(Vec::new()));
        let env = CliEnv {
            stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            stderr: OutputTarget::Capture(Arc::clone(&err)),
            stdin: StdinSource::Empty,
            working_directory: dir.to_path_buf(),
            color: false,
            mode: ExecMode::Direct,
            interrupt: Some(Box::new(run::NoInterrupt)),
            parts: None,
            heap: HeapConfig::default(),
            dev_panic: DevPanic::None,
            dev_alloc_stats: false,
        };
        (env, err)
    }

    fn args(paths: &[&str], check: bool) -> PathArgs {
        PathArgs {
            diagnostics: DiagFormat::Text,
            max_call_stack: None,
            deny_warnings: false,
            check,
            paths: paths.iter().map(PathBuf::from).collect(),
        }
    }

    fn fail_verify(_text: &[u8], _file: FileId) -> Result<Formatted, FormatError> {
        Err(FormatError::Verify(String::from(
            "verify mismatch for test",
        )))
    }

    fn panic_in_format(_text: &[u8], _file: FileId) -> Result<Formatted, FormatError> {
        panic!("formatter panic for test")
    }

    const UNFORMATTED: &str = "function main() -> Unit\n      ()\nend function\n";

    #[test]
    fn internal_errors_win_over_other_statuses_and_leave_files_alone() {
        let dir = Scratch::new("internal");
        std::fs::write(dir.0.join("a.bnt"), UNFORMATTED).unwrap();
        for format in [fail_verify as fn(&[u8], FileId) -> _, panic_in_format] {
            let (env, err) = env_in(&dir.0);
            // 読めないファイル（寄与 2）と並べても、処理系の不具合（3）で終わる。
            let status = run_fmt_with(&args(&["missing.bnt", "a.bnt"], false), &env, format);
            assert_eq!(status, EXIT_INTERNAL);
            let err = String::from_utf8(err.lock().unwrap().clone()).unwrap();
            assert!(err.contains("E0101"), "{err}");
            assert!(err.contains("internal error"), "{err}");
            assert_eq!(
                std::fs::read_to_string(dir.0.join("a.bnt")).unwrap(),
                UNFORMATTED
            );
        }
    }

    #[test]
    fn read_source_rejects_sources_over_the_limit() {
        let dir = Scratch::new("limit");
        let path = dir.0.join("big.bnt");
        std::fs::write(&path, b"12345").unwrap();
        assert_eq!(read_source(&path, 5).unwrap(), b"12345");
        assert_eq!(
            read_source(&path, 4),
            Err(source_text::SOURCE_TOO_LARGE.to_owned())
        );
    }

    #[test]
    fn replace_file_does_not_touch_an_existing_temporary_file() {
        let dir = Scratch::new("temp");
        let path = dir.0.join("a.bnt");
        std::fs::write(&path, "original").unwrap();
        let temp = dir.0.join(format!(".a.bnt.fmt-{}", std::process::id()));
        std::fs::write(&temp, "someone else's").unwrap();
        let diag = replace_file(&path, "a.bnt", b"formatted").unwrap_err();
        assert_eq!(diag.code, Some(DiagCode::E0125));
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "original");
        assert_eq!(std::fs::read_to_string(&temp).unwrap(), "someone else's");
    }
}
