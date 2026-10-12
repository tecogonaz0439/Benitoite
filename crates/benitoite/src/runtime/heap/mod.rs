//! ヒープ（設計書 02-09「メモリの管理」）。
//!
//! 公開の層（value・slot・trace・ctx・build・stats）は `unsafe` を書かず、内部の層（core とその子）の
//! 安全な関数だけを呼ぶ。不変条件は下の一覧の H1〜H12 である。
//! メモリの管理はマーク・スイープ（機能 `gc-mark-sweep`）であり、この層の API の裏に置く。
//!
//! H1: 区間内では対象を解放せず動かさない。値と中身への参照は区間の終わりまで正しい対象を指す。
//!   内部の層が守り、解放は安全点の `Heap::collect` の中だけで行う。
//! H2: 回収は区間の外だけで行い、`NoGcCtx` は回収の機能を持たない。
//!   型が守る。回収は `&mut Heap` を取り、区間は `&mut Heap` を借りる。
//! H3: 区間の外で値を保つのは `Slot` だけであり、`Value<'e>` は区間の外へ出せない。
//!   型が守る。`'e` は閉包ごとに新しい不変の寿命である。
//! H4: 回収後に使う `Slot` はすべて根か、根から辿れる対象の中にある。
//!   VM とランタイムの安全点の手順が守り、根に入れなかった `Slot` を回収後に読まない。
//! H5: `Trace` は、値が持つすべての `Slot` と `Trace` を実装する子を訪れる。
//!   `Trace` を実装する側が守る。
//! H6: 対象を指す参照の開始と終了を内部の層が回収方式に知らせ、通知の境目を障壁の位置として保つ。
//!   根・`Host` の `Slot`、値の並びとセルの中の値が対象であり、区間内の値の写しは参照に数えない。
//!   内部の層が守る。
//! H7: 中身を書き換える公開の関数は `cell_set`・`host_mut`・`reuse_ctor` だけであり、障壁の位置を兼ねる。
//!   公開の層と借用の規則が守り、`&self` で中身を借りる対象は `&mut self` を取る関数だけで書き換える。
//! H8: `Value<'e>` と `Slot` は `Send` でも `Sync` でもなく、作業用のスレッドへ渡せない。
//!   `NonNull` を含む型が守る。
//! H9: 一つのヒープの対象を指す値を別のヒープの区間で使わない。区間内の値は別々の寿命で区別する。
//!   型と実行時の検査が守り、`Slot` はヒープの番号を持ち、読むたびに照合する。
//! H10: `unsafe` は内部の層だけに書き、公開の層の関数を `unsafe fn` にしない。規約と lint が守る。
//! H11: `discard` が参照の終了を知らせるのは、捨てる値が所有する `Slot` だけである。
//!   型が守る。`Discard` は値を消費し、`Discarder::slot` は `Clone` のない `Slot` を値で受け取る。
//! H12: 文字列の対象の中身は、確保の時点から正しい UTF-8 である。
//!   型と内部の層が守る。`Str` の中身を書くのは `alloc_str`（`&str` を写す）と `alloc_str_parts`（`&str` の部分を写す）だけで、どちらも `&str` しか受け取らない。

//! 安全の範囲: 公開の層に `unsafe fn` はないが、公開の層の API は無条件に安全（sound）ではない
//! （設計書 02-09「メモリの管理」）。H4 と H5 は呼び出す側が守る契約であり、根に入れず、
//! 根から辿れる対象の中にもない `Slot`（`Trace` が訪れなかった `Slot` を含む）を回収の後に読むと、
//! `NoGcCtx::load` などの安全な関数だけで、解放した対象を読む（解放後の使用）。
//! 機能 `heap-verify` の構成は確保の世代の照合でこれを見つけ、不具合（`HeapFaultKind::StaleReference`）を
//! 記録して `Value::Unit` を返す。既定の構成（`gc-mark-sweep` だけ）は見つけない。
//! H9 のヒープの番号の照合は別のヒープの `Slot` を拒むが、同じヒープの古い `Slot` は拒まない。

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
/// 回収の閾値の係数 k の値（百分率。k = 1。設計書 02-09「メモリの管理」）。
pub const DEFAULT_TRIGGER_FACTOR_PERCENT: u32 = 100;
/// 機能 `heap-verify` の構成で、解放した領域を埋める値（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
pub const POISON_BYTE: u8 = 0xDB;
