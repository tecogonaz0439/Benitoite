//! VM の解放順序、待ち、失敗と継続の破棄（設計書 01-10・02-08、実装プラン R24）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::builtins::iface::OsResource;
use crate::bytecode::asm::ProgramBuilder;
use crate::bytecode::program::{
    CaptureSource, ClauseDesc, ConstDesc, HandlerDesc, HandlerIdx, MainKind, OpIdx, OpInfo,
};
use crate::runtime::heap::ResourceId;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::io::resources::{LendResult, ReleaseStart, ResourceContent, ResourceState};
use crate::runtime::io::services::RunInput;
use crate::runtime::sched::ExtOpId;
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::task::WaitReason;
use crate::vm::{FRAME_COST, REG_COST, StopInfo, Vm};
use std::any::Any;
use std::sync::{Arc, Mutex};

#[derive(Debug)]
struct Resource {
    name: &'static str,
    fail: bool,
    events: Arc<Mutex<Vec<&'static str>>>,
}
impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        self.events.lock().unwrap().push(self.name);
        if self.fail {
            Err(self.name.into())
        } else {
            Ok(())
        }
    }
}
fn handle(
    name: &'static str,
    fail: bool,
    events: &Arc<Mutex<Vec<&'static str>>>,
) -> Box<dyn OsResource> {
    Box::new(Resource {
        name,
        fail,
        events: Arc::clone(events),
    })
}
fn services() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}
fn vm(program: &CompiledProgram, config: VmConfig) -> Vm<'_> {
    let mut vm = Vm::new(
        program,
        config,
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    vm
}
fn install(
    vm: &mut Vm<'_>,
    reg: usize,
    kind: ResourceKind,
    name: &'static str,
    fail: bool,
    events: &Arc<Mutex<Vec<&'static str>>>,
) -> ResourceId {
    let id = vm.state.resources.insert(
        kind,
        ResourceContent::Os(Some(handle(name, fail, events))),
        Some(InstrRef {
            proto: ProtoIdx(100),
            pc: reg as u32,
        }),
    );
    vm.heap.epoch(|ctx| {
        ctx.store(
            &mut vm.state.segment_mut().unwrap().regs[reg],
            Value::Resource(id),
        )
    });
    id
}
fn run(vm: &mut Vm<'_>) -> VmStep {
    let step = vm.run(services().runtime(ExecMode::Direct));
    assert!(vm.heap.take_fault().is_none());
    step
}
fn stopped(step: VmStep) -> StopEnd {
    match step {
        VmStep::Stopped(end) => end,
        other @ (VmStep::Requests(_) | VmStep::Finished(_)) => panic!("expected stop: {other:?}"),
    }
}
fn stop_error(end: &StopEnd) -> &StopInfo {
    match &end.reason {
        StopReason::Error(info) => info,
        other @ (StopReason::Exit(_) | StopReason::Interrupted | StopReason::CheckFailed(_)) => {
            panic!("expected error: {other:?}")
        }
    }
}
fn unit(b: &mut ProgramBuilder, proto: ProtoIdx, reg: u16) {
    b.loadk(proto, reg, ConstDesc::Unit).unwrap();
    b.code(proto).unwrap().ret(reg);
}
fn divide_zero(b: &mut ProgramBuilder, proto: ProtoIdx, reg: u16) {
    b.loadk_int(proto, reg, 0).unwrap();
    b.code(proto).unwrap().op(Opcode::DivI, reg, reg, reg);
}
fn closure(b: &mut ProgramBuilder, proto: ProtoIdx, reg: u16, target: ProtoIdx) {
    b.code(proto).unwrap().abx(Opcode::Closure, reg, target.0);
}
fn handler(b: &mut ProgramBuilder, proto: ProtoIdx, handles: bool) -> u16 {
    let idx = HandlerIdx(b.program.handlers.len() as u32);
    b.program.handlers.push(HandlerDesc {
        clauses: if handles {
            vec![ClauseDesc {
                op: OpIdx(0),
                tail_resumptive: false,
            }]
        } else {
            vec![]
        },
    });
    let p = &mut b.code(proto).unwrap().proto;
    let local = p.handlers.len() as u16;
    p.handlers.push(idx);
    local
}
fn operation(b: &mut ProgramBuilder) {
    b.program.ops.push(OpInfo {
        name: "Test.ask".into(),
        effect: "Test".into(),
        arity: 0,
        builtin: None,
    });
}

// 関門: USE/RELEASE/RETURN を本物の VM で実行し、解放順・一度だけの解放・停止理由を守る。
// 表の単体テストでは、枠を戻す位置と止める手順との接続を確かめられない。
#[test]
fn own_releases_return_explicit_release_and_failure_aggregation() {
    for action in ["return", "release", "stop"] {
        for fail in [false, true] {
            let mut b = ProgramBuilder::new();
            let main = b.proto("main", 0, 8).unwrap();
            let child = b.proto("child", 2, 3).unwrap();
            for reg in [0, 1] {
                b.code(child).unwrap().op(Opcode::Use, reg, 0, 0);
            }
            if action == "release" {
                b.code(child).unwrap().op(Opcode::Release, 0, 0, 0);
            }
            if action == "stop" {
                divide_zero(&mut b, child, 2);
            }
            unit(&mut b, child, 2);
            closure(&mut b, main, 2, child);
            b.code(main).unwrap().op(Opcode::Move, 3, 0, 0);
            b.code(main).unwrap().op(Opcode::Move, 4, 1, 0);
            b.code(main).unwrap().op(Opcode::Call, 5, 2, 2);
            unit(&mut b, main, 6);
            let program = b.finish(main).unwrap();
            let mut vm = vm(&program, VmConfig::default());
            let events = Arc::new(Mutex::new(vec![]));
            install(&mut vm, 0, ResourceKind::FileReader, "A", fail, &events);
            install(&mut vm, 1, ResourceKind::FileReader, "B", fail, &events);
            let step = run(&mut vm);
            if action == "stop" {
                let end = stopped(step);
                assert_eq!(
                    stop_error(&end).stop,
                    Stop::Runtime(RuntimeError::DivisionByZero)
                );
                assert_eq!(
                    end.release_failures
                        .iter()
                        .map(|f| f.reason.as_str())
                        .collect::<Vec<_>>(),
                    if fail { vec!["B", "A"] } else { vec![] }
                );
            } else if fail {
                let end = stopped(step);
                let Stop::Runtime(RuntimeError::ReleaseFailed(failures)) = &stop_error(&end).stop
                else {
                    panic!("{end:?}")
                };
                assert_eq!(failures.len(), 1);
                assert_eq!(failures[0].reason, "B");
                assert_eq!(
                    failures[0].opened_at,
                    Some(InstrRef {
                        proto: ProtoIdx(100),
                        pc: 1
                    })
                );
                assert_eq!(end.release_failures.len(), 1);
                assert_eq!(end.release_failures[0].reason, "A");
            } else {
                assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
            }
            assert_eq!(*events.lock().unwrap(), vec!["B", "A"]);
            assert_eq!(vm.state.meter.bytes(), 0);
        }
    }
}

// 関門: 作業文書が指定する普通の戻りを、RETURN 一命令の出口で確かめる。
// 普通の戻りは局所を呼び出し元へ更新する。ReturnWork の経路は局所を読み直すため、
// この命令の出口ではまだ B を指す。回収の強制でもこの違いで経路を確かめる。
// この内部経路の確認は R24 の個別指示であり、新しい差し込み口は作らない。
#[test]
fn callee_return_keeps_callers_release_and_uses_plain_return() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 4).unwrap();
    let child = b.proto("child", 0, 1).unwrap();
    unit(&mut b, child, 0);
    b.code(main).unwrap().op(Opcode::Use, 0, 0, 0);
    closure(&mut b, main, 1, child);
    b.code(main).unwrap().op(Opcode::Call, 2, 1, 0);
    unit(&mut b, main, 3);
    let program = b.finish(main).unwrap();
    let mut vm = vm(&program, VmConfig::default());
    let events = Arc::new(Mutex::new(vec![]));
    let id = install(&mut vm, 0, ResourceKind::FileReader, "A", false, &events);
    // 本物の USE/CLOSURE/CALL/LOADK を一命令ずつ進め、B の RETURN の入口で止める。
    while vm.state.frame().unwrap().proto != child || vm.state.frame().unwrap().pc != 1 {
        let mut cursor = Cursor::load(&program, vm.state.frame().unwrap(), None).unwrap();
        let control = vm
            .heap
            .epoch(|ctx| {
                super::super::execute(
                    &program,
                    vm.config,
                    &mut vm.state,
                    ctx,
                    services().runtime(ExecMode::Direct),
                    &mut cursor,
                )
            })
            .unwrap();
        match control {
            Control::Next => {
                cursor.locals.pc += 1;
                cursor.locals.save(vm.state.frame_mut().unwrap());
            }
            Control::Reload | Control::Jumped => {}
            Control::Collect => {
                vm.heap.epoch(|ctx| {
                    super::super::clear_dead_registers(&program, &mut vm.state, ctx).unwrap()
                });
                vm.heap.collect(&vm.state);
                if vm.state.precall_done.is_some() {
                    crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                        .unwrap();
                }
            }
            Control::Return => panic!("returned before B"),
        }
    }
    vm.heap.collect(&vm.state);
    let mut cursor = Cursor::load(&program, vm.state.frame().unwrap(), None).unwrap();
    let instruction = cursor.locals.code[1];
    let control = vm
        .heap
        .epoch(|ctx| {
            super::super::handlers::dispatch(
                &program,
                vm.config,
                &mut vm.state,
                ctx,
                &mut cursor,
                instruction,
                BuiltinServices {
                    rt: services().runtime(ExecMode::Direct),
                },
            )
        })
        .unwrap();
    assert!(matches!(control, Control::Jumped | Control::Collect));
    assert_eq!((cursor.locals.proto, cursor.locals.pc), (main, 3));
    assert!(vm.state.returning.is_none());
    assert_eq!(vm.state.resources.state(id), Some(ResourceState::Open));
    assert!(events.lock().unwrap().is_empty());
    assert_eq!(run(&mut vm), VmStep::Finished(MainOutcome::Ok));
    assert_eq!(*events.lock().unwrap(), vec!["A"]);
}

// 関門: 解放が完了するまで Wait を返し続け、完了時の原因で失敗を扱う契約（R24 の指定）。
#[test]
fn waiting_release_rechecks_completion_and_current_cause() {
    for kind in [
        ResourceKind::FileReader,
        ResourceKind::FileWriter,
        ResourceKind::HttpExchange,
    ] {
        for cause in [
            UnwindCause::Return,
            UnwindCause::Cancel,
            UnwindCause::DropRel,
            UnwindCause::Stop,
        ] {
            for fail in [false, true] {
                let mut heap = Heap::new(HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                });
                let mut state = RunState::new(VmConfig::default(), 0);
                let events = Arc::new(Mutex::new(vec![]));
                let opened = InstrRef {
                    proto: ProtoIdx(2),
                    pc: 3,
                };
                let id = state.resources.insert(
                    kind,
                    ResourceContent::Os(Some(handle("release", fail, &events))),
                    None,
                );
                state.resources.check_lend(id).unwrap();
                let LendResult::Lent(handle) =
                    state.resources.lend(id, ExtOpId(0), state.current_task)
                else {
                    panic!("expected lend")
                };
                let mut log = ReleaseLog::default();
                for _ in 0..2 {
                    assert!(
                        matches!(heap.epoch(|ctx| unwind::unwind_release(ctx, &mut state, TaskId { index: 0, generation: 0 }, id, opened, UnwindCause::Return, &mut log)), Ok(UnwindStep::Wait(WaitReason::Release(r))) if r == id)
                    );
                }
                assert!(state.resources.give_back(id, handle));
                state.resources.check_release(id).unwrap();
                let op = state.scheduler.new_ext_op_id();
                let start = state.resources.request_release(id, op);
                let result = if kind == ResourceKind::FileReader {
                    let ReleaseStart::Done(result) = start else {
                        panic!("expected Done")
                    };
                    result
                } else {
                    assert!(matches!(start, ReleaseStart::Blocking));
                    assert!(
                        matches!(heap.epoch(|ctx| unwind::unwind_release(ctx, &mut state, TaskId { index: 0, generation: 0 }, id, opened, cause, &mut log)), Ok(UnwindStep::Wait(WaitReason::Release(r))) if r == id)
                    );
                    let (_, _, handle) = state.resources.take_release_job().unwrap();
                    assert!(state.resources.take_release_job().is_none());
                    handle.release()
                };
                state.resources.finish_release(id, result);
                let result = heap.epoch(|ctx| {
                    unwind::unwind_release(
                        ctx,
                        &mut state,
                        TaskId {
                            index: 0,
                            generation: 0,
                        },
                        id,
                        opened,
                        cause,
                        &mut log,
                    )
                });
                if fail && kind != ResourceKind::HttpExchange {
                    let failures = if cause == UnwindCause::Return {
                        let Err(Stop::Runtime(RuntimeError::ReleaseFailed(f))) = result else {
                            panic!("expected failure")
                        };
                        f
                    } else {
                        assert!(matches!(result, Ok(UnwindStep::Popped)));
                        std::mem::take(&mut log.failures)
                    };
                    assert_eq!(
                        failures,
                        vec![ReleaseFailure {
                            kind,
                            opened_at: Some(opened),
                            reason: "release".into()
                        }]
                    );
                } else {
                    assert!(matches!(result, Ok(UnwindStep::Popped)));
                    assert!(log.failures.is_empty());
                }
                assert!(matches!(
                    heap.epoch(|ctx| unwind::unwind_release(
                        ctx,
                        &mut state,
                        TaskId {
                            index: 0,
                            generation: 0
                        },
                        id,
                        opened,
                        cause,
                        &mut log
                    )),
                    Ok(UnwindStep::Popped)
                ));
                assert_eq!(*events.lock().unwrap(), vec!["release"]);
            }
        }
    }
}

// 関門: RELEASE の pc と RETURN の値・段を待ちの間に保ち、回収後に同じ枠から続ける。
// 表のテストでは根と命令位置の誤りに届かない。
#[test]
fn release_and_return_wait_keep_live_values_across_collection() {
    // R25 からは待ちが VM の内部で進む。外部の完了を与える直前の境界まで進め、
    // 仮の Requests 応答の代わりに、実際の待つ理由と保存した値を確かめる。
    fn parked(vm: &mut Vm<'_>) {
        let mut io = services();
        loop {
            let exit = vm.heap.epoch(|ctx| {
                super::super::run_until_exit(
                    vm.program,
                    vm.config,
                    &mut vm.state,
                    ctx,
                    io.runtime(ExecMode::Direct),
                    None,
                )
            });
            match exit {
                super::super::LoopExit::Collect => {
                    vm.heap.epoch(|ctx| {
                        super::super::clear_dead_registers(vm.program, &mut vm.state, ctx).unwrap()
                    });
                    vm.heap.collect(&vm.state);
                    if vm.state.precall_done.is_some() {
                        super::super::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                            .unwrap();
                    }
                }
                super::super::LoopExit::Return => {
                    assert!(matches!(
                        vm.state.scheduling.switch,
                        Some(crate::vm::state::Switch::Park)
                    ));
                    break;
                }
            }
        }
    }
    fn wake(vm: &mut Vm<'_>, id: ResourceId) {
        assert!(
            vm.state
                .scheduler
                .wake_if(vm.state.current_task, WaitReason::Release(id))
        );
        assert_eq!(
            vm.state
                .scheduler
                .next(&mut crate::runtime::sched::parts::FifoPicker),
            Some(vm.state.current_task)
        );
        vm.state.scheduling.switch = None;
    }
    for explicit in [false, true] {
        for lent in [false, true] {
            let mut b = ProgramBuilder::new();
            let main = b.proto("main", 0, 8).unwrap();
            b.program.main_kind = MainKind::Result;
            b.code(main).unwrap().op(Opcode::Use, 0, 0, 0);
            b.loadk(main, 1, ConstDesc::Str("live".into())).unwrap();
            b.loadk(main, 2, ConstDesc::Str(" value".into())).unwrap();
            b.code(main).unwrap().op(Opcode::Concat, 1, 1, 2);
            b.code(main).unwrap().op(Opcode::Concat, 7, 1, 2);
            let ctor = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
            b.code(main).unwrap().op(Opcode::Con, 3, ctor.0 as u16, 1);
            if explicit {
                b.code(main).unwrap().op(Opcode::Release, 0, 0, 0);
            }
            b.code(main).unwrap().ret(3);
            let program = b.finish(main).unwrap();
            let mut vm = vm(&program, VmConfig::default());
            let events = Arc::new(Mutex::new(vec![]));
            let id = install(&mut vm, 0, ResourceKind::FileWriter, "A", false, &events);
            let handle = if lent {
                vm.state.resources.check_lend(id).unwrap();
                let LendResult::Lent(h) =
                    vm.state
                        .resources
                        .lend(id, ExtOpId(99), vm.state.current_task)
                else {
                    panic!("expected lend")
                };
                Some(h)
            } else {
                None
            };
            parked(&mut vm);
            assert_eq!(
                vm.state
                    .scheduler
                    .waiting
                    .get(&vm.state.current_task)
                    .unwrap()
                    .reason,
                WaitReason::Release(id)
            );
            assert_eq!(vm.state.frame().unwrap().pc, 6);
            assert_eq!(vm.state.segment().unwrap().others.len(), 1);
            if explicit {
                assert!(vm.state.returning.is_none());
            } else {
                assert_eq!(
                    vm.state.returning.as_ref().unwrap().stage,
                    crate::vm::unwind::ReturnStage::OwnReleases
                );
            }
            vm.heap.epoch(|ctx| {
                super::super::clear_dead_registers(&program, &mut vm.state, ctx).unwrap();
                assert!(matches!(
                    ctx.load(&vm.state.segment().unwrap().regs[7]),
                    Value::Unit
                ));
            });
            vm.heap.collect(&vm.state);
            if let Some(handle) = handle {
                assert!(vm.state.resources.give_back(id, handle));
                vm.state.resources.check_release(id).unwrap();
                let op = vm.state.scheduler.new_ext_op_id();
                assert!(matches!(
                    vm.state.resources.request_release(id, op),
                    ReleaseStart::Blocking
                ));
                wake(&mut vm, id);
                parked(&mut vm);
                assert_eq!(vm.state.segment().unwrap().others.len(), 1);
            }
            let (_, _, handle) = vm.state.resources.take_release_job().unwrap();
            vm.state.resources.finish_release(id, handle.release());
            wake(&mut vm, id);
            assert_eq!(
                run(&mut vm),
                VmStep::Finished(MainOutcome::Error("live value".into()))
            );
            assert_eq!(*events.lock().unwrap(), vec!["A"]);
            assert_eq!(vm.state.meter.bytes(), 0);
        }
    }
}

fn captured_program(action: &str) -> (CompiledProgram, InstrRef) {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let outer = b.proto("A", 0, 6).unwrap();
    let inner = b.proto("B", 0, 4).unwrap();
    let clause = b.proto("clause", 1, 3).unwrap();
    operation(&mut b);
    for proto in [outer, inner, clause] {
        b.code(proto).unwrap().proto.boundary = false;
    }
    b.code(outer).unwrap().proto.captures = vec![CaptureSource::Reg(0), CaptureSource::Reg(1)];
    b.code(inner).unwrap().proto.captures = vec![CaptureSource::Reg(1)];
    b.code(outer).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(outer).unwrap().op(Opcode::Use, 0, 0, 0);
    b.code(outer).unwrap().op(Opcode::GetCap, 1, 1, 0);
    closure(&mut b, outer, 2, inner);
    let h = handler(&mut b, outer, false);
    b.code(outer).unwrap().op(Opcode::Handle, 3, 2, h);
    b.code(outer).unwrap().ret(3);
    b.code(inner).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(inner).unwrap().op(Opcode::Use, 0, 0, 0);
    let perform_at = InstrRef {
        proto: inner,
        pc: 2,
    };
    match action {
        "stop body" => divide_zero(&mut b, inner, 1),
        "escape" => {
            b.loadk(inner, 1, ConstDesc::Unit).unwrap();
            b.code(inner).unwrap().op(Opcode::Escape, 1, 0, 0);
        }
        _ => b.code(inner).unwrap().op(Opcode::Perform, 1, 0, 0),
    }
    unit(&mut b, inner, 1);
    if action == "stop clause" {
        divide_zero(&mut b, clause, 1);
    }
    unit(&mut b, clause, 1);
    closure(&mut b, main, 2, outer);
    closure(&mut b, main, 3, clause);
    let h = handler(&mut b, main, true);
    b.code(main).unwrap().op(Opcode::Handle, 4, 2, h);
    unit(&mut b, main, 5);
    (b.finish(main).unwrap(), perform_at)
}

// 関門: 捕捉した区画の実物の解放枠を、E-DropRel/Stop/ESCAPE が内側から降ろす契約。
// R21 から引き渡された PERFORM の上限の検査も、同じプログラムで確かめる。
#[test]
fn captured_releases_drop_stop_escape_and_perform_limit() {
    for action in ["drop", "stop body", "stop clause", "escape", "limit"] {
        for fail in [false, true] {
            let (program, perform_at) = captured_program(action);
            let config = if action == "limit" {
                VmConfig {
                    max_call_stack_bytes: 7 * FRAME_COST + 26 * REG_COST,
                    ..VmConfig::default()
                }
            } else {
                VmConfig::default()
            };
            let mut vm = vm(&program, config);
            let events = Arc::new(Mutex::new(vec![]));
            install(&mut vm, 0, ResourceKind::FileReader, "A", fail, &events);
            install(&mut vm, 1, ResourceKind::FileReader, "B", fail, &events);
            let step = run(&mut vm);
            if action == "limit" {
                let end = stopped(step);
                assert_eq!(
                    stop_error(&end).stop,
                    Stop::Resource(ResourceError::CallStackTooDeep { frames: 7 })
                );
                assert_eq!(stop_error(&end).at, Some(perform_at));
                assert_eq!(end.release_failures.len(), if fail { 2 } else { 0 });
            } else if action.starts_with("stop") {
                let end = stopped(step);
                assert_eq!(
                    stop_error(&end).stop,
                    Stop::Runtime(RuntimeError::DivisionByZero)
                );
                assert_eq!(
                    end.release_failures
                        .iter()
                        .map(|f| f.reason.as_str())
                        .collect::<Vec<_>>(),
                    if fail { vec!["B", "A"] } else { vec![] }
                );
            } else if fail {
                let end = stopped(step);
                let Stop::Runtime(RuntimeError::ReleaseFailed(f)) = &stop_error(&end).stop else {
                    panic!("{end:?}")
                };
                let reasons = f
                    .iter()
                    .chain(&end.release_failures)
                    .map(|f| f.reason.as_str())
                    .collect::<Vec<_>>();
                assert_eq!(reasons, vec!["B", "A"]);
            } else {
                assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
            }
            assert_eq!(*events.lock().unwrap(), vec!["B", "A"]);
            assert_eq!(vm.state.meter.bytes(), 0);
        }
    }
}

// 関門: A の解放枠・B を包む drop・B の呼び出し・B の解放枠が同一区画にある場合。
// HANDLE と PERFORM の実行が drop を作るので、準備で枠の順序を与えていない（R24）。
#[test]
fn releases_around_a_wrapped_clause_in_one_segment_keep_order() {
    for action in ["drop", "stop", "escape"] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("A", 0, 8).unwrap();
        let body = b.proto("body", 0, 1).unwrap();
        let clause = b.proto("B", 1, 3).unwrap();
        b.code(clause).unwrap().proto.boundary = false;
        b.code(clause).unwrap().proto.captures = vec![CaptureSource::Reg(1)];
        operation(&mut b);
        b.code(body).unwrap().op(Opcode::Perform, 0, 0, 0);
        unit(&mut b, body, 0);
        b.code(clause).unwrap().op(Opcode::GetCap, 1, 0, 0);
        b.code(clause).unwrap().op(Opcode::Use, 1, 0, 0);
        if action == "stop" {
            divide_zero(&mut b, clause, 2);
        }
        b.loadk(clause, 2, ConstDesc::Unit).unwrap();
        b.code(clause).unwrap().op(
            if action == "escape" {
                Opcode::Escape
            } else {
                Opcode::Return
            },
            2,
            0,
            0,
        );
        b.code(main).unwrap().op(Opcode::Use, 0, 0, 0);
        closure(&mut b, main, 2, body);
        closure(&mut b, main, 3, clause);
        let h = handler(&mut b, main, true);
        b.code(main).unwrap().op(Opcode::Handle, 4, 2, h);
        unit(&mut b, main, 5);
        let program = b.finish(main).unwrap();
        let mut vm = vm(&program, VmConfig::default());
        let events = Arc::new(Mutex::new(vec![]));
        install(&mut vm, 0, ResourceKind::FileReader, "A", false, &events);
        install(&mut vm, 1, ResourceKind::FileReader, "B", false, &events);
        let step = run(&mut vm);
        if action == "stop" {
            assert_eq!(
                stop_error(&stopped(step)).stop,
                Stop::Runtime(RuntimeError::DivisionByZero)
            );
        } else {
            assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
        }
        assert_eq!(*events.lock().unwrap(), vec!["B", "A"]);
        assert_eq!(vm.state.meter.bytes(), 0);
    }
}

#[test]
fn invalid_use_and_release_report_internal_without_creating_frames() {
    for opcode in [Opcode::Use, Opcode::Release] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 1).unwrap();
        b.code(main).unwrap().op(opcode, 0, 0, 0);
        unit(&mut b, main, 0);
        let program = b.finish(main).unwrap();
        let mut vm = vm(&program, VmConfig::default());
        assert!(matches!(
            stop_error(&stopped(run(&mut vm))).stop,
            Stop::Internal(_)
        ));
        assert_eq!(vm.state.meter.bytes(), 0);
    }
}

// 関門: USE の上限の検査は積む前、RELEASE は呼び出し元の枠へ進まない（R24）。
#[test]
fn use_limit_and_release_ownership_preserve_cleanup() {
    for limit in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 4).unwrap();
        let child = b.proto("child", 0, 1).unwrap();
        b.code(main).unwrap().op(Opcode::Use, 0, 0, 0);
        closure(&mut b, main, 1, child);
        b.code(main).unwrap().op(Opcode::Call, 2, 1, 0);
        unit(&mut b, main, 3);
        b.code(child).unwrap().op(Opcode::Release, 0, 0, 0);
        unit(&mut b, child, 0);
        let program = b.finish(main).unwrap();
        let config = if limit {
            VmConfig {
                max_call_stack_bytes: FRAME_COST + 4 * REG_COST,
                ..VmConfig::default()
            }
        } else {
            VmConfig::default()
        };
        let mut vm = vm(&program, config);
        let events = Arc::new(Mutex::new(vec![]));
        install(&mut vm, 0, ResourceKind::FileReader, "A", false, &events);
        let end = stopped(run(&mut vm));
        if limit {
            assert_eq!(
                stop_error(&end).stop,
                Stop::Resource(ResourceError::CallStackTooDeep { frames: 1 })
            );
            assert_eq!(stop_error(&end).at, Some(InstrRef { proto: main, pc: 0 }));
            assert!(events.lock().unwrap().is_empty());
        } else {
            assert!(matches!(stop_error(&end).stop, Stop::Internal(_)));
            assert_eq!(
                stop_error(&end).at,
                Some(InstrRef {
                    proto: child,
                    pc: 0
                })
            );
            assert_eq!(*events.lock().unwrap(), vec!["A"]);
        }
        assert_eq!(vm.state.meter.bytes(), 0);
    }
}
