//! 型の確定後に辞書を解く。実装の上位の辞書も同じ手順を使う（設計書 02-05「型クラスの制約の解決」）。
use super::{class_name, collect::show, constraint_name, parameter_edit};
use crate::base::{BindingId, NodeId};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::typeck::{
    context::Body,
    decls::{Decls, Scope},
    infer::*,
    solve::Solver,
};
use crate::types::*;
use std::collections::{BTreeMap, BTreeSet, VecDeque};

pub(super) type ImplTable = BTreeMap<(BindingId, TyCon), NodeId>;
pub(super) fn target_con(i: &ImplDef) -> Option<TyCon> {
    match &i.target {
        TypeArg::Ty(Ty::Con(c, _)) | TypeArg::Head(TyHead::Con(c)) => Some(*c),
        TypeArg::Ty(_) | TypeArg::Head(TyHead::Param(_)) => None,
    }
}
pub(super) fn table(d: &Decls<'_>) -> ImplTable {
    let mut out = BTreeMap::new();
    for (id, i) in d.out.impls.iter() {
        if let Some(con) = target_con(i) {
            out.entry((i.class, con)).or_insert(id);
        }
    }
    out
}
/// 辞書を持たない組み込みの制約も、実装を選ぶ際には検査する（設計書 01-06「組み込みの制約（初回リリース版）」）。
pub(super) struct Resolution {
    pub dict: DictExpr,
    bounds: Vec<(ITy, BuiltinConstraint)>,
}
pub(super) enum Failure {
    Unknown(IClassArg),
    Parameter { class: BindingId, index: u32 },
    Missing { class: BindingId, arg: IClassArg },
    Suppressed,
}
fn path(d: &Decls<'_>, from: BindingId, to: BindingId) -> Option<Vec<BindingId>> {
    let mut pending = VecDeque::from([(from, vec![])]);
    let mut seen = BTreeSet::new();
    while let Some((class, path)) = pending.pop_front() {
        if class == to {
            return Some(path);
        }
        if !seen.insert(class) {
            continue;
        }
        if let Some(t) = d.out.traits.get(class) {
            for s in &t.supers {
                let mut next = path.clone();
                next.push(*s);
                pending.push_back((*s, next));
            }
        }
    }
    None
}
pub(super) fn resolve(
    d: &Decls<'_>,
    solver: &Solver,
    scheme: &Scheme,
    table: &ImplTable,
    class: BindingId,
    arg: &IClassArg,
) -> Result<Resolution, Failure> {
    let normalized = match arg {
        IClassArg::Ty(t) => {
            if solver.contains_error(t) {
                return Err(Failure::Suppressed);
            }
            IClassArg::Ty(solver.zonk(t))
        }
        IClassArg::Con(c) => IClassArg::Con(*c),
        IClassArg::Head(h) => {
            if let IHead::Var(v) = h
                && solver.contains_error(&ITy::Var(*v))
            {
                return Err(Failure::Suppressed);
            }
            // 空の適用で頭だけを置き換える。finalize_head の既定値を解決前に選ばない。
            match solver.zonk(&ITy::App(*h, vec![])) {
                ITy::Con(c, _) => IClassArg::Con(c),
                ITy::App(h, _) => IClassArg::Head(h),
                ITy::Var(_) | ITy::Fn(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {
                    return Err(Failure::Suppressed);
                }
            }
        }
    };
    let parameter = match &normalized {
        IClassArg::Ty(ITy::Param(i)) | IClassArg::Head(IHead::Param(i)) => Some(*i),
        IClassArg::Ty(_) | IClassArg::Con(_) | IClassArg::Head(IHead::Var(_)) => None,
    };
    if let Some(index) = parameter {
        let mut best: Option<(usize, Vec<BindingId>)> = None;
        for (i, c) in scheme.class_constraints.iter().enumerate() {
            if c.param == index
                && let Some(path) = path(d, c.class, class)
                && best.as_ref().is_none_or(|(_, old)| path.len() < old.len())
            {
                best = Some((i, path));
            }
        }
        return best
            .map(|(i, supers)| Resolution {
                dict: DictExpr::Param {
                    constraint: u32::try_from(i).unwrap_or(u32::MAX),
                    supers,
                },
                bounds: vec![],
            })
            .ok_or(Failure::Parameter { class, index });
    }
    if matches!(
        normalized,
        IClassArg::Ty(ITy::Var(_)) | IClassArg::Head(IHead::Var(_))
    ) {
        return Err(Failure::Unknown(normalized));
    }
    let (con, args) = match &normalized {
        IClassArg::Ty(ITy::Con(c, args)) => (*c, args.clone()),
        IClassArg::Con(c) => (*c, vec![]),
        IClassArg::Ty(_) | IClassArg::Head(_) => {
            return Err(Failure::Missing {
                class,
                arg: normalized,
            });
        }
    };
    let Some(id) = table.get(&(class, con)) else {
        return Err(Failure::Missing {
            class,
            arg: normalized,
        });
    };
    let Some(i) = d.out.impls.get(*id) else {
        return Err(Failure::Suppressed);
    };
    let mut type_args = vec![TypeArg::Ty(crate::typeck::decls::unit()); i.type_params.len()];
    let mut infer_args = vec![ITy::Error; i.type_params.len()];
    // 対象は引数の順が宣言の順とは限らない（Pair[B, A]）。対象の Param の番号で置き換える。
    if let TypeArg::Ty(Ty::Con(_, params)) = &i.target {
        for (p, t) in params.iter().zip(&args) {
            if let Ty::Param(index) = p
                && let Ok(index) = usize::try_from(*index)
                && let (Some(out), Some(infer)) =
                    (type_args.get_mut(index), infer_args.get_mut(index))
            {
                *out = TypeArg::Ty(solver.finalize(t, d.resolved));
                *infer = t.clone();
            }
        }
    }
    // 誤りのある実装は表に残し、その実装を使うたびに子の制約の誤りを繰り返さない（02-05「誤りの報告と検査の継続」）。
    let invalid = super::impls::invalid(d, i);
    let mut dicts = vec![];
    let mut bounds = vec![];
    if !invalid {
        for (p, ty) in i.type_params.iter().zip(&infer_args) {
            if let Some(bound) = p.builtin {
                bounds.push((ty.clone(), bound));
            }
        }
        for c in &i.class_constraints {
            let Some(t) = usize::try_from(c.param)
                .ok()
                .and_then(|i| infer_args.get(i))
            else {
                return Err(Failure::Suppressed);
            };
            let child = resolve(d, solver, scheme, table, c.class, &IClassArg::Ty(t.clone()))?;
            dicts.push(child.dict);
            bounds.extend(child.bounds);
        }
    }
    Ok(Resolution {
        dict: DictExpr::Impl {
            impl_decl: *id,
            type_args,
            args: dicts,
        },
        bounds,
    })
}

pub(super) fn check_bounds(
    d: &mut Decls<'_>,
    scope: &Scope,
    scheme: &Scheme,
    resolution: &Resolution,
    reason: &Reason,
) -> Vec<Diagnostic> {
    if resolution.bounds.is_empty() {
        return vec![];
    }
    // 解決済みの型について F07 の等値・鍵・集まりの判定を再利用する。本体のエフェクトの
    // 状態とは分け、既に報告したエフェクトの失敗を繰り返さない（設計書 02-05「制約の解決」）。
    let constraints = resolution
        .bounds
        .iter()
        .map(|(ty, bound)| match bound {
            BuiltinConstraint::Equality => Constraint::Equality {
                ty: ty.clone(),
                reason: reason.clone(),
            },
            BuiltinConstraint::Key => Constraint::Key {
                ty: ty.clone(),
                reason: reason.clone(),
            },
            BuiltinConstraint::Ordered => Constraint::OneOf {
                ty: ty.clone(),
                set: TySet::ORD,
                reason: reason.clone(),
            },
        })
        .collect();
    let mut body = Body::new(d, scope.clone(), scheme.clone());
    Solver::default().solve(&mut body, constraints);
    body.diagnostics
}
pub(super) fn solve_classes(ctx: &mut Body<'_, '_>) {
    let table = table(ctx.decls);
    let constraints = std::mem::take(&mut ctx.constraints);
    let mut uses: BTreeMap<NodeId, BTreeMap<u32, DictExpr>> = BTreeMap::new();
    for c in constraints {
        let Constraint::Class {
            class,
            arg,
            site,
            reason,
        } = c
        else {
            ctx.constraints.push(c);
            continue;
        };
        let dict = match resolve(ctx.decls, &ctx.solver, &ctx.scheme, &table, class, &arg) {
            Ok(resolution) => {
                let diagnostics =
                    check_bounds(ctx.decls, &ctx.scope, &ctx.scheme, &resolution, &reason);
                if !diagnostics.is_empty() {
                    ctx.diagnostics.extend(diagnostics);
                    // 子の制約が型を決められない場合も、同じ型変数の失敗を重ねない（02-05「誤りの報告と検査の継続」）。
                    if let IClassArg::Ty(ty) = &arg {
                        let _poisoned = ctx.solver.equal(ty, &ITy::Error, &reason);
                    }
                    continue;
                }
                resolution.dict
            }
            Err(failure) => {
                report(ctx, failure, &reason);
                continue;
            }
        };
        match site {
            DictSite::Use { node, constraint } => {
                uses.entry(node).or_default().insert(constraint, dict);
            }
            DictSite::ImplSuper { impl_decl, index } => {
                if let Some(mut i) = ctx.decls.out.impls.get(impl_decl).cloned()
                    && usize::try_from(index).ok() == Some(i.supers.len())
                {
                    i.supers.push(dict);
                    ctx.decls.out.impls.insert(impl_decl, i);
                }
            }
        }
    }
    for (node, dicts) in uses {
        let expected = ctx
            .decls
            .reference(node)
            .and_then(|id| ctx.decls.out.decl_types.get(id))
            .map_or(0, |s| s.class_constraints.len());
        // 失敗した制約を詰めると辞書の番号がずれる。成功した使用だけを表に載せる。
        if dicts.len() == expected {
            ctx.decls
                .out
                .dicts
                .insert(node, dicts.into_values().collect());
        }
    }
}
fn report(ctx: &mut Body<'_, '_>, failure: Failure, r: &Reason) {
    let diag = match failure {
        Failure::Unknown(arg) => {
            let ty = match arg {
                IClassArg::Ty(t) => t,
                IClassArg::Head(IHead::Var(v)) => ITy::Var(v),
                IClassArg::Head(IHead::Param(i)) => ITy::Param(i),
                IClassArg::Con(c) => ITy::Con(c, vec![]),
            };
            // 型変数の同じ失敗を重ねず、後の表でも未確定と誤りを区別する（設計書 02-05「誤りの報告と検査の継続」）。
            let result = ctx.solver.equal(&ty, &ITy::Error, r);
            if result.is_err() {
                return;
            }
            DiagBuilder::new(DiagCode::E0407)
                .primary(r.span)
                .help("annotate")
                .build()
        }
        Failure::Parameter { class, index } => {
            let name = usize::try_from(index)
                .ok()
                .and_then(|i| ctx.scheme.type_params.get(i))
                .map_or_else(String::new, |p| p.name.clone());
            let class = constraint_name(ctx, class);
            DiagBuilder::new(DiagCode::E0706)
                .primary(r.span)
                .arg("param", name)
                .arg("trait_name", &class)
                .help_edits("add", parameter_edit(ctx.decls, &ctx.scope, index, &class))
                .build()
        }
        Failure::Missing { class, arg } => {
            let ty = match arg {
                IClassArg::Ty(t) => ctx.solver.finalize(&t, ctx.decls.resolved),
                IClassArg::Con(c) => Ty::Con(c, vec![]),
                IClassArg::Head(h) => Ty::App(
                    match ctx.solver.finalize_head(h, ctx.decls.resolved) {
                        TyHead::Param(i) => i,
                        TyHead::Con(_) => 0,
                    },
                    vec![],
                ),
            };
            DiagBuilder::new(DiagCode::E0705)
                .primary(r.span)
                .arg("trait_name", class_name(ctx.decls, class))
                .arg("ty", show(ctx.decls, &ctx.scheme, &ty))
                .build()
        }
        Failure::Suppressed => return,
    };
    ctx.diagnostic(diag);
}
