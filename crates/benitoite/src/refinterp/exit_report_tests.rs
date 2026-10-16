//! 報告付き App の独立したコア入力で、VM と参照インタプリタの結果を照合する
//! （設計書 02-08「参照インタプリタ」）。
use super::*;
use crate::ir::core_ir::*;
use crate::runtime::heap::HeapConfig;
use crate::vm::{DieFailure, ExecMode, StopEnd, StopReason, Vm, VmConfig, VmStep};
use std::sync::Arc;

fn attach(comp: &mut Comp, cause: &Var, message: Option<&Var>) -> Option<crate::base::Span> {
    if let CompKind::Let { bound, body, .. } = &mut comp.kind {
        return attach(bound, cause, message).or_else(|| attach(body, cause, message));
    }
    if let CompKind::App {
        func,
        args,
        exit_report,
        ..
    } = &mut comp.kind
        && matches!(&func.kind, ValKind::Builtin { id, .. }
            if Some(*id) == crate::builtins::lookup_builtin("Benitoite.IO.Process.exit"))
    {
        args[0].kind = ValKind::Const(Const::Int(1));
        let val = |var: &Var| {
            Box::new(Val {
                kind: ValKind::Var(var.id),
                ty: var.ty.clone(),
                origin: comp.origin,
            })
        };
        *exit_report = Some(ExitReportArgs {
            cause: val(cause),
            message: message.map(val),
        });
        return Some(comp.origin);
    }
    None
}

fn reported_core(
    body: &str,
    with_message: bool,
    main_uses: &str,
) -> (crate::modules::LoadOutput, CoreProgram, crate::base::Span) {
    let source = format!(
        "import Benitoite.Unofficial.IO.Process\nimport Benitoite.Unofficial.IO.Clock\nfunction fail(cause: String, message: String) -> Unit uses Process.Exit\n Process.exit(1)\nend function\nfunction main() -> Unit uses {main_uses}\n {body}\nend function\n"
    );
    let (load, _, _, mut core) = desugar_files(&[("main.bnt", &source)], true);
    let def = core.defs.iter_mut().find(|d| d.name == "fail").unwrap();
    let cause = def.params[0].clone();
    let message = def.params[1].clone();
    let at = attach(&mut def.body, &cause, with_message.then_some(&message)).unwrap();
    assert!(crate::ir::check::check_program(&core).is_empty());
    (load, core, at)
}

// 関門: 既定の終了だけが情報を所有し、処理・再開・破棄・再入後の独立した exit へ混入しない契約。
// 既存のソースは報告付き App を生成しない。各実行器の本物の入口と独立した期待結果を使う。
// 内部 IR の構築はテスト内に限り、本番の parser/API に差し込み口を足さない。
#[test]
fn exit_report_is_owned_only_by_the_default_call() {
    for (body, kind) in [
        ("fail(cause: \"cause\", message: \"explanation\")", "report"),
        (
            "handle fail(cause: \"cause\", message: \"explanation\") with\ncase Process.exit(code) -> ()\nend handle",
            "handled",
        ),
        (
            "handle fail(cause: \"cause\", message: \"explanation\") with\ncase Process.exit(code) -> ()\nend handle",
            "resumed",
        ),
        (
            "handle fail(cause: \"cause\", message: \"explanation\") with\ncase Process.exit(code) -> Process.exit(code)\nend handle",
            "reentered",
        ),
        (
            "handle fail(cause: \"cause\", message: \"explanation\") with\ncase Process.exit(code) -> ()\nend handle\nProcess.exit(1)",
            "later",
        ),
        (
            "handle fail(cause: \"cause\", message: \"explanation\") with\ncase Process.exit(code) -> ()\nend handle\nProcess.exit(1)",
            "resumed later",
        ),
    ] {
        for with_message in [false, true] {
            let (load, mut core, at) = reported_core(body, with_message, "Process.Exit");
            if matches!(kind, "resumed" | "resumed later") {
                // exit の戻り型 T は節で剛体なので、ソースの resume(()) は E0401 になる。
                // 再開時の情報の破棄は、型を消去した実行器への独立入力で確認する。
                // これはソースで受理する規則の検査ではない。
                fn resume(comp: &mut Comp) -> bool {
                    if let CompKind::Let { bound, body, .. } = &mut comp.kind {
                        return resume(bound) || resume(body);
                    }
                    if let CompKind::Handle(handle) = &mut comp.kind {
                        let clause = &mut handle.clauses[0];
                        clause.body.kind = CompKind::Resume {
                            cont: clause.cont.id,
                            value: Val {
                                kind: ValKind::Const(Const::Unit),
                                ty: clause.body.ty.clone(),
                                origin: clause.body.origin,
                            },
                        };
                        clause.tail_resumptive = true;
                        return true;
                    }
                    false
                }
                let main = core.defs.iter_mut().find(|d| d.name == "main").unwrap();
                assert!(resume(&mut main.body));
            }
            let failure = (kind == "report").then(|| DieFailure {
                cause: "cause".into(),
                message: with_message.then(|| "explanation".into()),
                at,
            });
            let returns = matches!(kind, "handled" | "resumed");
            let expected = if returns {
                RefOutcome::Finished(MainOutcome::Ok)
            } else {
                RefOutcome::Exited {
                    status: 1,
                    die_failure: failure.clone(),
                    release_failures: vec![],
                }
            };
            assert_eq!(run(&core, &mut io()), expected, "{kind}");
            let lower = crate::ir::decision::lower_program(&core).unwrap();
            let bytecode =
                crate::bytecode::codegen::codegen(&lower, Arc::new(load.sources)).unwrap();
            for mode in [ExecMode::Direct, ExecMode::Request] {
                let mut vm = Vm::new(
                    &bytecode,
                    VmConfig::default(),
                    HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                );
                vm.start_main().unwrap();
                let mut services = crate::vm::dispatch::test_support::TestIo::new(RunInput {
                    arguments: vec![],
                    working_directory: ".".into(),
                    script_directory: ".".into(),
                });
                let expected = if returns {
                    VmStep::Finished(MainOutcome::Ok)
                } else {
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Exit {
                            code: 1,
                            die_failure: failure.clone(),
                        },
                        release_failures: vec![],
                    })
                };
                let step = loop {
                    match vm.run(services.runtime(mode)) {
                        VmStep::Requests(ids) => {
                            for id in ids {
                                vm.serve_request(&mut services.rt, id);
                            }
                        }
                        step @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break step,
                    }
                };
                assert_eq!(step, expected, "{mode:?}: {kind}");
                assert!(services.take_output().is_empty());
            }
        }
    }
}

#[derive(Debug)]
struct BatchDispatcher(ExecMode, bool);
impl crate::runtime::io::Dispatcher for BatchDispatcher {
    fn on_wait_point(
        &mut self,
        queue: &mut crate::runtime::io::DispatchQueue,
        at: crate::runtime::io::WaitPoint,
    ) -> crate::runtime::io::DispatchAction {
        use crate::runtime::io::*;
        if queue.queued.len() < 2 {
            return DispatchAction::Nothing;
        }
        let mut action = match self.0 {
            ExecMode::Direct => DirectDispatcher.on_wait_point(queue, at),
            ExecMode::Request => RequestDispatcher.on_wait_point(queue, at),
        };
        if self.1 {
            match &mut action {
                DispatchAction::ServeNow(ids) | DispatchAction::ReturnToExecutor(ids) => {
                    ids.reverse()
                }
                DispatchAction::Nothing => {}
            }
        }
        action
    }
}

// 関門: 同時に生きた要求の情報を、採用した終了と取り違えない契約はタスクを持つ VM に属する。
// 参照インタプリタはタスクを扱わないため、この独立入力では VM の停止結果だけを照合する。
// 既存の通常の exit の競合では、原因・説明の取り違えを観測できない。公開 API は増やさない。
#[test]
fn competing_exit_reports_belong_only_to_the_selected_request() {
    use crate::runtime::sched::testing::{ScheduleHandle, ScheduleStep};
    for ordinary in [false, true] {
        let second = if ordinary {
            "Process.exit(7)"
        } else {
            "fail(cause: \"second\", message: \"two\")"
        };
        let body = format!(
            "bind _ <- Task.all([lambda() return fail(cause: \"first\", message: \"one\") end lambda, lambda() return {second} end lambda])\nreturn ()"
        );
        let (load, core, at) = reported_core(&body, true, "Process.Exit");
        let lower = crate::ir::decision::lower_program(&core).unwrap();
        let bytecode = crate::bytecode::codegen::codegen(&lower, Arc::new(load.sources)).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            for reverse in [false, true] {
                let mut vm = Vm::new(
                    &bytecode,
                    VmConfig::default(),
                    HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                );
                vm.start_main().unwrap();
                let script = ScheduleHandle::new(
                    [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
                    false,
                );
                let mut services = crate::vm::dispatch::test_support::TestIo::new(RunInput {
                    arguments: vec![],
                    working_directory: ".".into(),
                    script_directory: ".".into(),
                });
                services.rt.parts = script.parts();
                services.rt.dispatcher = Box::new(BatchDispatcher(mode, reverse));
                let mut step = vm.run(&mut services.rt);
                if let VmStep::Requests(ids) = step {
                    assert_eq!(ids.len(), 2);
                    assert_eq!(services.rt.queue.live.len(), 2);
                    for id in ids {
                        vm.serve_request(&mut services.rt, id);
                        vm.serve_request(&mut services.rt, id);
                    }
                    step = vm.run(&mut services.rt);
                }
                let failure = (!(ordinary && reverse)).then(|| DieFailure {
                    cause: if reverse { "second" } else { "first" }.into(),
                    message: Some(if reverse { "two" } else { "one" }.into()),
                    at,
                });
                assert_eq!(
                    step,
                    VmStep::Stopped(StopEnd {
                        reason: StopReason::Exit {
                            code: if ordinary && reverse { 7 } else { 1 },
                            die_failure: failure
                        },
                        release_failures: vec![],
                    }),
                    "{mode:?}: ordinary={ordinary}, reverse={reverse}"
                );
                assert!(services.rt.queue.live.is_empty());
                assert!(!services.rt.queue.has_outstanding());
                assert!(services.take_output().is_empty());
                assert_eq!(script.record().remaining, 0);
                assert_eq!(script.record().error, None);
                assert!(vm.heap_stats().collections > 0);
            }
        }
    }
}

// 関門: 取り消した報告付き要求の古い番号を再配送しても、後の通常の exit へ情報を移さない。
// Task.race の本物の取り消しを使い、応答前の要求を失効させる。
#[test]
fn cancelled_exit_report_does_not_leak_into_a_later_exit() {
    use crate::runtime::sched::testing::{ScheduleHandle, ScheduleStep};
    let (load, core, _) = reported_core(
        "bind _ <- Task.race([lambda() return fail(cause: \"cancelled\", message: \"discard me\") end lambda, lambda() return () end lambda])\nProcess.exit(1)",
        true,
        "Process.Exit, Clock.Time, State",
    );
    let lower = crate::ir::decision::lower_program(&core).unwrap();
    let bytecode = crate::bytecode::codegen::codegen(&lower, Arc::new(load.sources)).unwrap();
    let mut vm = Vm::new(
        &bytecode,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let script = ScheduleHandle::new(
        [ScheduleStep::PickTask(1), ScheduleStep::PickTask(2)],
        false,
    );
    let mut services = crate::vm::dispatch::test_support::TestIo::new(RunInput {
        arguments: vec![],
        working_directory: ".".into(),
        script_directory: ".".into(),
    });
    services.rt.parts = script.parts();
    let VmStep::Requests(first) = vm.run(services.runtime(ExecMode::Request)) else {
        panic!("report request missing");
    };
    assert_eq!(first.len(), 1);
    assert_eq!(
        services.rt.queue.live[&first[0]]
            .req
            .die_failure
            .as_ref()
            .unwrap()
            .cause,
        "cancelled"
    );
    let VmStep::Requests(later) = vm.run(services.runtime(ExecMode::Request)) else {
        panic!("later exit request missing");
    };
    assert_eq!(later.len(), 1);
    assert_ne!(first, later);
    assert_eq!(services.rt.queue.live.len(), 1);
    assert_eq!(services.rt.queue.live[&later[0]].req.die_failure, None);
    vm.serve_request(&mut services.rt, first[0]);
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Requests(vec![])
    );
    vm.serve_request(&mut services.rt, later[0]);
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Stopped(StopEnd {
            reason: StopReason::Exit {
                code: 1,
                die_failure: None
            },
            release_failures: vec![],
        })
    );
    assert!(services.rt.queue.live.is_empty());
    assert!(!services.rt.queue.has_outstanding());
    assert!(services.take_output().is_empty());
    assert_eq!(script.record().remaining, 0);
    assert_eq!(script.record().error, None);
    assert!(vm.heap_stats().collections > 0);
}

// 関門: ソースの die から生成した要求も、ハンドラで処理した後の独立した exit へ
// 情報を残さない。入力の一回性は、失敗を処理した節から State の値を読んで観測する。
// 先行する独立コアの再開検査は、ソースで受理しない resume の契約として維持する。
#[test]
fn source_die_handlers_observe_one_operand_and_discard_the_report() {
    for (body, status, output) in [
        (
            "handle fail(count) with case Process.exit(code) -> Console.writeLine(\"${code}:${Reference.get(count)}\") end handle",
            None,
            "1:1\n",
        ),
        (
            "handle fail(count) with case Process.exit(code) -> () end handle\nConsole.writeLine(\"${Reference.get(count)}\")\nProcess.exit(1)",
            Some(1),
            "1\n",
        ),
        (
            "handle fail(count) with case Process.exit(code) -> Process.exit(7) end handle",
            Some(7),
            "",
        ),
        (
            "handle\n handle fail(count) with case Process.exit(code) -> Process.exit(7) end handle\nwith case Process.exit(code) -> Console.writeLine(\"${code}:${Reference.get(count)}\") end handle",
            None,
            "7:1\n",
        ),
    ] {
        let source = format!(
            r#"
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.Console
function operand(count: Reference[Integer]) -> Option[Unit] uses State
 Reference.update(reference: count, f: lambda(value) return value + 1 end lambda)
 return Option.None
end function
function fail(count: Reference[Integer]) -> Unit uses State, Process.Exit
 return try operand(count) or die("discard this report")
end function
function main() -> Unit uses State, Process.Exit, Console.Write
 bind count <- Reference.new(0)
 {body}
end function
"#
        );
        let (load, _, _, core) = desugar_files(&[("main.bnt", &source)], true);
        let expected = status.map_or(RefOutcome::Finished(MainOutcome::Ok), |status| {
            RefOutcome::Exited {
                status,
                die_failure: None,
                release_failures: vec![],
            }
        });
        let mut fixed = io();
        assert_eq!(run(&core, &mut fixed), expected, "{body}");
        assert_eq!(fixed.take_internal_error(), None);
        let expected_output = if output.is_empty() {
            vec![]
        } else {
            vec![(Stream::Stdout, output.as_bytes().to_vec())]
        };
        assert_eq!(fixed.take_output(), expected_output);
        let lower = crate::ir::decision::lower_program(&core).unwrap();
        let bytecode = crate::bytecode::codegen::codegen(&lower, Arc::new(load.sources)).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(&bytecode, VmConfig::default(), HeapConfig::default());
            let mut services = crate::vm::dispatch::test_support::TestIo::new(RunInput {
                arguments: vec![],
                working_directory: ".".into(),
                script_directory: ".".into(),
            });
            vm.start_main().unwrap();
            let step = loop {
                match vm.run(services.runtime(mode)) {
                    VmStep::Requests(ids) => {
                        for id in ids {
                            vm.serve_request(&mut services.rt, id);
                        }
                    }
                    step @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break step,
                }
            };
            let expected = status.map_or(VmStep::Finished(MainOutcome::Ok), |code| {
                VmStep::Stopped(StopEnd {
                    reason: StopReason::Exit {
                        code,
                        die_failure: None,
                    },
                    release_failures: vec![],
                })
            });
            assert_eq!(step, expected, "{mode:?}: {body}");
            assert_eq!(services.take_output(), expected_output);
            assert!(services.rt.queue.live.is_empty());
            assert!(!services.rt.queue.has_outstanding());
        }
    }
}
