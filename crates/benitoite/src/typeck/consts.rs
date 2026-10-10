//! 定数の形・型・値の順の検査と算術の警告（設計書 02-05「定数の検査と評価」「警告」）。
use super::{
    context::{Body, fixed, reason},
    decls::{Decls, Scope},
    infer::{Constraint, ReasonKind},
};
use crate::base::decimal::DecimalError;
use crate::base::prim::{KeyAtom, cmp_key_atom, float_to_text};
use crate::base::{BindingId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::types::{ConstValue as V, EffectSet, Ty};
use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};

pub(super) fn check(d: &mut Decls<'_>) {
    let mut pending = BTreeMap::new();
    for ast in d.asts {
        for top in &ast.decls {
            let Item::Const(c) = &top.item else {
                continue;
            };
            let Some(id) = d.binding(c.id) else {
                continue;
            };
            if d.invalid.contains(&id) {
                continue;
            }
            let Some(s) = d.out.decl_types.get(id).cloned() else {
                continue;
            };
            if contains_param(&s.ret) {
                d.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0434)
                        .arg("name", &c.name.text)
                        .primary(c.ty.span())
                        .build(),
                );
                continue;
            }
            if let Some(span) = bad_shape(d, &c.value) {
                d.diagnostics.push(
                    DiagBuilder::new(DiagCode::E0433)
                        .primary(span)
                        .help("function")
                        .build(),
                );
                continue;
            }
            let before = d.diagnostics.len();
            let mut ctx = Body::new(d, Scope::default(), s.clone());
            ctx.effect = fixed(EffectSet::empty());
            ctx.ret = None;
            let ty = ctx.expr(&c.value);
            let mut r = reason(c.value.span(), ReasonKind::ConstValue);
            r.related = Some(c.ty.span());
            r.int_literal = super::generate::integer_literal(&ctx, &c.value);
            ctx.add(Constraint::Equal {
                expected: super::context::lift(&s.ret),
                found: ty,
                reason: r,
            });
            ctx.solve();
            ctx.check_type_limits(c.value.span());
            let valid = !ctx
                .diagnostics
                .iter()
                .any(crate::diag::Diagnostic::is_error)
                && ctx.decls.diagnostics.len() == before;
            ctx.finish();
            if valid {
                pending.insert(id, c.clone());
            }
        }
    }
    // 依存先が失敗した定数は後続へ渡さない。参照の循環は名前解決が拒む（02-04「宣言の検査」）。
    let mut failed = BTreeSet::new();
    while !pending.is_empty() {
        let mut progress = false;
        let ids = pending.keys().copied().collect::<Vec<_>>();
        for id in ids {
            let Some(c) = pending.get(&id) else {
                continue;
            };
            let deps = dependencies(d, &c.value);
            if deps.iter().any(|dep| pending.contains_key(dep)) {
                continue;
            }
            let Some(c) = pending.remove(&id) else {
                continue;
            };
            progress = true;
            if deps
                .iter()
                .any(|dep| failed.contains(dep) || d.out.consts.get(*dep).is_none())
            {
                failed.insert(id);
                continue;
            }
            match eval(d, &c.value) {
                Ok(v) => {
                    d.out.consts.insert(id, v);
                }
                Err(EvalError::Arithmetic(span, condition)) => {
                    d.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0435)
                            .arg("name", &c.name.text)
                            .arg("condition", condition)
                            .primary(span)
                            .build(),
                    );
                    failed.insert(id);
                }
                Err(EvalError::Duplicate { span, first, key }) => {
                    d.diagnostics.push(
                        DiagBuilder::new(DiagCode::E0436)
                            .arg("key", key)
                            .primary(span)
                            .secondary(first, "first")
                            .build(),
                    );
                    failed.insert(id);
                }
                Err(EvalError::Unavailable) => {
                    failed.insert(id);
                }
            }
        }
        if !progress {
            break;
        }
    }
}
fn contains_param(ty: &Ty) -> bool {
    match ty {
        Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => true,
        Ty::Con(_, a) => a.iter().any(contains_param),
        Ty::Fn(f) => {
            f.params.iter().any(contains_param)
                || contains_param(&f.ret)
                || !f.effects.vars.is_empty()
        }
    }
}
fn std_call(d: &Decls<'_>, e: &Expr, name: &str) -> bool {
    let Expr::Name(n) = e else {
        return false;
    };
    let Some(id) = d.reference(n.id) else {
        return false;
    };
    Some(id) == d.resolved.stdlib(name)
}
fn collection_call(d: &Decls<'_>, e: &Expr) -> bool {
    [
        "Benitoite.Map.fromList",
        "Benitoite.Set.fromList",
        "Benitoite.Map.empty",
        "Benitoite.Set.empty",
    ]
    .iter()
    .any(|s| std_call(d, e, s))
}
fn bad_shape(d: &Decls<'_>, e: &Expr) -> Option<Span> {
    match e {
        Expr::Lit(_) | Expr::Unit(_) => None,
        Expr::Name(n) => {
            if d.resolved.binding_of_ref(n.id).is_some_and(|b| {
                b.kind == BindingKind::Const
                    || matches!(b.kind, BindingKind::Ctor { .. })
                        && d.reference(n.id)
                            .and_then(|id| d.out.decl_types.get(id))
                            .is_some_and(|s| s.params.is_empty())
            }) {
                None
            } else {
                Some(e.span())
            }
        }
        Expr::Call(c) => {
            let ctor = matches!(c.callee.as_ref(),Expr::Name(n) if d.resolved.binding_of_ref(n.id).is_some_and(|b|matches!(b.kind,BindingKind::Ctor { .. })));
            if !ctor && !collection_call(d, &c.callee) {
                return Some(e.span());
            }
            for a in &c.args {
                match a {
                    Arg::Expr(e) => {
                        if let Some(span) = bad_shape(d, e) {
                            return Some(span);
                        }
                    }
                    Arg::Placeholder(p) => return Some(p.span),
                }
            }
            None
        }
        Expr::Record(r) => {
            if r.base.is_some() {
                return Some(e.span());
            }
            r.fields.iter().find_map(|f| bad_shape(d, &f.value))
        }
        Expr::List(l) => l.elems.iter().find_map(|el| match el {
            ListElem::Expr(e) => bad_shape(d, e),
            ListElem::Spread(s) => bad_shape(d, &s.expr),
        }),
        Expr::Interp(i) => i.segments.iter().find_map(|s| bad_shape(d, &s.expr)),
        Expr::Unary(u) => bad_shape(d, &u.operand),
        Expr::Binary(b) => bad_shape(d, &b.lhs).or_else(|| bad_shape(d, &b.rhs)),
        Expr::Paren(p) => bad_shape(d, &p.inner),
        Expr::Pipe(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => Some(e.span()),
    }
}
fn dependencies(d: &Decls<'_>, e: &Expr) -> Vec<BindingId> {
    let mut deps = vec![];
    visit_expr(e, &mut |e| {
        if let Expr::Name(n) = e
            && let Some(id) = d.reference(n.id)
            && d.resolved
                .bindings
                .get(id)
                .is_some_and(|b| b.kind == BindingKind::Const)
        {
            deps.push(id);
        }
    });
    deps
}

enum EvalError {
    Arithmetic(Span, &'static str),
    Duplicate {
        span: Span,
        first: Span,
        key: String,
    },
    Unavailable,
}
type EvalResult = Result<V, EvalError>;
#[inline(never)]
fn eval(d: &Decls<'_>, e: &Expr) -> EvalResult {
    if let Some(v) = d.out.lit_values.get(e.id()) {
        return Ok(v.clone());
    }
    match e {
        Expr::Unit(_) => Ok(V::Unit),
        Expr::Paren(p) => eval(d, &p.inner),
        Expr::Name(n) => eval_name(d, n),
        Expr::Interp(i) => eval_interp(d, i),
        Expr::List(l) => eval_list(d, l),
        Expr::Record(r) => eval_record(d, r),
        Expr::Call(c) => eval_call(d, c),
        Expr::Unary(u) => eval_unary(d, u),
        Expr::Binary(b) => eval_binary(d, b),
        Expr::Lit(_)
        | Expr::Pipe(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => Err(EvalError::Unavailable),
    }
}
fn eval_call(d: &Decls<'_>, c: &CallExpr) -> EvalResult {
    if let Expr::Name(n) = c.callee.as_ref()
        && let Some(id) = d.reference(n.id)
        && let Some(BindingKind::Ctor { data, tag }) = d.resolved.bindings.get(id).map(|b| b.kind)
    {
        let args = c
            .args
            .iter()
            .map(|a| match a {
                Arg::Expr(e) => eval(d, e),
                _ => Err(EvalError::Unavailable),
            })
            .collect::<Result<Vec<_>, _>>()?;
        return Ok(V::Ctor {
            adt: data,
            tag,
            args,
        });
    }
    if std_call(d, &c.callee, "Benitoite.Map.empty") {
        return Ok(V::Map(vec![]));
    }
    if std_call(d, &c.callee, "Benitoite.Set.empty") {
        return Ok(V::Set(vec![]));
    }
    let map = std_call(d, &c.callee, "Benitoite.Map.fromList");
    let set = std_call(d, &c.callee, "Benitoite.Set.fromList");
    if map || set {
        let Some(Arg::Expr(list)) = c.args.first() else {
            return Err(EvalError::Unavailable);
        };
        let V::List(values) = eval(d, list)? else {
            return Err(EvalError::Unavailable);
        };
        let spans = list_spans(d, list, map);
        let mut entries = vec![];
        for (i, value) in values.into_iter().enumerate() {
            let span = spans.get(i).copied().unwrap_or(list.span());
            let (key, value) = if map {
                let V::Ctor { args, .. } = value else {
                    return Err(EvalError::Unavailable);
                };
                let mut args = args.into_iter();
                (
                    args.next().ok_or(EvalError::Unavailable)?,
                    Some(args.next().ok_or(EvalError::Unavailable)?),
                )
            } else {
                (value, None)
            };
            entries.push((key, value, span));
        }
        let mut invalid = false;
        entries.sort_by(|a, b| match compare(&a.0, &b.0, false) {
            Some(o) => o,
            None => {
                invalid = true;
                Ordering::Equal
            }
        });
        if invalid {
            return Err(EvalError::Unavailable);
        }
        for pair in entries.windows(2) {
            if let [a, b] = pair
                && compare(&a.0, &b.0, false) == Some(Ordering::Equal)
            {
                return Err(EvalError::Duplicate {
                    span: b.2,
                    first: a.2,
                    key: key_text(d, &b.0),
                });
            }
        }
        if map {
            let values = entries
                .into_iter()
                .map(|(k, v, _)| v.map(|v| (k, v)).ok_or(EvalError::Unavailable))
                .collect::<Result<Vec<_>, _>>()?;
            return Ok(V::Map(values));
        }
        return Ok(V::Set(entries.into_iter().map(|(k, _, _)| k).collect()));
    }
    // 警告だけに使う標準関数も、名前の綴りでなく束縛を照合する（02-05「警告」）。
    let values = c
        .args
        .iter()
        .map(|a| match a {
            Arg::Expr(e) => eval(d, e),
            _ => Err(EvalError::Unavailable),
        })
        .collect::<Result<Vec<_>, _>>()?;
    if std_call(d, &c.callee, "Benitoite.Integer.absolute")
        && let Some(V::Integer(n)) = values.first()
    {
        return n
            .checked_abs()
            .map(V::Integer)
            .ok_or(EvalError::Arithmetic(c.span, super::text::INTEGER_OVERFLOW));
    }
    if let [V::Integer(a), V::Integer(b)] = values.as_slice() {
        if std_call(d, &c.callee, "Benitoite.Integer.floorDivide") {
            return int_div(*a, *b, true, false, c.span);
        }
        if std_call(d, &c.callee, "Benitoite.Integer.floorModulo") {
            return int_div(*a, *b, true, true, c.span);
        }
    }
    Err(EvalError::Unavailable)
}
fn int_div(a: i64, b: i64, floor: bool, modulo: bool, span: Span) -> EvalResult {
    if b == 0 {
        return Err(EvalError::Arithmetic(span, super::text::DIVISION_BY_ZERO));
    }
    if modulo && a == i64::MIN && b == -1 {
        return Ok(V::Integer(0));
    }
    let q = a
        .checked_div(b)
        .ok_or(EvalError::Arithmetic(span, super::text::INTEGER_OVERFLOW))?;
    let r = a
        .checked_rem(b)
        .ok_or(EvalError::Arithmetic(span, super::text::INTEGER_OVERFLOW))?;
    let differing = r != 0 && (r < 0) != (b < 0);
    let v = if modulo {
        if floor && differing {
            r.checked_add(b)
        } else {
            Some(r)
        }
    } else if floor && differing {
        q.checked_sub(1)
    } else {
        Some(q)
    };
    v.map(V::Integer)
        .ok_or(EvalError::Arithmetic(span, super::text::INTEGER_OVERFLOW))
}
fn binary(op: BinOp, a: V, b: V, span: Span) -> EvalResult {
    if matches!(op, BinOp::Eq | BinOp::Ne) {
        let same = value_equal(&a, &b);
        return Ok(V::Boolean(if op == BinOp::Eq { same } else { !same }));
    }
    if matches!(op, BinOp::Lt | BinOp::Le | BinOp::Gt | BinOp::Ge) {
        let ord = compare(&a, &b, true);
        return Ok(V::Boolean(match op {
            BinOp::Lt => ord == Some(Ordering::Less),
            BinOp::Le => matches!(ord, Some(Ordering::Less | Ordering::Equal)),
            BinOp::Gt => ord == Some(Ordering::Greater),
            BinOp::Ge => matches!(ord, Some(Ordering::Greater | Ordering::Equal)),
            BinOp::Add
            | BinOp::Sub
            | BinOp::Mul
            | BinOp::Div
            | BinOp::IntDiv
            | BinOp::Mod
            | BinOp::Eq
            | BinOp::Ne
            | BinOp::And
            | BinOp::Or => false,
        }));
    }
    match (a, b) {
        (V::Integer(a), V::Integer(b)) => {
            let v = match op {
                BinOp::Add => a.checked_add(b),
                BinOp::Sub => a.checked_sub(b),
                BinOp::Mul => a.checked_mul(b),
                BinOp::IntDiv => return int_div(a, b, false, false, span),
                BinOp::Mod => return int_div(a, b, false, true, span),
                BinOp::Div
                | BinOp::Eq
                | BinOp::Ne
                | BinOp::Lt
                | BinOp::Le
                | BinOp::Gt
                | BinOp::Ge
                | BinOp::And
                | BinOp::Or => return Err(EvalError::Unavailable),
            };
            v.map(V::Integer)
                .ok_or(EvalError::Arithmetic(span, super::text::INTEGER_OVERFLOW))
        }
        (V::Float(a), V::Float(b)) => Ok(V::Float(match op {
            BinOp::Add => a + b,
            BinOp::Sub => a - b,
            BinOp::Mul => a * b,
            BinOp::Div => a / b,
            BinOp::IntDiv
            | BinOp::Mod
            | BinOp::Eq
            | BinOp::Ne
            | BinOp::Lt
            | BinOp::Le
            | BinOp::Gt
            | BinOp::Ge
            | BinOp::And
            | BinOp::Or => return Err(EvalError::Unavailable),
        })),
        (V::Decimal(a), V::Decimal(b)) => {
            let result = match op {
                BinOp::Add => a.checked_add(b),
                BinOp::Sub => a.checked_sub(b),
                BinOp::Mul => a.checked_mul(b),
                BinOp::Div => a.checked_div(b),
                BinOp::IntDiv
                | BinOp::Mod
                | BinOp::Eq
                | BinOp::Ne
                | BinOp::Lt
                | BinOp::Le
                | BinOp::Gt
                | BinOp::Ge
                | BinOp::And
                | BinOp::Or => return Err(EvalError::Unavailable),
            };
            result.map(V::Decimal).map_err(|e| {
                EvalError::Arithmetic(
                    span,
                    match e {
                        DecimalError::DivisionByZero => super::text::DIVISION_BY_ZERO,
                        DecimalError::Overflow | DecimalError::InvalidPlaces => {
                            super::text::DECIMAL_OVERFLOW
                        }
                    },
                )
            })
        }
        (V::String(mut a), V::String(b)) if op == BinOp::Add => {
            a.push_str(&b);
            Ok(V::String(a))
        }
        (V::Boolean(a), V::Boolean(b)) => match op {
            BinOp::And => Ok(V::Boolean(a && b)),
            BinOp::Or => Ok(V::Boolean(a || b)),
            BinOp::Add
            | BinOp::Sub
            | BinOp::Mul
            | BinOp::Div
            | BinOp::IntDiv
            | BinOp::Mod
            | BinOp::Eq
            | BinOp::Ne
            | BinOp::Lt
            | BinOp::Le
            | BinOp::Gt
            | BinOp::Ge => Err(EvalError::Unavailable),
        },
        _ => Err(EvalError::Unavailable),
    }
}
fn value_text(v: &V) -> Option<String> {
    match v {
        V::Integer(n) => Some(n.to_string()),
        V::Float(n) => Some(float_to_text(*n)),
        V::Decimal(n) => Some(n.to_text()),
        V::Byte(n) => Some(n.to_string()),
        V::String(s) => Some(s.clone()),
        V::Character(c) => Some(c.to_string()),
        V::Boolean(b) => Some(b.to_string()),
        V::Unit | V::Ctor { .. } | V::List(_) | V::Map(_) | V::Set(_) => None,
    }
}
fn key_text(d: &Decls<'_>, v: &V) -> String {
    if let Some(s) = value_text(v) {
        return s;
    }
    match v {
        V::Unit => "()".into(),
        V::Ctor { adt, tag, .. } => d
            .out
            .adts
            .get(*adt)
            .and_then(|a| usize::try_from(*tag).ok().and_then(|t| a.ctors.get(t)))
            .map_or_else(String::new, |c| c.name.clone()),
        V::Integer(_)
        | V::Float(_)
        | V::String(_)
        | V::Character(_)
        | V::Boolean(_)
        | V::Byte(_)
        | V::Decimal(_)
        | V::List(_)
        | V::Map(_)
        | V::Set(_) => format!("{v:?}"),
    }
}
fn atom(v: &V) -> Option<KeyAtom<'_>> {
    match v {
        V::Unit => Some(KeyAtom::Unit),
        V::Boolean(b) => Some(KeyAtom::Boolean(*b)),
        V::Integer(n) => Some(KeyAtom::Integer(*n)),
        V::Byte(n) => Some(KeyAtom::Byte(*n)),
        V::Character(c) => Some(KeyAtom::Character(*c)),
        V::Decimal(n) => Some(KeyAtom::Decimal(*n)),
        V::String(s) => Some(KeyAtom::String(s)),
        V::Float(_) | V::Ctor { .. } | V::List(_) | V::Map(_) | V::Set(_) => None,
    }
}
/// 値の深さを Rust の呼び出しの深さにしない（実装プラン 00-02「再帰の深さ」）。
fn compare(a: &V, b: &V, float: bool) -> Option<Ordering> {
    enum Work<'a> {
        Pair(&'a V, &'a V),
        Length(usize, usize),
    }
    let mut work = vec![Work::Pair(a, b)];
    while let Some(item) = work.pop() {
        let (a, b) = match item {
            Work::Length(a, b) => {
                let o = a.cmp(&b);
                if o != Ordering::Equal {
                    return Some(o);
                }
                continue;
            }
            Work::Pair(a, b) => (a, b),
        };
        if let (Some(a), Some(b)) = (atom(a), atom(b)) {
            let o = cmp_key_atom(a, b)?;
            if o != Ordering::Equal {
                return Some(o);
            }
            continue;
        }
        match (a, b) {
            (V::Float(a), V::Float(b)) if float => {
                let o = a.partial_cmp(b)?;
                if o != Ordering::Equal {
                    return Some(o);
                }
            }
            (
                V::Ctor {
                    adt: a,
                    tag: ta,
                    args: aa,
                },
                V::Ctor {
                    adt: b,
                    tag: tb,
                    args: bb,
                },
            ) if a == b => {
                let o = ta.cmp(tb);
                if o != Ordering::Equal {
                    return Some(o);
                }
                work.push(Work::Length(aa.len(), bb.len()));
                for (a, b) in aa.iter().zip(bb).rev() {
                    work.push(Work::Pair(a, b));
                }
            }
            (V::List(a), V::List(b)) | (V::Set(a), V::Set(b)) => {
                work.push(Work::Length(a.len(), b.len()));
                for (a, b) in a.iter().zip(b).rev() {
                    work.push(Work::Pair(a, b));
                }
            }
            (V::Map(a), V::Map(b)) => {
                work.push(Work::Length(a.len(), b.len()));
                for ((ak, av), (bk, bv)) in a.iter().zip(b).rev() {
                    work.push(Work::Pair(av, bv));
                    work.push(Work::Pair(ak, bk));
                }
            }
            _ => return None,
        }
    }
    Some(Ordering::Equal)
}
fn value_equal(a: &V, b: &V) -> bool {
    compare(a, b, true) == Some(Ordering::Equal)
}

fn list_spans(d: &Decls<'_>, e: &Expr, map: bool) -> Vec<Span> {
    match e {
        Expr::List(l) => l
            .elems
            .iter()
            .flat_map(|e| match e {
                ListElem::Expr(Expr::Call(c))
                    if map && matches!(c.args.first(), Some(Arg::Expr(_))) =>
                {
                    let span = match c.args.first() {
                        Some(Arg::Expr(e)) => e.span(),
                        _ => c.span,
                    };
                    vec![span]
                }
                ListElem::Expr(e) => vec![e.span()],
                ListElem::Spread(s) => list_spans(d, &s.expr, map),
            })
            .collect(),
        Expr::Paren(p) => list_spans(d, &p.inner, map),
        Expr::Name(n) => match d.reference(n.id).and_then(|id| d.out.consts.get(id)) {
            Some(V::List(values)) => vec![n.span; values.len()],
            _ => vec![],
        },
        Expr::Lit(_)
        | Expr::Interp(_)
        | Expr::Unit(_)
        | Expr::Call(_)
        | Expr::Record(_)
        | Expr::Binary(_)
        | Expr::Unary(_)
        | Expr::Pipe(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => vec![],
    }
}
// 型の付いた Pair の構築だけは値が定数式でなくても鍵を調べる。普通の関数の第1引数を
// 鍵とみなすと、定数式でない鍵にも警告してしまう（設計書 02-05「警告」）。
fn known_key(d: &Decls<'_>, e: &Expr, map: bool) -> Option<(V, Span)> {
    if !map {
        return bad_shape(d, e)
            .is_none()
            .then(|| eval(d, e).ok())
            .flatten()
            .map(|v| (v, e.span()));
    }
    if let Expr::Paren(p) = e {
        return known_key(d, &p.inner, true);
    }
    if let Expr::Call(c) = e
        && let Expr::Name(n) = c.callee.as_ref()
        && d.reference(n.id) == d.resolved.stdlib("Benitoite.Pair.Pair")
        && let Some(Arg::Expr(key)) = c.args.first()
        && bad_shape(d, key).is_none()
    {
        return eval(d, key).ok().map(|v| (v, key.span()));
    }
    if bad_shape(d, e).is_some() {
        return None;
    }
    let V::Ctor { args, .. } = eval(d, e).ok()? else {
        return None;
    };
    args.into_iter().next().map(|v| (v, e.span()))
}
fn arithmetic_candidate(d: &Decls<'_>, e: &Expr) -> bool {
    match e {
        Expr::Binary(_) | Expr::Unary(_) => bad_shape(d, e).is_none(),
        Expr::Call(c) => {
            (std_call(d, &c.callee, "Benitoite.Integer.absolute")
                || std_call(d, &c.callee, "Benitoite.Integer.floorDivide"))
                && c.args
                    .iter()
                    .all(|a| matches!(a, Arg::Expr(e) if bad_shape(d, e).is_none()))
        }
        Expr::Lit(_)
        | Expr::Interp(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::Paren(_)
        | Expr::List(_)
        | Expr::Record(_)
        | Expr::Pipe(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Return(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => false,
    }
}
pub(super) fn warnings(ctx: &mut Body<'_, '_>, block: &Block) {
    if ctx
        .decls
        .modules
        .get(crate::base::ModuleId::of_file(block.span.file))
        .is_some_and(|m| {
            matches!(
                m.kind,
                crate::modules::ModuleKind::Prelude | crate::modules::ModuleKind::Stdlib
            )
        })
    {
        return;
    }
    let mut diagnostics = vec![];
    visit_block(block, &mut |e| {
        let divisor = match e {
            Expr::Binary(b)
                if matches!(b.op, BinOp::IntDiv | BinOp::Mod)
                    || b.op == BinOp::Div
                        && ctx
                            .operand_types
                            .get(b.id)
                            .map(|t| ctx.solver.finalize(t, ctx.decls.resolved))
                            == Some(super::decls::basic(
                                crate::types::builtin::BuiltinTypeId::DECIMAL,
                            )) =>
            {
                Some(b.rhs.as_ref())
            }
            Expr::Call(c)
                if std_call(ctx.decls, &c.callee, "Benitoite.Integer.floorDivide")
                    || std_call(ctx.decls, &c.callee, "Benitoite.Integer.floorModulo") =>
            {
                match c.args.get(1) {
                    Some(Arg::Expr(e)) => Some(e),
                    _ => None,
                }
            }
            Expr::Lit(_)
            | Expr::Interp(_)
            | Expr::Name(_)
            | Expr::Unit(_)
            | Expr::Paren(_)
            | Expr::List(_)
            | Expr::Call(_)
            | Expr::Record(_)
            | Expr::Binary(_)
            | Expr::Unary(_)
            | Expr::Pipe(_)
            | Expr::If(_)
            | Expr::Match(_)
            | Expr::Lambda(_)
            | Expr::Return(_)
            | Expr::Try(_)
            | Expr::Lazy(_)
            | Expr::With(_)
            | Expr::Handle(_)
            | Expr::Resume(_)
            | Expr::Error(_) => None,
        };
        if let Some(e) = divisor
            && bad_shape(ctx.decls, e).is_none()
            && eval(ctx.decls, e).ok().is_some_and(|v| match v {
                V::Integer(n) => n == 0,
                V::Decimal(n) => n.mantissa() == 0,
                V::Float(_)
                | V::String(_)
                | V::Character(_)
                | V::Boolean(_)
                | V::Unit
                | V::Byte(_)
                | V::Ctor { .. }
                | V::List(_)
                | V::Map(_)
                | V::Set(_) => false,
            })
        {
            diagnostics.push(DiagBuilder::new(DiagCode::W0401).primary(e.span()).build());
        }
        match arithmetic_candidate(ctx.decls, e).then(|| eval(ctx.decls, e)) {
            Some(Err(EvalError::Arithmetic(span, condition)))
                if span == e.span() && condition != super::text::DIVISION_BY_ZERO =>
            {
                diagnostics.push(
                    DiagBuilder::new(DiagCode::W0402)
                        .arg(
                            "ty",
                            if condition == super::text::INTEGER_OVERFLOW {
                                "Integer"
                            } else {
                                "Decimal"
                            },
                        )
                        .primary(span)
                        .build(),
                )
            }
            _ => {}
        }
        if let Expr::Call(c) = e
            && (std_call(ctx.decls, &c.callee, "Benitoite.Map.fromList")
                || std_call(ctx.decls, &c.callee, "Benitoite.Set.fromList"))
        {
            let map = std_call(ctx.decls, &c.callee, "Benitoite.Map.fromList");
            if let Some(Arg::Expr(Expr::List(l))) = c.args.first() {
                let mut keys: Vec<(V, Span)> = vec![];
                for el in &l.elems {
                    let ListElem::Expr(e) = el else {
                        continue;
                    };
                    let Some((value, span)) = known_key(ctx.decls, e, map) else {
                        continue;
                    };
                    if let Some((_, first)) = keys
                        .iter()
                        .find(|(v, _)| compare(v, &value, false) == Some(Ordering::Equal))
                    {
                        diagnostics.push(
                            DiagBuilder::new(DiagCode::W0403)
                                .arg("key", key_text(ctx.decls, &value))
                                .primary(span)
                                .secondary(*first, "first")
                                .build(),
                        );
                    } else {
                        keys.push((value, span));
                    }
                }
            }
        }
    });
    ctx.diagnostics.extend(diagnostics);
}
fn visit_block(b: &Block, f: &mut impl FnMut(&Expr)) {
    for s in &b.stmts {
        match s {
            Stmt::Expr(e) => visit_expr(e, f),
            Stmt::Bind(b) => visit_expr(&b.value, f),
            _ => {}
        }
    }
}
fn visit_expr(e: &Expr, f: &mut impl FnMut(&Expr)) {
    f(e);
    match e {
        Expr::Paren(p) => visit_expr(&p.inner, f),
        Expr::Interp(i) => {
            for s in &i.segments {
                visit_expr(&s.expr, f);
            }
        }
        Expr::List(l) => {
            for e in &l.elems {
                match e {
                    ListElem::Expr(e) => visit_expr(e, f),
                    ListElem::Spread(s) => visit_expr(&s.expr, f),
                }
            }
        }
        Expr::Call(c) => {
            visit_expr(&c.callee, f);
            for a in &c.args {
                if let Arg::Expr(e) = a {
                    visit_expr(e, f);
                }
            }
        }
        Expr::Record(r) => {
            if let Some(b) = &r.base {
                visit_expr(b, f);
            }
            for field in &r.fields {
                visit_expr(&field.value, f);
            }
        }
        Expr::Binary(b) => {
            visit_expr(&b.lhs, f);
            visit_expr(&b.rhs, f);
        }
        Expr::Unary(u) => visit_expr(&u.operand, f),
        Expr::Pipe(p) => {
            visit_expr(&p.lhs, f);
            visit_expr(&p.rhs, f);
        }
        Expr::Return(r) => visit_expr(&r.value, f),
        Expr::If(i) => {
            visit_expr(&i.cond, f);
            visit_block(&i.then_block, f);
            if let Some(b) = &i.else_branch {
                match b {
                    ElseBranch::Block(b) => visit_block(b, f),
                    ElseBranch::If(i) => visit_expr(&Expr::If(i.as_ref().clone()), f),
                }
            }
        }
        Expr::Match(m) => {
            visit_expr(&m.scrutinee, f);
            for arm in &m.arms {
                if let Some(g) = &arm.guard {
                    visit_expr(g, f);
                }
                visit_block(&arm.body, f);
            }
        }
        Expr::Lambda(l) => visit_block(&l.body, f),
        Expr::Try(t) => visit_expr(&t.value, f),
        Expr::Lazy(l) => visit_block(&l.body, f),
        Expr::With(w) => {
            for b in &w.binds {
                visit_expr(&b.value, f);
            }
            visit_block(&w.body, f);
        }
        Expr::Handle(h) => {
            visit_block(&h.body, f);
            for c in &h.clauses {
                visit_block(&c.body, f);
            }
        }
        Expr::Resume(r) => visit_expr(&r.value, f),
        Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Error(_) => {}
    }
}

// 複合値の評価の一時値を入口の再帰の枠から分ける（実装プラン F10「型検査の再帰の深さ」）。
#[inline(never)]
fn eval_name(d: &Decls<'_>, n: &NameExpr) -> EvalResult {
    let id = d.reference(n.id).ok_or(EvalError::Unavailable)?;
    if let Some(v) = d.out.consts.get(id) {
        return Ok(v.clone());
    }
    let Some(BindingKind::Ctor { data, tag }) = d.resolved.bindings.get(id).map(|b| b.kind) else {
        return Err(EvalError::Unavailable);
    };
    Ok(V::Ctor {
        adt: data,
        tag,
        args: vec![],
    })
}

#[inline(never)]
fn eval_interp(d: &Decls<'_>, i: &InterpExpr) -> EvalResult {
    let mut text = i.head.clone();
    for s in &i.segments {
        text.push_str(&value_text(&eval(d, &s.expr)?).ok_or(EvalError::Unavailable)?);
        text.push_str(&s.tail);
    }
    Ok(V::String(text))
}

#[inline(never)]
fn eval_list(d: &Decls<'_>, l: &ListExpr) -> EvalResult {
    let mut out = vec![];
    for el in &l.elems {
        match el {
            ListElem::Expr(e) => out.push(eval(d, e)?),
            ListElem::Spread(s) => {
                if let V::List(v) = eval(d, &s.expr)? {
                    out.extend(v);
                } else {
                    return Err(EvalError::Unavailable);
                }
            }
        }
    }
    Ok(V::List(out))
}

#[inline(never)]
fn eval_record(d: &Decls<'_>, r: &RecordExpr) -> EvalResult {
    let id = d.reference(r.id).ok_or(EvalError::Unavailable)?;
    let fields = d
        .out
        .adts
        .get(id)
        .and_then(|a| a.record.as_ref())
        .ok_or(EvalError::Unavailable)?;
    let mut args = vec![];
    for f in fields {
        let arg = r
            .fields
            .iter()
            .find(|arg| arg.name.text == f.name)
            .ok_or(EvalError::Unavailable)?;
        args.push(eval(d, &arg.value)?);
    }
    Ok(V::Ctor {
        adt: id,
        tag: 0,
        args,
    })
}

#[inline(never)]
fn eval_unary(d: &Decls<'_>, u: &UnaryExpr) -> EvalResult {
    let v = eval(d, &u.operand)?;
    match (u.op, v) {
        (UnOp::Not, V::Boolean(b)) => Ok(V::Boolean(!b)),
        (UnOp::Neg, V::Integer(n)) => n
            .checked_neg()
            .map(V::Integer)
            .ok_or(EvalError::Arithmetic(u.span, super::text::INTEGER_OVERFLOW)),
        (UnOp::Neg, V::Float(n)) => Ok(V::Float(-n)),
        (UnOp::Neg, V::Decimal(n)) => Ok(V::Decimal(n.negate())),
        _ => Err(EvalError::Unavailable),
    }
}

#[inline(never)]
fn eval_binary(d: &Decls<'_>, b: &BinaryExpr) -> EvalResult {
    let lhs = eval(d, &b.lhs)?;
    if b.op == BinOp::And && matches!(lhs, V::Boolean(false)) {
        return Ok(lhs);
    }
    if b.op == BinOp::Or && matches!(lhs, V::Boolean(true)) {
        return Ok(lhs);
    }
    binary(b.op, lhs, eval(d, &b.rhs)?, b.span)
}
