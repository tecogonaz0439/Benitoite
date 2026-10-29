//! uses の重なり、入口の契約と IO.All の警告（設計書 02-05「宣言の検査」「警告」）。
use super::super::{
    context::Body,
    decls::{Decls, Scope},
};
use crate::base::{ModuleId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::{EffectRef, Expr, FnDecl, Item, UsesList};
use crate::types::builtin::{BUILTIN_EFFECTS, BuiltinEffectId};
use crate::types::{EffectName, EffectSet};
use std::collections::{BTreeMap, BTreeSet};

pub(super) fn check_uses(d: &mut Decls<'_>, uses: &UsesList, scope: &Scope) {
    let mut names = BTreeMap::new();
    let mut vars = BTreeSet::new();
    for (i, e) in uses.effects.iter().enumerate() {
        let Some(id) = d.reference(e.id) else {
            continue;
        };
        if Some(id) == d.resolved.stdlib("Benitoite.Failure.Fail") {
            continue;
        }
        let repeated = if let Some(v) = scope.effects.get(id) {
            !vars.insert(*v)
        } else if let Some(mut name) = d.effect_name(id) {
            if let Some(range) = d.resolved.scopes.get(e.id) {
                match &mut name {
                    EffectName::Builtin(_, scope) | EffectName::User(_, scope) => {
                        *scope = crate::types::builtin::RangeIndex::fixed(range.clone())
                    }
                }
            }
            if let Some(first) = names.get(&name).copied() {
                if e.scope.is_some() {
                    let first: &EffectRef = first;
                    d.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0419)
                            .primary(e.scope.as_deref().map_or(e.span, |s| s.element_span()))
                            .secondary(
                                first
                                    .scope
                                    .as_deref()
                                    .map_or(first.span, |s| s.element_span()),
                                "first_scope",
                            )
                            .arg("name", path(e))
                            .help("scope")
                            .build(),
                    );
                    continue;
                }
                true
            } else {
                names.insert(name, e);
                false
            }
        } else {
            false
        };
        if repeated {
            duplicate_use(d, uses, i);
        }
    }
}
pub(in crate::typeck) fn duplicate_use(d: &mut Decls<'_>, uses: &UsesList, i: usize) {
    let Some(e) = uses.effects.get(i) else {
        return;
    };
    d.diagnostics.push(
        DiagBuilder::new(DiagCode::E0419)
            .primary(e.span)
            .arg("name", path(e))
            .help_edits(
                "remove",
                vec![Edit {
                    span: removal(uses, i),
                    replacement: String::new(),
                }],
            )
            .build(),
    );
}
fn removal(uses: &UsesList, i: usize) -> Span {
    let Some(e) = uses.effects.get(i) else {
        return uses.span;
    };
    if let Some(prev) = i.checked_sub(1).and_then(|i| uses.effects.get(i)) {
        Span {
            start: prev.span.end,
            ..e.span
        }
    } else if let Some(next) = uses.effects.get(i.saturating_add(1)) {
        Span {
            end: next.span.start,
            ..e.span
        }
    } else {
        uses.span
    }
}
fn path(e: &EffectRef) -> String {
    e.path
        .iter()
        .map(|n| n.text.as_str())
        .collect::<Vec<_>>()
        .join(".")
}
pub(super) fn check_entries(d: &mut Decls<'_>) {
    for ast in d.asts {
        for top in &ast.decls {
            let Item::Fn(f) = &top.item else {
                continue;
            };
            let Some(id) = d.binding(f.id) else {
                continue;
            };
            let main = d.resolved.main == Some(id);
            let test = top.attrs.iter().any(|a| a.name.text == "test");
            if !(main || test) {
                continue;
            }
            let Some(effective) = d.out.effective_effects.get(id) else {
                continue;
            };
            let mut seen = BTreeSet::new();
            // 両方に書かれた効果も、個別の uses だけを直しても除けないことを先に示す
            // （設計書 02-10「ファイル単位のエフェクトの宣言の診断」）。
            for origin in effective
                .origins
                .iter()
                .filter(|o| o.file)
                .chain(effective.origins.iter().filter(|o| !o.file))
            {
                let failure = (!origin.effects.failures.is_empty())
                    .then(|| d.resolved.stdlib("Benitoite.Failure.Fail"))
                    .flatten()
                    .map(|id| EffectName::User(id, crate::types::builtin::RangeIndex::TOP));
                for name in origin.effects.names.iter().cloned().chain(failure) {
                    if !seen.insert(name.clone()) {
                        continue;
                    }
                    match name {
                        EffectName::User(id, _)
                            if d.resolved.bindings.get(id).is_some_and(|b| {
                                matches!(b.kind, crate::resolve::BindingKind::Effect)
                            }) =>
                        {
                            let mut diagnostic = DiagBuilder::new(DiagCode::E0506)
                                .arg("function", &f.name.text)
                                .arg("effect", origin.name.clone())
                                .primary(origin.span)
                                .help(if origin.file { "file" } else { "handle" });
                            // 同名の利用者エフェクトをFailの捕捉へ案内しない
                            // （設計書 02-10「修正案」）。
                            if !origin.file
                                && Some(id) == d.resolved.stdlib("Benitoite.Failure.Fail")
                            {
                                diagnostic = diagnostic.help("to_result");
                            }
                            d.diagnostics.push(diagnostic.build());
                        }
                        EffectName::Builtin(b, _) if main && b != BuiltinEffectId::IO_ALL => {
                            if b.def().is_some_and(|b| b.module == ["Assert"]) {
                                d.diagnostics.push(
                                    DiagBuilder::new(DiagCode::E0415)
                                        .primary(origin.span)
                                        .note("assert")
                                        .build(),
                                );
                            } else if !b.def().is_some_and(|b| {
                                b.in_io_all
                                    || b.module.first() == Some(&"Network")
                                    || b.module == ["Log"] && b.name == "Log"
                            }) {
                                d.diagnostics.push(
                                    DiagBuilder::new(DiagCode::E0415)
                                        .primary(origin.span)
                                        .note("effects")
                                        .build(),
                                );
                            }
                        }
                        EffectName::Builtin(_, _) | EffectName::User(_, _) => {}
                    }
                }
            }
        }
    }
}

pub(super) fn check_body(ctx: &mut Body<'_, '_>) {
    if !ctx.scheme.wrote_io_all {
        return;
    }
    let Some(owner) = ctx.owner else {
        return;
    };
    let function = ctx
        .decls
        .asts
        .iter()
        .flat_map(|m| &m.decls)
        .find_map(|d| match &d.item {
            Item::Fn(f) if f.id == owner => Some(f.as_ref().clone()),
            Item::Impl(i) => i
                .fns
                .iter()
                .find(|f| f.decl.id == owner)
                .map(|f| f.decl.clone()),
            Item::Fn(_)
            | Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::ExternalType(_)
            | Item::Error(_) => None,
        });
    let Some(FnDecl {
        uses,
        body: Some(body),
        name,
        ..
    }) = function
    else {
        return;
    };
    // 誤りの式への置換で引数のエフェクトも失われ得るため、縮小の修正案を出さない
    // （設計書 02-05「警告」）。
    let mut contains_error = false;
    super::super::consts::visit_block(&body, &mut |e| {
        contains_error |= matches!(e, Expr::Error(_));
    });
    if contains_error {
        return;
    }
    let actual = ctx.actual_effects();
    let all = BUILTIN_EFFECTS
        .iter()
        .enumerate()
        .filter_map(|(i, e)| {
            if e.in_io_all {
                u16::try_from(i).ok().map(|i| {
                    EffectName::Builtin(BuiltinEffectId(i), crate::types::builtin::RangeIndex::TOP)
                })
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    if all.iter().all(|e| actual.names.contains(e)) {
        return;
    }
    let effective = ctx
        .decls
        .binding(owner)
        .and_then(|id| ctx.decls.out.effective_effects.get(id));
    // 共通IO.Allは関数ごとに知らせるが、一関数の実効果で全関数の契約を縮めない
    // （設計書 02-05「警告」）。
    if let Some(origin) = effective
        .into_iter()
        .flat_map(|e| &e.origins)
        .find(|origin| origin.file && all.iter().all(|e| origin.effects.names.contains(e)))
    {
        ctx.diagnostic(
            DiagBuilder::new(DiagCode::W0501)
                .primary(name.span)
                .secondary(origin.span, "file")
                .help("shared")
                .build(),
        );
        return;
    }
    let file_effects = effective
        .into_iter()
        .flat_map(|e| &e.origins)
        .filter(|origin| origin.file)
        .fold(EffectSet::empty(), |effects, origin| {
            effects.union(&origin.effects)
        });
    let Some(uses) = uses else {
        return;
    };
    let Some(index) = uses.effects.iter().position(|e| {
        ctx.decls
            .reference(e.id)
            .and_then(|id| ctx.decls.effect_name(id))
            == Some(EffectName::Builtin(
                BuiltinEffectId::IO_ALL,
                crate::types::builtin::RangeIndex::TOP,
            ))
    }) else {
        return;
    };
    let Some(token) = uses.effects.get(index) else {
        return;
    };
    let module = ctx
        .decls
        .binding(owner)
        .and_then(|id| ctx.decls.resolved.bindings.get(id))
        .map(|b| b.module);
    let names = shown_effects(ctx, &actual, module);
    let replacement = actual
        .names
        .iter()
        .filter(|name| !file_effects.names.contains(name))
        .filter(|name| {
            !uses.effects.iter().any(|e| {
                e.id != token.id
                    && ctx
                        .decls
                        .reference(e.id)
                        .and_then(|id| ctx.decls.effect_name(id))
                        == Some((*name).clone())
            })
        })
        .map(|name| effect_name(ctx, name, module))
        .chain(actual.vars.iter().filter_map(|v| {
            // すでに uses にある変数は残し、未宣言の変数は修正案にも含める。
            // 本体にエフェクトの誤りがあっても、生じた集合を示す（設計書 02-05「警告」）。
            if uses.effects.iter().any(|e| {
                ctx.decls
                    .reference(e.id)
                    .and_then(|id| ctx.scope.effects.get(id))
                    == Some(&v.0)
            }) {
                return None;
            }
            usize::try_from(v.0)
                .ok()
                .and_then(|i| ctx.scheme.effect_params.get(i))
                .cloned()
        }))
        .collect::<Vec<_>>()
        .join(", ");
    let (span, key) = if replacement.is_empty() {
        (
            removal(&uses, index),
            if !actual.is_empty() {
                "covered"
            } else {
                "remove"
            },
        )
    } else {
        (token.span, "narrow")
    };
    ctx.diagnostic(
        DiagBuilder::new(DiagCode::W0501)
            .primary(token.span)
            .arg("effects", names)
            .help_edits(key, vec![Edit { span, replacement }])
            .build(),
    );
}
fn shown_effects(ctx: &Body<'_, '_>, effects: &EffectSet, module: Option<ModuleId>) -> String {
    effects
        .names
        .iter()
        .map(|n| effect_name(ctx, n, module))
        .chain(effects.vars.iter().filter_map(|v| {
            usize::try_from(v.0)
                .ok()
                .and_then(|i| ctx.scheme.effect_params.get(i))
                .cloned()
        }))
        .collect::<Vec<_>>()
        .join(", ")
}
/// 診断の位置のモジュールで解決できるエフェクトの名前（設計書 02-10「修正案」）。
pub(in crate::typeck) fn effect_name(
    ctx: &Body<'_, '_>,
    name: &EffectName,
    module: Option<ModuleId>,
) -> String {
    format!(
        "{}{}",
        effect_base_name(ctx, name, module),
        name.index().suffix()
    )
}

fn effect_base_name(ctx: &Body<'_, '_>, name: &EffectName, module: Option<ModuleId>) -> String {
    // 修正案も取り込み時の別名を使う。関数名の表記からエフェクトを推測しない
    // （設計書 01-03「修飾された名前の解決」、02-10「修正案」）。
    let (target, name, fallback) = match name {
        EffectName::Builtin(b, _) => {
            let Some(def) = b.def() else {
                return String::new();
            };
            if def.module.is_empty() {
                return def.name.into();
            }
            if def.module.last().copied() == Some(def.name) {
                let shadowed = module.is_some_and(|module| {
                    ctx.decls.resolved.bindings.iter().any(|(id, binding)| {
                        binding.module == module
                            && binding.name == def.name
                            && if let crate::resolve::BindingKind::Module(target) = binding.kind {
                                ctx.decls.modules.get(target).is_none_or(|m| {
                                    m.name
                                        .0
                                        .iter()
                                        .map(String::as_str)
                                        .ne(std::iter::once("Benitoite")
                                            .chain(def.module.iter().copied()))
                                })
                            } else {
                                !matches!(
                                    ctx.decls.effect_name(id),
                                    Some(EffectName::Builtin(other, _)) if other == *b
                                )
                            }
                    })
                });
                return if shadowed {
                    format!("Benitoite.{}", def.module.join("."))
                } else {
                    def.name.into()
                };
            }
            let target = ctx
                .decls
                .modules
                .modules
                .iter()
                .find(|m| {
                    m.name
                        .0
                        .iter()
                        .skip(1)
                        .map(String::as_str)
                        .eq(def.module.iter().copied())
                })
                .map(|m| m.id);
            (
                target,
                def.name.to_string(),
                format!("{}.{}", def.module.last().copied().unwrap_or(""), def.name),
            )
        }
        EffectName::User(id, _) => {
            let Some(b) = ctx.decls.resolved.bindings.get(*id) else {
                return String::new();
            };
            (Some(b.module), b.name.clone(), b.name.clone())
        }
    };
    if target == module {
        return name;
    }
    if let Some(module) = module.and_then(|id| ctx.decls.modules.get(id)) {
        for import in &module.imports {
            if import.target != target {
                continue;
            }
            if let Some(ast) = usize::try_from(module.id.0)
                .ok()
                .and_then(|i| ctx.decls.asts.get(i))
                && let Some(i) = ast.imports.iter().find(|i| i.id == import.decl)
                && let Some(alias) = i.alias.as_ref().or_else(|| i.path.last())
            {
                return format!("{}.{name}", alias.text);
            }
        }
    }
    fallback
}
