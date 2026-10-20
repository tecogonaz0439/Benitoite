//! ブロック式の値・制御と局所操作の評価順を実行の境界で確かめる（設計書 01-02）。
// テストの失敗の表現を許す（AGENTS.md「実装の規約」）。
#![allow(clippy::unwrap_used, clippy::panic)]
use super::*;
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use std::sync::{Arc, Mutex};

// 関門: block の脱糖でラムダや return の境界を増やす退行、最後の値の欠落、
// ガードの巻き戻しや説明の先行/重複評価を固定した結果で検出する。
// spec: 01-02 ブロック式
#[test]
fn block_values_returns_guards_and_die_reach_vm_and_reference() {
    let imports = "import Benitoite.StringBuilder\nimport Benitoite.ListBuilder\nimport Benitoite.BytesBuilder\nimport Benitoite.Bytes\nimport Benitoite.Unofficial.IO.Process\neffect Pause\n function pause() -> Unit\nend effect\n";
    let cases = [
        (
            "values",
            "",
            "bind n <- 1\n bind xs <- [block bind x <- 2\n x end block, block 3 end block + 1]\n bind f <- block lambda(x: Integer) return x + 1 end lambda end block\n bind unit <- block bind x <- 1 end block\n bind empty <- block end block\n return if xs = [2,4] and f(block 8 end block) = 9 and unit = () and empty = () then \"ok\" else \"wrong\" end if",
            "ok",
        ),
        (
            "scope",
            "",
            "bind n <- 1\n bind x <- block shadow n <- 2\n n end block\n return if x = 2 and n = 1 then \"ok\" else \"wrong\" end if",
            "ok",
        ),
        (
            "return",
            "",
            "bind n <- block if true then return \"ok\" end if\n 9 end block\n return \"wrong\"",
            "ok",
        ),
        ("return operand", "", "return block \"ok\" end block", "ok"),
        (
            "try return",
            "",
            "bind r <- block bind _ <- try Result.Error(\"ok\") or return\n Result.Ok(()) end block\n return r",
            "ok",
        ),
        (
            "lambda return",
            "",
            "bind f <- lambda() block return \"ok\" end block end lambda\n return f()",
            "ok",
        ),
        (
            "lazy",
            "",
            "bind x <- lazy block bind n <- 2\n n + 3 end block end lazy\n return if Lazy.force(x) = 5 then \"ok\" else \"wrong\" end if",
            "ok",
        ),
        (
            "builders",
            "",
            "bind b: StringBuilder <- StringBuilder.new()\n bind text <- block\n StringBuilder.append(builder: b, text: \"a\")\n bind bs: BytesBuilder <- BytesBuilder.new()\n BytesBuilder.append(builder: bs, value: 0x01u8)\n bind ls: ListBuilder[Integer] <- ListBuilder.new()\n ListBuilder.append(builder: ls, value: 2)\n if Bytes.toList(BytesBuilder.copy(bs)) = [0x01u8] and ListBuilder.copy(ls) = [2] then StringBuilder.copy(b) else \"wrong\" end if\n end block\n StringBuilder.append(builder: b, text: \"b\")\n return if text = \"a\" and StringBuilder.copy(b) = \"ab\" then \"ok\" else \"wrong\" end if",
            "ok",
        ),
        (
            "handler block resume",
            "",
            "bind b: StringBuilder <- StringBuilder.new()\n bind _ <- handle\n block StringBuilder.append(builder: b, text: \"a\")\n pause() end block\n StringBuilder.append(builder: b, text: \"b\")\n with case pause() -> block resume(()) end block end handle\n return StringBuilder.copy(b)",
            "ab",
        ),
        (
            "ordinary State",
            "uses State",
            "bind r <- block Reference.new(1) end block\n Reference.set(reference: r, value: 2)\n return if Reference.get(r) = 2 then \"ok\" else \"wrong\" end if",
            "ok",
        ),
    ];
    for (name, effects, body, expected) in cases {
        let (ret, result) = if name == "try return" {
            ("Result[Unit, String]", "build()")
        } else {
            ("String", "Result.Error(build())")
        };
        let source = format!(
            "{imports}\nfunction build() -> {ret} {effects}\n{body}\nend function\nfunction main() -> Result[Unit, String] {effects}\n return {result}\nend function\n"
        );
        check_execution(name, &source, expected, None);
    }
    check_execution(
        "guard order",
        include_str!("../desugar_export/batch4/block-guards.bnt"),
        "gh/ghi/i",
        None,
    );
    for message in [
        "StringBuilder.copy(b)",
        "block StringBuilder.append(builder: b, text: \"d\")\n StringBuilder.copy(b) end block",
    ] {
        for success in [false, true] {
            let result = if success {
                "Result.Ok(())"
            } else {
                "Result.Error(\"error\")"
            };
            let source = format!(
                "{imports}\nfunction checked(result: Result[Unit, String]) -> String uses Process.Exit\n bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(builder: b, text: \"context\")\n bind _ <- try result or die({message})\n return StringBuilder.copy(b)\nend function\nfunction main() -> Result[Unit, String] uses Process.Exit\n return Result.Error(checked({result}))\nend function\n"
            );
            let stderr = if success {
                None
            } else if message.starts_with("block") {
                Some("contextd")
            } else {
                Some("context")
            };
            check_execution("die explanation", &source, "context", stderr);
        }
    }
}

fn check_execution(name: &str, source: &str, expected: &str, die: Option<&str>) {
    let checked = pipeline::check_text(
        name,
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
    assert!(benitoite::ir::check::check_program(&core).is_empty());
    let program = pipeline::compile(&core, Arc::clone(&checked.sources)).unwrap();
    benitoite::bytecode::verify::verify(&program).unwrap();
    let input = RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    };
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let stderr = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(
            &program,
            RunEnv {
                input: input.clone(),
                stdin: StdinSource::Empty,
                stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
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
        assert_eq!(end.exit_code, 1, "{name}/{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{name}: {end:?}");
        if let Some(message) = die {
            assert_eq!(end.end, EndKind::Exited(1), "{name}: {end:?}");
            assert_eq!(
                end.die_failure.as_ref().unwrap().message.as_deref(),
                Some(message)
            );
            assert!(stderr.lock().unwrap().is_empty());
        } else {
            assert_eq!(end.main_error.as_deref(), Some(expected), "{name}: {end:?}");
            assert!(stderr.lock().unwrap().is_empty());
        }
    }
    match differential::compare(
        checked.program.unwrap(),
        checked.sources,
        input,
        VmConfig::default(),
        ExecMode::Direct,
        differential::CompareOptions::default(),
        Box::new(|| Ok(())),
    ) {
        differential::Comparison::Matched => {}
        differential::Comparison::Failed(reason) | differential::Comparison::Excluded(reason) => {
            panic!("{name}: {reason}")
        }
    }
}
