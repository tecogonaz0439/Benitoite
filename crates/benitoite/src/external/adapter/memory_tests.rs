//! メモリと報告の契約を、独立したコアと本物の正準 ABI の境界で検査する。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::runtime::{AdapterFailure, FailureClass, link_failure, reported_failure};
use wasm_encoder::{
    Alias, CanonicalFunctionSection, ComponentAliasSection, ComponentExportKind,
    ComponentExportSection, ComponentTypeSection, ExportKind, InstanceSection, ModuleArg,
    PrimitiveValType as T, RawSection,
};
use wasmtime::component::{Component, Instance, Linker};
use wasmtime::{Engine, Store};

fn fixture(maximum: u64) -> (Engine, Component) {
    let mut component = super::component::memory_component(1, Some(maximum)).unwrap();
    // 生成器の命令を期待値に使わず、手書きのコアから検査と確保を呼ぶ。
    let core = wat::parse_str(
        r#"(module
        (import "support" "memory" (memory 1))
        (import "support" "realloc" (func $realloc (param i32 i32 i32 i32) (result i32)))
        (import "support" "check-range" (func $range (param i32 i32 i32)))
        (import "support" "check-header" (func $header (param i32 i32 i32 i64)))
        (import "failure" "adapter-fail" (func $fail (param i32 i64 i64)))
        (func (export "alloc") (param i32 i32 i32 i32) (result i32)
            local.get 0 local.get 1 local.get 2 local.get 3 call $realloc)
        (func (export "range") (param i32 i32 i32)
            local.get 0 local.get 1 local.get 2 call $range)
        (func (export "header") (param i32 i32 i32 i64)
            local.get 0 local.get 1 local.get 2 local.get 3 call $header)
        (func (export "report") (param i32 i64 i64)
            local.get 0 local.get 1 local.get 2 call $fail)
        (func (export "fill") (param i32 i32 i32)
            local.get 0 local.get 2 local.get 1 memory.fill)
        (func (export "read") (param i32) (result i32) local.get 0 i32.load8_u)
        (func (export "write") (param i32 i32) local.get 0 local.get 1 i32.store8)
        (func (export "pages") (result i32) memory.size)
        (func (export "spin") (loop br 0)))"#,
    )
    .unwrap();
    component.section(&RawSection { id: 1, data: &core });
    let mut instances = InstanceSection::new();
    instances.instantiate(
        1,
        [
            ("support", ModuleArg::Instance(1)),
            ("failure", ModuleArg::Instance(0)),
        ],
    );
    component.section(&instances);
    let signatures: &[(&str, &[T], Option<T>)] = &[
        ("alloc", &[T::U32; 4], Some(T::U32)),
        ("range", &[T::U32; 3], None),
        ("header", &[T::U32, T::U32, T::U32, T::U64], None),
        ("report", &[T::U32, T::U64, T::U64], None),
        ("fill", &[T::U32; 3], None),
        ("read", &[T::U32], Some(T::U32)),
        ("write", &[T::U32; 2], None),
        ("pages", &[], Some(T::U32)),
        ("spin", &[], None),
    ];
    for (i, (name, params, result)) in signatures.iter().enumerate() {
        let mut aliases = ComponentAliasSection::new();
        aliases.alias(Alias::CoreInstanceExport {
            instance: 2,
            kind: ExportKind::Func,
            name,
        });
        component.section(&aliases);
        let mut types = ComponentTypeSection::new();
        let names: Vec<_> = (0..params.len()).map(|n| format!("p{n}")).collect();
        types
            .function()
            .params(names.iter().zip(*params).map(|(n, t)| (n.as_str(), *t)))
            .result(result.map(Into::into));
        component.section(&types);
        let mut canonical = CanonicalFunctionSection::new();
        canonical.lift(i as u32 + 1, i as u32 + 1, []);
        component.section(&canonical);
        let mut exports = ComponentExportSection::new();
        exports.export(*name, ComponentExportKind::Func, i as u32 * 2 + 1, None);
        component.section(&exports);
    }
    let engine = Engine::new(&crate::external::engine_config()).unwrap();
    let component = Component::from_binary(&engine, &component.finish()).unwrap();
    (engine, component)
}

fn instantiate<T: 'static>(
    engine: &Engine,
    component: &Component,
    store: &mut Store<T>,
) -> Instance {
    store.set_fuel(1_000_000).unwrap();
    store.set_epoch_deadline(1);
    let mut linker = Linker::new(engine);
    link_failure(&mut linker).unwrap();
    linker.instantiate(&mut *store, component).unwrap()
}

#[test]
fn repeated_allocations_keep_headers_aligned_on_the_same_instance() {
    // 関門: 要求の整列が 1 でも転送ヘッダの整列 8 を守る。新しい Store だけの試験では
    // 最初の確保位置が偶然整列しているため、端数の確保に続く呼び出しの退行を捕まえない。
    let (engine, component) = fixture(1);
    let mut store = Store::new(&engine, ());
    let instance = instantiate(&engine, &component, &mut store);
    let alloc = instance
        .get_typed_func::<(u32, u32, u32, u32), (u32,)>(&mut store, "alloc")
        .unwrap();
    let write = instance
        .get_typed_func::<(u32, u32), ()>(&mut store, "write")
        .unwrap();
    let check = instance
        .get_typed_func::<(u32, u32, u32, u64), ()>(&mut store, "header")
        .unwrap();
    let bytes: [u8; 33] = [
        0x42, 0x4e, 0x54, 0x57, 1, 0, 0, 0, 33, 0, 0, 0, 1, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 64,
        0, 0, 0, 0, 0, 0, 0, 42,
    ];
    for expected in [8, 48] {
        let (pointer,) = alloc.call(&mut store, (0, 0, 1, 33)).unwrap();
        assert_eq!(pointer, expected);
        for (offset, byte) in bytes.iter().enumerate() {
            write
                .call(&mut store, (pointer + offset as u32, u32::from(*byte)))
                .unwrap();
        }
        check.call(&mut store, (pointer, 33, 1, 64)).unwrap();
    }
}

fn failure(error: &wasmtime::Error, expected: AdapterFailure, class: FailureClass) {
    let report = reported_failure(error).expect("typed adapter failure");
    assert_eq!(*report, expected);
    assert_eq!(report.class(), class);
}

#[test]
fn realloc_aligns_preserves_bytes_reuses_shrinks_and_checks_growth() {
    // 関門: 本物の補助の入口で整列・コピー・境界を守る。既存のホスト復号は realloc を呼ばない。
    // 独立したコアで書いて読み、コピー漏れ・端数ページの切り捨て・零長の余計な確保を捕まえる。
    let (engine, component) = fixture(2);
    let mut store = Store::new(&engine, ());
    let instance = instantiate(&engine, &component, &mut store);
    let alloc = instance
        .get_typed_func::<(u32, u32, u32, u32), (u32,)>(&mut store, "alloc")
        .unwrap();
    let fill = instance
        .get_typed_func::<(u32, u32, u32), ()>(&mut store, "fill")
        .unwrap();
    let read = instance
        .get_typed_func::<(u32,), (u32,)>(&mut store, "read")
        .unwrap();
    let pages = instance
        .get_typed_func::<(), (u32,)>(&mut store, "pages")
        .unwrap();
    assert_eq!(alloc.call(&mut store, (0, 0, 8, 0)).unwrap(), (0,));
    let (old,) = alloc.call(&mut store, (0, 0, 1, 5)).unwrap();
    assert_eq!(old, 8);
    fill.call(&mut store, (old, 5, 0xa5)).unwrap();
    let (new,) = alloc.call(&mut store, (old, 5, 8, 7)).unwrap();
    assert_eq!(new, 16);
    for offset in 0..5 {
        assert_eq!(read.call(&mut store, (new + offset,)).unwrap(), (0xa5,));
    }
    for offset in 5..7 {
        assert_eq!(read.call(&mut store, (new + offset,)).unwrap(), (0,));
    }
    assert_eq!(alloc.call(&mut store, (new, 7, 8, 3)).unwrap(), (new,));
    assert_eq!(alloc.call(&mut store, (new, 3, 8, 0)).unwrap(), (0,));
    // 次の位置は 24。最初のページの末尾と、その一バイト先を実際に確保する。
    let (edge,) = alloc.call(&mut store, (0, 0, 8, 65_512)).unwrap();
    assert_eq!(edge, 24);
    assert_eq!(pages.call(&mut store, ()).unwrap(), (1,));
    let (next,) = alloc.call(&mut store, (0, 0, 1, 1)).unwrap();
    assert_eq!(next, 65_536);
    assert_eq!(pages.call(&mut store, ()).unwrap(), (2,));
    assert_eq!(
        alloc.call(&mut store, (0, 0, 1, 65_528)).unwrap(),
        (65_544,)
    );
    let error = alloc.call(&mut store, (0, 0, 1, 1)).unwrap_err();
    failure(
        &error,
        AdapterFailure {
            number: 6,
            requested: 131_073,
            limit: 131_072,
        },
        FailureClass::Resource,
    );
}

#[test]
fn invalid_alignment_ranges_and_memory32_addition_stop_with_typed_reports() {
    // 関門: 各失敗の後も新しい Store で呼び、トラップしたインスタンスの状態に依存しない。
    let (engine, component) = fixture(1);
    for (ptr, len, align, requested, limit) in [
        (0, 0, 0, 0, 0),
        (0, 0, 3, 0, 3),
        (9, 1, 8, 9, 8),
        (65_535, 2, 1, 65_537, 65_536),
        (u32::MAX, 1, 1, 4_294_967_296, u64::from(u32::MAX)),
    ] {
        let mut store = Store::new(&engine, ());
        let instance = instantiate(&engine, &component, &mut store);
        let range = instance
            .get_typed_func::<(u32, u32, u32), ()>(&mut store, "range")
            .unwrap();
        let error = range.call(&mut store, (ptr, len, align)).unwrap_err();
        failure(
            &error,
            AdapterFailure {
                number: 7,
                requested,
                limit,
            },
            FailureClass::Internal,
        );
    }
    for (old, old_size, align, size, number, requested, limit) in [
        (0, 1, 1, 1, 7, 1, 0),
        (0, 0, 8, u32::MAX, 6, 4_294_967_303, u64::from(u32::MAX)),
        (0, 0, 1, 65_529, 6, 65_537, 65_536),
        (65_535, 2, 1, 0, 7, 65_537, 65_536),
    ] {
        let mut store = Store::new(&engine, ());
        let instance = instantiate(&engine, &component, &mut store);
        let alloc = instance
            .get_typed_func::<(u32, u32, u32, u32), (u32,)>(&mut store, "alloc")
            .unwrap();
        let error = alloc
            .call(&mut store, (old, old_size, align, size))
            .unwrap_err();
        failure(
            &error,
            AdapterFailure {
                number,
                requested,
                limit,
            },
            if number == 6 {
                FailureClass::Resource
            } else {
                FailureClass::Internal
            },
        );
    }
}

#[test]
fn known_and_unknown_failure_numbers_and_unsigned_quantities_cross_component_boundary() {
    // 関門: 固定の取り込みを実際に canon lower して呼び、型の消失と番号の再割り当てを捕まえる。
    // 既存の外部のトラップのテストは、この取り込みも専用の原因の型も持たない。
    let (engine, component) = fixture(1);
    for (number, class) in [
        (1, FailureClass::Resource),
        (2, FailureClass::Resource),
        (3, FailureClass::Resource),
        (4, FailureClass::Resource),
        (5, FailureClass::ValueSize),
        (6, FailureClass::Resource),
        (7, FailureClass::Internal),
        (0, FailureClass::Internal),
        (u32::MAX, FailureClass::Internal),
    ] {
        let mut store = Store::new(&engine, ());
        let instance = instantiate(&engine, &component, &mut store);
        let report = instance
            .get_typed_func::<(u32, u64, u64), ()>(&mut store, "report")
            .unwrap();
        let error = report
            .call(&mut store, (number, u64::MAX, 0x8000_0000_0000_0001))
            .unwrap_err();
        failure(
            &error,
            AdapterFailure {
                number,
                requested: u64::MAX,
                limit: 0x8000_0000_0000_0001,
            },
            class,
        );
    }
}

#[test]
fn header_checks_version_length_roots_budgets_and_transfer_before_reading_payload() {
    // 関門: ヘッダは手で書いた独立したバイト列を使う。ホストの writer との往復にしない。
    let (engine, component) = fixture(1);
    let header: [u8; 32] = [
        0x42, 0x4e, 0x54, 0x57, 1, 0, 0, 0, 32, 0, 0, 0, 2, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 32,
        0, 0, 0, 0, 0, 0, 0,
    ];
    let mut variants = vec![(header.to_vec(), 32, 2, 32, None)];
    for offset in [0, 4, 8, 12, 16, 23, 24, 31] {
        let mut bytes = header.to_vec();
        bytes[offset] ^= 1;
        variants.push((bytes, 32, 2, 32, Some(7)));
    }
    variants.push((header.to_vec(), 31, 2, 32, Some(7)));
    variants.push((header.to_vec(), 32, 3, 32, Some(7)));
    variants.push((header.to_vec(), 32, 2, 33, Some(7)));
    let mut limited = header.to_vec();
    limited[16] = 31;
    limited[24] = 31;
    variants.push((limited, 32, 2, 31, Some(1)));
    for (bytes, length, roots, budget, code) in variants {
        let mut store = Store::new(&engine, ());
        let instance = instantiate(&engine, &component, &mut store);
        let write = instance
            .get_typed_func::<(u32, u32), ()>(&mut store, "write")
            .unwrap();
        for (offset, byte) in bytes.iter().enumerate() {
            write
                .call(&mut store, (8 + offset as u32, u32::from(*byte)))
                .unwrap();
        }
        let check = instance
            .get_typed_func::<(u32, u32, u32, u64), ()>(&mut store, "header")
            .unwrap();
        let result = check.call(&mut store, (8, length, roots, budget));
        if let Some(code) = code {
            let error = result.unwrap_err();
            let report = reported_failure(&error).unwrap();
            assert_eq!(report.number, code);
            if code == 1 {
                assert_eq!((report.requested, report.limit), (32, 31));
            }
        } else {
            result.unwrap();
        }
    }
    for (ptr, length) in [(9, 32), (65_512, 32), (u32::MAX - 7, 32)] {
        let mut store = Store::new(&engine, ());
        let instance = instantiate(&engine, &component, &mut store);
        let check = instance
            .get_typed_func::<(u32, u32, u32, u64), ()>(&mut store, "header")
            .unwrap();
        let error = check.call(&mut store, (ptr, length, 2, 32)).unwrap_err();
        assert_eq!(reported_failure(&error).unwrap().number, 7);
    }
}

#[test]
fn fuel_interrupt_and_store_limiter_failures_take_priority_over_adapter_reports() {
    // 関門: 補助の実行も同じ燃料・epoch・Store の制限で止まることを確かめる。
    let (engine, component) = fixture(2);
    for interrupt in [false, true] {
        let mut store = Store::new(&engine, ());
        let instance = instantiate(&engine, &component, &mut store);
        if interrupt {
            store.set_epoch_deadline(0);
        } else {
            store.set_fuel(50).unwrap();
        }
        let spin = instance
            .get_typed_func::<(), ()>(&mut store, "spin")
            .unwrap();
        let error = spin.call(&mut store, ()).unwrap_err();
        assert_eq!(
            error.downcast_ref::<wasmtime::Trap>(),
            Some(if interrupt {
                &wasmtime::Trap::Interrupt
            } else {
                &wasmtime::Trap::OutOfFuel
            })
        );
        assert!(reported_failure(&error).is_none());
        // 複数の原因を持つ場合にも、既存の停止を補助の報告で隠さない。
        let mixed = wasmtime::Error::new(AdapterFailure {
            number: 7,
            requested: 0,
            limit: 0,
        })
        .context(*error.downcast_ref::<wasmtime::Trap>().unwrap());
        assert!(reported_failure(&mixed).is_none());
    }
    let mut store = Store::new(&engine, Limited);
    store.limiter(|state| state);
    let instance = instantiate(&engine, &component, &mut store);
    let alloc = instance
        .get_typed_func::<(u32, u32, u32, u32), (u32,)>(&mut store, "alloc")
        .unwrap();
    let error = alloc.call(&mut store, (0, 0, 1, 65_529)).unwrap_err();
    assert!(error.downcast_ref::<DeniedGrowth>().is_some());
    assert!(reported_failure(&error).is_none());

    // 文言だけを似せた外側の説明で、内側の型付きの報告を隠してはならない。
    for message in [
        crate::external::text::HOSTCALL_FUEL_EXHAUSTED,
        "resource limit exceeded: instance count too high at 17",
    ] {
        let report = AdapterFailure {
            number: 7,
            requested: 0,
            limit: 0,
        };
        let wrapped = wasmtime::Error::new(report).context(message);
        assert_eq!(reported_failure(&wrapped), Some(&report));
    }
}

#[derive(Debug)]
struct DeniedGrowth;
impl std::fmt::Display for DeniedGrowth {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("denied test growth")
    }
}
impl std::error::Error for DeniedGrowth {}
struct Limited;
impl wasmtime::ResourceLimiter for Limited {
    fn memory_growing(
        &mut self,
        _current: usize,
        desired: usize,
        _maximum: Option<usize>,
    ) -> wasmtime::Result<bool> {
        if desired > 65_536 {
            Err(wasmtime::Error::new(DeniedGrowth))
        } else {
            Ok(true)
        }
    }
    fn table_growing(
        &mut self,
        _current: usize,
        _desired: usize,
        _maximum: Option<usize>,
    ) -> wasmtime::Result<bool> {
        Ok(true)
    }
}
