//! 新交換形式の独立入力（設計書 07-04「証明する性質」）。
use super::*;
use benitoite::syntax::ast::{Expr, Item, Stmt};
use benitoite::typeck::CallPlan;
use benitoite::types::Ty;
use exchange::named_calls::call_fields;

fn checked(source: &str) -> pipeline::CheckResult {
    let result = pipeline::check_text(
        "named-calls.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
    result
}

pub(super) fn input(name: &str, definitions: Vec<Value>) -> Value {
    json!({"group":"golden","name":name,"excluded":[],"definitions":definitions,
        "dataTypes":[],"constants":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[]})
}

pub(super) fn write_tables(output: &Path, stem: &str, p: &pipeline::CheckedProgram, input: &Value) {
    let table = exchange::named_builtin_tables(p, input, &exchange::complete_stdlib());
    fs::write(
        output.join(format!("{stem}-builtins.json")),
        exchange::to_vec(&json!({"version":4,"inputs":[table]})).unwrap(),
    )
    .unwrap();
    let stdlib = json!({"version":4,"inputs":[{"group":input["group"],"name":input["name"],"functions":[],"impls":[]}]});
    fs::write(
        output.join(format!("{stem}-stdlib.json")),
        exchange::to_vec(&stdlib).unwrap(),
    )
    .unwrap();
}

fn write_named(
    output: &Path,
    stem: &str,
    mut inputs: Vec<Value>,
    tables: Vec<Value>,
    mut coverage: Vec<Value>,
) {
    for (input, table) in inputs.iter_mut().zip(&tables) {
        let mut empty = Value::Null;
        let cov = coverage
            .iter_mut()
            .find(|c| c["group"] == input["group"] && c["name"] == input["name"])
            .unwrap_or(&mut empty);
        exchange::attach_metadata(input, table, cov);
    }
    fs::write(
        output.join(format!("{stem}-corpus.json")),
        exchange::to_vec(&json!({"version":12,"operators":exchange::operators(),"inputs":inputs,"annotations":export_annotations(&inputs)}))
            .unwrap(),
    )
    .unwrap();
    fs::write(
        output.join(format!("{stem}-builtins.json")),
        exchange::to_vec(&json!({"version":4,"inputs":tables})).unwrap(),
    )
    .unwrap();
    let stdlib = inputs
        .iter()
        .map(|i| json!({"group":i["group"],"name":i["name"],"functions":[],"impls":[]}))
        .collect::<Vec<_>>();
    fs::write(
        output.join(format!("{stem}-stdlib.json")),
        exchange::to_vec(&json!({"version":4,"inputs":stdlib})).unwrap(),
    )
    .unwrap();
    fs::write(
        output.join(format!("{stem}-coverage.json")),
        exchange::to_vec(&json!({"version":4,"inputs":coverage})).unwrap(),
    )
    .unwrap();
}

#[test]
fn export_named_calls_smoke() {
    let output = export_directory("named-calls");
    let source = "function factory() -> function(a: Integer, b: Integer) -> Integer\n return lambda(a: Integer, b: Integer) return a\nend function\nfunction readB() -> Integer\n return 29\nend function\nfunction readA() -> Integer\n return 17\nend function\nfunction sample() -> Integer\n return factory()(b: readB(), a: readA())\nend function\nfunction inspect(callback: function(value: Integer) -> Integer) -> Integer\n return match callback with\n case _ -> 0\n end match\nend function";
    let result = checked(source);
    let p = result.program.unwrap();
    let call = p
        .asts
        .iter()
        .flat_map(|m| &m.decls)
        .find_map(|d| {
            let Item::Fn(f) = &d.item else { return None };
            if f.name.text != "sample" {
                return None;
            }
            let Stmt::Expr(Expr::Return(r)) = &f.body.as_ref().unwrap().stmts[0] else {
                panic!("return")
            };
            let Expr::Call(c) = r.value.as_ref() else {
                panic!("call")
            };
            Some(c)
        })
        .unwrap();
    let call_id = call.id;
    assert!(
        !result
            .diagnostics
            .iter()
            .any(benitoite::diag::Diagnostic::is_error),
        "{:?}",
        result.diagnostics
    );
    assert_eq!(
        p.types.call_plans.get(call_id).unwrap(),
        &CallPlan {
            direct_callee: p.resolved.refs.get(call.callee.id()).copied(),
            arity: 2,
            source_to_param: vec![1, 0],
            inserted_first: false,
            hole_names: vec![]
        }
    );
    let core = pipeline::desugar_checked(&p).unwrap();
    let (definitions, coverage) = exchange::named_definitions_with_coverage(&p, &core);
    assert_eq!(definitions.len(), 5);
    let sample = &definitions
        .iter()
        .find(|d| d["name"].as_str().unwrap().starts_with("sample ("))
        .unwrap()["scope"]["inScope"];
    let c = &sample["surface"]["body"]["last"]["expr"]["returnE"]["inner"]["call"];
    assert_eq!(c["labels"], json!(["b", "a"]));
    assert_eq!(c["positions"], json!([1, 0]));
    for (arg, expected) in c["args"].as_array().unwrap().iter().zip(["readB", "readA"]) {
        let binding = p
            .resolved
            .bindings
            .iter()
            .find(|(_, b)| b.name == expected)
            .unwrap()
            .0;
        assert_eq!(
            arg["call"]["callee"]["funName"]["name"],
            json!(format!("fn:{}", binding.0))
        );
        assert_eq!(arg["call"]["labels"], json!([]));
        assert_eq!(arg["call"]["positions"], json!([]));
    }
    assert_eq!(coverage.matches.len(), 1);
    assert!(coverage.bindings.is_empty());
    let integer = json!({"base":{"name":"Integer"}});
    assert_eq!(
        coverage.matches[0]["scrutineeTy"],
        json!({"fn":{"names":["value"],"params":[integer],"ret":integer,"eff":[]}})
    );
    let input = input("named-calls", definitions);
    let table = exchange::named_builtin_tables(&p, &input, &exchange::complete_stdlib());
    write_named(
        &output,
        "named-calls",
        vec![input],
        vec![table],
        vec![
            json!({"group":"golden","name":"named-calls","matches":coverage.matches,"bindings":coverage.bindings}),
        ],
    );
}

fn definition(name: &str, header: Value, expr: Value, body: Value, effects: Value) -> Value {
    json!({"name":name,"annotations":{},"scope":{"inScope":{
        "surface":{"package":"root","header":header,"dictParams":[],"body":{"last":{"expr":{"returnE":{"ret":header["ret"],"inner":expr}}}},"implementation":null,"method":null,"supers":[]},
        "core":{"header":header,"body":body,"lambdaEffects":effects,"supers":[]}}}})
}

// 穴・挿入は書き出しの準備だけを検査する。期待コアは Rust の脱糖から作らない。
#[test]
fn export_named_static_calls_smoke() {
    let output = export_directory("named-static-calls");
    let p = checked("function keep(callback: function(a: Integer, b: Integer) -> Integer) -> function(a: Integer, b: Integer) -> Integer\n return callback\nend function").program.unwrap();
    let scheme = p
        .types
        .decl_types
        .iter()
        .find(|(id, _)| p.resolved.bindings.get(*id).unwrap().name == "keep")
        .unwrap()
        .1;
    let callback = exchange::named_type(&p, &scheme.params[0]);
    let integer = json!({"base":{"name":"Integer"}});
    let literal = |n: i32| json!({"literal":{"value":{"integer":{"value":n}}}});
    let local = |n: i32| json!({"local":{"index":n}});
    let var = |n: i32| json!({"var":{"index":n}});
    let ret = |v: Value| json!({"ret":{"value":v}});
    let let_in = |bound: Value, body: Value| json!({"letIn":{"bound":bound,"body":body}});
    let names = vec!["a".into(), "b".into()];
    let plan = CallPlan {
        direct_callee: None,
        arity: 2,
        source_to_param: vec![1, 0],
        inserted_first: false,
        hole_names: vec!["b".into(), "a".into()],
    };
    let partial = call_fields(
        local(0),
        vec![Some("b".into()), Some("a".into())],
        vec![
            json!({"hole":{"ty":integer}}),
            json!({"hole":{"ty":integer}}),
        ],
        &plan,
        &names,
        Some((integer.clone(), json!([]))),
    );
    let header = json!({"tparams":[],"neffs":0,"effParams":[],"names":["callback"],"params":[callback],"ret":{"fn":{"names":["b","a"],"params":[integer,integer],"ret":integer,"eff":[]}},"eff":[]});
    let body = let_in(
        ret(var(2)),
        let_in(
            ret(var(2)),
            let_in(
                ret(var(2)),
                json!({"app":{"callee":var(2),"args":[var(0),var(1)]}}),
            ),
        ),
    );
    let partial_def = definition(
        "partial (fn:1)",
        header,
        partial,
        ret(json!({"lam":{"names":["b","a"],"params":[integer,integer],"body":body}})),
        json!([[]]),
    );
    let plan = CallPlan {
        direct_callee: None,
        arity: 2,
        source_to_param: vec![1],
        inserted_first: true,
        hole_names: vec![],
    };
    let rhs = call_fields(
        local(0),
        vec![Some("b".into())],
        vec![literal(29)],
        &plan,
        &names,
        None,
    );
    let header = json!({"tparams":[],"neffs":0,"effParams":[],"names":["callback"],"params":[callback],"ret":integer,"eff":[]});
    let body = let_in(
        ret(json!({"const":{"value":{"integer":{"value":17}}}})),
        let_in(
            ret(var(1)),
            let_in(
                ret(json!({"const":{"value":{"integer":{"value":29}}}})),
                json!({"app":{"callee":var(1),"args":[var(2),var(0)]}}),
            ),
        ),
    );
    let pipe_def = definition(
        "pipe (fn:2)",
        header,
        json!({"pipe":{"lhs":literal(17),"rhs":rhs}}),
        body,
        json!([]),
    );
    let plan = CallPlan {
        direct_callee: None,
        arity: 2,
        source_to_param: vec![1, 0],
        inserted_first: false,
        hole_names: vec!["b".into()],
    };
    let mixed = call_fields(
        local(0),
        vec![Some("b".into()), Some("a".into())],
        vec![
            json!({"hole":{"ty":integer}}),
            json!({"expr":{"inner":literal(17)}}),
        ],
        &plan,
        &names,
        Some((integer.clone(), json!([]))),
    );
    let header = json!({"tparams":[],"neffs":0,"effParams":[],"names":["callback"],"params":[callback],"ret":{"fn":{"names":["b"],"params":[integer],"ret":integer,"eff":[]}},"eff":[]});
    let body = let_in(
        ret(var(1)),
        let_in(
            ret(var(1)),
            let_in(
                ret(json!({"const":{"value":{"integer":{"value":17}}}})),
                json!({"app":{"callee":var(2),"args":[var(0),var(1)]}}),
            ),
        ),
    );
    let mixed_def = definition(
        "mixed (fn:3)",
        header,
        mixed,
        ret(json!({"lam":{"names":["b"],"params":[integer],"body":body}})),
        json!([[]]),
    );
    let input = input("named-static-calls", vec![partial_def, pipe_def, mixed_def]);
    let table = exchange::named_builtin_tables(&p, &input, &exchange::complete_stdlib());
    write_named(
        &output,
        "named-static-calls",
        vec![input],
        vec![table],
        vec![json!({"group":"golden","name":"named-static-calls","matches":[],"bindings":[]})],
    );
}

// 利用者の入力と標準宣言の型表を、それぞれの契約の版で独立した検査へ渡す。
#[test]
fn standard_library_calls_require_named_arguments() {
    let old = pipeline::check_text(
        "positional-map.bnt",
        b"function sample() -> List[Integer]\n return List.map([1], lambda(n) return n + 1)\nend function\n",
        CheckOptions { require_main: false, deny_warnings: false },
    );
    assert!(old.program.is_none());
    assert_eq!(
        old.diagnostics
            .iter()
            .filter(|d| d.is_error())
            .map(|d| d.code)
            .collect::<Vec<_>>(),
        [Some(benitoite::diag::DiagCode::E0449)]
    );
    let named = checked(
        "function sample() -> List[Integer]\n return List.map(xs: [1], f: lambda(value) return value + 1)\nend function\n",
    );
    assert!(contracts_well_formed(named.program.as_ref().unwrap()));
    let program = named.program.as_ref().unwrap();
    let core = pipeline::desugar_checked(program).unwrap();
    let definitions = exchange::named_definitions(program, &core);
    let table = exchange::named_stdlib_declarations(program, &core, &input("stdlib", definitions));
    assert_eq!(table["functions"].as_array().unwrap().len(), 1);
    assert_eq!(table["functions"][0]["header"]["names"], json!(["xs", "f"]));
    assert_eq!(
        table["functions"][0]["header"]["params"][1]["fn"]["names"],
        json!(["value"])
    );
    // 名前付きの呼び出しを持つ兄弟と、ゼロ引数だけの本体も同じ交換形式へ渡す。
    let siblings = checked(
        "function invoke(action: function() -> Unit) -> Unit\n return action()\nend function\nfunction identity(value: Integer) -> Integer\n return value\nend function\nfunction main() -> Unit\n invoke(action: lambda() bind _ <- identity(1) end lambda)\nend function\n",
    );
    let program = siblings.program.as_ref().unwrap();
    assert!(contracts_well_formed(program));
    let core = pipeline::desugar_checked(program).unwrap();
    assert_eq!(exchange::named_definitions(program, &core).len(), 3);
}

// 型表と式の型の双方で、入れ子の関数型まで静的な契約を保つ。
// 構文の有無で交換形式を分けず、宣言名の個数と一意性を確かめる。
pub(super) fn contracts_well_formed(p: &pipeline::CheckedProgram) -> bool {
    fn well_formed(ty: &Ty) -> bool {
        match ty {
            Ty::Fn(f) => {
                f.param_names.len() == f.params.len()
                    && f.param_names
                        .iter()
                        .collect::<std::collections::BTreeSet<_>>()
                        .len()
                        == f.params.len()
                    && f.params.iter().all(well_formed)
                    && well_formed(&f.ret)
            }
            Ty::Con(_, args) | Ty::App(_, args) => args.iter().all(well_formed),
            Ty::Param(_) | Ty::Rigid { .. } => true,
        }
    }
    p.types
        .decl_types
        .iter()
        .all(|(_, scheme)| well_formed(&scheme.fn_ty()))
        && p.types.expr_types.iter().all(|(_, ty)| well_formed(ty))
}

pub(super) struct Export {
    pub inputs: Vec<Value>,
    pub tables: Vec<Value>,
    pub coverage: Vec<Value>,
    pub declarations: Vec<Value>,
}
impl Export {
    pub fn new() -> Self {
        Self {
            inputs: vec![],
            tables: vec![],
            coverage: vec![],
            declarations: vec![],
        }
    }
    pub fn push(
        &mut self,
        group: &str,
        name: &str,
        p: &pipeline::CheckedProgram,
        stdlib: &pipeline::CheckedProgram,
    ) {
        let core = pipeline::desugar_checked(p).unwrap();
        let (definitions, constants, coverage) = exchange::named_program_parts(p, &core);
        let mut item = input(name, definitions);
        item["constants"] = constants;
        item["group"] = json!(group);
        let operations = exchange::named_operation_tables(p, &core);
        // 利用者の操作・クラス・実装も、同じ検査済みの宣言から実名を出す。
        let classes = exchange::named_class_tables(p, &core);
        for key in ["classes", "impls"] {
            item[key] = classes[key].clone();
        }
        for key in ["ops", "effects", "primOps"] {
            item[key] = operations[key].clone();
        }
        let table = exchange::named_builtin_tables(p, &item, stdlib);
        let mut cov = json!({"group":group,"name":name,"matches":coverage.matches,"bindings":coverage.bindings});
        exchange::attach_metadata(&mut item, &table, &mut cov);
        self.tables.push(table);
        self.declarations
            .push(exchange::named_stdlib_declarations(p, &core, &item));
        self.coverage.push(cov);
        self.inputs.push(item);
    }
    pub fn write(self, output: &Path) {
        self.write_to(output, "named-programs");
    }
    fn write_to(self, output: &Path, stem: &str) {
        write_named(output, stem, self.inputs, self.tables, self.coverage);
        fs::write(
            output.join(format!("{stem}-stdlib.json")),
            exchange::to_vec(&json!({"version":4,"inputs":self.declarations})).unwrap(),
        )
        .unwrap();
    }
}

// 全件の振り分けと同じ補助を使い、追加した実行入力を短い検査でも新形式へ出す。
// 生成した関数が参照する通常の標準宣言も、独立した検査の入力に含める。
// 実行の自己検査では交換時の宣言・名前・型の欠落を検出できない
// （設計書 07-04「証明する性質」）。
#[test]
fn export_generated_record_property() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap();
    let checked = pipeline::check_path(
        &root.join("tools/derive/examples/People.bnt"),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
    .unwrap();
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let program = checked.program.as_ref().unwrap();
    assert!(contracts_well_formed(program));
    let mut export = Export::new();
    export.push(
        "golden",
        "generated-record-property",
        program,
        &exchange::complete_stdlib(),
    );
    let declarations = export.declarations[0]["functions"].as_array().unwrap();
    for (name, names) in [
        (
            "Benitoite.Test.Property.check",
            vec!["config", "gen", "shrinker", "property"],
        ),
        (
            "Benitoite.Test.Property.formatFailure",
            vec!["failure", "show"],
        ),
        ("Benitoite.Test.Property.integer", vec!["low", "high"]),
        (
            "Benitoite.Json.Codec.decodeField",
            vec!["members", "key", "decode", "decodeMissing"],
        ),
    ] {
        let id = program.resolved.stdlib(name).unwrap();
        let function = declarations
            .iter()
            .find(|f| f["name"] == format!("fn:{}", id.0))
            .unwrap();
        assert_eq!(function["header"]["names"], json!(names), "{name}");
    }
    export.write_to(
        &export_directory("generated-record-property"),
        "generated-record-property",
    );
}

#[test]
fn export_general_named_programs() {
    let output = export_directory("named-programs");
    let mut export = Export::new();
    let stdlib = exchange::complete_stdlib();
    for stem in [
        "named_order",
        "named_escape",
        "named_tail",
        "named_failure",
        "named_contracts",
        "named_partials",
        "named_record_values",
    ] {
        let name = format!("testdata/eval/{stem}.bnt");
        let checked = pipeline::check_path(
            Path::new(env!("CARGO_MANIFEST_DIR")).join(&name).as_path(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        )
        .unwrap();
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let p = checked.program.unwrap();
        assert!(contracts_well_formed(&p));
        for d in &pipeline::desugar_checked(&p).unwrap().defs {
            if d.origin == benitoite::ir::core_ir::DefOrigin::User {
                assert!(d.dict_params.is_empty());
            }
        }
        // 既存の通常呼び出し七入力に利用者の操作がないことも維持する。
        assert!(
            exchange::named_operation_tables(&p, &pipeline::desugar_checked(&p).unwrap())["ops"]
                .as_array()
                .unwrap()
                .is_empty(),
            "user operations need named headers"
        );
        export.push("golden", &name, &p, &stdlib);
    }
    assert_eq!(export.inputs.len(), 7);
    assert_eq!(
        export
            .inputs
            .iter()
            .map(|i| i["definitions"].as_array().unwrap().len())
            .collect::<Vec<_>>(),
        [4, 5, 2, 4, 4, 9, 4]
    );
    for (stem, definitions, operations, implementations) in
        [("named_operations", 2, 1, 0), ("named_methods", 8, 0, 2)]
    {
        let name = format!("testdata/eval/{stem}.bnt");
        let result = pipeline::check_path(
            &Path::new(env!("CARGO_MANIFEST_DIR")).join(&name),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        )
        .unwrap();
        assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
        let p = result.program.unwrap();
        assert!(contracts_well_formed(&p));
        export.push("golden", &name, &p, &stdlib);
        let item = export.inputs.last().unwrap();
        assert_eq!(
            item["definitions"].as_array().unwrap().len(),
            definitions,
            "{stem}"
        );
        assert_eq!(item["ops"].as_array().unwrap().len(), operations);
        assert_eq!(
            item["definitions"]
                .as_array()
                .unwrap()
                .iter()
                .filter(|d| !d["scope"]["inScope"]["surface"]["method"].is_null())
                .count(),
            implementations
        );
    }
    assert_eq!(export.inputs.len(), 9);
    export.write(&output);
}

#[test]
fn export_checked_positional_constructor_holes() {
    let output = export_directory("named-positional-holes");
    let p = checked("data Pair\n Pair(Integer, Integer)\nend data\nfunction partial() -> function(arg2: Integer) -> Pair\n return Pair.Pair(1, _)\nend function").program.unwrap();
    assert!(contracts_well_formed(&p));
    let (id, plan) = p
        .types
        .call_plans
        .iter()
        .find(|(_, plan)| !plan.hole_names.is_empty())
        .unwrap();
    assert_eq!(plan.hole_names, ["arg2"]);
    assert_eq!(plan.source_to_param, [0, 1]);
    let Ty::Fn(f) = p.types.expr_types.get(id).unwrap() else {
        panic!("partial function")
    };
    assert_eq!(f.param_names, ["arg2"]);
    assert_eq!(f.params.len(), 1);
    assert_eq!(f.param_names.len(), f.params.len());
    let core = pipeline::desugar_checked(&p).unwrap();
    let (definitions, coverage) = exchange::named_definitions_with_coverage(&p, &core);
    assert_eq!(definitions.len(), 1);
    let item = input("named-positional-holes", definitions);
    let table = exchange::named_builtin_tables(&p, &item, &exchange::complete_stdlib());
    write_named(
        &output,
        "named-positional-holes",
        vec![item],
        vec![table],
        vec![
            json!({"group":"golden","name":"named-positional-holes","matches":coverage.matches,"bindings":coverage.bindings}),
        ],
    );
}

// 局所注釈だけの境界では、宣言型の走査に現れない契約名も Lean へ渡す。
// 呼び出しと穴の既存例では、注釈だけを旧形式へ送る退行を捕まえられない。
#[test]
fn export_named_annotation_without_named_calls() {
    let output = export_directory("named-annotation-only");
    let p = checked("function target(value: Integer) -> Integer\n return value\nend function\nfunction sample() -> Integer\n bind action: function(value: Integer) -> Integer <- target\n return action(17)\nend function").program.unwrap();
    assert!(contracts_well_formed(&p));
    let core = pipeline::desugar_checked(&p).unwrap();
    let (definitions, constants, coverage) = exchange::named_program_parts(&p, &core);
    let mut item = input("named-annotation-only", definitions);
    item["constants"] = constants;
    let table = exchange::named_builtin_tables(&p, &item, &exchange::complete_stdlib());
    write_named(
        &output,
        "named-annotation-only",
        vec![item],
        vec![table],
        vec![
            json!({"group":"golden","name":"named-annotation-only","matches":coverage.matches,"bindings":coverage.bindings}),
        ],
    );
}

// 関門: 依存の本体から見た標準型も全出力の view に含め、定数の宣言所属を保つ。
// 標準ライブラリに指定した型の view と、定数の宣言側の所属を同時に検査する。
#[test]
fn export_extensible_package() {
    let output = export_directory("extensible-package");
    let root = output.join("extensible-package-source");
    fs::create_dir_all(root.join("dep")).unwrap();
    fs::write(
        root.join("package.bnt"),
        "language \"0.0.9\"\ndependency Dep\n path \"dep\"\nend dependency\n",
    )
    .unwrap();
    fs::write(
        root.join("dep/package.bnt"),
        "language \"0.0.9\"\npackage Dep\nend package\n",
    )
    .unwrap();
    fs::write(root.join("dep/Inspect.bnt"), "import Benitoite.IOErrorKind\npublic const answer: Integer = 42\npublic function inspect(kind: IOErrorKind) -> Integer\n return match kind with\n case IOErrorKind.NotFound -> 1\n case _ -> 0\n end match\nend function\n").unwrap();
    fs::write(
        root.join("main.bnt"),
        "import Dep.Inspect\nfunction read() -> Integer\n return Inspect.answer\nend function\n",
    )
    .unwrap();
    let checked = pipeline::check_path(
        &root.join("main.bnt"),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    )
    .unwrap();
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let id = p
        .resolved
        .stdlib("Benitoite.IOErrorKind.IOErrorKind")
        .unwrap();
    assert!(p.types.adts.get(id).unwrap().extensible);
    let mut export = Export::new();
    export.push(
        "golden",
        "extensible-package",
        &p,
        &exchange::complete_stdlib(),
    );
    let input = &export.inputs[0];
    let data = input["dataTypes"].as_array().unwrap();
    let io = data
        .iter()
        .find(|d| d["name"] == format!("data:{}", id.0))
        .unwrap();
    assert_eq!(io["typeName"], "IOErrorKind");
    assert_eq!(io["package"], "stdlib");
    assert_eq!(io["builtin"], "ordinary");
    let standard: Vec<_> = data
        .iter()
        .filter(|d| d["package"] == "stdlib" && d["extensible"] == true)
        .collect();
    assert_eq!(standard.len(), 5);
    assert_eq!(
        standard
            .iter()
            .map(|d| (
                d["typeName"].as_str().unwrap(),
                d["isRecord"].as_bool().unwrap()
            ))
            .collect::<Vec<_>>(),
        [
            ("IOErrorKind", false),
            ("NetworkErrorKind", false),
            ("ParseError", true),
            ("ParseError", true),
            ("ConversionError", true)
        ]
    );
    for d in &standard {
        assert_eq!(d["package"], "stdlib");
        assert_eq!(d["extensible"], true);
    }
    let inspect = input["definitions"]
        .as_array()
        .unwrap()
        .iter()
        .find(|d| d["name"].as_str().unwrap().contains("inspect ("))
        .unwrap();
    let surface = &inspect["scope"]["inScope"]["surface"];
    assert_eq!(surface["package"], "package:Dep");
    assert_eq!(
        surface["coverageView"],
        json!(standard.iter().map(|d| &d["name"]).collect::<Vec<_>>())
    );
    assert_eq!(export.coverage[0]["matches"][0]["package"], "package:Dep");
    assert_eq!(
        export.coverage[0]["matches"][0]["coverageView"],
        surface["coverageView"]
    );
    assert_eq!(input["constants"][0]["package"], "package:Dep");
    export.write_to(&output, "extensible-package");
}

// 関門: ソースで受理した属性が、未使用の型も含め全交換出力へ残ることを守る。
// 型表を直接設定する既存入力では、属性から型表への接続漏れを捕まえられない。
#[test]
fn export_extensible_source() {
    let checked = pipeline::check_path(
        Path::new("testdata/packages/d6c-extensible-external"),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
    .unwrap();
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let mut export = Export::new();
    export.push(
        "golden",
        "extensible-source",
        &checked.program.unwrap(),
        &exchange::complete_stdlib(),
    );
    let input = &export.inputs[0];
    let decls = input["dataTypes"].as_array().unwrap();
    let open: Vec<_> = decls.iter().filter(|d| d["extensible"] == true).collect();
    assert_eq!(open.len(), 8);
    for name in [
        "Kind",
        "Detail",
        "Unused",
        "IOErrorKind",
        "NetworkErrorKind",
        "ConversionError",
    ] {
        assert!(open.iter().any(|d| d["typeName"] == name));
    }
    let root = input["definitions"]
        .as_array()
        .unwrap()
        .iter()
        .find(|d| d["name"].as_str().unwrap().contains("main ("))
        .unwrap();
    let surface = &root["scope"]["inScope"]["surface"];
    assert_eq!(
        surface["coverageView"],
        json!(open.iter().map(|d| &d["name"]).collect::<Vec<_>>())
    );
    let author = input["definitions"]
        .as_array()
        .unwrap()
        .iter()
        .find(|d| d["name"].as_str().unwrap().contains("inspect ("))
        .unwrap();
    let standard: Vec<_> = open.iter().filter(|d| d["package"] == "stdlib").collect();
    assert_eq!(standard.len(), 5);
    assert_eq!(
        author["scope"]["inScope"]["surface"]["coverageView"],
        json!(standard.iter().map(|d| &d["name"]).collect::<Vec<_>>())
    );
    // 全件の書き出しでも同じ fixture を発見し、六入口の検査へ渡す。
    assert_eq!(
        export.coverage[0]["matches"][0]["coverageView"],
        surface["coverageView"]
    );
    let table = export.tables[0]["dataDecls"].as_array().unwrap();
    for d in open {
        assert!(
            table
                .iter()
                .any(|entry| entry["name"] == d["name"] && entry["extensible"] == true)
        );
    }
}
