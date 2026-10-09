//! 外部の操作の記録と完了（ADR 0266 の決定 3・4・9・11）。

use std::collections::{BTreeMap, BTreeSet};
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
    task_ops: BTreeMap<TaskId, BTreeSet<ExtOpId>>,
}

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
    Deliver {
        task: TaskId,
        op: ExtOpId,
        site: Option<InstrRef>,
        outcome: Outcome,
    },
    /// 配送先を外した記録の完了なので、値と失敗を捨てた
    Dropped,
}

impl OpTable {
    pub fn insert(&mut self, op: ExtOpId, record: OpRecord) {
        // VM が check_insert を通す。二重の登録で既存の記録を失わない（実装プラン R26）。
        if self.check_insert(op).is_err() {
            debug_assert!(false, "operation already recorded");
            return;
        }
        if let Some(task) = record.deliver_to {
            self.task_ops.entry(task).or_default().insert(op);
        }
        self.records.insert(op, record);
    }
    /// 取り消したタスクの記録から `deliver_to` を外す。記録は残す。
    pub fn detach_task(&mut self, task: TaskId) {
        if let Some(ops) = self.task_ops.remove(&task) {
            for op in ops {
                if let Some(record) = self.records.get_mut(&op) {
                    record.deliver_to = None;
                }
            }
        }
    }
    pub(crate) fn task_operations(&self, task: TaskId) -> Vec<ExtOpId> {
        self.task_ops
            .get(&task)
            .map(|ops| ops.iter().copied().collect())
            .unwrap_or_default()
    }
    pub(crate) fn detach_all(&mut self) {
        for record in self.records.values_mut() {
            record.deliver_to = None;
        }
        self.task_ops.clear();
    }
    fn remove(&mut self, op: ExtOpId) -> Option<OpRecord> {
        let record = self.records.remove(&op)?;
        if let Some(task) = record.deliver_to
            && let Some(ops) = self.task_ops.get_mut(&task)
        {
            ops.remove(&op);
            if ops.is_empty() {
                self.task_ops.remove(&task);
            }
        }
        Some(record)
    }
}

/// 完了を受け取る共通の処理（ADR 0266 の決定 4）。
/// `stdin` は、標準入力の読み手を返す置き場。
pub fn accept_completion(
    ops: &mut OpTable,
    resources: &mut ResourceTable,
    stdin: &mut Option<Box<dyn StdinReader>>,
    completion: Completion,
) -> Vec<Accepted> {
    // 呼ぶ側が check_completion を通す。凍結した戻り値では不整合を報告できない（実装プラン R26）。
    if check_completion(ops, resources, &completion).is_err() {
        debug_assert!(false, "invalid completion");
        return Vec::new();
    }
    let Some(record) = ops.remove(completion.op) else {
        return Vec::new();
    };
    let mut accepted = Vec::new();
    match completion.returned {
        LentOwned::Nothing => {}
        LentOwned::Stdin(reader) => *stdin = Some(reader),
        LentOwned::Resource(id, handle) => {
            accepted.push(if resources.give_back(id, handle) {
                Accepted::StartRelease(id)
            } else {
                Accepted::Returned(id)
            });
        }
    }
    if let OpKind::Release(id) = record.kind {
        let result = match &completion.outcome {
            Outcome::Released(result) => result.clone(),
            Outcome::Panicked(_) => Ok(()),
            Outcome::Worker(_) | Outcome::Ready => {
                debug_assert!(false, "release completion has wrong outcome");
                return accepted;
            }
        };
        resources.finish_release(id, result);
        accepted.push(Accepted::ReleaseFinished(id));
    }
    match completion.outcome {
        Outcome::Panicked(report) => accepted.push(Accepted::Bug(report)),
        outcome if !matches!(record.kind, OpKind::Release(_)) => {
            accepted.push(match record.deliver_to {
                Some(task) => Accepted::Deliver {
                    task,
                    op: completion.op,
                    site: record.site,
                    outcome,
                },
                None => Accepted::Dropped,
            });
        }
        Outcome::Worker(_) | Outcome::Ready | Outcome::Released(_) => {}
    }
    accepted
}

impl OpTable {
    pub(crate) fn check_insert(&self, op: ExtOpId) -> Result<(), crate::runtime::Stop> {
        if self.records.contains_key(&op) {
            Err(crate::vm::state::internal("operation already recorded"))
        } else {
            Ok(())
        }
    }
}

pub(crate) fn check_completion(
    ops: &OpTable,
    resources: &ResourceTable,
    completion: &Completion,
) -> Result<(), crate::runtime::Stop> {
    use super::resources::{ResourceContent, ResourceState};
    use crate::vm::state::internal;
    let record = ops
        .records
        .get(&completion.op)
        .ok_or_else(|| internal("completion has no operation record"))?;
    match (&completion.returned, record.lent) {
        (LentOwned::Resource(id, _), Some(expected)) if *id == expected => {
            let entry = resources
                .entries
                .get(id)
                .ok_or_else(|| internal("returned resource missing"))?;
            if !matches!(entry.state, ResourceState::Lent(op, _) if op == completion.op)
                || !matches!(entry.content, ResourceContent::Os(None))
            {
                return Err(internal("returned resource is not lent to operation"));
            }
        }
        (LentOwned::Nothing | LentOwned::Stdin(_), None) => {}
        _ => return Err(internal("returned resource does not match record")),
    }
    if matches!(record.kind, OpKind::Release(_))
        != matches!(completion.outcome, Outcome::Released(_))
        && !matches!(completion.outcome, Outcome::Panicked(_))
    {
        return Err(internal("completion outcome does not match operation"));
    }
    Ok(())
}

/// 貸したものを panic 境界の外に保ち、成功でも panic でも返す（ADR 0266 の決定 9）。
pub(crate) fn execute_job(mut job: WorkerJob) -> Completion {
    use crate::builtins::iface::Lent;
    let outcome = crate::runtime::panic::catch(|| match job.work {
        JobWork::Builtin(work) => {
            let lent = match &mut job.lent {
                LentOwned::Nothing => Lent::Nothing,
                LentOwned::Resource(_, handle) => Lent::Resource(&mut **handle),
                LentOwned::Stdin(reader) => Lent::Stdin(&mut **reader),
            };
            Outcome::Worker(work.run(lent))
        }
        JobWork::Release(handle) => Outcome::Released(handle.release()),
    })
    .unwrap_or_else(Outcome::Panicked);
    Completion {
        op: job.op,
        outcome,
        returned: job.lent,
    }
}

#[cfg(test)]
mod tests;
