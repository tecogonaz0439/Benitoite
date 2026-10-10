//! セルのコード生成と VM の組み合わせ（設計書 01-07「可変のセル（初回リリース版）」、実装プラン R23）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

// 関門: 型検査・脱糖・コード生成から実行した結果を確かめる。ヒープと組み込みの
// 単体テストでは UPDATE の結果、末尾再帰での枠の蓄積、循環の回収を捕まえない。
// 準備は共有し、外部の出力だけを置き換える（実装プラン R23 の受け入れテスト）。
#[test]
fn scripts_update_values_return_unit_and_release_frames_and_cycles() {
    let cases = [
        (
            "update result",
            "",
            "bind r <- Reference.new(3)\n bind u <- Reference.update(r, lambda(n: Integer) -> Integer return n + 7 end lambda)\n Reference.set(r, Reference.get(r) * 2)\n return if u = () and Reference.get(r) = 20 then Result.Ok(()) else Result.Error(\"update\") end if",
        ),
        (
            "large allocated result",
            "function grow(xs: List[Integer], n: Integer) -> List[Integer]\n if n = 0 then return xs end if\n return grow(List.append(xs, n), n - 1)\nend function\n",
            "bind r <- Reference.new([0])\n bind u <- Reference.update(r, lambda(xs: List[Integer]) -> List[Integer] return grow(xs, 2048) end lambda)\n return if u = () and List.length(Reference.get(r)) = 2049 then Result.Ok(()) else Result.Error(\"list\") end if",
        ),
        (
            "100000 updates",
            "function repeat(r: Reference[Integer], n: Integer) -> Unit uses State\n if n = 0 then return () end if\n Reference.update(r, lambda(x: Integer) -> Integer return x + 1 end lambda)\n return repeat(r, n - 1)\nend function\n",
            "bind r <- Reference.new(0)\n repeat(r, 100000)\n return if Reference.get(r) = 100000 then Result.Ok(()) else Result.Error(\"frames\") end if",
        ),
        (
            "discarded cycles",
            "data Node\n Link(Reference[Option[Node]])\nend data\nfunction cycles(n: Integer) -> Unit uses State\n if n = 0 then return () end if\n bind r <- Reference.new(Option.None)\n bind v <- Node.Link(r)\n Reference.set(r, Option.Some(v))\n return cycles(n - 1)\nend function\n",
            "cycles(10000)\n return Result.Ok(())",
        ),
    ];
    for (name, extra, body) in cases {
        let source = format!(
            "{extra}\nfunction main() -> Result[Unit, String] uses State\n {body}\nend function\n"
        );
        let checked = pipeline::check_text(
            "cells.bnt",
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
        let program = pipeline::compile(&core, checked.sources).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let env = RunEnv {
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
                vm: VmConfig {
                    max_call_stack_bytes: 8192,
                    call_budget: 3,
                },
                heap: HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                dev_panic_after_first_write: false,
            };
            let end = run::run_program(&program, env);
            assert_eq!(end.exit_code, 0, "{name}: {end:?}");
            assert!(end.main_error.is_none(), "{name}: {end:?}");
            assert!(end.reports.is_empty(), "{name}: {end:?}");
        }
    }
}
