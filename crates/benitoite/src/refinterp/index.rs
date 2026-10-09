//! 本体と自由な変数の表（設計書 02-08「参照インタプリタ」、02-06「コア IR」）。
//! IR の走査だけを再帰で行い、実行中は BodyId から本体を引く。

use crate::base::BindingId;
use crate::ir::core_ir::*;
use crate::runtime::Stop;
use std::collections::{BTreeSet, HashMap};

pub(super) struct BodyInfo<'p> {
    pub body: &'p Comp,
    pub params: &'p [Var],
    pub free: Vec<VarId>,
    pub var_count: u32,
}

pub(super) struct Index<'p> {
    pub bodies: HashMap<BodyId, BodyInfo<'p>>,
    pub defs: HashMap<BindingId, &'p CoreDef>,
    pub constants: Vec<&'p ConstDef<Comp>>,
}

impl<'p> Index<'p> {
    pub fn new(program: &'p CoreProgram) -> Result<Self, Stop> {
        let mut result = Self {
            bodies: HashMap::new(),
            defs: HashMap::new(),
            constants: vec![],
        };
        for def in program
            .defs
            .iter()
            .chain(program.impls.iter().flat_map(|i| &i.methods))
        {
            result.defs.insert(def.binding, def);
            result.index(&def.body, def.var_count);
        }
        let mut dependencies = HashMap::new();
        let mut definitions = HashMap::new();
        for def in &program.consts {
            result.index(&def.body, def.var_count);
            let mut comps = vec![];
            let mut vals = vec![];
            walk(&def.body, &mut comps, &mut vals);
            dependencies.insert(
                def.binding,
                vals.iter()
                    .filter_map(|v| match v.kind {
                        ValKind::ConstRef(id) => Some(id),
                        ValKind::Var(_)
                        | ValKind::Const(_)
                        | ValKind::TopFn { .. }
                        | ValKind::Builtin { .. }
                        | ValKind::Op { .. }
                        | ValKind::Lambda(_)
                        | ValKind::Ctor { .. }
                        | ValKind::List(_) => None,
                    })
                    .collect::<Vec<_>>(),
            );
            definitions.insert(def.binding, def);
        }
        // 前方参照の定数も同じ実行のループで評価できる順に並べる（設計書 01-12「トップレベルの定数」）。
        let mut done = BTreeSet::new();
        let mut active = BTreeSet::new();
        for def in &program.consts {
            let mut pending = vec![(def.binding, false)];
            while let Some((id, finish)) = pending.pop() {
                if done.contains(&id) {
                    continue;
                }
                if finish {
                    active.remove(&id);
                    done.insert(id);
                    result.constants.push(
                        *definitions
                            .get(&id)
                            .ok_or_else(|| fault("unknown constant"))?,
                    );
                } else {
                    if !active.insert(id) {
                        return Err(fault("cyclic constants"));
                    }
                    pending.push((id, true));
                    for dep in dependencies
                        .get(&id)
                        .ok_or_else(|| fault("unknown constant"))?
                        .iter()
                        .rev()
                    {
                        pending.push((*dep, false));
                    }
                }
            }
        }
        Ok(result)
    }
    fn index(&mut self, body: &'p Comp, var_count: u32) {
        let mut comps = vec![];
        let mut vals = vec![];
        walk(body, &mut comps, &mut vals);
        for value in vals {
            if let ValKind::Lambda(l) = &value.kind {
                self.add(l.id, &l.body, &l.params, None, var_count);
            }
        }
        for comp in comps {
            match &comp.kind {
                CompKind::Lazy { id, body } => self.add(*id, body, &[], None, var_count),
                CompKind::Handle(h) => {
                    self.add(h.id, &h.body, &[], None, var_count);
                    for c in &h.clauses {
                        self.add(c.id, &c.body, &c.params, Some(c.cont.id), var_count);
                    }
                }
                CompKind::Return(_)
                | CompKind::Let { .. }
                | CompKind::App { .. }
                | CompKind::Method(_)
                | CompKind::If { .. }
                | CompKind::Match { .. }
                | CompKind::Escape(_)
                | CompKind::Use { .. }
                | CompKind::Resume { .. } => {}
            }
        }
    }
    fn add(
        &mut self,
        id: BodyId,
        body: &'p Comp,
        params: &'p [Var],
        cont: Option<VarId>,
        var_count: u32,
    ) {
        let mut comps = vec![];
        let mut vals = vec![];
        walk(body, &mut comps, &mut vals);
        let mut bound: BTreeSet<_> = params.iter().map(|p| p.id).chain(cont).collect();
        let mut used = BTreeSet::new();
        for value in vals {
            match &value.kind {
                ValKind::Var(id) => {
                    used.insert(*id);
                }
                ValKind::Lambda(l) => bound.extend(l.params.iter().map(|p| p.id)),
                ValKind::Const(_)
                | ValKind::TopFn { .. }
                | ValKind::Builtin { .. }
                | ValKind::Op { .. }
                | ValKind::Ctor { .. }
                | ValKind::List(_)
                | ValKind::ConstRef(_) => {}
            }
        }
        for comp in comps {
            match &comp.kind {
                CompKind::Let { var, .. } => {
                    bound.insert(var.id);
                }
                CompKind::App { dicts, .. } => {
                    for d in dicts {
                        dict_vars(d, &mut used);
                    }
                }
                CompKind::Method(m) => {
                    dict_vars(&m.dict, &mut used);
                    for d in &m.dicts {
                        dict_vars(d, &mut used);
                    }
                }
                CompKind::Match { arms, .. } => {
                    for arm in arms {
                        bound.extend(arm.vars.iter().map(|v| v.id));
                    }
                }
                CompKind::Handle(h) => {
                    for clause in &h.clauses {
                        bound.extend(clause.params.iter().map(|p| p.id));
                        bound.insert(clause.cont.id);
                    }
                }
                CompKind::Resume { cont, .. } => {
                    used.insert(*cont);
                }
                CompKind::Return(_)
                | CompKind::If { .. }
                | CompKind::Escape(_)
                | CompKind::Use { .. }
                | CompKind::Lazy { .. } => {}
            }
        }
        self.bodies.insert(
            id,
            BodyInfo {
                body,
                params,
                free: used.difference(&bound).copied().collect(),
                var_count,
            },
        );
    }
}
fn fault(message: &str) -> Stop {
    Stop::Internal(message.into())
}
fn dict_vars(dict: &DictVal, used: &mut BTreeSet<VarId>) {
    match &dict.kind {
        DictKind::Param(id) => {
            used.insert(*id);
        }
        DictKind::Impl { args, .. } => {
            for d in args {
                dict_vars(d, used);
            }
        }
        DictKind::Super { of, .. } => dict_vars(of, used),
        DictKind::ImplParam(_) => {}
    }
}
fn walk<'p>(comp: &'p Comp, comps: &mut Vec<&'p Comp>, vals: &mut Vec<&'p CoreVal>) {
    comps.push(comp);
    match &comp.kind {
        CompKind::Return(v) | CompKind::Escape(v) | CompKind::Resume { value: v, .. } => {
            walk_val(v, comps, vals)
        }
        CompKind::Let { bound, body, .. } => {
            walk(bound, comps, vals);
            walk(body, comps, vals);
        }
        CompKind::App { func, args, .. } => {
            walk_val(func, comps, vals);
            for v in args {
                walk_val(v, comps, vals);
            }
        }
        CompKind::Method(m) => {
            for v in &m.args {
                walk_val(v, comps, vals);
            }
        }
        CompKind::If {
            cond,
            then_branch,
            else_branch,
        } => {
            walk_val(cond, comps, vals);
            walk(then_branch, comps, vals);
            walk(else_branch, comps, vals);
        }
        CompKind::Match {
            scrutinee, arms, ..
        } => {
            walk_val(scrutinee, comps, vals);
            for arm in arms {
                if let Some(g) = &arm.guard {
                    walk(g, comps, vals);
                }
                walk(&arm.body, comps, vals);
            }
        }
        CompKind::Use { resource, body } => {
            walk_val(resource, comps, vals);
            walk(body, comps, vals);
        }
        CompKind::Lazy { body, .. } => walk(body, comps, vals),
        CompKind::Handle(h) => {
            walk(&h.body, comps, vals);
            for c in &h.clauses {
                walk(&c.body, comps, vals);
            }
        }
    }
}
fn walk_val<'p>(v: &'p CoreVal, comps: &mut Vec<&'p Comp>, vals: &mut Vec<&'p CoreVal>) {
    vals.push(v);
    match &v.kind {
        ValKind::Lambda(l) => walk(&l.body, comps, vals),
        ValKind::Ctor { args, .. } | ValKind::List(args) => {
            for v in args {
                walk_val(v, comps, vals);
            }
        }
        ValKind::Var(_)
        | ValKind::Const(_)
        | ValKind::TopFn { .. }
        | ValKind::Builtin { .. }
        | ValKind::Op { .. }
        | ValKind::ConstRef(_) => {}
    }
}
