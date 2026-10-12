//! 明示遅延の評価（設計書 01-08「明示遅延（初回リリース版）」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// `Lazy.force` の表の項目。コード生成が専用の命令 `FORCE` に移すので、
    /// この本体は呼ばれない（設計書 02-07「コード生成」）。
    name = "Lazy.force",
    pure fn force(ctx, a0: Value<'e>) -> Value<'e> {
        let _ = (ctx, a0);
        Err(Stop::Internal("FORCE instruction must execute this intrinsic".into()))
    }
}

/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[force::DECL];

#[cfg(test)]
mod tests;
