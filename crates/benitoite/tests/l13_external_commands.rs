//! 外部コマンドの標準入出力と取り消しを公開の実行経路で確かめる
//! （設計書 03-07「Process」、02-09「タスクの待ちと取り消し」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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
 bind output <- try Process.run(Process.command(program: "sh", arguments: ["-c", "printf out; printf err >&2; exit 7"])) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
 if Process.Output.exitCode(output) <> 7 or Process.Output.standardOutput(output) <> "out"
    or Process.Output.standardError(output) <> "err" then
  return Result.Error("output fields")
 end if
 Console.write("before ")
 bind empty <- try Process.runAttached(Process.command(program: "cat", arguments: [])) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
 if empty <> 0 then return Result.Error("empty input") end if
 bind cmd <- Process.Command(..Process.command(program: "cat", arguments: []), input: Option.Some("payload "))
 bind status <- try Process.runAttached(cmd) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
 if status <> 0 then return Result.Error("command input") end if
 bind invalid <- try Process.runAttached(Process.command(program: "sh", arguments: ["-c", "printf '\\377'; printf 'err\\377' >&2; exit 7"])) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
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
 bind status <- try Process.runAttached(Process.command(program: "sh", arguments: ["-c", "i=0; while [ \"$i\" -lt 131072 ]; do printf abcdefghABCDEFGH; i=$((i+1)); done"])) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
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
 bind cmd <- Process.Command(..Process.command(program: "sh", arguments: ["-c", "cat; printf child-error >&2"]), input: {input})
 bind status <- try Process.runAttached(cmd) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
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
 bind cmd <- Process.Command(..Process.command(program: "sh", arguments: ["-c", "exit 0"]), input: Option.Some(String.repeat(s: "x",n: 1048576)))
 bind output <- try Process.run(cmd) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
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

// 関門: 明示したローダ変数の失敗を値として扱え、子が始まらないことを CLI から守る。
// 既存の不正入力の表は二接頭辞・失敗の文言・親と同じ値の再設定を検査しない。
// 親の環境は子の CLI にだけ渡し、テストプロセスの環境と本番 API は変えない。
#[test]
fn cli_rejects_explicit_loader_environment_before_starting_child() {
    let directory = TestDirectory::new();
    let path = directory.0.join("loader-environment.bnt");
    let invalid = "program, arguments, or environment contain invalid input";
    let cases = [
        (
            "\"sh\"",
            "[]",
            r#"[Pair("DYLD_BENITOITE_TEST", "dummy-value")]"#,
            "DYLD_BENITOITE_TEST",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_BENITOITE_TEST", "inherited-loader")]"#,
            "LD_BENITOITE_TEST",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_BENITOITE_TEST", "different-value")]"#,
            "LD_BENITOITE_TEST",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_BENITOITE_TEST", "")]"#,
            "LD_BENITOITE_TEST",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("ld_benitoite_test", "dummy-value")]"#,
            "ld_benitoite_test",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("dYlD_benitoite_test", "dummy-value")]"#,
            "dYlD_benitoite_test",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_RUN_PATH", "dummy-value")]"#,
            "LD_RUN_PATH",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_", ""), Pair("DYLD_", "")]"#,
            "DYLD_",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("ld_A", "dummy-value"), Pair("LD_A", "dummy-value"), Pair("DYLD_Z", "dummy-value"), Pair("DYLD_A", "dummy-value")]"#,
            "DYLD_A",
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("dyld_A", "dummy-value"), Pair("LD_Z", "dummy-value")]"#,
            "LD_Z",
        ),
        (
            r#""sh\u{0}""#,
            "[]",
            r#"[Pair("LD_TEST", "dummy-value")]"#,
            invalid,
        ),
        (
            "\"sh\"",
            r#"["\u{0}"]"#,
            r#"[Pair("LD_TEST", "dummy-value")]"#,
            invalid,
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_TEST", "dummy\u{0}value")]"#,
            invalid,
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_TEST=", "dummy-value")]"#,
            invalid,
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("", "dummy-value"), Pair("LD_TEST", "dummy-value")]"#,
            invalid,
        ),
        (
            "\"sh\"",
            "[]",
            r#"[Pair("LD_TEST\u{0}", "dummy-value")]"#,
            invalid,
        ),
        // 存在しない作業ディレクトリとプログラムよりも、禁止名の検査が先に完了する。
        (
            "\"./missing-command\"",
            "[]",
            r#"[Pair("LD_TEST", "dummy-value")]"#,
            "LD_TEST",
        ),
    ];
    for operation in ["run", "runAttached"] {
        let mut source = String::from(
            "import Benitoite.Unofficial.IO.Process\nimport Benitoite.Unofficial.IO.Console\n",
        );
        let mut calls = String::new();
        let mut expected = String::new();
        for (index, (program, arguments, environment, name)) in cases.iter().enumerate() {
            let working_directory = if *program == "\"./missing-command\"" {
                "Option.Some(\"missing-directory\")"
            } else {
                "Option.None"
            };
            source.push_str(&format!(
                r#"
function check{index}() -> Unit uses Process.Run,Console.Write
 bind cmd <- Process.Command(..Process.command(program: {program}, arguments: List.concatenate(xs: ["-c", "printf started > marker"], ys: {arguments})), environment: Map.fromList({environment}), workingDirectory: {working_directory})
 match Process.{operation}(cmd) with
 case Result.Ok(_) -> Console.writeLine("unexpected success")
 case Result.Error(error) ->
  if IOError.kind(error) = IOErrorKind.InvalidInput then
   Console.writeLine(IOError.message(error))
  else
   Console.writeLine("unexpected error kind")
  end if
 end match
end function
"#
            ));
            calls.push_str(&format!(" check{index}()\n"));
            if *name == invalid {
                expected.push_str(invalid);
            } else {
                expected.push_str(&format!("environment variable `{name}` cannot be set in Command.environment: names starting with DYLD_ or LD_ are not accepted"));
            }
            expected.push('\n');
        }
        source.push_str(&format!(
            "function main() -> Unit uses Process.Run,Console.Write\n{calls}end function\n"
        ));
        std::fs::write(&path, source).unwrap();
        for mode in ["direct", "request"] {
            let output = Command::new(env!("CARGO_BIN_EXE_benitoite"))
                .current_dir(&directory.0)
                .env("BENITOITE_DEV_IO_MODE", mode)
                .env("LD_BENITOITE_TEST", "inherited-loader")
                .args(["run"])
                .arg(&path)
                .output()
                .unwrap();
            assert_eq!(
                output.status.code(),
                Some(0),
                "{operation}/{mode}: {output:?}"
            );
            assert_eq!(
                String::from_utf8_lossy(&output.stdout),
                expected,
                "{operation}/{mode}"
            );
            assert!(output.stderr.is_empty(), "{operation}/{mode}: {output:?}");
            assert!(!directory.0.join("marker").exists(), "{operation}/{mode}");
        }
    }
}

// 関門: 拒否と対照に、通常変数の追加・上書きとローダ変数の継承を実際の子で確認する。
// shell にも明示設定のない環境を継がせる。実際のローダ設定や秘密は使わない。
#[test]
fn cli_preserves_inherited_loader_environment_and_allows_other_names() {
    let directory = TestDirectory::new();
    let path = directory.0.join("inherited-environment.bnt");
    for operation in ["run", "runAttached", "shell"] {
        let expression = if operation == "shell" {
            r#"Process.shell("printf '%s/%s' \"$LD_BENITOITE_TEST\" \"$BENITOITE_L13_VALUE\"")"#
                .to_owned()
        } else {
            format!(
                r#"Process.{operation}(Process.Command(..Process.command(program: "sh", arguments: ["-c", "printf '%s/%s/%s/%s/%s/%s' \"$LD_BENITOITE_TEST\" \"$BENITOITE_L13_VALUE\" \"$BENITOITE_L13_ADDED\" \"$LD\" \"$DYLD\" \"$XLD_TEST\""]), environment: Map.fromList([Pair("BENITOITE_L13_VALUE", "overwritten"), Pair("BENITOITE_L13_ADDED", "added"), Pair("LD", "short"), Pair("DYLD", "shorter"), Pair("XLD_TEST", "unanchored"), Pair("ＬＤ_TEST", "non-ascii")])))"#
            )
        };
        let display = if operation == "runAttached" {
            "Console.writeLine(Integer.toString(result))"
        } else {
            "Console.writeLine(Process.Output.standardOutput(result))"
        };
        std::fs::write(&path, format!(r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Process.Run,Console.Write
 bind result <- try {expression} |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)
 {display}
 return Result.Ok(())
end function
"#)).unwrap();
        let expected = match operation {
            "shell" => "inherited-loader/parent-value\n",
            "runAttached" => "inherited-loader/overwritten/added/short/shorter/unanchored0\n",
            _ => "inherited-loader/overwritten/added/short/shorter/unanchored\n",
        };
        for mode in ["direct", "request"] {
            let output = Command::new(env!("CARGO_BIN_EXE_benitoite"))
                .env("BENITOITE_DEV_IO_MODE", mode)
                .env("LD_BENITOITE_TEST", "inherited-loader")
                .env("BENITOITE_L13_VALUE", "parent-value")
                .env_remove("BENITOITE_L13_ADDED")
                .args(["run"])
                .arg(&path)
                .output()
                .unwrap();
            assert_eq!(
                output.status.code(),
                Some(0),
                "{operation}/{mode}: {output:?}"
            );
            assert_eq!(output.stdout, expected.as_bytes(), "{operation}/{mode}");
            assert!(output.stderr.is_empty(), "{operation}/{mode}: {output:?}");
        }
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
 bind result <- Task.withTimeout(milliseconds: 100, action: lambda()
  return Process.run(Process.command(program: "sh", arguments: ["-c", "printf started > started; sleep 3; printf survived > finished"]))
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
