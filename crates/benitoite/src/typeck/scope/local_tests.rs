//! 関門: 通常ソースから ScopeLower の事実・忘却・記録位置の独立した契約を検査する。
//! Result の別名や合流値への伝播、境界での捕捉、無記録位置への外側の記録の流用を捕まえる。
//! R20.1 の番号テストは事実を検査せず、既存の区間テストは合流の規則が違う。
//! 本物の読み込み・名前解決・型検査と ScopeBodyInput::analyze だけを使う。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::types::scope::{Kind, Range};

fn limits(operations: u64, items: u64) -> ScopeLimits {
    let cap = ScopeCap { operations, items };
    ScopeLimits {
        body: cap,
        whole: cap,
    }
}

// 型の制約から Top を選べる入力は、由来を忘れた射影も受理する。
// 局所解析が認定する由来の期待値は、型検査で選んだ列とは独立に保つ。
fn source(text: &str) -> (crate::resolve::ResolveOutput, crate::typeck::TypeckOutput) {
    source_with_errors(text, &[])
}

// 本体の後の既知不良の追加拒否があっても、先行する局所解析の結果は同じである。
fn source_with_errors(
    text: &str,
    expected: &[crate::diag::DiagCode],
) -> (crate::resolve::ResolveOutput, crate::typeck::TypeckOutput) {
    let text = format!(
        r#"import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.File
function ignore[T](value: T) -> Unit
 ()
end function
{text}"#
    );
    let (_, resolved, output, diagnostics) =
        crate::typeck::test_support::check_files(&[(".bnt", &text)], false);
    let errors: Vec<_> = diagnostics
        .iter()
        .filter(|diagnostic| diagnostic.is_error())
        .collect();
    assert_eq!(
        errors
            .iter()
            .filter_map(|diagnostic| diagnostic.code)
            .collect::<Vec<_>>(),
        expected,
        "{diagnostics:#?}"
    );
    (resolved, output)
}

fn analyze(output: &crate::typeck::TypeckOutput, name: &str) -> ScopeAnalysis {
    let body = output
        .scope_inputs
        .bodies
        .iter()
        .find(|b| b.body_key.definition == format!(".{name}"))
        .unwrap();
    assert!(body.contains_rules());
    let result = body.analyze(DEFAULT_NUMBERING_OPERATIONS, limits(100_000, 10_000));
    assert_eq!(result.stopped, None);
    result
}

fn bound(argument: &ScopeArgument) -> Option<&ScopeValueOrigin> {
    match argument {
        ScopeArgument::Local {
            id,
            fact: Some(ScopeFact::Checked { origin, success_id }),
        } if id == success_id => Some(origin),
        ScopeArgument::String(_)
        | ScopeArgument::Integer(_)
        | ScopeArgument::Local { .. }
        | ScopeArgument::Unknown => None,
    }
}

fn projections(result: &ScopeAnalysis) -> Vec<Option<String>> {
    result
        .calls
        .iter()
        .filter(|c| {
            matches!(
                c.declaration,
                ScopeDeclaration::PathValue | ScopeDeclaration::RequestValue
            )
        })
        .map(|c| {
            bound(&c.arguments[0]).map(|o| match &o.bound {
                ScopeBound::Known(r) => r.suffix(),
                ScopeBound::Unknown => "unknown".into(),
            })
        })
        .collect()
}

#[test]
fn saved_result_ok_and_error_match_independent_scope_lower_records() {
    let (resolved, output) = source(
        r#"function sample(path: String) -> Unit
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: path)
 match result with
 case Result.Ok(p) -> ignore(Scope.pathInValue(p))
 case Result.Error(e) -> ignore(e)
 end match
 ()
end function"#,
    );
    let result = analyze(&output, "sample");
    // ScopeLower: call0/head1/lit2/local3, match4/local5,
    // ignore6/head7/project8/head9/p10, ignore11/head12/e13, unit14。
    assert_eq!(
        result
            .records
            .iter()
            .map(|r| r.key.surface_preorder)
            .collect::<Vec<_>>(),
        [0, 4, 6, 11, 14]
    );
    assert_eq!(projections(&result), [None]); // project8 自身には文の記録がない。
    let ok = &result.records[2].state;
    let slots: Vec<_> = ok.locals().collect();
    assert_eq!(ok.next_id(), 3);
    assert_eq!(
        slots
            .iter()
            .map(|s| (
                s.id,
                s.binding
                    .map(|b| resolved.bindings.get(b).unwrap().name.as_str())
            ))
            .collect::<Vec<_>>(),
        [(2, Some("p")), (1, Some("result")), (0, Some("path"))]
    );
    let ScopeFact::Checked { origin, success_id } = slots[0].fact.as_ref().unwrap() else {
        panic!("checked");
    };
    assert_eq!(*success_id, 2);
    assert_eq!(origin.key.surface_preorder, 0);
    assert_eq!(origin.kind, Kind::Path);
    assert_eq!(
        origin.bound,
        ScopeBound::Known(Range::Path(
            crate::types::scope::PathPattern::parse("/data/**").unwrap()
        ))
    );
    assert!(matches!(slots[1].fact, Some(ScopeFact::Result(_))));
    let err: Vec<_> = result.records[3].state.locals().collect();
    assert_eq!(err[0].id, 2);
    assert_eq!(err[0].fact, None);
    assert_eq!(result.records[4].state.locals().count(), 2);
    assert!(matches!(
        result.records[4].state.locals().next().unwrap().fact,
        Some(ScopeFact::Result(_))
    ));
}

#[test]
fn direct_projections_distinguish_instances_aliases_rewrap_and_unknown_calls() {
    let (_, output) = source(
        r#"function identity[T](value: T) -> T
 return value
end function
function sample(path: String, other: Scope.PathIn) -> Unit
 bind first <- Scope.checkPathIn(pattern: "/a/**", path: path)
 bind second <- Scope.checkPathIn(pattern: "/b/**", path: path)
 bind alias <- first
 bind wrapped <- Result.Ok(first)
 bind unknown <- identity(first)
 match first with
 case Result.Ok(p) ->
  bind _ <- Scope.pathInValue(p)
  bind _ <- Scope.pathInValue(other)
  bind q <- p
  bind _ <- Scope.pathInValue(q)
  bind projected <- Scope.pathInValue(p)
  bind r <- Scope.checkPathIn(pattern: projected, path: path)
  match r with
  case Result.Ok(x) -> bind _ <- Scope.pathInValue(x)
  case Result.Error(_) -> ()
  end match
  match second with
  case Result.Ok(x) -> bind _ <- Scope.pathInValue(x)
  case Result.Error(_) -> ()
  end match
 case Result.Error(_) -> ()
 end match
 match alias with
 case Result.Ok(p) -> bind _ <- Scope.pathInValue(p)
 case Result.Error(_) -> ()
 end match
 match wrapped with
 case Result.Ok(r) -> match r with
  case Result.Ok(p) -> bind _ <- Scope.pathInValue(p)
  case Result.Error(_) -> ()
  end match
 case Result.Error(_) -> ()
 end match
 match unknown with
 case Result.Ok(p) -> bind _ <- Scope.pathInValue(p)
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let result = analyze(&output, "sample");
    assert_eq!(
        projections(&result),
        [
            Some("[\"/a/**\"]".into()),
            None,
            None,
            Some("[\"/a/**\"]".into()),
            Some("unknown".into()),
            Some("[\"/b/**\"]".into()),
            None,
            None,
            None
        ]
    );
    assert!(
        result
            .calls
            .iter()
            .filter(|c| matches!(c.declaration, ScopeDeclaration::PathValue))
            .all(|c| c.result.is_none())
    );
}

#[test]
fn checks_read_only_literals_and_direct_const_chains_with_typed_integers() {
    let (_, output) = source_with_errors(
        r#"const pattern: String = "/data/**"
const chain: String = pattern
const computed: String = "/data" + "/**"
const host: String = "API.EXAMPLE"
const low: Integer = 0
const high: Integer = 65535
const aliasHigh: Integer = high
const computedPort: Integer = 440 + 3
function pure() -> String
 return "/data/**"
end function
function sample(path: String, req: Http.ClientRequest) -> Unit
 bind local <- "/data/**"
 bind _ <- Scope.checkPathIn(pattern: chain, path: path)
 bind _ <- Scope.checkPathIn(pattern: computed, path: path)
 bind _ <- Scope.checkPathIn(pattern: local, path: path)
 bind _ <- Scope.checkPathIn(pattern: pure(), path: path)
 bind _ <- Scope.checkPathIn(pattern: (pattern), path: path)
 bind _ <- Scope.checkPathIn(pattern: "/bad//path", path: path)
 bind _ <- Http.checkRequestIn(request: req, maximumPort: aliasHigh, hostPattern: host, minimumPort: low)
 bind _ <- Http.checkRequestIn(hostPattern: "**.example", minimumPort: -1, maximumPort: 443, request: req)
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: 65536, request: req)
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 443, maximumPort: 80, request: req)
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: computedPort, request: req)
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 443, maximumPort: 443, request: req)
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: 443, request: req)
 bind port <- 443
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: port, request: req)
 bind _ <- Http.checkRequestIn(hostPattern: "\u{0}443", minimumPort: 80, maximumPort: 443, request: req)
 ()
end function"#,
        &[
            crate::diag::DiagCode::E0459,
            crate::diag::DiagCode::E0461,
            crate::diag::DiagCode::E0461,
            crate::diag::DiagCode::E0461,
            crate::diag::DiagCode::E0459,
        ],
    );
    let result = analyze(&output, "sample");
    let bounds: Vec<_> = result
        .calls
        .iter()
        .map(|c| match &c.result {
            Some(ScopeFact::Result(o)) => match &o.bound {
                ScopeBound::Known(r) => Some(r.suffix()),
                _ => None,
            },
            _ => None,
        })
        .collect();
    assert_eq!(
        bounds,
        [
            Some("[\"/data/**\"]".into()),
            None,
            None,
            None,
            None,
            None,
            Some("[\"api.example\", 0..65535]".into()),
            None,
            None,
            // L40.3d の requestLitBound は PortRange.WF を要求する。
            // 443 > 80 なので未知。Rust の解析結果から期待値を作らない。
            None,
            None, // computedPort の演算を評価しない。
            Some("[\"api.example\", 443]".into()),
            Some("[\"api.example\", 80..443]".into()),
            None,
            None
        ]
    );
    let req = &result.calls[6];
    assert_eq!(req.arguments[1], ScopeArgument::Integer(0));
    assert_eq!(req.arguments[2], ScopeArgument::Integer(65535));
    assert_eq!(result.calls[7].arguments[1], ScopeArgument::Integer(-1));

    // 文字列のポートは通常の型検査が拒否する。収集済みの入力を読む場合も
    // Integer へ読み替えず未知にする（requestLitBound の型付き整数との対応）。
    let (_, _, output, diagnostics) = crate::typeck::test_support::check_files(
        &[(
            ".bnt",
            r#"import Benitoite.Unofficial.Network.Http
function sample(req: Http.ClientRequest) -> Unit
 bind _ <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: "80", maximumPort: "443", request: req)
 ()
end function"#,
        )],
        false,
    );
    assert!(diagnostics.iter().any(crate::diag::Diagnostic::is_error));
    let result = analyze(&output, "sample");
    assert!(matches!(
        result.calls[0].arguments[1],
        ScopeArgument::String(_)
    ));
    assert!(matches!(
        &result.calls[0].result,
        Some(ScopeFact::Result(ScopeValueOrigin {
            bound: ScopeBound::Unknown,
            ..
        }))
    ));
}

#[test]
fn request_ok_keeps_its_own_origin_and_projection_has_no_result_fact() {
    let (_, output) = source(
        r#"function sample(req: Http.ClientRequest, other: Http.RequestIn) -> Unit
 bind r <- Http.checkRequestIn(hostPattern: "api.example", minimumPort: 80, maximumPort: 443, request: req)
 match r with
 case Result.Ok(p) ->
  bind _ <- Http.requestInValue(p)
  bind _ <- Http.requestInValue(other)
  bind copy <- p
  bind _ <- Http.requestInValue(copy)
  bind projected <- Http.requestInValue(p)
  bind r2 <- Http.checkRequestIn(hostPattern: "other.example", minimumPort: 443, maximumPort: 443, request: projected)
  match r2 with
  case Result.Ok(q) -> bind _ <- Http.requestInValue(q)
  case Result.Error(_) -> ()
  end match
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let result = analyze(&output, "sample");
    assert_eq!(
        projections(&result),
        [
            Some("[\"api.example\", 80..443]".into()),
            None,
            None,
            Some("[\"api.example\", 80..443]".into()),
            Some("[\"other.example\", 443]".into())
        ]
    );
    for c in result
        .calls
        .iter()
        .filter(|c| c.declaration == ScopeDeclaration::RequestValue)
    {
        assert!(c.result.is_none());
        if let Some(o) = bound(&c.arguments[0]) {
            assert_eq!(o.kind, Kind::Endpoint);
        }
    }
}

#[test]
fn joins_forget_only_the_value_and_keep_outer_facts_and_positions() {
    let (_, output) = source(
        r#"function sample(path: String) -> Unit
 bind r <- Scope.checkPathIn(pattern: "/outer/**", path: path)
 match r with
 case Result.Ok(p) ->
  bind branch <- if true then p else p end if
  bind _ <- Scope.pathInValue(branch)
  bind _ <- Scope.pathInValue(p)
  bind blocked <- block p end block
  bind _ <- Scope.pathInValue(blocked)
  bind _ <- Scope.pathInValue(p)
  bind selected <- match true with
  case true -> p
  case false -> p
  end match
  bind _ <- Scope.pathInValue(selected)
  bind _ <- Scope.pathInValue(p)
  bind inner <- block
   bind r2 <- Scope.checkPathIn(pattern: "/inner/**", path: path)
   match r2 with
   case Result.Ok(q) ->
    bind _ <- Scope.pathInValue(q)
    p
   case Result.Error(_) -> p
   end match
  end block
  bind _ <- Scope.pathInValue(inner)
  bind _ <- Scope.pathInValue(p)
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let result = analyze(&output, "sample");
    let outer = Some("[\"/outer/**\"]".into());
    assert_eq!(
        projections(&result),
        [
            None,
            outer.clone(),
            None,
            outer.clone(),
            None,
            outer.clone(),
            Some("[\"/inner/**\"]".into()),
            None,
            outer
        ]
    );
    for r in &result.records {
        let locals: Vec<_> = r.state.locals().collect();
        for s in &locals {
            assert!(s.id < r.state.next_id());
        }
        let mut ids: Vec<_> = locals.iter().map(|s| s.id).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), locals.len());
    }
}

#[test]
fn bodies_clear_facts_preserve_positions_and_restore_the_outer_state() {
    let (resolved, output) = source(
        r#"effect E
 function ask() -> Unit
end effect
function sample(path: String) -> Unit uses State
 bind r <- Scope.checkPathIn(pattern: "/outer/**", path: path)
 match r with
 case Result.Ok(p) ->
  bind f <- lambda(x: String) -> Unit
   bind _ <- Scope.pathInValue(p)
   bind own <- Scope.checkPathIn(pattern: "/lambda/**", path: x)
   match own with
   case Result.Ok(q) -> bind _ <- Scope.pathInValue(q)
   case Result.Error(_) -> ()
   end match
  end lambda
  bind _ <- Scope.pathInValue(p)
  bind delayed <- lazy
   bind _ <- Scope.pathInValue(p)
   ()
  end lazy
  bind _ <- Scope.pathInValue(p)
  handle
   bind _ <- Scope.pathInValue(p)
   ask()
  with
  case ask() ->
   bind _ <- Scope.pathInValue(p)
   resume(())
  end handle
  bind _ <- Scope.pathInValue(p)
  handle
   bind _ <- Scope.pathInValue(p)
   Failure.raise(error: "failed")
  with
  case Failure.raise(error) ->
   bind _ <- Scope.pathInValue(p)
   ()
  end handle
  bind _ <- Scope.pathInValue(p)
  with group = TaskGroup.open() do
   bind _ <- TaskGroup.spawn(group: group, action: lambda() -> Unit
    bind _ <- Scope.pathInValue(p)
    ()
   end lambda)
  end with
  bind _ <- Scope.pathInValue(p)
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let result = analyze(&output, "sample");
    let outer = Some("[\"/outer/**\"]".into());
    assert_eq!(
        projections(&result),
        [
            None,
            Some("[\"/lambda/**\"]".into()),
            outer.clone(),
            None,
            outer.clone(),
            None,
            None,
            outer.clone(),
            None,
            None,
            outer.clone(),
            None,
            outer
        ]
    );
    // 入口で捕捉した p の位置は残る。事実だけを消し、x の新しい位置を上に積む。
    let capture = result
        .records
        .iter()
        .find(|r| {
            r.state.locals().next().is_some_and(|s| {
                s.binding
                    .is_some_and(|b| resolved.bindings.get(b).unwrap().name == "x")
            })
        })
        .unwrap();
    let positions: Vec<_> = capture.state.locals().collect();
    assert_eq!(
        positions.iter().map(|s| s.id).collect::<Vec<_>>(),
        [3, 2, 1, 0]
    );
    assert!(positions.iter().all(|s| s.fact.is_none()));
}

#[test]
fn try_direct_match_wrapping_and_unvisited_expressions_do_not_gain_facts() {
    let (_, output) = source(
        r#"function sample(path: String) -> Result[Unit, Scope.ScopeError]
 bind r <- Scope.checkPathIn(pattern: "/outer/**", path: path)
 bind p <- try r
 bind _ <- Scope.pathInValue(p)
 match Scope.checkPathIn(pattern: "/direct/**", path: path) with
 case Result.Ok(q) -> bind _ <- Scope.pathInValue(q)
 case Result.Error(_) -> ()
 end match
 match (r) with
 case Result.Ok(q) -> bind _ <- Scope.pathInValue(q)
 case Result.Error(_) -> ()
 end match
 match r with
 case Result.Ok(q) ->
  bind _ <- [block
   bind _ <- Scope.pathInValue(q)
   1
  end block]
  bind _ <- block
   bind _ <- Scope.pathInValue(q)
   1
  end block + 2
  bind _ <- Scope.pathInValue(q) |> ignore()
  bind _ <- Scope.checkPathIn(pattern: "/left/**", path: path) |> ignore()
  bind piped <- "/pipe/**" |> Scope.checkPathIn(path: path)
  match piped with
  case Result.Ok(x) -> bind _ <- Scope.pathInValue(x)
  case Result.Error(_) -> ()
  end match
  bind _ <- Scope.pathInValue(q)
 case Result.Error(_) -> ()
 end match
 return Result.Ok(())
end function"#,
    );
    let result = analyze(&output, "sample");
    assert_eq!(
        projections(&result),
        [
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            Some("[\"/outer/**\"]".into())
        ]
    );
    // パイプの両辺の規則も同定するが、transfer の事実と文の記録を作らない。
    // 受理へ渡す引数は ScopeAccept.factFree に対応する（局所の由来なし）。
    for call in &result.calls {
        if !result.records.iter().any(|r| r.key == call.key) {
            assert!(call.result.is_none(), "unrecorded transfer: {call:?}");
            assert!(call.arguments.iter().all(|a| bound(a).is_none()));
        }
    }
    // 未訪問の list・binary 内の文には記録を置かない。
    assert!(result.records.len() < result.input.statements.len());
}

#[test]
fn budget_forgetting_keeps_positions_and_literal_conditions() {
    let (_, output) = source(
        r#"function sample(path: String) -> Unit
 bind r <- Scope.checkPathIn(pattern: "/a/**", path: path)
 match r with
 case Result.Ok(p) ->
  bind text <- Scope.pathInValue(p)
  bind copy <- p
  bind _ <- Scope.pathInValue(p)
  bind _ <- Scope.checkPathIn(pattern: "/literal/**", path: text)
  ()
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let body = output
        .scope_inputs
        .bodies
        .iter()
        .find(|b| b.body_key.definition == ".sample")
        .unwrap();
    // ScopeState.stepCost: Result保存 = 1+read(path)1+write1 = 3、Ok = 2、
    // 射影結果の保存 = 1+read(p)2 = 3、別名 = 1。discard は一段を進めない。
    for (operations, items, expected, known) in [
        (2, 10, Some(ScopeBudgetResource::Operations), false),
        (4, 10, Some(ScopeBudgetResource::Operations), false),
        (7, 10, Some(ScopeBudgetResource::Operations), true),
        (8, 10, Some(ScopeBudgetResource::Operations), true),
        (9, 10, None, true),
        (100, 0, Some(ScopeBudgetResource::Items), false),
        (100, 1, Some(ScopeBudgetResource::Items), false),
        (100, 2, None, true),
    ] {
        let result = body.analyze(DEFAULT_NUMBERING_OPERATIONS, limits(operations, items));
        assert_eq!(
            result.stopped,
            expected.map(|resource| ScopeInputStop::BudgetExceeded {
                scope: ScopeBudgetScope::Body,
                resource
            }),
            "{operations}/{items}"
        );
        assert_eq!(projections(&result)[0].is_some(), known);
        assert_eq!(
            result
                .calls
                .last()
                .unwrap()
                .result
                .as_ref()
                .map(|f| match f {
                    ScopeFact::Result(o) => &o.bound,
                    _ => panic!("result"),
                }),
            Some(&ScopeBound::Known(Range::Path(
                crate::types::scope::PathPattern::parse("/literal/**").unwrap()
            )))
        );
        let r = result
            .records
            .iter()
            .find(|r| r.state.locals().count() == 5)
            .unwrap();
        assert_eq!(
            r.state.locals().map(|s| s.id).collect::<Vec<_>>(),
            [4, 3, 2, 1, 0]
        );
    }
}

// 登録済みの操作も Lean では primName であり、rhsStep.call の費用を持つ。
// 利用者の操作は opName なので directHead=false。通常ソースの境界で区別する。
#[test]
fn builtin_operation_calls_count_direct_steps_but_user_operations_do_not() {
    let (_, output) = source(
        r#"effect E
 function read(path: String) -> String
end effect
function builtin(path: String) -> Unit uses File.Read
 bind r <- Scope.checkPathIn(pattern: "/a/**", path: path)
 bind text <- File.readText(path: path)
 ()
end function
function user(path: String) -> Unit uses E
 bind r <- Scope.checkPathIn(pattern: "/a/**", path: path)
 bind text <- read(path: path)
 ()
end function"#,
    );
    for (name, stopped) in [("builtin", true), ("user", false)] {
        let body = output
            .scope_inputs
            .bodies
            .iter()
            .find(|b| b.body_key.definition == format!(".{name}"))
            .unwrap();
        // Result保存3、直接呼び出し1+局所読取1。予算4は組み込みだけ超過。
        let result = body.analyze(DEFAULT_NUMBERING_OPERATIONS, limits(4, 10));
        assert_eq!(result.stopped.is_some(), stopped, "{name}");
        let last = result.records.last().unwrap();
        assert_eq!(
            last.state.locals().map(|s| s.id).collect::<Vec<_>>(),
            [2, 1, 0]
        );
        assert_eq!(
            last.state.locals().any(|s| s.fact.is_some()),
            !stopped,
            "{name}"
        );
    }
}

// 関門: 本体だけの超過からの回復と全体の超過の伝播は、同一上限の既存テストでは区別できない。
// 期待値は Run.enter/leave と rejoin から手計算する。外側の検査は2操作、内側は2操作ずつ。
#[test]
fn nested_budget_entry_and_exit_follow_run_enter_leave() {
    let (_, output) = source(
        r#"function sample(path: String) -> Unit
 bind outer <- Scope.checkPathIn(pattern: "/outer/**", path: "/outer/a")
 bind nested <- lambda() -> Unit
  bind a <- Scope.checkPathIn(pattern: "/inner/**", path: "/inner/a")
  bind b <- Scope.checkPathIn(pattern: "/inner/**", path: "/inner/b")
  bind c <- Scope.checkPathIn(pattern: "/inner/**", path: "/inner/c")
  bind d <- Scope.checkPathIn(pattern: "/inner/**", path: "/inner/d")
  ()
 end lambda
 match outer with
 case Result.Ok(p) -> bind _ <- Scope.pathInValue(p)
 case Result.Error(_) -> ()
 end match
 ()
end function"#,
    );
    let body = output
        .scope_inputs
        .bodies
        .iter()
        .find(|b| b.body_key.definition == ".sample")
        .unwrap();
    use ScopeBudgetResource as R;
    use ScopeBudgetScope as S;
    // 外側の検査2、Okの写し2、discardの射影は位置を増やさず計上しない。
    // 内側の検査は各2。本体5では3回目で超え、外側は4操作で完了する。
    for (
        body_ops,
        whole_ops,
        body_items,
        whole_items,
        inner_failure,
        stop_preorder,
        final_failure,
        projected,
    ) in [
        (5, 100, 100, 100, (S::Body, R::Operations), 13, None, true),
        (
            100,
            8,
            100,
            100,
            (S::Whole, R::Operations),
            17,
            Some((S::Whole, R::Operations)),
            false,
        ),
        (
            100,
            100,
            1,
            100,
            (S::Body, R::Items),
            9,
            Some((S::Body, R::Items)),
            false,
        ),
        (
            100,
            100,
            100,
            1,
            (S::Whole, R::Items),
            5,
            Some((S::Whole, R::Items)),
            false,
        ),
    ] {
        let result = body.analyze(
            DEFAULT_NUMBERING_OPERATIONS,
            ScopeLimits {
                body: ScopeCap {
                    operations: body_ops,
                    items: body_items,
                },
                whole: ScopeCap {
                    operations: whole_ops,
                    items: whole_items,
                },
            },
        );
        assert_eq!(result.metrics.stops.first().unwrap().0, stop_preorder);
        // 外側の match は番号22。内側だけの超過なら入口のResultの事実を一つ保つ。
        let restored = result
            .records
            .iter()
            .find(|r| r.key.surface_preorder == 22)
            .unwrap();
        assert_eq!(
            restored.state.locals().filter(|l| l.fact.is_some()).count(),
            usize::from(inner_failure.0 == S::Body)
        );
        assert_eq!(
            result.metrics.stops.first().unwrap().1,
            ScopeInputStop::BudgetExceeded {
                scope: inner_failure.0,
                resource: inner_failure.1
            }
        );
        assert_eq!(
            result.stopped,
            final_failure
                .map(|(scope, resource)| ScopeInputStop::BudgetExceeded { scope, resource })
        );
        assert_eq!(projections(&result).last().unwrap().is_some(), projected);
    }
}
