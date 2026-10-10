# 値とヒープ

本章は、16 バイトの値、ヒープの対象の種類、確保器の公開の API、回収しない区間の型（`Value<'epoch>`・`NoGcCtx<'epoch>`）、根の保存領域、メモリの管理の方式によらない API、回収の要求、書き込みの障壁の位置、`Reference` のセルの対象、確かめ方の口、止まる理由の型とシグネチャを定める。設計書の対応する章は[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」と[ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「メモリの管理」「一つの操作で作る値の大きさの上限」、[処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md)の「ヒープとランタイムの確かめ方（初回リリース版）」であり、判断の根拠は [ADR 0258](../../2026-10-09-design-first-release/decisions/0258-sixteen-byte-value-enum.md)〜[ADR 0260](../../2026-10-09-design-first-release/decisions/0260-heap-and-unsafe-boundary.md)、[ADR 0267](../../2026-10-09-design-first-release/decisions/0267-lazy-and-reference-objects.md)、[ADR 0271](../../2026-10-09-design-first-release/decisions/0271-self-made-gc-as-exception.md) である。

- 置く作業: C01

本章のコードは、`task=C02` を付けたもの（`Decimal` の対象の関数と、マップと集合）を除いて C01 が置く（U2 第 1 段の章）。中身を書く作業は、各コードブロックの前に示す。

## 本章の読み方

本章は、`runtime::heap` の公開の層だけを凍結する。内部の層（確保器、対象の頭の配置、根の列挙、マーク・スイープのマークと掃き出し）の型と関数は、作業が決める。ただし、内部の層が守る不変条件は本章の「不変条件」で定め、作業はそれを変えない。

内部の層の型のうち、公開の層の型の欄に現れるもの（`HeapCore`・`ObjHeader`・`TraceSink`）は、名前だけを `sig=` の中で凍結する。`sig=` に中身のない本体（`{}`）で書いた構造体とトレイトは、作業が欄とメソッドを決めてよい。名前と可視性は変えない。

## 不変条件

`runtime::heap` は、次の不変条件を守る。内部の層の各ファイルの先頭の `//!` のコメントは、そのファイルが関わる項目を番号で挙げ、`// SAFETY:` のコメントはこの番号を引く（[実装の規約](../00-common/00-02-conventions.md)の「`unsafe` の書き方」）。

| 番号 | 不変条件 | 守る側 |
|---|---|---|
| H1 | 区間（`Heap::epoch` の閉包の実行）の中では、どの対象も解放せず、動かさない。したがって、区間の中で得た `Value<'e>` と、`&self` の借用で得た中身への参照（`&str` など）は、区間の終わりまで正しい対象を指す | 内部の層。解放は安全点の `Heap::collect` の中でだけ行う |
| H2 | 回収（`Heap::collect`）は区間の外でだけ起きる。`NoGcCtx` は回収の機能を持たない | 型。`Heap::collect` は `&mut Heap` を取り、区間は `&mut Heap` を借りている |
| H3 | 区間の外で値を保つのは `Slot` だけである。`Value<'e>` は区間の外へ出せない | 型（`'e` は閉包ごとに新しい、不変の寿命）。コンパイルの失敗のテストで確かめる |
| H4 | 回収のとき、この先使う `Slot` はすべて、`Heap::collect` に渡した根（`&dyn Trace`）か、根から辿れる対象の中にある。根に入れずに Rust の局所変数や構造体に残した `Slot` を、回収の後に読まない | VM とランタイム（安全点の手順）の契約。回収の強制、確保の世代の検査、ヒープの検証器で確かめる |
| H5 | `Trace` の実装は、その値が持つ `Slot` と、`Trace` を実装する子をすべて訪れる | `Trace` を実装する側の契約。H4 と同じ手段で確かめる |
| H6 | 対象を指す参照（根と `Host` の対象の中の `Slot`、値の並びとセルの中の値）の開始と終了を、内部の層は回収の方式に知らせる。区間の中の `Value<'e>` の写しは参照に数えない。この通知の境目は、書き込みの障壁を加える位置として残す（ADR 0259 の決定 7）。第 1 段の参照カウントは、この通知で数を増減した | 内部の層 |
| H7 | 対象の中身を書き換える公開の関数は、`NoGcCtx::cell_set`・`NoGcCtx::host_mut`・`NoGcCtx::reuse_ctor` だけである。これらが書き込みの障壁を差し込む位置になる（ADR 0259 の決定 7）。`&self` で中身への参照を返す関数（`ValueCtx::str` など）の対象は、`&mut self` を取る関数のほかでは書き換えない | 公開の層（借用の規則が一部を守る） |
| H8 | `Value<'e>` と `Slot` は `Send` でも `Sync` でもない。作業用のスレッドへ渡せない | 型（`NonNull` を含む） |
| H9 | 一つの `Heap` の対象を指す値を、別の `Heap` の区間で使わない | 区間の中は型（別の区間の `'e` は別の寿命）。`Slot` は、ヒープの番号（`HeapNo`）を持ち、読むたびに比べる（すべての構成。[ADR 0281](../../2026-10-09-design-first-release/decisions/0281-heap-number-in-slot-and-contract-safety.md)） |
| H10 | `unsafe` は `runtime::heap` の内部の層のファイルにだけ書く。公開の層の関数は `unsafe fn` にしない | 規約と lint |
| H11 | `NoGcCtx::discard` が参照の終了を方式に知らせるのは、捨てる値が所有していた `Slot` についてだけである | 型。`Discard` は値を消費し、`Discarder::slot` は `Slot` を値で受け取る。`Slot` は `Clone` を持たないので、借用した `Slot` を手放せない |

### 安全と言える範囲

公開の層の API は、VM とランタイムが次の二つの契約を守るかぎりにおいて安全である（[ADR 0260](../../2026-10-09-design-first-release/decisions/0260-heap-and-unsafe-boundary.md) の決定 4、ADR 0281）。契約を破ると、安全な関数だけで解放した対象を読みうるので、本章の API を無条件に健全な（sound な）API とは呼ばない。

1. 回収のとき、この先使う `Slot` をすべて根として列挙する（H4・H5）。
2. 列挙しなかった `Slot`（その対象が回収で解放されうるもの）を、回収の後に読まない。

たとえば、同じヒープで `Slot` を根に入れずに `Heap::collect` を呼び、次の区間でその `Slot` を `NoGcCtx::load` で読むと、解放した対象を指す値が得られる。別のヒープの `Slot` を読む誤りは、ヒープの番号の比較がすべての構成で見つける。

不変条件ごとの守り方は次のとおりである。

| 守り方 | 不変条件 | 働く構成 |
|---|---|---|
| 型 | H2、H3（ヒープを指す値を区間の外へ出さないこと）、H8、H9 のうち区間の中の値、H11 | すべて |
| 実行時の検査（一回の比較） | H9 のうち `Slot`（ヒープの番号）。`reuse_ctor` の再利用の条件（数が 0 であること、引数が候補の対象を指さないこと） | すべて |
| 実行時の検査（重い検査） | H4・H5 の破れの結果（解放した対象を指す `Slot` の読み出しを確保の世代で見つける、検証器の数の食い違いと根から辿れる対象の解放、毒） | 機能 `heap-verify` |
| 内部の層の実装とテスト | H1、H6 | すべて（Miri と検証器で確かめる） |
| 公開の層の規律と借用の規則 | H7 | すべて |
| VM とランタイムの契約とテスト | H4、H5、上の契約 2、`reuse_ctor` の候補の写しをこの後に読まないこと | 回収の強制、`heap-verify`、到達可能性の比較のテストで確かめる |
| 規約と lint | H10 | すべて |

H4 と H5 を VM の契約とし、その範囲を `Slot`・`Trace`・`Discard` の三つの型に限ることは、ADR 0260 の決定 4 と決定 7 による。

## 止まる理由

組み込みの関数、VM の命令、ランタイムが実行を止めるときの理由を `Stop` で表す（[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」）。実行時エラーの種類は[評価意味論](../../2026-10-09-design-first-release/01-spec/01-08-evaluation.md)の「実行時エラーによる停止」の表の初回リリース版の範囲をすべて持つ。サーバモードで加わる権限の拒否は、その版で加える。診断コードと文言は 10-02 が定める。

```rust file=src/runtime/mod.rs
//! ランタイム（設計書 02-09）: 値とヒープ（heap）、リスト（list）、マップと集合（map）、構造の等しさ（equal）、
//! スケジューラ（sched）と IO 実行器（io）、panic 境界（panic）、報告（report）、実行の流れ（run）。
//! 値とヒープとコレクションは 10-08、スケジューラと IO は 10-10、panic 境界と報告と実行の流れは 10-13 が定める。

pub mod equal;
pub mod heap;
pub mod io;
pub mod list;
pub mod map;
pub mod panic;
pub mod report;
pub mod run;
pub mod sched;

use crate::vm::InstrRef;

/// 一つの操作で作る文字列と `Bytes` の大きさの上限（2^30 バイト。02-09、ADR 0049）。
pub const MAX_STRING_BYTES: u64 = 1_073_741_824;
/// 一つの操作で作るリストの長さの上限（2^24 要素）。
pub const MAX_LIST_LEN: u64 = 16_777_216;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Stream {
    Stdout,
    Stderr,
}

/// リソースの型（01-10「リソース管理」、02-09「リソースの追跡」）。解放の失敗の報告に使う。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum ResourceKind {
    FileReader,
    FileWriter,
    HttpListener,
    HttpExchange,
    TaskGroup,
}

/// 解放の失敗一つ（02-09「リソースの追跡」の「解放の失敗」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct ReleaseFailure {
    pub kind: ResourceKind,
    /// リソースを開いた呼び出しの命令。報告の位置は 10-13 がこれから作る
    pub opened_at: Option<InstrRef>,
    /// 失敗の理由（`std::io::Error` の文字列など）
    pub reason: String,
}

/// 実行時エラーの種類（01-08「実行時エラーによる停止」の初回リリース版の範囲）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum RuntimeError {
    IntegerOverflow,
    DecimalOverflow,
    DivisionByZero,
    /// `reason` は `std::io::Error` の文字列
    WriteFailed {
        stream: Stream,
        reason: String,
    },
    /// 集めた解放の失敗（一つ以上）
    ReleaseFailed(Vec<ReleaseFailure>),
    ReleasedResourceUsed {
        kind: ResourceKind,
    },
    ContinuationResumedTwice,
    /// 引き継いだハンドラの節が末尾で再開する節でない（ADR 0151）。`operation` は操作の修飾した名前
    InheritedHandlerClause {
        operation: String,
    },
    /// `function` は関数の修飾した名前、`argument` は 0 から数えた引数の位置
    ArgumentOutOfDomain {
        function: &'static str,
        argument: u16,
    },
    ResponseSentTwice,
    TaskDeadlock,
    /// 取り消したタスクを `Task.await` で待った（01-11「取り消し」、ADR 0317）
    AwaitedTaskCancelled,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SizeUnit {
    Bytes,
    Elements,
}

/// 資源の不足の種類（01-08「資源の不足」のうち処理系が上限を設けるもの）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum ResourceError {
    /// `frames` はそのときの枠の数（二つの `Vec` の両方を数える。02-08「呼び出しの入れ子の上限」）
    CallStackTooDeep { frames: u64 },
    /// `function` は値を作ろうとした関数の修飾した名前、または演算子の記号
    ValueTooLarge {
        function: &'static str,
        size: u64,
        unit: SizeUnit,
        limit: u64,
    },
    /// 読む大きさが決まっていない入力を読む操作が、上限を超えた（02-09「一つの操作で作る値の大きさの上限」、
    /// 02-10「実行時エラーと資源の不足の報告」）。結果の大きさは決まらないので持たない。
    /// `function` は操作の修飾した名前（`Benitoite.IO.File.readText` など）
    InputTooLarge {
        function: &'static str,
        unit: SizeUnit,
        limit: u64,
    },
}

/// 実行を止める理由。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Stop {
    Runtime(RuntimeError),
    Resource(ResourceError),
    /// 処理系の不具合。文字列は調べるための説明（英語）
    Internal(String),
}
```

`runtime::panic` は、最小実行版のもの（`src/legacy/runtime/panic.rs` の `PanicReport`・`install_hook`・`take_report`・`catch`）を名前とシグネチャを変えずに写す（本章の「panic 境界」）。`runtime::report` と `runtime::run` は、パイプラインと CLI の章（10-13）が定め、C02 が置く。`runtime::sched` と `runtime::io` は 10-10 が定める。C01 は、`runtime/mod.rs` の宣言に合わせて、C02 が置くモジュールを中身のないモジュールとして置く（道具が作る）。

## panic 境界

panic 境界（[ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「panic 境界」）の型と関数は、最小実行版のものを変えない。C01 が型とシグネチャを置き、R09 が `src/legacy/runtime/panic.rs` の中身（hook の記録を持つスレッドローカルな記憶域を含む）を写す。移行の間は `legacy` にも同じ記憶域が残る。処理系の hook として設定するのは、CLI が使う側の `install_hook` だけである（C05 が `main.rs` を初回リリース版の CLI に切り替えるまでは、`legacy` の CLI が `legacy` の側を設定する）。

```rust file=src/runtime/panic.rs
//! panic hook と panic 境界（設計書 02-09「panic 境界」）。
//!
//! 既定の hook は標準エラー出力に書くので、出力のバッファより先に診断の形式によらない文が出てしまう。
//! 処理系の hook は何も書かず、panic したスレッドのスレッドローカルな記憶域に内容を記録する。
//! この記録は、大域の状態を持たない規約の例外として 00-02「大域の状態」が認めたものである。

/// panic hook が記録した内容。
#[derive(Clone, PartialEq, Debug)]
pub struct PanicReport {
    pub message: String,
    /// `ファイル:行:列`
    pub location: Option<String>,
    pub backtrace: Option<String>,
}
```

```rust sig=src/runtime/panic.rs
/// 処理系の panic hook を設定する。標準エラー出力に何も書かず、panic したスレッドのスレッドローカルな記憶域に記録する。
/// 処理系を使うプログラム（CLI）が、起動の直後、スレッドを作る前に一度だけ呼ぶ（02-09「panic 境界」）。
pub fn install_hook();

/// このスレッドで記録した panic の内容を取り出す（取り出した後は空になる）。
pub fn take_report() -> Option<PanicReport>;

/// `f` を `catch_unwind` で囲んで呼ぶ。panic を捕らえたら記録を取り出して返す。
pub fn catch<T>(f: impl FnOnce() -> T) -> Result<T, PanicReport>;
```

## ヒープのモジュールの構成

`runtime::heap` のファイルは次のとおりである。

| ファイル | 層 | 内容 | 置く作業 | 中身を書く作業 |
|---|---|---|---|---|
| `src/runtime/heap/mod.rs` | 公開 | 子のモジュール、機能の組み合わせの確かめ、定数 | C01 | — |
| `src/runtime/heap/value.rs` | 公開 | `Value<'e>`、対象を指す値、即値の型 | C01 | — |
| `src/runtime/heap/slot.rs` | 公開 | `Slot`、ヒープの番号（`HeapNo`）、`RootStack` | C01 | R02 |
| `src/runtime/heap/trace.rs` | 公開 | `Trace`、`Tracer`、`Discard`、`Discarder` | C01 | R02 |
| `src/runtime/heap/ctx.rs` | 公開 | `Heap`、`ValueCtx`、`NoGcCtx`、`SlotOps` | C01 | R01・R02・R03・R04（R14 が外した）・R06（関数ごとに下に示す） |
| `src/runtime/heap/build.rs` | 公開 | 大きさを確かめる構築（`CheckedLen`・`StrBuf`） | C01 | — |
| `src/runtime/heap/stats.rs` | 公開 | 設定と測定の記録 | C01 | — |
| `src/runtime/heap/core.rs` | 内部 | 内部の層の入口（`HeapCore`・`ObjHeader`・`TraceSink`） | C01 | R01 |
| `src/runtime/heap/` のほかのファイル | 内部 | 確保器、マーク・スイープ、検証器など | 作業 | R01〜R03、R11（第 1 段の参照カウントは R04 が書き、R14 が外した） |

最小実行版の `runtime`（`heap.rs`・`value.rs` など）は、C04 が `src/legacy/runtime/` へ移すので、本章のファイルは空いたパスに新しく置く。最小実行版の VM・組み込みの関数・参照インタプリタ・パイプラインは `legacy` の中で最小実行版の値とヒープを使い続け、移行の締め（C18）まで動く（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」）。

内部の層のファイル名と分け方は作業が決め、`core.rs` から非公開の子のモジュールとして宣言する（[作業の進め方](../00-common/00-03-workflow.md)の「ブランチと並行作業」）。公開の層の関数のシグネチャと意味は、回収の方式によらない。第 1 段では、マーク・スイープの実装を機能 `gc-mark-sweep`、参照カウントの実装を機能 `gc-refcount` の下に置いて比べ、第 1 段の締め（R14）が `gc-refcount` と参照カウントの実装を消した（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「機能（feature）」）。

```rust file=src/runtime/heap/mod.rs
//! ヒープ（設計書 02-09「メモリの管理」、ADR 0258・0259・0260・0271）。
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

/// マーク・スイープの回収を要求する確保の量の下限（4 MiB。ADR 0259 の決定 6）。
pub const MIN_COLLECT_TRIGGER_BYTES: u64 = 4_194_304;
/// 回収の閾値の係数 k の値（百分率。k = 1）。第 1 段の測定で 50・100・200 を比べ（R12）、k = 1 を暫定に採った（R14）。
pub const DEFAULT_TRIGGER_FACTOR_PERCENT: u32 = 100;
/// 機能 `heap-verify` の構成で、解放した領域を埋める値（ADR 0260 の決定 7）。
pub const POISON_BYTE: u8 = 0xDB;
```

## 値

値は 16 バイトの Rust の列挙型 `Value<'e>` である（ADR 0258）。即値の種類（[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」の表で「ヒープの対象」が「なし」の種類）は値の中に直接持ち、ほかの種類はすべて `Value::Obj` の一つの選択肢で持つ。対象の種類は対象の頭にあり、`ValueCtx::kind` で読む。値の選択肢を種類ごとに分けないのは、種類の区別を対象の頭の一か所に置き、値の選択肢の数を即値の数に抑えるためである。空のリスト・マップ・集合は、対象を持たない即値にする（02-08 の表の「空のリストでは持たない」）。

`'e` は回収しない区間の寿命である（不変条件 H1・H3）。`Epoch<'e>` は `'e` について不変（invariant）な印であり、別の区間の値を互いに渡せないようにする。対象を指す値（`ObjRef<'e>`）は欄を公開せず、`runtime::heap` の外から作れない。

機能 `heap-verify` を有効にした構成では、`ObjRef` に確保の世代を持たせる（ADR 0260 の決定 7）。このとき値は 16 バイトより大きくなってよい。大きさを確かめる定数の表明は、`heap-verify` を無効にした構成に限る。

```rust file=src/runtime/heap/value.rs
//! 値（設計書 02-08「値の表現」、ADR 0258）。値は 16 バイトの列挙型であり、`Send` にしない。

use std::any::Any;
use std::fmt::Debug;
use std::marker::PhantomData;
use std::ptr::NonNull;

use super::core::ObjHeader;
use super::trace::Trace;

/// 回収しない区間の印。`'e` について不変にするため、`fn(&'e ()) -> &'e ()` を持つ。
#[derive(Clone, Copy, Debug)]
pub struct Epoch<'e>(PhantomData<fn(&'e ()) -> &'e ()>);

impl<'e> Epoch<'e> {
    pub(super) fn new() -> Epoch<'e> {
        Epoch(PhantomData)
    }
}

/// 引数のない構成子のタグ。型の宣言の中で 0 から数えた番号である（10-07「コンパイル済みプログラム」）。
/// 構成子の表の位置（10-07 の `CtorIdx`）とは別の値である。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct CtorTag(pub u32);

/// 実行ごとのリソースの表の番号（02-09「リソースの追跡」）。一つの実行の中で使い回さない。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ResourceId(pub u64);

/// ヒープの対象を指す値。区間 `'e` の中でだけ使える。
#[derive(Clone, Copy, Debug)]
pub struct ObjRef<'e> {
    ptr: NonNull<ObjHeader>,
    /// 確保の世代（機能 `heap-verify`）。対象の頭の世代と比べ、解放後の使用を見つける
    #[cfg(feature = "heap-verify")]
    generation: u32,
    epoch: Epoch<'e>,
}

impl<'e> ObjRef<'e> {
    #[cfg(not(feature = "heap-verify"))]
    pub(super) fn from_raw(ptr: NonNull<ObjHeader>) -> ObjRef<'e> {
        ObjRef {
            ptr,
            epoch: Epoch::new(),
        }
    }

    #[cfg(feature = "heap-verify")]
    pub(super) fn from_raw(ptr: NonNull<ObjHeader>, generation: u32) -> ObjRef<'e> {
        ObjRef {
            ptr,
            generation,
            epoch: Epoch::new(),
        }
    }

    pub(super) fn ptr(self) -> NonNull<ObjHeader> {
        self.ptr
    }

    #[cfg(feature = "heap-verify")]
    pub(super) fn generation(self) -> u32 {
        self.generation
    }

    pub(super) fn epoch(self) -> Epoch<'e> {
        self.epoch
    }
}

/// 値（ADR 0258）。`Obj` のほかは即値である。
#[derive(Clone, Copy, Debug)]
pub enum Value<'e> {
    Int(i64),
    Float(f64),
    Byte(u8),
    Bool(bool),
    Char(char),
    Unit,
    /// 引数のない構成子
    Tag(CtorTag),
    Resource(ResourceId),
    EmptyList,
    EmptyMap,
    EmptySet,
    /// ヒープの対象。種類は対象の頭にある（`ValueCtx::kind`）
    Obj(ObjRef<'e>),
}

#[cfg(not(feature = "heap-verify"))]
const _: () = assert!(std::mem::size_of::<Value<'static>>() == 16);

impl<'e> Value<'e> {
    pub fn as_int(self) -> Option<i64> {
        if let Value::Int(n) = self {
            Some(n)
        } else {
            None
        }
    }

    pub fn as_float(self) -> Option<f64> {
        if let Value::Float(x) = self {
            Some(x)
        } else {
            None
        }
    }

    pub fn as_byte(self) -> Option<u8> {
        if let Value::Byte(b) = self {
            Some(b)
        } else {
            None
        }
    }

    pub fn as_bool(self) -> Option<bool> {
        if let Value::Bool(b) = self {
            Some(b)
        } else {
            None
        }
    }

    pub fn as_char(self) -> Option<char> {
        if let Value::Char(c) = self {
            Some(c)
        } else {
            None
        }
    }

    pub fn as_tag(self) -> Option<CtorTag> {
        if let Value::Tag(t) = self {
            Some(t)
        } else {
            None
        }
    }

    pub fn as_resource(self) -> Option<ResourceId> {
        if let Value::Resource(r) = self {
            Some(r)
        } else {
            None
        }
    }

    pub fn as_obj(self) -> Option<ObjRef<'e>> {
        if let Value::Obj(r) = self {
            Some(r)
        } else {
            None
        }
    }
}

/// ヒープの対象の種類（対象の頭に置く。ADR 0258 の決定 2）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum ObjKind {
    /// 文字列。中身は常に正しい UTF-8
    Str,
    Bytes,
    Decimal,
    /// 値の並びを持つ対象（下の `FieldsKind`）
    Fields(FieldsKind),
    /// `Reference` のセル。中身の値と版の番号を持ち、その場で書き換える（ADR 0267 の決定 1）
    Cell,
    /// 組み込みの関数が作った、言語の値を含まない Rust の値（`Regex.Pattern` など。ADR 0168）
    Opaque,
    /// VM とランタイムが定める、言語の値を含む Rust の値（タスク、継続、ハンドラの記録、`Lazy`）
    Host,
}

/// 値の並びを持つ対象の種類。どれも、種類・32 ビットの印（`tag`）・値の並びを持つ。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum FieldsKind {
    /// 構成子を適用した値（レコード、`Pair`・`Triple` を含む）。`tag` は構成子のタグ
    Ctor,
    /// 関数の値。`tag` は原型の番号（10-07 の `ProtoIdx` の値）、並びは捕捉した値
    Func,
    /// 型クラスの辞書。`tag` は実装の番号（10-07 の `ImplIdx` の値）、並びは実装の制約の辞書（ADR 0158）
    Dict,
    /// 連結リストのセル（第 1 段のリストの表現。並びは先頭の要素と残りのリスト、`tag` は長さ）
    ListCell,
    /// 永続ベクタのノードと葉（ADR 0104。`tag` の使い方はリストの表現を作る作業 R36 が決める）
    ListNode,
    /// マップの木のノード（ADR 0103。`tag` の使い方は R37 が決める）
    MapNode,
    /// 集合の木のノード
    SetNode,
    /// `IOError` の値。`tag` は `IOErrorKind` の番号、並びは理由の文字列
    IoError,
    /// `NetworkError` の値。`tag` は `NetworkErrorKind` の番号、並びは理由の文字列
    NetworkError,
}

/// `ObjKind::Opaque` の対象が持つ Rust の値。言語の値（`Slot`）を含めてはならない。
/// 作った後に変更しない（`ValueCtx::opaque` は共有の参照だけを返す）。
pub trait OpaqueData: Any + Debug {}

/// `ObjKind::Host` の対象が持つ Rust の値。持つ `Slot` を `Trace` ですべて訪れる（不変条件 H5）。
/// 書き換えは `NoGcCtx::host_mut` だけで行う（不変条件 H7）。
/// 対象を解放するときに内部の層が Rust の値を `drop` するが、`Drop` の実装でリソースの解放やタスクの取り消しなど
/// 言語の後始末を行ってはならない。後始末は VM が枠を降ろす処理と止める手順で行う（10-08「根の保存領域」）。
pub trait HostData: Trace + Any + Debug {}

/// 対象の識別（テストで到達可能性を独立に計算するために使う。番地から作る）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ObjId(pub u64);
```

## 根の保存領域

区間の外で値を保つ場所が `Slot` である（不変条件 H3・H4）。`Slot` は `Clone` を持たない。`Slot` の読み書きは区間の中で `NoGcCtx`（`host_mut` の中では `SlotOps`）を通して行い、`Slot` を作る・写す・消す操作を、参照の開始と終了を方式に知らせる一か所にする（不変条件 H6）。`Slot` を `NoGcCtx::clear` か `NoGcCtx::discard` を通さずに Rust の `drop` で捨てると、参照の終了が方式に届かない（未定義動作にはならない）。マーク・スイープでは対象の回収に影響しないが、第 1 段の参照カウントでは数が戻らず、ヒープの検証器が数の食い違いとして報告した。

`Slot` は、対象を指すとき、その対象を確保したヒープの番号（`HeapNo`）を持つ（[ADR 0281](../../2026-10-09-design-first-release/decisions/0281-heap-number-in-slot-and-contract-safety.md)）。ヒープの番号は、`Heap::new` が、プロセスで一つの原子的な計数器から順に割り当てる 32 ビットの数であり、番地から作らない。`Slot` を読む・書き換える・辿る公開の層の関数（`NoGcCtx` と `SlotOps` の `Slot` の関数、`Tracer::slot`、`Discarder::slot`）は、`Slot` が対象を指すとき、その番号と操作するヒープの番号をすべての構成で比べる。食い違えば、対象を読まず、数も変えずに、`HeapFault`（`ForeignHeap`）を記録する（読み出しは `Value::Unit` を返す）。VM は安全点で `Heap::take_fault` を呼び、`Stop::Internal` で止まる。

`Slot` の中身は、`Value<'static>` と同じ選択肢を持ち、対象を指す選択肢だけがヒープの番号を持つ列挙型（`SlotRaw`）である。対象へのポインタとヒープの番号を同じ選択肢の別の欄にすると、Rust 1.98.1 では、機能 `heap-verify` を無効にした構成で 16 バイトに収まる（2026-09-30 に確かめた。`Value` の欄にヒープの番号を加えた構造体にすると 24 バイトになる）。大きさは定数の表明で確かめる。値の並びとセルの中の値は、対象と同じヒープにあることが確保の時点で決まるので、内部の層がヒープの番号を持たない形で置いてよい（R01）。

VM のレジスタ、枠が持つ値、根の保存領域はどれも `Slot` で持つ。`RootStack` は、VM が安全点をまたいで一時的に保つ値の置き場（[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「実行ごとの状態のうち VM が使うもの」の根の保存領域）である。

言語のリソースは、リソースの表の番号（`ResourceId`）として持ち、ヒープの対象ではない（[ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「メモリの管理」「リソースの追跡」）。回収と、回収が `Opaque`・`Host` の Rust の値を `drop` することは、リソースの解放もタスクの取り消しも行わない。明示の後始末（解放の枠、取り消し、止める手順）が使う値は、後始末を終えるまで VM が根に置き、後始末の後に `NoGcCtx::discard` か `clear` で手放す。この順序を守る責任は VM にある（R21・R24・R28）。

```rust file=src/runtime/heap/slot.rs
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
    fn default() -> Slot {
        Slot { raw: SlotRaw::Unit }
    }
}

impl Slot {
    /// 中身の値と、対象を指すときはそのヒープの番号。
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
```

次の関数の中身は R02 が書く。

```rust sig=src/runtime/heap/slot.rs
use super::ctx::NoGcCtx;

impl RootStack {
    pub fn new() -> RootStack;
    pub fn len(&self) -> u32;
    pub fn is_empty(&self) -> bool;
    /// 値を積み、その位置を返す。
    pub fn push<'e>(&mut self, ctx: &NoGcCtx<'e>, v: Value<'e>) -> RootIdx;
    pub fn get<'e>(&self, ctx: &NoGcCtx<'e>, idx: RootIdx) -> Option<Value<'e>>;
    /// 長さを `len` まで縮め、除いた場所を `NoGcCtx::clear` で空にする。
    pub fn truncate<'e>(&mut self, ctx: &NoGcCtx<'e>, len: u32);
}
```

## 根と対象を辿る

`Trace` は、値が持つ `Slot` を回収とヒープの検証器に知らせる、読むだけのトレイトである。VM は、根の全体（すべてのタスクの枠とレジスタ、`RootStack`、定数の値の表など）を一つの `Trace` として `Heap::collect` に渡す。`ObjKind::Host` の対象の中身も `Trace` で辿る。`Tracer` の使い方（印を付ける、検証器が数える、解放する `Host` の対象の中の数を減らす）は内部の層が決め、`Trace` を実装する側は区別しない。解放する `Host` の対象に `Trace` を使ってよいのは、内部の層がその Rust の値を丸ごと捨てる直前であり、`HostData` は `'static` なので借用した `Slot` を持てないからである。

`Discard` は、値が所有する `Slot` を値で手放すトレイトであり、`NoGcCtx::discard` と `SlotOps::discard` だけが使う（不変条件 H11）。`Trace` と分けるのは、`Trace` を借用した `Slot` の見え方（`&Slot` を持つ型など）にも実装できるからである。`Trace` で辿って数を減らすと、借用した先の `Slot` が残ったまま数が減り、生きている対象が次の回収で解放されうる。`Discarder::slot` は `Slot` を値で受け取り、`Slot` は `Clone` を持たないので、`Discard` の実装は所有する `Slot` しか手放せない（`std::mem::take` で取り出した `Slot` を手放すと、元の場所は空になるので数と食い違わない）。

`Trace` と `Discard` の実装は、辿った `Slot` の先の対象を辿らない（辿るのは内部の層であり、明示の積み重ねで行う。[実装の規約](../00-common/00-02-conventions.md)の「再帰の深さ」）。

```rust file=src/runtime/heap/trace.rs
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
```

次の関数の中身は R02 が書く。

```rust sig=src/runtime/heap/trace.rs
impl<'t> Tracer<'t> {
    pub(super) fn new(sink: &'t mut dyn TraceSink) -> Tracer<'t>;
    pub fn slot(&mut self, s: &Slot);
    pub fn slots(&mut self, s: &[Slot]);
}

impl<'d> Discarder<'d> {
    pub(super) fn new(core: &'d HeapCore) -> Discarder<'d>;
    /// `s` が対象を指していれば「指さなくなった」（参照の終了）を方式に知らせ、`s` を捨てる。
    /// ヒープの番号が食い違えば方式に知らせずに不具合を記録する。
    pub fn slot(&mut self, s: Slot);
}
```

## 大きさを確かめる構築

値を作る関数は、確保の前に大きさを確かめる（[ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」、ADR 0049、ADR 0261 の決定 4）。`CheckedLen` は、上限を確かめた長さである。文字列を少しずつ作る組み込みの関数は `StrBuf` を使い、追加のたびに上限を確かめる。どちらも、上限を超えたときに `ResourceError::ValueTooLarge` を返す。

```rust file=src/runtime/heap/build.rs
//! 大きさを確かめる構築（設計書 02-09「一つの操作で作る値の大きさの上限」、ADR 0049）。

use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop};

/// 上限を確かめた長さ（文字列と `Bytes` はバイト数、リストは要素の数）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct CheckedLen {
    len: u32,
}

impl CheckedLen {
    /// 文字列と `Bytes` の大きさを確かめる。`function` は報告に使う関数の名前。
    pub fn bytes(len: u64, function: &'static str) -> Result<CheckedLen, Stop> {
        Self::check(len, MAX_STRING_BYTES, SizeUnit::Bytes, function)
    }

    /// リストの長さを確かめる。
    pub fn elements(len: u64, function: &'static str) -> Result<CheckedLen, Stop> {
        Self::check(len, MAX_LIST_LEN, SizeUnit::Elements, function)
    }

    pub fn get(self) -> u32 {
        self.len
    }

    fn check(len: u64, limit: u64, unit: SizeUnit, function: &'static str) -> Result<CheckedLen, Stop> {
        let too_large = Stop::Resource(ResourceError::ValueTooLarge {
            function,
            size: len,
            unit,
            limit,
        });
        if len > limit {
            return Err(too_large);
        }
        match u32::try_from(len) {
            Ok(len) => Ok(CheckedLen { len }),
            Err(_) => Err(too_large),
        }
    }
}

/// 上限を確かめながら文字列を作る場所。`ValueCtx::alloc_str_buf` で文字列の値にする。
#[derive(Debug)]
pub struct StrBuf {
    buf: String,
    function: &'static str,
}

impl StrBuf {
    pub fn new(function: &'static str) -> StrBuf {
        StrBuf {
            buf: String::new(),
            function,
        }
    }

    /// 加えた後の大きさが上限を超えるなら、加えずに資源の不足を返す。
    pub fn push_str(&mut self, s: &str) -> Result<(), Stop> {
        let new_len = u64::try_from(self.buf.len())
            .ok()
            .and_then(|n| n.checked_add(u64::try_from(s.len()).ok()?))
            .unwrap_or(u64::MAX);
        CheckedLen::bytes(new_len, self.function)?;
        self.buf.push_str(s);
        Ok(())
    }

    pub fn push_char(&mut self, c: char) -> Result<(), Stop> {
        let mut tmp = [0u8; 4];
        self.push_str(c.encode_utf8(&mut tmp))
    }

    pub fn as_str(&self) -> &str {
        &self.buf
    }

    pub fn function(&self) -> &'static str {
        self.function
    }

    pub(super) fn into_string(self) -> String {
        self.buf
    }
}
```

## 設定と測定の記録

`HeapConfig` は、実行ごとのヒープの設定である。`HeapStats` は、第 1 段の比較（[ADR 0259](../../2026-10-09-design-first-release/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 3）で記録した項目を持つ。参照カウントだけの項目（`rc_*`・`reuses`）は、第 1 段の締め（R14）が参照カウントを外した後も公開の型を変えないために残し、マーク・スイープでは 0 のままにする。

回収の閾値は、前回の回収からの確保の量 A と、前回の回収で数えた生きている量 L について、`A >= max(trigger_min_bytes, k × L)` とする（k は `trigger_factor_percent` ÷ 100）。A と L には、対象の頭、配置の切り上げ、対象が持つ別の領域の容量（文字列の中身など）を含める（ADR 0259 の決定 6）。k は、第 1 段の測定で比べた 50・100・200 のうち、設計者が 100（k = 1）を暫定に採った（R14、[第 1 段の測定の記録](../../../../tools/bench/results/2026-10-05-stage1-5b300d4-summary.md)）。第 1 段の参照カウントの回収の要求の条件（解放を待つ対象の量と、循環の回収の閾値）は、タグ `stage1-rc-final` の時点の本章と R04 の作業の文書に書いた。

```rust file=src/runtime/heap/stats.rs
//! ヒープの設定と測定の記録（ADR 0259 の決定 3・6、設計書 07-02）。

use super::{DEFAULT_TRIGGER_FACTOR_PERCENT, MIN_COLLECT_TRIGGER_BYTES};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct HeapConfig {
    /// A の下限（既定 4 MiB）
    pub trigger_min_bytes: u64,
    /// 係数 k の百分率（既定 100）
    pub trigger_factor_percent: u32,
    /// 回収の強制。安全点ごとに必ず回収する（機能 `gc-stress` のビルドでは常に真として扱う）
    pub stress: bool,
    /// その場での再利用を行う（既定は真）。偽なら `NoGcCtx::reuse_ctor` がつねに `Ok(None)` を返す。
    /// 再利用の有無を同じプログラムで比べるためにある（ADR 0280 の決定 4）。再利用は参照カウントの方式だけが
    /// 行うので、マーク・スイープでは設定によらず再利用しない
    pub reuse: bool,
}

impl Default for HeapConfig {
    fn default() -> HeapConfig {
        HeapConfig {
            trigger_min_bytes: MIN_COLLECT_TRIGGER_BYTES,
            trigger_factor_percent: DEFAULT_TRIGGER_FACTOR_PERCENT,
            stress: cfg!(feature = "gc-stress"),
            reuse: true,
        }
    }
}

/// 測定の記録。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct HeapStats {
    pub allocations: u64,
    /// 確保した量の合計（頭と切り上げと別の領域を含む）
    pub allocated_bytes: u64,
    /// 最後の回収で数えた生きている量 L
    pub live_bytes: u64,
    /// これまでで最も大きい、確保している量
    pub peak_heap_bytes: u64,
    pub collections: u64,
    /// 回収ごとの停止の時間（ナノ秒）
    pub pause_nanos: Vec<u64>,
    /// 回収で辿った根の `Slot` の数の合計
    pub roots_traced: u64,
    /// 参照の数の増減の回数（第 1 段で比べた参照カウントの項目。マーク・スイープでは 0 のまま）
    pub rc_increments: u64,
    pub rc_decrements: u64,
    /// 最後の使用での移動で省いた増減の回数（参照カウントの項目。マーク・スイープでは 0 のまま）
    pub rc_elided: u64,
    /// その場で再利用した対象の数（`NoGcCtx::reuse_ctor` が `Some` を返した回数。参照カウントの項目で、
    /// マーク・スイープでは 0 のまま）
    pub reuses: u64,
    /// 解放した対象の数。内部の層の解放の関数だけが数える（R01）
    pub frees: u64,
}

/// ヒープの検証器と確保の世代の検査が見つけた不具合の種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum HeapFaultKind {
    /// 解放した対象を指す値を読んだ（世代の食い違い）
    StaleReference,
    /// 別の `Heap` の番号を持つ `Slot` を読んだ・書いた・辿った（すべての構成で調べる。ADR 0281）
    ForeignHeap,
    /// 対象の頭が壊れている
    CorruptHeader,
    /// 参照カウントの数が、辿って数えた数と食い違う（参照カウントの項目。マーク・スイープでは起きない）
    CountMismatch,
    /// 根から辿れる対象が解放されている
    ReachableFreed,
}

/// ヒープの不具合。VM はこれを `Stop::Internal` にして止める。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct HeapFault {
    pub kind: HeapFaultKind,
    /// 調べるための説明（英語）
    pub detail: String,
}
```

## ヒープと区間

`Heap` は実行ごとに一つ作る。`Heap::epoch` が回収しない区間を開き、閉包に `&mut NoGcCtx<'e>` を渡す。`'e` は閉包ごとに新しい寿命であり（`for<'e>`）、閉包の戻り値の型は `'e` を含められない。区間の中の処理は回収の機能を持たず、回収は区間の外で `Heap::collect` だけが行う（不変条件 H1・H2）。

区間の中で使う文脈は、権限ごとに三つに分ける。

| 型 | できること | 使う側 |
|---|---|---|
| `ValueCtx<'e>` | 作った後に変わらない対象（文字列、`Bytes`、`Decimal`、値の並び、中身を見せない値）の確保と読み出し、対象の種類の読み出し | 純粋な組み込みの関数（10-11 の `PureCtx` がこれだけを見せる） |
| `NoGcCtx<'e>` | `ValueCtx` のすべて（`Deref`）に加え、`Slot` の読み書き、セル、`Host` の対象、`CONR` のその場での再利用、回収の要求の知らせ | VM、`State` と IO の組み込みの関数、ランタイム |
| `SlotOps<'a, 'e>` | `Slot` の読み書きだけ | `NoGcCtx::host_mut` の閉包の中 |

`ValueCtx` の確保の関数は `&self` を取る。確保は既にある対象を動かさず書き換えない（不変条件 H1・H7）ので、`&self` で借りた中身への参照（`ValueCtx::str` の `&str` など）を持ったまま、別の対象を確保してよい。

```rust file=src/runtime/heap/ctx.rs
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

    fn deref(&self) -> &ValueCtx<'e> {
        &self.values
    }
}

/// `NoGcCtx::host_mut` の閉包の中で `Slot` を読み書きする文脈。
pub struct SlotOps<'a, 'e> {
    core: &'a HeapCore,
    epoch: Epoch<'e>,
}
```

### 区間と回収（R01・R02・R03）

`Heap::new` と `Heap::epoch` と `NoGcCtx` の `Slot` の関数の中身は R02、`Heap::collect` は R03 が書く（第 1 段では参照カウントの `Heap::collect` を R04 が書き、R14 が外した）。

`Heap::collect` は、根から印を付けて掃き出す。統計の更新と回収の後の検査は、解放をすべて終えた後に行う。機能 `heap-verify` の構成では、回収の前後に `Heap::verify` を行い、見つけた不具合を `take_fault` で返せるように記録する。

第 1 段の参照カウントの `Heap::collect` の手順（遅らせた解放と ADR 0239 の循環の回収の順序）と解放の候補の規則（ADR 0277）は、タグ `stage1-rc-final` の時点の本章に書いた。R33 の判断で参照カウントに戻すときは、その版から戻す。

```rust sig=src/runtime/heap/ctx.rs
use super::slot::Slot;
use super::stats::{HeapConfig, HeapFault, HeapStats};
use super::trace::{Discard, Trace};
use super::value::{ObjId, Value};

impl Heap {
    pub fn new(config: HeapConfig) -> Heap;
    pub fn config(&self) -> HeapConfig;
    /// 回収しない区間を開き、`f` を実行する。
    pub fn epoch<R>(&mut self, f: impl for<'e> FnOnce(&mut NoGcCtx<'e>) -> R) -> R;
    /// 回収の要求が立っているか（`HeapConfig::stress` の構成では常に真）。
    pub fn collect_requested(&self) -> bool;
    /// 安全点で回収する。`roots` は、この先使う `Slot` をすべて辿る（不変条件 H4）。
    pub fn collect(&mut self, roots: &dyn Trace);
    pub fn stats(&self) -> HeapStats;
    /// ヒープの検証器（ADR 0260 の決定 7）。`heap-verify` を無効にした構成では何もせず `Ok` を返す。
    /// すべての対象の頭と、対象と根の `Slot` が指す先を確かめる。
    pub fn verify(&self, roots: &dyn Trace) -> Result<(), HeapFault>;
    /// 区間の中の読み出しや回収の中で記録した不具合を取り出す。VM は安全点ごとに呼ぶ。
    pub fn take_fault(&mut self) -> Option<HeapFault>;
    /// 生きている対象（回収していない対象）の識別をすべて返す。到達可能性を比べるテストで使う。
    pub fn object_ids(&self) -> Vec<ObjId>;
}

impl<'e> NoGcCtx<'e> {
    /// `Slot` の値を読む。区間の終わりまで使える写しを返す（数は変えない）。
    /// すべての構成でヒープの番号を比べ、`heap-verify` の構成ではさらに確保の世代を確かめる。
    /// 食い違えば不具合を記録して `Value::Unit` を返す。
    pub fn load(&self, s: &Slot) -> Value<'e>;
    /// `v` を持つ新しい `Slot` を作る（`v` の参照の開始を方式に知らせる）。
    pub fn new_slot(&self, v: Value<'e>) -> Slot;
    /// `dst` に `v` を書く。前の値の参照の終了と、`v` の参照の開始を方式に知らせる。
    pub fn store(&self, dst: &mut Slot, v: Value<'e>);
    /// `dst` を空（`Unit`）にする。使わなくなったレジスタを根から除くときに使う（02-08「枠を降ろす原因と処理」）。
    pub fn clear(&self, dst: &mut Slot);
    /// `src` の値を `dst` に移し、`src` を空にする。移した値の数は変えない（最後の使用での移動）。
    pub fn move_slot(&self, dst: &mut Slot, src: &mut Slot);
    /// `src` の値を読み、`src` を空にする。最後の使用の読み出しに使う。
    pub fn take(&self, src: &mut Slot) -> Value<'e>;
    /// `x` が所有する `Slot` をすべて手放す（`Discard`。不変条件 H11）。枠や継続の区画を捨てるときに使う。
    pub fn discard<T: Discard>(&self, x: T);
    /// 回収の要求が、前にこの関数を呼んだ後に新しく立ったかを返す（一度だけ真を返す）。
    /// VM は真を受けたら予算を 0 にして遅い経路に入る（ADR 0263 の決定 3）。
    pub fn take_collect_signal(&self) -> bool;
    /// 回収の要求が立っているか。続けて戻る処理と後始末の回収の位置が調べる（ADR 0259 の決定 5）。
    pub fn collect_requested(&self) -> bool;
}
```

### 作った後に変わらない対象（R01・R06）

対象の頭の読み書きと確保は R01、種類ごとの関数は R06 が書く。文字列の値を作る関数は、上限と UTF-8 を確かめる（ADR 0012、ADR 0261 の決定 4）。`&str` から作る関数は UTF-8 を確かめ直さないが、上限は確かめる。

```rust sig=src/runtime/heap/ctx.rs
use super::build::{CheckedLen, StrBuf};
use super::value::{FieldsKind, ObjKind, OpaqueData};
use crate::runtime::Stop;

impl<'e> ValueCtx<'e> {
    /// 対象の種類。即値には `None` を返す。
    pub fn kind(&self, v: Value<'e>) -> Option<ObjKind>;
    /// 二つの値が同じ対象を指すか（即値どうしは `false`）。
    pub fn same_object(&self, a: Value<'e>, b: Value<'e>) -> bool;
    pub fn object_id(&self, v: Value<'e>) -> Option<ObjId>;

    /// 文字列の値を作る。大きさの上限を確かめる。
    pub fn alloc_str(&self, s: &str, function: &'static str) -> Result<Value<'e>, Stop>;
    /// 部分をつないだ文字列の値を作る。合計の大きさを先に確かめ、一度だけ写す。
    pub fn alloc_str_parts(&self, parts: &[&str], function: &'static str) -> Result<Value<'e>, Stop>;
    /// 外部から受け取ったバイト列を文字列の値にする。上限を超えれば `Err(Stop)`、
    /// 正しい UTF-8 でなければ `Ok(None)`（呼び出し側が `IOErrorKind.InvalidUTF8` にする。ADR 0012）。
    pub fn alloc_str_utf8(&self, bytes: &[u8], function: &'static str) -> Result<Option<Value<'e>>, Stop>;
    pub fn alloc_str_buf(&self, buf: StrBuf) -> Result<Value<'e>, Stop>;
    pub fn str(&self, v: Value<'e>) -> Option<&str>;

    pub fn alloc_bytes(&self, bytes: &[u8], function: &'static str) -> Result<Value<'e>, Stop>;
    /// 確かめた長さの `Bytes` を作り、`fill` で中身を書く。
    pub fn alloc_bytes_with(&self, len: CheckedLen, fill: impl FnOnce(&mut [u8])) -> Result<Value<'e>, Stop>;
    pub fn bytes(&self, v: Value<'e>) -> Option<&[u8]>;

    /// 値の並びを持つ対象を作る。並びの長さが u32 に収まらなければ `Stop::Internal`。
    pub fn alloc_fields(&self, kind: FieldsKind, tag: u32, items: &[Value<'e>]) -> Result<Value<'e>, Stop>;
    /// 値の並びを持つ対象の種類と `tag`。それ以外の値には `None`。
    pub fn fields_header(&self, v: Value<'e>) -> Option<(FieldsKind, u32)>;
    pub fn fields_len(&self, v: Value<'e>) -> Option<u32>;
    /// `i` 番目の値の写し。範囲の外なら `None`。
    pub fn field(&self, v: Value<'e>, i: u32) -> Option<Value<'e>>;

    pub fn alloc_opaque<T: OpaqueData>(&self, data: T) -> Value<'e>;
    pub fn opaque<T: OpaqueData>(&self, v: Value<'e>) -> Option<&T>;
}
```

`Decimal` の値の表現（`crate::base::Decimal`）は 10-01 が C02 で置くので、`Decimal` の対象の関数は `task=C02` として足す。第 1 段は `Decimal` を使わない。中身は、`Decimal` の命令を VM に加える R35 が書く。`Decimal` の定数は、10-07 の定数の記述 `ConstDesc::Decimal { mantissa: i128, scale: u8 }` で渡る。VM は `LOADK` で `base::Decimal::new` により値の表現に戻し、`alloc_decimal` で対象を作る（10-07「定数の記述」）。

```rust sig=src/runtime/heap/ctx.rs task=C02 needs=10-01
use crate::base::Decimal;

impl<'e> ValueCtx<'e> {
    pub fn alloc_decimal(&self, d: Decimal) -> Value<'e>;
    pub fn decimal(&self, v: Value<'e>) -> Option<Decimal>;
}
```

### セルと `Host` の対象（R02・R06）

`Reference` のセルは、中身の値と版の番号を持つヒープの対象であり、その場で書き換える（[ADR 0267](../../2026-10-09-design-first-release/decisions/0267-lazy-and-reference-objects.md) の決定 1）。`cell_set` は版の番号を一つ増やす。`UPDATE` の手順（版の番号の比較とやり直し）は VM が `cell_version` と `cell_set` で行う（[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「可変のセル」）。第 1 段の参照カウントでは、`alloc_cell` がセルを ADR 0239 の生きているセルの表に加えた。

タスク、継続、ハンドラの記録、`Lazy` の対象は、VM が型を定める `Host` の対象である（10-09）。読み出しは `host`、書き換えは `host_mut` だけで行う。`host_mut` は、タスクの結果の書き込み、継続の状態の変更、`Lazy` の結果の書き込みの障壁の位置を兼ねる（不変条件 H7、ADR 0259 の決定 7）。`host_mut` の閉包は `SlotOps` だけを受け取り、ほかの対象を読めない。ほかの対象を読むと、書き換え中の対象と別名になりうるからである。

セルと `Host` の関数は R02 が書く（第 1 段では、`alloc_cell` の生きているセルの表への登録を R04 が書いた）。

```rust sig=src/runtime/heap/ctx.rs
use super::value::HostData;

impl<'e> NoGcCtx<'e> {
    pub fn alloc_cell(&self, v: Value<'e>) -> Value<'e>;
    /// セルの中身。セルでなければ `None`。
    pub fn cell_get(&self, cell: Value<'e>) -> Option<Value<'e>>;
    pub fn cell_version(&self, cell: Value<'e>) -> Option<u64>;
    /// セルに書き、版の番号を一つ増やす。書き込みの障壁の位置。セルでなければ `Stop::Internal`。
    pub fn cell_set(&self, cell: Value<'e>, v: Value<'e>) -> Result<(), Stop>;

    pub fn alloc_host<T: HostData>(&self, data: T) -> Value<'e>;
    pub fn host<T: HostData>(&self, v: Value<'e>) -> Option<&T>;
    /// `Host` の対象を書き換える。書き込みの障壁の位置。型が違えば `None`。
    pub fn host_mut<T: HostData, R>(
        &mut self,
        v: Value<'e>,
        f: impl FnOnce(&mut T, &SlotOps<'_, 'e>) -> R,
    ) -> Option<R>;
}

impl<'a, 'e> SlotOps<'a, 'e> {
    pub fn load(&self, s: &Slot) -> Value<'e>;
    pub fn new_slot(&self, v: Value<'e>) -> Slot;
    pub fn store(&self, dst: &mut Slot, v: Value<'e>);
    pub fn clear(&self, dst: &mut Slot);
    pub fn move_slot(&self, dst: &mut Slot, src: &mut Slot);
    pub fn take(&self, src: &mut Slot) -> Value<'e>;
    pub fn discard<T: Discard>(&self, x: T);
}
```

### その場での再利用（R04）

参照カウントの方式の、どの `Slot` からも指されない対象のその場での再利用（ADR 0259 の決定 1）の口である。第 1 段の締め（R14）が参照カウントを外した後も、公開の型と命令の集合を変えないために残し、マーク・スイープでは手順 1 の確かめの後に常に `Ok(None)` を返す（[ADR 0280](../../2026-10-09-design-first-release/decisions/0280-reuse-by-dedicated-construct-instruction.md) の帰結）。手順 3・4 と呼び出し側の契約は、参照カウントの方式で再利用するときの規則として残す。R16 の後の VM はこの口を使わない（[ADR 0314](../../2026-10-09-design-first-release/decisions/0314-clear-dead-registers-at-safepoints.md)）。参照カウントの VM でこの口を使った命令は、10-07 の `CONR` だけである（[ADR 0280](../../2026-10-09-design-first-release/decisions/0280-reuse-by-dedicated-construct-instruction.md)、10-07「その場での再利用の命令」）。一意であることの判定と書き換えを一つの関数 `reuse_ctor` に閉じ、判定した後に対象を別の場所へ公開してから書き換える順序を、公開の API で作れないようにする。

`reuse_ctor(candidate, tag, args)` は、次の順に行う。

1. `candidate` が `FieldsKind::Ctor` の対象で、並びの長さが `args` の長さと等しいことを確かめる。そうでなければ、何も書き換えずに `Stop::Internal` を返す（ADR 0280 の決定 3。どの方式でも同じ）。
2. マーク・スイープの方式、`HeapConfig::reuse` が偽の設定、`candidate` の対象の数が 0 でないときは、何も書き換えずに `Ok(None)` を返す。
3. `args` のどれかが `candidate` と同じ対象を指せば、何も書き換えずに `Stop::Internal` を返す。数が 0 の対象を指す引数は、数えられない写しから来ている（呼び出し側の契約違反）からであり、そのまま書くと `Slot` を通らない循環ができる。
4. 対象の `tag` を `tag` に、並びの各値を `args` に書き換え（前の値の数を一つ減らし、新しい値の数を一つ増やす。`NoGcCtx::store` と同じ）、`reuses` を一つ増やし、同じ対象を指す値を `Ok(Some(_))` で返す。

呼び出し側は、次の二つを守る。

- 一意であることの判定は、候補のほかの引数の参照がまだ数えられている間に行う。参照カウントの VM は、候補のレジスタを `take` で空にした後、引数のレジスタを `load` で読み（移さない）、`reuse_ctor` を呼んでから、最後の使用の引数のレジスタを空にする。引数を先に移すと、別のレジスタが同じ対象を指していた場合に数が 0 になり、自分自身を指す対象を作りうる。
- 区間の中の `Value<'e>` の写しは数えない（不変条件 H6）ので、`candidate` の写しを、`reuse_ctor` が `Some` を返した後に書き換える前の値として読まない。VM がこの口を使えるのは、10-07 の生存の情報が「この命令でこのレジスタを最後に使い、同じ命令のほかの被演算子に同じレジスタがない」と示した値に限る。

```rust sig=src/runtime/heap/ctx.rs
impl<'e> NoGcCtx<'e> {
    /// `CONR` のその場での再利用（上の手順 1〜4）。再利用したら同じ対象を指す値を、しなければ `None` を返す。
    pub fn reuse_ctor(&mut self, candidate: Value<'e>, tag: u32, args: &[Value<'e>]) -> Result<Option<Value<'e>>, Stop>;
}
```

## 内部の層の入口

`core.rs` は内部の層の入口であり、`unsafe` を書いてよい（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「`unsafe` を書いてよいモジュール」）。下の三つの名前は公開の層の型の欄に現れるので凍結する。欄と中身、ほかの内部の型、子のモジュールは R01 が決める。

```rust file=src/runtime/heap/core.rs
//! ヒープの内部の層の入口（ADR 0260）。確保器、対象の頭、根の列挙、マーク・スイープの実装を子のモジュールに置く。
//! 守る不変条件: 実装プランの 10-08「不変条件」の H1〜H11。子のモジュールは、関わる項目を先頭の `//!` に挙げる。
// 内部の層は生のポインタで対象を読み書きする（ADR 0260 の決定 1・2）。`unsafe` のブロックは操作を一つだけ含め、
// `// SAFETY:` のコメントで不変条件の番号を引く（00-02「`unsafe` の書き方」）。
#![allow(unsafe_code)]
```

```rust sig=src/runtime/heap/core.rs
use super::slot::Slot;

/// ヒープの状態（ヒープの番号、確保器、回収の要求、測定の記録、方式ごとの状態）。区間の中で `&HeapCore` から
/// 確保するので、変わる欄は内部の可変性（`Cell` など）で持つ。欄は R01 が決める。
pub(super) struct HeapCore {}

/// 対象の頭。種類、長さ、印（マーク・スイープ）、
/// `heap-verify` の構成では確保の世代を持つ。欄は R01 が決める。
pub(super) struct ObjHeader {}

/// `Tracer` が `Slot` を知らせる相手（印付け、検証器の数え上げ）。メソッドは R01・R02 が決める。
pub(super) trait TraceSink {
    fn visit(&mut self, s: &Slot);
}
```

## リスト

リストの値は、`Value::EmptyList` か、`FieldsKind` がリストの種類の対象を指す値である。組み込みの関数と VM は、リストの表現を下の関数だけで扱い、表現を直接読まない。第 1 段は連結リストのセル（`FieldsKind::ListCell`）で表す。永続ベクタ（[標準ライブラリ](../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「List の内部の表現」、ADR 0104）には、第 1 段の後に R36 が移す。移すときも、下の関数のシグネチャは変えない。第 1 段で表現を変えないのは、メモリの管理の比較の途中で永続ベクタの変更を混ぜないためである（ADR 0268 の決定 4）。

長さの上限を超えるリストを作る関数は、作る前に `ResourceError::ValueTooLarge` を返す。どの関数も、Rust の再帰を使わずに辿る。

次の関数の中身は R06 が書く。

```rust sig=src/runtime/list.rs
//! リストの値（設計書 03-06「List の内部の表現」、02-08「値の表現」）。

use crate::runtime::Stop;
use crate::runtime::heap::{ValueCtx, Value};

/// 並びの順のリストを作る。
pub fn from_values<'e>(ctx: &ValueCtx<'e>, items: &[Value<'e>], function: &'static str) -> Result<Value<'e>, Stop>;
/// 長さ。リストでなければ `Stop::Internal`。
pub fn len<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<u32, Stop>;
/// 位置 `i` の要素。範囲の外なら `None`。
pub fn get<'e>(ctx: &ValueCtx<'e>, list: Value<'e>, i: u32) -> Result<Option<Value<'e>>, Stop>;
/// 先頭の要素を除いたリスト。空なら `None`。
pub fn tail<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<Option<Value<'e>>, Stop>;
pub fn prepend<'e>(ctx: &ValueCtx<'e>, list: Value<'e>, x: Value<'e>, function: &'static str) -> Result<Value<'e>, Stop>;
pub fn append<'e>(ctx: &ValueCtx<'e>, list: Value<'e>, x: Value<'e>, function: &'static str) -> Result<Value<'e>, Stop>;
pub fn concat<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>, function: &'static str) -> Result<Value<'e>, Stop>;
/// 位置 `start` 以上 `end` 未満の要素のリスト（`start` と `end` は長さの中に切り詰める）。
pub fn slice<'e>(ctx: &ValueCtx<'e>, list: Value<'e>, start: u32, end: u32) -> Result<Value<'e>, Stop>;
/// 要素を先頭から順に並べた `Vec`。
pub fn to_vec<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<Vec<Value<'e>>, Stop>;
```

## マップと集合

マップと集合の値は、`Value::EmptyMap`・`Value::EmptySet` か、`FieldsKind::MapNode`・`SetNode` の対象を指す値である。表現は、重みで平衡させる二分木であり、ノードは作った後に変更せず、更新は根から変わるノードまでの道筋だけを写す（[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」、[標準ライブラリ](../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「Map と Set（初回リリース版）」、ADR 0103）。平衡の条件は、重みを「部分木の要素の数 + 1」とし、(Δ, Γ) = (3, 2) とする（R37 が決めた）。どのノードでも `Δ × weight(左) ≥ weight(右)` と `Δ × weight(右) ≥ weight(左)` が成り立ち、崩れたときは、重い側の子の内側の重みが `Γ × 外側の重み` より小さければ一重の回転、そうでなければ二重の回転にする。`MapNode` の欄は（鍵、値、左、右）、`SetNode` の欄は（要素、左、右）、`tag` は部分木の要素の数、空の子は `Value::EmptyMap`・`Value::EmptySet` である。組み込みの関数（U3 の `Map`・`Set` のモジュール）と VM（`LOADK` の `ConstDesc::Map`・`Set`、`EQV`）は、表現を下の関数だけで扱う。どの関数も、Rust の再帰を使わずに辿る。

鍵の順序と鍵の等しさは、01-06「鍵の型（初回リリース版）」と 03-06 の同節のとおりとする（`Decimal` は数の等しさで比べ、同じ鍵を加えるときは元の鍵を保つ）。第 1 段はマップと集合を使わないので、本節は `task=C02` として足し、中身は R37 が書く。

```rust sig=src/runtime/map.rs task=C02
//! マップと集合の値（設計書 03-06「Map と Set（初回リリース版）」、02-08「値の表現」、ADR 0103）。

use std::cmp::Ordering;

use crate::runtime::Stop;
use crate::runtime::heap::{ValueCtx, Value};

/// 二つの鍵を鍵の順序で比べる。鍵の型でない値に出会ったら `Stop::Internal`。
pub fn compare_keys<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>) -> Result<Ordering, Stop>;

/// 鍵の順に並べた、同じ鍵を含まない組の並びからマップを作る（定数の記述から作るとき）。
pub fn map_from_sorted<'e>(ctx: &ValueCtx<'e>, pairs: &[(Value<'e>, Value<'e>)], function: &'static str) -> Result<Value<'e>, Stop>;
/// 組の数。マップでなければ `Stop::Internal`。
pub fn map_len<'e>(ctx: &ValueCtx<'e>, map: Value<'e>) -> Result<u32, Stop>;
pub fn map_get<'e>(ctx: &ValueCtx<'e>, map: Value<'e>, key: Value<'e>) -> Result<Option<Value<'e>>, Stop>;
/// `key` の値を `value` にしたマップ。`key` が既にあれば元の鍵を保つ。
pub fn map_insert<'e>(ctx: &ValueCtx<'e>, map: Value<'e>, key: Value<'e>, value: Value<'e>, function: &'static str) -> Result<Value<'e>, Stop>;
pub fn map_remove<'e>(ctx: &ValueCtx<'e>, map: Value<'e>, key: Value<'e>) -> Result<Value<'e>, Stop>;
/// 鍵の順に並べた組。
pub fn map_to_vec<'e>(ctx: &ValueCtx<'e>, map: Value<'e>) -> Result<Vec<(Value<'e>, Value<'e>)>, Stop>;

/// 鍵の順に並べた、同じ要素を含まない並びから集合を作る（定数の記述から作るとき）。
pub fn set_from_sorted<'e>(ctx: &ValueCtx<'e>, items: &[Value<'e>], function: &'static str) -> Result<Value<'e>, Stop>;
pub fn set_len<'e>(ctx: &ValueCtx<'e>, set: Value<'e>) -> Result<u32, Stop>;
pub fn set_contains<'e>(ctx: &ValueCtx<'e>, set: Value<'e>, x: Value<'e>) -> Result<bool, Stop>;
/// `x` を加えた集合。同じ要素が既にあれば元の要素を保つ。
pub fn set_insert<'e>(ctx: &ValueCtx<'e>, set: Value<'e>, x: Value<'e>, function: &'static str) -> Result<Value<'e>, Stop>;
pub fn set_remove<'e>(ctx: &ValueCtx<'e>, set: Value<'e>, x: Value<'e>) -> Result<Value<'e>, Stop>;
pub fn set_union<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>, function: &'static str) -> Result<Value<'e>, Stop>;
pub fn set_intersection<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>) -> Result<Value<'e>, Stop>;
pub fn set_difference<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>) -> Result<Value<'e>, Stop>;
/// 鍵の順に並べた要素。
pub fn set_to_vec<'e>(ctx: &ValueCtx<'e>, set: Value<'e>) -> Result<Vec<Value<'e>>, Stop>;
```

## 構造の等しさ

構造の `=`（`EQV`、01-06「等値の型」）は、Rust の再帰を使わず、明示の積み重ねで辿る（02-08「組み込みの関数の呼び出し」）。VM の命令と組み込みの関数（`List.contains` など）の両方がこの関数を使う。中身は R06 が書く。

```rust sig=src/runtime/equal.rs
//! 構造の等しさ（設計書 01-06「等値の型」、02-08）。

use crate::runtime::Stop;
use crate::runtime::heap::{ValueCtx, Value};

/// 二つの値が構造として等しいか。`Float` の成分は IEEE 754 で比べる。値の並びを持つ対象は、種類と `tag` と
/// 各要素で比べる。リストは要素の並びで比べる（表現の形では比べない）。関数の値、セル、`Host`・`Opaque` の対象、
/// `IOError`・`NetworkError` に出会ったら `Stop::Internal` を返す（型検査を通ったプログラムでは起きない）。
pub fn values_equal<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>) -> Result<bool, Stop>;
```

## コード生成から受け取る生存の情報

生存の情報の型は 10-07 の `crate::bytecode::liveness::LiveInfo` であり、R05 が作り、R16 が命令ごとの入口の生きているレジスタと呼び出しの命令の結果のレジスタを加えた（[ADR 0314](../../2026-10-09-design-first-release/decisions/0314-clear-dead-registers-at-safepoints.md)）。ヒープと VM が 10-07 に求める内容と、10-07 の情報の対応は次のとおりである（10-07「生存の情報」）。

| 求める内容 | 10-07 の情報 | VM の使い方 | ヒープの関数 |
|---|---|---|---|
| 回収の時点で、各枠の窓のうち、再開の後に書かれる前に読まれうるレジスタ | `LiveInfo::live_in_at(pc)` と、呼び出しの途中の枠では `LiveInfo::call_write(pc − 1)` | 回収のために区間を閉じる前に、集合に含まれないレジスタを空にする（ADR 0314 の決定 2・3） | `NoGcCtx::clear` |
| 待つ組み込みの関数の呼び出しで、引数のレジスタを完了まで生かすこと | 完了を待つ枠は命令の入口の集合を使うので、引数が含まれる。`IO` と、権限が `Pure` でない `PRIM` の引数に `LastUse` を付けない | 完了の処理が引数を読み直す（10-11「作業用のスレッドの仕事」） | — |
| 命令ごとの、最後に使う被演算子のレジスタ・使わなくなるレジスタ・`LastUse::sole` | `LiveItem::LastUse`・`LiveItem::Dead` | R16 の後の VM は読まない。参照カウント（タグ `stage1-rc-final`）は、移す（`take`・`move_slot`）、空にする（`clear`）、再利用の判定（`reuse_ctor`）に使った | — |

R16 の後の VM は、被演算子をすべて `NoGcCtx::load` で読む。読んだ `Value<'e>` は区間の中だけで使う（不変条件 H4）。

窓を縮めたときと呼び出しの枠を降ろしたときに、窓の外になったレジスタを空にするのは、生存の情報によらず VM が行う（[仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「枠を降ろす原因と処理」）。

## 確かめ方の口

[ADR 0260](../../2026-10-09-design-first-release/decisions/0260-heap-and-unsafe-boundary.md) の決定 7 の確かめ方と、本章の口の対応は次のとおりである。確かめ方の実装は R11 が行う（機能の組み合わせと検査のスクリプトは [実装の規約](../00-common/00-02-conventions.md)の「完了条件の共通の検査」）。

| 確かめ方 | 本章の口 |
|---|---|
| 回収の強制 | `HeapConfig::stress`（機能 `gc-stress` で常に真として扱う）。`Heap::collect_requested` が常に真になる |
| ヒープの検証器 | `Heap::verify`。`heap-verify` の構成で、`Heap::collect` の前後に内部の層が呼ぶ |
| 解放した領域の毒 | `POISON_BYTE`。`heap-verify` の構成で、解放した対象の中身を埋める |
| ヒープの番号 | `Slot` の `HeapNo`。すべての構成で、`Slot` を読む・書き換える・辿る関数が比べ、`Heap::take_fault` で知らせる（ADR 0281） |
| 確保の世代 | `heap-verify` の構成の `ObjRef` の世代。`NoGcCtx::load` と `ValueCtx` の読み出しの関数が確かめ、`Heap::take_fault` で知らせる |
| 対象ごとの確保 | 機能 `heap-per-object`。確保器が対象ごとに Rust の確保器から確保し解放する。世代の確かめは、解放した領域を読まずに行う（内部の表で持つ）ことを R11 が確かめる |
| 到達可能性の比較 | `Heap::object_ids`・`ValueCtx::object_id`。テストは、操作と同時に持つ独立のグラフの模型（本番の `Trace` と内部の層の辿りを使わない）から期待する対象の集合を計算し、回収の後に残った対象の `ObjId` の集合と比べる（数でなく集合で比べる） |
| コンパイルの失敗 | 下の「コンパイルの失敗のテスト」 |

## コンパイルの失敗のテスト

次の九つの例は、不変条件 H2・H3・H7・H8・H9 の違反がコンパイルの誤りになることを確かめる。R02 は、これらを `Heap::epoch` の `///` のコメントに rustdoc の例として置き、以後の作業は消さない（[実装の規約](../00-common/00-02-conventions.md)の「テストの規約」）。

Rust 1.98.1 の rustdoc は、`compile_fail` の例の誤りの番号（`compile_fail,E0xxx`）を確かめない（2026-09-30 に確かめた。誤った番号を書いても通った）。誤りの理由を取り違えて通ることを防ぐため、`compile_fail` の例ごとに、違反する一行だけを違反しない形に変えた例を `no_run` で並べ、その例がコンパイルできることで、ほかの行に誤りがないことを確かめる。`Send` と `Sync` は、`std::thread::spawn` ではなく、その性質だけを求める関数（`require_send`・`require_sync`）で確かめる。`spawn` は `'static` も求めるので、区間の寿命を持つ値では、`Send` でなくても `'static` でないことで失敗し、理由を分けられないからである。

区間の外へ値を持ち出す（H3）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig};
let mut heap = Heap::new(HeapConfig::default());
let _escaped = heap.epoch(|ctx| ctx.alloc_str("x", "test")); // 戻り値の型が 'e を含む
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig};
let mut heap = Heap::new(HeapConfig::default());
let _len = heap.epoch(|ctx| ctx.alloc_str("x", "test").map(|v| ctx.str(v).map(str::len)).ok());
```

閉包の外の変数に値を残す（H3）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig, Value};
let mut heap = Heap::new(HeapConfig::default());
let mut kept: Option<Value<'_>> = None;
heap.epoch(|ctx| {
    kept = ctx.alloc_str("x", "test").ok(); // 外の寿命と 'e は一致しない
});
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig, Slot};
let mut heap = Heap::new(HeapConfig::default());
let mut kept = Slot::default();
heap.epoch(|ctx| {
    if let Ok(v) = ctx.alloc_str("x", "test") {
        ctx.store(&mut kept, v);
    }
});
```

別のヒープの区間に値を渡す（H9）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig, Slot};
let mut a = Heap::new(HeapConfig::default());
let mut b = Heap::new(HeapConfig::default());
let mut slot = Slot::default();
a.epoch(|ca| {
    if let Ok(v) = ca.alloc_str("x", "test") {
        b.epoch(|cb| cb.store(&mut slot, v)); // 'a の値を 'b の区間で書く
    }
});
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig, Slot};
let mut a = Heap::new(HeapConfig::default());
let mut b = Heap::new(HeapConfig::default());
let mut slot = Slot::default();
a.epoch(|ca| {
    if let Ok(_v) = ca.alloc_str("x", "test") {
        b.epoch(|cb| {
            if let Ok(w) = cb.alloc_str("y", "test") {
                cb.store(&mut slot, w);
            }
        });
    }
});
```

区間の中で回収する（H2）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig, RootStack};
let mut heap = Heap::new(HeapConfig::default());
let roots = RootStack::new();
heap.epoch(|_ctx| {
    heap.collect(&roots); // 区間は heap を &mut で借りている
});
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig, RootStack};
let mut heap = Heap::new(HeapConfig::default());
let roots = RootStack::new();
heap.epoch(|_ctx| {
    let _ = roots.len();
});
```

`Host` の対象の共有の参照を持ったまま書き換える（H7）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig, HostData, Trace, Tracer};
#[derive(Debug)]
struct Data(u32);
impl Trace for Data {
    fn trace(&self, _t: &mut Tracer<'_>) {}
}
impl HostData for Data {}
let mut heap = Heap::new(HeapConfig::default());
heap.epoch(|ctx| {
    let v = ctx.alloc_host(Data(1));
    let shared = ctx.host::<Data>(v);
    ctx.host_mut::<Data, _>(v, |d, _| d.0 = 2); // `host` の参照を持ったまま `&mut` で借りる
    let _ = shared.map(|d| d.0);
});
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig, HostData, Trace, Tracer};
#[derive(Debug)]
struct Data(u32);
impl Trace for Data {
    fn trace(&self, _t: &mut Tracer<'_>) {}
}
impl HostData for Data {}
let mut heap = Heap::new(HeapConfig::default());
heap.epoch(|ctx| {
    let v = ctx.alloc_host(Data(1));
    let shared = ctx.host::<Data>(v);
    let _ = ctx.host::<Data>(v);
    let _ = shared.map(|d| d.0);
});
```

値を作業用のスレッドへ渡す（H8。`Send`）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig};
fn require_send<T: Send>(_: T) {}
let mut heap = Heap::new(HeapConfig::default());
heap.epoch(|ctx| {
    if let Ok(v) = ctx.alloc_str("x", "test") {
        require_send(v); // Value は Send でない
    }
});
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig};
fn require_send<T: Send>(_: T) {}
let mut heap = Heap::new(HeapConfig::default());
heap.epoch(|ctx| {
    if let Ok(v) = ctx.alloc_str("x", "test") {
        require_send(ctx.str(v).map(str::len));
    }
});
```

値を作業用のスレッドと共有する（H8。`Sync`）:

```rust,compile_fail
use benitoite::runtime::heap::{Heap, HeapConfig};
fn require_sync<T: Sync>(_: &T) {}
let mut heap = Heap::new(HeapConfig::default());
heap.epoch(|ctx| {
    if let Ok(v) = ctx.alloc_str("x", "test") {
        require_sync(&v); // Value は Sync でない
    }
});
```

```rust,no_run
use benitoite::runtime::heap::{Heap, HeapConfig};
fn require_sync<T: Sync>(_: &T) {}
let mut heap = Heap::new(HeapConfig::default());
heap.epoch(|ctx| {
    if let Ok(v) = ctx.alloc_str("x", "test") {
        require_sync(&ctx.str(v).map(str::len));
    }
});
```

`Slot` を作業用のスレッドへ渡す（H8。`Send`）:

```rust,compile_fail
use benitoite::runtime::heap::Slot;
fn require_send<T: Send>(_: T) {}
let slot = Slot::default();
require_send(slot); // Slot は Send でない
```

```rust,no_run
use benitoite::runtime::heap::Slot;
fn require_send<T: Send>(_: T) {}
let slot = Slot::default();
require_send(slot.is_immediate());
```

`Slot` を作業用のスレッドと共有する（H8。`Sync`）:

```rust,compile_fail
use benitoite::runtime::heap::Slot;
fn require_sync<T: Sync>(_: &T) {}
let slot = Slot::default();
require_sync(&slot); // Slot は Sync でない
```

```rust,no_run
use benitoite::runtime::heap::Slot;
fn require_sync<T: Sync>(_: &T) {}
let slot = Slot::default();
require_sync(&slot.is_immediate());
```

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C01 | 本章の `task=C02` のないブロックを置く（`file=` のコードと、`sig=` の `todo!()` の仮置き。00-02） |
| C02 | `Decimal` の対象の関数と `runtime::map` のシグネチャ（`runtime/map.rs` は C01 が `runtime/mod.rs` の宣言に合わせて作った中身のないモジュールを埋める） |
| R01 | `core.rs` とその子（ヒープの番号の割り当て、確保器、対象の頭、根の列挙の土台、解放の関数と `frees` の計数）、`ValueCtx` の確保と頭の読み書き |
| R02 | `Heap::new`・`Heap::epoch`、`NoGcCtx` と `SlotOps` の `Slot` の関数（ヒープの番号の比較を含む）、セルと `Host` の関数、`Tracer`・`Discarder`、`RootStack`、コンパイルの失敗のテスト |
| R03 | `gc-mark-sweep` の `Heap::collect`・`collect_requested`・`take_collect_signal`、回収の閾値 |
| R04 | `gc-refcount` の数の増減、解放の候補と区間の外での遅らせた解放、`Heap::collect`、ADR 0239 の循環の回収、`reuse_ctor`（`HeapConfig::reuse` を含む）。第 1 段の締め（R14）が `gc-refcount` とともに外し、`reuse_ctor` と `HeapConfig::reuse` の口だけが残る |
| R06 | 種類ごとの `ValueCtx` の関数、`runtime::list`（第 1 段の連結リスト）、`runtime::equal`、値の大きさの表明を確かめるテスト |
| R35 | `alloc_decimal`・`decimal`、`runtime::equal` の `Decimal` の比較（数として比べる。小数の桁数は比べない） |
| R36 | `runtime::list` の表現を永続ベクタに移す |
| R37 | `runtime::map`、`runtime::equal` のマップと集合の比較 |
| R09 | `runtime::panic` の中身（`src/legacy/runtime/panic.rs` から写す） |
| R11 | `Heap::verify`、世代と毒と対象ごとの確保、到達可能性の比較のテスト、Miri での実行 |
