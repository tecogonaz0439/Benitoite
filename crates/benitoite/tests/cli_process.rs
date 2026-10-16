#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
//! CLI を別プロセスで起動し、終了状態と標準入出力を確かめる
//! （設計書 07-03「前提」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。

use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

// 作成時の関門: run のゴールデンでは届かない check と test の段の選択を守る。
// 公開の CLI と実ファイルを使い、時刻や本番の差し込み口には依存しない。
#[test]
fn decision_tree_limit_is_reported_by_test_but_not_check() {
    let directory = TestDirectory::new();
    let script = directory.write(
        "tree-budget.bnt",
        include_str!("../testdata/patterns/todo195-decision-tree-budget.bnt"),
    );
    for (mode, expected) in [("check", 0), ("test", 2)] {
        let output = command().arg(mode).arg(&script).output().unwrap();
        assert_eq!(exit_code(&output), expected, "{mode}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        if mode == "check" {
            assert!(stderr.is_empty(), "{stderr}");
        } else {
            assert!(stderr.contains("L0112"), "{stderr}");
            assert!(!stderr.contains("internal"), "{stderr}");
            assert!(
                stderr.lines().any(|line| line.contains("could not test")
                    && line.contains("due to 1 previous error")),
                "{stderr}"
            );
        }
    }
}

#[test]
fn cli_process_contracts() {
    let directory = TestDirectory::new();
    let hello = directory.write(
        "hello.bnt",
        "import Benitoite.Unofficial.IO.Console\n\nfunction main() -> Unit uses Console.Write\n    Console.writeLine(\"hello\")\nend function\n",
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
    let (major, minor, patch) = char::UNICODE_VERSION;
    assert_eq!(
        String::from_utf8_lossy(&version.stdout),
        format!(
            "benitoite {}\nUnicode {major}.{minor}.{patch}\n",
            env!("CARGO_PKG_VERSION")
        )
    );

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
    let text = String::from_utf8_lossy(&panic_check.stderr);
    assert!(
        text.contains("the panic occurred in the compiler thread"),
        "{text}"
    );
    assert_eq!(
        text.matches("BENITOITE_DEV_PANIC=check").count(),
        1,
        "{text}"
    );

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

// 関門: 道具の本体の外側の panic を、終了状態・段・診断形式まで確かめる。
// run/check の既存の例ではこの境界と JSON への hook 出力の混入を捕まえられない。
// 設計書 07-03 が指定する開発用の panic を使い、CLI を本物のプロセスで起動する。
#[test]
fn tool_panics_are_internal_reports() {
    let directory = TestDirectory::new();
    for (stage, args, json) in [
        ("skill", vec!["skill", "install", "--project"], false),
        ("test", vec!["test", "missing.bnt"], false),
        ("fmt", vec!["fmt", "missing.bnt"], false),
        ("package", vec!["package", "update"], false),
        (
            "package",
            vec!["package", "update", "--diagnostics=json"],
            true,
        ),
        (
            "test",
            vec!["test", "--diagnostics=json", "missing.bnt"],
            true,
        ),
        (
            "fmt",
            vec!["fmt", "--diagnostics=json", "missing.bnt"],
            true,
        ),
    ] {
        let output = command()
            .args(args)
            .current_dir(directory.path())
            .env("HOME", directory.path())
            .env("BENITOITE_DEV_PANIC", "tool")
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 3, "{stage}: {output:?}");
        assert!(output.stdout.is_empty(), "{stage}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        if json {
            assert_eq!(stderr.lines().count(), 1, "{stderr}");
            let report: serde_json::Value = serde_json::from_str(&stderr).unwrap();
            assert_eq!(report["kind"], "internal", "{stderr}");
        } else {
            assert_internal_report(&output.stderr);
            assert!(
                stderr.contains("the panic occurred in the main thread"),
                "{stderr}"
            );
        }
        assert!(
            stderr.contains(&format!("in the {stage} stage")),
            "{stderr}"
        );
        assert!(stderr.contains("BENITOITE_DEV_PANIC=tool"), "{stderr}");
        assert!(!stderr.contains("panicked at"), "{stderr}");
    }
    assert!(!directory.path().join(".claude").exists());
}

fn exit_code(output: &Output) -> i32 {
    output.status.code().unwrap_or(-1)
}

// 関門: 宣言をまたぐ型の増大を、CLI の診断と終了状態まで確かめる。既存の構文の
// 深さのテストでは、別名の展開や型変数の解決による増大を捕まえられない。
// プロセスで確かめるので、スタックの溢れによる abort もテストの失敗になる。
// 本番の上限を下げる差し込み口は作らない（設計書 07-03「テストの設計の原則」）。
#[test]
fn expanded_type_limits() {
    let directory = TestDirectory::new();
    let cases = [
        ("depth", alias_chain(2, 500)),
        ("depth-40", alias_chain(40, 990)),
        ("depth-100", alias_chain(100, 990)),
        ("alias-doubling", doubled_aliases(30)),
        (
            "nodes-one-over",
            format!("{}type Over = List[List[T13]]\n", doubled_aliases(13)),
        ),
        ("alias-chain", alias_chain(10_000, 1)),
        ("forward-chain", forward_alias_chain(10_000)),
        ("parameter-doubling", doubled_parameter_aliases(14)),
        ("function-alias", doubled_function_aliases(14)),
        (
            "signature",
            large_signature("function wide(a: T12, b: T12, c: T12) -> Unit\nend function\n"),
        ),
        (
            "constructor",
            large_signature("data Wide\n Wide(T12, T12, T12)\nend data\n"),
        ),
        (
            "record",
            large_signature("record Wide\n a: T12\n b: T12\n c: T12\nend record\n"),
        ),
        (
            "temporary-function",
            large_signature(
                "function take[T](x: T, y: T12) -> T12\n return y\nend function\nfunction mismatch(x: T12) -> Integer\n return take(x: x, y: x)\nend function\n",
            ),
        ),
        ("inferred-doubling", doubled_bindings(18)),
    ];
    for (name, source) in cases {
        let path = directory.write(&format!("{name}.bnt"), &source);
        let output = command().arg("check").arg(path).output().unwrap();
        assert_eq!(exit_code(&output), 2, "{name}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.contains("E0208"), "{name}: {stderr}");
        assert!(
            stderr.contains("levels in a type") || stderr.contains("nodes in a type"),
            "the type checker must reject this, {name}: {stderr}"
        );
        assert!(!stderr.contains("overflowed its stack"), "{name}: {stderr}");
    }
}

// 関門: 上限ちょうどの型を拒否する退行と、検査後の単一化・最終化・表示・
// コード生成・破棄でのスタックの溢れを捕まえる。拒否のテストだけでは確認できない。
#[test]
fn expanded_types_at_the_limits_are_usable() {
    let directory = TestDirectory::new();
    let mut nodes = doubled_aliases(13); // T13 は 16,383 ノード。
    nodes.push_str("type AtLimit = List[T13]\n");
    // consume の関数型は 16,383 ノードで、そのリストの型は 16,384 ノード。
    nodes = nodes.replace(
        "function main() -> Unit\nend function",
        "function main() -> Unit\n  bind fs <- [consume]\nend function",
    );
    nodes.push_str("function consume(x: T12) -> T12\n  return x\nend function\n");
    // A2 は 999 段であり、その型を引数・戻り値に持つ関数型は 1000 段になる。
    let mut function = alias_chain(2, 499).replace(
        "function main() -> Unit\nend function",
        "function main() -> Unit\n  bind f <- identity\nend function",
    );
    function.push_str("function identity(x: A2) -> A2\n  return x\nend function\n");
    for (name, source) in [
        ("depth", alias_chain(3, 333)),
        ("forward-depth", forward_alias_chain(999)),
        ("nodes", nodes),
        ("function", function.clone()),
        ("inferred", doubled_bindings(12)),
    ] {
        let path = directory.write(&format!("{name}.bnt"), &source);
        for subcommand in ["check", "run"] {
            let output = command().arg(subcommand).arg(&path).output().unwrap();
            assert_eq!(exit_code(&output), 0, "{name} {subcommand}: {output:?}");
            assert!(output.stderr.is_empty(), "{name}: {output:?}");
        }
    }
    // 型の不一致の診断では、境界の深さの型を表示する。
    function.push_str("function mismatch(x: A2) -> Integer\n  return x\nend function\n");
    let path = directory.write("display.bnt", &function);
    let output = command().arg("check").arg(path).output().unwrap();
    assert_eq!(exit_code(&output), 2, "{output:?}");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("E0401"), "{stderr}");
    assert!(!stderr.contains("E0208"), "{stderr}");
}

fn forward_alias_chain(count: usize) -> String {
    let mut source = String::new();
    for i in 0..count {
        source.push_str(&format!("type A{i} = List[A{}]\n", i + 1));
    }
    source.push_str(&format!("type A{count} = Integer\n"));
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_parameter_aliases(count: usize) -> String {
    let mut source = String::from("type Double[T] = Pair[T, T]\ntype T0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!("type T{i} = Double[T{}]\n", i - 1));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_function_aliases(count: usize) -> String {
    let mut source = String::from("type T0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!(
            "type T{i} = function(value: T{}) -> T{}\n",
            i - 1,
            i - 1
        ));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn large_signature(declaration: &str) -> String {
    let mut source = doubled_aliases(12);
    source.push_str(declaration);
    source
}

fn alias_chain(count: usize, wrappers: usize) -> String {
    let mut source = String::from("type A0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!(
            "type A{i} = {}A{}{}\n",
            "List[".repeat(wrappers),
            i - 1,
            "]".repeat(wrappers)
        ));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_aliases(count: usize) -> String {
    let mut source = String::from("type T0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!("type T{i} = Pair[T{}, T{}]\n", i - 1, i - 1));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_bindings(count: usize) -> String {
    let mut source = String::from("function main() -> Unit\n  bind a0 <- 0\n");
    for i in 1..=count {
        source.push_str(&format!("  bind a{i} <- Pair(a{}, a{})\n", i - 1, i - 1));
    }
    source.push_str("end function\n");
    source
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
    for (ending, expected_status) in [("", 1), ("Process.exit(3)", 3)] {
        let script = directory.write(
            "broken-pipe.bnt",
            &format!("import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\n\nfunction main() -> Unit uses Console.Write, Process.Exit\n    Console.write(\"{payload}\")\n    {ending}\nend function\n"),
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
        assert_eq!(exit_code(&output), expected_status, "{ending}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.contains("R0201"), "{stderr}");
    }
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
        // macOS の時計はマイクロ秒の精度なので、並行するテストが同じ時刻を得ても名前が重ならないよう番号を足す。
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let serial = NEXT.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!(
            "benitoite-cli-process-{}-{timestamp}-{serial}",
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

// 関門: 管から渡した入口も普通のファイルに限り、E0101・終了状態 2 で拒む。
// import 用の FIFO のテストでは、入口だけ管を許してしまう退行を捕まえられない。
#[cfg(unix)]
#[test]
fn check_rejects_a_script_piped_to_dev_stdin() {
    let dir = TestDirectory::new();
    let script = dir.write("main.bnt", "function main() -> Unit\nend function\n");
    let mut cat = Command::new("cat")
        .arg(&script)
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let pipe = cat.stdout.take().unwrap();
    // 小さな入力は管の容量に収まる。先に cat を終えて、check の拒否による SIGPIPE を避ける。
    assert!(cat.wait().unwrap().success());
    let output = command()
        .args(["check", "/dev/stdin"])
        .stdin(Stdio::from(pipe))
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2);
    let err = String::from_utf8_lossy(&output.stderr);
    assert!(err.contains("E0101") && err.contains("/dev/stdin"), "{err}");
    assert!(err.contains("not a regular file"), "{err}");
    assert!(output.stdout.is_empty());
}

// 関門: 実際の FIFO を import しても、check が読めない理由を報告して終了する。
#[cfg(unix)]
#[test]
fn check_rejects_a_fifo_module_without_blocking() {
    use std::time::{Duration, Instant};
    let dir = TestDirectory::new();
    let fifo = dir.path().join("Pipe.bnt");
    assert!(
        Command::new("mkfifo")
            .arg(&fifo)
            .status()
            .unwrap()
            .success()
    );
    let entry = dir.write(
        "main.bnt",
        "import Pipe\nfunction main() -> Unit\n  ()\nend function\n",
    );
    let mut child = command()
        .arg("check")
        .arg(entry)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let started = Instant::now();
    while child.try_wait().unwrap().is_none() {
        if started.elapsed() >= Duration::from_secs(5) {
            child.kill().unwrap();
            child.wait().unwrap();
            panic!("check blocked while opening a FIFO module");
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    let output = child.wait_with_output().unwrap();
    assert_eq!(exit_code(&output), 2);
    let err = String::from_utf8_lossy(&output.stderr);
    assert!(err.contains("E0101") && err.contains("Pipe.bnt"), "{err}");
    assert!(output.stdout.is_empty());
}

// 関門: 読み込みに失敗したパスが見出しから端末の制御列を実行させない。
#[test]
fn unreadable_path_controls_are_escaped_in_the_header() {
    let directory = TestDirectory::new();
    let output = command()
        .arg("check")
        .arg(directory.path().join("missing\u{1B}[31m.bnt"))
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2);
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("error[E0101]: cannot read file `"),
        "{stderr}"
    );
    assert!(
        stderr
            .lines()
            .next()
            .unwrap()
            .contains("missing\\u{1B}[31m.bnt"),
        "{stderr}"
    );
    assert!(!stderr.contains('\u{1B}'), "{stderr}");
}

// 作成時の関門: CLI の本物の入力から終了報告までを守る。構造化した結果を直接
// 描画する lib の検査では、受理と実行の接続漏れを捕まえられない。差し込み口は不要。
#[test]
fn die_source_reports_cause_message_and_location_once() {
    let directory = TestDirectory::new();
    for (name, source, cause, message) in [
        (
            "result",
            include_str!("../testdata/eval/todo250-die-result.bnt"),
            "\"bad input\"",
            Some("loading input"),
        ),
        (
            "option",
            include_str!("../testdata/eval/todo250-die-option.bnt"),
            "expected a value, got Option.None",
            None,
        ),
    ] {
        let script = directory.write(&format!("{name}.bnt"), source);
        for json in [false, true] {
            let mut cmd = command();
            cmd.arg("run");
            if json {
                cmd.arg("--diagnostics=json");
            }
            let output = cmd.arg(&script).output().unwrap();
            assert_eq!(exit_code(&output), 1, "{output:?}");
            assert!(output.stdout.is_empty(), "{output:?}");
            let stderr = String::from_utf8(output.stderr).unwrap();
            if json {
                let lines: Vec<serde_json::Value> = stderr
                    .lines()
                    .map(|s| serde_json::from_str(s).unwrap())
                    .collect();
                assert_eq!(lines.len(), 1, "{stderr}");
                let d = &lines[0];
                assert_eq!(d["kind"], "die");
                assert!(d["code"].is_null());
                assert_eq!(d["message"], "explicit failure exit");
                let mut notes = Vec::new();
                if let Some(message) = message {
                    notes.push(format!("message: {message}"));
                }
                notes.push(format!("cause: {cause}"));
                assert_eq!(d["notes"], serde_json::json!(notes));
                assert_eq!(d["primary"]["start"]["line"], 4);
                assert_eq!(d["primary"]["file"], script.display().to_string());
            } else {
                assert_eq!(
                    stderr.matches("error: explicit failure exit").count(),
                    1,
                    "{stderr}"
                );
                assert!(stderr.contains(&format!("cause: {cause}")), "{stderr}");
                assert_eq!(stderr.contains("message: "), message.is_some(), "{stderr}");
                if let Some(message) = message {
                    assert!(stderr.contains(&format!("message: {message}")), "{stderr}");
                }
                assert!(
                    stderr.contains(&format!("{}:4:", script.display())),
                    "{stderr}"
                );
            }
        }
    }
}

// 関門: 本物の die の後に、内側からの解放と最後の出力の転送の失敗を報告する。
// 子プロセスだけのファイルサイズ制限と閉じたソケットを使い、本番に差し込み口を増やさない。
// 構造化した RunEnd の描画検査だけでは、停止・解放・転送の接続の欠落を捕まえない。
#[cfg(unix)]
#[test]
fn die_reports_precede_real_release_and_flush_failures() {
    use std::os::fd::OwnedFd;
    use std::os::unix::net::UnixStream;
    let directory = TestDirectory::new();
    let script = directory.write(
        "die-cleanup.bnt",
        r#"import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
@test
function dies() -> Unit uses File.Write, State, Console.Write, Process.Exit
 Console.write("captured before die")
 Console.writeError("captured stderr before die\n")
 with first = try File.openWriter(path: "first", mode: File.WriteMode.Replace) or die,
      second = try File.openWriter(path: "second", mode: File.WriteMode.Replace) or die do
  bind _ <- try File.write(writer: first, text: "first buffered") or die
  bind _ <- try File.write(writer: second, text: "second buffered") or die
  bind missing: Option[Unit] <- Option.None
  try missing or die("during work")
 end with
end function
@test
function after() -> Unit uses Console.Write
 Console.write("after succeeded")
end function
function main() -> Unit uses File.Write, State, Console.Write, Process.Exit
 dies()
end function
"#,
    );
    for mode in ["direct", "request"] {
        for json in [false, true] {
            for tool in ["run", "test"] {
                let mut cmd = Command::new("/bin/sh");
                // 制限の設定に失敗したまま処理系を起動しない。SIGXFSZ は IO の失敗として返させる。
                cmd.args([
                    "-c",
                    "ulimit -f 0 || exit 125; trap '' XFSZ; exec \"$@\"",
                    "b12",
                ])
                .arg(env!("CARGO_BIN_EXE_benitoite"))
                .arg(tool)
                .current_dir(directory.path())
                .env_remove("BENITOITE_DEV_PANIC")
                .env("BENITOITE_DEV_IO_MODE", mode)
                .env("NO_COLOR", "1");
                if json {
                    cmd.arg("--diagnostics=json");
                }
                cmd.arg(&script);
                if tool == "run" {
                    let (writer, reader) = UnixStream::pair().unwrap();
                    drop(reader);
                    cmd.stdout(Stdio::from(OwnedFd::from(writer)));
                }
                let output = cmd.output().unwrap();
                assert_eq!(exit_code(&output), 1, "{mode}/{json}/{tool}: {output:?}");
                // 二つの書き込みは with の解放までバッファに残っていた。
                assert_eq!(fs::read(directory.path().join("first")).unwrap(), b"");
                assert_eq!(fs::read(directory.path().join("second")).unwrap(), b"");
                let stdout = String::from_utf8(output.stdout).unwrap();
                let stderr = String::from_utf8(output.stderr).unwrap();
                if tool == "run" {
                    assert!(stdout.is_empty());
                    assert!(
                        stderr.starts_with("captured stderr before die\n"),
                        "{stderr}"
                    );
                    let reports = stderr.strip_prefix("captured stderr before die\n").unwrap();
                    if json {
                        let lines: Vec<serde_json::Value> = reports
                            .lines()
                            .map(|line| serde_json::from_str(line).unwrap())
                            .collect();
                        assert_eq!(lines.len(), 4, "{reports}");
                        assert_eq!(lines[0]["kind"], "die");
                        assert_eq!(
                            lines[0]["notes"],
                            serde_json::json!([
                                "message: during work",
                                "cause: expected a value, got Option.None"
                            ])
                        );
                        assert_eq!(lines[0]["primary"]["start"]["line"], 13);
                        for (line, opened_line) in [(&lines[1], 9), (&lines[2], 8)] {
                            assert_eq!(line["kind"], "release");
                            assert_eq!(line["code"], "R0401");
                            assert!(
                                line["message"]
                                    .as_str()
                                    .unwrap()
                                    .contains(&format!("{}:{opened_line}:", script.display())),
                                "{line}"
                            );
                        }
                        assert_eq!(lines[3]["kind"], "runtime");
                        assert_eq!(lines[3]["code"], "R0201");
                    } else {
                        assert_eq!(
                            reports.matches("error: explicit failure exit").count(),
                            1,
                            "{reports}"
                        );
                        assert_eq!(reports.matches("error[R0401]").count(), 2, "{reports}");
                        assert!(
                            reports
                                .find("cause: expected a value, got Option.None")
                                .unwrap()
                                < reports.find("R0401").unwrap()
                        );
                        assert!(reports.rfind("R0401").unwrap() < reports.find("R0201").unwrap());
                        let second = reports.find(&format!("{}:9:", script.display())).unwrap();
                        let first = reports.find(&format!("{}:8:", script.display())).unwrap();
                        assert!(second < first, "{reports}");
                    }
                } else {
                    assert!(stderr.is_empty(), "{stderr}");
                    if json {
                        let lines: Vec<serde_json::Value> = stdout
                            .lines()
                            .map(|line| serde_json::from_str(line).unwrap())
                            .collect();
                        assert_eq!(lines.len(), 3, "{stdout}");
                        let failed = &lines[0];
                        assert_eq!(failed["failure"]["reason"], "exit");
                        assert_eq!(
                            failed["failure"]["message"],
                            "called `Process.exit` with status 1"
                        );
                        assert_eq!(failed["failure"]["exitCode"], 1);
                        assert_eq!(failed["failure"]["die"]["kind"], "die");
                        assert_eq!(
                            failed["failure"]["die"]["notes"],
                            serde_json::json!([
                                "message: during work",
                                "cause: expected a value, got Option.None"
                            ])
                        );
                        let notes = failed["failure"]["notes"].as_array().unwrap();
                        assert_eq!(notes.len(), 2);
                        assert!(
                            notes[0]
                                .as_str()
                                .unwrap()
                                .contains(&format!("{}:9:", script.display())),
                            "{notes:?}"
                        );
                        assert!(
                            notes[1]
                                .as_str()
                                .unwrap()
                                .contains(&format!("{}:8:", script.display())),
                            "{notes:?}"
                        );
                        assert_eq!(failed["stdout"], "captured before die");
                        assert_eq!(failed["stderr"], "captured stderr before die\n");
                        assert_eq!(lines[1]["function"], "after");
                        assert_eq!(lines[1]["outcome"], "passed");
                        assert_eq!(lines[1]["stdout"], "after succeeded");
                        assert_eq!(lines[2]["kind"], "testSummary");
                        assert_eq!(lines[2]["passed"], 1);
                        assert_eq!(lines[2]["failed"], 1);
                        assert_eq!(lines[2]["interrupted"], false);
                    } else {
                        assert_eq!(
                            stdout.matches("error: explicit failure exit").count(),
                            1,
                            "{stdout}"
                        );
                        assert!(!stdout.contains("called `Process.exit`"), "{stdout}");
                        assert_eq!(stdout.matches("error[R0401]").count(), 2, "{stdout}");
                        assert!(
                            stdout.find(&format!("{}:9:", script.display())).unwrap()
                                < stdout.find(&format!("{}:8:", script.display())).unwrap()
                        );
                        assert!(
                            stdout
                                .find("cause: expected a value, got Option.None")
                                .unwrap()
                                < stdout.find("R0401").unwrap()
                        );
                        assert!(
                            stdout.rfind("R0401").unwrap()
                                < stdout.find("---- captured stdout ----").unwrap()
                        );
                        assert!(
                            stdout.contains("---- captured stdout ----\ncaptured before die\n"),
                            "{stdout}"
                        );
                        assert!(
                            stdout.contains(
                                "---- captured stderr ----\ncaptured stderr before die\n"
                            ),
                            "{stdout}"
                        );
                        assert!(stdout.contains("after ... ok"), "{stdout}");
                        assert!(
                            stdout.contains("test result: FAILED. 1 passed; 1 failed"),
                            "{stdout}"
                        );
                    }
                }
            }
        }
    }
}
