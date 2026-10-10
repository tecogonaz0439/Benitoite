//! セルの更新の枠と回収の根の契約（設計書 02-08「可変のセル」、実装プラン R23）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::bytecode::asm::ProgramBuilder;
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::io::services::RunInput;
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::unwind::{self, ReturnStage, ReturnWork, UnwindCause, UnwindStep};
use crate::vm::{TaskId, Vm};

fn stress() -> HeapConfig {
    HeapConfig {
        stress: true,
        ..HeapConfig::default()
    }
}
fn services() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}
fn cell_frame(state: &RunState) -> &CellUpdate {
    let Some(OtherKind::CellUpdate(frame)) =
        state.segment().unwrap().others.last().map(|o| &o.kind)
    else {
        panic!("cell update frame missing")
    };
    frame
}
fn at() -> InstrRef {
    InstrRef {
        proto: ProtoIdx(0),
        pc: 0,
    }
}

// 関門: 原因による書き込みの禁止、版の比較、戻り値の根を一つの表で確かめる。
// 一つのタスクのスクリプトは Retry や Cancel を作れず、ReturnWork だけに残る
// 値の回収の時点も選べない。公開の unwind_cell_update を使い、差し込み口を加えない。
#[test]
fn unwind_respects_version_and_cause_and_roots_the_returned_value() {
    for (cause, changed, writes) in [
        (UnwindCause::Return, false, true),
        (UnwindCause::Return, true, false),
        (UnwindCause::Cancel, false, false),
        (UnwindCause::DropRel, false, false),
        (UnwindCause::Stop, false, false),
    ] {
        let mut heap = Heap::new(stress());
        let mut state = RunState::new(VmConfig::default(), 0);
        heap.epoch(|ctx| {
            let cell = ctx.alloc_cell(Value::Int(7));
            let version = ctx.cell_version(cell).unwrap();
            if changed {
                ctx.cell_set(cell, Value::Int(8)).unwrap();
            }
            let result = ctx.alloc_str("updated", "test").unwrap();
            state.returning = Some(ReturnWork {
                value: ctx.new_slot(result),
                dest: ReturnDest::Pending,
                stage: ReturnStage::Wrapping,
                at: at(),
            });
            state.stack.segments.push(crate::vm::frame::Segment {
                others: vec![OtherFrame {
                    depth: 0,
                    kind: OtherKind::CellUpdate(CellUpdate {
                        cell: ctx.new_slot(cell),
                        version,
                        func: Slot::default(),
                    }),
                }],
                ..crate::vm::frame::Segment::default()
            });
        });
        // 関数の結果は ReturnWork::value 以外から辿れない状態で回収する（R03 の根の引き渡し）。
        heap.collect(&state);
        heap.epoch(|ctx| {
            let other = state.segment_mut().unwrap().others.pop().unwrap();
            let OtherKind::CellUpdate(frame) = &other.kind else {
                panic!("cell update required")
            };
            let step = unwind::unwind_cell_update(
                ctx,
                &mut state,
                TaskId {
                    index: 0,
                    generation: 0,
                },
                frame,
                cause,
            )
            .unwrap();
            if cause == UnwindCause::Return && changed {
                assert!(matches!(step, UnwindStep::Retry));
            } else {
                assert!(matches!(step, UnwindStep::Popped));
            }
            let cell = ctx.load(&frame.cell);
            if writes {
                assert_eq!(ctx.str(ctx.cell_get(cell).unwrap()), Some("updated"));
                assert_eq!(ctx.cell_version(cell), Some(1));
                assert!(matches!(
                    ctx.load(&state.returning.as_ref().unwrap().value),
                    Value::Unit
                ));
            } else {
                assert_eq!(
                    ctx.cell_get(cell).unwrap().as_int(),
                    Some(if changed { 8 } else { 7 })
                );
                assert_eq!(ctx.cell_version(cell), Some(u64::from(changed)));
                assert_eq!(
                    ctx.str(ctx.load(&state.returning.as_ref().unwrap().value)),
                    Some("updated")
                );
            }
            ctx.discard(other);
            ctx.discard(state.returning.take().unwrap());
        });
        heap.collect(&state);
        assert!(heap.object_ids().is_empty());
        assert!(heap.take_fault().is_none());
    }
}

// 関門: 実際の UPDATE と末尾呼び出しを進め、被演算子の最後の使用の後の根を確かめる。
// 関数自身の呼び出しの枠も末尾呼び出しで置き換わるので、元の関数は更新枠だけに残る。
#[test]
fn update_frame_is_the_only_root_for_cell_and_original_function() {
    check_cell_update_roots();
}

/// 更新枠だけを根にした書き込みを Miri からも通す（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
pub(crate) fn check_cell_update_roots() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 3).unwrap();
    let outer = b.proto("update function", 1, 4).unwrap();
    let inner = b.proto("allocate", 1, 4).unwrap();
    let identity = b.proto("identity", 1, 1).unwrap();
    b.code(main).unwrap().op(Opcode::Update, 0, 1, 2);
    b.code(main).unwrap().ret(0);
    b.code(outer)
        .unwrap()
        .proto
        .captures
        .push(CaptureSource::Reg(0));
    b.code(outer).unwrap().abx(Opcode::Closure, 2, inner.0);
    b.code(outer).unwrap().op(Opcode::Move, 3, 0, 0);
    b.code(outer).unwrap().op(Opcode::TailCall, 0, 2, 1);
    b.code(inner).unwrap().op(Opcode::List, 1, 0, 1);
    b.code(inner).unwrap().abx(Opcode::Closure, 2, identity.0);
    b.code(inner).unwrap().op(Opcode::Move, 3, 1, 0);
    b.code(inner).unwrap().op(Opcode::Call, 1, 2, 1);
    b.code(inner).unwrap().ret(1);
    b.code(identity).unwrap().ret(0);
    let program = b.finish(main).unwrap();
    let config = VmConfig::default();
    let mut vm = Vm::new(&program, config, stress());
    vm.start_main().unwrap();
    vm.heap.epoch(|ctx| {
        let marker = ctx.alloc_str("function capture", "test").unwrap();
        let func = ctx
            .alloc_fields(FieldsKind::Func, outer.0, &[marker])
            .unwrap();
        let cell = ctx.alloc_cell(Value::Int(17));
        let window = &mut vm.state.segment_mut().unwrap().regs;
        ctx.store(&mut window[1], cell);
        ctx.store(&mut window[2], func);
    });
    let mut io = services();
    loop {
        let exit = vm.heap.epoch(|ctx| {
            run_epoch(
                &program,
                config,
                &mut vm.state,
                ctx,
                io.runtime(ExecMode::Direct),
            )
        });
        assert_eq!(exit, LoopExit::Collect);
        if vm.state.frame().unwrap().proto == inner {
            break;
        }
        vm.heap.collect(&vm.state);
    }
    assert_eq!(vm.state.segment().unwrap().calls[0].pc, 1);
    vm.heap.epoch(|ctx| {
        let segment = vm.state.segment().unwrap();
        assert!(matches!(ctx.load(&segment.regs[1]), Value::Unit));
        assert!(matches!(ctx.load(&segment.regs[2]), Value::Unit));
    });
    vm.heap.collect(&vm.state);
    vm.heap.epoch(|ctx| {
        let frame = cell_frame(&vm.state);
        assert_eq!(
            ctx.cell_get(ctx.load(&frame.cell)).unwrap().as_int(),
            Some(17)
        );
        assert_eq!(
            ctx.str(ctx.field(ctx.load(&frame.func), 0).unwrap()),
            Some("function capture")
        );
        // 更新枠だけから辿れる状態での回収を確かめた後、完了時の値を観察する根を残す。
        let cell = ctx.load(&frame.cell);
        vm.state.constants.push(Some(ctx.new_slot(cell)));
    });
    assert_eq!(
        vm.run(io.runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    vm.heap.epoch(|ctx| {
        let cell = ctx.load(vm.state.constants.last().unwrap().as_ref().unwrap());
        let value = ctx.cell_get(cell).unwrap();
        assert_eq!(crate::runtime::list::len(ctx, value).unwrap(), 1);
        assert_eq!(
            crate::runtime::list::get(ctx, value, 0)
                .unwrap()
                .unwrap()
                .as_int(),
            Some(17)
        );
        assert_eq!(ctx.cell_version(cell), Some(1));
    });
    assert_eq!(vm.state.meter.bytes(), 0);
    assert!(vm.heap.take_fault().is_none());
}

// 関門: タスクなしで版の不一致を作り、本物の戻りの経路から安全点・再開・呼び直しを通す。
// 枠の version、ret、ReturnWork の手放しを忘れた退行と、二重の tick を捕まえる（R23）。
#[test]
fn retry_reloads_version_and_argument_after_collecting_and_returns_to_same_destination() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 3).unwrap();
    let callback = b.proto("increment", 1, 2).unwrap();
    b.code(main).unwrap().op(Opcode::Update, 0, 1, 2);
    b.code(main).unwrap().ret(0);
    b.loadk(callback, 1, ConstDesc::Int(1)).unwrap();
    b.code(callback).unwrap().op(Opcode::AddI, 0, 0, 1);
    b.code(callback).unwrap().ret(0);
    let program = b.finish(main).unwrap();
    let config = VmConfig {
        call_budget: 7,
        ..VmConfig::default()
    };
    let mut vm = Vm::new(&program, config, stress());
    vm.start_main().unwrap();
    vm.state.frame_mut().unwrap().pc = 1;
    let return_at = InstrRef {
        proto: callback,
        pc: 2,
    };
    vm.heap.epoch(|ctx| {
        let cell = ctx.alloc_cell(Value::Int(1));
        ctx.cell_set(cell, Value::Int(20)).unwrap();
        let func = ctx.alloc_fields(FieldsKind::Func, callback.0, &[]).unwrap();
        vm.state.segment_mut().unwrap().others.push(OtherFrame {
            depth: 1,
            kind: OtherKind::CellUpdate(CellUpdate {
                cell: ctx.new_slot(cell),
                version: 0,
                func: ctx.new_slot(func),
            }),
        });
        vm.state.meter.grow(1, 0);
        vm.state.returning = Some(ReturnWork {
            value: ctx.new_slot(Value::Int(2)),
            dest: ReturnDest::Reg { segment: 0, reg: 0 },
            stage: ReturnStage::Wrapping,
            at: return_at,
        });
        assert!(matches!(
            handlers::continue_return(&program, &mut vm.state, ctx, None).unwrap(),
            Control::Collect
        ));
        clear_dead_registers(&program, &mut vm.state, ctx).unwrap();
    });
    let budget = vm.state.budget;
    assert_eq!(vm.state.precall_done, Some(return_at));
    assert_eq!(cell_frame(&vm.state).version, 0);
    vm.heap.collect(&vm.state);
    vm.heap.epoch(|ctx| {
        assert!(matches!(
            handlers::continue_return(&program, &mut vm.state, ctx, None).unwrap(),
            Control::Reload
        ));
        assert_eq!(vm.state.budget, budget);
        assert!(vm.state.precall_done.is_none());
        assert!(vm.state.returning.is_none());
        assert_eq!(cell_frame(&vm.state).version, 1);
        assert_eq!(vm.state.frame().unwrap().ret, Some(0));
        let base = index(vm.state.frame().unwrap().base).unwrap();
        assert_eq!(
            ctx.load(&vm.state.segment().unwrap().regs[base]).as_int(),
            Some(20)
        );
        // 呼び直しの後は版が一致し、同じ枠が書き込みを行う。戻りの値は更新した引数に 1 を加える。
        let cell = ctx.load(&cell_frame(&vm.state).cell);
        vm.state.constants.push(Some(ctx.new_slot(cell)));
    });
    assert_eq!(
        vm.run(services().runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Ok)
    );
    vm.heap.epoch(|ctx| {
        let cell = ctx.load(vm.state.constants.last().unwrap().as_ref().unwrap());
        assert_eq!(ctx.cell_get(cell).unwrap().as_int(), Some(21));
        assert_eq!(ctx.cell_version(cell), Some(2));
    });
    assert_eq!(vm.state.meter.bytes(), 0);
    assert!(vm.heap.take_fault().is_none());
}

// 関門: 実際のスクリプトを停止まで動かす。unwind の単体テストだけでは、停止の辿りが
// 誤って Return を原因にしてセルを書き換える退行を捕まえない。観察するセルだけを
// 定数の根にも残す（停止が積み重ねと RootStack を消すため）。本番の口は増やさない。
#[test]
fn division_by_zero_in_update_stops_without_writing_cell() {
    use crate::pipeline::{self, CheckOptions};
    let source = b"function main() -> Unit uses State\n bind r <- Reference.new(7)\n Reference.update(r, lambda(n: Integer) return n div 0 end lambda)\n return ()\nend function\n";
    let checked = pipeline::check_text(
        "stopped-cell.bnt",
        source,
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
    let program = pipeline::compile(&core, checked.sources).unwrap();
    let config = VmConfig::default();
    let mut vm = Vm::new(&program, config, stress());
    vm.start_main().unwrap();
    let mut io = services();
    let exit = vm.heap.epoch(|ctx| {
        run_epoch(
            &program,
            config,
            &mut vm.state,
            ctx,
            io.runtime(ExecMode::Direct),
        )
    });
    assert_eq!(exit, LoopExit::Collect);
    vm.heap.epoch(|ctx| {
        let cell = vm
            .state
            .segment()
            .unwrap()
            .regs
            .iter()
            .map(|s| ctx.load(s))
            .find(|v| ctx.cell_version(*v).is_some())
            .unwrap();
        vm.state.constants.push(Some(ctx.new_slot(cell)));
    });
    vm.heap.collect(&vm.state);
    let VmStep::Stopped(end) = vm.run(io.runtime(ExecMode::Direct)) else {
        panic!("program did not stop")
    };
    let StopReason::Error(info) = end.reason else {
        panic!("expected runtime error")
    };
    assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
    vm.heap.epoch(|ctx| {
        let cell = ctx.load(vm.state.constants.last().unwrap().as_ref().unwrap());
        assert_eq!(ctx.cell_get(cell).unwrap().as_int(), Some(7));
        assert_eq!(ctx.cell_version(cell), Some(0));
    });
    assert_eq!(vm.state.meter.bytes(), 0);
    assert!(vm.state.returning.is_none());
    assert!(vm.heap.take_fault().is_none());
}
