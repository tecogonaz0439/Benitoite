//! 型の確定後に辞書を解く。実装の上位の辞書も同じ手順を使う（設計書 02-05「型クラスの制約の解決」）。
use super::{class_name, collect::show, constraint_name, parameter_edit};
use crate::base::{BindingId, ModuleId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::typeck::{
    body_map::BodyNodeMap,
    context::Body,
    decls::{Decls, Scope},
    infer::*,
    limits::MAX_DICT_WORK,
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
    Limit,
}
fn path(d: &Decls<'_>, solver: &Solver, from: BindingId, to: BindingId) -> Option<Vec<BindingId>> {
    let key = (from, to);
    if let Some(path) = solver.superclass_paths.borrow().get(&key) {
        return path.clone();
    }
    let result = uncached_path(d, from, to);
    solver
        .superclass_paths
        .borrow_mut()
        .insert(key, result.clone());
    result
}
fn uncached_path(d: &Decls<'_>, from: BindingId, to: BindingId) -> Option<Vec<BindingId>> {
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
    parts: &mut usize,
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
    resolve_normalized(d, solver, scheme, table, class, &normalized, parts)
}

// 親で正規化済みの型の部分を子へ渡し、子では再び zonk しない。
fn resolve_normalized(
    d: &Decls<'_>,
    solver: &Solver,
    scheme: &Scheme,
    table: &ImplTable,
    class: BindingId,
    normalized: &IClassArg,
    parts: &mut usize,
) -> Result<Resolution, Failure> {
    // 子と同じ数えを使うことで、指数的に増える子も一つの辞書の予算に含める
    // （設計書 02-05「型クラスの制約の解決」）。
    charge(parts, 1)?;
    let parameter = match normalized {
        IClassArg::Ty(ITy::Param(i)) | IClassArg::Head(IHead::Param(i)) => Some(*i),
        IClassArg::Ty(_) | IClassArg::Con(_) | IClassArg::Head(IHead::Var(_)) => None,
    };
    if let Some(index) = parameter {
        let mut best: Option<(usize, Vec<BindingId>)> = None;
        for (i, c) in scheme.class_constraints.iter().enumerate() {
            if c.param == index
                && let Some(path) = path(d, solver, c.class, class)
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
    if let IClassArg::Ty(ITy::Rigid { clause, index }) = normalized {
        let mut best: Option<(usize, Vec<BindingId>)> = None;
        if let Some(constraints) = solver.clause_constraints.get(clause) {
            for (i, c) in constraints.iter().enumerate() {
                if c.param == *index
                    && let Some(path) = path(d, solver, c.class, class)
                    && best.as_ref().is_none_or(|(_, old)| path.len() < old.len())
                {
                    best = Some((i, path));
                }
            }
        }
        return best
            .map(|(i, supers)| Resolution {
                dict: DictExpr::Clause {
                    clause: *clause,
                    constraint: u32::try_from(i).unwrap_or(u32::MAX),
                    supers,
                },
                bounds: vec![],
            })
            .ok_or_else(|| Failure::Missing {
                class,
                arg: normalized.clone(),
            });
    }
    if matches!(
        normalized,
        IClassArg::Ty(ITy::Var(_)) | IClassArg::Head(IHead::Var(_))
    ) {
        return Err(Failure::Unknown(normalized.clone()));
    }
    let (con, args) = match normalized {
        IClassArg::Ty(ITy::Con(c, args)) => (*c, args.as_slice()),
        IClassArg::Con(c) => (*c, &[][..]),
        IClassArg::Ty(_) | IClassArg::Head(_) => {
            if d.invalid_impl_targets.contains(&class) {
                return Err(Failure::Suppressed);
            }
            return Err(Failure::Missing {
                class,
                arg: normalized.clone(),
            });
        }
    };
    let Some(id) = table.get(&(class, con)) else {
        return Err(Failure::Missing {
            class,
            arg: normalized.clone(),
        });
    };
    let Some(i) = d.out.impls.get(*id) else {
        return Err(Failure::Suppressed);
    };
    // 型の数えは TypeBudget と同じく Con/App と Fn の引数・戻り値を一節ずつ数える。
    // 写す前に予算を検査し、大きな型を持つ辞書も止める。
    if let TypeArg::Ty(Ty::Con(_, params)) = &i.target {
        for (_, ty) in params.iter().zip(args) {
            charge_type(parts, ty)?;
        }
        charge(parts, i.type_params.len().saturating_sub(args.len()))?;
    } else {
        charge(parts, i.type_params.len())?;
    }
    let mut type_args = vec![TypeArg::Ty(crate::typeck::decls::unit()); i.type_params.len()];
    let mut infer_args = vec![ITy::Error; i.type_params.len()];
    // 対象は引数の順が宣言の順とは限らない（Pair[B, A]）。対象の Param の番号で置き換える。
    if let TypeArg::Ty(Ty::Con(_, params)) = &i.target {
        for (p, t) in params.iter().zip(args) {
            if let Ty::Param(index) = p
                && let Ok(index) = usize::try_from(*index)
                && let (Some(out), Some(infer)) =
                    (type_args.get_mut(index), infer_args.get_mut(index))
            {
                *out = TypeArg::Ty(finalize_normalized(solver, t, d.resolved));
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
            let child = resolve_normalized(
                d,
                solver,
                scheme,
                table,
                c.class,
                &IClassArg::Ty(t.clone()),
                parts,
            )?;
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

fn charge(parts: &mut usize, amount: usize) -> Result<(), Failure> {
    *parts = parts.saturating_add(amount);
    if *parts > MAX_DICT_WORK {
        return Err(Failure::Limit);
    }
    Ok(())
}

fn charge_type(parts: &mut usize, ty: &ITy) -> Result<(), Failure> {
    let mut pending = vec![ty];
    while let Some(ty) = pending.pop() {
        charge(parts, 1)?;
        match ty {
            ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
            ITy::Fn(f) => {
                pending.extend(&f.effect.failures);
                pending.extend(&f.params);
                pending.push(&f.ret);
            }
            ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
        }
    }
    Ok(())
}

// 正規化済みの型を一度だけたどる。未確定の変数・頭・エフェクトの扱いは
// Solver::finalize と同じにする（設計書 02-05「型クラスの制約の解決」）。
fn finalize_normalized(solver: &Solver, ty: &ITy, r: &crate::resolve::ResolveOutput) -> Ty {
    match ty {
        ITy::Var(_) | ITy::Error => crate::typeck::decls::unit(),
        ITy::Con(c, args) => Ty::Con(
            *c,
            args.iter()
                .map(|t| finalize_normalized(solver, t, r))
                .collect(),
        ),
        ITy::App(h, args) => {
            let args = args
                .iter()
                .map(|t| finalize_normalized(solver, t, r))
                .collect();
            match solver.finalize_head(*h, r) {
                TyHead::Con(c) => Ty::Con(c, args),
                TyHead::Param(i) => Ty::App(i, args),
            }
        }
        ITy::Fn(_) if solver.invalid_contract(ty) => crate::typeck::decls::unit(),
        ITy::Fn(f) => Ty::Fn(Box::new(FnTy {
            param_names: solver.contract_names(&f.contract).unwrap_or_default(),
            params: f
                .params
                .iter()
                .map(|t| finalize_normalized(solver, t, r))
                .collect(),
            ret: finalize_normalized(solver, &f.ret, r),
            effects: solver.finalize_effect(&f.effect),
        })),
        ITy::Param(i) => Ty::Param(*i),
        ITy::Rigid { clause, index } => Ty::Rigid {
            clause: *clause,
            index: *index,
        },
    }
}

// 補助の検査でも節の型パラメータと診断の操作名を保つ（設計書 02-05「型クラスの制約の解決」）。
pub(super) type ClauseBounds<'a> = (
    &'a BodyNodeMap<Vec<TypeParamInfo>>,
    &'a BodyNodeMap<(String, Span)>,
);

pub(super) fn check_bounds(
    d: &mut Decls<'_>,
    module: ModuleId,
    scope: &Scope,
    scheme: &Scheme,
    resolution: &Resolution,
    reason: &Reason,
    clauses: Option<ClauseBounds<'_>>,
) -> Vec<Diagnostic> {
    if resolution.bounds.is_empty() {
        return vec![];
    }
    // 解決済みの型について等値・鍵・集まりの判定を再利用する。本体のエフェクトの
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
    let mut body = Body::new(d, module, scope.clone(), scheme.clone());
    if let Some((params, ops)) = clauses {
        body.clause_params = params.clone();
        body.clause_ops = ops.clone();
    }
    Solver::default().solve(&mut body, constraints);
    body.diagnostics
}
// 辞書の型引数も、既定値を選ぶ前に確定を待つ。外側の構成子が既知でも、
// 内側の変数や契約が未確定なら部分的な辞書を保存しない（設計書 02-05「型クラスの制約の解決」）。
fn unresolved_argument(solver: &Solver, arg: &IClassArg) -> bool {
    let ty = match arg {
        IClassArg::Ty(t) => solver.zonk(t),
        IClassArg::Head(h) => solver.zonk(&ITy::App(*h, vec![])),
        IClassArg::Con(_) => return false,
    };
    let mut pending = vec![ty];
    while let Some(ty) = pending.pop() {
        match ty {
            ITy::Var(_) | ITy::App(IHead::Var(_), _) => return true,
            ITy::Fn(f) => {
                if matches!(solver.resolve_contract(&f.contract), IContract::Var(_)) {
                    return true;
                }
                pending.extend(solver.failure_types(&f.effect));
                pending.extend(f.params);
                pending.push(f.ret);
            }
            ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
            ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
        }
    }
    false
}

pub(super) fn solve_classes(ctx: &mut Body<'_, '_>, final_pass: bool) {
    let table = table(ctx.decls);
    let mut waiting_uses = BTreeSet::new();
    let constraints = std::mem::take(&mut ctx.constraints)
        .into_iter()
        .map(|c| {
            let unknown = if !final_pass && let Constraint::Class { arg, site, .. } = &c {
                let unknown = unresolved_argument(&ctx.solver, arg);
                if unknown && let DictSite::Use { node, .. } = site {
                    waiting_uses.insert(*node);
                }
                unknown
            } else {
                false
            };
            (c, unknown)
        })
        .collect::<Vec<_>>();
    let mut uses: BTreeMap<NodeId, BTreeMap<u32, DictExpr>> = BTreeMap::new();
    let mut limited_uses = BTreeSet::new();
    for (c, unknown) in constraints {
        // 一つの使用の辞書の一部だけを確定すると番号が欠けるので、未知の
        // 制約を持つ使用は全体を最終検査まで保留する（設計書 02-05「型クラスの制約の解決」）。
        if !final_pass
            && (unknown
                || matches!(&c, Constraint::Class { site: DictSite::Use { node, .. }, .. } if waiting_uses.contains(node)))
        {
            ctx.add(c);
            continue;
        }
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
        if let DictSite::Use { node, .. } = site
            && limited_uses.contains(&node)
        {
            continue;
        }
        let mut parts = 0;
        let dict = match resolve(
            ctx.decls,
            &ctx.solver,
            &ctx.scheme,
            &table,
            class,
            &arg,
            &mut parts,
        ) {
            Ok(resolution) => {
                let diagnostics = check_bounds(
                    ctx.decls,
                    ctx.module,
                    &ctx.scope,
                    &ctx.scheme,
                    &resolution,
                    &reason,
                    Some((&ctx.clause_params, &ctx.clause_ops)),
                );
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
                if matches!(failure, Failure::Limit)
                    && let DictSite::Use { node, .. } = site
                {
                    limited_uses.insert(node);
                }
                report(ctx, failure, class, &arg, &reason);
                continue;
            }
        };
        match site {
            DictSite::DieShow { node } => {
                ctx.die_shows.insert(node, dict);
            }
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
fn argument_ty(ctx: &Body<'_, '_>, arg: &IClassArg) -> Ty {
    match arg {
        IClassArg::Ty(t) => ctx.solver.finalize(t, ctx.decls.resolved),
        IClassArg::Con(c) => Ty::Con(*c, vec![]),
        IClassArg::Head(h) => Ty::App(
            match ctx.solver.finalize_head(*h, ctx.decls.resolved) {
                TyHead::Param(i) => i,
                TyHead::Con(_) => 0,
            },
            vec![],
        ),
    }
}
fn show_argument(ctx: &Body<'_, '_>, arg: &IClassArg) -> String {
    match arg {
        IClassArg::Ty(ty) => ctx.show_type(ty),
        IClassArg::Con(_) | IClassArg::Head(_) => {
            show(ctx.decls, &ctx.scheme, &argument_ty(ctx, arg))
        }
    }
}
fn report(ctx: &mut Body<'_, '_>, failure: Failure, class: BindingId, arg: &IClassArg, r: &Reason) {
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
        Failure::Missing { class, arg } => DiagBuilder::new(DiagCode::E0705)
            .primary(r.span)
            .arg("trait_name", class_name(ctx.decls, class))
            .arg("ty", show_argument(ctx, &arg))
            .build(),
        Failure::Limit => DiagBuilder::new(DiagCode::E0715)
            .primary(r.span)
            .arg("trait_name", class_name(ctx.decls, class))
            .arg("ty", show_argument(ctx, arg))
            .arg("limit", MAX_DICT_WORK.to_string())
            .help("reduce")
            .build(),
        Failure::Suppressed => return,
    };
    let mut diag = diag;
    if r.kind == ReasonKind::Try && matches!(diag.code, Some(DiagCode::E0705 | DiagCode::E0706)) {
        let help = DiagBuilder::new(diag.code.unwrap_or(DiagCode::E0705))
            .help("die_show")
            .build();
        diag.helps.extend(help.helps);
    }
    ctx.diagnostic(diag);
}
