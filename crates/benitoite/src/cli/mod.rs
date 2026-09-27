//! CLI（設計書 06-01）。最小実行版のサブコマンドは `run` と `check`。

use std::ffi::OsString;
use std::io::{IsTerminal, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use std::sync::Arc;

use crate::base::SourceTable;
use crate::diag::codes::fill_template;
use crate::diag::render::TextOptions;
use crate::diag::{Diagnostic, ReportKind};
use crate::pipeline::{self, CheckResult, CompileError};
use crate::runtime::executor::{ExecMode, ExecOptions};
use crate::runtime::heap::AllocStats;
use crate::runtime::panic::{self, PanicReport};
use crate::runtime::real_io::RealIo;
use crate::runtime::report::internal_diagnostic;
use crate::runtime::run::{check_args, run_with};
use crate::vm::DEFAULT_MAX_CALL_STACK;

/// 診断の形式（`--diagnostics`）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DiagFormat {
    Text,
    Json,
}

/// `run` と `check` の選択肢。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Options {
    pub diagnostics: DiagFormat,
    /// `--max-call-stack` の値（バイト）
    pub max_call_stack: u64,
}

/// 解釈したコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Command {
    Run {
        options: Options,
        script: PathBuf,
        args: Vec<OsString>,
    },
    Check {
        options: Options,
        script: PathBuf,
    },
    Help,
    Version,
}

/// 使い方の誤りの文と、`--help` の文（ADR 0033 に従い英語で書き、ここにまとめる）。
pub mod text {
    pub const USAGE: &str = "\
Usage:
  benitoite run   [options] <script> [script arguments...]
  benitoite check [options] <script>
  benitoite --help
  benitoite --version

Options:
  --diagnostics=text|json   format of diagnostics and error reports (default: text)
  --max-call-stack=<size>   limit for nested calls, such as 512MiB or 2GiB (default: 1GiB)
";
    /// 使い方の誤りの 1 行目。`{detail}` を置き換える
    pub const USAGE_ERROR: &str = "error: {detail}";
    pub const SEE_HELP: &str = "run `benitoite --help` for usage";
    pub const MISSING_COMMAND: &str = "missing subcommand";
    pub const UNKNOWN_COMMAND: &str = "unknown subcommand `{name}`";
    pub const UNKNOWN_OPTION: &str = "unknown option `{name}`";
    pub const BAD_VALUE: &str = "invalid value `{value}` for `{name}`";
    pub const DUPLICATE_OPTION: &str = "option `{name}` may only be specified once";
    pub const MISSING_SCRIPT: &str = "missing script path";
    pub const EXTRA_ARGUMENT: &str = "unexpected argument `{value}`";
    pub const ALLOC_STATS: &str =
        "alloc-stats allocations={allocations} bytes={bytes} freed={freed}";
}

/// `benitoite` の後のコマンドライン引数を解釈する（06-01「コマンドラインの形」「オプション」）。
/// 使い方の誤りは、`text` の型板から作った 1 行の説明を返す。
pub fn parse_args(args: Vec<OsString>) -> Result<Command, String> {
    let mut args = args.into_iter();
    let Some(first) = args.next() else {
        return Err(String::from(text::MISSING_COMMAND));
    };
    let Some(command) = first.to_str() else {
        return Err(fill_template(
            text::UNKNOWN_COMMAND,
            &[("name", first.to_string_lossy().into_owned())],
        ));
    };

    match command {
        "--help" => {
            if let Some(extra) = args.next() {
                Err(extra_argument(&extra))
            } else {
                Ok(Command::Help)
            }
        }
        "--version" => {
            if let Some(extra) = args.next() {
                Err(extra_argument(&extra))
            } else {
                Ok(Command::Version)
            }
        }
        "run" => parse_script_command(args, true),
        "check" => parse_script_command(args, false),
        name => Err(fill_template(
            text::UNKNOWN_COMMAND,
            &[("name", String::from(name))],
        )),
    }
}

fn parse_script_command(
    args: impl Iterator<Item = OsString>,
    run: bool,
) -> Result<Command, String> {
    let mut args = args.peekable();
    let mut options = Options {
        diagnostics: DiagFormat::Text,
        max_call_stack: DEFAULT_MAX_CALL_STACK,
    };
    let mut seen_diagnostics = false;
    let mut seen_max_call_stack = false;
    let mut script = None;
    let mut script_args = Vec::new();

    while let Some(argument) = args.next() {
        if looks_like_option(&argument) {
            let Some(option) = argument.to_str() else {
                return Err(unknown_option(&argument));
            };
            if let Some(value) = option.strip_prefix("--diagnostics=") {
                if seen_diagnostics {
                    return Err(duplicate_option("--diagnostics"));
                }
                seen_diagnostics = true;
                options.diagnostics = match value {
                    "text" => DiagFormat::Text,
                    "json" => DiagFormat::Json,
                    _ => {
                        return Err(bad_value("--diagnostics", value));
                    }
                };
            } else if let Some(value) = option.strip_prefix("--max-call-stack=") {
                if seen_max_call_stack {
                    return Err(duplicate_option("--max-call-stack"));
                }
                seen_max_call_stack = true;
                let Some(bytes) = parse_size(value) else {
                    return Err(bad_value("--max-call-stack", value));
                };
                options.max_call_stack = bytes;
            } else {
                return Err(unknown_option(&argument));
            }
        } else {
            script = Some(PathBuf::from(argument));
            if run {
                script_args.extend(args);
            } else if let Some(extra) = args.next() {
                return Err(extra_argument(&extra));
            }
            break;
        }
    }

    let Some(script) = script else {
        return Err(String::from(text::MISSING_SCRIPT));
    };
    if run {
        Ok(Command::Run {
            options,
            script,
            args: script_args,
        })
    } else {
        Ok(Command::Check { options, script })
    }
}

fn looks_like_option(argument: &OsString) -> bool {
    argument.to_string_lossy().starts_with('-')
}

fn unknown_option(argument: &OsString) -> String {
    fill_template(
        text::UNKNOWN_OPTION,
        &[("name", argument.to_string_lossy().into_owned())],
    )
}

fn extra_argument(argument: &OsString) -> String {
    fill_template(
        text::EXTRA_ARGUMENT,
        &[("value", argument.to_string_lossy().into_owned())],
    )
}

fn bad_value(name: &str, value: &str) -> String {
    fill_template(
        text::BAD_VALUE,
        &[("name", String::from(name)), ("value", String::from(value))],
    )
}

fn duplicate_option(name: &str) -> String {
    fill_template(text::DUPLICATE_OPTION, &[("name", String::from(name))])
}

/// `--max-call-stack` の値（`512MiB` など）をバイト数にする。
pub fn parse_size(value: &str) -> Option<u64> {
    let (digits, multiplier) = if let Some(digits) = value.strip_suffix("KiB") {
        (digits, 1024_u64)
    } else if let Some(digits) = value.strip_suffix("MiB") {
        (digits, 1024_u64 * 1024)
    } else {
        let digits = value.strip_suffix("GiB")?;
        (digits, 1024_u64 * 1024 * 1024)
    };
    if digits.is_empty() || !digits.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    let number = digits.parse::<u64>().ok()?;
    if number == 0 {
        return None;
    }
    number.checked_mul(multiplier)
}

/// CLI の入口。panic hook を設定してから、コマンドを実行して終了状態を返す（06-01「終了状態」）。
pub fn main() -> ExitCode {
    panic::install_hook();
    let command = match parse_args(std::env::args_os().skip(1).collect()) {
        Ok(command) => command,
        Err(detail) => return usage_failure(&detail),
    };
    match command {
        Command::Help => {
            write_stdout(text::USAGE);
            ExitCode::SUCCESS
        }
        Command::Version => {
            write_stdout(&format!("benitoite {}\n", env!("CARGO_PKG_VERSION")));
            ExitCode::SUCCESS
        }
        Command::Run {
            options,
            script,
            args,
        } => {
            let mode = match io_mode() {
                Ok(mode) => mode,
                Err(detail) => return usage_failure(&detail),
            };
            run_command(options, script, args, mode)
        }
        Command::Check { options, script } => {
            let mode = match io_mode() {
                Ok(mode) => mode,
                Err(detail) => return usage_failure(&detail),
            };
            check_command(options, script, mode)
        }
    }
}

fn io_mode() -> Result<ExecMode, String> {
    match std::env::var_os("BENITOITE_DEV_IO_MODE") {
        None => Ok(ExecMode::Direct),
        Some(value) => match value.to_str() {
            Some("direct") => Ok(ExecMode::Direct),
            Some("request") => Ok(ExecMode::Request),
            Some(value) => Err(bad_value("BENITOITE_DEV_IO_MODE", value)),
            None => Err(bad_value("BENITOITE_DEV_IO_MODE", "<non-UTF-8>")),
        },
    }
}

fn check_command(options: Options, script: PathBuf, _mode: ExecMode) -> ExitCode {
    let checked = match panic::catch(|| check_for_cli(&script)) {
        Ok(result) => result,
        Err(report) => {
            write_internal(
                "check",
                "",
                Some(&report),
                &SourceTable::new(),
                options.diagnostics,
            );
            return ExitCode::from(3);
        }
    };
    if let Some(report) = checked
        .diagnostics
        .iter()
        .find(|diagnostic| diagnostic.kind == ReportKind::Internal)
    {
        write_one(report, &checked.sources, options.diagnostics);
        return ExitCode::from(3);
    }
    if !checked.diagnostics.is_empty() {
        write_check_diagnostics(&checked, &options, "check", &script.display().to_string());
        return ExitCode::from(2);
    }
    ExitCode::SUCCESS
}

#[allow(clippy::panic)] // 開発用の検査段の不具合報告をテストするため、意図して panic を起こす（10-09）。
fn check_for_cli(script: &std::path::Path) -> CheckResult {
    let result = pipeline::check_path(script);
    if cfg!(debug_assertions)
        && result.program.is_some()
        && std::env::var("BENITOITE_DEV_PANIC").is_ok_and(|value| value == "check")
    {
        panic!("BENITOITE_DEV_PANIC=check: panic after type checking");
    }
    result
}

fn run_command(options: Options, script: PathBuf, args: Vec<OsString>, mode: ExecMode) -> ExitCode {
    let checked = match panic::catch(|| check_for_cli(&script)) {
        Ok(result) => result,
        Err(report) => {
            write_internal(
                "check",
                "",
                Some(&report),
                &SourceTable::new(),
                options.diagnostics,
            );
            return ExitCode::from(3);
        }
    };
    if let Some(report) = checked
        .diagnostics
        .iter()
        .find(|diagnostic| diagnostic.kind == ReportKind::Internal)
    {
        write_one(report, &checked.sources, options.diagnostics);
        return ExitCode::from(3);
    }
    if !checked.diagnostics.is_empty() {
        write_check_diagnostics(&checked, &options, "run", &script.display().to_string());
        return ExitCode::from(2);
    }
    let Some(program) = checked.program.as_ref() else {
        let report = internal_diagnostic(
            "check",
            "pipeline returned no checked program and no diagnostics",
            None,
        );
        write_one(&report, &checked.sources, options.diagnostics);
        return ExitCode::from(3);
    };

    let core = match panic::catch(|| pipeline::desugar_checked(program)) {
        Ok(Ok(core)) => core,
        Ok(Err(error)) => {
            write_internal(
                error.stage,
                &error.message,
                None,
                &checked.sources,
                options.diagnostics,
            );
            return ExitCode::from(3);
        }
        Err(report) => {
            write_internal(
                "desugar",
                "",
                Some(&report),
                &checked.sources,
                options.diagnostics,
            );
            return ExitCode::from(3);
        }
    };

    let compiled = match panic::catch(|| pipeline::compile(&core, Arc::clone(&checked.sources))) {
        Ok(Ok(program)) => program,
        Ok(Err(CompileError::Limit(diagnostics))) => {
            write_reports(&diagnostics, &checked.sources, options.diagnostics);
            return ExitCode::from(2);
        }
        Ok(Err(CompileError::Internal(error))) => {
            write_internal(
                error.stage,
                &error.message,
                None,
                &checked.sources,
                options.diagnostics,
            );
            return ExitCode::from(3);
        }
        Err(report) => {
            write_internal(
                "compile",
                "",
                Some(&report),
                &checked.sources,
                options.diagnostics,
            );
            return ExitCode::from(3);
        }
    };

    let args = match check_args(args) {
        Ok(args) => args,
        Err(report) => {
            write_one(&report, &compiled.sources, options.diagnostics);
            return ExitCode::from(1);
        }
    };
    let mut io = RealIo::new(args);
    let result = run_with(
        &compiled,
        &mut io,
        ExecOptions {
            mode,
            max_call_stack_bytes: options.max_call_stack,
        },
    );
    if let Some(message) = result.main_error.as_deref() {
        write_stderr(&format!("{message}\n"));
    }
    write_reports(&result.reports, &compiled.sources, options.diagnostics);
    write_alloc_stats(result.alloc);
    ExitCode::from(result.exit_code)
}

fn write_check_diagnostics(checked: &CheckResult, options: &Options, verb: &str, file: &str) {
    match options.diagnostics {
        DiagFormat::Text => {
            let output = crate::diag::render::render_check_text(
                &checked.diagnostics,
                &checked.sources,
                verb,
                file,
                text_options(),
            );
            write_stderr(&output);
        }
        DiagFormat::Json => {
            write_reports(&checked.diagnostics, &checked.sources, options.diagnostics)
        }
    }
}

fn write_one(diagnostic: &Diagnostic, sources: &SourceTable, format: DiagFormat) {
    match format {
        DiagFormat::Text => {
            let output = crate::diag::render::render_one_text(diagnostic, sources, text_options());
            write_stderr(&output);
        }
        DiagFormat::Json => {
            let output = format!(
                "{}\n",
                crate::diag::render::render_json_line(diagnostic, sources)
            );
            write_stderr(&output);
        }
    }
}

fn write_reports(diagnostics: &[Diagnostic], sources: &SourceTable, format: DiagFormat) {
    for diagnostic in diagnostics {
        write_one(diagnostic, sources, format);
    }
}

fn write_internal(
    stage: &str,
    message: &str,
    panic_report: Option<&PanicReport>,
    sources: &SourceTable,
    format: DiagFormat,
) {
    let diagnostic = internal_diagnostic(stage, message, panic_report);
    write_one(&diagnostic, sources, format);
}

fn text_options() -> TextOptions {
    TextOptions {
        color: std::io::stderr().is_terminal() && std::env::var_os("NO_COLOR").is_none(),
    }
}

fn usage_failure(detail: &str) -> ExitCode {
    let first_line = fill_template(text::USAGE_ERROR, &[("detail", String::from(detail))]);
    write_stderr(&format!("{first_line}\n{}\n", text::SEE_HELP));
    ExitCode::from(2)
}

fn write_stdout(value: &str) {
    drop(std::io::stdout().write_all(value.as_bytes()));
}

fn write_stderr(value: &str) {
    drop(std::io::stderr().write_all(value.as_bytes()));
}

#[cfg(feature = "alloc-stats")]
fn write_alloc_stats(stats: AllocStats) {
    if std::env::var("BENITOITE_DEV_ALLOC_STATS").is_ok_and(|value| value == "1") {
        let line = fill_template(
            text::ALLOC_STATS,
            &[
                ("allocations", stats.allocations.to_string()),
                ("bytes", stats.bytes.to_string()),
                ("freed", crate::runtime::heap::freed_count().to_string()),
            ],
        );
        write_stderr(&format!("{line}\n"));
    }
}

#[cfg(not(feature = "alloc-stats"))]
fn write_alloc_stats(_stats: AllocStats) {}

#[cfg(test)]
// テストの失敗は panic で表す（07-03）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::{Command, DiagFormat, Options, parse_args, parse_size, text};
    use std::ffi::OsString;
    use std::path::PathBuf;

    fn args(values: &[&str]) -> Vec<OsString> {
        values.iter().map(OsString::from).collect()
    }

    fn default_options() -> Options {
        Options {
            diagnostics: DiagFormat::Text,
            max_call_stack: 1_073_741_824,
        }
    }

    #[test]
    fn parses_commands_and_preserves_run_arguments() {
        assert_eq!(
            parse_args(args(&["run", "a.bnt", "-x", "y"])),
            Ok(Command::Run {
                options: default_options(),
                script: PathBuf::from("a.bnt"),
                args: args(&["-x", "y"]),
            })
        );
        assert_eq!(
            parse_args(args(&["check", "--diagnostics=json", "a.bnt"])),
            Ok(Command::Check {
                options: Options {
                    diagnostics: DiagFormat::Json,
                    ..default_options()
                },
                script: PathBuf::from("a.bnt"),
            })
        );
        assert_eq!(
            parse_args(args(&["run", "--max-call-stack=512MiB", "a.bnt"])),
            Ok(Command::Run {
                options: Options {
                    max_call_stack: 536_870_912,
                    ..default_options()
                },
                script: PathBuf::from("a.bnt"),
                args: Vec::new(),
            })
        );
        assert_eq!(parse_args(args(&["--help"])), Ok(Command::Help));
        assert_eq!(parse_args(args(&["--version"])), Ok(Command::Version));
    }

    #[test]
    fn rejects_usage_errors() {
        let cases = [
            (args(&[]), text::MISSING_COMMAND),
            (args(&["build", "a.bnt"]), "unknown subcommand `build`"),
            (args(&["run"]), text::MISSING_SCRIPT),
            (
                args(&["run", "--color", "a.bnt"]),
                "unknown option `--color`",
            ),
            (
                args(&["run", "--diagnostics=xml", "a.bnt"]),
                "invalid value `xml` for `--diagnostics`",
            ),
            (
                args(&["check", "a.bnt", "b.bnt"]),
                "unexpected argument `b.bnt`",
            ),
            (
                args(&["run", "--diagnostics=json", "--diagnostics=text", "a.bnt"]),
                "option `--diagnostics` may only be specified once",
            ),
        ];
        for (arguments, expected) in cases {
            assert_eq!(parse_args(arguments), Err(String::from(expected)));
        }
    }

    #[test]
    fn parses_size_suffixes_and_rejects_invalid_values() {
        let cases = [
            ("1KiB", Some(1024)),
            ("2GiB", Some(2_147_483_648)),
            ("10", None),
            ("0MiB", None),
            ("1TiB", None),
            ("-1KiB", None),
            ("99999999999999999999GiB", None),
        ];
        for (value, expected) in cases {
            assert_eq!(parse_size(value), expected, "{value}");
        }
    }
}
