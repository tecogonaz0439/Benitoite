//! 辿りの順序・途中の停止・根の契約（実装プラン R21）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::bytecode::program::HandlerIdx;
use crate::runtime::heap::{Heap, HeapConfig, ResourceId};
use crate::runtime::{ReleaseFailure, ResourceKind};
use crate::vm::TaskId;
use crate::vm::frame::{FrameKind, HandleFrame, OtherFrame, TaskStack};
use crate::vm::handler::{ContState, HandlerRecord};
use crate::vm::task::{TaskEndWait, WaitReason};

fn at() -> InstrRef {
    InstrRef {
        proto: ProtoIdx(0),
        pc: 0,
    }
}
fn call(base: u32, size: u32) -> CallFrame {
    CallFrame {
        func: Slot::default(),
        proto: ProtoIdx(0),
        pc: 0,
        base,
        size,
        ret: None,
        call_site: None,
        boundary: true,
        chain_resume: None,
    }
}
fn failure() -> ReleaseFailure {
    ReleaseFailure {
        kind: ResourceKind::FileWriter,
        opened_at: Some(at()),
        reason: "test failure".into(),
    }
}
fn work(segments: Vec<Segment>) -> UnwindWork {
    UnwindWork {
        cause: UnwindCause::DropRel,
        segments: segments
            .into_iter()
            .map(|segment| (segment, UnwindCause::DropRel))
            .collect(),
        waiting: None,
        log: ReleaseLog::default(),
    }
}
fn handle(ctx: &mut NoGcCtx<'_>, member: bool) -> OtherFrame {
    let record = ctx.alloc_host(HandlerRecord {
        clauses: vec![],
        desc: HandlerIdx(0),
        evaluated_by: TaskId {
            index: 0,
            generation: 0,
        },
        members: if member {
            vec![TaskId {
                index: 1,
                generation: 0,
            }]
        } else {
            vec![]
        },
        body_finished: false,
    });
    OtherFrame {
        depth: 0,
        kind: OtherKind::Handle(HandleFrame {
            record: ctx.new_slot(record),
            ret: 0,
            at: at(),
        }),
    }
}

// 関門: R24 の解放処理を呼ばずに、二つの Vec から復元する順序を確かめる。
// 作業文書が指定する内部の順序のテストであり、一般の境界の原則の例外（R21）。
#[test]
fn traversal_selects_call_then_wrapper_then_own_release_then_call() {
    let mut w = work(vec![Segment {
        calls: vec![call(0, 1), call(1, 1)],
        others: vec![
            OtherFrame {
                depth: 1,
                kind: OtherKind::Release {
                    resource: ResourceId(0),
                    at: at(),
                },
            },
            OtherFrame {
                depth: 1,
                kind: OtherKind::Drop {
                    cont: Slot::default(),
                },
            },
        ],
        regs: vec![Slot::default(), Slot::default()],
    }]);
    let mut seen = vec![];
    while let Some(position) = next_frame(&w) {
        let segment = &mut w.segments[0].0;
        seen.push(match position {
            FrameAt::Call(_) => {
                segment.calls.pop().unwrap();
                FrameKind::Call
            }
            FrameAt::Other(_) => segment.others.pop().unwrap().kind.frame_kind(),
        });
    }
    assert_eq!(
        seen,
        vec![
            FrameKind::Call,
            FrameKind::Drop,
            FrameKind::Release,
            FrameKind::Call
        ]
    );
}

// 関門: 既に始めた解放と集めた失敗を失う退行を、公開の escalate の契約で捕まえる（R21）。
#[test]
fn escalation_preserves_progress_log_and_resource_wait() {
    for waiting in [
        WaitReason::TaskEnd(TaskEndWait::HandleEnd),
        WaitReason::Release(ResourceId(3)),
    ] {
        let segment = |pc| Segment {
            calls: vec![CallFrame { pc, ..call(0, 0) }],
            ..Segment::default()
        };
        let mut w = work(vec![segment(1), segment(2)]);
        w.log.failures.push(failure());
        w.waiting = Some(waiting);
        let unwait = w.escalate(
            TaskStack {
                segments: vec![segment(0)],
            },
            UnwindCause::Stop,
        );
        assert_eq!(
            w.segments
                .iter()
                .map(|(s, _)| s.calls[0].pc)
                .collect::<Vec<_>>(),
            vec![0, 1, 2]
        );
        assert!(
            w.segments
                .iter()
                .all(|(_, cause)| *cause == UnwindCause::Stop)
        );
        assert_eq!(w.cause, UnwindCause::Stop);
        assert_eq!(w.log.failures, vec![failure()]);
        assert_eq!(unwait, matches!(waiting, WaitReason::TaskEnd(_)));
        assert_eq!(w.waiting, if unwait { None } else { Some(waiting) });
    }
}

// 関門: 一つのタスクでは言語から作れない「E-DropRel の途中の停止」を本物の辿りで進める。
// 戻りへの復帰、入れ子へ原因を渡す誤り、log の消失を同時に検出する（R21 の指定）。
#[test]
fn stopping_inside_nested_drop_keeps_progress_and_uses_stop_cause() {
    let mut heap = Heap::new(HeapConfig {
        stress: true,
        ..HeapConfig::default()
    });
    let mut state = RunState::new(VmConfig::default(), 0);
    heap.epoch(|ctx| {
        let deepest = Segment {
            others: vec![handle(ctx, true)],
            ..Segment::default()
        };
        let nested = ctx.alloc_host(ContState::Captured(vec![deepest]));
        let middle = Segment {
            others: vec![
                handle(ctx, true),
                OtherFrame {
                    depth: 0,
                    kind: OtherKind::Drop {
                        cont: ctx.new_slot(nested),
                    },
                },
            ],
            ..Segment::default()
        };
        let captured = ctx.alloc_host(ContState::Captured(vec![middle]));
        let outer = Segment {
            others: vec![OtherFrame {
                depth: 0,
                kind: OtherKind::Drop {
                    cont: ctx.new_slot(captured),
                },
            }],
            ..Segment::default()
        };
        state.unwinding = Some(work(vec![outer]));
        state.stack.segments.push(Segment {
            calls: vec![call(0, 0)],
            ..Segment::default()
        });
        state.returning = Some(ReturnWork {
            value: ctx.new_slot(Value::Unit),
            dest: ReturnDest::Pending,
            stage: ReturnStage::Wrapping,
            at: at(),
        });
        state.meter.grow(5, 0);
        assert!(!advance(&mut state, ctx).unwrap());
        assert_eq!(state.unwinding.as_ref().unwrap().segments.len(), 2);
        state
            .unwinding
            .as_mut()
            .unwrap()
            .log
            .failures
            .push(failure());
    });
    heap.collect(&state);
    heap.epoch(|ctx| {
        begin_stop(&mut state, ctx, StopReason::Exit(7));
        assert!(state.returning.is_none());
        let w = state.unwinding.as_ref().unwrap();
        assert_eq!(w.segments.len(), 3);
        assert_eq!(w.log.failures, vec![failure()]);
        assert!(w.segments.iter().all(|(_, c)| *c == UnwindCause::Stop));
        // 次の drop が受け取った Stop を、取り出した区画に付けることを確かめる。
        assert!(!advance(&mut state, ctx).unwrap());
        assert_eq!(state.unwinding.as_ref().unwrap().segments.len(), 4);
        assert_eq!(
            state.unwinding.as_ref().unwrap().segments.last().unwrap().1,
            UnwindCause::Stop
        );
    });
    // members を持つ二つの handle が DropRel を受け取ると待つ。Stop なら待たずに降りる。
    loop {
        let exit = heap.epoch(|ctx| cleanup(&mut state, ctx));
        if exit == LoopExit::Return {
            break;
        }
        heap.collect(&state);
    }
    assert_eq!(
        state.step,
        Some(VmStep::Stopped(StopEnd {
            reason: StopReason::Exit(7),
            release_failures: vec![failure()]
        }))
    );
    assert_eq!(state.meter.bytes(), 0);
    assert!(state.unwinding.is_none());
    assert!(heap.take_fault().is_none());
}

// 関門: UnwindWork の区画だけに残る根と、ReturnWork だけに残る値を回収を挟んで読み直す。
// 通常の戻りの根のテストは、積み重ねの外の区画を通らない（R03 の引き渡し、R21）。
#[test]
fn traversal_segments_and_clause_return_value_remain_roots_across_collection() {
    let mut heap = Heap::new(HeapConfig {
        stress: true,
        ..HeapConfig::default()
    });
    let mut state = RunState::new(VmConfig::default(), 0);
    heap.epoch(|ctx| {
        crate::vm::dispatch::tasks::start_main(&mut state, ctx).unwrap();
        let record = handle(ctx, false);
        let record_value = match &record.kind {
            OtherKind::Handle(h) => ctx.load(&h.record),
            OtherKind::Release { .. }
            | OtherKind::Update { .. }
            | OtherKind::CellUpdate(_)
            | OtherKind::Drop { .. } => panic!("handle required"),
        };
        let segment = Segment {
            calls: vec![call(0, 1), call(1, 0)],
            others: vec![record],
            regs: vec![ctx.new_slot(record_value)],
        };
        state.unwinding = Some(work(vec![segment]));
        let value = ctx.alloc_str("clause result", "test").unwrap();
        state.returning = Some(ReturnWork {
            value: ctx.new_slot(value),
            dest: ReturnDest::Pending,
            stage: ReturnStage::Wrapping,
            at: at(),
        });
        state.meter.grow(3, 1);
        assert!(!advance(&mut state, ctx).unwrap());
    });
    heap.collect(&state);
    heap.epoch(|ctx| {
        assert_eq!(
            ctx.str(ctx.load(&state.returning.as_ref().unwrap().value)),
            Some("clause result")
        );
        let segment = &state.unwinding.as_ref().unwrap().segments[0].0;
        assert!(
            !ctx.host::<HandlerRecord>(ctx.load(&segment.regs[0]))
                .unwrap()
                .body_finished
        );
        assert!(!advance(&mut state, ctx).unwrap());
        // handle の処理も回収を越えて同じ記録を読む。
        assert!(!advance(&mut state, ctx).unwrap());
        assert!(!advance(&mut state, ctx).unwrap());
        assert!(matches!(
            traverse(&mut state, ctx).unwrap(),
            Control::Reload
        ));
        assert_eq!(
            ctx.str(ctx.load(&state.returning.as_ref().unwrap().value)),
            Some("clause result")
        );
        ctx.discard(state.returning.take().unwrap());
        state.tasks.remove(ctx, state.current_task);
    });
    heap.collect(&state);
    assert!(heap.object_ids().is_empty());
    assert!(heap.take_fault().is_none());
    assert_eq!(state.meter.bytes(), 0);
}
