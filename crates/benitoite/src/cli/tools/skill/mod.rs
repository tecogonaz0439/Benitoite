//! 同梱の Agent Skill の埋め込みと、`benitoite skill install`・`uninstall`（設計書 06-06「同梱の Agent Skill の構成」
//! 「Skill の導入（初回リリース版）」、06-01「`skill` のコマンドライン（初回リリース版）」、ADR 0229・0230・0288）。

pub mod bundle;
pub mod generate;

/// Skill の名前（書き出す先のディレクトリの名前。06-06、ADR 0241）。
pub const SKILL_NAME: &str = "benitoite";
/// `SKILL.md` の前付けの `metadata` の、処理系の版の欄の名前。この欄があれば `install` が書き出したものとみなす
pub const VERSION_KEY: &str = "benitoite-version";
/// リポジトリの `SKILL.md` の版の型板。`install` が処理系の版で置き換える
pub const VERSION_PLACEHOLDER: &str = "{{benitoite-version}}";

/// 埋め込んだファイル一つ。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct SkillFile {
    /// Skill の中のパス（`SKILL.md`、`references/grammar.md` など）
    pub path: &'static str,
    pub text: &'static str,
}

/// 書き出す先の単位（06-06「Skill の導入（初回リリース版）」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Scope {
    User,
    Project,
}

/// `--agent` の名前。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Agent {
    ClaudeCode,
    Codex,
    OpenCode,
}

/// 文（ADR 0033）。`{名前}` は埋める値。
pub mod text {
    pub const INSTALLED: &str = "installed {path}";
    pub const REMOVED: &str = "removed {path}";
    pub const NOT_OURS: &str =
        "error: `{path}` was not written by `benitoite skill install`; it was left unchanged";
    pub const WRITE_FAILED: &str = "error: cannot write `{path}`: {reason}";
    pub const REMOVE_FAILED: &str = "error: cannot remove `{path}`: {reason}";
    pub const NO_HOME: &str =
        "error: cannot find the home directory; set `HOME` or use `--project`";
    /// 使い方の誤りの `{detail}` に埋める文
    pub const MISSING_ACTION: &str = "missing `install` or `uninstall`";
    pub const UNKNOWN_AGENT: &str =
        "unknown agent `{name}`; expected `claude-code`, `codex`, or `opencode`";
    pub const USER_AND_PROJECT: &str = "`--user` and `--project` cannot be used together";
}

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use crate::cli::CliEnv;

/// 埋め込んだ Skill のファイル（`bundle::FILES`）。`SKILL.md` は版の型板を置き換える前の形である。
pub fn files() -> &'static [SkillFile] {
    bundle::FILES
}

/// 書き出す先の Skill のディレクトリ（`<base>/.claude/skills/benitoite` など）を、重複を除いて返す。
/// `agents` が空なら、すべてのエージェントとする。`base` は、`User` ではホームのディレクトリ、`Project` では作業ディレクトリ。
pub fn target_dirs(scope: Scope, agents: &[Agent], base: &Path) -> Vec<PathBuf> {
    // 置き場所の相対パスは、ホームと作業ディレクトリのどちらを基準にしても同じである（06-06「Skill の導入」）
    let _ignored = scope;
    let all = [Agent::ClaudeCode, Agent::Codex, Agent::OpenCode];
    let chosen: &[Agent] = if agents.is_empty() { &all } else { agents };
    let mut dirs: Vec<PathBuf> = Vec::new();
    for agent in chosen {
        let dir = base.join(agent_parent(*agent)).join(SKILL_NAME);
        if !dirs.contains(&dir) {
            dirs.push(dir);
        }
    }
    dirs
}

/// エージェントごとの Skill の置き場所の親（06-06 の表）。
fn agent_parent(agent: Agent) -> &'static str {
    match agent {
        Agent::ClaudeCode => ".claude/skills",
        Agent::Codex | Agent::OpenCode => ".agents/skills",
    }
}

/// Skill を `dir` に書き出す（本章「`skill install`・`uninstall`」）。`version` で `SKILL.md` の版の型板を置き換える。
/// 失敗したら、`env.stderr` に書く誤りの文（`text` の型板を埋めたもの）を返す。
pub fn install_dir(dir: &Path, version: &str) -> Result<(), String> {
    let parent = dir
        .parent()
        .ok_or_else(|| write_failed(dir, "no parent directory"))?;
    std::fs::create_dir_all(parent).map_err(|error| write_failed(parent, &error.to_string()))?;
    let exists = match std::fs::symlink_metadata(dir) {
        Ok(_) => true,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => false,
        Err(error) => return Err(write_failed(dir, &error.to_string())),
    };
    if exists && !is_ours(dir) {
        return Err(not_ours(dir));
    }
    let pid = std::process::id();
    let temp = parent.join(format!(".{SKILL_NAME}.install-{pid}"));
    // 前の実行が残した同じ名前の一時ディレクトリは、このプロセスのものではないので消してから使う
    let _ignored = std::fs::remove_dir_all(&temp);
    if let Err(reason) = write_files(&temp, version) {
        let _ignored = std::fs::remove_dir_all(&temp);
        return Err(write_failed(dir, &reason));
    }
    if !exists {
        return std::fs::rename(&temp, dir).map_err(|error| {
            let _ignored = std::fs::remove_dir_all(&temp);
            write_failed(dir, &error.to_string())
        });
    }
    // 置き換え: 古いものを退け、新しいものを据え、古いものを消す。新しいものの名前を据える前の段で失敗したら
    // 元に戻す。据えた後は置き換えが済んだものとし、古いものを消しきれなくても新しいものを残す（10-19）
    let old = parent.join(format!(".{SKILL_NAME}.old-{pid}"));
    let _ignored = std::fs::remove_dir_all(&old);
    if let Err(error) = std::fs::rename(dir, &old) {
        let _ignored = std::fs::remove_dir_all(&temp);
        return Err(write_failed(dir, &error.to_string()));
    }
    if let Err(error) = std::fs::rename(&temp, dir) {
        let _ignored = std::fs::rename(&old, dir);
        let _ignored = std::fs::remove_dir_all(&temp);
        return Err(write_failed(dir, &error.to_string()));
    }
    if let Err(error) = std::fs::remove_dir_all(&old) {
        // 一部が消えた古いものを戻すと壊れた Skill になるので、完全な新しいものを残し、名残のパスを示す
        return Err(remove_failed(&old, &error.to_string()));
    }
    Ok(())
}

/// 一時ディレクトリ `temp` に、埋め込んだすべてのファイルを書く。失敗したら理由を返す。
fn write_files(temp: &Path, version: &str) -> Result<(), String> {
    std::fs::create_dir(temp).map_err(|error| error.to_string())?;
    for file in files() {
        let path = temp.join(file.path);
        if let Some(sub) = path.parent() {
            std::fs::create_dir_all(sub).map_err(|error| error.to_string())?;
        }
        let written = if file.path == "SKILL.md" {
            std::fs::write(&path, file.text.replace(VERSION_PLACEHOLDER, version))
        } else {
            std::fs::write(&path, file.text)
        };
        written.map_err(|error| error.to_string())?;
    }
    Ok(())
}

/// `dir` が `install` の書き出したものか。`SKILL.md` の前付けの `metadata:` の下に `benitoite-version:` の行があるかで
/// 判定する（前付けを YAML として解析するクレートは加えない。00-02「依存するクレート」）。
fn is_ours(dir: &Path) -> bool {
    let Ok(metadata) = std::fs::symlink_metadata(dir) else {
        return false;
    };
    if !metadata.is_dir() {
        return false;
    }
    let Ok(skill) = std::fs::read_to_string(dir.join("SKILL.md")) else {
        return false;
    };
    has_version_key(&skill)
}

/// 前付け（先頭の `---` と次の `---` の間）の `metadata:` の下に、版の欄の行があるか。
fn has_version_key(skill: &str) -> bool {
    let mut lines = skill.lines();
    if lines.next().map(str::trim_end) != Some("---") {
        return false;
    }
    let mut in_metadata = false;
    for line in lines {
        let trimmed = line.trim_end();
        if trimmed == "---" {
            return false;
        }
        if trimmed.is_empty() {
            continue;
        }
        let indented = line.starts_with(' ') || line.starts_with('\t');
        if !indented {
            in_metadata = trimmed == "metadata:";
        } else if in_metadata
            && trimmed
                .trim_start()
                .strip_prefix(VERSION_KEY)
                .is_some_and(|rest| rest.starts_with(':'))
        {
            return true;
        }
    }
    false
}

fn write_failed(path: &Path, reason: &str) -> String {
    text::WRITE_FAILED
        .replace("{path}", &path.display().to_string())
        .replace("{reason}", reason)
}

fn not_ours(path: &Path) -> String {
    text::NOT_OURS.replace("{path}", &path.display().to_string())
}

/// `dir` の Skill を消す。消したら `Ok(true)`、なければ `Ok(false)`。`install` の書き出したものでなければ誤りの文を返す。
pub fn uninstall_dir(dir: &Path) -> Result<bool, String> {
    match std::fs::symlink_metadata(dir) {
        Ok(_) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(false),
        Err(error) => return Err(remove_failed(dir, &error.to_string())),
    }
    if !is_ours(dir) {
        return Err(not_ours(dir));
    }
    std::fs::remove_dir_all(dir).map_err(|error| remove_failed(dir, &error.to_string()))?;
    Ok(true)
}

fn remove_failed(path: &Path, reason: &str) -> String {
    text::REMOVE_FAILED
        .replace("{path}", &path.display().to_string())
        .replace("{reason}", reason)
}

/// `skill` の後の引数を解釈した結果。
#[derive(Debug, PartialEq, Eq)]
struct SkillArgs {
    install: bool,
    scope: Scope,
    agents: Vec<Agent>,
}

/// `skill` の後の引数を解釈する。使い方の誤りは、`cli::text::USAGE_ERROR` の `{detail}` に埋める 1 行を返す。
fn parse_skill_args(args: Vec<OsString>) -> Result<SkillArgs, String> {
    use crate::cli::text as cli_text;
    let mut action: Option<bool> = None;
    let mut user = false;
    let mut project = false;
    let mut agents: Vec<Agent> = Vec::new();
    let mut iter = args.into_iter();
    while let Some(arg) = iter.next() {
        let arg = arg.to_string_lossy().into_owned();
        let agent_name = if arg == "--agent" {
            match iter.next() {
                Some(value) => Some(value.to_string_lossy().into_owned()),
                None => {
                    return Err(cli_text::BAD_VALUE
                        .replace("{value}", "")
                        .replace("{name}", "--agent"));
                }
            }
        } else {
            arg.strip_prefix("--agent=").map(str::to_owned)
        };
        if let Some(name) = agent_name {
            let agent = match name.as_str() {
                "claude-code" => Agent::ClaudeCode,
                "codex" => Agent::Codex,
                "opencode" => Agent::OpenCode,
                _ => return Err(text::UNKNOWN_AGENT.replace("{name}", &name)),
            };
            if agents.contains(&agent) {
                return Err(cli_text::DUPLICATE_OPTION.replace("{name}", "--agent"));
            }
            agents.push(agent);
            continue;
        }
        match arg.as_str() {
            "--user" | "--project" => {
                let flag = if arg == "--user" {
                    &mut user
                } else {
                    &mut project
                };
                if *flag {
                    return Err(cli_text::DUPLICATE_OPTION.replace("{name}", &arg));
                }
                *flag = true;
            }
            "install" | "uninstall" if action.is_none() => action = Some(arg == "install"),
            _ if arg.starts_with('-') => {
                return Err(cli_text::UNKNOWN_OPTION.replace("{name}", &arg));
            }
            _ => return Err(cli_text::EXTRA_ARGUMENT.replace("{value}", &arg)),
        }
    }
    if user && project {
        return Err(text::USER_AND_PROJECT.to_owned());
    }
    let install = action.ok_or_else(|| text::MISSING_ACTION.to_owned())?;
    let scope = if project { Scope::Project } else { Scope::User };
    Ok(SkillArgs {
        install,
        scope,
        agents,
    })
}

/// `benitoite skill` の後の引数を解釈して実行し、終了状態を返す（06-01「`skill` のコマンドライン（初回リリース版）」）。
/// `home` は利用者のホームのディレクトリ（`run_tool` が環境変数 `HOME` から求める）。
pub fn run_skill(args: Vec<OsString>, env: CliEnv, home: Option<PathBuf>) -> u8 {
    use crate::runtime::run::{EXIT_FAILURE, EXIT_OK};
    let parsed = match parse_skill_args(args) {
        Ok(parsed) => parsed,
        Err(detail) => return crate::cli::usage_error(&env, &detail),
    };
    let base = match parsed.scope {
        Scope::Project => env.working_directory.clone(),
        Scope::User => match home {
            Some(home) => home,
            None => {
                let _ignored = env
                    .stderr
                    .write_bytes(format!("{}\n", text::NO_HOME).as_bytes());
                return EXIT_FAILURE;
            }
        },
    };
    let mut exit = EXIT_OK;
    for dir in target_dirs(parsed.scope, &parsed.agents, &base) {
        let path = dir.display().to_string();
        let result = if parsed.install {
            install_dir(&dir, env!("CARGO_PKG_VERSION"))
                .map(|()| Some(text::INSTALLED.replace("{path}", &path)))
        } else {
            uninstall_dir(&dir)
                .map(|removed| removed.then(|| text::REMOVED.replace("{path}", &path)))
        };
        match result {
            Ok(Some(line)) => {
                let _ignored = env.stdout.write_bytes(format!("{line}\n").as_bytes());
            }
            Ok(None) => {}
            Err(message) => {
                let _ignored = env.stderr.write_bytes(format!("{message}\n").as_bytes());
                exit = EXIT_FAILURE;
            }
        }
    }
    exit
}

#[cfg(test)]
mod tests;
