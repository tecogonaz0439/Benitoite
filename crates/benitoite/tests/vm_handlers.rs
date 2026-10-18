//! ハンドラのコード生成と VM の組み合わせ（設計書 02-08「ハンドラと継続」）。

// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]

#[path = "operation_dictionaries/mod.rs"]
mod operation_dictionaries;

#[path = "typed_failure/mod.rs"]
mod typed_failure;

use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::vm::{ExecMode, VmConfig};

// 関門: 実際の型検査・コード生成・VM をつなぐ契約。asm の検査は、コード生成が
// 節の引数や HANDLE の記述を取り違えた場合を捕まえない。
#[test]
fn scripts_connect_real_codegen_to_handlers_and_runtime() {
    use benitoite::pipeline::{self, CheckOptions};
    use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
    use std::sync::{Arc, Mutex};
    let declarations = "import Benitoite.Unofficial.Failure\neffect Test\n function ask(n: Integer) -> Integer\nend effect\n";
    let cases = [
        (
            "constrained operation dictionaries",
            "effect Render\n function render[T: Trait.Show](value: T) -> String\nend effect\n",
            "handle\n String.characterCount(render(42)) + String.characterCount(render(\"abc\"))\nwith\n case render(value) -> resume(Trait.Show.show(value))\nend handle",
            7,
            None,
        ),
        (
            "constrained operation value",
            "effect Render\n function render[T: Trait.Show](value: T) -> String\nend effect\n",
            "handle\n bind show: function(value: Integer) -> String uses Render <- render\n String.characterCount(show(42))\nwith\n case render(value) -> resume(Trait.Show.show(value))\nend handle",
            2,
            None,
        ),
        (
            "multiple operation classes",
            "effect Render\n function render[T: Trait.Show & Trait.Order](value: T) -> String\nend effect\n",
            "handle\n String.characterCount(render(42)) + String.characterCount(render(\"abc\"))\nwith\n case render(value) ->\n if Trait.Order.compare(x: value, y: value) = Trait.Ordering.Equal then resume(Trait.Show.show(value)) else resume(\"bad\") end if\nend handle",
            7,
            None,
        ),
        (
            "operation superclass dictionary",
            "effect Combine\n function combine[T: Trait.Monoid](left: T, right: T) -> T\nend effect\n",
            "String.characterCount(handle\n combine(left: \"ab\", right: \"c\")\nwith\n case combine(left, right) -> resume(Trait.Semigroup.combine(x: left, y: right))\nend handle)",
            3,
            None,
        ),
        (
            "operation dictionary with heap captures",
            "effect Render\n function render[T: Trait.Show](value: T) -> String\nend effect\n",
            "handle\n String.characterCount(render([42, 7])) + String.characterCount(render([8]))\nwith\n case render(value) ->\n bind show <- lambda() return Trait.Show.show(value) end lambda\n bind pad <- String.repeat(s: \"x\", n: 100)\n bind rest <- resume(show())\n rest + String.characterCount(show()) + String.characterCount(pad)\nend handle",
            220,
            None,
        ),
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
            "function early() -> Integer\n bind x <- handle\n return 42\n with\n case ask(n) -> resume(n)\n end handle\n return x + 1\nend function\n",
            "early()",
            42,
            None,
        ),
        (
            "escape from clause",
            "function early() -> Integer\n bind x <- handle\n ask(1) + (1 div 0)\n with\n case ask(n) ->\n return 42\n end handle\n return x + 1\nend function\n",
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
    for (name, extra, expression, expected, failure, wrap) in
        cases
            .into_iter()
            .map(|(name, extra, expression, expected, failure)| {
                (name, extra, expression, expected, failure, false)
            })
            .chain(operation_dictionaries::CASES.iter().map(
                |&(name, extra, expression, expected)| {
                    (name, extra, expression, expected, None, true)
                },
            ))
            .chain(typed_failure::CASES.iter().map(
                |&(name, extra, expression, expected, failure)| {
                    (name, extra, expression, expected, failure, true)
                },
            ))
    {
        let expression = if wrap {
            format!("if true then\n{expression}\nelse 0 end if")
        } else {
            expression.to_owned()
        };
        let source = operation_dictionaries::source(
            &format!("{declarations}\n{extra}"),
            &expression,
            expected,
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
        let errors = benitoite::ir::check::check_program(&core);
        assert!(errors.is_empty(), "{name}: {errors:?}");
        let p = pipeline::compile(&core, checked.sources).unwrap();
        assert!(benitoite::bytecode::verify::verify(&p).is_ok(), "{name}");
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

// 関門: 解放を待つ安全点を越えて元のエラーを保ち、内側から一度ずつ転送する。
// IO の順序のテストとは別に、局所の heap-verify/gc-stress でもこの経路を検査する。
#[test]
fn typed_failure_retains_error_across_nested_writer_release() {
    use benitoite::pipeline::{self, CheckOptions};
    use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
    use std::sync::{Arc, Mutex};
    for (action, expected) in [
        (
            "bind _ <- Failure.raise(error)\n Console.writeLine(\"unreachable\")\n Result.Ok(1 div 0)",
            "Result.Error(String.repeat(s: \"original\", n: 20))",
        ),
        ("return Result.Ok(7)", "Result.Ok(Result.Ok(7))"),
        (
            "bind _ <- try Result.Error(\"early\") or return\n Result.Ok(1 div 0)",
            "Result.Ok(Result.Error(\"early\"))",
        ),
    ] {
        let source = r#"
import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit, String] uses File.Write, State, Process.Exit, Console.Write
 bind caught: Result[Result[Integer, String], String] <- Failure.toResult(body: lambda()
  return with outer = try File.openWriter(path: "release.txt", mode: File.WriteMode.Append) or die do
   bind _ <- try File.write(writer: outer, text: "outer") or die
   with inner = try File.openWriter(path: "release.txt", mode: File.WriteMode.Append) or die do
    bind _ <- try File.write(writer: inner, text: "inner") or die
    bind error <- String.repeat(s: "original", n: 20)
    ACTION
   end with
  end with
 end lambda)
 return if caught = EXPECTED then Result.Ok(()) else Result.Error("wrong error") end if
end function
"#.replace("ACTION", action).replace("EXPECTED", expected);
        let checked = pipeline::check_text(
            "release.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        assert!(benitoite::ir::check::check_program(&core).is_empty());
        let program = pipeline::compile(&core, checked.sources).unwrap();
        let directory = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join(format!("../../target/f2-release-{}", std::process::id()));
        std::fs::create_dir(&directory).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let stdout = Arc::new(Mutex::new(Vec::new()));
            let stderr = Arc::new(Mutex::new(Vec::new()));
            let end = run::run_program(
                &program,
                RunEnv {
                    input: RunInput {
                        arguments: vec![],
                        working_directory: directory.clone(),
                        script_directory: directory.clone(),
                    },
                    stdin: StdinSource::Empty,
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
            assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
            assert!(end.main_error.is_none(), "{end:?}");
            assert!(end.reports.is_empty(), "{end:?}");
            assert!(stdout.lock().unwrap().is_empty());
            assert!(stderr.lock().unwrap().is_empty());
            assert_eq!(
                std::fs::read(directory.join("release.txt")).unwrap(),
                b"innerouter"
            );
            std::fs::remove_file(directory.join("release.txt")).unwrap();
        }
        std::fs::remove_dir(directory).unwrap();
    }
}
