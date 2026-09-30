#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
// テストの失敗は panic で表すため、テストコードではこれらを許す（実装規約 00-02「#[allow] を書いてよい箇所」）。
//! 最小限の言語リファレンスの例と prelude の関数一覧を確かめる。

use std::fs;
use std::path::{Path, PathBuf};

use benitoite::base::{FileId, IdGen, SourceKind};
use benitoite::builtins::{BuiltinId, table};
use benitoite::pipeline::check_text;
use benitoite::prelude;
use benitoite::syntax::ast::Item;
use benitoite::syntax::lexer::lex;
use benitoite::syntax::newline::resolve_newlines;
use benitoite::syntax::parser::parse;

#[derive(Debug)]
struct CodeBlock {
    first_line: usize,
    source: String,
}

fn reference_path() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../docs/reference/benitoite-minimal.md")
}

fn read_bnt_blocks(markdown: &str) -> Vec<CodeBlock> {
    let mut blocks = Vec::new();
    let mut opening_line = None;
    let mut body_lines = Vec::new();

    for (index, line) in markdown.lines().enumerate() {
        if let Some(opening_line_number) = opening_line {
            if line == "```" {
                blocks.push(CodeBlock {
                    first_line: opening_line_number + 1,
                    source: body_lines.join("\n"),
                });
                opening_line = None;
                body_lines.clear();
            } else {
                body_lines.push(line.to_owned());
            }
        } else if line == "```bnt" {
            opening_line = Some(index + 1);
        }
    }

    assert!(
        opening_line.is_none(),
        "language reference contains an unclosed bnt code block"
    );
    blocks
}

#[test]
fn reference_programs_pass_check() {
    let path = reference_path();
    let markdown = fs::read_to_string(&path)
        .unwrap_or_else(|error| panic!("{} を読めない: {error}", path.display()));
    let blocks = read_bnt_blocks(&markdown);
    assert!(
        blocks.len() >= 4,
        "expected at least four complete bnt programs, found {}",
        blocks.len()
    );

    let mut failures = Vec::new();
    for block in blocks {
        if !block.source.contains("fn main(") {
            failures.push(format!(
                "line {}: bnt example is not a complete program with fn main",
                block.first_line
            ));
            continue;
        }

        let name = format!("language reference line {}", block.first_line);
        let result = check_text(&name, block.source.as_bytes());
        if !result.diagnostics.is_empty() {
            let messages = result
                .diagnostics
                .iter()
                .map(|diagnostic| {
                    let code = diagnostic
                        .code
                        .map(|code| code.info().id.to_owned())
                        .unwrap_or_else(|| "unknown code".to_owned());
                    format!("{code}: {}", diagnostic.message)
                })
                .collect::<Vec<_>>();
            failures.push(format!(
                "line {}:\n{}",
                block.first_line,
                messages.join("\n")
            ));
        }
    }

    assert!(
        failures.is_empty(),
        "language reference examples failed check_text:\n{}",
        failures.join("\n")
    );
}

fn prelude_source_functions() -> Vec<String> {
    let mut names = Vec::new();
    for &(file_name, source) in &prelude::SOURCES {
        let file = FileId(0);
        let lexed = lex(file, source.as_bytes());
        assert!(
            lexed.diagnostics.is_empty(),
            "prelude source {file_name} has lexical diagnostics: {:?}",
            lexed.diagnostics
        );

        let mut ids = IdGen::new();
        let parsed = parse(
            file,
            SourceKind::Prelude,
            resolve_newlines(lexed.tokens),
            lexed.comments,
            &mut ids,
        );
        assert!(
            parsed.diagnostics.is_empty(),
            "prelude source {file_name} has parser diagnostics: {:?}",
            parsed.diagnostics
        );

        for item in parsed.program.items {
            let Item::Fn(declaration) = item else {
                continue;
            };
            if let Some(module) = declaration.module {
                names.push(format!("{}.{}", module.text, declaration.name.text));
            }
        }
    }
    names
}

#[test]
fn reference_lists_every_public_prelude_function() {
    let path = reference_path();
    let markdown = fs::read_to_string(&path)
        .unwrap_or_else(|error| panic!("{} を読めない: {error}", path.display()));

    let mut expected = Vec::new();
    for id in BuiltinId::ALL {
        if id.is_operator() {
            continue;
        }
        let entry = table::spec(id);
        if entry.prelude_only {
            continue;
        }
        let Some(module) = entry.module else {
            panic!("non-operator builtin {:?} has no module", id);
        };
        expected.push(format!("{}.{}", module.name(), entry.name));
    }

    let source_functions = prelude_source_functions();
    assert!(
        !source_functions.is_empty(),
        "prelude::SOURCES parsed without any module-qualified functions"
    );
    expected.extend(source_functions);
    expected.sort();
    expected.dedup();

    let missing = expected
        .iter()
        .filter(|name| !markdown.contains(name.as_str()))
        .cloned()
        .collect::<Vec<_>>();
    assert!(
        missing.is_empty(),
        "prelude functions missing from language reference:\n{}",
        missing.join("\n")
    );
}
