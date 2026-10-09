//! 処理系のテスト専用の筋書きと仮想の時間（設計書 07-03「順序を与えるスケジューラと仮想の時間」、ADR 0274）。
//! CLI と利用者のテストからは選べない。R26 の仕事を実行する部品も同じ筋書きを共有する。

use std::cell::RefCell;
use std::collections::{BTreeMap, VecDeque};
use std::rc::Rc;

use super::ExtOpId;
use super::parts::{Clock, TaskPicker};
use crate::vm::TaskId;

/// 筋書きの一歩。起動の通し番号はメインを 0 とする。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScheduleStep {
    PickIndex(usize),
    PickTask(u64),
    Advance(u64),
    RunWorker(ExtOpId),
}

/// 実際に行った選択と指示。既定の選択も記録し、偶然の成功と区別する。
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScheduleEvent {
    Spawned {
        serial: u64,
        task: TaskId,
        millis: u64,
    },
    Picked {
        task: TaskId,
        scripted: bool,
    },
    Advanced(u64),
    WorkerRan(ExtOpId),
}

/// 筋書きの消費数と記録と、最初の誤り。
#[derive(Clone, Debug, Default)]
pub struct ScheduleRecord {
    pub consumed: usize,
    pub events: Vec<ScheduleEvent>,
    pub error: Option<String>,
    pub remaining: usize,
}

#[derive(Debug)]
struct Script {
    wakeup: crate::runtime::io::event::Wakeup,
    output_wakes: bool,
    steps: VecDeque<ScheduleStep>,
    tasks: BTreeMap<u64, TaskId>,
    millis: u64,
    epoch_millis: i64,
    offset_minutes: i32,
    strict: bool,
    record: ScheduleRecord,
}

/// 三つの部品が共有する筋書きへの口（VM と同じスレッドだけで使う）。
#[derive(Clone, Debug)]
pub struct ScheduleHandle(Rc<RefCell<Script>>);

impl ScheduleHandle {
    /// 筋書きを作る。`strict` が真なら、筋書きが尽きた後の既定の選択も誤りにする。
    pub fn new(steps: impl IntoIterator<Item = ScheduleStep>, strict: bool) -> Self {
        Self(Rc::new(RefCell::new(Script {
            wakeup: crate::runtime::io::event::wakeup_without_poll(),
            output_wakes: false,
            steps: steps.into_iter().collect(),
            tasks: BTreeMap::new(),
            millis: 0,
            epoch_millis: 0,
            offset_minutes: 0,
            strict,
            record: ScheduleRecord::default(),
        })))
    }

    /// 出力ポートと筋書きの仕事の部品が共有する起こし口（実装プラン R27）。
    pub fn wakeup(&self) -> crate::runtime::io::event::Wakeup {
        let mut script = self.0.borrow_mut();
        if !script.output_wakes {
            script.wakeup = crate::runtime::io::event::wakeup_counted();
            script.output_wakes = true;
        }
        script.wakeup.clone()
    }

    /// 仮想の UTC の起点と地方時の差を設定する。単調な時計は 0 から始まる。
    pub fn with_clock(self, epoch_millis: i64, offset_minutes: i32) -> Self {
        {
            let mut script = self.0.borrow_mut();
            script.epoch_millis = epoch_millis;
            script.offset_minutes = offset_minutes;
        }
        self
    }

    /// 次に進めるタスクを選ぶ部品。
    pub fn picker(&self) -> Box<dyn TaskPicker> {
        Box::new(ScriptPicker(self.clone()))
    }
    /// 仮想の時計。
    pub fn clock(&self) -> Box<dyn Clock> {
        Box::new(VirtualClock(self.clone()))
    }
    /// 消費した指示、実際の順序、残る指示と誤りを読む。
    pub fn record(&self) -> ScheduleRecord {
        let script = self.0.borrow();
        let mut record = script.record.clone();
        record.remaining = script.steps.len();
        record
    }
    /// VM が起動した通し番号と世代付きの番号を登録する。
    pub fn register_spawn(&self, serial: u64, task: TaskId) {
        let mut script = self.0.borrow_mut();
        if script.tasks.insert(serial, task).is_some() {
            set_error(&mut script, "duplicate spawn serial");
            return;
        }
        let millis = script.millis;
        script.record.events.push(ScheduleEvent::Spawned {
            serial,
            task,
            millis,
        });
    }
    /// 既存の解放テストが完了を許可した位置に仕事の指示を置く。
    #[cfg(test)]
    pub(crate) fn allow_worker(&self, op: ExtOpId) {
        self.0
            .borrow_mut()
            .steps
            .push_front(ScheduleStep::RunWorker(op));
    }
    /// 要求を外側で処理した後に、仮想の時間の指示を追加する。
    #[cfg(test)]
    pub(crate) fn allow_time(&self, millis: u64) {
        self.0
            .borrow_mut()
            .steps
            .push_back(ScheduleStep::Advance(millis));
    }
    /// 次の指示を読む。R26 の仕事を実行する部品が使う。
    pub fn next_step(&self) -> Option<ScheduleStep> {
        self.0.borrow().steps.front().copied()
    }
    /// 時間を進める指示を、次の選択か仕事の指示までまとめて行う。
    pub fn advance_time(&self) -> Result<bool, String> {
        let mut script = self.0.borrow_mut();
        let mut progressed = false;
        while let Some(ScheduleStep::Advance(amount)) = script.steps.front().copied() {
            let Some(now) = script.millis.checked_add(amount) else {
                set_error(&mut script, "virtual clock overflow");
                break;
            };
            script.millis = now;
            script.steps.pop_front();
            script.record.consumed = script.record.consumed.saturating_add(1);
            script.record.events.push(ScheduleEvent::Advanced(amount));
            progressed = true;
        }
        if let Some(error) = &script.record.error {
            Err(error.clone())
        } else {
            Ok(progressed)
        }
    }
    /// 仕事を実行した部品が、指示を消費したことを記録する（R26）。
    pub fn worker_ran(&self, op: ExtOpId) {
        let mut script = self.0.borrow_mut();
        if script.steps.front() != Some(&ScheduleStep::RunWorker(op)) {
            set_error(&mut script, "worker does not match script");
            return;
        }
        script.steps.pop_front();
        script.record.consumed = script.record.consumed.saturating_add(1);
        script.record.events.push(ScheduleEvent::WorkerRan(op));
    }
    /// 行えない指示を最初の誤りとして残す。指示は消費しない。
    pub fn fail(&self, message: &str) {
        set_error(&mut self.0.borrow_mut(), message);
    }
}

fn set_error(script: &mut Script, message: &str) {
    if script.record.error.is_none() {
        script.record.error = Some(message.to_owned());
    }
}

#[derive(Debug)]
struct ScriptPicker(ScheduleHandle);
impl TaskPicker for ScriptPicker {
    fn spawned(&mut self, serial: u64, task: TaskId) {
        self.0.register_spawn(serial, task);
    }
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize> {
        if ready.is_empty() {
            return None;
        }
        let mut script = self.0.0.borrow_mut();
        if script.record.error.is_some() {
            return None;
        }
        let step = script.steps.front().copied();
        let position = match step {
            Some(ScheduleStep::PickIndex(position)) => Some(position),
            Some(ScheduleStep::PickTask(serial)) => script
                .tasks
                .get(&serial)
                .and_then(|id| ready.iter().position(|task| task == id)),
            Some(ScheduleStep::Advance(_) | ScheduleStep::RunWorker(_)) => None,
            None if script.strict => None,
            None => Some(0),
        };
        let Some(position) = position else {
            set_error(&mut script, "script cannot pick a ready task");
            return None;
        };
        let Some(&task) = ready.get(position) else {
            set_error(&mut script, "script picked outside ready queue");
            return None;
        };
        let scripted = step.is_some();
        if scripted {
            script.steps.pop_front();
            script.record.consumed = script.record.consumed.saturating_add(1);
        }
        script
            .record
            .events
            .push(ScheduleEvent::Picked { task, scripted });
        Some(position)
    }
}

/// 筋書きが進めた時間だけを返す時計。
#[derive(Debug)]
pub struct VirtualClock(ScheduleHandle);
impl Clock for VirtualClock {
    fn now_millis(&self) -> i64 {
        let script = self.0.0.borrow();
        script
            .epoch_millis
            .saturating_add(i64::try_from(script.millis).unwrap_or(i64::MAX))
    }
    fn local_offset_minutes(&self) -> i32 {
        self.0.0.borrow().offset_minutes
    }
    fn monotonic_millis(&self) -> u64 {
        self.0.0.borrow().millis
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    // 関門: 三つの部品は同じ指示列を消費し、誤った選択で指示も待ち行列も進めない（ADR 0274）。
    #[test]
    fn virtual_clock_picker_and_worker_share_the_script_and_record() {
        let task = TaskId {
            index: 7,
            generation: 3,
        };
        let script = ScheduleHandle::new(
            [
                ScheduleStep::Advance(9),
                ScheduleStep::RunWorker(ExtOpId(2)),
                ScheduleStep::Advance(1),
                ScheduleStep::PickTask(1),
            ],
            false,
        )
        .with_clock(1000, 540);
        let clock = script.clock();
        let mut picker = script.picker();
        script.register_spawn(1, task);
        assert!(script.advance_time().is_ok());
        assert_eq!(clock.monotonic_millis(), 9);
        assert_eq!(clock.now_millis(), 1009);
        assert_eq!(clock.local_offset_minutes(), 540);
        assert_eq!(
            script.next_step(),
            Some(ScheduleStep::RunWorker(ExtOpId(2)))
        );
        script.worker_ran(ExtOpId(2));
        assert!(script.advance_time().is_ok());
        assert_eq!(clock.monotonic_millis(), 10);
        assert_eq!(picker.pick(&VecDeque::from([task])), Some(0));
        assert_eq!(picker.pick(&VecDeque::from([task])), Some(0));
        let r = script.record();
        assert_eq!(r.consumed, 4);
        assert_eq!(r.remaining, 0);
        assert!(r.error.is_none());
        assert_eq!(
            r.events,
            [
                ScheduleEvent::Spawned {
                    serial: 1,
                    task,
                    millis: 0
                },
                ScheduleEvent::Advanced(9),
                ScheduleEvent::WorkerRan(ExtOpId(2)),
                ScheduleEvent::Advanced(1),
                ScheduleEvent::Picked {
                    task,
                    scripted: true
                },
                ScheduleEvent::Picked {
                    task,
                    scripted: false
                }
            ]
        );
    }
    #[test]
    fn unknown_serial_out_of_range_unperformed_work_and_strict_exhaustion_are_errors() {
        let task = TaskId {
            index: 0,
            generation: 0,
        };
        for steps in [
            vec![ScheduleStep::PickTask(99)],
            vec![ScheduleStep::PickIndex(1)],
            vec![ScheduleStep::RunWorker(ExtOpId(0))],
            vec![],
        ] {
            let count = steps.len();
            let script = ScheduleHandle::new(steps, true);
            let mut picker = script.picker();
            assert_eq!(picker.pick(&VecDeque::from([task])), None);
            let record = script.record();
            assert!(record.error.is_some());
            assert_eq!(record.consumed, 0);
            assert_eq!(record.remaining, count);
        }
    }
}

impl ScheduleHandle {
    /// 三つの部品を同じ筋書きで動かす（ADR 0274）。
    pub fn parts(&self) -> super::parts::RuntimeParts {
        super::parts::RuntimeParts {
            network_faults: super::parts::NetworkFaults::default(),
            picker: self.picker(),
            clock: self.clock(),
            workers: Box::new(ScriptWorkers {
                script: self.clone(),
                seen_wakes: 0,
                jobs: BTreeMap::new(),
                done: VecDeque::new(),
            }),
        }
    }
}
#[derive(Debug)]
struct ScriptWorkers {
    script: ScheduleHandle,
    seen_wakes: u64,
    jobs: BTreeMap<ExtOpId, crate::runtime::io::ops::WorkerJob>,
    done: VecDeque<crate::runtime::io::ops::Completion>,
}
impl ScriptWorkers {
    fn advance(&mut self) -> bool {
        let mut progressed = false;
        loop {
            match self.script.next_step() {
                Some(ScheduleStep::Advance(_)) => match self.script.advance_time() {
                    Ok(value) => progressed |= value,
                    // WorkerExec の凍結した口ではこの誤りを返せないため、進行だけを止める。
                    // 誤りは筋書きに残り、テストが record().error で確かめる（R26 の確認後の指示）。
                    Err(_) => return progressed,
                },
                Some(ScheduleStep::RunWorker(op)) => {
                    let Some(job) = self.jobs.remove(&op) else {
                        self.script.fail("script requested unknown worker job");
                        return progressed;
                    };
                    self.done
                        .push_back(crate::runtime::io::ops::execute_job(job));
                    self.script.worker_ran(op);
                    progressed = true;
                }
                _ => return progressed,
            }
        }
    }
}
impl super::parts::WorkerExec for ScriptWorkers {
    fn wakeup(&self) -> Option<crate::runtime::io::event::Wakeup> {
        Some(self.script.wakeup())
    }

    fn submit(&mut self, job: crate::runtime::io::ops::WorkerJob) {
        self.jobs.insert(job.op, job);
    }
    fn try_recv(&mut self) -> Option<crate::runtime::io::ops::Completion> {
        self.advance();
        self.done.pop_front()
    }
    fn idle(&mut self, _deadline: Option<u64>) -> super::parts::IdleWake {
        if !self.done.is_empty() || self.advance() {
            super::parts::IdleWake::Progress
        } else {
            let wakeup = self.script.0.borrow().wakeup.clone();
            if let Some(count) = crate::runtime::io::event::wait_counted(&wakeup, self.seen_wakes) {
                self.seen_wakes = count;
                return super::parts::IdleWake::Progress;
            }
            self.script
                .fail("scheduler script exhausted or cannot advance while waiting");
            super::parts::IdleWake::ScriptExhausted
        }
    }
}
