//! ビルド時の入力を検証し、commit とその由来を埋め込む（設計書 05-01「ソースからのビルド」）。

use std::{
    env,
    path::Path,
    process::{Command, ExitCode},
};

mod text {
    pub const COMMIT_INPUT: &str = "BENITOITE_BUILD_COMMIT";
    pub const DIRTY_INPUT: &str = "BENITOITE_BUILD_DIRTY";
    pub const COMMIT_SYNTAX: &str = "expected 40 or 64 ASCII hexadecimal digits, or unknown";
    pub const DIRTY_SYNTAX: &str = "expected true, false, or unknown";
    pub const TARGET_ERROR: &str = "TARGET must be a nonempty UTF-8 string without line breaks";
    pub const INVALID_INPUT: &str = "invalid build input";
}

fn main() -> ExitCode {
    println!("cargo::rerun-if-changed=build.rs");
    println!("cargo::rerun-if-env-changed={}", text::COMMIT_INPUT);
    println!("cargo::rerun-if-env-changed={}", text::DIRTY_INPUT);
    match embed() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{}: {message}", text::INVALID_INPUT);
            ExitCode::FAILURE
        }
    }
}

fn embed() -> Result<(), String> {
    let commit_input = input(text::COMMIT_INPUT, text::COMMIT_SYNTAX)?;
    let dirty_input = input(text::DIRTY_INPUT, text::DIRTY_SYNTAX)?;
    let commit = match commit_input.as_deref() {
        None | Some("unknown") => None,
        Some(value) => Some(
            commit_id(value)
                .ok_or_else(|| format!("{}: {}", text::COMMIT_INPUT, text::COMMIT_SYNTAX))?,
        ),
    };
    let dirty = match dirty_input.as_deref() {
        None | Some("unknown") => "unknown",
        Some("true") => "true",
        Some("false") => "false",
        Some(_) => return Err(format!("{}: {}", text::DIRTY_INPUT, text::DIRTY_SYNTAX)),
    };
    let target = env::var("TARGET").map_err(|_| text::TARGET_ERROR.to_owned())?;
    if target.is_empty() || target.contains(['\r', '\n']) {
        return Err(text::TARGET_ERROR.to_owned());
    }
    // 明示的な unknown でも Git を起動しない。dirty は作業ツリーから推測しない。
    let (commit, commit_provenance) = if commit_input.is_some() {
        (commit, "environment")
    } else {
        match git_commit() {
            Some(value) => (Some(value), "git"),
            None => (None, "unknown"),
        }
    };
    let dirty_provenance = if dirty_input.is_some() {
        "environment"
    } else {
        "notCollected"
    };
    for (name, value) in [
        (
            "BENITOITE_EMBEDDED_BUILD_COMMIT",
            commit.as_deref().unwrap_or(""),
        ),
        ("BENITOITE_EMBEDDED_BUILD_DIRTY", dirty),
        ("BENITOITE_EMBEDDED_BUILD_TARGET", target.as_str()),
        ("BENITOITE_EMBEDDED_COMMIT_PROVENANCE", commit_provenance),
        ("BENITOITE_EMBEDDED_DIRTY_PROVENANCE", dirty_provenance),
    ] {
        println!("cargo::rustc-env={name}={value}");
    }
    Ok(())
}

fn input(name: &str, syntax: &str) -> Result<Option<String>, String> {
    match env::var(name) {
        Ok(value) => Ok(Some(value)),
        Err(env::VarError::NotPresent) => Ok(None),
        Err(env::VarError::NotUnicode(_)) => Err(format!("{name}: {syntax}")),
    }
}

fn commit_id(value: &str) -> Option<String> {
    (matches!(value.len(), 40 | 64) && value.bytes().all(|byte| byte.is_ascii_hexdigit()))
        .then(|| value.to_ascii_lowercase())
}

fn git_commit() -> Option<String> {
    let manifest = env::var_os("CARGO_MANIFEST_DIR")?;
    let manifest = Path::new(&manifest).canonicalize().ok()?;
    let root = manifest.parent()?.parent()?;
    let marker = root.join(".git");
    if !(marker.is_file() || marker.is_dir())
        || !root.join("Cargo.toml").is_file()
        || root.join("crates/benitoite").canonicalize().ok()? != manifest
    {
        return None;
    }
    let toplevel = git(root, &["rev-parse", "--show-toplevel"])?;
    if Path::new(&toplevel).canonicalize().ok()? != root {
        return None;
    }
    // 管理場所は worktree でも Git に解決させる。欠けたパスの監視は毎回の再実行になる。
    let dir = git(root, &["rev-parse", "--path-format=absolute", "--git-dir"])?;
    let common = git(
        root,
        &["rev-parse", "--path-format=absolute", "--git-common-dir"],
    )?;
    // reftable はファイルだけの監視で ref の更新を追えないため採取しない。
    if Path::new(&common).join("reftable").exists() || !watch(&Path::new(&dir).join("HEAD")) {
        return None;
    }
    watch(&Path::new(&dir).join("logs/HEAD"));
    let packed = watch(&Path::new(&common).join("packed-refs"));
    if let Some(reference) = git(root, &["symbolic-ref", "-q", "HEAD"]) {
        let path = git(
            root,
            &[
                "rev-parse",
                "--path-format=absolute",
                "--git-path",
                &reference,
            ],
        )?;
        if !watch(Path::new(&path)) && !packed {
            return None;
        }
    }
    commit_id(&git(root, &["rev-parse", "--verify", "HEAD^{commit}"])?)
}

fn git(root: &Path, args: &[&str]) -> Option<String> {
    let mut command = Command::new("git");
    command
        .args(["--no-optional-locks", "-c", "core.fsmonitor=false", "-C"])
        .arg(root)
        .args(args);
    for name in [
        "GIT_DIR",
        "GIT_WORK_TREE",
        "GIT_COMMON_DIR",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    ] {
        command.env_remove(name);
    }
    let output = command.output().ok()?;
    if !output.status.success() {
        return None;
    }
    let output = String::from_utf8(output.stdout).ok()?;
    let value = output.strip_suffix('\n').unwrap_or(&output);
    let value = value.strip_suffix('\r').unwrap_or(value);
    (!value.is_empty() && !value.contains(['\r', '\n'])).then(|| value.to_owned())
}

fn watch(path: &Path) -> bool {
    if path.is_file()
        && let Some(path) = path.to_str()
        && !path.contains(['\r', '\n'])
    {
        println!("cargo::rerun-if-changed={path}");
        return true;
    }
    false
}
