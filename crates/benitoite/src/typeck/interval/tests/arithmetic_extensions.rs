//! 型検査の出力で Integer64 の減算・定数倍・負号を確かめる。
use super::*;

// 関門: 正常値の交差、全域外だけの候補、途中失敗と一般の積の Top を守る。
// 既存の算術表は加算・除数0だけであり、固定表は費用と候補位置を主に観察する。
// 本物の型検査と入力収集を通し、期待区間は数学上の端点から固定する。
#[test]
fn integer64_extensions_preserve_normal_ranges_and_failure_boundaries() {
    let cases = [
        (
            "difference",
            "bind n <- if flag then -3 else 4 end if\n return n - 2",
            Some((-5, 2)),
            0,
        ),
        (
            "reverseDifference",
            "bind n <- if flag then -3 else 4 end if\n return 2 - n",
            Some((-2, 5)),
            0,
        ),
        (
            "minimumDifference",
            "bind n <- -9223372036854775808\n return n - 1",
            None,
            1,
        ),
        (
            "maximumDifference",
            "bind n <- 9223372036854775807\n return n - -1",
            None,
            1,
        ),
        (
            "partialDifference",
            "return x - 1",
            Some((Interval::MIN, Interval::MAX - 1)),
            0,
        ),
        (
            "uncorrelated",
            "return x - x",
            Some((Interval::MIN, Interval::MAX)),
            0,
        ),
        (
            "positiveScale",
            "bind n <- if flag then -3 else 4 end if\n return n * 2",
            Some((-6, 8)),
            0,
        ),
        (
            "negativeScale",
            "bind n <- if flag then -3 else 4 end if\n return -2 * n",
            Some((-8, 6)),
            0,
        ),
        (
            "reverseScale",
            "bind n <- if flag then -3 else 4 end if\n return n * -2",
            Some((-8, 6)),
            0,
        ),
        ("zeroScale", "return x * 0", Some((0, 0)), 0),
        (
            "minimumScale",
            "bind n <- -9223372036854775808\n return n * -1",
            None,
            1,
        ),
        (
            "maximumScale",
            "bind n <- 9223372036854775807\n return n * 2",
            None,
            1,
        ),
        (
            "partialScale",
            "return x * -1",
            Some((-9223372036854775807, Interval::MAX)),
            0,
        ),
        (
            "generalScale",
            "bind n <- if flag then 2 else 3 end if\n return n * n",
            Some((Interval::MIN, Interval::MAX)),
            0,
        ),
        (
            "negation",
            "bind n <- if flag then -3 else 4 end if\n return -n",
            Some((-4, 3)),
            0,
        ),
        (
            "minimumNegation",
            "bind n <- -9223372036854775808\n return -n",
            None,
            1,
        ),
        (
            "partialNegation",
            "return -x",
            Some((-9223372036854775807, Interval::MAX)),
            0,
        ),
        (
            "intermediate",
            "bind n <- -9223372036854775808\n return (n - 1) + 1",
            None,
            1,
        ),
        (
            "skipRight",
            "bind n <- 9223372036854775807\n return (n * 2) - (1 div 0)",
            None,
            1,
        ),
        (
            "emptyNegation",
            "bind n <- 9223372036854775807\n return -(n + 1)",
            None,
            1,
        ),
        (
            "returnInNegation",
            "return -(if flag then return 7 else 3 end if)",
            Some((-3, 7)),
            0,
        ),
    ];
    let source: String = cases
        .iter()
        .map(|(name, body, ..)| {
            format!(
                "function {name}(x: Integer, flag: Boolean) -> Integer\n {body}\nend function\n"
            )
        })
        .collect();
    let (_, _, output, diagnostics) = check_files(&[("main.bnt", &source)], false);
    assert!(
        !diagnostics.iter().any(Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    for ((name, _, expected, warnings), report) in cases.iter().zip(&output.interval.bodies) {
        assert_eq!(report.name, format!(".{name}"));
        assert_eq!(report.coverage, Coverage::Prepared, "{name}");
        let flow = report.flow.as_ref().unwrap();
        let value = flow.value.as_ref().unwrap();
        assert_eq!(value.returned.bounds(), *expected, "{name}");
        assert_eq!(flow.candidates.len(), *warnings, "{name}");
        assert!(flow.independent.is_empty(), "{name}");
        assert!(!flow.unsupported, "{name}");
        assert_eq!(report.usage.temporary, 0, "{name}");
    }
}
