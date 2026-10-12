//! 内部層の入口で確保器の不変条件を検査する（設計書 07-03「テストの設計の原則」）。
//! H1・H2・H9・H12 と O1〜O6、A1〜A3、L1〜L2 を内容・集合・計数で確かめる。
//! T1: 毒を読むテストは塊の小さな対象だけを扱い、塊の所有者を生かしたまま読む。

// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。内部層の毒の検査だけ生の領域を読む。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::trace::{Trace, Tracer};
use super::alloc::{ALIGN, SIZE_CLASSES};
use super::layout::{BOX_BYTES, CELL_BYTES, DECIMAL_BYTES, FIELD_BYTES};
use super::*;
use std::cell::Cell;
use std::collections::BTreeSet;
use std::rc::Rc;

// 作成時の関門: H12 に反する対象を借りたとき、heap-verify が不具合を記録する契約を守る。
// 正常な作成経路の既存テストでは検査の欠落を捕まえられない。内部層の入口で確かめ、注入口は加えない。
#[cfg(feature = "heap-verify")]
#[test]
fn invalid_string_utf8_records_corrupt_header() {
    let mut core = HeapCore::new(HeapConfig::default());
    let value = core
        .alloc_byte_data(Epoch::new(), ObjKind::Str, &[0xff, 0xc0])
        .unwrap();
    assert_eq!(core.str(value), None);
    assert_eq!(
        core.take_fault().unwrap().kind,
        HeapFaultKind::CorruptHeader
    );
}

// 関門: 識別を読むときも O1 の添字と対象の記録が一致しなければ不具合を残す。
// 正常な確保と解放のテストでは検査漏れを捕まえない。内部層の入口で頭を一時的に壊し、注入口は加えない。
#[cfg(feature = "heap-verify")]
#[test]
fn object_id_records_corrupt_header_when_allocation_metadata_differs() {
    // 別の対象の記録を指す場合と、記録の範囲外を指す場合を確かめる。
    for invalid_index in [1, u32::MAX] {
        let mut core = HeapCore::new(HeapConfig::default());
        let value = core.alloc_str(Epoch::new(), "first").unwrap();
        core.alloc_str(Epoch::new(), "second").unwrap();
        core.header(value).unwrap().index.set(invalid_index);
        let identity = core.object_id(value);
        // 表明が失敗しても、捨てる処理が正しい添字で対象を解放できるように戻す。
        core.header(value).unwrap().index.set(0);
        assert_eq!(identity, None);
        let fault = core.take_fault().unwrap();
        assert_eq!(fault.kind, HeapFaultKind::CorruptHeader);
        assert_eq!(
            fault.detail,
            "object header differs from allocation metadata"
        );
    }
}

// 作成時の関門: 既存のヒープのテストはない。下の各テストはこの入口の独立した契約を守る。
// 誤った配置・別名への書き込み・二重解放・世代の取り違え・計数漏れを捕まえ、公開 API の拡張や注入口は要しない。

#[derive(Debug)]
struct Dropped(Rc<Cell<usize>>);
impl Drop for Dropped {
    fn drop(&mut self) {
        self.0.set(self.0.get() + 1);
    }
}
impl OpaqueData for Dropped {}
impl HostData for Dropped {}
impl Trace for Dropped {
    fn trace(&self, _t: &mut Tracer<'_>) {}
}

#[test]
fn object_kinds_headers_and_payloads() {
    let core = HeapCore::new(HeapConfig::default());
    let epoch = Epoch::new();
    let dropped = Rc::new(Cell::new(0));
    let decimal = Decimal::new(-123, 2).unwrap();
    let cases = [
        (core.alloc_str(epoch, "").unwrap(), ObjKind::Str, 0, 0),
        (core.alloc_str(epoch, "日本語").unwrap(), ObjKind::Str, 9, 0),
        (core.alloc_bytes(epoch, &[]).unwrap(), ObjKind::Bytes, 0, 0),
        (
            core.alloc_bytes(epoch, &[0, 255, 1]).unwrap(),
            ObjKind::Bytes,
            3,
            0,
        ),
        (
            core.alloc_decimal(epoch, decimal).unwrap(),
            ObjKind::Decimal,
            1,
            0,
        ),
        (
            core.alloc_cell(epoch, Value::Int(-7)).unwrap(),
            ObjKind::Cell,
            1,
            0,
        ),
        (
            core.alloc_opaque(epoch, Dropped(Rc::clone(&dropped)))
                .unwrap(),
            ObjKind::Opaque,
            1,
            0,
        ),
        (
            core.alloc_host(epoch, Dropped(Rc::clone(&dropped)))
                .unwrap(),
            ObjKind::Host,
            1,
            0,
        ),
    ];
    for (value, kind, len, tag) in cases {
        assert_eq!(core.kind(value), Some(kind));
        assert_eq!(core.len(value), Some(len));
        assert_eq!(core.tag(value), Some(tag));
        assert_eq!(value.as_obj().unwrap().ptr().addr().get() % ALIGN, 0);
        assert_eq!(core.word(value).unwrap().get(), 0);
    }
    assert_eq!(core.str(cases[0].0), Some(""));
    assert_eq!(core.str(cases[1].0), Some("日本語"));
    assert_eq!(core.bytes(cases[2].0), Some([].as_slice()));
    assert_eq!(core.bytes(cases[3].0), Some([0, 255, 1].as_slice()));
    assert!(core.decimal(cases[4].0).unwrap().same_repr(decimal));
    assert_eq!(
        core.cell(cases[5].0).unwrap().value.get().as_int(),
        Some(-7)
    );
    assert_eq!(core.cell(cases[5].0).unwrap().version.get(), 0);
    assert!(core.opaque::<Dropped>(cases[6].0).is_some());
    assert!(core.host::<Dropped>(cases[7].0).is_some());
    assert!(core.str(cases[3].0).is_none());
    assert!(core.opaque::<Dropped>(cases[7].0).is_none());

    let kinds = [
        FieldsKind::Ctor,
        FieldsKind::Func,
        FieldsKind::Dict,
        FieldsKind::ListNode,
        FieldsKind::MapNode,
        FieldsKind::SetNode,
        FieldsKind::IoError,
        FieldsKind::NetworkError,
    ];
    for kind in kinds {
        for items in [&[][..], &[Value::Int(i64::MIN), cases[1].0][..]] {
            let value = core.alloc_fields(epoch, kind, u32::MAX, items).unwrap();
            assert_eq!(core.kind(value), Some(ObjKind::Fields(kind)));
            assert_eq!(core.fields_header(value), Some((kind, u32::MAX)));
            assert_eq!(core.len(value), Some(u32::try_from(items.len()).unwrap()));
            if !items.is_empty() {
                assert_eq!(
                    core.field(epoch, value, 0).unwrap().as_int(),
                    Some(i64::MIN)
                );
                assert!(core.same_object(core.field(epoch, value, 1).unwrap(), cases[1].0));
            }
            assert!(
                core.field(epoch, value, u32::try_from(items.len()).unwrap())
                    .is_none()
            );
            assert!(core.field(epoch, value, u32::MAX).is_none());
        }
    }
    assert_eq!(HEADER_BYTES, 32);
    assert_eq!(DECIMAL_BYTES, 32);
    assert_eq!(BOX_BYTES, 16);
    #[cfg(not(feature = "heap-verify"))]
    {
        assert_eq!(FIELD_BYTES, 16);
        assert_eq!(CELL_BYTES, 24);
    }
    #[cfg(feature = "heap-verify")]
    {
        assert_eq!(FIELD_BYTES, 24);
        assert_eq!(CELL_BYTES, 32);
    }
}

#[test]
fn identity_and_immediates() {
    let mut core = HeapCore::new(HeapConfig::default());
    let epoch = Epoch::new();
    let a = core.alloc_str(epoch, "same").unwrap();
    let b = core.alloc_str(epoch, "same").unwrap();
    assert!(core.same_object(a, a));
    assert!(!core.same_object(a, b));
    assert_ne!(core.object_id(a), core.object_id(b));
    let a_id = core.object_id(a).unwrap();
    let b_id = core.object_id(b).unwrap();
    let a_ptr = a.as_obj().unwrap().ptr();
    let b_slot = core.slot_new_slot(b);
    let immediates = [
        Value::Int(3),
        Value::Float(1.5),
        Value::Byte(2),
        Value::Bool(true),
        Value::Char('字'),
        Value::Unit,
        Value::Tag(super::super::value::CtorTag(0)),
        Value::Resource(super::super::value::ResourceId(8)),
        Value::EmptyList,
        Value::EmptyMap,
        Value::EmptySet,
    ];
    for value in immediates {
        assert_eq!(core.kind(value), None);
        assert_eq!(core.object_id(value), None);
        assert!(!core.same_object(value, value));
        assert!(!core.same_object(a, value));
        assert!(!core.same_object(value, a));
    }
    // 空き領域を再利用しても、確保ごとの識別を引き継がない（設計書 02-09「メモリの管理」）。
    core.free_object(a_ptr).unwrap();
    let replacement = core.alloc_str(Epoch::new(), "same").unwrap();
    #[cfg(not(feature = "heap-per-object"))]
    assert_eq!(replacement.as_obj().unwrap().ptr(), a_ptr);
    assert_ne!(core.object_id(replacement), Some(a_id));
    // 解放で並びの位置が変わった対象も、元の識別を保つ。
    let b = core.slot_load(&b_slot, Epoch::new());
    assert_eq!(core.object_id(b), Some(b_id));
    assert_eq!(
        core.object_ids().into_iter().collect::<BTreeSet<_>>(),
        [b_id, core.object_id(replacement).unwrap()]
            .into_iter()
            .collect()
    );
    assert!(core.fault.borrow().is_none());
}

#[test]
fn size_class_boundaries_preserve_contents_and_existing_borrows() {
    let core = HeapCore::new(HeapConfig::default());
    let epoch = Epoch::new();
    let retained = core.alloc_str(epoch, "保持する借用").unwrap();
    let borrowed = core.str(retained).unwrap();
    let mut cases = Vec::new();
    for capacity in SIZE_CLASSES {
        for total in [capacity, capacity + 1] {
            let bytes = vec![u8::try_from(total % 251).unwrap(); total - HEADER_BYTES];
            let value = core.alloc_bytes(epoch, &bytes).unwrap();
            cases.push((value, bytes));
        }
    }
    // 大きな対象の境目の前後と塊の大きさを超える対象も同じ入口で扱う。
    for total in [4095, 4096, 4097, 65_535, 65_536, 65_537] {
        let bytes = vec![137; total - HEADER_BYTES];
        cases.push((core.alloc_bytes(epoch, &bytes).unwrap(), bytes));
    }
    for (value, bytes) in &cases {
        assert_eq!(core.bytes(*value), Some(bytes.as_slice()));
    }
    assert_eq!(borrowed, "保持する借用");
    assert_eq!(core.str(retained), Some(borrowed));
}

#[test]
fn free_reuse_and_exact_accounting() {
    let mut core = HeapCore::new(HeapConfig::default());
    let mut addresses = Vec::new();
    let count = if cfg!(miri) { 20 } else { 500 };
    let mut expected_bytes = 0;
    for _ in 0..count {
        let before = core.stats();
        let object = {
            let value = core.alloc_bytes(Epoch::new(), &[5; 32]).unwrap();
            assert_eq!(core.bytes(value), Some([5; 32].as_slice()));
            value.as_obj().unwrap().ptr()
        };
        expected_bytes += 64;
        assert_eq!(core.stats().allocations, before.allocations + 1);
        assert_eq!(core.stats().allocated_bytes, expected_bytes);
        assert_eq!(core.current_bytes(), 64);
        core.free_object(object).unwrap();
        assert_eq!(core.stats().frees, before.frees + 1);
        assert_eq!(core.current_bytes(), 0);
        assert!(core.object_ids().is_empty());
        addresses.push(object);
    }
    // 個別の確保では番地の再利用を Rust の確保器に委ねる。塊では空き領域の再利用が契約である。
    #[cfg(not(feature = "heap-per-object"))]
    assert!(addresses.iter().all(|id| *id == addresses[0]));
    assert_eq!(core.stats().peak_heap_bytes, 64);
    assert!(matches!(
        core.free_object(addresses[0]),
        Err(Stop::Internal(_))
    ));
    assert_eq!(core.stats().frees, count);
}

// 関門: 内部層の計上と解放の不変条件を守る。既存の型は別領域の容量を返さないため、
// 容量の加算漏れと Host の数え直し漏れを捕まえない。差し込み口は加えない。
#[derive(Debug)]
struct OwnedBytes(Vec<u8>);
impl OpaqueData for OwnedBytes {
    fn heap_bytes(&self) -> usize {
        self.0.capacity()
    }
}
impl HostData for OwnedBytes {
    fn heap_bytes(&self) -> usize {
        self.0.capacity()
    }
}
impl Trace for OwnedBytes {
    fn trace(&self, _t: &mut Tracer<'_>) {}
}

#[test]
fn opaque_owned_capacity_is_charged_and_removed_on_free() {
    let mut core = HeapCore::new(HeapConfig::default());
    let anchor = core
        .alloc_str(Epoch::new(), "anchor")
        .unwrap()
        .as_obj()
        .unwrap()
        .ptr();
    let before = core.current_bytes();
    let empty = core
        .alloc_opaque(Epoch::new(), OwnedBytes(Vec::new()))
        .unwrap()
        .as_obj()
        .unwrap()
        .ptr();
    let base = core.current_bytes() - before;
    core.free_object(empty).unwrap();
    let bytes = Vec::with_capacity(4096);
    let capacity = u64::try_from(bytes.capacity()).unwrap();
    let ptr = {
        let value = core.alloc_opaque(Epoch::new(), OwnedBytes(bytes)).unwrap();
        let index = usize::try_from(core.header(value).unwrap().index.get()).unwrap();
        assert_eq!(core.objects.borrow()[index].charged_bytes, base + capacity);
        assert_eq!(core.current_bytes(), before + base + capacity);
        value.as_obj().unwrap().ptr()
    };
    core.free_object(ptr).unwrap();
    assert_eq!(core.current_bytes(), before);
    core.free_object(anchor).unwrap();
    assert_eq!(core.current_bytes(), 0);
}

#[test]
fn host_owned_capacity_tracks_growth_and_shrinkage_until_free() {
    let mut core = HeapCore::new(HeapConfig::default());
    let empty = core
        .alloc_host(Epoch::new(), OwnedBytes(Vec::new()))
        .unwrap()
        .as_obj()
        .unwrap()
        .ptr();
    let base = core.current_bytes();
    core.free_object(empty).unwrap();
    let ptr = {
        let bytes = Vec::with_capacity(64);
        let initial = u64::try_from(bytes.capacity()).unwrap();
        let value = core.alloc_host(Epoch::new(), OwnedBytes(bytes)).unwrap();
        let index = usize::try_from(core.header(value).unwrap().index.get()).unwrap();
        assert_eq!(core.objects.borrow()[index].charged_bytes, base + initial);
        assert_eq!(core.current_bytes(), base + initial);
        let mut allocated = core.stats().allocated_bytes;
        let mut previous = initial;
        let mut peak = base + initial;
        for size in [128, 512, 64, 64, 0] {
            let capacity = core
                .with_host_mut(value, |data: &mut OwnedBytes| {
                    data.0 = Vec::with_capacity(size);
                    u64::try_from(data.0.capacity()).unwrap()
                })
                .unwrap();
            allocated += capacity.saturating_sub(previous);
            peak = peak.max(base + capacity);
            assert_eq!(core.objects.borrow()[index].charged_bytes, base + capacity);
            assert_eq!(core.current_bytes(), base + capacity);
            assert_eq!(core.stats().allocated_bytes, allocated);
            assert_eq!(core.stats().peak_heap_bytes, peak);
            assert_eq!(core.verify(&super::super::RootStack::new()), Ok(()));
            previous = capacity;
        }
        value.as_obj().unwrap().ptr()
    };
    core.free_object(ptr).unwrap();
    assert_eq!(core.current_bytes(), 0);
    assert!(core.take_fault().is_none());
}

// 関門: 対象ごとの記録と全体の量の一致を検証する契約を守る。正常な増減の検査だけでは、
// 検証器自身の検査漏れは見えない。既存の内部層の記録を壊し、公開範囲は広げない。
#[cfg(feature = "heap-verify")]
#[test]
fn verification_rejects_charged_bytes_that_differ_from_the_heap_total() {
    let core = HeapCore::new(HeapConfig::default());
    core.alloc_str(Epoch::new(), "test").unwrap();
    core.objects.borrow_mut()[0].charged_bytes += 1;
    let fault = core.verify(&super::super::RootStack::new()).unwrap_err();
    assert_eq!(fault.kind, HeapFaultKind::CorruptHeader);
    assert_eq!(
        fault.detail,
        "charged bytes of live objects differ from the current heap bytes"
    );
}

#[test]
fn heap_numbers_are_unique_across_simultaneous_and_recreated_heaps() {
    let first = HeapCore::new(HeapConfig::default());
    let old = first.heap_no();
    let second = HeapCore::new(HeapConfig::default());
    assert_ne!(old, second.heap_no());
    drop(first);
    let replacement = HeapCore::new(HeapConfig::default());
    assert_ne!(old, replacement.heap_no());
    assert_ne!(second.heap_no(), replacement.heap_no());
}

#[test]
fn live_enumeration_matches_an_independent_set() {
    let mut core = HeapCore::new(HeapConfig::default());
    let mut expected = BTreeSet::new();
    let mut handles = Vec::new();
    for i in 0..100 {
        let (id, object) = {
            let bytes = vec![7; i * 71];
            let value = core.alloc_bytes(Epoch::new(), &bytes).unwrap();
            (
                core.object_id(value).unwrap(),
                value.as_obj().unwrap().ptr(),
            )
        };
        expected.insert(id);
        if i % 3 == 0 {
            core.free_object(object).unwrap();
            expected.remove(&id);
        } else {
            handles.push(object);
        }
        assert_eq!(
            core.object_ids().into_iter().collect::<BTreeSet<_>>(),
            expected
        );
    }
    for object in handles {
        core.free_object(object).unwrap();
    }
    assert!(core.object_ids().is_empty());
}

#[test]
fn rust_payloads_drop_once_on_free_and_heap_drop() {
    let counter = Rc::new(Cell::new(0));
    let mut core = HeapCore::new(HeapConfig::default());
    let objects = {
        let a = core
            .alloc_opaque(Epoch::new(), Dropped(Rc::clone(&counter)))
            .unwrap();
        let b = core
            .alloc_host(Epoch::new(), Dropped(Rc::clone(&counter)))
            .unwrap();
        [a.as_obj().unwrap().ptr(), b.as_obj().unwrap().ptr()]
    };
    assert_eq!(counter.get(), 0);
    for (i, object) in objects.into_iter().enumerate() {
        core.free_object(object).unwrap();
        assert_eq!(counter.get(), i + 1);
        assert!(core.free_object(object).is_err());
        assert_eq!(counter.get(), i + 1);
    }
    core.alloc_opaque(Epoch::new(), Dropped(Rc::clone(&counter)))
        .unwrap();
    core.alloc_host(Epoch::new(), Dropped(Rc::clone(&counter)))
        .unwrap();
    assert!(
        core.current_bytes()
            >= 2 * (u64::try_from(HEADER_BYTES + BOX_BYTES + std::mem::size_of::<Dropped>())
                .unwrap())
    );
    drop(core);
    assert_eq!(counter.get(), 4);
}

// 対象ごとの確保は解放時に領域を返すので毒を読めない。塊と検証機能の組み合わせだけで読む（T1）。
#[cfg(all(feature = "heap-verify", not(feature = "heap-per-object")))]
#[test]
fn freed_slab_payload_is_poisoned_and_generation_advances() {
    let mut core = HeapCore::new(HeapConfig::default());
    let (id, allocation, layout, generation) = {
        let value = core.alloc_bytes(Epoch::new(), &[23; 11]).unwrap();
        let id = core.object_id(value).unwrap();
        let object = core.objects.borrow();
        let record = object
            .iter()
            .find(|record| {
                record.allocation.ptr.cast::<ObjHeader>() == value.as_obj().unwrap().ptr()
            })
            .unwrap();
        (
            id,
            record.allocation,
            ObjectLayout::new(ObjKind::Bytes, 11, 0).unwrap(),
            value.as_obj().unwrap().generation(),
        )
    };
    core.free_object(allocation.ptr.cast::<ObjHeader>())
        .unwrap();
    let payload = layout.payload(allocation.ptr);
    // SAFETY: O4・A1・T1。小さい対象の塊は core が所有したままで、毒は全中身と切り上げを初期化済みである。
    let bytes = unsafe {
        std::slice::from_raw_parts(payload.as_ptr(), allocation.capacity - layout.offset)
    };
    assert!(bytes.iter().all(|byte| *byte == super::super::POISON_BYTE));
    // SAFETY: O4・A1・T1。塊の頭は返却せず初期化済みのままであり、世代だけを更新した。
    let header = unsafe { allocation.ptr.cast::<ObjHeader>().as_ref() };
    assert_eq!(header.generation.get(), generation + 1);
    let replacement = core.alloc_bytes(Epoch::new(), &[91; 11]).unwrap();
    assert_eq!(replacement.as_obj().unwrap().ptr(), allocation.ptr.cast());
    assert_ne!(core.object_id(replacement), Some(id));
    assert_ne!(replacement.as_obj().unwrap().generation(), generation);
    assert_eq!(core.bytes(replacement), Some([91; 11].as_slice()));
}

// 個別の確保では死んだ領域を読まずに世代を判定する必要がある。この構成でだけ表の生死を検査する（O5）。
#[cfg(all(feature = "heap-per-object", feature = "heap-verify"))]
#[test]
fn per_object_liveness_and_generation_survive_deallocation() {
    let mut core = HeapCore::new(HeapConfig::default());
    for _ in 0..40 {
        let (id, generation, raw) = {
            let value = core.alloc_bytes(Epoch::new(), &[1; 17]).unwrap();
            (
                core.object_id(value).unwrap(),
                value.as_obj().unwrap().generation(),
                retime(value, Epoch::<'static>::new()),
            )
        };
        let addr = raw.as_obj().unwrap().ptr().addr().get();
        assert_eq!(
            core.generations
                .borrow()
                .get(&addr)
                .map(|life| (life.generation, life.alive)),
            Some((generation, true))
        );
        core.free_object(raw.as_obj().unwrap().ptr()).unwrap();
        assert_eq!(
            core.generations
                .borrow()
                .get(&addr)
                .map(|life| (life.generation, life.alive)),
            Some((generation + 1, false))
        );
        assert!(!core.object_ids().contains(&id));
        // Slot が残した生の値と同じ状況を内部だけで作り、世代の確認が解放済みの頭を読まないことを Miri で確かめる。
        assert_eq!(core.kind(raw), None);
        assert_eq!(
            core.take_fault().unwrap().kind,
            HeapFaultKind::StaleReference
        );
    }
}

#[test]
fn many_small_and_mixed_objects_remain_nonmoving() {
    let mut core = HeapCore::new(HeapConfig::default());
    // Miri では混合する確保を四回含む規模に縮め、大量の確保は通常実行で調べる。
    let count = if cfg!(miri) { 64 } else { 1_000_000 };
    let mixed_interval = if cfg!(miri) { 16 } else { 256 };
    let mut objects = Vec::new();
    {
        let epoch = Epoch::new();
        let mut chain = Value::Unit;
        let mut mixed = Vec::new();
        for i in 0..count {
            chain = core
                .alloc_fields(epoch, FieldsKind::Ctor, 11, &[chain])
                .unwrap();
            objects.push(chain.as_obj().unwrap().ptr());
            if i % mixed_interval == 0 {
                let bytes = vec![u8::try_from(i % 251).unwrap(); 31 + i % 8192];
                let value = core.alloc_bytes(epoch, &bytes).unwrap();
                assert_eq!(core.bytes(value), Some(bytes.as_slice()));
                objects.push(value.as_obj().unwrap().ptr());
                mixed.push((value, bytes));
            }
        }
        for (value, bytes) in mixed {
            assert_eq!(core.bytes(value), Some(bytes.as_slice()));
        }
        // 深い対象の中身も再帰を使わず読み、確保を繰り返した後のポインタと値が保たれることを確かめる。
        for _ in 0..count {
            assert_eq!(core.fields_header(chain), Some((FieldsKind::Ctor, 11)));
            chain = core.field(epoch, chain, 0).unwrap();
        }
        assert!(matches!(chain, Value::Unit));
        assert_eq!(core.object_ids().len(), objects.len());
        assert_eq!(
            core.stats().allocations,
            u64::try_from(objects.len()).unwrap()
        );
    }
    for object in objects {
        core.free_object(object).unwrap();
    }
    assert_eq!(core.stats().allocations, core.stats().frees);
    assert_eq!(core.current_bytes(), 0);
    assert!(core.object_ids().is_empty());
}

#[test]
fn overflowing_layouts_fail_before_allocating() {
    let core = HeapCore::new(HeapConfig::default());
    for kind in [
        ObjKind::Bytes,
        ObjKind::Str,
        ObjKind::Fields(FieldsKind::Ctor),
    ] {
        for len in [u32::MAX - 1, u32::MAX] {
            assert!(matches!(
                ObjectLayout::new(kind, len, 0),
                Err(Stop::Internal(_))
            ));
        }
    }
    assert_eq!(core.stats(), HeapStats::default());
    assert!(core.object_ids().is_empty());
    assert!(
        Allocator::capacity(
            std::alloc::Layout::from_size_align(usize::try_from(isize::MAX).unwrap(), 1).unwrap()
        )
        .is_err()
    );
}
