//! 基本型の演算子と構造の等しさ（設計書 01-04、01-06「等値の型」、実装プラン 10-12「演算子」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::RuntimeError;
use crate::runtime::Stop;
use crate::runtime::heap::Value;

builtin! {
    /// `%Integer.add` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.add",
    pure fn integer_add(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        a.checked_add(b)
            .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}

builtin! {
    /// `%Integer.subtract` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.subtract",
    pure fn integer_subtract(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        a.checked_sub(b)
            .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}

builtin! {
    /// `%Integer.multiply` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.multiply",
    pure fn integer_multiply(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        a.checked_mul(b)
            .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}

builtin! {
    /// `%Integer.div` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.div",
    pure fn integer_div(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        int_divide(a, b)
    }
}

builtin! {
    /// `%Integer.mod` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.mod",
    pure fn integer_mod(ctx, a: i64, b: i64) -> i64 {
        let _ = ctx;
        int_modulo(a, b)
    }
}

builtin! {
    /// `%Integer.negate` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.negate",
    pure fn integer_negate(ctx, a: i64) -> i64 {
        let _ = ctx;
        a.checked_neg()
            .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
    }
}

builtin! {
    /// `%Integer.less` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.less",
    pure fn integer_less(ctx, a: i64, b: i64) -> bool {
        let _ = ctx;
        Ok(a < b)
    }
}

builtin! {
    /// `%Integer.lessOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.lessOrEqual",
    pure fn integer_less_or_equal(ctx, a: i64, b: i64) -> bool {
        let _ = ctx;
        Ok(a <= b)
    }
}

builtin! {
    /// `%Integer.greater` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.greater",
    pure fn integer_greater(ctx, a: i64, b: i64) -> bool {
        let _ = ctx;
        Ok(a > b)
    }
}

builtin! {
    /// `%Integer.greaterOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Integer.greaterOrEqual",
    pure fn integer_greater_or_equal(ctx, a: i64, b: i64) -> bool {
        let _ = ctx;
        Ok(a >= b)
    }
}

builtin! {
    /// `%Float.add` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.add",
    pure fn float_add(ctx, a: f64, b: f64) -> f64 {
        let _ = ctx;
        Ok(std::ops::Add::add(a, b))
    }
}

builtin! {
    /// `%Float.subtract` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.subtract",
    pure fn float_subtract(ctx, a: f64, b: f64) -> f64 {
        let _ = ctx;
        Ok(std::ops::Sub::sub(a, b))
    }
}

builtin! {
    /// `%Float.multiply` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.multiply",
    pure fn float_multiply(ctx, a: f64, b: f64) -> f64 {
        let _ = ctx;
        Ok(std::ops::Mul::mul(a, b))
    }
}

builtin! {
    /// `%Float.divide` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.divide",
    pure fn float_divide(ctx, a: f64, b: f64) -> f64 {
        let _ = ctx;
        Ok(std::ops::Div::div(a, b))
    }
}

builtin! {
    /// `%Float.negate` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.negate",
    pure fn float_negate(ctx, a: f64) -> f64 {
        let _ = ctx;
        Ok(-a)
    }
}

builtin! {
    /// `%Float.less` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.less",
    pure fn float_less(ctx, a: f64, b: f64) -> bool {
        let _ = ctx;
        Ok(a < b)
    }
}

builtin! {
    /// `%Float.lessOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.lessOrEqual",
    pure fn float_less_or_equal(ctx, a: f64, b: f64) -> bool {
        let _ = ctx;
        Ok(a <= b)
    }
}

builtin! {
    /// `%Float.greater` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.greater",
    pure fn float_greater(ctx, a: f64, b: f64) -> bool {
        let _ = ctx;
        Ok(a > b)
    }
}

builtin! {
    /// `%Float.greaterOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Float.greaterOrEqual",
    pure fn float_greater_or_equal(ctx, a: f64, b: f64) -> bool {
        let _ = ctx;
        Ok(a >= b)
    }
}

builtin! {
    /// `%Decimal.add` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.add",
    pure fn decimal_add(ctx, a: Value<'e>, b: Value<'e>) -> Value<'e> {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        let result = a.checked_add(b).map_err(decimal_error)?;
        Ok(ctx.alloc_decimal(result))
    }
}

builtin! {
    /// `%Decimal.subtract` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.subtract",
    pure fn decimal_subtract(ctx, a: Value<'e>, b: Value<'e>) -> Value<'e> {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        let result = a.checked_sub(b).map_err(decimal_error)?;
        Ok(ctx.alloc_decimal(result))
    }
}

builtin! {
    /// `%Decimal.multiply` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.multiply",
    pure fn decimal_multiply(ctx, a: Value<'e>, b: Value<'e>) -> Value<'e> {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        let result = a.checked_mul(b).map_err(decimal_error)?;
        Ok(ctx.alloc_decimal(result))
    }
}

builtin! {
    /// `%Decimal.divide` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.divide",
    pure fn decimal_divide(ctx, a: Value<'e>, b: Value<'e>) -> Value<'e> {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        let result = a.checked_div(b).map_err(decimal_error)?;
        Ok(ctx.alloc_decimal(result))
    }
}

builtin! {
    /// `%Decimal.negate` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.negate",
    pure fn decimal_negate(ctx, a: Value<'e>) -> Value<'e> {
        Ok(ctx.alloc_decimal(super::decimal::operand(&ctx, a)?.negate()))
    }
}

builtin! {
    /// `%Decimal.less` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.less",
    pure fn decimal_less(ctx, a: Value<'e>, b: Value<'e>) -> bool {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        Ok(a.cmp_num(b).is_lt())
    }
}

builtin! {
    /// `%Decimal.lessOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.lessOrEqual",
    pure fn decimal_less_or_equal(ctx, a: Value<'e>, b: Value<'e>) -> bool {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        Ok(a.cmp_num(b).is_le())
    }
}

builtin! {
    /// `%Decimal.greater` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.greater",
    pure fn decimal_greater(ctx, a: Value<'e>, b: Value<'e>) -> bool {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        Ok(a.cmp_num(b).is_gt())
    }
}

builtin! {
    /// `%Decimal.greaterOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Decimal.greaterOrEqual",
    pure fn decimal_greater_or_equal(ctx, a: Value<'e>, b: Value<'e>) -> bool {
        let a = super::decimal::operand(&ctx, a)?;
        let b = super::decimal::operand(&ctx, b)?;
        Ok(a.cmp_num(b).is_ge())
    }
}

builtin! {
    /// `%String.add` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%String.add",
    pure fn string_add(ctx, a: &'c str, b: &'c str) -> Value<'e> {
        ctx.alloc_str_parts(&[a, b], "+")
    }
}

builtin! {
    /// `%String.less` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%String.less",
    pure fn string_less(ctx, a: &'c str, b: &'c str) -> bool {
        let _ = ctx;
        Ok(a < b)
    }
}

builtin! {
    /// `%String.lessOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%String.lessOrEqual",
    pure fn string_less_or_equal(ctx, a: &'c str, b: &'c str) -> bool {
        let _ = ctx;
        Ok(a <= b)
    }
}

builtin! {
    /// `%String.greater` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%String.greater",
    pure fn string_greater(ctx, a: &'c str, b: &'c str) -> bool {
        let _ = ctx;
        Ok(a > b)
    }
}

builtin! {
    /// `%String.greaterOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%String.greaterOrEqual",
    pure fn string_greater_or_equal(ctx, a: &'c str, b: &'c str) -> bool {
        let _ = ctx;
        Ok(a >= b)
    }
}

builtin! {
    /// `%Character.less` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Character.less",
    pure fn character_less(ctx, a: char, b: char) -> bool {
        let _ = ctx;
        Ok(a < b)
    }
}

builtin! {
    /// `%Character.lessOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Character.lessOrEqual",
    pure fn character_less_or_equal(ctx, a: char, b: char) -> bool {
        let _ = ctx;
        Ok(a <= b)
    }
}

builtin! {
    /// `%Character.greater` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Character.greater",
    pure fn character_greater(ctx, a: char, b: char) -> bool {
        let _ = ctx;
        Ok(a > b)
    }
}

builtin! {
    /// `%Character.greaterOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Character.greaterOrEqual",
    pure fn character_greater_or_equal(ctx, a: char, b: char) -> bool {
        let _ = ctx;
        Ok(a >= b)
    }
}

builtin! {
    /// `%Byte.less` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Byte.less",
    pure fn byte_less(ctx, a: u8, b: u8) -> bool {
        let _ = ctx;
        Ok(a.cmp(&b).is_lt())
    }
}

builtin! {
    /// `%Byte.lessOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Byte.lessOrEqual",
    pure fn byte_less_or_equal(ctx, a: u8, b: u8) -> bool {
        let _ = ctx;
        Ok(a.cmp(&b).is_le())
    }
}

builtin! {
    /// `%Byte.greater` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Byte.greater",
    pure fn byte_greater(ctx, a: u8, b: u8) -> bool {
        let _ = ctx;
        Ok(a.cmp(&b).is_gt())
    }
}

builtin! {
    /// `%Byte.greaterOrEqual` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%Byte.greaterOrEqual",
    pure fn byte_greater_or_equal(ctx, a: u8, b: u8) -> bool {
        let _ = ctx;
        Ok(a.cmp(&b).is_ge())
    }
}

builtin! {
    /// `%eq` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%eq",
    pure fn eq(ctx, a: Value<'e>, b: Value<'e>) -> bool {
        crate::runtime::equal::values_equal(&ctx, a, b)
    }
}

builtin! {
    /// `%ne` の本体（実装プラン 10-12「項目の一覧」）。
    name = "%ne",
    pure fn ne(ctx, a: Value<'e>, b: Value<'e>) -> bool {
        Ok(!crate::runtime::equal::values_equal(&ctx, a, b)?)
    }
}

/// 整数の商。VM の DIVI と参照インタプリタで規則を揃える（設計書 01-04「Integer」）。
pub(crate) fn int_divide(a: i64, b: i64) -> Result<i64, Stop> {
    if b == 0 {
        return Err(Stop::Runtime(RuntimeError::DivisionByZero));
    }
    a.checked_div(b)
        .ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
}

/// 商が表せない MIN mod -1 も剰余は 0 になる（設計書 01-04「Integer」）。
pub(crate) fn int_modulo(a: i64, b: i64) -> Result<i64, Stop> {
    if b == 0 {
        return Err(Stop::Runtime(RuntimeError::DivisionByZero));
    }
    Ok(a.checked_rem(b).unwrap_or(0))
}
/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    integer_add::DECL,
    integer_subtract::DECL,
    integer_multiply::DECL,
    integer_div::DECL,
    integer_mod::DECL,
    integer_negate::DECL,
    integer_less::DECL,
    integer_less_or_equal::DECL,
    integer_greater::DECL,
    integer_greater_or_equal::DECL,
    float_add::DECL,
    float_subtract::DECL,
    float_multiply::DECL,
    float_divide::DECL,
    float_negate::DECL,
    float_less::DECL,
    float_less_or_equal::DECL,
    float_greater::DECL,
    float_greater_or_equal::DECL,
    decimal_add::DECL,
    decimal_subtract::DECL,
    decimal_multiply::DECL,
    decimal_divide::DECL,
    decimal_negate::DECL,
    decimal_less::DECL,
    decimal_less_or_equal::DECL,
    decimal_greater::DECL,
    decimal_greater_or_equal::DECL,
    string_add::DECL,
    string_less::DECL,
    string_less_or_equal::DECL,
    string_greater::DECL,
    string_greater_or_equal::DECL,
    character_less::DECL,
    character_less_or_equal::DECL,
    character_greater::DECL,
    character_greater_or_equal::DECL,
    byte_less::DECL,
    byte_less_or_equal::DECL,
    byte_greater::DECL,
    byte_greater_or_equal::DECL,
    eq::DECL,
    ne::DECL,
];

/// Decimal の命令と組み込みの関数で、停止理由を揃える（設計書 01-04「Decimal（初回リリース版）」）。
pub(crate) fn decimal_error(error: crate::base::decimal::DecimalError) -> Stop {
    match error {
        crate::base::decimal::DecimalError::Overflow => {
            Stop::Runtime(RuntimeError::DecimalOverflow)
        }
        crate::base::decimal::DecimalError::DivisionByZero => {
            Stop::Runtime(RuntimeError::DivisionByZero)
        }
        crate::base::decimal::DecimalError::InvalidPlaces => {
            Stop::Internal("unexpected Decimal rounding places".into())
        }
    }
}

#[cfg(test)]
pub(super) mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use crate::base::Decimal;
    use crate::builtins::table::tags;
    use crate::runtime::heap::{CtorTag, FieldsKind, Value, ValueCtx};

    macro_rules! direct {
        ($ctx:expr, $function:path, $a:expr) => {{
            let a = $a;
            let call = crate::builtins::iface::CallCtx::new($ctx, None, None, None);
            $function(call.pure_ctx(), a)
        }};
        ($ctx:expr, $function:path, $a:expr, $b:expr) => {{
            let (a, b) = ($a, $b);
            let call = crate::builtins::iface::CallCtx::new($ctx, None, None, None);
            $function(call.pure_ctx(), a, b)
        }};
        ($ctx:expr, $function:path, $a:expr, $b:expr, $c:expr) => {{
            let (a, b, c) = ($a, $b, $c);
            let call = crate::builtins::iface::CallCtx::new($ctx, None, None, None);
            $function(call.pure_ctx(), a, b, c)
        }};
    }
    pub(in crate::builtins::funcs) use direct;

    pub(in crate::builtins::funcs) fn d<'e>(ctx: &ValueCtx<'e>, text: &str) -> Value<'e> {
        let (text, negative) = text.strip_prefix('-').map_or((text, false), |s| (s, true));
        let d = Decimal::parse_literal(text).expect("valid test Decimal");
        ctx.alloc_decimal(if negative { d.negate() } else { d })
    }

    pub(in crate::builtins::funcs) fn decimal_text<'e>(
        value: Value<'e>,
        ctx: &ValueCtx<'e>,
    ) -> String {
        ctx.decimal(value).expect("Decimal result").to_text()
    }

    pub(in crate::builtins::funcs) fn payload<'e>(
        v: Value<'e>,
        ctx: &ValueCtx<'e>,
    ) -> Option<Value<'e>> {
        if matches!(v, Value::Tag(CtorTag(tags::OPTION_NONE))) {
            None
        } else {
            assert_eq!(
                ctx.fields_header(v),
                Some((FieldsKind::Ctor, tags::OPTION_SOME))
            );
            assert_eq!(ctx.fields_len(v), Some(1));
            Some(ctx.field(v, 0).expect("Option.Some payload"))
        }
    }

    // 名前の付いた本体を直接呼ぶことは R35・10-12 が個別に指定する（00-03 の個別指示の優先）。
    // 関門: 数としての比較・桁数の保持・エラーの対応づけを守る。base のテストだけでは
    // 誤った関数や停止理由への接続を捕まえられず、公開の口も加えない。
    use super::*;
    use crate::base::decimal::MAX_MANTISSA;
    use crate::runtime::heap::{Heap, HeapConfig};

    type Arithmetic = for<'c, 'e> fn(
        crate::builtins::iface::PureCtx<'c, 'e>,
        Value<'e>,
        Value<'e>,
    ) -> Result<Value<'e>, Stop>;
    type Comparison = for<'c, 'e> fn(
        crate::builtins::iface::PureCtx<'c, 'e>,
        Value<'e>,
        Value<'e>,
    ) -> Result<bool, Stop>;
    type ByteComparison =
        for<'c, 'e> fn(crate::builtins::iface::PureCtx<'c, 'e>, u8, u8) -> Result<bool, Stop>;

    #[test]
    fn decimal_operators_preserve_results_and_stop_reasons() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (function, expected) in [
                (decimal_add as Arithmetic, "3.20"),
                (decimal_subtract, "-0.80"),
                (decimal_multiply, "2.400"),
                (decimal_divide, "0.6"),
            ] {
                let result = direct!(ctx, function, d(ctx, "1.20"), d(ctx, "2.0")).unwrap();
                assert_eq!(decimal_text(result, ctx), expected);
            }
            assert_eq!(
                decimal_text(direct!(ctx, decimal_negate, d(ctx, "1.20")).unwrap(), ctx),
                "-1.20"
            );
            assert_eq!(
                decimal_text(direct!(ctx, decimal_negate, d(ctx, "0.00")).unwrap(), ctx),
                "0.00"
            );
            let max = ctx.alloc_decimal(crate::base::Decimal::new(MAX_MANTISSA, 0).unwrap());
            for (function, a, b) in [
                (decimal_add as Arithmetic, max, d(ctx, "1")),
                (decimal_subtract, max, d(ctx, "-1")),
                (decimal_multiply, max, d(ctx, "2")),
                (decimal_divide, max, d(ctx, "0.1")),
            ] {
                assert_eq!(
                    direct!(ctx, function, a, b).unwrap_err(),
                    Stop::Runtime(RuntimeError::DecimalOverflow)
                );
            }
            assert_eq!(
                direct!(ctx, decimal_divide, max, d(ctx, "0.0")).unwrap_err(),
                Stop::Runtime(RuntimeError::DivisionByZero)
            );
            assert!(matches!(
                direct!(ctx, decimal_add, Value::Int(1), max),
                Err(Stop::Internal(_))
            ));
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    fn decimal_and_byte_ordering_use_numeric_values() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (function, less, equal, greater) in [
                (decimal_less as Comparison, true, false, false),
                (decimal_less_or_equal, true, true, false),
                (decimal_greater, false, false, true),
                (decimal_greater_or_equal, false, true, true),
            ] {
                for (a, b, expected) in [
                    ("-1", "1", less),
                    ("1.0", "1.00", equal),
                    ("2", "1", greater),
                ] {
                    assert_eq!(
                        direct!(ctx, function, d(ctx, a), d(ctx, b)).unwrap(),
                        expected
                    );
                }
            }
            for (function, less, equal, greater) in [
                (byte_less as ByteComparison, true, false, false),
                (byte_less_or_equal, true, true, false),
                (byte_greater, false, false, true),
                (byte_greater_or_equal, false, true, true),
            ] {
                for (a, b, expected) in [(0, 255, less), (255, 255, equal), (255, 0, greater)] {
                    assert_eq!(direct!(ctx, function, a, b).unwrap(), expected);
                }
            }
        });
    }
}
