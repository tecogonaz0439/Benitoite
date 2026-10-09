//! 出力のバッファと書き出し用のスレッド（設計書 02-09「出力のバッファ」、ADR 0045・0265）。

use std::collections::VecDeque;
use std::io::Write;
use std::sync::{Arc, Condvar, Mutex};
use std::thread::JoinHandle;

use crate::runtime::Stream;
use crate::runtime::panic::PanicReport;
use crate::vm::TaskId;

use super::event::Wakeup;

/// 転送を依頼するバッファの大きさ（64 KiB）。
pub const TRANSFER_THRESHOLD: u64 = 65_536;
/// 転送していない量の上限 B（1 MiB。本章「実装プランで決める値」）。
pub const UNSENT_LIMIT: u64 = 1_048_576;

/// 書き出しの失敗の記録。
#[derive(Clone, PartialEq, Debug)]
pub enum WriteFailure {
    /// `std::io::Error` の文字列
    Io(String),
    /// 書き出し用のスレッドの panic（処理系の不具合）
    Panicked(PanicReport),
}

/// 書き出し用のスレッドと VM のスレッドが共有する状態。
#[derive(Debug, Default)]
pub struct WriterState {
    /// 書き出し用のスレッドの列（転送を依頼したかたまり）
    pub queue: VecDeque<Vec<u8>>,
    /// 転送中の量
    pub in_flight: u64,
    /// 書き出し終えたかたまりの通し番号
    pub done_seq: u64,
    pub failure: Option<WriteFailure>,
    /// 終えるように求めた
    pub shutdown: bool,
}

#[derive(Debug, Default)]
pub struct WriterShared {
    pub state: Mutex<WriterState>,
    pub cond: Condvar,
}

/// 書き込みの受け付けの結果。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Accept {
    Accepted,
    /// 預けた。容量が空くまで書いたタスクを待たせる
    Deferred,
}

/// 出力一つ分の、VM のスレッドの側の状態。
#[derive(Debug)]
pub struct OutputPort {
    pub stream: Stream,
    pub is_terminal: bool,
    buf: Vec<u8>,
    /// 転送を依頼したかたまりの通し番号
    sent_seq: u64,
    /// 預けた書き込み（呼んだ順）
    deferred: VecDeque<(TaskId, Vec<u8>)>,
    /// 完了を待つタスクと、待つ通し番号
    flush_waiters: Vec<(TaskId, u64)>,
    shared: Arc<WriterShared>,
    thread: Option<JoinHandle<()>>,
}

impl OutputPort {
    /// 書き出し用のスレッドを起こして作る。`sink` は出力先（プロセスの出力か、メモリに捕らえる出力先）。
    pub fn start(
        stream: Stream,
        sink: Box<dyn Write + Send>,
        is_terminal: bool,
        wakeup: Wakeup,
    ) -> OutputPort {
        let shared = Arc::new(WriterShared::default());
        let writer = Arc::clone(&shared);
        let thread =
            match std::thread::Builder::new().spawn(move || writer_loop(writer, sink, wakeup)) {
                Ok(thread) => Some(thread),
                Err(error) => {
                    // start の戻り値は凍結している。通常の書き込み・完了確認で同じ失敗を返す（10-10）。
                    shared
                        .state
                        .lock()
                        .unwrap_or_else(|e| e.into_inner())
                        .failure = Some(WriteFailure::Io(error.to_string()));
                    None
                }
            };
        OutputPort {
            stream,
            is_terminal,
            buf: Vec::new(),
            sent_seq: 0,
            deferred: VecDeque::new(),
            flush_waiters: Vec::new(),
            shared,
            thread,
        }
    }
    /// 書き込む（ADR 0265 の決定 4 の規則）。失敗が記録されていれば、それを返す（書いたものは捨てる）。
    pub fn write(&mut self, task: TaskId, text: &[u8]) -> Result<Accept, WriteFailure> {
        let state = writer_state(&self.shared);
        if let Some(failure) = state.failure.clone() {
            return Err(failure);
        }
        let fits = self.deferred.is_empty() && accepts(&state, self.buf.len(), text.len());
        drop(state);
        if !fits {
            self.request_transfer();
            self.deferred.push_back((task, text.to_vec()));
            return Ok(Accept::Deferred);
        }
        self.accept_bytes(text);
        Ok(Accept::Accepted)
    }
    fn accept_bytes(&mut self, text: &[u8]) {
        self.buf.extend_from_slice(text);
        if size(self.buf.len()) >= TRANSFER_THRESHOLD || (self.is_terminal && text.contains(&b'\n'))
        {
            self.request_transfer();
        }
    }
    /// バッファの中身の転送を依頼する。
    pub fn request_transfer(&mut self) {
        let mut state = writer_state(&self.shared);
        if state.failure.is_some() {
            self.buf.clear();
            return;
        }
        if !self.buf.is_empty() {
            let Some(next) = self.sent_seq.checked_add(1) else {
                state.failure = Some(writer_bug("output sequence overflow"));
                self.buf.clear();
                return;
            };
            state.queue.push_back(std::mem::take(&mut self.buf));
            self.sent_seq = next;
            self.shared.cond.notify_one();
        }
    }
    /// その時点までに加えた出力の通し番号。完了を待つタスクはこの番号までの完了を待つ。
    pub fn flush_target(&mut self, task: TaskId) -> u64 {
        self.flush_waiters.push((task, self.sent_seq));
        self.sent_seq
    }
    /// 完了済みの出力は待たず、記録した失敗は仕事を出す前に返す（実装プラン R27）。
    pub(crate) fn flush_pending(&self) -> Result<bool, WriteFailure> {
        let state = writer_state(&self.shared);
        match state.failure.clone() {
            Some(failure) => Err(failure),
            None => Ok(state.done_seq < self.sent_seq),
        }
    }
    /// 書き出し用のスレッドの知らせを取り込み、容量が空いて受け付けた書き込みのタスクと、
    /// 完了を待ち終えたタスクを返す。失敗が記録されていれば、待つタスクをすべて返す。
    pub fn poll(&mut self) -> (Vec<TaskId>, Option<WriteFailure>) {
        let state = writer_state(&self.shared);
        let failure = state.failure.clone();
        let done = state.done_seq;
        drop(state);
        let mut ready = Vec::new();
        if failure.is_some() {
            ready.extend(self.deferred.drain(..).map(|(task, _)| task));
            ready.extend(self.flush_waiters.drain(..).map(|(task, _)| task));
            self.buf.clear();
            return (ready, failure);
        }
        self.flush_waiters.retain(|&(task, seq)| {
            if seq <= done {
                ready.push(task);
                false
            } else {
                true
            }
        });
        while let Some((_, bytes)) = self.deferred.front() {
            let state = writer_state(&self.shared);
            let fits = state.failure.is_none() && accepts(&state, self.buf.len(), bytes.len());
            drop(state);
            if !fits {
                break;
            }
            if let Some((task, bytes)) = self.deferred.pop_front() {
                self.accept_bytes(&bytes);
                ready.push(task);
            }
        }
        // 小さい書き込みを受け付けた後にも待ちが残る場合、容量を再び空ける（ADR 0265）。
        if !self.deferred.is_empty() {
            self.request_transfer();
        }
        (ready, None)
    }
    /// 取り消したタスクの、預けた書き込みと完了の待ちを取り下げる。
    pub fn cancel_pending(&mut self, task: TaskId) {
        self.deferred.retain(|(owner, _)| *owner != task);
        self.flush_waiters.retain(|(owner, _)| *owner != task);
    }
    /// 全体停止では受け付け前の書き込みと完了の待ちだけを捨てる（実装プラン R27）。
    pub(crate) fn cancel_all_pending(&mut self) {
        self.deferred.clear();
        self.flush_waiters.clear();
    }
    /// 最後の転送を依頼し、完了と失敗の確かめを終えるまで待つ。書き出し用のスレッドを終える。
    pub fn finish(&mut self) -> Result<(), WriteFailure> {
        self.request_transfer();
        writer_state(&self.shared).shutdown = true;
        self.shared.cond.notify_one();
        if let Some(thread) = self.thread.take()
            && thread.join().is_err()
        {
            writer_state(&self.shared).failure = Some(writer_bug(text::UNKNOWN_PANIC));
        }
        match writer_state(&self.shared).failure.clone() {
            Some(failure) => Err(failure),
            None => Ok(()),
        }
    }
}

mod text {
    pub const UNKNOWN_PANIC: &str = "unknown writer panic";
}
fn size(length: usize) -> u64 {
    u64::try_from(length).unwrap_or(u64::MAX)
}
fn accepts(state: &WriterState, buffered: usize, incoming: usize) -> bool {
    let unsent = state.queue.iter().fold(
        state.in_flight.saturating_add(size(buffered)),
        |sum, bytes| sum.saturating_add(size(bytes.len())),
    );
    let incoming = size(incoming);
    unsent.saturating_add(incoming) <= UNSENT_LIMIT || (incoming > UNSENT_LIMIT && unsent == 0)
}
fn writer_bug(message: &str) -> WriteFailure {
    WriteFailure::Panicked(PanicReport {
        message: message.into(),
        location: None,
        backtrace: None,
    })
}
fn writer_state(shared: &WriterShared) -> std::sync::MutexGuard<'_, WriterState> {
    match shared.state.lock() {
        Ok(state) => state,
        Err(poison) => {
            // 毒を通常の IO の失敗にしない。凍結した口が持つ panic の記録で伝える（実装プラン R27）。
            let mut state = poison.into_inner();
            state.failure = Some(writer_bug("output state mutex poisoned"));
            state.queue.clear();
            state
        }
    }
}
fn writer_loop(shared: Arc<WriterShared>, mut sink: Box<dyn Write + Send>, wakeup: Wakeup) {
    let result = crate::runtime::panic::catch(|| -> Result<(), WriteFailure> {
        loop {
            let mut state = writer_state(&shared);
            while state.queue.is_empty() && !state.shutdown && state.failure.is_none() {
                state = match shared.cond.wait(state) {
                    Ok(state) => state,
                    Err(poison) => {
                        drop(poison.into_inner());
                        return Err(writer_bug("output condition mutex poisoned"));
                    }
                };
            }
            if let Some(failure) = state.failure.clone() {
                return Err(failure);
            }
            let Some(bytes) = state.queue.pop_front() else {
                return Ok(());
            };
            state.in_flight = size(bytes.len());
            drop(state);
            // 出力先の待ちの間も VM は容量と失敗を読めるようにする（設計書 02-09「出力のバッファ」）。
            sink.write_all(&bytes)
                .and_then(|()| sink.flush())
                .map_err(|error| WriteFailure::Io(error.to_string()))?;
            let mut state = writer_state(&shared);
            state.in_flight = 0;
            state.done_seq = state
                .done_seq
                .checked_add(1)
                .ok_or_else(|| writer_bug("output completion sequence overflow"))?;
            drop(state);
            wakeup.wake();
        }
    });
    let failure = match result {
        Ok(Ok(())) => return,
        Ok(Err(failure)) => failure,
        Err(report) => WriteFailure::Panicked(report),
    };
    let mut state = writer_state(&shared);
    if state.failure.is_none() {
        state.failure = Some(failure);
    }
    state.queue.clear();
    state.in_flight = 0;
    drop(state);
    wakeup.wake();
}
impl Drop for OutputPort {
    fn drop(&mut self) {
        // 埋め込み側が早く捨てる場合も、所有する書き出しのスレッドを残さない（設計書 02-09）。
        if self.thread.is_some() {
            drop(self.finish());
        }
    }
}

#[cfg(test)]
pub(crate) mod testing;
