#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
//! CLI を別プロセスで起動し、終了状態と標準入出力を確かめる
//! （設計書 07-03「前提」、実装プラン C05「CLI の切り替え」）。
// テストの失敗は panic で表すため、テストコードではこれらを許す（実装規約 00-02「#[allow] を書いてよい箇所」）。

use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

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
                "function take[T](x: T, y: T12) -> T12\n return y\nend function\nfunction mismatch(x: T12) -> Integer\n return take(x, x)\nend function\n",
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
        source.push_str(&format!("type T{i} = function(T{}) -> T{}\n", i - 1, i - 1));
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
    let script = directory.write(
        "broken-pipe.bnt",
        &format!("import Benitoite.Unofficial.IO.Console\n\nfunction main() -> Unit uses Console.Write\n    Console.write(\"{payload}\")\nend function\n"),
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
