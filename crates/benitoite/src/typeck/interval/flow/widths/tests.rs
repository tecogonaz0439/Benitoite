//! 型検査の出力で、幅ごとの正常値と境界での忘却を確かめる。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::Approx;
use super::*;
use crate::typeck::interval::Coverage;
use crate::typeck::interval::{IdentityStop, analyze_body, budget, identity};
use crate::typeck::test_support::check_files;
use std::collections::BTreeMap;

// 関門: 本物の型検査と入力収集を通し、六幅を Integer64 の区間に切り詰める退行、
// 別名の誤認定、負の葉・shadow・捕捉の型を落とす退行を検出する。
// 既存の Integer64 の表と固定表には六幅がない。期待値は言語の型域から固定し、
// テスト用の公開範囲・引数・本番状態は追加しない。
const KINDS: [(IntKind, &str, &str, i128, i128); 9] = [
    (IntKind::Integer8, "Integer8", "s8", -128, 127),
    (IntKind::Integer16, "Integer16", "s16", -32768, 32767),
    (
        IntKind::Integer32,
        "Integer32",
        "s32",
        -2147483648,
        2147483647,
    ),
    (
        IntKind::Integer64,
        "Integer",
        "",
        -9223372036854775808,
        9223372036854775807,
    ),
    (
        IntKind::Integer64,
        "Integer64",
        "",
        -9223372036854775808,
        9223372036854775807,
    ),
    (
        IntKind::UnsignedInteger16,
        "UnsignedInteger16",
        "u16",
        0,
        65535,
    ),
    (
        IntKind::UnsignedInteger32,
        "UnsignedInteger32",
        "u32",
        0,
        4294967295,
    ),
    (
        IntKind::UnsignedInteger64,
        "UnsignedInteger64",
        "u64",
        0,
        18446744073709551615,
    ),
    (
        IntKind::UnsignedInteger64,
        "UnsignedInteger",
        "u64",
        0,
        18446744073709551615,
    ),
];

fn returned(value: &Approx, kind: IntKind) -> Interval {
    if kind == IntKind::Integer64 {
        value.returned
    } else {
        value.returned_widths.range(kind)
    }
}

// 関門: 型検査が返す正常区間・候補・途中失敗を観察する。既存の算術表と
// 固定表は Integer64 だけなので、幅を取り違える退行を捕まえられない。
// 期待値は型域と数学上の端点から固定し、本番の差し込み口は増やさない。
// UnsignedInteger64 は最大値の二乗、部分的なあふれ、左右反転、途中失敗を
// 含め、i128 で積を丸める退行と、未対応の経路で事実を忘れる退行を検出する。
#[test]
fn arithmetic_keeps_each_width_and_intermediate_failure() {
    for (kind, ty, suffix, min, max) in KINDS {
        // Lean の local は型付き整数の読出しにも mayFail := true を残す。
        let mut cases = vec![
            (
                format!("return 1{suffix} + 2{suffix}"),
                Some((3, 3)),
                false,
                0,
            ),
            (
                format!("return 3{suffix} - 1{suffix}"),
                Some((2, 2)),
                false,
                0,
            ),
            (
                format!(
                    "bind n <- if flag then 1{suffix} else 3{suffix} end if\n return n + 2{suffix}"
                ),
                Some((3, 5)),
                true,
                0,
            ),
            (
                format!(
                    "bind n <- if flag then 1{suffix} else 3{suffix} end if\n return 2{suffix} + n"
                ),
                Some((3, 5)),
                true,
                0,
            ),
            (
                format!("bind n <- {max}{suffix}\n return n + 1{suffix}"),
                None,
                true,
                1,
            ),
            (
                format!("return x + 1{suffix}"),
                Some((min + 1, max)),
                true,
                0,
            ),
            (
                format!(
                    "bind n <- if flag then 1{suffix} else 3{suffix} end if\n return 5{suffix} - n"
                ),
                Some((2, 4)),
                true,
                0,
            ),
            (
                format!("bind n <- {min}{suffix}\n return n - 1{suffix}"),
                None,
                true,
                1,
            ),
            (
                format!("return x - 1{suffix}"),
                Some((min, max - 1)),
                true,
                0,
            ),
            ("return x - x".into(), Some((min, max)), true, 0),
            (
                format!("bind n <- 2{suffix}\n return x div n"),
                Some((min, max)),
                true,
                0,
            ),
            (
                format!("bind n <- 2{suffix}\n return x mod n"),
                Some((min, max)),
                true,
                0,
            ),
            (
                format!("bind n <- 0{suffix}\n return x div n"),
                Some((min, max)),
                true,
                1,
            ),
            (
                format!("bind n <- 0{suffix}\n return x mod n"),
                Some((min, max)),
                true,
                1,
            ),
            (
                format!("bind n <- if flag then 0{suffix} else 1{suffix} end if\n return x div n"),
                Some((min, max)),
                true,
                0,
            ),
            (
                format!("bind n <- {max}{suffix}\n return (n + 1{suffix}) - 1{suffix}"),
                None,
                true,
                1,
            ),
            (
                format!("bind n <- {max}{suffix}\n return 1{suffix} + (n + 1{suffix})"),
                None,
                true,
                1,
            ),
            (
                format!(
                    "bind n <- {max}{suffix}\n bind z <- 0{suffix}\n return (n + 1{suffix}) + (x div z)"
                ),
                None,
                true,
                1,
            ),
            (
                format!("return (if flag then return 7{suffix} else 3{suffix} end if) + 1{suffix}"),
                Some((4, 7)),
                true,
                0,
            ),
        ];
        cases.extend([
            (
                format!(
                    "bind n <- if flag then 1{suffix} else 3{suffix} end if\n return n * 2{suffix}"
                ),
                Some((2, 6)),
                true,
                0,
            ),
            (
                format!(
                    "bind n <- if flag then 1{suffix} else 3{suffix} end if\n return 2{suffix} * n"
                ),
                Some((2, 6)),
                true,
                0,
            ),
            (format!("return x * 0{suffix}"), Some((0, 0)), true, 0),
            (format!("return 0{suffix} * x"), Some((0, 0)), true, 0),
            (
                format!("bind n <- {max}{suffix}\n return n * 2{suffix}"),
                None,
                true,
                1,
            ),
            (
                format!("bind n <- {max}{suffix}\n return n * n"),
                None,
                true,
                1,
            ),
            (format!("return x * 2{suffix}"), Some((min, max)), true, 0),
            (
                format!("bind n <- if flag then 2{suffix} else 3{suffix} end if\n return n * n"),
                Some((min, max)),
                true,
                0,
            ),
            (
                format!("bind n <- {max}{suffix}\n return (n + 1{suffix}) * 0{suffix}"),
                None,
                true,
                1,
            ),
        ]);
        if kind == IntKind::UnsignedInteger64 {
            cases.extend([
                ("return 18446744073709551615u64 * 1u64".into(), Some((max, max)), false, 0),
                ("return 1u64 * 18446744073709551615u64".into(), Some((max, max)), false, 0),
                ("return 18446744073709551615u64 * 18446744073709551615u64".into(), None, true, 1),
                ("return x * 1u64".into(), Some((0, max)), true, 0),
                ("bind n <- if flag then 9223372036854775807u64 else 9223372036854775808u64 end if\n return n * 2u64".into(), Some((18446744073709551614, max)), true, 0),
                ("bind n <- if flag then 9223372036854775807u64 else 9223372036854775808u64 end if\n return 2u64 * n".into(), Some((18446744073709551614, max)), true, 0),
                ("bind n <- if flag then 9223372036854775808u64 else 18446744073709551615u64 end if\n return n * 2u64".into(), None, true, 1),
                ("bind n <- 18446744073709551615u64\n return 0u64 * (n + 1u64)".into(), None, true, 1),
                ("bind n <- 18446744073709551615u64\n bind z <- 0u64\n return (n * n) + (x div z)".into(), None, true, 1),
                ("bind n <- 18446744073709551615u64\n return 1u64 + (n * n)".into(), None, true, 1),
                ("return (if flag then return 7u64 else 3u64 end if) * 2u64".into(), Some((6, 7)), true, 0),
            ]);
        }
        if min < 0 {
            cases.extend([
                (format!("bind n <- if flag then -3{suffix} else 4{suffix} end if\n return -2{suffix} * n"), Some((-8, 6)), true, 0),
                (format!("bind n <- if flag then -3{suffix} else 4{suffix} end if\n return n * -2{suffix}"), Some((-8, 6)), true, 0),
                (format!("bind n <- {min}{suffix}\n return n * -1{suffix}"), None, true, 1),
                (format!("return x * -1{suffix}"), Some((-max, max)), true, 0),
                (format!("bind n <- if flag then -3{suffix} else 4{suffix} end if\n return -n"), Some((-4, 3)), true, 0),
                ("return -x".into(), Some((-max, max)), true, 0),
                (format!("bind n <- {min}{suffix}\n return -n"), None, true, 1),
                (format!("bind n <- {max}{suffix}\n return -(n + 1{suffix})"), None, true, 1),
                (format!("return -(if flag then return 7{suffix} else 3{suffix} end if)"), Some((-3, 7)), true, 0),
            ]);
        }
        let source: String = cases
            .iter()
            .enumerate()
            .map(|(i, (body, ..))| {
                format!("function case{i}(x: {ty}, flag: Boolean) -> {ty}\n {body}\nend function\n")
            })
            .collect();
        let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(
            !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
            "{ty}: {diagnostics:#?}"
        );
        for ((body, normal, may_fail, warnings), report) in
            cases.iter().zip(&output.interval.bodies)
        {
            assert_eq!(report.coverage, Coverage::Prepared, "{ty}: {body}");
            let flow = report.flow.as_ref().unwrap();
            let value = flow.value.as_ref().unwrap();
            assert_eq!(returned(value, kind).bounds(), *normal, "{ty}: {body}");
            assert_eq!(value.may_fail, *may_fail, "{ty}: {body}: {flow:#?}");
            assert_eq!(flow.candidates.len(), *warnings, "{ty}: {body}");
            assert!(
                flow.independent.is_empty() && !flow.unsupported,
                "{ty}: {body}"
            );
            assert_eq!(report.usage.temporary, 0, "{ty}: {body}");
        }
        assert_eq!(output.interval.bodies.len(), cases.len(), "{ty}");
    }
}

#[test]
fn typed_literals_bindings_and_joins_keep_each_integer_domain() {
    for (kind, ty, suffix, min, max) in KINDS {
        let mut source = format!("const maximum: {ty} = {max}{suffix}\n");
        let mut cases = vec![
            (format!("return {min}{suffix}"), (min, min)),
            (format!("return {max}{suffix}"), (max, max)),
            (format!("return 0{suffix}"), (0, 0)),
            ("return maximum".into(), (max, max)),
            ("bind copy <- x\n return copy".into(), (min, max)),
            (
                format!(
                    "bind n <- 7{suffix}\n bind copy <- n\n shadow n <- 9{suffix}\n return copy"
                ),
                (7, 7),
            ),
            (
                format!("bind n <- 7{suffix}\n shadow n <- 9{suffix}\n return n"),
                (9, 9),
            ),
            (
                format!(
                    "bind n <- if flag then {min}{suffix} else {max}{suffix} end if\n return n"
                ),
                (min, max),
            ),
            (
                format!(
                    "bind n <- 7{suffix}\n bind _ <- block shadow n <- 9{suffix}\n n end block\n return n"
                ),
                (7, 7),
            ),
            (
                format!(
                    "return if flag then block return {max}{suffix} end block else {min}{suffix} end if"
                ),
                (min, max),
            ),
        ];
        if min < 0 {
            cases.push((format!("return -0{suffix}"), (0, 0)));
        }
        for (index, (body, _)) in cases.iter().enumerate() {
            source.push_str(&format!(
                "function case{index}(x: {ty}, flag: Boolean) -> {ty}\n {body}\nend function\n"
            ));
        }
        let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(diagnostics.is_empty(), "{ty}: {diagnostics:#?}");
        for (index, (body, expected)) in cases.iter().enumerate() {
            let report = output
                .interval
                .bodies
                .iter()
                .find(|b| b.name == format!(".case{index}"))
                .unwrap();
            assert_eq!(report.coverage, Coverage::Prepared, "{ty}: {body}");
            let flow = report.flow.as_ref().unwrap();
            let value = flow.value.as_ref().unwrap();
            assert_eq!(
                returned(value, kind).bounds(),
                Some(*expected),
                "{ty}: {body}"
            );
            assert!(!value.live && !value.unsupported, "{ty}: {body}");
            assert!(flow.candidates.is_empty() && flow.independent.is_empty());
            assert_eq!(report.usage.temporary, 0);
        }
    }
}

#[test]
fn independent_inputs_and_separate_bodies_forget_integer_facts_but_keep_kind() {
    for (kind, ty, suffix, min, max) in KINDS {
        let source = format!(
            "function sample(x: {ty}, flag: Boolean) -> {ty}\n bind n <- 7{suffix}\n bind _ <- [n, block bind inner <- 3{suffix}\n inner end block]\n bind f <- lambda(p: {ty}) -> {ty}\n return if flag then n else p end if\n end lambda\n bind l <- lazy if flag then n else x end if end lazy\n return n\nend function\n"
        );
        let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(diagnostics.is_empty(), "{ty}: {diagnostics:#?}");
        assert_eq!(output.interval.bodies.len(), 3, "{ty}");
        let root = &output.interval.bodies[0];
        let flow = root.flow.as_ref().unwrap();
        assert_eq!(
            returned(flow.value.as_ref().unwrap(), kind).bounds(),
            Some((7, 7))
        );
        let independent: Vec<_> = flow
            .independent
            .iter()
            .map(|i| i.value.as_ref().unwrap().range_kind(kind).bounds())
            .collect();
        assert_eq!(independent, [Some((min, max)), Some((3, 3))], "{ty}");
        let lambda = output.interval.bodies[1]
            .flow
            .as_ref()
            .unwrap()
            .value
            .as_ref()
            .unwrap();
        assert_eq!(returned(lambda, kind).bounds(), Some((min, max)), "{ty}");
        let lazy = output.interval.bodies[2]
            .flow
            .as_ref()
            .unwrap()
            .value
            .as_ref()
            .unwrap();
        assert_eq!(lazy.range_kind(kind).bounds(), Some((min, max)), "{ty}");
        for body in &output.interval.bodies {
            assert_eq!(body.coverage, Coverage::Prepared, "{ty}");
            assert_eq!(body.usage.temporary, 0, "{ty}");
        }
    }
}

// 関門: 六幅の位置の hullSlot が左右を読む二操作を落とす退行と、忘却中の
// unidentified / exceeded の取り違えを検出する。固定表の整数比較の or と異なり、
// 外の整数位置を保つ Boolean 条件の合流と、list の独立入力の接続を確かめる。
// 期待値は現行 Lean の prepareRoot/analyzeBody の実行値から得る。
#[test]
fn typed_environment_costs_and_stops_match_lean() {
    use budget::{Cap, LimitFailure, Limits, Resource, Scope, StopReason};
    // cap、操作数、保存数、最大同時保持、次番号、停止（0=完走、1=超過、3=未同定）。
    let operations = [
        (0, 0, 0, 2, 0, 1),
        (20, 20, 4, 11, 2, 1),
        (50, 50, 12, 26, 9, 1),
        (1000, 81, 14, 30, 11, 0),
    ];
    let items = [
        (0, 0, 0, 0, 0, 1),
        (20, 31, 6, 20, 3, 3),
        (50, 81, 14, 30, 11, 0),
        (1000, 81, 14, 30, 11, 0),
    ];
    for (kind, ty, suffix, min, max) in KINDS {
        let source = format!(
            "function sample(a: Boolean, b: Boolean) -> {ty}\n bind n <- 7{suffix}\n bind _ <- [n]\n return if a or b then n else 9{suffix} end if\nend function\n"
        );
        identity::tests::fixture_owned(&source, |inputs, tables| {
            for whole in [false, true] {
                for memory in [false, true] {
                    for (cap, ops, saved, peak, next, stop) in
                        if memory { items } else { operations }
                    {
                        let mut budget = budget::Budget::default();
                        let limited = Cap {
                            operations: if memory { 1000 } else { cap },
                            items: if memory { cap } else { 1000 },
                        };
                        budget.limits = Limits {
                            body: if whole {
                                Cap {
                                    operations: 1000,
                                    items: 1000,
                                }
                            } else {
                                limited
                            },
                            whole: if whole {
                                limited
                            } else {
                                Cap {
                                    operations: 1000,
                                    items: 1000,
                                }
                            },
                        };
                        let analysis =
                            analyze_body(&inputs[0], tables, &BTreeMap::new(), &mut budget, 200);
                        let failure = LimitFailure {
                            scope: if whole { Scope::Whole } else { Scope::Body },
                            resource: if memory {
                                Resource::Items
                            } else {
                                Resource::Operations
                            },
                        };
                        let expected = match stop {
                            0 => Coverage::Prepared,
                            1 => Coverage::Stopped(IdentityStop::AnalysisBudget(
                                StopReason::Exceeded(failure),
                            )),
                            _ => Coverage::Stopped(IdentityStop::AnalysisBudget(
                                StopReason::Unidentified(failure),
                            )),
                        };
                        assert_eq!(
                            analysis.coverage, expected,
                            "{ty}: whole={whole}, memory={memory}, cap={cap}"
                        );
                        assert_eq!(
                            (
                                budget.body.operations,
                                budget.body.saved,
                                budget.body.peak,
                                analysis.identity.as_ref().map_or(0, |i| i.next)
                            ),
                            (ops, saved, peak, next),
                            "{ty}: whole={whole}, memory={memory}, cap={cap}"
                        );
                        assert_eq!(budget.body.temporary, 0);
                        if stop == 0 {
                            let flow = analysis.flow.unwrap();
                            assert_eq!(
                                returned(flow.value.as_ref().unwrap(), kind).bounds(),
                                Some((7, 9))
                            );
                            assert_eq!(flow.independent.len(), 1);
                            assert_eq!(flow.independent[0].start, 3);
                            assert_eq!(
                                flow.independent[0]
                                    .value
                                    .as_ref()
                                    .unwrap()
                                    .range_kind(kind)
                                    .bounds(),
                                Some((min, max))
                            );
                            assert!(flow.unsupported && flow.candidates.is_empty());
                        }
                    }
                }
            }
        });
    }
}

// 関門: 幅別の比較の真偽・短絡・腕入口から得る区間を、本物の型検査で観察する。
// 既存の算術表は Boolean の引数で分岐するだけなので、比較の未認定や
// 構造由来の未知を整数と認定する退行を捕まえない。費用は別の Lean 固定表で守る。
#[test]
fn comparisons_and_match_keep_each_width_and_unknown_scrutinees() {
    for (kind, ty, suffix, min, max) in KINDS {
        let mut cases = Vec::new();
        for (condition, expected) in [
            (format!("x = 2{suffix}"), Some((2, 2))),
            (format!("2{suffix} = x"), Some((2, 2))),
            (format!("x <> {min}{suffix}"), Some((min + 1, max))),
            (format!("x <> {max}{suffix}"), Some((min, max - 1))),
            (format!("x <> 2{suffix}"), Some((min, max))),
            (format!("x < 3{suffix}"), Some((min, 2))),
            (format!("3{suffix} > x"), Some((min, 2))),
            (format!("x <= 3{suffix}"), Some((min, 3))),
            (format!("x > 2{suffix}"), Some((3, max))),
            (format!("x >= 2{suffix}"), Some((2, max))),
            (format!("x > {max}{suffix}"), None),
            (format!("x < {min}{suffix}"), None),
            (format!("not (x <> 2{suffix})"), Some((2, 2))),
            (format!("x >= 2{suffix} and x <= 3{suffix}"), Some((2, 3))),
            (format!("x = 2{suffix} or x = 3{suffix}"), Some((2, 3))),
            (
                format!("not (x < 2{suffix} or x > 3{suffix})"),
                Some((2, 3)),
            ),
            (
                format!("not (x <> 2{suffix} and x <> 3{suffix})"),
                Some((2, 3)),
            ),
            ("x = (limit)".into(), Some((2, 2))),
            ("(limit) = x".into(), Some((2, 2))),
        ] {
            cases.push((
                format!("return if {condition} then x else {max}{suffix} + 1{suffix} end if"),
                expected,
                1,
                false,
            ));
        }
        cases.extend([
            (format!("return match x with case y if y = 0{suffix} -> 1{suffix} div y\n case _ -> 1{suffix} end match"), Some((min, max)), 1, false),
            (format!("return match (x) with case _ if x = 0{suffix} -> 1{suffix} div x\n case _ -> 1{suffix} end match"), Some((min, max)), 1, false),
            ("return match x with case y -> y end match".into(), Some((min, max)), 0, false),
            (format!("return match helper(x) with case y if y = 0{suffix} -> 1{suffix} div y\n case _ -> 1{suffix} end match"), Some((min, max)), 0, true),
            (format!("bind Box(value: y) <- Box(value: x)\n return match y with case z if z = 0{suffix} -> 1{suffix} div z\n case _ -> 1{suffix} end match"), Some((min, max)), 0, true),
        ]);
        let mut source = format!(
            "const limit: {ty} = 2{suffix}\nrecord Box\n value: {ty}\nend record\nfunction helper(x: {ty}) -> {ty} return x end function\n"
        );
        for (i, (body, ..)) in cases.iter().enumerate() {
            source.push_str(&format!(
                "function sample{i}(x: {ty}) -> {ty}\n {body}\nend function\n"
            ));
        }
        let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(
            !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
            "{ty}: {diagnostics:#?}"
        );
        let reports: Vec<_> = output
            .interval
            .bodies
            .iter()
            .filter(|r| r.name.starts_with(".sample"))
            .collect();
        assert_eq!(reports.len(), cases.len());
        for ((body, expected, warnings, unsupported), report) in cases.iter().zip(reports) {
            let flow = report.flow.as_ref().unwrap();
            let value = flow.value.as_ref().unwrap();
            assert_eq!(returned(value, kind).bounds(), *expected, "{ty}: {body}");
            assert_eq!(flow.candidates.len(), *warnings, "{ty}: {body}");
            assert_eq!(flow.unsupported, *unsupported, "{ty}: {body}");
            assert_eq!(report.usage.temporary, 0, "{ty}: {body}");
        }
    }
}
