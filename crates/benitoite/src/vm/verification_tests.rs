//! 二つの回収方式で、VM の根と CONR の再利用を確かめる（実装プラン R11、設計書 07-03）。
// 関門: 公開ヒープのテストでは確かめられない、VM の生存の情報・枠・再利用の順序を守る。
// R09 は CONR が新規確保する経路だけを扱う。本物の命令・組み込み・ヒープをつなぐ。
use super::*;
use crate::bytecode::program::CtorIdx;
use crate::runtime::heap::{CtorTag, FieldsKind, ObjId, RootIdx};
use std::collections::BTreeSet;

fn config() -> VmConfig {
    // 予算切れの位置を各呼び出しに置き、stress の回収数で安全点の漏れを調べる（設計書 02-08）。
    VmConfig {
        call_budget: 0,
        ..VmConfig::default()
    }
}

fn output(b: &mut ProgramBuilder, p: ProtoIdx, reg: u16) {
    let write = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    b.code(p)
        .unwrap()
        .op(Opcode::Io, 14, u16::try_from(write.0).unwrap(), reg);
}
fn pause(b: &mut ProgramBuilder, p: ProtoIdx, text: &str) {
    b.loadk(p, 12, ConstDesc::Str(text.into())).unwrap();
    output(b, p, 12);
}
fn integer_result(b: &mut ProgramBuilder, p: ProtoIdx, reg: u16) {
    let convert = b
        .named_builtin("Integer.toString", 1, Capability::Pure, None)
        .unwrap();
    b.code(p)
        .unwrap()
        .op(Opcode::Prim, reg, u16::try_from(convert.0).unwrap(), reg);
    output(b, p, reg);
    finish_value(b, p, reg, None);
}
fn ctor(b: &mut ProgramBuilder, p: ProtoIdx, a: u16, kind: CtorIdx, c: u16) {
    b.code(p)
        .unwrap()
        .op(Opcode::Con, a, u16::try_from(kind.0).unwrap(), c);
}

// 固定の期待値で結果と出力を調べ、回収後は RunState 自身を根にして検証する。
fn check_program(p: &CompiledProgram, stress: bool, expected: &str, minimum_collections: u64) {
    let mut vm = Vm::new(
        p,
        config(),
        HeapConfig {
            stress,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut services = io();
    assert_eq!(
        vm.run(services.runtime(ExecMode::Direct)),
        VmStep::Finished(MainOutcome::Error(expected.into()))
    );
    assert_eq!(
        services.take_output(),
        vec![(Stream::Stdout, format!("{expected}\n").into_bytes())]
    );
    if stress || cfg!(feature = "gc-stress") {
        assert!(
            vm.heap_stats().collections >= minimum_collections,
            "result={expected}, collections={}, minimum={minimum_collections}",
            vm.heap_stats().collections
        );
    }
    vm.heap.collect(&vm.state);
    assert_eq!(vm.heap.verify(&vm.state), Ok(()));
    assert!(vm.heap.take_fault().is_none());
}

fn tree_program(depth: usize, shared: bool) -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let walk = b.proto("walk", 1, 8).unwrap();
    let node = b.ctor("Tree", "Node", 1, 2).unwrap();
    let leaf = b.ctor("Tree", "Leaf", 0, 1).unwrap();
    b.loadk_int(main, 0, 1).unwrap();
    b.loadk_int(main, 10, 1).unwrap();
    ctor(&mut b, main, 2, leaf, 0);
    for _ in 0..depth {
        b.code(main).unwrap().op(Opcode::Move, 0, 2, 0);
        if shared {
            b.code(main).unwrap().op(Opcode::Move, 1, 2, 0);
        } else {
            ctor(&mut b, main, 1, leaf, 10);
        }
        ctor(&mut b, main, 2, node, 0);
    }
    b.loadk(main, 3, ConstDesc::Func(walk)).unwrap();
    b.code(main).unwrap().op(Opcode::Move, 4, 2, 0);
    b.code(main).unwrap().op(Opcode::Call, 5, 3, 1);
    integer_result(&mut b, main, 5);
    let leaf_label = b.code(walk).unwrap().label("leaf").unwrap();
    let node_label = b.code(walk).unwrap().label("node").unwrap();
    b.code(walk)
        .unwrap()
        .switch(0, vec![Some(leaf_label), Some(node_label)], None)
        .unwrap();
    b.code(walk).unwrap().place(leaf_label).unwrap();
    b.loadk_int(walk, 1, 1).unwrap();
    b.code(walk).unwrap().ret(1);
    b.code(walk).unwrap().place(node_label).unwrap();
    b.loadk(walk, 1, ConstDesc::Func(walk)).unwrap();
    b.code(walk).unwrap().op(Opcode::Field, 2, 0, 0);
    b.code(walk).unwrap().op(Opcode::Call, 3, 1, 1);
    b.loadk(walk, 1, ConstDesc::Func(walk)).unwrap();
    b.code(walk).unwrap().op(Opcode::Field, 2, 0, 1);
    b.code(walk).unwrap().op(Opcode::Call, 4, 1, 1);
    b.code(walk).unwrap().op(Opcode::AddI, 5, 3, 4);
    b.code(walk).unwrap().ret(5);
    b.finish(main).unwrap()
}

fn strings_and_survivor_program(count: usize, survivor: bool) -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let leaf = b.proto("leaf", 0, 1).unwrap();
    let box_ = b.ctor("Box", "Box", 1, 2).unwrap();
    let batches: Vec<_> = (2_u16..=5)
        .map(|arity| {
            b.ctor("Batch", &format!("Batch{arity}"), u32::from(arity), arity)
                .unwrap()
        })
        .collect();
    let length = b
        .named_builtin("String.byteLength", 1, Capability::Pure, None)
        .unwrap();
    let range = b
        .named_builtin("List.range", 2, Capability::Pure, None)
        .unwrap();
    let list_length = b
        .named_builtin("List.length", 1, Capability::Pure, None)
        .unwrap();
    b.loadk(
        main,
        8,
        ConstDesc::Str("keep".repeat(if cfg!(miri) { 8 } else { 2048 })),
    )
    .unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 9, 8, 8);
    b.code(main).unwrap().op(Opcode::Move, 10, 9, 0);
    b.loadk_int(main, 11, 0).unwrap();
    b.loadk_int(main, 12, if cfg!(miri) { 8 } else { 512 })
        .unwrap();
    b.code(main)
        .unwrap()
        .op(Opcode::Prim, 13, u16::try_from(range.0).unwrap(), 11);
    b.code(main).unwrap().op(Opcode::Move, 11, 13, 0);
    ctor(&mut b, main, 9, box_, 10);
    b.loadk_int(main, 7, 0).unwrap();
    for i in 0..count {
        b.loadk(main, 0, ConstDesc::Str("x".repeat(i % 71 + 1)))
            .unwrap();
        b.code(main).unwrap().op(Opcode::Concat, 1, 0, 0);
        let arity = u16::try_from(i % 4 + 2).unwrap();
        for reg in 2..=arity {
            b.code(main).unwrap().op(Opcode::Move, reg, 1, 0);
        }
        ctor(&mut b, main, 3, batches[i % 4], 1);
        b.loadk(main, 4, ConstDesc::Func(leaf)).unwrap();
        b.code(main).unwrap().op(Opcode::Call, 5, 4, 0);
        // 並びの長さも変え、短命な並びの内部参照を回収後に確かめる（実装プラン R11）。
        b.code(main).unwrap().op(Opcode::Field, 6, 3, 0);
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, 6, u16::try_from(length.0).unwrap(), 6);
        b.code(main).unwrap().op(Opcode::AddI, 7, 7, 6);
    }
    if survivor {
        b.code(main).unwrap().op(Opcode::Field, 6, 9, 0);
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, 6, u16::try_from(length.0).unwrap(), 6);
        b.code(main).unwrap().op(Opcode::AddI, 7, 7, 6);
        b.code(main).unwrap().op(Opcode::Field, 6, 9, 1);
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, 6, u16::try_from(list_length.0).unwrap(), 6);
        b.code(main).unwrap().op(Opcode::AddI, 7, 7, 6);
    }
    integer_result(&mut b, main, 7);
    b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
    b.code(leaf).unwrap().ret(0);
    b.finish(main).unwrap()
}

fn closure_program() -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let captured = b.proto("captured", 0, 4).unwrap();
    let leaf = b.proto("leaf", 0, 1).unwrap();
    let length = b
        .named_builtin("String.byteLength", 1, Capability::Pure, None)
        .unwrap();
    b.loadk(main, 0, ConstDesc::Str("capture".into())).unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 1, 0, 0);
    b.code(main).unwrap().abx(Opcode::Closure, 2, captured.0);
    b.code(main).unwrap().op(Opcode::Call, 3, 2, 0);
    integer_result(&mut b, main, 3);
    b.code(captured).unwrap().proto.captures = vec![CaptureSource::Reg(1)];
    b.loadk(captured, 0, ConstDesc::Func(leaf)).unwrap();
    b.code(captured).unwrap().op(Opcode::Call, 1, 0, 0);
    b.code(captured).unwrap().op(Opcode::GetCap, 2, 0, 0);
    b.code(captured)
        .unwrap()
        .op(Opcode::Prim, 3, u16::try_from(length.0).unwrap(), 2);
    b.code(captured).unwrap().ret(3);
    b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
    b.code(leaf).unwrap().ret(0);
    b.finish(main).unwrap()
}

#[test]
fn workload_results_and_output_agree_with_and_without_stress() {
    let depth = if cfg!(miri) { 2 } else { 7 };
    let count = if cfg!(miri) { 3 } else { 100 };
    let total: usize = (0..count).map(|i| 2 * (i % 71 + 1)).sum();
    // 各 walk/leaf の呼び出し前と復帰後の安全点に一回ずつ要る（ADR 0259 の決定 5）。
    let cases = [
        (
            tree_program(depth, false),
            (depth + 1).to_string(),
            u64::try_from(2 * (2 * depth + 1)).unwrap(),
        ),
        (
            tree_program(depth, true),
            (1_usize << depth).to_string(),
            u64::try_from(2 * ((1_usize << (depth + 1)) - 1)).unwrap(),
        ),
        (
            strings_and_survivor_program(count, false),
            total.to_string(),
            u64::try_from(2 * count).unwrap(),
        ),
        (
            strings_and_survivor_program(count, true),
            (total + if cfg!(miri) { 8 + 64 } else { 512 + 16_384 }).to_string(),
            u64::try_from(2 * count).unwrap(),
        ),
        (closure_program(), "14".into(), 4),
    ];
    for (program, expected, minimum) in cases {
        for stress in [false, true] {
            check_program(&program, stress, &expected, minimum);
        }
    }
    // R09 の深い再帰の組み立てを共有し、小さな同一プログラムを四つの構成に通す。
    let depth = if cfg!(miri) { 3 } else { 128 };
    let program = deep_returns_program(depth, 12);
    for stress in [false, true] {
        let mut vm = Vm::new(
            &program,
            config(),
            HeapConfig {
                stress,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut services = io();
        assert_eq!(
            vm.run(services.runtime(ExecMode::Direct)),
            VmStep::Finished(MainOutcome::Error("12".into()))
        );
        assert_eq!(
            services.take_output(),
            vec![(Stream::Stdout, b"bottom\n".to_vec())]
        );
        if stress || cfg!(feature = "gc-stress") {
            assert!(vm.heap_stats().collections >= u64::try_from(2 * (depth + 1)).unwrap());
        }
        vm.heap.collect(&vm.state);
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        assert!(vm.heap.take_fault().is_none());
    }
}

fn map_program(count: usize) -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let map = b.proto("reverseMap", 1, 8).unwrap();
    let leaf = b.proto("leaf", 0, 1).unwrap();
    let cons = b.ctor("Chain", "Cons", 1, 2).unwrap();
    let nil = b.ctor("Chain", "Nil", 0, 0).unwrap();
    b.loadk(
        main,
        1,
        ConstDesc::Ctor {
            ctor: nil,
            args: vec![],
        },
    )
    .unwrap();
    for i in 0..count {
        b.loadk_int(main, 0, i64::try_from(i).unwrap()).unwrap();
        ctor(&mut b, main, 2, cons, 0);
        b.code(main).unwrap().op(Opcode::Move, 1, 2, 0);
    }
    pause(&mut b, main, "before");
    b.loadk(main, 3, ConstDesc::Func(map)).unwrap();
    b.code(main).unwrap().op(Opcode::Move, 4, 2, 0);
    b.code(main).unwrap().op(Opcode::Call, 2, 3, 1);
    pause(&mut b, main, "after");
    b.code(main).unwrap().op(Opcode::Field, 5, 2, 0);
    integer_result(&mut b, main, 5);
    b.loadk(
        map,
        1,
        ConstDesc::Ctor {
            ctor: nil,
            args: vec![],
        },
    )
    .unwrap();
    let again = b.code(map).unwrap().label("again").unwrap();
    let done = b.code(map).unwrap().label("done").unwrap();
    let item = b.code(map).unwrap().label("item").unwrap();
    b.code(map).unwrap().place(again).unwrap();
    b.code(map)
        .unwrap()
        .switch(0, vec![Some(done), Some(item)], None)
        .unwrap();
    b.code(map).unwrap().place(item).unwrap();
    b.code(map).unwrap().op(Opcode::Field, 2, 0, 0);
    b.code(map).unwrap().op(Opcode::Field, 5, 0, 1);
    b.loadk_int(map, 3, 1).unwrap();
    b.code(map).unwrap().op(Opcode::AddI, 3, 2, 3);
    b.code(map).unwrap().op(Opcode::Move, 4, 1, 0);
    b.code(map).unwrap().conr(0, cons, 3).unwrap();
    b.code(map).unwrap().op(Opcode::Move, 1, 0, 0);
    b.code(map).unwrap().op(Opcode::Move, 0, 5, 0);
    b.loadk(map, 6, ConstDesc::Func(leaf)).unwrap();
    b.code(map).unwrap().op(Opcode::Call, 7, 6, 0);
    b.code(map).unwrap().jmp(again);
    b.code(map).unwrap().place(done).unwrap();
    b.code(map).unwrap().ret(1);
    b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
    b.code(leaf).unwrap().ret(0);
    b.finish(main).unwrap()
}
fn chain(vm: &mut Vm<'_>, root: Option<RootIdx>) -> Vec<(ObjId, i64)> {
    vm.heap.epoch(|ctx| {
        let mut value = root.map_or_else(
            || {
                ctx.load(
                    &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs[2],
                )
            },
            |idx| vm.state.roots.get(ctx, idx).unwrap(),
        );
        let mut result = Vec::new();
        while value.as_tag().is_none() {
            let id = ctx.object_id(value).unwrap();
            assert!(!result.iter().any(|(previous, _)| *previous == id));
            result.push((id, ctx.field(value, 0).unwrap().as_int().unwrap()));
            value = ctx.field(value, 1).unwrap();
        }
        assert_eq!(value.as_tag(), Some(CtorTag(0)));
        result
    })
}

#[test]
fn conr_constructs_each_node_and_preserves_shared_chain() {
    let count = if cfg!(miri) { 3 } else { 80 };
    let program = map_program(count);
    for stress in [false, true] {
        for reuse in [false, true] {
            for shared in [false, true] {
                let mut vm = Vm::new(
                    &program,
                    config(),
                    HeapConfig {
                        stress,
                        reuse,
                        ..HeapConfig::default()
                    },
                );
                vm.start_main().unwrap();
                let mut services = io();
                let first = request(&mut vm, &mut services);
                let before = chain(&mut vm, None);
                let saved = shared.then(|| {
                    vm.heap.epoch(|ctx| {
                        vm.state.roots.push(
                            ctx,
                            ctx.load(
                                &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments
                                    [0]
                                .regs[2],
                            ),
                        )
                    })
                });
                vm.serve_request(&mut services.rt, first);
                let second = request(&mut vm, &mut services);
                let after = chain(&mut vm, None);
                assert_eq!(
                    after.iter().map(|(_, n)| *n).collect::<Vec<_>>(),
                    (1..=count)
                        .map(|n| i64::try_from(n).unwrap())
                        .collect::<Vec<_>>()
                );
                assert_eq!(vm.heap_stats().reuses, 0);
                if shared {
                    assert_eq!(chain(&mut vm, saved), before);
                }
                vm.heap.collect(&vm.state);
                assert_eq!(vm.heap.verify(&vm.state), Ok(()));
                assert!(vm.heap.take_fault().is_none());
                if stress || cfg!(feature = "gc-stress") {
                    assert!(vm.heap_stats().collections >= u64::try_from(2 * count).unwrap());
                }
                vm.serve_request(&mut services.rt, second);
                assert_eq!(
                    vm.run(services.runtime(ExecMode::Direct)),
                    VmStep::Finished(MainOutcome::Error("1".into()))
                );
                assert_eq!(
                    services.take_output(),
                    vec![
                        (Stream::Stdout, b"before\n".to_vec()),
                        (Stream::Stdout, b"after\n".to_vec()),
                        (Stream::Stdout, b"1\n".to_vec())
                    ]
                );
                vm.heap.epoch(|ctx| vm.state.roots.truncate(ctx, 0));
                assert!(vm.heap.take_fault().is_none());
            }
        }
    }
}

#[test]
fn conr_argument_alias_keeps_original_node_and_never_creates_self_edge() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let box_ = b.ctor("Box", "Box", 1, 1).unwrap();
    b.loadk(main, 0, ConstDesc::Str("x".into())).unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 0, 0, 0);
    ctor(&mut b, main, 1, box_, 0);
    b.code(main).unwrap().op(Opcode::Move, 0, 1, 0);
    let pc = b.code(main).unwrap().proto.code.len();
    b.code(main).unwrap().conr(1, box_, 0).unwrap();
    pause(&mut b, main, "alias");
    b.code(main).unwrap().op(Opcode::Field, 2, 1, 0);
    b.code(main).unwrap().op(Opcode::Field, 3, 2, 0);
    finish_value(&mut b, main, 3, None);
    let program = b.finish(main).unwrap();
    assert!(
        program.protos[0]
            .live
            .at(u32::try_from(pc).unwrap())
            .contains(&LiveItem::LastUse { reg: 1, sole: true })
    );
    for stress in [false, true] {
        let mut observations = Vec::new();
        for reuse in [false, true] {
            let mut vm = Vm::new(
                &program,
                config(),
                HeapConfig {
                    stress,
                    reuse,
                    ..HeapConfig::default()
                },
            );
            vm.start_main().unwrap();
            let mut services = io();
            let id = request(&mut vm, &mut services);
            vm.heap.collect(&vm.state);
            assert_eq!(vm.heap.verify(&vm.state), Ok(()));
            assert_eq!(vm.heap_stats().reuses, 0);
            let observation = vm.heap.epoch(|ctx| {
                let outer = ctx.load(
                    &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs[1],
                );
                let inner = ctx.field(outer, 0).unwrap();
                assert!(!ctx.same_object(outer, inner));
                let text = ctx.field(inner, 0).unwrap();
                let expected_inner = ctx.alloc_fields(FieldsKind::Ctor, 1, &[text]).unwrap();
                let expected = ctx
                    .alloc_fields(FieldsKind::Ctor, 1, &[expected_inner])
                    .unwrap();
                assert!(crate::runtime::equal::values_equal(ctx, outer, expected).unwrap());
                (
                    ctx.fields_header(outer),
                    ctx.fields_header(inner),
                    ctx.str(text).unwrap().to_owned(),
                )
            });
            // 確保番地に依存せず、同じ到達構造と対象の集合の大きさを比べる。
            vm.heap.collect(&vm.state);
            let live = vm.heap.object_ids().into_iter().collect::<BTreeSet<_>>();
            observations.push((observation, live.len()));
            assert!(vm.heap.take_fault().is_none());
            vm.serve_request(&mut services.rt, id);
            assert_eq!(
                vm.run(services.runtime(ExecMode::Request)),
                VmStep::Finished(MainOutcome::Error("xx".into()))
            );
            assert_eq!(
                services.take_output(),
                vec![(Stream::Stdout, b"alias\n".to_vec())]
            );
        }
        assert_eq!(observations[0], observations[1]);
    }
}
