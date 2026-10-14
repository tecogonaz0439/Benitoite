//! 場合の選択と合流、可変長の子の順序を独立したゲストで検査する（設計書 03-10「型の対応」）。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::fixed_tests::{MEMORY, call, compile, core_call, input};
use super::runtime::reported_failure;
use crate::external::WitPlan as P;

#[test]
fn variant_cases_join_numeric_bits_and_zero_unused_slots() {
    // 関門: 同じ位置の整数・浮動小数点の合流を、数値変換ではなく独立したビットで検査する。
    // ホスト codec と配置の試験は、生成した平らな引数や選択分岐を実行しない。
    let guest = format!(
        r#"(component (core module $m {MEMORY}
        (func (export "run") (param $case i32) (param $value i64) (param $second i32) (result i32)
            i32.const 1024 i32.const 204 i32.const 16 memory.fill
            local.get $case i32.const 0 i32.eq if
                local.get $value i64.eqz i32.eqz if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 5 i32.store8
                i32.const 1032 i32.const 13 i32.store16
                i32.const 1034 i32.const 17 i32.store8
            end
            local.get $case i32.const 1 i32.eq if
                local.get $value i64.const 4294967289 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 1 i32.store8
                i32.const 1032 i32.const -8 i32.store
            end
            local.get $case i32.const 2 i32.eq if
                local.get $value i64.const 2147483648 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 2 i32.store8
                i32.const 1032 f32.const -1.5 f32.store
            end
            local.get $case i32.const 3 i32.eq if
                local.get $value i64.const 4609434218613702656 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 3 i32.store8
                i32.const 1032 f64.const -1.5 f64.store
            end
            local.get $case i32.const 4 i32.eq if
                local.get $value i64.const -9223372036854775808 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 4 i32.store8
                i32.const 1032 i64.const -9223372036854775807 i64.store
            end
            local.get $case i32.const 5 i32.eq if
                local.get $value i64.const 9 i64.ne if unreachable end
                local.get $second i32.const 11 i32.ne if unreachable end
                i32.const 1024 i32.const 0 i32.store8
            end
            i32.const 1024))
        (core instance $i (instantiate $m)) (type $p (tuple u16 u8))
        (type $v0 (variant (case "empty") (case "signed" s32) (case "single" f32)
            (case "double" f64) (case "wide" u64) (case "pair" $p)))
        (export $v "value-type" (type $v0))
        (func (export "run") (param "x" $v) (result $v)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let plan = P::Variant {
        cases: vec![
            ("empty".into(), 99, None),
            ("signed".into(), 7, Some(Box::new(P::S32))),
            ("single".into(), 8, Some(Box::new(P::F32))),
            ("double".into(), 9, Some(Box::new(P::F64))),
            ("wide".into(), 10, Some(Box::new(P::U64))),
            (
                "pair".into(),
                11,
                Some(Box::new(P::TupleFields(vec![P::U16, P::U8]))),
            ),
        ],
    };
    let (engine, component) = compile(
        &guest,
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    for (case, value, result_case, result) in [
        (0, vec![], 5, vec![13, 0, 17]),
        (
            1,
            (-7_i32).to_le_bytes().to_vec(),
            1,
            (-8_i32).to_le_bytes().to_vec(),
        ),
        (
            2,
            0x8000_0000_u32.to_le_bytes().to_vec(),
            2,
            (-1.5_f32).to_le_bytes().to_vec(),
        ),
        (
            3,
            1.5_f64.to_le_bytes().to_vec(),
            3,
            (-1.5_f64).to_le_bytes().to_vec(),
        ),
        (
            4,
            0x8000_0000_0000_0000_u64.to_le_bytes().to_vec(),
            4,
            0x8000_0000_0000_0001_u64.to_le_bytes().to_vec(),
        ),
        (5, vec![9, 0, 11], 0, vec![]),
    ] {
        let mut payload = vec![0; 16];
        payload[0] = case;
        payload[8..8 + value.len()].copy_from_slice(&value);
        let mut expected = vec![0; 16];
        expected[0] = result_case;
        expected[8..8 + result.len()].copy_from_slice(&result);
        assert_eq!(
            call(&engine, &component, &input(&payload, 1, 128)).unwrap(),
            input(&expected, 1, 128)
        );
    }
    // 不正な判別子・非選択の領域・詰め物は、ゲストによる別の trap になる前に拒否する。
    for (case, position) in [
        (6, None),
        (0, Some(8)),
        (1, Some(12)),
        (1, Some(1)),
        (5, Some(11)),
    ] {
        let mut payload = vec![0; 16];
        payload[0] = case;
        if let Some(position) = position {
            payload[position] = 1;
        }
        let err = call(&engine, &component, &input(&payload, 1, 128)).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}

pub(super) fn pair_variant_guest() -> String {
    format!(
        r#"(component (core module $m {MEMORY}
        (func (export "run") (result i32)
            i32.const 1024 i32.const 0 i32.store8
            i32.const 1028 i32.const 7 i32.store
            i32.const 1032 i32.const 11 i32.store i32.const 1024))
        (core instance $i (instantiate $m)) (type $p (tuple u32 u32))
        (type $v0 (variant (case "pair" $p))) (export $v "value-type" (type $v0))
        (func (export "run") (result $v)
            (canon lift (core func $i "run") (memory (core memory $i "memory")))))"#
    )
}

#[test]
fn single_and_distributed_payloads_charge_only_language_constructors() {
    // 関門: 同じ WIT の結果でも One(Pair) は 64、Two は 48 バイトとして数える。
    // ホストの費用の試験だけでは、補助が確保前にこの違いを反映することを確かめられない。
    for (payload, cost) in [
        (P::Tuple(vec![P::U32, P::U32]), 64),
        (P::TupleFields(vec![P::U32, P::U32]), 48),
    ] {
        let plan = P::Variant {
            cases: vec![("pair".into(), 42, Some(Box::new(payload)))],
        };
        let (engine, component) = compile(&pair_variant_guest(), &[], &[plan]);
        for limit in [48, 63, 64] {
            let result = call(&engine, &component, &input(&[], 0, limit));
            if limit < cost {
                let err = result.unwrap_err();
                let report = reported_failure(&err).unwrap();
                assert_eq!(
                    (report.number, report.requested, report.limit),
                    (4, cost, limit)
                );
            } else {
                assert_eq!(
                    result.unwrap(),
                    input(&[0, 0, 0, 0, 7, 0, 0, 0, 11, 0, 0, 0], 1, limit)
                );
            }
        }
    }
}

#[test]
fn selected_references_reserve_depth_first_in_declaration_order() {
    // 関門: リストの全固定部を先に予約し、選んだ場合の文字列と子のリストだけを宣言順に辿る。
    // 場合の選択と親のループが互いの作業領域を壊す退行は、単純なリストの試験では見つからない。
    let guest = format!(
        r#"(component (core module $m {MEMORY}
        (func (export "run") (param $p i32) (param $len i32) (result i32)
            local.get $len i32.const 3 i32.ne if unreachable end
            local.get $p i32.load8_u i32.const 2 i32.ne if unreachable end
            local.get $p i32.load offset=4 i32.load8_u i32.const 65 i32.ne if unreachable end
            local.get $p i32.load offset=12 i32.load i32.load8_u i32.const 120 i32.ne if unreachable end
            local.get $p i32.load offset=12 i32.load offset=8 i32.load8_u i32.const 121 i32.ne if unreachable end
            local.get $p i32.load8_u offset=20 i32.const 1 i32.ne if unreachable end
            local.get $p i32.load offset=24 i32.load8_u i32.const 112 i32.ne if unreachable end
            local.get $p i32.load8_u offset=40 if unreachable end
            i32.const 4096 local.get $p i32.const 20 i32.add i32.const 20 memory.copy
            i32.const 4116 local.get $p i32.const 40 i32.add i32.const 20 memory.copy
            i32.const 4136 local.get $p i32.const 20 memory.copy
            local.get $p i32.load offset=24 i32.const 82 i32.store8
            local.get $p i32.load offset=4 i32.const 66 i32.store8
            i32.const 1024 i32.const 4096 i32.store
            i32.const 1028 i32.const 3 i32.store i32.const 1024))
        (core instance $i (instantiate $m)) (type $strings (list string))
        (type $p (tuple string $strings))
        (type $v0 (variant (case "empty") (case "text" string) (case "pair" $p)))
        (export $v "value-type" (type $v0)) (type $list (list $v))
        (func (export "run") (param "xs" $list) (result $list)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let plan = P::List(Box::new(P::Variant {
        cases: vec![
            ("empty".into(), 9, None),
            ("text".into(), 8, Some(Box::new(P::String))),
            (
                "pair".into(),
                7,
                Some(Box::new(P::TupleFields(vec![
                    P::String,
                    P::List(Box::new(P::String)),
                ]))),
            ),
        ],
    }));
    let (engine, component) = compile(
        &guest,
        std::slice::from_ref(&plan),
        std::slice::from_ref(&plan),
    );
    let bytes = |result: bool, limit| {
        let mut data = vec![0; if result { 91 } else { 93 }];
        let mut put = |position: usize, value: u32| {
            data[position - 32..position - 28].copy_from_slice(&value.to_le_bytes())
        };
        put(32, 40);
        put(36, 3);
        if result {
            put(40, 1);
            put(44, 100);
            put(48, 2);
            put(80, 2);
            put(84, 102);
            put(88, 1);
            put(92, 104);
            put(96, 2);
        } else {
            put(40, 2);
            put(44, 100);
            put(48, 1);
            put(52, 104);
            put(56, 2);
            put(60, 1);
            put(64, 123);
            put(68, 2);
        }
        put(104, 120);
        put(108, 1);
        put(112, 121);
        put(116, 2);
        if result {
            data[68..71].copy_from_slice(b"RqB");
            data[88..91].copy_from_slice(b"xyz");
        } else {
            data[68] = b'A';
            data[88..93].copy_from_slice(b"xyzpq");
        }
        input(&data, 1, limit)
    };
    assert_eq!(
        call(&engine, &component, &bytes(false, 150)).unwrap(),
        bytes(true, 150)
    );
    let err = call(&engine, &component, &bytes(false, 149)).unwrap_err();
    let report = reported_failure(&err).unwrap();
    assert_eq!(
        (report.number, report.requested, report.limit),
        (3, 150, 149)
    );
    // 参照先の順序の入れ替えと、空の場合に残したポインタも形式として拒否する。
    for (position, value) in [(44, 123_u32), (64, 100), (84, 100), (112, 120)] {
        let mut malformed = bytes(false, 150);
        malformed[position..position + 4].copy_from_slice(&value.to_le_bytes());
        let err = call(&engine, &component, &malformed).unwrap_err();
        assert_eq!(reported_failure(&err).unwrap().number, 7);
    }
}

#[test]
fn result_memory_copies_only_selected_leaves_and_rejects_invalid_discriminants() {
    // 関門: canon lower による値の検査を経ないコアの結果でも、非選択領域と詰め物を写さない。
    // 不正な判別子を、Wasm の trap ではなく補助の形式の不一致で止める契約も守る。
    let plan = P::Variant {
        cases: vec![
            ("small".into(), 7, Some(Box::new(P::U8))),
            ("wide".into(), 8, Some(Box::new(P::U64))),
            ("empty".into(), 9, None),
        ],
    };
    let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
    let support = wasmtime::Module::from_binary(
        &engine,
        &super::emit::memory_module(1, None).unwrap().finish(),
    )
    .unwrap();
    let adapter = wasmtime::Module::from_binary(
        &engine,
        &super::emit::fixed_module(&[], &[plan]).unwrap().finish(),
    )
    .unwrap();
    for case in [0, 1, 2, 3] {
        let guest = format!(
            r#"(module (import "support" "memory" (memory 1))
            (func (export "run") (param $result i32)
                local.get $result i32.const 204 i32.const 16 memory.fill
                local.get $result i32.const {case} i32.store8
                local.get $result i32.const 8 i32.add i64.const 17 i64.store))"#
        );
        let guest = wasmtime::Module::new(&engine, wat::parse_str(&guest).unwrap()).unwrap();
        let result = core_call(&engine, &support, &guest, &adapter, &input(&[], 0, 64));
        if case == 3 {
            let err = result.unwrap_err();
            assert_eq!(reported_failure(&err).unwrap().number, 7);
        } else {
            let mut payload = vec![0; 16];
            payload[0] = case;
            if case < 2 {
                payload[8] = 17;
            }
            assert_eq!(result.unwrap(), input(&payload, 1, 64));
        }
    }
}

#[test]
fn nested_variants_join_i32_and_f32_and_keep_multiple_arguments_separate() {
    // 関門: 内側の f32/i32 の合流と、外側の i32/f64 の合流を別々のビット変換として守る。
    // 複数の根の次の引数も検査し、場合の平らな幅で後続の欄をずらす退行を捕まえる。
    let guest = format!(
        r#"(component (core module $m {MEMORY}
        (func (export "run") (param $outer i32) (param $kind i64) (param $bits i32) (param $n i32) (result i32)
            local.get $outer if unreachable end
            local.get $n i32.const 13 i32.ne if unreachable end
            local.get $kind i64.eqz if
                local.get $bits i32.const -2147483648 i32.ne if unreachable end
            else
                local.get $kind i64.const 1 i64.ne if unreachable end
                local.get $bits i32.const -1 i32.ne if unreachable end
            end
            i32.const 1024 i32.const 0 i32.store8
            i32.const 1032 i32.const 0 i32.store8
            i32.const 1036 local.get $n f32.convert_i32_u f32.store
            i32.const 1024))
        (core instance $i (instantiate $m))
        (type $inner0 (variant (case "number" f32) (case "bits" u32)))
        (export $inner "inner-type" (type $inner0))
        (type $outer0 (variant (case "wrapped" $inner) (case "wide" f64)))
        (export $outer "outer-type" (type $outer0))
        (func (export "run") (param "x" $outer) (param "n" u16) (result $outer)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#
    );
    let inner = P::Variant {
        cases: vec![
            ("number".into(), 5, Some(Box::new(P::F32))),
            ("bits".into(), 6, Some(Box::new(P::U32))),
        ],
    };
    let outer = P::Variant {
        cases: vec![
            ("wrapped".into(), 7, Some(Box::new(inner))),
            ("wide".into(), 8, Some(Box::new(P::F64))),
        ],
    };
    let (engine, component) = compile(&guest, &[outer.clone(), P::U16], &[outer]);
    for (case, bits) in [(0, 0x8000_0000_u32), (1, u32::MAX)] {
        let mut payload = vec![0; 24];
        payload[8] = case;
        payload[12..16].copy_from_slice(&bits.to_le_bytes());
        payload[16] = 13;
        let mut expected = vec![0; 16];
        expected[12..16].copy_from_slice(&13.0_f32.to_le_bytes());
        assert_eq!(
            call(&engine, &component, &input(&payload, 2, 64)).unwrap(),
            input(&expected, 1, 64)
        );
    }
}

#[test]
fn options_and_unit_result_sides_select_fields_and_charge_unit_values() {
    // 関門: Option の無い側を省き、Result の省略した Unit の欄は言語の値として数える。
    // 転送量 40 より構築量が大きい組にし、Unit の費用を落とす退行を予算の境界で捕まえる。
    for (result_type, ok, err) in [
        ("(error u16)", None, Some(Box::new(P::U16))),
        ("u16", Some(Box::new(P::U16)), None),
    ] {
        let guest = format!(
            r#"(component (core module $m {MEMORY}
            (func (export "run") (param $option i32) (param $n i32) (param $result i32) (param $value i32) (result i32)
                local.get $option i32.const 1 i32.gt_u if unreachable end
                local.get $n local.get $option i32.const 9 i32.mul i32.ne if unreachable end
                local.get $result i32.const 1 i32.gt_u if unreachable end
                local.get $value local.get $result {unit_case} i32.xor i32.const 11 i32.mul i32.ne if unreachable end
                i32.const 1024 local.get $option i32.eqz i32.store8
                i32.const 1026 local.get $option i32.eqz i32.const 9 i32.mul i32.store16
                i32.const 1028 local.get $result i32.eqz i32.store8
                i32.const 1030 local.get $result i32.eqz {unit_case} i32.xor i32.const 11 i32.mul i32.store16
                i32.const 1024))
            (core instance $i (instantiate $m)) (type $option (option u16))
            (type $result (result {result_type})) (type $pair (tuple $option $result))
            (func (export "run") (param "x" $pair) (result $pair)
                (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))"#,
            unit_case = if ok.is_none() {
                "i32.const 0"
            } else {
                "i32.const 1"
            }
        );
        let plan = P::Tuple(vec![P::Option(Box::new(P::U16)), P::Result { ok, err }]);
        let (engine, component) = compile(
            &guest,
            std::slice::from_ref(&plan),
            std::slice::from_ref(&plan),
        );
        for option in [0, 1] {
            for result_case in [0, 1] {
                let non_unit = if result_type == "u16" {
                    result_case == 0
                } else {
                    result_case == 1
                };
                let payload = [
                    option,
                    0,
                    option * 9,
                    0,
                    result_case,
                    0,
                    if non_unit { 11 } else { 0 },
                    0,
                ];
                let expected = [
                    1 - option,
                    0,
                    (1 - option) * 9,
                    0,
                    1 - result_case,
                    0,
                    if non_unit { 0 } else { 11 },
                    0,
                ];
                assert_eq!(
                    call(&engine, &component, &input(&payload, 1, 80)).unwrap(),
                    input(&expected, 1, 80)
                );
                let err = call(&engine, &component, &input(&payload, 1, 79)).unwrap_err();
                let report = reported_failure(&err).unwrap();
                assert_eq!(
                    (report.number, report.requested, report.limit),
                    (if option == 1 { 3 } else { 4 }, 80, 79)
                );
            }
        }
    }
}
