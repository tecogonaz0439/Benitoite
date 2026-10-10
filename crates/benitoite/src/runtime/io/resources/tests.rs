//! リソース表の遷移、所有の受け渡し、解放が一度だけ行われる契約（設計書 02-09、実装プラン R24）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use std::any::Any;
use std::sync::{Arc, Mutex};

#[derive(Debug, Default)]
struct Counts {
    released: usize,
    dropped: usize,
}
#[derive(Debug)]
struct Resource {
    counts: Arc<Mutex<Counts>>,
    fail: bool,
}
impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        self.counts.lock().unwrap().released += 1;
        if self.fail {
            Err("failed".into())
        } else {
            Ok(())
        }
    }
}
impl Drop for Resource {
    fn drop(&mut self) {
        self.counts.lock().unwrap().dropped += 1;
    }
}
fn task(index: u32) -> TaskId {
    TaskId {
        index,
        generation: 0,
    }
}
fn insert(
    table: &mut ResourceTable,
    kind: ResourceKind,
    fail: bool,
) -> (ResourceId, Arc<Mutex<Counts>>) {
    let counts = Arc::new(Mutex::new(Counts::default()));
    let handle = Box::new(Resource {
        counts: Arc::clone(&counts),
        fail,
    });
    (
        table.insert(kind, ResourceContent::Os(Some(handle)), None),
        counts,
    )
}
fn lent(table: &mut ResourceTable, id: ResourceId, op: u64, who: u32) -> Box<dyn OsResource> {
    table.check_lend(id).unwrap();
    match table.lend(id, ExtOpId(op), task(who)) {
        LendResult::Lent(handle) => handle,
        other @ (LendResult::MustWait | LendResult::Released(_)) => {
            panic!("expected lent: {other:?}")
        }
    }
}
fn release(table: &mut ResourceTable, id: ResourceId, op: u64) -> ReleaseStart {
    table.check_release(id).unwrap();
    table.request_release(id, ExtOpId(op))
}

// 関門: 表の公開の入口で、各状態の貸し出し・返却・解放と OS の所有を確かめる。
// 既存テストには資源の受け渡しがない。退行は再貸し出し・二重解放・早い Released。
#[test]
fn os_state_transitions_and_one_release_job() {
    for kind in [
        ResourceKind::FileReader,
        ResourceKind::HttpListener,
        ResourceKind::FileWriter,
        ResourceKind::HttpExchange,
    ] {
        for fail in [false, true] {
            let mut table = ResourceTable::default();
            let (id, counts) = insert(&mut table, kind, fail);
            assert_eq!(table.state(id), Some(ResourceState::Open));
            let handle = lent(&mut table, id, 1, 0);
            assert_eq!(
                table.state(id),
                Some(ResourceState::Lent(ExtOpId(1), false))
            );
            assert!(matches!(
                table.lend(id, ExtOpId(2), task(1)),
                LendResult::MustWait
            ));
            assert!(!table.give_back(id, handle));
            assert_eq!(table.state(id), Some(ResourceState::Open));
            assert_eq!(table.pop_waiter(id), Some(task(1)));
            let handle = lent(&mut table, id, 3, 1);
            for op in [4, 5] {
                assert!(matches!(
                    release(&mut table, id, op),
                    ReleaseStart::AfterReturn
                ));
                assert_eq!(table.state(id), Some(ResourceState::Lent(ExtOpId(3), true)));
            }
            assert!(matches!(
                table.lend(id, ExtOpId(6), task(2)),
                LendResult::MustWait
            ));
            assert!(table.give_back(id, handle));
            let result = release(&mut table, id, 7);
            if matches!(kind, ResourceKind::FileWriter | ResourceKind::HttpExchange) {
                assert!(matches!(result, ReleaseStart::Blocking));
                assert_eq!(table.state(id), Some(ResourceState::Releasing(ExtOpId(7))));
                assert!(
                    matches!(table.lend(id, ExtOpId(8), task(3)), LendResult::Released(k) if k == kind)
                );
                assert!(matches!(
                    release(&mut table, id, 9),
                    ReleaseStart::InProgress
                ));
                let (job_id, op, handle) = table.take_release_job().unwrap();
                assert_eq!((job_id, op), (id, ExtOpId(7)));
                assert!(table.take_release_job().is_none());
                assert!(matches!(
                    release(&mut table, id, 10),
                    ReleaseStart::InProgress
                ));
                table.finish_release(id, handle.release());
                assert_eq!(
                    table.take_release_failure(id),
                    fail.then(|| "failed".into())
                );
                assert!(table.take_release_failure(id).is_none());
            } else {
                let ReleaseStart::Done(result) = result else {
                    panic!("expected Done")
                };
                assert_eq!(result, if fail { Err("failed".into()) } else { Ok(()) });
            }
            assert_eq!(table.state(id), Some(ResourceState::Released));
            assert!(matches!(
                release(&mut table, id, 11),
                ReleaseStart::AlreadyReleased
            ));
            assert!(
                matches!(table.lend(id, ExtOpId(12), task(3)), LendResult::Released(k) if k == kind)
            );
            assert_eq!(counts.lock().unwrap().released, 1);
            assert_eq!(counts.lock().unwrap().dropped, 1);
        }
    }
}

// 関門: 返却順の契約と、取り消した待ちを返却で起こさない契約を同じ並びで守る。
#[test]
fn lending_is_fifo_and_cancelled_waiters_are_removed_from_every_resource() {
    for cancelled in [false, true] {
        let mut table = ResourceTable::default();
        let (id, counts) = insert(&mut table, ResourceKind::FileReader, false);
        let (other, _) = insert(&mut table, ResourceKind::FileReader, false);
        let (unrelated, _) = insert(&mut table, ResourceKind::FileReader, false);
        let unrelated_handle = lent(&mut table, unrelated, 20, 0);
        for who in [4, 5] {
            assert!(matches!(
                table.lend(unrelated, ExtOpId(21), task(who)),
                LendResult::MustWait
            ));
        }
        let mut handle = lent(&mut table, id, 0, 0);
        let other_handle = lent(&mut table, other, 1, 0);
        for who in [1, 2, 3] {
            assert!(matches!(
                table.lend(id, ExtOpId(2), task(who)),
                LendResult::MustWait
            ));
        }
        assert!(matches!(
            table.lend(other, ExtOpId(3), task(2)),
            LendResult::MustWait
        ));
        if cancelled {
            table.remove_waiter(task(2));
            // 関係のない待ちの順序は変えず、登録されていないタスクの除去も何もしない。
            table.remove_waiter(task(99));
            assert!(table.pop_waiter(other).is_none());
        } else {
            assert_eq!(table.pop_waiter(other), Some(task(2)));
        }
        for who in if cancelled { vec![1, 3] } else { vec![1, 2, 3] } {
            assert!(!table.give_back(id, handle));
            assert_eq!(table.pop_waiter(id), Some(task(who)));
            handle = lent(&mut table, id, u64::from(who) + 4, who);
        }
        assert!(!table.give_back(id, handle));
        assert!(!table.give_back(other, other_handle));
        assert!(table.pop_waiter(id).is_none());
        assert_eq!(table.pop_waiter(unrelated), Some(task(4)));
        assert_eq!(table.pop_waiter(unrelated), Some(task(5)));
        assert!(table.pop_waiter(unrelated).is_none());
        assert!(!table.give_back(unrelated, unrelated_handle));
        assert!(matches!(
            release(&mut table, id, 10),
            ReleaseStart::Done(Ok(()))
        ));
        assert_eq!(counts.lock().unwrap().released, 1);
    }
}

// 関門: 解放済み項目の保持量を表の持ち主で確かめる。従来の遷移テストは
// Released の判定だけを守り、要求数とともに Rust の表が増える退行を検出しない。
#[test]
fn completed_releases_do_not_accumulate_resource_entries() {
    let mut table = ResourceTable::default();
    for _ in 0..1024 {
        for kind in [
            ResourceKind::FileReader,
            ResourceKind::FileWriter,
            ResourceKind::HttpListener,
            ResourceKind::HttpExchange,
        ] {
            let (id, _) = insert(&mut table, kind, false);
            match release(&mut table, id, 1) {
                ReleaseStart::Done(Ok(())) => {}
                ReleaseStart::Blocking => {
                    let (_, _, handle) = table.take_release_job().unwrap();
                    table.finish_release(id, handle.release());
                }
                result @ (ReleaseStart::Done(_)
                | ReleaseStart::AfterReturn
                | ReleaseStart::InProgress
                | ReleaseStart::TaskGroup(_)
                | ReleaseStart::AlreadyReleased) => panic!("unexpected release: {result:?}"),
            }
            assert_eq!(table.state(id), Some(ResourceState::Released));
        }
        let group = table.insert(
            ResourceKind::TaskGroup,
            ResourceContent::TaskGroup(vec![]),
            None,
        );
        assert!(
            matches!(release(&mut table, group, 2), ReleaseStart::TaskGroup(children) if children.is_empty())
        );
        assert!(
            table.entries.is_empty(),
            "completed resources must leave the table"
        );
        assert!(table.attachments.is_empty());
        assert!(table.release_jobs.is_empty());
    }
    for _ in 0..1024 {
        let (id, _) = insert(&mut table, ResourceKind::FileWriter, true);
        assert!(matches!(release(&mut table, id, 3), ReleaseStart::Blocking));
        let (_, _, handle) = table.take_release_job().unwrap();
        table.finish_release(id, handle.release());
        assert_eq!(table.take_release_failure(id), Some("failed".into()));
        assert!(table.entries.is_empty());
    }
}

#[test]
fn task_group_returns_children_again_after_becoming_released() {
    let mut table = ResourceTable::default();
    let children = vec![task(1), task(2)];
    let id = table.insert(
        ResourceKind::TaskGroup,
        ResourceContent::TaskGroup(children.clone()),
        None,
    );
    assert!(table.check_lend(id).is_err());
    for op in [0, 1] {
        assert!(matches!(release(&mut table, id, op), ReleaseStart::TaskGroup(c) if c == children));
        assert_eq!(table.state(id), Some(ResourceState::Released));
    }
    assert!(matches!(
        table.lend(id, ExtOpId(2), task(0)),
        LendResult::Released(ResourceKind::TaskGroup)
    ));
    assert_eq!(table.finish_group_task(task(1)).unwrap(), Some(id));
    assert!(matches!(release(&mut table, id, 3), ReleaseStart::TaskGroup(c) if c == [task(2)]));
    assert_eq!(table.finish_group_task(task(2)).unwrap(), Some(id));
    assert!(table.entries.is_empty());
    assert!(table.group_tasks.is_empty());
    assert!(matches!(release(&mut table, id, 4), ReleaseStart::TaskGroup(c) if c.is_empty()));
}

// 関門: 終了時の破棄で書き出しを行わず、遅い返却も破棄し、番号を再使用しない契約。
#[test]
fn silent_close_and_late_return_drop_os_handles_without_language_release() {
    let mut table = ResourceTable::default();
    let (open, open_counts) = insert(&mut table, ResourceKind::FileWriter, true);
    let (lent_id, lent_counts) = insert(&mut table, ResourceKind::FileReader, false);
    let handle = lent(&mut table, lent_id, 1, 0);
    table.close_all_silently();
    table.close_all_silently();
    assert!(!table.give_back(lent_id, handle));
    for counts in [open_counts, lent_counts] {
        let counts = counts.lock().unwrap();
        assert_eq!((counts.released, counts.dropped), (0, 1));
    }
    let (new, _) = insert(&mut table, ResourceKind::FileReader, false);
    assert!(new > open && new > lent_id);
    assert_eq!(table.state(open), None);
}

// 関門: 不具合を待ちや言語の解放失敗に変えずに、事前の検査で返す（R24 の個別指示）。
#[test]
fn preflight_rejects_missing_or_inconsistent_resources_without_changing_them() {
    let mut table = ResourceTable::default();
    for result in [
        table.check_lend(ResourceId(99)),
        table.check_release(ResourceId(99)),
    ] {
        assert!(matches!(result, Err(Stop::Internal(_))));
    }
    let id = table.insert(ResourceKind::FileReader, ResourceContent::Os(None), None);
    for result in [table.check_lend(id), table.check_release(id)] {
        assert!(matches!(result, Err(Stop::Internal(_))));
    }
    assert_eq!(table.state(id), Some(ResourceState::Open));
    let id = table.insert(ResourceKind::TaskGroup, ResourceContent::Os(None), None);
    assert!(matches!(table.check_release(id), Err(Stop::Internal(_))));
    let id = table.insert(
        ResourceKind::FileReader,
        ResourceContent::TaskGroup(vec![]),
        None,
    );
    assert!(matches!(table.check_release(id), Err(Stop::Internal(_))));
}

#[test]
fn deferred_release_jobs_keep_start_order_and_failure_after_immediate_return() {
    let mut table = ResourceTable::default();
    let mut ids = vec![];
    for op in [2, 1, 3] {
        let (id, _) = insert(&mut table, ResourceKind::FileWriter, false);
        assert!(matches!(
            release(&mut table, id, op),
            ReleaseStart::Blocking
        ));
        ids.push((id, ExtOpId(op)));
    }
    for expected in ids {
        let (id, op, handle) = table.take_release_job().unwrap();
        assert_eq!((id, op), expected);
        table.finish_release(id, handle.release());
    }
    assert!(table.take_release_job().is_none());
    let (id, _) = insert(&mut table, ResourceKind::FileReader, true);
    let handle = lent(&mut table, id, 10, 0);
    assert!(matches!(
        release(&mut table, id, 11),
        ReleaseStart::AfterReturn
    ));
    assert!(table.give_back(id, handle));
    let ReleaseStart::Done(result) = release(&mut table, id, 12) else {
        panic!("expected Done")
    };
    table.finish_release(id, result);
    assert_eq!(table.take_release_failure(id), Some("failed".into()));
    assert!(table.take_release_failure(id).is_none());
}

// 関門: Released の全経路で要求の添え物を除く（L30、設計書 03-09「サーバ」）。
// OS 資源の Drop だけでは別の表に残った要求を検出できない。
#[test]
fn released_resources_remove_attachments_on_every_path() {
    for fail in [false, true] {
        let mut table = ResourceTable::default();
        let (listener, _) = insert(&mut table, ResourceKind::HttpListener, fail);
        table
            .attachments
            .insert(listener, Box::new("request".to_owned()));
        assert!(matches!(
            release(&mut table, listener, 1),
            ReleaseStart::Done(_)
        ));
        assert!(!table.attachments.contains_key(&listener));
        let (exchange, _) = insert(&mut table, ResourceKind::HttpExchange, fail);
        table
            .attachments
            .insert(exchange, Box::new("request".to_owned()));
        assert!(matches!(
            release(&mut table, exchange, 2),
            ReleaseStart::Blocking
        ));
        assert!(table.attachments.contains_key(&exchange));
        let (id, _, handle) = table.take_release_job().unwrap();
        table.finish_release(id, handle.release());
        assert!(!table.attachments.contains_key(&exchange));
        let group = table.insert(
            ResourceKind::TaskGroup,
            ResourceContent::TaskGroup(vec![]),
            None,
        );
        table.attachments.insert(group, Box::new("test"));
        assert!(matches!(
            release(&mut table, group, 3),
            ReleaseStart::TaskGroup(_)
        ));
        assert!(!table.attachments.contains_key(&group));
        let (open, _) = insert(&mut table, ResourceKind::HttpExchange, fail);
        table.attachments.insert(open, Box::new("request"));
        table.close_all_silently();
        assert!(table.attachments.is_empty());
    }
}
