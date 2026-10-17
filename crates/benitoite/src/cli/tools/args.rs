//! `test` と `fmt` のコマンドラインの解釈（設計書 06-01「`test` のコマンドライン（初回リリース版）」
//! 「`fmt` のコマンドライン（初回リリース版）」「オプション」）。

use std::path::PathBuf;

use crate::cli::DiagFormat;

/// パスを受け取る補助のコマンド（設計書 06-01「サブコマンドの振る舞い」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PathTool {
    Test,
    Fmt,
}

/// 解釈した `test`・`fmt` のコマンドライン。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct PathArgs {
    pub diagnostics: DiagFormat,
    /// 非実行の検査を単一 JSON で報告する（`test` だけ）
    pub report: Option<crate::cli::ReportFormat>,
    /// 実行前に照合する原子的なエフェクトの上限（`test` だけ）
    pub allow_effects: Option<crate::cli::EffectLimit>,
    /// `--max-call-stack` の値（バイト。`test` だけ）。指定がなければ `None`
    pub max_call_stack: Option<u64>,
    /// `--deny-warnings`（`test` だけ）
    pub deny_warnings: bool,
    /// `--check`（`test` は非実行の検査、`fmt` は変更の有無の確認）
    pub check: bool,
    /// 与えた順のパス（一つ以上）
    pub paths: Vec<PathBuf>,
}

/// 使い方の誤りの文（設計書 02-10「文言の言語」）。ほかの誤りの文は `cli::text` を使う。
pub mod text {
    /// 報告は非実行の検査でだけ受ける
    pub const REPORT_REQUIRES_CHECK: &str = "`--report=json` requires `test --check`";
    /// パスが一つもない
    pub const MISSING_PATH: &str = "missing path";
    /// そのサブコマンドが受け付けないオプション。`{name}` はオプション、`{command}` はサブコマンドの名前
    pub const OPTION_NOT_FOR_COMMAND: &str = "option `{name}` is not accepted by `{command}`";
    /// テストを実行するときだけ意味を持つオプション
    pub const OPTION_NOT_FOR_CHECK: &str = "option `{name}` is not accepted with `test --check`";
}

use std::ffi::OsString;
use std::path::Path;

use crate::cli::parse_size;
use crate::cli::text as cli_text;

/// `benitoite test|fmt` の後の引数を解釈する。
/// 使い方の誤りは、`cli::text::USAGE_ERROR` の `{detail}` に埋める 1 行を返す。
pub fn parse_path_args(tool: PathTool, args: Vec<OsString>) -> Result<PathArgs, String> {
    if tool == PathTool::Test {
        // WasmOptions を返さない入口では、指定を受け付けて捨てない。
        return parse_test_options(args, false)
            .map(|(parsed, _)| parsed)
            .map_err(|error| error.detail);
    }
    let mut parsed = PathArgs {
        diagnostics: DiagFormat::Text,
        report: None,
        allow_effects: None,
        max_call_stack: None,
        deny_warnings: false,
        check: false,
        paths: Vec::new(),
    };
    let mut seen: Vec<String> = Vec::new();
    for arg in args {
        let value = arg.to_string_lossy().into_owned();
        // `-` で始まる引数はすべてオプションとして読む（設計書 06-01「コマンドラインの形」）。
        if !value.starts_with('-') {
            parsed.paths.push(PathBuf::from(arg));
            continue;
        }
        let (name, setting) = value
            .split_once('=')
            .map_or((value.as_str(), None), |(n, v)| (n, Some(v)));
        let accepted = ["--diagnostics", "--check"];
        if !accepted.contains(&name) {
            return Err(
                if matches!(
                    name,
                    "--diagnostics"
                        | "--max-call-stack"
                        | "--deny-warnings"
                        | "--check"
                        | "--report"
                        | "--allow-effects"
                ) {
                    text::OPTION_NOT_FOR_COMMAND
                        .replace("{name}", name)
                        .replace("{command}", "fmt")
                } else {
                    cli_text::UNKNOWN_OPTION.replace("{name}", &value)
                },
            );
        }
        if seen.iter().any(|s| s == name) {
            return Err(cli_text::DUPLICATE_OPTION.replace("{name}", name));
        }
        seen.push(name.to_owned());
        match (name, setting) {
            ("--diagnostics", Some("text")) => parsed.diagnostics = DiagFormat::Text,
            ("--diagnostics", Some("json")) => parsed.diagnostics = DiagFormat::Json,
            ("--check", None) => parsed.check = true,
            _ => {
                return Err(cli_text::BAD_VALUE
                    .replace("{name}", name)
                    .replace("{value}", setting.unwrap_or("")));
            }
        }
    }
    if parsed.paths.is_empty() {
        return Err(text::MISSING_PATH.to_owned());
    }
    Ok(parsed)
}

/// ディレクトリの下のすべての `.bnt` のファイルを、パスの辞書順に並べて返す（06-01「ディレクトリの指定（初回リリース版）」）。
/// シンボリックリンクは辿らず、返す並びにも含めない。読めないディレクトリがあれば、そのパスと理由を返す。
pub fn bnt_files(dir: &Path) -> Result<Vec<PathBuf>, (PathBuf, std::io::Error)> {
    collect_bnt_files(dir, false)
}

/// テストでは下位のパッケージと設定ファイルを除き、整形ではすべて集める。
pub(super) fn collect_bnt_files(
    root: &Path,
    skip_packages: bool,
) -> Result<Vec<PathBuf>, (PathBuf, std::io::Error)> {
    // 深いディレクトリでも Rust のスタックを増やさない（AGENTS.md「再帰の深さ」）。
    let mut files = Vec::new();
    let mut pending = vec![root.to_path_buf()];
    while let Some(current) = pending.pop() {
        let entries = std::fs::read_dir(&current).map_err(|error| (current.clone(), error))?;
        let mut children = Vec::new();
        let mut package = false;
        for entry in entries {
            let entry = entry.map_err(|error| (current.clone(), error))?;
            let path = entry.path();
            // リンクは辿らず集めない。設定の有無の判定にはリンクの項目も使う（設計書 06-01）。
            let kind = entry.file_type().map_err(|error| (path.clone(), error))?;
            let config = entry.file_name() == crate::modules::package::CONFIG_NAME;
            package |= config && !kind.is_dir();
            if kind.is_dir() {
                children.push((path, true));
            } else if kind.is_file()
                && path.extension().is_some_and(|ext| ext == "bnt")
                && !(skip_packages && config)
            {
                children.push((path, false));
            }
        }
        if skip_packages && current != root && package {
            continue;
        }
        for (path, is_dir) in children {
            if is_dir {
                pending.push(path);
            } else {
                files.push(path);
            }
        }
    }
    files.sort();
    Ok(files)
}

#[cfg(test)]
mod tests;

/// 誤りの後も走査して認識した報告モードと指定パス。
pub(in crate::cli) struct TestParseError {
    pub detail: String,
    pub report: Option<crate::cli::ReportFormat>,
    pub paths: Vec<PathBuf>,
}

/// 全オプションの範囲を走査してから報告の形式を確定する。
pub(in crate::cli) fn parse_test_invocation(
    args: Vec<OsString>,
) -> Result<(PathArgs, crate::cli::WasmOptions), TestParseError> {
    parse_test_options(args, true)
}

fn parse_test_options(
    args: Vec<OsString>,
    accept_wasm: bool,
) -> Result<(PathArgs, crate::cli::WasmOptions), TestParseError> {
    let mut parsed = PathArgs {
        diagnostics: DiagFormat::Text,
        report: None,
        allow_effects: None,
        max_call_stack: None,
        deny_warnings: false,
        check: false,
        paths: Vec::new(),
    };
    let mut wasm = crate::cli::WasmOptions::default();
    let mut seen = std::collections::BTreeSet::new();
    let mut detail = None;
    let mut report = None;
    let mut remaining = args.into_iter();
    while let Some(arg) = remaining.next() {
        let value = arg.to_string_lossy();
        if !value.starts_with('-') {
            parsed.paths.push(PathBuf::from(arg));
            continue;
        }
        let (name, setting) = value
            .split_once('=')
            .map_or((value.as_ref(), None), |(n, v)| (n, Some(v)));
        let separate = if setting.is_none() && crate::cli::takes_option_value(name) {
            remaining.next()
        } else {
            None
        };
        if name == "--report" && setting == Some("json") {
            report = Some(crate::cli::ReportFormat::Json);
        }
        let result = (|| {
            if !matches!(
                name,
                "--diagnostics"
                    | "--report"
                    | "--max-call-stack"
                    | "--deny-warnings"
                    | "--check"
                    | "--allow-effects"
            ) && !(accept_wasm && crate::cli::WasmOptions::accepts(name))
            {
                return Err(cli_text::UNKNOWN_OPTION.replace("{name}", &value));
            }
            if !seen.insert(name.to_owned()) {
                return Err(cli_text::DUPLICATE_OPTION.replace("{name}", name));
            }
            if crate::cli::WasmOptions::accepts(name) {
                return wasm.parse(name, setting);
            }
            match (name, setting) {
                ("--diagnostics", Some("text")) => parsed.diagnostics = DiagFormat::Text,
                ("--diagnostics", Some("json")) => parsed.diagnostics = DiagFormat::Json,
                ("--report", Some("json")) => parsed.report = Some(crate::cli::ReportFormat::Json),
                ("--max-call-stack", Some(size)) if parse_size(size).is_some() => {
                    parsed.max_call_stack = parse_size(size)
                }
                ("--deny-warnings", None) => parsed.deny_warnings = true,
                ("--check", None) => parsed.check = true,
                ("--allow-effects", setting) => {
                    let separate = separate.as_ref().map(|value| value.to_string_lossy());
                    let setting = setting
                        .or(separate.as_deref())
                        .ok_or_else(|| cli_text::MISSING_OPTION_VALUE.replace("{name}", name))?;
                    parsed.allow_effects = Some(crate::cli::effect_limit::parse(setting)?);
                }
                _ => {
                    return Err(cli_text::BAD_VALUE
                        .replace("{name}", name)
                        .replace("{value}", setting.unwrap_or("")));
                }
            }
            Ok(())
        })();
        if let Err(error) = result {
            detail.get_or_insert(error);
        }
    }
    if parsed.report.is_some() && !parsed.check {
        detail.get_or_insert_with(|| text::REPORT_REQUIRES_CHECK.into());
    }
    if parsed.report.is_some()
        && seen.contains("--diagnostics")
        && parsed.diagnostics == DiagFormat::Text
    {
        detail.get_or_insert_with(|| cli_text::REPORT_TEXT_DIAGNOSTICS.into());
    }
    if parsed.check {
        let execution = if parsed.max_call_stack.is_some() {
            Some("--max-call-stack")
        } else {
            seen.iter()
                .find(|name| crate::cli::WasmOptions::accepts(name))
                .map(String::as_str)
        };
        if let Some(name) = execution {
            detail.get_or_insert_with(|| text::OPTION_NOT_FOR_CHECK.replace("{name}", name));
        }
        if seen.contains("--allow-effects") {
            detail.get_or_insert_with(|| {
                text::OPTION_NOT_FOR_CHECK.replace("{name}", "--allow-effects")
            });
        }
    }
    if parsed.paths.is_empty() {
        detail.get_or_insert_with(|| text::MISSING_PATH.into());
    }
    if let Some(detail) = detail {
        Err(TestParseError {
            detail,
            report,
            paths: parsed.paths,
        })
    } else {
        Ok((parsed, wasm))
    }
}
