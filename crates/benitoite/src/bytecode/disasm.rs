//! 命令とオペランドの表示（設計書 02-07「命令」、実装プラン 10-07）。

use super::instr::Opcode;
use super::program::CompiledProgram;

/// コンパイル済みプログラムを、原型ごとに命令を一行ずつ並べた文字列にする。
/// 各行は命令の位置、命令の名前（`Opcode::name`）、オペランドを示す。形式はテストで比べない。
pub fn disassemble(program: &CompiledProgram) -> String {
    use std::fmt::Write;
    let mut out = String::new();
    for (i, proto) in program.protos.iter().enumerate() {
        writeln!(
            out,
            "{} {} ({} {}) {} {:?}",
            text::PROTOTYPE,
            i,
            proto.name,
            proto.num_regs,
            text::CONSTANTS,
            proto.consts
        )
        .unwrap_or(());
        for (pc, instr) in proto.code.iter().enumerate() {
            let name = instr
                .opcode()
                .map_or(text::UNKNOWN, super::instr::Opcode::name);
            write!(out, "  {pc:04} {name}").unwrap_or(());
            match instr.opcode() {
                Some(Opcode::LoadK | Opcode::Closure | Opcode::Switch | Opcode::Lazy) => {
                    writeln!(out, " {} {}", instr.a(), instr.bx()).unwrap_or(());
                }
                Some(
                    Opcode::Move
                    | Opcode::GetCap
                    | Opcode::GetDict
                    | Opcode::NegI
                    | Opcode::NegF
                    | Opcode::NegD
                    | Opcode::Force
                    | Opcode::Not,
                ) => {
                    writeln!(out, " {} {}", instr.a(), instr.b()).unwrap_or(());
                }
                Some(Opcode::TailCall | Opcode::TailMethod) => {
                    writeln!(out, " {} {}", instr.b(), instr.c()).unwrap_or(());
                }
                Some(Opcode::Return | Opcode::Escape | Opcode::Use) => {
                    writeln!(out, " {}", instr.a()).unwrap_or(());
                }
                Some(Opcode::Release) => {
                    writeln!(out).unwrap_or(());
                }
                Some(Opcode::Jmp) => {
                    writeln!(out, " {}", instr.sbx()).unwrap_or(());
                }
                Some(Opcode::JmpF) => {
                    writeln!(out, " {} {}", instr.a(), instr.sbx()).unwrap_or(());
                }
                _ => {
                    writeln!(out, " {} {} {}", instr.a(), instr.b(), instr.c()).unwrap_or(());
                }
            }
        }
        for (k, table) in proto.switch_tables.iter().enumerate() {
            writeln!(out, "  {} {k} {:?}", text::SWITCH, table).unwrap_or(());
        }
        for (k, global) in proto.handlers.iter().enumerate() {
            writeln!(out, "  {} {k} -> {}", text::HANDLER, global.0).unwrap_or(());
        }
        for (pc, class) in proto.method_traits.iter().enumerate() {
            if let Some(class) = class {
                writeln!(out, "  {} {pc} -> {}", text::METHOD_TRAIT, class.0).unwrap_or(());
            }
        }
    }
    for (i, ctor) in program.ctors.iter().enumerate() {
        writeln!(
            out,
            "{} {i} {}.{} {} {}",
            text::CTOR,
            ctor.type_name,
            ctor.ctor_name,
            ctor.tag,
            ctor.arity
        )
        .unwrap_or(());
    }
    for (i, class) in program.traits.iter().enumerate() {
        writeln!(
            out,
            "{} {i} {} {:?} {:?}",
            text::TRAIT,
            class.name,
            class.methods,
            class.supers
        )
        .unwrap_or(());
    }
    for (i, imp) in program.impls.iter().enumerate() {
        writeln!(
            out,
            "{} {i} {} {} {} {:?} {:?}",
            text::IMPL,
            imp.name,
            imp.trait_.0,
            imp.dict_arity,
            imp.methods,
            imp.supers
        )
        .unwrap_or(());
    }
    for (i, op) in program.ops.iter().enumerate() {
        writeln!(
            out,
            "{} {i} {} {} {} {:?}",
            text::OP,
            op.name,
            op.effect,
            op.arity,
            op.builtin
        )
        .unwrap_or(());
    }
    for (i, handler) in program.handlers.iter().enumerate() {
        writeln!(out, "{} {i} {:?}", text::HANDLER, handler.clauses).unwrap_or(());
    }
    for (i, builtin) in program.builtins.iter().enumerate() {
        let name = crate::builtins::builtin_decl(builtin.id).map_or(text::UNKNOWN, |d| d.name);
        writeln!(
            out,
            "{} {i} {name} {} {:?} {:?}",
            text::BUILTIN,
            builtin.arity,
            builtin.capability,
            builtin.op
        )
        .unwrap_or(());
    }
    out
}

mod text {
    pub const PROTOTYPE: &str = "prototype";
    pub const UNKNOWN: &str = "<unknown>";
    pub const CONSTANTS: &str = "constants";
    pub const SWITCH: &str = "switch";
    pub const CTOR: &str = "constructor";
    pub const TRAIT: &str = "trait";
    pub const IMPL: &str = "implementation";
    pub const OP: &str = "operation";
    pub const HANDLER: &str = "handler";
    pub const BUILTIN: &str = "builtin";
    pub const METHOD_TRAIT: &str = "method trait";
}
