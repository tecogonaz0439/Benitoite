//! 検証器の受理・拒否を、コード生成したゴールデンテストのプログラムで確かめる
//! （設計書 02-08「実行の手順」）。

// 変異の準備は添字と算術で記述し、検証器の失敗はテストの panic にする。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::path::{Path, PathBuf};
use std::sync::Arc;

use benitoite::bytecode::instr::{Instr, Opcode};
use benitoite::bytecode::program::{CompiledProgram, ConstIdx, ProtoIdx};
use benitoite::bytecode::verify::verify;
use benitoite::pipeline::{self, CheckOptions};

fn scripts() -> Vec<PathBuf> {
    let mut pending = vec![PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("testdata")];
    let mut paths = Vec::new();
    while let Some(dir) = pending.pop() {
        for entry in std::fs::read_dir(dir).unwrap() {
            let entry = entry.unwrap();
            let path = entry.path();
            let name = entry.file_name();
            let name = name.to_string_lossy();
            if entry.file_type().unwrap().is_dir() {
                if name.ends_with(".files") || name.ends_with(".formatted") {
                    continue;
                }
                if path.with_extension("mode").is_file() {
                    paths.push(path);
                } else {
                    pending.push(path);
                }
            } else if path.extension().is_some_and(|e| e == "bnt") {
                paths.push(path);
            }
        }
    }
    paths.sort();
    paths
}

fn compile(path: &Path) -> Option<CompiledProgram> {
    let checked = pipeline::check_path(
        path,
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    )
    .ok()?;
    let checked_program = checked.program?;
    let core = pipeline::desugar_checked(&checked_program).unwrap();
    match pipeline::compile(&core, checked.sources) {
        Ok(program) => Some(program),
        // 期待した処理系の制限では命令を作らないので、検証器の入力にならない。
        Err(pipeline::CompileError::Limit(_))
            if std::fs::read_to_string(path.with_extension("exit"))
                .is_ok_and(|s| s.trim() == "2")
                && std::fs::read_to_string(path.with_extension("diag.json")).is_ok_and(|s| {
                    s.lines().any(|line| {
                        serde_json::from_str::<serde_json::Value>(line)
                            .ok()
                            .is_some_and(|d| {
                                d.get("code")
                                    .and_then(|c| c.as_str())
                                    .is_some_and(|c| c.starts_with('L'))
                            })
                    })
                }) =>
        {
            None
        }
        Err(error) => panic!("{}: compilation failed: {error:?}", path.display()),
    }
}

fn copy(p: &CompiledProgram) -> CompiledProgram {
    CompiledProgram {
        protos: p.protos.clone(),
        consts: p.consts.clone(),
        top_fns: p.top_fns.clone(),
        ctors: p.ctors.clone(),
        traits: p.traits.clone(),
        impls: p.impls.clone(),
        ops: p.ops.clone(),
        builtins: p.builtins.clone(),
        externals: p.externals.clone(),
        handlers: p.handlers.clone(),
        main: p.main,
        main_kind: p.main_kind,
        sources: Arc::clone(&p.sources),
    }
}

fn random(seed: &mut u64, bound: usize) -> usize {
    *seed ^= *seed << 13;
    *seed ^= *seed >> 7;
    *seed ^= *seed << 17;
    usize::try_from(*seed % u64::try_from(bound).unwrap()).unwrap()
}

// 関門: verify の見落としが、正しく生成した命令の範囲外の変異を受け付ける退行を捕まえる。
// 手書きの表では捕まらない生成結果との不整合を、実際のパイプラインで確かめる。
// 命令を拒む位置も確かめ、別の位置や位置なしで報告する退行を捕まえる。
#[test]
fn golden_programs_and_seeded_single_site_mutations() {
    let mut seed = 0x32_b017_5eed_0263_u64;
    let (mut programs, mut mutations, mut rejected, mut accepted) = (0, 0, 0, 0);
    for path in scripts() {
        let Some(original) = compile(&path) else {
            continue;
        };
        assert_eq!(verify(&original), Ok(()), "{}", path.display());
        programs += 1;
        // 各プログラムで別々の原型と命令を選ぶ。最低限の範囲外の変異と任意の
        // オペランドの変異を分け、後者の拒否を前者の保証と取り違えない。
        for kind in 0..10 {
            let mut changed = copy(&original);
            let pi = random(&mut seed, changed.protos.len());
            let pc = random(&mut seed, changed.protos[pi].code.len());
            let proto = &mut changed.protos[pi];
            let instr = proto.code[pc];
            let mut must_reject = true;
            match kind {
                0 => proto.code[pc] = Instr((instr.0 & !255) | 255),
                1 => proto.code[pc] = Instr::asbx(Opcode::Jmp, 0, i32::MAX),
                2 => proto.code[pc] = Instr::abx(Opcode::LoadK, 0, u32::MAX),
                3 => {
                    proto.positions.pop();
                }
                4 => proto.live.starts[0] = 1,
                5 => {
                    proto.method_traits.pop();
                }
                6 => proto.code[pc] = Instr::abc(Opcode::Move, proto.num_regs, 0, 0),
                7 => {
                    let operand = random(&mut seed, 3);
                    let shift = [8, 24, 40][operand];
                    let bound = usize::from(proto.num_regs).saturating_add(2);
                    let mut value = u64::try_from(random(&mut seed, bound)).unwrap();
                    if value == (instr.0 >> shift) & 0xffff {
                        value = (value + 1) % u64::try_from(bound).unwrap();
                    }
                    proto.code[pc] = Instr((instr.0 & !(0xffff << shift)) | (value << shift));
                    must_reject = false;
                }
                8 => {
                    let mut byte = u64::try_from(random(&mut seed, 256)).unwrap();
                    if byte == instr.0 & 255 {
                        byte = (byte + 1) % 256;
                    }
                    proto.code[pc] = Instr((instr.0 & !255) | byte);
                    must_reject = false;
                }
                9 => {
                    if proto.consts.is_empty() {
                        proto.live.live_in_starts[0] = 1;
                    } else {
                        let index = random(&mut seed, proto.consts.len());
                        proto.consts[index] = ConstIdx(u32::MAX);
                    }
                }
                _ => unreachable!(),
            }
            mutations += 1;
            match verify(&changed) {
                Err(error) => {
                    if matches!(kind, 0 | 1 | 2 | 6) {
                        // 命令だけの差し替えは表の長さを変えず、先に検査する原型と命令も元のままである。
                        // 壊した命令で最初の誤りが出るため、表を変える場合と違い、原型と命令の位置を特定できる。
                        let expected_proto = ProtoIdx(u32::try_from(pi).unwrap());
                        let expected_pc = u32::try_from(pc).unwrap();
                        assert_eq!(
                            (error.proto, error.pc),
                            (expected_proto, Some(expected_pc)),
                            "incorrect mutation error location: {}, kind {kind}, expected proto {expected_proto:?}, pc {expected_pc}: {error:?}",
                            path.display()
                        );
                    }
                    rejected += 1;
                }
                Ok(()) => {
                    assert!(
                        !must_reject,
                        "accepted invalid mutation: {}, proto {pi}, pc {pc}, kind {kind}",
                        path.display()
                    );
                    accepted += 1;
                }
            }
        }
    }
    assert!(programs > 100, "golden programs: {programs}");
    assert_eq!(rejected + accepted, mutations);
    eprintln!(
        "verify corpus: programs={programs}, mutations={mutations}, rejected={rejected}, accepted={accepted}"
    );
}

// 関門: 上限検査を持つ純粋な合成が失敗した場合に set へ進まない、コアの
// 評価順とデータ依存を確かめる。巨大な値や本番に不要な上限の差し替え口は作らない。
#[test]
fn builder_sets_depend_on_successful_size_checked_combination() {
    use benitoite::ir::core_ir::{CompKind, ValKind};
    for (class, annotation, parameter, operation, combine) in [
        (
            "ListBuilder",
            "ListBuilder[Integer]",
            "Integer",
            "append(builder: b, value: value)",
            "List.append",
        ),
        (
            "ListBuilder",
            "ListBuilder[Integer]",
            "List[Integer]",
            "appendAll(builder: b, values: value)",
            "List.concatenate",
        ),
        (
            "BytesBuilder",
            "BytesBuilder",
            "Byte",
            "append(builder: b, value: value)",
            "Bytes.concatenate",
        ),
        (
            "BytesBuilder",
            "BytesBuilder",
            "Bytes",
            "appendAll(builder: b, bytes: value)",
            "Bytes.concatenate",
        ),
    ] {
        let source = format!(
            "import Benitoite.{class}\nfunction append(value: {parameter}) -> Unit uses State\n bind b: {annotation} <- {class}.new()\n {class}.{operation}\nend function\n"
        );
        let checked = pipeline::check_text(
            "builder-order.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
        assert!(benitoite::ir::check::check_program(&core).is_empty());
        let def = core.defs.iter().find(|d| d.name == "append").unwrap();
        let mut calls = Vec::new();
        let mut pending = vec![(&def.body, None)];
        while let Some((comp, result)) = pending.pop() {
            match &comp.kind {
                CompKind::Let { var, bound, body } => {
                    pending.push((body, result));
                    pending.push((bound, Some(var.id)));
                }
                CompKind::App { func, args, .. } => {
                    if let ValKind::Builtin { id, .. } = &func.kind {
                        calls.push((
                            benitoite::builtins::table::builtin_decl(*id).unwrap().name,
                            result,
                            args,
                        ));
                    }
                }
                CompKind::Return(_) | CompKind::Escape(_) => {}
                other @ (CompKind::Method(_)
                | CompKind::If { .. }
                | CompKind::Match { .. }
                | CompKind::Use { .. }
                | CompKind::Lazy { .. }
                | CompKind::Handle(_)
                | CompKind::Resume { .. }) => panic!("unexpected control flow: {other:?}"),
            }
        }
        let get = calls
            .iter()
            .position(|(name, _, _)| *name == "Reference.get")
            .unwrap();
        let combine = calls
            .iter()
            .position(|(name, _, _)| *name == combine)
            .unwrap();
        let set = calls
            .iter()
            .position(|(name, _, _)| *name == "Reference.set")
            .unwrap();
        assert!(
            get < combine && combine < set,
            "{class}/{operation}: {calls:?}"
        );
        let next = calls[combine].1.unwrap();
        assert!(
            matches!(calls[set].2[1].kind, ValKind::Var(id) if id == next),
            "{class}/{operation}: {calls:?}"
        );
        if class == "BytesBuilder" && parameter == "Byte" {
            let fragment = calls
                .iter()
                .position(|(name, _, _)| *name == "Bytes.fromList")
                .unwrap();
            assert!(get < fragment && fragment < combine);
            assert!(matches!(&calls[fragment].2[0].kind, ValKind::List(xs) if xs.len() == 1));
        }
        let compiled = pipeline::compile(&core, checked.sources).unwrap();
        assert!(verify(&compiled).is_ok());
    }
}
