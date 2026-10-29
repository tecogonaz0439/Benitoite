//! 関門: 通常入口で、必須の範囲判定と本体後の警告の独立性を守る。
//! 局所解析の小予算の検査だけでは、警告の駆動や本体の無効化との接続を通らない。
//! 差し込み口は増やさず、採用した本番の上限に届く入力を使う。
use super::{check, pipeline};
use benitoite::diag::DiagCode;

fn warnings(result: &pipeline::CheckResult) -> Vec<(DiagCode, String, Vec<String>)> {
    result
        .diagnostics
        .iter()
        .filter(|d| !d.is_error())
        .map(|d| (d.code.unwrap(), d.message.clone(), d.notes.clone()))
        .collect()
}

const RANGE_WARNING: &str = r#"
 match Range.checkInteger(minimum: 0, maximum: 0, value: x) with
 case Result.Ok(checked) ->
  bind zero <- Range.value(checked)
  bind _ <- 1 div zero
  ()
 case Result.Error(_) -> ()
 end match
"#;

#[test]
fn scope_exhaustion_changes_rejection_reason_without_changing_range_warnings() {
    let source = |count| {
        let mut source = String::from(
            "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Range\nfunction sample(path: String, x: Integer) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n",
        );
        source.push_str(RANGE_WARNING);
        for i in 0..count {
            source.push_str(&format!(
                " bind kept{i} <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n"
            ));
        }
        source.push_str(" return Scope.checkPathIn(pattern: path, path: path)\nend function\n");
        // この密度では Range 自身も本体の予算に届く。停止前の候補に加え、
        // Scope が超過した定義より後の正常な定義の警告も収集し続ける。
        source.push_str("function after_scope(x: Integer) -> Unit\n");
        source.push_str(RANGE_WARNING);
        source.push_str("end function\n");
        source
    };
    let small = check(&source(1));
    let exhausted = check(&source(513));
    for (result, reason) in [(&small, "unknownSource"), (&exhausted, "budgetExceeded")] {
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), 1, "{:?}", result.diagnostics);
        assert_eq!(errors[0].code, Some(DiagCode::E0519));
        assert!(errors[0].message.contains(reason), "{errors:?}");
        assert_eq!(
            warnings(result).len(),
            2,
            "{:?}: {:?}",
            result.interval_analysis,
            result.diagnostics
        );
        assert!(warnings(result).iter().all(|w| w.0 == DiagCode::W0401));
    }
    assert_eq!(warnings(&small), warnings(&exhausted));
}

#[test]
fn scope_rejection_and_legacy_errors_leave_other_range_warnings_intact() {
    for (body, code, warning_count) in [
        (
            "return Scope.checkPathIn(pattern: dynamic, path: dynamic)",
            DiagCode::E0519,
            2,
        ),
        (
            "bind _ <- Scope.checkPath(pattern: \"/bad/*\", path: dynamic)\n return Scope.checkPathIn(pattern: \"/data/**\", path: dynamic)",
            DiagCode::E0459,
            1,
        ),
    ] {
        let source = format!(
            "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Range\nfunction sample(dynamic: String, x: Integer) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n{RANGE_WARNING} {body}\nend function\nfunction warning(x: Integer) -> Unit\n{RANGE_WARNING}end function\n"
        );
        let result = check(&source);
        let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
        assert_eq!(errors.len(), 1, "{:?}", result.diagnostics);
        assert_eq!(errors[0].code, Some(code));
        assert_eq!(
            warnings(&result).len(),
            warning_count,
            "{:?}",
            result.diagnostics
        );
        assert!(warnings(&result).iter().all(|w| w.0 == DiagCode::W0401));
    }
}

#[test]
fn warning_candidates_do_not_change_scoped_type_acceptance() {
    let source = |bound| {
        format!(
            "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.Range\nfunction sample(path: String, x: Integer) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n bind result <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n {}\n return result\nend function\n",
            RANGE_WARNING.replace(
                "minimum: 0, maximum: 0",
                &format!("minimum: {bound}, maximum: {bound}")
            )
        )
    };
    let mut selections = vec![];
    for (bound, warned) in [(0, true), (1, false)] {
        let result = check(&source(bound));
        assert!(result.program.is_some(), "{:?}", result.diagnostics);
        assert_eq!(!warnings(&result).is_empty(), warned);
        let program = result.program.unwrap();
        selections.push(
            program
                .types
                .call_ranges
                .iter()
                .filter(|(_, r)| !r.is_empty())
                .map(|(_, r)| r.clone())
                .collect::<Vec<_>>(),
        );
    }
    assert_eq!(selections[0], selections[1]);
}

#[test]
fn stage_closure_input_keeps_ranges_through_methods_constants_and_forgetting() {
    let source = include_str!("closure.bnt");
    let result = check(source);
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
    let program = result.program.unwrap();
    let mut definitions = vec![];
    let mut body_ranges = std::collections::BTreeMap::new();
    for body in &program.types.scope_inputs.bodies {
        if !body.body_key.definition.starts_with("Benitoite.") {
            let numbered = body.numbered(benitoite::typeck::DEFAULT_NUMBERING_OPERATIONS);
            assert!(numbered.stopped.is_none(), "{numbered:?}");
            assert!(
                numbered
                    .occurrences
                    .iter()
                    .enumerate()
                    .all(|(i, o)| u64::try_from(i).unwrap() == o.preorder)
            );
            definitions.push(body.body_key.definition.clone());
            // 出現の位置で、型検査が実際に確定した組み込みの頭の列を読む。
            // 局所解析を再実行して期待値を作らない。
            let ranges: Vec<_> = numbered
                .occurrences
                .iter()
                .filter_map(|o| {
                    let benitoite::typeck::ScopeOrigin::Expression(node) = o.origin else {
                        return None;
                    };
                    let ranges = program.types.call_ranges.get(node)?;
                    if ranges.is_empty() {
                        return None;
                    }
                    let text = &source[usize::try_from(o.span.start.0).unwrap()
                        ..usize::try_from(o.span.end.0).unwrap()];
                    Some((text, ranges.iter().map(|r| r.suffix()).collect::<Vec<_>>()))
                })
                .collect();
            body_ranges.insert(body.body_key.definition.clone(), ranges);
        }
    }
    assert!(
        definitions.iter().any(|d| d.contains("%impl:")),
        "{definitions:?}"
    );
    assert!(
        definitions.iter().any(|d| d.ends_with(".pattern")),
        "{definitions:?}"
    );
    assert_eq!(
        program
            .types
            .call_ranges
            .iter()
            .filter(|(_, r)| !r.is_empty())
            .count(),
        10,
        "{body_ranges:?}"
    );
    let paths = body_ranges
        .iter()
        .find(|(name, _)| name.ends_with(".paths"))
        .unwrap()
        .1;
    assert_eq!(
        paths,
        &[
            ("S.checkPathIn", vec!["[\"/data/a\"]".to_string()]),
            ("S.pathInValue", vec!["[\"/data/a\"]".to_string()]),
            (
                "S.widenPathIn",
                vec!["[\"/data/a\"]".to_string(), "[\"/data/**\"]".to_string()]
            ),
            ("S.checkPathIn", vec![String::new()]),
            ("S.pathInValue", vec![String::new()]),
            // 間接呼び出しへ渡す関数値の列も Top のままである。
            ("S.checkPathIn", vec![String::new()]),
        ],
        "{body_ranges:?}"
    );
    let method = body_ranges
        .iter()
        .find(|(name, _)| name.contains("%impl:"))
        .unwrap()
        .1;
    assert_eq!(
        method,
        &[("S.checkPathIn", vec!["[\"/data/a\"]".to_string()])]
    );
    let pairs: Vec<_> = program
        .types
        .call_ranges
        .iter()
        .filter(|(_, r)| r.len() == 2)
        .map(|(_, r)| r.iter().map(|r| r.suffix()).collect::<Vec<_>>())
        .collect();
    assert!(
        pairs.contains(&vec!["[\"/data/a\"]".into(), "[\"/data/**\"]".into()]),
        "{pairs:?}"
    );
    assert!(
        pairs.contains(&vec![
            "[\"api.example.com\", 443]".into(),
            "[\"*.example.com\", 443]".into()
        ]),
        "{pairs:?}"
    );
    let core = pipeline::desugar_checked(&program).unwrap();
    let errors = benitoite::ir::check::check_program(&core);
    assert!(errors.is_empty(), "{errors:?}");
}

#[test]
fn range_budget_stop_does_not_erase_a_required_scope_selection() {
    let mut source = String::from(
        "import Benitoite.Unofficial.Scope\nfunction sample(path: String, x: Integer) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n bind result <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n",
    );
    for _ in 0..8 {
        source.push_str(" block\n");
        for _ in 0..500 {
            source.push_str(" bind _ <- (x + 1) * (x + 2)\n");
        }
        source.push_str(" ()\n end block\n");
    }
    source.push_str(" return result\nend function\n");
    let result = check(&source);
    assert!(result.program.is_some(), "{:?}", result.diagnostics);
    assert!(
        result.interval_analysis.body_budget_exceeded > 0
            || result
                .interval_analysis
                .phase_stops
                .exceeded
                .body_operations
                > 0,
        "{:?}",
        result.interval_analysis
    );
    let program = result.program.unwrap();
    let selected: Vec<_> = program
        .types
        .call_ranges
        .iter()
        .filter(|(_, r)| !r.is_empty())
        .map(|(_, r)| r.iter().map(|r| r.suffix()).collect::<Vec<_>>())
        .collect();
    assert_eq!(selected, [vec!["[\"/data/**\"]".to_string()]]);
}

#[test]
fn an_inferred_body_does_not_narrow_the_public_return_contract() {
    let result = check(
        r#"import Benitoite.Unofficial.Scope
function checked(path: String) -> Result[Scope.PathIn, Scope.ScopeError]
 return Scope.checkPathIn(pattern: "/data/**", path: path)
end function
function caller(path: String) -> Result[Scope.PathIn["/data/**"], Scope.ScopeError]
 return checked(path)
end function"#,
    );
    let errors: Vec<_> = result.diagnostics.iter().filter(|d| d.is_error()).collect();
    assert_eq!(errors.len(), 1, "{errors:?}");
    assert_eq!(errors[0].code, Some(DiagCode::E0401));
}
