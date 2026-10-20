//! パターンの行列から判定の木を作り、コア IR を下位 IR に移す
//! （設計書 02-06「判定の木への変換」）。

use crate::base::{BindingId, Span};
use std::collections::HashMap;

mod arena;
#[cfg(test)]
mod block_tests;
mod rows;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::types::builtin::BuiltinTypeId;
use crate::types::{AdtTable, EffectSet, Ty, TyCon};
use arena::{DecisionArena, Edge, MatrixKey, Node, NodeId};

use super::InternalError;
use super::core_ir::*;
use super::lower_ir::*;

/// 行列のセル数 + 1 の合計の上限（設計書 02-06「判定の木への変換」、02-07「処理系の制限」）。
const MAX_TREE_WORK: usize = 600_000;
/// ガードの写しを含め、定義ごとに消費する合計の上限。
const MAX_DEF_TREE_WORK: usize = MAX_TREE_WORK * 4;

/// 判定の木への変換での処理系の制限と不具合。
#[derive(Debug)]
pub enum LowerError {
    Limit(Vec<Diagnostic>),
    Internal(InternalError),
}

/// コア IR の `match` を判定の木に置き換えて下位 IR を作る（02-06「判定の木への変換」）。
pub fn lower_program(program: &CoreProgram) -> Result<LowerProgram, LowerError> {
    let mut body_count = program.body_count;
    let mut defs = Vec::new();
    for def in &program.defs {
        defs.push(lower_def(def, &program.adts, &mut body_count)?);
    }
    let mut impls = Vec::new();
    for imp in &program.impls {
        let mut methods = Vec::new();
        for def in &imp.methods {
            methods.push(lower_def(def, &program.adts, &mut body_count)?);
        }
        impls.push(ImplDef {
            impl_decl: imp.impl_decl,
            class: imp.class,
            name: imp.name.clone(),
            origin: imp.origin,
            type_params: imp.type_params.clone(),
            target: imp.target.clone(),
            dict_params: imp.dict_params.clone(),
            supers: imp.supers.clone(),
            methods,
            span: imp.span,
        });
    }
    let mut consts = Vec::new();
    for def in &program.consts {
        let mut ctx = Lowerer::new(
            &program.adts,
            def.var_count,
            &mut body_count,
            &def.name,
            def.span,
        );
        let body = ctx.comp(&def.body, false)?;
        consts.push(ConstDef {
            binding: def.binding,
            name: def.name.clone(),
            ty: def.ty.clone(),
            body,
            value: def.value.clone(),
            span: def.span,
            var_count: ctx.var_count,
        });
    }
    Ok(Program {
        defs,
        impls,
        consts,
        ops: program.ops.clone(),
        adts: program.adts.clone(),
        traits: program.traits.clone(),
        schemes: program.schemes.clone(),
        main: program.main,
        main_returns_result: program.main_returns_result,
        body_count,
    })
}

fn error(message: &str) -> LowerError {
    LowerError::Internal(InternalError {
        stage: "decision",
        message: message.into(),
    })
}

fn index(n: u32) -> Result<usize, LowerError> {
    usize::try_from(n).map_err(|_| error("index does not fit usize"))
}

fn size(n: usize) -> Result<u32, LowerError> {
    u32::try_from(n).map_err(|_| error("length does not fit u32"))
}

fn fresh(counter: &mut u32) -> Result<u32, LowerError> {
    let n = *counter;
    *counter = n
        .checked_add(1)
        .ok_or_else(|| error("identifier space exhausted"))?;
    Ok(n)
}

fn builtin_ty(id: BuiltinTypeId) -> Ty {
    Ty::Con(TyCon::Builtin(id), Vec::new())
}

fn lower_def(def: &CoreDef, adts: &AdtTable, body_count: &mut u32) -> Result<LowerDef, LowerError> {
    let mut ctx = Lowerer::new(adts, def.var_count, body_count, &def.name, def.span);
    let body = ctx.comp(&def.body, false)?;
    Ok(Def {
        param_names: def.param_names.clone(),
        binding: def.binding,
        name: def.name.clone(),
        origin: def.origin,
        kind: def.kind,
        type_params: def.type_params.clone(),
        effect_params: def.effect_params.clone(),
        dict_params: def.dict_params.clone(),
        params: def.params.clone(),
        ret: def.ret.clone(),
        eff: def.eff.clone(),
        body,
        span: def.span,
        var_count: ctx.var_count,
    })
}

struct Lowerer<'a> {
    adts: &'a AdtTable,
    var_count: u32,
    join_count: u32,
    body_count: &'a mut u32,
    name: &'a str,
    tree_work: usize,
    def_tree_work: usize,
    match_origin: Span,
    arena: DecisionArena,
    def_nodes: usize,
    def_edges: usize,
}

impl<'a> Lowerer<'a> {
    fn new(
        adts: &'a AdtTable,
        var_count: u32,
        body_count: &'a mut u32,
        name: &'a str,
        origin: Span,
    ) -> Self {
        Self {
            adts,
            var_count,
            join_count: 0,
            body_count,
            name,
            tree_work: 0,
            def_tree_work: 0,
            match_origin: origin,
            arena: DecisionArena::default(),
            def_nodes: 0,
            def_edges: 0,
        }
    }

    fn var(&mut self, ty: Ty) -> Result<Var, LowerError> {
        Ok(Var {
            id: VarId(fresh(&mut self.var_count)?),
            name: None,
            ty,
        })
    }

    fn body_id(&mut self, id: BodyId, renew: bool) -> Result<BodyId, LowerError> {
        if renew {
            Ok(BodyId(fresh(self.body_count)?))
        } else {
            Ok(id)
        }
    }

    fn vals(&mut self, vals: &[CoreVal], renew: bool) -> Result<Vec<LowVal>, LowerError> {
        vals.iter().map(|v| self.val(v, renew)).collect()
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn val(&mut self, v: &CoreVal, renew: bool) -> Result<LowVal, LowerError> {
        let kind = match &v.kind {
            ValKind::Var(id) => ValKind::Var(*id),
            ValKind::Const(c) => ValKind::Const(c.clone()),
            ValKind::TopFn { def, targs } => ValKind::TopFn {
                def: *def,
                targs: targs.clone(),
            },
            ValKind::Builtin { id, targs, info } => ValKind::Builtin {
                id: *id,
                targs: targs.clone(),
                info: *info,
            },
            ValKind::External { def, spec } => ValKind::External {
                def: *def,
                spec: std::sync::Arc::clone(spec),
            },
            ValKind::Op { op, targs } => ValKind::Op {
                op: *op,
                targs: targs.clone(),
            },
            ValKind::Lambda(_) => return self.lower_lambda(v, renew),
            ValKind::Ctor {
                adt,
                tag,
                tys,
                args,
            } => ValKind::Ctor {
                adt: *adt,
                tag: *tag,
                tys: tys.clone(),
                args: self.vals(args, renew)?,
            },
            ValKind::List(vs) => ValKind::List(self.vals(vs, renew)?),
            ValKind::ConstRef(id) => ValKind::ConstRef(*id),
        };
        Ok(Val {
            kind,
            ty: v.ty.clone(),
            origin: v.origin,
        })
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_lambda(&mut self, v: &CoreVal, renew: bool) -> Result<LowVal, LowerError> {
        let ValKind::Lambda(lam) = &v.kind else {
            return Err(error("expected lambda"));
        };
        Ok(Val {
            kind: ValKind::Lambda(Box::new(Lambda {
                param_names: lam.param_names.clone(),
                id: self.body_id(lam.id, renew)?,
                params: lam.params.clone(),
                body: self.comp(&lam.body, renew)?,
                span: lam.span,
            })),
            ty: v.ty.clone(),
            origin: v.origin,
        })
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn comp(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        match &c.kind {
            CompKind::BuilderLet { .. } => self.lower_lets(c, renew),
            CompKind::BuilderOp { id, kind, op, args } => {
                let args = self.vals(args, renew)?;
                Ok(LComp {
                    kind: LCompKind::BuilderOp {
                        id: *id,
                        kind: kind.clone(),
                        op: *op,
                        args,
                    },
                    ty: c.ty.clone(),
                    eff: c.eff.clone(),
                    origin: c.origin,
                })
            }
            CompKind::Return(..) => self.lower_return(c, renew),
            CompKind::Let { .. } => self.lower_lets(c, renew),
            CompKind::App { .. } => self.lower_app(c, renew),
            CompKind::Method(..) => self.lower_method(c, renew),
            CompKind::If { .. } => self.lower_if(c, renew),
            CompKind::Match {
                scrutinee,
                rows,
                arms,
            } => self.match_comp(c, scrutinee, rows, arms, renew),
            CompKind::Escape(..) => self.lower_escape(c, renew),
            CompKind::Use { .. } => self.lower_use(c, renew),
            CompKind::Lazy { .. } => self.lower_lazy(c, renew),
            CompKind::Handle(..) => self.lower_handle(c, renew),
            CompKind::Resume { .. } => self.lower_resume(c, renew),
        }
    }
    // bound を下る途中で下ろし、番号と最初の誤りの順を保つ。属性は元の Let から写す
    // （設計書 02-06「判定の木への変換」、02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_lets(&mut self, mut c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let mut bindings = Vec::new();
        loop {
            if let CompKind::BuilderLet { body, .. } = &c.kind {
                bindings.push((c, None));
                c = body;
            } else if let CompKind::Let { bound, body, .. } = &c.kind {
                bindings.push((c, Some(self.comp(bound, renew)?)));
                c = body;
            } else {
                break;
            }
        }
        let body = self.comp(c, renew)?;
        Self::finish_lets(bindings, body)
    }
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_lets(
        bindings: Vec<(&Comp, Option<LComp>)>,
        mut body: LComp,
    ) -> Result<LComp, LowerError> {
        for (original, bound) in bindings.into_iter().rev() {
            let kind = if let CompKind::BuilderLet { id, kind, .. } = &original.kind {
                LCompKind::BuilderLet {
                    id: *id,
                    kind: kind.clone(),
                    body: Box::new(body),
                }
            } else if let CompKind::Let { var, .. } = &original.kind {
                LCompKind::Let {
                    var: var.clone(),
                    bound: Box::new(bound.ok_or_else(|| error("missing let bound"))?),
                    body: Box::new(body),
                }
            } else {
                return Err(error("expected binding"));
            };
            body = made(
                kind,
                original.ty.clone(),
                original.eff.clone(),
                original.origin,
            );
        }
        Ok(body)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_return(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Return(v) = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::Return(self.val(v, renew)?);
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_app(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::App {
            func,
            dicts,
            args,
            exit_report,
        } = &c.kind
        else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::App {
            func: self.val(func, renew)?,
            dicts: dicts.clone(),
            args: self.vals(args, renew)?,
            exit_report: exit_report
                .as_ref()
                .map(|r| -> Result<_, LowerError> {
                    Ok(ExitReportArgs {
                        cause: Box::new(self.val(&r.cause, renew)?),
                        message: r
                            .message
                            .as_ref()
                            .map(|v| self.val(v, renew).map(Box::new))
                            .transpose()?,
                    })
                })
                .transpose()?,
        };
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_method(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Method(m) = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::Method(Box::new(MethodCall {
            dict: m.dict.clone(),
            method: m.method,
            targs: m.targs.clone(),
            dicts: m.dicts.clone(),
            args: self.vals(&m.args, renew)?,
        }));
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_if(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::If {
            cond,
            then_branch,
            else_branch,
        } = &c.kind
        else {
            return Err(error("unexpected computation kind"));
        };
        let cond = self.val(cond, renew)?;
        let then_branch = self.comp(then_branch, renew)?;
        let else_branch = self.comp(else_branch, renew)?;
        Ok(Self::finish_if(c, cond, then_branch, else_branch))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_if(c: &Comp, cond: LowVal, then_branch: LComp, else_branch: LComp) -> LComp {
        let kind = LCompKind::If {
            cond,
            then_branch: Box::new(then_branch),
            else_branch: Box::new(else_branch),
        };
        made(kind, c.ty.clone(), c.eff.clone(), c.origin)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_escape(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Escape(v) = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::Escape(self.val(v, renew)?);
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_use(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Use { resource, body } = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::Use {
            resource: self.val(resource, renew)?,
            body: Box::new(self.comp(body, renew)?),
        };
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_lazy(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Lazy { id, body } = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::Lazy {
            id: self.body_id(*id, renew)?,
            body: Box::new(self.comp(body, renew)?),
        };
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_handle(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Handle(h) = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = {
            let id = self.body_id(h.id, renew)?;
            let body = self.comp(&h.body, renew)?;
            let mut clauses = Vec::new();
            for cl in &h.clauses {
                clauses.push(Clause {
                    failure_type: cl.failure_type.clone(),
                    id: self.body_id(cl.id, renew)?,
                    node: cl.node,
                    op: cl.op,
                    dict_params: cl.dict_params.clone(),
                    params: cl.params.clone(),
                    cont: cl.cont.clone(),
                    tail_resumptive: cl.tail_resumptive,
                    body: self.comp(&cl.body, renew)?,
                    span: cl.span,
                });
            }
            LCompKind::Handle(Box::new(Handle {
                id,
                body,
                clauses,
                handled: h.handled.clone(),
            }))
        };
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn lower_resume(&mut self, c: &Comp, renew: bool) -> Result<LComp, LowerError> {
        let CompKind::Resume { cont, value } = &c.kind else {
            return Err(error("unexpected computation kind"));
        };
        let kind = LCompKind::Resume {
            cont: *cont,
            value: self.val(value, renew)?,
        };
        Ok(made(kind, c.ty.clone(), c.eff.clone(), c.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn match_comp(
        &mut self,
        c: &Comp,
        scrutinee: &CoreVal,
        rows: &[MatchRow],
        arms: &[MatchArm],
        renew: bool,
    ) -> Result<LComp, LowerError> {
        let saved = (
            self.var_count,
            self.join_count,
            *self.body_count,
            self.tree_work,
            self.def_tree_work,
            self.match_origin,
            self.def_nodes,
            self.def_edges,
        );
        self.match_origin = c.origin;
        self.arena = DecisionArena::new(self.var_count, self.name, c.origin);
        let attempt = self.match_tree(c, scrutinee, rows, arms).and_then(|tree| {
            let counts = self.prepare_output(&tree, arms.len())?;
            Ok((tree, counts))
        });
        let (tree, counts) = match attempt {
            Ok(prepared) => prepared,
            Err(LowerError::Limit(_)) => {
                self.var_count = saved.0;
                self.join_count = saved.1;
                *self.body_count = saved.2;
                self.tree_work = saved.3;
                self.def_tree_work = saved.4;
                self.def_nodes = saved.6;
                self.def_edges = saved.7;
                self.arena = DecisionArena::new(self.var_count, self.name, c.origin);
                let tree = self.row_match(scrutinee, rows, arms)?;
                let counts = self.prepare_output(&tree, arms.len())?;
                (tree, counts)
            }
            Err(e) => return Err(e),
        };
        let mut arena = std::mem::take(&mut self.arena);
        let LoweredArms { labels, bodies } = self.match_bodies(arms, counts, renew)?;
        let node_labels = arena.labels(&tree, &mut self.join_count)?;
        let mut emitted = Emission {
            arms,
            labels: &labels,
            bodies,
            guard_seen: vec![false; arms.len()],
            ty: &c.ty,
            origin: c.origin,
            renew,
            arena: &mut arena,
            node_labels: &node_labels,
        };
        let mut body = self.emit(tree, &mut emitted)?;
        // 子は親より先に配列へ置く。子の join を外側へ置けば全ての参照がスコープ内になる。
        for i in (0..node_labels.len()).rev() {
            if let Some(label) = node_labels.get(i).copied().flatten() {
                let node = emitted.arena.take(NodeId(size(i)?))?;
                let handler = self.emit_node(node.kind, &mut emitted)?;
                let eff = handler.eff.union(&body.eff);
                body = made(
                    LCompKind::Join {
                        label,
                        params: node.params,
                        handler: Box::new(handler),
                        body: Box::new(body),
                    },
                    c.ty.clone(),
                    eff,
                    c.origin,
                );
            }
        }
        body = Self::finish_match(body, &mut emitted, &labels, arms, c)?;
        self.match_origin = saved.5;
        Ok(body)
    }
    // 表と Join/Jump を含む最終出力も共有判定の試行に含める。
    fn prepare_output(&mut self, tree: &Edge, arm_count: usize) -> Result<Vec<u32>, LowerError> {
        let mut arena = std::mem::take(&mut self.arena);
        arena.table(
            arena
                .nodes
                .len()
                .checked_mul(32)
                .ok_or_else(|| self.limit_error("table"))?,
        )?;
        let counts = arena.counts(tree, arm_count)?;
        let (joins, jumps) = arena.emission_cost(tree)?;
        self.reserve_output(
            &arena,
            joins
                .checked_add(counts.iter().filter(|n| **n > 1).count())
                .ok_or_else(|| self.limit_error("nodes"))?,
            jumps,
        )?;
        self.arena = arena;
        Ok(counts)
    }
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn match_tree(
        &mut self,
        c: &Comp,
        scrutinee: &CoreVal,
        rows: &[MatchRow],
        arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        let ValKind::Var(id) = scrutinee.kind else {
            return Err(error("match scrutinee is not a variable"));
        };
        let mut bytes = 0_usize;
        for row in rows {
            bytes = bytes
                .checked_add(
                    arena::pattern_bytes(&row.pattern).map_err(|_| self.limit_error("table"))?,
                )
                .ok_or_else(|| self.limit_error("table"))?;
        }
        self.arena.table(
            bytes
                .checked_mul(2)
                .ok_or_else(|| self.limit_error("table"))?,
        )?;
        let matrix = Matrix {
            columns: vec![Var {
                id,
                name: None,
                ty: scrutinee.ty.clone(),
            }],
            rows: rows
                .iter()
                .map(|r| {
                    Ok(Row {
                        patterns: vec![r.pattern.clone()],
                        arm: index(r.arm)?,
                        bindings: Vec::new(),
                    })
                })
                .collect::<Result<_, LowerError>>()?,
        };
        self.tree_work = 0;
        self.match_origin = c.origin;
        self.tree(matrix, arms)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn match_bodies(
        &mut self,
        arms: &[MatchArm],
        counts: Vec<u32>,
        renew: bool,
    ) -> Result<LoweredArms, LowerError> {
        let mut labels = Vec::new();
        let mut bodies = Vec::new();
        for (arm, count) in arms.iter().zip(counts) {
            labels.push(if count > 1 {
                Some(JoinId(fresh(&mut self.join_count)?))
            } else {
                None
            });
            bodies.push(if count > 0 {
                Some(self.comp(&arm.body, renew)?)
            } else {
                None
            });
        }
        Ok(LoweredArms { labels, bodies })
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_match(
        mut body: LComp,
        emitted: &mut Emission<'_>,
        labels: &[Option<JoinId>],
        arms: &[MatchArm],
        c: &Comp,
    ) -> Result<LComp, LowerError> {
        for (i, label) in labels.iter().enumerate().rev() {
            if let Some(label) = label {
                let handler = emitted
                    .bodies
                    .get_mut(i)
                    .and_then(Option::take)
                    .ok_or_else(|| error("missing join body"))?;
                let params = arms
                    .get(i)
                    .ok_or_else(|| error("missing join arm"))?
                    .vars
                    .clone();
                let eff = handler.eff.union(&body.eff);
                body = made(
                    LCompKind::Join {
                        label: *label,
                        params,
                        handler: Box::new(handler),
                        body: Box::new(body),
                    },
                    c.ty.clone(),
                    eff,
                    c.origin,
                );
            }
        }
        Ok(body)
    }
}

struct LoweredArms {
    labels: Vec<Option<JoinId>>,
    bodies: Vec<Option<LComp>>,
}

#[derive(Clone)]
enum Source {
    Column(Var),
    Slice { list: Var, front: u32, back: u32 },
}

#[derive(Clone)]
struct Row {
    patterns: Vec<CorePat>,
    arm: usize,
    bindings: Vec<(VarId, Source)>,
}

#[derive(Clone)]
struct Matrix {
    columns: Vec<Var>,
    rows: Vec<Row>,
}

// この中間の木には本体を置かず、葉から分岐の番号だけを参照する。
// 葉の数が分かる前に本体を複製しないためである（設計書 02-06「判定の木への変換」）。
enum Tree {
    Leaf {
        arm: usize,
        bindings: Vec<(VarId, Source)>,
        fallback: Option<Edge>,
    },
    Ctor {
        column: Var,
        adt: BindingId,
        arms: Vec<(u32, Vec<Var>, Edge)>,
        default: Option<Edge>,
    },
    Constant {
        column: Var,
        arms: Vec<(ConstTest, Edge)>,
        default: Option<Edge>,
    },
    Length {
        column: Var,
        exact: Vec<(u32, Edge)>,
        at_least: u32,
        otherwise: Edge,
    },
    Gets {
        list: Var,
        fields: Vec<(Var, ListEnd, u32)>,
        body: Edge,
    },
}

fn simple(p: &CorePat) -> bool {
    matches!(p, CorePat::Wild | CorePat::Var(_))
}

fn replace<T: Clone>(items: &[T], c: usize, with: &[T]) -> Result<Vec<T>, LowerError> {
    items.get(c).ok_or_else(|| error("missing matrix column"))?;
    Ok(items
        .iter()
        .take(c)
        .chain(with.iter())
        .chain(items.iter().skip(c).skip(1))
        .cloned()
        .collect())
}

impl Matrix {
    fn specialize<F>(
        &self,
        c: usize,
        fields: &[Var],
        arena: &mut DecisionArena,
        mut patterns: F,
    ) -> Result<Self, LowerError>
    where
        F: FnMut(&CorePat, &mut Vec<(VarId, Source)>) -> Result<Option<Vec<CorePat>>, LowerError>,
    {
        let bytes = self.allocation_bytes(fields.len());
        arena.table(bytes.unwrap_or(usize::MAX))?;
        let mut rows = Vec::new();
        for row in &self.rows {
            let pat = row
                .patterns
                .get(c)
                .ok_or_else(|| error("missing row column"))?;
            let mut bindings = row.bindings.clone();
            if let Some(ps) = patterns(pat, &mut bindings)? {
                if ps.len() != fields.len() {
                    return Err(error("pattern arity differs from field count"));
                }
                rows.push(Row {
                    patterns: replace(&row.patterns, c, &ps)?,
                    arm: row.arm,
                    bindings,
                });
            }
        }
        Ok(Self {
            columns: replace(&self.columns, c, fields)?,
            rows,
        })
    }

    fn default(&self, c: usize, arena: &mut DecisionArena) -> Result<Self, LowerError> {
        self.specialize(c, &[], arena, |pat, _| {
            Ok(matches!(pat, CorePat::Wild).then(Vec::new))
        })
    }
}

impl Lowerer<'_> {
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn tree(&mut self, mut matrix: Matrix, arms: &[MatchArm]) -> Result<Edge, LowerError> {
        // 特殊化した行列の幅も仕事として数える（設計書 02-06「判定の木への変換」）。
        let work = matrix
            .rows
            .iter()
            .fold(1_usize, |n, r| n.saturating_add(r.patterns.len()));
        self.tree_work = self.tree_work.saturating_add(work);
        // match の数えは作るたびに戻すが、共有判定の試行量は定義に積算する
        // （設計書 02-07「処理系の制限」）。
        self.def_tree_work = self.def_tree_work.saturating_add(work);
        if self.tree_work > MAX_TREE_WORK || self.def_tree_work > MAX_DEF_TREE_WORK {
            // この Limit は共有判定の試行内の印であり、必ず行照合へ切り替える。
            return Err(self.limit_error("nodes"));
        }
        // 全行で不要な列を除く。値の取り出し元は束縛として残してから正規化する。
        matrix.prune();
        if matrix
            .rows
            .first()
            .is_some_and(|r| r.patterns.iter().all(simple))
        {
            return self.build_tree(matrix, arms);
        }
        self.arena.table(
            matrix
                .allocation_bytes(0)
                .map_err(|_| self.limit_error("table"))?,
        )?;
        let (key, params) = MatrixKey::new(&matrix, self.arena.first_var)?;
        if let Some(id) = self.arena.memo.get(&key).copied() {
            return Ok(Edge { id, args: params });
        }
        let edge = self.build_tree(matrix, arms)?;
        self.arena
            .set_params(edge.id, params.clone())
            .map_err(|_| self.limit_error("table"))?;
        self.arena.memo.insert(key, edge.id);
        Ok(Edge {
            id: edge.id,
            args: params,
        })
    }

    #[inline(never)]
    fn build_tree(&mut self, mut matrix: Matrix, arms: &[MatchArm]) -> Result<Edge, LowerError> {
        // 手順 1: 網羅性検査を通った行列には行がある（設計書 02-06「判定の木への変換」）。
        let first = matrix
            .rows
            .first()
            .ok_or_else(|| error("empty pattern matrix"))?;
        if matrix
            .rows
            .iter()
            .any(|r| r.patterns.len() != matrix.columns.len())
        {
            return Err(error("matrix width mismatch"));
        }
        // 手順 2: 先頭の行が必ず照合するなら葉にする。ガード失敗時は同じ分岐の行をすべて飛ばす。
        if first.patterns.iter().all(simple) {
            return self.leaf_tree(matrix, arms);
        }
        // 手順 3: 先頭の行の最も左の検査を選び、消す列の変数パターンの束縛を記録する。
        let c = first
            .patterns
            .iter()
            .position(|p| !simple(p))
            .ok_or_else(|| error("no discriminating column"))?;
        let column = matrix
            .columns
            .get(c)
            .ok_or_else(|| error("missing matrix column"))?
            .clone();
        for row in &mut matrix.rows {
            let p = row
                .patterns
                .get_mut(c)
                .ok_or_else(|| error("missing row column"))?;
            if let CorePat::Var(id) = p {
                row.bindings.push((*id, Source::Column(column.clone())));
                *p = CorePat::Wild;
            }
        }
        match &column.ty {
            Ty::Con(TyCon::Adt(adt), args) => self.ctor_tree(&matrix, c, &column, *adt, args, arms),
            Ty::Con(TyCon::Builtin(b), _)
                if [
                    BuiltinTypeId::STRING,
                    BuiltinTypeId::BOOLEAN,
                    BuiltinTypeId::UNIT,
                ]
                .contains(b) =>
            {
                self.const_tree(&matrix, c, &column, *b, arms)
            }
            Ty::Con(TyCon::Builtin(b), _)
                if [BuiltinTypeId::INTEGER, BuiltinTypeId::CHARACTER].contains(b) =>
            {
                self.range_tree(&matrix, c, &column, *b, arms)
            }
            Ty::Con(TyCon::Builtin(b), args) if *b == BuiltinTypeId::LIST => {
                let elem = args
                    .first()
                    .ok_or_else(|| error("list has no element type"))?;
                self.list_tree(&matrix, c, &column, elem, arms)
            }
            Ty::Con(_, _) | Ty::Fn(_) | Ty::Param(_) | Ty::App(_, _) | Ty::Rigid { .. } => {
                Err(error("pattern tests an unsupported type"))
            }
        }
    }

    // 診断は上限を超えたときだけ作るため、再帰する枠に置かない（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[cold]
    #[inline(never)]
    fn limit_error(&self, note: &'static str) -> LowerError {
        LowerError::Limit(vec![
            DiagBuilder::new(DiagCode::L0112)
                .arg("name", self.name)
                .primary(self.match_origin)
                .note(note)
                .build(),
        ])
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn leaf_tree(&mut self, mut matrix: Matrix, arms: &[MatchArm]) -> Result<Edge, LowerError> {
        let first = matrix
            .rows
            .first()
            .ok_or_else(|| error("empty pattern matrix"))?;

        let mut bindings = first.bindings.clone();
        for (p, col) in first.patterns.iter().zip(&matrix.columns) {
            if let CorePat::Var(id) = p {
                bindings.push((*id, Source::Column(col.clone())));
            }
        }
        let arm = first.arm;
        let guarded = arms
            .get(arm)
            .ok_or_else(|| error("invalid arm index"))?
            .guard
            .is_some();
        let fallback = if guarded {
            matrix.rows = matrix
                .rows
                .into_iter()
                .skip(1)
                .filter(|r| r.arm != arm)
                .collect();
            Some(self.tree(matrix, arms)?)
        } else {
            None
        };
        self.node(Tree::Leaf {
            arm,
            bindings,
            fallback,
        })
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn ctor_tree(
        &mut self,
        m: &Matrix,
        c: usize,
        col: &Var,
        adt: BindingId,
        args: &[Ty],
        match_arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        // 手順 4: タグの昇順で構成子を分け、宣言の型引数を置き換えた引数の列を作る。
        let def = self
            .adts
            .get(adt)
            .ok_or_else(|| error("missing ADT definition"))?;
        let mut tags = Vec::new();
        for row in &m.rows {
            match row
                .patterns
                .get(c)
                .ok_or_else(|| error("missing row column"))?
            {
                CorePat::Ctor { adt: b, tag, .. } if *b == adt => tags.push(*tag),
                CorePat::Wild => (),
                CorePat::Var(_)
                | CorePat::Const(_)
                | CorePat::Ctor { .. }
                | CorePat::Range { .. }
                | CorePat::List { .. } => return Err(error("invalid ADT pattern")),
            }
        }
        tags.sort_unstable();
        tags.dedup();
        let has_default = def.ctors.iter().any(|ctor| !tags.contains(&ctor.tag));
        let mut arms = Vec::new();
        for tag in tags {
            let tys = self
                .adts
                .field_types(adt, tag, args)
                .ok_or_else(|| error("missing constructor field types"))?;
            let fields = tys
                .into_iter()
                .map(|t| self.var(t))
                .collect::<Result<Vec<_>, _>>()?;
            let specialized = m.specialize(c, &fields, &mut self.arena, |p, _| {
                Ok(match p {
                    CorePat::Wild => Some(vec![CorePat::Wild; fields.len()]),
                    CorePat::Ctor { tag: t, args, .. } if *t == tag => Some(args.clone()),
                    CorePat::Ctor { .. } => None,
                    CorePat::Var(_)
                    | CorePat::Const(_)
                    | CorePat::Range { .. }
                    | CorePat::List { .. } => return Err(error("invalid ADT pattern")),
                })
            })?;
            // 手順 8: 分けた行列の行順を保って手順 1 に戻る。
            arms.push((tag, fields, self.tree(specialized, match_arms)?));
        }
        let default = if has_default {
            {
                let next = m.default(c, &mut self.arena)?;
                Some(self.tree(next, match_arms)?)
            }
        } else {
            None
        };
        self.node(Tree::Ctor {
            column: col.clone(),
            adt,
            arms,
            default,
        })
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn const_tree(
        &mut self,
        m: &Matrix,
        c: usize,
        col: &Var,
        ty: BuiltinTypeId,
        match_arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        // 手順 5: 定数が最初に現れた順を保ち、同じ定数の行も元の順で残す。
        let mut constants = Vec::new();
        for row in &m.rows {
            match row
                .patterns
                .get(c)
                .ok_or_else(|| error("missing row column"))?
            {
                CorePat::Const(k)
                    if matches!(
                        (ty, k),
                        (BuiltinTypeId::STRING, Const::Str(_))
                            | (BuiltinTypeId::BOOLEAN, Const::Bool(_))
                            | (BuiltinTypeId::UNIT, Const::Unit)
                    ) =>
                {
                    if !constants.contains(k) {
                        constants.push(k.clone());
                    }
                }
                CorePat::Wild => (),
                CorePat::Var(_)
                | CorePat::Const(_)
                | CorePat::Ctor { .. }
                | CorePat::Range { .. }
                | CorePat::List { .. } => return Err(error("invalid constant pattern")),
            }
        }
        let has_default =
            ty == BuiltinTypeId::STRING || (ty == BuiltinTypeId::BOOLEAN && constants.len() < 2);
        let mut arms = Vec::new();
        for k in constants {
            let next = m.specialize(c, &[], &mut self.arena, |p, _| {
                Ok(match p {
                    CorePat::Wild => Some(Vec::new()),
                    CorePat::Const(other) => (other == &k).then(Vec::new),
                    CorePat::Var(_)
                    | CorePat::Ctor { .. }
                    | CorePat::Range { .. }
                    | CorePat::List { .. } => return Err(error("invalid constant pattern")),
                })
            })?;
            // 手順 8: 分岐ごとに手順 1 に戻る。
            arms.push((ConstTest::Eq(k), self.tree(next, match_arms)?));
        }
        let default = if has_default {
            {
                let next = m.default(c, &mut self.arena)?;
                Some(self.tree(next, match_arms)?)
            }
        } else {
            None
        };
        self.node(Tree::Constant {
            column: col.clone(),
            arms,
            default,
        })
    }
}

#[derive(Clone, Copy)]
struct Domain {
    character: bool,
}

impl Domain {
    fn value(self, k: &Const) -> Result<i64, LowerError> {
        match (self.character, k) {
            (false, Const::Int(n)) => Ok(*n),
            (true, Const::Char(c)) => Ok(i64::from(u32::from(*c))),
            _ => Err(error("invalid interval endpoint")),
        }
    }

    fn constant(self, n: i64) -> Result<Const, LowerError> {
        if self.character {
            Ok(Const::Char(
                u32::try_from(n)
                    .ok()
                    .and_then(char::from_u32)
                    .ok_or_else(|| error("invalid scalar value"))?,
            ))
        } else {
            Ok(Const::Int(n))
        }
    }

    fn next(self, n: i64) -> Option<i64> {
        if self.character && n == 0x10ffff {
            None
        } else if self.character && n == 0xd7ff {
            Some(0xe000)
        } else {
            n.checked_add(1)
        }
    }

    fn prev(self, n: i64) -> Option<i64> {
        if self.character && n == 0 {
            None
        } else if self.character && n == 0xe000 {
            Some(0xd7ff)
        } else {
            n.checked_sub(1)
        }
    }

    fn max(self) -> i64 {
        if self.character { 0x10ffff } else { i64::MAX }
    }

    fn interval(self, p: &CorePat) -> Result<Option<(i64, i64)>, LowerError> {
        let bounds = match p {
            CorePat::Wild => return Ok(None),
            CorePat::Const(k) => (self.value(k)?, self.value(k)?),
            CorePat::Range { lo, hi } => (self.value(lo)?, self.value(hi)?),
            CorePat::Var(_) | CorePat::Ctor { .. } | CorePat::List { .. } => {
                return Err(error("invalid interval pattern"));
            }
        };
        if bounds.0 > bounds.1 {
            return Err(error("reversed interval"));
        }
        Ok(Some(bounds))
    }
}

struct Interval {
    lo: i64,
    hi: i64,
    rows: Vec<usize>,
}

impl Lowerer<'_> {
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn range_tree(
        &mut self,
        m: &Matrix,
        c: usize,
        col: &Var,
        ty: BuiltinTypeId,
        match_arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        // 手順 6: 下端と上端の次の値で分ける。文字はサロゲートを飛ばし、最大値の次は作らない。
        let domain = Domain {
            character: ty == BuiltinTypeId::CHARACTER,
        };
        let mut intervals = Vec::new();
        let mut boundaries = Vec::new();
        for row in &m.rows {
            let p = row
                .patterns
                .get(c)
                .ok_or_else(|| error("missing row column"))?;
            let interval = domain.interval(p)?;
            if let Some((lo, hi)) = interval {
                boundaries.push(lo);
                if let Some(next) = domain.next(hi) {
                    boundaries.push(next);
                }
            }
            intervals.push(interval);
        }
        boundaries.sort_unstable();
        boundaries.dedup();
        let mut parts: Vec<Interval> = Vec::new();
        let mut starts = boundaries.iter().peekable();
        while let Some(&lo) = starts.next() {
            let hi = match starts.peek() {
                Some(&&next) => domain
                    .prev(next)
                    .ok_or_else(|| error("missing interval predecessor"))?,
                None => domain.max(),
            };
            let covered = intervals
                .iter()
                .any(|range| range.is_some_and(|(a, b)| a <= lo && lo <= b));
            if !covered {
                continue;
            }
            let rows: Vec<_> = intervals
                .iter()
                .enumerate()
                .filter_map(|(i, range)| range.is_none_or(|(a, b)| a <= lo && lo <= b).then_some(i))
                .collect();
            if let Some(prev) = parts.last_mut()
                && domain.next(prev.hi) == Some(lo)
                && prev.rows == rows
            {
                prev.hi = hi;
            } else {
                parts.push(Interval { lo, hi, rows });
            }
        }
        let min = if domain.character { 0 } else { i64::MIN };
        let exhaustive_domain = parts.first().is_some_and(|p| p.lo == min)
            && parts.last().is_some_and(|p| p.hi == domain.max())
            && parts.windows(2).all(|pair| match pair {
                [a, b] => domain.next(a.hi) == Some(b.lo),
                _ => false,
            });
        let mut arms = Vec::new();
        for part in parts {
            let next = m.specialize(c, &[], &mut self.arena, |p, _| {
                Ok(domain
                    .interval(p)?
                    .is_none_or(|(a, b)| a <= part.lo && part.lo <= b)
                    .then(Vec::new))
            })?;
            let lo = domain.constant(part.lo)?;
            let hi = domain.constant(part.hi)?;
            let test = if part.lo == part.hi {
                ConstTest::Eq(lo)
            } else {
                ConstTest::Range(lo, hi)
            };
            // 手順 8: 重なった行を並べ替えずに手順 1 に戻る。
            arms.push((test, self.tree(next, match_arms)?));
        }
        // 全域なら既定分岐には届かない。既定の行だけでは残りの列を網羅しない場合もある
        // （設計書 02-06「判定の木への変換」）。
        let default = if exhaustive_domain {
            None
        } else {
            {
                let next = m.default(c, &mut self.arena)?;
                Some(self.tree(next, match_arms)?)
            }
        };
        self.node(Tree::Constant {
            column: col.clone(),
            arms,
            default,
        })
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn list_tree(
        &mut self,
        m: &Matrix,
        c: usize,
        col: &Var,
        elem: &Ty,
        match_arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        // 手順 7: 最大の固定長 a と、残りのある行の前後の最大 p・s から分ける長さを決める。
        let mut a: Option<u32> = None;
        let mut p = 0_u32;
        let mut s = 0_u32;
        for row in &m.rows {
            match row
                .patterns
                .get(c)
                .ok_or_else(|| error("missing row column"))?
            {
                CorePat::List {
                    before,
                    rest,
                    after,
                } => {
                    let front = size(before.len())?;
                    let back = size(after.len())?;
                    if rest.is_some() {
                        p = p.max(front);
                        s = s.max(back);
                    } else {
                        let len = front
                            .checked_add(back)
                            .ok_or_else(|| error("list pattern length overflow"))?;
                        a = Some(a.map_or(len, |a| a.max(len)));
                    }
                }
                CorePat::Wild => (),
                CorePat::Var(_)
                | CorePat::Const(_)
                | CorePat::Ctor { .. }
                | CorePat::Range { .. } => return Err(error("invalid list pattern")),
            }
        }
        let min = p
            .checked_add(s)
            .ok_or_else(|| error("list pattern length overflow"))?;
        let fixed = match a {
            Some(a) => a
                .checked_add(1)
                .ok_or_else(|| error("list pattern length overflow"))?,
            None => 0,
        };
        let at_least = min.max(fixed);
        let mut exact = Vec::new();
        for k in 0..at_least {
            exact.push((
                k,
                self.list_branch(m, c, col, elem, (k, 0, false), match_arms)?,
            ));
        }
        let otherwise = self.list_branch(m, c, col, elem, (p, s, true), match_arms)?;
        self.node(Tree::Length {
            column: col.clone(),
            exact,
            at_least,
            otherwise,
        })
    }

    fn list_branch(
        &mut self,
        m: &Matrix,
        c: usize,
        col: &Var,
        elem: &Ty,
        ends: (u32, u32, bool),
        match_arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        let (front, back, unbounded) = ends;
        let mut gets = Vec::new();
        for i in 0..front {
            gets.push((self.var(elem.clone())?, ListEnd::Front, i));
        }
        for j in 0..back {
            gets.push((self.var(elem.clone())?, ListEnd::Back, j));
        }
        let fields: Vec<_> = gets.iter().map(|(v, _, _)| v.clone()).collect();
        let length = front
            .checked_add(back)
            .ok_or_else(|| error("list pattern length overflow"))?;
        let next = m.specialize(c, &fields, &mut self.arena, |pat, bindings| {
            let CorePat::List {
                before,
                rest,
                after,
            } = pat
            else {
                return if matches!(pat, CorePat::Wild) {
                    Ok(Some(vec![CorePat::Wild; fields.len()]))
                } else {
                    Err(error("invalid list pattern"))
                };
            };
            let fixed = before
                .len()
                .checked_add(after.len())
                .ok_or_else(|| error("list pattern length overflow"))?;
            if unbounded && rest.is_none()
                || (!unbounded
                    && if rest.is_some() {
                        fixed > index(length)?
                    } else {
                        fixed != index(length)?
                    })
            {
                return Ok(None);
            }
            let mut ps = vec![CorePat::Wild; fields.len()];
            for (i, p) in before.iter().enumerate() {
                *ps.get_mut(i)
                    .ok_or_else(|| error("list prefix exceeds extracted fields"))? = p.clone();
            }
            for (j, p) in after.iter().rev().enumerate() {
                let pos = if unbounded {
                    index(front)?.checked_add(j)
                } else {
                    fields
                        .len()
                        .checked_sub(1)
                        .and_then(|last| last.checked_sub(j))
                }
                .ok_or_else(|| error("list suffix index overflow"))?;
                *ps.get_mut(pos)
                    .ok_or_else(|| error("list suffix exceeds extracted fields"))? = p.clone();
            }
            if let Some(ListRest { var: Some(id) }) = rest {
                bindings.push((
                    *id,
                    Source::Slice {
                        list: col.clone(),
                        front: size(before.len())?,
                        back: size(after.len())?,
                    },
                ));
            }
            Ok(Some(ps))
        })?;
        // 手順 8: 長さを確かめて取り出した列について手順 1 に戻る。
        let body = self.tree(next, match_arms)?;
        self.node(Tree::Gets {
            list: col.clone(),
            fields: gets,
            body,
        })
    }
}

fn made(kind: LCompKind, ty: Ty, eff: EffectSet, origin: Span) -> LComp {
    LComp {
        kind,
        ty,
        eff,
        origin,
    }
}

fn variable(var: &Var, origin: Span) -> LowVal {
    Val {
        kind: ValKind::Var(var.id),
        ty: var.ty.clone(),
        origin,
    }
}

fn let_comp(var: Var, bound: LComp, body: LComp, origin: Span) -> LComp {
    let ty = body.ty.clone();
    let eff = bound.eff.union(&body.eff);
    made(
        LCompKind::Let {
            var,
            bound: Box::new(bound),
            body: Box::new(body),
        },
        ty,
        eff,
        origin,
    )
}

struct Emission<'a> {
    arena: &'a mut DecisionArena,
    node_labels: &'a [Option<JoinId>],
    arms: &'a [MatchArm],
    labels: &'a [Option<JoinId>],
    bodies: Vec<Option<LComp>>,
    guard_seen: Vec<bool>,
    ty: &'a Ty,
    origin: Span,
    renew: bool,
}

impl Lowerer<'_> {
    #[inline(never)]
    fn emit(&mut self, edge: Edge, e: &mut Emission<'_>) -> Result<LComp, LowerError> {
        if let Some(label) = e.node_labels.get(index(edge.id.0)?).copied().flatten() {
            return Self::emit_jump(label, edge.args, e);
        }
        let node = e.arena.take(edge.id)?;
        self.emit_node(node.kind, e)
    }

    // Jump の構築用の値を、木を再帰で辿る枠へ置かない
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_jump(label: JoinId, args: Vec<Var>, e: &Emission<'_>) -> Result<LComp, LowerError> {
        Ok(made(
            LCompKind::Jump {
                label,
                args: args.iter().map(|v| variable(v, e.origin)).collect(),
            },
            e.ty.clone(),
            EffectSet::empty(),
            e.origin,
        ))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_node(&mut self, tree: Tree, e: &mut Emission<'_>) -> Result<LComp, LowerError> {
        match tree {
            Tree::Leaf {
                arm,
                bindings,
                fallback,
            } => self.leaf(arm, bindings, fallback, e),
            tree @ Tree::Ctor { .. } => self.emit_ctor(tree, e),
            tree @ Tree::Constant { .. } => self.emit_constant(tree, e),
            tree @ Tree::Length { .. } => self.emit_length(tree, e),
            tree @ Tree::Gets { .. } => self.emit_gets(tree, e),
        }
    }
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_ctor(&mut self, tree: Tree, e: &mut Emission<'_>) -> Result<LComp, LowerError> {
        let Tree::Ctor {
            column,
            adt,
            arms,
            default,
        } = tree
        else {
            return Err(error("unexpected decision tree"));
        };
        let mut eff = EffectSet::empty();
        let mut out = Vec::new();
        for (tag, fields, body) in arms {
            let body = self.emit(body, e)?;
            eff = eff.union(&body.eff);
            out.push(CtorArm { tag, fields, body });
        }
        let default = self.emit_default(default, e)?;
        if let Some(body) = &default {
            eff = eff.union(&body.eff);
        }
        let kind = LCompKind::CaseCtor {
            scrutinee: variable(&column, e.origin),
            adt,
            arms: out,
            default,
        };
        Ok(made(kind, e.ty.clone(), eff, e.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_constant(&mut self, tree: Tree, e: &mut Emission<'_>) -> Result<LComp, LowerError> {
        let Tree::Constant {
            column,
            arms,
            default,
        } = tree
        else {
            return Err(error("unexpected decision tree"));
        };
        let mut eff = EffectSet::empty();
        let mut out = Vec::new();
        for (test, body) in arms {
            let body = self.emit(body, e)?;
            eff = eff.union(&body.eff);
            out.push(ConstArm { test, body });
        }
        let default = self.emit_default(default, e)?;
        if let Some(body) = &default {
            eff = eff.union(&body.eff);
        }
        let kind = LCompKind::CaseConst {
            scrutinee: variable(&column, e.origin),
            arms: out,
            default,
        };
        Ok(made(kind, e.ty.clone(), eff, e.origin))
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_length(&mut self, tree: Tree, e: &mut Emission<'_>) -> Result<LComp, LowerError> {
        let Tree::Length {
            column,
            exact,
            at_least,
            otherwise,
        } = tree
        else {
            return Err(error("unexpected decision tree"));
        };
        let mut eff = EffectSet::empty();
        let mut out = Vec::new();
        for (len, body) in exact {
            let body = self.emit(body, e)?;
            eff = eff.union(&body.eff);
            out.push(LengthArm { len, body });
        }
        let otherwise = self.emit(otherwise, e)?;
        eff = eff.union(&otherwise.eff);
        Ok(Self::finish_length(
            column, out, at_least, otherwise, eff, e,
        ))
    }

    // 子を下ろした後の組み立て用の値を、再帰の間は保持しない
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_length(
        column: Var,
        exact: Vec<LengthArm>,
        at_least: u32,
        otherwise: LComp,
        eff: EffectSet,
        e: &Emission<'_>,
    ) -> LComp {
        made(
            LCompKind::CaseLength {
                scrutinee: variable(&column, e.origin),
                exact,
                at_least,
                otherwise: Box::new(otherwise),
            },
            e.ty.clone(),
            eff,
            e.origin,
        )
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_gets(&mut self, tree: Tree, e: &mut Emission<'_>) -> Result<LComp, LowerError> {
        let Tree::Gets { list, fields, body } = tree else {
            return Err(error("unexpected decision tree"));
        };
        let body = self.emit(body, e)?;
        Ok(Self::finish_gets(list, fields, body, e.origin))
    }

    // ListGet と Let の組み立ては再帰から戻ってから行う
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_gets(
        list: Var,
        fields: Vec<(Var, ListEnd, u32)>,
        mut body: LComp,
        origin: Span,
    ) -> LComp {
        for (var, from, index) in fields.into_iter().rev() {
            let bound = made(
                LCompKind::ListGet {
                    list: variable(&list, origin),
                    from,
                    index,
                },
                var.ty.clone(),
                EffectSet::empty(),
                origin,
            );
            body = let_comp(var, bound, body, origin);
        }
        body
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn emit_default(
        &mut self,
        tree: Option<Edge>,
        e: &mut Emission<'_>,
    ) -> Result<Option<Box<LComp>>, LowerError> {
        tree.map(|t| self.emit(t, e).map(Box::new)).transpose()
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn leaf(
        &mut self,
        arm: usize,
        bindings: Vec<(VarId, Source)>,
        fallback: Option<Edge>,
        e: &mut Emission<'_>,
    ) -> Result<LComp, LowerError> {
        let branch = e.arms.get(arm).ok_or_else(|| error("invalid arm index"))?;
        let mut body = Self::leaf_body(branch, &bindings, arm, e)?;
        if let Some(guard) = &branch.guard {
            body = self.leaf_guard(body, guard, fallback, arm, e)?;
        }
        Self::finish_leaf(branch, bindings, body, e)
    }
    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn finish_leaf(
        branch: &MatchArm,
        bindings: Vec<(VarId, Source)>,
        mut body: LComp,
        e: &Emission<'_>,
    ) -> Result<LComp, LowerError> {
        for (id, source) in bindings.into_iter().rev() {
            let var = branch
                .vars
                .iter()
                .find(|v| v.id == id)
                .ok_or_else(|| error("pattern variable missing from arm"))?
                .clone();
            let bound = match source {
                Source::Column(col) => made(
                    LCompKind::Return(variable(&col, e.origin)),
                    col.ty.clone(),
                    EffectSet::empty(),
                    e.origin,
                ),
                Source::Slice { list, front, back } => made(
                    LCompKind::ListSlice {
                        list: variable(&list, e.origin),
                        drop_front: front,
                        drop_back: back,
                    },
                    list.ty.clone(),
                    EffectSet::empty(),
                    e.origin,
                ),
            };
            body = let_comp(var, bound, body, e.origin);
        }
        Ok(body)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn leaf_body(
        branch: &MatchArm,
        bindings: &[(VarId, Source)],
        arm: usize,
        e: &mut Emission<'_>,
    ) -> Result<LComp, LowerError> {
        // 束縛済みの変数を渡すので、slice の計算を jump の引数で重ねない（設計書 02-06「判定の木への変換」）。
        let body = if let Some(label) = e
            .labels
            .get(arm)
            .ok_or_else(|| error("missing join label"))?
        {
            let args = branch
                .vars
                .iter()
                .map(|v| {
                    if bindings.iter().any(|(id, _)| *id == v.id) {
                        Ok(variable(v, e.origin))
                    } else {
                        Err(error("missing pattern variable binding"))
                    }
                })
                .collect::<Result<_, _>>()?;
            made(
                LCompKind::Jump {
                    label: *label,
                    args,
                },
                e.ty.clone(),
                EffectSet::empty(),
                e.origin,
            )
        } else {
            e.bodies
                .get_mut(arm)
                .and_then(Option::take)
                .ok_or_else(|| error("missing arm body"))?
        };
        Ok(body)
    }

    // 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
    #[inline(never)]
    fn leaf_guard(
        &mut self,
        body: LComp,
        guard: &Comp,
        fallback: Option<Edge>,
        arm: usize,
        e: &mut Emission<'_>,
    ) -> Result<LComp, LowerError> {
        let seen = e
            .guard_seen
            .get_mut(arm)
            .ok_or_else(|| error("missing guard state"))?;
        let renew = e.renew || *seen;
        *seen = true;
        let guard = self.comp(guard, renew)?;
        let g = self.var(builtin_ty(BuiltinTypeId::BOOLEAN))?;
        let fallback = self.emit(fallback.ok_or_else(|| error("missing guard fallback"))?, e)?;
        let eff = body.eff.union(&fallback.eff);
        let choice = made(
            LCompKind::If {
                cond: variable(&g, e.origin),
                then_branch: Box::new(body),
                else_branch: Box::new(fallback),
            },
            e.ty.clone(),
            eff,
            e.origin,
        );
        Ok(let_comp(g, guard, choice, e.origin))
    }
}

#[cfg(test)]
mod tests {
    // 作成時の関門: 公開の変換の出力で、行順・束縛・本体の共有・番号の一意性を確かめる。
    // 最小実行版から移したテストは初回リリース版の拡張を通らない。二つの評価器の比較は
    // 分岐の選び方を誤る退行を捕まえ、木の形の検査はコード生成へ渡す契約を守る。
    // 非公開の補助やテスト専用の本番の差し込み口は使わない（設計書 07-03「テストの設計の原則」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;
    use crate::base::{BindingMap, BytePos, FileId, ModuleId, NodeId};
    use crate::builtins::{BuiltinId, iface::Capability};
    use crate::types::builtin::BuiltinEffectId;
    use crate::types::{
        AdtDef, CtorDef, EffVar, EffectName, FieldInfo, FnTy, TypeArgs, TypeSummary,
    };
    use std::collections::{BTreeMap, BTreeSet};

    const OPTION: BindingId = BindingId(10);
    const THREE: BindingId = BindingId(20);
    const RECORD: BindingId = BindingId(30);
    const OBS: BindingId = BindingId(40);
    const PAIR: BindingId = BindingId(50);

    fn span() -> Span {
        Span {
            file: FileId(0),
            start: BytePos(10),
            end: BytePos(20),
        }
    }
    fn other_span() -> Span {
        Span {
            file: FileId(0),
            start: BytePos(30),
            end: BytePos(40),
        }
    }
    fn bool_ty() -> Ty {
        builtin_ty(BuiltinTypeId::BOOLEAN)
    }
    fn int_ty() -> Ty {
        builtin_ty(BuiltinTypeId::INTEGER)
    }
    fn list_ty(t: Ty) -> Ty {
        Ty::Con(TyCon::Builtin(BuiltinTypeId::LIST), vec![t])
    }
    fn adt_ty(b: BindingId, args: Vec<Ty>) -> Ty {
        Ty::Con(TyCon::Adt(b), args)
    }
    fn var(id: u32, ty: Ty) -> Var {
        Var {
            id: VarId(id),
            name: Some(format!("v{id}")),
            ty,
        }
    }
    fn vval(v: &Var) -> CoreVal {
        Val {
            kind: ValKind::Var(v.id),
            ty: v.ty.clone(),
            origin: span(),
        }
    }
    fn val(kind: ValKind<Comp>, ty: Ty) -> CoreVal {
        Val {
            kind,
            ty,
            origin: span(),
        }
    }
    fn ret(v: CoreVal) -> Comp {
        Comp {
            ty: v.ty.clone(),
            kind: CompKind::Return(v),
            eff: EffectSet::empty(),
            origin: other_span(),
        }
    }
    fn boolean(b: bool) -> Comp {
        ret(val(ValKind::Const(Const::Bool(b)), bool_ty()))
    }
    fn integer(i: i64) -> Comp {
        ret(val(ValKind::Const(Const::Int(i)), int_ty()))
    }
    fn pat_bool(b: bool) -> CorePat {
        CorePat::Const(Const::Bool(b))
    }
    fn pat_int(n: i64) -> CorePat {
        CorePat::Const(Const::Int(n))
    }
    fn pat_str(s: &str) -> CorePat {
        CorePat::Const(Const::Str(s.into()))
    }
    fn range(a: i64, b: i64) -> CorePat {
        CorePat::Range {
            lo: Const::Int(a),
            hi: Const::Int(b),
        }
    }
    fn ctor(adt: BindingId, tag: u32, args: Vec<CorePat>) -> CorePat {
        CorePat::Ctor { adt, tag, args }
    }
    fn list(before: Vec<CorePat>, rest: Option<Option<u32>>, after: Vec<CorePat>) -> CorePat {
        CorePat::List {
            before,
            rest: rest.map(|v| ListRest { var: v.map(VarId) }),
            after,
        }
    }
    fn arm(n: u32, vars: Vec<Var>, guard: Option<Comp>) -> MatchArm {
        let body = ret(val(
            ValKind::Ctor {
                adt: OBS,
                tag: n,
                tys: vec![],
                args: vars.iter().map(vval).collect(),
            },
            adt_ty(OBS, vec![]),
        ));
        MatchArm { vars, guard, body }
    }
    fn matching(scrutinee: CoreVal, rows: Vec<(CorePat, u32)>, arms: Vec<MatchArm>) -> Comp {
        let eff = arms
            .iter()
            .fold(EffectSet::empty(), |e, a| e.union(&a.body.eff));
        Comp {
            kind: CompKind::Match {
                scrutinee,
                rows: rows
                    .into_iter()
                    .map(|(pattern, arm)| MatchRow { pattern, arm })
                    .collect(),
                arms,
            },
            ty: adt_ty(OBS, vec![]),
            eff,
            origin: span(),
        }
    }
    fn adts() -> AdtTable {
        let mut table = AdtTable::default();
        for (binding, params, fields, record) in [
            (
                OPTION,
                vec!["T".into()],
                vec![vec![], vec![Ty::Param(0)]],
                None,
            ),
            (THREE, vec![], vec![vec![], vec![], vec![]], None),
            (
                PAIR,
                vec!["A".into(), "B".into()],
                vec![vec![Ty::Param(0), Ty::Param(1)]],
                None,
            ),
            (
                RECORD,
                vec![],
                vec![vec![bool_ty(), int_ty()]],
                Some(vec![
                    FieldInfo {
                        name: "flag".into(),
                        binding: BindingId(31),
                    },
                    FieldInfo {
                        name: "count".into(),
                        binding: BindingId(32),
                    },
                ]),
            ),
        ] {
            let ctors = fields
                .into_iter()
                .enumerate()
                .map(|(i, fields)| CtorDef {
                    name: format!("C{i}"),
                    binding: BindingId(binding.0 + 1 + u32::try_from(i).unwrap()),
                    tag: u32::try_from(i).unwrap(),
                    fields,
                })
                .collect();
            table.adts.insert(
                binding,
                AdtDef {
                    extensible: false,
                    binding,
                    name: format!("D{}", binding.0),
                    module: ModuleId(0),
                    type_params: params,
                    ctors,
                    record,
                    eq_summary: TypeSummary::default(),
                    key_summary: TypeSummary::default(),
                },
            );
        }
        table
    }
    fn program(body: Comp) -> CoreProgram {
        Program {
            defs: vec![Def {
                param_names: Vec::new(),
                binding: BindingId(0),
                name: "main".into(),
                origin: DefOrigin::User,
                kind: DefKind::Fn,
                type_params: vec![],
                effect_params: vec![],
                dict_params: vec![],
                params: vec![],
                ret: body.ty.clone(),
                eff: body.eff.clone(),
                body,
                span: span(),
                var_count: 100,
            }],
            impls: vec![],
            consts: vec![],
            ops: vec![],
            adts: adts(),
            traits: BindingMap::new(),
            schemes: BindingMap::new(),
            main: Some(BindingId(0)),
            main_returns_result: false,
            body_count: 10,
        }
    }
    fn lower(body: Comp) -> LComp {
        lower_program(&program(body)).unwrap().defs.remove(0).body
    }

    fn visit(c: &LComp, f: &mut impl FnMut(&LComp)) {
        f(c);
        match &c.kind {
            LCompKind::BuilderLet { body, .. } => visit(body, f),
            LCompKind::BuilderOp { args, .. } => {
                for v in args {
                    visit_val(v, f);
                }
            }
            LCompKind::Let { bound, body, .. } => {
                visit(bound, f);
                visit(body, f);
            }
            LCompKind::If {
                cond,
                then_branch,
                else_branch,
            } => {
                visit_val(cond, f);
                visit(then_branch, f);
                visit(else_branch, f);
            }
            LCompKind::CaseCtor { arms, default, .. } => {
                for a in arms {
                    visit(&a.body, f);
                }
                if let Some(c) = default {
                    visit(c, f);
                }
            }
            LCompKind::CaseConst { arms, default, .. } => {
                for a in arms {
                    visit(&a.body, f);
                }
                if let Some(c) = default {
                    visit(c, f);
                }
            }
            LCompKind::CaseLength {
                exact, otherwise, ..
            } => {
                for a in exact {
                    visit(&a.body, f);
                }
                visit(otherwise, f);
            }
            LCompKind::Join { handler, body, .. } => {
                visit(handler, f);
                visit(body, f);
            }
            LCompKind::Use { resource, body } => {
                visit_val(resource, f);
                visit(body, f);
            }
            LCompKind::Lazy { body, .. } => visit(body, f),
            LCompKind::Handle(h) => {
                visit(&h.body, f);
                for cl in &h.clauses {
                    visit(&cl.body, f);
                }
            }
            LCompKind::Return(v) | LCompKind::Escape(v) => visit_val(v, f),
            LCompKind::Resume { value, .. } => visit_val(value, f),
            LCompKind::App { func, args, .. } => {
                visit_val(func, f);
                for v in args {
                    visit_val(v, f);
                }
            }
            LCompKind::Method(m) => {
                for v in &m.args {
                    visit_val(v, f);
                }
            }
            LCompKind::ListGet { .. } | LCompKind::ListSlice { .. } | LCompKind::Jump { .. } => (),
        }
    }
    fn visit_val(v: &LowVal, f: &mut impl FnMut(&LComp)) {
        match &v.kind {
            ValKind::Lambda(l) => visit(&l.body, f),
            ValKind::Ctor { args, .. } | ValKind::List(args) => {
                for v in args {
                    visit_val(v, f);
                }
            }
            ValKind::Var(_)
            | ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::External { .. }
            | ValKind::Op { .. }
            | ValKind::ConstRef(_) => (),
        }
    }

    #[derive(Clone, Debug, PartialEq)]
    enum Value {
        Const(Const),
        Ctor(BindingId, u32, Vec<Value>),
        List(Vec<Value>),
    }
    type Env = BTreeMap<VarId, Value>;
    fn bvalue(b: bool) -> Value {
        Value::Const(Const::Bool(b))
    }
    fn ivalue(n: i64) -> Value {
        Value::Const(Const::Int(n))
    }
    fn eval_val<C>(v: &Val<C>, env: &Env) -> Value {
        match &v.kind {
            ValKind::Var(id) => env.get(id).expect("bound variable").clone(),
            ValKind::Const(c) => Value::Const(c.clone()),
            ValKind::Ctor { adt, tag, args, .. } => {
                Value::Ctor(*adt, *tag, args.iter().map(|v| eval_val(v, env)).collect())
            }
            ValKind::List(vs) => Value::List(vs.iter().map(|v| eval_val(v, env)).collect()),
            ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::External { .. }
            | ValKind::Op { .. }
            | ValKind::Lambda(_)
            | ValKind::ConstRef(_) => panic!("unsupported test value"),
        }
    }
    fn in_range(value: &Value, lo: &Const, hi: &Const) -> bool {
        match (value, lo, hi) {
            (Value::Const(Const::Int(n)), Const::Int(a), Const::Int(b)) => a <= n && n <= b,
            (Value::Const(Const::Char(n)), Const::Char(a), Const::Char(b)) => a <= n && n <= b,
            _ => panic!("invalid range in test"),
        }
    }
    fn matches(p: &CorePat, v: &Value, env: &mut Env) -> bool {
        // 行を順に照合する評価器は、行列の特殊化も判定の木も使わない。
        let mut pending = vec![(p, v)];
        while let Some((p, v)) = pending.pop() {
            match (p, v) {
                (CorePat::Wild, _) => (),
                (CorePat::Var(id), _) => {
                    env.insert(*id, v.clone());
                }
                (CorePat::Const(c), Value::Const(d)) if c == d => (),
                (CorePat::Range { lo, hi }, _) if in_range(v, lo, hi) => (),
                (CorePat::Ctor { adt, tag, args }, Value::Ctor(b, t, vs))
                    if adt == b && tag == t && args.len() == vs.len() =>
                {
                    pending.extend(args.iter().zip(vs));
                }
                (
                    CorePat::List {
                        before,
                        rest,
                        after,
                    },
                    Value::List(vs),
                ) => {
                    let fixed = before.len() + after.len();
                    if vs.len() < fixed || rest.is_none() && vs.len() != fixed {
                        return false;
                    }
                    pending.extend(before.iter().zip(vs));
                    pending.extend(after.iter().rev().zip(vs.iter().rev()));
                    if let Some(ListRest { var: Some(id) }) = rest {
                        env.insert(
                            *id,
                            Value::List(vs[before.len()..vs.len() - after.len()].to_vec()),
                        );
                    }
                }
                _ => return false,
            }
        }
        true
    }
    fn eval_core(c: &Comp, env: &Env) -> Value {
        match &c.kind {
            CompKind::BuilderLet { .. } | CompKind::BuilderOp { .. } => {
                panic!("builder outside pattern evaluation fixture")
            }
            CompKind::Return(v) => eval_val(v, env),
            CompKind::Let { var, bound, body } => {
                let value = eval_core(bound, env);
                let mut env = env.clone();
                env.insert(var.id, value);
                eval_core(body, &env)
            }
            CompKind::If {
                cond,
                then_branch,
                else_branch,
            } => eval_core(
                if eval_val(cond, env) == bvalue(true) {
                    then_branch
                } else {
                    else_branch
                },
                env,
            ),
            CompKind::Match {
                scrutinee,
                rows,
                arms,
            } => {
                let v = eval_val(scrutinee, env);
                let mut skipped = BTreeSet::new();
                for row in rows {
                    if skipped.contains(&row.arm) {
                        continue;
                    }
                    let mut bound = env.clone();
                    if !matches(&row.pattern, &v, &mut bound) {
                        continue;
                    }
                    let arm = &arms[usize::try_from(row.arm).unwrap()];
                    if arm
                        .guard
                        .as_ref()
                        .is_some_and(|g| eval_core(g, &bound) == bvalue(false))
                    {
                        skipped.insert(row.arm);
                        continue;
                    }
                    return eval_core(&arm.body, &bound);
                }
                panic!("nonexhaustive test match")
            }
            CompKind::App { .. }
            | CompKind::Method(_)
            | CompKind::Escape(_)
            | CompKind::Use { .. }
            | CompKind::Lazy { .. }
            | CompKind::Handle(_)
            | CompKind::Resume { .. } => panic!("unsupported test computation"),
        }
    }
    fn eval_low<'a>(mut c: &'a LComp, initial: &Env) -> Value {
        let mut env = initial.clone();
        let mut joins: Vec<(JoinId, &'a [Var], &'a LComp, Env)> = Vec::new();
        loop {
            match &c.kind {
                LCompKind::BuilderLet { .. } | LCompKind::BuilderOp { .. } => {
                    panic!("builder outside pattern evaluation fixture")
                }
                LCompKind::Return(v) => return eval_val(v, &env),
                LCompKind::Let { var, bound, body } => {
                    let v = eval_low(bound, &env);
                    env.insert(var.id, v);
                    c = body;
                }
                LCompKind::If {
                    cond,
                    then_branch,
                    else_branch,
                } => {
                    c = if eval_val(cond, &env) == bvalue(true) {
                        then_branch
                    } else {
                        else_branch
                    }
                }
                LCompKind::CaseCtor {
                    scrutinee,
                    adt,
                    arms,
                    default,
                } => {
                    let Value::Ctor(b, tag, vs) = eval_val(scrutinee, &env) else {
                        panic!("expected ctor");
                    };
                    assert_eq!(*adt, b);
                    if let Some(a) = arms.iter().find(|a| a.tag == tag) {
                        for (field, v) in a.fields.iter().zip(vs) {
                            env.insert(field.id, v);
                        }
                        c = &a.body;
                    } else {
                        c = default.as_ref().expect("ctor default");
                    }
                }
                LCompKind::CaseConst {
                    scrutinee,
                    arms,
                    default,
                } => {
                    let v = eval_val(scrutinee, &env);
                    c = arms
                        .iter()
                        .find(|a| match &a.test {
                            ConstTest::Eq(k) => v == Value::Const(k.clone()),
                            ConstTest::Range(a, b) => in_range(&v, a, b),
                        })
                        .map(|a| &a.body)
                        .or(default.as_deref())
                        .expect("constant default");
                }
                LCompKind::CaseLength {
                    scrutinee,
                    exact,
                    at_least,
                    otherwise,
                } => {
                    let Value::List(vs) = eval_val(scrutinee, &env) else {
                        panic!("expected list");
                    };
                    c = if vs.len() >= usize::try_from(*at_least).unwrap() {
                        otherwise
                    } else {
                        &exact
                            .iter()
                            .find(|a| usize::try_from(a.len).unwrap() == vs.len())
                            .unwrap()
                            .body
                    };
                }
                LCompKind::ListGet { list, from, index } => {
                    let Value::List(vs) = eval_val(list, &env) else {
                        panic!("expected list");
                    };
                    let i = usize::try_from(*index).unwrap();
                    return vs[match from {
                        ListEnd::Front => i,
                        ListEnd::Back => vs.len() - 1 - i,
                    }]
                    .clone();
                }
                LCompKind::ListSlice {
                    list,
                    drop_front,
                    drop_back,
                } => {
                    let Value::List(vs) = eval_val(list, &env) else {
                        panic!("expected list");
                    };
                    return Value::List(
                        vs[usize::try_from(*drop_front).unwrap()
                            ..vs.len() - usize::try_from(*drop_back).unwrap()]
                            .to_vec(),
                    );
                }
                LCompKind::Join {
                    label,
                    params,
                    handler,
                    body,
                } => {
                    joins.push((*label, params, handler, env.clone()));
                    c = body;
                }
                LCompKind::Jump { label, args } => {
                    let (_, params, handler, captured) = joins
                        .iter()
                        .rev()
                        .find(|(k, _, _, _)| k == label)
                        .expect("join label");
                    let values: Vec<_> = args.iter().map(|v| eval_val(v, &env)).collect();
                    env = captured.clone();
                    for (p, v) in params.iter().zip(values) {
                        env.insert(p.id, v);
                    }
                    c = handler;
                }
                LCompKind::App { .. }
                | LCompKind::Method(_)
                | LCompKind::Escape(_)
                | LCompKind::Use { .. }
                | LCompKind::Lazy { .. }
                | LCompKind::Handle(_)
                | LCompKind::Resume { .. } => panic!("unsupported test computation"),
            }
        }
    }
    fn compare(body: &Comp, values: impl IntoIterator<Item = Value>, guards: &[VarId]) {
        let low = lower(body.clone());
        for v in values {
            for bits in 0..1_usize << guards.len() {
                let mut env = Env::from([(VarId(0), v.clone())]);
                for (i, g) in guards.iter().enumerate() {
                    env.insert(*g, bvalue(bits & (1 << i) != 0));
                }
                assert_eq!(
                    eval_low(&low, &env),
                    eval_core(body, &env),
                    "value {v:?}, guards {bits}"
                );
            }
        }
    }

    #[test]
    fn constructors_nested_fields_records_and_default_obey_the_contract() {
        let input = var(0, adt_ty(OPTION, vec![bool_ty()]));
        let body = matching(
            vval(&input),
            vec![
                (ctor(OPTION, 1, vec![CorePat::Var(VarId(1))]), 0),
                (ctor(OPTION, 0, vec![]), 1),
            ],
            vec![arm(0, vec![var(1, bool_ty())], None), arm(1, vec![], None)],
        );
        let out = lower_program(&program(body.clone())).unwrap();
        let LCompKind::CaseCtor { arms, default, .. } = &out.defs[0].body.kind else {
            panic!("ctor case");
        };
        assert_eq!(arms.iter().map(|a| a.tag).collect::<Vec<_>>(), [0, 1]);
        assert!(default.is_none());
        assert_eq!(arms[1].fields[0].ty, bool_ty());
        assert_eq!(arms[1].fields[0].id, VarId(100));
        assert_eq!(out.defs[0].var_count, 101);
        compare(
            &body,
            [
                Value::Ctor(OPTION, 0, vec![]),
                Value::Ctor(OPTION, 1, vec![bvalue(false)]),
                Value::Ctor(OPTION, 1, vec![bvalue(true)]),
            ],
            &[],
        );

        let nested = matching(
            vval(&var(
                0,
                adt_ty(OPTION, vec![adt_ty(OPTION, vec![bool_ty()])]),
            )),
            vec![
                (
                    ctor(
                        OPTION,
                        1,
                        vec![ctor(OPTION, 1, vec![CorePat::Var(VarId(1))])],
                    ),
                    0,
                ),
                (ctor(OPTION, 1, vec![ctor(OPTION, 0, vec![])]), 1),
                (ctor(OPTION, 0, vec![]), 2),
            ],
            vec![
                arm(0, vec![var(1, bool_ty())], None),
                arm(1, vec![], None),
                arm(2, vec![], None),
            ],
        );
        let low = lower(nested.clone());
        let LCompKind::CaseCtor { arms, .. } = &low.kind else {
            panic!("outer ctor");
        };
        let LCompKind::CaseCtor { scrutinee, .. } = &arms[1].body.kind else {
            panic!("inner ctor");
        };
        assert_eq!(scrutinee.kind, ValKind::Var(arms[1].fields[0].id));
        compare(
            &nested,
            [
                Value::Ctor(OPTION, 0, vec![]),
                Value::Ctor(OPTION, 1, vec![Value::Ctor(OPTION, 0, vec![])]),
                Value::Ctor(OPTION, 1, vec![Value::Ctor(OPTION, 1, vec![bvalue(true)])]),
            ],
            &[],
        );

        let record = matching(
            vval(&var(0, adt_ty(RECORD, vec![]))),
            vec![(
                ctor(
                    RECORD,
                    0,
                    vec![CorePat::Var(VarId(1)), CorePat::Var(VarId(2))],
                ),
                0,
            )],
            vec![arm(0, vec![var(1, bool_ty()), var(2, int_ty())], None)],
        );
        let low = lower(record.clone());
        let LCompKind::CaseCtor { arms, default, .. } = &low.kind else {
            panic!("record ctor");
        };
        assert_eq!(arms.len(), 1);
        assert!(default.is_none());
        assert_eq!(
            arms[0]
                .fields
                .iter()
                .map(|v| v.ty.clone())
                .collect::<Vec<_>>(),
            [bool_ty(), int_ty()]
        );
        compare(
            &record,
            [Value::Ctor(RECORD, 0, vec![bvalue(true), ivalue(7)])],
            &[],
        );

        let partial = matching(
            vval(&var(0, adt_ty(THREE, vec![]))),
            vec![(ctor(THREE, 2, vec![]), 0), (CorePat::Wild, 1)],
            vec![arm(0, vec![], None), arm(1, vec![], None)],
        );
        let low = lower(partial.clone());
        let LCompKind::CaseCtor { default, .. } = low.kind else {
            panic!("three ctor");
        };
        assert!(default.is_some());
        compare(
            &partial,
            (0..3).map(|tag| Value::Ctor(THREE, tag, vec![])),
            &[],
        );
    }

    #[test]
    fn constant_cases_preserve_first_occurrence_order_and_required_defaults() {
        for (ty, rows, tests, default, values) in [
            (
                builtin_ty(BuiltinTypeId::STRING),
                vec![(pat_str("b"), 0), (pat_str("a"), 1), (CorePat::Wild, 2)],
                vec![Const::Str("b".into()), Const::Str("a".into())],
                true,
                vec![
                    Value::Const(Const::Str("a".into())),
                    Value::Const(Const::Str("b".into())),
                    Value::Const(Const::Str("other".into())),
                ],
            ),
            (
                bool_ty(),
                vec![(pat_bool(true), 0), (pat_bool(false), 1)],
                vec![Const::Bool(true), Const::Bool(false)],
                false,
                vec![bvalue(false), bvalue(true)],
            ),
            (
                bool_ty(),
                vec![(pat_bool(false), 0), (CorePat::Wild, 1)],
                vec![Const::Bool(false)],
                true,
                vec![bvalue(false), bvalue(true)],
            ),
            (
                builtin_ty(BuiltinTypeId::UNIT),
                vec![(CorePat::Const(Const::Unit), 0)],
                vec![Const::Unit],
                false,
                vec![Value::Const(Const::Unit)],
            ),
        ] {
            let arms = (0..rows.len())
                .map(|i| arm(u32::try_from(i).unwrap(), vec![], None))
                .collect();
            let body = matching(vval(&var(0, ty)), rows, arms);
            let low = lower(body.clone());
            let LCompKind::CaseConst {
                arms, default: d, ..
            } = &low.kind
            else {
                panic!("constant case");
            };
            assert_eq!(
                arms.iter().map(|a| a.test.clone()).collect::<Vec<_>>(),
                tests.into_iter().map(ConstTest::Eq).collect::<Vec<_>>()
            );
            assert_eq!(d.is_some(), default);
            compare(&body, values, &[]);
        }
        // 同じ定数の二番目の行も、先行するガードが false のときの木に残る。
        let body = matching(
            vval(&var(0, builtin_ty(BuiltinTypeId::STRING))),
            vec![(pat_str("a"), 0), (pat_str("a"), 1), (CorePat::Wild, 2)],
            vec![
                arm(0, vec![], Some(boolean(false))),
                arm(1, vec![], None),
                arm(2, vec![], None),
            ],
        );
        compare(&body, [Value::Const(Const::Str("a".into()))], &[]);
    }

    fn interval_tests(low: &LComp) -> Vec<ConstTest> {
        let mut tests = Vec::new();
        visit(low, &mut |c| {
            if let LCompKind::CaseConst { arms, .. } = &c.kind {
                tests.extend(arms.iter().map(|a| a.test.clone()));
            }
        });
        tests
    }

    // 網羅した整数の列でも、存在しない既定の行を木へ変換しない。
    // ソースの golden に加え、下位 IR に不要な既定分岐を残す回避策を捕まえる。
    #[test]
    fn exhaustive_integer_ranges_lower_without_a_default() {
        let range = |lo, hi| CorePat::Range {
            lo: Const::Int(lo),
            hi: Const::Int(hi),
        };
        for rows in [
            vec![(range(i64::MIN, i64::MAX), 0)],
            vec![(range(i64::MIN, -1), 0), (range(0, i64::MAX), 1)],
            vec![
                (range(i64::MIN, -1), 0),
                (CorePat::Const(Const::Int(0)), 1),
                (range(1, i64::MAX), 2),
            ],
        ] {
            let arms = (0..rows.len())
                .map(|i| arm(u32::try_from(i).unwrap(), vec![], None))
                .collect();
            let body = matching(
                vval(&var(0, builtin_ty(BuiltinTypeId::INTEGER))),
                rows,
                arms,
            );
            let low = lower(body.clone());
            let LCompKind::CaseConst { default, .. } = &low.kind else {
                panic!("expected constant cases")
            };
            assert!(default.is_none());
            compare(
                &body,
                [i64::MIN, -1, 0, 1, i64::MAX].map(|n| Value::Const(Const::Int(n))),
                &[],
            );
        }
    }

    // 網羅した文字には既定分岐が不要であり、未被覆のコア入力は拒否する。
    #[test]
    fn exhaustive_character_ranges_lower_without_a_default() {
        let ty = builtin_ty(BuiltinTypeId::CHARACTER);
        for rows in [
            vec![(
                CorePat::Range {
                    lo: Const::Char('\0'),
                    hi: Const::Char('\u{10ffff}'),
                },
                0,
            )],
            vec![
                (
                    CorePat::Range {
                        lo: Const::Char('\0'),
                        hi: Const::Char('\u{d7ff}'),
                    },
                    0,
                ),
                (
                    CorePat::Range {
                        lo: Const::Char('\u{e000}'),
                        hi: Const::Char('\u{10ffff}'),
                    },
                    1,
                ),
            ],
        ] {
            let arms = (0..rows.len())
                .map(|i| arm(u32::try_from(i).unwrap(), vec![], None))
                .collect();
            let body = matching(vval(&var(0, ty.clone())), rows, arms);
            let low = lower(body.clone());
            let LCompKind::CaseConst { default, .. } = &low.kind else {
                panic!("expected constant cases")
            };
            assert!(default.is_none());
            compare(
                &body,
                ['\0', 'a', '\u{d7ff}', '\u{e000}', '\u{10ffff}']
                    .map(|c| Value::Const(Const::Char(c))),
                &[],
            );
        }
        let body = matching(
            vval(&var(0, ty)),
            vec![(
                CorePat::Range {
                    lo: Const::Char('a'),
                    hi: Const::Char('z'),
                },
                0,
            )],
            vec![arm(0, vec![], None)],
        );
        assert!(matches!(
            lower_program(&program(body)),
            Err(LowerError::Internal(_))
        ));
    }

    // 全域の列に残るワイルドカード行だけでは、もう一方の列を網羅しない場合を守る。
    #[test]
    fn exhaustive_character_columns_preserve_correlated_rows() {
        let character = builtin_ty(BuiltinTypeId::CHARACTER);
        let char_range = |lo, hi| CorePat::Range {
            lo: Const::Char(lo),
            hi: Const::Char(hi),
        };
        for (second_ty, middle, last, seconds) in [
            (
                bool_ty(),
                pat_bool(true),
                pat_bool(false),
                vec![bvalue(false), bvalue(true)],
            ),
            (
                character.clone(),
                char_range('\0', '\u{d7ff}'),
                char_range('\u{e000}', '\u{10ffff}'),
                ['\0', '\u{d7ff}', '\u{e000}', '\u{10ffff}']
                    .map(|c| Value::Const(Const::Char(c)))
                    .to_vec(),
            ),
        ] {
            let body = matching(
                vval(&var(0, adt_ty(PAIR, vec![character.clone(), second_ty]))),
                vec![
                    (ctor(PAIR, 0, vec![char_range('\0', 'm'), CorePat::Wild]), 0),
                    (ctor(PAIR, 0, vec![CorePat::Wild, middle]), 1),
                    (ctor(PAIR, 0, vec![char_range('n', '\u{10ffff}'), last]), 2),
                ],
                (0..3).map(|i| arm(i, vec![], None)).collect(),
            );
            compare(
                &body,
                ['\0', 'm', 'n', 'z', '\u{d7ff}', '\u{e000}', '\u{10ffff}']
                    .into_iter()
                    .flat_map(|c| {
                        seconds.iter().cloned().map(move |second| {
                            Value::Ctor(PAIR, 0, vec![Value::Const(Const::Char(c)), second])
                        })
                    }),
                &[],
            );
        }
    }

    #[test]
    fn interval_splitting_preserves_overlapping_rows_guards_and_extreme_endpoints() {
        let guard_var = var(9, bool_ty());
        let body = matching(
            vval(&var(0, int_ty())),
            vec![(range(1, 10), 0), (range(5, 15), 1), (CorePat::Wild, 2)],
            vec![
                arm(0, vec![], Some(ret(vval(&guard_var)))),
                arm(1, vec![], None),
                arm(2, vec![], None),
            ],
        );
        let low = lower(body.clone());
        assert_eq!(
            interval_tests(&low),
            [
                ConstTest::Range(Const::Int(1), Const::Int(4)),
                ConstTest::Range(Const::Int(5), Const::Int(10)),
                ConstTest::Range(Const::Int(11), Const::Int(15))
            ]
        );
        compare(&body, (-3..=17).map(ivalue), &[guard_var.id]);

        let score_guard = Comp {
            kind: CompKind::App {
                exit_report: None,
                func: val(
                    ValKind::Builtin {
                        id: BuiltinId(0),
                        targs: TypeArgs::default(),
                        info: BuiltinInfo {
                            class: Capability::Pure,
                            op: None,
                            decl: None,
                            intrinsic: Some(Intrinsic::Operator {
                                op: OperatorKind::Lt,
                                operand: BuiltinTypeId::INTEGER,
                            }),
                        },
                    },
                    Ty::Fn(Box::new(FnTy {
                        param_names: (1..=2).map(|i| format!("arg{i}")).collect(),
                        params: vec![int_ty(), int_ty()],
                        ret: bool_ty(),
                        effects: EffectSet::empty(),
                    })),
                ),
                dicts: vec![],
                args: vec![
                    vval(&var(1, int_ty())),
                    val(ValKind::Const(Const::Int(0)), int_ty()),
                ],
            },
            ty: bool_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let score = matching(
            vval(&var(0, int_ty())),
            vec![
                (CorePat::Var(VarId(1)), 0),
                (range(90, 100), 1),
                (range(70, 89), 2),
                (CorePat::Wild, 3),
            ],
            vec![
                arm(0, vec![var(1, int_ty())], Some(score_guard)),
                arm(1, vec![], None),
                arm(2, vec![], None),
                arm(3, vec![], None),
            ],
        );
        let low = lower(score);
        let mut if_count = 0;
        visit(&low, &mut |c| {
            if matches!(c.kind, LCompKind::If { .. }) {
                if_count += 1;
            }
        });
        assert_eq!(if_count, 1);
        assert_eq!(
            interval_tests(&low),
            [
                ConstTest::Range(Const::Int(70), Const::Int(89)),
                ConstTest::Range(Const::Int(90), Const::Int(100))
            ]
        );

        let extremes = matching(
            vval(&var(0, int_ty())),
            vec![
                (range(i64::MIN, -1), 0),
                (range(0, i64::MAX), 1),
                (CorePat::Wild, 2),
            ],
            vec![
                arm(0, vec![], None),
                arm(1, vec![], None),
                arm(2, vec![], None),
            ],
        );
        compare(&extremes, [i64::MIN, -1, 0, i64::MAX].map(ivalue), &[]);
        let characters = matching(
            vval(&var(0, builtin_ty(BuiltinTypeId::CHARACTER))),
            vec![
                (
                    CorePat::Range {
                        lo: Const::Char('a'),
                        hi: Const::Char('z'),
                    },
                    0,
                ),
                (
                    CorePat::Range {
                        lo: Const::Char('\u{d7fe}'),
                        hi: Const::Char('\u{e001}'),
                    },
                    1,
                ),
                (
                    CorePat::Range {
                        lo: Const::Char('\u{d7ff}'),
                        hi: Const::Char('\u{d7ff}'),
                    },
                    2,
                ),
                (CorePat::Const(Const::Char('\u{10ffff}')), 3),
                (CorePat::Wild, 4),
            ],
            vec![
                arm(0, vec![], None),
                arm(1, vec![], Some(ret(vval(&guard_var)))),
                arm(2, vec![], None),
                arm(3, vec![], None),
                arm(4, vec![], None),
            ],
        );
        let low = lower(characters.clone());
        assert_eq!(
            interval_tests(&low),
            [
                ConstTest::Range(Const::Char('a'), Const::Char('z')),
                ConstTest::Eq(Const::Char('\u{d7fe}')),
                ConstTest::Eq(Const::Char('\u{d7ff}')),
                ConstTest::Range(Const::Char('\u{e000}'), Const::Char('\u{e001}')),
                ConstTest::Eq(Const::Char('\u{10ffff}'))
            ]
        );
        compare(
            &characters,
            [
                '\0',
                'a',
                'z',
                '\u{d7fe}',
                '\u{d7ff}',
                '\u{e000}',
                '\u{e001}',
                '\u{10ffff}',
            ]
            .map(|c| Value::Const(Const::Char(c))),
            &[guard_var.id],
        );
    }

    #[test]
    fn list_lengths_elements_and_rest_slices_follow_the_command_example() {
        let string = builtin_ty(BuiltinTypeId::STRING);
        let body = matching(
            vval(&var(0, list_ty(string.clone()))),
            vec![
                (list(vec![pat_str("help")], None, vec![]), 0),
                (list(vec![pat_str("--help")], None, vec![]), 0),
                (list(vec![], None, vec![]), 0),
                (
                    list(vec![pat_str("add"), CorePat::Var(VarId(1))], None, vec![]),
                    1,
                ),
                (
                    list(
                        vec![pat_str("remove"), CorePat::Var(VarId(2))],
                        Some(Some(3)),
                        vec![],
                    ),
                    2,
                ),
                (CorePat::Wild, 3),
            ],
            vec![
                arm(0, vec![], None),
                arm(1, vec![var(1, string.clone())], None),
                arm(
                    2,
                    vec![var(2, string.clone()), var(3, list_ty(string))],
                    None,
                ),
                arm(3, vec![], None),
            ],
        );
        let low = lower(body.clone());
        let mut lengths = vec![];
        let mut slices = vec![];
        visit(&low, &mut |c| match &c.kind {
            LCompKind::CaseLength {
                exact, at_least, ..
            } => lengths.push((exact.iter().map(|a| a.len).collect::<Vec<_>>(), *at_least)),
            LCompKind::ListSlice {
                drop_front,
                drop_back,
                ..
            } => slices.push((*drop_front, *drop_back)),
            LCompKind::Return(_)
            | LCompKind::BuilderLet { .. }
            | LCompKind::BuilderOp { .. }
            | LCompKind::Let { .. }
            | LCompKind::App { .. }
            | LCompKind::Method(_)
            | LCompKind::If { .. }
            | LCompKind::CaseCtor { .. }
            | LCompKind::CaseConst { .. }
            | LCompKind::ListGet { .. }
            | LCompKind::Join { .. }
            | LCompKind::Jump { .. }
            | LCompKind::Escape(_)
            | LCompKind::Use { .. }
            | LCompKind::Lazy { .. }
            | LCompKind::Handle(_)
            | LCompKind::Resume { .. } => (),
        });
        assert_eq!(lengths, [(vec![0, 1, 2], 3)]);
        assert_eq!(slices, [(2, 0), (2, 0)]);
        compare(
            &body,
            [
                vec![],
                vec!["help"],
                vec!["--help"],
                vec!["x"],
                vec!["add", "name"],
                vec!["remove", "first"],
                vec!["remove", "first", "rest", "end"],
                vec!["add", "name", "extra"],
            ]
            .map(|vs| {
                Value::List(
                    vs.into_iter()
                        .map(|s| Value::Const(Const::Str(s.into())))
                        .collect(),
                )
            }),
            &[],
        );
    }

    fn boolean_lists() -> Vec<Value> {
        let mut values = Vec::new();
        for len in 0..=4 {
            for bits in 0..1 << len {
                values.push(Value::List(
                    (0..len).map(|i| bvalue(bits & (1 << i) != 0)).collect(),
                ));
            }
        }
        values
    }

    #[test]
    fn exhaustive_values_preserve_branch_selection_and_pattern_bindings() {
        let g = var(8, bool_ty());
        let h = var(9, bool_ty());
        let option = matching(
            vval(&var(0, adt_ty(OPTION, vec![bool_ty()]))),
            vec![
                (ctor(OPTION, 1, vec![CorePat::Var(VarId(1))]), 0),
                (ctor(OPTION, 0, vec![]), 1),
                (CorePat::Wild, 2),
            ],
            vec![
                arm(0, vec![var(1, bool_ty())], Some(ret(vval(&g)))),
                arm(1, vec![], Some(ret(vval(&h)))),
                arm(2, vec![], None),
            ],
        );
        compare(
            &option,
            [
                Value::Ctor(OPTION, 0, vec![]),
                Value::Ctor(OPTION, 1, vec![bvalue(false)]),
                Value::Ctor(OPTION, 1, vec![bvalue(true)]),
            ],
            &[g.id, h.id],
        );
        let ints = matching(
            vval(&var(0, int_ty())),
            vec![
                (range(-2, 1), 0),
                (range(0, 2), 1),
                (pat_int(3), 1),
                (CorePat::Var(VarId(1)), 2),
            ],
            vec![
                arm(0, vec![], Some(ret(vval(&g)))),
                arm(1, vec![], Some(ret(vval(&h)))),
                arm(2, vec![var(1, int_ty())], None),
            ],
        );
        compare(&ints, (-3..=3).map(ivalue), &[g.id, h.id]);
        let lists = matching(
            vval(&var(0, list_ty(bool_ty()))),
            vec![
                (
                    list(
                        vec![CorePat::Var(VarId(1))],
                        Some(Some(2)),
                        vec![CorePat::Var(VarId(3))],
                    ),
                    0,
                ),
                (list(vec![CorePat::Var(VarId(4))], None, vec![]), 1),
                (CorePat::Var(VarId(5)), 2),
            ],
            vec![
                arm(
                    0,
                    vec![
                        var(1, bool_ty()),
                        var(2, list_ty(bool_ty())),
                        var(3, bool_ty()),
                    ],
                    Some(ret(vval(&g))),
                ),
                arm(1, vec![var(4, bool_ty())], Some(ret(vval(&h)))),
                arm(2, vec![var(5, list_ty(bool_ty()))], None),
            ],
        );
        compare(&lists, boolean_lists(), &[g.id, h.id]);
        let low = lower(lists);
        let mut gets = BTreeSet::new();
        visit(&low, &mut |c| {
            if let LCompKind::ListGet { from, index, .. } = &c.kind {
                gets.insert((matches!(from, ListEnd::Back), *index));
            }
        });
        assert!(gets.contains(&(false, 0)));
        assert!(gets.contains(&(true, 0)));
        // 異なる行が要求する前後の要素数を同じ列に置く場合も、後ろの二要素の順を保つ。
        let mixed = matching(
            vval(&var(0, list_ty(bool_ty()))),
            vec![
                (
                    list(
                        vec![pat_bool(true)],
                        Some(Some(2)),
                        vec![CorePat::Var(VarId(1))],
                    ),
                    0,
                ),
                (
                    list(
                        vec![],
                        Some(Some(4)),
                        vec![CorePat::Var(VarId(3)), pat_bool(false)],
                    ),
                    1,
                ),
                (CorePat::Wild, 2),
            ],
            vec![
                arm(
                    0,
                    vec![var(2, list_ty(bool_ty())), var(1, bool_ty())],
                    Some(ret(vval(&g))),
                ),
                arm(1, vec![var(4, list_ty(bool_ty())), var(3, bool_ty())], None),
                arm(2, vec![], None),
            ],
        );
        compare(&mixed, boolean_lists(), &[g.id]);
        for pattern in [
            list(vec![], Some(Some(1)), vec![]),
            list(vec![], None, vec![]),
        ] {
            let vars = if matches!(&pattern, CorePat::List { rest: Some(_), .. }) {
                vec![var(1, list_ty(bool_ty()))]
            } else {
                vec![]
            };
            let body = matching(
                vval(&var(0, list_ty(bool_ty()))),
                vec![(pattern, 0), (CorePat::Wild, 1)],
                vec![arm(0, vars, None), arm(1, vec![], None)],
            );
            compare(&body, boolean_lists(), &[]);
        }
    }

    fn lambda(id: u32, body: Comp) -> CoreVal {
        let ty = Ty::Fn(Box::new(FnTy {
            param_names: Vec::new(),
            params: vec![],
            ret: body.ty.clone(),
            effects: body.eff.clone(),
        }));
        val(
            ValKind::Lambda(Box::new(Lambda {
                param_names: Vec::new(),
                id: BodyId(id),
                params: vec![],
                body,
                span: other_span(),
            })),
            ty,
        )
    }
    fn bind(var: Var, bound: Comp, body: Comp) -> Comp {
        Comp {
            ty: body.ty.clone(),
            eff: bound.eff.union(&body.eff),
            kind: CompKind::Let {
                var,
                bound: Box::new(bound),
                body: Box::new(body),
            },
            origin: other_span(),
        }
    }
    fn handle(body: Comp, clause_body: Comp) -> Comp {
        let ty = body.ty.clone();
        Comp {
            kind: CompKind::Handle(Box::new(Handle {
                id: BodyId(2),
                body,
                clauses: vec![Clause {
                    failure_type: None,
                    id: BodyId(3),
                    node: NodeId(7),
                    op: BindingId(60),
                    dict_params: vec![],
                    params: vec![],
                    cont: ContVar {
                        id: VarId(6),
                        arg: bool_ty(),
                    },
                    tail_resumptive: true,
                    body: clause_body,
                    span: other_span(),
                }],
                handled: EffectSet {
                    failures: vec![],
                    names: vec![EffectName::User(BindingId(61))],
                    vars: vec![],
                },
            })),
            ty,
            eff: EffectSet::empty(),
            origin: other_span(),
        }
    }
    fn val_body_ids(v: &LowVal, ids: &mut Vec<BodyId>) {
        match &v.kind {
            ValKind::Lambda(l) => ids.push(l.id),
            ValKind::Ctor { args, .. } | ValKind::List(args) => {
                for v in args {
                    val_body_ids(v, ids);
                }
            }
            ValKind::Var(_)
            | ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::External { .. }
            | ValKind::Op { .. }
            | ValKind::ConstRef(_) => (),
        }
    }
    fn body_ids(c: &LComp) -> Vec<BodyId> {
        let mut ids = Vec::new();
        visit(c, &mut |c| match &c.kind {
            LCompKind::Return(v) | LCompKind::Escape(v) => val_body_ids(v, &mut ids),
            LCompKind::If { cond, .. } => val_body_ids(cond, &mut ids),
            LCompKind::App { func, args, .. } => {
                val_body_ids(func, &mut ids);
                for v in args {
                    val_body_ids(v, &mut ids);
                }
            }
            LCompKind::Method(m) => {
                for v in &m.args {
                    val_body_ids(v, &mut ids);
                }
            }
            LCompKind::Lazy { id, .. } => ids.push(*id),
            LCompKind::Handle(h) => {
                ids.push(h.id);
                ids.extend(h.clauses.iter().map(|cl| cl.id));
            }
            LCompKind::BuilderLet { .. }
            | LCompKind::BuilderOp { .. }
            | LCompKind::Let { .. }
            | LCompKind::CaseCtor { .. }
            | LCompKind::CaseConst { .. }
            | LCompKind::CaseLength { .. }
            | LCompKind::ListGet { .. }
            | LCompKind::ListSlice { .. }
            | LCompKind::Join { .. }
            | LCompKind::Jump { .. }
            | LCompKind::Use { .. }
            | LCompKind::Resume { .. } => (),
        });
        ids
    }

    #[test]
    fn joins_share_bodies_and_false_guards_skip_the_other_alternatives() {
        let body = matching(
            vval(&var(0, list_ty(bool_ty()))),
            vec![
                (
                    list(vec![CorePat::Var(VarId(1)), CorePat::Wild], None, vec![]),
                    0,
                ),
                (
                    list(vec![CorePat::Wild, CorePat::Var(VarId(1))], None, vec![]),
                    0,
                ),
                (CorePat::Wild, 1),
            ],
            vec![
                arm(
                    0,
                    vec![var(1, bool_ty())],
                    Some(ret(vval(&var(1, bool_ty())))),
                ),
                arm(1, vec![], None),
            ],
        );
        compare(&body, boolean_lists(), &[]);
        let low = lower(body);
        // 二番目の選択肢は先頭のパターンが必ず照合するため葉にならず、ガード失敗後にも試されない。
        let env = Env::from([(VarId(0), Value::List(vec![bvalue(false), bvalue(true)]))]);
        assert_eq!(eval_low(&low, &env), Value::Ctor(OBS, 1, vec![]));

        let shared = matching(
            vval(&var(0, adt_ty(OPTION, vec![bool_ty()]))),
            vec![
                (ctor(OPTION, 1, vec![pat_bool(true)]), 0),
                (ctor(OPTION, 1, vec![pat_bool(false)]), 0),
                (ctor(OPTION, 0, vec![]), 1),
            ],
            vec![
                MatchArm {
                    vars: vec![],
                    guard: None,
                    body: ret(lambda(0, boolean(true))),
                },
                MatchArm {
                    vars: vec![],
                    guard: None,
                    body: ret(lambda(1, boolean(false))),
                },
            ],
        );
        let low = lower(shared);
        let mut joins = vec![];
        let mut jumps = vec![];
        visit(&low, &mut |c| match &c.kind {
            LCompKind::Join { label, params, .. } => joins.push((*label, params.len())),
            LCompKind::Jump { label, args } => jumps.push((*label, args.len())),
            LCompKind::Return(_)
            | LCompKind::BuilderLet { .. }
            | LCompKind::BuilderOp { .. }
            | LCompKind::Let { .. }
            | LCompKind::App { .. }
            | LCompKind::Method(_)
            | LCompKind::If { .. }
            | LCompKind::CaseCtor { .. }
            | LCompKind::CaseConst { .. }
            | LCompKind::CaseLength { .. }
            | LCompKind::ListGet { .. }
            | LCompKind::ListSlice { .. }
            | LCompKind::Escape(_)
            | LCompKind::Use { .. }
            | LCompKind::Lazy { .. }
            | LCompKind::Handle(_)
            | LCompKind::Resume { .. } => (),
        });
        assert_eq!(joins, [(JoinId(0), 0)]);
        assert_eq!(jumps, [(JoinId(0), 0), (JoinId(0), 0)]);
        let mut ids = body_ids(&low);
        ids.sort_by_key(|id| id.0);
        assert_eq!(ids, [BodyId(0), BodyId(1)]);

        // 同じ変数を左右の異なる位置から束縛する選択肢でも join の引数順を保つ。
        let bound = matching(
            vval(&var(0, adt_ty(RECORD, vec![]))),
            vec![
                (
                    ctor(RECORD, 0, vec![pat_bool(true), CorePat::Var(VarId(1))]),
                    0,
                ),
                (
                    ctor(RECORD, 0, vec![pat_bool(false), CorePat::Var(VarId(1))]),
                    0,
                ),
            ],
            vec![arm(0, vec![var(1, int_ty())], None)],
        );
        compare(
            &bound,
            [
                Value::Ctor(RECORD, 0, vec![bvalue(false), ivalue(8)]),
                Value::Ctor(RECORD, 0, vec![bvalue(true), ivalue(-1)]),
            ],
            &[],
        );
    }

    #[test]
    fn copied_guards_renew_lambda_lazy_handle_and_clause_body_ids() {
        let lam = lambda(0, boolean(true));
        let lazy = Comp {
            kind: CompKind::Lazy {
                id: BodyId(1),
                body: Box::new(boolean(true)),
            },
            ty: Ty::Con(TyCon::Builtin(BuiltinTypeId::LAZY), vec![bool_ty()]),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let guard = bind(
            var(2, lam.ty.clone()),
            ret(lam),
            bind(
                var(3, lazy.ty.clone()),
                lazy,
                handle(boolean(true), boolean(true)),
            ),
        );
        let body = matching(
            vval(&var(0, bool_ty())),
            vec![
                (pat_bool(false), 0),
                (pat_bool(true), 0),
                (CorePat::Wild, 1),
            ],
            vec![arm(0, vec![], Some(guard)), arm(1, vec![], None)],
        );
        let p = program(body);
        let low = lower_program(&p).unwrap();
        let mut ids = body_ids(&low.defs[0].body);
        ids.sort_by_key(|id| id.0);
        assert_eq!(
            ids,
            [
                BodyId(0),
                BodyId(1),
                BodyId(2),
                BodyId(3),
                BodyId(10),
                BodyId(11),
                BodyId(12),
                BodyId(13)
            ]
        );
        assert_eq!(low.body_count, 14);
        let mut bound_vars = Vec::new();
        visit(&low.defs[0].body, &mut |c| {
            if let LCompKind::Let { var, .. } = &c.kind {
                bound_vars.push(var.id);
            }
        });
        assert_eq!(bound_vars.iter().filter(|id| **id == VarId(2)).count(), 2);
        assert_eq!(bound_vars.iter().filter(|id| **id == VarId(3)).count(), 2);
        let mut joins = Vec::new();
        visit(&low.defs[0].body, &mut |c| {
            if let LCompKind::Join { label, .. } = &c.kind {
                joins.push(*label);
            }
        });
        assert_eq!(joins, [JoinId(0), JoinId(1)]);
    }

    #[test]
    fn generated_nodes_have_minimal_effects_types_and_match_origins() {
        let io = EffectSet {
            failures: vec![],
            names: vec![EffectName::Builtin(BuiltinEffectId(2))],
            vars: vec![EffVar(0)],
        };
        let call = Comp {
            kind: CompKind::App {
                exit_report: None,
                func: val(
                    ValKind::Builtin {
                        id: BuiltinId(0),
                        targs: TypeArgs::default(),
                        info: BuiltinInfo {
                            class: Capability::Io,
                            op: Some(BindingId(50)),
                            decl: Some(BindingId(50)),
                            intrinsic: None,
                        },
                    },
                    Ty::Fn(Box::new(FnTy {
                        param_names: Vec::new(),
                        params: vec![],
                        ret: int_ty(),
                        effects: io.clone(),
                    })),
                ),
                dicts: vec![],
                args: vec![],
            },
            ty: int_ty(),
            eff: io.clone(),
            origin: other_span(),
        };
        for shared in [false, true] {
            let rows = if shared {
                vec![(pat_bool(false), 0), (pat_bool(true), 0)]
            } else {
                vec![(pat_bool(false), 0), (pat_bool(true), 1)]
            };
            let body = matching(
                vval(&var(0, bool_ty())),
                rows,
                vec![
                    MatchArm {
                        vars: vec![],
                        guard: None,
                        body: call.clone(),
                    },
                    MatchArm {
                        vars: vec![],
                        guard: None,
                        body: integer(9),
                    },
                ],
            );
            let mut body = body;
            body.ty = int_ty();
            let low = lower(body);
            assert_eq!(low.eff, io);
            assert_eq!(low.ty, int_ty());
            visit(&low, &mut |c| match &c.kind {
                LCompKind::Jump { .. } => {
                    assert!(c.eff.is_empty());
                    assert_eq!(c.ty, int_ty());
                    assert_eq!(c.origin, span());
                }
                LCompKind::CaseConst { .. } => {
                    assert_eq!(c.origin, span());
                    assert_eq!(c.ty, int_ty());
                    assert_eq!(
                        c.eff,
                        if shared {
                            EffectSet::empty()
                        } else {
                            io.clone()
                        }
                    );
                }
                LCompKind::Join { .. } => {
                    assert_eq!(c.origin, span());
                    assert_eq!(c.eff, io);
                }
                LCompKind::App { .. } | LCompKind::Return(_) => assert_eq!(c.origin, other_span()),
                LCompKind::BuilderLet { .. }
                | LCompKind::BuilderOp { .. }
                | LCompKind::Let { .. }
                | LCompKind::Method(_)
                | LCompKind::If { .. }
                | LCompKind::CaseCtor { .. }
                | LCompKind::CaseLength { .. }
                | LCompKind::ListGet { .. }
                | LCompKind::ListSlice { .. }
                | LCompKind::Escape(_)
                | LCompKind::Use { .. }
                | LCompKind::Lazy { .. }
                | LCompKind::Handle(_)
                | LCompKind::Resume { .. } => panic!("unexpected effect test node"),
            });
        }
    }

    #[test]
    fn non_match_nodes_metadata_methods_constants_and_nested_bodies_are_preserved() {
        let nested = || {
            matching(
                vval(&var(0, bool_ty())),
                vec![(pat_bool(false), 0), (pat_bool(true), 1)],
                vec![arm(0, vec![], None), arm(1, vec![], None)],
            )
        };
        let lam = lambda(0, nested());
        let lazy = Comp {
            kind: CompKind::Lazy {
                id: BodyId(1),
                body: Box::new(nested()),
            },
            ty: Ty::Con(
                TyCon::Builtin(BuiltinTypeId::LAZY),
                vec![adt_ty(OBS, vec![])],
            ),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let h = handle(nested(), nested());
        let body = bind(
            var(1, lam.ty.clone()),
            ret(lam),
            bind(var(2, lazy.ty.clone()), lazy, h),
        );
        let mut p = program(body);
        p.impls.push(ImplDef {
            impl_decl: NodeId(80),
            class: BindingId(81),
            name: "Show[Item]".into(),
            origin: DefOrigin::StdlibPublic,
            type_params: vec!["T".into()],
            target: crate::types::TypeArg::Ty(int_ty()),
            dict_params: vec![],
            supers: vec![],
            methods: vec![p.defs[0].clone()],
            span: other_span(),
        });
        p.consts.push(ConstDef {
            binding: BindingId(90),
            name: "constant".into(),
            ty: int_ty(),
            body: integer(7),
            value: crate::types::ConstValue::Integer(7),
            span: other_span(),
            var_count: 0,
        });
        p.ops.push(OpDef {
            failure: false,
            param_names: Vec::new(),
            binding: BindingId(60),
            effect: EffectName::User(BindingId(61)),
            name: "E.op".into(),
            arity: 0,
            builtin: None,
        });
        let low = lower_program(&p).unwrap();
        assert_eq!(low.main, p.main);
        assert_eq!(low.main_returns_result, p.main_returns_result);
        assert_eq!(low.ops, p.ops);
        assert_eq!(low.body_count, p.body_count);
        assert_eq!(
            low.adts
                .adts
                .iter()
                .map(|(id, def)| (id, def.clone()))
                .collect::<Vec<_>>(),
            p.adts
                .adts
                .iter()
                .map(|(id, def)| (id, def.clone()))
                .collect::<Vec<_>>()
        );
        assert_eq!(low.defs[0].body, low.impls[0].methods[0].body);
        assert_eq!(low.impls[0].name, p.impls[0].name);
        assert_eq!(
            low.consts[0].body,
            LComp {
                kind: LCompKind::Return(Val {
                    kind: ValKind::Const(Const::Int(7)),
                    ty: int_ty(),
                    origin: span()
                }),
                ty: int_ty(),
                eff: EffectSet::empty(),
                origin: other_span()
            }
        );
        let mut cases = 0;
        visit(&low.defs[0].body, &mut |c| {
            if matches!(c.kind, LCompKind::CaseConst { .. }) {
                cases += 1;
            }
        });
        assert_eq!(cases, 4);
        assert_eq!(
            body_ids(&low.defs[0].body),
            [BodyId(0), BodyId(1), BodyId(2), BodyId(3)]
        );

        // 通常の計算と値の全種類を、公開の下位 IR の欄で確かめる。
        let dict = DictVal {
            kind: DictKind::Param(VarId(1)),
            class: BindingId(5),
            arg: crate::types::TypeArg::Ty(int_ty()),
            origin: other_span(),
        };
        let targs = TypeArgs {
            tys: vec![crate::types::TypeArg::Ty(int_ty())],
            effects: vec![EffectSet::empty()],
        };
        let info = BuiltinInfo {
            class: Capability::Pure,
            op: None,
            decl: None,
            intrinsic: Some(Intrinsic::Eq),
        };
        let values = vec![
            val(
                ValKind::TopFn {
                    def: BindingId(4),
                    targs: targs.clone(),
                },
                int_ty(),
            ),
            val(
                ValKind::Builtin {
                    id: BuiltinId(1),
                    targs: targs.clone(),
                    info,
                },
                int_ty(),
            ),
            val(
                ValKind::Op {
                    op: BindingId(3),
                    targs: targs.clone(),
                },
                int_ty(),
            ),
            val(ValKind::ConstRef(BindingId(90)), int_ty()),
            val(
                ValKind::List(vec![vval(&var(0, int_ty()))]),
                list_ty(int_ty()),
            ),
            val(
                ValKind::Ctor {
                    adt: OPTION,
                    tag: 1,
                    tys: vec![int_ty()],
                    args: vec![vval(&var(0, int_ty()))],
                },
                adt_ty(OPTION, vec![int_ty()]),
            ),
        ];
        let app = Comp {
            kind: CompKind::App {
                exit_report: None,
                func: values[0].clone(),
                dicts: vec![dict.clone()],
                args: values.clone(),
            },
            ty: int_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let method = Comp {
            kind: CompKind::Method(Box::new(MethodCall {
                dict: dict.clone(),
                method: 2,
                targs: targs.clone(),
                dicts: vec![dict.clone()],
                args: values.clone(),
            })),
            ty: int_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let out = lower(app);
        let LCompKind::App {
            func, dicts, args, ..
        } = out.kind
        else {
            panic!("app");
        };
        assert_eq!(dicts.as_slice(), std::slice::from_ref(&dict));
        assert_eq!(
            func.kind,
            ValKind::TopFn {
                def: BindingId(4),
                targs: targs.clone()
            }
        );
        assert_eq!(
            args.iter().map(|v| v.ty.clone()).collect::<Vec<_>>(),
            values.iter().map(|v| v.ty.clone()).collect::<Vec<_>>()
        );
        assert_eq!(
            args[1].kind,
            ValKind::Builtin {
                id: BuiltinId(1),
                targs: targs.clone(),
                info
            }
        );
        assert_eq!(
            args[2].kind,
            ValKind::Op {
                op: BindingId(3),
                targs: targs.clone()
            }
        );
        assert_eq!(args[3].kind, ValKind::ConstRef(BindingId(90)));
        let out = lower(method);
        let LCompKind::Method(m) = out.kind else {
            panic!("method");
        };
        assert_eq!(m.dict, dict);
        assert_eq!(m.method, 2);
        assert_eq!(m.targs, targs);
        assert_eq!(m.args, args);
        let escape = Comp {
            kind: CompKind::Escape(vval(&var(0, int_ty()))),
            ty: int_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let resume = Comp {
            kind: CompKind::Resume {
                cont: VarId(6),
                value: vval(&var(0, int_ty())),
            },
            ty: int_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let use_comp = Comp {
            kind: CompKind::Use {
                resource: vval(&var(2, builtin_ty(BuiltinTypeId::IO_ERROR))),
                body: Box::new(resume),
            },
            ty: int_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let conditional = Comp {
            kind: CompKind::If {
                cond: vval(&var(3, bool_ty())),
                then_branch: Box::new(escape),
                else_branch: Box::new(use_comp),
            },
            ty: int_ty(),
            eff: EffectSet::empty(),
            origin: other_span(),
        };
        let out = lower(conditional);
        let LCompKind::If {
            cond,
            then_branch,
            else_branch,
        } = out.kind
        else {
            panic!("if");
        };
        assert_eq!(cond.kind, ValKind::Var(VarId(3)));
        assert!(matches!(then_branch.kind, LCompKind::Escape(_)));
        let LCompKind::Use { resource, body } = else_branch.kind else {
            panic!("use");
        };
        assert_eq!(resource.kind, ValKind::Var(VarId(2)));
        assert!(matches!(
            body.kind,
            LCompKind::Resume { cont: VarId(6), .. }
        ));
    }

    #[test]
    fn nested_patterns_and_long_lists_preserve_bindings_without_changing_stack_size() {
        let chain = BindingId(70);
        let chain_ty = adt_ty(chain, vec![]);
        let mut pattern = CorePat::Wild;
        let mut value = Value::Ctor(chain, 0, vec![]);
        let depth = 64;
        for _ in 0..depth {
            pattern = ctor(chain, 1, vec![pattern]);
            value = Value::Ctor(chain, 1, vec![value]);
        }
        let body = matching(
            vval(&var(0, chain_ty.clone())),
            vec![(pattern, 0), (CorePat::Wild, 1)],
            vec![arm(0, vec![], None), arm(1, vec![], None)],
        );
        let mut p = program(body.clone());
        p.adts.adts.insert(
            chain,
            AdtDef {
                extensible: false,
                binding: chain,
                name: "Chain".into(),
                module: ModuleId(0),
                type_params: vec![],
                ctors: vec![
                    CtorDef {
                        name: "End".into(),
                        binding: BindingId(71),
                        tag: 0,
                        fields: vec![],
                    },
                    CtorDef {
                        name: "Next".into(),
                        binding: BindingId(72),
                        tag: 1,
                        fields: vec![chain_ty],
                    },
                ],
                record: None,
                eq_summary: TypeSummary::default(),
                key_summary: TypeSummary::default(),
            },
        );
        let low = lower_program(&p).unwrap();
        assert_eq!(low.defs[0].var_count, 100 + depth);
        for v in [value, Value::Ctor(chain, 0, vec![])] {
            let env = Env::from([(VarId(0), v)]);
            assert_eq!(eval_low(&low.defs[0].body, &env), eval_core(&body, &env));
        }
        let len = 4096_u32;
        let selected = 777;
        let body = matching(
            vval(&var(0, list_ty(int_ty()))),
            vec![
                (
                    list(
                        (0..len)
                            .map(|i| {
                                if i == selected {
                                    CorePat::Var(VarId(1))
                                } else {
                                    CorePat::Wild
                                }
                            })
                            .collect(),
                        None,
                        vec![],
                    ),
                    0,
                ),
                (CorePat::Wild, 1),
            ],
            vec![arm(0, vec![var(1, int_ty())], None), arm(1, vec![], None)],
        );
        let p = program(body.clone());
        let low = lower_program(&p).unwrap();
        let env = Env::from([(
            VarId(0),
            Value::List((0..i64::from(len)).map(ivalue).collect()),
        )]);
        assert_eq!(
            eval_low(&low.defs[0].body, &env),
            Value::Ctor(OBS, 0, vec![ivalue(i64::from(selected))])
        );
        assert_eq!(eval_low(&low.defs[0].body, &env), eval_core(&body, &env));
    }

    // 作成時の関門: 公開の変換で、旧予算超過の入力も独立した照合器と同じ値になることを守る。
    // 小さい既存の行列では指数的に増える木を止めない退行を捕まえられない。
    // 本番の予算を下げず、差し込み口や時計に依存しない。
    #[test]
    fn decision_sharing_accepts_previous_limits_and_preserves_matching() {
        for (groups, extra, guarded) in [
            (8_u32, 0, false),
            (12, 0, false),
            (13, 0, false),
            (16, 0, false),
            (24, 0, false),
            (8, 2000, false),
            (8, 0, true),
        ] {
            let fields = groups * 2 + extra;
            let rows = (0..groups)
                .map(|i| {
                    let args = (0..fields)
                        .map(|j| {
                            if j == i * 2 || j == i * 2 + 1 {
                                pat_bool(true)
                            } else {
                                CorePat::Wild
                            }
                        })
                        .collect();
                    (ctor(RECORD, 0, args), i)
                })
                .chain([(CorePat::Wild, groups)])
                .collect();
            let body = matching(
                vval(&var(0, adt_ty(RECORD, vec![]))),
                rows,
                (0..=groups).map(|i| arm(i, vec![], None)).collect(),
            );
            let mut p = program(body.clone());
            let mut record = p.adts.adts.get(RECORD).unwrap().clone();
            record.ctors[0].fields = vec![bool_ty(); fields as usize];
            p.adts.adts.insert(RECORD, record);
            if groups == 12 {
                // 一つずつも定義の合計も予算の内側の二つの match。
                // 二つ目を最初の分岐に入れ、入れ子でも数えを混ぜないことを確かめる。
                let CompKind::Match { arms, .. } = &mut p.defs[0].body.kind else {
                    panic!("match");
                };
                arms[0].body = body.clone();
            }
            if guarded {
                // ガード内の大きな match も、共有して定義全体の予算の内側で受理する。
                let mut guard = body.clone();
                guard.ty = bool_ty();
                let CompKind::Match { arms, .. } = &mut guard.kind else {
                    panic!("match");
                };
                for a in arms {
                    a.body = ret(val(ValKind::Const(Const::Bool(false)), bool_ty()));
                }
                let CompKind::Match { rows, arms, .. } = &mut p.defs[0].body.kind else {
                    panic!("match");
                };
                arms.last_mut().unwrap().guard = Some(guard);
                rows.push(MatchRow {
                    pattern: CorePat::Wild,
                    arm: groups + 1,
                });
                arms.push(arm(groups + 1, vec![], None));
            }
            let result = lower_program(&p);
            {
                let low = result.unwrap();
                for selected in [None, Some(0), Some(groups - 1)] {
                    let values = (0..fields)
                        .map(|j| bvalue(selected.is_some_and(|i| j / 2 == i)))
                        .collect();
                    let env = Env::from([(VarId(0), Value::Ctor(RECORD, 0, values))]);
                    assert_eq!(
                        eval_low(&low.defs[0].body, &env),
                        eval_core(&p.defs[0].body, &env)
                    );
                }
            }
        }
    }

    // 関門: 共有判定は生成できても最終出力の予約で失敗する入力を、既存の
    // 私有の定義予算で作る。仕事量だけの切替テストではこの退行を捕まえない。
    #[test]
    fn final_output_reservation_falls_back_to_rows() {
        let body = matching(
            vval(&var(0, list_ty(bool_ty()))),
            vec![
                (list(vec![CorePat::Wild; 4], None, vec![]), 0),
                (CorePat::Wild, 1),
            ],
            vec![arm(0, vec![], None), arm(1, vec![], None)],
        );
        let p = program(body.clone());
        let CompKind::Match {
            scrutinee,
            rows,
            arms,
        } = &body.kind
        else {
            panic!("match");
        };
        let mut sizes = vec![];
        for fallback in [false, true] {
            let mut bodies = 0;
            let mut ctx = Lowerer::new(&p.adts, 100, &mut bodies, "main", span());
            let tree = if fallback {
                ctx.row_match(scrutinee, rows, arms).unwrap()
            } else {
                ctx.match_tree(&body, scrutinee, rows, arms).unwrap()
            };
            ctx.prepare_output(&tree, arms.len()).unwrap();
            sizes.push(ctx.def_nodes);
        }
        assert!(sizes[0] > sizes[1], "shared/rows={sizes:?}");
        let mut bodies = 0;
        let mut ctx = Lowerer::new(&p.adts, 100, &mut bodies, "main", span());
        ctx.def_nodes = 1_048_576 - sizes[1];
        let lowered = ctx.comp(&body, false).unwrap();
        assert_eq!(ctx.def_nodes, 1_048_576);
        assert_eq!(ctx.def_tree_work, 0);
        for len in [0, 4, 5] {
            let env = Env::from([(VarId(0), Value::List(vec![bvalue(true); len]))]);
            assert_eq!(eval_low(&lowered, &env), eval_core(&body, &env));
        }
    }

    // 作成時の関門: 公開 lower_program に符号化前の IR を渡し、parser の深さと独立に
    // 最終予算の拒否・診断の個数と位置を守る。小さい正常例ではこの契約を確かめられない。
    #[test]
    fn final_decision_budget_reports_one_limit_at_the_match() {
        let body = matching(
            vval(&var(0, list_ty(bool_ty()))),
            vec![
                (list(vec![CorePat::Wild; 1_048_576], None, vec![]), 0),
                (CorePat::Wild, 1),
            ],
            vec![arm(0, vec![], None), arm(1, vec![], None)],
        );
        let Err(LowerError::Limit(diagnostics)) = lower_program(&program(body)) else {
            panic!("expected a final limit");
        };
        assert_eq!(diagnostics.len(), 1);
        assert_eq!(diagnostics[0].code, Some(DiagCode::L0112));
        assert_eq!(diagnostics[0].primary.as_ref().unwrap().span, span());
        assert_eq!(
            diagnostics[0].message,
            "the definition `main` is too large to compile"
        );
        assert_eq!(
            diagnostics[0].notes,
            ["the match decision requires more than 64 MiB of working tables; simplify the match"]
        );
    }

    #[test]
    fn malformed_core_inputs_report_decision_internal_errors() {
        let invalids = [
            matching(
                val(ValKind::Const(Const::Bool(true)), bool_ty()),
                vec![(CorePat::Wild, 0)],
                vec![arm(0, vec![], None)],
            ),
            matching(vval(&var(0, bool_ty())), vec![], vec![]),
            matching(
                vval(&var(0, bool_ty())),
                vec![(CorePat::Wild, 1)],
                vec![arm(0, vec![], None)],
            ),
            matching(
                vval(&var(0, bool_ty())),
                vec![(CorePat::Wild, 0)],
                vec![arm(0, vec![], Some(boolean(true)))],
            ),
            matching(
                vval(&var(0, adt_ty(BindingId(99), vec![]))),
                vec![(ctor(BindingId(99), 0, vec![]), 0)],
                vec![arm(0, vec![], None)],
            ),
        ];
        for body in invalids {
            let LowerError::Internal(e) = lower_program(&program(body)).unwrap_err() else {
                panic!("expected an internal error");
            };
            assert_eq!(e.stage, "decision");
        }
    }
}
