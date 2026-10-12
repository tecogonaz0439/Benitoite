//! `skill install`・`uninstall` のテスト（設計書 06-06「Skill の導入（初回リリース版）」）。ホームと作業ディレクトリを一時ディレクトリにして `run_skill` を呼ぶ。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::fs;
use std::sync::{Arc, Mutex};

use super::*;
use crate::cli::{DevPanic, text as cli_text};
use crate::runtime::heap::HeapConfig;
use crate::runtime::run::{NoInterrupt, OutputTarget, StdinSource};
use crate::vm::ExecMode;

struct Temp(PathBuf);

impl Temp {
    fn new(name: &str) -> Self {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "benitoite-skill-{name}-{}-{nanos}",
            std::process::id()
        ));
        fs::create_dir_all(path.join("home")).unwrap();
        fs::create_dir_all(path.join("work")).unwrap();
        Self(path)
    }
    fn home(&self) -> PathBuf {
        self.0.join("home")
    }
    fn work(&self) -> PathBuf {
        self.0.join("work")
    }
}

impl Drop for Temp {
    fn drop(&mut self) {
        let _ignored = fs::remove_dir_all(&self.0);
    }
}

struct Outcome {
    exit: u8,
    out: String,
    err: String,
}

fn run(temp: &Temp, args: &[&str], home: Option<PathBuf>) -> Outcome {
    let out = Arc::new(Mutex::new(Vec::new()));
    let err = Arc::new(Mutex::new(Vec::new()));
    let env = CliEnv {
        stdout: OutputTarget::Capture(Arc::clone(&out)),
        stderr: OutputTarget::Capture(Arc::clone(&err)),
        stdin: StdinSource::Empty,
        working_directory: temp.work(),
        color: false,
        mode: ExecMode::Direct,
        interrupt: Some(Box::new(NoInterrupt)),
        parts: None,
        heap: HeapConfig::default(),
        dev_panic: DevPanic::None,
        dev_alloc_stats: false,
    };
    let exit = run_skill(args.iter().map(OsString::from).collect(), env, home);
    let out = String::from_utf8(out.lock().unwrap().clone()).unwrap();
    let err = String::from_utf8(err.lock().unwrap().clone()).unwrap();
    Outcome { exit, out, err }
}

fn claude(base: &Path) -> PathBuf {
    base.join(".claude/skills/benitoite")
}
fn agents(base: &Path) -> PathBuf {
    base.join(".agents/skills/benitoite")
}

/// 埋め込んだすべてのファイルが書かれ、`SKILL.md` の版が処理系の版になっていることを確かめる。
fn assert_installed(dir: &Path) {
    for file in files() {
        let written = fs::read_to_string(dir.join(file.path)).unwrap();
        if file.path == "SKILL.md" {
            assert!(!written.contains(VERSION_PLACEHOLDER));
            assert!(written.contains(&format!("{VERSION_KEY}: \"{}\"", env!("CARGO_PKG_VERSION"))));
        } else {
            assert_eq!(written, file.text, "{}", file.path);
        }
    }
}

/// 親のディレクトリに一時ディレクトリ（`.benitoite.install-*`・`.benitoite.old-*`）が残っていないこと。
fn assert_no_temp(dir: &Path) {
    let Some(parent) = dir.parent() else { return };
    let Ok(entries) = fs::read_dir(parent) else {
        return;
    };
    for entry in entries {
        let name = entry.unwrap().file_name().to_string_lossy().into_owned();
        assert!(!name.starts_with(".benitoite."), "{name} remains");
    }
}

fn line(template: &str, path: &Path) -> String {
    format!(
        "{}\n",
        template.replace("{path}", &path.display().to_string())
    )
}

#[test]
fn install_writes_every_agent_directory_under_home() {
    let temp = Temp::new("install");
    let home = temp.home();
    let result = run(&temp, &["install"], Some(home.clone()));
    assert_eq!(result.exit, 0, "{}", result.err);
    assert_eq!(
        result.out,
        format!(
            "{}{}",
            line(text::INSTALLED, &claude(&home)),
            line(text::INSTALLED, &agents(&home))
        )
    );
    assert!(result.err.is_empty());
    assert_installed(&claude(&home));
    assert_installed(&agents(&home));
    assert_no_temp(&claude(&home));
    assert_no_temp(&agents(&home));
    assert!(!temp.work().join(".claude").exists());
}

#[test]
fn project_writes_under_the_working_directory_and_agents_share_a_directory() {
    let temp = Temp::new("project");
    let work = temp.work();
    let result = run(
        &temp,
        &[
            "install",
            "--project",
            "--agent",
            "codex",
            "--agent=opencode",
        ],
        None,
    );
    assert_eq!(result.exit, 0, "{}", result.err);
    assert_eq!(result.out, line(text::INSTALLED, &agents(&work)));
    assert_installed(&agents(&work));
    assert!(!work.join(".claude").exists());
    assert!(!temp.home().join(".agents").exists());
}

#[test]
fn reinstall_replaces_the_old_install_without_leftover_files() {
    let temp = Temp::new("replace");
    let home = temp.home();
    let dir = claude(&home);
    let args = ["install", "--agent", "claude-code"];
    assert_eq!(run(&temp, &args, Some(home.clone())).exit, 0);
    fs::write(dir.join("references/only-in-old.md"), "old").unwrap();
    let result = run(&temp, &args, Some(home.clone()));
    assert_eq!(result.exit, 0, "{}", result.err);
    assert!(!dir.join("references/only-in-old.md").exists());
    assert_installed(&dir);
    assert_no_temp(&dir);
}

#[test]
fn a_directory_not_written_by_install_is_left_unchanged() {
    let temp = Temp::new("not-ours");
    let home = temp.home();
    let dir = claude(&home);
    fs::create_dir_all(&dir).unwrap();
    // metadata の版の欄がない前付け。本文に版の欄の名前があっても前付けの外なので数えない
    let foreign = "---\nname: benitoite\nmetadata:\n  author: someone\n---\nbenitoite-version: 1\n";
    fs::write(dir.join("SKILL.md"), foreign).unwrap();
    for action in ["install", "uninstall"] {
        let result = run(
            &temp,
            &[action, "--agent", "claude-code"],
            Some(home.clone()),
        );
        assert_eq!(result.exit, 1);
        assert_eq!(result.err, line(text::NOT_OURS, &dir));
        assert!(result.out.is_empty());
        assert_eq!(fs::read_to_string(dir.join("SKILL.md")).unwrap(), foreign);
        assert_eq!(fs::read_dir(&dir).unwrap().count(), 1);
        assert_no_temp(&dir);
    }
}

#[test]
fn version_key_is_found_only_under_metadata_in_the_front_matter() {
    assert!(has_version_key(
        "---\nmetadata:\n  benitoite-version: \"1\"\n---\n"
    ));
    assert!(!has_version_key("---\nbenitoite-version: \"1\"\n---\n"));
    assert!(!has_version_key(
        "---\nmetadata:\n  author: x\n---\n  benitoite-version: 1\n"
    ));
    assert!(!has_version_key(
        "# no front matter\nmetadata:\n  benitoite-version: 1\n"
    ));
    assert!(!has_version_key(
        "---\nmetadata:\n  benitoite-versions: 1\n---\n"
    ));
}

#[cfg(unix)]
#[test]
fn an_unwritable_parent_fails_and_leaves_no_temporary_directory() {
    use std::os::unix::fs::PermissionsExt;
    let temp = Temp::new("unwritable");
    let home = temp.home();
    let parent = home.join(".claude/skills");
    fs::create_dir_all(&parent).unwrap();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o555)).unwrap();
    if fs::write(parent.join("probe"), "").is_ok() {
        // root では書き込めてしまうので確かめられない
        return;
    }
    let result = run(
        &temp,
        &["install", "--agent", "claude-code"],
        Some(home.clone()),
    );
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o755)).unwrap();
    assert_eq!(result.exit, 1);
    let prefix = text::WRITE_FAILED
        .replace("{path}", &claude(&home).display().to_string())
        .replace("{reason}", "");
    assert!(result.err.starts_with(&prefix), "{}", result.err);
    assert_eq!(fs::read_dir(&parent).unwrap().count(), 0);
}

#[test]
fn uninstall_removes_installs_and_ignores_missing_directories() {
    let temp = Temp::new("uninstall");
    let home = temp.home();
    let result = run(&temp, &["uninstall"], Some(home.clone()));
    assert_eq!((result.exit, result.out.as_str()), (0, ""));
    assert_eq!(
        run(&temp, &["install", "--agent", "codex"], Some(home.clone())).exit,
        0
    );
    let result = run(&temp, &["uninstall", "--user"], Some(home.clone()));
    assert_eq!(result.exit, 0, "{}", result.err);
    assert_eq!(result.out, line(text::REMOVED, &agents(&home)));
    assert!(!agents(&home).exists());
    assert!(home.join(".agents/skills").exists());
    assert_no_temp(&agents(&home));
}

#[test]
fn user_scope_without_home_reports_no_home() {
    let temp = Temp::new("no-home");
    for action in ["install", "uninstall"] {
        for home in [None, Some(PathBuf::new())] {
            let result = run(&temp, &[action], home);
            assert_eq!(result.exit, 1);
            assert_eq!(result.err, format!("{}\n", text::NO_HOME));
            assert!(result.out.is_empty());
        }
    }
    assert_eq!(fs::read_dir(temp.home()).unwrap().count(), 0);
    assert_eq!(fs::read_dir(temp.work()).unwrap().count(), 0);
}

#[test]
fn user_scope_rejects_home_that_is_not_an_absolute_existing_directory() {
    for action in ["install", "uninstall"] {
        let temp = Temp::new("invalid-home");
        let missing = temp.0.join("missing-\x1b{path}-{reason}");
        let file = temp.0.join("file");
        fs::write(&file, "keep").unwrap();
        // 作業ディレクトリから根まで上り、一時ディレクトリを相対パスで指す。
        // 相対パスの拒否が退行しても、書き出し先と後始末は一時ディレクトリの中に収まる。
        let cwd = std::env::current_dir().unwrap();
        let mut relative_base = PathBuf::new();
        for component in cwd.components() {
            if matches!(component, std::path::Component::Normal(_)) {
                relative_base.push("..");
            }
        }
        relative_base.push(temp.0.strip_prefix("/").unwrap());
        let relative = relative_base.join("rel-missing");
        let relative_existing = relative_base.join("rel-existing");
        assert!(!relative.is_absolute());
        assert!(!relative.exists());
        fs::create_dir(&relative_existing).unwrap();
        let homes = vec![
            missing.clone(),
            file.clone(),
            relative.clone(),
            relative_existing.clone(),
        ];
        #[cfg(unix)]
        let homes = {
            let mut homes = homes;
            let broken = temp.0.join("broken-home");
            std::os::unix::fs::symlink(&missing, &broken).unwrap();
            homes.push(broken);
            homes
        };
        for home in homes {
            let result = run(&temp, &[action], Some(home.clone()));
            assert_eq!(result.exit, 1, "{action}: {home:?}");
            let escaped = home.display().to_string().replace('\x1b', r#"\u{1B}"#);
            assert_eq!(
                result.err,
                format!("{}\n", text::HOME_NOT_DIRECTORY.replace("{path}", &escaped)),
                "{action}: {home:?}"
            );
            assert!(result.out.is_empty(), "{action}: {home:?}");
        }
        assert!(!missing.exists());
        assert!(!relative.exists());
        assert_eq!(fs::read_dir(&relative_existing).unwrap().count(), 0);
        assert_eq!(fs::read_to_string(file).unwrap(), "keep");
        assert_eq!(fs::read_dir(temp.home()).unwrap().count(), 0);
        assert_eq!(fs::read_dir(temp.work()).unwrap().count(), 0);
    }
}

// 関門: HOME のディレクトリへのリンクを辿る契約を、実際の導入結果で確かめる。
// metadata を symlink_metadata に変える退行は、通常のディレクトリと拒否の表だけでは捕まらない。
// 本番の差し込み口を増やさず run_skill から確かめる（設計書 06-06「Skill の導入（初回リリース版）」）。
#[cfg(unix)]
#[test]
fn user_scope_installs_through_a_symlink_to_a_home_directory() {
    let temp = Temp::new("home-link");
    let link = temp.0.join("home-link");
    std::os::unix::fs::symlink(temp.home(), &link).unwrap();
    let result = run(&temp, &["install"], Some(link.clone()));
    assert_eq!(result.exit, 0, "{}", result.err);
    assert!(result.err.is_empty());
    assert_eq!(
        result.out,
        format!(
            "{}{}",
            line(text::INSTALLED, &claude(&link)),
            line(text::INSTALLED, &agents(&link))
        )
    );
    assert_installed(&claude(&temp.home()));
    assert_installed(&agents(&temp.home()));
    assert!(
        fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink()
    );
    assert_no_temp(&claude(&temp.home()));
    assert_no_temp(&agents(&temp.home()));
    assert_eq!(fs::read_dir(temp.work()).unwrap().count(), 0);
}

#[test]
fn usage_errors_have_two_lines_and_exit_two() {
    let temp = Temp::new("usage");
    let cases: [(&[&str], String); 8] = [
        (&[], text::MISSING_ACTION.to_owned()),
        (&["--user"], text::MISSING_ACTION.to_owned()),
        (
            &["install", "--user", "--project"],
            text::USER_AND_PROJECT.to_owned(),
        ),
        (
            &["install", "--agent", "cursor"],
            text::UNKNOWN_AGENT.replace("{name}", "cursor"),
        ),
        (
            &["install", "--diagnostics=json"],
            cli_text::UNKNOWN_OPTION.replace("{name}", "--diagnostics=json"),
        ),
        (
            &["install", "--project", "--project"],
            cli_text::DUPLICATE_OPTION.replace("{name}", "--project"),
        ),
        (
            &["install", "uninstall"],
            cli_text::EXTRA_ARGUMENT.replace("{value}", "uninstall"),
        ),
        (
            &["install", "--agent"],
            cli_text::BAD_VALUE
                .replace("{value}", "")
                .replace("{name}", "--agent"),
        ),
    ];
    for (args, detail) in cases {
        let result = run(&temp, args, Some(temp.home()));
        assert_eq!(result.exit, 2, "{args:?}");
        assert!(result.out.is_empty());
        assert_eq!(
            result.err,
            format!(
                "{}\n{}\n",
                cli_text::USAGE_ERROR.replace("{detail}", &detail),
                cli_text::SEE_HELP
            )
        );
    }
    assert_eq!(fs::read_dir(temp.home()).unwrap().count(), 0);
}

#[cfg(unix)]
#[test]
fn replacing_under_an_unwritable_parent_keeps_the_old_install() {
    use std::os::unix::fs::PermissionsExt;
    let temp = Temp::new("replace-unwritable");
    let home = temp.home();
    let dir = claude(&home);
    let args = ["install", "--agent", "claude-code"];
    assert_eq!(run(&temp, &args, Some(home.clone())).exit, 0);
    fs::write(dir.join("references/only-in-old.md"), "old").unwrap();
    let parent = home.join(".claude/skills");
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o555)).unwrap();
    if fs::write(parent.join("probe"), "").is_ok() {
        // root では書き込めてしまうので確かめられない
        return;
    }
    let result = run(&temp, &args, Some(home.clone()));
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o755)).unwrap();
    assert_eq!(result.exit, 1);
    assert!(
        result.err.contains(&dir.display().to_string()),
        "{}",
        result.err
    );
    assert_eq!(
        fs::read_to_string(dir.join("references/only-in-old.md")).unwrap(),
        "old"
    );
    assert_installed(&dir);
    assert_no_temp(&dir);
}

#[cfg(unix)]
#[test]
fn an_old_install_that_cannot_be_removed_keeps_the_new_install() {
    use std::os::unix::fs::PermissionsExt;
    let temp = Temp::new("old-unremovable");
    let home = temp.home();
    let dir = claude(&home);
    let args = ["install", "--agent", "claude-code"];
    assert_eq!(run(&temp, &args, Some(home.clone())).exit, 0);
    let locked = dir.join("references/locked");
    fs::create_dir(&locked).unwrap();
    fs::write(locked.join("stuck.md"), "").unwrap();
    fs::set_permissions(&locked, fs::Permissions::from_mode(0o555)).unwrap();
    if fs::write(locked.join("probe"), "").is_ok() {
        fs::set_permissions(&locked, fs::Permissions::from_mode(0o755)).unwrap();
        return;
    }
    let result = run(&temp, &args, Some(home.clone()));
    let old = home
        .join(".claude/skills")
        .join(format!(".benitoite.old-{}", std::process::id()));
    let old_locked = old.join("references/locked");
    if old_locked.exists() {
        fs::set_permissions(&old_locked, fs::Permissions::from_mode(0o755)).unwrap();
    }
    assert_eq!(result.exit, 1);
    let prefix = text::REMOVE_FAILED
        .replace("{path}", &old.display().to_string())
        .replace("{reason}", "");
    assert!(result.err.starts_with(&prefix), "{}", result.err);
    assert!(old_locked.join("stuck.md").exists());
    assert!(!dir.join("references/locked").exists());
    assert_installed(&dir);
}

// 関門: project の既存 SKILL.md が FIFO なら、停止せず上書きを拒む。
#[cfg(unix)]
#[test]
fn install_refuses_a_fifo_skill_without_blocking() {
    let temp = Temp::new("fifo");
    let dir = claude(&temp.work());
    fs::create_dir_all(&dir).unwrap();
    let fifo = dir.join("SKILL.md");
    assert!(
        std::process::Command::new("mkfifo")
            .arg(&fifo)
            .status()
            .unwrap()
            .success()
    );
    let (send, recv) = std::sync::mpsc::channel();
    let worker = std::thread::spawn(move || {
        let result = run(
            &temp,
            &["install", "--project", "--agent", "claude-code"],
            None,
        );
        send.send((temp, result)).unwrap();
    });
    let (_temp, result) = recv
        .recv_timeout(std::time::Duration::from_secs(5))
        .expect("skill install blocked while reading a FIFO");
    worker.join().unwrap();
    assert_eq!(result.exit, 1);
    assert_eq!(result.err, line(text::NOT_OURS, &dir));
    assert!(result.out.is_empty());
    use std::os::unix::fs::FileTypeExt;
    assert!(fs::symlink_metadata(fifo).unwrap().file_type().is_fifo());
    assert_no_temp(&dir);
}

// 関門: パスの制御文字を逃がし、埋めたパスの {reason} をもう一度展開しない。
#[cfg(unix)]
#[test]
fn skill_messages_escape_paths_and_preserve_template_names() {
    let temp = Temp::new("escape-\u{1b}{reason}");
    let home = temp.home();
    let dir = claude(&home);
    let escaped = dir.display().to_string().replace('\u{1b}', "\\u{1B}");
    for (action, verb) in [("install", "installed"), ("uninstall", "removed")] {
        let result = run(
            &temp,
            &[action, "--agent", "claude-code"],
            Some(home.clone()),
        );
        assert_eq!(result.exit, 0, "{}", result.err);
        assert_eq!(result.out, format!("{verb} {escaped}\n"));
    }
    fs::create_dir_all(&dir).unwrap();
    let result = run(&temp, &["install", "--agent", "claude-code"], Some(home));
    assert_eq!(result.exit, 1);
    assert_eq!(
        result.err,
        format!(
            "error: `{escaped}` was not written by `benitoite skill install`; it was left unchanged\n"
        )
    );
    assert_eq!(
        write_failed(&dir, "denied"),
        format!("error: cannot write `{escaped}`: denied")
    );
    assert_eq!(
        remove_failed(&dir, "denied"),
        format!("error: cannot remove `{escaped}`: denied")
    );
}

#[cfg(unix)]
#[test]
fn install_refuses_symlinked_and_oversized_skill_files() {
    let temp = Temp::new("skill-file");
    let dir = claude(&temp.work());
    fs::create_dir_all(&dir).unwrap();
    let original = "---\nmetadata:\n  benitoite-version: 1\n---\n";
    let outside = temp.work().join("ours.md");
    fs::write(&outside, original).unwrap();
    std::os::unix::fs::symlink(&outside, dir.join("SKILL.md")).unwrap();
    let args = ["install", "--project", "--agent", "claude-code"];
    let result = run(&temp, &args, None);
    assert_eq!(result.exit, 1, "{}", result.err);
    assert_eq!(result.err, line(text::NOT_OURS, &dir));
    assert_eq!(fs::read_to_string(&outside).unwrap(), original);
    fs::remove_file(dir.join("SKILL.md")).unwrap();
    let mut oversized = original.to_owned();
    oversized.push_str(&"x".repeat(1024 * 1024));
    fs::write(dir.join("SKILL.md"), &oversized).unwrap();
    let result = run(&temp, &args, None);
    assert_eq!(result.exit, 1, "{}", result.err);
    assert_eq!(result.err, line(text::NOT_OURS, &dir));
    assert_eq!(fs::read_to_string(dir.join("SKILL.md")).unwrap(), oversized);
    assert_no_temp(&dir);
}
