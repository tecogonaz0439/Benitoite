//! 解決済みの構文からの構造入力と先行順番号
//! （設計書 02-05「Scope の必須判定の入力」）。

use super::*;
use crate::base::BindingMap;
use crate::modules::{ModuleKind, ModuleTable};
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::*;
use crate::types::Scheme;
use std::collections::{BTreeMap, BTreeSet};

const MAX_INPUT_DEPTH: u32 = 4096;

enum Event {
    Depth(u32),
    Expression(ScopeOrigin, Span),
    Constant(BindingId, NodeId),
    Converter(NodeId, Span, bool),
    Statement(NodeId, NodeId),
    Call(Box<ScopeCall>),
    Argument {
        call: usize,
        source: usize,
        node: NodeId,
    },
    Stop(ScopeInputStop),
    DiagnosedInput(NodeId),
}

pub(super) struct PendingBody {
    body: ScopeNumberedInput,
    constant: bool,
    events: Vec<Event>,
    pub(super) program: super::lower::Program,
    pub(super) literal: super::lower::Argument,
}

pub(super) struct Structure {
    pub(super) bodies: Vec<PendingBody>,
    pub(super) constants: BTreeMap<BindingId, usize>,
    rules: Vec<bool>,
    pub(super) diagnosed: Vec<bool>,
}

impl std::fmt::Debug for Structure {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ScopeStructure")
            .field("bodies", &self.bodies.len())
            .finish_non_exhaustive()
    }
}

pub(super) fn finish(bodies: Vec<PendingBody>, converters: NodeMap<bool>) -> ScopeInputs {
    let constants: BTreeMap<_, _> = bodies
        .iter()
        .enumerate()
        .filter_map(|(i, b)| {
            b.body
                .binding
                .filter(|_| b.constant)
                .map(|binding| (binding, i))
        })
        .collect();
    // 定数の参照を共有したまま、規則の存在を逆向きに伝える。各辺は一度だけ辿る。
    let mut rules: Vec<_> = bodies
        .iter()
        .map(|b| {
            b.body.stopped.is_some()
                || b.events.iter().any(|e| {
                    matches!(
                        e,
                        Event::Call(_) | Event::Stop(_) | Event::DiagnosedInput(_)
                    )
                })
        })
        .collect();
    let mut users = vec![Vec::new(); bodies.len()];
    for (index, body) in bodies.iter().enumerate() {
        for event in &body.events {
            if let Event::Constant(binding, _) = event
                && let Some(target) = constants.get(binding)
                && let Some(list) = users.get_mut(*target)
            {
                list.push(index);
            }
        }
    }
    let mut queue: std::collections::VecDeque<_> = rules
        .iter()
        .enumerate()
        .filter_map(|(i, r)| r.then_some(i))
        .collect();
    while let Some(index) = queue.pop_front() {
        for user in users.get(index).into_iter().flatten() {
            if let Some(false) = rules.get(*user)
                && let Some(rule) = rules.get_mut(*user)
            {
                *rule = true;
                queue.push_back(*user);
            }
        }
    }
    let converters = std::sync::Arc::new(converters);
    // 前段で診断済みのエラーノードを、表の欠落から区別する。定数経由も含める。
    let mut diagnosed: Vec<_> = bodies
        .iter()
        .map(|body| {
            body.events
                .iter()
                .any(|event| matches!(event, Event::DiagnosedInput(_)))
        })
        .collect();
    let mut queue: std::collections::VecDeque<_> = diagnosed
        .iter()
        .enumerate()
        .filter_map(|(index, diagnosed)| diagnosed.then_some(index))
        .collect();
    while let Some(index) = queue.pop_front() {
        for user in users.get(index).into_iter().flatten() {
            if let Some(false) = diagnosed.get(*user)
                && let Some(flag) = diagnosed.get_mut(*user)
            {
                *flag = true;
                queue.push_back(*user);
            }
        }
    }
    let structure = std::sync::Arc::new(Structure {
        bodies,
        constants,
        rules,
        diagnosed,
    });
    let mut by_binding = BindingMap::default();
    for (index, body) in structure.bodies.iter().enumerate() {
        if let Some(binding) = body.body.binding {
            by_binding.insert(binding, index);
        }
    }
    ScopeInputs {
        by_binding,
        bodies: structure
            .bodies
            .iter()
            .enumerate()
            .map(|(index, b)| ScopeBodyInput {
                body_key: b.body.body_key.clone(),
                binding: b.body.binding,
                entry: b.body.entry.clone(),
                structure: std::sync::Arc::clone(&structure),
                converters: std::sync::Arc::clone(&converters),
                index,
            })
            .collect(),
    }
}

struct ReadFrame {
    body: usize,
    event: usize,
    calls: Vec<usize>,
    depth: u32,
    offset: u32,
}

impl Structure {
    pub fn rule_calls(&self, index: usize) -> Vec<ScopeCall> {
        self.bodies
            .get(index)
            .into_iter()
            .flat_map(|body| &body.events)
            .filter_map(|event| match event {
                Event::Call(call) => Some(call.as_ref().clone()),
                Event::Depth(_)
                | Event::Expression(..)
                | Event::Constant(..)
                | Event::Converter(..)
                | Event::Statement(..)
                | Event::Argument { .. }
                | Event::Stop(_)
                | Event::DiagnosedInput(_) => None,
            })
            .collect()
    }

    pub fn contains_rules(&self, index: usize) -> bool {
        self.rules.get(index).copied().unwrap_or(false)
    }

    pub fn number(
        &self,
        index: usize,
        max_operations: u64,
        budget: &mut ScopeNumberingBudget,
        converters: &NodeMap<bool>,
        pending: bool,
        mut body: ScopeNumberedInput,
    ) -> ScopeNumberedInput {
        body.stopped = self.bodies.get(index).and_then(|b| b.body.stopped);
        if body.stopped.is_some() {
            return body;
        }
        let mut next = 0_u64;
        let mut stack = vec![ReadFrame {
            body: index,
            event: 0,
            calls: Vec::new(),
            depth: 0,
            offset: 0,
        }];
        while let Some(frame) = stack.last_mut() {
            let Some(event) = self
                .bodies
                .get(frame.body)
                .and_then(|b| b.events.get(frame.event))
            else {
                stack.pop();
                continue;
            };
            // Lean の局所解析の費用とは別の、Rust の展開量の制限である。
            if budget.operations >= max_operations {
                body.stopped = Some(ScopeInputStop::NumberingLimit { max_operations });
                break;
            }
            body.numbering_operations = body.numbering_operations.saturating_add(1);
            budget.operations = budget.operations.saturating_add(1);
            frame.event = frame.event.saturating_add(1);
            let (origin, span) = match event {
                Event::Depth(depth) => {
                    frame.depth = *depth;
                    if frame.offset.saturating_add(*depth) > MAX_INPUT_DEPTH {
                        body.stopped = Some(ScopeInputStop::Depth);
                        break;
                    }
                    continue;
                }
                Event::Expression(origin, span) => (*origin, *span),
                Event::Constant(binding, node) => {
                    let Some(index) = self.constants.get(binding) else {
                        body.stopped = Some(ScopeInputStop::MissingInput(*node));
                        break;
                    };
                    // 定数の参照は constE の子だけを展開し、定義自身の最初の文の印を含めない。
                    let offset = frame.offset.saturating_add(frame.depth).saturating_add(1);
                    // 深さ0のイベントを省いても、共有先へ入る時点の深さを検査する。
                    if offset > MAX_INPUT_DEPTH {
                        body.stopped = Some(ScopeInputStop::Depth);
                        break;
                    }
                    if let Some(stop) = self.bodies.get(*index).and_then(|b| b.body.stopped) {
                        body.stopped = Some(stop);
                        break;
                    }
                    stack.push(ReadFrame {
                        body: *index,
                        event: 1,
                        calls: Vec::new(),
                        depth: 0,
                        offset,
                    });
                    continue;
                }
                Event::Converter(node, span, formatted) => {
                    match if *formatted {
                        Some(true)
                    } else {
                        converters.get(*node).copied().or(pending.then_some(true))
                    } {
                        Some(true) => (ScopeOrigin::InterpolationConverter(*node), *span),
                        Some(false) => continue,
                        None => {
                            body.stopped = Some(ScopeInputStop::PendingInterpolation(*node));
                            break;
                        }
                    }
                }
                Event::Statement(statement, rhs) => {
                    body.statements.push(ScopeStatement {
                        statement: *statement,
                        rhs: *rhs,
                        preorder: next,
                    });
                    continue;
                }
                Event::Call(call) => {
                    frame.calls.push(body.calls.len());
                    let mut call = call.as_ref().clone();
                    call.preorder = next;
                    body.calls.push(call);
                    continue;
                }
                Event::Argument { call, source, node } => {
                    let Some(target) = frame.calls.get(*call).and_then(|i| body.calls.get_mut(*i))
                    else {
                        body.stopped = Some(ScopeInputStop::MissingInput(*node));
                        break;
                    };
                    if target.argument_preorders.len() != *source {
                        body.stopped = Some(ScopeInputStop::MissingInput(*node));
                        break;
                    }
                    target.argument_preorders.push(next);
                    continue;
                }
                Event::DiagnosedInput(node) => {
                    body.stopped = Some(ScopeInputStop::MissingInput(*node));
                    break;
                }
                Event::Stop(stop) => {
                    body.stopped = Some(*stop);
                    break;
                }
            };
            let Some(after) = next.checked_add(1) else {
                body.stopped = Some(ScopeInputStop::NumberOverflow);
                break;
            };
            body.occurrences.push(ScopeOccurrence {
                preorder: next,
                origin,
                span,
            });
            next = after;
        }
        body
    }
}

enum Task<'a> {
    Expr(&'a Expr),
    PipeRight(&'a Expr, NodeId),
    Conditional(&'a IfExpr),
    Block(&'a Block),
    With(&'a WithExpr, usize),
    Emit(Event),
}

struct Collector<'a> {
    resolved: &'a ResolveOutput,
    schemes: &'a BindingMap<Scheme>,
    constants: &'a BTreeMap<BindingId, &'a ConstDecl>,
    standard: &'a BTreeMap<BindingId, ScopeDeclaration>,
    events: Vec<Event>,
    stack: Vec<(Task<'a>, u32)>,
    calls: usize,
    arguments: BTreeMap<NodeId, Vec<super::lower::Argument>>,
}

impl<'a> Collector<'a> {
    fn later(&mut self, task: Task<'a>, depth: u32) {
        self.stack.push((task, depth.saturating_add(1)));
    }

    fn emit(&mut self, origin: ScopeOrigin, span: Span) {
        self.events.push(Event::Expression(origin, span));
    }

    fn reference(&self, node: NodeId) -> Option<BindingId> {
        self.resolved.refs.get(node).copied()
    }

    fn call(&self, call: &CallExpr, pipe_input: Option<NodeId>) -> Option<ScopeCall> {
        let Expr::Name(name) = call.callee.as_ref() else {
            return None;
        };
        let binding = self.reference(name.id)?;
        let declaration = *self.standard.get(&binding)?;
        if self.resolved.builder_calls.get(call.id).is_some() {
            return None;
        }
        let scheme = self.schemes.get(binding)?;
        let offset = usize::from(pipe_input.is_some());
        if call.args.len().checked_add(offset)? != scheme.param_names.len() {
            return None;
        }
        let mut arguments = Vec::new();
        let mut source_to_contract = Vec::new();
        let mut seen = BTreeSet::new();
        if pipe_input.is_some() {
            seen.insert(0);
        }
        for (source, arg) in call.args.iter().enumerate() {
            arguments.push(arg.expr()?.id());
            let position = match arg {
                Arg::Named(arg) => scheme
                    .param_names
                    .iter()
                    .position(|n| n == &arg.name.text)?,
                Arg::Expr(_) | Arg::Placeholder(_) => source.checked_add(offset)?,
            };
            if !seen.insert(position) {
                return None;
            }
            source_to_contract.push(position);
        }
        let contract_to_source = (0..scheme.param_names.len())
            .map(|position| {
                if position == 0
                    && let Some(node) = pipe_input
                {
                    Some(ScopeArgumentSource::PipeLeft(node))
                } else {
                    source_to_contract
                        .iter()
                        .position(|p| *p == position)
                        .map(ScopeArgumentSource::Explicit)
                }
            })
            .collect::<Option<Vec<_>>>()?;
        Some(ScopeCall {
            preorder: 0,
            node: call.id,
            declaration,
            binding,
            arguments,
            argument_preorders: Vec::new(),
            source_to_contract,
            contract_to_source,
        })
    }

    fn block(&mut self, block: &'a Block, depth: u32) {
        for stmt in block.stmts.iter().rev() {
            let (statement, rhs) = match stmt {
                Stmt::Bind(b) if self.resolved.builder_binds.get(b.id).is_some() => continue,
                Stmt::Bind(b) => (b.id, &b.value),
                Stmt::Expr(e) => (e.id(), e),
                Stmt::Error(e) => {
                    self.later(Task::Emit(Event::DiagnosedInput(e.id)), depth);
                    continue;
                }
            };
            self.later(Task::Expr(rhs), depth);
            self.later(Task::Emit(Event::Statement(statement, rhs.id())), depth);
        }
    }

    fn conditional(&mut self, conditional: &'a IfExpr, depth: u32) {
        match &conditional.else_branch {
            Some(ElseBranch::Block(b)) => self.later(Task::Block(b), depth),
            Some(ElseBranch::If(e)) => self.later(Task::Conditional(e), depth),
            None => (),
        }
        self.later(Task::Block(&conditional.then_block), depth);
        self.later(Task::Expr(&conditional.cond), depth);
    }

    fn with(&mut self, source: &'a WithExpr, index: usize, depth: u32) {
        let Some(bind) = source.binds.get(index) else {
            self.events
                .push(Event::Stop(ScopeInputStop::MissingInput(source.id)));
            return;
        };
        if index != 0 {
            self.events.push(Event::Statement(bind.id, bind.id));
            self.emit(ScopeOrigin::WithBinding(bind.id), bind.span);
        }
        if index.saturating_add(1) < source.binds.len() {
            self.later(Task::With(source, index.saturating_add(1)), depth);
        } else {
            self.later(Task::Block(&source.body), depth);
        }
        self.later(Task::Expr(&bind.value), depth);
    }

    fn expression(&mut self, expr: &'a Expr, depth: u32, pipe_input: Option<NodeId>) {
        let scope_call = if let Expr::Call(call) = expr
            && let Some(call) = self.call(call, pipe_input)
        {
            let ordinal = self.calls;
            self.calls = self.calls.saturating_add(1);
            self.arguments.insert(
                call.node,
                if let Expr::Call(c) = expr {
                    c.args
                        .iter()
                        .filter_map(Arg::expr)
                        .map(|e| super::lower::argument(e, self.resolved, self.schemes))
                        .collect()
                } else {
                    Vec::new()
                },
            );
            self.events.push(Event::Call(Box::new(call)));
            Some(ordinal)
        } else {
            None
        };
        self.emit(ScopeOrigin::Expression(expr.id()), expr.span());
        match expr {
            Expr::Name(n) => {
                if let Some(id) = self.reference(n.id)
                    && self
                        .resolved
                        .bindings
                        .get(id)
                        .is_some_and(|b| matches!(b.kind, BindingKind::Const))
                {
                    if self.constants.contains_key(&id) {
                        self.events.push(Event::Constant(id, n.id));
                    } else {
                        self.events
                            .push(Event::Stop(ScopeInputStop::MissingInput(n.id)));
                    }
                }
            }
            Expr::Lit(_) | Expr::Unit(_) => (),
            Expr::Paren(p) => self.later(Task::Expr(&p.inner), depth),
            Expr::Call(c) => {
                let builder_call = self.resolved.builder_calls.get(c.id);
                let constructor = if let Expr::Name(n) = c.callee.as_ref() {
                    self.reference(n.id)
                        .and_then(|id| self.resolved.bindings.get(id))
                        .is_some_and(|b| {
                            matches!(b.kind, BindingKind::Ctor { .. } | BindingKind::Record)
                        })
                } else {
                    false
                };
                let builder = builder_call.and_then(|b| b.builder);
                for (source, arg) in c.args.iter().enumerate().rev() {
                    if let Some(e) = arg.expr() {
                        if matches!(e, Expr::Name(n) if builder.is_some_and(|b| self.reference(n.id) == Some(b.0)))
                        {
                            continue;
                        }
                        self.later(Task::Expr(e), depth);
                        if let Some(call) = scope_call {
                            self.later(
                                Task::Emit(Event::Argument {
                                    call,
                                    source,
                                    node: e.id(),
                                }),
                                depth,
                            );
                        }
                    }
                }
                if builder_call.is_none() && !constructor {
                    self.later(Task::Expr(&c.callee), depth);
                }
            }
            Expr::Binary(b) => {
                self.later(Task::Expr(&b.rhs), depth);
                self.later(Task::Expr(&b.lhs), depth);
            }
            Expr::Pipe(p) => {
                self.later(Task::PipeRight(&p.rhs, p.lhs.id()), depth);
                self.later(Task::Expr(&p.lhs), depth);
            }
            Expr::Unary(u) => {
                if u.op == UnOp::Not || !matches!(u.operand.as_ref(), Expr::Lit(_)) {
                    self.later(Task::Expr(&u.operand), depth);
                }
            }
            Expr::Return(r) => self.later(Task::Expr(&r.value), depth),
            Expr::Resume(r) => self.later(Task::Expr(&r.value), depth),
            Expr::Record(r) => {
                for field in r.fields.iter().rev() {
                    self.later(Task::Expr(&field.value), depth);
                }
                if let Some(base) = &r.base {
                    self.later(Task::Expr(base), depth);
                }
            }
            Expr::List(l) => {
                for element in l.elems.iter().rev() {
                    match element {
                        ListElem::Expr(e) => self.later(Task::Expr(e), depth),
                        ListElem::Spread(s) => self.later(Task::Expr(&s.expr), depth),
                    }
                }
                if l.elems.iter().any(|e| matches!(e, ListElem::Spread(_))) {
                    self.later(
                        Task::Emit(Event::Expression(
                            ScopeOrigin::ListConcatenate(l.id),
                            l.span,
                        )),
                        depth,
                    );
                }
            }
            Expr::Interp(i) => {
                for segment in i.segments.iter().rev() {
                    self.later(
                        Task::Emit(Event::Converter(
                            segment.expr.id(),
                            segment.span,
                            segment.format.is_some(),
                        )),
                        depth,
                    );
                }
                for segment in i.segments.iter().rev() {
                    self.later(Task::Expr(&segment.expr), depth);
                }
            }
            Expr::Lambda(l) => self.later(Task::Block(&l.body), depth),
            Expr::Lazy(l) => self.later(Task::Block(&l.body), depth),
            Expr::Block(b) => self.later(Task::Block(&b.body), depth),
            Expr::If(i) => self.conditional(i, depth),
            Expr::Match(m) => {
                for arm in m.arms.iter().rev() {
                    self.later(Task::Block(&arm.body), depth);
                    if let Some(guard) = &arm.guard {
                        self.later(Task::Expr(guard), depth);
                    }
                }
                self.later(Task::Expr(&m.scrutinee), depth);
            }
            Expr::Try(t) => {
                if let TryAction::Die {
                    message: Some(message),
                    ..
                } = &t.action
                {
                    self.later(Task::Expr(message), depth);
                }
                self.later(Task::Expr(&t.value), depth);
            }
            Expr::With(w) => self.with(w, 0, depth),
            Expr::Handle(h) => {
                for clause in h.clauses.iter().rev() {
                    self.later(Task::Block(&clause.body), depth);
                }
                self.later(Task::Block(&h.body), depth);
            }
            Expr::Error(e) => self.events.push(Event::DiagnosedInput(e.id)),
        }
    }

    fn run(
        mut self,
        task: Task<'a>,
    ) -> (Vec<Event>, BTreeMap<NodeId, Vec<super::lower::Argument>>) {
        self.stack.push((task, 0));
        let mut previous_depth = 0;
        while let Some((task, depth)) = self.stack.pop() {
            if depth > MAX_INPUT_DEPTH {
                self.events.push(Event::Stop(ScopeInputStop::Depth));
                break;
            }
            if depth != previous_depth {
                self.events.push(Event::Depth(depth));
                previous_depth = depth;
            }
            match task {
                Task::Expr(e) => self.expression(e, depth, None),
                Task::PipeRight(e, node) => self.expression(e, depth, Some(node)),
                Task::Conditional(i) => {
                    self.emit(ScopeOrigin::Conditional(i.id), i.span);
                    self.conditional(i, depth);
                }
                Task::Block(b) => self.block(b, depth),
                Task::With(w, index) => self.with(w, index, depth),
                Task::Emit(e) => self.events.push(e),
            }
            if matches!(self.events.last(), Some(Event::Stop(_))) {
                break;
            }
        }
        (self.events, self.arguments)
    }
}

fn standard_declarations(
    modules: &ModuleTable,
    resolved: &ResolveOutput,
) -> BTreeMap<BindingId, ScopeDeclaration> {
    use ScopeDeclaration::*;
    [
        ("Benitoite.Scope", CheckPath),
        ("Benitoite.Network.Http", CheckRequest),
        ("Benitoite.Scope", PathValue),
        ("Benitoite.Network.Http", RequestValue),
        ("Benitoite.Scope", WidenPath),
        ("Benitoite.Network.Http", WidenRequest),
    ]
    .into_iter()
    .filter_map(|(module_name, declaration)| {
        let short = declaration.name().rsplit('.').next()?;
        let binding = resolved.stdlib(&format!("{module_name}.{short}"))?;
        let owner = resolved.bindings.get(binding)?;
        let module = modules.get(owner.module)?;
        (matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
            && module.name.dotted() == module_name
            && owner.name == short
            && matches!(owner.kind, BindingKind::BuiltinFn(_)))
        .then_some((binding, declaration))
    })
    .collect()
}

pub(super) fn collect(
    asts: &[Module],
    modules: &ModuleTable,
    resolved: &ResolveOutput,
    schemes: &BindingMap<Scheme>,
    implementations: &NodeMap<crate::types::ImplDef>,
) -> Vec<PendingBody> {
    use crate::typeck::source_input::{BodySource, definition_inputs};
    let definitions: Vec<_> = definition_inputs(asts, modules, resolved).collect();
    let constants = definitions
        .iter()
        .filter_map(|d| match d.as_ref().ok()?.source {
            BodySource::Constant(c) => Some((d.as_ref().ok()?.binding, c)),
            _ => None,
        })
        .collect();
    let standard = standard_declarations(modules, resolved);
    definitions
        .iter()
        .map(|d| {
            let d = match d {
                Ok(d) => d,
                Err(error) => {
                    return PendingBody {
                        body: ScopeNumberedInput {
                            body_key: ScopeKey {
                                definition: error.name.clone(),
                                surface_preorder: 0,
                            },
                            binding: error.binding,
                            entry: ScopeEntry {
                                dictionaries: 0,
                                positions: Vec::new(),
                                next_id: 0,
                            },
                            occurrences: Vec::new(),
                            statements: Vec::new(),
                            calls: Vec::new(),
                            numbering_operations: 0,
                            stopped: Some(ScopeInputStop::MissingInput(error.node)),
                        },
                        constant: false,
                        events: Vec::new(),
                        program: super::lower::Program::default(),
                        literal: super::lower::Argument::Other,
                    };
                }
            };
            let mut stopped = None;
            let scheme = schemes.get(d.binding);
            let captured = match resolved.bindings.get(d.binding).map(|b| b.kind) {
                Some(BindingKind::ImplFn { impl_decl }) => implementations
                    .get(impl_decl)
                    .map(|i| i.class_constraints.len()),
                Some(_) => Some(0),
                None => None,
            };
            // 実装自身の辞書は捕捉環境であり、MethodInput.names の明示引数ではない。
            // 脱糖がメソッド自身の辞書を取り出すのと同じ範囲を使う。
            let dictionaries = scheme
                .and_then(|s| captured.and_then(|n| s.class_constraints.len().checked_sub(n)))
                .unwrap_or_else(|| {
                    stopped = Some(ScopeInputStop::MissingInput(d.source.node()));
                    0
                });
            let mut positions = vec![None; dictionaries];
            positions.extend(
                d.source
                    .params()
                    .iter()
                    .map(|p| resolved.decls.get(p.id).copied()),
            );
            // binds は引数列を反転する。entryScope の idAt(0) は最後の値引数である。
            positions.reverse();
            let next_id = u64::try_from(positions.len()).unwrap_or_else(|_| {
                stopped = Some(ScopeInputStop::NumberOverflow);
                0
            });
            let body = ScopeNumberedInput {
                body_key: ScopeKey {
                    definition: d.name.clone(),
                    surface_preorder: 0,
                },
                binding: Some(d.binding),
                entry: ScopeEntry {
                    dictionaries,
                    positions,
                    next_id,
                },
                occurrences: Vec::new(),
                statements: Vec::new(),
                calls: Vec::new(),
                numbering_operations: 0,
                stopped,
            };
            let collector = Collector {
                resolved,
                schemes,
                constants: &constants,
                standard: &standard,
                events: Vec::new(),
                stack: Vec::new(),
                calls: 0,
                arguments: BTreeMap::new(),
            };
            let (events, arguments) = match d.source {
                BodySource::Constant(c) => {
                    let mut events = vec![Event::Statement(c.id, c.value.id())];
                    let (rest, arguments) = collector.run(Task::Expr(&c.value));
                    events.extend(rest);
                    (events, arguments)
                }
                BodySource::Function { body, .. } => collector.run(Task::Block(body)),
            };
            let code = if events.iter().any(|e| matches!(e, Event::Call(_))) {
                super::lower::collect(d.source, resolved, schemes)
            } else {
                Vec::new()
            };
            let literal = match d.source {
                BodySource::Constant(c) => super::lower::argument(&c.value, resolved, schemes),
                _ => super::lower::Argument::Other,
            };
            PendingBody {
                program: super::lower::Program { code, arguments },
                literal,
                body,
                constant: matches!(d.source, BodySource::Constant(_)),
                events,
            }
        })
        .collect()
}
