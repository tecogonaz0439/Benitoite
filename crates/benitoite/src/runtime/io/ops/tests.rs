//! 完了の順序と照合を、外部操作の表の境界で確かめる（実装プラン R26）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
use super::*;
use crate::bytecode::program::ProtoIdx;
use crate::runtime::ResourceKind;
use crate::runtime::io::resources::{LendResult, ReleaseStart, ResourceContent, ResourceState};
#[derive(Debug)]
struct Resource;
impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        Ok(())
    }
}
// 関門: 返却を配送より後にする、取り消しで記録を消す、panic を捨てる退行を
// 凍結した完了の API で捕まえる。VM のテストだけでは完了の種類と順序を分離できない。
#[test]
fn completion_returns_before_delivery_and_keeps_detached_cleanup_and_bugs() {
    let op = ExtOpId(7);
    let task = TaskId {
        index: 2,
        generation: 4,
    };
    let site = Some(InstrRef {
        proto: ProtoIdx(0),
        pc: 9,
    });
    for case in 0..4 {
        let mut resources = ResourceTable::default();
        let id = resources.insert(
            ResourceKind::FileWriter,
            ResourceContent::Os(Some(Box::new(Resource))),
            site,
        );
        let LendResult::Lent(handle) = resources.lend(id, op, task) else {
            panic!("lend failed")
        };
        let mut ops = OpTable::default();
        ops.insert(
            op,
            OpRecord {
                kind: OpKind::Worker,
                deliver_to: Some(task),
                lent: Some(id),
                site,
            },
        );
        if case != 0 {
            ops.detach_task(task);
        }
        if case == 3 {
            assert!(matches!(
                resources.request_release(id, ExtOpId(8)),
                ReleaseStart::AfterReturn
            ));
        }
        let outcome = if case == 2 {
            Outcome::Panicked(PanicReport {
                message: "worker panic".into(),
                location: None,
                backtrace: None,
            })
        } else {
            Outcome::Ready
        };
        let completion = Completion {
            op,
            outcome,
            returned: LentOwned::Resource(id, handle),
        };
        assert!(check_completion(&ops, &resources, &completion).is_ok());
        let events = accept_completion(&mut ops, &mut resources, &mut None, completion);
        assert!(ops.records.is_empty());
        assert_eq!(resources.state(id), Some(ResourceState::Open));
        assert!(matches!(
            resources.entries[&id].content,
            ResourceContent::Os(Some(_))
        ));
        assert_eq!(events.len(), 2);
        if case == 3 {
            assert!(matches!(events[0],Accepted::StartRelease(r) if r == id));
        } else {
            assert!(matches!(events[0],Accepted::Returned(r) if r == id));
        }
        match case {
            0 => assert!(
                matches!(events[1],Accepted::Deliver{task:t,op:o,site:s,..} if t==task && o==op && s==site)
            ),
            2 => assert!(matches!(events[1], Accepted::Bug(_))),
            _ => assert!(matches!(events[1], Accepted::Dropped)),
        }
        assert!(
            check_completion(
                &ops,
                &resources,
                &Completion {
                    op,
                    outcome: Outcome::Ready,
                    returned: LentOwned::Nothing
                }
            )
            .is_err()
        );
    }
}
#[test]
fn release_completion_finishes_without_delivery_and_rejects_wrong_return() {
    let op = ExtOpId(4);
    let mut resources = ResourceTable::default();
    let id = resources.insert(
        ResourceKind::FileWriter,
        ResourceContent::Os(Some(Box::new(Resource))),
        None,
    );
    assert!(matches!(
        resources.request_release(id, op),
        ReleaseStart::Blocking
    ));
    let (_, _, handle) = resources.take_release_job().unwrap();
    let mut ops = OpTable::default();
    ops.insert(
        op,
        OpRecord {
            kind: OpKind::Release(id),
            deliver_to: None,
            lent: None,
            site: None,
        },
    );
    let invalid = Completion {
        op,
        outcome: Outcome::Released(Ok(())),
        returned: LentOwned::Resource(id, handle),
    };
    assert!(check_completion(&ops, &resources, &invalid).is_err());
    let events = accept_completion(
        &mut ops,
        &mut resources,
        &mut None,
        Completion {
            op,
            outcome: Outcome::Released(Err("release failed".into())),
            returned: LentOwned::Nothing,
        },
    );
    assert!(matches!(&events[..],[Accepted::ReleaseFinished(r)] if *r==id));
    assert_eq!(resources.state(id), Some(ResourceState::Released));
    assert_eq!(
        resources.take_release_failure(id).as_deref(),
        Some("release failed")
    );
}
