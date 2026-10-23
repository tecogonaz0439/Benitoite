//! 抽出の公開境界で、形式の拒否と元ソースの位置・期待値の契約を確かめる。
// テストの失敗はpanicで表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::base::{BytePos, FileId, IdGen, LineCol, Source, SourceKind, Span};
use crate::diag::{DiagBuilder, Diagnostic, Edit, Help, Label};
use crate::syntax::{ast::Module, lexer::lex, newline::resolve_newlines, parser::parse};

const ORIGINAL: FileId = FileId(7);
const VIRTUAL: FileId = FileId(99);

fn parsed(text: &str) -> Module {
    let lexed = lex(ORIGINAL, text.as_bytes());
    assert!(lexed.diagnostics.is_empty(), "{:?}", lexed.diagnostics);
    let parsed = parse(
        ORIGINAL,
        SourceKind::User,
        text.as_bytes(),
        resolve_newlines(lexed.tokens),
        lexed.comments,
        lexed.pending,
        &mut IdGen::new(),
    );
    assert!(parsed.diagnostics.is_empty(), "{:?}", parsed.diagnostics);
    parsed.module
}

fn comment(body: &str) -> String {
    let mut source: String = body.lines().map(|line| format!("/// {line}\n")).collect();
    source.push_str("function documented() -> Unit\n  return ()\nend function\n");
    source
}

fn span(file: FileId, range: Range<usize>) -> Span {
    Span {
        file,
        start: BytePos(range.start.try_into().unwrap()),
        end: BytePos(range.end.try_into().unwrap()),
    }
}

#[test]
fn doc_examples_preserve_modes_output_and_diagnostic_inclusion() {
    let source = comment(
        "\
```benitoite test
@test
function sample() -> Unit
  return ()
end function
```
```benitoite check
const greeting: String = \"日本語\"
```
```benitoite error
function bad() -> Integer
  return \"wrong\"
end function
```
```diagnostic
E0401

expected Integer
```
```benitoite
function main() -> Unit
  return ()
end function
```
```output
日本語

```
```stderr
message
```
```text
no execution
```
```
also ignored
```",
    );
    let found = extract(&parsed(&source)).unwrap();
    assert_eq!(found.examples.len(), 4);
    assert_eq!(found.ignored_blocks, 2);
    assert_eq!(found.examples[0].expectation, Expectation::Test);
    assert!(found.examples[0].source.contains("\n  return ()\n"));
    assert_eq!(found.examples[1].expectation, Expectation::Static);
    let error = &found.examples[2].expectation;
    assert_eq!(error.diagnostic_codes(), [DiagCode::E0401]);
    assert!(error.matches_diagnostics("expected Integer; details here; E0401"));
    assert!(!error.matches_diagnostics("expected Integer; E0402"));
    assert!(!error.matches_diagnostics("E0401"));
    assert_eq!(
        found.examples[3].expectation,
        Expectation::Run {
            stdout: "日本語\n\n".to_string(),
            stderr: "message\n".to_string(),
            exit: 0,
        }
    );
    let source = comment(
        "```benitoite\nfunction main() -> Unit\n  return ()\nend function\n```\n```output\n```\n",
    );
    let found = extract(&parsed(&source)).unwrap();
    assert_eq!(
        found.examples[0].expectation,
        Expectation::Run {
            stdout: String::new(),
            stderr: String::new(),
            exit: 0
        }
    );
}

#[test]
fn doc_format_errors_are_e0260_only_on_explicit_extraction() {
    for body in [
        "```benitoite nope\n```",
        "```benitoite check\nconst x: Integer = 1",
        "```benitoite error\n```",
        "```benitoite error\n```\n```diagnostic\nexpected Integer\n```",
        "```benitoite error\n```\n```diagnostic\nE9999\n```",
        "```benitoite error\n```\n```diagnostic\nR0101\n```",
        "```benitoite error\n```\n```diagnostic\nW0301\n```",
        "```benitoite\n```",
        "```benitoite\n```\n```output\nexit 1\n```",
        "```files\nname: Lib.bnt\n```",
        "```output\nstray\n```",
        "```stderr\nstray\n```",
        "```diagnostic\nstray\n```",
    ] {
        let source = comment(body);
        // 通常の構文解析では本文を実行用に解析しない。
        let module = parsed(&source);
        let errors = extract(&module).unwrap_err();
        assert_eq!(errors.len(), 1, "{body}");
        assert_eq!(errors[0].code, Some(DiagCode::E0260), "{body}");
        let primary = errors[0].primary.as_ref().unwrap().span;
        assert_eq!(primary.file, ORIGINAL);
        assert!(primary.start.0 < primary.end.0);
        assert!(
            source[primary.start.0 as usize..primary.end.0 as usize].contains("```"),
            "{body}"
        );
    }
}

#[test]
fn source_positions_survive_unicode_blank_lines_crlf_and_synthetic_ranges() {
    let source = "\u{feff}#!/bin/benitoite\r\n//! 概要\r\n//!   ```benitoite check\r\n//! const text: String = \"猫${1}犬\"\r\n//!\r\n//!  const next: Integer = 2\r\n//! ```\r\n";
    let module = parsed(source);
    let doc = module.doc.as_ref().unwrap();
    // 接頭辞・任意の一空白・CRLFを除く前の範囲も、ASTが保持する。
    let raw = doc.lines[2].span;
    assert_eq!(
        &source[raw.start.0 as usize..raw.end.0 as usize],
        "//! const text: String = \"猫${1}犬\"\r\n"
    );
    let found = extract(&module).unwrap();
    let example = &found.examples[0];
    assert_eq!(
        example.source,
        "const text: String = \"猫${1}犬\"\n\n const next: Integer = 2\n"
    );
    for needle in ["猫", "${1}", "犬", "const next", "\n\n"] {
        let start = example.source.find(needle).unwrap();
        let mapped = example
            .source_map
            .map_span(VIRTUAL, span(VIRTUAL, start..start + needle.len()));
        let original = &source[mapped.start.0 as usize..mapped.end.0 as usize];
        if needle == "\n\n" {
            assert_eq!(original, "\r\n//!\r\n");
        } else {
            assert_eq!(original, needle);
        }
    }
    let pos = example.source.find('犬').unwrap();
    let mapped = example
        .source_map
        .map_span(VIRTUAL, span(VIRTUAL, pos..pos + "犬".len()));
    let original = Source::new(
        "doc.bnt".to_string(),
        SourceKind::User,
        source.as_bytes().to_vec(),
    );
    assert_eq!(
        original.line_col(mapped.start),
        LineCol {
            line: 4,
            column: 32
        }
    );
    let empty_line = example.source.find("\n\n").unwrap() + 1;
    let blank = example
        .source_map
        .map_span(VIRTUAL, span(VIRTUAL, empty_line..empty_line));
    assert_eq!(
        original.line_col(blank.start),
        LineCol { line: 5, column: 4 }
    );
    assert_eq!(blank.start, blank.end);
    let eof = example.source.len();
    let mapped_eof = example
        .source_map
        .map_span(VIRTUAL, span(VIRTUAL, eof..eof));
    assert_eq!(
        original.line_col(mapped_eof.start),
        LineCol { line: 7, column: 1 }
    );
    assert_eq!(
        example
            .source_map
            .map_span(VIRTUAL, span(VIRTUAL, 0..eof + 1)),
        example.span
    );
    let external = span(FileId(200), 0..10);
    assert_eq!(example.source_map.map_span(VIRTUAL, external), external);
}

#[test]
fn diagnostic_primary_secondary_and_edit_explanations_return_to_comments() {
    let source =
        comment("```benitoite check\nconst text: String = \"猫\"\nconst other: Integer = 2\n```");
    let found = extract(&parsed(&source)).unwrap();
    let example = &found.examples[0];
    let virtual_primary = span(VIRTUAL, 0..5);
    let other = example.source.find("other").unwrap();
    let virtual_secondary = span(VIRTUAL, other..other + 5);
    let external = span(FileId(200), 10..12);
    let mut diagnostic: Diagnostic = DiagBuilder::new(DiagCode::E0401)
        .primary(virtual_primary)
        .build();
    diagnostic.secondary = vec![
        Label {
            span: virtual_secondary,
            text: "other declaration".to_string(),
        },
        Label {
            span: external,
            text: "import".to_string(),
        },
    ];
    diagnostic.helps = vec![
        Help {
            message: "change the declaration".to_string(),
            edits: vec![
                Edit {
                    span: virtual_primary.to(virtual_secondary),
                    replacement: "replacement".to_string(),
                },
                Edit {
                    span: external,
                    replacement: "external".to_string(),
                },
            ],
        },
        Help {
            message: "external fix".to_string(),
            edits: vec![Edit {
                span: external,
                replacement: "external".to_string(),
            }],
        },
    ];
    example.source_map.map_diagnostic(VIRTUAL, &mut diagnostic);
    let primary = diagnostic.primary.unwrap().span;
    assert_eq!(
        &source[primary.start.0 as usize..primary.end.0 as usize],
        "const"
    );
    let secondary = diagnostic.secondary[0].span;
    assert_eq!(
        &source[secondary.start.0 as usize..secondary.end.0 as usize],
        "other"
    );
    assert_eq!(diagnostic.secondary[1].span, external);
    assert_eq!(diagnostic.helps[0].message, "change the declaration");
    assert!(diagnostic.helps[0].edits.is_empty());
    assert_eq!(diagnostic.helps[1].edits[0].span, external);
}

#[test]
fn every_attached_doc_is_collected_once_in_source_order() {
    fn doc(prefix: &str, index: usize) -> String {
        format!(
            "{prefix} ```benitoite check\n{prefix} const index: Integer = {index}\n{prefix} ```\n"
        )
    }
    let source = format!(
        "{}{}public function visible() -> Unit\n  return ()\nend function\n{}function private() -> Unit\n  return ()\nend function\n{}data D\n{}  C\nend data\n{}record R\n{}  value: Integer\nend record\n{}trait T[A]\n{}  function f(value: A) -> Unit\nend trait\n{}implement T[Integer]\n{}  function f(value: Integer) -> Unit\n    return ()\n  end function\nend implement\n{}effect E\n{}  function operation() -> Unit\nend effect\n",
        doc("//!", 0),
        doc("///", 1),
        doc("///", 2),
        doc("///", 3),
        doc("  ///", 4),
        doc("///", 5),
        doc("  ///", 6),
        doc("///", 7),
        doc("  ///", 8),
        doc("///", 9),
        doc("  ///", 10),
        doc("///", 11),
        doc("  ///", 12)
    );
    let found = extract(&parsed(&source)).unwrap();
    assert_eq!(found.examples.len(), 13);
    for (index, example) in found.examples.iter().enumerate() {
        assert_eq!(example.source, format!("const index: Integer = {index}\n"));
        if index > 0 {
            assert!(found.examples[index - 1].span.start < example.span.start);
        }
    }
}

#[test]
fn markdown_adapter_keeps_exit_and_legacy_diagnostic_expectations() {
    let text = "```benitoite\nsource\n```\n```output\n日本語\n\nexit 2\n```\n```stderr\nerror\n```\n```benitoite error\nsource\n```\n```diagnostic\na legacy message without a code\n```\n";
    let blocks = blocks(text).unwrap();
    let (run, next) = example(&blocks, 0, Format::Markdown).unwrap().unwrap();
    assert_eq!(
        run.expectation,
        Expectation::Run {
            stdout: "日本語\n\n".to_string(),
            stderr: "error\n".to_string(),
            exit: 2
        }
    );
    let (error, _) = example(&blocks, next, Format::Markdown).unwrap().unwrap();
    assert!(
        error
            .expectation
            .matches_diagnostics("prefix: a legacy message without a code")
    );
    assert!(!error.expectation.matches_diagnostics("another message"));
}
