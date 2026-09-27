//! Char の整数・文字列変換と ASCII 判定（設計書 01-04「Char」、03-06「Char」）。

use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::value::Value;

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("Char builtin received invalid arguments"))
}

fn one_char(args: &[Value]) -> Result<char, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_char)
        .ok_or_else(invalid_arguments)
}

fn one_int(args: &[Value]) -> Result<i64, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_int)
        .ok_or_else(invalid_arguments)
}

fn some(heap: &mut Heap, value: Value) -> Value {
    heap.ctor(0, vec![value])
}

fn none(heap: &mut Heap) -> Value {
    heap.ctor(1, Vec::new())
}

/// Char の Unicode スカラー値を Int で返す。
pub fn to_int(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = one_char(args)?;
    Ok(Value::Int(i64::from(u32::from(value))))
}

/// Int が Unicode スカラー値なら Char として返す。
pub fn from_int(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = one_int(args)?;
    let character = u32::try_from(value).ok().and_then(char::from_u32);
    match character {
        Some(character) => Ok(some(heap, Value::Char(character))),
        None => Ok(none(heap)),
    }
}

/// Char 一文字からなる String を作る。
pub fn to_string(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = one_char(args)?;
    Ok(heap.string(&value.to_string()))
}

/// ASCII の 0 から 9 までの文字かを返す。
pub fn is_ascii_digit(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Bool(one_char(args)?.is_ascii_digit()))
}

/// U+0020・U+0009・U+000A・U+000D のいずれかかを返す。
pub fn is_ascii_whitespace(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let value = one_char(args)?;
    Ok(Value::Bool(matches!(value, ' ' | '\t' | '\n' | '\r')))
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
    // Char の変換と ASCII 分類を公開関数で確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::runtime::Stop;
    use crate::runtime::heap::Heap;
    use crate::runtime::value::Value;

    use super::{from_int, is_ascii_digit, is_ascii_whitespace, to_int, to_string};

    fn assert_option_char(value: &Value, expected: Option<char>) {
        let (tag, fields) = value.as_ctor().unwrap();
        match expected {
            Some(expected) => {
                assert_eq!(tag, 0);
                assert_eq!(fields.len(), 1);
                assert_eq!(fields.first().and_then(Value::as_char), Some(expected));
            }
            None => {
                assert_eq!(tag, 1);
                assert!(fields.is_empty());
            }
        }
    }

    #[test]
    fn integer_conversion_accepts_only_unicode_scalar_values() {
        let mut heap = Heap::new();
        for (value, expected) in [
            (0x41_i64, Some('A')),
            (0xD800, None),
            (0x110000, None),
            (0x10FFFF, Some('\u{10FFFF}')),
            (-1, None),
        ] {
            let actual = from_int(&mut heap, &[Value::Int(value)]).unwrap();
            assert_option_char(&actual, expected);
        }
        assert_eq!(
            to_int(&mut heap, &[Value::Char('あ')]).unwrap().as_int(),
            Some(i64::from(u32::from('あ')))
        );
    }

    #[test]
    fn string_conversion_and_ascii_classification_match_the_named_sets() {
        let mut heap = Heap::new();
        assert_eq!(
            to_string(&mut heap, &[Value::Char('あ')]).unwrap().as_str(),
            Some("あ")
        );
        for value in ['0', '5', '9'] {
            assert_eq!(
                is_ascii_digit(&mut heap, &[Value::Char(value)])
                    .unwrap()
                    .as_bool(),
                Some(true)
            );
        }
        assert_eq!(
            is_ascii_digit(&mut heap, &[Value::Char('３')])
                .unwrap()
                .as_bool(),
            Some(false)
        );
        for value in [' ', '\t', '\n', '\r'] {
            assert_eq!(
                is_ascii_whitespace(&mut heap, &[Value::Char(value)])
                    .unwrap()
                    .as_bool(),
                Some(true)
            );
        }
        for value in ['\u{0C}', '\u{00A0}'] {
            assert_eq!(
                is_ascii_whitespace(&mut heap, &[Value::Char(value)])
                    .unwrap()
                    .as_bool(),
                Some(false)
            );
        }
        assert!(matches!(
            to_int(&mut heap, &[Value::Bool(true)]),
            Err(Stop::Internal(_))
        ));
    }
}
