//! IO 実行器（設計書 02-09「IO 実行器」「panic 境界」）。
//!
//! VM を作り、`main` を最後まで実行する。IO の命令の実行には二つの方式がある（ADR 0029）。
//! 直接呼び出しでは VM がハンドラ表を呼び、要求と応答では VM が要求を返して止まり、ここでハンドラ表を呼んで応答を渡す。

use super::heap::AllocStats;
use super::io::IoHandlers;
use super::panic::{self, PanicReport};
use super::value::Value;
use crate::bytecode::program::CompiledProgram;
use crate::vm::{IoDispatch, StopInfo, Vm, VmConfig, VmStep};

/// IO の命令の実行の方式（ADR 0029）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ExecMode {
    Direct,
    Request,
}

/// IO 実行器の設定。`max_call_stack_bytes` は呼び出しの情報の合計の上限（ADR 0030）。
#[derive(Clone, Copy, Debug)]
pub struct ExecOptions {
    pub mode: ExecMode,
    pub max_call_stack_bytes: u64,
}

/// IO 実行器の結果。
#[derive(Debug)]
pub enum ExecEnd {
    Returned(Value),
    Stopped(StopInfo),
    /// 巻き戻しの panic を捕らえた（処理系の不具合）
    Panicked(PanicReport),
}

/// `main` を最後まで実行する（02-09「IO 実行器」）。VM の実行全体を `catch_unwind` で囲む（02-09「panic 境界」）。
/// 実行を終えたときの確保の統計も返す。
pub fn execute(
    program: &CompiledProgram,
    io: &mut dyn IoHandlers,
    opts: ExecOptions,
) -> (ExecEnd, AllocStats) {
    match panic::catch(|| run_vm(program, io, opts)) {
        Ok(end) => end,
        // panic の後の VM の状態は使わないので、統計は既定の値にする。
        Err(report) => (ExecEnd::Panicked(report), AllocStats::default()),
    }
}

fn run_vm(
    program: &CompiledProgram,
    io: &mut dyn IoHandlers,
    opts: ExecOptions,
) -> (ExecEnd, AllocStats) {
    let mut vm = Vm::new(
        program,
        VmConfig {
            max_call_stack_bytes: opts.max_call_stack_bytes,
        },
    );
    if let Err(info) = vm.start_main() {
        return (ExecEnd::Stopped(info), vm.heap().stats());
    }
    let step = match opts.mode {
        ExecMode::Direct => vm.run(IoDispatch::Direct(io)),
        // 要求を受けるたびにハンドラ表を呼び、応答を渡して続ける（ADR 0029）。
        ExecMode::Request => loop {
            match vm.run(IoDispatch::Request) {
                VmStep::Request(req) => {
                    let response = io.call(req.op, &req.args, vm.heap_mut());
                    vm.resume(response);
                }
                done @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break done,
            }
        },
    };
    let end = match step {
        VmStep::Finished(v) => ExecEnd::Returned(v),
        VmStep::Stopped(info) => ExecEnd::Stopped(info),
        // 直接呼び出しの方式では要求を返さない。返したら VM の不具合である。
        VmStep::Request(_) => ExecEnd::Stopped(StopInfo {
            stop: super::Stop::Internal(String::from("VM returned an IO request in direct mode")),
            at: None,
            frames: Vec::new(),
        }),
    };
    (end, vm.heap().stats())
}
