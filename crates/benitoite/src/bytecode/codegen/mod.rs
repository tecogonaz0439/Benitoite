//! 下位 IR をレジスタ型の命令へ移す（設計書 02-07、実装プラン F15）。
//! 表をすべて埋めてから生存の情報を求める（10-07「生存の情報」）。

mod analysis;
mod emit;
mod state;
mod tables;
#[cfg(test)]
mod tests;

use super::instr::{Instr, Opcode};
use super::liveness::{LiveInfo, compute_liveness};
use super::program::*;
use crate::base::{BindingId, NodeId, SourceTable, Span};
use crate::builtins::BuiltinId;
use crate::builtins::iface::Capability;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::ir::InternalError;
use crate::ir::core_ir::*;
use crate::ir::lower_ir::*;
use crate::types::builtin::BuiltinTypeId;
use crate::types::{ConstValue, EffectName, Ty, TyCon, TypeArg, TypeArgs};
use analysis::{Key, Node, free_keys};
use state::{FnGen, Loc, Target, count, internal, r16, relative};
use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::Arc;

/// コード生成の失敗。
#[derive(Debug)]
pub enum CodegenError {
    /// 処理系の制限（原型ごとの L0101〜L0104 と、10-07「オペランドの補足」の表の大きさの制限 L0105〜L0111）。原型ごとの制限は当たった関数ごとに一つ、表の大きさの制限は表ごとに一つ
    Limit(Vec<Diagnostic>),
    Internal(InternalError),
}

type CgResult<T> = Result<T, Box<InternalError>>;

/// 下位 IR からコンパイル済みプログラムを作る（02-07「コード生成」、10-07「コード生成」）。
pub fn codegen(
    program: &LowerProgram,
    sources: Arc<SourceTable>,
) -> Result<CompiledProgram, CodegenError> {
    generate(program, sources).map_err(|e| CodegenError::Internal(*e))?
}

fn generate(
    input: &LowerProgram,
    sources: Arc<SourceTable>,
) -> CgResult<Result<CompiledProgram, CodegenError>> {
    let mut g = Gen::new(input, sources);
    // 相互再帰と後の定義への参照のため、本体より先に番号を振る（F15「表と原型の番号」）。
    for def in &input.defs {
        let index = g.reserve_proto()?;
        if g.def_protos.insert(def.binding, index).is_some() {
            return Err(internal("duplicate top-level binding"));
        }
        g.out.top_fns.push((def.binding, index));
    }
    for imp in &input.impls {
        let mut methods = Vec::new();
        for _ in &imp.methods {
            methods.push(g.reserve_proto()?);
        }
        if g.method_protos.insert(imp.impl_decl, methods).is_some() {
            return Err(internal("duplicate implementation"));
        }
    }
    for def in &input.defs {
        let index = *g
            .def_protos
            .get(&def.binding)
            .ok_or_else(|| internal("missing definition prototype"))?;
        g.definition(def, index)?;
        g.drain_bodies()?;
    }
    for imp in &input.impls {
        let indices = g
            .method_protos
            .get(&imp.impl_decl)
            .cloned()
            .ok_or_else(|| internal("missing method prototypes"))?;
        for (def, index) in imp.methods.iter().zip(indices) {
            g.definition(def, index)?;
            g.drain_bodies()?;
        }
    }
    g.out.main = input
        .main
        .map(|id| {
            g.def_protos
                .get(&id)
                .copied()
                .ok_or_else(|| internal("missing main prototype"))
        })
        .transpose()?;
    g.out.main_kind = if g.out.main.is_some() && input.main_returns_result {
        MainKind::Result
    } else {
        MainKind::Unit
    };
    if !g.diags.is_empty() {
        return Ok(Err(CodegenError::Limit(g.diags)));
    }
    if g.filled.iter().any(|filled| !filled) {
        return Err(internal("unfilled prototype slot"));
    }
    // 捕捉と命令の引数の数は表から引くので、表の生成の途中では計算しない（10-07「生存の情報」）。
    for i in 0..g.out.protos.len() {
        let live = compute_liveness(&g.out, ProtoIdx(count(i)?))
            .map_err(|e| internal(format!("liveness: {e:?}")))?;
        g.out
            .protos
            .get_mut(i)
            .ok_or_else(|| internal("missing prototype"))?
            .live = live;
    }
    Ok(Ok(g.out))
}

struct Gen<'p> {
    input: &'p LowerProgram,
    out: CompiledProgram,
    filled: Vec<bool>,
    def_protos: HashMap<BindingId, ProtoIdx>,
    method_protos: HashMap<NodeId, Vec<ProtoIdx>>,
    builtin_protos: HashMap<BuiltinId, ProtoIdx>,
    op_protos: HashMap<BindingId, ProtoIdx>,
    const_index: HashMap<tables::ConstKey, ConstIdx>,
    const_refs: HashMap<BindingId, ConstIdx>,
    ctor_index: HashMap<(BindingId, u32), CtorIdx>,
    trait_index: HashMap<BindingId, TraitIdx>,
    impl_index: HashMap<NodeId, ImplIdx>,
    op_index: HashMap<BindingId, OpIdx>,
    builtin_index: HashMap<BuiltinId, BuiltinRefIdx>,
    diags: Vec<Diagnostic>,
    limit_keys: HashSet<(DiagCode, String)>,
    pending: VecDeque<PendingBody<'p>>,
}

struct PendingBody<'p> {
    index: ProtoIdx,
    body: &'p LComp,
    inner: Box<FnGen<'p>>,
    name: String,
    origin: ProtoOrigin,
    span: Span,
    params: u32,
}

impl<'p> Gen<'p> {
    fn new(input: &'p LowerProgram, sources: Arc<SourceTable>) -> Self {
        Self {
            input,
            out: CompiledProgram {
                protos: Vec::new(),
                consts: Vec::new(),
                top_fns: Vec::new(),
                ctors: Vec::new(),
                traits: Vec::new(),
                impls: Vec::new(),
                ops: Vec::new(),
                builtins: Vec::new(),
                handlers: Vec::new(),
                main: None,
                main_kind: MainKind::Unit,
                sources,
            },
            filled: Vec::new(),
            def_protos: HashMap::new(),
            method_protos: HashMap::new(),
            builtin_protos: HashMap::new(),
            op_protos: HashMap::new(),
            const_index: HashMap::new(),
            const_refs: HashMap::new(),
            ctor_index: HashMap::new(),
            trait_index: HashMap::new(),
            impl_index: HashMap::new(),
            op_index: HashMap::new(),
            builtin_index: HashMap::new(),
            diags: Vec::new(),
            limit_keys: HashSet::new(),
            pending: VecDeque::new(),
        }
    }
    fn reserve_proto(&mut self) -> CgResult<ProtoIdx> {
        let index = ProtoIdx(count(self.out.protos.len())?);
        self.out.protos.push(state::empty_proto());
        self.filled.push(false);
        Ok(index)
    }
    fn set_proto(&mut self, index: ProtoIdx, proto: Proto) -> CgResult<()> {
        let i = usize::try_from(index.0).map_err(|_| internal("prototype index overflow"))?;
        *self
            .out
            .protos
            .get_mut(i)
            .ok_or_else(|| internal("invalid prototype index"))? = proto;
        *self
            .filled
            .get_mut(i)
            .ok_or_else(|| internal("invalid prototype index"))? = true;
        Ok(())
    }
    fn definition(&mut self, def: &'p LowerDef, index: ProtoIdx) -> CgResult<()> {
        let mut fg = Box::new(FnGen::new(def, true));
        for p in &def.dict_params {
            let r = fg.alloc();
            fg.bind(Key::Var(p.var), Loc::Reg(r))?;
        }
        for p in &def.params {
            let r = fg.alloc();
            fg.bind(Key::Var(p.id), Loc::Reg(r))?;
        }
        self.comp(&mut fg, &def.body, Target::Tail, &HashSet::new())?;
        let origin = match def.origin {
            DefOrigin::User => {
                if matches!(def.kind, DefKind::Method { .. }) {
                    ProtoOrigin::UserMethod
                } else {
                    ProtoOrigin::UserFn
                }
            }
            DefOrigin::StdlibPublic => ProtoOrigin::StdlibPublic,
            DefOrigin::StdlibHelper => ProtoOrigin::StdlibHelper,
        };
        let params = count(def.dict_params.len().saturating_add(def.params.len()))?;
        let proto = self.finish(*fg, def.name.clone(), origin, None, params)?;
        self.set_proto(index, proto)
    }
    fn finish(
        &mut self,
        fg: FnGen<'p>,
        name: String,
        origin: ProtoOrigin,
        span: Option<Span>,
        params: u32,
    ) -> CgResult<Proto> {
        for (code, size, max) in [
            (
                DiagCode::L0101,
                usize::try_from(fg.max_regs).map_err(|_| internal("register count overflow"))?,
                65535,
            ),
            (DiagCode::L0102, fg.consts.len(), 65536),
            (DiagCode::L0103, fg.switch_tables.len(), 65536),
            (DiagCode::L0104, fg.handlers.len(), 65536),
        ] {
            if size > max {
                self.diags.push(
                    DiagBuilder::new(code)
                        .arg("name", fg.def.name.clone())
                        .primary(fg.def.span)
                        .note("limit")
                        .build(),
                );
            }
        }
        Ok(Proto {
            name,
            origin,
            span,
            boundary: fg.boundary,
            code: fg.code,
            consts: fg.consts,
            switch_tables: fg.switch_tables,
            handlers: fg.handlers,
            num_regs: r16(fg.max_regs),
            num_params: r16(params),
            captures: fg.captures,
            positions: fg.positions,
            method_traits: fg.method_traits,
            live: LiveInfo::default(),
        })
    }
}
