//! 逆アセンブラ（設計書 02-07、実装プラン 10-07「コード生成」）。
//!
//! テストの失敗を調べるときと、設計者が生成したコードを読むときに使う。形式はテストで比べない
//! （10-07）ので、読みやすさだけを考えて並べる。

use std::fmt::Write;

use super::instr::{Instr, Opcode};
use super::program::{CaptureSource, CompiledProgram, ConstDesc, Proto, SwitchTable};

/// コンパイル済みプログラムを、原型ごとに命令を一行ずつ並べた文字列にする。
/// 各行は命令の位置、命令の名前（`LOADK` など大文字）、オペランドを示す。形式はテストで比べない。
pub fn disassemble(program: &CompiledProgram) -> String {
    let mut out = String::new();
    // String への書き込みは失敗しない。失敗したときも、そこまでに書いた分を返せば足りる
    match write_program(&mut out, program) {
        Ok(()) | Err(_) => out,
    }
}

fn write_program(out: &mut String, program: &CompiledProgram) -> std::fmt::Result {
    writeln!(
        out,
        "main: proto {} ({:?})",
        program.main.0, program.main_kind
    )?;
    for (binding, proto) in &program.top_fns {
        writeln!(out, "top b{} -> proto {}", binding.0, proto.0)?;
    }
    for (i, c) in program.ctors.iter().enumerate() {
        writeln!(
            out,
            "ctor {i}: {}.{} tag={} arity={}",
            c.type_name, c.ctor_name, c.tag, c.arity
        )?;
    }
    for (i, b) in program.builtins.iter().enumerate() {
        writeln!(out, "builtin {i}: {b:?}")?;
    }
    for (i, p) in program.protos.iter().enumerate() {
        writeln!(out)?;
        write_proto(out, i, p)?;
    }
    Ok(())
}

fn write_proto(out: &mut String, index: usize, p: &Proto) -> std::fmt::Result {
    writeln!(
        out,
        "proto {index} {} ({:?}) params={} regs={}",
        p.name, p.origin, p.num_params, p.num_regs
    )?;
    for (i, c) in p.captures.iter().enumerate() {
        match c {
            CaptureSource::Reg(r) => writeln!(out, "  capture {i}: R{r}")?,
            CaptureSource::Capture(k) => writeln!(out, "  capture {i}: cap {k}")?,
        }
    }
    for (i, k) in p.consts.iter().enumerate() {
        writeln!(out, "  K{i} = {}", show_const(k))?;
    }
    for (i, t) in p.switch_tables.iter().enumerate() {
        writeln!(out, "  switch {i}: {}", show_table(t))?;
    }
    for (pos, instr) in p.code.iter().enumerate() {
        writeln!(out, "  {pos:04}  {}", show_instr(*instr, pos))?;
    }
    Ok(())
}

fn show_const(k: &ConstDesc) -> String {
    match k {
        ConstDesc::Int(n) => format!("{n}"),
        ConstDesc::Float(x) => format!("{x:?}"),
        ConstDesc::Str(s) => format!("{s:?}"),
        ConstDesc::Char(c) => format!("{c:?}"),
        ConstDesc::Bool(b) => format!("{b}"),
        ConstDesc::Unit => "()".to_string(),
        ConstDesc::NullaryCtor { tag } => format!("ctor tag {tag}"),
        ConstDesc::Proto(p) => format!("proto {}", p.0),
    }
}

fn show_table(t: &SwitchTable) -> String {
    let targets: Vec<String> = t
        .targets
        .iter()
        .enumerate()
        .map(|(tag, off)| match off {
            Some(o) => format!("{tag}=>{o:+}"),
            None => format!("{tag}=>-"),
        })
        .collect();
    let default = match t.default {
        Some(o) => format!("{o:+}"),
        None => "-".to_string(),
    };
    format!("[{}] default={default}", targets.join(" "))
}

fn opcode_name(op: Opcode) -> &'static str {
    match op {
        Opcode::Move => "MOVE",
        Opcode::LoadK => "LOADK",
        Opcode::GetCap => "GETCAP",
        Opcode::Closure => "CLOSURE",
        Opcode::Call => "CALL",
        Opcode::TailCall => "TAILCALL",
        Opcode::Return => "RETURN",
        Opcode::Prim => "PRIM",
        Opcode::Io => "IO",
        Opcode::AddI => "ADDI",
        Opcode::SubI => "SUBI",
        Opcode::MulI => "MULI",
        Opcode::DivI => "DIVI",
        Opcode::ModI => "MODI",
        Opcode::NegI => "NEGI",
        Opcode::AddF => "ADDF",
        Opcode::SubF => "SUBF",
        Opcode::MulF => "MULF",
        Opcode::DivF => "DIVF",
        Opcode::NegF => "NEGF",
        Opcode::Concat => "CONCAT",
        Opcode::EqI => "EQI",
        Opcode::LtI => "LTI",
        Opcode::LeI => "LEI",
        Opcode::EqF => "EQF",
        Opcode::LtF => "LTF",
        Opcode::LeF => "LEF",
        Opcode::EqS => "EQS",
        Opcode::LtS => "LTS",
        Opcode::LeS => "LES",
        Opcode::EqC => "EQC",
        Opcode::LtC => "LTC",
        Opcode::LeC => "LEC",
        Opcode::EqB => "EQB",
        Opcode::EqV => "EQV",
        Opcode::Not => "NOT",
        Opcode::Con => "CON",
        Opcode::List => "LIST",
        Opcode::Field => "FIELD",
        Opcode::Jmp => "JMP",
        Opcode::JmpF => "JMPF",
        Opcode::Switch => "SWITCH",
    }
}

/// 跳ぶ先の絶対位置（読みやすさのために添える）。求められなければ `?`。
fn jump_target(pos: usize, sbx: i32) -> String {
    i64::try_from(pos)
        .ok()
        .and_then(|p| p.checked_add(1))
        .and_then(|p| p.checked_add(i64::from(sbx)))
        .map_or_else(|| "?".to_string(), |t| format!("{t:04}"))
}

fn show_instr(instr: Instr, pos: usize) -> String {
    let Some(op) = instr.opcode() else {
        return format!("??? {:#018x}", instr.0);
    };
    let name = opcode_name(op);
    let operands = match op {
        Opcode::Return => format!("A={}", instr.a()),
        Opcode::Move | Opcode::GetCap | Opcode::NegI | Opcode::NegF | Opcode::Not => {
            format!("A={} B={}", instr.a(), instr.b())
        }
        Opcode::LoadK | Opcode::Closure | Opcode::Switch => {
            format!("A={} Bx={}", instr.a(), instr.bx())
        }
        Opcode::TailCall => format!("B={} C={}", instr.b(), instr.c()),
        Opcode::Jmp => format!("sBx={} ->{}", instr.sbx(), jump_target(pos, instr.sbx())),
        Opcode::JmpF => format!(
            "A={} sBx={} ->{}",
            instr.a(),
            instr.sbx(),
            jump_target(pos, instr.sbx())
        ),
        Opcode::Call
        | Opcode::Prim
        | Opcode::Io
        | Opcode::AddI
        | Opcode::SubI
        | Opcode::MulI
        | Opcode::DivI
        | Opcode::ModI
        | Opcode::AddF
        | Opcode::SubF
        | Opcode::MulF
        | Opcode::DivF
        | Opcode::Concat
        | Opcode::EqI
        | Opcode::LtI
        | Opcode::LeI
        | Opcode::EqF
        | Opcode::LtF
        | Opcode::LeF
        | Opcode::EqS
        | Opcode::LtS
        | Opcode::LeS
        | Opcode::EqC
        | Opcode::LtC
        | Opcode::LeC
        | Opcode::EqB
        | Opcode::EqV
        | Opcode::Con
        | Opcode::List
        | Opcode::Field => format!("A={} B={} C={}", instr.a(), instr.b(), instr.c()),
    };
    format!("{name:<9} {operands}")
}

#[cfg(test)]
// テストの失敗は panic で表す（設計書 07-03「実装の規約と静的な検査」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use std::sync::Arc;

    use super::*;
    use crate::base::SourceTable;
    use crate::bytecode::program::{MainKind, ProtoIdx, ProtoOrigin};

    #[test]
    fn lists_every_instruction_by_name_in_order() {
        let proto = Proto {
            name: "main".to_string(),
            origin: ProtoOrigin::UserFn,
            lambda_span: None,
            code: vec![
                Instr::asbx(Opcode::JmpF, 0, 1),
                Instr::abx(Opcode::LoadK, 1, 0),
                Instr::abc(Opcode::Return, 1, 0, 0),
            ],
            consts: vec![ConstDesc::Int(42)],
            switch_tables: Vec::new(),
            num_regs: 2,
            num_params: 1,
            captures: Vec::new(),
            positions: vec![None, None, None],
        };
        let program = CompiledProgram {
            protos: vec![proto],
            top_fns: Vec::new(),
            ctors: Vec::new(),
            builtins: Vec::new(),
            main: ProtoIdx(0),
            main_kind: MainKind::Unit,
            sources: Arc::new(SourceTable::new()),
        };
        let text = disassemble(&program);
        // 形式はテストで比べない（10-07）。原型の名前と、各命令の名前が命令の順に一度ずつ出ることだけを確かめる
        assert!(text.contains("main"), "{text}");
        let mut rest = text.as_str();
        for name in ["JMPF", "LOADK", "RETURN"] {
            let at = rest
                .find(name)
                .unwrap_or_else(|| panic!("{name} missing in\n{text}"));
            rest = &rest[at + name.len()..];
        }
        for name in ["JMPF", "LOADK", "RETURN"] {
            assert_eq!(text.matches(name).count(), 1, "{text}");
        }
    }
}
