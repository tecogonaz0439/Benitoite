//! VM のテストで使うヒープの観察とランタイムの準備処理
//! （設計書 02-08「値の表現」、02-09「IO 実行器」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]
use crate::bytecode::program::ConstIdx;
use crate::runtime::Stream;
use crate::runtime::heap::{NoGcCtx, ObjId, ObjKind, Value};
use crate::runtime::io::output::OutputPort;

use crate::runtime::io::services::{IoRuntime, RunInput};
use crate::runtime::io::{DirectDispatcher, RequestDispatcher};
use crate::runtime::run::NoInterrupt;
use crate::runtime::sched::parts::RuntimeParts;
use crate::vm::state::RunState;
use crate::vm::{ExecMode, Vm};
use std::collections::HashSet;

/// 読み込み済みの定数を、回収しない区間の値として読む（設計書 02-07「定数表」）。
pub(crate) fn constant<'e>(state: &RunState, ctx: &NoGcCtx<'e>, k: ConstIdx) -> Value<'e> {
    ctx.load(
        state
            .constants
            .get(usize::try_from(k.0).unwrap())
            .unwrap()
            .as_ref()
            .unwrap(),
    )
}

/// 値の並びの欄から到達できる対象の ID を、言語の値を確保せずに集める。
/// セルや Host の子は辿らない（設計書 02-08「値の表現」）。
/// 解放を確かめる用途では、元の値だけが持つ対象から成る値に使う。
pub(crate) fn reachable_object_ids<'e>(ctx: &NoGcCtx<'e>, value: Value<'e>) -> HashSet<ObjId> {
    let mut pending = vec![value];
    let mut ids = HashSet::new();
    while let Some(value) = pending.pop() {
        let Some(kind) = ctx.kind(value) else {
            continue;
        };
        if !ids.insert(ctx.object_id(value).unwrap()) {
            continue;
        }
        if matches!(kind, ObjKind::Fields(_)) {
            for i in 0..ctx.fields_len(value).unwrap() {
                pending.push(ctx.field(value, i).unwrap());
            }
        }
    }
    ids
}

pub(crate) struct TestIo {
    pub(crate) rt: IoRuntime,
}

/// 捕捉・再開・破棄の小さな VM の経路を通す（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
pub(crate) fn check_small_continuations() {
    super::handlers::tests::check_small_continuations();
}

/// Lazy の結果とセルの書き込みの経路を回収と組み合わせる（設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
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

/// 保存したタスクの枠を読む。待つ間は RunState の実行中の窓が空になる。
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
