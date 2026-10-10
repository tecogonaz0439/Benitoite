//! 実行ごとの状態のうちランタイムが持つもの（設計書 02-09「実行ごとの状態」）と、VM とのつなぎ目。

use std::path::PathBuf;

use super::event::{InterruptGuard, Wakeup};
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
    /// 中断の要求があるか（`Relaxed` で読む。印はほかのデータの公開を知らせないため）。
    fn requested(&self) -> bool;
    /// 中断のシグナルで実行ごとのイベントループ（`wakeup` の `Poll`）が起きるように登録する。
    /// 返した印を実行の終わりまで持ち、落とすと登録を外す。登録しない読み口は `Ok(None)` を返す。
    /// R28 が加えた既定の本体付きの関数。`NoInterrupt` は既定のまま。
    fn attach(&self, _wakeup: &Wakeup) -> std::io::Result<Option<InterruptGuard>> {
        Ok(None)
    }

    /// 印そのものへの参照。振り分けのループが呼び出しのたびに動的な呼び出しなしで読むために使う。
    /// 印を持たない読み口は `None` を返し、ループは呼び出しごとの印の読み出しを省く
    /// （中断の要求が来ない読み口なので。切り替えの位置では `requested` を呼ぶ）。
    /// R28 が加えた既定の本体付きの関数。`NoInterrupt` は既定のまま。
    fn flag(&self) -> Option<&std::sync::atomic::AtomicBool> {
        None
    }
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
    /// 標準入力の返却を待つタスクを呼んだ順に保つ（実装プラン R26）。
    pub(crate) stdin_waiters: std::collections::VecDeque<crate::vm::TaskId>,
    /// Sleep の満了で結果を書く命令。タイムアウトのタイマーとは区別する。
    pub(crate) sleeps:
        std::collections::BTreeMap<crate::runtime::sched::TimerId, (crate::vm::TaskId, InstrRef)>,
    pub(crate) sleep_timers:
        std::collections::BTreeMap<crate::vm::TaskId, crate::runtime::sched::TimerId>,
    /// 容量を待つ IO の命令の入口（実装プラン R27、設計書 02-08「IO の命令」）。
    pub(crate) output_sites: std::collections::BTreeMap<crate::vm::TaskId, InstrRef>,
    /// HTTP の準備の待ちとやり直しの期限（実装プラン 10-16）。
    pub(crate) readiness: super::http::ReadinessState,
    pub(crate) main_announced: bool,
    pub(crate) output_task: crate::vm::TaskId,
    pub(crate) dev_panic_after_first_write: bool,
    #[cfg(test)]
    pub(crate) output_trace: Vec<(Stream, Vec<u8>)>,
    pub(crate) worker_bug: Option<crate::runtime::panic::PanicReport>,
    #[cfg(test)]
    pub(crate) builtin_overrides: std::collections::BTreeMap<
        crate::builtins::BuiltinId,
        &'static crate::builtins::iface::BuiltinDecl,
    >,
    /// `Process.runAttached` の標準入出力のつなぎ先（実装プラン 10-16）。`IoRuntime::new` は既定の値（継がせない）で作り、
    /// `runtime::run` が `RunEnv` の標準入出力から決める（L13）
    pub process_stdio: ProcessStdio,
}

/// 第 2 段の `io` の関数に渡すランタイムの口。`IoRuntime` と、`RunState` のリソースの表を一緒に借りる。
#[derive(Debug)]
pub struct IoView<'a> {
    pub rt: &'a mut IoRuntime,
    pub resources: &'a mut ResourceTable,
}

use crate::builtins::iface::{IoServices, IoWait, OsResource};
use crate::runtime::heap::ResourceId;
use crate::runtime::{ResourceKind, Stop, Stream};
use crate::vm::{ExecMode, InstrRef, RequestId, Vm, VmStep};

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
        match port.write(self.rt.output_task, text.as_bytes()) {
            Ok(super::output::Accept::Accepted) => {}
            Ok(super::output::Accept::Deferred) => {
                return Ok(Some(IoWait::Output {
                    stream,
                    kind: crate::builtins::iface::OutputWaitKind::Capacity,
                }));
            }
            Err(super::output::WriteFailure::Io(reason)) => {
                return Err(Stop::Runtime(crate::runtime::RuntimeError::WriteFailed {
                    stream,
                    reason,
                }));
            }
            Err(super::output::WriteFailure::Panicked(report)) => {
                return Err(crate::vm::state::internal(&report.message));
            }
        }
        #[cfg(test)]
        self.rt
            .output_trace
            .push((stream, text.as_bytes().to_vec()));
        dev_panic(&mut self.rt.dev_panic_after_first_write);
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
        let [a, b, c, d] = self.rt.random_state;
        let result = b.wrapping_mul(5).rotate_left(7).wrapping_mul(9);
        self.rt.random_state = [
            a ^ d ^ b,
            b ^ c ^ a,
            c ^ a ^ b.wrapping_shl(17),
            (d ^ b).rotate_left(45),
        ];
        result
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
    /// タスクを実行する（第 2 段）。要求と応答の方式では `VmStep::Requests` を返して止まる。
    pub fn run(&mut self, rt: &mut IoRuntime) -> VmStep {
        self.run_io(rt)
    }
    /// 要求と応答の方式で、外側の実行器が要求 `id` をハンドラ表の関数で行う（VM のスレッド）。
    /// 完了なら結果を入れてタスクを起こし、待つなら外部の操作の記録に登録する。
    pub fn serve_request(&mut self, rt: &mut IoRuntime, id: RequestId) {
        self.serve_io(rt, id)
    }
}

// 開発用の panic の差し込みだけを許す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
#[allow(clippy::panic)]
fn dev_panic(after_write: &mut bool) {
    if std::mem::take(after_write) {
        panic!("BENITOITE_DEV_PANIC=run");
    }
}

/// `Process.runAttached` が子プロセスの標準入出力をつなぐ先（実装プラン 10-16「外部コマンドの標準入出力」）。
/// 真ならプロセスのものを子に継がせる。偽なら、標準入力は空の入力、標準出力と標準エラー出力は、子の出力を
/// 集めて、コマンドが終わった後に実行の出力先へ書く。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct ProcessStdio {
    pub inherit_stdin: bool,
    pub inherit_stdout: bool,
    pub inherit_stderr: bool,
}
