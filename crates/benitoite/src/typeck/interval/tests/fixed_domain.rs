//! 固定域の候補・ソース順・未知境界を、本物の型検査と本体入口で検査する。
//! 関門: Range の入力ではシフトの27宣言・対象引数・失敗の順序を観察できない。
//! 期待値は DomainExamples の独立した幅と区間から指定し、契約表から生成しない。

use super::*;
use arithmetic::{Cause, TargetOperation};
use std::collections::BTreeMap;

#[test]
fn shifts_match_all_lean_declarations_orders_and_interval_cases() {
    let mut source = String::new();
    let mut expected = BTreeMap::new();
    for (module, ty, upper, signed) in [
        ("Integer", "Integer", 63, true),
        ("Integer64", "Integer", 63, true),
        ("Integer8", "Integer8", 7, true),
        ("Integer16", "Integer16", 15, true),
        ("Integer32", "Integer32", 31, true),
        ("UnsignedInteger", "UnsignedInteger64", 63, false),
        ("UnsignedInteger64", "UnsignedInteger64", 63, false),
        ("UnsignedInteger16", "UnsignedInteger16", 15, false),
        ("UnsignedInteger32", "UnsignedInteger32", 31, false),
        ("Byte", "Byte", 7, false),
        ("UnsignedInteger8", "Byte", 7, false),
    ] {
        for direction in ["shiftLeft", "shiftRight", "shiftRightUnsigned"] {
            if direction == "shiftRightUnsigned" && !signed {
                continue;
            }
            for reverse in [false, true] {
                for (expression, bounds, outside, overflow) in [
                    (
                        format!("if flag then 0 else {upper} end if"),
                        (0, upper),
                        false,
                        false,
                    ),
                    (
                        "if flag then -2 else -1 end if".to_owned(),
                        (-2, -1),
                        true,
                        false,
                    ),
                    (
                        format!("if flag then {} else {} end if", upper + 1, upper + 2),
                        (upper + 1, upper + 2),
                        true,
                        false,
                    ),
                    (
                        "if flag then -1 else 0 end if".to_owned(),
                        (-1, 0),
                        false,
                        false,
                    ),
                    (
                        format!("if flag then {upper} else {} end if", upper + 1),
                        (upper, upper + 1),
                        false,
                        false,
                    ),
                    ("n".to_owned(), (Interval::MIN, Interval::MAX), false, false),
                    ("9223372036854775807 + 1".to_owned(), (0, 0), false, true),
                ] {
                    let name = format!("case{}", expected.len());
                    let args = if reverse {
                        format!("n: {expression}, a: a")
                    } else {
                        format!("a: a, n: {expression}")
                    };
                    source.push_str(&format!("function {name}(flag: Boolean, n: Integer, a: {ty}) -> Unit\n bind _ <- {module}.{direction}({args})\nend function\n"));
                    expected.insert(
                        format!(".{name}"),
                        (
                            format!("Benitoite.{module}.{direction}"),
                            upper,
                            bounds,
                            outside,
                            overflow,
                        ),
                    );
                }
            }
        }
    }
    identity::tests::fixture_owned(&source, |inputs, tables| {
        assert_eq!(expected.len(), 378);
        assert_eq!(
            inputs
                .iter()
                .filter(|i| expected.contains_key(&i.definition.name))
                .count(),
            expected.len()
        );
        for input in inputs
            .iter()
            .filter(|i| expected.contains_key(&i.definition.name))
        {
            let (name, upper, bounds, outside, overflow) = &expected[&input.definition.name];
            let mut budget = Budget::default();
            let report = analyze_body(input, tables, &BTreeMap::new(), &mut budget, 200);
            assert_eq!(report.coverage, Coverage::Prepared, "{name}");
            let analysis = report.flow.unwrap();
            assert!(analysis.value.is_ok(), "{name}: {:?}", analysis.value);
            assert!(
                analysis.independent.is_empty(),
                "{name}: {:?}",
                analysis.independent
            );
            assert!(!analysis.unsupported, "{name}");
            assert_eq!(
                analysis.candidates.len(),
                usize::from(*outside || *overflow),
                "{name}"
            );
            if *outside {
                let candidate = &analysis.candidates[0];
                assert_eq!(candidate.cause, Cause::OutsideDomain);
                assert_eq!(candidate.left.bounds(), Some(*bounds));
                assert_eq!(candidate.right.bounds(), Some((0, *upper)));
                let TargetOperation::Standard {
                    declaration,
                    contract,
                } = candidate.operation
                else {
                    panic!("{candidate:?}");
                };
                assert_eq!(tables.resolved.stdlib(name), Some(declaration));
                assert_eq!(contract.argument, 1);
                assert_eq!(contract.parameters[1], "n");
            } else if *overflow {
                assert_eq!(analysis.candidates[0].cause, Cause::Overflow);
            }
            assert_eq!(budget.body.temporary, 0);
        }
    });
}

fn inspect(source: &str, check: impl FnOnce(&flow::Analysis)) {
    identity::tests::fixture_owned(source, |inputs, tables| {
        let input = inputs
            .iter()
            .find(|i| i.definition.name == ".sample")
            .unwrap();
        let mut budget = Budget::default();
        let report = analyze_body(input, tables, &BTreeMap::new(), &mut budget, 200);
        assert_eq!(report.coverage, Coverage::Prepared);
        let analysis = report.flow.unwrap();
        assert!(analysis.value.is_ok(), "{:?}", analysis.value);
        assert_eq!(budget.body.temporary, 0);
        check(&analysis);
    });
}

#[test]
fn shift_arguments_keep_parent_facts_and_only_selected_position() {
    for (imports, callee) in [
        ("", "Integer.shiftLeft"),
        ("import Benitoite.Integer64 as I", "I.shiftLeft"),
    ] {
        for (args, expected, live) in [
            ("a: 1, n: amount", vec![Cause::OutsideDomain], false),
            ("n: amount, a: 1", vec![Cause::OutsideDomain], false),
            // Integer64 の div 0 は正常区間Topを残す。子の候補も親に属する。
            (
                "a: x div zero, n: amount",
                vec![Cause::ZeroDivisor, Cause::OutsideDomain],
                false,
            ),
            // 対象外の a が域外でもシフト量の候補に使わない。
            ("a: amount, n: 0", vec![], true),
            ("a: 9223372036854775807, n: 63", vec![], true),
            (
                "n: amount, a: 9223372036854775807 + 1",
                vec![Cause::Overflow],
                false,
            ),
            (
                "a: 9223372036854775807 + 1, n: amount",
                vec![Cause::Overflow],
                false,
            ),
            ("a: block return () end block, n: amount", vec![], false),
            ("n: amount, a: block return () end block", vec![], false),
            ("a: x div zero, n: 0", vec![Cause::ZeroDivisor], true),
        ] {
            let source = format!(
                "{imports}\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n bind amount <- 64\n bind _ <- {callee}({args})\nend function\n"
            );
            inspect(&source, |analysis| {
                assert_eq!(
                    analysis
                        .candidates
                        .iter()
                        .map(|c| c.cause)
                        .collect::<Vec<_>>(),
                    expected,
                    "{source}"
                );
                assert!(analysis.independent.is_empty(), "{source}");
                assert!(!analysis.unsupported, "{source}");
                assert_eq!(analysis.value.as_ref().unwrap().live, live, "{source}");
                if let Some(candidate) = analysis
                    .candidates
                    .iter()
                    .find(|c| c.cause == Cause::OutsideDomain)
                {
                    assert_eq!(candidate.origins.as_slice().len(), 1);
                    let start = usize::try_from(candidate.primary.start.0).unwrap();
                    let end = usize::try_from(candidate.primary.end.0).unwrap();
                    assert_eq!(&source[start..end], "amount");
                }
            });
        }
    }
}

#[test]
fn unrecognized_shift_calls_forget_parent_facts_and_keep_independent_children() {
    for (declaration, body) in [
        (
            "function shiftLeft(a: Integer, n: Integer) -> Integer return a end function",
            "shiftLeft(a: x div 0, n: 64)",
        ),
        ("", "(Integer.shiftLeft)(a: x div 0, n: 64)"),
        ("", "Integer.shiftLeft(a: x div 0, n: _)"),
        ("", "x div 0 |> Integer.shiftLeft(n: 64)"),
        (
            "",
            "block bind f <- Integer.shiftLeft\n f(a: x div 0, n: 64) end block",
        ),
    ] {
        let source = format!(
            "{declaration}\nfunction sample(x: Integer) -> Unit\n bind _ <- {body}\nend function\n"
        );
        inspect(&source, |analysis| {
            assert!(analysis.candidates.is_empty(), "{source}");
            assert!(analysis.unsupported, "{source}");
            assert_eq!(
                analysis
                    .independent
                    .iter()
                    .flat_map(|i| i.candidates.iter())
                    .map(|c| c.cause)
                    .collect::<Vec<_>>(),
                [Cause::ZeroDivisor],
                "{source}"
            );
        });
    }
}

// 関門: 固定域の置換走査と候補保存を任意予算で観察する。
// 既存の三表はシフトを含まないため、全引数の保持や無計上の認定を捕まえない。
#[test]
fn shift_permutation_costs_and_budget_stops_preserve_saved_prefixes() {
    let source = "function forward() -> Unit\n bind _ <- Integer.shiftLeft(a: 1, n: 64)\nend function\nfunction reverse() -> Unit\n bind _ <- Integer.shiftLeft(n: 64, a: 1)\nend function\n";
    identity::tests::fixture_owned(source, |inputs, tables| {
        let mut operations = Vec::new();
        for name in [".forward", ".reverse"] {
            let input = inputs.iter().find(|i| i.definition.name == name).unwrap();
            let mut complete = Budget::default();
            let report = analyze_body(input, tables, &BTreeMap::new(), &mut complete, 200);
            assert_eq!(report.coverage, Coverage::Prepared);
            assert_eq!(report.flow.unwrap().candidates.len(), 1);
            operations.push(complete.body.operations);
            for resource in 0..4 {
                for cap in 0..=complete.body.operations.max(complete.body.peak) + 1 {
                    let high = budget::Cap {
                        operations: 1_000,
                        items: 1_000,
                    };
                    let low = if resource % 2 == 0 {
                        budget::Cap {
                            operations: cap,
                            ..high
                        }
                    } else {
                        budget::Cap { items: cap, ..high }
                    };
                    let mut budget = Budget {
                        limits: budget::Limits {
                            body: if resource < 2 { low } else { high },
                            whole: if resource < 2 { high } else { low },
                        },
                        ..Budget::default()
                    };
                    let report = analyze_body(input, tables, &BTreeMap::new(), &mut budget, 200);
                    assert_eq!(budget.body.temporary, 0, "{name}/{resource}/{cap}");
                    if let Some(analysis) = report.flow {
                        assert!(analysis.independent.is_empty());
                        assert!(analysis.candidates.len() <= 1);
                        if let Some(candidate) = analysis.candidates.first() {
                            assert_eq!(candidate.cause, Cause::OutsideDomain);
                            assert_eq!(candidate.left.bounds(), Some((64, 64)));
                            assert!(budget.body.saved > 0);
                        }
                    }
                    let boundary = if resource % 2 == 0 {
                        complete.body.operations
                    } else {
                        complete.body.peak
                    };
                    assert_eq!(
                        report.coverage == Coverage::Prepared,
                        cap >= boundary,
                        "{name}/{resource}/{cap}"
                    );
                }
            }
        }
        // domainRange は両順とも3分類。逆順では最初の contains と erase が
        // それぞれ先頭0を一度余分に読み、erase が接頭辞一項を複写する。
        assert_eq!(operations[1] - operations[0], 2);
    });
}
