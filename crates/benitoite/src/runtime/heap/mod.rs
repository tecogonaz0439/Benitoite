//! ヒープ（設計書 02-09「メモリの管理」）。
//!
//! 公開の層（value・slot・trace・ctx・build・stats）は `unsafe` を書かず、内部の層（core とその子）の
//! 安全な関数だけを呼ぶ。不変条件 H1〜H11 は実装プランの 10-08「不変条件」で定める。
//! メモリの管理はマーク・スイープ（機能 `gc-mark-sweep`）であり、この層の API の裏に置く
//! （00-01「機能（feature）」）。第 1 段で比べた参照カウントは、第 1 段の締め（R14）が外した。

#[cfg(not(feature = "gc-mark-sweep"))]
compile_error!("enable the feature `gc-mark-sweep`");

pub mod build;
pub mod ctx;
pub mod slot;
pub mod stats;
pub mod trace;
pub mod value;

mod core;

pub use build::{CheckedLen, StrBuf};
pub use ctx::{Heap, NoGcCtx, SlotOps, ValueCtx};
pub use slot::{RootIdx, RootStack, Slot};
pub use stats::{HeapConfig, HeapFault, HeapFaultKind, HeapStats};
pub use trace::{Discard, Discarder, Trace, Tracer};
pub use value::{
    CtorTag, Epoch, FieldsKind, HostData, ObjId, ObjKind, ObjRef, OpaqueData, ResourceId, Value,
};

/// マーク・スイープの回収を要求する確保の量の下限（4 MiB。設計書 02-09「メモリの管理」）。
pub const MIN_COLLECT_TRIGGER_BYTES: u64 = 4_194_304;
/// 回収の閾値の係数 k の値（百分率。k = 1）。第 1 段の測定で 50・100・200 を比べ（R12）、k = 1 を暫定に採った（R14）。
pub const DEFAULT_TRIGGER_FACTOR_PERCENT: u32 = 100;
/// 機能 `heap-verify` の構成で、解放した領域を埋める値（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
pub const POISON_BYTE: u8 = 0xDB;
