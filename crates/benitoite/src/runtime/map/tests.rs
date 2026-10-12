//! 公開のコレクション操作と独立したモデルの比較（設計書 07-03「ほかの章が求めるテスト（初回リリース版）」）。

// 作成時の関門: 公開 API の順序・永続性・集合演算と、元の鍵の保存を守る。
// 回転や分割の取り違えを、操作の列とモデルの比較で検出する。
// BTreeMap・BTreeSet を独立した期待値とし、公開の口を増やさない。
// 大きな木の確保数を測り、道筋の外のノードを共有する契約を確かめる（設計書 03-06「Map と Set（初回リリース版）」）。
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
        // 鍵の辞書式比較は、異なる木の形・内部ノードの境界・長い共通接頭辞を
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

// 作成時の関門: 共有した鍵の比較を終え、後ろの成分が決める辞書式の順序を守る。
// 既存の深い構成子は子が一つなので、共有を展開する退行を捕まえない。
// 組を覚える仕組みが壊れると、共有を指数時間で展開するため、このテストは終わらなくなる。
// 別に作った等しい鍵と、等しい第 1 欄の後に違う第 2 欄を持つ鍵を公開の比較関数で調べる。
// 差し込み口は増やさない（設計書 03-06「Map と Set（初回リリース版）」、02-08「組み込みの関数の呼び出し」）。
#[test]
fn shared_keys_preserve_lexicographic_order_without_expansion() {
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for shape in ["constructor", "list", "map", "set"] {
            let pair = |a, b| crate::runtime::equal::test_support::pair(ctx, shape, a, b);
            let grow =
                |depth, leaf| crate::runtime::equal::test_support::grow(ctx, shape, depth, leaf);
            let a63 = grow(63, Value::Int(1));
            let a = pair(a63, a63);
            let b = pair(grow(63, Value::Int(1)), grow(63, Value::Int(1)));
            let c = pair(a63, grow(63, Value::Int(2)));
            for (case, x, y, expected) in [
                ("equal", a, b, Ordering::Equal),
                ("late lesser", a, c, Ordering::Less),
                ("late greater", c, a, Ordering::Greater),
            ] {
                assert_eq!(
                    compare_keys(ctx, x, y).unwrap(),
                    expected,
                    "{shape}: {case}"
                );
            }
        }
    });
    assert!(heap.take_fault().is_none());
}

// 作成時の関門: 対数の更新と、道筋の外の共有を公開 API の確保数と独立したモデルで守る。
// 偏った挿入と最小の鍵の削除で回転の向きの誤りを、集合演算で join の回転の欠落を捕まえる。
// 平衡の崩れは make の debug_assert! で捕まえるため、デバッグビルドで走らせる。
// 既存の無作為のテストは鍵が 257 種類で浅く、昇順・降順の更新を含まない。
// 差し込み口は増やさず、既存の heap.stats() で確保数を観察する
// （設計書 03-06「Map と Set（初回リリース版）」）。
#[test]
fn skewed_workloads_keep_update_paths_logarithmic() {
    let started = std::time::Instant::now();
    let count: i64 = if cfg!(feature = "gc-stress") {
        1 << 12
    } else {
        1 << 15
    };
    let log = u64::from(count.ilog2() + 1);
    // Δ = 3 では子の重みは親の 3/4 以下なので、高さ h は
    // log_(4/3)(n + 1) ≈ 2.41 * log2(n + 1) 以下である。
    // 挿入は道筋の各段で高々 3 ノードを作り、葉の 1 ノードを加えても 8 * log に収まる。
    // 削除は祖先・最小の取り出し・join の下りの各道筋をそれぞれ h 以下として、
    // 高々 9h + 1 ノードを見込む。24 * log はこの上界に余裕を加えた値である。
    let insert_bound = 8 * log;
    let remove_bound = 24 * log;
    for is_map in [true, false] {
        let mut heap = Heap::new(HeapConfig {
            stress: false,
            ..HeapConfig::default()
        });
        let mut roots = heap.epoch(|ctx| {
            let empty = if is_map {
                Value::EmptyMap
            } else {
                Value::EmptySet
            };
            vec![ctx.new_slot(empty), ctx.new_slot(empty)]
        });
        let mut map_model = BTreeMap::new();
        let mut set_model = BTreeSet::new();
        let mut max_insert = 0;
        for i in 0..count {
            let n = if is_map { i } else { count - 1 - i };
            let before = heap.stats().allocations;
            heap.epoch(|ctx| {
                let old = ctx.load(&roots[0]);
                let updated = if is_map {
                    map_insert(ctx, old, Value::Int(n), Value::Int(-n), "test").unwrap()
                } else {
                    set_insert(ctx, old, Value::Int(n), "test").unwrap()
                };
                ctx.store(&mut roots[0], updated);
            });
            let allocated = heap.stats().allocations - before;
            max_insert = max_insert.max(allocated);
            assert!(allocated <= insert_bound, "insert {n}: {allocated} objects");
            map_model.insert(n, -n);
            set_model.insert(n);
        }
        heap.epoch(|ctx| {
            let tree = ctx.load(&roots[0]);
            if is_map {
                assert_eq!(
                    contents(ctx, 0, tree),
                    map_model.iter().map(|(&k, &v)| (k, v)).collect::<Vec<_>>()
                );
            } else {
                assert_eq!(
                    elements(ctx, 0, tree),
                    set_model.iter().copied().collect::<Vec<_>>()
                );
            }
            ctx.store(&mut roots[1], tree);
        });
        // 回収は段の区切りだけで行う。毎操作では、強制の構成で木全体を何度も辿ってしまう。
        heap.collect(&roots);
        let mut max_remove = 0;
        for n in 0..count / 2 {
            let before = heap.stats().allocations;
            heap.epoch(|ctx| {
                let old = ctx.load(&roots[0]);
                let updated = if is_map {
                    map_remove(ctx, old, Value::Int(n)).unwrap()
                } else {
                    set_remove(ctx, old, Value::Int(n)).unwrap()
                };
                ctx.store(&mut roots[0], updated);
            });
            let allocated = heap.stats().allocations - before;
            max_remove = max_remove.max(allocated);
            assert!(allocated <= remove_bound, "remove {n}: {allocated} objects");
            map_model.remove(&n);
            set_model.remove(&n);
        }
        heap.collect(&roots);
        assert!(heap.take_fault().is_none());
        heap.epoch(|ctx| {
            if is_map {
                assert_eq!(
                    contents(ctx, 0, ctx.load(&roots[0])),
                    map_model.iter().map(|(&k, &v)| (k, v)).collect::<Vec<_>>()
                );
                assert_eq!(
                    contents(ctx, 0, ctx.load(&roots[1])),
                    (0..count).map(|n| (n, -n)).collect::<Vec<_>>()
                );
            } else {
                assert_eq!(
                    elements(ctx, 0, ctx.load(&roots[0])),
                    set_model.iter().copied().collect::<Vec<_>>()
                );
                assert_eq!(
                    elements(ctx, 0, ctx.load(&roots[1])),
                    (0..count).collect::<Vec<_>>()
                );
            }
            ctx.discard(roots);
        });
        eprintln!("is_map={is_map}: max insert={max_insert}, max remove={max_remove}");
    }

    // 4 要素の木と両端の集合の和は join の帰りに回転を要する。挿入の向きも反転する。
    for (large_count, descending) in [(4i64, false), (4, true), (count, false)] {
        let mut heap = Heap::new(HeapConfig::default());
        let large_model: BTreeSet<_> = (0..large_count).collect();
        let small_model: BTreeSet<_> = if large_count == 4 {
            [0, 3].into_iter().collect()
        } else {
            [
                0,
                count / 7,
                count / 2,
                count - 1,
                count,
                count + 1,
                count * 2,
            ]
            .into_iter()
            .collect()
        };
        let roots = heap.epoch(|ctx| {
            // 順序を偏らせた挿入で平衡の境界に近い木を作り、join の回転を試す。
            let mut large = Value::EmptySet;
            for i in 0..large_count {
                let n = if descending { large_count - 1 - i } else { i };
                large = set_insert(ctx, large, Value::Int(n), "test").unwrap();
            }
            let small = set_from_sorted(
                ctx,
                &small_model
                    .iter()
                    .copied()
                    .map(Value::Int)
                    .collect::<Vec<_>>(),
                "test",
            )
            .unwrap();
            vec![ctx.new_slot(large), ctx.new_slot(small)]
        });
        for operation in ["union", "intersection", "difference"] {
            for reverse in [false, true] {
                let before = heap.stats().allocations;
                heap.epoch(|ctx| {
                    let large = ctx.load(&roots[0]);
                    let small = ctx.load(&roots[1]);
                    let (a, b, am, bm) = if reverse {
                        (small, large, &small_model, &large_model)
                    } else {
                        (large, small, &large_model, &small_model)
                    };
                    let result = if operation == "union" {
                        set_union(ctx, a, b, "test").unwrap()
                    } else if operation == "intersection" {
                        set_intersection(ctx, a, b).unwrap()
                    } else {
                        set_difference(ctx, a, b).unwrap()
                    };
                    let expected: Vec<_> = if operation == "union" {
                        am.union(bm).copied().collect()
                    } else if operation == "intersection" {
                        am.intersection(bm).copied().collect()
                    } else {
                        am.difference(bm).copied().collect()
                    };
                    assert_eq!(elements(ctx, 0, result), expected);
                    assert_eq!(
                        elements(ctx, 0, large),
                        large_model.iter().copied().collect::<Vec<_>>()
                    );
                    assert_eq!(
                        elements(ctx, 0, small),
                        small_model.iter().copied().collect::<Vec<_>>()
                    );
                });
                let allocated = heap.stats().allocations - before;
                // 既存の和のテストと同じ、少数の分割・join の道筋に余裕を持たせた上限を使う。
                assert!(
                    allocated
                        <= 64
                            * u64::try_from(small_model.len()).unwrap()
                            * u64::from(large_count.ilog2() + 1),
                    "operation={operation}, reverse={reverse}, count={large_count}, descending={descending}: {allocated} objects"
                );
                eprintln!(
                    "operation={operation}, reverse={reverse}, count={large_count}, descending={descending}: allocated={allocated}"
                );
            }
        }
        heap.epoch(|ctx| ctx.discard(roots));
    }
    eprintln!("skewed workloads elapsed: {:?}", started.elapsed());
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
