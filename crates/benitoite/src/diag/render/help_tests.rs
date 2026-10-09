//! 修正案を当てて本物の段で読み直す（設計書 02-10「修正案」、実装プラン F16）。
// テストの失敗と準備用の算術・添字は、00-02 のテストの例外に従う。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use crate::base::{Source, SourceKind, SourceTable};
use crate::diag::{DiagCode, Diagnostic, Help, codes};
use crate::modules::memfs::load_files;
use crate::resolve::test_support::resolve_files;
use crate::syntax::parser::test_support::parse_source;

fn syntax_diagnostics(text: &str) -> Vec<Diagnostic> {
    let (parsed, mut diagnostics) = parse_source(text, SourceKind::User);
    diagnostics.extend(parsed.diagnostics);
    diagnostics
}

fn diagnostic(diags: &[Diagnostic], code: DiagCode) -> &Diagnostic {
    diags
        .iter()
        .find(|diag| diag.code == Some(code))
        .unwrap_or_else(|| panic!("missing {code:?}: {diags:?}"))
}

fn apply(files: &[(&str, &str)], sources: &SourceTable, help: &Help) -> Vec<(String, String)> {
    files
        .iter()
        .map(|(path, text)| {
            let mut text = (*text).to_owned();
            let mut edits = help
                .edits
                .iter()
                .filter(|edit| {
                    sources
                        .get(edit.span.file)
                        .is_some_and(|source| source.name() == *path)
                })
                .collect::<Vec<_>>();
            edits.sort_by_key(|edit| std::cmp::Reverse(edit.span.start));
            for edit in edits {
                text.replace_range(
                    usize::try_from(edit.span.start.0).unwrap()
                        ..usize::try_from(edit.span.end.0).unwrap(),
                    &edit.replacement,
                );
            }
            ((*path).to_owned(), text)
        })
        .collect()
}

fn has_template(template: &str, message: &str) -> bool {
    // 型板の値は識別子・ソースの写し等で可変である。固定の文を順に照合し、
    // 鍵を見失って鍵の名前をそのまま出す退行を公開の診断で検出する。
    let mut rest = template;
    let mut message = message;
    while let Some(start) = rest.find('{') {
        let Some(end) = rest
            .get(start + 1..)
            .and_then(|tail| tail.find('}'))
            .map(|end| end + start + 1)
        else {
            break;
        };
        if !rest[start + 1..end]
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_')
        {
            break;
        }
        let literal = &rest[..start];
        if let Some(after) = message.strip_prefix(literal) {
            message = after;
        } else {
            return false;
        }
        rest = &rest[end + 1..];
        let next = rest.find('{').unwrap_or(rest.len());
        let literal = &rest[..next];
        if rest.is_empty() {
            return true;
        }
        if let Some(offset) = message.find(literal) {
            message = &message[offset..];
        } else {
            return false;
        }
    }
    message == rest
}

fn validate_keys(diag: &Diagnostic) {
    let info = diag.code.unwrap().info();
    for help in &diag.helps {
        assert!(
            info.extras
                .iter()
                .any(|(_, template)| has_template(template, &help.message)),
            "{}: {help:?}",
            info.id
        );
        if !help.edits.is_empty() {
            assert!(
                info.extras
                    .iter()
                    .any(|(key, template)| info.fixes.contains(key)
                        && has_template(template, &help.message)),
                "{}: {help:?}",
                info.id
            );
        }
    }
}

#[test]
fn syntax_repairs_remove_the_original_code_when_reparsed() {
    // 作成時の関門: 診断の修正案という独立の契約を、実際の字句・構文解析で
    // 確かめる。描画のテストは範囲と修正文字列の正しさを検出できない。
    let cases = [
        (
            DiagCode::E0106,
            "function f() -> Unit\n bind x <- 1;\nend function",
        ),
        (
            DiagCode::E0106,
            "function f() -> Unit\n bind x <- 1; bind y <- 2\nend function",
        ),
        (
            DiagCode::E0113,
            "function f() -> String\n return 'e\u{301}'\nend function",
        ),
        (
            DiagCode::E0202,
            "function f(a: Integer, b: Integer, c: Integer) -> Boolean\n return a < b < c\nend function",
        ),
        (
            DiagCode::E0242,
            "function f(x: Integer) -> Integer\n return match x with\n case 1..=9 -> 1\n case _ -> 0\n end match\nend function",
        ),
        (DiagCode::E0233, "type Shape\n Circle(Float)\nend type"),
        (DiagCode::E0234, "function f(): Unit\nend function"),
        (
            DiagCode::E0124,
            "function f() -> Decimal\n return 1M\nend function",
        ),
        (
            DiagCode::E0121,
            "function f() -> String\n return \"\"\"abc\n\"\"\"\nend function",
        ),
        (DiagCode::E0206, "data Shape\n Leaf()\nend data"),
        (DiagCode::E0207, "function Lib.f() -> Unit\nend function"),
        (
            DiagCode::E0210,
            "function f() -> Unit\n lambda(_) return () end lambda\nend function",
        ),
        (
            DiagCode::E0211,
            "function f() -> Boolean\n return 1 == 1\nend function",
        ),
        (DiagCode::E0213, "function f() -> Unit\nend if"),
        (
            DiagCode::E0215,
            "function f(x: Integer) -> Integer\n return match x\n with\n case _ -> 1\n end match\nend function",
        ),
        (
            DiagCode::E0224,
            "function f(x: R) -> R\n return R(..x)\nend function",
        ),
        (
            DiagCode::E0225,
            "function f(x: R) -> Integer\n return match x with\n case R(..) -> 1\n end match\nend function",
        ),
        (
            DiagCode::E0227,
            "function f(xs: List[Integer]) -> List[Integer]\n return [...xs]\nend function",
        ),
        (
            DiagCode::E0228,
            "/// orphan\n\nfunction f() -> Unit\nend function",
        ),
        (
            DiagCode::E0229,
            "function f() -> Unit\nend function\n//! late",
        ),
        (
            DiagCode::E0236,
            "function f(x: Integer) -> Integer\n return match x with\n case 1 | 2 -> 1\n end match\nend function",
        ),
        (
            DiagCode::E0240,
            "function f(x: Integer) -> Unit\n match x with\n case _ ->\n break\n end match\nend function",
        ),
        (
            DiagCode::E0241,
            "function f(x: Integer) -> Unit\n match x with\n case n when n > 0 -> ()\n end match\nend function",
        ),
        (
            DiagCode::E0247,
            "#[test]\nfunction f() -> Unit\nend function",
        ),
        (DiagCode::E0221, "public implement Show[R]\nend implement"),
        (
            DiagCode::E0223,
            "trait Eq[T: equality]\nfunction f() -> T\nend trait",
        ),
    ];
    for (code, text) in cases {
        let diagnostics = syntax_diagnostics(text);
        let diag = diagnostic(&diagnostics, code);
        validate_keys(diag);
        let edits = diag
            .helps
            .iter()
            .filter(|help| !help.edits.is_empty())
            .collect::<Vec<_>>();
        assert!(!edits.is_empty(), "{code:?}: {text}");
        let mut sources = SourceTable::new();
        sources.add(Source::new(
            "main.bnt".into(),
            SourceKind::User,
            text.as_bytes().to_vec(),
        ));
        for help in edits {
            let fixed = apply(&[("main.bnt", text)], &sources, help);
            let after = syntax_diagnostics(&fixed[0].1);
            assert!(
                !after.iter().any(|diag| diag.code == Some(code)),
                "{code:?}: {fixed:?}: {after:?}"
            );
        }
    }
}

#[test]
fn resolver_repairs_remove_the_original_code_when_reloaded() {
    let cases = [
        (
            DiagCode::E0301,
            "function total() -> Unit\nend function\nfunction f() -> Unit\n totla()\nend function",
        ),
        (
            DiagCode::E0302,
            "function f() -> Unit\n Lisst.length([])\nend function",
        ),
        (
            DiagCode::E0303,
            "function f() -> Unit\n List.lenght([])\nend function",
        ),
        (
            DiagCode::E0331,
            "function f() -> Option[Integer]\n return Some(1)\nend function",
        ),
        (
            DiagCode::E0332,
            "function f() -> Unit\n Console.writeLine(\"ok\")\nend function",
        ),
        (
            DiagCode::E0333,
            "function f() -> Unit uses IO\nend function",
        ),
        (
            DiagCode::E0316,
            "type F = function(function() -> Unit uses State, Integer) -> Unit",
        ),
        (
            DiagCode::E0334,
            "function f(x: Integer) -> Unit\n bind x <- 2\nend function",
        ),
        (
            DiagCode::E0335,
            "function f() -> Unit\n shadow y <- 2\nend function",
        ),
        (
            DiagCode::E0337,
            "function f() -> Unit\n shadow _ <- 2\nend function",
        ),
        (
            DiagCode::E0329,
            "data Shape\n Circle(Float)\nend data\npublic function f() -> Shape\n return Shape.Circle(1.0)\nend function",
        ),
    ];
    for (code, text) in cases {
        let (load, resolved, _) = resolve_files(&[("main.bnt", text)]);
        let diag = diagnostic(&resolved.diagnostics, code);
        validate_keys(diag);
        let help = diag
            .helps
            .iter()
            .find(|help| !help.edits.is_empty())
            .unwrap();
        let fixed = apply(&[("main.bnt", text)], &load.sources, help);
        let files = fixed
            .iter()
            .map(|(path, text)| (path.as_str(), text.as_str()))
            .collect::<Vec<_>>();
        let (after_load, _) = load_files(&files);
        assert!(
            !after_load.diagnostics.iter().any(Diagnostic::is_error),
            "{code:?}: {fixed:?}: {:?}",
            after_load.diagnostics
        );
        let (_, after, _) = resolve_files(&files);
        assert!(
            !after.diagnostics.iter().any(|diag| diag.code == Some(code)),
            "{code:?}: {fixed:?}: {:?}",
            after.diagnostics
        );
    }
}

#[test]
fn module_repairs_update_the_file_selected_by_the_edit() {
    for (code, files) in [
        (
            DiagCode::E0323,
            vec![
                ("main.bnt", "import Lib.A as X\nimport Lib.B as X"),
                ("Lib/A.bnt", ""),
                ("Lib/B.bnt", ""),
            ],
        ),
        (
            DiagCode::E0324,
            vec![
                ("main.bnt", "import Lib.A\nimport Lib.A"),
                ("Lib/A.bnt", ""),
            ],
        ),
        (
            DiagCode::E0305,
            vec![
                ("main.bnt", "import Lib.A\ndata A\n One\nend data"),
                ("Lib/A.bnt", ""),
            ],
        ),
        (
            DiagCode::E0330,
            vec![
                (
                    "main.bnt",
                    "import Lib.A\nfunction main() -> Unit\n A.hidden()\nend function",
                ),
                ("Lib/A.bnt", "function hidden() -> Unit\nend function"),
            ],
        ),
    ] {
        let (load, resolved, _) = resolve_files(&files);
        let diag = diagnostic(&resolved.diagnostics, code);
        validate_keys(diag);
        let help = diag
            .helps
            .iter()
            .find(|help| !help.edits.is_empty())
            .unwrap();
        let fixed = apply(&files, &load.sources, help);
        let files = fixed
            .iter()
            .map(|(path, text)| (path.as_str(), text.as_str()))
            .collect::<Vec<_>>();
        let (_, after, _) = resolve_files(&files);
        assert!(
            !after.diagnostics.iter().any(|diag| diag.code == Some(code)),
            "{code:?}: {fixed:?}: {:?}",
            after.diagnostics
        );
    }
    for text in [
        "import Benitoite.IO.Console",
        "import Benitoite.Unofficial.List",
        "import Benitoite.Lisst",
    ] {
        let (load, _) = load_files(&[("main.bnt", text)]);
        let diag = diagnostic(&load.diagnostics, DiagCode::E0321);
        validate_keys(diag);
        let help = diag
            .helps
            .iter()
            .find(|help| !help.edits.is_empty())
            .unwrap();
        let fixed = apply(&[("main.bnt", text)], &load.sources, help);
        let (after, _) = load_files(&[("main.bnt", &fixed[0].1)]);
        assert!(
            !after
                .diagnostics
                .iter()
                .any(|diag| diag.code == Some(DiagCode::E0321)),
            "{fixed:?}: {:?}",
            after.diagnostics
        );
    }
}

#[test]
fn text_only_repairs_and_multiple_candidates_do_not_attach_edits() {
    for (code, text, key) in [
        (DiagCode::E0212, "function f() -> Unit {\n}\n", "open"),
        (
            DiagCode::E0203,
            "function f(xs: List[Integer]) -> Unit\n xs.map()\nend function",
            "pipe",
        ),
        (
            DiagCode::E0235,
            "function f() -> Unit\n try {\n }\nend function",
            "result",
        ),
        (
            DiagCode::E0230,
            "function f() -> Unit\n let x = 1\nend function",
            "bind",
        ),
        (
            DiagCode::E0231,
            "function f(x: Integer) -> Unit\n case x of\n when _:\n ()\n end case\nend function",
            "match_with",
        ),
        (
            DiagCode::E0232,
            "function f(x: Integer) -> Unit\n match x with\n when _:\n ()\n end match\nend function",
            "case",
        ),
        (
            DiagCode::E0216,
            "function if() -> Unit\nend function",
            "rename",
        ),
    ] {
        let diagnostics = syntax_diagnostics(text);
        let diag = diagnostic(&diagnostics, code);
        assert!(diag.helps.iter().any(|help| {
            has_template(
                code.info()
                    .extras
                    .iter()
                    .find(|(k, _)| *k == key)
                    .unwrap()
                    .1,
                &help.message,
            )
        }));
        assert!(diag.helps.iter().all(|help| help.edits.is_empty()));
        validate_keys(diag);
    }
    for (code, text, key) in [
        (
            DiagCode::E0336,
            "function f(a: Integer, p: Pair[Integer, Integer]) -> Unit\n shadow Pair(a, b) <- p\nend function",
            "split",
        ),
        (
            DiagCode::E0338,
            "function f(x: Integer) -> Unit\n lambda(x) return x end lambda\nend function",
            "rename",
        ),
        (
            DiagCode::E0301,
            "function help() -> Unit\nend function\nfunction helm() -> Unit\nend function\nfunction f() -> Unit\n helx()\nend function",
            "similar",
        ),
        (
            DiagCode::E0303,
            "function f(s: String) -> Unit\n String.length(s)\nend function",
            "length",
        ),
        (
            DiagCode::E0303,
            "function f(o: Option[Integer]) -> Unit\n Option.unwrap(o)\nend function",
            "unwrap",
        ),
        (
            DiagCode::E0303,
            "function f(o: Result[Integer, String]) -> Unit\n Result.unwrap(o)\nend function",
            "unwrap",
        ),
    ] {
        let (_, resolved, _) = resolve_files(&[("main.bnt", text)]);
        let diag = diagnostic(&resolved.diagnostics, code);
        let template = code
            .info()
            .extras
            .iter()
            .find(|(k, _)| *k == key)
            .unwrap()
            .1;
        assert!(
            diag.helps
                .iter()
                .any(|help| has_template(template, &help.message)),
            "{code:?}: {diag:?}"
        );
        assert!(
            diag.helps
                .iter()
                .filter(|help| has_template(template, &help.message))
                .all(|help| help.edits.is_empty()),
            "{code:?}: {diag:?}"
        );
        validate_keys(diag);
    }
}

#[test]
fn deprecated_warning_preserves_the_message_without_guessing_a_replacement() {
    let (_, resolved, _) = resolve_files(&[(
        "main.bnt",
        "@deprecated(\"use g\")\nfunction f() -> Unit\nend function\nfunction g() -> Unit\n f()\nend function",
    )]);
    let diag = diagnostic(&resolved.diagnostics, DiagCode::W0301);
    assert_eq!(diag.notes, ["use g"]);
    assert!(diag.helps.is_empty());
    assert!(diag.is_warning());
    assert!(codes::DiagCode::W0301.info().fixes.is_empty());
}
