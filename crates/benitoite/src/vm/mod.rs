//! 仮想機械（設計書 02-08）。言語の関数の呼び出しで Rust の関数を入れ子に呼ばない（設計書 02-08「枠の積み重ね」）。
//! 命令の型と命令ごとの処理は 10-07 が定める。本モジュールは命令の集合に依存しない部分を持つ。

pub mod budget;
pub mod dispatch;
pub mod frame;
pub mod handler;
pub mod stage1;
pub mod state;
pub mod task;
pub mod unwind;

use crate::bytecode::program::{CompiledProgram, ProtoIdx};
use crate::runtime::heap::Heap;
use crate::runtime::{ReleaseFailure, Stop};

use self::state::RunState;

/// 枠一つの大きさとして数える固定の定数（02-08「呼び出しの入れ子の上限」）。
pub const FRAME_COST: u64 = 96;
/// レジスタ一つの大きさとして数える固定の定数。
pub const REG_COST: u64 = 32;
/// 呼び出しの入れ子の上限の既定（1 GiB）。
pub const DEFAULT_MAX_CALL_STACK: u64 = 1_073_741_824;
/// タスクごとの呼び出しの回数の予算の初めの値（02-08「タスクの切り替え」）。性能の測定で見直す（docs/todo の TODO-034）。
pub const DEFAULT_CALL_BUDGET: u32 = 2_500;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct VmConfig {
    pub max_call_stack_bytes: u64,
    pub call_budget: u32,
}

impl Default for VmConfig {
    fn default() -> VmConfig {
        VmConfig {
            max_call_stack_bytes: DEFAULT_MAX_CALL_STACK,
            call_budget: DEFAULT_CALL_BUDGET,
        }
    }
}

/// 命令の位置（原型と命令の番号の組）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct InstrRef {
    pub proto: ProtoIdx,
    pub pc: u32,
}

/// 世代付きのタスクの番号（設計書 02-08「実行ごとの状態のうち VM が使うもの」）。所有しない参照に使う。引いた世代が合わなければ、
/// そのタスクは終わってタスクの表から除かれている。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct TaskId {
    pub index: u32,
    pub generation: u32,
}

/// 送り出しの列の要求の番号（設計書 02-09「IO 実行器」）。一つの実行の中で使い回さない。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct RequestId(pub u64);

/// IO の命令の実行の方式（設計書 02-08「IO の命令」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ExecMode {
    Direct,
    Request,
}

/// 実行時エラーの情報の記録の、呼び出しの枠一つ分（02-08「実行時エラーの情報の記録」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct FrameRecord {
    /// 実行中の関数の値の原型
    pub proto: ProtoIdx,
    /// 呼び出した命令。`main` の枠とタスクの最初の枠では `None`
    pub call_site: Option<InstrRef>,
}

/// タスクの起動の履歴の材料の一段（止まったタスクから最初のタスクへ向かう順）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct SpawnRecord {
    /// 起動したタスクの、起動したときの呼び出しの枠（内側から外側の順）
    pub spawner_frames: Vec<FrameRecord>,
    /// 起動した命令
    pub spawned_at: InstrRef,
}

/// 行き詰まりで待っていたものの種類（02-08「実行時エラーの情報の記録」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum DeadlockWaitKind {
    /// `Task.await`・`Task.all` などの組み込みの関数。修飾した名前
    Builtin(&'static str),
    Lazy,
    HandleEnd,
    TaskGroupRelease,
}

/// 行き詰まりで待っていたタスク一つ分の記録。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct DeadlockWaiter {
    pub kind: DeadlockWaitKind,
    /// 待つ命令（組み込みの関数を呼んだ命令、`FORCE`、`HANDLE`、`USE`）
    pub at: InstrRef,
    /// そのタスクの積み重ねの各呼び出しの枠が記録した、呼び出した命令（内側から外側の順）
    pub call_sites: Vec<Option<InstrRef>>,
    pub spawns: Vec<SpawnRecord>,
}

/// 止まったときの記録。枠を一つも降ろさないうちに作る。
#[derive(Clone, PartialEq, Debug)]
pub struct StopInfo {
    pub stop: Stop,
    /// 止まった命令。書き込みの失敗と行き詰まりでは `None`
    pub at: Option<InstrRef>,
    /// 止まったタスクの呼び出しの枠（内側から外側の順）。行き詰まりでは空
    pub frames: Vec<FrameRecord>,
    pub spawns: Vec<SpawnRecord>,
    /// 行き詰まりのときだけ、待っていたタスクごとの記録
    pub deadlock: Vec<DeadlockWaiter>,
}

/// `main` の終わり方（02-09「プログラムの実行の流れ」）。値は区間の外へ出せないので、VM が区間の中で変える。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum MainOutcome {
    /// `()` または `Result.Ok(())`
    Ok,
    /// `Result.Error(msg)` の `msg`
    Error(String),
}

/// 止める手順の始まりの理由（02-08「止める手順」）。
#[derive(Clone, PartialEq, Debug)]
pub enum StopReason {
    /// 実行時エラーか資源の不足
    Error(StopInfo),
    /// `Process.exit`
    Exit(u8),
    /// 中断の要求（終了状態 130）
    Interrupted,
    /// テストの確認の失敗（`Assert.Check`。内容は U4 が定める）
    CheckFailed(String),
}

/// 止める手順を終えたときの結果。
#[derive(Clone, PartialEq, Debug)]
pub struct StopEnd {
    pub reason: StopReason,
    /// 止める途中の解放の失敗（止める理由は置き換えない）
    pub release_failures: Vec<ReleaseFailure>,
}

/// VM の実行関数の結果（02-08「IO の命令」の最後の段落）。
#[derive(Clone, PartialEq, Debug)]
pub enum VmStep {
    /// 要求と応答の方式で、要求を返して止まった。応答を待つために空の並びを返すこともある
    Requests(Vec<RequestId>),
    /// 最初のタスクが値で終わった
    Finished(MainOutcome),
    /// 止める手順を終えた
    Stopped(StopEnd),
}

/// 実行ごとの VM。
pub struct Vm<'p> {
    program: &'p CompiledProgram,
    config: VmConfig,
    heap: Heap,
    state: RunState,
}

use crate::runtime::heap::{HeapConfig, HeapStats};

impl<'p> Vm<'p> {
    pub fn new(program: &'p CompiledProgram, config: VmConfig, heap: HeapConfig) -> Vm<'p> {
        Vm {
            program,
            config,
            heap: Heap::new(heap),
            state: RunState::new(config, program.consts.len()),
        }
    }
    /// `main` の関数の値を引数なしで呼ぶ呼び出しの枠一つを積んだ最初のタスクを作る（02-08「実行の開始と終わり」）。
    /// `CompiledProgram::main` が `None` のプログラムでは、枠を積まずに `Stop::Internal` の記録を返す
    /// （`main` のないプログラムを実行する経路は、`main` を検査した後の `check`・`run` にはない）。
    /// 記録を `Box` に入れるのは、`StopInfo` が大きく、Clippy の `result_large_err` に当たるからである。
    pub fn start_main(&mut self) -> Result<(), Box<StopInfo>> {
        if self.state.started {
            return Err(Box::new(
                self.state
                    .stop_info(state::internal("main has already started"), None),
            ));
        }
        let main = self.program.main;
        self.start_entry(main.ok_or_else(|| state::internal("program has no main")))
    }

    // `main` とテストの関数に共通の、最初のタスクを作る手順（02-08「実行の開始と終わり」、02-11「テストの実行」）。
    fn start_entry(&mut self, entry: Result<ProtoIdx, Stop>) -> Result<(), Box<StopInfo>> {
        let result = (|| {
            let main = entry?;
            let proto = self
                .program
                .proto(main)
                .ok_or_else(|| state::internal("main prototype missing"))?;
            if proto.num_params != 0 || !proto.captures.is_empty() {
                return Err(state::internal("main requires arguments or captures"));
            }
            let size = u32::from(proto.num_regs);
            if !self.state.meter.fits(1, u64::from(size)) {
                return Err(Stop::Resource(
                    crate::runtime::ResourceError::CallStackTooDeep {
                        frames: self.state.meter.frames(),
                    },
                ));
            }
            self.heap.epoch(|ctx| {
                let value =
                    ctx.alloc_fields(crate::runtime::heap::FieldsKind::Func, main.0, &[])?;
                let mut segment = frame::Segment::default();
                segment
                    .regs
                    .resize_with(usize::from(proto.num_regs), Default::default);
                segment.calls.push(frame::CallFrame {
                    func: ctx.new_slot(value),
                    proto: main,
                    pc: 0,
                    base: 0,
                    size,
                    ret: None,
                    call_site: None,
                    boundary: proto.boundary,
                    chain_resume: None,
                });
                self.state.stack.segments.push(segment);
                self.state.meter.grow(1, u64::from(size));
                dispatch::tasks::start_main(&mut self.state, ctx)?;
                self.state.started = true;
                if ctx.take_collect_signal() {
                    self.state.budget.interrupt();
                }
                Ok(())
            })
        })();
        result.map_err(|stop| Box::new(self.state.stop_info(stop, None)))
    }
    pub fn heap_stats(&self) -> HeapStats {
        self.heap.stats()
    }
}

#[cfg(test)]
mod tests;

#[cfg(test)]
mod miri_tests;

use std::sync::Arc;

use crate::bytecode::program::MainKind;
use crate::runtime::assert::{AssertTable, CheckFailure};

impl<'p> Vm<'p> {
    /// テストの関数 `proto` を引数なしで呼ぶ呼び出しの枠一つを積んだ最初のタスクを作り、`Assert` の操作の表を置く
    /// （02-11「テストの実行」）。最初のタスクの戻り値は、`CompiledProgram::main_kind` の代わりに `kind` で読む。
    /// `proto` が表にないときは、枠を積まずに `Stop::Internal` の記録を返す。
    pub fn start_test(
        &mut self,
        proto: ProtoIdx,
        kind: MainKind,
        assert: Arc<AssertTable>,
    ) -> Result<(), Box<StopInfo>> {
        if self.state.started {
            return Err(Box::new(
                self.state
                    .stop_info(state::internal("main has already started"), None),
            ));
        }
        let entry = self
            .program
            .proto(proto)
            .map(|_| proto)
            .ok_or_else(|| state::internal("test function prototype missing"));
        self.start_entry(entry)?;
        self.state.main_kind = Some(kind);
        self.state.assert = Some(assert);
        Ok(())
    }

    /// 確認の失敗で止めたときの記録を取り出す（取り出した後は空になる）。
    pub fn take_check_failure(&mut self) -> Option<CheckFailure> {
        self.state.check_failure.take().map(|failure| *failure)
    }
}
