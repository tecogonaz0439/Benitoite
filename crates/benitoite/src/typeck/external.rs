//! 外部の宣言のエフェクトを確定した型で検査する（設計書 02-05「宣言の検査」、03-10「型の対応」）。

use super::{decls::Decls, text};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::resolve::ResolveOutput;
use crate::syntax::ast::{FnDecl, Item};
use crate::types::builtin::BuiltinTypeId as B;
use crate::types::{AdtTable, EffectName, Ty, TyCon, builtin::BuiltinEffectId};

pub(super) fn check(d: &mut Decls<'_>) {
    let mut expansion_remaining = 1_000_000;
    // 後方のレコードと直和型の欄も揃ってから検査し、呼び出し側の検査に先立って報告する。
    for ast in d.asts {
        for top in &ast.decls {
            let Item::Fn(f) = &top.item else { continue };
            let Some(binding) = d.binding(f.id) else {
                continue;
            };
            if d.invalid.contains(&binding) || d.resolved.externals.get(binding).is_none() {
                continue;
            }
            let Some(scheme) = d.out.decl_types.get(binding) else {
                continue;
            };
            let Some(external) = contains_external(
                scheme
                    .params
                    .iter()
                    .chain((!is_unit(&scheme.ret)).then_some(&scheme.ret)),
                d.resolved,
                &d.out.adts,
                &mut expansion_remaining,
            ) else {
                // 循環や予算切れでは途中の結果で State を判定せず、境界の照合で根の E1010 を報告する。
                continue;
            };
            let state = scheme.effects.failures.is_empty()
                && scheme.effects.vars.is_empty()
                && scheme.effects.names.as_slice() == [EffectName::Builtin(BuiltinEffectId::STATE)];
            if external && !state || !external && (f.uses.is_some() || !scheme.effects.is_empty()) {
                let file_origin = d.out.effective_effects.get(binding).and_then(|effective| {
                    effective.origins.iter().find(|origin| {
                        origin.file
                            && (!external
                                || !origin.effects.failures.is_empty()
                                || origin.effects.names.iter().any(|name| {
                                    *name != EffectName::Builtin(BuiltinEffectId::STATE)
                                }))
                    })
                });
                let diagnostic = if let Some(origin) = file_origin {
                    DiagBuilder::new(DiagCode::E0812)
                        .primary(origin.span)
                        .note("pure")
                        .help("file")
                        .build()
                } else {
                    external_effect_error(f, external)
                };
                d.diagnostics.push(diagnostic);
            }
        }
    }
}

fn contains_external<'a>(
    types: impl Iterator<Item = &'a Ty>,
    resolved: &ResolveOutput,
    adts: &'a AdtTable,
    total: &mut usize,
) -> Option<bool> {
    let mut external = false;
    for ty in types {
        crate::external::expansion::walk(ty, resolved, adts, total, |ty, visit| {
            if matches!(visit, crate::external::expansion::Visit::Enter)
                && matches!(ty, Ty::Con(TyCon::External(_), _))
            {
                external = true;
            }
            Ok::<_, std::convert::Infallible>(())
        })
        .ok()?;
    }
    Some(external)
}

fn is_unit(ty: &Ty) -> bool {
    matches!(ty, Ty::Con(TyCon::Builtin(B::UNIT), args) if args.is_empty())
}

fn external_effect_error(f: &FnDecl, external: bool) -> Diagnostic {
    if let Some(uses) = &f.uses {
        DiagBuilder::new(DiagCode::E0812)
            .primary(uses.span)
            .note("pure")
            .help_edits(
                if external { "state" } else { "remove" },
                vec![crate::diag::Edit {
                    span: uses.span,
                    replacement: if external {
                        text::USES_STATE.trim().into()
                    } else {
                        String::new()
                    },
                }],
            )
            .build()
    } else {
        let end = f.ret.span();
        DiagBuilder::new(DiagCode::E0816)
            .arg("name", &f.name.text)
            .primary(end)
            .help_edits(
                "state",
                vec![crate::diag::Edit {
                    span: Span {
                        start: end.end,
                        end: end.end,
                        ..end
                    },
                    replacement: text::USES_STATE.into(),
                }],
            )
            .build()
    }
}
