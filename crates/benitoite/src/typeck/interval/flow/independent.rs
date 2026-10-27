//! 未対応の形の子を、忘却した環境と元番号で独立解析する
//! （設計書 02-05「区間解析の独立入力と別本体」）。

use super::*;
use crate::typeck::interval::input::{Handling, SurfaceForm};

/// 入れ子の内側から保存する。環境の initial は Lean の証明用なので保存しない。
#[derive(Debug)]
pub(in crate::typeck) struct IndependentResult {
    pub start: u64,
    pub value: Result<Approx, IdentityStop>,
    pub candidates: Vec<Candidate>,
    pub unsupported: bool,
}

impl<'ast> Flow<'_, 'ast, '_> {
    fn independent(
        &mut self,
        work: impl FnOnce(&mut Self) -> Result<Approx, IdentityStop>,
    ) -> Result<(), IdentityStop> {
        let temporary = self.budget.body.temporary;
        self.frame()?;
        let result = self.capture_independent(work);
        self.budget.release(
            Lifetime::Temporary,
            self.budget.body.temporary.saturating_sub(temporary),
        );
        result
    }

    #[inline(never)]
    fn capture_independent(
        &mut self,
        work: impl FnOnce(&mut Self) -> Result<Approx, IdentityStop>,
    ) -> Result<(), IdentityStop> {
        // independentWith/captureIndependent: 保存枠、親の退避、忘却、解析、保存、復帰。
        // 枠の取得後に停止したときは、停止した入力自身も保存する。
        self.budget
            .reserve(Item::Auxiliary, Lifetime::Saved)
            .map_err(IdentityStop::AnalysisBudget)?;
        let start = self.identity.next;
        let parent = std::mem::take(&mut self.candidates);
        let parent_unsupported = std::mem::replace(&mut self.unsupported, false);
        let checkpoint = self.env.checkpoint();
        let value = self
            .env
            .forget(self.budget)
            .map_err(IdentityStop::AnalysisBudget)
            .and_then(|()| work(self));
        if let Ok(value) = &value {
            self.unsupported |= value.unsupported;
        }
        self.env.rollback(checkpoint, self.budget);
        let candidates = std::mem::replace(&mut self.candidates, parent);
        let unsupported = std::mem::replace(&mut self.unsupported, parent_unsupported);
        self.independent.push(IndependentResult {
            start,
            value,
            candidates,
            unsupported,
        });
        self.independent.last().map_or(Ok(()), |entry| {
            entry.value.as_ref().map(|_| ()).map_err(|e| *e)
        })
    }

    fn independent_expr(&mut self, source: &'ast Expr, fuel: u32) -> Result<(), IdentityStop> {
        self.independent(|flow| flow.expr(source, fuel))
    }

    fn independent_block(&mut self, source: &'ast Block, fuel: u32) -> Result<(), IdentityStop> {
        self.independent(|flow| flow.block(source, fuel))
    }

    /// childExprs/childHoles は空の末尾も分類し、列の長さでも fuel を減らす。
    /// 各要素の枠は末尾から返す。穴は一つの分類だけを持ち、入力を作らない。
    fn child_list(
        &mut self,
        sources: impl Iterator<Item = Option<&'ast Expr>>,
        mut fuel: u32,
        visit_fuel: u32,
    ) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for source in sources.chain(std::iter::once(None)) {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(source) = source {
                    self.independent_expr(source, visit_fuel)?;
                }
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    pub(super) fn unknown_binary(
        &mut self,
        source: &'ast BinaryExpr,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        let _fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        // runExpr は unknownChildren の呼び出し元の fuel を捕捉している。
        self.independent_expr(&source.lhs, fuel)?;
        self.independent_expr(&source.rhs, fuel)?;
        Ok(Approx::unknown())
    }

    #[inline(never)]
    pub(super) fn unknown(
        &mut self,
        source: &'ast Expr,
        fuel: u32,
    ) -> Result<Approx, IdentityStop> {
        let child_fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        let occurrence = self
            .identity
            .occurrences
            .get(
                usize::try_from(self.current_occurrence)
                    .map_err(|_| IdentityStop::NumberOverflow)?,
            )
            .ok_or(IdentityStop::Unmapped(source.id()))?;
        match occurrence.form.handling() {
            Handling::UnknownValue => return Ok(Approx::unknown()),
            Handling::SeparateBody => {
                let body = match source {
                    Expr::Lambda(l) => &l.body,
                    Expr::Lazy(l) => &l.body,
                    Expr::Lit(_)
                    | Expr::Interp(_)
                    | Expr::Name(_)
                    | Expr::Unit(_)
                    | Expr::Paren(_)
                    | Expr::List(_)
                    | Expr::Call(_)
                    | Expr::Record(_)
                    | Expr::Binary(_)
                    | Expr::Unary(_)
                    | Expr::Pipe(_)
                    | Expr::If(_)
                    | Expr::Match(_)
                    | Expr::Return(_)
                    | Expr::Try(_)
                    | Expr::Block(_)
                    | Expr::With(_)
                    | Expr::Handle(_)
                    | Expr::Resume(_)
                    | Expr::Error(_) => return Err(IdentityStop::Unmapped(source.id())),
                };
                self.skip(SkipInput::Statements(&body.stmts), child_fuel)?;
                return Ok(Approx::unknown());
            }
            Handling::Transfer | Handling::IndependentExpressions | Handling::IndependentBlocks => {
            }
        }
        match source {
            Expr::Unary(u) => self.independent_expr(&u.operand, fuel)?,
            Expr::Pipe(p) => {
                self.independent_expr(&p.lhs, fuel)?;
                self.independent_expr(&p.rhs, fuel)?;
            }
            Expr::Call(c) => self.unknown_call(c, occurrence.form, fuel, child_fuel)?,
            Expr::Record(r) => {
                if let Some(base) = &r.base {
                    self.independent_expr(base, fuel)?;
                }
                self.child_list(r.fields.iter().map(|f| Some(&f.value)), child_fuel, fuel)?;
            }
            Expr::List(l) => self.unknown_list(l, occurrence.form, fuel, child_fuel)?,
            Expr::Interp(i) => self.unknown_interpolation(i, fuel, child_fuel)?,
            Expr::Try(t) => {
                self.independent_expr(&t.value, fuel)?;
                if let TryAction::Die { message, .. } = &t.action {
                    let _ = child_fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                    if let Some(message) = message {
                        self.independent_expr(message, fuel)?;
                    }
                }
            }
            Expr::Resume(r) => self.independent_expr(&r.value, fuel)?,
            Expr::Handle(h) => {
                self.independent_block(&h.body, fuel)?;
                if occurrence.form == SurfaceForm::HandleFail {
                    let [clause] = h.clauses.as_slice() else {
                        return Err(IdentityStop::Unmapped(h.id));
                    };
                    self.skip(SkipInput::Statements(&clause.body.stmts), child_fuel)?;
                } else {
                    self.skip(SkipInput::Clauses(&h.clauses), child_fuel)?;
                }
            }
            Expr::With(w) => self.unknown_with(w, 0, fuel)?,
            // 括弧は expr のループが処理する。別本体は親の値の解析に入らない。
            Expr::Paren(_) | Expr::Lambda(_) | Expr::Lazy(_) => {}
            Expr::Lit(_)
            | Expr::Name(_)
            | Expr::Unit(_)
            | Expr::Binary(_)
            | Expr::If(_)
            | Expr::Match(_)
            | Expr::Return(_)
            | Expr::Block(_)
            | Expr::Error(_) => return Err(IdentityStop::Unmapped(source.id())),
        }
        Ok(Approx::unknown())
    }

    fn unknown_call(
        &mut self,
        source: &'ast CallExpr,
        form: SurfaceForm,
        fuel: u32,
        child_fuel: u32,
    ) -> Result<(), IdentityStop> {
        if matches!(form, SurfaceForm::Call | SurfaceForm::PartialCall) {
            self.independent_expr(&source.callee, fuel)?;
        }
        let builder = self
            .tables
            .resolved
            .builder_calls
            .get(source.id)
            .and_then(|b| b.builder);
        let args = source.args.iter().filter(|arg| {
            !matches!(arg.expr(), Some(Expr::Name(n)) if builder.is_some_and(|b| self.tables.resolved.refs.get(n.id) == Some(&b.0)))
        }).map(|arg| arg.expr());
        self.child_list(args, child_fuel, fuel)
    }

    fn synthetic_input(&mut self, node: Node<'ast>, fuel: u32) -> Result<(), IdentityStop> {
        self.independent(|flow| flow.node(node, fuel))
    }

    fn unknown_list(
        &mut self,
        source: &'ast ListExpr,
        form: SurfaceForm,
        fuel: u32,
        child_fuel: u32,
    ) -> Result<(), IdentityStop> {
        if form != SurfaceForm::ListSpread {
            return self.child_list(
                source.elems.iter().filter_map(|e| match e {
                    ListElem::Expr(e) => Some(Some(e)),
                    ListElem::Spread(_) => None,
                }),
                child_fuel,
                fuel,
            );
        }
        let binding = self
            .tables
            .resolved
            .stdlib("Benitoite.List.concatenate")
            .and_then(|b| self.tables.resolved.bindings.get(b))
            .ok_or(IdentityStop::Unmapped(source.id))?;
        let form = if matches!(binding.kind, BindingKind::BuiltinFn(_)) {
            SurfaceForm::PrimName
        } else {
            SurfaceForm::FunName
        };
        self.synthetic_input(
            Node::Synthetic(
                form,
                super::super::identity::Synthetic::ListConcatenate,
                super::super::identity::Origin {
                    node: source.id,
                    span: source.span,
                },
            ),
            fuel,
        )?;
        let spread = source
            .elems
            .iter()
            .position(|e| matches!(e, ListElem::Spread(_)))
            .ok_or(IdentityStop::Unmapped(source.id))?;
        self.child_list(
            source.elems.iter().take(spread).filter_map(|e| match e {
                ListElem::Expr(e) => Some(Some(e)),
                _ => None,
            }),
            child_fuel,
            fuel,
        )?;
        if let Some(ListElem::Spread(s)) = source.elems.get(spread) {
            self.independent_expr(&s.expr, fuel)?;
        }
        self.child_list(
            source
                .elems
                .iter()
                .skip(spread.saturating_add(1))
                .filter_map(|e| match e {
                    ListElem::Expr(e) => Some(Some(e)),
                    _ => None,
                }),
            child_fuel,
            fuel,
        )
    }

    fn unknown_interpolation(
        &mut self,
        source: &'ast InterpExpr,
        fuel: u32,
        child_fuel: u32,
    ) -> Result<(), IdentityStop> {
        self.child_list(
            source.segments.iter().map(|s| Some(&s.expr)),
            child_fuel,
            fuel,
        )?;
        let mut held = 0_u64;
        let result = (|| {
            let mut remaining = child_fuel;
            for segment in &source.segments {
                let ty = self
                    .input
                    .interpolation_type(segment.expr.id())
                    .map_err(IdentityStop::Input)?;
                if segment.format.is_some() || *ty != Ty::Con(TyCon::Builtin(B::STRING), Vec::new())
                {
                    remaining = remaining.checked_sub(1).ok_or(IdentityStop::Depth)?;
                    self.frame()?;
                    held = held.saturating_add(1);
                    self.tick(Operation::Classification)?;
                    self.synthetic_input(
                        Node::Synthetic(
                            SurfaceForm::PrimName,
                            super::super::identity::Synthetic::InterpolationConverter,
                            super::super::identity::Origin {
                                node: segment.expr.id(),
                                span: segment.span,
                            },
                        ),
                        fuel,
                    )?;
                }
            }
            let _ = remaining.checked_sub(1).ok_or(IdentityStop::Depth)?;
            self.frame()?;
            held = held.saturating_add(1);
            self.tick(Operation::Classification)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    pub(super) fn unknown_with(
        &mut self,
        source: &'ast WithExpr,
        index: usize,
        fuel: u32,
    ) -> Result<(), IdentityStop> {
        let bind = source
            .binds
            .get(index)
            .ok_or(IdentityStop::Unmapped(source.id))?;
        self.independent_expr(&bind.value, fuel)?;
        let binding = *self
            .tables
            .resolved
            .decls
            .get(bind.id)
            .ok_or(IdentityStop::Input(InputError::MissingBinding(bind.id)))?;
        let checkpoint = self.env.checkpoint();
        let result = (|| {
            self.env
                .write(binding, Slot::Unknown, self.budget)
                .map_err(IdentityStop::AnalysisBudget)?;
            if source.binds.get(index.saturating_add(1)).is_some() {
                self.independent(|flow| {
                    let fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                    flow.frame()?;
                    let result = (|| {
                        flow.tick(Operation::Classification)?;
                        // 合成した Block.last の式も通常の expr と同じ順序で識別する。
                        flow.node(Node::With(source, index.saturating_add(1)), fuel)
                    })();
                    flow.budget.release(Lifetime::Temporary, 1);
                    result
                })
            } else {
                self.independent_block(&source.body, fuel)
            }
        })();
        self.env.rollback(checkpoint, self.budget);
        result
    }
}
