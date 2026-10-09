//! 中断から停止・解放・報告までを本物の VM とランタイムで確かめる（実装プラン R28）。

use super::*;
use crate::runtime::io::event::Wakeup;
use crate::runtime::sched::parts::TaskPicker;
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::TaskId;
use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};

#[derive(Debug)]
struct Flag(Arc<AtomicBool>);
impl InterruptSource for Flag {
    fn requested(&self) -> bool {
        self.0.load(Ordering::Relaxed)
    }
    fn flag(&self) -> Option<&AtomicBool> {
        Some(&self.0)
    }
    fn attach(
        &self,
        _: &Wakeup,
    ) -> std::io::Result<Option<crate::runtime::io::event::InterruptGuard>> {
        panic!("test parts must not attach signals")
    }
}

#[derive(Debug)]
struct InterruptPicker {
    flag: Arc<AtomicBool>,
    picks: Arc<Mutex<usize>>,
}
impl TaskPicker for InterruptPicker {
    fn pick(&mut self, ready: &VecDeque<TaskId>) -> Option<usize> {
        if ready.is_empty() {
            return None;
        }
        *self.picks.lock().unwrap() += 1;
        self.flag.store(true, Ordering::Relaxed);
        Some(0)
    }
}

// 関門: 中断を予算の満了時だけ調べる退行は、有限の末尾再帰の結果と
// 終了状態で捕まえる。出力の最終転送と attach の省略も run_program で観察する。
#[test]
fn computing_interrupts_at_the_next_call_and_flushes_buffered_output() {
    let program = compiled(
        "import Benitoite.Unofficial.IO.Console\nfunction loop(n: Integer) -> Unit\n if n = 0 then return () end if\n return loop(n - 1)\nend function\nfunction main() -> Unit uses Console.Write\n Console.writeLine(\"before interrupt\")\n loop(100)\n return ()\nend function\n",
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let flag = Arc::new(AtomicBool::new(false));
        let picks = Arc::new(Mutex::new(0));
        let mut env = environment();
        env.mode = mode;
        env.vm.call_budget = 3;
        env.heap.stress = true;
        let OutputTarget::Capture(output) = &env.stdout else {
            panic!("capture missing")
        };
        let output = Arc::clone(output);
        let mut parts = ScheduleHandle::new([], false).parts();
        parts.picker = Box::new(InterruptPicker {
            flag: Arc::clone(&flag),
            picks: Arc::clone(&picks),
        });
        env.parts = Some(parts);
        env.interrupt = Box::new(Flag(flag));
        let end = run_program(&program, env);
        assert_eq!(end.end, EndKind::Interrupted);
        assert_eq!(end.exit_code, EXIT_INTERRUPTED);
        assert!(end.reports.is_empty(), "{:?}", end.reports);
        assert_eq!(*output.lock().unwrap(), b"before interrupt\n");
        // 次の呼び出しで止まれば、次の予算の満了による選択は起きない。
        assert_eq!(*picks.lock().unwrap(), 1);
    }
}

// 関門: 暗黙の呼び出しには通常の CALL の予算処理を通らないものがある。
// 本体の先頭で印が立っているとき、正常終了する前に停止する契約を表で確かめる。
#[test]
fn implicit_calls_observe_the_flag_before_running_the_body() {
    let sources = [
        "function f() -> Unit\n return ()\nend function\nfunction main() -> Unit\n f()\n return ()\nend function\n",
        "function f() -> Unit\n return ()\nend function\nfunction main() -> Unit\n return f()\nend function\n",
        "function main() -> Unit\n bind v <- lazy () end lazy\n return Lazy.force(v)\nend function\n",
        "function main() -> Unit uses State\n bind c <- Reference.new(0)\n bind _ <- Reference.update(c, lambda(n) return n + 1 end lambda)\n return ()\nend function\n",
        "effect Probe\n function ask() -> Unit\nend effect\nfunction main() -> Unit\n return handle ask() with case ask() -> resume(()) end handle\nend function\n",
    ];
    for source in sources {
        let program = compiled(source);
        let mut env = environment();
        env.interrupt = Box::new(Flag(Arc::new(AtomicBool::new(true))));
        env.parts = Some(ScheduleHandle::new([], false).parts());
        let end = run_program(&program, env);
        assert_eq!(end.end, EndKind::Interrupted, "{source}: {:?}", end.reports);
        assert_eq!(end.exit_code, EXIT_INTERRUPTED);
    }
}

// 関門: NoInterrupt は本物の部品でもシグナルを登録しない。parts がある経路の
// attach の省略は Flag::attach の panic で上の run_program のテストが確かめる。
#[test]
fn no_interrupt_does_not_attach_to_an_event_loop() {
    let wakeup = crate::runtime::io::event::wakeup_without_poll();
    assert!(NoInterrupt.attach(&wakeup).unwrap().is_none());
}

// 関門: VM の StopEnd の返却だけでは、失敗ごとの Release の報告と終了状態の
// 組み合わせを確かめられない。ランタイムが受け取る停止結果の表で確かめる。
#[test]
fn release_reports_keep_interrupt_and_exit_statuses() {
    let program = compiled("function main() -> Unit\n return ()\nend function\n");
    for (reason, kind, code) in [
        (StopReason::Interrupted, EndKind::Interrupted, 130),
        (StopReason::Exit(3), EndKind::Exited(3), 3),
    ] {
        let failures =
            ["inner failed", "outer failed"].map(|reason| crate::runtime::ReleaseFailure {
                kind: crate::runtime::ResourceKind::FileWriter,
                opened_at: None,
                reason: reason.into(),
            });
        let end = step_end(
            &program,
            VmStep::Stopped(crate::vm::StopEnd {
                reason,
                release_failures: failures.to_vec(),
            }),
        );
        assert_eq!(end.end, kind);
        assert_eq!(end.exit_code, code);
        assert_eq!(end.reports.len(), 2);
        for (report, failure) in end.reports.iter().zip(failures) {
            assert_eq!(report.kind, crate::diag::ReportKind::Release);
            assert!(
                report
                    .notes
                    .iter()
                    .any(|note| note.contains(&failure.reason))
            );
            assert!(
                report
                    .notes
                    .iter()
                    .any(|note| note.contains("exit status is not changed"))
            );
        }
    }
}
