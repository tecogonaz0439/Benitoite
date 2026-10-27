//! 保存済みの結果から非実行報告を集計する（設計書 02-05「区間解析の報告の集計」）。

use super::budget::{LimitFailure, Resource, Scope, StopReason};
use super::{Coverage, IdentityStop, Report};

/// 解析範囲。型とエフェクトの検査の完了や安全性を意味しない。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum IntervalCoverage {
    All,
    Some,
    #[default]
    None,
}

/// 段停止の資源別件数。本体の停止件数とは重ねない。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct IntervalBudgetStops {
    pub body_operations: u64,
    pub body_items: u64,
    pub whole_operations: u64,
    pub whole_items: u64,
}

impl IntervalBudgetStops {
    fn add(&mut self, failure: LimitFailure) {
        let count = match (failure.scope, failure.resource) {
            (Scope::Body, Resource::Operations) => &mut self.body_operations,
            (Scope::Body, Resource::Items) => &mut self.body_items,
            (Scope::Whole, Resource::Operations) => &mut self.whole_operations,
            (Scope::Whole, Resource::Items) => &mut self.whole_items,
        };
        *count = count.saturating_add(1);
    }

    fn merge(&mut self, other: Self) {
        self.body_operations = self.body_operations.saturating_add(other.body_operations);
        self.body_items = self.body_items.saturating_add(other.body_items);
        self.whole_operations = self.whole_operations.saturating_add(other.whole_operations);
        self.whole_items = self.whole_items.saturating_add(other.whole_items);
    }
}

/// 入口・発見・待ち行列・別本体制御と検査全体の停止事象。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct IntervalPhaseStops {
    pub exceeded: IntervalBudgetStops,
    pub unidentified: IntervalBudgetStops,
    pub depth: u64,
    pub other: u64,
}

impl IntervalPhaseStops {
    fn add(&mut self, stop: IdentityStop) {
        match stop {
            IdentityStop::AnalysisBudget(StopReason::Exceeded(f)) => self.exceeded.add(f),
            IdentityStop::AnalysisBudget(StopReason::Unidentified(f)) => self.unidentified.add(f),
            IdentityStop::Depth => self.depth = self.depth.saturating_add(1),
            IdentityStop::NumberOverflow
            | IdentityStop::Input(_)
            | IdentityStop::MissingReference(_)
            | IdentityStop::MissingScheme(_)
            | IdentityStop::MissingConstant(_)
            | IdentityStop::MissingLiteral(_)
            | IdentityStop::MissingTryKind(_)
            | IdentityStop::Unmapped(_) => self.other = self.other.saturating_add(1),
        }
    }
}

/// 実消費。全体操作数には、本体の外のモジュール分類も含む。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct IntervalUsage {
    pub operations: u64,
    pub saved_items: u64,
    pub peak_items: u64,
    pub max_body_operations: u64,
    pub max_body_items: u64,
}

/// 一検査の区間解析の集計。program の有無と独立して保持する。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct IntervalAnalysis {
    pub coverage: IntervalCoverage,
    pub input_definitions: u64,
    pub unsupported_bodies: u64,
    pub body_budget_exceeded: u64,
    pub whole_budget_skipped: u64,
    pub unidentified_bodies: u64,
    pub phase_stops: IntervalPhaseStops,
    pub usage: IntervalUsage,
}

impl IntervalAnalysis {
    /// 正常な空の探索の集計。未着手は Default の None で表す。
    pub fn empty() -> Self {
        Self {
            coverage: IntervalCoverage::All,
            ..Self::default()
        }
    }

    /// Target の和。重複した入口も別検査として数える。
    pub fn aggregate<'a>(targets: impl IntoIterator<Item = &'a Self>) -> Self {
        let mut result = Self::empty();
        let mut any = false;
        let mut all_none = true;
        for target in targets {
            any = true;
            all_none &= target.coverage == IntervalCoverage::None;
            if target.coverage != IntervalCoverage::All {
                result.coverage = IntervalCoverage::Some;
            }
            result.input_definitions = result
                .input_definitions
                .saturating_add(target.input_definitions);
            result.unsupported_bodies = result
                .unsupported_bodies
                .saturating_add(target.unsupported_bodies);
            result.body_budget_exceeded = result
                .body_budget_exceeded
                .saturating_add(target.body_budget_exceeded);
            result.whole_budget_skipped = result
                .whole_budget_skipped
                .saturating_add(target.whole_budget_skipped);
            result.unidentified_bodies = result
                .unidentified_bodies
                .saturating_add(target.unidentified_bodies);
            result
                .phase_stops
                .exceeded
                .merge(target.phase_stops.exceeded);
            result
                .phase_stops
                .unidentified
                .merge(target.phase_stops.unidentified);
            result.phase_stops.depth = result
                .phase_stops
                .depth
                .saturating_add(target.phase_stops.depth);
            result.phase_stops.other = result
                .phase_stops
                .other
                .saturating_add(target.phase_stops.other);
            result.usage.operations = result
                .usage
                .operations
                .saturating_add(target.usage.operations);
            result.usage.saved_items = result
                .usage
                .saved_items
                .saturating_add(target.usage.saved_items);
            result.usage.peak_items = result.usage.peak_items.max(target.usage.peak_items);
            result.usage.max_body_operations = result
                .usage
                .max_body_operations
                .max(target.usage.max_body_operations);
            result.usage.max_body_items =
                result.usage.max_body_items.max(target.usage.max_body_items);
        }
        if any && all_none {
            result.coverage = IntervalCoverage::None;
        }
        result
    }
}

fn whole_cause(stop: IdentityStop) -> bool {
    matches!(
        stop,
        IdentityStop::AnalysisBudget(
            StopReason::Exceeded(LimitFailure {
                scope: Scope::Whole,
                ..
            }) | StopReason::Unidentified(LimitFailure {
                scope: Scope::Whole,
                ..
            })
        )
    )
}

fn whole_exceeded(stop: IdentityStop) -> bool {
    matches!(
        stop,
        IdentityStop::AnalysisBudget(StopReason::Exceeded(LimitFailure {
            scope: Scope::Whole,
            ..
        }))
    )
}

impl Report {
    pub fn summary(&self) -> IntervalAnalysis {
        if !self.started {
            return IntervalAnalysis::default();
        }
        let mut summary = IntervalAnalysis {
            input_definitions: self.input_definitions,
            ..IntervalAnalysis::empty()
        };
        let mut incomplete = self.remaining.is_some() || !self.remaining_modules.is_empty();
        for body in &self.bodies {
            incomplete |= body.coverage != Coverage::Prepared;
            if body
                .flow
                .as_ref()
                .is_some_and(|a| a.unsupported || a.independent.iter().any(|i| i.unsupported))
            {
                summary.unsupported_bodies = summary.unsupported_bodies.saturating_add(1);
                incomplete = true;
            }
            match body.coverage {
                Coverage::Stopped(IdentityStop::AnalysisBudget(StopReason::Exceeded(
                    LimitFailure {
                        scope: Scope::Body, ..
                    },
                ))) => {
                    summary.body_budget_exceeded = summary.body_budget_exceeded.saturating_add(1)
                }
                Coverage::Stopped(IdentityStop::AnalysisBudget(StopReason::Unidentified(_))) => {
                    summary.unidentified_bodies = summary.unidentified_bodies.saturating_add(1)
                }
                Coverage::Stopped(stop) if whole_exceeded(stop) => {
                    summary.whole_budget_skipped = summary.whole_budget_skipped.saturating_add(1)
                }
                Coverage::None | Coverage::Prepared | Coverage::Stopped(_) => {}
            }
            summary.usage.max_body_operations =
                summary.usage.max_body_operations.max(body.usage.operations);
            summary.usage.max_body_items = summary.usage.max_body_items.max(body.usage.peak);
        }
        // root がない入口停止を bodyStops へ混ぜない。根の並びは definitions と同じ。
        for definition in &self.definitions {
            let root = definition.root.and_then(|index| self.bodies.get(index));
            incomplete |= definition.incomplete();
            let stops = [
                definition.prepared.and_then(Result::err),
                definition.discovery.and_then(Result::err),
                definition.queue.and_then(Result::err),
                definition.embedded_stop,
            ];
            for stop in stops.into_iter().flatten() {
                summary.phase_stops.add(stop);
            }
            if definition.pending.is_empty()
                && !root
                    .is_some_and(|b| matches!(b.coverage, Coverage::Stopped(s) if whole_cause(s)))
                && stops.into_iter().flatten().any(whole_exceeded)
            {
                summary.whole_budget_skipped = summary.whole_budget_skipped.saturating_add(1);
            }
            if definition.embedded_stop.is_some_and(whole_cause) {
                summary.whole_budget_skipped = summary
                    .whole_budget_skipped
                    .saturating_add(u64::try_from(definition.pending.len()).unwrap_or(u64::MAX));
            }
        }
        if let Some(stop) = self.stopped {
            summary.phase_stops.add(IdentityStop::AnalysisBudget(stop));
            incomplete = true;
            if whole_cause(IdentityStop::AnalysisBudget(stop)) {
                summary.whole_budget_skipped = summary
                    .whole_budget_skipped
                    .saturating_add(self.remaining_definitions);
            }
        }
        if incomplete {
            summary.coverage = IntervalCoverage::Some;
        }
        if self.input_definitions == 0 && self.bodies.iter().any(|b| b.coverage == Coverage::None) {
            summary.coverage = IntervalCoverage::None;
        }
        summary.usage.operations = self.whole.operations;
        summary.usage.saved_items = self.whole.saved;
        summary.usage.peak_items = self.whole.peak;
        summary
    }
}
