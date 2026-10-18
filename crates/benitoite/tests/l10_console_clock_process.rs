//! Console・Process・Clock のソースの関数・レコードの欄と、OS の時計を公開の経路で確かめる
//! （設計書 03-07「Process」「Clock」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::panic)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::testing::ScheduleHandle;
use benitoite::vm::{ExecMode, VmConfig};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

// 関門: Process.command の既定の値とレコード更新、組み込みが作った Instant の欄を
// ソースのアクセサで読む。単体テストでは検出できない欄の並びとソースの関数の退行を守る。
#[test]
fn command_defaults_record_update_and_instant_accessor() {
    let source = r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Clock
import Benitoite.Unofficial.Time
function main() -> Result[Unit,String] uses Clock.Time
 bind cmd <- Process.command(program: "git", arguments: ["status"])
 if Process.Command.program(cmd) <> "git" or Process.Command.arguments(cmd) <> ["status"]
    or Process.Command.workingDirectory(cmd) <> Option.None
    or Process.Command.environment(cmd) <> Map.empty()
    or Process.Command.input(cmd) <> Option.None then
  return Result.Error("command defaults")
 end if
 bind changed <- Process.Command(..cmd, workingDirectory: Option.Some("./sub"))
 if Process.Command.program(changed) <> Process.Command.program(cmd)
    or Process.Command.arguments(changed) <> Process.Command.arguments(cmd)
    or Process.Command.environment(changed) <> Process.Command.environment(cmd)
    or Process.Command.input(changed) <> Process.Command.input(cmd)
    or Process.Command.workingDirectory(changed) <> Option.Some("./sub")
    or Process.Command.workingDirectory(cmd) <> Option.None then
  return Result.Error("record update")
 end if
 return if Time.Instant.unixNanoseconds(Clock.now()) = 123_000_000 then Result.Ok(()) else Result.Error("instant field") end if
end function
"#;
    let checked = pipeline::check_text(
        "l10.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false).with_clock(123, 540);
        let result = run::run_program(
            &program,
            RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: "/".into(),
                    script_directory: "/".into(),
                },
                stdin: StdinSource::Empty,
                stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                interrupt: Box::new(NoInterrupt),
                parts: Some(script.parts()),
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
    }
}

struct ScriptDirectory(PathBuf);
impl ScriptDirectory {
    fn new() -> Self {
        let base = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../target/l10-tests");
        std::fs::create_dir_all(&base).unwrap();
        for serial in 0..10000 {
            let path = base.join(format!("{}-{serial}", std::process::id()));
            match std::fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => panic!("create script directory: {error}"),
            }
        }
        panic!("script directory names exhausted")
    }
}
impl Drop for ScriptDirectory {
    fn drop(&mut self) {
        // 巻き戻しの途中で二度目の panic を起こさない。
        let _removed = std::fs::remove_dir_all(&self.0);
    }
}

// 関門: TZ はプロセス全体の入力なので、子プロセスだけで指定して本物の時計を通す。
// 仮想の時計の単体テストでは、jiff の機能指定や OS のデータの探索の誤りを捕まえない。
#[test]
fn real_clock_reads_tz_without_changing_parent_environment() {
    let directory = ScriptDirectory::new();
    let path = directory.0.join("offset.bnt");
    std::fs::write(
        &path,
        r#"
import Benitoite.Unofficial.IO.Clock
import Benitoite.Unofficial.IO.Console
function main() -> Unit uses Clock.Time,Console.Write
 Console.writeLine(Integer.toString(Clock.localOffsetMinutes()))
end function
"#,
    )
    .unwrap();
    let tokyo = if std::path::Path::new("/usr/share/zoneinfo/Asia/Tokyo").exists() {
        "540\n"
    } else {
        "0\n"
    };
    for (tz, expected) in [
        ("UTC", "0\n"),
        ("Asia/Tokyo", tokyo),
        ("/benitoite-missing-zoneinfo", "0\n"),
    ] {
        let output = std::process::Command::new(env!("CARGO_BIN_EXE_benitoite"))
            .env("TZ", tz)
            .env_remove("TZDIR")
            .args(["run"])
            .arg(&path)
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(0), "TZ={tz}: {output:?}");
        assert!(output.stderr.is_empty(), "TZ={tz}: {output:?}");
        assert_eq!(output.stdout, expected.as_bytes(), "TZ={tz}");
    }
}

// 関門: 通常ソースの toResult が捨てる継続と、OS の解放失敗をつなぐ。
// 制限は子プロセスだけに設定し、標準のソースや VM にテスト用の口を増やさない。
#[cfg(unix)]
#[test]
fn result_conversion_does_not_hide_release_failure_or_die() {
    let directory = ScriptDirectory::new();
    let path = directory.0.join("failure-cleanup.bnt");
    for (action, expected) in [
        ("return Failure.raise(error: \"original\")", "R0401"),
        ("return 7", "R0401"),
        (
            "bind missing: Option[Integer] <- Option.None\n return try missing or die(\"die inside conversion\")",
            "die",
        ),
    ] {
        let source = format!(
            r#"import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Unit uses File.Write, State, Process.Exit, Console.Write
 bind result: Result[Integer, String] <- Failure.toResult(body: lambda()
  with outer = try File.openWriter(path: "outer", mode: File.WriteMode.Replace) or die,
       inner = try File.openWriter(path: "inner", mode: File.WriteMode.Replace) or die do
   bind _ <- try File.write(writer: outer, text: "outer buffered") or die
   bind _ <- try File.write(writer: inner, text: "inner buffered") or die
   {action}
  end with
 end lambda)
 Console.writeLine("unexpected normal result")
end function
"#
        );
        std::fs::write(&path, source).unwrap();
        for mode in ["direct", "request"] {
            let output = std::process::Command::new("/bin/sh")
                .args([
                    "-c",
                    "ulimit -f 0 || exit 125; trap '' XFSZ; exec \"$@\"",
                    "f2",
                ])
                .arg(env!("CARGO_BIN_EXE_benitoite"))
                .args(["run", "--diagnostics=json"])
                .arg(&path)
                .current_dir(&directory.0)
                .env("BENITOITE_DEV_IO_MODE", mode)
                .env_remove("BENITOITE_DEV_PANIC")
                .output()
                .unwrap();
            assert_eq!(output.status.code(), Some(1), "{action}/{mode}: {output:?}");
            assert!(output.stdout.is_empty(), "{output:?}");
            let reports: Vec<serde_json::Value> = String::from_utf8(output.stderr)
                .unwrap()
                .lines()
                .map(|line| serde_json::from_str(line).unwrap())
                .collect();
            if expected == "die" {
                assert_eq!(reports.len(), 3, "{reports:?}");
                assert_eq!(reports.first().unwrap()["kind"], "die");
                assert_eq!(
                    reports.first().unwrap()["notes"],
                    serde_json::json!([
                        "message: die inside conversion",
                        "cause: expected a value, got Option.None"
                    ])
                );
            } else {
                assert_eq!(reports.len(), 1, "{reports:?}");
                assert_eq!(reports.first().unwrap()["code"], expected);
                let failures: Vec<_> = reports.first().unwrap()["notes"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .filter_map(|note| note.as_str())
                    .filter(|note| note.contains("failed to release"))
                    .collect();
                assert_eq!(failures.len(), 2, "{failures:?}");
                for (failure, opened_line) in failures.iter().zip([8, 7]) {
                    assert!(failure.contains(&format!(":{opened_line}:")), "{failure}");
                }
            }
            for (report, opened_line) in reports.iter().skip(1).rev().zip([7, 8]) {
                assert_eq!(report["code"], "R0401", "{report}");
                assert!(
                    report["message"]
                        .as_str()
                        .unwrap()
                        .contains(&format!(":{opened_line}:")),
                    "{report}"
                );
            }
            for file in ["outer", "inner"] {
                assert_eq!(std::fs::read(directory.0.join(file)).unwrap(), b"");
            }
        }
    }
}
