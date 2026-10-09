//! Map の組み込みの関数（設計書 03-06「Map と Set（初回リリース版）」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::FieldsKind;
use crate::runtime::heap::Value;
use crate::runtime::{Stop, list, map};

builtin! {
    /// `Map.empty` の本体（実装プラン 10-12「リスト・マップ・集合」）。
    name = "Map.empty",
    pure fn empty(ctx) -> Value<'e> {
        let _ = ctx;
        Ok(Value::EmptyMap)
    }
}

builtin! {
    /// `Map.fromList` の本体（実装プラン 10-12「リスト・マップ・集合」）。
    name = "Map.fromList",
    pure fn from_list(ctx, xs: Value<'e>) -> Value<'e> {
        let mut result = Value::EmptyMap;
        let mut cursor = list::cursor(&ctx, xs)?;
        while let Some(x) = cursor.next(&ctx)? {
            if ctx.fields_header(x) != Some((FieldsKind::Ctor, tags::PAIR)) || ctx.fields_len(x) != Some(2) {
                return Err(Stop::Internal("Map.fromList requires Pair values".into()));
            }
            let key = ctx.field(x, 0).ok_or_else(|| Stop::Internal("Pair key missing".into()))?;
            let value = ctx.field(x, 1).ok_or_else(|| Stop::Internal("Pair value missing".into()))?;
            result = map::map_insert(&ctx, result, key, value, "Map.fromList")?;
        }
        Ok(result)
    }
}

builtin! {
    /// `Map.toList` の本体（実装プラン 10-12「リスト・マップ・集合」）。
    name = "Map.toList",
    pure fn to_list(ctx, xs: Value<'e>) -> Value<'e> {
        let pairs = map::map_to_vec(&ctx, xs)?;
        let items: Result<Vec<_>, Stop> = pairs.into_iter().map(|(k, v)| ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[k, v])).collect();
        list::from_values(&ctx, &items?, "Map.toList")
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[empty::DECL, from_list::DECL, to_list::DECL];

#[cfg(test)]
pub(in crate::builtins::funcs) mod tests {
    // 関門: 三つの本体が型付きの引数と Pair・リストを正しく接続する契約。
    // ランタイムの木のテストでは項目の配線とタグの誤りを検出できない。
    // 10-12 の個別の指示どおり直接呼び、公開の口を増やさない。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::builtins::iface::CallCtx;
    use crate::runtime::heap::{Heap, HeapConfig};

    #[test]
    fn construction_and_sorted_list_conversion_keep_first_keys() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let call = CallCtx::new(ctx, None, None, None);
            let empty = empty(call.pure_ctx()).unwrap();
            assert!(matches!(empty, Value::EmptyMap));

            assert!(matches!(
                direct!(ctx, to_list, empty).unwrap(),
                Value::EmptyList
            ));
            let d = |n, s| ctx.alloc_decimal(crate::base::Decimal::new(n, s).unwrap());
            let first = d(10, 1);
            let duplicate = d(100, 2);
            let pair = |k, v| {
                ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[k, Value::Int(v)])
                    .unwrap()
            };
            let xs = list::from_values(
                ctx,
                &[pair(d(2, 0), 2), pair(first, 3), pair(duplicate, 7)],
                "test",
            )
            .unwrap();
            let m = direct!(ctx, from_list, xs).unwrap();
            let result = direct!(ctx, to_list, m).unwrap();
            let items = list::to_vec(ctx, result).unwrap();
            assert_eq!(items.len(), 2);
            let observed: Vec<_> = items
                .iter()
                .map(|&p| {
                    assert_eq!(ctx.fields_header(p), Some((FieldsKind::Ctor, tags::PAIR)));
                    assert_eq!(ctx.fields_len(p), Some(2));
                    (
                        ctx.decimal(ctx.field(p, 0).unwrap()).unwrap().to_text(),
                        ctx.field(p, 1).unwrap().as_int().unwrap(),
                    )
                })
                .collect();
            assert_eq!(observed, vec![("1.0".to_string(), 7), ("2".to_string(), 2)]);
            assert_eq!(list::len(ctx, xs).unwrap(), 3);
            let bad = list::from_values(ctx, &[Value::Int(1)], "test").unwrap();
            assert!(matches!(
                direct!(ctx, from_list, bad),
                Err(Stop::Internal(_))
            ));
            assert!(matches!(
                direct!(ctx, from_list, Value::EmptyList).unwrap(),
                Value::EmptyMap
            ));
            assert!(matches!(
                direct!(ctx, from_list, Value::Int(1)),
                Err(Stop::Internal(_))
            ));
            assert!(matches!(
                direct!(ctx, to_list, Value::Int(1)),
                Err(Stop::Internal(_))
            ));
        });
        assert!(heap.take_fault().is_none());
    }

    // 関門: L02 の型付きの入口で、引数の位置・Option の包み・鍵順のリスト・永続性を守る。
    // runtime::map のモデル比較では入口の配線の誤りは分からない。L02 の個別の指示で
    // 同じ固定種の生成器を入口に適用する。木の形を読まず、公開の口も増やさない。
    use crate::base::Decimal;
    use crate::runtime::heap::{CtorTag, NoGcCtx, ValueCtx};
    use std::collections::BTreeMap;

    // Set のテストでも同じ鍵の準備を使う。公開範囲はテストのモジュールだけである。
    #[derive(Clone, Copy, Debug)]
    pub(in crate::builtins::funcs) enum KeyKind {
        Integer,
        String,
        Decimal,
        Constructor,
        Pair,
    }
    pub(in crate::builtins::funcs) const KEY_KINDS: [KeyKind; 5] = [
        KeyKind::Integer,
        KeyKind::String,
        KeyKind::Decimal,
        KeyKind::Constructor,
        KeyKind::Pair,
    ];
    pub(in crate::builtins::funcs) fn key<'e>(
        ctx: &ValueCtx<'e>,
        kind: KeyKind,
        n: i64,
    ) -> Value<'e> {
        match kind {
            KeyKind::Integer => Value::Int(n),
            KeyKind::String => ctx.alloc_str(&format!("{n:04}"), "test").unwrap(),
            KeyKind::Decimal => ctx.alloc_decimal(Decimal::new(i128::from(n) * 10, 1).unwrap()),
            KeyKind::Constructor if n == 0 => Value::Tag(CtorTag(200)),
            KeyKind::Constructor => ctx
                .alloc_fields(FieldsKind::Ctor, 201, &[Value::Int(n)])
                .unwrap(),
            KeyKind::Pair => ctx
                .alloc_fields(
                    FieldsKind::Ctor,
                    tags::PAIR,
                    &[Value::Int(n / 16), Value::Int(n % 16)],
                )
                .unwrap(),
        }
    }
    pub(in crate::builtins::funcs) fn number<'e>(
        ctx: &ValueCtx<'e>,
        kind: KeyKind,
        v: Value<'e>,
    ) -> i64 {
        match kind {
            KeyKind::Integer => v.as_int().unwrap(),
            KeyKind::String => ctx.str(v).unwrap().parse().unwrap(),
            KeyKind::Decimal => ctx
                .decimal(v)
                .unwrap()
                .to_text()
                .split_once('.')
                .unwrap()
                .0
                .parse()
                .unwrap(),
            KeyKind::Constructor if matches!(v, Value::Tag(CtorTag(200))) => 0,
            KeyKind::Constructor => ctx.field(v, 0).unwrap().as_int().unwrap(),
            KeyKind::Pair => {
                ctx.field(v, 0).unwrap().as_int().unwrap() * 16
                    + ctx.field(v, 1).unwrap().as_int().unwrap()
            }
        }
    }
    pub(in crate::builtins::funcs) fn random(seed: &mut u64) -> u64 {
        *seed ^= *seed << 13;
        *seed ^= *seed >> 7;
        *seed ^= *seed << 17;
        *seed
    }
    fn contents<'e>(ctx: &mut NoGcCtx<'e>, kind: KeyKind, m: Value<'e>) -> Vec<(i64, i64)> {
        {
            let result = direct!(ctx, to_list, m).unwrap();
            list::to_vec(ctx, result)
        }
        .unwrap()
        .into_iter()
        .map(|p| {
            (
                number(ctx, kind, ctx.field(p, 0).unwrap()),
                ctx.field(p, 1).unwrap().as_int().unwrap(),
            )
        })
        .collect()
    }
    fn lookup<'e>(ctx: &mut NoGcCtx<'e>, m: Value<'e>, k: Value<'e>) -> Option<i64> {
        let value = direct!(ctx, get, m, k).unwrap();
        if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
            return None;
        }
        assert_eq!(
            ctx.fields_header(value),
            Some((FieldsKind::Ctor, tags::OPTION_SOME))
        );
        assert_eq!(ctx.fields_len(value), Some(1));
        Some(ctx.field(value, 0).unwrap().as_int().unwrap())
    }

    #[test]
    fn remaining_functions_cover_empty_singleton_and_large_maps_for_each_key_kind() {
        for kind in KEY_KINDS {
            for count in [0, 1, 1024] {
                let mut heap = Heap::new(HeapConfig::default());
                heap.epoch(|ctx| {
                    let mut m = Value::EmptyMap;
                    for n in (0..count).rev() {
                        m = direct!(ctx, set, m, key(ctx, kind, n), Value::Int(-n)).unwrap();
                    }
                    let expected: Vec<_> = (0..count).map(|n| (n, -n)).collect();
                    assert_eq!(contents(ctx, kind, m), expected);
                    assert_eq!(direct!(ctx, size, m).unwrap().as_int(), Some(count));
                    let ks = direct!(ctx, keys, m).unwrap();
                    let vs = direct!(ctx, values, m).unwrap();
                    assert_eq!(
                        list::to_vec(ctx, ks)
                            .unwrap()
                            .into_iter()
                            .map(|v| number(ctx, kind, v))
                            .collect::<Vec<_>>(),
                        (0..count).collect::<Vec<_>>()
                    );
                    assert_eq!(
                        list::to_vec(ctx, vs)
                            .unwrap()
                            .into_iter()
                            .map(|v| v.as_int().unwrap())
                            .collect::<Vec<_>>(),
                        (0..count).map(|n| -n).collect::<Vec<_>>()
                    );
                    for n in 0..count {
                        let k = key(ctx, kind, n);
                        assert_eq!(lookup(ctx, m, k), Some(-n));
                        assert!(matches!(
                            direct!(ctx, contains, m, k).unwrap(),
                            Value::Bool(true)
                        ));
                    }
                    let missing = key(ctx, kind, count);
                    assert_eq!(lookup(ctx, m, missing), None);
                    assert!(matches!(
                        direct!(ctx, contains, m, missing).unwrap(),
                        Value::Bool(false)
                    ));
                    let unchanged = direct!(ctx, remove, m, missing).unwrap();
                    assert_eq!(contents(ctx, kind, unchanged), expected);
                    let inserted = direct!(ctx, set, m, missing, Value::Int(77)).unwrap();
                    assert_eq!(lookup(ctx, inserted, missing), Some(77));
                    assert_eq!(
                        direct!(ctx, size, inserted).unwrap().as_int(),
                        Some(count + 1)
                    );
                    if count > 0 {
                        let k = key(ctx, kind, 0);
                        let updated = direct!(ctx, set, m, k, Value::Int(99)).unwrap();
                        assert_eq!(lookup(ctx, updated, k), Some(99));
                        assert_eq!(direct!(ctx, size, updated).unwrap().as_int(), Some(count));
                        let removed = direct!(ctx, remove, m, k).unwrap();
                        assert_eq!(contents(ctx, kind, removed), expected[1..]);
                    }
                    assert_eq!(contents(ctx, kind, m), expected);
                });
                assert!(heap.take_fault().is_none());
            }
        }
    }

    #[test]
    fn remaining_map_operations_match_model_and_preserve_inputs_across_collection() {
        for kind in KEY_KINDS {
            let mut heap = Heap::new(HeapConfig {
                stress: true,
                ..HeapConfig::default()
            });
            let mut roots = heap.epoch(|ctx| vec![ctx.new_slot(Value::EmptyMap)]);
            let mut model = BTreeMap::new();
            let mut seed = 0x91af_5352_0984_2311;
            for step in 0..512 {
                let n = i64::try_from(random(&mut seed) % 257).unwrap();
                let op = random(&mut seed) % 7;
                heap.epoch(|ctx| {
                    let old = ctx.load(&roots[0]);
                    let before = contents(ctx, kind, old);
                    let k = key(ctx, kind, n);
                    let result = match op {
                        0..=2 => { model.insert(n, step); direct!(ctx, set, old, k, Value::Int(step)).unwrap() }
                        3 => { model.remove(&n); direct!(ctx, remove, old, k).unwrap() }
                        4 => { assert_eq!(lookup(ctx, old, k), model.get(&n).copied()); old }
                        5 => { assert!(matches!(direct!(ctx, contains, old, k).unwrap(), Value::Bool(b) if b == model.contains_key(&n))); old }
                        _ => { assert_eq!(direct!(ctx, size, old).unwrap().as_int(), Some(i64::try_from(model.len()).unwrap())); old }
                    };
                    assert_eq!(contents(ctx, kind, result), model.iter().map(|(&k, &v)| (k, v)).collect::<Vec<_>>(), "{kind:?}, step {step}");
                    assert_eq!(direct!(ctx, size, result).unwrap().as_int(), Some(i64::try_from(model.len()).unwrap()));
                    assert_eq!(contents(ctx, kind, old), before);
                    ctx.store(&mut roots[0], result);
                });
                if step % 32 == 0 {
                    heap.collect(&roots);
                    assert!(heap.take_fault().is_none());
                }
            }
            heap.collect(&roots);
            assert!(heap.verify(&roots).is_ok());
            heap.epoch(|ctx| ctx.discard(roots));
        }
    }

    #[test]
    fn set_keeps_original_decimal_key_while_replacing_only_the_value() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let first = ctx.alloc_decimal(Decimal::new(10, 1).unwrap());
            let duplicate = ctx.alloc_decimal(Decimal::new(100, 2).unwrap());
            let original = direct!(ctx, set, Value::EmptyMap, first, Value::Int(3)).unwrap();
            let updated = direct!(ctx, set, original, duplicate, Value::Int(7)).unwrap();
            for (m, expected) in [(original, 3), (updated, 7)] {
                assert_eq!(lookup(ctx, m, duplicate), Some(expected));
                assert!(matches!(
                    direct!(ctx, contains, m, duplicate).unwrap(),
                    Value::Bool(true)
                ));
                assert_eq!(direct!(ctx, size, m).unwrap().as_int(), Some(1));
                let ks = {
                    let result = direct!(ctx, keys, m).unwrap();
                    list::to_vec(ctx, result)
                }
                .unwrap();
                assert_eq!(ctx.decimal(ks[0]).unwrap().to_text(), "1.0");
                let vs = {
                    let result = direct!(ctx, values, m).unwrap();
                    list::to_vec(ctx, result)
                }
                .unwrap();
                assert_eq!(vs[0].as_int(), Some(expected));
                let removed = direct!(ctx, remove, m, duplicate).unwrap();
                assert!(contents(ctx, KeyKind::Decimal, removed).is_empty());
                assert_eq!(contents(ctx, KeyKind::Decimal, m), vec![(1, expected)]);
            }
        });
        assert!(heap.take_fault().is_none());
    }
}

builtin! {
    /// `Map.get` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.get",
    pure fn get(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        super::option(&ctx, map::map_get(&ctx, arg0, arg1)?)
    }
}

builtin! {
    /// `Map.set` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.set",
    pure fn set(ctx, arg0: Value<'e>, arg1: Value<'e>, arg2: Value<'e>) -> Value<'e> {
        map::map_insert(&ctx, arg0, arg1, arg2, "Map.set")
    }
}

builtin! {
    /// `Map.remove` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.remove",
    pure fn remove(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        map::map_remove(&ctx, arg0, arg1)
    }
}

builtin! {
    /// `Map.contains` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.contains",
    pure fn contains(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        Ok(Value::Bool(map::map_get(&ctx, arg0, arg1)?.is_some()))
    }
}

builtin! {
    /// `Map.size` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.size",
    pure fn size(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(i64::from(map::map_len(&ctx, arg0)?)))
    }
}

builtin! {
    /// `Map.keys` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.keys",
    pure fn keys(ctx, arg0: Value<'e>) -> Value<'e> {
        let items: Vec<_> = map::map_to_vec(&ctx, arg0)?.into_iter().map(|(k, _)| k).collect();
        list::from_values(&ctx, &items, "Map.keys")
    }
}

builtin! {
    /// `Map.values` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Map.values",
    pure fn values(ctx, arg0: Value<'e>) -> Value<'e> {
        let items: Vec<_> = map::map_to_vec(&ctx, arg0)?.into_iter().map(|(_, v)| v).collect();
        list::from_values(&ctx, &items, "Map.values")
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const MORE_DECLS: &[BuiltinDecl] = &[
    get::DECL,
    set::DECL,
    remove::DECL,
    contains::DECL,
    size::DECL,
    keys::DECL,
    values::DECL,
];
