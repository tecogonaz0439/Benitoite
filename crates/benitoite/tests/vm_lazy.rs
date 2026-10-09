//! lazy の型検査・コード生成と VM の接続（実装プラン R22「受け入れテスト」）。

// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

// 関門: 本物のコード生成が LAZY の捕捉と FORCE の戻り先を VM に渡す契約。
// 手組みの命令だけでは、脱糖・コード生成との接続の誤りを捕まえられない。
#[test]
fn scripts_execute_nested_captured_and_repeated_lazy_bodies() {
    let cases = [
        (
            "repeated",
            "bind x <- lazy 21 * 2 end lazy\nreturn Lazy.force(x) + Lazy.force(x)",
            84,
        ),
        (
            "nested",
            "bind x <- lazy 20 end lazy\nbind y <- lazy Lazy.force(x) + 22 end lazy\nreturn Lazy.force(y)",
            42,
        ),
        (
            "closure capture",
            "bind text <- \"hello\" + \"!\"\nbind make <- lambda() return lazy String.characterCount(text) end lazy end lambda\nreturn Lazy.force(make())",
            6,
        ),
        (
            "unevaluated failure",
            "bind _ <- lazy 1 div 0 end lazy\nreturn 42",
            42,
        ),
    ];
    for (name, expression, expected) in cases {
        let source = format!(
            "function value() -> Integer\n {expression}\nend function\nfunction main() -> Result[Unit, String]\n bind answer <- value()\n return if answer = {expected} then Result.Ok(()) else Result.Error(\"wrong value\") end if\nend function\n"
        );
        let checked = pipeline::check_text(
            "lazy.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
        let compiled = pipeline::compile(&core, checked.sources).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let end = run::run_program(
                &compiled,
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
            assert_eq!(end.exit_code, 0, "{name}: {end:?}");
            assert!(end.main_error.is_none(), "{name}: {end:?}");
            assert!(end.reports.is_empty(), "{name}: {end:?}");
        }
    }
}
