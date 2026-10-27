//! 比較用ソースだけへ標識を加え、元番号と追加後の番号を別々に保存する。
//! （設計書 07-04「01-12 との対応」）。
use super::*;

fn checked(text: &str) -> pipeline::CheckResult {
    let result = pipeline::check_text(
        "arithmetic.bnt",
        text.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
    result
}

// 関門: 実 VM と対象構文の評価関係の間の値・失敗・到達の契約を守る。
// 元の位置から標識を作り、本物の交換を再度通す。VM の観測口は増やさない。
#[test]
fn export_interval_vm() {
    let output = export_directory("interval-vm");
    export_vm(&output, "arithmetic", include_str!("vm-arithmetic.bnt"));
    let range = format!(
        "import Benitoite.Unofficial.IO.Console\n{}\n{}",
        include_str!("range.bnt"),
        include_str!("vm-range.bnt")
    );
    let range = range
        .replace(
            "import Benitoite.Unofficial.Range\n",
            "import Benitoite.Unofficial.Range as R\n",
        )
        .replace("Range.", "R.");
    export_vm(&output.join("range"), "range", &range);
    export_vm(&output.join("shifts"), "shifts", &shift_source());
}

fn shift_source() -> String {
    let mut text = "import Benitoite.Unofficial.IO.Console\n".to_owned();
    for (module, ty) in SHIFT_MODULES {
        let (width, operand) = match *ty {
            "Integer8" => (8, "-1s8"),
            "Integer16" => (16, "-1s16"),
            "Integer32" => (32, "-1s32"),
            "UnsignedInteger16" => (16, "65535u16"),
            "UnsignedInteger32" => (32, "4294967295u32"),
            "UnsignedInteger64" => (64, "18446744073709551615u64"),
            "Byte" => (8, "255u8"),
            "Integer" => (64, "-1"),
            _ => panic!("unexpected shift operand"),
        };
        for direction in ["Left", "Right", "RightUnsigned"] {
            if direction == "RightUnsigned" && !module.starts_with("Integer") {
                continue;
            }
            for (label, amount) in [
                ("negative", -1),
                ("width", width),
                ("zero", 0),
                ("last", width - 1),
            ] {
                // 幅の域外は逆順の名前付き引数にし、契約順との取り違えも捕まえる。
                let args = if label == "width" {
                    format!("n: {amount}, a: {operand}")
                } else {
                    format!("a: {operand}, n: {amount}")
                };
                text.push_str(&format!("function shift{module}{direction}{label}() -> {ty}\n return {module}.shift{direction}({args})\nend function\n"));
            }
        }
    }
    text
}

fn export_vm(output: &Path, label: &str, text: &str) {
    fs::create_dir_all(output).unwrap();
    assert!(
        !text.contains("intervalOperand"),
        "temporary name collision"
    );
    let original = checked(text);
    let stdlib = exchange::complete_stdlib();
    let mut export = manifest::Export::new(&output.join("original"));
    export.push("vm", label, &original, &stdlib);
    export.finish();
    let p = original.program.as_ref().unwrap();
    let core = pipeline::desugar_checked(p).unwrap();
    let raw = exchange::definitions_recorded(p, &core, true).0;
    let table = exchange::named_builtin_tables(p, &json!({"name":label,"definitions":[]}), &stdlib);
    let standards = standard_bindings(p, &table);
    let (_, _, observations) = benitoite::typeck::typecheck_with_interval_observations(
        &p.modules,
        &p.asts,
        &original.sources,
        &p.resolved,
        false,
    );
    let mut sites = Vec::new();
    for definition in &raw {
        let mut connected = source::connect(definition, &observations);
        let standard_sites = source::standard_sites(&mut connected, &standards);
        for e in &connected.correspondence {
            let expression = &e["expression"];
            let standard_call = expression.get("call").is_some_and(|call| {
                let head = &call["callee"];
                let name = head["funName"]["name"]
                    .as_str()
                    .or_else(|| head["primName"]["name"].as_str());
                standard_sites.iter().any(|site| {
                    site["key"][1] == e["preorder"] && site["declaration"].as_str() == name
                })
            });
            if expression.get("binary").is_none()
                && expression.get("neg").is_none()
                && !standard_call
            {
                continue;
            }
            let key = e["preorder"].as_str().unwrap();
            let name = definition["name"].as_str().unwrap();
            let children: Vec<_> = connected
                .correspondence
                .iter()
                .filter(|c| c["parent"] == *key)
                // 認定した直接名は評価する引数ではない。残りは Surface のソース順である。
                .skip(usize::from(standard_call))
                .collect();
            let start = usize::try_from(e["span"][1].as_u64().unwrap()).unwrap();
            let end = usize::try_from(e["span"][2].as_u64().unwrap()).unwrap();
            let mut replacements = Vec::new();
            for (i, child) in children.iter().enumerate() {
                let a = usize::try_from(child["span"][1].as_u64().unwrap()).unwrap();
                let b = usize::try_from(child["span"][2].as_u64().unwrap()).unwrap();
                let temp = format!("intervalOperand{key}x{i}");
                replacements.push((a, b, temp));
            }
            // 元の演算子と空白を残し、子だけを新しい束縛の参照へ置き換える。
            let mut operation = text[start..end].to_owned();
            for (a, b, temp) in replacements.iter().rev() {
                operation.replace_range(a - start..b - start, temp);
            }
            let marker = format!("REACH:{name}:{key}");
            sites.push(
                json!({"key":[name,key],"span":e["span"],"expression":expression,
                "operands":children.iter().map(|c|c["span"].clone()).collect::<Vec<_>>(),
                "operationText":operation,"marker":marker}),
            );
        }
    }
    let mut instrumented = rewrite(text, 0, text.len(), &sites);
    instrumented = instrumented
        .lines()
        .map(|line| {
            if line.starts_with("function ") {
                format!("{line} uses Console.Write")
            } else {
                line.to_owned()
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
        + "\n";
    let marked = checked(&instrumented);
    let mut export = manifest::Export::new(&output.join("instrumented"));
    export.push("vm", label, &marked, &stdlib);
    export.finish();
    fs::write(output.join("original.bnt"), text).unwrap();
    fs::write(output.join("instrumented.bnt"), instrumented).unwrap();
    fs::write(
        output.join("vm-sites.json"),
        exchange::to_vec(&json!({"version":1,"sites":sites})).unwrap(),
    )
    .unwrap();
    eprintln!("VM interval export: {} operations", sites.len());
}

fn span(value: &Value) -> (usize, usize) {
    (
        usize::try_from(value[1].as_u64().unwrap()).unwrap(),
        usize::try_from(value[2].as_u64().unwrap()).unwrap(),
    )
}

fn rewrite(text: &str, start: usize, end: usize, sites: &[Value]) -> String {
    let mut ordered: Vec<_> = sites
        .iter()
        .filter(|s| {
            let (a, b) = span(&s["span"]);
            start <= a && b <= end
        })
        .collect();
    ordered.sort_by_key(|s| {
        let (a, b) = span(&s["span"]);
        (a, std::cmp::Reverse(b))
    });
    let mut result = String::new();
    let mut next = start;
    for site in ordered {
        let (a, b) = span(&site["span"]);
        if a < next {
            continue;
        }
        result.push_str(&text[next..a]);
        result.push_str("(block\n");
        for (i, operand) in site["operands"].as_array().unwrap().iter().enumerate() {
            let (lo, hi) = span(operand);
            assert!(a <= lo && hi <= b && (lo > a || hi < b));
            result.push_str(&format!(
                "bind intervalOperand{}x{i} <- {}\n",
                site["key"][1].as_str().unwrap(),
                rewrite(text, lo, hi, sites)
            ));
        }
        result.push_str(&format!(
            "Console.writeLine(\"{}\")\n{}\nend block)",
            site["marker"].as_str().unwrap(),
            site["operationText"].as_str().unwrap()
        ));
        next = b;
    }
    result.push_str(&text[next..end]);
    result
}
