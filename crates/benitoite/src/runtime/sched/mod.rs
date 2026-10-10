//! スケジューラ（設計書 02-08「タスクの切り替え」、02-09「タスクの待ちと取り消し」）。

pub mod parts;
pub mod testing;

use std::collections::{BTreeMap, BTreeSet, VecDeque};

use crate::vm::TaskId;
use crate::vm::task::WaitReason;

/// 外部の操作の番号（作業用のスレッドの仕事、イベントループの準備、ブロックする解放）。
/// エフェクトの操作の番号 `bytecode::program::OpIdx` とは別のもの。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ExtOpId(pub u64);

/// タイマーの番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct TimerId(pub u64);

/// 待つタスクの表の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Waiting {
    pub reason: WaitReason,
}

#[cfg(test)]
mod tests {
    // 関門: 二つの種類の番号はそれぞれ進み、相互に計数を変えない（実装プラン R24）。
    // テストの失敗は panic で表す（実装プラン 00-02）。
    use super::{ExtOpId, Scheduler, TimerId};

    #[test]
    fn external_operation_and_timer_numbers_are_independent() {
        let mut scheduler = Scheduler::default();
        assert_eq!(scheduler.new_ext_op_id(), ExtOpId(0));
        assert_eq!(scheduler.new_timer_id(), TimerId(0));
        assert_eq!(scheduler.new_timer_id(), TimerId(1));
        assert_eq!(scheduler.new_ext_op_id(), ExtOpId(1));
        assert_eq!(scheduler.new_ext_op_id(), ExtOpId(2));
        assert_eq!(scheduler.new_timer_id(), TimerId(2));
    }
}

/// スケジューラの状態。
#[derive(Debug, Default)]
pub struct Scheduler {
    /// 進められるタスクの待ち行列
    pub ready: VecDeque<TaskId>,
    /// 待つタスクの表
    pub waiting: BTreeMap<TaskId, Waiting>,
    /// タイマー（期限の単調な時計のミリ秒、番号 → 待つタスク）
    pub timers: BTreeMap<(u64, TimerId), TaskId>,
    next_ext_op: u64,
    next_timer: u64,
    resource_waiters: BTreeMap<(bool, crate::runtime::heap::ResourceId), BTreeSet<TaskId>>,
    task_timers: BTreeMap<TaskId, BTreeSet<(u64, TimerId)>>,
    timer_keys: BTreeMap<TimerId, (u64, TaskId)>,
    external_waiters: usize,
}

use self::parts::TaskPicker;

impl Scheduler {
    pub fn new_ext_op_id(&mut self) -> ExtOpId {
        let id = ExtOpId(self.next_ext_op);
        // 1 ns に一つでも 2^64 個には 500 年以上かかる。一実行で使い切らない前提で
        // 番号を進める（実装プラン R24「凍結した戻り値で処理系の不具合を扱う方法」）。
        self.next_ext_op = self.next_ext_op.wrapping_add(1);
        id
    }
    pub fn new_timer_id(&mut self) -> TimerId {
        let id = TimerId(self.next_timer);
        // 外部の操作の番号と同じく、一実行で 2^64 個を使い切らない（実装プラン R24）。
        self.next_timer = self.next_timer.wrapping_add(1);
        id
    }
    /// 実行中のタスクを待たせる。要求を送り出しの列に公開する前に呼ぶ（02-09「IO 実行器」）。
    pub fn park(&mut self, task: TaskId, reason: WaitReason) {
        if self.check_park(task).is_err() {
            // VM は check_park を先に通す（実装プラン R25）。
            debug_assert!(false, "invalid scheduler park");
            return;
        }
        self.index_wait(task, reason);
        self.waiting.insert(task, Waiting { reason });
    }
    /// 待つタスクを進められるタスクに戻す（待ち行列の末尾）。待っていなければ何もしない。
    /// 待ちの理由を問わないので、待ちを外す取り消しと止める手順で使う。
    pub fn wake(&mut self, task: TaskId) {
        if self.remove_waiting(task).is_some() {
            self.ready.push_back(task);
        }
    }
    /// `task` が `reason` で待っていれば進められるタスクに戻し、`true` を返す。ほかの理由で待つか、
    /// 待っていなければ何もしない。知らせ（完了、返却、解放の完了、タスクの終わり）で起こすときに使い、
    /// 古い知らせで別の待ちのタスクを起こさない。
    pub fn wake_if(&mut self, task: TaskId, reason: WaitReason) -> bool {
        if self.waiting.get(&task).is_some_and(|w| w.reason == reason) {
            self.wake(task);
            true
        } else {
            false
        }
    }
    /// `reason` で待つタスクをすべて、番号の順に進められるタスクに戻し、戻したタスクを返す。
    pub fn wake_all(&mut self, reason: WaitReason) -> Vec<TaskId> {
        let tasks: Vec<_> = if let Some(key) = resource_wait_key(reason) {
            self.resource_waiters
                .get(&key)
                .map(|tasks| tasks.iter().copied().collect())
                .unwrap_or_default()
        } else {
            self.waiting
                .iter()
                .filter_map(|(&task, w)| (w.reason == reason).then_some(task))
                .collect()
        };
        for &task in &tasks {
            self.wake_if(task, reason);
        }
        tasks
    }
    /// 待ち行列から次のタスクを除いて返す。選び方は `picker` が決める。
    pub fn next(&mut self, picker: &mut dyn TaskPicker) -> Option<TaskId> {
        let position = picker.pick(&self.ready)?;
        self.ready.remove(position)
    }
    /// 外部の完了の待ち（`WaitReason::is_external`）か、タイマーがあるか。
    pub fn has_external_waits(&self) -> bool {
        !self.timers.is_empty() || self.external_waiters != 0
    }
    /// 行き詰まりか: 待ち行列が空で、外部の待ち（`WaitReason::is_external`）で待つタスクもタイマーもなく、
    /// 待つタスクがあるとき（02-08「タスクの切り替え」、02-09「IO 実行器」）。どのタスクも待って
    /// いない外部の操作の記録と出力の転送は数えないので、ほかの状態は調べない（本章「完了の処理と行き詰まりの
    /// 判定の順序」の手順 5）。止める手順の途中では、呼び出し側が停止の理由を置き換えない。
    pub fn is_deadlocked(&self) -> bool {
        self.ready.is_empty() && !self.waiting.is_empty() && !self.has_external_waits()
    }
    /// 期限の来たタイマーを除き、その待つタスクを返す。
    pub fn expire_timers(&mut self, now_monotonic_millis: u64) -> Vec<(TimerId, TaskId)> {
        let mut expired = Vec::new();
        while let Some((&(deadline, timer), &task)) = self.timers.first_key_value() {
            if deadline > now_monotonic_millis {
                break;
            }
            self.timers.pop_first();
            self.remove_timer(timer);
            expired.push((timer, task));
        }
        expired
    }
    /// 最も早いタイマーの期限。
    pub fn next_deadline(&self) -> Option<u64> {
        self.timers
            .first_key_value()
            .map(|(&(deadline, _), _)| deadline)
    }
}

impl Scheduler {
    // 凍結した park の戻り値では不具合を返せないので、VM が先に照合する（実装プラン R25）。
    pub(crate) fn check_park(&self, task: TaskId) -> Result<(), crate::runtime::Stop> {
        if self.waiting.contains_key(&task) || self.ready.contains(&task) {
            Err(crate::vm::state::internal("task already queued or waiting"))
        } else {
            Ok(())
        }
    }
}

#[cfg(test)]
mod contract_tests {
    // 関門: 古い知らせで別の待ちを解かず、二重の待ちを拒む。単一タスクの実行では
    // 誤った起こしでも次に進めるため、スケジューラ自身の境界で照合する（実装プラン R25）。
    use super::*;
    use crate::vm::task::TaskEndWait;
    fn task(index: u32) -> TaskId {
        TaskId {
            index,
            generation: 0,
        }
    }
    #[test]
    fn notifications_match_wait_reason_and_parking_rejects_duplicates() {
        let mut s = Scheduler::default();
        s.park(task(1), WaitReason::Lazy);
        assert!(s.check_park(task(1)).is_err());
        assert!(!s.wake_if(task(1), WaitReason::TaskEnd(TaskEndWait::Spawned)));
        assert!(!s.wake_if(task(2), WaitReason::Lazy));
        assert!(s.wake_if(task(1), WaitReason::Lazy));
        assert!(s.check_park(task(1)).is_err());
        assert!(!s.wake_if(task(1), WaitReason::Lazy));
        assert_eq!(s.next(&mut parts::FifoPicker), Some(task(1)));
        s.park(
            task(1),
            WaitReason::Release(crate::runtime::heap::ResourceId(0)),
        );
        assert!(!s.wake_if(task(1), WaitReason::Lazy));
        assert!(s.ready.is_empty());
    }
    #[test]
    fn only_internal_waits_deadlock_and_timers_expire_in_deadline_order() {
        let mut s = Scheduler::default();
        s.park(task(1), WaitReason::Lazy);
        assert!(s.is_deadlocked());
        let timer = s.new_timer_id();
        s.park(task(2), WaitReason::Timer(timer));
        s.add_timer(10, timer, task(2));
        assert!(!s.is_deadlocked());
        assert_eq!(s.next_deadline(), Some(10));
        assert!(s.expire_timers(9).is_empty());
        assert_eq!(s.expire_timers(10), [(timer, task(2))]);
        assert!(s.wake_if(task(2), WaitReason::Timer(timer)));
        assert_eq!(s.next(&mut parts::FifoPicker), Some(task(2)));
        for reason in [
            WaitReason::Worker(ExtOpId(0)),
            WaitReason::Readiness(ExtOpId(0)),
            WaitReason::Lend(crate::runtime::heap::ResourceId(0)),
            WaitReason::Release(crate::runtime::heap::ResourceId(0)),
            WaitReason::Response,
        ] {
            s.park(task(2), reason);
            assert!(!s.is_deadlocked());
            s.wake_if(task(2), reason);
            s.next(&mut parts::FifoPicker);
        }
    }
    #[derive(Debug)]
    struct InvalidPicker;
    impl parts::TaskPicker for InvalidPicker {
        fn pick(&mut self, _: &VecDeque<TaskId>) -> Option<usize> {
            Some(99)
        }
    }
    #[test]
    fn invalid_picker_keeps_the_ready_queue() {
        let mut s = Scheduler::default();
        s.ready.extend([task(1), task(2)]);
        assert!(s.next(&mut InvalidPicker).is_none());
        assert_eq!(s.ready, VecDeque::from([task(1), task(2)]));
    }
}

impl Scheduler {
    /// 二重に park せず、要求の処理で決まった理由へ待ちを移す（実装プラン R26）。
    pub(crate) fn repark(
        &mut self,
        task: TaskId,
        from: WaitReason,
        to: WaitReason,
    ) -> Result<(), crate::runtime::Stop> {
        let wait = self
            .waiting
            .get_mut(&task)
            .filter(|w| w.reason == from)
            .ok_or_else(|| crate::vm::state::internal("task is not waiting for expected reason"))?;
        wait.reason = to;
        self.unindex_wait(task, from);
        self.index_wait(task, to);
        Ok(())
    }
    /// タイマーの期限と待つタスクを登録する。
    pub(crate) fn add_timer(&mut self, deadline: u64, timer: TimerId, task: TaskId) {
        self.timers.insert((deadline, timer), task);
        self.timer_keys.insert(timer, (deadline, task));
        self.task_timers
            .entry(task)
            .or_default()
            .insert((deadline, timer));
    }

    pub(crate) fn remove_timer(&mut self, timer: TimerId) {
        if let Some((deadline, task)) = self.timer_keys.remove(&timer) {
            self.timers.remove(&(deadline, timer));
            if let Some(timers) = self.task_timers.get_mut(&task) {
                timers.remove(&(deadline, timer));
                if timers.is_empty() {
                    self.task_timers.remove(&task);
                }
            }
        }
    }
    pub(crate) fn remove_task_timers(&mut self, task: TaskId) {
        if let Some(timers) = self.task_timers.remove(&task) {
            for (deadline, timer) in timers {
                self.timer_keys.remove(&timer);
                self.timers.remove(&(deadline, timer));
            }
        }
    }
    pub(crate) fn clear_timers(&mut self) {
        self.timers.clear();
        self.task_timers.clear();
        self.timer_keys.clear();
    }
    pub(crate) fn remove_waiting(&mut self, task: TaskId) -> Option<Waiting> {
        let waiting = self.waiting.remove(&task)?;
        self.unindex_wait(task, waiting.reason);
        Some(waiting)
    }
    pub(crate) fn clear_waiting(&mut self) {
        self.waiting.clear();
        self.resource_waiters.clear();
        self.external_waiters = 0;
    }
    fn index_wait(&mut self, task: TaskId, reason: WaitReason) {
        if let Some(key) = resource_wait_key(reason) {
            self.resource_waiters.entry(key).or_default().insert(task);
        }
        if reason.is_external() {
            self.external_waiters = self.external_waiters.saturating_add(1);
        }
    }
    fn unindex_wait(&mut self, task: TaskId, reason: WaitReason) {
        if let Some(key) = resource_wait_key(reason)
            && let Some(tasks) = self.resource_waiters.get_mut(&key)
        {
            tasks.remove(&task);
            if tasks.is_empty() {
                self.resource_waiters.remove(&key);
            }
        }
        if reason.is_external() {
            self.external_waiters = self.external_waiters.saturating_sub(1);
        }
    }
}

fn resource_wait_key(reason: WaitReason) -> Option<(bool, crate::runtime::heap::ResourceId)> {
    match reason {
        WaitReason::Release(id) => Some((false, id)),
        WaitReason::TaskEnd(crate::vm::task::TaskEndWait::TaskGroupRelease(id)) => Some((true, id)),
        WaitReason::Worker(_)
        | WaitReason::Timer(_)
        | WaitReason::Readiness(_)
        | WaitReason::Output(..)
        | WaitReason::Lend(_)
        | WaitReason::TaskEnd(_)
        | WaitReason::Lazy
        | WaitReason::Response => None,
    }
}
