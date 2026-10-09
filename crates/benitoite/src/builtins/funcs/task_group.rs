//! タスクの集まりの構築と起動（設計書 01-11「タスクの集まり」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::iface::{Spawn, SpawnMode, StateReply};
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// 空のタスクの集まりを開く（設計書 01-11）。
    name = "TaskGroup.open",
    state fn open(ctx) -> StateReply<'e> {
        let mut ctx = ctx;
        let site = ctx.site();
        let group = ctx.services().open_task_group(site);
        Ok(StateReply::Done(Value::Resource(group)))
    }
}

builtin! {
    /// 関数をタスクとして起動し、集まりに加える応答を返す（設計書 01-11）。
    name = "TaskGroup.spawn",
    state fn spawn(ctx, a0: Value<'e>, a1: Value<'e>) -> StateReply<'e> {
        let _ = ctx;
        let group = a0.as_resource().ok_or_else(|| Stop::Internal("TaskGroup.spawn requires a resource".to_owned()))?;
        Ok(StateReply::SpawnTasks(Spawn { mode: SpawnMode::GroupSpawn { group }, funcs: vec![a1] }))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[open::DECL, spawn::DECL];
