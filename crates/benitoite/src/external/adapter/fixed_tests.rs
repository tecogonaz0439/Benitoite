//! 固定値の生成と合成を、手書きゲストの結果と独立した期待値で確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::{
    component::fixed_component,
    runtime::{link_failure, reported_failure},
    wire,
};
use crate::external::WitPlan as P;
use wasmtime::component::{Component, Linker};
use wasmtime::{Engine, Store};

pub(super) fn compile(guest: &str, params: &[P], results: &[P]) -> (Engine, Component) {
    let guest = wat::parse_str(guest).unwrap();
    let bytes = fixed_component(&guest, "run", params, results).unwrap();
    let engine = Engine::new(&crate::external::engine_config()).unwrap();
    // 検証は本番の合成したバイナリに対して行い、WAT の検証で代用しない。
    let component = Component::from_binary(&engine, &bytes).unwrap();
    (engine, component)
}

pub(super) fn input(payload: &[u8], roots: u32, limit: u64) -> Vec<u8> {
    let mut bytes = vec![0; 32];
    bytes.extend_from_slice(payload);
    wire::Header {
        length: bytes.len() as u32,
        roots,
        limit,
    }
    .write(&mut bytes)
    .unwrap();
    bytes
}

pub(super) fn call(
    engine: &Engine,
    component: &Component,
    bytes: &[u8],
) -> wasmtime::Result<Vec<u8>> {
    let mut store = Store::new(engine, ());
    store.set_fuel(1_000_000).unwrap();
    store.set_epoch_deadline(1);
    let mut linker = Linker::new(engine);
    link_failure(&mut linker).unwrap();
    let instance = linker.instantiate(&mut store, component).unwrap();
    let f = instance
        .get_typed_func::<(&[u8],), (Vec<u8>,)>(&mut store, "call")
        .unwrap();
    // 正準 ABI の後処理は Wasmtime の同期の呼び出しが行う。
    let (result,) = f.call(&mut store, (bytes,))?;
    Ok(result)
}

#[test]
fn scalar_widths_signed_extension_and_float_bits_cross_generated_adapter() {
    // 関門: 生成器の境界で実際の lower/lift を接続する。既存の配置・ホスト変換の試験は
    // 生成した補助を呼ばないため、符号拡張や合成の関数番号の誤りを捕まえられない。
    // 入力をそのまま返さず、独立したゲストの演算結果と手で定めたビットを比べる。
    let cases = [
        (
            P::S8,
            "s8",
            "i32",
            "local.get 0 i32.const -128 i32.eq if (result i32) i32.const -127 else i32.const 0 end",
            vec![0x80],
            vec![0x81],
        ),
        (
            P::S16,
            "s16",
            "i32",
            "local.get 0 i32.const -32768 i32.eq if (result i32) i32.const -32767 else i32.const 0 end",
            vec![0, 0x80],
            vec![1, 0x80],
        ),
        (
            P::S32,
            "s32",
            "i32",
            "local.get 0 i32.const 1 i32.add",
            0x80000000_u32.to_le_bytes().to_vec(),
            0x80000001_u32.to_le_bytes().to_vec(),
        ),
        (
            P::S64,
            "s64",
            "i64",
            "local.get 0 i64.const 1 i64.add",
            i64::MIN.to_le_bytes().to_vec(),
            (i64::MIN + 1).to_le_bytes().to_vec(),
        ),
        (
            P::U8,
            "u8",
            "i32",
            "local.get 0 i32.const 1 i32.sub",
            vec![0xff],
            vec![0xfe],
        ),
        (
            P::U16,
            "u16",
            "i32",
            "local.get 0 i32.const 1 i32.sub",
            vec![0xff, 0xff],
            vec![0xfe, 0xff],
        ),
        (
            P::U32,
            "u32",
            "i32",
            "local.get 0 i32.const 1 i32.sub",
            u32::MAX.to_le_bytes().to_vec(),
            (u32::MAX - 1).to_le_bytes().to_vec(),
        ),
        (
            P::U64,
            "u64",
            "i64",
            "local.get 0 i64.const 1 i64.xor",
            0x8000000000000000_u64.to_le_bytes().to_vec(),
            0x8000000000000001_u64.to_le_bytes().to_vec(),
        ),
        (
            P::F32,
            "f32",
            "f32",
            "local.get 0 f32.neg",
            0_u32.to_le_bytes().to_vec(),
            0x80000000_u32.to_le_bytes().to_vec(),
        ),
        (
            P::F64,
            "f64",
            "f64",
            "local.get 0 f64.neg",
            0x3ff8000000000000_u64.to_le_bytes().to_vec(),
            0xbff8000000000000_u64.to_le_bytes().to_vec(),
        ),
        (
            P::Bool,
            "bool",
            "i32",
            "local.get 0 i32.eqz",
            vec![1],
            vec![0],
        ),
        (
            P::Char,
            "char",
            "i32",
            "local.get 0 i32.const 1 i32.add",
            0x1f600_u32.to_le_bytes().to_vec(),
            0x1f601_u32.to_le_bytes().to_vec(),
        ),
    ];
    for (plan, wit, core, operation, payload, expected) in cases {
        let guest = format!(
            r#"(component
            (core module $m (func (export "run") (param {core}) (result {core}) {operation}))
            (core instance $i (instantiate $m))
            (func (export "run") (param "x" {wit}) (result {wit}) (canon lift (core func $i "run"))))"#
        );
        let (engine, component) = compile(
            &guest,
            std::slice::from_ref(&plan),
            std::slice::from_ref(&plan),
        );
        let result = call(&engine, &component, &input(&payload, 1, 1024)).unwrap();
        assert_eq!(result, input(&expected, 1, 1024), "{wit}");
    }
}

pub(super) const MEMORY: &str = r#"
    (memory (export "memory") 1)
    (global $next (mut i32) (i32.const 2048))
    (global $calls (mut i32) (i32.const 0))
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) (local i32)
        global.get $next local.get 2 i32.const 1 i32.sub i32.add
        local.get 2 i32.const 1 i32.sub i32.const -1 i32.xor i32.and
        local.tee 4 local.get 3 i32.add global.set $next local.get 4)
"#;

#[test]
fn nested_record_and_tuple_use_direct_arguments_and_indirect_result_once() {
    // 関門: ネストの欄順・幅と詰め物を、手書きの結果位置からホストへ戻す。
    // カウンタを結果に含め、呼び直しが値に現れるようにする。専用の試験用差し込み口は加えない。
    let guest = format!(
        r#"(component
        (core module $m {MEMORY}
            (func (export "run") (param i32 i64 f32 i32) (result i32)
                global.get $calls i32.const 1 i32.add global.set $calls
                i32.const 1024 local.get 0 i32.const 1 i32.add i32.store8
                i32.const 1032 local.get 1 global.get $calls i64.extend_i32_u i64.add i64.store
                i32.const 1040 local.get 2 f32.neg f32.store
                i32.const 1044 local.get 3 i32.const 1 i32.add i32.store
                i32.const 1025 i32.const 127 i32.store8
                i32.const 1024))
        (core instance $i (instantiate $m))
        (type $t (tuple f32 char))
        (type $r0 (record (field "a" s8) (field "b" u64) (field "c" $t)))
        (export $r "record-type" (type $r0))
        (func (export "run") (param "x" $r) (result $r)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let plan = P::Record {
        fields: vec![
            ("a".into(), P::S8),
            ("b".into(), P::U64),
            ("c".into(), P::Tuple(vec![P::F32, P::Char])),
        ],
    };
    let (engine, component) = compile(
        &guest,
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    let mut payload = vec![0; 24];
    payload[0] = 0x80;
    payload[8..16].copy_from_slice(&0x8000000000000000_u64.to_le_bytes());
    payload[16..20].copy_from_slice(&1.5_f32.to_le_bytes());
    payload[20..24].copy_from_slice(&0x1f600_u32.to_le_bytes());
    let mut expected = vec![0; 24];
    expected[0] = 0x81;
    expected[8..16].copy_from_slice(&0x8000000000000001_u64.to_le_bytes());
    expected[16..20].copy_from_slice(&(-1.5_f32).to_le_bytes());
    expected[20..24].copy_from_slice(&0x1f601_u32.to_le_bytes());
    assert_eq!(
        call(&engine, &component, &input(&payload, 1, 1024)).unwrap(),
        input(&expected, 1, 1024)
    );
}

#[test]
fn sixteen_and_seventeen_arguments_and_empty_results_follow_lower_abi() {
    // 関門: 16 個の平らな引数には結果位置を後から足し、17 個なら引数の位置一つへ切り替える。
    // 同じ手書きのゲストで全引数の和を返し、先頭だけを読んで通る退行を避ける。
    for count in [16, 17] {
        let (signature, sum) = if count == 16 {
            (
                "(param i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)",
                "local.get 0 local.get 1 i32.add local.get 2 i32.add local.get 3 i32.add local.get 4 i32.add local.get 5 i32.add local.get 6 i32.add local.get 7 i32.add local.get 8 i32.add local.get 9 i32.add local.get 10 i32.add local.get 11 i32.add local.get 12 i32.add local.get 13 i32.add local.get 14 i32.add local.get 15 i32.add",
            )
        } else {
            (
                "(param i32) (local $idx i32) (local $sum i32)",
                "(loop $sumloop local.get $sum local.get 0 local.get $idx i32.const 4 i32.mul i32.add i32.load i32.add local.set $sum local.get $idx i32.const 1 i32.add local.tee $idx i32.const 17 i32.lt_u br_if $sumloop) local.get $sum",
            )
        };
        let guest = format!(
            r#"(component
            (core module $m {MEMORY}
                (func (export "run") {params} (result i32) {locals}
                    i32.const 1024 {sum} i32.store
                    i32.const 1032 i64.const -9223372036854775807 i64.store
                    i32.const 1024))
            (core instance $i (instantiate $m))
            (type $t (tuple {fields})) (type $r (tuple u32 u64))
            (func (export "run") (param "x" $t) (result $r)
                (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#,
            params = if count == 16 {
                signature
            } else {
                "(param i32)"
            },
            locals = if count == 16 {
                ""
            } else {
                "(local $idx i32) (local $sum i32)"
            },
            fields = vec!["u32"; count].join(" ")
        );
        let (engine, component) = compile(
            &guest,
            &[P::ConstructorTuple {
                tag: 37,
                fields: vec![P::U32; count],
            }],
            &[P::Tuple(vec![P::U32, P::U64])],
        );
        let payload: Vec<u8> = (1..=count as u32).flat_map(u32::to_le_bytes).collect();
        let mut expected = vec![0; 16];
        expected[..4].copy_from_slice(&(if count == 16 { 136_u32 } else { 153_u32 }).to_le_bytes());
        expected[8..].copy_from_slice(&0x8000000000000001_u64.to_le_bytes());
        assert_eq!(
            call(&engine, &component, &input(&payload, 1, 1024)).unwrap(),
            input(&expected, 1, 1024)
        );
    }
    let guest = r#"(component (core module $m (func (export "run")))
        (core instance $i (instantiate $m)) (func (export "run") (canon lift (core func $i "run"))))"#;
    let (engine, component) = compile(guest, &[], &[]);
    assert_eq!(
        call(&engine, &component, &input(&[], 0, 32)).unwrap(),
        input(&[], 0, 32)
    );
    let guest = r#"(component (core module $m
        (func (export "run") (param i32 i64)
            local.get 0 i32.const 255 i32.ne if unreachable end
            local.get 1 i64.const -9223372036854775807 i64.ne if unreachable end))
        (core instance $i (instantiate $m))
        (func (export "run") (param "byte" u8) (param "wide" u64) (canon lift (core func $i "run"))))"#;
    let (engine, component) = compile(guest, &[P::U8, P::U64], &[]);
    let mut payload = vec![0; 16];
    payload[0] = 255;
    payload[8..].copy_from_slice(&0x8000_0000_0000_0001_u64.to_le_bytes());
    assert_eq!(
        call(&engine, &component, &input(&payload, 2, 48)).unwrap(),
        input(&[], 0, 48)
    );
}

#[test]
fn malformed_fixed_values_and_fixed_budgets_stop_before_guest_call() {
    // 関門: 境界の検査が実際の補助の呼び出し前に働くことを、呼ばれると trap するゲストで確認する。
    // 既存のメモリのヘッダ試験には、値の妥当性と構築量の計数は含まれない。
    let guest = r#"(component
        (core module $m (func (export "run") (param i32 i32) unreachable))
        (core instance $i (instantiate $m))
        (func (export "run") (param "b" bool) (param "c" char) (canon lift (core func $i "run"))))"#;
    let (engine, component) = compile(guest, &[P::Bool, P::Char], &[]);
    for (payload, limit, number) in [
        (vec![2, 0, 0, 0, 65, 0, 0, 0], 64, 7),
        (vec![1, 1, 0, 0, 65, 0, 0, 0], 64, 7),
        (vec![1, 0, 0, 0, 0, 0xd8, 0, 0], 64, 7),
        (vec![1, 0, 0, 0, 0, 0, 0x11, 0], 64, 7),
        (vec![1, 0, 0, 0, 65, 0, 0, 0], 39, 1),
    ] {
        let err = call(&engine, &component, &input(&payload, 2, limit)).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, number);
    }
    let guest = format!(
        r#"(component (core module $m {MEMORY}
        (func (export "run") (param i32 i32 i32) (result i32) unreachable))
        (core instance $i (instantiate $m)) (type $t (tuple u8 u8 u8))
        (func (export "run") (param "x" $t) (result $t)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    // 同じ ABI でも、言語の構成子と ABI 専用の tuple では構築量が異なる。
    for (p, r, number, requested) in [
        (
            P::ConstructorTuple {
                tag: 9,
                fields: vec![P::U8; 3],
            },
            P::TupleFields(vec![P::U8; 3]),
            3,
            64,
        ),
        (
            P::TupleFields(vec![P::U8; 3]),
            P::ConstructorTuple {
                tag: 9,
                fields: vec![P::U8; 3],
            },
            4,
            64,
        ),
    ] {
        let (engine, component) = compile(&guest, &[p], &[r]);
        let err = call(&engine, &component, &input(&[1, 2, 3], 1, 48)).unwrap_err();
        let report = reported_failure(&err).unwrap();
        assert_eq!(
            (report.number, report.requested, report.limit),
            (number, requested, 48)
        );
    }
}

fn reference_input(data: &[u8], count: u32, limit: u64) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(&(if count == 0 { 0_u32 } else { 40_u32 }).to_le_bytes());
    payload.extend_from_slice(&count.to_le_bytes());
    payload.extend_from_slice(data);
    input(&payload, 1, limit)
}

fn list_guest(wit: &str, size: u32, load: &str, operation: &str, store: &str) -> String {
    format!(
        r#"(component
        (core module $m {MEMORY}
            (func (export "run") (param $ptr i32) (param $len i32) (result i32) (local $idx i32)
                (block $done (loop $copy
                    local.get $idx local.get $len i32.ge_u br_if $done
                    i32.const 4096 local.get $idx i32.const {size} i32.mul i32.add
                    local.get $ptr local.get $len i32.const 1 i32.sub local.get $idx i32.sub i32.const {size} i32.mul i32.add
                    {load} {operation} {store}
                    local.get $idx i32.const 1 i32.add local.set $idx br $copy))
                i32.const 1024 i32.const 4096 i32.store
                i32.const 1028 local.get $len i32.store
                i32.const 1024))
        (core instance $i (instantiate $m))
        (type $list (list {wit}))
        (func (export "run") (param "xs" $list) (result $list)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    )
}

#[test]
fn simple_lists_cross_generated_adapter_with_all_widths_and_empty_values() {
    // 関門: 手書きのゲストが全要素を逆順に演算し、生成器の両方向のコピーの幅・順序を守る。
    // 配置表やホストの codec の往復では、生成したループの終了条件やメモリ位置を検査できない。
    let cases = [
        (
            P::S8,
            "s8",
            1,
            "i32.load8_s",
            "i32.const 1 i32.add",
            "i32.store8",
            vec![0x80, 0, 0x7e],
            vec![0x7f, 1, 0x81],
        ),
        (
            P::S16,
            "s16",
            2,
            "i32.load16_s",
            "i32.const 1 i32.add",
            "i32.store16",
            vec![0, 0x80, 0, 0, 0xfe, 0x7f],
            vec![0xff, 0x7f, 1, 0, 1, 0x80],
        ),
        (
            P::S32,
            "s32",
            4,
            "i32.load",
            "i32.const 1 i32.add",
            "i32.store",
            [i32::MIN, 0, i32::MAX - 1]
                .into_iter()
                .flat_map(i32::to_le_bytes)
                .collect(),
            [i32::MAX, 1, i32::MIN + 1]
                .into_iter()
                .flat_map(i32::to_le_bytes)
                .collect(),
        ),
        (
            P::S64,
            "s64",
            8,
            "i64.load",
            "i64.const 1 i64.add",
            "i64.store",
            [i64::MIN, 0, i64::MAX - 1]
                .into_iter()
                .flat_map(i64::to_le_bytes)
                .collect(),
            [i64::MAX, 1, i64::MIN + 1]
                .into_iter()
                .flat_map(i64::to_le_bytes)
                .collect(),
        ),
        (
            P::U8,
            "u8",
            1,
            "i32.load8_u",
            "i32.const 1 i32.xor",
            "i32.store8",
            vec![0xff, 0x80, 0],
            vec![1, 0x81, 0xfe],
        ),
        (
            P::U16,
            "u16",
            2,
            "i32.load16_u",
            "i32.const 1 i32.xor",
            "i32.store16",
            vec![0xff, 0xff, 0, 0x80, 0, 0],
            vec![1, 0, 1, 0x80, 0xfe, 0xff],
        ),
        (
            P::U32,
            "u32",
            4,
            "i32.load",
            "i32.const 1 i32.xor",
            "i32.store",
            [u32::MAX, 0x80000000, 0]
                .into_iter()
                .flat_map(u32::to_le_bytes)
                .collect(),
            [1_u32, 0x80000001, u32::MAX - 1]
                .into_iter()
                .flat_map(u32::to_le_bytes)
                .collect(),
        ),
        (
            P::U64,
            "u64",
            8,
            "i64.load",
            "i64.const 1 i64.xor",
            "i64.store",
            [u64::MAX, 0x8000000000000000, 0]
                .into_iter()
                .flat_map(u64::to_le_bytes)
                .collect(),
            [1_u64, 0x8000000000000001, u64::MAX - 1]
                .into_iter()
                .flat_map(u64::to_le_bytes)
                .collect(),
        ),
        (
            P::F32,
            "f32",
            4,
            "f32.load",
            "f32.neg",
            "f32.store",
            [0.0_f32, -0.0, 1.5]
                .into_iter()
                .flat_map(f32::to_le_bytes)
                .collect(),
            [-1.5_f32, 0.0, -0.0]
                .into_iter()
                .flat_map(f32::to_le_bytes)
                .collect(),
        ),
        (
            P::F64,
            "f64",
            8,
            "f64.load",
            "f64.neg",
            "f64.store",
            [0.0_f64, -0.0, 1.5]
                .into_iter()
                .flat_map(f64::to_le_bytes)
                .collect(),
            [-1.5_f64, 0.0, -0.0]
                .into_iter()
                .flat_map(f64::to_le_bytes)
                .collect(),
        ),
        (
            P::Bool,
            "bool",
            1,
            "i32.load8_u",
            "i32.eqz",
            "i32.store8",
            vec![1, 0, 0],
            vec![1, 1, 0],
        ),
        (
            P::Char,
            "char",
            4,
            "i32.load",
            "i32.const 1 i32.add",
            "i32.store",
            [0_u32, 0x3042, 0x1f600]
                .into_iter()
                .flat_map(u32::to_le_bytes)
                .collect(),
            [0x1f601_u32, 0x3043, 1]
                .into_iter()
                .flat_map(u32::to_le_bytes)
                .collect(),
        ),
    ];
    for (plan, wit, size, load, operation, store, data, expected) in cases {
        let plan = P::List(Box::new(plan));
        let (engine, component) = compile(
            &list_guest(wit, size, load, operation, store),
            std::slice::from_ref(&plan),
            std::slice::from_ref(&plan),
        );
        for (data, count, expected) in [(&data[..], 3, &expected[..]), (&[][..], 0, &[][..])] {
            assert_eq!(
                call(&engine, &component, &reference_input(data, count, 1024)).unwrap(),
                reference_input(expected, count, 1024),
                "{wit}"
            );
        }
    }
}

fn string_guest(operation: &str) -> String {
    format!(
        r#"(component
        (core module $m {MEMORY}
            (func (export "run") (param i32 i32) (result i32) {operation}))
        (core instance $i (instantiate $m))
        (func (export "run") (param "s" string) (result string)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    )
}

#[test]
fn strings_and_bytes_copy_content_and_relocate_results() {
    // 関門: UTF-8 のバイト数を文字数と取り違えず、空の値も正規化する。
    // ゲストが結果を別の位置・長さで返すため、入力をそのまま返す実装では通らない。
    let guest = string_guest(
        "i32.const 4096 local.get 0 local.get 1 memory.copy i32.const 4096 local.get 1 i32.add i32.const 33 i32.store8 i32.const 1024 i32.const 4096 i32.store i32.const 1028 local.get 1 i32.const 1 i32.add i32.store i32.const 1024",
    );
    let (engine, component) = compile(&guest, &[P::String], &[P::String]);
    for (text, expected) in [
        ("", "!"),
        ("A\0¢あ😀", "A\0¢あ😀!"),
        (
            "\u{7f}\u{80}\u{7ff}\u{800}\u{d7ff}\u{e000}\u{10ffff}",
            "\u{7f}\u{80}\u{7ff}\u{800}\u{d7ff}\u{e000}\u{10ffff}!",
        ),
    ] {
        assert_eq!(
            call(
                &engine,
                &component,
                &reference_input(text.as_bytes(), text.len() as u32, 1024)
            )
            .unwrap(),
            reference_input(expected.as_bytes(), expected.len() as u32, 1024)
        );
    }
    let (engine, component) = compile(
        &list_guest(
            "u8",
            1,
            "i32.load8_u",
            "i32.const 255 i32.xor",
            "i32.store8",
        ),
        &[P::Bytes],
        &[P::Bytes],
    );
    for (data, expected) in [
        (&[0, 0x80, 0xff][..], &[0, 0x7f, 0xff][..]),
        (&[][..], &[][..]),
    ] {
        assert_eq!(
            call(
                &engine,
                &component,
                &reference_input(data, data.len() as u32, 64)
            )
            .unwrap(),
            reference_input(expected, expected.len() as u32, 64)
        );
    }
}

#[test]
fn malformed_dynamic_arguments_stop_before_guest_call() {
    // 関門: 呼ばれると trap するゲストで、UTF-8 と各要素の不正値が形式の失敗として先に止まる。
    // 既存のホスト復号の試験は、生成器の検査漏れを検出できない。
    let (engine, component) = compile(&string_guest("unreachable"), &[P::String], &[P::String]);
    for bytes in [
        &[0x80][..],
        &[0xc0, 0x80],
        &[0xc1, 0xbf],
        &[0xc2],
        &[0xe0, 0x80, 0x80],
        &[0xed, 0xa0, 0x80],
        &[0xf0, 0x80, 0x80, 0x80],
        &[0xf4, 0x90, 0x80, 0x80],
        &[0xf5, 0x80, 0x80, 0x80],
        &[0xc2, 0x41],
        &[0xe2, 0x82],
    ] {
        let err = call(
            &engine,
            &component,
            &reference_input(bytes, bytes.len() as u32, 1024),
        )
        .unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7, "{bytes:x?}");
    }
    for (p, wit, size, bytes) in [
        (P::Bool, "bool", 1, vec![0, 2]),
        (
            P::Char,
            "char",
            4,
            [0x41_u32, 0xd800]
                .into_iter()
                .flat_map(u32::to_le_bytes)
                .collect(),
        ),
        (
            P::Char,
            "char",
            4,
            [0x41_u32, 0x110000]
                .into_iter()
                .flat_map(u32::to_le_bytes)
                .collect(),
        ),
    ] {
        let (engine, component) = compile(
            &list_guest(wit, size, "unreachable", "", ""),
            &[P::List(Box::new(p.clone()))],
            &[P::List(Box::new(p))],
        );
        let err = call(&engine, &component, &reference_input(&bytes, 2, 1024)).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
    for (offset, count, data) in [
        (0_u32, 1_u32, vec![65]),
        (39, 1, vec![65]),
        (41, 1, vec![65]),
        (40, 0, vec![]),
        (40, 2, vec![65]),
        (40, 1, vec![65, 66]),
    ] {
        let mut bytes = reference_input(&data, count, 1024);
        bytes[32..36].copy_from_slice(&offset.to_le_bytes());
        let err = call(&engine, &component, &bytes).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}

#[test]
fn dynamic_transfer_construction_and_value_size_limits_keep_failure_contract() {
    // 関門: 同じ WIT の Bytes と List[Byte] で異なる費用を、生成器の入口と小さい上限で守る。
    // 転送の全長・構築量・既存の大きさの番号と要求量を独立した期待値で確認する。
    let guest = format!(
        r#"(component
        (core module $m {MEMORY} (data (i32.const 4096) "\01\02\03")
            (func (export "run") (result i32)
                i32.const 1024 i32.const 4096 i32.store
                i32.const 1028 i32.const 3 i32.store i32.const 1024))
        (core instance $i (instantiate $m)) (type $list (list u8))
        (func (export "run") (result $list)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    for (plan, limit, expected) in [
        (P::Bytes, 42, Some((2, 43))),
        (P::Bytes, 43, None),
        (P::List(Box::new(P::U8)), 43, Some((4, 64))),
        (P::List(Box::new(P::U8)), 63, Some((4, 64))),
        (P::List(Box::new(P::U8)), 64, None),
    ] {
        let (engine, component) = compile(&guest, &[], &[plan]);
        let result = call(&engine, &component, &input(&[], 0, limit));
        if let Some((number, requested)) = expected {
            let err = result.unwrap_err();
            let report = reported_failure(&err).unwrap();
            assert_eq!(
                (report.number, report.requested, report.limit),
                (number, requested, limit)
            );
        } else {
            assert_eq!(result.unwrap(), reference_input(&[1, 2, 3], 3, limit));
        }
    }
    let plan = P::List(Box::new(P::U8));
    let (engine, component) = compile(
        &list_guest("u8", 1, "i32.load8_u", "i32.const 1 i32.xor", "i32.store8"),
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    for (limit, expected) in [(42, Some((1, 43))), (63, Some((3, 64))), (64, None)] {
        let result = call(&engine, &component, &reference_input(&[1, 2, 3], 3, limit));
        if let Some((number, requested)) = expected {
            let err = result.unwrap_err();
            let report = reported_failure(&err).unwrap();
            assert_eq!(
                (report.number, report.requested, report.limit),
                (number, requested, limit)
            );
        } else {
            assert_eq!(result.unwrap(), reference_input(&[2, 3, 0], 3, limit));
        }
    }
    for (plan, wit, count, maximum) in [
        (P::Bytes, "u8", (1_u32 << 30) + 1, 1_u64 << 30),
        (
            P::List(Box::new(P::U8)),
            "u8",
            (1_u32 << 24) + 1,
            1_u64 << 24,
        ),
    ] {
        let (engine, component) = compile(
            &list_guest(wit, 1, "unreachable", "", ""),
            std::slice::from_ref(&plan),
            std::slice::from_ref(&plan),
        );
        let err = call(&engine, &component, &reference_input(&[], count, u64::MAX)).unwrap_err();
        let report = reported_failure(&err).unwrap();
        assert_eq!(
            (report.number, report.requested, report.limit),
            (5, u64::from(count), maximum)
        );
    }
}

#[test]
fn mixed_references_align_in_order_and_use_indirect_arguments() {
    // 関門: 複数の参照を含む根を間接の引数で渡し、参照先の整列と宣言順の再配置を守る。
    // ゲストは欄を交換して返すため、固定部だけのコピーや共有参照の見落としでは通らない。
    let guest = format!(
        r#"(component
        (core module $m {MEMORY}
            (func (export "run") (param $p i32) (result i32)
                i32.const 1024 local.get $p i32.const 8 i32.add i32.load i32.store
                i32.const 1028 local.get $p i32.const 12 i32.add i32.load i32.store
                i32.const 1032 local.get $p i32.load i32.store
                i32.const 1036 local.get $p i32.const 4 i32.add i32.load i32.store
                i32.const 1040 local.get $p i32.const 16 i32.add i32.load i32.store
                i32.const 1044 local.get $p i32.const 20 i32.add i32.load i32.store
                i32.const 1024))
        (core instance $i (instantiate $m)) (type $list (list u64))
        (type $args (tuple string string $list u32 u32 u32 u32 u32 u32 u32 u32 u32 u32 u32))
        (type $result (tuple string string $list))
        (func (export "run") (param "args" $args) (result $result)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let mut args = vec![P::String, P::String, P::List(Box::new(P::U64))];
    args.extend(vec![P::U32; 11]);
    let (engine, component) = compile(
        &guest,
        &[P::TupleFields(args)],
        &[P::TupleFields(vec![
            P::String,
            P::String,
            P::List(Box::new(P::U64)),
        ])],
    );
    // 根は 68 バイト、文字列は 100 と 101、u64 の参照先は 104 に置く。
    let mut payload = vec![0; 88];
    payload[0..4].copy_from_slice(&100_u32.to_le_bytes());
    payload[4..8].copy_from_slice(&1_u32.to_le_bytes());
    payload[8..12].copy_from_slice(&101_u32.to_le_bytes());
    payload[12..16].copy_from_slice(&2_u32.to_le_bytes());
    payload[16..20].copy_from_slice(&104_u32.to_le_bytes());
    payload[20..24].copy_from_slice(&2_u32.to_le_bytes());
    payload[68..71].copy_from_slice(b"ABC");
    payload[72..80].copy_from_slice(&u64::MAX.to_le_bytes());
    payload[80..88].copy_from_slice(&0x8000000000000001_u64.to_le_bytes());
    let mut expected = vec![0; 48];
    expected[0..4].copy_from_slice(&56_u32.to_le_bytes());
    expected[4..8].copy_from_slice(&2_u32.to_le_bytes());
    expected[8..12].copy_from_slice(&58_u32.to_le_bytes());
    expected[12..16].copy_from_slice(&1_u32.to_le_bytes());
    expected[16..20].copy_from_slice(&64_u32.to_le_bytes());
    expected[20..24].copy_from_slice(&2_u32.to_le_bytes());
    expected[24..27].copy_from_slice(b"BCA");
    expected[32..40].copy_from_slice(&u64::MAX.to_le_bytes());
    expected[40..48].copy_from_slice(&0x8000000000000001_u64.to_le_bytes());
    assert_eq!(
        call(&engine, &component, &input(&payload, 1, 1024)).unwrap(),
        input(&expected, 1, 1024)
    );
    for (position, replacement) in [
        (8, 100_u32.to_le_bytes().to_vec()),
        (16, 103_u32.to_le_bytes().to_vec()),
        (71, vec![1]),
    ] {
        let mut bad = payload.clone();
        bad[position..position + replacement.len()].copy_from_slice(&replacement);
        let err = call(&engine, &component, &input(&bad, 1, 1024)).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}

#[test]
fn invalid_guest_utf8_remains_a_component_abi_error() {
    // 関門: 元のゲストの不正な UTF-8 は Wasmtime の検査に残し、補助形式の不具合へ分類しない。
    let guest = string_guest(
        "i32.const 4096 i32.const 255 i32.store8 i32.const 1024 i32.const 4096 i32.store i32.const 1028 i32.const 1 i32.store i32.const 1024",
    );
    let (engine, component) = compile(&guest, &[P::String], &[P::String]);
    let err = call(&engine, &component, &reference_input(b"", 0, 64)).unwrap_err();
    assert!(reported_failure(&err).is_none());
    assert!(
        format!("{err:#}").contains("invalid utf8 encoding"),
        "{err:#}"
    );
}

fn nested_numbers_guest(with_input: bool) -> String {
    let (params, wit_params, check) = if with_input {
        (
            "(param $ptr i32) (param $len i32)",
            "(param \"xs\" $outer)",
            r#"local.get $len i32.const 3 i32.ne if unreachable end
                local.get $ptr i32.load i32.load16_u i32.const 10 i32.ne if unreachable end
                local.get $ptr i32.load i32.const 2 i32.add i32.load16_u i32.const 20 i32.ne if unreachable end
                local.get $ptr i32.const 12 i32.add i32.load if unreachable end
                local.get $ptr i32.const 16 i32.add i32.load i32.load16_u i32.const 30 i32.ne if unreachable end"#,
        )
    } else {
        ("", "", "")
    };
    format!(
        r#"(component
        (core module $m {MEMORY}
            (func (export "run") {params} (result i32)
                {check}
                i32.const 4096 i32.const 5000 i32.store
                i32.const 4100 i32.const 1 i32.store
                i32.const 4104 i32.const 5100 i32.store
                i32.const 4108 i32.const 2 i32.store
                i32.const 4112 i32.const 12344 i32.store
                i32.const 4116 i32.const 0 i32.store
                i32.const 5000 i32.const 31 i32.store16
                i32.const 5100 i32.const 11 i32.store16
                i32.const 5102 i32.const 21 i32.store16
                i32.const 1024 i32.const 4096 i32.store
                i32.const 1028 i32.const 3 i32.store i32.const 1024))
        (core instance $i (instantiate $m))
        (type $inner (list u16)) (type $outer (list $inner))
        (func (export "run") {wit_params} (result $outer)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    )
}

fn nested_numbers_input(result: bool, limit: u64) -> Vec<u8> {
    let mut data = Vec::new();
    let pairs = if result {
        [(64_u32, 1_u32), (66, 2), (0, 0)]
    } else {
        [(64_u32, 2_u32), (0, 0), (68, 1)]
    };
    for (ptr, count) in pairs {
        data.extend_from_slice(&ptr.to_le_bytes());
        data.extend_from_slice(&count.to_le_bytes());
    }
    for n in if result {
        [31_u16, 11, 21]
    } else {
        [10, 20, 30]
    } {
        data.extend_from_slice(&n.to_le_bytes());
    }
    reference_input(&data, 3, limit)
}

#[test]
fn nested_lists_reserve_fixed_regions_and_charge_both_directions() {
    // 関門: 子の固定部を全要素分予約し、親のループの状態を子と分ける契約を守る。
    // 手書きゲストは入力の全非空要素を検査し、独立した順序・位置・値で結果を返す。
    // 単純なリストとホスト codec の試験には、生成した入れ子の走査の検査はない。
    let plan = P::List(Box::new(P::List(Box::new(P::U16))));
    for with_input in [true, false] {
        let params = if with_input {
            vec![plan.clone()]
        } else {
            vec![]
        };
        let (engine, component) = compile(
            &nested_numbers_guest(with_input),
            &params,
            std::slice::from_ref(&plan),
        );
        for limit in [111, 112] {
            let bytes = if with_input {
                nested_numbers_input(false, limit)
            } else {
                input(&[], 0, limit)
            };
            let result = call(&engine, &component, &bytes);
            if limit == 112 {
                assert_eq!(result.unwrap(), nested_numbers_input(true, limit));
            } else {
                let err = result.unwrap_err();
                let report = reported_failure(&err).unwrap();
                assert_eq!(
                    (report.number, report.requested, report.limit),
                    (if with_input { 3 } else { 4 }, 112, 111)
                );
            }
        }
    }
}

#[test]
fn nested_strings_keep_parent_iteration_and_reject_malformed_children() {
    // 関門: UTF-8 の検査ループが親の添字を壊す退行と、子の共有・重なりを拒否する契約を守る。
    // 外部ゲストが文字列の記述子を逆順に返すため、再配置は独立した期待値と比べられる。
    let plan = P::List(Box::new(P::String));
    let guest = list_guest("string", 8, "i64.load", "", "i64.store");
    let (engine, component) = compile(
        &guest,
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    let payload = |result: bool| {
        let mut data = Vec::new();
        for (ptr, count) in if result {
            [(64_u32, 1_u32), (0, 0), (65, 3)]
        } else {
            [(64_u32, 3_u32), (0, 0), (67, 1)]
        } {
            data.extend_from_slice(&ptr.to_le_bytes());
            data.extend_from_slice(&count.to_le_bytes());
        }
        data.extend_from_slice(if result {
            "Qあ".as_bytes()
        } else {
            "あQ".as_bytes()
        });
        reference_input(&data, 3, 68)
    };
    assert_eq!(
        call(&engine, &component, &payload(false)).unwrap(),
        payload(true)
    );
    let (engine, component) = compile(
        &list_guest("string", 8, "unreachable", "", ""),
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    for (offset, replacement) in [
        (32, 44_u32.to_le_bytes().to_vec()),
        (40, 63_u32.to_le_bytes().to_vec()),
        (48, 67_u32.to_le_bytes().to_vec()),
        (56, 64_u32.to_le_bytes().to_vec()),
        (64, vec![0xed, 0xa0, 0x80]),
    ] {
        let mut malformed = payload(false);
        malformed[offset..offset + replacement.len()].copy_from_slice(&replacement);
        let err = call(&engine, &component, &malformed).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}

pub(super) fn core_call(
    engine: &Engine,
    support: &wasmtime::Module,
    guest: &wasmtime::Module,
    adapter: &wasmtime::Module,
    bytes: &[u8],
) -> wasmtime::Result<Vec<u8>> {
    measured_core_call(engine, support, guest, adapter, bytes).map(|(output, _)| output)
}

pub(super) fn measured_core_call(
    engine: &Engine,
    support: &wasmtime::Module,
    guest: &wasmtime::Module,
    adapter: &wasmtime::Module,
    bytes: &[u8],
) -> wasmtime::Result<(Vec<u8>, u64)> {
    let mut store = Store::new(engine, ());
    store.set_fuel(1_000_000).unwrap();
    store.set_epoch_deadline(1);
    let mut linker = wasmtime::Linker::new(engine);
    linker
        .func_wrap(
            "adapter",
            "adapter-fail",
            |number: u32, requested: u64, limit: u64| -> wasmtime::Result<()> {
                Err(wasmtime::Error::new(super::runtime::AdapterFailure {
                    number,
                    requested,
                    limit,
                }))
            },
        )
        .unwrap();
    linker
        .alias("adapter", "adapter-fail", "failure", "adapter-fail")
        .unwrap();
    let support = linker.instantiate(&mut store, support).unwrap();
    linker.instance(&mut store, "support", support).unwrap();
    let guest = linker.instantiate(&mut store, guest).unwrap();
    let guest_call = guest.get_func(&mut store, "run").unwrap();
    linker
        .define(&mut store, "guest", "call", guest_call)
        .unwrap();
    let adapter = linker.instantiate(&mut store, adapter).unwrap();
    let alloc = support
        .get_typed_func::<(i32, i32, i32, i32), i32>(&mut store, "realloc")
        .unwrap();
    let pointer = alloc
        .call(&mut store, (0, 0, 8, bytes.len() as i32))
        .unwrap();
    let memory = support.get_memory(&mut store, "memory").unwrap();
    memory.write(&mut store, pointer as usize, bytes).unwrap();
    let function = adapter
        .get_typed_func::<(i32, i32), i32>(&mut store, "call")
        .unwrap();
    let pair = function.call(&mut store, (pointer, bytes.len() as i32))?;
    let mut fields = [0; 8];
    memory.read(&store, pair as usize, &mut fields).unwrap();
    let pointer = u32::from_le_bytes(fields[..4].try_into().unwrap());
    let length = u32::from_le_bytes(fields[4..].try_into().unwrap());
    let mut result = vec![0; length as usize];
    memory.read(&store, pointer as usize, &mut result).unwrap();
    Ok((result, 1_000_000 - store.get_fuel()?))
}

#[test]
fn zero_sized_list_elements_still_cost_one_language_value_each() {
    // 関門: ABI の占有量が零でも言語の空の構成子を数える契約を、入れ子の両方向で守る。
    // ホストの復号の試験だけでは、生成した補助が確保前に予算を検査するかは分からない。
    // Wasmtime の検証器は空の WIT record を拒否するので、零サイズの配置はコアの入口で検査する。
    // ゲストは実際に生成した補助と同じメモリを読み、lower の結果領域へ書く独立したコアである。
    let guest = r#"(module
        (import "support" "memory" (memory 1))
        (func (export "run") (param $ptr i32) (param $len i32) (param $result i32)
            local.get $len i32.const 2 i32.ne if unreachable end
            local.get $ptr i32.const 4 i32.add i32.load i32.const 2 i32.ne if unreachable end
            local.get $ptr i32.const 12 i32.add i32.load i32.const 1 i32.ne if unreachable end
            i32.const 4096 i32.const 0 i32.store
            i32.const 4100 i32.const 3 i32.store
            i32.const 4104 i32.const 0 i32.store
            i32.const 4108 i32.const 1 i32.store
            local.get $result i32.const 4096 i32.store
            local.get $result i32.const 2 i32.store offset=4))"#;
    let plan = P::List(Box::new(P::List(Box::new(P::Record { fields: vec![] }))));
    let engine = Engine::new(&crate::external::engine_config()).unwrap();
    let support = wasmtime::Module::from_binary(
        &engine,
        &super::emit::memory_module(1, None).unwrap().finish(),
    )
    .unwrap();
    let guest = wasmtime::Module::new(&engine, wat::parse_str(guest).unwrap()).unwrap();
    let adapter = wasmtime::Module::from_binary(
        &engine,
        &super::emit::fixed_module(std::slice::from_ref(&plan), std::slice::from_ref(&plan))
            .unwrap()
            .finish(),
    )
    .unwrap();
    let bytes = |first: u32, limit| {
        let mut data = Vec::new();
        for (ptr, count) in [(56_u32, first), (56, 1)] {
            data.extend_from_slice(&ptr.to_le_bytes());
            data.extend_from_slice(&count.to_le_bytes());
        }
        reference_input(&data, 2, limit)
    };
    for (limit, expected) in [(95, Some((3, 96))), (111, Some((4, 112))), (112, None)] {
        let result = core_call(&engine, &support, &guest, &adapter, &bytes(2, limit));
        if let Some((number, requested)) = expected {
            let err = result.unwrap_err();
            let report = reported_failure(&err).unwrap();
            assert_eq!(
                (report.number, report.requested, report.limit),
                (number, requested, limit)
            );
        } else {
            assert_eq!(result.unwrap(), bytes(3, limit));
        }
    }
}

#[test]
fn list_type_depth_boundary_runs_with_small_values_and_rejects_one_more_level() {
    // 関門: 深さの上限の型を、各リスト一要素という小さい値で本番の生成・合成・実行へ通す。
    // 型の配置だけの試験では、生成したループの入れ子や Wasm のスタックの退行を検出できない。
    for depth in [4, crate::external::expansion::MAX_DEPTH] {
        let mut plan = P::U8;
        let mut types = String::new();
        for n in 0..depth - 1 {
            let element = if n == 0 {
                "u8".to_string()
            } else {
                format!("$l{}", n - 1)
            };
            types.push_str(&format!("(type $l{n} (list {element}))"));
            plan = P::List(Box::new(plan));
        }
        let chase = "local.get 0 i32.load local.set 0 ".repeat((depth - 2) as usize);
        let guest = format!(
            r#"(component (core module $m {MEMORY}
            (func (export "run") (param i32 i32) (result i32)
                i32.const 1024 local.get 0 i32.store
                i32.const 1028 local.get 1 i32.store
                {chase}
                local.get 0 local.get 0 i32.load8_u i32.const 1 i32.add i32.store8
                i32.const 1024))
            (core instance $i (instantiate $m)) {types}
            (func (export "run") (param "x" $l{last}) (result $l{last})
                (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#,
            last = depth - 2,
        );
        let (engine, component) = compile(
            &guest,
            std::slice::from_ref(&plan),
            std::slice::from_ref(&plan),
        );
        let mut data = Vec::new();
        for n in 0..depth - 1 {
            data.extend_from_slice(&(40 + n * 8).to_le_bytes());
            data.extend_from_slice(&1_u32.to_le_bytes());
        }
        data.push(42);
        let bytes = input(&data, 1, 1600);
        *data.last_mut().unwrap() = 43;
        assert_eq!(
            call(&engine, &component, &bytes).unwrap(),
            input(&data, 1, 1600)
        );
        if depth == crate::external::expansion::MAX_DEPTH {
            let too_deep = P::List(Box::new(plan));
            let err = fixed_component(&wat::parse_str(&guest).unwrap(), "run", &[too_deep], &[])
                .unwrap_err();
            assert_eq!(err, super::layout::LayoutError::TypeBudget);
        }
    }
}

#[test]
fn variable_length_children_use_element_alignment_and_zero_fixed_padding() {
    // 関門: 要素の大きさ 12 と整列 4 を取り違えず、欄の順序で可変長の子を写す。
    // 既存のスカラーのリストは大きさと整列が同じなので、この退行を検出できない。
    let guest = format!(
        r#"(component (core module $m {MEMORY}
        (func (export "run") (param $p i32) (param $len i32) (result i32) (local $n i32)
            (block $done (loop $copy
                local.get $n local.get $len i32.ge_u br_if $done
                i32.const 4096 local.get $n i32.const 12 i32.mul i32.add
                local.get $p local.get $len i32.const 1 i32.sub local.get $n i32.sub i32.const 12 i32.mul i32.add
                i32.const 12 memory.copy
                i32.const 4104 local.get $n i32.const 12 i32.mul i32.add
                i32.const 4104 local.get $n i32.const 12 i32.mul i32.add i32.load8_u i32.const 1 i32.add i32.store8
                local.get $n i32.const 1 i32.add local.set $n br $copy))
            i32.const 1024 i32.const 4096 i32.store
            i32.const 1028 local.get $len i32.store i32.const 1024))
        (core instance $i (instantiate $m)) (type $item (tuple string u8)) (type $items (list $item))
        (func (export "run") (param "xs" $items) (result $items)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let plan = P::List(Box::new(P::Tuple(vec![P::String, P::U8])));
    let (engine, component) = compile(
        &guest,
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    let bytes = |result: bool| {
        let mut data = Vec::new();
        let fields = if result {
            [(64_u32, 1_u32, 10_u8), (65, 3, 8)]
        } else {
            [(64_u32, 3_u32, 7_u8), (67, 1, 9)]
        };
        for (ptr, count, byte) in fields {
            data.extend_from_slice(&ptr.to_le_bytes());
            data.extend_from_slice(&count.to_le_bytes());
            data.extend_from_slice(&[byte, 0, 0, 0]);
        }
        data.extend_from_slice(if result {
            "Qあ".as_bytes()
        } else {
            "あQ".as_bytes()
        });
        reference_input(&data, 2, 116)
    };
    assert_eq!(
        call(&engine, &component, &bytes(false)).unwrap(),
        bytes(true)
    );
    for offset in [49, 50, 51, 61, 62, 63] {
        let mut malformed = bytes(false);
        malformed[offset] = 1;
        let err = call(&engine, &component, &malformed).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}
