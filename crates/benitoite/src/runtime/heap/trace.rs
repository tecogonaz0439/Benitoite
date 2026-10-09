//! 根と対象の中の Slot を辿る（Trace）、所有する Slot を手放す（Discard）（設計書 02-09「メモリの管理」）。

use super::core::{HeapCore, TraceSink};
use super::slot::Slot;

/// 持つ `Slot` をすべて訪れる（不変条件 H5）。公開の層の `Slot` を手放す操作には使わない（それは `Discard`）。
pub trait Trace {
    fn trace(&self, t: &mut Tracer<'_>);
}

/// `Trace::trace` が `Slot` を知らせる相手。作れるのは内部の層だけである。
pub struct Tracer<'t> {
    sink: &'t mut dyn TraceSink,
}

/// 所有する `Slot` をすべて `Discarder::slot` に渡して手放す（不変条件 H11）。
pub trait Discard {
    fn discard(self, d: &mut Discarder<'_>);
}

/// `Discard::discard` が `Slot` を渡す相手。作れるのは `NoGcCtx::discard` と `SlotOps::discard` だけである。
pub struct Discarder<'d> {
    core: &'d HeapCore,
}

impl Trace for Slot {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slot(self);
    }
}

impl<T: Trace> Trace for [T] {
    fn trace(&self, t: &mut Tracer<'_>) {
        for x in self {
            x.trace(t);
        }
    }
}

impl<T: Trace> Trace for Vec<T> {
    fn trace(&self, t: &mut Tracer<'_>) {
        self.as_slice().trace(t);
    }
}

impl<T: Trace> Trace for Option<T> {
    fn trace(&self, t: &mut Tracer<'_>) {
        if let Some(x) = self {
            x.trace(t);
        }
    }
}

impl<T: Trace + ?Sized> Trace for Box<T> {
    fn trace(&self, t: &mut Tracer<'_>) {
        (**self).trace(t);
    }
}

impl Discard for Slot {
    fn discard(self, d: &mut Discarder<'_>) {
        d.slot(self);
    }
}

impl<T: Discard> Discard for Vec<T> {
    fn discard(self, d: &mut Discarder<'_>) {
        for x in self {
            x.discard(d);
        }
    }
}

impl<T: Discard> Discard for Option<T> {
    fn discard(self, d: &mut Discarder<'_>) {
        if let Some(x) = self {
            x.discard(d);
        }
    }
}

impl<T: Discard> Discard for Box<T> {
    fn discard(self, d: &mut Discarder<'_>) {
        (*self).discard(d);
    }
}

impl<'t> Tracer<'t> {
    pub(super) fn new(sink: &'t mut dyn TraceSink) -> Tracer<'t> {
        Tracer { sink }
    }
    pub fn slot(&mut self, s: &Slot) {
        if self.sink.core().check_slot_heap(s) {
            self.sink.visit(s);
        } else {
            self.sink.foreign_slot();
        }
    }
    pub fn slots(&mut self, s: &[Slot]) {
        for slot in s {
            self.slot(slot);
        }
    }
}

impl<'d> Discarder<'d> {
    pub(super) fn new(core: &'d HeapCore) -> Discarder<'d> {
        Discarder { core }
    }
    /// `s` が対象を指していれば「指さなくなった」（参照の終了）を方式に知らせ、`s` を捨てる。
    /// ヒープの番号が食い違えば方式に知らせずに不具合を記録する。
    pub fn slot(&mut self, s: Slot) {
        self.core.slot_release(&s);
    }
}
