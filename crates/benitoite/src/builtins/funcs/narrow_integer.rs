//! 狭い整数の明示的な変換と標準関数を、型付きの呼び出しで実行する。
//! （設計書 01-04「型の変換」、02-08「組み込みの関数の呼び出し」、03-06「Integer」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;
use crate::runtime::{RuntimeError, Stop};

// 最小値の剰余は 0 だが、商と絶対値はあふれとして報告する。
// 床への補正も同じ幅で行い、算術の失敗を変換の None と区別する。
macro_rules! signed {
    ($ty:ty) => {
        fn absolute_value(n: $ty) -> Result<$ty, Stop> {
            n.checked_abs()
                .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
        }
        fn floor_divide_value(a: $ty, b: $ty) -> Result<$ty, Stop> {
            if b == 0 {
                return Err(Stop::Runtime(RuntimeError::DivisionByZero));
            }
            let q = a
                .checked_div(b)
                .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))?;
            let r = a.checked_rem(b).unwrap_or(0);
            if r != 0 && ((a < 0) != (b < 0)) {
                q.checked_sub(1)
                    .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
            } else {
                Ok(q)
            }
        }
        fn floor_modulo_value(a: $ty, b: $ty) -> Result<$ty, Stop> {
            if b == 0 {
                return Err(Stop::Runtime(RuntimeError::DivisionByZero));
            }
            let r = a.checked_rem(b).unwrap_or(0);
            if r != 0 && ((r < 0) != (b < 0)) {
                r.checked_add(b)
                    .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
            } else {
                Ok(r)
            }
        }
    };
}

// 符号なしでは床への補正がなく、絶対値も元の値である。
macro_rules! unsigned {
    ($ty:ty) => {
        fn absolute_value(n: $ty) -> Result<$ty, Stop> {
            Ok(n)
        }
        fn floor_divide_value(a: $ty, b: $ty) -> Result<$ty, Stop> {
            a.checked_div(b)
                .ok_or(Stop::Runtime(RuntimeError::DivisionByZero))
        }
        fn floor_modulo_value(a: $ty, b: $ty) -> Result<$ty, Stop> {
            a.checked_rem(b)
                .ok_or(Stop::Runtime(RuntimeError::DivisionByZero))
        }
    };
}

// 各型の読み書きを宣言のマクロに任せ、旧型の呼び出しの共通部を保つ。
macro_rules! narrow_integer {
    ($module:ident, $ty:ty, $value:ident, $behavior:ident, $signed:literal,
     $from:literal, $to:literal, $parse:literal, $float:literal, $abs:literal,
     $min:literal, $max:literal, $div:literal, $mod:literal) => {
        mod $module {
            use super::*;
            $behavior!($ty);

            builtin! {
                /// Integer から縮小し、範囲外なら None を返す。
                name = $from,
                pure fn from_integer(ctx, n: i64) -> Value<'e> {
                    super::super::option(&ctx, <$ty>::try_from(n).ok().map(Value::$value))
                }
            }
            builtin! {
                /// Integer へ全域で正確に拡大する。
                name = $to,
                pure fn to_integer(ctx, n: $ty) -> i64 {
                    let _ = ctx;
                    Ok(i64::from(n))
                }
            }
            builtin! {
                /// Integer と同じ十進の字句を読み、範囲外なら None を返す。
                name = $parse,
                pure fn parse(ctx, s: &'c str) -> Value<'e> {
                    let digits = if $signed { s.strip_prefix('-').unwrap_or(s) } else { s };
                    let parsed = super::super::decimal_integer(digits)
                        .then(|| s.parse::<$ty>().ok()).flatten();
                    super::super::option(&ctx, parsed.map(Value::$value))
                }
            }
            builtin! {
                /// Float へ拡大する。
                name = $float,
                pure fn to_float(ctx, n: $ty) -> f64 {
                    let _ = ctx;
                    // 対象の全整数は binary64 の仮数部に収まり、正確に変換できる。
                    Ok(f64::from(n))
                }
            }
            builtin! {
                /// 絶対値を返し、符号付きの最小値なら停止する。
                name = $abs,
                pure fn absolute(ctx, n: $ty) -> $ty {
                    let _ = ctx;
                    absolute_value(n)
                }
            }
            builtin! {
                /// 小さい方を返す。
                name = $min,
                pure fn minimum(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    Ok(a.min(b))
                }
            }
            builtin! {
                /// 大きい方を返す。
                name = $max,
                pure fn maximum(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    Ok(a.max(b))
                }
            }
            builtin! {
                /// 負の無限大へ切り捨てた商を返す。
                name = $div,
                pure fn floor_divide(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    floor_divide_value(a, b)
                }
            }
            builtin! {
                /// 除数と同符号か 0 の剰余を返す。
                name = $mod,
                pure fn floor_modulo(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    floor_modulo_value(a, b)
                }
            }
        }
    };
}

narrow_integer!(
    integer8,
    i8,
    Int8,
    signed,
    true,
    "Integer8.fromInteger",
    "Integer8.toInteger",
    "Integer8.parse",
    "Integer8.toFloat",
    "Integer8.absolute",
    "Integer8.minimum",
    "Integer8.maximum",
    "Integer8.floorDivide",
    "Integer8.floorModulo"
);
narrow_integer!(
    integer16,
    i16,
    Int16,
    signed,
    true,
    "Integer16.fromInteger",
    "Integer16.toInteger",
    "Integer16.parse",
    "Integer16.toFloat",
    "Integer16.absolute",
    "Integer16.minimum",
    "Integer16.maximum",
    "Integer16.floorDivide",
    "Integer16.floorModulo"
);
narrow_integer!(
    integer32,
    i32,
    Int32,
    signed,
    true,
    "Integer32.fromInteger",
    "Integer32.toInteger",
    "Integer32.parse",
    "Integer32.toFloat",
    "Integer32.absolute",
    "Integer32.minimum",
    "Integer32.maximum",
    "Integer32.floorDivide",
    "Integer32.floorModulo"
);
narrow_integer!(
    unsigned16,
    u16,
    UInt16,
    unsigned,
    false,
    "UnsignedInteger16.fromInteger",
    "UnsignedInteger16.toInteger",
    "UnsignedInteger16.parse",
    "UnsignedInteger16.toFloat",
    "UnsignedInteger16.absolute",
    "UnsignedInteger16.minimum",
    "UnsignedInteger16.maximum",
    "UnsignedInteger16.floorDivide",
    "UnsignedInteger16.floorModulo"
);
narrow_integer!(
    unsigned32,
    u32,
    UInt32,
    unsigned,
    false,
    "UnsignedInteger32.fromInteger",
    "UnsignedInteger32.toInteger",
    "UnsignedInteger32.parse",
    "UnsignedInteger32.toFloat",
    "UnsignedInteger32.absolute",
    "UnsignedInteger32.minimum",
    "UnsignedInteger32.maximum",
    "UnsignedInteger32.floorDivide",
    "UnsignedInteger32.floorModulo"
);

/// 既存の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    integer8::from_integer::DECL,
    integer8::to_integer::DECL,
    integer8::parse::DECL,
    integer8::to_float::DECL,
    integer8::absolute::DECL,
    integer8::minimum::DECL,
    integer8::maximum::DECL,
    integer8::floor_divide::DECL,
    integer8::floor_modulo::DECL,
    integer16::from_integer::DECL,
    integer16::to_integer::DECL,
    integer16::parse::DECL,
    integer16::to_float::DECL,
    integer16::absolute::DECL,
    integer16::minimum::DECL,
    integer16::maximum::DECL,
    integer16::floor_divide::DECL,
    integer16::floor_modulo::DECL,
    integer32::from_integer::DECL,
    integer32::to_integer::DECL,
    integer32::parse::DECL,
    integer32::to_float::DECL,
    integer32::absolute::DECL,
    integer32::minimum::DECL,
    integer32::maximum::DECL,
    integer32::floor_divide::DECL,
    integer32::floor_modulo::DECL,
    unsigned16::from_integer::DECL,
    unsigned16::to_integer::DECL,
    unsigned16::parse::DECL,
    unsigned16::to_float::DECL,
    unsigned16::absolute::DECL,
    unsigned16::minimum::DECL,
    unsigned16::maximum::DECL,
    unsigned16::floor_divide::DECL,
    unsigned16::floor_modulo::DECL,
    unsigned32::from_integer::DECL,
    unsigned32::to_integer::DECL,
    unsigned32::parse::DECL,
    unsigned32::to_float::DECL,
    unsigned32::absolute::DECL,
    unsigned32::minimum::DECL,
    unsigned32::maximum::DECL,
    unsigned32::floor_divide::DECL,
    unsigned32::floor_modulo::DECL,
];
