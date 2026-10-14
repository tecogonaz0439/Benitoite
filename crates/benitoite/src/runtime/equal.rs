//! 構造の等しさ（設計書 01-06「等値の型」、02-08）。

use crate::runtime::Stop;
use crate::runtime::heap::{FieldsKind, ObjId, ObjKind, Value, ValueCtx};
use crate::runtime::list;
use crate::runtime::map;
use std::collections::HashSet;
use std::hash::{BuildHasher, Hasher};

// 比較の結果を変えない費用の調整。小さな比較では集合を作らない
// （設計書 02-08「組み込みの関数の呼び出し」）。
const SHARED_PAIR_THRESHOLD: u32 = 1_024;

// 利用者が直接選べない確保の通し番号だけを鍵にするため、固定のハッシュを使う。
// 回転・排他的論理和・64 ビットで溢れた分を捨てる乗算で混ぜる。
// hashbrown はバケットの番号に下位のビットを使うため、finish で上位のビットを下位へ混ぜる。
// ハッシュの衝突は HashSet が組そのものの等しさで区別する
// （設計書 02-08「組み込みの関数の呼び出し」）。
#[derive(Default)]
struct PairBuildHasher;

impl BuildHasher for PairBuildHasher {
    type Hasher = PairHasher;

    fn build_hasher(&self) -> Self::Hasher {
        PairHasher::default()
    }
}

#[derive(Default)]
struct PairHasher(u64);

impl Hasher for PairHasher {
    fn finish(&self) -> u64 {
        self.0 ^ (self.0 >> 32)
    }

    fn write(&mut self, bytes: &[u8]) {
        for byte in bytes {
            self.write_u64(u64::from(*byte));
        }
    }

    fn write_u64(&mut self, value: u64) {
        self.0 = (self.0.rotate_left(5) ^ value).wrapping_mul(0x517c_c1b7_2722_0a95);
    }
}

/// 一回の比較の回収しない区間で、種類と構成子の `tag` を確かめて子を積む対象の組を覚える。
/// 構造の `=` では欄の数と長さも等しいと確かめる。鍵の比較では成分を比べた後に数を比べる。
/// 等値の型と鍵の型の値は循環せず、深さ優先で辿るため、同じ組の 2 回目に出会う時点で
/// 1 回目の調べを終えている。そこで比較が続いていることから、成分と数はすべて等しかった
/// （鍵の比較では `Equal`）と分かる。記憶は辿った異なる組の数に比例し、共有のない値では
/// 値の大きさに比例する。上限を設けると、それを超える値で指数時間に戻りうる
/// （設計書 01-06「等値の型」、02-08「組み込みの関数の呼び出し」）。
#[derive(Default)]
pub(in crate::runtime) struct SharedPairs {
    steps: u32,
    seen: Option<HashSet<(ObjId, ObjId), PairBuildHasher>>,
}

impl SharedPairs {
    /// 積み重ねから取り出す仕事の種類によらず歩数を数える。
    pub(in crate::runtime) fn step(&mut self) {
        self.steps = self.steps.saturating_add(1);
        if self.steps == SHARED_PAIR_THRESHOLD.saturating_add(1) {
            self.seen = Some(HashSet::with_hasher(PairBuildHasher));
        }
    }

    /// 覚え始めた後の対象の組は、一度だけ展開する。即値を含む組は覚えない。
    pub(in crate::runtime) fn first_visit<'e>(
        &mut self,
        ctx: &ValueCtx<'e>,
        a: Value<'e>,
        b: Value<'e>,
    ) -> Result<bool, Stop> {
        let Some(seen) = self.seen.as_mut() else {
            return Ok(true);
        };
        if !matches!((a, b), (Value::Obj(_), Value::Obj(_))) {
            return Ok(true);
        }
        let object_id = |value| {
            ctx.object_id(value).ok_or_else(|| {
                Stop::Internal("missing object identity in structural comparison".into())
            })
        };
        Ok(seen.insert((object_id(a)?, object_id(b)?)))
    }
}

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
    let mut shared = SharedPairs::default();
    while let Some(work) = pending.pop() {
        shared.step();
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
        // 同じ対象の組でも 1 回目は成分を調べ、NaN と非等値の型を取りこぼさない。
        // 調べ終えた組は省き、共有した部分木を指数時間で展開しない
        // （設計書 01-06「等値の型」、02-08「組み込みの関数の呼び出し」）。
        let equal = match (a, b) {
            (Value::Int(a), Value::Int(b)) => a == b,
            (Value::Int8(a), Value::Int8(b)) => a == b,
            (Value::Int16(a), Value::Int16(b)) => a == b,
            (Value::Int32(a), Value::Int32(b)) => a == b,
            (Value::UInt16(a), Value::UInt16(b)) => a == b,
            (Value::UInt32(a), Value::UInt32(b)) => a == b,
            (Value::UInt64(a), Value::UInt64(b)) => a == b,
            (Value::Float32(a), Value::Float32(b)) => a == b,
            (Value::Float(a), Value::Float(b)) => a == b,
            (Value::Byte(a), Value::Byte(b)) => a == b,
            (Value::Bool(a), Value::Bool(b)) => a == b,
            (Value::Char(a), Value::Char(b)) => a == b,
            (Value::Tag(a), Value::Tag(b)) => a == b,
            (Value::Tag(_), object @ Value::Obj(_)) | (object @ Value::Obj(_), Value::Tag(_)) => {
                // 引数の有無が違う構成子は等しくない。他の種類の対象との比較は不具合である。
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
                    if !shared.first_visit(ctx, a, b)? {
                        continue;
                    }
                    pending.push(Work::Lists(list::cursor(ctx, a)?, list::cursor(ctx, b)?));
                    true
                }
            }
            _ if is_map(ctx, a) && is_map(ctx, b) => {
                if map::map_len(ctx, a)? != map::map_len(ctx, b)? {
                    false
                } else {
                    if !shared.first_visit(ctx, a, b)? {
                        continue;
                    }
                    pending.push(Work::Trees(map::Cursor::map(a), map::Cursor::map(b), true));
                    true
                }
            }
            _ if is_set(ctx, a) && is_set(ctx, b) => {
                if map::set_len(ctx, a)? != map::set_len(ctx, b)? {
                    false
                } else {
                    if !shared.first_visit(ctx, a, b)? {
                        continue;
                    }
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
                            if !shared.first_visit(ctx, a, b)? {
                                continue;
                            }
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
                    // リストの頭は先に API で扱う。内部ノードは言語の値ではない（設計書 02-08「値の表現」）。
                    ObjKind::Fields(
                        FieldsKind::Func
                        | FieldsKind::Dict
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
pub(in crate::runtime) mod test_support {
    //! 等値と鍵の比較に使う共有した値の準備（設計書 02-08「組み込みの関数の呼び出し」）。

    // テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
    #![allow(clippy::unwrap_used, clippy::panic)]
    use super::*;

    /// 同じ準備で等値と鍵の比較を確かめ、共有した部分木を展開する退行を捕まえる。
    pub(in crate::runtime) fn pair<'e>(
        ctx: &ValueCtx<'e>,
        shape: &str,
        a: Value<'e>,
        b: Value<'e>,
    ) -> Value<'e> {
        match shape {
            "constructor" => ctx.alloc_fields(FieldsKind::Ctor, 1, &[a, b]).unwrap(),
            "list" => list::from_values(ctx, &[a, b], "test").unwrap(),
            "map" => map::map_from_sorted(ctx, &[(Value::Int(0), a), (Value::Int(1), b)], "test")
                .unwrap(),
            "set" => {
                // タグで順序と区別を決め、同じ子を二つとも集合に残す。
                let a = ctx.alloc_fields(FieldsKind::Ctor, 0, &[a]).unwrap();
                let b = ctx.alloc_fields(FieldsKind::Ctor, 1, &[b]).unwrap();
                map::set_from_sorted(ctx, &[a, b], "test").unwrap()
            }
            _ => unreachable!(),
        }
    }

    /// 共有した子を重ねる。集合の葉は整数 1 か 2 とし、異なる二つの部分集合を共有する。
    pub(in crate::runtime) fn grow<'e>(
        ctx: &ValueCtx<'e>,
        shape: &str,
        depth: u32,
        mut leaf: Value<'e>,
    ) -> Value<'e> {
        if shape == "set" {
            let mut low = map::set_from_sorted(ctx, &[leaf], "test").unwrap();
            let mut high = map::set_from_sorted(ctx, &[leaf, Value::Int(3)], "test").unwrap();
            for _ in 0..depth {
                // 両方に異なる二つの部分集合を共有させる。空集合がある方は必ず小さい。
                // 構成子などを挟まないので、集合の組の記憶だけが指数時間の展開を防ぐ。
                let next_low =
                    map::set_from_sorted(ctx, &[Value::EmptySet, low, high], "test").unwrap();
                high = map::set_from_sorted(ctx, &[low, high], "test").unwrap();
                low = next_low;
            }
            return low;
        }
        for _ in 0..depth {
            leaf = pair(ctx, shape, leaf, leaf);
        }
        leaf
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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

    // 2 の冪の間隔で確保された対象の組でも、バケットに使う下位のビットが偏らないことを守る。
    // 既存の比較結果のテストではハッシュの偏りを検出できないため、出力の分布を直接調べる。
    #[test]
    fn pair_hash_spreads_low_bits_for_power_of_two_spaced_ids() {
        let mut buckets = HashSet::new();
        for index in 0_u64..10_000 {
            let serial = index << 14;
            let pair = (ObjId(serial), ObjId(serial + 1));
            buckets.insert(PairBuildHasher.hash_one(pair) & 0xfff);
        }
        assert!(
            buckets.len() > 3_000,
            "only {} of 4096 low-bit buckets used",
            buckets.len()
        );
    }

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
            // 引数の有無が違う構成子も、同じ型の値として比較できる。
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
    // この分岐への接続を検出できず、公開の口も加えない。
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
    // map のモデル比較では構造比較への接続を検出できず、公開の口も増やさない。
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

    // 作成時の関門: 共有を展開せずに比較を終え、NaN と非等値の成分を見落とさない契約を守る。
    // 既存の深い値は子を一つしか持たず、同じ部分木を二度展開する退行を捕まえない。
    // 同じ対象を無条件に等しいとする退行は、等しい接頭辞の後の NaN とセルで捕まえる。
    // 組を覚える仕組みが壊れると、共有を指数時間で展開するため、このテストは終わらなくなる。
    // 公開の比較関数で確かめ、差し込み口は増やさない（設計書 01-06「等値の型」、02-08「組み込みの関数の呼び出し」）。
    #[test]
    fn shared_structures_compare_without_expansion_and_preserve_leaf_checks() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for shape in ["constructor", "list", "map", "set"] {
                let pair = |a, b| test_support::pair(ctx, shape, a, b);
                let grow = |depth, leaf| test_support::grow(ctx, shape, depth, leaf);
                let a63 = grow(63, Value::Int(1));
                let a = pair(a63, a63);
                let b = if shape == "set" {
                    pair(grow(63, Value::Int(1)), grow(63, Value::Int(1)))
                } else {
                    grow(64, Value::Int(1))
                };
                let changed = pair(a63, grow(63, Value::Int(2)));
                if shape == "set" {
                    // 集合の要素は鍵の型なので、NaN とセルの行は作らない。
                    // 要素は別の鍵の比較で辿るため、等値の比較の集合の記憶は反復した値で守る。
                    let repeated = list::from_values(ctx, &vec![a; 16_384], "test").unwrap();
                    let prefixed = ctx
                        .alloc_fields(
                            FieldsKind::Ctor,
                            2,
                            &[
                                test_support::grow(ctx, "constructor", 64, Value::Int(1)),
                                repeated,
                            ],
                        )
                        .unwrap();
                    for (case, x, y, expected) in [
                        ("equal, separate objects", a, b, true),
                        ("equal, same object", a, a, true),
                        ("late difference", a, changed, false),
                        ("repeated set after equal prefix", prefixed, prefixed, true),
                    ] {
                        assert_eq!(
                            values_equal(ctx, x, y).unwrap(),
                            expected,
                            "{shape}: {case}"
                        );
                    }
                    continue;
                }
                let wrap = |v| ctx.alloc_fields(FieldsKind::Ctor, 2, &[v]).unwrap();
                let n = pair(a, wrap(Value::Float(f64::NAN)));
                let n2 = pair(b, wrap(Value::Float(f64::NAN)));
                let bad = pair(a, wrap(ctx.alloc_cell(Value::Unit)));
                // 葉がすべて NaN の場合は最初の葉で終わり、組を覚え始める前の扱いを守る。
                let early_nan = grow(64, Value::Float(f64::NAN));
                let early_nan2 = grow(64, Value::Float(f64::NAN));
                for (case, x, y, expected) in [
                    ("early NaN, same object", early_nan, early_nan, Some(false)),
                    (
                        "early NaN, separate objects",
                        early_nan,
                        early_nan2,
                        Some(false),
                    ),
                    ("equal, separate objects", a, b, Some(true)),
                    ("equal, same object", a, a, Some(true)),
                    ("late difference", a, changed, Some(false)),
                    ("late NaN, same object", n, n, Some(false)),
                    ("late NaN, separate objects", n, n2, Some(false)),
                    (
                        "signed zero",
                        grow(64, Value::Float(0.0)),
                        grow(64, Value::Float(-0.0)),
                        Some(true),
                    ),
                    ("late non-equality value", bad, bad, None),
                ] {
                    let result = values_equal(ctx, x, y);
                    match expected {
                        Some(expected) => assert_eq!(result.unwrap(), expected, "{shape}: {case}"),
                        None => {
                            assert!(matches!(result, Err(Stop::Internal(_))), "{shape}: {case}")
                        }
                    }
                }
            }
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
        // Miri は同じ比較の経路を小さな値で調べる。通常構成では指定の深さを使う。
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
