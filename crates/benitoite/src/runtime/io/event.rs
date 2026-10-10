//! イベントループ（設計書 02-09「IO 実行器」）。`mio` の型はこのモジュールと HTTP の接続の層の中に閉じる（実装プラン 10-16）。

use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use crate::runtime::sched::parts::IdleWake;

const WAKE_TOKEN: mio::Token = mio::Token(0);
// R28 のシグナルの登録に予約する。起こし口と区別して中断を返す（設計書 02-09「中断の要求」）。
const INTERRUPT_TOKEN: mio::Token = mio::Token(1);

/// 中断のシグナルを実行ごとのイベントループに登録した印。落とすと登録を外す（`Drop`）。
/// R28 が `InterruptSource::attach` とあわせて加えた。中身の欄は R28 が決める。
pub struct InterruptGuard {
    registry: mio::Registry,
    signals: signal_hook_mio::v1_0::Signals,
}

impl std::fmt::Debug for InterruptGuard {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("InterruptGuard").finish_non_exhaustive()
    }
}

impl Drop for InterruptGuard {
    fn drop(&mut self) {
        // Poll の登録を先に外し、続いて Signals 自身がシグナルの登録を外す
        // （実装プラン R28「読み口のトレイトへの追加」）。
        drop(self.registry.deregister(&mut self.signals));
    }
}

/// Poll の所有を実行器へ渡す前に、中断の起こしを登録する（実装プラン R28）。
pub(crate) fn attach_interrupt(wakeup: &Wakeup) -> std::io::Result<InterruptGuard> {
    let WakeBackend::WithPoll { poll, .. } = &wakeup.inner.backend else {
        return Err(std::io::Error::other("interrupt wakeup has no event loop"));
    };
    let poll = poll.lock().unwrap_or_else(|e| e.into_inner());
    let registry = poll
        .as_ref()
        .ok_or_else(|| std::io::Error::other("interrupt event loop already taken"))?
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .registry()
        .try_clone()?;
    let mut signals = signal_hook_mio::v1_0::Signals::new([
        signal_hook::consts::SIGINT,
        signal_hook::consts::SIGTERM,
    ])?;
    registry.register(&mut signals, INTERRUPT_TOKEN, mio::Interest::READABLE)?;
    Ok(InterruptGuard { registry, signals })
}

/// イベントループを起こす口（`mio::Waker` を包む）。ほかのスレッドへ写してよい。
#[derive(Clone, Debug)]
pub struct Wakeup {
    inner: Arc<WakeupInner>,
}

/// `Wakeup` の中身。欄は R26・R40 が決める（R26 は欄を置かず、R40 が `mio` を使う形との分岐の欄を加える）。
#[derive(Debug)]
pub struct WakeupInner {
    backend: WakeBackend,
}

#[derive(Debug)]
enum WakeBackend {
    WithoutPoll,
    Counted {
        count: Mutex<u64>,
        cond: Condvar,
    },
    WithPoll {
        waker: mio::Waker,
        poll: Mutex<Option<Arc<Mutex<mio::Poll>>>>,
        registry: Arc<mio::Registry>,
        active_poll: Arc<Mutex<mio::Poll>>,
        ready_events: Mutex<mio::Events>,
        ready: Arc<Mutex<Vec<usize>>>,
        next_token: std::sync::atomic::AtomicUsize,
    },
}

impl Wakeup {
    pub fn wake(&self) {
        match &self.inner.backend {
            WakeBackend::WithoutPoll => {}
            WakeBackend::Counted { count, cond } => {
                let mut count = count.lock().unwrap_or_else(|e| e.into_inner());
                *count = count.saturating_add(1);
                cond.notify_all();
            }
            WakeBackend::WithPoll { waker, .. } => {
                // 失敗は捨ててよい。次のタイマーの期限か channel の確認でも待ちから戻る
                // （実装プラン R40「Wakeup とイベントループ」）。
                drop(waker.wake());
            }
        }
    }
}

/// 筋書きの部品が書き出しの知らせを失わずに待つ口（実装プラン R27）。
pub(crate) fn wakeup_counted() -> Wakeup {
    Wakeup {
        inner: Arc::new(WakeupInner {
            backend: WakeBackend::Counted {
                count: Mutex::new(0),
                cond: Condvar::new(),
            },
        }),
    }
}

/// 前回より新しい知らせを待つ。上限はテストの停止を検出するためだけに使う（実装プラン R27）。
pub(crate) fn wait_counted(wakeup: &Wakeup, seen: u64) -> Option<u64> {
    match &wakeup.inner.backend {
        WakeBackend::WithoutPoll | WakeBackend::WithPoll { .. } => None,
        WakeBackend::Counted { count, cond } => {
            let count = count.lock().unwrap_or_else(|e| e.into_inner());
            let (count, _) = cond
                .wait_timeout_while(count, Duration::from_secs(5), |n| *n <= seen)
                .unwrap_or_else(|e| e.into_inner());
            (*count > seen).then_some(*count)
        }
    }
}

/// テスト用の、イベントループを持たない起こし口。
pub(crate) fn wakeup_without_poll() -> Wakeup {
    Wakeup {
        inner: Arc::new(WakeupInner {
            backend: WakeBackend::WithoutPoll,
        }),
    }
}

/// OS の待ちと起こし口を作る。資源の不足は呼ぶ側が内部の誤りとして報告する（実装プラン R40）。
pub(crate) fn wakeup_with_poll() -> std::io::Result<Wakeup> {
    let poll = mio::Poll::new()?;
    let waker = mio::Waker::new(poll.registry(), WAKE_TOKEN)?;
    let registry = Arc::new(poll.registry().try_clone()?);
    let poll = Arc::new(Mutex::new(poll));
    Ok(Wakeup {
        inner: Arc::new(WakeupInner {
            backend: WakeBackend::WithPoll {
                waker,
                poll: Mutex::new(Some(Arc::clone(&poll))),
                registry,
                active_poll: poll,
                // 切り替えのたびの確保を避ける。idle 用とは別に保つ。
                ready_events: Mutex::new(mio::Events::with_capacity(128)),
                ready: Arc::new(Mutex::new(Vec::new())),
                next_token: std::sync::atomic::AtomicUsize::new(2),
            },
        }),
    })
}

/// `mio` の型を IO の外へ出さずに待つための包み（設計書 02-09「IO 実行器」）。
/// R28 はこのモジュール内で `poll.registry()` にシグナルを `INTERRUPT_TOKEN` で登録できる。
#[derive(Debug)]
pub(crate) struct EventLoop {
    poll: Arc<Mutex<mio::Poll>>,
    ready: Arc<Mutex<Vec<usize>>>,
    events: mio::Events,
}

impl EventLoop {
    /// 一つの実行器だけが Poll を所有する。テスト用の起こし口には Poll がない（実装プラン R40）。
    pub(crate) fn take(wakeup: &Wakeup) -> Option<Self> {
        match &wakeup.inner.backend {
            WakeBackend::WithoutPoll | WakeBackend::Counted { .. } => None,
            WakeBackend::WithPoll { poll, ready, .. } => {
                let taken = poll.lock().unwrap_or_else(|e| e.into_inner()).take();
                debug_assert!(taken.is_some(), "event loop already taken");
                taken.map(|poll| Self {
                    poll,
                    ready: Arc::clone(ready),
                    events: mio::Events::with_capacity(8),
                })
            }
        }
    }

    /// 起こしと期限は進行、中断の登録のトークンは中断として知らせる。
    pub(crate) fn wait(&mut self, timeout: Option<Duration>) -> IdleWake {
        match self
            .poll
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .poll(&mut self.events, timeout)
        {
            Ok(()) => {
                collect_ready(&self.ready, &self.events);
                if self.events.iter().any(|e| e.token() == INTERRUPT_TOKEN) {
                    IdleWake::Interrupted
                } else {
                    IdleWake::Progress
                }
            }
            // EINTR の後も VM に戻り、印とタイマーを調べ直す（設計書 02-09「中断の要求」）。
            Err(e) if e.kind() == std::io::ErrorKind::Interrupted => IdleWake::Progress,
            Err(_) => {
                // 戻り値は凍結しており IO の失敗を返せない。OS の待ちが失敗し続けても
                // 空回りせず、channel とタイマーを調べ直せるようにする（実装プラン R40）。
                std::thread::sleep(Duration::from_millis(1));
                IdleWake::Progress
            }
        }
    }
}

// 計算を続けるタスクがあっても、切り替えの境界で準備を取り込む（設計書 02-08「タスクの切り替え」）。
fn collect_ready(ready: &Mutex<Vec<usize>>, events: &mio::Events) {
    let mut ready = ready.lock().unwrap_or_else(|e| e.into_inner());
    ready.extend(events.iter().filter_map(|event| {
        let token = event.token();
        (token != WAKE_TOKEN && token != INTERRUPT_TOKEN).then_some(token.0)
    }));
}

/// HTTP の資源が解放時にも登録を外せるよう、実行ごとの Registry を共有する（実装プラン L30）。
/// 接続ごとの複製は記述子を消費するため、HTTP では起こし口の作成時の一つを共有する。
pub(crate) fn registry(wakeup: &Wakeup) -> std::io::Result<Arc<mio::Registry>> {
    match &wakeup.inner.backend {
        WakeBackend::WithPoll { registry, .. } => Ok(Arc::clone(registry)),
        WakeBackend::WithoutPoll | WakeBackend::Counted { .. } => Err(std::io::Error::other(
            "HTTP readiness requires an event loop",
        )),
    }
}

/// 予約済みの二つのトークンを避け、実行内で再利用しない番号を割り当てる（実装プラン 10-16）。
pub(crate) fn next_token(wakeup: &Wakeup) -> Result<usize, crate::runtime::Stop> {
    match &wakeup.inner.backend {
        WakeBackend::WithPoll { next_token, .. } => next_token
            .fetch_update(
                std::sync::atomic::Ordering::Relaxed,
                std::sync::atomic::Ordering::Relaxed,
                |token| token.checked_add(1),
            )
            .map_err(|_| crate::runtime::Stop::Internal("HTTP token overflow".into())),
        WakeBackend::WithoutPoll | WakeBackend::Counted { .. } => Err(
            crate::runtime::Stop::Internal("HTTP readiness requires an event loop".into()),
        ),
    }
}

/// HTTP の接続を、VM が待ちを公開した後に登録する（実装プラン 10-16）。
pub(crate) fn register(
    wakeup: &Wakeup,
    source: &mut impl mio::event::Source,
    token: usize,
    interest: mio::Interest,
) -> std::io::Result<()> {
    registry(wakeup)?.register(source, mio::Token(token), interest)
}
/// 読み書きの向きが変わった接続の準備を再登録する（実装プラン 10-16）。
pub(crate) fn reregister(
    wakeup: &Wakeup,
    source: &mut impl mio::event::Source,
    token: usize,
    interest: mio::Interest,
) -> std::io::Result<()> {
    registry(wakeup)?.reregister(source, mio::Token(token), interest)
}
/// HTTP の接続の登録を外す（実装プラン 10-16）。
pub(crate) fn deregister(
    wakeup: &Wakeup,
    source: &mut impl mio::event::Source,
) -> std::io::Result<()> {
    registry(wakeup)?.deregister(source)
}
/// 計算を続けるタスクがある間も準備を取り込み、VM に渡す列を取り出す（設計書 02-08）。
pub(crate) fn take_ready(wakeup: &Wakeup) -> Vec<usize> {
    match &wakeup.inner.backend {
        WakeBackend::WithPoll {
            active_poll,
            ready_events,
            ready,
            ..
        } => {
            let mut events = ready_events.lock().unwrap_or_else(|e| e.into_inner());
            // 同じ VM スレッドで idle と順に呼ぶ。準備を別の Poll に分けると通知を失う。
            if active_poll
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .poll(&mut events, Some(Duration::ZERO))
                .is_ok()
            {
                collect_ready(ready, &events);
            }
            std::mem::take(&mut *ready.lock().unwrap_or_else(|e| e.into_inner()))
        }
        WakeBackend::WithoutPoll | WakeBackend::Counted { .. } => Vec::new(),
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used)]
    use super::*;
    use std::sync::mpsc;

    // 関門: 登録が所有の移動の後に遅れると、待つ実行器を中断で起こせない。
    // シグナルを登録・送信せず、登録できない起こし口の拒否を確かめる（実装プラン R28）。
    #[test]
    fn interrupt_attachment_rejects_missing_or_already_taken_poll() {
        assert!(attach_interrupt(&wakeup_without_poll()).is_err());
        let wakeup = wakeup_with_poll().unwrap();
        let _events = EventLoop::take(&wakeup).unwrap();
        assert!(attach_interrupt(&wakeup).is_err());
    }

    // 関門: WorkerExec::idle の channel の事前確認だけでは、Poll 自体の起こしを通らない。
    // 外部の通知が先でも後でも失われない契約を、Poll を包む境界で確かめる。
    #[test]
    fn wake_before_or_during_poll_is_kept_after_ownership_transfer() {
        let wakeup = wakeup_with_poll().unwrap();
        let mut events = EventLoop::take(&wakeup).unwrap();
        let (ready, readiness) = mpsc::channel();
        let (done, completion) = mpsc::channel();
        let (next, another) = mpsc::channel();
        wakeup.wake();
        let waiting = std::thread::spawn(move || {
            ready.send(()).unwrap();
            done.send(events.wait(None)).unwrap();
            another.recv().unwrap();
            ready.send(()).unwrap();
            done.send(events.wait(None)).unwrap();
        });
        readiness.recv_timeout(Duration::from_secs(10)).unwrap();
        assert!(matches!(
            completion.recv_timeout(Duration::from_secs(10)).unwrap(),
            IdleWake::Progress
        ));
        next.send(()).unwrap();
        readiness.recv_timeout(Duration::from_secs(10)).unwrap();
        wakeup.wake();
        assert!(matches!(
            completion.recv_timeout(Duration::from_secs(10)).unwrap(),
            IdleWake::Progress
        ));
        waiting.join().unwrap();
    }

    // 関門: シグナルと完了のトークンを取り違えると中断が通常の進行として失われる。
    // R28 のシグナルの登録に先立ち、同じトークンの OS の読み取り通知で分類を確かめる。
    #[cfg(unix)]
    #[test]
    fn reserved_interrupt_token_returns_interrupted() {
        use std::io::Write;
        use std::os::fd::AsRawFd;
        use std::os::unix::net::UnixStream;
        let wakeup = wakeup_with_poll().unwrap();
        let mut events = EventLoop::take(&wakeup).unwrap();
        let (reader, mut writer) = UnixStream::pair().unwrap();
        reader.set_nonblocking(true).unwrap();
        events
            .poll
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .registry()
            .register(
                &mut mio::unix::SourceFd(&reader.as_raw_fd()),
                INTERRUPT_TOKEN,
                mio::Interest::READABLE,
            )
            .unwrap();
        writer.write_all(b"interrupt").unwrap();
        assert!(matches!(
            events.wait(Some(Duration::ZERO)),
            IdleWake::Interrupted
        ));
    }
    // 関門: 予約外の準備が Poll の所有の移動の後にも VM の take_ready に届く。
    // ソケット対を使い、ポートの bind と実時間の待ちに依存しない（L30）。
    #[cfg(unix)]
    #[test]
    fn ordinary_readiness_is_collected_and_drained_after_poll_transfer() {
        use std::io::Write;
        use std::os::fd::AsRawFd;
        let wakeup = wakeup_with_poll().unwrap();
        let mut events = EventLoop::take(&wakeup).unwrap();
        let (reader, mut writer) = std::os::unix::net::UnixStream::pair().unwrap();
        reader.set_nonblocking(true).unwrap();
        let token = next_token(&wakeup).unwrap();
        assert!(token >= 2);
        let mut source = mio::unix::SourceFd(&reader.as_raw_fd());
        register(&wakeup, &mut source, token, mio::Interest::READABLE).unwrap();
        writer.write_all(b"request").unwrap();
        assert!(matches!(
            events.wait(Some(Duration::ZERO)),
            IdleWake::Progress
        ));
        assert_eq!(take_ready(&wakeup), vec![token]);
        assert!(take_ready(&wakeup).is_empty());
        reregister(&wakeup, &mut source, token, mio::Interest::READABLE).unwrap();
        assert_eq!(take_ready(&wakeup), vec![token]);
        deregister(&wakeup, &mut source).unwrap();
        assert!(take_ready(&wakeup).is_empty());
        wakeup.wake();
        assert!(take_ready(&wakeup).is_empty());
    }
}
