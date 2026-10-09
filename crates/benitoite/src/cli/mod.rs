//! CLI（設計書 06-01）。初回リリース版のサブコマンドは `run`・`check`・`test`・`fmt`・`skill`。
//! `test`・`fmt`・`skill` と `--licenses` の中身は U4 が `tools` に書く。

pub mod tools;

use std::ffi::OsString;
use std::path::PathBuf;

use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::InterruptSource;
use crate::runtime::run::{OutputTarget, StdinSource};
use crate::runtime::sched::parts::RuntimeParts;
use crate::vm::{DEFAULT_MAX_CALL_STACK, ExecMode};

/// 診断の形式（`--diagnostics`）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DiagFormat {
    Text,
    Json,
}

/// `run` と `check` の選択肢（06-01「オプション」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Options {
    pub diagnostics: DiagFormat,
    /// `--max-call-stack` の値（バイト）
    pub max_call_stack: u64,
    /// `--deny-warnings`
    pub deny_warnings: bool,
}

impl Default for Options {
    fn default() -> Options {
        Options {
            diagnostics: DiagFormat::Text,
            max_call_stack: DEFAULT_MAX_CALL_STACK,
            deny_warnings: false,
        }
    }
}

/// U4 が中身を書くサブコマンド。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ToolCommand {
    Test,
    Fmt,
    Skill,
}

/// 解釈したコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Command {
    /// `run`、`run` を省いた実行、シェバンによる実行
    Run {
        options: Options,
        script: PathBuf,
        args: Vec<OsString>,
    },
    Check {
        options: Options,
        script: PathBuf,
    },
    /// `test`・`fmt`・`skill`。名前の前のオプションと名前の後の引数を、解釈せずに渡す（`tools::run_tool` が解釈する）
    Tool {
        tool: ToolCommand,
        args: Vec<OsString>,
    },
    Help,
    Version,
    Licenses,
}

/// 予約したサブコマンドの名前（06-01「予約したサブコマンドの名前」、ADR 0209）。
pub const RESERVED_COMMANDS: &[&str] = &[
    "server", "mcp", "sign", "verify", "repl", "lsp", "package", "agent",
];

/// 開発用の panic の指定（`BENITOITE_DEV_PANIC`。デバッグのビルドでだけ読む）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DevPanic {
    None,
    /// 型検査の後、脱糖の前に panic を起こす
    Check,
    /// 最初の書き込みを出力のバッファに加えた直後に panic を起こす（`RunEnv::dev_panic_after_first_write`）
    Run,
}

/// CLI の一回の実行の環境。`main` はプロセスの標準入出力で作り、ゴールデンテストの実行器（C10）は
/// メモリに捕らえる出力先で作る。
#[derive(Debug)]
pub struct CliEnv {
    /// `--help`・`--version`・`--licenses` の出力と、スクリプトの標準出力
    pub stdout: OutputTarget,
    /// 診断と報告と、スクリプトの標準エラー出力
    pub stderr: OutputTarget,
    pub stdin: StdinSource,
    /// 基準のディレクトリ（`main` は処理系を起動したときの作業ディレクトリ）
    pub working_directory: PathBuf,
    /// 文章の形式に色を付けるか（標準エラー出力が端末で、`NO_COLOR` がないとき。02-10「文章の形式」）
    pub color: bool,
    /// `BENITOITE_DEV_IO_MODE`（06-01「開発用の設定」）
    pub mode: ExecMode,
    /// 中断の要求の読み口。`None` なら、`run` の実行の前に `runtime::run::process_interrupt` で作る
    pub interrupt: Option<Box<dyn InterruptSource>>,
    /// テストで差し替える部品（ADR 0274）。`main` は `None`
    pub parts: Option<RuntimeParts>,
    pub heap: HeapConfig,
    pub dev_panic: DevPanic,
    /// `run` の終わりに確保の統計を標準エラー出力に一行で書く（機能 `alloc-stats` のビルドの `BENITOITE_DEV_ALLOC_STATS=1`）
    pub dev_alloc_stats: bool,
}

/// 使い方の誤りの文と、`--help`・`--version` の文（ADR 0033 に従い英語で書き、ここにまとめる）。
pub mod text {
    pub const USAGE: &str = "\
Usage:
  benitoite [options] <script> [script arguments...]
  benitoite run   [options] <script> [script arguments...]
  benitoite check [options] <script>
  benitoite test  [options] <path>...
  benitoite fmt   [options] <path>...
  benitoite skill install|uninstall [--user | --project] [--agent <name>]...
  benitoite --help
  benitoite --version
  benitoite --licenses

<script> is a .bnt file, or a directory that contains main.bnt.

Options:
  --diagnostics=text|json   format of diagnostics and error reports (default: text)
  --max-call-stack=<size>   limit for nested calls, such as 512MiB or 2GiB (default: 1GiB)
  --deny-warnings           treat warnings as errors
  --check                   (fmt) report files that would change without rewriting them
";
    /// `--version` の出力。`{version}` は処理系の版、`{unicode}` は文字の分類と変換が従う Unicode の版
    /// （Rust の `char::UNICODE_VERSION`。03-06「Character」、ADR 0169）
    pub const VERSION: &str = "benitoite {version}\nUnicode {unicode}\n";
    /// 使い方の誤りの 1 行目。`{detail}` を置き換える
    pub const USAGE_ERROR: &str = "error: {detail}";
    pub const SEE_HELP: &str = "run `benitoite --help` for usage";
    pub const MISSING_COMMAND: &str = "missing subcommand or script path";
    pub const RESERVED_COMMAND: &str =
        "`{name}` is reserved for a later version; to run a file with this name, write `./{name}`";
    pub const UNKNOWN_OPTION: &str = "unknown option `{name}`";
    pub const BAD_VALUE: &str = "invalid value `{value}` for `{name}`";
    pub const DUPLICATE_OPTION: &str = "option `{name}` may only be specified once";
    pub const MISSING_SCRIPT: &str = "missing script path";
    pub const EXTRA_ARGUMENT: &str = "unexpected argument `{value}`";
    pub const NO_MAIN_FILE: &str = "directory `{dir}` has no `main.bnt`";
    /// `BENITOITE_DEV_ALLOC_STATS` の行
    pub const ALLOC_STATS: &str = "alloc-stats: allocations={allocations} allocated_bytes={allocated_bytes} peak_heap_bytes={peak_heap_bytes} collections={collections}";
}

use std::process::ExitCode;

/// `benitoite` の後のコマンドライン引数を解釈する（本章「コマンドライン」）。
/// 使い方の誤りは、`text` の型板から作った 1 行の説明（`USAGE_ERROR` の `{detail}` の部分）を返す。
pub fn parse_args(args: Vec<OsString>) -> Result<Command, String> {
    if let Some(first) = args.first().and_then(|a| a.to_str()) {
        match first {
            "--help" => return Ok(Command::Help),
            "--version" => return Ok(Command::Version),
            "--licenses" => return Ok(Command::Licenses),
            _ => {}
        }
    }
    let command_index = args
        .iter()
        .position(|a| !a.to_string_lossy().starts_with('-'));
    if let Some(index) = command_index {
        let name = args.get(index).and_then(|a| a.to_str()).unwrap_or("");
        let tool = match name {
            "test" => Some(ToolCommand::Test),
            "fmt" => Some(ToolCommand::Fmt),
            "skill" => Some(ToolCommand::Skill),
            _ => None,
        };
        if let Some(tool) = tool {
            return Ok(Command::Tool {
                tool,
                args: args
                    .into_iter()
                    .enumerate()
                    .filter_map(|(i, a)| (i != index).then_some(a))
                    .collect(),
            });
        }
        if RESERVED_COMMANDS.contains(&name) {
            return Err(text::RESERVED_COMMAND.replace("{name}", name));
        }
    }
    let explicit =
        command_index.and_then(|i| args.get(i).and_then(|a| a.to_str()).map(|name| (i, name)));
    let (skip, checking) = match explicit {
        Some((index, "run")) => (Some(index), false),
        Some((index, "check")) => (Some(index), true),
        _ => (None, false),
    };
    let mut options = Options::default();
    let mut seen = std::collections::BTreeSet::new();
    let mut script = None;
    let mut script_args = Vec::new();
    for (index, arg) in args.into_iter().enumerate() {
        if Some(index) == skip {
            continue;
        }
        if script.is_some() {
            if checking {
                return Err(text::EXTRA_ARGUMENT.replace("{value}", &arg.to_string_lossy()));
            }
            script_args.push(arg);
        } else if arg.to_string_lossy().starts_with('-') {
            let value = arg.to_string_lossy();
            let (name, setting) = value
                .split_once('=')
                .map_or((&*value, None), |(n, v)| (n, Some(v)));
            if !matches!(
                name,
                "--diagnostics" | "--max-call-stack" | "--deny-warnings"
            ) {
                return Err(text::UNKNOWN_OPTION.replace("{name}", &value));
            }
            if !seen.insert(name.to_owned()) {
                return Err(text::DUPLICATE_OPTION.replace("{name}", name));
            }
            match (name, setting) {
                ("--diagnostics", Some("text")) => options.diagnostics = DiagFormat::Text,
                ("--diagnostics", Some("json")) => options.diagnostics = DiagFormat::Json,
                ("--max-call-stack", Some(size)) if parse_size(size).is_some() => {
                    options.max_call_stack = parse_size(size).unwrap_or(DEFAULT_MAX_CALL_STACK);
                }
                ("--deny-warnings", None) => options.deny_warnings = true,
                _ => {
                    return Err(text::BAD_VALUE
                        .replace("{name}", name)
                        .replace("{value}", setting.unwrap_or("")));
                }
            }
        } else {
            script = Some(PathBuf::from(arg));
        }
    }
    let script = script.ok_or_else(|| {
        if skip.is_some() || !seen.is_empty() {
            text::MISSING_SCRIPT.to_owned()
        } else {
            text::MISSING_COMMAND.to_owned()
        }
    })?;
    Ok(if checking {
        Command::Check { options, script }
    } else {
        Command::Run {
            options,
            script,
            args: script_args,
        }
    })
}

/// `--max-call-stack` の値（`512MiB` など）をバイト数にする。
pub fn parse_size(value: &str) -> Option<u64> {
    let (digits, factor) = if let Some(digits) = value.strip_suffix("KiB") {
        (digits, 1024_u64)
    } else if let Some(digits) = value.strip_suffix("MiB") {
        (digits, 1024_u64.pow(2))
    } else {
        (value.strip_suffix("GiB")?, 1024_u64.pow(3))
    };
    if digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    digits
        .parse::<u64>()
        .ok()
        .filter(|n| *n > 0)?
        .checked_mul(factor)
}

/// 解釈したコマンドを実行し、終了状態を返す（本章「コマンドの実行」）。出力は `env` の出力先に書く。
/// panic hook は設定しない（呼び出し側が設定する）。
pub fn execute(command: Command, env: CliEnv) -> u8 {
    match command {
        Command::Help => write_plain(&env.stdout, text::USAGE),
        Command::Version => {
            let (major, minor, update) = char::UNICODE_VERSION;
            write_plain(
                &env.stdout,
                &text::VERSION
                    .replace("{version}", env!("CARGO_PKG_VERSION"))
                    .replace("{unicode}", &format!("{major}.{minor}.{update}")),
            )
        }
        Command::Licenses => tools::print_licenses(&env),
        Command::Tool { tool, args } => tools::run_tool(tool, args, env),
        Command::Run {
            options,
            script,
            args,
        } => execute_script(options, script, Some(args), env),
        Command::Check { options, script } => execute_script(options, script, None, env),
    }
}

/// CLI の入口。panic hook を設定し（`runtime::panic::install_hook`）、コマンドラインを解釈し、
/// 環境変数（`BENITOITE_DEV_IO_MODE`、デバッグのビルドの `BENITOITE_DEV_PANIC`、機能 `alloc-stats` のビルドの
/// `BENITOITE_DEV_ALLOC_STATS`、`NO_COLOR`）を読んでプロセスの標準入出力の `CliEnv` を作り、`execute` を呼ぶ。
/// 使い方の誤りは、`USAGE_ERROR` と `SEE_HELP` の 2 行を標準エラー出力に書き、終了状態 2 で終える。
pub fn main() -> ExitCode {
    crate::runtime::panic::install_hook();
    let mut env = CliEnv {
        stdout: OutputTarget::Stdout,
        stderr: OutputTarget::Stderr,
        stdin: StdinSource::Process,
        working_directory: PathBuf::new(),
        color: false,
        mode: ExecMode::Direct,
        interrupt: None,
        parts: None,
        heap: HeapConfig::default(),
        dev_panic: DevPanic::None,
        dev_alloc_stats: false,
    };
    env.color = env.stderr.is_terminal() && std::env::var_os("NO_COLOR").is_none();
    env.working_directory = match std::env::current_dir() {
        Ok(path) => path,
        Err(error) => {
            return ExitCode::from(write_internal(
                &env,
                DiagFormat::Text,
                &SourceTable::new(),
                "run",
                &error.to_string(),
                None,
            ));
        }
    };
    if let Err(detail) = read_development_environment(&mut env) {
        return ExitCode::from(usage_error(&env, &detail));
    }
    ExitCode::from(invoke(std::env::args_os().skip(1).collect(), env))
}

use crate::base::{SourceKind, SourceTable};
use crate::diag::render::{self, TextOptions, Verb};
use crate::diag::{Diagnostic, ReportKind};
use crate::pipeline::{self, CheckOptions, CheckResult, CompileError, EntryError};
use crate::runtime::report::FaultThread;
use crate::runtime::run::{EXIT_CHECK, EXIT_FAILURE, EXIT_INTERNAL, EXIT_OK};
use crate::runtime::{panic as panic_boundary, report, run};

fn invoke(args: Vec<OsString>, env: CliEnv) -> u8 {
    match parse_args(args) {
        Ok(command) => execute(command, env),
        Err(detail) => usage_error(&env, &detail),
    }
}
fn write_plain(target: &OutputTarget, message: &str) -> u8 {
    if target.write_bytes(message.as_bytes()).is_ok() {
        EXIT_OK
    } else {
        EXIT_FAILURE
    }
}
fn usage_error(env: &CliEnv, detail: &str) -> u8 {
    let message = format!(
        "{}\n{}\n",
        text::USAGE_ERROR.replace("{detail}", detail),
        text::SEE_HELP
    );
    let _result = env.stderr.write_bytes(message.as_bytes());
    EXIT_CHECK
}
fn write_report(env: &CliEnv, format: DiagFormat, sources: &SourceTable, diagnostic: &Diagnostic) {
    let message = match format {
        DiagFormat::Text => {
            render::render_one_text(diagnostic, sources, TextOptions { color: env.color })
        }
        DiagFormat::Json => format!("{}\n", render::render_json_line(diagnostic, sources)),
    };
    let _result = env.stderr.write_bytes(message.as_bytes());
}
fn write_internal(
    env: &CliEnv,
    format: DiagFormat,
    sources: &SourceTable,
    stage: &str,
    message: &str,
    panic: Option<&panic_boundary::PanicReport>,
) -> u8 {
    write_report(
        env,
        format,
        sources,
        &report::internal_diagnostic(stage, message, panic, FaultThread::Stage),
    );
    EXIT_INTERNAL
}
fn prelude_error(result: &CheckResult) -> Option<&Diagnostic> {
    result.diagnostics.iter().find(|diag| {
        diag.is_error()
            && diag.primary.as_ref().is_some_and(|label| {
                result
                    .sources
                    .get(label.span.file)
                    .is_some_and(|s| s.kind() == SourceKind::Prelude)
            })
    })
}
fn report_check(
    result: &CheckResult,
    env: &CliEnv,
    format: DiagFormat,
    verb: Verb,
    name: &str,
) -> Option<u8> {
    if let Some(diag) = prelude_error(result) {
        let message = render::render_one_text(diag, &result.sources, TextOptions { color: false });
        return Some(write_internal(
            env,
            format,
            &result.sources,
            "check",
            &message,
            None,
        ));
    }
    if let Some(diag) = result
        .diagnostics
        .iter()
        .find(|diag| diag.kind == ReportKind::Internal)
    {
        write_report(env, format, &result.sources, diag);
        return Some(EXIT_INTERNAL);
    }
    match format {
        DiagFormat::Text => {
            let text = render::render_check_text(
                &result.diagnostics,
                &result.sources,
                verb,
                name,
                TextOptions { color: env.color },
            );
            let _result = env.stderr.write_bytes(text.as_bytes());
        }
        DiagFormat::Json => {
            for diag in &result.diagnostics {
                write_report(env, format, &result.sources, diag);
            }
        }
    }
    (result.error_count() > 0).then_some(EXIT_CHECK)
}

fn execute_script(
    options: Options,
    script: PathBuf,
    args: Option<Vec<OsString>>,
    mut env: CliEnv,
) -> u8 {
    let entry = match pipeline::entry_spec(&script) {
        Ok(entry) => entry,
        Err(EntryError::NoMainFile { dir }) => {
            return usage_error(
                &env,
                &text::NO_MAIN_FILE.replace("{dir}", &dir.display().to_string()),
            );
        }
    };
    let running = args.is_some();
    if running && env.interrupt.is_none() {
        match run::process_interrupt() {
            Ok(interrupt) => env.interrupt = Some(interrupt),
            Err(error) => {
                return write_internal(
                    &env,
                    options.diagnostics,
                    &SourceTable::new(),
                    "run",
                    &error.to_string(),
                    None,
                );
            }
        }
    }
    // 検査の状態と IR の破棄も段のスレッドで行い、深い構造の drop によるスタック超過を防ぐ（実装プラン F18）。
    let dev_panic = env.dev_panic;
    let prepared = panic_boundary::catch(|| {
        pipeline::on_large_stack(|| {
            panic_boundary::catch(|| {
                let checked = pipeline::check(
                    &entry,
                    &crate::modules::RealFs,
                    CheckOptions {
                        require_main: true,
                        deny_warnings: options.deny_warnings,
                    },
                );
                if dev_panic == DevPanic::Check && checked.program.is_some() {
                    development_check_panic();
                }
                let verb = if running { Verb::Run } else { Verb::Check };
                // CliEnv の IO 部品は Send とは限らないため、ここでは検査の診断とコンパイルの結果だけを返す。
                let sources = Arc::clone(&checked.sources);
                let mut compilation = None;
                if running && checked.program.is_some() && prelude_error(&checked).is_none() {
                    compilation = Some(panic_boundary::catch(|| match checked.program.as_ref() {
                        Some(program) => pipeline::desugar_checked(program)
                            .map_err(CompileError::Internal)
                            .and_then(|core| pipeline::compile(&core, Arc::clone(&sources))),
                        None => Err(CompileError::Internal(crate::ir::InternalError {
                            stage: "desugar",
                            message: "checked program missing".into(),
                        })),
                    }));
                }
                // 深い AST を呼び出し側へ返さず、診断とソースだけを残す。
                let result = CheckResult {
                    sources,
                    entry: checked.entry,
                    diagnostics: checked.diagnostics,
                    program: None,
                };
                (result, compilation, verb)
            })
        })
    });
    let (checked, compiled, verb) = match prepared {
        Ok(Ok(Ok(prepared))) => prepared,
        Ok(Ok(Err(panic))) => {
            return write_internal(
                &env,
                options.diagnostics,
                &SourceTable::new(),
                "check",
                &panic.message,
                Some(&panic),
            );
        }
        Ok(Err(error)) => {
            return write_internal(
                &env,
                options.diagnostics,
                &SourceTable::new(),
                "check",
                &error.to_string(),
                None,
            );
        }
        Err(panic) => {
            return write_internal(
                &env,
                options.diagnostics,
                &SourceTable::new(),
                "check",
                &panic.message,
                Some(&panic),
            );
        }
    };
    if let Some(code) = report_check(
        &checked,
        &env,
        options.diagnostics,
        verb,
        &entry.display_name,
    ) {
        return code;
    }
    if !running {
        return EXIT_OK;
    }
    let program = match compiled {
        Some(Ok(Ok(program))) => program,
        Some(Err(panic)) => {
            return write_internal(
                &env,
                options.diagnostics,
                &checked.sources,
                "compile",
                &panic.message,
                Some(&panic),
            );
        }
        Some(Ok(Err(CompileError::Limit(diags)))) => {
            for diag in diags {
                write_report(&env, options.diagnostics, &checked.sources, &diag);
            }
            return EXIT_CHECK;
        }
        Some(Ok(Err(CompileError::Internal(error)))) => {
            return write_internal(
                &env,
                options.diagnostics,
                &checked.sources,
                error.stage,
                &error.message,
                None,
            );
        }
        None => {
            return write_internal(
                &env,
                options.diagnostics,
                &checked.sources,
                "check",
                "missing compilation result",
                None,
            );
        }
    };
    let arguments = match run::check_args(args.unwrap_or_default()) {
        Ok(arguments) => arguments,
        Err(diagnostic) => {
            write_report(&env, options.diagnostics, &checked.sources, &diagnostic);
            return EXIT_FAILURE;
        }
    };
    let input = match run::run_input(&entry, arguments, env.working_directory.clone()) {
        Ok(input) => input,
        Err(error) => {
            return write_internal(
                &env,
                options.diagnostics,
                &checked.sources,
                "run",
                &error.to_string(),
                None,
            );
        }
    };
    let interrupt = match env.interrupt.take() {
        Some(interrupt) => interrupt,
        None => {
            return write_internal(
                &env,
                options.diagnostics,
                &checked.sources,
                "run",
                "missing interrupt source",
                None,
            );
        }
    };
    let end = run::run_program(
        &program,
        run::RunEnv {
            input,
            stdout: env.stdout.clone(),
            stderr: env.stderr.clone(),
            stdin: env.stdin.clone(),
            interrupt,
            parts: env.parts.take(),
            mode: env.mode,
            vm: crate::vm::VmConfig {
                max_call_stack_bytes: options.max_call_stack,
                ..crate::vm::VmConfig::default()
            },
            heap: env.heap,
            dev_panic_after_first_write: env.dev_panic == DevPanic::Run,
        },
    );
    if let Some(message) = end.main_error {
        let _result = env.stderr.write_bytes(format!("{message}\n").as_bytes());
    }
    for diagnostic in end.reports {
        write_report(&env, options.diagnostics, &checked.sources, &diagnostic);
    }
    if env.dev_alloc_stats {
        let message = text::ALLOC_STATS
            .replace("{allocations}", &end.heap.allocations.to_string())
            .replace("{allocated_bytes}", &end.heap.allocated_bytes.to_string())
            .replace("{peak_heap_bytes}", &end.heap.peak_heap_bytes.to_string())
            .replace("{collections}", &end.heap.collections.to_string());
        let _result = env.stderr.write_bytes(format!("{message}\n").as_bytes());
    }
    end.exit_code
}

// 処理系の不具合の報告を確認する開発用の panic に限る（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#[allow(clippy::panic)]
fn development_check_panic() {
    panic!("BENITOITE_DEV_PANIC=check");
}

fn read_development_environment(env: &mut CliEnv) -> Result<(), String> {
    if let Some(value) = std::env::var_os("BENITOITE_DEV_IO_MODE") {
        env.mode = match value.to_str() {
            Some("direct") => ExecMode::Direct,
            Some("request") => ExecMode::Request,
            _ => return Err(bad_environment("BENITOITE_DEV_IO_MODE", &value)),
        };
    }
    if cfg!(debug_assertions)
        && let Some(value) = std::env::var_os("BENITOITE_DEV_PANIC")
    {
        env.dev_panic = match value.to_str() {
            Some("check") => DevPanic::Check,
            Some("run") => DevPanic::Run,
            _ => return Err(bad_environment("BENITOITE_DEV_PANIC", &value)),
        };
    }
    if cfg!(feature = "alloc-stats")
        && let Some(value) = std::env::var_os("BENITOITE_DEV_ALLOC_STATS")
    {
        if value != "1" {
            return Err(bad_environment("BENITOITE_DEV_ALLOC_STATS", &value));
        }
        env.dev_alloc_stats = true;
    }
    Ok(())
}
fn bad_environment(name: &str, value: &std::ffi::OsStr) -> String {
    text::BAD_VALUE
        .replace("{name}", name)
        .replace("{value}", &value.to_string_lossy())
}
use std::sync::Arc;

#[cfg(test)]
mod tests {
    // 関門: CLI が段をつなぐ時の終了状態・出力・診断を確かめる。各段のテストだけでは
    // 入口の選択や実行を止める判定の退行を捕まえない。内部の段は本物をつなぐ（設計書 07-03）。
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use std::sync::Mutex;

    const HELLO: &str = include_str!("../../testdata/modules/f18_hello.bnt");
    struct Directory(PathBuf);
    impl Directory {
        fn new() -> Self {
            let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../../target/f18-tests")
                .join(format!(
                    "{}-{}",
                    std::process::id(),
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_nanos()
                ));
            std::fs::create_dir_all(&path).unwrap();
            Self(path)
        }
        fn write(&self, name: &str, text: &str) -> PathBuf {
            let path = self.0.join(name);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(&path, text).unwrap();
            path
        }
    }
    impl Drop for Directory {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).unwrap();
        }
    }
    type Capture = Arc<Mutex<Vec<u8>>>;
    fn captured() -> (CliEnv, Capture, Capture) {
        let out = Arc::new(Mutex::new(Vec::new()));
        let err = Arc::new(Mutex::new(Vec::new()));
        (
            CliEnv {
                stdout: OutputTarget::Capture(Arc::clone(&out)),
                stderr: OutputTarget::Capture(Arc::clone(&err)),
                stdin: StdinSource::Empty,
                working_directory: std::env::current_dir().unwrap(),
                color: false,
                mode: ExecMode::Direct,
                interrupt: Some(Box::new(run::NoInterrupt)),
                parts: None,
                heap: HeapConfig::default(),
                dev_panic: DevPanic::None,
                dev_alloc_stats: false,
            },
            out,
            err,
        )
    }
    fn call(args: Vec<OsString>, mode: ExecMode, panic: DevPanic) -> (u8, String, String) {
        let (mut env, out, err) = captured();
        env.mode = mode;
        env.dev_panic = panic;
        let exit = invoke(args, env);
        let out = String::from_utf8(out.lock().unwrap().clone()).unwrap();
        let err = String::from_utf8(err.lock().unwrap().clone()).unwrap();
        (exit, out, err)
    }
    fn strings(args: &[&str]) -> Vec<OsString> {
        args.iter().map(OsString::from).collect()
    }
    fn script_args(verb: &str, path: &std::path::Path, options: &[&str]) -> Vec<OsString> {
        let mut args = strings(&[verb]);
        args.extend(strings(options));
        args.push(path.as_os_str().to_owned());
        args
    }

    #[test]
    fn parse_commands_sizes_options_and_passthrough() {
        for (size, expected) in [
            ("512MiB", Some(536870912)),
            ("2GiB", Some(2147483648)),
            ("1KiB", Some(1024)),
            ("0MiB", None),
            ("10", None),
            ("1TiB", None),
            ("18446744073709551616GiB", None),
            ("18446744073709551615KiB", None),
            ("+1KiB", None),
            ("-1KiB", None),
        ] {
            assert_eq!(parse_size(size), expected, "{size}");
        }
        assert_eq!(
            parse_args(strings(&["run", "a.bnt", "--x", "y"])).unwrap(),
            Command::Run {
                options: Options::default(),
                script: "a.bnt".into(),
                args: strings(&["--x", "y"])
            }
        );
        for prefix in [
            vec!["--deny-warnings", "run"],
            vec!["run", "--deny-warnings"],
            vec!["--deny-warnings"],
        ] {
            let mut args = strings(&prefix);
            args.push("a.bnt".into());
            assert!(
                matches!(parse_args(args).unwrap(), Command::Run { options, .. } if options.deny_warnings)
            );
        }
        assert_eq!(
            parse_args(strings(&["--diagnostics=json", "fmt", "--check", "a.bnt"])).unwrap(),
            Command::Tool {
                tool: ToolCommand::Fmt,
                args: strings(&["--diagnostics=json", "--check", "a.bnt"])
            }
        );
        assert!(matches!(
            parse_args(strings(&["./server"])).unwrap(),
            Command::Run { .. }
        ));
        assert!(
            matches!(parse_args(strings(&["check", "--max-call-stack=2GiB", "a.bnt"])).unwrap(),
            Command::Check { options, .. } if options.max_call_stack == 2147483648)
        );
    }

    #[test]
    fn usage_errors_have_two_lines_and_exit_two() {
        let cases = [
            (
                vec!["server"],
                text::RESERVED_COMMAND.replace("{name}", "server"),
            ),
            (
                vec!["run", "--unknown", "a.bnt"],
                text::UNKNOWN_OPTION.replace("{name}", "--unknown"),
            ),
            (
                vec!["check", "--check", "a.bnt"],
                text::UNKNOWN_OPTION.replace("{name}", "--check"),
            ),
            (
                vec!["run", "--diagnostics=bad", "a.bnt"],
                text::BAD_VALUE
                    .replace("{name}", "--diagnostics")
                    .replace("{value}", "bad"),
            ),
            (
                vec![
                    "run",
                    "--max-call-stack=1MiB",
                    "--max-call-stack=2MiB",
                    "a.bnt",
                ],
                text::DUPLICATE_OPTION.replace("{name}", "--max-call-stack"),
            ),
            (
                vec!["check", "--deny-warnings", "--deny-warnings", "a.bnt"],
                text::DUPLICATE_OPTION.replace("{name}", "--deny-warnings"),
            ),
            (vec!["run"], text::MISSING_SCRIPT.to_owned()),
            (vec![], text::MISSING_COMMAND.to_owned()),
            (
                vec!["check", "a.bnt", "extra"],
                text::EXTRA_ARGUMENT.replace("{value}", "extra"),
            ),
        ];
        for (args, detail) in cases {
            assert_eq!(parse_args(strings(&args)).unwrap_err(), detail);
            let (exit, out, err) = call(strings(&args), ExecMode::Direct, DevPanic::None);
            assert_eq!(exit, EXIT_CHECK);
            assert!(out.is_empty());
            assert_eq!(
                err,
                format!(
                    "{}\n{}\n",
                    text::USAGE_ERROR.replace("{detail}", &detail),
                    text::SEE_HELP
                )
            );
        }
    }

    // 機能 bundled-licenses を付けたビルドでは一覧を埋め込むので、このテストは開発のビルドだけで行う。
    #[cfg(not(feature = "bundled-licenses"))]
    #[test]
    fn licenses_in_development_build_say_list_is_not_bundled() {
        // 開発のビルドは機能 bundled-licenses を持たない（05-01「ライセンスの表示」）
        let (exit, out, err) = call(strings(&["--licenses"]), ExecMode::Direct, DevPanic::None);
        assert_eq!(exit, EXIT_OK);
        assert!(err.is_empty());
        assert_eq!(
            out,
            format!(
                "{}{}",
                tools::licenses::text::OWN_LICENSE,
                tools::licenses::text::NOT_BUNDLED
            )
        );
    }

    #[test]
    fn run_implicit_shebang_directory_and_request_execution() {
        let dir = Directory::new();
        let path = dir.write("hello.bnt", HELLO);
        let shebang = dir.write("shebang.bnt", &format!("#!/usr/bin/env benitoite\n{HELLO}"));
        dir.write(
            "Lib/Text.bnt",
            include_str!("../../testdata/modules/f18_directory/Lib/Text.bnt"),
        );
        dir.write(
            "main.bnt",
            include_str!("../../testdata/modules/f18_directory/main.bnt"),
        );
        for mode in [ExecMode::Direct, ExecMode::Request] {
            for args in [
                script_args("run", &path, &[]),
                vec![path.as_os_str().to_owned()],
                vec![shebang.as_os_str().to_owned()],
                script_args("run", &dir.0, &[]),
            ] {
                assert_eq!(
                    call(args, mode, DevPanic::None),
                    (EXIT_OK, "hello\n".into(), String::new())
                );
            }
        }
    }

    #[test]
    fn file_positions_check_errors_json_and_missing_main() {
        let dir = Directory::new();
        let bad = dir.write(
            "bad.bnt",
            "#!/usr/bin/env benitoite\nfunction main() -> Unit\n return \"bad\"\nend function\n",
        );
        for verb in ["run", "check"] {
            let (exit, out, err) = call(
                script_args(verb, &bad, &[]),
                ExecMode::Direct,
                DevPanic::None,
            );
            assert_eq!(exit, EXIT_CHECK);
            assert!(out.is_empty());
            assert!(err.contains("error[E0401]"), "{err}");
            assert!(err.contains(&format!("{}:3:", bad.display())), "{err}");
            assert!(err.contains(&format!("could not {verb}")), "{err}");
            let (exit, out, err) = call(
                script_args(verb, &bad, &["--diagnostics=json"]),
                ExecMode::Direct,
                DevPanic::None,
            );
            assert_eq!(exit, EXIT_CHECK);
            assert!(out.is_empty());
            assert_eq!(err.lines().count(), 1);
            assert!(err.starts_with("{\"kind\":\"check\""));
            assert!(err.ends_with("}\n"));
        }
        let empty = Directory::new();
        let (exit, out, err) = call(
            script_args("run", &empty.0, &["--diagnostics=json"]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(exit, EXIT_CHECK);
        assert!(out.is_empty());
        assert_eq!(
            err,
            format!(
                "{}\n{}\n",
                text::USAGE_ERROR.replace(
                    "{detail}",
                    &text::NO_MAIN_FILE.replace("{dir}", &empty.0.display().to_string())
                ),
                text::SEE_HELP
            )
        );
        dir.write(
            "main.bnt",
            "function main() -> Unit\n\n return \"bad\"\nend function\n",
        );
        let (exit, _, err) = call(
            script_args("check", &dir.0, &[]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(exit, EXIT_CHECK);
        assert!(err.contains(&format!("{}/main.bnt:3:", dir.0.display())));
    }

    #[test]
    fn warnings_are_reported_before_execution_and_deny_prevents_it() {
        let dir = Directory::new();
        let source = HELLO.replace("function main()", "@deprecated(\"old\")\nfunction old() -> String\n return \"hello\"\nend function\nfunction main()").replace("Console.writeLine(\"hello\")", "Console.writeLine(old())");
        let path = dir.write("warnings.bnt", &source);
        for verb in ["check", "run"] {
            for deny in [false, true] {
                let options = if deny {
                    vec!["--deny-warnings"]
                } else {
                    vec![]
                };
                let (exit, out, err) = call(
                    script_args(verb, &path, &options),
                    ExecMode::Direct,
                    DevPanic::None,
                );
                assert_eq!(exit, if deny { EXIT_CHECK } else { EXIT_OK }, "{err}");
                assert_eq!(
                    out,
                    if !deny && verb == "run" {
                        "hello\n"
                    } else {
                        ""
                    }
                );
                assert!(
                    err.contains(if deny {
                        "error[W0301]"
                    } else {
                        "warning[W0301]"
                    }),
                    "{err}"
                );
                if deny {
                    assert!(err.contains("--deny-warnings"));
                }
            }
        }
    }

    #[test]
    fn main_result_runtime_error_and_panic_exit_states() {
        let dir = Directory::new();
        for (name, source, exit, needle) in [
            (
                "result",
                "function main() -> Result[Unit, String]\n return Result.Error(\"bad\")\nend function\n",
                EXIT_FAILURE,
                "bad\n",
            ),
            (
                "division",
                "function main() -> Unit\n bind _ <- 1 div 0\nend function\n",
                EXIT_FAILURE,
                "R0101",
            ),
        ] {
            let path = dir.write(&format!("{name}.bnt"), source);
            for options in [vec![], vec!["--diagnostics=json"]] {
                let (actual, out, err) = call(
                    script_args("run", &path, &options),
                    ExecMode::Direct,
                    DevPanic::None,
                );
                assert_eq!(actual, exit, "{err}");
                assert!(out.is_empty());
                assert!(err.contains(needle), "{err}");
                if name == "result" {
                    assert_eq!(err, "bad\n");
                }
            }
        }
        let path = dir.write("hello.bnt", HELLO);
        for (panic, expected_out) in [(DevPanic::Check, ""), (DevPanic::Run, "hello\n")] {
            let (exit, out, err) = call(script_args("run", &path, &[]), ExecMode::Direct, panic);
            assert_eq!(exit, EXIT_INTERNAL);
            assert_eq!(out, expected_out);
            assert!(err.contains("internal error"), "{err}");
        }
    }

    #[test]
    fn prelude_source_errors_are_internal_and_user_errors_are_check_failures() {
        // 作業文書が指定した判定の単体テスト。check_files では埋め込んだソースを差し替えられない。
        let mut table = SourceTable::new();
        let user = table.add(crate::base::Source::new(
            "user.bnt".into(),
            SourceKind::User,
            b"bad".to_vec(),
        ));
        let prelude = table.add(crate::base::Source::new(
            "<benitoite>/Bad.bnt".into(),
            SourceKind::Prelude,
            b"bad".to_vec(),
        ));
        let mut result = CheckResult {
            sources: Arc::new(table),
            entry: Some(user),
            program: None,
            diagnostics: vec![
                crate::diag::DiagBuilder::new(crate::diag::DiagCode::E0301)
                    .arg("name", "bad")
                    .primary(crate::base::Span {
                        file: user,
                        start: crate::base::BytePos(0),
                        end: crate::base::BytePos(3),
                    })
                    .build(),
            ],
        };
        assert!(prelude_error(&result).is_none());
        for format in [DiagFormat::Text, DiagFormat::Json] {
            let (env, _, err) = captured();
            assert_eq!(
                report_check(&result, &env, format, Verb::Check, "user.bnt"),
                Some(EXIT_CHECK)
            );
            result.diagnostics.push(
                crate::diag::DiagBuilder::new(crate::diag::DiagCode::E0301)
                    .arg("name", "bad")
                    .primary(crate::base::Span {
                        file: prelude,
                        start: crate::base::BytePos(0),
                        end: crate::base::BytePos(3),
                    })
                    .build(),
            );
            assert_eq!(
                prelude_error(&result)
                    .unwrap()
                    .primary
                    .as_ref()
                    .unwrap()
                    .span
                    .file,
                prelude
            );
            let (env, _, internal) = captured();
            assert_eq!(
                report_check(&result, &env, format, Verb::Check, "user.bnt"),
                Some(EXIT_INTERNAL)
            );
            let internal = String::from_utf8(internal.lock().unwrap().clone()).unwrap();
            assert!(internal.contains("internal"));
            assert!(internal.contains("check"));
            assert!(internal.contains("<benitoite>"));
            assert!(!err.lock().unwrap().is_empty());
            result.diagnostics.pop();
        }
    }

    #[cfg(unix)]
    #[test]
    fn invalid_utf8_script_argument_reports_r0301_without_running() {
        use std::os::unix::ffi::OsStringExt;
        let dir = Directory::new();
        let path = dir.write("hello.bnt", HELLO);
        let mut args = script_args("run", &path, &[]);
        args.extend([OsString::from("good"), OsString::from_vec(vec![255])]);
        let (exit, out, err) = call(args, ExecMode::Direct, DevPanic::None);
        assert_eq!(exit, EXIT_FAILURE);
        assert!(out.is_empty());
        assert!(err.contains("R0301"));
        assert!(err.contains("argument 2"));
    }

    #[test]
    fn codegen_limit_is_a_run_error_but_check_succeeds() {
        let dir = Directory::new();
        // 宣言を大量に並べる入力は検査が遅いため、作業文書が認める原型内の定数の上限を使う。
        // 引数を一つ混ぜ、リスト全体を単一の定数へ畳ませない（実装プラン F18「処理系の制限」）。
        let mut source = String::from("function many(x: Integer) -> Unit\n");
        // 一つのリストと文の数をそれぞれ抑え、構文の入れ子の上限ではなく定数の上限へ届かせる。
        for start in (0..65537).step_by(256) {
            source.push_str(" bind _ <- [x");
            for index in start..(start + 256).min(65537) {
                source.push_str(&format!(", {index}"));
            }
            source.push_str("]\n");
        }
        source.push_str("end function\nfunction main() -> Unit\nend function\n");
        let path = dir.write("limit.bnt", &source);
        let (exit, out, err) = call(
            script_args("check", &path, &[]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(exit, EXIT_OK, "{}", err.lines().next().unwrap_or(""));
        assert!(out.is_empty());
        assert!(err.is_empty());
        let (exit, out, err) = call(
            script_args("run", &path, &[]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(exit, EXIT_CHECK, "{err}");
        assert!(out.is_empty());
        assert!(err.contains("L0102"), "{err}");
    }
}
