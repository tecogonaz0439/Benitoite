//! 補助の本番の接続から、診断と成功・失敗の統計までを確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::bytecode::asm::ProgramBuilder;
use crate::bytecode::program::{ExternalRef, ExternalTable};
use crate::diag::DiagCode;
use crate::external::stats::{Collector, ExecutionOptions};
use crate::external::{ComponentSource, ExternalRoute, WitPlan as P};
use crate::runtime::heap::{Heap, HeapConfig};
use crate::runtime::report::stop_diagnostic;
use crate::vm::StopInfo;

const GUEST: &str = r#"(component
    (core module $m (func (export "run") (result i32) i32.const 19))
    (core instance $i (instantiate $m))
    (func (export "run") (result u32) (canon lift (core func $i "run"))))"#;

fn table(guest: &str) -> ExternalTable {
    let source = Arc::new(ComponentSource {
        display: "report.wasm".into(),
        bytes: wat::parse_str(guest).unwrap().into(),
    });
    let mut spec = ExternalSpec {
        id: 0,
        function: "old-name".into(),
        component: Arc::clone(&source),
        instance: None,
        export: "run".into(),
        params: vec![],
        route: ExternalRoute::Dynamic,
        result: Some(P::U32),
        adapter: None,
    };
    spec.adapter = prepare(
        &[Arc::new(spec.clone())],
        &mut 100_000,
        super::super::component::GENERATION_LIMIT,
    )
    .unwrap()
    .remove(&0);
    ExternalTable {
        components: vec![source],
        functions: vec![ExternalRef {
            component: 0,
            arity: 0,
            spec: Arc::new(spec),
        }],
    }
}

fn invoke(
    table: &ExternalTable,
    limits: Limits,
    stats: Option<Collector>,
) -> Result<u32, ExternalFailure> {
    let mut runtime = ExternalRuntime::configured(
        None,
        ExecutionOptions {
            limits,
            stats,
            session: None,
        },
    )
    .unwrap();
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        crate::external::runtime::call_with_usage(
            &mut runtime,
            table,
            0,
            ctx,
            &[],
            limits,
            table.functions[0].spec.adapter.as_deref(),
        )
        .map(|v| v.as_uint32().unwrap())
    })
}

fn diagnostic(stop: Stop) -> crate::diag::Diagnostic {
    let program = ProgramBuilder::new().program;
    stop_diagnostic(
        &program,
        &StopInfo {
            stop,
            at: None,
            frames: vec![],
            spawns: vec![],
            deadlock: vec![],
        },
    )
}

#[test]
fn composed_reports_keep_their_type_quantities_and_diagnostic_class() {
    // 関門: 手書きの外側から報告し、合成・本番の呼び出し・診断・統計を通す。
    // 報告型だけの試験では、実行の接続が予算不足を内部エラーへ変える退行を捕まえない。
    for (number, requested, limit, code) in [
        (1, 65, 64, Some(DiagCode::R0905)),
        (2, 65, 64, Some(DiagCode::R0905)),
        (3, 80, 64, Some(DiagCode::R0905)),
        (4, 80, 64, Some(DiagCode::R0905)),
        (5, (1 << 24) + 1, 1 << 24, Some(DiagCode::R0902)),
        (5, (1 << 30) + 1, 1 << 30, Some(DiagCode::R0902)),
        (6, 131_072, 65_536, Some(DiagCode::R0905)),
        (6, u64::MAX, u32::MAX as u64, Some(DiagCode::R0905)),
        (7, 8, 4, None),
        (99, 8, 4, None),
    ] {
        let mut table = table(GUEST);
        // 元のゲストへ報告の取り込みを追加せず、外側の報告だけを明示する。
        let outer = format!(
            r#"(component
            (type $fail (func (param "code" u32) (param "requested" u64) (param "limit" u64)))
            (import "adapter-fail" (func $fail (type $fail)))
            {GUEST}
            (instance $guest (instantiate 0))
            (alias export $guest "run" (func $run))
            (core func $fail-core (canon lower (func $fail)))
            (core func $run-core (canon lower (func $run)))
            (core module $m
                (import "host" "fail" (func $fail (param i32 i64 i64)))
                (import "host" "run" (func $run (result i32)))
                (memory (export "memory") 1)
                (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
                (func (export "call") (param i32 i32) (result i32)
                    call $run drop i32.const {number} i64.const {requested} i64.const {limit}
                    call $fail unreachable))
            (core instance $host (export "fail" (func $fail-core)) (export "run" (func $run-core)))
            (core instance $i (instantiate $m (with "host" (instance $host))))
            (type $bytes (list u8))
            (func (export "call") (param "input" $bytes) (result $bytes)
                (canon lift (core func $i "call") (memory (core memory $i "memory"))
                    (realloc (core func $i "realloc")))))"#
        );
        let Binding::Adapter {
            component,
            arguments,
            results,
            ..
        } = table.functions[0].spec.adapter.as_deref().unwrap()
        else {
            panic!("expected adapter");
        };
        let binding = Binding::Adapter {
            component: Arc::new(PreparedComponent {
                key: component.key.clone(),
                bytes: wat::parse_str(outer).unwrap().into(),
            }),
            export: "call".into(),
            arguments: arguments.clone(),
            results: results.clone(),
        };
        Arc::make_mut(&mut table.functions[0].spec).adapter = Some(Arc::new(binding));
        for enabled in [false, true] {
            let stats = enabled.then(Collector::new);
            let result = invoke(&table, Limits::default(), stats.clone());
            let Err(ExternalFailure::Stop(stop)) = result else {
                panic!("{result:?}");
            };
            let report = diagnostic(stop);
            assert_eq!(report.code, code, "{report:?}");
            assert!(format!("{report:?}").contains("old-name"));
            if code == Some(DiagCode::R0902) {
                assert!(
                    report
                        .notes
                        .iter()
                        .any(|n| n.contains(&requested.to_string()))
                );
            }
            if let Some(stats) = stats {
                let json = stats.json().unwrap();
                let function = &json["functions"]["report.wasm#old-name"];
                assert_eq!(function["routes"]["adapter"], 1);
                assert_eq!(function["construction_bytes"]["incomplete_calls"], 1);
                assert_eq!(
                    function["adapter_failures"],
                    serde_json::json!([
                        {"code": number, "requested": requested, "limit": limit, "calls": 1}
                    ])
                );
                let budget = if number == 6 { "memory" } else { "transfer" };
                if code == Some(DiagCode::R0905) {
                    assert_eq!(function["reached_limits"][budget], 1);
                }
                assert_eq!(json["adapter_failures"], function["adapter_failures"]);
            }
        }
    }
}

#[test]
fn generated_calls_report_success_and_guest_traps_without_retry() {
    // 関門: 本物の生成器を通し、成功の構築量とゲストのトラップの分類を独立して守る。
    // 報告専用の外側では、正常終了と通常の Wasmtime のトラップへ届かない。
    let extra = "(core instance (instantiate $extra))".repeat(15);
    let many_instances = GUEST.replacen(
        "(component",
        &format!("(component (core module $extra) {extra}"),
        1,
    );
    for (guest, limits, expected) in [
        (GUEST.to_owned(), Limits::default(), None),
        (
            GUEST.replace("i32.const 19", "unreachable"),
            Limits::default(),
            Some(DiagCode::R0601),
        ),
        (
            GUEST.to_owned(),
            Limits {
                fuel: 1,
                ..Limits::default()
            },
            Some(DiagCode::R0904),
        ),
        (
            GUEST.to_owned(),
            Limits {
                memory: 0,
                ..Limits::default()
            },
            Some(DiagCode::R0905),
        ),
        (many_instances, Limits::default(), Some(DiagCode::R0906)),
    ] {
        let mut table = table(&guest);
        if expected == Some(DiagCode::R0906) {
            assert_eq!(
                table.functions[0]
                    .spec
                    .adapter
                    .as_deref()
                    .unwrap()
                    .fallback_reason(),
                Some(crate::external::text::FALLBACK_INSTANCES)
            );
            // 事前の振り分けとは独立に、内部の合成の上限診断も保つ。
            let mut forced = self::table(GUEST);
            let group = super::super::component::ComponentGroup::prepare(&[Arc::clone(
                &table.functions[0].spec,
            )])
            .unwrap()
            .remove(0);
            let Binding::Adapter { component, .. } = Arc::get_mut(
                Arc::make_mut(&mut forced.functions[0].spec)
                    .adapter
                    .as_mut()
                    .unwrap(),
            )
            .unwrap() else {
                panic!("expected adapter");
            };
            Arc::get_mut(component).unwrap().key = group.key.clone();
            Arc::get_mut(component).unwrap().bytes = group
                .generate(super::super::component::GENERATION_LIMIT)
                .unwrap()
                .into();
            table = forced;
        }
        let stats = Collector::new();
        let result = invoke(&table, limits, Some(stats.clone()));
        match expected {
            None => assert_eq!(result.unwrap(), 19),
            Some(code) => {
                let Err(ExternalFailure::Stop(stop)) = result else {
                    panic!("{result:?}");
                };
                let report = diagnostic(stop);
                assert_eq!(report.code, Some(code));
                assert!(report.message.contains("old-name"));
                if code == DiagCode::R0905 {
                    assert!(
                        report
                            .notes
                            .iter()
                            .any(|note| note.contains("generated adapter memory"))
                    );
                }
            }
        }
        let json = stats.json().unwrap();
        assert_eq!(json["calls"], 1);
        assert_eq!(json["routes"]["adapter"], 1);
        assert_eq!(json["arguments_transfer"]["total"], 32);
        assert_eq!(json["adapter_failures"], serde_json::json!([]));
        assert_eq!(
            json["functions"]["report.wasm#old-name"]["routes"]["adapter"],
            1
        );
        match expected {
            Some(DiagCode::R0904) => {
                assert_eq!(json["reached_limits"]["fuel"], 1);
                assert_eq!(json["fuel"]["total"], 1);
            }
            Some(DiagCode::R0905) => assert_eq!(json["reached_limits"]["memory"], 1),
            Some(DiagCode::R0906) => assert_eq!(json["reached_limits"]["core_instances"], 1),
            _ => {}
        }
        if expected.is_none() {
            assert_eq!(json["results_transfer"]["total"], 36);
            assert_eq!(json["construction_bytes"]["total"], 16);
            assert_eq!(json["construction_bytes"]["incomplete_calls"], 0);
        }
    }
}

#[test]
fn adapter_linking_failure_is_internal() {
    // 関門: 補助の取り込みの不整合を、本番の Linker の失敗から内部エラーへ分類する。
    // 元ゲストの start の trap や燃料切れの試験は、この取り込みの不具合へ届かない。
    let mut table = table(GUEST);
    let binding = Arc::get_mut(
        Arc::make_mut(&mut table.functions[0].spec)
            .adapter
            .as_mut()
            .unwrap(),
    )
    .unwrap();
    let Binding::Adapter { component, .. } = binding else {
        panic!("expected adapter");
    };
    Arc::get_mut(component).unwrap().bytes =
        wat::parse_str(r#"(component (type $f (func)) (import "missing" (func (type $f))))"#)
            .unwrap()
            .into();
    let result = invoke(&table, Limits::default(), None);
    let Err(ExternalFailure::Stop(Stop::Internal(message))) = result else {
        panic!("{result:?}");
    };
    assert!(
        message.contains("adapter instantiation failed") && message.contains("missing"),
        "{message}"
    );
}
