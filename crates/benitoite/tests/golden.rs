//! 初回リリース版の CLI のゴールデンテスト（設計書 07-03、ADR 0039・0224）。
//! 報告の分離のため、スクリプトが `{` で始まる行を標準エラー出力へ書くケースと、
//! 改行で終えずに標準エラー出力へ書いてから止まるケースは置かない（実装プラン C10）。
// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

#[path = "golden/differential.rs"]
mod differential;
#[path = "golden/formatting.rs"]
mod formatting;

use std::collections::BTreeMap;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use benitoite::cli::{self, CliEnv, Command, DevPanic};
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};
use differential::Comparison;

const GOLDEN_ROOTS: &[&str] = &["testdata"];
const BENCH_DIRS: &[&str] = &["../../tools/bench/programs"];
// 時計・乱数を使うケースは名前をここへ加える。CLI のオプションには独自の印を混ぜない。
const NONDETERMINISTIC_CASES: &[&str] = &["testdata/io/l40-clock-sleep.bnt"];
// 10-16「広げるものの一覧」の表と「ランタイムの内部への口」は、参照インタプリタの
// runtime_view を None と定めるため、これを要るケースだけ差分比較から除く。
// CLI の二方式・コア IR・フォーマッタの検査は残す（設計書 02-06「参照インタプリタの範囲」）。
const RUNTIME_VIEW_CASES: &[&str] = &["testdata/io/l40-process-attached.bnt"];
// 参照インタプリタは組み込みの呼び出しごとにリスト全体を写すため、5 万要素では
// 差分検査が 30 秒を超える。CLI の二方式の検査とコア IR の検査は残す（C05 の追加指示）。
const EXPENSIVE_REFERENCE_CASES: &[&str] = &["testdata/eval/list_hof_long.bnt"];
// 回収の強制（機能 `gc-stress`）は安全点ごとに生きている構造の全体を辿るので、長さに比例した
// 生きているリストを持つケースは二次の時間になり終わらない。回収の強制のビルドでだけ除き、
// 除いた名前を最後に示す（07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
const STRESS_EXCLUDED_CASES: &[&str] = &["testdata/eval/list_hof_long.bnt"];
const FILTER_ENV: &str = "BENITOITE_GOLDEN_FILTER";
const BLESS_ENV: &str = "BENITOITE_BLESS";

type TestResult<T> = Result<T, String>;

struct TestCase {
    path: PathBuf,
    stem: PathBuf,
    mode: String,
    options: Vec<String>,
    args: Vec<String>,
    stdin: Option<Vec<u8>>,
    text: Option<Vec<u8>>,
    /// `.text.stdout`。`test` の方式で、文章の形の結果の報告を確かめるテストだけに置く（実装プラン D12）
    text_stdout: Option<Vec<u8>>,
    expected: Actual,
}

#[derive(Debug, PartialEq, Eq)]
struct Actual {
    exit_code: u8,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    diagnostics: Vec<String>,
}

#[derive(Default)]
struct Summary {
    matched: usize,
    check_core_matched: usize,
    excluded: BTreeMap<String, usize>,
    warnings: Vec<String>,
    /// フォーマッタの性質を確かめた `check`・`run` のテストの数
    format_checked: usize,
    /// 性質の確かめから除いた理由ごとの数
    format_excluded: BTreeMap<&'static str, usize>,
}
impl Summary {
    fn record(&mut self, comparison: Comparison, name: &str, failures: &mut Vec<String>) {
        match comparison {
            Comparison::Matched => self.matched += 1,
            Comparison::Failed(reason) => failures.push(format!("{name}: {reason}")),
            Comparison::Excluded(reason) => *self.excluded.entry(reason).or_default() += 1,
        }
    }
}

// 関門: CLI の出力・診断・終了状態と実行器の入力形式を守る。ディレクトリの誤検出、
// オプションの渡し忘れ、IO 方式の違い、期待値の読み落としを捕まえる。旧実行器は
// 新しい CLI を通らず、複数のモジュールと .options を扱わないため、この境界が要る。
#[test]
fn golden_suite() {
    assert_eq!(
        std::env::current_dir().expect("cannot read working directory"),
        Path::new(env!("CARGO_MANIFEST_DIR")),
        "golden runner requires the crate directory as its working directory"
    );
    benitoite::runtime::panic::install_hook();
    let filter = std::env::var(FILTER_ENV).unwrap_or_default();
    let bless = std::env::var(BLESS_ENV).is_ok_and(|s| s == "1");
    let mut failures = Vec::new();
    let mut summary = Summary::default();
    let mut selected = 0;
    let mut stress_excluded: Vec<String> = Vec::new();
    for root in GOLDEN_ROOTS {
        let scripts = match discover_scripts(Path::new(root)) {
            Ok(scripts) => scripts,
            Err(error) => {
                failures.push(error);
                continue;
            }
        };
        for path in scripts {
            let name = path.display().to_string();
            if !name.contains(&filter) {
                continue;
            }
            selected += 1;
            if cfg!(feature = "gc-stress") && STRESS_EXCLUDED_CASES.contains(&name.as_str()) {
                stress_excluded.push(name);
                continue;
            }
            match load_case(path)
                .and_then(|case| run_case(&case, selected, bless, &mut summary, &mut failures))
            {
                Ok(()) => {}
                Err(error) => failures.push(format!("{name}: {error}")),
            }
        }
    }
    for dir in BENCH_DIRS {
        match sorted_entries(Path::new(dir)) {
            Err(error) => failures.push(error),
            Ok(entries) => {
                for entry in entries {
                    let path = entry.path();
                    if path.extension().is_none_or(|ext| ext != "bnt") {
                        continue;
                    }
                    let stem = path.with_extension("");
                    let name = path.display().to_string();
                    if !sidecar(&stem, "args.small").is_file() || !name.contains(&filter) {
                        continue;
                    }
                    selected += 1;
                    let result = lines(&sidecar(&stem, "args.small")).and_then(|args| {
                        let checked = pipeline::check_path(
                            &path,
                            CheckOptions {
                                require_main: true,
                                deny_warnings: false,
                            },
                        )
                        .map_err(|e| format!("entry error: {e:?}"))?;
                        let program = checked.program.ok_or_else(|| {
                            format!("benchmark check failed: {:?}", checked.diagnostics)
                        })?;
                        if NONDETERMINISTIC_CASES.contains(&name.as_str()) {
                            summary.record(
                                validate_core(program, Comparison::Excluded("clock/random".into())),
                                &name,
                                &mut failures,
                            );
                            return Ok(());
                        }
                        let entry = pipeline::entry_spec(&path)
                            .map_err(|e| format!("entry error: {e:?}"))?;
                        let directory = fs::canonicalize(dir).map_err(|e| e.to_string())?;
                        let input =
                            run::run_input(&entry, args, directory).map_err(|e| e.to_string())?;
                        summary.record(
                            differential::compare(
                                program,
                                checked.sources,
                                input,
                                VmConfig::default(),
                                ExecMode::Direct,
                            ),
                            &name,
                            &mut failures,
                        );
                        Ok(())
                    });
                    if let Err(error) = result {
                        failures.push(format!("{name}: {error}"));
                    }
                }
            }
        }
    }
    if selected == 0 {
        failures.push(format!("{FILTER_ENV} matched no test: {filter:?}"));
    }
    eprintln!(
        "golden: {selected} cases; core IR/differential: {} matched",
        summary.matched
    );
    eprintln!("check mode core IR: {} matched", summary.check_core_matched);
    for name in &stress_excluded {
        eprintln!("gc-stress excluded: {name}");
    }
    for (reason, count) in summary.excluded {
        eprintln!("differential excluded: {reason}: {count}");
    }
    let format_excluded: usize = summary.format_excluded.values().sum();
    eprintln!(
        "formatter properties: {} checked, {format_excluded} excluded",
        summary.format_checked
    );
    for (reason, count) in &summary.format_excluded {
        eprintln!("formatter properties excluded: {reason}: {count}");
    }
    for failure in &failures {
        eprintln!("{failure}");
    }
    for warning in summary.warnings {
        eprintln!("warning: {warning}");
    }
    assert!(
        failures.is_empty(),
        "golden tests failed ({} failure(s)):\n{}",
        failures.len(),
        failures.join("\n")
    );
}

fn discover_scripts(root: &Path) -> TestResult<Vec<PathBuf>> {
    let mut pending = vec![root.to_path_buf()];
    let mut scripts = Vec::new();
    while let Some(dir) = pending.pop() {
        for entry in sorted_entries(&dir)? {
            let path = entry.path();
            let kind = entry.file_type().map_err(|e| e.to_string())?;
            if kind.is_dir() {
                let name = entry.file_name();
                let name = name.to_string_lossy();
                if name.ends_with(".files") || name.ends_with(".formatted") {
                    continue;
                }
                if sidecar(&path, "mode").is_file() {
                    scripts.push(path);
                } else {
                    pending.push(path);
                }
            } else if kind.is_file() && path.extension().is_some_and(|ext| ext == "bnt") {
                scripts.push(path);
            }
        }
    }
    scripts.sort();
    Ok(scripts)
}
fn sorted_entries(dir: &Path) -> TestResult<Vec<fs::DirEntry>> {
    let mut entries = fs::read_dir(dir)
        .and_then(|entries| entries.collect::<io::Result<Vec<_>>>())
        .map_err(|e| format!("{}: {e}", dir.display()))?;
    entries.sort_by_key(fs::DirEntry::file_name);
    Ok(entries)
}
// 拡張子を置き換えずに付け足す。名前にピリオドがあるディレクトリでも隣の期待値を読む。
fn sidecar(stem: &Path, suffix: &str) -> PathBuf {
    let mut path = stem.as_os_str().to_os_string();
    path.push(format!(".{suffix}"));
    PathBuf::from(path)
}
fn optional(path: &Path) -> TestResult<Option<Vec<u8>>> {
    match fs::read(path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("{}: {e}", path.display())),
    }
}
fn lines(path: &Path) -> TestResult<Vec<String>> {
    let text = String::from_utf8(optional(path)?.unwrap_or_default())
        .map_err(|e| format!("{}: {e}", path.display()))?;
    Ok(text
        .split_terminator('\n')
        .map(|line| line.strip_suffix('\r').unwrap_or(line).to_owned())
        .collect())
}
fn load_case(path: PathBuf) -> TestResult<TestCase> {
    let stem = if path.is_dir() {
        path.clone()
    } else {
        path.with_extension("")
    };
    if sidecar(&stem, "opts").exists() {
        return Err("legacy .opts found; rename it to .options and use CLI options".into());
    }
    let mode = fs::read_to_string(sidecar(&stem, "mode"))
        .map_err(|e| format!(".mode: {e}"))?
        .trim()
        .to_owned();
    match mode.as_str() {
        "check" | "run" | "fmt" | "fmt-check" | "test" => {}
        _ => return Err(format!("unknown .mode: {mode:?}")),
    }
    let options = lines(&sidecar(&stem, "options"))?;
    if has_diagnostics_option(&options) && sidecar(&stem, "diag.json").exists() {
        return Err(".options with --diagnostics cannot have .diag.json".into());
    }
    // `.exit` は必須である（07-03「ゴールデンテストの形式（初回リリース版）」）。
    let exit_code = match optional(&sidecar(&stem, "exit"))? {
        None => return Err("missing .exit".into()),
        Some(bytes) => {
            let text = String::from_utf8(bytes).map_err(|e| format!(".exit: {e}"))?;
            let value = text.trim();
            if value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) {
                return Err(format!("invalid .exit: {value:?}"));
            }
            value.parse::<u8>().map_err(|e| format!(".exit: {e}"))?
        }
    };
    Ok(TestCase {
        options,
        args: lines(&sidecar(&stem, "args"))?,
        stdin: optional(&sidecar(&stem, "stdin"))?,
        text: optional(&sidecar(&stem, "text.stderr"))?,
        text_stdout: optional(&sidecar(&stem, "text.stdout"))?,
        expected: Actual {
            exit_code,
            stdout: optional(&sidecar(&stem, "stdout"))?.unwrap_or_default(),
            stderr: optional(&sidecar(&stem, "stderr"))?.unwrap_or_default(),
            diagnostics: lines(&sidecar(&stem, "diag.json"))?,
        },
        path,
        stem,
        mode,
    })
}
fn has_diagnostics_option(options: &[String]) -> bool {
    options
        .iter()
        .any(|s| s == "--diagnostics" || s.starts_with("--diagnostics="))
}
fn command(case: &TestCase, text: bool) -> Result<Command, String> {
    let mut args = vec![OsString::from(&case.mode)];
    if !text && !has_diagnostics_option(&case.options) {
        args.push("--diagnostics=json".into());
    }
    // 文章の確認では明示した診断形式も外し、CLI の既定を使う。
    let mut skip_value = false;
    for option in &case.options {
        if skip_value {
            skip_value = false;
            continue;
        }
        if text && option == "--diagnostics" {
            skip_value = true;
            continue;
        }
        if text && option.starts_with("--diagnostics=") {
            continue;
        }
        args.push(option.into());
    }
    args.push(case.path.as_os_str().to_owned());
    if case.mode == "run" {
        args.extend(case.args.iter().map(OsString::from));
    }
    cli::parse_args(args)
}
fn execute(
    case: &TestCase,
    directory: PathBuf,
    mode: ExecMode,
    text: bool,
) -> (u8, Vec<u8>, Vec<u8>) {
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let exit = match command(case, text) {
        Ok(command) => cli::execute(
            command,
            CliEnv {
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                stdin: case
                    .stdin
                    .clone()
                    .map_or(StdinSource::Empty, StdinSource::Bytes),
                working_directory: directory,
                color: false,
                mode,
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
fn split_actual(exit_code: u8, stdout: Vec<u8>, bytes: Vec<u8>) -> TestResult<Actual> {
    let mut stderr = Vec::new();
    let mut diagnostics = Vec::new();
    for line in bytes.split_inclusive(|b| *b == b'\n') {
        let body = line.strip_suffix(b"\n").unwrap_or(line);
        let body = body.strip_suffix(b"\r").unwrap_or(body);
        if body.starts_with(b"{") && body.ends_with(b"}") {
            diagnostics.push(
                String::from_utf8(body.to_vec())
                    .map_err(|e| format!("diagnostic is not UTF-8: {e}"))?,
            );
        } else {
            stderr.extend_from_slice(line);
        }
    }
    Ok(Actual {
        exit_code,
        stdout,
        stderr,
        diagnostics,
    })
}

fn run_case(
    case: &TestCase,
    index: usize,
    bless: bool,
    summary: &mut Summary,
    failures: &mut Vec<String>,
) -> TestResult<()> {
    let name = case.path.display().to_string();
    if case.mode == "fmt" || case.mode == "fmt-check" {
        return formatting::run_fmt_case(case, index, bless, summary, failures);
    }
    // `test` の方式は fmt と同じく頭で分け、フォーマッタの性質の確かめ（対象は `check`・`run`）に数えない
    // （実装プラン D12「手順の要点」の 6）。
    if case.mode != "test" {
        // `check`・`run` のすべてのテストで、フォーマッタの性質を確かめる（ADR 0224 の決定 4）。コマンドラインが
        // 使い方の誤りになるテストは `--deny-warnings` を決められないので除き、除いた数に含める。
        {
            let property = match command(case, false)
                .as_ref()
                .map(formatting::deny_warnings_of)
            {
                Ok(Some(deny_warnings)) => formatting::check_properties(case, deny_warnings)?,
                _ => formatting::Property::Excluded("command line error"),
            };
            match property {
                formatting::Property::Checked => summary.format_checked += 1,
                formatting::Property::Excluded(reason) => {
                    *summary.format_excluded.entry(reason).or_default() += 1;
                }
                formatting::Property::Failed(reason) => {
                    failures.push(format!("{name}: formatter property: {reason}"));
                }
            }
        }
    }
    let mut actuals = Vec::new();
    // `test` は利用者のテストの関数を実行するので、`run` と同じく IO の二つの方式で確かめる（実装プラン D12）。
    let modes: &[ExecMode] = if case.mode == "run" || case.mode == "test" {
        &[ExecMode::Direct, ExecMode::Request]
    } else {
        &[ExecMode::Direct]
    };
    for mode in modes {
        let (exit, out, err) = with_directory(case, index, summary, |directory| {
            Ok(execute(case, directory, *mode, false))
        })?;
        let actual = split_actual(exit, out, err)?;
        if !bless {
            compare_actual(
                &case.expected,
                &actual,
                &format!("{name} ({mode:?})"),
                failures,
            );
        }
        actuals.push(actual);
    }
    let consistent = actuals.iter().all(|actual| actual == &actuals[0]);
    if !consistent {
        compare_actual(
            &actuals[0],
            &actuals[1],
            &format!("{name} (Direct versus Request)"),
            failures,
        );
    }
    let text = if case.text.is_some() || case.text_stdout.is_some() {
        let (_, out, bytes) = with_directory(case, index, summary, |directory| {
            Ok(execute(case, directory, ExecMode::Direct, true))
        })?;
        if !bless {
            if let Some(expected) = case.text.as_deref() {
                compare_bytes(
                    expected,
                    &bytes,
                    &format!("{name} (Direct) .text.stderr"),
                    failures,
                );
            }
            if let Some(expected) = case.text_stdout.as_deref() {
                compare_bytes(
                    expected,
                    &out,
                    &format!("{name} (Direct) .text.stdout"),
                    failures,
                );
            }
        }
        Some((out, bytes))
    } else {
        None
    };
    if case.mode == "run"
        && let Ok(Command::Run { options, .. }) = command(case, false)
    {
        let result = with_directory(case, index, summary, |directory| {
            let checked = match pipeline::check_path(
                &case.path,
                CheckOptions {
                    require_main: true,
                    deny_warnings: options.deny_warnings,
                },
            ) {
                Ok(checked) => checked,
                // 実行を始めるファイルの指定に誤りがあるケースも CLI の期待値で確かめる。
                Err(_) => return Ok(None),
            };
            let Some(program) = checked.program else {
                return Ok(None);
            };
            let reason = if case.stdin.is_some() {
                Some("stdin")
            } else if name.starts_with("testdata/network/") {
                // サーバのタスクと runtime_view は参照インタプリタの対象外（実装プラン L33、設計書 02-06）。
                Some("network (tasks and runtime view)")
            } else if NONDETERMINISTIC_CASES.contains(&name.as_str()) {
                Some("clock/random")
            } else if RUNTIME_VIEW_CASES.contains(&name.as_str()) {
                Some("runtime view (Process.runAttached)")
            } else if EXPENSIVE_REFERENCE_CASES.contains(&name.as_str()) {
                Some("reference list conversion cost")
            } else {
                None
            };
            if let Some(reason) = reason {
                return Ok(Some(validate_core(
                    program,
                    Comparison::Excluded(reason.into()),
                )));
            }
            let entry =
                pipeline::entry_spec(&case.path).map_err(|e| format!("entry error: {e:?}"))?;
            let input = run::run_input(&entry, case.args.clone(), directory)
                .map_err(|e| format!("run input: {e}"))?;
            let config = VmConfig {
                max_call_stack_bytes: options.max_call_stack,
                ..VmConfig::default()
            };
            Ok(Some(differential::compare(
                program,
                checked.sources,
                input,
                config,
                ExecMode::Direct,
            )))
        })?;
        if let Some(result) = result {
            summary.record(result, &name, failures);
        }
    }
    // 関門: CLI の check が成功した入力も脱糖後に型が付く契約を守る。従来は run だけを
    // 検査したため、実行を要しない言語機能の脱糖の誤りを見逃した（実装プラン F19）。
    if case.expected.exit_code == 0
        && let Ok(Command::Check { options, .. }) = command(case, false)
    {
        let checked = pipeline::check_path(
            &case.path,
            CheckOptions {
                require_main: true,
                deny_warnings: options.deny_warnings,
            },
        )
        .map_err(|e| format!("entry error: {e:?}"))?;
        let program = checked
            .program
            .ok_or_else(|| format!("successful check has no program: {:?}", checked.diagnostics))?;
        let result = validate_core(program, Comparison::Matched);
        if matches!(result, Comparison::Matched) {
            summary.check_core_matched += 1;
        }
        summary.record(result, &name, failures);
    }
    if bless && consistent {
        write_expected(case, &actuals[0], text.as_ref())?;
    }
    Ok(())
}
// 入力を比較できない場合も、脱糖したすべてのプログラムの IR を検査する（設計書 07-03）。
fn validate_core(checked: pipeline::CheckedProgram, success: Comparison) -> Comparison {
    let thread = std::thread::Builder::new()
        .name("golden-core-check".into())
        .stack_size(pipeline::STAGE_STACK_BYTES)
        .spawn(move || {
            let core = match pipeline::desugar_checked(&checked) {
                Ok(core) => core,
                Err(error) => return Comparison::Failed(format!("desugaring failed: {error:?}")),
            };
            let errors = benitoite::ir::check::check_program(&core);
            if errors.is_empty() {
                success
            } else {
                Comparison::Failed(format!("core IR check failed: {errors:?}"))
            }
        });
    match thread {
        Ok(thread) => thread
            .join()
            .unwrap_or_else(|_| Comparison::Failed("core IR check: stage thread panicked".into())),
        Err(error) => Comparison::Failed(format!("core IR check: cannot start stage: {error}")),
    }
}

fn with_directory<T>(
    case: &TestCase,
    index: usize,
    summary: &mut Summary,
    action: impl FnOnce(PathBuf) -> TestResult<T>,
) -> TestResult<T> {
    let directory =
        std::env::temp_dir().join(format!("benitoite-golden-{}-{index}", std::process::id()));
    if directory.exists() {
        fs::remove_dir_all(&directory)
            .map_err(|e| format!("reset {}: {e}", directory.display()))?;
    }
    fs::create_dir_all(&directory).map_err(|e| e.to_string())?;
    let result = (|| {
        let files = sidecar(&case.stem, "files");
        if files.exists() {
            copy_files(&files, &directory)?;
        }
        action(directory.clone())
    })();
    if let Err(e) = fs::remove_dir_all(&directory) {
        summary
            .warnings
            .push(format!("cannot remove {}: {e}", directory.display()));
    }
    result
}
fn copy_files(source: &Path, target: &Path) -> TestResult<()> {
    for entry in sorted_entries(source)? {
        let destination = target.join(entry.file_name());
        let kind = entry.file_type().map_err(|e| e.to_string())?;
        if kind.is_dir() {
            fs::create_dir(&destination).map_err(|e| e.to_string())?;
            copy_files(&entry.path(), &destination)?;
        } else if kind.is_file() {
            fs::copy(entry.path(), destination).map_err(|e| e.to_string())?;
        } else {
            return Err(format!(
                "unsupported .files entry: {}",
                entry.path().display()
            ));
        }
    }
    Ok(())
}
fn compare_actual(expected: &Actual, actual: &Actual, label: &str, failures: &mut Vec<String>) {
    if expected.exit_code != actual.exit_code {
        failures.push(format!(
            "{label} .exit: expected {}, actual {}",
            expected.exit_code, actual.exit_code
        ));
    }
    compare_bytes(
        &expected.stdout,
        &actual.stdout,
        &format!("{label} .stdout"),
        failures,
    );
    compare_bytes(
        &expected.stderr,
        &actual.stderr,
        &format!("{label} .stderr"),
        failures,
    );
    if expected.diagnostics != actual.diagnostics {
        failures.push(format!(
            "{label} .diag.json:\n- expected: {}\n+ actual: {}",
            expected.diagnostics.join("\n"),
            actual.diagnostics.join("\n")
        ));
    }
}
fn compare_bytes(expected: &[u8], actual: &[u8], label: &str, failures: &mut Vec<String>) {
    if expected != actual {
        let offset = expected
            .iter()
            .zip(actual)
            .position(|(a, b)| a != b)
            .unwrap_or(expected.len().min(actual.len()));
        failures.push(format!(
            "{label}: first differing byte {offset}\n- expected: {:?}\n+ actual: {:?}",
            String::from_utf8_lossy(expected),
            String::from_utf8_lossy(actual)
        ));
    }
}
// 文章の形の期待値は、`.text.stderr`・`.text.stdout` のうち置いてあるものだけを書き直す。
fn write_expected(
    case: &TestCase,
    actual: &Actual,
    text: Option<&(Vec<u8>, Vec<u8>)>,
) -> TestResult<()> {
    fs::write(
        sidecar(&case.stem, "exit"),
        format!("{}\n", actual.exit_code),
    )
    .map_err(|e| e.to_string())?;
    write_nonempty(&sidecar(&case.stem, "stdout"), &actual.stdout)?;
    write_nonempty(&sidecar(&case.stem, "stderr"), &actual.stderr)?;
    let mut diagnostics = actual.diagnostics.join("\n").into_bytes();
    if !diagnostics.is_empty() {
        diagnostics.push(b'\n');
    }
    write_nonempty(&sidecar(&case.stem, "diag.json"), &diagnostics)?;
    if let Some((out, err)) = text {
        if case.text.is_some() {
            fs::write(sidecar(&case.stem, "text.stderr"), err).map_err(|e| e.to_string())?;
        }
        if case.text_stdout.is_some() {
            fs::write(sidecar(&case.stem, "text.stdout"), out).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}
fn write_nonempty(path: &Path, bytes: &[u8]) -> TestResult<()> {
    if bytes.is_empty() {
        match fs::remove_file(path) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(format!("{}: {e}", path.display())),
        }
    } else {
        fs::write(path, bytes).map_err(|e| format!("{}: {e}", path.display()))
    }
}
