//! 七種の整数の診断と受理を、公開の検査入口で確かめる。
//! （設計書 02-05「警告」、02-10「警告の扱い」）。
// 数学上の端点と元位置の期待値を組み立てる（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::arithmetic_side_effects)]

use super::{CheckOptions, pipeline};
use benitoite::diag::{Diagnostic, Severity};

const LOCAL_ANALYSIS: &str = "this local analysis applies only if execution reaches this operation and all operands are evaluated successfully";

fn check(source: &str, deny_warnings: bool) -> pipeline::CheckResult {
    pipeline::check_text(
        "width-intervals.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings,
        },
    )
}

// strict で変わる重大度・注記以外は、元位置・順序・重複を含めて保つ。
fn assert_denied(source: &str, ordinary: &[Diagnostic]) {
    let denied = check(source, true);
    assert_eq!(denied.program.is_some(), ordinary.is_empty(), "{source}");
    let mut expected = ordinary.to_vec();
    for diagnostic in &mut expected {
        assert!(diagnostic.is_warning(), "{source}: {diagnostic:?}");
        diagnostic.severity = Severity::Error;
        diagnostic
            .notes
            .push("treated as an error because of `--deny-warnings`".into());
    }
    assert_eq!(denied.diagnostics, expected, "{source}");
}

const KINDS: [(&str, &str, i128, i128); 9] = [
    ("Integer8", "s8", -128, 127),
    ("Integer16", "s16", -32768, 32767),
    ("Integer32", "s32", -2147483648, 2147483647),
    ("Integer", "", -9223372036854775808, 9223372036854775807),
    ("Integer64", "", -9223372036854775808, 9223372036854775807),
    ("UnsignedInteger16", "u16", 0, 65535),
    ("UnsignedInteger32", "u32", 0, 4294967295),
    ("UnsignedInteger64", "u64", 0, 18446744073709551615),
    ("UnsignedInteger", "u64", 0, 18446744073709551615),
];

// 関門: 候補数だけでは、幅付きの警告を Integer の型域や別の span で出す退行を
// 検出できない。旧定数警告に隠れない局所束縛を使い、型検査の診断を観察する。
#[test]
fn arithmetic_warnings_keep_the_integer_kind_range_and_primary() {
    use benitoite::diag::DiagCode::{W0401, W0402};

    for (ty, suffix, min, max) in KINDS {
        let display = match ty {
            "Integer64" => "Integer",
            "UnsignedInteger" => "UnsignedInteger64",
            _ => ty,
        };
        let mut cases = vec![
            (
                format!("bind n <- {max}{suffix}\n return n + 1{suffix}"),
                format!("n + 1{suffix}"),
                W0402,
                format!("[{},{}]", max + 1, max + 1),
            ),
            (
                format!("bind n <- {min}{suffix}\n return n - 1{suffix}"),
                format!("n - 1{suffix}"),
                W0402,
                format!("[{},{}]", min - 1, min - 1),
            ),
            (
                format!("bind n <- 0{suffix}\n return x div n"),
                "n".into(),
                W0401,
                "[0,0]".into(),
            ),
            (
                format!("bind n <- 0{suffix}\n return x mod n"),
                "n".into(),
                W0401,
                "[0,0]".into(),
            ),
        ];
        cases.push((
            format!("bind n <- {max}{suffix}\n return n * 2{suffix}"),
            format!("n * 2{suffix}"),
            W0402,
            format!("[{},{}]", max * 2, max * 2),
        ));
        if ty == "UnsignedInteger64" || ty == "UnsignedInteger" {
            cases.push((
                "bind n <- 18446744073709551615u64\n return n * n".into(),
                "n * n".into(),
                W0402,
                "[340282366920938463426481119284349108225,340282366920938463426481119284349108225]"
                    .into(),
            ));
            cases.push((
                "bind n <- if flag then 9223372036854775808u64 else 18446744073709551615u64 end if\n return 2u64 * n".into(),
                "2u64 * n".into(),
                W0402,
                "[18446744073709551616,36893488147419103230]".into(),
            ));
        }
        if min < 0 {
            cases.push((
                format!("bind n <- {max}{suffix}\n return n - -1{suffix}"),
                format!("n - -1{suffix}"),
                W0402,
                format!("[{},{}]", max + 1, max + 1),
            ));
            cases.push((
                format!("bind n <- {min}{suffix}\n return -n"),
                "-n".into(),
                W0402,
                format!("[{},{}]", -min, -min),
            ));
        }
        for (body, primary, code, result) in cases {
            let source =
                format!("function sample(x: {ty}, flag: Boolean) -> {ty}\n {body}\nend function\n");
            let checked = check(&source, false);
            assert!(
                checked.program.is_some(),
                "{source}: {:?}",
                checked.diagnostics
            );
            let diagnostics = checked.diagnostics;
            assert_eq!(diagnostics.len(), 1, "{source}: {diagnostics:#?}");
            let diagnostic = &diagnostics[0];
            assert_eq!(diagnostic.code, Some(code), "{source}");
            let span = diagnostic.primary.as_ref().unwrap().span;
            assert_eq!(
                &source
                    [usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()],
                primary
            );
            assert!(
                diagnostic.notes.iter().any(|note| note.contains(&result)),
                "{diagnostic:#?}"
            );
            if code == W0402 {
                assert!(diagnostic.message.contains(display), "{diagnostic:#?}");
                let allowed = format!("[{min},{max}]");
                assert!(
                    diagnostic.notes.iter().any(|note| note.contains(&allowed)),
                    "{diagnostic:#?}"
                );
            }
            assert!(!diagnostic.secondary.is_empty(), "{diagnostic:#?}");
            assert!(diagnostic.helps.is_empty());
            assert!(diagnostic.notes.iter().any(|n| n == LOCAL_ANALYSIS));
            let binding = diagnostic.secondary[0].span;
            assert!(
                source[usize::try_from(binding.start.0).unwrap()
                    ..usize::try_from(binding.end.0).unwrap()]
                    .starts_with("bind n <-")
            );
            assert_denied(&source, &diagnostics);
        }
    }
}

// 関門: 内部の正常区間の表では確かめない、公開診断の有無と通常の受理を守る。
// 比較・短絡・guard・途中失敗を幅ごとに通し、未到達の警告や Rust だけの
// 商・剰余の精密化を検出する。テスト用の本番の公開範囲は増やさない。
#[test]
fn width_boundaries_warn_only_at_reached_operations() {
    use benitoite::diag::DiagCode::{W0401, W0402};
    for (ty, suffix, min, max) in KINDS {
        let cases = [
            (format!("return x + 1{suffix}"), None),
            (format!("return x - 1{suffix}"), None),
            ("return x - x".into(), None),
            (
                format!("bind n <- if flag then 2{suffix} else 3{suffix} end if\n return n * n"),
                None,
            ),
            (
                format!("bind q <- 0{suffix} div 1{suffix}\n return 1{suffix} div q"),
                None,
            ),
            (
                format!("bind r <- 0{suffix} mod 1{suffix}\n return 1{suffix} div r"),
                None,
            ),
            (
                format!(
                    "bind z <- 0{suffix}\n return if false then 1{suffix} div z else 1{suffix} end if"
                ),
                None,
            ),
            (
                format!(
                    "bind z <- 0{suffix}\n if true then return 1{suffix} end if\n return 1{suffix} div z"
                ),
                None,
            ),
            (
                format!(
                    "bind z <- 0{suffix}\n bind _ <- false and (1{suffix} div z = 0{suffix})\n return 1{suffix}"
                ),
                None,
            ),
            (
                format!(
                    "bind z <- 0{suffix}\n bind _ <- true or (1{suffix} div z = 0{suffix})\n return 1{suffix}"
                ),
                None,
            ),
            (
                format!(
                    "return if x = 0{suffix} then if x <> 0{suffix} then 1{suffix} div x else 1{suffix} end if else 1{suffix} end if"
                ),
                None,
            ),
            (
                format!("return if x = 0{suffix} then 1{suffix} div x else 1{suffix} end if"),
                Some((W0401, "x".into())),
            ),
            (
                format!("return if {max}{suffix} <= x then x + 1{suffix} else 1{suffix} end if"),
                Some((W0402, format!("x + 1{suffix}"))),
            ),
            (
                format!("return if x <= {min}{suffix} then x - 1{suffix} else 1{suffix} end if"),
                Some((W0402, format!("x - 1{suffix}"))),
            ),
            (
                format!(
                    "return match x with\n case v if v = 0{suffix} -> 1{suffix} div v\n case _ -> 1{suffix}\n end match"
                ),
                Some((W0401, "v".into())),
            ),
            (
                format!(
                    "return match x with\n case _ if x = 0{suffix} -> 1{suffix} mod x\n case _ -> 1{suffix}\n end match"
                ),
                Some((W0401, "x".into())),
            ),
            (
                format!(
                    "bind n <- {max}{suffix}\n bind z <- 0{suffix}\n return (n + 1{suffix}) + (1{suffix} div z)"
                ),
                Some((W0402, format!("n + 1{suffix}"))),
            ),
        ];
        for (index, (body, expected)) in cases.into_iter().enumerate() {
            let source =
                format!("function sample(x: {ty}, flag: Boolean) -> {ty}\n {body}\nend function\n");
            let checked = check(&source, false);
            assert!(
                checked.program.is_some(),
                "{ty}/{index}: {:?}",
                checked.diagnostics
            );
            let expected_codes: Vec<_> = expected
                .as_ref()
                .map(|(code, _)| *code)
                .into_iter()
                .collect();
            assert_eq!(
                checked
                    .diagnostics
                    .iter()
                    .filter_map(|d| d.code)
                    .collect::<Vec<_>>(),
                expected_codes,
                "{source}"
            );
            if let Some((_, primary)) = expected {
                let span = checked.diagnostics[0].primary.as_ref().unwrap().span;
                assert_eq!(
                    &source[usize::try_from(span.start.0).unwrap()
                        ..usize::try_from(span.end.0).unwrap()],
                    primary,
                    "{source}"
                );
                assert!(
                    checked.diagnostics[0]
                        .notes
                        .iter()
                        .any(|n| n == LOCAL_ANALYSIS)
                );
            }
            assert_denied(&source, &checked.diagnostics);
        }
    }
}

// 関門: 宣言・別名・複数参照の新候補を元位置で一件にまとめ、旧定数警告を
// 優先する契約は、局所変数だけの算術表では守れない。同じ公開入口で観察する。
#[test]
fn width_constants_merge_expansions_and_prefer_existing_warnings() {
    use benitoite::diag::DiagCode::{W0401, W0402};
    for (ty, suffix, _, max) in KINDS {
        let source = format!(
            "const c: Boolean = 0{suffix} div 1{suffix} <> 0{suffix} and (1{suffix} div 0{suffix} = 1{suffix})\nconst alias: Boolean = c\nfunction sample() -> Boolean\n bind a <- c\n bind b <- alias\n return c or alias\nend function\n"
        );
        let checked = check(&source, false);
        assert!(checked.program.is_some(), "{ty}: {:?}", checked.diagnostics);
        assert_eq!(
            checked.diagnostics.len(),
            1,
            "{source}: {:?}",
            checked.diagnostics
        );
        let diagnostic = &checked.diagnostics[0];
        assert_eq!(diagnostic.code, Some(W0401));
        let span = diagnostic.primary.as_ref().unwrap().span;
        let start = source.find(&format!("1{suffix} div 0{suffix}")).unwrap()
            + format!("1{suffix} div ").len();
        assert_eq!(usize::try_from(span.start.0).unwrap(), start);
        assert_eq!(
            &source[start..usize::try_from(span.end.0).unwrap()],
            format!("0{suffix}")
        );
        assert!(diagnostic.secondary.is_empty());
        assert!(diagnostic.notes.iter().any(|n| n == LOCAL_ANALYSIS));
        assert_denied(&source, &checked.diagnostics);

        for (expression, primary, code) in [
            (
                format!("1{suffix} div 0{suffix}"),
                format!("0{suffix}"),
                W0401,
            ),
            (
                format!("{max}{suffix} + 1{suffix}"),
                format!("{max}{suffix} + 1{suffix}"),
                W0402,
            ),
        ] {
            let source = format!("function sample() -> {ty}\n return {expression}\nend function\n");
            let checked = check(&source, false);
            assert!(
                checked.program.is_some(),
                "{source}: {:?}",
                checked.diagnostics
            );
            assert_eq!(
                checked.diagnostics.len(),
                1,
                "{source}: {:?}",
                checked.diagnostics
            );
            let diagnostic = &checked.diagnostics[0];
            assert_eq!(diagnostic.code, Some(code));
            let span = diagnostic.primary.as_ref().unwrap().span;
            assert_eq!(
                &source
                    [usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()],
                primary
            );
            assert!(diagnostic.notes.is_empty(), "{diagnostic:?}");
            assert!(diagnostic.secondary.is_empty());
            assert_denied(&source, &checked.diagnostics);
        }
    }
}

// 関門: 局所解析の拡張後も、Decimal と標準関数の旧警告（定数引数・名前付き
// 引数・import の別名）を残す。旧警告に局所解析の注記を混ぜる退行も検出する。
#[test]
fn standard_arithmetic_warnings_keep_constant_evaluation_contract() {
    use benitoite::diag::DiagCode::{W0401, W0402};
    for (ty, suffix, min, _) in KINDS {
        let module = match ty {
            "Integer64" => "Integer",
            "UnsignedInteger" => "UnsignedInteger64",
            _ => ty,
        };
        let mut cases = vec![
            (
                format!("Num.floorDivide(b: 0{suffix}, a: 1{suffix})"),
                format!("0{suffix}"),
                Some(W0401),
            ),
            (
                format!("Num.floorModulo(a: 1{suffix}, b: 0{suffix})"),
                format!("0{suffix}"),
                Some(W0401),
            ),
            (format!("Num.absolute(1{suffix})"), String::new(), None),
        ];
        if min < 0 {
            for expression in [
                format!("Num.absolute({min}{suffix})"),
                format!("Num.floorDivide(a: {min}{suffix}, b: -1{suffix})"),
            ] {
                cases.push((expression.clone(), expression, Some(W0402)));
            }
            cases.push((
                format!("Num.floorModulo(a: {min}{suffix}, b: -1{suffix})"),
                String::new(),
                None,
            ));
        }
        for (expression, primary, code) in cases {
            let source = format!(
                "import Benitoite.{module} as Num\nfunction sample() -> {ty}\n return {expression}\nend function\n"
            );
            assert_constant_warning(&source, &primary, code);
        }
    }
    for (expression, primary, code) in [
        ("1m / 0m", "0m", Some(W0401)),
        (
            "79228162514264337593543950335m + 1m",
            "79228162514264337593543950335m + 1m",
            Some(W0402),
        ),
        ("Decimal.absolute(-1m)", "", None),
    ] {
        let source = format!(
            "import Benitoite.Decimal\nfunction sample() -> Decimal\n return {expression}\nend function\n"
        );
        assert_constant_warning(&source, primary, code);
    }
}

fn assert_constant_warning(source: &str, primary: &str, code: Option<benitoite::diag::DiagCode>) {
    let checked = check(source, false);
    assert!(
        checked.program.is_some(),
        "{source}: {:?}",
        checked.diagnostics
    );
    assert_eq!(
        checked
            .diagnostics
            .iter()
            .filter_map(|d| d.code)
            .collect::<Vec<_>>(),
        code.into_iter().collect::<Vec<_>>(),
        "{source}"
    );
    if code.is_some() {
        let diagnostic = &checked.diagnostics[0];
        let span = diagnostic.primary.as_ref().unwrap().span;
        assert_eq!(
            &source[usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()],
            primary,
            "{source}"
        );
        assert!(diagnostic.notes.is_empty(), "{diagnostic:?}");
        assert!(diagnostic.secondary.is_empty());
    }
    assert_denied(source, &checked.diagnostics);
}
