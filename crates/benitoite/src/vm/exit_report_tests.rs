//! 内部の報告付きバイトコードから、既定の終了と不正な入力の拒否を確認する
//! （設計書 02-08「IO の命令」）。
use super::*;
use crate::base::{BytePos, FileId, Span};
use crate::bytecode::program::ExitReportSite;

fn report_program(message: Option<&str>) -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 4).unwrap();
    let exit = b
        .named_builtin("Benitoite.IO.Process.exit", 1, Capability::Io, None)
        .unwrap();
    b.loadk(main, 0, ConstDesc::Int(1)).unwrap();
    b.loadk(main, 1, ConstDesc::Str("\"cause\\n\"".into()))
        .unwrap();
    if let Some(message) = message {
        b.loadk(main, 2, ConstDesc::Str(message.into())).unwrap();
    }
    let code = b.code(main).unwrap();
    let pc = code.proto.code.len();
    code.op(Opcode::Io, 3, u16::try_from(exit.0).unwrap(), 0);
    code.proto.exit_reports[pc] = Some(ExitReportSite {
        cause_reg: 1,
        message_reg: message.map(|_| 2),
        span: Span {
            file: FileId(0),
            start: BytePos(7),
            end: BytePos(21),
        },
    });
    code.ret(3);
    b.finish(main).unwrap()
}

// 関門: VM の実行境界で、所有した文章・空/無し・位置と、verify を通さない不正入力の拒否を守る。
// 従来の exit は報告表を持たず、この情報を読み捨てる退行を捕まえない。
// 手書きの bytecode と独立した期待値を使い、本番の差し込み口を増やさない。
#[test]
fn exit_report_owns_strings_in_both_execution_modes() {
    for message in [None, Some(""), Some("plain explanation\nnext")] {
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let p = report_program(message);
            let (step, output) = run(&p, VmConfig::default(), HeapConfig::default(), mode);
            assert_eq!(
                step,
                VmStep::Stopped(StopEnd {
                    reason: StopReason::Exit {
                        code: 1,
                        die_failure: Some(DieFailure {
                            cause: "\"cause\\n\"".into(),
                            message: message.map(str::to_owned),
                            at: Span {
                                file: FileId(0),
                                start: BytePos(7),
                                end: BytePos(21)
                            },
                        }),
                    },
                    release_failures: vec![],
                })
            );
            assert!(output.is_empty());
        }
    }
}

// 関門: VM の情報を RunEnd へ移す経路での欠落を、ランタイムの公開入口で確認する。
// 通常の終了状態 1 も対照にし、main_error や補足の報告へ付け替えない。
#[test]
fn exit_report_runtime_result_distinguishes_an_ordinary_exit() {
    use crate::runtime::run::{
        EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource, run_program,
    };
    use std::sync::{Arc, Mutex};
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for ordinary in [false, true] {
            let mut p = report_program(None);
            if ordinary {
                p.protos[0].exit_reports.fill(None);
            }
            let stdout = Arc::new(Mutex::new(Vec::new()));
            let stderr = Arc::new(Mutex::new(Vec::new()));
            let end = run_program(
                &p,
                RunEnv {
                    input: RunInput {
                        arguments: vec![],
                        working_directory: "/".into(),
                        script_directory: "/".into(),
                    },
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                    stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                    interrupt: Box::new(NoInterrupt),
                    parts: None,
                    mode,
                    vm: VmConfig::default(),
                    heap: HeapConfig::default(),
                    dev_panic_after_first_write: false,
                },
            );
            assert!(end.end == EndKind::Exited(1));
            assert_eq!(end.exit_code, 1);
            assert_eq!(
                end.die_failure,
                (!ordinary).then(|| DieFailure {
                    cause: "\"cause\\n\"".into(),
                    message: None,
                    at: Span {
                        file: FileId(0),
                        start: BytePos(7),
                        end: BytePos(21),
                    },
                })
            );
            assert_eq!(end.main_error, None);
            assert!(end.reports.is_empty());
            assert!(stdout.lock().unwrap().is_empty());
            assert!(stderr.lock().unwrap().is_empty());
        }
    }
}

#[test]
fn exit_report_runtime_checks_unverified_operands() {
    for bad in [
        "cause type",
        "message type",
        "cause range",
        "message range",
        "code",
        "opcode",
        "builtin",
        "table",
    ] {
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut p = report_program(Some("explanation"));
            let proto = &mut p.protos[0];
            let pc = proto.exit_reports.iter().position(Option::is_some).unwrap();
            let report = proto.exit_reports[pc].as_mut().unwrap();
            match bad {
                "cause type" => report.cause_reg = 0,
                "message type" => report.message_reg = Some(0),
                "cause range" => report.cause_reg = 4,
                "message range" => report.message_reg = Some(4),
                "code" => p.consts[0] = ConstDesc::Int(2),
                "table" => proto.exit_reports.truncate(pc),
                "opcode" => {
                    let instr = proto.code[pc];
                    proto.code[pc] = Instr::abc(Opcode::Prim, instr.a(), instr.b(), instr.c());
                }
                "builtin" => {
                    p.builtins[0].id =
                        crate::builtins::lookup_builtin("String.byteLength").unwrap();
                }
                _ => unreachable!(),
            }
            let (step, _) = run(&p, VmConfig::default(), HeapConfig::default(), mode);
            let VmStep::Stopped(StopEnd {
                reason: StopReason::Error(info),
                ..
            }) = step
            else {
                panic!("{bad}: {step:?}");
            };
            let Stop::Internal(text) = info.stop else {
                panic!("{bad}: {:?}", info.stop);
            };
            let expected = match bad {
                "cause type" | "message type" => "exit report requires String",
                "cause range" | "message range" => "exit report register outside window",
                "table" => "exit report table entry missing",
                _ => "exit report requires canonical Process.exit(1)",
            };
            assert!(text.contains(expected), "{bad}: {text}");
        }
    }
}

// 関門: Request を返した後はヒープの報告値に頼らず、同じ番号の所有した情報だけを使う。
// Direct の即時応答では、待つ間の再読み出し・完了後の再配送による混入を捕まえない。
#[test]
fn request_exit_report_survives_collection_and_is_consumed_once() {
    let p = report_program(Some("explanation"));
    let mut vm = Vm::new(&p, VmConfig::default(), HeapConfig::default());
    vm.start_main().unwrap();
    let mut services = io();
    let id = request(&mut vm, &mut services);
    let expected = DieFailure {
        cause: "\"cause\\n\"".into(),
        message: Some("explanation".into()),
        at: Span {
            file: FileId(0),
            start: BytePos(7),
            end: BytePos(21),
        },
    };
    assert_eq!(
        services.rt.queue.live[&id].req.die_failure,
        Some(expected.clone())
    );
    vm.heap.epoch(|ctx| {
        crate::vm::dispatch::test_support::clear_waiting_registers(&mut vm.state, ctx, &[1, 2]);
    });
    vm.heap.collect(&vm.state);
    assert_eq!(vm.heap.verify(&vm.state), Ok(()));
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Requests(vec![])
    );
    vm.serve_request(&mut services.rt, id);
    assert!(services.rt.queue.live.is_empty());
    let expected = VmStep::Stopped(StopEnd {
        reason: StopReason::Exit {
            code: 1,
            die_failure: Some(expected),
        },
        release_failures: vec![],
    });
    vm.serve_request(&mut services.rt, id);
    assert_eq!(vm.run(services.runtime(ExecMode::Request)), expected);
    assert!(services.take_output().is_empty());
    assert!(vm.heap.take_fault().is_none());
}

// 関門: 停止の採用は要求の所有と独立した契約であり、先に採用された理由を表で保つ。
// 終了だけを起こす検査では、Internal/Interrupt や別の報告への転記を捕まえない。
#[test]
fn request_exit_report_does_not_replace_an_adopted_stop() {
    let p = report_program(Some("must be discarded"));
    for reason in [
        StopReason::Interrupted,
        StopReason::Error(StopInfo {
            stop: Stop::Internal("already stopped".into()),
            at: None,
            frames: vec![],
            spawns: vec![],
            deadlock: vec![],
        }),
        StopReason::Exit {
            code: 9,
            die_failure: None,
        },
        StopReason::Exit {
            code: 1,
            die_failure: Some(DieFailure {
                cause: "another request".into(),
                message: None,
                at: Span {
                    file: FileId(2),
                    start: BytePos(1),
                    end: BytePos(2),
                },
            }),
        },
    ] {
        let mut vm = Vm::new(&p, VmConfig::default(), HeapConfig::default());
        vm.start_main().unwrap();
        let mut services = io();
        let id = request(&mut vm, &mut services);
        assert!(services.rt.queue.live[&id].req.die_failure.is_some());
        vm.state.stopping = Some(reason.clone());
        vm.serve_request(&mut services.rt, id);
        vm.serve_request(&mut services.rt, id);
        assert_eq!(
            vm.run(services.runtime(ExecMode::Request)),
            VmStep::Stopped(StopEnd {
                reason,
                release_failures: vec![],
            })
        );
        assert!(services.rt.queue.live.is_empty());
        assert!(!services.rt.queue.has_outstanding());
        assert_eq!(vm.state.tasks.live_count(), 0);
        assert!(services.take_output().is_empty());
        assert!(vm.heap.take_fault().is_none());
    }
}
