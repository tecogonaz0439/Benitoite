//! ヒープの内部の層の入口（ADR 0260）。確保器、対象の頭、根の列挙、マーク・スイープの実装を子のモジュールに置く。
//! 守る不変条件: 実装プランの 10-08「不変条件」の H1〜H11。子のモジュールは、関わる項目を先頭の `//!` に挙げる。
//!
//! O1: 生きている対象の並びは初期化済みの対象だけを持ち、頭の列挙添字は並びの位置と一致する。
//!     swap_remove で移した対象の添字も更新し、除いた頭には u32::MAX を書く。
//! O2: 中身の種類・長さ・配置は確保時に一致させ、長さと種類を後から変えない。
//! O3: 中身の借用を返した後に確保しても、既存の対象の領域に書かない。
//! O4: 解放は可変借用でだけ行い、Rust の所有値を一度捨ててから領域を返す。
//! O5: heap-verify の世代の表と heap-per-object の解放用の表は領域の外にある。
//!     死んだ対象の検査は頭を読む前に行う。通常構成の読み出しは H1・H4・H5 の契約に頼る。
//! O6: 対象の中の値は同じヒープの生きている対象だけを指す。寿命の復元は区間内だけで行う。
//! 方式へ知らせる出来事: 参照の開始・終了（retain/release）、対象と量の確保（allocated）、
//! セルの確保（cell_allocated）、解放（freed）、回収（collect）、要求と新しい要求の問い合わせ
//! （collect_requested/take_collect_signal）、一意な構成子の書き換え（reuse_ctor）。
//! 参照の通知の境目は、後で書き込みの障壁を加えるために残す（ADR 0259 の決定 7）。
//! Slot の移動では元の対象の開始・終了を省き、移動先の前の参照だけを終了する。
//! O8: Host の可変参照は NoGcCtx の可変借用中の閉包だけに渡す。SlotOps は対象を借用する機能を持たない。
//! O7: 解放には、このヒープの生存中の対象から得た、確保時の provenance を持つポインタを渡す。
//!     回収方式側がこの契約を守り、Rust に返した領域は読まない。
//!     塊の解放済みの頭は塊を所有する間だけ残り、無効な添字により二度目の解放を拒む。

// 内部の層は生のポインタで対象を読み書きする（ADR 0260 の決定 1・2）。`unsafe` のブロックは操作を一つだけ含め、
// `// SAFETY:` のコメントで不変条件の番号を引く（00-02「`unsafe` の書き方」）。
#![allow(unsafe_code)]

mod alloc;
mod layout;
#[path = "core/mark_sweep.rs"]
mod mode;
#[cfg(test)]
mod probe;
#[cfg(feature = "heap-verify")]
mod verify;

#[cfg(test)]
mod tests;

use std::cell::{Cell, RefCell};
#[cfg(feature = "heap-verify")]
use std::collections::HashMap;
#[cfg(all(feature = "heap-per-object", not(feature = "heap-verify")))]
use std::collections::HashSet;
use std::ptr::NonNull;
use std::sync::atomic::{AtomicU32, Ordering};

use super::slot::{HeapNo, Slot};
use super::stats::{HeapConfig, HeapFault, HeapFaultKind, HeapStats};
use super::value::{Epoch, FieldsKind, HostData, ObjId, ObjKind, ObjRef, OpaqueData, Value};
use crate::base::Decimal;
use crate::runtime::Stop;
use alloc::{Allocation, Allocator};
use layout::{CellPayload, ObjectLayout};

// Heap::new が呼ぶ内部の初期化だけが増やす（ADR 0281、実装プラン R01「内部の層が持つもの」）。
static NEXT_HEAP_NO: AtomicU32 = AtomicU32::new(1);

/// ヒープの状態（ヒープの番号、確保器、回収の要求、測定の記録、方式ごとの状態）。区間の中で `&HeapCore` から
/// 確保するので、変わる欄は内部の可変性（`Cell` など）で持つ。欄は R01 が決める。
pub(super) struct HeapCore {
    heap_no: HeapNo,
    mode: mode::State,
    #[cfg(test)]
    notifications: probe::Events,
    config: HeapConfig,
    allocator: RefCell<Allocator>,
    objects: RefCell<Vec<ObjectRecord>>,
    #[cfg(all(feature = "heap-per-object", not(feature = "heap-verify")))]
    live_allocations: RefCell<HashSet<usize>>,
    stats: RefCell<HeapStats>,
    current_bytes: Cell<u64>,
    fault: RefCell<Option<HeapFault>>,
    #[cfg(feature = "heap-verify")]
    generations: RefCell<HashMap<usize, Life>>,
    #[cfg(feature = "heap-verify")]
    next_generation: Cell<u32>,
}

struct ObjectRecord {
    allocation: Allocation,
    charged_bytes: u64,
    #[cfg(feature = "heap-verify")]
    layout: ObjectLayout,
}

#[cfg(feature = "heap-verify")]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Life {
    generation: u32,
    alive: bool,
}

/// 対象の頭。種類、長さ、印（マーク・スイープ）、
/// `heap-verify` の構成では確保の世代を持つ。欄は R01 が決める。
#[repr(C, align(16))]
pub(super) struct ObjHeader {
    kind: ObjKind,
    len: u32,
    tag: Cell<u32>,
    index: Cell<u32>,
    word: Cell<u64>,
    #[cfg(feature = "heap-verify")]
    generation: Cell<u32>,
}

/// 両構成で頭を 32 バイトに収め、Decimal と値の並びの整列も満たす。
pub(super) const HEADER_BYTES: usize = 32;
const _: () = assert!(std::mem::size_of::<ObjHeader>() == HEADER_BYTES);

/// `Tracer` が `Slot` を知らせる相手（印付け、検証器の数え上げ）。メソッドは R01・R02 が決める。
pub(super) trait TraceSink {
    fn core(&self) -> &HeapCore;
    fn visit(&mut self, s: &Slot);
    fn foreign_slot(&mut self) {}
}

impl HeapCore {
    pub(super) fn new(mut config: HeapConfig) -> Self {
        config.stress |= cfg!(feature = "gc-stress");
        Self {
            heap_no: HeapNo(NEXT_HEAP_NO.fetch_add(1, Ordering::Relaxed)),
            config,
            mode: mode::State::new(config),
            #[cfg(test)]
            notifications: probe::Events::default(),
            allocator: RefCell::new(Allocator::new()),
            objects: RefCell::new(Vec::new()),
            #[cfg(all(feature = "heap-per-object", not(feature = "heap-verify")))]
            live_allocations: RefCell::new(HashSet::new()),
            stats: RefCell::new(HeapStats::default()),
            current_bytes: Cell::new(0),
            fault: RefCell::new(None),
            #[cfg(feature = "heap-verify")]
            generations: RefCell::new(HashMap::new()),
            #[cfg(feature = "heap-verify")]
            next_generation: Cell::new(1),
        }
    }

    pub(super) fn heap_no(&self) -> HeapNo {
        self.heap_no
    }
    pub(super) fn config(&self) -> HeapConfig {
        self.config
    }
    pub(super) fn stats(&self) -> HeapStats {
        self.stats.borrow().clone()
    }
    pub(super) fn current_bytes(&self) -> u64 {
        self.current_bytes.get()
    }

    pub(super) fn record_fault(&self, kind: HeapFaultKind, detail: &str) {
        let mut fault = self.fault.borrow_mut();
        if fault.is_none() {
            *fault = Some(HeapFault {
                kind,
                detail: detail.into(),
            });
        }
    }

    pub(super) fn take_fault(&mut self) -> Option<HeapFault> {
        self.fault.get_mut().take()
    }

    pub(super) fn object_ids(&self) -> Vec<ObjId> {
        self.objects
            .borrow()
            .iter()
            .filter_map(|record| {
                u64::try_from(record.allocation.ptr.addr().get())
                    .ok()
                    .map(ObjId)
            })
            .collect()
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn checked_object<'e>(&self, value: Value<'e>) -> Option<ObjRef<'e>> {
        let object = value.as_obj()?;
        #[cfg(feature = "heap-verify")]
        let addr = object.ptr().addr().get();
        // O5: 表を先に見るので、対象ごとの確保でも死んだ領域は読まない。
        #[cfg(feature = "heap-verify")]
        if !self
            .generations
            .borrow()
            .get(&addr)
            .is_some_and(|life| life.alive && life.generation == object.generation())
        {
            self.record_fault(
                HeapFaultKind::StaleReference,
                "object is dead or its allocation generation differs",
            );
            return None;
        }
        Some(object)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn header<'a>(&'a self, value: Value<'_>) -> Option<&'a ObjHeader> {
        let object = self.checked_object(value)?;
        // SAFETY: H1・H4・H5・O2・O4。区間内の対象は生存し、共有借用中に解放しない。検証構成では O5 も確認済み。
        Some(unsafe { object.ptr().as_ref() })
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn kind(&self, value: Value<'_>) -> Option<ObjKind> {
        self.header(value).map(|head| head.kind)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn object_id(&self, value: Value<'_>) -> Option<ObjId> {
        let object = self.checked_object(value)?;
        u64::try_from(object.ptr().addr().get()).ok().map(ObjId)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn same_object(&self, a: Value<'_>, b: Value<'_>) -> bool {
        match (self.object_id(a), self.object_id(b)) {
            (Some(a), Some(b)) => a == b,
            (Some(_), None) | (None, Some(_)) | (None, None) => false,
        }
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn fields_header(&self, value: Value<'_>) -> Option<(FieldsKind, u32)> {
        let head = self.header(value)?;
        if let ObjKind::Fields(kind) = head.kind {
            Some((kind, head.tag.get()))
        } else {
            None
        }
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn len(&self, value: Value<'_>) -> Option<u32> {
        self.header(value).map(|head| head.len)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn tag(&self, value: Value<'_>) -> Option<u32> {
        self.header(value).map(|head| head.tag.get())
    }

    /// 回収方式の印を頭の内部の可変性だけで扱う。書き込みの障壁は方式の境目に加える（ADR 0259 の決定 7）。
    pub(super) fn word(&self, value: Value<'_>) -> Option<&Cell<u64>> {
        self.header(value).map(|head| &head.word)
    }

    fn allocate<'e>(
        &'e self,
        epoch: Epoch<'e>,
        layout: ObjectLayout,
        external: usize,
        initialize: impl FnOnce(NonNull<u8>),
    ) -> Result<Value<'e>, Stop> {
        let capacity = Allocator::capacity(layout.layout)?;
        let charged = capacity
            .checked_add(external)
            .and_then(|n| u64::try_from(n).ok())
            .ok_or_else(size_overflow)?;
        let current = self
            .current_bytes
            .get()
            .checked_add(charged)
            .ok_or_else(size_overflow)?;
        let mut stats = self.stats.borrow_mut();
        let allocations = stats.allocations.checked_add(1).ok_or_else(size_overflow)?;
        let allocated_bytes = stats
            .allocated_bytes
            .checked_add(charged)
            .ok_or_else(size_overflow)?;
        #[cfg(feature = "heap-verify")]
        let generation = {
            let generation = self.next_generation.get();
            self.next_generation
                .set(generation.checked_add(1).ok_or_else(size_overflow)?);
            generation
        };
        let mut objects = self.objects.borrow_mut();
        let index = u32::try_from(objects.len())
            .ok()
            .filter(|index| *index != u32::MAX)
            .ok_or_else(size_overflow)?;
        let allocation = self.allocator.borrow_mut().allocate(layout.layout)?;
        let ptr = allocation.ptr.cast::<ObjHeader>();
        let header = ObjHeader {
            kind: layout.kind,
            len: layout.len,
            tag: Cell::new(layout.tag),
            index: Cell::new(index),
            word: Cell::new(0),
            #[cfg(feature = "heap-verify")]
            generation: Cell::new(generation),
        };
        // SAFETY: O1・O2。確保した領域は頭の大きさと整列を満たし、まだ参照を公開していない。
        unsafe { ptr.as_ptr().write(header) };
        let payload = layout.payload(allocation.ptr);
        initialize(payload);
        #[cfg(any(feature = "heap-verify", feature = "heap-per-object"))]
        let addr = ptr.addr().get();
        objects.push(ObjectRecord {
            allocation,
            charged_bytes: charged,
            #[cfg(feature = "heap-verify")]
            layout,
        });
        #[cfg(all(feature = "heap-per-object", not(feature = "heap-verify")))]
        self.live_allocations.borrow_mut().insert(addr);
        #[cfg(feature = "heap-verify")]
        self.generations.borrow_mut().insert(
            addr,
            Life {
                generation,
                alive: true,
            },
        );
        stats.allocations = allocations;
        stats.allocated_bytes = allocated_bytes;
        stats.peak_heap_bytes = stats.peak_heap_bytes.max(current);
        self.current_bytes.set(current);
        drop(objects);
        drop(stats);
        let value = Value::Obj(make_ref(
            ptr,
            epoch,
            #[cfg(feature = "heap-verify")]
            generation,
        ));
        self.mode.allocated(self, value, charged);
        Ok(value)
    }

    pub(super) fn alloc_str<'e>(&'e self, epoch: Epoch<'e>, text: &str) -> Result<Value<'e>, Stop> {
        self.alloc_byte_data(epoch, ObjKind::Str, text.as_bytes())
    }
    pub(super) fn alloc_str_parts<'e>(
        &'e self,
        epoch: Epoch<'e>,
        len: u32,
        parts: &[&str],
    ) -> Result<Value<'e>, Stop> {
        let layout = ObjectLayout::new(ObjKind::Str, len, 0)?;
        let size = usize::try_from(len).map_err(|_| size_overflow())?;
        // 公開層の計算と一致することを確保前に確かめ、未初期化の部分を公開しない（O2）。
        let total = parts
            .iter()
            .try_fold(0_usize, |sum, s| sum.checked_add(s.len()));
        if total != Some(size) {
            return Err(Stop::Internal("string parts length mismatch".into()));
        }
        self.allocate(epoch, layout, 0, |payload| {
            let mut dst = payload.as_ptr();
            for part in parts {
                // SAFETY: O2・O3。合計は size と等しく、各部分は確保済みの未公開領域に収まる。入力と重ならない。
                unsafe { std::ptr::copy_nonoverlapping(part.as_ptr(), dst, part.len()) };
                // SAFETY: O2。写した部分の直後は確保した領域の中か終端であり、次の部分も合計長の中に収まる。
                dst = unsafe { dst.add(part.len()) };
            }
        })
    }
    pub(super) fn alloc_bytes_with<'e>(
        &'e self,
        epoch: Epoch<'e>,
        len: u32,
        fill: impl FnOnce(&mut [u8]),
    ) -> Result<Value<'e>, Stop> {
        let layout = ObjectLayout::new(ObjKind::Bytes, len, 0)?;
        let size = usize::try_from(len).map_err(|_| size_overflow())?;
        let value = self.allocate(epoch, layout, 0, |payload| {
            // SAFETY: O2・O3。未公開の size バイトの領域をすべて初期化してから、安全なスライスを渡す。
            unsafe { std::ptr::write_bytes(payload.as_ptr(), 0, size) };
        })?;
        let (payload, _) = self
            .payload(value, ObjKind::Bytes)
            .ok_or_else(|| Stop::Internal("new bytes object has no payload".into()))?;
        // fill は別の値を確保してよい。確保器・対象の表・統計の借用が終わってから呼ぶ（H1・O3）。
        // SAFETY: O2・O3。初期化済みの領域で、value はまだ呼び出し側へ返しておらず、別名の参照はない。
        let bytes = unsafe { std::slice::from_raw_parts_mut(payload.as_ptr(), size) };
        fill(bytes);
        Ok(value)
    }
    pub(super) fn alloc_bytes<'e>(
        &'e self,
        epoch: Epoch<'e>,
        bytes: &[u8],
    ) -> Result<Value<'e>, Stop> {
        self.alloc_byte_data(epoch, ObjKind::Bytes, bytes)
    }
    fn alloc_byte_data<'e>(
        &'e self,
        epoch: Epoch<'e>,
        kind: ObjKind,
        bytes: &[u8],
    ) -> Result<Value<'e>, Stop> {
        let len = u32::try_from(bytes.len()).map_err(|_| size_overflow())?;
        let layout = ObjectLayout::new(kind, len, 0)?;
        self.allocate(epoch, layout, 0, |payload| {
            // SAFETY: O2・O3。中身は bytes.len() バイト確保済みで、入力と新しい対象は重ならない。
            unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), payload.as_ptr(), bytes.len()) };
        })
    }
    pub(super) fn alloc_fields<'e>(
        &'e self,
        epoch: Epoch<'e>,
        kind: FieldsKind,
        tag: u32,
        items: &[Value<'e>],
    ) -> Result<Value<'e>, Stop> {
        for value in items {
            if value.as_obj().is_some() && self.checked_object(*value).is_none() {
                return Err(Stop::Internal("field refers to an invalid object".into()));
            }
        }
        let len = u32::try_from(items.len()).map_err(|_| size_overflow())?;
        let layout = ObjectLayout::new(ObjKind::Fields(kind), len, tag)?;
        self.allocate(epoch, layout, 0, |payload| {
            for (i, value) in items.iter().enumerate() {
                let ptr = payload.cast::<Value<'static>>();
                // SAFETY: O2。i は items.len() 未満で、同じ長さの値の領域を確保した。
                let ptr = unsafe { ptr.as_ptr().add(i) };
                // SAFETY: O2・O6。未公開の整列済みの場所へ、このヒープの検査済みの値を書き込む。
                unsafe { ptr.write(retime(*value, Epoch::new())) };
            }
        })
    }
    pub(super) fn alloc_decimal<'e>(
        &'e self,
        epoch: Epoch<'e>,
        value: Decimal,
    ) -> Result<Value<'e>, Stop> {
        let layout = ObjectLayout::new(ObjKind::Decimal, 1, 0)?;
        self.allocate(epoch, layout, 0, |payload| {
            // SAFETY: O2・O3。Decimal の大きさと整列を満たす未公開の領域である。
            unsafe { payload.cast::<Decimal>().as_ptr().write(value) };
        })
    }
    pub(super) fn alloc_cell<'e>(
        &'e self,
        epoch: Epoch<'e>,
        value: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        if value.as_obj().is_some() && self.checked_object(value).is_none() {
            return Err(Stop::Internal("cell refers to an invalid object".into()));
        }
        let layout = ObjectLayout::new(ObjKind::Cell, 1, 0)?;
        let cell = self.allocate(epoch, layout, 0, |payload| {
            let body = CellPayload {
                value: Cell::new(retime(value, Epoch::new())),
                version: Cell::new(0),
            };
            // SAFETY: O2・O3・O6。CellPayload 用の未公開の領域へ検査済みの値を置く。
            unsafe { payload.cast::<CellPayload>().as_ptr().write(body) };
        })?;
        self.mode.cell_allocated(self, cell);
        Ok(cell)
    }
    pub(super) fn alloc_opaque<'e, T: OpaqueData>(
        &'e self,
        epoch: Epoch<'e>,
        data: T,
    ) -> Result<Value<'e>, Stop> {
        // T が所有する Vec などの別領域の容量は数えていない。凍結した OpaqueData に容量を返す口がないため、
        // 現時点では Box 内の size_of::<T>() だけを加える（10-08「設定と測定の記録」、ADR 0259 決定 6 の未対応部分）。
        let layout = ObjectLayout::new(ObjKind::Opaque, 1, 0)?;
        self.allocate(epoch, layout, std::mem::size_of::<T>(), |payload| {
            let data: Box<dyn OpaqueData> = Box::new(data);
            // SAFETY: O2・O3・O4。Box 用の未公開の領域へ所有権を移し、free_object だけが捨てる。
            unsafe { payload.cast::<Box<dyn OpaqueData>>().as_ptr().write(data) };
        })
    }
    pub(super) fn alloc_host<'e, T: HostData>(
        &'e self,
        epoch: Epoch<'e>,
        data: T,
    ) -> Result<Value<'e>, Stop> {
        // T が所有する Vec などの別領域の容量は数えていない。凍結した HostData に容量を返す口がないため、
        // 現時点では Box 内の size_of::<T>() だけを加える（10-08「設定と測定の記録」、ADR 0259 決定 6 の未対応部分）。
        let layout = ObjectLayout::new(ObjKind::Host, 1, 0)?;
        self.allocate(epoch, layout, std::mem::size_of::<T>(), |payload| {
            let data: Box<dyn HostData> = Box::new(data);
            // SAFETY: O2・O3・O4。Box 用の未公開の領域へ所有権を移し、free_object だけが捨てる。
            unsafe { payload.cast::<Box<dyn HostData>>().as_ptr().write(data) };
        })
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn payload(&self, value: Value<'_>, kind: ObjKind) -> Option<(NonNull<u8>, u32)> {
        let object = self.checked_object(value)?;
        // SAFETY: H1・H4・H5・O2・O4。生存する対象の頭は初期化済み。検証構成では O5 も確認済み。
        let head = unsafe { object.ptr().as_ref() };
        if head.kind != kind {
            return None;
        }
        let layout = ObjectLayout::new(head.kind, head.len, head.tag.get()).ok()?;
        Some((layout.payload(object.ptr().cast()), head.len))
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn bytes(&self, value: Value<'_>) -> Option<&[u8]> {
        let (ptr, len) = self.payload(value, ObjKind::Bytes)?;
        let len = usize::try_from(len).ok()?;
        // SAFETY: H1・O2・O3・O4。初期化済みのバイト領域と同じ長さで、共有借用中には変えず解放しない。
        Some(unsafe { std::slice::from_raw_parts(ptr.as_ptr(), len) })
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn str(&self, value: Value<'_>) -> Option<&str> {
        let (ptr, len) = self.payload(value, ObjKind::Str)?;
        let len = usize::try_from(len).ok()?;
        // SAFETY: H1・O2・O3・O4。文字列の領域は同じ長さで初期化され、共有借用中には変えず解放しない。
        let bytes = unsafe { std::slice::from_raw_parts(ptr.as_ptr(), len) };
        std::str::from_utf8(bytes).ok()
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn field<'e>(
        &'e self,
        epoch: Epoch<'e>,
        value: Value<'e>,
        i: u32,
    ) -> Option<Value<'e>> {
        let kind = self.kind(value)?;
        if !matches!(kind, ObjKind::Fields(_)) {
            return None;
        }
        let (ptr, len) = self.payload(value, kind)?;
        if i >= len {
            return None;
        }
        let i = usize::try_from(i).ok()?;
        // SAFETY: O2。i < len を確かめた値の領域である。
        let ptr = unsafe { ptr.cast::<Value<'static>>().as_ptr().add(i) };
        // SAFETY: H1・O1・O2・O6。初期化済みの値を写し、この区間の寿命に戻す。
        let raw = unsafe { ptr.read() };
        Some(retime(raw, epoch))
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn decimal(&self, value: Value<'_>) -> Option<Decimal> {
        let (ptr, _) = self.payload(value, ObjKind::Decimal)?;
        // SAFETY: H1・O2。Decimal の配置で初期化された対象の中身を写す。
        Some(unsafe { ptr.cast::<Decimal>().as_ptr().read() })
    }
    pub(super) fn cell(&self, value: Value<'_>) -> Option<&CellPayload> {
        let (ptr, _) = self.payload(value, ObjKind::Cell)?;
        // SAFETY: H1・O2・O4。CellPayload の配置で初期化され、共有借用中に解放しない。
        Some(unsafe { ptr.cast::<CellPayload>().as_ref() })
    }
    pub(super) fn opaque<T: OpaqueData>(&self, value: Value<'_>) -> Option<&T> {
        let (ptr, _) = self.payload(value, ObjKind::Opaque)?;
        // SAFETY: H1・O2・O4。初期化済みの Box は共有借用中に捨てず書き換えない。
        let data = unsafe { ptr.cast::<Box<dyn OpaqueData>>().as_ref() };
        let any: &dyn std::any::Any = data.as_ref();
        any.downcast_ref()
    }
    pub(super) fn host<T: HostData>(&self, value: Value<'_>) -> Option<&T> {
        let (ptr, _) = self.payload(value, ObjKind::Host)?;
        // SAFETY: H1・H7・O2・O4。初期化済みの Box は共有借用中に捨てず、書き換えは公開層の可変借用に限る。
        let data = unsafe { ptr.cast::<Box<dyn HostData>>().as_ref() };
        let any: &dyn std::any::Any = data.as_ref();
        any.downcast_ref()
    }

    /// 安全点からだけ呼ぶ。object はこのヒープの生きている対象から得る（O7）。
    /// Host の Slot と対象内の値の参照の終了は、方式側が先に扱う（H6）。
    pub(super) fn free_object(&mut self, object: NonNull<ObjHeader>) -> Result<(), Stop> {
        #[cfg(any(feature = "heap-verify", feature = "heap-per-object"))]
        let addr = object.addr().get();
        if self.objects.get_mut().is_empty() {
            return Err(Stop::Internal("cannot free a non-live object".into()));
        }
        // O5: 頭より先に領域の外の生死を見るので、対象ごとの確保でも返却済みの領域を読まない。
        #[cfg(feature = "heap-verify")]
        if !self
            .generations
            .get_mut()
            .get(&addr)
            .is_some_and(|life| life.alive)
        {
            return Err(Stop::Internal("cannot free a non-live object".into()));
        }
        #[cfg(all(feature = "heap-per-object", not(feature = "heap-verify")))]
        if !self.live_allocations.get_mut().contains(&addr) {
            return Err(Stop::Internal("cannot free a non-live object".into()));
        }
        // SAFETY: O2・O4・O7。方式側が渡した頭は、この確保器が初期化した領域を元の provenance で指す。
        // 検証構成と対象ごとの確保では O5 も確認済み。塊の解放済みの頭は所有する塊の中に残る。
        let head = unsafe { object.as_ref() };
        let index = usize::try_from(head.index.get()).map_err(|_| size_overflow())?;
        let objects = self.objects.get_mut();
        let record = objects
            .get(index)
            .filter(|record| record.allocation.ptr.cast::<ObjHeader>() == object)
            .ok_or_else(|| Stop::Internal("cannot free a non-live object".into()))?;
        let layout = ObjectLayout::new(head.kind, head.len, head.tag.get())?;
        let current = self
            .current_bytes
            .get()
            .checked_sub(record.charged_bytes)
            .ok_or_else(size_overflow)?;
        let frees = self
            .stats
            .get_mut()
            .frees
            .checked_add(1)
            .ok_or_else(size_overflow)?;
        #[cfg(feature = "heap-verify")]
        let next_generation = {
            let life = self
                .generations
                .get_mut()
                .get(&addr)
                .ok_or_else(size_overflow)?;
            life.generation.checked_add(1).ok_or_else(size_overflow)?
        };
        // O1・O4: 移した対象の添字を更新する。Rust の drop が panic しても、除いた対象は二度捨てない。
        let record = objects.swap_remove(index);
        if let Some(moved) = objects.get(index) {
            // SAFETY: O1・O2・O4。並びに残る初期化済みの頭。安全点の可変借用中に添字だけを更新する。
            let head = unsafe { moved.allocation.ptr.cast::<ObjHeader>().as_ref() };
            head.index
                .set(u32::try_from(index).map_err(|_| size_overflow())?);
        }
        head.index.set(u32::MAX);
        #[cfg(all(feature = "heap-per-object", not(feature = "heap-verify")))]
        self.live_allocations.get_mut().remove(&addr);
        // O4・O5: Rust の drop が panic しても、この対象を検証済みの生存対象として読み直さない。
        #[cfg(feature = "heap-verify")]
        self.generations.get_mut().insert(
            addr,
            Life {
                generation: next_generation,
                alive: false,
            },
        );
        let payload = layout.payload(record.allocation.ptr);
        match layout.kind {
            ObjKind::Opaque => {
                // SAFETY: O2・O4。所有する Box はまだ捨てておらず、この可変借用中に一度だけ捨てる。
                unsafe {
                    payload
                        .cast::<Box<dyn OpaqueData>>()
                        .as_ptr()
                        .drop_in_place()
                };
            }
            ObjKind::Host => {
                // SAFETY: O2・O4。方式側が Slot の数を処理済みの所有する Box を一度だけ捨てる。
                unsafe { payload.cast::<Box<dyn HostData>>().as_ptr().drop_in_place() };
            }
            ObjKind::Str
            | ObjKind::Bytes
            | ObjKind::Decimal
            | ObjKind::Fields(_)
            | ObjKind::Cell => {}
        }
        #[cfg(feature = "heap-verify")]
        {
            // H2・O2・O4: まだ確保器へ返していない頭の世代を進める。
            head.generation.set(next_generation);
            let payload_capacity = record
                .allocation
                .capacity
                .checked_sub(layout.offset)
                .ok_or_else(size_overflow)?;
            // SAFETY: H2・O2・O4。中身を捨てた後、確保器へ返す前の中身と切り上げの範囲だけを埋める。
            unsafe {
                payload
                    .as_ptr()
                    .write_bytes(super::POISON_BYTE, payload_capacity)
            };
        }
        self.mode.freed(object);
        self.allocator.get_mut().release(record.allocation);
        self.stats.get_mut().frees = frees;
        self.current_bytes.set(current);
        Ok(())
    }
}

impl Drop for HeapCore {
    fn drop(&mut self) {
        // 対象を辿る再帰はせず、すべての Rust の所有値を一度ずつ捨てる（設計書 02-09「メモリの管理」）。
        while let Some(record) = self.objects.get_mut().last() {
            let object = record.allocation.ptr.cast::<ObjHeader>();
            if self.free_object(object).is_err() {
                break;
            }
        }
    }
}

fn size_overflow() -> Stop {
    Stop::Internal("heap allocation size or accounting overflow".into())
}

fn make_ref<'e>(
    ptr: NonNull<ObjHeader>,
    _epoch: Epoch<'e>,
    #[cfg(feature = "heap-verify")] generation: u32,
) -> ObjRef<'e> {
    ObjRef::from_raw(
        ptr,
        #[cfg(feature = "heap-verify")]
        generation,
    )
}

/// 生の値と区間内の値は同じ表現である。参照を作らず、対象のポインタに区間の印を付け直すだけである（O6）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn retime<'a, 'e>(value: Value<'a>, epoch: Epoch<'e>) -> Value<'e> {
    retime_checked(value, epoch, |_| true)
}

// 寿命の付け直しと対象の検査を同じ分岐で行い、即値の経路に検査を展開しない（H9、O6）。
#[cfg_attr(debug_assertions, inline)]
#[cfg_attr(not(debug_assertions), inline(always))]
fn retime_checked<'a, 'e>(
    value: Value<'a>,
    epoch: Epoch<'e>,
    check: impl FnOnce(ObjRef<'a>) -> bool,
) -> Value<'e> {
    match value {
        Value::Int(n) => Value::Int(n),
        Value::Float(n) => Value::Float(n),
        Value::Byte(n) => Value::Byte(n),
        Value::Bool(n) => Value::Bool(n),
        Value::Char(n) => Value::Char(n),
        Value::Unit => Value::Unit,
        Value::Tag(n) => Value::Tag(n),
        Value::Resource(n) => Value::Resource(n),
        Value::EmptyList => Value::EmptyList,
        Value::EmptyMap => Value::EmptyMap,
        Value::EmptySet => Value::EmptySet,
        Value::Obj(r) => {
            if !check(r) {
                return Value::Unit;
            }
            Value::Obj(make_ref(
                r.ptr(),
                epoch,
                #[cfg(feature = "heap-verify")]
                r.generation(),
            ))
        }
    }
}

use super::trace::Trace;

impl HeapCore {
    /// 対象を読むより先に番号だけを比較する（H9）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn check_slot_heap(&self, slot: &Slot) -> bool {
        let (_, heap) = slot.raw();
        self.check_heap_no(heap)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn check_heap_no(&self, heap: Option<HeapNo>) -> bool {
        if heap.is_some_and(|heap| heap != self.heap_no) {
            self.record_fault(HeapFaultKind::ForeignHeap, "slot belongs to another heap");
            return false;
        }
        true
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_load<'e>(&self, slot: &Slot, epoch: Epoch<'e>) -> Value<'e> {
        let (value, heap) = slot.raw();
        retime_checked(value, epoch, |_object| {
            let valid = self.check_heap_no(heap);
            #[cfg(feature = "heap-verify")]
            let valid = valid && self.checked_object(Value::Obj(_object)).is_some();
            valid
        })
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn retain(&self, value: Value<'_>) {
        if value.as_obj().is_some() {
            #[cfg(test)]
            self.notifications
                .retained
                .set(self.notifications.retained.get().saturating_add(1));
            self.mode.retain(self, value);
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn release(&self, value: Value<'_>) {
        if value.as_obj().is_some() {
            #[cfg(test)]
            self.notifications
                .released
                .set(self.notifications.released.get().saturating_add(1));
            self.mode.release(self, value);
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_new_slot(&self, value: Value<'_>) -> Slot {
        let mut slot = Slot::default();
        // 新しい場所には前の参照がない。開始の通知だけを行う（H6）。
        self.retain(value);
        slot.set_raw(retime(value, Epoch::new()), self.heap_no);
        slot
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_store(&self, dst: &mut Slot, value: Value<'_>) {
        // 先に新しい参照の開始を知らせてから前の参照の終了を知らせ、同じ対象への書き込みでも参照を途切れさせない（H6）。
        self.retain(value);
        self.slot_release(dst);
        dst.set_raw(retime(value, Epoch::new()), self.heap_no);
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_release(&self, slot: &Slot) {
        if slot.is_immediate() {
            return;
        }
        let (value, heap) = slot.raw();
        if self.check_heap_no(heap) {
            self.release(value);
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_clear(&self, dst: &mut Slot) {
        self.slot_release(dst);
        dst.set_raw(Value::Unit, self.heap_no);
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_move_slot(&self, dst: &mut Slot, src: &mut Slot) {
        self.slot_release(dst);
        let (value, heap) = src.raw();
        let value = if self.check_heap_no(heap) {
            value
        } else {
            Value::Unit
        };
        dst.set_raw(value, self.heap_no);
        src.set_raw(Value::Unit, self.heap_no);
        // 値の移動は参照の開始・終了を通知しない（H6）。
        self.mode.moved(self, value);
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn slot_take<'e>(&self, src: &mut Slot, epoch: Epoch<'e>) -> Value<'e> {
        // 読み出しと消去の両方に同じ比較の結果を使い、番号を二度比べない（H9、ADR 0281）。
        let value = self.slot_load(src, epoch);
        self.release(value);
        src.set_raw(Value::Unit, self.heap_no);
        value
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn collect_requested(&self) -> bool {
        self.mode.collect_requested()
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn take_collect_signal(&self) -> bool {
        self.mode.take_collect_signal()
    }
    pub(super) fn collect(&mut self, roots: &dyn Trace) {
        mode::collect(self, roots);
    }

    pub(super) fn new_cell<'e>(&'e self, epoch: Epoch<'e>, value: Value<'e>) -> Value<'e> {
        self.infallible_allocation(self.alloc_cell(epoch, value))
    }
    pub(super) fn new_host<'e, T: HostData>(&'e self, epoch: Epoch<'e>, data: T) -> Value<'e> {
        self.infallible_allocation(self.alloc_host(epoch, data))
    }
    pub(super) fn new_opaque<'e, T: OpaqueData>(&'e self, epoch: Epoch<'e>, data: T) -> Value<'e> {
        // 結果型に Stop がない確保は、セルと Host と同じく不具合を安全点で報告する（10-08「ヒープと区間」）。
        self.infallible_allocation(self.alloc_opaque(epoch, data))
    }
    pub(super) fn new_decimal<'e>(&'e self, epoch: Epoch<'e>, d: Decimal) -> Value<'e> {
        // Stop を返さない公開の確保も、失敗は安全点で報告する（10-08「ヒープと区間」）。
        self.infallible_allocation(self.alloc_decimal(epoch, d))
    }
    fn infallible_allocation<'e>(&self, value: Result<Value<'e>, Stop>) -> Value<'e> {
        match value {
            Ok(value) => value,
            Err(error) => {
                self.record_fault(
                    HeapFaultKind::CorruptHeader,
                    &format!("cannot allocate heap object: {error:?}"),
                );
                Value::Unit
            }
        }
    }
    pub(super) fn cell_get<'e>(&self, epoch: Epoch<'e>, cell: Value<'e>) -> Option<Value<'e>> {
        let value = self.cell(cell)?.value.get();
        if value.as_obj().is_some() && self.checked_object(value).is_none() {
            return None;
        }
        Some(retime(value, epoch))
    }
    pub(super) fn cell_set(&self, cell: Value<'_>, value: Value<'_>) -> Result<(), Stop> {
        let body = self
            .cell(cell)
            .ok_or_else(|| Stop::Internal("value is not a cell".into()))?;
        let version = body
            .version
            .get()
            .checked_add(1)
            .ok_or_else(|| Stop::Internal("cell version overflow".into()))?;
        self.retain(value);
        self.release(body.value.get());
        // 書き込みの障壁を置く唯一の箇所（H7、設計書 02-09「メモリの管理」）。
        body.value.set(retime(value, Epoch::new()));
        body.version.set(version);
        Ok(())
    }

    /// 呼び出す公開層は NoGcCtx を可変借用し、閉包に SlotOps だけを渡す（O8）。
    pub(super) fn with_host_mut<T: HostData, R>(
        &self,
        value: Value<'_>,
        f: impl FnOnce(&mut T) -> R,
    ) -> Option<R> {
        let (ptr, _) = self.payload(value, ObjKind::Host)?;
        // SAFETY: H1・H7・O2・O4・O8。初期化済みの Box は生存し、NoGcCtx の可変借用が別名の借用を防ぐ。
        let data = unsafe { &mut *ptr.cast::<Box<dyn HostData>>().as_ptr() };
        let any: &mut dyn std::any::Any = data.as_mut();
        // Host の書き込みの障壁は、この可変借用を渡す一か所に置く（H7）。
        Some(f(any.downcast_mut()?))
    }

    pub(super) fn reuse_ctor<'e>(
        &self,
        epoch: Epoch<'e>,
        candidate: Value<'e>,
        tag: u32,
        args: &[Value<'e>],
    ) -> Result<Option<Value<'e>>, Stop> {
        // 種類と長さの契約は、回収方式と再利用の設定によらない（10-08「その場での再利用」）。
        if !matches!(
            self.kind(candidate),
            Some(ObjKind::Fields(FieldsKind::Ctor))
        ) || self
            .len(candidate)
            .and_then(|len| usize::try_from(len).ok())
            != Some(args.len())
        {
            return Err(Stop::Internal(
                "reuse candidate is not a constructor of the required length".into(),
            ));
        }
        self.mode.reuse_ctor(self, epoch, candidate, tag, args)
    }

    pub(super) fn verify(&self, roots: &dyn Trace) -> Result<(), HeapFault> {
        #[cfg(not(feature = "heap-verify"))]
        {
            let _ = roots;
            Ok(())
        }
        #[cfg(feature = "heap-verify")]
        {
            self.verify_live_objects(roots)
        }
    }

    #[cfg(test)]
    pub(super) fn notification_counts(&self) -> (u64, u64) {
        (
            self.notifications.retained.get(),
            self.notifications.released.get(),
        )
    }
}

#[cfg(all(test, feature = "heap-verify"))]
mod region_verifier_tests {
    // 内部層の入口で、頭を壊す操作だけを直接行う（R02 の個別の指示、ADR 0309）。
    // 作成時の関門: R01 は検証器を持たず、公開層の正常な操作では壊れた頭を作れない。
    // 中身を読む前に頭の範囲の食い違いを拒む独立した契約を守る。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::super::trace::Tracer;
    use super::*;

    #[test]
    fn verifier_checks_headers_before_traversing_payloads() {
        let core = HeapCore::new(HeapConfig::default());
        let value = core.alloc_cell(Epoch::new(), Value::Int(3)).unwrap();
        let roots = core.slot_new_slot(value);
        assert_eq!(core.verify(&roots), Ok(()));
        let mut ptr = value.as_obj().unwrap().ptr();
        // SAFETY: O1・O2・O4。テストが所有する生存中の頭で、頭への参照は残していない。
        unsafe { ptr.as_mut() }.len = u32::MAX;
        assert_eq!(
            core.verify(&roots).unwrap_err().kind,
            HeapFaultKind::CorruptHeader
        );
        // SAFETY: O1・O2・O4。同じ生存中の頭を確保時の長さに戻し、Drop が正しい配置で処理できるようにする。
        unsafe { ptr.as_mut() }.len = 1;
        assert_eq!(core.verify(&roots), Ok(()));
    }

    #[test]
    fn verifier_checks_references_in_fields_cells_hosts_and_roots() {
        // 並び・セルの内部参照と Host の Slot に対する各経路の漏れを一つの表で検査する。
        for kind in [
            ObjKind::Fields(FieldsKind::Ctor),
            ObjKind::Cell,
            ObjKind::Host,
        ] {
            let mut core = HeapCore::new(HeapConfig::default());
            let child = core.alloc_str(Epoch::new(), "child").unwrap();
            let child_ptr = child.as_obj().unwrap().ptr();
            #[derive(Debug)]
            struct Data(Slot);
            impl Trace for Data {
                fn trace(&self, t: &mut Tracer<'_>) {
                    t.slot(&self.0);
                }
            }
            impl HostData for Data {}
            let parent = match kind {
                ObjKind::Fields(fields) => core
                    .alloc_fields(Epoch::new(), fields, 0, &[child])
                    .unwrap(),
                ObjKind::Cell => core.alloc_cell(Epoch::new(), child).unwrap(),
                ObjKind::Host => core
                    .alloc_host(Epoch::new(), Data(core.slot_new_slot(child)))
                    .unwrap(),
                ObjKind::Str | ObjKind::Bytes | ObjKind::Decimal | ObjKind::Opaque => {
                    unreachable!()
                }
            };
            let roots = core.slot_new_slot(parent);
            assert_eq!(core.verify(&roots), Ok(()));
            core.free_object(child_ptr).unwrap();
            assert_eq!(
                core.verify(&roots).unwrap_err().kind,
                HeapFaultKind::ReachableFreed
            );
        }
    }
}
