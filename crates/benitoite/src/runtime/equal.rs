//! 構造の等しさ（設計書 01-06「等値の型」、02-08）。

use crate::runtime::Stop;
use crate::runtime::heap::{FieldsKind, ObjKind, Value, ValueCtx};
use crate::runtime::list;
use crate::runtime::map;

/// 二つの値が構造として等しいか。`Float` の成分は IEEE 754 で比べる。値の並びを持つ対象は、種類と `tag` と
/// 各要素で比べる。リストは要素の並びで比べる（表現の形では比べない）。関数の値、セル、`Host`・`Opaque` の対象、
/// `IOError`・`NetworkError` に出会ったら `Stop::Internal` を返す（型検査を通ったプログラムでは起きない）。
pub fn values_equal<'e>(ctx: &ValueCtx<'e>, a: Value<'e>, b: Value<'e>) -> Result<bool, Stop> {
    enum Work<'e> {
        Values(Value<'e>, Value<'e>),
        Lists(list::Cursor<'e>, list::Cursor<'e>),
        Trees(map::Cursor<'e>, map::Cursor<'e>, bool),
    }
    let mut pending = vec![Work::Values(a, b)];
    while let Some(work) = pending.pop() {
        let (a, b) = match work {
            Work::Values(a, b) => (a, b),
            Work::Lists(mut a, mut b) => {
                match (a.next(ctx)?, b.next(ctx)?) {
                    (None, None) => {}
                    (Some(x), Some(y)) => {
                        pending.push(Work::Lists(a, b));
                        pending.push(Work::Values(x, y));
                    }
                    _ => return Ok(false),
                }
                continue;
            }
            Work::Trees(mut a, mut b, is_map) => {
                match (a.next(ctx)?, b.next(ctx)?) {
                    (None, None) => {}
                    (Some((ak, av)), Some((bk, bv))) => {
                        if map::compare_keys(ctx, ak, bk)? != std::cmp::Ordering::Equal {
                            return Ok(false);
                        }
                        pending.push(Work::Trees(a, b, is_map));
                        if is_map {
                            pending.push(Work::Values(av, bv));
                        }
                    }
                    _ => return Ok(false),
                }
                continue;
            }
        };
        // 同じ対象への参照でも成分を調べる。[NaN] と非等値の型を取りこぼさない（設計書 01-06「等値の型」）。
        let equal = match (a, b) {
            (Value::Int(a), Value::Int(b)) => a == b,
            (Value::Float(a), Value::Float(b)) => a == b,
            (Value::Byte(a), Value::Byte(b)) => a == b,
            (Value::Bool(a), Value::Bool(b)) => a == b,
            (Value::Char(a), Value::Char(b)) => a == b,
            (Value::Tag(a), Value::Tag(b)) => a == b,
            (Value::Tag(_), object @ Value::Obj(_)) | (object @ Value::Obj(_), Value::Tag(_)) => {
                // 引数の有無が違う構成子は等しくない。他の種類の対象との比較は不具合である
                // （R06「構造の等しさ」）。
                if ctx.kind(object) != Some(ObjKind::Fields(FieldsKind::Ctor)) {
                    return Err(invalid_comparison());
                }
                false
            }
            (Value::Unit, Value::Unit)
            | (Value::EmptyMap, Value::EmptyMap)
            | (Value::EmptySet, Value::EmptySet) => true,
            _ if list::is_list(ctx, a) && list::is_list(ctx, b) => {
                if list::len(ctx, a)? != list::len(ctx, b)? {
                    false
                } else {
                    pending.push(Work::Lists(list::cursor(ctx, a)?, list::cursor(ctx, b)?));
                    true
                }
            }
            _ if is_map(ctx, a) && is_map(ctx, b) => {
                if map::map_len(ctx, a)? != map::map_len(ctx, b)? {
                    false
                } else {
                    pending.push(Work::Trees(map::Cursor::map(a), map::Cursor::map(b), true));
                    true
                }
            }
            _ if is_set(ctx, a) && is_set(ctx, b) => {
                if map::set_len(ctx, a)? != map::set_len(ctx, b)? {
                    false
                } else {
                    pending.push(Work::Trees(map::Cursor::set(a), map::Cursor::set(b), false));
                    true
                }
            }
            (Value::Obj(_), Value::Obj(_)) => {
                let a_kind = ctx.kind(a).ok_or_else(invalid_comparison)?;
                let b_kind = ctx.kind(b).ok_or_else(invalid_comparison)?;
                if a_kind != b_kind {
                    return Err(invalid_comparison());
                }
                match a_kind {
                    ObjKind::Str => {
                        ctx.str(a).ok_or_else(invalid_comparison)?
                            == ctx.str(b).ok_or_else(invalid_comparison)?
                    }
                    ObjKind::Bytes => {
                        ctx.bytes(a).ok_or_else(invalid_comparison)?
                            == ctx.bytes(b).ok_or_else(invalid_comparison)?
                    }
                    ObjKind::Fields(FieldsKind::Ctor) => {
                        let a_header = ctx.fields_header(a).ok_or_else(invalid_comparison)?;
                        let b_header = ctx.fields_header(b).ok_or_else(invalid_comparison)?;
                        let a_len = ctx.fields_len(a).ok_or_else(invalid_comparison)?;
                        let b_len = ctx.fields_len(b).ok_or_else(invalid_comparison)?;
                        if a_header != b_header || a_len != b_len {
                            false
                        } else {
                            for i in (0..a_len).rev() {
                                pending.push(Work::Values(
                                    ctx.field(a, i).ok_or_else(invalid_comparison)?,
                                    ctx.field(b, i).ok_or_else(invalid_comparison)?,
                                ));
                            }
                            true
                        }
                    }
                    ObjKind::Decimal => {
                        ctx.decimal(a)
                            .ok_or_else(invalid_comparison)?
                            .cmp_num(ctx.decimal(b).ok_or_else(invalid_comparison)?)
                            == std::cmp::Ordering::Equal
                    }
                    // リストの頭は先に API で扱う。内部ノードと旧セルは言語の値ではない。
                    ObjKind::Fields(
                        FieldsKind::Func
                        | FieldsKind::Dict
                        | FieldsKind::ListCell
                        | FieldsKind::ListNode
                        | FieldsKind::MapNode
                        | FieldsKind::SetNode
                        | FieldsKind::IoError
                        | FieldsKind::NetworkError,
                    )
                    | ObjKind::Cell
                    | ObjKind::Host
                    | ObjKind::Opaque => return Err(invalid_comparison()),
                }
            }
            _ => return Err(invalid_comparison()),
        };
        if !equal {
            return Ok(false);
        }
    }
    Ok(true)
}

fn is_map<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptyMap)
        || ctx.kind(value) == Some(ObjKind::Fields(FieldsKind::MapNode))
}
fn is_set<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptySet)
        || ctx.kind(value) == Some(ObjKind::Fields(FieldsKind::SetNode))
}

fn invalid_comparison() -> Stop {
    Stop::Internal("incompatible or non-equality values in structural comparison".into())
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
    use crate::runtime::heap::{
        CtorTag, Heap, HeapConfig, HostData, OpaqueData, ResourceId, Trace, Tracer,
    };

    // 作成時の関門: EQV の公開の境界で、IEEE 754・文字の列・構造比較・非等値の拒否を守る。
    // 同じ対象の省略比較、タグや要素の無視、非等値を false にする退行は既存のテストでは検出できない。
    // 独立に作った木とリストを使い、大きな値を辿る際の再帰も捕まえる。公開の口は加えない。
    #[test]
    fn equality_compares_scalars_strings_bytes_and_constructor_trees() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (a, b, expected) in [
                (Value::Int(-7), Value::Int(-7), true),
                (Value::Int(1), Value::Int(2), false),
                (Value::Float(0.0), Value::Float(-0.0), true),
                (Value::Float(f64::NAN), Value::Float(f64::NAN), false),
                (Value::Float(1.0), Value::Float(2.0), false),
                (
                    Value::Float(f64::INFINITY),
                    Value::Float(f64::INFINITY),
                    true,
                ),
                (Value::Byte(255), Value::Byte(255), true),
                (Value::Byte(0), Value::Byte(1), false),
                (Value::Bool(true), Value::Bool(true), true),
                (Value::Bool(false), Value::Bool(true), false),
                (Value::Char('あ'), Value::Char('あ'), true),
                (Value::Char('あ'), Value::Char('い'), false),
                (Value::Unit, Value::Unit, true),
                (Value::Tag(CtorTag(1)), Value::Tag(CtorTag(1)), true),
                (Value::Tag(CtorTag(0)), Value::Tag(CtorTag(1)), false),
                (Value::EmptyList, Value::EmptyList, true),
                (Value::EmptyMap, Value::EmptyMap, true),
                (Value::EmptySet, Value::EmptySet, true),
            ] {
                assert_eq!(values_equal(ctx, a, b).unwrap(), expected, "{a:?}, {b:?}");
            }
            for (a, b, expected) in [
                ("あい", "あい", true),
                ("あ", "い", false),
                ("é", "e\u{301}", false),
                ("", "", true),
            ] {
                let a = ctx.alloc_str(a, "test").unwrap();
                let b = ctx.alloc_str(b, "test").unwrap();
                assert_eq!(values_equal(ctx, a, b).unwrap(), expected);
            }
            for (a, b, expected) in [([0, 255], [0, 255], true), ([0, 255], [0, 254], false)] {
                assert_eq!(
                    values_equal(
                        ctx,
                        ctx.alloc_bytes(&a, "test").unwrap(),
                        ctx.alloc_bytes(&b, "test").unwrap()
                    )
                    .unwrap(),
                    expected
                );
            }
            let make_tree = |tag, extra| {
                let child = ctx.alloc_fields(FieldsKind::Ctor, 7, extra).unwrap();
                ctx.alloc_fields(FieldsKind::Ctor, tag, &[Value::Int(3), child])
                    .unwrap()
            };
            let tree = make_tree(1, &[Value::Int(4), Value::Bool(true)]);
            for (other, expected) in [
                (make_tree(1, &[Value::Int(4), Value::Bool(true)]), true),
                (make_tree(2, &[Value::Int(4), Value::Bool(true)]), false),
                (make_tree(1, &[Value::Int(4)]), false),
                (make_tree(1, &[Value::Int(5), Value::Bool(true)]), false),
                (make_tree(1, &[Value::Int(4), Value::Bool(false)]), false),
            ] {
                assert_eq!(values_equal(ctx, tree, other).unwrap(), expected);
            }
            // 引数の有無が違う構成子も、同じ型の値として比較できる（R06「構造の等しさ」）。
            // 従来の木の比較には即値と対象の組がなく、Stop::Internal を返す退行を検出できなかった。
            let none = Value::Tag(CtorTag(0));
            let some = ctx
                .alloc_fields(FieldsKind::Ctor, 1, &[Value::Int(1)])
                .unwrap();
            let some_none = ctx.alloc_fields(FieldsKind::Ctor, 1, &[none]).unwrap();
            let some_some = ctx.alloc_fields(FieldsKind::Ctor, 1, &[some]).unwrap();
            for (a, b) in [
                (none, some),
                (some, none),
                (some_none, some_some),
                (some_some, some_none),
            ] {
                assert!(!values_equal(ctx, a, b).unwrap(), "{a:?}, {b:?}");
            }
            let empty = ctx.alloc_fields(FieldsKind::Ctor, 5, &[]).unwrap();
            assert!(
                values_equal(
                    ctx,
                    empty,
                    ctx.alloc_fields(FieldsKind::Ctor, 5, &[]).unwrap()
                )
                .unwrap()
            );
            let nan = list::from_values(ctx, &[Value::Float(f64::NAN)], "list").unwrap();
            let other_nan = list::from_values(ctx, &[Value::Float(f64::NAN)], "list").unwrap();
            assert!(!values_equal(ctx, nan, other_nan).unwrap());
            assert!(!values_equal(ctx, nan, nan).unwrap());
            let xs =
                list::from_values(ctx, &[Value::Float(0.0), Value::Float(3.0)], "list").unwrap();
            let ys = list::prepend(
                ctx,
                list::from_values(ctx, &[Value::Float(3.0)], "list").unwrap(),
                Value::Float(-0.0),
                "prepend",
            )
            .unwrap();
            assert!(values_equal(ctx, xs, ys).unwrap());
            assert!(!values_equal(ctx, xs, Value::EmptyList).unwrap());
            assert!(!values_equal(ctx, Value::EmptyList, xs).unwrap());
            assert!(
                !values_equal(
                    ctx,
                    xs,
                    list::from_values(ctx, &[Value::Float(1.0), Value::Float(3.0)], "list")
                        .unwrap()
                )
                .unwrap()
            );
        });
        assert!(heap.take_fault().is_none());
    }

    // 関門: EQV の境界で厳密な木と連結・分割で作った木を要素列で比べる契約。
    // 小さい既存の比較は内部ノードと走査の継続に届かない。リストの公開 API だけで準備する。
    #[test]
    fn list_equality_compares_sequences_across_concatenation_and_slicing() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let count = if cfg!(miri) { 35 } else { 1057 };
            let items: Vec<_> = (0..count).map(Value::Int).collect();
            let strict = list::from_values(ctx, &items, "list").unwrap();
            let mut joined = Value::EmptyList;
            for chunk in items.chunks(17) {
                joined = list::concat(
                    ctx,
                    joined,
                    list::from_values(ctx, chunk, "list").unwrap(),
                    "concat",
                )
                .unwrap();
            }
            assert!(values_equal(ctx, strict, joined).unwrap());
            for start in [0, 1, 31, 32, 33] {
                let a = list::slice(ctx, strict, start, u32::MAX).unwrap();
                let b = list::slice(ctx, joined, start, u32::MAX).unwrap();
                assert!(values_equal(ctx, a, b).unwrap());
            }
            let changed = list::concat(
                ctx,
                list::slice(ctx, joined, 0, u32::try_from(count - 1).unwrap()).unwrap(),
                list::from_values(ctx, &[Value::Int(-1)], "list").unwrap(),
                "concat",
            )
            .unwrap();
            assert!(!values_equal(ctx, strict, changed).unwrap());
            // 要素自体がリストでも、Rust の呼び出しを入れ子にしない。
            let mut a = strict;
            let mut b = joined;
            for _ in 0..if cfg!(miri) { 3 } else { 10_000 } {
                a = list::from_values(ctx, &[a], "list").unwrap();
                b = list::from_values(ctx, &[b], "list").unwrap();
            }
            assert!(values_equal(ctx, a, b).unwrap());
        });
        assert!(heap.take_fault().is_none());
    }

    // 関門: EQV が構造の中でも Decimal の桁数を無視する契約。スカラーの比較命令では
    // この分岐への接続を検出できず、公開の口も加えない（R35「構造の等しさ」）。
    #[test]
    fn decimal_components_compare_numbers_in_options_and_records() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let d = |mantissa, scale| {
                ctx.alloc_decimal(crate::base::Decimal::new(mantissa, scale).unwrap())
            };
            for (a, b, expected) in [
                (d(10, 1), d(100, 2), true),
                (d(-10, 1), d(-100, 2), true),
                (d(0, 0), d(0, 28), true),
                (d(10, 1), d(101, 2), false),
            ] {
                let some = |v| {
                    ctx.alloc_fields(
                        FieldsKind::Ctor,
                        crate::builtins::table::tags::OPTION_SOME,
                        &[v],
                    )
                    .unwrap()
                };
                assert_eq!(values_equal(ctx, some(a), some(b)).unwrap(), expected);
                let record = |v| {
                    ctx.alloc_fields(FieldsKind::Ctor, 0, &[v, Value::Int(7)])
                        .unwrap()
                };
                assert_eq!(values_equal(ctx, record(a), record(b)).unwrap(), expected);
            }
        });
        assert!(heap.take_fault().is_none());
    }

    // 関門: EQV が木の形によらず鍵と値を比べ、値の非等値を拒む契約を守る。
    // map のモデル比較では構造比較への接続を検出できず、公開の口も増やさない（R37）。
    #[test]
    fn map_and_set_equality_ignores_tree_shape_and_compares_values() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let build = |order: &[i64], changed| {
                let mut m = Value::EmptyMap;
                let mut s = Value::EmptySet;
                for &n in order {
                    let value = Value::Int(if changed && n == 3 { 77 } else { n });
                    m = map::map_insert(ctx, m, Value::Int(n), value, "test").unwrap();
                    s = map::set_insert(ctx, s, Value::Int(n), "test").unwrap();
                }
                (m, s)
            };
            let (a, sa) = build(&[1, 2, 3, 4, 5, 6, 7, 8, 9], false);
            let (b, sb) = build(&[9, 7, 5, 3, 1, 2, 4, 6, 8], false);
            assert!(values_equal(ctx, a, b).unwrap());
            assert!(values_equal(ctx, sa, sb).unwrap());
            assert!(!values_equal(ctx, a, build(&[9, 7, 5, 3, 1, 2, 4, 6, 8], true).0).unwrap());
            assert!(
                !values_equal(ctx, sa, map::set_remove(ctx, sb, Value::Int(3)).unwrap()).unwrap()
            );
            for (full, empty) in [(a, Value::EmptyMap), (sa, Value::EmptySet)] {
                assert!(!values_equal(ctx, full, empty).unwrap());
                assert!(!values_equal(ctx, empty, full).unwrap());
            }
            let d = |n, s| ctx.alloc_decimal(crate::base::Decimal::new(n, s).unwrap());
            let a = map::map_insert(ctx, Value::EmptyMap, d(10, 1), sa, "test").unwrap();
            let b = map::map_insert(ctx, Value::EmptyMap, d(100, 2), sb, "test").unwrap();
            assert!(values_equal(ctx, a, b).unwrap());
            for (x, y) in [
                (Value::Float(f64::NAN), Value::Float(f64::NAN)),
                (Value::Float(0.0), Value::Float(-0.0)),
            ] {
                let a = map::map_insert(ctx, Value::EmptyMap, Value::Int(0), x, "test").unwrap();
                let b = map::map_insert(ctx, Value::EmptyMap, Value::Int(0), y, "test").unwrap();
                assert_eq!(
                    values_equal(ctx, a, b).unwrap(),
                    !x.as_float().unwrap().is_nan()
                );
            }
            let bad = map::map_insert(
                ctx,
                Value::EmptyMap,
                Value::Int(0),
                ctx.alloc_cell(Value::Unit),
                "test",
            )
            .unwrap();
            assert!(matches!(
                values_equal(ctx, bad, bad),
                Err(Stop::Internal(_))
            ));
            // コレクションを値に含む深い構造でも再帰しない。
            let mut a = Value::Int(1);
            let mut b = Value::Int(1);
            for _ in 0..if cfg!(miri) { 8 } else { 20_000 } {
                a = map::map_from_sorted(ctx, &[(Value::Int(0), a)], "test").unwrap();
                b = map::map_from_sorted(ctx, &[(Value::Int(0), b)], "test").unwrap();
            }
            assert!(values_equal(ctx, a, b).unwrap());
        });
        assert!(heap.take_fault().is_none());
    }

    #[derive(Debug)]
    struct Opaque;
    impl OpaqueData for Opaque {}
    #[derive(Debug)]
    struct Host;
    impl Trace for Host {
        fn trace(&self, _t: &mut Tracer<'_>) {}
    }
    impl HostData for Host {}

    #[test]
    fn non_equality_values_and_incompatible_kinds_are_internal_errors() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let mut invalid = vec![
                ctx.alloc_cell(Value::Unit),
                ctx.alloc_host(Host),
                ctx.alloc_opaque(Opaque),
                Value::Resource(ResourceId(0)),
            ];
            for kind in [
                FieldsKind::Func,
                FieldsKind::Dict,
                FieldsKind::IoError,
                FieldsKind::NetworkError,
                FieldsKind::MapNode,
                FieldsKind::SetNode,
                FieldsKind::ListNode,
            ] {
                invalid.push(ctx.alloc_fields(kind, 0, &[]).unwrap());
            }
            for value in invalid {
                assert!(matches!(
                    values_equal(ctx, value, value),
                    Err(Stop::Internal(_))
                ));
                for (a, b) in [
                    (Value::Tag(CtorTag(0)), value),
                    (value, Value::Tag(CtorTag(0))),
                ] {
                    assert!(matches!(values_equal(ctx, a, b), Err(Stop::Internal(_))));
                }
                let a = ctx.alloc_fields(FieldsKind::Ctor, 0, &[value]).unwrap();
                let b = ctx.alloc_fields(FieldsKind::Ctor, 0, &[value]).unwrap();
                assert!(matches!(values_equal(ctx, a, b), Err(Stop::Internal(_))));
                let a = list::from_values(ctx, &[value], "list").unwrap();
                let b = list::from_values(ctx, &[value], "list").unwrap();
                assert!(matches!(values_equal(ctx, a, b), Err(Stop::Internal(_))));
            }
            let string = ctx.alloc_str("x", "test").unwrap();
            let bytes = ctx.alloc_bytes(b"x", "test").unwrap();
            let ctor = ctx.alloc_fields(FieldsKind::Ctor, 0, &[]).unwrap();
            for (a, b) in [
                (Value::Int(1), Value::Bool(true)),
                (Value::Unit, string),
                (Value::Tag(CtorTag(0)), string),
                (Value::Tag(CtorTag(0)), bytes),
                (string, bytes),
                (ctor, string),
            ] {
                assert!(matches!(values_equal(ctx, a, b), Err(Stop::Internal(_))));
                assert!(matches!(values_equal(ctx, b, a), Err(Stop::Internal(_))));
            }
        });
        assert!(heap.take_fault().is_none());
    }

    #[test]
    #[ignore = "long: 大きさで確かめるテスト。全体の検査（scripts/check.sh --full）で走らせる"]
    fn million_element_lists_and_million_deep_trees_do_not_recurse() {
        // Miri は同じ比較の経路を小さな値で調べる（R06「等しさ」）。通常構成では指定の深さを使う。
        let count = if cfg!(miri) { 24 } else { 1_000_000 };
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let values = vec![Value::Int(17); count];
            let a = list::from_values(ctx, &values, "list").unwrap();
            let b = list::from_values(ctx, &values, "list").unwrap();
            assert!(!ctx.same_object(a, b));
            assert!(values_equal(ctx, a, b).unwrap());
            let mut a = Value::Int(17);
            let mut b = Value::Int(17);
            for _ in 0..count {
                a = ctx.alloc_fields(FieldsKind::Ctor, 3, &[a]).unwrap();
                b = ctx.alloc_fields(FieldsKind::Ctor, 3, &[b]).unwrap();
            }
            assert!(!ctx.same_object(a, b));
            assert!(values_equal(ctx, a, b).unwrap());
        });
        assert!(heap.take_fault().is_none());
    }
}
