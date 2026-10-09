//! 第 1 段の VM の契約を、R05 の組み立てと本番のヒープ・組み込みの表をつないで確かめる。
// テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::builtins::iface::Capability;
use crate::builtins::table::tags;
use crate::bytecode::asm::ProgramBuilder;
use crate::bytecode::instr::{Instr, Opcode};
use crate::bytecode::liveness::LiveItem;
use crate::bytecode::program::{CaptureSource, ConstDesc, MainKind};
use crate::runtime::heap::{CheckedLen, HeapConfig, Slot, Value};
use crate::runtime::io::services::RunInput;
use crate::runtime::{ResourceError, RuntimeError, Stop, Stream, list};
use crate::vm::dispatch::test_support::TestIo;

#[path = "verification_tests.rs"]
mod verification_tests;

fn io() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}

fn finish_value(b: &mut ProgramBuilder, main: ProtoIdx, reg: u16, conversion: Option<&str>) {
    b.program.main_kind = MainKind::Result;
    if let Some(name) = conversion {
        let builtin = b.named_builtin(name, 1, Capability::Pure, None).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, reg, u16::try_from(builtin.0).unwrap(), reg);
    }
    let ctor = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
    b.code(main)
        .unwrap()
        .op(Opcode::Con, 15, u16::try_from(ctor.0).unwrap(), reg);
    b.code(main).unwrap().ret(15);
}

fn run(
    program: &CompiledProgram,
    config: VmConfig,
    heap: HeapConfig,
    mode: ExecMode,
) -> (VmStep, Vec<(Stream, Vec<u8>)>) {
    let mut vm = Vm::new(program, config, heap);
    vm.start_main().unwrap();
    let mut services = io();
    let step = loop {
        match vm.run(services.runtime(mode)) {
            VmStep::Requests(ids) => {
                assert!(!ids.is_empty());
                for id in ids {
                    vm.serve_request(&mut services.rt, id);
                }
            }
            step @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break step,
        }
    };
    assert!(vm.heap.take_fault().is_none());
    (step, services.take_output())
}

fn error(step: VmStep) -> StopInfo {
    match step {
        VmStep::Stopped(StopEnd {
            reason: StopReason::Error(info),
            release_failures,
        }) => {
            assert!(release_failures.is_empty());
            info
        }
        other @ (VmStep::Requests(_) | VmStep::Finished(_) | VmStep::Stopped(_)) => {
            panic!("expected stopped: {other:?}")
        }
    }
}

// 関門: 命令の種類・被演算子・結果の書き先・LastUse を VM が正しくつなぐ契約。
// 演算本体のテストでは命令の振り分けや同じレジスタの二度の読み出しを捕まえられない。
#[test]
fn arithmetic_and_comparisons_follow_language_rules() {
    use ConstDesc::{Bool, Char, Float, Int, Str};
    let cases = [
        (Opcode::AddI, Int(4), Int(7), "Integer.toString", "11"),
        (Opcode::SubI, Int(4), Int(7), "Integer.toString", "-3"),
        (Opcode::MulI, Int(-4), Int(7), "Integer.toString", "-28"),
        (Opcode::DivI, Int(-7), Int(2), "Integer.toString", "-3"),
        (Opcode::ModI, Int(-7), Int(2), "Integer.toString", "-1"),
        (
            Opcode::ModI,
            Int(i64::MIN),
            Int(-1),
            "Integer.toString",
            "0",
        ),
        (
            Opcode::AddF,
            Float(1.5),
            Float(2.0),
            "Float.toString",
            "3.5",
        ),
        (
            Opcode::SubF,
            Float(1.5),
            Float(2.0),
            "Float.toString",
            "-0.5",
        ),
        (
            Opcode::MulF,
            Float(1.5),
            Float(2.0),
            "Float.toString",
            "3.0",
        ),
        (
            Opcode::DivF,
            Float(3.0),
            Float(2.0),
            "Float.toString",
            "1.5",
        ),
        (Opcode::EqI, Int(7), Int(7), "%Boolean.toString", "true"),
        (Opcode::LtI, Int(7), Int(8), "%Boolean.toString", "true"),
        (Opcode::LeI, Int(7), Int(7), "%Boolean.toString", "true"),
        (
            Opcode::EqF,
            Float(f64::NAN),
            Float(f64::NAN),
            "%Boolean.toString",
            "false",
        ),
        (
            Opcode::LtF,
            Float(f64::NAN),
            Float(0.0),
            "%Boolean.toString",
            "false",
        ),
        (
            Opcode::LeF,
            Float(0.0),
            Float(f64::NAN),
            "%Boolean.toString",
            "false",
        ),
        (
            Opcode::EqS,
            Str("あ".into()),
            Str("あ".into()),
            "%Boolean.toString",
            "true",
        ),
        (
            Opcode::LtS,
            Str("あ".into()),
            Str("い".into()),
            "%Boolean.toString",
            "true",
        ),
        (
            Opcode::LeS,
            Str("あ".into()),
            Str("あ".into()),
            "%Boolean.toString",
            "true",
        ),
        (
            Opcode::EqC,
            Char('あ'),
            Char('あ'),
            "%Boolean.toString",
            "true",
        ),
        (
            Opcode::LtC,
            Char('あ'),
            Char('い'),
            "%Boolean.toString",
            "true",
        ),
        (
            Opcode::LeC,
            Char('あ'),
            Char('あ'),
            "%Boolean.toString",
            "true",
        ),
        (
            Opcode::EqB,
            Bool(true),
            Bool(false),
            "%Boolean.toString",
            "false",
        ),
    ];
    for (opcode, a, c, conversion, expected) in cases {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        b.loadk(main, 0, a).unwrap();
        b.loadk(main, 1, c).unwrap();
        b.code(main).unwrap().op(opcode, 2, 0, 1);
        finish_value(&mut b, main, 2, Some(conversion));
        let p = b.finish(main).unwrap();
        assert_eq!(
            run(
                &p,
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct
            )
            .0,
            VmStep::Finished(MainOutcome::Error(expected.into())),
            "{opcode:?}"
        );
    }
    for (opcode, input, conversion, expected) in [
        (Opcode::NegI, Int(7), "Integer.toString", "-7"),
        (Opcode::NegF, Float(1.5), "Float.toString", "-1.5"),
        (Opcode::Not, Bool(false), "%Boolean.toString", "true"),
    ] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        b.loadk(main, 0, input).unwrap();
        b.code(main).unwrap().op(opcode, 1, 0, 0);
        finish_value(&mut b, main, 1, Some(conversion));
        assert_eq!(
            run(
                &b.finish(main).unwrap(),
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct
            )
            .0,
            VmStep::Finished(MainOutcome::Error(expected.into()))
        );
    }
    // 同じ被演算子を二度読む最後の使用と MOVE の移動。
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    b.loadk_int(main, 0, 21).unwrap();
    b.code(main).unwrap().op(Opcode::Move, 1, 0, 0);
    b.code(main).unwrap().op(Opcode::AddI, 2, 1, 1);
    finish_value(&mut b, main, 2, Some("Integer.toString"));
    assert_eq!(
        run(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            HeapConfig::default(),
            ExecMode::Direct
        )
        .0,
        VmStep::Finished(MainOutcome::Error("42".into()))
    );
}

#[test]
fn arithmetic_stops_preserve_instruction_and_frames() {
    for (opcode, a, b, expected) in [
        (Opcode::DivI, 7, 0, RuntimeError::DivisionByZero),
        (Opcode::ModI, 7, 0, RuntimeError::DivisionByZero),
        (Opcode::AddI, i64::MAX, 1, RuntimeError::IntegerOverflow),
        (Opcode::SubI, i64::MIN, 1, RuntimeError::IntegerOverflow),
        (Opcode::MulI, i64::MAX, 2, RuntimeError::IntegerOverflow),
        (Opcode::DivI, i64::MIN, -1, RuntimeError::IntegerOverflow),
        (Opcode::NegI, i64::MIN, 0, RuntimeError::IntegerOverflow),
    ] {
        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 0, 3).unwrap();
        builder.loadk_int(main, 0, a).unwrap();
        builder.loadk_int(main, 1, b).unwrap();
        builder.code(main).unwrap().op(opcode, 2, 0, 1);
        builder.code(main).unwrap().ret(2);
        let info = error(
            run(
                &builder.finish(main).unwrap(),
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct,
            )
            .0,
        );
        assert_eq!(info.stop, Stop::Runtime(expected));
        assert_eq!(info.at, Some(InstrRef { proto: main, pc: 2 }));
        assert_eq!(
            info.frames,
            vec![FrameRecord {
                proto: main,
                call_site: None
            }]
        );
    }
    // 上限の大きさの計算はヒープの CheckedLen が担う。実際の GiB の確保は行わない。
    assert!(matches!(
        CheckedLen::bytes(crate::runtime::MAX_STRING_BYTES + 1, "+"),
        Err(Stop::Resource(ResourceError::ValueTooLarge {
            function: "+",
            ..
        }))
    ));
}

// 関門: main の変換、定数の組み立て、構成子・リスト・FIELD・EQV を通した結果を守る。
// ランタイムのテストでは VM が表の位置とタグを混同する誤りを捕まえられない。
#[test]
fn constants_data_and_main_outcomes() {
    for kind in [MainKind::Unit, MainKind::Result] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        b.program.main_kind = kind;
        b.loadk(main, 0, ConstDesc::Unit).unwrap();
        if kind == MainKind::Result {
            let ctor = b.ctor("Result", "Ok", tags::RESULT_OK, 1).unwrap();
            b.code(main)
                .unwrap()
                .op(Opcode::Con, 1, u16::try_from(ctor.0).unwrap(), 0);
            b.code(main).unwrap().ret(1);
        } else {
            b.code(main).unwrap().ret(0);
        }
        let mut program = b.finish(main).unwrap();
        assert_eq!(
            run(
                &program,
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct
            )
            .0,
            VmStep::Finished(MainOutcome::Ok)
        );
        program.main = None;
        assert!(matches!(
            Vm::new(&program, VmConfig::default(), HeapConfig::default())
                .start_main()
                .unwrap_err()
                .stop,
            Stop::Internal(_)
        ));
    }
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    b.loadk(main, 0, ConstDesc::Str("左".into())).unwrap();
    b.loadk(main, 1, ConstDesc::Str("右".into())).unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 2, 0, 1);
    finish_value(&mut b, main, 2, None);
    assert_eq!(
        run(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            HeapConfig::default(),
            ExecMode::Direct
        )
        .0,
        VmStep::Finished(MainOutcome::Error("左右".into()))
    );

    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let node = b.ctor("Node", "Node", 4, 1).unwrap();
    // 異なる即値の順序と、同じ子を共有する入れ子の定数を、動的に作った値と比べる。
    let first = b.constant(ConstDesc::Int(9)).unwrap();
    let second = b.constant(ConstDesc::Int(10)).unwrap();
    let child = b.constant(ConstDesc::List(vec![first, second])).unwrap();
    let constant = b.constant(ConstDesc::List(vec![child, child])).unwrap();
    b.loadk_ref(main, 0, constant).unwrap();
    b.loadk_int(main, 1, 9).unwrap();
    b.loadk_int(main, 2, 10).unwrap();
    b.code(main).unwrap().op(Opcode::List, 3, 1, 2);
    b.code(main).unwrap().op(Opcode::Move, 4, 3, 0);
    b.code(main).unwrap().op(Opcode::List, 5, 3, 2);
    b.code(main)
        .unwrap()
        .op(Opcode::Con, 6, u16::try_from(node.0).unwrap(), 5);
    b.code(main).unwrap().op(Opcode::Field, 7, 6, 0);
    b.code(main).unwrap().op(Opcode::EqV, 8, 0, 7);
    finish_value(&mut b, main, 8, Some("%Boolean.toString"));
    assert_eq!(
        run(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
            ExecMode::Direct
        )
        .0,
        VmStep::Finished(MainOutcome::Error("true".into()))
    );
}

// 関門: 定数表だけを根にした回収の後も、同じ番号の LOADK が同じ対象を返す。
// 文字列以外の種類でもキャッシュの保存や Trace を漏らす退行を、VM の入口で検出する
// （実装プラン R17「受け入れテスト」。既存の文字列・写像・集合のテストを補う）。
#[test]
fn heap_constants_keep_identity_when_only_the_cache_roots_them() {
    for kind in 0..7 {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 5).unwrap();
        let leaf = b.proto("leaf", 0, 1).unwrap();
        b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
        b.code(leaf).unwrap().ret(0);
        let child = b.constant(ConstDesc::Str("child".into())).unwrap();
        let key = b.constant(ConstDesc::Int(7)).unwrap();
        let ctor = b.ctor("Node", "Node", 4, 1).unwrap();
        let desc = match kind {
            0 => ConstDesc::Str("cached".into()),
            1 => ConstDesc::Func(leaf),
            2 => ConstDesc::Ctor {
                ctor,
                args: vec![child],
            },
            3 => ConstDesc::List(vec![child, child]),
            4 => ConstDesc::Map(vec![(key, child)]),
            5 => ConstDesc::Set(vec![key]),
            6 => ConstDesc::Decimal {
                mantissa: 123,
                scale: 2,
            },
            _ => panic!("unknown constant test kind"),
        };
        let constant = b.constant(desc).unwrap();
        let pause = b
            .named_builtin("Benitoite.IO.Process.arguments", 0, Capability::Io, None)
            .unwrap();
        b.loadk_ref(main, 0, constant).unwrap();
        b.loadk_ref(main, 1, constant).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 4, u16::try_from(pause.0).unwrap(), 0);
        // 第 2 段は要求を返す前にも整理する。最初の観察までは二つの値を生存させ、
        // 観察後に明示的に消してキャッシュだけを根にする（ADR 0314）。
        b.code(main).unwrap().op(Opcode::Move, 4, 0, 0);
        b.code(main).unwrap().op(Opcode::Move, 4, 1, 0);
        b.loadk_ref(main, 2, constant).unwrap();
        b.loadk_ref(main, 3, constant).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 4, u16::try_from(pause.0).unwrap(), 0);
        // 関数の値は構造の等しさを持たないので、待つ間の生存は MOVE の読み出しで保つ。
        b.code(main).unwrap().op(Opcode::Move, 4, 2, 0);
        b.code(main).unwrap().op(Opcode::Move, 4, 3, 0);
        b.loadk(main, 4, ConstDesc::Unit).unwrap();
        b.code(main).unwrap().ret(4);
        let program = b.finish(main).unwrap();
        let mut vm = Vm::new(&program, VmConfig::default(), HeapConfig::default());
        vm.start_main().unwrap();
        let mut services = io();
        let first = request(&mut vm, &mut services);
        let identity = vm.heap.epoch(|ctx| {
            let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
            let value = ctx.load(&regs[0]);
            assert!(ctx.same_object(value, ctx.load(&regs[1])), "kind {kind}");
            let identity = ctx.object_id(value).unwrap();
            let count = regs.len();
            crate::vm::dispatch::test_support::clear_waiting_registers(
                &mut vm.state,
                ctx,
                &(0..count).collect::<Vec<_>>(),
            );
            identity
        });
        vm.heap.collect(&vm.state);
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        vm.serve_request(&mut services.rt, first);
        let second = request(&mut vm, &mut services);
        vm.heap.epoch(|ctx| {
            let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
            assert_eq!(
                ctx.object_id(ctx.load(&regs[2])),
                Some(identity),
                "kind {kind}"
            );
            assert!(ctx.same_object(ctx.load(&regs[2]), ctx.load(&regs[3])));
        });
        vm.serve_request(&mut services.rt, second);
        assert_eq!(
            vm.run(services.runtime(ExecMode::Request)),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert!(vm.heap.take_fault().is_none());
    }
}

// 関門: 検証器を通していない不正な番号も、VM の公開の実行関数は panic にせず止める。
#[test]
fn loadk_rejects_constant_indices_outside_the_table() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 1).unwrap();
    b.loadk(main, 0, ConstDesc::Str("cached".into())).unwrap();
    b.code(main).unwrap().ret(0);
    let mut program = b.finish(main).unwrap();
    for idx in [u32::try_from(program.consts.len()).unwrap(), u32::MAX] {
        program.protos[0].consts[0] = crate::bytecode::program::ConstIdx(idx);
        let info = error(
            run(
                &program,
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct,
            )
            .0,
        );
        assert!(matches!(info.stop, Stop::Internal(_)));
        assert_eq!(info.at, Some(InstrRef { proto: main, pc: 0 }));
    }
}

#[test]
fn branches_use_constructor_tags_and_relative_offsets() {
    for tag in [0, 1, 2, 5] {
        for fields in [false, true] {
            let mut b = ProgramBuilder::new();
            let main = b.proto("main", 0, 16).unwrap();
            let ctor = b.ctor("Choice", "Choice", tag, u16::from(fields)).unwrap();
            let children = if fields {
                vec![b.constant(ConstDesc::Int(0)).unwrap()]
            } else {
                vec![]
            };
            b.loadk(
                main,
                0,
                ConstDesc::Ctor {
                    ctor,
                    args: children,
                },
            )
            .unwrap();
            if !fields {
                b.code(main)
                    .unwrap()
                    .op(Opcode::Con, 0, u16::try_from(ctor.0).unwrap(), 0);
            }
            let mut labels = vec![];
            for name in ["first", "second", "third", "fallback"] {
                labels.push(b.code(main).unwrap().label(name).unwrap());
            }
            let done = b.code(main).unwrap().label("done").unwrap();
            b.code(main)
                .unwrap()
                .switch(
                    0,
                    labels[..3].iter().copied().map(Some).collect(),
                    Some(labels[3]),
                )
                .unwrap();
            for (i, label) in labels.into_iter().enumerate() {
                b.code(main).unwrap().place(label).unwrap();
                b.loadk_int(main, 1, i64::try_from(i).unwrap()).unwrap();
                b.code(main).unwrap().jmp(done);
            }
            b.code(main).unwrap().place(done).unwrap();
            finish_value(&mut b, main, 1, Some("Integer.toString"));
            let mut p = b.finish(main).unwrap();
            assert_eq!(
                run(
                    &p,
                    VmConfig::default(),
                    HeapConfig::default(),
                    ExecMode::Direct
                )
                .0,
                VmStep::Finished(MainOutcome::Error(if tag < 3 {
                    tag.to_string()
                } else {
                    "3".into()
                }))
            );
            if tag == 5 {
                p.protos[0].switch_tables[0].default = None;
                assert!(matches!(
                    error(
                        run(
                            &p,
                            VmConfig::default(),
                            HeapConfig::default(),
                            ExecMode::Direct
                        )
                        .0
                    )
                    .stop,
                    Stop::Internal(_)
                ));
            }
        }
    }
    for condition in [true, false] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let otherwise = b.code(main).unwrap().label("else").unwrap();
        let done = b.code(main).unwrap().label("done").unwrap();
        b.loadk(main, 0, ConstDesc::Bool(condition)).unwrap();
        b.code(main).unwrap().jmpf(0, otherwise);
        b.loadk_int(main, 1, 11).unwrap();
        b.code(main).unwrap().jmp(done);
        b.code(main).unwrap().place(otherwise).unwrap();
        b.loadk_int(main, 1, 22).unwrap();
        b.code(main).unwrap().place(done).unwrap();
        finish_value(&mut b, main, 1, Some("Integer.toString"));
        assert_eq!(
            run(
                &b.finish(main).unwrap(),
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct
            )
            .0,
            VmStep::Finished(MainOutcome::Error(
                if condition { "11" } else { "22" }.into()
            ))
        );
    }
}

#[test]
fn calls_read_two_arguments_and_flattened_captures() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let add = b.proto("add", 2, 3).unwrap();
    let outer = b.proto("outer", 0, 2).unwrap();
    let inner = b.proto("inner", 0, 3).unwrap();
    b.loadk(main, 0, ConstDesc::Func(add)).unwrap();
    b.loadk_int(main, 1, 20).unwrap();
    b.loadk_int(main, 2, 22).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 3, 0, 2);
    b.code(main).unwrap().abx(Opcode::Closure, 4, outer.0);
    b.code(main).unwrap().op(Opcode::Call, 5, 4, 0);
    b.code(main).unwrap().op(Opcode::Call, 6, 5, 0);
    finish_value(&mut b, main, 6, Some("Integer.toString"));
    b.code(add).unwrap().op(Opcode::AddI, 2, 0, 1);
    b.code(add).unwrap().ret(2);
    b.code(outer).unwrap().proto.captures = vec![CaptureSource::Reg(3)];
    b.loadk_int(outer, 0, 1).unwrap();
    b.code(outer).unwrap().abx(Opcode::Closure, 1, inner.0);
    b.code(outer).unwrap().ret(1);
    b.code(inner).unwrap().proto.captures = vec![CaptureSource::Capture(0), CaptureSource::Reg(0)];
    b.code(inner).unwrap().op(Opcode::GetCap, 0, 0, 0);
    b.code(inner).unwrap().op(Opcode::GetCap, 1, 1, 0);
    b.code(inner).unwrap().op(Opcode::AddI, 2, 0, 1);
    b.code(inner).unwrap().ret(2);
    assert_eq!(
        run(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
            ExecMode::Direct
        )
        .0,
        VmStep::Finished(MainOutcome::Error("43".into()))
    );
}

#[test]
fn non_tail_recursion_stops_at_meter_limit() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 2).unwrap();
    b.loadk(main, 0, ConstDesc::Func(main)).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 1, 0, 0);
    b.code(main).unwrap().ret(1);
    let p = b.finish(main).unwrap();
    let info = error(
        run(
            &p,
            VmConfig {
                max_call_stack_bytes: 10240,
                ..VmConfig::default()
            },
            HeapConfig::default(),
            ExecMode::Direct,
        )
        .0,
    );
    let frames = 10240 / (FRAME_COST + 2 * REG_COST);
    assert_eq!(
        info.stop,
        Stop::Resource(ResourceError::CallStackTooDeep { frames })
    );
    assert_eq!(u64::try_from(info.frames.len()).unwrap(), frames);
    assert_eq!(info.at, Some(InstrRef { proto: main, pc: 1 }));
}

// 関門: Rust の再帰や、末尾呼び出しで古い窓を残す誤りを、計数上限と結果で検出する。
#[test]
fn tail_calls_keep_one_frame_and_resize_both_ways() {
    for mutual in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        let small = b.proto("small", 1, 5).unwrap();
        let large = if mutual {
            b.proto("large", 1, 9).unwrap()
        } else {
            small
        };
        let count = if cfg!(miri) {
            12
        } else if mutual {
            128
        } else {
            1_000_000
        };
        b.loadk(main, 0, ConstDesc::Func(small)).unwrap();
        b.loadk_int(main, 1, count).unwrap();
        b.code(main).unwrap().op(Opcode::TailCall, 0, 0, 1);
        for (p, next) in if mutual {
            vec![(small, large), (large, small)]
        } else {
            vec![(small, small)]
        } {
            let again = b.code(p).unwrap().label("again").unwrap();
            b.loadk_int(p, 1, 0).unwrap();
            b.code(p).unwrap().op(Opcode::EqI, 2, 0, 1);
            b.code(p).unwrap().jmpf(2, again);
            b.loadk(p, 1, ConstDesc::Unit).unwrap();
            b.code(p).unwrap().ret(1);
            b.code(p).unwrap().place(again).unwrap();
            b.loadk(p, 3, ConstDesc::Func(next)).unwrap();
            b.loadk_int(p, 1, 1).unwrap();
            b.code(p).unwrap().op(Opcode::SubI, 4, 0, 1);
            b.code(p).unwrap().op(Opcode::TailCall, 0, 3, 1);
        }
        let p = b.finish(main).unwrap();
        assert_eq!(
            run(
                &p,
                VmConfig {
                    max_call_stack_bytes: 1024,
                    ..VmConfig::default()
                },
                HeapConfig::default(),
                ExecMode::Direct
            )
            .0,
            VmStep::Finished(MainOutcome::Ok)
        );
    }
}

#[test]
fn conr_matches_con_and_rejects_invalid_candidates() {
    for invalid in [0, 1, 2] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let ctor = b.ctor("Box", "Box", 8, 1).unwrap();
        b.loadk_int(main, 0, 19).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Con, 1, u16::try_from(ctor.0).unwrap(), 0);
        if invalid == 1 {
            b.loadk_int(main, 1, 0).unwrap();
        }
        if invalid == 2 {
            let pair = b.ctor("Pair", "Pair", 9, 2).unwrap();
            b.loadk_int(main, 2, 0).unwrap();
            b.loadk_int(main, 3, 0).unwrap();
            b.code(main)
                .unwrap()
                .op(Opcode::Con, 1, u16::try_from(pair.0).unwrap(), 2);
        }
        b.loadk_int(main, 0, 42).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::ConR, 1, u16::try_from(ctor.0).unwrap(), 0);
        b.code(main)
            .unwrap()
            .op(Opcode::Con, 2, u16::try_from(ctor.0).unwrap(), 0);
        b.code(main).unwrap().op(Opcode::EqV, 3, 1, 2);
        finish_value(&mut b, main, 3, Some("%Boolean.toString"));
        let step = run(
            &b.finish(main).unwrap(),
            VmConfig::default(),
            HeapConfig {
                reuse: false,
                stress: true,
                ..HeapConfig::default()
            },
            ExecMode::Direct,
        )
        .0;
        if invalid == 0 {
            assert_eq!(step, VmStep::Finished(MainOutcome::Error("true".into())));
        } else {
            assert!(matches!(error(step).stop, Stop::Internal(_)));
        }
    }
}

fn output_program(texts: &[&str]) -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 2).unwrap();
    let write = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    for text in texts {
        b.loadk(main, 0, ConstDesc::Str((*text).into())).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 1, u16::try_from(write.0).unwrap(), 0);
    }
    b.code(main).unwrap().ret(1);
    b.finish(main).unwrap()
}

// 関門: IO の停止位置と引数の保持を、外部サービスを差し替える実行の境界で守る。
#[test]
fn io_modes_write_the_same_output_and_finish_reports_sink_failure() {
    let p = output_program(&["first", "二番目"]);
    let direct = run(
        &p,
        VmConfig::default(),
        HeapConfig::default(),
        ExecMode::Direct,
    );
    let request = run(
        &p,
        VmConfig::default(),
        HeapConfig::default(),
        ExecMode::Request,
    );
    assert_eq!(direct, request);
    assert_eq!(direct.0, VmStep::Finished(MainOutcome::Ok));
    assert_eq!(
        direct.1,
        vec![
            (Stream::Stdout, b"first\n".to_vec()),
            (Stream::Stdout, "二番目\n".as_bytes().to_vec())
        ]
    );

    struct BrokenSink;
    impl std::io::Write for BrokenSink {
        fn write(&mut self, _: &[u8]) -> std::io::Result<usize> {
            Err(std::io::Error::other("broken sink"))
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let p = output_program(&[&"x".repeat(65_536)]);
    let mut vm = Vm::new(&p, VmConfig::default(), HeapConfig::default());
    vm.start_main().unwrap();
    let mut services = crate::vm::dispatch::test_support::TestIo::with_sinks(
        RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        Box::new(BrokenSink),
        Box::new(std::io::sink()),
    );
    let VmStep::Requests(ids) = vm.run(services.runtime(ExecMode::Request)) else {
        panic!("expected request");
    };
    vm.serve_request(&mut services.rt, ids[0]);
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Ok)
    );
    // 書き込みは書き出しスレッドへ渡るので、完了の確認で失敗を取り込む（R26）。
    assert!(matches!(
        services.rt.stdout.finish(),
        Err(crate::runtime::io::output::WriteFailure::Io(_))
    ));
}

fn request(vm: &mut Vm<'_>, services: &mut TestIo) -> RequestId {
    match vm.run(services.runtime(ExecMode::Request)) {
        VmStep::Requests(ids) if ids.len() == 1 => ids[0],
        other @ (VmStep::Requests(_) | VmStep::Finished(_) | VmStep::Stopped(_)) => {
            panic!("expected one request: {other:?}")
        }
    }
}

// 関門: 同じヒープの検証器と object_ids を用い、VM の根の列挙漏れと解放漏れを検出する。
#[test]
fn roots_constants_and_waiting_arguments_survive_collection() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 4).unwrap();
    let leaf = b.proto("leaf", 0, 1).unwrap();
    let string = b.constant(ConstDesc::Str("cached".into())).unwrap();
    let write = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    b.loadk_ref(main, 0, string).unwrap();
    b.loadk_ref(main, 1, string).unwrap();
    b.code(main)
        .unwrap()
        .op(Opcode::Io, 2, u16::try_from(write.0).unwrap(), 0);
    b.code(main).unwrap().op(Opcode::Concat, 3, 0, 1);
    b.loadk(main, 0, ConstDesc::Func(leaf)).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 2, 0, 0);
    b.loadk_ref(main, 0, string).unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 1, 0, 0);
    b.code(main)
        .unwrap()
        .op(Opcode::Io, 2, u16::try_from(write.0).unwrap(), 1);
    b.code(main).unwrap().ret(2);
    b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
    b.code(leaf).unwrap().ret(0);
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
    let root = vm.heap.epoch(|ctx| {
        let v = ctx.alloc_str("only root stack", "test").unwrap();
        vm.state.roots.push(ctx, v)
    });
    let mut services = io();
    let first = request(&mut vm, &mut services);
    let cached_id = vm.heap.epoch(|ctx| {
        let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
        assert!(ctx.same_object(ctx.load(&regs[0]), ctx.load(&regs[1])));
        ctx.object_id(ctx.load(&regs[0])).unwrap()
    });
    vm.serve_request(&mut services.rt, first);
    let second = request(&mut vm, &mut services);
    // 命令ごとの消去には依存せず、待つ IO の引数以外の窓を明示して空にする。
    // 定数の表・根の保存領域・待つ引数の三つだけを根にするという意図を保つ（実装プラン R16）。
    vm.heap.epoch(|ctx| {
        crate::vm::dispatch::test_support::clear_waiting_registers(&mut vm.state, ctx, &[0, 2, 3]);
        let cached = ctx.load(
            vm.state
                .constants
                .get(usize::try_from(string.0).unwrap())
                .unwrap()
                .as_ref()
                .unwrap(),
        );
        assert_eq!(ctx.object_id(cached), Some(cached_id));
        assert_eq!(ctx.str(cached), Some("cached"));
        assert_eq!(
            ctx.str(vm.state.roots.get(ctx, root).unwrap()),
            Some("only root stack")
        );
    });
    vm.heap.collect(&vm.state);
    assert_eq!(vm.heap.verify(&vm.state), Ok(()));
    vm.heap.epoch(|ctx| {
        assert_eq!(
            ctx.str(ctx.load(
                &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs[1]
            )),
            Some("cachedcached")
        );
        assert_eq!(
            ctx.str(vm.state.roots.get(ctx, root).unwrap()),
            Some("only root stack")
        );
    });
    vm.serve_request(&mut services.rt, second);
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Ok)
    );
    assert_eq!(
        services.take_output(),
        vec![
            (Stream::Stdout, b"cached\n".to_vec()),
            (Stream::Stdout, b"cachedcached\n".to_vec())
        ]
    );
    vm.heap.epoch(|ctx| vm.state.roots.truncate(ctx, 0));
    assert!(vm.heap.take_fault().is_none());
}

#[test]
fn unimplemented_and_unknown_instructions_stop_and_disassembly_lists_supported() {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 1).unwrap();
    b.loadk(main, 0, ConstDesc::Unit).unwrap();
    b.code(main).unwrap().ret(0);
    let mut p = b.finish(main).unwrap();
    let opcodes: Vec<_> = (0..=u8::MAX).filter_map(Opcode::from_u8).collect();
    let supported = |op: Opcode| {
        op.in_stage1()
            || matches!(
                op,
                Opcode::GetDict
                    | Opcode::Dict
                    | Opcode::Super
                    | Opcode::Method
                    | Opcode::TailMethod
                    | Opcode::Escape
            )
    };
    // 型クラスの命令の成功と誤値の拒否は R34 のテストが確かめる。ここに残すと、
    // 表のないプログラムを別の理由で拒んだことを、未実装の拒否と取り違える。
    // ESCAPE の成功と境界の検査は R21 のテストが確かめる。
    let stage_two: Vec<_> = opcodes
        .iter()
        .filter(|op| !supported(**op))
        .copied()
        .collect();
    for opcode in stage_two {
        p.protos[0].code[0] = Instr::abc(opcode, 0, 0, 0);
        assert!(
            matches!(
                error(
                    run(
                        &p,
                        VmConfig::default(),
                        HeapConfig::default(),
                        ExecMode::Direct
                    )
                    .0
                )
                .stop,
                Stop::Internal(_)
            ),
            "{opcode:?}"
        );
    }
    p.protos[0].code[0] = Instr(255);
    assert!(matches!(
        error(
            run(
                &p,
                VmConfig::default(),
                HeapConfig::default(),
                ExecMode::Direct
            )
            .0
        )
        .stop,
        Stop::Internal(_)
    ));
    let stage_one: Vec<_> = opcodes.into_iter().filter(|op| supported(*op)).collect();
    p.protos[0].code = stage_one
        .iter()
        .map(|op| Instr::abc(*op, 1, 2, 3))
        .collect();
    let output = crate::bytecode::disasm::disassemble(&p);
    let lines: Vec<_> = output.lines().skip(1).collect();
    assert_eq!(lines.len(), stage_one.len());
    for (line, opcode) in lines.iter().zip(stage_one) {
        assert!(line.split_whitespace().any(|word| word == opcode.name()));
    }
}

#[test]
fn recorded_heap_fault_becomes_internal_stop() {
    let p = output_program(&["unreachable"]);
    let mut foreign = Heap::new(HeapConfig::default());
    let slot = foreign.epoch(|ctx| ctx.new_slot(ctx.alloc_str("foreign", "test").unwrap()));
    let mut vm = Vm::new(&p, VmConfig::default(), HeapConfig::default());
    vm.start_main().unwrap();
    vm.heap.epoch(|ctx| {
        let _ = ctx.load(&slot);
    });
    let info = error(vm.run(io().runtime(ExecMode::Direct)));
    assert!(matches!(info.stop, Stop::Internal(_)));
    assert_eq!(info.frames.len(), 1);
    assert!(vm.state.stack.segments.is_empty());
    foreign.epoch(|ctx| ctx.discard(slot));
}

#[test]
fn budget_requests_preserve_saved_remaining_and_calls_execute_once() {
    use super::budget::{Budget, SlowPathEnd};
    let mut budget = Budget::new(9);
    assert!(budget.tick());
    budget.interrupt();
    budget.interrupt();
    assert!(!budget.tick());
    assert_eq!(budget.finish_slow(9), SlowPathEnd::Continue);
    assert_eq!(budget.remaining(), 7);
    for _ in 0..7 {
        assert!(budget.tick());
    }
    assert!(!budget.tick());
    assert_eq!(budget.finish_slow(9), SlowPathEnd::Switch);
    assert_eq!(budget.remaining(), 9);

    // 動的なリストと捕捉を、最後の使用で渡す。CALL と窓を広げる・狭める TAILCALL を
    // 通すたびに一つ加え、GC からの再開で命令が飛ばされたり二度実行されたりしないかを測る。
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let first = b.proto("first", 1, 5).unwrap();
    let large = b.proto("large", 1, 8).unwrap();
    let small = b.proto("small", 1, 4).unwrap();
    let prepend = b
        .named_builtin("List.prepend", 2, Capability::Pure, None)
        .unwrap();
    let length = b
        .named_builtin("List.length", 1, Capability::Pure, None)
        .unwrap();
    let pause = b
        .named_builtin("Benitoite.IO.Process.arguments", 0, Capability::Io, None)
        .unwrap();
    b.loadk_int(main, 0, 7).unwrap();
    b.code(main).unwrap().op(Opcode::List, 1, 0, 1);
    b.code(main).unwrap().abx(Opcode::Closure, 3, first.0);
    b.code(main).unwrap().op(Opcode::Move, 4, 1, 0);
    b.code(main).unwrap().op(Opcode::Call, 5, 3, 1);
    b.code(main)
        .unwrap()
        .op(Opcode::Prim, 6, u16::try_from(length.0).unwrap(), 5);
    finish_value(&mut b, main, 6, Some("Integer.toString"));
    b.code(first).unwrap().proto.captures = vec![CaptureSource::Reg(0)];
    b.code(first).unwrap().op(Opcode::GetCap, 1, 0, 0);
    b.code(first)
        .unwrap()
        .op(Opcode::Prim, 0, u16::try_from(prepend.0).unwrap(), 0);
    b.loadk(first, 3, ConstDesc::Func(large)).unwrap();
    b.code(first).unwrap().op(Opcode::Move, 4, 0, 0);
    b.code(first).unwrap().op(Opcode::TailCall, 0, 3, 1);
    b.loadk_int(large, 1, 8).unwrap();
    b.code(large)
        .unwrap()
        .op(Opcode::Prim, 0, u16::try_from(prepend.0).unwrap(), 0);
    b.loadk(large, 6, ConstDesc::Func(small)).unwrap();
    b.code(large).unwrap().op(Opcode::Move, 7, 0, 0);
    b.code(large).unwrap().op(Opcode::TailCall, 0, 6, 1);
    b.loadk_int(small, 1, 9).unwrap();
    b.code(small)
        .unwrap()
        .op(Opcode::Io, 2, u16::try_from(pause.0).unwrap(), 0);
    b.code(small)
        .unwrap()
        .op(Opcode::Prim, 0, u16::try_from(prepend.0).unwrap(), 0);
    b.code(small).unwrap().ret(0);
    let p = b.finish(main).unwrap();
    for proto in &p.protos {
        for (pc, instr) in proto.code.iter().enumerate() {
            if matches!(instr.opcode(), Some(Opcode::Call | Opcode::TailCall)) {
                assert!(proto.live.at(u32::try_from(pc).unwrap()).iter().any(
                    |item| matches!(item, LiveItem::LastUse { reg, .. } if *reg == instr.b() + 1)
                ));
            }
        }
    }
    let mut vm = Vm::new(
        &p,
        VmConfig {
            call_budget: 12,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut services = io();
    let id = request(&mut vm, &mut services);
    // 旧クロージャの解放による次の回収通知が、IO で中断する前に届くことがある。
    // 通知の有無にかかわらず、三回だけ数えた残りを保持していなければならない。
    let mut expected = Budget::new(9);
    if vm.state.budget.remaining() == 0 {
        expected.interrupt();
        let mut resumed = vm.state.budget;
        assert_eq!(resumed.finish_slow(12), SlowPathEnd::Continue);
        assert_eq!(resumed.remaining(), 8);
    }
    assert_eq!(vm.state.budget, expected);
    vm.serve_request(&mut services.rt, id);
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Error("4".into()))
    );
    assert!(vm.heap_stats().collections >= 3);
    assert!(vm.heap.take_fault().is_none());
}

#[test]
fn caller_registers_and_frame_function_keep_their_values_and_release_them() {
    for stop in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let captured = b.proto("captured", 0, 5).unwrap();
        let leaf = b.proto("leaf", 0, 1).unwrap();
        let write = b
            .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
            .unwrap();
        b.loadk(main, 0, ConstDesc::Str("a".into())).unwrap();
        b.code(main).unwrap().op(Opcode::Concat, 1, 0, 0);
        b.code(main).unwrap().op(Opcode::Concat, 2, 0, 0);
        b.code(main).unwrap().abx(Opcode::Closure, 3, captured.0);
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 4, u16::try_from(write.0).unwrap(), 0);
        b.code(main).unwrap().op(Opcode::Call, 5, 3, 0);
        b.code(main).unwrap().op(Opcode::Concat, 6, 2, 5);
        finish_value(&mut b, main, 6, None);
        b.code(captured).unwrap().proto.captures = vec![CaptureSource::Reg(1)];
        b.loadk(captured, 0, ConstDesc::Func(leaf)).unwrap();
        b.code(captured).unwrap().op(Opcode::Call, 1, 0, 0);
        b.code(captured).unwrap().op(Opcode::GetCap, 2, 0, 0);
        if stop {
            b.loadk_int(captured, 3, 0).unwrap();
            b.loadk_int(captured, 4, 1).unwrap();
            b.code(captured).unwrap().op(Opcode::DivI, 4, 4, 3);
        }
        b.code(captured).unwrap().ret(2);
        b.loadk(leaf, 0, ConstDesc::Unit).unwrap();
        b.code(leaf).unwrap().ret(0);
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
        let mut services = io();
        let id = request(&mut vm, &mut services);
        let owned = vm.heap.epoch(|ctx| {
            let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
            let closure = ctx.load(&regs[3]);
            [
                ctx.object_id(ctx.field(closure, 0).unwrap()).unwrap(),
                ctx.object_id(closure).unwrap(),
            ]
        });
        vm.serve_request(&mut services.rt, id);
        let step = vm.run(services.runtime(ExecMode::Request));
        if stop {
            let info = error(step);
            assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
            assert_eq!(
                info.at,
                Some(InstrRef {
                    proto: captured,
                    pc: 5
                })
            );
            assert_eq!(
                info.frames,
                vec![
                    FrameRecord {
                        proto: captured,
                        call_site: Some(InstrRef { proto: main, pc: 5 })
                    },
                    FrameRecord {
                        proto: main,
                        call_site: None
                    }
                ]
            );
        } else {
            assert_eq!(step, VmStep::Finished(MainOutcome::Error("aaaa".into())));
        }
        vm.heap.collect(&vm.state);
        for id in owned {
            assert!(!vm.heap.object_ids().contains(&id));
        }
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        assert!(vm.heap.take_fault().is_none());
    }
}

#[test]
fn dead_large_list_is_reclaimed_after_its_last_use() {
    check_dead_list_at_safepoints(if cfg!(miri) { 12 } else { 4096 });
}

/// 代表の形を小さく再利用し、通常の大きなリストの検査も残す（ADR 0318）。
pub(super) fn check_dead_list_at_safepoints(count: u16) {
    for stress in [false, true] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let leaf = b.proto("leaf", 0, 2).unwrap();
        let write = b
            .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
            .unwrap();
        let length = b
            .named_builtin("List.length", 1, Capability::Pure, None)
            .unwrap();
        let range = b
            .named_builtin("List.range", 2, Capability::Pure, None)
            .unwrap();
        // リストのセル数だけを大きくする。レジスタ数まで増やすと、ここで調べない
        // 生存解析の費用が増える（実装プラン R09「生存の情報と回収」）。
        b.loadk_int(main, 0, 0).unwrap();
        b.loadk_int(main, 1, i64::from(count)).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, 2, u16::try_from(range.0).unwrap(), 0);
        b.loadk(main, 3, ConstDesc::Str("before".into())).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 4, u16::try_from(write.0).unwrap(), 3);
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, 5, u16::try_from(length.0).unwrap(), 2);
        b.loadk(main, 3, ConstDesc::Func(leaf)).unwrap();
        b.code(main).unwrap().op(Opcode::Call, 4, 3, 0);
        finish_value(&mut b, main, 5, Some("Integer.toString"));
        b.loadk(leaf, 0, ConstDesc::Str("after".into())).unwrap();
        b.code(leaf)
            .unwrap()
            .op(Opcode::Io, 1, u16::try_from(write.0).unwrap(), 0);
        b.code(leaf).unwrap().ret(1);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig::default(),
            HeapConfig {
                stress,
                trigger_min_bytes: 1,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut services = io();
        let id = request(&mut vm, &mut services);
        let cells = vm.heap.epoch(|ctx| {
            let mut value = ctx.load(
                &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs[2],
            );
            let mut cells = vec![];
            while list::len(ctx, value).unwrap() > 0 {
                cells.push(ctx.object_id(value).unwrap());
                value = list::tail(ctx, value).unwrap().unwrap();
            }
            cells
        });
        assert_eq!(cells.len(), usize::from(count));
        vm.serve_request(&mut services.rt, id);
        // run の呼び出し前の安全点で回収した直後に確かめる。枠をすべて
        // 降ろした後の直接の collect だけでは、安全点の整理漏れを捕まえない（R16）。
        let after = request(&mut vm, &mut services);
        let remaining = vm.heap.object_ids();
        for cell in &cells {
            assert!(!remaining.contains(cell));
        }
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        vm.serve_request(&mut services.rt, after);
        assert_eq!(
            vm.run(services.runtime(ExecMode::Request)),
            VmStep::Finished(MainOutcome::Error(count.to_string()))
        );
        assert_eq!(
            services.take_output(),
            vec![
                (Stream::Stdout, b"before\n".to_vec()),
                (Stream::Stdout, b"after\n".to_vec())
            ]
        );
        if stress || cfg!(feature = "gc-stress") {
            assert!(vm.heap_stats().collections >= 2);
        }
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        assert!(vm.heap.take_fault().is_none());
    }
}

// 関門: 新しい末尾呼び出しの窓に旧値が残る三つの場合を、実際の安全点の回収で確かめる。
// 既存の回収の精度のテストは、呼び出し元の窓の再利用を含まない（R18、ADR 0314）。
#[test]
fn tail_window_old_objects_are_cleared_at_collection() {
    for size in [4, 8, 12] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let caller = b.proto("caller", 0, 8).unwrap();
        let callee = b.proto("callee", 1, size).unwrap();
        let gate = b.proto("gate", 0, 1).unwrap();
        let range = b
            .named_builtin("List.range", 2, Capability::Pure, None)
            .unwrap();
        let output = b
            .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
            .unwrap();
        let output = u16::try_from(output.0).unwrap();
        b.loadk(main, 0, ConstDesc::Func(caller)).unwrap();
        b.code(main).unwrap().op(Opcode::Call, 2, 0, 0);
        finish_value(&mut b, main, 2, None);

        b.loadk_int(caller, 0, 0).unwrap();
        b.loadk_int(caller, 1, if cfg!(miri) { 8 } else { 128 })
            .unwrap();
        b.code(caller)
            .unwrap()
            .op(Opcode::Prim, 0, u16::try_from(range.0).unwrap(), 0);
        b.loadk(caller, 3, ConstDesc::Func(callee)).unwrap();
        b.loadk(caller, 4, ConstDesc::Str("keep".into())).unwrap();
        b.code(caller).unwrap().op(Opcode::Concat, 4, 4, 4);
        b.loadk(caller, 5, ConstDesc::Str("before".into())).unwrap();
        b.code(caller).unwrap().op(Opcode::Io, 6, output, 5);
        // 最後の使用の後にも旧値が窓に残り、末尾呼び出しが引数だけを上書きする。
        b.code(caller).unwrap().op(Opcode::Move, 2, 0, 0);
        b.code(caller).unwrap().op(Opcode::Move, 7, 0, 0);
        b.code(caller).unwrap().op(Opcode::TailCall, 0, 3, 1);

        b.code(callee).unwrap().op(Opcode::Io, 1, output, 0);
        b.loadk(callee, 3, ConstDesc::Func(gate)).unwrap();
        b.code(callee).unwrap().op(Opcode::Call, 1, 3, 0);
        b.code(callee).unwrap().op(Opcode::Io, 1, output, 0);
        b.code(callee).unwrap().ret(0);
        b.loadk(gate, 0, ConstDesc::Unit).unwrap();
        b.code(gate).unwrap().ret(0);
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
        let mut services = io();
        let before = request(&mut vm, &mut services);
        let base = usize::try_from(vm.heap.epoch(|ctx| {
            crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                .segments
                .last()
                .unwrap()
                .calls
                .last()
                .unwrap()
                .base
        }))
        .unwrap();
        assert!(base > 0);
        let old = vm.heap.epoch(|ctx| {
            let mut value = ctx.load(
                &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs[base],
            );
            let mut ids = vec![];
            while list::len(ctx, value).unwrap() > 0 {
                ids.push(ctx.object_id(value).unwrap());
                value = list::tail(ctx, value).unwrap().unwrap();
            }
            ids
        });
        assert!(!old.is_empty());
        vm.serve_request(&mut services.rt, before);
        // 回収を caller の TAILCALL の前ではなく、callee の CALL の前で起こす。
        // 外部 IO の停止位置で予算を与え、本番の run の整理と回収を通す（R18）。
        vm.heap.epoch(|ctx| {
            let task = vm.state.tasks.get(ctx, vm.state.current_task).unwrap();
            ctx.host_mut::<crate::vm::task::TaskObj, _>(task, |t, _| {
                t.budget = super::budget::Budget::new(1)
            })
            .unwrap();
        });
        let reused = request(&mut vm, &mut services);
        assert_eq!(
            vm.heap.epoch(
                |ctx| crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                    .segments
                    .last()
                    .unwrap()
                    .calls
                    .last()
                    .unwrap()
                    .proto
            ),
            callee
        );
        assert_eq!(
            vm.heap.epoch(
                |ctx| crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                    .segments
                    .last()
                    .unwrap()
                    .calls
                    .last()
                    .unwrap()
                    .size
            ),
            u32::from(size)
        );
        vm.heap.epoch(|ctx| {
            let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
            assert!(matches!(ctx.load(&regs[base + 2]), Value::Unit));
            if size > 8 {
                assert!(regs[base + 8..].iter().all(Slot::is_immediate));
            }
        });
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        let collections = vm.heap_stats().collections;
        vm.serve_request(&mut services.rt, reused);
        let after = request(&mut vm, &mut services);
        assert!(vm.heap_stats().collections > collections);
        assert!(old.iter().all(|id| !vm.heap.object_ids().contains(id)));
        vm.heap.epoch(|ctx| {
            assert!(matches!(
                ctx.load(
                    &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs
                        [base + 2]
                ),
                Value::Unit
            ));
        });
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        vm.serve_request(&mut services.rt, after);
        assert_eq!(
            vm.run(services.runtime(ExecMode::Request)),
            VmStep::Finished(MainOutcome::Error("keepkeep".into()))
        );
        assert_eq!(
            services.take_output(),
            vec![
                (Stream::Stdout, b"before\n".to_vec()),
                (Stream::Stdout, b"keepkeep\n".to_vec()),
                (Stream::Stdout, b"keepkeep\n".to_vec())
            ]
        );
        assert!(vm.heap.take_fault().is_none());
    }
}

// 関門: 呼び出し元の窓が 0 以外から始まる場合に、引数と結果の旧値だけを除き、
// 呼び出しをまたぐ値を残す。既存の回収テストは未書き込みの結果の旧値を持たない。
// run が行う回収を使い、heap の計数・VM の出力・停止位置で契約を確かめる（R16）。
#[test]
fn suspended_callers_release_old_arguments_and_results_before_collection() {
    for stop in [false, true] {
        let count = if cfg!(miri) { 8 } else { 1024 };
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 16).unwrap();
        let caller = b.proto("caller", 0, 8).unwrap();
        let callee = b.proto("callee", 1, 5).unwrap();
        let gate = b.proto("gate", 0, 1).unwrap();
        let range = b
            .named_builtin("List.range", 2, Capability::Pure, None)
            .unwrap();
        let length = b
            .named_builtin("List.length", 1, Capability::Pure, None)
            .unwrap();
        let output = b
            .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
            .unwrap();
        let (range, length, output) = (
            u16::try_from(range.0).unwrap(),
            u16::try_from(length.0).unwrap(),
            u16::try_from(output.0).unwrap(),
        );
        b.loadk(main, 0, ConstDesc::Func(caller)).unwrap();
        b.code(main).unwrap().op(Opcode::Call, 2, 0, 0);
        finish_value(&mut b, main, 2, Some("Integer.toString"));

        b.loadk_int(caller, 0, 0).unwrap();
        b.loadk_int(caller, 1, count).unwrap();
        b.code(caller).unwrap().op(Opcode::Prim, 1, range, 0);
        b.loadk_int(caller, 4, 0).unwrap();
        b.loadk_int(caller, 5, count).unwrap();
        b.code(caller).unwrap().op(Opcode::Prim, 6, range, 4);
        b.loadk(caller, 7, ConstDesc::Str("keep".into())).unwrap();
        b.code(caller).unwrap().op(Opcode::Concat, 7, 7, 7);
        b.loadk(caller, 3, ConstDesc::Str("before".into())).unwrap();
        b.code(caller).unwrap().op(Opcode::Io, 2, output, 3);
        // 最初の IO 待ちでも二つのリストを生存させ、後の呼び出しで死ぬ対象を記録する。
        b.code(caller).unwrap().op(Opcode::Prim, 2, length, 6);
        b.loadk(caller, 0, ConstDesc::Func(callee)).unwrap();
        b.code(caller).unwrap().op(Opcode::Call, 6, 0, 1);
        // 回収済みのリストがあったレジスタへ新しく確保した値を上書きする（ADR 0314）。
        b.code(caller).unwrap().op(Opcode::Concat, 1, 7, 7);
        b.code(caller).unwrap().op(Opcode::Io, 2, output, 1);
        b.code(caller).unwrap().ret(6);

        b.code(callee).unwrap().op(Opcode::Prim, 0, length, 0);
        b.loadk(callee, 1, ConstDesc::Func(gate)).unwrap();
        b.code(callee).unwrap().op(Opcode::Call, 2, 1, 0);
        b.loadk(callee, 3, ConstDesc::Str("after".into())).unwrap();
        b.code(callee).unwrap().op(Opcode::Io, 4, output, 3);
        if stop {
            b.loadk_int(callee, 0, 0).unwrap();
            b.loadk_int(callee, 1, 1).unwrap();
            b.code(callee).unwrap().op(Opcode::DivI, 2, 1, 0);
        }
        b.code(callee).unwrap().ret(0);
        b.loadk(gate, 0, ConstDesc::Unit).unwrap();
        b.code(gate).unwrap().ret(0);
        let p = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &p,
            VmConfig {
                call_budget: 1,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        vm.start_main().unwrap();
        let mut services = io();
        let before = request(&mut vm, &mut services);
        let base = usize::try_from(vm.heap.epoch(|ctx| {
            crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                .segments
                .last()
                .unwrap()
                .calls
                .last()
                .unwrap()
                .base
        }))
        .unwrap();
        assert!(base > 0);
        let (old, kept) = vm.heap.epoch(|ctx| {
            let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx).segments[0].regs;
            let mut old = vec![];
            for reg in [1, 6] {
                let mut value = ctx.load(&regs[base + reg]);
                while list::len(ctx, value).unwrap() > 0 {
                    old.push(ctx.object_id(value).unwrap());
                    value = list::tail(ctx, value).unwrap().unwrap();
                }
            }
            (old, ctx.object_id(ctx.load(&regs[base + 7])).unwrap())
        });
        assert_eq!(old.len(), usize::try_from(2 * count).unwrap());
        vm.serve_request(&mut services.rt, before);
        let after = request(&mut vm, &mut services);
        let objects = vm.heap.object_ids();
        assert!(old.iter().all(|id| !objects.contains(id)));
        assert!(objects.contains(&kept));
        assert_eq!(vm.heap.verify(&vm.state), Ok(()));
        assert!(vm.heap_stats().collections > 0);
        let collections = vm.heap_stats().collections;
        vm.serve_request(&mut services.rt, after);
        if stop {
            let info = error(vm.run(services.runtime(ExecMode::Request)));
            assert_eq!(info.stop, Stop::Runtime(RuntimeError::DivisionByZero));
            assert_eq!(
                info.at,
                Some(InstrRef {
                    proto: callee,
                    pc: 7
                })
            );
            assert!(vm.heap_stats().collections > collections);
        } else {
            let overwritten = request(&mut vm, &mut services);
            vm.serve_request(&mut services.rt, overwritten);
            assert_eq!(
                vm.run(services.runtime(ExecMode::Request)),
                VmStep::Finished(MainOutcome::Error(count.to_string()))
            );
        }
        let mut expected = vec![
            (Stream::Stdout, b"before\n".to_vec()),
            (Stream::Stdout, b"after\n".to_vec()),
        ];
        if !stop {
            expected.push((Stream::Stdout, b"keepkeepkeepkeep\n".to_vec()));
        }
        assert_eq!(services.take_output(), expected);
        assert!(vm.heap.take_fault().is_none());
    }
}

fn consecutive_calls_program() -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let produce = b.proto("produce", 0, 2).unwrap();
    let consume = b.proto("consume", 1, 3).unwrap();
    let gate = b.proto("gate", 0, 1).unwrap();
    b.loadk(main, 0, ConstDesc::Func(produce)).unwrap();
    b.loadk(main, 2, ConstDesc::Func(consume)).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 3, 0, 0);
    b.code(main).unwrap().op(Opcode::Call, 1, 2, 1);
    finish_value(&mut b, main, 1, None);
    b.loadk(produce, 0, ConstDesc::Str("value".into())).unwrap();
    b.code(produce).unwrap().op(Opcode::Concat, 1, 0, 0);
    b.code(produce).unwrap().ret(1);
    b.loadk(consume, 1, ConstDesc::Func(gate)).unwrap();
    b.code(consume).unwrap().op(Opcode::Call, 2, 1, 0);
    b.code(consume).unwrap().ret(0);
    b.loadk(gate, 0, ConstDesc::Unit).unwrap();
    b.code(gate).unwrap().ret(0);
    b.finish(main).unwrap()
}

// 関門: 直前の CALL の結果は次の CALL の入口では引数である。最内側にも結果を除く
// 規則を当てる退行を、動的な文字列の出力で検出する（ADR 0314、実装プラン R16）。
#[test]
fn consecutive_calls_keep_returned_heap_arguments_at_pre_call_safepoints() {
    let p = consecutive_calls_program();
    assert_eq!(
        run(
            &p,
            VmConfig {
                call_budget: 1,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
            ExecMode::Direct
        )
        .0,
        VmStep::Finished(MainOutcome::Error("valuevalue".into()))
    );
}

// 関門: 検証器をまだ持たない VM でも、不整合な情報で窓の一部を消さない。
// 既存の正常なバイトコードでは None と空集合、昇順と範囲の検査の退行を捕まえない（R16）。
#[test]
fn invalid_safepoint_information_is_conservative_or_an_internal_stop() {
    for case in 0..5 {
        let mut p = consecutive_calls_program();
        let proto = &mut p.protos[0];
        match case {
            0 => proto.live.live_in_starts.clear(),
            1 | 2 => {
                let regs = if case == 1 { [2, 0] } else { [0, u16::MAX] };
                proto.live.live_in = regs.repeat(proto.code.len());
                proto.live.live_in_starts = (0..=proto.code.len())
                    .map(|pc| u32::try_from(2 * pc).unwrap())
                    .collect();
            }
            3 => proto.live.call_writes.fill(None),
            4 => proto.live.live_in_starts.fill(u32::MAX),
            _ => unreachable!(),
        }
        let step = run(
            &p,
            VmConfig {
                call_budget: 1,
                ..VmConfig::default()
            },
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
            ExecMode::Direct,
        )
        .0;
        if cfg!(feature = "heap-verify") {
            assert!(matches!(error(step).stop, Stop::Internal(_)), "case {case}");
        } else {
            assert_eq!(
                step,
                VmStep::Finished(MainOutcome::Error("valuevalue".into())),
                "case {case}"
            );
        }
    }
}

fn deep_returns_program(depth: i64, count: i64) -> CompiledProgram {
    let mut b = ProgramBuilder::new();
    let main = b.proto("main", 0, 16).unwrap();
    let recurse = b.proto("recurse", 1, 7).unwrap();
    let length = b
        .named_builtin("List.length", 1, Capability::Pure, None)
        .unwrap();
    let range = b
        .named_builtin("List.range", 2, Capability::Pure, None)
        .unwrap();
    let write = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    b.loadk(main, 0, ConstDesc::Func(recurse)).unwrap();
    b.loadk_int(main, 1, depth).unwrap();
    b.code(main).unwrap().op(Opcode::Call, 2, 0, 1);
    b.code(main)
        .unwrap()
        .op(Opcode::Prim, 3, u16::try_from(length.0).unwrap(), 2);
    finish_value(&mut b, main, 3, Some("Integer.toString"));
    let deeper = b.code(recurse).unwrap().label("deeper").unwrap();
    b.loadk_int(recurse, 1, 0).unwrap();
    b.code(recurse).unwrap().op(Opcode::EqI, 2, 0, 1);
    b.code(recurse).unwrap().jmpf(2, deeper);
    b.loadk_int(recurse, 0, 0).unwrap();
    b.loadk_int(recurse, 1, count).unwrap();
    b.code(recurse)
        .unwrap()
        .op(Opcode::Prim, 3, u16::try_from(range.0).unwrap(), 0);
    b.loadk(recurse, 4, ConstDesc::Str("bottom".into()))
        .unwrap();
    b.code(recurse)
        .unwrap()
        .op(Opcode::Io, 5, u16::try_from(write.0).unwrap(), 4);
    b.code(recurse).unwrap().ret(3);
    b.code(recurse).unwrap().place(deeper).unwrap();
    b.loadk(recurse, 5, ConstDesc::Func(recurse)).unwrap();
    b.loadk_int(recurse, 1, 1).unwrap();
    b.code(recurse).unwrap().op(Opcode::SubI, 6, 0, 1);
    b.code(recurse).unwrap().op(Opcode::Call, 3, 5, 1);
    b.code(recurse).unwrap().ret(3);
    b.finish(main).unwrap()
}

#[test]
fn deep_returns_collect_requested_allocations_without_rust_recursion() {
    let depth = if cfg!(miri) { 8 } else { 10_000 };
    let count = if cfg!(miri) { 12 } else { 4096 };
    let p = deep_returns_program(depth, count);
    let mut vm = Vm::new(
        &p,
        VmConfig::default(),
        HeapConfig {
            trigger_min_bytes: 1,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut services = io();
    let id = request(&mut vm, &mut services);
    assert!(vm.heap_stats().collections > 0);
    let before = vm.heap_stats().collections;
    vm.serve_request(&mut services.rt, id);
    let before_bytes = vm
        .heap_stats()
        .live_bytes
        .saturating_mul(2)
        .saturating_add(1024);
    // IO 待ちでの回収の後に、深い戻りの列へ新しい回収要求を持ち込む。
    vm.heap.epoch(|ctx| {
        ctx.alloc_str(&"x".repeat(usize::try_from(before_bytes).unwrap()), "test")
            .unwrap();
    });
    assert!(vm.heap.collect_requested());
    assert_eq!(
        vm.run(services.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Error(count.to_string()))
    );
    assert!(vm.heap_stats().collections > before);
    assert!(vm.heap.take_fault().is_none());
}

// 関門: 12 個の動的な引数を通常呼び出しと重なる末尾呼び出しで渡し、回収後の順序を守る。
// 既存の末尾呼び出しは引数一つであり、未読の写し元を消す誤りと多引数の経路を捕まえない。
// 組み立てから VM の出力まで確かめ、専用の公開 API を加えない（実装プラン R15）。
#[test]
fn overlapping_tail_arguments_preserve_many_heap_values_in_order() {
    // 関門: 小さい作業領域と全レジスタを覆う作業領域の双方で、重なる窓から
    // 未読の引数を失う退行を、VM の結果と回収の強制で検出する。
    for arity in [12_u16, 128] {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, arity + 8).unwrap();
        let forward = b.proto("forward", arity, arity + 4).unwrap();
        let join = b.proto("join", arity, arity + 2).unwrap();
        let separator = arity + 3;
        let temporary = arity + 4;
        let result = arity + 2;
        b.loadk(main, 0, ConstDesc::Func(forward)).unwrap();
        b.loadk(main, separator, ConstDesc::Str("!".into()))
            .unwrap();
        for i in 0..arity {
            b.loadk(main, temporary, ConstDesc::Str(i.to_string()))
                .unwrap();
            b.code(main)
                .unwrap()
                .op(Opcode::Concat, i + 1, temporary, separator);
        }
        b.code(main).unwrap().op(Opcode::Call, result, 0, arity);
        finish_value(&mut b, main, result, None);
        // 一つ後ろへ並べ直した写し元と、先頭からの写し先が重なる。新しい窓も小さくなる。
        for i in (0..arity).rev() {
            b.code(forward).unwrap().op(Opcode::Move, i + 1, i, 0);
        }
        b.loadk(forward, 0, ConstDesc::Func(join)).unwrap();
        b.code(forward).unwrap().op(Opcode::TailCall, 0, 0, arity);
        b.code(join).unwrap().op(Opcode::Concat, arity, 0, 1);
        for i in 2..arity {
            b.code(join).unwrap().op(Opcode::Concat, arity, arity, i);
        }
        b.code(join).unwrap().ret(arity);
        let program = b.finish(main).unwrap();
        let expected = (0..arity).map(|i| format!("{i}!")).collect::<String>();
        assert_eq!(
            run(
                &program,
                VmConfig {
                    call_budget: 1,
                    ..VmConfig::default()
                },
                HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                ExecMode::Direct
            )
            .0,
            VmStep::Finished(MainOutcome::Error(expected))
        );
    }
}
