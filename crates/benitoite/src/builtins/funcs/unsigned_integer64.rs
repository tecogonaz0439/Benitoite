//! u64 の全域での変換と標準関数を、型付きの呼び出しで実行する。
//! （設計書 01-04「型の変換」、02-08「組み込みの関数の呼び出し」）。

use crate::base::Decimal;
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;
use crate::runtime::{RuntimeError, Stop};

builtin! {
    /// 負の Integer なら None を返す。
    name = "UnsignedInteger64.fromInteger",
    pure fn from_integer(ctx, n: i64) -> Value<'e> {
        super::option(&ctx, u64::try_from(n).ok().map(Value::UInt64))
    }
}

builtin! {
    /// Integer の範囲外なら None を返す。
    name = "UnsignedInteger64.toInteger",
    pure fn to_integer(ctx, n: u64) -> Value<'e> {
        super::option(&ctx, i64::try_from(n).ok().map(Value::Int))
    }
}

builtin! {
    /// 負号のない十進の整数を読み、範囲外なら None を返す。
    name = "UnsignedInteger64.parse",
    pure fn parse(ctx, s: &'c str) -> Value<'e> {
        let parsed = super::decimal_integer(s).then(|| s.parse::<u64>().ok()).flatten();
        super::option(&ctx, parsed.map(Value::UInt64))
    }
}

builtin! {
    /// binary64 の精度に丸めて Float を返す。
    name = "UnsignedInteger64.toFloat",
    pure fn to_float(ctx, n: u64) -> f64 {
        let _ = ctx;
        // u64 の全範囲は f64 の有限範囲に収まる。整数の精度は丸められる。
        // `as` は binary64 の最近接値への丸めのために使う（設計書 01-04「型の変換」）。
        Ok(n as f64)
    }
}

builtin! {
    /// Decimal へ全域で正確に変換する。
    name = "UnsignedInteger64.toDecimal",
    pure fn to_decimal(ctx, n: u64) -> Value<'e> {
        // u64 は Decimal の 96 bit の仮数部に全域で収まる。
        let decimal = Decimal::new(i128::from(n), 0)
            .ok_or_else(|| Stop::Internal("u64 does not fit Decimal".into()))?;
        Ok(ctx.alloc_decimal(decimal))
    }
}

builtin! {
    /// 数学的に整数であり u64 に収まる Decimal だけを変換する。
    name = "UnsignedInteger64.fromDecimal",
    pure fn from_decimal(ctx, x: Value<'e>) -> Value<'e> {
        let decimal = super::decimal::operand(&ctx, x)?;
        let divisor = 10_i128.checked_pow(u32::from(decimal.scale()))
            .ok_or_else(|| Stop::Internal("Decimal scale exceeds i128 precision".into()))?;
        // 丸めてから縮小すると端数も受理してしまうため、先に剰余を確かめる。
        let mantissa = decimal.mantissa();
        let remainder = mantissa.checked_rem(divisor)
            .ok_or_else(|| Stop::Internal("invalid Decimal divisor".into()))?;
        let integral = mantissa.checked_div(divisor)
            .ok_or_else(|| Stop::Internal("invalid Decimal divisor".into()))?;
        let parsed = (remainder == 0).then(|| u64::try_from(integral).ok()).flatten();
        super::option(&ctx, parsed.map(Value::UInt64))
    }
}

builtin! {
    /// 符号なしの絶対値は元の値を返す。
    name = "UnsignedInteger64.absolute",
    pure fn absolute(ctx, n: u64) -> u64 {
        let _ = ctx;
        Ok(n)
    }
}

builtin! {
    /// 小さい方を返す。
    name = "UnsignedInteger64.minimum",
    pure fn minimum(ctx, a: u64, b: u64) -> u64 {
        let _ = ctx;
        Ok(a.min(b))
    }
}

builtin! {
    /// 大きい方を返す。
    name = "UnsignedInteger64.maximum",
    pure fn maximum(ctx, a: u64, b: u64) -> u64 {
        let _ = ctx;
        Ok(a.max(b))
    }
}

builtin! {
    /// 床へ切り捨てた商を返し、除数が 0 なら停止する。
    name = "UnsignedInteger64.floorDivide",
    pure fn floor_divide(ctx, a: u64, b: u64) -> u64 {
        let _ = ctx;
        a.checked_div(b).ok_or(Stop::Runtime(RuntimeError::DivisionByZero))
    }
}

builtin! {
    /// 剰余を返し、除数が 0 なら停止する。
    name = "UnsignedInteger64.floorModulo",
    pure fn floor_modulo(ctx, a: u64, b: u64) -> u64 {
        let _ = ctx;
        a.checked_rem(b).ok_or(Stop::Runtime(RuntimeError::DivisionByZero))
    }
}

/// 既存の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    from_integer::DECL,
    to_integer::DECL,
    parse::DECL,
    to_float::DECL,
    to_decimal::DECL,
    from_decimal::DECL,
    absolute::DECL,
    minimum::DECL,
    maximum::DECL,
    floor_divide::DECL,
    floor_modulo::DECL,
];
