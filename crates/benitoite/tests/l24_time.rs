//! Time の欄のアクセサと鍵の型の契約（設計書 03-08「Time」、実装プラン L24）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]

// 関門: 欄の宣言順と鍵としての利用を、本物の型検査・脱糖・実行で確かめる。
// 単体テストでは欄のアクセサと鍵の辞書の退行には届かない。
// 本番の差し込み口を加えず、回収の強制と二つの IO の方式で通す。
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::testing::ScheduleHandle;
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

fn run_script(source: &str) {
    let checked = pipeline::check_text(
        "l24.bnt",
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
        let script = ScheduleHandle::new([], false);
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
        assert_eq!(result.end, EndKind::Returned, "{mode:?}: {result:?}");
        assert_eq!(result.exit_code, 0, "{mode:?}: {result:?}");
        assert!(result.main_error.is_none(), "{mode:?}: {result:?}");
        assert!(result.reports.is_empty(), "{mode:?}: {result:?}");
    }
}

#[test]
fn record_accessors_and_map_keys_follow_source_declarations() {
    run_script(
        r#"
import Benitoite.Unofficial.Time
function main() -> Result[Unit, String]
  bind t <- Time.fromUnixMilliseconds(1_790_566_496_789)
  if Time.Instant.unixNanoseconds(t) <> 1_790_566_496_789_000_000 then
    return Result.Error("Instant field")
  end if
  bind dt <- Time.toDateTime(t, 540)
  if Time.DateTime.year(dt) <> 2026 or Time.DateTime.month(dt) <> 9
    or Time.DateTime.day(dt) <> 28 or Time.DateTime.hour(dt) <> 12
    or Time.DateTime.minute(dt) <> 34 or Time.DateTime.second(dt) <> 56
    or Time.DateTime.nanosecond(dt) <> 789_000_000
    or Time.DateTime.offsetMinutes(dt) <> 540 then
    return Result.Error("DateTime fields")
  end if
  bind other <- Time.Instant(unixNanoseconds: 1_790_566_496_789_000_001)
  bind instants <- Map.fromList([Pair(other, "next"), Pair(t, "instant")])
  if Map.size(instants) <> 2 or Map.get(instants, t) <> Option.Some("instant")
    or Map.get(instants, other) <> Option.Some("next") then
    return Result.Error("Instant keys")
  end if
  bind same <- Time.DateTime(year: 2026, month: 9, day: 28, hour: 12,
    minute: 34, second: 56, nanosecond: 789_000_000, offsetMinutes: 540)
  if Time.fromDateTime(same) <> Result.Ok(t) then
    return Result.Error("DateTime input fields")
  end if
  bind changed <- Time.DateTime(..same, nanosecond: 789_000_001)
  bind dates <- Map.fromList([Pair(changed, "next"), Pair(dt, "date")])
  if Map.size(dates) <> 2 or Map.get(dates, same) <> Option.Some("date")
    or Map.get(dates, changed) <> Option.Some("next") then
    return Result.Error("DateTime keys")
  end if
  return Result.Ok(())
end function
"#,
    );
}
