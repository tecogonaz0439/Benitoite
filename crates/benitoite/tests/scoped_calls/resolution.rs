//! 標準認定を解決済みの束縛に限り、六宣言の同綴りと別名を通す。
use benitoite::diag::DiagCode;
use benitoite::pipeline::{self, CheckOptions};

const OPTIONS: CheckOptions = CheckOptions {
    require_main: false,
    deny_warnings: false,
};

const MOCK_SCOPE: &str = r#"public function checkPathIn(pattern: String, path: String) -> String
 return path
end function
public function pathInValue(path: String) -> String
 return path
end function
public function widenPathIn(path: String) -> String
 return path
end function
"#;

const MOCK_HTTP: &str = r#"public function checkRequestIn(hostPattern: String, minimumPort: Integer, maximumPort: Integer, request: String) -> String
 return request
end function
public function requestInValue(request: String) -> String
 return request
end function
public function widenRequestIn(request: String) -> String
 return request
end function
"#;

// 関門: 所有元の異なる同綴りの関数を、六宣言の必須判定へ入れる退行を捕まえる。
// 既存の単体例は checkPathIn 一つだけで、モジュールを読む通常入口を通さない。
// 公開 check_files と、通常の型・脱糖の入口だけを使い、注入の入口は増やさない。
#[test]
fn user_spellings_and_standard_like_import_aliases_are_ordinary_functions() {
    let calls = [
        (
            "Scope",
            "checkPathIn(pattern: \"/bad//path\", path: \"value\")",
        ),
        ("Scope", "pathInValue(path: \"value\")"),
        ("Scope", "widenPathIn(path: \"value\")"),
        (
            "Http",
            "checkRequestIn(request: \"value\", maximumPort: 0, hostPattern: \"*\", minimumPort: 1)",
        ),
        ("Http", "requestInValue(request: \"value\")"),
        ("Http", "widenRequestIn(request: \"value\")"),
    ];
    for (module, call) in calls {
        for qualified in [false, true] {
            let main = if qualified {
                format!(
                    "import MockScope as Scope\nimport MockHttp as Http\nfunction sample() -> String\n return {module}.{call}\nend function\n"
                )
            } else {
                format!(
                    "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Network.Http\n{MOCK_SCOPE}{MOCK_HTTP}function sample() -> String\n return {call}\nend function\n"
                )
            };
            let result = pipeline::check_files(
                &[
                    ("main.bnt", main.as_bytes()),
                    ("MockScope.bnt", MOCK_SCOPE.as_bytes()),
                    ("MockHttp.bnt", MOCK_HTTP.as_bytes()),
                ],
                OPTIONS,
            );
            assert!(result.program.is_some(), "{main}\n{:?}", result.diagnostics);
            let program = result.program.unwrap();
            let input = program
                .types
                .scope_inputs
                .bodies
                .iter()
                .find(|body| body.body_key.definition.ends_with(".sample"))
                .unwrap();
            assert!(!input.contains_rules(), "{main}");
            let core = pipeline::desugar_checked(&program).unwrap();
            assert!(benitoite::ir::check::check_program(&core).is_empty());
        }
    }
}

// 関門: 狭い戻り契約と異なるパターンを与え、綴りだけでの標準認定を判別する。
// 上の String の利用者関数の表は、型クラス・効果操作・標準との同時 import を通さない。
// 同じ公開 check_files で三つの所有元と標準の拒否を比べ、差し込み口は増やさない。
#[test]
fn trait_methods_user_operations_and_module_names_do_not_gain_standard_rules() {
    const TRAIT: &str = r#"trait Scope[T]
 function checkPathIn(pattern: String, path: T) -> Result[S.PathIn["/data/a"], S.ScopeError]
end trait
implement Scope[String]
 function checkPathIn(pattern: String, path: String) -> Result[S.PathIn["/data/a"], S.ScopeError]
  return S.checkPathIn(pattern: "/data/a", path: path)
 end function
end implement
"#;
    const MODULE: &str = r#"import Benitoite.Unofficial.Scope as S
public function checkPathIn(pattern: String, path: String) -> Result[S.PathIn["/data/a"], S.ScopeError]
 return S.checkPathIn(pattern: "/data/a", path: path)
end function
"#;
    const OPERATION: &str = r#"import Benitoite.Unofficial.Scope as S
public effect Ops
 function checkPathIn(pattern: String, path: String) -> Result[S.PathIn["/data/a"], S.ScopeError]
end effect
"#;
    for (declarations, module, body, rejected) in [
        (
            TRAIT,
            "",
            "Scope.checkPathIn(pattern: \"/x/**\", path: p)",
            false,
        ),
        (
            "import Lib.Scope\n",
            MODULE,
            "Scope.checkPathIn(pattern: \"/x/**\", path: p)",
            false,
        ),
        (
            "import Lib.Scope\n",
            OPERATION,
            r#"handle
  Scope.checkPathIn(pattern: "/x/**", path: p)
 with
 case Scope.checkPathIn(pattern, path) -> resume(S.checkPathIn(pattern: "/data/a", path: path))
 end handle"#,
            false,
        ),
        ("", "", "S.checkPathIn(pattern: \"/x/**\", path: p)", true),
    ] {
        let main = format!(
            "import Benitoite.Unofficial.Scope as S\n{declarations}function sample(p: String) -> Result[S.PathIn[\"/data/a\"], S.ScopeError]\n return {body}\nend function\n"
        );
        let result = pipeline::check_files(
            &[
                ("main.bnt", main.as_bytes()),
                ("Lib/Scope.bnt", module.as_bytes()),
            ],
            OPTIONS,
        );
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), usize::from(rejected), "{main}\n{errors:?}");
        if rejected {
            assert_eq!(errors[0].code, Some(DiagCode::E0519));
            assert!(errors[0].message.contains("notCovered"), "{errors:?}");
        } else {
            let program = result.program.unwrap();
            let ranges: Vec<_> = program
                .types
                .call_ranges
                .iter()
                .filter(|(_, r)| !r.is_empty())
                .map(|(_, r)| r.iter().map(|r| r.suffix()).collect::<Vec<_>>())
                .collect();
            assert_eq!(ranges, [vec!["[\"/data/a\"]".to_string()]], "{main}");
            let core = pipeline::desugar_checked(&program).unwrap();
            assert!(benitoite::ir::check::check_program(&core).is_empty());
        }
    }
}

// 関門: 関数値にした六宣言は全 Top であり、別名によって所属を取り戻さない。
// 既存の間接呼び出しの表は checkPathIn だけを扱う。
#[test]
fn indirect_six_declarations_keep_top_instead_of_recovering_a_direct_rule() {
    for (function, parameter, returned, call, narrow_return) in [
        (
            "Scope.checkPathIn",
            "value: String",
            "Result[Scope.PathIn, Scope.ScopeError]",
            "indirect(pattern: \"/data/**\", path: value)",
            "Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]",
        ),
        (
            "Scope.pathInValue",
            "value: Scope.PathIn",
            "String",
            "indirect(path: value)",
            "String",
        ),
        (
            "Scope.widenPathIn",
            "value: Scope.PathIn",
            "Scope.PathIn",
            "indirect(path: value)",
            "Scope.PathIn[\"/**\"]",
        ),
        (
            "Http.checkRequestIn",
            "value: Http.ClientRequest",
            "Result[Http.RequestIn, Http.RequestCheckError]",
            "indirect(request: value, maximumPort: 443, hostPattern: \"api.example.com\", minimumPort: 443)",
            "Result[Http.RequestIn[\"api.example.com\", 443], Http.RequestCheckError]",
        ),
        (
            "Http.requestInValue",
            "value: Http.RequestIn",
            "Http.ClientRequest",
            "indirect(request: value)",
            "Http.ClientRequest",
        ),
        (
            "Http.widenRequestIn",
            "value: Http.RequestIn",
            "Http.RequestIn",
            "indirect(request: value)",
            "Http.RequestIn[\"api.example.com\", 443]",
        ),
    ] {
        for narrow in [false, true] {
            let parameter = if narrow && function == "Scope.pathInValue" {
                "value: Scope.PathIn[\"/data/**\"]"
            } else if narrow && function == "Http.requestInValue" {
                "value: Http.RequestIn[\"api.example.com\", 443]"
            } else {
                parameter
            };
            let returned = if narrow { narrow_return } else { returned };
            let source = format!(
                "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Network.Http\nfunction sample({parameter}) -> {returned}\n bind indirect <- {function}\n return {call}\nend function\n"
            );
            let result = super::check(&source);
            let errors: Vec<_> = result
                .diagnostics
                .iter()
                .filter(|diagnostic| diagnostic.is_error())
                .filter_map(|diagnostic| diagnostic.code)
                .collect();
            assert_eq!(
                errors,
                if narrow {
                    vec![DiagCode::E0401]
                } else {
                    vec![]
                },
                "{source}\n{:?}",
                result.diagnostics
            );
            assert_eq!(result.program.is_some(), !narrow, "{source}");
            if let Some(program) = result.program {
                let core = pipeline::desugar_checked(&program).unwrap();
                assert!(benitoite::ir::check::check_program(&core).is_empty());
            }
        }
    }
}

// 関門: 許される Scope の別名は標準の束縛を保ち、Http の別名は既存の禁止を保つ。
#[test]
fn permitted_alias_keeps_scope_rules_and_effect_module_alias_is_rejected() {
    let source = r#"import Benitoite.Unofficial.Scope as S
function sample(path: String) -> String
 bind checked <- S.checkPathIn(path: path, pattern: "/data/a")
 return match checked with
 case Result.Ok(value) ->
  bind wide: S.PathIn["/data/**"] <- S.widenPathIn(path: value)
  bind _ <- wide
  S.pathInValue(path: value)
 case Result.Error(_) -> "error"
 end match
end function
"#;
    let result = super::check(source);
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
    let program = result.program.unwrap();
    let ranges: Vec<_> = program
        .types
        .call_ranges
        .iter()
        .filter(|(_, ranges)| !ranges.is_empty())
        .map(|(_, ranges)| {
            ranges
                .iter()
                .map(|range| range.suffix())
                .collect::<Vec<_>>()
        })
        .collect();
    assert_eq!(ranges.len(), 3, "{ranges:?}");
    assert!(
        ranges
            .iter()
            .all(|ranges| ranges.iter().all(|range| !range.is_empty()))
    );
    let core = pipeline::desugar_checked(&program).unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());

    for call in [
        "H.checkRequestIn(hostPattern: \"api.example.com\", minimumPort: 443, maximumPort: 443, request: request)",
        "H.requestInValue(request: checked)",
        "H.widenRequestIn(request: checked)",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Network.Http as H\nfunction sample(request: H.ClientRequest, checked: H.RequestIn) -> Unit\n bind _ <- {call}\n ()\nend function\n"
        );
        let result = super::check(&source);
        let errors: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect();
        assert_eq!(
            errors,
            [DiagCode::E0339],
            "{source}\n{:?}",
            result.diagnostics
        );
    }
}

#[test]
fn standard_import_names_cannot_be_redeclared() {
    for (import, name) in [
        ("Benitoite.Unofficial.Scope", "Scope"),
        ("Benitoite.Unofficial.Network.Http", "Http"),
    ] {
        let source = format!("import {import}\nrecord {name}\n value: String\nend record\n");
        let result = super::check(&source);
        let errors: Vec<_> = result
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .filter_map(|d| d.code)
            .collect();
        assert_eq!(
            errors,
            [DiagCode::E0305],
            "{source}\n{:?}",
            result.diagnostics
        );
    }
}
