//! 局所の束縛、書き分けとパターンの選択肢（設計書 02-04「名前の引き方」、ADR 0255）。

use std::collections::BTreeMap;

use crate::base::{BindingId, NodeId};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::*;

use super::collect::Resolver;
use super::lookup::{Ctx, Position};
use super::{BindingKind, LocalKind, text};

impl Resolver<'_> {
    pub(super) fn add_local(
        &mut self,
        ctx: &mut Ctx,
        node: NodeId,
        name: &Name,
        kind: LocalKind,
    ) -> BindingId {
        let id = self.node_binding(
            ctx.module,
            node,
            name,
            BindingKind::Local(kind),
            false,
            None,
        );
        if let Some(scope) = ctx.scopes.last_mut() {
            scope.insert(name.text.clone(), id);
        }
        id
    }

    pub(super) fn implicit_shadow(&mut self, ctx: &Ctx, name: &Name, kind: LocalKind) {
        if let Some(visible) = ctx.local(&name.text) {
            let binder = match kind {
                LocalKind::LambdaParam => text::LAMBDA_PARAM,
                LocalKind::PatternVar => text::PATTERN_VAR,
                LocalKind::WithVar => text::WITH_VAR,
                LocalKind::ClauseParam => text::CLAUSE_PARAM,
                LocalKind::Param | LocalKind::BindVar => return,
            };
            let mut d = DiagBuilder::new(DiagCode::E0338)
                .arg("name", name.text.clone())
                .arg("binder", binder)
                .primary(name.span)
                .help("rename");
            if let Some(span) = self.out.bindings.get(visible).and_then(|b| b.span) {
                d = d.secondary(span, "hidden");
            }
            self.out.diagnostics.push(d.build());
        }
    }

    pub(super) fn parameters(&mut self, ctx: &mut Ctx, params: &[Param], kind: LocalKind) {
        let mut seen = BTreeMap::new();
        for param in params {
            if let Some(first) = seen.get(&param.name.text).copied() {
                self.duplicate(DiagCode::E0310, &param.name, first, "");
            } else {
                self.implicit_shadow(ctx, &param.name, kind);
            }
            let id = self.add_local(ctx, param.id, &param.name, kind);
            seen.entry(param.name.text.clone()).or_insert(id);
        }
    }

    pub(super) fn bind_statement(&mut self, ctx: &mut Ctx, stmt: &BindStmt) {
        self.expr(ctx, &stmt.value);
        if let Some(ty) = &stmt.ty {
            self.ty(ctx, ty);
        }
        let vars = self.pattern(ctx, &stmt.pattern);
        let visible: Vec<_> = vars
            .iter()
            .filter_map(|(_, n)| ctx.local(&n.text).map(|id| (*n, id)))
            .collect();
        let code = if vars.is_empty() && stmt.mode == BindMode::Shadow {
            Some(DiagCode::E0337)
        } else if !visible.is_empty() && visible.len() != vars.len() {
            Some(DiagCode::E0336)
        } else if !vars.is_empty() && visible.len() == vars.len() && stmt.mode == BindMode::Bind {
            Some(DiagCode::E0334)
        } else if !vars.is_empty() && visible.is_empty() && stmt.mode == BindMode::Shadow {
            Some(DiagCode::E0335)
        } else {
            None
        };
        if let Some(code) = code {
            let mut d = DiagBuilder::new(code)
                .arg(
                    "name",
                    vars.first().map_or(String::new(), |(_, n)| n.text.clone()),
                )
                .primary(stmt.keyword_span);
            let mut labels = Vec::new();
            for (name, id) in &visible {
                if let Some(span) = self.out.bindings.get(*id).and_then(|b| b.span) {
                    labels.extend(
                        DiagBuilder::new(code)
                            .arg("name", name.text.clone())
                            .secondary(span, "visible")
                            .build()
                            .secondary,
                    );
                }
            }
            d = if code == DiagCode::E0334 {
                d.help_edits(
                    "shadow",
                    vec![Edit {
                        span: stmt.keyword_span,
                        replacement: "shadow".into(),
                    }],
                )
            } else if matches!(code, DiagCode::E0335 | DiagCode::E0337) {
                d.help_edits(
                    "bind",
                    vec![Edit {
                        span: stmt.keyword_span,
                        replacement: "bind".into(),
                    }],
                )
            } else {
                d.help("split")
            };
            let mut diagnostic = d.build();
            diagnostic.secondary = labels;
            self.out.diagnostics.push(diagnostic);
        }
        for (node, name) in vars {
            self.add_local(ctx, node, name, LocalKind::BindVar);
        }
    }

    // 各選択肢を独立して走査し、重複の検査を選択肢の内部に限る（ADR 0121）。
    pub(super) fn pattern<'p>(
        &mut self,
        ctx: &mut Ctx,
        pattern: &'p Pattern,
    ) -> Vec<(NodeId, &'p Name)> {
        let mut vars = Vec::new();
        self.pattern_inner(ctx, pattern, &mut vars);
        let mut unique: BTreeMap<&str, (NodeId, &Name)> = BTreeMap::new();
        let mut result = Vec::new();
        for (node, name) in vars {
            if let Some((_, first)) = unique.get(name.text.as_str()) {
                self.out.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0311)
                        .arg("name", name.text.clone())
                        .primary(name.span)
                        .secondary(first.span, "first")
                        .build(),
                );
            } else {
                unique.insert(&name.text, (node, name));
                result.push((node, name));
            }
        }
        result
    }

    fn pattern_inner<'p>(
        &mut self,
        ctx: &mut Ctx,
        pattern: &'p Pattern,
        vars: &mut Vec<(NodeId, &'p Name)>,
    ) {
        match pattern {
            Pattern::Var(p) => vars.push((p.id, &p.name)),
            Pattern::Ctor(p) => {
                self.name(ctx, p.id, &p.path, Position::Ctor);
                for arg in &p.args {
                    self.pattern_inner(ctx, arg, vars);
                }
            }
            Pattern::Record(p) => {
                let record = self.name(ctx, p.id, &p.path, Position::Record);
                for field in &p.fields {
                    if let Some(record) = record
                        && let Some(id) = self
                            .members
                            .get(&record)
                            .and_then(|m| m.get(&field.name.text))
                            .copied()
                    {
                        self.record_ref(ctx, field.id, id, field.name.span);
                    }
                    self.pattern_inner(ctx, &field.pattern, vars);
                }
            }
            Pattern::List(p) => {
                for p in &p.before {
                    self.pattern_inner(ctx, p, vars);
                }
                if let Some(rest) = &p.rest
                    && let Some(name) = &rest.name
                {
                    vars.push((rest.id, name));
                }
                for p in &p.after {
                    self.pattern_inner(ctx, p, vars);
                }
            }
            Pattern::Wildcard(_)
            | Pattern::Lit(_)
            | Pattern::Unit(_)
            | Pattern::Range(_)
            | Pattern::Error(_) => {}
        }
    }

    pub(super) fn arm(&mut self, ctx: &mut Ctx, arm: &MatchArm) {
        ctx.scopes.push(BTreeMap::new());
        let mut alternatives = Vec::new();
        for pattern in &arm.patterns {
            alternatives.push(self.pattern(ctx, pattern));
        }
        let first = alternatives.first().cloned().unwrap_or_default();
        let mut bindings = BTreeMap::new();
        // 定数の可視性は分岐の変数を段に加える前に判定する（01-05「パターン」）。
        for (node, name) in &first {
            self.implicit_shadow(ctx, name, LocalKind::PatternVar);
            let visible = ctx.local(&name.text).or_else(|| {
                self.top
                    .get(&ctx.module)
                    .and_then(|m| m.get(&name.text))
                    .copied()
            });
            if let Some(constant) = visible.filter(|id| {
                self.out
                    .bindings
                    .get(*id)
                    .is_some_and(|b| b.kind == BindingKind::Const)
            }) {
                let mut d = DiagBuilder::new(DiagCode::E0603)
                    .arg("name", name.text.clone())
                    .primary(name.span)
                    .help("guard");
                if let Some(span) = self.out.bindings.get(constant).and_then(|b| b.span) {
                    d = d.secondary(span, "constant");
                }
                if arm.patterns.len() == 1
                    && arm.guard.is_none()
                    && ctx.local("n").is_none()
                    && !self
                        .top
                        .get(&ctx.module)
                        .is_some_and(|m| m.contains_key("n"))
                    && let Some(Pattern::Var(pattern)) = arm.patterns.first()
                {
                    d = DiagBuilder::new(DiagCode::E0603)
                        .arg("name", name.text.clone())
                        .primary(name.span)
                        .help_edits(
                            "guard",
                            vec![
                                Edit {
                                    span: name.span,
                                    replacement: "n".into(),
                                },
                                Edit {
                                    span: crate::base::Span {
                                        start: pattern.span.end,
                                        ..pattern.span
                                    },
                                    replacement: format!(" if n = {}", name.text),
                                },
                            ],
                        );
                    if let Some(span) = self.out.bindings.get(constant).and_then(|b| b.span) {
                        d = d.secondary(span, "constant");
                    }
                }
                self.out.diagnostics.push(d.build());
            }
            let id = self.node_binding(
                ctx.module,
                *node,
                name,
                BindingKind::Local(LocalKind::PatternVar),
                false,
                None,
            );
            bindings.insert(name.text.clone(), id);
        }
        for (index, vars) in alternatives.iter().enumerate().skip(1) {
            let names: BTreeMap<&str, &Name> =
                vars.iter().map(|(_, n)| (n.text.as_str(), *n)).collect();
            let missing: Vec<_> = first
                .iter()
                .filter(|(_, n)| !names.contains_key(n.text.as_str()))
                .map(|(_, n)| *n)
                .collect();
            let extra: Vec<_> = vars
                .iter()
                .filter(|(_, n)| !bindings.contains_key(&n.text))
                .map(|(_, n)| *n)
                .collect();
            if !missing.is_empty() || !extra.is_empty() {
                let span = arm.patterns.get(index).map_or(arm.span, Pattern::span);
                let d = DiagBuilder::new(DiagCode::E0604)
                    .arg(
                        "missing",
                        missing
                            .iter()
                            .map(|n| n.text.as_str())
                            .collect::<Vec<_>>()
                            .join(", "),
                    )
                    .arg(
                        "extra",
                        extra
                            .iter()
                            .map(|n| n.text.as_str())
                            .collect::<Vec<_>>()
                            .join(", "),
                    )
                    .primary(span);
                let key = if missing.is_empty() {
                    "extra_set"
                } else if extra.is_empty() {
                    "missing_set"
                } else {
                    "sets"
                };
                let mut diagnostic = d.note(key).build();
                for (names, key) in [(missing, "first"), (extra, "extra")] {
                    for name in names {
                        diagnostic.secondary.extend(
                            DiagBuilder::new(DiagCode::E0604)
                                .arg("name", name.text.clone())
                                .secondary(name.span, key)
                                .build()
                                .secondary,
                        );
                    }
                }
                self.out.diagnostics.push(diagnostic);
            }
            for (node, name) in vars {
                if let Some(id) = bindings.get(&name.text) {
                    self.out.refs.insert(*node, *id);
                }
            }
        }
        if let Some(scope) = ctx.scopes.last_mut() {
            scope.extend(bindings);
        }
        if let Some(guard) = &arm.guard {
            self.expr(ctx, guard);
        }
        self.block(ctx, &arm.body);
        ctx.scopes.pop();
    }
}
