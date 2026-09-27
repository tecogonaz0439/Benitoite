//! Float の演算、変換、読み取り（設計書 01-04「Float」「型の変換」、03-06「Float」）。

use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::value::Value;

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("Float builtin received invalid arguments"))
}

fn unary_float(args: &[Value]) -> Result<f64, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_float)
        .ok_or_else(invalid_arguments)
}

fn unary_string(args: &[Value]) -> Result<&str, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_str)
        .ok_or_else(invalid_arguments)
}

fn some(heap: &mut Heap, value: Value) -> Value {
    heap.ctor(0, vec![value])
}

fn none(heap: &mut Heap) -> Value {
    heap.ctor(1, Vec::new())
}

fn is_ascii_digits(text: &str) -> bool {
    !text.is_empty() && text.bytes().all(|digit| digit.is_ascii_digit())
}

fn is_canonical_integer_part(text: &str) -> bool {
    is_ascii_digits(text) && !(text.len() > 1 && text.starts_with('0'))
}

fn is_valid_exponent(text: &str) -> bool {
    let digits = match text.strip_prefix('+').or_else(|| text.strip_prefix('-')) {
        Some(digits) => digits,
        None => text,
    };
    is_ascii_digits(digits)
}

fn is_valid_decimal(text: &str) -> bool {
    if text.is_empty() {
        return false;
    }
    let body = match text.strip_prefix('-') {
        Some(body) => body,
        None => text,
    };
    if body.is_empty() {
        return false;
    }

    // Rust の数値パーサーに任せる前に、字句仕様と同じ表記だけに絞る（設計書 01-01「浮動小数リテラル」、01-04「型の変換」）。
    let (mantissa, exponent) = if let Some((mantissa, exponent)) = body.split_once('e') {
        if exponent.contains('E') || exponent.contains('e') {
            return false;
        }
        (mantissa, Some(exponent))
    } else if let Some((mantissa, exponent)) = body.split_once('E') {
        if exponent.contains('E') {
            return false;
        }
        (mantissa, Some(exponent))
    } else {
        (body, None)
    };
    if let Some(exponent) = exponent
        && !is_valid_exponent(exponent)
    {
        return false;
    }

    if let Some((whole, fraction)) = mantissa.split_once('.') {
        is_canonical_integer_part(whole) && is_ascii_digits(fraction)
    } else {
        is_canonical_integer_part(mantissa)
    }
}

fn float_text(value: f64) -> Result<String, Stop> {
    if value.is_nan() {
        return Ok(String::from("NaN"));
    }
    if value == f64::INFINITY {
        return Ok(String::from("Infinity"));
    }
    if value == f64::NEG_INFINITY {
        return Ok(String::from("-Infinity"));
    }

    let negative = value.is_sign_negative();
    // LowerExp の最短の仮数と指数を使い、仕様が定める指数境界だけで固定表記と指数表記を切り替える（設計書 01-04「型の変換」）。
    let representation = format!("{:e}", value.abs());
    let Some((mantissa, exponent_text)) = representation.split_once('e') else {
        return Err(Stop::Internal(String::from(
            "lower exponential formatting omitted its exponent",
        )));
    };
    let exponent = exponent_text.parse::<i32>().map_err(|_| {
        Stop::Internal(String::from(
            "lower exponential formatting returned an invalid exponent",
        ))
    })?;
    let digits = mantissa
        .chars()
        .filter(char::is_ascii_digit)
        .collect::<String>();
    if digits.is_empty() {
        return Err(Stop::Internal(String::from(
            "lower exponential formatting returned no significand digits",
        )));
    }

    let mut result = if (-5..21).contains(&exponent) {
        fixed_decimal(&digits, exponent)?
    } else {
        exponential_decimal(&digits, exponent)?
    };
    if negative {
        result.insert(0, '-');
    }
    Ok(result)
}

fn fixed_decimal(digits: &str, exponent: i32) -> Result<String, Stop> {
    let decimal_position = exponent
        .checked_add(1)
        .ok_or_else(|| Stop::Internal(String::from("decimal position overflowed")))?;
    if decimal_position <= 0 {
        let Ok(leading_zeroes) = usize::try_from(decimal_position.unsigned_abs()) else {
            return Err(Stop::Internal(String::from(
                "decimal position does not fit the host address space",
            )));
        };
        return Ok(format!("0.{}{}", "0".repeat(leading_zeroes), digits));
    }

    let Ok(decimal_position) = usize::try_from(decimal_position) else {
        return Err(Stop::Internal(String::from(
            "decimal position does not fit the host address space",
        )));
    };
    if decimal_position >= digits.len() {
        let zeroes = decimal_position
            .checked_sub(digits.len())
            .ok_or_else(|| Stop::Internal(String::from("invalid decimal position")))?;
        return Ok(format!("{digits}{}.0", "0".repeat(zeroes)));
    }

    let Some(whole) = digits.get(..decimal_position) else {
        return Err(Stop::Internal(String::from(
            "decimal point is outside the significand",
        )));
    };
    let Some(fraction) = digits.get(decimal_position..) else {
        return Err(Stop::Internal(String::from(
            "decimal point is outside the significand",
        )));
    };
    Ok(format!("{whole}.{fraction}"))
}

fn exponential_decimal(digits: &str, exponent: i32) -> Result<String, Stop> {
    let Some(first) = digits.chars().next() else {
        return Err(Stop::Internal(String::from(
            "lower exponential formatting returned no significand digits",
        )));
    };
    let mut fraction = digits.chars().skip(1).collect::<String>();
    if fraction.is_empty() {
        fraction.push('0');
    }
    let sign = if exponent >= 0 { "+" } else { "-" };
    let Some(exponent_magnitude) = exponent.checked_abs() else {
        return Err(Stop::Internal(String::from(
            "lower exponential formatting returned an unrepresentable exponent",
        )));
    };
    Ok(format!("{first}.{fraction}e{sign}{exponent_magnitude}"))
}

/// Float を基本型の規則に従う最短の 10 進表記にする。
pub fn to_string(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = unary_float(args)?;
    Ok(heap.string(&float_text(value)?))
}

/// 整数リテラルまたは浮動小数リテラルの 10 進表記を読む。
pub fn parse(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let text = unary_string(args)?;
    if !is_valid_decimal(text) {
        return Ok(none(heap));
    }
    match text.parse::<f64>() {
        Ok(value) if value.is_finite() => Ok(some(heap, Value::Float(value))),
        Ok(_) | Err(_) => Ok(none(heap)),
    }
}

/// Float を 0 の方向へ切り捨て、Int の範囲に入るときだけ Some を返す。
pub fn truncate(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = unary_float(args)?;
    let truncated = value.trunc();
    const I64_MIN_AS_FLOAT: f64 = -9_223_372_036_854_775_808.0;
    const I64_MAX_EXCLUSIVE_AS_FLOAT: f64 = 9_223_372_036_854_775_808.0;
    if !truncated.is_finite()
        || truncated < I64_MIN_AS_FLOAT
        || truncated >= I64_MAX_EXCLUSIVE_AS_FLOAT
    {
        return Ok(none(heap));
    }
    // 上の範囲検査で整数値が i64 に収まることを示したため、飽和変換に頼らずに変換できる（設計書 01-04「型の変換」）。
    Ok(some(heap, Value::Int(truncated as i64)))
}

/// 値が NaN かを返す。
pub fn is_nan(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Bool(unary_float(args)?.is_nan()))
}

/// Float の絶対値を返す。
pub fn abs(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Float(unary_float(args)?.abs()))
}

/// Float 以下の最大の整数値を Float で返す。
pub fn floor(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Float(unary_float(args)?.floor()))
}

/// Float 以上の最小の整数値を Float で返す。
pub fn ceil(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Float(unary_float(args)?.ceil()))
}

/// 最も近い整数値を返し、中間では 0 から遠いほうへ丸める。
pub fn round(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Float(unary_float(args)?.round()))
}

/// Float の平方根を返す。負の値の結果は NaN となる。
pub fn sqrt(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Float(unary_float(args)?.sqrt()))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // Float の文字列形式、丸め境界、Option の結果を公開関数で確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::runtime::Stop;
    use crate::runtime::heap::Heap;
    use crate::runtime::value::Value;

    use super::{abs, ceil, floor, is_nan, parse, round, sqrt, to_string, truncate};

    fn option_float(value: &Value) -> Option<f64> {
        let (tag, fields) = value.as_ctor()?;
        if tag == 0 {
            fields.first().and_then(Value::as_float)
        } else {
            None
        }
    }

    fn assert_option_float(value: &Value, expected: Option<f64>) {
        let (tag, fields) = value.as_ctor().unwrap();
        match expected {
            Some(expected) => {
                assert_eq!(tag, 0);
                assert_eq!(fields.len(), 1);
                let actual = fields.first().and_then(Value::as_float).unwrap();
                assert_eq!(actual.to_bits(), expected.to_bits());
            }
            None => {
                assert_eq!(tag, 1);
                assert!(fields.is_empty());
            }
        }
    }

    fn assert_option_int(value: &Value, expected: Option<i64>) {
        let (tag, fields) = value.as_ctor().unwrap();
        match expected {
            Some(expected) => {
                assert_eq!(tag, 0);
                assert_eq!(fields.len(), 1);
                assert_eq!(fields.first().and_then(Value::as_int), Some(expected));
            }
            None => {
                assert_eq!(tag, 1);
                assert!(fields.is_empty());
            }
        }
    }

    fn parsed_float(heap: &mut Heap, text: &str) -> Option<f64> {
        let input = heap.string(text);
        let result = parse(heap, &[input]).ok()?;
        option_float(&result)
    }

    #[test]
    fn float_to_string_uses_fixed_and_exponential_forms() {
        let cases = [
            (1.0, "1.0"),
            (0.1, "0.1"),
            (1e21, "1.0e+21"),
            (1e20, "100000000000000000000.0"),
            (1.5e-7, "1.5e-7"),
            (0.00001, "0.00001"),
            (0.000001, "1.0e-6"),
            (123.45, "123.45"),
            (-0.0, "-0.0"),
            (f64::MAX, "1.7976931348623157e+308"),
            (5e-324, "5.0e-324"),
        ];
        let mut heap = Heap::new();
        for (value, expected) in cases {
            let result = to_string(&mut heap, &[Value::Float(value)]).unwrap();
            let text = result.as_str().unwrap();
            assert_eq!(text, expected);
            let reparsed = parsed_float(&mut heap, text).unwrap();
            assert_eq!(reparsed.to_bits(), value.to_bits(), "text: {expected}");
        }
        assert_eq!(
            to_string(&mut heap, &[Value::Float(f64::NAN)])
                .unwrap()
                .as_str(),
            Some("NaN")
        );
        assert_eq!(
            to_string(&mut heap, &[Value::Float(f64::INFINITY)])
                .unwrap()
                .as_str(),
            Some("Infinity")
        );
        assert_eq!(
            to_string(&mut heap, &[Value::Float(f64::NEG_INFINITY)])
                .unwrap()
                .as_str(),
            Some("-Infinity")
        );
    }

    #[test]
    fn float_parse_checks_literal_grammar_and_preserves_underflow_sign() {
        let cases: [(&str, Option<f64>); 16] = [
            ("1.5", Some(1.5)),
            ("42", Some(42.0)),
            ("-0", Some(-0.0)),
            ("1e10", Some(1e10)),
            ("-1e-9999", Some(-0.0)),
            ("1e400", None),
            ("NaN", None),
            ("Infinity", None),
            ("inf", None),
            (".5", None),
            ("1.", None),
            ("01.5", None),
            ("1_0.0", None),
            ("+1.0", None),
            ("1e+", None),
            ("0e05", Some(0.0)),
        ];
        let mut heap = Heap::new();
        for (text, expected) in cases {
            let input = heap.string(text);
            let actual = parse(&mut heap, &[input]).unwrap();
            assert_option_float(&actual, expected);
        }
    }

    #[test]
    fn truncate_accepts_the_signed_integer_range_only() {
        let mut heap = Heap::new();
        for (value, expected) in [
            (2.9, Some(2_i64)),
            (-2.9, Some(-2_i64)),
            (-9.223372036854776e18, Some(i64::MIN)),
            (9.3e18, None),
            (f64::NAN, None),
            (f64::INFINITY, None),
        ] {
            let result = truncate(&mut heap, &[Value::Float(value)]).unwrap();
            assert_option_int(&result, expected);
        }
    }

    #[test]
    fn float_rounding_helpers_keep_their_documented_behavior() {
        let mut heap = Heap::new();
        assert_eq!(
            floor(&mut heap, &[Value::Float(-0.5)]).unwrap().as_float(),
            Some(-1.0)
        );
        let ceil_value = ceil(&mut heap, &[Value::Float(-0.5)])
            .unwrap()
            .as_float()
            .unwrap();
        assert_eq!(ceil_value.to_bits(), (-0.0_f64).to_bits());
        assert_eq!(
            round(&mut heap, &[Value::Float(2.5)]).unwrap().as_float(),
            Some(3.0)
        );
        let rounded_zero = round(&mut heap, &[Value::Float(-0.4)])
            .unwrap()
            .as_float()
            .unwrap();
        assert_eq!(rounded_zero.to_bits(), (-0.0_f64).to_bits());
        assert!(
            sqrt(&mut heap, &[Value::Float(-1.0)])
                .unwrap()
                .as_float()
                .unwrap()
                .is_nan()
        );
        assert_eq!(
            abs(&mut heap, &[Value::Float(-2.5)]).unwrap().as_float(),
            Some(2.5)
        );
        assert_eq!(
            is_nan(&mut heap, &[Value::Float(f64::NAN)])
                .unwrap()
                .as_bool(),
            Some(true)
        );
        assert!(matches!(
            truncate(&mut heap, &[Value::Int(1)]),
            Err(Stop::Internal(_))
        ));
    }
}
