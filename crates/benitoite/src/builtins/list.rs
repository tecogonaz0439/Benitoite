//! List モジュールの組み込み関数（設計書 03-06「List」）。

use std::cmp::Ordering;

use crate::runtime::heap::Heap;
use crate::runtime::value::{ListRef, Value, values_equal};
use crate::runtime::{MAX_LIST_LEN, ResourceError, SizeUnit, Stop};

fn invalid_arguments() -> Stop {
    Stop::Internal(String::from("List builtin received invalid arguments"))
}

fn internal_error(message: &'static str) -> Stop {
    Stop::Internal(String::from(message))
}

fn one_list(args: &[Value]) -> Result<&ListRef, Stop> {
    if args.len() != 1 {
        return Err(invalid_arguments());
    }
    args.first()
        .and_then(Value::as_list)
        .ok_or_else(invalid_arguments)
}

fn list_and_int(args: &[Value]) -> Result<(&ListRef, i64), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(list) = args.first().and_then(Value::as_list) else {
        return Err(invalid_arguments());
    };
    let Some(index) = args.get(1).and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    Ok((list, index))
}

fn list_and_value(args: &[Value]) -> Result<(&ListRef, &Value), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(list) = args.first().and_then(Value::as_list) else {
        return Err(invalid_arguments());
    };
    let Some(value) = args.get(1) else {
        return Err(invalid_arguments());
    };
    Ok((list, value))
}

fn two_lists(args: &[Value]) -> Result<(&ListRef, &ListRef), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(left) = args.first().and_then(Value::as_list) else {
        return Err(invalid_arguments());
    };
    let Some(right) = args.get(1).and_then(Value::as_list) else {
        return Err(invalid_arguments());
    };
    Ok((left, right))
}

fn two_ints(args: &[Value]) -> Result<(i64, i64), Stop> {
    if args.len() != 2 {
        return Err(invalid_arguments());
    }
    let Some(start) = args.first().and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    let Some(end) = args.get(1).and_then(Value::as_int) else {
        return Err(invalid_arguments());
    };
    Ok((start, end))
}

fn some(heap: &mut Heap, value: Value) -> Value {
    heap.ctor(0, vec![value])
}

fn none(heap: &mut Heap) -> Value {
    heap.ctor(1, Vec::new())
}

fn value_too_large(function: &'static str, size: u64) -> Stop {
    Stop::Resource(ResourceError::ValueTooLarge {
        function,
        size,
        unit: SizeUnit::Elements,
        limit: MAX_LIST_LEN,
    })
}

fn ensure_list_size(function: &'static str, size: u64) -> Result<(), Stop> {
    if size > MAX_LIST_LEN {
        return Err(value_too_large(function, size));
    }
    Ok(())
}

fn cons_list(
    heap: &mut Heap,
    head: Value,
    tail: &ListRef,
    function: &'static str,
) -> Result<ListRef, Stop> {
    let value = heap.cons(head, tail, function)?;
    value
        .as_list()
        .cloned()
        .ok_or_else(|| internal_error("List cons returned a non-list value"))
}

/// リストの長さを返す。
pub fn length(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    Ok(Value::Int(i64::from(list.len())))
}

/// リストが空かを返す。
pub fn is_empty(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    Ok(Value::Bool(list.is_empty()))
}

/// 先頭の要素を Some に入れて返し、空なら None を返す。
pub fn head(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    match list.head() {
        Some(value) => Ok(some(heap, value.clone())),
        None => Ok(none(heap)),
    }
}

/// 先頭を除いたリストを Some に入れて返し、空なら None を返す。
pub fn tail(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    match list.tail() {
        Some(rest) => Ok(some(heap, Value::List(rest.clone()))),
        None => Ok(none(heap)),
    }
}

/// 0 から数えた位置の要素を Some に入れて返し、範囲外なら None を返す。
pub fn get(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, index) = list_and_int(args)?;
    if index < 0 || index >= i64::from(list.len()) {
        return Ok(none(heap));
    }

    let mut current = list;
    for _ in 0..index {
        let Some(rest) = current.tail() else {
            return Err(internal_error("List.get reached the end before its length"));
        };
        current = rest;
    }
    match current.head() {
        Some(value) => Ok(some(heap, value.clone())),
        None => Err(internal_error(
            "List.get found no element within its length",
        )),
    }
}

/// 要素をリストの先頭に加える。
pub fn prepend(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, value) = list_and_value(args)?;
    heap.cons(value.clone(), list, "List.prepend")
}

/// 要素をリストの末尾に加える。
pub fn append(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, value) = list_and_value(args)?;
    let Some(size) = u64::from(list.len()).checked_add(1) else {
        return Err(value_too_large("List.append", u64::MAX));
    };
    ensure_list_size("List.append", size)?;

    let mut items: Vec<Value> = list.iter().cloned().collect();
    items.push(value.clone());
    heap.list_from_vec(items, "List.append")
}

/// 左のリストの後ろに右のリストを続ける。
pub fn concat(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (left, right) = two_lists(args)?;
    let Some(size) = u64::from(left.len()).checked_add(u64::from(right.len())) else {
        return Err(value_too_large("List.concat", u64::MAX));
    };
    ensure_list_size("List.concat", size)?;

    let mut items: Vec<Value> = left.iter().cloned().collect();
    let mut result = right.clone();
    while let Some(item) = items.pop() {
        result = cons_list(heap, item, &result, "List.concat")?;
    }
    Ok(Value::List(result))
}

/// 要素の順を逆にしたリストを作る。
pub fn reverse(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    let mut result = ListRef::empty();
    for item in list.iter() {
        result = cons_list(heap, item.clone(), &result, "List.reverse")?;
    }
    Ok(Value::List(result))
}

/// 先頭から n 個を返す。n が 0 以下なら空、長さ以上なら元のリストを返す。
pub fn take(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, count) = list_and_int(args)?;
    if count <= 0 {
        return Ok(Value::List(ListRef::empty()));
    }
    if count >= i64::from(list.len()) {
        return Ok(Value::List(list.clone()));
    }

    let count = u32::try_from(count)
        .map_err(|_| internal_error("List.take count did not fit the list length"))?;
    let mut items = Vec::new();
    let mut current = list;
    for _ in 0..count {
        let Some(item) = current.head() else {
            return Err(internal_error("List.take reached the end before its count"));
        };
        items.push(item.clone());
        let Some(rest) = current.tail() else {
            return Err(internal_error("List.take found no tail before its count"));
        };
        current = rest;
    }
    heap.list_from_vec(items, "List.take")
}

/// 先頭から n 個を除いたリストを返す。既存のセルを共有する。
pub fn drop(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, count) = list_and_int(args)?;
    if count <= 0 {
        return Ok(Value::List(list.clone()));
    }
    if count >= i64::from(list.len()) {
        return Ok(Value::List(ListRef::empty()));
    }

    let mut current = list;
    for _ in 0..count {
        let Some(rest) = current.tail() else {
            return Err(internal_error("List.drop reached the end before its count"));
        };
        current = rest;
    }
    Ok(Value::List(current.clone()))
}

/// start 以上 end 未満の整数を昇順に並べたリストを作る。
pub fn range(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (start, end) = two_ints(args)?;
    if end <= start {
        return Ok(Value::List(ListRef::empty()));
    }

    let size = match end.checked_sub(start) {
        Some(size) => u64::try_from(size)
            .map_err(|_| internal_error("List.range produced a negative length"))?,
        None => return Err(value_too_large("List.range", start.abs_diff(end))),
    };
    ensure_list_size("List.range", size)?;

    let mut current = end;
    let mut result = ListRef::empty();
    while current > start {
        let Some(value) = current.checked_sub(1) else {
            return Err(internal_error(
                "List.range could not decrement its endpoint",
            ));
        };
        current = value;
        result = cons_list(heap, Value::Int(value), &result, "List.range")?;
    }
    Ok(Value::List(result))
}

/// 等値の要素が含まれるかを返す。
pub fn contains(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let (list, value) = list_and_value(args)?;
    for item in list.iter() {
        if values_equal(item, value)? {
            return Ok(Value::Bool(true));
        }
    }
    Ok(Value::Bool(false))
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum SortKind {
    Int,
    Float,
    String,
    Char,
}

fn sort_kind(value: &Value) -> Option<SortKind> {
    match value {
        Value::Int(_) => Some(SortKind::Int),
        Value::Float(_) => Some(SortKind::Float),
        Value::Str(_) => Some(SortKind::String),
        Value::Char(_) => Some(SortKind::Char),
        Value::Bool(_)
        | Value::Unit
        | Value::Func(_)
        | Value::Ctor(_)
        | Value::List(_)
        | Value::IoError(_) => None,
    }
}

fn compare_floats(left: f64, right: f64) -> Ordering {
    match (left.is_nan(), right.is_nan()) {
        (true, true) => Ordering::Equal,
        (true, false) => Ordering::Greater,
        (false, true) => Ordering::Less,
        (false, false) => match left.partial_cmp(&right) {
            Some(ordering) => ordering,
            None => Ordering::Equal,
        },
    }
}

fn compare_values(left: &Value, right: &Value, kind: SortKind) -> Ordering {
    match (kind, left, right) {
        (SortKind::Int, Value::Int(left), Value::Int(right)) => left.cmp(right),
        (SortKind::Float, Value::Float(left), Value::Float(right)) => compare_floats(*left, *right),
        (SortKind::String, Value::Str(left), Value::Str(right)) => {
            left.as_str().cmp(right.as_str())
        }
        (SortKind::Char, Value::Char(left), Value::Char(right)) => left.cmp(right),
        _ => Ordering::Equal,
    }
}

/// Int・Float・String・Char の要素を昇順かつ安定に並べ替える。
pub fn sort(heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    let mut items: Vec<Value> = list.iter().cloned().collect();
    let Some(kind) = items.first().and_then(sort_kind) else {
        if items.is_empty() {
            return heap.list_from_vec(items, "List.sort");
        }
        return Err(invalid_arguments());
    };
    if items.iter().any(|item| sort_kind(item) != Some(kind)) {
        return Err(invalid_arguments());
    }

    items.sort_by(|left, right| compare_values(left, right, kind));
    heap.list_from_vec(items, "List.sort")
}

/// 先頭を除いたリストを返す。空なら空のリストを返す。
pub fn drop_first(_heap: &mut Heap, args: &[Value]) -> Result<Value, Stop> {
    let list = one_list(args)?;
    match list.tail() {
        Some(rest) => Ok(Value::List(rest.clone())),
        None => Ok(Value::List(ListRef::empty())),
    }
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
    // 組み込み関数の値、構造共有、不変条件、上限を公開関数で確かめる（設計書 03-06「List の内部の表現」、07-03「テストの設計の原則」）。
    use crate::runtime::heap::Heap;
    use crate::runtime::value::{ListRef, Value};
    use crate::runtime::{MAX_LIST_LEN, ResourceError, SizeUnit, Stop};

    use super::{
        append, concat, contains, drop, drop_first, get, head, is_empty, length, prepend, range,
        reverse, sort, tail, take,
    };

    fn make_list(heap: &mut Heap, values: Vec<Value>) -> Value {
        heap.list_from_vec(values, "test").unwrap()
    }

    fn int_values(value: &Value) -> Vec<i64> {
        value
            .as_list()
            .unwrap()
            .iter()
            .map(|item| item.as_int().unwrap())
            .collect()
    }

    fn string_values(value: &Value) -> Vec<&str> {
        value
            .as_list()
            .unwrap()
            .iter()
            .map(|item| item.as_str().unwrap())
            .collect()
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

    fn assert_cell_lengths(value: &Value) {
        let mut current = value.as_list().unwrap();
        while !current.is_empty() {
            let rest = current.tail().unwrap();
            assert_eq!(current.len(), rest.len() + 1);
            current = rest;
        }
        assert_eq!(current.len(), 0);
    }

    #[test]
    fn accessors_and_get_follow_empty_and_index_boundaries() {
        let mut heap = Heap::new();
        let list = make_list(&mut heap, vec![Value::Int(10), Value::Int(20)]);
        let empty = make_list(&mut heap, Vec::new());

        assert_eq!(
            length(&mut heap, std::slice::from_ref(&list))
                .unwrap()
                .as_int(),
            Some(2)
        );
        assert_eq!(
            is_empty(&mut heap, std::slice::from_ref(&list))
                .unwrap()
                .as_bool(),
            Some(false)
        );
        assert_eq!(
            is_empty(&mut heap, std::slice::from_ref(&empty))
                .unwrap()
                .as_bool(),
            Some(true)
        );
        assert_option_int(
            &head(&mut heap, std::slice::from_ref(&list)).unwrap(),
            Some(10),
        );
        assert_option_int(
            &head(&mut heap, std::slice::from_ref(&empty)).unwrap(),
            None,
        );
        assert_option_int(
            &get(&mut heap, &[list.clone(), Value::Int(1)]).unwrap(),
            Some(20),
        );
        assert_option_int(
            &get(&mut heap, &[list.clone(), Value::Int(2)]).unwrap(),
            None,
        );
        assert_option_int(
            &get(&mut heap, &[list.clone(), Value::Int(-1)]).unwrap(),
            None,
        );

        let list_ref = list.as_list().unwrap();
        let expected_tail = list_ref.tail().unwrap();
        let actual_tail = tail(&mut heap, std::slice::from_ref(&list)).unwrap();
        let (tag, fields) = actual_tail.as_ctor().unwrap();
        assert_eq!(tag, 0);
        assert_eq!(fields.len(), 1);
        assert!(
            fields
                .first()
                .unwrap()
                .as_list()
                .unwrap()
                .same_cells(expected_tail)
        );
        assert_eq!(int_values(fields.first().unwrap()), vec![20]);
        let empty_tail = tail(&mut heap, std::slice::from_ref(&empty)).unwrap();
        let (tag, fields) = empty_tail.as_ctor().unwrap();
        assert_eq!(tag, 1);
        assert!(fields.is_empty());
    }

    #[test]
    fn take_drop_and_drop_first_preserve_the_required_cells() {
        let mut heap = Heap::new();
        let list = make_list(&mut heap, vec![Value::Int(1), Value::Int(2), Value::Int(3)]);
        let empty = ListRef::empty();
        let original = list.as_list().unwrap();

        let taken_empty = take(&mut heap, &[list.clone(), Value::Int(-1)]).unwrap();
        assert!(taken_empty.as_list().unwrap().is_empty());
        let taken_all = take(&mut heap, &[list.clone(), Value::Int(10)]).unwrap();
        assert!(taken_all.as_list().unwrap().same_cells(original));
        assert_eq!(
            int_values(&take(&mut heap, &[list.clone(), Value::Int(2)]).unwrap()),
            vec![1, 2]
        );

        assert!(
            drop(&mut heap, &[list.clone(), Value::Int(0)])
                .unwrap()
                .as_list()
                .unwrap()
                .same_cells(original)
        );
        assert!(
            drop(&mut heap, &[list.clone(), Value::Int(2)])
                .unwrap()
                .as_list()
                .unwrap()
                .same_cells(original.tail().unwrap().tail().unwrap())
        );
        assert!(
            drop(&mut heap, &[list.clone(), Value::Int(5)])
                .unwrap()
                .as_list()
                .unwrap()
                .same_cells(&empty)
        );
        assert!(
            drop_first(&mut heap, std::slice::from_ref(&list))
                .unwrap()
                .as_list()
                .unwrap()
                .same_cells(original.tail().unwrap())
        );
        assert!(
            drop_first(&mut heap, &[Value::List(empty.clone())])
                .unwrap()
                .as_list()
                .unwrap()
                .same_cells(&empty)
        );
    }

    #[test]
    fn rebuilding_operations_preserve_lengths_and_leave_inputs_unchanged() {
        let mut heap = Heap::new();
        let left = make_list(&mut heap, vec![Value::Int(3), Value::Int(1), Value::Int(2)]);
        let right = make_list(&mut heap, vec![Value::Int(4), Value::Int(5)]);
        let left_before = int_values(&left);
        let right_before = int_values(&right);

        let appended = append(&mut heap, &[left.clone(), Value::Int(9)]).unwrap();
        let joined = concat(&mut heap, &[left.clone(), right.clone()]).unwrap();
        let reversed = reverse(&mut heap, std::slice::from_ref(&left)).unwrap();
        let taken = take(&mut heap, &[left.clone(), Value::Int(2)]).unwrap();
        let ranged = range(&mut heap, &[Value::Int(2), Value::Int(5)]).unwrap();
        let sorted = sort(&mut heap, std::slice::from_ref(&left)).unwrap();

        assert_eq!(int_values(&appended), vec![3, 1, 2, 9]);
        assert_eq!(int_values(&joined), vec![3, 1, 2, 4, 5]);
        assert_eq!(int_values(&reversed), vec![2, 1, 3]);
        assert_eq!(int_values(&taken), vec![3, 1]);
        assert_eq!(int_values(&ranged), vec![2, 3, 4]);
        assert_eq!(int_values(&sorted), vec![1, 2, 3]);

        for result in [&appended, &joined, &reversed, &taken, &ranged, &sorted] {
            assert_cell_lengths(result);
        }
        assert_eq!(int_values(&left), left_before);
        assert_eq!(int_values(&right), right_before);

        let joined_ref = joined.as_list().unwrap();
        let mut suffix = joined_ref;
        for _ in 0..left.as_list().unwrap().len() {
            suffix = suffix.tail().unwrap();
        }
        assert!(suffix.same_cells(right.as_list().unwrap()));
    }

    #[test]
    fn every_list_operation_leaves_its_input_lists_unchanged() {
        let mut heap = Heap::new();
        let list = make_list(&mut heap, vec![Value::Int(3), Value::Int(1), Value::Int(2)]);
        let other = make_list(&mut heap, vec![Value::Int(4), Value::Int(5)]);
        let list_before = int_values(&list);
        let other_before = int_values(&other);

        let _length = length(&mut heap, std::slice::from_ref(&list)).unwrap();
        let _is_empty = is_empty(&mut heap, std::slice::from_ref(&list)).unwrap();
        let _head = head(&mut heap, std::slice::from_ref(&list)).unwrap();
        let _tail = tail(&mut heap, std::slice::from_ref(&list)).unwrap();
        let _get = get(&mut heap, &[list.clone(), Value::Int(1)]).unwrap();
        let _prepend = prepend(&mut heap, &[list.clone(), Value::Int(0)]).unwrap();
        let _append = append(&mut heap, &[list.clone(), Value::Int(0)]).unwrap();
        let _concat = concat(&mut heap, &[list.clone(), other.clone()]).unwrap();
        let _reverse = reverse(&mut heap, std::slice::from_ref(&list)).unwrap();
        let _take = take(&mut heap, &[list.clone(), Value::Int(2)]).unwrap();
        let _drop = drop(&mut heap, &[list.clone(), Value::Int(1)]).unwrap();
        let _range = range(&mut heap, &[Value::Int(0), Value::Int(2)]).unwrap();
        let _contains = contains(&mut heap, &[list.clone(), Value::Int(1)]).unwrap();
        let _sort = sort(&mut heap, std::slice::from_ref(&list)).unwrap();
        let _drop_first = drop_first(&mut heap, std::slice::from_ref(&list)).unwrap();

        assert_eq!(int_values(&list), list_before);
        assert_eq!(int_values(&other), other_before);
    }

    #[test]
    fn prepend_shares_its_tail_and_contains_uses_structural_equality() {
        let mut heap = Heap::new();
        let list = make_list(&mut heap, vec![Value::Int(2), Value::Int(3)]);
        let prepended = prepend(&mut heap, &[list.clone(), Value::Int(1)]).unwrap();
        assert!(
            prepended
                .as_list()
                .unwrap()
                .tail()
                .unwrap()
                .same_cells(list.as_list().unwrap())
        );

        let some_one = heap.ctor(0, vec![Value::Int(1)]);
        let none = heap.ctor(1, Vec::new());
        let options = make_list(&mut heap, vec![some_one, none.clone()]);
        let another_none = heap.ctor(1, Vec::new());
        assert_eq!(
            contains(&mut heap, &[options.clone(), none])
                .unwrap()
                .as_bool(),
            Some(true)
        );
        assert_eq!(
            contains(&mut heap, &[options, another_none])
                .unwrap()
                .as_bool(),
            Some(true)
        );
    }

    #[test]
    fn range_returns_empty_for_non_increasing_endpoints_and_checks_limits_first() {
        let mut heap = Heap::new();
        assert!(
            range(&mut heap, &[Value::Int(5), Value::Int(5)])
                .unwrap()
                .as_list()
                .unwrap()
                .is_empty()
        );
        assert!(
            range(&mut heap, &[Value::Int(6), Value::Int(5)])
                .unwrap()
                .as_list()
                .unwrap()
                .is_empty()
        );
        assert_eq!(
            int_values(&range(&mut heap, &[Value::Int(3), Value::Int(6)]).unwrap()),
            vec![3, 4, 5]
        );

        let before = heap.stats();
        assert_eq!(
            range(&mut heap, &[Value::Int(0), Value::Int(16_777_217)]).unwrap_err(),
            Stop::Resource(ResourceError::ValueTooLarge {
                function: "List.range",
                size: 16_777_217,
                unit: SizeUnit::Elements,
                limit: MAX_LIST_LEN,
            })
        );
        assert_eq!(heap.stats(), before);
        assert_eq!(
            range(&mut heap, &[Value::Int(i64::MIN), Value::Int(i64::MAX)]).unwrap_err(),
            Stop::Resource(ResourceError::ValueTooLarge {
                function: "List.range",
                size: u64::MAX,
                unit: SizeUnit::Elements,
                limit: MAX_LIST_LEN,
            })
        );
        assert_eq!(heap.stats(), before);
    }

    #[test]
    fn sort_orders_supported_kinds_stably_and_places_nan_last() {
        let mut heap = Heap::new();
        let string_b = heap.string("b");
        let string_a = heap.string("a");
        let string_e_acute = heap.string("é");
        let strings = make_list(&mut heap, vec![string_b, string_a, string_e_acute]);
        assert_eq!(
            string_values(&sort(&mut heap, std::slice::from_ref(&strings)).unwrap()),
            vec!["a", "b", "é"]
        );

        let chars = make_list(
            &mut heap,
            vec![Value::Char('z'), Value::Char('A'), Value::Char('a')],
        );
        let sorted_chars = sort(&mut heap, std::slice::from_ref(&chars)).unwrap();
        assert_eq!(
            sorted_chars
                .as_list()
                .unwrap()
                .iter()
                .map(|value| value.as_char().unwrap())
                .collect::<Vec<_>>(),
            vec!['A', 'a', 'z']
        );

        let first_nan = f64::from_bits(0x7ff8_0000_0000_0001);
        let second_nan = f64::from_bits(0x7ff8_0000_0000_0002);
        let floats = make_list(
            &mut heap,
            vec![
                Value::Float(3.0),
                Value::Float(first_nan),
                Value::Float(1.0),
                Value::Float(second_nan),
                Value::Float(-0.0),
                Value::Float(0.0),
            ],
        );
        let sorted_floats = sort(&mut heap, std::slice::from_ref(&floats)).unwrap();
        let bits = sorted_floats
            .as_list()
            .unwrap()
            .iter()
            .map(|value| value.as_float().unwrap().to_bits())
            .collect::<Vec<_>>();
        assert_eq!(
            bits,
            vec![
                (-0.0_f64).to_bits(),
                0.0_f64.to_bits(),
                1.0_f64.to_bits(),
                3.0_f64.to_bits(),
                first_nan.to_bits(),
                second_nan.to_bits(),
            ]
        );

        let reversed_zeroes = make_list(&mut heap, vec![Value::Float(0.0), Value::Float(-0.0)]);
        let sorted_zeroes = sort(&mut heap, std::slice::from_ref(&reversed_zeroes)).unwrap();
        assert_eq!(
            sorted_zeroes
                .as_list()
                .unwrap()
                .iter()
                .map(|value| value.as_float().unwrap().to_bits())
                .collect::<Vec<_>>(),
            vec![0.0_f64.to_bits(), (-0.0_f64).to_bits()]
        );

        let mixed = make_list(&mut heap, vec![Value::Int(1), Value::Char('a')]);
        assert!(matches!(
            sort(&mut heap, std::slice::from_ref(&mixed)),
            Err(Stop::Internal(_))
        ));
        let unsupported = make_list(&mut heap, vec![Value::Bool(true)]);
        assert!(matches!(
            sort(&mut heap, std::slice::from_ref(&unsupported)),
            Err(Stop::Internal(_))
        ));
    }

    #[test]
    fn million_element_sort_reverse_and_concat_use_iterative_traversal() {
        let mut heap = Heap::new();
        let source = make_list(
            &mut heap,
            (0_i64..1_000_000_i64).rev().map(Value::Int).collect(),
        );
        let empty = Value::List(ListRef::empty());

        {
            let sorted = sort(&mut heap, std::slice::from_ref(&source)).unwrap();
            let items = sorted.as_list().unwrap();
            assert_eq!(items.len(), 1_000_000);
            assert_eq!(items.iter().next().and_then(Value::as_int), Some(0));
            assert_eq!(items.iter().last().and_then(Value::as_int), Some(999_999));
        }
        {
            let reversed = reverse(&mut heap, std::slice::from_ref(&source)).unwrap();
            let items = reversed.as_list().unwrap();
            assert_eq!(items.len(), 1_000_000);
            assert_eq!(items.iter().next().and_then(Value::as_int), Some(0));
            assert_eq!(items.iter().last().and_then(Value::as_int), Some(999_999));
        }
        {
            let joined = concat(&mut heap, &[source.clone(), empty]).unwrap();
            let items = joined.as_list().unwrap();
            assert_eq!(items.len(), 1_000_000);
            assert_eq!(items.iter().next().and_then(Value::as_int), Some(999_999));
            assert_eq!(items.iter().last().and_then(Value::as_int), Some(0));
        }
    }

    #[test]
    fn wrong_argument_kinds_return_internal_stop() {
        let mut heap = Heap::new();
        assert!(matches!(
            length(&mut heap, &[Value::Int(1)]),
            Err(Stop::Internal(_))
        ));
        assert!(matches!(
            get(
                &mut heap,
                &[Value::List(ListRef::empty()), Value::Bool(false)]
            ),
            Err(Stop::Internal(_))
        ));
    }
}
