//! 解放の枠と USE・RELEASE の冷たい経路（設計書 02-08「リソースの解放の枠」、02-09「リソースの追跡」）。

use super::*;
use crate::runtime::{ReleaseFailure, ResourceKind};
use crate::vm::TaskId;
use crate::vm::frame::{OtherFrame, OtherKind};
use crate::vm::unwind::{self, ReleaseLog, UnwindCause, UnwindStep};

#[cold]
#[inline(never)]
pub(super) fn dispatch(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
) -> Result<Control, Stop> {
    let depth = u32::try_from(state.segment()?.calls.len())
        .map_err(|_| missing("release depth overflow"))?;
    match instr.opcode() {
        Some(Opcode::Use) => {
            let resource = read_one(
                ctx,
                active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
                instr.a(),
            )?
            .as_resource()
            .ok_or_else(|| missing("USE requires a resource"))?;
            state.resources.check_release(resource)?;
            if !state.meter.fits(1, 0) {
                return Err(Stop::Resource(ResourceError::CallStackTooDeep {
                    frames: state.meter.frames(),
                }));
            }
            state.segment_mut()?.others.push(OtherFrame {
                depth,
                kind: OtherKind::Release {
                    resource,
                    at: InstrRef {
                        proto: cursor.locals.proto,
                        pc: cursor.locals.pc,
                    },
                },
            });
            state.meter.grow(1, 0);
            Ok(Control::Next)
        }
        Some(Opcode::Release) => {
            let position = state
                .segment()?
                .others
                .iter()
                .rposition(|other| {
                    other.depth == depth && matches!(other.kind, OtherKind::Release { .. })
                })
                .ok_or_else(|| missing("RELEASE has no own release frame"))?;
            let other = state.segment_mut()?.others.remove(position);
            let result = if let OtherKind::Release { resource, at } = &other.kind {
                unwind::unwind_release(
                    ctx,
                    state,
                    state.current_task,
                    *resource,
                    *at,
                    UnwindCause::Return,
                    &mut ReleaseLog::default(),
                )
            } else {
                Err(missing("release frame changed"))
            };
            match result {
                Ok(UnwindStep::Popped) => {
                    ctx.discard(other);
                    state.meter.shrink(1, 0);
                    Ok(Control::Next)
                }
                result => {
                    // 待ちと失敗では同じ枠を元の位置に保つ。pc は命令の入口なので、
                    // 再開後は RELEASE を初めから実行する（実装プラン R24、ADR 0314）。
                    state.segment_mut()?.others.insert(position, other);
                    match result {
                        Ok(UnwindStep::Wait(reason)) => {
                            cursor.locals.save(state.frame_mut()?);
                            tasks::park(state, reason)
                        }
                        Err(stop) => Err(stop),
                        Ok(
                            UnwindStep::Retry | UnwindStep::Traverse { .. } | UnwindStep::Popped,
                        ) => Err(missing("invalid release unwind result")),
                    }
                }
            }
        }
        _ => Err(missing("unexpected resource instruction")),
    }
}

// 失敗を一度取り出した後に、現在の原因で扱う。待ちの間に取り消し・停止へ変わる場合も
// 同じ入口を使う（設計書 01-10「解放の失敗」、ADR 0149・0266）。
pub(in crate::vm) fn release_failure(
    kind: ResourceKind,
    opened_at: Option<InstrRef>,
    cause: UnwindCause,
    log: &mut ReleaseLog,
    reason: String,
) -> Result<UnwindStep, Stop> {
    if kind == ResourceKind::HttpExchange {
        return Ok(UnwindStep::Popped);
    }
    let failure = ReleaseFailure {
        kind,
        opened_at,
        reason,
    };
    match cause {
        UnwindCause::Return => Err(Stop::Runtime(RuntimeError::ReleaseFailed(vec![failure]))),
        UnwindCause::Cancel | UnwindCause::DropRel | UnwindCause::Stop => {
            log.failures.push(failure);
            Ok(UnwindStep::Popped)
        }
    }
}

// R39 で共通の取り消しの入口へ接続した。Return で待つ間に Cancel へ変わった場合にも
// 子を調べ直して取り消す（実装プラン R24・R39、ADR 0164）。
pub(in crate::vm) fn cancel_group_children(
    ctx: &mut NoGcCtx<'_>,
    state: &mut RunState,
    at: TaskId,
    children: &[TaskId],
) -> Result<(), Stop> {
    let ids: Vec<_> = children.iter().copied().filter(|&id| id != at).collect();
    crate::vm::dispatch::tasks::cancel::request(state, ctx, &ids)
}

pub(in crate::vm) fn group_children_pending(
    ctx: &NoGcCtx<'_>,
    state: &RunState,
    children: &[TaskId],
) -> Result<bool, Stop> {
    Ok(children
        .iter()
        .any(|&id| state.tasks.get(ctx, id).is_some()))
}

#[cfg(test)]
mod tests;
