//! タスクの対象、状態、タスクの表（設計書 02-08「タスクの切り替え」「取り消し」、ADR 0161・0266）。

use crate::builtins::iface::{OutputWaitKind, SpawnMode};
use crate::runtime::Stream;
use crate::runtime::heap::{HostData, ResourceId, Slot, Trace, Tracer};
use crate::runtime::sched::{ExtOpId, TimerId};

use super::budget::Budget;
use super::frame::TaskStack;
use super::unwind::{ReturnWork, UnwindWork};
use super::{InstrRef, TaskId};

/// タスクの終わりを待つ理由（02-08「組み込みの関数の呼び出し」の待つ理由の表の「タスクの終わり」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TaskEndWait {
    /// `Task.await`
    Await(TaskId),
    /// `Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout` が起動したタスク
    Spawned,
    /// `handle` の枠に属するタスク（E-HRet、取り消し）
    HandleEnd,
    /// `TaskGroup` の解放
    TaskGroupRelease(ResourceId),
}

/// 待つ理由（02-08 の待つ理由の表）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum WaitReason {
    /// 作業用のスレッドの仕事（外部の待ち）
    Worker(ExtOpId),
    /// タイマー（外部の待ち）
    Timer(TimerId),
    /// イベントループの準備（外部の待ち）
    Readiness(ExtOpId),
    /// 出力（外部の待ち）
    Output(Stream, OutputWaitKind),
    /// 貸し出しを受けるために、貸しているリソースの返却を待つ（外部の待ち）。取り消しと全体の停止で外す
    Lend(ResourceId),
    /// 解放の枠（と `StateServices::begin_release`）が、解放の完了を待つ。返却を待ってから解放する場合を
    /// 含む（外部の待ち）。取り消しと全体の停止で外さない（本章「既に枠を降ろしているタスクの扱い」）
    Release(ResourceId),
    /// タスクの終わり（内部の待ち）
    TaskEnd(TaskEndWait),
    /// `Lazy` の評価（内部の待ち）
    Lazy,
    /// 要求と応答の方式で、応答を待つ（外部の待ち）
    Response,
}

impl WaitReason {
    /// 行き詰まりの判定で外部の完了の待ちとして数えるか（ADR 0266 の決定 8、ADR 0267 の決定 5、ADR 0283）。
    pub fn is_external(self) -> bool {
        !matches!(self, WaitReason::TaskEnd(_) | WaitReason::Lazy)
    }
}

/// タスクの状態（ADR 0266 の決定 1）。
#[derive(Debug)]
pub enum TaskState {
    Ready,
    Waiting(WaitReason),
    /// 枠を降ろしている。降ろす原因、辿る途中の区画、解放などを待っているかを持つ
    Unwinding(UnwindWork),
    Done,
}

/// タスクの結果。
#[derive(Debug)]
pub enum TaskResult {
    /// まだ終わっていない
    Pending,
    /// 値で終わった
    Value(Slot),
    /// 取り消されて結果なしで終わった
    Cancelled,
}

/// `Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout` で起動したタスクを待つ状態。
#[derive(Debug)]
pub struct SpawnWait {
    pub mode: SpawnMode,
    /// 起動したタスクの `Task` の値（起動した順）。終わった後も結果を読むために所有する
    pub children: Vec<Slot>,
    /// `Task.withTimeout` の期限のタイマー
    pub timer: Option<TimerId>,
}

impl Trace for SpawnWait {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slots(&self.children);
    }
}

/// タスクの対象（`Host` の対象）。
#[derive(Debug)]
pub struct TaskObj {
    pub id: TaskId,
    pub state: TaskState,
    /// 枠の積み重ね。実行中は `RunState` へ移してあり、ここは空
    pub stack: TaskStack,
    /// 引き継いだハンドラの連鎖（内側から外側の順。ハンドラの記録）
    pub inherited: Vec<Slot>,
    pub budget: Budget,
    pub cancel_requested: bool,
    pub result: TaskResult,
    /// 終わりを待つタスク
    pub awaiters: Vec<TaskId>,
    /// 属する `handle` のハンドラの記録（ADR 0266 の決定 6）。どの `handle` にも属さなければ `None`
    pub handle: Option<Slot>,
    /// このタスクが起動したタスク
    pub spawned: Vec<TaskId>,
    /// 起動したタスクの終わりを待っているとき、その状態
    pub spawn_wait: Option<SpawnWait>,
    /// 起動したタスクと、起動した命令（最初のタスクでは `None`）
    pub spawner: Option<(TaskId, InstrRef)>,
    /// 呼び出しの前の安全点を通り、呼び出しがまだ成立していない命令（10-09「呼び出しの前の安全点」）。
    /// 実行中は `RunState` へ移してあり、ここは `None`
    pub precall_done: Option<InstrRef>,
    /// 戻りの再開状態（10-09「戻りの再開状態」）。実行中は `RunState` へ移してあり、ここは `None`
    pub returning: Option<ReturnWork>,
}

impl Trace for TaskState {
    fn trace(&self, t: &mut Tracer<'_>) {
        match self {
            TaskState::Unwinding(work) => work.trace(t),
            TaskState::Ready | TaskState::Waiting(_) | TaskState::Done => {}
        }
    }
}

impl Trace for TaskResult {
    fn trace(&self, t: &mut Tracer<'_>) {
        if let TaskResult::Value(v) = self {
            t.slot(v);
        }
    }
}

impl Trace for TaskObj {
    fn trace(&self, t: &mut Tracer<'_>) {
        self.state.trace(t);
        self.stack.trace(t);
        t.slots(&self.inherited);
        self.result.trace(t);
        self.handle.trace(t);
        self.spawn_wait.trace(t);
        self.returning.trace(t);
    }
}

impl HostData for TaskObj {}

/// タスクの表の項目。
#[derive(Debug, Default)]
pub struct TaskEntry {
    pub generation: u32,
    /// 終わっていないタスクの対象（`Task` の値）。空いた項目では `None`
    pub task: Option<Slot>,
}

/// タスクの表（終わっていないタスクの根）。
#[derive(Debug, Default)]
pub struct TaskTable {
    pub entries: Vec<TaskEntry>,
    /// 空いた項目の位置
    pub free: Vec<u32>,
}

impl Trace for TaskTable {
    fn trace(&self, t: &mut Tracer<'_>) {
        for e in &self.entries {
            e.task.trace(t);
        }
    }
}

use crate::runtime::heap::{NoGcCtx, Value};

impl TaskTable {
    /// タスクの対象 `task`（`NoGcCtx::alloc_host` で作った値）を加え、番号を返す。項目を使い回すときは世代を一つ増やす。
    pub fn insert<'e>(
        &mut self,
        ctx: &NoGcCtx<'e>,
        make: impl FnOnce(TaskId) -> Value<'e>,
    ) -> TaskId {
        if self.check_insert().is_err() {
            // VM が先に確かめるので、ここへは来ない（実装プラン R25）。
            debug_assert!(false, "task table overflow");
            return TaskId {
                index: u32::MAX,
                generation: u32::MAX,
            };
        }
        let id = if let Some(index) = self.free.pop() {
            let Some(entry) = self
                .entries
                .get_mut(usize::try_from(index).unwrap_or(usize::MAX))
            else {
                debug_assert!(false, "invalid free task entry");
                return TaskId {
                    index: u32::MAX,
                    generation: u32::MAX,
                };
            };
            // 古い番号が同じ世代になるには、同じ項目を 2^32 回使い回してなお古い番号を
            // 保持する必要があるため、実際上起きない（実装プラン R25）。
            entry.generation = entry.generation.wrapping_add(1);
            TaskId {
                index,
                generation: entry.generation,
            }
        } else {
            let index = u32::try_from(self.entries.len()).unwrap_or(u32::MAX);
            self.entries.push(TaskEntry::default());
            TaskId {
                index,
                generation: 0,
            }
        };
        let value = make(id);
        if let Some(entry) = self
            .entries
            .get_mut(usize::try_from(id.index).unwrap_or(usize::MAX))
        {
            entry.task = Some(ctx.new_slot(value));
        }
        id
    }
    /// 番号の世代が合えば、タスクの対象を返す。
    pub fn get<'e>(&self, ctx: &NoGcCtx<'e>, id: TaskId) -> Option<Value<'e>> {
        let entry = self.entries.get(usize::try_from(id.index).ok()?)?;
        if entry.generation != id.generation {
            return None;
        }
        entry.task.as_ref().map(|slot| ctx.load(slot))
    }
    /// タスクを表から除く（`Done` にするとき）。
    pub fn remove<'e>(&mut self, ctx: &NoGcCtx<'e>, id: TaskId) {
        if self.check_remove(id).is_err() {
            // VM は check_remove を先に通す（実装プラン R25）。
            debug_assert!(false, "invalid task removal");
            return;
        }
        if let Some(entry) = self
            .entries
            .get_mut(usize::try_from(id.index).unwrap_or(usize::MAX))
        {
            if let Some(slot) = entry.task.take() {
                ctx.discard(slot);
            }
            self.free.push(id.index);
        }
    }
    /// 終わっていないタスクの数。
    pub fn live_count(&self) -> u32 {
        u32::try_from(self.entries.iter().filter(|e| e.task.is_some()).count()).unwrap_or(u32::MAX)
    }
}

impl TaskTable {
    pub(crate) fn check_insert(&self) -> Result<(), crate::runtime::Stop> {
        if let Some(&index) = self.free.last() {
            if self
                .entries
                .get(usize::try_from(index).unwrap_or(usize::MAX))
                .is_none_or(|e| e.task.is_some())
            {
                return Err(super::state::internal("invalid free task entry"));
            }
        } else if u32::try_from(self.entries.len()).map_or(true, |n| n == u32::MAX) {
            return Err(super::state::internal("task table overflow"));
        }
        Ok(())
    }
    pub(crate) fn check_remove(&self, id: TaskId) -> Result<(), crate::runtime::Stop> {
        if self
            .entries
            .get(usize::try_from(id.index).unwrap_or(usize::MAX))
            .is_none_or(|e| e.generation != id.generation || e.task.is_none())
        {
            return Err(super::state::internal("invalid task removal"));
        }
        Ok(())
    }
}
