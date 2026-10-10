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

/// `fmt`・`fmt-check` のテストを一つ実行する（実装プラン D04「`fmt` と `fmt-check` の方式」）。
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
    let originals = script_files(&case.path)?;
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
            } else if entry_path.extension().is_some_and(|ext| ext == "bnt") {
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
        match format_source(file, SourceKind::User, &once.text) {
            Ok(again) if !again.changed => {}
            Ok(_) => {
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
