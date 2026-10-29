//! 元 AST の全定義と交換・通常解析の範囲を別々に記録する。
//! （設計書 02-05「区間解析の式の識別」）。
use super::*;
use benitoite::syntax::ast::Item;
use std::collections::BTreeSet;

/// 六入口の出力とは独立した、逐次書き出し。
pub(crate) struct Export {
    output: PathBuf,
    manifests: exchange::InputStream,
    materials: exchange::InputStream,
    readers: exchange::InputStream,
    observations: exchange::InputStream,
    summaries: exchange::InputStream,
}

impl Export {
    /// 検査できなかった入力も元の入力順で残す。
    pub(crate) fn unavailable(&mut self, group: &str, name: &str, reasons: Value) {
        let row = json!({"group":group,"name":name,"checker":"failed",
            "reasons":reasons,"definitions":[],"counts":{"checkerSucceeded":"0","checkerFailed":"1"},
            "enumerationComplete":false});
        self.manifests.push(&row);
        self.summaries.push(&row);
    }
    /// 既存六入口と独立した出力先を準備する。
    pub(crate) fn new(output: &Path) -> Self {
        fs::create_dir_all(output).unwrap();
        Self {
            output: output.to_owned(),
            manifests: exchange::InputStream::new(output, "interval-manifest"),
            materials: exchange::InputStream::new(output, "interval-material"),
            readers: exchange::InputStream::new(output, "interval-reader"),
            observations: exchange::InputStream::new(output, "interval-observations"),
            summaries: exchange::InputStream::new(output, "interval-summary"),
        }
    }

    /// 型検査成功・全定義・通常解析の範囲を同じ検査から書き出す。
    pub(crate) fn push(
        &mut self,
        group: &str,
        name: &str,
        checked: &pipeline::CheckResult,
        stdlib: &pipeline::CheckedProgram,
    ) {
        assert!(
            !checked
                .diagnostics
                .iter()
                .any(|d| d.kind == benitoite::diag::ReportKind::Internal)
        );
        let Some(p) = checked.program.as_ref() else {
            let errors: Vec<_> = checked
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .map(|d| format!("{:?}", d.code))
                .collect();
            assert!(!errors.is_empty(), "{name}: unchecked input without errors");
            self.unavailable(group, name, json!(errors));
            return;
        };
        let (types, diagnostics, observed) =
            benitoite::typeck::typecheck_with_interval_observations(
                &p.modules,
                &p.asts,
                &checked.sources,
                &p.resolved,
                false,
            );
        assert!(
            !diagnostics
                .iter()
                .any(benitoite::diag::Diagnostic::is_error),
            "{name}: {diagnostics:?}"
        );
        let summary = types.interval_analysis();
        assert_eq!(
            summary,
            p.types.interval_analysis(),
            "{name}: observation changed analysis"
        );
        let interval_diagnostics = |rows: &[benitoite::diag::Diagnostic]| {
            rows.iter()
                .filter(|d| {
                    matches!(
                        d.code,
                        Some(
                            benitoite::diag::DiagCode::W0401
                                | benitoite::diag::DiagCode::W0402
                                | benitoite::diag::DiagCode::W0404
                        )
                    )
                })
                .map(|d| (d.code, d.primary.as_ref().map(|label| label.span)))
                .collect::<Vec<_>>()
        };
        let hidden_warnings: BTreeSet<_> = p
            .modules
            .iter()
            .filter(|module| {
                matches!(
                    module.kind,
                    benitoite::modules::ModuleKind::Package
                        | benitoite::modules::ModuleKind::PackageConfig
                )
            })
            .map(|module| module.id.file())
            .collect();
        let mut observed_diagnostics = interval_diagnostics(&diagnostics);
        // pipeline::append_stage と同じ公開時の射影を通し、同じ位置の順序も保つ。
        observed_diagnostics.retain(|(_, primary)| {
            !primary.is_some_and(|span| {
                hidden_warnings.contains(&span.file)
                    || checked
                        .sources
                        .get(span.file)
                        .is_some_and(|source| source.kind() == benitoite::base::SourceKind::Prelude)
            })
        });
        observed_diagnostics.sort_by_key(|(_, primary)| {
            primary.map_or(
                (
                    true,
                    benitoite::base::FileId(0),
                    benitoite::base::BytePos(0),
                ),
                |span| (false, span.file, span.start),
            )
        });
        assert_eq!(
            observed_diagnostics,
            interval_diagnostics(&checked.diagnostics),
            "{name}: observation changed interval diagnostics or their order"
        );
        let roots = definitions(p);
        assert_eq!(
            roots.len().to_string(),
            summary.input_definitions.to_string(),
            "{name}: checker definitions"
        );
        let core = pipeline::desugar_checked(p).unwrap();
        let raw = exchange::definitions_recorded(p, &core, true).0;
        assert_eq!(
            roots.iter().map(|d| &d["name"]).collect::<Vec<_>>(),
            raw.iter().map(|d| &d["name"]).collect::<Vec<_>>(),
            "{name}: source order or missing definition"
        );
        let table =
            exchange::named_builtin_tables(p, &json!({"name":name,"definitions":[]}), stdlib);
        let standards = standard_bindings(p, &table);
        let whole = observed.iter().find(|row| row["kind"] == "whole").unwrap();
        let mut modules = modules(p);
        let mut manifest = Vec::new();
        let mut records = Vec::new();
        let mut sites = Vec::new();
        let mut outside = 0usize;
        let mut excluded = Vec::new();
        let mut constants = Value::Null;
        for (root, raw) in roots.into_iter().zip(&raw) {
            if constants.is_null() {
                constants = source::strip(&raw["constants"]);
            }
            if raw["outside"] != json!([]) {
                outside += 1;
                let name = root["name"].as_str().unwrap();
                let bodies: Vec<_> = observed
                    .iter()
                    .filter(|row| {
                        let definition = row["definition"].as_str().unwrap();
                        definition == name || definition.starts_with(&format!("{name}%body:"))
                    })
                    .map(|row| row["definition"].as_str().unwrap().to_owned())
                    .collect();
                assert!(
                    bodies.iter().any(|body| body == name),
                    "missing excluded root {name}"
                );
                manifest.extend(bodies.iter().cloned());
                let external = raw["outside"] == json!(["external type"]);
                if external {
                    excluded
                        .push(json!({"definition":name,"reason":"externalType","bodies":bodies}));
                }
                records.push(json!({"source":root,"manifest":bodies,
                    "outside":raw["outside"],"enumerationComplete":external}));
                continue;
            }
            let mut connected = source::connect(raw, &observed);
            sites.extend(source::standard_sites(&mut connected, &standards));
            manifest.extend(connected.manifest.iter().cloned());
            let module = modules
                .iter_mut()
                .find(|m| m["name"] == raw["module"])
                .unwrap();
            module["definitions"]
                .as_array_mut()
                .unwrap()
                .push(connected.definition.clone());
            records.push(
                json!({"source":root,"manifest":connected.manifest,"outside":[],
                "correspondence":connected.correspondence,"embedded":connected.embedded,
                "bodyTypes":connected.body_types,"enumerationComplete":true}),
            );
        }
        let mut unique = BTreeSet::new();
        assert!(
            manifest.iter().all(|name| unique.insert(name)),
            "duplicate body key"
        );
        let rows = classify(&manifest, &records, &observed);
        let count = |predicate: fn(&Value) -> bool| {
            rows.iter().filter(|r| predicate(r)).count().to_string()
        };
        let counts = json!({"checkerSucceeded":"1","checkerFailed":"0",
            "sourceModules":modules.len().to_string(),
            "constantDefinitions":records.iter().filter(|r|r["source"]["kind"]=="constant").count().to_string(),
            "functionDefinitions":records.iter().filter(|r|r["source"]["kind"]=="function").count().to_string(),
            "methodDefinitions":records.iter().filter(|r|!r["source"]["method"].is_null()).count().to_string(),
            "inputDefinitions":summary.input_definitions.to_string(),"allBodies":manifest.len().to_string(),
            "analyzedBodies":count(|r|r["analyzed"]==true),"outsideDefinitions":outside.to_string(),
            "excludedDefinitions":excluded.len().to_string(),
            "excludedBodies":excluded.iter().map(|e|e["bodies"].as_array().unwrap().len()).sum::<usize>().to_string(),
            "topBodies":count(|r|r["top"]==true),"bottomBodies":count(|r|r["bottom"]==true),
            "informativeBodies":count(|r|r["informative"]==true),
            "depthBodies":count(|r|r["depth"]==true),"notAnalyzedBodies":count(|r|r["analyzed"]==false),
            "unsupportedBodies":summary.unsupported_bodies.to_string(),
            "bodyBudgetExceeded":summary.body_budget_exceeded.to_string(),
            "wholeBudgetSkipped":summary.whole_budget_skipped.to_string(),
            "unidentifiedBodies":summary.unidentified_bodies.to_string(),
            "phaseDepth":summary.phase_stops.depth.to_string()});
        let warnings: Vec<_> = diagnostics.iter().filter(|d|d.is_warning()).map(|d| {
            let span = |s: benitoite::base::Span|json!([s.file.0,s.start.0,s.end.0]);
            json!({"code":format!("{:?}",d.code),"message":d.message,
                "primary":d.primary.as_ref().map(|l|span(l.span)),
                "secondary":d.secondary.iter().map(|l|json!({"span":span(l.span),"text":l.text})).collect::<Vec<_>>(),"notes":d.notes})
        }).collect();
        let identifier = format!("{group}:{name}");
        self.observations
            .push(&json!({"name":identifier,"bodies":observed,"warnings":warnings}));
        self.manifests.push(
            &json!({"group":group,"name":name,"input":identifier,"checker":"succeeded",
            "manifest":manifest,"definitions":records,"bodies":rows,"counts":counts,
            "enumerationComplete":outside==excluded.len(),"excluded":excluded,"whole":whole}),
        );
        self.summaries
            .push(&json!({"group":group,"name":name,"checker":"succeeded",
            "counts":counts,"enumerationComplete":outside==excluded.len(),"excluded":excluded,
            "definitions":records.iter().map(|r|&r["source"]).collect::<Vec<_>>() }));
        self.materials.push(
            &json!({"name":identifier,"fuel":whole["fuel"],"limits":whole["limits"],
            "initial":zero(),"constants":if constants.is_null(){json!([])}else{constants.clone()},
            "standards":standards,"apiAt":sites,"modules":modules}),
        );
        // 読者による全列挙との照合専用。通常解析の成功には数えない。
        if outside == excluded.len() {
            let stop = json!({"kind":"exceeded","scope":"whole","resource":"operations"});
            let mut reader_modules = modules;
            for module in &mut reader_modules {
                for definition in module["definitions"].as_array_mut().unwrap() {
                    definition["expected"] = json!({"notAnalyzed":stop});
                }
            }
            let expected_bodies: Vec<_> = manifest
                .iter()
                .filter(|name| {
                    name.contains("%body:")
                        && !excluded
                            .iter()
                            .any(|e| e["bodies"].as_array().unwrap().iter().any(|b| b == *name))
                })
                .map(|name| json!({"definition":name,"expected":{"notAnalyzed":stop}}))
                .collect();
            let mut limits = whole["limits"].clone();
            limits["whole"]["operations"] = json!("0");
            self.readers.push(&json!({"name":identifier,"fuel":whole["fuel"],"limits":limits,
                "initial":zero(),"constants":if constants.is_null(){json!([])}else{constants},
                "standards":standards,"apiAt":sites,"modules":reader_modules,"expectedBodies":expected_bodies,
                "expected":{"after":zero(),"phaseStops":[{"phase":"whole","reason":stop}],
                    "counts":{"inputDefinitions":(records.len()-excluded.len()).to_string(),"unsupportedBodies":"0",
                        "bodyBudgetExceeded":"0","unidentifiedBodies":"0","wholeBudgetSkipped":(records.len()-excluded.len()).to_string()}}}));
        }
    }

    /// 本文・観測・全定義の一覧と要約をそれぞれ確定する。
    pub(crate) fn finish(self) {
        self.summaries.finish(
            &self.output.join("interval-summary.json"),
            json!({"kind":"interval-source-summary","version":1}),
        );
        self.manifests.finish(
            &self.output.join("interval-manifest.json"),
            json!({"kind":"interval-source-manifest","version":1,"scope":"sourceModules","excludedModuleKinds":["Prelude","Stdlib"]}),
        );
        self.materials.finish(&self.output.join("interval-material.json"),json!({"kind":"interval-source-material","version":1,"profile":"domain","expectations":"pending-X02b"}));
        self.readers.finish(&self.output.join("interval-manifest-corpus.json"),json!({"kind":"interval-corpus","version":1,"surfaceVersion":15,"traversalVersion":1,"profile":"domain"}));
        self.observations.finish(
            &self.output.join("interval-observations.json"),
            json!({"kind":"interval-source-observations","version":1}),
        );
    }
}

fn zero() -> Value {
    json!({"body":{"operations":"0","temporary":"0","saved":"0","peak":"0"},
        "whole":{"operations":"0","saved":"0","peak":"0"}})
}

fn modules(p: &pipeline::CheckedProgram) -> Vec<Value> {
    p.asts
        .iter()
        .enumerate()
        .filter_map(|(index, _)| {
            let module = p
                .modules
                .get(benitoite::base::ModuleId(u32::try_from(index).unwrap()))
                .unwrap();
            (!matches!(
                module.kind,
                benitoite::modules::ModuleKind::Prelude | benitoite::modules::ModuleKind::Stdlib
            ))
            .then(|| json!({"name":module.name.dotted(),"definitions":[]}))
        })
        .collect()
}

/// Surface・解析結果から独立して、元 AST の宣言位置と全件数を得る。
fn definitions(p: &pipeline::CheckedProgram) -> Vec<Value> {
    let mut result = Vec::new();
    for (index, ast) in p.asts.iter().enumerate() {
        let module = p
            .modules
            .get(benitoite::base::ModuleId(u32::try_from(index).unwrap()))
            .unwrap();
        if matches!(
            module.kind,
            benitoite::modules::ModuleKind::Prelude | benitoite::modules::ModuleKind::Stdlib
        ) {
            continue;
        }
        let module = module.name.dotted();
        for (position, decl) in ast.decls.iter().enumerate() {
            let mut emit = |node, method: Option<usize>, kind| {
                let binding = p.resolved.decls.get(node).unwrap();
                let declaration = p.resolved.bindings.get(*binding).unwrap();
                let name = method.map_or_else(
                    || format!("{module}.{}", declaration.name),
                    |method| format!("{module}%impl:{position}:{method}:{}", declaration.name),
                );
                result.push(
                    json!({"name":name,"module":module,"declaration":position.to_string(),
                    "method":method.map(|m|m.to_string()),"kind":kind}),
                );
            };
            match &decl.item {
                Item::Const(c) => emit(c.id, None, "constant"),
                Item::Fn(f) if f.body.is_some() => emit(f.id, None, "function"),
                Item::Impl(i) => {
                    for (method, f) in i.fns.iter().enumerate() {
                        if f.decl.body.is_some() {
                            emit(f.decl.id, Some(method), "function");
                        }
                    }
                }
                Item::Fn(_)
                | Item::Data(_)
                | Item::Alias(_)
                | Item::ExternalType(_)
                | Item::Record(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Error(_) => {}
            }
        }
    }
    result
}

fn classify(manifest: &[String], records: &[Value], observed: &[Value]) -> Vec<Value> {
    manifest
        .iter()
        .map(|name| {
            let actual = observed
                .iter()
                .find(|r| r["definition"] == *name && r["kind"] != "whole");
            let ty = records
                .iter()
                .filter_map(|r| r["bodyTypes"].as_array())
                .flatten()
                .find(|row| row["definition"] == *name)
                .map(|row| &row["type"]);
            let value = actual.map(|a| &a["value"]).filter(|v| !v.is_null());
            let range = value
                .zip(ty)
                .map(|(v, ty)| match ty["base"]["name"].as_str() {
                    Some("Integer") => v["integer"].clone(),
                    Some(
                        "Integer8" | "Integer16" | "Integer32" | "UnsignedInteger16"
                        | "UnsignedInteger32" | "UnsignedInteger64",
                    ) => v["widths"][ty["base"]["name"].as_str().unwrap()].clone(),
                    _ => Value::Null,
                });
            let top = if actual.is_some() && value.is_none() {
                Some(true)
            } else {
                value
                    .zip(ty)
                    .map(|(v, ty)| match ty["base"]["name"].as_str() {
                        Some(
                            "Integer" | "Integer8" | "Integer16" | "Integer32"
                            | "UnsignedInteger16" | "UnsignedInteger32" | "UnsignedInteger64",
                        ) => {
                            let (lo, hi) = match ty["base"]["name"].as_str().unwrap() {
                                "Integer" => (i128::from(i64::MIN), i128::from(i64::MAX)),
                                "Integer8" => (i128::from(i8::MIN), i128::from(i8::MAX)),
                                "Integer16" => (i128::from(i16::MIN), i128::from(i16::MAX)),
                                "Integer32" => (i128::from(i32::MIN), i128::from(i32::MAX)),
                                "UnsignedInteger16" => (0, i128::from(u16::MAX)),
                                "UnsignedInteger32" => (0, i128::from(u32::MAX)),
                                "UnsignedInteger64" => (0, i128::from(u64::MAX)),
                                _ => unreachable!(),
                            };
                            range.as_ref()
                                == Some(&json!({"closed":[lo.to_string(),hi.to_string()]}))
                        }
                        Some("Boolean") => v["boolean"] == json!([true, true]),
                        _ => v["nonIntegerOther"] == true,
                    })
            };
            let coverage = actual
                .and_then(|a| a["coverage"].as_str())
                .unwrap_or("notAnalyzed");
            let bottom = value
                .zip(ty)
                .map(|(v, ty)| match ty["base"]["name"].as_str() {
                    Some(
                        "Integer" | "Integer8" | "Integer16" | "Integer32" | "UnsignedInteger16"
                        | "UnsignedInteger32" | "UnsignedInteger64",
                    ) => range.as_ref() == Some(&json!("bottom")),
                    Some("Boolean") => v["boolean"] == json!([false, false]),
                    _ => v["nonIntegerOther"] == false,
                });
            json!({"definition":name,"analyzed":actual.is_some(),"coverage":coverage,"top":top,
            "bottom":bottom,"informative":top.map(|v|!v),
            "depth":coverage.contains("Depth"),"valueAvailable":value.is_some()})
        })
        .collect()
}
