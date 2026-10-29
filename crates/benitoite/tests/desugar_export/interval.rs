//! 区間比較の実ソースを既存の型付き交換へ渡す（設計書 07-04「01-12 との対応」）。
use super::*;
use benitoite::resolve::BindingKind;

#[path = "interval/manifest.rs"]
pub(crate) mod manifest;

/// 全件入口の局所入力と、区間の予算入力を持ち主の境界で検査する。
pub(super) fn export_interval_manifest() {
    let output = export_directory("interval-manifest");
    let stdlib = exchange::complete_stdlib();
    let mut stream = CorpusStream::new(&output, "manifest-");
    let options = CheckOptions {
        require_main: false,
        deny_warnings: false,
    };
    for (name, text) in [
        ("empty", ""),
        ("top", "function top() -> Unit\nend function"),
        (
            "otherTop",
            "const top: String = \"unknown to interval analysis\"",
        ),
        ("boolean", "const yes: Boolean = true"),
        (
            "nonintegerMatch",
            "function opaque(flag: Boolean) -> Integer\n bind zero <- 0\n return match flag with\n case true -> 8 div zero\n case false -> 1\n end match\nend function",
        ),
        ("invalid", "const invalid: Integer = true"),
    ] {
        let checked = pipeline::check_text(name, text.as_bytes(), options);
        assert_eq!(
            checked.error_count() > 0,
            name == "invalid",
            "{name}: {:?}",
            checked.diagnostics
        );
        stream.export("manifest", name, checked, &stdlib);
    }
    let files = [
        ("main.bnt", b"import Lib\nimport Empty\nconst before: Integer = after\nconst after: Integer = 7\nfunction call() -> Integer\n return Lib.value()\nend function".as_slice()),
        ("Lib.bnt", b"public\nfunction value() -> Integer\n return 42\nend function".as_slice()),
        ("Empty.bnt", b"".as_slice()),
    ];
    let checked = pipeline::check_files(&files, options);
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    stream.export("manifest", "modules", checked, &stdlib);
    // 全件入口と同じ生成器の一入力を局所で通し、辞書や特殊構文も全列挙に含める。
    // ignored の全件書き出しは K1/K2 に残す。
    for seed in [0, 965] {
        let generated = generator::generate_formal(seed);
        let name = format!("random-{seed}.bnt");
        let checked = pipeline::check_text(
            &name,
            generated.source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        stream.export("random", &name, checked, &stdlib);
    }
    // 多数の局所位置の忘却を使い、短い Surface で既定予算の本体・全体上限を通す。
    // 上限と深さ fuel は通常 checker の値を使い、比較用の小予算へ変更しない。
    let params = (0..200)
        .map(|i| format!("p{i}: Integer"))
        .collect::<Vec<_>>()
        .join(", ");
    let list = std::iter::repeat_n("1", 600).collect::<Vec<_>>().join(", ");
    for (name, number) in [("bodyBudget", 1), ("wholeBudget", 16)] {
        let text = (0..number)
            .map(|i| {
                format!(
                    "function many{i}({params}) -> List[Integer]\n return [{list}]\nend function\n"
                )
            })
            .collect::<String>();
        let checked = pipeline::check_text(name, text.as_bytes(), options);
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        stream
            .intervals
            .push("interval-budget", name, &checked, &stdlib);
        fs::write(output.join(format!("{name}.bnt")), text).unwrap();
    }
    // 全件で発見した外部型の四入力と、幅付き警告の追加入力を同じ境界で検査する。
    for name in [
        "testdata/external/resource",
        "testdata/external/wit-docs-declarations",
        "testdata/packages/json-wasm-same",
        "testdata/packages/wasm-regex-same",
        "testdata/warnings/local-width-intervals.bnt",
    ] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
        let checked = pipeline::check_path(&path, options).unwrap();
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        stream.export("golden", name, checked, &stdlib);
    }
    stream.finish(&output, "manifest");
    let manifest: Value = serde_json::from_slice(
        &fs::read(output.join("manifest-interval/interval-summary.json")).unwrap(),
    )
    .unwrap();
    let inputs = manifest["inputs"].as_array().unwrap();
    assert_eq!(inputs.len(), 16);
    assert_eq!(
        inputs
            .iter()
            .map(|i| i["counts"]["excludedDefinitions"]
                .as_str()
                .unwrap_or("0")
                .parse::<usize>()
                .unwrap())
            .sum::<usize>(),
        12
    );
    assert!(
        inputs
            .iter()
            .filter(|i| i["checker"] == "succeeded")
            .all(|i| i["enumerationComplete"] == true)
    );
    let input = |name| inputs.iter().find(|i| i["name"] == name).unwrap();
    assert_eq!(input("invalid")["checker"], "failed");
    assert_eq!(input("empty")["counts"]["inputDefinitions"], "0");
    for name in ["top", "otherTop"] {
        assert_eq!(input(name)["counts"]["topBodies"], "1");
        assert_eq!(input(name)["counts"]["informativeBodies"], "0");
    }
    assert_ne!(input("bodyBudget")["counts"]["bodyBudgetExceeded"], "0");
    assert_ne!(input("wholeBudget")["counts"]["wholeBudgetSkipped"], "0");
    assert_eq!(input("wholeBudget")["counts"]["inputDefinitions"], "16");
    assert!(
        input("modules")["definitions"]
            .as_array()
            .unwrap()
            .iter()
            .any(|d| d["name"] == "Lib.value")
    );
}
#[path = "interval/source.rs"]
mod source;

#[path = "interval/vm.rs"]
mod vm;

const RANGE_BUDGET_CASES: &[(&str, &str)] = &[
    ("rangeCall", include_str!("interval/rangeCall.bnt")),
    ("rangeSaved", include_str!("interval/rangeSaved.bnt")),
    ("rangeAllArms", include_str!("interval/rangeAllArms.bnt")),
    ("rangeValue", include_str!("interval/rangeValue.bnt")),
    ("rangeFake", include_str!("interval/rangeFake.bnt")),
    ("rangeDynamic", include_str!("interval/rangeDynamic.bnt")),
    (
        "rangeIncrement",
        include_str!("interval/rangeIncrement.bnt"),
    ),
    (
        "rangeUnrecognized",
        include_str!("interval/rangeUnrecognized.bnt"),
    ),
];

// 関門: 実交換の型・構成子宣言から得るRangeNamesを、固定表とX02/X03bへ渡す。
// 既存のVM/goldenには表層番号や誤った構成子の同定を検出する期待値がない。
// 本物のpipelineと交換を使い、本番の認定・型・署名は変えない。
#[test]
fn export_interval_range() {
    let output = export_directory("interval-range");
    fs::create_dir_all(&output).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut intervals = manifest::Export::new(&output.join("interval"));
    let mut export = named::Export::new();
    let mut bindings = Vec::new();
    let prelude = include_str!("interval/budget-prelude.bnt");
    let mut sources = vec![
        ("range", include_str!("interval/range.bnt").to_owned()),
        (
            "range-existing",
            include_str!("batch3/range.bnt").to_owned(),
        ),
        (
            "fake-range",
            include_str!("interval/fake-range.bnt").to_owned(),
        ),
    ];
    sources.extend(
        RANGE_BUDGET_CASES
            .iter()
            .map(|(name, body)| (*name, format!("{prelude}{body}"))),
    );
    for (name, source) in sources {
        let checked = pipeline::check_text(
            name,
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
        let program = checked.program.as_ref().unwrap();
        intervals.push("interval-range", name, &checked, &stdlib);
        export.push("interval-range", name, program, &stdlib);
        assert_eq!(export.inputs.last().unwrap()["excluded"], json!([]));
        let table = export.tables.last().unwrap();
        let binding = range_bindings(program, table, name);
        // 表示名を変えても同じ解決済み宣言と構成子を渡す。
        let mut renamed = table.clone();
        for data in renamed["dataDecls"].as_array_mut().unwrap() {
            data["typeName"] = json!("display-only");
            for ctor in data["ctors"].as_array_mut().unwrap() {
                ctor["constructorName"] = json!("display-only");
            }
        }
        let renamed = range_bindings(program, &renamed, name);
        assert_eq!(binding["rangeNames"], renamed["rangeNames"]);
        assert_range_types(&binding);
        bindings.push(binding);
        fs::write(output.join(format!("{name}.bnt")), source).unwrap();
    }
    fs::write(
        output.join("range-bindings.json"),
        exchange::to_vec(&json!({"version":1,"inputs":bindings})).unwrap(),
    )
    .unwrap();
    let annotations = export_annotations(&export.inputs);
    write_exchange(
        &output,
        export.inputs,
        export.tables,
        export.declarations,
        annotations,
    );
    intervals.finish();
    eprintln!("Range interval export: 11 inputs; {}", output.display());
}

fn range_bindings(p: &pipeline::CheckedProgram, table: &Value, input: &str) -> Value {
    let mut binding = range_identities(p, table, input);
    binding["typedCalls"] = json!(typed_calls(p));
    binding
}

fn range_identities(p: &pipeline::CheckedProgram, table: &Value, input: &str) -> Value {
    let resolved = |name: &str| {
        p.resolved
            .stdlib(name)
            .unwrap_or_else(|| panic!("missing standard {name}"))
    };
    // 型名・表示名で検索しない。解決済み宣言のIDとdataDeclsの同一性を照合する。
    let data = |name: &str| {
        let id = resolved(name);
        table["dataDecls"]
            .as_array()
            .unwrap()
            .iter()
            .find(|d| d["name"] == format!("data:{}", id.0))
            .unwrap()
            .clone()
    };
    let owner = data("Benitoite.Range.CheckedInteger");
    let result = data("Benitoite.Result.Result");
    let error = data("Benitoite.Range.RangeError");
    assert_eq!(owner["isRecord"], true);
    let ctors = owner["ctors"].as_array().unwrap();
    assert_eq!(ctors.len(), 1);
    assert_eq!(ctors[0]["fields"], json!(["minimum", "maximum", "value"]));
    assert_eq!(
        ctors[0]["args"],
        json!([{"base":{"name":"Integer"}},{"base":{"name":"Integer"}},{"base":{"name":"Integer"}}])
    );
    let constructor = |decl: &Value, name: &str| {
        let BindingKind::Ctor { data, tag } = p.resolved.bindings.get(resolved(name)).unwrap().kind
        else {
            panic!("constructor")
        };
        assert_eq!(decl["name"], format!("data:{}", data.0));
        decl["ctors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|c| c["name"] == exchange::con_name(p, data, tag))
            .unwrap()["name"]
            .clone()
    };
    let names = json!({"owner":owner["name"], "checkedConstructor":ctors[0]["name"],
        "result":result["name"],"error":error["name"],
        "ok":constructor(&result,"Benitoite.Result.Ok"),
        "err":constructor(&result,"Benitoite.Result.Error"),
        "invalidBounds":constructor(&error,"Benitoite.Range.RangeError.InvalidBounds"),
        "outOfRange":constructor(&error,"Benitoite.Range.RangeError.OutOfRange")});
    json!({"name":input,"rangeNames":names,
        "checkDeclaration":format!("fn:{}",resolved("Benitoite.Range.checkInteger").0),
        "valueDeclaration":format!("fn:{}",resolved("Benitoite.Range.value").0),
        "declarations":[owner,result,error]})
}

// Surfaceと同じ型符号化を実際の式・引数に適用し、署名だけの照合にしない。
fn typed_calls(p: &pipeline::CheckedProgram) -> Vec<Value> {
    use benitoite::syntax::ast::{self as a, Arg, ArgValue, Expr, Item, Stmt};
    fn block(p: &pipeline::CheckedProgram, name: &str, b: &a::Block, out: &mut Vec<Value>) {
        for s in &b.stmts {
            match s {
                Stmt::Expr(e) => expr(p, name, e, out),
                Stmt::Bind(b) => expr(p, name, &b.value, out),
                Stmt::Error(_) => panic!("checked block"),
            }
        }
    }
    fn expr(p: &pipeline::CheckedProgram, name: &str, e: &Expr, out: &mut Vec<Value>) {
        match e {
            Expr::Call(c) => {
                let args: Vec<_> = c
                    .args
                    .iter()
                    .map(|arg| match arg {
                        Arg::Expr(e) => e,
                        Arg::Named(a) => match &a.value {
                            ArgValue::Expr(e) => e,
                            _ => panic!("hole"),
                        },
                        Arg::Placeholder(_) => panic!("hole"),
                    })
                    .collect();
                if let Some(id) = p.resolved.refs.get(c.callee.id())
                    && ["Benitoite.Range.checkInteger", "Benitoite.Range.value"]
                        .iter()
                        .any(|n| p.resolved.stdlib(n) == Some(*id))
                {
                    let ty = |node| exchange::named_type(p, p.types.expr_types.get(node).unwrap());
                    out.push(json!({"definition":name, "callee":format!("fn:{}", id.0),
                            "resultType":ty(c.id), "argumentTypes":args.iter().map(|a| ty(a.id())).collect::<Vec<_>>()}));
                }
                expr(p, name, &c.callee, out);
                for a in args {
                    expr(p, name, a, out);
                }
            }
            Expr::Return(r) => expr(p, name, &r.value, out),
            Expr::Match(m) => {
                expr(p, name, &m.scrutinee, out);
                for arm in &m.arms {
                    if let Some(g) = &arm.guard {
                        expr(p, name, g, out);
                    }
                    block(p, name, &arm.body, out);
                }
            }
            Expr::Binary(b) => {
                expr(p, name, &b.lhs, out);
                expr(p, name, &b.rhs, out);
            }
            Expr::Unary(u) => expr(p, name, &u.operand, out),
            Expr::Paren(e) => expr(p, name, &e.inner, out),
            Expr::Block(e) => block(p, name, &e.body, out),
            Expr::List(l) => {
                for e in &l.elems {
                    match e {
                        a::ListElem::Expr(e) => expr(p, name, e, out),
                        _ => panic!("spread"),
                    }
                }
            }
            Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) => {}
            other @ (Expr::Interp(_)
            | Expr::Record(_)
            | Expr::Pipe(_)
            | Expr::If(_)
            | Expr::Lambda(_)
            | Expr::Try(_)
            | Expr::Lazy(_)
            | Expr::With(_)
            | Expr::Handle(_)
            | Expr::Resume(_)
            | Expr::Error(_)) => {
                panic!("Range fixture traversal needs {other:?}")
            }
        }
    }
    let mut out = Vec::new();
    for (index, module) in p.asts.iter().enumerate() {
        if !matches!(
            p.modules
                .get(benitoite::base::ModuleId(u32::try_from(index).unwrap()))
                .unwrap()
                .kind,
            benitoite::modules::ModuleKind::Entry
        ) {
            continue;
        }
        for d in &module.decls {
            if let Item::Fn(f) = &d.item {
                block(p, &f.name.text, f.body.as_ref().unwrap(), &mut out);
            }
        }
    }
    out
}

fn assert_range_types(binding: &Value) {
    let names = &binding["rangeNames"];
    let integer = json!({"base":{"name":"Integer"}});
    let owner = json!({"data":{"name":names["owner"],"args":[]}});
    let result = json!({"data":{"name":names["result"],"args":[owner,{"data":{"name":names["error"],"args":[]}}]}});
    for call in binding["typedCalls"].as_array().unwrap() {
        let (ret, args) = if call["callee"] == binding["checkDeclaration"] {
            (&result, vec![&integer, &integer, &integer])
        } else {
            assert_eq!(call["callee"], binding["valueDeclaration"]);
            (&integer, vec![&owner])
        };
        assert_eq!(&call["resultType"], ret, "{call}");
        assert_eq!(call["argumentTypes"], json!(args), "{call}");
    }
}

// 関門: 同じ実ソースの通常解析と既存Surface交換の順・元演算の対応を照合する。
// 定数展開、未到達、独立入力、別本体で順や由来がずれれば失敗する。
// 既存の六入口は解析の訪問表を読まない。sinkは計画で認めた任意の内部観測だけ。
pub(super) fn export_interval_identity() {
    let output = export_directory("interval-identity");
    fs::create_dir_all(&output).unwrap();
    let cases = [
        ("point", "const point: Integer = 42"),
        (
            "division",
            "function division() -> Integer\n return 8 div 0\nend function",
        ),
        (
            "flow",
            "const zero: Integer = 0\nfunction flow(x: Integer) -> Integer\n bind alias <- zero\n return if x = 0 then 8 div x else if false then 9 mod 0 else alias end if\nend function",
        ),
        (
            "independent",
            "function independent() -> List[Integer]\n return [block bind x <- 0\n 8 div x end block]\nend function",
        ),
        (
            "lambda",
            "function nested() -> (function() -> Integer)\n return lambda() return 8 div 0 end lambda\nend function",
        ),
        (
            "spread",
            "function spread(xs: List[Integer]) -> List[Integer]\n return [1, ..xs, 3]\nend function",
        ),
        (
            "interpolation",
            "function interpolation(x: Integer) -> String\n return \"a${x}b${true}c${x:04d}\"\nend function",
        ),
        (
            "with",
            "function scoped() -> Unit uses State\n with first = TaskGroup.open(), second = TaskGroup.open() do\n bind _ <- 1 div 0\n end with\nend function",
        ),
        (
            "lazy",
            "function delayed() -> Lazy[Integer]\n return lazy 8 div 0 end lazy\nend function",
        ),
        (
            "constant-reuse",
            "const zero: Integer = 0\nfunction reused() -> Integer\n return (zero + zero) div zero\nend function",
        ),
        (
            "handler",
            "effect E\n function get() -> Integer\nend effect\nfunction handled() -> Integer\n return handle get() with case get() -> 8 div 0 end handle\nend function",
        ),
        (
            "match",
            "function guarded(x: Integer) -> Integer\n return match x with\n case n if n = 0 -> 8 div n\n case _ -> 1\n end match\nend function",
        ),
        (
            "impl",
            "trait First[T]\n function score(x: T) -> Integer\nend trait\ntrait Second[T]\n function score(x: T) -> Integer\nend trait\nimplement First[Integer]\n function score(x: Integer) -> Integer\n return x div 0\n end function\nend implement\nimplement Second[Integer]\n function score(x: Integer) -> Integer\n return x mod 0\n end function\nend implement",
        ),
    ];
    let mut cases: Vec<_> = cases
        .into_iter()
        .map(|(label, text)| (label.to_owned(), text.to_owned()))
        .collect();
    cases.extend(contract_cases());
    let mut records = Vec::new();
    let mut inputs = Vec::new();
    let stdlib = exchange::complete_stdlib();
    let mut manifests = manifest::Export::new(&output);
    for (label, text) in cases {
        let checked = pipeline::check_text(
            &label,
            text.as_bytes(),
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{label}: {:?}",
            checked.diagnostics
        );
        let p = checked.program.as_ref().unwrap();
        manifests.push("interval", &label, &checked, &stdlib);
        // 同じ AST を本物の型検査へ再度渡す。記録先はこの検査の中だけで所有する。
        let (_, diagnostics, observed) = benitoite::typeck::typecheck_with_interval_observations(
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
            "{label}: {diagnostics:?}"
        );
        let core = pipeline::desugar_checked(p).unwrap();
        let definitions = exchange::definitions_recorded(p, &core, true).0;
        let table =
            exchange::named_builtin_tables(p, &json!({"name":label,"definitions":[]}), &stdlib);
        let standards = standard_bindings(p, &table);
        fs::write(output.join(format!("{label}.bnt")), &text).unwrap();
        for raw in definitions {
            let mut connected = source::connect(&raw, &observed);
            let api_at = source::standard_sites(&mut connected, &standards);
            inputs.push(source::reader_input(
                &raw, &connected, &label, &standards, api_at,
            ));
            if label == "division" {
                assert_eq!(connected.candidates["parent"].as_array().unwrap().len(), 1);
            }
            if matches!(label.as_str(), "lambda" | "lazy" | "handler") {
                assert_eq!(connected.embedded.len(), 1, "{label}");
                assert_eq!(
                    connected.embedded[0]["candidates"]["parent"]
                        .as_array()
                        .unwrap()
                        .len(),
                    1,
                    "{label}"
                );
            }
            if label == "independent" {
                assert!(
                    connected.candidates["independent"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|entry| !entry["candidates"].as_array().unwrap().is_empty())
                );
            }
            records.push(json!({"input":label,"name":raw["name"],"correspondence":connected.correspondence,"candidates":connected.candidates,"embedded":connected.embedded}));
            if label == "point" {
                let zero = json!({"operations":"0","temporary":"0","saved":"0","peak":"0"});
                let expected = json!({"integer":{"closed":["42","42"]},"boolean":[false,false],"other":false,"mayFail":false,
                    "warnings":[],"coverage":"complete","after":{"body":zero,"whole":{"operations":"8","saved":"3","peak":"7"}},
                    "context":{"budget":{"body":{"operations":"7","temporary":"0","saved":"3","peak":"7"},"whole":{"operations":"8","saved":"0","peak":"7"}},
                        "next":[".point","2"],"identities":[[".point","0"],[".point","1"]],"unsupported":false}});
                fs::write(
                    output.join("point.json"),
                    exchange::to_vec(&source::corpus(&raw, connected, expected)).unwrap(),
                )
                .unwrap();
            }
        }
    }
    fs::write(
        output.join("reader-corpus.json"),
        exchange::to_vec(&json!({
        "kind":"interval-corpus","version":1,"surfaceVersion":15,"traversalVersion":1,
        "profile":"domain","inputs":inputs}))
        .unwrap(),
    )
    .unwrap();
    fs::write(
        output.join("correspondence.json"),
        exchange::to_vec(&json!(records)).unwrap(),
    )
    .unwrap();
    manifests.finish();
}

// 七種の全演算・四種の負号と、シフト27宣言を同じ実交換の境界で扱う。
fn contract_cases() -> Vec<(String, String)> {
    let mut cases = Vec::new();
    for ty in [
        "Integer",
        "Integer8",
        "Integer16",
        "Integer32",
        "UnsignedInteger16",
        "UnsignedInteger32",
        "UnsignedInteger64",
    ] {
        let mut source = String::new();
        for (name, op) in [
            ("add", "+"),
            ("sub", "-"),
            ("mul", "*"),
            ("div", "div"),
            ("mod", "mod"),
            ("eq", "="),
            ("ne", "<>"),
            ("lt", "<"),
            ("le", "<="),
            ("gt", ">"),
            ("ge", ">="),
        ] {
            let result = if ["eq", "ne", "lt", "le", "gt", "ge"].contains(&name) {
                "Boolean"
            } else {
                ty
            };
            source.push_str(&format!(
                "function arithmetic{name}(x: {ty}, y: {ty}) -> {result}\n return x {op} y\nend function\n"
            ));
        }
        if ty.starts_with("Integer") {
            source.push_str(&format!(
                "function negate(x: {ty}) -> {ty}\n return -x\nend function\n"
            ));
        }
        cases.push((format!("arithmetic-{ty}"), source));
    }
    let mut shifts = String::new();
    for (index, (module, ty)) in SHIFT_MODULES.iter().enumerate() {
        for suffix in ["Left", "Right", "RightUnsigned"] {
            if suffix == "RightUnsigned" && !module.starts_with("Integer") {
                continue;
            }
            for (order, args) in [("ordered", "a: x, n: -1"), ("reversed", "n: 64, a: x")] {
                shifts.push_str(&format!("function shift{index}{suffix}{order}(x: {ty}) -> {ty}\n return {module}.shift{suffix}({args})\nend function\n"));
            }
        }
    }
    cases.push(("shifts".to_owned(), shifts));
    cases.push((
        "range-identity".to_owned(),
        include_str!("interval/range.bnt").to_owned(),
    ));
    cases.push((
        "fake-range-identity".to_owned(),
        include_str!("interval/fake-range.bnt").to_owned(),
    ));
    cases.push(("heads".to_owned(), "import Benitoite.Unofficial.IO.Process\neffect E\n function get() -> Integer\nend effect\nfunction user(x: Integer) -> Integer\n return x\nend function\nfunction heads() -> Integer uses E, Process.Exit\n bind _ <- Process.exit(code: 300)\n bind _ <- get()\n return user(x: 1)\nend function".to_owned()));
    cases
}

const SHIFT_MODULES: &[(&str, &str)] = &[
    ("Byte", "Byte"),
    ("Integer", "Integer"),
    ("Integer8", "Integer8"),
    ("Integer16", "Integer16"),
    ("Integer32", "Integer32"),
    ("Integer64", "Integer"),
    ("UnsignedInteger", "UnsignedInteger64"),
    ("UnsignedInteger8", "Byte"),
    ("UnsignedInteger16", "UnsignedInteger16"),
    ("UnsignedInteger32", "UnsignedInteger32"),
    ("UnsignedInteger64", "UnsignedInteger64"),
];

// 宣言の実ID・種類・署名を読み、Surfaceの実名と同じ表現で交換へ渡す。
fn standard_bindings(p: &pipeline::CheckedProgram, table: &Value) -> Vec<Value> {
    let binding = |name: &str| {
        let id = p.resolved.stdlib(name)?;
        let scheme = p.types.decl_types.get(id).unwrap();
        assert!(
            scheme.type_params.is_empty()
                && scheme.effect_params.is_empty()
                && scheme.class_constraints.is_empty()
                && scheme.effects.is_empty()
        );
        let declaration = match p.resolved.bindings.get(id).unwrap().kind {
            BindingKind::Fn => format!("fn:{}", id.0),
            BindingKind::BuiltinFn(b) => benitoite::builtins::builtin_decl(b)
                .unwrap()
                .name
                .to_owned(),
            BindingKind::ImplFn { .. }
            | BindingKind::Const
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::ExternalType
            | BindingKind::Record
            | BindingKind::Field { .. }
            | BindingKind::Ctor { .. }
            | BindingKind::Trait
            | BindingKind::Method { .. }
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Op { .. }
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Local(_) => panic!("standard must be a pure function: {name}"),
        };
        Some(
            json!({"declaration":declaration,"name":name,"argumentTypes":scheme.params.iter()
            .map(|t| exchange::named_type(p,t)).collect::<Vec<_>>()}),
        )
    };
    let mut out = Vec::new();
    if p.resolved.stdlib("Benitoite.Range.checkInteger").is_some() {
        let identities = range_identities(p, table, "interval-source");
        let names = &identities["rangeNames"];
        let owner = &identities["declarations"][0];
        let ctor = &owner["ctors"][0];
        let record =
            json!({"fields":ctor["fields"],"data":owner["name"],"ntys":0,"args":ctor["args"]});
        let mut check = binding("Benitoite.Range.checkInteger").unwrap();
        let mut rule = names.clone();
        rule["record"] = record.clone();
        check["rule"] = json!({"rangeCheck":rule});
        out.push(check);
        let mut value = binding("Benitoite.Range.value").unwrap();
        value["rule"] = json!({"rangeValue":{"owner":names["owner"],"constructor":names["checkedConstructor"],"record":record}});
        out.push(value);
    }
    let mut shifts = Vec::new();
    for (module, ty) in SHIFT_MODULES {
        for (suffix, direction) in [
            ("Left", "left"),
            ("Right", "right"),
            ("RightUnsigned", "rightUnsigned"),
        ] {
            if suffix == "RightUnsigned" && !module.starts_with("Integer") {
                continue;
            }
            if let Some(mut row) = binding(&format!("Benitoite.{module}.shift{suffix}")) {
                assert_eq!(
                    row["argumentTypes"],
                    json!([{"base":{"name":ty}},{"base":{"name":"Integer"}}])
                );
                row["rule"] =
                    json!({"fixedDomain":{"operand":{"base":{"name":ty}},"direction":direction}});
                shifts.push(row);
            }
        }
    }
    shifts.sort_by(|a, b| a["name"].as_str().unwrap().cmp(b["name"].as_str().unwrap()));
    out.extend(shifts);
    out
}
