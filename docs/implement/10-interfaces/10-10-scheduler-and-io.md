# スケジューラと IO 実行器

本章は、スケジューラと IO 実行器の型とシグネチャを定める。進められるタスクの待ち行列、要求の番号と送り出しの列、列を処理する二つの部品、外部の操作の記録、完了の型と完了を受け取る共通の処理、リソースの表と状態、出力のバッファと書き出し用のスレッド、テストで差し替える三つの部品（次に進めるタスクを選ぶ部品、時計とタイマー、作業用のスレッドの仕事の実行）、VM と IO 実行器のつなぎ目である。設計書の対応する章は[ランタイム](../../design/02-impl/02-09-runtime.md)の「IO 実行器」「タスクの待ちと取り消し」「リソースの追跡」「出力のバッファ」と、[仮想機械](../../design/02-impl/02-08-vm.md)の「タスクの切り替え」「IO の命令」、[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「順序を与えるスケジューラと仮想の時間（初回リリース版）」であり、判断の根拠は [ADR 0264](../../design/decisions/0264-single-dispatch-queue-for-builtin-operations.md)・[ADR 0265](../../design/decisions/0265-output-transfer-by-writer-threads.md)・[ADR 0266](../../design/decisions/0266-task-and-resource-state-machines.md)・[ADR 0274](../../design/decisions/0274-deterministic-scheduler-and-virtual-time-for-tests.md) である。

- 置く作業: C02

本章は U2 第 2 段の章であり、C02 が置く。第 1 段の IO は、10-09 の「第 1 段の実行の関数」の一時的な形で行い、R26 が本章の形に置き換える。

最小実行版の `executor.rs`・`real_io.rs`・`test_io.rs`・`io.rs` は、C04 が `src/legacy/runtime/` へ移し、最小実行版の VM とともに C18 まで `legacy` の中で使われる。本章の `runtime::io` は子のモジュールを持つディレクトリ（`src/runtime/io/mod.rs`）であり、C04 が空けたパスに置く。`runtime/mod.rs`（10-08。C01）が `io` と `sched` を宣言するので、C01 の時点で道具が中身のないモジュール（`src/runtime/io/mod.rs`・`src/runtime/sched/mod.rs`）を作り、C02 がそれを埋める。

## 実装プランで決める値

設計書が実装プランに委ねた値を次のとおり決める。

| 値 | 決めたこと | 理由 |
|---|---|---|
| 作業用のスレッドの数 | 仕事を出すときに空いたスレッドがなければ新しく作り、上限を 64 とする。上限に達したら、仕事は空くまで列で待つ。空いたスレッドは実行の終わりまで残す | 標準入力の読み取りや外部コマンドの待ちでスレッドが長く埋まっても、ほかの仕事が始まるようにするため。上限は OS の資源を使い尽くさないため |
| 転送していない量の上限 B | 出力ごとに 1 MiB（1,048,576 バイト） | 転送を依頼する大きさ（64 KiB）の 16 倍とし、書き出しが遅い出力先でも VM がすぐには待たないようにする |
| 出力先が端末かの判定 | 実行を始めるときに、出力先ごとに一度だけ Rust の `std::io::IsTerminal` で調べる。メモリに捕らえる出力先は端末でないとする | 標準ライブラリで判定でき、依存を増やさない |

作業用のスレッドの数の既定は、R26 の測定で見直してよい。見直したら本表を改める。

## タスクとスケジューラ

スケジューラは、進められるタスクの待ち行列と、待つタスクの表を持つ（02-08「タスクの切り替え」）。タスクの状態は 10-09 の `TaskState` であり、待つ理由は `WaitReason` である。待ち行列から次のタスクを選ぶ部品（`TaskPicker`）は、テストで差し替える（ADR 0274 の決定 1）。

外部の完了を待つ番号（`ExtOpId`・`TimerId`）は、実行の中で使い回さない。`ExtOpId` は外部の操作の記録の番号であり、10-07 の `OpIdx`（コンパイル済みプログラムの操作の表の番号。エフェクトの操作を指す）とは別のものである。

```rust file=src/runtime/sched/mod.rs
//! スケジューラ（設計書 02-08「タスクの切り替え」、02-09「タスクの待ちと取り消し」、ADR 0161・0266・0274）。

pub mod parts;
pub mod testing;

use std::collections::{BTreeMap, VecDeque};

use crate::vm::TaskId;
use crate::vm::task::WaitReason;

/// 外部の操作の番号（作業用のスレッドの仕事、イベントループの準備、ブロックする解放）。
/// エフェクトの操作の番号 `bytecode::program::OpIdx` とは別のもの。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ExtOpId(pub u64);

/// タイマーの番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct TimerId(pub u64);

/// 待つタスクの表の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Waiting {
    pub reason: WaitReason,
}

/// スケジューラの状態。
#[derive(Debug, Default)]
pub struct Scheduler {
    /// 進められるタスクの待ち行列
    pub ready: VecDeque<TaskId>,
    /// 待つタスクの表
    pub waiting: BTreeMap<TaskId, Waiting>,
    /// タイマー（期限の単調な時計のミリ秒、番号 → 待つタスク）
    pub timers: BTreeMap<(u64, TimerId), TaskId>,
    next_ext_op: u64,
    next_timer: u64,
}
```

次の関数の中身は R25 が書く。

```rust sig=src/runtime/sched/mod.rs
use self::parts::TaskPicker;

impl Scheduler {
    pub fn new_ext_op_id(&mut self) -> ExtOpId;
    pub fn new_timer_id(&mut self) -> TimerId;
    /// 実行中のタスクを待たせる。要求を送り出しの列に公開する前に呼ぶ（ADR 0264 の決定 2）。
    pub fn park(&mut self, task: TaskId, reason: WaitReason);
    /// 待つタスクを進められるタスクに戻す（待ち行列の末尾）。待っていなければ何もしない。
    /// 待ちの理由を問わないので、待ちを外す取り消しと止める手順で使う。
    pub fn wake(&mut self, task: TaskId);
    /// `task` が `reason` で待っていれば進められるタスクに戻し、`true` を返す。ほかの理由で待つか、
    /// 待っていなければ何もしない。知らせ（完了、返却、解放の完了、タスクの終わり）で起こすときに使い、
    /// 古い知らせで別の待ちのタスクを起こさない。
    pub fn wake_if(&mut self, task: TaskId, reason: WaitReason) -> bool;
    /// `reason` で待つタスクをすべて、番号の順に進められるタスクに戻し、戻したタスクを返す。
    pub fn wake_all(&mut self, reason: WaitReason) -> Vec<TaskId>;
    /// 待ち行列から次のタスクを除いて返す。選び方は `picker` が決める。
    pub fn next(&mut self, picker: &mut dyn TaskPicker) -> Option<TaskId>;
    /// 外部の完了の待ち（`WaitReason::is_external`）か、タイマーがあるか。
    pub fn has_external_waits(&self) -> bool;
    /// 行き詰まりか: 待ち行列が空で、外部の待ち（`WaitReason::is_external`）で待つタスクもタイマーもなく、
    /// 待つタスクがあるとき（02-08「タスクの切り替え」、ADR 0238・0266 の決定 8・0283）。どのタスクも待って
    /// いない外部の操作の記録と出力の転送は数えないので、ほかの状態は調べない（本章「完了の処理と行き詰まりの
    /// 判定の順序」の手順 5）。止める手順の途中では、呼び出し側が停止の理由を置き換えない。
    pub fn is_deadlocked(&self) -> bool;
    /// 期限の来たタイマーを除き、その待つタスクを返す。
    pub fn expire_timers(&mut self, now_monotonic_millis: u64) -> Vec<(TimerId, TaskId)>;
    /// 最も早いタイマーの期限。
    pub fn next_deadline(&self) -> Option<u64>;
}
```

## テストで差し替える部品

次の三つの部品を、実際の実装とテスト用の実装で差し替えられるようにする（ADR 0274 の決定 1）。差し替えは処理系のテスト（Rust のテストとゴールデンテストの実行器）だけが行い、CLI と `benitoite test` からは選べない（同 決定 2）。`RuntimeParts::real` のほかの作り方は `#[cfg(test)]` と、ゴールデンテストの実行器が使う公開の関数に限る。

| 部品 | 実際の実装 | テスト用の実装 |
|---|---|---|
| `TaskPicker` | 待ち行列の先頭を選ぶ（`FifoPicker`） | テストが与えた順序で選ぶ |
| `Clock` | OS の時計と単調な時計 | 仮想の時間。テストが時間を進めたときにだけ進み、タイマーはそのときだけ満了する |
| `WorkerExec` | 作業用のスレッドで仕事を行い、完了を channel とイベントループの起こしで知らせる | 仕事を預かり、テストが指示した時点で VM のスレッドで実行して完了を返す |

`WorkerExec::idle` は、進められるタスクがないときに VM のスレッドを待たせる口である。実際の実装は、次のタイマーの期限までイベントループと完了の channel を待つ。テスト用の実装は、実時間では待たず、テストが与えた筋書き（時間を進める、預かった仕事を実行する）の次の一歩を行う。

テスト用の三つの部品は、一つの筋書きを共有する。筋書きは、タスクを選ぶ指示、仮想の時間を進める指示、預かった仕事を実行する指示を順に並べたものである。筋書きを進める境界は次の二つに限る（[相談の第 7 回](../studies/u2-runtime/consult/07-plan-scheduler-review.md)の指摘 7）。

- タスクを選ぶ指示は、`TaskPicker::pick` が消費する。
- 時間を進める指示と仕事を実行する指示は、完了の取り込みの境界（本章「完了の処理と行き詰まりの判定の順序」の手順 2。待たせる位置と、予算を使い切った遅い経路の両方で通る）で、テスト用の `WorkerExec::try_recv` が、筋書きの先頭から次のタスクを選ぶ指示の前までをまとめて行う。進められるタスクがないときは、`idle` が同じことを行う。

境界を完了の取り込みに置くのは、ほかのタスクが計算を続けている間（予算を使い切るたびに遅い経路を通る）にも、時間を進める時点と仕事を実行する時点を、筋書きの位置だけで決められるようにするためである。仮想の時間が進んだ結果のタイマーの満了は、同じ待たせる位置の手順 3 で取り込む。

筋書きは、消費した指示の数と、実際に選んだタスクと行った指示の記録をテストに返す。先頭の指示を行えないとき（まだ預かっていない仕事を実行する指示など）と、筋書きのない選択で待ち行列の先頭へ戻ることを誤りとするかの扱いは R25 が決める。順序に依存する再現テストは、筋書きを使い切ったことと、狙った順序で選び・実行したことを、この記録で確かめる。待ち行列の先頭を選ぶ既定の振る舞いで偶然に通ることを、テストの成功としない。

```rust file=src/runtime/sched/parts.rs
//! テストで差し替える部品（ADR 0274）: 次に進めるタスクを選ぶ部品、時計、作業用のスレッドの仕事の実行。

use std::collections::VecDeque;
use std::fmt::Debug;

use crate::runtime::io::ops::{Completion, WorkerJob};
use crate::vm::TaskId;

/// 次に進めるタスクを選ぶ部品。
pub trait TaskPicker: Debug {
    /// 待ち行列の中から次に進めるタスクの位置を返す。空なら `None`。
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize>;
}

/// 実際の実装: 待ち行列の先頭を選ぶ。
#[derive(Clone, Copy, Debug, Default)]
pub struct FifoPicker;

impl TaskPicker for FifoPicker {
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize> {
        if ready.is_empty() { None } else { Some(0) }
    }
}

/// 時計（`Clock.now` などとタイマーの期限）。
pub trait Clock: Debug {
    /// UTC の 1970-01-01 からのミリ秒
    fn now_millis(&self) -> i64;
    fn local_offset_minutes(&self) -> i32;
    /// 実行を始めてからの単調な時計のミリ秒
    fn monotonic_millis(&self) -> u64;
}

/// `WorkerExec::idle` の結果。
#[derive(Debug)]
pub enum IdleWake {
    /// 完了、タイマー、イベントループの準備、出力の知らせのどれかが届いたか、時間が進んだ
    Progress,
    /// 中断の要求でイベントループが起こされた
    Interrupted,
    /// テスト用の実装で、筋書きが尽きた（テストの誤り。VM は `Stop::Internal` にする）
    ScriptExhausted,
}

/// 作業用のスレッドの仕事の実行と、完了とイベントの待ち。
pub trait WorkerExec: Debug {
    /// 仕事を出す。完了は後で `try_recv` が返す。
    fn submit(&mut self, job: WorkerJob);
    /// 届いた完了を一つ返す。待たない。
    fn try_recv(&mut self) -> Option<Completion>;
    /// 進められるタスクがないときに待つ。`deadline` は次のタイマーの期限（単調な時計のミリ秒）。
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake;
}

/// 差し替える部品の組。実行ごとに一つ持つ。
#[derive(Debug)]
pub struct RuntimeParts {
    pub picker: Box<dyn TaskPicker>,
    pub clock: Box<dyn Clock>,
    pub workers: Box<dyn WorkerExec>,
}
```

実際の実装の作り方と、テスト用の実装は R25（`TaskPicker`・`Clock`）と R26（`WorkerExec`）が書く。テスト用の実装の筋書きの型（どのタスクを選ぶか、いつ時間を進めるか、どの仕事をいつ実行するか）は R25 が決め、`src/runtime/sched/testing.rs` に置く。`sched/mod.rs` は `pub mod testing;` と宣言する。`#[cfg(test)]` にしないのは、統合テスト（`tests/`）と CLI のテストの補助が、テスト用の部品を公開の API として使うからである（ADR 0274）。C02 は、宣言に合わせて中身のないモジュールを置く。

```rust sig=src/runtime/sched/parts.rs
use crate::runtime::io::event::Wakeup;

impl RuntimeParts {
    /// 実際の実装の組。`wakeup` は作業用のスレッドが完了を知らせるときにイベントループを起こす口。
    pub fn real(wakeup: Wakeup) -> RuntimeParts;
}
```

## 送り出しの列と二つの部品

言語のハンドラが処理しなかった組み込みのエフェクトの操作は、どちらの方式でも、番号付きの要求として送り出しの列に置く（ADR 0264 の決定 1〜3）。VM は、タスクを `Scheduler::park` で待たせてから、要求を列に公開する。要求は、操作（組み込みの関数の登録の項目）、要求を出したタスク、呼び出しの命令を持つ。引数の値は要求に写さない。待っているタスクの枠のレジスタに残っており、要求を行うときと完了の処理で、呼び出しの命令の被演算子から読み直す。被演算子は、呼び出しの命令（`Request::site` の原型と位置の命令）を `CompiledProgram::builtin_call_operands` に渡して得る `BuiltinCallOperands`（結果のレジスタ、組み込みの関数の参照、引数の並びの先頭と数。10-07「コンパイル済みプログラム」）で決める。

要求の呼び出しの命令を持つ場所は、要求の段階ごとに一つに決める（ADR 0264 の決定 3「要求と、待つタスクの保存した枠との対応を、この番号で持つ」。相談の第 7 回の指摘 4）。

| 段階 | 要求（と呼び出しの命令）を持つ場所 | 待つタスクの理由 |
|---|---|---|
| 列にある（部品に渡す前） | `DispatchQueue::live`（段階 `Queued`） | `Response` |
| 要求と応答の方式で、外側の実行器の応答を待つ | `DispatchQueue::live`（段階 `Outstanding`） | `Response` |
| ハンドラ表の関数を呼んでいる | VM の一回の処理の局所変数（`DispatchQueue::take_for_serve` で除いた `Request`）。この間にほかのタスクは動かない | `Response` |
| 仕事を出す前に、貸すリソースの返却を待つ | `DispatchQueue::live`（段階 `AwaitLend`。応答の仕事も持つ） | `Lend(リソース)` |
| 仕事を出す前に、出力の転送の完了を待つ | `DispatchQueue::live`（段階 `AwaitFlush`。応答の仕事も持つ） | `Output(出力, Flush)` |
| 外部の操作に移った | `OpTable` の記録（`OpRecord::site`）。`live` からは除く | `Worker(番号)` |
| 失効した（要求を出したタスクの取り消し、止める手順） | どこにもない（`live` から除き、応答の仕事は捨てる） | — |

要求を出したタスクの取り消しと止める手順は、`DispatchQueue::expire_task`・`expire_all` で、外部の操作に移る前の要求を失効させる。要求と応答の方式で外側の実行器が失効した要求の番号で `Vm::serve_request` を呼んでも、`take_for_serve` が `None` を返すので、何もしない。`take_for_serve` が要求を返したときも、VM は、要求のタスクがまだ番号の世代のまま `Response` で待っていることを確かめてから処理する（[ADR 0282](../../design/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。

列を処理する部品は方式ごとに一つである（ADR 0264 の決定 4）。VM は、タスクを待たせる位置と、予算を使い切った遅い経路の手順 2 で、`Dispatcher::on_wait_point` を呼ぶ。

| 部品 | `on_wait_point` の結果 | VM の処理 |
|---|---|---|
| `DirectDispatcher` | 列の要求の番号をすべて `ServeNow` で返す（段階は `Queued` のまま） | 番号ごとに `take_for_serve` で要求を除いてハンドラ表の関数を呼び、応答を処理する（完了なら結果を入れて起こす、待つなら外部の操作の記録に登録するか、段階を改めて `live` に戻す）。途中で止める手順が始まったら、残りの番号は `expire_all` で失効しているので、`take_for_serve` が `None` を返す |
| `RequestDispatcher` | 列の要求があれば段階を `Outstanding` にして `ReturnToExecutor` で返す。段階が `Outstanding` の要求があり、呼ばれた位置が遅い経路なら、空の `ReturnToExecutor` を返す | 実行関数から `VmStep::Requests` を返す。外側の実行器が `Vm::serve_request` を呼んでから実行を再開する |

すぐに完了する操作の近道は設けない（ADR 0264 の決定 6）。近道を入れるときは、`DirectDispatcher` の中の分岐として一か所に置く。

```rust file=src/runtime/io/mod.rs
//! IO 実行器（設計書 02-09「IO 実行器」「タスクの待ちと取り消し」「リソースの追跡」「出力のバッファ」）。

pub mod event;
pub mod ops;
pub mod output;
pub mod resources;
pub mod services;

use std::collections::{BTreeMap, VecDeque};

use crate::builtins::iface::{BuiltinDecl, WorkerWait};
use crate::runtime::heap::ResourceId;
use crate::vm::{InstrRef, RequestId, TaskId};

/// 送り出しの列の要求。
#[derive(Clone, Copy, Debug)]
pub struct Request {
    pub id: RequestId,
    pub task: TaskId,
    /// 操作（10-11 の `io` の権限の組み込みの関数）
    pub op: &'static BuiltinDecl,
    /// 呼び出しの命令。引数と結果のレジスタは、この命令の被演算子（10-07 の
    /// `CompiledProgram::builtin_call_operands`）で決まる
    pub site: InstrRef,
}

/// 外部の操作に移る前の要求の段階（本章の段階の表）。
#[derive(Debug)]
pub enum RequestPhase {
    /// 送り出しの列にある
    Queued,
    /// 要求と応答の方式で、外側の実行器に渡して応答を待つ
    Outstanding,
    /// 応答が作業用のスレッドの仕事で、貸すリソースの返却を待つ。返却の後に貸し出しからやり直す
    AwaitLend(ResourceId, WorkerWait),
    /// 応答が作業用のスレッドの仕事で、仕事を出す前に出力の転送の完了を待つ
    AwaitFlush(WorkerWait),
}

/// 生きている要求（外部の操作に移る前で、失効していない要求）。
#[derive(Debug)]
pub struct LiveRequest {
    pub req: Request,
    pub phase: RequestPhase,
}

/// 送り出しの列（実行ごとに一つ）。
#[derive(Debug, Default)]
pub struct DispatchQueue {
    /// 部品に渡す前の要求の番号（公開した順）
    pub queued: VecDeque<RequestId>,
    /// 生きている要求。外部の操作に移る前の要求の呼び出しの命令は、どの段階でもここにある
    pub live: BTreeMap<RequestId, LiveRequest>,
    next_id: u64,
}

/// VM が待たせる位置で部品に尋ねた結果。
#[derive(Debug)]
pub enum DispatchAction {
    /// 何もしない
    Nothing,
    /// これらの番号の要求をいまハンドラ表の関数で行う（直接呼び出し）
    ServeNow(Vec<RequestId>),
    /// VM の実行関数から戻り、これらの要求の番号を外側の実行器に渡す（要求と応答）
    ReturnToExecutor(Vec<RequestId>),
}

/// 待たせる位置の種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum WaitPoint {
    /// 要求を置いたタスクを待たせる位置
    Park,
    /// 予算を使い切った遅い経路の手順 2
    SlowPath,
}

/// 列を処理する部品（ADR 0264 の決定 4）。
pub trait Dispatcher: std::fmt::Debug {
    fn on_wait_point(&mut self, queue: &mut DispatchQueue, at: WaitPoint) -> DispatchAction;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct DirectDispatcher;

#[derive(Clone, Copy, Debug, Default)]
pub struct RequestDispatcher;
```

次の関数の中身は R26 が書く。

```rust sig=src/runtime/io/mod.rs
impl DispatchQueue {
    /// 番号を付けて要求を列に置く（段階 `Queued`）。呼び出し側は先にタスクを待たせておく。
    pub fn publish(&mut self, task: TaskId, op: &'static BuiltinDecl, site: InstrRef) -> RequestId;
    /// ハンドラ表の関数で行うために、段階が `Queued` か `Outstanding` の要求を除いて返す。
    /// 失効した番号と、ほかの段階の要求には `None` を返す。
    pub fn take_for_serve(&mut self, id: RequestId) -> Option<Request>;
    /// 応答が仕事で、資源の返却か出力の転送の完了を待つ要求を、段階を付けて戻す。
    pub fn park_request(&mut self, req: Request, phase: RequestPhase);
    /// `task` の生きている要求（段階を問わない）を除いて返す（資源の返却や出力の転送の完了の後にやり直す）。
    pub fn take_task_request(&mut self, task: TaskId) -> Option<LiveRequest>;
    /// `task` の生きている要求を失効させる（取り消し）。応答の仕事は捨てる。
    pub fn expire_task(&mut self, task: TaskId);
    /// 生きている要求をすべて失効させる（止める手順）。
    pub fn expire_all(&mut self);
    /// 段階が `Outstanding` の要求があるか（`RequestDispatcher` の遅い経路）。
    pub fn has_outstanding(&self) -> bool;
}

impl Dispatcher for DirectDispatcher {
    fn on_wait_point(&mut self, queue: &mut DispatchQueue, at: WaitPoint) -> DispatchAction;
}

impl Dispatcher for RequestDispatcher {
    fn on_wait_point(&mut self, queue: &mut DispatchQueue, at: WaitPoint) -> DispatchAction;
}
```

## 外部の操作の記録と完了

作業用のスレッドとイベントループで行う外部の操作は、番号（`ExtOpId`）付きの記録として持つ（ADR 0266 の決定 3）。記録は、結果を渡すタスクと、貸したものを持つ。タスクを取り消したときは、記録の `deliver_to` を外すだけで、記録は完了するまで消さない。

完了（`Completion`）は、「タスクへの結果」（`outcome`）と「返すもの」（`returned`）の二つの欄を持つ（ADR 0266 の決定 4）。作業用のスレッドは、貸したものを `catch_unwind` で囲む処理の外で持ち、仕事が panic しても `returned` を作る（同 決定 9）。完了を受け取る共通の処理（`accept_completion`）は、記録を表から除く前に、記録の欄（種類、`deliver_to`、`site`）を取り出しておき、次の順に行う。個々の組み込みの関数には任せない。

1. `returned` をリソースの表（または標準入力の読み手の置き場）に戻す。閉じる要求がなければ `Returned`、あれば `StartRelease` を結果に加える。記録の種類が `Release(リソース)` なら、配送とは別に、`finish_release` で結果を記録して `Released` にし、`ReleaseFinished` を加える（`outcome` が `Panicked` でも `Released` にする。そのときは失敗を記録せず、手順 2 で報告する）。
2. `outcome` が処理系の不具合（`Panicked`）なら、タスクが待っているかによらず、`Bug` を加える（panic 境界の処理で処理系の不具合として報告する）。
3. そうでなければ、種類が `Worker` か `Readiness` の記録について、`deliver_to` があれば配送の候補（`Deliver`。タスク、操作の番号、`site`、結果）を、なければ `Dropped` を加える。捨ててよいのは値と失敗だけである。

`accept_completion` はスケジューラとタスクの表を受け取らないので、タスクがまだその操作を待っているかは、`Deliver` を受けた VM が調べる（相談の第 7 回の指摘 3）。VM は、そのタスクが `WaitReason::Worker(操作の番号)` か `Readiness(操作の番号)` で待っていれば、作業用のスレッドの仕事の結果（`WorkerDone`）を言語の値にして起こし（`Scheduler::wake_if`）、待っていなければ結果を捨てる。言語の値にするときは、`Deliver` の `site` の命令を `CompiledProgram::builtin_call_operands` に渡して引数の並びと結果のレジスタを求め、待っていたタスクの枠のレジスタから引数を読み直して `WorkerDone::complete` に渡し、結果を結果のレジスタに入れる。

`Returned`・`StartRelease`・`ReleaseFinished` を受けた VM の処理は次のとおりである。

- `Returned(リソース)`: 返却を待つ並び（`ResourceEntry::waiters`）の先頭から、`WaitReason::Lend(リソース)` で待つタスクの要求（段階 `AwaitLend`）を一つ取り出し、貸し出しからやり直す。並びに残るタスクは、次の返却を待つ。
- `StartRelease(リソース)`: 新しい操作の番号で `request_release` を呼んで解放を始める。すぐに終わった（`Done`）なら、`finish_release` で結果を記録して `ReleaseFinished` と同じく扱う。ブロックする解放なら、仕事を出す（後述の「ブロックする解放の仕事の受け渡し」）。
- `ReleaseFinished(リソース)`: `WaitReason::Release(リソース)` で待つタスクをすべて起こす（`wake_all`）。返却を待つ並びのタスクの要求も貸し出しからやり直し、「解放したリソースの使用」にする。

ブロックする解放の仕事の受け渡しは次のとおりである（相談の第 7 回の指摘 5）。解放を始める関数（R24 の `request_release`）は、OS の資源をリソースの表の項目に残したまま状態を `Releasing(番号)` にし、番号を表の解放の仕事の列（`ResourceTable::release_jobs`）に加えて `Blocking` を返す。完了の処理と行き詰まりの判定の順序の手順 1 の後に、共通の関数（R26）が `ResourceTable::take_release_job` で資源を取り出し、種類 `Release(リソース)` の記録を `OpTable` に加え（`deliver_to` と `site` は `None`）、`JobWork::Release` の仕事を `WorkerExec::submit` で出す。解放を待つタスクは、完了で `finish_release` した後に `ReleaseFinished` で起きる。

すべてのタスクが終わった後に残る外部の操作は待たない（ADR 0266 の決定 11）。実行ごとの状態を捨てるときに記録も捨て、後で完了した作業用のスレッドは、受け取る側のない `returned` を破棄して OS の資源を閉じる（言語の解放としては扱わない）。

```rust file=src/runtime/io/ops.rs
//! 外部の操作の記録と完了（ADR 0266 の決定 3・4・9・11）。

use std::collections::BTreeMap;
use std::io::BufRead;

use crate::builtins::iface::{OsResource, WorkerDone, WorkerWait};
use crate::runtime::heap::ResourceId;
use crate::runtime::panic::PanicReport;
use crate::runtime::sched::ExtOpId;
use crate::vm::{InstrRef, TaskId};

/// 仕事に貸したもの（作業用のスレッドへ移し、完了で返す）。
#[derive(Debug)]
pub enum LentOwned {
    Nothing,
    Resource(ResourceId, Box<dyn OsResource>),
    Stdin(Box<dyn StdinReader>),
}

/// 標準入力の読み手（作業用のスレッドへ貸す）。
pub trait StdinReader: BufRead + Send + std::fmt::Debug {}

/// 作業用のスレッドで行うこと。
#[derive(Debug)]
pub enum JobWork {
    /// 組み込みの関数の仕事。完了は `Outcome::Worker`
    Builtin(WorkerWait),
    /// ブロックする解放（`OsResource::release` を呼ぶ）。完了は `Outcome::Released` で、`returned` は `Nothing`
    Release(Box<dyn OsResource>),
}

/// 作業用のスレッドへ出す仕事。
#[derive(Debug)]
pub struct WorkerJob {
    pub op: ExtOpId,
    pub work: JobWork,
    pub lent: LentOwned,
}

/// 操作の種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum OpKind {
    /// 作業用のスレッドの仕事
    Worker,
    /// イベントループの準備の待ち
    Readiness,
    /// ブロックする解放（作業用のスレッドで `OsResource::release` を呼ぶ）
    Release(ResourceId),
}

/// タスクへの結果。
#[derive(Debug)]
pub enum Outcome {
    /// 仕事を終えた（値か失敗かは完了の処理が決める）
    Worker(WorkerDone),
    /// イベントループの準備ができた
    Ready,
    /// ブロックする解放を終えた。失敗は理由の文字列
    Released(Result<(), String>),
    /// 作業用のスレッドか書き出し用のスレッドで panic が起きた（処理系の不具合）
    Panicked(PanicReport),
}

/// 完了。作業用のスレッドから VM のスレッドへ送るので `Send` である。
#[derive(Debug)]
pub struct Completion {
    pub op: ExtOpId,
    pub outcome: Outcome,
    /// 返すもの。先に表へ戻す
    pub returned: LentOwned,
}

/// 外部の操作の記録。
#[derive(Debug)]
pub struct OpRecord {
    pub kind: OpKind,
    /// 結果を渡すタスク。取り消しで外す（記録は残す）
    pub deliver_to: Option<TaskId>,
    /// 貸したリソース（返るまで `Lent` の状態にある）
    pub lent: Option<ResourceId>,
    /// 操作を呼んだ命令。結果を入れるレジスタと、完了の処理に渡す引数のレジスタは、この命令の被演算子
    /// （10-07 の `CompiledProgram::builtin_call_operands`）で決まる
    pub site: Option<InstrRef>,
}

/// 外部の操作の記録の表。
#[derive(Debug, Default)]
pub struct OpTable {
    pub records: BTreeMap<ExtOpId, OpRecord>,
}
```

次の関数の中身は R26 が書く。`accept_completion` は上の 1〜3 の順を守り、結果もこの順に並べる。VM の側の処理（待ちの照合、結果の値を作ってタスクを起こす、解放を始める、panic 境界へ移る）を呼び出し側に返すため、結果を `Accepted` で表す。

```rust sig=src/runtime/io/ops.rs
use super::resources::ResourceTable;

/// 完了を受け取った後に VM が行うこと。
#[derive(Debug)]
pub enum Accepted {
    /// 閉じる要求のないリソースが返り、`Open` に戻った。返却を待つタスクの要求をやり直す
    Returned(ResourceId),
    /// 閉じる要求のあるリソースが返った。新しい操作の番号で解放を始める
    StartRelease(ResourceId),
    /// ブロックする解放を終え、`finish_release` で記録した。解放を待つタスクを起こす
    ReleaseFinished(ResourceId),
    /// 処理系の不具合として報告する（タスクが待っているかによらない）
    Bug(PanicReport),
    /// 配送の候補。`task` がまだ `op` を待っているかは VM が調べる。記録は既に表から除いてあるので、
    /// 結果を作るのに要る `site` をここに写す
    Deliver { task: TaskId, op: ExtOpId, site: Option<InstrRef>, outcome: Outcome },
    /// 配送先を外した記録の完了なので、値と失敗を捨てた
    Dropped,
}

impl OpTable {
    pub fn insert(&mut self, op: ExtOpId, record: OpRecord);
    /// 取り消したタスクの記録から `deliver_to` を外す。記録は残す。
    pub fn detach_task(&mut self, task: TaskId);
}

/// 完了を受け取る共通の処理（ADR 0266 の決定 4）。
/// `stdin` は、標準入力の読み手を返す置き場。
pub fn accept_completion(
    ops: &mut OpTable,
    resources: &mut ResourceTable,
    stdin: &mut Option<Box<dyn StdinReader>>,
    completion: Completion,
) -> Vec<Accepted>;
```

## リソースの表と状態

リソースの表の項目は、種類、中身、状態、開いた位置を持つ（02-09「リソースの追跡」）。番号は実行の中で使い回さない。中身の OS の資源は、作業用のスレッドへ貸している間は表にない。

リソースの状態の遷移は次のとおりである（ADR 0266 の決定 2・5）。タスクの状態との組み合わせの規則は、[ランタイム](../../design/02-impl/02-09-runtime.md)の「リソースの追跡」の表のとおりであり、組み合わせごとにテストを置く。

| 状態 | 貸し出し（`lend`） | 返却（完了の手順 1） | 解放の要求（`request_release`） | 使用 |
|---|---|---|---|---|
| `Open` | `Lent(op, false)` へ | — | ブロックしない解放は `Released` へ、ブロックする解放は `Releasing(op)` へ | 許す |
| `Lent(op, false)` | 返るまで待たせる（`WaitReason::Lend`） | `Open` へ | `Lent(op, true)` へ。返った後に解放を始める | 返るまで待たせる |
| `Lent(op, true)` | 受け付けない（待たせる） | 解放を始める（`Releasing` か `Released` へ） | そのまま（`AfterReturn`。返った後の解放の完了を待つ） | 返るまで待たせる |
| `Releasing(op)` | 解放したリソースの使用 | — | 解放の完了を待つ（`InProgress`） | 解放したリソースの使用 |
| `Released` | 解放したリソースの使用 | —（受け取る側がなければ OS の資源を破棄する） | 何もしない（`AlreadyReleased`。02-08「リソースの解放の枠」）。`TaskGroup` は子の並びを返し直す | 解放したリソースの使用 |

`AlreadyReleased` を返すのは `Released` のときだけである。`Releasing` と、返却の後に解放する `Lent(op, true)` では、解放の枠は解放の完了を待ち続ける（`WaitReason::Release`）。解放を終える前に枠を降ろすと、解放の失敗を報告できず、解放の途中のリソースを残したままタスクが終わるからである（相談の第 7 回の指摘 1）。解放の成否は、完了を待った側が読むまで項目の `release_failure` に残す。

```rust file=src/runtime/io/resources.rs
//! リソースの表と状態（設計書 02-09「リソースの追跡」、ADR 0150・0266）。

use std::collections::{BTreeMap, VecDeque};

use crate::builtins::iface::OsResource;
use crate::runtime::ResourceKind;
use crate::runtime::heap::ResourceId;
use crate::runtime::sched::ExtOpId;
use crate::vm::{InstrRef, TaskId};

/// リソースの状態（ADR 0266 の決定 2）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ResourceState {
    Open,
    /// 作業用のスレッドに貸している。二つ目は閉じる要求があるか
    Lent(ExtOpId, bool),
    /// 解放を行っている
    Releasing(ExtOpId),
    Released,
}

/// リソースの中身。
#[derive(Debug)]
pub enum ResourceContent {
    /// OS の資源。貸している間と解放した後は `None`
    Os(Option<Box<dyn OsResource>>),
    /// `TaskGroup` が起動したタスク（所有しない番号。ADR 0266 の決定 10）
    TaskGroup(Vec<TaskId>),
}

/// リソースの表の項目。
#[derive(Debug)]
pub struct ResourceEntry {
    pub kind: ResourceKind,
    pub content: ResourceContent,
    pub state: ResourceState,
    /// リソースを開いた呼び出しの命令（解放の失敗の報告に使う）
    pub opened_at: Option<InstrRef>,
    /// 貸し出しを受けるために返却を待つタスク（呼んだ順。`WaitReason::Lend`）
    pub waiters: Vec<TaskId>,
    /// 解放の完了を待った側に渡す解放の失敗の理由（`finish_release` が入れ、`take_release_failure` が除く）
    pub release_failure: Option<String>,
}

/// リソースの表（実行ごとに一つ）。
#[derive(Debug, Default)]
pub struct ResourceTable {
    pub entries: BTreeMap<ResourceId, ResourceEntry>,
    /// 作業用のスレッドへまだ出していない、ブロックする解放の仕事（`Releasing` の項目の番号。始めた順）
    pub release_jobs: VecDeque<ResourceId>,
    next: u64,
}

/// 貸し出しの結果。
#[derive(Debug)]
pub enum LendResult {
    Lent(Box<dyn OsResource>),
    /// 返るまで待つ
    MustWait,
    /// 解放したリソースの使用（実行時エラー）
    Released(ResourceKind),
}

/// 解放の要求の結果。
#[derive(Debug)]
pub enum ReleaseStart {
    /// 解放を終えた（失敗は理由）。`TaskGroup` はここに来ない
    Done(Result<(), String>),
    /// 作業用のスレッドで解放する（ブロックする解放）。OS の資源は項目に残し、番号を `release_jobs` に加えた
    Blocking,
    /// 返るまで待ち、返った後に解放する
    AfterReturn,
    /// 解放を行っている（`Releasing`）。完了を待つ
    InProgress,
    /// `TaskGroup`: 子のタスクの終わりを待つか取り消すかは呼び出し側（10-09 の解放の枠）が決める。
    /// 既に `Released` でも子の並びを返す（解放の枠が呼ばれるたびに子を評価し直すため）
    TaskGroup(Vec<TaskId>),
    /// 解放を終えてある（`Released`）
    AlreadyReleased,
}
```

次の関数の中身は R24 が書く。

```rust sig=src/runtime/io/resources.rs
impl ResourceTable {
    pub fn insert(&mut self, kind: ResourceKind, content: ResourceContent, opened_at: Option<InstrRef>) -> ResourceId;
    pub fn state(&self, id: ResourceId) -> Option<ResourceState>;
    /// OS の資源を操作 `op` に貸す。`MustWait` なら `task` を返却を待つ並びの末尾に加える。
    pub fn lend(&mut self, id: ResourceId, op: ExtOpId, task: TaskId) -> LendResult;
    /// 返却を待つ並びから `task` を除く（取り消しと止める手順。すべての項目から除く）。
    pub fn remove_waiter(&mut self, task: TaskId);
    /// 返却を待つ並びの先頭のタスクを除いて返す。
    pub fn pop_waiter(&mut self, id: ResourceId) -> Option<TaskId>;
    /// 貸した資源を返す（完了の手順 1）。閉じる要求があれば `true` を返し、状態を `Open` に戻す。
    /// 呼び出し側は、ほかの処理を挟まずに `request_release` で解放を始める。
    pub fn give_back(&mut self, id: ResourceId, handle: Box<dyn OsResource>) -> bool;
    /// 解放を要求する（`with` を抜けるとき、取り消し、止める手順、E-DropRel、返却の後の解放）。
    pub fn request_release(&mut self, id: ResourceId, op: ExtOpId) -> ReleaseStart;
    /// 作業用のスレッドへまだ出していないブロックする解放の仕事を一つ取り出す。項目の OS の資源を取り出して返す。
    pub fn take_release_job(&mut self) -> Option<(ResourceId, ExtOpId, Box<dyn OsResource>)>;
    /// 解放の完了を記録し、状態を `Released` にする。失敗なら理由を `release_failure` に入れる。
    pub fn finish_release(&mut self, id: ResourceId, result: Result<(), String>);
    /// 解放の完了を待った側が、記録した解放の失敗を一度だけ取り出す。
    pub fn take_release_failure(&mut self, id: ResourceId) -> Option<String>;
    /// 実行を終えるとき、表に残った OS の資源を閉じる（言語の解放ではない。失敗は報告しない）。
    pub fn close_all_silently(&mut self);
}
```

## 出力のバッファと書き出し用のスレッド

標準出力と標準エラー出力ごとに、VM のスレッドのバッファ（`OutputPort`）と、書き出し用のスレッドを一つずつ置く（ADR 0265）。書き込みは VM のスレッドでバッファに加え、転送は書き出し用のスレッドで行う。転送していない量 N は、バッファ・書き出し用のスレッドの列・転送中の量の合計で数える。

| 時点 | 種類 | `OutputPort` の関数 |
|---|---|---|
| バッファが 64 KiB 以上になったとき、進められるタスクがなくなりイベントループで待つ前、端末への出力で改行を書いたとき | 依頼するだけ | `request_transfer` |
| 標準入力を読む前、`Process.runAttached` の前 | その時点までの完了を待つ（`WaitReason::Output(stream, Flush)` でタスクを待たせる） | `request_transfer` と `flush_target` |
| 止める手順の終わり、プログラムを終える前 | 最後の転送と失敗の確かめを終える | `finish` |

書き込みの受け付けは、ADR 0265 の決定 4 のとおり、N + n ≤ B なら加え、n > B なら N = 0 のときに限り加え、それ以外は書き込みを預けて書いたタスクを待たせる（`WaitReason::Output(stream, Capacity)`）。預けた書き込みは呼んだ順に受け付け、後から来た書き込みは追い越さない。待っている間に取り消されたタスクの書き込みは、`cancel_pending` で取り下げる。

書き出し用のスレッドは、失敗と panic を出力ごとの記録（`WriterShared`）に残し、容量と完了の待ちを解く（ADR 0265 の決定 5）。VM のスレッドは、書き込みの関数の中と、転送の依頼と完了の待ちのときにこれを読む。完了の知らせは `Wakeup` でイベントループを起こす。テストの実行器が出力をメモリに捕らえる場合も、同じ転送と完了の手順を通す（同 決定 6）。

```rust file=src/runtime/io/output.rs
//! 出力のバッファと書き出し用のスレッド（設計書 02-09「出力のバッファ」、ADR 0045・0265）。

use std::collections::VecDeque;
use std::io::Write;
use std::sync::{Arc, Condvar, Mutex};
use std::thread::JoinHandle;

use crate::runtime::Stream;
use crate::runtime::panic::PanicReport;
use crate::vm::TaskId;

use super::event::Wakeup;

/// 転送を依頼するバッファの大きさ（64 KiB）。
pub const TRANSFER_THRESHOLD: u64 = 65_536;
/// 転送していない量の上限 B（1 MiB。本章「実装プランで決める値」）。
pub const UNSENT_LIMIT: u64 = 1_048_576;

/// 書き出しの失敗の記録。
#[derive(Clone, PartialEq, Debug)]
pub enum WriteFailure {
    /// `std::io::Error` の文字列
    Io(String),
    /// 書き出し用のスレッドの panic（処理系の不具合）
    Panicked(PanicReport),
}

/// 書き出し用のスレッドと VM のスレッドが共有する状態。
#[derive(Debug, Default)]
pub struct WriterState {
    /// 書き出し用のスレッドの列（転送を依頼したかたまり）
    pub queue: VecDeque<Vec<u8>>,
    /// 転送中の量
    pub in_flight: u64,
    /// 書き出し終えたかたまりの通し番号
    pub done_seq: u64,
    pub failure: Option<WriteFailure>,
    /// 終えるように求めた
    pub shutdown: bool,
}

#[derive(Debug, Default)]
pub struct WriterShared {
    pub state: Mutex<WriterState>,
    pub cond: Condvar,
}

/// 書き込みの受け付けの結果。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Accept {
    Accepted,
    /// 預けた。容量が空くまで書いたタスクを待たせる
    Deferred,
}

/// 出力一つ分の、VM のスレッドの側の状態。
#[derive(Debug)]
pub struct OutputPort {
    pub stream: Stream,
    pub is_terminal: bool,
    buf: Vec<u8>,
    /// 転送を依頼したかたまりの通し番号
    sent_seq: u64,
    /// 預けた書き込み（呼んだ順）
    deferred: VecDeque<(TaskId, Vec<u8>)>,
    /// 完了を待つタスクと、待つ通し番号
    flush_waiters: Vec<(TaskId, u64)>,
    shared: Arc<WriterShared>,
    thread: Option<JoinHandle<()>>,
}
```

次の関数の中身は R27 が書く。

```rust sig=src/runtime/io/output.rs
impl OutputPort {
    /// 書き出し用のスレッドを起こして作る。`sink` は出力先（プロセスの出力か、メモリに捕らえる出力先）。
    pub fn start(stream: Stream, sink: Box<dyn Write + Send>, is_terminal: bool, wakeup: Wakeup) -> OutputPort;
    /// 書き込む（ADR 0265 の決定 4 の規則）。失敗が記録されていれば、それを返す（書いたものは捨てる）。
    pub fn write(&mut self, task: TaskId, text: &[u8]) -> Result<Accept, WriteFailure>;
    /// バッファの中身の転送を依頼する。
    pub fn request_transfer(&mut self);
    /// その時点までに加えた出力の通し番号。完了を待つタスクはこの番号までの完了を待つ。
    pub fn flush_target(&mut self, task: TaskId) -> u64;
    /// 書き出し用のスレッドの知らせを取り込み、容量が空いて受け付けた書き込みのタスクと、
    /// 完了を待ち終えたタスクを返す。失敗が記録されていれば、待つタスクをすべて返す。
    pub fn poll(&mut self) -> (Vec<TaskId>, Option<WriteFailure>);
    /// 取り消したタスクの、預けた書き込みと完了の待ちを取り下げる。
    pub fn cancel_pending(&mut self, task: TaskId);
    /// 最後の転送を依頼し、完了と失敗の確かめを終えるまで待つ。書き出し用のスレッドを終える。
    pub fn finish(&mut self) -> Result<(), WriteFailure>;
}
```

## イベントループ

イベントループは VM のスレッドで `mio` を動かす（ADR 0162）。`Wakeup` は、作業用のスレッド・書き出し用のスレッド・中断の要求がイベントループを起こす口であり、`mio::Waker` を包む。`mio` の型は `runtime::io::event` の外に出さない。

```rust file=src/runtime/io/event.rs
//! イベントループ（設計書 02-09「IO 実行器」、ADR 0162）。`mio` の型はこのモジュールの外に出さない。

use std::sync::Arc;

/// イベントループを起こす口（`mio::Waker` を包む）。ほかのスレッドへ写してよい。
#[derive(Clone, Debug)]
pub struct Wakeup {
    inner: Arc<WakeupInner>,
}

/// `Wakeup` の中身。欄は R26 が決める。
#[derive(Debug)]
pub struct WakeupInner {}
```

```rust sig=src/runtime/io/event.rs
impl Wakeup {
    pub fn wake(&self);
}
```

イベントループの本体（`mio::Poll` の登録と待ち、タイマーとの組み合わせ）は R26 が `event.rs` に書く。`WorkerExec` の実際の実装の `idle` がこれを使う。

## 実行ごとの状態と VM のつなぎ目

`IoRuntime` は、実行ごとの状態のうちランタイムが持つもの（02-09「実行ごとの状態」の表のうち VM が使うもの以外）である。スケジューラ（`Scheduler`）とリソースの表（`ResourceTable`）は、`IoRuntime` に置かず、10-09 の `RunState` の欄 `scheduler`・`resources` に置く。枠を降ろす関数（10-09 の `unwind_*`）が `&mut RunState` だけを受け取り、待つタスクを起こし、リソースの解放を始めるからである。

第 2 段の `IoServices` は、`IoRuntime` と `RunState` のリソースの表を一緒に借りる `IoView` が実装する（リソースの登録 `register_resource` がリソースの表に書くため）。VM は、`io` の組み込みの関数を呼ぶたびに `IoView` を作って `CallCtx` に渡す。`StateServices` は、タスクの表とリソースの表を持つ VM の側が実装する（R23 が一時的な実装を置き、R25 が置き換える）。

VM の第 2 段の実行の関数は、`IoRuntime` を受け取る。第 1 段の `Vm::run_stage1` と `Vm::serve_request_stage1`（10-09）は、R26 がこれに置き換えて消す。

```rust file=src/runtime/io/services.rs
//! 実行ごとの状態のうちランタイムが持つもの（設計書 02-09「実行ごとの状態」）と、VM とのつなぎ目。

use std::path::PathBuf;

use super::event::Wakeup;
use super::ops::{OpTable, StdinReader};
use super::output::OutputPort;
use super::resources::ResourceTable;
use super::{DispatchQueue, Dispatcher};
use crate::runtime::sched::parts::RuntimeParts;

/// 実行の入力（02-11「実行の入力と結果」）。
#[derive(Clone, Debug)]
pub struct RunInput {
    pub arguments: Vec<String>,
    /// 基準のディレクトリ（絶対パス）
    pub working_directory: PathBuf,
    pub script_directory: PathBuf,
}

/// 中断の要求の読み口（02-09「中断の要求」）。CLI ではプロセス全体の印を読む。
pub trait InterruptSource: std::fmt::Debug {
    /// 中断の要求があるか（`Relaxed` で読む。ADR 0263 の決定 4）。
    fn requested(&self) -> bool;
}

/// 実行ごとの状態のうちランタイムが持つもの。欄は R26 が加えてよい（下の欄は変えない）。
/// スケジューラとリソースの表は 10-09 の `RunState` に置く。
#[derive(Debug)]
pub struct IoRuntime {
    pub input: RunInput,
    pub queue: DispatchQueue,
    pub dispatcher: Box<dyn Dispatcher>,
    pub ops: OpTable,
    pub stdout: OutputPort,
    pub stderr: OutputPort,
    /// 標準入力の読み手。作業用のスレッドへ貸している間は `None`
    pub stdin: Option<Box<dyn StdinReader>>,
    pub parts: RuntimeParts,
    pub interrupt: Box<dyn InterruptSource>,
    pub wakeup: Wakeup,
    /// 隠れた乱数の生成器の状態（`Random.fromSeed` と同じ xoshiro256** の 256 ビットの状態。03-07「Random」）。
    /// `IoRuntime::new` は 0 で埋め、`IoView::random_u64` はこの状態で xoshiro256** の一歩を進める。
    /// 実行の始めに OS の乱数から種を入れるのは U3 の L14 である（10-16「隠れた乱数の生成器」）
    pub random_state: [u64; 4],
}

/// 第 2 段の `io` の関数に渡すランタイムの口。`IoRuntime` と、`RunState` のリソースの表を一緒に借りる。
#[derive(Debug)]
pub struct IoView<'a> {
    pub rt: &'a mut IoRuntime,
    pub resources: &'a mut ResourceTable,
}
```

次の関数の中身は R26 が書く。

```rust sig=src/runtime/io/services.rs
use crate::builtins::iface::{IoServices, IoWait, OsResource};
use crate::runtime::heap::ResourceId;
use crate::runtime::{ResourceKind, Stop, Stream};
use crate::vm::{ExecMode, InstrRef, RequestId, Vm, VmStep};

impl IoServices for IoView<'_> {
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop>;
    fn arguments(&self) -> &[String];
    fn script_directory(&self) -> &std::path::Path;
    fn working_directory(&self) -> &std::path::Path;
    fn environment_variable(&self, name: &str) -> Option<std::ffi::OsString>;
    fn now_millis(&self) -> i64;
    fn local_offset_minutes(&self) -> i32;
    fn monotonic_millis(&self) -> i64;
    fn random_u64(&mut self) -> u64;
    fn register_resource(&mut self, kind: ResourceKind, handle: Box<dyn OsResource>, opened_at: Option<InstrRef>) -> ResourceId;
}

impl IoRuntime {
    /// 方式に合った部品（`DirectDispatcher` か `RequestDispatcher`）を入れて作る。
    pub fn new(input: RunInput, mode: ExecMode, outputs: (OutputPort, OutputPort), stdin: Box<dyn StdinReader>, parts: RuntimeParts, interrupt: Box<dyn InterruptSource>, wakeup: Wakeup) -> IoRuntime;
}

impl<'p> Vm<'p> {
    /// タスクを実行する（第 2 段）。要求と応答の方式では `VmStep::Requests` を返して止まる。
    pub fn run(&mut self, rt: &mut IoRuntime) -> VmStep;
    /// 要求と応答の方式で、外側の実行器が要求 `id` をハンドラ表の関数で行う（VM のスレッド）。
    /// 完了なら結果を入れてタスクを起こし、待つなら外部の操作の記録に登録する。
    pub fn serve_request(&mut self, rt: &mut IoRuntime, id: RequestId);
}
```

`Vm::run` と `Vm::serve_request` のファイルは `src/runtime/io/services.rs` とする。VM の内部（`RunState`）に触れるので、R26 は `vm` のモジュールに `pub(crate)` の補助の関数を置いてよい。

## 完了の処理と行き詰まりの判定の順序

VM が待たせる位置と遅い経路で行う順序は次のとおりである（02-08「タスクの切り替え」、ADR 0264 の決定 5、ADR 0266 の決定 8、ADR 0283）。R25・R26 は、この順を一つの関数にまとめ、どちらの方式でも同じ関数を通す。

1. `Dispatcher::on_wait_point` で列の要求を送り出す。続けて、ブロックする解放の仕事（`ResourceTable::take_release_job`）をすべて出す。
2. `WorkerExec::try_recv` で届いた完了をすべて取り込み、`accept_completion` で処理し、結果（`Accepted`）を順に処理する。テスト用の部品では、この境界で筋書きの時間を進める指示と仕事を実行する指示を行う（本章「テストで差し替える部品」）。
3. 出力の `OutputPort::poll` と、期限の来たタイマー（`Scheduler::expire_timers`）を取り込む。
4. 待ち行列が空なら、両方の出力の `request_transfer` を行う。
5. 待ち行列が空で、`Scheduler::is_deadlocked` が真であれば、行き詰まりの実行時エラーとする。止める手順の途中では元の理由を置き換えない。外部の待ちに数えるのは、完了がいずれかのタスクを起こしうるものだけである（ADR 0283）。外部の操作の結果、要求の応答、貸したリソースの返却、解放の完了、出力の容量と転送の完了を待つタスクは、それぞれ `WaitReason` の `Worker`・`Readiness`・`Response`・`Lend`・`Release`・`Output` で待つので、スケジューラの待つタスクの表だけで判定できる。配送先を外した外部の操作の記録（取り消したタスクの標準入力の読み取りなど）と、完了を待つタスクのない出力の転送は、残っていても数えない。この判定が正しいためには、外部の完了で起きるタスクを、必ず上の理由で待たせる（本章「送り出しの列と二つの部品」の段階の表の「待つタスクの理由」）。
6. 待ち行列が空で、手順 5 の行き詰まりでなければ、`WorkerExec::idle` で待ち、1 に戻る。待つ間も中断の印を調べる。

止める手順の途中も、同じ関数を通る。手順 1〜3 で要求の送り出しと完了の取り込みを続け（返却と解放の完了を待つタスクがあるため）、手順 5 では行き詰まりで元の停止の理由を置き換えない。止める手順を始めたときに、生きている要求は `expire_all` で失効させる（相談の第 7 回の指摘 6、[ADR 0282](../../design/decisions/0282-cancellation-timing-during-unwinding-and-requests.md)）。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C02 | 本章のすべての `file=` のコードと、`sig=` の `todo!()` の仮置き（00-02）を置く（C01 が作った中身のないモジュールを埋める） |
| R24 | `ResourceTable` の関数（`take_release_job` を含む。仕事を出すのは R26） |
| R25 | `Scheduler` の関数、`TaskPicker`・`Clock` のテスト用の実装、筋書きの型と筋書きを進める境界（`sched/testing.rs`）、上の順序の関数、`StateServices` の実装 |
| R26 | 送り出しの列と二つの部品、要求の段階と失効、`OpTable`・`accept_completion` と `Accepted` の処理、ブロックする解放の仕事の受け渡し、`WorkerExec` の実際の実装とテスト用の実装、イベントループ、`IoRuntime`・`IoView`、`Vm::run`・`serve_request`、上の順序の関数の手順 1・2。第 1 段の一時的な形（10-09 の `vm/stage1.rs`）を使う箇所（`runtime::run` と VM の単体テスト）をこれらに移してから消す |
| R27 | `OutputPort` と書き出し用のスレッド |
| R28 | 中断の要求の読み口と、ランタイムの止める手順 |
