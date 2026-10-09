//! ハンドラの記録、継続、Lazy の対象（設計書 02-08「ハンドラと継続」「明示遅延」、ADR 0160・0266・0267）。

use crate::bytecode::program::HandlerIdx;
use crate::runtime::heap::{HostData, Slot, Trace, Tracer};

use super::TaskId;
use super::frame::Segment;

/// ハンドラの記録（02-08「ハンドラの記録とハンドラの連鎖」）。
#[derive(Debug)]
pub struct HandlerRecord {
    /// 節の関数の値の並び（10-07 のハンドラの記述の順）
    pub clauses: Vec<Slot>,
    /// ハンドラの記述の、プログラム全体の並びの番号（10-07 の `CompiledProgram::handlers`）
    pub desc: HandlerIdx,
    /// この `handle` を評価したタスク
    pub evaluated_by: TaskId,
    /// 属する終わっていないタスク（ADR 0266 の決定 6・7）
    pub members: Vec<TaskId>,
    /// 本体が終わったか。本体が終わり、`members` が空になるまで記録を残す
    pub body_finished: bool,
}

impl Trace for HandlerRecord {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slots(&self.clauses);
    }
}

impl HostData for HandlerRecord {}

/// 継続の状態（02-08「値の表現」の表の継続）。
#[derive(Debug)]
pub enum ContState {
    /// 捕まえた区画の並び（下から上の順）
    Captured(Vec<Segment>),
    /// 使用済み
    Used,
    /// 直接の再開（引き継いだハンドラの末尾で再開する節）
    Direct,
}

impl Trace for ContState {
    fn trace(&self, t: &mut Tracer<'_>) {
        if let ContState::Captured(segments) = self {
            segments.trace(t);
        }
    }
}

impl HostData for ContState {}

/// `Lazy` の対象の状態（ADR 0267 の決定 2）。
#[derive(Debug)]
pub enum LazyState {
    /// 本体の関数の値
    Before {
        body: Slot,
    },
    /// 評価の途中。取り消しと止める手順で「評価の前」に戻すため、本体の関数を捨てない
    Evaluating {
        body: Slot,
        by: TaskId,
        waiters: Vec<TaskId>,
    },
    Done {
        value: Slot,
    },
}

impl Trace for LazyState {
    fn trace(&self, t: &mut Tracer<'_>) {
        match self {
            LazyState::Before { body } | LazyState::Evaluating { body, .. } => t.slot(body),
            LazyState::Done { value } => t.slot(value),
        }
    }
}

impl HostData for LazyState {}
