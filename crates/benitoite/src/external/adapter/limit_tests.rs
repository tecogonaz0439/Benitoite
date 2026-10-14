//! 内部の補助接続で、資源の上限とコピーの燃料消費を確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::component::GENERATION_LIMIT;
use super::runtime::{Binding, call, prepare};
use crate::external::stats::CallUsage;
use crate::external::{
    ComponentSource, ExternalFailure, ExternalRoute, ExternalRuntime, ExternalSpec, Limits,
    WitPlan as P,
};
use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx, Value};
use crate::runtime::{ResourceError, Stop};
use std::sync::Arc;

pub(super) fn fixture(
    guest: &str,
    params: Vec<P>,
    result: Option<P>,
) -> (Arc<ExternalSpec>, Arc<Binding>) {
    let spec = Arc::new(ExternalSpec {
        id: 0,
        function: "limited-call".into(),
        component: Arc::new(ComponentSource {
            display: "limits.wasm".into(),
            bytes: wat::parse_str(guest).unwrap().into(),
        }),
        instance: None,
        export: "run".into(),
        route: ExternalRoute::of(&params, result.as_ref()),
        params,
        result,
        adapter: None,
    });
    let bindings = prepare(&[Arc::clone(&spec)], &mut 100_000, GENERATION_LIMIT).unwrap();
    (spec, Arc::clone(&bindings[&0]))
}

pub(super) fn invoke<'e>(
    fixture: &(Arc<ExternalSpec>, Arc<Binding>),
    runtime: &mut ExternalRuntime,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
    limits: Limits,
    usage: &mut Option<CallUsage>,
) -> Result<Value<'e>, ExternalFailure> {
    call(runtime, &fixture.1, &fixture.0, ctx, args, limits, usage)
}

fn reference_guest(wit: &str, input: bool) -> String {
    let params = if input { "(param i32 i32)" } else { "" };
    let set_result = if input {
        "i32.const 16 local.get 0 i32.store i32.const 20 local.get 1 i32.store"
    } else {
        "i32.const 16 i32.const 1024 i32.store i32.const 20 i32.const 4096 i32.store"
    };
    let declaration = if input { "(param \"x\" $t)" } else { "" };
    let ty = if wit == "string" {
        "string"
    } else {
        "(list u8)"
    };
    let memory = super::fixed_tests::MEMORY.replace("i32.const 2048", "i32.const 8192");
    format!(
        r#"(component
        (core module $m {memory}
            (data (i32.const 1024) "{}")
            (func (export "run") {params} (result i32)
                {set_result}
                i32.const 16 i32.load i32.const 90 i32.store8 i32.const 16))
        (core instance $i (instantiate $m)) (type $t {ty})
        (func (export "run") {declaration} (result $t)
            (canon lift (core func $i "run") (memory (core memory $i "memory"))
                (realloc (core func $i "realloc")))))"#,
        "a".repeat(4096)
    )
}

#[test]
fn byte_and_string_result_copying_has_bounded_fuel_overhead() {
    // 関門: 生成したコアの入口で 32/4096 バイトを比べ、要素ごとのコピーと結果の
    // UTF-8 再検査の退行を捕まえる。正準 ABI 自身の list の走査の燃料とは分ける。
    // 手書きゲストの変更した先頭と独立したバイト列も確認し、写し漏れを見逃さない。
    use super::fixed_tests::{input, measured_core_call};
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    let support = wasmtime::Module::from_binary(
        &engine,
        &super::emit::memory_module(1, None).unwrap().finish(),
    )
    .unwrap();
    for plan in [P::Bytes, P::String] {
        let adapter = wasmtime::Module::from_binary(
            &engine,
            &super::emit::fixed_module(&[], std::slice::from_ref(&plan))
                .unwrap()
                .finish(),
        )
        .unwrap();
        let mut fuel = vec![];
        for len in [32, 4096] {
            let guest = format!(
                r#"(module (import "support" "memory" (memory 1))
                (func (export "run") (param $result i32)
                    i32.const 32768 i32.const 97 i32.const {len} memory.fill
                    i32.const 32768 i32.const 90 i32.store8
                    local.get $result i32.const 32768 i32.store
                    local.get $result i32.const {len} i32.store offset=4))"#
            );
            let guest = wasmtime::Module::new(&engine, wat::parse_str(guest).unwrap()).unwrap();
            let (output, used) =
                measured_core_call(&engine, &support, &guest, &adapter, &input(&[], 0, 8192))
                    .unwrap();
            let mut payload = vec![];
            payload.extend_from_slice(&40_u32.to_le_bytes());
            payload.extend_from_slice(&(len as u32).to_le_bytes());
            payload.push(b'Z');
            payload.extend(std::iter::repeat_n(b'a', len - 1));
            assert_eq!(output, input(&payload, 1, 8192));
            fuel.push(used);
        }
        // bulk 命令自身もバイト数に応じて燃料を使うため、その費用は残す。
        assert!(
            fuel[1] <= fuel[0] + 4 * (4096 - 32) + 1000,
            "{plan:?}: {fuel:?}"
        );
    }
}

#[test]
fn adapter_memory_and_instances_count_toward_store_totals() {
    // 関門: 内部の本番接続で補助も合計へ加える。ゲストだけの既存試験では追加の
    // メモリとインスタンスを数え忘れる退行を検出できない。統計なしでも止める。
    let guest = r#"(component (core module $m (memory 1) (func (export "run")))
        (core instance $i (instantiate $m))
        (func (export "run") (canon lift (core func $i "run"))))"#;
    let fixture = fixture(guest, vec![], None);
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for memory in [131_071, 131_072] {
            let mut usage = Some(CallUsage::default());
            let result = invoke(
                &fixture,
                &mut runtime,
                ctx,
                &[],
                Limits {
                    memory,
                    ..Limits::default()
                },
                &mut usage,
            );
            if memory == 131_072 {
                assert!(matches!(result, Ok(Value::Unit)), "{result:?}");
                assert_eq!(usage.unwrap().memory, 131_072);
            } else {
                assert!(
                    matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalAdapterMemory {
                                store_limit: Some(131_071),
                                ..
                            }
                        )))
                    ),
                    "{result:?}"
                );
            }
        }
        assert!(matches!(
            invoke(
                &fixture,
                &mut runtime,
                ctx,
                &[],
                Limits {
                    memory: 131_071,
                    ..Limits::default()
                },
                &mut None
            ),
            Err(ExternalFailure::Stop(Stop::Resource(
                ResourceError::ExternalAdapterMemory {
                    store_limit: Some(131_071),
                    ..
                }
            )))
        ));
    });
    // 初期ページだけでなく、結果を写すために補助が増やすページも合計へ含める。
    let growing = self::fixture(
        &reference_guest("bytes", true),
        vec![P::Bytes],
        Some(P::Bytes),
    );
    heap.epoch(|ctx| {
        let argument = ctx
            .alloc_bytes_with(
                crate::runtime::heap::CheckedLen::bytes(24_576, "test").unwrap(),
                |bytes| bytes.fill(b'a'),
            )
            .unwrap();
        for memory in [196_607, 196_608] {
            let mut usage = Some(CallUsage::default());
            let result = invoke(
                &growing,
                &mut runtime,
                ctx,
                &[argument],
                Limits {
                    memory,
                    ..Limits::default()
                },
                &mut usage,
            );
            if memory == 196_608 {
                let value = result.unwrap();
                assert_eq!(ctx.bytes(value).unwrap().len(), 24_576);
                assert_eq!(ctx.bytes(value).unwrap()[0], b'Z');
                assert_eq!(usage.unwrap().memory, 196_608);
            } else {
                assert!(
                    matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalAdapterMemory {
                                store_limit: Some(196_607),
                                ..
                            }
                        )))
                    ),
                    "{result:?}"
                );
            }
        }
    });
    for count in [13, 14] {
        let instances = (0..count)
            .map(|i| format!("(core instance $i{i} (instantiate $m))"))
            .collect::<String>();
        let guest = format!(
            r#"(component (core module $m (func (export "run"))) {instances}
            (func (export "run") (canon lift (core func $i0 "run"))))"#
        );
        let fixture = self::fixture(&guest, vec![], None);
        if count == 13 {
            heap.epoch(|ctx| {
                let result = invoke(
                    &fixture,
                    &mut runtime,
                    ctx,
                    &[],
                    Limits::default(),
                    &mut None,
                );
                assert!(matches!(result, Ok(Value::Unit)), "{result:?}");
            });
        } else {
            // 補助の追加で上限に当たる組み合わせは、呼び出し前に動的へ送る。
            assert_eq!(
                fixture.1.fallback_reason(),
                Some(crate::external::text::FALLBACK_INSTANCES)
            );
            let mut spec = (*fixture.0).clone();
            spec.route = ExternalRoute::Dynamic;
            spec.adapter = Some(Arc::clone(&fixture.1));
            let table = crate::bytecode::program::ExternalTable {
                components: vec![Arc::clone(&spec.component)],
                functions: vec![crate::bytecode::program::ExternalRef {
                    component: 0,
                    arity: 0,
                    spec: Arc::new(spec),
                }],
            };
            heap.epoch(|ctx| {
                let result = crate::external::call(&mut runtime, &table, 0, ctx, &[]);
                assert!(matches!(result, Ok(Value::Unit)), "{result:?}");
            });
        }
    }
}

#[test]
fn generated_list_walk_obeys_shared_fuel_and_epoch() {
    // 関門: ゲストはループしない。補助の値の走査で燃料と epoch を無視する退行を
    // 内部の呼び出しで捕まえる。既存の spin は生成した走査を通らない。
    let guest = reference_guest("bytes", true);
    let plan = P::List(Box::new(P::U8));
    let fixture = fixture(&guest, vec![plan.clone()], Some(plan));
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let argument = crate::runtime::list::from_iter_exact(
            ctx,
            128,
            (0..128).map(|_| Value::Byte(b'a')),
            "test",
        )
        .unwrap();
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let result = invoke(
            &fixture,
            &mut runtime,
            ctx,
            &[argument],
            Limits {
                fuel: 1000,
                ..Limits::default()
            },
            &mut None,
        );
        assert!(
            matches!(
                result,
                Err(ExternalFailure::Stop(Stop::Resource(
                    ResourceError::ExternalFuel { limit: 1000, .. }
                )))
            ),
            "{result:?}"
        );
        let flag = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let mut runtime = ExternalRuntime::new(Some(flag)).unwrap();
        let mut usage = None;
        let mut interrupted = false;
        // 各呼び出しは短いが、見張りが epoch を進めるまで同じ純粋な呼び出しを行う。
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(1);
        while std::time::Instant::now() < deadline {
            let result = invoke(
                &fixture,
                &mut runtime,
                ctx,
                &[argument],
                Limits::default(),
                &mut usage,
            );
            if matches!(result, Err(ExternalFailure::Interrupted)) {
                interrupted = true;
                break;
            }
            result.unwrap();
        }
        assert!(interrupted);
    });
}

#[test]
fn transfer_and_construction_boundaries_apply_without_statistics() {
    // 関門: 内部の本番接続で行き帰りの転送と構築の予算を確認し、統計を指定しない
    // 呼び出しが予算検査を省く退行を捕まえる。生成器だけの既存試験では接続に届かない。
    for plan in [P::Bytes, P::String, P::List(Box::new(P::U8))] {
        let wit = if matches!(plan, P::String) {
            "string"
        } else {
            "bytes"
        };
        let incoming = fixture(
            &reference_guest(wit, true),
            vec![plan.clone()],
            Some(plan.clone()),
        );
        let outgoing = fixture(
            &reference_guest(wit, false)
                .replace("i32.const 4096 i32.store", "i32.const 3 i32.store"),
            vec![],
            Some(plan.clone()),
        );
        let mut runtime = ExternalRuntime::new(None).unwrap();
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let argument = if matches!(plan, P::String) {
                ctx.alloc_str("aaa", "test").unwrap()
            } else if matches!(plan, P::Bytes) {
                ctx.alloc_bytes_with(crate::runtime::heap::CheckedLen::bytes(3, "test").unwrap(), |bytes| bytes.fill(b'a')).unwrap()
            } else {
                crate::runtime::list::from_iter_exact(ctx, 3, std::iter::repeat_n(Value::Byte(b'a'), 3), "test").unwrap()
            };
            let boundary = if matches!(plan, P::List(_)) { 64 } else { 43 };
            for (fixture, args) in [(&incoming, vec![argument]), (&outgoing, vec![])] {
                for stats in [false, true] {
                    for limit in [boundary - 1, boundary, boundary + 1] {
                        let mut usage = stats.then(CallUsage::default);
                        let result = invoke(fixture, &mut runtime, ctx, &args, Limits { transfer: limit, ..Limits::default() }, &mut usage);
                        if limit < boundary {
                            assert!(matches!(result, Err(ExternalFailure::Stop(Stop::Resource(ResourceError::ExternalTransfer { limit: l, .. }))) if l == limit), "{result:?}");
                        } else {
                            let value = result.unwrap();
                            if matches!(plan, P::String) {
                                assert_eq!(ctx.str(value).unwrap(), "Zaa");
                            } else if matches!(plan, P::Bytes) {
                                assert_eq!(ctx.bytes(value).unwrap(), b"Zaa");
                            } else {
                                assert_eq!(crate::runtime::list::to_vec(ctx, value).unwrap().iter().map(|v| v.as_byte().unwrap()).collect::<Vec<_>>(), b"Zaa");
                            }
                            if let Some(usage) = usage {
                                assert_eq!(usage.results_transfer, Some(43));
                            }
                        }
                    }
                }
            }
        });
    }
}

#[test]
fn memory32_array_product_stops_before_missing_payload_or_guest_call() {
    // 関門: 既存の List の個数上限内でも、欄の幅との積が memory32 に収まらなければ
    // 参照先を読む前に止める。巨大な入力を作らず、ヘッダと長さだけで確かめる。
    use super::fixed_tests::{call, compile, input};
    let tuple = vec!["u64"; 64].join(" ");
    let guest = format!(
        r#"(component (core module $m (memory (export "memory") 1)
        (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 128)
        (func (export "run") (param i32 i32) unreachable))
        (core instance $i (instantiate $m)) (type $t (tuple {tuple})) (type $l (list $t))
        (func (export "run") (param "x" $l) (canon lift (core func $i "run")
            (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let plan = P::List(Box::new(P::TupleFields(vec![P::U64; 64])));
    let (engine, component) = compile(&guest, &[plan], &[]);
    let mut payload = 40_u32.to_le_bytes().to_vec();
    payload.extend_from_slice(&(1_u32 << 23).to_le_bytes());
    let error = call(&engine, &component, &input(&payload, 1, u64::MAX)).unwrap_err();
    let report = super::runtime::reported_failure(&error).unwrap();
    assert_eq!(
        (report.number, report.requested, report.limit),
        (1, 1_u64 << 32, u64::from(u32::MAX))
    );
}

#[test]
fn nested_construction_is_checked_before_each_direction_allocates() {
    // 関門: 転送量 62 バイトの入れ子でも言語の出現の構築量 144 バイトを数える。
    // 単純な値の境界試験では、子に入るたび予算をリセットする退行を捕まえない。
    let guest = reference_guest("bytes", true)
        .replace(
            "(type $t (list u8))",
            "(type $b (list u8)) (type $t (list $b))",
        )
        .replace(
            "i32.const 16 i32.load i32.const 90",
            "i32.const 16 i32.load i32.load i32.const 90",
        );
    let plan = P::List(Box::new(P::List(Box::new(P::U8))));
    let fixture = fixture(&guest, vec![plan.clone()], Some(plan));
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let child = crate::runtime::list::from_iter_exact(
            ctx,
            3,
            std::iter::repeat_n(Value::Byte(b'a'), 3),
            "test",
        )
        .unwrap();
        let argument =
            crate::runtime::list::from_iter_exact(ctx, 2, [child, child].into_iter(), "test")
                .unwrap();
        for stats in [false, true] {
            for limit in [143, 144, 145] {
                let mut usage = stats.then(CallUsage::default);
                let result = invoke(
                    &fixture,
                    &mut runtime,
                    ctx,
                    &[argument],
                    Limits {
                        transfer: limit,
                        ..Limits::default()
                    },
                    &mut usage,
                );
                if limit == 143 {
                    assert!(
                        matches!(
                            result,
                            Err(ExternalFailure::Stop(Stop::Resource(
                                ResourceError::ExternalTransfer { limit: 143, .. }
                            )))
                        ),
                        "{result:?}"
                    );
                } else {
                    let children = crate::runtime::list::to_vec(ctx, result.unwrap()).unwrap();
                    assert_eq!(children.len(), 2);
                    assert_eq!(
                        crate::runtime::list::to_vec(ctx, children[0])
                            .unwrap()
                            .iter()
                            .map(|v| v.as_byte().unwrap())
                            .collect::<Vec<_>>(),
                        b"Zaa"
                    );
                    assert_eq!(
                        crate::runtime::list::to_vec(ctx, children[1])
                            .unwrap()
                            .iter()
                            .map(|v| v.as_byte().unwrap())
                            .collect::<Vec<_>>(),
                        b"aaa"
                    );
                    if let Some(usage) = usage {
                        assert_eq!(usage.arguments_transfer, Some(62));
                        assert_eq!(usage.results_transfer, Some(62));
                        assert_eq!(usage.construction_bytes, Some(288));
                    }
                }
            }
        }
    });
}
