//! CLI（設計書 06-01）。サブコマンドは `run`・`check`・`test`・`fmt`・`skill`・`package`。
//! `test`・`fmt`・`skill`・`package` と `--licenses` は `tools` で処理する。

mod build_info;
mod check_report;
mod content_hash;
mod effect_limit;
mod inspection;
pub use effect_limit::EffectLimit;
pub mod tools;
mod wasm;
pub use wasm::WasmOptions;

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

/// 非実行の検査報告の形式（06-01「main の非実行の検査報告」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReportFormat {
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
    /// `check --report=json`
    pub report: Option<ReportFormat>,
    /// `run --allow-effects` の許す集合。
    pub allow_effects: Option<EffectLimit>,
}

impl Default for Options {
    fn default() -> Options {
        Options {
            diagnostics: DiagFormat::Text,
            max_call_stack: DEFAULT_MAX_CALL_STACK,
            deny_warnings: false,
            report: None,
            allow_effects: None,
        }
    }
}

/// `tools` で処理するサブコマンド。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ToolCommand {
    Test,
    Fmt,
    Skill,
    Package,
}

/// 解釈したコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Command {
    /// `run`、`run` を省いた実行、シェバンによる実行
    Run {
        options: Options,
        script: PathBuf,
        args: Vec<OsString>,
        wasm: WasmOptions,
    },
    Check {
        options: Options,
        script: PathBuf,
    },
    /// `test`・`fmt`・`skill`・`package`。名前の前のオプションと名前の後の引数を、解釈せずに渡す（`tools::run_tool` が解釈する）
    Tool {
        tool: ToolCommand,
        args: Vec<OsString>,
    },
    Help,
    Version,
    /// ビルド情報と提供済みの形式を単一の JSON で問い合わせる。
    VersionJson,
    Licenses,
}

/// 予約したサブコマンドの名前（06-01「予約したサブコマンドの名前（初回リリース版）」）。
pub const RESERVED_COMMANDS: &[&str] = &["server", "mcp", "sign", "verify", "repl", "lsp", "agent"];

/// 開発用の panic の指定（`BENITOITE_DEV_PANIC`。デバッグのビルドでだけ読む）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DevPanic {
    None,
    /// 型検査の後、脱糖の前に panic を起こす
    Check,
    /// 最初の書き込みを出力のバッファに加えた直後に panic を起こす（`RunEnv::dev_panic_after_first_write`）
    Run,
    /// `skill`・`test`・`fmt` の本体の先頭で、ファイルに触れる前に panic を起こす
    Tool,
}

/// CLI の一回の実行の環境。`main` はプロセスの標準入出力で作り、ゴールデンテストの実行器は
/// メモリに捕らえる出力先で作る。
#[derive(Debug)]
pub struct CliEnv {
    /// `--help`・`--version`・`--licenses`・check の検査報告の出力と、スクリプトの標準出力
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
    /// テストで差し替える部品（07-03「順序を与えるスケジューラと仮想の時間（初回リリース版）」）。`main` は `None`
    pub parts: Option<RuntimeParts>,
    pub heap: HeapConfig,
    pub dev_panic: DevPanic,
    /// `run` の終わりに確保の統計を標準エラー出力に一行で書く（機能 `alloc-stats` のビルドの `BENITOITE_DEV_ALLOC_STATS=1`）
    pub dev_alloc_stats: bool,
}

/// 使い方の誤りの文と、`--help`・`--version` の文（02-10「文言の言語」に従い英語で書き、ここにまとめる）。
pub mod text {
    pub const USAGE: &str = "\
Usage:
  benitoite [options] <script> [script arguments...]
  benitoite run   [options] <script> [script arguments...]
  benitoite check [options] <script>
  benitoite test  [options] <path>...
  benitoite fmt   [options] <path>...
  benitoite skill install|uninstall [--user | --project] [--agent <name>]...
  benitoite skill list [--format=text|json]
  benitoite skill show [--format=text|json] <logical-name>
  benitoite package add [options] <alias> --path <directory> [<root or entry>]
  benitoite package update [options] [<alias>] [<root or entry>]
  benitoite package move [options] <entry>
  benitoite --help
  benitoite --version
  benitoite --version=json
  benitoite --licenses

<script> is a .bnt file, or a directory that contains main.bnt.

Options:
  --diagnostics=text|json   format of diagnostics and error reports (default: text)
  --max-call-stack=<size>   limit for nested calls, such as 512MiB or 2GiB (default: 1GiB)
  --wasm-memory=<size>      (run, test) linear memory limit, 1MiB-4GiB (default: 64MiB)
  --wasm-fuel=<count>       (run, test) fuel per external call (default: 10000000000)
  --wasm-transfer=<size>    (run, test) transfer budget, 1MiB-4GiB (default: 256MiB)
  --wasm-stats              (run, test) write aggregate WASM statistics as JSON to stderr
  --deny-warnings           treat warnings as errors
  --report=json             (check, test --check) write a single JSON inspection report to stdout
  --allow-effects=<names>   (run, test) allowed atomic effects, comma-separated; empty means none
  --doc                     (test) include documentation examples
  --check                   (test) type-check without running tests; (fmt) report files that would change
";
    /// `--version` の出力。`{version}` は処理系の版、`{unicode}` は文字の分類と変換が従う Unicode の版
    /// （Rust の `char::UNICODE_VERSION`。03-06「Character」）
    pub const VERSION: &str = "benitoite {version}\nUnicode {unicode}\n";
    /// 使い方の誤りの 1 行目。`{detail}` を置き換える
    pub const USAGE_ERROR: &str = "error: {detail}";
    pub const SEE_HELP: &str = "run `benitoite --help` for usage";
    pub const MISSING_COMMAND: &str = "missing subcommand or script path";
    pub const RESERVED_COMMAND: &str =
        "`{name}` is reserved for a later version; to run a file with this name, write `./{name}`";
    pub const UNKNOWN_OPTION: &str = "unknown option `{name}`";
    pub const MISSING_OPTION_VALUE: &str = "missing value for `{name}`";
    pub const INVALID_EFFECT_NAME: &str =
        "invalid effect name `{name}` in `--allow-effects`; use atomic names from `expanded`";
    pub const DUPLICATE_EFFECT_NAME: &str = "duplicate effect name `{name}` in `--allow-effects`";
    pub const EMPTY_EFFECT_NAME: &str = "empty effect name in `--allow-effects`";
    pub const OPTION_TAKES_NO_VALUE: &str = "`{name}` does not take a value";
    pub const WASM_SIZE_RANGE: &str = "expected a size in 1MiB-4GiB";
    pub const WASM_FUEL_RANGE: &str = "expected an integer in 1-18446744073709551615";
    pub const BAD_VALUE: &str = "invalid value `{value}` for `{name}`";
    pub const DUPLICATE_OPTION: &str = "option `{name}` may only be specified once";
    pub const OPTION_NOT_FOR_COMMAND: &str = "option `{name}` is not accepted by `{command}`";
    pub const MISSING_SCRIPT: &str = "missing script path";
    pub const EXTRA_ARGUMENT: &str = "unexpected argument `{value}`";
    pub const REPORT_TEXT_DIAGNOSTICS: &str =
        "`--report=json` cannot be combined with `--diagnostics=text`";
    pub const NO_MAIN_FILE: &str = "directory `{dir}` has no `main.bnt`";
    /// `BENITOITE_DEV_ALLOC_STATS` の行
    pub const ALLOC_STATS: &str = "alloc-stats: allocations={allocations} allocated_bytes={allocated_bytes} peak_heap_bytes={peak_heap_bytes} collections={collections}";
}

use std::process::ExitCode;

/// `benitoite` の後のコマンドライン引数を解釈する（本章「コマンドライン」）。
/// 使い方の誤りは、`text` の型板から作った 1 行の説明（`USAGE_ERROR` の `{detail}` の部分）を返す。
pub fn parse_args(args: Vec<OsString>) -> Result<Command, String> {
    parse_invocation(args).map_err(|error| error.detail)
}

// 診断の kind と区別し、入口で確定した報告の形式だけを保持する。
#[derive(Debug)]
enum ReportKind {
    Check,
}

#[derive(Debug)]
struct CliParseError {
    detail: String,
    report: Option<ReportKind>,
    script: Option<PathBuf>,
}

impl From<String> for CliParseError {
    fn from(detail: String) -> Self {
        Self {
            detail,
            report: None,
            script: None,
        }
    }
}

// サブコマンドの選択と誤りの後の走査でも、値をオプションと取り違えないために使う。
// 分離した値を受理するのは allow-effects だけである（設計書 06-01「オプション」）。
fn takes_option_value(name: &str) -> bool {
    matches!(
        name,
        "--diagnostics"
            | "--max-call-stack"
            | "--report"
            | "--allow-effects"
            | "--wasm-memory"
            | "--wasm-fuel"
            | "--wasm-transfer"
    )
}

fn parse_invocation(args: Vec<OsString>) -> Result<Command, CliParseError> {
    if let Some(first) = args.first().and_then(|a| a.to_str()) {
        match first {
            "--help" => return Ok(Command::Help),
            "--version" => return Ok(Command::Version),
            "--version=json" => {
                if let Some(extra) = args.get(1) {
                    return Err(text::EXTRA_ARGUMENT
                        .replace("{value}", &extra.to_string_lossy())
                        .into());
                }
                return Ok(Command::VersionJson);
            }
            value if value.starts_with("--version=") => {
                return Err(text::BAD_VALUE
                    .replace("{name}", "--version")
                    .replace("{value}", value.strip_prefix("--version=").unwrap_or(""))
                    .into());
            }
            "--licenses" => return Ok(Command::Licenses),
            _ => {}
        }
    }
    let mut command_index = None;
    let mut command_args = args.iter().enumerate();
    while let Some((index, arg)) = command_args.next() {
        let value = arg.to_string_lossy();
        if !value.starts_with('-') {
            command_index = Some(index);
            break;
        }
        if takes_option_value(&value) {
            let _value = command_args.next();
        }
    }
    if let Some(index) = command_index {
        let name = args.get(index).and_then(|a| a.to_str()).unwrap_or("");
        let tool = match name {
            "test" => Some(ToolCommand::Test),
            "fmt" => Some(ToolCommand::Fmt),
            "skill" => Some(ToolCommand::Skill),
            "package" => Some(ToolCommand::Package),
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
            return Err(text::RESERVED_COMMAND.replace("{name}", name).into());
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
    let mut wasm = WasmOptions::default();
    let mut seen = std::collections::BTreeSet::new();
    let mut script = None;
    let mut script_args = Vec::new();
    let mut detail = None;
    let mut report = None;
    let mut remaining = args.into_iter().enumerate();
    while let Some((index, arg)) = remaining.next() {
        if Some(index) == skip {
            continue;
        }
        if script.is_some() {
            if checking {
                detail.get_or_insert_with(|| {
                    text::EXTRA_ARGUMENT.replace("{value}", &arg.to_string_lossy())
                });
            } else {
                script_args.push(arg);
            }
        } else if arg.to_string_lossy().starts_with('-') {
            let value = arg.to_string_lossy();
            let (name, setting) = value
                .split_once('=')
                .map_or((&*value, None), |(n, v)| (n, Some(v)));
            let separate_value = (setting.is_none() && takes_option_value(name))
                .then(|| remaining.next())
                .flatten();
            // 重複や先行する誤りがあっても、有効な指定の存在を記録する。
            // スクリプト引数と分離値はここへ来ない（設計書 06-01「オプション」）。
            if checking && name == "--report" && setting == Some("json") {
                report = Some(ReportKind::Check);
            }
            let parsed = (|| {
                if name == "--report" && !checking {
                    return Err(text::OPTION_NOT_FOR_COMMAND
                        .replace("{name}", name)
                        .replace("{command}", "run"));
                }
                if name == "--allow-effects" && checking {
                    return Err(text::OPTION_NOT_FOR_COMMAND
                        .replace("{name}", name)
                        .replace("{command}", "check"));
                }
                if !matches!(
                    name,
                    "--diagnostics" | "--max-call-stack" | "--deny-warnings" | "--allow-effects"
                ) && !(WasmOptions::accepts(name) && !checking || name == "--report" && checking)
                {
                    return Err(text::UNKNOWN_OPTION.replace("{name}", &value));
                }
                if !seen.insert(name.to_owned()) {
                    return Err(text::DUPLICATE_OPTION.replace("{name}", name));
                }
                if WasmOptions::accepts(name) {
                    return wasm.parse(name, setting);
                }
                if name == "--allow-effects" {
                    let separate_value = separate_value
                        .as_ref()
                        .map(|(_, value)| value.to_string_lossy());
                    let value = setting
                        .or(separate_value.as_deref())
                        .ok_or_else(|| text::MISSING_OPTION_VALUE.replace("{name}", name))?;
                    options.allow_effects = Some(effect_limit::parse(value)?);
                    return Ok(());
                }
                match (name, setting) {
                    ("--diagnostics", Some("text")) => options.diagnostics = DiagFormat::Text,
                    ("--diagnostics", Some("json")) => options.diagnostics = DiagFormat::Json,
                    ("--report", Some("json")) => options.report = Some(ReportFormat::Json),
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
                Ok(())
            })();
            if let Err(error) = parsed {
                detail.get_or_insert(error);
            }
        } else {
            script = Some(PathBuf::from(arg));
        }
    }
    if options.report.is_some()
        && seen.contains("--diagnostics")
        && options.diagnostics == DiagFormat::Text
    {
        detail.get_or_insert_with(|| text::REPORT_TEXT_DIAGNOSTICS.into());
    }
    if script.is_none() {
        detail.get_or_insert_with(|| {
            if skip.is_some() || !seen.is_empty() {
                text::MISSING_SCRIPT.to_owned()
            } else {
                text::MISSING_COMMAND.to_owned()
            }
        });
    }
    if let Some(detail) = detail {
        return Err(CliParseError {
            detail,
            report,
            script,
        });
    }
    let script = script.ok_or_else(|| CliParseError::from(text::MISSING_SCRIPT.to_owned()))?;
    Ok(if checking {
        Command::Check { options, script }
    } else {
        Command::Run {
            options,
            script,
            args: script_args,
            wasm,
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
        Command::VersionJson => {
            let (major, minor, update) = char::UNICODE_VERSION;
            let (width_major, width_minor, width_update) =
                crate::base::display_width::UNICODE_VERSION;
            let value = serde_json::json!({
                "schemaVersion": 1,
                "kind": "version",
                "name": "benitoite",
                "version": env!("CARGO_PKG_VERSION"),
                "unicodeVersion": format!("{major}.{minor}.{update}"),
                "displayWidthUnicodeVersion": format!("{width_major}.{width_minor}.{width_update}"),
                "build": build_info::value(),
                "formats": {
                    "version": [1],
                    "diagnostics": [1],
                    "testResults": [1, 2],
                    "checkReport": [1],
                    "testCheckReport": [1, 2],
                    "effectLimit": [1],
                    "loaderEnvironment": [1],
                    "skillList": [1],
                    "skillDocument": [1]
                },
                "loaderEnvironment": {
                    "schemaVersion": 1,
                    "mode": "always",
                    "deniedPrefixes": ["DYLD_", "LD_"],
                    "nameComparison": "asciiCaseInsensitive",
                    "inherited": "unchanged",
                    "errorKind": "InvalidInput"
                }
            });
            write_plain(&env.stdout, &format!("{value}\n"))
        }
        Command::Licenses => tools::print_licenses(&env),
        Command::Tool { tool, args } => tools::run_tool(tool, args, env),
        Command::Run {
            options,
            script,
            args,
            wasm,
        } => {
            let execution = wasm.execution();
            let stderr = env.stderr.clone();
            let code = execute_script(options, script, Some(args), env, execution.clone());
            wasm.report(&execution, &stderr);
            code
        }
        Command::Check { options, script } => {
            if options.report.is_some() {
                check_report::run_check(options, script, env)
            } else {
                execute_script(options, script, None, env, Default::default())
            }
        }
    }
}

/// CLI の入口。panic hook を設定し（`runtime::panic::install_hook`）、コマンドラインを解釈し、
/// 環境変数（`BENITOITE_DEV_IO_MODE`、デバッグのビルドの `BENITOITE_DEV_PANIC`、機能 `alloc-stats` のビルドの
/// `BENITOITE_DEV_ALLOC_STATS`、`NO_COLOR`）を読んでプロセスの標準入出力の `CliEnv` を作り、`execute` を呼ぶ。
/// 使い方の誤りは、認識済みの check の報告に収めるか、`USAGE_ERROR` と `SEE_HELP` の
/// 2 行を標準エラー出力に書き、終了状態 2 で終える。
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
                FaultThread::Stage,
            ));
        }
    };
    if let Err(detail) = read_development_environment(&mut env) {
        return ExitCode::from(usage_error(&env, &detail));
    }
    ExitCode::from(invoke(std::env::args_os().skip(1).collect(), env))
}

use crate::base::{SourceKind, SourceTable};
use crate::bytecode::program::CompiledProgram;
use crate::diag::render::{self, TextOptions, Verb};
use crate::diag::{Diagnostic, ReportKind as DiagnosticKind};
use crate::modules::EntrySpec;
use crate::pipeline::{self, CheckOptions, CheckResult, CompileError, EntryError};
use crate::runtime::report::FaultThread;
use crate::runtime::run::{EXIT_CHECK, EXIT_FAILURE, EXIT_INTERNAL, EXIT_OK};
use crate::runtime::{panic as panic_boundary, report, run};

fn invoke(args: Vec<OsString>, env: CliEnv) -> u8 {
    match parse_invocation(args) {
        Ok(command) => execute(command, env),
        Err(error) => match error.report {
            Some(ReportKind::Check) => {
                check_report::usage_error(&env, error.script.as_deref(), &error.detail)
            }
            None => usage_error(&env, &error.detail),
        },
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
    write_report_to(&env.stderr, env.color, format, sources, diagnostic);
}
fn write_report_to(
    stderr: &OutputTarget,
    color: bool,
    format: DiagFormat,
    sources: &SourceTable,
    diagnostic: &Diagnostic,
) {
    let message = match format {
        DiagFormat::Text => render::render_one_text(diagnostic, sources, TextOptions { color }),
        DiagFormat::Json => format!("{}\n", render::render_json_line(diagnostic, sources)),
    };
    let _result = stderr.write_bytes(message.as_bytes());
}
fn write_tool_panic(
    stderr: &OutputTarget,
    color: bool,
    format: DiagFormat,
    stage: &str,
    panic: &panic_boundary::PanicReport,
) -> u8 {
    write_report_to(
        stderr,
        color,
        format,
        &SourceTable::new(),
        &report::internal_diagnostic(stage, &panic.message, Some(panic), FaultThread::Main),
    );
    EXIT_INTERNAL
}
fn write_internal(
    env: &CliEnv,
    format: DiagFormat,
    sources: &SourceTable,
    stage: &str,
    message: &str,
    panic: Option<&panic_boundary::PanicReport>,
    thread: FaultThread,
) -> u8 {
    write_report(
        env,
        format,
        sources,
        &report::internal_diagnostic(stage, message, panic, thread),
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
            FaultThread::Stage,
        ));
    }
    if let Some(diag) = result
        .diagnostics
        .iter()
        .find(|diag| diag.kind == DiagnosticKind::Internal)
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

// CliEnv の IO 部品は Send とは限らないため、段からは所有する結果だけを返す
// （設計書 02-01「検査と実行の経路」「関数の呼び出しと処理系のスタック」）。
struct PreparedScript {
    checked: CheckResult,
    compilation: Option<Result<Result<CompiledProgram, CompileError>, panic_boundary::PanicReport>>,
    verb: Verb,
    inspection: Option<Result<inspection::ProgramInspection, crate::ir::InternalError>>,
}

fn prepare_script(
    entry: &EntrySpec,
    deny_warnings: bool,
    running: bool,
    inspecting: bool,
    allow_effects: Option<&EffectLimit>,
    dev_panic: DevPanic,
) -> Result<PreparedScript, Box<Diagnostic>> {
    // 検査の状態と IR の破棄も段のスレッドで行い、深い構造の drop によるスタック超過を防ぐ
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    let prepared = panic_boundary::catch(|| {
        pipeline::on_large_stack(|| {
            panic_boundary::catch(|| {
                let mut checked = pipeline::check(
                    entry,
                    &crate::modules::RealFs,
                    CheckOptions {
                        require_main: true,
                        deny_warnings,
                    },
                );
                if dev_panic == DevPanic::Check && checked.program.is_some() {
                    development_check_panic();
                }
                let verb = if running { Verb::Run } else { Verb::Check };
                let sources = Arc::clone(&checked.sources);
                let inspection = if inspecting {
                    checked.program.as_ref().map(inspection::inspect_main)
                } else {
                    None
                };
                if running
                    && checked.error_count() == 0
                    && prelude_error(&checked).is_none()
                    && let (Some(allowed), Some(program)) =
                        (allow_effects, checked.program.as_ref())
                {
                    let contract = inspection::main_contract(program);
                    match contract {
                        Ok(contract) => {
                            if let Some(diagnostic) = effect_limit::check(&contract, allowed) {
                                checked.diagnostics.push(diagnostic);
                            }
                        }
                        Err(error) => checked.diagnostics.push(report::internal_diagnostic(
                            error.stage,
                            &error.message,
                            None,
                            FaultThread::Stage,
                        )),
                    }
                }
                let mut compilation = None;
                if running
                    && checked.error_count() == 0
                    && checked.program.is_some()
                    && prelude_error(&checked).is_none()
                {
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
                    interval_analysis: checked.interval_analysis,
                    program: None,
                };
                PreparedScript {
                    checked: result,
                    compilation,
                    verb,
                    inspection,
                }
            })
        })
    });
    match prepared {
        Ok(Ok(Ok(prepared))) => Ok(prepared),
        Ok(Ok(Err(panic))) => Err(Box::new(report::internal_diagnostic(
            "check",
            &panic.message,
            Some(&panic),
            FaultThread::Stage,
        ))),
        Ok(Err(error)) => Err(Box::new(report::internal_diagnostic(
            "check",
            &error.to_string(),
            None,
            FaultThread::Stage,
        ))),
        Err(panic) => Err(Box::new(report::internal_diagnostic(
            "check",
            &panic.message,
            Some(&panic),
            FaultThread::Main,
        ))),
    }
}

fn execute_script(
    options: Options,
    script: PathBuf,
    args: Option<Vec<OsString>>,
    mut env: CliEnv,
    externals: crate::external::stats::ExecutionOptions,
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
                    FaultThread::Stage,
                );
            }
        }
    }
    let PreparedScript {
        checked,
        compilation: compiled,
        verb,
        inspection: _,
    } = match prepare_script(
        &entry,
        options.deny_warnings,
        running,
        false,
        options.allow_effects.as_ref(),
        env.dev_panic,
    ) {
        Ok(prepared) => prepared,
        Err(diagnostic) => {
            write_report(&env, options.diagnostics, &SourceTable::new(), &diagnostic);
            return EXIT_INTERNAL;
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
                FaultThread::Stage,
            );
        }
        Some(Ok(Err(CompileError::Limit(diags)))) => {
            match options.diagnostics {
                DiagFormat::Text => {
                    let text = render::render_check_text(
                        &diags,
                        &checked.sources,
                        verb,
                        &entry.display_name,
                        TextOptions { color: env.color },
                    );
                    let _result = env.stderr.write_bytes(text.as_bytes());
                }
                DiagFormat::Json => {
                    for diag in &diags {
                        write_report(&env, options.diagnostics, &checked.sources, diag);
                    }
                }
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
                FaultThread::Stage,
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
                FaultThread::Stage,
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
                FaultThread::Stage,
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
                FaultThread::Stage,
            );
        }
    };
    let end = run::run_program_with_externals(
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
        externals,
    );
    write_run_reports(&env, options.diagnostics, &checked.sources, &end);
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

// 最後の転送を終えた RunEnd だけを受け取り、終了理由の後に補足を描画する
// （設計書 06-01「終了状態」）。テストの実行器は捕捉した出力へこの報告を書かない。
fn write_run_reports(env: &CliEnv, format: DiagFormat, sources: &SourceTable, end: &run::RunEnd) {
    if let Some(message) = &end.main_error {
        let _result = env.stderr.write_bytes(format!("{message}\n").as_bytes());
    }
    if end.end == run::EndKind::Exited(run::EXIT_FAILURE)
        && let Some(failure) = &end.die_failure
    {
        write_report(
            env,
            format,
            sources,
            &crate::runtime::report::die_diagnostic(failure),
        );
    }
    for diagnostic in &end.reports {
        write_report(env, format, sources, diagnostic);
    }
}

// 処理系の不具合の報告を確認する開発用の panic に限る（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#[allow(clippy::panic)]
fn development_check_panic() {
    panic!("BENITOITE_DEV_PANIC=check");
}

// 処理系の不具合の報告を確認する開発用の panic に限る（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#[allow(clippy::panic)]
fn development_tool_panic() {
    panic!("BENITOITE_DEV_PANIC=tool");
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
            Some("tool") => DevPanic::Tool,
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
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use std::sync::Mutex;
    use std::sync::atomic::{AtomicUsize, Ordering};

    const HELLO: &str = include_str!("../../testdata/modules/f18_hello.bnt");

    // 関門: 構造化した終了結果から、die を補足より先に一度だけ出す。ソースの die の受理は検査しない。
    #[test]
    fn run_reports_put_the_adopted_die_before_supplementary_failures() {
        use crate::base::{BytePos, Source, SourceKind, Span};
        let mut sources = SourceTable::new();
        let file = sources.add(Source::new(
            "exit.bnt".into(),
            SourceKind::User,
            b"try r or die\n".to_vec(),
        ));
        let die = crate::vm::DieFailure {
            cause: "missing".into(),
            message: Some("read input".into()),
            at: Span {
                file,
                start: BytePos(0),
                end: BytePos(12),
            },
        };
        for format in [DiagFormat::Text, DiagFormat::Json] {
            let (env, out, err) = captured();
            let end = run::RunEnd {
                exit_code: 1,
                end: run::EndKind::Exited(1),
                main_error: None,
                die_failure: Some(die.clone()),
                reports: vec![crate::runtime::report::write_failed(
                    crate::runtime::Stream::Stdout,
                    "broken pipe",
                )],
                heap: Default::default(),
            };
            write_run_reports(&env, format, &sources, &end);
            let output = String::from_utf8(std::mem::take(&mut *err.lock().unwrap())).unwrap();
            match format {
                DiagFormat::Text => {
                    assert_eq!(output.matches("error: explicit failure exit").count(), 1);
                    assert!(
                        output.find("cause: missing").unwrap()
                            < output.find("runtime error[R0201]").unwrap()
                    );
                }
                DiagFormat::Json => {
                    let lines: Vec<serde_json::Value> = output
                        .lines()
                        .map(|line| serde_json::from_str(line).unwrap())
                        .collect();
                    assert_eq!(lines.len(), 2);
                    assert_eq!(lines[0]["kind"], "die");
                    assert_eq!(lines[1]["kind"], "runtime");
                    assert_eq!(lines[1]["code"], "R0201");
                }
            }
            assert_eq!(end.exit_code, 1);
            assert!(out.lock().unwrap().is_empty());
            for end_kind in [
                run::EndKind::Exited(0),
                run::EndKind::Interrupted,
                run::EndKind::Internal,
            ] {
                let other = run::RunEnd {
                    exit_code: 1,
                    end: end_kind,
                    main_error: None,
                    die_failure: Some(die.clone()),
                    reports: Vec::new(),
                    heap: Default::default(),
                };
                write_run_reports(&env, format, &sources, &other);
                assert!(err.lock().unwrap().is_empty());
            }
        }
    }
    struct Directory(PathBuf);
    impl Directory {
        fn new() -> Self {
            // テストのビルドだけの計数器で、処理系の大域の状態ではない。並列のテストが同じ名前のディレクトリを作らないようにする。
            static NEXT: AtomicUsize = AtomicUsize::new(0);
            let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../../target/f18-tests")
                .join(format!(
                    "{}-{}-{}",
                    std::process::id(),
                    NEXT.fetch_add(1, Ordering::Relaxed),
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
            // 巻き戻しの途中で二度目の panic を起こさない。
            let _removed = std::fs::remove_dir_all(&self.0);
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

    // 関門: 使い方の誤りは実行前に拒否し、run のパスの後だけはスクリプトへ渡す。
    // spec: 06-01 オプション
    #[test]
    fn wasm_options_accept_units_and_reject_invalid_ranges() {
        for (value, expected) in [
            ("1048576", 1048576),
            ("1024KiB", 1048576),
            ("64MiB", 67108864),
            ("4GiB", 4294967296),
        ] {
            for command in ["run", "test"] {
                let args = strings(&[
                    command,
                    &format!("--wasm-memory={value}"),
                    &format!("--wasm-transfer={value}"),
                    "--wasm-fuel=18446744073709551615",
                    "--wasm-stats",
                    "a.bnt",
                ]);
                let wasm = if command == "run" {
                    let Command::Run { wasm, .. } = parse_args(args).unwrap() else {
                        panic!("run expected")
                    };
                    wasm
                } else {
                    tools::args::parse_test_invocation(args.into_iter().skip(1).collect())
                        .map_err(|error| error.detail)
                        .unwrap()
                        .1
                };
                assert_eq!(wasm.limits.memory, expected);
                assert_eq!(wasm.limits.transfer, expected);
                assert_eq!(wasm.limits.fuel, u64::MAX);
                assert!(
                    wasm.stats
                        && wasm.memory_overridden
                        && wasm.fuel_overridden
                        && wasm.transfer_overridden
                );
            }
        }
        for option in [
            "--wasm-memory=0",
            "--wasm-memory=1KiB",
            "--wasm-transfer=4294967297",
            "--wasm-memory=5GiB",
            "--wasm-fuel=0",
            "--wasm-fuel=1MiB",
            "--wasm-fuel=-1",
            "--wasm-fuel=+1",
            "--wasm-memory=1mib",
            "--wasm-memory=18446744073709551615GiB",
            "--wasm-fuel=18446744073709551616",
            "--wasm-stats=yes",
            "--wasm-stats=",
            "--wasm-memory",
            "--wasm-memory=",
        ] {
            let error = parse_args(strings(&["run", option, "a.bnt"]))
                .err()
                .unwrap();
            assert!(!error.contains("``"), "{error}");
            if option.starts_with("--wasm-memory") || option.starts_with("--wasm-transfer") {
                assert!(error.contains("1MiB-4GiB"), "{error}");
            } else if option.starts_with("--wasm-fuel") {
                assert!(error.contains("1-18446744073709551615"), "{error}");
            } else if option.starts_with("--wasm-stats=") {
                assert_eq!(error, "`--wasm-stats` does not take a value");
            }
            let test_error = tools::args::parse_test_invocation(strings(&[option, "a.bnt"]))
                .map_err(|error| error.detail)
                .err()
                .unwrap();
            assert_eq!(test_error, error, "{option}");
        }
        assert!(parse_args(strings(&["run", "--wasm-stats", "--wasm-stats", "a.bnt"])).is_err());
        assert!(
            tools::args::parse_test_invocation(strings(&[
                "--wasm-fuel=1",
                "a.bnt",
                "--wasm-fuel=2"
            ]))
            .is_err()
        );
        assert!(parse_args(strings(&["check", "--wasm-stats", "a.bnt"])).is_err());
        assert!(
            tools::args::parse_path_args(
                tools::args::PathTool::Fmt,
                strings(&["--wasm-stats", "a.bnt"])
            )
            .is_err()
        );
        let Command::Run { wasm, args, .. } =
            parse_args(strings(&["a.bnt", "--wasm-fuel=0"])).unwrap()
        else {
            panic!("run expected")
        };
        assert_eq!(wasm, WasmOptions::default());
        assert_eq!(args, strings(&["--wasm-fuel=0"]));
    }

    // 関門: CLI から VM への値の受け渡しと test の起動全体の集計を守る。
    // 外部呼び出しの単体では CLI が既定値へ戻す退行を検出できない。
    // spec: 06-01 オプション
    #[test]
    fn wasm_limits_and_stats_reach_run_and_test() {
        let temp = Directory::new();
        let function_key = format!("{}#f", temp.0.join("x.wasm").display());
        let component = r#"(component (core module $m
            (memory 32) (func (export "f") (result i64) i64.const 7))
            (core instance $i (instantiate $m))
            (func (export "f") (result s64) (canon lift (core func $i "f"))))"#;
        std::fs::write(temp.0.join("x.wasm"), wat::parse_str(component).unwrap()).unwrap();
        let path = temp.0.join("main.bnt");
        let declaration = "@external(\"wasm\", \"x.wasm\", \"f\")\nfunction f() -> Integer\n";
        std::fs::write(&path, format!("{declaration}function main() -> Unit\n  bind value <- f()\n  return ()\nend function\n")).unwrap();
        for (limit, exit) in [("1MiB", EXIT_FAILURE), ("2MiB", EXIT_OK)] {
            let (code, _, err) = call(
                script_args(
                    "run",
                    &path,
                    &[&format!("--wasm-memory={limit}"), "--wasm-stats"],
                ),
                ExecMode::Direct,
                DevPanic::None,
            );
            assert_eq!(code, exit, "{err}");
            let line = err.lines().find(|line| line.starts_with('{')).unwrap();
            let stats: serde_json::Value = serde_json::from_str(line).unwrap();
            assert_eq!(stats["calls"], 1);
            assert_eq!(stats["routes"]["typed"], 1);
            assert_eq!(
                stats["functions"][function_key.as_str()]["routes"]["typed"],
                1
            );
            assert_eq!(stats["construction_bytes"]["total"], 0);
            assert_eq!(stats["construction_bytes"]["incomplete_calls"], 0);
            assert_eq!(stats["fallback_reasons"], serde_json::json!({}));
            assert_eq!(stats["overrides"]["memory"], true);
            if exit == EXIT_FAILURE {
                assert!(err.contains("R0905"));
                assert_eq!(stats["reached_limits"]["memory"], 1);
                assert_eq!(
                    stats["functions"][function_key.as_str()]["reached_limits"]["memory"],
                    1,
                    "{stats}"
                );
            } else {
                assert_eq!(stats["memory"]["total"], 2 * 1024 * 1024);
                assert_eq!(stats["memory"]["maximum"], 2 * 1024 * 1024);
                assert_eq!(stats["fuel"]["total"], 2);
                assert_eq!(stats["results_transfer"]["total"], 0);
            }
        }
        let (code, out, err) = call(
            script_args("run", &path, &["--wasm-memory=2MiB"]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(code, EXIT_OK, "{err}");
        assert!(out.is_empty());
        assert!(err.is_empty());
        for (fuel, expected) in [("1", EXIT_FAILURE), ("100", EXIT_OK)] {
            let (code, _, err) = call(
                script_args(
                    "run",
                    &path,
                    &[&format!("--wasm-fuel={fuel}"), "--wasm-stats"],
                ),
                ExecMode::Direct,
                DevPanic::None,
            );
            assert_eq!(code, expected, "{err}");
            if code == EXIT_FAILURE {
                assert!(err.contains("R0904"));
                let stats: serde_json::Value =
                    serde_json::from_str(err.lines().find(|line| line.starts_with('{')).unwrap())
                        .unwrap();
                assert_eq!(stats["reached_limits"]["fuel"], 1);
                assert_eq!(
                    stats["functions"][function_key.as_str()]["reached_limits"]["fuel"],
                    1
                );
                assert_eq!(stats["fuel"]["total"], 1);
            }
        }
        std::fs::write(&path, format!("{declaration}@test\nfunction first() -> Unit\n  bind value <- f()\n  return ()\nend function\n@test\nfunction second() -> Unit\n  bind value <- f()\n  return ()\nend function\n")).unwrap();
        let (code, _, err) = call(
            script_args("test", &path, &["--wasm-stats", "--wasm-memory=2MiB"]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(code, EXIT_OK, "{err}");
        let lines: Vec<_> = err.lines().filter(|line| line.starts_with('{')).collect();
        assert_eq!(lines.len(), 1);
        let stats: serde_json::Value = serde_json::from_str(lines[0]).unwrap();
        assert_eq!(stats["calls"], 2);
        assert_eq!(stats["routes"]["typed"], 2);
        assert_eq!(stats["functions"][function_key.as_str()]["calls"], 2);
        assert_eq!(stats["memory"]["total"], 4 * 1024 * 1024);
        assert_eq!(stats["memory"]["maximum"], 2 * 1024 * 1024);
        let (code, _, err) = call(
            script_args("test", &path, &["--wasm-memory=1MiB"]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(code, EXIT_FAILURE, "{err}");
        assert!(!err.contains("wasm_stats"));
        let (code, _, err) = call(
            script_args("test", &path, &["--wasm-stats", "--wasm-memory=1MiB"]),
            ExecMode::Direct,
            DevPanic::None,
        );
        assert_eq!(code, EXIT_FAILURE, "{err}");
        let lines: Vec<_> = err.lines().filter(|line| line.starts_with('{')).collect();
        assert_eq!(lines.len(), 1);
        let stats: serde_json::Value = serde_json::from_str(lines[0]).unwrap();
        assert_eq!(stats["calls"], 2);
        assert_eq!(
            stats["functions"][function_key.as_str()]["reached_limits"]["memory"],
            2
        );
        std::fs::write(
            temp.0.join("x.wasm"),
            wat::parse_str(
                r#"(component (core module $m
            (memory (export "memory") 32)
            (func (export "f") (result i32)
                i32.const 0 i32.const 16 i32.store
                i32.const 4 i32.const 1048577 i32.store i32.const 0))
            (core instance $i (instantiate $m)) (type $bytes (list u8))
            (func (export "f") (result $bytes)
                (canon lift (core func $i "f") (memory (core memory $i "memory")))))"#,
            )
            .unwrap(),
        )
        .unwrap();
        std::fs::write(&path, "@external(\"wasm\", \"x.wasm\", \"f\")\nfunction f() -> Bytes\nfunction main() -> Unit\n  bind value <- f()\n  return ()\nend function\n").unwrap();
        for (transfer, expected) in [("1MiB", EXIT_FAILURE), ("2MiB", EXIT_OK)] {
            let (code, _, err) = call(
                script_args(
                    "run",
                    &path,
                    &[&format!("--wasm-transfer={transfer}"), "--wasm-stats"],
                ),
                ExecMode::Direct,
                DevPanic::None,
            );
            assert_eq!(code, expected, "{err}");
            let stats: serde_json::Value =
                serde_json::from_str(err.lines().find(|line| line.starts_with('{')).unwrap())
                    .unwrap();
            if code == EXIT_FAILURE {
                assert!(err.contains("R0905"));
                assert_eq!(stats["reached_limits"]["transfer"], 1);
                assert_eq!(
                    stats["functions"][function_key.as_str()]["reached_limits"]["transfer"],
                    1
                );
                assert_eq!(stats["results_transfer"]["incomplete_calls"], 1);
            } else {
                assert_eq!(stats["results_transfer"]["total"], 1048577);
            }
        }
        // 関門: 公開の補助経路の集計が run/test の指定へ届き、燃料切れを分類する。
        // 内部の補助の試験は CLI のオプションと出力の省略を通らない。
        std::fs::write(
            temp.0.join("x.wasm"),
            wat::parse_str(include_str!("../../testdata/external/adapter-route/x.wat")).unwrap(),
        )
        .unwrap();
        let declaration = "@external(\"wasm\", \"x.wasm\", \"f\")\nfunction f(x: UnsignedInteger32) -> UnsignedInteger32\n";
        for mode in ["run", "test"] {
            let entry = if mode == "run" { "main" } else { "first" };
            let attribute = if mode == "test" { "@test\n" } else { "" };
            std::fs::write(&path, format!("{declaration}{attribute}function {entry}() -> Unit\n  bind value <- f(12u32)\n  return ()\nend function\n")).unwrap();
            for (fuel, expected) in [("1", EXIT_FAILURE), ("100000", EXIT_OK)] {
                for enabled in [true, false] {
                    let fuel_option = format!("--wasm-fuel={fuel}");
                    let options = if enabled {
                        vec![fuel_option.as_str(), "--wasm-stats"]
                    } else {
                        vec![fuel_option.as_str()]
                    };
                    let (code, out, err) = call(
                        script_args(mode, &path, &options),
                        ExecMode::Direct,
                        DevPanic::None,
                    );
                    assert_eq!(code, expected, "{mode}: {err}");
                    if mode == "run" {
                        assert!(out.is_empty(), "{out}");
                    } else if expected == EXIT_OK {
                        assert!(out.contains("1 passed"), "{out}");
                    }
                    if expected == EXIT_FAILURE {
                        assert!(
                            out.contains("R0904") || err.contains("R0904"),
                            "{out}\n{err}"
                        );
                    }
                    let lines: Vec<_> = err.lines().filter(|line| line.starts_with('{')).collect();
                    assert_eq!(lines.len(), usize::from(enabled), "{err}");
                    if !enabled {
                        assert!(!err.contains("wasm_stats"), "{err}");
                        if expected == EXIT_OK {
                            assert!(err.is_empty(), "{err}");
                        }
                        continue;
                    }
                    let stats: serde_json::Value = serde_json::from_str(lines[0]).unwrap();
                    assert_eq!(stats["calls"], 1);
                    assert_eq!(stats["routes"]["adapter"], 1);
                    assert_eq!(
                        stats["functions"][function_key.as_str()]["routes"]["adapter"],
                        1
                    );
                    assert_eq!(stats["fallback_reasons"], serde_json::json!({}));
                    if expected == EXIT_FAILURE {
                        assert_eq!(stats["reached_limits"]["fuel"], 1);
                        assert_eq!(stats["construction_bytes"]["incomplete_calls"], 1);
                    } else {
                        assert_eq!(stats["arguments_transfer"]["total"], 36);
                        assert_eq!(stats["results_transfer"]["total"], 36);
                        assert_eq!(stats["construction_bytes"]["total"], 32);
                        assert_eq!(stats["construction_bytes"]["incomplete_calls"], 0);
                    }
                }
            }
        }
        for (name, guest) in [
            (
                "post-return",
                include_str!("../../testdata/external/adapter-lifetime/post-return.wat"),
            ),
            (
                "utf16",
                include_str!("../../testdata/external/adapter-lifetime/utf16.wat"),
            ),
        ] {
            std::fs::write(
                temp.0.join(format!("{name}.wasm")),
                wat::parse_str(guest).unwrap(),
            )
            .unwrap();
        }
        // 同じ期待値のゴールデンと違い、ここでは宣言ごとの経路が統計に反映されることを確かめる。
        for (script, expected, typed, adapter) in [
            (
                include_str!("../../testdata/external/adapter-route/main.bnt"),
                include_str!("../../testdata/external/adapter-route.stdout"),
                1,
                4,
            ),
            (
                include_str!("../../testdata/external/adapter-lifetime/main.bnt"),
                include_str!("../../testdata/external/adapter-lifetime.stdout"),
                0,
                5,
            ),
        ] {
            std::fs::write(&path, script).unwrap();
            let (code, out, err) = call(
                script_args("run", &path, &["--wasm-stats"]),
                ExecMode::Direct,
                DevPanic::None,
            );
            assert_eq!(code, EXIT_OK, "{err}");
            assert_eq!(out, expected);
            let stats: serde_json::Value = serde_json::from_str(err.trim()).unwrap();
            assert_eq!(stats["calls"], typed + adapter);
            assert_eq!(stats["routes"]["typed"].as_u64().unwrap_or(0), typed);
            assert_eq!(stats["routes"]["adapter"], adapter);
            assert_eq!(stats["construction_bytes"]["incomplete_calls"], 0);
        }
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
                args: strings(&["--x", "y"]),
                wasm: WasmOptions::default()
            }
        );
        assert_eq!(
            parse_args(strings(&[
                "a.bnt",
                "--allow-effects",
                "State",
                "--allow-effects="
            ]))
            .unwrap(),
            Command::Run {
                options: Options::default(),
                script: "a.bnt".into(),
                args: strings(&["--allow-effects", "State", "--allow-effects="]),
                wasm: WasmOptions::default(),
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
        assert_eq!(
            parse_args(strings(&["package", "add", "Text", "--path", "deps/text"])).unwrap(),
            Command::Tool {
                tool: ToolCommand::Package,
                args: strings(&["add", "Text", "--path", "deps/text"]),
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
        // check_files では埋め込んだソースを差し替えられないので、判定を直接呼ぶ。
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
            interval_analysis: Default::default(),
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
        // 原型の中の定数の上限の近くまで並べる。
        // 引数を一つ混ぜ、リスト全体を単一の定数へ畳ませない。
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
        assert!(
            err.lines()
                .last()
                .unwrap()
                .ends_with("due to 1 previous error"),
            "{err}"
        );
    }
}
