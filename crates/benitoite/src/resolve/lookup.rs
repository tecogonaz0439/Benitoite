//! 名前の検索順と参照の記録（設計書 01-03「修飾された名前の解決」、02-04「名前の引き方」）。

use std::collections::BTreeMap;

use crate::base::{BindingId, ModuleId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::modules::ModuleKind;
use crate::syntax::ast::{Name, UsesList};

use super::collect::Resolver;
use super::{BindingKind, renames, suggest, text};

#[derive(Clone)]
pub(super) struct Ctx {
    pub(super) module: ModuleId,
    pub(super) owner: NodeId,
    pub(super) types: BTreeMap<String, BindingId>,
    pub(super) scopes: Vec<BTreeMap<String, BindingId>>,
    pub(super) used: Vec<(BindingId, Span)>,
    pub(super) record_values: bool,
    pub(super) builder_boundary: Option<(NodeId, &'static str, Span)>,
}

impl Ctx {
    pub(super) fn new(module: ModuleId, owner: NodeId) -> Self {
        Self {
            module,
            owner,
            types: BTreeMap::new(),
            scopes: Vec::new(),
            used: Vec::new(),
            record_values: true,
            builder_boundary: None,
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
                    | BindingKind::ExternalType
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
        BindingKind::Data
        | BindingKind::BuiltinType(_)
        | BindingKind::Alias
        | BindingKind::ExternalType => text::TYPE,
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

// 診断の冠詞に依存せず、注記に埋める種類の名を選ぶ（設計書 02-04「名前の引き方」）。
fn kind_name(kind: BindingKind) -> &'static str {
    match kind {
        BindingKind::Module(_) => text::MODULE_NAME,
        BindingKind::NamespaceRoot => text::NAMESPACE_NAME,
        BindingKind::Record => text::RECORD_DECL,
        BindingKind::Trait => text::TRAIT_DECL,
        BindingKind::Effect | BindingKind::BuiltinEffect(_) => text::EFFECT_DECL,
        BindingKind::Ctor { .. } => text::CONSTRUCTOR_NAME,
        BindingKind::TypeParam { .. } => text::TYPE_PARAMETER_NAME,
        BindingKind::EffectVar { .. } => text::EFFECT_VARIABLE_NAME,
        BindingKind::Data
        | BindingKind::BuiltinType(_)
        | BindingKind::Alias
        | BindingKind::ExternalType => text::DATA,
        BindingKind::Fn
        | BindingKind::BuiltinFn(_)
        | BindingKind::ImplFn { .. }
        | BindingKind::Const
        | BindingKind::Field { .. }
        | BindingKind::Method { .. }
        | BindingKind::Op { .. }
        | BindingKind::Local(_) => text::VALUE_NAME,
    }
}

// 見つからない名前の一覧は最大 40 個まで示す（設計書 02-04「誤りと修正案」）。
const MEMBER_LIST_LIMIT: usize = 40;

// 補助の優先順位を一か所で定め、候補の一覧にも同じ絞り込みを使う（設計書 02-04「誤りと修正案」）。
struct MemberLookup<'a> {
    path: &'a [Name],
    index: usize,
    module: Option<ModuleId>,
    pool: Vec<String>,
    hidden: Option<BindingId>,
    parent: BindingId,
    position: Position,
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
            if !public_only
                && super::same_package(self.modules, ctx.module, module)
                && let Some(package) = self.package_exports.get(&module)
            {
                names.extend(package.iter().map(|(name, id)| (name.clone(), *id)));
            }
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
        if self.builder_name(ctx, node, path) {
            return None;
        }
        let id = self.raw_name(ctx, node, path, position)?;
        self.checked_name(ctx, node, path, position, id)
    }

    fn checked_name(
        &mut self,
        ctx: &mut Ctx,
        node: NodeId,
        path: &[Name],
        position: Position,
        id: BindingId,
    ) -> Option<BindingId> {
        if self.reject_opaque(ctx, path, position, id) {
            return None;
        }
        let binding = self.out.bindings.get(id)?;
        if !position.accepts(binding.kind)
            && !(ctx.record_values
                && position == Position::Value
                && binding.kind == BindingKind::Record)
        {
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
            if code == DiagCode::E0304
                && binding.kind == BindingKind::Record
                && position == Position::Value
            {
                d = self.record_construct(d, id, dotted(path));
            }
            self.out.diagnostics.push(d.build());
            return None;
        }
        self.record_ref(ctx, node, id, path.first()?.span.to(path.last()?.span));
        Some(id)
    }

    // 型名の公開と内部表現の利用を分ける。メンバーの印を複製せず親型の所有元で判定する。
    fn reject_opaque(
        &mut self,
        ctx: &Ctx,
        path: &[Name],
        position: Position,
        id: BindingId,
    ) -> bool {
        if !matches!(
            position,
            Position::Value | Position::Ctor | Position::Record
        ) {
            return false;
        }
        let Some(binding) = self.out.bindings.get(id) else {
            return false;
        };
        let parent = match binding.kind {
            BindingKind::Ctor { data, .. } => data,
            BindingKind::Field { record, .. } => record,
            BindingKind::Record => id,
            BindingKind::Fn
            | BindingKind::BuiltinFn(_)
            | BindingKind::ImplFn { .. }
            | BindingKind::Const
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::ExternalType
            | BindingKind::Trait
            | BindingKind::Method { .. }
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Op { .. }
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Local(_) => return false,
        };
        let Some(owner) = self.out.bindings.get(parent) else {
            return false;
        };
        if !owner.opaque || owner.module == ctx.module {
            return false;
        }
        let (Some(first), Some(last), Some(module)) =
            (path.first(), path.last(), self.modules.get(owner.module))
        else {
            return false;
        };
        let mut diagnostic = DiagBuilder::new(DiagCode::E0340)
            .arg("type", &owner.name)
            .arg("module", module.name.dotted())
            .primary(first.span.to(last.span))
            .help("public_api");
        if let Some(span) = owner.span {
            diagnostic = diagnostic.secondary(span, "declared");
        }
        self.out.diagnostics.push(diagnostic.build());
        true
    }

    /// レコードと直接のデータ構成子は束縛の種類で区別する（設計書 02-04「名前の引き方」）。
    pub(super) fn record_call_name(
        &mut self,
        ctx: &mut Ctx,
        node: NodeId,
        path: &[Name],
        label: Option<Span>,
    ) -> Option<BindingId> {
        let raw = self.raw_name(ctx, node, path, Position::Record)?;
        let id = self.final_name(raw, Position::Ctor);
        if self.reject_opaque(ctx, path, Position::Value, id) {
            return None;
        }
        if self
            .out
            .bindings
            .get(id)
            .is_some_and(|b| matches!(b.kind, BindingKind::Ctor { .. }))
            && let Some(span) = label
        {
            self.out.diagnostics.push(
                DiagBuilder::new(DiagCode::E0456)
                    .primary(span)
                    .help("bind")
                    .build(),
            );
            return None;
        }
        self.checked_name(ctx, node, path, Position::Record, raw)
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
            let d = if let Some((new, _)) = renames::find("Benitoite", &first.text) {
                self.module_rename(d, ctx, path, new, position)
            } else {
                self.similar(d, &first.text, first.span, pool)
            };
            self.out.diagnostics.push(d.build());
            return None;
        };
        if let Some(alias) = self
            .pending_aliases
            .get_mut(&ctx.module)
            .and_then(|m| m.get_mut(&id))
            && first.text == alias.alias
            && first.text != alias.original
        {
            alias.references.push(first.span);
        }
        let hidden = self.prelude.get(&first.text).copied().filter(|hidden| {
            *hidden != id
                && !(self.as_module(id).is_some() && self.as_module(id) == self.as_module(*hidden))
                && self.modules.get(ctx.module).is_some_and(|m| {
                    matches!(
                        m.kind,
                        ModuleKind::Entry | ModuleKind::User | ModuleKind::Package
                    )
                })
        });
        if let Some(hidden) = hidden {
            self.out.prelude_shadowed.insert(node, hidden);
        }
        let shadowing = id;
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
                    .arg("module", dotted(path.get(..index)?))
                    .arg("declared_in", self.modules.get(module)?.name.dotted())
                    .primary(next.span);
                if let Some(span) = self.out.bindings.get(private).and_then(|b| b.span) {
                    d = d.secondary(span, "declared");
                }
                if index == 1
                    && let Some(hidden) = hidden
                {
                    d = self.shadowing_note(d, first, shadowing, hidden);
                    if self.children(ctx, hidden, true).contains_key(&next.text) {
                        d = self.prelude_help(d, first);
                    }
                }
                // 標準ライブラリと依存を編集する修正案は、根のソースの修正にはならないので出さない。
                let user_module = self
                    .modules
                    .get(module)
                    .is_some_and(|m| matches!(m.kind, ModuleKind::Entry | ModuleKind::User));
                if self
                    .modules
                    .get(module)
                    .is_some_and(|m| m.kind == ModuleKind::Package)
                {
                    d = d.note(
                        if self.out.bindings.get(private).is_some_and(|b| b.package) {
                            "package_only"
                        } else {
                            "package"
                        },
                    );
                }
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
            let mut d = DiagBuilder::new(DiagCode::E0303)
                .arg("module", dotted(path.get(..index)?))
                .arg("name", next.text.clone())
                .primary(next.span);
            if index == 1
                && let Some(hidden) = hidden
            {
                d = self.shadowing_note(d, first, shadowing, hidden);
            }
            if module.is_some_and(|m| {
                self.imported
                    .get(&m)
                    .is_some_and(|names| names.contains_key(&next.text))
            }) {
                d = d.note("not_reexported");
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
            let d = self.member_assists(
                d,
                ctx,
                MemberLookup {
                    path,
                    index,
                    module,
                    pool,
                    hidden: hidden.filter(|_| index == 1),
                    parent: id,
                    position,
                },
            );
            self.out.diagnostics.push(d.build());
            return None;
        }
        Some(self.final_name(id, position))
    }

    fn shadowing_note(
        &self,
        mut d: DiagBuilder,
        first: &Name,
        shadowing: BindingId,
        hidden: BindingId,
    ) -> DiagBuilder {
        let Some(binding) = self.out.bindings.get(shadowing) else {
            return d;
        };
        let Some(prelude) = self.out.bindings.get(hidden) else {
            return d;
        };
        // import の位置を宣言と呼ばず、利用者が直す場所を区別する（設計書 02-04「名前の引き方」）。
        let imported = self.ast(binding.module).is_some_and(|ast| {
            ast.imports
                .iter()
                .any(|import| self.out.refs.get(import.id) == Some(&shadowing))
        });
        d = d
            .arg("first", &first.text)
            .arg("shadow_kind", kind_name(binding.kind))
            .arg("prelude_kind", kind_name(prelude.kind))
            .note(if imported {
                "shadowed_import"
            } else {
                "shadowed"
            });
        if let Some(span) = binding.span {
            d = d.secondary(span, if imported { "imported" } else { "shadowing" });
        }
        d
    }

    fn prelude_help(&self, d: DiagBuilder, first: &Name) -> DiagBuilder {
        d.help_edits(
            "prelude",
            vec![Edit {
                span: Span {
                    end: first.span.start,
                    ..first.span
                },
                replacement: "Benitoite.".into(),
            }],
        )
    }

    // 当てた先が標準のモジュールで、書いた位置を解決できる場合だけ編集する（設計書 02-10「修正案」）。
    #[cold]
    #[inline(never)]
    fn module_rename(
        &self,
        d: DiagBuilder,
        ctx: &Ctx,
        path: &[Name],
        new: &str,
        position: Position,
    ) -> DiagBuilder {
        let rooted = path.first().is_some_and(|n| n.text == "Benitoite");
        let offset = usize::from(rooted);
        let Some(first) = path.get(offset) else {
            return d;
        };
        let mut old = first.text.clone();
        let mut replacement = new.to_owned();
        let module_name = format!("Benitoite.{new}");
        let new_module = if rooted {
            self.prelude.get(new).copied()
        } else {
            self.upper(ctx, new, false)
        }
        .filter(|id| {
            self.as_module(*id)
                .and_then(|m| self.modules.get(m))
                .is_some_and(|m| m.name.dotted() == module_name)
        });
        let mut span = None;
        if let Some(next) = path.get(offset.saturating_add(1)) {
            let renamed = renames::find(&module_name, &next.text);
            if let Some((member, renames::RenameKind::Renamed)) = renamed {
                old = format!("{}.{}", first.text, next.text);
                replacement = format!("{new}.{member}");
                span = new_module.map(|_| first.span.to(next.span));
            } else if new_module
                .is_some_and(|id| self.children(ctx, id, false).contains_key(&next.text))
            {
                span = Some(first.span);
            }
        } else if new_module.is_some_and(|id| {
            self.out
                .bindings
                .get(self.final_name(id, position))
                .is_some_and(|b| position.accepts(b.kind))
        }) {
            span = Some(first.span);
        }
        let d = d.arg("old", old).arg("new", replacement.clone());
        match span {
            Some(span) => d.help_edits("renamed", vec![Edit { span, replacement }]),
            None => d.help("renamed"),
        }
    }

    // 補助の分類は一つに絞り、無関係な import より元のモジュールの名前を優先する（設計書 02-04「誤りと修正案」）。
    #[cold]
    #[inline(never)]
    fn member_assists(
        &self,
        mut d: DiagBuilder,
        ctx: &Ctx,
        lookup: MemberLookup<'_>,
    ) -> DiagBuilder {
        let Some(next) = lookup.path.get(lookup.index) else {
            return d;
        };
        if let Some(hidden) = lookup.hidden
            && self.children(ctx, hidden, true).contains_key(&next.text)
            && let Some(first) = lookup.path.first()
        {
            return self.prelude_help(d, first);
        }
        // 利用者の同名モジュールを、標準ライブラリの取り込みへ誘導しない。
        let root = self
            .out
            .bindings
            .get(lookup.parent)
            .is_some_and(|b| b.kind == BindingKind::NamespaceRoot);
        let standard = lookup
            .module
            .and_then(|m| self.modules.get(m))
            .is_some_and(|m| matches!(m.kind, ModuleKind::Prelude | ModuleKind::Stdlib));
        if (root || standard)
            && let Some((full, local, key, edits)) =
                self.member_import(ctx, lookup.path, lookup.index)
        {
            d = d.arg("full", full).arg("local", local);
            return if edits.is_empty() {
                d.help(key)
            } else {
                d.help_edits(key, edits)
            };
        }
        if root && let Some((new, _)) = renames::find("Benitoite", &next.text) {
            return self.module_rename(d, ctx, lookup.path, new, lookup.position);
        }
        let module = lookup.module.and_then(|m| self.modules.get(m));
        if matches!(
            next.text.as_str(),
            "new" | "create" | "make" | "of" | "init"
        ) && let Some(record) = self.record_binding(lookup.parent)
        {
            let mut name = dotted(lookup.path.get(..lookup.index).unwrap_or_default());
            if self.as_module(lookup.parent).is_some()
                && self.type_in_module(lookup.parent).is_none()
                && let Some(binding) = self.out.bindings.get(record)
            {
                name.push('.');
                name.push_str(&binding.name);
            }
            return self.record_construct(d, record, name);
        }
        if let Some(module) = module
            && matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
            && let Some((new, kind)) = renames::find(&module.name.dotted(), &next.text)
        {
            let d = d.arg("old", next.text.clone()).arg("new", new);
            return if kind.replace() {
                d.help_edits(
                    kind.key(),
                    vec![Edit {
                        span: next.span,
                        replacement: new.into(),
                    }],
                )
            } else {
                d.help(kind.key())
            };
        }
        let mut has_help = false;
        if module.is_some_and(|m| m.name.dotted() == "Benitoite.String") {
            let key = match next.text.as_str() {
                "length" => Some("length"),
                "slice" | "substring" => Some("slice"),
                "indexOf" => Some("index_of"),
                _ => None,
            };
            if let Some(key) = key {
                d = d.help(key);
                has_help = true;
            }
        }
        if matches!(next.text.as_str(), "unwrap" | "expect")
            && module.is_some_and(|m| {
                matches!(
                    m.name.dotted().as_str(),
                    "Benitoite.Option" | "Benitoite.Result"
                )
            })
        {
            d = d.help("unwrap");
            has_help = true;
        }
        // 専用の案内と近い名前は従来どおり併記する。一覧はどちらもない場合だけ示す。
        let candidates = suggest::candidates(&next.text, lookup.pool.iter().map(String::as_str));
        if !candidates.is_empty() {
            return Self::similar_candidates(d, next.span, candidates);
        }
        if !has_help && !lookup.pool.is_empty() {
            let names = crate::diag::code_list(
                lookup
                    .pool
                    .iter()
                    .take(MEMBER_LIST_LIMIT)
                    .map(String::as_str),
            );
            d = d.arg("names", names);
            d = if lookup.pool.len() > MEMBER_LIST_LIMIT {
                d.arg(
                    "remaining",
                    lookup
                        .pool
                        .len()
                        .saturating_sub(MEMBER_LIST_LIMIT)
                        .to_string(),
                )
                .note("members_more")
            } else {
                d.note("members")
            };
        }
        d
    }

    fn record_binding(&self, id: BindingId) -> Option<BindingId> {
        if self.out.bindings.get(id)?.kind == BindingKind::Record {
            return Some(id);
        }
        let module = self.as_module(id)?;
        let name = self.modules.get(module)?.name.0.last()?;
        let record = *self.top.get(&module)?.get(name)?;
        (self.out.bindings.get(record)?.kind == BindingKind::Record).then_some(record)
    }

    #[cold]
    #[inline(never)]
    fn record_construct(&self, d: DiagBuilder, id: BindingId, record: String) -> DiagBuilder {
        let mut fields = self
            .members
            .get(&id)
            .into_iter()
            .flat_map(|names| names.iter())
            .filter_map(|(name, id)| {
                let BindingKind::Field { index, .. } = self.out.bindings.get(*id)?.kind else {
                    return None;
                };
                Some((index, name))
            })
            .collect::<Vec<_>>();
        fields.sort_by_key(|(index, _)| *index);
        let fields = fields
            .into_iter()
            .map(|(_, name)| format!("{name}: ..."))
            .collect::<Vec<_>>()
            .join(", ");
        d.arg("record", record)
            .arg("fields", fields)
            .help("construct")
    }

    // 取り込み済みなら参照だけを直し、衝突する名前には別名を案内する（設計書 02-10「修正案」）。
    #[cold]
    #[inline(never)]
    fn member_import(
        &self,
        ctx: &Ctx,
        path: &[Name],
        index: usize,
    ) -> Option<(String, String, &'static str, Vec<Edit>)> {
        let rooted = path.first()?.text == "Benitoite";
        let unofficial = rooted && path.get(1).is_some_and(|n| n.text == "Unofficial");
        let offset = if unofficial { 2 } else { usize::from(rooted) };
        let tail = if unofficial {
            path.get(offset..)?
        } else {
            path.get(offset..=index)?
        };
        let module = crate::prelude::STDLIB
            .iter()
            .filter(|m| !m.prelude)
            .filter(|m| {
                if unofficial {
                    m.unofficial
                        && tail.len() >= m.path.len()
                        && tail
                            .iter()
                            .take(m.path.len())
                            .map(|n| n.text.as_str())
                            .eq(m.path.iter().copied())
                } else {
                    tail.iter()
                        .map(|n| n.text.as_str())
                        .eq(m.path.iter().copied())
                }
            })
            .max_by_key(|m| m.path.len())?;
        let prefix = path.get(..offset.saturating_add(module.path.len()))?;
        let canonical = format!("Benitoite.{}", module.path.join("."));
        let full = if module.unofficial {
            format!("Benitoite.Unofficial.{}", module.path.join("."))
        } else {
            canonical.clone()
        };
        let imports = self.imported.get(&ctx.module);
        let imported = imports.and_then(|names| {
            names.iter().find_map(|(name, id)| {
                let id = (*id)?;
                let m = self.as_module(id).and_then(|m| self.modules.get(m))?;
                (m.name.dotted() == canonical).then_some(name.clone())
            })
        });
        let local = imported
            .clone()
            .unwrap_or_else(|| module.path.last().copied().unwrap_or_default().into());
        let conflict = self
            .top
            .get(&ctx.module)
            .is_some_and(|names| names.contains_key(&local))
            || (imported.is_none() && imports.is_some_and(|names| names.contains_key(&local)));
        if conflict {
            return Some((full, local, "import_member_as", Vec::new()));
        }
        let mut edits = Vec::new();
        if imported.is_none() {
            let Some(span) = self.import_start(ctx) else {
                return Some((full, local, "import_member", Vec::new()));
            };
            edits.push(Edit {
                span,
                replacement: format!("import {full}\n"),
            });
        }
        edits.push(Edit {
            span: prefix.first()?.span.to(prefix.last()?.span),
            replacement: local.clone(),
        });
        Some((
            full,
            local,
            if imported.is_some() {
                "use_imported"
            } else {
                "import_member"
            },
            edits,
        ))
    }

    // 取り込みの修正案は、文書コメントより前の同じ行頭に挿入する（設計書 02-04「誤りと修正案」）。
    fn import_start(&self, ctx: &Ctx) -> Option<Span> {
        self.ast(ctx.module)
            .and_then(|a| {
                a.imports.first().map(|i| i.span).or_else(|| {
                    a.decls
                        .first()
                        .map(|d| d.doc.as_ref().map_or(d.span, |doc| doc.span))
                })
            })
            .and_then(|s| self.line_start(s))
    }

    // 最後の段は位置に合わせて、標準のモジュールの同名の型・エフェクトと省略できる構成子を選ぶ。
    // 候補の検査も同じ変換を使い、実際には解決できない置き換えを付けない（01-03）。
    fn final_name(&self, mut id: BindingId, position: Position) -> BindingId {
        if matches!(
            position,
            Position::Type
                | Position::Record
                | Position::Class
                | Position::Ctor
                | Position::Value
                | Position::Effect
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
        Self::similar_candidates(d, span, candidates)
    }

    fn similar_candidates(d: DiagBuilder, span: Span, candidates: Vec<String>) -> DiagBuilder {
        if candidates.is_empty() {
            return d;
        }
        let listed = crate::diag::code_list(candidates.iter().map(String::as_str));
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
        let start = self.import_start(ctx);
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
        // 略記は同じ名前の原子を連続して持つ。群の最初だけで名前と種類を検査し、
        // 診断と修正編集を重ねず、成功した束縛を各原子へ記録する（設計書 02-04「範囲引数の解決」）。
        let mut group_binding = None;
        for (index, effect) in uses.effects.iter().enumerate() {
            if effect.scope.as_deref().is_some_and(|s| s.element.start > 0) {
                if let Some(id) = group_binding {
                    self.record_ref(ctx, effect.id, id, effect.span);
                    self.effect_arguments(ctx, effect, id);
                }
                continue;
            }
            group_binding = None;
            let Some(id) = self.raw_name(ctx, effect.id, &effect.path, Position::Effect) else {
                prefix_valid = false;
                continue;
            };
            let Some(binding) = self.out.bindings.get(id) else {
                continue;
            };
            if Position::Effect.accepts(binding.kind) {
                group_binding = Some(id);
                self.record_ref(ctx, effect.id, id, effect.span);
                self.effect_arguments(ctx, effect, id);
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
                // 次の型として取り込まれた名前の直前で閉じると、コンマが外側の型の並びへ戻る（02-04「誤りと修正案」）。
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
