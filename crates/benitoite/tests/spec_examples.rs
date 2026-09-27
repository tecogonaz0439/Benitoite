#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
// テストの失敗は panic で表すため、テストコードではこれらを許す（実装規約 00-02「#[allow] を書いてよい箇所」）。
//! 仕様書の例と処理系の字句解析・構文解析の整合を確かめる（設計書 07-03「言語仕様の例の検査」）。

use std::fs;
use std::path::{Path, PathBuf};

use benitoite::base::{FileId, IdGen, SourceKind};
use benitoite::diag::Diagnostic;
use benitoite::syntax::lexer::lex;
use benitoite::syntax::newline::resolve_newlines;
use benitoite::syntax::parser::parse;

// grammar_check.py の EXPECTED と同じ一覧に保つ。grammar_check.py を変えたらこちらも変える。
const EXPECTED_UNREADABLE: &[(&str, &str)] = &[
    (
        "01-01-lexical.md",
        "effect  else  false  fn  if  let  match  true  type  uses",
    ),
    (
        "01-01-lexical.md",
        "as  break  class  continue  derive  for  handle  impl",
    ),
    ("01-01-lexical.md", "+   -   *   /   %"),
    ("01-01-lexical.md", "..  ?"),
    ("01-01-lexical.md", "fn double(x: Int) -> Int"),
    (
        "01-02-syntax.md",
        "fn((fn() -> Unit uses IO), Int) -> Unit        // fn(fn() -> Unit uses IO, Int) -> Unit は誤り",
    ),
    (
        "01-06-type-system.md",
        "fn map[T, U, effect E](xs: List[T], f: fn(T) -> U uses E) -> List[U] uses E   // 本体は省略",
    ),
    (
        "01-06-type-system.md",
        "fn runAll(actions: List[fn() -> Unit uses IO]) -> Unit uses IO   // 本体は省略",
    ),
];

struct TextBlock {
    filename: String,
    heading: Option<String>,
    first_line_number: usize,
    source: String,
}

#[derive(Clone, Copy, Debug)]
enum InputShape {
    Program,
    Statements,
    Type,
    Pattern,
}

#[derive(Clone, Debug)]
struct DiagnosticSummary {
    code: String,
    message: String,
}

#[derive(Debug)]
enum ExampleRead {
    Read(InputShape),
    Unreadable(Option<DiagnosticSummary>),
}

fn spec_directory() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../doc/design/01-spec")
}

fn spec_files() -> Vec<PathBuf> {
    let directory = spec_directory();
    let entries = fs::read_dir(&directory)
        .unwrap_or_else(|error| panic!("{} を読めない: {error}", directory.display()));
    let mut files = Vec::new();
    for entry in entries {
        let entry = entry
            .unwrap_or_else(|error| panic!("{} の項目を読めない: {error}", directory.display()));
        let path = entry.path();
        if path.extension().is_some_and(|extension| extension == "md") {
            files.push(path);
        }
    }
    files.sort_by(|left, right| left.file_name().cmp(&right.file_name()));
    files
}

fn read_text_blocks(filename: &str, markdown: &str) -> Vec<TextBlock> {
    let mut blocks = Vec::new();
    let mut heading: Option<String> = None;
    let mut opening_line = None;
    let mut body = Vec::new();

    for (index, line) in markdown.lines().enumerate() {
        let line_number = index + 1;
        if opening_line.is_some() {
            if line == "```" {
                blocks.push(TextBlock {
                    filename: filename.to_owned(),
                    heading: heading.clone(),
                    first_line_number: opening_line.map_or(line_number, |opening| opening + 1),
                    source: body.join("\n"),
                });
                body.clear();
                opening_line = None;
            } else {
                body.push(line);
            }
        } else if is_spec_heading(line) {
            heading = Some(line.trim().to_owned());
        } else if line == "```text" {
            opening_line = Some(line_number);
        }
    }

    blocks
}

fn is_spec_heading(line: &str) -> bool {
    let line = line.trim_start();
    line.starts_with("### ") || line.starts_with("#### ")
}

fn is_ebnf_block(source: &str) -> bool {
    source.lines().any(is_ebnf_rule_start) && source.trim_end().ends_with('.')
}

fn is_ebnf_rule_start(line: &str) -> bool {
    let chars: Vec<char> = line.chars().collect();
    let mut position = 0;

    while chars
        .get(position)
        .is_some_and(|character| character.is_whitespace())
    {
        position += 1;
    }
    if !chars
        .get(position)
        .is_some_and(|character| character.is_ascii_uppercase())
    {
        return false;
    }
    position += 1;
    while chars
        .get(position)
        .is_some_and(|character| character.is_ascii_alphabetic())
    {
        position += 1;
    }

    if chars.get(position) == Some(&'(')
        && chars
            .get(position + 1)
            .is_some_and(|character| character.is_ascii_uppercase())
        && chars.get(position + 2) == Some(&')')
    {
        position += 3;
    }

    let whitespace_start = position;
    while chars
        .get(position)
        .is_some_and(|character| character.is_whitespace())
    {
        position += 1;
    }
    if position == whitespace_start || chars.get(position) != Some(&'=') {
        return false;
    }
    position += 1;
    let equals_end = position;
    while chars
        .get(position)
        .is_some_and(|character| character.is_whitespace())
    {
        position += 1;
    }
    position > equals_end
}

fn strip_strings_and_comments(source: &str) -> (String, bool) {
    let chars: Vec<char> = source.chars().collect();
    let mut clean = String::new();
    let mut has_interpolation = false;
    let mut position = 0;

    while position < chars.len() {
        if chars.get(position) == Some(&'"')
            && let Some(end) = string_end(&chars, position)
        {
            let content_start = position + 1;
            let content_end = end - 1;
            if chars
                .get(content_start..content_end)
                .is_some_and(|content| content.windows(2).any(|pair| pair == ['$', '{']))
            {
                has_interpolation = true;
            }
            position = end;
        } else if chars.get(position) == Some(&'/') && chars.get(position + 1) == Some(&'/') {
            position += 2;
            while chars
                .get(position)
                .is_some_and(|character| *character != '\n')
            {
                position += 1;
            }
        } else {
            if let Some(character) = chars.get(position) {
                clean.push(*character);
            }
            position += 1;
        }
    }

    (clean, has_interpolation)
}

fn string_end(chars: &[char], opening: usize) -> Option<usize> {
    let mut position = opening + 1;
    while let Some(character) = chars.get(position) {
        if *character == '\\' {
            position += 2;
        } else if *character == '"' {
            return Some(position + 1);
        } else {
            position += 1;
        }
    }
    None
}

fn is_source_block(source: &str) -> bool {
    let (clean, _) = strip_strings_and_comments(source);
    clean.is_ascii()
}

fn is_minimal_scope(block: &TextBlock) -> bool {
    if is_ebnf_block(&block.source) || !is_source_block(&block.source) {
        return false;
    }
    if block
        .heading
        .as_deref()
        .is_some_and(|heading| heading.contains("（v1）"))
    {
        return false;
    }

    let (clean, has_interpolation) = strip_strings_and_comments(&block.source);
    if has_interpolation {
        return false;
    }
    ![
        "import ",
        "record ",
        "trait ",
        "impl ",
        "lazy ",
        "with ",
        "permissions",
        "pub ",
        "?",
        "..",
    ]
    .iter()
    .any(|marker| clean.contains(marker))
}

fn first_nonempty_line(source: &str) -> &str {
    source
        .lines()
        .map(str::trim)
        .find(|line| !line.is_empty())
        .unwrap_or("")
}

fn is_expected_unreadable(filename: &str, first_line: &str) -> bool {
    EXPECTED_UNREADABLE
        .iter()
        .any(|(expected_file, expected_line)| {
            *expected_file == filename && *expected_line == first_line
        })
}

fn diagnostic_summary(diagnostic: &Diagnostic) -> DiagnosticSummary {
    let code = diagnostic
        .code
        .map(|code| code.info().id.to_owned())
        .unwrap_or_else(|| "unknown code".to_owned());
    DiagnosticSummary {
        code,
        message: diagnostic.message.clone(),
    }
}

fn check_source(source: &str) -> Result<(), DiagnosticSummary> {
    let file = FileId(0);
    let lexed = lex(file, source.as_bytes());
    let mut ids = IdGen::new();
    let parsed = parse(
        file,
        SourceKind::User,
        resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut ids,
    );
    let mut diagnostics = lexed.diagnostics;
    diagnostics.extend(parsed.diagnostics);

    match diagnostics.first() {
        Some(diagnostic) => Err(diagnostic_summary(diagnostic)),
        None => Ok(()),
    }
}

fn wrapped_source(shape: InputShape, source: &str) -> Option<String> {
    match shape {
        InputShape::Program => Some(source.to_owned()),
        InputShape::Statements => Some(format!("fn example_wrapper() -> Unit {{\n{source}\n}}")),
        InputShape::Type if source.lines().count() == 1 => {
            Some(format!("fn example_wrapper(x: {source}) -> Unit {{}}"))
        }
        InputShape::Pattern if source.lines().count() == 1 => Some(format!(
            "fn example_wrapper() -> Unit {{\nmatch () {{\n{source} => ()\n}}\n}}"
        )),
        InputShape::Type | InputShape::Pattern => None,
    }
}

fn check_example(source: &str) -> ExampleRead {
    let mut program_diagnostic = None;
    for shape in [
        InputShape::Program,
        InputShape::Statements,
        InputShape::Type,
        InputShape::Pattern,
    ] {
        let Some(wrapped) = wrapped_source(shape, source) else {
            continue;
        };
        match check_source(&wrapped) {
            Ok(()) => return ExampleRead::Read(shape),
            Err(diagnostic) if matches!(shape, InputShape::Program) => {
                program_diagnostic = Some(diagnostic);
            }
            Err(_) => {}
        }
    }
    ExampleRead::Unreadable(program_diagnostic)
}

#[test]
fn minimal_spec_examples_are_readable() {
    let mut blocks = Vec::new();
    for path in spec_files() {
        let filename = path
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_else(|| panic!("{} にファイル名がない", path.display()));
        let markdown = fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("{} を読めない: {error}", path.display()));
        blocks.extend(read_text_blocks(&filename, &markdown));
    }

    let import_v1_example = blocks.iter().find(|block| {
        block.filename == "01-02-syntax.md"
            && block
                .heading
                .as_deref()
                .is_some_and(|heading| heading.contains("モジュールと import（v1）"))
            && first_nonempty_line(&block.source) == "import Geo from \"./geo.bnt\""
    });
    assert!(
        import_v1_example.is_some_and(|block| !is_minimal_scope(block)),
        "01-02 の import（v1）の例を最小実行版の検査から除く"
    );

    let syntax_example = blocks.iter().find(|block| {
        block.filename == "01-02-syntax.md"
            && block.heading.as_deref() == Some("### 例")
            && first_nonempty_line(&block.source) == "type Shape {"
    });
    let syntax_example = syntax_example.expect("01-02 の「例」にある Shape プログラムが必要");
    let mut broken_example = syntax_example.source.clone();
    let final_brace = broken_example
        .rfind('}')
        .expect("例のプログラムに閉じ波括弧が必要");
    broken_example.remove(final_brace);
    assert!(
        matches!(check_example(&broken_example), ExampleRead::Unreadable(_)),
        "閉じ波括弧を一つ除いたプログラムを読めない例として判定する"
    );

    let mut readable = 0;
    let mut excluded = 0;
    let mut unreadable = Vec::new();
    for block in &blocks {
        if !is_minimal_scope(block) {
            excluded += 1;
            continue;
        }
        let first_line = first_nonempty_line(&block.source);
        if is_expected_unreadable(&block.filename, first_line) {
            excluded += 1;
            continue;
        }
        match check_example(&block.source) {
            ExampleRead::Read(_shape) => readable += 1,
            ExampleRead::Unreadable(program_diagnostic) => {
                unreadable.push(match program_diagnostic {
                    Some(diagnostic) => format!(
                        "{}:{}: {}: {}",
                        block.filename,
                        block.first_line_number,
                        diagnostic.code,
                        diagnostic.message
                    ),
                    None => format!(
                        "{}:{}: (program の最初の診断なし)",
                        block.filename, block.first_line_number
                    ),
                });
            }
        }
    }

    assert!(
        unreadable.is_empty(),
        "最小実行版の構文で読めない仕様例がある:\n{}\n読めた例: {readable}, 除いた例: {excluded}, 読めなかった例: {}",
        unreadable.join("\n"),
        unreadable.len()
    );
    println!("読めた例: {readable}, 除いた例: {excluded}, 読めなかった例: 0");
}
