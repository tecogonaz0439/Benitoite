//! 原型ごとのレジスタと束縛の管理（設計書 02-07「レジスタの割り当て」）。

use super::*;

pub(super) fn internal(message: impl Into<String>) -> Box<InternalError> {
    Box::new(InternalError {
        stage: "codegen",
        message: message.into(),
    })
}

pub(super) fn count(n: usize) -> CgResult<u32> {
    u32::try_from(n).map_err(|_| internal("table size exceeds 32 bits"))
}

// 制限に当たっても他の原型の生成を続ける。丸めた命令は実行に渡さない（02-07「処理系の制限」）。
pub(super) fn r16(n: u32) -> u16 {
    u16::try_from(n).unwrap_or(u16::MAX)
}

pub(super) fn relative(from: usize, to: usize) -> CgResult<i32> {
    let from = i64::try_from(from).map_err(|_| internal("jump position overflow"))?;
    let to = i64::try_from(to).map_err(|_| internal("jump target overflow"))?;
    let offset = to
        .checked_sub(from)
        .and_then(|x| x.checked_sub(1))
        .ok_or_else(|| internal("jump offset overflow"))?;
    i32::try_from(offset).map_err(|_| internal("jump offset exceeds 32 bits"))
}

#[derive(Clone, Copy)]
pub(super) enum Loc {
    Reg(u32),
    Cap(u32),
}
#[derive(Clone, Copy)]
pub(super) enum Target {
    Reg(u32),
    Tail,
}

pub(super) struct JoinState {
    pub params: Vec<u32>,
    pub target: Option<usize>,
    pub pending: Vec<usize>,
    pub reuse: Vec<Reuse>,
}

#[derive(Clone)]
pub(super) struct Reuse {
    pub reg: u32,
    pub aliases: HashSet<Key>,
    pub arity: usize,
    pub used: bool,
    pub captured: bool,
}

pub(super) struct FnGen<'p> {
    pub def: &'p LowerDef,
    pub boundary: bool,
    pub method_body: bool,
    pub code: Vec<Instr>,
    pub positions: Vec<Option<Span>>,
    pub method_traits: Vec<Option<TraitIdx>>,
    pub consts: Vec<ConstIdx>,
    pub const_index: HashMap<ConstIdx, u32>,
    pub switch_tables: Vec<SwitchTable>,
    pub handlers: Vec<HandlerIdx>,
    pub next_reg: u32,
    pub max_regs: u32,
    pub env: HashMap<Key, Loc>,
    pub joins: HashMap<JoinId, JoinState>,
    pub captures: Vec<CaptureSource>,
    pub aliases: HashMap<Key, HashSet<Key>>,
    pub reuse: Vec<Reuse>,
}

pub(super) fn empty_proto() -> Proto {
    Proto {
        name: String::new(),
        origin: ProtoOrigin::UserFn,
        span: None,
        boundary: true,
        code: Vec::new(),
        consts: Vec::new(),
        switch_tables: Vec::new(),
        handlers: Vec::new(),
        num_regs: 0,
        num_params: 0,
        captures: Vec::new(),
        positions: Vec::new(),
        method_traits: Vec::new(),
        live: LiveInfo::default(),
    }
}

impl<'p> FnGen<'p> {
    pub fn new(def: &'p LowerDef, boundary: bool) -> Self {
        Self {
            def,
            boundary,
            method_body: matches!(def.kind, DefKind::Method { .. }),
            code: Vec::new(),
            positions: Vec::new(),
            method_traits: Vec::new(),
            consts: Vec::new(),
            const_index: HashMap::new(),
            switch_tables: Vec::new(),
            handlers: Vec::new(),
            next_reg: 0,
            max_regs: 0,
            env: HashMap::new(),
            joins: HashMap::new(),
            captures: Vec::new(),
            aliases: HashMap::new(),
            reuse: Vec::new(),
        }
    }
    pub fn alloc(&mut self) -> u32 {
        self.alloc_block(1)
    }
    pub fn alloc_block(&mut self, n: u32) -> u32 {
        let base = self.next_reg;
        self.next_reg = self.next_reg.saturating_add(n);
        self.max_regs = self.max_regs.max(self.next_reg);
        base
    }
    pub fn release(&mut self, mark: u32) {
        self.next_reg = mark;
    }
    pub fn bind(&mut self, key: Key, loc: Loc) -> CgResult<()> {
        if self.env.contains_key(&key) {
            return Err(internal("duplicate variable in a nested scope"));
        }
        self.env.insert(key, loc);
        Ok(())
    }
    pub fn lookup(&self, key: Key) -> CgResult<Loc> {
        self.env
            .get(&key)
            .copied()
            .ok_or_else(|| internal(format!("unbound variable: {key:?}")))
    }
    pub fn reg_of(&self, v: &LowVal) -> Option<u32> {
        if let ValKind::Var(x) = v.kind
            && let Some(Loc::Reg(r)) = self.env.get(&Key::Var(x))
        {
            Some(*r)
        } else {
            None
        }
    }
    pub fn emit(&mut self, instr: Instr, origin: Option<Span>) -> usize {
        let pc = self.code.len();
        self.code.push(instr);
        self.positions.push(origin);
        self.method_traits.push(None);
        pc
    }
    pub fn jump(&mut self, op: Opcode, a: u32, origin: Span) -> usize {
        self.emit(Instr::asbx(op, r16(a), 0), Some(origin))
    }
    pub fn patch(&mut self, pc: usize, target: usize) -> CgResult<()> {
        let offset = relative(pc, target)?;
        let slot = self
            .code
            .get_mut(pc)
            .ok_or_else(|| internal("invalid jump position"))?;
        let op = slot
            .opcode()
            .ok_or_else(|| internal("invalid jump opcode"))?;
        *slot = Instr::asbx(op, slot.a(), offset);
        Ok(())
    }
    pub fn patch_here(&mut self, pc: usize) -> CgResult<()> {
        self.patch(pc, self.code.len())
    }
    pub fn jump_to_end(&mut self, target: Target, origin: Span) -> Option<usize> {
        match target {
            Target::Reg(_) => Some(self.jump(Opcode::Jmp, 0, origin)),
            Target::Tail => None,
        }
    }
    pub fn end(&mut self, jump: Option<usize>) -> CgResult<()> {
        if let Some(pc) = jump {
            self.patch_here(pc)?;
        }
        Ok(())
    }
    pub fn load(&mut self, dst: u32, index: ConstIdx, origin: Option<Span>) -> CgResult<()> {
        let local = if let Some(local) = self.const_index.get(&index) {
            *local
        } else {
            let local = count(self.consts.len())?;
            self.consts.push(index);
            self.const_index.insert(index, local);
            local
        };
        self.emit(Instr::abx(Opcode::LoadK, r16(dst), local), origin);
        Ok(())
    }
    pub fn result(&mut self, target: Target) -> u32 {
        match target {
            Target::Reg(r) => r,
            Target::Tail => self.alloc(),
        }
    }
    pub fn returned(&mut self, target: Target, dst: u32, origin: Option<Span>) {
        if let Target::Tail = target {
            self.emit(Instr::abc(Opcode::Return, r16(dst), 0, 0), origin);
        }
    }
    pub fn alias(&mut self, key: Key, of: Key) {
        let mut group = self
            .aliases
            .get(&of)
            .cloned()
            .unwrap_or_else(|| HashSet::from([of]));
        group.insert(key);
        for x in &group {
            self.aliases.insert(*x, group.clone());
        }
        for candidate in &mut self.reuse {
            if !candidate.aliases.is_disjoint(&group) {
                candidate.aliases.extend(group.iter().copied());
            }
        }
    }
    pub fn unbind(&mut self, key: Key) {
        self.env.remove(&key);
        self.aliases.remove(&key);
        for group in self.aliases.values_mut() {
            group.remove(&key);
        }
        for candidate in &mut self.reuse {
            candidate.aliases.remove(&key);
        }
    }
}
