//! 公開のヒープ API と独立のグラフ模型を比較する（設計書 07-03「ヒープとランタイムの確かめ方」、実装プラン R11）。
// 関門: 固定のグラフでは届かない、確保・上書き・根の増減・候補の復活の組み合わせを守る。
// 期待する到達先は操作から記録し、Trace と内部層の辿りを使わない。公開の口の追加は不要である。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use crate::runtime::heap::{
    FieldsKind, Heap, HeapConfig, HostData, NoGcCtx, ObjId, RootIdx, RootStack, Slot, Trace,
    Tracer, Value,
};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ModelValue {
    Int(i64),
    Obj(ObjId),
}
#[derive(Debug)]
enum Node {
    Str(String),
    Fields(Vec<ModelValue>),
    Cell(ModelValue),
    Host(ModelValue),
}
impl Node {
    fn edges(&self) -> Vec<ModelValue> {
        match self {
            Self::Str(_) => vec![],
            Self::Fields(values) => values.clone(),
            Self::Cell(value) | Self::Host(value) => vec![*value],
        }
    }
}
#[derive(Debug)]
struct Host(Slot);
impl Trace for Host {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slot(&self.0);
    }
}
impl HostData for Host {}

fn model<'e>(ctx: &NoGcCtx<'e>, value: Value<'e>) -> ModelValue {
    // 寿命を含む Value を保存せず、番号と即値だけを模型に残す。
    if let Value::Int(n) = value {
        ModelValue::Int(n)
    } else {
        ModelValue::Obj(ctx.object_id(value).unwrap())
    }
}
struct Rng(u64);
impl Rng {
    fn pick(&mut self, n: usize) -> usize {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        usize::try_from(self.0 % u64::try_from(n).unwrap()).unwrap()
    }
}
fn root<'e>(ctx: &NoGcCtx<'e>, roots: &RootStack, index: usize) -> Value<'e> {
    roots
        .get(ctx, RootIdx(u32::try_from(index).unwrap()))
        .unwrap()
}
fn reach(graph: &BTreeMap<ObjId, Node>, roots: &[ModelValue]) -> BTreeSet<ObjId> {
    let mut pending = roots.to_vec();
    let mut seen = BTreeSet::new();
    while let Some(value) = pending.pop() {
        if let ModelValue::Obj(id) = value
            && seen.insert(id)
        {
            pending.extend(graph[&id].edges());
        }
    }
    seen
}
fn check_contents(
    ctx: &NoGcCtx<'_>,
    roots: &RootStack,
    expected_roots: &[ModelValue],
    graph: &BTreeMap<ObjId, Node>,
) {
    let mut pending: Vec<_> = expected_roots
        .iter()
        .enumerate()
        .map(|(i, expected)| (root(ctx, roots, i), *expected))
        .collect();
    let mut seen = BTreeSet::new();
    while let Some((value, expected)) = pending.pop() {
        assert_eq!(model(ctx, value), expected);
        let ModelValue::Obj(id) = expected else {
            continue;
        };
        if !seen.insert(id) {
            continue;
        }
        match &graph[&id] {
            Node::Str(text) => assert_eq!(ctx.str(value), Some(text.as_str())),
            Node::Fields(fields) => {
                assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, 7)));
                assert_eq!(
                    ctx.fields_len(value),
                    Some(u32::try_from(fields.len()).unwrap())
                );
                for (i, expected) in fields.iter().enumerate() {
                    pending.push((
                        ctx.field(value, u32::try_from(i).unwrap()).unwrap(),
                        *expected,
                    ));
                }
            }
            Node::Cell(expected) => pending.push((ctx.cell_get(value).unwrap(), *expected)),
            Node::Host(expected) => {
                pending.push((ctx.load(&ctx.host::<Host>(value).unwrap().0), *expected))
            }
        }
    }
}

#[test]
fn random_reachability_matches_model_and_preserves_contents() {
    // check-heap.sh は同じテストを 20000 列で実行する。Miri は二列・各 24 操作に縮める。
    let cases = if cfg!(miri) {
        2
    } else {
        std::env::var("BENITOITE_HEAP_RANDOM_CASES")
            .ok()
            .map(|n| n.parse::<usize>().unwrap())
            .unwrap_or(24)
    };
    let steps = if cfg!(miri) { 24 } else { 320 };
    for case in 0..cases {
        let seed = 0x9e37_79b9_7f4a_7c15_u64.wrapping_add(u64::try_from(case).unwrap());
        let mut rng = Rng(seed);
        let mut heap = Heap::new(HeapConfig {
            stress: true,
            ..HeapConfig::default()
        });
        let mut roots = RootStack::new();
        let mut expected_roots = Vec::new();
        let mut graph = BTreeMap::new();
        for step in 0..steps {
            // 失敗時には、種と操作の番号を添えた panic にして再現できるようにする。
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                heap.epoch(|ctx| {
                    let op = if roots.is_empty() { 0 } else { rng.pick(10) };
                    let index = rng.pick(expected_roots.len().max(1));
                    let source = if roots.is_empty() {
                        Value::Int(13)
                    } else {
                        root(ctx, &roots, index)
                    };
                    match op {
                        0 => {
                            let text = format!("{case}:{step}:{}", "あ".repeat(rng.pick(80)));
                            let value = ctx.alloc_str(&text, "R11").unwrap();
                            graph.insert(ctx.object_id(value).unwrap(), Node::Str(text));
                            roots.push(ctx, value);
                            expected_roots.push(model(ctx, value));
                        }
                        1 => {
                            let args = vec![source; rng.pick(4) + 1];
                            let value = ctx.alloc_fields(FieldsKind::Ctor, 7, &args).unwrap();
                            graph.insert(
                                ctx.object_id(value).unwrap(),
                                Node::Fields(args.iter().map(|v| model(ctx, *v)).collect()),
                            );
                            roots.push(ctx, value);
                            expected_roots.push(model(ctx, value));
                        }
                        2 | 3 => {
                            // Host だけの循環は作らない。可変の循環は必ずセルを通す（ADR 0239）。
                            let source = if op == 3
                                && !matches!(
                                    ctx.object_id(source).and_then(|id| graph.get(&id)),
                                    Some(Node::Str(_) | Node::Cell(_))
                                ) {
                                Value::Int(13)
                            } else {
                                source
                            };
                            let value = if op == 2 {
                                ctx.alloc_cell(source)
                            } else {
                                ctx.alloc_host(Host(ctx.new_slot(source)))
                            };
                            let node = if op == 2 {
                                Node::Cell(model(ctx, source))
                            } else {
                                Node::Host(model(ctx, source))
                            };
                            graph.insert(ctx.object_id(value).unwrap(), node);
                            roots.push(ctx, value);
                            expected_roots.push(model(ctx, value));
                        }
                        4 | 5 => {
                            let wanted: Vec<_> = expected_roots
                                .iter()
                                .enumerate()
                                .filter_map(|(i, v)| {
                                    if let ModelValue::Obj(id) = v
                                        && matches!(
                                            (op, &graph[id]),
                                            (4, Node::Cell(_)) | (5, Node::Host(_))
                                        )
                                    {
                                        Some(i)
                                    } else {
                                        None
                                    }
                                })
                                .collect();
                            if !wanted.is_empty() {
                                let target = root(ctx, &roots, wanted[rng.pick(wanted.len())]);
                                let source = if op == 5
                                    && !matches!(
                                        ctx.object_id(source).and_then(|id| graph.get(&id)),
                                        Some(Node::Str(_) | Node::Cell(_))
                                    ) {
                                    Value::Int(13)
                                } else {
                                    source
                                };
                                if op == 4 {
                                    ctx.cell_set(target, source).unwrap();
                                    graph.insert(
                                        ctx.object_id(target).unwrap(),
                                        Node::Cell(model(ctx, source)),
                                    );
                                } else {
                                    ctx.host_mut::<Host, _>(target, |host, ops| {
                                        ops.store(&mut host.0, source)
                                    })
                                    .unwrap();
                                    graph.insert(
                                        ctx.object_id(target).unwrap(),
                                        Node::Host(model(ctx, source)),
                                    );
                                }
                            }
                        }
                        6 => {
                            roots.push(ctx, source);
                            expected_roots.push(model(ctx, source));
                        }
                        7 => {
                            roots.truncate(ctx, u32::try_from(index).unwrap());
                            expected_roots.truncate(index);
                        }
                        8 => {
                            let value = ctx.alloc_str("resaved", "R11").unwrap();
                            let len = roots.len();
                            // 同じ区間の 0 → 1 → 0、0 の後の再保存、一度も保存しない一時の値。
                            roots.push(ctx, value);
                            roots.truncate(ctx, len);
                            roots.push(ctx, value);
                            roots.truncate(ctx, len);
                            let _ = ctx.alloc_str("never saved", "R11").unwrap();
                            if rng.pick(2) == 0 {
                                roots.push(ctx, value);
                                graph.insert(
                                    ctx.object_id(value).unwrap(),
                                    Node::Str("resaved".into()),
                                );
                                expected_roots.push(model(ctx, value));
                            }
                        }
                        9 => {
                            // 再利用した対象の内部参照と、結果を保存しない候補の解放を両方比べる。
                            let value = ctx
                                .alloc_fields(FieldsKind::Ctor, 7, &[Value::Int(1)])
                                .unwrap();
                            let result = ctx.reuse_ctor(value, 7, &[source]).unwrap();
                            if rng.pick(2) == 0 {
                                let value = result.unwrap_or_else(|| {
                                    ctx.alloc_fields(FieldsKind::Ctor, 7, &[source]).unwrap()
                                });
                                graph.insert(
                                    ctx.object_id(value).unwrap(),
                                    Node::Fields(vec![model(ctx, source)]),
                                );
                                roots.push(ctx, value);
                                expected_roots.push(model(ctx, value));
                            }
                        }
                        _ => unreachable!(),
                    }
                });
                if step % 8 == 7 || step + 1 == steps {
                    let expected = reach(&graph, &expected_roots);
                    let before = heap.stats().collections;
                    heap.collect(&roots);
                    assert_eq!(heap.stats().collections, before + 1);
                    assert_eq!(
                        heap.object_ids().into_iter().collect::<BTreeSet<_>>(),
                        expected
                    );
                    assert_eq!(heap.verify(&roots), Ok(()));
                    assert!(heap.take_fault().is_none());
                    heap.epoch(|ctx| check_contents(ctx, &roots, &expected_roots, &graph));
                    graph.retain(|id, _| expected.contains(id));
                }
            }));
            assert!(result.is_ok(), "seed={seed:#x}, operation={step}");
        }
        heap.epoch(|ctx| roots.truncate(ctx, 0));
        heap.collect(&roots);
        assert!(heap.object_ids().is_empty());
        assert!(heap.take_fault().is_none());
    }
}

// 関門: H4 の根の列挙漏れを検出する。R02 の世代テストは強制的な解放だけを扱う。
#[cfg(feature = "heap-verify")]
#[test]
fn omitted_root_is_detected_without_reading_freed_memory() {
    use crate::runtime::heap::HeapFaultKind;
    let mut heap = Heap::new(HeapConfig {
        stress: true,
        ..HeapConfig::default()
    });
    let empty = RootStack::new();
    let saved = heap.epoch(|ctx| ctx.new_slot(ctx.alloc_str("omitted", "R11").unwrap()));
    heap.collect(&empty);
    assert!(heap.object_ids().is_empty());
    heap.epoch(|ctx| assert!(matches!(ctx.load(&saved), Value::Unit)));
    assert_eq!(
        heap.take_fault().unwrap().kind,
        HeapFaultKind::StaleReference
    );
    assert_eq!(
        heap.verify(&saved).unwrap_err().kind,
        HeapFaultKind::ReachableFreed
    );
}
