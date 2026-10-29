//! 定数引数の追加拒否と通常のCall/Resultの境界（設計書 02-05「本体の後の検査」）。
// テストの失敗はpanicで表す（AGENTS.md「実装の規約」）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]
use benitoite::diag::DiagCode as C;
use benitoite::pipeline::{self, CheckOptions};

fn check(source: &str) -> pipeline::CheckResult {
    pipeline::check_text(
        "checked-args.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    )
}

// 関門: 標準の検査済み整数にもopaqueの境界を適用する。Scopeの例だけでは
// Rangeの属性や登録の漏れを検出できない。公開のcheck入口を使い、差し込み口は不要。
#[test]
fn range_checked_integer_hides_all_representation_operations() {
    for expression in [
        "Range.CheckedInteger(minimum: 0, maximum: 10, value: 11)",
        "Range.CheckedInteger(..checked, value: 11)",
        "match checked with case Range.CheckedInteger(minimum: _, maximum: _, value: _) -> () end match",
        "Range.CheckedInteger.minimum(checked)",
        "Range.CheckedInteger.maximum(checked)",
        "Range.CheckedInteger.value(checked)",
        "Range.CheckedInteger",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Range\nfunction sample(checked: Range.CheckedInteger) -> Unit\n bind _ <- {expression}\nend function\n"
        );
        let result = check(&source);
        let codes: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect();
        assert_eq!(codes, [C::E0340], "{expression}: {:?}", result.diagnostics);
        assert!(result.program.is_none());
    }
}

// 関門: 実際の解決済み標準束縛とCallPlanを経由する拒否を守る。既存の定数・Regex単体
// テストでは、別名・間接・パイプと型エラー抑制の接続漏れを検出できない。差し込み口は不要。
#[test]
fn regex_constants_reject_only_known_direct_standard_calls() {
    for (setup, expression, expected) in [
        ("", "Regex.compile(\"[\")", vec![C::E0457]),
        ("", "Regex.compile(source: r\"(a)\\1\")", vec![C::E0457]),
        ("", "Regex.compile(r\"\\w{1000}\")", vec![C::E0458]),
        ("", "Regex.compile(\"a\" + \"+\")", vec![]),
        ("", "Regex.compile(\"[\" + \"\")", vec![C::E0457]),
        ("", "Regex.compile(\"${\"[\"}\")", vec![C::E0457]),
        ("", "Regex.compile(dynamic)", vec![]),
        (" bind source <- \"[\"\n", "Regex.compile(source)", vec![]),
        (" bind compile <- Regex.compile\n", "compile(\"[\")", vec![]),
        (
            " bind compile <- Regex.compile(_)\n",
            "compile(\"[\")",
            vec![],
        ),
        ("", "\"[\" |> Regex.compile", vec![]),
        ("", "\"[\" |> Regex.compile(_)", vec![]),
        ("", "Regex.compile(unknown: \"[\")", vec![C::E0451]),
        ("", "Regex.compile(1)", vec![C::E0401]),
        ("", "Regex.compile(\"[\" + 1)", vec![C::E0401]),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Regex\nfunction sample(dynamic: String) -> Result[Regex.Pattern, String]\n{setup} return {expression}\nend function\n"
        );
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected,
            "{expression}: {errors:?}"
        );
        assert_eq!(result.program.is_some(), expected.is_empty());
        if expected == [C::E0457] || expected == [C::E0458] {
            let span = errors[0].primary.as_ref().unwrap().span;
            let input = &source[span.start.0 as usize..span.end.0 as usize];
            assert!(expression.contains(input), "{input}");
            assert!(!input.starts_with("Regex.compile"));
        }
    }
    let cases: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/checked-regex.json")).unwrap();
    for case in cases.as_array().unwrap() {
        let source = case["source"].as_str().unwrap();
        let source = format!(
            "import Benitoite.Unofficial.Regex\nfunction sample() -> Result[Regex.Pattern, String]\n return Regex.compile(r\"{source}\")\nend function\n"
        );
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), 1, "{errors:?}");
        assert_eq!(
            format!("{:?}", errors[0].code.unwrap()),
            case["code"].as_str().unwrap()
        );
    }
    let user = check(
        "function compile(source: String) -> Unit\n ()\nend function\nfunction sample() -> Unit\n compile(\"[\")\nend function\n",
    );
    assert!(user.program.is_some(), "{:?}", user.diagnostics);
    let alias = check(
        "import Benitoite.Unofficial.Regex as R\nfunction sample() -> Unit\n bind _ <- R.compile(\"[\")\nend function\n",
    );
    assert_eq!(
        alias
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect::<Vec<_>>(),
        [C::E0457]
    );
    let constant = check(
        "import Benitoite.Unofficial.Regex\nconst p: Result[Regex.Pattern, String] = Regex.compile(\"[\")\n",
    );
    assert_eq!(
        constant
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect::<Vec<_>>(),
        [C::E0433]
    );
}

#[test]
fn constant_origins_follow_cached_transitive_values() {
    let source = "import Benitoite.Unofficial.Regex\nconst first: String = \"[\"\nconst second: String = first\nfunction sample() -> Unit\n bind _ <- Regex.compile(second)\n bind _ <- Regex.compile(second)\nend function\n";
    let result = check(source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 2);
    for (error, offset) in errors.iter().zip(
        source
            .match_indices("Regex.compile(second)")
            .map(|(i, _)| i.saturating_add("Regex.compile(".len())),
    ) {
        assert_eq!(error.code, Some(C::E0457));
        assert_eq!(
            error.primary.as_ref().unwrap().span.start.0 as usize,
            offset
        );
        let mut spans: Vec<_> = error
            .secondary
            .iter()
            .map(|label| label.span.start.0 as usize)
            .collect();
        spans.sort_unstable();
        assert_eq!(
            spans,
            [
                source.find("first:").unwrap(),
                source.find("second:").unwrap()
            ]
        );
    }
}

// 関門: 取得とRegex組み立ての二つの予算を区別し、全本体で共有する。小さい例では
// 予算のリセットや、上限をE0458へ誤分類する退行を捕まえられない。
#[test]
fn additional_budgets_fall_back_to_runtime_and_do_not_reset_per_body() {
    let large = format!("{}[", "x".repeat(1024 * 1024));
    let source = format!(
        "import Benitoite.Unofficial.Regex\nfunction sample() -> Unit\n bind _ <- Regex.compile(\"{large}\")\nend function\n"
    );
    let result = check(&source);
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
    let boundary = &large[1..];
    let source = format!(
        "import Benitoite.Unofficial.Regex\nfunction sample() -> Unit\n bind _ <- Regex.compile(\"{boundary}\")\nend function\n"
    );
    let result = check(&source);
    assert_eq!(
        result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect::<Vec<_>>(),
        [C::E0457]
    );
    let fragment = format!("{}[", "x".repeat(900_000));
    let mut source =
        format!("import Benitoite.Unofficial.Regex\nconst source: String = \"{fragment}\"\n");
    for i in 0..90 {
        source.push_str(&format!(
            "function f{i}() -> Unit\n bind _ <- Regex.compile(source)\nend function\n"
        ));
    }
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert!(errors.len() > 60 && errors.len() < 90, "{}", errors.len());
    assert!(
        errors.iter().all(|d| d.code == Some(C::E0457)),
        "{errors:?}"
    );
    let mut source = format!(
        "import Benitoite.Unofficial.Regex\nconst fragment: String = \"{fragment}\"\nfunction sample() -> Unit\n"
    );
    for i in 0..10 {
        source.push_str(&format!(" bind _ <- Regex.compile(fragment + \"{i}\")\n"));
    }
    source.push_str(" bind _ <- Regex.compile(fragment + \"0\")\nend function\n");
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 10, "{errors:?}");
    assert!(errors.iter().all(|d| d.code == Some(C::E0457)));
    let last = source.rfind("fragment + \"0\"").unwrap();
    assert_eq!(
        errors
            .last()
            .unwrap()
            .primary
            .as_ref()
            .unwrap()
            .span
            .start
            .0 as usize,
        last
    );
}

#[path = "fixtures/scope.rs"]
mod scope_cases;

// 四問: 公開の検査入口で形式/所属の追加拒否と部分既知の健全性を守る。
// Regexの既存表はScopeの登録・整数・失敗順・条件の位置を通らない。
// JSONは独立した期待値であり、共通判定部から期待を生成せず、差し込み口も加えない。
#[test]
fn scope_constants_follow_shared_runtime_contract_and_positions() {
    for case in scope_cases::cases() {
        let expression = format!(
            "Scope.check{}({})",
            scope_cases::operation(&case),
            scope_cases::arguments(&case)
        );
        let source = format!(
            "import Benitoite.Unofficial.Scope\nfunction sample() -> Unit\n bind _ <- {expression}\nend function\n"
        );
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        let expected: Vec<_> = case["code"].as_str().into_iter().collect();
        assert_eq!(
            errors
                .iter()
                .map(|d| format!("{:?}", d.code.unwrap()))
                .collect::<Vec<_>>(),
            expected,
            "{case}: {errors:?}"
        );
        assert_eq!(result.program.is_some(), expected.is_empty(), "{case}");
    }
    for (expression, code, primary, related) in [
        (
            "Scope.checkEndpoint(hostPattern: dynamic, host: dynamic, minimumPort: 443, maximumPort: 0, port: p)",
            C::E0461,
            "0",
            vec!["443"],
        ),
        (
            "Scope.checkEndpoint(port: -1, maximumPort: 0, minimumPort: 443, host: dynamic, hostPattern: dynamic)",
            C::E0461,
            "0",
            vec!["443"],
        ),
        (
            "Scope.checkEndpoint(hostPattern: dynamic, host: dynamic, minimumPort: p, maximumPort: -1, port: 65536)",
            C::E0461,
            "-1",
            vec![],
        ),
        (
            "Scope.checkEndpoint(hostPattern: dynamic, host: dynamic, minimumPort: -1, maximumPort: p, port: 0)",
            C::E0461,
            "-1",
            vec![],
        ),
        (
            "Scope.checkEndpoint(hostPattern: dynamic, host: dynamic, minimumPort: 0, maximumPort: 65535, port: 65536)",
            C::E0461,
            "65536",
            vec![],
        ),
        (
            "Scope.checkEndpoint(hostPattern: \"*.example.com\", host: \"a.b.example.com\", minimumPort: p, maximumPort: p, port: p)",
            C::E0462,
            "\"a.b.example.com\"",
            vec!["\"*.example.com\""],
        ),
        (
            "Scope.checkEndpoint(hostPattern: dynamic, host: dynamic, minimumPort: 443, maximumPort: 443, port: 444)",
            C::E0462,
            "444",
            vec!["443", "443"],
        ),
        (
            "Scope.checkHost(pattern: dynamic, host: \"bad.\")",
            C::E0460,
            "\"bad.\"",
            vec![],
        ),
        (
            "Scope.checkHost(pattern: dynamic, host: \"::ffff:127.0.0.1\")",
            C::E0460,
            "\"::ffff:127.0.0.1\"",
            vec![],
        ),
        (
            "Scope.checkPath(pattern: \"/a/*\", path: dynamic)",
            C::E0459,
            "\"/a/*\"",
            vec![],
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nfunction sample(dynamic: String, p: Integer) -> Unit\n bind _ <- {expression}\nend function\n"
        );
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), 1, "{expression}: {errors:?}");
        assert_eq!(errors[0].code, Some(code), "{expression}");
        let span = errors[0].primary.as_ref().unwrap().span;
        assert_eq!(
            &source[span.start.0 as usize..span.end.0 as usize],
            primary,
            "{expression}"
        );
        let actual: Vec<_> = errors[0]
            .secondary
            .iter()
            .map(|label| {
                let span = label.span;
                &source[span.start.0 as usize..span.end.0 as usize]
            })
            .collect();
        assert_eq!(actual, related, "{expression}");
    }
}

// 関門: 新しい検査入口も旧入口と同じ既知の不良を報告し、引数名の並べ替えと
// 部分既知の条件でも位置を保つ。既存表は新入口の登録・異なるポート位置を通らない。
// 期待は通常の公開checkで観察し、共通判定やテスト用の差し込み口から作らない。
#[test]
fn scoped_value_checks_report_known_bad_arguments_after_body_checking() {
    // 新しい入口の既知の不良の代表的な入力と、旧入口の拒否を通常ソースで検査する。
    for (source, expected) in [
        (
            r#"import Benitoite.Unofficial.Scope as S
import Benitoite.Unofficial.Network.Http
function main() -> Unit
 ()
end function
function f(p: String) -> Result[S.PathIn, S.ScopeError]
 return S.checkPathIn(pattern: "relative/**", path: p)
end function
"#,
            C::E0459,
        ),
        (
            r#"import Benitoite.Unofficial.Scope as S
import Benitoite.Unofficial.Network.Http
function main() -> Unit
 ()
end function
function f(r: Http.ClientRequest) -> Result[Http.RequestIn, Http.RequestCheckError]
 return Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 443, maximumPort: 80, request: r)
end function
"#,
            C::E0461,
        ),
        (
            r#"import Benitoite.Unofficial.Scope as S
import Benitoite.Unofficial.Network.Http
function main() -> Unit
 ()
end function
function f(r: Http.ClientRequest) -> Result[Http.RequestIn, Http.RequestCheckError]
 return Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 70000, maximumPort: 80000, request: r)
end function
"#,
            C::E0461,
        ),
        (
            r#"import Benitoite.Unofficial.Scope as S
import Benitoite.Unofficial.Network.Http
function main() -> Unit
 ()
end function
function f(p: String) -> Result[S.CheckedPath, S.ScopeError]
 return S.checkPath(pattern: "relative/**", path: p)
end function
"#,
            C::E0459,
        ),
        (
            r#"import Benitoite.Unofficial.Scope as S
import Benitoite.Unofficial.Network.Http
function main() -> Unit
 ()
end function
function f(p: String) -> Result[S.PathIn, S.ScopeError]
 return S.checkPathIn(pattern: "/data/**", path: "relative")
end function
"#,
            C::E0460,
        ),
    ] {
        let result = check(source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            [expected],
            "{source}: {errors:?}"
        );
        assert!(result.program.is_none());
    }
    for (setup, expression, expected, primary, related) in [
        (
            "",
            "S.checkPathIn(pattern: \"/data/*\", path: dynamic)",
            Some(C::E0459),
            "\"/data/*\"",
            vec![],
        ),
        (
            "",
            "S.checkPathIn(path: \"relative\", pattern: dynamic)",
            Some(C::E0460),
            "\"relative\"",
            vec![],
        ),
        (
            "",
            "S.checkPathIn(pattern: \"/data/**\", path: \"/other/file\")",
            Some(C::E0462),
            "\"/other/file\"",
            vec!["\"/data/**\""],
        ),
        (
            "",
            "Http.checkRequestIn(request: request, maximumPort: 80, hostPattern: dynamic, minimumPort: 443)",
            Some(C::E0461),
            "80",
            vec!["443"],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: dynamic, minimumPort: p, maximumPort: -1, request: request)",
            Some(C::E0461),
            "-1",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: dynamic, minimumPort: 65536, maximumPort: p, request: request)",
            Some(C::E0461),
            "65536",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"*\", minimumPort: p, maximumPort: p, request: request)",
            Some(C::E0459),
            "\"*\"",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"192.0.2.1/24\", minimumPort: p, maximumPort: p, request: request)",
            Some(C::E0459),
            "\"192.0.2.1/24\"",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"::ffff:127.0.0.1\", minimumPort: 0, maximumPort: 65535, request: request)",
            None,
            "",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"::ffff:0.0.0.0/96\", minimumPort: 0, maximumPort: 65535, request: request)",
            None,
            "",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"::ffff:127.0.0.0/104\", minimumPort: 0, maximumPort: 65535, request: request)",
            None,
            "",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"::/0\", minimumPort: 0, maximumPort: 65535, request: request)",
            None,
            "",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: \"192.0.2.0/24\", minimumPort: 0, maximumPort: 65535, request: request)",
            None,
            "",
            vec![],
        ),
        (
            "",
            "S.checkPathIn(pattern: dynamic, path: dynamic)",
            None,
            "",
            vec![],
        ),
        (
            "",
            "Http.checkRequestIn(hostPattern: dynamic, minimumPort: p, maximumPort: p, request: request)",
            None,
            "",
            vec![],
        ),
        (
            " bind f <- S.checkPathIn\n",
            "f(pattern: \"relative/**\", path: dynamic)",
            None,
            "",
            vec![],
        ),
        (
            " bind f <- Http.checkRequestIn\n",
            "f(hostPattern: \"*\", minimumPort: 443, maximumPort: 80, request: request)",
            None,
            "",
            vec![],
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope as S\nimport Benitoite.Unofficial.Network.Http\nfunction sample(dynamic: String, p: Integer, request: Http.ClientRequest) -> Unit\n{setup} bind _ <- {expression}\nend function\n"
        );
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(
            errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            expected.into_iter().collect::<Vec<_>>(),
            "{expression}: {errors:?}"
        );
        assert_eq!(result.program.is_some(), expected.is_none(), "{expression}");
        if let Some(error) = errors.first() {
            let span = error.primary.as_ref().unwrap().span;
            assert_eq!(
                &source[span.start.0 as usize..span.end.0 as usize],
                primary,
                "{expression}"
            );
            assert_eq!(
                error
                    .secondary
                    .iter()
                    .map(|label| &source[label.span.start.0 as usize..label.span.end.0 as usize])
                    .collect::<Vec<_>>(),
                related,
                "{expression}"
            );
        }
    }
    let source = "import Benitoite.Unofficial.Scope as S\nimport Benitoite.Unofficial.Network.Http\nconst first: String = \"relative/**\"\nconst pattern: String = first\nconst minimum: Integer = 443\nconst maximum: Integer = 80\nfunction sample(path: String, request: Http.ClientRequest) -> Unit\n bind _ <- S.checkPathIn(pattern: pattern, path: path)\n bind _ <- Http.checkRequestIn(hostPattern: \"api.example.com\", minimumPort: minimum, maximumPort: maximum, request: request)\nend function\n";
    let result = check(source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(
        errors.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
        [C::E0459, C::E0461],
        "{errors:?}"
    );
    for (error, names) in errors
        .iter()
        .zip([vec!["first:", "pattern:"], vec!["minimum:", "maximum:"]])
    {
        let positions: Vec<_> = names
            .into_iter()
            .map(|name| source.find(name).unwrap())
            .collect();
        for position in positions {
            assert!(
                error
                    .secondary
                    .iter()
                    .any(|label| label.span.start.0 as usize == position),
                "{error:?}"
            );
        }
    }
}

#[test]
fn scope_direct_binding_boundary_origins_and_opaque_representation() {
    for (setup, expression, expected) in [
        (
            "",
            "Scope.checkHost(pattern: dynamic, host: dynamic)",
            vec![],
        ),
        (
            "",
            "Scope.checkEndpoint(hostPattern: \"*.example.com\", host: dynamic, minimumPort: p, maximumPort: p, port: p)",
            vec![],
        ),
        (
            " bind pattern <- \"*\"\n",
            "Scope.checkHost(pattern: pattern, host: \"x\")",
            vec![],
        ),
        (
            " bind f <- Scope.checkHost\n",
            "f(pattern: \"*\", host: \"x\")",
            vec![],
        ),
        (
            "",
            "\"*\" |> Scope.checkHost(pattern: _, host: \"x\")",
            vec![],
        ),
        (
            " bind f <- Scope.checkHost(pattern: _, host: \"x\")\n",
            "f(\"*\")",
            vec![],
        ),
        (
            "",
            "Scope.checkHost(pattern: 1, host: \"bad.\")",
            vec![C::E0401],
        ),
        (
            "",
            "Scope.checkHost(unknown: \"*\", host: \"bad.\")",
            vec![C::E0451],
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nfunction sample(dynamic: String, p: Integer) -> Unit\n{setup} bind _ <- {expression}\nend function\n"
        );
        let result = check(&source);
        let codes: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect();
        assert_eq!(codes, expected, "{expression}: {:?}", result.diagnostics);
    }
    let source = "import Benitoite.Unofficial.Scope as S\nconst first: String = \"*\"\nconst second: String = first\nfunction sample() -> Unit\n bind _ <- S.checkHost(pattern: second, host: \"x\")\nend function\n";
    let result = check(source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{:?}", result.diagnostics);
    assert_eq!(errors[0].code, Some(C::E0459));
    let mut spans: Vec<_> = errors[0]
        .secondary
        .iter()
        .map(|label| label.span.start.0 as usize)
        .collect();
    spans.sort_unstable();
    assert_eq!(
        spans,
        [
            source.find("first:").unwrap(),
            source.find("second:").unwrap()
        ]
    );
    for expression in [
        "Scope.CheckedHost(pattern: \"*\", host: \"x\")",
        "Scope.CheckedHost(..h, host: \"x\")",
        "Scope.CheckedHost.host(h)",
        "Scope.CheckedHost",
        "Scope.CheckedPath(pattern: \"/**\", path: \"/x\")",
        "Scope.CheckedEndpoint(hostPattern: \"x\", host: \"x\", minimumPort: 0, maximumPort: 1, port: 2)",
        "match h with case Scope.CheckedHost(pattern: _, host: _) -> () end match",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nfunction sample(h: Scope.CheckedHost) -> Unit\n bind _ <- {expression}\nend function\n"
        );
        let result = check(&source);
        let codes: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect();
        assert_eq!(codes, [C::E0340], "{expression}: {:?}", result.diagnostics);
    }
    let user = check(
        "function checkHost(pattern: String, host: String) -> Unit\n ()\nend function\nfunction sample() -> Unit\n checkHost(pattern: \"*\", host: \"bad.\")\nend function\n",
    );
    assert!(user.program.is_some(), "{:?}", user.diagnostics);
}

// 関門: 診断の由来を有限個に抑え、連鎖の起点と直接参照を残す。
// 二段の既存例では位置の膨張と省略数の誤りを検出できない。公開checkを使う。
#[test]
fn constant_origin_labels_are_bounded_and_keep_chain_endpoints() {
    let mut source = String::from("import Benitoite.Unofficial.Regex\nconst c0: String = \"[\"\n");
    for i in 1..16 {
        source.push_str(&format!("const c{i}: String = c{}\n", i - 1));
    }
    source.push_str("function sample() -> Unit\n bind _ <- Regex.compile(c15)\nend function\n");
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{:?}", result.diagnostics);
    assert_eq!(errors[0].code, Some(C::E0457));
    let spans: Vec<_> = errors[0]
        .secondary
        .iter()
        .map(|s| s.span.start.0 as usize)
        .collect();
    assert_eq!(
        spans,
        [source.find("c0:").unwrap(), source.find("c15:").unwrap()]
    );
    assert_eq!(errors[0].notes, ["14 other constant declarations omitted"]);

    let mut source = String::from("import Benitoite.Unofficial.Scope\n");
    for i in 0..12 {
        source.push_str(&format!("const c{i}: String = \"[\"\n"));
    }
    let expression = (0..12)
        .map(|i| format!("c{i}"))
        .collect::<Vec<_>>()
        .join(" + ");
    source.push_str(&format!("const merged: String = {expression}\nfunction sample() -> Unit\n bind _ <- Scope.checkHost(pattern: merged, host: \"localhost\")\nend function\n"));
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{:?}", result.diagnostics);
    assert_eq!(errors[0].code, Some(C::E0459));
    assert_eq!(errors[0].secondary.len(), 8);
    assert!(
        errors[0]
            .secondary
            .iter()
            .any(|s| s.span.start.0 as usize == source.find("merged:").unwrap())
    );
    assert_eq!(errors[0].notes, ["5 other constant declarations omitted"]);
}

// 関門: ソースの短い異なるパターンも一検査の件数上限を共有する。
// バイト予算の既存例では無制限の組み立てと本体ごとのリセットを捕まえられない。
#[test]
fn regex_pattern_count_is_shared_and_cached_failures_survive_exhaustion() {
    let mut source = String::from("import Benitoite.Unofficial.Regex\n");
    for i in 0..258 {
        source.push_str(&format!(
            "function f{i}() -> Unit\n bind _ <- Regex.compile(\"[{i}\")\nend function\n"
        ));
    }
    source.push_str("function cached() -> Unit\n bind _ <- Regex.compile(\"[0\")\nend function\n");
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 257, "{:?}", result.diagnostics);
    assert!(errors.iter().all(|d| d.code == Some(C::E0457)));
    assert_eq!(
        errors
            .last()
            .unwrap()
            .primary
            .as_ref()
            .unwrap()
            .span
            .start
            .0 as usize,
        source.rfind("\"[0\"").unwrap()
    );
    // 成功した組み立ても件数に含め、超過後の不良入力は実行時へ残す。
    let mut source = String::from("import Benitoite.Unofficial.Regex\nfunction sample() -> Unit\n");
    for i in 0..256 {
        source.push_str(&format!(" bind _ <- Regex.compile(\"{i}\")\n"));
    }
    source.push_str(" bind _ <- Regex.compile(\"[\")\nend function\n");
    let result = check(&source);
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
}

// 関門: here の特別扱いは解決済みの標準束縛と直接呼び出しに限る。
// 値化・パイプの誤受理と、普通の引数診断を隠す退行を公開checkで捉える。
#[test]
fn source_location_requires_the_standard_direct_zero_argument_call() {
    for (expression, expected) in [
        ("SourceLocation.here()", vec![]),
        ("SourceLocation.here", vec![C::E0467]),
        ("(SourceLocation.here)", vec![C::E0467]),
        ("(SourceLocation.here)()", vec![C::E0467]),
        ("() |> SourceLocation.here", vec![C::E0467]),
        ("() |> SourceLocation.here()", vec![C::E0467]),
        ("() |> (SourceLocation.here())", vec![C::E0467]),
        ("SourceLocation.here(1)", vec![C::E0402]),
        ("SourceLocation.here(extra: 1)", vec![C::E0451]),
        ("SourceLocation.here(_)", vec![C::E0402]),
        ("SourceLocation.here(extra: _)", vec![C::E0451]),
    ] {
        let result = check(&format!(
            "function sample() -> Unit\n bind _ <- {expression}\nend function\n"
        ));
        let codes = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect::<Vec<_>>();
        assert_eq!(codes, expected, "{expression}: {:?}", result.diagnostics);
        assert_eq!(result.program.is_some(), expected.is_empty());
    }
    let alias = check(
        "import Benitoite.Unofficial.SourceLocation as SL\nconst place: SL.Location = SL.here()\nfunction sample() -> SL.Location\n return SL.here()\nend function\n",
    );
    assert!(alias.program.is_some(), "{:?}", alias.diagnostics);
    let user = pipeline::check_files(&[
        ("main.bnt", b"import Places as SourceLocation\nfunction sample() -> Integer\n bind f <- SourceLocation.here\n return () |> f\nend function\n"),
        ("Places.bnt", b"public function here(x: Unit) -> Integer\n return 7\nend function\n"),
    ], CheckOptions { require_main: false, deny_warnings: false });
    assert!(user.program.is_some(), "{:?}", user.diagnostics);
}

// 関門: Logの公開パラメータ名recordを通常の型・束縛・参照でも保ち、改行を失わない。
#[test]
fn log_record_parameter_is_an_ordinary_contextual_name() {
    let result = check(
        "function identity(record: Integer) -> Integer\n return record\nend function\nfunction caller(callback: function(record: Integer) -> Integer) -> Integer\n bind record <- callback(record: 3)\n return identity(record)\nend function\n",
    );
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
}
