//! 型検査済みの直接呼び出しの定数引数を追加検査する（設計書 02-05「本体の後の検査」）。

use super::consts::{self, ConstKnowledge, EvalBudget};
use super::decls::Decls;
use crate::base::BindingId;
use crate::builtins::{checked_regex, checked_scope};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{Block, CallExpr, Expr};
use crate::types::ConstValue;
use std::collections::{BTreeMap, BTreeSet};

// 暫定の組み立て予算。定数取得の64 MiBとは独立に数える
// （設計書 02-05「定数の検査と評価」）。
const REGEX_PATTERN_BYTES: usize = 1024 * 1024;
const REGEX_TOTAL_BYTES: usize = 8 * 1024 * 1024;
const REGEX_PATTERN_COUNT: usize = 256;
const CONST_ORIGIN_LABELS: usize = 8;

/// 追加検査の予算と同一入力の判定。Declsと同じ一検査の間だけ保持する。
pub(super) struct CheckedArgsState {
    budget: EvalBudget,
    regex_bytes: usize,
    regex: BTreeMap<String, Option<(DiagCode, String)>>,
    origins: BTreeMap<BTreeSet<BindingId>, OriginLabels>,
}

struct OriginLabels {
    selected: BTreeSet<BindingId>,
    omitted: usize,
}

impl Default for CheckedArgsState {
    fn default() -> Self {
        Self {
            budget: EvalBudget::traced(),
            regex_bytes: 0,
            regex: BTreeMap::new(),
            origins: BTreeMap::new(),
        }
    }
}

impl CheckedArgsState {
    fn regex(&mut self, source: &str) -> Option<(DiagCode, String)> {
        if let Some(result) = self.regex.get(source) {
            return result.clone();
        }
        let total = self.regex_bytes.saturating_add(source.len());
        if source.len() > REGEX_PATTERN_BYTES
            || total > REGEX_TOTAL_BYTES
            || self.regex.len() >= REGEX_PATTERN_COUNT
        {
            return None;
        }
        self.regex_bytes = total;
        let result = match checked_regex::compile(source) {
            Ok(_) => None,
            Err(error) => {
                let code = match &error {
                    ::regex::Error::Syntax(_) => Some(DiagCode::E0457),
                    ::regex::Error::CompiledTooBig(_) => Some(DiagCode::E0458),
                    // regex::Errorはnon_exhaustiveである。将来の失敗は実行時へ残す。
                    _ => None,
                };
                code.map(|code| (code, checked_regex::compile_error(error)))
            }
        };
        self.regex.insert(source.to_owned(), result.clone());
        result
    }
}

pub(super) fn check(d: &mut Decls<'_>, block: &Block) {
    let mut calls = vec![];
    consts::visit_block(block, &mut |expr| {
        if let Expr::Call(call) = expr
            && let Some(plan) = d.out.call_plans.get(call.id)
            && plan.direct_callee.is_some()
            && let Some(target) = Target::of(d, &call.callee)
        {
            calls.push((call, target));
        }
    });
    // 訪問の再帰順ではなくソース位置を予算の消費順にする。パイプと穴はCallPlanで除外済み。
    calls.sort_by_key(|(call, _)| call.span.start.0);
    let mut state = std::mem::take(&mut d.checked_args);
    for (call, target) in calls {
        if !matches!(target, Target::Regex) {
            check_scope(d, call, target, &mut state);
            continue;
        }
        let Some(argument) = consts::standard_argument(call, 0, "source") else {
            continue;
        };
        match consts::argument(d, argument, &mut state.budget) {
            ConstKnowledge::Known {
                value: ConstValue::String(source),
                argument_span,
                const_origins,
            } => {
                if let Some((code, reason)) = state.regex(&source) {
                    let mut diagnostic = DiagBuilder::new(code)
                        .arg("reason", reason)
                        .primary(argument_span);
                    diagnostic = origin_labels(d, &mut state, diagnostic, &const_origins);
                    d.diagnostics.push(diagnostic.build());
                }
            }
            ConstKnowledge::Known { .. }
            | ConstKnowledge::Unknown
            | ConstKnowledge::BudgetExceeded
            | ConstKnowledge::Invalid => {}
        }
    }
    d.checked_args = state;
}

#[derive(Clone, Copy)]
enum Target {
    Regex,
    Host,
    Path,
    Endpoint,
}

impl Target {
    fn of(d: &Decls<'_>, callee: &Expr) -> Option<Self> {
        [
            ("Benitoite.Regex.compile", Self::Regex),
            ("Benitoite.Scope.checkHost", Self::Host),
            ("Benitoite.Scope.checkPath", Self::Path),
            ("Benitoite.Scope.checkEndpoint", Self::Endpoint),
        ]
        .into_iter()
        .find_map(|(name, target)| consts::std_call(d, callee, name).then_some(target))
    }
}

fn known_string(value: &ConstKnowledge) -> Option<&str> {
    match value {
        ConstKnowledge::Known {
            value: ConstValue::String(s),
            ..
        } => Some(s),
        ConstKnowledge::Known { .. }
        | ConstKnowledge::Unknown
        | ConstKnowledge::BudgetExceeded
        | ConstKnowledge::Invalid => None,
    }
}

fn known_integer(value: &ConstKnowledge) -> Option<i64> {
    match value {
        ConstKnowledge::Known {
            value: ConstValue::Integer(n),
            ..
        } => Some(*n),
        ConstKnowledge::Known { .. }
        | ConstKnowledge::Unknown
        | ConstKnowledge::BudgetExceeded
        | ConstKnowledge::Invalid => None,
    }
}

fn check_scope(d: &mut Decls<'_>, call: &CallExpr, target: Target, state: &mut CheckedArgsState) {
    let names: &[&str] = match target {
        Target::Host => &["pattern", "host"],
        Target::Path => &["pattern", "path"],
        Target::Endpoint => &["hostPattern", "host", "minimumPort", "maximumPort", "port"],
        Target::Regex => return,
    };
    let mut arguments: Vec<_> = names
        .iter()
        .enumerate()
        .filter_map(|(i, name)| consts::standard_argument(call, i, name).map(|expr| (i, expr)))
        .collect();
    arguments.sort_by_key(|(_, expr)| expr.span().start.0);
    let mut values: [ConstKnowledge; 5] = std::array::from_fn(|_| ConstKnowledge::Unknown);
    for (i, argument) in arguments {
        if let Some(value) = values.get_mut(i) {
            *value = consts::argument(d, argument, &mut state.budget);
        }
    }
    let mut iter = values.iter();
    let pattern = iter.next().and_then(known_string);
    let input = iter.next().and_then(known_string);
    let minimum = iter.next().and_then(known_integer);
    let maximum = iter.next().and_then(known_integer);
    let port = iter.next().and_then(known_integer);
    let result = match target {
        Target::Host => checked_scope::check_host(pattern, input),
        Target::Path => checked_scope::check_path(pattern, input),
        Target::Endpoint => checked_scope::check_endpoint(pattern, input, minimum, maximum, port),
        Target::Regex => return,
    };
    // 位置は契約順に引き直す。取得の予算を消費したソース順とは別に保つ。
    if let Err(failure) = result {
        scope_diagnostic(d, state, call, names, failure, &values);
    }
}

fn scope_diagnostic(
    d: &mut Decls<'_>,
    state: &mut CheckedArgsState,
    call: &CallExpr,
    names: &[&str],
    failure: checked_scope::Failure,
    values: &[ConstKnowledge; 5],
) {
    use checked_scope::Failure as F;
    let (code, primary, related): (_, usize, &[usize]) = match failure {
        F::InvalidPattern(_) => (DiagCode::E0459, 0, &[]),
        F::InvalidTarget(_) => (DiagCode::E0460, 1, &[]),
        F::InvalidMinimum => (DiagCode::E0461, 2, &[]),
        F::InvalidMaximum => (DiagCode::E0461, 3, &[]),
        F::InvalidBounds => (DiagCode::E0461, 3, &[2]),
        F::InvalidPort => (DiagCode::E0461, 4, &[]),
        F::OutsideScope => (DiagCode::E0462, 1, &[0]),
        F::PortOutsideScope => (DiagCode::E0462, 4, &[2, 3]),
    };
    let Some(ConstKnowledge::Known { argument_span, .. }) = values.get(primary) else {
        return;
    };
    let mut diagnostic = DiagBuilder::new(code).primary(*argument_span);
    if let F::InvalidPattern(reason) | F::InvalidTarget(reason) = failure {
        diagnostic = diagnostic.arg("reason", reason);
    }
    let mut origins = std::collections::BTreeSet::new();
    for index in std::iter::once(&primary).chain(related) {
        if let Some(ConstKnowledge::Known { const_origins, .. }) = values.get(*index) {
            origins.extend(const_origins.iter().copied());
        }
    }
    for index in related {
        if let Some(argument) = names
            .get(*index)
            .and_then(|name| consts::standard_argument(call, *index, name))
        {
            diagnostic = diagnostic.secondary(argument.span(), "condition");
        }
    }
    diagnostic = origin_labels(d, state, diagnostic, &origins);
    d.diagnostics.push(diagnostic.build());
}

// 直接参照を優先し、残りの位置には値の出どころを示す。途中の宣言も省略数には含める。
// constの依存関係は本体の検査中に変わらないため、同じ直接参照の診断で走査を再利用する
// （設計書 02-05「本体の後の検査」）。位置の集合と正確な省略数だけを保存する。
fn origin_labels(
    d: &Decls<'_>,
    state: &mut CheckedArgsState,
    mut diagnostic: DiagBuilder,
    direct: &BTreeSet<BindingId>,
) -> DiagBuilder {
    let labels = state
        .origins
        .entry(direct.clone())
        .or_insert_with(|| select_origin_labels(d, direct));
    for id in &labels.selected {
        if let Some(span) = d.resolved.bindings.get(*id).and_then(|b| b.span) {
            diagnostic = diagnostic.secondary(span, "constant");
        }
    }
    if labels.omitted > 0 {
        diagnostic = diagnostic
            .arg("omitted", labels.omitted.to_string())
            .note("origins_omitted");
    }
    diagnostic
}

fn select_origin_labels(d: &Decls<'_>, direct: &BTreeSet<BindingId>) -> OriginLabels {
    let mut selected: BTreeSet<_> = direct.iter().copied().take(CONST_ORIGIN_LABELS).collect();
    let mut visited = BTreeSet::new();
    let mut work: Vec<_> = direct.iter().rev().copied().collect();
    while let Some(id) = work.pop() {
        if !visited.insert(id) {
            continue;
        }
        match d.const_origins.get(id) {
            Some(deps) if !deps.is_empty() => work.extend(deps.iter().rev().copied()),
            Some(_) | None => {
                if selected.len() < CONST_ORIGIN_LABELS {
                    selected.insert(id);
                }
            }
        }
    }
    let omitted = visited.len().saturating_sub(selected.len());
    OriginLabels { selected, omitted }
}
