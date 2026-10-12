//! 安全点で止めて行う非移動のマーク・スイープ（設計書 02-09「メモリの管理」）。
//! H1・H2: 確保は要求だけを立て、解放は区間の外の collect だけが行う。
//! H4・H5: 渡された根と対象の内部参照だけを辿り、Host は Trace に委ねる。
//! H6・H9: 参照の数は持たず、Slot のヒープの番号の検査は Tracer に委ねる。
//! O1・O2・O4・O7: 親の生存対象一覧は初期化済みの頭と正しい配置を持つ。
//! 解放には一覧から得たポインタを渡し、解放後は頭も中身も読まない。
//! M1: 印付けの間は解放しない。印は回収ごとの番号で付け、頭の印が今の回収の番号と等しい対象だけを、
//! 今の回収で辿った対象とみなす。対象は印を付けたときに一度だけ積み、前の回収の印は消さない。
//! 確保した対象の印は 0、回収の番号は 1 以上なので、確保した対象は次の回収で未訪問とみなす。
//! 番号が一周するときだけ、印付けの前に全対象の印を 0 に戻す。

// 内部の層で Host の所有値と生存対象の頭を読む（設計書 02-09「メモリの管理」）。
#![allow(unsafe_code)]

use std::cell::Cell;
use std::ptr::NonNull;
use std::time::Instant;

use super::super::slot::Slot;
use super::super::stats::{HeapConfig, HeapFaultKind};
use super::super::trace::{Trace, Tracer};
use super::super::value::{Epoch, HostData, ObjKind, Value};
use super::{HeapCore, ObjHeader, TraceSink, retime};
use crate::runtime::Stop;

pub(super) struct State {
    config: HeapConfig,
    allocated_bytes: Cell<u64>,
    live_bytes: Cell<u64>,
    signal: Cell<bool>,
    requested: Cell<bool>,
    mark_epoch: Cell<u64>,
}
impl State {
    pub(super) fn new(config: HeapConfig) -> Self {
        Self {
            config,
            allocated_bytes: Cell::new(0),
            live_bytes: Cell::new(0),
            signal: Cell::new(config.stress),
            requested: Cell::new(config.stress),
            mark_epoch: Cell::new(0),
        }
    }
    pub(super) fn retain(&self, _core: &HeapCore, _value: Value<'_>) {}
    pub(super) fn release(&self, _core: &HeapCore, _value: Value<'_>) {}
    pub(super) fn allocated(&self, _core: &HeapCore, _value: Value<'_>, bytes: u64) {
        let allocated = self.allocated_bytes.get().checked_add(bytes);
        self.allocated_bytes.set(allocated.unwrap_or(u64::MAX));
        let threshold = self
            .live_bytes
            .get()
            .checked_mul(u64::from(self.config.trigger_factor_percent))
            .and_then(|scaled| scaled.checked_div(100))
            .map(|scaled| scaled.max(self.config.trigger_min_bytes));
        // 溢れたときは回収を遅らせない。
        let reached = match (allocated, threshold) {
            (Some(allocated), Some(threshold)) => allocated >= threshold,
            _ => true,
        };
        if (self.config.stress || reached) && !self.requested.replace(true) {
            self.signal.set(true);
        }
    }
    pub(super) fn cell_allocated(&self, _core: &HeapCore, _cell: Value<'_>) {}
    pub(super) fn freed(&self, _object: NonNull<ObjHeader>) {}
    pub(super) fn moved(&self, _core: &HeapCore, _value: Value<'_>) {}
    pub(super) fn collect_requested(&self) -> bool {
        self.config.stress || self.requested.get()
    }
    pub(super) fn take_collect_signal(&self) -> bool {
        self.signal.replace(false)
    }
    pub(super) fn reuse_ctor<'e>(
        &self,
        _core: &HeapCore,
        _epoch: Epoch<'e>,
        _candidate: Value<'e>,
        _tag: u32,
        _args: &[Value<'e>],
    ) -> Result<Option<Value<'e>>, Stop> {
        Ok(None)
    }
}

struct Marker<'a> {
    core: &'a HeapCore,
    epoch: u64,
    pending: Vec<Value<'a>>,
    roots_traced: u64,
    tracing_roots: bool,
    failed: bool,
}
impl<'a> Marker<'a> {
    fn mark(&mut self, value: Value<'a>) {
        if value.as_obj().is_none() {
            return;
        }
        let Some(word) = self.core.word(value) else {
            self.failed = true;
            return;
        };
        if word.get() != self.epoch {
            word.set(self.epoch);
            self.pending.push(value);
        }
    }

    fn trace_object(&mut self, value: Value<'a>) {
        match self.core.kind(value) {
            Some(ObjKind::Fields(_)) => {
                if let Some(len) = self.core.len(value) {
                    for i in 0..len {
                        if let Some(field) = self.core.field(Epoch::new(), value, i) {
                            self.mark(field);
                        }
                    }
                }
            }
            Some(ObjKind::Cell) => {
                if let Some(child) = self.core.cell_get(Epoch::new(), value) {
                    self.mark(child);
                }
            }
            Some(ObjKind::Host) => {
                if let Some((payload, _)) = self.core.payload(value, ObjKind::Host) {
                    // SAFETY: H4・H5・O2・O4・M1。生存する Host の初期化済みの Box を読み、辿る間は解放しない。
                    let host = unsafe { payload.cast::<Box<dyn HostData>>().as_ref() };
                    host.trace(&mut Tracer::new(self));
                }
            }
            Some(ObjKind::Str | ObjKind::Bytes | ObjKind::Decimal | ObjKind::Opaque) => {}
            None => self.failed = true,
        }
    }
}
impl TraceSink for Marker<'_> {
    fn core(&self) -> &HeapCore {
        self.core
    }
    fn visit(&mut self, slot: &Slot) {
        if self.tracing_roots {
            self.roots_traced = self.roots_traced.saturating_add(1);
        }
        self.mark(retime(slot.raw().0, Epoch::new()));
    }
    fn foreign_slot(&mut self) {
        if self.tracing_roots {
            self.roots_traced = self.roots_traced.saturating_add(1);
        }
        self.failed = true;
    }
}

pub(super) fn collect(core: &mut HeapCore, roots: &dyn Trace) {
    let started = Instant::now();
    // 壊れた頭で中身を辿ると範囲外を読みうるので、検証失敗では印付けに進まない。
    if let Err(fault) = core.verify(roots) {
        core.record_fault(fault.kind, &fault.detail);
        return;
    }
    let epoch = match core.mode.mark_epoch.get().checked_add(1) {
        Some(epoch) => epoch,
        None => {
            // 番号が一周すると古い印と一致するので、全対象を未訪問に戻してから始める。
            for record in core.objects.get_mut().iter() {
                // SAFETY: O1・O4・M1。一覧の初期化済みの頭を印付けと解放の前に読み、印だけを戻す。
                let head = unsafe { record.allocation.ptr.cast::<ObjHeader>().as_ref() };
                head.word.set(0);
            }
            1
        }
    };
    // Trace が panic しても番号を残し、次の回収では途中まで付けた印を未訪問とみなす。
    core.mode.mark_epoch.set(epoch);
    let mut marker = Marker {
        core,
        epoch,
        pending: Vec::new(),
        roots_traced: 0,
        tracing_roots: true,
        failed: false,
    };
    roots.trace(&mut Tracer::new(&mut marker));
    marker.tracing_roots = false;
    while let Some(value) = marker.pending.pop() {
        marker.trace_object(value);
    }
    let roots_traced = marker.roots_traced;
    let failed = marker.failed;
    drop(marker);

    let mut dead = Vec::new();
    for record in core.objects.get_mut().iter() {
        let ptr = record.allocation.ptr.cast::<ObjHeader>();
        // SAFETY: O1・O2・O4・O7・M1。一覧の初期化済みの頭を解放前に読み、元の provenance のまま解放へ渡す。
        let head = unsafe { ptr.as_ref() };
        if head.word.get() != epoch {
            dead.push(ptr);
        }
    }
    // 印は回収ごとの番号なので消さずに戻ってよい。根が欠けたままの解放は行わない。
    if failed {
        return;
    }
    for object in dead {
        if let Err(error) = core.free_object(object) {
            core.record_fault(
                HeapFaultKind::CorruptHeader,
                &format!("mark-sweep cannot free object: {error:?}"),
            );
            return;
        }
    }
    let live_bytes = core.current_bytes();
    let stats = core.stats.get_mut();
    stats.collections = stats.collections.saturating_add(1);
    stats.roots_traced = stats.roots_traced.saturating_add(roots_traced);
    stats.live_bytes = live_bytes;
    if let Err(fault) = core.verify(roots) {
        core.record_fault(fault.kind, &fault.detail);
    }
    core.mode.live_bytes.set(live_bytes);
    core.mode.allocated_bytes.set(0);
    core.mode.requested.set(false);
    core.mode.signal.set(false);
    let pause = u64::try_from(started.elapsed().as_nanos()).unwrap_or(u64::MAX);
    let record_pauses = core.config().record_pauses;
    let stats = core.stats.get_mut();
    stats.pause_total_nanos = stats.pause_total_nanos.saturating_add(pause);
    stats.pause_max_nanos = stats.pause_max_nanos.max(pause);
    if record_pauses {
        stats.pause_nanos.push(pause);
    }
}

#[cfg(test)]
mod tests {
    // 作成時の関門: 公開層の根の保存と一回の回収だけでは、回収方式の状態遷移の退行を捕まえない。
    // ここでは方式の持ち主の公開境界で、辿り漏れ・循環の残留・印の消し忘れ・
    // 閾値と信号の退行・深い値でのスタックの枯渇を確かめる。差し込み口は加えない。
    // 到達の期待値は操作と同時に記録する独立したグラフから求め、本番の Trace を使わない。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use std::collections::{BTreeMap, BTreeSet};
    use std::rc::Rc;

    use super::*;
    use crate::runtime::heap::{FieldsKind, Heap, NoGcCtx, ObjId, OpaqueData, RootIdx, RootStack};

    #[derive(Debug)]
    struct Data {
        slots: Vec<Slot>,
        drops: Rc<Cell<u32>>,
    }
    impl Trace for Data {
        fn trace(&self, t: &mut Tracer<'_>) {
            t.slots(&self.slots);
        }
    }
    impl HostData for Data {}
    impl Drop for Data {
        fn drop(&mut self) {
            // Rust の記憶域の破棄だけを観察する。言語の後始末は行わない。
            self.drops.set(self.drops.get() + 1);
        }
    }
    #[derive(Debug)]
    struct Opaque(Rc<Cell<u32>>);
    impl OpaqueData for Opaque {}
    impl Drop for Opaque {
        fn drop(&mut self) {
            self.0.set(self.0.get() + 1);
        }
    }

    // 関門: 印付けが panic で止まっても、次の回収で到達できる子を解放しない契約を守る。
    // 既存の正常終了の回収では残った印の退行を捕まえない。公開の Trace だけで止め、差し込み口は加えない。
    #[test]
    fn reachable_child_survives_collection_after_marking_panics() {
        struct PanicRoots {
            slot: Slot,
            calls: Cell<u32>,
            panic_at: Cell<Option<u32>>,
        }
        impl Trace for PanicRoots {
            fn trace(&self, t: &mut Tracer<'_>) {
                t.slot(&self.slot);
                let calls = self.calls.get() + 1;
                self.calls.set(calls);
                if self.panic_at.get() == Some(calls) {
                    panic!("stop during marking");
                }
            }
        }

        let mut heap = Heap::new(HeapConfig::default());
        let (parent, child_id) = heap.epoch(|ctx| {
            let child = ctx.alloc_str("保持する子", "test").unwrap();
            let parent = ctx.alloc_fields(FieldsKind::Ctor, 0, &[child]).unwrap();
            (ctx.new_slot(parent), ctx.object_id(child).unwrap())
        });
        let roots = PanicRoots {
            slot: parent,
            calls: Cell::new(0),
            panic_at: Cell::new(None),
        };
        // 検証器の呼び出し数を測り、その後の印付けで親を積んだ直後に止める。
        heap.verify(&roots).unwrap();
        roots.panic_at.set(Some(roots.calls.get() + 1));
        roots.calls.set(0);
        assert!(
            std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                heap.collect(&roots);
            }))
            .is_err()
        );

        roots.panic_at.set(None);
        heap.collect(&roots);
        // 解放済みの領域を読まないよう、生存と不具合の有無を中身より先に確かめる。
        assert!(
            heap.object_ids().contains(&child_id),
            "{:?}",
            heap.take_fault()
        );
        assert!(heap.take_fault().is_none());
        heap.epoch(|ctx| {
            let parent = ctx.load(&roots.slot);
            let child = ctx.field(parent, 0).unwrap();
            assert_eq!(ctx.str(child), Some("保持する子"));
        });
    }

    #[derive(Default)]
    struct Model {
        edges: BTreeMap<ObjId, Vec<ObjId>>,
        bytes: BTreeMap<ObjId, u64>,
    }
    impl Model {
        fn add(
            &mut self,
            heap: &mut Heap,
            children: &[ObjId],
            make: impl for<'e> FnOnce(&mut NoGcCtx<'e>) -> Value<'e>,
        ) -> (Slot, ObjId) {
            // 確保器の量の計数を確かめる。対象ごとの記録から生存分だけを合計する。
            let before = heap.stats().allocated_bytes;
            let (slot, id) = heap.epoch(|ctx| {
                let value = make(ctx);
                (ctx.new_slot(value), ctx.object_id(value).unwrap())
            });
            self.edges.insert(id, children.to_vec());
            self.bytes.insert(id, heap.stats().allocated_bytes - before);
            (slot, id)
        }
        fn reachable(&self, roots: &[ObjId]) -> BTreeSet<ObjId> {
            let mut found = BTreeSet::new();
            let mut pending = roots.to_vec();
            while let Some(id) = pending.pop() {
                if found.insert(id) {
                    pending.extend(&self.edges[&id]);
                }
            }
            found
        }
        fn collect_and_check(&self, heap: &mut Heap, roots: &RootStack, ids: &[ObjId]) {
            let expected = self.reachable(ids);
            let before_ids: BTreeSet<_> = heap.object_ids().into_iter().collect();
            let before = heap.stats();
            heap.collect(roots);
            let after = heap.stats();
            assert_eq!(
                heap.object_ids().into_iter().collect::<BTreeSet<_>>(),
                expected
            );
            assert_eq!(
                after.frees - before.frees,
                u64::try_from(before_ids.len() - expected.len()).unwrap()
            );
            assert_eq!(after.collections - before.collections, 1);
            assert_eq!(
                after.roots_traced - before.roots_traced,
                u64::from(roots.len())
            );
            assert_eq!(
                after.live_bytes,
                expected.iter().map(|id| self.bytes[id]).sum::<u64>()
            );
            assert!(after.pause_nanos.is_empty());
            assert!(after.pause_total_nanos >= before.pause_total_nanos);
            assert!(after.pause_max_nanos >= before.pause_max_nanos);
            assert!(after.pause_total_nanos >= after.pause_max_nanos);
            assert_eq!(heap.verify(roots), Ok(()));
            assert!(heap.take_fault().is_none());
        }
    }

    // 生の並びは測定の設定でだけ保持し、合計と最大と同じ停止時間を表す（設計書 07-02「測る項目」）。
    #[test]
    fn pause_samples_are_recorded_when_requested() {
        let mut heap = Heap::new(HeapConfig {
            record_pauses: true,
            ..HeapConfig::default()
        });
        let roots = RootStack::new();
        heap.collect(&roots);
        let stats = heap.stats();
        assert_eq!(stats.collections, 1);
        assert_eq!(stats.pause_nanos.len(), 1);
        assert_eq!(stats.pause_total_nanos, stats.pause_nanos[0]);
        assert_eq!(stats.pause_max_nanos, stats.pause_nanos[0]);
    }

    #[test]
    fn reachability_cycles_and_stats_match_independent_model() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = RootStack::new();
        let mut model = Model::default();
        let host_drops = Rc::new(Cell::new(0));
        let opaque_drops = Rc::new(Cell::new(0));
        let (shared, shared_id) =
            model.add(&mut heap, &[], |ctx| ctx.alloc_str("共有", "test").unwrap());
        let (bytes, bytes_id) = model.add(&mut heap, &[], |ctx| {
            ctx.alloc_bytes(&[0, 255, 7], "test").unwrap()
        });
        let (inner, inner_id) = model.add(&mut heap, &[shared_id, bytes_id], |ctx| {
            ctx.alloc_fields(
                FieldsKind::Ctor,
                7,
                &[ctx.load(&shared), ctx.load(&bytes), ctx.load(&shared)],
            )
            .unwrap()
        });
        let (outer, outer_id) = model.add(&mut heap, &[inner_id], |ctx| {
            ctx.alloc_fields(FieldsKind::Ctor, 8, &[ctx.load(&inner)])
                .unwrap()
        });
        let (cell, cell_id) = model.add(&mut heap, &[outer_id], |ctx| {
            ctx.alloc_cell(ctx.load(&outer))
        });
        let (host, host_id) = model.add(&mut heap, &[cell_id, shared_id], |ctx| {
            ctx.alloc_host(Data {
                slots: vec![
                    ctx.new_slot(ctx.load(&cell)),
                    ctx.new_slot(ctx.load(&shared)),
                ],
                drops: Rc::clone(&host_drops),
            })
        });
        let (cycle, cycle_id) = model.add(&mut heap, &[], |ctx| ctx.alloc_cell(Value::Unit));
        let (a, a_id) = model.add(&mut heap, &[cycle_id], |ctx| {
            ctx.alloc_fields(FieldsKind::Ctor, 1, &[ctx.load(&cycle)])
                .unwrap()
        });
        let (b, b_id) = model.add(&mut heap, &[a_id], |ctx| {
            ctx.alloc_fields(FieldsKind::Ctor, 2, &[ctx.load(&a)])
                .unwrap()
        });
        heap.epoch(|ctx| {
            ctx.cell_set(ctx.load(&cycle), ctx.load(&b)).unwrap();
            roots.push(ctx, ctx.load(&host));
            roots.push(ctx, ctx.load(&host));
            roots.push(ctx, Value::Int(42));
            roots.push(ctx, ctx.load(&cycle));
        });
        model.edges.insert(cycle_id, vec![b_id]);
        let (garbage, garbage_id) = model.add(&mut heap, &[], |ctx| {
            ctx.alloc_str("garbage", "test").unwrap()
        });
        let (garbage_host, _) = model.add(&mut heap, &[garbage_id], |ctx| {
            ctx.alloc_host(Data {
                slots: vec![ctx.new_slot(ctx.load(&garbage))],
                drops: Rc::clone(&host_drops),
            })
        });
        let (garbage_opaque, _) = model.add(&mut heap, &[], |ctx| {
            ctx.alloc_opaque(Opaque(Rc::clone(&opaque_drops)))
        });
        // 準備の保存領域も手放し、指定した RootStack だけからの到達を確かめる。
        heap.epoch(|ctx| {
            ctx.discard(vec![
                shared,
                bytes,
                inner,
                outer,
                cell,
                host,
                cycle,
                a,
                b,
                garbage,
                garbage_host,
                garbage_opaque,
            ])
        });
        model.collect_and_check(&mut heap, &roots, &[host_id, cycle_id]);
        assert_eq!(host_drops.get(), 1);
        assert_eq!(opaque_drops.get(), 1);
        // 同じ根で二度回収し、印を消し忘れて辿りを省く退行も捕まえる。
        model.collect_and_check(&mut heap, &roots, &[host_id, cycle_id]);
        heap.epoch(|ctx| {
            let host = roots.get(ctx, RootIdx(0)).unwrap();
            let data = ctx.host::<Data>(host).unwrap();
            let cell = ctx.load(&data.slots[0]);
            let outer = ctx.cell_get(cell).unwrap();
            let inner = ctx.field(outer, 0).unwrap();
            assert_eq!(ctx.fields_header(outer), Some((FieldsKind::Ctor, 8)));
            assert_eq!(ctx.fields_header(inner), Some((FieldsKind::Ctor, 7)));
            assert_eq!(ctx.str(ctx.field(inner, 0).unwrap()), Some("共有"));
            assert_eq!(
                ctx.bytes(ctx.field(inner, 1).unwrap()),
                Some([0, 255, 7].as_slice())
            );
            assert!(ctx.same_object(ctx.field(inner, 0).unwrap(), ctx.field(inner, 2).unwrap()));
            let cycle = roots.get(ctx, RootIdx(3)).unwrap();
            let b = ctx.cell_get(cycle).unwrap();
            let a = ctx.field(b, 0).unwrap();
            assert!(ctx.same_object(ctx.field(a, 0).unwrap(), cycle));
            ctx.cell_set(cell, Value::Int(17)).unwrap();
        });
        model.edges.insert(cell_id, vec![]);
        model.collect_and_check(&mut heap, &roots, &[host_id, cycle_id]);
        heap.epoch(|ctx| {
            let host = roots.get(ctx, RootIdx(0)).unwrap();
            let data = ctx.host::<Data>(host).unwrap();
            assert_eq!(ctx.str(ctx.load(&data.slots[1])), Some("共有"));
            assert_eq!(
                ctx.cell_get(ctx.load(&data.slots[0])).unwrap().as_int(),
                Some(17)
            );
            roots.truncate(ctx, 3);
        });
        model.collect_and_check(&mut heap, &roots, &[host_id]);
        heap.epoch(|ctx| roots.truncate(ctx, 0));
        model.collect_and_check(&mut heap, &roots, &[]);
        assert_eq!(host_drops.get(), 2);
        assert_eq!(opaque_drops.get(), 1);
        model.collect_and_check(&mut heap, &roots, &[]);
    }

    #[test]
    #[cfg_attr(
        not(miri),
        ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"
    )]
    fn million_linked_and_nested_fields_use_bounded_rust_stack() {
        // Miri は内部参照と回収の安全性を小さな構造で調べ、深さの検査は通常実行に残す。
        let depth = if cfg!(miri) { 64_u32 } else { 1_000_000_u32 };
        for linked in [true, false] {
            let mut heap = Heap::new(HeapConfig::default());
            let mut roots = RootStack::new();
            heap.epoch(|ctx| {
                let mut value = ctx.alloc_str("end", "test").unwrap();
                for i in 0..depth {
                    value = if linked {
                        ctx.alloc_fields(
                            FieldsKind::Ctor,
                            i + 1,
                            &[Value::Int(i64::from(i)), value],
                        )
                    } else {
                        ctx.alloc_fields(FieldsKind::Ctor, i, &[value])
                    }
                    .unwrap();
                }
                roots.push(ctx, value);
            });
            let before = heap.stats();
            heap.collect(&roots);
            assert_eq!(heap.object_ids().len(), usize::try_from(depth).unwrap() + 1);
            assert_eq!(heap.stats().frees, before.frees);
            assert_eq!(heap.stats().live_bytes, before.allocated_bytes);
            heap.epoch(|ctx| {
                let mut value = roots.get(ctx, RootIdx(0)).unwrap();
                for i in (0..depth).rev() {
                    let next = if linked {
                        assert_eq!(ctx.field(value, 0).unwrap().as_int(), Some(i64::from(i)));
                        1
                    } else {
                        0
                    };
                    value = ctx.field(value, next).unwrap();
                }
                assert_eq!(ctx.str(value), Some("end"));
                roots.truncate(ctx, 0);
            });
            heap.collect(&roots);
            assert_eq!(heap.stats().frees - before.frees, u64::from(depth) + 1);
            assert!(heap.object_ids().is_empty());
            assert!(heap.take_fault().is_none());
        }
    }

    #[derive(Debug)]
    struct OwnedBytes(Vec<u8>);
    impl OpaqueData for OwnedBytes {
        fn heap_bytes(&self) -> usize {
            self.0.capacity()
        }
    }
    impl HostData for OwnedBytes {
        fn heap_bytes(&self) -> usize {
            self.0.capacity()
        }
    }
    impl Trace for OwnedBytes {
        fn trace(&self, _t: &mut Tracer<'_>) {}
    }

    // 関門: 公開の確保・書き換えから回収要求までの契約を守る。内部層の合計だけでは
    // 回収方式への通知漏れを捕まえない。閾値を使い、A を読む差し込み口は加えない。
    #[test]
    fn discarded_opaque_owned_capacity_requests_collection() {
        if cfg!(feature = "gc-stress") {
            return;
        }
        let mut heap = Heap::new(HeapConfig {
            trigger_min_bytes: 8192,
            stress: false,
            ..HeapConfig::default()
        });
        heap.epoch(|ctx| {
            for i in 0..3 {
                assert_eq!(ctx.collect_requested(), i >= 2);
                ctx.alloc_opaque(OwnedBytes(Vec::with_capacity(4096)));
            }
            assert!(ctx.collect_requested());
        });
        heap.collect(&RootStack::new());
        assert!(heap.object_ids().is_empty());
        assert_eq!(heap.stats().live_bytes, 0);
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn host_shrinkage_does_not_reduce_allocations_since_collection() {
        if cfg!(feature = "gc-stress") {
            return;
        }
        let mut probe = Heap::new(HeapConfig::default());
        probe.epoch(|ctx| {
            ctx.alloc_host(OwnedBytes(Vec::new()));
        });
        let base = probe.stats().allocated_bytes;
        let mut heap = Heap::new(HeapConfig {
            trigger_min_bytes: base + 6144,
            stress: false,
            ..HeapConfig::default()
        });
        let added_capacity = heap.epoch(|ctx| {
            let host = ctx.alloc_host(OwnedBytes(Vec::new()));
            let mut added_capacity = 0;
            for size in [4096, 0] {
                added_capacity += ctx
                    .host_mut(host, |data: &mut OwnedBytes, _| {
                        data.0 = Vec::with_capacity(size);
                        data.0.capacity()
                    })
                    .unwrap();
                assert!(!ctx.collect_requested());
            }
            added_capacity += ctx
                .host_mut(host, |data: &mut OwnedBytes, _| {
                    data.0 = Vec::with_capacity(4096);
                    data.0.capacity()
                })
                .unwrap();
            assert!(ctx.collect_requested());
            added_capacity
        });
        assert_eq!(
            heap.stats().allocated_bytes,
            base + u64::try_from(added_capacity).unwrap()
        );
        heap.collect(&RootStack::new());
        assert_eq!(heap.stats().live_bytes, 0);
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn threshold_and_signal_follow_allocated_bytes_and_last_live_bytes() {
        // gc-stress は閾値による偽を上書きするので、その構成は専用の強制テストが持つ。
        if cfg!(feature = "gc-stress") {
            return;
        }
        // 一つの空文字列の頭・切り上げ込みの量を公開の統計で読む。
        let mut probe = Heap::new(HeapConfig::default());
        probe.epoch(|ctx| {
            ctx.alloc_str("", "test").unwrap();
        });
        let unit = probe.stats().allocated_bytes;
        for percent in [50, 100, 200] {
            let mut heap = Heap::new(HeapConfig {
                trigger_min_bytes: unit * 3,
                trigger_factor_percent: percent,
                stress: false,
                ..HeapConfig::default()
            });
            let mut roots = RootStack::new();
            assert!(!heap.collect_requested());
            heap.epoch(|ctx| {
                for i in 1..=8 {
                    roots.push(ctx, ctx.alloc_str("", "test").unwrap());
                    assert_eq!(ctx.collect_requested(), i >= 3);
                    assert_eq!(ctx.take_collect_signal(), i == 3);
                    assert!(!ctx.take_collect_signal());
                }
            });
            assert_eq!(heap.stats().frees, 0);
            assert_eq!(heap.object_ids().len(), 8);
            heap.collect(&roots);
            assert_eq!(heap.stats().live_bytes, unit * 8);
            let count = u64::from(percent) * 8 / 100;
            for _ in 0..2 {
                assert!(!heap.collect_requested());
                let before = heap.stats().allocated_bytes;
                heap.epoch(|ctx| {
                    assert!(!ctx.take_collect_signal());
                    for i in 1..=count + 1 {
                        ctx.alloc_str("", "test").unwrap();
                        assert_eq!(ctx.collect_requested(), i >= count);
                        assert_eq!(ctx.take_collect_signal(), i == count);
                        assert!(!ctx.take_collect_signal());
                    }
                });
                assert_eq!(heap.stats().allocated_bytes - before, unit * (count + 1));
                assert!(heap.collect_requested());
                let frees = heap.stats().frees;
                heap.collect(&roots);
                assert_eq!(heap.stats().frees - frees, count + 1);
                assert_eq!(heap.stats().live_bytes, unit * 8);
                heap.epoch(|ctx| assert!(!ctx.take_collect_signal()));
            }
            heap.epoch(|ctx| roots.truncate(ctx, 0));
            heap.collect(&roots);
            assert_eq!(heap.stats().live_bytes, 0);
            heap.epoch(|ctx| {
                for i in 1..=3 {
                    ctx.alloc_str("", "test").unwrap();
                    assert_eq!(ctx.collect_requested(), i == 3);
                }
            });
            assert!(heap.take_fault().is_none());
        }
    }

    #[test]
    fn stress_always_requests_and_allocation_rearms_signal() {
        let mut heap = Heap::new(HeapConfig {
            stress: true,
            ..HeapConfig::default()
        });
        let mut roots = RootStack::new();
        heap.epoch(|ctx| {
            assert!(ctx.take_collect_signal());
            assert!(!ctx.take_collect_signal());
        });
        for _ in 0..3 {
            assert!(heap.collect_requested());
            heap.epoch(|ctx| {
                assert!(ctx.collect_requested());
                assert!(!ctx.take_collect_signal());
            });
            heap.collect(&roots);
            assert!(heap.collect_requested());
            heap.epoch(|ctx| {
                assert!(ctx.collect_requested());
                assert!(!ctx.take_collect_signal());
                roots.push(ctx, ctx.alloc_str("stress", "test").unwrap());
                assert!(ctx.take_collect_signal());
                roots.push(ctx, ctx.alloc_str("stress", "test").unwrap());
                assert!(!ctx.take_collect_signal());
            });
        }
        heap.collect(&roots);
        assert_eq!(heap.object_ids().len(), 6);
        assert!(heap.take_fault().is_none());
    }
}
