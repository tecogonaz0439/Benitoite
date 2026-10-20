//! 共有の準備の鍵と寿命を、実行入口と実コンポーネントで確かめる
//! （設計書 03-10「実行」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]

use super::*;
use crate::external::{
    WitPlan,
    stats::{Collector, ExecutionOptions},
};
use crate::runtime::heap::{Heap, HeapConfig};

// 関門: 同じ表示パスと配列番号の別 bytes を混同せず、別 Engine の成果物を使わない。
// CLI の同一 bytes の反復だけではこの誤ったキャッシュの鍵も通る。
#[test]
fn session_keys_use_bytes_and_owner_and_never_cache_failed_compilation() {
    let tables = [7, 9].map(|value| {
        super::tests::table(
            &format!(
                r#"(component
        (core module $m (func (export "f") (result i64) i64.const {value}))
        (core instance $i (instantiate $m))
        (func (export "f") (result s64) (canon lift (core func $i "f"))))"#
            ),
            "f",
            Some(WitPlan::S64),
        )
    });
    let session = Rc::new(ExternalSession::new(None));
    assert!(session.prepared.borrow().is_none());
    let stats = Collector::new();
    let options = || ExecutionOptions {
        stats: Some(stats.clone()),
        ..Default::default()
    };
    let mut heap = Heap::new(HeapConfig::default());
    for (table, expected) in [(&tables[0], 7), (&tables[1], 9), (&tables[0], 7)] {
        let mut runtime = ExternalRuntime::new_in(Rc::clone(&session), options()).unwrap();
        heap.epoch(|ctx| {
            assert_eq!(
                call(&mut runtime, table, 0, ctx, &[]).unwrap().as_int(),
                Some(expected)
            )
        });
    }
    assert_eq!(stats.json().unwrap()["runtime_compilations"]["normal"], 2);
    let mut other =
        ExternalRuntime::new_in(Rc::new(ExternalSession::new(None)), options()).unwrap();
    heap.epoch(|ctx| {
        assert_eq!(
            call(&mut other, &tables[0], 0, ctx, &[]).unwrap().as_int(),
            Some(7)
        )
    });
    assert_eq!(stats.json().unwrap()["runtime_compilations"]["normal"], 3);
    let mut invalid = tables[0].clone();
    Arc::make_mut(&mut invalid.components[0]).bytes = Arc::from(b"invalid wasm".as_slice());
    for _ in 0..2 {
        let mut runtime = ExternalRuntime::new_in(Rc::clone(&session), options()).unwrap();
        heap.epoch(|ctx| {
            assert!(matches!(
                call(&mut runtime, &invalid, 0, ctx, &[]),
                Err(ExternalFailure::Stop(Stop::Internal(_)))
            ))
        });
    }
    assert_eq!(stats.json().unwrap()["runtime_compilations"]["normal"], 3);
    assert_eq!(
        session
            .prepared
            .borrow()
            .as_ref()
            .unwrap()
            .components
            .values()
            .map(Vec::len)
            .sum::<usize>(),
        2
    );
}

// 関門: 同じ Engine でも、制限の失敗を次の実行の Store や燃料へ持ち越さない。
// 単独ランタイムの上限検査では、共有所有者へ実行状態を置く退行を捕まえない。
#[test]
fn session_keeps_limits_and_failed_stores_local_to_each_run() {
    let table = super::tests::resources();
    let session = Rc::new(ExternalSession::new(None));
    let stats = Collector::new();
    let mut heap = Heap::new(HeapConfig::default());
    for _ in 0..3 {
        let mut runtime = ExternalRuntime::new_in(
            Rc::clone(&session),
            ExecutionOptions {
                limits: Limits {
                    fuel: 100,
                    memory: 2 * 65536,
                    transfer: 1024,
                },
                stats: Some(stats.clone()),
                ..Default::default()
            },
        )
        .unwrap();
        heap.epoch(|ctx| {
            let a = call(&mut runtime, &table, 0, ctx, &[Value::Int(10)]).unwrap();
            for _ in 0..30 {
                assert_eq!(
                    call(&mut runtime, &table, 3, ctx, &[a]).unwrap().as_int(),
                    Some(1)
                );
            }
            assert!(matches!(
                call(&mut runtime, &table, 0, ctx, &[Value::Int(20)]),
                Err(ExternalFailure::Stop(Stop::Resource(
                    ResourceError::ExternalMemory { limit: 131072, .. }
                )))
            ));
        });
    }
    let value = stats.json().unwrap();
    assert_eq!(value["runtime_compilations"]["normal"], 1);
    assert_eq!(value["reached_limits"]["memory"], 3);
    assert_eq!(value["stateful_instances"].as_array().unwrap().len(), 3);
}
