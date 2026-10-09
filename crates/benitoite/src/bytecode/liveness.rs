//! コード生成が VM に渡す生存の情報（設計書 02-08「枠を降ろす原因と処理」、ADR 0259 の決定 2、
//! 実装プラン 10-07「生存の情報」）。回収の方式によらず同じ情報を使う。

use std::collections::{BTreeMap, BTreeSet, VecDeque};

use crate::builtins::iface::Capability;

use super::instr::{Instr, Opcode};
use super::program::{BuiltinRefIdx, CaptureSource, CtorIdx, ImplIdx, OpIdx, Proto, ProtoIdx};

/// 命令一つに付く生存の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum LiveItem {
    /// この命令が被演算子として最後に読むレジスタ。写さずに移してよい。
    /// `sole` は同じ命令のほかの被演算子に同じレジスタがないこと（その場での再利用の条件）
    LastUse { reg: u16, sole: bool },
    /// この命令の前に空にするレジスタ（被演算子でない）
    Dead { reg: u16 },
}

/// 原型一つの生存の情報。命令 i の項目は `items[starts[i]..starts[i + 1]]` である。
/// `starts` の長さは命令の数に 1 を足した数（空の原型では空でもよい）。
/// 命令 i の入口で生きているレジスタ（昇順）は `live_in[live_in_starts[i]..live_in_starts[i + 1]]`、
/// 命令 i が呼び出しの命令なら、その結果のレジスタは `call_writes[i]` である（ADR 0314）。
/// `live_in_starts` の長さは命令の数に 1 を足した数（`starts` と同じく 0 から始める。空の原型では `[0]`）、`call_writes` の長さは命令の数である。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct LiveInfo {
    pub starts: Vec<u32>,
    pub items: Vec<LiveItem>,
    pub live_in_starts: Vec<u32>,
    pub live_in: Vec<u16>,
    pub call_writes: Vec<Option<u16>>,
}

impl LiveInfo {
    /// 命令 `pc` の項目。範囲の外なら空。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn at(&self, pc: u32) -> &[LiveItem] {
        let Ok(i) = usize::try_from(pc) else {
            return &[];
        };
        let (Some(&start), Some(&end)) = (self.starts.get(i), self.starts.get(i.saturating_add(1)))
        else {
            return &[];
        };
        let (Ok(start), Ok(end)) = (usize::try_from(start), usize::try_from(end)) else {
            return &[];
        };
        self.items.get(start..end).unwrap_or(&[])
    }

    /// 命令 `pc` の入口で生きているレジスタ（昇順）。範囲の外なら `None`。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn live_in_at(&self, pc: u32) -> Option<&[u16]> {
        let i = usize::try_from(pc).ok()?;
        let start = usize::try_from(*self.live_in_starts.get(i)?).ok()?;
        let end = usize::try_from(*self.live_in_starts.get(i.checked_add(1)?)?).ok()?;
        self.live_in.get(start..end)
    }

    /// 命令 `pc` が呼び出しの命令なら、その結果のレジスタ。呼び出しの命令でないか範囲の外なら `None`。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn call_write(&self, pc: u32) -> Option<u16> {
        let i = usize::try_from(pc).ok()?;
        self.call_writes.get(i).copied().flatten()
    }
}

/// 命令一つが読むレジスタと書くレジスタ。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct RegUse {
    /// 読むレジスタ（被演算子の順。同じレジスタが二度現れることがある）
    pub reads: Vec<u16>,
    /// 結果を書くレジスタ
    pub write: Option<u16>,
    /// 命令の後に続く道筋がない（`RETURN`・`TAILCALL`・`TAILMETHOD`・`ESCAPE`）
    pub terminal: bool,
}

/// 生存の情報を求められないとき（命令列の不整合。処理系の不具合）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct LivenessError {
    pub proto: ProtoIdx,
    pub pc: u32,
    pub message: String,
}

use super::program::CompiledProgram;

/// 原型 `proto` の命令 `pc` が読むレジスタと書くレジスタ（10-07「生存の情報」の規則の 1 つ目）。
pub fn reg_use(
    program: &CompiledProgram,
    proto: ProtoIdx,
    pc: u32,
) -> Result<RegUse, LivenessError> {
    let site = Site::new(program, proto, pc)?;
    let instr = site.instr()?;
    let opcode = instr.opcode().ok_or_else(|| site.error("unknown opcode"))?;
    let (a, b, c) = (instr.a(), instr.b(), instr.c());
    let mut result = RegUse::default();
    match opcode {
        Opcode::Move
        | Opcode::Super
        | Opcode::Field
        | Opcode::Force
        | Opcode::NegI
        | Opcode::NegF
        | Opcode::NegD
        | Opcode::Not => {
            result.reads.push(b);
            result.write = Some(a);
        }
        Opcode::LoadK | Opcode::GetCap | Opcode::GetDict => result.write = Some(a),
        Opcode::Closure | Opcode::Lazy => {
            let captured = program
                .proto(ProtoIdx(instr.bx()))
                .ok_or_else(|| site.error("captured prototype is missing"))?;
            for source in &captured.captures {
                match source {
                    CaptureSource::Reg(reg) => result.reads.push(*reg),
                    CaptureSource::Capture(_) => {}
                }
            }
            result.write = Some(a);
        }
        Opcode::Call | Opcode::TailCall => {
            site.read_following(&mut result.reads, b, u32::from(c))?;
            result.terminal = opcode == Opcode::TailCall;
            result.write = (!result.terminal).then_some(a);
        }
        Opcode::Return | Opcode::Escape => {
            result.reads.push(a);
            result.terminal = true;
        }
        Opcode::Prim | Opcode::Io => {
            let builtin = program
                .builtin(BuiltinRefIdx(u32::from(b)))
                .ok_or_else(|| site.error("builtin reference is missing"))?;
            site.read_range(&mut result.reads, c, u32::from(builtin.arity))?;
            result.write = Some(a);
        }
        Opcode::Dict => {
            let imp = program
                .impl_info(ImplIdx(u32::from(b)))
                .ok_or_else(|| site.error("implementation is missing"))?;
            site.read_range(&mut result.reads, c, u32::from(imp.dict_arity))?;
            result.write = Some(a);
        }
        Opcode::Method | Opcode::TailMethod => {
            let trait_idx = site
                .p
                .method_traits
                .get(site.index)
                .copied()
                .flatten()
                .ok_or_else(|| site.error("method trait is missing"))?;
            let method = program
                .trait_info(trait_idx)
                .and_then(|info| info.methods.get(usize::from(c)))
                .ok_or_else(|| site.error("trait or method is missing"))?;
            site.read_following(&mut result.reads, b, u32::from(method.arity))?;
            result.terminal = opcode == Opcode::TailMethod;
            result.write = (!result.terminal).then_some(a);
        }
        Opcode::AddI
        | Opcode::SubI
        | Opcode::MulI
        | Opcode::DivI
        | Opcode::ModI
        | Opcode::AddF
        | Opcode::SubF
        | Opcode::MulF
        | Opcode::DivF
        | Opcode::AddD
        | Opcode::SubD
        | Opcode::MulD
        | Opcode::DivD
        | Opcode::Concat
        | Opcode::EqI
        | Opcode::LtI
        | Opcode::LeI
        | Opcode::EqF
        | Opcode::LtF
        | Opcode::LeF
        | Opcode::EqD
        | Opcode::LtD
        | Opcode::LeD
        | Opcode::EqS
        | Opcode::LtS
        | Opcode::LeS
        | Opcode::EqC
        | Opcode::LtC
        | Opcode::LeC
        | Opcode::EqBt
        | Opcode::LtBt
        | Opcode::LeBt
        | Opcode::EqB
        | Opcode::EqV
        | Opcode::Update
        | Opcode::Resume => {
            result.reads.extend([b, c]);
            result.write = Some(a);
        }
        Opcode::Con | Opcode::ConR => {
            let ctor = program
                .ctor(CtorIdx(u32::from(b)))
                .ok_or_else(|| site.error("constructor is missing"))?;
            if opcode == Opcode::ConR {
                result.reads.push(a);
            }
            site.read_range(&mut result.reads, c, u32::from(ctor.arity))?;
            result.write = Some(a);
        }
        Opcode::List => {
            site.read_range(&mut result.reads, b, u32::from(c))?;
            result.write = Some(a);
        }
        Opcode::Jmp | Opcode::Release => {}
        Opcode::JmpF | Opcode::Switch | Opcode::Use => result.reads.push(a),
        Opcode::Handle => {
            let handler = site
                .p
                .handler(c)
                .and_then(|idx| program.handler(idx))
                .ok_or_else(|| site.error("handler descriptor is missing"))?;
            let count = u32::try_from(handler.clauses.len())
                .map_err(|_| site.error("too many handler clauses"))?;
            site.read_following(&mut result.reads, b, count)?;
            result.write = Some(a);
        }
        Opcode::Perform => {
            let op = program
                .op(OpIdx(u32::from(b)))
                .ok_or_else(|| site.error("operation is missing"))?;
            site.read_range(&mut result.reads, c, u32::from(op.arity))?;
            result.write = Some(a);
        }
    }
    if result
        .reads
        .iter()
        .chain(result.write.iter())
        .any(|reg| *reg >= site.p.num_regs)
    {
        return Err(site.error("register is outside the prototype window"));
    }
    Ok(result)
}

/// 原型 `proto` の生存の情報を求める。
pub fn compute_liveness(
    program: &CompiledProgram,
    proto: ProtoIdx,
) -> Result<LiveInfo, LivenessError> {
    let p = program
        .proto(proto)
        .ok_or_else(|| error(proto, 0, "prototype is missing"))?;
    if p.method_traits.len() != p.code.len() || p.num_params > p.num_regs {
        return Err(error(proto, 0, "invalid prototype metadata"));
    }
    let mut nodes = Vec::with_capacity(p.code.len());
    for (index, instr) in p.code.iter().enumerate() {
        let pc = u32::try_from(index).map_err(|_| error(proto, 0, "code is too long"))?;
        let usage = reg_use(program, proto, pc)?;
        let site = Site::new(program, proto, pc)?;
        nodes.push(Node {
            successors: site.successors(*instr, usage.terminal)?,
            usage,
            ..Node::default()
        });
    }
    for index in 0..nodes.len() {
        let successors = node(&nodes, index, proto)?.successors.clone();
        for next in successors {
            node_mut(&mut nodes, next, proto)?.predecessors.push(index);
        }
    }

    // 空集合から始め、入口の集合が増えたときだけ先行命令を再計算する。
    // 有限個のレジスタの集合は単調に増えるため、後ろ向きの辺があっても終了する
    // （実装プラン R05「compute_liveness」）。
    let mut work: VecDeque<_> = (0..nodes.len()).rev().collect();
    while let Some(index) = work.pop_front() {
        let current = node(&nodes, index, proto)?;
        let mut live_out = BTreeSet::new();
        for next in &current.successors {
            live_out.extend(&node(&nodes, *next, proto)?.live_in);
        }
        let mut live_in = live_out.clone();
        if let Some(reg) = current.usage.write {
            live_in.remove(&reg);
        }
        live_in.extend(&current.usage.reads);
        let current = node_mut(&mut nodes, index, proto)?;
        current.live_out = live_out;
        if current.live_in != live_in {
            current.live_in = live_in;
            work.extend(&current.predecessors);
        }
    }
    for (index, current) in nodes.iter_mut().enumerate() {
        let pc = u32::try_from(index).map_err(|_| error(proto, 0, "code is too long"))?;
        let site = Site::new(program, proto, pc)?;
        let instr = site.instr()?;
        let waits = instr.opcode() == Some(Opcode::Io)
            || (instr.opcode() == Some(Opcode::Prim)
                && program
                    .builtin(BuiltinRefIdx(u32::from(instr.b())))
                    .is_some_and(|builtin| builtin.capability != Capability::Pure));
        if !waits {
            let mut sole_reads = BTreeMap::new();
            for reg in &current.usage.reads {
                sole_reads
                    .entry(*reg)
                    .and_modify(|sole| *sole = false)
                    .or_insert(true);
            }
            for reg in &current.usage.reads {
                let Some(sole) = sole_reads.remove(reg) else {
                    continue;
                };
                if !current.live_out.contains(reg) || current.usage.write == Some(*reg) {
                    current.last.push(LiveItem::LastUse { reg: *reg, sole });
                }
            }
        }
    }

    // H の変換は固定した生存集合との積・最後の使用の除去・書き込みの追加である。
    // これも単調なので、合流では和を取り、増えた分を後続へ伝えれば最小の解になる
    // （実装プラン 10-07「生存の情報」）。
    if let Some(first) = nodes.first_mut() {
        first.held.extend(0..p.num_params);
    }
    work.extend(0..nodes.len());
    while let Some(index) = work.pop_front() {
        let current = node(&nodes, index, proto)?;
        let mut held_out: BTreeSet<_> = current
            .held
            .intersection(&current.live_in)
            .copied()
            .collect();
        for item in &current.last {
            if let LiveItem::LastUse { reg, .. } = item {
                held_out.remove(reg);
            }
        }
        held_out.extend(current.usage.write);
        let successors = current.successors.clone();
        for next in successors {
            let target = node_mut(&mut nodes, next, proto)?;
            let old_len = target.held.len();
            target.held.extend(&held_out);
            if target.held.len() != old_len {
                work.push_back(next);
            }
        }
    }
    let mut live = LiveInfo::default();
    live.starts.push(0);
    live.live_in_starts.push(0);
    for (current, instr) in nodes.iter().zip(&p.code) {
        // 差分の項目とは別に入口の集合を保存し、過去に死んだ値も安全点で除く（ADR 0314）。
        live.live_in.extend(&current.live_in);
        live.live_in_starts.push(
            u32::try_from(live.live_in.len())
                .map_err(|_| error(proto, 0, "too many live-in registers"))?,
        );
        let writes = matches!(
            instr.opcode(),
            Some(
                Opcode::Call
                    | Opcode::Method
                    | Opcode::Handle
                    | Opcode::Force
                    | Opcode::Update
                    | Opcode::Perform
                    | Opcode::Io
                    | Opcode::Resume
            )
        );
        live.call_writes
            .push(if writes { current.usage.write } else { None });
        for reg in current.held.difference(&current.live_in) {
            live.items.push(LiveItem::Dead { reg: *reg });
        }
        live.items.extend(&current.last);
        live.starts.push(
            u32::try_from(live.items.len())
                .map_err(|_| error(proto, 0, "too many liveness items"))?,
        );
    }
    Ok(live)
}

fn error(proto: ProtoIdx, pc: u32, message: &str) -> LivenessError {
    LivenessError {
        proto,
        pc,
        message: message.to_owned(),
    }
}

struct Site<'a> {
    p: &'a Proto,
    proto: ProtoIdx,
    pc: u32,
    index: usize,
}

impl<'a> Site<'a> {
    fn new(program: &'a CompiledProgram, proto: ProtoIdx, pc: u32) -> Result<Self, LivenessError> {
        let p = program
            .proto(proto)
            .ok_or_else(|| error(proto, pc, "prototype is missing"))?;
        if p.method_traits.len() != p.code.len() {
            return Err(error(proto, pc, "method trait table has the wrong length"));
        }
        let index = usize::try_from(pc).map_err(|_| error(proto, pc, "pc does not fit usize"))?;
        Ok(Self {
            p,
            proto,
            pc,
            index,
        })
    }

    fn error(&self, message: &str) -> LivenessError {
        error(self.proto, self.pc, message)
    }

    fn instr(&self) -> Result<Instr, LivenessError> {
        self.p
            .code
            .get(self.index)
            .copied()
            .ok_or_else(|| self.error("instruction is missing"))
    }

    fn read_range(
        &self,
        reads: &mut Vec<u16>,
        start: u16,
        count: u32,
    ) -> Result<(), LivenessError> {
        for offset in 0..count {
            let reg = u32::from(start)
                .checked_add(offset)
                .and_then(|n| u16::try_from(n).ok())
                .ok_or_else(|| self.error("register range overflow"))?;
            reads.push(reg);
        }
        Ok(())
    }

    fn read_following(
        &self,
        reads: &mut Vec<u16>,
        start: u16,
        count: u32,
    ) -> Result<(), LivenessError> {
        let count = count
            .checked_add(1)
            .ok_or_else(|| self.error("argument count overflow"))?;
        self.read_range(reads, start, count)
    }

    fn jump_target(&self, offset: i32) -> Result<usize, LivenessError> {
        let target = i64::from(self.pc)
            .checked_add(1)
            .and_then(|n| n.checked_add(i64::from(offset)))
            .and_then(|n| usize::try_from(n).ok())
            .filter(|n| *n < self.p.code.len())
            .ok_or_else(|| self.error("jump target is outside the code"))?;
        Ok(target)
    }

    fn successors(&self, instr: Instr, terminal: bool) -> Result<Vec<usize>, LivenessError> {
        if terminal {
            return Ok(Vec::new());
        }
        let mut successors = Vec::new();
        if instr.opcode() == Some(Opcode::Jmp) || instr.opcode() == Some(Opcode::JmpF) {
            successors.push(self.jump_target(instr.sbx())?);
        } else if instr.opcode() == Some(Opcode::Switch) {
            let table = self
                .p
                .switch_table(instr.bx())
                .ok_or_else(|| self.error("switch table is missing"))?;
            for offset in table
                .targets
                .iter()
                .chain(std::iter::once(&table.default))
                .flatten()
            {
                successors.push(self.jump_target(*offset)?);
            }
        }
        // SWITCH はすべて表の相対位置へ跳ぶ。表にないタグで default もない場合は停止する
        // （実装プラン 10-07「コンパイル済みプログラム」）。
        if instr.opcode() != Some(Opcode::Jmp) && instr.opcode() != Some(Opcode::Switch) {
            let next = self
                .index
                .checked_add(1)
                .ok_or_else(|| self.error("pc overflow"))?;
            if next < self.p.code.len() {
                successors.push(next);
            }
        }
        successors.sort_unstable();
        successors.dedup();
        Ok(successors)
    }
}

#[derive(Default)]
struct Node {
    usage: RegUse,
    successors: Vec<usize>,
    predecessors: Vec<usize>,
    live_in: BTreeSet<u16>,
    live_out: BTreeSet<u16>,
    held: BTreeSet<u16>,
    last: Vec<LiveItem>,
}

fn node(nodes: &[Node], index: usize, proto: ProtoIdx) -> Result<&Node, LivenessError> {
    nodes
        .get(index)
        .ok_or_else(|| error(proto, 0, "analysis node is missing"))
}

fn node_mut(nodes: &mut [Node], index: usize, proto: ProtoIdx) -> Result<&mut Node, LivenessError> {
    nodes
        .get_mut(index)
        .ok_or_else(|| error(proto, 0, "analysis node is missing"))
}

#[cfg(test)]
// 公開の解析結果と独立した契約を確かめる。失敗は assert と準備データの添字・算術で表す。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::builtins::BuiltinId;
    use crate::bytecode::asm::ProgramBuilder;
    use crate::bytecode::program::{
        BuiltinRef, ClauseDesc, HandlerDesc, HandlerIdx, ImplInfo, MethodInfo, OpInfo, SwitchTable,
        TraitIdx, TraitInfo,
    };

    fn program(code: Vec<Instr>, params: u16, regs: u16) -> CompiledProgram {
        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", params, regs).unwrap();
        builder.code(main).unwrap().ret(0);
        let mut program = builder.finish(main).unwrap();
        let p = &mut program.protos[0];
        p.method_traits = vec![None; code.len()];
        p.positions = vec![None; code.len()];
        p.code = code;
        program
    }

    fn metadata_program() -> CompiledProgram {
        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 10, 16).unwrap();
        for arity in [1, 2, 3] {
            builder
                .builtin(BuiltinId(100), arity, Capability::Pure, None)
                .unwrap();
            builder.ctor("Node", "Node", 0, arity).unwrap();
        }
        for _ in 0..2 {
            let captured = builder.proto("captured", 0, 1).unwrap();
            builder.code(captured).unwrap().ret(0);
            builder.code(captured).unwrap().proto.captures = vec![
                CaptureSource::Reg(7),
                CaptureSource::Capture(4),
                CaptureSource::Reg(7),
            ];
        }
        builder.program.traits = vec![
            TraitInfo {
                name: "Methods".to_owned(),
                supers: vec![],
                methods: (0..5)
                    .map(|i| MethodInfo {
                        name: format!("m{i}"),
                        arity: 3,
                    })
                    .collect(),
            },
            TraitInfo {
                name: "OtherMethods".to_owned(),
                supers: vec![],
                methods: (0..5)
                    .map(|i| MethodInfo {
                        name: format!("m{i}"),
                        arity: 1,
                    })
                    .collect(),
            },
        ];
        for _ in 0..3 {
            builder.program.impls.push(ImplInfo {
                name: "impl".to_owned(),
                trait_: TraitIdx(0),
                dict_arity: 2,
                methods: vec![],
                supers: vec![],
            });
            builder.program.ops.push(OpInfo {
                name: "E.op".to_owned(),
                effect: "E".to_owned(),
                arity: 4,
                builtin: None,
            });
            builder.program.handlers.push(HandlerDesc {
                clauses: vec![
                    ClauseDesc {
                        op: OpIdx(2),
                        tail_resumptive: false,
                    };
                    4
                ],
            });
        }
        builder.code(main).unwrap().proto.handlers = vec![HandlerIdx(2); 5];
        builder.code(main).unwrap().ret(0);
        builder.finish(main).unwrap()
    }

    // 関門: 68 命令の読み書きは VM とコード生成が共有する契約であり、取り違えた
    // レジスタや表の arity をここで検出する。C01 の仮置きには既存のテストがない。
    #[test]
    fn all_opcodes_obey_register_operand_contracts() {
        use Opcode::*;
        let mut p = metadata_program();
        let mut cases = vec![
            (Move, vec![2], Some(1), false),
            (LoadK, vec![], Some(1), false),
            (GetCap, vec![], Some(1), false),
            (GetDict, vec![], Some(1), false),
            (Closure, vec![7, 7], Some(1), false),
            (Lazy, vec![7, 7], Some(1), false),
            (Call, vec![2, 3, 4, 5, 6], Some(1), false),
            (TailCall, vec![2, 3, 4, 5, 6], None, true),
            (Return, vec![1], None, true),
            (Escape, vec![1], None, true),
            (Prim, vec![4, 5, 6], Some(1), false),
            (Io, vec![4, 5, 6], Some(1), false),
            (Dict, vec![4, 5], Some(1), false),
            (Super, vec![2], Some(1), false),
            (Method, vec![2, 3, 4, 5], Some(1), false),
            (TailMethod, vec![2, 3, 4, 5], None, true),
            (Con, vec![4, 5, 6], Some(1), false),
            (ConR, vec![1, 4, 5, 6], Some(1), false),
            (List, vec![2, 3, 4, 5], Some(1), false),
            (Field, vec![2], Some(1), false),
            (Jmp, vec![], None, false),
            (JmpF, vec![1], None, false),
            (Switch, vec![1], None, false),
            (Force, vec![2], Some(1), false),
            (Use, vec![1], None, false),
            (Release, vec![], None, false),
            (Handle, vec![2, 3, 4, 5, 6], Some(1), false),
            (Perform, vec![4, 5, 6, 7], Some(1), false),
        ];
        for op in [NegI, NegF, NegD, Not] {
            cases.push((op, vec![2], Some(1), false));
        }
        for op in [
            AddI, SubI, MulI, DivI, ModI, AddF, SubF, MulF, DivF, AddD, SubD, MulD, DivD, Concat,
            EqI, LtI, LeI, EqF, LtF, LeF, EqD, LtD, LeD, EqS, LtS, LeS, EqC, LtC, LeC, EqBt, LtBt,
            LeBt, EqB, EqV, Update, Resume,
        ] {
            cases.push((op, vec![2, 4], Some(1), false));
        }
        let mut covered = BTreeSet::new();
        for (op, reads, write, terminal) in cases {
            // 捕捉の表の番号だけは Bx である。
            p.protos[0].code = vec![if op == Closure || op == Lazy {
                Instr::abx(op, 1, 2)
            } else {
                Instr::abc(op, 1, 2, 4)
            }];
            p.protos[0].method_traits = vec![Some(TraitIdx(0))];
            assert_eq!(
                reg_use(&p, ProtoIdx(0), 0).unwrap(),
                RegUse {
                    reads,
                    write,
                    terminal
                },
                "{op:?}"
            );
            assert!(covered.insert(op as u8));
            if !matches!(op, Jmp | JmpF | Switch) {
                // 結果を書くだけの命令と、中断中の旧値を除ける命令を取り違えない（ADR 0314）。
                let expected =
                    if [Call, Method, Handle, Force, Update, Perform, Io, Resume].contains(&op) {
                        Some(1)
                    } else {
                        None
                    };
                let live = compute_liveness(&p, ProtoIdx(0)).unwrap();
                assert_eq!(live.call_write(0), expected, "{op:?}");
                assert_eq!(live.call_write(1), None);
            }
        }
        assert_eq!(covered.len(), 68);
        assert_eq!(
            covered,
            (0..=u8::MAX)
                .filter(|n| Opcode::from_u8(*n).is_some())
                .collect()
        );

        // 同じ辞書のレジスタ・同じメソッドの位置でも、型クラスの記録で数が変わる。
        p.protos[0].code = vec![Instr::abc(Method, 1, 2, 4)];
        p.protos[0].method_traits = vec![Some(TraitIdx(1))];
        assert_eq!(reg_use(&p, ProtoIdx(0), 0).unwrap().reads, vec![2, 3]);
        for op in [
            Call, TailCall, List, Prim, Io, Dict, Con, ConR, Method, TailMethod, Handle, Perform,
        ] {
            let mut p = metadata_program();
            p.protos[0].code = vec![Instr::abc(op, 1, 2, 0)];
            p.protos[0].method_traits = vec![Some(TraitIdx(0))];
            p.builtins[2].arity = 0;
            p.impls[2].dict_arity = 0;
            p.ctors[2].arity = 0;
            p.ops[2].arity = 0;
            p.traits[0].methods[0].arity = 0;
            p.handlers[2].clauses.clear();
            let expected = if [Call, TailCall, Method, TailMethod, Handle].contains(&op) {
                vec![2]
            } else if op == ConR {
                vec![1]
            } else {
                vec![]
            };
            assert_eq!(
                reg_use(&p, ProtoIdx(0), 0).unwrap().reads,
                expected,
                "zero arity {op:?}"
            );
        }
    }

    #[test]
    fn malformed_operands_and_tables_return_liveness_errors() {
        use Opcode::*;
        for instr in [
            Instr(255),
            Instr::abc(Prim, 1, 99, 0),
            Instr::abc(Io, 1, 99, 0),
            Instr::abc(Dict, 1, 99, 0),
            Instr::abc(Con, 1, 99, 0),
            Instr::abc(ConR, 1, 99, 0),
            Instr::abc(Perform, 1, 99, 0),
            Instr::abc(Handle, 1, 2, 99),
            Instr::abc(Method, 1, 2, 99),
            Instr::abc(TailMethod, 1, 2, 99),
            Instr::abx(Closure, 1, 99),
            Instr::abx(Lazy, 1, 99),
            Instr::abc(Call, 1, u16::MAX, 1),
            Instr::abc(List, 1, u16::MAX, 2),
            Instr::abc(Prim, 1, 2, u16::MAX),
            Instr::abc(Move, 16, 0, 0),
        ] {
            let mut p = metadata_program();
            p.protos[0].code = vec![instr];
            p.protos[0].method_traits = vec![Some(TraitIdx(0))];
            let err = reg_use(&p, ProtoIdx(0), 0).unwrap_err();
            assert_eq!((err.proto, err.pc), (ProtoIdx(0), 0), "{instr:?}");
        }
        for trait_ in [None, Some(TraitIdx(99))] {
            let mut p = metadata_program();
            p.protos[0].code = vec![Instr::abc(Method, 1, 2, 0)];
            p.protos[0].method_traits = vec![trait_];
            assert!(reg_use(&p, ProtoIdx(0), 0).is_err());
        }
        let mut p = metadata_program();
        assert!(reg_use(&p, ProtoIdx(99), 0).is_err());
        assert!(compute_liveness(&p, ProtoIdx(99)).is_err());
        assert!(reg_use(&p, ProtoIdx(0), 99).is_err());
        p.protos[0].method_traits.clear();
        assert!(reg_use(&p, ProtoIdx(0), 0).is_err());
        assert!(compute_liveness(&p, ProtoIdx(0)).is_err());
        let mut p = metadata_program();
        p.protos[0].num_params = 17;
        assert!(compute_liveness(&p, ProtoIdx(0)).is_err());
        for instr in [
            Instr::asbx(Jmp, 0, -2),
            Instr::asbx(JmpF, 0, 1),
            Instr::abx(Switch, 0, 99),
        ] {
            let p = program(vec![instr], 1, 1);
            assert!(compute_liveness(&p, ProtoIdx(0)).is_err());
        }
        for table in [
            SwitchTable {
                targets: vec![Some(-2)],
                default: None,
            },
            SwitchTable {
                targets: vec![None],
                default: Some(1),
            },
        ] {
            let mut p = program(vec![Instr::abx(Switch, 0, 0)], 1, 1);
            p.protos[0].switch_tables.push(table);
            assert!(compute_liveness(&p, ProtoIdx(0)).is_err());
        }
    }

    fn items(p: &CompiledProgram) -> Vec<Vec<LiveItem>> {
        let live = compute_liveness(p, ProtoIdx(0)).unwrap();
        assert_eq!(live.starts.len(), p.protos[0].code.len() + 1);
        (0..p.protos[0].code.len())
            .map(|i| live.at(u32::try_from(i).unwrap()).to_vec())
            .collect()
    }

    fn last(reg: u16, sole: bool) -> LiveItem {
        LiveItem::LastUse { reg, sole }
    }
    fn dead(reg: u16) -> LiveItem {
        LiveItem::Dead { reg }
    }

    fn assert_items(p: &CompiledProgram, expected: Vec<Vec<LiveItem>>) {
        // 項目の並び順は契約に含めない。重複を消さずに揃え、余分な項目も検出する。
        let normalize = |mut lists: Vec<Vec<LiveItem>>| {
            for list in &mut lists {
                list.sort_by_key(|item| match item {
                    LiveItem::Dead { reg } => (0, *reg, false),
                    LiveItem::LastUse { reg, sole } => (1, *reg, *sole),
                });
            }
            lists
        };
        assert_eq!(normalize(items(p)), normalize(expected));
    }

    #[test]
    fn straight_line_overwrites_and_terminal_windows() {
        use Opcode::*;
        let p = program(
            vec![
                Instr::abc(Move, 1, 0, 0),
                Instr::abc(AddI, 2, 1, 1),
                Instr::abc(Return, 2, 0, 0),
            ],
            1,
            3,
        );
        assert_items(
            &p,
            vec![
                vec![last(0, true)],
                vec![last(1, false)],
                vec![last(2, true)],
            ],
        );
        let p = program(
            vec![Instr::abc(Move, 0, 0, 0), Instr::abc(Return, 0, 0, 0)],
            1,
            1,
        );
        assert_items(&p, vec![vec![last(0, true)], vec![last(0, true)]]);
        for terminal in [Return, Escape, TailCall, TailMethod] {
            let mut p = metadata_program();
            p.protos[0].code = vec![Instr::abc(terminal, 0, 0, 0), Instr::abc(Release, 0, 0, 0)];
            p.protos[0].method_traits = vec![Some(TraitIdx(0)), None];
            let found = items(&p);
            assert!(found[1].is_empty(), "window cleared after {terminal:?}");
        }
        let p = program(vec![Instr::abc(Return, 0, 0, 0)], 3, 3);
        assert_items(&p, vec![vec![dead(1), dead(2), last(0, true)]]);
        let p = program(vec![], 0, 1);
        assert_eq!(
            compute_liveness(&p, ProtoIdx(0)).unwrap(),
            LiveInfo {
                starts: vec![0],
                items: vec![],
                live_in_starts: vec![0],
                live_in: vec![],
                call_writes: vec![],
            }
        );
    }

    #[test]
    fn branches_clear_only_the_unused_path_and_loops_keep_values() {
        use Opcode::*;
        let p = program(
            vec![
                Instr::asbx(JmpF, 0, 2),
                Instr::abc(AddI, 4, 1, 3),
                Instr::asbx(Jmp, 0, 1),
                Instr::abc(AddI, 4, 2, 3),
                Instr::abc(AddI, 5, 4, 3),
                Instr::abc(Return, 5, 0, 0),
            ],
            4,
            6,
        );
        assert_items(
            &p,
            vec![
                vec![last(0, true)],
                vec![dead(2), last(1, true)],
                vec![],
                vec![dead(1), last(2, true)],
                vec![last(4, true), last(3, true)],
                vec![last(5, true)],
            ],
        );
        let p = program(
            vec![
                Instr::abc(AddI, 2, 1, 0),
                Instr::asbx(JmpF, 2, 1),
                Instr::asbx(Jmp, 0, -3),
                Instr::abc(Return, 1, 0, 0),
            ],
            2,
            3,
        );
        assert_items(
            &p,
            vec![
                vec![],
                vec![last(2, true)],
                vec![],
                vec![dead(0), last(1, true)],
            ],
        );
    }

    #[test]
    fn waiting_arguments_survive_until_the_next_instruction() {
        use Opcode::*;
        let mut p = program(
            vec![
                Instr::abc(Io, 6, 0, 1),
                Instr::abc(Release, 0, 0, 0),
                Instr::abc(Prim, 6, 1, 3),
                Instr::abc(Release, 0, 0, 0),
                Instr::abc(Prim, 6, 2, 5),
                Instr::abc(Return, 6, 0, 0),
            ],
            6,
            7,
        );
        p.builtins = vec![
            BuiltinRef {
                id: BuiltinId(0),
                arity: 2,
                capability: Capability::Io,
                op: None,
            },
            BuiltinRef {
                id: BuiltinId(1),
                arity: 2,
                capability: Capability::State,
                op: None,
            },
            BuiltinRef {
                id: BuiltinId(2),
                arity: 1,
                capability: Capability::Pure,
                op: None,
            },
        ];
        assert_items(
            &p,
            vec![
                vec![dead(0)],
                vec![dead(1), dead(2), dead(6)],
                vec![],
                vec![dead(3), dead(4), dead(6)],
                vec![last(5, true)],
                vec![last(6, true)],
            ],
        );
        // 待つ命令が結果で引数を上書きする場合も、完了するまでは移動しない。
        p.protos[0].code = vec![
            Instr::abc(Io, 1, 0, 1),
            Instr::asbx(Jmp, 0, 0),
            Instr::abc(Return, 1, 0, 0),
        ];
        p.protos[0].method_traits = vec![None; 3];
        let found = items(&p);
        assert!(
            !found[0]
                .iter()
                .any(|i| matches!(i, LiveItem::LastUse { .. }))
        );
        assert!(found[1].contains(&dead(2)));
        assert!(!found[1].contains(&dead(1)));
    }

    // 関門: 差分の項目では分からない命令入口の集合を、分岐の和と後ろ向きの辺を含む
    // 手書きの期待値で守る。既存の LastUse/Dead のテストはこの新しい契約を確かめない。
    #[test]
    fn live_in_sets_include_branch_merges_and_backward_edges() {
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 4, 7).unwrap();
        let code = b.code(main).unwrap();
        let again = code.label("again").unwrap();
        let right = code.label("right").unwrap();
        let join = code.label("join").unwrap();
        code.place(again).unwrap();
        code.jmpf(0, right);
        code.op(Opcode::AddI, 4, 1, 3);
        code.jmpf(4, again);
        code.jmp(join);
        code.place(right).unwrap();
        code.op(Opcode::AddI, 4, 2, 3);
        code.place(join).unwrap();
        code.op(Opcode::Move, 5, 4, 0);
        code.op(Opcode::Call, 6, 5, 0);
        code.ret(6);
        let p = b.finish(main).unwrap();
        let live = &p.protos[0].live;
        let expected: &[&[u16]] = &[
            &[0, 1, 2, 3],
            &[0, 1, 2, 3],
            &[0, 1, 2, 3, 4],
            &[4],
            &[2, 3],
            &[4],
            &[5],
            &[6],
        ];
        for (pc, regs) in expected.iter().enumerate() {
            assert_eq!(live.live_in_at(u32::try_from(pc).unwrap()), Some(*regs));
        }
        assert_eq!(live.live_in_starts.len(), expected.len() + 1);
        assert_eq!(
            live.call_writes,
            vec![None, None, None, None, None, None, Some(6), None]
        );
        assert_eq!(live.live_in_at(8), None);
        assert_eq!(live.live_in_at(u32::MAX), None);

        // 空集合は範囲外と異なる。命令入口に読む値がない原型でも情報を持つ。
        let mut b = ProgramBuilder::new();
        let main = b.proto("main", 0, 1).unwrap();
        b.loadk(main, 0, super::super::program::ConstDesc::Unit)
            .unwrap();
        b.code(main).unwrap().ret(0);
        let p = b.finish(main).unwrap();
        assert_eq!(p.protos[0].live.live_in_at(0), Some([].as_slice()));
        assert_eq!(p.protos[0].live.live_in_at(1), Some([0].as_slice()));
    }

    #[test]
    fn reuse_candidate_is_last_even_when_the_new_value_is_live() {
        for (start, expected) in [
            (1, vec![last(0, true), last(1, true), last(2, true)]),
            (0, vec![dead(2), last(0, false), last(1, true)]),
        ] {
            let mut p = program(
                vec![
                    Instr::abc(Opcode::ConR, 0, 0, start),
                    Instr::abc(Opcode::Return, 0, 0, 0),
                ],
                3,
                3,
            );
            p.ctors.push(super::super::program::CtorInfo {
                type_name: "Node".to_owned(),
                ctor_name: "Node".to_owned(),
                tag: 0,
                arity: 2,
            });
            assert_items(&p, vec![expected, vec![last(0, true)]]);
        }
    }

    // データフローの式を使わず、道筋を直接辿る。読み出しは同じ命令の書き込みより先である。
    fn reads_before_write(
        start: &[usize],
        reg: u16,
        uses: &[RegUse],
        edges: &[Vec<usize>],
    ) -> bool {
        let mut stack = start.to_vec();
        let mut visited = vec![false; uses.len()];
        while let Some(pc) = stack.pop() {
            if visited[pc] {
                continue;
            }
            visited[pc] = true;
            if uses[pc].reads.contains(&reg) {
                return true;
            }
            if uses[pc].write != Some(reg) {
                stack.extend(&edges[pc]);
            }
        }
        false
    }

    fn oracle_edges(p: &Proto, pc: usize) -> Vec<usize> {
        let instr = p.code[pc];
        let op = instr.opcode().unwrap();
        let jump = |offset: i32| {
            usize::try_from(i64::try_from(pc).unwrap() + 1 + i64::from(offset)).unwrap()
        };
        if [
            Opcode::Return,
            Opcode::TailCall,
            Opcode::TailMethod,
            Opcode::Escape,
        ]
        .contains(&op)
        {
            vec![]
        } else if op == Opcode::Jmp {
            vec![jump(instr.sbx())]
        } else if op == Opcode::JmpF {
            vec![pc + 1, jump(instr.sbx())]
        } else if op == Opcode::Switch {
            let table = &p.switch_tables[usize::try_from(instr.bx()).unwrap()];
            table
                .targets
                .iter()
                .chain([&table.default])
                .flatten()
                .map(|offset| jump(*offset))
                .collect()
        } else if pc + 1 < p.code.len() {
            vec![pc + 1]
        } else {
            vec![]
        }
    }

    fn random(state: &mut u64, bound: u32) -> u32 {
        *state ^= *state << 13;
        *state ^= *state >> 7;
        *state ^= *state << 17;
        u32::try_from(*state % u64::from(bound)).unwrap()
    }

    // 関門: 解析の反復や H の伝播を取り違えても、別の方式の道筋探索と具体的な
    // レジスタの有無の探索が検出する。固定例では組み合わせを網羅できない。
    #[test]
    fn random_prototypes_agree_with_path_and_register_state_exploration() {
        use Opcode::*;
        let mut seed = 0x4b05_5eed_a739_0123;
        for case in 0..1_200 {
            let len = usize::try_from(8 + random(&mut seed, 13)).unwrap();
            let mut p = program(vec![], 6, 6);
            p.consts.push(super::super::program::ConstDesc::Int(0));
            p.protos[0].consts.push(super::super::program::ConstIdx(0));
            p.ctors.push(super::super::program::CtorInfo {
                type_name: "Node".to_owned(),
                ctor_name: "Node".to_owned(),
                tag: 0,
                arity: 2,
            });
            for capability in [Capability::Io, Capability::State, Capability::Pure] {
                p.builtins.push(BuiltinRef {
                    id: BuiltinId(0),
                    arity: 2,
                    capability,
                    op: None,
                });
            }
            for pc in 0..len {
                let a = u16::try_from(random(&mut seed, 6)).unwrap();
                let b = u16::try_from(random(&mut seed, 6)).unwrap();
                let c = u16::try_from(random(&mut seed, 6)).unwrap();
                let target =
                    usize::try_from(random(&mut seed, u32::try_from(len).unwrap())).unwrap();
                let offset = i32::try_from(target).unwrap() - i32::try_from(pc).unwrap() - 1;
                let kind = if pc == len - 1 {
                    11
                } else {
                    random(&mut seed, 12)
                };
                let instr = match kind {
                    0 => Instr::abc(Move, a, b, 0),
                    1 => Instr::abc(AddI, a, b, c),
                    2 => Instr::abx(LoadK, a, 0),
                    3 => Instr::asbx(Jmp, 0, offset),
                    4 => Instr::asbx(JmpF, a, offset),
                    5 => {
                        let other = usize::try_from(random(&mut seed, u32::try_from(len).unwrap()))
                            .unwrap();
                        let other_offset =
                            i32::try_from(other).unwrap() - i32::try_from(pc).unwrap() - 1;
                        let idx = u32::try_from(p.protos[0].switch_tables.len()).unwrap();
                        p.protos[0].switch_tables.push(SwitchTable {
                            targets: vec![Some(offset), None],
                            default: Some(other_offset),
                        });
                        Instr::abx(Switch, a, idx)
                    }
                    6 => Instr::abc(Io, a, 0, c % 5),
                    7 => Instr::abc(Prim, a, 1, c % 5),
                    8 => Instr::abc(Prim, a, 2, c % 5),
                    9 => Instr::abc(ConR, a, 0, c % 5),
                    10 => Instr::abc(Call, a, b % 4, c % 3),
                    11 => Instr::abc(Return, a, 0, 0),
                    _ => unreachable!(),
                };
                p.protos[0].code.push(instr);
                p.protos[0].method_traits.push(None);
            }
            let uses: Vec<_> = (0..len)
                .map(|pc| reg_use(&p, ProtoIdx(0), u32::try_from(pc).unwrap()).unwrap())
                .collect();
            let edges: Vec<_> = (0..len).map(|pc| oracle_edges(&p.protos[0], pc)).collect();
            let may_read: Vec<Vec<_>> = (0..len)
                .map(|pc| {
                    (0..6)
                        .map(|r| reads_before_write(&[pc], r, &uses, &edges))
                        .collect()
                })
                .collect();
            let expected_last: Vec<BTreeSet<_>> = (0..len)
                .map(|pc| {
                    let instr = p.protos[0].code[pc];
                    let waits = instr.opcode() == Some(Io)
                        || (instr.opcode() == Some(Prim) && instr.b() == 1);
                    uses[pc]
                        .reads
                        .iter()
                        .filter(|r| {
                            !waits
                                && (uses[pc].write == Some(**r)
                                    || !reads_before_write(&edges[pc], **r, &uses, &edges))
                        })
                        .map(|r| {
                            (
                                *r,
                                uses[pc].reads.iter().filter(|other| *other == r).count() == 1,
                            )
                        })
                        .collect()
                })
                .collect();

            // H を集合の方程式では求めず、具体的な窓の状態を全探索する。到達しない命令も
            // 空の窓から始めることで、R05 が定める H の最小の解と同じ書き込みを含める。
            let mut stack: Vec<_> = (0..len).map(|pc| (pc, 0_u16)).collect();
            stack.push((0, 0b11_1111));
            let mut visited = BTreeSet::new();
            let mut held = vec![0_u16; len];
            while let Some((pc, mut mask)) = stack.pop() {
                if !visited.insert((pc, mask)) {
                    continue;
                }
                held[pc] |= mask;
                for (r, read) in may_read[pc].iter().enumerate() {
                    if !read {
                        mask &= !(1 << r);
                    }
                }
                for (r, _) in &expected_last[pc] {
                    mask &= !(1 << r);
                }
                if let Some(r) = uses[pc].write {
                    mask |= 1 << r;
                }
                stack.extend(edges[pc].iter().map(|next| (*next, mask)));
            }
            let live = compute_liveness(&p, ProtoIdx(0)).unwrap();
            for pc in 0..len {
                let actual = live.at(u32::try_from(pc).unwrap());
                let mut found_last = BTreeSet::new();
                let mut found_dead = BTreeSet::new();
                for item in actual {
                    match item {
                        LiveItem::LastUse { reg, sole } => {
                            assert!(found_last.insert((*reg, *sole)))
                        }
                        LiveItem::Dead { reg } => {
                            assert!(
                                !reads_before_write(&[pc], *reg, &uses, &edges),
                                "unsafe Dead: case {case}, pc {pc}, reg {reg}"
                            );
                            assert!(found_dead.insert(*reg));
                        }
                    }
                }
                assert_eq!(
                    found_last, expected_last[pc],
                    "LastUse: case {case}, pc {pc}"
                );
                let expected_dead = (0..6_u16)
                    .filter(|r| held[pc] & (1 << r) != 0 && !may_read[pc][usize::from(*r)])
                    .collect();
                assert_eq!(found_dead, expected_dead, "Dead: case {case}, pc {pc}");
            }
        }
    }
}
