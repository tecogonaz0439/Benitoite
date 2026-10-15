//! 定数の形・型・値の順の検査と算術の警告（設計書 02-05「定数の検査と評価」「警告」）。
mod key;
#[cfg(test)]
mod width_tests;

use super::{
    context::{Body, fixed, reason},
    decls::{Decls, Scope},
    infer::{Constraint, ReasonKind},
};
use crate::base::decimal::DecimalError;
use crate::base::prim::numeric::{self, ArithmeticError, ArithmeticOp};
use crate::base::prim::{KeyAtom, cmp_key_atom, float_to_text};
use crate::base::{BindingId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use crate::resolve::BindingKind;
use crate::syntax::ast::*;
use crate::types::{ConstValue as V, EffectSet, Ty};
use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use std::mem::size_of;

/// 型やリテラルの誤りがある式は評価しない（設計書 02-05「定数の検査と評価」）。
pub(super) fn prevents_evaluation(diagnostic: &crate::diag::Diagnostic) -> bool {
    diagnostic.is_error()
}

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
            let valid = !ctx.diagnostics.iter().any(prevents_evaluation)
                && ctx.decls.diagnostics.len() == before;
            ctx.finish();
            if valid {
                pending.insert(id, c.clone());
            }
        }
    }
    // 依存先が失敗した定数は後続へ渡さない。参照の循環は名前解決が拒む（02-04「宣言の検査」）。
    let mut failed = BTreeSet::new();
    let mut budget = EvalBudget::default();
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
            match eval(d, &c.value, &mut budget) {
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
                Err(EvalError::Limit(span, limit)) => {
                    let mut diag = DiagBuilder::new(DiagCode::E0435)
                        .arg("name", &c.name.text)
                        .arg("condition", limit.condition(budget.limits))
                        .primary(span);
                    if matches!(limit, EvalLimit::Budget) {
                        diag = diag.help("budget");
                    }
                    d.diagnostics.push(diag.build());
                    if matches!(limit, EvalLimit::Budget) {
                        // 予算は全定数で共有する。独立した後続の定数も評価せず、派生の誤りを出さない。
                        return;
                    }
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
                    Arg::Named(a) => match &a.value {
                        ArgValue::Expr(e) => {
                            if let Some(span) = bad_shape(d, e) {
                                return Some(span);
                            }
                        }
                        ArgValue::Placeholder(p) => return Some(p.span),
                    },
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

// 定数の検査で作る値の総量を 64 MiB に制限する（設計書 02-05「定数の検査と評価」）。
const CONST_EVAL_BUDGET: usize = 67_108_864;

#[derive(Clone, Copy)]
struct EvalLimits {
    string_bytes: u64,
    list_len: u64,
    budget: usize,
}
impl Default for EvalLimits {
    fn default() -> Self {
        Self {
            // 検査時だけ実行時より大きい値を作らないよう、実行時と上限を揃える
            // （設計書 02-09「一つの操作で作る値の大きさの上限」）。
            string_bytes: crate::runtime::MAX_STRING_BYTES,
            list_len: crate::runtime::MAX_LIST_LEN,
            budget: CONST_EVAL_BUDGET,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EvalLimit {
    String,
    List,
    Budget,
}
impl EvalLimit {
    fn condition(self, limits: EvalLimits) -> String {
        match self {
            Self::String => super::text::const_string_limit(limits.string_bytes),
            Self::List => super::text::const_list_limit(limits.list_len),
            Self::Budget => super::text::const_budget_limit(limits.budget),
        }
    }
}
#[derive(Default)]
struct EvalBudget {
    limits: EvalLimits,
    used: usize,
}
impl EvalBudget {
    fn charge(&mut self, bytes: usize, span: Span) -> Result<(), EvalError> {
        self.used = self
            .used
            .checked_add(bytes)
            .filter(|used| *used <= self.limits.budget)
            .ok_or(EvalError::Limit(span, EvalLimit::Budget))?;
        Ok(())
    }
    fn string(&mut self, bytes: usize, span: Span) -> Result<(), EvalError> {
        if u64::try_from(bytes).unwrap_or(u64::MAX) > self.limits.string_bytes {
            return Err(EvalError::Limit(span, EvalLimit::String));
        }
        self.charge(bytes, span)
    }
    fn list(&self, len: usize, span: Span) -> Result<(), EvalError> {
        if u64::try_from(len).unwrap_or(u64::MAX) > self.limits.list_len {
            return Err(EvalError::Limit(span, EvalLimit::List));
        }
        Ok(())
    }
    fn slots(&mut self, count: usize, span: Span) -> Result<(), EvalError> {
        // Vec の再確保で旧領域と新領域が重なる分を含め、要素の格納領域を二倍で見積もる。
        self.charge(count.saturating_mul(size_of::<V>()).saturating_mul(2), span)
    }
    fn clone_value(&mut self, value: &V, span: Span) -> EvalResult {
        // 複製も新しく作る値である。文字列の容量、Vec の容量と入れ子の確保を全て数える。
        // 明示の積み重ねで辿り、既存の値の深さを Rust の呼び出しの深さにしない。
        let mut work = vec![value];
        self.charge(size_of::<V>(), span)?;
        while let Some(value) = work.pop() {
            match value {
                V::String(s) => {
                    self.string(s.len(), span)?;
                    self.charge(s.capacity().saturating_sub(s.len()), span)?;
                }
                V::List(v) | V::Set(v) | V::Ctor { args: v, .. } => {
                    if matches!(value, V::List(_)) {
                        self.list(v.len(), span)?;
                    }
                    self.slots(v.capacity(), span)?;
                    work.extend(v);
                }
                V::Map(v) => {
                    self.slots(v.capacity().saturating_mul(2), span)?;
                    for (k, v) in v {
                        work.push(k);
                        work.push(v);
                    }
                }
                V::Integer8(_)
                | V::Integer16(_)
                | V::Integer32(_)
                | V::UnsignedInteger16(_)
                | V::UnsignedInteger32(_)
                | V::UnsignedInteger64(_)
                | V::Float32(_)
                | V::Integer(_)
                | V::Float(_)
                | V::Character(_)
                | V::Boolean(_)
                | V::Unit
                | V::Byte(_)
                | V::Decimal(_) => {}
            }
        }
        Ok(value.clone())
    }
}

enum EvalError {
    Limit(Span, EvalLimit),
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
fn eval(d: &Decls<'_>, e: &Expr, budget: &mut EvalBudget) -> EvalResult {
    // 各評価の値の本体も数える。移動先の格納領域との重複は保守的な見積もりとして残す。
    budget.charge(size_of::<V>(), e.span())?;
    if let Some(v) = d.out.lit_values.get(e.id()) {
        return budget.clone_value(v, e.span());
    }
    match e {
        Expr::Unit(_) => Ok(V::Unit),
        Expr::Paren(p) => eval(d, &p.inner, budget),
        Expr::Name(n) => eval_name(d, n, budget),
        Expr::Interp(i) => eval_interp(d, i, budget),
        Expr::List(l) => eval_list(d, l, budget),
        Expr::Record(r) => eval_record(d, r, budget),
        Expr::Call(c) => eval_call(d, c, budget),
        Expr::Unary(u) => eval_unary(d, u, budget),
        Expr::Binary(b) => eval_binary(d, b, budget),
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
fn eval_call(d: &Decls<'_>, c: &CallExpr, budget: &mut EvalBudget) -> EvalResult {
    if let Expr::Name(n) = c.callee.as_ref()
        && let Some(id) = d.reference(n.id)
        && let Some(BindingKind::Ctor { data, tag }) = d.resolved.bindings.get(id).map(|b| b.kind)
    {
        budget.slots(c.args.len(), c.span)?;
        let mut args = Vec::with_capacity(c.args.len());
        for arg in &c.args {
            // 直接の構成子の名前指定は、評価前の型検査が E0456 で拒否する。
            let e = arg.expr().ok_or(EvalError::Unavailable)?;
            args.push(eval(d, e, budget)?);
        }
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
        let Some(list) = standard_argument(c, 0, if map { "pairs" } else { "xs" }) else {
            return Err(EvalError::Unavailable);
        };
        let V::List(values) = eval(d, list, budget)? else {
            return Err(EvalError::Unavailable);
        };
        // 入力の入れ子の値は移動する。新たな格納領域、位置の表、安定ソートの一時領域は
        // 作る前に数える。Map と Set には一つの値の上限はない（設計書 02-09）。
        let per_entry = size_of::<(V, Option<V>, Span)>()
            .saturating_mul(2)
            .saturating_add(size_of::<Span>().saturating_mul(2))
            .saturating_add(size_of::<(V, V)>());
        budget.charge(values.len().saturating_mul(per_entry), c.span)?;
        let spans = list_spans(d, list, map);
        let mut entries = Vec::with_capacity(values.len());
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
            let mut values = Vec::with_capacity(entries.len());
            for (k, v, _) in entries {
                values.push((k, v.ok_or(EvalError::Unavailable)?));
            }
            return Ok(V::Map(values));
        }
        return Ok(V::Set(entries.into_iter().map(|(k, _, _)| k).collect()));
    }
    // 警告だけに使う標準関数も、名前の綴りでなく束縛を照合する（02-05「警告」）。
    budget.slots(c.args.len(), c.span)?;
    if std_call(d, &c.callee, "Benitoite.Integer.absolute")
        && c.args.len() == 1
        && let Some(e) = standard_argument(c, 0, "n")
        && let V::Integer(n) = eval(d, e, budget)?
    {
        return n
            .checked_abs()
            .map(V::Integer)
            .ok_or(EvalError::Arithmetic(c.span, super::text::INTEGER_OVERFLOW));
    }
    let divide = std_call(d, &c.callee, "Benitoite.Integer.floorDivide");
    let modulo = std_call(d, &c.callee, "Benitoite.Integer.floorModulo");
    if (divide || modulo)
        && c.args.len() == 2
        && let (Some(a), Some(b)) = (standard_argument(c, 0, "a"), standard_argument(c, 1, "b"))
        && let (V::Integer(a), V::Integer(b)) = (eval(d, a, budget)?, eval(d, b, budget)?)
    {
        return int_div(a, b, true, modulo, c.span);
    }
    Err(EvalError::Unavailable)
}
// 名前付きのソース順から引数の位置を推測しない。標準の束縛を照合した呼び出しだけで
// 宣言の名前を使う（設計書 02-05「定数の検査と評価」「警告」）。
fn standard_argument<'a>(c: &'a CallExpr, index: usize, name: &str) -> Option<&'a Expr> {
    if c.args.iter().any(|a| matches!(a, Arg::Named(_))) {
        c.args
            .iter()
            .find(|a| matches!(a, Arg::Named(a) if a.name.text == name))
            .and_then(Arg::expr)
    } else {
        c.args.get(index).and_then(Arg::expr)
    }
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
fn binary(op: BinOp, a: V, b: V, span: Span, budget: &mut EvalBudget) -> EvalResult {
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
    macro_rules! width_integer {
        ($a:expr, $b:expr, $variant:ident) => {
            numeric::integer_binary(arithmetic_op(op)?, $a, $b)
                .map(V::$variant)
                .map_err(|error| arithmetic_error(error, span))
        };
    }
    match (a, b) {
        (V::Integer8(a), V::Integer8(b)) => width_integer!(a, b, Integer8),
        (V::Integer16(a), V::Integer16(b)) => width_integer!(a, b, Integer16),
        (V::Integer32(a), V::Integer32(b)) => width_integer!(a, b, Integer32),
        (V::UnsignedInteger16(a), V::UnsignedInteger16(b)) => {
            width_integer!(a, b, UnsignedInteger16)
        }
        (V::UnsignedInteger32(a), V::UnsignedInteger32(b)) => {
            width_integer!(a, b, UnsignedInteger32)
        }
        (V::UnsignedInteger64(a), V::UnsignedInteger64(b)) => {
            width_integer!(a, b, UnsignedInteger64)
        }
        (V::Float32(a), V::Float32(b)) => numeric::float32_binary(arithmetic_op(op)?, a, b)
            .map(V::Float32)
            .ok_or(EvalError::Unavailable),
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
        (V::String(a), V::String(b)) if op == BinOp::Add => {
            let len = a.len().saturating_add(b.len());
            budget.string(len, span)?;
            let mut out = String::with_capacity(len);
            out.push_str(&a);
            out.push_str(&b);
            Ok(V::String(out))
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
fn arithmetic_op(op: BinOp) -> Result<ArithmeticOp, EvalError> {
    match op {
        BinOp::Add => Ok(ArithmeticOp::Add),
        BinOp::Sub => Ok(ArithmeticOp::Subtract),
        BinOp::Mul => Ok(ArithmeticOp::Multiply),
        BinOp::IntDiv | BinOp::Div => Ok(ArithmeticOp::Divide),
        BinOp::Mod => Ok(ArithmeticOp::Modulo),
        BinOp::Eq
        | BinOp::Ne
        | BinOp::Lt
        | BinOp::Le
        | BinOp::Gt
        | BinOp::Ge
        | BinOp::And
        | BinOp::Or => Err(EvalError::Unavailable),
    }
}
fn arithmetic_error(error: ArithmeticError, span: Span) -> EvalError {
    EvalError::Arithmetic(
        span,
        match error {
            ArithmeticError::Overflow => super::text::INTEGER_OVERFLOW,
            ArithmeticError::DivisionByZero => super::text::DIVISION_BY_ZERO,
        },
    )
}
fn value_text(v: &V) -> Option<String> {
    match v {
        V::Integer8(n) => Some(n.to_string()),
        V::Integer16(n) => Some(n.to_string()),
        V::Integer32(n) => Some(n.to_string()),
        V::UnsignedInteger16(n) => Some(n.to_string()),
        V::UnsignedInteger32(n) => Some(n.to_string()),
        V::UnsignedInteger64(n) => Some(n.to_string()),
        V::Float32(n) => Some(crate::base::prim::float32_to_text(*n)),
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
    key::const_key(&d.out.adts, v)
}

fn atom(v: &V) -> Option<KeyAtom<'_>> {
    match v {
        V::Unit => Some(KeyAtom::Unit),
        V::Boolean(b) => Some(KeyAtom::Boolean(*b)),
        V::Integer(n) => Some(KeyAtom::Integer(*n)),
        V::Integer8(n) => Some(KeyAtom::Integer8(*n)),
        V::Integer16(n) => Some(KeyAtom::Integer16(*n)),
        V::Integer32(n) => Some(KeyAtom::Integer32(*n)),
        V::UnsignedInteger16(n) => Some(KeyAtom::UnsignedInteger16(*n)),
        V::UnsignedInteger32(n) => Some(KeyAtom::UnsignedInteger32(*n)),
        V::UnsignedInteger64(n) => Some(KeyAtom::UnsignedInteger64(*n)),
        V::Byte(n) => Some(KeyAtom::Byte(*n)),
        V::Character(c) => Some(KeyAtom::Character(*c)),
        V::Decimal(n) => Some(KeyAtom::Decimal(*n)),
        V::String(s) => Some(KeyAtom::String(s)),
        V::Float32(_) | V::Float(_) | V::Ctor { .. } | V::List(_) | V::Map(_) | V::Set(_) => None,
    }
}
/// 値の深さを Rust の呼び出しの深さにしない（AGENTS.md「実装の規約」の「再帰の深さ」）。
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
            (V::Float32(a), V::Float32(b)) if float => {
                let o = a.partial_cmp(b)?;
                if o != Ordering::Equal {
                    return Some(o);
                }
            }
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
fn known_key(
    d: &Decls<'_>,
    e: &Expr,
    map: bool,
    budget: &mut EvalBudget,
) -> Result<(V, Span), EvalError> {
    if !map {
        if bad_shape(d, e).is_some() {
            return Err(EvalError::Unavailable);
        }
        return eval(d, e, budget).map(|v| (v, e.span()));
    }
    if let Expr::Paren(p) = e {
        return known_key(d, &p.inner, true, budget);
    }
    if let Expr::Call(c) = e
        && let Expr::Name(n) = c.callee.as_ref()
        && d.reference(n.id) == d.resolved.stdlib("Benitoite.Pair.Pair")
        && let Some(Arg::Expr(key)) = c.args.first()
        && bad_shape(d, key).is_none()
    {
        return eval(d, key, budget).map(|v| (v, key.span()));
    }
    if bad_shape(d, e).is_some() {
        return Err(EvalError::Unavailable);
    }
    let V::Ctor { args, .. } = eval(d, e, budget)? else {
        return Err(EvalError::Unavailable);
    };
    args.into_iter()
        .next()
        .map(|v| (v, e.span()))
        .ok_or(EvalError::Unavailable)
}
fn duplicate_key_warnings(
    d: &Decls<'_>,
    l: &ListExpr,
    map: bool,
    budget: &mut EvalBudget,
) -> Vec<crate::diag::Diagnostic> {
    let mut diagnostics = vec![];
    let mut keys: Vec<(V, Span)> = vec![];
    for el in &l.elems {
        let ListElem::Expr(e) = el else {
            continue;
        };
        let (value, span) = match known_key(d, e, map, budget) {
            Ok(key) => key,
            Err(EvalError::Limit(..)) => break,
            Err(_) => continue,
        };
        if let Some((_, first)) = keys
            .iter()
            .find(|(v, _)| compare(v, &value, false) == Some(Ordering::Equal))
        {
            diagnostics.push(
                DiagBuilder::new(DiagCode::W0403)
                    .arg("key", key_text(d, &value))
                    .primary(span)
                    .secondary(*first, "first")
                    .build(),
            );
        } else {
            keys.push((value, span));
        }
    }
    diagnostics
}
fn arithmetic_candidate(d: &Decls<'_>, e: &Expr) -> bool {
    match e {
        Expr::Binary(_) | Expr::Unary(_) => bad_shape(d, e).is_none(),
        Expr::Call(c) => {
            (std_call(d, &c.callee, "Benitoite.Integer.absolute")
                || std_call(d, &c.callee, "Benitoite.Integer.floorDivide"))
                && c.args
                    .iter()
                    .all(|a| a.expr().is_some_and(|e| bad_shape(d, e).is_none()))
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
                standard_argument(c, 1, "b")
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
            && eval(ctx.decls, e, &mut EvalBudget::default())
                .ok()
                .is_some_and(|v| match v {
                    V::Integer(n) => n == 0,
                    V::Integer8(n) => n == 0,
                    V::Integer16(n) => n == 0,
                    V::Integer32(n) => n == 0,
                    V::UnsignedInteger16(n) => n == 0,
                    V::UnsignedInteger32(n) => n == 0,
                    V::UnsignedInteger64(n) => n == 0,
                    V::Decimal(n) => n.mantissa() == 0,
                    V::Float32(_)
                    | V::Float(_)
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
        match arithmetic_candidate(ctx.decls, e)
            .then(|| eval(ctx.decls, e, &mut EvalBudget::default()))
        {
            Some(Err(EvalError::Arithmetic(span, condition)))
                if span == e.span() && condition != super::text::DIVISION_BY_ZERO =>
            {
                if let Some(ty) = ctx.expr_types.get(e.id()) {
                    diagnostics.push(
                        DiagBuilder::new(DiagCode::W0402)
                            .arg("ty", ctx.show_type(ty))
                            .primary(span)
                            .build(),
                    );
                }
            }
            _ => {}
        }
        if let Expr::Call(c) = e
            && (std_call(ctx.decls, &c.callee, "Benitoite.Map.fromList")
                || std_call(ctx.decls, &c.callee, "Benitoite.Set.fromList"))
        {
            let map = std_call(ctx.decls, &c.callee, "Benitoite.Map.fromList");
            if let Some(Expr::List(l)) = standard_argument(c, 0, if map { "pairs" } else { "xs" }) {
                // 予算の単位は「警告を調べる一つの式」。fromList の全ての鍵で共有し、
                // 保持する鍵の総量も制限する。上限に達した鍵には警告せず、残りを調べない。
                let mut budget = EvalBudget::default();
                diagnostics.extend(duplicate_key_warnings(ctx.decls, l, map, &mut budget));
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
// 呼び出し側の検査は If 自体を対象にしないので、else if の子だけを同じ順序で辿る。
fn visit_if(i: &IfExpr, f: &mut impl FnMut(&Expr)) {
    visit_expr(&i.cond, f);
    visit_block(&i.then_block, f);
    if let Some(b) = &i.else_branch {
        match b {
            ElseBranch::Block(b) => visit_block(b, f),
            ElseBranch::If(i) => visit_if(i, f),
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
                if let Some(e) = a.expr() {
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
        Expr::If(i) => visit_if(i, f),
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

// 複合値の評価の一時値を入口の再帰の枠から分ける。
#[inline(never)]
fn eval_name(d: &Decls<'_>, n: &NameExpr, budget: &mut EvalBudget) -> EvalResult {
    let id = d.reference(n.id).ok_or(EvalError::Unavailable)?;
    if let Some(v) = d.out.consts.get(id) {
        return budget.clone_value(v, n.span);
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
fn eval_interp(d: &Decls<'_>, i: &InterpExpr, budget: &mut EvalBudget) -> EvalResult {
    // 各段の値は通常どおり予算に数え、出力の全長を求めてから一度だけ確保する。
    budget.charge(i.segments.len().saturating_mul(size_of::<String>()), i.span)?;
    let mut fragments = Vec::with_capacity(i.segments.len());
    let mut len = i.head.len();
    for s in &i.segments {
        let value = eval(d, &s.expr, budget)?;
        let fragment = if let V::String(text) = value {
            text
        } else {
            // 基本型の書式化は最大でも 128 バイト未満。文字列の値は移動し、複製しない。
            budget.charge(128, s.expr.span())?;
            value_text(&value).ok_or(EvalError::Unavailable)?
        };
        len = len
            .saturating_add(fragment.len())
            .saturating_add(s.tail.len());
        fragments.push(fragment);
    }
    budget.string(len, i.span)?;
    let mut text = String::with_capacity(len);
    text.push_str(&i.head);
    for (fragment, segment) in fragments.iter().zip(&i.segments) {
        text.push_str(fragment);
        text.push_str(&segment.tail);
    }
    Ok(V::String(text))
}

#[inline(never)]
fn eval_list(d: &Decls<'_>, l: &ListExpr, budget: &mut EvalBudget) -> EvalResult {
    budget.slots(l.elems.len(), l.span)?;
    let mut out = Vec::with_capacity(l.elems.len());
    for el in &l.elems {
        match el {
            ListElem::Expr(e) => {
                budget.list(out.len().saturating_add(1), l.span)?;
                let value = eval(d, e, budget)?;
                reserve_values(&mut out, 1, budget, l.span)?;
                out.push(value);
            }
            ListElem::Spread(s) => {
                if let V::List(v) = eval(d, &s.expr, budget)? {
                    budget.list(out.len().saturating_add(v.len()), l.span)?;
                    reserve_values(&mut out, v.len(), budget, l.span)?;
                    out.extend(v);
                } else {
                    return Err(EvalError::Unavailable);
                }
            }
        }
    }
    Ok(V::List(out))
}

// 展開を含むリストは全長が先に分からない。幾何的に領域を増やして伸長を二乗の手間にせず、
// 新しい領域の全体を確保前に数える（移動する入れ子の値の確保は既に数えている）。
fn reserve_values(
    out: &mut Vec<V>,
    additional: usize,
    budget: &mut EvalBudget,
    span: Span,
) -> Result<(), EvalError> {
    let needed = out.len().saturating_add(additional);
    if needed > out.capacity() {
        let capacity = needed.max(out.capacity().saturating_mul(2));
        budget.slots(capacity, span)?;
        out.reserve_exact(capacity.saturating_sub(out.len()));
    }
    Ok(())
}

#[inline(never)]
fn eval_record(d: &Decls<'_>, r: &RecordExpr, budget: &mut EvalBudget) -> EvalResult {
    let id = d.reference(r.id).ok_or(EvalError::Unavailable)?;
    let fields = d
        .out
        .adts
        .get(id)
        .and_then(|a| a.record.as_ref())
        .ok_or(EvalError::Unavailable)?;
    budget.slots(fields.len(), r.span)?;
    let mut args = Vec::with_capacity(fields.len());
    for f in fields {
        let arg = r
            .fields
            .iter()
            .find(|arg| arg.name.text == f.name)
            .ok_or(EvalError::Unavailable)?;
        args.push(eval(d, &arg.value, budget)?);
    }
    Ok(V::Ctor {
        adt: id,
        tag: 0,
        args,
    })
}

#[inline(never)]
fn eval_unary(d: &Decls<'_>, u: &UnaryExpr, budget: &mut EvalBudget) -> EvalResult {
    let v = eval(d, &u.operand, budget)?;
    match (u.op, v) {
        (UnOp::Not, V::Boolean(b)) => Ok(V::Boolean(!b)),
        (UnOp::Neg, V::Integer(n)) => n
            .checked_neg()
            .map(V::Integer)
            .ok_or(EvalError::Arithmetic(u.span, super::text::INTEGER_OVERFLOW)),
        (UnOp::Neg, V::Integer8(n)) => numeric::integer_negate(n)
            .map(V::Integer8)
            .map_err(|e| arithmetic_error(e, u.span)),
        (UnOp::Neg, V::Integer16(n)) => numeric::integer_negate(n)
            .map(V::Integer16)
            .map_err(|e| arithmetic_error(e, u.span)),
        (UnOp::Neg, V::Integer32(n)) => numeric::integer_negate(n)
            .map(V::Integer32)
            .map_err(|e| arithmetic_error(e, u.span)),
        (UnOp::Neg, V::Float32(n)) => Ok(V::Float32(-n)),
        (UnOp::Neg, V::Float(n)) => Ok(V::Float(-n)),
        (UnOp::Neg, V::Decimal(n)) => Ok(V::Decimal(n.negate())),
        _ => Err(EvalError::Unavailable),
    }
}

#[inline(never)]
fn eval_binary(d: &Decls<'_>, b: &BinaryExpr, budget: &mut EvalBudget) -> EvalResult {
    let lhs = eval(d, &b.lhs, budget)?;
    if b.op == BinOp::And && matches!(lhs, V::Boolean(false)) {
        return Ok(lhs);
    }
    if b.op == BinOp::Or && matches!(lhs, V::Boolean(true)) {
        return Ok(lhs);
    }
    binary(b.op, lhs, eval(d, &b.rhs, budget)?, b.span, budget)
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す。ソースの準備の失敗もテストの失敗である。
    #![allow(clippy::expect_used, clippy::panic)]
    // 小さい上限を評価器に渡し、実際の連結と値の複製が拒否する境界を確かめる。
    // 1 GiB の値をテストで作らないための、T7 で指定された評価器の単体テストである。
    use super::*;
    use crate::base::{BytePos, FileId};

    #[test]
    fn duplicate_key_display_is_bounded_at_utf8_boundaries() {
        // 公開の型検査の診断で、上限ちょうど・超過・多バイト文字・構造の走査を確かめる。
        // 短い鍵の表記のテストでは、出力を無制限にする退行を捕まえられない。
        let exact = format!("\"{}\"", "a".repeat(4094));
        for (value, expected) in [
            (exact.clone(), exact),
            (
                format!("\"{}\"", "a".repeat(4095)),
                format!("\"{}…", "a".repeat(4092)),
            ),
            (
                format!("\"{}\"", "あ".repeat(2048)),
                format!("\"{}…", "あ".repeat(1364)),
            ),
            (
                format!("[{}]", vec!["1000000000"; 400].join(", ")),
                format!("[{}…", "1000000000, ".repeat(341)),
            ),
        ] {
            let source = format!(
                "import Benitoite.Set\nfunction f() -> Unit\n bind _ <- Set.fromList([{value}, {value}])\nend function\n"
            );
            let (_, _, _, diagnostics) =
                crate::typeck::test_support::check_files(&[("main.bnt", &source)], false);
            assert_eq!(diagnostics.len(), 1, "{diagnostics:#?}");
            let actual = diagnostics
                .first()
                .expect("duplicate key diagnostic")
                .message
                .as_str();
            let expected = format!("the key `{expected}` appears more than once");
            assert!(
                actual == expected,
                "value bytes {}, actual bytes {}, expected bytes {}, tails {:?} / {:?}",
                value.len(),
                actual.len(),
                expected.len(),
                actual.get(actual.len().saturating_sub(50)..),
                expected.get(expected.len().saturating_sub(50)..)
            );
        }
    }

    #[test]
    fn duplicate_key_headings_use_show_notation() {
        for (decls, ty, value, shown) in [
            ("", "String", "\"a\\nb\"", "\"a\\nb\""),
            (
                "data Color\n Rgb(Integer, Integer)\n Red\nend data\n",
                "Color",
                "Color.Rgb(1, 2)",
                "Color.Rgb(1, 2)",
            ),
            (
                "record Point\n x: Integer\n y: Integer\nend record\n",
                "Point",
                "Point(x: 1, y: 2)",
                "Point(x: 1, y: 2)",
            ),
            ("", "List[Integer]", "[1, 2]", "[1, 2]"),
            (
                "",
                "Set[Integer]",
                "Set.fromList([2, 1])",
                "Set.fromList([1, 2])",
            ),
            (
                "",
                "Map[Integer, String]",
                "Map.fromList([Pair(2, \"b\"), Pair(1, \"a\")])",
                "Map.fromList([Pair(1, \"a\"), Pair(2, \"b\")])",
            ),
            ("", "Character", "'\\n'", "'\\n'"),
            (
                "",
                "Pair[Integer, String]",
                "Pair(1, \"x\")",
                "Pair(1, \"x\")",
            ),
            (
                "data Color\n Red\n Blue\nend data\n",
                "Color",
                "Color.Red",
                "Color.Red",
            ),
        ] {
            let source = format!(
                "import Benitoite.Set\nimport Benitoite.Map\n{decls}function f() -> Unit\n bind _ <- Set.fromList([{value}, {value}])\nend function\n"
            );
            let (_, _, _, diagnostics) =
                crate::typeck::test_support::check_files(&[("main.bnt", &source)], false);
            assert_eq!(diagnostics.len(), 1, "{source}: {diagnostics:#?}");
            assert_eq!(
                diagnostics.first().map(|d| d.code),
                Some(Some(DiagCode::W0403))
            );
            assert_eq!(
                diagnostics.first().map(|d| d.message.as_str()),
                Some(format!("the key `{shown}` appears more than once").as_str())
            );
            let source = format!(
                "import Benitoite.Set\nimport Benitoite.Map\n{decls}const keys: Set[{ty}] = Set.fromList([{value}, {value}])\n"
            );
            let (_, _, _, diagnostics) =
                crate::typeck::test_support::check_files(&[("main.bnt", &source)], false);
            assert_eq!(diagnostics.len(), 1, "{source}: {diagnostics:#?}");
            assert_eq!(
                diagnostics.first().map(|d| d.code),
                Some(Some(DiagCode::E0436))
            );
            assert_eq!(
                diagnostics.first().map(|d| d.message.as_str()),
                Some(format!("the key `{shown}` appears more than once in a constant").as_str())
            );
        }
    }

    #[test]
    fn single_value_limits_allow_the_boundary_and_reject_the_next_size() {
        // spec: 01-06 定数の型（初回リリース版）
        let span = Span {
            file: FileId(0),
            start: BytePos(0),
            end: BytePos(1),
        };
        for (string_bytes, list_len, string_ok, list_ok) in
            [(4, 2, true, true), (3, 1, false, false)]
        {
            let limits = EvalLimits {
                string_bytes,
                list_len,
                budget: 4096,
            };
            let mut budget = EvalBudget { limits, used: 0 };
            let result = binary(
                BinOp::Add,
                V::String("ab".into()),
                V::String("cd".into()),
                span,
                &mut budget,
            );
            if string_ok {
                assert!(matches!(result, Ok(V::String(s)) if s == "abcd"));
            } else {
                assert!(matches!(result, Err(EvalError::Limit(s, EvalLimit::String)) if s == span));
            }
            let mut budget = EvalBudget { limits, used: 0 };
            let value = V::List(vec![V::Integer(1), V::Integer(2)]);
            let result = budget.clone_value(&value, span);
            if list_ok {
                assert!(matches!(result, Ok(V::List(v)) if v.len() == 2));
            } else {
                assert!(matches!(result, Err(EvalError::Limit(s, EvalLimit::List)) if s == span));
            }
        }
    }

    // 本物の読み込み・名前解決・型検査で作った式と値の表を、小さい上限で再評価する。
    fn with_const_expr(source: &str, f: impl FnOnce(&Decls<'_>, &Expr)) {
        let (load, resolved, out, diagnostics) =
            crate::typeck::test_support::check_files(&[("main.bnt", source)], false);
        assert!(diagnostics.is_empty(), "{diagnostics:#?}");
        let expr = load
            .asts
            .iter()
            .flat_map(|m| &m.decls)
            .find_map(|top| {
                if let Item::Const(c) = &top.item {
                    Some(&c.value)
                } else {
                    None
                }
            })
            .expect("fixture must contain a constant");
        let mut d = Decls::new(&load.modules, &load.asts, &load.sources, &resolved);
        d.out = out;
        f(&d, expr);
    }

    #[test]
    fn duplicate_key_warning_stops_at_the_second_key_when_budget_is_exhausted() {
        // spec: 01-06 定数の型（初回リリース版）
        // 関門: fromList 全体の予算を守る。鍵ごとに予算を作り直す退行と、超過後に
        // 調査を再開する退行を捕まえる。既存の W0403 のテストは予算の境界を扱わない。
        with_const_expr(
            "const keys: List[String] = [\"abc\", \"abc\", \"x\", \"x\"]\n",
            |d, e| {
                let Expr::List(l) = e else {
                    panic!("fixture must be a list")
                };
                let mut budget = EvalBudget::default();
                let full = duplicate_key_warnings(d, l, false, &mut budget);
                assert_eq!(full.len(), 2);
                assert!(full.iter().all(|d| d.code == Some(DiagCode::W0403)));

                // 最初の文字列だけを評価できる。二つ目で止まり、後ろの短い鍵も調べない。
                let mut budget = EvalBudget {
                    limits: EvalLimits {
                        budget: size_of::<V>().saturating_mul(2).saturating_add(3),
                        ..EvalLimits::default()
                    },
                    used: 0,
                };
                assert!(duplicate_key_warnings(d, l, false, &mut budget).is_empty());
            },
        );
    }

    #[test]
    fn spread_list_checks_the_length_after_expansion() {
        // spec: 01-06 定数の型（初回リリース版）
        // 関門: 展開後の全長を制限する。元のリストと展開元だけを検査する退行を捕まえる。
        // 既存の上限テストは値の複製だけを扱い、展開の組み立てには届かない。
        with_const_expr("const xs: List[Integer] = [1, ..[2, 3]]\n", |d, e| {
            for (list_len, allowed) in [(3, true), (2, false)] {
                let mut budget = EvalBudget {
                    limits: EvalLimits {
                        list_len,
                        budget: 4096,
                        ..EvalLimits::default()
                    },
                    used: 0,
                };
                let result = eval(d, e, &mut budget);
                if allowed {
                    assert!(
                        matches!(result, Ok(V::List(v)) if matches!(v.as_slice(), [V::Integer(1), V::Integer(2), V::Integer(3)]))
                    );
                } else {
                    assert!(
                        matches!(result, Err(EvalError::Limit(span, EvalLimit::List)) if span == e.span())
                    );
                }
            }
        });
    }

    #[test]
    fn interpolation_counts_the_output_once() {
        // spec: 01-06 定数の型（初回リリース版）
        // 関門: 最終文字列と段の値が収まる予算で補間できることを守る。
        // 各段の累積長を重ねて数える退行を捕まえる。上限のテストとは別の契約である。
        let fragment = "a".repeat(256);
        let segment = format!("${{\"{fragment}\"}}");
        let source = format!("const text: String = \"{}\"\n", segment.repeat(5));
        with_const_expr(&source, |d, e| {
            let mut budget = EvalBudget {
                limits: EvalLimits {
                    budget: 4096,
                    ..EvalLimits::default()
                },
                used: 0,
            };
            assert!(
                matches!(eval(d, e, &mut budget), Ok(V::String(text)) if text == fragment.repeat(5))
            );
        });
    }
}
