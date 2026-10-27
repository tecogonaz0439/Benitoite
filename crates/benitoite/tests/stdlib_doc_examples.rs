//! 標準ソースのdocの代表例を、利用者と同じ抽出・公開境界・実行部で検査する
//! （設計書 06-04「docの例」、06-06「同梱の Agent Skill の構成」）。
// テストの失敗はpanicで表す（AGENTS.md「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::ffi::OsString;
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use benitoite::base::{FileId, IdGen, Source, SourceKind};
use benitoite::cli::tools::doc_examples::{self, Expectation};
use benitoite::cli::{self, CliEnv, Command, DevPanic, ToolCommand};
use benitoite::prelude::STDLIB;
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::run::{NoInterrupt, OutputTarget, StdinSource};
use benitoite::syntax::{lexer, newline, parser};
use benitoite::vm::ExecMode;
use serde_json::{Value, json};

struct Directory(PathBuf);
impl Drop for Directory {
    fn drop(&mut self) {
        let _result = fs::remove_dir_all(&self.0);
    }
}

// 元の例だけをdoc付きの空関数へ付ける入力アダプタ。例のバイト位置と行・列を保ち、
// @builtinや元のimport・私有宣言は複製しない。本番にテスト専用の入口を追加しない。
fn carrier(text: &str, start: usize, end: usize) -> String {
    let first = text[..start].rfind('\n').map_or(0, |i| i + 1);
    let last = if text.as_bytes().get(end - 1) == Some(&b'\n') {
        end
    } else {
        text[end..].find('\n').map_or(text.len(), |i| end + i + 1)
    };
    let mut bytes = text.as_bytes()[..first].to_vec();
    for byte in &mut bytes {
        if !matches!(*byte, b'\r' | b'\n') {
            *byte = b' ';
        }
    }
    let mut result = String::from_utf8(bytes).unwrap();
    for line in text[first..last].split_inclusive('\n') {
        assert!(line.trim_start().starts_with("///") || line.trim_start().starts_with("//!"));
        let mut line = line.to_string();
        let prefix = line.len() - line.trim_start().len();
        if line[prefix..].starts_with("//!") {
            line.replace_range(prefix + 2..prefix + 3, "/");
        }
        result.push_str(&line);
    }
    if !result.ends_with('\n') {
        result.push('\n');
    }
    // 元のdocの途中にある閉じフェンスは、その後の改行も抽出範囲に含む。
    // 空のdoc行を残し、コメント結合時にその改行が末尾として落ちないようにする。
    if text.as_bytes().get(end - 1) == Some(&b'\n') {
        result.push_str("///\n");
    }
    result.push_str("function docCarrier() -> Unit\n  return ()\nend function\n");
    result
}

// 関門: 生成文書の一覧では保証できない、標準docの実行結果・拒否・公開APIを守る。
// 固定したモジュールとmode別件数により、抽出漏れや0件の成功を拒否する。
#[test]
fn standard_doc_examples_behave_as_written() {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let directory = Directory(std::env::temp_dir().join(format!(
        "benitoite-stdlib-doc-{}-{stamp}",
        std::process::id()
    )));
    fs::create_dir(&directory.0).unwrap();
    let expected = [
        ("String", [1, 0, 0, 0]),
        ("List", [1, 0, 0, 0]),
        ("Option", [1, 0, 0, 0]),
        ("Result", [1, 0, 0, 0]),
        ("IO", [1, 1, 0, 0]),
        ("Failure", [1, 0, 0, 1]),
        ("Test.Property", [1, 0, 0, 0]),
        ("Scope", [1, 0, 0, 2]),
        ("Range", [2, 0, 1, 1]),
        ("NonEmptyList", [1, 0, 0, 0]),
        ("Log", [1, 0, 0, 0]),
    ];
    let (found, locations) = {
        let mut found = Vec::new();
        let mut locations = Vec::new();
        for module in STDLIB {
            let name = module.path.join(".");
            let lexed = lexer::lex(FileId(0), module.text.as_bytes());
            assert!(
                lexed.diagnostics.is_empty(),
                "{name}: {:?}",
                lexed.diagnostics
            );
            let parsed = parser::parse(
                FileId(0),
                SourceKind::Prelude,
                module.text.as_bytes(),
                newline::resolve_newlines(lexed.tokens),
                lexed.comments,
                lexed.pending,
                &mut IdGen::default(),
            );
            assert!(
                parsed.diagnostics.is_empty(),
                "{name}: {:?}",
                parsed.diagnostics
            );
            let extracted = doc_examples::extract(&parsed.module).unwrap();
            let mut counts = [0; 4];
            for (index, example) in extracted.examples.iter().enumerate() {
                let (slot, mode) = match example.expectation {
                    Expectation::Test => (0, "test"),
                    Expectation::Run { .. } => (1, "run"),
                    Expectation::Static => (2, "check"),
                    Expectation::Error { .. } => (3, "error"),
                };
                counts[slot] += 1;
                let file = format!("{}_{index}.bnt", name.replace('.', "_"));
                let input = carrier(
                    module.text,
                    usize::try_from(example.span.start.0).unwrap(),
                    usize::try_from(example.span.end.0).unwrap(),
                );
                fs::write(directory.0.join(&file), input).unwrap();
                let original = Source::new(
                    name.clone(),
                    SourceKind::Prelude,
                    module.text.as_bytes().to_vec(),
                );
                locations.push((
                    file,
                    mode,
                    original.line_col(example.span.start),
                    original.line_col(example.span.end),
                    example.span,
                ));
            }
            if !extracted.examples.is_empty() {
                found.push((name, counts));
            }
        }
        (found, locations)
    };
    assert_eq!(
        found,
        expected.map(|(name, counts)| (name.to_string(), counts))
    );
    assert_eq!(locations.len(), 18);

    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let exit = cli::execute(
        Command::Tool {
            tool: ToolCommand::Test,
            args: [
                "--doc",
                "--diagnostics=json",
                "--allow-effects=Assert.Check,Console.Write",
            ]
            .map(OsString::from)
            .into_iter()
            .chain([directory.0.clone().into_os_string()])
            .collect(),
        },
        CliEnv {
            stdout: OutputTarget::Capture(Arc::clone(&stdout)),
            stderr: OutputTarget::Capture(Arc::clone(&stderr)),
            stdin: StdinSource::Empty,
            working_directory: directory.0.clone(),
            color: false,
            mode: ExecMode::Direct,
            interrupt: Some(Box::new(NoInterrupt)),
            parts: None,
            heap: HeapConfig::default(),
            dev_panic: DevPanic::None,
            dev_alloc_stats: false,
        },
    );
    let out = String::from_utf8(stdout.lock().unwrap().clone()).unwrap();
    let err = String::from_utf8(stderr.lock().unwrap().clone()).unwrap();
    assert_eq!(exit, 0, "{out}\n{err}");
    assert!(err.is_empty(), "{err}");
    let rows: Vec<Value> = out
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    let examples: Vec<_> = rows
        .iter()
        .filter(|row| row["kind"] == "docExample")
        .collect();
    assert_eq!(examples.len(), locations.len());
    for (file, mode, start, end, span) in locations {
        let row = examples
            .iter()
            .find(|row| {
                row["id"]
                    .as_str()
                    .unwrap()
                    .ends_with(&format!("{file}:{}:doc:1", start.line))
            })
            .unwrap();
        assert_eq!(row["mode"], mode);
        assert_eq!(row["outcome"], "ok", "{row}");
        assert_eq!(row["location"]["start"]["offset"], span.start.0);
        assert_eq!(row["location"]["end"]["offset"], span.end.0);
        assert_eq!(row["location"]["start"]["line"], start.line);
        assert_eq!(row["location"]["start"]["column"], start.column);
        assert_eq!(row["location"]["end"]["line"], end.line);
        assert_eq!(row["location"]["end"]["column"], end.column);
    }
    assert_eq!(
        rows[rows.len() - 2],
        json!({
            "kind": "docSummary", "test": 12, "run": 1, "check": 1, "error": 4, "ignoredBlocks": 0,
        })
    );
    assert_eq!(rows.last().unwrap()["kind"], "testSummary");
    assert_eq!(rows.last().unwrap()["passed"], 18);
    assert_eq!(rows.last().unwrap()["failed"], 0);
}
