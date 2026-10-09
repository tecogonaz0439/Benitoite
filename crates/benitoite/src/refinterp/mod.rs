//! コア計算の状態と遷移による参照インタプリタ（設計書 01-12、02-08「参照インタプリタ」）。

mod convert;
mod eval;
mod index;
mod pattern;
mod resources;
#[cfg(test)]
mod tests;
mod value;

use crate::base::Span;
use crate::builtins::iface::IoServices;
use crate::ir::core_ir::CoreProgram;
use crate::runtime::{ReleaseFailure, Stop};
use crate::vm::MainOutcome;

/// 参照インタプリタの実行の結果。VM の `VmStep` と比べられる形にする。
#[derive(Clone, PartialEq, Debug)]
pub enum RefOutcome {
    /// `main` が値を返した
    Finished(MainOutcome),
    /// 実行時エラー・資源の不足・処理系の不具合で止まった（`error(r̄, [], σ)` に達した）。
    /// `origin` は止まった計算の由来位置、`release_failures` は r̄ の先頭の後の解放の失敗
    Stopped {
        stop: Stop,
        origin: Option<Span>,
        release_failures: Vec<ReleaseFailure>,
    },
    /// `Process.exit` で終わった（`exit(n, r̄, [], σ)` に達した）
    Exited {
        status: u8,
        release_failures: Vec<ReleaseFailure>,
    },
    /// 参照インタプリタが実行しない組み込みの関数（タスクの起動）に出会った。文字列はその関数の修飾した名前
    Unsupported(String),
}

/// `main` を呼ぶ状態 `⟨main[;](), [], ∅⟩` から実行する（01-12「エフェクトの名前と開始状態」）。テストだけで使う。
/// 継続は `Vec` で持ち、Rust の再帰を使わない。`program.main` が `None` なら、実行せずに `Stop::Internal` の `Stopped` を返す。
pub fn run(program: &CoreProgram, io: &mut dyn IoServices) -> RefOutcome {
    match eval::Machine::new(program) {
        Ok(mut machine) => machine.run(io),
        Err(stop) => eval::stopped(stop, None),
    }
}
