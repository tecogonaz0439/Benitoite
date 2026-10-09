//! パターンの変数と選択肢を移す（設計書 02-06「パターンの拡張」、01-12「ブロック」）。
use super::*;

impl State<'_> {
    /// 01-12「リスト、ラムダ、条件分岐、match」のパターン、および初回リリース版の範囲・リスト・レコード。
    /// 変数の並びはソースを左から辿り、レコードの引数だけ宣言の順に並べ替える。
    pub(super) fn pattern(
        &mut self,
        p: &ast::Pattern,
        vars: &mut Vec<Var>,
    ) -> Result<CorePat, InternalError> {
        Ok(match p {
            ast::Pattern::Wildcard(_) => CorePat::Wild,
            ast::Pattern::Var(v) => CorePat::Var(self.pattern_var(v.id, &v.name.text, vars)?),
            ast::Pattern::Lit(v) => CorePat::Const(constant(
                self.types
                    .lit_values
                    .get(v.id)
                    .ok_or_else(|| error(format!("missing lit_values for {:?}", v.id)))?,
            )?),
            ast::Pattern::Unit(_) => CorePat::Const(Const::Unit),
            ast::Pattern::Ctor(c) => {
                let binding = self.reference(c.id)?;
                let BindingKind::Ctor { data, tag } = self.binding(binding)?.kind else {
                    return Err(error("constructor pattern binding expected"));
                };
                CorePat::Ctor {
                    adt: data,
                    tag,
                    args: c
                        .args
                        .iter()
                        .map(|p| self.pattern(p, vars))
                        .collect::<Result<_, _>>()?,
                }
            }
            ast::Pattern::Record(r) => {
                let adt = self.reference(r.id)?;
                let fields = self
                    .types
                    .adts
                    .get(adt)
                    .and_then(|a| a.record.as_ref())
                    .ok_or_else(|| error("missing record pattern fields"))?
                    .clone();
                let mut written = BTreeMap::new();
                for f in &r.fields {
                    let binding = self.reference(f.id)?;
                    written.insert(binding, self.pattern(&f.pattern, vars)?);
                }
                CorePat::Ctor {
                    adt,
                    tag: 0,
                    args: fields
                        .iter()
                        .map(|f| written.remove(&f.binding).unwrap_or(CorePat::Wild))
                        .collect(),
                }
            }
            ast::Pattern::Range(r) => {
                let (lo, hi) = self
                    .types
                    .range_bounds
                    .get(r.id)
                    .ok_or_else(|| error(format!("missing range_bounds for {:?}", r.id)))?;
                CorePat::Range {
                    lo: constant(lo)?,
                    hi: constant(hi)?,
                }
            }
            ast::Pattern::List(l) => {
                let before = l
                    .before
                    .iter()
                    .map(|p| self.pattern(p, vars))
                    .collect::<Result<_, _>>()?;
                let rest = l
                    .rest
                    .as_ref()
                    .map(|r| {
                        Ok(ListRest {
                            var: r
                                .name
                                .as_ref()
                                .map(|n| self.pattern_var(r.id, &n.text, vars))
                                .transpose()?,
                        })
                    })
                    .transpose()?;
                let after = l
                    .after
                    .iter()
                    .map(|p| self.pattern(p, vars))
                    .collect::<Result<_, _>>()?;
                CorePat::List {
                    before,
                    rest,
                    after,
                }
            }
            ast::Pattern::Error(e) => return Err(error(format!("error pattern {:?}", e.id))),
        })
    }

    fn pattern_var(
        &mut self,
        node: NodeId,
        name: &str,
        vars: &mut Vec<Var>,
    ) -> Result<VarId, InternalError> {
        if let Some(binding) = self.resolved.decls.get(node).copied() {
            let var = self.var(Some(name.into()), self.ty(node)?)?;
            self.locals.insert(binding, var.clone());
            vars.push(var.clone());
            Ok(var.id)
        } else {
            let binding = self.reference(node)?;
            self.locals
                .get(&binding)
                .map(|v| v.id)
                .ok_or_else(|| error(format!("missing alternative local for {node:?}")))
        }
    }

    /// 01-12「リスト、ラムダ、条件分岐、match」の `match` の行。
    /// 初回リリース版の選択肢は行ごと、ガードと本体は分岐ごとに一つだけ作る（ADR 0159）。
    pub(super) fn match_expr(
        &mut self,
        e: &ast::MatchExpr,
        position: Position,
    ) -> Result<Comp, InternalError> {
        let mut pending = vec![];
        let scrutinee = self.eval(&e.scrutinee, &mut pending)?;
        let mut rows = vec![];
        let mut arms = vec![];
        let mut eff = EffectSet::empty();
        for (index, arm) in e.arms.iter().enumerate() {
            let mut vars = vec![];
            for pattern in &arm.patterns {
                rows.push(MatchRow {
                    pattern: self.pattern(pattern, &mut vars)?,
                    arm: number(index)?,
                });
            }
            let guard = arm
                .guard
                .as_ref()
                .map(|g| self.expr(g, Position::Other))
                .transpose()?;
            let body = self.block(&arm.body, position)?;
            eff = eff.union(&body.eff);
            if let Some(g) = &guard {
                eff = eff.union(&g.eff);
            }
            arms.push(MatchArm { vars, guard, body });
        }
        Ok(finish(
            pending,
            Comp {
                ty: self.result_ty(e.id, position)?,
                eff,
                origin: e.span,
                kind: CompKind::Match {
                    scrutinee,
                    rows,
                    arms,
                },
            },
            e.span,
        ))
    }
}
