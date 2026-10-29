
#[test]
fn r20_1_method_entry_probe() {
    let directory = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r20.1");
    let source = fs::read_to_string(directory.join("method-entry.bnt")).unwrap();
    let checked = pipeline::check_text("method-entry.bnt", source.as_bytes(), CheckOptions { require_main: false, deny_warnings: false });
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let core = pipeline::desugar_checked(&p).unwrap();
    let definitions = exchange::named_definitions(&p, &core);
    let method = definitions.iter().find(|d| d["scope"]["inScope"]["surface"]["implementation"].is_string()).unwrap();
    let surface = &method["scope"]["inScope"]["surface"];
    let input = p.types.scope_inputs.bodies.iter().find(|b| b.body_key.definition.starts_with("%impl:")).unwrap();
    let (node, implementation) = p.types.impls.iter().find(|(_, i)| !i.class_constraints.is_empty()).unwrap();
    let scheme = p.types.decl_types.get(input.binding).unwrap();
    let result = json!({
        "scopeBodyKey": {"definition":input.body_key.definition,"surfacePreorder":input.body_key.surface_preorder},
        "scopeEntry": {"dictionaries":input.entry.dictionaries,"positions":input.entry.positions.iter().map(|p| p.map(|b| b.0)).collect::<Vec<_>>(),"nextId":input.entry.next_id},
        "schemeClassConstraints":scheme.class_constraints.len(),
        "schemeValueParams":scheme.params.len(),
        "implNode":node.0,"implClassConstraints":implementation.class_constraints.len(),
        "exportedMethod":method,
        "exportedDictionaryCount":surface["dictParams"].as_array().unwrap().len(),
        "exportedHeaderNames":surface["header"]["names"],
        "leanMethodInputNameCount":surface["dictParams"].as_array().unwrap().len()+surface["header"]["names"].as_array().unwrap().len(),
    });
    fs::write(directory.join("method-entry-probe.json"), serde_json::to_string_pretty(&result).unwrap()).unwrap();
    println!("{result}");
}
