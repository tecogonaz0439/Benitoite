//! 必須判定から型・脱糖・実行へ渡す契約（設計書 01-06、02-05、02-06）。
//! 関門: 注釈だけの所属獲得、暗黙の拡大、予算後の呼び出しの見落としを捕まえる。
//! 局所解析の既存検査では、本番の受理入口と型制約の接続を検査しない。
#![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]

use benitoite::pipeline::{self, CheckOptions};

#[path = "scoped_calls/closure.rs"]
mod closure;
#[path = "scoped_calls/file_io.rs"]
mod file_io;
#[path = "scoped_calls/handler_selection.rs"]
mod handler_selection;
#[path = "scoped_calls/http_io.rs"]
mod http_io;
#[path = "scoped_calls/resolution.rs"]
mod resolution;

fn check(source: &str) -> pipeline::CheckResult {
    pipeline::check_text(
        "scope-call.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    )
}

fn path_source(body: &str) -> String {
    format!("import Benitoite.Unofficial.Scope\n{body}")
}

#[test]
fn accepted_calls_keep_non_top_ranges_and_widen_uses_the_return_annotation() {
    for body in [
        r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 return Scope.checkPathIn(pattern: "/data/**", path: path)
end function"#,
        r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 bind result <- Scope.checkPathIn(pattern: "/data/a", path: path)
 return match result with
 case Result.Ok(value) ->
  bind wide: Scope.PathIn["/data/**"] <- Scope.widenPathIn(path: value)
  Result.Ok(wide)
 case Result.Error(error) -> Result.Error(error)
 end match
end function"#,
        r#"function sample(path: String) -> String
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: path)
 return match result with
 case Result.Ok(value) ->
  bind text <- Scope.pathInValue(path: value)
  text
 case Result.Error(_) -> "error"
 end match
end function"#,
    ] {
        let source = path_source(body);
        let result = check(&source);
        assert!(
            !result.diagnostics.iter().any(|d| d.is_error()),
            "{source}\n{:?}",
            result.diagnostics
        );
        let program = result.program.unwrap();
        assert!(program.types.call_ranges.iter().any(|(_, ranges)| {
            ranges
                .iter()
                .any(|range| range.suffix() == "[\"/data/**\"]")
        }));
        let core = pipeline::desugar_checked(&program).unwrap();
        assert!(benitoite::ir::check::check_program(&core).is_empty());
    }
}

#[test]
fn unannotated_checks_use_top_when_projection_or_join_requires_it() {
    // 通常の入口で、由来の忘却と型変数の共有による既定値の衝突を検査する。
    // 既存の拒否表と組にし、注釈のない利用を狭い既定値で拒否する退行を捕まえる。
    for (name, body) in [
        (
            "alias",
            r#"bind alias <- value
  Scope.pathInValue(path: alias)"#,
        ),
        (
            "rewrap",
            r#"bind wrapped <- Result.Ok(value)
  match wrapped with
  case Result.Ok(unwrapped) -> Scope.pathInValue(path: unwrapped)
  case Result.Error(_) -> "error"
  end match"#,
        ),
        (
            "capture",
            r#"bind project <- lambda() -> String
   return Scope.pathInValue(path: value)
  end lambda
  project()"#,
        ),
        ("pipe", "value |> Scope.pathInValue()"),
    ] {
        let source = path_source(&format!(
            r#"function sample(path: String) -> String
 bind checked <- Scope.checkPathIn(pattern: "/data/**", path: path)
 return match checked with
 case Result.Ok(value) ->
  {body}
 case Result.Error(_) -> "error"
 end match
end function"#
        ));
        assert_top_calls(name, &source);
    }
    let source = path_source(
        r#"function sample(flag: Boolean, path: String) -> Unit
 bind checked <- if flag then
  Scope.checkPathIn(pattern: "/data/a", path: path)
 else
  Scope.checkPathIn(pattern: "/data/b", path: path)
 end if
 bind _ <- checked
 ()
end function"#,
    );
    assert_top_calls("join", &source);
}

fn assert_top_calls(name: &str, source: &str) {
    let result = check(source);
    assert!(
        !result.diagnostics.iter().any(|d| d.is_error()),
        "{name}: {source}\n{:?}",
        result.diagnostics
    );
    let program = result.program.unwrap();
    let scoped: Vec<_> = program
        .types
        .call_ranges
        .iter()
        .filter(|(_, ranges)| !ranges.is_empty())
        .collect();
    assert_eq!(scoped.len(), 2, "{name}: {scoped:?}");
    assert!(
        scoped.iter().all(|(_, ranges)| ranges
            .iter()
            .all(|range| *range == benitoite::types::scope::Range::Top)),
        "{name}: {scoped:?}"
    );
    let core = pipeline::desugar_checked(&program).unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());
}

#[test]
fn scope_acceptance_rejects_unknown_uncovered_pipe_and_implicit_widening() {
    for (body, reason) in [
        (
            r#"function sample(top: Scope.PathIn) -> Unit
 bind w: Scope.PathIn["/data/**"] <- Scope.widenPathIn(path: top)
 ()
end function"#,
            "unknownSource",
        ),
        (
            r#"function sample(path: String) -> Unit
 bind first <- Scope.checkPathIn(pattern: "/data/**", path: path)
 match first with
 case Result.Ok(p) ->
  bind q <- p
  bind w: Scope.PathIn["/**"] <- Scope.widenPathIn(path: q)
  ()
 case Result.Error(_) -> ()
 end match
end function"#,
            "unknownSource",
        ),
        (
            r#"function sample(pattern: String, path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 return Scope.checkPathIn(pattern: pattern, path: path)
end function"#,
            "unknownSource",
        ),
        (
            r#"function sample(path: String) -> Result[Scope.PathIn["/data/a"], Scope.ScopeError]
 return Scope.checkPathIn(pattern: "/data/**", path: path)
end function"#,
            "notCovered",
        ),
        (
            r#"function sample(value: Scope.PathIn["/data/**"]) -> String
 return Scope.pathInValue(path: value)
end function"#,
            "unknownSource",
        ),
        (
            r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 return "/data/**" |> Scope.checkPathIn(path: path)
end function"#,
            "unknownSource",
        ),
        (
            r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: path)
 return match result with
 case Result.Ok(value) ->
  bind narrow: Scope.PathIn["/data/a"] <- Scope.widenPathIn(path: value)
  Result.Ok(value)
 case Result.Error(error) -> Result.Error(error)
 end match
end function"#,
            "notCovered",
        ),
    ] {
        let source = path_source(body);
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), 1, "{source}\n{errors:?}");
        assert_eq!(
            errors[0].code.unwrap().info().id,
            "E0519",
            "{source}\n{errors:?}"
        );
        assert!(errors[0].message.contains(reason), "{errors:?}");
        assert!(
            errors[0].notes.iter().any(|note| note.contains(".sample")),
            "{errors:?}"
        );
    }
}

// 関門: 通常の入口で停止情報から選ぶ注記と修正案を守る。
// 局所の受理テストでは番号付けの停止を診断へ渡す接続を検査できない。
#[test]
fn numbering_and_local_budget_diagnostics_explain_different_losses() {
    let mut expanded = String::from("const c0: Integer = 0\n");
    for index in 1..=20 {
        expanded.push_str(&format!(
            "const c{index}: Integer = c{} + c{}\n",
            index - 1,
            index - 1
        ));
    }
    expanded.push_str("function sample(path: String) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n bind _ <- c20\n return Scope.checkPathIn(pattern: \"/data/**\", path: path)\nend function\n");
    let mut retained = String::from(
        "function sample(path: String) -> Unit\n bind first <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n",
    );
    for index in 0..511 {
        retained.push_str(&format!(
            " bind kept{index} <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n"
        ));
    }
    retained.push_str(" match first with\n case Result.Ok(p) ->\n bind wide: Scope.PathIn[\"/data/**\"] <- Scope.widenPathIn(path: p)\n ()\n case Result.Error(_) -> ()\n end match\n ()\nend function\n");
    for (body, numbering) in [(expanded, true), (retained, false)] {
        let result = check(&path_source(&body));
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), 1, "{errors:?}");
        let diagnostic = errors[0];
        assert_eq!(diagnostic.code.unwrap().info().id, "E0519");
        assert!(
            diagnostic.message.contains("budgetExceeded"),
            "{diagnostic:?}"
        );
        assert_eq!(
            diagnostic
                .notes
                .iter()
                .any(|n| n.contains("all Scope rules in this definition require Top")),
            numbering,
            "{diagnostic:?}"
        );
        assert_eq!(
            diagnostic
                .notes
                .iter()
                .any(|n| n
                    .contains("provenance was forgotten while literal patterns remain readable")),
            !numbering,
            "{diagnostic:?}"
        );
        if numbering {
            assert!(
                diagnostic
                    .helps
                    .iter()
                    .any(|h| h.message.contains("split this definition")),
                "{diagnostic:?}"
            );
        } else {
            assert!(
                diagnostic
                    .notes
                    .iter()
                    .any(|n| n.contains("body items limit")),
                "{diagnostic:?}"
            );
        }
    }
}

#[test]
fn reversed_request_literals_are_rejected_before_scope_acceptance() {
    for (ret, narrow) in [
        ("Http.RequestIn[\"api.example.com\", 443]", true),
        ("Http.RequestIn", false),
    ] {
        for direct in [true, false] {
            let (setup, minimum, maximum) = if direct {
                ("", "443", "80")
            } else {
                (
                    " bind minimum <- 443\n bind maximum <- 80\n",
                    "minimum",
                    "maximum",
                )
            };
            let source = format!(
                r#"import Benitoite.Unofficial.Network.Http
function sample(request: Http.ClientRequest) -> Result[{ret}, Http.RequestCheckError]
{setup} return Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: {minimum}, maximumPort: {maximum}, request: request)
end function"#
            );
            let result = check(&source);
            let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
            // ポートの既知不良は本体の後で先に報告する。先行する誤りがあるため
            // 必須の受理の診断へ進まず、狭い注釈とTopのどちらでも同じ追加拒否になる。
            // 局所解析で逆転を未知にする契約は scope::local_tests の表が検査する。
            // bindで名前を付けた引数は追加検査の対象外で、従来の必須受理へ進む。
            let expected = if direct {
                vec!["E0461"]
            } else if narrow {
                vec!["E0519"]
            } else {
                vec![]
            };
            assert_eq!(
                errors
                    .iter()
                    .map(|d| d.code.unwrap().info().id)
                    .collect::<Vec<_>>(),
                expected,
                "{errors:?}"
            );
            if !direct && narrow {
                assert!(errors[0].message.contains("unknownSource"), "{errors:?}");
            }
            assert_eq!(result.program.is_some(), expected.is_empty());
        }
    }
}

#[test]
fn numbering_budget_applies_to_a_rule_after_the_expanding_constant() {
    let mut source = String::from("import Benitoite.Unofficial.Scope\nconst c0: Integer = 0\n");
    for i in 1..=40 {
        source.push_str(&format!("const c{i}: Integer = c{} + c{}\n", i - 1, i - 1));
    }
    source.push_str(
        r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 bind _ <- c40
 return Scope.checkPathIn(pattern: "/data/**", path: path)
end function"#,
    );
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{errors:?}");
    assert_eq!(errors[0].code.unwrap().info().id, "E0519");
    assert!(errors[0].message.contains("budgetExceeded"), "{errors:?}");
    assert!(
        errors[0]
            .notes
            .iter()
            .any(|note| note.contains("surface preorder unavailable"))
    );
}

#[test]
fn function_values_holes_and_unannotated_widen_do_not_invent_ranges() {
    for (body, code) in [
        (
            r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 bind check <- Scope.checkPathIn
 return check(pattern: "/data/**", path: path)
end function"#,
            "E0401",
        ),
        (
            r#"function sample(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 bind check <- Scope.checkPathIn(pattern: "/data/**", path: _)
 return check(path: path)
end function"#,
            "E0401",
        ),
        (
            r#"function sample() -> Unit
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 match result with
 case Result.Ok(value) ->
  bind _ <- Scope.widenPathIn(path: value)
  ()
 case Result.Error(_) -> ()
 end match
end function"#,
            "E0407",
        ),
    ] {
        let source = path_source(body);
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert!(!errors.is_empty(), "{source}");
        assert!(
            errors
                .iter()
                .all(|error| error.code.unwrap().info().id == code),
            "{source}\n{errors:?}"
        );
    }
}

#[test]
fn acceptance_checks_definitions_before_implementation_methods() {
    let source = path_source(
        r#"trait Project[T]
 function project(value: T) -> String
end trait
implement Project[Scope.PathIn["/data/**"]]
 function project(value: Scope.PathIn["/data/**"]) -> String
  return Scope.pathInValue(path: value)
 end function
end implement
function ordinary(value: Scope.PathIn["/data/**"]) -> String
 return Scope.pathInValue(path: value)
end function"#,
    );
    let result = check(&source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{errors:?}");
    assert_eq!(errors[0].code.unwrap().info().id, "E0519");
    assert!(
        errors[0]
            .notes
            .iter()
            .any(|note| note.contains(".ordinary")),
        "{errors:?}"
    );
    let method_only = source[..source.find("function ordinary").unwrap()].to_string();
    let result = check(&method_only);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{errors:?}");
    assert_eq!(errors[0].code.unwrap().info().id, "E0519");
    assert!(
        errors[0].notes.iter().any(|note| note.contains("%impl:")),
        "{errors:?}"
    );
}

// 関門: 旧来の範囲変数なしの操作も、全節がそろう名前の狭原子だけを消す。
// 節自身の同名・別対象の IO は外側へ残る。既存の VM テストは Top の操作だけである。
#[test]
fn handlers_remove_complete_names_and_keep_clause_io_at_its_own_scope() {
    let remaining_clauses = r#"
 case File.openReader(path) -> 0
 case File.readLine(reader) -> 0
 case File.readBytes(path) -> 0
 case File.readTextIn(path) -> 0
 case File.readBytesIn(path) -> 0
 case File.readLines(path) -> 0
 case File.exists(path) -> 0
 case File.info(path) -> 0
 case File.listDirectory(path) -> 0
 case File.walk(path) -> 0
 case File.canonicalize(path) -> 0
 case File.readChunk(reader, maximumBytes) -> 0"#;
    for (name, remaining, clause, upper, expected) in [
        ("complete", remaining_clauses, "0", "", None),
        ("partial", "", "0", "", Some("E0501")),
        (
            "clause IO remains",
            remaining_clauses,
            "outside()",
            r#"uses File.Read["/logs/**"]"#,
            None,
        ),
        (
            "clause IO needs its own bound",
            remaining_clauses,
            "outside()",
            "",
            Some("E0501"),
        ),
    ] {
        let source = format!(
            r#"import Benitoite.Unofficial.IO.File
function protected() -> Integer uses File.Read["/data/a"]
 return 1
end function
function outside() -> Integer uses File.Read["/logs/**"]
 return 2
end function
function sample() -> Integer {upper}
 return handle
  protected()
 with
 case File.readText(path) -> {clause}
 {remaining}
 end handle
end function"#
        );
        assert_handler_contract(name, &source, expected);
    }

    // 後のハンドラの節が run の関数引数を決める場合も、最終の狭原子を消す。
    // 通常入口から脱糖・IR 検査まで結び、仮の範囲変数付き署名だけで代用しない。
    for (name, tail) in [
        ("direct late atom", "return run(protected)"),
        (
            "late atom from later clause",
            "return handle tick() with\n case tick() -> resume(run(protected))\n end handle",
        ),
    ] {
        let source = format!(
            r#"import Benitoite.Unofficial.IO.File
effect Tick
 function tick() -> Integer
end effect
function protected() -> Integer uses File.Read["/data/a"]
 return 1
end function
function sample() -> Integer
 bind run <- lambda(f)
  return handle
   f()
  with
  case File.readText(path) -> 0
  {remaining_clauses}
  end handle
 end lambda
 {tail}
end function"#
        );
        assert_handler_contract(name, &source, None);
    }
}

// 関門: 利用者の操作の固定範囲は、保護本体や節から選んだ添字で置換しない。
#[test]
fn user_operation_clauses_keep_their_declared_fixed_scope() {
    for (name, body, target, expected) in [
        ("called", "save(value)", "/data/**", None),
        ("unused", "()", "/data/**", None),
        ("called mismatch", "save(value)", "/other/**", Some("E0401")),
        ("unused mismatch", "()", "/other/**", Some("E0401")),
    ] {
        let source = path_source(&format!(
            r#"effect Save
 function save(value: Scope.PathIn["/data/**"]) -> Unit
end effect
function accept(value: Scope.PathIn["{target}"]) -> Unit
 ()
end function
function sample(value: Scope.PathIn["/data/**"]) -> Unit
 handle
  {body}
 with
 case save(captured) -> accept(captured)
 end handle
end function"#
        ));
        assert_handler_contract(name, &source, expected);
    }
}

// 関門: handle の節を待つための制約解決で Scope の既定値を早期に確定しない。
#[test]
fn an_unrelated_handler_does_not_finalize_a_prior_scope_check_before_its_later_use() {
    for (name, body) in [
        (
            "use after handler",
            r#"bind _ <- handle
  1
 with
 case tick() -> resume(1)
 end handle
 return match checked with
 case Result.Ok(value) -> accept(value)
 case Result.Error(_) -> 0
 end match"#,
        ),
        (
            "use in unused clause",
            r#"return handle
  1
 with
 case tick() ->
  match checked with
  case Result.Ok(value) -> accept(value)
  case Result.Error(_) -> 0
  end match
 end handle"#,
        ),
        (
            "use in called clause",
            r#"return handle
  tick()
 with
 case tick() ->
  match checked with
  case Result.Ok(value) -> accept(value)
  case Result.Error(_) -> 0
  end match
 end handle"#,
        ),
    ] {
        let source = path_source(&format!(
            r#"effect Tick
 function tick() -> Integer
end effect
function accept(value: Scope.PathIn) -> Integer
 return 7
end function
function sample(path: String) -> Integer
 bind checked <- Scope.checkPathIn(pattern: "/data/**", path: path)
 {body}
end function"#
        ));
        let result = check(&source);
        assert!(
            !result.diagnostics.iter().any(|d| d.is_error()),
            "{name}: {source}\n{:?}",
            result.diagnostics
        );
        let program = result.program.unwrap();
        let selected: Vec<_> = program
            .types
            .call_ranges
            .iter()
            .filter(|(_, ranges)| !ranges.is_empty())
            .collect();
        assert_eq!(selected.len(), 1, "{name}: {selected:?}");
        assert_eq!(
            selected[0].1.as_slice(),
            &[benitoite::types::scope::Range::Top],
            "{name}"
        );
        let core = pipeline::desugar_checked(&program).unwrap();
        assert!(
            benitoite::ir::check::check_program(&core).is_empty(),
            "{name}"
        );
    }
}

fn assert_handler_contract(name: &str, source: &str, expected: Option<&str>) {
    let result = check(source);
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    let actual: Vec<_> = errors
        .iter()
        .map(|error| error.code.unwrap().info().id)
        .collect();
    assert_eq!(
        actual,
        expected.into_iter().collect::<Vec<_>>(),
        "{name}: {source}\n{errors:?}"
    );
    if expected.is_none() {
        let core = pipeline::desugar_checked(&result.program.unwrap()).unwrap();
        assert!(
            benitoite::ir::check::check_program(&core).is_empty(),
            "{name}"
        );
    }
}
