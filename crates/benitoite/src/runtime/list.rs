//! リストの値（設計書 03-06「List の内部の表現」、02-08「値の表現」）。
//!
//! 非空のリストは `ListNode` の頭を指す。tag の下位 2 ビットは、0 = 頭、
//! 1 = 厳密な内部ノード、2 = 緩和した内部ノード、3 = 葉。上位ビットは
//! シフト量（葉は 0、内部ノードは 5 刻み）であり、頭の tag は 0 とする。
//! 頭の欄は `[長さ, 根のシフト量, 根（空なら Unit）, 末尾の葉]`。
//! 緩和したノードの欄は `[子 k 個, 累積要素数 k 個]`、厳密なノードは子だけを持つ。
//!
//! 連結は末尾の葉を木へ押し込んで、両端の道筋を下から結合する。
//! 各高さの境界の並びが r 個のノードに s 個の子（葉では要素）を持つとき、
//! `r > ceil(s / 32) + 2` なら隣へ詰め直す（実装プラン R36、E_MAX = 2）。
//! 詰め直すときは 32 個ずつに詰め、区切りが合う満ちたノードは共有する。
//! 分割は両境界の道筋だけを写す。新しいノードの不変条件だけを debug_assert で検査する。
//! 長さ 2^24 は 32 進で 5 桁なので連結の根一段を含め MAX_SHIFT = 25 とし、cut の境界の単子鎖は根直下を 32 欄以内にまとめられる段も縮め、連結の履歴で高さを増やさない。

use crate::runtime::Stop;
use crate::runtime::heap::{CheckedLen, FieldsKind, Value, ValueCtx};
mod rrb;
pub(crate) use rrb::Cursor;
use rrb::{Tree, WIDTH};

/// 並びの順のリストを作る。
pub fn from_values<'e>(
    ctx: &ValueCtx<'e>,
    items: &[Value<'e>],
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let length =
        CheckedLen::elements(u64::try_from(items.len()).unwrap_or(u64::MAX), function)?.get();
    if length == 0 {
        return Ok(Value::EmptyList);
    }
    let tail_start = (items.len().checked_sub(1).ok_or_else(invalid_list)? / WIDTH)
        .checked_mul(WIDTH)
        .ok_or_else(invalid_list)?;
    let tail = rrb::leaf(ctx, items.get(tail_start..).ok_or_else(invalid_list)?)?;
    let mut nodes = items
        .get(..tail_start)
        .ok_or_else(invalid_list)?
        .chunks(WIDTH)
        .map(|c| rrb::leaf(ctx, c))
        .collect::<Result<Vec<_>, _>>()?;
    while nodes.len() > 1 {
        nodes = nodes
            .chunks(WIDTH)
            .map(|c| rrb::branch(ctx, c, false))
            .collect::<Result<_, _>>()?;
    }
    head(ctx, length, nodes.pop(), tail)
}
/// 長さ。リストでなければ `Stop::Internal`。
pub fn len<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<u32, Stop> {
    if matches!(list, Value::EmptyList) {
        return Ok(0);
    }
    if !is_list(ctx, list) {
        return Err(invalid_list());
    }
    let length = integer(ctx, list, 0)?;
    if length == 0 || u64::from(length) > crate::runtime::MAX_LIST_LEN {
        return Err(invalid_list());
    }
    Ok(length)
}
/// 位置 `i` の要素。範囲の外なら `None`。
pub fn get<'e>(ctx: &ValueCtx<'e>, list: Value<'e>, i: u32) -> Result<Option<Value<'e>>, Stop> {
    let length = len(ctx, list)?;
    if i >= length {
        return Ok(None);
    }
    let (root, tail) = parts(ctx, list, length)?;
    let tree_len = length.checked_sub(tail.size).ok_or_else(invalid_list)?;
    let item = if i >= tree_len {
        rrb::lookup(ctx, tail, i.checked_sub(tree_len).ok_or_else(invalid_list)?)?
    } else {
        rrb::lookup(ctx, root.ok_or_else(invalid_list)?, i)?
    };
    Ok(Some(item))
}
/// 先頭の要素を除いたリスト。空なら `None`。
pub fn tail<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<Option<Value<'e>>, Stop> {
    if len(ctx, list)? == 0 {
        Ok(None)
    } else {
        Ok(Some(slice(ctx, list, 1, u32::MAX)?))
    }
}
/// 元のリストを共有し、先頭に要素を加える。
pub fn prepend<'e>(
    ctx: &ValueCtx<'e>,
    list: Value<'e>,
    x: Value<'e>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    checked_sum(len(ctx, list)?, 1, function)?;
    let one = from_values(ctx, &[x], function)?;
    concat(ctx, one, list, function)
}
/// 元のリストを変えず、末尾に要素を加える。
pub fn append<'e>(
    ctx: &ValueCtx<'e>,
    list: Value<'e>,
    x: Value<'e>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let old_len = len(ctx, list)?;
    let length = checked_sum(old_len, 1, function)?;
    if old_len == 0 {
        return from_values(ctx, &[x], function);
    }
    let (mut root, tail) = parts(ctx, list, old_len)?;
    let tail = if tail.size < 32 {
        let mut items = rrb::elements(ctx, tail)?;
        items.push(x);
        rrb::leaf(ctx, &items)?
    } else {
        root = Some(rrb::push_leaf(ctx, root, tail)?);
        rrb::leaf(ctx, &[x])?
    };
    head(ctx, length, root, tail)
}
/// 二つのリストを順に連結する。
pub fn concat<'e>(
    ctx: &ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let a_len = len(ctx, a)?;
    let b_len = len(ctx, b)?;
    let length = checked_sum(a_len, b_len, function)?;
    if a_len == 0 {
        return Ok(b);
    }
    if b_len == 0 {
        return Ok(a);
    }
    let (ar, at) = parts(ctx, a, a_len)?;
    let (br, bt) = parts(ctx, b, b_len)?;
    let a = rrb::push_leaf(ctx, ar, at)?;
    let b = rrb::push_leaf(ctx, br, bt)?;
    let joined = rrb::join(ctx, a, b)?;
    let (root, tail) = rrb::pop_leaf(ctx, joined)?;
    head(ctx, length, root, tail)
}
/// 位置 `start` 以上 `end` 未満の要素のリスト（`start` と `end` は長さの中に切り詰める）。
pub fn slice<'e>(
    ctx: &ValueCtx<'e>,
    list: Value<'e>,
    start: u32,
    end: u32,
) -> Result<Value<'e>, Stop> {
    let length = len(ctx, list)?;
    let start = start.min(length);
    let end = end.min(length);
    if start >= end {
        return Ok(Value::EmptyList);
    }
    if start == 0 && end == length {
        return Ok(list);
    }
    let count = end.checked_sub(start).ok_or_else(invalid_list)?;
    let (root, tail) = parts(ctx, list, length)?;
    let tree_len = length.checked_sub(tail.size).ok_or_else(invalid_list)?;
    // 元の末尾を含む切り出しでは、その葉を押し込み直す必要がない。
    if end == length && start < tree_len {
        let root = rrb::cut(ctx, root.ok_or_else(invalid_list)?, start, tree_len)?;
        return head(ctx, count, Some(root), tail);
    }
    if start >= tree_len {
        let sliced = rrb::cut(
            ctx,
            tail,
            start.checked_sub(tree_len).ok_or_else(invalid_list)?,
            end.checked_sub(tree_len).ok_or_else(invalid_list)?,
        )?;
        return head(ctx, count, None, sliced);
    }
    let tree = if end <= tree_len {
        root.ok_or_else(invalid_list)?
    } else {
        rrb::push_leaf(ctx, root, tail)?
    };
    let cut = rrb::cut(ctx, tree, start, end)?;
    let (root, tail) = rrb::pop_leaf(ctx, cut)?;
    head(ctx, count, root, tail)
}
/// 要素を先頭から順に並べた `Vec`。
pub fn to_vec<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<Vec<Value<'e>>, Stop> {
    let capacity = usize::try_from(len(ctx, list)?).map_err(|_| invalid_list())?;
    let mut items = Vec::with_capacity(capacity);
    let mut cursor = cursor(ctx, list)?;
    while let Some(item) = cursor.next(ctx)? {
        items.push(item);
    }
    if items.len() != capacity {
        return Err(invalid_list());
    }
    Ok(items)
}

/// リストの値か。内部ノードと葉をリストの値として受け付けない。
pub(crate) fn is_list<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> bool {
    matches!(list, Value::EmptyList)
        || (ctx.fields_header(list) == Some((FieldsKind::ListNode, rrb::HEAD))
            && ctx.fields_len(list) == Some(4))
}
/// 表現を外へ見せず、要素を順に辿る走査を作る。
pub(crate) fn cursor<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Result<Cursor<'e>, Stop> {
    let length = len(ctx, list)?;
    if length == 0 {
        return Ok(Cursor::new(None, None));
    }
    let (root, tail) = parts(ctx, list, length)?;
    Ok(Cursor::new(root, Some(tail)))
}
fn integer<'e>(ctx: &ValueCtx<'e>, list: Value<'e>, i: u32) -> Result<u32, Stop> {
    ctx.field(list, i)
        .and_then(Value::as_int)
        .and_then(|n| u32::try_from(n).ok())
        .ok_or_else(invalid_list)
}
fn checked_sum(a: u32, b: u32, function: &'static str) -> Result<u32, Stop> {
    Ok(CheckedLen::elements(
        u64::from(a)
            .checked_add(u64::from(b))
            .ok_or_else(invalid_list)?,
        function,
    )?
    .get())
}
fn parts<'e>(
    ctx: &ValueCtx<'e>,
    list: Value<'e>,
    length: u32,
) -> Result<(Option<Tree<'e>>, Tree<'e>), Stop> {
    let tail = rrb::leaf_tree(ctx, ctx.field(list, 3).ok_or_else(invalid_list)?)?;
    let size = length.checked_sub(tail.size).ok_or_else(invalid_list)?;
    let shift = integer(ctx, list, 1)?;
    if shift % rrb::BITS != 0 || shift > rrb::MAX_SHIFT {
        return Err(invalid_list());
    }
    let value = ctx.field(list, 2).ok_or_else(invalid_list)?;
    let root = if size == 0 {
        if !matches!(value, Value::Unit) || shift != 0 {
            return Err(invalid_list());
        }
        None
    } else {
        Some(Tree { value, shift, size })
    };
    Ok((root, tail))
}
fn head<'e>(
    ctx: &ValueCtx<'e>,
    length: u32,
    root: Option<Tree<'e>>,
    tail: Tree<'e>,
) -> Result<Value<'e>, Stop> {
    // 作成と追加は子が一つの根を作らず、連結・切り出しは各操作が根を縮める。
    // 頭では辿り直さず、末尾の葉だけを写す追加の定数の費用を保つ（実装プラン R36）。
    debug_assert_eq!(
        root.map_or(0, |tree| tree.size).checked_add(tail.size),
        Some(length)
    );
    debug_assert!(root.is_none_or(|tree| tree.shift <= rrb::MAX_SHIFT));
    let (value, shift) = root.map_or((Value::Unit, 0), |tree| (tree.value, tree.shift));
    ctx.alloc_fields(
        FieldsKind::ListNode,
        rrb::HEAD,
        &[
            Value::Int(i64::from(length)),
            Value::Int(i64::from(shift)),
            value,
            tail.value,
        ],
    )
}
fn invalid_list() -> Stop {
    Stop::Internal("invalid persistent list value or node".into())
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::runtime::heap::{Heap, HeapConfig};
    use crate::runtime::{MAX_LIST_LEN, ResourceError, SizeUnit};

    // 作成時の関門: 公開 API の要素の順・永続性・上限と、非再帰の走査を守る。
    // Vec を独立したモデルにし、位置や共有の誤りを捕まえる。既存のヒープのテストは
    // リストの操作を呼ばない。本番にテスト用の口は加えず、R36 が認めた上限の頭だけ準備する。
    fn ints<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) -> Vec<i64> {
        to_vec(ctx, list)
            .unwrap()
            .into_iter()
            .map(|v| v.as_int().unwrap())
            .collect()
    }

    #[test]
    fn operations_match_vec_and_keep_previous_lists() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let mut list =
                from_values(ctx, &[Value::Int(1), Value::Int(2), Value::Int(3)], "list").unwrap();
            let mut model = vec![1, 2, 3];
            let original = list;
            let prefixed = prepend(ctx, list, Value::Int(0), "prepend").unwrap();
            assert_eq!(
                ints(ctx, tail(ctx, prefixed).unwrap().unwrap()),
                ints(ctx, original)
            );
            assert_eq!(ints(ctx, original), vec![1, 2, 3]);
            assert_eq!(ints(ctx, prefixed), vec![0, 1, 2, 3]);
            let joined = concat(ctx, prefixed, original, "concat").unwrap();
            assert_eq!(
                ints(ctx, slice(ctx, joined, 4, u32::MAX).unwrap()),
                ints(ctx, original)
            );
            assert_eq!(
                ints(ctx, slice(ctx, original, 1, u32::MAX).unwrap()),
                ints(ctx, tail(ctx, original).unwrap().unwrap())
            );
            for (start, end, expected) in [
                (0, u32::MAX, vec![1, 2, 3]),
                (1, 2, vec![2]),
                (9, 20, vec![]),
                (2, 1, vec![]),
                (1, 1, vec![]),
            ] {
                assert_eq!(
                    ints(ctx, slice(ctx, original, start, end).unwrap()),
                    expected
                );
            }
            let empty = from_values(ctx, &[], "list").unwrap();
            assert!(matches!(empty, Value::EmptyList));
            assert!(tail(ctx, empty).unwrap().is_none());
            assert!(get(ctx, empty, 0).unwrap().is_none());
            assert_eq!(
                ints(ctx, append(ctx, empty, Value::Int(7), "append").unwrap()),
                vec![7]
            );
            assert_eq!(
                ints(ctx, prepend(ctx, empty, Value::Int(7), "prepend").unwrap()),
                vec![7]
            );
            assert!(ctx.same_object(concat(ctx, empty, original, "concat").unwrap(), original));
            assert_eq!(
                ints(ctx, concat(ctx, original, empty, "concat").unwrap()),
                vec![1, 2, 3]
            );
            let mut seed = 0x06_u64;
            let mut history = Vec::new();
            let steps = if cfg!(miri) { 30 } else { 300 };
            for n in 0..steps {
                seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
                history.push((list, model.clone()));
                match (seed >> 32) % 6 {
                    0 => {
                        list = prepend(ctx, list, Value::Int(n), "prepend").unwrap();
                        model.insert(0, n);
                    }
                    1 => {
                        list = append(ctx, list, Value::Int(n), "append").unwrap();
                        model.push(n);
                    }
                    2 => {
                        let extra =
                            from_values(ctx, &[Value::Int(n), Value::Int(-n)], "list").unwrap();
                        list = concat(ctx, list, extra, "concat").unwrap();
                        model.extend([n, -n]);
                    }
                    3 => {
                        let start = (seed % 12) as u32;
                        let end = ((seed >> 8) % 15) as u32;
                        list = slice(ctx, list, start, end).unwrap();
                        let start = (start as usize).min(model.len());
                        let end = (end as usize).min(model.len()).max(start);
                        model = model[start..end].to_vec();
                    }
                    4 => {
                        list = tail(ctx, list).unwrap().unwrap_or(Value::EmptyList);
                        if !model.is_empty() {
                            model.remove(0);
                        }
                    }
                    5 => {
                        let values: Vec<_> = model.iter().copied().map(Value::Int).collect();
                        list = from_values(ctx, &values, "list").unwrap();
                    }
                    _ => unreachable!(),
                }
                assert_eq!(len(ctx, list).unwrap() as usize, model.len());
                assert_eq!(ints(ctx, list), model);
                for i in 0..=model.len() {
                    assert_eq!(
                        get(ctx, list, i as u32)
                            .unwrap()
                            .map(|v| v.as_int().unwrap()),
                        model.get(i).copied()
                    );
                }
                assert!(get(ctx, list, u32::MAX).unwrap().is_none());
            }
            for (old, expected) in history {
                assert_eq!(ints(ctx, old), expected);
            }
        });
        assert!(heap.take_fault().is_none());
    }

    fn oversized_head<'e>(ctx: &ValueCtx<'e>) -> Value<'e> {
        // R36 が許す準備: 上限の失敗は長さだけで決まり、実際に 2^24 要素を作る必要がない。
        ctx.alloc_fields(
            FieldsKind::ListNode,
            rrb::HEAD,
            &[
                Value::Int(i64::try_from(MAX_LIST_LEN).unwrap()),
                Value::Int(0),
                Value::Unit,
                Value::Unit,
            ],
        )
        .unwrap()
    }

    #[test]
    fn limits_and_invalid_inputs_fail_before_building_nodes() {
        let mut heap = Heap::new(HeapConfig::default());
        let (large, one) = heap.epoch(|ctx| {
            (
                ctx.new_slot(oversized_head(ctx)),
                ctx.new_slot(from_values(ctx, &[Value::Unit], "list").unwrap()),
            )
        });
        let before = heap.stats().allocations;
        heap.epoch(|ctx| {
            let list = ctx.load(&large);
            for (function, result) in [
                ("prepend", prepend(ctx, list, Value::Unit, "prepend")),
                ("append", append(ctx, list, Value::Unit, "append")),
                ("concat", concat(ctx, list, ctx.load(&one), "concat")),
            ] {
                assert_eq!(
                    result.unwrap_err(),
                    Stop::Resource(ResourceError::ValueTooLarge {
                        function,
                        size: 16777217,
                        unit: SizeUnit::Elements,
                        limit: 16777216,
                    })
                );
            }
            ctx.discard(vec![large, one]);
        });
        assert_eq!(heap.stats().allocations, before);
        heap.epoch(|ctx| {
            for invalid in [
                Value::Unit,
                Value::Int(1),
                ctx.alloc_str("x", "test").unwrap(),
                ctx.alloc_fields(FieldsKind::Ctor, 0, &[]).unwrap(),
            ] {
                assert!(matches!(len(ctx, invalid), Err(Stop::Internal(_))));
                assert!(matches!(get(ctx, invalid, 0), Err(Stop::Internal(_))));
                assert!(matches!(tail(ctx, invalid), Err(Stop::Internal(_))));
                assert!(matches!(to_vec(ctx, invalid), Err(Stop::Internal(_))));
                assert!(matches!(slice(ctx, invalid, 0, 0), Err(Stop::Internal(_))));
            }
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    #[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
    fn ten_million_elements_are_traversed_without_rust_recursion() {
        // Miri でも同じ操作の経路を調べ、解釈するセルの数だけ減らす（R06「長いリスト」）。
        let count: u32 = if cfg!(miri) { 24 } else { 10_000_000 };
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let values: Vec<_> = (0..count).map(|i| Value::Int(i64::from(i))).collect();
            let list = from_values(ctx, &values, "list").unwrap();
            drop(values);
            assert_eq!(len(ctx, list).unwrap(), count);
            let values = to_vec(ctx, list).unwrap();
            assert_eq!(values.len(), count as usize);
            for (i, value) in values.into_iter().enumerate() {
                assert_eq!(value.as_int(), Some(i as i64));
            }
            let part = slice(ctx, list, count - 3, count - 1).unwrap();
            assert_eq!(
                ints(ctx, part),
                vec![i64::from(count - 3), i64::from(count - 2)]
            );
            assert_eq!(len(ctx, list).unwrap(), count);
        });
        assert!(heap.take_fault().is_none());
    }
    // 関門: 境界をまたぐ連結・分割・追加の組み合わせと旧値の永続性を公開 API で守る。
    // R06 の小さいモデルでは内部ノードの境界に届かず、単独の大きい作成では緩和を作らない。
    // 独立した Vec を使い、内部の高さや対象の同一性は期待値にしない。公開の口は増やさない。
    #[test]
    fn boundary_operations_match_vec_and_preserve_shared_inputs() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let boundaries = [
                0_usize, 1, 31, 32, 33, 63, 64, 65, 1023, 1024, 1025, 1055, 1056, 1057, 32767,
                32768, 32769,
            ];
            let sizes = if cfg!(miri) {
                &boundaries[..7]
            } else {
                &boundaries[..]
            };
            let mut seed = 0x36_0211_u64;
            let mut versions = Vec::new();
            for &n in sizes {
                let model: Vec<_> = (0..n).map(|i| i64::try_from(i).unwrap()).collect();
                let values: Vec<_> = model.iter().copied().map(Value::Int).collect();
                let list = from_values(ctx, &values, "list").unwrap();
                versions.push((list, model));
            }
            let steps = if cfg!(miri) { 12 } else { 320 };
            for step in 0..steps {
                seed = seed
                    .wrapping_mul(6364136223846793005)
                    .wrapping_add(1442695040888963407);
                let a_index = usize::try_from(seed >> 32).unwrap() % versions.len();
                let b_index = usize::try_from(seed & 0xffff).unwrap() % versions.len();
                let (a, mut model) = versions[a_index].clone();
                let (b, other) = versions[b_index].clone();
                let before_a = ints(ctx, a);
                let before_b = ints(ctx, b);
                let result = match step % 8 {
                    0 => {
                        let items: Vec<_> = model.iter().copied().map(Value::Int).collect();
                        from_values(ctx, &items, "list").unwrap()
                    }
                    1 => {
                        model.push(step);
                        append(ctx, a, Value::Int(step), "append").unwrap()
                    }
                    2 => {
                        model.insert(0, -step);
                        prepend(ctx, a, Value::Int(-step), "prepend").unwrap()
                    }
                    3 | 4 => {
                        if model.len() + other.len() < 100_000 {
                            model.extend(other);
                            concat(ctx, a, b, "concat").unwrap()
                        } else {
                            a
                        }
                    }
                    5 | 6 => {
                        let start = boundaries[usize::try_from(seed >> 8).unwrap() % sizes.len()]
                            .min(model.len());
                        let stop = boundaries[usize::try_from(seed >> 16).unwrap() % sizes.len()]
                            .min(model.len());
                        let end = stop.max(start);
                        model = model[start..end].to_vec();
                        slice(
                            ctx,
                            a,
                            u32::try_from(start).unwrap(),
                            u32::try_from(end).unwrap(),
                        )
                        .unwrap()
                    }
                    7 => {
                        if !model.is_empty() {
                            model.remove(0);
                        }
                        tail(ctx, a).unwrap().unwrap_or(Value::EmptyList)
                    }
                    _ => unreachable!(),
                };
                assert_eq!(
                    usize::try_from(len(ctx, result).unwrap()).unwrap(),
                    model.len()
                );
                assert_eq!(ints(ctx, result), model, "step {step}");
                for &pos in sizes {
                    assert_eq!(
                        get(ctx, result, u32::try_from(pos).unwrap())
                            .unwrap()
                            .map(|x| x.as_int().unwrap()),
                        model.get(pos).copied()
                    );
                }
                assert_eq!(ints(ctx, a), before_a);
                assert_eq!(ints(ctx, b), before_b);
                if model.is_empty() {
                    assert!(matches!(result, Value::EmptyList));
                }
                // 小さいモデルだけで共有部分も含む全体の不変条件を検査する（R36）。
                if model.len() < 2048 {
                    assert_valid_tree(ctx, result);
                }
                versions.push((result, model));
            }
            for (list, model) in versions {
                assert_eq!(ints(ctx, list), model);
            }
        });
        assert!(heap.take_fault().is_none());
    }

    fn assert_valid_tree<'e>(ctx: &ValueCtx<'e>, list: Value<'e>) {
        let length = len(ctx, list).unwrap();
        if length == 0 {
            return;
        }
        let (root, tail) = parts(ctx, list, length).unwrap();
        let mut pending: Vec<_> = root.into_iter().chain(Some(tail)).collect();
        let mut total = 0;
        while let Some(tree) = pending.pop() {
            if tree.shift == 0 {
                let items = rrb::elements(ctx, tree).unwrap();
                assert!(!items.is_empty() && items.len() <= 32);
                total += items.len();
            } else {
                let children = rrb::children(ctx, tree).unwrap();
                assert_eq!(children.iter().map(|x| x.size).sum::<u32>(), tree.size);
                pending.extend(children);
            }
        }
        assert_eq!(total, usize::try_from(length).unwrap());
    }

    // 関門: 2^20 回の末尾追加と全添字の読み出し、連結・分割の非再帰と永続性を守る。
    // 大きい from_values だけでは追加時の木への押し込みを確かめられない。
    // 根を通常の Slot に保存して回収を行い、長い区間に全履歴を残す準備は避ける。
    #[test]
    #[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
    fn million_appends_gets_and_repeated_splits_do_not_recurse() {
        use crate::runtime::heap::Slot;
        let count: u32 = if cfg!(miri) { 40 } else { 1 << 20 };
        let mut heap = Heap::new(HeapConfig::default());
        let mut saved = Slot::default();
        let mut collected_bytes = 0;
        for start in (0..count).step_by(8192) {
            heap.epoch(|ctx| {
                let mut list = if start == 0 {
                    Value::EmptyList
                } else {
                    ctx.load(&saved)
                };
                for n in start..(start + 8192).min(count) {
                    list = append(ctx, list, Value::Int(i64::from(n)), "append").unwrap();
                }
                ctx.store(&mut saved, list);
            });
            // 最大の木も回収の強制も全要素を毎追加で辿らない。安全点の区切りを明示する。
            if heap.stats().allocated_bytes - collected_bytes > 64 * 1024 * 1024 {
                heap.collect(&saved);
                collected_bytes = heap.stats().allocated_bytes;
            }
        }
        heap.collect(&saved);
        heap.epoch(|ctx| {
            let original = ctx.load(&saved);
            assert_eq!(len(ctx, original).unwrap(), count);
            for n in 0..count {
                assert_eq!(
                    get(ctx, original, n).unwrap().unwrap().as_int(),
                    Some(i64::from(n))
                );
            }
            let before = ints(ctx, original);
            let mut list = original;
            for offset in [1, 31, 32, 33, 1023, 1024, 1025] {
                let cut = offset.min(count);
                let left = slice(ctx, list, 0, cut).unwrap();
                let right = slice(ctx, list, cut, count).unwrap();
                list = concat(ctx, left, right, "concat").unwrap();
                assert_eq!(ints(ctx, list), before);
                assert_eq!(ints(ctx, original), before);
            }
            ctx.discard(saved);
        });
        assert!(heap.take_fault().is_none());
    }

    // 関門: 切り出しの単子鎖を連結・再切り出しで蓄積させても、公開 API が値を拒まない。
    // 32769 要素までの無作為テストと短い葉だけの連結では、この履歴の退行に届かない。
    // 修正前は二巡目の連結で get が Internal になった。高さは検査せず Vec と比べる（設計書 03-06「List の内部の表現」）。
    #[test]
    #[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
    fn repeated_cuts_of_joined_lists_preserve_sequences() {
        let count: usize = if cfg!(miri) { 8 } else { 26_039 };
        let pivot: u32 = if cfg!(miri) { 64 } else { 1 << 20 };
        let mut heap = Heap::new(HeapConfig::default());
        let mut model: Vec<_> = (pivot - 33..pivot + 33).map(i64::from).collect();
        let mut roots = heap.epoch(|ctx| {
            let values: Vec<_> = (0..pivot + 74).map(|n| Value::Int(i64::from(n))).collect();
            let large = from_values(ctx, &values, "list").unwrap();
            let chunk = slice(ctx, large, pivot - 33, pivot + 33).unwrap();
            assert_eq!(ints(ctx, chunk), model);
            vec![ctx.new_slot(Value::EmptyList), ctx.new_slot(chunk)]
        });
        let mut collected_bytes = 0;
        for cycle in 0..2 {
            heap.epoch(|ctx| ctx.store(&mut roots[0], Value::EmptyList));
            for start in (0..count).step_by(512) {
                heap.epoch(|ctx| {
                    let mut list = ctx.load(&roots[0]);
                    let chunk = ctx.load(&roots[1]);
                    for _ in start..(start + 512).min(count) {
                        list = concat(ctx, list, chunk, "concat").unwrap();
                    }
                    ctx.store(&mut roots[0], list);
                });
                if heap.stats().allocated_bytes - collected_bytes > 64 * 1024 * 1024 {
                    heap.collect(&roots);
                    collected_bytes = heap.stats().allocated_bytes;
                }
            }
            heap.collect(&roots);
            heap.epoch(|ctx| {
                let list = ctx.load(&roots[0]);
                let expected = model.repeat(count);
                assert_eq!(ints(ctx, list), expected);
                assert_eq!(ints(ctx, ctx.load(&roots[1])), model);
                let length = u32::try_from(expected.len()).unwrap();
                for i in [0, 31, 32, 33, length - 1] {
                    assert_eq!(
                        get(ctx, list, i).unwrap().unwrap().as_int(),
                        Some(expected[usize::try_from(i).unwrap()])
                    );
                }
                if cycle == 0 {
                    let start = length - 66;
                    let chunk = slice(ctx, list, start, length).unwrap();
                    model = expected[usize::try_from(start).unwrap()..].to_vec();
                    assert_eq!(ints(ctx, chunk), model);
                    ctx.store(&mut roots[1], chunk);
                }
            });
        }
        heap.epoch(|ctx| ctx.discard(roots));
        assert!(heap.take_fault().is_none());
    }

    // 関門: 小さいリストの反復連結で疎な境界が蓄積しても値と順序を保ち、再帰しない。
    // 単発の境界テストでは反復連結の平衡の退行を検出できない。高さは検査しない（設計書 03-06「List の内部の表現」）。
    #[test]
    #[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
    fn hundred_thousand_short_concatenations_match_vec() {
        use crate::runtime::heap::Slot;
        let count = if cfg!(miri) { 20 } else { 100_000 };
        let mut heap = Heap::new(HeapConfig::default());
        let mut saved = Slot::default();
        let mut model = Vec::new();
        let mut collected_bytes = 0;
        for start in (0..count).step_by(1024) {
            heap.epoch(|ctx| {
                let mut list = if start == 0 {
                    Value::EmptyList
                } else {
                    ctx.load(&saved)
                };
                for n in start..(start + 1024).min(count) {
                    let values = [Value::Int(n), Value::Int(-n), Value::Int(n + 7)];
                    let extra = from_values(ctx, &values, "list").unwrap();
                    list = concat(ctx, list, extra, "concat").unwrap();
                    model.extend([n, -n, n + 7]);
                }
                ctx.store(&mut saved, list);
            });
            if heap.stats().allocated_bytes - collected_bytes > 64 * 1024 * 1024 {
                heap.collect(&saved);
                collected_bytes = heap.stats().allocated_bytes;
            }
        }
        heap.collect(&saved);
        heap.epoch(|ctx| {
            let list = ctx.load(&saved);
            assert_eq!(ints(ctx, list), model);
            assert_eq!(
                usize::try_from(len(ctx, list).unwrap()).unwrap(),
                model.len()
            );
            ctx.discard(saved);
        });
        assert!(heap.take_fault().is_none());
    }
}
