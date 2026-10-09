//! テストで差し替える部品（ADR 0274）: 次に進めるタスクを選ぶ部品、時計、作業用のスレッドの仕事の実行。

use std::collections::VecDeque;
use std::fmt::Debug;

use crate::runtime::io::ops::{Completion, WorkerJob};
use crate::vm::TaskId;

/// 次に進めるタスクを選ぶ部品。
pub trait TaskPicker: Debug {
    /// 待ち行列の中から次に進めるタスクの位置を返す。空なら `None`。
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize>;
    /// タスクを起動したことを知らせる（`serial` は起動の通し番号。メインのタスクは 0）。
    /// テスト用の実装が、筋書きの起動の通し番号で選ぶ指示を引くために使う。既定は何もしない。
    fn spawned(&mut self, _serial: u64, _task: TaskId) {}
}

/// 実際の実装: 待ち行列の先頭を選ぶ。
#[derive(Clone, Copy, Debug, Default)]
pub struct FifoPicker;

impl TaskPicker for FifoPicker {
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize> {
        if ready.is_empty() { None } else { Some(0) }
    }
}

/// 時計（`Clock.now` などとタイマーの期限）。
pub trait Clock: Debug {
    /// UTC の 1970-01-01 からのミリ秒
    fn now_millis(&self) -> i64;
    fn local_offset_minutes(&self) -> i32;
    /// 実行を始めてからの単調な時計のミリ秒
    fn monotonic_millis(&self) -> u64;
}

/// `WorkerExec::idle` の結果。
#[derive(Debug)]
pub enum IdleWake {
    /// 完了、タイマー、イベントループの準備、出力の知らせのどれかが届いたか、時間が進んだ
    Progress,
    /// 中断の要求でイベントループが起こされた
    Interrupted,
    /// テスト用の実装で、筋書きが尽きた（テストの誤り。VM は `Stop::Internal` にする）
    ScriptExhausted,
}

/// 作業用のスレッドの仕事の実行と、完了とイベントの待ち。
pub trait WorkerExec: Debug {
    /// 仕事を出す。完了は後で `try_recv` が返す。
    fn submit(&mut self, job: WorkerJob);
    /// 届いた完了を一つ返す。待たない。
    fn try_recv(&mut self) -> Option<Completion>;
    /// 進められるタスクがないときに待つ。`deadline` は次のタイマーの期限（単調な時計のミリ秒）。
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake;
    /// この部品が使ってほしい起こし口。`run_program` は、`RunEnv::parts` で部品を受け取ったとき、
    /// これが `Some` ならその `Wakeup` を出力と IO 実行器に渡し、`None` なら `mio` を使わない形を作る。
    /// テスト用の部品が、書き出し用のスレッドの知らせを待てる形を渡すために使う。
    /// R27 が加えた既定の本体付きの関数。本物の部品と既存の部品は既定のまま。
    fn wakeup(&self) -> Option<Wakeup> {
        None
    }
}

/// 差し替える部品の組。実行ごとに一つ持つ。
#[derive(Debug)]
pub struct RuntimeParts {
    pub picker: Box<dyn TaskPicker>,
    pub clock: Box<dyn Clock>,
    pub workers: Box<dyn WorkerExec>,
    /// テスト用のハンドラ表のネットワークの失敗（実装プラン 10-16）。実際の実装の組（`RuntimeParts::real`）は空である
    pub network_faults: NetworkFaults,
}

use crate::runtime::io::event::Wakeup;

impl RuntimeParts {
    /// イベントループを持つ実際の部品を作る（実装プラン 10-16）。
    pub fn real_with_poll(network_faults: NetworkFaults) -> std::io::Result<RuntimeParts> {
        let mut parts = Self::real(crate::runtime::io::event::wakeup_with_poll()?);
        parts.network_faults = network_faults;
        Ok(parts)
    }
    /// 実際の実装の組。`wakeup` は作業用のスレッドが完了を知らせるときにイベントループを起こす口。
    pub fn real(wakeup: Wakeup) -> RuntimeParts {
        let started = std::time::Instant::now();
        RuntimeParts {
            picker: Box::new(FifoPicker),
            clock: Box::new(RealClock { started }),
            workers: Box::new(ThreadWorkers::new(started, wakeup)),
            network_faults: NetworkFaults::default(),
        }
    }
}

/// OS の UTC 時計と、実行の開始からの単調な時計（設計書 02-09「実行ごとの状態」）。
#[derive(Debug)]
pub struct RealClock {
    started: std::time::Instant,
}
impl RealClock {
    /// 実行の開始時点を記録する。
    pub fn new() -> Self {
        Self {
            started: std::time::Instant::now(),
        }
    }
}
impl Default for RealClock {
    fn default() -> Self {
        Self::new()
    }
}
impl Clock for RealClock {
    fn now_millis(&self) -> i64 {
        match std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH) {
            Ok(d) => i64::try_from(d.as_millis()).unwrap_or(i64::MAX),
            Err(e) => i64::try_from(e.duration().as_millis())
                .unwrap_or(i64::MAX)
                .saturating_neg(),
        }
    }
    fn local_offset_minutes(&self) -> i32 {
        // OS のデータだけを使い、取得できなければ UTC として扱う（ADR 0287 の決定 1）。
        jiff::tz::TimeZone::try_system()
            .ok()
            .and_then(|zone| {
                zone.to_offset(jiff::Timestamp::now())
                    .seconds()
                    .checked_div(60)
            })
            .unwrap_or(0)
    }
    fn monotonic_millis(&self) -> u64 {
        u64::try_from(self.started.elapsed().as_millis()).unwrap_or(u64::MAX)
    }
}

// 仕事は列から所有権ごと取り出し、ロックの外で実行する。言語の値を持たない
// WorkerJob と Completion だけをスレッドへ渡す（設計書 02-09「IO 実行器」）。
use std::sync::{Arc, Condvar, Mutex, mpsc};
use std::time::{Duration, Instant};

use crate::runtime::io::event::EventLoop;
use crate::runtime::io::ops::{Outcome, execute_job};
use crate::runtime::panic::PanicReport;

const MAX_WORKERS: usize = 64;

#[derive(Debug, Default)]
struct WorkQueue {
    jobs: VecDeque<WorkerJob>,
    threads: usize,
    busy: usize,
    closed: bool,
}

#[derive(Debug, Default)]
struct SharedWork {
    queue: Mutex<WorkQueue>,
    available: Condvar,
}

#[derive(Debug)]
struct ThreadWorkers {
    started: Instant,
    wakeup: Wakeup,
    events: Option<EventLoop>,
    shared: Arc<SharedWork>,
    sender: mpsc::Sender<Completion>,
    receiver: mpsc::Receiver<Completion>,
    pending: Option<Completion>,
}

impl ThreadWorkers {
    fn new(started: Instant, wakeup: Wakeup) -> Self {
        let events = EventLoop::take(&wakeup);
        let (sender, receiver) = mpsc::channel();
        Self {
            started,
            wakeup,
            events,
            shared: Arc::new(SharedWork::default()),
            sender,
            receiver,
            pending: None,
        }
    }

    fn timeout(&self, deadline: Option<u64>) -> Option<Duration> {
        deadline.map(|deadline| {
            let remaining = Duration::from_millis(deadline).saturating_sub(self.started.elapsed());
            // Poll の待ち時間は切り上げ、期限の直前に何度も起きることを防ぐ（実装プラン R40）。
            let millis = u64::try_from(remaining.as_millis()).unwrap_or(u64::MAX);
            Duration::from_millis(millis.saturating_add(u64::from(
                !remaining.subsec_nanos().is_multiple_of(1_000_000),
            )))
        })
    }
}

impl WorkerExec for ThreadWorkers {
    fn wakeup(&self) -> Option<Wakeup> {
        Some(self.wakeup.clone())
    }
    fn submit(&mut self, job: WorkerJob) {
        let mut queue = self.shared.queue.lock().unwrap_or_else(|e| e.into_inner());
        queue.jobs.push_back(job);
        // まだ列を取り出していない空きスレッドも数える。連続して submit しても
        // 必要な本数だけ作る（設計書 02-09「IO 実行器」）。
        if queue.jobs.len() > queue.threads.saturating_sub(queue.busy)
            && queue.threads < MAX_WORKERS
        {
            let shared = Arc::clone(&self.shared);
            let sender = self.sender.clone();
            let wakeup = self.wakeup.clone();
            match std::thread::Builder::new()
                .name("benitoite-worker".into())
                .spawn(move || worker_loop(shared, sender, wakeup))
            {
                Ok(handle) => {
                    queue.threads = queue.threads.saturating_add(1);
                    // 実行の終わりは仕事を待たない。JoinHandle を捨てて切り離す（ADR 0266 の決定 11）。
                    drop(handle);
                }
                Err(error) if queue.threads == 0 => {
                    if let Some(job) = queue.jobs.pop_front() {
                        // 凍結した submit の戻り値に誤りを載せられないので、完了で不具合を
                        // 報告し、貸したものも返す（実装プラン R40）。
                        drop(self.sender.send(Completion {
                            op: job.op,
                            outcome: Outcome::Panicked(PanicReport {
                                message: format!("cannot start worker thread: {error}"),
                                location: None,
                                backtrace: None,
                            }),
                            returned: job.lent,
                        }));
                        self.wakeup.wake();
                    }
                }
                // 既存のスレッドが空いたときに実行する。列から仕事を消さない（実装プラン R40）。
                Err(_) => {}
            }
        }
        self.shared.available.notify_one();
    }

    fn try_recv(&mut self) -> Option<Completion> {
        self.pending
            .take()
            .or_else(|| self.receiver.try_recv().ok())
    }

    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        if self.pending.is_some() {
            return IdleWake::Progress;
        }
        self.pending = self.receiver.try_recv().ok();
        if self.pending.is_some() {
            return IdleWake::Progress;
        }
        let timeout = self.timeout(deadline);
        if let Some(events) = &mut self.events {
            events.wait(timeout)
        } else {
            // Poll のないテスト用の実行器も、本物の仕事は channel から受け取る。
            // 出力の起こしは何もしないので、期限がないときは定期的に VM に戻って確認する
            // （実装プラン R40「RuntimeParts::real」）。
            let interval = Duration::from_millis(1);
            let timeout = timeout.unwrap_or(interval);
            self.pending = self.receiver.recv_timeout(timeout).ok();
            IdleWake::Progress
        }
    }
}

fn worker_loop(shared: Arc<SharedWork>, sender: mpsc::Sender<Completion>, wakeup: Wakeup) {
    loop {
        let job = {
            let mut queue = shared.queue.lock().unwrap_or_else(|e| e.into_inner());
            loop {
                if queue.closed {
                    return;
                }
                if let Some(job) = queue.jobs.pop_front() {
                    queue.busy = queue.busy.saturating_add(1);
                    break job;
                }
                queue = shared
                    .available
                    .wait(queue)
                    .unwrap_or_else(|e| e.into_inner());
            }
        };
        let completion = execute_job(job);
        {
            let mut queue = shared.queue.lock().unwrap_or_else(|e| e.into_inner());
            // 完了を届ける前に空きを記録し、次の submit が同じスレッドを使えるようにする。
            queue.busy = queue.busy.saturating_sub(1);
        }
        // 受け取り側がなくなったときは SendError とともに returned を破棄し、OS の資源を閉じる
        // （設計書 02-09「リソースの追跡」、ADR 0266 の決定 11）。
        drop(sender.send(completion));
        wakeup.wake();
    }
}

impl Drop for ThreadWorkers {
    fn drop(&mut self) {
        let jobs = {
            let mut queue = self.shared.queue.lock().unwrap_or_else(|e| e.into_inner());
            queue.closed = true;
            std::mem::take(&mut queue.jobs)
        };
        self.shared.available.notify_all();
        // 未開始の仕事も実行せず捨てる。資源の破棄は列のロックの外で行う（ADR 0266 の決定 11）。
        drop(jobs);
    }
}

#[cfg(test)]
mod tests;

/// テスト用のハンドラ表が返すネットワークの失敗（実装プラン 10-16、ADR 0222・0287）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum NetworkFault {
    HostNotFound,
    ConnectionRefused,
    ConnectionReset,
    TimedOut,
}

/// テスト用のハンドラ表のネットワークの失敗の表。空なら、本番のハンドラ表と同じく実際に行う。
#[derive(Clone, Debug, Default)]
pub struct NetworkFaults {
    /// 名前（`Http.send`・`Http.get` の URL の host と、`Http.listen` の `host`）ごとに返す失敗
    pub by_host: Vec<(String, NetworkFault)>,
}

impl NetworkFaults {
    /// `host` に当てる失敗。名前は ASCII の大文字と小文字を区別せずに比べる。なければ `None`。
    pub fn lookup(&self, host: &str) -> Option<NetworkFault> {
        self.by_host
            .iter()
            .find(|(name, _)| name.eq_ignore_ascii_case(host))
            .map(|(_, fault)| *fault)
    }
}
