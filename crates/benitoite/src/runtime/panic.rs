//! panic hook と panic 境界（設計書 02-09「panic 境界」）。
//!
//! 既定の hook は標準エラー出力に書くので、出力のバッファより先に診断の形式によらない文が出てしまう。
//! 処理系の hook は何も書かず、panic したスレッドのスレッドローカルな記憶域に内容を記録する。
//! この記録は、大域の状態を持たない規約の例外として 00-02「大域の状態」が認めたものである。

use std::backtrace::{Backtrace, BacktraceStatus};
use std::cell::RefCell;
use std::panic::{AssertUnwindSafe, PanicHookInfo};

/// payload が文字列でないときの文言。
const NON_STRING_PAYLOAD: &str = "<non-string panic payload>";
/// 記録がないまま panic を捕らえたときの文言（hook を設定していないときなど）。
const UNKNOWN_PANIC: &str = "unknown panic";

/// panic hook が記録した内容。
#[derive(Clone, PartialEq, Debug)]
pub struct PanicReport {
    pub message: String,
    /// `ファイル:行:列`
    pub location: Option<String>,
    pub backtrace: Option<String>,
}

thread_local! {
    /// panic したスレッドの記録。panic 境界が取り出す（02-09「panic 境界」）。
    static LAST_PANIC: RefCell<Option<PanicReport>> = const { RefCell::new(None) };
}

fn record(info: &PanicHookInfo<'_>) {
    let payload = info.payload();
    let message = payload
        .downcast_ref::<&str>()
        .map(|s| (*s).to_owned())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| String::from(NON_STRING_PAYLOAD));
    let location = info
        .location()
        .map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column()));
    // RUST_BACKTRACE に従って取る。無効なら報告に載せない。
    let bt = Backtrace::capture();
    let backtrace = (bt.status() == BacktraceStatus::Captured).then(|| bt.to_string());
    let report = PanicReport {
        message,
        location,
        backtrace,
    };
    // 記憶域が既に壊されている（スレッドの終わり）ときは記録しない。hook の中で panic しないため。
    // 記録できなくても hook の中でできることはないので、結果は捨てる。
    LAST_PANIC
        .try_with(|slot| {
            if let Ok(mut slot) = slot.try_borrow_mut() {
                *slot = Some(report);
            }
        })
        .unwrap_or(());
}

/// 処理系の panic hook を設定する。標準エラー出力に何も書かず、panic したスレッドのスレッドローカルな記憶域に記録する。
/// 処理系を使うプログラム（CLI）が、起動の直後、スレッドを作る前に一度だけ呼ぶ（02-09「panic 境界」）。
pub fn install_hook() {
    std::panic::set_hook(Box::new(record));
}

/// このスレッドで記録した panic の内容を取り出す（取り出した後は空になる）。
pub fn take_report() -> Option<PanicReport> {
    LAST_PANIC
        .try_with(|slot| slot.try_borrow_mut().ok().and_then(|mut s| s.take()))
        .ok()
        .flatten()
}

/// `f` を `catch_unwind` で囲んで呼ぶ。panic を捕らえたら記録を取り出して返す。
pub fn catch<T>(f: impl FnOnce() -> T) -> Result<T, PanicReport> {
    // 捕らえた後は、壊れたかもしれない状態を使わずに報告して終える（02-09）ので AssertUnwindSafe でよい。
    std::panic::catch_unwind(AssertUnwindSafe(f)).map_err(|_| {
        take_report().unwrap_or_else(|| PanicReport {
            message: String::from(UNKNOWN_PANIC),
            location: None,
            backtrace: None,
        })
    })
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::{catch, install_hook, take_report};

    #[test]
    fn caught_panic_carries_message_and_location() {
        // hook はプロセス全体で一つなので、hook を設定するテストはこの一つにまとめる。
        install_hook();
        assert_eq!(catch(|| 7), Ok(7));
        let report = catch(|| panic!("boom {}", 1)).unwrap_err();
        assert_eq!(report.message, "boom 1");
        let location = report.location.unwrap();
        assert!(location.contains("panic.rs:"), "{location}");
        // 取り出した後は空になる。
        assert_eq!(take_report(), None);
    }
}
