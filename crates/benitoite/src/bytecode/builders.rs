//! 専用保持先の定義・種類・handle 本体の用途を制御フローで検査する（設計書 02-07「命令」）。

use super::instr::Opcode;
use super::liveness::{LivenessError, reg_use, successors};
use super::program::{CompiledProgram, ProtoIdx, ProtoOrigin};
use crate::resolve::builders::BuilderClass;
use std::collections::{BTreeMap, BTreeSet, VecDeque};

#[derive(Clone, Default, PartialEq, Eq)]
struct State {
    locals: BTreeMap<u16, BuilderClass>,
    bodies: BTreeMap<u16, ProtoIdx>,
}

/// 命令ごとの専用の読み取りと書き込み。通常値の生存集合と混ぜない。
#[derive(Default)]
pub(crate) struct Use {
    pub reads: BTreeSet<u16>,
    pub write: Option<u16>,
}

/// 専用欄の定義と本体の用途を検査し、各命令の専用読み書きを返す。
pub(crate) fn analyze(program: &CompiledProgram, id: ProtoIdx) -> Result<Vec<Use>, LivenessError> {
    let fail = |pc, message: &str| LivenessError {
        proto: id,
        pc,
        message: message.to_owned(),
    };
    let proto = program
        .proto(id)
        .ok_or_else(|| fail(0, "builder prototype missing"))?;
    if proto.builder_slots == 0
        && proto.builder_sites.is_empty()
        && proto.builder_inputs.is_empty()
        && !proto.code.iter().any(|instr| {
            matches!(instr.opcode(), Some(Opcode::Closure | Opcode::Lazy))
                && program
                    .proto(ProtoIdx(instr.bx()))
                    .is_some_and(|body| !body.builder_inputs.is_empty())
        })
    {
        return Ok(vec![]);
    }
    if !proto.builder_inputs.is_empty() && proto.origin != ProtoOrigin::UserHandleBody {
        return Err(fail(0, "builder inputs require handle body origin"));
    }
    let mut entry = State::default();
    for input in &proto.builder_inputs {
        if input.target >= proto.builder_slots
            || entry.locals.insert(input.target, input.kind).is_some()
        {
            return Err(fail(0, "invalid or duplicate builder input target"));
        }
    }
    let mut states = vec![None; proto.code.len()];
    let mut queue = VecDeque::new();
    if let Some(first) = states.first_mut() {
        *first = Some(entry.clone());
        queue.push_back(0);
    }
    while let Some(pc) = queue.pop_front() {
        let mut state = states
            .get(pc)
            .and_then(Clone::clone)
            .ok_or_else(|| fail(0, "builder state missing"))?;
        let instruction = *proto
            .code
            .get(pc)
            .ok_or_else(|| fail(0, "builder instruction missing"))?;
        let pc32 = u32::try_from(pc).map_err(|_| fail(0, "builder pc overflow"))?;
        let usage = reg_use(program, id, pc32)?;
        let opcode = instruction
            .opcode()
            .ok_or_else(|| fail(pc32, "builder opcode missing"))?;
        if opcode == Opcode::Closure
            && let Some(body) = program.proto(ProtoIdx(instruction.bx()))
            && !body.builder_inputs.is_empty()
            && body.builder_parent != Some(id)
        {
            return Err(fail(
                pc32,
                "handle builder body has wrong generating parent",
            ));
        }
        let body = if opcode == Opcode::Move {
            state.bodies.get(&instruction.b()).copied()
        } else if opcode == Opcode::Closure {
            program
                .proto(ProtoIdx(instruction.bx()))
                .filter(|p| !p.builder_inputs.is_empty())
                .map(|_| ProtoIdx(instruction.bx()))
        } else {
            None
        };
        if let Some(write) = usage.write {
            state.bodies.remove(&write);
            if let Some(body) = body {
                state.bodies.insert(write, body);
            }
        }
        if opcode == Opcode::BuilderNew {
            let site = proto
                .builder_sites
                .get(
                    usize::try_from(instruction.bx())
                        .map_err(|_| fail(pc32, "builder site overflow"))?,
                )
                .ok_or_else(|| fail(pc32, "builder site missing"))?;
            state.locals.insert(site.local, site.kind);
        }
        for next in successors(program, id, pc32)? {
            let slot = states
                .get_mut(next)
                .ok_or_else(|| fail(pc32, "builder successor missing"))?;
            let merged = if let Some(old) = slot.as_ref() {
                State {
                    locals: old
                        .locals
                        .iter()
                        .filter(|(k, v)| state.locals.get(k) == Some(v))
                        .map(|(k, v)| (*k, *v))
                        .collect(),
                    // 専用入力を持つ本体の可能性は合流で消さない。
                    // 異なる本体・通常値との合流は不明の印を保ち、使用時に拒否する。
                    bodies: old
                        .bodies
                        .keys()
                        .chain(state.bodies.keys())
                        .map(|key| {
                            let body = match (old.bodies.get(key), state.bodies.get(key)) {
                                (Some(a), Some(b)) if a == b => *a,
                                _ => ProtoIdx(u32::MAX),
                            };
                            (*key, body)
                        })
                        .collect(),
                }
            } else {
                state.clone()
            };
            if slot.as_ref() != Some(&merged) {
                *slot = Some(merged);
                queue.push_back(next);
            }
        }
    }
    let mut result = Vec::with_capacity(proto.code.len());
    for (pc, instr) in proto.code.iter().enumerate() {
        let pc32 = u32::try_from(pc).map_err(|_| fail(0, "builder pc overflow"))?;
        let opcode = instr
            .opcode()
            .ok_or_else(|| fail(pc32, "builder opcode missing"))?;
        let mut usage = Use::default();
        let Some(state) = states.get(pc).and_then(Option::as_ref) else {
            result.push(usage);
            continue;
        };
        let regs = reg_use(program, id, pc32)?;
        for reg in &regs.reads {
            if state.bodies.contains_key(reg)
                && !(opcode == Opcode::Move || (opcode == Opcode::Handle && *reg == instr.b()))
            {
                return Err(fail(pc32, "handle body with builder inputs escaped"));
            }
        }
        if matches!(
            opcode,
            Opcode::BuilderNew
                | Opcode::BuilderAppend
                | Opcode::BuilderAppendAll
                | Opcode::BuilderCopy
                | Opcode::BuilderLength
        ) {
            let site = proto
                .builder_sites
                .get(usize::try_from(instr.bx()).map_err(|_| fail(pc32, "builder site overflow"))?)
                .ok_or_else(|| fail(pc32, "builder site missing"))?;
            if opcode == Opcode::BuilderNew {
                usage.write = Some(site.local);
            } else {
                if state.locals.get(&site.local) != Some(&site.kind) {
                    return Err(fail(
                        pc32,
                        "builder definition does not dominate use or kind mismatch",
                    ));
                }
                usage.reads.insert(site.local);
            }
        }
        if opcode == Opcode::Lazy
            && program
                .proto(ProtoIdx(instr.bx()))
                .is_some_and(|p| !p.builder_inputs.is_empty())
        {
            return Err(fail(
                pc32,
                "handle builder inputs cannot be used as lazy body",
            ));
        }
        if opcode == Opcode::Handle
            && let Some(body) = state.bodies.get(&instr.b())
        {
            let body = program
                .proto(*body)
                .ok_or_else(|| fail(pc32, "handle body missing"))?;
            for input in &body.builder_inputs {
                if state.locals.get(&input.source) != Some(&input.kind) {
                    return Err(fail(
                        pc32,
                        "handle builder source is undefined or has wrong kind",
                    ));
                }
                usage.reads.insert(input.source);
            }
        }
        result.push(usage);
    }
    Ok(result)
}
