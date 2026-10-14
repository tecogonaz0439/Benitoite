//! 合成の共有を、異なる宣言の結果・予算・タグの対応で確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::{
    codec::CodecPlan,
    component::{BuildError, ComponentGroup, GENERATION_LIMIT},
    fixed_tests::{MEMORY, input},
    layout::LayoutError,
    runtime::{link_failure, reported_failure},
    variant_tests::pair_variant_guest,
};
use crate::external::{ComponentSource, ExternalRoute, ExternalSpec, WitPlan as P};
use crate::runtime::heap::{Heap, HeapConfig};
use std::sync::Arc;
use wasmtime::{
    Engine, Store,
    component::{Component, Linker},
};

fn spec(source: &[u8], id: u32, export: &str, result: P) -> Arc<ExternalSpec> {
    Arc::new(ExternalSpec {
        adapter: None,
        id,
        function: format!("declaration-{id}"),
        component: Arc::new(ComponentSource {
            display: format!("source-{id}"),
            bytes: source.into(),
        }),
        instance: None,
        export: export.into(),
        params: vec![],
        result: Some(result),
        route: ExternalRoute::Dynamic,
    })
}
fn group(groups: &[ComponentGroup], id: u32) -> &ComponentGroup {
    groups.iter().find(|g| g.exports.contains_key(&id)).unwrap()
}

fn engine() -> Engine {
    Engine::new(&crate::external::engine_config()).unwrap()
}
fn call(
    engine: &Engine,
    component: &Component,
    name: &str,
    bytes: &[u8],
) -> wasmtime::Result<Vec<u8>> {
    // コンパイル済み Component だけを共有し、ゲストの状態と補助の確保器は毎回捨てる。
    let mut store = Store::new(engine, ());
    store.set_fuel(1_000_000).unwrap();
    store.set_epoch_deadline(1);
    let mut linker = Linker::new(engine);
    link_failure(&mut linker).unwrap();
    let instance = linker.instantiate(&mut store, component)?;
    let f = instance.get_typed_func::<(&[u8],), (Vec<u8>,)>(&mut store, name)?;
    Ok(f.call(&mut store, (bytes,))?.0)
}

#[test]
fn grouped_exports_sources_and_interface_functions_keep_their_results() {
    // 関門: 複数関数・インターフェース・異なる元コードの取り違えと、呼び出し間の状態の残留を捕まえる。
    // 同じ書き出しの再宣言と異なる書き出しの合成を、実際に呼んで区別する。
    let guest = |number| {
        wat::parse_str(format!(r#"(component
        (core module $m (global $n (mut i32) (i32.const {number}))
            (func (export "first") (result i32) global.get $n i32.const 1 i32.add global.set $n global.get $n)
            (func (export "second") (result i32) i32.const 99))
        (core instance $i (instantiate $m))
        (func $first (result u32) (canon lift (core func $i "first")))
        (func $second (result u32) (canon lift (core func $i "second")))
        (export "first" (func $first)) (export "second" (func $second))
        (instance $api (export "get" (func $second))) (export "api" (instance $api)))"#)).unwrap()
    };
    let a = guest(10);
    let b = guest(20);
    let mut interface = spec(&a, 3, "get", P::U32);
    Arc::get_mut(&mut interface).unwrap().instance = Some("api".into());
    let declarations = [
        spec(&a, 0, "first", P::U32),
        spec(&a, 1, "second", P::U32),
        spec(&a, 2, "first", P::U32),
        interface,
        spec(&b, 4, "first", P::U32),
    ];
    let groups = ComponentGroup::prepare(&declarations).unwrap();
    assert_eq!(groups.len(), 4);
    assert_eq!(group(&groups, 0).key, group(&groups, 2).key);
    // 元のコードは関数数によらず一つだけ含む。区画の識別子と LEB の長さを独立に読み、入れ子の区画を数える。
    let generated = group(&groups, 0).generate(GENERATION_LIMIT).unwrap();
    let mut cursor = 8;
    let mut originals = 0;
    while cursor < generated.len() {
        let section = generated[cursor];
        cursor += 1;
        let mut length = 0_usize;
        let mut shift = 0;
        loop {
            let byte = generated[cursor];
            cursor += 1;
            length |= usize::from(byte & 0x7f) << shift;
            if byte & 0x80 == 0 {
                break;
            }
            shift += 7;
        }
        if section == 4 {
            assert_eq!(&generated[cursor..cursor + length], &a);
            originals += 1;
        }
        cursor += length;
    }
    assert_eq!(originals, 1);
    let reversed: Vec<_> = declarations.iter().rev().cloned().collect();
    let reordered = ComponentGroup::prepare(&reversed).unwrap();
    for id in 0..5 {
        assert_eq!(group(&groups, id).key, group(&reordered, id).key);
        assert_eq!(group(&groups, id).exports, group(&reordered, id).exports);
    }
    let engine = engine();
    for selected in &groups {
        let component = selected.compile(&engine, GENERATION_LIMIT).unwrap();
        for id in selected.exports.keys().cycle().take(8) {
            let number = match id {
                0 | 2 => 11_u32,
                4 => 21,
                _ => 99,
            };
            assert_eq!(
                call(
                    &engine,
                    &component,
                    &selected.exports[id],
                    &input(&[], 0, 64)
                )
                .unwrap(),
                input(&number.to_le_bytes(), 1, 64)
            );
        }
    }
}

#[test]
fn shared_byte_list_exports_preserve_host_construction_budgets() {
    // 関門: 同じ実行内の Bytes と List[Byte] の予算を分離する。個別の合成では共有キーの欠落を見つけられない。
    let guest = wat::parse_str(format!(r#"(component (core module $m {MEMORY}
        (data (i32.const 4096) "\01\02\03")
        (func (export "run") (result i32)
            i32.const 1024 i32.const 4096 i32.store i32.const 1028 i32.const 3 i32.store i32.const 1024))
        (core instance $i (instantiate $m)) (type $list (list u8))
        (func (export "run") (result $list) (canon lift (core func $i "run")
            (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#)).unwrap();
    let declarations = [
        spec(&guest, 0, "run", P::Bytes),
        spec(&guest, 1, "run", P::List(Box::new(P::U8))),
    ];
    let groups = ComponentGroup::prepare(&declarations).unwrap();
    assert_ne!(group(&groups, 0).key, group(&groups, 1).key);
    let engine = engine();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (id, cost) in [(0, 19), (1, 64)] {
            let selected = group(&groups, id as u32);
            let component = selected.compile(&engine, GENERATION_LIMIT).unwrap();
            let plans = [declarations[id].result.clone().unwrap()];
            let codec = CodecPlan::new(&plans, &mut 100_000).unwrap();
            for limit in [43, 63, 64] {
                let output = call(
                    &engine,
                    &component,
                    &selected.exports[&(id as u32)],
                    &input(&[], 0, limit),
                );
                if limit < cost {
                    let error = output.unwrap_err();
                    let report = reported_failure(&error).unwrap();
                    assert_eq!(
                        (report.number, report.requested, report.limit),
                        (4, cost, limit)
                    );
                } else {
                    let output = output.unwrap();
                    assert_eq!(output, input(&[40, 0, 0, 0, 3, 0, 0, 0, 1, 2, 3], 1, limit));
                    assert_eq!(
                        codec
                            .decode(ctx, &output, limit)
                            .unwrap()
                            .construction_bytes,
                        cost
                    );
                }
            }
        }
    });
}

#[test]
fn constructor_tags_share_code_but_payload_construction_rules_do_not() {
    // 関門: タグだけが違う宣言はコードを共有し、One(Pair) と Two の構築量はホストと一致させる。
    let guest = wat::parse_str(pair_variant_guest()).unwrap();
    let variant = |tag, payload| P::Variant {
        cases: vec![("pair".into(), tag, Some(Box::new(payload)))],
    };
    let declarations = [
        spec(
            &guest,
            0,
            "run",
            variant(42, P::Tuple(vec![P::U32, P::U32])),
        ),
        spec(
            &guest,
            1,
            "run",
            variant(77, P::Tuple(vec![P::U32, P::U32])),
        ),
        spec(
            &guest,
            2,
            "run",
            variant(88, P::TupleFields(vec![P::U32, P::U32])),
        ),
    ];
    let groups = ComponentGroup::prepare(&declarations).unwrap();
    assert_eq!(group(&groups, 0).key, group(&groups, 1).key);
    assert_ne!(group(&groups, 0).key, group(&groups, 2).key);
    let engine = engine();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (id, cost, tag) in [(0, 64, 42), (1, 64, 77), (2, 48, 88)] {
            let selected = group(&groups, id as u32);
            let component = selected.compile(&engine, GENERATION_LIMIT).unwrap();
            let plans = [declarations[id].result.clone().unwrap()];
            let codec = CodecPlan::new(&plans, &mut 100_000).unwrap();
            for limit in [48, 63, 64] {
                let output = call(
                    &engine,
                    &component,
                    &selected.exports[&(id as u32)],
                    &input(&[], 0, limit),
                );
                if limit < cost {
                    let error = output.unwrap_err();
                    let report = reported_failure(&error).unwrap();
                    assert_eq!(
                        (report.number, report.requested, report.limit),
                        (4, cost, limit)
                    );
                } else {
                    let output = output.unwrap();
                    assert_eq!(
                        output,
                        input(&[0, 0, 0, 0, 7, 0, 0, 0, 11, 0, 0, 0], 1, limit)
                    );
                    let decoded = codec.decode(ctx, &output, limit).unwrap();
                    assert_eq!(decoded.construction_bytes, cost);
                    assert_eq!(ctx.fields_header(decoded.values[0]).unwrap().1, tag);
                }
            }
        }
    });
}

#[test]
fn generation_limits_allow_fallback_without_hiding_invalid_code_or_imports() {
    // 関門: 小さい上限で生成途中の破棄を確認し、ABI の食い違い・取り込みは動的へ隠さない。
    let guest = wat::parse_str("(component (core module $m (func (export \"run\") (result i32) i32.const 7)) (core instance $i (instantiate $m)) (func (export \"run\") (result u32) (canon lift (core func $i \"run\"))))").unwrap();
    let declarations = [spec(&guest, 0, "run", P::U32)];
    let groups = ComponentGroup::prepare(&declarations).unwrap();
    let engine = engine();
    for limit in [0, 100, 1_000] {
        let error = groups[0].compile(&engine, limit).unwrap_err();
        assert!(matches!(
            error,
            BuildError::Layout(LayoutError::GenerationBudget)
        ));
        assert!(error.permits_dynamic());
    }
    assert!(groups[0].compile(&engine, GENERATION_LIMIT).is_ok());
    let groups = ComponentGroup::prepare(&[spec(&guest, 0, "missing", P::U32)]).unwrap();
    let error = groups[0].compile(&engine, GENERATION_LIMIT).unwrap_err();
    assert!(!error.permits_dynamic());
    let BuildError::Invalid(message) = error else {
        panic!("expected generated validation failure")
    };
    assert!(!message.is_empty());
    for guest in [
        "(component (type $f (func (result u32))) (import \"run\" (func (type $f))))",
        "(component (type $f (func (param \"code\" u32) (param \"requested\" u64) (param \"limit\" u64))) (import \"adapter-fail\" (func (type $f))))",
    ] {
        let guest = wat::parse_str(guest).unwrap();
        let groups = ComponentGroup::prepare(&[spec(&guest, 0, "run", P::U32)]).unwrap();
        let error = groups[0].compile(&engine, GENERATION_LIMIT).unwrap_err();
        assert!(!error.permits_dynamic());
        assert!(matches!(
            error,
            BuildError::Original(crate::external::check::ComponentError::Imports { count: 1, .. })
        ));
    }
}
