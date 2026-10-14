//! flags と map の補助を手書きゲストで実行し、幅・構築量・正規化を確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::codec::{CodecError, CodecPlan};
use super::fixed_tests::{MEMORY, call, compile, core_call, input};
use super::runtime::reported_failure;
use super::wire::WireError;
use crate::external::WitPlan as P;
use crate::runtime::heap::{CtorTag, Heap, HeapConfig, Value};
use crate::runtime::map;

fn flags(count: u32) -> P {
    P::Flags {
        // タグ順を WIT の宣言順と逆にし、項目の番号とタグを取り違える退行も捕まえる。
        cases: (0..count).map(|i| (format!("f{i}"), 100 - i)).collect(),
    }
}

#[test]
fn flags_width_boundaries_use_i32_and_charge_only_selected_items() {
    // 関門: 全幅の境界を本物の lower/lift で渡し、独立したゲストのビット演算を確かめる。
    // codec の試験だけでは生成した i32 の幅と popcount による確保前の計数を検査できない。
    for (count, width) in [(1, 1), (8, 1), (9, 2), (16, 2), (17, 4), (32, 4)] {
        let names = (0..count).map(|i| format!("\"f{i}\" ")).collect::<String>();
        let mask = 1_u32 << (count - 1);
        let guest = format!(
            r#"(component (core module $m
                (func (export "run") (param i32) (result i32)
                    local.get 0 i32.const {mask} i32.xor))
                (core instance $i (instantiate $m))
                (type $f0 (flags {names})) (export $f "flags-type" (type $f0))
                (func (export "run") (param "x" $f) (result $f)
                    (canon lift (core func $i "run"))))"#
        );
        let plans = [flags(count)];
        let (engine, component) = compile(&guest, &plans, &plans);
        let codec = CodecPlan::new(&plans, &mut 100_000).unwrap();
        for bits in [0, mask] {
            let source = &bits.to_le_bytes()[..width];
            let expected = &((bits ^ mask).to_le_bytes())[..width];
            let limit = (32 + width) as u64;
            let result = call(&engine, &component, &input(source, 1, limit)).unwrap();
            assert_eq!(result, input(expected, 1, limit));
            let mut heap = Heap::new(HeapConfig::default());
            heap.epoch(|ctx| {
                let decoded = codec.decode(ctx, &result, limit).unwrap();
                assert_eq!(decoded.construction_bytes, if bits == 0 { 32 } else { 16 });
                let set = decoded.values[0];
                assert_eq!(
                    map::set_len(ctx, set).unwrap(),
                    if bits == 0 { 1 } else { 0 }
                );
                if bits == 0 {
                    assert!(map::set_contains(ctx, set, Value::Tag(CtorTag(101 - count))).unwrap());
                }
            });
        }
        if !matches!(count, 8 | 16 | 32) {
            let bad = (1_u32 << count).to_le_bytes();
            let err = call(&engine, &component, &input(&bad[..width], 1, 1024)).unwrap_err();
            assert_eq!(reported_failure(&err).unwrap().number, 7);
        }
        if count > 1 {
            let limit = 47;
            let err = call(
                &engine,
                &component,
                &input(&(mask | 1).to_le_bytes()[..width], 1, limit),
            )
            .unwrap_err();
            let report = reported_failure(&err).unwrap();
            assert_eq!(
                (report.number, report.requested, report.limit),
                (3, 48, limit)
            );
        }
    }
    // ゲストの返す全選択は、空選択の引数と異なる構築量で制限される。
    let guest = r#"(component (core module $m
        (func (export "run") (param i32) (result i32) i32.const 511))
        (core instance $i (instantiate $m))
        (type $f0 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
        (export $f "flags-type" (type $f0))
        (func (export "run") (param "x" $f) (result $f) (canon lift (core func $i "run"))))"#;
    let (engine, component) = compile(guest, &[flags(9)], &[flags(9)]);
    assert_eq!(
        call(&engine, &component, &input(&[0, 0], 1, 160)).unwrap(),
        input(&[255, 1], 1, 160)
    );
    let err = call(&engine, &component, &input(&[0, 0], 1, 159)).unwrap_err();
    let report = reported_failure(&err).unwrap();
    assert_eq!(
        (report.number, report.requested, report.limit),
        (4, 160, 159)
    );
}

#[test]
fn flags_unknown_result_bits_are_rejected_before_copying() {
    // 関門: canon lower の検査を経ない結果でも、補助自体が未知ビットを拒否する。
    // 幅の往復だけでは、結果の上位ビットを捨てて不正な形式を受理する退行を捕まえない。
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    let support = wasmtime::Module::from_binary(
        &engine,
        &super::emit::memory_module(1, None).unwrap().finish(),
    )
    .unwrap();
    for (count, width) in [(1, 1), (9, 2), (17, 4)] {
        // 二つの flags の tuple にして、結果をメモリで受け取る ABI を通す。
        let plans = [P::Tuple(vec![flags(count), flags(count)])];
        let adapter = wasmtime::Module::from_binary(
            &engine,
            &super::emit::fixed_module(&[], &plans).unwrap().finish(),
        )
        .unwrap();
        let bits = 1_u32 << count;
        let store = match width {
            1 => "i32.store8",
            2 => "i32.store16",
            _ => "i32.store",
        };
        let guest = format!(
            r#"(module (import "support" "memory" (memory 1))
            (func (export "run") (param $result i32)
                local.get $result i32.const {bits} {store}
                local.get $result i32.const 0 {store} offset={width}))"#
        );
        let guest = wasmtime::Module::new(&engine, wat::parse_str(&guest).unwrap()).unwrap();
        let err = core_call(&engine, &support, &guest, &adapter, &input(&[], 0, 128)).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}

#[test]
fn nested_map_counts_duplicates_before_host_normalizes_last_values() {
    // 関門: 動的な鍵・list・flags が親のループを壊さず、重複で消える値も数える。
    // 独立したゲストが乱れた順序で三組を返すため、ホスト codec との往復だけではない。
    let guest = format!(
        r#"(component (core module $m {MEMORY}
        (data (i32.const 5000) "zaz")
        (data (i32.const 5100) "\01\00\00\01\03\00\02\00")
        (func (export "run") (param $p i32) (param $len i32) (result i32)
            local.get $len i32.eqz if
                i32.const 1024 i32.const 0 i32.store
                i32.const 1028 i32.const 0 i32.store i32.const 1024 return
            end
            local.get $len i32.const 2 i32.ne if unreachable end
            local.get $p i32.load i32.load8_u i32.const 97 i32.ne if unreachable end
            local.get $p i32.load offset=8 i32.load16_u i32.const 256 i32.ne if unreachable end
            local.get $p i32.load offset=12 i32.const 1 i32.ne if unreachable end
            local.get $p i32.load offset=16 i32.load8_u i32.const 122 i32.ne if unreachable end
            local.get $p i32.load offset=28 if unreachable end
            i32.const 4096 i32.const 5000 i32.store
            i32.const 4100 i32.const 1 i32.store
            i32.const 4104 i32.const 5100 i32.store
            i32.const 4108 i32.const 2 i32.store
            i32.const 4112 i32.const 5001 i32.store
            i32.const 4116 i32.const 1 i32.store
            i32.const 4120 i32.const 5104 i32.store
            i32.const 4124 i32.const 1 i32.store
            i32.const 4128 i32.const 5002 i32.store
            i32.const 4132 i32.const 1 i32.store
            i32.const 4136 i32.const 5106 i32.store
            i32.const 4140 i32.const 1 i32.store
            i32.const 1024 i32.const 4096 i32.store
            i32.const 1028 i32.const 3 i32.store i32.const 1024))
        (core instance $i (instantiate $m))
        (type $f0 (flags "f0" "f1" "f2" "f3" "f4" "f5" "f6" "f7" "f8"))
        (export $f "flags-type" (type $f0)) (type $list (list $f)) (type $map (map string $list))
        (func (export "run") (param "x" $map) (result $map)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let plans = [P::Map(
        Box::new(P::String),
        Box::new(P::List(Box::new(flags(9)))),
    )];
    let (engine, component) = compile(&guest, &plans, &plans);
    let codec = CodecPlan::new(&plans, &mut 100_000).unwrap();
    let mut body = vec![0; 70];
    for (offset, value) in [
        (32, 40_u32),
        (36, 3),
        (40, 88),
        (44, 1),
        (48, 90),
        (52, 2),
        (56, 94),
        (60, 1),
        (64, 96),
        (68, 1),
        (72, 98),
        (76, 1),
        (80, 100),
        (84, 1),
    ] {
        body[offset - 32..offset - 28].copy_from_slice(&value.to_le_bytes());
    }
    body[56] = b'z';
    body[58] = 1;
    body[61] = 1;
    body[62] = b'a';
    body[64] = 3;
    body[66] = b'z';
    body[68] = 2;
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let empty = codec.encode(ctx, &[Value::EmptyMap], 40).unwrap();
        let result = call(&engine, &component, &empty.bytes).unwrap();
        assert_eq!(result, input(&[0; 8], 1, 40));
        let decoded = codec.decode(ctx, &result, 40).unwrap();
        assert_eq!(decoded.construction_bytes, 16);
        assert_eq!(map::map_len(ctx, decoded.values[0]).unwrap(), 0);
        let a = ctx.alloc_str("a", "test").unwrap();
        let z = ctx.alloc_str("z", "test").unwrap();
        let set = map::set_insert(ctx, Value::EmptySet, Value::Tag(CtorTag(92)), "test").unwrap();
        let list =
            crate::runtime::list::from_iter_exact(ctx, 1, [set].into_iter(), "test").unwrap();
        let m = map::map_insert(ctx, Value::EmptyMap, z, Value::EmptyList, "test").unwrap();
        let m = map::map_insert(ctx, m, a, list, "test").unwrap();
        let source = codec.encode(ctx, &[m], 259).unwrap();
        assert_eq!(source.construction_bytes, 114);
        let result = call(&engine, &component, &source.bytes).unwrap();
        assert_eq!(result, input(&body, 1, 259));
        let decoded = codec.decode(ctx, &result, 259).unwrap();
        assert_eq!(decoded.construction_bytes, 259);
        let pairs = map::map_to_vec(ctx, decoded.values[0]).unwrap();
        assert_eq!(
            pairs
                .iter()
                .map(|(k, _)| ctx.str(*k).unwrap())
                .collect::<Vec<_>>(),
            ["a", "z"]
        );
        for ((_, list), selected) in pairs.iter().zip([vec![100, 99], vec![99]]) {
            let set = crate::runtime::list::get(ctx, *list, 0).unwrap().unwrap();
            assert_eq!(crate::runtime::list::len(ctx, *list).unwrap(), 1);
            assert_eq!(map::set_len(ctx, set).unwrap(), selected.len() as u32);
            for tag in selected {
                assert!(map::set_contains(ctx, set, Value::Tag(CtorTag(tag))).unwrap());
            }
        }
        let mut source = source.bytes;
        for (limit, number) in [(113_u64, 3), (258, 4)] {
            source[16..24].copy_from_slice(&limit.to_le_bytes());
            source[24..32].copy_from_slice(&limit.to_le_bytes());
            let err = call(&engine, &component, &source).unwrap_err();
            let report = reported_failure(&err).unwrap();
            assert_eq!(
                (report.number, report.requested, report.limit),
                (number, if number == 3 { 114 } else { 259 }, limit)
            );
        }
        let bad = input(&body, 1, 258);
        assert!(matches!(
            codec.decode(ctx, &bad, 258),
            Err(CodecError::Wire(WireError::ConstructionLimit))
        ));
    });
}

#[test]
fn map_rejects_invalid_values_even_when_later_keys_would_replace_them() {
    // 関門: 正準 ABI の検査を経ないゲストの結果も、消える値を含めて全体を検査する。
    // codec の不正な文字列の試験は、補助が元のメモリを走査する段の漏れには届かない。
    let plans = [P::Map(Box::new(P::U8), Box::new(P::Char))];
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    let support = wasmtime::Module::from_binary(
        &engine,
        &super::emit::memory_module(1, None).unwrap().finish(),
    )
    .unwrap();
    let adapter = wasmtime::Module::from_binary(
        &engine,
        &super::emit::fixed_module(&[], &plans).unwrap().finish(),
    )
    .unwrap();
    for invalid in [0xd800, 0x110000] {
        let guest = format!(
            r#"(module (import "support" "memory" (memory 1))
            (func (export "run") (param $result i32)
                i32.const 4096 i32.const 1 i32.store8
                i32.const 4100 i32.const {invalid} i32.store
                i32.const 4104 i32.const 1 i32.store8
                i32.const 4108 i32.const 65 i32.store
                local.get $result i32.const 4096 i32.store
                local.get $result i32.const 2 i32.store offset=4))"#
        );
        let guest = wasmtime::Module::new(&engine, wat::parse_str(&guest).unwrap()).unwrap();
        let err = core_call(&engine, &support, &guest, &adapter, &input(&[], 0, 128)).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}
