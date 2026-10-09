//! 根の保存領域の一つの場所（Slot）と、一時的に値を保つ積み重ね（RootStack）（ADR 0260 の決定 4、ADR 0281）。

use super::trace::{Discard, Discarder, Trace, Tracer};
use super::value::{CtorTag, ObjRef, ResourceId, Value};

/// ヒープの番号（ADR 0281）。`Heap::new` が、プロセスで一つの原子的な計数器から割り当てる。番地から作らない。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub(super) struct HeapNo(pub(super) u32);

/// `Slot` の中身。選択肢は `Value` と同じであり、対象を指す選択肢だけがヒープの番号を持つ。
/// ポインタと番号を同じ選択肢の別の欄にするので、`heap-verify` を無効にした構成では 16 バイトに収まる。
#[derive(Clone, Copy, Debug)]
enum SlotRaw {
    Int(i64),
    Float(f64),
    Byte(u8),
    Bool(bool),
    Char(char),
    Unit,
    Tag(CtorTag),
    Resource(ResourceId),
    EmptyList,
    EmptyMap,
    EmptySet,
    Obj(ObjRef<'static>, HeapNo),
}

/// 区間の外で値を保つ場所。中身は区間の寿命を外した値であり、`runtime::heap` の外からは
/// `NoGcCtx` を通してだけ読み書きできる。既定の値は `Unit`（対象を指さない）。
#[derive(Debug)]
pub struct Slot {
    raw: SlotRaw,
}

#[cfg(not(feature = "heap-verify"))]
const _: () = assert!(std::mem::size_of::<Slot>() == 16);

impl Default for Slot {
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn default() -> Slot {
        Slot { raw: SlotRaw::Unit }
    }
}

impl Slot {
    /// 中身の値と、対象を指すときはそのヒープの番号。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn raw(&self) -> (Value<'static>, Option<HeapNo>) {
        match self.raw {
            SlotRaw::Int(n) => (Value::Int(n), None),
            SlotRaw::Float(x) => (Value::Float(x), None),
            SlotRaw::Byte(b) => (Value::Byte(b), None),
            SlotRaw::Bool(b) => (Value::Bool(b), None),
            SlotRaw::Char(c) => (Value::Char(c), None),
            SlotRaw::Unit => (Value::Unit, None),
            SlotRaw::Tag(t) => (Value::Tag(t), None),
            SlotRaw::Resource(r) => (Value::Resource(r), None),
            SlotRaw::EmptyList => (Value::EmptyList, None),
            SlotRaw::EmptyMap => (Value::EmptyMap, None),
            SlotRaw::EmptySet => (Value::EmptySet, None),
            SlotRaw::Obj(r, heap) => (Value::Obj(r), Some(heap)),
        }
    }

    /// 中身を `raw` にする。`heap` は、`raw` が対象を指すときに書くヒープの番号である。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub(super) fn set_raw(&mut self, raw: Value<'static>, heap: HeapNo) {
        self.raw = match raw {
            Value::Int(n) => SlotRaw::Int(n),
            Value::Float(x) => SlotRaw::Float(x),
            Value::Byte(b) => SlotRaw::Byte(b),
            Value::Bool(b) => SlotRaw::Bool(b),
            Value::Char(c) => SlotRaw::Char(c),
            Value::Unit => SlotRaw::Unit,
            Value::Tag(t) => SlotRaw::Tag(t),
            Value::Resource(r) => SlotRaw::Resource(r),
            Value::EmptyList => SlotRaw::EmptyList,
            Value::EmptyMap => SlotRaw::EmptyMap,
            Value::EmptySet => SlotRaw::EmptySet,
            Value::Obj(r) => SlotRaw::Obj(r, heap),
        };
    }

    /// 対象を指していないか（即値か `Unit`）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn is_immediate(&self) -> bool {
        !matches!(self.raw, SlotRaw::Obj(..))
    }
}

/// `RootStack` の中の位置。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct RootIdx(pub u32);

/// 安全点をまたいで一時的に値を保つ積み重ね。VM の根の一つとして `Trace` で訪れる。
#[derive(Debug, Default)]
pub struct RootStack {
    slots: Vec<Slot>,
}

impl Trace for RootStack {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slots(&self.slots);
    }
}

impl Discard for RootStack {
    fn discard(self, d: &mut Discarder<'_>) {
        self.slots.discard(d);
    }
}

use super::ctx::NoGcCtx;

impl RootStack {
    pub fn new() -> RootStack {
        RootStack::default()
    }
    pub fn len(&self) -> u32 {
        u32::try_from(self.slots.len()).unwrap_or(u32::MAX)
    }
    pub fn is_empty(&self) -> bool {
        self.slots.is_empty()
    }
    /// 値を積み、その位置を返す。
    /// 長さが u32::MAX なら積まず、無効な位置 u32::MAX を返してヒープの不具合を記録する。
    pub fn push<'e>(&mut self, ctx: &NoGcCtx<'e>, v: Value<'e>) -> RootIdx {
        let Ok(len) = u32::try_from(self.slots.len()) else {
            ctx.root_overflow();
            return RootIdx(u32::MAX);
        };
        if len == u32::MAX {
            ctx.root_overflow();
            return RootIdx(u32::MAX);
        }
        self.slots.push(ctx.new_slot(v));
        RootIdx(len)
    }
    pub fn get<'e>(&self, ctx: &NoGcCtx<'e>, idx: RootIdx) -> Option<Value<'e>> {
        let idx = usize::try_from(idx.0).ok()?;
        self.slots.get(idx).map(|slot| ctx.load(slot))
    }
    /// 長さを `len` まで縮め、除いた場所を `NoGcCtx::clear` で空にする。
    pub fn truncate<'e>(&mut self, ctx: &NoGcCtx<'e>, len: u32) {
        let Ok(len) = usize::try_from(len) else {
            return;
        };
        for slot in self.slots.iter_mut().skip(len) {
            ctx.clear(slot);
        }
        self.slots.truncate(len);
    }
}
