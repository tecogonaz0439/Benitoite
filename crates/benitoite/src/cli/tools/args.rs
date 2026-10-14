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
    /// `--max-call-stack` の値（バイト。`test` だけ）。指定がなければ `None`
    pub max_call_stack: Option<u64>,
    /// `--deny-warnings`（`test` だけ）
    pub deny_warnings: bool,
    /// `--check`（`fmt` だけ）
    pub check: bool,
    /// 与えた順のパス（一つ以上）
    pub paths: Vec<PathBuf>,
}

/// 使い方の誤りの文（設計書 02-10「文言の言語」）。ほかの誤りの文は `cli::text` を使う。
pub mod text {
    /// パスが一つもない
    pub const MISSING_PATH: &str = "missing path";
    /// そのサブコマンドが受け付けないオプション。`{name}` はオプション、`{command}` はサブコマンドの名前
    pub const OPTION_NOT_FOR_COMMAND: &str = "option `{name}` is not accepted by `{command}`";
}

use std::ffi::OsString;
use std::path::Path;

use crate::cli::parse_size;
use crate::cli::text as cli_text;

/// `benitoite test|fmt` の後の引数を解釈する。
/// 使い方の誤りは、`cli::text::USAGE_ERROR` の `{detail}` に埋める 1 行を返す。
pub fn parse_path_args(tool: PathTool, args: Vec<OsString>) -> Result<PathArgs, String> {
    let command = match tool {
        PathTool::Test => "test",
        PathTool::Fmt => "fmt",
    };
    let mut parsed = PathArgs {
        diagnostics: DiagFormat::Text,
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
        let accepted: &[&str] = match tool {
            PathTool::Fmt => &["--diagnostics", "--check"],
            PathTool::Test => &["--diagnostics", "--max-call-stack", "--deny-warnings"],
        };
        if !accepted.contains(&name) {
            return Err(
                if matches!(
                    name,
                    "--diagnostics" | "--max-call-stack" | "--deny-warnings" | "--check"
                ) {
                    text::OPTION_NOT_FOR_COMMAND
                        .replace("{name}", name)
                        .replace("{command}", command)
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
            ("--max-call-stack", Some(size)) if parse_size(size).is_some() => {
                parsed.max_call_stack = parse_size(size);
            }
            ("--deny-warnings", None) => parsed.deny_warnings = true,
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

// PathArgs の契約を保ち、外部呼び出しの設定だけを別に返す。
pub(in crate::cli) fn parse_test_args(
    args: Vec<OsString>,
) -> Result<(PathArgs, crate::cli::WasmOptions), String> {
    let mut remaining = Vec::new();
    let mut wasm = crate::cli::WasmOptions::default();
    let mut seen = std::collections::BTreeSet::new();
    for arg in args {
        let value = arg.to_string_lossy();
        let (name, setting) = value
            .split_once('=')
            .map_or((value.as_ref(), None), |(n, v)| (n, Some(v)));
        if crate::cli::WasmOptions::accepts(name) {
            if !seen.insert(name.to_owned()) {
                return Err(cli_text::DUPLICATE_OPTION.replace("{name}", name));
            }
            wasm.parse(name, setting)?;
        } else {
            remaining.push(arg);
        }
    }
    Ok((parse_path_args(PathTool::Test, remaining)?, wasm))
}
