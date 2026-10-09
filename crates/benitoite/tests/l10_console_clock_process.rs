//! L10 のソースの関数・レコードの欄と、OS の時計を公開の経路で確かめる
//! （設計書 03-07「Process」「Clock」、実装プラン L10）。
// テストの失敗は panic で表す（実装プラン 00-02）。
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
 bind cmd <- Process.command("git", ["status"])
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
        std::fs::remove_dir_all(&self.0).unwrap();
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
            .args(["run"])
            .arg(&path)
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(0), "TZ={tz}: {output:?}");
        assert!(output.stderr.is_empty(), "TZ={tz}: {output:?}");
        assert_eq!(output.stdout, expected.as_bytes(), "TZ={tz}");
    }
}
