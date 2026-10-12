//! Boolean の文字列補間（設計書 01-04「型の変換」）。
//! 名前・権限・引数の数は標準ライブラリのソースの宣言と一致させる
//! （設計書 02-04「標準ライブラリのソースの持ち方」）。番号は表の中の位置で決まるので、DECLS の中の位置は変えない。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

builtin! {
    /// `%Boolean.toString` の本体。
    name = "%Boolean.toString",
    pure fn to_string(ctx, b: bool) -> Value<'e> {
        ctx.alloc_str(if b { "true" } else { "false" }, "%Boolean.toString")
    }
}

/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[to_string::DECL];
