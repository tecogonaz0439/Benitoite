//! 実行ごとの状態のうちランタイムが持つもの（設計書 02-09「実行ごとの状態」）と、VM とのつなぎ目。

use std::path::PathBuf;

use super::event::{InterruptGuard, Wakeup};
use super::ops::{OpTable, StdinReader};
use super::output::{OutputPort, WriteFailure};
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
    /// 中断の要求があるか（`Relaxed` で読む。印はほかのデータの公開を知らせないため）。
    fn requested(&self) -> bool;
    /// 中断のシグナルで実行ごとのイベントループ（`wakeup` の `Poll`）が起きるように登録する。
    /// 返した印を実行の終わりまで持ち、落とすと登録を外す。登録しない読み口は `Ok(None)` を返す。
    /// `NoInterrupt` は既定の本体を使う。
    fn attach(&self, _wakeup: &Wakeup) -> std::io::Result<Option<InterruptGuard>> {
        Ok(None)
    }

    /// 印そのものへの参照。振り分けのループが呼び出しのたびに動的な呼び出しなしで読むために使う。
    /// 印を持たない読み口は `None` を返し、ループは呼び出しごとの印の読み出しを省く
    /// （中断の要求が来ない読み口なので。切り替えの位置では `requested` を呼ぶ）。
    /// `NoInterrupt` は既定の本体を使う。
    fn flag(&self) -> Option<&std::sync::atomic::AtomicBool> {
        None
    }
}

/// 実行ごとの状態のうちランタイムが持つもの（設計書 02-09「実行ごとの状態」）。
/// スケジューラとリソースの表は VM の `RunState` に置く（設計書 02-08「実行ごとの状態のうち VM が使うもの」）。
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
    /// `runtime::run` が実行の始めに OS の乱数から種を入れる（設計書 02-09「組み込みの操作とハンドラ表」）。
    pub random_state: [u64; 4],
    /// 標準入力の返却を待つタスクを呼んだ順に保つ。
    pub(crate) stdin_waiters: std::collections::VecDeque<crate::vm::TaskId>,
    /// Sleep の満了で結果を書く命令。タイムアウトのタイマーとは区別する。
    pub(crate) sleeps:
        std::collections::BTreeMap<crate::runtime::sched::TimerId, (crate::vm::TaskId, InstrRef)>,
    pub(crate) sleep_timers:
        std::collections::BTreeMap<crate::vm::TaskId, crate::runtime::sched::TimerId>,
    /// 容量を待つ IO の命令の入口（設計書 02-08「IO の命令」）。
    pub(crate) output_sites: std::collections::BTreeMap<crate::vm::TaskId, InstrRef>,
    /// HTTP の準備の待ちとやり直しの期限（設計書 02-09「IO 実行器」）。
    pub(crate) readiness: super::http::ReadinessState,
    pub(crate) main_announced: bool,
    pub(crate) output_task: crate::vm::TaskId,
    pub(crate) dev_panic_after_first_write: bool,
    /// すぐに受け付けた書き込み（output_written）だけを記録し、出力の待ちの後に
    /// OutputPort::poll が受け付けた書き込みは記録しない。預ける場合の出力は
    /// 本物の出力先（OutputTarget::Capture）で確かめる（設計書 07-03「テストの設計の原則」）。
    #[cfg(test)]
    pub(crate) output_trace: Vec<(Stream, Vec<u8>)>,
    pub(crate) worker_bug: Option<crate::runtime::panic::PanicReport>,
    #[cfg(test)]
    pub(crate) builtin_overrides: std::collections::BTreeMap<
        crate::builtins::BuiltinId,
        &'static crate::builtins::iface::BuiltinDecl,
    >,
    /// `Process.runAttached` の標準入出力のつなぎ先（設計書 03-07「Process」）。
    /// `IoRuntime::new` は既定の値（継がせない）で作り、`runtime::run` が `RunEnv` の標準入出力から決める
    /// （設計書 02-11「実行の入力と結果」）。
    pub process_stdio: ProcessStdio,
}

/// `io` の関数に渡すランタイムの口。`IoRuntime` と、`RunState` のリソースの表を一緒に借りる。
#[derive(Debug)]
pub struct IoView<'a> {
    pub rt: &'a mut IoRuntime,
    pub resources: &'a mut ResourceTable,
}

use crate::builtins::iface::{IoServices, IoWait, OsResource};
use crate::runtime::heap::ResourceId;
use crate::runtime::{ResourceKind, Stop, Stream};
use crate::vm::{ExecMode, InstrRef, RequestId, Vm, VmStep};

impl IoView<'_> {
    /// 警告で受け付けを止めないよう、容量があるときだけ書き、容量の待ちを作らない
    /// （設計書 03-09「失敗の種類」、設計書 02-09「出力のバッファ」）。
    pub(crate) fn write_output_if_room(&mut self, stream: Stream, text: &str) -> Result<(), Stop> {
        let port = match stream {
            Stream::Stdout => &mut self.rt.stdout,
            Stream::Stderr => &mut self.rt.stderr,
        };
        if !port
            .write_if_room(text.as_bytes())
            .map_err(|failure| output_write_failure(stream, failure))?
        {
            return Ok(());
        }
        self.output_written(stream, text);
        Ok(())
    }

    // 受け入れた書き込みだけを記録し、開発用の panic の条件を進める（設計書 02-09「出力のバッファ」）。
    fn output_written(&mut self, _stream: Stream, _text: &str) {
        #[cfg(test)]
        self.rt
            .output_trace
            .push((_stream, _text.as_bytes().to_vec()));
        dev_panic(&mut self.rt.dev_panic_after_first_write);
    }
}

// 出力の失敗は両方の書き込みの入口で同じ停止に変える（設計書 02-09「出力のバッファ」）。
fn output_write_failure(stream: Stream, failure: WriteFailure) -> Stop {
    match failure {
        WriteFailure::Io(reason) => {
            Stop::Runtime(crate::runtime::RuntimeError::WriteFailed { stream, reason })
        }
        WriteFailure::Panicked(report) => crate::vm::state::internal(&report.message),
    }
}

impl IoServices for IoView<'_> {
    fn runtime_view(&mut self) -> Option<IoView<'_>> {
        Some(IoView {
            rt: &mut *self.rt,
            resources: &mut *self.resources,
        })
    }
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop> {
        let port = match stream {
            Stream::Stdout => &mut self.rt.stdout,
            Stream::Stderr => &mut self.rt.stderr,
        };
        match port
            .write(self.rt.output_task, text.as_bytes())
            .map_err(|failure| output_write_failure(stream, failure))?
        {
            super::output::Accept::Accepted => {}
            super::output::Accept::Deferred => {
                return Ok(Some(IoWait::Output {
                    stream,
                    kind: crate::builtins::iface::OutputWaitKind::Capacity,
                }));
            }
        }
        self.output_written(stream, text);
        Ok(None)
    }
    fn arguments(&self) -> &[String] {
        &self.rt.input.arguments
    }
    fn script_directory(&self) -> &std::path::Path {
        &self.rt.input.script_directory
    }
    fn working_directory(&self) -> &std::path::Path {
        &self.rt.input.working_directory
    }
    fn environment_variable(&self, name: &str) -> Option<std::ffi::OsString> {
        std::env::var_os(name)
    }
    fn now_millis(&self) -> i64 {
        self.rt.parts.clock.now_millis()
    }
    fn local_offset_minutes(&self) -> i32 {
        self.rt.parts.clock.local_offset_minutes()
    }
    fn monotonic_millis(&self) -> i64 {
        i64::try_from(self.rt.parts.clock.monotonic_millis()).unwrap_or(i64::MAX)
    }
    fn random_u64(&mut self) -> u64 {
        crate::runtime::random::next(&mut self.rt.random_state)
    }
    fn register_resource(
        &mut self,
        kind: ResourceKind,
        handle: Box<dyn OsResource>,
        opened_at: Option<InstrRef>,
    ) -> ResourceId {
        self.resources.insert(
            kind,
            super::resources::ResourceContent::Os(Some(handle)),
            opened_at,
        )
    }
}

impl IoRuntime {
    /// 方式に合った部品（`DirectDispatcher` か `RequestDispatcher`）を入れて作る。
    pub fn new(
        input: RunInput,
        mode: ExecMode,
        outputs: (OutputPort, OutputPort),
        stdin: Box<dyn StdinReader>,
        parts: RuntimeParts,
        interrupt: Box<dyn InterruptSource>,
        wakeup: Wakeup,
    ) -> IoRuntime {
        let dispatcher: Box<dyn Dispatcher> = match mode {
            ExecMode::Direct => Box::new(super::DirectDispatcher),
            ExecMode::Request => Box::new(super::RequestDispatcher),
        };
        IoRuntime {
            input,
            queue: DispatchQueue::default(),
            dispatcher,
            ops: OpTable::default(),
            stdout: outputs.0,
            stderr: outputs.1,
            stdin: Some(stdin),
            parts,
            interrupt,
            wakeup,
            random_state: [0; 4],
            process_stdio: ProcessStdio::default(),
            stdin_waiters: Default::default(),
            sleeps: Default::default(),
            sleep_timers: Default::default(),
            output_sites: Default::default(),
            readiness: Default::default(),
            main_announced: false,
            output_task: crate::vm::TaskId {
                index: 0,
                generation: 0,
            },
            dev_panic_after_first_write: false,
            worker_bug: None,
            #[cfg(test)]
            builtin_overrides: Default::default(),
            #[cfg(test)]
            output_trace: Vec::new(),
        }
    }
}

impl<'p> Vm<'p> {
    /// タスクを実行する。要求と応答の方式では `VmStep::Requests` を返して止まる。
    pub fn run(&mut self, rt: &mut IoRuntime) -> VmStep {
        self.run_io(rt)
    }
    /// 要求と応答の方式で、外側の実行器が要求 `id` をハンドラ表の関数で行う（VM のスレッド）。
    /// 完了なら結果を入れてタスクを起こし、待つなら外部の操作の記録に登録する。
    pub fn serve_request(&mut self, rt: &mut IoRuntime, id: RequestId) {
        self.serve_io(rt, id)
    }
}

// 開発用の panic の差し込みだけを許す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#[allow(clippy::panic)]
fn dev_panic(after_write: &mut bool) {
    if std::mem::take(after_write) {
        panic!("BENITOITE_DEV_PANIC=run");
    }
}

/// `Process.runAttached` が子プロセスの標準入出力をつなぐ先（設計書 03-07「Process」）。
/// 真ならプロセスのものを子に継がせる。偽なら、標準入力は空の入力、標準出力と標準エラー出力は、子の出力を
/// 集めて、コマンドが終わった後に実行の出力先へ書く。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct ProcessStdio {
    pub inherit_stdin: bool,
    pub inherit_stdout: bool,
    pub inherit_stderr: bool,
}
