//! 外部の関数の実行と中断の見張り（設計書 02-09「外部の関数の実行」）。
//! 外部の型を受け渡す関数は実行ごとの状態を持ち、それ以外は呼び出しごとに作る。

use super::{ExternalRoute, ExternalSpec, TypedShape, convert, engine_config, text, typed};
use crate::bytecode::program::ExternalTable;
use crate::runtime::heap::{NoGcCtx, Value};
use crate::runtime::{ResourceError, RuntimeError, Stop};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};
use std::thread::{self, JoinHandle};
use std::time::Duration;
use std::{cell::RefCell, rc::Rc};
use wasmtime::{
    Engine, ResourceLimiter, Store, Trap,
    component::{Component, Func, Instance, Linker, ResourceAny, Val},
};

pub(super) const FUEL: u64 = 10_000_000_000;
pub(super) const MEMORY: u64 = 64 * 1024 * 1024;
pub(super) const TRANSFER: u64 = 256 * 1024 * 1024;
const TABLE_ELEMENTS: u64 = 10_000;
pub(in crate::external) const OBJECTS: usize = 16;

/// 中断は VM の停止の経路へ返し、実行時エラーと区別する。
#[derive(Debug)]
pub enum ExternalFailure {
    Interrupted,
    Stop(Stop),
}
impl From<Stop> for ExternalFailure {
    fn from(stop: Stop) -> Self {
        Self::Stop(stop)
    }
}
/// 補助の接続でも、処理系の不具合を同じ停止の形で返す。
pub(in crate::external) fn internal(e: impl std::fmt::Display) -> Stop {
    Stop::Internal(e.to_string())
}

/// 言語の値を保持しない実行ごとの外部の関数の状態。
pub struct ExternalRuntime {
    pub(in crate::external) engine: Engine,
    components: Vec<Option<Component>>,
    pub(in crate::external) adapters: Vec<(super::adapter::component::ComponentKey, Component)>,
    stateful: Vec<Option<Stateful>>,
    linker: Linker<CallLimits>,
    pub(in crate::external) adapter_linker: Linker<CallLimits>,
    _watcher: Option<Watcher>,
    limits: Limits,
    stats: Option<super::stats::Collector>,
    run_id: u64,
}
impl ExternalRuntime {
    /// 最初の外部の呼び出しでだけ作る。印を持たない実行ではスレッドを起こさない。
    pub fn new(interrupt: Option<Arc<AtomicBool>>) -> Result<Self, Stop> {
        let engine = Engine::new(&engine_config()).map_err(internal)?;
        let watcher = interrupt
            .map(|flag| Watcher::new(engine.clone(), flag))
            .transpose()?;
        let mut adapter_linker = Linker::new(&engine);
        super::adapter::runtime::link_failure(&mut adapter_linker).map_err(internal)?;
        Ok(Self {
            adapter_linker,
            linker: Linker::new(&engine),
            engine,
            components: vec![],
            adapters: vec![],
            stateful: vec![],
            _watcher: watcher,
            limits: Limits::default(),
            stats: None,
            run_id: 0,
        })
    }
}
impl ExternalRuntime {
    pub(crate) fn configured(
        interrupt: Option<Arc<AtomicBool>>,
        options: super::stats::ExecutionOptions,
    ) -> Result<Self, Stop> {
        let mut runtime = Self::new(interrupt)?;
        runtime.limits = options.limits;
        runtime.run_id = options
            .stats
            .as_ref()
            .map(|stats| stats.next_run())
            .transpose()?
            .unwrap_or(0);
        runtime.stats = options.stats;
        Ok(runtime)
    }
}

struct Watcher {
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
}
impl Watcher {
    fn new(engine: Engine, interrupt: Arc<AtomicBool>) -> Result<Self, Stop> {
        let stop = Arc::new(AtomicBool::new(false));
        let thread_stop = Arc::clone(&stop);
        let thread = thread::Builder::new()
            .name("benitoite-wasm-interrupt".into())
            .spawn(move || {
                while !thread_stop.load(Ordering::Relaxed) {
                    if interrupt.load(Ordering::Relaxed) {
                        engine.increment_epoch();
                    }
                    thread::park_timeout(Duration::from_millis(10));
                }
            })
            .map_err(internal)?;
        Ok(Self {
            stop,
            thread: Some(thread),
        })
    }
}
impl Drop for Watcher {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            thread.thread().unpark();
            // スレッドは印の読み出しと epoch の更新だけを行う。合流の失敗は巻き戻さない。
            let _joined = thread.join();
        }
    }
}
#[derive(Debug)]
struct MemoryLimitExceeded;
impl std::fmt::Display for MemoryLimitExceeded {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(text::MEMORY_LIMIT)
    }
}
impl std::error::Error for MemoryLimitExceeded {}
#[derive(Debug)]
struct TableLimitExceeded {
    desired: u64,
}
impl std::fmt::Display for TableLimitExceeded {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(text::TABLE_LIMIT)
    }
}
impl std::error::Error for TableLimitExceeded {}
/// Store の寿命全体でゲストの線形メモリの合計を数える制限器。
pub(super) struct CallLimits {
    memory: u64,
    limit: u64,
}
impl ResourceLimiter for CallLimits {
    fn memory_growing(
        &mut self,
        current: usize,
        desired: usize,
        maximum: Option<usize>,
    ) -> wasmtime::Result<bool> {
        // Wasm 自身の maximum を超える要求は確保されないので、合計へ加えない。
        if maximum.is_some_and(|max| desired > max) {
            return Ok(false);
        }
        let growth = desired
            .checked_sub(current)
            .and_then(|n| u64::try_from(n).ok())
            .unwrap_or(u64::MAX);
        let total = self.memory.saturating_add(growth);
        if total > self.limit {
            return Err(wasmtime::Error::new(MemoryLimitExceeded));
        }
        // 確保が後で失敗しても合計を戻さず、次の要求を多めに数える。
        self.memory = total;
        Ok(true)
    }
    fn table_growing(
        &mut self,
        _current: usize,
        desired: usize,
        _maximum: Option<usize>,
    ) -> wasmtime::Result<bool> {
        let desired = u64::try_from(desired).unwrap_or(u64::MAX);
        if desired > TABLE_ELEMENTS {
            return Err(wasmtime::Error::new(TableLimitExceeded { desired }));
        }
        Ok(true)
    }
    fn instances(&self) -> usize {
        OBJECTS
    }
    fn memories(&self) -> usize {
        OBJECTS
    }
    fn tables(&self) -> usize {
        OBJECTS
    }
}
/// 補助の報告より先に適用する、既存の燃料・中断・Store の制限の原因。
pub(in crate::external) fn has_priority_failure(e: &wasmtime::Error) -> bool {
    e.downcast_ref::<MemoryLimitExceeded>().is_some()
        || e.downcast_ref::<TableLimitExceeded>().is_some()
        || matches!(
            e.downcast_ref::<Trap>(),
            Some(Trap::Interrupt | Trap::OutOfFuel)
        )
}

/// 既存経路と補助で Wasmtime の停止原因の優先順を共有する。
pub(in crate::external) fn failure(
    e: wasmtime::Error,
    spec: &ExternalSpec,
    limits: Limits,
) -> ExternalFailure {
    if e.downcast_ref::<MemoryLimitExceeded>().is_some() {
        return ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalMemory {
            function: spec.function.clone(),
            component: spec.component.display.clone(),
            limit: limits.memory,
        }));
    }
    if let Some(error) = e.downcast_ref::<TableLimitExceeded>() {
        return ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalObjects {
            function: spec.function.clone(),
            component: spec.component.display.clone(),
            resource: text::TABLE_ELEMENTS,
            size: error.desired,
            limit: TABLE_ELEMENTS,
        }));
    }
    if let Some(report) = super::adapter::runtime::reported_failure(&e) {
        return report.stop(spec).into();
    }
    // 非公開の型は downcast できないため、固定した Wasmtime の原因の文言だけで識別する。
    if e.chain()
        .any(|cause| cause.to_string() == text::HOSTCALL_FUEL_EXHAUSTED)
    {
        return ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalTransfer {
            function: spec.function.clone(),
            component: spec.component.display.clone(),
            limit: limits.transfer,
        }));
    }
    // 数の制限には公開の誤りの型がない。固定した版の原因だけを照合し、資源の不足にする。
    // 本物のインスタンス化を使うテストが、依存の更新による文言の変更を検出する。
    for cause in e.chain() {
        let cause = cause.to_string();
        for (prefix, resource) in text::OBJECT_LIMITS {
            if let Some(size) = cause
                .strip_prefix(prefix)
                .and_then(|s| s.parse::<u64>().ok())
            {
                return ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalObjects {
                    function: spec.function.clone(),
                    component: spec.component.display.clone(),
                    resource,
                    size,
                    limit: u64::try_from(OBJECTS).unwrap_or(u64::MAX),
                }));
            }
        }
    }
    match e.downcast_ref::<Trap>() {
        Some(Trap::Interrupt) => ExternalFailure::Interrupted,
        Some(Trap::OutOfFuel) => {
            ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalFuel {
                function: spec.function.clone(),
                component: spec.component.display.clone(),
                limit: limits.fuel,
            }))
        }
        Some(trap) => ExternalFailure::Stop(Stop::Runtime(RuntimeError::ExternalTrap {
            function: spec.function.clone(),
            component: spec.component.display.clone(),
            export: spec.export_name(),
            trap: trap.to_string(),
        })),
        None => ExternalFailure::Stop(Stop::Runtime(RuntimeError::ExternalTrap {
            function: spec.function.clone(),
            component: spec.component.display.clone(),
            export: spec.export_name(),
            trap: e.to_string(),
        })),
    }
}

/// VM と参照インタプリタの外部の呼び出しをまとめる唯一の入口（設計書 03-10「実行」）。
pub fn call<'e>(
    runtime: &mut ExternalRuntime,
    table: &ExternalTable,
    index: u32,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
) -> Result<Value<'e>, ExternalFailure> {
    call_with_fuel(runtime, table, index, ctx, args, runtime.limits)
}
/// 外部の関数の上限の既定値（設計書 03-10「実行」）。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Limits {
    /// 線形メモリの合計の上限（バイト）。
    pub(crate) memory: u64,
    /// 一回の呼び出しの燃料の上限。
    pub(crate) fuel: u64,
    /// 引数・戻り値それぞれの受け渡しの予算（バイト）。
    pub(crate) transfer: u64,
}
impl Limits {
    /// 線形メモリの合計の上限をバイト数で返す。
    pub fn memory(&self) -> u64 {
        self.memory
    }
    /// 一回の呼び出しの燃料の上限を返す。
    pub fn fuel(&self) -> u64 {
        self.fuel
    }
    /// 引数・戻り値それぞれの受け渡しの予算をバイト数で返す。
    pub fn transfer(&self) -> u64 {
        self.transfer
    }
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            memory: MEMORY,
            fuel: FUEL,
            transfer: TRANSFER,
        }
    }
}
fn call_with_fuel<'e>(
    runtime: &mut ExternalRuntime,
    table: &ExternalTable,
    index: u32,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
    limits: Limits,
) -> Result<Value<'e>, ExternalFailure> {
    // 状態を持つ経路と既存の具体化を優先し、事前に生成できた残りの宣言だけを補助へ送る。
    let adapter = table
        .functions
        .get(usize::try_from(index).map_err(internal)?)
        .filter(|reference| reference.spec.route == ExternalRoute::Dynamic)
        .and_then(|reference| reference.spec.adapter.as_deref())
        .filter(|binding| binding.fallback_reason().is_none());
    call_with_usage(runtime, table, index, ctx, args, limits, adapter)
}

/// 内部の補助接続も、公開経路と同じ成功・失敗の集計を通す。
pub(in crate::external) fn call_with_usage<'e>(
    runtime: &mut ExternalRuntime,
    table: &ExternalTable,
    index: u32,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
    limits: Limits,
    adapter: Option<&super::adapter::runtime::Binding>,
) -> Result<Value<'e>, ExternalFailure> {
    let mut usage = runtime
        .stats
        .as_ref()
        .map(|_| super::stats::CallUsage::default());
    let result = call_inner(
        runtime,
        table,
        index,
        ctx,
        args,
        (limits, &mut usage),
        adapter,
    );
    if let (Some(stats), Some(usage), Some(reference)) = (
        &runtime.stats,
        usage,
        table
            .functions
            .get(usize::try_from(index).map_err(internal)?),
    ) {
        stats.record(runtime.run_id, reference, usage, result.as_ref().err())?;
    }
    result
}
fn call_inner<'e>(
    runtime: &mut ExternalRuntime,
    table: &ExternalTable,
    index: u32,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
    (limits, usage): (Limits, &mut Option<super::stats::CallUsage>),
    adapter: Option<&super::adapter::runtime::Binding>,
) -> Result<Value<'e>, ExternalFailure> {
    let reference = table
        .functions
        .get(usize::try_from(index).map_err(internal)?)
        .ok_or_else(|| internal("external reference missing"))?;
    let spec = &reference.spec;
    if let Some(usage) = usage {
        usage.route = Some(if adapter.is_some() {
            text::ROUTE_ADAPTER
        } else {
            match spec.route {
                ExternalRoute::Typed(_) => text::ROUTE_TYPED,
                ExternalRoute::Dynamic => text::ROUTE_DYNAMIC,
                ExternalRoute::Stateful => text::ROUTE_STATEFUL,
            }
        });
        if spec.route == ExternalRoute::Dynamic && adapter.is_none() {
            usage.fallback_reason = spec.adapter.as_deref().and_then(|b| b.fallback_reason());
        }
    }
    if args.len() != usize::from(reference.arity) {
        return Err(internal("external arity mismatch").into());
    }
    if let Some(binding) = adapter {
        return super::adapter::runtime::call(runtime, binding, spec, ctx, args, limits, usage);
    }
    let source_index = usize::try_from(reference.component).map_err(internal)?;
    let source = table
        .components
        .get(source_index)
        .ok_or_else(|| internal("external component missing"))?;
    // 引数の失敗を、コンパイルやゲストの start・解放の失敗より先に報告する
    // （設計書 03-10「実行」）。初回は外部の対象の表がないので借用を拒否する。
    runtime
        .stateful
        .resize_with(table.components.len(), || None);
    let prepared = (|| -> Result<PreparedArgs<'_>, Stop> {
        match &spec.route {
            ExternalRoute::Typed(shape) => typed::prepare(ctx, spec, shape, args, limits.transfer)
                .map(|args| {
                    if let Some(usage) = usage {
                        usage.arguments_transfer = Some(args.1);
                    }
                    PreparedArgs::Typed(args)
                }),
            ExternalRoute::Dynamic | ExternalRoute::Stateful => {
                let transfer = convert::check_arguments(ctx, spec, args, limits.transfer)?;
                if let Some(usage) = usage {
                    usage.arguments_transfer = Some(transfer);
                }
                let mut handles = runtime
                    .stateful
                    .get_mut(source_index)
                    .and_then(Option::as_mut)
                    .map(|state| ExternalHandles {
                        component: reference.component,
                        handles: &mut state.handles,
                        free: &mut state.free,
                        queue: &state.queue,
                        growth: 0,
                    });
                spec.params
                    .iter()
                    .zip(args)
                    .map(|(p, v)| convert::to_wasm(ctx, p, *v, handles.as_mut()))
                    .collect::<Result<Vec<_>, _>>()
                    .map(PreparedArgs::Dynamic)
            }
        }
    })();
    let prepared = match prepared {
        Ok(params) => params,
        Err(stop) => {
            if spec.route == ExternalRoute::Stateful {
                *runtime
                    .stateful
                    .get_mut(source_index)
                    .ok_or_else(|| internal("stateful cache missing"))? = None;
            }
            return Err(stop.into());
        }
    };
    runtime
        .components
        .resize_with(table.components.len(), || None);
    let component = runtime
        .components
        .get_mut(source_index)
        .ok_or_else(|| internal("external component cache missing"))?;
    if component.is_none() {
        *component =
            Some(Component::from_binary(&runtime.engine, &source.bytes).map_err(internal)?);
    }
    let component = component
        .as_ref()
        .ok_or_else(|| internal("external component not compiled"))?;
    if spec.route == ExternalRoute::Stateful {
        let slot = runtime
            .stateful
            .get_mut(source_index)
            .ok_or_else(|| internal("stateful cache missing"))?;
        let before = slot.as_ref().map_or(0, |s| s.store.data().memory);
        if slot.is_none() {
            let mut store = new_store(&runtime.engine, limits)?;
            let instance = runtime.linker.instantiate(&mut store, component);
            if instance.is_err() {
                record_store(usage, &store, limits, before)?;
            }
            let instance = instance.map_err(|e| failure(e, spec, limits))?;
            *slot = Some(Stateful {
                store,
                instance,
                handles: vec![],
                free: vec![],
                queue: Rc::new(RefCell::new(vec![])),
            });
        } else {
            reset_limits(
                &mut slot
                    .as_mut()
                    .ok_or_else(|| internal("stateful instance missing"))?
                    .store,
                limits,
            )?;
        }
        let state = slot
            .as_mut()
            .ok_or_else(|| internal("stateful instance missing"))?;
        let result = call_stateful(
            state,
            component,
            (reference.component, before),
            ctx,
            spec,
            match &prepared {
                PreparedArgs::Dynamic(params) => params,
                PreparedArgs::Typed(_) => return Err(internal("typed stateful arguments").into()),
            },
            (limits, usage),
        );
        record_store(usage, &state.store, limits, before)?;
        if result.is_err() {
            *slot = None;
        }
        return result;
    }
    let mut store = new_store(&runtime.engine, limits)?;
    let result = (|| {
        let instance = runtime
            .linker
            .instantiate(&mut store, component)
            .map_err(|e| failure(e, spec, limits))?;
        let func = function(component, instance, &mut store, spec)?;
        match (&spec.route, &prepared) {
            (ExternalRoute::Dynamic, PreparedArgs::Dynamic(params)) => {
                call_dynamic(&mut store, &func, ctx, spec, params, limits, usage)
            }
            (ExternalRoute::Typed(shape), PreparedArgs::Typed(params)) => {
                call_typed(&mut store, &func, ctx, spec, shape, params, (limits, usage))
            }
            _ => Err(internal("external argument route mismatch").into()),
        }
    })();
    record_store(usage, &store, limits, 0)?;
    result
}
/// Store の消費量は、成功と失敗のどちらでも同じ方法で記録する。
pub(in crate::external) fn record_store(
    usage: &mut Option<super::stats::CallUsage>,
    store: &Store<CallLimits>,
    limits: Limits,
    before: u64,
) -> Result<(), Stop> {
    if let Some(usage) = usage {
        usage.fuel = limits
            .fuel
            .saturating_sub(store.get_fuel().map_err(internal)?);
        usage.memory = store.data().memory;
        usage.memory_growth = usage.memory.saturating_sub(before);
    }
    Ok(())
}

enum PreparedArgs<'a> {
    Dynamic(Vec<Val>),
    Typed(typed::PreparedArgs<'a>),
}

/// 純粋な呼び出し用の Store を、同じ制限器と燃料・中断の設定で作る。
pub(in crate::external) fn new_store(
    engine: &Engine,
    limits: Limits,
) -> Result<Store<CallLimits>, Stop> {
    let mut store = Store::new(
        engine,
        CallLimits {
            memory: 0,
            limit: limits.memory,
        },
    );
    store.limiter(|s| s);
    reset_limits(&mut store, limits)?;
    Ok(store)
}
fn reset_limits(store: &mut Store<CallLimits>, limits: Limits) -> Result<(), Stop> {
    store.set_fuel(limits.fuel).map_err(internal)?;
    store.set_hostcall_fuel(usize::try_from(limits.transfer).map_err(internal)?);
    store.set_epoch_deadline(1);
    Ok(())
}
fn function(
    component: &Component,
    instance: Instance,
    store: &mut Store<CallLimits>,
    spec: &ExternalSpec,
) -> Result<Func, Stop> {
    let parent = spec
        .instance
        .as_ref()
        .map(|name| {
            component
                .get_export_index(None, name)
                .ok_or_else(|| internal("checked external interface missing"))
        })
        .transpose()?;
    let index = component
        .get_export_index(parent.as_ref(), &spec.export)
        .ok_or_else(|| internal("checked external export index missing"))?;
    instance
        .get_func(store, index)
        .ok_or_else(|| internal("checked external export missing"))
}

struct Stateful {
    store: Store<CallLimits>,
    instance: Instance,
    handles: Vec<Option<ResourceAny>>,
    free: Vec<u32>,
    queue: Rc<RefCell<Vec<u32>>>,
}

/// 言語の値を保持せず、変換の間だけ外部の対象の表を借りる。
pub(super) struct ExternalHandles<'a> {
    pub component: u32,
    pub handles: &'a mut Vec<Option<ResourceAny>>,
    pub free: &'a mut Vec<u32>,
    pub queue: &'a Rc<RefCell<Vec<u32>>>,
    pub growth: usize,
}
/// 作った後は変更しない対象。解放待ちの列は対象の外の共有の領域である。
#[derive(Debug)]
pub(super) struct ExternalHandle {
    pub component: u32,
    pub resource: u32,
    pub slot: u32,
    pub queue: Rc<RefCell<Vec<u32>>>,
    pub growth: usize,
}
impl crate::runtime::heap::OpaqueData for ExternalHandle {
    fn heap_bytes(&self) -> usize {
        self.growth
    }
}
impl Drop for ExternalHandle {
    fn drop(&mut self) {
        // 解放そのものは行わず番号だけを積む。次に状態を持つインスタンスへ入る前に
        // 解放する（設計書 03-10「実行」）。実行系が先に捨てられても列は生きている。
        if let Ok(mut queue) = self.queue.try_borrow_mut() {
            queue.push(self.slot);
        }
    }
}
fn call_stateful<'e>(
    state: &mut Stateful,
    component: &Component,
    (component_id, before): (u32, u64),
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    params: &[Val],
    (limits, usage): (Limits, &mut Option<super::stats::CallUsage>),
) -> Result<Value<'e>, ExternalFailure> {
    // 最初のインスタンス化も同じ呼び出しの燃料と受け渡しの予算に含める。
    // 初回の設定をやり直さないため、呼び出し側で既存の状態だけを設定し直す。
    let pending = std::mem::take(&mut *state.queue.try_borrow_mut().map_err(internal)?);
    for slot in pending {
        let resource = state
            .handles
            .get_mut(usize::try_from(slot).map_err(internal)?)
            .and_then(Option::take)
            .ok_or_else(|| internal("external release slot missing"))?;
        resource.resource_drop(&mut state.store).map_err(|e| {
            let mut destructor = spec.clone();
            if let Some((_, name)) =
                super::check::resource_exports(&component.component_type(), state.store.engine())
                    .into_iter()
                    .find(|(_, name)| {
                        let (parent, export) = name
                            .rsplit_once('#')
                            .map_or((None, name.as_str()), |(p, n)| (Some(p), n));
                        let parent = parent.and_then(|p| component.get_export_index(None, p));
                        component
                            .get_export_index(parent.as_ref(), export)
                            .and_then(|index| state.instance.get_resource(&mut state.store, index))
                            == Some(resource.ty())
                    })
            {
                let (parent, name) = name
                    .rsplit_once('#')
                    .map_or((None, name.as_str()), |(p, n)| (Some(p.to_owned()), n));
                destructor.instance = parent;
                destructor.export = text::resource_drop(name);
            } else {
                destructor.export = text::resource_drop(text::EXTERNAL_TYPE);
            }
            failure(e, &destructor, limits)
        })?;
        state.free.push(slot);
    }
    let func = function(component, state.instance, &mut state.store, spec)?;
    let mut handles = ExternalHandles {
        component: component_id,
        handles: &mut state.handles,
        free: &mut state.free,
        queue: &state.queue,
        growth: 0,
    };
    let mut result = if spec.result.is_some() {
        vec![Val::Bool(false)]
    } else {
        vec![]
    };
    func.call(&mut state.store, params, &mut result)
        .map_err(|e| failure(e, spec, limits))?;
    handles.growth =
        usize::try_from(state.store.data().memory.saturating_sub(before)).map_err(internal)?;
    if let Some(usage) = usage {
        usage.results_transfer = Some(super::stats::dynamic_transfer(&result));
    }
    match &spec.result {
        None => Ok(Value::Unit),
        Some(plan) => convert::from_wasm(
            ctx,
            spec,
            plan,
            result
                .first()
                .ok_or_else(|| internal("external result missing"))?,
            Some(&mut handles),
        )
        .map_err(ExternalFailure::Stop),
    }
}

fn call_typed<'e>(
    store: &mut Store<CallLimits>,
    func: &Func,
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    shape: &TypedShape,
    args: &typed::PreparedArgs<'_>,
    (limits, usage): (Limits, &mut Option<super::stats::CallUsage>),
) -> Result<Value<'e>, ExternalFailure> {
    let result = typed::call(store, func, shape, args).map_err(|e| match e {
        typed::CallError::Stop(stop) => ExternalFailure::Stop(stop),
        typed::CallError::Call(e) => failure(e, spec, limits),
    })?;
    if let Some(usage) = usage {
        usage.results_transfer = Some(result.transfer());
    }
    typed::into_value(ctx, spec, shape.result, result).map_err(ExternalFailure::Stop)
}
fn call_dynamic<'e>(
    store: &mut Store<CallLimits>,
    func: &Func,
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    params: &[Val],
    limits: Limits,
    usage: &mut Option<super::stats::CallUsage>,
) -> Result<Value<'e>, ExternalFailure> {
    let mut result = if spec.result.is_some() {
        vec![Val::Bool(false)]
    } else {
        vec![]
    };
    func.call(&mut *store, params, &mut result)
        .map_err(|e| failure(e, spec, limits))?;
    // Wasmtime の call が post-return まで行うので、追加の呼び出しは不要である。
    if let Some(usage) = usage {
        usage.results_transfer = Some(super::stats::dynamic_transfer(&result));
    }
    match &spec.result {
        None => Ok(Value::Unit),
        Some(plan) => convert::from_wasm(
            ctx,
            spec,
            plan,
            result
                .first()
                .ok_or_else(|| internal("external result missing"))?,
            None,
        )
        .map_err(ExternalFailure::Stop),
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」）。
    #![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
    use super::*;
    use crate::bytecode::program::ExternalRef;
    use crate::external::{ComponentSource, WitPlan};
    use crate::runtime::heap::{Heap, HeapConfig};

    pub(super) fn table(wat: &str, export: &str, result: Option<WitPlan>) -> ExternalTable {
        let source = Arc::new(ComponentSource {
            display: "wasm/test.wasm".into(),
            bytes: Arc::from(wat::parse_str(wat).unwrap()),
        });
        ExternalTable {
            components: vec![Arc::clone(&source)],
            functions: vec![ExternalRef {
                spec: Arc::new(ExternalSpec {
                    adapter: None,
                    id: 0,
                    function: "testFn".into(),
                    component: source,
                    instance: None,
                    export: export.into(),
                    params: vec![],
                    route: ExternalRoute::of(&[], result.as_ref()),
                    result,
                }),
                component: 0,
                arity: 0,
            }],
        }
    }
    pub(super) fn resources() -> ExternalTable {
        let source = Arc::new(ComponentSource {
            display: "resource/x.wasm".into(),
            bytes: Arc::from(
                wat::parse_str(include_str!("../../testdata/external/resource/x.wat")).unwrap(),
            ),
        });
        let functions = [
            (
                "counter",
                "[constructor]cell",
                vec![WitPlan::S64],
                WitPlan::Own(1),
            ),
            (
                "counter",
                "[method]cell.bump",
                vec![WitPlan::Borrow(1), WitPlan::S64],
                WitPlan::S64,
            ),
            (
                "counter",
                "[method]cell.pair",
                vec![WitPlan::Borrow(1), WitPlan::Borrow(1)],
                WitPlan::S64,
            ),
            (
                "counter",
                "[method]cell.live",
                vec![WitPlan::Borrow(1)],
                WitPlan::S64,
            ),
            ("second", "[constructor]cell", vec![], WitPlan::Own(2)),
        ]
        .into_iter()
        .enumerate()
        .map(|(id, (interface, export, params, result))| ExternalRef {
            component: 0,
            arity: u16::try_from(params.len()).unwrap(),
            spec: Arc::new(ExternalSpec {
                adapter: None,
                id: u32::try_from(id).unwrap(),
                function: export.into(),
                component: Arc::clone(&source),
                instance: Some(format!("bnt:test/{interface}@0.1.0")),
                export: export.into(),
                route: ExternalRoute::of(&params, Some(&result)),
                params,
                result: Some(result),
            }),
        })
        .collect();
        ExternalTable {
            components: vec![source],
            functions,
        }
    }

    // 関門: 同じ対象の状態と二つの対象の借用を、実際の ABI で確かめる。
    // 関数の照合だけでは、呼び出しごとに状態を捨てる退行を捕まえられない。
    // spec: 03-10 実行
    #[test]
    fn stateful_calls_keep_values_and_reset_limits() {
        let table = resources();
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let a = call(&mut runtime, &table, 0, ctx, &[Value::Int(10)]).unwrap();
            let b = call(&mut runtime, &table, 0, ctx, &[Value::Int(20)]).unwrap();
            assert_eq!(
                call(&mut runtime, &table, 1, ctx, &[a, Value::Int(2)])
                    .unwrap()
                    .as_int(),
                Some(12)
            );
            assert_eq!(
                call(&mut runtime, &table, 1, ctx, &[a, Value::Int(3)])
                    .unwrap()
                    .as_int(),
                Some(15)
            );
            assert_eq!(
                call(&mut runtime, &table, 2, ctx, &[a, b])
                    .unwrap()
                    .as_int(),
                Some(35)
            );
            assert_eq!(
                crate::runtime::heap::OpaqueData::heap_bytes(
                    ctx.opaque::<ExternalHandle>(a).unwrap()
                ),
                2 * 65536
            );
            for _ in 0..30 {
                assert_eq!(
                    call_with_fuel(
                        &mut runtime,
                        &table,
                        3,
                        ctx,
                        &[a],
                        Limits {
                            fuel: 100,
                            transfer: 1024,
                            ..Limits::default()
                        }
                    )
                    .unwrap()
                    .as_int(),
                    Some(2)
                );
            }
        });
    }
    // 関門: 回収前後の根を制御して、次の呼び出しでだけゲストを解放する契約を守る。
    // ゴールデンでは回収の時期が構成によって違うため、生きている数は比較できない。
    // spec: 03-10 実行
    #[test]
    fn collected_handles_are_released_before_next_call() {
        use crate::runtime::heap::RootStack;
        let table = resources();
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = RootStack::new();
        let a = heap.epoch(|ctx| {
            let a = call(&mut runtime, &table, 0, ctx, &[Value::Int(1)]).unwrap();
            let root = roots.push(ctx, a);
            let b = call(&mut runtime, &table, 0, ctx, &[Value::Int(2)]).unwrap();
            roots.push(ctx, b);
            assert_eq!(
                call(&mut runtime, &table, 3, ctx, &[a]).unwrap().as_int(),
                Some(2)
            );
            roots.truncate(ctx, 1);
            root
        });
        heap.collect(&roots);
        // 回収そのものはゲストに入らず、次の呼び出しの前に列を空にする。
        assert_eq!(
            runtime.stateful[0].as_ref().unwrap().queue.borrow().len(),
            1
        );
        heap.epoch(|ctx| {
            let a = roots.get(ctx, a).unwrap();
            assert_eq!(
                call(&mut runtime, &table, 3, ctx, &[a]).unwrap().as_int(),
                Some(1)
            );
            let b = call(&mut runtime, &table, 0, ctx, &[Value::Int(4)]).unwrap();
            assert_eq!(
                crate::runtime::heap::OpaqueData::heap_bytes(
                    ctx.opaque::<ExternalHandle>(b).unwrap()
                ),
                0
            );
            assert_eq!(
                call(&mut runtime, &table, 2, ctx, &[a, b])
                    .unwrap()
                    .as_int(),
                Some(5)
            );
        });
    }
    // 関門: 解放の失敗は次の呼び出しに返し、呼び出すメソッドと解放の名前を区別する。
    // 正常な解放のテストでは、失敗の分類と書き出し名を守れない。
    // spec: 03-10 実行
    #[test]
    fn destructor_failures_identify_resource_drop() {
        use crate::runtime::heap::RootStack;
        for (body, trap) in [("unreachable", true), ("loop br 0 end", false)] {
            let mut table = resources();
            let original = include_str!("../../testdata/external/resource/x.wat");
            let destructor_body = "local.get $rep\n      i32.const 16\n      i32.shl\n      global.get $free\n      i32.store offset=8";
            assert!(original.contains(destructor_body));
            let wat = original.replace(destructor_body, body);
            Arc::make_mut(&mut table.components[0]).bytes = wat::parse_str(&wat).unwrap().into();
            let mut runtime = ExternalRuntime::new(None).unwrap();
            let mut heap = Heap::new(HeapConfig::default());
            heap.epoch(|ctx| {
                call(&mut runtime, &table, 0, ctx, &[Value::Int(1)]).unwrap();
            });
            heap.collect(&RootStack::new());
            let result = heap.epoch(|ctx| {
                call_with_fuel(
                    &mut runtime,
                    &table,
                    0,
                    ctx,
                    &[Value::Int(2)],
                    Limits {
                        fuel: 1000,
                        ..Limits::default()
                    },
                )
                .map(|_| ())
            });
            match result {
                Err(ExternalFailure::Stop(Stop::Runtime(RuntimeError::ExternalTrap {
                    export,
                    ..
                }))) if trap => assert_eq!(export, "bnt:test/counter@0.1.0#[resource-drop]cell"),
                Err(ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalFuel {
                    ..
                }))) if !trap => {}
                other => panic!("{body}: {other:?}"),
            }
        }
    }

    // 関門: 同じ番号でも実行系と外部の型の違う値を、Wasmtime に入る前に拒否する。
    // spec: 03-10 実行
    #[test]
    fn handles_from_other_execution_or_resource_are_internal_failures() {
        let table = resources();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let mut runtime = ExternalRuntime::new(None).unwrap();
            let mut other = ExternalRuntime::new(None).unwrap();
            let a = call(&mut runtime, &table, 0, ctx, &[Value::Int(1)]).unwrap();
            let b = call(&mut runtime, &table, 4, ctx, &[]).unwrap();
            assert!(matches!(
                call(&mut other, &table, 3, ctx, &[a]),
                Err(ExternalFailure::Stop(Stop::Internal(_)))
            ));
            assert!(other.stateful[0].is_none());
            assert!(matches!(
                call(&mut runtime, &table, 3, ctx, &[b]),
                Err(ExternalFailure::Stop(Stop::Internal(_)))
            ));
            assert!(runtime.stateful[0].is_none());
        });
    }

    fn set_params(table: &mut ExternalTable, params: Vec<WitPlan>) {
        table.functions[0].arity = u16::try_from(params.len()).unwrap();
        let spec = Arc::make_mut(&mut table.functions[0].spec);
        spec.params = params;
        spec.route = ExternalRoute::of(&spec.params, spec.result.as_ref());
    }
    fn call_both<'e>(
        table: &ExternalTable,
        ctx: &NoGcCtx<'e>,
        args: &[Value<'e>],
    ) -> [Value<'e>; 2] {
        let spec = &table.functions[0].spec;
        let ExternalRoute::Typed(shape) = &spec.route else {
            panic!("expected typed route: {:?}", spec.route);
        };
        let runtime = ExternalRuntime::new(None).unwrap();
        let component = Component::from_binary(&runtime.engine, &spec.component.bytes).unwrap();
        [true, false].map(|typed| {
            let typed_args = typed::prepare(ctx, spec, shape, args, TRANSFER).unwrap();
            convert::check_arguments(ctx, spec, args, TRANSFER).unwrap();
            let dynamic_args = spec
                .params
                .iter()
                .zip(args)
                .map(|(p, v)| convert::to_wasm(ctx, p, *v, None))
                .collect::<Result<Vec<_>, _>>()
                .unwrap();
            let mut store = new_store(&runtime.engine, Limits::default()).unwrap();
            let instance = runtime.linker.instantiate(&mut store, &component).unwrap();
            let func = instance.get_func(&mut store, spec.export.as_str()).unwrap();
            if typed {
                call_typed(
                    &mut store,
                    &func,
                    ctx,
                    spec,
                    shape,
                    &typed_args,
                    (Limits::default(), &mut None),
                )
                .unwrap()
            } else {
                call_dynamic(
                    &mut store,
                    &func,
                    ctx,
                    spec,
                    &dynamic_args,
                    Limits::default(),
                    &mut None,
                )
                .unwrap()
            }
        })
    }
    // 関門: 引数の予算の拒否を start のトラップより先に報告する。
    // 既存のテストはインスタンス化が成功するため、この順序を守れない。
    // spec: 03-10 実行
    #[test]
    fn argument_budget_precedes_instantiation() {
        let wat = bytes_echo(1).replace(
            "(memory (export \"memory\") 1)",
            "(func $start unreachable) (start $start) (memory (export \"memory\") 1)",
        );
        let mut table = table(&wat, "f", Some(WitPlan::Bytes));
        set_params(&mut table, vec![WitPlan::Bytes]);
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let arg = ctx
                .alloc_bytes_with(
                    crate::runtime::heap::CheckedLen::bytes(1025, "test").unwrap(),
                    |out| out.fill(0),
                )
                .unwrap();
            for route in [
                table.functions[0].spec.route.clone(),
                ExternalRoute::Dynamic,
                ExternalRoute::Stateful,
            ] {
                Arc::make_mut(&mut table.functions[0].spec).route = route;
                let mut runtime = ExternalRuntime::new(None).unwrap();
                let result = call_with_fuel(
                    &mut runtime,
                    &table,
                    0,
                    ctx,
                    &[arg],
                    Limits {
                        transfer: 1024,
                        ..Limits::default()
                    },
                );
                assert!(
                    matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalTransfer { .. }
                        )))
                    ),
                    "{result:?}"
                );
            }
        });
    }

    // 関門: 個別には予算内の引数も、合計が予算を超えれば拒否する。
    // 単一の Bytes のテストは、引数ごとに予算を戻す退行を捕まえない。
    // spec: 03-10 実行
    #[test]
    fn typed_arguments_share_transfer_budget() {
        use crate::runtime::list;
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (plan, wit, count, element) in [
                (WitPlan::Bytes, "u8", 600, Value::Byte(0)),
                (
                    WitPlan::List(Box::new(WitPlan::U8)),
                    "u8",
                    600,
                    Value::Byte(0),
                ),
                (
                    WitPlan::List(Box::new(WitPlan::S64)),
                    "s64",
                    75,
                    Value::Int(0),
                ),
                (
                    WitPlan::List(Box::new(WitPlan::F64)),
                    "f64",
                    75,
                    Value::Float(0.0),
                ),
            ] {
                let mut table = table(
                    &format!(
                        r#"(component (core module $m
                    (memory (export "memory") 1)
                    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
                    (func (export "f") (param i32 i32 i32 i32) (result i64)
                        local.get 1 local.get 3 i32.add i64.extend_i32_u))
                    (core instance $i (instantiate $m)) (type $list (list {wit}))
                    (func (export "f") (param "s" string) (param "b" $list) (result s64)
                        (canon lift (core func $i "f") (memory (core memory $i "memory"))
                            (realloc (core func $i "realloc")))))"#
                    ),
                    "f",
                    Some(WitPlan::S64),
                );
                set_params(&mut table, vec![WitPlan::String, plan.clone()]);
                let s = ctx.alloc_str(&"x".repeat(600), "test").unwrap();
                let b = if plan == WitPlan::Bytes {
                    ctx.alloc_bytes_with(
                        crate::runtime::heap::CheckedLen::bytes(600, "test").unwrap(),
                        |out| out.fill(0),
                    )
                    .unwrap()
                } else {
                    list::from_values(ctx, &vec![element; count], "test").unwrap()
                };
                for transfer in [1024, 1200] {
                    let mut runtime = ExternalRuntime::new(None).unwrap();
                    let result = call_with_fuel(
                        &mut runtime,
                        &table,
                        0,
                        ctx,
                        &[s, b],
                        Limits {
                            transfer,
                            ..Limits::default()
                        },
                    );
                    if transfer == 1024 {
                        assert!(
                            matches!(
                                result,
                                Err(ExternalFailure::Stop(Stop::Resource(
                                    ResourceError::ExternalTransfer { .. }
                                )))
                            ),
                            "{plan:?}: {result:?}"
                        );
                    } else {
                        assert_eq!(result.unwrap().as_int(), Some(600 + count as i64));
                    }
                }
            }
        });
    }

    fn bytes_echo(pages: u32) -> String {
        format!(
            r#"(component (core module $m
            (memory (export "memory") {pages})
            (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
            (func (export "f") (param i32 i32) (result i32)
                i32.const 0 local.get 0 i32.store i32.const 4 local.get 1 i32.store i32.const 0))
            (core instance $i (instantiate $m))
            (type $bytes (list u8))
            (func (export "f") (param "v" $bytes) (result $bytes)
                (canon lift (core func $i "f") (memory (core memory $i "memory"))
                    (realloc (core func $i "realloc")))))"#
        )
    }
    fn component(body: &str) -> String {
        format!(
            r#"(component (core module $m {body})
            (core instance $i (instantiate $m))
            (func (export "f") (canon lift (core func $i "f"))))"#
        )
    }
    // 関門: 本物の Wasm の実行で、停止の分類とインスタンスの分離を守る。
    // 静的な照合のテストはトラップや memory.grow を実行しない。
    #[test]
    fn failures_and_fresh_instances() {
        let cases = [
            ("(func (export \"f\") unreachable)", "trap"),
            ("(func (export \"f\") (loop br 0))", "fuel"),
            (
                "(memory 1) (func (export \"f\") i32.const 1024 memory.grow drop)",
                "memory",
            ),
            (
                "(func $rec call $rec) (func (export \"f\") call $rec)",
                "stack",
            ),
        ];
        let interface_trap = r#"(component
            (core module $m (func (export "f") unreachable))
            (core instance $i (instantiate $m))
            (func $f (canon lift (core func $i "f")))
            (instance $api (export "f" (func $f)))
            (export "bnt:test/api@1.2.0" (instance $api)))"#;
        let mut heap = Heap::new(HeapConfig::default());
        // 静的な照合のテストでは通らない実行時の名前の表示を、同じ失敗の表で守る。
        // spec: 03-10 実行
        for (wat, instance, expected) in cases
            .into_iter()
            .map(|(body, expected)| (component(body), None, expected))
            .chain([(interface_trap.into(), Some("bnt:test/api@1.2.0"), "trap")])
        {
            let mut table = table(&wat, "f", None);
            Arc::make_mut(&mut table.functions[0].spec).instance = instance.map(str::to_owned);
            let mut runtime = ExternalRuntime::new(None).unwrap();
            let result = heap.epoch(|ctx| {
                call_with_fuel(
                    &mut runtime,
                    &table,
                    0,
                    ctx,
                    &[],
                    Limits {
                        fuel: 100_000,
                        ..Limits::default()
                    },
                )
                .map(|_| ())
            });
            match (expected, result) {
                (
                    "trap",
                    Err(ExternalFailure::Stop(Stop::Runtime(RuntimeError::ExternalTrap {
                        trap,
                        export,
                        ..
                    }))),
                ) => {
                    assert!(trap.contains("unreachable"));
                    assert_eq!(
                        export,
                        instance.map_or_else(|| "f".to_owned(), |name| format!("{name}#f"))
                    );
                }
                (
                    "stack",
                    Err(ExternalFailure::Stop(Stop::Runtime(RuntimeError::ExternalTrap {
                        trap,
                        ..
                    }))),
                ) => assert!(trap.contains("stack")),
                (
                    "fuel",
                    Err(ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalFuel {
                        limit,
                        ..
                    }))),
                ) => assert_eq!(limit, 100_000),
                (
                    "memory",
                    Err(ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalMemory {
                        limit,
                        ..
                    }))),
                ) => assert_eq!(limit, MEMORY),
                (_, result) => panic!("{expected}: {result:?}"),
            }
        }
        let mut lowering = table(
            r#"(component (core module $m
            (memory (export "memory") 1)
            (func (export "realloc") (param i32 i32 i32 i32) (result i32)
                i32.const 1024 memory.grow drop i32.const 0)
            (func (export "f") (param i32 i32)))
            (core instance $i (instantiate $m))
            (func (export "f") (param "s" string)
                (canon lift (core func $i "f") (memory (core memory $i "memory"))
                    (realloc (core func $i "realloc")))))"#,
            "f",
            None,
        );
        set_params(&mut lowering, vec![WitPlan::String]);
        let mut runtime = ExternalRuntime::new(None).unwrap();
        heap.epoch(|ctx| {
            let arg = ctx.alloc_str("argument", "test").unwrap();
            assert!(matches!(
                call(&mut runtime, &lowering, 0, ctx, &[arg]),
                Err(ExternalFailure::Stop(Stop::Resource(
                    ResourceError::ExternalMemory { .. }
                )))
            ));
        });
        let wat = r#"(component (core module $m
            (global $counter (mut i64) (i64.const 0))
            (func (export "f") (result i64)
                global.get $counter i64.const 1 i64.add global.set $counter global.get $counter))
            (core instance $i (instantiate $m))
            (func (export "f") (result s64) (canon lift (core func $i "f"))))"#;
        let table = table(wat, "f", Some(WitPlan::S64));
        let mut runtime = ExternalRuntime::new(None).unwrap();
        for _ in 0..2 {
            heap.epoch(|ctx| {
                assert_eq!(
                    call(&mut runtime, &table, 0, ctx, &[]).unwrap().as_int(),
                    Some(1)
                )
            });
        }
    }

    // 関門: 動的な ABI の持ち上げと資源制限を、本物のコンポーネントで確かめる。
    // 変換単体では Wasmtime の hostcall fuel や複数メモリの制限を通らない。
    // spec: 03-10 実行
    #[test]
    fn bytes_transfer_budget_and_empty_values() {
        let mut echo_table = table(&bytes_echo(176), "f", Some(WitPlan::Bytes));
        set_params(&mut echo_table, vec![WitPlan::Bytes]);
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for size in [0, 64, 10 * 1024 * 1024] {
                let bytes = vec![0xa5; size];
                let length = crate::runtime::heap::CheckedLen::bytes(size as u64, "test").unwrap();
                let arg = ctx
                    .alloc_bytes_with(length, |out| out.copy_from_slice(&bytes))
                    .unwrap();
                if size <= 64 {
                    for result in call_both(&echo_table, ctx, &[arg]) {
                        assert_eq!(ctx.bytes(result), Some(bytes.as_slice()));
                    }
                }
                let result = call(&mut runtime, &echo_table, 0, ctx, &[arg]).unwrap();
                assert_eq!(ctx.bytes(result), Some(bytes.as_slice()));
                if size > 64 {
                    assert!(matches!(
                        convert::check_arguments(
                            ctx,
                            &echo_table.functions[0].spec,
                            &[arg],
                            TRANSFER
                        ),
                        Err(Stop::Resource(ResourceError::ExternalTransfer { .. }))
                    ));
                }
            }
        });
        // 戻り値を持たない関数に渡し、戻り値の予算の拒否で誤って通らないようにする。
        let mut consume = table(
            r#"(component (core module $m
            (memory (export "memory") 128)
            (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
            (func (export "f") (param i32 i32)))
            (core instance $i (instantiate $m)) (type $bytes (list u8))
            (func (export "f") (param "v" $bytes)
                (canon lift (core func $i "f") (memory (core memory $i "memory"))
                    (realloc (core func $i "realloc")))))"#,
            "f",
            None,
        );
        set_params(&mut consume, vec![WitPlan::Bytes]);
        let mut runtime = ExternalRuntime::new(None).unwrap();
        heap.epoch(|ctx| {
            let length = crate::runtime::heap::CheckedLen::bytes(7 * 1024 * 1024, "test").unwrap();
            let arg = ctx.alloc_bytes_with(length, |out| out.fill(0)).unwrap();
            let result = call(&mut runtime, &consume, 0, ctx, &[arg]);
            assert!(
                matches!(
                    result,
                    Err(ExternalFailure::Stop(Stop::Resource(
                        ResourceError::ExternalTransfer {
                            limit: 268_435_456,
                            ..
                        }
                    )))
                ),
                "{result:?}"
            );
        });
        let oversized = r#"(component (core module $m
            (memory (export "memory") 128)
            (func (export "f") (result i32)
                i32.const 4 i32.const 7340032 i32.store i32.const 0))
            (core instance $i (instantiate $m))
            (type $bytes (list u8))
            (func (export "f") (result $bytes)
                (canon lift (core func $i "f") (memory (core memory $i "memory")))))"#;
        let mut table = table(oversized, "f", Some(WitPlan::List(Box::new(WitPlan::U8))));
        Arc::make_mut(&mut table.functions[0].spec).route = ExternalRoute::Dynamic;
        let mut runtime = ExternalRuntime::new(None).unwrap();
        assert!(matches!(
            heap.epoch(|ctx| call(&mut runtime, &table, 0, ctx, &[]).map(|_| ())),
            Err(ExternalFailure::Stop(Stop::Resource(
                ResourceError::ExternalTransfer {
                    limit: 268_435_456,
                    ..
                }
            )))
        ));
    }

    // 関門: 個々のメモリが上限内でも、同じ呼び出しの合計で拒否する。
    // 単一の memory.grow の検査では、初期メモリと別インスタンスの合計を守れない。
    // spec: 02-09 外部の関数の実行
    #[test]
    fn initial_and_growing_memories_share_call_budget() {
        for (body, allowed) in [
            ("(memory 512) (func (export \"f\"))", true),
            ("(memory 600) (func (export \"f\"))", false),
            (
                "(memory 1) (func $start i32.const 600 memory.grow drop) (start $start) (func (export \"f\"))",
                false,
            ),
        ] {
            let wat = format!(
                r#"(component (core module $m {body})
                (core instance $a (instantiate $m)) (core instance $b (instantiate $m))
                (func (export "f") (canon lift (core func $a "f"))))"#
            );
            let table = table(&wat, "f", None);
            let mut runtime = ExternalRuntime::new(None).unwrap();
            let mut heap = Heap::new(HeapConfig::default());
            let result = heap.epoch(|ctx| call(&mut runtime, &table, 0, ctx, &[]).map(|_| ()));
            if allowed {
                result.unwrap();
                continue;
            }
            assert!(
                matches!(
                    result,
                    Err(ExternalFailure::Stop(Stop::Resource(
                        ResourceError::ExternalMemory { limit: MEMORY, .. }
                    )))
                ),
                "{result:?}"
            );
        }
    }

    // 関門: NaN と無限大の型と値を、変換単体でなく Component Model の ABI 往復で守る。
    // spec: 03-10 型の対応
    #[test]
    fn floats_and_empty_string_roundtrip() {
        let mut floats = table(
            r#"(component (core module $m
            (func (export "f") (param f64) (result f64) local.get 0))
            (core instance $i (instantiate $m))
            (func (export "f") (param "v" f64) (result f64) (canon lift (core func $i "f"))))"#,
            "f",
            Some(WitPlan::F64),
        );
        set_params(&mut floats, vec![WitPlan::F64]);
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for value in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
                for result in call_both(&floats, ctx, &[Value::Float(value)]) {
                    let result = result.as_float().unwrap();
                    if value.is_nan() {
                        assert!(result.is_nan());
                    } else {
                        assert_eq!(result, value);
                    }
                }
            }
        });
        let empty = table(
            r#"(component (core module $m
            (memory (export "memory") 1) (func (export "f") (result i32) i32.const 0))
            (core instance $i (instantiate $m))
            (func (export "f") (result string)
                (canon lift (core func $i "f") (memory (core memory $i "memory")))))"#,
            "f",
            Some(WitPlan::String),
        );
        heap.epoch(|ctx| {
            for result in call_both(&empty, ctx, &[]) {
                assert_eq!(ctx.str(result), Some(""));
            }
        });
    }

    // 関門: 自身の maximum の拒否は -1 で続き、ホストの資源制限と区別する。
    // spec: 02-09 外部の関数の実行
    #[test]
    fn memory_grow_beyond_guest_maximum_returns_minus_one() {
        let table = table(
            r#"(component (core module $m (memory 1 2) (func (export "f") (result i64) i32.const 100000 memory.grow i64.extend_i32_s)) (core instance $i (instantiate $m)) (func (export "f") (result s64) (canon lift (core func $i "f"))))"#,
            "f",
            Some(WitPlan::S64),
        );
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            assert_eq!(
                call(&mut runtime, &table, 0, ctx, &[]).unwrap().as_int(),
                Some(-1)
            )
        });
    }

    // 関門: 実際のインスタンス化が返す数の上限超過を、トラップに紛れ込ませない。
    // spec: 02-09 外部の関数の実行
    #[test]
    fn object_count_limits_are_resource_failures() {
        for (body, instances, expected) in [
            (
                "(func (export \"f\"))".to_owned(),
                (0..17)
                    .map(|i| format!("(core instance $i{i} (instantiate $m))"))
                    .collect::<String>(),
                "core instances",
            ),
            (
                format!("{} (func (export \"f\"))", "(memory 0) ".repeat(17)),
                "(core instance $i0 (instantiate $m))".into(),
                "core memories",
            ),
            (
                format!("{} (func (export \"f\"))", "(table 0 funcref) ".repeat(17)),
                "(core instance $i0 (instantiate $m))".into(),
                "core tables",
            ),
        ] {
            let table = table(
                &format!(
                    "(component (core module $m {body}) {instances} (func (export \"f\") (canon lift (core func $i0 \"f\"))))"
                ),
                "f",
                None,
            );
            let mut runtime = ExternalRuntime::new(None).unwrap();
            let mut heap = Heap::new(HeapConfig::default());
            let result = heap.epoch(|ctx| call(&mut runtime, &table, 0, ctx, &[]).map(|_| ()));
            assert!(
                matches!(result, Err(ExternalFailure::Stop(Stop::Resource(
                ResourceError::ExternalObjects { resource, size: 17, limit: 16, .. }
            ))) if resource == expected),
                "{result:?}"
            );
        }
    }

    // 関門: 受け渡しの数え方を決める経路の契約を、型の境界の前後で確かめる。
    // ABI の照合だけでは、入れ子と引数の数による予算の違いを守れない。
    // spec: 03-10 実行
    #[test]
    fn routes_follow_declared_types_and_arity() {
        use crate::external::TypedKind;
        assert_eq!(
            ExternalRoute::of(
                &[WitPlan::S64, WitPlan::String, WitPlan::Bytes],
                Some(&WitPlan::F64)
            ),
            ExternalRoute::Typed(TypedShape {
                params: vec![TypedKind::S64, TypedKind::String, TypedKind::Bytes],
                result: TypedKind::F64,
            })
        );
        assert_eq!(
            ExternalRoute::of(&[], Some(&WitPlan::S64)),
            ExternalRoute::Typed(TypedShape {
                params: vec![],
                result: TypedKind::S64
            })
        );
        for (element, kind) in [
            (WitPlan::U8, TypedKind::ListU8),
            (WitPlan::S64, TypedKind::ListS64),
            (WitPlan::F64, TypedKind::ListF64),
        ] {
            let list = WitPlan::List(Box::new(element));
            assert_eq!(
                ExternalRoute::of(std::slice::from_ref(&list), Some(&list)),
                ExternalRoute::Typed(TypedShape {
                    params: vec![kind],
                    result: kind
                })
            );
            for position in 0..2 {
                let mut params = vec![WitPlan::Bytes; 2];
                params[position] = list.clone();
                let mut kinds = vec![TypedKind::Bytes; 2];
                kinds[position] = kind;
                assert_eq!(
                    ExternalRoute::of(&params, Some(&list)),
                    ExternalRoute::Typed(TypedShape {
                        params: kinds,
                        result: kind,
                    })
                );
            }
            for position in 0..3 {
                let mut params = vec![WitPlan::Bytes; 3];
                params[position] = list.clone();
                let expected = if kind == TypedKind::ListU8 {
                    let mut kinds = vec![TypedKind::Bytes; 3];
                    kinds[position] = kind;
                    ExternalRoute::Typed(TypedShape {
                        params: kinds,
                        result: kind,
                    })
                } else {
                    ExternalRoute::Dynamic
                };
                assert_eq!(ExternalRoute::of(&params, Some(&list)), expected);
            }
            let params = vec![list.clone(); 3];
            let expected = if kind == TypedKind::ListU8 {
                ExternalRoute::Typed(TypedShape {
                    params: vec![kind; 3],
                    result: kind,
                })
            } else {
                ExternalRoute::Dynamic
            };
            assert_eq!(ExternalRoute::of(&params, Some(&list)), expected);
            assert_eq!(
                ExternalRoute::of(
                    &[WitPlan::Bytes, WitPlan::Bytes, WitPlan::Bytes],
                    Some(&list)
                ),
                ExternalRoute::Typed(TypedShape {
                    params: vec![TypedKind::Bytes; 3],
                    result: kind,
                })
            );
            for nested in [
                WitPlan::List(Box::new(list.clone())),
                WitPlan::Option(Box::new(list.clone())),
                WitPlan::Result {
                    ok: Some(Box::new(list.clone())),
                    err: None,
                },
                WitPlan::Tuple(vec![list.clone(), WitPlan::S64]),
                WitPlan::Record {
                    fields: vec![("items".into(), list.clone())],
                },
            ] {
                assert_eq!(
                    ExternalRoute::of(std::slice::from_ref(&nested), Some(&list)),
                    ExternalRoute::Dynamic
                );
                assert_eq!(
                    ExternalRoute::of(std::slice::from_ref(&list), Some(&nested)),
                    ExternalRoute::Dynamic
                );
            }
        }
        for (params, result) in [
            (vec![WitPlan::S64; 4], Some(WitPlan::S64)),
            (vec![WitPlan::Bool], Some(WitPlan::S64)),
            (
                vec![WitPlan::List(Box::new(WitPlan::U8)); 4],
                Some(WitPlan::Bytes),
            ),
            (vec![], Some(WitPlan::Bool)),
            (vec![], Some(WitPlan::List(Box::new(WitPlan::Bool)))),
            (vec![WitPlan::Bytes], None),
        ] {
            assert_eq!(
                ExternalRoute::of(&params, result.as_ref()),
                ExternalRoute::Dynamic
            );
        }
    }

    // 関門: 型の異なる引数の位置と戻り値を、実際の ABI と期待値で確かめる。
    // 単独の型の往復では、複数引数の具体化の取り違えを検出できない。
    // spec: 03-10 実行
    #[test]
    fn mixed_typed_and_dynamic_calls_agree() {
        let mut numbers = table(
            r#"(component (core module $m
            (func (export "f") (param i64 f64 i64) (result f64)
                local.get 0 f64.convert_i64_s local.get 1 f64.add
                local.get 2 f64.convert_i64_s f64.sub))
            (core instance $i (instantiate $m))
            (func (export "f") (param "a" s64) (param "b" f64) (param "c" s64)
                (result f64) (canon lift (core func $i "f"))))"#,
            "f",
            Some(WitPlan::F64),
        );
        set_params(&mut numbers, vec![WitPlan::S64, WitPlan::F64, WitPlan::S64]);
        let mut prefix = table(
            r#"(component (core module $m
            (memory (export "memory") 1)
            (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
            (func (export "f") (param i32 i32 i64) (result i32)
                i32.const 0 local.get 0 i32.store
                i32.const 4 local.get 2 i32.wrap_i64 i32.store i32.const 0))
            (core instance $i (instantiate $m))
            (func (export "f") (param "s" string) (param "n" s64) (result string)
                (canon lift (core func $i "f") (memory (core memory $i "memory"))
                    (realloc (core func $i "realloc")))))"#,
            "f",
            Some(WitPlan::String),
        );
        set_params(&mut prefix, vec![WitPlan::String, WitPlan::S64]);
        let constant = table(
            r#"(component (core module $m (func (export "f") (result i64) i64.const -42))
            (core instance $i (instantiate $m))
            (func (export "f") (result s64) (canon lift (core func $i "f"))))"#,
            "f",
            Some(WitPlan::S64),
        );
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for result in call_both(
                &numbers,
                ctx,
                &[Value::Int(7), Value::Float(0.5), Value::Int(2)],
            ) {
                assert_eq!(result.as_float(), Some(5.5));
            }
            let text = ctx.alloc_str("héllo", "test").unwrap();
            for result in call_both(&prefix, ctx, &[text, Value::Int(3)]) {
                assert_eq!(ctx.str(result), Some("hé"));
            }
            for result in call_both(&constant, ctx, &[]) {
                assert_eq!(result.as_int(), Some(-42));
            }
        });
    }

    // 関門: リストの型付き変換は順序・境界の値・空の結果を動的な経路と同じに保つ。
    // 既存の Bytes の比較は数の要素と、借用する並びの引数の位置を検査しない。
    // spec: 03-10 実行
    #[test]
    fn typed_lists_and_dynamic_calls_agree() {
        use crate::runtime::list;
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (element, wit, width, values) in [
                (WitPlan::U8, "u8", 1, vec![Value::Byte(42), Value::Byte(0), Value::Byte(255)]),
                (WitPlan::S64, "s64", 8, vec![Value::Int(42), Value::Int(i64::MIN), Value::Int(-1), Value::Int(0), Value::Int(i64::MAX)]),
                (WitPlan::F64, "f64", 8, vec![Value::Float(42.0), Value::Float(-f64::MAX), Value::Float(-0.0), Value::Float(f64::MIN_POSITIVE), Value::Float(f64::MAX), Value::Float(f64::from_bits(0x7ff8_0000_0000_1234)), Value::Float(f64::NEG_INFINITY), Value::Float(f64::INFINITY)]),
            ] {
                let plan = WitPlan::List(Box::new(element));
                let wat = format!(r#"(component (core module $m
                    (memory (export "memory") 1)
                    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
                    (func (export "f") (param i64 i32 i32) (result i32) (local $skip i32)
                        local.get 0 i32.wrap_i64 local.set $skip
                        local.get 2 local.get $skip i32.lt_u
                        if local.get 2 local.set $skip end
                        i32.const 0 local.get 1 local.get $skip i32.const {width} i32.mul i32.add i32.store
                        i32.const 4 local.get 2 local.get $skip i32.sub i32.store i32.const 0))
                    (core instance $i (instantiate $m)) (type $list (list {wit}))
                    (func (export "f") (param "n" s64) (param "v" $list) (result $list)
                        (canon lift (core func $i "f") (memory (core memory $i "memory"))
                            (realloc (core func $i "realloc")))))"#);
                let mut table = table(&wat, "f", Some(plan.clone()));
                set_params(&mut table, vec![WitPlan::S64, plan]);
                for input in [&values[..], &values[..1], &[][..]] {
                    let arg = list::from_values(ctx, input, "test").unwrap();
                    let expected = input.get(1..).unwrap_or_default();
                    for result in call_both(&table, ctx, &[Value::Int(1), arg]) {
                        let actual = list::to_vec(ctx, result).unwrap();
                        assert_eq!(actual.len(), expected.len());
                        for (actual, expected) in actual.into_iter().zip(expected) {
                            match (actual, *expected) {
                                (Value::Byte(a), Value::Byte(b)) => assert_eq!(a, b),
                                (Value::Int(a), Value::Int(b)) => assert_eq!(a, b),
                                (Value::Float(a), Value::Float(b)) => assert_eq!(a.to_bits(), b.to_bits()),
                                pair => panic!("unexpected elements: {pair:?}"),
                            }
                        }
                    }
                }
            }
            // 同じ WIT の型でも、Bytes とリストの宣言に従って値を作る。
            let plan = WitPlan::List(Box::new(WitPlan::U8));
            let mut to_list = table(&bytes_echo(1), "f", Some(plan.clone()));
            set_params(&mut to_list, vec![WitPlan::Bytes]);
            let mut to_bytes = table(&bytes_echo(1), "f", Some(WitPlan::Bytes));
            set_params(&mut to_bytes, vec![plan]);
            let bytes = ctx.alloc_bytes_with(crate::runtime::heap::CheckedLen::bytes(3, "test").unwrap(), |out| out.copy_from_slice(&[0, 42, 255])).unwrap();
            for result in call_both(&to_list, ctx, &[bytes]) {
                assert_eq!(list::to_vec(ctx, result).unwrap().into_iter().map(|v| v.as_byte().unwrap()).collect::<Vec<_>>(), [0, 42, 255]);
                for result in call_both(&to_bytes, ctx, &[result]) {
                    assert_eq!(ctx.bytes(result).unwrap(), [0, 42, 255]);
                }
            }
        });
    }

    // 関門: 3 引数では List[Byte] だけが型付きの具体化を通り、数のリストは動的な経路で同じ結果を返す。
    // 2 引数の比較は 3 引数の振り分けの分岐と、そこから外した組の実行を検査しない。
    // spec: 03-10 実行
    #[test]
    fn three_argument_list_calls_follow_their_routes() {
        use crate::runtime::list;
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (element, wit, width, values, typed) in [
                (WitPlan::U8, "u8", 1, vec![Value::Byte(7), Value::Byte(0), Value::Byte(255)], true),
                (WitPlan::S64, "s64", 8, vec![Value::Int(7), Value::Int(i64::MIN), Value::Int(i64::MAX)], false),
                (WitPlan::F64, "f64", 8, vec![Value::Float(7.0), Value::Float(-0.0), Value::Float(f64::from_bits(0x7ff8_0000_0000_1234))], false),
            ] {
                let plan = WitPlan::List(Box::new(element));
                let wat = format!(r#"(component (core module $m
                    (memory (export "memory") 1)
                    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
                    (func (export "f") (param i64 i32 i32 f64) (result i32)
                        i32.const 0 local.get 1 i32.const {width} i32.add i32.store
                        i32.const 4 local.get 2 i32.const 1 i32.sub i32.store i32.const 0))
                    (core instance $i (instantiate $m)) (type $list (list {wit}))
                    (func (export "f") (param "n" s64) (param "v" $list) (param "extra" f64) (result $list)
                        (canon lift (core func $i "f") (memory (core memory $i "memory"))
                            (realloc (core func $i "realloc")))))"#);
                let mut table = table(&wat, "f", Some(plan.clone()));
                set_params(&mut table, vec![WitPlan::S64, plan, WitPlan::F64]);
                assert_eq!(matches!(table.functions[0].spec.route, ExternalRoute::Typed(_)), typed);
                let arg = list::from_values(ctx, &values, "test").unwrap();
                let args = [Value::Int(1), arg, Value::Float(0.5)];
                let results = if typed {
                    call_both(&table, ctx, &args).to_vec()
                } else {
                    let mut runtime = ExternalRuntime::new(None).unwrap();
                    vec![call(&mut runtime, &table, 0, ctx, &args).unwrap()]
                };
                for result in results {
                    let actual = list::to_vec(ctx, result).unwrap();
                    assert_eq!(actual.len(), 2);
                    for (actual, expected) in actual.into_iter().zip(&values[1..]) {
                        match (actual, *expected) {
                            (Value::Byte(a), Value::Byte(b)) => assert_eq!(a, b),
                            (Value::Int(a), Value::Int(b)) => assert_eq!(a, b),
                            (Value::Float(a), Value::Float(b)) => assert_eq!(a.to_bits(), b.to_bits()),
                            pair => panic!("unexpected elements: {pair:?}"),
                        }
                    }
                }
            }
        });
    }

    // 関門: 借用する Bytes と所有する List[Byte] を同じ具体化に並べ、順序と予算の合算を守る。
    // 単独の往復では、並びの取り違えと引数の一方だけを数える退行を捕まえない。
    // spec: 03-10 実行
    #[test]
    fn bytes_and_byte_list_share_typed_call_and_sum_transfer_costs() {
        use super::super::stats::{Collector, ExecutionOptions};
        let mut table = table(
            r#"(component (core module $m
                (memory (export "memory") 1)
                (global $next (mut i32) (i32.const 1024))
                (func (export "realloc") (param i32 i32 i32 i32) (result i32)
                    (local $ptr i32)
                    global.get $next local.tee $ptr local.get 3 i32.add global.set $next
                    local.get $ptr)
                (func (export "f") (param i32 i32 i32 i32) (result i32)
                    i32.const 2048 local.get 0 local.get 1 memory.copy
                    i32.const 2048 local.get 1 i32.add local.get 2 local.get 3 memory.copy
                    i32.const 0 i32.const 2048 i32.store
                    i32.const 4 local.get 1 local.get 3 i32.add i32.store i32.const 0))
                (core instance $i (instantiate $m)) (type $bytes (list u8))
                (func (export "f") (param "a" $bytes) (param "b" $bytes) (result $bytes)
                    (canon lift (core func $i "f") (memory (core memory $i "memory"))
                        (realloc (core func $i "realloc")))))"#,
            "f",
            Some(WitPlan::Bytes),
        );
        set_params(
            &mut table,
            vec![WitPlan::Bytes, WitPlan::List(Box::new(WitPlan::U8))],
        );
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let bytes = ctx
                .alloc_bytes_with(
                    crate::runtime::heap::CheckedLen::bytes(3, "test").unwrap(),
                    |out| {
                        out.copy_from_slice(&[0, 42, 255]);
                    },
                )
                .unwrap();
            let list =
                crate::runtime::list::from_values(ctx, &[Value::Byte(7), Value::Byte(128)], "test")
                    .unwrap();
            for transfer in [4, 5] {
                let stats = Collector::new();
                let mut runtime = ExternalRuntime::configured(
                    None,
                    ExecutionOptions {
                        limits: Limits {
                            transfer,
                            ..Limits::default()
                        },
                        stats: Some(stats.clone()),
                    },
                )
                .unwrap();
                let result = call(&mut runtime, &table, 0, ctx, &[bytes, list]);
                if transfer == 4 {
                    assert!(matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalTransfer { limit: 4, .. }
                        )))
                    ));
                } else {
                    assert_eq!(ctx.bytes(result.unwrap()).unwrap(), [0, 42, 255, 7, 128]);
                    let json = stats.json().unwrap();
                    assert_eq!(json["arguments_transfer"]["total"], 5);
                    assert_eq!(json["results_transfer"]["total"], 5);
                }
            }
        });
    }

    // 関門: 6 MB のバイトのリストを 40 倍せずに渡し、統計にも同じ量を報告する。
    // 小さい値の結果比較と Bytes の計数だけでは、リストが動的な経路へ戻る退行を捕まえない。
    // spec: 03-10 実行
    #[test]
    fn six_megabyte_byte_list_uses_one_transfer_byte_per_element() {
        use super::super::stats::{Collector, ExecutionOptions};
        use crate::runtime::list;
        let mut table = table(&bytes_echo(92), "f", Some(WitPlan::Bytes));
        set_params(&mut table, vec![WitPlan::List(Box::new(WitPlan::U8))]);
        let stats = Collector::new();
        let mut runtime = ExternalRuntime::configured(
            None,
            ExecutionOptions {
                limits: Limits {
                    transfer: 6_000_000,
                    ..Limits::default()
                },
                stats: Some(stats.clone()),
            },
        )
        .unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let input = vec![Value::Byte(0xa5); 6_000_000];
            let arg = list::from_values(ctx, &input, "test").unwrap();
            let result = call(&mut runtime, &table, 0, ctx, &[arg]).unwrap();
            let bytes = ctx.bytes(result).unwrap();
            assert_eq!(bytes.len(), 6_000_000);
            assert!(bytes.iter().all(|b| *b == 0xa5));
        });
        let json = stats.json().unwrap();
        assert_eq!(json["arguments_transfer"]["total"], 6_000_000);
        assert_eq!(json["results_transfer"]["total"], 6_000_000);
        assert_eq!(json["arguments_transfer"]["maximum"], 6_000_000);
        assert_eq!(json["results_transfer"]["maximum"], 6_000_000);
    }

    // 関門: リストの要素上限を超える戻り値を、言語の値の確保より先に拒否する。
    // 動的な経路では同じ長さが先に受け渡しの予算に達する。
    // list<s64> の要素上限超過は既定の線形メモリ上限 64 MiB に先に阻まれるため、ここでは検査しない。
    // spec: 02-09 外部の関数の実行
    #[test]
    fn typed_list_result_obeys_element_limit() {
        let table = table(
            r#"(component (core module $m
            (memory (export "memory") 257)
            (func (export "f") (result i32)
                i32.const 8 i32.const 16777217 i32.store i32.const 4))
            (core instance $i (instantiate $m)) (type $list (list u8))
            (func (export "f") (result $list)
                (canon lift (core func $i "f") (memory (core memory $i "memory")))))"#,
            "f",
            Some(WitPlan::List(Box::new(WitPlan::U8))),
        );
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        let result = heap.epoch(|ctx| call(&mut runtime, &table, 0, ctx, &[]).map(|_| ()));
        assert!(
            matches!(
                result,
                Err(ExternalFailure::Stop(Stop::Resource(
                    ResourceError::ExternalValueTooLarge {
                        size: 16_777_217,
                        unit: crate::runtime::SizeUnit::Elements,
                        limit: 16_777_216,
                        ..
                    }
                )))
            ),
            "{result:?}"
        );
    }

    // 関門: 取得した戻り値の計数は ABI の種類で違い、設定値の読み出しでは守れない。
    // spec: 03-10 実行
    #[test]
    fn statistics_count_typed_dynamic_and_stateful_calls() {
        use super::super::stats::{Collector, ExecutionOptions};
        let mut echo = table(&bytes_echo(1), "f", Some(WitPlan::Bytes));
        set_params(&mut echo, vec![WitPlan::Bytes]);
        let stats = Collector::new();
        let mut runtime = ExternalRuntime::configured(
            None,
            ExecutionOptions {
                limits: Limits::default(),
                stats: Some(stats.clone()),
            },
        )
        .unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let len = crate::runtime::heap::CheckedLen::bytes(3, "test").unwrap();
            let bytes = ctx.alloc_bytes_with(len, |out| out.fill(42)).unwrap();
            call(&mut runtime, &echo, 0, ctx, &[bytes]).unwrap();
            Arc::make_mut(&mut echo.functions[0].spec).route = ExternalRoute::Dynamic;
            call(&mut runtime, &echo, 0, ctx, &[bytes]).unwrap();
        });
        let json = stats.json().unwrap();
        assert_eq!(json["calls"], 2);
        assert_eq!(json["routes"]["typed"], 1);
        assert_eq!(json["routes"]["dynamic"], 1);
        assert_eq!(
            json["arguments_transfer"]["total"],
            3 + 3 * std::mem::size_of::<Val>()
        );
        assert_eq!(
            json["results_transfer"]["total"],
            3 + 3 * std::mem::size_of::<Val>()
        );
        assert_eq!(json["memory"]["total"], 2 * 65536);
        assert_eq!(json["memory"]["maximum"], 65536);
        assert_eq!(json["results_transfer"]["incomplete_calls"], 0);
        assert_eq!(json["construction_bytes"]["incomplete_calls"], 0);

        // 同名の宣言でも、別のコンポーネントの呼び出しを合算しない。
        let mut other = echo.clone();
        let source = Arc::new(ComponentSource {
            display: "wasm/other.wasm".into(),
            bytes: Arc::clone(&other.components[0].bytes),
        });
        other.components[0] = Arc::clone(&source);
        Arc::make_mut(&mut other.functions[0].spec).component = source;
        let mut other_runtime = ExternalRuntime::configured(
            None,
            ExecutionOptions {
                limits: Limits::default(),
                stats: Some(stats.clone()),
            },
        )
        .unwrap();
        heap.epoch(|ctx| {
            let len = crate::runtime::heap::CheckedLen::bytes(1, "test").unwrap();
            let bytes = ctx.alloc_bytes_with(len, |out| out.fill(42)).unwrap();
            call(&mut other_runtime, &other, 0, ctx, &[bytes]).unwrap();
        });
        let json = stats.json().unwrap();
        assert_eq!(json["functions"]["wasm/test.wasm#testFn"]["calls"], 2);
        assert_eq!(json["functions"]["wasm/other.wasm#testFn"]["calls"], 1);
        let table = resources();
        let stats = Collector::new();
        let mut runtime = ExternalRuntime::configured(
            None,
            ExecutionOptions {
                limits: Limits::default(),
                stats: Some(stats.clone()),
            },
        )
        .unwrap();
        heap.epoch(|ctx| {
            let handle = call(&mut runtime, &table, 0, ctx, &[Value::Int(1)]).unwrap();
            call(&mut runtime, &table, 1, ctx, &[handle, Value::Int(3)]).unwrap();
        });
        let json = stats.json().unwrap();
        assert_eq!(json["calls"], 2);
        assert_eq!(json["memory"]["total"], 2 * 65536);
        assert_eq!(json["memory"]["maximum"], 2 * 65536);
        assert_eq!(json["stateful_instances"][0]["maximum"], 2 * 65536);
        assert_eq!(json["routes"]["stateful"], 2);

        // 呼び出しごとに上限を入れ直しても、状態を持つメモリの計数は寿命全体で保つ。
        let stats = Collector::new();
        let mut runtime = ExternalRuntime::configured(
            None,
            ExecutionOptions {
                limits: Limits {
                    memory: 2 * 65536,
                    ..Limits::default()
                },
                stats: Some(stats.clone()),
            },
        )
        .unwrap();
        heap.epoch(|ctx| {
            call(&mut runtime, &table, 0, ctx, &[Value::Int(1)]).unwrap();
            let error = call(&mut runtime, &table, 0, ctx, &[Value::Int(2)]).unwrap_err();
            assert!(matches!(
                error,
                ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalMemory {
                    limit: 131072,
                    ..
                }))
            ));
        });
        let json = stats.json().unwrap();
        assert_eq!(json["calls"], 2);
        assert_eq!(json["memory"]["total"], 2 * 65536);
        assert_eq!(json["stateful_instances"][0]["maximum"], 2 * 65536);
        assert_eq!(json["reached_limits"]["memory"], 1);
        assert_eq!(
            json["functions"]["resource/x.wasm#[constructor]cell"]["reached_limits"]["memory"],
            1
        );
    }

    // 関門: 型付きの引数と戻り値それぞれの予算を、本物の持ち上げ・引き下げで守る。
    // 動的な経路のテストは Bytes を Val の大きさで数えるため、この境界を守れない。
    // spec: 03-10 実行
    #[test]
    fn typed_transfer_limits_apply_to_arguments_and_results() {
        use super::super::stats::{Collector, ExecutionOptions};
        use crate::runtime::list;
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (plan, wit, count, element) in [
                (WitPlan::Bytes, "u8", 2048, Value::Byte(0)),
                (
                    WitPlan::List(Box::new(WitPlan::U8)),
                    "u8",
                    2048,
                    Value::Byte(0),
                ),
                (
                    WitPlan::List(Box::new(WitPlan::S64)),
                    "s64",
                    256,
                    Value::Int(0),
                ),
                (
                    WitPlan::List(Box::new(WitPlan::F64)),
                    "f64",
                    256,
                    Value::Float(0.0),
                ),
            ] {
                let mut echo = table(
                    &bytes_echo(1).replace("(list u8)", &format!("(list {wit})")),
                    "f",
                    Some(plan.clone()),
                );
                set_params(&mut echo, vec![plan.clone()]);
                let returned = table(
                    &format!(
                        r#"(component (core module $m
                (memory (export "memory") 1)
                (func (export "f") (result i32)
                    i32.const 4 i32.const 16 i32.store
                    i32.const 8 i32.const {count} i32.store i32.const 4))
                (core instance $i (instantiate $m)) (type $list (list {wit}))
                (func (export "f") (result $list)
                    (canon lift (core func $i "f") (memory (core memory $i "memory")))))"#
                    ),
                    "f",
                    Some(plan.clone()),
                );
                let arg = if plan == WitPlan::Bytes {
                    ctx.alloc_bytes_with(
                        crate::runtime::heap::CheckedLen::bytes(2048, "test").unwrap(),
                        |out| out.fill(0),
                    )
                    .unwrap()
                } else {
                    list::from_values(ctx, &vec![element; count], "test").unwrap()
                };
                for (table, args) in [(&echo, vec![arg]), (&returned, vec![])] {
                    let mut runtime = ExternalRuntime::new(None).unwrap();
                    let result = call_with_fuel(
                        &mut runtime,
                        table,
                        0,
                        ctx,
                        &args,
                        Limits {
                            transfer: 1024,
                            ..Limits::default()
                        },
                    );
                    assert!(
                        matches!(
                            result,
                            Err(ExternalFailure::Stop(Stop::Resource(
                                ResourceError::ExternalTransfer { limit: 1024, .. }
                            )))
                        ),
                        "{plan:?}: {result:?}"
                    );
                    // 同じ呼び出しを境界の予算で成功させ、戻り値も正確に数える。
                    let stats = Collector::new();
                    let mut runtime = ExternalRuntime::configured(
                        None,
                        ExecutionOptions {
                            limits: Limits {
                                transfer: 2048,
                                ..Limits::default()
                            },
                            stats: Some(stats.clone()),
                        },
                    )
                    .unwrap();
                    let result = call(&mut runtime, table, 0, ctx, &args).unwrap();
                    if plan == WitPlan::Bytes {
                        assert_eq!(ctx.bytes(result).unwrap(), vec![0; count]);
                    } else {
                        assert_eq!(list::len(ctx, result).unwrap(), count as u32);
                        assert!(list::to_vec(ctx, result).unwrap().iter().all(|v| {
                            match (*v, element) {
                                (Value::Byte(a), Value::Byte(b)) => a == b,
                                (Value::Int(a), Value::Int(b)) => a == b,
                                (Value::Float(a), Value::Float(b)) => a == b,
                                _ => false,
                            }
                        }));
                    }
                    let json = stats.json().unwrap();
                    assert_eq!(
                        json["arguments_transfer"]["total"],
                        if args.is_empty() { 0 } else { 2048 }
                    );
                    assert_eq!(json["results_transfer"]["total"], 2048);
                }
            }
        });
    }

    // 関門: 型付きの call からの燃料の停止も、既存と同じ資源の不足へ分類する。
    // spec: 03-10 実行
    #[test]
    fn typed_loop_exhausts_fuel() {
        let mut table = table(
            r#"(component (core module $m
            (func (export "f") (param i64) (result i64) (loop br 0) unreachable))
            (core instance $i (instantiate $m))
            (func (export "f") (param "v" s64) (result s64) (canon lift (core func $i "f"))))"#,
            "f",
            Some(WitPlan::S64),
        );
        set_params(&mut table, vec![WitPlan::S64]);
        let mut heap = Heap::new(HeapConfig::default());
        let mut runtime = ExternalRuntime::new(None).unwrap();
        assert!(matches!(
            heap.epoch(|ctx| call_with_fuel(
                &mut runtime,
                &table,
                0,
                ctx,
                &[Value::Int(0)],
                Limits {
                    fuel: 1000,
                    ..Limits::default()
                }
            )
            .map(|_| ())),
            Err(ExternalFailure::Stop(Stop::Resource(
                ResourceError::ExternalFuel { limit: 1000, .. }
            )))
        ));
    }

    // spec: 03-10 実行
    #[test]
    fn epoch_interrupts_running_wasm_and_watcher_joins() {
        let tables = [
            table(&component("(func (export \"f\") (loop br 0))"), "f", None),
            table(
                r#"(component (core module $m
                (func (export "f") (result i64) (loop br 0) unreachable))
                (core instance $i (instantiate $m))
                (func (export "f") (result s64) (canon lift (core func $i "f"))))"#,
                "f",
                Some(WitPlan::S64),
            ),
        ];
        for table in tables {
            let flag = Arc::new(AtomicBool::new(false));
            let other = Arc::clone(&flag);
            let mut runtime = ExternalRuntime::new(Some(flag)).unwrap();
            let setter = thread::spawn(move || {
                thread::sleep(Duration::from_millis(200));
                other.store(true, Ordering::Relaxed);
            });
            let mut heap = Heap::new(HeapConfig::default());
            assert!(matches!(
                heap.epoch(|ctx| call(&mut runtime, &table, 0, ctx, &[]).map(|_| ())),
                Err(ExternalFailure::Interrupted)
            ));
            setter.join().unwrap();
            drop(runtime);
        }
    }
}

#[cfg(test)]
#[path = "runtime/adapter_tests.rs"]
mod adapter_tests;
