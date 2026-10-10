//! マップと集合の値（設計書 03-06「Map と Set（初回リリース版）」、02-08「値の表現」）。
//! MapNode の欄は（鍵、値、左、右）、SetNode は（要素、左、右）。tag は部分木の要素数である。
//! 空の子は EmptyMap・EmptySet。重みは要素数 + 1、平衡と回転の定数は Δ = 3、Γ = 2。
//! 不変のノードを共有し、変更の道筋を明示の積み重ねから写し直す。

use std::cmp::Ordering;

use crate::runtime::Stop;
use crate::runtime::heap::{Value, ValueCtx};

mod keys;
mod tree;
pub(super) use tree::Cursor;
use tree::TreeKind::{Map, Set};

/// 二つの鍵を鍵の順序で比べる。鍵の型でない値に出会ったら `Stop::Internal`。
pub fn compare_keys<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>) -> Result<Ordering, Stop> {
    keys::compare(ctx, a, b)
}

/// 鍵の順に並べた、同じ鍵を含まない組の並びからマップを作る（定数の記述から作るとき）。
pub fn map_from_sorted<'e>(
    ctx: &ValueCtx<'e>,
    pairs: &[(Value<'e>, Value<'e>)],
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let _ = function;
    Map.build_sorted(ctx, pairs)
}
/// 組の数。マップでなければ `Stop::Internal`。
pub fn map_len<'e>(ctx: &ValueCtx<'e>, map: Value<'e>) -> Result<u32, Stop> {
    Map.len(ctx, map)
}
/// 鍵に対応する値。鍵がなければ `None`。
pub fn map_get<'e>(
    ctx: &ValueCtx<'e>,
    map: Value<'e>,
    key: Value<'e>,
) -> Result<Option<Value<'e>>, Stop> {
    Ok(Map.find(ctx, map, key)?.map(|node| node.value))
}
/// `key` の値を `value` にしたマップ。`key` が既にあれば元の鍵を保つ。
pub fn map_insert<'e>(
    ctx: &ValueCtx<'e>,
    map: Value<'e>,
    key: Value<'e>,
    value: Value<'e>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let _ = function;
    Map.insert(ctx, map, key, value)
}
/// 鍵を除いたマップ。鍵がなければ元のマップを返す。
pub fn map_remove<'e>(
    ctx: &ValueCtx<'e>,
    map: Value<'e>,
    key: Value<'e>,
) -> Result<Value<'e>, Stop> {
    Map.remove(ctx, map, key)
}
/// 鍵の順に並べた組。
pub fn map_to_vec<'e>(
    ctx: &ValueCtx<'e>,
    map: Value<'e>,
) -> Result<Vec<(Value<'e>, Value<'e>)>, Stop> {
    let mut cursor = Cursor::new(map, Map);
    let mut pairs = Vec::new();
    while let Some((key, value)) = cursor.next(ctx)? {
        pairs.push((key, value));
    }
    Ok(pairs)
}

/// 鍵の順に並べた、同じ要素を含まない並びから集合を作る（定数の記述から作るとき）。
pub fn set_from_sorted<'e>(
    ctx: &ValueCtx<'e>,
    items: &[Value<'e>],
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let _ = function;
    let pairs: Vec<_> = items.iter().map(|&x| (x, Value::Unit)).collect();
    Set.build_sorted(ctx, &pairs)
}
/// 要素の数。集合でなければ `Stop::Internal`。
pub fn set_len<'e>(ctx: &ValueCtx<'e>, set: Value<'e>) -> Result<u32, Stop> {
    Set.len(ctx, set)
}
/// 鍵の順序で同じ要素が集合にあるか。
pub fn set_contains<'e>(ctx: &ValueCtx<'e>, set: Value<'e>, x: Value<'e>) -> Result<bool, Stop> {
    Ok(Set.find(ctx, set, x)?.is_some())
}
/// `x` を加えた集合。同じ要素が既にあれば元の要素を保つ。
pub fn set_insert<'e>(
    ctx: &ValueCtx<'e>,
    set: Value<'e>,
    x: Value<'e>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let _ = function;
    Set.insert(ctx, set, x, Value::Unit)
}
/// 要素を除いた集合。要素がなければ元の集合を返す。
pub fn set_remove<'e>(ctx: &ValueCtx<'e>, set: Value<'e>, x: Value<'e>) -> Result<Value<'e>, Stop> {
    Set.remove(ctx, set, x)
}
/// 二つの集合の和。同じ要素では第一の集合の表現を保つ。
pub fn set_union<'e>(
    ctx: &ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let _ = function;
    tree::combine(ctx, a, b, tree::Operation::Union)
}
/// 二つの集合の共通部分。同じ要素では第一の集合の表現を保つ。
pub fn set_intersection<'e>(
    ctx: &ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
) -> Result<Value<'e>, Stop> {
    tree::combine(ctx, a, b, tree::Operation::Intersection)
}
/// 第一の集合から第二の集合の要素を除いた差。
pub fn set_difference<'e>(
    ctx: &ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
) -> Result<Value<'e>, Stop> {
    tree::combine(ctx, a, b, tree::Operation::Difference)
}
/// 鍵の順に並べた要素。
pub fn set_to_vec<'e>(ctx: &ValueCtx<'e>, set: Value<'e>) -> Result<Vec<Value<'e>>, Stop> {
    let mut cursor = Cursor::new(set, Set);
    let mut items = Vec::new();
    while let Some((key, _)) = cursor.next(ctx)? {
        items.push(key);
    }
    Ok(items)
}

#[cfg(test)]
mod tests;
