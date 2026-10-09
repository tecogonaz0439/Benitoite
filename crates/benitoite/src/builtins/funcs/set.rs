//! Set の組み込みの関数（設計書 03-06「Map と Set（初回リリース版）」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;
use crate::runtime::{list, map};

builtin! {
    /// `Set.empty` の本体（実装プラン 10-12「リスト・マップ・集合」）。
    name = "Set.empty",
    pure fn empty(ctx) -> Value<'e> {
        let _ = ctx;
        Ok(Value::EmptySet)
    }
}

builtin! {
    /// `Set.fromList` の本体（実装プラン 10-12「リスト・マップ・集合」）。
    name = "Set.fromList",
    pure fn from_list(ctx, xs: Value<'e>) -> Value<'e> {
        let mut result = Value::EmptySet;
        let mut cursor = list::cursor(&ctx, xs)?;
        while let Some(x) = cursor.next(&ctx)? {
            result = map::set_insert(&ctx, result, x, "Set.fromList")?;
        }
        Ok(result)
    }
}

builtin! {
    /// `Set.toList` の本体（実装プラン 10-12「リスト・マップ・集合」）。
    name = "Set.toList",
    pure fn to_list(ctx, xs: Value<'e>) -> Value<'e> {
        list::from_values(&ctx, &map::set_to_vec(&ctx, xs)?, "Set.toList")
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[empty::DECL, from_list::DECL, to_list::DECL];

#[cfg(test)]
mod tests {
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
    use crate::runtime::Stop;
    use crate::runtime::heap::{Heap, HeapConfig};

    #[test]
    fn construction_and_sorted_list_conversion_keep_first_keys() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let call = CallCtx::new(ctx, None, None, None);
            let empty = empty(call.pure_ctx()).unwrap();
            assert!(matches!(empty, Value::EmptySet));

            assert!(matches!(
                direct!(ctx, to_list, empty).unwrap(),
                Value::EmptyList
            ));
            let d = |n, s| ctx.alloc_decimal(crate::base::Decimal::new(n, s).unwrap());
            let first = d(10, 1);
            let duplicate = d(100, 2);
            let xs = list::from_values(ctx, &[d(2, 0), first, duplicate], "test").unwrap();
            let s = direct!(ctx, from_list, xs).unwrap();
            let result = direct!(ctx, to_list, s).unwrap();
            let items = list::to_vec(ctx, result).unwrap();
            let observed: Vec<_> = items
                .into_iter()
                .map(|v| ctx.decimal(v).unwrap().to_text())
                .collect();
            assert_eq!(observed, vec!["1.0", "2"]);
            assert_eq!(list::len(ctx, xs).unwrap(), 3);
            let bad = list::from_values(ctx, &[Value::Float(1.0)], "test").unwrap();
            assert!(matches!(
                direct!(ctx, from_list, bad),
                Err(Stop::Internal(_))
            ));
            assert!(matches!(
                direct!(ctx, from_list, Value::EmptyList).unwrap(),
                Value::EmptySet
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

    // 関門: L02 の入口の配線、集合演算の向き、鍵の保存、引数の永続性を守る。
    // runtime::map のテストでは入口の誤りは分からない。L02 の指示に従って
    // BTreeSet を入口の結果と比べ、木の内部やテスト用の本番の口を使わない。
    use super::super::map::tests::{KEY_KINDS, KeyKind, key, number, random};
    use crate::base::Decimal;
    use crate::runtime::heap::NoGcCtx;
    use std::collections::BTreeSet;

    fn elements<'e>(ctx: &mut NoGcCtx<'e>, kind: KeyKind, s: Value<'e>) -> Vec<i64> {
        {
            let result = direct!(ctx, to_list, s).unwrap();
            list::to_vec(ctx, result)
        }
        .unwrap()
        .into_iter()
        .map(|v| number(ctx, kind, v))
        .collect()
    }
    fn build<'e>(ctx: &mut NoGcCtx<'e>, kind: KeyKind, model: &BTreeSet<i64>) -> Value<'e> {
        let mut s = Value::EmptySet;
        for &n in model.iter().rev() {
            s = direct!(ctx, add, s, key(ctx, kind, n)).unwrap();
        }
        s
    }

    #[test]
    fn remaining_functions_cover_empty_singleton_and_large_sets_for_each_key_kind() {
        for kind in KEY_KINDS {
            for count in [0, 1, 1024] {
                let mut heap = Heap::new(HeapConfig::default());
                heap.epoch(|ctx| {
                    let model: BTreeSet<_> = (0..count).collect();
                    let s = build(ctx, kind, &model);
                    let before: Vec<_> = model.iter().copied().collect();
                    assert_eq!(elements(ctx, kind, s), before);
                    assert_eq!(direct!(ctx, size, s).unwrap().as_int(), Some(count));
                    for n in 0..count {
                        assert!(matches!(
                            direct!(ctx, contains, s, key(ctx, kind, n)).unwrap(),
                            Value::Bool(true)
                        ));
                    }
                    let missing = key(ctx, kind, count);
                    assert!(matches!(
                        direct!(ctx, contains, s, missing).unwrap(),
                        Value::Bool(false)
                    ));
                    assert_eq!(
                        {
                            let result = direct!(ctx, remove, s, missing).unwrap();
                            elements(ctx, kind, result)
                        },
                        before
                    );
                    let added = direct!(ctx, add, s, missing).unwrap();
                    assert_eq!(elements(ctx, kind, added), (0..=count).collect::<Vec<_>>());
                    if count > 0 {
                        let k = key(ctx, kind, 0);
                        assert_eq!(
                            {
                                let result = direct!(ctx, add, s, k).unwrap();
                                elements(ctx, kind, result)
                            },
                            before
                        );
                        assert_eq!(
                            {
                                let result = direct!(ctx, remove, s, k).unwrap();
                                elements(ctx, kind, result)
                            },
                            before[1..]
                        );
                    }
                    // 空・同一・重複・分離した相手を、どの集合演算にも適用する。
                    for other_model in [
                        BTreeSet::new(),
                        model.clone(),
                        (0..count).map(|n| n * 2).collect(),
                        (count..count * 2).collect(),
                    ] {
                        let other = build(ctx, kind, &other_model);
                        let other_before: Vec<_> = other_model.iter().copied().collect();
                        for (result, expected) in [
                            (
                                direct!(ctx, union, s, other).unwrap(),
                                model.union(&other_model).copied().collect::<Vec<_>>(),
                            ),
                            (
                                direct!(ctx, intersection, s, other).unwrap(),
                                model.intersection(&other_model).copied().collect(),
                            ),
                            (
                                direct!(ctx, difference, s, other).unwrap(),
                                model.difference(&other_model).copied().collect(),
                            ),
                        ] {
                            assert_eq!(elements(ctx, kind, result), expected);
                            assert_eq!(
                                direct!(ctx, size, result).unwrap().as_int(),
                                Some(i64::try_from(expected.len()).unwrap())
                            );
                            assert_eq!(elements(ctx, kind, s), before);
                            assert_eq!(elements(ctx, kind, other), other_before);
                        }
                    }
                    assert_eq!(elements(ctx, kind, s), before);
                });
                assert!(heap.take_fault().is_none());
            }
        }
    }

    #[test]
    fn remaining_set_operations_match_model_and_preserve_both_inputs_across_collection() {
        for kind in KEY_KINDS {
            let mut heap = Heap::new(HeapConfig {
                stress: true,
                ..HeapConfig::default()
            });
            let mut roots = heap.epoch(|ctx| vec![ctx.new_slot(Value::EmptySet)]);
            let mut model = BTreeSet::new();
            let mut seed = 0x91af_5352_0984_2311;
            for step in 0..512 {
                let n = i64::try_from(random(&mut seed) % 257).unwrap();
                let op = random(&mut seed) % 9;
                heap.epoch(|ctx| {
                    let old = ctx.load(&roots[0]);
                    let before = elements(ctx, kind, old);
                    let k = key(ctx, kind, n);
                    let result = match op {
                        0..=2 => { model.insert(n); direct!(ctx, add, old, k).unwrap() }
                        3 => { model.remove(&n); direct!(ctx, remove, old, k).unwrap() }
                        4 => { assert!(matches!(direct!(ctx, contains, old, k).unwrap(), Value::Bool(b) if b == model.contains(&n))); old }
                        5 => { assert_eq!(direct!(ctx, size, old).unwrap().as_int(), Some(i64::try_from(model.len()).unwrap())); old }
                        _ => {
                            let mut other_model = BTreeSet::new();
                            for _ in 0..random(&mut seed) % 80 {
                                other_model.insert(i64::try_from(random(&mut seed) % 257).unwrap());
                            }
                            let other = build(ctx, kind, &other_model);
                            let result = match op {
                                6 => { model = model.union(&other_model).copied().collect(); direct!(ctx, union, old, other).unwrap() }
                                7 => { model = model.intersection(&other_model).copied().collect(); direct!(ctx, intersection, old, other).unwrap() }
                                _ => { model = model.difference(&other_model).copied().collect(); direct!(ctx, difference, old, other).unwrap() }
                            };
                            assert_eq!(elements(ctx, kind, other), other_model.iter().copied().collect::<Vec<_>>());
                            result
                        }
                    };
                    assert_eq!(elements(ctx, kind, result), model.iter().copied().collect::<Vec<_>>(), "{kind:?}, step {step}");
                    assert_eq!(direct!(ctx, size, result).unwrap().as_int(), Some(i64::try_from(model.len()).unwrap()));
                    assert_eq!(elements(ctx, kind, old), before);
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
    fn add_and_set_operations_keep_original_decimal_elements() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let first = ctx.alloc_decimal(Decimal::new(10, 1).unwrap());
            let duplicate = ctx.alloc_decimal(Decimal::new(100, 2).unwrap());
            let original = direct!(ctx, add, Value::EmptySet, first).unwrap();
            let other = direct!(ctx, add, Value::EmptySet, duplicate).unwrap();
            for s in [
                original,
                direct!(ctx, add, original, duplicate).unwrap(),
                direct!(ctx, union, original, other).unwrap(),
                direct!(ctx, intersection, original, other).unwrap(),
            ] {
                let items = {
                    let result = direct!(ctx, to_list, s).unwrap();
                    list::to_vec(ctx, result)
                }
                .unwrap();
                assert_eq!(items.len(), 1);
                assert_eq!(ctx.decimal(items[0]).unwrap().to_text(), "1.0");
                assert!(matches!(
                    direct!(ctx, contains, s, duplicate).unwrap(),
                    Value::Bool(true)
                ));
                assert!(matches!(
                    direct!(ctx, remove, s, duplicate).unwrap(),
                    Value::EmptySet
                ));
            }
            assert!(matches!(
                direct!(ctx, difference, original, other).unwrap(),
                Value::EmptySet
            ));
            for (s, expected) in [(original, "1.0"), (other, "1.00")] {
                let items = {
                    let result = direct!(ctx, to_list, s).unwrap();
                    list::to_vec(ctx, result)
                }
                .unwrap();
                assert_eq!(ctx.decimal(items[0]).unwrap().to_text(), expected);
            }
        });
        assert!(heap.take_fault().is_none());
    }
}

builtin! {
    /// `Set.contains` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.contains",
    pure fn contains(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        Ok(Value::Bool(map::set_contains(&ctx, arg0, arg1)?))
    }
}

builtin! {
    /// `Set.add` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.add",
    pure fn add(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        map::set_insert(&ctx, arg0, arg1, "Set.add")
    }
}

builtin! {
    /// `Set.remove` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.remove",
    pure fn remove(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        map::set_remove(&ctx, arg0, arg1)
    }
}

builtin! {
    /// `Set.size` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.size",
    pure fn size(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(i64::from(map::set_len(&ctx, arg0)?)))
    }
}

builtin! {
    /// `Set.union` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.union",
    pure fn union(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        map::set_union(&ctx, arg0, arg1, "Set.union")
    }
}

builtin! {
    /// `Set.intersection` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.intersection",
    pure fn intersection(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        map::set_intersection(&ctx, arg0, arg1)
    }
}

builtin! {
    /// `Set.difference` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Set.difference",
    pure fn difference(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        map::set_difference(&ctx, arg0, arg1)
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const MORE_DECLS: &[BuiltinDecl] = &[
    contains::DECL,
    add::DECL,
    remove::DECL,
    size::DECL,
    union::DECL,
    intersection::DECL,
    difference::DECL,
];
