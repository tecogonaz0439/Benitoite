//! 補助だけが取り込む失敗の報告を、型を保ったままホストへ返す（設計書 03-10「実行」）。
//! 実行の燃料・中断・Store の制限は、補助の報告より先に分類する。

use wasmtime::component::Linker;

use super::{
    codec::{CodecError, CodecPlan},
    component::{ComponentGroup, ComponentKey},
    layout::{LayoutError, LayoutTable},
    wire::WireError,
};
use crate::external::{ExternalFailure, ExternalRuntime, ExternalSpec, Limits};
use crate::runtime::heap::{NoGcCtx, Value};
use crate::runtime::{ResourceError, Stop};
use std::{collections::BTreeMap, sync::Arc};

/// コンパイル前の集合。元のソースとは別のキャッシュへ入れる。
pub(crate) struct PreparedComponent {
    key: ComponentKey,
    bytes: Arc<[u8]>,
}

/// 宣言固有の復号表と、タグ番号に依存しない合成の共有を分ける。
pub(crate) enum Binding {
    Adapter {
        component: Arc<PreparedComponent>,
        export: String,
        arguments: LayoutTable,
        results: LayoutTable,
    },
    Dynamic {
        reason: &'static str,
    },
}

impl Binding {
    /// 動的への事前の振り分けを、実行後の失敗と区別する。
    pub(crate) fn fallback_reason(&self) -> Option<&'static str> {
        match self {
            Self::Adapter { .. } => None,
            Self::Dynamic { reason } => Some(reason),
        }
    }
}

/// 準備の予算で候補を生成する。生成・表現の上限だけは実行前に動的へ戻せる。
pub(crate) fn prepare(
    specs: &[Arc<ExternalSpec>],
    budget: &mut usize,
    generation_limit: usize,
) -> Result<BTreeMap<u32, Arc<Binding>>, LayoutError> {
    let groups = match ComponentGroup::prepare_with_budget(specs, budget) {
        Ok(groups) => groups,
        Err(LayoutError::Memory32) => {
            return Ok(specs
                .iter()
                .map(|spec| {
                    (
                        spec.id,
                        Arc::new(Binding::Dynamic {
                            reason: crate::external::text::FALLBACK_MEMORY32,
                        }),
                    )
                })
                .collect());
        }
        Err(error) => return Err(error),
    };
    let mut bindings = BTreeMap::new();
    for group in groups {
        // 補助メモリ・変換用・融合用の三個を見込む。上限超過なら start より先に振り分ける。
        if super::component::core_instances(
            &specs
                .iter()
                .find(|spec| group.exports.contains_key(&spec.id))
                .ok_or(LayoutError::Internal("adapter source missing"))?
                .component
                .bytes,
        )?
        .saturating_add(3)
            > crate::external::runtime::OBJECTS
        {
            for id in group.exports.keys() {
                bindings.insert(
                    *id,
                    Arc::new(Binding::Dynamic {
                        reason: crate::external::text::FALLBACK_INSTANCES,
                    }),
                );
            }
            continue;
        }
        let bytes = match group.generate_with_budget(generation_limit, budget) {
            Ok(bytes) => bytes,
            Err(error @ (LayoutError::GenerationBudget | LayoutError::Memory32)) => {
                let reason = if error == LayoutError::GenerationBudget {
                    crate::external::text::FALLBACK_GENERATION
                } else {
                    crate::external::text::FALLBACK_MEMORY32
                };
                for id in group.exports.keys() {
                    bindings.insert(*id, Arc::new(Binding::Dynamic { reason }));
                }
                continue;
            }
            Err(error) => return Err(error),
        };
        let component = Arc::new(PreparedComponent {
            key: group.key,
            bytes: bytes.into(),
        });
        for spec in specs {
            let Some(export) = group.exports.get(&spec.id) else {
                continue;
            };
            bindings.insert(
                spec.id,
                Arc::new(Binding::Adapter {
                    component: Arc::clone(&component),
                    export: export.clone(),
                    arguments: LayoutTable::new(&spec.params, budget)?,
                    results: LayoutTable::new(
                        &spec.result.iter().cloned().collect::<Vec<_>>(),
                        budget,
                    )?,
                }),
            );
        }
    }
    Ok(bindings)
}

/// 固定した一種類の型で呼ぶ。言語の値と Store は呼び出し内だけに置く。
pub(in crate::external) fn call<'e>(
    runtime: &mut ExternalRuntime,
    binding: &Binding,
    spec: &ExternalSpec,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
    limits: Limits,
    usage: &mut Option<crate::external::stats::CallUsage>,
) -> Result<Value<'e>, ExternalFailure> {
    use crate::external::runtime::{internal, new_store, record_store};

    let Binding::Adapter {
        component: prepared,
        export,
        arguments,
        results,
    } = binding
    else {
        return Err(internal("dynamic fallback entered adapter call").into());
    };
    if let Some(usage) = usage {
        usage.route = Some(crate::external::text::ROUTE_ADAPTER);
    }

    let codec = CodecPlan::with_layout(&spec.params, arguments.clone())
        .map_err(|e| internal(format!("{e:?}")))?;
    // 引数の検査と詰め込みが成功するまでは、コンパイルも start も行わない。
    let input = codec
        .encode(ctx, args, limits.transfer)
        .map_err(|e| codec_failure(e, spec, limits))?;
    if let Some(usage) = usage {
        usage.arguments_transfer = Some(u64::try_from(input.bytes.len()).map_err(internal)?);
    }
    let component = runtime.session.adapter(
        &prepared.key,
        &prepared.bytes,
        &spec.component.bytes,
        runtime.stats.as_ref(),
    )?;
    // bump 確保と純粋なゲストの状態を次の呼び出しへ残さない。
    let mut store = new_store(&runtime.engine, limits)?;
    let result = (|| {
        let instance = runtime
            .adapter_linker
            .instantiate(&mut store, &component)
            .map_err(|e| {
                // 生成するコアモジュールには start がないため、Wasm の trap は元ゲストのものとする。
                let guest_trap = e.downcast_ref::<wasmtime::Trap>().is_some();
                match adapter_failure(e, spec, limits) {
                    ExternalFailure::Stop(Stop::Runtime(
                        crate::runtime::RuntimeError::ExternalTrap { trap, .. },
                    )) if !guest_trap => {
                        internal(format!("adapter instantiation failed: {trap}")).into()
                    }
                    other @ (ExternalFailure::Interrupted | ExternalFailure::Stop(_)) => other,
                }
            })?;
        let function = instance
            .get_typed_func::<(&[u8],), (Vec<u8>,)>(&mut store, export)
            .map_err(internal)?;
        // call は post-return まで行う。失敗後の再呼び出しと手動の後処理はしない。
        let (output,) = function.call(&mut store, (&input.bytes,)).map_err(|e| {
            if let Some(report) = reported_failure(&e) {
                if let Some(usage) = usage {
                    usage.adapter_failure = Some(*report);
                    // 途中で止まった構築量を、全体を測り終えた量として加算しない。
                    usage.construction_bytes = None;
                }
                report.stop(spec).into()
            } else {
                adapter_failure(e, spec, limits)
            }
        })?;
        if let Some(usage) = usage {
            usage.results_transfer = Some(u64::try_from(output.len()).map_err(internal)?);
        }
        let plans: Vec<_> = spec.result.iter().cloned().collect();
        let codec = CodecPlan::with_layout(&plans, results.clone())
            .map_err(|e| internal(format!("{e:?}")))?;
        let decoded = codec
            .decode(ctx, &output, limits.transfer)
            .map_err(|e| codec_failure(e, spec, limits))?;
        if let Some(usage) = usage {
            usage.construction_bytes = Some(
                input
                    .construction_bytes
                    .saturating_add(decoded.construction_bytes),
            );
        }
        match (spec.result.as_ref(), decoded.values.as_slice()) {
            (None, []) => Ok(Value::Unit),
            (Some(_), [value]) => Ok(*value),
            _ => Err(internal("adapter result count mismatch").into()),
        }
    })();
    record_store(usage, &store, limits, 0)?;
    result
}

fn adapter_failure(error: wasmtime::Error, spec: &ExternalSpec, limits: Limits) -> ExternalFailure {
    match crate::external::runtime::failure(error, spec, limits) {
        ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalMemory {
            function,
            component,
            limit,
        })) => Stop::Resource(ResourceError::ExternalAdapterMemory {
            function,
            component,
            requested: None,
            memory32_limit: None,
            allocated: None,
            store_limit: Some(limit),
        })
        .into(),
        other @ (ExternalFailure::Interrupted | ExternalFailure::Stop(_)) => other,
    }
}

fn codec_failure(error: CodecError, spec: &ExternalSpec, limits: Limits) -> Stop {
    match error {
        CodecError::Value(Stop::Resource(ResourceError::ValueTooLarge {
            size,
            unit,
            limit,
            ..
        })) => Stop::Resource(ResourceError::ExternalValueTooLarge {
            function: spec.function.clone(),
            size,
            unit,
            limit,
        }),
        CodecError::Value(stop) => stop,
        CodecError::Wire(
            WireError::TransferLimit | WireError::ConstructionLimit | WireError::Memory32,
        ) => Stop::Resource(ResourceError::ExternalTransfer {
            function: spec.function.clone(),
            component: spec.component.display.clone(),
            limit: limits.transfer,
        }),
        CodecError::Wire(WireError::Internal(message)) => Stop::Internal(message.into()),
    }
}

/// 生成器と報告の受け手が共有する固定の番号。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u32)]
pub(crate) enum FailureCode {
    ArgumentTransfer = 1,
    ResultTransfer = 2,
    ArgumentConstruction = 3,
    ResultConstruction = 4,
    ValueSize = 5,
    Realloc = 6,
    Format = 7,
}

/// 実行側で診断へ変換する分類。未知の番号も内部の不一致である。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum FailureClass {
    Resource,
    ValueSize,
    Internal,
}

impl FailureCode {
    /// 未知の番号を既知の資源不足として扱わない。
    pub(crate) fn from_number(number: u32) -> Option<Self> {
        match number {
            1 => Some(Self::ArgumentTransfer),
            2 => Some(Self::ResultTransfer),
            3 => Some(Self::ArgumentConstruction),
            4 => Some(Self::ResultConstruction),
            5 => Some(Self::ValueSize),
            6 => Some(Self::Realloc),
            7 => Some(Self::Format),
            _ => None,
        }
    }
}

/// Wasmtime の原因の列を通して保持する。量は符号なしのまま扱う。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct AdapterFailure {
    pub number: u32,
    pub requested: u64,
    pub limit: u64,
}

impl AdapterFailure {
    /// 凍結した停止の型を保ち、報告番号と量を既存の診断へ接続する。
    pub(in crate::external) fn stop(self, spec: &ExternalSpec) -> Stop {
        use crate::runtime::SizeUnit;
        match self.class() {
            FailureClass::Resource if self.number != FailureCode::Realloc as u32 => {
                Stop::Resource(ResourceError::ExternalTransfer {
                    function: spec.function.clone(),
                    component: spec.component.display.clone(),
                    limit: self.limit,
                })
            }
            FailureClass::Resource => Stop::Resource(ResourceError::ExternalAdapterMemory {
                function: spec.function.clone(),
                component: spec.component.display.clone(),
                requested: Some(self.requested),
                memory32_limit: (self.requested > u64::from(u32::MAX)).then_some(self.limit),
                allocated: (self.requested <= u64::from(u32::MAX)).then_some(self.limit),
                store_limit: None,
            }),
            FailureClass::ValueSize => {
                let unit = if self.limit == crate::runtime::MAX_LIST_LEN {
                    SizeUnit::Elements
                } else if self.limit == crate::runtime::MAX_STRING_BYTES {
                    SizeUnit::Bytes
                } else {
                    return Stop::Internal(format!("invalid adapter value limit: {self}"));
                };
                Stop::Resource(ResourceError::ExternalValueTooLarge {
                    function: spec.function.clone(),
                    size: self.requested,
                    unit,
                    limit: self.limit,
                })
            }
            FailureClass::Internal => Stop::Internal(format!(
                "adapter failure in {} ({}#{}): {self}",
                spec.function,
                spec.component.display,
                spec.export_name(),
            )),
        }
    }

    /// 診断の文言を読むことなく、報告番号で分類する。
    pub(crate) fn class(self) -> FailureClass {
        match FailureCode::from_number(self.number) {
            Some(FailureCode::ValueSize) => FailureClass::ValueSize,
            Some(FailureCode::Format) | None => FailureClass::Internal,
            Some(
                FailureCode::ArgumentTransfer
                | FailureCode::ResultTransfer
                | FailureCode::ArgumentConstruction
                | FailureCode::ResultConstruction
                | FailureCode::Realloc,
            ) => FailureClass::Resource,
        }
    }
}

impl std::fmt::Display for AdapterFailure {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}: {} ({} / {})",
            text::ADAPTER_FAILURE,
            self.number,
            self.requested,
            self.limit
        )
    }
}
impl std::error::Error for AdapterFailure {}

mod text {
    //! 内部の報告の表示名をまとめる（設計書 02-10「文言の言語」）。

    pub(super) const ADAPTER_FAILURE: &str = "adapter failure";
}

/// 既存の Wasmtime の停止原因を優先し、そのほかの場合だけ補助の報告を読む。
pub(crate) fn reported_failure(error: &wasmtime::Error) -> Option<&AdapterFailure> {
    if super::super::runtime::has_priority_failure(error) {
        None
    } else {
        error.downcast_ref::<AdapterFailure>()
    }
}

/// 外側の補助専用の取り込みだけを接続する。元のゲストの Linker には追加しない。
pub(crate) fn link_failure<T: 'static>(linker: &mut Linker<T>) -> wasmtime::Result<()> {
    linker.root().func_wrap(
        "adapter-fail",
        |_store, (number, requested, limit): (u32, u64, u64)| -> wasmtime::Result<()> {
            Err(wasmtime::Error::new(AdapterFailure {
                number,
                requested,
                limit,
            }))
        },
    )?;
    Ok(())
}

#[cfg(test)]
#[path = "report_tests.rs"]
mod tests;
