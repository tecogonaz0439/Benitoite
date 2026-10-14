//! 外部の関数の補助コードで使う配置と転送の処理をまとめる（設計書 03-10「型の対応」）。
//! 呼び出し経路への接続までは、既存の型付き・動的な受け渡しを保つ。

pub(crate) mod codec;
pub(crate) mod component;
pub(crate) mod emit;
mod emit_values;
pub(crate) mod layout;
pub(crate) mod runtime;
pub(crate) mod wire;

#[cfg(test)]
mod abi_tests;

#[cfg(test)]
mod memory_tests;

#[cfg(test)]
mod fixed_tests;

#[cfg(test)]
mod variant_tests;

#[cfg(test)]
mod collection_tests;

#[cfg(test)]
mod sharing_tests;

#[cfg(test)]
mod limit_tests;

#[cfg(test)]
mod lifetime_tests;

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::layout::{LayoutError, LayoutKind, LayoutTable, MemoryLayout, TypeLayout};
    use crate::external::WitPlan as P;

    fn table(plans: &[P]) -> LayoutTable {
        LayoutTable::new(plans, &mut 1_000_000).unwrap()
    }

    fn root(table: &LayoutTable) -> &TypeLayout {
        &table.nodes[table.roots.fields[0].node]
    }

    fn memory(size: u32, alignment: u32) -> MemoryLayout {
        MemoryLayout { size, alignment }
    }

    fn cases(count: usize) -> Vec<(String, u32)> {
        (0..count).map(|n| (format!("case{n}"), n as u32)).collect()
    }

    #[test]
    fn widths_references_and_discriminants_have_canonical_memory32_layouts() {
        // 関門: 転送表の入口で独立した ABI の幅を守る。幅・判別子の境界の退行を捕まえる。
        // 既存の動的変換はメモリの配置を求めないため、この契約は既存の試験では検査できない。
        for (plan, expected) in [
            (P::S8, memory(1, 1)),
            (P::U8, memory(1, 1)),
            (P::Bool, memory(1, 1)),
            (P::S16, memory(2, 2)),
            (P::U16, memory(2, 2)),
            (P::S32, memory(4, 4)),
            (P::U32, memory(4, 4)),
            (P::F32, memory(4, 4)),
            (P::Char, memory(4, 4)),
            (P::S64, memory(8, 8)),
            (P::U64, memory(8, 8)),
            (P::F64, memory(8, 8)),
            (P::String, memory(8, 4)),
            (P::Bytes, memory(8, 4)),
            (P::List(Box::new(P::U64)), memory(8, 4)),
            (P::Map(Box::new(P::U8), Box::new(P::U64)), memory(8, 4)),
        ] {
            let table = table(&[plan]);
            assert_eq!(root(&table).memory, expected);
            assert_eq!(root(&table).memory.stride().unwrap(), expected.size);
        }
        for (count, size) in [(1, 1), (256, 1), (257, 2), (65_536, 2), (65_537, 4)] {
            assert_eq!(
                root(&table(&[P::Enum {
                    cases: cases(count)
                }]))
                .memory,
                memory(size, size)
            );
        }
        for (count, size) in [(1, 1), (8, 1), (9, 2), (16, 2), (17, 4), (32, 4)] {
            assert_eq!(
                root(&table(&[P::Flags {
                    cases: cases(count)
                }]))
                .memory,
                memory(size, size)
            );
        }
        for count in [0, 33] {
            assert!(matches!(
                LayoutTable::new(
                    &[P::Flags {
                        cases: cases(count)
                    }],
                    &mut 1_000
                ),
                Err(LayoutError::Internal(_))
            ));
        }
        assert!(matches!(
            LayoutTable::new(&[P::Enum { cases: vec![] }], &mut 1_000),
            Err(LayoutError::Internal(_))
        ));
    }

    #[test]
    fn aggregates_preserve_field_order_padding_and_element_stride() {
        // 関門: 複合型の欄と参照先を手計算の配置で検査する。末尾の整列漏れや map の欄の逆転を捕まえる。
        let fields = vec![P::U8, P::U64, P::S16];
        for plan in [
            P::Tuple(fields.clone()),
            P::TupleFields(fields.clone()),
            P::ConstructorTuple {
                tag: 42,
                fields: fields.clone(),
            },
            P::Record {
                fields: vec![
                    ("a".into(), P::U8),
                    ("b".into(), P::U64),
                    ("c".into(), P::S16),
                ],
            },
        ] {
            let table = table(&[plan]);
            let node = root(&table);
            assert_eq!(node.memory, memory(24, 8));
            let LayoutKind::Record { fields } = &node.kind else {
                panic!("record expected")
            };
            assert_eq!(
                fields.iter().map(|f| f.offset).collect::<Vec<_>>(),
                [0, 8, 16]
            );
            assert_eq!(
                fields
                    .iter()
                    .map(|f| table.nodes[f.node].memory.size)
                    .collect::<Vec<_>>(),
                [1, 8, 2]
            );
        }
        let table = table(&[
            P::U8,
            P::List(Box::new(P::Tuple(vec![P::U16, P::U8]))),
            P::Map(Box::new(P::U8), Box::new(P::U64)),
            P::U8,
        ]);
        assert_eq!(table.roots.memory, memory(24, 4));
        assert_eq!(
            table
                .roots
                .fields
                .iter()
                .map(|f| f.offset)
                .collect::<Vec<_>>(),
            [0, 4, 12, 20]
        );
        let LayoutKind::List { element } = table.nodes[table.roots.fields[1].node].kind else {
            panic!("list expected")
        };
        assert_eq!(table.nodes[element].memory, memory(4, 2));
        assert_eq!(table.nodes[element].memory.array_size(3).unwrap(), 12);
        let LayoutKind::Map { entry } = &table.nodes[table.roots.fields[2].node].kind else {
            panic!("map expected")
        };
        assert_eq!(entry.memory, memory(16, 8));
        assert_eq!(
            entry.fields.iter().map(|f| f.offset).collect::<Vec<_>>(),
            [0, 8]
        );
        assert_eq!(entry.memory.array_size(3).unwrap(), 48);
        assert_eq!(
            LayoutTable::new(&[], &mut 0).unwrap().roots.memory,
            memory(0, 1)
        );
        assert_eq!(
            root(&self::table(&[P::Record { fields: vec![] }]))
                .memory
                .array_size(u32::MAX)
                .unwrap(),
            0
        );
    }

    #[test]
    fn variants_options_and_results_align_the_shared_payload() {
        // 関門: 判別子の後の詰め物と、最大の場合で決まる末尾の整列を守る。
        for (plan, expected, payload_offset, present) in [
            (
                P::Option(Box::new(P::U64)),
                memory(16, 8),
                8,
                vec![false, true],
            ),
            (
                P::Result {
                    ok: None,
                    err: Some(Box::new(P::U16)),
                },
                memory(4, 2),
                2,
                vec![false, true],
            ),
            (
                P::Result {
                    ok: Some(Box::new(P::U16)),
                    err: None,
                },
                memory(4, 2),
                2,
                vec![true, false],
            ),
            (
                P::Result {
                    ok: None,
                    err: None,
                },
                memory(1, 1),
                1,
                vec![false, false],
            ),
            (
                P::Result {
                    ok: Some(Box::new(P::U8)),
                    err: Some(Box::new(P::F64)),
                },
                memory(16, 8),
                8,
                vec![true, true],
            ),
            (
                P::Variant {
                    cases: vec![
                        (
                            "small".into(),
                            9,
                            Some(Box::new(P::Tuple(vec![P::U8, P::U8, P::U8]))),
                        ),
                        ("wide".into(), 3, Some(Box::new(P::U16))),
                        ("empty".into(), 8, None),
                    ],
                },
                memory(6, 2),
                2,
                vec![true, true, false],
            ),
        ] {
            let table = table(&[plan]);
            let node = root(&table);
            assert_eq!(node.memory, expected);
            let LayoutKind::Variant {
                discriminant_size,
                payload_offset: offset,
                cases,
            } = &node.kind
            else {
                panic!("variant expected")
            };
            assert_eq!(*discriminant_size, 1);
            assert_eq!(*offset, payload_offset);
            assert_eq!(
                cases.iter().map(Option::is_some).collect::<Vec<_>>(),
                present
            );
        }
    }

    #[test]
    fn type_and_memory32_limits_are_checked_before_unbounded_work() {
        // 関門: 表全体の入口の予算と配列の積の上限を検査する。深さ・兄弟・判別子だけの大量の場合も対象とする。
        let nested = |depth: usize| (1..depth).fold(P::U8, |p, _| P::List(Box::new(p)));
        assert!(LayoutTable::new(&[nested(100)], &mut 100).is_ok());
        assert_eq!(
            LayoutTable::new(&[nested(101)], &mut 101),
            Err(LayoutError::TypeBudget)
        );
        assert!(LayoutTable::new(&[P::Tuple(vec![P::U8; 99])], &mut 100).is_ok());
        assert_eq!(
            LayoutTable::new(&[P::Tuple(vec![P::U8; 100])], &mut 100),
            Err(LayoutError::TypeBudget)
        );
        assert_eq!(
            LayoutTable::new(&[P::U8, P::U64], &mut 1),
            Err(LayoutError::TypeBudget)
        );
        assert_eq!(
            LayoutTable::new(&[P::Enum { cases: cases(100) }], &mut 100),
            Err(LayoutError::TypeBudget)
        );
        assert_eq!(
            LayoutTable::new(
                &[P::Variant {
                    cases: (0..100).map(|i| (format!("c{i}"), i, None)).collect()
                }],
                &mut 100
            ),
            Err(LayoutError::TypeBudget)
        );
        assert_eq!(
            LayoutTable::new(&[P::Borrow(1)], &mut 1),
            Err(LayoutError::Resource)
        );
        assert_eq!(
            LayoutTable::new(&[P::Own(1)], &mut 1),
            Err(LayoutError::Resource)
        );
        assert_eq!(memory(8, 8).array_size(536_870_911), Ok(4_294_967_288));
        assert_eq!(
            memory(8, 8).array_size(536_870_912),
            Err(LayoutError::Memory32)
        );
        assert_eq!(memory(u32::MAX, 8).stride(), Err(LayoutError::Memory32));
        assert_eq!(memory(1, 1).array_size(u32::MAX), Ok(u32::MAX));
    }

    #[test]
    fn handwritten_guest_reads_record_and_variant_at_computed_offsets() {
        // 関門: 表が指定する位置へ書いた値を独立したゲストの canon lift に読ませる。
        // 表と復号器だけの往復が共有しうる配置の誤りを、Wasmtime が返す独立した値で捕まえる。
        use wasmtime::component::{Component, Linker, Val};
        let record = table(&[P::Record {
            fields: vec![
                ("a".into(), P::U8),
                ("b".into(), P::U64),
                ("c".into(), P::S16),
            ],
        }]);
        let variant = table(&[P::Variant {
            cases: vec![
                ("empty".into(), 5, None),
                ("byte".into(), 8, Some(Box::new(P::U8))),
                (
                    "pair".into(),
                    2,
                    Some(Box::new(P::TupleFields(vec![P::U16, P::U64]))),
                ),
            ],
        }]);
        let mut data = vec![0xcc; 64];
        let LayoutKind::Record { fields } = &root(&record).kind else {
            panic!("record expected")
        };
        let put = |data: &mut [u8], offset: u32, bytes: &[u8]| {
            let start = offset as usize;
            data[start..start + bytes.len()].copy_from_slice(bytes);
        };
        put(&mut data, fields[0].offset, &[7]);
        put(
            &mut data,
            fields[1].offset,
            &0xfedc_ba98_7654_3210_u64.to_le_bytes(),
        );
        put(&mut data, fields[2].offset, &(-123_i16).to_le_bytes());
        let LayoutKind::Variant {
            discriminant_size,
            payload_offset,
            cases,
        } = &root(&variant).kind
        else {
            panic!("variant expected")
        };
        assert_eq!(*discriminant_size, 1);
        put(&mut data, 32, &[2]);
        let LayoutKind::Record { fields } = &variant.nodes[cases[2].unwrap()].kind else {
            panic!("tuple expected")
        };
        put(
            &mut data,
            32 + payload_offset + fields[0].offset,
            &9_u16.to_le_bytes(),
        );
        put(
            &mut data,
            32 + payload_offset + fields[1].offset,
            &0x8000_0000_0000_0001_u64.to_le_bytes(),
        );
        let data = data
            .iter()
            .map(|b| format!("\\{b:02x}"))
            .collect::<String>();
        let bytes = wat::parse_str(format!(
            r#"(component
            (core module $m
                (memory (export "memory") 1)
                (data (i32.const 0) "{data}")
                (func (export "record") (result i32) i32.const 0)
                (func (export "variant") (result i32) i32.const 32))
            (core instance $i (instantiate $m))
            (type $r0 (record (field "a" u8) (field "b" u64) (field "c" s16)))
            (export $r "record-type" (type $r0))
            (type $p (tuple u16 u64))
            (type $v0 (variant (case "empty") (case "byte" u8) (case "pair" $p)))
            (export $v "variant-type" (type $v0))
            (func (export "record") (result $r)
                (canon lift (core func $i "record") (memory (core memory $i "memory"))))
            (func (export "variant") (result $v)
                (canon lift (core func $i "variant") (memory (core memory $i "memory")))))"#
        ))
        .unwrap();
        let engine = wasmtime::Engine::new(&crate::external::engine_config()).unwrap();
        let component = Component::from_binary(&engine, &bytes).unwrap();
        let mut store = wasmtime::Store::new(&engine, ());
        store.set_fuel(1_000_000).unwrap();
        store.set_epoch_deadline(1);
        let instance = Linker::new(&engine)
            .instantiate(&mut store, &component)
            .unwrap();
        for (name, expected) in [
            (
                "record",
                Val::Record(vec![
                    ("a".into(), Val::U8(7)),
                    ("b".into(), Val::U64(0xfedc_ba98_7654_3210)),
                    ("c".into(), Val::S16(-123)),
                ]),
            ),
            (
                "variant",
                Val::Variant(
                    "pair".into(),
                    Some(Box::new(Val::Tuple(vec![
                        Val::U16(9),
                        Val::U64(0x8000_0000_0000_0001),
                    ]))),
                ),
            ),
        ] {
            let function = instance.get_func(&mut store, name).unwrap();
            let mut results = [Val::Bool(false)];
            function.call(&mut store, &[], &mut results).unwrap();
            assert_eq!(results[0], expected);
        }
    }
}
