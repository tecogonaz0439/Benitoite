//! 関数の境界、解放、遅延、ハンドラを移す（設計書 01-12「初回リリース版の拡張」、02-06「コア IR」）。
use super::*;
use crate::typeck::TryKind;
use crate::types::EffectName;

impl State<'_> {
    /// 01-12「関数の境界と `escape`：途中の `return` と `try`」の `Result` と `Option` の `try` の二つの行。
    pub(super) fn try_expr(&mut self, e: &ast::TryExpr) -> Result<Comp, InternalError> {
        let info = self
            .types
            .try_kinds
            .get(e.id)
            .cloned()
            .ok_or_else(|| error(format!("missing try_kinds for {:?}", e.id)))?;
        let Ty::Con(_, input_args) = self.ty(e.value.id())? else {
            return Err(error("try operand has no type arguments"));
        };
        let Ty::Con(_, ret_args) = &info.ret else {
            return Err(error("try return has no type arguments"));
        };
        let (success, failure) = match info.kind {
            TryKind::Result => ("Benitoite.Result.Ok", "Benitoite.Result.Error"),
            TryKind::Option => ("Benitoite.Option.Some", "Benitoite.Option.None"),
        };
        let mut pending = vec![];
        let scrutinee = self.eval(&e.value, &mut pending)?;
        let y = self.var(
            None,
            input_args
                .first()
                .cloned()
                .ok_or_else(|| error("try success type missing"))?,
        )?;
        let (adt, ok_tag) = self.std_ctor(success)?;
        let (failure_adt, fail_tag) = self.std_ctor(failure)?;
        if adt != failure_adt {
            return Err(error("try constructors belong to different ADTs"));
        }
        let (fail_vars, fail_patterns, fail_values) = match info.kind {
            TryKind::Result => {
                let z = self.var(
                    None,
                    input_args
                        .get(1)
                        .cloned()
                        .ok_or_else(|| error("try error type missing"))?,
                )?;
                (
                    vec![z.clone()],
                    vec![CorePat::Var(z.id)],
                    vec![variable(&z, e.span)],
                )
            }
            TryKind::Option => (vec![], vec![], vec![]),
        };
        let escaped = value(
            ValKind::Ctor {
                adt,
                tag: fail_tag,
                tys: ret_args.clone(),
                args: fail_values,
            },
            info.ret,
            e.span,
        );
        let body = Comp {
            ty: self.ty(e.id)?,
            eff: EffectSet::empty(),
            origin: e.span,
            kind: CompKind::Match {
                scrutinee,
                rows: vec![
                    MatchRow {
                        pattern: CorePat::Ctor {
                            adt,
                            tag: ok_tag,
                            args: vec![CorePat::Var(y.id)],
                        },
                        arm: 0,
                    },
                    MatchRow {
                        pattern: CorePat::Ctor {
                            adt,
                            tag: fail_tag,
                            args: fail_patterns,
                        },
                        arm: 1,
                    },
                ],
                arms: vec![
                    MatchArm {
                        vars: vec![y.clone()],
                        guard: None,
                        body: returned(variable(&y, e.span)),
                    },
                    MatchArm {
                        vars: fail_vars,
                        guard: None,
                        body: Comp {
                            kind: CompKind::Escape(escaped),
                            ty: self.ty(e.id)?,
                            eff: EffectSet::empty(),
                            origin: e.span,
                        },
                    },
                ],
            },
        };
        Ok(finish(pending, body, e.span))
    }
    fn std_ctor(&self, name: &str) -> Result<(BindingId, u32), InternalError> {
        let id = self
            .resolved
            .stdlib(name)
            .ok_or_else(|| error(format!("missing stdlib {name}")))?;
        match self.binding(id)?.kind {
            BindingKind::Ctor { data, tag } => Ok((data, tag)),
            BindingKind::Fn
            | BindingKind::BuiltinFn(_)
            | BindingKind::ImplFn { .. }
            | BindingKind::Const
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::Record
            | BindingKind::Field { .. }
            | BindingKind::Trait
            | BindingKind::Method { .. }
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Op { .. }
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Local(_) => {
                Err(error(format!("invalid stdlib constructor {name}: {id:?}")))
            }
        }
    }

    /// 01-12「解放の枠と実行時エラーの継続：`with`」の `with` の行。
    pub(super) fn with(
        &mut self,
        e: &ast::WithExpr,
        position: Position,
    ) -> Result<Comp, InternalError> {
        let body_position = match position {
            Position::Tail | Position::Result => Position::Result,
            Position::Other => Position::Other,
        };
        self.with_binds(&e.binds, &e.body, body_position)
    }
    fn with_binds(
        &mut self,
        binds: &[ast::WithBind],
        block: &ast::Block,
        position: Position,
    ) -> Result<Comp, InternalError> {
        let Some((b, rest)) = binds.split_first() else {
            return self.block(block, position);
        };
        let bound = self.expr(&b.value, Position::Other)?;
        let var = self.local(b.id, Some(b.name.text.clone()), self.ty(b.id)?)?;
        let body = self.with_binds(rest, block, position)?;
        let comp = Comp {
            ty: body.ty.clone(),
            eff: state_effect(&body.eff),
            origin: b.span,
            kind: CompKind::Use {
                resource: variable(&var, b.span),
                body: Box::new(body),
            },
        };
        Ok(let_comp(var, bound, comp, b.span))
    }

    /// 01-12「ストア：可変のセルと明示遅延」の `lazy` の規則。
    pub(super) fn lazy(&mut self, e: &ast::LazyExpr) -> Result<Comp, InternalError> {
        let id = self.body_id()?;
        let conts = std::mem::take(&mut self.conts);
        let return_ty = self.return_ty.take();
        let body = self.block(&e.body, Position::Other);
        self.return_ty = return_ty;
        self.conts = conts;
        let body = body?;
        Ok(Comp {
            ty: Ty::Con(TyCon::Builtin(BuiltinTypeId::LAZY), vec![body.ty.clone()]),
            eff: EffectSet::empty(),
            origin: e.span,
            kind: CompKind::Lazy {
                id,
                body: Box::new(body),
            },
        })
    }

    /// 01-12「ハンドラ」の `handle` と節の規則。`Resume` のエフェクトは節を作った後に確定する。
    pub(super) fn handle(&mut self, e: &ast::HandleExpr) -> Result<Comp, InternalError> {
        let info = self
            .types
            .handlers
            .get(e.id)
            .cloned()
            .ok_or_else(|| error(format!("missing handlers for {:?}", e.id)))?;
        if e.clauses.len() != info.clauses.len() {
            return Err(error("handler clause count mismatch"));
        }
        let id = self.body_id()?;
        let body = self.block(&e.body, Position::Other)?;
        let mut clauses = vec![];
        for (clause, info) in e.clauses.iter().zip(&info.clauses) {
            let id = self.body_id()?;
            let mut params = vec![];
            for p in &clause.params {
                params.push(if let Some(n) = &p.name {
                    self.local(p.id, Some(n.text.clone()), self.ty(p.id)?)?
                } else {
                    self.var(None, self.ty(p.id)?)?
                });
            }
            let scheme = self.declared(info.op)?;
            let rigid = scheme
                .type_params
                .iter()
                .enumerate()
                .map(|(i, _)| {
                    Ok(TypeArg::Ty(Ty::Rigid {
                        clause: clause.id,
                        index: number(i)?,
                    }))
                })
                .collect::<Result<Vec<_>, InternalError>>()?;
            let arg = scheme.ret.subst(&rigid, &[]);
            let cont = ContVar {
                id: VarId(fresh(&mut self.vars)?),
                arg,
            };
            self.conts.push((cont.clone(), self.ty(e.id)?));
            let body = self.block(&clause.body, Position::Other)?;
            self.conts.pop();
            clauses.push(Clause {
                id,
                node: clause.id,
                op: info.op,
                params,
                cont,
                tail_resumptive: info.tail_resumptive,
                body,
                span: clause.span,
            });
        }
        let mut handle = Handle {
            id,
            body,
            clauses,
            handled: info.handled,
        };
        settle_handle(&mut handle);
        let eff = handle_effect(&handle, &[]);
        Ok(Comp {
            kind: CompKind::Handle(Box::new(handle)),
            ty: self.ty(e.id)?,
            eff,
            origin: e.span,
        })
    }

    /// 01-12「ハンドラ」の `resume(v)` の規則。最も内側の節の継続を指す。
    pub(super) fn resume(&mut self, e: &ast::ResumeExpr) -> Result<Comp, InternalError> {
        let (cont, ty) = self
            .conts
            .last()
            .cloned()
            .ok_or_else(|| error(format!("no enclosing continuation for {:?}", e.id)))?;
        let mut pending = vec![];
        let value = self.eval(&e.value, &mut pending)?;
        Ok(finish(
            pending,
            Comp {
                kind: CompKind::Resume {
                    cont: cont.id,
                    value,
                },
                ty,
                eff: EffectSet::empty(),
                origin: e.span,
            },
            e.span,
        ))
    }
}

fn state_effect(eff: &EffectSet) -> EffectSet {
    let mut eff = eff.clone();
    eff.insert_name(EffectName::Builtin(BuiltinEffectId::STATE));
    eff
}
fn without(eff: &EffectSet, removed: &EffectSet) -> EffectSet {
    EffectSet {
        names: eff
            .names
            .iter()
            .filter(|n| !removed.names.contains(n))
            .copied()
            .collect(),
        vars: eff
            .vars
            .iter()
            .filter(|n| !removed.vars.contains(n))
            .copied()
            .collect(),
    }
}

/// 節自身の再開のエフェクトを除いて ε を求める。入れ子のハンドラも同じ規則で求める
/// （設計書 02-06「コア IR」の表の後の段落）。
fn handle_effect(h: &Handle<Comp>, skipped: &[VarId]) -> EffectSet {
    let mut eff = without(&effect_without(&h.body, skipped), &h.handled);
    let mut inner = skipped.to_vec();
    inner.extend(h.clauses.iter().map(|c| c.cont.id));
    for clause in &h.clauses {
        eff = eff.union(&effect_without(&clause.body, &inner));
    }
    eff
}
fn effect_without(c: &Comp, skipped: &[VarId]) -> EffectSet {
    match &c.kind {
        CompKind::Return(_) | CompKind::Escape(_) | CompKind::Lazy { .. } => EffectSet::empty(),
        CompKind::Let { bound, body, .. } => {
            effect_without(bound, skipped).union(&effect_without(body, skipped))
        }
        CompKind::App { .. } | CompKind::Method(_) => c.eff.clone(),
        CompKind::Resume { cont, .. } => {
            if skipped.contains(cont) {
                EffectSet::empty()
            } else {
                c.eff.clone()
            }
        }
        CompKind::If {
            then_branch,
            else_branch,
            ..
        } => effect_without(then_branch, skipped).union(&effect_without(else_branch, skipped)),
        CompKind::Match { arms, .. } => arms.iter().fold(EffectSet::empty(), |e, a| {
            let e = e.union(&effect_without(&a.body, skipped));
            a.guard
                .as_ref()
                .map_or(e.clone(), |g| e.union(&effect_without(g, skipped)))
        }),
        CompKind::Use { body, .. } => state_effect(&effect_without(body, skipped)),
        CompKind::Handle(h) => handle_effect(h, skipped),
    }
}

fn settle_handle(h: &mut Handle<Comp>) {
    let eff = handle_effect(h, &[]);
    for clause in &mut h.clauses {
        patch_resume(&mut clause.body, clause.cont.id, &eff);
    }
}
/// 再開を確定して外へエフェクトを求め直す。ラムダと遅延には入り込まない（`resume` はそこに書けない。設計書 02-03「文脈の制限」）。
fn patch_resume(c: &mut Comp, target: VarId, eff: &EffectSet) {
    match &mut c.kind {
        CompKind::Resume { cont, .. } => {
            if *cont == target {
                c.eff = eff.clone();
            }
        }
        CompKind::Return(_)
        | CompKind::Escape(_)
        | CompKind::Lazy { .. }
        | CompKind::App { .. }
        | CompKind::Method(_) => {}
        CompKind::Let { bound, body, .. } => {
            patch_resume(bound, target, eff);
            patch_resume(body, target, eff);
            c.eff = bound.eff.union(&body.eff);
        }
        CompKind::If {
            then_branch,
            else_branch,
            ..
        } => {
            patch_resume(then_branch, target, eff);
            patch_resume(else_branch, target, eff);
            c.eff = then_branch.eff.union(&else_branch.eff);
        }
        CompKind::Match { arms, .. } => {
            c.eff = EffectSet::empty();
            for arm in arms {
                if let Some(g) = &mut arm.guard {
                    patch_resume(g, target, eff);
                    c.eff = c.eff.union(&g.eff);
                }
                patch_resume(&mut arm.body, target, eff);
                c.eff = c.eff.union(&arm.body.eff);
            }
        }
        CompKind::Use { body, .. } => {
            patch_resume(body, target, eff);
            c.eff = state_effect(&body.eff);
        }
        CompKind::Handle(h) => {
            patch_resume(&mut h.body, target, eff);
            for clause in &mut h.clauses {
                patch_resume(&mut clause.body, target, eff);
            }
            settle_handle(h);
            c.eff = handle_effect(h, &[]);
        }
    }
}
