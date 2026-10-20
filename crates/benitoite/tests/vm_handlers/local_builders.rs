//! 局所構築器の表層から保存継続・独立参照評価までを照合する（設計書 02-08）。
// 検査の準備と失敗を表す添字・panic を許す（AGENTS.md「実装の規約」）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
use super::*;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use std::sync::{Arc, Mutex};

// 関門: 専用コアの手書き入力では検査できない、State の追加の有無・通常引数の
// 一回評価・handleFail の脱糖と専用入力の接続を、固定した期待内容と比較する。
#[test]
fn local_builders_connect_source_to_vm_and_reference() {
    let imports = "import Benitoite.StringBuilder\nimport Benitoite.ListBuilder\nimport Benitoite.BytesBuilder\nimport Benitoite.Bytes\nimport Benitoite.Unofficial.Failure\neffect Pause\n function pause() -> Unit\nend effect\n";
    let mut cases = vec![
        ("string snapshots", "", "bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: b, text: \"a\")\n bind old <- StringBuilder.copy(b)\n StringBuilder.appendAll(builder: b, texts: [\"b\", \"c\"])\n return if old = \"a\" and StringBuilder.copy(b) = \"abc\" and StringBuilder.byteLength(b) = 3 then \"ok\" else \"wrong\" end if".to_string()),
        ("list snapshots", "", "bind b: ListBuilder[Integer] <- ListBuilder.new()\n ListBuilder.append(builder: b, value: 1)\n bind old <- ListBuilder.copy(b)\n ListBuilder.appendAll(builder: b, values: [2,3])\n return if old = [1] and ListBuilder.copy(b) = [1,2,3] and ListBuilder.length(b) = 3 then \"ok\" else \"wrong\" end if".into()),
        ("bytes snapshots", "", "bind b: BytesBuilder <- BytesBuilder.new()\n BytesBuilder.append(builder: b, value: 0x01u8)\n bind old <- BytesBuilder.copy(b)\n BytesBuilder.appendAll(builder: b, bytes: Bytes.fromList([0x02u8]))\n return if Bytes.toList(old) = [0x01u8] and Bytes.toList(BytesBuilder.copy(b)) = [0x01u8,0x02u8] and BytesBuilder.length(b) = 2 then \"ok\" else \"wrong\" end if".into()),
        ("typed failure", "", "bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: b, text: \"a\")\n bind _ <- handle\n StringBuilder.append(builder: b, text: \"b\")\n Failure.raise(error: \"stop\")\n with case Failure.raise(error) -> () end handle\n return if StringBuilder.copy(b) = \"ab\" then \"ok\" else \"wrong\" end if".into()),
        ("early return", "", "bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: b, text: \"ok\")\n if true then return StringBuilder.copy(b) end if\n return \"unreachable\"".into()),
        ("ordinary State argument", "uses State", "bind cell <- Reference.new(0)\n bind b: ListBuilder[Unit] <- ListBuilder.new()\n ListBuilder.append(builder: b, value: Reference.set(reference: cell, value: Reference.get(cell) + 1))\n return if Reference.get(cell) = 1 and ListBuilder.length(b) = 1 then \"ok\" else \"wrong\" end if".into()),
    ];
    for (name, clause, tail) in [("resume", "resume(())", "abc"), ("drop", "()", "ab")] {
        cases.push((name, "", format!("bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: b, text: \"a\")\n bind _ <- handle\n StringBuilder.append(builder: b, text: \"b\")\n pause()\n StringBuilder.append(builder: b, text: \"c\")\n with case pause() -> {clause} end handle\n return if StringBuilder.copy(b) = \"{tail}\" then \"ok\" else \"wrong\" end if")));
    }
    for (name, effects, body) in cases {
        let source = format!(
            "{imports}\nfunction build() -> String {effects}\n {body}\nend function\nfunction main() -> Result[Unit, String] {effects}\n return Result.Error(build())\nend function\n"
        );
        let checked = pipeline::check_text(
            "local-builders.bnt",
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
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        assert!(
            benitoite::ir::check::check_program(&core).is_empty(),
            "{name}: {:?}",
            benitoite::ir::check::check_program(&core)
        );
        let program = pipeline::compile(&core, Arc::clone(&checked.sources)).unwrap();
        benitoite::bytecode::verify::verify(&program).unwrap();
        let input = RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        };
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let end = run::run_program(
                &program,
                RunEnv {
                    input: input.clone(),
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    interrupt: Box::new(NoInterrupt),
                    parts: None,
                    mode,
                    vm: VmConfig {
                        call_budget: 1,
                        ..VmConfig::default()
                    },
                    heap: HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                    dev_panic_after_first_write: false,
                },
            );
            assert_eq!(
                end.main_error.as_deref(),
                Some("ok"),
                "{name}/{mode:?}: {end:?}"
            );
            assert!(end.reports.is_empty(), "{name}: {end:?}");
        }
        let comparison = differential::compare(
            checked.program.unwrap(),
            checked.sources,
            input,
            VmConfig::default(),
            ExecMode::Direct,
            differential::CompareOptions::default(),
            Box::new(|| Ok(())),
        );
        match comparison {
            differential::Comparison::Matched => {}
            differential::Comparison::Failed(reason)
            | differential::Comparison::Excluded(reason) => panic!("{name}: {reason}"),
        }
    }
}
