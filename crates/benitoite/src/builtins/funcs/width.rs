//! 幅の決まった数の比較と文字列化を、型付きの呼び出しで実行する
//! （設計書 02-08「組み込みの関数の呼び出し」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

// 型を明示して比較し、符号と幅を保つ。f32 の比較も Rust の部分順序を使い、
// NaN を最大値とする型クラスの全順序とは区別する（設計書 01-06「演算子の型付け」）。
macro_rules! number {
    ($module:ident, $ty:ty, $less:literal, $le:literal, $greater:literal, $ge:literal,
     $string:literal, $format:path) => {
        mod $module {
            use super::*;

            builtin! {
                /// 左辺が右辺より小さいかを返す。
                name = $less,
                pure fn less(ctx, a: $ty, b: $ty) -> bool {
                    let _ = ctx;
                    Ok(a < b)
                }
            }
            builtin! {
                /// 左辺が右辺以下かを返す。
                name = $le,
                pure fn less_or_equal(ctx, a: $ty, b: $ty) -> bool {
                    let _ = ctx;
                    Ok(a <= b)
                }
            }
            builtin! {
                /// 左辺が右辺より大きいかを返す。
                name = $greater,
                pure fn greater(ctx, a: $ty, b: $ty) -> bool {
                    let _ = ctx;
                    Ok(a > b)
                }
            }
            builtin! {
                /// 左辺が右辺以上かを返す。
                name = $ge,
                pure fn greater_or_equal(ctx, a: $ty, b: $ty) -> bool {
                    let _ = ctx;
                    Ok(a >= b)
                }
            }
            builtin! {
                /// 補間と標準関数で共通の数の表記を返す。
                name = $string,
                pure fn to_string(ctx, n: $ty) -> Value<'e> {
                    ctx.alloc_str(&$format(n), $string)
                }
            }
        }
    };
}

fn integer_text(n: impl std::fmt::Display) -> String {
    n.to_string()
}

number!(
    integer8,
    i8,
    "%Integer8.less",
    "%Integer8.lessOrEqual",
    "%Integer8.greater",
    "%Integer8.greaterOrEqual",
    "Integer8.toString",
    integer_text
);
number!(
    integer16,
    i16,
    "%Integer16.less",
    "%Integer16.lessOrEqual",
    "%Integer16.greater",
    "%Integer16.greaterOrEqual",
    "Integer16.toString",
    integer_text
);
number!(
    integer32,
    i32,
    "%Integer32.less",
    "%Integer32.lessOrEqual",
    "%Integer32.greater",
    "%Integer32.greaterOrEqual",
    "Integer32.toString",
    integer_text
);
number!(
    unsigned16,
    u16,
    "%UnsignedInteger16.less",
    "%UnsignedInteger16.lessOrEqual",
    "%UnsignedInteger16.greater",
    "%UnsignedInteger16.greaterOrEqual",
    "UnsignedInteger16.toString",
    integer_text
);
number!(
    unsigned32,
    u32,
    "%UnsignedInteger32.less",
    "%UnsignedInteger32.lessOrEqual",
    "%UnsignedInteger32.greater",
    "%UnsignedInteger32.greaterOrEqual",
    "UnsignedInteger32.toString",
    integer_text
);
number!(
    unsigned64,
    u64,
    "%UnsignedInteger64.less",
    "%UnsignedInteger64.lessOrEqual",
    "%UnsignedInteger64.greater",
    "%UnsignedInteger64.greaterOrEqual",
    "UnsignedInteger64.toString",
    integer_text
);
number!(
    float32,
    f32,
    "%Float32.less",
    "%Float32.lessOrEqual",
    "%Float32.greater",
    "%Float32.greaterOrEqual",
    "Float32.toString",
    crate::base::prim::float32_to_text
);

/// 既存の関数の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    integer8::less::DECL,
    integer8::less_or_equal::DECL,
    integer8::greater::DECL,
    integer8::greater_or_equal::DECL,
    integer8::to_string::DECL,
    integer16::less::DECL,
    integer16::less_or_equal::DECL,
    integer16::greater::DECL,
    integer16::greater_or_equal::DECL,
    integer16::to_string::DECL,
    integer32::less::DECL,
    integer32::less_or_equal::DECL,
    integer32::greater::DECL,
    integer32::greater_or_equal::DECL,
    integer32::to_string::DECL,
    unsigned16::less::DECL,
    unsigned16::less_or_equal::DECL,
    unsigned16::greater::DECL,
    unsigned16::greater_or_equal::DECL,
    unsigned16::to_string::DECL,
    unsigned32::less::DECL,
    unsigned32::less_or_equal::DECL,
    unsigned32::greater::DECL,
    unsigned32::greater_or_equal::DECL,
    unsigned32::to_string::DECL,
    unsigned64::less::DECL,
    unsigned64::less_or_equal::DECL,
    unsigned64::greater::DECL,
    unsigned64::greater_or_equal::DECL,
    unsigned64::to_string::DECL,
    float32::less::DECL,
    float32::less_or_equal::DECL,
    float32::greater::DECL,
    float32::greater_or_equal::DECL,
    float32::to_string::DECL,
];
