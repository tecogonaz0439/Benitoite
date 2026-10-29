//! 独立実ソースと手書き契約を、既存の交換の境界から全比較へ渡す。
//! 関門: 型表だけの一致・群全体のTop退行・拒否理由の取り違えを捕まえる。
//! 本番の差し込み口は追加せず、実pipelineと既存の書き出しを使う。
use super::*;

#[test]
fn export_range_sources() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/desugar_export/range-sources");
    let expected: Value =
        serde_json::from_slice(&fs::read(root.join("expected.json")).unwrap()).unwrap();
    let output = export_directory("range-sources").join("range-sources");
    fs::create_dir_all(&output).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut observed = vec![];
    for case in expected["cases"].as_array().unwrap() {
        let name = case["name"].as_str().unwrap();
        let file = case["file"].as_str().unwrap();
        let source = fs::read(root.join(file)).unwrap();
        fs::write(output.join(file), &source).unwrap();
        let checked = pipeline::check_text(
            file,
            &source,
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        if name == "effect-top-exceeded" {
            // 契約だけをTopへ戻した同じ本体から、最後のRunの超過を独立に観測する。
            let accepted_source = String::from_utf8(source.clone())
                .unwrap()
                .replace("uses File.Read[\"/**\"]", "uses File.Read");
            let accepted = pipeline::check_text(
                file,
                accepted_source.as_bytes(),
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            assert_eq!(accepted.error_count(), 0, "{:?}", accepted.diagnostics);
            let program = accepted.program.unwrap();
            let body = program
                .types
                .scope_inputs
                .bodies
                .iter()
                .find(|body| body.body_key.definition == ".sample")
                .unwrap();
            let analysis = body.analyze_with_limits(benitoite::typeck::DEFAULT_SCOPE_LIMITS);
            assert!(analysis.input.stopped.is_none(), "numbering must complete");
            assert!(
                analysis.stopped.is_some(),
                "last Run must exceed its budget"
            );
            fs::write(output.join("effect-top-exceeded-provenance.json"),
                exchange::to_vec(&json!({"numberingComplete":true,"lastRunExceeded":true,
                    "stop":format!("{:?}",analysis.stopped),"operations":analysis.metrics.body_operations})).unwrap()).unwrap();
        }
        let codes: Vec<_> = checked
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .map(|d| format!("{:?}", d.code.unwrap()))
            .collect();
        let wanted = case.get("codes").cloned().unwrap_or_else(|| json!([]));
        assert_eq!(json!(codes), wanted, "{name}: {:?}", checked.diagnostics);
        let diagnostics: Vec<_> = checked
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .map(|d| {
                json!({
                    "code":format!("{:?}", d.code.unwrap()),"message":d.message,"notes":d.notes,
                    "primary":format!("{:?}",d.primary),"secondary":format!("{:?}",d.secondary)
                })
            })
            .collect();
        let mut required = vec![];
        let mut positions = vec![];
        let mut exported = named::Export::new();
        if let Some(p) = checked.program.as_ref() {
            for body in &p.types.scope_inputs.bodies {
                if body.body_key.definition == ".sample" || body.body_key.definition == ".classify"
                {
                    let analysis =
                        body.analyze_with_limits(benitoite::typeck::DEFAULT_SCOPE_LIMITS);
                    assert!(
                        analysis.input.stopped.is_none(),
                        "{name}: {:?}",
                        analysis.input.stopped
                    );
                    for occurrence in &analysis.input.occurrences {
                        positions.push(json!({"definition":body.body_key.definition,"surfacePreorder":occurrence.preorder,
                            "start":occurrence.span.start.0,"end":occurrence.span.end.0}));
                    }
                    for call in &analysis.input.calls {
                        required.push(json!({"definition":body.body_key.definition,"surfacePreorder":call.preorder,
                            "declaration":call.declaration.name(),"ranges":analysis.required_ranges(call).unwrap().iter().map(|row|row.iter().map(|r| exchange::scope_export::index(&benitoite::types::builtin::RangeIndex::fixed(r.index()), None)["fixed"].clone()).collect::<Vec<_>>()).collect::<Vec<_>>()}));
                    }
                }
            }
            exported.push("golden", name, p, &stdlib);
            assert_eq!(
                exported.inputs[0]["definitions"].as_array().unwrap().len(),
                usize::try_from(case["definitions"].as_u64().unwrap()).unwrap(),
                "{name}"
            );
            // 実ソース群の比較では候補欄を数に加えない。型表と実際の原子は保持する。
            exported.inputs[0]
                .as_object_mut()
                .unwrap()
                .remove("candidates");
            fs::create_dir_all(output.join(name)).unwrap();
            exported.write(&output.join(name));
            // write は既存の named-programs-* の組を使い、群と一対一にする。
        }
        observed.push(json!({"name":name,"accepted":checked.program.is_some(),"diagnostics":diagnostics,"required":required,"positions":positions}));
    }
    // 拒否の三入力を、契約だけ変えた受理する形で同じ交換境界から書き出す。
    let counterpart_root = root.join("contract-counterparts");
    let counterparts: Value =
        serde_json::from_slice(&fs::read(counterpart_root.join("expected.json")).unwrap()).unwrap();
    for case in counterparts["cases"].as_array().unwrap() {
        let name = case["name"].as_str().unwrap();
        let source = fs::read(counterpart_root.join(case["file"].as_str().unwrap())).unwrap();
        let checked = pipeline::check_text(
            name,
            &source,
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
        let mut export = named::Export::new();
        export.push("golden", name, checked.program.as_ref().unwrap(), &stdlib);
        let directory = output.join("contract-counterparts").join(name);
        fs::create_dir_all(&directory).unwrap();
        export.write(&directory);
    }
    fs::write(
        output.join("rust-observed.json"),
        exchange::to_vec(&json!(observed)).unwrap(),
    )
    .unwrap();
}
