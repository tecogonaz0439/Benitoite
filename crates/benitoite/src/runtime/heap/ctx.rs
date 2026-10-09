//! 実行ごとのヒープ（Heap）と、回収しない区間の文脈（ValueCtx・NoGcCtx・SlotOps）（ADR 0260 の決定 3）。

use std::ops::Deref;

use super::core::HeapCore;
use super::value::Epoch;

/// 実行ごとのヒープ。
pub struct Heap {
    core: Box<HeapCore>,
}

/// 作った後に変わらない対象を確保し読む文脈。
pub struct ValueCtx<'e> {
    core: &'e HeapCore,
    epoch: Epoch<'e>,
}

/// 回収しない区間の文脈。`Heap::epoch` だけが作る。`Clone` を持たない。
pub struct NoGcCtx<'e> {
    values: ValueCtx<'e>,
}

impl<'e> Deref for NoGcCtx<'e> {
    type Target = ValueCtx<'e>;

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn deref(&self) -> &ValueCtx<'e> {
        &self.values
    }
}

/// `NoGcCtx::host_mut` の閉包の中で `Slot` を読み書きする文脈。
pub struct SlotOps<'a, 'e> {
    core: &'a HeapCore,
    epoch: Epoch<'e>,
}

use super::slot::Slot;
use super::stats::{HeapConfig, HeapFault, HeapStats};
use super::trace::{Discard, Trace};
use super::value::{ObjId, Value};

#[cfg(test)]
#[path = "verification_tests.rs"]
mod verification_tests;

impl Heap {
    pub fn new(config: HeapConfig) -> Heap {
        Heap {
            core: Box::new(HeapCore::new(config)),
        }
    }
    pub fn config(&self) -> HeapConfig {
        self.core.config()
    }
    /// 回収しない区間を開き、`f` を実行する。
    ///
    /// 区間の外へ値を持ち出す（H3）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig};
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let _escaped = heap.epoch(|ctx| ctx.alloc_str("x", "test")); // 戻り値の型が 'e を含む
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig};
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let _len = heap.epoch(|ctx| ctx.alloc_str("x", "test").map(|v| ctx.str(v).map(str::len)).ok());
    /// ```
    ///
    /// 閉包の外の変数に値を残す（H3）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig, Value};
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let mut kept: Option<Value<'_>> = None;
    /// heap.epoch(|ctx| {
    ///     kept = ctx.alloc_str("x", "test").ok(); // 外の寿命と 'e は一致しない
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig, Slot};
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let mut kept = Slot::default();
    /// heap.epoch(|ctx| {
    ///     if let Ok(v) = ctx.alloc_str("x", "test") {
    ///         ctx.store(&mut kept, v);
    ///     }
    /// });
    /// ```
    ///
    /// 別のヒープの区間に値を渡す（H9）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig, Slot};
    /// let mut a = Heap::new(HeapConfig::default());
    /// let mut b = Heap::new(HeapConfig::default());
    /// let mut slot = Slot::default();
    /// a.epoch(|ca| {
    ///     if let Ok(v) = ca.alloc_str("x", "test") {
    ///         b.epoch(|cb| cb.store(&mut slot, v)); // 'a の値を 'b の区間で書く
    ///     }
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig, Slot};
    /// let mut a = Heap::new(HeapConfig::default());
    /// let mut b = Heap::new(HeapConfig::default());
    /// let mut slot = Slot::default();
    /// a.epoch(|ca| {
    ///     if let Ok(_v) = ca.alloc_str("x", "test") {
    ///         b.epoch(|cb| {
    ///             if let Ok(w) = cb.alloc_str("y", "test") {
    ///                 cb.store(&mut slot, w);
    ///             }
    ///         });
    ///     }
    /// });
    /// ```
    ///
    /// 区間の中で回収する（H2）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig, RootStack};
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let roots = RootStack::new();
    /// heap.epoch(|_ctx| {
    ///     heap.collect(&roots); // 区間は heap を &mut で借りている
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig, RootStack};
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let roots = RootStack::new();
    /// heap.epoch(|_ctx| {
    ///     let _ = roots.len();
    /// });
    /// ```
    ///
    /// `Host` の対象の共有の参照を持ったまま書き換える（H7）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig, HostData, Trace, Tracer};
    /// #[derive(Debug)]
    /// struct Data(u32);
    /// impl Trace for Data {
    ///     fn trace(&self, _t: &mut Tracer<'_>) {}
    /// }
    /// impl HostData for Data {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     let v = ctx.alloc_host(Data(1));
    ///     let shared = ctx.host::<Data>(v);
    ///     ctx.host_mut::<Data, _>(v, |d, _| d.0 = 2); // `host` の参照を持ったまま `&mut` で借りる
    ///     let _ = shared.map(|d| d.0);
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig, HostData, Trace, Tracer};
    /// #[derive(Debug)]
    /// struct Data(u32);
    /// impl Trace for Data {
    ///     fn trace(&self, _t: &mut Tracer<'_>) {}
    /// }
    /// impl HostData for Data {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     let v = ctx.alloc_host(Data(1));
    ///     let shared = ctx.host::<Data>(v);
    ///     let _ = ctx.host::<Data>(v);
    ///     let _ = shared.map(|d| d.0);
    /// });
    /// ```
    ///
    /// 値を作業用のスレッドへ渡す（H8。`Send`）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig};
    /// fn require_send<T: Send>(_: T) {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     if let Ok(v) = ctx.alloc_str("x", "test") {
    ///         require_send(v); // Value は Send でない
    ///     }
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig};
    /// fn require_send<T: Send>(_: T) {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     if let Ok(v) = ctx.alloc_str("x", "test") {
    ///         require_send(ctx.str(v).map(str::len));
    ///     }
    /// });
    /// ```
    ///
    /// 値を作業用のスレッドと共有する（H8。`Sync`）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig};
    /// fn require_sync<T: Sync>(_: &T) {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     if let Ok(v) = ctx.alloc_str("x", "test") {
    ///         require_sync(&v); // Value は Sync でない
    ///     }
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig};
    /// fn require_sync<T: Sync>(_: &T) {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     if let Ok(v) = ctx.alloc_str("x", "test") {
    ///         require_sync(&ctx.str(v).map(str::len));
    ///     }
    /// });
    /// ```
    ///
    /// `Slot` を作業用のスレッドへ渡す（H8。`Send`）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::Slot;
    /// fn require_send<T: Send>(_: T) {}
    /// let slot = Slot::default();
    /// require_send(slot); // Slot は Send でない
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::Slot;
    /// fn require_send<T: Send>(_: T) {}
    /// let slot = Slot::default();
    /// require_send(slot.is_immediate());
    /// ```
    ///
    /// `Slot` を作業用のスレッドと共有する（H8。`Sync`）:
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::Slot;
    /// fn require_sync<T: Sync>(_: &T) {}
    /// let slot = Slot::default();
    /// require_sync(&slot); // Slot は Sync でない
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::Slot;
    /// fn require_sync<T: Sync>(_: &T) {}
    /// let slot = Slot::default();
    /// require_sync(&slot.is_immediate());
    /// ```
    ///
    /// `SlotOps` の借用を `host_mut` の外へ持ち出す（H2・H7）:
    /// R02 の値の例では扱わない、操作用の文脈の寿命を確かめる（実装プラン R11）。
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Heap, HeapConfig, HostData, Trace, Tracer};
    /// #[derive(Debug)]
    /// struct Data;
    /// impl Trace for Data { fn trace(&self, _: &mut Tracer<'_>) {} }
    /// impl HostData for Data {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     let host = ctx.alloc_host(Data);
    ///     let _escaped = ctx.host_mut::<Data, _>(host, |_, ops| ops); // 借用は閉包の外へ出せない
    /// });
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Heap, HeapConfig, HostData, Trace, Tracer};
    /// #[derive(Debug)]
    /// struct Data;
    /// impl Trace for Data { fn trace(&self, _: &mut Tracer<'_>) {} }
    /// impl HostData for Data {}
    /// let mut heap = Heap::new(HeapConfig::default());
    /// heap.epoch(|ctx| {
    ///     let host = ctx.alloc_host(Data);
    ///     let _escaped = ctx.host_mut::<Data, _>(host, |_, ops| ops.new_slot(benitoite::runtime::heap::Value::Unit));
    /// });
    /// ```
    ///
    /// `Discarder` の借用を `discard` の外に残す（H2・H11）:
    /// 手放す操作の文脈を保存して後で使う書き方を拒む（実装プラン R11）。
    ///
    /// ```rust,compile_fail
    /// use benitoite::runtime::heap::{Discard, Discarder, Heap, HeapConfig};
    /// struct Save<'a, 'd>(&'a mut Option<&'a mut Discarder<'d>>);
    /// impl Discard for Save<'_, '_> {
    ///     fn discard(self, d: &mut Discarder<'_>) {
    ///         *self.0 = Some(d); // 借用は discard の外へ出せない
    ///     }
    /// }
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let mut kept = None;
    /// heap.epoch(|ctx| ctx.discard(Save(&mut kept)));
    /// ```
    ///
    /// ```rust,no_run
    /// use benitoite::runtime::heap::{Discard, Discarder, Heap, HeapConfig};
    /// struct Save<'a, 'd>(&'a mut Option<&'a mut Discarder<'d>>);
    /// impl Discard for Save<'_, '_> {
    ///     fn discard(self, d: &mut Discarder<'_>) {
    ///         *self.0 = None; // 文脈を保存しなければよい
    ///     }
    /// }
    /// let mut heap = Heap::new(HeapConfig::default());
    /// let mut kept = None;
    /// heap.epoch(|ctx| ctx.discard(Save(&mut kept)));
    /// ```
    pub fn epoch<R>(&mut self, f: impl for<'e> FnOnce(&mut NoGcCtx<'e>) -> R) -> R {
        let mut ctx = NoGcCtx {
            values: ValueCtx {
                core: &self.core,
                epoch: Epoch::new(),
            },
        };
        f(&mut ctx)
    }
    /// 回収の要求が立っているか（`HeapConfig::stress` の構成では常に真）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn collect_requested(&self) -> bool {
        self.core.collect_requested()
    }
    /// 安全点で回収する。`roots` は、この先使う `Slot` をすべて辿る（不変条件 H4）。
    pub fn collect(&mut self, roots: &dyn Trace) {
        self.core.collect(roots);
    }
    pub fn stats(&self) -> HeapStats {
        self.core.stats()
    }
    /// ヒープの検証器（ADR 0260 の決定 7）。`heap-verify` を無効にした構成では何もせず `Ok` を返す。
    /// すべての対象の頭と、対象と根の `Slot` が指す先を確かめる。
    pub fn verify(&self, roots: &dyn Trace) -> Result<(), HeapFault> {
        self.core.verify(roots)
    }
    /// 区間の中の読み出しや回収の中で記録した不具合を取り出す。VM は安全点ごとに呼ぶ。
    pub fn take_fault(&mut self) -> Option<HeapFault> {
        self.core.take_fault()
    }
    /// 生きている対象（回収していない対象）の識別をすべて返す。到達可能性を比べるテストで使う。
    pub fn object_ids(&self) -> Vec<ObjId> {
        self.core.object_ids()
    }
}

impl<'e> NoGcCtx<'e> {
    /// `Slot` の値を読む。区間の終わりまで使える写しを返す（数は変えない）。
    /// すべての構成でヒープの番号を比べ、`heap-verify` の構成ではさらに確保の世代を確かめる。
    /// 食い違えば不具合を記録して `Value::Unit` を返す。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn load(&self, s: &Slot) -> Value<'e> {
        self.values.core.slot_load(s, self.values.epoch)
    }
    /// `v` を持つ新しい `Slot` を作る（`v` の参照の開始を方式に知らせる）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn new_slot(&self, v: Value<'e>) -> Slot {
        self.values.core.slot_new_slot(v)
    }
    /// `dst` に `v` を書く。前の値の参照の終了と、`v` の参照の開始を方式に知らせる。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn store(&self, dst: &mut Slot, v: Value<'e>) {
        self.values.core.slot_store(dst, v)
    }
    /// `dst` を空（`Unit`）にする。使わなくなったレジスタを根から除くときに使う（02-08「枠を降ろす原因と処理」）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn clear(&self, dst: &mut Slot) {
        self.values.core.slot_clear(dst)
    }
    /// `src` の値を `dst` に移し、`src` を空にする。移した値の数は変えない（最後の使用での移動）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn move_slot(&self, dst: &mut Slot, src: &mut Slot) {
        self.values.core.slot_move_slot(dst, src)
    }
    /// `src` の値を読み、`src` を空にする。最後の使用の読み出しに使う。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn take(&self, src: &mut Slot) -> Value<'e> {
        self.values.core.slot_take(src, self.values.epoch)
    }
    /// `x` が所有する `Slot` をすべて手放す（`Discard`。不変条件 H11）。枠や継続の区画を捨てるときに使う。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn discard<T: Discard>(&self, x: T) {
        let mut d = super::trace::Discarder::new(self.values.core);
        x.discard(&mut d);
    }
    /// 回収の要求が、前にこの関数を呼んだ後に新しく立ったかを返す（一度だけ真を返す）。
    /// VM は真を受けたら予算を 0 にして遅い経路に入る（ADR 0263 の決定 3）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn take_collect_signal(&self) -> bool {
        self.values.core.take_collect_signal()
    }
    /// 回収の要求が立っているか。続けて戻る処理と後始末の回収の位置が調べる（ADR 0259 の決定 5）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn collect_requested(&self) -> bool {
        self.values.core.collect_requested()
    }
}

use super::build::{CheckedLen, StrBuf};
use super::value::{FieldsKind, ObjKind, OpaqueData};
use crate::runtime::Stop;

impl<'e> ValueCtx<'e> {
    /// 対象の種類。即値には `None` を返す。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn kind(&self, v: Value<'e>) -> Option<ObjKind> {
        self.core.kind(v)
    }
    /// 二つの値が同じ対象を指すか（即値どうしは `false`）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn same_object(&self, a: Value<'e>, b: Value<'e>) -> bool {
        self.core.same_object(a, b)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn object_id(&self, v: Value<'e>) -> Option<ObjId> {
        self.core.object_id(v)
    }

    /// 文字列の値を作る。大きさの上限を確かめる。
    pub fn alloc_str(&self, s: &str, function: &'static str) -> Result<Value<'e>, Stop> {
        CheckedLen::bytes(u64::try_from(s.len()).unwrap_or(u64::MAX), function)?;
        self.core.alloc_str(self.epoch, s)
    }
    /// 部分をつないだ文字列の値を作る。合計の大きさを先に確かめ、一度だけ写す。
    pub fn alloc_str_parts(
        &self,
        parts: &[&str],
        function: &'static str,
    ) -> Result<Value<'e>, Stop> {
        let len = checked_parts_len(parts.iter().map(|s| s.len()), function)?;
        self.core.alloc_str_parts(self.epoch, len.get(), parts)
    }
    /// 外部から受け取ったバイト列を文字列の値にする。上限を超えれば `Err(Stop)`、
    /// 正しい UTF-8 でなければ `Ok(None)`（呼び出し側が `IOErrorKind.InvalidUTF8` にする。ADR 0012）。
    pub fn alloc_str_utf8(
        &self,
        bytes: &[u8],
        function: &'static str,
    ) -> Result<Option<Value<'e>>, Stop> {
        CheckedLen::bytes(u64::try_from(bytes.len()).unwrap_or(u64::MAX), function)?;
        match std::str::from_utf8(bytes) {
            Ok(s) => self.core.alloc_str(self.epoch, s).map(Some),
            Err(_) => Ok(None),
        }
    }
    pub fn alloc_str_buf(&self, buf: StrBuf) -> Result<Value<'e>, Stop> {
        self.core.alloc_str(self.epoch, &buf.into_string())
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn str(&self, v: Value<'e>) -> Option<&str> {
        self.core.str(v)
    }

    pub fn alloc_bytes(&self, bytes: &[u8], function: &'static str) -> Result<Value<'e>, Stop> {
        CheckedLen::bytes(u64::try_from(bytes.len()).unwrap_or(u64::MAX), function)?;
        self.core.alloc_bytes(self.epoch, bytes)
    }
    /// 確かめた長さの `Bytes` を作り、`fill` で中身を書く。
    pub fn alloc_bytes_with(
        &self,
        len: CheckedLen,
        fill: impl FnOnce(&mut [u8]),
    ) -> Result<Value<'e>, Stop> {
        self.core.alloc_bytes_with(self.epoch, len.get(), fill)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn bytes(&self, v: Value<'e>) -> Option<&[u8]> {
        self.core.bytes(v)
    }

    /// 値の並びを持つ対象を作る。並びの長さが u32 に収まらなければ `Stop::Internal`。
    pub fn alloc_fields(
        &self,
        kind: FieldsKind,
        tag: u32,
        items: &[Value<'e>],
    ) -> Result<Value<'e>, Stop> {
        u32::try_from(items.len())
            .map_err(|_| Stop::Internal("fields length exceeds u32".into()))?;
        // 内部参照の開始は内部層の allocated が方式へ通知する（10-08「根と対象を辿る」、H6）。
        self.core.alloc_fields(self.epoch, kind, tag, items)
    }
    /// 値の並びを持つ対象の種類と `tag`。それ以外の値には `None`。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn fields_header(&self, v: Value<'e>) -> Option<(FieldsKind, u32)> {
        self.core.fields_header(v)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn fields_len(&self, v: Value<'e>) -> Option<u32> {
        self.core.fields_header(v)?;
        self.core.len(v)
    }
    /// `i` 番目の値の写し。範囲の外なら `None`。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn field(&self, v: Value<'e>, i: u32) -> Option<Value<'e>> {
        self.core.field(self.epoch, v, i)
    }

    pub fn alloc_opaque<T: OpaqueData>(&self, data: T) -> Value<'e> {
        self.core.new_opaque(self.epoch, data)
    }
    pub fn opaque<T: OpaqueData>(&self, v: Value<'e>) -> Option<&T> {
        self.core.opaque(v)
    }
}

// 合計が表現できないときも上限超過として返す（設計書 02-09「一つの操作で作る値の大きさの上限」）。
fn checked_parts_len(
    mut lengths: impl Iterator<Item = usize>,
    function: &'static str,
) -> Result<CheckedLen, Stop> {
    let sum = lengths
        .try_fold(0_u64, |sum, len| sum.checked_add(u64::try_from(len).ok()?))
        .unwrap_or(u64::MAX);
    CheckedLen::bytes(sum, function)
}

use super::value::HostData;

impl<'e> NoGcCtx<'e> {
    pub fn alloc_cell(&self, v: Value<'e>) -> Value<'e> {
        self.values.core.new_cell(self.values.epoch, v)
    }
    /// セルの中身。セルでなければ `None`。
    pub fn cell_get(&self, cell: Value<'e>) -> Option<Value<'e>> {
        self.values.core.cell_get(self.values.epoch, cell)
    }
    pub fn cell_version(&self, cell: Value<'e>) -> Option<u64> {
        self.values.core.cell(cell).map(|body| body.version.get())
    }
    /// セルに書き、版の番号を一つ増やす。書き込みの障壁の位置。セルでなければ `Stop::Internal`。
    pub fn cell_set(&self, cell: Value<'e>, v: Value<'e>) -> Result<(), Stop> {
        self.values.core.cell_set(cell, v)
    }

    pub fn alloc_host<T: HostData>(&self, data: T) -> Value<'e> {
        self.values.core.new_host(self.values.epoch, data)
    }
    pub fn host<T: HostData>(&self, v: Value<'e>) -> Option<&T> {
        self.values.core.host(v)
    }
    /// `Host` の対象を書き換える。書き込みの障壁の位置。型が違えば `None`。
    pub fn host_mut<T: HostData, R>(
        &mut self,
        v: Value<'e>,
        f: impl FnOnce(&mut T, &SlotOps<'_, 'e>) -> R,
    ) -> Option<R> {
        let ops = SlotOps {
            core: self.values.core,
            epoch: self.values.epoch,
        };
        self.values.core.with_host_mut(v, |data| f(data, &ops))
    }
}

impl<'a, 'e> SlotOps<'a, 'e> {
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn load(&self, s: &Slot) -> Value<'e> {
        self.core.slot_load(s, self.epoch)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn new_slot(&self, v: Value<'e>) -> Slot {
        self.core.slot_new_slot(v)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn store(&self, dst: &mut Slot, v: Value<'e>) {
        self.core.slot_store(dst, v)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn clear(&self, dst: &mut Slot) {
        self.core.slot_clear(dst)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn move_slot(&self, dst: &mut Slot, src: &mut Slot) {
        self.core.slot_move_slot(dst, src)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn take(&self, src: &mut Slot) -> Value<'e> {
        self.core.slot_take(src, self.epoch)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn discard<T: Discard>(&self, x: T) {
        let mut d = super::trace::Discarder::new(self.core);
        x.discard(&mut d);
    }
}

impl<'e> NoGcCtx<'e> {
    /// `CONR` のその場での再利用（上の手順 1〜4）。再利用したら同じ対象を指す値を、しなければ `None` を返す。
    pub fn reuse_ctor(
        &mut self,
        candidate: Value<'e>,
        tag: u32,
        args: &[Value<'e>],
    ) -> Result<Option<Value<'e>>, Stop> {
        self.values
            .core
            .reuse_ctor(self.values.epoch, candidate, tag, args)
    }
}

use crate::base::Decimal;

impl<'e> ValueCtx<'e> {
    pub fn alloc_decimal(&self, d: Decimal) -> Value<'e> {
        self.core.new_decimal(self.epoch, d)
    }
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn decimal(&self, v: Value<'e>) -> Option<Decimal> {
        self.core.decimal(v)
    }
}

impl NoGcCtx<'_> {
    pub(super) fn root_overflow(&self) {
        self.values.core.record_fault(
            super::stats::HeapFaultKind::CorruptHeader,
            "root stack length exceeds u32",
        );
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::super::slot::{RootIdx, RootStack};
    use super::super::stats::HeapFaultKind;
    use super::super::trace::{Discarder, Tracer};
    use super::*;

    // 作成時の関門: この公開 API の既存のテストはない。R01 の内部層のテストでは
    // 区間・Slot・RootStack・Host の借用と方式への通知を経由しないため、その退行を捕まえない。
    // 以下は区間をまたぐ値の保存、参照の所有の移動、型の検査、外国の Slot の拒否を守る。
    // R06 の前の文字列の準備と R02 が指定する通知の計数だけを内部層で行い、公開範囲は広げない。

    // R06 の作成時の関門: 公開の値操作による UTF-8・型・欄・上限の契約を守る。
    // 内部層の既存のテストは公開層の検査の抜けを捕まえない。上限超過時の確保数も確認し、
    // 本番の公開範囲を広げない。大きさの測定は R06 が定数の表明とは別に要求する。

    // heap-verify は対象の世代を値に加えるため、通常構成だけで 16 バイトを要求する（ADR 0258）。
    #[cfg(not(feature = "heap-verify"))]
    #[test]
    fn r06_value_and_slot_sizes_are_sixteen_bytes() {
        let value_size = std::mem::size_of::<Value<'static>>();
        let slot_size = std::mem::size_of::<Slot>();
        println!("Value={value_size}, Slot={slot_size}");
        assert_eq!((value_size, slot_size), (16, 16));
    }

    // 関門: Decimal の公開の確保・読み取りの接続と、根に残した値の区間をまたぐ保持。
    // 内部の対象のテストだけでは公開 API の種類や桁数の取り違えを検出できない（R35）。
    #[test]
    fn decimal_values_preserve_representation_across_collection() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = RootStack::new();
        let expected = Decimal::new(-12300, 4).unwrap();
        let root = heap.epoch(|ctx| {
            let value = ctx.alloc_decimal(expected);
            assert_eq!(ctx.kind(value), Some(ObjKind::Decimal));
            assert!(ctx.decimal(value).unwrap().same_repr(expected));
            for value in [
                Value::Int(1),
                Value::Byte(1),
                Value::Unit,
                ctx.alloc_str("1", "test").unwrap(),
                ctx.alloc_fields(FieldsKind::Ctor, 0, &[]).unwrap(),
            ] {
                assert!(ctx.decimal(value).is_none());
            }
            roots.push(ctx, value)
        });
        heap.collect(&roots);
        heap.epoch(|ctx| {
            let value = roots.get(ctx, root).unwrap();
            assert!(ctx.decimal(value).unwrap().same_repr(expected));
            roots.truncate(ctx, 0);
        });
        heap.collect(&roots);
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn r06_strings_bytes_and_fields_preserve_contents_and_check_kinds() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let text = ctx.alloc_str("あい", "test").unwrap();
            assert_eq!(ctx.str(text), Some("あい"));
            assert_eq!(ctx.kind(text), Some(ObjKind::Str));
            let parts = ctx.alloc_str_parts(&["", "あ", "い", ""], "join").unwrap();
            assert_eq!(ctx.str(parts), Some("あい"));
            assert_eq!(ctx.str(ctx.alloc_str_parts(&[], "join").unwrap()), Some(""));
            assert!(ctx.alloc_str_utf8(&[0xff, 0xc0], "read").unwrap().is_none());
            let external = ctx
                .alloc_str_utf8("うえ".as_bytes(), "read")
                .unwrap()
                .unwrap();
            assert_eq!(ctx.str(external), Some("うえ"));
            let mut buf = StrBuf::new("format");
            buf.push_str("お").unwrap();
            buf.push_char('か').unwrap();
            assert_eq!(ctx.str(ctx.alloc_str_buf(buf).unwrap()), Some("おか"));
            let bytes = ctx.alloc_bytes(&[0, 255, 127], "bytes").unwrap();
            assert_eq!(ctx.bytes(bytes), Some([0, 255, 127].as_slice()));
            let filled = ctx
                .alloc_bytes_with(CheckedLen::bytes(3, "fill").unwrap(), |b| {
                    assert_eq!(b, &[0, 0, 0]);
                    let other = ctx.alloc_str("during fill", "test").unwrap();
                    assert_eq!(ctx.str(other), Some("during fill"));
                    b[0] = 17;
                    b[2] = 42;
                })
                .unwrap();
            assert_eq!(ctx.bytes(filled), Some([17, 0, 42].as_slice()));
            assert_eq!(
                ctx.bytes(
                    ctx.alloc_bytes_with(CheckedLen::bytes(0, "empty").unwrap(), |b| assert!(
                        b.is_empty()
                    ))
                    .unwrap()
                ),
                Some([].as_slice())
            );
            let fields = ctx
                .alloc_fields(FieldsKind::Ctor, 1, &[text, Value::Int(-7), bytes])
                .unwrap();
            assert_eq!(ctx.fields_header(fields), Some((FieldsKind::Ctor, 1)));
            assert_eq!(ctx.fields_len(fields), Some(3));
            assert_eq!(ctx.str(ctx.field(fields, 0).unwrap()), Some("あい"));
            assert_eq!(ctx.field(fields, 1).unwrap().as_int(), Some(-7));
            assert_eq!(
                ctx.bytes(ctx.field(fields, 2).unwrap()),
                Some([0, 255, 127].as_slice())
            );
            assert!(ctx.field(fields, 3).is_none());
            assert!(ctx.field(fields, u32::MAX).is_none());
            let empty = ctx.alloc_fields(FieldsKind::Ctor, 9, &[]).unwrap();
            assert_eq!(ctx.fields_header(empty), Some((FieldsKind::Ctor, 9)));
            assert_eq!(ctx.fields_len(empty), Some(0));
            assert!(ctx.field(empty, 0).is_none());
            for v in [Value::Unit, Value::Int(1), bytes, fields] {
                assert!(ctx.str(v).is_none());
            }
            for v in [Value::Unit, text, fields] {
                assert!(ctx.bytes(v).is_none());
            }
            for v in [Value::Unit, text, bytes] {
                assert!(ctx.fields_header(v).is_none());
                assert!(ctx.fields_len(v).is_none());
                assert!(ctx.field(v, 0).is_none());
            }
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn r06_checked_lengths_accept_limits_and_reject_one_more() {
        use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit};
        for (limit, unit, check) in [
            (
                MAX_STRING_BYTES,
                SizeUnit::Bytes,
                CheckedLen::bytes as fn(u64, &'static str) -> Result<CheckedLen, Stop>,
            ),
            (MAX_LIST_LEN, SizeUnit::Elements, CheckedLen::elements),
        ] {
            assert_eq!(u64::from(check(limit, "boundary").unwrap().get()), limit);
            assert_eq!(
                check(limit + 1, "boundary"),
                Err(Stop::Resource(ResourceError::ValueTooLarge {
                    function: "boundary",
                    size: limit + 1,
                    unit,
                    limit,
                }))
            );
        }
    }

    // Miri では実際の巨大な値を作らずに上限を確かめる CheckedLen のテストを使う。
    // このテストの 1 MiB の準備を毎回解釈するのは遅すぎる（check-heap.sh の方針）。
    #[cfg_attr(miri, ignore)]
    #[test]
    fn r06_string_parts_reject_oversize_and_overflow_without_allocating() {
        use crate::runtime::{MAX_STRING_BYTES, ResourceError, SizeUnit};
        let mut heap = Heap::new(HeapConfig::default());
        let part = "x".repeat(1 << 20);
        let parts = vec![part.as_str(); 1025];
        let before = heap.stats().allocations;
        heap.epoch(|ctx| {
            assert_eq!(
                ctx.alloc_str_parts(&parts, "join").unwrap_err(),
                Stop::Resource(ResourceError::ValueTooLarge {
                    function: "join",
                    size: 1025 * (1 << 20),
                    unit: SizeUnit::Bytes,
                    limit: MAX_STRING_BYTES,
                })
            );
            // 安全な実在の &str の配列では u64 の合計を溢れさせられないので、同じ計算へ長さを与える。
            assert_eq!(
                checked_parts_len([usize::MAX, usize::MAX, 2].into_iter(), "join"),
                Err(Stop::Resource(ResourceError::ValueTooLarge {
                    function: "join",
                    size: u64::MAX,
                    unit: SizeUnit::Bytes,
                    limit: MAX_STRING_BYTES,
                }))
            );
        });
        assert_eq!(heap.stats().allocations, before);
    }

    #[derive(Debug, PartialEq)]
    struct Pattern(u32);
    impl OpaqueData for Pattern {}
    #[derive(Debug)]
    struct OtherPattern;
    impl OpaqueData for OtherPattern {}

    #[test]
    fn r06_opaque_checks_rust_type_and_object_kind() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let opaque = ctx.alloc_opaque(Pattern(42));
            assert_eq!(ctx.kind(opaque), Some(ObjKind::Opaque));
            assert_eq!(ctx.opaque::<Pattern>(opaque), Some(&Pattern(42)));
            assert!(ctx.opaque::<OtherPattern>(opaque).is_none());
            assert!(ctx.opaque::<Pattern>(Value::Int(42)).is_none());
            let string = ctx.alloc_str("42", "test").unwrap();
            assert!(ctx.opaque::<Pattern>(string).is_none());
        });
        assert!(heap.take_fault().is_none());
    }

    fn string<'e>(ctx: &NoGcCtx<'e>, text: &str) -> Value<'e> {
        ctx.values.core.alloc_str(ctx.values.epoch, text).unwrap()
    }

    #[derive(Debug, Default)]
    struct Data {
        slots: Vec<Slot>,
        number: u32,
    }
    impl Trace for Data {
        fn trace(&self, t: &mut Tracer<'_>) {
            self.slots.trace(t);
        }
    }
    impl HostData for Data {}
    #[derive(Debug)]
    struct Other;
    impl Trace for Other {
        fn trace(&self, _t: &mut Tracer<'_>) {}
    }
    impl HostData for Other {}
    struct Owned {
        slots: Vec<Slot>,
        extra: Option<Slot>,
    }
    impl Discard for Owned {
        fn discard(self, d: &mut Discarder<'_>) {
            self.slots.discard(d);
            self.extra.discard(d);
        }
    }

    #[test]
    fn slots_preserve_values_between_epochs_and_transfer_ownership() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut saved = Slot::default();
        heap.epoch(|ctx| {
            let value = string(ctx, "日本語");
            ctx.store(&mut saved, value);
            assert!(!saved.is_immediate());
        });
        heap.epoch(|ctx| {
            let value = ctx.load(&saved);
            assert_eq!(ctx.values.core.str(value), Some("日本語"));
            let mut dst = ctx.new_slot(Value::Int(99));
            ctx.move_slot(&mut dst, &mut saved);
            assert!(saved.is_immediate());
            assert!(matches!(ctx.load(&saved), Value::Unit));
            assert_eq!(ctx.values.core.str(ctx.load(&dst)), Some("日本語"));
            let taken = ctx.take(&mut dst);
            assert!(dst.is_immediate());
            assert!(matches!(ctx.load(&dst), Value::Unit));
            assert_eq!(ctx.values.core.str(taken), Some("日本語"));
            ctx.store(&mut dst, taken);
            ctx.clear(&mut dst);
            assert!(dst.is_immediate());
            assert!(matches!(ctx.load(&dst), Value::Unit));
            ctx.store(&mut dst, Value::Int(-7));
            assert!(dst.is_immediate());
            assert_eq!(ctx.load(&dst).as_int(), Some(-7));
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn root_stack_tracks_positions_and_truncation() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = RootStack::new();
        assert!(roots.is_empty());
        assert_eq!(roots.len(), 0);
        heap.epoch(|ctx| {
            let a = roots.push(ctx, Value::Int(17));
            let b = roots.push(ctx, string(ctx, "saved"));
            assert_eq!(a, RootIdx(0));
            assert_eq!(b, RootIdx(1));
            assert_eq!(roots.len(), 2);
            assert_eq!(roots.get(ctx, a).unwrap().as_int(), Some(17));
            assert_eq!(
                ctx.values.core.str(roots.get(ctx, b).unwrap()),
                Some("saved")
            );
            roots.truncate(ctx, 1);
            assert!(roots.get(ctx, b).is_none());
            assert!(roots.get(ctx, RootIdx(u32::MAX)).is_none());
            assert_eq!(roots.len(), 1);
            roots.truncate(ctx, 99);
            assert_eq!(roots.len(), 1);
            roots.truncate(ctx, 0);
            assert!(roots.is_empty());
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn cell_writes_update_value_and_version_and_reject_other_kinds() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let first = string(ctx, "first");
            let cell = ctx.alloc_cell(first);
            assert_eq!(ctx.cell_version(cell), Some(0));
            assert_eq!(
                ctx.values.core.str(ctx.cell_get(cell).unwrap()),
                Some("first")
            );
            for (version, value) in [(1, Value::Int(42)), (2, Value::Bool(true))] {
                ctx.cell_set(cell, value).unwrap();
                assert_eq!(ctx.cell_version(cell), Some(version));
            }
            assert_eq!(ctx.cell_get(cell).unwrap().as_bool(), Some(true));
            // 自己参照も版を進め、一つの実行の中で循環を作れる（ADR 0267）。
            ctx.cell_set(cell, cell).unwrap();
            assert!(ctx.same_object(ctx.cell_get(cell).unwrap(), cell));
            assert_eq!(ctx.cell_version(cell), Some(3));
            for value in [Value::Unit, Value::Int(5), first] {
                assert!(ctx.cell_get(value).is_none());
                assert!(ctx.cell_version(value).is_none());
                assert!(matches!(
                    ctx.cell_set(value, Value::Unit),
                    Err(Stop::Internal(_))
                ));
            }
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn host_mutation_uses_slot_ops_and_checks_rust_types() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let value = string(ctx, "host slot");
            let host = ctx.alloc_host(Data::default());
            assert!(ctx.host::<Other>(host).is_none());
            assert!(
                ctx.host_mut::<Other, _>(host, |_, _| panic!("wrong type"))
                    .is_none()
            );
            assert!(ctx.host::<Data>(Value::Unit).is_none());
            assert!(
                ctx.host_mut::<Data, _>(Value::Unit, |_, _| panic!("wrong kind"))
                    .is_none()
            );
            assert_eq!(
                ctx.host_mut::<Data, _>(host, |data, ops| {
                    let mut src = ops.new_slot(value);
                    let mut dst = ops.new_slot(Value::Int(9));
                    ops.move_slot(&mut dst, &mut src);
                    assert!(src.is_immediate());
                    assert!(matches!(ops.load(&src), Value::Unit));
                    assert!(!dst.is_immediate());
                    let taken = ops.take(&mut dst);
                    assert!(dst.is_immediate());
                    ops.store(&mut dst, taken);
                    ops.clear(&mut dst);
                    assert!(matches!(ops.load(&dst), Value::Unit));
                    ops.store(&mut dst, value);
                    ops.discard(Some(ops.new_slot(value)));
                    data.slots.push(dst);
                    data.number = 12;
                    data.number
                }),
                Some(12)
            );
            let data = ctx.host::<Data>(host).unwrap();
            assert_eq!(data.number, 12);
            assert_eq!(
                ctx.values.core.str(ctx.load(&data.slots[0])),
                Some("host slot")
            );
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn discard_notifies_each_owned_object_reference_once() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let value = ctx.alloc_cell(Value::Unit);
            let before = ctx.values.core.notification_counts();
            ctx.discard(vec![
                ctx.new_slot(value),
                ctx.new_slot(value),
                ctx.new_slot(Value::Int(1)),
            ]);
            ctx.discard(Some(ctx.new_slot(value)));
            ctx.discard(Owned {
                slots: vec![ctx.new_slot(value)],
                extra: Some(ctx.new_slot(value)),
            });
            assert_eq!(
                ctx.values.core.notification_counts(),
                (before.0 + 5, before.1 + 5)
            );
            let mut src = ctx.new_slot(value);
            let mut dst = ctx.new_slot(value);
            let before = ctx.values.core.notification_counts();
            ctx.move_slot(&mut dst, &mut src);
            assert_eq!(
                ctx.values.core.notification_counts(),
                (before.0, before.1 + 1)
            );
            ctx.clear(&mut dst);
        });
    }

    #[derive(Clone, Copy, Debug)]
    enum Operation {
        Load,
        Store,
        Clear,
        Take,
        Discard,
        MoveSource,
        MoveDestination,
        Collect,
        Verify,
        RootGet,
        RootTruncate,
    }

    #[test]
    fn foreign_slots_are_rejected_before_reading_or_notifying_their_heap() {
        let mut a = Heap::new(HeapConfig::default());
        let ids = a.epoch(|ctx| {
            let _ = ctx.alloc_cell(Value::Int(7));
            ctx.values.core.object_ids()
        });
        for operation in [
            Operation::Load,
            Operation::Store,
            Operation::Clear,
            Operation::Take,
            Operation::Discard,
            Operation::MoveSource,
            Operation::MoveDestination,
            Operation::Collect,
            Operation::Verify,
            Operation::RootGet,
            Operation::RootTruncate,
        ] {
            // 各行で本物の元ヒープと対象を使い、番号違反以外の理由では拒否させない。
            let mut foreign = a.epoch(|ctx| {
                let epoch = ctx.values.epoch;
                let value = ctx.values.core.alloc_cell(epoch, Value::Int(7)).unwrap();
                ctx.new_slot(value)
            });
            let mut roots = RootStack::new();
            if matches!(operation, Operation::RootGet | Operation::RootTruncate) {
                a.epoch(|ctx| {
                    let value = ctx.alloc_cell(Value::Int(7));
                    roots.push(ctx, value);
                });
            }
            let before_ids = a.object_ids();
            let before_counts = a.core.notification_counts();
            let mut b = Heap::new(HeapConfig::default());
            match operation {
                Operation::Collect => b.collect(&foreign),
                Operation::Verify => {
                    let result = b.verify(&foreign);
                    #[cfg(feature = "heap-verify")]
                    assert_eq!(result.unwrap_err().kind, HeapFaultKind::ForeignHeap);
                    #[cfg(not(feature = "heap-verify"))]
                    {
                        assert!(result.is_ok());
                        b.collect(&foreign);
                    }
                }
                Operation::Load
                | Operation::Store
                | Operation::Clear
                | Operation::Take
                | Operation::Discard
                | Operation::MoveSource
                | Operation::MoveDestination
                | Operation::RootGet
                | Operation::RootTruncate => b.epoch(|ctx| match operation {
                    Operation::Load => assert!(matches!(ctx.load(&foreign), Value::Unit)),
                    Operation::Store => {
                        ctx.store(&mut foreign, Value::Int(1));
                        assert_eq!(ctx.load(&foreign).as_int(), Some(1));
                    }
                    Operation::Clear => {
                        ctx.clear(&mut foreign);
                        assert!(foreign.is_immediate());
                    }
                    Operation::Take => {
                        assert!(matches!(ctx.take(&mut foreign), Value::Unit));
                        assert!(foreign.is_immediate());
                    }
                    Operation::Discard => ctx.discard(std::mem::take(&mut foreign)),
                    Operation::MoveSource => {
                        let mut dst = Slot::default();
                        ctx.move_slot(&mut dst, &mut foreign);
                        assert!(matches!(ctx.load(&dst), Value::Unit));
                        assert!(foreign.is_immediate());
                    }
                    Operation::MoveDestination => {
                        let mut src = ctx.new_slot(Value::Int(8));
                        ctx.move_slot(&mut foreign, &mut src);
                        assert_eq!(ctx.load(&foreign).as_int(), Some(8));
                        assert!(src.is_immediate());
                    }
                    Operation::RootGet | Operation::RootTruncate => {
                        if matches!(operation, Operation::RootGet) {
                            assert!(matches!(roots.get(ctx, RootIdx(0)), Some(Value::Unit)));
                        } else {
                            roots.truncate(ctx, 0);
                            assert!(roots.is_empty());
                        }
                    }
                    Operation::Collect | Operation::Verify => unreachable!(),
                }),
            }
            assert_eq!(
                b.take_fault().unwrap().kind,
                HeapFaultKind::ForeignHeap,
                "{operation:?}"
            );
            assert!(b.take_fault().is_none());
            assert_eq!(b.core.notification_counts(), (0, 0), "{operation:?}");
            assert_eq!(a.object_ids(), before_ids);
            assert_eq!(a.core.notification_counts(), before_counts);
        }
        assert!(a.object_ids().starts_with(&ids));
        assert!(a.take_fault().is_none());
    }

    #[test]
    fn collection_preserves_rooted_contents_and_counts_one_collection() {
        for stress in [false, true] {
            let config = HeapConfig {
                stress,
                ..HeapConfig::default()
            };
            let mut heap = Heap::new(config);
            assert_eq!(heap.config().stress, stress || cfg!(feature = "gc-stress"));
            let mut roots = RootStack::new();
            let index = heap.epoch(|ctx| roots.push(ctx, string(ctx, "rooted")));
            let before = heap.stats();
            if stress || cfg!(feature = "gc-stress") {
                assert!(heap.collect_requested());
                heap.epoch(|ctx| {
                    assert!(ctx.collect_requested());
                    assert!(ctx.take_collect_signal());
                    assert!(!ctx.take_collect_signal());
                });
            }
            heap.collect(&roots);
            assert_eq!(heap.stats().collections, before.collections + 1);
            assert_eq!(heap.stats().roots_traced, before.roots_traced + 1);
            assert!(heap.stats().peak_heap_bytes >= heap.stats().live_bytes);
            heap.epoch(|ctx| {
                assert_eq!(
                    ctx.values.core.str(roots.get(ctx, index).unwrap()),
                    Some("rooted")
                );
                roots.truncate(ctx, 0);
            });
            assert!(heap.take_fault().is_none());
        }
    }

    #[cfg(feature = "heap-verify")]
    #[test]
    fn freed_generation_is_rejected_without_reading_released_memory() {
        let mut heap = Heap::new(HeapConfig::default());
        let saved = heap.epoch(|ctx| ctx.new_slot(string(ctx, "stale")));
        heap.core
            .free_object(saved.raw().0.as_obj().unwrap().ptr())
            .unwrap();
        heap.epoch(|ctx| assert!(matches!(ctx.load(&saved), Value::Unit)));
        assert_eq!(
            heap.take_fault().unwrap().kind,
            HeapFaultKind::StaleReference
        );
        assert_eq!(
            heap.verify(&saved).unwrap_err().kind,
            HeapFaultKind::ReachableFreed
        );
        heap.epoch(|ctx| {
            let host = ctx.alloc_host(Data::default());
            ctx.host_mut::<Data, _>(host, |_, ops| {
                assert!(matches!(ops.load(&saved), Value::Unit))
            })
            .unwrap();
        });
        assert_eq!(
            heap.take_fault().unwrap().kind,
            HeapFaultKind::StaleReference
        );
    }
}

#[cfg(test)]
mod r04_tests {
    // 作成時の関門: 公開層で H1・H6 と再利用の契約を確かめる。
    // R02 は方式への通知、R06 は値の読み書きが主対象なので、候補の重複・
    // 循環の残留・再利用の契約違反はここが持ち主となる。
    // 期待する到達集合は操作とともに作る独立のグラフから求める。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::super::trace::Tracer;
    use super::*;
    use std::cell::Cell;
    use std::collections::{BTreeMap, BTreeSet};
    use std::rc::Rc;

    #[test]
    fn r04_candidates_survive_resaving_and_free_exactly_once() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = Vec::new();
        heap.epoch(|ctx| {
            ctx.alloc_str("temporary", "test").unwrap();
            let again = ctx.alloc_str("discard twice", "test").unwrap();
            let mut slot = ctx.new_slot(again);
            ctx.clear(&mut slot);
            ctx.store(&mut slot, again);
            ctx.clear(&mut slot);
            assert_eq!(ctx.str(again), Some("discard twice"));
            let saved = ctx.alloc_str("saved", "test").unwrap();
            ctx.store(&mut slot, saved);
            let saved = ctx.take(&mut slot);
            assert_eq!(ctx.str(saved), Some("saved"));
            ctx.store(&mut slot, saved);
            roots.push(slot);
        });
        let before = heap.stats().frees;
        heap.collect(&roots);
        assert_eq!(heap.stats().frees - before, 2);
        heap.epoch(|ctx| {
            assert_eq!(ctx.str(ctx.load(&roots[0])), Some("saved"));
            ctx.discard(std::mem::take(&mut roots));
        });
        heap.collect(&roots);
        assert_eq!(heap.stats().frees - before, 3);
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn r04_reuse_checks_contract_and_returns_none_without_mutation() {
        for reuse in [false, true] {
            let mut heap = Heap::new(HeapConfig {
                reuse,
                ..HeapConfig::default()
            });
            let mut roots = Vec::new();
            heap.epoch(|ctx| {
                for bad in [
                    Value::Int(1),
                    ctx.alloc_str("wrong", "test").unwrap(),
                    ctx.alloc_fields(FieldsKind::ListCell, 0, &[Value::Int(1)])
                        .unwrap(),
                ] {
                    assert!(matches!(
                        ctx.reuse_ctor(bad, 2, &[Value::Int(2)]),
                        Err(Stop::Internal(_))
                    ));
                }
                let ctor = ctx
                    .alloc_fields(FieldsKind::Ctor, 1, &[Value::Int(10)])
                    .unwrap();
                assert!(matches!(
                    ctx.reuse_ctor(ctor, 2, &[]),
                    Err(Stop::Internal(_))
                ));
                assert_eq!(ctx.fields_header(ctor), Some((FieldsKind::Ctor, 1)));
                let mut a = ctx.new_slot(ctor);
                let b = ctx.new_slot(ctor);
                let candidate = ctx.take(&mut a);
                let arg = ctx.load(&b);
                assert!(ctx.reuse_ctor(candidate, 2, &[arg]).unwrap().is_none());
                assert_eq!(ctx.field(candidate, 0).unwrap().as_int(), Some(10));
                ctx.discard(b);
                assert!(
                    ctx.reuse_ctor(candidate, 2, &[Value::Int(20)])
                        .unwrap()
                        .is_none()
                );
                assert_eq!(ctx.fields_header(candidate), Some((FieldsKind::Ctor, 1)));
                assert_eq!(ctx.field(candidate, 0).unwrap().as_int(), Some(10));
                roots.push(ctx.new_slot(candidate));
                // 根に保存しない候補も変更されず、次の安全点で回収される。
                let unsaved = ctx.alloc_fields(FieldsKind::Ctor, 3, &[]).unwrap();
                assert!(ctx.reuse_ctor(unsaved, 4, &[]).unwrap().is_none());
                assert_eq!(ctx.fields_header(unsaved), Some((FieldsKind::Ctor, 3)));
            });
            let before = heap.stats().frees;
            heap.collect(&roots);
            assert_eq!(heap.stats().frees - before, 3);
            assert_eq!(heap.object_ids().len(), 1);
            let stats = heap.stats();
            assert_eq!(
                (
                    stats.rc_increments,
                    stats.rc_decrements,
                    stats.rc_elided,
                    stats.reuses
                ),
                (0, 0, 0, 0)
            );
            heap.epoch(|ctx| {
                let value = ctx.load(&roots[0]);
                assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, 1)));
                assert_eq!(ctx.field(value, 0).unwrap().as_int(), Some(10));
                ctx.discard(std::mem::take(&mut roots));
            });
            heap.collect(&roots);
            assert_eq!(heap.stats().frees - before, 4);
            assert!(heap.take_fault().is_none());
        }
    }

    #[test]
    fn r04_million_linked_and_nested_objects_free_without_recursion() {
        // Miri は解放の連鎖の安全性を小さな構造で調べ、百万の深さは通常実行に残す（実装プラン R11）。
        let depth = if cfg!(miri) { 64 } else { 1_000_000 };
        for kind in [FieldsKind::ListCell, FieldsKind::Ctor] {
            let mut heap = Heap::new(HeapConfig::default());
            let mut roots = Vec::new();
            heap.epoch(|ctx| {
                let mut value = Value::Unit;
                for i in 0..depth {
                    value = if kind == FieldsKind::ListCell {
                        ctx.alloc_fields(kind, 0, &[Value::Int(i), value])
                    } else {
                        ctx.alloc_fields(kind, 0, &[value])
                    }
                    .unwrap();
                }
                roots.push(ctx.new_slot(value));
            });
            heap.collect(&roots);
            assert_eq!(heap.stats().frees, 0);
            heap.epoch(|ctx| ctx.discard(std::mem::take(&mut roots)));
            let before = heap.stats().frees;
            heap.collect(&roots);
            assert_eq!(heap.stats().frees - before, u64::try_from(depth).unwrap());
            assert!(heap.object_ids().is_empty());
            assert!(heap.take_fault().is_none());
        }
    }

    #[derive(Debug)]
    struct Host {
        slot: Slot,
        drops: Rc<Cell<u32>>,
    }
    impl Trace for Host {
        fn trace(&self, t: &mut Tracer<'_>) {
            t.slot(&self.slot);
        }
    }
    impl HostData for Host {}
    impl Drop for Host {
        fn drop(&mut self) {
            self.drops.set(self.drops.get() + 1);
        }
    }
    #[test]
    fn r04_shared_substructure_and_host_edges_remain_until_last_owner() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = Vec::new();
        let drops = Rc::new(Cell::new(0));
        heap.epoch(|ctx| {
            let shared = ctx.alloc_str("shared", "test").unwrap();
            let host = ctx.alloc_host(Host {
                slot: ctx.new_slot(shared),
                drops: Rc::clone(&drops),
            });
            let ctor = ctx.alloc_fields(FieldsKind::Ctor, 0, &[shared]).unwrap();
            roots.push(ctx.new_slot(host));
            roots.push(ctx.new_slot(ctor));
        });
        heap.collect(&roots);
        heap.epoch(|ctx| ctx.discard(roots.pop().unwrap()));
        heap.collect(&roots);
        assert_eq!(heap.stats().frees, 1);
        heap.epoch(|ctx| {
            let host = ctx.load(&roots[0]);
            assert_eq!(
                ctx.str(ctx.load(&ctx.host::<Host>(host).unwrap().slot)),
                Some("shared")
            );
            ctx.discard(std::mem::take(&mut roots));
        });
        heap.collect(&roots);
        assert_eq!(heap.stats().frees, 3);
        assert_eq!(drops.get(), 1);
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn r04_cell_cycles_remain_reachable_then_free_with_exact_statistics() {
        let long = if cfg!(miri) { 100 } else { 100_000 };
        // 自己循環、二つのセル、セルと並びが交互の長い循環。
        for (len, fields) in [(1, false), (2, false), (long, true)] {
            let mut heap = Heap::new(HeapConfig {
                stress: true,
                ..HeapConfig::default()
            });
            let mut roots = Vec::new();
            heap.epoch(|ctx| {
                let first = ctx.alloc_cell(Value::Unit);
                let mut previous = first;
                for _ in 1..len {
                    let next = ctx.alloc_cell(Value::Unit);
                    let edge = if fields {
                        ctx.alloc_fields(FieldsKind::Ctor, 0, &[next]).unwrap()
                    } else {
                        next
                    };
                    ctx.cell_set(previous, edge).unwrap();
                    previous = next;
                }
                let edge = if fields {
                    ctx.alloc_fields(FieldsKind::Ctor, 0, &[first]).unwrap()
                } else {
                    first
                };
                ctx.cell_set(previous, edge).unwrap();
                roots.push(ctx.new_slot(first));
            });
            let before = heap.stats();
            heap.collect(&roots);
            assert_eq!(heap.stats().frees, before.frees);
            assert_eq!(heap.stats().live_bytes, before.allocated_bytes);
            heap.epoch(|ctx| {
                assert_eq!(ctx.cell_version(ctx.load(&roots[0])), Some(1));
                ctx.discard(std::mem::take(&mut roots));
            });
            heap.collect(&roots);
            assert_eq!(
                heap.stats().frees - before.frees,
                u64::try_from(len * if fields { 2 } else { 1 }).unwrap()
            );
            assert_eq!(heap.stats().live_bytes, 0);
            assert!(heap.object_ids().is_empty());
            assert_eq!(heap.verify(&roots), Ok(()));
            assert!(heap.take_fault().is_none());
        }
    }

    #[test]
    fn r04_reachable_sets_match_an_independent_graph() {
        let mut heap = Heap::new(HeapConfig {
            stress: true,
            ..HeapConfig::default()
        });
        let mut roots = Vec::new();
        let mut graph = BTreeMap::<ObjId, Vec<ObjId>>::new();
        let ids = heap.epoch(|ctx| {
            let shared = ctx.alloc_str("shared", "test").unwrap();
            let a = ctx.alloc_cell(shared);
            let b = ctx.alloc_cell(Value::Unit);
            let node = ctx
                .alloc_fields(FieldsKind::Ctor, 0, &[a, shared, a])
                .unwrap();
            let outside = ctx.alloc_fields(FieldsKind::Ctor, 0, &[shared]).unwrap();
            let ids: Vec<_> = [shared, a, b, node, outside]
                .into_iter()
                .map(|v| ctx.object_id(v).unwrap())
                .collect();
            graph.insert(ids[0], vec![]);
            graph.insert(ids[1], vec![ids[0]]);
            graph.insert(ids[2], vec![]);
            graph.insert(ids[3], vec![ids[1], ids[0], ids[1]]);
            graph.insert(ids[4], vec![ids[0]]);
            roots.extend([
                ctx.new_slot(a),
                ctx.new_slot(b),
                ctx.new_slot(node),
                ctx.new_slot(outside),
            ]);
            ids
        });
        for phase in 0..4 {
            heap.epoch(|ctx| {
                if phase == 0 {
                    let a = ctx.load(&roots[0]);
                    let b = ctx.load(&roots[1]);
                    let node = ctx.load(&roots[2]);
                    ctx.cell_set(a, b).unwrap();
                    ctx.cell_set(b, node).unwrap();
                    graph.insert(ids[1], vec![ids[2]]);
                    graph.insert(ids[2], vec![ids[3]]);
                    ctx.clear(&mut roots[0]);
                    ctx.clear(&mut roots[1]);
                } else if phase == 1 {
                    ctx.clear(&mut roots[2]);
                } else if phase == 2 {
                    ctx.clear(&mut roots[3]);
                }
            });
            let mut work = if phase == 0 {
                vec![ids[3], ids[4]]
            } else if phase == 1 {
                vec![ids[4]]
            } else {
                vec![]
            };
            let mut expected = BTreeSet::new();
            while let Some(id) = work.pop() {
                if expected.insert(id) {
                    work.extend(&graph[&id]);
                }
            }
            heap.collect(&roots);
            assert_eq!(
                heap.object_ids().into_iter().collect::<BTreeSet<_>>(),
                expected
            );
            assert!(heap.take_fault().is_none());
        }
    }
}
