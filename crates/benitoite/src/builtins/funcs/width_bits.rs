//! 幅の決まった整数のビット演算とシフトを実行する
//! （設計書 02-08「組み込みの関数の呼び出し」）。

use crate::builtins::iface::{BuiltinDecl, builtin};

// 算術のあふれとは区別し、左シフトで幅から出たビットは捨てる。
// シフト量は先に検査し、Rust のシフトの失敗を言語の停止へ変える。
macro_rules! integer_bits {
    ($module:ident, $ty:ty, $and:literal, $or:literal, $xor:literal,
     $not:literal, $left:literal, $right:literal) => {
        mod $module {
            use super::*;

            builtin! {
                /// ビットごとの積を返す。
                name = $and,
                pure fn bitwise_and(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    Ok(a & b)
                }
            }
            builtin! {
                /// ビットごとの和を返す。
                name = $or,
                pure fn bitwise_or(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    Ok(a | b)
                }
            }
            builtin! {
                /// ビットごとの排他的論理和を返す。
                name = $xor,
                pure fn bitwise_exclusive_or(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    Ok(a ^ b)
                }
            }
            builtin! {
                /// 幅の中の全ビットを反転する。
                name = $not,
                pure fn bitwise_not(ctx, a: $ty) -> $ty {
                    let _ = ctx;
                    Ok(!a)
                }
            }
            builtin! {
                /// 幅から出たビットを捨て、低位へ零を入れる。
                name = $left,
                pure fn shift_left(ctx, a: $ty, n: i64) -> $ty {
                    let _ = ctx;
                    let amount = super::super::integer::shift_amount(
                        n, <$ty>::BITS.saturating_sub(1), $left,
                    )?;
                    Ok(a << amount)
                }
            }
            builtin! {
                /// 符号付きなら符号ビット、符号なしなら零を高位へ入れる。
                name = $right,
                pure fn shift_right(ctx, a: $ty, n: i64) -> $ty {
                    let _ = ctx;
                    let amount = super::super::integer::shift_amount(
                        n, <$ty>::BITS.saturating_sub(1), $right,
                    )?;
                    Ok(a >> amount)
                }
            }
        }
    };
}

// 同じ幅の符号なし整数としてビット列を読み直し、数値の縮小変換を避ける。
macro_rules! unsigned_shift {
    ($module:ident, $signed:ty, $unsigned:ty, $name:literal) => {
        mod $module {
            use super::*;

            builtin! {
                /// 高位へ零を入れる右シフトを返す。
                name = $name,
                pure fn shift_right_unsigned(ctx, a: $signed, n: i64) -> $signed {
                    let _ = ctx;
                    let amount = super::super::integer::shift_amount(
                        n, <$signed>::BITS.saturating_sub(1),
                        $name,
                    )?;
                    let bits = <$unsigned>::from_ne_bytes(a.to_ne_bytes()) >> amount;
                    Ok(<$signed>::from_ne_bytes(bits.to_ne_bytes()))
                }
            }
        }
    };
}

integer_bits!(
    integer8,
    i8,
    "Integer8.bitwiseAnd",
    "Integer8.bitwiseOr",
    "Integer8.bitwiseExclusiveOr",
    "Integer8.bitwiseNot",
    "Integer8.shiftLeft",
    "Integer8.shiftRight"
);
integer_bits!(
    integer16,
    i16,
    "Integer16.bitwiseAnd",
    "Integer16.bitwiseOr",
    "Integer16.bitwiseExclusiveOr",
    "Integer16.bitwiseNot",
    "Integer16.shiftLeft",
    "Integer16.shiftRight"
);
integer_bits!(
    integer32,
    i32,
    "Integer32.bitwiseAnd",
    "Integer32.bitwiseOr",
    "Integer32.bitwiseExclusiveOr",
    "Integer32.bitwiseNot",
    "Integer32.shiftLeft",
    "Integer32.shiftRight"
);
integer_bits!(
    unsigned16,
    u16,
    "UnsignedInteger16.bitwiseAnd",
    "UnsignedInteger16.bitwiseOr",
    "UnsignedInteger16.bitwiseExclusiveOr",
    "UnsignedInteger16.bitwiseNot",
    "UnsignedInteger16.shiftLeft",
    "UnsignedInteger16.shiftRight"
);
integer_bits!(
    unsigned32,
    u32,
    "UnsignedInteger32.bitwiseAnd",
    "UnsignedInteger32.bitwiseOr",
    "UnsignedInteger32.bitwiseExclusiveOr",
    "UnsignedInteger32.bitwiseNot",
    "UnsignedInteger32.shiftLeft",
    "UnsignedInteger32.shiftRight"
);
integer_bits!(
    unsigned64,
    u64,
    "UnsignedInteger64.bitwiseAnd",
    "UnsignedInteger64.bitwiseOr",
    "UnsignedInteger64.bitwiseExclusiveOr",
    "UnsignedInteger64.bitwiseNot",
    "UnsignedInteger64.shiftLeft",
    "UnsignedInteger64.shiftRight"
);
unsigned_shift!(integer8_unsigned, i8, u8, "Integer8.shiftRightUnsigned");
unsigned_shift!(integer16_unsigned, i16, u16, "Integer16.shiftRightUnsigned");
unsigned_shift!(integer32_unsigned, i32, u32, "Integer32.shiftRightUnsigned");

/// 既存の組み込みの番号を保つため、登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    integer8::bitwise_and::DECL,
    integer8::bitwise_or::DECL,
    integer8::bitwise_exclusive_or::DECL,
    integer8::bitwise_not::DECL,
    integer8::shift_left::DECL,
    integer8::shift_right::DECL,
    integer8_unsigned::shift_right_unsigned::DECL,
    integer16::bitwise_and::DECL,
    integer16::bitwise_or::DECL,
    integer16::bitwise_exclusive_or::DECL,
    integer16::bitwise_not::DECL,
    integer16::shift_left::DECL,
    integer16::shift_right::DECL,
    integer16_unsigned::shift_right_unsigned::DECL,
    integer32::bitwise_and::DECL,
    integer32::bitwise_or::DECL,
    integer32::bitwise_exclusive_or::DECL,
    integer32::bitwise_not::DECL,
    integer32::shift_left::DECL,
    integer32::shift_right::DECL,
    integer32_unsigned::shift_right_unsigned::DECL,
    unsigned16::bitwise_and::DECL,
    unsigned16::bitwise_or::DECL,
    unsigned16::bitwise_exclusive_or::DECL,
    unsigned16::bitwise_not::DECL,
    unsigned16::shift_left::DECL,
    unsigned16::shift_right::DECL,
    unsigned32::bitwise_and::DECL,
    unsigned32::bitwise_or::DECL,
    unsigned32::bitwise_exclusive_or::DECL,
    unsigned32::bitwise_not::DECL,
    unsigned32::shift_left::DECL,
    unsigned32::shift_right::DECL,
    unsigned64::bitwise_and::DECL,
    unsigned64::bitwise_or::DECL,
    unsigned64::bitwise_exclusive_or::DECL,
    unsigned64::bitwise_not::DECL,
    unsigned64::shift_left::DECL,
    unsigned64::shift_right::DECL,
];

#[cfg(test)]
mod tests {
    // 作成時の関門: 全幅・全シフトの範囲外を、登録表の本番の入口で停止させる。
    // CLI の成功例では、負の量と幅以上の量の拒否・関数名・引数位置を確かめられない。
    // 値の生成や演算を置き換える差し込み口は加えない。
    #![allow(clippy::unwrap_used, clippy::expect_used)]

    use crate::builtins::table::{builtin_decl, call_builtin, lookup_builtin};
    use crate::runtime::heap::{Heap, HeapConfig, Value};
    use crate::runtime::{RuntimeError, Stop};

    #[test]
    fn shifts_reject_amounts_outside_each_width() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (name, value, width, signed) in [
                ("Integer8", Value::Int8(1), 8, true),
                ("Integer16", Value::Int16(1), 16, true),
                ("Integer32", Value::Int32(1), 32, true),
                ("UnsignedInteger16", Value::UInt16(1), 16, false),
                ("UnsignedInteger32", Value::UInt32(1), 32, false),
                ("UnsignedInteger64", Value::UInt64(1), 64, false),
            ] {
                for operation in ["shiftLeft", "shiftRight", "shiftRightUnsigned"] {
                    if operation == "shiftRightUnsigned" && !signed {
                        continue;
                    }
                    let function = format!("{name}.{operation}");
                    let decl = builtin_decl(lookup_builtin(&function).unwrap()).unwrap();
                    for amount in [-1, width, i64::MIN, i64::MAX] {
                        let result =
                            call_builtin(decl, ctx, None, None, None, &[value, Value::Int(amount)]);
                        assert!(
                            matches!(
                                result,
                                Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                                    function,
                                    argument: 1,
                                })) if function == decl.name
                            ),
                            "{function}({amount})"
                        );
                    }
                }
            }
        });
    }
}
