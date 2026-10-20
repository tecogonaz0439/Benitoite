//! 実 Host の容量・snapshot・予約失敗と根を確かめる（設計書 02-09「構築器の物理バッファ」）。

// テストの失敗は panic で表す（AGENTS.md「実装の規約」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::runtime::heap::{Heap, HeapConfig};

const KINDS: [BuilderClass; 3] = [
    BuilderClass::String,
    BuilderClass::Bytes,
    BuilderClass::List,
];

fn capacity<'e>(ctx: &NoGcCtx<'e>, kind: BuilderClass, receiver: Value<'e>) -> usize {
    match kind {
        BuilderClass::String => ctx
            .host::<StringBuilderData>(receiver)
            .unwrap()
            .buffer
            .capacity(),
        BuilderClass::Bytes => ctx
            .host::<BytesBuilderData>(receiver)
            .unwrap()
            .buffer
            .capacity(),
        BuilderClass::List => ctx
            .host::<ListBuilderData>(receiver)
            .unwrap()
            .buffer
            .capacity(),
    }
}
fn single<'e>(ctx: &NoGcCtx<'e>, kind: BuilderClass) -> Value<'e> {
    match kind {
        BuilderClass::String | BuilderClass::List => ctx.alloc_str("猫", "test").unwrap(),
        BuilderClass::Bytes => Value::Byte(0x80),
    }
}
fn all<'e>(ctx: &NoGcCtx<'e>, kind: BuilderClass) -> Value<'e> {
    match kind {
        BuilderClass::String => {
            let first = ctx.alloc_str("é", "test").unwrap();
            let second = ctx.alloc_str("終", "test").unwrap();
            list::from_values(ctx, &[first, second], "test").unwrap()
        }
        BuilderClass::Bytes => ctx.alloc_bytes(&[0, 255], "test").unwrap(),
        BuilderClass::List => {
            let value = ctx.alloc_str("終", "test").unwrap();
            list::from_values(ctx, &[Value::Int(7), value], "test").unwrap()
        }
    }
}
fn observe<'e>(ctx: &NoGcCtx<'e>, kind: BuilderClass, value: Value<'e>) -> String {
    match kind {
        BuilderClass::String => ctx.str(value).unwrap().to_owned(),
        BuilderClass::Bytes => format!("{:?}", ctx.bytes(value).unwrap()),
        BuilderClass::List => list::to_vec(ctx, value)
            .unwrap()
            .into_iter()
            .map(|v| {
                if let Value::Int(n) = v {
                    n.to_string()
                } else {
                    ctx.str(v).unwrap().to_owned()
                }
            })
            .collect::<Vec<_>>()
            .join(","),
    }
}

#[test]
fn snapshots_capacity_and_list_children_survive_collection() {
    for (kind, expected, initial_len) in [
        (BuilderClass::String, "猫é終", 8),
        (BuilderClass::Bytes, "[128, 0, 255]", 3),
        (BuilderClass::List, "猫,7,終", 3),
    ] {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = Vec::new();
        let before = heap.stats().allocated_bytes;
        let host_bytes = heap.epoch(|ctx| {
            let receiver = new(ctx, kind).unwrap();
            roots.push(ctx.new_slot(receiver));
            assert_eq!(capacity(ctx, kind, receiver), 0);
            let empty_input = if kind == BuilderClass::Bytes {
                ctx.alloc_bytes(&[], "test").unwrap()
            } else {
                Value::EmptyList
            };
            let mut refuse = RefuseReservation { calls: Vec::new() };
            apply_with(
                ctx,
                kind,
                BuilderOp::AppendAll,
                receiver,
                &[empty_input],
                &mut refuse,
            )
            .unwrap();
            assert!(refuse.calls.is_empty());
            assert_eq!(capacity(ctx, kind, receiver), 0);
            let empty = apply(ctx, kind, BuilderOp::Copy, receiver, &[]).unwrap();
            assert_eq!(
                observe(ctx, kind, empty),
                if kind == BuilderClass::Bytes {
                    "[]"
                } else {
                    ""
                }
            );
            assert_eq!(
                apply(ctx, kind, BuilderOp::Length, receiver, &[])
                    .unwrap()
                    .as_int(),
                Some(0)
            );
            let one = single(ctx, kind);
            assert!(matches!(
                apply(ctx, kind, BuilderOp::Append, receiver, &[one]).unwrap(),
                Value::Unit
            ));
            let many = all(ctx, kind);
            apply(ctx, kind, BuilderOp::AppendAll, receiver, &[many]).unwrap();
            assert_eq!(
                apply(ctx, kind, BuilderOp::Length, receiver, &[])
                    .unwrap()
                    .as_int(),
                Some(initial_len)
            );
            let snapshot = apply(ctx, kind, BuilderOp::Copy, receiver, &[]).unwrap();
            roots.push(ctx.new_slot(snapshot));
            assert_eq!(observe(ctx, kind, snapshot), expected);
            let initial_capacity = capacity(ctx, kind, receiver);
            let owned = initial_capacity * limit(kind).2;
            assert!(initial_capacity >= if kind == BuilderClass::List { 8 } else { 64 });
            // 初回の容量を超える追記で、copy の物理表現と共有する要素の内容を変えない。
            let additions = if kind == BuilderClass::List { 32 } else { 64 };
            let extra = if kind == BuilderClass::List {
                ctx.alloc_str("追", "test").unwrap()
            } else {
                one
            };
            for _ in 0..additions {
                apply(ctx, kind, BuilderOp::Append, receiver, &[extra]).unwrap();
            }
            assert!(capacity(ctx, kind, receiver) > initial_capacity);
            assert_eq!(observe(ctx, kind, snapshot), expected);
            let actual_owned = match kind {
                BuilderClass::String => ctx
                    .host::<StringBuilderData>(receiver)
                    .unwrap()
                    .heap_bytes(),
                BuilderClass::Bytes => ctx.host::<BytesBuilderData>(receiver).unwrap().heap_bytes(),
                BuilderClass::List => ctx.host::<ListBuilderData>(receiver).unwrap().heap_bytes(),
            };
            assert_eq!(actual_owned, capacity(ctx, kind, receiver) * limit(kind).2);
            assert!(actual_owned > owned);
            actual_owned as u64
        });
        assert!(heap.stats().allocated_bytes >= before + host_bytes);
        heap.collect(&roots);
        heap.verify(&roots).unwrap();
        assert!(heap.stats().live_bytes >= host_bytes);
        heap.epoch(|ctx| {
            let snapshot = ctx.load(&roots[1]);
            assert_eq!(observe(ctx, kind, snapshot), expected);
            let receiver = ctx.load(&roots[0]);
            let next = apply(ctx, kind, BuilderOp::Copy, receiver, &[]).unwrap();
            let expected_len = initial_len
                + match kind {
                    BuilderClass::String => 192,
                    BuilderClass::Bytes => 64,
                    BuilderClass::List => 32,
                };
            assert_eq!(
                apply(ctx, kind, BuilderOp::Length, receiver, &[])
                    .unwrap()
                    .as_int(),
                Some(expected_len)
            );
            let expected_full = match kind {
                BuilderClass::String => format!("猫é終{}", "猫".repeat(64)),
                BuilderClass::Bytes => {
                    let mut bytes = vec![128_u8, 0, 255];
                    bytes.extend([128_u8; 64]);
                    format!("{bytes:?}")
                }
                BuilderClass::List => format!("猫,7,終{}", ",追".repeat(32)),
            };
            assert_eq!(observe(ctx, kind, next), expected_full);
            ctx.discard(std::mem::take(&mut roots));
        });
        heap.collect(&roots);
        assert_eq!(heap.stats().live_bytes, 0);
        assert!(heap.take_fault().is_none());
    }
}

struct RefuseReservation {
    calls: Vec<u64>,
}
impl Reservation for RefuseReservation {
    fn string(&mut self, _: &mut String, request: Request) -> Result<(), Stop> {
        self.calls.push(request.bytes);
        Err(request.failed())
    }
    fn vector<T>(&mut self, _: &mut Vec<T>, request: Request) -> Result<(), Stop> {
        self.calls.push(request.bytes);
        Err(request.failed())
    }
}

#[test]
fn failed_reservation_preserves_length_contents_and_capacity() {
    for kind in KINDS {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let receiver = new(ctx, kind).unwrap();
            let one = single(ctx, kind);
            // バッファを容量まで満たしてから、append と appendAll の双方の予約を失敗させる。
            apply(ctx, kind, BuilderOp::Append, receiver, &[one]).unwrap();
            if kind == BuilderClass::String {
                let ascii = ctx.alloc_str("x", "test").unwrap();
                while ctx
                    .host::<StringBuilderData>(receiver)
                    .unwrap()
                    .buffer
                    .len()
                    < capacity(ctx, kind, receiver)
                {
                    apply(ctx, kind, BuilderOp::Append, receiver, &[ascii]).unwrap();
                }
            } else {
                for _ in 1..capacity(ctx, kind, receiver) {
                    apply(ctx, kind, BuilderOp::Append, receiver, &[one]).unwrap();
                }
            }
            let snapshot = apply(ctx, kind, BuilderOp::Copy, receiver, &[]).unwrap();
            let expected = observe(ctx, kind, snapshot);
            let old_len = apply(ctx, kind, BuilderOp::Length, receiver, &[])
                .unwrap()
                .as_int();
            let old_capacity = capacity(ctx, kind, receiver);
            for op in [BuilderOp::Append, BuilderOp::AppendAll, BuilderOp::Copy] {
                let many = all(ctx, kind);
                let args = match op {
                    BuilderOp::Append => vec![one],
                    BuilderOp::AppendAll => vec![many],
                    BuilderOp::Copy | BuilderOp::Length => vec![],
                };
                let mut refuse = RefuseReservation { calls: Vec::new() };
                let error = apply_with(ctx, kind, op, receiver, &args, &mut refuse).unwrap_err();
                let expected_bytes = if op == BuilderOp::Copy {
                    old_capacity
                } else {
                    old_capacity * 2
                } * limit(kind).2;
                assert_eq!(
                    error,
                    Stop::Resource(ResourceError::AllocationFailed {
                        function: name(kind, op),
                        requested_bytes: expected_bytes as u64,
                    })
                );
                assert_eq!(refuse.calls, [expected_bytes as u64]);
                assert_eq!(capacity(ctx, kind, receiver), old_capacity);
                assert_eq!(
                    apply(ctx, kind, BuilderOp::Length, receiver, &[])
                        .unwrap()
                        .as_int(),
                    old_len
                );
                let after = apply(ctx, kind, BuilderOp::Copy, receiver, &[]).unwrap();
                assert_eq!(observe(ctx, kind, after), expected);
            }
        });
        assert!(heap.take_fault().is_none());
    }
}

#[test]
fn logical_limits_fail_before_reservation_without_partial_append() {
    // 上限そのものの契約を、巨大な出力の確保をせずに共有入力で検査する。
    for kind in [BuilderClass::String, BuilderClass::List] {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let receiver = new(ctx, kind).unwrap();
            let one = if kind == BuilderClass::String {
                ctx.alloc_str("x", "test").unwrap()
            } else {
                Value::Int(1)
            };
            apply(ctx, kind, BuilderOp::Append, receiver, &[one]).unwrap();
            let (item, doubles) = if kind == BuilderClass::String {
                (ctx.alloc_str(&"x".repeat(1 << 20), "test").unwrap(), 10)
            } else {
                (Value::Int(2), 24)
            };
            let mut input = list::from_values(ctx, &[item], "test").unwrap();
            for _ in 0..doubles {
                input = list::concat(ctx, input, input, "test").unwrap();
            }
            let mut refuse = RefuseReservation { calls: Vec::new() };
            let error = apply_with(
                ctx,
                kind,
                BuilderOp::AppendAll,
                receiver,
                &[input],
                &mut refuse,
            )
            .unwrap_err();
            let (limit, unit, _) = limit(kind);
            assert_eq!(
                error,
                Stop::Resource(ResourceError::ValueTooLarge {
                    function: name(kind, BuilderOp::AppendAll),
                    size: limit + 1,
                    unit,
                    limit,
                })
            );
            assert!(refuse.calls.is_empty());
            let snapshot = apply(ctx, kind, BuilderOp::Copy, receiver, &[]).unwrap();
            assert_eq!(
                observe(ctx, kind, snapshot),
                if kind == BuilderClass::String {
                    "x"
                } else {
                    "1"
                }
            );
        });
    }
}

#[test]
fn capacity_arithmetic_rejects_overflow_and_clamps_growth() {
    for kind in KINDS {
        let function = name(kind, BuilderOp::AppendAll);
        assert!(matches!(
            required(kind, function, 1, u64::MAX),
            Err(Stop::Resource(ResourceError::ValueTooLarge { .. }))
        ));
        assert!(matches!(
            request(kind, function, usize::MAX),
            Err(Stop::Resource(ResourceError::ValueTooLarge { .. }))
        ));
        assert!(matches!(
            growth(kind, function, usize::MAX / 2 + 1, usize::MAX),
            Err(Stop::Resource(ResourceError::ValueTooLarge { .. }))
        ));
        let upper = limit(kind).0 as usize;
        assert_eq!(required(kind, function, upper, 0).unwrap(), upper);
        assert_eq!(
            required(kind, function, upper, 1).unwrap_err(),
            too_large(kind, function, limit(kind).0 + 1)
        );
        assert_eq!(
            growth(kind, function, upper - 1, upper)
                .unwrap()
                .unwrap()
                .capacity,
            upper
        );
    }
}

#[test]
fn owned_capacity_is_charged_once_and_released_with_host() {
    for kind in KINDS {
        let mut heap = Heap::new(HeapConfig::default());
        let mut roots = Vec::new();
        heap.epoch(|ctx| {
            let receiver = new(ctx, kind).unwrap();
            roots.push(ctx.new_slot(receiver));
            let value = single(ctx, kind);
            roots.push(ctx.new_slot(value));
        });
        let empty_bytes = heap.stats().allocated_bytes;
        let owned = heap.epoch(|ctx| {
            let receiver = ctx.load(&roots[0]);
            let value = ctx.load(&roots[1]);
            apply(ctx, kind, BuilderOp::Append, receiver, &[value]).unwrap();
            (capacity(ctx, kind, receiver) * limit(kind).2) as u64
        });
        assert_eq!(heap.stats().allocated_bytes - empty_bytes, owned);
        heap.collect(&roots);
        assert_eq!(heap.stats().live_bytes, empty_bytes + owned);
        heap.epoch(|ctx| ctx.discard(std::mem::take(&mut roots)));
        heap.collect(&roots);
        assert_eq!(heap.stats().live_bytes, 0);
        heap.verify(&roots).unwrap();
        assert!(heap.take_fault().is_none());
    }
}
