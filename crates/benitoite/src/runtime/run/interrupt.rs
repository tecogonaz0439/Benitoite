//! プロセスの中断の印とシグナルの登録（設計書 02-09「中断の要求」）。

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::runtime::io::event::{InterruptGuard, Wakeup, attach_interrupt};
use crate::runtime::io::services::InterruptSource;

#[derive(Debug)]
struct ProcessInterrupt {
    flag: Arc<AtomicBool>,
    registrations: Vec<signal_hook::SigId>,
}

impl InterruptSource for ProcessInterrupt {
    fn requested(&self) -> bool {
        self.flag.load(Ordering::Relaxed)
    }

    fn flag(&self) -> Option<&AtomicBool> {
        Some(&self.flag)
    }

    fn attach(&self, wakeup: &Wakeup) -> std::io::Result<Option<InterruptGuard>> {
        attach_interrupt(wakeup).map(Some)
    }
}

impl Drop for ProcessInterrupt {
    fn drop(&mut self) {
        // 登録の途中の失敗でも、それまでの登録を残さない（実装プラン R28「中断の印」）。
        for id in self.registrations.drain(..) {
            signal_hook::low_level::unregister(id);
        }
    }
}

pub(super) fn register() -> std::io::Result<Box<dyn InterruptSource>> {
    let mut source = ProcessInterrupt {
        flag: Arc::new(AtomicBool::new(false)),
        registrations: Vec::with_capacity(4),
    };
    for signal in [signal_hook::consts::SIGINT, signal_hook::consts::SIGTERM] {
        // 既定動作の条件を先に調べる。一度目に立てた印で同じ要求が即時終了しない
        // （signal-hook の flag の登録順、設計書 02-09「中断の要求」）。
        source
            .registrations
            .push(signal_hook::flag::register_conditional_default(
                signal,
                Arc::clone(&source.flag),
            )?);
        source.registrations.push(signal_hook::flag::register(
            signal,
            Arc::clone(&source.flag),
        )?);
    }
    Ok(Box::new(source))
}
