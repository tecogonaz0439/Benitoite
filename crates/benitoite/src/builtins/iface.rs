//! 組み込みの関数の型付きの形（設計書 02-08「組み込みの関数の呼び出し」、02-09「組み込みの操作とハンドラ表」）。
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
    Sleep {
        millis: u64,
    },
    Readiness {
        resource: ResourceId,
        interest: Interest,
    },
    Output {
        stream: Stream,
        kind: OutputWaitKind,
    },
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

/// close の関数が解放を始めた結果（実装プラン 10-16「close の関数が解放の失敗を受け取る口」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum CloseStep {
    /// 解放を終えた。失敗したときは理由の文字列を持つ
    Done(Option<String>),
    /// 待つ。待つ理由を持つ（`begin_release` が返すものと同じ）
    Wait(StateWait),
}

/// タスクの起動の待ち方（02-08「タスクの起動と待ち方」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SpawnMode {
    All,
    AllOk,
    Race,
    /// 期限のミリ秒（0 以下を 0 に直した値）
    WithTimeout {
        millis: u64,
    },
    /// `TaskGroup.spawn`。起動したタスクを待たずに `Task` の値を結果とする
    GroupSpawn {
        group: ResourceId,
    },
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

/// 応答（内部の共通の形。設計書 02-08「組み込みの関数の呼び出し」）。
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

/// 完了を言語の値に変える処理。環境を捕えない `fn` ポインタである（設計書 02-08「組み込みの関数の呼び出し」）。
/// `args` は、待った組み込みの関数の呼び出しの引数（レジスタから読み直したもの）。
pub type CompleteFn<O> =
    for<'c, 'e> fn(&mut IoCtx<'c, 'e>, O, &[Value<'e>]) -> Result<Value<'e>, Stop>;

trait ErasedDone: Send {
    fn complete<'c, 'e>(
        self: Box<Self>,
        ctx: &mut IoCtx<'c, 'e>,
        args: &[Value<'e>],
    ) -> Result<Value<'e>, Stop>;
}

struct Pending<O> {
    output: O,
    complete: CompleteFn<O>,
}

impl<O: Send> ErasedDone for Pending<O> {
    fn complete<'c, 'e>(
        self: Box<Self>,
        ctx: &mut IoCtx<'c, 'e>,
        args: &[Value<'e>],
    ) -> Result<Value<'e>, Stop> {
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

    /// 仕事を実行する（作業用のスレッド、またはテスト用の実装では VM のスレッド。設計書 07-03「順序を与えるスケジューラと仮想の時間（初回リリース版）」）。
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
    pub fn complete<'c, 'e>(
        self,
        ctx: &mut IoCtx<'c, 'e>,
        args: &[Value<'e>],
    ) -> Result<Value<'e>, Stop> {
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
    /// 実行ごとの状態のうちランタイムが持つものと、リソースの表を借りる（実装プラン 10-16「ランタイムの内部への口」）。
    /// 第 2 段の `IoView` だけが `Some` を返す。第 1 段の一時的な実装、参照インタプリタ、テスト用の実装は既定の
    /// `None` のままとし、これを要る組み込みの関数は `None` のとき `Stop::Internal` を返す。
    fn runtime_view(&mut self) -> Option<crate::runtime::io::services::IoView<'_>> {
        None
    }
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
    /// リソースの表を借りる（実装プラン 10-16「受け付けた要求の保存」）。第 2 段の VM の側の実装だけが `Some` を返す。
    fn resource_table(&mut self) -> Option<&mut crate::runtime::io::resources::ResourceTable> {
        None
    }
    /// close の関数が解放を始める（設計書 02-09「リソースの追跡」）。すぐに終われば `CloseStep::Done`、待つなら `CloseStep::Wait` を返す。
    /// 解放の失敗は `Stop` にも捨てもせず、理由の文字列を `CloseStep::Done(Some(..))` で返す。待った後にもう一度
    /// 呼ばれたときは、記録した解放の失敗を一度だけ取り出して返す。既定の本体は `begin_release` に委ね、失敗の理由を
    /// 返さない。VM の側の実装が上書きする。
    fn begin_close(&mut self, resource: ResourceId) -> Result<CloseStep, Stop> {
        Ok(match self.begin_release(resource)? {
            None => CloseStep::Done(None),
            Some(wait) => CloseStep::Wait(wait),
        })
    }
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
        CallCtx {
            heap,
            io,
            state,
            site,
        }
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
            None => Err(Stop::Internal(String::from(
                "io builtin called without io services",
            ))),
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
            None => Err(Stop::Internal(String::from(
                "state builtin called without state services",
            ))),
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
    /// タスクの状態を読む。`StateServices::task_poll` はヒープと実行時のサービスを同時に要るが、
    /// `services()` は文脈の全体を可変で借りるので、二つを分けて借りてこの関数から呼ぶ（R25 で加えた）。
    pub fn task_poll(&mut self, task: Value<'e>) -> Result<TaskPoll<'e>, Stop> {
        self.services.task_poll(&*self.heap, task)
    }

    pub fn services(&mut self) -> &mut dyn StateServices {
        &mut *self.services
    }

    pub fn site(&self) -> Option<InstrRef> {
        self.site
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
/// （大きさを確かめない値の作り方を型で塞ぐ。設計書 02-09「一つの操作で作る値の大きさの上限」）。
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

/// 内部の共通の形（設計書 02-08「組み込みの関数の呼び出し」）。`builtin!` が作り、実装者は直接書かない。
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

/// 組み込みの関数を宣言する（本章「宣言のマクロ」）。
///
/// 次の例は、権限と値の作り方の誤りがコンパイルの誤りになることを確かめる（10-11「コンパイルの失敗のテスト」）。
///
/// 純粋な関数が待つ応答を返す（権限の誤り）:
///
/// ```rust,compile_fail
/// use benitoite::builtins::iface::{IoReply, IoWait};
/// benitoite::builtin! {
///     name = "Test.pureWaits",
///     pure fn pure_waits(ctx, ms: i64) -> IoReply<'e> {
///         let _ = ctx;
///         Ok(IoReply::Wait(IoWait::Sleep { millis: ms.unsigned_abs() })) // IoReply は IntoValue でない
///     }
/// }
/// fn main() {}
/// ```
///
/// ```rust,no_run
/// benitoite::builtin! {
///     name = "Test.pureWaits",
///     pure fn pure_waits(ctx, ms: i64) -> i64 {
///         let _ = ctx;
///         Ok(ms)
///     }
/// }
/// fn main() {}
/// ```
///
/// 純粋な関数が IO の口を使う（権限の誤り）:
///
/// ```rust,compile_fail
/// benitoite::builtin! {
///     name = "Test.pureWrites",
///     pure fn pure_writes(ctx, s: &'c str) -> () {
///         ctx.services().write_output(benitoite::runtime::Stream::Stdout, s)?; // PureCtx に services はない
///         Ok(())
///     }
/// }
/// fn main() {}
/// ```
///
/// ```rust,no_run
/// benitoite::builtin! {
///     name = "Test.pureWrites",
///     pure fn pure_writes(ctx, s: &'c str) -> () {
///         let _ = ctx.str(benitoite::runtime::heap::Value::Unit);
///         let _ = s;
///         Ok(())
///     }
/// }
/// fn main() {}
/// ```
///
/// 大きさを確かめずに Rust の `String` を結果にする（値の作り方の誤り）:
///
/// ```rust,compile_fail
/// benitoite::builtin! {
///     name = "Test.unchecked",
///     pure fn unchecked(ctx, s: &'c str) -> String {
///         let _ = ctx;
///         Ok(s.repeat(2)) // String は IntoValue でない
///     }
/// }
/// fn main() {}
/// ```
///
/// ```rust,no_run
/// use benitoite::runtime::heap::Value;
/// benitoite::builtin! {
///     name = "Test.unchecked",
///     pure fn unchecked(ctx, s: &'c str) -> Value<'e> {
///         ctx.alloc_str_parts(&[s, s], "Test.unchecked")
///     }
/// }
/// fn main() {}
/// ```
///
/// `state` の関数が借用する引数を読む（引数の型の誤り）:
///
/// ```rust,compile_fail
/// use benitoite::builtins::iface::StateReply;
/// benitoite::builtin! {
///     name = "Test.stateBorrows",
///     state fn state_borrows(ctx, s: &'c str) -> StateReply<'e> { // &str は FromValue でない
///         let _ = (ctx, s);
///         Ok(StateReply::Done(benitoite::runtime::heap::Value::Unit))
///     }
/// }
/// fn main() {}
/// ```
///
/// ```rust,no_run
/// use benitoite::builtins::iface::StateReply;
/// benitoite::builtin! {
///     name = "Test.stateBorrows",
///     state fn state_borrows(ctx, n: i64) -> StateReply<'e> {
///         let _ = (ctx, n);
///         Ok(StateReply::Done(benitoite::runtime::heap::Value::Unit))
///     }
/// }
/// fn main() {}
/// ```
///
/// 作業用のスレッドの仕事が言語の値を捕える（捕捉の誤り）:
///
/// ```rust,compile_fail
/// use benitoite::builtins::iface::{IoCtx, IoReply, IoWait, Lend, WorkerWait};
/// use benitoite::runtime::{Stop, heap::Value};
/// fn done<'c, 'e>(_ctx: &mut IoCtx<'c, 'e>, _out: (), _args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
///     Ok(Value::Unit)
/// }
/// benitoite::builtin! {
///     name = "Test.capturesValue",
///     io fn captures_value(ctx, v: Value<'e>) -> IoReply<'e> {
///         let _ = ctx;
///         Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Nothing, move |_lent| drop(v), done)))) // Value は Send でない
///     }
/// }
/// fn main() {}
/// ```
///
/// ```rust,no_run
/// use benitoite::builtins::iface::{IoCtx, IoReply, IoWait, Lend, WorkerWait};
/// use benitoite::runtime::{Stop, heap::Value};
/// fn done<'c, 'e>(_ctx: &mut IoCtx<'c, 'e>, _out: (), _args: &[Value<'e>]) -> Result<Value<'e>, Stop> {
///     Ok(Value::Unit)
/// }
/// benitoite::builtin! {
///     name = "Test.capturesValue",
///     io fn captures_value(ctx, v: Value<'e>) -> IoReply<'e> {
///         let _ = (ctx, v);
///         let n = 1_u64;
///         Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Nothing, move |_lent| drop(n), done))))
///     }
/// }
/// fn main() {}
/// ```
///
/// 完了の処理が環境を捕える（捕捉の誤り）:
///
/// ```rust,compile_fail
/// use benitoite::builtins::iface::{IoReply, IoWait, Lend, WorkerWait};
/// use benitoite::runtime::heap::Value;
/// benitoite::builtin! {
///     name = "Test.capturingCompletion",
///     io fn capturing_completion(ctx, n: i64) -> IoReply<'e> {
///         let _ = ctx;
///         Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
///             Lend::Nothing,
///             |_lent| (),
///             move |_ctx, _out: (), _args| Ok(Value::Int(n)), // 捕える閉包は fn ポインタにならない
///         ))))
///     }
/// }
/// fn main() {}
/// ```
///
/// ```rust,no_run
/// use benitoite::builtins::iface::{IoReply, IoWait, Lend, WorkerWait};
/// use benitoite::runtime::heap::Value;
/// benitoite::builtin! {
///     name = "Test.capturingCompletion",
///     io fn capturing_completion(ctx, n: i64) -> IoReply<'e> {
///         let _ = (ctx, n);
///         Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
///             Lend::Nothing,
///             |_lent| (),
///             |_ctx, _out: (), _args| Ok(Value::Int(0)),
///         ))))
///     }
/// }
/// fn main() {}
/// ```
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
