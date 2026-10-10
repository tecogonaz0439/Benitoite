//! 型クラスの命令の契約を、組み立てたバイトコードから VM の実行結果まで確かめる（実装プラン R34）。
// 準備の表とテストの失敗には、添字・算術と panic を使う（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use crate::builtins::iface::Capability;
use crate::builtins::table::tags;
use crate::bytecode::asm::ProgramBuilder;
use crate::bytecode::instr::{Instr, Opcode};
use crate::bytecode::program::{
    CompiledProgram, ConstDesc, DictRecipe, ImplIdx, ImplInfo, MainKind, MethodInfo, ProtoIdx,
    TraitIdx, TraitInfo,
};
use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::RunInput;
use crate::runtime::{ResourceError, Stop};
use crate::vm::dispatch::test_support::TestIo;
use crate::vm::{
    ExecMode, FRAME_COST, InstrRef, MainOutcome, REG_COST, StopEnd, StopInfo, StopReason, Vm,
    VmConfig, VmStep,
};

fn io() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}

fn trait_info(b: &mut ProgramBuilder, name: &str, arity: u16, supers: Vec<TraitIdx>) -> TraitIdx {
    let idx = TraitIdx(u32::try_from(b.program.traits.len()).unwrap());
    b.program.traits.push(TraitInfo {
        name: name.into(),
        methods: vec![MethodInfo {
            name: "call".into(),
            arity,
        }],
        supers,
    });
    idx
}

fn implementation(
    b: &mut ProgramBuilder,
    name: &str,
    trait_: TraitIdx,
    dict_arity: u16,
    method: ProtoIdx,
    supers: Vec<DictRecipe>,
) -> ImplIdx {
    let idx = ImplIdx(u32::try_from(b.program.impls.len()).unwrap());
    b.program.impls.push(ImplInfo {
        name: name.into(),
        trait_,
        dict_arity,
        methods: vec![method],
        supers,
    });
    idx
}

fn method(b: &mut ProgramBuilder, p: ProtoIdx, tail: bool, trait_: TraitIdx, a: u16, r: u16) {
    b.code(p)
        .unwrap()
        .method(
            if tail {
                Opcode::TailMethod
            } else {
                Opcode::Method
            },
            trait_,
            a,
            r,
            0,
        )
        .unwrap();
}

fn result(b: &mut ProgramBuilder, p: ProtoIdx, reg: u16) {
    b.program.main_kind = MainKind::Result;
    let ctor = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
    b.code(p)
        .unwrap()
        .op(Opcode::Con, reg, u16::try_from(ctor.0).unwrap(), reg);
    b.code(p).unwrap().ret(reg);
}

fn run(program: &CompiledProgram, config: VmConfig, stress: bool) -> VmStep {
    let mut vm = Vm::new(
        program,
        config,
        HeapConfig {
            stress,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let step = vm.run(io().runtime(ExecMode::Direct));
    assert!(vm.heap.take_fault().is_none());
    step
}

fn error(step: VmStep) -> StopInfo {
    let VmStep::Stopped(StopEnd {
        reason: StopReason::Error(info),
        release_failures,
    }) = step
    else {
        panic!("expected error: {step:?}");
    };
    assert!(release_failures.is_empty());
    info
}

// 関門: LOADK の辞書の共有と METHOD の引数（メソッド自身の辞書を含む）の契約。
// 関数の呼び出しのテストは辞書の実装の表・method_traits を通らない。公開 API は広げない。
#[test]
fn constant_dictionary_is_shared_and_method_constraints_are_arguments() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 8).unwrap();
    let show = b.proto("showInteger", 1, 1).unwrap();
    let generic = b.proto("showGeneric", 2, 4).unwrap();
    let scalar_trait = trait_info(&mut b, "Show", 1, vec![]);
    let generic_trait = trait_info(&mut b, "GenericShow", 2, vec![]);
    let scalar = implementation(&mut b, "Show[Integer]", scalar_trait, 0, show, vec![]);
    let generic_imp = implementation(
        &mut b,
        "GenericShow[Unit]",
        generic_trait,
        0,
        generic,
        vec![],
    );
    let cached = b.constant(ConstDesc::Dict(generic_imp)).unwrap();
    let scalar_k = b.constant(ConstDesc::Dict(scalar)).unwrap();
    let conversion = b
        .named_builtin("Integer.toString", 1, Capability::Pure, None)
        .unwrap();
    b.code(show)
        .unwrap()
        .op(Opcode::Prim, 0, u16::try_from(conversion.0).unwrap(), 0);
    b.code(show).unwrap().ret(0);
    method(&mut b, generic, false, scalar_trait, 2, 0);
    b.code(generic).unwrap().ret(2);
    b.loadk_ref(main, 0, cached).unwrap();
    b.loadk_ref(main, 1, cached).unwrap();
    b.loadk_ref(main, 2, scalar_k).unwrap();
    b.loadk_int(main, 3, 42).unwrap();
    method(&mut b, main, false, generic_trait, 4, 1);
    let output = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    b.code(main)
        .unwrap()
        .op(Opcode::Io, 5, u16::try_from(output.0).unwrap(), 4);
    // 待つ間も二つの LOADK の値を使い続けるので、生存解析に根として残る。
    b.loadk_ref(main, 2, scalar_k).unwrap();
    b.loadk_int(main, 3, 43).unwrap();
    method(&mut b, main, false, generic_trait, 4, 1);
    b.code(main).unwrap().op(Opcode::Move, 1, 0, 0);
    b.loadk_ref(main, 2, scalar_k).unwrap();
    b.loadk_int(main, 3, 44).unwrap();
    method(&mut b, main, false, generic_trait, 4, 1);
    result(&mut b, main, 4);
    let program = b.finish(main).unwrap();
    let mut vm = Vm::new(
        &program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut services = io();
    let VmStep::Requests(ids) = vm.run(services.runtime(ExecMode::Request)) else {
        panic!("expected IO request");
    };
    assert_eq!(ids.len(), 1);
    vm.heap.epoch(|ctx| {
        let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
        assert!(ctx.same_object(ctx.load(&regs[0]), ctx.load(&regs[1])));
        assert!(
            ctx.same_object(
                ctx.load(&regs[0]),
                ctx.load(
                    vm.state.constants[usize::try_from(cached.0).unwrap()]
                        .as_ref()
                        .unwrap()
                )
            )
        );
    });
    vm.serve_request(&mut services.rt, ids[0]);
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Error("44".into()))
    );
    assert!(vm.heap.take_fault().is_none());
    assert_eq!(
        services.take_output(),
        vec![(crate::runtime::Stream::Stdout, b"42\n".to_vec())]
    );
}

// 関門: DICT の制約と GETDICT の枠の辞書を、回収後も呼び出せる契約。
// ヒープの単体テストは VM の定数の表・枠の func の根の持ち方を確かめない。
#[test]
fn constrained_dictionary_and_call_frame_survive_collection() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 4).unwrap();
    let leaf = b.proto("showElement", 0, 1).unwrap();
    let wrapper = b.proto("showList", 1, 6).unwrap();
    let leaf_trait = trait_info(&mut b, "Show", 0, vec![]);
    let wrapper_trait = trait_info(&mut b, "ListShow", 1, vec![]);
    let leaf_imp = implementation(&mut b, "Show[Integer]", leaf_trait, 0, leaf, vec![]);
    let wrapper_imp = implementation(&mut b, "Show[List[T]]", wrapper_trait, 1, wrapper, vec![]);
    let leaf_k = b.constant(ConstDesc::Dict(leaf_imp)).unwrap();
    b.loadk(leaf, 0, ConstDesc::Str("element".into())).unwrap();
    b.code(leaf).unwrap().ret(0);
    let again = b.code(wrapper).unwrap().label("again").unwrap();
    b.loadk_int(wrapper, 1, 0).unwrap();
    b.code(wrapper).unwrap().op(Opcode::EqI, 2, 0, 1);
    b.code(wrapper).unwrap().jmpf(2, again);
    b.code(wrapper).unwrap().op(Opcode::GetDict, 3, 0, 0);
    method(&mut b, wrapper, false, leaf_trait, 4, 3);
    b.code(wrapper).unwrap().ret(4);
    b.code(wrapper).unwrap().place(again).unwrap();
    b.loadk_int(wrapper, 1, 1).unwrap();
    b.code(wrapper).unwrap().op(Opcode::SubI, 4, 0, 1);
    b.code(wrapper).unwrap().op(Opcode::GetDict, 2, 0, 0);
    b.code(wrapper)
        .unwrap()
        .op(Opcode::Dict, 3, u16::try_from(wrapper_imp.0).unwrap(), 2);
    // 親の辞書は、この呼び出しで回収するときには枠の func だけが指す。
    method(&mut b, wrapper, false, wrapper_trait, 5, 3);
    b.code(wrapper).unwrap().op(Opcode::GetDict, 3, 0, 0);
    method(&mut b, wrapper, false, leaf_trait, 5, 3);
    b.code(wrapper).unwrap().ret(5);
    b.loadk_ref(main, 0, leaf_k).unwrap();
    b.code(main)
        .unwrap()
        .op(Opcode::Dict, 1, u16::try_from(wrapper_imp.0).unwrap(), 0);
    b.loadk_int(main, 2, if cfg!(miri) { 4 } else { 256 })
        .unwrap();
    method(&mut b, main, false, wrapper_trait, 3, 1);
    result(&mut b, main, 3);
    let program = b.finish(main).unwrap();
    assert_eq!(
        run(&program, VmConfig::default(), true),
        VmStep::Finished(MainOutcome::Error("element".into()))
    );
}

// 関門: 辞書の式の三つの形と、その入れ子を SUPER が正しく評価する契約。
// 辞書の式の非公開の評価器を直接呼ばず、取り出したメソッドの結果で確かめる。
#[test]
fn superclass_recipes_select_the_correct_dictionary() {
    for kind in 0..4 {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 4).unwrap();
        let leaf = b.proto("leaf", 0, 1).unwrap();
        let forward = b.proto("forward", 0, 2).unwrap();
        let middle = b.proto("middle", 0, 1).unwrap();
        let base = trait_info(&mut b, "Base", 0, vec![]);
        let mid = trait_info(&mut b, "Middle", 0, vec![base]);
        let top = trait_info(&mut b, "Top", 0, vec![base]);
        let leaf_imp = implementation(&mut b, "Base[X]", base, 0, leaf, vec![]);
        let constrained = implementation(&mut b, "Base[List[T]]", base, 1, forward, vec![]);
        let mid_imp = implementation(
            &mut b,
            "Middle[T]",
            mid,
            1,
            middle,
            vec![DictRecipe::Param(0)],
        );
        let recipe = match kind {
            0 => DictRecipe::Impl {
                imp: leaf_imp,
                args: vec![],
            },
            1 => DictRecipe::Param(0),
            2 => DictRecipe::Super {
                of: Box::new(DictRecipe::Param(0)),
                index: 0,
            },
            3 => DictRecipe::Impl {
                imp: constrained,
                args: vec![DictRecipe::Super {
                    of: Box::new(DictRecipe::Param(0)),
                    index: 0,
                }],
            },
            _ => unreachable!(),
        };
        let top_imp = implementation(&mut b, "Top[T]", top, 1, middle, vec![recipe]);
        b.loadk(leaf, 0, ConstDesc::Str("base".into())).unwrap();
        b.code(leaf).unwrap().ret(0);
        b.code(forward).unwrap().op(Opcode::GetDict, 0, 0, 0);
        method(&mut b, forward, true, base, 0, 0);
        b.loadk(middle, 0, ConstDesc::Unit).unwrap();
        b.code(middle).unwrap().ret(0);
        b.loadk(main, 0, ConstDesc::Dict(leaf_imp)).unwrap();
        if kind >= 2 {
            b.code(main)
                .unwrap()
                .op(Opcode::Dict, 0, u16::try_from(mid_imp.0).unwrap(), 0);
        }
        b.code(main)
            .unwrap()
            .op(Opcode::Dict, 1, u16::try_from(top_imp.0).unwrap(), 0);
        b.code(main).unwrap().op(Opcode::Super, 1, 1, 0);
        method(&mut b, main, false, base, 2, 1);
        result(&mut b, main, 2);
        assert_eq!(
            run(&b.finish(main).unwrap(), VmConfig::default(), true),
            VmStep::Finished(MainOutcome::Error("base".into())),
            "recipe {kind}"
        );
    }
}

// 関門: 末尾メソッドの呼び出しは枠を増やさず、窓が重なり・伸縮しても引数を保つ契約。
// CALL のテストでは func の辞書への置き換えと TAILMETHOD の予算を通らない。
#[test]
#[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
fn tail_methods_repeat_a_million_times_and_resize_windows() {
    for mutual in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        let small = b.proto("small", 1, 5).unwrap();
        let large = if mutual {
            b.proto("large", 1, 9).unwrap()
        } else {
            small
        };
        let trait_ = trait_info(&mut b, "Countdown", 1, vec![]);
        let small_imp = implementation(&mut b, "Small", trait_, 0, small, vec![]);
        let large_imp = if mutual {
            implementation(&mut b, "Large", trait_, 0, large, vec![])
        } else {
            small_imp
        };
        b.loadk(main, 0, ConstDesc::Dict(small_imp)).unwrap();
        b.loadk_int(
            main,
            1,
            if cfg!(miri) {
                4
            } else if mutual {
                512
            } else {
                1_000_000
            },
        )
        .unwrap();
        method(&mut b, main, true, trait_, 0, 0);
        for (p, next) in if mutual {
            vec![(small, large_imp), (large, small_imp)]
        } else {
            vec![(small, small_imp)]
        } {
            let again = b.code(p).unwrap().label("again").unwrap();
            b.loadk_int(p, 1, 0).unwrap();
            b.code(p).unwrap().op(Opcode::EqI, 2, 0, 1);
            b.code(p).unwrap().jmpf(2, again);
            b.loadk(p, 1, ConstDesc::Unit).unwrap();
            b.code(p).unwrap().ret(1);
            b.code(p).unwrap().place(again).unwrap();
            b.loadk_int(p, 1, 1).unwrap();
            b.code(p).unwrap().op(Opcode::SubI, 4, 0, 1);
            // 毎回作る辞書によって TAILMETHOD の前の安全点に回収の要求を届ける。
            b.code(p)
                .unwrap()
                .op(Opcode::Dict, 3, u16::try_from(next.0).unwrap(), 0);
            method(&mut b, p, true, trait_, 0, 3);
        }
        let program = b.finish(main).unwrap();
        assert_eq!(
            run(
                &program,
                VmConfig {
                    max_call_stack_bytes: 1024,
                    call_budget: 3
                },
                false
            ),
            VmStep::Finished(MainOutcome::Ok)
        );
    }
}

// 関門: METHOD の非末尾再帰と TAILMETHOD の窓の拡大が、操作前に上限で止まる契約。
#[test]
fn method_calls_report_stack_limits_at_the_call_site() {
    for tail in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        let recurse = b.proto("recursive", 0, if tail { 30 } else { 2 }).unwrap();
        let trait_ = trait_info(&mut b, "Recursive", 0, vec![]);
        let imp = implementation(&mut b, "Recursive[X]", trait_, 0, recurse, vec![]);
        let k = b.constant(ConstDesc::Dict(imp)).unwrap();
        b.loadk_ref(main, 0, k).unwrap();
        method(&mut b, main, tail, trait_, 1, 0);
        b.code(main).unwrap().ret(1);
        b.loadk_ref(recurse, 0, k).unwrap();
        method(&mut b, recurse, false, trait_, 1, 0);
        b.code(recurse).unwrap().ret(1);
        let program = b.finish(main).unwrap();
        let limit = 1024;
        let info = error(run(
            &program,
            VmConfig {
                max_call_stack_bytes: limit,
                call_budget: 1,
            },
            true,
        ));
        let frames = if tail {
            1
        } else {
            limit / (FRAME_COST + 2 * REG_COST)
        };
        assert_eq!(
            info.stop,
            Stop::Resource(ResourceError::CallStackTooDeep { frames })
        );
        assert_eq!(info.frames.len(), usize::try_from(frames).unwrap());
        assert_eq!(
            info.at,
            Some(InstrRef {
                proto: if tail { main } else { recurse },
                pc: 1
            })
        );
    }
}

// 関門: 辞書でない値は、各命令の持ち主で Internal として拒む契約。
// まず有効な表で生存解析を通し、命令を VM で実行する。公開 API の差し込み口は不要。
#[test]
fn dictionary_instructions_reject_wrong_values_and_missing_entries() {
    for opcode in [
        Opcode::Method,
        Opcode::TailMethod,
        Opcode::Super,
        Opcode::GetDict,
        Opcode::Dict,
    ] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 3).unwrap();
        let leaf = b.proto("leaf", 0, 1).unwrap();
        let trait_ = trait_info(&mut b, "Trait", 0, vec![]);
        implementation(
            &mut b,
            "Trait[T]",
            trait_,
            1,
            leaf,
            vec![DictRecipe::Param(0)],
        );
        b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
        b.code(leaf).unwrap().ret(0);
        b.loadk_int(main, 0, 5).unwrap();
        if matches!(opcode, Opcode::Method | Opcode::TailMethod) {
            method(&mut b, main, opcode == Opcode::TailMethod, trait_, 1, 0);
        } else {
            b.code(main).unwrap().op(opcode, 1, 0, 0);
        }
        b.loadk(main, 2, ConstDesc::Unit).unwrap();
        b.code(main).unwrap().ret(2);
        let program = b.finish(main).unwrap();
        let info = error(run(&program, VmConfig::default(), true));
        assert!(matches!(info.stop, Stop::Internal(_)), "{opcode:?}");
        assert_eq!(info.at, Some(InstrRef { proto: main, pc: 1 }));
    }

    // 有効な辞書とメソッドのプログラムを作り、表の破損だけを各行で与える。
    let build = || {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        let leaf = b.proto("leaf", 0, 1).unwrap();
        let trait_ = trait_info(&mut b, "Trait", 0, vec![]);
        let imp = implementation(&mut b, "Trait[X]", trait_, 0, leaf, vec![]);
        b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
        b.code(leaf).unwrap().ret(0);
        b.loadk(main, 0, ConstDesc::Dict(imp)).unwrap();
        method(&mut b, main, false, trait_, 1, 0);
        b.code(main).unwrap().ret(1);
        b.finish(main).unwrap()
    };
    for case in 0..6 {
        let mut p = build();
        let pc = if case < 2 { 0 } else { 1 };
        match case {
            0 => p.impls.clear(),
            1 => p.impls[0].dict_arity = 1,
            2 => p.protos[0].method_traits[1] = None,
            3 => p.impls[0].methods.clear(),
            4 => p.impls[0].methods[0] = ProtoIdx(99),
            5 => p.protos[1].num_params = 1,
            _ => unreachable!(),
        }
        let info = error(run(&p, VmConfig::default(), true));
        assert!(matches!(info.stop, Stop::Internal(_)), "case {case}");
        assert_eq!(
            info.at,
            Some(InstrRef {
                proto: ProtoIdx(0),
                pc
            })
        );
    }
    // SUPER の番号が表にないときも、VM が命令の位置を記録して止める。
    let mut p = build();
    p.protos[0].code[1] = Instr::abc(Opcode::Super, 1, 0, 0);
    let info = error(run(&p, VmConfig::default(), true));
    assert!(matches!(info.stop, Stop::Internal(_)));
}
