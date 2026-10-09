# 組み込みの関数の型付きの形

本章は、組み込みの関数（ハンドラ表の関数を含む）を書く形を定める。内部の共通の形（文脈と引数を受け取り、応答か停止を返す関数）、権限ごとの文脈、応答、待つ理由、作業用のスレッドの仕事と完了の処理、引数の読み出しと結果の変換、宣言から包みと登録の項目を作るマクロである。設計書の対応する章は[仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」と[ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」「IO 実行器」であり、判断の根拠は [ADR 0261](../../design/decisions/0261-typed-builtin-interface.md) である。包みの作り方は `macro_rules!` による宣言のマクロとする（[README](../README.md) の「決めたこと」の 7）。

- 置く作業: C01

本章は U2 が持ち、U1 と U3 が使う共有の章である。第 2 段で使う型（`state` の権限の文脈、待つ理由のうちタスクの終わりとリソース）も、応答の型が参照するので、本章で C01 がまとめて置く。その中身（`StateServices` の実装）は第 2 段の作業が書く。組み込みの関数の名前・番号・型の表は 10-12 が定める。

## 権限と応答

組み込みの関数は、三つの権限のどれか一つを持つ。権限ごとに受け取る文脈と返せる応答を分け、権限の誤りをコンパイルの誤りにする（ADR 0261 の決定 3）。

| 権限 | 当たる関数 | 文脈 | 文脈でできること | 返せる応答 |
|---|---|---|---|---|
| `pure` | 純粋な関数（数値、文字列、リスト、`Decimal` など） | `PureCtx` | 作った後に変わらない値の確保と読み出し（10-08 の `ValueCtx`） | 値（完了） |
| `state` | `State` を型に持つ関数（`Reference`・`TaskGroup` の関数、`Task.await`、リソースを解放する関数）と、タスクを起動する関数（`Task.all` など） | `StateCtx` | `pure` のすべて、セル、`Host` の対象（10-08 の `NoGcCtx`）、タスクとリソースの表（`StateServices`） | 完了、待つ（タスクの終わり、リソース）、タスクの起動 |
| `io` | ハンドラ表の関数（組み込みのエフェクトの操作） | `IoCtx` | `pure` のすべて、出力、時計、乱数、実行の入力、リソースの登録（`IoServices`） | 完了、待つ（作業用のスレッド、タイマー、イベントループ、出力）、終了 |

`state` の関数は送り出しの列を通さず、`io` の関数は送り出しの列を通る（[ADR 0264](../../design/decisions/0264-single-dispatch-queue-for-builtin-operations.md) の決定 1）。どちらの関数も、送り出しの列・完了の保存・起動する関数の登録・取り消しとの競合・リソースの返却には触れず、応答を返すだけである。これらは共通の部分（10-10）が行う（ADR 0261 の決定 6）。

待つ理由と起こす規則は、[仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」の表のとおりである。本章の待つ理由の型との対応は次のとおりである。`Lazy` の評価の待ちは VM の命令（`FORCE`）だけが作るので、組み込みの関数の応答には現れない。

| 02-08 の理由 | 本章の型 |
|---|---|
| 作業用のスレッドの仕事 | `IoWait::Worker(WorkerWait)` |
| タイマー（`Clock.sleep`） | `IoWait::Sleep { millis }`。`Task.withTimeout` の期限は `SpawnMode::WithTimeout` が持つ |
| イベントループの準備 | `IoWait::Readiness { resource, interest }` |
| 出力（上限、転送の完了） | `IoWait::Output { stream, kind }` |
| リソース（返却、ブロックする解放の完了） | `StateWait::Resource(ResourceId)` |
| タスクの終わり | `StateWait::TaskEnd(TaskEndTarget)`、`SpawnMode` の待ち方 |

## 作業用のスレッドの仕事

作業用のスレッドに渡す仕事は `Send + 'static` の閉包であり、言語の値を捕えられない（10-08 の不変条件 H8）。完了を言語の値に変える処理は、環境を捕えない `fn` ポインタ（`CompleteFn`）であり、VM のスレッドで `IoCtx` を受け取って動く（ADR 0261 の決定 5）。待つ間に要る言語の値は、仕事にも完了の処理にも捕えず、呼び出しの命令の引数のレジスタに残す。完了の処理は、その引数を `args` として読み直す（10-08「コード生成から受け取る生存の情報」）。

仕事に貸すもの（リソースの OS の資源、標準入力の読み手）は `Lend` で指定する。貸し出しと返却、解放したリソースの使用の判定、取り消したタスクの完了の扱いは、共通の部分が行う（ADR 0266 の決定 4・9）。仕事の閉包が panic したときも、共通の部分が貸したものを返してから処理系の不具合として扱う（10-10）。

標準入力を読む仕事と `Process.runAttached` の仕事は、`WorkerWait::after_output_flush` で「出力の転送の完了を待ってから始める」ことを指定する（[ランタイム](../../design/02-impl/02-09-runtime.md)の「出力のバッファ」の「完了を待つ」時点）。

## 型と文脈

```rust file=src/builtins/iface.rs
//! 組み込みの関数の型付きの形（設計書 02-08「組み込みの関数の呼び出し」、02-09「組み込みの操作とハンドラ表」、ADR 0261）。
//! 実装者は `builtin!` で名前と型の付いた引数を受け取る関数を書き、内部の共通の形（`RawFn`）を直接書かない。

use std::any::Any;
use std::ffi::OsString;
use std::fmt::Debug;
use std::io::BufRead;
use std::ops::{Deref, DerefMut};
use std::path::Path;

use crate::runtime::heap::{NoGcCtx, ResourceId, Value, ValueCtx};
use crate::runtime::{ResourceKind, Stop, Stream};
use crate::vm::{InstrRef, TaskId};

/// 組み込みの関数の権限。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Capability {
    Pure,
    State,
    Io,
}

// ---- 応答と待つ理由 ---------------------------------------------------------

/// 出力の待ちの種類（02-09「出力のバッファ」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum OutputWaitKind {
    /// 転送していない量の上限（容量が空くのを待つ）
    Capacity,
    /// その時点までの転送の完了
    Flush,
}

/// イベントループで待つ準備の種類。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Interest {
    Readable,
    Writable,
}

/// `io` の関数が返せる待つ理由。
#[derive(Debug)]
pub enum IoWait {
    Worker(WorkerWait),
    /// `Clock.sleep`。0 のときは待たずに戻ることを呼び出し側が決める
    Sleep { millis: u64 },
    Readiness { resource: ResourceId, interest: Interest },
    Output { stream: Stream, kind: OutputWaitKind },
}

/// タスクの終わりを待つ先。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TaskEndTarget {
    /// `Task.await`
    Await(TaskId),
    /// `TaskGroup` の解放（子のタスクの終わり）
    TaskGroupRelease(ResourceId),
}

/// `state` の関数が返せる待つ理由。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum StateWait {
    TaskEnd(TaskEndTarget),
    /// 貸しているリソースの返却か、ブロックする解放の完了
    Resource(ResourceId),
}

/// タスクの起動の待ち方（02-08「タスクの起動と待ち方」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SpawnMode {
    All,
    AllOk,
    Race,
    /// 期限のミリ秒（0 以下を 0 に直した値）
    WithTimeout { millis: u64 },
    /// `TaskGroup.spawn`。起動したタスクを待たずに `Task` の値を結果とする
    GroupSpawn { group: ResourceId },
}

/// タスクの起動の応答。
#[derive(Debug)]
pub struct Spawn<'e> {
    /// 引数なしで呼ぶ関数の値の並び
    pub funcs: Vec<Value<'e>>,
    pub mode: SpawnMode,
}

/// `Process.exit` の終了状態。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ExitStatus(pub u8);

/// `state` の関数の応答。
#[derive(Debug)]
pub enum StateReply<'e> {
    Done(Value<'e>),
    Wait(StateWait),
    SpawnTasks(Spawn<'e>),
}

/// `io` の関数の応答（02-09: ハンドラ表の関数が返すのは、完了・待つ・終了のどれか）。
#[derive(Debug)]
pub enum IoReply<'e> {
    Done(Value<'e>),
    Wait(IoWait),
    Exit(ExitStatus),
}

/// 待つ理由（内部の共通の形）。
#[derive(Debug)]
pub enum WaitRequest {
    Io(IoWait),
    State(StateWait),
}

/// 応答（内部の共通の形。ADR 0261 の決定 1）。
#[derive(Debug)]
pub enum Reply<'e> {
    Done(Value<'e>),
    Wait(WaitRequest),
    SpawnTasks(Spawn<'e>),
    Exit(ExitStatus),
}

impl<'e> From<StateReply<'e>> for Reply<'e> {
    fn from(r: StateReply<'e>) -> Reply<'e> {
        match r {
            StateReply::Done(v) => Reply::Done(v),
            StateReply::Wait(w) => Reply::Wait(WaitRequest::State(w)),
            StateReply::SpawnTasks(s) => Reply::SpawnTasks(s),
        }
    }
}

impl<'e> From<IoReply<'e>> for Reply<'e> {
    fn from(r: IoReply<'e>) -> Reply<'e> {
        match r {
            IoReply::Done(v) => Reply::Done(v),
            IoReply::Wait(w) => Reply::Wait(WaitRequest::Io(w)),
            IoReply::Exit(s) => Reply::Exit(s),
        }
    }
}

// ---- 作業用のスレッドの仕事 -------------------------------------------------

/// リソースの OS の資源（ファイル、ソケットなど）。作業用のスレッドに貸すので `Send` にする。
/// 言語の値を持たない。
pub trait OsResource: Send + Debug + Any {
    /// 具体的な型で操作するために、`Any` として借りる。
    fn as_any_mut(&mut self) -> &mut dyn Any;
    /// 解放の処理（02-09「リソースの追跡」のリソースの型ごとの解放）。作業用のスレッドで呼ぶ。
    /// 失敗は理由の文字列で返す。
    fn release(self: Box<Self>) -> Result<(), String>;
}

/// 仕事に貸すものの指定。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Lend {
    Nothing,
    Resource(ResourceId),
    /// 実行ごとの状態の標準入力の読み手
    Stdin,
}

/// 作業用のスレッドで、仕事が借りたもの。
pub enum Lent<'a> {
    Nothing,
    Resource(&'a mut dyn OsResource),
    Stdin(&'a mut dyn BufRead),
}

/// 完了を言語の値に変える処理。環境を捕えない `fn` ポインタである（ADR 0261 の決定 5）。
/// `args` は、待った組み込みの関数の呼び出しの引数（レジスタから読み直したもの）。
pub type CompleteFn<O> = for<'c, 'e> fn(&mut IoCtx<'c, 'e>, O, &[Value<'e>]) -> Result<Value<'e>, Stop>;

trait ErasedDone: Send {
    fn complete<'c, 'e>(self: Box<Self>, ctx: &mut IoCtx<'c, 'e>, args: &[Value<'e>]) -> Result<Value<'e>, Stop>;
}

struct Pending<O> {
    output: O,
    complete: CompleteFn<O>,
}

impl<O: Send> ErasedDone for Pending<O> {
    fn complete<'c, 'e>(self: Box<Self>, ctx: &mut IoCtx<'c, 'e>, args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
        (self.complete)(ctx, self.output, args)
    }
}

type ErasedJob = Box<dyn for<'a> FnOnce(Lent<'a>) -> Box<dyn ErasedDone> + Send>;

/// 作業用のスレッドの仕事と、完了の処理の組。
pub struct WorkerWait {
    job: ErasedJob,
    lend: Lend,
    after_output_flush: bool,
}

impl Debug for WorkerWait {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WorkerWait")
            .field("lend", &self.lend)
            .field("after_output_flush", &self.after_output_flush)
            .finish_non_exhaustive()
    }
}

impl WorkerWait {
    /// 仕事 `job`（作業用のスレッドで一度だけ呼ぶ）と、完了の処理 `complete` を組にする。
    pub fn new<O: Send + 'static>(
        lend: Lend,
        job: impl for<'a> FnOnce(Lent<'a>) -> O + Send + 'static,
        complete: CompleteFn<O>,
    ) -> WorkerWait {
        WorkerWait {
            job: Box::new(move |lent| {
                let output = job(lent);
                let done: Box<dyn ErasedDone> = Box::new(Pending { output, complete });
                done
            }),
            lend,
            after_output_flush: false,
        }
    }

    /// 出力の転送の完了を待ってから仕事を始める（標準入力の読み取り、`Process.runAttached`）。
    pub fn after_output_flush(mut self) -> WorkerWait {
        self.after_output_flush = true;
        self
    }

    pub fn lend(&self) -> Lend {
        self.lend
    }

    pub fn needs_output_flush(&self) -> bool {
        self.after_output_flush
    }

    /// 仕事を実行する（作業用のスレッド、またはテスト用の実装では VM のスレッド。ADR 0274）。
    pub fn run(self, lent: Lent<'_>) -> WorkerDone {
        WorkerDone {
            done: (self.job)(lent),
        }
    }
}

/// 実行を終えた仕事。VM のスレッドへ送り、完了の処理を呼ぶ。
pub struct WorkerDone {
    done: Box<dyn ErasedDone>,
}

impl Debug for WorkerDone {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WorkerDone").finish_non_exhaustive()
    }
}

impl WorkerDone {
    /// 完了の処理を呼び、結果の値を作る（VM のスレッド）。
    pub fn complete<'c, 'e>(self, ctx: &mut IoCtx<'c, 'e>, args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
        self.done.complete(ctx, args)
    }
}

// ---- ランタイムの口 ---------------------------------------------------------

/// `io` の関数が使うランタイムの口。第 1 段は一時的な実装（10-09「第 1 段の実行の関数」）、
/// 第 2 段は 10-10 の実行ごとの状態が実装する。
pub trait IoServices {
    /// 出力のバッファに書く（02-09「出力のバッファ」）。受け付けたら `None`、転送していない量の上限で
    /// 受け付けられなければ、書き込みを預けたうえで待つ理由を返す。書き出しの失敗が記録されていれば、
    /// 書き込みの失敗の実行時エラーを返す。
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop>;
    /// コマンドライン引数（`Process.arguments`）
    fn arguments(&self) -> &[String];
    fn script_directory(&self) -> &Path;
    /// 基準のディレクトリ（02-09「実行ごとの状態」）
    fn working_directory(&self) -> &Path;
    fn environment_variable(&self, name: &str) -> Option<OsString>;
    /// UTC の 1970-01-01 からのミリ秒（`Clock.now`）。時計は 10-10 の差し替えられる部品が決める
    fn now_millis(&self) -> i64;
    /// 地方時の UTC からの差（分）
    fn local_offset_minutes(&self) -> i32;
    /// 実行を始めてからの単調な時計のミリ秒（`Clock.monotonicMilliseconds`）
    fn monotonic_millis(&self) -> i64;
    /// 隠れた乱数の生成器から次の 64 ビットを得る（`Random.Generate`）
    fn random_u64(&mut self) -> u64;
    /// 開いたリソースを表に加える（02-09「リソースの追跡」）。完了の処理から呼ぶ
    fn register_resource(
        &mut self,
        kind: ResourceKind,
        handle: Box<dyn OsResource>,
        opened_at: Option<InstrRef>,
    ) -> ResourceId;
}

/// `Task.await` の結果。
#[derive(Debug)]
pub enum TaskPoll<'e> {
    Done(Value<'e>),
    /// まだ終わっていない。この番号の終わりを待つ
    Pending(TaskId),
}

/// `state` の関数が使うランタイムの口。第 2 段の VM の側が実装する（R23 が一時的な実装を置き、R25 が置き換える）。
pub trait StateServices {
    /// `Task` の値のタスクが終わっていれば結果を返す。
    fn task_poll<'e>(&mut self, ctx: &NoGcCtx<'e>, task: Value<'e>) -> Result<TaskPoll<'e>, Stop>;
    /// 空の `TaskGroup` をリソースの表に加える。
    fn open_task_group(&mut self, opened_at: Option<InstrRef>) -> ResourceId;
    /// リソースの解放を始める（02-08「リソースの解放の枠」）。すぐに終われば `None`、待つなら待つ理由を返す。
    /// 解放の失敗は、リソースの型の規則に従って `Stop` にするか無視する。
    fn begin_release(&mut self, resource: ResourceId) -> Result<Option<StateWait>, Stop>;
}

// ---- 文脈 -----------------------------------------------------------------

/// VM が組み込みの関数を呼ぶときに作る文脈（内部の共通の形）。
pub struct CallCtx<'c, 'e> {
    heap: &'c mut NoGcCtx<'e>,
    io: Option<&'c mut dyn IoServices>,
    state: Option<&'c mut dyn StateServices>,
    site: Option<InstrRef>,
}

impl<'c, 'e> CallCtx<'c, 'e> {
    /// VM が作る。`site` は組み込みの関数を呼んだ命令（リソースを開いた位置の記録に使う）。
    pub fn new(
        heap: &'c mut NoGcCtx<'e>,
        io: Option<&'c mut dyn IoServices>,
        state: Option<&'c mut dyn StateServices>,
        site: Option<InstrRef>,
    ) -> CallCtx<'c, 'e> {
        CallCtx { heap, io, state, site }
    }

    #[doc(hidden)]
    pub fn pure_ctx(&'c self) -> PureCtx<'c, 'e> {
        PureCtx { values: self.heap }
    }

    #[doc(hidden)]
    pub fn io_ctx(&'c mut self) -> Result<IoCtx<'c, 'e>, Stop> {
        match self.io.as_deref_mut() {
            Some(services) => Ok(IoCtx {
                values: self.heap,
                services,
                site: self.site,
            }),
            None => Err(Stop::Internal(String::from("io builtin called without io services"))),
        }
    }

    #[doc(hidden)]
    pub fn state_ctx(&'c mut self) -> Result<StateCtx<'c, 'e>, Stop> {
        match self.state.as_deref_mut() {
            Some(services) => Ok(StateCtx {
                heap: self.heap,
                services,
                site: self.site,
            }),
            None => Err(Stop::Internal(String::from("state builtin called without state services"))),
        }
    }
}

/// `pure` の関数の文脈。作った後に変わらない値の確保と読み出しだけができる。
#[derive(Clone, Copy)]
pub struct PureCtx<'c, 'e> {
    values: &'c ValueCtx<'e>,
}

impl<'c, 'e> PureCtx<'c, 'e> {
    /// 区間の寿命 `'c` の間借りる値の文脈（`&str` の引数を読むときに使う）。
    pub fn values(self) -> &'c ValueCtx<'e> {
        self.values
    }
}

impl<'c, 'e> Deref for PureCtx<'c, 'e> {
    type Target = ValueCtx<'e>;

    fn deref(&self) -> &ValueCtx<'e> {
        self.values
    }
}

/// `io` の関数と完了の処理の文脈。
pub struct IoCtx<'c, 'e> {
    values: &'c ValueCtx<'e>,
    services: &'c mut dyn IoServices,
    site: Option<InstrRef>,
}

impl<'c, 'e> IoCtx<'c, 'e> {
    pub fn values(&self) -> &'c ValueCtx<'e> {
        self.values
    }

    pub fn services(&mut self) -> &mut dyn IoServices {
        &mut *self.services
    }

    /// 組み込みの関数を呼んだ命令。
    pub fn site(&self) -> Option<InstrRef> {
        self.site
    }
}

impl<'c, 'e> Deref for IoCtx<'c, 'e> {
    type Target = ValueCtx<'e>;

    fn deref(&self) -> &ValueCtx<'e> {
        self.values
    }
}

/// `state` の関数の文脈。
pub struct StateCtx<'c, 'e> {
    heap: &'c mut NoGcCtx<'e>,
    services: &'c mut dyn StateServices,
    site: Option<InstrRef>,
}

impl<'c, 'e> StateCtx<'c, 'e> {
    pub fn services(&mut self) -> &mut dyn StateServices {
        &mut *self.services
    }

    pub fn site(&self) -> Option<InstrRef> {
        self.site
    }

    /// タスクの状態を読む。`StateServices::task_poll` はヒープと実行時のサービスを同時に要るが、
    /// `services()` は文脈の全体を可変で借りるので、二つを分けて借りてこの関数から呼ぶ（R25 で加えた）。
    pub fn task_poll(&mut self, task: Value<'e>) -> Result<TaskPoll<'e>, Stop> {
        self.services.task_poll(&*self.heap, task)
    }
}

impl<'c, 'e> Deref for StateCtx<'c, 'e> {
    type Target = NoGcCtx<'e>;

    fn deref(&self) -> &NoGcCtx<'e> {
        self.heap
    }
}

impl<'c, 'e> DerefMut for StateCtx<'c, 'e> {
    fn deref_mut(&mut self) -> &mut NoGcCtx<'e> {
        self.heap
    }
}

// ---- 引数と結果 -------------------------------------------------------------

/// 引数の値を Rust の型にする（借用しない型）。`state` の関数の引数はこの型に限る。
pub trait FromValue<'e>: Sized {
    fn from_value(v: Value<'e>) -> Option<Self>;
}

/// 引数の値を Rust の型にする。`&'c str` など、区間の中の対象を借りる型を含む。
pub trait FromArg<'c, 'e>: Sized {
    fn from_arg(values: &'c ValueCtx<'e>, v: Value<'e>) -> Option<Self>;
}

impl<'c, 'e, T: FromValue<'e>> FromArg<'c, 'e> for T {
    fn from_arg(_values: &'c ValueCtx<'e>, v: Value<'e>) -> Option<T> {
        T::from_value(v)
    }
}

impl<'e> FromValue<'e> for Value<'e> {
    fn from_value(v: Value<'e>) -> Option<Value<'e>> {
        Some(v)
    }
}

impl<'e> FromValue<'e> for i64 {
    fn from_value(v: Value<'e>) -> Option<i64> {
        v.as_int()
    }
}

impl<'e> FromValue<'e> for f64 {
    fn from_value(v: Value<'e>) -> Option<f64> {
        v.as_float()
    }
}

impl<'e> FromValue<'e> for u8 {
    fn from_value(v: Value<'e>) -> Option<u8> {
        v.as_byte()
    }
}

impl<'e> FromValue<'e> for bool {
    fn from_value(v: Value<'e>) -> Option<bool> {
        v.as_bool()
    }
}

impl<'e> FromValue<'e> for char {
    fn from_value(v: Value<'e>) -> Option<char> {
        v.as_char()
    }
}

impl<'e> FromValue<'e> for ResourceId {
    fn from_value(v: Value<'e>) -> Option<ResourceId> {
        v.as_resource()
    }
}

impl<'c, 'e> FromArg<'c, 'e> for &'c str {
    fn from_arg(values: &'c ValueCtx<'e>, v: Value<'e>) -> Option<&'c str> {
        values.str(v)
    }
}

impl<'c, 'e> FromArg<'c, 'e> for &'c [u8] {
    fn from_arg(values: &'c ValueCtx<'e>, v: Value<'e>) -> Option<&'c [u8]> {
        values.bytes(v)
    }
}

/// `pure` の関数の結果を値にする。確保の要らない型だけに実装する。文字列やリストは、関数の中で
/// 大きさを確かめる確保の関数（10-08）で値にしてから `Value` で返す。Rust の `String` などには実装しない
/// （大きさを確かめない値の作り方を型で塞ぐ。ADR 0261 の決定 4）。
pub trait IntoValue<'e> {
    fn into_value(self) -> Value<'e>;
}

impl<'e> IntoValue<'e> for Value<'e> {
    fn into_value(self) -> Value<'e> {
        self
    }
}

impl<'e> IntoValue<'e> for i64 {
    fn into_value(self) -> Value<'e> {
        Value::Int(self)
    }
}

impl<'e> IntoValue<'e> for f64 {
    fn into_value(self) -> Value<'e> {
        Value::Float(self)
    }
}

impl<'e> IntoValue<'e> for u8 {
    fn into_value(self) -> Value<'e> {
        Value::Byte(self)
    }
}

impl<'e> IntoValue<'e> for bool {
    fn into_value(self) -> Value<'e> {
        Value::Bool(self)
    }
}

impl<'e> IntoValue<'e> for char {
    fn into_value(self) -> Value<'e> {
        Value::Char(self)
    }
}

impl<'e> IntoValue<'e> for () {
    fn into_value(self) -> Value<'e> {
        Value::Unit
    }
}

// ---- 登録 -----------------------------------------------------------------

/// 内部の共通の形（ADR 0261 の決定 1）。`builtin!` が作り、実装者は直接書かない。
pub type RawFn = for<'c, 'e> fn(&'c mut CallCtx<'c, 'e>, &[Value<'e>]) -> Result<Reply<'e>, Stop>;

/// 組み込みの関数の登録の項目。`builtin!` が関数ごとに `DECL` として作る。
#[derive(Clone, Copy)]
pub struct BuiltinDecl {
    /// 修飾した名前（`String.byteLength` など。10-12 の表の名前と一致させる）
    pub name: &'static str,
    pub capability: Capability,
    pub arity: u16,
    pub raw: RawFn,
}

impl Debug for BuiltinDecl {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("BuiltinDecl")
            .field("name", &self.name)
            .field("capability", &self.capability)
            .field("arity", &self.arity)
            .finish_non_exhaustive()
    }
}

#[doc(hidden)]
pub fn arg_mismatch(name: &'static str) -> Stop {
    Stop::Internal(format!("builtin {name}: argument count or kind mismatch"))
}
```

## 宣言のマクロ

組み込みの関数は `builtin!` で宣言する。一つの宣言から、次の三つを作る。

- 実装者が書いた本体を持つ関数 `$name`（名前と型の付いた引数を受け取る。単体テストはこの関数を直接呼ぶ）
- 子のモジュール `$name` の中の、内部の共通の形の包み（引数を読み出し、応答を `Reply` にする。非公開）。子のモジュールは `use super::*;` で親のモジュールの名前を取り込み、引数と結果の型の名前を宣言を書いたモジュールと同じく解決する
- 子のモジュール `$name` の中の登録の項目 `$name::DECL`

関数と子のモジュールは、Rust の別の名前空間にあるので、同じ名前でよい。10-12 の組み込みの表は、`DECL` を集めて作る。

書き方は次のとおりである。`'c` は文脈を借りる寿命、`'e` は回収しない区間の寿命であり、引数と結果の型に書いてよい。

```text
builtin! {
    /// ドキュメントコメント
    name = "String.byteLength",
    pure fn string_byte_length(ctx, s: &'c str) -> i64 { ... }
}
```

| 権限 | 本体の関数の形 | 引数の型 | 結果の型 |
|---|---|---|---|
| `pure` | `fn $name<'c, 'e>(ctx: PureCtx<'c, 'e>, 引数...) -> Result<R, Stop>` | `FromArg<'c, 'e>` を実装する型 | `IntoValue<'e>` を実装する型 `R` |
| `state` | `fn $name<'c, 'e>(ctx: StateCtx<'c, 'e>, 引数...) -> Result<StateReply<'e>, Stop>` | `FromValue<'e>` を実装する型（文脈を可変で借りるので、借用する引数は読めない） | `StateReply<'e>` |
| `io` | `fn $name<'c, 'e>(ctx: IoCtx<'c, 'e>, 引数...) -> Result<IoReply<'e>, Stop>` | `FromArg<'c, 'e>` を実装する型 | `IoReply<'e>` |

引数の個数か種類が違うとき（型検査を通ったプログラムでは起きない）、包みは `Stop::Internal` を返す。

```rust file=src/builtins/iface.rs
/// 組み込みの関数を宣言する（本章「宣言のマクロ」）。
///
/// 次の例は、権限と値の作り方の誤りがコンパイルの誤りになることを確かめる（10-11「コンパイルの失敗のテスト」）。
#[macro_export]
macro_rules! builtin {
    (
        $(#[$meta:meta])*
        name = $qname:literal,
        pure fn $name:ident ($ctx:ident $(, $arg:ident : $ty:ty)* $(,)?) -> $ret:ty $body:block
    ) => {
        $(#[$meta])*
        pub fn $name<'c, 'e>(
            $ctx: $crate::builtins::iface::PureCtx<'c, 'e>,
            $($arg: $ty),*
        ) -> ::core::result::Result<$ret, $crate::runtime::Stop> $body

        pub mod $name {
            // 引数と結果の型の名前を、宣言を書いたモジュールと同じく解決する。本体の関数もこの取り込みで呼ぶ。
            use super::*;

            fn raw<'c, 'e>(
                call: &'c mut $crate::builtins::iface::CallCtx<'c, 'e>,
                args: &[$crate::runtime::heap::Value<'e>],
            ) -> ::core::result::Result<$crate::builtins::iface::Reply<'e>, $crate::runtime::Stop> {
                let ctx = call.pure_ctx();
                let mismatch = || $crate::builtins::iface::arg_mismatch($qname);
                let mut it = args.iter().copied();
                $(
                    let $arg = it
                        .next()
                        .and_then(|v| <$ty as $crate::builtins::iface::FromArg<'c, 'e>>::from_arg(ctx.values(), v))
                        .ok_or_else(mismatch)?;
                )*
                if it.next().is_some() {
                    return Err(mismatch());
                }
                let r = $name(ctx, $($arg),*)?;
                Ok($crate::builtins::iface::Reply::Done(
                    $crate::builtins::iface::IntoValue::into_value(r),
                ))
            }

            pub const DECL: $crate::builtins::iface::BuiltinDecl = $crate::builtins::iface::BuiltinDecl {
                name: $qname,
                capability: $crate::builtins::iface::Capability::Pure,
                arity: <[&str]>::len(&[$(stringify!($arg)),*]) as u16,
                raw,
            };
        }
    };
    (
        $(#[$meta:meta])*
        name = $qname:literal,
        state fn $name:ident ($ctx:ident $(, $arg:ident : $ty:ty)* $(,)?) -> $ret:ty $body:block
    ) => {
        $(#[$meta])*
        pub fn $name<'c, 'e>(
            $ctx: $crate::builtins::iface::StateCtx<'c, 'e>,
            $($arg: $ty),*
        ) -> ::core::result::Result<$ret, $crate::runtime::Stop> $body

        pub mod $name {
            // 引数と結果の型の名前を、宣言を書いたモジュールと同じく解決する。本体の関数もこの取り込みで呼ぶ。
            use super::*;

            fn raw<'c, 'e>(
                call: &'c mut $crate::builtins::iface::CallCtx<'c, 'e>,
                args: &[$crate::runtime::heap::Value<'e>],
            ) -> ::core::result::Result<$crate::builtins::iface::Reply<'e>, $crate::runtime::Stop> {
                let mismatch = || $crate::builtins::iface::arg_mismatch($qname);
                let mut it = args.iter().copied();
                $(
                    let $arg = it
                        .next()
                        .and_then(<$ty as $crate::builtins::iface::FromValue<'e>>::from_value)
                        .ok_or_else(mismatch)?;
                )*
                if it.next().is_some() {
                    return Err(mismatch());
                }
                let ctx = call.state_ctx()?;
                let r: $crate::builtins::iface::StateReply<'e> = $name(ctx, $($arg),*)?;
                Ok($crate::builtins::iface::Reply::from(r))
            }

            pub const DECL: $crate::builtins::iface::BuiltinDecl = $crate::builtins::iface::BuiltinDecl {
                name: $qname,
                capability: $crate::builtins::iface::Capability::State,
                arity: <[&str]>::len(&[$(stringify!($arg)),*]) as u16,
                raw,
            };
        }
    };
    (
        $(#[$meta:meta])*
        name = $qname:literal,
        io fn $name:ident ($ctx:ident $(, $arg:ident : $ty:ty)* $(,)?) -> $ret:ty $body:block
    ) => {
        $(#[$meta])*
        pub fn $name<'c, 'e>(
            $ctx: $crate::builtins::iface::IoCtx<'c, 'e>,
            $($arg: $ty),*
        ) -> ::core::result::Result<$ret, $crate::runtime::Stop> $body

        pub mod $name {
            // 引数と結果の型の名前を、宣言を書いたモジュールと同じく解決する。本体の関数もこの取り込みで呼ぶ。
            use super::*;

            fn raw<'c, 'e>(
                call: &'c mut $crate::builtins::iface::CallCtx<'c, 'e>,
                args: &[$crate::runtime::heap::Value<'e>],
            ) -> ::core::result::Result<$crate::builtins::iface::Reply<'e>, $crate::runtime::Stop> {
                let ctx = call.io_ctx()?;
                let mismatch = || $crate::builtins::iface::arg_mismatch($qname);
                let mut it = args.iter().copied();
                $(
                    let $arg = it
                        .next()
                        .and_then(|v| <$ty as $crate::builtins::iface::FromArg<'c, 'e>>::from_arg(ctx.values(), v))
                        .ok_or_else(mismatch)?;
                )*
                if it.next().is_some() {
                    return Err(mismatch());
                }
                let r: $crate::builtins::iface::IoReply<'e> = $name(ctx, $($arg),*)?;
                Ok($crate::builtins::iface::Reply::from(r))
            }

            pub const DECL: $crate::builtins::iface::BuiltinDecl = $crate::builtins::iface::BuiltinDecl {
                name: $qname,
                capability: $crate::builtins::iface::Capability::Io,
                arity: <[&str]>::len(&[$(stringify!($arg)),*]) as u16,
                raw,
            };
        }
    };
}

pub use builtin;
```

`builtin!` はクレートの外（rustdoc の例）からも使えるように `#[macro_export]` にする。クレートの中では `crate::builtins::iface::builtin` として使う。

マクロの中の `as u16` は、引数の名前の数（関数の引数の個数であり、どの組み込みの関数でも 16 ビットに収まる）の変換である（[実装の規約](../00-common/00-02-conventions.md)の「数値の変換」）。引数の数を `<[&str]>::len(&[…])` の形で数えるのは、引数のない関数（`TaskGroup.open` など）で配列が空になっても要素の型が決まるようにするためである。`[…].len()` と書くと、空の配列の要素の型を推論できず、コンパイルの誤り（E0282）になる（Rust 1.98.1 で確かめた）。

`name` に書く名前は、[組み込みの関数の表](10-12-builtin-table.md)の「名前の付け方」に従う。後述の例の `Benitoite.IO.File.readText` は組み込みのエフェクトの操作なので `Benitoite.` から始まり、`@builtin` を付けて宣言した関数（`Integer.absolute` など）は `Benitoite.` を除いた名前である。

## 例

純粋な関数（`Integer` の加算の溢れを確かめる例）:

```text
builtin! {
    /// `Integer.absolute`
    name = "Integer.absolute",
    pure fn integer_absolute(ctx, n: i64) -> i64 {
        let _ = ctx;
        n.checked_abs().ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}
```

文字列を作る関数（大きさを確かめる確保の関数を使う）:

```text
builtin! {
    name = "String.repeat",
    pure fn string_repeat(ctx, s: &'c str, n: i64) -> Value<'e> {
        let mut buf = StrBuf::new("String.repeat");
        for _ in 0..n.max(0) {
            buf.push_str(s)?; // 上限を超えたら資源の不足（02-09 の計算で先に判定してもよい）
        }
        ctx.alloc_str_buf(buf)
    }
}
```

待つ関数（ファイルを読み、完了の処理で文字列の値にする）:

```text
fn read_text_done<'c, 'e>(ctx: &mut IoCtx<'c, 'e>, out: Result<Vec<u8>, IoFailure>, _args: &[Value<'e>])
    -> Result<Value<'e>, Stop> { ... } // UTF-8 と上限を確かめて Result.Ok か Result.Error を作る

builtin! {
    name = "Benitoite.IO.File.readText",
    io fn file_read_text(ctx, path: &'c str) -> IoReply<'e> {
        let path = ctx.services().working_directory().join(path); // 捕えるのは Send の PathBuf だけ
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_lent| read_limited(&path),
            read_text_done,
        ))))
    }
}
```

## コンパイルの失敗のテスト

次の例は、ADR 0261 の決定 7 の「誤った引数の型・結果の型・権限・捕捉がコンパイルで止まる」ことを確かめる。R07 は、これらを `builtin!` の `///` のコメントに rustdoc の例として置き、以後の作業は消さない。10-08 の「コンパイルの失敗のテスト」と同じく、各例には、違反する一行だけを変えた `no_run` の例を並べる。`builtin!` は子のモジュールから親のモジュールの本体の関数を呼ぶので、例は `fn main() {}` を明示して、宣言を関数の外（モジュールの直下）に置く。rustdoc が例を `fn main` で包むと、子のモジュールから本体の関数が見えず、違反と別の理由で失敗する（2026-09-30 に確かめた。対にした通る例がこの失敗を見つけた）。

純粋な関数が待つ応答を返す（権限の誤り）:

```rust,compile_fail
use benitoite::builtins::iface::{IoReply, IoWait};
benitoite::builtin! {
    name = "Test.pureWaits",
    pure fn pure_waits(ctx, ms: i64) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Sleep { millis: ms.unsigned_abs() })) // IoReply は IntoValue でない
    }
}
fn main() {}
```

```rust,no_run
benitoite::builtin! {
    name = "Test.pureWaits",
    pure fn pure_waits(ctx, ms: i64) -> i64 {
        let _ = ctx;
        Ok(ms)
    }
}
fn main() {}
```

純粋な関数が IO の口を使う（権限の誤り）:

```rust,compile_fail
benitoite::builtin! {
    name = "Test.pureWrites",
    pure fn pure_writes(ctx, s: &'c str) -> () {
        ctx.services().write_output(benitoite::runtime::Stream::Stdout, s)?; // PureCtx に services はない
        Ok(())
    }
}
fn main() {}
```

```rust,no_run
benitoite::builtin! {
    name = "Test.pureWrites",
    pure fn pure_writes(ctx, s: &'c str) -> () {
        let _ = ctx.str(benitoite::runtime::heap::Value::Unit);
        let _ = s;
        Ok(())
    }
}
fn main() {}
```

大きさを確かめずに Rust の `String` を結果にする（値の作り方の誤り）:

```rust,compile_fail
benitoite::builtin! {
    name = "Test.unchecked",
    pure fn unchecked(ctx, s: &'c str) -> String {
        let _ = ctx;
        Ok(s.repeat(2)) // String は IntoValue でない
    }
}
fn main() {}
```

```rust,no_run
use benitoite::runtime::heap::Value;
benitoite::builtin! {
    name = "Test.unchecked",
    pure fn unchecked(ctx, s: &'c str) -> Value<'e> {
        ctx.alloc_str_parts(&[s, s], "Test.unchecked")
    }
}
fn main() {}
```

`state` の関数が借用する引数を読む（引数の型の誤り）:

```rust,compile_fail
use benitoite::builtins::iface::StateReply;
benitoite::builtin! {
    name = "Test.stateBorrows",
    state fn state_borrows(ctx, s: &'c str) -> StateReply<'e> { // &str は FromValue でない
        let _ = (ctx, s);
        Ok(StateReply::Done(benitoite::runtime::heap::Value::Unit))
    }
}
fn main() {}
```

```rust,no_run
use benitoite::builtins::iface::StateReply;
benitoite::builtin! {
    name = "Test.stateBorrows",
    state fn state_borrows(ctx, n: i64) -> StateReply<'e> {
        let _ = (ctx, n);
        Ok(StateReply::Done(benitoite::runtime::heap::Value::Unit))
    }
}
fn main() {}
```

作業用のスレッドの仕事が言語の値を捕える（捕捉の誤り）:

```rust,compile_fail
use benitoite::builtins::iface::{IoCtx, IoReply, IoWait, Lend, WorkerWait};
use benitoite::runtime::{Stop, heap::Value};
fn done<'c, 'e>(_ctx: &mut IoCtx<'c, 'e>, _out: (), _args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
    Ok(Value::Unit)
}
benitoite::builtin! {
    name = "Test.capturesValue",
    io fn captures_value(ctx, v: Value<'e>) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Nothing, move |_lent| drop(v), done)))) // Value は Send でない
    }
}
fn main() {}
```

```rust,no_run
use benitoite::builtins::iface::{IoCtx, IoReply, IoWait, Lend, WorkerWait};
use benitoite::runtime::{Stop, heap::Value};
fn done<'c, 'e>(_ctx: &mut IoCtx<'c, 'e>, _out: (), _args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
    Ok(Value::Unit)
}
benitoite::builtin! {
    name = "Test.capturesValue",
    io fn captures_value(ctx, v: Value<'e>) -> IoReply<'e> {
        let _ = (ctx, v);
        let n = 1_u64;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Nothing, move |_lent| drop(n), done))))
    }
}
fn main() {}
```

完了の処理が環境を捕える（捕捉の誤り）:

```rust,compile_fail
use benitoite::builtins::iface::{IoReply, IoWait, Lend, WorkerWait};
use benitoite::runtime::heap::Value;
benitoite::builtin! {
    name = "Test.capturingCompletion",
    io fn capturing_completion(ctx, n: i64) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            |_lent| (),
            move |_ctx, _out: (), _args| Ok(Value::Int(n)), // 捕える閉包は fn ポインタにならない
        ))))
    }
}
fn main() {}
```

```rust,no_run
use benitoite::builtins::iface::{IoReply, IoWait, Lend, WorkerWait};
use benitoite::runtime::heap::Value;
benitoite::builtin! {
    name = "Test.capturingCompletion",
    io fn capturing_completion(ctx, n: i64) -> IoReply<'e> {
        let _ = (ctx, n);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            |_lent| (),
            |_ctx, _out: (), _args| Ok(Value::Int(0)),
        ))))
    }
}
fn main() {}
```

## 登録と第 1 段の扱い

組み込みの関数を書くモジュールは、宣言した関数の `DECL` を並べた定数 `pub const DECLS: &[BuiltinDecl]` を持つ。組み込みの表は、これを集め、組み込みの関数の番号から `BuiltinDecl` を引く表を作る。VM は `IO` と `PRIM` の命令で、命令の B が指す組み込みの関数の参照（10-07 の `BuiltinRef`）の `id` で `builtin_decl` を引き、`CallCtx` を作って `raw` を呼ぶ。引数の数・権限・操作は `BuiltinRef` の `arity`・`capability`・`op` から決め、表を引かない（10-07「コンパイル済みプログラム」）。`BuiltinRef::arity` と `capability` は、コード生成が `BuiltinDecl::arity`・`capability` を写したものである。応答の処理は次のとおりである。

| 応答 | 第 1 段（R09） | 第 2 段（R25・R26） |
|---|---|---|
| `Reply::Done` | 結果のレジスタに入れる | 同じ |
| `Reply::Wait(WaitRequest::Io(IoWait::Worker(w)))` | 仕事をその場で実行し（`WorkerWait::run`）、`WorkerDone::complete` で結果を作る（10-09「第 1 段の実行の関数」） | 10-10 の外部の操作の記録に登録し、タスクを待たせる |
| ほかの `Reply::Wait` | `Stop::Internal` | 10-10 の待つ理由に変えて、タスクを待たせる |
| `Reply::SpawnTasks` | `Stop::Internal` | 10-09 のタスクの起動 |
| `Reply::Exit` | 止める手順を `Process.exit` として始める | 同じ |

最小実行版の組み込みの関数と組み込みの表は、C04 が `src/legacy/builtins/` へ移し、最小実行版の実装が C18 まで使う。初回リリース版の `builtins` は、C01 が次の三つを置いて始める。

- `src/builtins/mod.rs`: 子のモジュールの宣言と、組み込みの関数の番号 `BuiltinId`。10-07 の `BuiltinRef`、10-04 の名前解決、10-06 の IR が使うので、C01 で凍結する。
- `src/builtins/table.rs`: 番号から登録の項目を引く `builtin_decl` と、名前から番号を引く `lookup_builtin`（10-04 が使う）のシグネチャ。組み込みの表のほかの項目（型、専用の命令、演算子の引き方など。10-06「10-12 に求めるもの」）は、組み込みの表の章（10-12）が C02 で同じファイルに `sig=` として足す。10-12 はこのファイルに `file=` を置かない（C01 が置いたファイルを C02 は変えない。[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」）。
- `src/builtins/funcs/`: 組み込みの関数の本体を書くモジュールの親。子のモジュール（型や prelude のモジュールごとのファイル）は、組み込みの関数を書く作業（R07・R08・R23・R25・R29・R35・R37・R39、U3 の作業）が `funcs/mod.rs` に宣言して加える。組み込みの表は、各モジュールの `DECLS` を集める。

第 1 段で既存の組み込みの関数を型付きの形へ移す作業（R08）は、`src/legacy/builtins/` の関数を写して `funcs` の下に型付きの形で書き、`table.rs` の関数の中身を書く。番号は、表の中の位置とする。表には、第 1 段で本体を書く項目（最小実行版の組み込みの関数を 03-06 の名前に改めたものなど）だけでなく、10-12 の項目の一覧の U1・U2 の範囲のすべての項目を並べ、後の作業が本体を書く項目は仮の本体で宣言する（10-12「まだ書かない項目の仮の本体」）。

```rust file=src/builtins/mod.rs
//! 組み込みの関数（設計書 02-08「組み込みの関数の呼び出し」、02-09「組み込みの操作とハンドラ表」、03-01）。
//! iface.rs: 型付きの形（実装プラン 10-11）、table.rs: 組み込みの表（10-11・10-12）、
//! funcs: 組み込みの関数の本体（子のモジュールは組み込みの関数を書く作業が加える）。

pub mod funcs;
pub mod iface;
pub mod table;

pub use table::{builtin_decl, lookup_builtin};

/// 組み込みの関数の番号（組み込みの表の中の位置）。組み込みの関数は 65536 個に満たない。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinId(pub u16);
```

中身は R08 が書く。表の項目は、10-12 の項目の一覧の U1・U2 の範囲のすべてである（10-12「まだ書かない項目の仮の本体」）。

```rust sig=src/builtins/table.rs
//! 組み込みの表（実装プラン 10-11「登録と第 1 段の扱い」、10-12）。初期化の後に変更しないので、
//! `const` か関数で表す（ADR 0015）。

use super::BuiltinId;
use super::iface::BuiltinDecl;

/// 番号から登録の項目を引く。表にない番号なら `None`（VM は `Stop::Internal` にする）。
pub fn builtin_decl(id: BuiltinId) -> Option<&'static BuiltinDecl>;

/// 修飾した名前（`BuiltinDecl::name`。`String.byteLength`、`Benitoite.IO.Console.writeLine` など、
/// 10-12 が定める形）から番号を引く。表にない名前なら `None`。
pub fn lookup_builtin(name: &str) -> Option<BuiltinId>;
```

```rust sig=src/builtins/funcs/mod.rs
//! 組み込みの関数の本体（実装プラン 10-11「登録と第 1 段の扱い」）。子のモジュールは、組み込みの関数を書く作業が加える。
```

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C01 | `src/builtins/mod.rs`・`iface.rs` を置き、`table.rs` を `sig=` の `todo!()` の仮置き（00-02）として、`funcs/mod.rs` を中身のないモジュールとして置く |
| R07 | 純粋な関数・文字列を作る関数・待つ関数を一つずつこの形で書いて確かめる（ADR 0261 の決定 7）、コンパイルの失敗のテストを置く、`CallCtx` を使う VM の側の呼び出しの補助 |
| R08 | 最小実行版の組み込みの関数（`src/legacy/builtins/`）を型付きの形へ移す（`funcs` の下）。`builtin_decl`・`lookup_builtin` と、10-12 の U1・U2 の範囲のすべての項目の表（後の作業の項目は仮の本体）。第 1 段の `IoServices` の一時的な実装（本番の出力とテスト用の出力） |
| R23 | `StateServices` の一時的な実装、`state` の関数のうち `Reference.new`・`Reference.get`・`Reference.set`（10-12） |
| R25 | `StateServices` の実装（R23 の一時的な実装を置き換える）、`state` の関数のうち `Task.all`・`Task.await`・`TaskGroup.open`・`TaskGroup.spawn`（10-12） |
| R39 | `state` の関数のうち `Task.allOk`・`Task.race`・`Task.withTimeout`（10-12） |
| R29 | 残りの `state` の関数（`Reference.update` の `raw` の確かめ、`IO.File.closeReader`。10-12） |
| R26 | 第 2 段の `IoServices` の実装（10-10 の実行ごとの状態） |
