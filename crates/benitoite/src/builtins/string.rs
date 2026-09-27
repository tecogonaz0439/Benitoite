//! 文字列の位置、検索、分割、連結、変換を行う組み込み関数（設計書 01-04「String」、03-06「String」）。

use crate::runtime::heap::Heap;
use crate::runtime::value::{ListRef, Value};
use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop};

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("String builtin received invalid arguments"))
}

fn internal_error(reason: &'static str) -> Stop {
    Stop::Internal(String::from(reason))
}

fn one_string(args: &[Value]) -> Result<&str, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_str)
        .ok_or_else(invalid_arguments)
}

fn two_strings(args: &[Value]) -> Result<(&str, &str), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(first) = args.first().and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    let Some(second) = args.get(1).and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    Ok((first, second))
}

fn string_and_int(args: &[Value]) -> Result<(&str, i64), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(string) = args.first().and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    let Some(integer) = args.get(1).and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    Ok((string, integer))
}

fn string_and_two_ints(args: &[Value]) -> Result<(&str, i64, i64), Stop> {
    if args.len() != 3 {
        return Err(invalid_arguments());
    }
    let Some(string) = args.first().and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    let Some(start) = args.get(1).and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    let Some(end) = args.get(2).and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    Ok((string, start, end))
}

fn three_strings(args: &[Value]) -> Result<(&str, &str, &str), Stop> {
    if args.len() != 3 {
        return Err(invalid_arguments());
    }
    let Some(first) = args.first().and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    let Some(second) = args.get(1).and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    let Some(third) = args.get(2).and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    Ok((first, second, third))
}

fn one_list(args: &[Value]) -> Result<&ListRef, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_list)
        .ok_or_else(invalid_arguments)
}

fn list_and_string(args: &[Value]) -> Result<(&ListRef, &str), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(list) = args.first().and_then(Value::as_list) else {
        return Err(invalid_arguments());
    };
    let Some(string) = args.get(1).and_then(Value::as_str) else {
        return Err(invalid_arguments());
    };
    Ok((list, string))
}

fn some(heap: &mut Heap, value: Value) -> Value {
    heap.ctor(0, vec![value])
}

fn none(heap: &mut Heap) -> Value {
    heap.ctor(1, Vec::new())
}

fn value_too_large(function: &'static str, size: u64, unit: SizeUnit, limit: u64) -> Stop {
    Stop::Resource(ResourceError::ValueTooLarge {
        function,
        size,
        unit,
        limit,
    })
}

fn checked_string_capacity(function: &'static str, size: Option<i64>) -> Result<usize, Stop> {
    let Some(size) = size else {
        return Err(value_too_large(
            function,
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    };
    let size = u64::try_from(size).map_err(|_| internal_error("String size became negative"))?;
    if size > MAX_STRING_BYTES {
        return Err(value_too_large(
            function,
            size,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    }
    usize::try_from(size).map_err(|_| internal_error("String size does not fit usize"))
}

fn check_list_length(function: &'static str, length: usize) -> Result<(), Stop> {
    let size = u64::try_from(length).unwrap_or(u64::MAX);
    if size > MAX_LIST_LEN {
        return Err(value_too_large(
            function,
            size,
            SizeUnit::Elements,
            MAX_LIST_LEN,
        ));
    }
    Ok(())
}

fn byte_length_as_int(length: usize) -> Result<i64, Stop> {
    i64::try_from(length).map_err(|_| internal_error("String length does not fit Int"))
}

/// UTF-8 で符号化したバイト数を返す。
pub fn byte_length(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let string = one_string(args)?;
    Ok(Value::Int(byte_length_as_int(string.len())?))
}

/// バイト位置の半開区間を切り出す。範囲や文字境界が正しくなければ `None` を返す。
pub fn byte_slice(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, start, end) = string_and_two_ints(args)?;
    if start < 0 || end < start {
        return Ok(none(heap));
    }
    let (Ok(start), Ok(end)) = (usize::try_from(start), usize::try_from(end)) else {
        return Ok(none(heap));
    };
    if end > string.len() || !string.is_char_boundary(start) || !string.is_char_boundary(end) {
        return Ok(none(heap));
    }
    let Some(slice) = string.get(start..end) else {
        return Ok(none(heap));
    };
    let value = heap.string(slice);
    Ok(some(heap, value))
}

/// Unicode スカラー値の個数を返す。
pub fn char_count(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let string = one_string(args)?;
    Ok(Value::Int(byte_length_as_int(string.chars().count())?))
}

/// 文字位置のスカラー値を返す。範囲外なら `None` を返す。
pub fn char_at(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, index) = string_and_int(args)?;
    let Some(index) = usize::try_from(index).ok() else {
        return Ok(none(heap));
    };
    match string.chars().nth(index) {
        Some(character) => Ok(some(heap, Value::Char(character))),
        None => Ok(none(heap)),
    }
}

fn char_byte_offset(string: &str, index: usize) -> usize {
    string
        .char_indices()
        .nth(index)
        .map_or(string.len(), |(offset, _)| offset)
}

/// 文字位置の半開区間を切り出す。範囲が正しくなければ `None` を返す。
pub fn char_slice(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, start, end) = string_and_two_ints(args)?;
    if start < 0 || end < start {
        return Ok(none(heap));
    }
    let (Ok(start), Ok(end)) = (usize::try_from(start), usize::try_from(end)) else {
        return Ok(none(heap));
    };
    let char_count = string.chars().count();
    if end > char_count {
        return Ok(none(heap));
    }
    let start_byte = char_byte_offset(string, start);
    let end_byte = char_byte_offset(string, end);
    let Some(slice) = string.get(start_byte..end_byte) else {
        return Ok(none(heap));
    };
    let value = heap.string(slice);
    Ok(some(heap, value))
}

/// 空文字列かを返す。
pub fn is_empty(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    Ok(Value::Bool(one_string(args)?.is_empty()))
}

/// 部分文字列を含むかを返す。空の部分文字列は常に含む。
pub fn contains(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, substring) = two_strings(args)?;
    Ok(Value::Bool(string.contains(substring)))
}

/// 指定した文字列で始まるかを返す。
pub fn starts_with(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, prefix) = two_strings(args)?;
    Ok(Value::Bool(string.starts_with(prefix)))
}

/// 指定した文字列で終わるかを返す。
pub fn ends_with(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, suffix) = two_strings(args)?;
    Ok(Value::Bool(string.ends_with(suffix)))
}

/// 最初に見つかる部分文字列のバイト位置を返す。見つからなければ `None` を返す。
pub fn byte_index_of(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, substring) = two_strings(args)?;
    match string.find(substring) {
        Some(index) => Ok(some(heap, Value::Int(byte_length_as_int(index)?))),
        None => Ok(none(heap)),
    }
}

/// 区切り文字列または Unicode スカラー値ごとに分けたリストを作る。
pub fn split(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, separator) = two_strings(args)?;
    let count = if separator.is_empty() {
        string.chars().count()
    } else {
        string.split(separator).count()
    };
    check_list_length("String.split", count)?;

    let mut values = Vec::with_capacity(count);
    if separator.is_empty() {
        for character in string.chars() {
            let mut buffer = [0; 4];
            values.push(heap.string(character.encode_utf8(&mut buffer)));
        }
    } else {
        for part in string.split(separator) {
            values.push(heap.string(part));
        }
    }
    heap.list_from_vec(values, "String.split")
}

/// LF ごとに分け、各行の末尾にある CR を一つ取り除いたリストを作る。
pub fn lines(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let string = one_string(args)?;
    let count = if string.is_empty() {
        0
    } else {
        let segments = string.split('\n').count();
        if string.ends_with('\n') {
            segments.saturating_sub(1)
        } else {
            segments
        }
    };
    check_list_length("String.lines", count)?;

    let mut values = Vec::with_capacity(count);
    for line in string.split('\n').take(count) {
        values.push(heap.string(line.strip_suffix('\r').unwrap_or(line)));
    }
    heap.list_from_vec(values, "String.lines")
}

/// 文字列のリストを区切り文字列でつないだ新しい文字列を作る。
pub fn join(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, separator) = list_and_string(args)?;
    let separator_size = byte_length_as_int(separator.len())?;
    let mut item_size = 0_i64;
    for item in list.iter() {
        let Some(string) = item.as_str() else {
            return Err(invalid_arguments());
        };
        let size = byte_length_as_int(string.len())?;
        let Some(total) = item_size.checked_add(size) else {
            return Err(value_too_large(
                "String.join",
                u64::MAX,
                SizeUnit::Bytes,
                MAX_STRING_BYTES,
            ));
        };
        item_size = total;
    }
    let separator_count = if list.is_empty() {
        0
    } else {
        i64::from(list.len()).saturating_sub(1)
    };
    let Some(separator_size) = separator_size.checked_mul(separator_count) else {
        return Err(value_too_large(
            "String.join",
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    };
    let Some(result_size) = item_size.checked_add(separator_size) else {
        return Err(value_too_large(
            "String.join",
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    };
    let capacity = checked_string_capacity("String.join", Some(result_size))?;

    let mut result = String::with_capacity(capacity);
    let mut first = true;
    for item in list.iter() {
        let Some(string) = item.as_str() else {
            return Err(invalid_arguments());
        };
        if !first {
            result.push_str(separator);
        }
        result.push_str(string);
        first = false;
    }
    Ok(heap.string(&result))
}

/// 先頭と末尾から ASCII の空白四文字だけを取り除く。
pub fn trim(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let string = one_string(args)?;
    let trimmed = string.trim_matches(|character| matches!(character, ' ' | '\t' | '\n' | '\r'));
    Ok(heap.string(trimmed))
}

/// 空でない部分文字列の重ならない出現をすべて置き換える。
pub fn replace(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, old, new) = three_strings(args)?;
    if old.is_empty() {
        return Ok(heap.string(string));
    }

    let occurrence_count = byte_length_as_int(string.matches(old).count())?;
    let string_size = byte_length_as_int(string.len())?;
    let old_size = byte_length_as_int(old.len())?;
    let new_size = byte_length_as_int(new.len())?;
    let Some(removed_size) = occurrence_count.checked_mul(old_size) else {
        return Err(value_too_large(
            "String.replace",
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    };
    let Some(added_size) = occurrence_count.checked_mul(new_size) else {
        return Err(value_too_large(
            "String.replace",
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    };
    let Some(result_size) = string_size
        .checked_sub(removed_size)
        .and_then(|size| size.checked_add(added_size))
    else {
        return Err(value_too_large(
            "String.replace",
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    };
    checked_string_capacity("String.replace", Some(result_size))?;

    let result = string.replace(old, new);
    Ok(heap.string(&result))
}

/// 文字列を正の回数だけ繰り返す。回数が 0 以下なら空文字列を返す。
pub fn repeat(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (string, count) = string_and_int(args)?;
    if count <= 0 || string.is_empty() {
        return Ok(heap.string(""));
    }

    let size = byte_length_as_int(string.len())?.checked_mul(count);
    checked_string_capacity("String.repeat", size)?;
    let repetitions = usize::try_from(count)
        .map_err(|_| internal_error("String repeat count does not fit usize"))?;
    let result = string.repeat(repetitions);
    Ok(heap.string(&result))
}

/// 文字列の Unicode スカラー値を並べたリストを作る。
pub fn chars(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let string = one_string(args)?;
    let count = string.chars().count();
    check_list_length("String.chars", count)?;
    let values: Vec<Value> = string.chars().map(Value::Char).collect();
    heap.list_from_vec(values, "String.chars")
}

/// Char のリストを UTF-8 文字列に連結する。
pub fn from_chars(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    let mut size = 0_i64;
    for item in list.iter() {
        let Some(character) = item.as_char() else {
            return Err(invalid_arguments());
        };
        let character_size = byte_length_as_int(character.len_utf8())?;
        let Some(total) = size.checked_add(character_size) else {
            return Err(value_too_large(
                "String.fromChars",
                u64::MAX,
                SizeUnit::Bytes,
                MAX_STRING_BYTES,
            ));
        };
        size = total;
    }
    let capacity = checked_string_capacity("String.fromChars", Some(size))?;

    let mut result = String::with_capacity(capacity);
    for item in list.iter() {
        let Some(character) = item.as_char() else {
            return Err(invalid_arguments());
        };
        result.push(character);
    }
    Ok(heap.string(&result))
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
    // String の公開 PureFn が返す値と資源エラーを確かめる（設計書 07-03「テストの設計の原則」）。
    use crate::runtime::heap::Heap;
    use crate::runtime::value::Value;
    use crate::runtime::{MAX_STRING_BYTES, ResourceError, SizeUnit, Stop};

    use super::{
        byte_index_of, byte_length, byte_slice, char_at, char_count, char_slice, chars, contains,
        ends_with, from_chars, is_empty, join, lines, repeat, replace, split, starts_with, trim,
    };

    fn string_args(heap: &mut Heap, strings: &[&str]) -> Vec<Value> {
        strings.iter().map(|string| heap.string(string)).collect()
    }

    fn assert_option_string(value: &Value, expected: Option<&str>) {
        let (tag, fields) = value.as_ctor().unwrap();
        match expected {
            Some(expected) => {
                assert_eq!(tag, 0);
                assert_eq!(fields.len(), 1);
                assert_eq!(fields.first().and_then(Value::as_str), Some(expected));
            }
            None => {
                assert_eq!(tag, 1);
                assert!(fields.is_empty());
            }
        }
    }

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

    fn list_strings(value: &Value) -> Vec<String> {
        value
            .as_list()
            .unwrap()
            .iter()
            .map(|item| item.as_str().unwrap().to_owned())
            .collect()
    }

    fn assert_value_too_large(
        result: Result<Value, Stop>,
        function: &'static str,
        size: u64,
        unit: SizeUnit,
        limit: u64,
    ) {
        let Err(Stop::Resource(ResourceError::ValueTooLarge {
            function: actual_function,
            size: actual_size,
            unit: actual_unit,
            limit: actual_limit,
        })) = result
        else {
            panic!("expected a value-too-large resource error");
        };
        assert_eq!(actual_function, function);
        assert_eq!(actual_size, size);
        assert_eq!(actual_unit, unit);
        assert_eq!(actual_limit, limit);
    }

    #[test]
    fn positions_use_bytes_and_unicode_scalar_values_as_named() {
        let mut heap = Heap::new();
        let string = heap.string("aあb");
        assert_eq!(
            byte_length(&mut heap, std::slice::from_ref(&string))
                .unwrap()
                .as_int(),
            Some(5)
        );
        assert_eq!(
            char_count(&mut heap, std::slice::from_ref(&string))
                .unwrap()
                .as_int(),
            Some(3)
        );
        assert_option_char(
            &char_at(&mut heap, &[string.clone(), Value::Int(1)]).unwrap(),
            Some('あ'),
        );
        for index in [3, -1] {
            assert_option_char(
                &char_at(&mut heap, &[string.clone(), Value::Int(index)]).unwrap(),
                None,
            );
        }

        assert_option_string(
            &byte_slice(&mut heap, &[string.clone(), Value::Int(1), Value::Int(4)]).unwrap(),
            Some("あ"),
        );
        for (start, end) in [(-1, 1), (1, 2), (2, 1), (0, 6)] {
            assert_option_string(
                &byte_slice(
                    &mut heap,
                    &[string.clone(), Value::Int(start), Value::Int(end)],
                )
                .unwrap(),
                None,
            );
        }
        assert_option_string(
            &char_slice(&mut heap, &[string.clone(), Value::Int(1), Value::Int(3)]).unwrap(),
            Some("あb"),
        );
        assert_option_string(
            &char_slice(&mut heap, &[string.clone(), Value::Int(3), Value::Int(3)]).unwrap(),
            Some(""),
        );
        assert_option_string(
            &char_slice(&mut heap, &[string.clone(), Value::Int(-1), Value::Int(1)]).unwrap(),
            None,
        );
        assert_option_string(
            &char_slice(&mut heap, &[string.clone(), Value::Int(2), Value::Int(1)]).unwrap(),
            None,
        );
        assert_option_string(
            &char_slice(&mut heap, &[string, Value::Int(0), Value::Int(4)]).unwrap(),
            None,
        );
    }

    #[test]
    fn searching_and_prefix_suffix_checks_follow_string_semantics() {
        let mut heap = Heap::new();
        let args = string_args(&mut heap, &["aあb", "b"]);
        assert_option_int(&byte_index_of(&mut heap, &args).unwrap(), Some(4));
        let args = string_args(&mut heap, &["abc", ""]);
        assert_option_int(&byte_index_of(&mut heap, &args).unwrap(), Some(0));
        let args = string_args(&mut heap, &["abc", "x"]);
        assert_option_int(&byte_index_of(&mut heap, &args).unwrap(), None);
        let args = string_args(&mut heap, &["abc", ""]);
        assert_eq!(contains(&mut heap, &args).unwrap().as_bool(), Some(true));
        let args = string_args(&mut heap, &[""]);
        assert_eq!(is_empty(&mut heap, &args).unwrap().as_bool(), Some(true));
        let args = string_args(&mut heap, &["abc"]);
        assert_eq!(is_empty(&mut heap, &args).unwrap().as_bool(), Some(false));
        let args = string_args(&mut heap, &["abc", "ab"]);
        assert_eq!(starts_with(&mut heap, &args).unwrap().as_bool(), Some(true));
        let args = string_args(&mut heap, &["abc", "bc"]);
        assert_eq!(ends_with(&mut heap, &args).unwrap().as_bool(), Some(true));
    }

    #[test]
    fn split_preserves_empty_fields_and_handles_empty_separator_by_scalar() {
        let mut heap = Heap::new();
        for (string, separator, expected) in [
            ("a,,b", ",", vec!["a", "", "b"]),
            ("", ",", vec![""]),
            (",a,", ",", vec!["", "a", ""]),
            ("aあ", "", vec!["a", "あ"]),
            ("", "", vec![]),
            ("aaa", "aa", vec!["", "a"]),
        ] {
            let args = string_args(&mut heap, &[string, separator]);
            let actual = split(&mut heap, &args).unwrap();
            assert_eq!(list_strings(&actual), expected);
        }
    }

    #[test]
    fn lines_split_only_on_lf_and_remove_one_trailing_cr() {
        let mut heap = Heap::new();
        for (string, expected) in [
            ("a\r\nb\n", vec!["a", "b"]),
            ("a\n\nb", vec!["a", "", "b"]),
            ("", vec![]),
            ("a", vec!["a"]),
            ("a\r", vec!["a"]),
            ("\n", vec![""]),
        ] {
            let args = string_args(&mut heap, &[string]);
            let actual = lines(&mut heap, &args).unwrap();
            assert_eq!(list_strings(&actual), expected);
        }
    }

    #[test]
    fn join_and_trim_follow_their_byte_and_ascii_rules() {
        let mut heap = Heap::new();
        let items = vec![heap.string("a"), heap.string("b"), heap.string("c")];
        let list = heap.list_from_vec(items, "test").unwrap();
        let args = vec![list, heap.string(", ")];
        assert_eq!(join(&mut heap, &args).unwrap().as_str(), Some("a, b, c"));
        let empty = heap.list_from_vec(Vec::new(), "test").unwrap();
        let args = vec![empty, heap.string(",")];
        assert_eq!(join(&mut heap, &args).unwrap().as_str(), Some(""));
        let args = string_args(&mut heap, &[" \t x \r\n"]);
        assert_eq!(trim(&mut heap, &args).unwrap().as_str(), Some("x"));
        let args = string_args(&mut heap, &["\u{3000}x"]);
        assert_eq!(trim(&mut heap, &args).unwrap().as_str(), Some("\u{3000}x"));
    }

    #[test]
    fn replace_counts_non_overlapping_matches_and_ignores_empty_old_text() {
        let mut heap = Heap::new();
        for (string, old, new, expected) in [
            ("aaa", "a", "bb", "bbbbbb"),
            ("aaa", "aa", "b", "ba"),
            ("abc", "", "x", "abc"),
        ] {
            let args = string_args(&mut heap, &[string, old, new]);
            assert_eq!(replace(&mut heap, &args).unwrap().as_str(), Some(expected));
        }
    }

    #[test]
    fn repeat_checks_result_size_before_creating_a_string() {
        let mut heap = Heap::new();
        let source = heap.string("ab");
        assert_eq!(
            repeat(&mut heap, &[source.clone(), Value::Int(3)])
                .unwrap()
                .as_str(),
            Some("ababab")
        );
        assert_eq!(
            repeat(&mut heap, &[source.clone(), Value::Int(0)])
                .unwrap()
                .as_str(),
            Some("")
        );
        assert_eq!(
            repeat(&mut heap, &[source.clone(), Value::Int(-1)])
                .unwrap()
                .as_str(),
            Some("")
        );
        let before_errors = heap.stats();
        assert_value_too_large(
            repeat(&mut heap, &[source.clone(), Value::Int(536_870_913)]),
            "String.repeat",
            1_073_741_826,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        );
        assert_value_too_large(
            repeat(&mut heap, &[source, Value::Int(i64::MAX)]),
            "String.repeat",
            u64::MAX,
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        );
        assert_eq!(heap.stats(), before_errors);
    }

    #[test]
    fn chars_and_from_chars_preserve_scalar_order() {
        let mut heap = Heap::new();
        let args = string_args(&mut heap, &["aあ"]);
        let characters = chars(&mut heap, &args).unwrap();
        let character_values: Vec<char> = characters
            .as_list()
            .unwrap()
            .iter()
            .map(|item| item.as_char().unwrap())
            .collect();
        assert_eq!(character_values, vec!['a', 'あ']);
        let input = heap
            .list_from_vec(vec![Value::Char('a'), Value::Char('あ')], "test")
            .unwrap();
        assert_eq!(
            from_chars(&mut heap, &[input]).unwrap().as_str(),
            Some("aあ")
        );
    }
}
