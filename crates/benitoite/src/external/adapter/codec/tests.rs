//! 転送形式のバイト列、検査前の確保の禁止と、言語の構築予算を確かめる。

// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::external::WitPlan as P;
use crate::runtime::heap::{CheckedLen, Heap, HeapConfig};

fn plan(plans: &[P]) -> CodecPlan<'_> {
    CodecPlan::new(plans, &mut 100_000).unwrap()
}
fn hex(text: &str) -> Vec<u8> {
    text.split_whitespace()
        .map(|s| u8::from_str_radix(s, 16).unwrap())
        .collect()
}
fn expected(roots: u32, limit: u64, body: &[u8]) -> Vec<u8> {
    // 本番のヘッダの位置・幅の定数や書き込み関数に依存せず、版の契約を組み立てる。
    let mut bytes = b"BNTW".to_vec();
    bytes.extend(1_u32.to_le_bytes());
    bytes.extend(u32::try_from(32 + body.len()).unwrap().to_le_bytes());
    bytes.extend(roots.to_le_bytes());
    bytes.extend(limit.to_le_bytes());
    bytes.extend(limit.to_le_bytes());
    bytes.extend(body);
    bytes
}
fn ctor<'e>(ctx: &NoGcCtx<'e>, tag: u32, fields: &[Value<'e>]) -> Value<'e> {
    ctx.alloc_fields(FieldsKind::Ctor, tag, fields).unwrap()
}
fn bytes<'e>(ctx: &NoGcCtx<'e>, content: &[u8]) -> Value<'e> {
    ctx.alloc_bytes_with(
        CheckedLen::bytes(content.len() as u64, "test").unwrap(),
        |dst| dst.copy_from_slice(content),
    )
    .unwrap()
}
fn limited(error: WireError) -> CodecError {
    CodecError::Wire(error)
}

#[test]
fn root_counts_numeric_bits_and_transfer_boundary_match_independent_bytes() {
    // 関門: 書き込みの入口でヘッダ・幅・整列・ビット列を守る。動的変換と配置だけの試験では
    // ヘッダのずれや NaN の数値変換を捕まえない。新しい本番の差し込み口は不要である。
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let empty = plan(&[]).encode(ctx, &[], 32).unwrap();
        let decoded = plan(&[]).decode(ctx, &expected(0, 32, &[]), 32).unwrap();
        assert!(decoded.values.is_empty());
        assert_eq!(decoded.construction_bytes, 0);
        assert_eq!(empty.bytes, expected(0, 32, &[]));
        assert_eq!(empty.construction_bytes, 0);
        assert_eq!(
            plan(&[]).encode(ctx, &[], 31),
            Err(limited(WireError::TransferLimit))
        );
        assert_eq!(
            plan(&[P::U8])
                .encode(ctx, &[Value::Byte(255)], 33)
                .unwrap()
                .bytes,
            expected(1, 33, &[255])
        );
        assert_eq!(
            plan(&[P::U8]).encode(ctx, &[Value::Byte(255)], 32),
            Err(limited(WireError::TransferLimit))
        );
        let text = ctx.alloc_str("字", "test").unwrap();
        assert_eq!(
            plan(&[P::String]).encode(ctx, &[text], 43).unwrap().bytes,
            expected(1, 43, &hex("28 00 00 00 03 00 00 00 e5 ad 97"))
        );
        assert_eq!(
            plan(&[P::String]).encode(ctx, &[text], 42),
            Err(limited(WireError::TransferLimit))
        );
        let ps = [
            P::S8,
            P::U8,
            P::S16,
            P::U16,
            P::S32,
            P::U32,
            P::S64,
            P::U64,
            P::F32,
            P::F64,
            P::Bool,
            P::Char,
        ];
        let values = [
            Value::Int8(-128),
            Value::Byte(255),
            Value::Int16(-32768),
            Value::UInt16(65535),
            Value::Int32(i32::MIN),
            Value::UInt32(u32::MAX),
            Value::Int(i64::MIN),
            Value::UInt64(u64::MAX),
            Value::Float32(f32::from_bits(0xffc0_1234)),
            Value::Float(-0.0),
            Value::Bool(true),
            Value::Char('字'),
        ];
        let encoded = plan(&ps).encode(ctx, &values, 256).unwrap();
        let body = hex("80 ff 00 80 ff ff 00 00 00 00 00 80 ff ff ff ff
            00 00 00 00 00 00 00 80 ff ff ff ff ff ff ff ff
            34 12 c0 ff 00 00 00 00 00 00 00 00 00 00 00 80
            01 00 00 00 57 5b 00 00");
        assert_eq!(encoded.bytes, expected(12, 256, &body));
        assert_eq!(encoded.construction_bytes, 192);
        let decoded = plan(&ps)
            .decode(ctx, &expected(12, 256, &body), 256)
            .unwrap();
        assert_eq!(decoded.construction_bytes, 192);
        for (actual, expected) in decoded.values.iter().zip(values) {
            match (actual, expected) {
                (Value::Float32(a), Value::Float32(b)) => assert_eq!(a.to_bits(), b.to_bits()),
                (Value::Float(a), Value::Float(b)) => assert_eq!(a.to_bits(), b.to_bits()),
                (actual, expected) => {
                    assert!(crate::runtime::equal::values_equal(ctx, *actual, expected).unwrap())
                }
            }
        }
        assert_eq!(
            plan(&ps).encode(ctx, &values, 191),
            Err(limited(WireError::ConstructionLimit))
        );
        assert!(plan(&ps).encode(ctx, &values, 192).is_ok());
    });
}

#[test]
fn header_and_zero_regions_reject_corruption() {
    // 関門: 復号の入口が信用してよいヘッダの範囲を独立した入力で固定する。
    let good = expected(2, 64, &[0; 8]);
    assert_eq!(
        Header::read(&good, 2, 64).unwrap(),
        Header {
            length: 40,
            roots: 2,
            limit: 64
        }
    );
    for offset in [0, 4, 8, 12, 16, 24] {
        let mut bad = good.clone();
        bad[offset] ^= 1;
        assert!(
            matches!(Header::read(&bad, 2, 64), Err(WireError::Internal(_))),
            "offset {offset}"
        );
    }
    for offset in [4, 16, 24] {
        let mut bad = good.clone();
        bad[offset] = 255;
        assert!(matches!(
            Header::read(&bad, 2, 64),
            Err(WireError::Internal(_))
        ));
    }
    for end in 0..good.len() {
        assert!(Header::read(&good[..end], 2, 64).is_err());
    }
    let mut trailing = good.clone();
    trailing.push(0);
    assert!(Header::read(&trailing, 2, 64).is_err());
    assert!(Header::read(&good, 1, 64).is_err());
    assert!(Header::read(&good, 2, 65).is_err());
    assert_eq!(
        Header::read(&expected(2, 39, &[0; 8]), 2, 39),
        Err(WireError::TransferLimit)
    );
    assert!(wire::require_zero(&[0; 17]).is_ok());
    for position in 0..17 {
        let mut bad = [0; 17];
        bad[position] = 1;
        assert!(matches!(
            wire::require_zero(&bad),
            Err(WireError::Internal(_))
        ));
    }
    assert_eq!(wire::range(&good, u32::MAX, 1), Err(WireError::Memory32));
}

#[test]
fn references_reserve_all_elements_then_visit_children_in_declaration_order() {
    // 関門: 配列の固定部を先に予約し、空の参照と動的な子の深さ優先の順を守る。
    // 生成器と同じ往復を使わず、参照先を手計算する。
    let ps = [P::String, P::List(Box::new(P::String)), P::Bytes, P::String];
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let text = ctx.alloc_str("字", "test").unwrap();
        let empty = ctx.alloc_str("", "test").unwrap();
        let a = ctx.alloc_str("a", "test").unwrap();
        let b = ctx.alloc_str("bc", "test").unwrap();
        let strings = list::from_values(ctx, &[a, empty, b], "test").unwrap();
        let vs = [text, strings, bytes(ctx, &[0xff, 0]), empty];
        let encoded = plan(&ps).encode(ctx, &vs, 256).unwrap();
        let body = hex("40 00 00 00 03 00 00 00 44 00 00 00 03 00 00 00
            5f 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00
            e5 ad 97 00
            5c 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00
            5d 00 00 00 02 00 00 00 61 62 63 ff 00");
        assert_eq!(encoded.bytes, expected(4, 256, &body));
        assert_eq!(encoded.construction_bytes, 120);
        assert!(plan(&ps).encode(ctx, &vs, 120).is_ok());
        assert_eq!(
            plan(&ps).encode(ctx, &vs, 119),
            Err(limited(WireError::ConstructionLimit))
        );
        for p in [
            P::List(Box::new(P::U8)),
            P::Map(Box::new(P::String), Box::new(P::U8)),
        ] {
            let v = if matches!(p, P::List(_)) {
                Value::EmptyList
            } else {
                Value::EmptyMap
            };
            let ps = [p.clone()];
            let decoded = plan(&ps)
                .decode(ctx, &expected(1, 40, &[0; 8]), 40)
                .unwrap();
            assert!(crate::runtime::equal::values_equal(ctx, decoded.values[0], v).unwrap());
            assert_eq!(
                plan(&[p]).encode(ctx, &[v], 40).unwrap().bytes,
                expected(1, 40, &[0; 8])
            );
        }
    });
}

#[test]
fn map_keys_and_flags_use_wit_order_and_no_intermediate_values() {
    // 関門: map の組の ABI 専用の費用を加えず、鍵の順と幅・flags の WIT の順を守る。
    let ps = [
        P::Map(Box::new(P::U8), Box::new(P::String)),
        P::Flags {
            cases: vec![
                ("last-tag".into(), 9),
                ("first-tag".into(), 2),
                ("middle-tag".into(), 5),
            ],
        },
    ];
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let a = ctx.alloc_str("A", "test").unwrap();
        let b = ctx.alloc_str("B", "test").unwrap();
        let mut m = map::map_insert(ctx, Value::EmptyMap, Value::Byte(2), b, "test").unwrap();
        m = map::map_insert(ctx, m, Value::Byte(1), a, "test").unwrap();
        let mut set =
            map::set_insert(ctx, Value::EmptySet, Value::Tag(CtorTag(9)), "test").unwrap();
        set = map::set_insert(ctx, set, Value::Tag(CtorTag(5)), "test").unwrap();
        let result = plan(&ps).encode(ctx, &[m, set], 256).unwrap();
        let body = hex("2c 00 00 00 02 00 00 00 05 00 00 00
            01 00 00 00 44 00 00 00 01 00 00 00
            02 00 00 00 45 00 00 00 01 00 00 00 41 42");
        assert_eq!(result.bytes, expected(2, 256, &body));
        assert_eq!(result.construction_bytes, 130);
        assert!(plan(&ps).encode(ctx, &[m, set], 130).is_ok());
        assert_eq!(
            plan(&ps).encode(ctx, &[m, set], 129),
            Err(limited(WireError::ConstructionLimit))
        );
        for (count, selected, body) in [
            (8, 7, hex("80")),
            (16, 15, hex("00 80")),
            (32, 31, hex("00 00 00 80")),
        ] {
            let p = P::Flags {
                cases: (0..count).map(|i| (format!("f{i}"), 100 - i)).collect(),
            };
            let set = map::set_insert(
                ctx,
                Value::EmptySet,
                Value::Tag(CtorTag(100 - selected)),
                "test",
            )
            .unwrap();
            let output = plan(std::slice::from_ref(&p))
                .encode(ctx, &[set], 64)
                .unwrap();
            assert_eq!(output.bytes, expected(1, 64, &body));
            assert_eq!(output.construction_bytes, 32);
            let ps = [p.clone()];
            let decoded = plan(&ps).decode(ctx, &expected(1, 64, &body), 64).unwrap();
            assert_eq!(decoded.construction_bytes, 32);
            assert!(crate::runtime::equal::values_equal(ctx, decoded.values[0], set).unwrap());
        }
    });
}

#[test]
fn same_wit_shapes_have_declaration_specific_construction_costs() {
    // 関門: 同じ ABI の配置だけで補助を共有すると、Bytes と List[Byte] または構成子の
    // 包み方の費用を取り違える。小さい独立した期待値と上限でその退行を捕まえる。
    let bytes_p = [P::Bytes];
    let list_p = [P::List(Box::new(P::U8))];
    let one_p = [P::Variant {
        cases: vec![(
            "value".into(),
            37,
            Some(Box::new(P::Tuple(vec![P::U8, P::U8]))),
        )],
    }];
    let two_p = [P::Variant {
        cases: vec![(
            "value".into(),
            38,
            Some(Box::new(P::TupleFields(vec![P::U8, P::U8]))),
        )],
    }];
    let renamed_p = [P::Variant {
        cases: vec![(
            "value".into(),
            99,
            Some(Box::new(P::TupleFields(vec![P::U8, P::U8]))),
        )],
    }];
    let one = plan(&one_p);
    let two = plan(&two_p);
    let renamed = plan(&renamed_p);
    assert_eq!(one.layout, two.layout);
    assert_ne!(one.construction, two.construction);
    assert_eq!(two.layout, renamed.layout);
    assert_eq!(two.construction, renamed.construction);
    assert_ne!(plan(&bytes_p).construction, plan(&list_p).construction);
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let data = bytes(ctx, &[7, 8]);
        let list = list::from_values(ctx, &[Value::Byte(7), Value::Byte(8)], "test").unwrap();
        let expected_body = hex("28 00 00 00 02 00 00 00 07 08");
        let b = plan(&bytes_p).encode(ctx, &[data], 48).unwrap();
        let l = plan(&list_p).encode(ctx, &[list], 48).unwrap();
        assert_eq!(b.bytes, expected(1, 48, &expected_body));
        assert_eq!(l.bytes, expected(1, 48, &expected_body));
        assert_eq!((b.construction_bytes, l.construction_bytes), (18, 48));
        let b = plan(&bytes_p)
            .decode(ctx, &expected(1, 48, &expected_body), 48)
            .unwrap();
        let l = plan(&list_p)
            .decode(ctx, &expected(1, 48, &expected_body), 48)
            .unwrap();
        assert_eq!(ctx.bytes(b.values[0]), Some(&[7, 8][..]));
        assert!(crate::runtime::equal::values_equal(ctx, l.values[0], list).unwrap());
        assert_eq!((b.construction_bytes, l.construction_bytes), (18, 48));
        assert!(plan(&bytes_p).encode(ctx, &[data], 47).is_ok());
        assert_eq!(
            plan(&list_p).encode(ctx, &[list], 47),
            Err(limited(WireError::ConstructionLimit))
        );
        let pair = ctor(ctx, tags::PAIR, &[Value::Byte(7), Value::Byte(8)]);
        let one_v = ctor(ctx, 37, &[pair]);
        let two_v = ctor(ctx, 38, &[Value::Byte(7), Value::Byte(8)]);
        for (p, value, cost) in [(&one, one_v, 64), (&two, two_v, 48)] {
            let decoded = p.decode(ctx, &expected(1, 64, &[0, 7, 8]), 64).unwrap();
            assert!(crate::runtime::equal::values_equal(ctx, decoded.values[0], value).unwrap());
            assert_eq!(ctx.fields_len(decoded.values[0]), ctx.fields_len(value));
            assert_eq!(decoded.construction_bytes, cost);
        }
        let one_result = one.encode(ctx, &[one_v], 64).unwrap();
        let two_result = two.encode(ctx, &[two_v], 64).unwrap();
        assert_eq!(one_result.bytes, expected(1, 64, &[0, 7, 8]));
        assert_eq!(two_result.bytes, expected(1, 64, &[0, 7, 8]));
        assert_eq!(
            (one_result.construction_bytes, two_result.construction_bytes),
            (64, 48)
        );
        assert_eq!(
            one.encode(ctx, &[one_v], 63),
            Err(limited(WireError::ConstructionLimit))
        );
        assert!(two.encode(ctx, &[two_v], 48).is_ok());
        assert_eq!(
            two.encode(ctx, &[two_v], 47),
            Err(limited(WireError::ConstructionLimit))
        );
        assert_eq!(
            renamed
                .encode(ctx, &[ctor(ctx, 99, &[Value::Byte(7), Value::Byte(8)])], 64)
                .unwrap(),
            two_result
        );
    });
}

#[test]
fn selected_payloads_zero_unused_regions_and_count_actual_fields() {
    // 関門: 非選択の欄を数えず零で残し、複数引数の ABI tuple と Result の省略した
    // Unit の欄の費用を区別する。配列の要素が零バイトでも言語の値は数える。
    let variant = P::Variant {
        cases: vec![
            ("empty".into(), 9, None),
            ("small".into(), 7, Some(Box::new(P::U8))),
            (
                "many".into(),
                8,
                Some(Box::new(P::TupleFields(vec![P::U8, P::U64]))),
            ),
        ],
    };
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (p, v, body, cost) in [
            (variant.clone(), Value::Tag(CtorTag(9)), vec![0; 24], 16),
            (
                variant.clone(),
                ctor(ctx, 7, &[Value::Byte(5)]),
                {
                    let mut b = vec![0; 24];
                    b[0] = 1;
                    b[8] = 5;
                    b
                },
                32,
            ),
            (
                variant,
                ctor(ctx, 8, &[Value::Byte(5), Value::UInt64(9)]),
                hex("02 00 00 00 00 00 00 00 05 00 00 00 00 00 00 00 09 00 00 00 00 00 00 00"),
                48,
            ),
            (
                P::Option(Box::new(P::U64)),
                Value::Tag(CtorTag(tags::OPTION_NONE)),
                vec![0; 16],
                16,
            ),
            (
                P::Option(Box::new(P::U64)),
                ctor(ctx, tags::OPTION_SOME, &[Value::UInt64(9)]),
                hex("01 00 00 00 00 00 00 00 09 00 00 00 00 00 00 00"),
                32,
            ),
            (
                P::Result {
                    ok: None,
                    err: Some(Box::new(P::String)),
                },
                ctor(ctx, tags::RESULT_OK, &[Value::Unit]),
                vec![0; 12],
                32,
            ),
            (
                P::Result {
                    ok: Some(Box::new(P::U8)),
                    err: None,
                },
                ctor(ctx, tags::RESULT_OK, &[Value::Byte(5)]),
                vec![0, 5],
                32,
            ),
            (
                P::Result {
                    ok: Some(Box::new(P::U8)),
                    err: None,
                },
                ctor(ctx, tags::RESULT_ERROR, &[Value::Unit]),
                vec![1, 0],
                32,
            ),
            (
                P::Enum {
                    cases: vec![("a".into(), 3), ("b".into(), 1)],
                },
                Value::Tag(CtorTag(1)),
                vec![1],
                16,
            ),
            (
                P::Tuple(vec![P::U8, P::U16, P::U8]),
                ctor(
                    ctx,
                    tags::TRIPLE,
                    &[Value::Byte(1), Value::UInt16(2), Value::Byte(3)],
                ),
                hex("01 00 02 00 03 00"),
                64,
            ),
            (
                P::Record {
                    fields: vec![("x".into(), P::U8), ("y".into(), P::U32)],
                },
                ctor(ctx, tags::RECORD, &[Value::Byte(1), Value::UInt32(2)]),
                hex("01 00 00 00 02 00 00 00"),
                48,
            ),
        ] {
            let result = plan(std::slice::from_ref(&p))
                .encode(ctx, &[v], 128)
                .unwrap();
            assert_eq!(result.bytes, expected(1, 128, &body));
            // 独立したバイト列から、タグと欄を含む実際の言語の値を復元する。
            let ps = [p.clone()];
            let decoded = plan(&ps)
                .decode(ctx, &expected(1, 128, &body), 128)
                .unwrap();
            assert!(crate::runtime::equal::values_equal(ctx, decoded.values[0], v).unwrap());
            assert_eq!(ctx.fields_header(decoded.values[0]), ctx.fields_header(v));
            assert_eq!(decoded.construction_bytes, cost);
            assert_eq!(result.construction_bytes, cost);
        }
        for count in [1, 4, 17] {
            let p = [P::ConstructorTuple {
                tag: 27,
                fields: vec![P::U8; count],
            }];
            let value = ctor(ctx, 27, &vec![Value::Byte(7); count]);
            let result = plan(&p).encode(ctx, &[value], 512).unwrap();
            assert_eq!(result.bytes, expected(1, 512, &vec![7; count]));
            assert_eq!(result.construction_bytes, 16 * (count as u64 + 1));
            let decoded = plan(&p)
                .decode(ctx, &expected(1, 512, &vec![7; count]), 512)
                .unwrap();
            assert!(crate::runtime::equal::values_equal(ctx, decoded.values[0], value).unwrap());
            assert_eq!(decoded.construction_bytes, result.construction_bytes);
        }
        let p = [P::List(Box::new(P::Record { fields: vec![] }))];
        let empty = ctor(ctx, tags::RECORD, &[]);
        let list = list::from_values(ctx, &[empty, empty], "test").unwrap();
        let decoded = plan(&p)
            .decode(ctx, &expected(1, 48, &hex("28 00 00 00 02 00 00 00")), 48)
            .unwrap();
        assert_eq!(decoded.construction_bytes, 48);
        assert!(crate::runtime::equal::values_equal(ctx, decoded.values[0], list).unwrap());
        assert_eq!(
            plan(&p).encode(ctx, &[list], 48).unwrap(),
            Encoded {
                bytes: expected(1, 48, &hex("28 00 00 00 02 00 00 00")),
                construction_bytes: 48
            }
        );
        assert_eq!(
            plan(&p).encode(ctx, &[list], 47),
            Err(limited(WireError::ConstructionLimit))
        );
    });
}

#[test]
fn plan_value_mismatches_are_internal_failures() {
    // 関門: 型付きの値の種類や構成子の欄数を黙って切り詰めない。外部の失敗とは区別する。
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (p, v) in [
            (P::S16, Value::Int8(1)),
            (
                P::Tuple(vec![P::U8, P::U8]),
                ctor(ctx, 99, &[Value::Byte(1), Value::Byte(2)]),
            ),
            (
                P::ConstructorTuple {
                    tag: 7,
                    fields: vec![P::U8],
                },
                ctor(ctx, 7, &[Value::Byte(1), Value::Byte(2)]),
            ),
            (
                P::Option(Box::new(P::U8)),
                ctor(ctx, tags::OPTION_SOME, &[Value::Byte(1), Value::Byte(2)]),
            ),
            (
                P::Result {
                    ok: None,
                    err: None,
                },
                ctor(ctx, tags::RESULT_OK, &[Value::Byte(0)]),
            ),
            (
                P::Enum {
                    cases: vec![("a".into(), 7)],
                },
                ctor(ctx, 7, &[]),
            ),
            (
                P::Flags {
                    cases: vec![("a".into(), 7)],
                },
                map::set_insert(ctx, Value::EmptySet, Value::Tag(CtorTag(8)), "test").unwrap(),
            ),
        ] {
            assert!(matches!(
                plan(&[p]).encode(ctx, &[v], 256),
                Err(CodecError::Wire(WireError::Internal(_)))
            ));
        }
        assert!(matches!(
            plan(&[P::U8]).encode(ctx, &[], 256),
            Err(CodecError::Wire(WireError::Internal(_)))
        ));
    });
}

#[test]
fn deep_values_and_long_lists_use_bounded_cursor_work() {
    // 関門: 型の深さは作業列で、要素数はカーソルで扱う。小さい上限で拒否も確認する。
    let p = (0..80).fold(P::U8, |p, _| P::List(Box::new(p)));
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let mut value = Value::Byte(7);
        for _ in 0..80 {
            value = list::from_values(ctx, &[value], "test").unwrap();
        }
        let encoded = plan(&[p]).encode(ctx, &[value], 1296).unwrap();
        assert_eq!(encoded.construction_bytes, 1296);
        assert_eq!(encoded.bytes.len(), 673);
        assert_eq!(*encoded.bytes.last().unwrap(), 7);
        let input = vec![Value::Byte(3); 5000];
        let list = list::from_values(ctx, &input, "test").unwrap();
        let ps = [P::List(Box::new(P::U8))];
        let encoded = plan(&ps).encode(ctx, &[list], 80_016).unwrap();
        assert_eq!(encoded.construction_bytes, 80_016);
        assert_eq!(
            encoded.bytes,
            expected(
                1,
                80_016,
                &[hex("28 00 00 00 88 13 00 00"), vec![3; 5000]].concat()
            )
        );
        assert_eq!(
            plan(&ps).encode(ctx, &[list], 80_015),
            Err(limited(WireError::ConstructionLimit))
        );
    });
}

fn rejected_before_allocation(ps: &[P], bytes: &[u8], limit: u64) -> CodecError {
    let mut heap = Heap::new(HeapConfig::default());
    let before = heap.stats().allocations;
    let error = heap.epoch(|ctx| plan(ps).decode(ctx, bytes, limit).err().unwrap());
    assert_eq!(heap.stats().allocations, before);
    error
}

#[test]
fn decode_rejects_bad_references_scalars_and_padding_before_any_value_allocation() {
    // 関門: 復号の入口で後続の破損も値の確保前に拒否する。ヘッダや書き込みの試験は
    // 子の検査と確保の順を確かめない。先頭に有効な文字列を置き、一段の逐次復号を捕まえる。
    let ps = [P::String, P::List(Box::new(P::String))];
    let good_body = hex("30 00 00 00 01 00 00 00 34 00 00 00 02 00 00 00
        61 00 00 00 44 00 00 00 01 00 00 00 45 00 00 00 01 00 00 00 62 63");
    let good = expected(2, 256, &good_body);
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let values = plan(&ps).decode(ctx, &good, 256).unwrap();
        assert_eq!(ctx.str(values.values[0]), Some("a"));
        assert_eq!(values.construction_bytes, 67);
        let strings = list::to_vec(ctx, values.values[1]).unwrap();
        assert_eq!(
            strings
                .iter()
                .map(|v| ctx.str(*v).unwrap())
                .collect::<Vec<_>>(),
            ["b", "c"]
        );
    });
    for (offset, value) in [
        (32, 0),
        (36, 0),
        (40, 48),
        (52, 48),
        (60, 68),
        (60, 70),
        (68, 0xff),
        (49, 1),
    ] {
        let mut bad = good.clone();
        bad[offset] = value;
        assert!(
            matches!(
                rejected_before_allocation(&ps, &bad, 256),
                CodecError::Wire(WireError::Internal(_))
            ),
            "offset {offset}"
        );
    }
    let mut trailing = good.clone();
    trailing.push(0);
    let length = trailing.len() as u32;
    trailing[8..12].copy_from_slice(&length.to_le_bytes());
    assert!(matches!(
        rejected_before_allocation(&ps, &trailing, 256),
        CodecError::Wire(WireError::Internal(_))
    ));
    let mut truncated = good.clone();
    truncated.pop();
    let length = truncated.len() as u32;
    truncated[8..12].copy_from_slice(&length.to_le_bytes());
    assert!(
        rejected_before_allocation(&ps, &truncated, 256).eq(&limited(WireError::Internal(
            "adapter wire format mismatch"
        )))
    );

    for (p, body) in [
        (P::Bool, vec![2]),
        (P::Char, 0xd800_u32.to_le_bytes().to_vec()),
        (P::Char, 0x110000_u32.to_le_bytes().to_vec()),
        (
            P::Enum {
                cases: vec![("only".into(), 19)],
            },
            vec![1],
        ),
        (
            P::Flags {
                cases: vec![("only".into(), 19)],
            },
            vec![2],
        ),
        (P::Option(Box::new(P::U64)), {
            let mut v = vec![0; 16];
            v[0] = 2;
            v
        }),
        (P::Option(Box::new(P::U64)), {
            let mut v = vec![0; 16];
            v[8] = 1;
            v
        }),
        (P::Option(Box::new(P::U64)), {
            let mut v = vec![0; 16];
            v[0] = 1;
            v[1] = 1;
            v
        }),
        (P::Tuple(vec![P::U8, P::U64]), {
            let mut v = vec![0; 16];
            v[1] = 1;
            v
        }),
    ] {
        assert!(matches!(
            rejected_before_allocation(&[p], &expected(1, 256, &body), 256),
            CodecError::Wire(WireError::Internal(_))
        ));
    }
    // 零サイズの要素でも要素数の上限と構築予算を適用し、巨大な反復に入らない。
    let empty_records = [P::List(Box::new(P::Record { fields: vec![] }))];
    let body = [
        40_u32.to_le_bytes(),
        (crate::runtime::MAX_LIST_LEN as u32 + 1).to_le_bytes(),
    ]
    .concat();
    assert!(matches!(
        rejected_before_allocation(&empty_records, &expected(1, u64::MAX, &body), u64::MAX),
        CodecError::Value(Stop::Resource(_))
    ));
    let body = [40_u32.to_le_bytes(), 1000_u32.to_le_bytes()].concat();
    assert_eq!(
        rejected_before_allocation(&empty_records, &expected(1, 64, &body), 64),
        limited(WireError::ConstructionLimit)
    );
    let body = [40_u32.to_le_bytes(), u32::MAX.to_le_bytes()].concat();
    assert_eq!(
        rejected_before_allocation(
            &[P::Map(Box::new(P::U64), Box::new(P::U64))],
            &expected(1, u64::MAX, &body),
            u64::MAX
        ),
        limited(WireError::Memory32)
    );
}

#[test]
fn decode_validates_and_charges_disappearing_map_values_before_last_wins_normalization() {
    // 関門: 重複した鍵の先の値も UTF-8 と予算を検査する。書き込みは正規化済みの Map
    // しか持たないため、この入力は既存の試験で検査できない。期待値は三組から独立に決める。
    let ps = [P::Map(Box::new(P::U8), Box::new(P::String))];
    let body = hex("28 00 00 00 03 00 00 00
        02 00 00 00 4c 00 00 00 01 00 00 00
        01 00 00 00 4d 00 00 00 01 00 00 00
        02 00 00 00 4e 00 00 00 01 00 00 00 41 42 43");
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let decoded = plan(&ps)
            .decode(ctx, &expected(1, 115, &body), 115)
            .unwrap();
        assert_eq!(decoded.construction_bytes, 115);
        let pairs = map::map_to_vec(ctx, decoded.values[0]).unwrap();
        assert_eq!(
            pairs
                .iter()
                .map(|(k, v)| (k.as_byte().unwrap(), ctx.str(*v).unwrap()))
                .collect::<Vec<_>>(),
            [(1, "B"), (2, "C")]
        );
    });
    assert_eq!(
        rejected_before_allocation(&ps, &expected(1, 114, &body), 114),
        limited(WireError::ConstructionLimit)
    );
    let mut bad = expected(1, 115, &body);
    bad[76] = 255;
    assert!(matches!(
        rejected_before_allocation(&ps, &bad, 115),
        CodecError::Wire(WireError::Internal(_))
    ));
}

#[test]
fn decoded_nested_lists_and_leaf_boundaries_survive_collection() {
    // 関門: 全要素の Vec を作らず、明示の作業列と葉で構築した値を保存して回収を越える。
    // 手書きの参照先と期待値で、深い入れ子と複数の葉の順・寿命を検査する。
    let nested = [(0..80).fold(P::U8, |p, _| P::List(Box::new(p)))];
    let mut nested_body = Vec::new();
    for i in 0..80 {
        nested_body.extend((40_u32 + 8 * i).to_le_bytes());
        nested_body.extend(1_u32.to_le_bytes());
    }
    nested_body.push(7);
    let strings = [P::List(Box::new(P::String))];
    let mut string_body = hex("28 00 00 00 46 00 00 00");
    for i in 0..70 {
        string_body.extend((600_u32 + i).to_le_bytes());
        string_body.extend(1_u32.to_le_bytes());
    }
    string_body.extend((0..70).map(|i| b'a' + i % 26));
    let mut heap = Heap::new(HeapConfig {
        stress: true,
        ..HeapConfig::default()
    });
    let roots = heap.epoch(|ctx| {
        vec![
            ctx.new_slot(
                plan(&nested)
                    .decode(ctx, &expected(1, 1296, &nested_body), 1296)
                    .unwrap()
                    .values[0],
            ),
            ctx.new_slot(
                plan(&strings)
                    .decode(ctx, &expected(1, 1206, &string_body), 1206)
                    .unwrap()
                    .values[0],
            ),
        ]
    });
    heap.collect(&roots);
    heap.verify(&roots).unwrap();
    heap.epoch(|ctx| {
        let mut value = ctx.load(&roots[0]);
        for _ in 0..80 {
            assert_eq!(list::len(ctx, value).unwrap(), 1);
            value = list::get(ctx, value, 0).unwrap().unwrap();
        }
        assert_eq!(value.as_byte(), Some(7));
        let value = ctx.load(&roots[1]);
        assert_eq!(list::len(ctx, value).unwrap(), 70);
        for i in 0..70 {
            let v = list::get(ctx, value, i).unwrap().unwrap();
            assert_eq!(ctx.str(v).unwrap().as_bytes(), &[b'a' + (i % 26) as u8]);
        }
        ctx.discard(roots);
    });
}
