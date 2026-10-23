//! 公開する契約、実装のメソッドと宣言の循環（設計書 02-04「宣言の検査」）。

use std::collections::{BTreeMap, BTreeSet};

use crate::base::BindingId;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::Item;

use super::collect::Resolver;
use super::{Binding, BindingKind, Level, text};

fn level(binding: &Binding) -> Level {
    Level::of(binding.public, binding.package)
}

impl Resolver<'_> {
    pub(super) fn check_declarations(&mut self) {
        for (owner, used, span, file) in self.contracts.clone() {
            let (Some(binding), Some(exposed)) =
                (self.out.bindings.get(owner), self.out.bindings.get(used))
            else {
                continue;
            };
            // 別モジュールの非公開名は名前の検索で拒み、公開名は契約の段階以上になる。
            // 契約では別モジュールのパッケージ内公開だけを追加で調べる（設計書 01-03「公開（初回リリース版）」）。
            if level(exposed) >= level(binding)
                || (exposed.module != binding.module && level(exposed) != Level::Package)
                || !matches!(
                    exposed.kind,
                    BindingKind::Data
                        | BindingKind::BuiltinType(_)
                        | BindingKind::Alias
                        | BindingKind::ExternalType
                        | BindingKind::Record
                        | BindingKind::Trait
                        | BindingKind::Effect
                        | BindingKind::BuiltinEffect(_)
                )
            {
                continue;
            }
            let target = if binding.package {
                text::PACKAGE
            } else {
                text::PUBLIC
            };
            let mut d = DiagBuilder::new(DiagCode::E0329)
                .arg(
                    "level",
                    if binding.package {
                        text::PACKAGE_LEVEL
                    } else {
                        text::PUBLIC
                    },
                )
                .arg(
                    "used_level",
                    if exposed.package {
                        text::PACKAGE_LEVEL
                    } else {
                        text::NON_PUBLIC
                    },
                )
                .arg("target", target)
                .arg("what", declaration_kind(binding.kind))
                .arg("name", binding.name.clone())
                .arg("used_kind", declaration_kind(exposed.kind))
                .arg("used", exposed.name.clone())
                .primary(span);
            if let Some(span) = exposed.span {
                d = d.secondary(span, "declared");
            }
            let edit = if exposed.package {
                self.package_span.get(&used).map(|span| Edit {
                    span: *span,
                    replacement: String::new(),
                })
            } else {
                self.insertion.get(&used).map(|span| Edit {
                    span: *span,
                    replacement: format!("{target} "),
                })
            };
            if let Some(edit) = edit {
                d = d.help_edits("make_public", vec![edit]);
            } else {
                d = d.help("make_public");
            }
            if file {
                // 本体で処理してもファイルから加わる契約は消えない
                // （設計書 02-10「ファイル単位のエフェクトの宣言の診断」）。
                d = d.note("file_contract").help("file");
            } else if matches!(
                exposed.kind,
                BindingKind::Effect | BindingKind::BuiltinEffect(_)
            ) {
                d = d.help("handle");
            }
            self.out.diagnostics.push(d.build());
        }
        self.cycles(&self.alias_edges.clone(), DiagCode::E0431);
        self.cycles(&self.trait_edges.clone(), DiagCode::E0703);
        for module in self.modules.iter() {
            let Some(ast) = self.ast(module.id) else {
                continue;
            };
            for top in &ast.decls {
                let Item::Impl(decl) = &top.item else {
                    continue;
                };
                let Some(class) = self.out.refs.get(decl.class.id).copied() else {
                    continue;
                };
                let Some(binding) = self.out.bindings.get(class) else {
                    continue;
                };
                let class_name = binding.name.clone();
                let class_span = binding.span;
                let methods = self.members.get(&class).cloned().unwrap_or_default();
                let mut found = BTreeSet::new();
                let mut ctx = super::lookup::Ctx::new(module.id, decl.id);
                for f in &decl.fns {
                    if let Some(method) = methods.get(&f.decl.name.text).copied() {
                        self.record_ref(&mut ctx, f.id, method, f.decl.name.span);
                        found.insert(f.decl.name.text.clone());
                    } else {
                        let d = DiagBuilder::new(DiagCode::E0708)
                            .arg("name", f.decl.name.text.clone())
                            .arg("trait_name", class_name.clone())
                            .primary(f.decl.name.span);
                        let d = self.similar(
                            d,
                            &f.decl.name.text,
                            f.decl.name.span,
                            methods.keys().cloned().collect(),
                        );
                        self.out.diagnostics.push(d.build());
                    }
                }
                let missing: Vec<_> = methods
                    .keys()
                    .filter(|name| !found.contains(*name))
                    .cloned()
                    .collect();
                if !missing.is_empty() {
                    let mut d = DiagBuilder::new(DiagCode::E0707)
                        .arg("trait_name", class_name)
                        .arg("methods", missing.join(", "))
                        .primary(decl.class.span);
                    if let Some(span) = class_span {
                        d = d.secondary(span, "trait_decl");
                    }
                    self.out.diagnostics.push(d.build());
                }
            }
        }
    }

    pub(super) fn check_constants(&mut self) {
        self.cycles(&self.const_edges.clone(), DiagCode::E0437);
    }

    fn cycles(&mut self, edges: &BTreeMap<BindingId, Vec<BindingId>>, code: DiagCode) {
        let mut finished = BTreeSet::new();
        for root in edges.keys() {
            if finished.contains(root) {
                continue;
            }
            let mut active = BTreeMap::new();
            let mut stack = vec![(*root, 0_usize)];
            active.insert(*root, 0_usize);
            while let Some((current, next)) = stack.last().copied() {
                let target = edges
                    .get(&current)
                    .and_then(|targets| targets.get(next))
                    .copied();
                let Some(target) = target else {
                    stack.pop();
                    active.remove(&current);
                    finished.insert(current);
                    continue;
                };
                if let Some(frame) = stack.last_mut() {
                    frame.1 = next.saturating_add(1);
                }
                if let Some(start) = active.get(&target).copied() {
                    let Some(binding) = self.out.bindings.get(target) else {
                        continue;
                    };
                    let mut d = DiagBuilder::new(code).arg("name", binding.name.clone());
                    if let Some(span) = binding.span {
                        d = d.primary(span);
                    }
                    let chain: Vec<_> = stack
                        .iter()
                        .skip(start)
                        .map(|(id, _)| *id)
                        .chain(std::iter::once(target))
                        .collect();
                    let names = chain
                        .iter()
                        .filter_map(|id| self.out.bindings.get(*id).map(|b| b.name.clone()))
                        .collect::<Vec<_>>()
                        .join(" -> ");
                    d = d.arg("chain", names).note("chain");
                    for (id, _) in stack.iter().skip(start.saturating_add(1)) {
                        if let Some(span) = self.out.bindings.get(*id).and_then(|b| b.span) {
                            d = d.secondary(span, "member");
                        }
                    }
                    if code == DiagCode::E0431 {
                        d = d.help("data");
                    }
                    self.out.diagnostics.push(d.build());
                } else if !finished.contains(&target) && edges.contains_key(&target) {
                    active.insert(target, stack.len());
                    stack.push((target, 0));
                }
            }
        }
    }
}

fn declaration_kind(kind: BindingKind) -> &'static str {
    match kind {
        BindingKind::Fn
        | BindingKind::BuiltinFn(_)
        | BindingKind::ImplFn { .. }
        | BindingKind::Field { .. }
        | BindingKind::Method { .. }
        | BindingKind::Op { .. }
        | BindingKind::Local(_) => text::FUNCTION,
        BindingKind::Const => text::CONSTANT,
        BindingKind::Data
        | BindingKind::BuiltinType(_)
        | BindingKind::TypeParam { .. }
        | BindingKind::Ctor { .. } => text::DATA,
        BindingKind::ExternalType => text::DATA,
        BindingKind::Alias => text::ALIAS,
        BindingKind::Record => text::RECORD_DECL,
        BindingKind::Trait => text::TRAIT_DECL,
        BindingKind::Effect | BindingKind::BuiltinEffect(_) | BindingKind::EffectVar { .. } => {
            text::EFFECT_DECL
        }
        BindingKind::Module(_) | BindingKind::NamespaceRoot => text::MODULE,
    }
}
