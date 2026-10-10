//! L13 の標準入出力と取り消しを公開の実行経路で確かめる
//! （設計書 03-07「Process」、02-09「タスクの待ちと取り消し」）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]

use benitoite::bytecode::program::CompiledProgram;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

struct TestDirectory(PathBuf);
impl TestDirectory {
    fn new() -> Self {
        // テストが作るファイルも作業ディレクトリ内に置く。排他的な作成で並列の衝突を防ぐ。
        let base = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../target/l13-tests");
        std::fs::create_dir_all(&base).unwrap();
        let base = base.canonicalize().unwrap();
        for serial in 0..10000 {
            let path = base.join(format!("{}-{serial}", std::process::id()));
            match std::fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(e) => panic!("create test directory: {e}"),
            }
        }
        panic!("test directory names exhausted")
    }
}
impl Drop for TestDirectory {
    fn drop(&mut self) {
        // テスト失敗による巻き戻し中も、後片付けの失敗で二重に panic しない。
        let _cleanup = std::fs::remove_dir_all(&self.0);
    }
}

fn wait_for_marker(path: &Path, expected: &[u8]) {
    let started = Instant::now();
    loop {
        let contents = std::fs::read(path);
        if contents.as_deref().is_ok_and(|bytes| bytes == expected) {
            return;
        }
        assert!(
            started.elapsed() < Duration::from_secs(5),
            "marker not ready: {}: {contents:?}",
            path.display()
        );
        std::thread::sleep(Duration::from_millis(10));
    }
}

fn compile(source: &str) -> CompiledProgram {
    let checked = pipeline::check_text(
        "l13.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}

fn capture(program: &CompiledProgram, mode: ExecMode, directory: &Path) -> (String, String) {
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let result = run::run_program(
        program,
        RunEnv {
            input: RunInput {
                arguments: vec![],
                working_directory: directory.to_owned(),
                script_directory: directory.to_owned(),
            },
            // Bytes は runAttached に継がせない。子が空の入力を読むことを出力で確かめる。
            stdin: StdinSource::Bytes(b"script stdin must not reach child".to_vec()),
            stdout: OutputTarget::Capture(Arc::clone(&stdout)),
            stderr: OutputTarget::Capture(Arc::clone(&stderr)),
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode,
            vm: VmConfig::default(),
            heap: HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
            dev_panic_after_first_write: false,
        },
    );
    assert_eq!(result.end, EndKind::Returned, "{result:?}");
    assert_eq!(result.exit_code, 0, "{result:?}");
    assert!(result.main_error.is_none(), "{result:?}");
    assert!(result.reports.is_empty(), "{result:?}");
    (
        String::from_utf8(stdout.lock().unwrap().clone()).unwrap(),
        String::from_utf8(stderr.lock().unwrap().clone()).unwrap(),
    )
}

// 関門: レコードの欄の対応、出力の転送の順、継がせない入力、UTF-8 の置換を守る。
// 本体を呼ぶ単体テストでは、RunEnv のつなぎ先と送り出しの待ちの退行を捕まえない。
#[test]
fn captured_attached_output_follows_console_and_uses_command_input() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Process.Run,Console.Write
 bind output <- try Process.run(Process.command("sh", ["-c", "printf out; printf err >&2; exit 7"])) |> Result.mapError(_, IOError.message)
 if Process.Output.exitCode(output) <> 7 or Process.Output.standardOutput(output) <> "out"
    or Process.Output.standardError(output) <> "err" then
  return Result.Error("output fields")
 end if
 Console.write("before ")
 bind empty <- try Process.runAttached(Process.command("cat", [])) |> Result.mapError(_, IOError.message)
 if empty <> 0 then return Result.Error("empty input") end if
 bind cmd <- Process.Command(..Process.command("cat", []), input: Option.Some("payload "))
 bind status <- try Process.runAttached(cmd) |> Result.mapError(_, IOError.message)
 if status <> 0 then return Result.Error("command input") end if
 bind invalid <- try Process.runAttached(Process.command("sh", ["-c", "printf '\\377'; printf 'err\\377' >&2; exit 7"])) |> Result.mapError(_, IOError.message)
 if invalid <> 7 then return Result.Error("attached nonzero exit") end if
 Console.write(" after")
 return Result.Ok(())
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let (stdout, stderr) = capture(&program, mode, Path::new("/"));
        assert_eq!(stdout, "before payload � after");
        assert_eq!(stderr, "err�");
    }
}

// 関門: バッファの上限を超える一回の出力を受け付けた後も、次の Console.write に追い越されない。
// 空のバッファは大きな出力を受け付け、転送中の後続の書き込みは待つ（設計書 02-09「出力のバッファ」）。
#[test]
fn attached_output_larger_than_buffer_keeps_later_writes_in_order() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Process.Run,Console.Write
 Console.write("before ")
 bind status <- try Process.runAttached(Process.command("sh", ["-c", "i=0; while [ \"$i\" -lt 131072 ]; do printf abcdefghABCDEFGH; i=$((i+1)); done"])) |> Result.mapError(_, IOError.message)
 if status <> 0 then return Result.Error("child failed") end if
 Console.write(" after")
 return Result.Ok(())
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let (stdout, stderr) = capture(&program, mode, Path::new("/"));
        assert_eq!(
            stdout,
            format!("before {} after", "abcdefghABCDEFGH".repeat(131072))
        );
        assert!(stderr.is_empty());
    }
}

// 関門: 継がせる場合は CLI の別プロセスで確かめる。単体テストの出力のパイプを子に残さない。
// input の指定の有無で、CLI の標準入力と Command の入力の優先順位を出力で区別する。
#[test]
fn cli_attached_inherits_streams_and_command_input_overrides_stdin() {
    let directory = TestDirectory::new();
    for (input, expected) in [
        ("Option.None", "cli input"),
        ("Option.Some(\"command input\")", "command input"),
    ] {
        let source = format!(
            r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Process.Run,Console.Write
 Console.write("before ")
 bind cmd <- Process.Command(..Process.command("sh", ["-c", "cat; printf child-error >&2"]), input: {input})
 bind status <- try Process.runAttached(cmd) |> Result.mapError(_, IOError.message)
 if status <> 0 then return Result.Error("child failed") end if
 Console.write(" after")
 return Result.Ok(())
end function
"#
        );
        let path = directory.0.join("attached.bnt");
        std::fs::write(&path, source).unwrap();
        for mode in ["direct", "request"] {
            let mut child = Command::new(env!("CARGO_BIN_EXE_benitoite"))
                .env("BENITOITE_DEV_IO_MODE", mode)
                .arg("run")
                .arg(&path)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .unwrap();
            child.stdin.take().unwrap().write_all(b"cli input").unwrap();
            let output = child.wait_with_output().unwrap();
            assert_eq!(output.status.code(), Some(0), "{output:?}");
            assert_eq!(output.stdout, format!("before {expected} after").as_bytes());
            assert_eq!(output.stderr, b"child-error");
        }
    }
}

// 関門: Rust の SIGPIPE の扱いが CLI でも保たれ、閉じた入力への書き込みで処理系が終了しない。
// 本体の単体テストだけでは CLI の起動時にシグナルの扱いを変える退行を捕まえない。
#[test]
fn cli_survives_child_closing_input_early() {
    let directory = TestDirectory::new();
    let path = directory.0.join("closed-input.bnt");
    std::fs::write(&path, r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Process.Run,Console.Write
 bind cmd <- Process.Command(..Process.command("sh", ["-c", "exit 0"]), input: Option.Some(String.repeat("x",1048576)))
 bind output <- try Process.run(cmd) |> Result.mapError(_, IOError.message)
 if Process.Output.exitCode(output) <> 0 then return Result.Error("child failed") end if
 Console.write("continued")
 return Result.Ok(())
end function
"#).unwrap();
    for mode in ["direct", "request"] {
        let output = Command::new(env!("CARGO_BIN_EXE_benitoite"))
            .env("BENITOITE_DEV_IO_MODE", mode)
            .arg("run")
            .arg(&path)
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(0), "{output:?}");
        assert_eq!(output.stdout, b"continued");
        assert!(output.stderr.is_empty(), "{output:?}");
    }
}

// 関門: 本物の仕事が起動してから時間切れになり、実行が子より先に終わることを守る。
// 仮想の時間は子を待つ実際の仕事を進められない。このテストだけ、実時間の待ちに頼らない方針の例外として実時間の待ちを使う。
// 子が後で完了の印を書くことも確かめ、取り消しで子を終わらせる退行を捕まえる。
#[test]
fn timeout_returns_before_child_finishes_and_child_is_not_terminated() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit,String] uses Process.Run,Console.Write,Clock.Time,State
 bind result <- Task.withTimeout(100, lambda()
  return Process.run(Process.command("sh", ["-c", "printf started > started; sleep 3; printf survived > finished"]))
 end lambda)
 match result with
 case Option.None -> Console.write("continued")
 case Option.Some(_) -> return Result.Error("child finished before timeout")
 end match
 return Result.Ok(())
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let directory = TestDirectory::new();
        let started = Instant::now();
        let (stdout, stderr) = capture(&program, mode, &directory.0);
        let elapsed = started.elapsed();
        assert_eq!(stdout, "continued");
        assert!(stderr.is_empty());
        assert!(
            elapsed < Duration::from_secs(2),
            "runtime waited for child: {elapsed:?}"
        );
        wait_for_marker(&directory.0.join("started"), b"started");
        assert!(!directory.0.join("finished").exists());
        wait_for_marker(&directory.0.join("finished"), b"survived");
    }
}
