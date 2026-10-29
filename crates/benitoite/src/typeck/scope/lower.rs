//! ScopeLower の局所解析が辿る部分だけを、番号を持たない命令列へ写す。
//! （設計書 02-05「Scope の必須判定の入力」）。
//! 番号は input の一つの走査が与え、ここでは数え直さない。

use super::*;
use crate::base::BindingMap;
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::*;
use crate::types::Scheme;

#[derive(Clone, Debug)]
pub(super) enum Argument {
    String(std::sync::Arc<str>),
    Integer(i64),
    Constant(BindingId),
    Local(BindingId),
    Projection(BindingId),
    Other,
}

fn direct_head(expr: &Expr, resolved: &ResolveOutput, schemes: &BindingMap<Scheme>) -> bool {
    if let Expr::Name(n) = expr
        && let Some(binding) = resolved.refs.get(n.id)
    {
        resolved.bindings.get(*binding).is_some_and(|b| {
            // 登録済みの操作は表層の primName、利用者の操作は opName である。
            matches!(
                b.kind,
                BindingKind::Fn
                    | BindingKind::ImplFn { .. }
                    | BindingKind::BuiltinFn(_)
                    | BindingKind::Field { .. }
            ) || resolved.builtin_ops.get(*binding).is_some()
        }) && schemes
            .get(*binding)
            .is_some_and(|s| s.class_constraints.is_empty())
    } else {
        false
    }
}

pub(super) fn argument(
    expr: &Expr,
    resolved: &ResolveOutput,
    schemes: &BindingMap<Scheme>,
) -> Argument {
    match expr {
        Expr::Lit(LitExpr {
            lit: Literal::Str(s),
            ..
        }) => Argument::String(s.as_str().into()),
        Expr::Lit(LitExpr {
            lit: Literal::Int { radix, digits },
            ..
        }) => i64::from_str_radix(digits, *radix).map_or(Argument::Other, Argument::Integer),
        Expr::Unary(u) if u.op == UnOp::Neg => {
            if let Expr::Lit(LitExpr {
                lit: Literal::Int { radix, digits },
                ..
            }) = u.operand.as_ref()
            {
                i128::from_str_radix(digits, *radix)
                    .ok()
                    .and_then(|n| n.checked_neg())
                    .and_then(|n| i64::try_from(n).ok())
                    .map_or(Argument::Other, Argument::Integer)
            } else {
                Argument::Other
            }
        }
        Expr::Name(n) => resolved
            .refs
            .get(n.id)
            .and_then(|b| resolved.bindings.get(*b).map(|d| (*b, d.kind)))
            .map_or(Argument::Other, |(b, k)| match k {
                BindingKind::Const => Argument::Constant(b),
                BindingKind::Local(_) => Argument::Local(b),
                BindingKind::Fn
                | BindingKind::BuiltinFn(_)
                | BindingKind::ImplFn { .. }
                | BindingKind::Data
                | BindingKind::BuiltinType(_)
                | BindingKind::Alias
                | BindingKind::ExternalType
                | BindingKind::Record
                | BindingKind::Field { .. }
                | BindingKind::Ctor { .. }
                | BindingKind::Trait
                | BindingKind::Method { .. }
                | BindingKind::Effect
                | BindingKind::BuiltinEffect(_)
                | BindingKind::Op { .. }
                | BindingKind::Module(_)
                | BindingKind::NamespaceRoot
                | BindingKind::TypeParam { .. }
                | BindingKind::EffectVar { .. } => Argument::Other,
            }),
        Expr::Call(c) if c.args.len() == 1 => {
            // projectRule.transfer は none である。同定の有無によらず、射影の値は未知だが、
            // 引数の読み取りと適用の計上点は lowerArg の proj として残す。
            let direct = direct_head(&c.callee, resolved, schemes);
            if direct
                && let Some(Expr::Name(n)) = c.args.first().and_then(Arg::expr)
                && let Some(b) = resolved.refs.get(n.id)
                && resolved
                    .bindings
                    .get(*b)
                    .is_some_and(|b| matches!(b.kind, BindingKind::Local(_)))
            {
                Argument::Projection(*b)
            } else {
                Argument::Other
            }
        }
        Expr::Lit(_)
        | Expr::Unary(_)
        | Expr::Call(_)
        | Expr::Interp(_)
        | Expr::Unit(_)
        | Expr::Paren(_)
        | Expr::List(_)
        | Expr::Record(_)
        | Expr::Binary(_)
        | Expr::Pipe(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Try(_)
        | Expr::Block(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => Argument::Other,
    }
}

pub(super) enum Instruction {
    Record(NodeId),
    Stop(ScopeInputStop),
    Save,
    Restore,
    Enter(Vec<Option<BindingId>>),
    Leave,
    Bind {
        binding: Option<BindingId>,
        rhs: Option<NodeId>,
        alias: bool,
        call: Option<Vec<Argument>>,
    },
    Ok {
        binding: Option<BindingId>,
        scrutinee: BindingId,
    },
}

#[derive(Default)]
pub(super) struct Program {
    pub code: Vec<Instruction>,
    pub arguments: std::collections::BTreeMap<NodeId, Vec<Argument>>,
}

enum Work<'a> {
    Expr(&'a Expr),
    Block(&'a Block),
    Conditional(&'a IfExpr),
    With(&'a WithExpr, usize),
    Emit(Instruction),
}

struct Lower<'a> {
    resolved: &'a ResolveOutput,
    schemes: &'a BindingMap<Scheme>,
    code: Vec<Instruction>,
    work: Vec<(Work<'a>, u32)>,
}

impl<'a> Lower<'a> {
    fn later(&mut self, work: Work<'a>, depth: u32) {
        self.work.push((work, depth.saturating_add(1)));
    }

    fn binding(&self, node: NodeId) -> Option<BindingId> {
        self.resolved
            .decls
            .get(node)
            .or_else(|| self.resolved.refs.get(node))
            .copied()
    }

    fn binders(&self, pattern: &Pattern) -> Vec<Option<BindingId>> {
        let mut result = Vec::new();
        enum Part<'p> {
            Pattern(&'p Pattern),
            Rest(NodeId),
        }
        let mut stack = vec![Part::Pattern(pattern)];
        while let Some(part) = stack.pop() {
            let p = match part {
                Part::Pattern(p) => p,
                Part::Rest(id) => {
                    result.push(self.binding(id));
                    continue;
                }
            };
            match p {
                Pattern::Var(p) => result.push(self.binding(p.id)),
                Pattern::Ctor(p) => stack.extend(p.args.iter().rev().map(Part::Pattern)),
                Pattern::Record(p) => {
                    let mut fields: Vec<_> = p.fields.iter().collect();
                    fields.sort_by_key(|f| {
                        self.resolved.binding_of_ref(f.id).and_then(|b| {
                            if let BindingKind::Field { index, .. } = b.kind {
                                Some(index)
                            } else {
                                None
                            }
                        })
                    });
                    stack.extend(fields.into_iter().rev().map(|f| Part::Pattern(&f.pattern)));
                }
                Pattern::List(p) => {
                    stack.extend(p.after.iter().rev().map(Part::Pattern));
                    if let Some(r) = &p.rest
                        && r.name.is_some()
                    {
                        stack.push(Part::Rest(r.id));
                    }
                    stack.extend(p.before.iter().rev().map(Part::Pattern));
                }
                Pattern::Wildcard(_)
                | Pattern::Lit(_)
                | Pattern::Unit(_)
                | Pattern::Range(_)
                | Pattern::Error(_) => (),
            }
        }
        result
    }

    fn unknown(&mut self, binding: Option<BindingId>, depth: u32) {
        self.later(
            Work::Emit(Instruction::Bind {
                binding,
                rhs: None,
                alias: false,
                call: None,
            }),
            depth,
        );
    }

    fn scoped(&mut self, work: Work<'a>, depth: u32) {
        self.later(Work::Emit(Instruction::Restore), depth);
        self.later(work, depth);
        self.later(Work::Emit(Instruction::Save), depth);
    }

    fn separate(&mut self, body: &'a Block, bindings: Vec<Option<BindingId>>, depth: u32) {
        self.later(Work::Emit(Instruction::Leave), depth);
        self.later(Work::Block(body), depth);
        self.later(Work::Emit(Instruction::Enter(bindings)), depth);
    }

    fn block(&mut self, block: &'a Block, depth: u32) {
        for (i, stmt) in block.stmts.iter().enumerate().rev() {
            let (node, rhs) = match stmt {
                Stmt::Bind(b) if self.resolved.builder_binds.get(b.id).is_some() => {
                    self.unknown(self.binding(b.pattern.id()), depth);
                    continue;
                }
                Stmt::Bind(b) => {
                    if i.saturating_add(1) < block.stmts.len() {
                        if let Pattern::Var(v) = &b.pattern {
                            self.later(Work::Emit(Instruction::Bind {
                                binding: self.binding(v.id), rhs: Some(b.value.id()),
                                call: if let Expr::Call(c) = &b.value {
                                    let direct = direct_head(&c.callee, self.resolved, self.schemes);
                                    (direct && c.args.iter().all(|a| a.expr().is_some())).then(||
                                        c.args.iter().filter_map(Arg::expr).map(|e| argument(e, self.resolved, self.schemes)).collect())
                                } else { None },
                                alias: matches!(&b.value, Expr::Name(n) if self.resolved.binding_of_ref(n.id)
                                    .is_some_and(|b| matches!(b.kind, BindingKind::Local(_)))),
                            }), depth);
                        } else {
                            for binding in self.binders(&b.pattern).into_iter().rev() {
                                self.unknown(binding, depth);
                            }
                        }
                    }
                    (b.id, &b.value)
                }
                Stmt::Expr(e) => (e.id(), e),
                Stmt::Error(_) => continue,
            };
            self.later(Work::Expr(rhs), depth);
            self.later(Work::Emit(Instruction::Record(node)), depth);
        }
    }

    fn conditional(&mut self, e: &'a IfExpr, depth: u32) {
        match &e.else_branch {
            Some(ElseBranch::Block(b)) => self.scoped(Work::Block(b), depth),
            Some(ElseBranch::If(i)) => self.scoped(Work::Conditional(i), depth),
            None => (),
        }
        self.scoped(Work::Block(&e.then_block), depth);
        self.scoped(Work::Expr(&e.cond), depth);
    }

    fn with(&mut self, e: &'a WithExpr, i: usize, depth: u32) {
        let Some(b) = e.binds.get(i) else {
            return;
        };
        if i != 0 {
            self.code.push(Instruction::Record(b.id));
        }
        if i.saturating_add(1) < e.binds.len() {
            self.later(Work::With(e, i.saturating_add(1)), depth);
        } else {
            self.later(Work::Block(&e.body), depth);
        }
        self.unknown(self.binding(b.id), depth);
        self.scoped(Work::Expr(&b.value), depth);
    }

    fn expression(&mut self, e: &'a Expr, depth: u32) {
        match e {
            Expr::Paren(p) => self.scoped(Work::Expr(&p.inner), depth),
            Expr::Return(r) => self.scoped(Work::Expr(&r.value), depth),
            Expr::Call(c) => {
                if self.resolved.builder_calls.get(c.id).is_some()
                    || c.args.iter().any(|a| a.expr().is_none())
                    || matches!(c.callee.as_ref(), Expr::Name(n) if self.resolved.binding_of_ref(n.id)
                        .is_some_and(|b| matches!(b.kind, BindingKind::Ctor { .. } | BindingKind::Record)))
                {
                    return;
                }
                for a in c.args.iter().rev().filter_map(Arg::expr) {
                    self.scoped(Work::Expr(a), depth);
                }
                self.scoped(Work::Expr(&c.callee), depth);
            }
            Expr::Block(b) => self.scoped(Work::Block(&b.body), depth),
            Expr::If(i) => self.conditional(i, depth),
            Expr::With(w) => {
                self.later(Work::Emit(Instruction::Restore), depth);
                self.later(Work::With(w, 0), depth);
                self.later(Work::Emit(Instruction::Save), depth);
            }
            Expr::Match(m) => {
                let scrutinee = if let Expr::Name(n) = m.scrutinee.as_ref() {
                    self.resolved.refs.get(n.id).copied().filter(|b| {
                        self.resolved
                            .bindings
                            .get(*b)
                            .is_some_and(|b| matches!(b.kind, BindingKind::Local(_)))
                    })
                } else {
                    None
                };
                for arm in m.arms.iter().rev() {
                    self.later(Work::Emit(Instruction::Restore), depth);
                    self.later(Work::Block(&arm.body), depth);
                    if let Some(g) = &arm.guard {
                        self.scoped(Work::Expr(g), depth);
                    }
                    let success = match (scrutinee, arm.patterns.as_slice()) {
                        (Some(scrutinee), [Pattern::Ctor(c)])
                            if self.resolved.refs.get(c.id).copied()
                                == self.resolved.stdlib("Benitoite.Result.Ok") =>
                        {
                            match c.args.as_slice() {
                                [Pattern::Var(v)] => Some((scrutinee, self.binding(v.id))),
                                _ => None,
                            }
                        }
                        _ => None,
                    };
                    if let Some((scrutinee, binding)) = success {
                        self.later(Work::Emit(Instruction::Ok { binding, scrutinee }), depth);
                    } else if let Some(p) = arm.patterns.first() {
                        for b in self.binders(p).into_iter().rev() {
                            self.unknown(b, depth);
                        }
                    }
                    self.later(Work::Emit(Instruction::Save), depth);
                }
                self.scoped(Work::Expr(&m.scrutinee), depth);
            }
            Expr::Lambda(l) => self.separate(
                &l.body,
                l.params.iter().map(|p| self.binding(p.id)).collect(),
                depth,
            ),
            Expr::Lazy(l) => self.separate(&l.body, Vec::new(), depth),
            Expr::Handle(h) => {
                for c in h.clauses.iter().rev() {
                    let op = self.resolved.refs.get(c.op.id).copied();
                    let dictionaries = op
                        .and_then(|b| self.schemes.get(b))
                        .map_or(0, |s| s.class_constraints.len());
                    let bindings = std::iter::repeat_n(None, dictionaries)
                        .chain(c.params.iter().map(|p| self.binding(p.id)))
                        .chain(std::iter::once(None))
                        .collect();
                    // Fail も失敗値と再開しない継続の二位置を持つ。
                    self.separate(&c.body, bindings, depth);
                }
                self.separate(&h.body, Vec::new(), depth);
            }
            // constE・try・pipe・構築子・record・list・演算・補間・resume の内側は辿らない。
            Expr::Lit(_)
            | Expr::Interp(_)
            | Expr::Name(_)
            | Expr::Unit(_)
            | Expr::List(_)
            | Expr::Record(_)
            | Expr::Binary(_)
            | Expr::Unary(_)
            | Expr::Pipe(_)
            | Expr::Try(_)
            | Expr::Resume(_)
            | Expr::Error(_) => (),
        }
    }
}

pub(super) fn collect(
    source: crate::typeck::source_input::BodySource<'_>,
    resolved: &ResolveOutput,
    schemes: &BindingMap<Scheme>,
) -> Vec<Instruction> {
    use crate::typeck::source_input::BodySource;
    let mut lower = Lower {
        resolved,
        schemes,
        code: Vec::new(),
        work: Vec::new(),
    };
    match source {
        BodySource::Constant(c) => {
            lower.code.push(Instruction::Record(c.id));
            lower.work.push((Work::Expr(&c.value), 0));
        }
        BodySource::Function { body, .. } => lower.work.push((Work::Block(body), 0)),
    }
    while let Some((work, depth)) = lower.work.pop() {
        // 収集が同じ深さで停止した入力は、解析の入口でも停止する。
        if depth > 4096 {
            lower.code.push(Instruction::Stop(ScopeInputStop::Depth));
            break;
        }
        match work {
            Work::Expr(e) => lower.expression(e, depth),
            Work::Block(b) => lower.block(b, depth),
            Work::Conditional(i) => lower.conditional(i, depth),
            Work::With(w, i) => lower.with(w, i, depth),
            Work::Emit(i) => lower.code.push(i),
        }
    }
    lower.code
}
