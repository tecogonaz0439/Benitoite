//! import の束縛と修正案の位置（設計書 02-04「import の宣言の誤り」）。

use std::collections::BTreeMap;

use crate::base::{BytePos, ModuleId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::ImportDecl;

use super::BindingKind;
use super::collect::Resolver;

impl Resolver<'_> {
    pub(super) fn imports(&mut self) {
        for module in self.modules.iter() {
            let Some(ast) = self.ast(module.id) else {
                continue;
            };
            let mut seen = BTreeMap::new();
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
                if let Some(first) = seen.get(&name.text).copied() {
                    let suggestion = self.import_alias(module.id, import);
                    let mut d = DiagBuilder::new(DiagCode::E0323)
                        .arg("name", name.text.clone())
                        .arg("module", dotted(import))
                        .arg("suggestion", suggestion.clone())
                        .primary(name.span)
                        .secondary(first, "first");
                    let edit = if import.alias.is_some() {
                        Edit {
                            span: name.span,
                            replacement: suggestion,
                        }
                    } else {
                        Edit {
                            span: Span {
                                start: import.span.end,
                                ..import.span
                            },
                            replacement: format!(" as {suggestion}"),
                        }
                    };
                    d = d.help_edits("alias", vec![edit]);
                    self.out.diagnostics.push(d.build());
                } else {
                    seen.insert(name.text.clone(), name.span);
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
                    let suggestion = self.import_alias(module.id, import);
                    let mut d = DiagBuilder::new(DiagCode::E0305)
                        .arg("name", name.text.clone())
                        .arg("suggestion", suggestion.clone())
                        .primary(name.span);
                    if let Some(span) = self.out.bindings.get(first).and_then(|b| b.span) {
                        d = d.secondary(span, "first");
                    }
                    let edit = if import.alias.is_some() {
                        Edit {
                            span: name.span,
                            replacement: suggestion,
                        }
                    } else {
                        Edit {
                            span: Span {
                                start: import.span.end,
                                ..import.span
                            },
                            replacement: format!(" as {suggestion}"),
                        }
                    };
                    self.out
                        .diagnostics
                        .push(d.help_edits("import", vec![edit]).build());
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
            }
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

fn dotted(import: &ImportDecl) -> String {
    import
        .path
        .iter()
        .map(|n| n.text.as_str())
        .collect::<Vec<_>>()
        .join(".")
}
