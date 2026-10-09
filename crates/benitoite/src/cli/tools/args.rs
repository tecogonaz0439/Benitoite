//! `test` と `fmt` のコマンドラインの解釈（設計書 06-01「`test` のコマンドライン（初回リリース版）」
//! 「`fmt` のコマンドライン（初回リリース版）」「オプション」、ADR 0206・0207）。

use std::path::PathBuf;

use crate::cli::DiagFormat;

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

/// 使い方の誤りの文（ADR 0033）。ほかの誤りの文は 10-13 の `cli::text` を使う。
pub mod text {
    /// パスが一つもない
    pub const MISSING_PATH: &str = "missing path";
    /// そのサブコマンドが受け付けないオプション。`{name}` はオプション、`{command}` はサブコマンドの名前
    pub const OPTION_NOT_FOR_COMMAND: &str = "option `{name}` is not accepted by `{command}`";
}

use std::ffi::OsString;
use std::path::Path;

use crate::cli::text as cli_text;
use crate::cli::{ToolCommand, parse_size};

/// `benitoite test|fmt` の後の引数を解釈する。`tool` は `Test` か `Fmt`（`skill` は CLI からこの関数を通らない）。
/// 使い方の誤りは、10-13 の `cli::text::USAGE_ERROR` の `{detail}` に埋める 1 行を返す。
pub fn parse_path_args(tool: ToolCommand, args: Vec<OsString>) -> Result<PathArgs, String> {
    let command = match tool {
        ToolCommand::Test => "test",
        ToolCommand::Fmt => "fmt",
        // `skill` はこの関数を使わない（作業 D03 の手順 1）。名前だけを与え、同じ規則で解釈する。
        ToolCommand::Skill => "skill",
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
        // `-` で始まる引数はすべてオプションとして読む（10-17「`test` と `fmt` のコマンドライン」）。
        if !value.starts_with('-') {
            parsed.paths.push(PathBuf::from(arg));
            continue;
        }
        let (name, setting) = value
            .split_once('=')
            .map_or((value.as_str(), None), |(n, v)| (n, Some(v)));
        let accepted: &[&str] = match tool {
            ToolCommand::Fmt => &["--diagnostics", "--check"],
            ToolCommand::Test | ToolCommand::Skill => {
                &["--diagnostics", "--max-call-stack", "--deny-warnings"]
            }
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

/// ディレクトリの下のすべての `.bnt` のファイルを、パスの辞書順に並べて返す（06-01「ディレクトリの指定」）。
/// シンボリックリンクは辿らず、返す並びにも含めない。読めないディレクトリがあれば、そのパスと理由を返す。
pub fn bnt_files(dir: &Path) -> Result<Vec<PathBuf>, (PathBuf, std::io::Error)> {
    // 実行時の入れ子の深さに依らないよう、明示の積み重ねで辿る（00-02「再帰の深さ」）。
    let mut files = Vec::new();
    let mut pending = vec![dir.to_path_buf()];
    while let Some(current) = pending.pop() {
        let entries = std::fs::read_dir(&current).map_err(|e| (current.clone(), e))?;
        for entry in entries {
            let entry = entry.map_err(|e| (current.clone(), e))?;
            let path = entry.path();
            // シンボリックリンクは辿らず集めない（ADR 0327）。`symlink_metadata` はリンクそのものを見る。
            let metadata = std::fs::symlink_metadata(&path).map_err(|e| (path.clone(), e))?;
            let file_type = metadata.file_type();
            if file_type.is_dir() {
                pending.push(path);
            } else if file_type.is_file() && path.extension().is_some_and(|ext| ext == "bnt") {
                files.push(path);
            }
        }
    }
    files.sort();
    Ok(files)
}

#[cfg(test)]
mod tests;
