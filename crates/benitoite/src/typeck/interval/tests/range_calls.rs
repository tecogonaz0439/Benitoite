//! 型検査済み本体から、標準callの引数と未知callの独立入力を比較する。
//! 関門: Rangeの表を持たない固定表では標準宣言・別名・親の局所事実を検査できない。
//! LeanのExamples・SyntacticReachExamplesの独立例に対応し、本番の差し込み口は増やさない。

use super::*;
use std::collections::BTreeMap;

fn inspect(source: &str, check: impl FnOnce(&flow::Analysis)) {
    inspect_files(&[("main.bnt", source)], check);
}

fn inspect_files(files: &[(&str, &str)], check: impl FnOnce(&flow::Analysis)) {
    identity::tests::fixture_files_owned(files, |inputs, tables| {
        let input = inputs
            .iter()
            .find(|input| input.definition.name.ends_with(".sample"))
            .unwrap();
        let mut budget = budget::Budget::default();
        let result = analyze_body(input, tables, &BTreeMap::new(), &mut budget, 200);
        assert_eq!(result.coverage, Coverage::Prepared);
        let analysis = result.flow.as_ref().unwrap();
        assert!(analysis.value.is_ok(), "{:?}", analysis.value);
        check(analysis);
    });
}

#[test]
fn range_call_arguments_match_lean_parent_and_independent_warning_examples() {
    // SyntacticReachExamples.callWithDivisionの根7を、本体の根の直後の1へ移す。
    // 期待値は元の独立例のキーから6を引いたもので、Rustの実行値から作らない。
    for (declaration, callee, recognized) in [
        (
            "import Benitoite.Unofficial.Range\n",
            "Range.checkInteger",
            true,
        ),
        (
            "import Benitoite.Unofficial.Range as R\n",
            "R.checkInteger",
            true,
        ),
        (
            "function checkInteger(minimum: Integer, maximum: Integer, value: Integer) -> Integer\n return value\nend function\n",
            "checkInteger",
            false,
        ),
    ] {
        let source = format!(
            "{declaration}function sample(x: Integer) -> Unit\n bind _ <- {callee}(minimum: x div 0, maximum: 0, value: 1)\nend function\n"
        );
        inspect(&source, |analysis| {
            let parent: Vec<_> = analysis.candidates.iter().map(|c| c.preorder).collect();
            let independent: Vec<_> = analysis
                .independent
                .iter()
                .map(|entry| {
                    (
                        entry.start,
                        entry
                            .candidates
                            .iter()
                            .map(|c| c.preorder)
                            .collect::<Vec<_>>(),
                    )
                })
                .collect();
            if recognized {
                assert_eq!(parent, [3], "{source}");
                assert!(independent.is_empty(), "{independent:?}");
            } else {
                assert!(parent.is_empty());
                assert_eq!(
                    independent,
                    [(2, vec![]), (3, vec![3]), (6, vec![]), (7, vec![])]
                );
            }
        });
    }
}

#[test]
fn range_call_arguments_keep_parent_facts_without_marking_unknown() {
    for (imports, callee) in [
        ("import Benitoite.Unofficial.Range", "Range.checkInteger"),
        ("import Benitoite.Unofficial.Range as R", "R.checkInteger"),
    ] {
        let source = format!(
            "{imports}\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n bind _ <- {callee}(value: x div zero, maximum: x + 9223372036854775807, minimum: 0)\nend function\n"
        );
        inspect(&source, |analysis| {
            assert_eq!(analysis.candidates.len(), 1);
            assert!(analysis.independent.is_empty());
            // divは正常値Topを保つので、後続の引数もソース順に解析する。
            assert!(!analysis.value.as_ref().unwrap().unsupported);
            assert!(!analysis.unsupported);
        });
    }
}

#[test]
fn range_calls_skip_remaining_arguments_after_abrupt_value_in_source_order() {
    for (args, expected) in [
        (
            "value: block return () end block, minimum: x div 0, maximum: 1",
            vec![],
        ),
        (
            "value: 9223372036854775807 + 1, minimum: x div 0, maximum: 1",
            vec![3],
        ),
        (
            "minimum: x div 0, value: 9223372036854775807 + 1, maximum: 1",
            vec![3, 6],
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range\nfunction sample(x: Integer) -> Unit\n bind _ <- Range.checkInteger({args})\nend function\n"
        );
        inspect(&source, |analysis| {
            assert_eq!(
                analysis
                    .candidates
                    .iter()
                    .map(|c| c.preorder)
                    .collect::<Vec<_>>(),
                expected
            );
            assert!(analysis.independent.is_empty());
            assert!(!analysis.value.as_ref().unwrap().live);
            assert!(!analysis.unsupported);
        });
    }
}

#[test]
fn range_value_argument_uses_parent_environment_without_projecting_bounds() {
    let source = "import Benitoite.Unofficial.Range as R\nfunction sample(checked: R.CheckedInteger, x: Integer) -> Unit\n bind zero <- 0\n bind _ <- R.value(block\n bind _ <- x div zero\n checked\n end block)\nend function\n";
    inspect(source, |analysis| {
        assert_eq!(analysis.candidates.len(), 1);
        assert!(analysis.independent.is_empty());
        assert!(!analysis.unsupported);
    });
}

#[test]
fn range_calls_exclude_function_values_holes_pipes_and_parenthesized_callees() {
    for body in [
        "bind f <- Range.checkInteger\n bind _ <- f(minimum: x div zero, maximum: 0, value: 1)",
        "bind _ <- Range.checkInteger(minimum: x div zero, maximum: 0, value: _)",
        "bind _ <- x div zero |> Range.checkInteger(maximum: 0, value: 1)",
        "bind _ <- (Range.checkInteger)(minimum: x div zero, maximum: 0, value: 1)",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n {body}\nend function\n"
        );
        inspect(&source, |analysis| {
            assert!(analysis.candidates.is_empty(), "{source}");
            assert!(!analysis.independent.is_empty());
            assert!(
                analysis
                    .independent
                    .iter()
                    .all(|entry| entry.candidates.is_empty()),
                "{source}"
            );
            assert!(analysis.unsupported);
        });
    }
}

#[test]
fn nested_unrecognized_call_keeps_its_warning_in_the_independent_input() {
    let source = "function checkInteger(minimum: Integer, maximum: Integer, value: Integer) -> Integer\n return value\nend function\nfunction sample(x: Integer) -> Unit\n bind _ <- [checkInteger(minimum: x div 0, maximum: 0, value: 1)]\nend function\n";
    inspect(source, |analysis| {
        assert!(analysis.candidates.is_empty());
        let entries: Vec<_> = analysis
            .independent
            .iter()
            .map(|entry| {
                (
                    entry.start,
                    entry
                        .candidates
                        .iter()
                        .map(|c| c.preorder)
                        .collect::<Vec<_>>(),
                )
            })
            .collect();
        // SyntacticReachExamplesのnestedと同じ列（開始キー7を2へ移した値）。
        assert_eq!(
            entries,
            [
                (3, vec![]),
                (4, vec![4]),
                (7, vec![]),
                (8, vec![]),
                (2, vec![])
            ]
        );
    });
}

#[test]
fn user_range_module_alias_is_not_the_standard_declaration() {
    let source = "import Benitoite.Unofficial.Range as Actual\nimport Fake as Range\nfunction sample(x: Integer) -> Unit\n bind _ <- Range.checkInteger(minimum: x div 0, maximum: 0, value: 1)\nend function\n";
    let fake = "public function checkInteger(minimum: Integer, maximum: Integer, value: Integer) -> Integer\n return value\nend function\n";
    inspect_files(&[("main.bnt", source), ("Fake.bnt", fake)], |analysis| {
        assert!(analysis.candidates.is_empty());
        assert_eq!(
            analysis
                .independent
                .iter()
                .map(|entry| entry.start)
                .collect::<Vec<_>>(),
            [2, 3, 6, 7]
        );
        assert_eq!(
            analysis
                .independent
                .iter()
                .flat_map(|entry| &entry.candidates)
                .map(|c| c.preorder)
                .collect::<Vec<_>>(),
            [3]
        );
        assert!(analysis.unsupported);
    });
}

// 関門: Resultの全腕を親の事実で読む契約と、由来を一度だけ保存する契約を守る。
// 既存のcallのテストは腕へ進まず、標準表のない固定表もこの退行を捕まえない。
// Examples.RangeSurfaceの接続例に、resultArmListに従う除数0の独立期待値を加える。
#[test]
fn range_result_matches_analyze_ok_error_guards_and_whole_patterns() {
    for (arms, keys) in [
        (
            "case Result.Ok(c) -> x div zero\n case Result.Error(e) -> x div zero",
            vec![8, 11],
        ),
        (
            "case Result.Ok(c) if x div zero = 1 -> x div zero\n case Result.Error(e) -> x div zero\n case _ -> 1",
            vec![9, 13, 16],
        ),
        (
            "case Result.Ok(_) -> x div zero\n case Result.Error(_) -> x div zero",
            vec![8, 11],
        ),
        (
            "case Result.Error(e) if x div zero = 1 -> x div zero\n case Result.Ok(c) -> x div zero\n case _ -> 1",
            vec![9, 13, 16],
        ),
        ("case Result.Ok(_), Result.Error(_) -> x div zero", vec![8]),
        ("case whole -> x div zero", vec![8]),
        ("case _ -> x div zero", vec![8]),
        (
            "case Result.Ok(c) if false -> x div zero\n case Result.Error(e) -> x div zero\n case _ -> x div zero",
            vec![12, 15],
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n bind _ <- match R.checkInteger(minimum: 0, maximum: 10, value: x) with\n {arms}\n end match\nend function\n"
        );
        inspect(&source, |analysis| {
            assert_eq!(
                analysis
                    .candidates
                    .iter()
                    .map(|c| c.preorder)
                    .collect::<Vec<_>>(),
                keys,
                "{source}"
            );
            assert!(analysis.independent.is_empty());
            assert!(!analysis.unsupported);
            assert!(!analysis.value.as_ref().unwrap().unsupported);
        });
    }
}

#[test]
fn range_result_origin_survives_one_save_but_not_aliases_or_repackaging() {
    let call = "R.checkInteger(minimum: 0, maximum: 10, value: x)";
    for (prefix, tested, recognized) in [
        (String::new(), call, true),
        (format!("bind saved <- {call}"), "saved", true),
        (
            format!("bind saved <- {call}\n bind alias <- saved"),
            "saved",
            true,
        ),
        (
            format!("bind saved <- {call}\n bind alias <- saved"),
            "alias",
            false,
        ),
        (
            format!("bind saved <- {call}\n shadow saved <- saved"),
            "saved",
            false,
        ),
        (format!("bind saved <- {call}"), "(saved)", false),
        (
            String::new(),
            "(R.checkInteger(minimum: 0, maximum: 10, value: x))",
            false,
        ),
        (
            format!("bind saved <- if flag then {call} else {call} end if"),
            "saved",
            false,
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer, flag: Boolean) -> Unit\n bind zero <- 0\n {prefix}\n bind _ <- match {tested} with\n case Result.Ok(c) -> x div zero\n case Result.Error(e) -> x div zero\n end match\nend function\n"
        );
        inspect(&source, |analysis| {
            assert_eq!(
                analysis.candidates.len(),
                if recognized { 2 } else { 0 },
                "{source}"
            );
            assert_eq!(analysis.unsupported, !recognized, "{source}");
            assert!(analysis.independent.is_empty());
        });
    }
    // 外側のOkの記録を、再包装したResultや外側の変数パターンへ移さない。
    for inner in [
        "bind wrapped: Result[R.CheckedInteger, R.RangeError] <- Result.Ok(c)\n wrapped",
        "Result.Ok(c)",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n bind _ <- match {call} with\n case Result.Ok(c) -> match block {inner} end block with\n case Result.Ok(other) -> x div zero\n case Result.Error(e) -> x div zero\n end match\n case Result.Error(e) -> 1\n end match\nend function\n"
        );
        inspect(&source, |analysis| {
            assert!(analysis.candidates.is_empty(), "{source}");
            assert!(analysis.unsupported);
        });
    }
}

#[test]
fn range_result_arm_bindings_are_unknown_and_do_not_replace_outer_facts() {
    let call = "R.checkInteger(minimum: 0, maximum: 10, value: x)";
    // 成功値・Error・Result全体は通常の整数位置へ変えない。
    for arms in [
        "case Result.Ok(c) -> match c with case _ -> x div zero end match\n case Result.Error(e) -> 1",
        "case Result.Ok(_) -> 1\n case Result.Error(e) -> match e with case _ -> x div zero end match",
        "case whole -> match whole with case Result.Ok(c) -> x div zero\n case Result.Error(e) -> x div zero end match",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n bind _ <- match {call} with\n {arms}\n end match\nend function\n"
        );
        inspect(&source, |analysis| {
            assert!(analysis.candidates.is_empty());
            assert!(analysis.independent.is_empty());
            assert!(analysis.unsupported);
        });
    }
    // guardと前の腕の局所束縛は、次の腕の親環境へ漏れない。
    let source = format!(
        "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer, zero: Integer) -> Unit\n bind _ <- match {call} with\n case Result.Ok(c) if zero = 0 -> block\n bind changed <- 0\n x div zero\n end block\n case Result.Error(e) -> x div zero\n case _ -> 1\n end match\nend function\n"
    );
    inspect(&source, |analysis| {
        assert_eq!(analysis.candidates.len(), 1);
        assert!(!analysis.unsupported);
    });
}

#[test]
fn range_result_match_in_independent_input_keeps_warnings_out_of_parent() {
    let source = "import Benitoite.Unofficial.Range as R\nfunction consume(value: Integer) -> Unit\n bind _ <- value\nend function\nfunction sample(x: Integer) -> Unit\n consume(match R.checkInteger(minimum: 0, maximum: 10, value: x) with\n case Result.Ok(c) -> x div 0\n case Result.Error(e) -> x div 0\n end match)\nend function\n";
    inspect(source, |analysis| {
        assert!(analysis.candidates.is_empty());
        assert!(analysis.unsupported);
        // Examples.RangeSurfaceの独立入力の例と同じく、子の元キーを使う。
        // 根call1、callee2、match3、check4、最初の腕9、次の腕12。
        assert_eq!(
            analysis
                .independent
                .iter()
                .map(|entry| (
                    entry.start,
                    entry
                        .candidates
                        .iter()
                        .map(|c| c.preorder)
                        .collect::<Vec<_>>(),
                    entry.unsupported,
                ))
                .collect::<Vec<_>>(),
            [(2, vec![], true), (3, vec![9, 12], false)]
        );
    });
}

#[test]
fn range_result_report_counts_only_user_bodies_and_actual_unsupported_inputs() {
    // 公開の型検査出力で集計まで確認する。本体の候補の検査だけでは集計の退行を防げない。
    for (setup, tested, unsupported, independent) in [
        (
            "",
            "R.checkInteger(minimum: 0, maximum: 10, value: x)",
            0,
            0,
        ),
        (
            "bind saved <- R.checkInteger(minimum: 0, maximum: 10, value: x)",
            "saved",
            0,
            0,
        ),
        (
            "bind saved <- R.checkInteger(minimum: 0, maximum: 10, value: x)\n bind alias <- saved",
            "alias",
            1,
            0,
        ),
        (
            "",
            "R.checkInteger(minimum: x, maximum: 10, value: x)",
            1,
            0,
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n {setup}\n bind _ <- match {tested} with\n case Result.Ok(c) -> x div zero\n case Result.Error(e) -> x div zero\n end match\nend function\n"
        );
        let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(
            !diagnostics.iter().any(Diagnostic::is_error),
            "{diagnostics:#?}"
        );
        let report = output.interval_analysis();
        assert_eq!(
            diagnostics
                .iter()
                .filter(|d| d.code == Some(crate::diag::DiagCode::W0401))
                .count(),
            if unsupported == 0 { 2 } else { 0 },
        );
        assert_eq!(report.input_definitions, 1);
        assert_eq!(report.unsupported_bodies, unsupported);
        assert_eq!(
            report.coverage,
            if unsupported == 0 {
                IntervalCoverage::All
            } else {
                IntervalCoverage::Some
            }
        );
        assert_eq!(output.interval.bodies.len(), 1);
        let body = output.interval.bodies[0].flow.as_ref().unwrap();
        assert_eq!(body.independent.len(), independent);
        assert_eq!(body.candidates.len(), if unsupported == 0 { 2 } else { 0 });
    }
}

#[test]
fn range_result_skips_arms_after_abrupt_scrutinee() {
    let source = "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer) -> Unit\n bind zero <- 0\n bind _ <- match R.checkInteger(minimum: 0, maximum: 10, value: 9223372036854775807 + 1) with\n case Result.Ok(c) -> x div zero\n case Result.Error(e) -> x div zero\n end match\nend function\n";
    inspect(source, |analysis| {
        assert_eq!(
            analysis
                .candidates
                .iter()
                .map(|c| c.preorder)
                .collect::<Vec<_>>(),
            [7]
        );
        assert!(analysis.independent.is_empty());
        assert!(!analysis.unsupported);
        assert!(!analysis.value.as_ref().unwrap().live);
    });
}

// 関門: Examples.RangeSurface/RangeC3の独立期待値を、型検査済み本体で照合する。
// 既存の腕の検査は成功値の記録を読む射影結果を観察せず、常にTopでも通る。
// 番号・候補・標準表は注入せず、同じ準備で精密化と忘却を対にする。
fn projection_source(setup: &str, tested: &str, body: &str) -> String {
    format!(
        "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer, flag: Boolean, other: R.CheckedInteger) -> Integer\n bind _ <- [block\n {setup}\n match {tested} with\n case Result.Ok(c) -> {body}\n case Result.Error(_) -> return -99\n end match\n end block]\n return 0\nend function\n"
    )
}

fn inspect_projection(
    source: &str,
    check: impl FnOnce(&flow::Approx, &[arithmetic::Candidate], bool),
) {
    inspect(source, |analysis| {
        assert!(analysis.candidates.is_empty());
        // list1の独立入力block2を観察する。Errorのreturnは正常区間に混ぜない。
        let projection = analysis
            .independent
            .iter()
            .find(|entry| entry.start == 2)
            .unwrap();
        check(
            projection.value.as_ref().unwrap(),
            &projection.candidates,
            projection.unsupported,
        );
    });
}

#[test]
fn range_projection_matches_lean_bounds_and_following_arithmetic() {
    for (lo, hi, n, expression, expected, warnings) in [
        ("0", "10", "0", "R.value(c)", Some((0, 10)), 0),
        ("0", "10", "10", "R.value(c)", Some((0, 10)), 0),
        ("7", "7", "7", "R.value(value: c)", Some((7, 7)), 0),
        (
            "-9223372036854775808",
            "9223372036854775807",
            "-9223372036854775808",
            "R.value(c)",
            Some((Interval::MIN, Interval::MAX)),
            0,
        ),
        (
            "-9223372036854775808",
            "9223372036854775807",
            "9223372036854775807",
            "R.value(c)",
            Some((Interval::MIN, Interval::MAX)),
            0,
        ),
        ("0", "9", "9", "R.value(c) + 1", Some((1, 10)), 0),
        (
            "9223372036854775807",
            "9223372036854775807",
            "x",
            "R.value(c) + 1",
            None,
            1,
        ),
        (
            "-9223372036854775808",
            "-9223372036854775808",
            "x",
            "R.value(c) - 1",
            None,
            1,
        ),
        // 表現可能な部分が残る場合は警告を作らず、正常区間だけを渡す。
        (
            "9223372036854775806",
            "9223372036854775807",
            "x",
            "R.value(c) + 1",
            Some((Interval::MAX, Interval::MAX)),
            0,
        ),
    ] {
        let call = format!("R.checkInteger(value: {n}, maximum: {hi}, minimum: {lo})");
        let source = projection_source("", &call, expression);
        inspect_projection(&source, |value, candidates, unsupported| {
            assert_eq!(value.normal.bounds(), expected, "{source}");
            assert!(value.may_fail);
            assert_eq!(candidates.len(), warnings, "{source}");
            assert!(
                candidates
                    .iter()
                    .all(|c| c.cause == arithmetic::Cause::Overflow)
            );
            assert!(!unsupported);
        });
    }
    // 親の本体でも同じ区間を得る。Errorのreturnの値を区間内に置き、合流で広げない。
    let source = "import Benitoite.Unofficial.Range as R\nfunction sample(x: Integer) -> Integer\n return match R.checkInteger(minimum: 0, maximum: 10, value: x) with\n case Result.Ok(c) -> R.value(c)\n case Result.Error(_) -> return 0\n end match\nend function\n";
    inspect(source, |analysis| {
        assert_eq!(
            analysis.value.as_ref().unwrap().returned.bounds(),
            Some((0, 10))
        );
        assert!(analysis.independent.is_empty());
        assert!(analysis.candidates.is_empty());
        assert!(!analysis.unsupported);
    });
}

#[test]
fn range_projection_preserves_original_binding_and_distinct_nested_origins() {
    let call = "R.checkInteger(minimum: 0, maximum: 10, value: x)";
    for (setup, tested, body, expected) in [
        (
            format!("bind saved <- {call}"),
            "saved",
            "R.value(c)",
            (0, 10),
        ),
        (String::new(), call, "bind alias <- c\n R.value(c)", (0, 10)),
        (
            String::new(),
            call,
            "bind before <- c\n shadow c <- other\n R.value(before)",
            (Interval::MIN, Interval::MAX),
        ),
        (
            String::new(),
            call,
            "bind before <- c\n shadow c <- other\n R.value(c)",
            (Interval::MIN, Interval::MAX),
        ),
        (
            String::new(),
            call,
            "bind unrelated <- other\n R.value(c)",
            (0, 10),
        ),
        (String::new(), call, "shadow x <- 99\n R.value(c)", (0, 10)),
        (
            String::new(),
            call,
            "bind _ <- if flag then 0 else 1 end if\n R.value(c)",
            (0, 10),
        ),
        (
            String::new(),
            call,
            "match R.checkInteger(minimum: 100, maximum: 110, value: 105) with\n case Result.Ok(inner) -> R.value(inner)\n case Result.Error(_) -> return -99\n end match",
            (100, 110),
        ),
        (
            String::new(),
            call,
            "match R.checkInteger(minimum: 100, maximum: 110, value: 105) with\n case Result.Ok(inner) -> R.value(c)\n case Result.Error(_) -> return -99\n end match",
            (0, 10),
        ),
    ] {
        let source = projection_source(&setup, tested, body);
        inspect_projection(&source, |value, candidates, unsupported| {
            assert_eq!(value.normal.bounds(), Some(expected), "{source}");
            assert!(candidates.is_empty());
            assert!(!unsupported);
        });
    }
}

#[test]
fn range_projection_forgets_aliases_boundaries_and_both_kinds_of_merge() {
    let call = "R.checkInteger(minimum: 0, maximum: 10, value: x)";
    for body in [
        "bind alias <- c\n R.value(alias)",
        "R.value(other)",
        "R.value((c))",
        "R.value(block c end block)",
        "bind getter <- R.value\n getter(c)",
        "bind getter <- R.value(_)\n getter(c)",
        "c |> R.value",
        "bind merged <- if flag then c else c end if\n R.value(merged)",
        "bind wrapped: Result[R.CheckedInteger, R.RangeError] <- Result.Ok(c)\n match wrapped with\n case Result.Ok(payload) -> R.value(payload)\n case Result.Error(_) -> return -99\n end match",
        // orの真・andの偽の入口は、条件の外のcの記録まで忘れる。
        "if x < 0 or x > 5 then R.value(c) else 1 end if",
        "if x >= 0 and x <= 5 then 1 else R.value(c) end if",
    ] {
        let source = projection_source("", call, body);
        inspect_projection(&source, |value, candidates, _unsupported| {
            assert_eq!(value.normal, Interval::top(), "{source}");
            assert!(candidates.is_empty(), "{source}");
        });
    }
    for (setup, tested) in [
        (
            String::new(),
            "R.checkInteger(minimum: x, maximum: 10, value: x)".to_owned(),
        ),
        (
            "bind lo <- 0".to_owned(),
            "R.checkInteger(minimum: lo, maximum: 10, value: x)".to_owned(),
        ),
        (
            format!("bind saved <- {call}\n bind alias <- saved"),
            "alias".to_owned(),
        ),
        (
            format!("bind saved <- if flag then {call} else {call} end if"),
            "saved".to_owned(),
        ),
    ] {
        let source = projection_source(&setup, &tested, "R.value(c)");
        inspect_projection(&source, |value, candidates, _unsupported| {
            assert_eq!(value.normal, Interval::top(), "{source}");
            assert!(candidates.is_empty());
        });
    }
}

#[test]
fn range_projection_independent_child_forgets_outer_success_but_restores_parent() {
    let source = projection_source(
        "",
        "R.checkInteger(minimum: 0, maximum: 10, value: x)",
        "bind discarded <- [R.value(c)]\n R.value(c)",
    );
    inspect(&source, |analysis| {
        assert!(analysis.candidates.is_empty());
        assert_eq!(analysis.independent.len(), 2);
        // 内側の射影が先、外側のblock2が後に保存される。
        assert_eq!(
            analysis.independent[0].value.as_ref().unwrap().normal,
            Interval::top()
        );
        assert_eq!(
            analysis.independent[1]
                .value
                .as_ref()
                .unwrap()
                .normal
                .bounds(),
            Some((0, 10))
        );
        assert_eq!(analysis.independent[1].start, 2);
        assert!(
            analysis
                .independent
                .iter()
                .all(|entry| entry.candidates.is_empty())
        );
    });
}

#[test]
fn range_projection_reaches_public_overflow_diagnostics_only_for_the_same_value() {
    // 公開の診断への接続と一次位置を守る。正常区間だけの検査では届かない境界である。
    for (setup, argument, count) in [
        ("", "c", 1),
        ("bind alias <- c", "alias", 0),
        ("", "other", 0),
    ] {
        let expression = format!("R.value({argument}) + 1");
        let source = projection_source(
            "",
            "R.checkInteger(minimum: 9223372036854775807, maximum: 9223372036854775807, value: x)",
            &format!("{setup}\n {expression}"),
        );
        let (_, _, _, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(
            !diagnostics.iter().any(Diagnostic::is_error),
            "{diagnostics:#?}"
        );
        let warnings: Vec<_> = diagnostics
            .iter()
            .filter(|d| d.code == Some(crate::diag::DiagCode::W0402))
            .collect();
        assert_eq!(warnings.len(), count, "{source}");
        for warning in warnings {
            assert_eq!(
                usize::try_from(warning.primary.as_ref().unwrap().span.start.0).unwrap(),
                source.find(&expression).unwrap()
            );
        }
    }
}

#[test]
fn range_projection_does_not_warn_on_error_reversed_or_out_of_range() {
    // l21/x03-range-casesの逆転二行と範囲外両側。実際のErrorの種類はX03bで比較する。
    for (lo, hi, n) in [(10, 0, 5), (10, 0, 15), (0, 10, -1), (0, 10, 11)] {
        let call = format!("R.checkInteger(minimum: {lo}, maximum: {hi}, value: {n})");
        let source = projection_source("", &call, "R.value(c)");
        inspect_projection(&source, |value, candidates, unsupported| {
            assert!(candidates.is_empty(), "{source}");
            assert!(!unsupported);
            let expected = if lo > hi {
                None
            } else {
                Some((i128::from(lo), i128::from(hi)))
            };
            assert_eq!(value.normal.bounds(), expected);
        });
    }
}
