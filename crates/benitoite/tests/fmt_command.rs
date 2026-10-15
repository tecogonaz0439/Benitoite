//! `benitoite fmt` のプロセスのテスト（設計書 06-01「`fmt` のコマンドライン（初回リリース版）」「ディレクトリの指定
//! （初回リリース版）」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::time::{SystemTime, UNIX_EPOCH};

const UNFORMATTED: &str = "function main() -> Unit\n      ()\nend function\n";
const FORMATTED: &str = "function main() -> Unit\n  ()\nend function\n";
const BROKEN: &str = "function main( -> Unit\n  ()\nend function\n";

struct TestDirectory {
    path: PathBuf,
}

impl TestDirectory {
    fn new(tag: &str) -> TestDirectory {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |duration| duration.as_nanos());
        let path = std::env::temp_dir().join(format!(
            "benitoite-fmt-command-{tag}-{}-{timestamp}",
            std::process::id()
        ));
        fs::create_dir(&path).unwrap();
        TestDirectory { path }
    }

    fn write(&self, name: &str, contents: &str) -> PathBuf {
        let path = self.path.join(name);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(&path, contents).unwrap();
        path
    }

    fn read(&self, name: &str) -> String {
        fs::read_to_string(self.path.join(name)).unwrap()
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        #[cfg(unix)]
        restore_writable(&self.path);
        let _result = fs::remove_dir_all(&self.path);
    }
}

#[cfg(unix)]
fn restore_writable(root: &Path) {
    use std::os::unix::fs::PermissionsExt;
    let mut pending = vec![root.to_path_buf()];
    while let Some(dir) = pending.pop() {
        let _result = fs::set_permissions(&dir, fs::Permissions::from_mode(0o755));
        if let Ok(entries) = fs::read_dir(&dir) {
            for entry in entries.flatten() {
                if entry.file_type().is_ok_and(|t| t.is_dir()) {
                    pending.push(entry.path());
                }
            }
        }
    }
}

/// `dir` を作業ディレクトリにして `benitoite fmt` を起動する。
fn fmt(dir: &TestDirectory, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_benitoite"))
        .env_remove("BENITOITE_DEV_PANIC")
        .env_remove("BENITOITE_DEV_IO_MODE")
        .env_remove("NO_COLOR")
        .current_dir(&dir.path)
        .arg("fmt")
        .args(args)
        .output()
        .unwrap()
}

fn code(output: &Output) -> i32 {
    output.status.code().unwrap_or(-1)
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).into_owned()
}

#[test]
fn rewrites_changed_files_and_leaves_canonical_files_untouched() {
    let dir = TestDirectory::new("rewrites_changed_files_and_leaves_canonical_files_untouched");
    dir.write("a.bnt", UNFORMATTED);
    let canonical = dir.write("b.bnt", FORMATTED);
    let before = fs::metadata(&canonical).unwrap().modified().unwrap();
    let output = fmt(&dir, &["a.bnt", "b.bnt"]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert!(output.stdout.is_empty());
    assert!(output.stderr.is_empty(), "{}", stderr(&output));
    assert_eq!(dir.read("a.bnt"), FORMATTED);
    assert_eq!(
        fs::metadata(&canonical).unwrap().modified().unwrap(),
        before
    );
    // 一時ファイルが残らない
    let names: Vec<_> = fs::read_dir(&dir.path)
        .unwrap()
        .flatten()
        .map(|e| e.file_name())
        .collect();
    assert_eq!(names.len(), 2, "{names:?}");
}

#[test]
fn saves_short_lambdas_on_their_original_line() {
    let dir = TestDirectory::new("saves_short_lambdas_on_their_original_line");
    dir.write("short.bnt", "function main() -> Unit\r\n bind f<-lambda (x) return x+1 // keep\r\n bind g<-lambda(x) return x end lambda\r\n ()\r\nend function");
    let output = fmt(&dir, &["short.bnt"]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert!(output.stdout.is_empty());
    assert!(output.stderr.is_empty(), "{}", stderr(&output));
    assert_eq!(
        dir.read("short.bnt"),
        "function main() -> Unit\n  bind f <- lambda(x) return x + 1 // keep\n  bind g <- lambda(x) return x end lambda\n  ()\nend function\n"
    );
    let output = fmt(&dir, &["--check", "short.bnt"]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert!(output.stdout.is_empty());
    assert!(output.stderr.is_empty(), "{}", stderr(&output));
}

#[test]
fn check_reports_without_rewriting() {
    let dir = TestDirectory::new("check_reports_without_rewriting");
    dir.write("a.bnt", UNFORMATTED);
    dir.write("b.bnt", FORMATTED);
    let output = fmt(&dir, &["--check", "a.bnt", "b.bnt"]);
    assert_eq!(code(&output), 1);
    assert!(output.stdout.is_empty());
    assert_eq!(stderr(&output), "would reformat a.bnt\n");
    assert_eq!(dir.read("a.bnt"), UNFORMATTED);
}

#[test]
fn directory_expands_to_sorted_bnt_files_only() {
    let dir = TestDirectory::new("directory_expands_to_sorted_bnt_files_only");
    dir.write("src/z.bnt", UNFORMATTED);
    dir.write("src/a/y.bnt", UNFORMATTED);
    dir.write("src/notes.txt", UNFORMATTED);
    #[cfg(unix)]
    {
        let outside = dir.write("outside.bnt", UNFORMATTED);
        std::os::unix::fs::symlink(&outside, dir.path.join("src/link.bnt")).unwrap();
    }
    let output = fmt(&dir, &["--check", "src"]);
    assert_eq!(code(&output), 1);
    let sep = std::path::MAIN_SEPARATOR;
    assert_eq!(
        stderr(&output),
        format!("would reformat src{sep}a{sep}y.bnt\nwould reformat src{sep}z.bnt\n")
    );
    let output = fmt(&dir, &["src"]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert_eq!(dir.read("src/z.bnt"), FORMATTED);
    assert_eq!(dir.read("src/a/y.bnt"), FORMATTED);
    assert_eq!(dir.read("src/notes.txt"), UNFORMATTED);
    #[cfg(unix)]
    assert_eq!(dir.read("outside.bnt"), UNFORMATTED);
}

#[test]
fn syntax_errors_and_unreadable_files_do_not_stop_other_files() {
    let dir = TestDirectory::new("syntax_errors_and_unreadable_files_do_not_stop_other_files");
    dir.write("bad.bnt", BROKEN);
    dir.write("good.bnt", UNFORMATTED);
    let output = fmt(&dir, &["bad.bnt", "missing.bnt", "good.bnt"]);
    assert_eq!(code(&output), 2);
    assert!(output.stdout.is_empty());
    let err = stderr(&output);
    assert!(err.contains("bad.bnt:1:"), "{err}");
    assert!(err.contains("E0101"), "{err}");
    assert!(err.contains("missing.bnt"), "{err}");
    assert_eq!(dir.read("bad.bnt"), BROKEN);
    assert_eq!(dir.read("good.bnt"), FORMATTED);
}

#[test]
fn json_diagnostics_are_one_object_per_line() {
    let dir = TestDirectory::new("json_diagnostics_are_one_object_per_line");
    dir.write("bad.bnt", BROKEN);
    let output = fmt(&dir, &["--diagnostics=json", "bad.bnt"]);
    assert_eq!(code(&output), 2);
    let err = stderr(&output);
    assert!(!err.is_empty());
    for line in err.lines() {
        assert!(line.starts_with("{\"kind\":"), "{line}");
        assert!(line.contains("\"severity\":\"error\""), "{line}");
        assert!(line.contains("\"file\":\"bad.bnt\""), "{line}");
        assert!(line.ends_with('}'), "{line}");
    }
}

#[test]
fn usage_errors_have_two_lines_and_exit_two() {
    let dir = TestDirectory::new("usage_errors_have_two_lines_and_exit_two");
    dir.write("a.bnt", UNFORMATTED);
    for args in [
        &[][..],
        &["--deny-warnings", "a.bnt"],
        &["--frobnicate", "a.bnt"],
        &["--diagnostics=xml", "a.bnt"],
    ] {
        let output = fmt(&dir, args);
        assert_eq!(code(&output), 2, "{args:?}");
        let err = stderr(&output);
        assert_eq!(err.lines().count(), 2, "{args:?}: {err}");
        assert!(err.starts_with("error:"), "{err}");
        assert!(err.contains("--help"), "{err}");
    }
    assert_eq!(dir.read("a.bnt"), UNFORMATTED);
}

#[cfg(unix)]
#[test]
fn unreadable_directory_is_reported_and_other_paths_continue() {
    use std::os::unix::fs::PermissionsExt;
    let dir = TestDirectory::new("unreadable_directory_is_reported_and_other_paths_continue");
    dir.write("locked/a.bnt", UNFORMATTED);
    dir.write("good.bnt", UNFORMATTED);
    fs::set_permissions(dir.path.join("locked"), fs::Permissions::from_mode(0o000)).unwrap();
    if fs::read_dir(dir.path.join("locked")).is_ok() {
        // root では許可を外しても読めるので確かめられない
        return;
    }
    let output = fmt(&dir, &["locked", "good.bnt"]);
    assert_eq!(code(&output), 2);
    let err = stderr(&output);
    assert!(err.contains("E0101") && err.contains("locked"), "{err}");
    assert_eq!(dir.read("good.bnt"), FORMATTED);
}

#[cfg(unix)]
#[test]
fn unwritable_directory_keeps_the_original_and_leaves_no_temp_file() {
    use std::os::unix::fs::PermissionsExt;
    let dir = TestDirectory::new("unwritable_directory_keeps_the_original_and_leaves_no_temp_file");
    dir.write("ro/a.bnt", UNFORMATTED);
    let ro = dir.path.join("ro");
    fs::set_permissions(&ro, fs::Permissions::from_mode(0o555)).unwrap();
    if fs::write(ro.join("probe"), "").is_ok() {
        // root では書き込めてしまうので確かめられない
        return;
    }
    let output = fmt(&dir, &["ro/a.bnt"]);
    assert_eq!(code(&output), 2);
    let err = stderr(&output);
    assert!(err.contains("E0125") && err.contains("ro/a.bnt"), "{err}");
    assert_eq!(dir.read("ro/a.bnt"), UNFORMATTED);
    assert_eq!(fs::read_dir(&ro).unwrap().count(), 1);
}

#[cfg(unix)]
#[test]
fn a_link_given_directly_rewrites_its_target_and_keeps_the_link() {
    let dir = TestDirectory::new("a_link_given_directly_rewrites_its_target_and_keeps_the_link");
    let target = dir.write("real/a.bnt", UNFORMATTED);
    let link = dir.path.join("link.bnt");
    std::os::unix::fs::symlink(&target, &link).unwrap();
    let output = fmt(&dir, &["link.bnt"]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert!(
        fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink()
    );
    assert_eq!(fs::read_link(&link).unwrap(), target);
    assert_eq!(dir.read("real/a.bnt"), FORMATTED);
    let names = |path: &Path| {
        let mut names: Vec<_> = fs::read_dir(path)
            .unwrap()
            .map(|entry| entry.unwrap().file_name())
            .collect();
        names.sort();
        names
    };
    assert_eq!(names(&dir.path.join("real")), ["a.bnt"]);
    assert_eq!(names(&dir.path), ["link.bnt", "real"]);
}

#[cfg(unix)]
#[test]
fn execute_permission_is_kept() {
    use std::os::unix::fs::PermissionsExt;
    let dir = TestDirectory::new("execute_permission_is_kept");
    let path = dir.write("script.bnt", UNFORMATTED);
    fs::set_permissions(&path, fs::Permissions::from_mode(0o751)).unwrap();
    let output = fmt(&dir, &["script.bnt"]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert_eq!(dir.read("script.bnt"), FORMATTED);
    assert_eq!(
        fs::metadata(&path).unwrap().permissions().mode() & 0o777,
        0o751
    );
}

// 関門: 直接指定した FIFO で fmt のプロセスが停止しない。
#[cfg(unix)]
#[test]
fn fmt_rejects_a_fifo_without_blocking() {
    use std::process::Stdio;
    use std::time::{Duration, Instant};
    let dir = TestDirectory::new("fifo");
    assert!(
        Command::new("mkfifo")
            .arg(dir.path.join("pipe.bnt"))
            .status()
            .unwrap()
            .success()
    );
    let mut child = Command::new(env!("CARGO_BIN_EXE_benitoite"))
        .env_remove("BENITOITE_DEV_PANIC")
        .current_dir(&dir.path)
        .args(["fmt", "pipe.bnt"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let started = Instant::now();
    while child.try_wait().unwrap().is_none() {
        if started.elapsed() >= Duration::from_secs(5) {
            child.kill().unwrap();
            child.wait().unwrap();
            panic!("fmt blocked while opening a FIFO");
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    let output = child.wait_with_output().unwrap();
    assert_eq!(code(&output), 2);
    assert!(stderr(&output).contains("E0101"), "{}", stderr(&output));
    assert!(output.stdout.is_empty());
}

// 関門: 書き込み禁止と固いリンクの拒否理由、元の保存、一時ファイルの掃除を CLI で確かめる。
#[cfg(unix)]
#[test]
fn fmt_refuses_read_only_and_hard_linked_targets_but_check_does_not() {
    use std::os::unix::fs::{MetadataExt, PermissionsExt, symlink};
    for (tag, mode, hard_link, reason) in [
        ("read-only", 0o444, false, "owner has no write permission"),
        (
            "group-writable",
            0o464,
            false,
            "owner has no write permission",
        ),
        ("hard-link", 0o644, true, "more than one hard link"),
    ] {
        let dir = TestDirectory::new(tag);
        let target = dir.write("original.bnt", UNFORMATTED);
        fs::set_permissions(&target, fs::Permissions::from_mode(mode)).unwrap();
        if hard_link {
            fs::hard_link(&target, dir.path.join("other.bnt")).unwrap();
        }
        symlink("original.bnt", dir.path.join("link.bnt")).unwrap();
        let before = fs::metadata(&target).unwrap();
        for path in ["original.bnt", "link.bnt"] {
            let check = fmt(&dir, &["--check", path]);
            assert_eq!(code(&check), 1, "{}", stderr(&check));
            assert_eq!(stderr(&check), format!("would reformat {path}\n"));
            let output = fmt(&dir, &["--diagnostics=json", path]);
            assert_eq!(code(&output), 2, "{}", stderr(&output));
            let diag: serde_json::Value = serde_json::from_slice(&output.stderr).unwrap();
            assert_eq!(diag["code"], "E0125");
            assert!(
                diag["notes"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .any(|note| note.as_str().unwrap().contains(reason)),
                "{diag}"
            );
            let after = fs::metadata(&target).unwrap();
            assert_eq!(
                (after.ino(), after.nlink(), after.mode(), after.uid()),
                (before.ino(), before.nlink(), before.mode(), before.uid())
            );
            assert_eq!(dir.read("original.bnt"), UNFORMATTED);
            assert_eq!(
                fs::read_link(dir.path.join("link.bnt")).unwrap(),
                PathBuf::from("original.bnt")
            );
            assert_eq!(
                fs::read_dir(&dir.path).unwrap().count(),
                if hard_link { 3 } else { 2 }
            );
        }
        if hard_link {
            assert_eq!(dir.read("other.bnt"), UNFORMATTED);
        }
    }
}

#[cfg(unix)]
#[test]
fn check_escapes_terminal_controls_in_the_file_name() {
    let dir = TestDirectory::new("escaped-name");
    let name = "a\u{1b}[2J.bnt";
    dir.write(name, UNFORMATTED);
    let output = fmt(&dir, &["--check", name]);
    assert_eq!(code(&output), 1);
    assert_eq!(stderr(&output), "would reformat a\\u{1B}[2J.bnt\n");
    assert_eq!(dir.read(name), UNFORMATTED);
}

#[test]
fn directory_walk_formats_package_settings() {
    let dir = TestDirectory::new("package-settings");
    dir.write(
        "package.bnt",
        "language    \"0.0.5\"\npackage Textkit\n       license   \"MIT\"\nend package\n",
    );
    let output = fmt(&dir, &["."]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
    assert_eq!(
        dir.read("package.bnt"),
        "language \"0.0.5\"\n\npackage Textkit\n  license \"MIT\"\nend package\n"
    );
    let output = fmt(&dir, &["--check", "."]);
    assert_eq!(code(&output), 0, "{}", stderr(&output));
}
