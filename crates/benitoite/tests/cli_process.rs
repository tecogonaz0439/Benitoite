#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
//! CLI を別プロセスで起動し、終了状態と標準入出力を確かめる
//! （設計書 07-03「前提」、実装プラン T25「CLI を別のプロセスとして起動するテスト」）。
// テストの失敗は panic で表すため、テストコードではこれらを許す（実装規約 00-02「#[allow] を書いてよい箇所」）。

use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

#[test]
fn cli_process_contracts() {
    let directory = TestDirectory::new();
    let hello = directory.write(
        "hello.bnt",
        "fn main() -> Unit uses IO {\n    Console.println(\"hello\")\n}\n",
    );

    let usage_cases: [(&str, &[&str]); 3] = [
        ("missing subcommand", &[]),
        ("unknown option", &["run", "--unknown"]),
        ("missing script path", &["run"]),
    ];
    for (name, args) in usage_cases {
        let output = command().args(args).output().unwrap_or_else(|error| {
            panic!("could not run CLI for {name}: {error}");
        });
        assert_eq!(exit_code(&output), 2, "{name}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.contains("error:"), "{name}: {stderr}");
        assert!(stderr.contains("--help"), "{name}: {stderr}");
    }

    let version = command()
        .arg("--version")
        .output()
        .unwrap_or_else(|error| panic!("could not run --version: {error}"));
    assert_eq!(exit_code(&version), 0);
    assert!(String::from_utf8_lossy(&version.stdout).contains(env!("CARGO_PKG_VERSION")));

    let help = command()
        .arg("--help")
        .output()
        .unwrap_or_else(|error| panic!("could not run --help: {error}"));
    assert_eq!(exit_code(&help), 0);
    assert!(String::from_utf8_lossy(&help.stdout).starts_with("Usage:"));

    let run = command()
        .arg("run")
        .arg(&hello)
        .output()
        .unwrap_or_else(|error| panic!("could not run hello script: {error}"));
    assert_eq!(exit_code(&run), 0);
    assert_eq!(run.stdout, b"hello\n");
    assert!(run.stderr.is_empty());

    let missing = directory.path().join("missing.bnt");
    let missing_check = command()
        .arg("check")
        .arg(&missing)
        .output()
        .unwrap_or_else(|error| panic!("could not check missing script: {error}"));
    assert_eq!(exit_code(&missing_check), 2);
    let missing_stderr = String::from_utf8_lossy(&missing_check.stderr);
    assert!(missing_stderr.contains("E0101"), "{missing_stderr}");
    assert!(
        missing_stderr.contains(&missing.display().to_string()),
        "{missing_stderr}"
    );

    let panic_check = command()
        .arg("run")
        .arg(&hello)
        .env("BENITOITE_DEV_PANIC", "check")
        .output()
        .unwrap_or_else(|error| panic!("could not exercise check panic: {error}"));
    assert_eq!(exit_code(&panic_check), 3);
    assert!(panic_check.stdout.is_empty());
    assert_internal_report(&panic_check.stderr);

    let panic_run = command()
        .arg("run")
        .arg(&hello)
        .env("BENITOITE_DEV_PANIC", "run")
        .output()
        .unwrap_or_else(|error| panic!("could not exercise run panic: {error}"));
    assert_eq!(exit_code(&panic_run), 3);
    assert_eq!(panic_run.stdout, b"hello\n");
    assert_internal_report(&panic_run.stderr);

    let panic_json = command()
        .args(["run", "--diagnostics=json"])
        .arg(&hello)
        .env("BENITOITE_DEV_PANIC", "check")
        .output()
        .unwrap_or_else(|error| panic!("could not exercise JSON internal report: {error}"));
    assert_eq!(exit_code(&panic_json), 3);
    let json_stderr = String::from_utf8_lossy(&panic_json.stderr);
    assert!(
        json_stderr.starts_with("{\"kind\":\"internal\",\"severity\":\"error\",\"code\":null,"),
        "{json_stderr}"
    );
    assert_eq!(json_stderr.lines().count(), 1, "{json_stderr}");

    #[cfg(unix)]
    broken_pipe_is_a_runtime_error(&directory);

    #[cfg(unix)]
    invalid_utf8_argument_stops_before_main(&hello);
}

fn command() -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_benitoite"));
    command
        .env_remove("BENITOITE_DEV_PANIC")
        .env_remove("BENITOITE_DEV_IO_MODE")
        .env_remove("NO_COLOR");
    command
}

fn exit_code(output: &Output) -> i32 {
    output.status.code().unwrap_or(-1)
}

fn assert_internal_report(stderr: &[u8]) {
    let text = String::from_utf8_lossy(stderr);
    assert!(text.starts_with("internal error"), "{text}");
    assert!(text.to_ascii_lowercase().contains("internal"), "{text}");
    assert!(
        !text.contains("panicked at"),
        "panic hook output preceded the report: {text}"
    );
}

#[cfg(unix)]
fn broken_pipe_is_a_runtime_error(directory: &TestDirectory) {
    let payload = "x".repeat(80 * 1024);
    let script = directory.write(
        "broken-pipe.bnt",
        &format!("fn main() -> Unit uses IO {{\n    Console.print(\"{payload}\")\n}}\n"),
    );
    let mut child: Child = command()
        .arg("run")
        .arg(&script)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|error| panic!("could not start broken-pipe child: {error}"));
    let Some(reader) = child.stdout.take() else {
        panic!("child stdout was not piped");
    };
    drop(reader);
    let output = child
        .wait_with_output()
        .unwrap_or_else(|error| panic!("could not wait for broken-pipe child: {error}"));
    assert_eq!(exit_code(&output), 1);
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("R0201"), "{stderr}");
}

#[cfg(unix)]
fn invalid_utf8_argument_stops_before_main(script: &Path) {
    use std::os::unix::ffi::OsStrExt;

    let invalid = OsStr::from_bytes(b"\xff");
    let output = command()
        .arg("run")
        .arg(script)
        .arg(invalid)
        .output()
        .unwrap_or_else(|error| panic!("could not pass invalid UTF-8 argument: {error}"));
    assert_eq!(exit_code(&output), 1);
    assert!(output.stdout.is_empty());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("R0301"), "{stderr}");
}

struct TestDirectory {
    path: PathBuf,
}

impl TestDirectory {
    fn new() -> TestDirectory {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |duration| duration.as_nanos());
        let path = std::env::temp_dir().join(format!(
            "benitoite-cli-process-{}-{timestamp}",
            std::process::id()
        ));
        fs::create_dir(&path).unwrap_or_else(|error| {
            panic!(
                "could not create CLI test directory {}: {error}",
                path.display()
            );
        });
        TestDirectory { path }
    }

    fn path(&self) -> &Path {
        &self.path
    }

    fn write(&self, name: &str, contents: &str) -> PathBuf {
        let path = self.path.join(name);
        fs::write(&path, contents).unwrap_or_else(|error| {
            panic!(
                "could not write CLI test script {}: {error}",
                path.display()
            );
        });
        path
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        match fs::remove_dir_all(&self.path) {
            Ok(()) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(_) => {}
        }
    }
}
