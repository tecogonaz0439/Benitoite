//! CLI の一回の起動で外部呼び出しを集計する（設計書 03-10「実行」）。
//! 言語の値を保持せず、指定した場合だけ作る共有の記録である。

use super::{ExternalFailure, ExternalRoute, Limits, text};
use crate::bytecode::program::ExternalRef;
use crate::runtime::{ResourceError, Stop};
use std::{cell::RefCell, collections::BTreeMap, rc::Rc};
use wasmtime::component::Val;

#[derive(Clone, Default)]
pub(crate) struct ExecutionOptions {
    pub limits: Limits,
    pub stats: Option<Collector>,
}
#[derive(Clone)]
pub(crate) struct Collector(Rc<RefCell<Stats>>);
#[derive(Default)]
pub(super) struct CallUsage {
    pub route: Option<&'static str>,
    pub fallback_reason: Option<&'static str>,
    pub adapter_failure: Option<super::adapter::runtime::AdapterFailure>,
    pub fuel: u64,
    pub memory: u64,
    pub memory_growth: u64,
    pub arguments_transfer: Option<u64>,
    pub results_transfer: Option<u64>,
    pub construction_bytes: Option<u64>,
}
#[derive(Default)]
struct Amount {
    total: u64,
    maximum: u64,
    incomplete_calls: u64,
}
impl Amount {
    fn json(&self) -> serde_json::Value {
        serde_json::json!({"total": self.total, "maximum": self.maximum, "incomplete_calls": self.incomplete_calls})
    }
    fn add(&mut self, value: Option<u64>) {
        match value {
            Some(value) => {
                self.total = self.total.saturating_add(value);
                self.maximum = self.maximum.max(value);
            }
            None => self.incomplete_calls = self.incomplete_calls.saturating_add(1),
        }
    }
}
#[derive(Default)]
struct FunctionStats {
    calls: u64,
    fuel: Amount,
    memory: Amount,
    arguments_transfer: Amount,
    results_transfer: Amount,
    construction_bytes: Amount,
    routes: BTreeMap<&'static str, u64>,
    fallback_reasons: BTreeMap<&'static str, u64>,
    adapter_failures: BTreeMap<(u32, u64, u64), u64>,
    reached_limits: BTreeMap<&'static str, u64>,
}
impl FunctionStats {
    fn json(&self) -> serde_json::Value {
        serde_json::json!({"calls": self.calls, "fuel": self.fuel.json(), "memory": self.memory.json(), "arguments_transfer": self.arguments_transfer.json(), "results_transfer": self.results_transfer.json(), "reached_limits": self.reached_limits,
            "construction_bytes": self.construction_bytes.json(), "routes": self.routes,
            "fallback_reasons": self.fallback_reasons,
            "adapter_failures": self.adapter_failures.iter().map(|((code, requested, limit), calls)|
                serde_json::json!({"code": code, "requested": requested, "limit": limit, "calls": calls})
            ).collect::<Vec<_>>()})
    }
    fn add(&mut self, usage: &CallUsage, limit: Option<&'static str>) {
        self.calls = self.calls.saturating_add(1);
        self.fuel.add(Some(usage.fuel));
        // 合計は成長分だけを加え、状態を持つインスタンスの同じメモリを重ねて数えない。
        self.memory.total = self.memory.total.saturating_add(usage.memory_growth);
        self.memory.maximum = self.memory.maximum.max(usage.memory);
        self.arguments_transfer.add(usage.arguments_transfer);
        self.results_transfer.add(usage.results_transfer);
        // 構築量を測る補助経路だけで、測定途中の停止を数える。
        if usage.route == Some(text::ROUTE_ADAPTER) {
            self.construction_bytes.add(usage.construction_bytes);
        }
        if let Some(route) = usage.route {
            let count = self.routes.entry(route).or_default();
            *count = count.saturating_add(1);
        }
        if let Some(reason) = usage.fallback_reason {
            let count = self.fallback_reasons.entry(reason).or_default();
            *count = count.saturating_add(1);
        }
        if let Some(report) = usage.adapter_failure {
            let count = self
                .adapter_failures
                .entry((report.number, report.requested, report.limit))
                .or_default();
            *count = count.saturating_add(1);
        }
        if let Some(limit) = limit {
            let count = self.reached_limits.entry(limit).or_default();
            *count = count.saturating_add(1);
        }
    }
}
struct StatefulMemory {
    instance: u64,
    component: String,
    maximum: u64,
}
#[derive(Default)]
struct Stats {
    next_run: u64,
    stateful_indices: BTreeMap<(u64, u32), usize>,
    total: FunctionStats,
    functions: BTreeMap<String, BTreeMap<String, FunctionStats>>,
    stateful_instances: Vec<StatefulMemory>,
}
impl Collector {
    pub(crate) fn new() -> Self {
        Self(Rc::new(RefCell::new(Stats::default())))
    }
    pub(super) fn next_run(&self) -> Result<u64, Stop> {
        let mut stats = self
            .0
            .try_borrow_mut()
            .map_err(|e| Stop::Internal(e.to_string()))?;
        let id = stats.next_run;
        stats.next_run = id
            .checked_add(1)
            .ok_or_else(|| Stop::Internal("external run count overflow".into()))?;
        Ok(id)
    }
    pub(super) fn record(
        &self,
        run: u64,
        reference: &ExternalRef,
        usage: CallUsage,
        failure: Option<&ExternalFailure>,
    ) -> Result<(), Stop> {
        let limit = match failure {
            Some(ExternalFailure::Stop(Stop::Resource(error))) => match error {
                ResourceError::ExternalFuel { .. } => Some("fuel"),
                ResourceError::ExternalMemory { .. }
                | ResourceError::ExternalAdapterMemory { .. } => Some("memory"),
                ResourceError::ExternalTransfer { .. } => Some("transfer"),
                ResourceError::ExternalObjects { resource, .. } => Some(match *resource {
                    text::CORE_INSTANCES => "core_instances",
                    text::CORE_MEMORIES => "core_memories",
                    text::CORE_TABLES => "core_tables",
                    text::TABLE_ELEMENTS => "table_elements",
                    _ => {
                        return Err(Stop::Internal(format!(
                            "unknown external resource: {resource}"
                        )));
                    }
                }),
                ResourceError::CallStackTooDeep { .. }
                | ResourceError::ExternalValueTooLarge { .. }
                | ResourceError::ValueTooLarge { .. }
                | ResourceError::InputTooLarge { .. } => None,
            },
            _ => None,
        };
        let mut stats = self
            .0
            .try_borrow_mut()
            .map_err(|e| Stop::Internal(e.to_string()))?;
        stats.total.add(&usage, limit);
        let component = &reference.spec.component.display;
        let function = &reference.spec.function;
        if let Some(function_stats) = stats
            .functions
            .get_mut(component)
            .and_then(|functions| functions.get_mut(function))
        {
            function_stats.add(&usage, limit);
        } else {
            stats
                .functions
                .entry(component.clone())
                .or_default()
                .entry(function.clone())
                .or_default()
                .add(&usage, limit);
        }
        if reference.spec.route == ExternalRoute::Stateful {
            let key = (run, reference.component);
            let index = if let Some(index) = stats.stateful_indices.get(&key) {
                *index
            } else {
                let index = stats.stateful_instances.len();
                stats.stateful_indices.insert(key, index);
                stats.stateful_instances.push(StatefulMemory {
                    instance: u64::try_from(index).map_err(|e| Stop::Internal(e.to_string()))?,
                    component: reference.spec.component.display.clone(),
                    maximum: 0,
                });
                index
            };
            let memory = stats
                .stateful_instances
                .get_mut(index)
                .ok_or_else(|| Stop::Internal("external memory record missing".into()))?;
            memory.maximum = memory.maximum.max(usage.memory);
        }
        Ok(())
    }
    pub(crate) fn json(&self) -> Result<serde_json::Value, Stop> {
        let stats = self
            .0
            .try_borrow()
            .map_err(|e| Stop::Internal(e.to_string()))?;
        let mut value = stats.total.json();
        let object = value
            .as_object_mut()
            .ok_or_else(|| Stop::Internal("external statistics object missing".into()))?;
        object.insert(
            "functions".into(),
            serde_json::Value::Object(
                stats
                    .functions
                    .iter()
                    .flat_map(|(component, functions)| {
                        functions.iter().map(move |(function, stats)| {
                            (format!("{component}#{function}"), stats.json())
                        })
                    })
                    .collect(),
            ),
        );
        object.insert("stateful_instances".into(), serde_json::Value::Array(stats.stateful_instances.iter().map(|state| serde_json::json!({"instance": state.instance, "component": state.component, "maximum": state.maximum})).collect()));
        Ok(value)
    }
}

// Wasmtime の残量は公開されないため、取得した戻り値を同じ規則で数える。
// この走査は統計を指定したときだけ行い、深さによる Rust の再帰を避ける。
pub(super) fn dynamic_transfer(values: &[Val]) -> u64 {
    let val_size = u64::try_from(std::mem::size_of::<Val>()).unwrap_or(u64::MAX);
    let size = |n: usize| u64::try_from(n).unwrap_or(u64::MAX);
    let mut total = 0_u64;
    let mut work: Vec<&Val> = values.iter().collect();
    while let Some(value) = work.pop() {
        let cost = match value {
            Val::String(s) | Val::Enum(s) => size(s.len()),
            Val::List(values) | Val::Tuple(values) | Val::FixedLengthList(values) => {
                work.extend(values);
                size(values.len()).saturating_mul(val_size)
            }
            Val::Record(fields) => {
                work.extend(fields.iter().map(|(_, value)| value));
                fields.iter().fold(
                    size(fields.len()).saturating_mul(val_size),
                    |n, (name, _)| n.saturating_add(size(name.len())),
                )
            }
            Val::Variant(name, payload) => {
                if let Some(payload) = payload {
                    work.push(payload);
                }
                size(name.len()).saturating_add(if payload.is_some() { val_size } else { 0 })
            }
            Val::Option(payload) | Val::Result(Ok(payload) | Err(payload)) => {
                if let Some(payload) = payload {
                    work.push(payload);
                    val_size
                } else {
                    0
                }
            }
            Val::Map(values) => {
                work.extend(values.iter().flat_map(|(key, value)| [key, value]));
                size(values.len()).saturating_mul(size(std::mem::size_of::<(Val, Val)>()))
            }
            Val::Flags(names) => names
                .iter()
                .fold(0_u64, |n, name| n.saturating_add(size(name.len()))),
            Val::Bool(_)
            | Val::S8(_)
            | Val::U8(_)
            | Val::S16(_)
            | Val::U16(_)
            | Val::S32(_)
            | Val::U32(_)
            | Val::S64(_)
            | Val::U64(_)
            | Val::Float32(_)
            | Val::Float64(_)
            | Val::Char(_)
            | Val::Resource(_)
            | Val::Future(_)
            | Val::Stream(_)
            | Val::ErrorContext(_) => 0,
        };
        total = total.saturating_add(cost);
    }
    total
}
