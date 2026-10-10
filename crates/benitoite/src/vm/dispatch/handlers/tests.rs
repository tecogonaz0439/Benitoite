//! ハンドラと継続を降ろす契約を VM の入口から確かめる（実装プラン R20・R21）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::bytecode::asm::ProgramBuilder;
use crate::bytecode::program::{ClauseDesc, HandlerDesc, HandlerIdx, MainKind, OpInfo};
use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::RunInput;
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::{StopInfo, Vm};

fn services() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}
fn operation(b: &mut ProgramBuilder, name: &str, arity: u16) -> OpIdx {
    let op = OpIdx(b.program.ops.len().try_into().unwrap());
    b.program.ops.push(OpInfo {
        name: name.into(),
        effect: "Test".into(),
        arity,
        builtin: None,
    });
    op
}
fn handler(b: &mut ProgramBuilder, owner: ProtoIdx, clauses: &[(OpIdx, bool)]) -> u16 {
    let idx = HandlerIdx(b.program.handlers.len().try_into().unwrap());
    b.program.handlers.push(HandlerDesc {
        clauses: clauses
            .iter()
            .map(|&(op, tail_resumptive)| ClauseDesc {
                op,
                tail_resumptive,
            })
            .collect(),
    });
    let p = &mut b.code(owner).unwrap().proto;
    let local = p.handlers.len().try_into().unwrap();
    p.handlers.push(idx);
    local
}
fn closure(b: &mut ProgramBuilder, p: ProtoIdx, reg: u16, called: ProtoIdx) {
    b.code(p).unwrap().abx(Opcode::Closure, reg, called.0);
}
fn finish(b: &mut ProgramBuilder, main: ProtoIdx, reg: u16, conversion: Option<&str>) {
    b.program.main_kind = MainKind::Result;
    if let Some(name) = conversion {
        let f = b.named_builtin(name, 1, Capability::Pure, None).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, reg, f.0.try_into().unwrap(), reg);
    }
    let ctor = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
    b.code(main)
        .unwrap()
        .op(Opcode::Con, 15, ctor.0.try_into().unwrap(), reg);
    b.code(main).unwrap().ret(15);
}
fn run(vm: &mut Vm<'_>, io: &mut TestIo, mode: ExecMode) -> VmStep {
    loop {
        match vm.run(io.runtime(mode)) {
            VmStep::Requests(ids) => {
                assert!(!ids.is_empty());
                for id in ids {
                    vm.serve_request(&mut io.rt, id);
                }
            }
            step @ (VmStep::Finished(_) | VmStep::Stopped(_)) => {
                assert!(vm.heap.take_fault().is_none());
                return step;
            }
        }
    }
}
fn value(program: &CompiledProgram, config: VmConfig, answer: &str) {
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            program,
            config,
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        assert_eq!(
            run(&mut vm, &mut services(), mode),
            VmStep::Finished(MainOutcome::Error(answer.into()))
        );
        assert_eq!(vm.state.meter.bytes(), 0);
    }
}
fn error(step: VmStep) -> StopInfo {
    match step {
        VmStep::Stopped(StopEnd {
            reason: StopReason::Error(info),
            ..
        }) => info,
        other @ (VmStep::Requests(_) | VmStep::Finished(_) | VmStep::Stopped(_)) => {
            panic!("expected stopped: {other:?}")
        }
    }
}
fn resume_clause(b: &mut ProgramBuilder, name: &str, add: i64, after: i64) -> ProtoIdx {
    let p = b.proto(name, 2, 5).unwrap();
    b.loadk_int(p, 2, add).unwrap();
    b.code(p).unwrap().op(Opcode::AddI, 2, 0, 2);
    b.code(p).unwrap().op(Opcode::Resume, 3, 1, 2);
    if after != 0 {
        b.loadk_int(p, 4, after).unwrap();
        b.code(p).unwrap().op(Opcode::AddI, 3, 3, 4);
    }
    b.code(p).unwrap().ret(3);
    p
}

// 関門: 同じ本体で操作を繰り返し、E-Resume の戻り先と深いハンドラの保持を守る。
// 第 1 段のテストには区画の移動がなく、この退行を捕まえられない。公開の VM の入口を使う。
#[test]
fn repeated_operations_and_computation_around_resume() {
    for after in [0, 100] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let body = b.proto("body", 0, 5).unwrap();
        let op = operation(&mut b, "Test.ask", 1);
        for (dst, n) in [(0, 1), (1, 2), (2, 3)] {
            b.loadk_int(body, 4, n).unwrap();
            b.code(body)
                .unwrap()
                .op(Opcode::Perform, dst, op.0.try_into().unwrap(), 4);
        }
        b.code(body).unwrap().op(Opcode::AddI, 0, 0, 1);
        b.code(body).unwrap().op(Opcode::AddI, 0, 0, 2);
        b.code(body).unwrap().ret(0);
        let clause = resume_clause(&mut b, "clause", 10, after);
        let h = handler(&mut b, main, &[(op, after == 0)]);
        closure(&mut b, main, 0, body);
        closure(&mut b, main, 1, clause);
        b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
        finish(&mut b, main, 2, Some("Integer.toString"));
        value(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            &(36 + after * 3).to_string(),
        );
    }
}

// 関門: 捕まえた区画の中の内側の handle を保ち、節は選んだ handle の外で操作を呼ぶ。
#[test]
fn nested_handlers_keep_inner_handlers_and_search_outside_clauses() {
    for in_clause in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let outer = b.proto("outer body", 0, 4).unwrap();
        let inner = b.proto("inner body", 0, 4).unwrap();
        let op0 = operation(&mut b, "Test.outer", 1);
        let op1 = operation(&mut b, "Test.inner", 1);
        let outer_clause = resume_clause(&mut b, "outer clause", 100, 0);
        let inner_clause = if in_clause {
            let p = b.proto("inner clause", 2, 4).unwrap();
            b.code(p)
                .unwrap()
                .op(Opcode::Perform, 2, op0.0.try_into().unwrap(), 0);
            b.code(p).unwrap().op(Opcode::Resume, 3, 1, 2);
            b.code(p).unwrap().ret(3);
            p
        } else {
            resume_clause(&mut b, "inner clause", 10, 0)
        };
        b.loadk_int(inner, 2, 1).unwrap();
        if !in_clause {
            b.code(inner)
                .unwrap()
                .op(Opcode::Perform, 0, op0.0.try_into().unwrap(), 2);
        }
        b.code(inner).unwrap().op(
            Opcode::Perform,
            1,
            (if in_clause { op0 } else { op1 }).0.try_into().unwrap(),
            2,
        );
        if !in_clause {
            b.code(inner).unwrap().op(Opcode::AddI, 1, 0, 1);
        }
        b.code(inner).unwrap().ret(1);
        let h = handler(&mut b, outer, &[(if in_clause { op0 } else { op1 }, true)]);
        closure(&mut b, outer, 0, inner);
        closure(&mut b, outer, 1, inner_clause);
        b.code(outer).unwrap().op(Opcode::Handle, 2, 0, h);
        b.code(outer).unwrap().ret(2);
        let h = handler(&mut b, main, &[(op0, true)]);
        closure(&mut b, main, 0, outer);
        closure(&mut b, main, 1, outer_clause);
        b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
        finish(&mut b, main, 2, Some("Integer.toString"));
        value(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            if in_clause { "101" } else { "112" },
        );
    }
}

#[test]
fn second_resume_stops_at_the_second_instruction() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 1).unwrap();
    let op = operation(&mut b, "Test.ask", 1);
    b.loadk_int(body, 0, 7).unwrap();
    b.code(body).unwrap().op(Opcode::Perform, 0, 0, 0);
    b.code(body).unwrap().ret(0);
    let clause = b.proto("twice", 2, 3).unwrap();
    b.code(clause).unwrap().op(Opcode::Resume, 2, 1, 0);
    b.code(clause).unwrap().op(Opcode::Resume, 2, 1, 0);
    b.code(clause).unwrap().ret(2);
    let h = handler(&mut b, main, &[(op, false)]);
    closure(&mut b, main, 0, body);
    closure(&mut b, main, 1, clause);
    b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
    finish(&mut b, main, 2, Some("Integer.toString"));
    let p = b.finish(main).unwrap();
    let mut vm = Vm::new(
        &p,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let info = error(run(&mut vm, &mut services(), ExecMode::Direct));
    assert_eq!(
        info.stop,
        Stop::Runtime(RuntimeError::ContinuationResumedTwice)
    );
    assert_eq!(
        info.at,
        Some(InstrRef {
            proto: clause,
            pc: 1
        })
    );
}

// 関門: HANDLE/PERFORM の上限検査を所有の移動より先に行う契約。
// 枠数・停止位置と後始末後の計数を、実行の結果から確かめる。
#[test]
fn stack_limits_preserve_the_performing_frame_and_clear_the_meter() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 1).unwrap();
    let op = operation(&mut b, "Test.ask", 1);
    b.loadk_int(body, 0, 1).unwrap();
    b.code(body).unwrap().op(Opcode::Perform, 0, 0, 0);
    b.code(body).unwrap().ret(0);
    let c = resume_clause(&mut b, "clause", 0, 0);
    let h = handler(&mut b, main, &[(op, true)]);
    closure(&mut b, main, 0, body);
    closure(&mut b, main, 1, c);
    b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
    finish(&mut b, main, 2, Some("Integer.toString"));
    let p = b.finish(main).unwrap();
    let limit = 3 * crate::vm::FRAME_COST + 17 * crate::vm::REG_COST;
    let mut vm = Vm::new(
        &p,
        VmConfig {
            max_call_stack_bytes: limit,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let info = error(run(&mut vm, &mut services(), ExecMode::Direct));
    assert_eq!(
        info.stop,
        Stop::Resource(ResourceError::CallStackTooDeep { frames: 3 })
    );
    assert_eq!(info.at, Some(InstrRef { proto: body, pc: 1 }));
    assert_eq!(info.frames.len(), 2);
    assert_eq!(vm.state.meter.bytes(), 0);
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("nested", 0, 3).unwrap();
    let h = handler(&mut b, body, &[]);
    closure(&mut b, body, 0, body);
    b.code(body).unwrap().op(Opcode::Handle, 1, 0, h);
    b.code(body).unwrap().ret(1);
    let h = handler(&mut b, main, &[]);
    closure(&mut b, main, 0, body);
    b.code(main).unwrap().op(Opcode::Handle, 1, 0, h);
    b.loadk(main, 2, ConstDesc::Unit).unwrap();
    b.code(main).unwrap().ret(2);
    let p = b.finish(main).unwrap();
    let mut vm = Vm::new(
        &p,
        VmConfig {
            max_call_stack_bytes: 4096,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let info = error(run(&mut vm, &mut services(), ExecMode::Direct));
    let Stop::Resource(ResourceError::CallStackTooDeep { frames }) = info.stop else {
        panic!("{info:?}")
    };
    assert_eq!(frames, 2 * info.frames.len() as u64 - 1);
    assert_eq!(vm.state.meter.bytes(), 0);
}

// 関門: 反復ごとに区画と包む枠を降ろす形は定数の空間で走り、
// 再開後の計算を積む形は上限に達する。深さの計数の別々の契約を同じ準備で確かめる。
#[test]
#[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
fn million_completed_handlers_use_constant_space_but_pending_resumes_grow() {
    for pending in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let iteration = b.proto("iteration", 1, 8).unwrap();
        let body = b.proto("body", 0, 1).unwrap();
        let op = operation(&mut b, "Test.ask", 1);
        let clause = resume_clause(&mut b, "clause", 0, if pending { 1 } else { 0 });
        b.loadk_int(body, 0, 1).unwrap();
        b.code(body).unwrap().op(Opcode::Perform, 0, 0, 0);
        b.code(body).unwrap().ret(0);
        let done = b.code(iteration).unwrap().label("done").unwrap();
        b.loadk_int(iteration, 2, 0).unwrap();
        b.code(iteration).unwrap().op(Opcode::LtI, 3, 2, 0);
        b.code(iteration).unwrap().jmpf(3, done);
        if pending {
            b.code(iteration).unwrap().op(Opcode::Perform, 3, 0, 0);
        } else {
            let h = handler(&mut b, iteration, &[(op, true)]);
            closure(&mut b, iteration, 4, body);
            closure(&mut b, iteration, 5, clause);
            b.code(iteration).unwrap().op(Opcode::Handle, 3, 4, h);
        }
        b.loadk_int(iteration, 2, 1).unwrap();
        b.code(iteration).unwrap().op(Opcode::SubI, 7, 0, 2);
        closure(&mut b, iteration, 6, iteration);
        b.code(iteration).unwrap().op(Opcode::TailCall, 0, 6, 1);
        b.code(iteration).unwrap().place(done).unwrap();
        b.code(iteration).unwrap().ret(0);
        let entry = if pending {
            let entry = b.proto("entry", 0, 3).unwrap();
            closure(&mut b, entry, 0, iteration);
            b.loadk_int(entry, 1, 100).unwrap();
            b.code(entry).unwrap().op(Opcode::Call, 2, 0, 1);
            b.code(entry).unwrap().ret(2);
            entry
        } else {
            iteration
        };
        if pending {
            let h = handler(&mut b, main, &[(op, false)]);
            closure(&mut b, main, 0, entry);
            closure(&mut b, main, 1, clause);
            b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
        } else {
            closure(&mut b, main, 0, entry);
            b.loadk_int(main, 1, if cfg!(miri) { 64 } else { 1_000_000 })
                .unwrap();
            b.code(main).unwrap().op(Opcode::Call, 2, 0, 1);
        }
        finish(&mut b, main, 2, Some("Integer.toString"));
        let p = b.finish(main).unwrap();
        value(
            &p,
            VmConfig {
                max_call_stack_bytes: 1024 * 1024,
                ..VmConfig::default()
            },
            if pending { "100" } else { "0" },
        );
        if pending {
            let mut vm = Vm::new(
                &p,
                VmConfig {
                    max_call_stack_bytes: 4096,
                    ..VmConfig::default()
                },
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let info = error(run(&mut vm, &mut services(), ExecMode::Direct));
            let Stop::Resource(ResourceError::CallStackTooDeep { frames }) = info.stop else {
                panic!("{info:?}")
            };
            assert_eq!(frames, 2 * info.frames.len() as u64 - 2);
            assert_eq!(info.at.unwrap().proto, iteration);
        }
    }
}

#[test]
fn call_results_survive_handle_and_resume_safepoints() {
    check_call_results_at_handle_and_resume();
}

fn check_call_results_at_handle_and_resume() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 2).unwrap();
    let clause = b.proto("clause", 2, 5).unwrap();
    let leaf = b.proto("leaf", 0, 1).unwrap();
    b.code(leaf).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
    b.code(leaf).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(leaf).unwrap().ret(0);
    let op = operation(&mut b, "Test.ask", 1);
    b.code(body).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
    b.code(body).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(body).unwrap().op(Opcode::Perform, 1, 0, 0);
    b.code(body).unwrap().op(Opcode::Concat, 1, 0, 1);
    b.code(body).unwrap().ret(1);
    closure(&mut b, clause, 3, leaf);
    b.code(clause).unwrap().op(Opcode::Call, 0, 3, 0);
    b.code(clause).unwrap().op(Opcode::Resume, 2, 1, 0);
    b.code(clause).unwrap().op(Opcode::Concat, 4, 0, 2);
    b.code(clause).unwrap().ret(4);
    b.loadk(main, 0, ConstDesc::Str("hello".into())).unwrap();
    b.loadk(main, 2, ConstDesc::Str("!".into())).unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 0, 0, 2);
    closure(&mut b, main, 1, leaf);
    b.code(main).unwrap().op(Opcode::Call, 0, 1, 0);
    closure(&mut b, main, 3, body);
    closure(&mut b, main, 4, clause);
    let h = handler(&mut b, main, &[(op, false)]);
    b.code(main).unwrap().op(Opcode::Handle, 2, 3, h);
    b.code(main).unwrap().op(Opcode::Concat, 2, 0, 2);
    finish(&mut b, main, 2, None);
    value(
        &b.finish(main).unwrap(),
        VmConfig::default(),
        "hello!hello!hello!hello!",
    );
}

/// 捕捉した窓の再開と破棄を短い二つの経路で通す（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
pub(crate) fn check_small_continuations() {
    check_call_results_at_handle_and_resume();
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("captured body", 0, 1).unwrap();
    let clause = b.proto("discard clause", 1, 3).unwrap();
    let checkpoint = b.proto("collect", 0, 1).unwrap();
    let op = operation(&mut b, "Test.drop", 0);
    b.code(body)
        .unwrap()
        .op(Opcode::Perform, 0, op.0.try_into().unwrap(), 0);
    b.code(body).unwrap().ret(0);
    b.loadk(checkpoint, 0, ConstDesc::Unit).unwrap();
    b.code(checkpoint).unwrap().ret(0);
    closure(&mut b, clause, 1, checkpoint);
    b.code(clause).unwrap().op(Opcode::Call, 2, 1, 0);
    b.loadk_int(clause, 1, 7).unwrap();
    b.code(clause).unwrap().ret(1);
    closure(&mut b, main, 0, body);
    closure(&mut b, main, 1, clause);
    let h = handler(&mut b, main, &[(op, false)]);
    b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
    finish(&mut b, main, 2, Some("Integer.toString"));
    value(&b.finish(main).unwrap(), VmConfig::default(), "7");
}

// 関門: 窓以外の根（record の節、func の捕捉、drop の継続、ReturnWork の値）を
// 回収から守り、降ろした枠だけに残る値を回収する。定数のキャッシュに残らない値を作る。
#[test]
fn frame_only_roots_survive_collection_and_are_released_after_return_or_stop() {
    for fail in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let body = b.proto("body", 0, 4).unwrap();
        let clause = b.proto("clause", 2, 6).unwrap();
        let leaf = b.proto("collect", 0, 1).unwrap();
        b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
        b.code(leaf).unwrap().ret(0);
        let op = operation(&mut b, "Test.ask", 1);
        b.code(body).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
        b.code(clause).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
        closure(&mut b, body, 2, leaf);
        b.code(body).unwrap().op(Opcode::Call, 3, 2, 0);
        b.code(body).unwrap().op(Opcode::GetCap, 0, 0, 0);
        // func の捕捉とは別の値を作り、捕捉された窓の r0 だけを根にする。
        b.loadk(body, 3, ConstDesc::Str(" saved".into())).unwrap();
        b.code(body).unwrap().op(Opcode::Concat, 0, 0, 3);
        b.loadk_int(body, 1, 7).unwrap();
        b.code(body).unwrap().op(Opcode::Perform, 1, 0, 1);
        b.code(body).unwrap().op(Opcode::Call, 3, 2, 0);
        b.code(body).unwrap().ret(0);
        closure(&mut b, clause, 4, leaf);
        b.code(clause).unwrap().op(Opcode::Call, 5, 4, 0);
        b.code(clause).unwrap().op(Opcode::GetCap, 2, 0, 0);
        if fail {
            b.loadk_int(clause, 3, 0).unwrap();
            b.code(clause).unwrap().op(Opcode::DivI, 3, 0, 3);
        } else {
            b.code(clause).unwrap().op(Opcode::Resume, 3, 1, 0);
            b.code(clause).unwrap().op(Opcode::Concat, 3, 2, 3);
            b.code(clause).unwrap().ret(3);
        }
        b.loadk(main, 0, ConstDesc::Str("frame".into())).unwrap();
        b.loadk(main, 1, ConstDesc::Str(" only".into())).unwrap();
        b.code(main).unwrap().op(Opcode::Concat, 0, 0, 1);
        closure(&mut b, main, 1, body);
        // body が持つ値とも区別し、最初の CALL の回収では record の節だけに残す。
        b.loadk(main, 3, ConstDesc::Str(" clause".into())).unwrap();
        b.code(main).unwrap().op(Opcode::Concat, 0, 0, 3);
        closure(&mut b, main, 2, clause);
        b.loadk(main, 0, ConstDesc::Unit).unwrap();
        let h = handler(&mut b, main, &[(op, false)]);
        b.code(main).unwrap().op(Opcode::Handle, 3, 1, h);
        finish(&mut b, main, 3, None);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let step = run(&mut vm, &mut services(), ExecMode::Direct);
        if fail {
            assert_eq!(
                error(step).stop,
                Stop::Runtime(RuntimeError::DivisionByZero)
            );
        } else {
            assert_eq!(
                step,
                VmStep::Finished(MainOutcome::Error(
                    "frame only clauseframe only saved".into()
                ))
            );
        }
        vm.heap.collect(&vm.state);
        assert!(vm.heap.take_fault().is_none());
        // LOADK が作った四つの文字列だけが定数の表に残る。枠のクロージャと捕捉は残らない。
        assert_eq!(vm.heap.object_ids().len(), 4);
    }
}

#[test]
fn returning_value_is_rooted_after_the_body_and_handle_are_popped() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 2).unwrap();
    b.loadk(body, 0, ConstDesc::Str("return".into())).unwrap();
    b.loadk(body, 1, ConstDesc::Str(" work".into())).unwrap();
    b.code(body).unwrap().op(Opcode::Concat, 0, 0, 1);
    b.code(body).unwrap().ret(0);
    let h = handler(&mut b, main, &[]);
    closure(&mut b, main, 0, body);
    b.code(main).unwrap().op(Opcode::Handle, 1, 0, h);
    finish(&mut b, main, 1, None);
    let p = b.finish(main).unwrap();
    let mut vm = Vm::new(
        &p,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut io = services();
    // run_epoch は VM の区間の境目。実際に RETURN を処理し、途中の根だけを残したところで回収する。
    let mut saw_return = false;
    loop {
        let exit = vm.heap.epoch(|ctx| {
            super::super::run_epoch(
                &p,
                vm.config,
                &mut vm.state,
                ctx,
                io.runtime(ExecMode::Direct),
            )
        });
        if let Some(work) = &vm.state.returning {
            saw_return = true;
            assert_eq!(vm.state.stack.segments.len(), 1);
            assert_eq!(work.stage, ReturnStage::Wrapping);
            assert_eq!(vm.state.meter.frames(), 1);
        }
        if exit == LoopExit::Return {
            break;
        }
        vm.heap.collect(&vm.state);
        if vm.state.precall_done.is_some() {
            crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                .unwrap();
        }
    }
    assert!(saw_return);
    assert_eq!(
        vm.state.step,
        Some(VmStep::Finished(MainOutcome::Error("return work".into())))
    );
    assert!(vm.heap.take_fault().is_none());
}

#[test]
fn inherited_clause_search_skips_the_callers_inner_handlers() {
    for tail in [true, false] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let body = b.proto("body", 0, 1).unwrap();
        let op0 = operation(&mut b, "Test.outer", 1);
        let op1 = operation(&mut b, "Test.inherited", 1);
        let local = resume_clause(&mut b, "local", 1000, 0);
        let outer = resume_clause(&mut b, "inherited outer", 200, 0);
        let inner = b.proto("inherited inner", 2, 4).unwrap();
        b.code(inner).unwrap().op(Opcode::Perform, 2, 0, 0);
        b.code(inner).unwrap().op(Opcode::Resume, 3, 1, 2);
        b.code(inner).unwrap().ret(3);
        b.loadk_int(body, 0, 1).unwrap();
        b.code(body).unwrap().op(Opcode::Perform, 0, 1, 0);
        b.code(body).unwrap().ret(0);
        let h = handler(&mut b, main, &[(op0, true)]);
        closure(&mut b, main, 0, body);
        closure(&mut b, main, 1, local);
        b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
        finish(&mut b, main, 2, Some("Integer.toString"));
        let _ = handler(&mut b, main, &[(op1, tail)]);
        let _ = handler(&mut b, main, &[(op0, true)]);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        vm.heap.epoch(|ctx| {
            for (proto, desc) in [(inner, HandlerIdx(1)), (outer, HandlerIdx(2))] {
                let f = ctx.alloc_fields(FieldsKind::Func, proto.0, &[]).unwrap();
                let h = ctx.alloc_host(HandlerRecord {
                    clauses: vec![ctx.new_slot(f)],
                    desc,
                    evaluated_by: crate::vm::TaskId {
                        index: 1,
                        generation: 0,
                    },
                    members: vec![],
                    body_finished: false,
                });
                vm.state.inherited.push(ctx.new_slot(h));
            }
        });
        let step = run(&mut vm, &mut services(), ExecMode::Direct);
        if tail {
            assert_eq!(step, VmStep::Finished(MainOutcome::Error("201".into())));
        } else {
            assert_eq!(
                error(step).stop,
                Stop::Runtime(RuntimeError::InheritedHandlerClause {
                    operation: "Test.inherited".into()
                })
            );
        }
    }
}

#[test]
fn perform_pre_call_collection_keeps_arguments_and_counts_the_call_once() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 2).unwrap();
    let clause = b.proto("clause", 2, 4).unwrap();
    let op = operation(&mut b, "Test.write", 1);
    let output = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    b.loadk(body, 0, ConstDesc::Str("one".into())).unwrap();
    b.loadk(body, 1, ConstDesc::Str(" call".into())).unwrap();
    b.code(body).unwrap().op(Opcode::Concat, 0, 0, 1);
    b.code(body).unwrap().op(Opcode::Perform, 1, 0, 0);
    b.code(body).unwrap().ret(1);
    b.code(clause)
        .unwrap()
        .op(Opcode::Io, 2, output.0.try_into().unwrap(), 0);
    b.code(clause).unwrap().op(Opcode::Resume, 3, 1, 2);
    b.code(clause).unwrap().ret(3);
    let h = handler(&mut b, main, &[(op, true)]);
    closure(&mut b, main, 0, body);
    closure(&mut b, main, 1, clause);
    b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
    b.code(main).unwrap().ret(2);
    let p = b.finish(main).unwrap();
    let config = VmConfig {
        call_budget: 100,
        ..VmConfig::default()
    };
    let mut vm = Vm::new(
        &p,
        config,
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut io = services();
    // 関門: 引数を作った後、PERFORM の前で回収する出口そのものを観測する。
    // HANDLE 前の回収だけでも通ってしまう、全体の回収回数の下限では代用しない（R20）。
    let perform_at = InstrRef { proto: body, pc: 3 };
    loop {
        let exit = vm.heap.epoch(|ctx| {
            super::super::run_epoch(
                &p,
                config,
                &mut vm.state,
                ctx,
                io.runtime(ExecMode::Request),
            )
        });
        assert_eq!(exit, LoopExit::Collect);
        let before_perform = vm.state.precall_done == Some(perform_at);
        if before_perform {
            assert_eq!(vm.state.stack.segments.len(), 2);
            assert_eq!(vm.state.frame().unwrap().proto, body);
            assert_eq!(vm.state.frame().unwrap().pc, perform_at.pc);
        }
        vm.heap.collect(&vm.state);
        assert!(vm.heap.take_fault().is_none());
        if vm.state.precall_done.is_some() {
            crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, config.call_budget).unwrap();
        }
        if before_perform {
            break;
        }
    }
    let VmStep::Requests(ids) = vm.run(io.runtime(ExecMode::Request)) else {
        panic!("expected clause output request")
    };
    assert_eq!(ids.len(), 1);
    let mut expected = crate::vm::budget::Budget::new(98);
    expected.interrupt();
    assert_eq!(vm.state.budget, expected);
    assert!(vm.state.precall_done.is_none());
    vm.serve_request(&mut io.rt, ids[0]);
    assert_eq!(
        run(&mut vm, &mut io, ExecMode::Request),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(
        io.take_output(),
        vec![(crate::runtime::Stream::Stdout, b"one call\n".to_vec())]
    );
}

// 関門: 継承したハンドラのない IO の探索を省略しても、深い通常呼び出しの
// 底で操作を処理系へ渡す契約を保つ。既存の IO のテストには op と深い枠の併存がない。
#[test]
fn unhandled_io_with_operation_keeps_results_in_deep_calls() {
    for depth in [0, 512] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 3).unwrap();
        let recurse = b.proto("recurse", 1, 5).unwrap();
        let op = operation(&mut b, "Console.writeLine", 1);
        let output = b
            .named_builtin(
                "Benitoite.IO.Console.writeLine",
                1,
                Capability::Io,
                Some(op),
            )
            .unwrap();
        let deeper = b.code(recurse).unwrap().label("deeper").unwrap();
        b.loadk_int(recurse, 1, 0).unwrap();
        b.code(recurse).unwrap().op(Opcode::EqI, 1, 0, 1);
        b.code(recurse).unwrap().jmpf(1, deeper);
        b.loadk(recurse, 0, ConstDesc::Str("outside".into()))
            .unwrap();
        b.code(recurse)
            .unwrap()
            .op(Opcode::Io, 2, output.0.try_into().unwrap(), 0);
        b.code(recurse).unwrap().ret(2);
        b.code(recurse).unwrap().place(deeper).unwrap();
        b.loadk(recurse, 2, ConstDesc::Func(recurse)).unwrap();
        b.loadk_int(recurse, 3, 1).unwrap();
        b.code(recurse).unwrap().op(Opcode::SubI, 3, 0, 3);
        b.code(recurse).unwrap().op(Opcode::Call, 4, 2, 1);
        b.code(recurse).unwrap().ret(4);
        b.loadk(main, 0, ConstDesc::Func(recurse)).unwrap();
        b.loadk_int(main, 1, depth).unwrap();
        b.code(main).unwrap().op(Opcode::Call, 2, 0, 1);
        b.code(main).unwrap().ret(2);
        let p = b.finish(main).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut vm = Vm::new(&p, VmConfig::default(), HeapConfig::default());
            vm.start_main().unwrap();
            let mut io = services();
            assert_eq!(
                run(&mut vm, &mut io, mode),
                VmStep::Finished(MainOutcome::Ok)
            );
            assert_eq!(
                io.take_output(),
                vec![(crate::runtime::Stream::Stdout, b"outside\n".to_vec())]
            );
        }
    }
}

#[test]
fn io_operations_use_the_handler_before_invoking_external_services() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 2).unwrap();
    let clause = b.proto("clause", 2, 3).unwrap();
    let op = operation(&mut b, "Console.writeLine", 1);
    let output = b
        .named_builtin(
            "Benitoite.IO.Console.writeLine",
            1,
            Capability::Io,
            Some(op),
        )
        .unwrap();
    b.loadk(body, 0, ConstDesc::Str("must be handled".into()))
        .unwrap();
    b.code(body)
        .unwrap()
        .op(Opcode::Io, 1, output.0.try_into().unwrap(), 0);
    b.code(body).unwrap().ret(1);
    b.loadk(clause, 0, ConstDesc::Unit).unwrap();
    b.code(clause).unwrap().op(Opcode::Resume, 2, 1, 0);
    b.code(clause).unwrap().ret(2);
    let h = handler(&mut b, main, &[(op, true)]);
    closure(&mut b, main, 0, body);
    closure(&mut b, main, 1, clause);
    b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
    b.code(main).unwrap().ret(2);
    let p = b.finish(main).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut io = services();
        assert_eq!(
            run(&mut vm, &mut io, mode),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert!(io.take_output().is_empty());
    }
}

// 関門: 継続を再開しない節と ESCAPE は R20 では未実装だった。
// 入れ子の drop を含め、VM の入口の結果・停止位置・計数を一つの表で確かめる（R21）。
#[test]
fn discarded_nested_continuations_escape_and_stop() {
    for nested in [false, true] {
        for action in [
            "drop",
            "escape body",
            "escape clause",
            "stop body",
            "stop clause",
        ] {
            let mut b = ProgramBuilder::new();
            let main = b.proto("main", 0, 16).unwrap();
            let owner = b.proto("owner", 0, 5).unwrap();
            let body = b.proto("outer body", 0, 4).unwrap();
            let clause = b.proto("outer clause", 1, 3).unwrap();
            let inner_body = b.proto("inner body", 0, 2).unwrap();
            let inner_clause = b.proto("inner clause", 1, 2).unwrap();
            for p in [body, clause, inner_body, inner_clause] {
                b.code(p).unwrap().proto.boundary = false;
            }
            let outer = operation(&mut b, "Outer.ask", 0);
            let inner = operation(&mut b, "Inner.ask", 0);
            let h = handler(&mut b, owner, &[(outer, false)]);
            closure(&mut b, owner, 0, body);
            closure(&mut b, owner, 1, clause);
            b.code(owner).unwrap().op(Opcode::Handle, 2, 0, h);
            b.loadk_int(owner, 3, 1).unwrap();
            b.code(owner).unwrap().op(Opcode::AddI, 2, 2, 3);
            b.code(owner).unwrap().ret(2);
            let stop_at;
            if action == "escape body" || action == "stop body" {
                b.loadk_int(body, 0, 42).unwrap();
                b.loadk_int(body, 1, 0).unwrap();
                stop_at = InstrRef { proto: body, pc: 2 };
                if action == "escape body" {
                    b.code(body).unwrap().op(Opcode::Escape, 0, 0, 0);
                } else {
                    b.code(body).unwrap().op(Opcode::DivI, 0, 0, 1);
                }
                b.code(body).unwrap().ret(0);
            } else {
                stop_at = InstrRef {
                    proto: clause,
                    pc: 2,
                };
                if nested {
                    let ih = handler(&mut b, body, &[(inner, false)]);
                    closure(&mut b, body, 0, inner_body);
                    closure(&mut b, body, 1, inner_clause);
                    b.code(body).unwrap().op(Opcode::Handle, 2, 0, ih);
                    b.code(body).unwrap().ret(2);
                } else {
                    b.code(body)
                        .unwrap()
                        .op(Opcode::Perform, 0, outer.0.try_into().unwrap(), 0);
                    b.loadk_int(body, 1, 0).unwrap();
                    b.code(body).unwrap().op(Opcode::DivI, 0, 0, 1);
                    b.code(body).unwrap().ret(0);
                }
            }
            b.code(inner_body)
                .unwrap()
                .op(Opcode::Perform, 0, inner.0.try_into().unwrap(), 0);
            b.code(inner_body).unwrap().ret(0);
            b.code(inner_clause)
                .unwrap()
                .op(Opcode::Perform, 1, outer.0.try_into().unwrap(), 0);
            b.code(inner_clause).unwrap().ret(1);
            b.loadk_int(clause, 1, 42).unwrap();
            b.loadk_int(clause, 2, 0).unwrap();
            match action {
                "stop clause" => {
                    b.code(clause).unwrap().op(Opcode::DivI, 1, 1, 2);
                }
                "escape clause" => {
                    b.code(clause).unwrap().op(Opcode::Escape, 1, 0, 0);
                }
                _ => {}
            }
            b.code(clause).unwrap().ret(1);
            closure(&mut b, main, 0, owner);
            b.code(main).unwrap().op(Opcode::Call, 1, 0, 0);
            finish(&mut b, main, 1, Some("Integer.toString"));
            let p = b.finish(main).unwrap();
            if action.starts_with("stop") {
                for mode in [ExecMode::Direct, ExecMode::Request] {
                    let mut vm = Vm::new(
                        &p,
                        VmConfig::default(),
                        HeapConfig {
                            stress: true,
                            ..HeapConfig::default()
                        },
                    );
                    vm.start_main().unwrap();
                    let info = error(run(&mut vm, &mut services(), mode));
                    assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
                    assert_eq!(info.at, Some(stop_at));
                    assert_eq!(
                        info.frames.iter().map(|f| f.proto).collect::<Vec<_>>(),
                        vec![stop_at.proto, owner, main]
                    );
                    assert!(info.frames.iter().take(2).all(|f| f.call_site.is_some()));
                    assert!(vm.state.stack.segments.is_empty());
                    assert!(vm.state.returning.is_none());
                    assert!(vm.state.unwinding.is_none());
                    assert_eq!(vm.state.meter.bytes(), 0);
                }
            } else {
                value(
                    &p,
                    VmConfig::default(),
                    if action == "drop" { "43" } else { "42" },
                );
            }
        }
    }
}

// 関門: 捨てた継続が計数に残ると小さい上限で反復が止まる。通常の末尾再帰では検出できない（R21）。
#[test]
#[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
fn dropping_one_hundred_thousand_continuations_does_not_accumulate_stack() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let owner = b.proto("iterate", 1, 7).unwrap();
    let body = b.proto("body", 0, 1).unwrap();
    let clause = b.proto("clause", 1, 2).unwrap();
    b.code(body).unwrap().proto.boundary = false;
    b.code(clause).unwrap().proto.boundary = false;
    let op = operation(&mut b, "Test.ask", 0);
    b.code(body)
        .unwrap()
        .op(Opcode::Perform, 0, op.0.try_into().unwrap(), 0);
    b.code(body).unwrap().ret(0);
    b.loadk_int(clause, 1, 1).unwrap();
    b.code(clause).unwrap().ret(1);
    let more = b.code(owner).unwrap().label("more").unwrap();
    b.loadk_int(owner, 1, 0).unwrap();
    b.code(owner).unwrap().op(Opcode::EqI, 1, 0, 1);
    b.code(owner).unwrap().jmpf(1, more);
    b.code(owner).unwrap().ret(0);
    b.code(owner).unwrap().place(more).unwrap();
    closure(&mut b, owner, 2, body);
    closure(&mut b, owner, 3, clause);
    let h = handler(&mut b, owner, &[(op, false)]);
    b.code(owner).unwrap().op(Opcode::Handle, 4, 2, h);
    b.loadk(owner, 5, ConstDesc::Func(owner)).unwrap();
    b.code(owner).unwrap().op(Opcode::SubI, 6, 0, 4);
    b.code(owner).unwrap().op(Opcode::TailCall, 0, 5, 1);
    closure(&mut b, main, 0, owner);
    b.loadk_int(main, 1, 100_000).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 2, 0, 1);
    finish(&mut b, main, 2, Some("Integer.toString"));
    value(
        &b.finish(main).unwrap(),
        VmConfig {
            max_call_stack_bytes: 4096,
            ..VmConfig::default()
        },
        "0",
    );
}

// 関門: 長い継続を捨てる途中の各回収で、節の戻り値が ReturnWork だけに残る。
// 通常の RETURN のテストは UnwindWork の辿りを挟まない（R21、R03 の根の引き渡し）。
#[test]
fn long_dropped_continuation_roots_clause_result_between_steps() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 3).unwrap();
    let recurse = b.proto("recurse", 1, 5).unwrap();
    let clause = b.proto("clause", 1, 3).unwrap();
    let op = operation(&mut b, "Test.ask", 0);
    b.code(body).unwrap().proto.boundary = false;
    b.code(clause).unwrap().proto.boundary = false;
    let more = b.code(recurse).unwrap().label("more").unwrap();
    b.loadk_int(recurse, 1, 0).unwrap();
    b.code(recurse).unwrap().op(Opcode::EqI, 1, 0, 1);
    b.code(recurse).unwrap().jmpf(1, more);
    b.code(recurse)
        .unwrap()
        .op(Opcode::Perform, 0, op.0.try_into().unwrap(), 0);
    b.code(recurse).unwrap().ret(0);
    b.code(recurse).unwrap().place(more).unwrap();
    b.loadk(recurse, 2, ConstDesc::Func(recurse)).unwrap();
    b.loadk_int(recurse, 3, 1).unwrap();
    b.code(recurse).unwrap().op(Opcode::SubI, 3, 0, 3);
    b.code(recurse).unwrap().op(Opcode::Call, 4, 2, 1);
    b.code(recurse).unwrap().ret(4);
    b.loadk(body, 0, ConstDesc::Func(recurse)).unwrap();
    b.loadk_int(body, 1, 256).unwrap();
    b.code(body).unwrap().op(Opcode::Call, 2, 0, 1);
    b.code(body).unwrap().ret(2);
    b.loadk(clause, 1, ConstDesc::Str("clause".into())).unwrap();
    b.loadk(clause, 2, ConstDesc::Str(" result".into()))
        .unwrap();
    b.code(clause).unwrap().op(Opcode::Concat, 1, 1, 2);
    b.code(clause).unwrap().ret(1);
    let h = handler(&mut b, main, &[(op, false)]);
    closure(&mut b, main, 0, body);
    closure(&mut b, main, 1, clause);
    b.code(main).unwrap().op(Opcode::Handle, 2, 0, h);
    finish(&mut b, main, 2, None);
    let p = b.finish(main).unwrap();
    let mut vm = Vm::new(
        &p,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut io = services();
    let mut during_traversal = 0;
    loop {
        let exit = vm.heap.epoch(|ctx| {
            super::super::run_epoch(
                &p,
                vm.config,
                &mut vm.state,
                ctx,
                io.runtime(ExecMode::Direct),
            )
        });
        if exit == LoopExit::Return {
            break;
        }
        let traversing = vm.state.unwinding.is_some();
        vm.heap.collect(&vm.state);
        assert!(vm.heap.take_fault().is_none());
        if traversing {
            during_traversal += 1;
            vm.heap.epoch(|ctx| {
                assert_eq!(
                    ctx.str(ctx.load(&vm.state.returning.as_ref().unwrap().value)),
                    Some("clause result")
                );
            });
        }
        if vm.state.precall_done.is_some() {
            crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                .unwrap();
        }
    }
    assert!(during_traversal >= 256);
    assert_eq!(
        vm.state.step,
        Some(VmStep::Finished(MainOutcome::Error("clause result".into())))
    );
    assert_eq!(vm.state.meter.bytes(), 0);
}

// 関門: CallFrame::func だけが持つクロージャと捕捉値を、破棄・ESCAPE・停止で根から外す。
// R20 の通常の戻りのテストを、この三つの経路へ広げる（R21）。
#[test]
fn frame_only_closure_and_capture_are_collected_after_drop_escape_and_stop() {
    for action in ["drop", "escape", "stop"] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 4).unwrap();
        let body = b.proto("body", 0, 3).unwrap();
        let leaf = b.proto("leaf", 0, 1).unwrap();
        b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
        b.code(leaf).unwrap().ret(0);
        let clause = b.proto("clause", 1, 2).unwrap();
        b.code(body).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
        b.code(body).unwrap().proto.boundary = false;
        b.code(clause).unwrap().proto.boundary = false;
        let op = operation(&mut b, "Test.ask", 0);
        b.loadk(main, 0, ConstDesc::Str("frame".into())).unwrap();
        b.loadk(main, 1, ConstDesc::Str(" capture".into())).unwrap();
        b.code(main).unwrap().op(Opcode::Concat, 0, 0, 1);
        closure(&mut b, main, 1, body);
        closure(&mut b, main, 2, clause);
        b.loadk(main, 0, ConstDesc::Unit).unwrap();
        let h = handler(&mut b, main, &[(op, false)]);
        b.code(main).unwrap().op(Opcode::Handle, 3, 1, h);
        b.code(main).unwrap().ret(3);
        closure(&mut b, body, 1, leaf);
        b.code(body).unwrap().op(Opcode::Call, 2, 1, 0);
        b.loadk(body, 0, ConstDesc::Unit).unwrap();
        match action {
            "drop" => {
                b.code(body)
                    .unwrap()
                    .op(Opcode::Perform, 0, op.0.try_into().unwrap(), 0);
            }
            "escape" => {
                b.code(body).unwrap().op(Opcode::Escape, 0, 0, 0);
            }
            "stop" => {
                b.loadk_int(body, 0, 1).unwrap();
                b.loadk_int(body, 1, 0).unwrap();
                b.code(body).unwrap().op(Opcode::DivI, 0, 0, 1);
            }
            _ => unreachable!(),
        }
        b.code(body).unwrap().ret(0);
        b.loadk(clause, 1, ConstDesc::Unit).unwrap();
        b.code(clause).unwrap().ret(1);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut io = services();
        // HANDLE の後で回収し、本体のクロージャは func だけが保持する状態を作る。
        loop {
            let exit = vm.heap.epoch(|ctx| {
                super::super::run_epoch(
                    &p,
                    vm.config,
                    &mut vm.state,
                    ctx,
                    io.runtime(ExecMode::Direct),
                )
            });
            assert_eq!(exit, LoopExit::Collect);
            let in_body = vm.state.frame().unwrap().proto == body;
            vm.heap.collect(&vm.state);
            if vm.state.precall_done.is_some() {
                crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                    .unwrap();
            }
            if in_body {
                break;
            }
        }
        let ids = vm.heap.epoch(|ctx| {
            let f = ctx.load(&vm.state.frame().unwrap().func);
            let capture = ctx.field(f, 0).unwrap();
            assert_eq!(ctx.str(capture), Some("frame capture"));
            vec![ctx.object_id(f).unwrap(), ctx.object_id(capture).unwrap()]
        });
        let step = run(&mut vm, &mut io, ExecMode::Direct);
        if action == "stop" {
            assert_eq!(
                error(step).stop,
                Stop::Runtime(RuntimeError::DivisionByZero)
            );
        } else {
            assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
        }
        vm.heap.collect(&vm.state);
        assert!(ids.iter().all(|id| !vm.heap.object_ids().contains(id)));
        assert_eq!(vm.state.meter.bytes(), 0);
        assert!(vm.heap.take_fault().is_none());
    }
}

// 関門: 包む枠から Reg へ戻った後の回収要求を、次の命令より前に処理する。
// return_plain の経路のテストでは finish_return の要求の見落としを捕まえない（R21 の補足）。
#[test]
fn wrapped_return_checks_collection_before_executing_the_caller() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let body = b.proto("body", 0, 1).unwrap();
    b.loadk(body, 0, ConstDesc::Str("returned".into())).unwrap();
    b.code(body).unwrap().ret(0);
    let h = handler(&mut b, main, &[]);
    closure(&mut b, main, 0, body);
    b.code(main).unwrap().op(Opcode::Handle, 1, 0, h);
    finish(&mut b, main, 1, None);
    let p = b.finish(main).unwrap();
    let mut vm = Vm::new(
        &p,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut io = services();
    loop {
        let exit = vm.heap.epoch(|ctx| {
            super::super::run_epoch(
                &p,
                vm.config,
                &mut vm.state,
                ctx,
                io.runtime(ExecMode::Direct),
            )
        });
        assert_eq!(exit, LoopExit::Collect);
        vm.heap.collect(&vm.state);
        if vm.state.precall_done.is_some() {
            crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                .unwrap();
        }
        if vm.state.returning.is_some() && vm.state.stack.segments.len() == 1 {
            break;
        }
    }
    let exit = vm.heap.epoch(|ctx| {
        super::super::run_epoch(
            &p,
            vm.config,
            &mut vm.state,
            ctx,
            io.runtime(ExecMode::Direct),
        )
    });
    assert_eq!(exit, LoopExit::Collect);
    assert!(vm.state.returning.is_none());
    assert!(vm.state.step.is_none());
    assert_eq!(vm.state.frame().unwrap().pc, 2);
    vm.heap.collect(&vm.state);
    assert_eq!(
        run(&mut vm, &mut io, ExecMode::Direct),
        VmStep::Finished(MainOutcome::Error("returned".into()))
    );
}

// 関門: 戻りの途中でヒープの不具合が届くと、実行の入口は残った枠の命令を渡す。
// 命令の処理自体が失敗する場合と違い、fail_instruction の位置の補正を通らない（R21）。
#[test]
fn heap_fault_during_return_records_origin_and_only_remaining_calls() {
    for opcode in [Opcode::Return, Opcode::Escape] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        let body = b.proto("body", 0, 1).unwrap();
        b.code(body).unwrap().proto.boundary = false;
        b.loadk(body, 0, ConstDesc::Unit).unwrap();
        b.code(body).unwrap().op(opcode, 0, 0, 0);
        let h = handler(&mut b, main, &[]);
        closure(&mut b, main, 0, body);
        b.code(main).unwrap().op(Opcode::Handle, 1, 0, h);
        b.code(main).unwrap().ret(1);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut io = services();
        loop {
            let exit = vm.heap.epoch(|ctx| {
                super::super::run_epoch(
                    &p,
                    vm.config,
                    &mut vm.state,
                    ctx,
                    io.runtime(ExecMode::Direct),
                )
            });
            assert_eq!(exit, LoopExit::Collect);
            vm.heap.collect(&vm.state);
            if vm.state.precall_done.is_some() {
                crate::vm::dispatch::tasks::slow_path_end(&mut vm.state, vm.config.call_budget)
                    .unwrap();
            }
            if vm.state.returning.is_some()
                && vm
                    .state
                    .stack
                    .segments
                    .iter()
                    .all(|segment| segment.calls.iter().all(|call| call.proto != body))
            {
                break;
            }
        }
        let mut foreign = crate::runtime::heap::Heap::new(HeapConfig::default());
        let slot = foreign.epoch(|ctx| ctx.new_slot(ctx.alloc_str("foreign", "test").unwrap()));
        vm.heap.epoch(|ctx| {
            let _ = ctx.load(&slot);
        });
        let info = error(run(&mut vm, &mut io, ExecMode::Direct));
        assert!(matches!(info.stop, Stop::Internal(_)));
        assert_eq!(info.at, Some(InstrRef { proto: body, pc: 1 }));
        assert_eq!(
            info.frames.iter().map(|f| f.proto).collect::<Vec<_>>(),
            vec![main]
        );
        assert_eq!(vm.state.meter.bytes(), 0);
        foreign.epoch(|ctx| ctx.discard(slot));
    }
}
