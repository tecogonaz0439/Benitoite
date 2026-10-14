//! 内部の補助接続の寿命・キャッシュ・引数の優先を、本物の合成と実行で確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

use super::*;
use crate::bytecode::program::ExternalRef;
use crate::external::adapter::{
    component::GENERATION_LIMIT, layout::LayoutError, runtime::prepare,
};
use crate::external::{ComponentSource, WitPlan as P};
use crate::runtime::heap::{Heap, HeapConfig};

fn append(table: &mut ExternalTable, export: &str, params: Vec<P>, result: Option<P>) -> u32 {
    let id = u32::try_from(table.functions.len()).unwrap();
    table.functions.push(ExternalRef {
        component: 0,
        arity: u16::try_from(params.len()).unwrap(),
        spec: Arc::new(ExternalSpec {
            id,
            function: format!("declaration-{id}"),
            component: Arc::clone(&table.components[0]),
            instance: None,
            export: export.into(),
            route: ExternalRoute::of(&params, result.as_ref()),
            params,
            result,
            adapter: None,
        }),
    });
    id
}

fn attach(table: &mut ExternalTable, ids: &[u32], limit: usize) {
    let specs: Vec<_> = ids
        .iter()
        .map(|id| Arc::clone(&table.functions[*id as usize].spec))
        .collect();
    let bindings = prepare(&specs, &mut 1_000_000, limit).unwrap();
    for id in ids {
        Arc::make_mut(&mut table.functions[*id as usize].spec).adapter = bindings.get(id).cloned();
    }
}

fn adapted<'e>(
    runtime: &mut ExternalRuntime,
    table: &ExternalTable,
    index: u32,
    ctx: &NoGcCtx<'e>,
    args: &[Value<'e>],
    limit: u64,
) -> Result<Value<'e>, ExternalFailure> {
    let binding = table.functions[index as usize]
        .spec
        .adapter
        .as_deref()
        .unwrap();
    call_with_usage(
        runtime,
        table,
        index,
        ctx,
        args,
        Limits {
            transfer: limit,
            ..Limits::default()
        },
        Some(binding),
    )
}

#[test]
fn unused_adapter_declarations_do_not_exhaust_core_instances() {
    // 関門: 一つのゲストの宣言を増やしても、呼ぶ関数のインスタンス数は増えない。
    // 既存の複数関数の試験は、Store のインスタンス数の上限まで届かない。
    let core = (0..15)
        .map(|i| format!("(func (export \"f{i}\") (result i32) i32.const {i})"))
        .collect::<String>();
    let exports = (0..15)
        .map(|i| {
            format!("(func (export \"f{i}\") (result u32) (canon lift (core func $i \"f{i}\")))")
        })
        .collect::<String>();
    let guest = format!(
        "(component (core module $m {core}) (core instance $i (instantiate $m)) {exports})"
    );
    let mut table = super::tests::table(&guest, "f0", Some(P::U32));
    for i in 1..15 {
        append(&mut table, &format!("f{i}"), vec![], Some(P::U32));
    }
    attach(&mut table, &(0..15).collect::<Vec<_>>(), GENERATION_LIMIT);
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        assert_eq!(
            adapted(&mut runtime, &table, 0, ctx, &[], 64)
                .unwrap()
                .as_uint32(),
            Some(0)
        );
    });
}

#[test]
fn core_instance_limits_choose_dynamic_before_entering_the_guest() {
    // 関門: 補助の三個を含む上限の前後を実際に呼び、動的経路なら通る契約を保つ。
    // 宣言数の試験は、元ゲストだけで上限近くまで使う組み合わせを確かめない。
    for count in [13, 14, 16, 17] {
        let extra = "(core instance (instantiate $empty))".repeat(count - 1);
        let guest = format!(
            r#"(component (core module $empty) {extra}
            (core module $m (func (export "run") (result i32) i32.const 19))
            (core instance $i (instantiate $m))
            (func (export "run") (result u32) (canon lift (core func $i "run"))))"#
        );
        let nested_instances = (0..count)
            .map(|i| format!("(instance $i{i} (instantiate $c))"))
            .collect::<String>();
        let nested = format!(
            r#"(component
            (component $c (core module $m (func (export "run") (result i32) i32.const 19))
                (core instance $i (instantiate $m))
                (func (export "run") (result u32) (canon lift (core func $i "run"))))
            {nested_instances} (alias export $i0 "run" (func $run)) (export "run" (func $run)))"#
        );
        for guest in [guest, nested] {
            let mut table = super::tests::table(&guest, "run", Some(P::U32));
            attach(&mut table, &[0], GENERATION_LIMIT);
            assert_eq!(
                table.functions[0]
                    .spec
                    .adapter
                    .as_deref()
                    .unwrap()
                    .fallback_reason(),
                (count > 13).then_some(text::FALLBACK_INSTANCES)
            );
            let stats = super::super::stats::Collector::new();
            let mut runtime = ExternalRuntime::configured(
                None,
                super::super::stats::ExecutionOptions {
                    stats: Some(stats.clone()),
                    ..Default::default()
                },
            )
            .unwrap();
            let mut heap = Heap::new(HeapConfig::default());
            heap.epoch(|ctx| {
                let result = call(&mut runtime, &table, 0, ctx, &[]);
                if count <= 16 {
                    assert_eq!(result.unwrap().as_uint32(), Some(19));
                } else {
                    assert!(matches!(
                        result,
                        Err(ExternalFailure::Stop(Stop::Resource(
                            ResourceError::ExternalObjects {
                                resource: text::CORE_INSTANCES,
                                size: 17,
                                limit: 16,
                                ..
                            }
                        )))
                    ));
                }
            });
            let json = stats.json().unwrap();
            let route = if count == 13 { "adapter" } else { "dynamic" };
            assert_eq!(json["routes"][route], 1);
            if count > 13 {
                assert_eq!(json["fallback_reasons"]["core_instance_limit"], 1);
            }
        }
    }
}

#[test]
fn generation_fallback_for_one_function_preserves_other_adapter_calls() {
    // 関門: 長い書き出し名が生成上限を超えても、別の関数の経路と結果は変わらない。
    // 単独の生成上限の試験では、複数の宣言をまとめることによる退行を捕まえない。
    let long = "large".repeat(2_000);
    let guest = format!(
        r#"(component
        (core module $m (func (export "run") (result i32) i32.const 19))
        (core instance $i (instantiate $m))
        (func $run (result u32) (canon lift (core func $i "run")))
        (export "small" (func $run)) (export "{long}" (func $run)))"#
    );
    let mut table = super::tests::table(&guest, "small", Some(P::U32));
    let other = append(&mut table, &long, vec![], Some(P::U32));
    attach(&mut table, &[0, other], 6_000);
    assert_eq!(
        table.functions[0]
            .spec
            .adapter
            .as_deref()
            .unwrap()
            .fallback_reason(),
        None
    );
    assert_eq!(
        table.functions[1]
            .spec
            .adapter
            .as_deref()
            .unwrap()
            .fallback_reason(),
        Some(text::FALLBACK_GENERATION)
    );
    let stats = super::super::stats::Collector::new();
    let mut runtime = ExternalRuntime::configured(
        None,
        super::super::stats::ExecutionOptions {
            stats: Some(stats.clone()),
            ..Default::default()
        },
    )
    .unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for id in [0, other] {
            assert_eq!(
                call(&mut runtime, &table, id, ctx, &[])
                    .unwrap()
                    .as_uint32(),
                Some(19)
            );
        }
    });
    let json = stats.json().unwrap();
    assert_eq!(json["routes"]["adapter"], 1);
    assert_eq!(json["routes"]["dynamic"], 1);
    assert_eq!(json["fallback_reasons"]["generation_limit"], 1);
}

#[test]
fn adapter_and_resource_caches_coexist_and_pure_instances_are_fresh() {
    // 関門: 同じ元コードの二つの経路で状態・キャッシュを上書きする退行を捕まえる。
    // 補助単体の合成の試験では、実行系の resource の保存領域へ届かない。
    let mut table = super::tests::resources();
    let original = include_str!("../../../testdata/external/resource/x.wat");
    let end = original.rfind(')').unwrap();
    let guest = format!(
        r#"{}
        (core module $pure (global $n (mut i64) (i64.const 40))
            (func (export "tick") (result i64)
                global.get $n i64.const 1 i64.add global.set $n global.get $n)
            (func (export "void")))
        (core instance $pure-i (instantiate $pure))
        (func (export "tick") (result s64) (canon lift (core func $pure-i "tick")))
        (func (export "void") (canon lift (core func $pure-i "void"))))"#,
        &original[..end]
    );
    let source = Arc::new(ComponentSource {
        display: "resource-and-pure.wasm".into(),
        bytes: wat::parse_str(guest).unwrap().into(),
    });
    table.components[0] = Arc::clone(&source);
    for reference in &mut table.functions {
        Arc::make_mut(&mut reference.spec).component = Arc::clone(&source);
    }
    let tick = append(&mut table, "tick", vec![], Some(P::S64));
    let void = append(&mut table, "void", vec![], None);
    attach(&mut table, &[tick, void], GENERATION_LIMIT);
    assert!(matches!(
        table.functions[tick as usize].spec.route,
        ExternalRoute::Typed(_)
    ));
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let handle = call(&mut runtime, &table, 0, ctx, &[Value::Int(7)]).unwrap();
        for _ in 0..3 {
            assert!(matches!(
                adapted(&mut runtime, &table, void, ctx, &[], 32),
                Ok(Value::Unit)
            ));
            assert_eq!(
                call(&mut runtime, &table, tick, ctx, &[]).unwrap().as_int(),
                Some(41)
            );
            assert_eq!(
                adapted(&mut runtime, &table, tick, ctx, &[], 64)
                    .unwrap()
                    .as_int(),
                Some(41)
            );
            assert_eq!(
                call(&mut runtime, &table, 3, ctx, &[handle])
                    .unwrap()
                    .as_int(),
                Some(1)
            );
        }
        assert_eq!(
            call(&mut runtime, &table, 1, ctx, &[handle, Value::Int(2)])
                .unwrap()
                .as_int(),
            Some(9)
        );
    });
    assert_eq!(runtime.components.iter().flatten().count(), 1);
    assert_eq!(runtime.adapters.len(), 2);
    assert_eq!(runtime.stateful.iter().flatten().count(), 1);
}

#[test]
fn adapter_cache_keeps_construction_rules_sources_and_host_tags_distinct() {
    // 関門: 実行系で別の構築表を使う退行を、同じ WIT の結果の独立した値と上限で捕まえる。
    // 補助単体の試験と違い、キャッシュ済みの Component と宣言固有の復号表を接続する。
    let memory = r#"(memory (export "memory") 1)
        (global $bump (mut i32) (i32.const 8192))
        (func (export "realloc") (param i32 i32 i32) (param $len i32) (result i32)
            global.get $bump global.get $bump local.get $len i32.add global.set $bump)"#;
    let guest = format!(
        r#"(component (core module $m {memory}
        (data (i32.const 4096) "\01\02\03")
        (func (export "bytes") (result i32)
            i32.const 1024 i32.const 4096 i32.store
            i32.const 1028 i32.const 3 i32.store i32.const 1024)
        (func (export "pair") (result i32)
            i32.const 2048 i32.const 0 i32.store8
            i32.const 2052 i32.const 7 i32.store
            i32.const 2056 i32.const 9 i32.store i32.const 2048))
        (core instance $i (instantiate $m)) (type $list (list u8))
        (type $p (tuple u32 u32)) (type $v0 (variant (case "pair" $p)))
        (export $v "value-type" (type $v0))
        (func (export "bytes") (result $list) (canon lift (core func $i "bytes")
            (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
        (func (export "pair") (result $v) (canon lift (core func $i "pair")
            (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let mut table = super::tests::table(&guest, "bytes", Some(P::Bytes));
    let list = append(&mut table, "bytes", vec![], Some(P::List(Box::new(P::U8))));
    let variant = |tag, payload| P::Variant {
        cases: vec![("pair".into(), tag, Some(Box::new(payload)))],
    };
    let one = append(
        &mut table,
        "pair",
        vec![],
        Some(variant(55, P::Tuple(vec![P::U32, P::U32]))),
    );
    let two = append(
        &mut table,
        "pair",
        vec![],
        Some(variant(66, P::TupleFields(vec![P::U32, P::U32]))),
    );
    let other_tag = append(
        &mut table,
        "pair",
        vec![],
        Some(variant(77, P::TupleFields(vec![P::U32, P::U32]))),
    );
    attach(
        &mut table,
        &[0, list, one, two, other_tag],
        GENERATION_LIMIT,
    );
    let changed = guest.replace("i32.const 7 i32.store", "i32.const 11 i32.store");
    let mut other = super::tests::table(
        &changed,
        "pair",
        Some(variant(88, P::TupleFields(vec![P::U32, P::U32]))),
    );
    attach(&mut other, &[0], GENERATION_LIMIT);
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for _ in 0..2 {
            let bytes = adapted(&mut runtime, &table, 0, ctx, &[], 48).unwrap();
            assert_eq!(ctx.bytes(bytes).unwrap(), &[1, 2, 3]);
            assert!(matches!(
                adapted(&mut runtime, &table, list, ctx, &[], 63),
                Err(ExternalFailure::Stop(Stop::Resource(
                    ResourceError::ExternalTransfer { limit: 63, .. }
                )))
            ));
            let values = adapted(&mut runtime, &table, list, ctx, &[], 64).unwrap();
            assert_eq!(crate::runtime::list::len(ctx, values).unwrap(), 3);
            assert!(matches!(
                adapted(&mut runtime, &table, one, ctx, &[], 63),
                Err(ExternalFailure::Stop(Stop::Resource(
                    ResourceError::ExternalTransfer { limit: 63, .. }
                )))
            ));
            let value = adapted(&mut runtime, &table, one, ctx, &[], 64).unwrap();
            assert_eq!(ctx.fields_header(value).unwrap().1, 55);
            let pair = ctx.field(value, 0).unwrap();
            assert_eq!(ctx.field(pair, 0).unwrap().as_uint32(), Some(7));
            assert_eq!(ctx.field(pair, 1).unwrap().as_uint32(), Some(9));
            for (table, id, tag, first) in [
                (&table, two, 66, 7),
                (&table, other_tag, 77, 7),
                (&other, 0, 88, 11),
            ] {
                let value = adapted(&mut runtime, table, id, ctx, &[], 48).unwrap();
                assert_eq!(ctx.fields_header(value).unwrap().1, tag);
                assert_eq!(ctx.field(value, 0).unwrap().as_uint32(), Some(first));
                assert_eq!(ctx.field(value, 1).unwrap().as_uint32(), Some(9));
            }
        }
    });
    assert_eq!(runtime.adapters.len(), 5);
    assert!(runtime.components.is_empty());
}

#[test]
fn adapter_arguments_fail_before_lazy_compile_and_guest_start() {
    // 関門: 内部の本番接続で、引数の予算・種類の誤りを start のトラップより先に返す。
    // 既存経路の試験は補助のヘッダと構築予算を通らない。
    let guest = r#"(component (core module $m
        (func $start unreachable) (start $start)
        (func (export "run") (param i32) (result i32) local.get 0))
        (core instance $i (instantiate $m))
        (func (export "run") (param "x" u32) (result u32) (canon lift (core func $i "run"))))"#;
    let mut table = super::tests::table(guest, "run", Some(P::U32));
    let spec = Arc::make_mut(&mut table.functions[0].spec);
    spec.params = vec![P::U32];
    table.functions[0].arity = 1;
    attach(&mut table, &[0], GENERATION_LIMIT);
    let mut runtime = ExternalRuntime::new(None).unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        assert!(matches!(
            adapted(&mut runtime, &table, 0, ctx, &[Value::UInt32(1)], 35),
            Err(ExternalFailure::Stop(Stop::Resource(
                ResourceError::ExternalTransfer { limit: 35, .. }
            )))
        ));
        assert!(matches!(
            adapted(&mut runtime, &table, 0, ctx, &[Value::Bool(true)], 64),
            Err(ExternalFailure::Stop(Stop::Internal(_)))
        ));
        assert!(runtime.adapters.is_empty());
        assert!(matches!(
            adapted(&mut runtime, &table, 0, ctx, &[Value::UInt32(1)], 64),
            Err(ExternalFailure::Stop(Stop::Runtime(
                RuntimeError::ExternalTrap { .. }
            )))
        ));
        assert_eq!(runtime.adapters.len(), 1);
        assert!(runtime.components.is_empty());
    });
}

#[test]
fn adapter_candidates_keep_the_remaining_type_budget_and_generation_fallback() {
    // 関門: 照合後の残量を内部の準備へ渡し、生成・配置が予算を戻す退行を捕まえる。
    // 配置だけの試験は、共有キー・生成・ホストの復号表を通した合計を検査できない。
    let guest = r#"(component (core module $m (func (export "run") (result i32) i32.const 19))
        (core instance $i (instantiate $m))
        (func (export "run") (result u32) (canon lift (core func $i "run"))))"#;
    let mut table = super::tests::table(guest, "run", Some(P::U32));
    let specs = [Arc::clone(&table.functions[0].spec)];
    assert!(matches!(
        prepare(&specs, &mut 2, GENERATION_LIMIT),
        Err(LayoutError::TypeBudget)
    ));
    let mut remaining = 3;
    assert_eq!(
        prepare(&specs, &mut remaining, GENERATION_LIMIT)
            .unwrap()
            .len(),
        1
    );
    assert_eq!(remaining, 0);
    attach(&mut table, &[0], 1);
    assert_eq!(
        table.functions[0]
            .spec
            .adapter
            .as_deref()
            .unwrap()
            .fallback_reason(),
        Some(text::FALLBACK_GENERATION)
    );
    assert_eq!(table.functions[0].spec.route, ExternalRoute::Dynamic);
    let stats = super::super::stats::Collector::new();
    let mut runtime = ExternalRuntime::configured(
        None,
        super::super::stats::ExecutionOptions {
            stats: Some(stats.clone()),
            ..Default::default()
        },
    )
    .unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        assert_eq!(
            call(&mut runtime, &table, 0, ctx, &[]).unwrap().as_uint32(),
            Some(19)
        );
    });
    assert!(runtime.adapters.is_empty());
    let json = stats.json().unwrap();
    assert_eq!(json["routes"]["dynamic"], 1);
    assert_eq!(json["fallback_reasons"]["generation_limit"], 1);
    assert_eq!(
        json["functions"]["wasm/test.wasm#testFn"]["fallback_reasons"]["generation_limit"],
        1
    );
}
