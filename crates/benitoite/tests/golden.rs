#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
//! ゴールデンテスト、IO 方式の一致、参照インタプリタとの差分を公開 API で確かめる
//! （設計書 07-03「ゴールデンテスト」「差分テスト」「IO の方式のテスト」「コア IR の検査」）。
// テストの失敗は panic で表すため、テストコードではこれらを許す（実装規約 00-02「#[allow] を書いてよい箇所」）。

use std::collections::BTreeMap;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use benitoite::base::{SourceKind, SourceTable, Span};
use benitoite::bytecode::program::MainKind;
use benitoite::diag::render::{TextOptions, render_check_text, render_json_line, render_one_text};
use benitoite::diag::{Diagnostic, ReportKind};
use benitoite::pipeline::{self, CheckResult, CompileError};
use benitoite::refinterp::{self, RefOutcome};
use benitoite::runtime::executor::{ExecMode, ExecOptions};
use benitoite::runtime::io::IoEvent;
use benitoite::runtime::run::{self, RunEnd};
use benitoite::runtime::test_io::TestIo;
use benitoite::runtime::{ResourceError, RuntimeError, Stop};
use benitoite::vm::DEFAULT_MAX_CALL_STACK;

const FILTER_ENV: &str = "BENITOITE_GOLDEN_FILTER";
const BLESS_ENV: &str = "BENITOITE_BLESS";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Mode {
    Check,
    Run,
}

impl Mode {
    fn parse(value: &str) -> Option<Mode> {
        match value {
            "check" => Some(Mode::Check),
            "run" => Some(Mode::Run),
            _ => None,
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Mode::Check => "check",
            Mode::Run => "run",
        }
    }
}

#[derive(Debug)]
struct TestCase {
    stem: PathBuf,
    name: String,
    source: Vec<u8>,
    mode: Mode,
    args: Vec<OsString>,
    files: BTreeMap<String, Vec<u8>>,
    max_call_stack: u64,
    expected: Expected,
}

#[derive(Debug)]
struct Expected {
    exit_code: u8,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    diagnostics: Vec<String>,
    text_stderr: Option<Vec<u8>>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Actual {
    exit_code: u8,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    diagnostics: Vec<String>,
    text_stderr: String,
}

#[test]
fn golden_suite() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("testdata");
    let filter = std::env::var(FILTER_ENV).unwrap_or_default();
    let bless = std::env::var(BLESS_ENV).is_ok_and(|value| value == "1");
    let mut failures = Vec::new();
    let scripts = match discover_scripts(&root) {
        Ok(scripts) => scripts,
        Err(error) => {
            panic!(
                "could not discover golden scripts under {}: {error}",
                root.display()
            );
        }
    };
    let mut selected = 0usize;

    for script in scripts {
        let name = display_name(&root, &script);
        if !filter.is_empty() && !name.contains(&filter) {
            continue;
        }
        selected = selected.saturating_add(1);
        match load_case(script, name) {
            Ok(case) => run_case(case, bless, &mut failures),
            Err((name, error)) => failures.push(format!("{name}: invalid test data: {error}")),
        }
    }

    let benchmark_selected = run_benchmarks(&mut failures, &filter);
    if !filter.is_empty() && selected == 0 && benchmark_selected == 0 {
        failures.push(format!("{FILTER_ENV} matched no test: {filter}"));
    }
    if selected == 0 && benchmark_selected == 0 && filter.is_empty() {
        failures.push(String::from(
            "testdata and tools/bench/programs contain no selected scripts",
        ));
    }

    assert!(
        failures.is_empty(),
        "golden tests failed ({} failure(s)):\n{}",
        failures.len(),
        failures.join("\n")
    );
}

fn discover_scripts(root: &Path) -> io::Result<Vec<PathBuf>> {
    let mut pending = Vec::new();
    let mut scripts = Vec::new();
    for entry in sorted_entries(root)? {
        let file_type = entry.file_type()?;
        if file_type.is_dir() && !is_files_directory(&entry.path()) {
            pending.push(entry.path());
        } else if file_type.is_file()
            && entry
                .path()
                .extension()
                .is_some_and(|extension| extension == "bnt")
        {
            scripts.push(entry.path());
        }
    }
    while let Some(directory) = pending.pop() {
        for entry in sorted_entries(&directory)? {
            let file_type = entry.file_type()?;
            let path = entry.path();
            if file_type.is_dir() {
                if !is_files_directory(&path) {
                    pending.push(path);
                }
            } else if file_type.is_file()
                && path.extension().is_some_and(|extension| extension == "bnt")
            {
                scripts.push(path);
            }
        }
    }
    scripts.sort();
    Ok(scripts)
}

fn sorted_entries(directory: &Path) -> io::Result<Vec<fs::DirEntry>> {
    let mut entries = fs::read_dir(directory)?.collect::<Result<Vec<_>, _>>()?;
    entries.sort_by_key(fs::DirEntry::file_name);
    Ok(entries)
}

fn is_files_directory(path: &Path) -> bool {
    path.file_name()
        .and_then(|name| name.to_str())
        .is_some_and(|name| name.ends_with(".files"))
}

fn display_name(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .map(|relative| relative.to_string_lossy().replace('\\', "/"))
        .unwrap_or_else(|_| path.to_string_lossy().replace('\\', "/"))
}

fn load_case(script: PathBuf, name: String) -> Result<TestCase, (String, String)> {
    let mut stem = script.clone();
    stem.set_extension("");
    let source = fs::read(&script).map_err(|error| (name.clone(), error.to_string()))?;
    let mode_text =
        read_required_text(&sibling(&stem, "mode")).map_err(|error| (name.clone(), error))?;
    let mode_text = mode_text.trim();
    let Some(mode) = Mode::parse(mode_text) else {
        return Err((
            name,
            format!(".mode must be `check` or `run`, found {mode_text:?}"),
        ));
    };
    let exit_text =
        read_required_text(&sibling(&stem, "exit")).map_err(|error| (name.clone(), error))?;
    let exit_text = exit_text.trim();
    if exit_text.is_empty() || !exit_text.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err((
            name,
            format!(".exit must contain a decimal integer, found {exit_text:?}"),
        ));
    }
    let exit_code = exit_text
        .parse::<u8>()
        .map_err(|error| (name.clone(), format!("invalid .exit value: {error}")))?;

    let stdout = read_optional_bytes(&sibling(&stem, "stdout"))
        .map_err(|error| (name.clone(), error))?
        .unwrap_or_default();
    let stderr = read_optional_bytes(&sibling(&stem, "stderr"))
        .map_err(|error| (name.clone(), error))?
        .unwrap_or_default();
    let diagnostics = read_optional_lines(&sibling(&stem, "diag.json"))
        .map_err(|error| (name.clone(), error))?
        .unwrap_or_default();
    let text_stderr = read_optional_bytes(&sibling(&stem, "text.stderr"))
        .map_err(|error| (name.clone(), error))?;
    let args = read_optional_lines(&sibling(&stem, "args"))
        .map_err(|error| (name.clone(), error))?
        .unwrap_or_default()
        .into_iter()
        .map(OsString::from)
        .collect();
    let max_call_stack =
        read_options(&sibling(&stem, "opts")).map_err(|error| (name.clone(), error))?;
    let files = read_files(&sibling(&stem, "files")).map_err(|error| (name.clone(), error))?;

    Ok(TestCase {
        stem,
        name,
        source,
        mode,
        args,
        files,
        max_call_stack,
        expected: Expected {
            exit_code,
            stdout,
            stderr,
            diagnostics,
            text_stderr,
        },
    })
}

fn sibling(stem: &Path, extension: &str) -> PathBuf {
    stem.with_extension(extension)
}

fn read_required_text(path: &Path) -> Result<String, String> {
    fs::read_to_string(path).map_err(|error| format!("{}: {error}", path.display()))
}

fn read_optional_bytes(path: &Path) -> Result<Option<Vec<u8>>, String> {
    match fs::read(path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(format!("{}: {error}", path.display())),
    }
}

fn read_optional_lines(path: &Path) -> Result<Option<Vec<String>>, String> {
    let Some(bytes) = read_optional_bytes(path)? else {
        return Ok(None);
    };
    let text = String::from_utf8(bytes)
        .map_err(|error| format!("{} is not UTF-8: {error}", path.display()))?;
    let lines = text
        .split_terminator('\n')
        .map(|line| line.strip_suffix('\r').unwrap_or(line).to_owned())
        .collect();
    Ok(Some(lines))
}

fn read_options(path: &Path) -> Result<u64, String> {
    let Some(lines) = read_optional_lines(path)? else {
        return Ok(DEFAULT_MAX_CALL_STACK);
    };
    let mut max_call_stack = DEFAULT_MAX_CALL_STACK;
    let mut seen = false;
    for line in lines {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let Some((name, value)) = line.split_once('=') else {
            return Err(format!(
                "{}: expected name=value, found {line:?}",
                path.display()
            ));
        };
        if name != "max-call-stack" {
            return Err(format!("{}: unsupported option {name:?}", path.display()));
        }
        if seen {
            return Err(format!(
                "{}: max-call-stack may only be specified once",
                path.display()
            ));
        }
        seen = true;
        max_call_stack = benitoite::cli::parse_size(value)
            .ok_or_else(|| format!("{}: invalid max-call-stack value {value:?}", path.display()))?;
    }
    Ok(max_call_stack)
}

fn read_files(directory: &Path) -> Result<BTreeMap<String, Vec<u8>>, String> {
    if !directory.exists() {
        return Ok(BTreeMap::new());
    }
    let mut pending = vec![directory.to_path_buf()];
    let mut files = BTreeMap::new();
    while let Some(current) = pending.pop() {
        let entries =
            sorted_entries(&current).map_err(|error| format!("{}: {error}", current.display()))?;
        for entry in entries {
            let file_type = entry
                .file_type()
                .map_err(|error| format!("{}: {error}", entry.path().display()))?;
            let path = entry.path();
            if file_type.is_dir() {
                pending.push(path);
            } else if file_type.is_file() {
                let relative = path
                    .strip_prefix(directory)
                    .map_err(|error| format!("{}: {error}", path.display()))?;
                let key = relative.to_string_lossy().replace('\\', "/");
                let bytes =
                    fs::read(&path).map_err(|error| format!("{}: {error}", path.display()))?;
                files.insert(key, bytes);
            }
        }
    }
    Ok(files)
}

fn run_case(case: TestCase, bless: bool, failures: &mut Vec<String>) {
    let checked = pipeline::check_text(&case.name, &case.source);
    if checked
        .diagnostics
        .iter()
        .any(|diagnostic| diagnostic.kind == ReportKind::Internal)
    {
        failures.push(format!(
            "{}: pipeline check returned an internal error",
            case.name
        ));
        return;
    }

    if !checked.diagnostics.is_empty() {
        let actual = actual_for_check(&case, &checked, 2);
        finish_case(&case, &actual, bless, "check", failures);
        return;
    }

    let Some(checked_program) = checked.program.as_ref() else {
        failures.push(format!(
            "{}: check returned no program and no diagnostics",
            case.name
        ));
        return;
    };
    if case.mode == Mode::Check {
        let actual = actual_for_check(&case, &checked, 0);
        finish_case(&case, &actual, bless, "check", failures);
        return;
    }

    let core = match pipeline::desugar_checked(checked_program) {
        Ok(core) => core,
        Err(error) => {
            failures.push(format!(
                "{}: desugar returned an internal error in {}: {}",
                case.name, error.stage, error.message
            ));
            return;
        }
    };
    let core_errors = benitoite::ir::check::check_program(&core);
    if !core_errors.is_empty() {
        let detail = core_errors
            .iter()
            .map(|error| format!("{} at {:?}: {}", error.def, error.origin, error.message))
            .collect::<Vec<_>>()
            .join("; ");
        failures.push(format!("{}: core IR check failed: {detail}", case.name));
        return;
    }
    let compiled = match pipeline::compile(&core, std::sync::Arc::clone(&checked.sources)) {
        Ok(program) => program,
        Err(CompileError::Limit(diagnostics)) => {
            let actual = actual_for_reports(2, &diagnostics, &checked.sources);
            finish_case(&case, &actual, bless, "compile limit", failures);
            return;
        }
        Err(CompileError::Internal(error)) => {
            failures.push(format!(
                "{}: compile returned an internal error in {}: {}",
                case.name, error.stage, error.message
            ));
            return;
        }
    };

    let checked_args = match run::check_args(case.args.clone()) {
        Ok(args) => args,
        Err(report) => {
            let reports = vec![*report];
            let actual = actual_for_reports(1, &reports, &compiled.sources);
            finish_case(&case, &actual, bless, "argument check", failures);
            return;
        }
    };

    let mut direct_result = None;
    let mut request_result = None;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut io = TestIo::new(checked_args.clone(), case.files.clone());
        let end = run::run_with(
            &compiled,
            &mut io,
            ExecOptions {
                mode,
                max_call_stack_bytes: case.max_call_stack,
            },
        );
        let actual = actual_for_run(&end, &io, &compiled.sources);
        match mode {
            ExecMode::Direct => direct_result = Some((end, io, actual)),
            ExecMode::Request => request_result = Some(actual),
        }
    }

    let Some((direct_end, direct_io, direct_actual)) = direct_result else {
        failures.push(format!(
            "{}: direct IO execution was not recorded",
            case.name
        ));
        return;
    };
    let Some(request_actual) = request_result else {
        failures.push(format!(
            "{}: request IO execution was not recorded",
            case.name
        ));
        return;
    };

    if direct_actual != request_actual {
        failures.push(format!(
            "{}: IO modes differ; direct: {}; request: {}",
            case.name,
            describe_actual(&direct_actual),
            describe_actual(&request_actual)
        ));
    }

    check_differential(
        DifferentialInput {
            name: &case.name,
            core: &core,
            sources: &compiled.sources,
            args: &checked_args,
            files: &case.files,
        },
        &direct_end,
        &direct_io.events,
        failures,
    );

    if bless && direct_actual == request_actual {
        if let Err(error) = write_expected(&case, &direct_actual) {
            failures.push(format!(
                "{}: could not rewrite expected files: {error}",
                case.name
            ));
        }
    } else if !bless {
        compare_expected(&case, &direct_actual, "direct", failures);
        compare_expected(&case, &request_actual, "request", failures);
    }
}

fn actual_for_check(case: &TestCase, checked: &CheckResult, exit_code: u8) -> Actual {
    let text_stderr = render_check_text(
        &checked.diagnostics,
        &checked.sources,
        case.mode.as_str(),
        &case.name,
        TextOptions { color: false },
    );
    Actual {
        exit_code,
        stdout: Vec::new(),
        stderr: Vec::new(),
        diagnostics: json_lines(&checked.diagnostics, &checked.sources),
        text_stderr,
    }
}

fn actual_for_reports(exit_code: u8, reports: &[Diagnostic], sources: &SourceTable) -> Actual {
    Actual {
        exit_code,
        stdout: Vec::new(),
        stderr: Vec::new(),
        diagnostics: json_lines(reports, sources),
        text_stderr: reports
            .iter()
            .map(|diagnostic| render_one_text(diagnostic, sources, TextOptions { color: false }))
            .collect(),
    }
}

fn actual_for_run(end: &RunEnd, io: &TestIo, sources: &SourceTable) -> Actual {
    let mut stderr = io.stderr.as_bytes().to_vec();
    if let Some(message) = end.main_error.as_deref() {
        stderr.extend_from_slice(message.as_bytes());
        stderr.push(b'\n');
    }
    Actual {
        exit_code: end.exit_code,
        stdout: io.stdout.as_bytes().to_vec(),
        stderr,
        diagnostics: json_lines(&end.reports, sources),
        text_stderr: end
            .reports
            .iter()
            .map(|diagnostic| render_one_text(diagnostic, sources, TextOptions { color: false }))
            .collect(),
    }
}

fn json_lines(reports: &[Diagnostic], sources: &SourceTable) -> Vec<String> {
    reports
        .iter()
        .map(|diagnostic| render_json_line(diagnostic, sources))
        .collect()
}

fn finish_case(
    case: &TestCase,
    actual: &Actual,
    bless: bool,
    label: &str,
    failures: &mut Vec<String>,
) {
    if bless {
        if let Err(error) = write_expected(case, actual) {
            failures.push(format!(
                "{} ({label}): could not rewrite expected files: {error}",
                case.name
            ));
        }
    } else {
        compare_expected(case, actual, label, failures);
    }
}

fn compare_expected(case: &TestCase, actual: &Actual, label: &str, failures: &mut Vec<String>) {
    if actual.exit_code != case.expected.exit_code {
        failures.push(format!(
            "{} ({label}) .exit: expected {}, actual {}",
            case.name, case.expected.exit_code, actual.exit_code
        ));
    }
    if actual.stdout != case.expected.stdout {
        failures.push(format!(
            "{} ({label}) .stdout: expected {:?}, actual {:?}",
            case.name, case.expected.stdout, actual.stdout
        ));
    }
    if actual.stderr != case.expected.stderr {
        failures.push(format!(
            "{} ({label}) .stderr: expected {:?}, actual {:?}",
            case.name, case.expected.stderr, actual.stderr
        ));
    }
    if actual.diagnostics != case.expected.diagnostics {
        failures.push(format!(
            "{} ({label}) .diag.json:\nexpected:\n{}\nactual:\n{}",
            case.name,
            case.expected.diagnostics.join("\n"),
            actual.diagnostics.join("\n")
        ));
    }
    if let Some(expected) = case.expected.text_stderr.as_ref()
        && actual.text_stderr.as_bytes() != expected
    {
        failures.push(format!(
            "{} ({label}) .text.stderr: expected {:?}, actual {:?}",
            case.name,
            String::from_utf8_lossy(expected),
            actual.text_stderr
        ));
    }
}

fn write_expected(case: &TestCase, actual: &Actual) -> io::Result<()> {
    fs::write(
        sibling(&case.stem, "exit"),
        format!("{}\n", actual.exit_code),
    )?;
    write_optional_nonempty(&sibling(&case.stem, "stdout"), &actual.stdout)?;
    write_optional_nonempty(&sibling(&case.stem, "stderr"), &actual.stderr)?;
    let mut json = actual.diagnostics.join("\n").into_bytes();
    if !actual.diagnostics.is_empty() {
        json.push(b'\n');
    }
    write_optional_nonempty(&sibling(&case.stem, "diag.json"), &json)?;
    let text_path = sibling(&case.stem, "text.stderr");
    if case.expected.text_stderr.is_some() {
        fs::write(text_path, actual.text_stderr.as_bytes())?;
    }
    Ok(())
}

fn write_optional_nonempty(path: &Path, bytes: &[u8]) -> io::Result<()> {
    if bytes.is_empty() {
        match fs::remove_file(path) {
            Ok(()) => Ok(()),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
            Err(error) => Err(error),
        }
    } else {
        fs::write(path, bytes)
    }
}

fn describe_actual(actual: &Actual) -> String {
    format!(
        "exit={}, stdout={:?}, stderr={:?}, diagnostics={:?}",
        actual.exit_code, actual.stdout, actual.stderr, actual.diagnostics
    )
}

#[derive(Debug, PartialEq, Eq)]
enum DifferentialEnd {
    Unit,
    Ok,
    Err(String),
    Runtime(String),
    Resource,
    Internal,
    Invalid(String),
}

struct DifferentialInput<'a> {
    name: &'a str,
    core: &'a benitoite::ir::core_ir::CoreProgram,
    sources: &'a SourceTable,
    args: &'a [String],
    files: &'a BTreeMap<String, Vec<u8>>,
}

fn check_differential(
    input: DifferentialInput<'_>,
    vm_end: &RunEnd,
    vm_events: &[IoEvent],
    failures: &mut Vec<String>,
) {
    let mut reference_io = TestIo::new(input.args.to_vec(), input.files.clone());
    let reference_end = refinterp::run(input.core, &mut reference_io);
    let main_kind = main_kind_for_core(input.core);
    let vm_summary = summarize_vm(vm_end, main_kind);
    let (reference_summary, reference_origin) = summarize_reference(reference_end, main_kind);

    if vm_summary == DifferentialEnd::Resource || reference_summary == DifferentialEnd::Resource {
        return;
    }

    if vm_events != reference_io.events.as_slice() {
        failures.push(format!(
            "{}: differential IO events differ; VM: {vm_events:?}; reference: {:?}",
            input.name, reference_io.events
        ));
    }
    if vm_summary != reference_summary {
        failures.push(format!(
            "{}: differential end differs; VM: {vm_summary:?}; reference: {reference_summary:?}",
            input.name
        ));
    }
    if matches!(&vm_summary, DifferentialEnd::Runtime(_))
        && matches!(&reference_summary, DifferentialEnd::Runtime(_))
    {
        let vm_origin = vm_user_origin(vm_end, input.sources);
        let reference_origin = user_origin(reference_origin, input.sources);
        if let (Some(vm_origin), Some(reference_origin)) = (vm_origin, reference_origin)
            && vm_origin != reference_origin
        {
            failures.push(format!(
                "{}: differential runtime error positions differ; VM: {vm_origin:?}; reference: {reference_origin:?}",
                input.name
            ));
        }
    }
}

fn main_kind_for_core(core: &benitoite::ir::core_ir::CoreProgram) -> MainKind {
    if core.main_returns_result {
        MainKind::Result
    } else {
        MainKind::Unit
    }
}

fn summarize_vm(end: &RunEnd, main_kind: MainKind) -> DifferentialEnd {
    if let Some(error) = end.main_error.as_ref() {
        return DifferentialEnd::Err(error.clone());
    }
    if end.exit_code == 0 {
        return match main_kind {
            MainKind::Unit => DifferentialEnd::Unit,
            MainKind::Result => DifferentialEnd::Ok,
        };
    }
    let Some(report) = end.reports.first() else {
        return DifferentialEnd::Invalid(format!("exit {} without a report", end.exit_code));
    };
    match report.kind {
        ReportKind::Runtime => report
            .code
            .map(|code| DifferentialEnd::Runtime(String::from(code.info().id)))
            .unwrap_or_else(|| {
                DifferentialEnd::Invalid(String::from("runtime report has no code"))
            }),
        ReportKind::Resource => DifferentialEnd::Resource,
        ReportKind::Internal => DifferentialEnd::Internal,
        ReportKind::Check | ReportKind::Limit | ReportKind::Args => {
            DifferentialEnd::Invalid(format!("unexpected report kind {:?}", report.kind))
        }
    }
}

fn summarize_reference(
    outcome: RefOutcome,
    main_kind: MainKind,
) -> (DifferentialEnd, Option<Span>) {
    match outcome {
        RefOutcome::Returned(value) => {
            let end = match main_kind {
                MainKind::Unit => match &value {
                    benitoite::runtime::value::Value::Unit => DifferentialEnd::Unit,
                    benitoite::runtime::value::Value::Int(_)
                    | benitoite::runtime::value::Value::Float(_)
                    | benitoite::runtime::value::Value::Bool(_)
                    | benitoite::runtime::value::Value::Char(_)
                    | benitoite::runtime::value::Value::Str(_)
                    | benitoite::runtime::value::Value::Func(_)
                    | benitoite::runtime::value::Value::Ctor(_)
                    | benitoite::runtime::value::Value::List(_)
                    | benitoite::runtime::value::Value::IoError(_) => {
                        DifferentialEnd::Invalid(format!("main returned {value:?}, expected Unit"))
                    }
                },
                MainKind::Result => match value.as_ctor() {
                    // `Ok(())` は引数を一つ（`()`）持つ構成子である。
                    Some((0, [benitoite::runtime::value::Value::Unit])) => DifferentialEnd::Ok,
                    Some((1, [message])) => message
                        .as_str()
                        .map(|message| DifferentialEnd::Err(message.to_owned()))
                        .unwrap_or_else(|| {
                            DifferentialEnd::Invalid(String::from("Err payload is not String"))
                        }),
                    _ => DifferentialEnd::Invalid(format!(
                        "main returned {value:?}, expected Result[Unit, String]"
                    )),
                },
            };
            (end, None)
        }
        RefOutcome::Stopped { stop, origin } => {
            let end = match stop {
                Stop::Runtime(RuntimeError::DivisionByZero) => {
                    DifferentialEnd::Runtime(String::from("R0101"))
                }
                Stop::Runtime(RuntimeError::IntegerOverflow) => {
                    DifferentialEnd::Runtime(String::from("R0102"))
                }
                Stop::Runtime(RuntimeError::WriteFailed { stream, .. }) => {
                    let code = match stream {
                        benitoite::runtime::Stream::Stdout => "R0201",
                        benitoite::runtime::Stream::Stderr => "R0202",
                    };
                    DifferentialEnd::Runtime(String::from(code))
                }
                Stop::Resource(ResourceError::CallStackTooDeep { .. })
                | Stop::Resource(ResourceError::ValueTooLarge { .. }) => DifferentialEnd::Resource,
                Stop::Internal(_) => DifferentialEnd::Internal,
            };
            (end, origin)
        }
    }
}

fn vm_user_origin(end: &RunEnd, sources: &SourceTable) -> Option<Span> {
    end.reports
        .iter()
        .find(|report| report.kind == ReportKind::Runtime)
        .and_then(|report| report.primary.as_ref())
        .map(|label| label.span)
        .filter(|span| is_user_span(span, sources))
}

fn user_origin(origin: Option<Span>, sources: &SourceTable) -> Option<Span> {
    origin.filter(|span| is_user_span(span, sources))
}

fn is_user_span(span: &Span, sources: &SourceTable) -> bool {
    sources
        .get(span.file)
        .is_some_and(|source| source.kind() == SourceKind::User)
}

fn run_benchmarks(failures: &mut Vec<String>, filter: &str) -> usize {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tools/bench/programs");
    if !root.is_dir() {
        return 0;
    }
    let scripts = match discover_scripts(&root) {
        Ok(scripts) => scripts,
        Err(error) => {
            failures.push(format!(
                "could not discover benchmark scripts under {}: {error}",
                root.display()
            ));
            return 0;
        }
    };
    let mut selected = 0usize;
    for script in scripts {
        let mut args_path = script.clone();
        args_path.set_extension("args.small");
        if !args_path.is_file() {
            continue;
        }
        let name = format!("tools/bench/programs/{}", display_name(&root, &script));
        if !filter.is_empty() && !name.contains(filter) {
            continue;
        }
        selected = selected.saturating_add(1);
        run_benchmark(&script, &args_path, &name, failures);
    }
    selected
}

fn run_benchmark(script: &Path, args_path: &Path, name: &str, failures: &mut Vec<String>) {
    let source = match fs::read(script) {
        Ok(source) => source,
        Err(error) => {
            failures.push(format!("{name}: could not read script: {error}"));
            return;
        }
    };
    let args = match read_required_text(args_path) {
        Ok(text) => text
            .split_terminator('\n')
            .map(|line| OsString::from(line.strip_suffix('\r').unwrap_or(line)))
            .collect::<Vec<_>>(),
        Err(error) => {
            failures.push(format!("{name}: could not read arguments: {error}"));
            return;
        }
    };
    let checked = pipeline::check_text(name, &source);
    if !checked.diagnostics.is_empty() {
        failures.push(format!(
            "{name}: benchmark did not pass check: {:?}",
            checked.diagnostics
        ));
        return;
    }
    let Some(checked_program) = checked.program.as_ref() else {
        failures.push(format!(
            "{name}: check returned no program and no diagnostics"
        ));
        return;
    };
    let core = match pipeline::desugar_checked(checked_program) {
        Ok(core) => core,
        Err(error) => {
            failures.push(format!(
                "{name}: desugar failed: {}: {}",
                error.stage, error.message
            ));
            return;
        }
    };
    if !benitoite::ir::check::check_program(&core).is_empty() {
        failures.push(format!("{name}: core IR check failed"));
        return;
    }
    let compiled = match pipeline::compile(&core, std::sync::Arc::clone(&checked.sources)) {
        Ok(program) => program,
        Err(error) => {
            failures.push(format!("{name}: benchmark compilation failed: {error:?}"));
            return;
        }
    };
    let args = match run::check_args(args) {
        Ok(args) => args,
        Err(report) => {
            failures.push(format!("{name}: invalid benchmark argument: {report:?}"));
            return;
        }
    };
    let mut vm_io = TestIo::new(args.clone(), BTreeMap::new());
    let vm_end = run::run_with(
        &compiled,
        &mut vm_io,
        ExecOptions {
            mode: ExecMode::Direct,
            max_call_stack_bytes: DEFAULT_MAX_CALL_STACK,
        },
    );
    check_differential(
        DifferentialInput {
            name,
            core: &core,
            sources: &compiled.sources,
            args: &args,
            files: &BTreeMap::new(),
        },
        &vm_end,
        &vm_io.events,
        failures,
    );
}
