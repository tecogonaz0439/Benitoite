//! Decimal の丸めと変換（設計書 01-04「Decimal（初回リリース版）」「型の変換」）。

use crate::base::Decimal;
use crate::base::decimal::{DecimalError, DecimalRounding};
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{Value, ValueCtx};
use crate::runtime::{RuntimeError, Stop};

builtin! {
    /// `Decimal.round` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.round",
    pure fn round(ctx, x: Value<'e>, places: i64, mode: Value<'e>) -> Value<'e> {
        let x = operand(&ctx, x)?;
        let mode = match mode.as_tag().map(|tag| tag.0) {
            Some(tags::ROUNDING_MODE_HALF_TO_EVEN) => DecimalRounding::HalfToEven,
            Some(tags::ROUNDING_MODE_HALF_AWAY_FROM_ZERO) => DecimalRounding::HalfAwayFromZero,
            Some(tags::ROUNDING_MODE_TOWARD_ZERO) => DecimalRounding::TowardZero,
            Some(tags::ROUNDING_MODE_TOWARD_NEGATIVE_INFINITY) => DecimalRounding::TowardNegativeInfinity,
            Some(tags::ROUNDING_MODE_TOWARD_POSITIVE_INFINITY) => DecimalRounding::TowardPositiveInfinity,
            _ => return Err(Stop::Internal("RoundingMode tag required".into())),
        };
        let result = x.round(places, mode).map_err(|error| match error {
            DecimalError::InvalidPlaces => Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                function: "Decimal.round", argument: 1,
            }),
            DecimalError::Overflow | DecimalError::DivisionByZero => super::operators::decimal_error(error),
        })?;
        Ok(ctx.alloc_decimal(result))
    }
}

builtin! {
    /// `Decimal.absolute` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.absolute",
    pure fn absolute(ctx, x: Value<'e>) -> Value<'e> {
        Ok(ctx.alloc_decimal(operand(&ctx, x)?.abs()))
    }
}

builtin! {
    /// `Decimal.fromInteger` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.fromInteger",
    pure fn from_integer(ctx, n: i64) -> Value<'e> {
        Ok(ctx.alloc_decimal(Decimal::from_integer(n)))
    }
}

builtin! {
    /// `Decimal.truncate` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.truncate",
    pure fn truncate(ctx, x: Value<'e>) -> Value<'e> {
        let integral = operand(&ctx, x)?.round(0, DecimalRounding::TowardZero)
            .map_err(super::operators::decimal_error)?;
        super::option(&ctx, i64::try_from(integral.mantissa()).ok().map(Value::Int))
    }
}

builtin! {
    /// `Decimal.toFloat` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.toFloat",
    pure fn to_float(ctx, x: Value<'e>) -> f64 {
        operand(&ctx, x)?.to_text().parse()
            .map_err(|_| Stop::Internal("Decimal text cannot be read as Float".into()))
    }
}

builtin! {
    /// `Decimal.fromFloat` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.fromFloat",
    pure fn from_float(ctx, x: f64) -> Value<'e> {
        super::option(&ctx, float_decimal(x).map(|d| ctx.alloc_decimal(d)))
    }
}

builtin! {
    /// `Decimal.toString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.toString",
    pure fn to_string(ctx, x: Value<'e>) -> Value<'e> {
        ctx.alloc_str(&operand(&ctx, x)?.to_text(), "Decimal.toString")
    }
}

builtin! {
    /// `Decimal.parse` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Decimal.parse",
    pure fn parse(ctx, s: &'c str) -> Value<'e> {
        let (digits, negative) = match s.strip_prefix('-') {
            Some(digits) => (digits, true),
            None => (s, false),
        };
        let value = Decimal::parse_literal(digits)
            .map(|d| if negative { d.negate() } else { d });
        super::option(&ctx, value.map(|d| ctx.alloc_decimal(d)))
    }
}

// FromArg にない Decimal は公開の読み取り API で検査する（実装プラン R35「組み込みの関数」）。
pub(super) fn operand<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Decimal, Stop> {
    ctx.decimal(value)
        .ok_or_else(|| Stop::Internal("Decimal operand required".into()))
}

fn float_decimal(x: f64) -> Option<Decimal> {
    if !x.is_finite() {
        return None;
    }
    let text = crate::base::prim::float_to_text(x);
    let (unsigned, negative) = text
        .strip_prefix('-')
        .map_or((text.as_str(), false), |s| (s, true));
    let (significand, exponent) = match unsigned.split_once('e') {
        Some((s, e)) => (s, e.parse::<i32>().ok()?),
        None => (unsigned, 0),
    };
    let (whole, fraction) = significand.split_once('.').unwrap_or((significand, ""));
    let mut digits = format!("{whole}{fraction}");
    let scale = i32::try_from(fraction.len()).ok()?.checked_sub(exponent)?;
    let scale = if scale < 0 {
        for _ in 0..scale.checked_neg()? {
            digits.push('0');
        }
        0
    } else {
        u32::try_from(scale).ok()?
    };
    // Float の最短表記を一度だけ丸める。指数を展開してから文字の桁を捨てることで、
    // 96 bit に収まらない中間の仮数や二重丸めを避ける（設計書 01-04「型の変換」）。
    let discarded = usize::try_from(scale.saturating_sub(28)).ok()?;
    let retained = digits.len().saturating_sub(discarded);
    let mut mantissa = if retained == 0 {
        0
    } else {
        digits.get(..retained)?.parse::<i128>().ok()?
    };
    if discarded != 0 && discarded <= digits.len() {
        let tail = digits.get(retained..)?;
        let first = *tail.as_bytes().first()?;
        let above_half = first > b'5' || (first == b'5' && tail.bytes().skip(1).any(|b| b != b'0'));
        if above_half || (first == b'5' && mantissa & 1 != 0) {
            mantissa = mantissa.checked_add(1)?;
        }
    }
    if negative {
        mantissa = mantissa.checked_neg()?;
    }
    Decimal::new(mantissa, u8::try_from(scale.min(28)).ok()?)
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    round::DECL,
    absolute::DECL,
    from_integer::DECL,
    truncate::DECL,
    to_float::DECL,
    from_float::DECL,
    to_string::DECL,
    parse::DECL,
];

#[cfg(test)]
mod tests {
    // 関門: 8 項目の桁数・タグの対応・変換の失敗を、名前の付いた本体で確かめる（R35、10-12）。
    // base の算術では Float の表記、Option と RoundingMode の接続の退行を検出できない。
    // 期待値を仕様の数で記し、本番の口は増やさない。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::builtins::funcs::operators::tests::{d, decimal_text, direct, payload};
    use crate::runtime::heap::{CtorTag, Heap, HeapConfig};

    #[test]
    fn rounding_modes_places_and_overflow() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (tag, positive, negative) in [
                (tags::ROUNDING_MODE_HALF_TO_EVEN, "2", "-2"),
                (tags::ROUNDING_MODE_HALF_AWAY_FROM_ZERO, "3", "-3"),
                (tags::ROUNDING_MODE_TOWARD_ZERO, "2", "-2"),
                (tags::ROUNDING_MODE_TOWARD_NEGATIVE_INFINITY, "2", "-3"),
                (tags::ROUNDING_MODE_TOWARD_POSITIVE_INFINITY, "3", "-2"),
            ] {
                for (input, expected) in [("2.5", positive), ("-2.5", negative)] {
                    let value =
                        direct!(ctx, round, d(ctx, input), 0, Value::Tag(CtorTag(tag))).unwrap();
                    assert_eq!(decimal_text(value, ctx), expected);
                }
            }
            let even = Value::Tag(CtorTag(tags::ROUNDING_MODE_HALF_TO_EVEN));
            for (input, places, expected) in [
                ("3.5", 0, "4"),
                ("1.5", 2, "1.50"),
                ("0", 28, "0.0000000000000000000000000000"),
            ] {
                assert_eq!(
                    decimal_text(
                        direct!(ctx, round, d(ctx, input), places, even).unwrap(),
                        ctx
                    ),
                    expected
                );
            }
            for places in [-1, 29, i64::MAX] {
                assert_eq!(
                    direct!(ctx, round, d(ctx, "1"), places, even).unwrap_err(),
                    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                        function: "Decimal.round",
                        argument: 1
                    })
                );
            }
            assert_eq!(
                direct!(ctx, round, d(ctx, "79228162514264337593543950335"), 1, even).unwrap_err(),
                Stop::Runtime(RuntimeError::DecimalOverflow)
            );
            assert!(matches!(
                direct!(ctx, round, d(ctx, "1"), 0, Value::Int(0)),
                Err(Stop::Internal(_))
            ));
        });
    }

    #[test]
    fn absolute_integer_conversion_and_truncation() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (input, expected) in [("-1.50", "1.50"), ("1.50", "1.50"), ("0.00", "0.00")] {
                assert_eq!(
                    decimal_text(direct!(ctx, absolute, d(ctx, input)).unwrap(), ctx),
                    expected
                );
            }
            for n in [i64::MIN, 0, i64::MAX] {
                let value = direct!(ctx, from_integer, n).unwrap();
                assert_eq!(decimal_text(value, ctx), n.to_string());
                assert_eq!(ctx.decimal(value).unwrap().scale(), 0);
            }
            for (input, expected) in [
                ("-1.9", Some(-1)),
                ("1.9", Some(1)),
                ("-0.9", Some(0)),
                ("9223372036854775807.9", Some(i64::MAX)),
                ("-9223372036854775808.9", Some(i64::MIN)),
                ("9223372036854775808", None),
                ("-9223372036854775809", None),
                ("79228162514264337593543950335", None),
            ] {
                assert_eq!(
                    payload(direct!(ctx, truncate, d(ctx, input)).unwrap(), ctx)
                        .map(|v| v.as_int().unwrap()),
                    expected
                );
            }
        });
    }

    #[test]
    fn text_conversion_preserves_scale_and_parse_rejects_non_literals() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for text in [
                "1.50",
                "-3",
                "0.05",
                "0.00",
                "79228162514264337593543950335",
                "0.1234567890123456789012345678",
            ] {
                let value = payload(direct!(ctx, parse, text).unwrap(), ctx).unwrap();
                let result = direct!(ctx, to_string, value).unwrap();
                assert_eq!(ctx.str(result).unwrap(), text);
            }
            assert_eq!(
                decimal_text(
                    payload(direct!(ctx, parse, "-0.00").unwrap(), ctx).unwrap(),
                    ctx
                ),
                "0.00"
            );
            for text in [
                "",
                "-",
                "+1",
                " 1",
                "1 ",
                "1_0",
                "1m",
                "1e2",
                ".1",
                "1.",
                "1.2.3",
                "NaN",
                "Infinity",
                "１２",
                "--1",
                "79228162514264337593543950336",
                "0.12345678901234567890123456789",
            ] {
                assert!(
                    payload(direct!(ctx, parse, text).unwrap(), ctx).is_none(),
                    "{text}"
                );
            }
        });
    }

    #[test]
    fn float_conversion_uses_shortest_text_and_half_even_at_scale_28() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (input, expected) in [
                ("0.1", 0.1),
                ("-1.50", -1.5),
                ("9007199254740993", 9007199254740992.0),
                ("9007199254740995", 9007199254740996.0),
            ] {
                assert_eq!(direct!(ctx, to_float, d(ctx, input)).unwrap(), expected);
            }
            for (input, expected) in [
                (0.1, "0.1"),
                (-1.5, "-1.5"),
                (0.0, "0.0"),
                (-0.0, "0.0"),
                (1e21, "1000000000000000000000"),
                (1.25e-27, "0.0000000000000000000000000012"),
                (1.35e-27, "0.0000000000000000000000000014"),
                (-1.35e-27, "-0.0000000000000000000000000014"),
                (5e-29, "0.0000000000000000000000000000"),
                (6e-29, "0.0000000000000000000000000001"),
                (1e-300, "0.0000000000000000000000000000"),
                (7.9e28, "79000000000000000000000000000"),
            ] {
                let value = payload(direct!(ctx, from_float, input).unwrap(), ctx).unwrap();
                assert_eq!(decimal_text(value, ctx), expected, "{input}");
            }
            for input in [
                f64::NAN,
                f64::INFINITY,
                f64::NEG_INFINITY,
                8e28,
                -8e28,
                f64::MAX,
            ] {
                assert!(payload(direct!(ctx, from_float, input).unwrap(), ctx).is_none());
            }
        });
    }
}
