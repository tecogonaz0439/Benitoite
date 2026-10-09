//! 既存の VM のテストの準備処理を第 2 段のランタイムへ移す（実装プラン R26）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]
use crate::runtime::Stream;
use crate::runtime::io::output::OutputPort;

use crate::runtime::io::services::{IoRuntime, RunInput};
use crate::runtime::io::{DirectDispatcher, RequestDispatcher};
use crate::runtime::run::NoInterrupt;
use crate::runtime::sched::parts::RuntimeParts;
use crate::vm::{ExecMode, Vm};

pub(crate) struct TestIo {
    pub(crate) rt: IoRuntime,
}

/// 捕捉・再開・破棄の小さな VM の経路を通す（ADR 0318）。
pub(crate) fn check_small_continuations() {
    super::handlers::tests::check_small_continuations();
}

/// Lazy の結果とセルの書き込みの経路を回収と組み合わせる（ADR 0318）。
pub(crate) fn check_lazy_and_cell_writes() {
    super::lazy::tests::check_lazy_capture_and_result();
    super::cell::tests::check_cell_update_roots();
}
impl TestIo {
    pub(crate) fn new(input: RunInput) -> Self {
        Self::with_sinks(input, Box::new(std::io::sink()), Box::new(std::io::sink()))
    }
    pub(crate) fn with_sinks(
        input: RunInput,
        stdout: Box<dyn std::io::Write + Send>,
        stderr: Box<dyn std::io::Write + Send>,
    ) -> Self {
        let wakeup = crate::runtime::io::event::wakeup_without_poll();
        let outputs = (
            OutputPort::start(Stream::Stdout, stdout, false, wakeup.clone()),
            OutputPort::start(Stream::Stderr, stderr, false, wakeup.clone()),
        );
        let parts = RuntimeParts::real(wakeup.clone());
        Self {
            rt: IoRuntime::new(
                input,
                ExecMode::Direct,
                outputs,
                Box::new(std::io::Cursor::new(Vec::<u8>::new())),
                parts,
                Box::new(NoInterrupt),
                wakeup,
            ),
        }
    }
    pub(crate) fn runtime(&mut self, mode: ExecMode) -> &mut IoRuntime {
        self.rt.dispatcher = match mode {
            ExecMode::Direct => Box::new(DirectDispatcher),
            ExecMode::Request => Box::new(RequestDispatcher),
        };
        &mut self.rt
    }
    pub(crate) fn take_output(&mut self) -> Vec<(Stream, Vec<u8>)> {
        std::mem::take(&mut self.rt.output_trace)
    }
}
impl Vm<'_> {
    pub(crate) fn use_schedule(&mut self, script: crate::runtime::sched::testing::ScheduleHandle) {
        self.state.scheduling.test_parts = Some(script.parts());
    }
}

/// 保存したタスクの枠を読む。待つ間は RunState の実行中の窓が空になる（実装プラン R26）。
pub(crate) fn stack<'a, 'e>(
    state: &'a crate::vm::state::RunState,
    ctx: &'a crate::runtime::heap::NoGcCtx<'e>,
) -> &'a crate::vm::frame::TaskStack {
    if state.scheduling.active {
        &state.stack
    } else {
        let task = state.tasks.get(ctx, state.current_task).unwrap();
        &ctx.host::<crate::vm::task::TaskObj>(task).unwrap().stack
    }
}

pub(crate) fn clear_waiting_registers(
    state: &mut crate::vm::state::RunState,
    ctx: &mut crate::runtime::heap::NoGcCtx<'_>,
    regs: &[usize],
) {
    let task = state.tasks.get(ctx, state.current_task).unwrap();
    ctx.host_mut::<crate::vm::task::TaskObj, _>(task, |task, slots| {
        let window = &mut task.stack.segments[0].regs;
        for &reg in regs {
            slots.clear(&mut window[reg]);
        }
    })
    .unwrap();
}
