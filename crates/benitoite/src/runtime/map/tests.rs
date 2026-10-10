//! 公開のコレクション操作と独立したモデルの比較（設計書 07-03「ほかの章が求めるテスト（初回リリース版）」）。

// 作成時の関門: 公開 API の順序・永続性・集合演算と、元の鍵の保存を守る。
// 回転や分割の取り違えは既存の仮置きのテストでは検出できない。
// BTreeMap・BTreeSet を独立した期待値とし、公開の口を増やさない。
// 大きな木の確保数は R37 が個別に要求する共有の契約として測る。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::base::Decimal;
use crate::runtime::{
    heap::{CtorTag, FieldsKind, Heap, HeapConfig},
    list,
};
use std::collections::{BTreeMap, BTreeSet};

fn random(seed: &mut u64) -> u64 {
    *seed ^= *seed << 13;
    *seed ^= *seed >> 7;
    *seed ^= *seed << 17;
    *seed
}
fn key<'e>(ctx: &ValueCtx<'e>, mode: u8, n: i64) -> Value<'e> {
    match mode {
        0 => Value::Int(n),
        1 => ctx.alloc_str(&format!("{n:04}"), "test").unwrap(),
        _ if n == 0 => Value::Tag(CtorTag(0)),
        _ => ctx
            .alloc_fields(FieldsKind::Ctor, 1, &[Value::Int(n)])
            .unwrap(),
    }
}
fn number<'e>(ctx: &ValueCtx<'e>, mode: u8, v: Value<'e>) -> i64 {
    match mode {
        0 => v.as_int().unwrap(),
        1 => ctx.str(v).unwrap().parse().unwrap(),
        _ if matches!(v, Value::Tag(CtorTag(0))) => 0,
        _ => ctx.field(v, 0).unwrap().as_int().unwrap(),
    }
}
fn contents<'e>(ctx: &ValueCtx<'e>, mode: u8, m: Value<'e>) -> Vec<(i64, i64)> {
    map_to_vec(ctx, m)
        .unwrap()
        .into_iter()
        .map(|(k, v)| (number(ctx, mode, k), v.as_int().unwrap()))
        .collect()
}
fn elements<'e>(ctx: &ValueCtx<'e>, mode: u8, s: Value<'e>) -> Vec<i64> {
    set_to_vec(ctx, s)
        .unwrap()
        .into_iter()
        .map(|k| number(ctx, mode, k))
        .collect()
}

#[test]
fn randomized_operations_match_models_and_preserve_inputs_across_collection() {
    for mode in 0..3 {
        let mut heap = Heap::new(HeapConfig {
            stress: true,
            ..HeapConfig::default()
        });
        let mut roots =
            heap.epoch(|ctx| vec![ctx.new_slot(Value::EmptyMap), ctx.new_slot(Value::EmptySet)]);
        let mut model = BTreeMap::new();
        let mut set_model = BTreeSet::new();
        let mut seed = 0x91af_5352_0984_2311;
        for step in 0..if cfg!(miri) { 24 } else { 2400 } {
            let n = i64::try_from(random(&mut seed) % 257).unwrap();
            let op = random(&mut seed) % 8;
            heap.epoch(|ctx| {
                let old_map = ctx.load(&roots[0]);
                let old_set = ctx.load(&roots[1]);
                let before_map = contents(ctx, mode, old_map);
                let before_set = elements(ctx, mode, old_set);
                let mut map = old_map;
                let mut set = old_set;
                let k = key(ctx, mode, n);
                match op {
                    0..=2 => {
                        map = map_insert(ctx, map, k, Value::Int(step), "test").unwrap();
                        set = set_insert(ctx, set, k, "test").unwrap();
                        model.insert(n, step);
                        set_model.insert(n);
                    }
                    3 => {
                        map = map_remove(ctx, map, k).unwrap();
                        set = set_remove(ctx, set, k).unwrap();
                        model.remove(&n);
                        set_model.remove(&n);
                    }
                    4 => {
                        assert_eq!(
                            map_get(ctx, map, k).unwrap().map(|v| v.as_int().unwrap()),
                            model.get(&n).copied()
                        );
                        assert_eq!(set_contains(ctx, set, k).unwrap(), set_model.contains(&n));
                    }
                    _ => {
                        let mut other = Value::EmptySet;
                        let mut other_model = BTreeSet::new();
                        for _ in 0..random(&mut seed) % 80 {
                            let j = i64::try_from(random(&mut seed) % 257).unwrap();
                            other = set_insert(ctx, other, key(ctx, mode, j), "test").unwrap();
                            other_model.insert(j);
                        }
                        match op {
                            5 => {
                                set = set_union(ctx, set, other, "test").unwrap();
                                set_model = set_model.union(&other_model).copied().collect();
                            }
                            6 => {
                                set = set_intersection(ctx, set, other).unwrap();
                                set_model = set_model.intersection(&other_model).copied().collect();
                            }
                            _ => {
                                set = set_difference(ctx, set, other).unwrap();
                                set_model = set_model.difference(&other_model).copied().collect();
                            }
                        }
                    }
                }
                assert_eq!(map_len(ctx, map).unwrap() as usize, model.len());
                assert_eq!(set_len(ctx, set).unwrap() as usize, set_model.len());
                assert_eq!(
                    contents(ctx, mode, map),
                    model.iter().map(|(&k, &v)| (k, v)).collect::<Vec<_>>()
                );
                assert_eq!(
                    elements(ctx, mode, set),
                    set_model.iter().copied().collect::<Vec<_>>()
                );
                assert_eq!(contents(ctx, mode, old_map), before_map);
                assert_eq!(elements(ctx, mode, old_set), before_set);
                ctx.store(&mut roots[0], map);
                ctx.store(&mut roots[1], set);
            });
            if step % 32 == 0 {
                heap.collect(&roots);
                assert!(heap.take_fault().is_none());
            }
        }
        heap.collect(&roots);
        assert!(heap.verify(&roots).is_ok());
        heap.epoch(|ctx| ctx.discard(roots));
        heap.collect(&Vec::<crate::runtime::heap::Slot>::new());
        assert!(heap.object_ids().is_empty());
    }
}

#[test]
fn equal_decimal_keys_keep_the_first_representation_in_updates_and_set_operations() {
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let first = ctx.alloc_decimal(Decimal::new(10, 1).unwrap());
        let second = ctx.alloc_decimal(Decimal::new(100, 2).unwrap());
        let original = map_insert(ctx, Value::EmptyMap, first, Value::Int(3), "test").unwrap();
        let updated = map_insert(ctx, original, second, Value::Int(7), "test").unwrap();
        let pairs = map_to_vec(ctx, updated).unwrap();
        assert_eq!(ctx.decimal(pairs[0].0).unwrap().to_text(), "1.0");
        assert_eq!(pairs[0].1.as_int(), Some(7));
        assert_eq!(
            map_get(ctx, original, first).unwrap().unwrap().as_int(),
            Some(3)
        );
        let a = set_insert(ctx, Value::EmptySet, first, "test").unwrap();
        let b = set_insert(ctx, Value::EmptySet, second, "test").unwrap();
        for s in [
            set_insert(ctx, a, second, "test").unwrap(),
            set_union(ctx, a, b, "test").unwrap(),
            set_intersection(ctx, a, b).unwrap(),
        ] {
            assert_eq!(
                ctx.decimal(set_to_vec(ctx, s).unwrap()[0])
                    .unwrap()
                    .to_text(),
                "1.0"
            );
        }
        // a が大きいときにも、b を軸にする分割で a の要素を保つ。
        let a = set_insert(ctx, a, ctx.alloc_decimal(Decimal::from_integer(2)), "test").unwrap();
        for s in [
            set_union(ctx, a, b, "test").unwrap(),
            set_intersection(ctx, a, b).unwrap(),
        ] {
            assert_eq!(
                ctx.decimal(set_to_vec(ctx, s).unwrap()[0])
                    .unwrap()
                    .to_text(),
                "1.0"
            );
        }
    });
}

#[test]
fn key_order_is_lexicographic_for_all_key_kinds_and_rejects_invalid_values() {
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let xs = |xs: &[_]| list::from_values(ctx, xs, "test").unwrap();
        let ctor = |tag, xs: &[_]| ctx.alloc_fields(FieldsKind::Ctor, tag, xs).unwrap();
        let dec = |n, s| ctx.alloc_decimal(Decimal::new(n, s).unwrap());
        let set = |xs: &[_]| set_from_sorted(ctx, xs, "test").unwrap();
        let map = |xs: &[(_, _)]| map_from_sorted(ctx, xs, "test").unwrap();
        let cases = [
            (Value::Int(-4), Value::Int(3), Ordering::Less),
            (Value::Byte(0), Value::Byte(255), Ordering::Less),
            (Value::Char('é'), Value::Char('あ'), Ordering::Less),
            (Value::Bool(false), Value::Bool(true), Ordering::Less),
            (Value::Unit, Value::Unit, Ordering::Equal),
            (dec(-10, 1), dec(-100, 2), Ordering::Equal),
            (dec(10, 1), dec(101, 2), Ordering::Less),
            (
                ctx.alloc_str("a", "test").unwrap(),
                ctx.alloc_str("aa", "test").unwrap(),
                Ordering::Less,
            ),
            (
                ctx.alloc_str("é", "test").unwrap(),
                ctx.alloc_str("あ", "test").unwrap(),
                Ordering::Less,
            ),
            (
                ctx.alloc_bytes(&[1], "test").unwrap(),
                ctx.alloc_bytes(&[1, 0], "test").unwrap(),
                Ordering::Less,
            ),
            (
                ctx.alloc_bytes(&[1, 3], "test").unwrap(),
                ctx.alloc_bytes(&[1, 2, 99], "test").unwrap(),
                Ordering::Greater,
            ),
            (
                Value::Tag(CtorTag(0)),
                ctor(1, &[Value::Int(-1)]),
                Ordering::Less,
            ),
            (
                ctor(0, &[Value::Int(9)]),
                Value::Tag(CtorTag(1)),
                Ordering::Less,
            ),
            (
                ctor(1, &[Value::Int(1), Value::Int(9)]),
                ctor(1, &[Value::Int(2), Value::Int(0)]),
                Ordering::Less,
            ),
            (
                xs(&[Value::Int(1)]),
                xs(&[Value::Int(1), Value::Int(0)]),
                Ordering::Less,
            ),
            (
                xs(&[Value::Int(2)]),
                xs(&[Value::Int(1), Value::Int(99)]),
                Ordering::Greater,
            ),
            (
                set(&[Value::Int(1)]),
                set(&[Value::Int(1), Value::Int(2)]),
                Ordering::Less,
            ),
            (
                set(&[Value::Int(2)]),
                set(&[Value::Int(1), Value::Int(3)]),
                Ordering::Greater,
            ),
            (
                map(&[(Value::Int(1), Value::Int(9))]),
                map(&[(Value::Int(2), Value::Int(0))]),
                Ordering::Less,
            ),
            (
                map(&[(Value::Int(1), Value::Int(2))]),
                map(&[(Value::Int(1), Value::Int(3))]),
                Ordering::Less,
            ),
            (
                map(&[(Value::Int(1), Value::Int(2))]),
                map(&[
                    (Value::Int(1), Value::Int(2)),
                    (Value::Int(3), Value::Int(0)),
                ]),
                Ordering::Less,
            ),
            (Value::EmptySet, set(&[Value::Int(0)]), Ordering::Less),
            (
                Value::EmptyMap,
                map(&[(Value::Int(0), Value::Unit)]),
                Ordering::Less,
            ),
        ];
        // R36: 鍵の辞書式比較は、異なる木の形・内部ノードの境界・長い共通接頭辞を
        // 要素列で扱う。小さい既存の鍵では Cursor の内部ノードに届かない。
        let count = if cfg!(miri) { 35 } else { 1057 };
        let items: Vec<_> = (0..count).map(Value::Int).collect();
        let strict = xs(&items);
        let mut joined = Value::EmptyList;
        for chunk in items.chunks(17) {
            joined = list::concat(ctx, joined, xs(chunk), "test").unwrap();
        }
        assert_eq!(compare_keys(ctx, strict, joined).unwrap(), Ordering::Equal);
        let prefix = list::slice(ctx, joined, 0, u32::try_from(count - 1).unwrap()).unwrap();
        let smaller = list::append(ctx, prefix, Value::Int(-1), "test").unwrap();
        for (a, b, expected) in [
            (prefix, strict, Ordering::Less),
            (strict, prefix, Ordering::Greater),
            (strict, smaller, Ordering::Greater),
            (smaller, joined, Ordering::Less),
            (xs(&[strict]), xs(&[joined]), Ordering::Equal),
        ] {
            assert_eq!(compare_keys(ctx, a, b).unwrap(), expected);
        }
        for (a, b, expected) in cases {
            assert_eq!(compare_keys(ctx, a, b).unwrap(), expected);
            assert_eq!(compare_keys(ctx, b, a).unwrap(), expected.reverse());
        }
        for bad in [
            Value::Float(1.0),
            ctx.alloc_cell(Value::Int(0)),
            ctor(1, &[Value::Float(0.0)]),
            xs(&[Value::Float(0.0)]),
            map(&[(Value::Int(0), Value::Float(0.0))]),
        ] {
            assert!(matches!(
                compare_keys(ctx, bad, bad),
                Err(Stop::Internal(_))
            ));
            assert!(matches!(
                set_insert(ctx, Value::EmptySet, bad, "test"),
                Err(Stop::Internal(_))
            ));
        }
        assert!(matches!(
            compare_keys(ctx, Value::Int(1), Value::Bool(true)),
            Err(Stop::Internal(_))
        ));
        let mut a = Value::Int(1);
        let mut b = Value::Int(2);
        for _ in 0..if cfg!(miri) { 24 } else { 20_000 } {
            a = ctor(0, &[a]);
            b = ctor(0, &[b]);
        }
        assert_eq!(compare_keys(ctx, a, b).unwrap(), Ordering::Less);
    });
}

#[test]
#[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
fn million_element_trees_support_updates_and_union_shares_the_large_input() {
    let count: i64 = if cfg!(miri) { 32 } else { 1_000_000 };
    let mut heap = Heap::new(HeapConfig {
        stress: true,
        ..HeapConfig::default()
    });
    let mut roots = heap.epoch(|ctx| {
        let pairs: Vec<_> = (0..count)
            .map(|n| (Value::Int(n), Value::Int(-n)))
            .collect();
        let items: Vec<_> = (0..count).map(Value::Int).collect();
        let map = map_from_sorted(ctx, &pairs, "test").unwrap();
        let set = set_from_sorted(ctx, &items, "test").unwrap();
        assert_eq!(
            contents(ctx, 0, map),
            (0..count).map(|n| (n, -n)).collect::<Vec<_>>()
        );
        assert_eq!(elements(ctx, 0, set), (0..count).collect::<Vec<_>>());
        vec![ctx.new_slot(map), ctx.new_slot(set)]
    });
    heap.collect(&roots);
    let small = heap.epoch(|ctx| {
        let mut small = Value::EmptySet;
        for n in [
            0,
            count / 7,
            count / 2,
            count - 1,
            count,
            count + 1,
            count * 2,
        ] {
            small = set_insert(ctx, small, Value::Int(n), "test").unwrap();
        }
        ctx.new_slot(small)
    });
    let before = heap.stats().allocations;
    let unions = heap.epoch(|ctx| {
        let large = ctx.load(&roots[1]);
        let small = ctx.load(&small);
        let a = set_union(ctx, large, small, "test").unwrap();
        let b = set_union(ctx, small, large, "test").unwrap();
        let expected: Vec<_> = (0..count).chain([count, count + 1, count * 2]).collect();
        assert_eq!(elements(ctx, 0, a), expected);
        assert_eq!(elements(ctx, 0, b), expected);
        vec![ctx.new_slot(a), ctx.new_slot(b)]
    });
    let allocations = heap.stats().allocations - before;
    let log = u64::from(count.ilog2() + 1);
    assert!(
        allocations <= 64 * 7 * log,
        "union allocated {allocations} objects"
    );
    heap.epoch(|ctx| {
        ctx.discard(unions);
        ctx.discard(small);
        let original_map = ctx.load(&roots[0]);
        let original_set = ctx.load(&roots[1]);
        let mut map = original_map;
        let mut set = original_set;
        let changes = count.min(512);
        for i in 0..changes {
            let n = (i * 7919) % count;
            assert_eq!(
                map_get(ctx, map, Value::Int(n)).unwrap().unwrap().as_int(),
                Some(-n)
            );
            assert!(set_contains(ctx, set, Value::Int(n)).unwrap());
            map = map_remove(ctx, map, Value::Int(n)).unwrap();
            set = set_remove(ctx, set, Value::Int(n)).unwrap();
            assert!(map_get(ctx, map, Value::Int(n)).unwrap().is_none());
            assert!(!set_contains(ctx, set, Value::Int(n)).unwrap());
            assert_eq!(
                map_get(ctx, original_map, Value::Int(n))
                    .unwrap()
                    .unwrap()
                    .as_int(),
                Some(-n)
            );
            assert!(set_contains(ctx, original_set, Value::Int(n)).unwrap());
        }
        assert_eq!(i64::from(map_len(ctx, map).unwrap()), count - changes);
        assert_eq!(i64::from(set_len(ctx, set).unwrap()), count - changes);
        // 末尾への挿入でも経路だけを写し、元の木を保つ。
        map = map_insert(ctx, map, Value::Int(count), Value::Int(42), "test").unwrap();
        set = set_insert(ctx, set, Value::Int(count), "test").unwrap();
        ctx.store(&mut roots[0], map);
        ctx.store(&mut roots[1], set);
    });
    heap.collect(&roots);
    assert!(heap.verify(&roots).is_ok());
    assert!(heap.take_fault().is_none());
    heap.epoch(|ctx| ctx.discard(roots));
    heap.collect(&Vec::<crate::runtime::heap::Slot>::new());
    assert!(heap.object_ids().is_empty());
}
