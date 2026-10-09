//! 明示遅延の評価（設計書 01-08「明示遅延（初回リリース版）」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// `Lazy.force` の raw の本体（実装プラン 10-12「項目の種類」）。
    name = "Lazy.force",
    pure fn force(ctx, a0: Value<'e>) -> Value<'e> {
        let _ = (ctx, a0);
        Err(Stop::Internal("FORCE instruction must execute this intrinsic".into()))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[force::DECL];

#[cfg(test)]
mod tests;
