//! 行と選択肢の順を保つ、予算超過時の照合（設計書 02-06「判定の木への変換」）。

use super::*;
use std::mem::size_of;

impl Lowerer<'_> {
    pub(super) fn node(&mut self, kind: Tree) -> Result<Edge, LowerError> {
        let mut edges = 0_usize;
        let mut args = Some(0_usize);
        kind.visit_edges(|edge| {
            edges = edges.saturating_add(1);
            args = args.and_then(|n| n.checked_add(edge.args.len()));
        });
        let args = args.ok_or_else(|| self.limit_error("table"))?;
        let (extra_nodes, extra_edges) = match &kind {
            Tree::Gets { fields, .. } => (
                fields.len().saturating_mul(2),
                fields.len().saturating_mul(2),
            ),
            Tree::Leaf {
                bindings, fallback, ..
            } => (
                bindings
                    .len()
                    .saturating_mul(2)
                    .saturating_add(usize::from(fallback.is_some()).saturating_mul(2)),
                bindings
                    .len()
                    .saturating_mul(2)
                    .saturating_add(usize::from(fallback.is_some()).saturating_mul(3)),
            ),
            Tree::Ctor { .. } | Tree::Constant { .. } | Tree::Length { .. } => (0, 0),
        };
        let nodes = self
            .arena
            .output_nodes
            .checked_add(1)
            .and_then(|n| n.checked_add(extra_nodes))
            .filter(|n| *n <= arena::MAX_NODES)
            .ok_or_else(|| self.limit_error("nodes"))?;
        let edge_count = self
            .arena
            .output_edges
            .checked_add(edges)
            .and_then(|n| n.checked_add(extra_edges))
            .filter(|n| *n <= arena::MAX_EDGES)
            .ok_or_else(|| self.limit_error("edges"))?;
        let bytes = size_of::<Node>()
            .checked_add(
                args.checked_mul(size_of::<Var>())
                    .ok_or_else(|| self.limit_error("table"))?,
            )
            .and_then(|n| n.checked_add(edges.checked_mul(size_of::<Edge>())?))
            .ok_or_else(|| self.limit_error("table"))?;
        self.arena
            .table(
                bytes
                    .checked_mul(2)
                    .ok_or_else(|| self.limit_error("table"))?,
            )
            .map_err(|_| self.limit_error("table"))?;
        self.arena.output_nodes = nodes;
        self.arena.output_edges = edge_count;
        let id = NodeId(size(self.arena.nodes.len())?);
        self.arena.nodes.push(Some(Node {
            kind,
            params: Vec::new(),
        }));
        Ok(Edge {
            id,
            args: Vec::new(),
        })
    }

    pub(super) fn reserve_output(
        &mut self,
        arena: &DecisionArena,
        joins: usize,
        jumps: usize,
    ) -> Result<(), LowerError> {
        let nodes = arena
            .output_nodes
            .checked_add(joins)
            .and_then(|n| n.checked_add(jumps))
            .and_then(|n| self.def_nodes.checked_add(n))
            .filter(|n| *n <= 1_048_576)
            .ok_or_else(|| self.limit_error("definition_final"))?;
        let edges = joins
            .checked_mul(2)
            .and_then(|n| n.checked_add(arena.output_edges))
            .and_then(|n| n.checked_add(jumps))
            .and_then(|n| self.def_edges.checked_add(n))
            .filter(|n| *n <= 4_194_304)
            .ok_or_else(|| self.limit_error("definition_final"))?;
        if arena
            .output_nodes
            .checked_add(joins)
            .and_then(|n| n.checked_add(jumps))
            .is_none_or(|n| n > arena::MAX_NODES)
        {
            return Err(self.limit_error("nodes"));
        }
        if arena
            .output_edges
            .checked_add(joins.saturating_mul(2))
            .and_then(|n| n.checked_add(jumps))
            .is_none_or(|n| n > arena::MAX_EDGES)
        {
            return Err(self.limit_error("edges"));
        }
        self.def_nodes = nodes;
        self.def_edges = edges;
        Ok(())
    }

    pub(super) fn row_match(
        &mut self,
        scrutinee: &CoreVal,
        rows: &[MatchRow],
        arms: &[MatchArm],
    ) -> Result<Edge, LowerError> {
        let ValKind::Var(id) = scrutinee.kind else {
            return Err(error("match scrutinee is not a variable"));
        };
        let column = Var {
            id,
            name: None,
            ty: scrutinee.ty.clone(),
        };
        let mut next: Option<Edge> = None;
        let mut next_case: Option<Edge> = None;
        let mut previous = None;
        for row in rows.iter().rev() {
            if previous != Some(row.arm) {
                next_case = next.clone();
            }
            previous = Some(row.arm);
            let arm = index(row.arm)?;
            let branch = arms.get(arm).ok_or_else(|| error("invalid arm index"))?;
            let mut bindings = Vec::new();
            // 束縛元はパターンの走査で確定する。成功の節はその後に作る。
            let mut tests = Vec::new();
            self.row_plan(&row.pattern, &column, &mut bindings, &mut tests)?;
            let fallback = if branch.guard.is_some() {
                Some(
                    next_case
                        .clone()
                        .ok_or_else(|| error("missing guard fallback"))?,
                )
            } else {
                None
            };
            let mut success = self.node(Tree::Leaf {
                arm,
                bindings,
                fallback,
            })?;
            for test in tests.into_iter().rev() {
                success = match test {
                    Test::Ctor {
                        column,
                        adt,
                        tag,
                        fields,
                    } => self.node(Tree::Ctor {
                        column,
                        adt,
                        arms: vec![(tag, fields, success)],
                        default: next.clone(),
                    })?,
                    Test::Constant { column, test } => self.node(Tree::Constant {
                        column,
                        arms: vec![(test, success)],
                        default: next.clone(),
                    })?,
                    Test::Length {
                        column,
                        fixed,
                        rest,
                    } => {
                        // 網羅性検査済みの末尾行へ届く値はこのパターンに照合する。
                        // 失敗先がないときは、先行する行が確定した長さを再検査しない。
                        if next.is_none() {
                            continue;
                        }
                        let count = index(fixed)?;
                        // exact は既存の下位 IR の契約どおり全長を持つ。確保前に辺を検査する。
                        if self
                            .arena
                            .output_edges
                            .checked_add(count)
                            .is_none_or(|n| n >= arena::MAX_EDGES)
                        {
                            return Err(self.limit_error("edges"));
                        }
                        self.arena
                            .table(
                                count
                                    .checked_mul(size_of::<(u32, Edge)>())
                                    .ok_or_else(|| self.limit_error("table"))?,
                            )
                            .map_err(|_| self.limit_error("table"))?;
                        let mut exact = Vec::new();
                        for len in 0..fixed {
                            exact.push((
                                len,
                                next.clone()
                                    .ok_or_else(|| error("nonexhaustive list pattern"))?,
                            ));
                        }
                        if rest {
                            self.node(Tree::Length {
                                column,
                                exact,
                                at_least: fixed,
                                otherwise: success,
                            })?
                        } else {
                            exact.push((fixed, success));
                            self.node(Tree::Length {
                                column,
                                exact,
                                at_least: fixed
                                    .checked_add(1)
                                    .ok_or_else(|| self.limit_error("edges"))?,
                                otherwise: next
                                    .clone()
                                    .ok_or_else(|| error("nonexhaustive list pattern"))?,
                            })?
                        }
                    }
                    Test::Gets { list, fields } => self.node(Tree::Gets {
                        list,
                        fields,
                        body: success,
                    })?,
                };
            }
            next = Some(success);
        }
        next.ok_or_else(|| error("empty pattern matrix"))
    }

    #[inline(never)]
    fn row_plan(
        &mut self,
        p: &CorePat,
        column: &Var,
        bindings: &mut Vec<(VarId, Source)>,
        tests: &mut Vec<Test>,
    ) -> Result<(), LowerError> {
        if tests.len() >= arena::MAX_NODES {
            return Err(self.limit_error("nodes"));
        }
        if !matches!(p, CorePat::Wild) {
            self.arena.table(
                size_of::<Test>()
                    .checked_mul(2)
                    .ok_or_else(|| self.limit_error("table"))?,
            )?;
        }
        match p {
            CorePat::Wild => (),
            CorePat::Var(v) => bindings.push((*v, Source::Column(column.clone()))),
            CorePat::Const(c) => tests.push(Test::Constant {
                column: column.clone(),
                test: ConstTest::Eq(c.clone()),
            }),
            CorePat::Range { lo, hi } => tests.push(Test::Constant {
                column: column.clone(),
                test: ConstTest::Range(lo.clone(), hi.clone()),
            }),
            CorePat::Ctor { adt, tag, args } => {
                let Ty::Con(TyCon::Adt(actual), tys, _) = &column.ty else {
                    return Err(error("invalid ADT pattern"));
                };
                if actual != adt {
                    return Err(error("invalid ADT pattern"));
                }
                let tys = self
                    .adts
                    .field_types(*adt, *tag, tys)
                    .ok_or_else(|| error("missing constructor field types"))?;
                if tys.len() != args.len() {
                    return Err(error("pattern arity differs from field count"));
                }
                self.arena
                    .table(
                        tys.len()
                            .checked_mul(size_of::<Var>())
                            .ok_or_else(|| self.limit_error("table"))?,
                    )
                    .map_err(|_| self.limit_error("table"))?;
                let fields = tys
                    .into_iter()
                    .map(|ty| self.var(ty))
                    .collect::<Result<Vec<_>, _>>()?;
                tests.push(Test::Ctor {
                    column: column.clone(),
                    adt: *adt,
                    tag: *tag,
                    fields: fields.clone(),
                });
                for (p, v) in args.iter().zip(fields) {
                    self.row_plan(p, &v, bindings, tests)?;
                }
            }
            CorePat::List {
                before,
                rest,
                after,
            } => {
                let Ty::Con(TyCon::Builtin(b), tys, _) = &column.ty else {
                    return Err(error("invalid list pattern"));
                };
                if *b != BuiltinTypeId::LIST {
                    return Err(error("invalid list pattern"));
                }
                let elem = tys
                    .first()
                    .ok_or_else(|| error("list has no element type"))?;
                let len = before
                    .len()
                    .checked_add(after.len())
                    .ok_or_else(|| self.limit_error("edges"))?;
                self.arena
                    .table(
                        len.checked_mul(size_of::<Var>())
                            .ok_or_else(|| self.limit_error("table"))?,
                    )
                    .map_err(|_| self.limit_error("table"))?;
                tests.push(Test::Length {
                    column: column.clone(),
                    fixed: size(len)?,
                    rest: rest.is_some(),
                });
                let mut fields = Vec::new();
                let mut children = Vec::new();
                for (ps, end) in [
                    (before.as_slice(), ListEnd::Front),
                    (after.as_slice(), ListEnd::Back),
                ] {
                    for (i, p) in ps.iter().enumerate() {
                        if matches!(p, CorePat::Wild) {
                            continue;
                        }
                        let v = self.var(elem.clone())?;
                        let pos = if end == ListEnd::Back {
                            ps.len().saturating_sub(i).saturating_sub(1)
                        } else {
                            i
                        };
                        fields.push((v.clone(), end, size(pos)?));
                        children.push((p, v));
                    }
                }
                tests.push(Test::Gets {
                    list: column.clone(),
                    fields,
                });
                for (p, v) in children {
                    self.row_plan(p, &v, bindings, tests)?;
                }
                if let Some(ListRest { var: Some(id) }) = rest {
                    bindings.push((
                        *id,
                        Source::Slice {
                            list: column.clone(),
                            front: size(before.len())?,
                            back: size(after.len())?,
                        },
                    ));
                }
            }
        }
        Ok(())
    }
}

enum Test {
    Ctor {
        column: Var,
        adt: BindingId,
        tag: u32,
        fields: Vec<Var>,
    },
    Constant {
        column: Var,
        test: ConstTest,
    },
    Length {
        column: Var,
        fixed: u32,
        rest: bool,
    },
    Gets {
        list: Var,
        fields: Vec<(Var, ListEnd, u32)>,
    },
}
