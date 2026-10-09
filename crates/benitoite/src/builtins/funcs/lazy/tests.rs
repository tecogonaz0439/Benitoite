//! 専用命令だけが遅延を評価する契約（実装プラン R29）。
use super::*;
use crate::builtins::table::call_builtin;
use crate::runtime::heap::{Heap, HeapConfig};
// 関門: 誤って raw を呼んだときの不具合の報告。FORCE のプログラムのテストはこの経路を通らない。
#[test]
fn raw_force_rejects_execution_outside_the_force_instruction() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        assert!(matches!(
            call_builtin(&force::DECL, ctx, None, None, None, &[Value::Unit]),
            Err(Stop::Internal(_))
        ));
    });
}
