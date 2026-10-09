//! 可変のセルの操作（設計書 01-07「可変のセル（初回リリース版）」）。

use crate::builtins::iface::StateReply;
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// 初期値を持つセルを作る。
    name = "Reference.new",
    state fn new(ctx, value: Value<'e>) -> StateReply<'e> {
        Ok(StateReply::Done(ctx.alloc_cell(value)))
    }
}
builtin! {
    /// セルの現在の値を返す。
    name = "Reference.get",
    state fn get(ctx, cell: Value<'e>) -> StateReply<'e> {
        ctx.cell_get(cell)
            .map(StateReply::Done)
            .ok_or_else(|| Stop::Internal("Reference.get requires a cell".into()))
    }
}
builtin! {
    /// セルに書き、版の番号を一つ増やす。
    name = "Reference.set",
    state fn set(ctx, cell: Value<'e>, value: Value<'e>) -> StateReply<'e> {
        ctx.cell_set(cell, value)?;
        Ok(StateReply::Done(Value::Unit))
    }
}
builtin! {
    /// `Reference.update` の raw の本体（実装プラン 10-12「項目の種類」）。
    name = "Reference.update",
    state fn update(ctx, a0: Value<'e>, a1: Value<'e>) -> StateReply<'e> {
        let _ = (ctx, a0, a1);
        Err(Stop::Internal("UPDATE instruction must execute this intrinsic".into()))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[new::DECL, get::DECL, set::DECL, update::DECL];

#[cfg(test)]
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(clippy::unwrap_used, clippy::panic, clippy::arithmetic_side_effects)]
mod tests {
    use super::*;
    use crate::builtins::iface::CallCtx;
    use crate::runtime::heap::{Heap, HeapConfig};
    use crate::vm::state::Stage1StateServices;

    // 関門: 名前の付いた本体の値・Unit・版の契約。ヒープのテストは組み込みの応答を
    // 確かめず、スクリプトのテストでは版を読めない。差し込み口は加えない（実装プラン 10-12）。
    #[test]
    fn new_get_and_set_preserve_values_and_increment_version() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let mut resources = crate::runtime::io::resources::ResourceTable::default();
            let mut scheduler = crate::runtime::sched::Scheduler::default();
            let mut services = Stage1StateServices {
                resources: &mut resources,
                scheduler: &mut scheduler,
            };
            let StateReply::Done(cell) = new(
                CallCtx::new(ctx, None, Some(&mut services), None)
                    .state_ctx()
                    .unwrap(),
                Value::Int(7),
            )
            .unwrap() else {
                panic!("new did not finish")
            };
            let StateReply::Done(value) = get(
                CallCtx::new(ctx, None, Some(&mut services), None)
                    .state_ctx()
                    .unwrap(),
                cell,
            )
            .unwrap() else {
                panic!("get did not finish")
            };
            assert_eq!(value.as_int(), Some(7));
            let version = ctx.cell_version(cell).unwrap();
            let replacement = ctx.alloc_str("changed", "test").unwrap();
            let StateReply::Done(value) = set(
                CallCtx::new(ctx, None, Some(&mut services), None)
                    .state_ctx()
                    .unwrap(),
                cell,
                replacement,
            )
            .unwrap() else {
                panic!("set did not finish")
            };
            assert!(matches!(value, Value::Unit));
            assert_eq!(ctx.cell_version(cell), Some(version + 1));
            let StateReply::Done(value) = get(
                CallCtx::new(ctx, None, Some(&mut services), None)
                    .state_ctx()
                    .unwrap(),
                cell,
            )
            .unwrap() else {
                panic!("get did not finish")
            };
            assert_eq!(ctx.str(value), Some("changed"));
            assert!(matches!(
                get(
                    CallCtx::new(ctx, None, Some(&mut services), None)
                        .state_ctx()
                        .unwrap(),
                    Value::Unit,
                ),
                Err(Stop::Internal(_))
            ));
            assert!(matches!(
                set(
                    CallCtx::new(ctx, None, Some(&mut services), None)
                        .state_ctx()
                        .unwrap(),
                    Value::Unit,
                    Value::Int(1),
                ),
                Err(Stop::Internal(_))
            ));
        });
    }
    // 関門: UPDATE のプログラムは raw を通らない。専用命令の外で実行されないことを確かめる。
    #[test]
    fn raw_update_rejects_execution_outside_the_update_instruction() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let mut resources = crate::runtime::io::resources::ResourceTable::default();
            let mut scheduler = crate::runtime::sched::Scheduler::default();
            let mut services = Stage1StateServices {
                resources: &mut resources,
                scheduler: &mut scheduler,
            };
            assert!(matches!(
                crate::builtins::table::call_builtin(
                    &update::DECL,
                    ctx,
                    None,
                    Some(&mut services),
                    None,
                    &[Value::Unit, Value::Unit]
                ),
                Err(Stop::Internal(_))
            ));
        });
    }
}
