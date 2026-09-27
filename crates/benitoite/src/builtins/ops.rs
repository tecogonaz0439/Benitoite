//! 演算子と VM が共有する演算（設計書 01-04「Int」「Float」「String」「Char」）。

use crate::runtime::heap::Heap;
use crate::runtime::value::{Value, values_equal};
use crate::runtime::{MAX_STRING_BYTES, ResourceError, RuntimeError, SizeUnit, Stop};

fn overflow() -> Stop {
    Stop::Runtime(RuntimeError::IntegerOverflow)
}

fn division_by_zero() -> Stop {
    Stop::Runtime(RuntimeError::DivisionByZero)
}

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("operator received invalid arguments"))
}

fn int_args(args: &[Value]) -> Result<(i64, i64), Stop> {
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

fn float_args(args: &[Value]) -> Result<(f64, f64), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(left) = args.first().and_then(Value::as_float) else {
        return Err(invalid_arguments());
    };
    let Some(right) = args.get(1).and_then(Value::as_float) else {
        return Err(invalid_arguments());
    };
    Ok((left, right))
}

fn string_args(args: &[Value]) -> Result<(&str, &str), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(left) = args.first().and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    let Some(right) = args.get(1).and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    Ok((left, right))
}

fn char_args(args: &[Value]) -> Result<(char, char), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(left) = args.first().and_then(Value::as_char) else {
        return Err(invalid_arguments());
    };
    let Some(right) = args.get(1).and_then(Value::as_char) else {
        return Err(invalid_arguments());
    };
    Ok((left, right))
}

fn unary_int_arg(args: &[Value]) -> Result<i64, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_int)
        .ok_or_else(invalid_arguments)
}

fn unary_float_arg(args: &[Value]) -> Result<f64, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_float)
        .ok_or_else(invalid_arguments)
}

/// Int の加算。溢れを整数オーバーフローとして返す（設計書 01-04「Int」）。
pub fn int_add(a: i64, b: i64) -> Result<i64, Stop> {
    a.checked_add(b).ok_or_else(overflow)
}

/// Int の減算。溢れを整数オーバーフローとして返す（設計書 01-04「Int」）。
pub fn int_sub(a: i64, b: i64) -> Result<i64, Stop> {
    a.checked_sub(b).ok_or_else(overflow)
}

/// Int の乗算。溢れを整数オーバーフローとして返す（設計書 01-04「Int」）。
pub fn int_mul(a: i64, b: i64) -> Result<i64, Stop> {
    a.checked_mul(b).ok_or_else(overflow)
}

/// 0 の方向に切り捨てる。b が 0 なら 0 による除算、a が最小値で b が -1 なら溢れる。
pub fn int_div(a: i64, b: i64) -> Result<i64, Stop> {
    if b == 0 {
        return Err(division_by_zero());
    }
    a.checked_div(b).ok_or_else(overflow)
}

/// 余りの符号は a と同じか 0。最小値を -1 で割った余りは 0 である（設計書 01-04「Int」）。
pub fn int_rem(a: i64, b: i64) -> Result<i64, Stop> {
    if b == 0 {
        return Err(division_by_zero());
    }
    // 0 を先に除外した後の None は MIN % -1 だけであり、仕様では 0 とする（設計書 01-04「Int」）。
    match a.checked_rem(b) {
        Some(remainder) => Ok(remainder),
        None => Ok(0),
    }
}

/// Int の符号を反転する。最小値の反転は整数オーバーフローとなる。
pub fn int_neg(a: i64) -> Result<i64, Stop> {
    a.checked_neg().ok_or_else(overflow)
}

fn concat_size_error(size: u64) -> Stop {
    Stop::Resource(ResourceError::ValueTooLarge {
        function: "+",
        size,
        unit: SizeUnit::Bytes,
        limit: MAX_STRING_BYTES,
    })
}

fn checked_concat_size(a_len: usize, b_len: usize) -> Result<u64, Stop> {
    let Some(size) = a_len
        .checked_add(b_len)
        .and_then(|sum| u64::try_from(sum).ok())
    else {
        return Err(concat_size_error(u64::MAX));
    };
    if size > MAX_STRING_BYTES {
        return Err(concat_size_error(size));
    }
    Ok(size)
}

/// String の加算。上限判定を値の確保より先に行う（設計書 02-09「一つの操作で作る値の大きさの上限」）。
pub fn string_concat(heap: &mut Heap, a: &str, b: &str) -> Result<Value, Stop> {
    let size = checked_concat_size(a.len(), b.len())?;
    let Ok(capacity) = usize::try_from(size) else {
        return Err(Stop::Internal(String::from(
            "string length does not fit the host address space",
        )));
    };
    let mut result = String::with_capacity(capacity);
    result.push_str(a);
    result.push_str(b);
    Ok(heap.string(&result))
}

/// 演算子 + の Int 実装。
pub fn add_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = int_args(args)?;
    int_add(left, right).map(Value::Int)
}

/// 演算子 - の Int 実装。
pub fn sub_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = int_args(args)?;
    int_sub(left, right).map(Value::Int)
}

/// 演算子 * の Int 実装。
pub fn mul_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = int_args(args)?;
    int_mul(left, right).map(Value::Int)
}

/// 演算子 / の Int 実装。
pub fn div_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = int_args(args)?;
    int_div(left, right).map(Value::Int)
}

/// 演算子 % の Int 実装。
pub fn rem_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = int_args(args)?;
    int_rem(left, right).map(Value::Int)
}

/// 単項 - の Int 実装。
pub fn neg_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    int_neg(unary_int_arg(args)?).map(Value::Int)
}

/// 演算子 + の Float 実装。
pub fn add_float(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = float_args(args)?;
    Ok(Value::Float(left + right))
}

/// 演算子 - の Float 実装。
pub fn sub_float(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = float_args(args)?;
    Ok(Value::Float(left - right))
}

/// 演算子 * の Float 実装。
pub fn mul_float(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = float_args(args)?;
    Ok(Value::Float(left * right))
}

/// 演算子 / の Float 実装。0 による除算も IEEE 754 の結果を返す。
pub fn div_float(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = float_args(args)?;
    Ok(Value::Float(left / right))
}

/// 単項 - の Float 実装。
pub fn neg_float(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Float(-unary_float_arg(args)?))
}

/// 演算子 + の String 実装。
pub fn concat_string(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = string_args(args)?;
    string_concat(heap, left, right)
}

macro_rules! comparison_fn {
    ($name:ident, $args_fn:ident, $ty:ty, $operator:tt) => {
        #[doc = "比較演算子の PureFn 実装。"]
        pub fn $name(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
            let (left, right): ($ty, $ty) = $args_fn(args)?;
            Ok(Value::Bool(left $operator right))
        }
    };
}

comparison_fn!(lt_int, int_args, i64, <);
comparison_fn!(le_int, int_args, i64, <=);
comparison_fn!(gt_int, int_args, i64, >);
comparison_fn!(ge_int, int_args, i64, >=);
comparison_fn!(lt_float, float_args, f64, <);
comparison_fn!(le_float, float_args, f64, <=);
comparison_fn!(gt_float, float_args, f64, >);
comparison_fn!(ge_float, float_args, f64, >=);
comparison_fn!(lt_string, string_args, &str, <);
comparison_fn!(le_string, string_args, &str, <=);
comparison_fn!(gt_string, string_args, &str, >);
comparison_fn!(ge_string, string_args, &str, >=);
comparison_fn!(lt_char, char_args, char, <);
comparison_fn!(le_char, char_args, char, <=);
comparison_fn!(gt_char, char_args, char, >);
comparison_fn!(ge_char, char_args, char, >=);

fn is_structural(value: &Value) -> bool {
    matches!(value, Value::Ctor(_) | Value::List(_))
}

fn equality_args(args: &[Value]) -> Result<bool, Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(left) = args.first() else {
        return Err(invalid_arguments());
    };
    let Some(right) = args.get(1) else {
        return Err(invalid_arguments());
    };
    if is_structural(left) || is_structural(right) {
        if is_structural(left) && is_structural(right) {
            return values_equal(left, right);
        }
        return Err(invalid_arguments());
    }
    match (left, right) {
        (Value::Int(left), Value::Int(right)) => Ok(left == right),
        (Value::Float(left), Value::Float(right)) => Ok(left == right),
        (Value::Bool(left), Value::Bool(right)) => Ok(left == right),
        (Value::Char(left), Value::Char(right)) => Ok(left == right),
        (Value::Unit, Value::Unit) => Ok(true),
        (Value::Str(left), Value::Str(right)) => Ok(left.as_str() == right.as_str()),
        _ => Err(invalid_arguments()),
    }
}

/// 等値の型を値または構造で比較する（設計書 01-06「等値の型」）。
pub fn eq(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    equality_args(args).map(Value::Bool)
}

/// 等値の型を比較した結果の否定。NaN との比較も == の否定になる。
pub fn ne(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    equality_args(args).map(|equal| Value::Bool(!equal))
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
    // 公開された演算の結果と失敗を確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::bytecode::program::ProtoIdx;
    use crate::runtime::value::Value;
    use crate::runtime::{MAX_STRING_BYTES, ResourceError, RuntimeError, SizeUnit, Stop};

    use super::{
        add_float, add_int, checked_concat_size, div_float, eq, ge_char, int_add, int_div, int_mul,
        int_neg, int_rem, lt_float, lt_string, mul_int, ne, rem_int, string_concat,
    };
    use crate::runtime::heap::Heap;

    #[test]
    fn integer_operators_check_overflow_and_division_edges() {
        assert_eq!(int_div(-7, 2), Ok(-3));
        assert_eq!(int_div(7, -2), Ok(-3));
        assert_eq!(
            int_div(1, 0),
            Err(Stop::Runtime(RuntimeError::DivisionByZero))
        );
        assert_eq!(
            int_div(i64::MIN, -1),
            Err(Stop::Runtime(RuntimeError::IntegerOverflow))
        );
        assert_eq!(int_rem(-7, 2), Ok(-1));
        assert_eq!(int_rem(7, -2), Ok(1));
        assert_eq!(int_rem(i64::MIN, -1), Ok(0));
        assert_eq!(
            int_rem(1, 0),
            Err(Stop::Runtime(RuntimeError::DivisionByZero))
        );
        assert_eq!(
            int_add(i64::MAX, 1),
            Err(Stop::Runtime(RuntimeError::IntegerOverflow))
        );
        assert_eq!(
            int_mul(i64::MIN, -1),
            Err(Stop::Runtime(RuntimeError::IntegerOverflow))
        );
        assert_eq!(
            int_neg(i64::MIN),
            Err(Stop::Runtime(RuntimeError::IntegerOverflow))
        );
    }

    #[test]
    fn operator_functions_reject_wrong_arity_and_argument_kinds() {
        let mut heap = Heap::new();
        assert!(matches!(
            add_int(&mut heap, &[Value::Int(1)]),
            Err(Stop::Internal(_))
        ));
        assert!(matches!(
            add_int(&mut heap, &[Value::Int(1), Value::Bool(true)]),
            Err(Stop::Internal(_))
        ));
    }

    #[test]
    fn arithmetic_and_comparison_functions_return_values() {
        let mut heap = Heap::new();
        assert_eq!(
            add_int(&mut heap, &[Value::Int(2), Value::Int(3)])
                .unwrap()
                .as_int(),
            Some(5)
        );
        assert_eq!(
            add_float(&mut heap, &[Value::Float(2.0), Value::Float(3.0)])
                .unwrap()
                .as_float(),
            Some(5.0)
        );
        assert_eq!(
            div_float(&mut heap, &[Value::Float(1.0), Value::Float(0.0)])
                .unwrap()
                .as_float(),
            Some(f64::INFINITY)
        );
        assert_eq!(
            mul_int(&mut heap, &[Value::Int(2), Value::Int(4)])
                .unwrap()
                .as_int(),
            Some(8)
        );
        assert_eq!(
            rem_int(&mut heap, &[Value::Int(-7), Value::Int(2)])
                .unwrap()
                .as_int(),
            Some(-1)
        );
        assert_eq!(
            lt_float(&mut heap, &[Value::Float(f64::NAN), Value::Float(1.0)])
                .unwrap()
                .as_bool(),
            Some(false)
        );
        let accented = heap.string("é");
        let ascii = heap.string("z");
        assert_eq!(
            lt_string(&mut heap, &[accented, ascii]).unwrap().as_bool(),
            Some(false)
        );
        let left = heap.string("a");
        let right = heap.string("b");
        assert_eq!(
            lt_string(&mut heap, &[left, right]).unwrap().as_bool(),
            Some(true)
        );
        assert_eq!(
            ge_char(&mut heap, &[Value::Char('é'), Value::Char('z')])
                .unwrap()
                .as_bool(),
            Some(true)
        );
    }

    #[test]
    fn equality_uses_float_and_structural_value_semantics() {
        let mut heap = Heap::new();
        assert_eq!(
            eq(&mut heap, &[Value::Float(0.0), Value::Float(-0.0)],)
                .unwrap()
                .as_bool(),
            Some(true)
        );
        assert_eq!(
            eq(&mut heap, &[Value::Float(f64::NAN), Value::Float(f64::NAN)],)
                .unwrap()
                .as_bool(),
            Some(false)
        );
        assert_eq!(
            ne(&mut heap, &[Value::Float(f64::NAN), Value::Float(f64::NAN)],)
                .unwrap()
                .as_bool(),
            Some(true)
        );
        let left = heap.ctor(0, vec![Value::Int(7)]);
        let right = heap.ctor(0, vec![Value::Int(7)]);
        assert_eq!(eq(&mut heap, &[left, right]).unwrap().as_bool(), Some(true));

        let function = heap.func_proto(ProtoIdx(0), Vec::new());
        assert!(matches!(
            eq(&mut heap, &[function.clone(), function]),
            Err(Stop::Internal(_))
        ));
    }

    #[test]
    fn string_concatenation_checks_numeric_size_before_allocation() {
        let limit = usize::try_from(MAX_STRING_BYTES).unwrap();
        assert_eq!(checked_concat_size(2, 3), Ok(5));
        assert_eq!(
            checked_concat_size(limit, 1),
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "+",
                size: MAX_STRING_BYTES + 1,
                unit: SizeUnit::Bytes,
                limit: MAX_STRING_BYTES,
            }))
        );
        assert_eq!(
            checked_concat_size(usize::MAX, 1),
            Err(Stop::Resource(ResourceError::ValueTooLarge {
                function: "+",
                size: u64::MAX,
                unit: SizeUnit::Bytes,
                limit: MAX_STRING_BYTES,
            }))
        );

        let mut heap = Heap::new();
        let result = string_concat(&mut heap, "あ", "b").unwrap();
        assert_eq!(result.as_str(), Some("あb"));
    }
}
