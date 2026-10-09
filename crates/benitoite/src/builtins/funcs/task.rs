//! タスクの起動と待ち（設計書 01-11「タスクを起動する関数」「タスクの集まり」）。
//! 名前・権限・引数の数・DECLS の中の位置は、実装プラン 10-12 の宣言に揃える。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::iface::{Spawn, SpawnMode, StateReply, StateWait, TaskEndTarget, TaskPoll};
use crate::runtime::heap::Value;
use crate::runtime::list;

builtin! {
    /// 起動する関数の並びを VM に渡し、すべての結果を起動した順に待つ（設計書 01-11）。
    name = "Task.all",
    state fn all(ctx, a0: Value<'e>) -> StateReply<'e> {
        Ok(StateReply::SpawnTasks(Spawn { mode: SpawnMode::All, funcs: list::to_vec(&ctx, a0)? }))
    }
}

builtin! {
    /// 起動する関数と待ち方を VM に渡す（設計書 01-11）。
    name = "Task.allOk",
    state fn all_ok(ctx, a0: Value<'e>) -> StateReply<'e> {
        Ok(StateReply::SpawnTasks(Spawn { mode: SpawnMode::AllOk, funcs: list::to_vec(&ctx, a0)? }))
    }
}

builtin! {
    /// 起動する関数と待ち方を VM に渡す（設計書 01-11）。
    name = "Task.race",
    state fn race(ctx, a0: Value<'e>) -> StateReply<'e> {
        Ok(StateReply::SpawnTasks(Spawn { mode: SpawnMode::Race, funcs: list::to_vec(&ctx, a0)? }))
    }
}

builtin! {
    /// 0 以下の期限を 0 に直し、子と期限を VM に渡す（設計書 01-11）。
    name = "Task.withTimeout",
    state fn with_timeout(ctx, a0: i64, a1: Value<'e>) -> StateReply<'e> {
        let _ = ctx;
        Ok(StateReply::SpawnTasks(Spawn {
            mode: SpawnMode::WithTimeout { millis: u64::try_from(a0).unwrap_or(0) },
            funcs: vec![a1],
        }))
    }
}

builtin! {
    /// タスクの結果を読むか、終わりを待つ応答を返す（設計書 01-11）。
    name = "Task.await",
    state fn await_task(ctx, a0: Value<'e>) -> StateReply<'e> {
        let mut ctx = ctx;
        Ok(match ctx.task_poll(a0)? {
            TaskPoll::Done(value) => StateReply::Done(value),
            TaskPoll::Pending(id) => StateReply::Wait(StateWait::TaskEnd(TaskEndTarget::Await(id))),
        })
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    all::DECL,
    all_ok::DECL,
    race::DECL,
    with_timeout::DECL,
    await_task::DECL,
];

#[cfg(test)]
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(clippy::unwrap_used, clippy::panic)]
mod tests {
    use super::*;
    use crate::builtins::iface::CallCtx;
    use crate::runtime::heap::{Heap, HeapConfig};

    // 関門: 期限の正規化は組み込みの本体が守る独立の境界条件（実装プラン R39）。
    #[test]
    fn timeout_normalizes_non_positive_milliseconds() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let mut resources = crate::runtime::io::resources::ResourceTable::default();
            let mut scheduler = crate::runtime::sched::Scheduler::default();
            let mut services = crate::vm::state::Stage1StateServices {
                resources: &mut resources,
                scheduler: &mut scheduler,
            };
            for (input, expected) in [
                (i64::MIN, 0),
                (-1, 0),
                (0, 0),
                (1, 1),
                (i64::MAX, i64::MAX as u64),
            ] {
                let reply = with_timeout(
                    CallCtx::new(ctx, None, Some(&mut services), None)
                        .state_ctx()
                        .unwrap(),
                    input,
                    Value::Unit,
                )
                .unwrap();
                let StateReply::SpawnTasks(spawn) = reply else {
                    panic!("timeout did not spawn")
                };
                assert_eq!(spawn.mode, SpawnMode::WithTimeout { millis: expected });
            }
        });
    }
}
