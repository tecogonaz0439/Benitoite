//! 型検査の入口から収集・順序・停止を確かめる。
// 関門: 旧検査は区間解析の収集漏れや共有予算の初期化を観察できない。
// 本物の名前解決・型検査を使い、公開範囲やテスト用引数を増やさない。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::domain::Interval;
use super::*;
use crate::diag::Diagnostic;
use crate::typeck::test_support::check_files;

mod arithmetic_extensions;
mod budget_reference;
mod fixed_domain;
mod range_calls;

// 関門: 独立入力と親の警告を、保存時刻によらずキーの先行順で採用する。
// 既存の独立入力の表は各列を別々に比較し、利用者向けの併合順を観察しない。
// 本物の型検査が返す診断を使い、候補列や元位置を手作りしない（設計書 02-05「警告」）。
#[test]
fn warnings_merge_parent_and_independent_inputs_in_preorder() {
    let source = "function sample() -> Unit\n bind _ <- [block bind first <- 0\n 1 div first end block]\n bind second <- 0\n bind _ <- 1 div second\nend function\n";
    let (_, _, _, diagnostics) = check_files(&[("main.bnt", source)], false);
    assert_eq!(diagnostics.len(), 2, "{diagnostics:#?}");
    let starts: Vec<_> = diagnostics
        .iter()
        .map(|d| {
            assert_eq!(d.code, Some(crate::diag::DiagCode::W0401));
            usize::try_from(d.primary.as_ref().unwrap().span.start.0).unwrap()
        })
        .collect();
    assert_eq!(
        starts,
        [
            source.rfind("first").unwrap(),
            source.rfind("second").unwrap()
        ]
    );
}

// 関門: 本物の型検査の出力で、単一比較の両枝・左右反転・凸な合流を確かめる。
// 算術と束縛だけの既存表では、境界の ±1 や枝間の事実の漏れを観察できない。
// 非公開の絞り込み関数を呼ばず、同じ入力準備と本体結果の境界を使う。
#[test]
fn comparisons_refine_only_the_selected_branch_and_merge_normal_values() {
    let mut source = String::from(
        "const zero: Integer = (0)\nconst alias: Integer = zero\nconst computed: Integer = 1 + -1\n",
    );
    let mut cases = Vec::new();
    // 各枝の代替値を期待区間内へ置き、合流からも絞り込みの端を観察できる。
    for (op, reverse, yes, no, yes_fallback, no_fallback) in [
        ("=", "=", (0, 0), (Interval::MIN, Interval::MAX), "0", "0"),
        ("<>", "<>", (Interval::MIN, Interval::MAX), (0, 0), "0", "0"),
        ("<", ">", (Interval::MIN, -1), (0, Interval::MAX), "-1", "0"),
        ("<=", ">=", (Interval::MIN, 0), (1, Interval::MAX), "0", "1"),
        (">", "<", (1, Interval::MAX), (Interval::MIN, 0), "1", "0"),
        (
            ">=",
            "<=",
            (0, Interval::MAX),
            (Interval::MIN, -1),
            "0",
            "-1",
        ),
    ] {
        for condition in [format!("x {op} 0"), format!("0 {reverse} x")] {
            cases.push((
                format!("return if {condition} then x else {yes_fallback} end if"),
                Some(yes),
                0,
            ));
            cases.push((
                format!("return if {condition} then {no_fallback} else x end if"),
                Some(no),
                0,
            ));
        }
    }
    // 合流後の具体区間は診断の有無だけでは区別できないため、本体出力で確認する。
    cases.extend([
        ("return if x = -2 or x = 3 then x else 0 end if".into(), Some((-2, 3)), 0),
        ("return if x >= 2 and x <= 4 then x else 3 end if".into(), Some((2, 4)), 0),
        ("return if not (x < 2 or x > 4) then x else 3 end if".into(), Some((2, 4)), 0),
        ("return if x < 0 or x > 0 then x else 0 end if".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("return if not false then 7 else 10 div 0 end if".into(), Some((7, 7)), 0),
        ("return if ((x)) = ((alias)) then x else 0 end if".into(), Some((0, 0)), 0),
        ("return if x = computed then x else 0 end if".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("bind k <- 0\n return if x = k then x else 0 end if".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("return if x = other then x else 0 end if".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("return if x + 1 < 0 then x else -1 end if".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("return if x = -9223372036854775808 then x else -9223372036854775808 end if".into(), Some((Interval::MIN, Interval::MIN)), 0),
        ("return if x <> 9223372036854775807 then 9223372036854775807 else x end if".into(), Some((Interval::MAX, Interval::MAX)), 0),
        ("return if x < 9223372036854775807 then x else -1 end if".into(), Some((Interval::MIN, Interval::MAX - 1)), 0),
        ("return if x > -9223372036854775808 then x else 0 end if".into(), Some((Interval::MIN + 1, Interval::MAX)), 0),
        ("bind n <- if flag then -2 else 2 end if\n return if n = 0 then 1 else n end if".into(), Some((-2, 2)), 0),
        ("bind n <- if flag then 0 else 2 end if\n return if n <> 0 then n else 1 end if".into(), Some((1, 2)), 0),
        ("bind n <- if flag then -2 else 0 end if\n return if n = 0 then -1 else n end if".into(), Some((-2, -1)), 0),
        ("return if flag then -2 else if x = 0 then 7 else 2 end if".into(), Some((-2, 7)), 0),
        ("return if x < 0 then x else if x = 0 then 0 else 1 end if".into(), Some((Interval::MIN, 1)), 0),
        ("if x = 0 then bind y <- 10 div x end if\n return x".into(), Some((Interval::MIN, Interval::MAX)), 1),
        ("if x <> 0 then return 1 end if\n return x".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("bind copy <- x\n return if x = 0 then copy else 0 end if".into(), Some((Interval::MIN, Interval::MAX)), 0),
        ("return if x = 0 then block shadow x <- 7\n x end block else 0 end if".into(), Some((0, 7)), 0),
        ("return if flag then block bind n <- 9223372036854775807\n n + 1 end block else 7 end if".into(), Some((7, 7)), 1),
        ("return if true then 7 else 10 div 0 end if".into(), Some((7, 7)), 0),
        ("return if false then 10 div 0 else 7 end if".into(), Some((7, 7)), 0),
        ("return if (if flag then true else true end if) then 7 else 10 div 0 end if".into(), Some((7, 7)), 0),
        ("if false then bind n <- 10 div 0 end if\n return 7".into(), Some((7, 7)), 0),
        ("bind n <- 0s8\n return if n = 0s8 then 7 else 9 end if".into(), Some((7, 7)), 0),
        ("return if x <= -9223372036854775808 then x else -9223372036854775808 end if".into(), Some((Interval::MIN, Interval::MIN)), 0),
        ("return if x >= 9223372036854775807 then x else 9223372036854775807 end if".into(), Some((Interval::MAX, Interval::MAX)), 0),
        ("return if flag then 10 div 0 else 20 mod 0 end if".into(), Some((Interval::MIN, Interval::MAX)), 2),
        ("bind n <- 0\n return if n <> 0 then 10 div 0 else n end if".into(), Some((0, 0)), 0),
        ("bind n <- 0\n return if n = 0 then n else 10 div 0 end if".into(), Some((0, 0)), 0),
        ("return if x = 0 then block if x <> 0 then bind n <- 10 div 0 end if\n x end block else 0 end if".into(), Some((0, 0)), 0),
        ("return if (block bind n <- 9223372036854775807\n n + 1 end block) = 0 then 10 div 0 else 20 mod 0 end if".into(), None, 1),
    ]);
    for condition in ["x < -9223372036854775808", "x > 9223372036854775807"] {
        cases.push((
            format!("return if {condition} then 10 div 0 else 7 end if"),
            Some((7, 7)),
            0,
        ));
    }
    for condition in ["x >= -9223372036854775808", "x <= 9223372036854775807"] {
        cases.push((
            format!("return if {condition} then 7 else 10 div 0 end if"),
            Some((7, 7)),
            0,
        ));
    }
    for (index, (body, _, _)) in cases.iter().enumerate() {
        source.push_str(&format!("function case{index}(x: Integer, other: Integer, flag: Boolean) -> Integer\n {body}\nend function\n"));
    }
    let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    for (index, (source, expected, count)) in cases.iter().enumerate() {
        let body = output
            .interval
            .bodies
            .iter()
            .find(|b| b.name == format!(".case{index}"))
            .unwrap();
        assert_eq!(body.coverage, Coverage::Prepared, "{source}");
        let flow = body.flow.as_ref().unwrap();
        let value = flow.value.as_ref().unwrap();
        assert_eq!(value.returned.bounds(), *expected, "{source}");
        assert!(!value.live && value.normal.is_bottom(), "{source}");
        assert_eq!(flow.candidates.len(), *count, "{source}");
        assert_eq!(body.usage.temporary, 0, "{source}");
    }
}

// 関門: 予算停止の途中でも分岐の一時環境と枠を返し、保存済み候補を保持する。
// 通常上限の表では停止を起こせないため、既存の型付き入力の準備を使う。
#[test]
fn branch_scopes_release_temporary_state_and_keep_candidates_on_budget_stop() {
    use budget::{Cap, Limits};
    for (source, max_limit) in [
        // 腕・選択肢・guard の途中停止で、候補の接頭辞と一時保持の返却を守る。
        (
            "function branches(x: Integer) -> Integer\n return match x with\n case -1, 1 if x = 0 -> 10 div x\n case n if n = 0 -> 20 mod n\n case _ -> 30 div 0 end match\nend function\n",
            900,
        ),
        (
            "function branches(x: Integer) -> Integer\n return if ((x)) = ((0)) then block bind first <- 10 div x\n 20 mod 0 end block else if x = 1 then 30 div 0 else 7 end if\nend function\n",
            350,
        ),
        (
            "function branches(x: Integer) -> Integer\n return if ((x)) = ((0)) or (x = 1 and x <= 0) then block bind first <- 10 div x\n 20 mod 0 end block else if not (x < 1 or x > 1) then 30 div 0 else 7 end if\nend function\n",
            700,
        ),
        // 同じ元演算の候補も展開ごとに保存・計上し、停止前の接頭辞を失わない。
        (
            "const c: Boolean = 0 div 1 <> 0 and (10 div 0 = 1)\nfunction branches(x: Integer) -> Boolean\n bind first <- c\n bind second <- c\n return c\nend function\n",
            700,
        ),
    ] {
        identity::tests::fixture_owned(source, |inputs, tables| {
            let constants = inputs
                .iter()
                .filter(|input| matches!(input.definition.source, BodySource::Constant(_)))
                .map(|input| (input.definition.binding, input))
                .collect();
            let input = inputs.last().unwrap();
            for items in [false, true] {
                let mut completed = false;
                let mut saved_then_stopped = false;
                for limit in 1..=max_limit {
                    let mut budget = Budget {
                        limits: Limits {
                            body: Cap {
                                operations: if items { 2000 } else { limit },
                                items: if items { limit } else { 2000 },
                            },
                            whole: Cap {
                                operations: 2000,
                                items: 2000,
                            },
                        },
                        ..Budget::default()
                    };
                    let analysis = analyze_body(input, tables, &constants, &mut budget, 100);
                    assert_eq!(budget.body.temporary, 0, "items={items}, limit={limit}");
                    if let Some(flow) = analysis.flow {
                        // 識別対応・候補に加え、発見まで共有する根の引数環境を保存する。
                        // 補助位置の有無・件数では増えない。
                        assert_eq!(
                            budget.body.saved,
                            u64::try_from(
                                analysis.identity.as_ref().unwrap().occurrences.len()
                                    + flow.candidates.len()
                                    + input.definition.source.params().len()
                            )
                            .unwrap(),
                            "items={items}, limit={limit}"
                        );
                        let operations: Vec<_> = flow
                            .candidates
                            .iter()
                            .map(|c| match c.operation {
                                arithmetic::TargetOperation::Binary(op) => op,
                                arithmetic::TargetOperation::Neg
                                | arithmetic::TargetOperation::Standard { .. } => {
                                    panic!("unexpected non-binary candidate")
                                }
                            })
                            .collect();
                        let expected = if constants.is_empty() {
                            vec![
                                crate::syntax::ast::BinOp::IntDiv,
                                crate::syntax::ast::BinOp::Mod,
                                crate::syntax::ast::BinOp::IntDiv,
                            ]
                        } else {
                            vec![crate::syntax::ast::BinOp::IntDiv; 3]
                        };
                        assert!(expected.starts_with(&operations));
                        if !constants.is_empty() {
                            let mut preorders = Vec::new();
                            for candidate in &flow.candidates {
                                assert!(!preorders.contains(&candidate.preorder));
                                preorders.push(candidate.preorder);
                                assert_eq!(candidate.origin.node, flow.candidates[0].origin.node);
                            }
                        }
                        match flow.value {
                            Ok(value) => {
                                completed = true;
                                if constants.is_empty() {
                                    assert_eq!(value.returned, Interval::top());
                                } else {
                                    assert_eq!(value.boolean, (false, false));
                                }
                                assert_eq!(flow.candidates.len(), 3);
                            }
                            Err(IdentityStop::AnalysisBudget(_)) => {
                                saved_then_stopped |= !flow.candidates.is_empty()
                            }
                            Err(other) => panic!("unexpected stop: {other:?}"),
                        }
                    }
                }
                assert!(completed && saved_then_stopped, "items={items}");
            }
        });
    }
}

// 関門: 型検査の出力で、成功値の区間と途中の失敗、候補の原因と位置を確かめる。
// 既存の束縛の表では、全域外と一部のあふれ、子 Bottom の取り違えを観察できない。
// 本物の型と元 AST から得た入力を使い、算術の非公開関数のテストを重ねない。
#[test]
fn integer_arithmetic_keeps_successful_values_and_conditional_failure_candidates() {
    use crate::syntax::ast::BinOp::{Add, IntDiv, Mod};
    use arithmetic::Cause::{Overflow, ZeroDivisor};
    let cases = [
        ("safe", "return 1 + 2", Some((3, 3)), false, vec![]),
        (
            "minimum",
            "return -9223372036854775808 + 0",
            Some((Interval::MIN, Interval::MIN)),
            false,
            vec![],
        ),
        (
            "maximum",
            "return 9223372036854775807 + 0",
            Some((Interval::MAX, Interval::MAX)),
            false,
            vec![],
        ),
        (
            "partialUpper",
            "return x + 1",
            Some((Interval::MIN + 1, Interval::MAX)),
            true,
            vec![],
        ),
        (
            "partialLower",
            "return x + -1",
            Some((Interval::MIN, Interval::MAX - 1)),
            true,
            vec![],
        ),
        (
            "overflowUpper",
            "bind n <- 9223372036854775807\n return n + 1",
            None,
            true,
            vec![(Add, Overflow, "n + 1")],
        ),
        (
            "overflowLower",
            "bind n <- -9223372036854775808\n return n + -1",
            None,
            true,
            vec![(Add, Overflow, "n + -1")],
        ),
        (
            "intermediate",
            "bind n <- 9223372036854775807\n return (n + 1) + -1",
            None,
            true,
            vec![(Add, Overflow, "n + 1")],
        ),
        (
            "rightBottom",
            "bind n <- 9223372036854775807\n return 1 + (n + 1)",
            None,
            true,
            vec![(Add, Overflow, "n + 1")],
        ),
        (
            "skippedRight",
            "bind n <- 9223372036854775807\n return (n + 1) + (10 div 0)",
            None,
            true,
            vec![(Add, Overflow, "n + 1")],
        ),
        (
            "divisionBottom",
            "bind n <- 9223372036854775807\n return (n + 1) div 0",
            None,
            true,
            vec![(Add, Overflow, "n + 1")],
        ),
        (
            "remainderBottom",
            "bind n <- 9223372036854775807\n return 10 mod (n + 1)",
            None,
            true,
            vec![(Add, Overflow, "n + 1")],
        ),
        (
            "zeroDivisor",
            "bind z <- 0\n return 10 div z",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![(IntDiv, ZeroDivisor, "z")],
        ),
        (
            "zeroRemainder",
            "bind z <- 0\n return 10 mod z",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![(Mod, ZeroDivisor, "z")],
        ),
        (
            "nonzero",
            "return 10 div 2",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![],
        ),
        (
            "unknownDivisor",
            "return 10 mod x",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![],
        ),
        (
            "minimumDivision",
            "return -9223372036854775808 div -1",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![],
        ),
        (
            "minimumRemainder",
            "return -9223372036854775808 mod -1",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![],
        ),
        // 各段の正常値を交差すると d は [-1,1] になる。0 を含むだけでは候補にしない。
        (
            "straddlingZero",
            "bind d <- (((x + 9223372036854775806) + 9223372036854775807) + -9223372036854775808) + 2\n return 10 div d",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![],
        ),
        (
            "straddlingValue",
            "return (((x + 9223372036854775806) + 9223372036854775807) + -9223372036854775808) + 2",
            Some((-1, 1)),
            true,
            vec![],
        ),
        (
            "candidateOrder",
            "return (10 div 0) + (20 mod 0)",
            Some((Interval::MIN, Interval::MAX)),
            true,
            vec![(IntDiv, ZeroDivisor, "0"), (Mod, ZeroDivisor, "0")],
        ),
        (
            "otherWidth",
            "bind n <- 1s8 + 2s8\n return 7",
            Some((7, 7)),
            false,
            vec![],
        ),
        (
            "otherOperation",
            "return (x * 2) + 1",
            Some((Interval::MIN + 1, Interval::MAX)),
            true,
            vec![],
        ),
    ];
    let source: String = cases
        .iter()
        .map(|(name, body, ..)| {
            format!("function {name}(x: Integer) -> Integer\n {body}\nend function\n")
        })
        .collect();
    let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    assert_eq!(output.interval.bodies.len(), cases.len());
    for ((name, _, expected, may_fail, candidates), body) in
        cases.into_iter().zip(&output.interval.bodies)
    {
        assert_eq!(body.name, format!(".{name}"));
        assert_eq!(body.coverage, Coverage::Prepared, "{name}");
        let flow = body.flow.as_ref().unwrap();
        let value = flow.value.as_ref().unwrap();
        assert_eq!(value.returned.bounds(), expected, "{name}");
        assert!(value.normal.is_bottom() && !value.live, "{name}");
        assert_eq!(value.may_fail, may_fail, "{name}");
        assert_eq!(flow.candidates.len(), candidates.len(), "{name}");
        for (candidate, (operation, cause, primary)) in flow.candidates.iter().zip(candidates) {
            assert_eq!(
                (candidate.operation, candidate.cause),
                (arithmetic::TargetOperation::Binary(operation), cause),
                "{name}"
            );
            let start = usize::try_from(candidate.primary.start.0).unwrap();
            let end = usize::try_from(candidate.primary.end.0).unwrap();
            assert_eq!(&source[start..end], primary, "{name}");
            assert!(candidate.preorder > 0, "{name}");
            assert!(
                !candidate.left.is_bottom() && !candidate.right.is_bottom(),
                "{name}"
            );
            if cause == ZeroDivisor {
                assert_eq!(candidate.right.bounds(), Some((0, 0)), "{name}");
            }
        }
        if name == "overflowUpper" {
            let candidate = &flow.candidates[0];
            assert_eq!(candidate.preorder, 3);
            assert_eq!(candidate.origin.span, candidate.primary);
            assert_eq!(
                candidate.left.bounds(),
                Some((Interval::MAX, Interval::MAX))
            );
            assert_eq!(candidate.right.bounds(), Some((1, 1)));
        }
        assert_eq!(body.usage.temporary, 0, "{name}");
    }
}

// 関門: 解析の途中停止でも保存済み候補は本体の結果に残すという独立した契約。
// 既存の停止テストには候補がなく、全消去や未確保の候補の追加を検出できない。
#[test]
fn arithmetic_candidates_survive_later_budget_stops() {
    use budget::{Cap, Limits};
    identity::tests::fixture_owned(
        "function warnings() -> Integer\n bind z <- 0\n bind _ <- 10 div z\n bind _ <- 20 mod z\n return 7\nend function\n",
        |inputs, tables| {
            let input = &inputs[0];
            let constants = BTreeMap::new();
            for items in [false, true] {
                let mut saved_then_stopped = false;
                let mut completed = false;
                for limit in 1..=200 {
                    let mut budget = Budget {
                        limits: Limits {
                            body: Cap {
                                operations: if items { 1000 } else { limit },
                                items: if items { limit } else { 1000 },
                            },
                            whole: Cap {
                                operations: 1000,
                                items: 1000,
                            },
                        },
                        ..Budget::default()
                    };
                    let analysis = analyze_body(input, tables, &constants, &mut budget, 100);
                    assert_eq!(budget.body.temporary, 0, "items={items}, limit={limit}");
                    if let Some(flow) = analysis.flow {
                        let operations: Vec<_> = flow
                            .candidates
                            .iter()
                            .map(|c| match c.operation {
                                arithmetic::TargetOperation::Binary(op) => op,
                                arithmetic::TargetOperation::Neg
                                | arithmetic::TargetOperation::Standard { .. } => {
                                    panic!("unexpected non-binary candidate")
                                }
                            })
                            .collect();
                        assert!(
                            [
                                crate::syntax::ast::BinOp::IntDiv,
                                crate::syntax::ast::BinOp::Mod
                            ]
                            .starts_with(&operations)
                        );
                        assert!(
                            flow.candidates
                                .iter()
                                .all(|c| c.cause == arithmetic::Cause::ZeroDivisor)
                        );
                        match flow.value {
                            Ok(value) => {
                                completed = true;
                                assert_eq!(value.returned.bounds(), Some((7, 7)));
                                assert_eq!(flow.candidates.len(), 2);
                            }
                            Err(IdentityStop::AnalysisBudget(_)) => {
                                saved_then_stopped |= !flow.candidates.is_empty();
                            }
                            Err(other) => panic!("unexpected stop: {other:?}"),
                        }
                    }
                }
                assert!(saved_then_stopped && completed, "items={items}");
            }
        },
    );
}

// 関門: 型検査の出力に保存した本体の区間を確かめる。番号付けだけの既存検査は、
// 束縛の取り違えや構造の内部・可変内容からの過剰な推測を捕まえられない。
// 本物の収集・駆動を通し、環境の保存形式や操作の厳密な件数には依存しない。
#[test]
fn local_binding_values_survive_shadow_and_block_scope() {
    let mut source = String::from("const answer: Integer = 7\n");
    let cases = [
        ("direct", "bind n <- 7\n return n", Some((7, 7))),
        (
            "alias",
            "bind n <- 7\n bind alias <- n\n shadow n <- 9\n return alias",
            Some((7, 7)),
        ),
        (
            "shadowed",
            "bind n <- 7\n shadow n <- -9\n return n",
            Some((-9, -9)),
        ),
        (
            "wildcard",
            "bind n <- 7\n bind _ <- 9\n return n",
            Some((7, 7)),
        ),
        (
            "scope",
            "bind n <- 7\n bind _ <- block shadow n <- 9\n n end block\n return n",
            Some((7, 7)),
        ),
        (
            "nested",
            "bind n <- block bind n <- -9\n n end block\n return n",
            Some((-9, -9)),
        ),
        ("constant", "bind n <- answer\n return n", Some((7, 7))),
        (
            "parameter",
            "bind n <- x\n return n",
            Some((Interval::MIN, Interval::MAX)),
        ),
        (
            "minimum",
            "bind n <- -9223372036854775808\n return n",
            Some((Interval::MIN, Interval::MIN)),
        ),
        (
            "maximum",
            "bind n <- 9223372036854775807\n return n",
            Some((Interval::MAX, Interval::MAX)),
        ),
        (
            "boundary",
            "bind n <- 7\n bind f <- lambda() -> Integer return 99 end lambda\n return n",
            Some((7, 7)),
        ),
    ];
    for (name, body, _) in &cases {
        source.push_str(&format!(
            "function {name}(x: Integer) -> Integer\n {body}\nend function\n"
        ));
    }
    let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    for (name, _, expected) in cases {
        let body = output
            .interval
            .bodies
            .iter()
            .find(|b| b.name == format!(".{name}"))
            .unwrap();
        assert_eq!(body.coverage, Coverage::Prepared, "{name}");
        let value = body.flow.as_ref().unwrap().value.as_ref().unwrap();
        assert_eq!(value.returned.bounds(), expected, "{name}");
        assert!(value.normal.is_bottom(), "{name}");
        assert!(!value.live, "{name}");
        assert_eq!(body.usage.temporary, 0, "{name}");
    }
}

#[test]
fn destructured_and_mutable_contents_do_not_become_integer_facts() {
    let source = "import Benitoite.StringBuilder\nrecord Box\n value: Integer\nend record\nfunction pair() -> Integer\n bind Pair(a, b) <- Pair(7, 9)\n return a\nend function\nfunction recordValue() -> Integer\n bind Box(value: n) <- Box(value: 7)\n return n\nend function\nfunction reference() -> Integer uses State\n bind cell <- Reference.new(7)\n bind n <- Reference.get(cell)\n return n\nend function\nfunction builder() -> Integer\n bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(text: \"abc\", builder: b)\n bind n <- StringBuilder.byteLength(b)\n return n\nend function\n";
    let (_, _, output, diagnostics) = check_files(&[("main.bnt", source)], false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    assert_eq!(output.interval.bodies.len(), 4);
    for body in output.interval.bodies {
        assert_eq!(body.coverage, Coverage::Prepared, "{}", body.name);
        assert_eq!(
            body.flow.unwrap().value.unwrap().returned,
            Interval::top(),
            "{}",
            body.name
        );
        assert_eq!(body.usage.temporary, 0);
    }
}

// 関門: 停止時の一時環境の解放は共有予算の独立した契約である。
// 通常の上限の公開検査では、辞書追加と復元用保存の途中の停止を強制できない。
// 既存の本物の型付き入力の準備と本体入口を使い、停止位置の実装には依存しない。
#[test]
fn local_environment_is_released_at_every_budget_stop() {
    use budget::{Cap, Limits};
    identity::tests::fixture_owned(
        "function scoped() -> Integer\n bind n <- 7\n bind copy <- block bind alias <- n\n shadow n <- -9\n alias end block\n return copy\nend function\n",
        |inputs, tables| {
            let constants = BTreeMap::new();
            let input = &inputs[0];
            for items in [false, true] {
                let mut stopped = 0;
                let mut completed = 0;
                for limit in 1..=100 {
                    let mut budget = Budget {
                        limits: Limits {
                            body: Cap {
                                operations: if items { 1000 } else { limit },
                                items: if items { limit } else { 1000 },
                            },
                            whole: Cap {
                                operations: 1000,
                                items: 1000,
                            },
                        },
                        ..Budget::default()
                    };
                    let analysis = analyze_body(input, tables, &constants, &mut budget, 100);
                    assert_eq!(budget.body.temporary, 0, "items={items}, limit={limit}");
                    match analysis.coverage {
                        Coverage::Prepared => {
                            completed += 1;
                            assert_eq!(
                                analysis.flow.unwrap().value.unwrap().returned.bounds(),
                                Some((7, 7))
                            );
                        }
                        Coverage::Stopped(IdentityStop::AnalysisBudget(_)) => {
                            stopped += 1;
                            assert!(analysis.flow.is_none_or(|flow| flow.value.is_err()));
                        }
                        other @ (Coverage::None | Coverage::Stopped(_)) => {
                            panic!("unexpected coverage: {other:?}")
                        }
                    }
                }
                assert!(stopped > 0 && completed > 0);
            }
        },
    );
}

#[test]
fn accepted_polymorphic_failure_calls_are_collected() {
    let source = "import Benitoite.Unofficial.Failure\nfunction recover() -> Integer\n return handle Failure.raise(\"bad\") with case Failure.raise(error) -> 7 end handle\nend function\nfunction from(r: Result[Integer, String]) -> Integer\n return handle Failure.fromResult(r) with case Failure.raise(error) -> 8 end handle\nend function\n";
    let (_, _, output, diagnostics) = check_files(&[("main.bnt", source)], false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    assert_eq!(output.interval.bodies.len(), 4);
    assert_eq!(
        output.interval.bodies.len(),
        output.interval.definitions.len() + 2
    );
    for body in &output.interval.bodies {
        assert_eq!(body.coverage, Coverage::Prepared, "{}", body.name);
    }
}

#[test]
fn source_order_is_independent_of_constant_evaluation_and_function_checking() {
    let source = "import M\nfunction first() -> Integer\n return later\nend function\nconst later: Integer = dependency + 1\nfunction second(x: Integer) -> Integer\n return x + later\nend function\nconst dependency: Integer = 2\ntrait Echo[T]\n function echo(value: T) -> T\nend trait\nimplement Echo[Integer]\n function echo(value: Integer) -> Integer return value end function\nend implement\n";
    let (_, _, output, diagnostics) = check_files(
        &[
            ("main.bnt", source),
            (
                "M.bnt",
                "public const value: Integer = 4\npublic function last() -> Integer return value end function\n",
            ),
        ],
        false,
    );
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    let bodies = &output.interval.bodies;
    assert_eq!(
        bodies.iter().map(|b| b.name.as_str()).collect::<Vec<_>>(),
        [
            ".first",
            ".later",
            ".second",
            ".dependency",
            "%impl:5:0:echo",
            "M.value",
            "M.last"
        ]
    );
    assert!(bodies.iter().all(|b| b.coverage == Coverage::Prepared));
    // main と M の分類は全体だけに残し、元定義の本体消費へ含めない。
    assert_eq!(
        output.interval.whole.operations,
        2 + bodies.iter().map(|b| b.usage.operations).sum::<u64>()
    );
    assert_eq!(
        output.interval.whole.saved,
        bodies.iter().map(|b| b.usage.saved).sum::<u64>()
    );
    assert!(bodies.iter().all(|b| b.usage.temporary == 0));
    // 定数の値を一点に置換せず、元の依存先を展開して番号を取得する。
}

#[test]
fn invalid_body_is_not_analyzed_and_healthy_neighbor_is_prepared() {
    for (wrong, finish_error) in [
        (
            "function wrong() -> Integer return \"bad\" end function\n",
            false,
        ),
        (
            "import Benitoite.Unofficial.Failure\nfunction wrong() -> Integer return handle 1 with case Failure.raise(error) -> 2 end handle end function\n",
            true,
        ),
    ] {
        let source =
            format!("{wrong}function healthy(x: Integer) -> Integer return x + 1 end function\n");
        let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(diagnostics.iter().any(Diagnostic::is_error));
        if finish_error {
            assert!(
                diagnostics
                    .iter()
                    .any(|d| d.code == Some(crate::diag::DiagCode::E0517))
            );
        }
        assert_eq!(output.interval.bodies.len(), 2);
        assert_eq!(output.interval.bodies[0].coverage, Coverage::None);
        assert_eq!(output.interval.bodies[1].coverage, Coverage::Prepared);
    }
}

#[test]
fn budget_rejection_is_atomic_and_saved_items_survive_body_end() {
    use budget::{Cap, Limits, Operation, Resource, Scope};
    for resource in [Resource::Operations, Resource::Items] {
        let mut budget = Budget {
            limits: Limits {
                body: Cap {
                    operations: 2,
                    items: 2,
                },
                whole: Cap {
                    operations: 3,
                    items: 3,
                },
            },
            ..Budget::default()
        };
        let take = |budget: &mut Budget| match resource {
            Resource::Operations => budget.charge(Operation::Expression),
            Resource::Items => budget.reserve(Item::Identity, Lifetime::Saved),
        };
        take(&mut budget).unwrap();
        take(&mut budget).unwrap();
        let before = (budget.body, budget.whole);
        assert_eq!(
            take(&mut budget),
            Err(StopReason::Exceeded(budget::LimitFailure {
                scope: Scope::Body,
                resource
            }))
        );
        assert_eq!((budget.body, budget.whole), before);
        let first = budget.finish_body();
        assert_eq!(first.temporary, 0);
        take(&mut budget).unwrap();
        let before = (budget.body, budget.whole);
        assert_eq!(
            take(&mut budget),
            Err(StopReason::Exceeded(budget::LimitFailure {
                scope: Scope::Whole,
                resource
            }))
        );
        assert_eq!((budget.body, budget.whole), before);
    }
    let mut budget = Budget::default();
    budget
        .reserve(Item::StackFrame, Lifetime::Temporary)
        .unwrap();
    budget.reserve(Item::Warning, Lifetime::Saved).unwrap();
    budget.release(Lifetime::Temporary, 1);
    budget.finish_body();
    assert_eq!(budget.whole.saved, 1);
    assert_eq!(budget.whole.peak, 2);
}

#[test]
fn body_stop_continues_but_whole_stop_keeps_remaining_inputs_without_new_outputs() {
    use budget::{Cap, Limits, Scope};
    let source = "function wide() -> Integer return 1 + 2 end function\nfunction narrow() -> Unit end function\nfunction last() -> Unit end function\n";
    for (scope, items) in [
        (Scope::Body, false),
        (Scope::Whole, false),
        (Scope::Body, true),
        (Scope::Whole, true),
    ] {
        identity::tests::fixture_owned(source, |inputs, tables| {
            let low = Cap {
                operations: if items { 100 } else { 5 },
                items: if items { 0 } else { 100 },
            };
            let high = Cap {
                operations: 100,
                items: 100,
            };
            let limits = match scope {
                Scope::Body => Limits {
                    body: low,
                    whole: high,
                },
                Scope::Whole => Limits {
                    body: high,
                    whole: low,
                },
            };
            let mut state = AnalysisState {
                modules: vec![crate::base::ModuleId(0)],
                pending: inputs
                    .into_iter()
                    .map(|input| {
                        (
                            input.definition.source.node(),
                            Box::new(Pending {
                                definition: input.definition.clone(),
                                input: Some(Ok(input)),
                            }),
                        )
                    })
                    .collect(),
                budget: Budget {
                    limits,
                    ..Budget::default()
                },
                warnings: diagnostics::Warnings::default(),
            };
            let report = state.analyze(tables, 100, &mut Vec::new());
            assert_eq!(state.budget.body.temporary, 0);
            match scope {
                Scope::Body if items => {
                    // 保持上限0はモジュール自身の枠で止まり、定義を開始しない。
                    assert_eq!(report.summary().phase_stops.exceeded.body_items, 1);
                    assert_eq!(report.whole.saved, 0);
                    assert!(report.bodies.is_empty());
                    assert!(report.definitions.is_empty());
                    assert_eq!(report.remaining_modules, [crate::base::ModuleId(0)]);
                    assert_eq!(
                        report.stopped,
                        Some(StopReason::Exceeded(budget::LimitFailure {
                            scope,
                            resource: budget::Resource::Items
                        }))
                    );
                }
                Scope::Body => {
                    assert_eq!(report.bodies.len(), 3);
                    assert!(matches!(
                        report.bodies[0].coverage,
                        Coverage::Stopped(IdentityStop::AnalysisBudget(_))
                    ));
                    assert_eq!(report.bodies[1].coverage, Coverage::Prepared);
                    assert_eq!(report.bodies[2].coverage, Coverage::Prepared);
                    assert!(report.stopped.is_none());
                    assert!(report.remaining.is_none());
                }
                Scope::Whole => {
                    assert!(matches!(
                        report.stopped.unwrap(),
                        StopReason::Exceeded(budget::LimitFailure {
                            scope: budget::Scope::Whole,
                            ..
                        }) | StopReason::Unidentified(budget::LimitFailure {
                            scope: budget::Scope::Whole,
                            ..
                        })
                    ));
                    if items {
                        assert!(report.remaining.is_none());
                        assert_eq!(report.remaining_modules, [crate::base::ModuleId(0)]);
                    } else {
                        assert_eq!(report.remaining.unwrap().declaration, 1);
                    }
                    assert_eq!(report.bodies.len(), if items { 0 } else { 1 });
                    assert_eq!(report.whole.operations, if items { 0 } else { 5 });
                }
            }
        });
    }
}

#[test]
fn reaching_whole_limit_exactly_does_not_allocate_the_next_body() {
    identity::tests::fixture_owned(
        "function one() -> Unit end function\nfunction two() -> Unit end function\n",
        |inputs, tables| {
            let mut state = AnalysisState {
                modules: vec![crate::base::ModuleId(0)],
                pending: inputs
                    .into_iter()
                    .map(|input| {
                        (
                            input.definition.source.node(),
                            Box::new(Pending {
                                definition: input.definition.clone(),
                                input: Some(Ok(input)),
                            }),
                        )
                    })
                    .collect(),
                budget: Budget::default(),
                warnings: diagnostics::Warnings::default(),
            };
            state.budget.limits.whole.operations = 2;
            let report = state.analyze(tables, 100, &mut Vec::new());
            // module と bodySlot の分類で2操作を使い、prepareRoot 内で停止する。
            // 出力枠は一つ保存するが、根の解析と次の定義は開始しない。
            assert!(report.bodies.is_empty());
            assert_eq!(report.definitions.len(), 1);
            assert_eq!(
                report.definitions[0].prepared,
                Some(Err(IdentityStop::AnalysisBudget(StopReason::Exceeded(
                    budget::LimitFailure {
                        scope: budget::Scope::Whole,
                        resource: budget::Resource::Operations
                    }
                ))))
            );
            assert_eq!(report.remaining.unwrap().declaration, 1);
            assert!(matches!(
                report.stopped.unwrap(),
                StopReason::Exceeded(budget::LimitFailure {
                    scope: budget::Scope::Whole,
                    ..
                }) | StopReason::Unidentified(budget::LimitFailure {
                    scope: budget::Scope::Whole,
                    ..
                })
            ));
            assert_eq!(report.whole.operations, 2);
            assert_eq!(report.whole.saved, 1);
        },
    );
}

// 関門: 独立入力の保存順と停止前の候補は交換の契約であり、利用者向けの
// 重複排除後の診断だけでは検証できない。既存の任意予算表へ同じ準備で接続する。
#[test]
fn independent_inputs_keep_postorder_results_and_release_every_temporary_scope() {
    let source = "function id(value: Integer) -> Boolean return value = 0 end function\nfunction sample() -> Boolean\n bind z <- 0\n return id(block bind q <- 0\n 10 div q end block) = (block bind n <- 9223372036854775807\n n + 1 = 0 end block)\nend function\n";
    identity::tests::fixture_owned(source, |inputs, tables| {
        let input = inputs.last().unwrap();
        let constants = BTreeMap::new();
        let mut complete = false;
        let mut stopped_with_candidate = false;
        for items in [false, true] {
            for limit in 0..500 {
                let mut budget = Budget::default();
                budget.limits.body = budget::Cap {
                    operations: if items { 2000 } else { limit },
                    items: if items { limit } else { 2000 },
                };
                let analysis = analyze_body(input, tables, &constants, &mut budget, 100);
                assert_eq!(budget.body.temporary, 0, "items={items}, limit={limit}");
                if let Some(flow) = analysis.flow {
                    assert!(flow.candidates.is_empty());
                    let candidates: Vec<_> = flow
                        .independent
                        .iter()
                        .flat_map(|i| &i.candidates)
                        .map(|c| c.preorder)
                        .collect();
                    assert!([8, 15].starts_with(&candidates));
                    assert_eq!(
                        budget.body.saved,
                        analysis.identity.unwrap().next
                            + u64::try_from(flow.independent.len() + candidates.len()).unwrap()
                    );
                    match flow.value {
                        Ok(value) => {
                            assert!(!value.live);
                            assert_eq!(value.returned, Interval::top());
                            assert_eq!(
                                flow.independent.iter().map(|i| i.start).collect::<Vec<_>>(),
                                [5, 6, 4, 11]
                            );
                            assert_eq!(candidates, [8, 15]);
                            assert_eq!(
                                flow.independent
                                    .iter()
                                    .map(|i| i.unsupported)
                                    .collect::<Vec<_>>(),
                                [true, false, true, false]
                            );
                            complete = true;
                        }
                        Err(IdentityStop::AnalysisBudget(_)) => {
                            stopped_with_candidate |= !candidates.is_empty();
                        }
                        Err(other) => panic!("unexpected stop {other:?}"),
                    }
                }
            }
        }
        assert!(complete && stopped_with_candidate);
    });
}

// 関門: 新しい発見・反転だけの計上を、Lean の独立した実行期待値と比較する。
// 本体全体の比較とは分け、停止時の発見した入口の保存と返却も確かめる。
#[test]
fn discovery_and_queue_keep_reference_costs_and_pending_entries() {
    identity::tests::fixture_owned(
        "function empty() -> Unit\n bind f <- lambda() -> Unit end lambda\nend function\nfunction param() -> Unit\n bind f <- lambda(x: Integer) -> Unit end lambda\nend function\n",
        |inputs, tables| {
            // BudgetDiscovery.discover の (operations,saved,peak,temporary) は
            // 空引数 (7,1,6,0)、一引数 (11,2,8,0)。根の prepareRoot は一操作、
            // prepareQueue は二分類と保存一項を追加する。位置の由来は計上しない。
            for (input, expected) in inputs.iter().zip([(10, 2, 6), (14, 3, 8)]) {
                let mut complete = Budget::default();
                let seed = discovery::prepare_root(input, tables, &BTreeMap::new(), &mut complete)
                    .unwrap();
                let report =
                    discovery::discover(input, tables, &BTreeMap::new(), seed, &mut complete, 100);
                assert_eq!(report.result, Ok(()));
                assert_eq!(report.queue, Some(Ok(())));
                assert_eq!(
                    (
                        complete.body.operations,
                        complete.body.saved,
                        complete.body.peak
                    ),
                    expected
                );
                assert_eq!(complete.body.temporary, 0);
                let mut saved_before_stop = false;
                for items in [false, true] {
                    for limit in 0..20 {
                        let mut budget = Budget::default();
                        budget.limits.body = budget::Cap {
                            operations: if items { 1000 } else { limit },
                            items: if items { limit } else { 1000 },
                        };
                        if let Ok(seed) =
                            discovery::prepare_root(input, tables, &BTreeMap::new(), &mut budget)
                        {
                            let report = discovery::discover(
                                input,
                                tables,
                                &BTreeMap::new(),
                                seed,
                                &mut budget,
                                100,
                            );
                            saved_before_stop |=
                                report.result.is_err() && !report.entries.is_empty();
                            if let Some(entry) = report.entries.last()
                                && entry.initial.is_none()
                            {
                                assert!(report.result.is_err());
                            }
                        }
                        assert_eq!(budget.body.temporary, 0, "items={items}, limit={limit}");
                    }
                }
                assert!(saved_before_stop);
            }
        },
    );
}
