//! 出力先だけを置き換え、転送の順序を channel で定める部品（実装プラン R27、設計書 07-03）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::*;
use std::sync::mpsc::{self, Receiver, Sender};
use std::time::Duration;

pub(crate) struct Gate {
    pub(crate) entered: Receiver<usize>,
    pub(crate) permit: Sender<()>,
    pub(crate) bytes: Arc<Mutex<Vec<u8>>>,
}
struct GatedSink {
    entered: Sender<usize>,
    permit: Receiver<()>,
    bytes: Arc<Mutex<Vec<u8>>>,
    fail: bool,
    panic: bool,
}
impl Write for GatedSink {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        self.entered.send(bytes.len()).unwrap();
        self.permit.recv_timeout(Duration::from_secs(5)).unwrap();
        assert!(!self.panic, "writer test panic");
        if self.fail {
            return Err(std::io::ErrorKind::BrokenPipe.into());
        }
        self.bytes.lock().unwrap().extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
pub(crate) fn gated(fail: bool, panic: bool) -> (Box<dyn Write + Send>, Gate) {
    let (entered, observed) = mpsc::channel();
    let (permit, allowed) = mpsc::channel();
    let bytes = Arc::new(Mutex::new(Vec::new()));
    (
        Box::new(GatedSink {
            entered,
            permit: allowed,
            bytes: Arc::clone(&bytes),
            fail,
            panic,
        }),
        Gate {
            entered: observed,
            permit,
            bytes,
        },
    )
}
impl Gate {
    pub(crate) fn entered(&self) -> usize {
        self.entered.recv_timeout(Duration::from_secs(5)).unwrap()
    }
    pub(crate) fn release(&self) {
        self.permit.send(()).unwrap();
    }
}
fn task(index: u32) -> TaskId {
    TaskId {
        index,
        generation: 0,
    }
}
fn notified(wakeup: &Wakeup, seen: &mut u64) {
    *seen = crate::runtime::io::event::wait_counted(wakeup, *seen).unwrap();
}
// 関門: 容量の数え漏れ、待つ書き込みの追い越し、取り消した未受け付け出力の配送を、
// 公開の OutputPort から確かめる。VM の小さい出力のテストは上限に達しない。
#[test]
fn capacity_counts_in_flight_and_queue_keeps_fifo_and_cancellation() {
    {
        let wakeup = crate::runtime::io::event::wakeup_counted();
        let (sink, gate) = gated(false, false);
        let mut port = OutputPort::start(Stream::Stdout, sink, false, wakeup);
        assert_eq!(
            port.write(task(0), &vec![b'a'; 1048544]),
            Ok(Accept::Accepted)
        );
        assert_eq!(gate.entered(), 1048544);
        assert_eq!(port.write(task(1), &[b'a'; 32]), Ok(Accept::Accepted));
        // まだバッファにある 32 バイトも容量に数える。
        assert_eq!(port.write(task(2), b"overflow"), Ok(Accept::Deferred));
        port.cancel_pending(task(2));
        gate.release();
        assert_eq!(gate.entered(), 32);
        gate.release();
        assert_eq!(port.finish(), Ok(()));
        assert_eq!(gate.bytes.lock().unwrap().len(), 1048576);
    }
    let wakeup = crate::runtime::io::event::wakeup_counted();
    let (sink, gate) = gated(false, false);
    let mut port = OutputPort::start(Stream::Stdout, sink, false, wakeup.clone());
    let half = vec![b'a'; 524288];
    assert_eq!(port.write(task(0), &half), Ok(Accept::Accepted));
    assert_eq!(gate.entered(), half.len());
    assert_eq!(port.write(task(1), &half), Ok(Accept::Accepted));
    assert_eq!(
        port.write(task(2), &vec![b'b'; 600000]),
        Ok(Accept::Deferred)
    );
    assert_eq!(port.write(task(3), b"cancelled"), Ok(Accept::Deferred));
    assert_eq!(port.write(task(4), b"last"), Ok(Accept::Deferred));
    port.cancel_pending(task(3));
    port.cancel_pending(task(0)); // 受け付けた出力は残す。
    gate.release();
    let mut seen = 0;
    notified(&wakeup, &mut seen);
    assert_eq!(gate.entered(), half.len());
    assert!(port.poll().0.is_empty()); // 小さい last も大きい先頭を追い越さない。
    gate.release();
    notified(&wakeup, &mut seen);
    assert_eq!(port.poll(), (vec![task(2), task(4)], None));
    assert_eq!(gate.entered(), 600000);
    gate.release();
    notified(&wakeup, &mut seen);
    port.request_transfer();
    assert_eq!(gate.entered(), 4);
    gate.release();
    assert_eq!(port.finish(), Ok(()));
    let bytes = gate.bytes.lock().unwrap();
    assert_eq!(bytes.len(), 1048576 + 600000 + 4);
    assert!(bytes[..1048576].iter().all(|&b| b == b'a'));
    assert!(bytes[1048576..1648576].iter().all(|&b| b == b'b'));
    assert_eq!(&bytes[1648576..], b"last");
}
#[test]
fn oversized_write_waits_for_empty_and_flush_only_waits_for_its_target() {
    let wakeup = crate::runtime::io::event::wakeup_counted();
    let (sink, gate) = gated(false, false);
    let mut port = OutputPort::start(Stream::Stdout, sink, false, wakeup.clone());
    let big = vec![b'x'; 2097152];
    assert_eq!(port.write(task(0), &big), Ok(Accept::Accepted));
    assert_eq!(gate.entered(), big.len());
    port.flush_target(task(1));
    port.flush_target(task(8));
    port.cancel_pending(task(8));
    assert_eq!(port.write(task(2), &big), Ok(Accept::Deferred));
    gate.release();
    let mut seen = 0;
    notified(&wakeup, &mut seen);
    assert_eq!(port.poll(), (vec![task(1), task(2)], None));
    assert_eq!(gate.entered(), big.len());
    // 後から加えた出力は最初の flush_target に含めない。
    gate.release();
    assert_eq!(port.finish(), Ok(()));
    assert_eq!(gate.bytes.lock().unwrap().len(), 4194304);
}
// 関門: finish より前に転送を依頼する条件を、実際の出力先への到着で観察する。
#[test]
fn threshold_and_terminal_newline_request_transfer_before_finish() {
    for (terminal, bytes, transfer) in [
        (false, vec![b'a'; 65536], true),
        (true, b"line\n".to_vec(), true),
        (false, b"line\n".to_vec(), false),
    ] {
        let (sink, gate) = gated(false, false);
        let wakeup = crate::runtime::io::event::wakeup_counted();
        let mut port = OutputPort::start(Stream::Stdout, sink, terminal, wakeup.clone());
        assert_eq!(port.write(task(0), &bytes), Ok(Accept::Accepted));
        if !transfer {
            // 通し番号なら書き出し用のスレッドの実行の速さに依存せず、未依頼を確かめられる。
            assert_eq!(port.flush_target(task(1)), 0);
            // バッファのままなら失敗も到着もまだない。finish の依頼で初めて write が始まる。
            assert!(matches!(
                gate.entered.try_recv(),
                Err(mpsc::TryRecvError::Empty)
            ));
            port.request_transfer();
        }
        assert_eq!(gate.entered(), bytes.len());
        gate.release();
        let mut seen = 0;
        notified(&wakeup, &mut seen);
        assert_eq!(*gate.bytes.lock().unwrap(), bytes);
        assert_eq!(port.finish(), Ok(()));
        assert_eq!(*gate.bytes.lock().unwrap(), bytes);
    }
}
// 関門: 失敗を出したタスクの取り消し後にも記録が残り、容量と完了の待ちが同時に解ける。
#[test]
fn failure_or_panic_releases_waiters_and_rejects_later_writes() {
    for panic in [false, true] {
        let wakeup = crate::runtime::io::event::wakeup_counted();
        let (sink, gate) = gated(!panic, panic);
        let mut port = OutputPort::start(Stream::Stdout, sink, false, wakeup.clone());
        assert_eq!(
            port.write(task(0), &vec![b'x'; 1048576]),
            Ok(Accept::Accepted)
        );
        gate.entered();
        port.cancel_pending(task(0));
        assert_eq!(port.write(task(1), b"deferred"), Ok(Accept::Deferred));
        port.flush_target(task(2));
        gate.release();
        let mut seen = 0;
        notified(&wakeup, &mut seen);
        let (tasks, failure) = port.poll();
        assert_eq!(tasks, [task(1), task(2)]);
        let failure = failure.unwrap();
        assert_eq!(matches!(failure, WriteFailure::Panicked(_)), panic);
        assert_eq!(port.write(task(3), b"later"), Err(failure.clone()));
        assert_eq!(port.flush_pending(), Err(failure.clone()));
        assert_eq!(port.finish(), Err(failure));
        assert!(gate.bytes.lock().unwrap().is_empty());
    }
}
