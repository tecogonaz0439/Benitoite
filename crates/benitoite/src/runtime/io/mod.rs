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
    task_requests: BTreeMap<TaskId, RequestId>,
    outstanding: std::collections::BTreeSet<RequestId>,
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

/// 標準入力はリソースの表に載らないので、貸し出しの待ちだけに予約番号を使う（実装プラン R26）。
pub(crate) const STDIN_LEND: ResourceId = ResourceId(u64::MAX);

impl DispatchQueue {
    /// 番号を付けて要求を列に置く（段階 `Queued`）。呼び出し側は先にタスクを待たせておく。
    pub fn publish(&mut self, task: TaskId, op: &'static BuiltinDecl, site: InstrRef) -> RequestId {
        let id = RequestId(self.next_id);
        self.next_id = self.next_id.wrapping_add(1);
        self.live.insert(
            id,
            LiveRequest {
                req: Request { id, task, op, site },
                phase: RequestPhase::Queued,
            },
        );
        self.task_requests.insert(task, id);
        self.queued.push_back(id);
        id
    }
    /// 失効した番号と、呼び出し以外の段階の要求には `None` を返す。
    pub fn take_for_serve(&mut self, id: RequestId) -> Option<Request> {
        if !self
            .live
            .get(&id)
            .is_some_and(|r| matches!(r.phase, RequestPhase::Queued | RequestPhase::Outstanding))
        {
            return None;
        }
        let request = self.live.remove(&id)?.req;
        self.task_requests.remove(&request.task);
        self.outstanding.remove(&id);
        Some(request)
    }
    /// 応答の仕事と要求を、段階を付けて戻す。
    pub fn park_request(&mut self, req: Request, phase: RequestPhase) {
        // VM が先に確かめる。凍結した戻り値では不具合を返せない（実装プラン R26）。
        if self.check_park_request(&req).is_err() {
            debug_assert!(false, "request already live");
            return;
        }
        if matches!(phase, RequestPhase::Outstanding) {
            self.outstanding.insert(req.id);
        }
        self.task_requests.insert(req.task, req.id);
        self.live.insert(req.id, LiveRequest { req, phase });
    }
    pub(crate) fn check_park_request(&self, req: &Request) -> Result<(), crate::runtime::Stop> {
        if self.live.contains_key(&req.id) || self.task_requests.contains_key(&req.task) {
            Err(crate::vm::state::internal("request already live"))
        } else {
            Ok(())
        }
    }
    /// タスクの要求を除いて返す。
    pub fn take_task_request(&mut self, task: TaskId) -> Option<LiveRequest> {
        let id = self.task_requests.remove(&task)?;
        self.outstanding.remove(&id);
        // 列の番号は部品に渡すときに失効を調べる。取り消しごとに列を走査しない。
        self.live.remove(&id)
    }
    /// 取り消したタスクの要求と応答の仕事を捨てる。
    pub fn expire_task(&mut self, task: TaskId) {
        self.take_task_request(task);
    }
    /// 全体停止では、まだ外部の操作に移っていない要求をすべて捨てる。
    pub fn expire_all(&mut self) {
        self.queued.clear();
        self.live.clear();
        self.task_requests.clear();
        self.outstanding.clear();
    }
    /// 外側の応答を待つ要求があるか。
    pub fn has_outstanding(&self) -> bool {
        !self.outstanding.is_empty()
    }
}
impl Dispatcher for DirectDispatcher {
    fn on_wait_point(&mut self, queue: &mut DispatchQueue, _at: WaitPoint) -> DispatchAction {
        let ids: Vec<_> = queue
            .queued
            .drain(..)
            .filter(|id| queue.live.contains_key(id))
            .collect();
        if ids.is_empty() {
            DispatchAction::Nothing
        } else {
            DispatchAction::ServeNow(ids)
        }
    }
}
impl Dispatcher for RequestDispatcher {
    fn on_wait_point(&mut self, queue: &mut DispatchQueue, _at: WaitPoint) -> DispatchAction {
        let ids: Vec<_> = queue
            .queued
            .drain(..)
            .filter(|id| queue.live.contains_key(id))
            .collect();
        for id in &ids {
            if let Some(r) = queue.live.get_mut(id) {
                r.phase = RequestPhase::Outstanding;
                queue.outstanding.insert(*id);
            }
        }
        if !ids.is_empty() || queue.has_outstanding() {
            DispatchAction::ReturnToExecutor(ids)
        } else {
            DispatchAction::Nothing
        }
    }
}

#[cfg(test)]
mod tests {
    // 関門: 番号の失効と Outstanding の再通知は、部品の独立した契約である（R26）。
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used, clippy::indexing_slicing)]
    use super::*;
    use crate::bytecode::program::ProtoIdx;
    #[test]
    fn dispatchers_preserve_live_phases_and_expired_requests_are_inert() {
        let decl = crate::builtins::builtin_decl(
            crate::builtins::lookup_builtin("Benitoite.IO.File.readText").unwrap(),
        )
        .unwrap();
        let task = TaskId {
            index: 1,
            generation: 2,
        };
        let site = InstrRef {
            proto: ProtoIdx(0),
            pc: 3,
        };
        let mut queue = DispatchQueue::default();
        let first = queue.publish(task, decl, site);
        assert!(
            matches!(RequestDispatcher.on_wait_point(&mut queue,WaitPoint::Park),DispatchAction::ReturnToExecutor(ids) if ids==[first])
        );
        assert!(queue.has_outstanding());
        assert!(
            matches!(RequestDispatcher.on_wait_point(&mut queue,WaitPoint::SlowPath),DispatchAction::ReturnToExecutor(ids) if ids.is_empty())
        );
        queue.expire_task(task);
        assert!(queue.take_for_serve(first).is_none());
        let next = queue.publish(task, decl, site);
        assert_ne!(first, next);
        assert!(
            matches!(DirectDispatcher.on_wait_point(&mut queue,WaitPoint::Park),DispatchAction::ServeNow(ids) if ids==[next])
        );
        let req = queue.take_for_serve(next).unwrap();
        queue.park_request(req, RequestPhase::Outstanding);
        assert!(queue.check_park_request(&req).is_err());
        assert!(queue.take_task_request(task).is_some());
        queue.publish(task, decl, site);
        queue.expire_all();
        assert!(queue.queued.is_empty() && queue.live.is_empty());
    }
}

pub mod http;
