//! Decimal と Byte の命令（設計書 01-04、02-08「値の表現」、実装プラン 10-07「算術」「比較」）。

use super::{Instr, NoGcCtx, Slot, Stop, Value, missing, operators, read_one};
use crate::base::Decimal;

pub(super) fn constant<'e>(
    ctx: &NoGcCtx<'e>,
    mantissa: i128,
    scale: u8,
) -> Result<Value<'e>, Stop> {
    let d = Decimal::new(mantissa, scale).ok_or_else(|| missing("invalid Decimal constant"))?;
    Ok(ctx.alloc_decimal(d))
}

fn decimal_pair<'e>(
    window: &mut [Slot],
    ctx: &NoGcCtx<'e>,
    instr: Instr,
) -> Result<[Decimal; 2], Stop> {
    let [a, b] = super::read_pair(ctx, window, instr.b(), instr.c())?;
    Ok([
        ctx.decimal(a)
            .ok_or_else(|| missing("Decimal operand required"))?,
        ctx.decimal(b)
            .ok_or_else(|| missing("Decimal operand required"))?,
    ])
}

/// 単項の Decimal 演算を行う。種類の判定は呼び出し元の振り分けだけで行う。
#[inline(never)]
pub(super) fn negate<'e>(
    window: &mut [Slot],
    ctx: &NoGcCtx<'e>,
    instr: Instr,
) -> Result<Value<'e>, Stop> {
    let value = read_one(ctx, window, instr.b())?;
    let d = ctx
        .decimal(value)
        .ok_or_else(|| missing("Decimal operand required"))?;
    Ok(ctx.alloc_decimal(d.negate()))
}

/// 振り分けで選んだ Decimal の算術を、確保せずに読んだ被演算子へ適用する。
#[inline(never)]
pub(super) fn arithmetic<'e>(
    window: &mut [Slot],
    ctx: &NoGcCtx<'e>,
    instr: Instr,
    operation: impl FnOnce(Decimal, Decimal) -> Result<Decimal, crate::base::decimal::DecimalError>,
) -> Result<Value<'e>, Stop> {
    let [a, b] = decimal_pair(window, ctx, instr)?;
    let result = operation(a, b).map_err(operators::decimal_error)?;
    Ok(ctx.alloc_decimal(result))
}

/// 振り分けで選んだ Decimal の比較を行う。
#[inline(never)]
pub(super) fn compare<'e>(
    window: &mut [Slot],
    ctx: &NoGcCtx<'e>,
    instr: Instr,
    operation: impl FnOnce(std::cmp::Ordering) -> bool,
) -> Result<Value<'e>, Stop> {
    let [a, b] = decimal_pair(window, ctx, instr)?;
    Ok(Value::Bool(operation(a.cmp_num(b))))
}

#[cfg(test)]
mod tests {
    // 関門: 命令の振り分け、被演算子の読み出し、停止位置、回収後の結果と定数の共有を守る。
    // base と組み込みの本体のテストは VM のレジスタや安全点を通らない。
    // 本番の API を増やさず、R05 の組み立てから VM の結果まで確かめる（実装プラン R35）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::base::decimal::MAX_MANTISSA;
    use crate::builtins::iface::Capability;
    use crate::builtins::table::tags;
    use crate::bytecode::asm::ProgramBuilder;
    use crate::bytecode::instr::Opcode;
    use crate::bytecode::program::{CompiledProgram, ConstDesc, MainKind, ProtoIdx};
    use crate::runtime::RuntimeError;
    use crate::runtime::heap::HeapConfig;
    use crate::runtime::io::services::RunInput;
    use crate::vm::dispatch::test_support::TestIo;
    use crate::vm::{ExecMode, InstrRef, MainOutcome, StopEnd, StopReason, Vm, VmConfig, VmStep};

    fn desc(text: &str) -> ConstDesc {
        let (text, negative) = text.strip_prefix('-').map_or((text, false), |s| (s, true));
        let d = Decimal::parse_literal(text).unwrap();
        ConstDesc::Decimal {
            mantissa: if negative {
                -d.mantissa()
            } else {
                d.mantissa()
            },
            scale: d.scale(),
        }
    }

    fn finish(b: &mut ProgramBuilder, main: ProtoIdx, reg: u16, conversion: &str) {
        let reference = b
            .named_builtin(conversion, 1, Capability::Pure, None)
            .unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Prim, reg, u16::try_from(reference.0).unwrap(), reg);
        b.program.main_kind = MainKind::Result;
        let ctor = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Con, reg, u16::try_from(ctor.0).unwrap(), reg);
        b.code(main).unwrap().ret(reg);
    }

    fn run(program: &CompiledProgram, stress: bool) -> VmStep {
        let mut vm = Vm::new(
            program,
            VmConfig::default(),
            HeapConfig {
                stress,
                ..HeapConfig::default()
            },
        );
        let mut io = TestIo::new(RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        });
        vm.start_main().unwrap();
        let step = vm.run(io.runtime(ExecMode::Direct));
        assert!(vm.heap.take_fault().is_none());
        step
    }

    fn operation(
        opcode: Opcode,
        a: ConstDesc,
        b: ConstDesc,
        conversion: &str,
        builtin: Option<&str>,
    ) -> CompiledProgram {
        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 0, 4).unwrap();
        builder.loadk(main, 0, a).unwrap();
        builder.loadk(main, 1, b).unwrap();
        if let Some(name) = builtin {
            let reference = builder
                .named_builtin(name, 2, Capability::Pure, None)
                .unwrap();
            builder
                .code(main)
                .unwrap()
                .op(Opcode::Prim, 2, u16::try_from(reference.0).unwrap(), 0);
        } else {
            builder.code(main).unwrap().op(opcode, 2, 0, 1);
        }
        // 確保した結果の後に安全点を通し、回収後に変換へ渡す（10-09）。
        let target = builder.code(main).unwrap().label("after_numeric").unwrap();
        builder.code(main).unwrap().jmp(target);
        builder.code(main).unwrap().place(target).unwrap();
        finish(&mut builder, main, 2, conversion);
        builder.finish(main).unwrap()
    }

    #[test]
    fn decimal_and_byte_instructions_produce_language_results_after_collection() {
        for (opcode, a, b, expected) in [
            (Opcode::AddD, "1.20", "2.0", "3.20"),
            (Opcode::SubD, "1.20", "2.0", "-0.80"),
            (Opcode::MulD, "1.20", "2.0", "2.400"),
            (Opcode::DivD, "1.20", "2.0", "0.6"),
            (Opcode::NegD, "1.20", "0", "-1.20"),
            (Opcode::EqD, "1.0", "1.00", "true"),
            (Opcode::EqD, "1", "2", "false"),
            (Opcode::LtD, "-1", "1", "true"),
            (Opcode::LtD, "1.0", "1.00", "false"),
            (Opcode::LtD, "2", "1", "false"),
            (Opcode::LeD, "-1", "1", "true"),
            (Opcode::LeD, "1.0", "1.00", "true"),
            (Opcode::LeD, "2", "1", "false"),
        ] {
            let comparison = matches!(opcode, Opcode::EqD | Opcode::LtD | Opcode::LeD);
            let program = operation(
                opcode,
                desc(a),
                desc(b),
                if comparison {
                    "%Boolean.toString"
                } else {
                    "Decimal.toString"
                },
                None,
            );
            for stress in [false, true] {
                assert_eq!(
                    run(&program, stress),
                    VmStep::Finished(MainOutcome::Error(expected.into())),
                    "{opcode:?}"
                );
            }
        }
        for opcode in [Opcode::EqBt, Opcode::LtBt, Opcode::LeBt] {
            for (a, b) in [(0, 255), (255, 255), (255, 0)] {
                let expected = if opcode == Opcode::EqBt {
                    a == b
                } else if opcode == Opcode::LtBt {
                    a < b
                } else {
                    a <= b
                };
                let p = operation(
                    opcode,
                    ConstDesc::Byte(a),
                    ConstDesc::Byte(b),
                    "%Boolean.toString",
                    None,
                );
                assert_eq!(
                    run(&p, true),
                    VmStep::Finished(MainOutcome::Error(expected.to_string()))
                );
            }
        }
        // 同じレジスタを二度読む前に結果を書き、被演算子を壊す誤りを捕まえる。
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 2).unwrap();
        b.loadk(main, 0, desc("1.50")).unwrap();
        b.code(main).unwrap().op(Opcode::AddD, 0, 0, 0);
        b.code(main).unwrap().op(Opcode::NegD, 0, 0, 0);
        finish(&mut b, main, 0, "Decimal.toString");
        assert_eq!(
            run(&b.finish(main).unwrap(), true),
            VmStep::Finished(MainOutcome::Error("-3.00".into()))
        );
    }

    #[test]
    fn numeric_errors_stop_at_the_faulting_instruction_and_match_builtins() {
        let max = MAX_MANTISSA.to_string();
        for (opcode, name, b, reason) in [
            (
                Opcode::AddD,
                "%Decimal.add",
                "1",
                RuntimeError::DecimalOverflow,
            ),
            (
                Opcode::SubD,
                "%Decimal.subtract",
                "-1",
                RuntimeError::DecimalOverflow,
            ),
            (
                Opcode::MulD,
                "%Decimal.multiply",
                "2",
                RuntimeError::DecimalOverflow,
            ),
            (
                Opcode::DivD,
                "%Decimal.divide",
                "0.1",
                RuntimeError::DecimalOverflow,
            ),
            (
                Opcode::DivD,
                "%Decimal.divide",
                "0.0",
                RuntimeError::DivisionByZero,
            ),
        ] {
            for builtin in [None, Some(name)] {
                let p = operation(opcode, desc(&max), desc(b), "Decimal.toString", builtin);
                for stress in [false, true] {
                    let VmStep::Stopped(StopEnd {
                        reason: StopReason::Error(info),
                        release_failures,
                    }) = run(&p, stress)
                    else {
                        panic!("expected stop");
                    };
                    assert!(release_failures.is_empty());
                    assert_eq!(info.stop, Stop::Runtime(reason.clone()));
                    assert_eq!(
                        info.at,
                        Some(InstrRef {
                            proto: p.main.unwrap(),
                            pc: 2
                        })
                    );
                }
            }
        }
        for builtin in [None, Some("%Decimal.add")] {
            let p = operation(
                Opcode::AddD,
                desc("1.20"),
                desc("2.0"),
                "Decimal.toString",
                builtin,
            );
            assert_eq!(
                run(&p, true),
                VmStep::Finished(MainOutcome::Error("3.20".into()))
            );
        }
        for opcode in [
            Opcode::AddD,
            Opcode::SubD,
            Opcode::MulD,
            Opcode::DivD,
            Opcode::NegD,
            Opcode::EqD,
            Opcode::LtD,
            Opcode::LeD,
            Opcode::EqBt,
            Opcode::LtBt,
            Opcode::LeBt,
        ] {
            let p = operation(
                opcode,
                ConstDesc::Int(1),
                ConstDesc::Int(1),
                "Decimal.toString",
                None,
            );
            let VmStep::Stopped(StopEnd {
                reason: StopReason::Error(info),
                ..
            }) = run(&p, true)
            else {
                panic!("expected internal stop");
            };
            assert!(matches!(info.stop, Stop::Internal(_)));
            assert_eq!(
                info.at,
                Some(InstrRef {
                    proto: p.main.unwrap(),
                    pc: 2
                })
            );
        }
    }

    #[test]
    fn decimal_constant_is_cached_across_collection_and_invalid_descriptions_stop() {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 4).unwrap();
        let decimal = b.constant(desc("1.00")).unwrap();
        b.loadk_ref(main, 0, decimal).unwrap();
        let target = b.code(main).unwrap().label("second_load").unwrap();
        b.code(main).unwrap().jmp(target);
        b.code(main).unwrap().place(target).unwrap();
        b.loadk_ref(main, 1, decimal).unwrap();
        b.loadk(main, 2, ConstDesc::Str("waiting".into())).unwrap();
        let output = b
            .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
            .unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 3, u16::try_from(output.0).unwrap(), 2);
        b.code(main).unwrap().op(Opcode::EqD, 2, 0, 1);
        finish(&mut b, main, 2, "%Boolean.toString");
        let program = b.finish(main).unwrap();
        let mut vm = Vm::new(
            &program,
            VmConfig::default(),
            HeapConfig {
                stress: true,
                ..HeapConfig::default()
            },
        );
        let mut io = TestIo::new(RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        });
        vm.start_main().unwrap();
        let VmStep::Requests(ids) = vm.run(io.runtime(ExecMode::Request)) else {
            panic!("expected waiting IO");
        };
        vm.heap.collect(&vm.state);
        vm.heap.epoch(|ctx| {
            let regs = &crate::vm::dispatch::test_support::stack(&vm.state, ctx)
                .segments
                .last()
                .unwrap()
                .regs;
            assert!(ctx.same_object(ctx.load(&regs[0]), ctx.load(&regs[1])));
            assert!(
                ctx.same_object(
                    ctx.load(&regs[0]),
                    ctx.load(
                        vm.state
                            .constants
                            .get(usize::try_from(decimal.0).unwrap())
                            .unwrap()
                            .as_ref()
                            .unwrap()
                    )
                )
            );
            assert_eq!(ctx.decimal(ctx.load(&regs[0])).unwrap().to_text(), "1.00");
        });
        for id in ids {
            vm.serve_request(&mut io.rt, id);
        }
        assert_eq!(
            vm.run(io.runtime(ExecMode::Request)),
            VmStep::Finished(MainOutcome::Error("true".into()))
        );
        assert!(vm.heap.take_fault().is_none());
        for (mantissa, scale) in [(MAX_MANTISSA + 1, 0), (0, 29)] {
            let mut b = ProgramBuilder::new();
            let main = b.proto("main", 0, 2).unwrap();
            b.loadk(main, 0, ConstDesc::Decimal { mantissa, scale })
                .unwrap();
            finish(&mut b, main, 0, "Decimal.toString");
            let p = b.finish(main).unwrap();
            let VmStep::Stopped(StopEnd {
                reason: StopReason::Error(info),
                ..
            }) = run(&p, true)
            else {
                panic!("expected internal stop");
            };
            assert!(matches!(info.stop, Stop::Internal(_)));
            assert_eq!(
                info.at,
                Some(InstrRef {
                    proto: p.main.unwrap(),
                    pc: 0
                })
            );
        }
    }
}
