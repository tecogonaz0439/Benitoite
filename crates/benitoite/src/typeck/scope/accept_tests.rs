//! 規則の選択・全呼び出しの受理と、番号ラベルの確定の独立した契約を検査する。
//! 関門: 予算後の呼び出しの欠落、パイプの所属の誤認、仮番号の流出を捕まえる。
//! 既存の局所解析の検査は受理と補間後の番号の更新を検査しない。
//! 本物の読み込み・名前解決・型検査から返る入力だけを使う。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::types::scope::{PathPattern, Range};

fn input(source: &str) -> ScopeBodyInput {
    let (_, _, output, diagnostics) = crate::typeck::test_support::check_files(
        &[(
            ".bnt",
            &format!("import Benitoite.Unofficial.Scope\n{source}"),
        )],
        false,
    );
    assert!(
        !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    output
        .scope_inputs
        .bodies
        .into_iter()
        .find(|body| body.body_key.definition == ".sample")
        .unwrap()
}

fn limits() -> ScopeLimits {
    let cap = ScopeCap {
        operations: 100_000,
        items: 10_000,
    };
    ScopeLimits {
        body: cap,
        whole: cap,
    }
}

fn path(pattern: &str) -> Range {
    Range::Path(PathPattern::parse(pattern).unwrap())
}

#[test]
fn selected_range_and_acceptance_distinguish_known_unknown_missing_and_unselected() {
    let body = input(
        r#"function sample(pattern: String, top: Scope.PathIn) -> Unit
 bind _ <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 bind _ <- Scope.checkPathIn(pattern: pattern, path: "/data/a")
 bind _ <- Scope.pathInValue(top)
 ()
end function"#,
    );
    let analysis = body.analyze(DEFAULT_NUMBERING_OPERATIONS, limits());
    let known = &analysis.input.calls[0];
    let unknown = &analysis.input.calls[1];
    let explicit_top = &analysis.input.calls[2];
    assert_eq!(analysis.selected_ranges(known).unwrap(), [path("/data/**")]);
    assert_eq!(analysis.selected_ranges(unknown).unwrap(), [Range::Top]);
    assert_eq!(
        analysis.required_ranges(explicit_top).unwrap(),
        [vec![ScopeRequired::Unknown]]
    );
    assert_eq!(analysis.accept_call(known, &[path("/**")]), Ok(()));
    assert_eq!(analysis.accept_call(known, &[Range::Top]), Ok(()));
    for (call, ranges, reason) in [
        (
            known,
            vec![path("/other/**")],
            ScopeCoverFailure::NotCovered,
        ),
        (
            unknown,
            vec![path("/data/**")],
            ScopeCoverFailure::UnknownSource,
        ),
        (
            explicit_top,
            vec![path("/data/**")],
            ScopeCoverFailure::UnknownSource,
        ),
        (known, vec![], ScopeCoverFailure::NotCovered),
    ] {
        assert_eq!(
            analysis.accept_call(call, &ranges),
            Err(ScopeAcceptError::Rejected(ScopeRejection {
                definition: ".sample".into(),
                preorder: Some(call.preorder),
                node: call.node,
                reason,
            }))
        );
    }
    // 規則が選ばない追加位置への制約は置かない。列の個数は署名の型付けが担う。
    assert_eq!(
        analysis.accept_call(known, &[path("/data/**"), path("/other/**")]),
        Ok(())
    );
}

#[test]
fn final_run_budget_keeps_literals_and_the_completed_preorder() {
    let body = input(
        r#"function sample() -> Unit
 bind _ <- 1 + 2
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 ()
end function"#,
    );
    let mut limits = limits();
    limits.body.operations = 0;
    let analysis = body.analyze(DEFAULT_NUMBERING_OPERATIONS, limits);
    assert_eq!(analysis.input.stopped, None);
    assert!(matches!(
        analysis.stopped,
        Some(ScopeInputStop::BudgetExceeded { .. })
    ));
    let calls = &analysis.input.calls;
    assert_eq!(calls.len(), 1);
    assert_eq!(
        analysis.selected_ranges(&calls[0]).unwrap(),
        [path("/data/**")]
    );
    assert_eq!(
        analysis.accept_call(&calls[0], &[path("/other/**")]),
        Err(ScopeAcceptError::Rejected(ScopeRejection {
            definition: ".sample".into(),
            preorder: Some(calls[0].preorder),
            node: calls[0].node,
            reason: ScopeCoverFailure::NotCovered,
        }))
    );
    assert_eq!(analysis.accept_call(&calls[0], &[Range::Top]), Ok(()));
}

#[test]
fn pipe_right_requires_top_even_when_the_left_is_a_pattern_literal() {
    let body = input(
        r#"function sample() -> Unit
 bind _ <- "/data/**" |> Scope.checkPathIn(path: "/data/a")
 ()
end function"#,
    );
    let analysis = body.analyze(DEFAULT_NUMBERING_OPERATIONS, limits());
    assert_eq!(analysis.input.calls.len(), 1);
    assert_eq!(
        analysis.selected_ranges(&analysis.input.calls[0]).unwrap(),
        [Range::Top]
    );
}

#[test]
fn pending_interpolation_changes_only_labels_and_not_the_numbering_budget() {
    let mut body = input(
        r#"function sample(text: String) -> Unit
 bind _ <- "${text}"
 bind r <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 match r with
 case Result.Ok(p) -> bind _ <- Scope.pathInValue(p)
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let final_input = body.numbered(DEFAULT_NUMBERING_OPERATIONS);
    body.converters = std::sync::Arc::new(NodeMap::default());
    let mut analysis = body.analyze_pending(DEFAULT_NUMBERING_OPERATIONS, limits());
    assert_eq!(analysis.stopped, None);
    let pending_call = analysis.input.calls[0].preorder;
    let selected = analysis.selected_ranges(&analysis.input.calls[0]).unwrap();
    assert_eq!(selected, [path("/data/**")]);
    assert_eq!(pending_call, final_input.calls[0].preorder + 1);
    analysis.renumber(final_input.clone()).unwrap();
    assert_eq!(analysis.input, final_input);
    assert_eq!(
        analysis.selected_ranges(&analysis.input.calls[0]).unwrap(),
        selected
    );
    let fact = analysis.calls[0].result.as_ref().unwrap();
    let ScopeFact::Result(origin) = fact else {
        panic!("result origin")
    };
    assert_eq!(origin.key.surface_preorder, final_input.calls[0].preorder);
    let mut checked_origins = 0;
    for record in &analysis.records {
        for local in record.state.locals() {
            if let Some(ScopeFact::Checked { origin, .. }) = local.fact {
                checked_origins += 1;
                assert_eq!(origin.key.surface_preorder, final_input.calls[0].preorder);
            }
        }
    }
    assert!(checked_origins > 0);
    // Converter の操作を読む前後の上限でも、変換の有無で停止の位置を変えない。
    for budget in 0..40 {
        let pending = body.number(budget, true);
        let mut final_body = body.clone();
        let mut converters = NodeMap::default();
        for occurrence in body.number(DEFAULT_NUMBERING_OPERATIONS, true).occurrences {
            if let ScopeOrigin::InterpolationConverter(node) = occurrence.origin {
                converters.insert(node, false);
            }
        }
        final_body.converters = std::sync::Arc::new(converters);
        assert_eq!(pending.stopped, final_body.numbered(budget).stopped);
    }
}

// 関門: 予算を失った地点だけへ理由を付ける退行と、リテラルを全てTopへ丸める退行を捕まえる。
#[test]
fn exceeded_reason_applies_to_top_at_every_location_but_preserves_literals() {
    let body = input(
        r#"function sample(pattern: String) -> Unit
 bind before <- Scope.checkPathIn(pattern: pattern, path: "/data/a")
 bind literal <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 bind after <- Scope.checkPathIn(pattern: pattern, path: "/data/a")
 ()
end function"#,
    );
    let mut small = limits();
    // 最初の未知の検査は同定1+読み取り1+事実書込み1で通す。次のリテラル検査で超える。
    small.body.operations = 3;
    let result = body.analyze(DEFAULT_NUMBERING_OPERATIONS, small);
    assert!(result.stopped.is_some());
    for (call, known) in result.input.calls.iter().zip([false, true, false]) {
        let expected = if known {
            ScopeRequired::Known(path("/data/**"))
        } else {
            ScopeRequired::Exceeded
        };
        assert_eq!(result.required_ranges(call).unwrap(), [vec![expected]]);
        let accepted = result.accept_call(call, &[path("/data/**")]);
        if known {
            assert_eq!(accepted, Ok(()));
        } else {
            assert!(matches!(
                accepted,
                Err(ScopeAcceptError::Rejected(ScopeRejection {
                    reason: ScopeCoverFailure::BudgetExceeded,
                    ..
                }))
            ));
        }
    }
}

// 関門: 番号付けの接頭辞からリテラルだけを受理する退行を捕まえる。
// 本番のソースから得る六宣言を全て問い合わせ、小上限だけを独立に指定する。
#[test]
fn numbering_limit_requires_top_for_every_rule_including_literal_checks() {
    let body = input(
        r#"import Benitoite.Unofficial.Network.Http
function sample(path: String, request: Http.ClientRequest) -> Unit
 bind first <- Scope.checkPathIn(pattern: "/data/**", path: path)
 match first with
 case Result.Ok(p) ->
  bind projected <- Scope.pathInValue(path: p)
  bind wide: Scope.PathIn <- Scope.widenPathIn(path: p)
  ()
 case Result.Error(_) -> ()
 end match
 bind second <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: 443, request: request)
 match second with
 case Result.Ok(r) ->
  bind projected <- Http.requestInValue(request: r)
  bind wide: Http.RequestIn <- Http.widenRequestIn(request: r)
  ()
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let calls = body.rule_calls();
    assert_eq!(calls.len(), 6);
    for limit in [0, 20] {
        let result = body.analyze(limit, limits());
        assert_eq!(
            result.input.stopped,
            Some(ScopeInputStop::NumberingLimit {
                max_operations: limit
            })
        );
        for call in &calls {
            assert_eq!(
                result.required_ranges(call).unwrap(),
                [vec![ScopeRequired::Exceeded]]
            );
            assert_eq!(result.selected_ranges(call).unwrap(), [Range::Top]);
            assert_eq!(result.accept_call(call, &[Range::Top, Range::Top]), Ok(()));
            assert!(matches!(
                result.accept_call(call, &[path("/data/**"), Range::Top]),
                Err(ScopeAcceptError::Rejected(ScopeRejection {
                    reason: ScopeCoverFailure::BudgetExceeded,
                    preorder: None,
                    ..
                }))
            ));
        }
    }
}
