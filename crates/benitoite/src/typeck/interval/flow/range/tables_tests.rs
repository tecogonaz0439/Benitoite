//! 本物の名前解決・型検査から標準束縛の交換用入力を確かめる
//! （設計書 02-05「区間解析の内部入力」）。
// 関門: 宣言の集合・型・契約・表の順序は Lean への入力の契約であり、
// Range だけの既存の固定表ではシフトの別名の欠落や誤同定を検出できない。
// 既存の本体入力の収集を使い、公開範囲やテスト用の差し込み口を増やさない。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::typeck::interval::identity::tests::fixture_owned;
use std::collections::BTreeSet;

#[test]
fn shift_tables_identify_all_resolved_declarations_and_lean_contracts() {
    // FixedDomainApi の20役割と、標準ソースの別名7宣言を別々に列挙する。
    // 期待値は実装の CONTRACTS や loaded から作らない。
    let modules = [
        ("Integer", B::INTEGER, 63, true),
        ("Integer64", B::INTEGER, 63, true),
        ("Integer8", B::INTEGER8, 7, true),
        ("Integer16", B::INTEGER16, 15, true),
        ("Integer32", B::INTEGER32, 31, true),
        ("UnsignedInteger", B::UNSIGNED_INTEGER64, 63, false),
        ("UnsignedInteger64", B::UNSIGNED_INTEGER64, 63, false),
        ("UnsignedInteger16", B::UNSIGNED_INTEGER16, 15, false),
        ("UnsignedInteger32", B::UNSIGNED_INTEGER32, 31, false),
        ("UnsignedInteger8", B::BYTE, 7, false),
        ("Byte", B::BYTE, 7, false),
    ];
    let mut source = String::from("import Benitoite.Unofficial.Range\n");
    for (module, _, _, _) in modules {
        source.push_str(&format!("import Benitoite.{module} as Alias{module}\n"));
    }
    source.push_str("function sample(i: Integer, i8: Integer8, i16: Integer16, i32: Integer32, u: UnsignedInteger64, u16: UnsignedInteger16, u32: UnsignedInteger32, b: Byte) -> Unit\n");
    let mut expected = BTreeMap::new();
    for (module, operand, upper, signed) in modules {
        let value = match operand {
            B::INTEGER => "i",
            B::INTEGER8 => "i8",
            B::INTEGER16 => "i16",
            B::INTEGER32 => "i32",
            B::UNSIGNED_INTEGER64 => "u",
            B::UNSIGNED_INTEGER16 => "u16",
            B::UNSIGNED_INTEGER32 => "u32",
            B::BYTE => "b",
            _ => unreachable!(),
        };
        for operation in ["shiftLeft", "shiftRight", "shiftRightUnsigned"]
            .into_iter()
            .take(if signed { 3 } else { 2 })
        {
            source.push_str(&format!(
                " bind _ <- Alias{module}.{operation}(n: 0, a: {value})\n"
            ));
            expected.insert(format!("Benitoite.{module}.{operation}"), (operand, upper));
        }
    }
    source.push_str(
        " bind _ <- Range.checkInteger(minimum: 0, maximum: 1, value: 0)\nend function\n",
    );
    fixture_owned(&source, |inputs, tables| {
        let input = inputs
            .iter()
            .find(|i| i.definition.name.ends_with(".sample"))
            .unwrap();
        let table = input.range.as_ref().unwrap();
        assert!(matches!(table.standards[0], Standard::Check { .. }));
        assert!(matches!(table.standards[1], Standard::Value { .. }));
        let mut declaration_kinds = (0, 0);
        let shifts: Vec<_> = table
            .standards
            .iter()
            .skip(2)
            .map(|entry| {
                let Standard::Shift(entry) = entry else {
                    panic!("shift entry");
                };
                let c = entry.contract;
                let (operand, upper) = expected[c.name];
                assert_eq!(c.argument, 1);
                assert_eq!(c.parameters, ["a", "n"]);
                assert_eq!(c.argument_types, [operand, B::INTEGER]);
                assert_eq!(c.result, operand);
                assert_eq!((c.minimum, c.maximum), (0, upper));
                assert_eq!(tables.resolved.stdlib(c.name), Some(entry.declaration));
                let kind = tables
                    .resolved
                    .bindings
                    .get(entry.declaration)
                    .unwrap()
                    .kind;
                if kind == BindingKind::Fn {
                    declaration_kinds.1 += 1;
                } else {
                    assert!(matches!(kind, BindingKind::BuiltinFn(_)), "{kind:?}");
                    declaration_kinds.0 += 1;
                }
                let actual = tables.schemes.get(entry.declaration).unwrap();
                assert!(actual.effects.is_empty());
                assert_eq!(actual.param_names, ["a", "n"]);
                for (ty, builtin) in actual.params.iter().zip([operand, B::INTEGER]) {
                    assert_eq!(
                        *ty,
                        Ty::Con(
                            TyCon::Builtin(builtin),
                            vec![],
                            crate::types::builtin::RangeIndex::TOP
                        )
                    );
                }
                assert_eq!(
                    actual.ret,
                    Ty::Con(
                        TyCon::Builtin(operand),
                        vec![],
                        crate::types::builtin::RangeIndex::TOP
                    )
                );
                (c.name, entry.declaration)
            })
            .collect();
        assert_eq!(
            shifts.iter().map(|(name, _)| *name).collect::<Vec<_>>(),
            expected.keys().map(String::as_str).collect::<Vec<_>>()
        );
        assert_eq!(
            shifts
                .iter()
                .map(|(_, id)| *id)
                .collect::<BTreeSet<_>>()
                .len(),
            27
        );
        assert_eq!(declaration_kinds, (20, 7));
        eprintln!("shift declarations: 20 BuiltinFn (PrimName), 7 Fn (FunName)");
        // 各宣言の名前の出現が、表示上の Alias* ではなく元の宣言を指す。
        assert_eq!(table.calls.len(), 28);
        for (_, id) in shifts {
            assert_eq!(
                table.calls.values().filter(|found| **found == id).count(),
                1
            );
        }
    });
}

#[test]
fn shift_tables_leave_unrelated_bodies_and_unloaded_modules_unchanged() {
    let source = "import Benitoite.Unofficial.Range\nfunction shiftLeft(a: Integer, n: Integer) -> Integer return a end function\nfunction fake() -> Integer return shiftLeft(a: 1, n: 0) end function\nfunction sample() -> Integer return Integer64.shiftLeft(a: 1, n: 0) end function\nfunction plain() -> Unit end function\nfunction rangeOnly() -> Unit bind _ <- Range.checkInteger(minimum: 0, maximum: 1, value: 0) end function\n";
    fixture_owned(source, |inputs, tables| {
        for name in [".plain", ".fake", ".shiftLeft"] {
            assert!(
                inputs
                    .iter()
                    .find(|i| i.definition.name == name)
                    .unwrap()
                    .range
                    .is_none()
            );
        }
        let range = inputs
            .iter()
            .find(|i| i.definition.name == ".rangeOnly")
            .unwrap()
            .range
            .as_ref()
            .unwrap();
        assert_eq!(range.standards.len(), 2);
        assert!(matches!(range.standards[0], Standard::Check { .. }));
        assert!(matches!(range.standards[1], Standard::Value { .. }));
        assert_eq!(range.calls.len(), 1);
        let shifts = inputs
            .iter()
            .find(|i| i.definition.name == ".sample")
            .unwrap()
            .range
            .as_ref()
            .unwrap();
        assert!(
            shifts
                .standards
                .iter()
                .all(|entry| matches!(entry, Standard::Shift(_)))
        );
        for entry in &shifts.standards {
            let Standard::Shift(entry) = entry else {
                unreachable!();
            };
            assert_eq!(
                tables.resolved.stdlib(entry.contract.name),
                Some(entry.declaration)
            );
        }
        // 使われていないモジュールを表の作成が読み込んでいない。
        assert_eq!(
            tables
                .resolved
                .stdlib("Benitoite.Network.Http.Listen.listen"),
            None
        );
    });
}

// 関門: 二表と元キーは認定の独立した入力契約である。正常な表だけの既存例では
// 不在・別宣言・別キーでも字面から認定してしまう退行を捕まえられない。
#[test]
fn shift_recognition_requires_both_tables_and_the_original_name_key() {
    use crate::typeck::interval::arithmetic::Cause;
    use crate::typeck::interval::identity::tests::fixture_files_batched;
    use crate::typeck::interval::{Budget, Coverage, analyze_body};
    let source = "function sample(x: Integer) -> Unit\n bind _ <- Integer.shiftLeft(a: x div 0, n: 64)\nend function\n";
    fixture_files_batched(&[("main.bnt", source)], 5, |batches, tables| {
        for (case, mut inputs) in batches.into_iter().enumerate() {
            let input = inputs
                .iter_mut()
                .find(|i| i.definition.name == ".sample")
                .unwrap();
            let standard = input.range.as_mut().unwrap();
            match case {
                0 => {}
                1 => standard.calls.clear(),
                2 => {
                    let other = tables
                        .resolved
                        .stdlib("Benitoite.Integer.shiftRight")
                        .unwrap();
                    for declaration in standard.calls.values_mut() {
                        *declaration = other;
                    }
                }
                3 => {
                    let declaration = *standard.calls.values().next().unwrap();
                    standard.calls.clear();
                    // 有効な別の元ノード（定義の根）へ同じ宣言を誤って付ける。
                    standard
                        .calls
                        .insert(input.definition.source.node(), declaration);
                }
                4 => standard.standards.clear(),
                _ => unreachable!(),
            }
            let mut budget = Budget::default();
            let report = analyze_body(input, tables, &BTreeMap::new(), &mut budget, 200);
            assert_eq!(report.coverage, Coverage::Prepared);
            let analysis = report.flow.unwrap();
            if case == 0 {
                assert_eq!(
                    analysis
                        .candidates
                        .iter()
                        .map(|c| c.cause)
                        .collect::<Vec<_>>(),
                    [Cause::ZeroDivisor, Cause::OutsideDomain]
                );
                assert!(!analysis.unsupported);
                assert!(analysis.independent.is_empty());
            } else {
                assert!(analysis.candidates.is_empty());
                assert!(analysis.unsupported);
                assert_eq!(
                    analysis
                        .independent
                        .iter()
                        .flat_map(|i| i.candidates.iter())
                        .map(|c| c.cause)
                        .collect::<Vec<_>>(),
                    [Cause::ZeroDivisor]
                );
            }
            assert_eq!(budget.body.temporary, 0);
        }
    });
}
