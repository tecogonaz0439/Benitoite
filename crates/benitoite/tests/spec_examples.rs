#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
// テストの失敗は panic で表すため、テストコードではこれらを許す（実装規約 00-02「#[allow] を書いてよい箇所」）。
//! 言語仕様と付録の例を、初回リリース版の構文解析器と名前解決で確かめる（設計書 07-03「言語仕様の例の検査」）。

use std::fs;
use std::path::{Path, PathBuf};

use benitoite::base::{FileId, IdGen, SourceKind};
use benitoite::diag::{DiagCode, Diagnostic};
use benitoite::pipeline::{self, CheckOptions};
use benitoite::prelude;
use benitoite::syntax::ast::Module;
use benitoite::syntax::lexer::lex;
use benitoite::syntax::newline::resolve_newlines;
use benitoite::syntax::parser::parse;

// 例を足したときは、この表も見直す。誤りの例と本体を省略した宣言などを除く唯一の一覧である。
// C13 で削除する前の grammar_check.py の EXPECTED のうち、現在の例に当たる 7 件を写した。
const EXPECTED_FAILURES: &[(&str, &str)] = &[
    (
        "01-01-lexical.md",
        "and  bind  case  data  div  effect  else  end  false  function  if  lambda  match",
    ),
    ("01-01-lexical.md", "+   -   *   /"),
    ("01-01-lexical.md", "..  &"),
    (
        "01-02-syntax.md",
        "function((function() -> Unit uses Console.Write), Integer) -> Unit        // function(function() -> Unit uses Console.Write, Integer) -> Unit は誤り",
    ),
    (
        "01-03-names-modules.md",
        "function total(items: List[Integer]) -> Integer",
    ),
    (
        "01-06-type-system.md",
        "function map[T, U, effect E](xs: List[T], f: function(T) -> U uses E) -> List[U] uses E   // 本体は省略",
    ),
    (
        "01-06-type-system.md",
        "function runAll(actions: List[function() -> Unit uses Console.Write]) -> Unit uses Console.Write   // 本体は省略",
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
    LoadingFailure {
        shape: InputShape,
        diagnostics: Vec<DiagnosticSummary>,
        program_diagnostic: Option<DiagnosticSummary>,
    },
    ScopeViolation {
        shape: InputShape,
        diagnostics: Vec<DiagnosticSummary>,
        program_diagnostic: Option<DiagnosticSummary>,
    },
}

#[derive(Debug)]
enum ExampleResult {
    Read(InputShape),
    ExpectedFailure,
    Skipped,
    Failed(ExampleRead),
}

#[derive(Default, Debug)]
struct Counts {
    ok: usize,
    expected_fail: usize,
    skipped: usize,
    fail: usize,
}

impl Counts {
    fn record(&mut self, result: &ExampleResult) {
        match result {
            ExampleResult::Read(_shape) => self.ok += 1,
            ExampleResult::ExpectedFailure => self.expected_fail += 1,
            ExampleResult::Skipped => self.skipped += 1,
            ExampleResult::Failed(_) => self.fail += 1,
        }
    }

    fn summary(&self, group: &str) -> String {
        format!(
            "{group}: ok {}, expected-fail {}, skipped {}, fail {}",
            self.ok, self.expected_fail, self.skipped, self.fail
        )
    }
}

fn design_directory() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../docs/design")
}

fn spec_files() -> Vec<PathBuf> {
    let directory = design_directory().join("01-spec");
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
        assert!(
            !line.contains("```text") || (line == "```text" && opening_line.is_none()),
            "{filename}:{line_number}: 取り出せない text フェンス: {line}"
        );
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

    assert!(
        opening_line.is_none(),
        "{filename}:{opening_line:?}: text フェンスが閉じていない"
    );

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

fn strip_strings_and_comments(source: &str) -> String {
    let chars: Vec<char> = source.chars().collect();
    let mut without_strings = String::new();
    let mut position = 0;

    // Python の is_source と同じく、文字列を先に除き、その結果からコメントを除く。
    // 文字リテラルと raw 文字列には、特別な規則を加えない（実装プラン C13「例の取り出し」）。
    while position < chars.len() {
        if chars.get(position) == Some(&'"')
            && let Some(end) = string_end(&chars, position)
        {
            position = end;
        } else {
            without_strings.push(chars[position]);
            position += 1;
        }
    }

    without_strings
        .split('\n')
        .map(|line| line.split_once("//").map_or(line, |(before, _)| before))
        .collect::<Vec<_>>()
        .join("\n")
}

fn string_end(chars: &[char], opening: usize) -> Option<usize> {
    let mut position = opening + 1;
    while let Some(character) = chars.get(position) {
        if *character == '\\' {
            if chars.get(position + 1).is_none_or(|next| *next == '\n') {
                return None;
            }
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
    strip_strings_and_comments(source).is_ascii()
}

// 仕様の import は正式な名前で書かれている。現在の取り込み名へ直して名前解決まで進める
// （設計書 07-03「言語仕様の例の検査」、ADR 0286）。
fn rewrite_unofficial_imports(source: &str) -> String {
    source
        .lines()
        .map(|line| {
            let Some(rest) = line.strip_prefix("import Benitoite.") else {
                return line.to_owned();
            };
            let path_end = rest
                .find(|character: char| {
                    !(character.is_ascii_alphanumeric() || character == '_' || character == '.')
                })
                .unwrap_or(rest.len());
            let path = &rest[..path_end];
            if prelude::STDLIB
                .iter()
                .any(|module| module.unofficial && module.path.join(".") == path)
            {
                format!("import Benitoite.Unofficial.{rest}")
            } else {
                line.to_owned()
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn first_nonempty_line(source: &str) -> &str {
    source
        .lines()
        .map(str::trim)
        .find(|line| !line.is_empty())
        .unwrap_or("")
}

fn is_expected_failure(filename: &str, first_line: &str) -> bool {
    EXPECTED_FAILURES
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

fn check_source(source: &str) -> Result<Module, DiagnosticSummary> {
    let file = FileId(0);
    let lexed = lex(file, source.as_bytes());
    let mut ids = IdGen::new();
    let parsed = parse(
        file,
        SourceKind::User,
        source.as_bytes(),
        resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut ids,
    );
    let mut diagnostics = lexed.diagnostics;
    diagnostics.extend(parsed.diagnostics);

    match diagnostics.first() {
        Some(diagnostic) => Err(diagnostic_summary(diagnostic)),
        None => Ok(parsed.module),
    }
}

fn wrapped_source(shape: InputShape, source: &str) -> Option<String> {
    match shape {
        InputShape::Program => Some(source.to_owned()),
        InputShape::Statements => Some(format!(
            "function exampleWrapper() -> Unit\n{source}\nend function"
        )),
        InputShape::Type if source.lines().count() == 1 => Some(format!(
            "function exampleWrapper(x: {source}) -> Unit\nend function"
        )),
        InputShape::Pattern if source.lines().count() == 1 => Some(format!(
            "function exampleWrapper() -> Unit\nmatch () with\ncase {source} -> ()\nend match\nend function"
        )),
        InputShape::Type | InputShape::Pattern => None,
    }
}

fn check_example(source: &str) -> ExampleRead {
    let source = rewrite_unofficial_imports(source);
    let mut program_diagnostic = None;
    for shape in [
        InputShape::Program,
        InputShape::Statements,
        InputShape::Type,
        InputShape::Pattern,
    ] {
        let Some(wrapped) = wrapped_source(shape, &source) else {
            continue;
        };
        match check_source(&wrapped) {
            Ok(module) => {
                return match check_local_bindings(shape, &wrapped, &module) {
                    Ok(diagnostics) if diagnostics.is_empty() => ExampleRead::Read(shape),
                    Ok(diagnostics) => ExampleRead::ScopeViolation {
                        shape,
                        diagnostics,
                        program_diagnostic,
                    },
                    Err(diagnostics) => ExampleRead::LoadingFailure {
                        shape,
                        diagnostics,
                        program_diagnostic,
                    },
                };
            }
            Err(diagnostic) if matches!(shape, InputShape::Program) => {
                program_diagnostic = Some(diagnostic);
            }
            Err(_) => {}
        }
    }
    ExampleRead::Unreadable(program_diagnostic)
}

fn check_local_bindings(
    shape: InputShape,
    source: &str,
    module: &Module,
) -> Result<Vec<DiagnosticSummary>, Vec<DiagnosticSummary>> {
    let fragment = match shape {
        InputShape::Program => false,
        InputShape::Statements => true,
        InputShape::Type | InputShape::Pattern => return Ok(Vec::new()),
    };
    // 仮のモジュールの内容は不要だが、ファイルがないと読み込みで止まり名前解決に
    // 進まない。構文解析した import のパスに空のソースを当てる（実装プラン C13「局所の束縛の規則」）。
    let mut paths: Vec<_> = module
        .imports
        .iter()
        .filter(|import| {
            import
                .path
                .first()
                .is_some_and(|name| name.text != "Benitoite")
        })
        .map(|import| {
            format!(
                "{}.bnt",
                import
                    .path
                    .iter()
                    .map(|name| name.text.as_str())
                    .collect::<Vec<_>>()
                    .join("/")
            )
        })
        .collect();
    paths.sort();
    paths.dedup();
    let mut files = vec![("example.bnt", source.as_bytes())];
    files.extend(paths.iter().map(|path| (path.as_str(), b"".as_slice())));
    let checked = pipeline::check_files(
        &files,
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    // 読み込みには字句・構文の検査も含まれる。これらの誤りとモジュールの探索の
    // 誤りがあると名前解決を走らせないため、束縛の検査が済んだと数えない（10-13「check」）。
    let loading_errors: Vec<_> = checked
        .diagnostics
        .iter()
        .filter(|diagnostic| {
            diagnostic.is_error()
                && diagnostic.code.is_none_or(|code| {
                    code.info().id.starts_with("E01")
                        || code.info().id.starts_with("E02")
                        || matches!(
                            code,
                            DiagCode::E0318
                                | DiagCode::E0319
                                | DiagCode::E0320
                                | DiagCode::E0321
                                | DiagCode::E0322
                        )
                })
        })
        .map(diagnostic_summary)
        .collect();
    if !loading_errors.is_empty() {
        return Err(loading_errors);
    }
    Ok(checked
        .diagnostics
        .iter()
        .filter(|diagnostic| {
            matches!(
                diagnostic.code,
                Some(
                    DiagCode::E0334
                        | DiagCode::E0336
                        | DiagCode::E0337
                        | DiagCode::E0338
                        | DiagCode::E0603
                )
            ) || (!fragment && diagnostic.code == Some(DiagCode::E0335))
        })
        .map(diagnostic_summary)
        .collect())
}

fn classify_example(block: &TextBlock) -> ExampleResult {
    if is_expected_failure(&block.filename, first_nonempty_line(&block.source)) {
        return match check_example(&block.source) {
            ExampleRead::Unreadable(_) | ExampleRead::ScopeViolation { .. } => {
                ExampleResult::ExpectedFailure
            }
            other @ (ExampleRead::Read(_) | ExampleRead::LoadingFailure { .. }) => {
                ExampleResult::Failed(other)
            }
        };
    }
    if is_ebnf_block(&block.source) || !is_source_block(&block.source) {
        return ExampleResult::Skipped;
    }
    match check_example(&block.source) {
        ExampleRead::Read(shape) => ExampleResult::Read(shape),
        failed @ (ExampleRead::Unreadable(_)
        | ExampleRead::ScopeViolation { .. }
        | ExampleRead::LoadingFailure { .. }) => ExampleResult::Failed(failed),
    }
}

fn failure_summary(block: &TextBlock, failed: &ExampleRead) -> String {
    let (program_diagnostic, scope) = match failed {
        ExampleRead::Unreadable(diagnostic) => (diagnostic, String::new()),
        ExampleRead::ScopeViolation {
            shape,
            diagnostics,
            program_diagnostic,
        } => (
            program_diagnostic,
            format!(
                "\n  local binding ({shape:?}): {}",
                diagnostics
                    .iter()
                    .map(|diagnostic| format!("{}: {}", diagnostic.code, diagnostic.message))
                    .collect::<Vec<_>>()
                    .join("; ")
            ),
        ),
        ExampleRead::LoadingFailure {
            shape,
            diagnostics,
            program_diagnostic,
        } => (
            program_diagnostic,
            format!(
                "\n  loading ({shape:?}): {}",
                diagnostics
                    .iter()
                    .map(|diagnostic| format!("{}: {}", diagnostic.code, diagnostic.message))
                    .collect::<Vec<_>>()
                    .join("; ")
            ),
        ),
        ExampleRead::Read(shape) => {
            return format!(
                "{}:{}: expected-fail の例が読め、局所の束縛の違反もない ({shape:?})",
                block.filename, block.first_line_number
            );
        }
    };
    let first = program_diagnostic.as_ref().map_or_else(
        || "(program の最初の診断なし)".to_owned(),
        |diagnostic| format!("{}: {}", diagnostic.code, diagnostic.message),
    );
    format!(
        "{}:{}: {first}{scope}",
        block.filename, block.first_line_number
    )
}

fn read_file_blocks(path: &Path) -> Vec<TextBlock> {
    let filename = path
        .file_name()
        .expect("章のパスにファイル名が必要")
        .to_string_lossy();
    let markdown = fs::read_to_string(path)
        .unwrap_or_else(|error| panic!("{} を読めない: {error}", path.display()));
    read_text_blocks(&filename, &markdown)
}

// 設計書の例と処理系のずれは、段ごとのテストでは検出できない。この境界で全例を読む
// （test-audit「作成時の関門」、設計書 07-03「言語仕様の例の検査」）。
#[test]
fn spec_and_appendix_examples_are_readable() {
    let mut spec_blocks = Vec::new();
    for path in spec_files() {
        spec_blocks.extend(read_file_blocks(&path));
    }
    let appendix_blocks =
        read_file_blocks(&design_directory().join("08-appendix/08-04-fp-syntax-comparison.md"));
    let mut failures = Vec::new();
    let mut summaries = Vec::new();
    for (group, blocks) in [("01-spec", &spec_blocks), ("08-04", &appendix_blocks)] {
        let mut counts = Counts::default();
        for block in blocks {
            let result = classify_example(block);
            counts.record(&result);
            if let ExampleResult::Failed(failed) = result {
                failures.push(failure_summary(block, &failed));
            }
        }
        summaries.push(counts.summary(group));
    }
    println!("{}", summaries.join("\n"));
    for (filename, first_line) in EXPECTED_FAILURES {
        assert!(
            spec_blocks.iter().any(|block| {
                block.filename == *filename && first_nonempty_line(&block.source) == *first_line
            }),
            "除く表の項目に当たる例がない: {filename}: {first_line}"
        );
    }
    assert!(
        failures.is_empty(),
        "例の検査に失敗した:\n{}\n{}",
        failures.join("\n"),
        summaries.join("\n")
    );
}

// 検査器が壊れた例を見逃す退行を、この検査器の判定と集計で確かめる。本番の段に
// テスト用の口を加えない（test-audit「作成時の関門」、実装プラン C13「受け入れテスト」）。
#[test]
fn broken_syntax_example_is_counted_as_unreadable() {
    let blocks = read_file_blocks(&design_directory().join("01-spec/01-02-syntax.md"));
    let block = blocks
        .into_iter()
        .find(|block| {
            block.heading.as_deref() == Some("### 例")
                && first_nonempty_line(&block.source) == "data Shape"
        })
        .expect("01-02 の「例」にある Shape プログラムが必要");
    assert!(matches!(
        classify_example(&block),
        ExampleResult::Read(InputShape::Program)
    ));
    let broken = TextBlock {
        source: block.source.replacen("end function", "", 1),
        ..block
    };
    let result = classify_example(&broken);
    let mut counts = Counts::default();
    counts.record(&result);
    assert!(matches!(
        result,
        ExampleResult::Failed(ExampleRead::Unreadable(Some(_)))
    ));
    assert_eq!(counts.fail, 1);
    assert_eq!(counts.ok, 0);
}

#[test]
fn local_binding_violations_are_counted_and_fragment_shadow_is_allowed() {
    for (source, expected_code) in [
        ("bind x <- 1\nbind x <- 2", Some("E0334")),
        // 仮の名前への診断を無視しても、後の束縛違反を見逃さないことを確かめる
        // （実装プラン C13「局所の束縛の規則」）。
        ("bind x <- missing\nbind x <- 2", Some("E0334")),
        // 読み替えを誤ると、読み込みで止まり E0334 が出ない。この層で名前解決まで
        // 進めることを確かめる（設計書 07-03「言語仕様の例の検査」、ADR 0286）。
        (
            "import Benitoite.IO.Console// comment\nfunction example() -> Unit\nbind x <- 1\nbind x <- 2\nend function",
            Some("E0334"),
        ),
        (
            "import Lib.X\nfunction example() -> Unit\nbind x <- 1\nbind x <- 2\nend function",
            Some("E0334"),
        ),
        (
            "function example() -> Unit\nshadow y <- 1\nend function",
            Some("E0335"),
        ),
        (
            "function example(x: Integer) -> Unit\nmatch 1 with\ncase x -> x\nend match\nend function",
            Some("E0338"),
        ),
        ("shadow y <- 1", None),
    ] {
        let block = TextBlock {
            filename: "binding-fragment.md".to_owned(),
            heading: None,
            first_line_number: 1,
            source: source.to_owned(),
        };
        let result = classify_example(&block);
        let mut counts = Counts::default();
        counts.record(&result);
        assert_eq!(
            counts.fail,
            usize::from(expected_code.is_some()),
            "{source}: {result:?}"
        );
        if expected_code.is_none() {
            assert!(matches!(
                result,
                ExampleResult::Read(InputShape::Statements)
            ));
            assert_eq!(counts.ok, 1);
        } else {
            let ExampleResult::Failed(ExampleRead::ScopeViolation { diagnostics, .. }) = result
            else {
                panic!("局所の束縛の違反として数える必要がある: {result:?}");
            };
            assert!(
                diagnostics
                    .iter()
                    .any(|diagnostic| Some(diagnostic.code.as_str()) == expected_code)
            );
            assert_eq!(counts.ok, 0);
        }
    }
}

// 除く表が、直した例の検査を飛ばす退行を確かめる。表の照合キーを保ったまま
// E0338 の原因となる本体を除く（実装プラン C13「例の取り出し」）。
#[test]
fn expected_failure_must_still_be_invalid() {
    let blocks = read_file_blocks(&design_directory().join("01-spec/01-03-names-modules.md"));
    let block = blocks
        .into_iter()
        .find(|block| {
            first_nonempty_line(&block.source) == "function total(items: List[Integer]) -> Integer"
        })
        .expect("除く表の total の例が必要");
    assert!(
        matches!(check_example(&block.source), ExampleRead::ScopeViolation { diagnostics, .. }
        if diagnostics.iter().any(|diagnostic| diagnostic.code == "E0338"))
    );
    assert!(matches!(
        classify_example(&block),
        ExampleResult::ExpectedFailure
    ));
    let fixed = TextBlock {
        source: format!("{}\nend function", first_nonempty_line(&block.source)),
        ..block
    };
    let result = classify_example(&fixed);
    let mut counts = Counts::default();
    counts.record(&result);
    assert!(matches!(
        result,
        ExampleResult::Failed(ExampleRead::Read(InputShape::Program))
    ));
    assert_eq!(counts.fail, 1);
    assert_eq!(counts.expected_fail, 0);
    assert!(
        failure_summary(&fixed, &ExampleRead::Read(InputShape::Program)).contains("expected-fail")
    );
}

// 読み込みで止まった例を、束縛を検査できた例として数えない。
#[test]
fn loading_errors_are_counted_as_failures() {
    let block = TextBlock {
        filename: "loading.md".to_owned(),
        heading: None,
        first_line_number: 10,
        source: "import Benitoite.Missing\nfunction example() -> Unit\nend function".to_owned(),
    };
    let result = classify_example(&block);
    let mut counts = Counts::default();
    counts.record(&result);
    assert_eq!(counts.fail, 1, "{result:?}");
    let ExampleResult::Failed(failed) = result else {
        panic!("読み込みの誤りを見逃した");
    };
    let summary = failure_summary(&block, &failed);
    assert!(summary.contains("loading.md:10"));
    assert!(summary.contains("E0321"));
}

// 字下げなどで取り出せなかったフェンスも黙って飛ばさない。
#[test]
fn unextracted_text_fences_are_rejected() {
    assert_eq!(
        read_text_blocks("example.md", "```text\n()\n```\n").len(),
        1
    );
    for markdown in [
        "  ```text\n()\n  ```\n",
        "```text extra\n()\n```\n",
        "```text\n()\n",
    ] {
        assert!(
            std::panic::catch_unwind(|| read_text_blocks("example.md", markdown)).is_err(),
            "{markdown}"
        );
    }
}
