//! Csv.ParseError の欄をソースの関数で読む（実装プラン L23、10-15）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]

// 関門: 組み込みが作ったレコードの欄の宣言順を公開のパイプラインで守る。
// 単体テストでは届かないフィールドの脱糖・アクセサの退行を捕まえる。
// 本番の差し込み口を加えず、本物の各段をつなぎ回収の強制でも走らせる。
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::testing::ScheduleHandle;
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

fn run_script(source: &str) {
    let checked = pipeline::check_text(
        "l23.bnt",
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
fn parse_error_accessors_read_the_constructed_record() {
    run_script(
        r#"
import Benitoite.Unofficial.Csv
function main() -> Result[Unit, String]
  bind valid <- match Csv.parse("first\r\n\r\n\"unfinished\nfield") with
    case Result.Error(e) -> Csv.ParseError.line(e) = 3 and Csv.ParseError.message(e) = "unclosed quoted field"
    case Result.Ok(_) -> false
  end match
  if not valid then
    return Result.Error("Csv.ParseError fields")
  end if
  return Result.Ok(())
end function
"#,
    );
}
