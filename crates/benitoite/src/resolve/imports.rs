//! import の束縛と修正案の位置（設計書 02-04「import の宣言の誤り」）。

use std::collections::BTreeMap;

use crate::base::{BytePos, ModuleId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::modules::ModuleKind;
use crate::syntax::ast::ImportDecl;
use crate::types::builtin::BUILTIN_EFFECTS;

use super::BindingKind;
use super::collect::Resolver;

pub(super) struct PendingAlias {
    diagnostic: DiagBuilder,
    removal: Edit,
    pub(super) alias: String,
    pub(super) original: String,
    rewrite: bool,
    pub(super) references: Vec<Span>,
}

impl Resolver<'_> {
    pub(super) fn imports(&mut self) {
        for module in self.modules.iter() {
            let Some(ast) = self.ast(module.id) else {
                continue;
            };
            let mut seen = BTreeMap::<String, (&ImportDecl, bool, Span)>::new();
            let mut targets = BTreeMap::new();
            for import in &ast.imports {
                let Some(name) = import.alias.as_ref().or_else(|| import.path.last()) else {
                    continue;
                };
                let target = module
                    .imports
                    .iter()
                    .find(|l| l.decl == import.id)
                    .and_then(|l| l.target);
                if name.text == "Benitoite" {
                    self.out.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0325)
                            .primary(name.span)
                            .note("reserved")
                            .build(),
                    );
                    continue;
                }
                let declares_effects =
                    target
                        .and_then(|id| self.modules.get(id))
                        .is_some_and(|info| {
                            matches!(info.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
                                && BUILTIN_EFFECTS.iter().any(|def| {
                                    !def.module.is_empty()
                                        && info
                                            .name
                                            .0
                                            .iter()
                                            .skip(1)
                                            .map(String::as_str)
                                            .eq(def.module.iter().copied())
                                })
                        });
                // 組み込みのエフェクトの名前を別名で偽れないようにする
                // （設計書 01-03「モジュールと import（初回リリース版）」）。
                // 二度目の取り込みは E0324 の行の削除で直すので、編集を重ねない。
                let mut pending = None;
                if declares_effects
                    && !target.is_some_and(|id| targets.contains_key(&id))
                    && let Some(alias) = &import.alias
                    && let Some(original) = import.path.last()
                {
                    let conflict = self
                        .top
                        .get(&module.id)
                        .is_some_and(|names| names.contains_key(&original.text))
                        || ast.imports.iter().any(|other| {
                            other.id != import.id
                                && other
                                    .alias
                                    .as_ref()
                                    .or_else(|| other.path.last())
                                    .is_some_and(|name| name.text == original.text)
                        });
                    pending = Some(PendingAlias {
                        diagnostic: DiagBuilder::new(DiagCode::E0339)
                            .arg("module", dotted(import))
                            .arg("name", alias.text.clone())
                            .arg("original", original.text.clone())
                            .primary(alias.span),
                        removal: Edit {
                            span: Span {
                                start: original.span.end,
                                end: alias.span.end,
                                ..import.span
                            },
                            replacement: String::new(),
                        },
                        alias: alias.text.clone(),
                        original: original.text.clone(),
                        rewrite: !conflict,
                        references: Vec::new(),
                    });
                }
                if let Some((first, first_effects, first_span)) = seen.get(&name.text).copied() {
                    let mut d = DiagBuilder::new(DiagCode::E0323)
                        .arg("name", name.text.clone())
                        .primary(name.span)
                        .secondary(first_span, "first");
                    // 対象の別名は削除するので、衝突のための改名案を重ねない。
                    let removes_alias = (first_effects && first.alias.is_some())
                        || (declares_effects && import.alias.is_some());
                    if !(removes_alias || (first_effects && declares_effects)) {
                        let rename = if declares_effects { first } else { import };
                        let suggestion = self.import_alias(module.id, rename);
                        d = d
                            .arg("module", dotted(rename))
                            .arg("suggestion", suggestion.clone());
                        d = d.help_edits("alias", vec![alias_edit(rename, &suggestion)]);
                    }
                    self.out.diagnostics.push(d.build());
                } else {
                    seen.insert(name.text.clone(), (import, declares_effects, name.span));
                }
                if let Some(target) = target {
                    if let Some(first) = targets.get(&target).copied() {
                        let mut d = DiagBuilder::new(DiagCode::E0324)
                            .arg("module", dotted(import))
                            .primary(import.span)
                            .secondary(first, "first");
                        if let Some(span) = self.whole_line(import.span) {
                            d = d.help_edits(
                                "remove",
                                vec![Edit {
                                    span,
                                    replacement: String::new(),
                                }],
                            );
                        } else {
                            d = d.help("remove");
                        }
                        self.out.diagnostics.push(d.build());
                    } else {
                        targets.insert(target, import.span);
                    }
                }
                if let Some(first) = self
                    .top
                    .get(&module.id)
                    .and_then(|m| m.get(&name.text))
                    .copied()
                {
                    let mut d = DiagBuilder::new(DiagCode::E0305)
                        .arg("name", name.text.clone())
                        .primary(name.span);
                    if let Some(span) = self.out.bindings.get(first).and_then(|b| b.span) {
                        d = d.secondary(span, "first");
                    }
                    if declares_effects {
                        if import.alias.is_none() {
                            d = d.arg("module", dotted(import)).help("rename");
                        }
                    } else {
                        let suggestion = self.import_alias(module.id, import);
                        d = d.arg("suggestion", suggestion.clone());
                        d = d.help_edits("import", vec![alias_edit(import, &suggestion)]);
                    }
                    self.out.diagnostics.push(d.build());
                }
                let id = target.map(|target| {
                    self.node_binding(
                        module.id,
                        import.id,
                        name,
                        BindingKind::Module(target),
                        false,
                        None,
                    )
                });
                if let Some(id) = id {
                    self.out.refs.insert(import.id, id);
                }
                self.imported
                    .entry(module.id)
                    .or_default()
                    .entry(name.text.clone())
                    .or_insert(id);
                if let (Some(id), Some(pending)) = (id, pending) {
                    // 本来の名前も解決し、同じ取り込みを足す派生の修正案を出さない
                    // （設計書 02-04「import の宣言の誤り」）。
                    if pending.rewrite {
                        self.imported
                            .entry(module.id)
                            .or_default()
                            .entry(pending.original.clone())
                            .or_insert(Some(id));
                    }
                    self.pending_aliases
                        .entry(module.id)
                        .or_default()
                        .insert(id, pending);
                }
            }
        }
    }

    pub(super) fn finish_aliases(&mut self, module: ModuleId) {
        let Some(pending) = self.pending_aliases.remove(&module) else {
            return;
        };
        for (_, mut alias) in pending {
            let mut edits = vec![alias.removal];
            if alias.rewrite {
                alias.references.sort_by_key(|s| (s.file, s.start, s.end));
                alias.references.dedup();
                edits.extend(alias.references.into_iter().map(|span| Edit {
                    span,
                    replacement: alias.original.clone(),
                }));
            }
            self.out
                .diagnostics
                .push(alias.diagnostic.help_edits("remove", edits).build());
        }
    }

    fn import_alias(&self, module: ModuleId, import: &ImportDecl) -> String {
        let base = import
            .path
            .iter()
            .rev()
            .take(2)
            .rev()
            .map(|n| n.text.as_str())
            .collect::<String>();
        let base = if base.is_empty() {
            "Module".to_owned()
        } else {
            base
        };
        let ast = self.ast(module);
        let used = |name: &str| {
            name == "Benitoite"
                || self.top.get(&module).is_some_and(|t| t.contains_key(name))
                || ast.is_some_and(|a| {
                    a.imports.iter().any(|i| {
                        i.alias
                            .as_ref()
                            .or_else(|| i.path.last())
                            .is_some_and(|n| n.text == name)
                    })
                })
        };
        if !used(&base) {
            return base;
        }
        let mut suffix = 2_u64;
        loop {
            let name = format!("{base}{suffix}");
            if !used(&name) {
                return name;
            }
            suffix = suffix.saturating_add(1);
        }
    }

    pub(super) fn line_start(&self, span: Span) -> Option<Span> {
        let bytes = self.sources.get(span.file)?.text();
        let start = usize::try_from(span.start.0).ok()?;
        let prefix = bytes.get(..start)?;
        let pos = prefix
            .iter()
            .rposition(|b| *b == b'\n')
            .map_or(0, |i| i.saturating_add(1));
        // BOM はソースの先頭だけに置ける。最初の行への挿入でも BOM の後に置く
        // （設計書 01-01「ソースファイルと文字集合」）。
        let pos = if pos == 0 && bytes.starts_with(&[0xef, 0xbb, 0xbf]) {
            3
        } else {
            pos
        };
        let pos = BytePos(u32::try_from(pos).ok()?);
        Some(Span {
            start: pos,
            end: pos,
            ..span
        })
    }

    fn whole_line(&self, span: Span) -> Option<Span> {
        let start = self.line_start(span)?;
        let bytes = self.sources.get(span.file)?.text();
        let offset = usize::try_from(span.end.0).ok()?;
        let end = bytes
            .get(offset..)?
            .iter()
            .position(|b| *b == b'\n')
            .map_or(bytes.len(), |i| offset.saturating_add(i).saturating_add(1));
        Some(Span {
            end: BytePos(u32::try_from(end).ok()?),
            ..start
        })
    }
}

fn alias_edit(import: &ImportDecl, suggestion: &str) -> Edit {
    if let Some(alias) = &import.alias {
        Edit {
            span: alias.span,
            replacement: suggestion.to_owned(),
        }
    } else {
        Edit {
            span: Span {
                start: import.span.end,
                ..import.span
            },
            replacement: format!(" as {suggestion}"),
        }
    }
}

fn dotted(import: &ImportDecl) -> String {
    import
        .path
        .iter()
        .map(|n| n.text.as_str())
        .collect::<Vec<_>>()
        .join(".")
}
