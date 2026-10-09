//! 実装の形・一貫性・上位の辞書・メソッドの型を検査する（設計書 02-05「実装の検査」）。
use super::{class_name, collect::show, solve};
use crate::base::{BindingId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{ImplDecl, Item};
use crate::typeck::{
    context::{lift, reason},
    decls::{Decls, scheme, unit},
    infer::{IClassArg, ReasonKind},
    solve::Solver,
};
use crate::types::*;
use std::collections::{BTreeMap, BTreeSet};

pub(super) fn invalid(d: &Decls<'_>, i: &ImplDef) -> bool {
    d.invalid.contains(&i.class) || i.methods.iter().any(|m| d.invalid.contains(m))
}
fn mark(d: &mut Decls<'_>, i: &ImplDef) {
    for m in &i.methods {
        d.invalid.insert(*m);
    }
}
fn head_scheme(i: &ImplDef) -> Scheme {
    let mut s = scheme(vec![], unit());
    s.type_params = i.type_params.clone();
    s.class_constraints = i.class_constraints.clone();
    s
}
fn target_ty(i: &ImplDef) -> Ty {
    match &i.target {
        TypeArg::Ty(t) => t.clone(),
        TypeArg::Head(TyHead::Con(c)) => Ty::Con(*c, vec![]),
        TypeArg::Head(TyHead::Param(i)) => Ty::App(*i, vec![]),
    }
}
pub(super) fn check(d: &mut Decls<'_>) {
    let mut seen = BTreeMap::new();
    // 頭部が全て揃ってから上位の実装を解くので、宣言の前後は実装の選択に影響しない。
    for ast in d.asts {
        for top in &ast.decls {
            if let Item::Impl(source) = &top.item
                && let Some(i) = d.out.impls.get(source.id).cloned()
            {
                let before = d.diagnostics.len();
                if !invalid(d, &i) {
                    check_shape(d, source, &i);
                }
                let s = head_scheme(&i);
                let ty = show(d, &s, &target_ty(&i));
                let class = class_name(d, i.class);
                if !invalid(d, &i) && d.diagnostics.len() == before {
                    let class_module = d.resolved.bindings.get(i.class).map(|b| b.module);
                    let type_module = match i.target_con {
                        TyCon::Adt(id) => d.resolved.bindings.get(id).map(|b| b.module),
                        TyCon::Builtin(id) => id.def().and_then(|b| {
                            d.modules
                                .modules
                                .iter()
                                .find(|m| {
                                    m.name
                                        .0
                                        .iter()
                                        .map(String::as_str)
                                        .eq(std::iter::once("Benitoite")
                                            .chain(b.module.iter().copied()))
                                })
                                .map(|m| m.id)
                        }),
                    };
                    if Some(i.module) != class_module && Some(i.module) != type_module {
                        let mut diag = DiagBuilder::new(DiagCode::E0701)
                            .arg("trait_name", &class)
                            .arg("ty", &ty)
                            .primary(source.span);
                        if let Some(span) = d.resolved.bindings.get(i.class).and_then(|b| b.span) {
                            diag = diag.secondary(span, "trait_decl");
                        }
                        if let TyCon::Adt(id) = i.target_con
                            && let Some(span) = d.resolved.bindings.get(id).and_then(|b| b.span)
                        {
                            diag = diag.secondary(span, "type_decl");
                        }
                        d.diagnostics.push(diag.build());
                    }
                }
                // 型構成子を決められない対象には表の鍵を作らない。出力の仮の target_con を
                // 本物の Unit の実装と比較すると、対象の誤りから重なりの診断が派生する（ADR 0024）。
                if let Some(con) = solve::target_con(&i) {
                    if let Some(span) = seen.get(&(i.class, con)) {
                        d.diagnostics.push(
                            DiagBuilder::new(DiagCode::E0702)
                                .arg("trait_name", &class)
                                .arg("ty", &ty)
                                .primary(source.span)
                                .secondary(*span, "other")
                                .build(),
                        );
                    } else {
                        seen.insert((i.class, con), source.span);
                    }
                }
                if before != d.diagnostics.len() {
                    mark(d, &i);
                }
            }
        }
    }
    let table = solve::table(d);
    for ast in d.asts {
        for top in &ast.decls {
            if let Item::Impl(source) = &top.item
                && let Some(mut i) = d.out.impls.get(source.id).cloned()
                && !invalid(d, &i)
            {
                let before = d.diagnostics.len();
                let s = head_scheme(&i);
                if let Some(t) = d.out.traits.get(i.class).cloned() {
                    let arg = match &i.target {
                        TypeArg::Ty(t) => IClassArg::Ty(lift(t)),
                        TypeArg::Head(TyHead::Con(c)) => IClassArg::Con(*c),
                        TypeArg::Head(TyHead::Param(p)) => {
                            IClassArg::Head(crate::typeck::infer::IHead::Param(*p))
                        }
                    };
                    for sup in t.supers {
                        let resolution =
                            solve::resolve(d, &Solver::default(), &s, &table, sup, &arg);
                        let r = reason(source.span, ReasonKind::ImplSuper { class: sup });
                        let scope = d.scopes.get(&source.id).cloned().unwrap_or_default();
                        let dict = resolution.ok().and_then(|resolution| {
                            solve::check_bounds(d, &scope, &s, &resolution, &r)
                                .is_empty()
                                .then_some(resolution.dict)
                        });
                        if let Some(dict) = dict {
                            i.supers.push(dict);
                        } else {
                            d.diagnostics.push(
                                DiagBuilder::new(DiagCode::E0704)
                                    .arg("trait_name", &t.name)
                                    .arg("supertrait", class_name(d, sup))
                                    .arg("ty", show(d, &s, &target_ty(&i)))
                                    .primary(source.span)
                                    .build(),
                            );
                        }
                    }
                    check_methods(d, source, &i);
                }
                d.out.impls.insert(i.decl, i.clone());
                if before != d.diagnostics.len() {
                    mark(d, &i);
                }
            }
        }
    }
}
fn check_shape(d: &mut Decls<'_>, source: &ImplDecl, i: &ImplDef) {
    let mut used = BTreeSet::new();
    let valid = match &i.target {
        TypeArg::Ty(Ty::Con(_, args)) => args.iter().all(|t| {
            if let Ty::Param(p) = t {
                used.insert(*p)
            } else {
                false
            }
        }),
        TypeArg::Head(TyHead::Con(_)) => true,
        TypeArg::Ty(_) | TypeArg::Head(TyHead::Param(_)) => false,
    };
    if !valid {
        d.diagnostics.push(
            DiagBuilder::new(DiagCode::E0712)
                .arg("ty", show(d, &head_scheme(i), &target_ty(i)))
                .primary(source.target.span())
                .help("form")
                .build(),
        );
        return;
    }
    for (index, (_, decl)) in i.type_params.iter().zip(&source.type_params).enumerate() {
        if !used.contains(&u32::try_from(index).unwrap_or(u32::MAX)) {
            d.diagnostics.push(
                DiagBuilder::new(DiagCode::E0713)
                    .arg("param", &decl.name.text)
                    .primary(decl.name.span)
                    .build(),
            );
        }
    }
}
fn check_methods(d: &mut Decls<'_>, source: &ImplDecl, i: &ImplDef) {
    let Some(t) = d.out.traits.get(i.class).cloned() else {
        return;
    };
    for (method, implementation) in t.methods.iter().zip(&i.methods) {
        if d.invalid.contains(method) || d.invalid.contains(implementation) {
            continue;
        }
        let Some(expected) = d.out.decl_types.get(*method).cloned() else {
            continue;
        };
        let Some(found) = d.out.decl_types.get(*implementation).cloned() else {
            continue;
        };
        let offset = u32::try_from(i.type_params.len()).unwrap_or(u32::MAX);
        let mut args = vec![i.target.clone()];
        for (j, p) in expected.type_params.iter().skip(1).enumerate() {
            let index = offset.saturating_add(u32::try_from(j).unwrap_or(u32::MAX));
            args.push(match p.kind {
                ParamKind::Value => TypeArg::Ty(Ty::Param(index)),
                ParamKind::Ctor { .. } => TypeArg::Head(TyHead::Param(index)),
            });
        }
        let params: Vec<_> = expected
            .params
            .iter()
            .map(|t| t.subst(&args, &[]))
            .collect();
        let ret = expected.ret.subst(&args, &[]);
        let constraints: Vec<_> = expected
            .class_constraints
            .iter()
            .skip(1)
            .map(|c| ClassConstraint {
                param: offset.saturating_add(c.param.saturating_sub(1)),
                class: c.class,
            })
            .collect();
        let own = found.type_params.iter().skip(i.type_params.len());
        let expected_own = expected.type_params.iter().skip(1);
        let same_params = own.clone().count() == expected_own.clone().count()
            && own
                .zip(expected_own)
                .all(|(a, b)| a.kind == b.kind && a.builtin == b.builtin);
        let same_constraints = found
            .class_constraints
            .iter()
            .skip(i.class_constraints.len())
            .copied()
            .collect::<Vec<_>>()
            == constraints;
        let valid = same_params
            && same_constraints
            && found.effect_params.len() == expected.effect_params.len()
            && params == found.params
            && ret == found.ret
            && found.effects.is_subset(&expected.effects);
        if !valid {
            let span = source
                .fns
                .iter()
                .find(|f| d.binding(f.decl.id) == Some(*implementation))
                .map_or(source.span, |f| f.decl.name.span);
            let expected_ty = Ty::Fn(Box::new(FnTy {
                params,
                ret,
                effects: expected.effects,
            }));
            let mut diag = DiagBuilder::new(DiagCode::E0711)
                .arg("name", class_name(d, *method))
                .arg("trait_name", &t.name)
                .arg("expected", show(d, &found, &expected_ty))
                .arg("found", show(d, &found, &found.fn_ty()))
                .primary(span);
            if let Some(declared) = binding_span(d, *method) {
                diag = diag.secondary(declared, "declared");
            }
            d.diagnostics.push(diag.build());
        }
    }
}
fn binding_span(d: &Decls<'_>, id: BindingId) -> Option<Span> {
    d.resolved.bindings.get(id).and_then(|b| b.span)
}
