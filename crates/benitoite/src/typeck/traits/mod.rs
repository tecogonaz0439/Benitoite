//! 型クラスの宣言・実装と辞書、型パラメータの組み込みの制約を検査する（設計書 02-05）。
mod collect;
mod impls;
mod solve;
mod text;

use super::{
    context::{Body, IArg, reason},
    decls::{Decls, Scope},
    infer::{Constraint, DictSite, IClassArg, IEffect, ITy, Reason, ReasonKind},
};
use crate::base::{BindingId, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::ast::{NameExpr, TypeParamDecl};
use crate::types::{BuiltinConstraint, ParamKind, Scheme, TySet, TypeParamInfo};

pub(super) fn collect(d: &mut Decls<'_>) {
    collect::collect(d);
}
pub(super) fn check_parameters(
    d: &mut Decls<'_>,
    params: &[TypeParamDecl],
    scope: &Scope,
    s: &Scheme,
    allowed: bool,
) {
    collect::check_parameters(d, params, scope, s, allowed);
}
pub(super) fn check_impls(d: &mut Decls<'_>) {
    impls::check(d);
}
pub(super) fn instantiate(
    ctx: &mut Body<'_, '_>,
    node: NodeId,
    span: Span,
    s: &Scheme,
    args: &[IArg],
    _: &[IEffect],
) {
    for (i, c) in s.class_constraints.iter().enumerate() {
        let Some(arg) = usize::try_from(c.param).ok().and_then(|i| args.get(i)) else {
            continue;
        };
        let arg = match arg {
            IArg::Ty(t) => IClassArg::Ty(t.clone()),
            IArg::Head(h) => IClassArg::Head(*h),
        };
        ctx.add(Constraint::Class {
            class: c.class,
            arg,
            site: DictSite::Use {
                node,
                constraint: u32::try_from(i).unwrap_or(u32::MAX),
            },
            reason: reason(span, ReasonKind::ClassUse { class: c.class }),
        });
    }
}
pub(super) fn method(ctx: &mut Body<'_, '_>, name: &NameExpr) -> ITy {
    let Some(binding) = ctx.decls.reference(name.id) else {
        return ITy::Error;
    };
    // メソッドの宣言の型に自己の制約を先頭に置くことで、値として使う場合も T4 と同じ経路にする
    // （実装プラン 10-05「型パラメータの番号」）。
    ctx.instantiate(name.id, name.span, binding).0
}
pub(super) fn solve_classes(ctx: &mut Body<'_, '_>) {
    solve::solve_classes(ctx);
}

/// 修正案の判定は推論に制約を加えずに行う（設計書 02-10「修正案」）。
pub(super) fn implements(
    ctx: &Body<'_, '_>,
    solver: &super::solve::Solver,
    class: BindingId,
    ty: &ITy,
) -> bool {
    solve::resolve(
        ctx.decls,
        solver,
        &ctx.scheme,
        &solve::table(ctx.decls),
        class,
        &IClassArg::Ty(ty.clone()),
    )
    .is_ok()
}

/// F07 の区分を入口だけで読み替え、内部の判定で数値を取り違えないようにする。
enum Bound {
    Set,
    Equality,
    Key,
}
pub(super) fn check_bound(
    ctx: &mut Body<'_, '_>,
    index: u32,
    mode: u8,
    set: Option<TySet>,
    r: &Reason,
) {
    let Some(p) = usize::try_from(index)
        .ok()
        .and_then(|i| ctx.scheme.type_params.get(i))
        .cloned()
    else {
        return;
    };
    check_parameter_bound(ctx, &p, mode, set, r, Some(index));
}

/// 節の型パラメータを囲む関数のパラメータと混同しない（設計書 01-06、ADR 0312）。
pub(super) fn check_rigid_bound(
    ctx: &mut Body<'_, '_>,
    clause: NodeId,
    index: u32,
    mode: u8,
    set: Option<TySet>,
    r: &Reason,
) {
    let Some(p) = ctx
        .clause_params
        .get(clause)
        .and_then(|ps| usize::try_from(index).ok().and_then(|i| ps.get(i)))
        .cloned()
    else {
        debug_assert!(false, "missing operation type parameter");
        return;
    };
    check_parameter_bound(ctx, &p, mode, set, r, None);
}

fn check_parameter_bound(
    ctx: &mut Body<'_, '_>,
    p: &TypeParamInfo,
    mode: u8,
    set: Option<TySet>,
    r: &Reason,
    index: Option<u32>,
) {
    let bound = match mode {
        0 => Bound::Set,
        1 => Bound::Equality,
        2 => Bound::Key,
        _ => return,
    };
    let valid = match bound {
        Bound::Equality => matches!(
            p.builtin,
            Some(BuiltinConstraint::Equality | BuiltinConstraint::Key)
        ),
        Bound::Key => p.builtin == Some(BuiltinConstraint::Key),
        Bound::Set => {
            p.builtin == Some(BuiltinConstraint::Ordered)
                && set.is_some_and(|s| TySet::ORD.0.iter().all(|b| s.contains(*b)))
        }
    };
    if valid {
        return;
    }
    let name = p.name.clone();
    let (code, constraint, help) = match bound {
        Bound::Set => (DiagCode::E0405, text::ORDERED, "type_param"),
        Bound::Equality if matches!(r.kind, ReasonKind::Operator { .. }) => {
            (DiagCode::E0406, text::EQUALITY, "constraint")
        }
        Bound::Equality => (DiagCode::E0424, text::EQUALITY, "add"),
        Bound::Key => (DiagCode::E0424, text::KEY, "add"),
    };
    let mut diag = DiagBuilder::new(code)
        .primary(r.span)
        .arg("param", &name)
        .arg("ty", &name)
        .arg("op", op_text(&r.kind))
        .arg("constraint", constraint);
    if code == DiagCode::E0405 {
        diag = diag.help(help);
    } else {
        diag = diag.help_edits(
            help,
            index.map_or_else(Vec::new, |index| {
                parameter_edit(ctx.decls, &ctx.scope, index, constraint)
            }),
        );
    }
    ctx.diagnostic(diag.build());
}

fn class_name(d: &Decls<'_>, id: BindingId) -> String {
    d.resolved
        .bindings
        .get(id)
        .map_or_else(String::new, |b| b.name.clone())
}
fn constraint_name(ctx: &Body<'_, '_>, class: BindingId) -> String {
    let name = class_name(ctx.decls, class);
    let Some(target) = ctx.decls.resolved.bindings.get(class).map(|b| b.module) else {
        return name;
    };
    let Some(owner) = ctx
        .owner
        .and_then(|n| ctx.decls.binding(n))
        .and_then(|id| ctx.decls.resolved.bindings.get(id))
        .map(|b| b.module)
    else {
        return name;
    };
    if owner == target {
        return name;
    }
    // 修正案でも取り込み時の名前を使う。標準ライブラリ名と利用者の別名を同じ表で扱う
    // （設計書 01-03「修飾された名前の解決」、02-10「修正案」）。
    let Some(module) = ctx.decls.modules.get(owner) else {
        return name;
    };
    let Some(link) = module.imports.iter().find(|i| i.target == Some(target)) else {
        return name;
    };
    let Some(ast) = usize::try_from(owner.0)
        .ok()
        .and_then(|i| ctx.decls.asts.get(i))
    else {
        return name;
    };
    let Some(import) = ast.imports.iter().find(|i| i.id == link.decl) else {
        return name;
    };
    import
        .alias
        .as_ref()
        .or_else(|| import.path.last())
        .map_or(name.clone(), |alias| format!("{}.{name}", alias.text))
}
fn kind(p: &TypeParamDecl) -> ParamKind {
    if let crate::syntax::ast::TypeParamKind::Ctor { arity } = p.kind {
        ParamKind::Ctor { arity }
    } else {
        ParamKind::Value
    }
}
fn parameter_edit(d: &Decls<'_>, scope: &Scope, index: u32, constraint: &str) -> Vec<Edit> {
    let Some((id, _)) = scope.params.iter().find(|(_, (i, _))| *i == index) else {
        return vec![];
    };
    let Some(p) = collect::parameter(d, id) else {
        return vec![];
    };
    // 既存の制約の末尾へ加え、制約のない場合は名前の後へ挿入する（設計書 02-05「誤りの報告と検査の継続」）。
    let (end, prefix) = if p.constraints.is_empty() {
        (p.span.end, ": ")
    } else {
        (p.span.end, " & ")
    };
    vec![Edit {
        span: Span {
            file: p.span.file,
            start: end,
            end,
        },
        replacement: format!("{prefix}{constraint}"),
    }]
}
fn op_text(r: &ReasonKind) -> String {
    use crate::syntax::ast::{BinOp, UnOp};
    use crate::typeck::infer::OpName;
    if let ReasonKind::Operator { op } = r {
        match op {
            OpName::Un(UnOp::Neg) => "-",
            OpName::Un(UnOp::Not) => "not",
            OpName::Bin(b) => match b {
                BinOp::Add => "+",
                BinOp::Sub => "-",
                BinOp::Mul => "*",
                BinOp::Div => "/",
                BinOp::IntDiv => "div",
                BinOp::Mod => "mod",
                BinOp::Eq => "=",
                BinOp::Ne => "<>",
                BinOp::Lt => "<",
                BinOp::Le => "<=",
                BinOp::Gt => ">",
                BinOp::Ge => ">=",
                BinOp::And => "and",
                BinOp::Or => "or",
            },
        }
        .into()
    } else if let ReasonKind::BuiltinParam { name } | ReasonKind::ParamBound { name } = r {
        name.clone()
    } else {
        text::ORDERED.into()
    }
}

#[cfg(test)]
mod tests;
