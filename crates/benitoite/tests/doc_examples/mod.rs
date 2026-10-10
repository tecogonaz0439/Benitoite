//! 文書に載せたコードの例の検査の共通の部分（設計書 06-06「同梱の Agent Skill の構成」・
//! 「言語の文書と日本語の訳」、実装プラン D21・D33）。
//! `tests/skill_examples.rs`（同梱の Skill の手で書く文書）と `tests/reference_examples.rs`
//! （英語の言語リファレンス）が、同じ規則で例を検査するために使う。
//!
//! 例の書き方（各文書の先頭のコメントにも書く）:
//! - 情報文字列が `benitoite` のブロックは、続く `output` のブロックの出力と比べて `run` する。
//!   `output` の最後の行に `exit N` を置けば終了状態も比べる（なければ 0）。
//! - `benitoite check` は `check` だけを行い、誤りも警告もないことを確かめる。
//! - `benitoite test` は `test` を行い、すべてのテストが成功することを確かめる。
//! - `benitoite error` は、`check` が誤りを報告し、続く `diagnostic` のブロックの各行が報告に含まれることを確かめる。
//! - 例の前の `files` のブロック（1 行目が `name: <名前>`、残りが内容）は、一時ディレクトリに置くファイルである。
//!   名前に `/` を含めば、途中のディレクトリも作る（モジュールの例のため）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::ffi::OsString;
use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, mpsc};
use std::time::Duration;

use benitoite::cli::{self, CliEnv, DevPanic};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::run::{NoInterrupt, OutputTarget, StdinSource};
use benitoite::vm::ExecMode;

/// 文書の中のコードブロック。`line` は開きの行（1 から数える）である。
pub struct Block {
    info: String,
    line: usize,
    body: String,
}

pub fn blocks(text: &str) -> Vec<Block> {
    let mut result = Vec::new();
    let mut open: Option<Block> = None;
    for (index, line) in text.lines().enumerate() {
        match open.as_mut() {
            None => {
                if let Some(info) = line.strip_prefix("```") {
                    open = Some(Block {
                        info: info.trim().to_string(),
                        line: index + 1,
                        body: String::new(),
                    });
                }
            }
            Some(block) => {
                if line == "```" {
                    result.push(open.take().unwrap());
                } else {
                    block.body.push_str(line);
                    block.body.push('\n');
                }
            }
        }
    }
    assert!(open.is_none(), "unclosed code block");
    result
}

pub enum Check {
    Run {
        stdout: String,
        stderr: String,
        exit: u8,
    },
    Static,
    Test,
    Error {
        lines: Vec<String>,
    },
}

pub struct Example {
    pub document: &'static str,
    pub line: usize,
    source: String,
    files: Vec<(String, String)>,
    check: Check,
}

pub fn examples(document: &'static str, text: &str) -> Result<Vec<Example>, String> {
    let blocks = blocks(text);
    let mut result = Vec::new();
    let mut files = Vec::new();
    let mut index = 0;
    while let Some(block) = blocks.get(index) {
        index += 1;
        let at = format!("{document}:{}", block.line);
        let next = blocks.get(index);
        let check = match block.info.as_str() {
            "files" => {
                let (first, content) = block.body.split_once('\n').unwrap_or((&block.body, ""));
                let name = first
                    .strip_prefix("name: ")
                    .ok_or_else(|| format!("{at}: a files block starts with `name: <name>`"))?;
                files.push((name.to_string(), content.to_string()));
                continue;
            }
            "benitoite" => {
                let output = next
                    .filter(|b| b.info == "output")
                    .ok_or_else(|| format!("{at}: a `benitoite` example needs an `output` block after it (or use `benitoite check`)"))?;
                index += 1;
                let mut lines: Vec<&str> = output.body.lines().collect();
                // 最後の行が `exit N`（N は数）のときだけ終了状態とみなす。
                let code = lines
                    .last()
                    .and_then(|l| l.strip_prefix("exit "))
                    .and_then(|c| c.parse::<u8>().ok());
                if code.is_some() {
                    lines.pop();
                }
                let exit = code.unwrap_or(0);
                let stdout = lines.iter().map(|l| format!("{l}\n")).collect();
                // 標準エラー出力は、続く `stderr` のブロックと比べる（なければ空であること）。
                let stderr = match blocks.get(index).filter(|b| b.info == "stderr") {
                    Some(b) => {
                        index += 1;
                        b.body.clone()
                    }
                    None => String::new(),
                };
                Check::Run {
                    stdout,
                    stderr,
                    exit,
                }
            }
            "benitoite check" => Check::Static,
            "benitoite test" => Check::Test,
            "benitoite error" => {
                let diagnostic = next.filter(|b| b.info == "diagnostic").ok_or_else(|| {
                    format!("{at}: a `benitoite error` example needs a `diagnostic` block after it")
                })?;
                index += 1;
                Check::Error {
                    lines: diagnostic
                        .body
                        .lines()
                        .filter(|l| !l.trim().is_empty())
                        .map(str::to_string)
                        .collect(),
                }
            }
            info if info.starts_with("benitoite") => {
                return Err(format!("{at}: unknown info string `{info}`"));
            }
            "output" | "diagnostic" | "stderr" => {
                return Err(format!(
                    "{at}: an `{}` block without an example before it",
                    block.info
                ));
            }
            _ => continue,
        };
        result.push(Example {
            document,
            line: block.line,
            source: block.body.clone(),
            files: std::mem::take(&mut files),
            check,
        });
    }
    if !files.is_empty() {
        return Err(format!(
            "{document}: a files block without an example after it"
        ));
    }
    Ok(result)
}

static NEXT_DIRECTORY: AtomicUsize = AtomicUsize::new(0);

/// 例一つの実行の上限。止まる例でテスト全体が止まらないようにする。
const TIME_LIMIT: Duration = Duration::from_secs(60);

/// 別のスレッドで実行し、上限を超えたら `None` を返す（スレッドは置き去りにする）。
fn execute(subcommand: &str, directory: &Path) -> Option<(u8, String, String)> {
    let (sender, receiver) = mpsc::channel();
    let subcommand = subcommand.to_string();
    let directory = directory.to_path_buf();
    std::thread::spawn(move || {
        // 上限を超えて受け手が去った後の送信の失敗は無視してよい。
        sender.send(execute_now(&subcommand, &directory)).ok();
    });
    receiver.recv_timeout(TIME_LIMIT).ok()
}

fn execute_now(subcommand: &str, directory: &Path) -> (u8, String, String) {
    let script = directory.join("main.bnt");
    let args = vec![OsString::from(subcommand), script.into_os_string()];
    let command = cli::parse_args(args).unwrap();
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let exit = cli::execute(
        command,
        CliEnv {
            stdout: OutputTarget::Capture(Arc::clone(&stdout)),
            stderr: OutputTarget::Capture(Arc::clone(&stderr)),
            stdin: StdinSource::Empty,
            working_directory: directory.to_path_buf(),
            color: false,
            mode: ExecMode::Direct,
            interrupt: Some(Box::new(NoInterrupt)),
            parts: None,
            heap: HeapConfig::default(),
            dev_panic: DevPanic::None,
            dev_alloc_stats: false,
        },
    );
    let out = String::from_utf8_lossy(&stdout.lock().unwrap()).into_owned();
    let err = String::from_utf8_lossy(&stderr.lock().unwrap()).into_owned();
    (exit, out, err)
}

/// 例を一つ検査し、期待との差を返す。
pub fn check_example(example: &Example) -> Option<String> {
    let directory = std::env::temp_dir().join(format!(
        "benitoite-doc-example-{}-{}",
        std::process::id(),
        NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed)
    ));
    if directory.exists() {
        fs::remove_dir_all(&directory).unwrap();
    }
    fs::create_dir_all(&directory).unwrap();
    fs::write(directory.join("main.bnt"), &example.source).unwrap();
    for (name, content) in &example.files {
        let path = directory.join(name);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, content).unwrap();
    }
    let subcommand = match &example.check {
        Check::Run { .. } => "run",
        Check::Static | Check::Error { .. } => "check",
        Check::Test => "test",
    };
    let Some((code, out, err)) = execute(subcommand, &directory) else {
        // 置き去りにしたスレッドがまだ使うので、ディレクトリは消さない。
        return Some(format!(
            "{subcommand}: did not finish within {TIME_LIMIT:?}"
        ));
    };
    let problem = match &example.check {
        Check::Run {
            stdout,
            stderr,
            exit,
        } => {
            if (code, out.as_str(), err.as_str()) == (*exit, stdout.as_str(), stderr.as_str()) {
                None
            } else {
                Some(format!(
                    "run: expected exit {exit}, stdout {stdout:?}, stderr {stderr:?}; got exit {code}, stdout {out:?}, stderr {err:?}"
                ))
            }
        }
        Check::Static => (code != 0 || !err.is_empty())
            .then(|| format!("check: expected no diagnostics, got exit {code}, stderr {err:?}")),
        Check::Test => {
            // 成功が 1 件以上あり、失敗も診断もないこと。
            let passed = out.contains("test result: ok.") && !out.contains("ok. 0 passed");
            (code != 0 || !passed || !err.is_empty()).then(|| format!("test: expected all tests to pass, got exit {code}, stdout {out:?}, stderr {err:?}"))
        }
        Check::Error { lines } => {
            let missing: Vec<&String> =
                lines.iter().filter(|l| !err.contains(l.as_str())).collect();
            (code == 0 || !missing.is_empty()).then(|| {
                format!("check: expected an error containing {missing:?}, got exit {code}, stderr {err:?}")
            })
        }
    };
    fs::remove_dir_all(&directory).unwrap();
    problem
}

/// `directory` の下の文書の例をすべて検査し、例の数と失敗の一覧を返す。失敗は
/// `<prefix><文書>:<行>: <内容>` の形にする。
pub fn check_documents(
    directory: &Path,
    documents: &[&'static str],
    prefix: &str,
) -> (usize, Vec<String>) {
    let mut failures = Vec::new();
    let mut count = 0;
    for document in documents {
        let text = fs::read_to_string(directory.join(document)).unwrap();
        match examples(document, &text) {
            Ok(examples) => {
                for example in &examples {
                    count += 1;
                    if let Some(problem) = check_example(example) {
                        failures.push(format!(
                            "{prefix}{}:{}: {problem}",
                            example.document, example.line
                        ));
                    }
                }
            }
            Err(error) => failures.push(format!("{prefix}{error}")),
        }
    }
    (count, failures)
}
