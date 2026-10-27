//! 区間解析の内部入力（設計書 02-05「区間解析の内部入力」）。
//! 型とエフェクトの検査結果を変更せず、推論の文脈の寿命から入力を切り離す。

pub(super) mod arithmetic;
pub(super) mod budget;
pub(super) mod diagnostics;
mod discovery;
pub(super) mod domain;
pub(super) mod environment;
mod fixed_domain;
pub(super) mod flow;
pub(super) mod identity;
pub(super) mod input;
mod observation;
mod origins;
mod summary;

pub use summary::{
    IntervalAnalysis, IntervalBudgetStops, IntervalCoverage, IntervalPhaseStops, IntervalUsage,
};

#[cfg(test)]
mod tests;

use crate::base::{BindingId, ModuleId, NodeId};
use crate::modules::{ModuleKind, ModuleTable};
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Module;
use budget::{Budget, Item, Lifetime, StopReason};
use identity::{IdentityMap, IdentityStop};
use input::{BodyInput, BodySource, Definition, InputError, InputTables, SourceOrder};
use std::collections::BTreeMap;

/// 型の収集と番号付けの状態。値の解析の完了を表す all と混同しない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum Coverage {
    None,
    Prepared,
    Stopped(IdentityStop),
}

#[derive(Debug)]
/// 元定義一つの準備・停止と予算の実消費。
pub(in crate::typeck) struct BodyReport {
    pub name: String,
    pub coverage: Coverage,
    pub usage: budget::BodyState,
    pub flow: Option<Box<flow::Analysis>>,
}

/// 入口・発見・待ち行列と別本体の制御を、本体自身の停止から分けて残す。
#[derive(Debug)]
pub(in crate::typeck) struct DefinitionPhases {
    pub root: Option<usize>,
    pub prepared: Option<Result<(), IdentityStop>>,
    pub discovery: Option<Result<(), IdentityStop>>,
    pub queue: Option<Result<(), IdentityStop>>,
    pub discovered: Vec<(String, bool)>,
    pub pending: Vec<String>,
    pub embedded_stop: Option<IdentityStop>,
}

impl DefinitionPhases {
    fn incomplete(&self) -> bool {
        self.prepared != Some(Ok(()))
            || self.discovery != Some(Ok(()))
            || self.queue != Some(Ok(()))
            || self.discovered.iter().any(|(_, ready)| !ready)
            || !self.pending.is_empty()
            || self.embedded_stop.is_some()
    }
}

/// AST の寿命を持たない内部の記録。CLI への公開は報告の接続で行う。
#[derive(Debug, Default)]
pub(crate) struct Report {
    pub(in crate::typeck) bodies: Vec<BodyReport>,
    pub(in crate::typeck) definitions: Vec<DefinitionPhases>,
    pub(in crate::typeck) remaining: Option<SourceOrder>,
    pub(in crate::typeck) remaining_modules: Vec<ModuleId>,
    pub(in crate::typeck) stopped: Option<StopReason>,
    pub(in crate::typeck) whole: budget::WholeState,
    pub(in crate::typeck) input_definitions: u64,
    pub(in crate::typeck) remaining_definitions: u64,
    pub(in crate::typeck) started: bool,
}

/// 収集は finish 前、消費は全本体の型検査後。未収集と収集失敗を保つ。
struct Pending<'ast> {
    definition: Definition<'ast>,
    input: Option<Result<BodyInput<'ast>, InputError>>,
}

/// 検査全体で一つの予算と、元ソース順の入力を所有する。
pub(in crate::typeck) struct AnalysisState<'ast> {
    pending: BTreeMap<NodeId, Box<Pending<'ast>>>,
    modules: Vec<ModuleId>,
    pub warnings: diagnostics::Warnings,
    pub budget: Budget,
}

/// 本体の訪問と同時に作った番号表、停止、値の解析結果を保持する。
pub(in crate::typeck) struct BodyAnalysis<'ast> {
    pub identity: Option<IdentityMap<'ast>>,
    pub coverage: Coverage,
    pub flow: Option<Box<flow::Analysis>>,
    seed: Option<environment::SavedEnvironment>,
}

impl<'ast> AnalysisState<'ast> {
    pub fn new(
        asts: &'ast [Module],
        modules: &'ast ModuleTable,
        resolved: &'ast ResolveOutput,
    ) -> Self {
        let pending = input::definitions(asts, modules, resolved)
            .filter_map(Result::ok)
            .filter(|d| {
                !modules
                    .get(d.order.module)
                    .is_some_and(|m| matches!(m.kind, ModuleKind::Prelude | ModuleKind::Stdlib))
            })
            .map(|definition| {
                (
                    definition.source.node(),
                    Box::new(Pending {
                        definition,
                        input: None,
                    }),
                )
            })
            .collect();
        Self {
            pending,
            modules: asts
                .iter()
                .enumerate()
                .filter_map(|(i, _)| {
                    let id = ModuleId(u32::try_from(i).ok()?);
                    (!modules.get(id).is_some_and(|m| {
                        matches!(m.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
                    }))
                    .then_some(id)
                })
                .collect(),
            warnings: diagnostics::Warnings::default(),
            budget: Budget::default(),
        }
    }

    pub fn definition(&self, node: NodeId) -> Option<Definition<'ast>> {
        self.pending.get(&node).map(|p| p.definition.clone())
    }

    pub fn collect(&mut self, node: NodeId, input: Result<BodyInput<'ast>, InputError>) {
        if let Some(pending) = self.pending.get_mut(&node) {
            pending.input = Some(input);
        }
    }

    /// finish 内や checked_args の診断も、解析へ渡す前に反映する。
    pub fn invalidate(&mut self, node: NodeId) {
        if let Some(pending) = self.pending.get_mut(&node) {
            pending.input = Some(Err(InputError::InvalidBody));
        }
    }

    pub fn analyze(
        &mut self,
        tables: &InputTables<'_>,
        fuel: u32,
        diagnostics: &mut Vec<crate::diag::Diagnostic>,
    ) -> Report {
        self.analyze_recorded(tables, fuel, diagnostics, None)
    }

    /// 任意の記録先は検査ごとに借用し、大域状態や解析予算に加えない。
    pub fn analyze_recorded(
        &mut self,
        tables: &InputTables<'_>,
        fuel: u32,
        diagnostics: &mut Vec<crate::diag::Diagnostic>,
        mut observations: Option<&mut Vec<serde_json::Value>>,
    ) -> Report {
        // 旧定数警告の順序と採用済みの組を、新しい候補で上書きしない
        // （設計書 02-05「警告」）。記録先なしでは複写・確保をしない。
        let legacy_warnings = observations
            .as_ref()
            .map(|_| observation::legacy_warnings(diagnostics, &self.warnings));
        let pending = std::mem::take(&mut self.pending);
        let mut ordered: Vec<_> = pending.values().collect();
        ordered.sort_unstable_by_key(|p| p.definition.order);
        let constants: BTreeMap<BindingId, &BodyInput<'ast>> = pending
            .values()
            .filter_map(|p| p.input.as_ref()?.as_ref().ok())
            .filter(|i| matches!(i.definition.source, BodySource::Constant(_)))
            .filter(|i| tables.constants.get(i.definition.binding).is_some())
            .map(|i| (i.definition.binding, i))
            .collect();
        let valid = |p: &Pending<'ast>| {
            p.input
                .as_ref()
                .and_then(|i| i.as_ref().ok())
                .is_some_and(|i| {
                    !matches!(i.definition.source, BodySource::Constant(_))
                        || tables.constants.get(i.definition.binding).is_some()
                })
        };
        let mut report = Report {
            started: true,
            input_definitions: u64::try_from(pending.values().filter(|p| valid(p)).count())
                .unwrap_or(u64::MAX),
            ..Report::default()
        };
        let mut ordered = ordered.into_iter().peekable();
        for (module_index, module) in self.modules.iter().enumerate() {
            if let Some(stop) = self.budget.exhausted() {
                report.remaining_modules = self.modules.get(module_index..).unwrap_or(&[]).to_vec();
                report.stopped = Some(stop);
                break;
            }
            // BudgetWhole.modules: モジュール自身の枠と分類も一度ずつ数える。
            let entered = self
                .budget
                .reserve(Item::StackFrame, Lifetime::Temporary)
                .and_then(|()| {
                    let result = self.budget.charge(budget::Operation::Classification);
                    self.budget.release(Lifetime::Temporary, 1);
                    result
                });
            if let Err(stop) = entered {
                report.remaining_modules = self.modules.get(module_index..).unwrap_or(&[]).to_vec();
                report.stopped = Some(stop);
                self.budget.finish_body();
                break;
            }
            // 分類の消費を全体へ残し、先頭の定義も新しい本体予算で始める
            // （設計書 01-12「区間解析の検査全体の駆動」）。
            self.budget.finish_body();
            while ordered
                .peek()
                .is_some_and(|p| p.definition.order.module == *module)
            {
                let Some(pending) = ordered.next() else {
                    break;
                };
                if let Some(stop) = self.budget.exhausted() {
                    report.remaining = Some(pending.definition.order);
                    report.stopped = Some(stop);
                    break;
                }
                // BudgetWhole.bodySlot: 一時枠、分類、出力一枠の順。
                let entered = self
                    .budget
                    .reserve(Item::StackFrame, Lifetime::Temporary)
                    .and_then(|()| {
                        let result = self
                            .budget
                            .charge(budget::Operation::Classification)
                            .and_then(|()| self.budget.reserve(Item::Auxiliary, Lifetime::Saved));
                        self.budget.release(Lifetime::Temporary, 1);
                        result
                    });
                if let Err(stop) = entered {
                    self.budget.finish_body();
                    report.remaining = Some(pending.definition.order);
                    report.stopped = Some(stop);
                    break;
                }
                let input = pending
                    .input
                    .as_ref()
                    .and_then(|i| i.as_ref().ok())
                    .filter(|i| {
                        !matches!(i.definition.source, BodySource::Constant(_))
                            || tables.constants.get(i.definition.binding).is_some()
                    });
                let mut analysis = match input {
                    Some(input) => analyze_body(input, tables, &constants, &mut self.budget, fuel),
                    None => BodyAnalysis {
                        identity: None,
                        coverage: Coverage::None,
                        flow: None,
                        seed: None,
                    },
                };
                let mut phases = DefinitionPhases {
                    root: None,
                    prepared: if analysis.seed.is_some() {
                        Some(Ok(()))
                    } else {
                        match analysis.coverage {
                            Coverage::Stopped(reason) => Some(Err(reason)),
                            Coverage::None | Coverage::Prepared => None,
                        }
                    },
                    discovery: None,
                    queue: None,
                    discovered: Vec::new(),
                    pending: Vec::new(),
                    embedded_stop: None,
                };
                observation::context(
                    observations.as_deref_mut(),
                    analysis.identity.as_ref(),
                    &self.budget,
                );
                let discovery = match (input, analysis.identity.as_ref(), analysis.seed.take()) {
                    (Some(input), _, Some(seed)) if self.budget.exhausted().is_none() => {
                        Some(discovery::discover(
                            input,
                            tables,
                            &constants,
                            seed,
                            &mut self.budget,
                            fuel,
                        ))
                    }
                    _ => None,
                };
                if phases.prepared == Some(Ok(()))
                    && discovery.is_none()
                    && let Some(stop) = self.budget.exhausted()
                {
                    phases.embedded_stop = Some(IdentityStop::AnalysisBudget(stop));
                }
                let usage = self.budget.finish_body();
                let body_report = BodyReport {
                    name: pending.definition.name.clone(),
                    coverage: analysis.coverage,
                    usage,
                    flow: analysis.flow.take(),
                };
                if let Some(identity) = &analysis.identity {
                    observation::record(observations.as_deref_mut(), identity, &body_report);
                    self.warnings.append(identity, &body_report, diagnostics);
                }
                if input.is_none() || body_report.flow.is_some() {
                    phases.root = Some(report.bodies.len());
                    report.bodies.push(body_report);
                }
                if let (Some(input), Some(discovery)) = (input, discovery) {
                    phases.discovery = Some(discovery.result);
                    phases.queue = discovery.queue;
                    phases.discovered = discovery
                        .entries
                        .iter()
                        .map(|entry| {
                            (
                                entry.embedded.definition(&pending.definition.name),
                                entry.initial.is_some(),
                            )
                        })
                        .collect();
                    if discovery.queue != Some(Ok(())) {
                        if discovery.queue.is_none()
                            && let Some(stop) = self.budget.exhausted()
                        {
                            phases.embedded_stop = Some(IdentityStop::AnalysisBudget(stop));
                        }
                        report.definitions.push(phases);
                        continue;
                    }
                    let mut entries = discovery.entries.into_iter().peekable();
                    while let Some(entry) = entries.peek() {
                        if let Some(stop) = self.budget.exhausted() {
                            phases.embedded_stop = Some(IdentityStop::AnalysisBudget(stop));
                            break;
                        }
                        let Some(seed) = entry.initial.clone() else {
                            break;
                        };
                        // bodySlot: 一時枠・分類・出力一枠を、別本体の入口より前に計上する。
                        let entered = (|| {
                            self.budget.reserve(Item::StackFrame, Lifetime::Temporary)?;
                            let result = self
                                .budget
                                .charge(budget::Operation::Classification)
                                .and_then(|()| {
                                    self.budget.reserve(Item::Auxiliary, Lifetime::Saved)
                                });
                            self.budget.release(Lifetime::Temporary, 1);
                            result
                        })();
                        if let Err(stop) = entered {
                            phases.embedded_stop = Some(IdentityStop::AnalysisBudget(stop));
                            self.budget.finish_body();
                            break;
                        }
                        let owner_input = if input.definition.binding == entry.type_owner {
                            input
                        } else {
                            match constants.get(&entry.type_owner) {
                                Some(input) => *input,
                                None => break,
                            }
                        };
                        let mut identity = IdentityMap::new(
                            owner_input,
                            Some((&pending.definition.name, &entry.embedded)),
                        );
                        let analysis = flow::analyze(
                            owner_input,
                            tables,
                            &mut identity,
                            &constants,
                            &mut self.budget,
                            fuel,
                            (seed, Some(entry.embedded.body)),
                        );
                        let coverage = analysis
                            .value
                            .as_ref()
                            .err()
                            .copied()
                            .map_or(Coverage::Prepared, Coverage::Stopped);
                        let flow = Some(Box::new(analysis));
                        observation::context(
                            observations.as_deref_mut(),
                            Some(&identity),
                            &self.budget,
                        );
                        let usage = self.budget.finish_body();
                        let body = BodyReport {
                            name: entry.embedded.definition(&pending.definition.name),
                            coverage,
                            usage,
                            flow,
                        };
                        observation::record(observations.as_deref_mut(), &identity, &body);
                        self.warnings.append(&identity, &body, diagnostics);
                        report.bodies.push(body);
                        entries.next();
                    }
                    phases.pending = entries
                        .map(|entry| entry.embedded.definition(&pending.definition.name))
                        .collect();
                }
                report.definitions.push(phases);
            }
            if report.stopped.is_some() {
                report.remaining_modules = self
                    .modules
                    .get(module_index.saturating_add(1)..)
                    .unwrap_or(&[])
                    .to_vec();
                break;
            }
        }
        // 未発見の別本体は推測せず、元入力の残りだけを数える。
        report.remaining_definitions = u64::try_from(
            pending
                .values()
                .filter(|p| valid(p))
                .filter(|p| {
                    report.remaining.is_some_and(|first| {
                        p.definition.order.module == first.module && p.definition.order >= first
                    }) || report
                        .remaining_modules
                        .contains(&p.definition.order.module)
                })
                .count(),
        )
        .unwrap_or(u64::MAX);
        report.whole = self.budget.whole;
        observation::finish(
            observations.as_deref_mut(),
            &report,
            &pending,
            &self.budget,
            fuel,
        );
        if let (Some(records), Some(legacy)) = (observations, legacy_warnings)
            && let Some(whole) = records
                .last_mut()
                .and_then(serde_json::Value::as_object_mut)
        {
            whole.insert("legacyWarnings".into(), legacy);
        }
        report
    }
}

/// 一般関数の引数・捕捉値には値の事実を与えない。番号付けと値の解析を
/// 同じ訪問で進め、未知を安全性の判定や追加拒否に使わない。
pub(in crate::typeck) fn analyze_body<'ast>(
    input: &BodyInput<'ast>,
    tables: &InputTables<'_>,
    constants: &BTreeMap<BindingId, &BodyInput<'ast>>,
    budget: &mut Budget,
    fuel: u32,
) -> BodyAnalysis<'ast> {
    // 親のseedは発見まで保存し、解析入口自身の忘却とは別に計上する。
    let prepared = discovery::prepare_root(input, tables, constants, budget);
    let seed = match prepared {
        Ok(seed) => seed,
        Err(stop) => {
            return BodyAnalysis {
                identity: None,
                coverage: Coverage::Stopped(stop),
                flow: None,
                seed: None,
            };
        }
    };
    let mut identity = IdentityMap::new(input, None);
    let analysis = flow::analyze(
        input,
        tables,
        &mut identity,
        constants,
        budget,
        fuel,
        (seed.clone(), None),
    );
    let coverage = analysis
        .value
        .as_ref()
        .err()
        .copied()
        .map_or(Coverage::Prepared, Coverage::Stopped);
    let flow = Some(Box::new(analysis));
    BodyAnalysis {
        identity: Some(identity),
        coverage,
        flow,
        seed: Some(seed),
    }
}
