//! マップと集合の定数の組み立て（設計書 02-07「定数表」、ADR 0136）。

use crate::runtime::heap::{Value, ValueCtx};
use crate::runtime::{Stop, map};

pub(super) fn map_constant<'e>(ctx: &ValueCtx<'e>, args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
    let (chunks, remainder) = args.as_chunks::<2>();
    if !remainder.is_empty() {
        return Err(invalid());
    }
    let pairs: Vec<_> = chunks.iter().map(|&[key, value]| (key, value)).collect();
    map::map_from_sorted(ctx, &pairs, "LOADK")
}
pub(super) fn set_constant<'e>(ctx: &ValueCtx<'e>, args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
    map::set_from_sorted(ctx, args, "LOADK")
}
fn invalid() -> Stop {
    Stop::Internal("map constant pair is incomplete".into())
}

#[cfg(test)]
mod tests {
    // 関門: LOADK が子を鍵・値の順に接続し、回収後にも定数を共有する契約。
    // runtime::map のテストでは定数の子の平坦化と根の表の漏れを捕まえられない。
    // 手で組んだバイトコードを VM の入口から実行し、公開の口を増やさない（R37）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::builtins::iface::Capability;
    use crate::bytecode::{asm::ProgramBuilder, instr::Opcode, program::ConstDesc};
    use crate::runtime::{heap::HeapConfig, io::services::RunInput};
    use crate::vm::dispatch::test_support::TestIo;
    use crate::vm::{ExecMode, MainOutcome, Vm, VmConfig, VmStep};

    #[test]
    fn loadk_builds_nested_sorted_collections_and_caches_them_across_collection() {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 8).unwrap();
        let one = b.constant(ConstDesc::Int(1)).unwrap();
        let two = b.constant(ConstDesc::Int(2)).unwrap();
        let text = b.constant(ConstDesc::Str("one".into())).unwrap();
        let set = b.constant(ConstDesc::Set(vec![one, two])).unwrap();
        let map = b
            .constant(ConstDesc::Map(vec![(one, text), (two, set)]))
            .unwrap();
        let empty_map = b.constant(ConstDesc::Map(vec![])).unwrap();
        let empty_set = b.constant(ConstDesc::Set(vec![])).unwrap();
        b.loadk_ref(main, 0, map).unwrap();
        b.loadk_ref(main, 2, set).unwrap();
        let target = b.code(main).unwrap().label("second_load").unwrap();
        b.code(main).unwrap().jmp(target);
        b.code(main).unwrap().place(target).unwrap();
        b.loadk_ref(main, 1, map).unwrap();
        b.loadk_ref(main, 3, set).unwrap();
        b.loadk_ref(main, 4, empty_map).unwrap();
        b.loadk_ref(main, 7, empty_set).unwrap();
        b.loadk(main, 5, ConstDesc::Str("waiting".into())).unwrap();
        let output = b
            .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
            .unwrap();
        b.code(main)
            .unwrap()
            .op(Opcode::Io, 6, u16::try_from(output.0).unwrap(), 5);
        // 待つ前のレジスタを後で使い、生存解析が回収前に消さないようにする。
        b.code(main).unwrap().op(Opcode::EqV, 6, 0, 1);
        b.code(main).unwrap().op(Opcode::EqV, 6, 2, 3);
        b.code(main).unwrap().op(Opcode::Move, 5, 4, 0);
        b.code(main).unwrap().op(Opcode::Move, 5, 7, 0);
        b.loadk(main, 7, ConstDesc::Unit).unwrap();
        b.code(main).unwrap().ret(7);
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
            let m = ctx.load(&regs[0]);
            let s = ctx.load(&regs[2]);
            assert!(ctx.same_object(m, ctx.load(&regs[1])));
            assert!(ctx.same_object(s, ctx.load(&regs[3])));
            assert!(
                ctx.same_object(
                    m,
                    ctx.load(
                        vm.state
                            .constants
                            .get(usize::try_from(map.0).unwrap())
                            .unwrap()
                            .as_ref()
                            .unwrap()
                    )
                )
            );
            assert!(
                ctx.same_object(
                    s,
                    ctx.load(
                        vm.state
                            .constants
                            .get(usize::try_from(set.0).unwrap())
                            .unwrap()
                            .as_ref()
                            .unwrap()
                    )
                )
            );
            let pairs = crate::runtime::map::map_to_vec(ctx, m).unwrap();
            assert_eq!(
                pairs
                    .iter()
                    .map(|(k, _)| k.as_int().unwrap())
                    .collect::<Vec<_>>(),
                vec![1, 2]
            );
            assert_eq!(ctx.str(pairs[0].1), Some("one"));
            assert!(ctx.same_object(pairs[1].1, s));
            assert_eq!(
                crate::runtime::map::set_to_vec(ctx, s)
                    .unwrap()
                    .iter()
                    .map(|v| v.as_int().unwrap())
                    .collect::<Vec<_>>(),
                vec![1, 2]
            );
            assert!(matches!(ctx.load(&regs[4]), Value::EmptyMap));
            assert!(matches!(ctx.load(&regs[7]), Value::EmptySet));
        });
        for id in ids {
            vm.serve_request(&mut io.rt, id);
        }
        assert_eq!(
            vm.run(io.runtime(ExecMode::Request)),
            VmStep::Finished(MainOutcome::Ok)
        );
        assert!(vm.heap.take_fault().is_none());
    }
}
