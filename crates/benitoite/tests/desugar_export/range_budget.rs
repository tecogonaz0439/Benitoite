//! 実ソースの番号付け停止と最後の Run の超過・回復を交換境界で区別する。
// 関門: 最後の Run が回復した内側の Top を budgetExceeded とする退行と、
// 番号付け停止で接頭辞の番号やリテラルを流用する退行を捕まえる。
// 既存の局所解析単体検査は交換の出現の鍵へ届かない。公開 pipeline と
// ScopeBodyInput::analyze/accept_call を使い、本番の差し込み口は増やさない。
use super::*;
use benitoite::typeck::{
    ScopeAcceptError, ScopeCap, ScopeCoverFailure, ScopeInputStop, ScopeLimits, ScopeRequired,
};
use benitoite::types::scope::{PathKind, PathPattern, Range};

const EXPECTED: &str = include_str!("range-budget/expected.json");
const LAST_RUN: &str = include_str!("range-budget/last-run.bnt");
const RECOVERED: &str = include_str!("range-budget/recovered.bnt");

fn limit(value: &Value) -> ScopeCap {
    ScopeCap {
        operations: value["operations"].as_u64().unwrap(),
        items: value["items"].as_u64().unwrap(),
    }
}

fn range_text(range: Range) -> String {
    match range {
        Range::Top => "top".into(),
        Range::Path(path) => format!(
            "/{}{}",
            path.stem().parts().join("/"),
            match path.kind() {
                PathKind::Exact => "",
                PathKind::Tree => "/**",
            }
        ),
        Range::Host(_) | Range::Endpoint(_) => panic!("unexpected path rule range"),
    }
}

fn stop(stop: Option<ScopeInputStop>) -> Value {
    use benitoite::typeck::{ScopeBudgetResource, ScopeBudgetScope};
    match stop {
        None => Value::Null,
        Some(ScopeInputStop::NumberingLimit { .. }) => json!("numberingLimit"),
        Some(ScopeInputStop::BudgetExceeded {
            scope: ScopeBudgetScope::Body,
            resource: ScopeBudgetResource::Operations,
        }) => json!("bodyOperations"),
        other => panic!("unexpected analysis stop: {other:?}"),
    }
}

#[test]
fn export_range_budget_sources() {
    let expected: Value = serde_json::from_str(EXPECTED).unwrap();
    let root = export_directory("range-budget").join("range-budget");
    fs::create_dir_all(&root).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut manifest = Vec::new();
    for case in expected["cases"].as_array().unwrap() {
        let name = case["name"].as_str().unwrap();
        let source = match case["source"].as_str().unwrap() {
            "last-run.bnt" => LAST_RUN,
            "recovered.bnt" => RECOVERED,
            other => panic!("unknown fixed source {other}"),
        };
        let directory = root.join(name);
        fs::create_dir_all(&directory).unwrap();
        fs::write(directory.join("source.bnt"), source).unwrap();
        let checked = pipeline::check_text(
            "range-budget.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        let program = checked.program.unwrap();
        let body = program
            .types
            .scope_inputs
            .bodies
            .iter()
            .find(|body| body.body_key.definition == ".sample")
            .unwrap();
        let analysis = body.analyze(
            case["numberingOperations"].as_u64().unwrap(),
            ScopeLimits {
                body: limit(&case["limits"]["body"]),
                whole: limit(&case["limits"]["whole"]),
            },
        );
        let complete = analysis.input.stopped.is_none();
        assert_eq!(complete, case["numberingComplete"].as_bool().unwrap());
        assert_eq!(stop(analysis.stopped), case["finalStop"], "{name}");
        // metrics の停止文と、後で拒否される規則のキーは異なる。
        // 固定期待値の補助欄の不一致は観測に明記し、Required の比較へ流用しない。
        let observed_first_stop = analysis.metrics.stops.first().map(|(key, _)| *key);
        let corrected_first_stop = case
            .get("firstStopPreorderCorrection")
            .and_then(|v| v["value"].as_u64())
            .or_else(|| case["firstStopPreorder"].as_u64());
        assert_eq!(
            observed_first_stop, corrected_first_stop,
            "{name}: first stop"
        );
        // 停止後は全 raw 規則を検査し、取得済みの接頭辞だけを対象にしない。
        let calls = if complete {
            analysis.input.calls.clone()
        } else {
            body.rule_calls()
        };
        assert_eq!(
            calls.len(),
            case["calls"].as_array().unwrap().len(),
            "{name}"
        );
        let mut rows = Vec::new();
        for call in &calls {
            let requirements = analysis.required_ranges(call).unwrap();
            assert_eq!(requirements.len(), 1, "{name}: {requirements:?}");
            assert_eq!(requirements[0].len(), 1);
            let requirement = &requirements[0][0];
            let kind = match requirement {
                ScopeRequired::Known(_) => "known",
                ScopeRequired::Unknown => "unknown",
                ScopeRequired::Exceeded => "exceeded",
            };
            let required = range_text(requirement.index());
            let contract = match requirement {
                ScopeRequired::Known(range) => range.clone(),
                ScopeRequired::Unknown | ScopeRequired::Exceeded => {
                    Range::Path(PathPattern::parse("/data/**").unwrap())
                }
            };
            let reason = match analysis.accept_call(call, &[contract]) {
                Ok(()) => Value::Null,
                Err(ScopeAcceptError::Rejected(rejected)) => {
                    assert_eq!(rejected.definition, ".sample");
                    assert_eq!(rejected.preorder, complete.then_some(call.preorder));
                    json!(match rejected.reason {
                        ScopeCoverFailure::NotCovered => "notCovered",
                        ScopeCoverFailure::UnknownSource => "unknownSource",
                        ScopeCoverFailure::BudgetExceeded => "budgetExceeded",
                    })
                }
                Err(ScopeAcceptError::InputStopped(stop)) => panic!("{name}: {stop:?}"),
            };
            // Top は予算や由来によらず受理する。
            assert!(analysis.accept_call(call, &[Range::Top]).is_ok());
            rows.push(json!({
                "rule":call.declaration.name(), "preorder":complete.then_some(call.preorder),
                "required":required, "kind":kind, "reason":reason
            }));
        }
        assert_eq!(json!(rows), case["calls"], "{name}");
        let report = json!({
            "name":name, "numberingComplete":complete, "finalStop":stop(analysis.stopped),
            "calls":rows, "records":analysis.records.iter().map(|r| r.key.surface_preorder).collect::<Vec<_>>(),
            "stops":analysis.metrics.stops.iter().map(|(key,s)| json!({"preorder":key,"reason":stop(Some(*s))})).collect::<Vec<_>>(),
            "auxiliaryFirstStopExpected":case["firstStopPreorder"],
            "auxiliaryFirstStopActual":observed_first_stop,
            "auxiliaryFirstStopMatches":case.get("firstStopPreorder").is_none_or(|v| v.as_u64() == observed_first_stop)
        });
        fs::write(
            directory.join("rust.json"),
            exchange::to_vec(&report).unwrap(),
        )
        .unwrap();
        if complete {
            let core = pipeline::desugar_checked(&program).unwrap();
            assert!(benitoite::ir::check::check_program(&core).is_empty());
            let definitions = exchange::named_definitions(&program, &core);
            assert_eq!(definitions.len(), 1, "{name}");
            assert!(definitions[0]["scope"].get("inScope").is_some(), "{name}");
            let mut input = named::input(name, definitions);
            let table = exchange::named_builtin_tables(&program, &input, &stdlib);
            exchange::attach_metadata(&mut input, &table, &mut Value::Null);
            input["scopeAcceptance"]["limits"] = case["limits"].clone();
            let corpus = json!({"version":15,"operators":exchange::operators(),"inputs":[input],"annotations":{"tailMatch":[0,0]}});
            fs::write(
                directory.join("corpus.json"),
                exchange::to_vec(&corpus).unwrap(),
            )
            .unwrap();
            fs::write(
                directory.join("builtins.json"),
                exchange::to_vec(&json!({"version":7,"inputs":[table]})).unwrap(),
            )
            .unwrap();
            fs::write(directory.join("stdlib.json"), exchange::to_vec(&json!({"version":7,"inputs":[{"group":"golden","name":name,"functions":[],"impls":[]}]})).unwrap()).unwrap();
        }
        manifest.push(json!({"name":name,"source":case["source"],"rustCalls":calls.len(),"numberingComplete":complete,"lean":case["lean"]["comparison"]}));
    }
    fs::write(
        root.join("manifest.json"),
        exchange::to_vec(&json!({"version":1,"inputs":manifest})).unwrap(),
    )
    .unwrap();
    fs::write(root.join("expected.json"), EXPECTED).unwrap();
}
