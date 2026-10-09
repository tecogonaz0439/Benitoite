//! 名前の検索順と参照の記録（設計書 01-03「修飾された名前の解決」、02-04「名前の引き方」）。

use std::collections::BTreeMap;

use crate::base::{BindingId, ModuleId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::modules::ModuleKind;
use crate::syntax::ast::{Name, UsesList};

use super::collect::Resolver;
use super::{BindingKind, suggest, text};

#[derive(Clone)]
pub(super) struct Ctx {
    pub(super) module: ModuleId,
    pub(super) owner: NodeId,
    pub(super) types: BTreeMap<String, BindingId>,
    pub(super) scopes: Vec<BTreeMap<String, BindingId>>,
    pub(super) used: Vec<(BindingId, Span)>,
}

impl Ctx {
    pub(super) fn new(module: ModuleId, owner: NodeId) -> Self {
        Self {
            module,
            owner,
            types: BTreeMap::new(),
            scopes: Vec::new(),
            used: Vec::new(),
        }
    }
    pub(super) fn local(&self, name: &str) -> Option<BindingId> {
        self.scopes.iter().rev().find_map(|m| m.get(name).copied())
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum Position {
    Value,
    Type,
    Effect,
    Ctor,
    Record,
    Class,
}

impl Position {
    fn label(self) -> &'static str {
        match self {
            Self::Value => text::VALUE,
            Self::Type => text::TYPE,
            Self::Effect => text::EFFECT,
            Self::Ctor => text::CONSTRUCTOR,
            Self::Record => text::RECORD,
            Self::Class => text::TRAIT,
        }
    }
    fn accepts(self, kind: BindingKind) -> bool {
        match self {
            Self::Value => matches!(
                kind,
                BindingKind::Fn
                    | BindingKind::BuiltinFn(_)
                    | BindingKind::ImplFn { .. }
                    | BindingKind::Const
                    | BindingKind::Field { .. }
                    | BindingKind::Ctor { .. }
                    | BindingKind::Method { .. }
                    | BindingKind::Op { .. }
                    | BindingKind::Local(_)
            ),
            Self::Type => matches!(
                kind,
                BindingKind::Data
                    | BindingKind::BuiltinType(_)
                    | BindingKind::Alias
                    | BindingKind::Record
                    | BindingKind::TypeParam { .. }
            ),
            Self::Effect => matches!(
                kind,
                BindingKind::Effect | BindingKind::BuiltinEffect(_) | BindingKind::EffectVar { .. }
            ),
            Self::Ctor => matches!(kind, BindingKind::Ctor { .. }),
            Self::Record => kind == BindingKind::Record,
            Self::Class => kind == BindingKind::Trait,
        }
    }
}

pub(super) fn kind_label(kind: BindingKind) -> &'static str {
    match kind {
        BindingKind::Fn
        | BindingKind::BuiltinFn(_)
        | BindingKind::ImplFn { .. }
        | BindingKind::Const
        | BindingKind::Field { .. }
        | BindingKind::Method { .. }
        | BindingKind::Op { .. }
        | BindingKind::Local(_) => text::VALUE,
        BindingKind::Data | BindingKind::BuiltinType(_) | BindingKind::Alias => text::TYPE,
        BindingKind::Record => text::RECORD,
        BindingKind::Ctor { .. } => text::CONSTRUCTOR,
        BindingKind::Trait => text::TRAIT,
        BindingKind::Effect | BindingKind::BuiltinEffect(_) => text::EFFECT,
        BindingKind::Module(_) => text::MODULE,
        BindingKind::NamespaceRoot => text::NAMESPACE,
        BindingKind::TypeParam { .. } => text::TYPE_PARAMETER,
        BindingKind::EffectVar { .. } => text::EFFECT_VARIABLE,
    }
}

impl Resolver<'_> {
    pub(super) fn upper(&self, ctx: &Ctx, name: &str, parameters: bool) -> Option<BindingId> {
        if name == "Benitoite" {
            return self.prelude.get(name).copied();
        }
        if parameters && let Some(id) = ctx.types.get(name) {
            return Some(*id);
        }
        self.top
            .get(&ctx.module)
            .and_then(|m| m.get(name))
            .copied()
            .or_else(|| {
                self.imported
                    .get(&ctx.module)
                    .and_then(|m| m.get(name))
                    .copied()
                    .flatten()
            })
            .or_else(|| self.prelude.get(name).copied())
    }

    // 標準ライブラリの同名の型とモジュールは、最後の段を読む位置によって選ぶ（02-04「標準ライブラリのソースの持ち方」）。
    fn type_in_module(&self, id: BindingId) -> Option<BindingId> {
        let b = self.out.bindings.get(id)?;
        let BindingKind::Module(module) = b.kind else {
            return None;
        };
        let info = self.modules.get(module)?;
        if !matches!(info.kind, ModuleKind::Prelude | ModuleKind::Stdlib) {
            return None;
        }
        self.top.get(&module)?.get(info.name.0.last()?).copied()
    }

    fn as_module(&self, id: BindingId) -> Option<ModuleId> {
        let b = self.out.bindings.get(id)?;
        if let BindingKind::Module(module) = b.kind {
            return Some(module);
        }
        let info = self.modules.get(b.module)?;
        if matches!(info.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
            && info.name.0.last() == Some(&b.name)
            && matches!(
                b.kind,
                BindingKind::Data
                    | BindingKind::BuiltinType(_)
                    | BindingKind::Record
                    | BindingKind::Trait
            )
        {
            Some(b.module)
        } else {
            None
        }
    }

    fn children(&self, ctx: &Ctx, id: BindingId, public_only: bool) -> BTreeMap<String, BindingId> {
        let Some(b) = self.out.bindings.get(id) else {
            return BTreeMap::new();
        };
        if b.kind == BindingKind::NamespaceRoot {
            return self
                .prelude
                .iter()
                .filter(|(name, _)| name.as_str() != "Benitoite")
                .map(|(n, id)| (n.clone(), *id))
                .collect();
        }
        if let Some(module) = self.as_module(id) {
            let table = if !public_only && module == ctx.module {
                self.top.get(&module)
            } else {
                self.out.exports.get(&module)
            };
            let mut names = table.cloned().unwrap_or_default();
            if let Some(info) = self.modules.get(module)
                && matches!(info.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
                && let Some(ty) = info
                    .name
                    .0
                    .last()
                    .and_then(|name| self.top.get(&module).and_then(|t| t.get(name)))
                && let Some(children) = self.members.get(ty)
            {
                for (name, child) in children {
                    if self
                        .out
                        .bindings
                        .get(*child)
                        .is_some_and(|b| b.public || (!public_only && module == ctx.module))
                    {
                        names.entry(name.clone()).or_insert(*child);
                    }
                }
            }
            return names;
        }
        self.members.get(&id).cloned().unwrap_or_default()
    }

    pub(super) fn record_ref(&mut self, ctx: &mut Ctx, node: NodeId, id: BindingId, span: Span) {
        self.out.refs.insert(node, id);
        ctx.used.push((id, span));
        let Some(binding) = self.out.bindings.get(id) else {
            return;
        };
        if let Some(message) = &binding.deprecated
            && self.parent.get(&id).copied() != Some(ctx.owner)
        {
            let mut d = DiagBuilder::new(DiagCode::W0301)
                .arg("name", binding.name.clone())
                .arg("message", message.clone())
                .primary(span)
                .note("message");
            if let Some(span) = binding.span {
                d = d.secondary(span, "declared");
            }
            self.out.diagnostics.push(d.build());
        }
    }

    pub(super) fn name(
        &mut self,
        ctx: &mut Ctx,
        node: NodeId,
        path: &[Name],
        position: Position,
    ) -> Option<BindingId> {
        let id = self.raw_name(ctx, node, path, position)?;
        let binding = self.out.bindings.get(id)?;
        if !position.accepts(binding.kind) {
            let code = if position == Position::Type
                && matches!(
                    binding.kind,
                    BindingKind::Effect
                        | BindingKind::BuiltinEffect(_)
                        | BindingKind::EffectVar { .. }
                ) {
                DiagCode::E0314
            } else {
                DiagCode::E0304
            };
            let span = path.first()?.span.to(path.last()?.span);
            let mut d = DiagBuilder::new(code)
                .arg("name", dotted(path))
                .arg("found_kind", kind_label(binding.kind))
                .arg("expected_kind", position.label())
                .primary(span);
            if code == DiagCode::E0314 {
                d = d.note("uses_only");
            }
            self.out.diagnostics.push(d.build());
            return None;
        }
        self.record_ref(ctx, node, id, path.first()?.span.to(path.last()?.span));
        Some(id)
    }

    fn raw_name(
        &mut self,
        ctx: &Ctx,
        node: NodeId,
        path: &[Name],
        position: Position,
    ) -> Option<BindingId> {
        let first = path.first()?;
        let single = path.len() == 1;
        let lower = first
            .text
            .starts_with(|c: char| c.is_ascii_lowercase() || c == '_');
        if !lower
            && self
                .imported
                .get(&ctx.module)
                .and_then(|m| m.get(&first.text))
                .is_some_and(Option::is_none)
            && !self
                .top
                .get(&ctx.module)
                .is_some_and(|m| m.contains_key(&first.text))
        {
            return None;
        }
        let parameters = matches!(
            position,
            Position::Type | Position::Effect | Position::Class
        );
        let found = if single && lower {
            ctx.local(&first.text).or_else(|| {
                self.top
                    .get(&ctx.module)
                    .and_then(|m| m.get(&first.text))
                    .copied()
            })
        } else {
            self.upper(ctx, &first.text, parameters)
        };
        let Some(mut id) = found else {
            if single
                && matches!(position, Position::Value | Position::Ctor)
                && !lower
                && self.unqualified_ctor(ctx, first)
            {
                return None;
            }
            if !single && self.missing_import(ctx, first) {
                return None;
            }
            let code = if single {
                DiagCode::E0301
            } else {
                DiagCode::E0302
            };
            let pool = self.visible_names(ctx, position, !single);
            let d = DiagBuilder::new(code)
                .arg("name", first.text.clone())
                .primary(first.span);
            let d = self.similar(d, &first.text, first.span, pool);
            self.out.diagnostics.push(d.build());
            return None;
        };
        if let Some(hidden) = self.prelude.get(&first.text).copied()
            && hidden != id
            && self
                .modules
                .get(ctx.module)
                .is_some_and(|m| matches!(m.kind, ModuleKind::Entry | ModuleKind::User))
        {
            self.out.prelude_shadowed.insert(node, hidden);
        }
        for (index, next) in path.iter().enumerate().skip(1) {
            let binding = self.out.bindings.get(id)?.clone();
            let module = self.as_module(id);
            if module.is_none()
                && !matches!(
                    binding.kind,
                    BindingKind::NamespaceRoot
                        | BindingKind::Data
                        | BindingKind::Record
                        | BindingKind::Trait
                )
            {
                self.out.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0304)
                        .arg("name", binding.name)
                        .arg("found_kind", kind_label(binding.kind))
                        .arg("expected_kind", text::MODULE)
                        .primary(path.first()?.span.to(next.span))
                        .build(),
                );
                return None;
            }
            let children = self.children(ctx, id, false);
            if let Some(child) = children.get(&next.text) {
                id = *child;
                continue;
            }
            if let Some(module) = module
                && module != ctx.module
                && let Some(private) = self
                    .top
                    .get(&module)
                    .and_then(|m| m.get(&next.text))
                    .copied()
            {
                let mut d = DiagBuilder::new(DiagCode::E0330)
                    .arg("name", next.text.clone())
                    .arg("module", self.modules.get(module)?.name.dotted())
                    .primary(next.span);
                if let Some(span) = self.out.bindings.get(private).and_then(|b| b.span) {
                    d = d.secondary(span, "declared");
                }
                // 標準ライブラリの名前を `public` にする修正案は、利用者には行えないので出さない。
                let user_module = self
                    .modules
                    .get(module)
                    .is_some_and(|m| matches!(m.kind, ModuleKind::Entry | ModuleKind::User));
                if user_module {
                    d = match self.insertion.get(&private) {
                        Some(span) => d.help_edits(
                            "make_public",
                            vec![Edit {
                                span: *span,
                                replacement: "public ".into(),
                            }],
                        ),
                        None => d.help("make_public"),
                    };
                }
                self.out.diagnostics.push(d.build());
                return None;
            }
            let module_name = module
                .and_then(|m| self.modules.get(m))
                .map_or(binding.name.clone(), |m| m.name.dotted());
            let mut d = DiagBuilder::new(DiagCode::E0303)
                .arg("module", module_name)
                .arg("name", next.text.clone())
                .primary(next.span);
            if module.is_some_and(|m| {
                self.imported
                    .get(&m)
                    .is_some_and(|names| names.contains_key(&next.text))
            }) {
                d = d.note("not_reexported");
            }
            if module.is_some_and(|m| {
                self.modules
                    .get(m)
                    .is_some_and(|m| m.name.dotted() == "Benitoite.String")
            }) {
                let key = match next.text.as_str() {
                    "length" => Some("length"),
                    "slice" | "substring" => Some("slice"),
                    "indexOf" => Some("index_of"),
                    _ => None,
                };
                if let Some(key) = key {
                    d = d.help(key);
                }
            }
            if matches!(next.text.as_str(), "unwrap" | "expect")
                && module.is_some_and(|m| {
                    self.modules.get(m).is_some_and(|m| {
                        matches!(
                            m.name.dotted().as_str(),
                            "Benitoite.Option" | "Benitoite.Result"
                        )
                    })
                })
            {
                d = d.help("unwrap");
            }
            let pool = children
                .into_iter()
                .filter(|(_, bid)| {
                    if index.saturating_add(1) != path.len() {
                        return self.as_module(*bid).is_some()
                            || self.out.bindings.get(*bid).is_some_and(|b| {
                                matches!(
                                    b.kind,
                                    BindingKind::Data
                                        | BindingKind::Record
                                        | BindingKind::Trait
                                        | BindingKind::NamespaceRoot
                                )
                            });
                    }
                    let id = self.final_name(*bid, position);
                    self.out
                        .bindings
                        .get(id)
                        .is_some_and(|b| position.accepts(b.kind))
                })
                .map(|(name, _)| name)
                .collect();
            let d = self.similar(d, &next.text, next.span, pool);
            self.out.diagnostics.push(d.build());
            return None;
        }
        Some(self.final_name(id, position))
    }

    // 最後の段は位置に合わせて、標準のモジュールの同名の型と省略できる構成子を選ぶ。
    // 候補の検査も同じ変換を使い、実際には解決できない置き換えを付けない（01-03、ADR 0148）。
    fn final_name(&self, mut id: BindingId, position: Position) -> BindingId {
        if matches!(
            position,
            Position::Type | Position::Record | Position::Class | Position::Ctor | Position::Value
        ) && let Some(ty) = self.type_in_module(id)
        {
            id = ty;
        }
        if matches!(position, Position::Ctor | Position::Value)
            && self
                .out
                .bindings
                .get(id)
                .is_some_and(|b| b.kind == BindingKind::Data)
            && let Some(b) = self.out.bindings.get(id)
            && let Some(children) = self.members.get(&id)
            && children.len() == 1
            && let Some(ctor) = children.get(&b.name)
        {
            id = *ctor;
        }
        id
    }

    fn visible_names(&self, ctx: &Ctx, position: Position, qualified: bool) -> Vec<String> {
        let mut table = self.prelude.clone();
        if let Some(imports) = self.imported.get(&ctx.module) {
            table.extend(
                imports
                    .iter()
                    .filter_map(|(name, id)| id.map(|id| (name.clone(), id))),
            );
        }
        if let Some(top) = self.top.get(&ctx.module) {
            table.extend(top.clone());
        }
        if matches!(
            position,
            Position::Type | Position::Effect | Position::Class
        ) {
            table.extend(ctx.types.clone());
        }
        if !qualified && position == Position::Value {
            for scope in &ctx.scopes {
                table.extend(scope.clone());
            }
        }
        table
            .into_iter()
            .filter(|(_, id)| {
                let id = if !qualified {
                    self.final_name(*id, position)
                } else {
                    *id
                };
                self.out.bindings.get(id).is_some_and(|b| {
                    if qualified {
                        self.as_module(id).is_some()
                            || matches!(
                                b.kind,
                                BindingKind::Data
                                    | BindingKind::Record
                                    | BindingKind::Trait
                                    | BindingKind::NamespaceRoot
                            )
                    } else {
                        position.accepts(b.kind)
                    }
                })
            })
            .map(|(name, _)| name)
            .collect()
    }

    pub(super) fn similar(
        &self,
        d: DiagBuilder,
        name: &str,
        span: Span,
        pool: Vec<String>,
    ) -> DiagBuilder {
        let candidates = suggest::candidates(name, pool.iter().map(String::as_str));
        if candidates.is_empty() {
            return d;
        }
        let listed = candidates
            .iter()
            .map(|n| format!("`{n}`"))
            .collect::<Vec<_>>()
            .join(", ");
        let d = d.arg("candidates", listed);
        if candidates.len() == 1 {
            d.help_edits(
                "similar",
                vec![Edit {
                    span,
                    replacement: candidates.first().cloned().unwrap_or_default(),
                }],
            )
        } else {
            d.help("similar")
        }
    }

    fn unqualified_ctor(&mut self, ctx: &Ctx, name: &Name) -> bool {
        let mut routes = BTreeMap::new();
        let mut roots = self.prelude.clone();
        if let Some(imports) = self.imported.get(&ctx.module) {
            roots.extend(
                imports
                    .iter()
                    .filter_map(|(n, id)| id.map(|id| (n.clone(), id))),
            );
        }
        if let Some(top) = self.top.get(&ctx.module) {
            roots.extend(
                top.iter()
                    .filter(|(n, _)| n.starts_with(|c: char| c.is_ascii_uppercase()))
                    .map(|(n, id)| (n.clone(), *id)),
            );
        }
        for (prefix, id) in roots {
            let children = self.children(ctx, id, false);
            for (child_name, child) in children {
                if self
                    .out
                    .bindings
                    .get(child)
                    .is_some_and(|b| matches!(b.kind, BindingKind::Ctor { .. }))
                {
                    routes.insert(format!("{prefix}.{child_name}"), (child_name, child));
                } else if self
                    .out
                    .bindings
                    .get(child)
                    .is_some_and(|b| b.kind == BindingKind::Data)
                {
                    for (ctor_name, ctor) in self.children(ctx, child, false) {
                        routes.insert(
                            format!("{prefix}.{child_name}.{ctor_name}"),
                            (ctor_name, ctor),
                        );
                    }
                }
            }
        }
        let matches: Vec<String> = routes
            .into_iter()
            .filter(|(_, (n, _))| *n == name.text || (name.text == "Err" && *n == "Error"))
            .map(|(route, _)| route)
            .collect();
        if matches.is_empty() {
            return false;
        }
        // 同じ構成子への冗長な経路は、短い修飾を優先する。
        let canonical: Vec<&String> = matches
            .iter()
            .filter(|route| {
                !matches
                    .iter()
                    .any(|short| route.len() > short.len() && route.ends_with(&format!(".{short}")))
            })
            .collect();
        let mut d = DiagBuilder::new(DiagCode::E0331)
            .arg("name", name.text.clone())
            .arg(
                "suggestion",
                canonical
                    .iter()
                    .map(|s| s.as_str())
                    .collect::<Vec<_>>()
                    .join(", "),
            )
            .primary(name.span);
        if canonical.len() == 1 {
            if let Some(route) = canonical.first() {
                d = d.arg("suggestion", (*route).clone()).help_edits(
                    "qualify",
                    vec![Edit {
                        span: name.span,
                        replacement: (*route).clone(),
                    }],
                );
            }
        } else {
            d = d.help("qualify");
        }
        self.out.diagnostics.push(d.build());
        true
    }

    fn missing_import(&mut self, ctx: &Ctx, name: &Name) -> bool {
        let candidates: Vec<_> = crate::prelude::STDLIB
            .iter()
            .filter(|m| !m.prelude && m.path.last().copied() == Some(name.text.as_str()))
            .collect();
        if candidates.len() != 1 {
            return false;
        }
        let Some(module) = candidates.first() else {
            return false;
        };
        let full = if module.unofficial {
            format!("Benitoite.Unofficial.{}", module.path.join("."))
        } else {
            format!("Benitoite.{}", module.path.join("."))
        };
        let mut d = DiagBuilder::new(DiagCode::E0332)
            .arg("module", name.text.clone())
            .arg("full", full.clone())
            .primary(name.span);
        let start = self
            .ast(ctx.module)
            .and_then(|a| {
                a.imports.first().map(|i| i.span).or_else(|| {
                    a.decls
                        .first()
                        .map(|d| d.doc.as_ref().map_or(d.span, |doc| doc.span))
                })
            })
            .and_then(|s| self.line_start(s));
        if let Some(span) = start {
            d = d.help_edits(
                "import",
                vec![Edit {
                    span,
                    replacement: format!("import {full}\n"),
                }],
            );
        } else {
            d = d.help("import");
        }
        self.out.diagnostics.push(d.build());
        true
    }

    pub(super) fn uses(&mut self, ctx: &mut Ctx, uses: &UsesList, fn_span: Option<Span>) {
        let mut prefix_valid = true;
        for (index, effect) in uses.effects.iter().enumerate() {
            let Some(id) = self.raw_name(ctx, effect.id, &effect.path, Position::Effect) else {
                prefix_valid = false;
                continue;
            };
            let Some(binding) = self.out.bindings.get(id) else {
                continue;
            };
            if Position::Effect.accepts(binding.kind) {
                self.record_ref(ctx, effect.id, id, effect.span);
                continue;
            }
            let io = matches!(binding.kind, BindingKind::Module(module) if self.modules.get(module).is_some_and(|m| m.name.dotted() == "Benitoite.IO"));
            let code = if io {
                DiagCode::E0333
            } else if index == 0 {
                DiagCode::E0315
            } else {
                DiagCode::E0316
            };
            let mut d = DiagBuilder::new(code)
                .arg("name", dotted(&effect.path))
                .primary(effect.span);
            if io {
                d = d.help_edits(
                    "all",
                    vec![Edit {
                        span: effect.span,
                        replacement: format!("{}.All", dotted(&effect.path)),
                    }],
                );
            } else if index == 0 {
                d = d.help("qualify");
            } else if prefix_valid
                && let (Some(fn_span), Some(previous)) =
                    (fn_span, uses.effects.get(index.saturating_sub(1)))
            {
                // 次の型として取り込まれた名前の直前で閉じると、コンマが外側の型の並びへ戻る（ADR 0047）。
                d = d.help_edits(
                    "paren",
                    vec![
                        Edit {
                            span: Span {
                                end: fn_span.start,
                                ..fn_span
                            },
                            replacement: "(".into(),
                        },
                        Edit {
                            span: Span {
                                start: previous.span.end,
                                ..previous.span
                            },
                            replacement: ")".into(),
                        },
                    ],
                );
            } else {
                d = d.help("paren");
            }
            prefix_valid = false;
            self.out.diagnostics.push(d.build());
        }
    }
}

pub(super) fn dotted(path: &[Name]) -> String {
    path.iter()
        .map(|n| n.text.as_str())
        .collect::<Vec<_>>()
        .join(".")
}
