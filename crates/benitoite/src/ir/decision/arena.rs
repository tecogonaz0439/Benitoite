//! 判定の節と正規化した行列の表（設計書 02-06「判定の木への変換」）。

use super::*;
use std::mem::size_of;

pub(super) const MAX_NODES: usize = 262_144;
pub(super) const MAX_EDGES: usize = 1_048_576;
const MAX_TABLE: usize = 64 * 1024 * 1024;

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub(super) struct NodeId(pub u32);

#[derive(Clone)]
pub(super) struct Edge {
    pub id: NodeId,
    pub args: Vec<Var>,
}

pub(super) struct Node {
    pub kind: Tree,
    pub params: Vec<Var>,
}

#[derive(Default)]
pub(super) struct DecisionArena {
    pub nodes: Vec<Option<Node>>,
    pub memo: HashMap<MatrixKey, NodeId>,
    pub first_var: u32,
    bytes: usize,
    name: String,
    origin: Option<Span>,
    pub output_nodes: usize,
    pub output_edges: usize,
}

impl DecisionArena {
    pub fn new(first_var: u32, name: &str, origin: Span) -> Self {
        Self {
            first_var,
            name: name.into(),
            origin: Some(origin),
            ..Self::default()
        }
    }

    pub fn table(&mut self, bytes: usize) -> Result<(), LowerError> {
        self.bytes = self
            .bytes
            .checked_add(bytes)
            .filter(|n| *n <= MAX_TABLE)
            .ok_or_else(|| {
                let diagnostic = DiagBuilder::new(DiagCode::L0112)
                    .arg("name", &self.name)
                    .note("table");
                let diagnostic = if let Some(origin) = self.origin {
                    diagnostic.primary(origin)
                } else {
                    diagnostic
                };
                LowerError::Limit(vec![diagnostic.build()])
            })?;
        Ok(())
    }

    pub fn set_params(&mut self, id: NodeId, params: Vec<Var>) -> Result<(), LowerError> {
        self.table(
            params
                .len()
                .checked_mul(size_of::<Var>())
                .ok_or_else(|| error("decision capacity overflow"))?,
        )?;
        self.nodes
            .get_mut(index(id.0)?)
            .and_then(Option::as_mut)
            .ok_or_else(|| error("missing decision node"))?
            .params = params;
        Ok(())
    }

    pub fn take(&mut self, id: NodeId) -> Result<Node, LowerError> {
        self.nodes
            .get_mut(index(id.0)?)
            .and_then(Option::take)
            .ok_or_else(|| error("decision node emitted twice"))
    }

    fn incoming(&self, root: &Edge) -> Result<Vec<u32>, LowerError> {
        let mut counts = vec![0_u32; self.nodes.len()];
        *counts
            .get_mut(index(root.id.0)?)
            .ok_or_else(|| error("missing root"))? = 1;
        for node in self.nodes.iter().flatten() {
            let mut valid = true;
            node.kind.visit_edges(|edge| {
                if let Ok(i) = index(edge.id.0)
                    && let Some(count) = counts.get_mut(i)
                {
                    if let Some(n) = count.checked_add(1) {
                        *count = n;
                    } else {
                        valid = false;
                    }
                } else {
                    valid = false;
                }
            });
            if !valid {
                return Err(error("invalid decision edge"));
            }
        }
        Ok(counts)
    }

    pub fn counts(&self, root: &Edge, len: usize) -> Result<Vec<u32>, LowerError> {
        let incoming = self.incoming(root)?;
        let mut counts = vec![0_u32; len];
        for (node, uses) in self.nodes.iter().zip(incoming) {
            if let Some(Node {
                kind: Tree::Leaf { arm, .. },
                ..
            }) = node
            {
                let count = counts
                    .get_mut(*arm)
                    .ok_or_else(|| error("invalid arm index"))?;
                *count = count
                    .checked_add(uses)
                    .ok_or_else(|| error("leaf count overflow"))?;
            }
        }
        Ok(counts)
    }

    pub fn emission_cost(&self, root: &Edge) -> Result<(usize, usize), LowerError> {
        let mut joins = 0_usize;
        let mut jumps = 0_usize;
        for n in self.incoming(root)? {
            if n > 1 {
                joins = joins
                    .checked_add(1)
                    .ok_or_else(|| error("join count overflow"))?;
                jumps = jumps
                    .checked_add(index(n)?)
                    .ok_or_else(|| error("jump count overflow"))?;
            }
        }
        Ok((joins, jumps))
    }

    pub fn labels(&self, root: &Edge, next: &mut u32) -> Result<Vec<Option<JoinId>>, LowerError> {
        self.incoming(root)?
            .into_iter()
            .map(|n| {
                if n > 1 {
                    Ok(Some(JoinId(fresh(next)?)))
                } else {
                    Ok(None)
                }
            })
            .collect()
    }
}

impl Tree {
    pub(super) fn visit_edges(&self, mut visit: impl FnMut(&Edge)) {
        match self {
            Self::Leaf { fallback, .. } => {
                if let Some(e) = fallback {
                    visit(e);
                }
            }
            Self::Ctor { arms, default, .. } => {
                for (_, _, e) in arms {
                    visit(e);
                }
                if let Some(e) = default {
                    visit(e);
                }
            }
            Self::Constant { arms, default, .. } => {
                for (_, e) in arms {
                    visit(e);
                }
                if let Some(e) = default {
                    visit(e);
                }
            }
            Self::Length {
                exact, otherwise, ..
            } => {
                for (_, e) in exact {
                    visit(e);
                }
                visit(otherwise);
            }
            Self::Gets { body, .. } => visit(body),
        }
    }
}

// 型と元の列の同一性を残し、枝で新しく振った番号だけを出現順へ置き換える。
#[derive(PartialEq, Eq, Hash)]
enum Input {
    Fixed(VarId),
    Param(u32),
}
#[derive(PartialEq, Eq, Hash)]
enum Atom {
    Wild,
    Var(VarId),
    Int(i64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    Ctor(BindingId, u32, usize),
    Range,
    List(usize, Option<Option<VarId>>, usize),
}
#[derive(PartialEq, Eq, Hash)]
enum BindingSource {
    Column(Input),
    Slice(Input, u32, u32),
}
#[derive(PartialEq, Eq, Hash)]
pub(super) struct MatrixKey {
    columns: Vec<(Input, Ty)>,
    params: Vec<Ty>,
    rows: Vec<RowKey>,
}

#[derive(PartialEq, Eq, Hash)]
struct RowKey {
    arm: usize,
    patterns: Vec<Atom>,
    bindings: Vec<(VarId, BindingSource)>,
}

#[inline(never)]
fn atoms(pattern: &CorePat, out: &mut Vec<Atom>) -> Result<(), LowerError> {
    match pattern {
        CorePat::Wild => out.push(Atom::Wild),
        CorePat::Var(v) => out.push(Atom::Var(*v)),
        CorePat::Const(c) => out.push(match c {
            Const::Int(v) => Atom::Int(*v),
            Const::Str(v) => Atom::Str(v.clone()),
            Const::Char(v) => Atom::Char(*v),
            Const::Bool(v) => Atom::Bool(*v),
            Const::Unit => Atom::Unit,
            Const::Float(_)
            | Const::Byte(_)
            | Const::Decimal(_)
            | Const::Int8(_)
            | Const::Int16(_)
            | Const::Int32(_)
            | Const::UInt16(_)
            | Const::UInt32(_)
            | Const::UInt64(_)
            | Const::Float32(_) => return Err(error("unsupported pattern constant")),
        }),
        CorePat::Ctor { adt, tag, args } => {
            out.push(Atom::Ctor(*adt, *tag, args.len()));
            for p in args {
                atoms(p, out)?;
            }
        }
        CorePat::Range { lo, hi } => {
            out.push(Atom::Range);
            atoms(&CorePat::Const(lo.clone()), out)?;
            atoms(&CorePat::Const(hi.clone()), out)?;
        }
        CorePat::List {
            before,
            rest,
            after,
        } => {
            out.push(Atom::List(
                before.len(),
                rest.as_ref().map(|r| r.var),
                after.len(),
            ));
            for p in before.iter().chain(after) {
                atoms(p, out)?;
            }
        }
    }
    Ok(())
}

impl MatrixKey {
    pub fn new(m: &Matrix, first_var: u32) -> Result<(Self, Vec<Var>), LowerError> {
        let mut params: Vec<Var> = Vec::new();
        let mut input = |v: &Var| -> Result<Input, LowerError> {
            if v.id.0 < first_var {
                return Ok(Input::Fixed(v.id));
            }
            let position = match params.iter().position(|p| p.id == v.id) {
                Some(i) => i,
                None => {
                    params.push(v.clone());
                    params.len().saturating_sub(1)
                }
            };
            Ok(Input::Param(size(position)?))
        };
        let columns = m
            .columns
            .iter()
            .map(|v| Ok((input(v)?, v.ty.clone())))
            .collect::<Result<_, LowerError>>()?;
        let mut rows = Vec::new();
        for row in &m.rows {
            let mut patterns = Vec::new();
            for p in &row.patterns {
                atoms(p, &mut patterns)?;
            }
            let mut bindings = Vec::new();
            for (id, source) in &row.bindings {
                bindings.push((
                    *id,
                    match source {
                        Source::Column(v) => BindingSource::Column(input(v)?),
                        Source::Slice { list, front, back } => {
                            BindingSource::Slice(input(list)?, *front, *back)
                        }
                    },
                ));
            }
            rows.push(RowKey {
                arm: row.arm,
                patterns,
                bindings,
            });
        }
        Ok((
            Self {
                columns,
                rows,
                params: params.iter().map(|v| v.ty.clone()).collect(),
            },
            params,
        ))
    }
}

impl Matrix {
    pub(super) fn prune(&mut self) {
        for c in (0..self.columns.len()).rev() {
            if self
                .rows
                .iter()
                .all(|r| r.patterns.get(c).is_some_and(simple))
            {
                let col = self.columns.remove(c);
                for row in &mut self.rows {
                    if let CorePat::Var(id) = row.patterns.remove(c) {
                        row.bindings.push((id, Source::Column(col.clone())));
                    }
                }
            }
        }
    }
}

// 複製する前に動的な内容も数える。上限を超えた時点で走査を打ち切る。
#[inline(never)]
pub(super) fn pattern_bytes(p: &CorePat) -> Result<usize, LowerError> {
    let mut bytes = size_of::<CorePat>();
    match p {
        CorePat::Ctor { args, .. } => {
            for p in args {
                bytes = add_bytes(bytes, pattern_bytes(p)?)?;
            }
        }
        CorePat::List { before, after, .. } => {
            for p in before.iter().chain(after) {
                bytes = add_bytes(bytes, pattern_bytes(p)?)?;
            }
        }
        CorePat::Const(Const::Str(s)) => bytes = add_bytes(bytes, s.len())?,
        CorePat::Wild | CorePat::Var(_) | CorePat::Const(_) | CorePat::Range { .. } => (),
    }
    Ok(bytes)
}

fn add_bytes(a: usize, b: usize) -> Result<usize, LowerError> {
    a.checked_add(b)
        .filter(|n| *n <= MAX_TABLE)
        .ok_or_else(|| error("decision capacity exceeds table budget"))
}

#[inline(never)]
fn ty_bytes(t: &Ty) -> Result<usize, LowerError> {
    let mut bytes = size_of::<Ty>();
    match t {
        Ty::Con(_, args) | Ty::App(_, args) => {
            for t in args {
                bytes = add_bytes(bytes, ty_bytes(t)?)?;
            }
        }
        Ty::Fn(f) => {
            bytes = add_bytes(bytes, size_of::<crate::types::FnTy>())?;
            for t in f.params.iter().chain([&f.ret]).chain(&f.effects.failures) {
                bytes = add_bytes(bytes, ty_bytes(t)?)?;
            }
            for name in &f.param_names {
                bytes = add_bytes(bytes, add_bytes(size_of::<String>(), name.len())?)?;
            }
            bytes = add_bytes(
                bytes,
                f.effects
                    .names
                    .len()
                    .checked_mul(size_of::<crate::types::EffectName>())
                    .ok_or_else(|| error("effect capacity overflow"))?,
            )?;
            bytes = add_bytes(
                bytes,
                f.effects
                    .vars
                    .len()
                    .checked_mul(size_of::<crate::types::EffVar>())
                    .ok_or_else(|| error("effect capacity overflow"))?,
            )?;
        }
        Ty::Param(_) | Ty::Rigid { .. } => (),
    }
    Ok(bytes)
}

impl Matrix {
    pub(super) fn allocation_bytes(&self, extra: usize) -> Result<usize, LowerError> {
        let mut bytes = size_of::<Self>();
        for col in &self.columns {
            bytes = add_bytes(bytes, add_bytes(size_of::<Var>(), ty_bytes(&col.ty)?)?)?;
        }
        for row in &self.rows {
            bytes = add_bytes(bytes, size_of::<Row>())?;
            for p in &row.patterns {
                bytes = add_bytes(bytes, pattern_bytes(p)?)?;
            }
            for (_, source) in &row.bindings {
                let ty = match source {
                    Source::Column(v) => &v.ty,
                    Source::Slice { list, .. } => &list.ty,
                };
                bytes = add_bytes(
                    bytes,
                    add_bytes(size_of::<(VarId, Source)>(), ty_bytes(ty)?)?,
                )?;
            }
            bytes = add_bytes(
                bytes,
                extra
                    .checked_mul(size_of::<CorePat>())
                    .ok_or_else(|| error("matrix capacity overflow"))?,
            )?;
        }
        // 成長する配列とハッシュ表の空き欄も要求容量に含める。
        bytes
            .checked_mul(2)
            .filter(|n| *n <= MAX_TABLE)
            .ok_or_else(|| error("matrix capacity exceeds table budget"))
    }
}
