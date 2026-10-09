//! Boolean の文字列補間（設計書 01-04「型の変換」、実装プラン 10-12「基本型のモジュール」）。
//! 仮の本体は、後の作業が本体と Rust の引数型だけを書き換える。
//! 名前・権限・引数の数・DECLS の中の位置は変えない（実装プラン 10-12「まだ書かない項目の仮の本体」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

builtin! {
    /// `%Boolean.toString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Boolean.toString",
    pure fn to_string(ctx, b: bool) -> Value<'e> {
        ctx.alloc_str(if b { "true" } else { "false" }, "%Boolean.toString")
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[to_string::DECL];
