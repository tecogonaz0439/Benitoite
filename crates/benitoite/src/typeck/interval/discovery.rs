//! 元定義からの別本体の発見と、同じ予算での待ち行列作成
//! （設計書 02-05「区間解析の独立入力と別本体」）。

use super::budget::{Budget, Item, Lifetime, Operation};
use super::environment::{Environment, SavedEnvironment, Slot};
use super::identity::{
    EmbeddedBody, IdentityMap, IdentityStop, Origin, Synthetic, TraversalNode as Node,
};
use super::input::SurfaceForm as F;
use super::input::{BodyInput, BodySource, InputError, InputTables};
use crate::base::{BindingId, NodeId};
use crate::syntax::ast::*;
use std::collections::BTreeMap;

pub(super) struct Entry<'ast> {
    pub embedded: EmbeddedBody<'ast>,
    pub initial: Option<SavedEnvironment>,
    pub type_owner: BindingId,
}

/// 発見と反転は別の停止である。枠取得後に環境構築が止まった項目も残す。
pub(super) struct DiscoveryReport<'ast> {
    pub result: Result<(), IdentityStop>,
    pub queue: Option<Result<(), IdentityStop>>,
    pub entries: Vec<Entry<'ast>>,
}

struct Discovery<'a, 'ast, 'tables> {
    input: &'a BodyInput<'ast>,
    tables: &'a InputTables<'tables>,
    constants: &'a BTreeMap<BindingId, &'a BodyInput<'ast>>,
    budget: &'a mut Budget,
    env: Environment,
    next: u64,
    entries: Vec<Entry<'ast>>,
    counting: bool,
    identity: Option<&'a mut IdentityMap<'ast>>,
    parent: Option<u64>,
}

impl<'ast> Discovery<'_, 'ast, '_> {
    fn tick(&mut self, op: Operation) -> Result<(), IdentityStop> {
        self.budget.charge(op).map_err(IdentityStop::AnalysisBudget)
    }
    fn frame(&mut self) -> Result<(), IdentityStop> {
        self.budget
            .reserve(Item::StackFrame, Lifetime::Temporary)
            .map_err(IdentityStop::AnalysisBudget)
    }
    fn scope<T>(
        &mut self,
        work: impl FnOnce(&mut Self) -> Result<T, IdentityStop>,
    ) -> Result<T, IdentityStop> {
        self.frame()?;
        let checkpoint = self.env.checkpoint();
        let result = work(self);
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(Lifetime::Temporary, 1);
        result
    }
    fn write(&mut self, binding: Option<BindingId>, slot: Slot) -> Result<(), IdentityStop> {
        match binding {
            Some(binding) => self.env.write(binding, slot, self.budget),
            None => self.env.anonymous(slot, self.budget),
        }
        .map_err(IdentityStop::AnalysisBudget)
    }
    fn binding(&self, node: NodeId) -> Option<BindingId> {
        self.tables.resolved.decls.get(node).copied()
    }

    fn typed_values(&mut self, params: &'ast [Param]) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for param in params.iter().map(Some).chain(std::iter::once(None)) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(param) = param {
                    let binding = self
                        .binding(param.id)
                        .ok_or(IdentityStop::Input(InputError::MissingBinding(param.id)))?;
                    let ty = self
                        .input
                        .local_type(binding)
                        .or_else(|| self.input.expression_type(param.id).ok())
                        .ok_or(IdentityStop::Input(InputError::MissingType(param.id)))?;
                    let slot = Slot::top(ty);
                    self.write(Some(binding), slot)?;
                }
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn save_entry(
        &mut self,
        embedded: EmbeddedBody<'ast>,
        prepare: impl FnOnce(&mut Self) -> Result<(), IdentityStop>,
    ) -> Result<SavedEnvironment, IdentityStop> {
        self.budget
            .reserve(Item::Auxiliary, Lifetime::Saved)
            .map_err(IdentityStop::AnalysisBudget)?;
        let parent_head = self.env.snapshot();
        let result = (|| {
            prepare(self)?;
            let middle = self.env.checkpoint();
            self.env
                .forget(self.budget)
                .map_err(IdentityStop::AnalysisBudget)?;
            Ok(self.env.save_since(middle, self.budget))
        })();
        self.env.select(parent_head);
        self.entries.push(Entry {
            embedded,
            initial: result.as_ref().ok().cloned(),
            type_owner: self.input.definition.binding,
        });
        result
    }

    fn in_seed<T>(
        &mut self,
        seed: SavedEnvironment,
        work: impl FnOnce(&mut Self) -> Result<T, IdentityStop>,
    ) -> Result<T, IdentityStop> {
        let parent = std::mem::replace(&mut self.env, Environment::from_saved(seed));
        let checkpoint = self.env.checkpoint();
        let result = work(self);
        self.env.rollback(checkpoint, self.budget);
        self.env = parent;
        result
    }

    fn counted(
        &mut self,
        work: impl FnOnce(&mut Self) -> Result<(), IdentityStop>,
    ) -> Result<u64, IdentityStop> {
        let next = self.next;
        let parent = self.counting;
        self.counting = true;
        let result = work(self).map(|()| self.next.saturating_sub(next));
        self.next = next;
        self.counting = parent;
        result.map_err(IdentityStop::for_numbering)
    }

    fn expr(&mut self, mut node: Node<'ast>, mut fuel: u32) -> Result<(), IdentityStop> {
        let checkpoint = self.env.checkpoint();
        let outer = self.parent;
        let start = self.next;
        let mut held = 0_u64;
        let result = (|| loop {
            fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
            self.frame()?;
            held = held.saturating_add(1);
            let owner = self.next;
            if let Some(map) = &mut self.identity {
                map.identify(self.input, self.tables, node, self.parent, self.budget)?;
                self.next = map.next;
                self.parent = Some(owner);
            } else {
                self.tick(Operation::Numbering)
                    .map_err(IdentityStop::for_numbering)?;
                self.next = self
                    .next
                    .checked_add(1)
                    .ok_or(IdentityStop::NumberOverflow)?;
            }
            if !self.counting {
                self.tick(Operation::Classification)?;
            }
            // skipExpr は identify の後で skipChildren の fuel も一段消費する。
            if self.identity.is_some() {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
            }
            if let Node::Expr(Expr::Paren(p)) = node {
                node = Node::Expr(&p.inner);
            } else {
                let result = self.children(node, owner, fuel);
                if result.is_ok()
                    && let Some(map) = &mut self.identity
                {
                    map.finish(owner);
                }
                break result;
            }
        })();
        if result.is_ok()
            && let Some(map) = &mut self.identity
        {
            // 括弧のループで保持した祖先だけを閉じる。子の終端は子自身が設定する。
            for key in start..start.saturating_add(held) {
                map.finish(key);
            }
        }
        self.parent = outer;
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(Lifetime::Temporary, held);
        if self.identity.is_some() {
            result.map_err(IdentityStop::for_numbering)
        } else {
            result
        }
    }

    #[inline(never)]
    fn children(&mut self, node: Node<'ast>, owner: u64, fuel: u32) -> Result<(), IdentityStop> {
        match node {
            Node::Root => match self.input.definition.source {
                BodySource::Constant(c) => self.last(Node::Expr(&c.value), fuel),
                BodySource::Function { body, .. } => self.block(body, fuel),
            },
            Node::Synthetic(..) => Ok(()),
            Node::Conditional(i) => self.conditional(i, fuel),
            Node::With(w, index) => self.with(w, index, fuel),
            Node::Expr(source) => match source {
                Expr::Lambda(l) if !self.counting => {
                    self.boundary(owner, &l.body, fuel, |this| this.typed_values(&l.params))
                }
                Expr::Lazy(l) if !self.counting => self.boundary(owner, &l.body, fuel, |_| Ok(())),
                Expr::Lambda(l) => self.block(&l.body, fuel),
                Expr::Lazy(l) => self.block(&l.body, fuel),
                Expr::Name(n) => self.name(n, fuel),
                Expr::Paren(p) => self.expr(Node::Expr(&p.inner), fuel),
                Expr::Return(r) => self.expr(Node::Expr(&r.value), fuel),
                Expr::Resume(r) => self.expr(Node::Expr(&r.value), fuel),
                Expr::Unary(u) => {
                    if u.op == UnOp::Not || !matches!(u.operand.as_ref(), Expr::Lit(_)) {
                        self.expr(Node::Expr(&u.operand), fuel)
                    } else {
                        Ok(())
                    }
                }
                Expr::Binary(b) => {
                    self.expr(Node::Expr(&b.lhs), fuel)?;
                    self.expr(Node::Expr(&b.rhs), fuel)
                }
                Expr::Pipe(p) => {
                    self.expr(Node::Expr(&p.lhs), fuel)?;
                    self.expr(Node::Expr(&p.rhs), fuel)
                }
                Expr::Call(c) => self.call(c, fuel),
                Expr::Record(r) => self.record(r, fuel),
                Expr::List(l) => self.list_expr(l, fuel),
                Expr::Interp(i) => self.interpolation(i, fuel),
                Expr::If(i) => self.conditional(i, fuel),
                Expr::Match(m) => {
                    self.expr(Node::Expr(&m.scrutinee), fuel)?;
                    self.arms(&m.arms, fuel)
                }
                Expr::Try(t) => {
                    self.expr(Node::Expr(&t.value), fuel)?;
                    if let TryAction::Die { message, .. } = &t.action {
                        self.optional(message.as_deref().map(Node::Expr), fuel)?;
                    }
                    Ok(())
                }
                Expr::Block(b) => self.block(&b.body, fuel),
                Expr::With(w) => self.with(w, 0, fuel),
                Expr::Handle(h) => self.handle(h, owner, fuel),
                Expr::Lit(_) | Expr::Unit(_) => Ok(()),
                Expr::Error(e) => Err(IdentityStop::Unmapped(e.id)),
            },
        }
    }

    #[inline(never)]
    fn name(&mut self, n: &'ast NameExpr, fuel: u32) -> Result<(), IdentityStop> {
        let binding = *self
            .tables
            .resolved
            .refs
            .get(n.id)
            .ok_or(IdentityStop::MissingReference(n.id))?;
        if !matches!(
            self.tables.resolved.bindings.get(binding).map(|b| &b.kind),
            Some(crate::resolve::BindingKind::Const)
        ) {
            return Ok(());
        }
        let parent = self.input;
        let constant = self
            .constants
            .get(&binding)
            .copied()
            .ok_or(IdentityStop::MissingConstant(binding))?;
        let BodySource::Constant(c) = constant.definition.source else {
            return Err(IdentityStop::MissingConstant(binding));
        };
        self.input = constant;
        let checkpoint = self.env.checkpoint();
        self.env.clear_locals();
        let result = self.expr(Node::Expr(&c.value), fuel);
        self.env.rollback(checkpoint, self.budget);
        self.input = parent;
        result
    }

    #[inline(never)]
    fn call(&mut self, c: &'ast CallExpr, fuel: u32) -> Result<(), IdentityStop> {
        let builder_call = self.tables.resolved.builder_calls.get(c.id);
        let constructor = if let Expr::Name(n) = c.callee.as_ref() {
            self.tables
                .resolved
                .refs
                .get(n.id)
                .and_then(|b| self.tables.resolved.bindings.get(*b))
                .is_some_and(|b| {
                    matches!(
                        b.kind,
                        crate::resolve::BindingKind::Ctor { .. }
                            | crate::resolve::BindingKind::Record
                    )
                })
        } else {
            false
        };
        if builder_call.is_none() && !constructor {
            self.expr(Node::Expr(&c.callee), fuel)?;
        }
        let builder = builder_call.and_then(|b| b.builder);
        self.list(c.args.iter().filter(|a| !matches!(a.expr(), Some(Expr::Name(n)) if builder.is_some_and(|b| self.tables.resolved.refs.get(n.id) == Some(&b.0)))).map(|a| a.expr().map(Node::Expr)), fuel)
    }

    #[inline(never)]
    fn record(&mut self, r: &'ast RecordExpr, fuel: u32) -> Result<(), IdentityStop> {
        if let Some(base) = &r.base {
            self.expr(Node::Expr(base), fuel)?;
        }
        self.list(r.fields.iter().map(|f| Some(Node::Expr(&f.value))), fuel)
    }

    #[inline(never)]
    fn interpolation(&mut self, i: &'ast InterpExpr, fuel: u32) -> Result<(), IdentityStop> {
        self.list(i.segments.iter().map(|s| Some(Node::Expr(&s.expr))), fuel)?;
        let input = self.input;
        self.list(i.segments.iter().filter(|s| {
        s.format.is_some() || input.interpolation_type(s.expr.id()).is_ok_and(|t| !matches!(t, crate::types::Ty::Con(crate::types::TyCon::Builtin(b), a) if *b == crate::types::builtin::BuiltinTypeId::STRING && a.is_empty()))
    }).map(|s| Some(Node::Synthetic(F::PrimName, Synthetic::InterpolationConverter, Origin { node: s.expr.id(), span: s.span }))), fuel)
    }

    fn boundary(
        &mut self,
        owner: u64,
        body: &'ast Block,
        fuel: u32,
        prepare: impl FnOnce(&mut Self) -> Result<(), IdentityStop>,
    ) -> Result<(), IdentityStop> {
        let index = self.entries.len();
        let seed = self.save_entry(
            EmbeddedBody {
                owner,
                ordinal: 0,
                body,
                parent_start: Some(self.next),
                parent_end: None,
            },
            prepare,
        )?;
        let result = self.in_seed(seed, |this| this.block(body, fuel));
        if result.is_ok()
            && let Some(entry) = self.entries.get_mut(index)
        {
            entry.embedded.parent_end = Some(self.next);
        }
        result
    }

    fn list(
        &mut self,
        sources: impl Iterator<Item = Option<Node<'ast>>>,
        mut fuel: u32,
    ) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for source in sources.chain(std::iter::once(None)) {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(source) = source {
                    self.expr(source, fuel)?;
                }
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }
    fn optional(&mut self, source: Option<Node<'ast>>, fuel: u32) -> Result<(), IdentityStop> {
        let fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        if let Some(source) = source {
            self.expr(source, fuel)?;
        }
        Ok(())
    }
    fn last(&mut self, source: Node<'ast>, fuel: u32) -> Result<(), IdentityStop> {
        let fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
        self.scope(|this| {
            this.tick(Operation::Classification)?;
            this.expr(source, fuel)
        })
    }
    fn block(&mut self, source: &'ast Block, fuel: u32) -> Result<(), IdentityStop> {
        self.statements(&source.stmts, fuel)
    }
    fn statements(&mut self, statements: &'ast [Stmt], mut fuel: u32) -> Result<(), IdentityStop> {
        let checkpoint = self.env.checkpoint();
        let mut held = 0_u64;
        let result = (|| {
            let mut statements = statements.iter().peekable();
            loop {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                let Some(statement) = statements.next() else {
                    break;
                };
                match statement {
                    Stmt::Bind(bind) => {
                        if self.tables.resolved.builder_binds.get(bind.id).is_some() {
                            if !self.counting {
                                self.write(
                                    self.tables.resolved.builder_binds.get(bind.id).copied(),
                                    Slot::Builder,
                                )?;
                            }
                            continue;
                        }
                        self.expr(Node::Expr(&bind.value), fuel)?;
                        if statements.peek().is_some() && !self.counting {
                            self.pattern(&bind.pattern)?;
                        }
                    }
                    Stmt::Expr(expr) => self.expr(Node::Expr(expr), fuel)?,
                    Stmt::Error(e) => return Err(IdentityStop::Unmapped(e.id)),
                }
                if statements.peek().is_none() {
                    break;
                }
            }
            Ok(())
        })();
        self.env.rollback(checkpoint, self.budget);
        self.budget.release(Lifetime::Temporary, held);
        result
    }
    fn conditional(&mut self, source: &'ast IfExpr, fuel: u32) -> Result<(), IdentityStop> {
        self.expr(Node::Expr(&source.cond), fuel)?;
        self.block(&source.then_block, fuel)?;
        match &source.else_branch {
            Some(ElseBranch::Block(b)) => self.block(b, fuel),
            Some(ElseBranch::If(i)) => self.expr(Node::Conditional(i), fuel),
            None => Ok(()),
        }
    }
    fn list_expr(&mut self, source: &'ast ListExpr, fuel: u32) -> Result<(), IdentityStop> {
        let Some(index) = source
            .elems
            .iter()
            .position(|e| matches!(e, ListElem::Spread(_)))
        else {
            return self.list(
                source.elems.iter().filter_map(|e| match e {
                    ListElem::Expr(e) => Some(Some(Node::Expr(e))),
                    _ => None,
                }),
                fuel,
            );
        };
        let binding = self
            .tables
            .resolved
            .stdlib("Benitoite.List.concatenate")
            .and_then(|b| self.tables.resolved.bindings.get(b))
            .ok_or(IdentityStop::Unmapped(source.id))?;
        let form = if matches!(binding.kind, crate::resolve::BindingKind::BuiltinFn(_)) {
            F::PrimName
        } else {
            F::FunName
        };
        self.expr(
            Node::Synthetic(
                form,
                Synthetic::ListConcatenate,
                Origin {
                    node: source.id,
                    span: source.span,
                },
            ),
            fuel,
        )?;
        self.list(
            source.elems.iter().take(index).filter_map(|e| match e {
                ListElem::Expr(e) => Some(Some(Node::Expr(e))),
                _ => None,
            }),
            fuel,
        )?;
        if let Some(ListElem::Spread(s)) = source.elems.get(index) {
            self.expr(Node::Expr(&s.expr), fuel)?;
        }
        self.list(
            source
                .elems
                .iter()
                .skip(index.saturating_add(1))
                .filter_map(|e| match e {
                    ListElem::Expr(e) => Some(Some(Node::Expr(e))),
                    _ => None,
                }),
            fuel,
        )
    }
    fn with(
        &mut self,
        source: &'ast WithExpr,
        index: usize,
        fuel: u32,
    ) -> Result<(), IdentityStop> {
        let bind = source
            .binds
            .get(index)
            .ok_or(IdentityStop::Unmapped(source.id))?;
        self.expr(Node::Expr(&bind.value), fuel)?;
        if !self.counting {
            self.write(self.binding(bind.id), Slot::Unknown)?;
        }
        if index.saturating_add(1) < source.binds.len() {
            self.last(Node::With(source, index.saturating_add(1)), fuel)
        } else {
            self.block(&source.body, fuel)
        }
    }

    fn repeat_slots(
        &mut self,
        bindings: impl Iterator<Item = (Option<BindingId>, Slot)> + Clone,
    ) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for _ in bindings.clone().map(Some).chain(std::iter::once(None)) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
            }
            self.budget.release(Lifetime::Temporary, 1);
            held = held.saturating_sub(1);
            for (binding, slot) in bindings {
                self.write(binding, slot)?;
                self.budget.release(Lifetime::Temporary, 1);
                held = held.saturating_sub(1);
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn clause_env(
        &mut self,
        clause: &'ast HandleClause,
        failure: bool,
    ) -> Result<(), IdentityStop> {
        self.env
            .forget(self.budget)
            .map_err(IdentityStop::AnalysisBudget)?;
        if failure {
            let [param] = clause.params.as_slice() else {
                return Err(IdentityStop::Unmapped(clause.id));
            };
            self.write(self.binding(param.id), Slot::Unknown)?;
            return self.write(None, Slot::Unavailable);
        }
        let op = *self
            .tables
            .resolved
            .refs
            .get(clause.op.id)
            .ok_or(IdentityStop::MissingReference(clause.op.id))?;
        let scheme = self
            .tables
            .schemes
            .get(op)
            .ok_or(IdentityStop::MissingScheme(op))?;
        let resolved = self.tables.resolved;
        let bindings = scheme
            .class_constraints
            .iter()
            .map(|_| (None, Slot::Unknown))
            .chain(
                clause
                    .params
                    .iter()
                    .map(|p| (resolved.decls.get(p.id).copied(), Slot::Unknown)),
            )
            .chain(std::iter::once((None, Slot::Unknown)));
        self.repeat_slots(bindings)
    }

    fn handle(
        &mut self,
        source: &'ast HandleExpr,
        owner: u64,
        fuel: u32,
    ) -> Result<(), IdentityStop> {
        if self.counting {
            self.block(&source.body, fuel)?;
            if self.input.failure_handler(source.id) {
                let [clause] = source.clauses.as_slice() else {
                    return Err(IdentityStop::Unmapped(source.id));
                };
                return self.block(&clause.body, fuel);
            }
            return self.clauses(&source.clauses, fuel);
        }
        let count = self.counted(|this| this.block(&source.body, u32::MAX))?;
        let start = self.next.saturating_add(count);
        if self.input.failure_handler(source.id) {
            let [clause] = source.clauses.as_slice() else {
                return Err(IdentityStop::Unmapped(source.id));
            };
            let embedded = EmbeddedBody {
                owner,
                ordinal: 0,
                body: &clause.body,
                parent_start: Some(start),
                parent_end: None,
            };
            let index = self.entries.len();
            let seed = self.save_entry(embedded, |this| this.clause_env(clause, true))?;
            self.block(&source.body, fuel)?;
            let result = self.in_seed(seed, |this| this.block(&clause.body, fuel));
            if result.is_ok()
                && let Some(entry) = self.entries.get_mut(index)
            {
                entry.embedded.parent_end = Some(self.next);
            }
            result
        } else {
            self.save_clauses(&source.clauses, owner, start)?;
            self.block(&source.body, fuel)?;
            self.clauses(&source.clauses, fuel)
        }
    }
    fn save_clauses(
        &mut self,
        clauses: &'ast [HandleClause],
        owner: u64,
        mut start: u64,
    ) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for (ordinal, clause) in clauses
                .iter()
                .map(Some)
                .chain(std::iter::once(None))
                .enumerate()
            {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(clause) = clause {
                    self.scope(|this| {
                        this.save_entry(
                            EmbeddedBody {
                                owner,
                                ordinal,
                                body: &clause.body,
                                parent_start: Some(start),
                                parent_end: None,
                            },
                            |this| this.clause_env(clause, false),
                        )
                        .map(|_| ())
                    })?;
                    let next = self.next;
                    self.next = start;
                    let count = self.counted(|this| this.block(&clause.body, u32::MAX));
                    self.next = next;
                    let count = count?;
                    if let Some(entry) = self.entries.last_mut() {
                        entry.embedded.parent_end = Some(start.saturating_add(count));
                    }
                    start = start.saturating_add(count);
                }
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }
    fn clauses(
        &mut self,
        clauses: &'ast [HandleClause],
        mut fuel: u32,
    ) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for clause in clauses.iter().map(Some).chain(std::iter::once(None)) {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(clause) = clause {
                    if self.counting {
                        self.block(&clause.body, fuel)?;
                    } else {
                        self.scope(|this| {
                            this.clause_env(clause, false)?;
                            this.block(&clause.body, fuel)
                        })?;
                    }
                }
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }

    fn arms(&mut self, arms: &'ast [MatchArm], mut fuel: u32) -> Result<(), IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            for arm in arms.iter().map(Some).chain(std::iter::once(None)) {
                fuel = fuel.checked_sub(1).ok_or(IdentityStop::Depth)?;
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(arm) = arm {
                    if self.counting {
                        self.optional(arm.guard.as_deref().map(Node::Expr), fuel)?;
                        self.block(&arm.body, fuel)?;
                        continue;
                    }
                    self.scope(|this| {
                        if !this.counting {
                            let mut bindings = Vec::new();
                            if let Some(first) = arm.patterns.first() {
                                this.pattern_bindings(first, &mut bindings)?;
                            }
                            // countList は空の末尾も数える。
                            let mut count_frames = 0_u64;
                            let counted = (|| {
                                for _ in 0..=bindings.len() {
                                    this.frame()?;
                                    count_frames = count_frames.saturating_add(1);
                                    this.tick(Operation::Classification)?;
                                }
                                Ok(())
                            })();
                            this.budget.release(Lifetime::Temporary, count_frames);
                            counted?;
                            this.repeat_slots(bindings.into_iter())?;
                        }
                        this.optional(arm.guard.as_deref().map(Node::Expr), fuel)?;
                        this.block(&arm.body, fuel)
                    })?;
                }
            }
            Ok(())
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }
    fn pattern_bindings(
        &self,
        pattern: &'ast Pattern,
        bindings: &mut Vec<(Option<BindingId>, Slot)>,
    ) -> Result<(), IdentityStop> {
        match pattern {
            Pattern::Var(v) => bindings.push((
                Some(
                    self.binding(v.id)
                        .or_else(|| self.tables.resolved.refs.get(v.id).copied())
                        .ok_or(IdentityStop::Input(InputError::MissingBinding(v.id)))?,
                ),
                Slot::Unknown,
            )),
            Pattern::Ctor(c) => {
                for p in &c.args {
                    self.pattern_bindings(p, bindings)?;
                }
            }
            Pattern::Record(r) => {
                let mut order: Vec<_> = r
                    .fields
                    .iter()
                    .map(|f| self.field_index(f).map(|i| (i, f)))
                    .collect::<Result<_, _>>()?;
                order.sort_by_key(|(index, _)| *index);
                for (_, field) in order {
                    self.pattern_bindings(&field.pattern, bindings)?;
                }
            }
            Pattern::List(l) => {
                for p in &l.before {
                    self.pattern_bindings(p, bindings)?;
                }
                if let Some(rest) = &l.rest
                    && rest.name.is_some()
                {
                    bindings.push((
                        Some(
                            self.binding(rest.id)
                                .ok_or(IdentityStop::Input(InputError::MissingBinding(rest.id)))?,
                        ),
                        Slot::Unknown,
                    ));
                }
                for p in &l.after {
                    self.pattern_bindings(p, bindings)?;
                }
            }
            Pattern::Wildcard(_) | Pattern::Lit(_) | Pattern::Unit(_) | Pattern::Range(_) => {}
            Pattern::Error(e) => return Err(IdentityStop::Unmapped(e.id)),
        }
        Ok(())
    }
    fn pattern(&mut self, source: &'ast Pattern) -> Result<(), IdentityStop> {
        if let Pattern::Var(v) = source {
            let binding = self
                .binding(v.id)
                .ok_or(IdentityStop::Input(InputError::MissingBinding(v.id)))?;
            let slot = self
                .input
                .local_type(binding)
                .map_or(Slot::Unknown, Slot::top);
            return self.write(Some(binding), slot);
        }
        if matches!(source, Pattern::Wildcard(_)) {
            return Ok(());
        }
        self.tick(Operation::Classification)?;
        self.pattern_binders(source)?;
        let mut bindings = Vec::new();
        self.pattern_bindings(source, &mut bindings)?;
        self.repeat_slots(bindings.into_iter())
    }

    fn pattern_binders(&mut self, source: &'ast Pattern) -> Result<u64, IdentityStop> {
        self.scope(|this| {
            this.tick(Operation::Classification)?;
            match source {
                Pattern::Var(_) => Ok(1),
                Pattern::Ctor(c) => this.pattern_sum(c.args.iter()),
                Pattern::List(l) => {
                    let before = this.pattern_sum(l.before.iter())?;
                    let after = this.pattern_sum(l.after.iter())?;
                    Ok(before.saturating_add(after).saturating_add(u64::from(
                        l.rest.as_ref().is_some_and(|r| r.name.is_some()),
                    )))
                }
                Pattern::Record(r) => this.record_binders(r),
                Pattern::Wildcard(_) | Pattern::Lit(_) | Pattern::Unit(_) | Pattern::Range(_) => {
                    Ok(0)
                }
                Pattern::Error(e) => Err(IdentityStop::Unmapped(e.id)),
            }
        })
    }
    fn pattern_sum(
        &mut self,
        sources: impl Iterator<Item = &'ast Pattern>,
    ) -> Result<u64, IdentityStop> {
        let mut held = 0_u64;
        let result = (|| {
            let mut count = 0_u64;
            for source in sources.map(Some).chain(std::iter::once(None)) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(source) = source {
                    count = count.saturating_add(self.pattern_binders(source)?);
                }
            }
            Ok(count)
        })();
        self.budget.release(Lifetime::Temporary, held);
        result
    }
    fn field_index(&self, field: &FieldPat) -> Result<u32, IdentityStop> {
        let binding = *self
            .tables
            .resolved
            .refs
            .get(field.id)
            .ok_or(IdentityStop::MissingReference(field.id))?;
        match self.tables.resolved.bindings.get(binding).map(|b| &b.kind) {
            Some(crate::resolve::BindingKind::Field { index, .. }) => Ok(*index),
            _ => Err(IdentityStop::MissingReference(field.id)),
        }
    }
    fn record_binders(&mut self, source: &'ast RecordPat) -> Result<u64, IdentityStop> {
        let mut held = 0_u64;
        let mut counts = Vec::new();
        let mut saved = 0_u64;
        let result = (|| {
            // patternCounts: 各欄を先に数え、末尾から recordField を確保する。
            for field in source.fields.iter().map(Some).chain(std::iter::once(None)) {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if let Some(field) = field {
                    counts.push(self.pattern_binders(&field.pattern)?);
                }
            }
            self.budget.release(Lifetime::Temporary, 1);
            held = held.saturating_sub(1);
            for _ in &counts {
                self.budget
                    .reserve(Item::RecordField, Lifetime::Temporary)
                    .map_err(IdentityStop::AnalysisBudget)?;
                saved = saved.saturating_add(1);
                self.budget.release(Lifetime::Temporary, 1);
                held = held.saturating_sub(1);
            }
            let owner = *self
                .tables
                .resolved
                .refs
                .get(source.id)
                .ok_or(IdentityStop::MissingReference(source.id))?;
            let count = self
                .tables
                .schemes
                .get(owner)
                .ok_or(IdentityStop::MissingScheme(owner))?
                .params
                .len();
            let mut total = 0_u64;
            // fieldsSum と field の空の末尾も、それぞれ再帰の一枠と分類を持つ。
            for index in 0..=count {
                self.frame()?;
                held = held.saturating_add(1);
                self.tick(Operation::Classification)?;
                if index == count {
                    break;
                }
                let mut fields_held = 0_u64;
                let found = (|| {
                    for pair in source
                        .fields
                        .iter()
                        .zip(&counts)
                        .map(Some)
                        .chain(std::iter::once(None))
                    {
                        self.frame()?;
                        fields_held = fields_held.saturating_add(1);
                        self.tick(Operation::Classification)?;
                        match pair {
                            Some((field, value))
                                if usize::try_from(self.field_index(field)?).ok()
                                    == Some(index) =>
                            {
                                return Ok(*value);
                            }
                            None => break,
                            _ => {}
                        }
                    }
                    Ok(0)
                })();
                self.budget.release(Lifetime::Temporary, fields_held);
                total = total.saturating_add(found?);
            }
            Ok(total)
        })();
        self.budget
            .release(Lifetime::Temporary, held.saturating_add(saved));
        result
    }
}

pub(super) fn prepare_root<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    budget: &mut Budget,
) -> Result<SavedEnvironment, IdentityStop> {
    let mut this = Discovery {
        input,
        tables,
        constants,
        budget,
        env: Environment::default(),
        next: 0,
        entries: Vec::new(),
        counting: false,
        identity: None,
        parent: None,
    };
    this.scope(|this| {
        this.typed_values(input.definition.source.params())?;
        let middle = this.env.checkpoint();
        this.env
            .forget(this.budget)
            .map_err(IdentityStop::AnalysisBudget)?;
        Ok(this.env.save_since(middle, this.budget))
    })
}

pub(super) fn discover<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    seed: SavedEnvironment,
    budget: &mut Budget,
    fuel: u32,
) -> DiscoveryReport<'ast> {
    let mut this = Discovery {
        input,
        tables,
        constants,
        budget,
        env: Environment::from_saved(seed),
        next: 0,
        entries: Vec::new(),
        counting: false,
        identity: None,
        parent: None,
    };
    let result = this.scope(|this| {
        this.env
            .forget(this.budget)
            .map_err(IdentityStop::AnalysisBudget)?;
        this.expr(Node::Root, fuel)
    });
    let queue = if this.budget.exhausted().is_some() {
        None
    } else {
        // reverseEntries の枠と各参照の保存だけを数える。環境と入力は共有する。
        let mut held = 0_u64;
        let temporary = this.budget.body.temporary;
        let prepared = this.scope(|this| {
            let result = (|| {
                for entry in this
                    .entries
                    .iter()
                    .rev()
                    .map(Some)
                    .chain(std::iter::once(None))
                {
                    this.budget
                        .reserve(Item::StackFrame, Lifetime::Temporary)
                        .map_err(IdentityStop::AnalysisBudget)?;
                    held = held.saturating_add(1);
                    this.budget
                        .charge(Operation::Classification)
                        .map_err(IdentityStop::AnalysisBudget)?;
                    if entry.is_some() {
                        this.budget
                            .reserve(Item::Auxiliary, Lifetime::Temporary)
                            .map_err(IdentityStop::AnalysisBudget)?;
                    }
                }
                Ok(())
            })();
            this.budget.release(Lifetime::Temporary, held);
            if result.is_ok() {
                this.budget.save_temporary(
                    this.budget
                        .body
                        .temporary
                        .saturating_sub(temporary.saturating_add(1)),
                );
            } else {
                let count = this
                    .budget
                    .body
                    .temporary
                    .saturating_sub(temporary.saturating_add(1));
                this.budget.release(Lifetime::Temporary, count);
            }
            result
        });
        Some(prepared)
    };
    DiscoveryReport {
        result,
        queue,
        entries: this.entries,
    }
}

/// BudgetWalk の skip 群。発見の読み取り専用の構造走査を使い、環境や発見列を作らない。
/// 番号の対応は親の解析と同じ表へ一度だけ保存する。
pub(super) enum SkipInput<'ast> {
    Expr(Node<'ast>),
    Statements(&'ast [Stmt]),
    Arguments(&'ast [Arg]),
    Arms(&'ast [MatchArm]),
    Clauses(&'ast [HandleClause]),
    Optional(Option<&'ast Expr>),
}

pub(super) fn skip<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    budget: &mut Budget,
    fuel: u32,
    traversal: (&mut IdentityMap<'ast>, Option<u64>),
    source: SkipInput<'ast>,
) -> Result<(), IdentityStop> {
    let (identity, parent) = traversal;
    let mut this = Discovery {
        input,
        tables,
        constants,
        budget,
        env: Environment::default(),
        next: identity.next,
        entries: Vec::new(),
        counting: true,
        identity: Some(identity),
        parent,
    };
    let result = match source {
        SkipInput::Expr(node) => this.expr(node, fuel),
        SkipInput::Statements(stmts) => this.statements(stmts, fuel),
        SkipInput::Arguments(args) => {
            this.list(args.iter().map(|arg| arg.expr().map(Node::Expr)), fuel)
        }
        SkipInput::Arms(arms) => this.arms(arms, fuel),
        SkipInput::Clauses(clauses) => this.clauses(clauses, fuel),
        SkipInput::Optional(value) => this.optional(value.map(Node::Expr), fuel),
    };
    result.map_err(IdentityStop::for_numbering)
}

#[cfg(test)]
pub(super) fn identify_all<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    budget: &mut Budget,
    fuel: u32,
    identity: &mut IdentityMap<'ast>,
) -> Result<(), IdentityStop> {
    skip(
        input,
        tables,
        constants,
        budget,
        fuel,
        (identity, None),
        SkipInput::Expr(Node::Root),
    )
}

/// BudgetScan.patternEnv。構造パターンは個々の値の事実を渡さず位置だけを作る。
pub(super) fn pattern_env<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    budget: &mut Budget,
    env: &mut Environment,
    pattern: &'ast Pattern,
) -> Result<(), IdentityStop> {
    let mut this = Discovery {
        input,
        tables,
        constants,
        budget,
        env: std::mem::take(env),
        next: 0,
        entries: Vec::new(),
        counting: false,
        identity: None,
        parent: None,
    };
    let result = this.pattern(pattern);
    *env = this.env;
    result
}
