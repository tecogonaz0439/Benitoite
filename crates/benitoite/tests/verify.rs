//! 検証器の受理・拒否を、コード生成したゴールデンテストのプログラムで確かめる
//! （設計書 02-08「実行の手順」、ADR 0263、実装プラン R32）。

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
use benitoite::bytecode::program::{CompiledProgram, ConstIdx};
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
    Some(pipeline::compile(&core, checked.sources).unwrap())
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
                Err(_) => rejected += 1,
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
