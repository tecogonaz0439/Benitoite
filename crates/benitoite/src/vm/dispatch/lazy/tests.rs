//! Lazy の状態遷移、枠の根、深い連鎖の検査（実装プラン R22「受け入れテスト」）。

use super::*;
use crate::bytecode::asm::ProgramBuilder;
use crate::runtime::heap::{HeapConfig, RootIdx};
use crate::runtime::io::services::RunInput;
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::unwind::{self, ReturnDest, ReturnStage, ReturnWork};
use crate::vm::{FRAME_COST, REG_COST, Vm};

fn io() -> TestIo {
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

fn lazy_at<'e>(ctx: &NoGcCtx<'e>, vm: &RunState, root: RootIdx) -> Value<'e> {
    vm.roots.get(ctx, root).unwrap()
}

// 関門: LAZY の捕捉と update の枠は VM の根の契約であり、結果だけでは保持の
// 漏れを捕まえられない。生存解析と VM の実物を使い、本番の差し込み口は加えない。
#[test]
fn lazy_captures_and_update_frame_survive_collection_and_cache_the_result() {
    check_lazy_capture_and_result();
}

/// 回収と結果の書き込みを同じ小さなケースで Miri からも通す（ADR 0318）。
pub(crate) fn check_lazy_capture_and_result() {
    let mut b = ProgramBuilder::new();
    b.program.main_kind = MainKind::Result;
    let main = b.proto("main", 0, 4).unwrap();
    let body = b.proto("lazy body", 0, 1).unwrap();
    let checkpoint = b.proto("checkpoint", 0, 1).unwrap();
    let error = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
    b.loadk(checkpoint, 0, ConstDesc::Unit).unwrap();
    b.code(checkpoint).unwrap().ret(0);
    b.code(main).unwrap().abx(Opcode::Lazy, 0, body.0);
    b.loadk(main, 2, ConstDesc::Func(checkpoint)).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 2, 2, 0);
    b.code(main).unwrap().op(Opcode::Force, 1, 0, 0);
    b.code(main)
        .unwrap()
        .op(Opcode::Con, 2, u16::try_from(error.0).unwrap(), 1);
    b.code(main).unwrap().ret(2);
    b.code(body).unwrap().proto.captures = vec![CaptureSource::Reg(3)];
    b.loadk(body, 0, ConstDesc::Func(checkpoint)).unwrap();
    b.code(body).unwrap().op(Opcode::Call, 0, 0, 0);
    b.code(body).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(body).unwrap().ret(0);
    let program = b.finish(main).unwrap();
    let config = VmConfig::default();
    let mut vm = vm(&program, config);
    vm.heap.epoch(|ctx| {
        let captured = ctx
            .alloc_str("only in the lazy capture", "R22 test")
            .unwrap();
        let stale = ctx
            .alloc_str("stale result must be cleared", "R22 test")
            .unwrap();
        ctx.store(&mut vm.state.segment_mut().unwrap().regs[3], captured);
        ctx.store(&mut vm.state.segment_mut().unwrap().regs[1], stale);
        notify_collect(&mut vm.state, ctx);
    });
    let mut before_collected = false;
    let mut update_collected = false;
    let mut retained = None;
    let mut services = io();
    loop {
        let exit = vm.heap.epoch(|ctx| {
            run_epoch(
                &program,
                config,
                &mut vm.state,
                ctx,
                services.runtime(ExecMode::Direct),
            )
        });
        if exit == LoopExit::Return {
            break;
        }
        vm.heap.epoch(|ctx| {
            if vm.state.tasks.live_count() == 0 {
                return;
            }
            let segment = crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                .segments
                .last()
                .unwrap();
            if vm.state.precall_done == Some(InstrRef { proto: main, pc: 2 }) {
                let lazy = ctx.load(&segment.regs[0]);
                let LazyState::Before { body } = ctx.host::<LazyState>(lazy).unwrap() else {
                    panic!()
                };
                assert_eq!(
                    ctx.str(ctx.field(ctx.load(body), 0).unwrap()),
                    Some("only in the lazy capture")
                );
                assert!(matches!(ctx.load(&segment.regs[3]), Value::Unit));
                before_collected = true;
            }
            if !update_collected && vm.state.precall_done == Some(InstrRef { proto: body, pc: 1 }) {
                let OtherKind::Update { lazy, at } = &segment.others.last().unwrap().kind else {
                    panic!()
                };
                assert_eq!(*at, InstrRef { proto: main, pc: 3 });
                assert_eq!(segment.calls[0].pc, 4);
                assert_eq!(program.proto(main).unwrap().live.call_write(3), Some(1));
                // FORCE の被演算子は最後の使用。結果の古い値も取り除かれている。
                assert!(matches!(ctx.load(&segment.regs[0]), Value::Unit));
                assert!(matches!(ctx.load(&segment.regs[1]), Value::Unit));
                assert!(vm.state.roots.is_empty());
                assert!(matches!(
                    ctx.host::<LazyState>(ctx.load(lazy)),
                    Some(LazyState::Evaluating { .. })
                ));
                update_collected = true;
            }
        });
        vm.heap.collect(&vm.state);
        assert!(vm.heap.take_fault().is_none());
        if update_collected && retained.is_none() {
            // update だけを根にした回収が終わった後、状態と二度目の force を調べる根を置く。
            vm.heap.epoch(|ctx| {
                let OtherKind::Update { lazy, .. } =
                    &crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                        .segments
                        .last()
                        .unwrap()
                        .others
                        .last()
                        .unwrap()
                        .kind
                else {
                    panic!()
                };
                let lazy = ctx.load(lazy);
                let LazyState::Evaluating { body, .. } = ctx.host::<LazyState>(lazy).unwrap()
                else {
                    panic!()
                };
                assert_eq!(
                    ctx.str(ctx.field(ctx.load(body), 0).unwrap()),
                    Some("only in the lazy capture")
                );
                retained = Some(vm.state.roots.push(ctx, lazy));
            });
        }
        if vm.state.precall_done.is_some() {
            crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, config.call_budget).unwrap();
        }
    }
    assert!(before_collected && update_collected);
    assert_eq!(
        vm.state.step,
        Some(VmStep::Finished(MainOutcome::Error(
            "only in the lazy capture".into()
        )))
    );
    let retained = retained.unwrap();
    vm.heap.epoch(|ctx| {
        let LazyState::Done { value } = ctx
            .host::<LazyState>(lazy_at(ctx, &vm.state, retained))
            .unwrap()
        else {
            panic!()
        };
        assert_eq!(ctx.str(ctx.load(value)), Some("only in the lazy capture"));
    });
    // 同じヒープと対象で FORCE を実行し直す。Done の経路は呼び出しの印も消す。
    let roots = std::mem::take(&mut vm.state.roots);
    vm.state = RunState::new(config, program.consts.len());
    vm.state.roots = roots;
    vm.start_main().unwrap();
    vm.heap.epoch(|ctx| {
        let lazy = lazy_at(ctx, &vm.state, retained);
        ctx.store(&mut vm.state.segment_mut().unwrap().regs[0], lazy);
        vm.state.frame_mut().unwrap().pc = 3;
        vm.state.precall_done = Some(InstrRef { proto: main, pc: 3 });
    });
    assert_eq!(
        vm.run(services.runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Error("only in the lazy capture".into()))
    );
    assert!(vm.state.precall_done.is_none());
    assert_eq!(vm.state.meter.frames(), 0);
    vm.heap.epoch(|ctx| vm.state.roots.truncate(ctx, 0));
    vm.heap.collect(&vm.state);
    assert!(vm.heap.object_ids().is_empty());
}

// 関門: 停止時の Before への復元は VM の停止の契約。正常な結果のテストでは
// update の枠の Stop 分岐を通らない（R22 の受け入れテスト）。
#[test]
fn stopping_a_lazy_body_restores_before_and_preserves_its_captures() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 1).unwrap();
    let body = b.proto("divide by zero", 0, 2).unwrap();
    b.code(main).unwrap().op(Opcode::Force, 0, 0, 0);
    b.code(main).unwrap().ret(0);
    b.loadk_int(body, 0, 1).unwrap();
    b.loadk_int(body, 1, 0).unwrap();
    b.code(body).unwrap().op(Opcode::DivI, 0, 0, 1);
    b.code(body).unwrap().ret(0);
    let program = b.finish(main).unwrap();
    let mut vm = vm(&program, VmConfig::default());
    let observed = vm.heap.epoch(|ctx| {
        let capture = ctx.alloc_str("kept after stop", "R22 test").unwrap();
        let func = ctx
            .alloc_fields(FieldsKind::Func, body.0, &[capture])
            .unwrap();
        let lazy = ctx.alloc_host(LazyState::Before {
            body: ctx.new_slot(func),
        });
        ctx.store(&mut vm.state.segment_mut().unwrap().regs[0], lazy);
        notify_collect(&mut vm.state, ctx);
        ctx.new_slot(lazy)
    });
    // 停止の手順は VM の根の保存領域も空にする。停止後を観察する対象だけは
    // テストの根として残し、実際の停止と回収を最後まで通す。
    struct Observed<'a>(&'a RunState, &'a Slot);
    impl crate::runtime::heap::Trace for Observed<'_> {
        fn trace(&self, t: &mut crate::runtime::heap::Tracer<'_>) {
            crate::runtime::heap::Trace::trace(self.0, t);
            t.slot(self.1);
        }
    }
    let mut services = io();
    while vm.heap.epoch(|ctx| {
        run_epoch(
            &program,
            VmConfig::default(),
            &mut vm.state,
            ctx,
            services.runtime(ExecMode::Direct),
        )
    }) == LoopExit::Collect
    {
        vm.heap.collect(&Observed(&vm.state, &observed));
        assert!(vm.heap.take_fault().is_none());
        if vm.state.precall_done.is_some() {
            crate::vm::dispatch::tasks::slow_path_end(
                &mut vm.state,
                VmConfig::default().call_budget,
            )
            .unwrap();
        }
    }
    let Some(VmStep::Stopped(end)) = vm.state.step.as_ref() else {
        panic!()
    };
    let StopReason::Error(info) = &end.reason else {
        panic!()
    };
    assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
    assert_eq!(info.at, Some(InstrRef { proto: body, pc: 2 }));
    assert!(vm.state.stack.segments.is_empty());
    assert_eq!(vm.state.meter.frames(), 0);
    vm.heap.collect(&Observed(&vm.state, &observed));
    vm.heap.epoch(|ctx| {
        let LazyState::Before { body } = ctx.host::<LazyState>(ctx.load(&observed)).unwrap() else {
            panic!()
        };
        assert_eq!(
            ctx.str(ctx.field(ctx.load(body), 0).unwrap()),
            Some("kept after stop")
        );
    });
    assert!(vm.heap.take_fault().is_none());
    vm.heap.epoch(|ctx| ctx.discard(observed));
    vm.heap.collect(&vm.state);
    assert!(vm.heap.object_ids().is_empty());
}

// 関門: 原因ごとの復元は公開の unwind_update の契約。DropRel は純粋な lazy の
// プログラムからは到達できないため、作業文書の指定どおり直接呼ぶ。
#[test]
fn update_unwind_obeys_every_cause_and_rejects_non_evaluating_states() {
    for cause in [
        UnwindCause::Return,
        UnwindCause::Cancel,
        UnwindCause::DropRel,
        UnwindCause::Stop,
    ] {
        let mut heap = crate::runtime::heap::Heap::new(HeapConfig {
            stress: true,
            ..HeapConfig::default()
        });
        let mut rt = RunState::new(VmConfig::default(), 0);
        let root = heap.epoch(|ctx| {
            let body = ctx.alloc_str("body to restore", "R22 test").unwrap();
            let returned = ctx.alloc_str("cached result", "R22 test").unwrap();
            rt.returning = Some(ReturnWork {
                value: ctx.new_slot(returned),
                dest: ReturnDest::Pending,
                stage: ReturnStage::Wrapping,
                at: InstrRef {
                    proto: ProtoIdx(0),
                    pc: 0,
                },
            });
            let waiters = if cause == UnwindCause::Stop {
                vec![TaskId {
                    index: 7,
                    generation: 3,
                }]
            } else {
                vec![]
            };
            let lazy = ctx.alloc_host(LazyState::Evaluating {
                body: ctx.new_slot(body),
                by: rt.current_task,
                waiters,
            });
            let slot = ctx.new_slot(lazy);
            assert!(matches!(
                unwind::unwind_update(
                    ctx,
                    &mut rt,
                    TaskId {
                        index: 0,
                        generation: 0
                    },
                    &slot,
                    cause
                ),
                Ok(UnwindStep::Popped)
            ));
            ctx.discard(slot);
            rt.roots.push(ctx, lazy)
        });
        heap.collect(&rt);
        heap.epoch(|ctx| {
            let lazy = lazy_at(ctx, &rt, root);
            match (cause, ctx.host::<LazyState>(lazy).unwrap()) {
                (UnwindCause::Return, LazyState::Done { value }) => {
                    assert_eq!(ctx.str(ctx.load(value)), Some("cached result"))
                }
                (
                    UnwindCause::Cancel | UnwindCause::DropRel | UnwindCause::Stop,
                    LazyState::Before { body },
                ) => assert_eq!(ctx.str(ctx.load(body)), Some("body to restore")),
                _ => panic!(),
            }
            let slot = ctx.new_slot(lazy);
            assert!(matches!(
                unwind::unwind_update(
                    ctx,
                    &mut rt,
                    TaskId {
                        index: 0,
                        generation: 0
                    },
                    &slot,
                    cause
                ),
                Err(Stop::Internal(_))
            ));
            ctx.discard(slot);
        });
        assert!(rt.scheduler.ready.is_empty());
        assert!(heap.take_fault().is_none());
    }
}

// 関門: 10 万段の値を実行しても Rust のスタックが深くならず、言語の上限で
// 止まる契約。小さな入れ子やヒープだけの深い値のテストでは捕まえられない。
#[test]
fn a_hundred_thousand_lazies_stop_at_the_vm_stack_limit() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 1).unwrap();
    let body = b.proto("force previous", 0, 1).unwrap();
    b.code(main).unwrap().op(Opcode::Force, 0, 0, 0);
    b.code(main).unwrap().ret(0);
    b.code(body).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
    b.code(body).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(body).unwrap().op(Opcode::Force, 0, 0, 0);
    b.code(body).unwrap().ret(0);
    let program = b.finish(main).unwrap();
    let config = VmConfig {
        max_call_stack_bytes: (FRAME_COST * 2 + REG_COST) * 8,
        ..VmConfig::default()
    };
    let mut vm = vm(&program, config);
    vm.heap.epoch(|ctx| {
        let mut lazy = ctx.alloc_host(LazyState::Done {
            value: ctx.new_slot(Value::Unit),
        });
        for _ in 0..100_000 {
            let func = ctx.alloc_fields(FieldsKind::Func, body.0, &[lazy]).unwrap();
            lazy = ctx.alloc_host(LazyState::Before {
                body: ctx.new_slot(func),
            });
        }
        ctx.store(&mut vm.state.segment_mut().unwrap().regs[0], lazy);
        notify_collect(&mut vm.state, ctx);
    });
    let VmStep::Stopped(end) = vm.run(io().runtime(ExecMode::Direct)) else {
        panic!()
    };
    let StopReason::Error(info) = end.reason else {
        panic!()
    };
    assert_eq!(
        info.stop,
        Stop::Resource(ResourceError::CallStackTooDeep { frames: 15 })
    );
    assert_eq!(vm.state.meter.frames(), 0);
    assert!(vm.state.stack.segments.is_empty());
    vm.heap.collect(&vm.state);
    assert!(vm.heap.object_ids().is_empty());
    assert!(vm.heap.take_fault().is_none());
}

// 関門: FORCE の誤った値と自己評価は VM の不具合として止める契約。
// 正常なコード生成では作れず、型検査や正常な結果のテストではこの境界に届かない。
#[test]
fn force_rejects_invalid_values_and_checks_limits_before_starting_evaluation() {
    for case in [
        "not lazy",
        "self evaluation",
        "body arguments",
        "stack limit",
    ] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 1).unwrap();
        let body = b
            .proto("body", u16::from(case == "body arguments"), 1)
            .unwrap();
        b.code(main).unwrap().op(Opcode::Force, 0, 0, 0);
        b.code(main).unwrap().ret(0);
        b.loadk(body, 0, ConstDesc::Unit).unwrap();
        b.code(body).unwrap().ret(0);
        let program = b.finish(main).unwrap();
        let config = VmConfig {
            max_call_stack_bytes: if case == "stack limit" {
                FRAME_COST * 3 + REG_COST * 2 - 1
            } else {
                crate::vm::DEFAULT_MAX_CALL_STACK
            },
            ..VmConfig::default()
        };
        let mut vm = vm(&program, config);
        vm.heap.epoch(|ctx| {
            let func = ctx.alloc_fields(FieldsKind::Func, body.0, &[]).unwrap();
            let value = match case {
                "not lazy" => Value::Unit,
                "self evaluation" => ctx.alloc_host(LazyState::Evaluating {
                    body: ctx.new_slot(func),
                    by: vm.state.current_task,
                    waiters: vec![],
                }),
                _ => ctx.alloc_host(LazyState::Before {
                    body: ctx.new_slot(func),
                }),
            };
            ctx.store(&mut vm.state.segment_mut().unwrap().regs[0], value);
        });
        let VmStep::Stopped(end) = vm.run(io().runtime(ExecMode::Direct)) else {
            panic!()
        };
        let StopReason::Error(info) = end.reason else {
            panic!()
        };
        if case == "stack limit" {
            assert_eq!(
                info.stop,
                Stop::Resource(ResourceError::CallStackTooDeep { frames: 1 })
            );
        } else {
            assert!(matches!(info.stop, Stop::Internal(_)), "{case}: {info:?}");
        }
        assert_eq!(info.at, Some(InstrRef { proto: main, pc: 0 }));
        assert_eq!(vm.state.meter.frames(), 0);
        assert!(vm.state.precall_done.is_none());
        assert!(vm.heap.take_fault().is_none());
    }
}
