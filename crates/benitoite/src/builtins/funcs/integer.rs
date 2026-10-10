//! 整数の変換と演算（設計書 01-04「Integer」「型の変換」、03-06「Integer」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::RuntimeError;
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// `Integer.toString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.toString",
    pure fn to_string(ctx, n: i64) -> Value<'e> {
        ctx.alloc_str(&n.to_string(), "Integer.toString")
    }
}

builtin! {
    /// `Integer.parse` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.parse",
    pure fn parse(ctx, s: &'c str) -> Value<'e> {
        let digits = s.strip_prefix('-').unwrap_or(s);
        let parsed = super::decimal_integer(digits)
            .then(|| s.parse::<i64>().ok())
            .flatten();
        super::option(&ctx, parsed.map(Value::Int))
    }
}

builtin! {
    /// `Integer.toFloat` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.toFloat",
    pure fn to_float(ctx, n: i64) -> f64 {
        let _ = ctx;
        // i64 の全範囲は f64 の有限範囲に収まる（設計書 01-04「型の変換」）。
        Ok(n as f64)
    }
}

builtin! {
    /// `Integer.floorDivide` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.floorDivide",
    pure fn floor_divide(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        let q = super::operators::int_divide(a, b)?;
        let r = super::operators::int_modulo(a, b)?;
        if r != 0 && ((a < 0) != (b < 0)) {
            q.checked_sub(1)
                .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
        } else {
            Ok(q)
        }
    }
}

builtin! {
    /// `Integer.floorModulo` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.floorModulo",
    pure fn floor_modulo(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        let r = super::operators::int_modulo(a, b)?;
        if r != 0 && ((r < 0) != (b < 0)) {
            r.checked_add(b)
                .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
        } else {
            Ok(r)
        }
    }
}

builtin! {
    /// `Integer.absolute` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.absolute",
    pure fn absolute(ctx, n: i64) -> i64 {
        let _ = ctx;
        n.checked_abs()
            .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}

builtin! {
    /// `Integer.minimum` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.minimum",
    pure fn minimum(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        Ok(a.min(b))
    }
}

builtin! {
    /// `Integer.maximum` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.maximum",
    pure fn maximum(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        Ok(a.max(b))
    }
}

builtin! {
    /// `Integer.bitwiseAnd` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.bitwiseAnd",
    pure fn bitwise_and(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        Ok(a & b)
    }
}

builtin! {
    /// `Integer.bitwiseOr` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.bitwiseOr",
    pure fn bitwise_or(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        Ok(a | b)
    }
}

builtin! {
    /// `Integer.bitwiseExclusiveOr` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.bitwiseExclusiveOr",
    pure fn bitwise_exclusive_or(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        Ok(a ^ b)
    }
}

builtin! {
    /// `Integer.bitwiseNot` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.bitwiseNot",
    pure fn bitwise_not(ctx, a: i64) -> i64 {
        let _ = ctx;
        Ok(!a)
    }
}

builtin! {
    /// `Integer.shiftLeft` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.shiftLeft",
    pure fn shift_left(ctx, a: i64, n: i64) -> i64 {
        let _ = ctx;
        let amount = super::integer::shift_amount(n, 63, "Integer.shiftLeft")?;
        Ok(a << amount)
    }
}

builtin! {
    /// `Integer.shiftRight` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.shiftRight",
    pure fn shift_right(ctx, a: i64, n: i64) -> i64 {
        let _ = ctx;
        let amount = super::integer::shift_amount(n, 63, "Integer.shiftRight")?;
        Ok(a >> amount)
    }
}

builtin! {
    /// `Integer.shiftRightUnsigned` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Integer.shiftRightUnsigned",
    pure fn shift_right_unsigned(ctx, a: i64, n: i64) -> i64 {
        let _ = ctx;
        let amount = super::integer::shift_amount(n, 63, "Integer.shiftRightUnsigned")?;
        Ok(i64::from_ne_bytes((u64::from_ne_bytes(a.to_ne_bytes()) >> amount).to_ne_bytes()))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    to_string::DECL,
    parse::DECL,
    to_float::DECL,
    floor_divide::DECL,
    floor_modulo::DECL,
    absolute::DECL,
    minimum::DECL,
    maximum::DECL,
    bitwise_and::DECL,
    bitwise_or::DECL,
    bitwise_exclusive_or::DECL,
    bitwise_not::DECL,
    shift_left::DECL,
    shift_right::DECL,
    shift_right_unsigned::DECL,
];

// シフトの量は値の幅で検査し、引数の位置は 0 から数える（設計書 01-04「ビット演算（初回リリース版）」）。
pub(super) fn shift_amount(n: i64, maximum: u32, function: &'static str) -> Result<u32, Stop> {
    u32::try_from(n)
        .ok()
        .filter(|n| *n <= maximum)
        .ok_or(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
            function,
            argument: 1,
        }))
}

#[cfg(test)]
mod tests {
    // 関門: 各ビット演算の向き、符号の補充、無効な量の停止を守る。既存の算術の
    // テストはこれらの関数を呼ばず、差し込み口も加えない（実装プラン R35、10-12）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::runtime::heap::{Heap, HeapConfig};

    type Binary = for<'c, 'e> fn(
        crate::builtins::iface::PureCtx<'c, 'e>,
        i64,
        i64,
    ) -> Result<i64, crate::runtime::Stop>;
    type Shift = for<'c, 'e> fn(
        crate::builtins::iface::PureCtx<'c, 'e>,
        i64,
        i64,
    ) -> Result<i64, crate::runtime::Stop>;

    #[test]
    fn bitwise_functions_and_shift_boundaries() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (function, expected) in [
                (bitwise_and as Binary, 8),
                (bitwise_or, 14),
                (bitwise_exclusive_or, 6),
            ] {
                assert_eq!(direct!(ctx, function, 12, 10).unwrap(), expected);
            }
            assert_eq!(direct!(ctx, bitwise_not, 0).unwrap(), -1);
            assert_eq!(direct!(ctx, bitwise_not, i64::MIN).unwrap(), i64::MAX);
            for (function, name, last) in [
                (shift_left as Shift, "Integer.shiftLeft", i64::MIN),
                (shift_right, "Integer.shiftRight", -1),
                (shift_right_unsigned, "Integer.shiftRightUnsigned", 1),
            ] {
                assert_eq!(direct!(ctx, function, -1, 0).unwrap(), -1);
                assert_eq!(direct!(ctx, function, -1, 63).unwrap(), last);
                for n in [-1, 64, i64::MIN, i64::MAX] {
                    assert_eq!(
                        direct!(ctx, function, 1, n),
                        Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                            function: name,
                            argument: 1
                        }))
                    );
                }
            }
            assert_eq!(direct!(ctx, shift_left, i64::MIN, 1).unwrap(), 0);
            assert_eq!(direct!(ctx, shift_right, -8, 1).unwrap(), -4);
            assert_eq!(
                direct!(ctx, shift_right_unsigned, -8, 1).unwrap(),
                9223372036854775804
            );
        });
    }
}
