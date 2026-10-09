//! テストの関数一つの実行（`run_test`）の終わり方・終了状態・確認の失敗の記録を、本物の VM とランタイムで
//! 確かめる（実装プラン D10「受け入れテスト」、10-18「テストの関数の実行」）。

use super::*;
use crate::builtins::iface::{IoReply, OsResource, builtin};
use crate::bytecode::program::MainKind;
use crate::runtime::assert::AssertOp;
use crate::runtime::assert::tests::{environment, prepare};
use crate::runtime::io::event::Wakeup;
use crate::runtime::sched::testing::ScheduleHandle;
use std::sync::atomic::AtomicBool;

const MODES: [ExecMode; 2] = [ExecMode::Direct, ExecMode::Request];

fn span_text(program: &CompiledProgram, span: crate::base::Span) -> String {
    let source = program.sources.get(span.file).unwrap();
    String::from_utf8(source.text()[span.start.0 as usize..span.end.0 as usize].to_vec()).unwrap()
}

fn captured(bytes: &Arc<Mutex<Vec<u8>>>) -> String {
    String::from_utf8(bytes.lock().unwrap().clone()).unwrap()
}

// 関門: 10-18 の表の行ごとに、VM の結果を終わり方・終了状態・報告へ写す。`run_program` と分けた共通の手順の
// 取り違え（`main_kind` で戻り値を読む、確認の失敗以外の欄を埋める）を、テストの関数の戻り値の型ごとに捕まえる。
#[test]
fn test_functions_end_as_the_runner_table_requires() {
    let source = r#"
import Benitoite.Unofficial.IO.Process
@test
function unitOk() -> Unit uses Assert.Check
  Assert.equal(1, 1)
  return ()
end function
@test
function resultOk() -> Result[Unit, String]
  return Result.Ok(())
end function
@test
function resultError() -> Result[Unit, String]
  return Result.Error("x")
end function
@test
function exits() -> Unit uses Process.Exit
  return Process.exit(4)
end function
@test
function runtimeError() -> Unit
  bind _ <- 1 div 0
  return ()
end function
"#;
    let prepared = prepare(source);
    for mode in MODES {
        for (name, kind, end_kind, code, main_error, reports) in [
            ("unitOk", MainKind::Unit, EndKind::Returned, 0, None, 0),
            ("resultOk", MainKind::Result, EndKind::Returned, 0, None, 0),
            (
                "resultError",
                MainKind::Result,
                EndKind::MainError,
                1,
                Some("x"),
                0,
            ),
            ("exits", MainKind::Unit, EndKind::Exited(4), 4, None, 0),
            ("runtimeError", MainKind::Unit, EndKind::Stopped, 1, None, 1),
        ] {
            let end = prepared.run(name, kind, environment(mode).0);
            assert_eq!(end.run.end, end_kind, "{name}: {:?}", end.run.reports);
            assert_eq!(end.run.exit_code, code, "{name}");
            assert_eq!(end.run.main_error.as_deref(), main_error, "{name}");
            assert_eq!(end.run.reports.len(), reports, "{name}");
            assert!(end.check_failure.is_none(), "{name}");
            assert!(end.release_failures.is_empty(), "{name}");
        }
        // 表にない原型は枠を積まずに処理系の不具合として終える（10-18 の `start_test`）。
        let mut target = prepared.target("unitOk", MainKind::Unit);
        target.proto = crate::bytecode::program::ProtoIdx(u32::MAX);
        let end = run_test(&prepared.program, target, environment(mode).0);
        assert_eq!(end.run.end, EndKind::Internal);
        assert_eq!(end.run.exit_code, EXIT_INTERNAL);
        assert_eq!(end.run.reports.len(), 1);
    }
}

// 関門: 確認の失敗は、操作を呼んだ位置で止め、後の文を評価しない（02-11）。記録の位置は呼び出しの式、枠は
// 失敗を見つけた時点のもの（10-18 の手順 4）。捕らえた出力は止める手順の後の最後の転送で届く。
#[test]
fn failed_check_stops_at_the_call_and_keeps_captured_output() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
function helper() -> Unit uses Console.Write, Assert.Check
  Console.writeLine("before")
  Console.writeErrorLine("to stderr")
  Assert.equal(1, 2)
  Console.writeLine("after")
end function
@test
function failing() -> Unit uses Console.Write, Assert.Check
  helper()
  Console.writeLine("after helper")
end function
"#;
    let prepared = prepare(source);
    for mode in MODES {
        let (env, out) = environment(mode);
        let end = prepared.run("failing", MainKind::Unit, env);
        assert_eq!(end.run.end, EndKind::CheckFailed, "{:?}", end.run.reports);
        assert_eq!(end.run.exit_code, EXIT_FAILURE);
        assert!(end.run.reports.is_empty());
        let failure = end.check_failure.unwrap();
        assert_eq!(failure.op, AssertOp::Equal);
        assert_eq!(failure.left.as_deref(), Some("1"));
        assert_eq!(failure.right.as_deref(), Some("2"));
        let span = report::instr_span(&prepared.program, failure.at).unwrap();
        assert_eq!(span_text(&prepared.program, span), "Assert.equal(1, 2)");
        // 内側から外側の順。外側の枠はテストの関数で、呼び出した命令を持たない。
        assert_eq!(failure.frames.len(), 2, "{:?}", failure.frames);
        assert_eq!(failure.frames[0].proto, failure.at.proto);
        assert_eq!(
            failure.frames[1].proto,
            prepared.target("failing", MainKind::Unit).proto
        );
        assert_eq!(failure.frames[1].call_site, None);
        assert!(failure.spawns.is_empty());
        assert_eq!(captured(&out.stdout), "before\n");
        assert_eq!(captured(&out.stderr), "to stderr\n");
    }
}

// リソースの OS の依存だけを差し替え、close を失敗させる（10-10「テストで差し替える部品」と同じ考え方）。
#[derive(Debug)]
struct FailingClose(String);
impl OsResource for FailingClose {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        Err(format!("cannot close {}", self.0))
    }
}
builtin! {
    /// 開いたことにして、閉じられないリソースを表に加える。
    name = "Benitoite.IO.File.openReader",
    io fn failing_open(ctx, name: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let id = ctx.services().register_resource(
            crate::runtime::ResourceKind::FileReader,
            Box::new(FailingClose(name.into())),
            None,
        );
        Ok(IoReply::Done(ctx.alloc_fields(
            crate::runtime::heap::FieldsKind::Ctor,
            crate::builtins::table::tags::RESULT_OK,
            &[crate::runtime::heap::Value::Resource(id)],
        )?))
    }
}

// 関門: 確認の失敗で止める手順は `Process.exit` と同じく `with` のリソースを内側から解放し、解放の失敗を止める
// 理由と別に返す（02-08「止める手順」）。確認の失敗の経路だけが `release_failures` を `TestEnd` に移す。
// `RunEnv` はリソースを差し替える口を持たないので、`run_test` と同じ共通の手順を IO 実行器から呼ぶ。
#[test]
fn failed_check_releases_resources_innermost_first() {
    let source = r#"
import Benitoite.Unofficial.IO.File
@test
function resources() -> Result[Unit, String] uses File.Read, State, Assert.Check
  with first = try File.openReader("first") |> Result.mapError(_, IOError.message),
       second = try File.openReader("second") |> Result.mapError(_, IOError.message) do
    return Assert.fail("stop")
  end with
end function
"#;
    let prepared = prepare(source);
    for mode in MODES {
        let env = environment(mode).0;
        let wakeup = crate::runtime::io::event::wakeup_with_poll().unwrap();
        let outputs = (
            crate::runtime::io::output::OutputPort::start(
                Stream::Stdout,
                Box::new(std::io::sink()),
                false,
                wakeup.clone(),
            ),
            crate::runtime::io::output::OutputPort::start(
                Stream::Stderr,
                Box::new(std::io::sink()),
                false,
                wakeup.clone(),
            ),
        );
        let mut rt = crate::runtime::io::services::IoRuntime::new(
            env.input,
            mode,
            outputs,
            Box::new(std::io::Cursor::new(Vec::<u8>::new())),
            RuntimeParts::real(wakeup.clone()),
            env.interrupt,
            wakeup,
        );
        rt.builtin_overrides.insert(
            crate::builtins::lookup_builtin(failing_open::DECL.name).unwrap(),
            &failing_open::DECL,
        );
        let target = prepared.target("resources", MainKind::Result);
        let end = run_vm_entry(
            &prepared.program,
            env.vm,
            env.heap,
            rt,
            &Entry::Test(target),
        );
        assert_eq!(end.run.end, EndKind::CheckFailed, "{:?}", end.run.reports);
        assert_eq!(end.run.exit_code, EXIT_FAILURE);
        assert!(end.run.reports.is_empty());
        assert_eq!(end.check_failure.unwrap().message, "stop");
        let reasons: Vec<_> = end
            .release_failures
            .iter()
            .map(|failure| failure.reason.as_str())
            .collect();
        assert_eq!(reasons, ["cannot close second", "cannot close first"]);
    }
}

// 関門: 起動したタスクの `Assert` の操作も同じ分岐を通る（10-18「`Assert.Check` の処理」の手順 2 の最後の段落）。
// 最初のタスクだけで確かめる退行（起動したタスクで送り出しの列に置き、表の本体の `Stop::Internal` に達する）を、
// 終わり方と起動の履歴で捕まえる。利用者のハンドラは組み込みの処理より先に受ける（手順 1）。
#[test]
fn spawned_tasks_fail_checks_and_user_handlers_take_precedence() {
    let source = r#"
@test
function spawned() -> Unit uses Assert.Check
  bind _ <- Task.all([lambda() return () end lambda, lambda() return Assert.equal(1, 2) end lambda])
  return ()
end function
@test
function handled() -> Unit uses Assert.Check
  return handle Assert.equal(1, 2) with case Assert.equal(_, _) -> resume(()) end handle
end function
"#;
    let prepared = prepare(source);
    for mode in MODES {
        let end = prepared.run("spawned", MainKind::Unit, environment(mode).0);
        assert_eq!(end.run.end, EndKind::CheckFailed, "{:?}", end.run.reports);
        let failure = end.check_failure.unwrap();
        assert_eq!(failure.spawns.len(), 1, "{failure:?}");
        let span = report::instr_span(&prepared.program, failure.spawns[0].spawned_at).unwrap();
        assert!(
            span_text(&prepared.program, span).starts_with("Task.all("),
            "{failure:?}"
        );
        let end = prepared.run("handled", MainKind::Unit, environment(mode).0);
        assert_eq!(end.run.end, EndKind::Returned, "{:?}", end.run.reports);
        assert!(end.check_failure.is_none());
    }
}

#[derive(Debug)]
struct Requested(AtomicBool);
impl InterruptSource for Requested {
    fn requested(&self) -> bool {
        true
    }
    fn flag(&self) -> Option<&AtomicBool> {
        Some(&self.0)
    }
    fn attach(
        &self,
        _: &Wakeup,
    ) -> std::io::Result<Option<crate::runtime::io::event::InterruptGuard>> {
        panic!("test parts must not attach signals")
    }
}

// 関門: 中断の要求の終わり方は、テストの実行器が残りのテストを止める合図になる（10-18 の表）。テストの関数を
// 最初のタスクにした実行でも、中断の読み口を VM に渡す経路が働くことを確かめる。
#[test]
fn interrupt_request_ends_a_test_as_interrupted() {
    let source = r#"
function step() -> Unit
  return ()
end function
@test
function interrupted() -> Unit uses Assert.Check
  step()
  Assert.equal(1, 1)
end function
"#;
    let prepared = prepare(source);
    for mode in MODES {
        let (mut env, _) = environment(mode);
        env.interrupt = Box::new(Requested(AtomicBool::new(true)));
        env.parts = Some(ScheduleHandle::new([], false).parts());
        let end = prepared.run("interrupted", MainKind::Unit, env);
        assert_eq!(end.run.end, EndKind::Interrupted, "{:?}", end.run.reports);
        assert_eq!(end.run.exit_code, EXIT_INTERRUPTED);
        assert!(end.check_failure.is_none());
    }
}
