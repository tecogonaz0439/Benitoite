//! Int の変換と補助関数（設計書 01-04「Int」「型の変換」、03-06「Int」）。

use crate::builtins::ops::{int_div, int_rem};
use crate::runtime::heap::Heap;
use crate::runtime::value::Value;
use crate::runtime::{RuntimeError, Stop};

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("Int builtin received invalid arguments"))
}

fn integer_overflow() -> Stop {
    Stop::Runtime(RuntimeError::IntegerOverflow)
}

fn division_by_zero() -> Stop {
    Stop::Runtime(RuntimeError::DivisionByZero)
}

fn one_int(args: &[Value]) -> Result<i64, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_int)
        .ok_or_else(invalid_arguments)
}

fn two_ints(args: &[Value]) -> Result<(i64, i64), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(left) = args.first().and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    let Some(right) = args.get(1).and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    Ok((left, right))
}

fn one_string(args: &[Value]) -> Result<&str, Stop> {
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

fn is_decimal_integer(text: &str) -> bool {
    let digits = match text.strip_prefix('-') {
        Some(digits) => digits,
        None => text,
    };
    !digits.is_empty()
        && !(digits.len() > 1 && digits.starts_with('0'))
        && digits.bytes().all(|digit| digit.is_ascii_digit())
}

/// Int を符号付き 10 進表記の String にする。
pub fn to_string(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = one_int(args)?;
    Ok(heap.string(&value.to_string()))
}

/// 符号と 10 進数字列だけからなる表記を Int として読む。
pub fn parse(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let text = one_string(args)?;
    if !is_decimal_integer(text) {
        return Ok(none(heap));
    }
    match text.parse::<i64>() {
        Ok(value) => Ok(some(heap, Value::Int(value))),
        Err(_) => Ok(none(heap)),
    }
}

/// Int を最も近い Float に変換する。変換先はすべて有限範囲内である（設計書 01-04「型の変換」）。
pub fn to_float(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = one_int(args)?;
    // i64 の値はすべて f64 の有限範囲に入り、浮動小数への変換規則が最近接偶数丸めである（設計書 01-04「型の変換」）。
    Ok(Value::Float(value as f64))
}

/// 商を負の無限大の方向に丸める（設計書 01-04「Int」）。
pub fn floor_div(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = two_ints(args)?;
    let quotient = int_div(left, right)?;
    let remainder = int_rem(left, right)?;
    let rounds_down = remainder != 0 && ((left < 0) != (right < 0));
    let value = if rounds_down {
        quotient.checked_sub(1).ok_or_else(integer_overflow)?
    } else {
        quotient
    };
    Ok(Value::Int(value))
}

/// 剰余の符号を除数と同じにする（設計書 01-04「Int」）。
pub fn modulo(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = two_ints(args)?;
    if right == 0 {
        return Err(division_by_zero());
    }
    let remainder = int_rem(left, right)?;
    let adjusts_sign = remainder != 0 && ((remainder < 0) != (right < 0));
    let value = if adjusts_sign {
        remainder.checked_add(right).ok_or_else(integer_overflow)?
    } else {
        remainder
    };
    Ok(Value::Int(value))
}

/// Int の絶対値。最小値は正の Int にできないため溢れとなる。
pub fn abs(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    one_int(args)?
        .checked_abs()
        .map(Value::Int)
        .ok_or_else(integer_overflow)
}

/// 二つの Int の小さいほう。
pub fn min(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = two_ints(args)?;
    Ok(Value::Int(left.min(right)))
}

/// 二つの Int の大きいほう。
pub fn max(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = two_ints(args)?;
    Ok(Value::Int(left.max(right)))
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
    // Int の公開組み込み関数が返す値と実行時エラーを確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::runtime::heap::Heap;
    use crate::runtime::value::Value;
    use crate::runtime::{RuntimeError, Stop};

    use super::{abs, floor_div, max, min, modulo, parse, to_float, to_string};

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

    #[test]
    fn floor_division_and_modulo_follow_floor_sign_rules() {
        let mut heap = Heap::new();
        assert_eq!(
            floor_div(&mut heap, &[Value::Int(-7), Value::Int(2)])
                .unwrap()
                .as_int(),
            Some(-4)
        );
        assert_eq!(
            modulo(&mut heap, &[Value::Int(-7), Value::Int(2)])
                .unwrap()
                .as_int(),
            Some(1)
        );
        assert_eq!(
            modulo(&mut heap, &[Value::Int(7), Value::Int(-2)])
                .unwrap()
                .as_int(),
            Some(-1)
        );
        assert_eq!(
            modulo(&mut heap, &[Value::Int(i64::MIN), Value::Int(-1)])
                .unwrap()
                .as_int(),
            Some(0)
        );
        assert!(matches!(
            floor_div(&mut heap, &[Value::Int(i64::MIN), Value::Int(-1)]),
            Err(Stop::Runtime(RuntimeError::IntegerOverflow))
        ));
        assert!(matches!(
            floor_div(&mut heap, &[Value::Int(1), Value::Int(0)]),
            Err(Stop::Runtime(RuntimeError::DivisionByZero))
        ));
    }

    #[test]
    fn decimal_parse_accepts_only_canonical_in_range_forms() {
        let cases = [
            ("0", Some(0)),
            ("42", Some(42)),
            ("-0", Some(0)),
            ("007", None),
            ("-007", None),
            ("+1", None),
            ("1_000", None),
            (" 1", None),
            ("", None),
            ("-", None),
            ("9223372036854775808", None),
            ("-9223372036854775808", Some(i64::MIN)),
        ];
        let mut heap = Heap::new();
        for (text, expected) in cases {
            let input = heap.string(text);
            let result = parse(&mut heap, &[input]).unwrap();
            assert_option_int(&result, expected);
        }
    }

    #[test]
    fn conversions_and_integer_helpers_preserve_their_contracts() {
        let mut heap = Heap::new();
        assert_eq!(
            to_string(&mut heap, &[Value::Int(i64::MIN)])
                .unwrap()
                .as_str(),
            Some("-9223372036854775808")
        );
        assert_eq!(
            to_float(&mut heap, &[Value::Int(9_007_199_254_740_993)])
                .unwrap()
                .as_float(),
            Some(9_007_199_254_740_992.0)
        );
        assert_eq!(
            min(&mut heap, &[Value::Int(4), Value::Int(-2)])
                .unwrap()
                .as_int(),
            Some(-2)
        );
        assert_eq!(
            max(&mut heap, &[Value::Int(4), Value::Int(-2)])
                .unwrap()
                .as_int(),
            Some(4)
        );
        assert_eq!(abs(&mut heap, &[Value::Int(-5)]).unwrap().as_int(), Some(5));
        assert!(matches!(
            abs(&mut heap, &[Value::Int(i64::MIN)]),
            Err(Stop::Runtime(RuntimeError::IntegerOverflow))
        ));
    }
}
