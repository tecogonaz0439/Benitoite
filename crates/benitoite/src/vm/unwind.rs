//! 枠を降ろす原因と処理（設計書 02-08「枠を降ろす原因と処理」「取り消し」「止める手順」、ADR 0267 の決定 4）。

use crate::runtime::ReleaseFailure;
use crate::runtime::heap::{Discard, Discarder, Slot, Trace, Tracer};

use super::InstrRef;
use super::frame::{Segment, TaskStack};
use super::task::WaitReason;

/// 枠を降ろす原因。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum UnwindCause {
    /// `RETURN` と `ESCAPE`
    Return,
    /// タスクの取り消し
    Cancel,
    /// 節が `resume` を呼ばずに終わった（E-DropRel）
    DropRel,
    /// 全体の停止（止める手順）
    Stop,
}

/// 枠一つを処理した結果。
#[derive(Debug)]
pub enum UnwindStep {
    /// 枠の種類ごとの処理を終えた。枠を取り出して所有する `Slot` を手放すのは呼び出し側
    Popped,
    /// 枠を残して待つ。待ちが解けたら同じ枠に同じ原因でもう一度処理する
    Wait(WaitReason),
    /// セルの更新の枠で版の番号が変わっていた。セルを読み直して関数を呼び直す
    Retry,
    /// `drop` の枠の継続の区画（下から上の順）を、`cause` で先に辿る。継続は使用済みにしてある
    Traverse {
        segments: Vec<Segment>,
        cause: UnwindCause,
    },
}

/// 取り消し・E-DropRel・止める手順で集める解放の失敗。
#[derive(Debug, Default)]
pub struct ReleaseLog {
    pub failures: Vec<ReleaseFailure>,
}

/// 取り消し・止める手順・E-DropRel で枠を辿る途中の状態。
#[derive(Debug)]
pub struct UnwindWork {
    pub cause: UnwindCause,
    /// 辿る区画と、その区画を辿る原因（最後の要素から辿る）。タスクの積み重ねの区画は、辿り始めるときにここへ移す
    pub segments: Vec<(Segment, UnwindCause)>,
    /// 待っているときの理由
    pub waiting: Option<WaitReason>,
    pub log: ReleaseLog,
}

impl Trace for UnwindWork {
    fn trace(&self, t: &mut Tracer<'_>) {
        for (segment, _) in &self.segments {
            segment.trace(t);
        }
    }
}

impl UnwindWork {
    /// 辿る途中の状態を原因 `cause`（`Stop`、または E-DropRel を辿り終えた後の `Cancel`）へ移す
    /// （10-09「既に枠を降ろしているタスクの扱い」）。辿る位置、区画、`log` は保つ。`rest` はタスクの
    /// 積み重ねに残る区画であり、辿る区画の下に加える。全体の停止では子のタスクの終わりの待ちを外し、
    /// 外したら `true` を返す（呼び出し側がタスクを進められるタスクに戻す）。
    pub fn escalate(&mut self, rest: TaskStack, cause: UnwindCause) -> bool {
        let mut segments: Vec<(Segment, UnwindCause)> =
            rest.segments.into_iter().map(|s| (s, cause)).collect();
        segments.append(&mut self.segments);
        for (_, c) in &mut segments {
            *c = cause;
        }
        self.segments = segments;
        self.cause = cause;
        let unwait =
            cause == UnwindCause::Stop && matches!(self.waiting, Some(WaitReason::TaskEnd(_)));
        if unwait {
            self.waiting = None;
        }
        unwait
    }
}

/// 戻りの処理の段階（10-09「戻りの再開状態」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReturnStage {
    /// `RETURN`: 降ろす呼び出しの枠に属する解放の枠を処理している。呼び出しの枠はまだ降ろしていない
    OwnReleases,
    /// 呼び出しの枠を降ろし、同じ深さの包む枠を処理している。区画の底の `handle` の枠は戻り先を決める
    Wrapping,
    /// `ESCAPE`: 関数の境界の呼び出しの枠に達するまで枠を降ろしている。`handle` の枠は戻り先を決めない
    Escaping,
}

/// 戻り先。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReturnDest {
    /// まだ決まっていない
    Pending,
    /// タスクの積み重ねの下から `segment` 番目の区画の `regs` の `reg`
    Reg { segment: u32, reg: u32 },
    /// タスクの最初の呼び出しの枠から戻ったので、値をタスクの結果にする
    TaskResult,
}

/// 戻りの再開状態。タスクごとに一つ持ち、待ちと回収をまたいで保つ。
#[derive(Debug)]
pub struct ReturnWork {
    /// 戻る値
    pub value: Slot,
    pub dest: ReturnDest,
    pub stage: ReturnStage,
    /// 戻りを始めた命令（`RETURN`・`ESCAPE`）。戻りの処理から止まるときの止まった命令
    pub at: InstrRef,
}

impl Trace for ReturnWork {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slot(&self.value);
    }
}

impl Discard for ReturnWork {
    fn discard(self, d: &mut Discarder<'_>) {
        d.slot(self.value);
    }
}

use crate::runtime::Stop;
use crate::runtime::heap::{NoGcCtx, ResourceId};

use super::TaskId;
use super::frame::{CellUpdate, HandleFrame};
use super::state::RunState;

/// 解放の枠。`opened_at` は枠を積んだ `USE` の命令。
pub fn unwind_release<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut RunState,
    at: TaskId,
    resource: ResourceId,
    opened_at: InstrRef,
    cause: UnwindCause,
    log: &mut ReleaseLog,
) -> Result<UnwindStep, Stop> {
    rt.resources.check_release(resource)?;
    if cause == UnwindCause::Stop
        && crate::runtime::io::http::stop_exchange(&mut rt.resources, resource)
    {
        return Ok(UnwindStep::Popped);
    }
    let kind = rt
        .resources
        .kind(resource)
        .ok_or_else(|| super::state::internal("released resource missing"))?;
    let original_opened_at = rt
        .resources
        .entries
        .get(&resource)
        .and_then(|entry| entry.opened_at)
        .or(Some(opened_at));
    let op = rt.scheduler.new_ext_op_id();
    match rt.resources.request_release(resource, op) {
        crate::runtime::io::resources::ReleaseStart::AlreadyReleased => {
            if let Some(reason) = rt.resources.take_release_failure(resource) {
                super::dispatch::resource::release_failure(
                    kind,
                    original_opened_at,
                    cause,
                    log,
                    reason,
                )
            } else {
                Ok(UnwindStep::Popped)
            }
        }
        crate::runtime::io::resources::ReleaseStart::Done(result) => match result {
            Ok(()) => Ok(UnwindStep::Popped),
            Err(reason) => {
                rt.resources.take_release_failure(resource);
                super::dispatch::resource::release_failure(
                    kind,
                    original_opened_at,
                    cause,
                    log,
                    reason,
                )
            }
        },
        crate::runtime::io::resources::ReleaseStart::Blocking
        | crate::runtime::io::resources::ReleaseStart::AfterReturn
        | crate::runtime::io::resources::ReleaseStart::InProgress => {
            Ok(UnwindStep::Wait(WaitReason::Release(resource)))
        }
        crate::runtime::io::resources::ReleaseStart::TaskGroup(children) => {
            if cause == UnwindCause::Stop {
                return Ok(UnwindStep::Popped);
            }
            if matches!(cause, UnwindCause::Cancel | UnwindCause::DropRel) {
                super::dispatch::resource::cancel_group_children(ctx, rt, at, &children)?;
            }
            if super::dispatch::resource::group_children_pending(ctx, rt, &children)? {
                Ok(UnwindStep::Wait(WaitReason::TaskEnd(
                    super::task::TaskEndWait::TaskGroupRelease(resource),
                )))
            } else {
                Ok(UnwindStep::Popped)
            }
        }
    }
}

/// `update` の枠。`lazy` は評価の途中の `Lazy` の対象。
pub fn unwind_update<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut RunState,
    at: TaskId,
    lazy: &Slot,
    cause: UnwindCause,
) -> Result<UnwindStep, Stop> {
    super::dispatch::lazy::finish(ctx, rt, at, lazy, cause)
}

pub fn unwind_cell_update<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut RunState,
    at: TaskId,
    frame: &CellUpdate,
    cause: UnwindCause,
) -> Result<UnwindStep, Stop> {
    let _ = at;
    if cause != UnwindCause::Return {
        return Ok(UnwindStep::Popped);
    }
    let cell = ctx.load(&frame.cell);
    let version = ctx
        .cell_version(cell)
        .ok_or_else(|| super::state::internal("cell update requires a cell"))?;
    if version != frame.version {
        return Ok(UnwindStep::Retry);
    }
    let work = rt
        .returning
        .as_mut()
        .ok_or_else(|| super::state::internal("cell update return work missing"))?;
    // 確かめと書き込みの間に安全点を置かず、UPDATE の結果は Unit に替える
    // （設計書 02-08「可変のセル」、実装プラン 10-09「戻りの再開状態」）。
    ctx.cell_set(cell, ctx.load(&work.value))?;
    ctx.store(&mut work.value, crate::runtime::heap::Value::Unit);
    Ok(UnwindStep::Popped)
}

pub fn unwind_handle<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut RunState,
    at: TaskId,
    frame: &HandleFrame,
    cause: UnwindCause,
) -> Result<UnwindStep, Stop> {
    if matches!(cause, UnwindCause::Cancel | UnwindCause::DropRel) {
        cancel_handle_members(ctx, rt, at, frame)?;
    }
    ctx.host_mut::<super::handler::HandlerRecord, _>(ctx.load(&frame.record), |record, _| {
        record.body_finished = true;
        if cause == UnwindCause::Stop || record.members.is_empty() {
            UnwindStep::Popped
        } else {
            UnwindStep::Wait(WaitReason::TaskEnd(super::task::TaskEndWait::HandleEnd))
        }
    })
    .ok_or_else(|| super::state::internal("handler record required"))
}

/// `drop` の枠。`cont` は継続の値。
pub fn unwind_drop<'e>(
    ctx: &mut NoGcCtx<'e>,
    rt: &mut RunState,
    at: TaskId,
    cont: &Slot,
    cause: UnwindCause,
) -> Result<UnwindStep, Stop> {
    let _ = (rt, at);
    use super::handler::ContState;
    ctx.host_mut::<ContState, _>(ctx.load(cont), |state, _| match state {
        ContState::Used => Ok(UnwindStep::Popped),
        ContState::Captured(_) => {
            let ContState::Captured(segments) = std::mem::replace(state, ContState::Used) else {
                return Err(super::state::internal("continuation changed during unwind"));
            };
            Ok(UnwindStep::Traverse {
                segments,
                cause: if cause == UnwindCause::Return {
                    UnwindCause::DropRel
                } else {
                    cause
                },
            })
        }
        ContState::Direct => Err(super::state::internal(
            "direct continuation has no drop frame",
        )),
    })
    .ok_or_else(|| super::state::internal("continuation required"))?
}

// R39 で、所属タスクへの要求の記録と子の取り消しを共通の入口へ接続した
// （実装プラン R21「E-DropRel」、設計書 02-08「取り消し」）。
fn cancel_handle_members(
    ctx: &mut NoGcCtx<'_>,
    rt: &mut RunState,
    at: TaskId,
    frame: &HandleFrame,
) -> Result<(), Stop> {
    super::dispatch::tasks::cancel::handle_members(ctx, rt, at, frame)
}

/// E-DropRel の終了時に読む取り消しの印。R39 でタスクの印に接続した（実装プラン R21・R39）。
pub(crate) fn cancel_requested(ctx: &NoGcCtx<'_>, rt: &RunState) -> bool {
    // traverse が checked_requested を先に通すため、この失敗には到達しない（実装プラン R39）。
    match super::dispatch::tasks::cancel::checked_requested(ctx, rt) {
        Ok(requested) => requested,
        Err(_) => {
            debug_assert!(false, "cancellation check was not validated");
            false
        }
    }
}
