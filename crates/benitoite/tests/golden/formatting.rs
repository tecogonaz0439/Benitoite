//! ゴールデンテストの `fmt`・`fmt-check` の方式と、`check`・`run` のテストでのフォーマッタの性質の確かめ
//! （設計書 07-03「ゴールデンテストの形式（初回リリース版）」、06-03「テスト」）。

use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use benitoite::base::{FileId, SourceKind};
use benitoite::cli::tools::formatter::{FormatError, format_source};
use benitoite::cli::{self, CliEnv, Command, DevPanic};
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::run::{NoInterrupt, OutputTarget, StdinSource};
use benitoite::vm::ExecMode;

use super::{
    Summary, TestCase, TestResult, compare_actual, compare_bytes, copy_files,
    has_diagnostics_option, sidecar, sorted_entries, split_actual, with_directory, write_expected,
};

/// `fmt`・`fmt-check` のテストを一つ実行する（設計書 06-01「`fmt` のコマンドライン（初回リリース版）」）。
pub(super) fn run_fmt_case(
    case: &TestCase,
    index: usize,
    bless: bool,
    summary: &mut Summary,
    failures: &mut Vec<String>,
) -> TestResult<()> {
    let name = case.path.display().to_string();
    let check = case.mode == "fmt-check";
    let file_name = case
        .path
        .file_name()
        .ok_or_else(|| "test path has no file name".to_owned())?;
    let originals: Vec<_> = script_files(&case.path)?
        .into_iter()
        .filter(|(path, _)| path.extension().is_some_and(|ext| ext == "bnt"))
        .collect();
    for path in stale_formatted(case, &originals)? {
        if bless {
            remove_formatted(&path)?;
        } else {
            failures.push(format!("{name}: stale .formatted: {}", path.display()));
        }
    }
    if bless && case.path.is_dir() {
        remove_empty_dirs(&sidecar(&case.stem, "formatted"))?;
    }
    let (actual, results) = with_directory(case, index, summary, |directory| {
        let copied = directory.join(file_name);
        if case.path.is_dir() {
            fs::create_dir(&copied).map_err(|e| e.to_string())?;
            copy_files(&case.path, &copied)?;
        } else {
            fs::copy(&case.path, &copied).map_err(|e| e.to_string())?;
        }
        let (exit, out, err) = execute_fmt(case, check, &copied, directory.clone());
        // 表示名のうち一時ディレクトリの部分を、テストのあるディレクトリ（`testdata/fmt`）に置き換える。
        let shown = case
            .path
            .parent()
            .unwrap_or(Path::new(""))
            .display()
            .to_string();
        let temp = directory.display().to_string();
        let err = String::from_utf8_lossy(&err)
            .replace(&temp, &shown)
            .into_bytes();
        let mut results = Vec::new();
        for (relative, _) in &originals {
            let path = if case.path.is_dir() {
                copied.join(relative)
            } else {
                copied.clone()
            };
            results.push(fs::read(&path).map_err(|e| format!("{}: {e}", path.display()))?);
        }
        Ok((split_actual(exit, out, err)?, results))
    })?;
    if !check {
        let previous_failures = failures.len();
        for (index, ((relative, _), result)) in originals.iter().zip(&results).enumerate() {
            let file = FileId(u32::try_from(index).map_err(|e| e.to_string())?);
            let context = format!("{name} formatted {}", relative.display());
            match is_idempotent(file, result) {
                Ok(true) | Err(FormatError::Syntax(_)) => {}
                Ok(false) => failures.push(format!("{context}: formatting is not idempotent")),
                Err(error) => failures.push(format!(
                    "{context}: formatted source cannot be formatted again: {error:?}"
                )),
            }
        }
        // 冪等でない結果を期待値として固定しない（設計書 06-03「テスト」）。
        if bless && failures.len() != previous_failures {
            return Ok(());
        }
    }
    if bless {
        write_expected(case, &actual, None)?;
        if !check {
            bless_formatted(case, &originals, &results)?;
        }
        return Ok(());
    }
    compare_actual(&case.expected, &actual, &name, failures);
    for ((relative, original), result) in originals.iter().zip(&results) {
        let expected = if check {
            original.clone()
        } else {
            match super::optional(&formatted_path(case, relative))? {
                Some(bytes) => bytes,
                None => original.clone(),
            }
        };
        compare_bytes(
            &expected,
            result,
            &format!("{name} formatted {}", relative.display()),
            failures,
        );
    }
    Ok(())
}

/// スクリプトの `.bnt` を、テストのパスからの相対パスと内容の組で返す。ファイルのテストでは相対パスはファイル名である。
fn script_files(path: &Path) -> TestResult<Vec<(PathBuf, Vec<u8>)>> {
    if !path.is_dir() {
        let bytes = fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
        let name = PathBuf::from(path.file_name().unwrap_or_default());
        return Ok(vec![(name, bytes)]);
    }
    let mut files = Vec::new();
    let mut pending = vec![path.to_path_buf()];
    while let Some(dir) = pending.pop() {
        for entry in sorted_entries(&dir)? {
            let entry_path = entry.path();
            let kind = entry.file_type().map_err(|e| e.to_string())?;
            if kind.is_dir() {
                pending.push(entry_path);
            } else if entry_path
                .extension()
                .is_some_and(|ext| ext == "bnt" || ext == "wasm")
            {
                let bytes = fs::read(&entry_path).map_err(|e| e.to_string())?;
                let relative = entry_path
                    .strip_prefix(path)
                    .map_err(|e| e.to_string())?
                    .to_path_buf();
                files.push((relative, bytes));
            }
        }
    }
    files.sort();
    Ok(files)
}

/// 期待する整形の結果のファイル（`<名前>.formatted` か `<名前>.formatted/<相対パス>`）。
fn formatted_path(case: &TestCase, relative: &Path) -> PathBuf {
    let base = sidecar(&case.stem, "formatted");
    if case.path.is_dir() {
        base.join(relative)
    } else {
        base
    }
}

// 元のスクリプトだけを走査すると、削除されたファイルの期待値を見落とす。
fn stale_formatted(case: &TestCase, originals: &[(PathBuf, Vec<u8>)]) -> TestResult<Vec<PathBuf>> {
    let base = sidecar(&case.stem, "formatted");
    if !base.exists() {
        return Ok(Vec::new());
    }
    if case.mode == "fmt-check" {
        return Ok(vec![base]);
    }
    if !case.path.is_dir() {
        return Ok(Vec::new());
    }
    let mut stale = Vec::new();
    let mut pending = vec![base.clone()];
    while let Some(dir) = pending.pop() {
        for entry in sorted_entries(&dir)? {
            let path = entry.path();
            if entry.file_type().map_err(|e| e.to_string())?.is_dir() {
                pending.push(path);
            } else {
                let relative = path.strip_prefix(&base).map_err(|e| e.to_string())?;
                if !originals.iter().any(|(original, _)| original == relative) {
                    stale.push(path);
                }
            }
        }
    }
    stale.sort();
    Ok(stale)
}

/// 古い期待値を消す。ディレクトリを指すシンボリックリンクもリンク自体だけを消す。
pub(super) fn remove_formatted(path: &Path) -> TestResult<()> {
    let kind = fs::symlink_metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let result = if kind.is_dir() {
        fs::remove_dir_all(path)
    } else {
        fs::remove_file(path)
    };
    result.map_err(|e| format!("{}: {e}", path.display()))
}

/// 書き直しの指定で `.formatted` を書き直す。元と同じ結果のファイルは `.formatted` を作らず、あれば消す。
fn bless_formatted(
    case: &TestCase,
    originals: &[(PathBuf, Vec<u8>)],
    results: &[Vec<u8>],
) -> TestResult<()> {
    for ((relative, original), result) in originals.iter().zip(results) {
        let path = formatted_path(case, relative);
        if result == original {
            match fs::remove_file(&path) {
                Ok(()) => {}
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                Err(e) => return Err(format!("{}: {e}", path.display())),
            }
        } else {
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            fs::write(&path, result).map_err(|e| format!("{}: {e}", path.display()))?;
        }
    }
    if case.path.is_dir() {
        remove_empty_dirs(&sidecar(&case.stem, "formatted"))?;
    }
    Ok(())
}

/// 空になったディレクトリを、下から順に消す（根も空なら消す）。
fn remove_empty_dirs(dir: &Path) -> TestResult<()> {
    if !dir.is_dir() {
        return Ok(());
    }
    for entry in sorted_entries(dir)? {
        if entry.file_type().map_err(|e| e.to_string())?.is_dir() {
            remove_empty_dirs(&entry.path())?;
        }
    }
    if sorted_entries(dir)?.is_empty() {
        fs::remove_dir(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    }
    Ok(())
}

fn execute_fmt(
    case: &TestCase,
    check: bool,
    path: &Path,
    directory: PathBuf,
) -> (u8, Vec<u8>, Vec<u8>) {
    let mut args = vec![OsString::from("fmt")];
    if check {
        args.push("--check".into());
    }
    if !has_diagnostics_option(&case.options) {
        args.push("--diagnostics=json".into());
    }
    args.extend(case.options.iter().map(OsString::from));
    args.push(path.as_os_str().to_owned());
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let exit = match cli::parse_args(args) {
        Ok(command) => cli::execute(
            command,
            CliEnv {
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                stdin: StdinSource::Empty,
                working_directory: directory,
                color: false,
                mode: ExecMode::Direct,
                interrupt: Some(Box::new(NoInterrupt)),
                parts: None,
                heap: HeapConfig::default(),
                dev_panic: DevPanic::None,
                dev_alloc_stats: false,
            },
        ),
        Err(detail) => {
            let message = format!(
                "{}\n{}\n",
                cli::text::USAGE_ERROR.replace("{detail}", &detail),
                cli::text::SEE_HELP
            );
            stderr.lock().unwrap().extend_from_slice(message.as_bytes());
            2
        }
    };
    let out = stdout.lock().unwrap().clone();
    let err = stderr.lock().unwrap().clone();
    (exit, out, err)
}

/// フォーマッタの性質の確かめの結果。
pub(super) enum Property {
    Checked,
    Excluded(&'static str),
    Failed(String),
}

/// 実際の整形の結果を再び整形し、変わらないことを確かめる（設計書 06-03「テスト」）。
fn is_idempotent(file: FileId, formatted: &[u8]) -> Result<bool, FormatError> {
    format_source(file, SourceKind::User, formatted).map(|again| !again.changed)
}

/// `check`・`run` のテストについて、整形の冪等性と、整形の前後で `check` の診断のコードと文言の並びが同じことを
/// 確かめる（位置は比べない。設計書 07-03「ゴールデンテストの形式（初回リリース版）」）。
pub(super) fn check_properties(case: &TestCase, deny_warnings: bool) -> TestResult<Property> {
    let mut files = script_files(&case.path)?;
    if case.path.is_dir() {
        // `check_files` は最初の項目を入口にするので、`main.bnt` を先頭にする。ないものは入口を決められない。
        let Some(main) = files.iter().position(|(p, _)| p == Path::new("main.bnt")) else {
            return Ok(Property::Excluded("directory without main.bnt"));
        };
        let entry = files.remove(main);
        files.insert(0, entry);
    }
    let mut formatted = Vec::new();
    for (index, (relative, text)) in files.iter().enumerate() {
        if relative.extension().is_some_and(|ext| ext == "wasm") {
            formatted.push(text.clone());
            continue;
        }
        let file = FileId(u32::try_from(index).map_err(|e| e.to_string())?);
        let once = match format_source(file, SourceKind::User, text) {
            Ok(once) => once,
            Err(FormatError::Syntax(_)) => return Ok(Property::Excluded("syntax error")),
            Err(FormatError::Verify(message)) => {
                return Ok(Property::Failed(format!(
                    "{}: verification failed: {message}",
                    relative.display()
                )));
            }
        };
        match is_idempotent(file, &once.text) {
            Ok(true) => {}
            Ok(false) => {
                return Ok(Property::Failed(format!(
                    "{}: formatting is not idempotent",
                    relative.display()
                )));
            }
            Err(error) => {
                return Ok(Property::Failed(format!(
                    "{}: formatted source cannot be formatted again: {error:?}",
                    relative.display()
                )));
            }
        }
        formatted.push(once.text);
    }
    let options = CheckOptions {
        require_main: true,
        deny_warnings,
    };
    let names: Vec<String> = files
        .iter()
        .map(|(p, _)| p.to_string_lossy().replace('\\', "/"))
        .collect();
    let before: Vec<(&str, &[u8])> = names
        .iter()
        .zip(&files)
        .map(|(n, (_, t))| (n.as_str(), t.as_slice()))
        .collect();
    let after: Vec<(&str, &[u8])> = names
        .iter()
        .zip(&formatted)
        .map(|(n, t)| (n.as_str(), t.as_slice()))
        .collect();
    let before = diagnostic_summary(&pipeline::check_files(&before, options));
    let after = diagnostic_summary(&pipeline::check_files(&after, options));
    if before == after {
        Ok(Property::Checked)
    } else {
        Ok(Property::Failed(format!(
            "check diagnostics changed by formatting:\n- before: {before:?}\n+ after: {after:?}"
        )))
    }
}

fn diagnostic_summary(result: &pipeline::CheckResult) -> Vec<(String, String)> {
    result
        .diagnostics
        .iter()
        .map(|d| (format!("{:?}", d.code), d.message.clone()))
        .collect()
}

/// テストのコマンドラインから `--deny-warnings` の指定を読む。
pub(super) fn deny_warnings_of(command: &Command) -> Option<bool> {
    if let Command::Check { options, .. } | Command::Run { options, .. } = command {
        Some(options.deny_warnings)
    } else {
        None
    }
}
