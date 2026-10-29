//! 署名と表のデータを手書きの独立入力と照合する（設計書 07-04「交換の形式の版」）。
use super::exchange::{
    Surface, builtin_export, complete_stdlib, named_builtin_tables, scope_export, to_vec,
};
use benitoite::base::BindingId;
use benitoite::builtins;
use benitoite::types::builtin::BuiltinTypeId;
use benitoite::types::builtin::{BuiltinEffectId, RangeIndex};
use benitoite::types::scope::Kind;
use benitoite::types::signature::{IoShape, RangeAdmission, RangeSignature};
use benitoite::types::{EffectName, EffectSet, Scheme, Ty, TyCon};
use serde_json::{Value, json};
use std::collections::BTreeSet;

// 関門: 交換境界で範囲変数・種類・形・許容の向きを守る。旧 Top だけのテストでは、
// rvar の消失、inner/outer の逆転、未使用操作の脱落を捕まえられない。
// 本番の差し込み口は増やさず、通常の書き出しと同じ関数を呼ぶ。
const EXPECTED: &str = include_str!("scope-tables-expected.json");

// 関門: 脱糖の読者が見る corpus の候補に、署名だけの固定原子と呼び出しの
// 具体化原子を欠かさず含める契約を守る。旧テストの型・項だけでは候補の欠落を検出できない。
// 手書きの交換入力と独立期待値を使い、署名の rvar の漏れと、別の範囲での具体化も検出する。
// 本番の公開範囲やテスト用の差し込み口は増やさない。
#[test]
fn exports_closed_candidate_atoms_from_signatures_and_calls() {
    let input = json!({
        "definitions":[{
            "header":{"eff":[{"name":{"value":"Console.Write","ix":{"fixed":"top"}}},{"rho":{"index":2}}]},
            "body":[
                {"primName":{"name":"File.writeTextIn","ranges":[{"path":{"tree":["data"]}}]}},
                {"prim":{"name":"File.writeTextIn","ranges":["top"]}},
                {"primName":{"name":"Http.sendIn","ranges":[{"endpoint":{"host":{"name":{"exact":["example","api"]}},"ports":{"lo":443,"hi":443}}}]}}
            ]
        }]
    });
    let table = json!({
        "effKinds":[{"name":"IO.File.Write","kind":"path"},{"name":"Network.Http.Connect","kind":"endpoint"}],
        "prims":[
            {"name":"File.writeTextIn","rkinds":["path"],"eff":[{"name":{"value":"IO.File.Write","ix":{"rvar":0}}}]},
            {"name":"Http.sendIn","rkinds":["endpoint"],"eff":[{"name":{"value":"Network.Http.Connect","ix":{"rvar":0}}}]},
            {"name":"fixedOnly","rkinds":[],"params":[{"fn":{"eff":[{"name":{"value":"IO.File.Read","ix":{"fixed":{"path":{"exact":["readme"]}}}}}]}}]}
        ]
    });
    let candidates = builtin_export::candidate_atoms(&input, &table);
    let expected = json!([
        {"name":{"value":"Console.Write","ix":{"fixed":"top"}}},
        {"rho":{"index":2}},
        {"name":{"value":"IO.File.Write","ix":{"fixed":{"path":{"tree":["data"]}}}}},
        {"name":{"value":"IO.File.Write","ix":{"fixed":"top"}}},
        {"name":{"value":"Network.Http.Connect","ix":{"fixed":{"endpoint":{"host":{"name":{"exact":["example","api"]}},"ports":{"lo":443,"hi":443}}}}}},
        {"name":{"value":"IO.File.Read","ix":{"fixed":{"path":{"exact":["readme"]}}}}}
    ]);
    let actual = candidates.as_array().unwrap();
    let expected = expected.as_array().unwrap();
    assert_eq!(actual.len(), expected.len(), "{candidates}");
    for atom in expected {
        assert!(
            actual.contains(atom),
            "missing candidate {atom}: {candidates}"
        );
    }
    assert!(!super::contains_json(&candidates, &json!({"rvar":0})));
}

// 関門: 合成した署名の検査では、標準宣言から rvar を登録する経路の欠落や、
// 通常ソースを対象外へ戻す退行を捕まえられない。項側の型は閉じたまま保つ。
#[test]
fn exports_used_path_checks_with_range_variables_only_in_signatures() {
    let checked = benitoite::pipeline::check_text(
        "path-in-export.bnt",
        br#"import Benitoite.Unofficial.Scope
function roundTrip(pattern: String, raw: String) -> String
  bind result <- Scope.checkPathIn(pattern: pattern, path: raw)
  return match result with
    case Result.Ok(path) -> Scope.pathInValue(path: path)
    case Result.Error(_) -> "outside"
  end match
end function
"#,
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let core = benitoite::pipeline::desugar_checked(&p).unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());
    let definitions = super::exchange::named_definitions(&p, &core);
    assert_eq!(definitions.len(), 1);
    assert!(
        definitions[0]["scope"].get("inScope").is_some(),
        "{definitions:?}"
    );
    let mut input = super::named::input("path-in", definitions);
    let table = named_builtin_tables(&p, &input, &complete_stdlib());
    let path =
        json!({"opaque":{"name":format!("{}:[]", BuiltinTypeId::PATH_IN.0),"ix":{"rvar":0}}});
    for (name, names) in [
        ("Scope.checkPathIn", vec!["pattern", "path"]),
        ("Scope.pathInValue", vec!["path"]),
    ] {
        let signature = table["prims"]
            .as_array()
            .unwrap()
            .iter()
            .find(|p| p["name"] == name)
            .unwrap();
        assert_eq!(signature["rkinds"], json!(["path"]));
        assert_eq!(signature["names"], json!(names));
        assert_eq!(signature["kind"], "pure");
        assert_eq!(signature["eff"], json!([]));
        assert_eq!(signature["shape"], "untargeted");
        if name == "Scope.checkPathIn" {
            assert_eq!(signature["ret"]["data"]["args"][0], path);
        } else {
            assert_eq!(signature["params"], json!([path]));
        }
    }
    super::exchange::attach_metadata(&mut input, &table, &mut Value::Null);
    // Surface と Core の通常の型の書き出しは署名の文脈を持たず、rvar を拒否する。
    assert!(!super::contains_json(
        &input["definitions"],
        &json!({"rvar":0})
    ));
    assert!(super::contains_json(
        &input["definitions"],
        &json!({"fixed":"top"})
    ));
    let output = super::export_directory("path-in");
    let corpus = json!({"version":15,"operators":super::exchange::operators(),
        "inputs":[input],"annotations":{"tailMatch":[0,0]}});
    std::fs::write(output.join("path-in-corpus.json"), to_vec(&corpus).unwrap()).unwrap();
    super::named::write_tables(&output, "path-in", &p, &corpus["inputs"][0]);
}

// 関門: Lean の読者が検査しない内容の data 名と二署名の一致を交換境界で守る。
// 既存の合成入力は実 ClientRequest の束縛の番号・五欄・通常ソースの対象内を確かめない。
// 期待する型は宣言の名前から直接組み、Surface::ty や data_name で算出し直さない。
#[test]
fn exports_request_content_as_the_same_record_type_in_declarations_and_signatures() {
    let checked = benitoite::pipeline::check_text(
        "request-in-export.bnt",
        br#"import Benitoite.Unofficial.Network.Http
function roundTrip(pattern: String, minimum: Integer, maximum: Integer, raw: Http.ClientRequest) -> String
  bind result <- Http.checkRequestIn(hostPattern: pattern, minimumPort: minimum, maximumPort: maximum, request: raw)
  return match result with
    case Result.Ok(request) -> Http.ClientRequest.url(Http.requestInValue(request: request))
    case Result.Error(_) -> "outside"
  end match
end function
"#,
        benitoite::pipeline::CheckOptions { require_main: false, deny_warnings: false },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let core = benitoite::pipeline::desugar_checked(&p).unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());
    let definitions = super::exchange::named_definitions(&p, &core);
    assert_eq!(definitions.len(), 1);
    assert!(
        definitions[0]["scope"].get("inScope").is_some(),
        "{definitions:?}"
    );
    let mut input = super::named::input("request-in", definitions);
    let table = named_builtin_tables(&p, &input, &complete_stdlib());
    let data = table["dataDecls"].as_array().unwrap();
    let record = data
        .iter()
        .find(|d| d["typeName"] == "ClientRequest")
        .unwrap();
    let pair = data.iter().find(|d| d["typeName"] == "Pair").unwrap();
    assert!(record["name"].as_str().unwrap().starts_with("data:"));
    assert_eq!(record["isRecord"], true);
    assert_eq!(record["ntys"], 0);
    assert_eq!(record["ctors"].as_array().unwrap().len(), 1);
    assert_eq!(record["ctors"][0]["constructorName"], "ClientRequest");
    assert_eq!(
        record["ctors"][0]["fields"],
        json!(["method", "url", "headers", "body", "timeoutMilliseconds"])
    );
    let string = json!({"base":{"name":"String"}});
    assert_eq!(
        record["ctors"][0]["args"],
        json!([
            string, string,
            {"list":{"elem":{"data":{"name":pair["name"],"args":[string,string]}}}},
            "bytes", {"base":{"name":"Integer"}}
        ])
    );
    let content = json!({"data":{"name":record["name"],"args":[]}});
    assert_eq!(
        table["valContents"],
        json!([{"name":"33:[]","content":content}])
    );
    for name in ["Http.checkRequestIn", "Http.requestInValue"] {
        let signature = table["prims"]
            .as_array()
            .unwrap()
            .iter()
            .find(|s| s["name"] == name)
            .unwrap();
        assert_eq!(signature["rkinds"], json!(["endpoint"]));
        assert_eq!(signature["kind"], "pure");
        assert_eq!(signature["eff"], json!([]));
        if name == "Http.checkRequestIn" {
            assert_eq!(signature["params"][3], content);
            assert_eq!(
                signature["ret"]["data"]["args"][0],
                json!({"opaque":{"name":"33:[]","ix":{"rvar":0}}})
            );
        } else {
            assert_eq!(signature["ret"], content);
            assert_eq!(
                signature["params"],
                json!([{"opaque":{"name":"33:[]","ix":{"rvar":0}}}])
            );
        }
    }
    super::exchange::attach_metadata(&mut input, &table, &mut Value::Null);
    assert!(!super::contains_json(
        &input["definitions"],
        &json!({"rvar":0})
    ));
    let output = super::export_directory("request-in");
    let corpus = json!({"version":15,"operators":super::exchange::operators(),"inputs":[input],"annotations":{"tailMatch":[0,0]}});
    std::fs::write(
        output.join("request-in-corpus.json"),
        to_vec(&corpus).unwrap(),
    )
    .unwrap();
    super::named::write_tables(&output, "request-in", &p, &corpus["inputs"][0]);
}

fn builtin(id: BuiltinTypeId) -> Ty {
    Ty::Con(TyCon::Builtin(id), vec![], RangeIndex::TOP)
}
fn variable(id: BuiltinTypeId, index: u32) -> Ty {
    Ty::Con(TyCon::Builtin(id), vec![], RangeIndex::var(index))
}
fn result(ok: Ty, error: Ty) -> Ty {
    Ty::Con(
        TyCon::Adt(BindingId(1001)),
        vec![ok, error],
        RangeIndex::TOP,
    )
}
fn scheme(names: &[&str], params: Vec<Ty>, ret: Ty, effects: EffectSet) -> Scheme {
    Scheme {
        param_names: names.iter().map(|n| (*n).into()).collect(),
        type_params: vec![],
        effect_params: vec![],
        no_fail: vec![],
        class_constraints: vec![],
        params,
        ret,
        effects,
        wrote_io_all: false,
    }
}

type SignatureFixture = (
    String,
    Scheme,
    RangeSignature,
    &'static str,
    Option<&'static str>,
);

fn fixtures() -> Vec<SignatureFixture> {
    let string = builtin(BuiltinTypeId::STRING);
    let integer = builtin(BuiltinTypeId::INTEGER);
    let unit = builtin(BuiltinTypeId::UNIT);
    let bytes = builtin(BuiltinTypeId::BYTES);
    let path = variable(BuiltinTypeId::PATH_IN, 0);
    let request = variable(BuiltinTypeId::REQUEST_IN, 0);
    let error = builtin(BuiltinTypeId::IO_ERROR);
    // L40.3c と同じ五欄のレコードを、合成入力の data 宣言として保持する。
    let content = Ty::Con(TyCon::Adt(BindingId(1003)), vec![], RangeIndex::TOP);
    let path_ranges = RangeSignature {
        kinds: vec![Kind::Path],
        ..RangeSignature::default()
    };
    let endpoint_ranges = RangeSignature {
        kinds: vec![Kind::Endpoint],
        ..RangeSignature::default()
    };
    let mut entries = vec![
        (
            "Scope.checkPathIn".into(),
            scheme(
                &["pattern", "path"],
                vec![string.clone(), string.clone()],
                result(path.clone(), error.clone()),
                EffectSet::empty(),
            ),
            path_ranges.clone(),
            "pure",
            None,
        ),
        (
            "File.writeTextIn".into(),
            scheme(
                &["path", "text"],
                vec![path.clone(), string.clone()],
                result(unit.clone(), error.clone()),
                EffectSet {
                    names: vec![EffectName::Builtin(
                        BuiltinEffectId::FILE_WRITE,
                        RangeIndex::var(0),
                    )],
                    vars: vec![],
                    failures: vec![],
                },
            ),
            RangeSignature {
                kinds: vec![Kind::Path],
                admission: RangeAdmission::Any,
                shape: IoShape::Single {
                    kind: Kind::Path,
                    position: 0,
                },
            },
            "io",
            Some("IO.File.Write"),
        ),
        (
            "Http.checkRequestIn".into(),
            scheme(
                &["hostPattern", "minimumPort", "maximumPort", "request"],
                vec![string.clone(), integer.clone(), integer, content.clone()],
                result(
                    request.clone(),
                    Ty::Con(TyCon::Adt(BindingId(1002)), vec![], RangeIndex::TOP),
                ),
                EffectSet::empty(),
            ),
            endpoint_ranges.clone(),
            "pure",
            None,
        ),
    ];
    for (name, extra, ret, effect) in [
        (
            "File.readTextIn",
            None,
            string.clone(),
            BuiltinEffectId::FILE_READ,
        ),
        (
            "File.readBytesIn",
            None,
            bytes.clone(),
            BuiltinEffectId::FILE_READ,
        ),
        (
            "File.appendTextIn",
            Some(("text", string.clone())),
            unit.clone(),
            BuiltinEffectId::FILE_WRITE,
        ),
        (
            "File.writeBytesIn",
            Some(("content", bytes.clone())),
            unit.clone(),
            BuiltinEffectId::FILE_WRITE,
        ),
        (
            "File.appendBytesIn",
            Some(("content", bytes)),
            unit,
            BuiltinEffectId::FILE_WRITE,
        ),
        (
            "Http.sendIn",
            None,
            string.clone(),
            BuiltinEffectId::HTTP_CONNECT,
        ),
    ] {
        let endpoint = effect == BuiltinEffectId::HTTP_CONNECT;
        let kind = if endpoint { Kind::Endpoint } else { Kind::Path };
        let mut names = vec![if endpoint { "request" } else { "path" }];
        let mut params = vec![if endpoint {
            request.clone()
        } else {
            path.clone()
        }];
        if let Some((name, ty)) = extra {
            names.push(name);
            params.push(ty);
        }
        let op_eff = if endpoint {
            "Network.Http.Connect"
        } else if effect == BuiltinEffectId::FILE_READ {
            "IO.File.Read"
        } else {
            "IO.File.Write"
        };
        entries.push((
            name.into(),
            scheme(
                &names,
                params,
                result(ret, error.clone()),
                EffectSet {
                    names: vec![EffectName::Builtin(effect, RangeIndex::var(0))],
                    vars: vec![],
                    failures: vec![],
                },
            ),
            RangeSignature {
                kinds: vec![kind],
                admission: RangeAdmission::Any,
                shape: IoShape::Single { kind, position: 0 },
            },
            "io",
            Some(op_eff),
        ));
    }
    entries.push((
        "Scope.pathInValue".into(),
        scheme(&["path"], vec![path.clone()], string, EffectSet::empty()),
        path_ranges,
        "pure",
        None,
    ));
    entries.push((
        "Http.requestInValue".into(),
        scheme(
            &["request"],
            vec![request.clone()],
            content,
            EffectSet::empty(),
        ),
        endpoint_ranges,
        "pure",
        None,
    ));
    for (name, param_name, param, id, kind) in [
        (
            "Scope.widenPathIn",
            "path",
            path,
            BuiltinTypeId::PATH_IN,
            Kind::Path,
        ),
        (
            "Http.widenRequestIn",
            "request",
            request,
            BuiltinTypeId::REQUEST_IN,
            Kind::Endpoint,
        ),
    ] {
        entries.push((
            name.into(),
            scheme(
                &[param_name],
                vec![param],
                variable(id, 1),
                EffectSet::empty(),
            ),
            RangeSignature {
                kinds: vec![kind, kind],
                admission: RangeAdmission::Covers { inner: 0, outer: 1 },
                shape: IoShape::Untargeted,
            },
            "pure",
            None,
        ));
    }
    entries
}

fn opaque(name: &str, range: &Value) -> Value {
    json!({"opaque":{"name":name,"ix":{"fixed":range}}})
}
fn header(param: Value, ret: Value, name: &str) -> Value {
    json!({"tparams":[],"neffs":0,"effParams":[],"names":[name],"params":[param],"ret":ret,"eff":[]})
}
fn widen_definition(
    key: u32,
    prim: &str,
    ty: &str,
    param_name: &str,
    inner: Value,
    outer: Value,
) -> Value {
    let ret = opaque(ty, &outer);
    let header = header(opaque(ty, &inner), ret.clone(), param_name);
    let ranges = json!([inner, outer]);
    let surface = json!({"last":{"expr":{"returnE":{"ret":ret,"inner":{"call":{
        "callee":{"primName":{"name":prim,"tys":[],"effs":[],"ranges":ranges}},
        "labels":[param_name],"positions":[0],"args":[{"local":{"index":0}}]}}}}}});
    let core = json!({"letIn":{"bound":{"ret":{"value":{"var":{"index":0}}}},"body":{
        "app":{"callee":{"prim":{"name":prim,"tys":[],"effs":[],"ranges":ranges}},"args":[{"var":{"index":0}}]}}}});
    json!({"name":format!("widen{key} (fn:{key})"),"scope":{"inScope":{
        "surface":{"header":header,"body":surface,"dictParams":[],"implementation":null,"method":null,"supers":[],"coverageView":[],"package":"author"},
        "core":{"header":header,"body":core,"lambdaEffects":[],"supers":[]}}}})
}

/// 手書きの独立期待値と通常の書き出しを照合し、局所比較専用の完全な入力を書く。
pub fn scope_tables_smoke(output: &std::path::Path) {
    let expected: Value = serde_json::from_str(EXPECTED).unwrap();
    let checked = benitoite::pipeline::check_text(
        "scope-tables.bnt",
        b"",
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let mut surface = Surface::new(&p, None, vec![]);
    let entries = fixtures();
    let prims: Vec<_> = entries
        .iter()
        .map(|(name, scheme, ranges, kind, op_eff)| {
            builtin_export::export_prim(&mut surface, name, scheme, ranges, kind, *op_eff)
        })
        .collect();
    assert_eq!(
        json!(prims),
        expected["prims"],
        "independent signature fixture"
    );
    let ranges: Vec<_> = entries
        .iter()
        .map(|(name, _, ranges, _, _)| (name.clone(), ranges.clone()))
        .collect();
    let tables = scope_export::table_data(&ranges, json!({"data":{"name":"data:1003","args":[]}}));
    assert_eq!(tables, expected["tables"], "independent table fixture");
    assert!(surface.outside.is_empty());
    let definitions = vec![
        widen_definition(
            1,
            "Scope.widenPathIn",
            "32:[]",
            "path",
            json!({"path":{"tree":["data","a"]}}),
            json!({"path":{"tree":["data"]}}),
        ),
        widen_definition(
            2,
            "Http.widenRequestIn",
            "33:[]",
            "request",
            json!({"endpoint":{"host":{"name":{"exact":["api","example","com"]}},"ports":{"lo":443,"hi":443}}}),
            json!({"endpoint":{"host":{"name":{"exact":["api","example","com"]}},"ports":{"lo":443,"hi":444}}}),
        ),
    ];
    let corpus = json!({"version":15,"operators":[],"annotations":{"tailMatch":[0,0]},"inputs":[{
        "group":"golden","name":"scope-tables","excluded":[],"definitions":definitions,"dataTypes":expected["dataTypes"],"constants":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[],
        "scopeAcceptance":{"patterns":[],"hosts":[],"limits":{"body":{"operations":1000,"items":1000},"whole":{"operations":10000,"items":10000}}}}]});
    let mut table = json!({"group":"golden","name":"scope-tables","prims":prims,
        "effects":[{"name":"State","ops":[]},{"name":"IO.File.Read","ops":["File.readTextIn","File.readBytesIn"]},{"name":"IO.File.Write","ops":["File.writeTextIn","File.appendTextIn","File.writeBytesIn","File.appendBytesIn"]},{"name":"Network.Http.Connect","ops":["Http.sendIn"]}],
        "resources":[],"dataDecls":expected["dataDecls"],"summaries":expected["summaries"],"statePure":[],"supplementalData":[],"supplementalPrims":[]});
    for (key, value) in tables.as_object().unwrap() {
        table[key] = value.clone();
    }
    for (filename, data) in [
        ("scope-tables-corpus.json", corpus),
        (
            "scope-tables-builtins.json",
            json!({"version":7,"inputs":[table]}),
        ),
        ("scope-tables-expected.json", expected),
    ] {
        std::fs::write(output.join(filename), to_vec(&data).unwrap()).unwrap();
    }
}

#[test]
fn rejects_range_variables_outside_signatures_and_invalid_signature_indices() {
    let checked = benitoite::pipeline::check_text(
        "scope-boundary.bnt",
        b"",
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0);
    let p = checked.program.unwrap();
    let term_type = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        Surface::new(&p, None, vec![]).ty(&variable(BuiltinTypeId::PATH_IN, 0))
    }));
    assert!(term_type.is_err(), "term type must reject rvar");
    let term_effect = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        Surface::new(&p, None, vec![]).eff(&EffectSet {
            names: vec![EffectName::Builtin(
                BuiltinEffectId::FILE_WRITE,
                RangeIndex::var(0),
            )],
            vars: vec![],
            failures: vec![],
        })
    }));
    assert!(term_effect.is_err(), "term effect must reject rvar");
    let source = fixtures();
    for (label, mut declaration, ranges) in [
        ("out-of-bounds", source[0].1.clone(), source[0].2.clone()),
        (
            "wrong-kind",
            source[0].1.clone(),
            RangeSignature {
                kinds: vec![Kind::Endpoint],
                ..RangeSignature::default()
            },
        ),
    ] {
        if label == "out-of-bounds" {
            declaration.ret = variable(BuiltinTypeId::PATH_IN, 1);
        }
        let rejected = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            builtin_export::export_prim(
                &mut Surface::new(&p, None, vec![]),
                label,
                &declaration,
                &ranges,
                "pure",
                None,
            )
        }));
        assert!(rejected.is_err(), "{label}");
    }
}

#[test]
fn exports_closed_type_and_atom_indices_without_losing_ip_precision() {
    use benitoite::types::scope::{
        EndpointPattern, HostPattern, PathPattern, Port, PortRange, Range,
    };

    // 関門: メモリ上の範囲から交換の最終バイト列までを確かめる。F-table の手書きの項では
    // 固定添字の脱落や IPv6 の丸め・文字列化を検出できない。期待値の根拠は results に記す。
    let checked = benitoite::pipeline::check_text(
        "closed-indices.bnt",
        b"",
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0);
    let p = checked.program.unwrap();
    let endpoint = |text| {
        Range::Endpoint(EndpointPattern {
            host: HostPattern::parse(text).unwrap(),
            ports: PortRange::new(Port::new(443), Port::new(443)).unwrap(),
        })
    };
    for (range, ty, effect, expected) in [
        (
            Range::Path(PathPattern::parse("/data/**").unwrap()),
            BuiltinTypeId::PATH_IN,
            BuiltinEffectId::FILE_WRITE,
            r#"{"path":{"tree":["data"]}}"#,
        ),
        (
            endpoint("api.example.com"),
            BuiltinTypeId::REQUEST_IN,
            BuiltinEffectId::HTTP_CONNECT,
            r#"{"endpoint":{"host":{"name":{"exact":["api","example","com"]}},"ports":{"hi":443,"lo":443}}}"#,
        ),
        (
            endpoint("192.168.1.0/24"),
            BuiltinTypeId::REQUEST_IN,
            BuiltinEffectId::HTTP_CONNECT,
            r#"{"endpoint":{"host":{"ip":{"cidr":{"family":"v4","network":3232235776,"prefixLen":24}}},"ports":{"hi":443,"lo":443}}}"#,
        ),
        (
            endpoint("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"),
            BuiltinTypeId::REQUEST_IN,
            BuiltinEffectId::HTTP_CONNECT,
            r#"{"endpoint":{"host":{"ip":{"exact":{"bits":340282366920938463463374607431768211455,"family":"v6"}}},"ports":{"hi":443,"lo":443}}}"#,
        ),
        (
            endpoint("8000::/1"),
            BuiltinTypeId::REQUEST_IN,
            BuiltinEffectId::HTTP_CONNECT,
            r#"{"endpoint":{"host":{"ip":{"cidr":{"family":"v6","network":170141183460469231731687303715884105728,"prefixLen":1}}},"ports":{"hi":443,"lo":443}}}"#,
        ),
    ] {
        let ix = RangeIndex::fixed(range);
        let mut surface = Surface::new(&p, None, vec![]);
        let actual = json!({
            "ty":surface.ty(&Ty::Con(TyCon::Builtin(ty),vec![],ix.clone())),
            "eff":surface.eff(&EffectSet{names:vec![EffectName::Builtin(effect,ix)],vars:vec![],failures:vec![]})
        });
        let (type_name, effect_name) = if ty == BuiltinTypeId::PATH_IN {
            ("32:[]", "IO.File.Write")
        } else {
            ("33:[]", "Network.Http.Connect")
        };
        let expected = format!(
            r#"{{"eff":[{{"name":{{"ix":{{"fixed":{expected}}},"value":"{effect_name}"}}}}],"ty":{{"opaque":{{"ix":{{"fixed":{expected}}},"name":"{type_name}"}}}}}}"#
        );
        assert_eq!(
            String::from_utf8(to_vec(&actual).unwrap()).unwrap(),
            expected
        );
    }
}

#[test]
fn exports_all_unused_operations_from_complete_stdlib() {
    let checked = benitoite::pipeline::check_text(
        "unused-operations.bnt",
        b"",
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0);
    let p = checked.program.unwrap();
    let stdlib = complete_stdlib();
    let input = json!({"group":"golden","name":"unused-operations","definitions":[]});
    let table = named_builtin_tables(&p, &input, &stdlib);
    assert_eq!(table["valContents"].as_array().unwrap().len(), 1);
    assert!(
        table["valContents"][0]["content"]["data"]["name"]
            .as_str()
            .unwrap()
            .starts_with("data:")
    );
    let signatures: BTreeSet<_> = table["prims"]
        .as_array()
        .unwrap()
        .iter()
        .map(|p| p["name"].as_str().unwrap())
        .collect();
    // 期待する集合は全標準入力の解決結果から得る。書き出し側の使用判定や補充処理は使わない。
    let operations: BTreeSet<_> = stdlib
        .resolved
        .builtin_ops
        .iter()
        .map(|(_, id)| builtins::builtin_decl(*id).unwrap().name)
        .collect();
    assert!(!operations.is_empty());
    assert_eq!(signatures, operations);
    // Prelude の操作は空ソースにも現れる。未 import の操作が別にあることを確かめる。
    let imported: BTreeSet<_> = p
        .resolved
        .builtin_ops
        .iter()
        .map(|(_, id)| builtins::builtin_decl(*id).unwrap().name)
        .collect();
    let missing: BTreeSet<_> = operations.difference(&imported).copied().collect();
    assert!(!missing.is_empty());
    let supplemental: BTreeSet<_> = table["supplementalPrims"]
        .as_array()
        .unwrap()
        .iter()
        .map(|n| n.as_str().unwrap())
        .collect();
    assert_eq!(supplemental, missing);
    for name in [
        "Benitoite.IO.File.readBytes",
        "Benitoite.IO.File.writeBytes",
        "Benitoite.Network.Http.send",
    ] {
        assert!(
            signatures.contains(name),
            "missing unused operation: {name}"
        );
    }
}

// 関門: 型の添字だけが残り、primName/prim の列が Top または空へ戻る交換の退行を捕まえる。
// 範囲の期待値は実装の解析器から作らず、交換の形式で独立に書く。
#[test]
fn exports_the_same_non_top_call_ranges_before_and_after_desugaring() {
    let checked = benitoite::pipeline::check_text(
        "path-ranges-export.bnt",
        br#"import Benitoite.Unofficial.Scope
function check() -> Unit
  bind result <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
  ()
end function
"#,
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let program = checked.program.unwrap();
    let core = benitoite::pipeline::desugar_checked(&program).unwrap();
    let definitions = super::exchange::named_definitions(&program, &core);
    fn columns(value: &Value, tag: &str, found: &mut Vec<Value>) {
        match value {
            Value::Object(object) => {
                if let Some(call) = object.get(tag)
                    && call["name"] == "Scope.checkPathIn"
                {
                    found.push(call["ranges"].clone());
                }
                object.values().for_each(|child| columns(child, tag, found));
            }
            Value::Array(array) => array.iter().for_each(|child| columns(child, tag, found)),
            Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {}
        }
    }
    let definition = &definitions[0]["scope"]["inScope"];
    for (stage, tag) in [("surface", "primName"), ("core", "prim")] {
        let mut found = vec![];
        columns(&definition[stage], tag, &mut found);
        assert_eq!(found, vec![json!([{"path":{"tree":["data"]}}])], "{stage}");
    }
}

mod atom_order_tests {
    use super::super::exchange::{Surface, scope_export};
    use benitoite::base::BindingId;
    use benitoite::types::builtin::{BuiltinEffectId, RangeIndex};
    use benitoite::types::scope::{
        EndpointPattern, HostPattern, PathPattern, Port, PortRange, Range,
    };
    use benitoite::types::{EffVar, EffectName, EffectSet};
    use serde_json::{Value, json};

    // 関門: 交換の原子列が Lean の符号順になる契約を守る。derive 順では
    // tree /a と exact /b、IP の族と値、名前と rho が逆になる。旧 Top だけの
    // 検査では捕まらないため、この境界の一件に独立の期待順をまとめる。
    #[test]
    fn exports_effect_atoms_in_lean_code_order() {
        let checked = benitoite::pipeline::check_text(
            "atom-order.bnt",
            b"",
            benitoite::pipeline::CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let p = checked.program.unwrap();
        let mut surface = Surface::new(&p, None, vec![]);
        let path_rows: Vec<_> = ["/b", "/a/**", "/ab", "/ba", "/あ/x"]
            .into_iter()
            .map(|path| {
                EffectName::Builtin(
                    BuiltinEffectId::FILE_READ,
                    RangeIndex::fixed(Range::Path(PathPattern::parse(path).unwrap())),
                )
            })
            .collect();
        let endpoint_rows: Vec<_> = [
            "0.0.0.1",
            "::1",
            "0.0.0.2",
            "0.0.0.0/1",
            "::/1",
            "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
            "8000::/1",
            "a",
            "*.a",
            "**.a",
            "b",
        ]
        .into_iter()
        .map(|host| {
            EffectName::Builtin(
                BuiltinEffectId::HTTP_CONNECT,
                RangeIndex::fixed(Range::Endpoint(EndpointPattern {
                    host: HostPattern::parse(host).unwrap(),
                    ports: PortRange::new(Port::new(1), Port::new(2)).unwrap(),
                })),
            )
        })
        .collect();
        // 順は Order/Range.lean の数式から独立に固定したもの。基数の低い桁が
        // 文字列の先頭なので /ba は /ab より先であり、辞書式の比較とも違う。
        for (rows, order) in [
            (path_rows, vec![1, 0, 4, 3, 2]),
            (endpoint_rows, vec![0, 3, 2, 1, 4, 7, 8, 9, 10, 5, 6]),
        ] {
            let expected: Vec<Value> = order.into_iter().map(|i| {
                let EffectName::Builtin(id, ix) = &rows[i] else { unreachable!() };
                json!({"name":{"value":scope_export::effect_name(*id),"ix":scope_export::index(ix, None)}})
            }).collect();
            let mut effects = EffectSet::empty();
            for row in rows {
                effects.insert_name(row);
            }
            assert_eq!(surface.eff(&effects), json!(expected));
        }
        let mut effects = EffectSet::empty();
        for id in [
            BuiltinEffectId::HTTP_CONNECT,
            BuiltinEffectId::FILE_WRITE,
            BuiltinEffectId::FILE_READ,
            BuiltinEffectId::STATE,
        ] {
            effects.insert_name(EffectName::Builtin(id, RangeIndex::TOP));
        }
        for id in [42, 1] {
            effects.insert_name(EffectName::User(BindingId(id), RangeIndex::TOP));
        }
        effects.vars = vec![EffVar(0), EffVar(3)];
        assert_eq!(
            surface.eff(&effects),
            json!([
                {"rho":{"index":0}}, {"rho":{"index":3}},
                {"name":{"value":"State","ix":{"fixed":"top"}}},
                {"name":{"value":"effect:1","ix":{"fixed":"top"}}},
                {"name":{"value":"effect:42","ix":{"fixed":"top"}}},
                {"name":{"value":"IO.File.Read","ix":{"fixed":"top"}}},
                {"name":{"value":"IO.File.Write","ix":{"fixed":"top"}}},
                {"name":{"value":"Network.Http.Connect","ix":{"fixed":"top"}}}
            ])
        );
        // 固定添字と署名だけの変数の偶奇も同じ自然数の比較へ入る。
        let mut effects = EffectSet::empty();
        for index in [
            RangeIndex::var(1),
            RangeIndex::TOP,
            RangeIndex::var(0),
            RangeIndex::fixed(Range::Path(PathPattern::parse("/").unwrap())),
        ] {
            effects.insert_name(EffectName::Builtin(BuiltinEffectId::FILE_READ, index));
        }
        let signature = super::scheme(
            &[],
            vec![],
            super::builtin(benitoite::types::builtin::BuiltinTypeId::UNIT),
            effects,
        );
        let ranges = benitoite::types::signature::RangeSignature {
            kinds: vec![benitoite::types::scope::Kind::Path; 2],
            ..benitoite::types::signature::RangeSignature::default()
        };
        let exported = super::builtin_export::export_prim(
            &mut surface,
            "signature-order",
            &signature,
            &ranges,
            "pure",
            None,
        );
        assert_eq!(
            exported["eff"],
            json!([
                {"name":{"value":"IO.File.Read","ix":{"fixed":"top"}}},
                {"name":{"value":"IO.File.Read","ix":{"rvar":0}}},
                {"name":{"value":"IO.File.Read","ix":{"fixed":{"path":{"exact":[]}}}}},
                {"name":{"value":"IO.File.Read","ix":{"rvar":1}}}
            ])
        );
    }
}
