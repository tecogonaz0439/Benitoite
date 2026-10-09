//! ハンドラのコード生成と VM の組み合わせ（実装プラン R20）。

// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]

use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::vm::{ExecMode, VmConfig};

// 関門: 実際の型検査・コード生成・VM をつなぐ契約。asm の検査は、コード生成が
// 節の引数や HANDLE の記述を取り違えた場合を捕まえない（R20 の受け入れテスト）。
#[test]
fn scripts_connect_real_codegen_to_handlers_and_runtime() {
    use benitoite::pipeline::{self, CheckOptions};
    use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
    use std::sync::{Arc, Mutex};
    let declarations = "effect Test\n function ask(n: Integer) -> Integer\nend effect\n";
    let cases = [
        (
            "call result across handle",
            "function word() -> String\n return \"hello\" + \"!\"\nend function\nfunction across() -> Integer\n bind text <- word()\n bind n <- handle\n ask(1)\n with\n case ask(i) -> resume(i)\n end handle\n return String.characterCount(text) + n\nend function\n",
            "across()",
            7,
            None,
        ),
        (
            "repeated",
            "",
            "handle\n ask(1) + ask(2) + ask(3)\nwith\n case ask(n) -> resume(n + 10)\nend handle",
            36,
            None,
        ),
        (
            "around resume",
            "",
            "handle\n ask(1) * 2\nwith\n case ask(n) ->\n bind x <- resume(n + 10)\n x + 100\nend handle",
            122,
            None,
        ),
        (
            "nested",
            "effect Inner\n function inside(n: Integer) -> Integer\nend effect\n",
            "handle\n handle\n ask(1) + inside(2)\n with\n case inside(n) -> resume(n + 10)\n end handle\nwith\n case ask(n) -> resume(n + 100)\nend handle",
            113,
            None,
        ),
        (
            "same operation in clause",
            "",
            "handle\n handle\n ask(1)\n with\n case ask(n) -> resume(ask(n))\n end handle\nwith\n case ask(n) -> resume(n + 100)\nend handle",
            101,
            None,
        ),
        (
            "twice",
            "",
            "handle\n ask(1)\nwith\n case ask(n) ->\n bind x <- resume(n)\n resume(x)\nend handle",
            0,
            Some(benitoite::diag::codes::DiagCode::R0501),
        ),
        (
            "completed iterations",
            "function iterate(n: Integer) -> Integer\n if n = 0 then return 0 end if\n bind x <- handle\n ask(n)\n with\n case ask(i) -> resume(i)\n end handle\n return iterate(n - x div x)\nend function\n",
            "iterate(100)",
            0,
            None,
        ),
        (
            "pending computation",
            "function repeat(n: Integer) -> Integer uses Test\n return if n = 0 then 0 else repeat(n - ask(1)) end if\nend function\n",
            "handle\n repeat(100)\nwith\n case ask(n) ->\n bind x <- resume(n)\n x + 1\nend handle",
            100,
            None,
        ),
        (
            "call before handle",
            "function word() -> String\n return \"hello\" + \"!\"\nend function\n",
            "handle\n bind text <- word()\n bind n <- ask(1)\n String.characterCount(text) + n\nwith\n case ask(n) ->\n bind text <- word()\n bind x <- resume(n)\n x + String.characterCount(text)\nend handle",
            13,
            None,
        ),
        (
            "discard body continuation",
            "",
            "handle\n ask(1) + (1 div 0)\nwith\n case ask(n) -> n + 41\nend handle",
            42,
            None,
        ),
        (
            "discard nested continuation",
            "effect Inner\n function inside(n: Integer) -> Integer\nend effect\n",
            "handle\n handle\n inside(1)\n with\n case inside(n) -> ask(n)\n end handle\nwith\n case ask(n) -> n + 41\nend handle",
            42,
            None,
        ),
        (
            "escape from body",
            "function early() -> Integer\n bind x <- handle\n return 42\n 0\n with\n case ask(n) -> resume(n)\n end handle\n return x + 1\nend function\n",
            "early()",
            42,
            None,
        ),
        (
            "escape from clause",
            "function early() -> Integer\n bind x <- handle\n ask(1) + (1 div 0)\n with\n case ask(n) ->\n return 42\n 0\n end handle\n return x + 1\nend function\n",
            "early()",
            42,
            None,
        ),
        (
            "try from body",
            "function early() -> Option[Integer]\n bind x <- handle\n try Integer.parse(\"bad\")\n with\n case ask(n) -> resume(n)\n end handle\n return Option.Some(x + 1)\nend function\n",
            "match early() with\n case Option.None -> 42\n case Option.Some(n) -> n\n end match",
            42,
            None,
        ),
        (
            "try from clause",
            "function early() -> Option[Integer]\n bind x <- handle\n ask(1)\n with\n case ask(n) -> try Integer.parse(\"bad\")\n end handle\n return Option.Some(x + 1)\nend function\n",
            "match early() with\n case Option.None -> 42\n case Option.Some(n) -> n\n end match",
            42,
            None,
        ),
        (
            "stop in body",
            "",
            "handle\n ask(1) div 0\nwith\n case ask(n) -> resume(n)\nend handle",
            0,
            Some(benitoite::diag::codes::DiagCode::R0101),
        ),
        (
            "stop in clause with captured continuation",
            "",
            "handle\n ask(1)\nwith\n case ask(n) -> n div 0\nend handle",
            0,
            Some(benitoite::diag::codes::DiagCode::R0101),
        ),
        (
            "stop with nested captured continuation",
            "effect Inner\n function inside(n: Integer) -> Integer\nend effect\n",
            "handle\n handle\n inside(1)\n with\n case inside(n) -> ask(n)\n end handle\nwith\n case ask(n) -> n div 0\nend handle",
            0,
            Some(benitoite::diag::codes::DiagCode::R0101),
        ),
        (
            "discarded iterations",
            "function iterate(n: Integer) -> Integer\n if n = 0 then return 0 end if\n bind x <- handle\n ask(n)\n with\n case ask(i) -> i\n end handle\n return iterate(n - x div x)\nend function\n",
            "iterate(100000)",
            0,
            None,
        ),
    ];
    for (name, extra, expression, expected, failure) in cases {
        let source = format!(
            "{declarations}\n{extra}\nfunction main() -> Result[Unit, String]\n bind answer <- {expression}\n return if answer = {expected} then Result.Ok(()) else Result.Error(\"wrong value\") end if\nend function\n"
        );
        let checked = pipeline::check_text(
            "handlers.bnt",
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
        let p = pipeline::compile(&core, checked.sources).unwrap();
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
                    max_call_stack_bytes: 1024 * 1024,
                    ..VmConfig::default()
                },
                heap: HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                dev_panic_after_first_write: false,
            };
            let end = run::run_program(&p, env);
            if let Some(failure) = failure {
                assert_eq!(end.exit_code, 1, "{name}: {end:?}");
                assert_eq!(end.reports[0].code, Some(failure));
            } else {
                assert_eq!(end.exit_code, 0, "{name}: {end:?}");
                assert!(end.main_error.is_none(), "{name}: {end:?}");
            }
        }
    }
}
