//! Byte の変換とビット演算（設計書 01-04「Byte（初回リリース版）」「ビット演算（初回リリース版）」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

builtin! {
    /// `Byte.fromInteger` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.fromInteger",
    pure fn from_integer(ctx, n: i64) -> Value<'e> {
        super::option(&ctx, u8::try_from(n).ok().map(Value::Byte))
    }
}

builtin! {
    /// `Byte.toInteger` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.toInteger",
    pure fn to_integer(ctx, b: u8) -> i64 {
        let _ = ctx;
        Ok(i64::from(b))
    }
}

builtin! {
    /// `Byte.toString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.toString",
    pure fn to_string(ctx, b: u8) -> Value<'e> {
        ctx.alloc_str(&b.to_string(), "Byte.toString")
    }
}

builtin! {
    /// `Byte.bitwiseAnd` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.bitwiseAnd",
    pure fn bitwise_and(ctx, a: u8, b: u8) -> u8 {
        let _ = ctx;
        Ok(a & b)
    }
}

builtin! {
    /// `Byte.bitwiseOr` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.bitwiseOr",
    pure fn bitwise_or(ctx, a: u8, b: u8) -> u8 {
        let _ = ctx;
        Ok(a | b)
    }
}

builtin! {
    /// `Byte.bitwiseExclusiveOr` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.bitwiseExclusiveOr",
    pure fn bitwise_exclusive_or(ctx, a: u8, b: u8) -> u8 {
        let _ = ctx;
        Ok(a ^ b)
    }
}

builtin! {
    /// `Byte.bitwiseNot` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.bitwiseNot",
    pure fn bitwise_not(ctx, a: u8) -> u8 {
        let _ = ctx;
        Ok(!a)
    }
}

builtin! {
    /// `Byte.shiftLeft` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.shiftLeft",
    pure fn shift_left(ctx, a: u8, n: i64) -> u8 {
        let _ = ctx;
        let amount = super::integer::shift_amount(n, 7, "Byte.shiftLeft")?;
        Ok(a << amount)
    }
}

builtin! {
    /// `Byte.shiftRight` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Byte.shiftRight",
    pure fn shift_right(ctx, a: u8, n: i64) -> u8 {
        let _ = ctx;
        let amount = super::integer::shift_amount(n, 7, "Byte.shiftRight")?;
        Ok(a >> amount)
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    from_integer::DECL,
    to_integer::DECL,
    to_string::DECL,
    bitwise_and::DECL,
    bitwise_or::DECL,
    bitwise_exclusive_or::DECL,
    bitwise_not::DECL,
    shift_left::DECL,
    shift_right::DECL,
];

#[cfg(test)]
mod tests {
    // 関門: Byte の範囲、8 bit の切り捨て、10 進表記と停止理由を守る。
    // 既存の Integer のテストには幅の違いがなく、公開の口も加えない（R35、10-12）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::builtins::funcs::operators::tests::{direct, payload};
    use crate::runtime::heap::{Heap, HeapConfig};
    use crate::runtime::{RuntimeError, Stop};

    type Binary = for<'c, 'e> fn(
        crate::builtins::iface::PureCtx<'c, 'e>,
        u8,
        u8,
    ) -> Result<u8, crate::runtime::Stop>;
    type Shift = for<'c, 'e> fn(
        crate::builtins::iface::PureCtx<'c, 'e>,
        u8,
        i64,
    ) -> Result<u8, crate::runtime::Stop>;

    #[test]
    fn conversions_bitwise_functions_and_shift_boundaries() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (n, expected) in [
                (-1, None),
                (0, Some(0)),
                (255, Some(255)),
                (256, None),
                (i64::MAX, None),
            ] {
                assert_eq!(
                    payload(direct!(ctx, from_integer, n).unwrap(), ctx)
                        .map(|v| v.as_byte().unwrap()),
                    expected
                );
            }
            for b in [0, 1, 255] {
                assert_eq!(direct!(ctx, to_integer, b).unwrap(), i64::from(b));
                let text = direct!(ctx, to_string, b).unwrap();
                assert_eq!(ctx.str(text).unwrap(), b.to_string());
            }
            for (function, expected) in [
                (bitwise_and as Binary, 8),
                (bitwise_or, 14),
                (bitwise_exclusive_or, 6),
            ] {
                assert_eq!(direct!(ctx, function, 12, 10).unwrap(), expected);
            }
            assert_eq!(direct!(ctx, bitwise_not, 0).unwrap(), 255);
            assert_eq!(direct!(ctx, bitwise_not, 255).unwrap(), 0);
            for (function, name, last) in [
                (shift_left as Shift, "Byte.shiftLeft", 128),
                (shift_right, "Byte.shiftRight", 1),
            ] {
                assert_eq!(direct!(ctx, function, 255, 0).unwrap(), 255);
                assert_eq!(direct!(ctx, function, 255, 7).unwrap(), last);
                for n in [-1, 8, 63, 64, i64::MAX] {
                    assert_eq!(
                        direct!(ctx, function, 1, n),
                        Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                            function: name,
                            argument: 1
                        }))
                    );
                }
            }
            assert_eq!(direct!(ctx, shift_left, 128, 1).unwrap(), 0);
        });
    }
}
