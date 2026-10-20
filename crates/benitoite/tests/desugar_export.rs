//! Lean の脱糖との差分検査用の書き出し。比較は scripts/check-formal.sh が行う。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
#[path = "desugar_export/batch3.rs"]
mod batch3;
#[path = "golden/differential.rs"]
mod differential;
#[path = "desugar_export/exchange.rs"]
mod exchange;
#[path = "random_programs/generator.rs"]
pub mod generator;
#[path = "desugar_export/named.rs"]
mod named;

#[path = "operation_dictionaries/mod.rs"]
mod operation_dictionaries;

use benitoite::pipeline::{self, CheckOptions};
use serde_json::{Value, json};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

// 関門: 新しい数の脱糖と宣言表が Lean の独立した規則へ実際に渡せることを守る。
// VM の実行だけでは、交換形式のビット欠落や対象外への誤った除外を捕まえられない。
// 既存の書き出しを使い、全 corpus の発見・無作為の生成・本番の差し込み口を増やさない。
#[test]
fn export_width_smoke() {
    let start = Instant::now();
    let output = export_directory("width-smoke").join("width-smoke");
    fs::create_dir_all(&output).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut inputs = vec![];
    let mut builtin_inputs = vec![];
    let mut stdlib_inputs = vec![];
    let mut coverage_inputs = vec![];
    let groups = [
        (
            "signed",
            vec![
                ("Integer8", "-128s8"),
                ("Integer16", "-32768s16"),
                ("Integer32", "-2147483648s32"),
            ],
        ),
        (
            "unsigned",
            vec![
                ("UnsignedInteger16", "65535u16"),
                ("UnsignedInteger32", "4294967295u32"),
                ("UnsignedInteger64", "18446744073709551615u64"),
            ],
        ),
        ("float", vec![("Float32", "1.000000059604644775390625f32")]),
    ];
    for (group, widths) in groups {
        let mut source = String::new();
        for (index, (ty, literal)) in widths.iter().enumerate() {
            source.push_str(&format!(
                "const edge{index}: {ty} = {literal}\n\
                 function literal{index}() -> {ty}\n return {literal}\nend function\n\
                 function constant{index}() -> {ty}\n return edge{index}\nend function\n"
            ));
            let operation = if *ty == "Float32" {
                "((x + y) * (x - y)) / y".to_owned()
            } else {
                "((x + y) * (x - y)) div y mod y".to_owned()
            };
            let standard = if *ty == "Float32" {
                "Float32.squareRoot(x + y)".to_owned()
            } else {
                format!("{ty}.minimum(a: x, b: y)")
            };
            source.push_str(&format!(
                "function arithmetic{index}(x: {ty}, y: {ty}) -> {ty}\n\
                 return {operation}\nend function\n\
                 function standard{index}(x: {ty}, y: {ty}) -> {ty}\n\
                 return {standard}\nend function\n"
            ));
        }
        if group == "float" {
            source.push_str("function negativeZero() -> Float32\n return -0.0f32\nend function\n");
        }
        if group == "unsigned" {
            source.push_str("function upperHalf() -> UnsignedInteger64\n return 9223372036854775808u64\nend function\n");
        }
        let name = format!("width-{group}.bnt");
        fs::write(output.join(&name), &source).unwrap();
        let checked = pipeline::check_text(
            &name,
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
        let mut named = named::Export::new();
        named.push("golden", &name, checked.program.as_ref().unwrap(), &stdlib);
        let input = named.inputs.pop().unwrap();
        builtin_inputs.extend(named.tables);
        stdlib_inputs.extend(named.declarations);
        coverage_inputs.extend(named.coverage);
        assert_eq!(input["excluded"], json!([]));
        let definitions = input["definitions"].as_array().unwrap();
        assert_eq!(
            definitions.len(),
            widths.len() * 4 + usize::from(group != "signed")
        );
        for definition in definitions {
            assert!(
                definition["scope"].get("inScope").is_some(),
                "{name}: {definition}"
            );
        }
        // 型ごとに演算と標準関数を対象内に保ち、型の追加だけの空の確認にしない。
        for (ty, _) in widths {
            let standard = if ty == "Float32" {
                "squareRoot"
            } else {
                "minimum"
            };
            assert!(
                contains_json(&input["definitions"], &json!({"base":{"name":ty}})),
                "{name}: {ty}"
            );
            assert!(
                builtin_inputs.last().unwrap()["prims"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .any(|p| p["name"] == format!("{ty}.{standard}")),
                "{name}: {ty}.{standard}"
            );
        }
        inputs.push(input);
    }
    let annotations = export_annotations(&inputs);
    write_exchange(&output, inputs, builtin_inputs, stdlib_inputs, annotations);
    fs::write(
        output.join("coverage.json"),
        exchange::to_vec(&json!({"version":5,"inputs":coverage_inputs})).unwrap(),
    )
    .unwrap();
    // メモリ上の表だけでなく、Lean が読むファイルにも境界値とビットが残ることを確かめる。
    let corpus: Value =
        serde_json::from_slice(&fs::read(output.join("corpus.json")).unwrap()).unwrap();
    for expected in [
        json!({"integer8":{"value":-128}}),
        json!({"integer16":{"value":-32768}}),
        json!({"integer32":{"value":-2147483648_i64}}),
        json!({"unsignedInteger16":{"value":65535}}),
        json!({"unsignedInteger32":{"value":4294967295_u64}}),
        json!({"unsignedInteger64":{"value":9223372036854775808_u64}}),
        json!({"unsignedInteger64":{"value":u64::MAX}}),
        json!({"float32":{"bits":0x3f800000_u32}}),
        json!({"float32":{"bits":0x80000000_u32}}),
    ] {
        assert!(
            contains_json(&corpus["inputs"], &expected),
            "missing {expected}"
        );
    }
    eprintln!(
        "width export: 3 inputs; {:.3}s; {}",
        start.elapsed().as_secs_f64(),
        output.display()
    );
}

fn contains_json(value: &Value, expected: &Value) -> bool {
    value == expected
        || match value {
            Value::Array(values) => values.iter().any(|v| contains_json(v, expected)),
            Value::Object(values) => values.values().any(|v| contains_json(v, expected)),
            Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => false,
        }
}

fn sidecar(stem: &Path, suffix: &str) -> PathBuf {
    let mut p = stem.as_os_str().to_os_string();
    p.push(format!(".{suffix}"));
    PathBuf::from(p)
}

// golden.rs の discover_scripts と同じ規則。bench の入力は含めない。
fn discover(root: &Path) -> Vec<PathBuf> {
    let mut pending = vec![root.to_owned()];
    let mut inputs = Vec::new();
    while let Some(dir) = pending.pop() {
        let mut entries: Vec<_> = fs::read_dir(&dir).unwrap().map(Result::unwrap).collect();
        entries.sort_by_key(fs::DirEntry::file_name);
        for entry in entries {
            let path = entry.path();
            if entry.file_type().unwrap().is_dir() {
                let name = entry.file_name();
                let name = name.to_string_lossy();
                if name.ends_with(".files") || name.ends_with(".formatted") {
                    continue;
                }
                if sidecar(&path, "mode").is_file() {
                    inputs.push(path);
                } else {
                    pending.push(path);
                }
            } else if path.extension().is_some_and(|e| e == "bnt") {
                inputs.push(path);
            }
        }
    }
    inputs.sort();
    inputs
}

fn export(
    group: &str,
    name: &str,
    checked: pipeline::CheckResult,
    builtin_inputs: Option<(&mut Vec<Value>, &mut Vec<Value>, &pipeline::CheckedProgram)>,
    coverage_inputs: &mut Vec<Value>,
) -> Value {
    // 検査が失敗した入力も、処理系の不具合を単なる除外に隠さない。
    assert!(
        checked
            .diagnostics
            .iter()
            .all(|d| d.kind != benitoite::diag::ReportKind::Internal),
        "{name}: internal check error: {:?}",
        checked.diagnostics
    );
    let Some(program) = checked.program else {
        assert!(
            checked.error_count() > 0,
            "{name}: no checked program without an error"
        );
        let errors: Vec<_> = checked
            .diagnostics
            .iter()
            .filter(|d| d.is_error())
            .map(|d| format!("{:?}", d.code))
            .collect();
        return json!({"group":group,"name":name,"excluded":errors,"dataTypes":[],"definitions":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[],"constants":[]});
    };
    if program.resolved.externals.iter().next().is_some() {
        return json!({"group":group,"name":name,"excluded":["external function"],"dataTypes":[],"definitions":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[],"constants":[]});
    }
    let core = pipeline::desugar_checked(&program).unwrap_or_else(|e| panic!("{name}: {e:?}"));
    let tables = exchange::named_operation_tables(&program, &core);
    let classes = exchange::named_class_tables(&program, &core);
    let (definitions, constants, coverage) = exchange::named_program_parts(&program, &core);
    coverage_inputs.push(json!({"group":group,"name":name,
        "matches":coverage.matches,"bindings":coverage.bindings}));
    let mut input = json!({"group":group,"name":name,"excluded":[],
        "ops":tables["ops"],"effects":tables["effects"],"primOps":tables["primOps"],
        "classes":classes["classes"],"impls":classes["impls"],
        "definitions":definitions,"constants":constants});
    if let Some((inputs, declarations, stdlib)) = builtin_inputs {
        declarations.push(exchange::named_stdlib_declarations(&program, &core, &input));
        let table = exchange::named_builtin_tables(&program, &input, stdlib);
        exchange::attach_metadata(&mut input, &table, coverage_inputs.last_mut().unwrap());
        inputs.push(table);
    } else {
        let table = exchange::named_builtin_tables(&program, &input, &exchange::complete_stdlib());
        exchange::attach_metadata(&mut input, &table, coverage_inputs.last_mut().unwrap());
    }
    input
}

// 書き出し先の検査は短い入力と全 corpus で揃え、リンク経由の逸脱も拒否する。
fn export_directory(purpose: &str) -> PathBuf {
    let repo = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .unwrap();
    let output = std::env::var_os("BENITOITE_DESUGAR_DIFF_DIR").map_or_else(
        || repo.join(format!("target/{purpose}/export-{}", std::process::id())),
        PathBuf::from,
    );
    let output = if output.is_relative() {
        repo.join(output)
    } else {
        output
    };
    assert!(
        output.starts_with(&repo)
            && !output
                .components()
                .any(|c| c == std::path::Component::ParentDir),
        "output must stay inside this repository"
    );
    // 存在する親を先に調べ、リポジトリの外を指すリンクの先に作らない。
    let ancestor = output.ancestors().find(|p| p.exists()).unwrap();
    assert!(
        ancestor.canonicalize().unwrap().starts_with(&repo),
        "output ancestor must stay inside this repository"
    );
    fs::create_dir_all(&output).unwrap();
    output
}

// 表層の注釈の位置を同じ走査で集計し、短い corpus にも検査に必要な項目を残す。
fn export_annotations(inputs: &[Value]) -> std::collections::BTreeMap<String, [usize; 2]> {
    // 表層の実行器は、照合を含まない入力でも末尾の照合の件数を読む。
    let mut annotations = std::collections::BTreeMap::from([("tailMatch".to_owned(), [0, 0])]);
    for input in inputs {
        for definition in input["definitions"].as_array().unwrap() {
            for (kind, counts) in definition["annotations"].as_object().unwrap() {
                let total = annotations.entry(kind.clone()).or_default();
                total[0] += usize::try_from(counts[0].as_u64().unwrap()).unwrap();
                total[1] += usize::try_from(counts[1].as_u64().unwrap()).unwrap();
            }
        }
    }
    annotations
}

// 名前付きの標準関数を含む幅付きの入力は、新形式の型と対応表を保つ。
fn write_exchange(
    output: &Path,
    inputs: Vec<Value>,
    builtin_inputs: Vec<Value>,
    stdlib_inputs: Vec<Value>,
    annotations: std::collections::BTreeMap<String, [usize; 2]>,
) -> Value {
    let corpus = json!({"version":13,"operators":exchange::operators(),"inputs":inputs,"annotations":annotations});
    fs::write(
        output.join("corpus.json"),
        exchange::to_vec(&corpus).unwrap(),
    )
    .unwrap();
    // 新しい契約名を型表にも保持する。
    fs::write(
        output.join("builtins.json"),
        exchange::to_vec(&json!({"version":5,"inputs":builtin_inputs})).unwrap(),
    )
    .unwrap();
    fs::write(
        output.join("stdlib-decls.json"),
        exchange::to_vec(&json!({"version":5,"inputs":stdlib_inputs})).unwrap(),
    )
    .unwrap();
    corpus
}

// corpus と各表は同じ入力順で直ちに書き、注釈と分類の件数だけを保持する。
struct CorpusStream {
    inputs: exchange::InputStream,
    builtins: exchange::InputStream,
    declarations: exchange::InputStream,
    coverage: exchange::InputStream,
    annotations: std::collections::BTreeMap<String, [usize; 2]>,
    counts: [usize; 3],
}

impl CorpusStream {
    fn new(output: &Path, prefix: &str) -> Self {
        Self {
            inputs: exchange::InputStream::new(output, &format!("{prefix}corpus")),
            builtins: exchange::InputStream::new(output, &format!("{prefix}builtins")),
            declarations: exchange::InputStream::new(output, &format!("{prefix}stdlib")),
            coverage: exchange::InputStream::new(output, &format!("{prefix}coverage")),
            annotations: export_annotations(&[]),
            counts: [0; 3],
        }
    }

    fn push(
        &mut self,
        input: Value,
        tables: Vec<Value>,
        declarations: Vec<Value>,
        coverage: Vec<Value>,
    ) {
        let class =
            if !input["excluded"].as_array().unwrap().is_empty() {
                2
            } else if input["definitions"].as_array().unwrap().iter().any(|d| {
                d["scope"].get("inScope").is_some() || d["scope"].get("accessor").is_some()
            }) {
                0
            } else {
                1
            };
        self.counts[class] += 1;
        for (kind, counts) in export_annotations(std::slice::from_ref(&input)) {
            let total = self.annotations.entry(kind).or_default();
            total[0] += counts[0];
            total[1] += counts[1];
        }
        self.inputs.push(&input);
        for table in tables {
            self.builtins.push(&table);
        }
        for declaration in declarations {
            self.declarations.push(&declaration);
        }
        for item in coverage {
            self.coverage.push(&item);
        }
    }

    fn export(
        &mut self,
        group: &str,
        name: &str,
        checked: pipeline::CheckResult,
        stdlib: &pipeline::CheckedProgram,
    ) {
        let mut tables = vec![];
        let mut declarations = vec![];
        let mut coverage = vec![];
        let input = export(
            group,
            name,
            checked,
            Some((&mut tables, &mut declarations, stdlib)),
            &mut coverage,
        );
        self.push(input, tables, declarations, coverage);
    }

    fn finish(self, output: &Path, stem: &str) {
        self.inputs.finish(
            &output.join(format!("{stem}-corpus.json")),
            json!({"version":13,"operators":exchange::operators(),"annotations":self.annotations}),
        );
        self.builtins.finish(
            &output.join(format!("{stem}-builtins.json")),
            json!({"version":5}),
        );
        self.declarations.finish(
            &output.join(format!("{stem}-stdlib.json")),
            json!({"version":5}),
        );
        self.coverage.finish(
            &output.join(format!("{stem}-coverage.json")),
            json!({"version":5}),
        );
    }
}

// 関門: 公開の脱糖が、独立して証明した Lean の脱糖に対応するという契約を守る。
// 変数の移動、引数の評価順、末尾位置、構成子・演算子の選択の退行を検出する。
// 既存の IR 型検査と VM/参照実行器の比較は、型の付く誤った脱糖を検出できない。
// 本番の API と serde の導出を足さず、公開の AST と各段の出力だけを読む。
// E2 の追加: 入力ごとの宣言表を Lean で変換し、prim・構成子の書き出し漏れを検出する。
// 型保存の差分比較だけでは、型検査のための宣言表の欠けや opaque の型引数を検出できない。
// E1c-2: 型検査が受理した表層の照合を Lean の独立した網羅性判定と比較する。
// 既存の手順単独の比較は、実際の型検査が使う型・宣言との対応を検査しない。
#[test]
#[ignore = "formal: scripts/check-formal.sh が走らせる"]
fn export_desugar_corpus() {
    let start = Instant::now();
    let output = export_directory("desugar-diff");
    let stdlib = exchange::complete_stdlib();
    let mut named_stream = CorpusStream::new(&output, "named-programs-");
    for path in discover(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("testdata")
            .as_path(),
    ) {
        let relative = path.strip_prefix(env!("CARGO_MANIFEST_DIR")).unwrap();
        let stem = if path.is_dir() {
            path.clone()
        } else {
            path.with_extension("")
        };
        let mode = fs::read_to_string(sidecar(&stem, "mode")).unwrap();
        let options = CheckOptions {
            require_main: mode.trim() != "test",
            deny_warnings: false,
        };
        match pipeline::check_path(&path, options) {
            Ok(checked) => named_stream.export("golden", &relative.display().to_string(), checked, &stdlib),
            Err(error) => named_stream.push(
                json!({"group":"golden","name":relative.display().to_string(),
                "excluded":[format!("entry: {error:?}")],"dataTypes":[],"definitions":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[],"constants":[]}), vec![], vec![], vec![],
            ),
        }
    }
    for seed in 0..1000 {
        let generated = generator::generate_formal(seed);
        let name = format!("random-{seed}.bnt");
        // 反例の再現用。生成器の後の変更にも依存しない。
        fs::write(output.join(&name), &generated.source).unwrap();
        let checked = pipeline::check_text(
            &name,
            generated.source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: generated program failed check: {:?}",
            checked.diagnostics
        );
        let program = checked.program.as_ref().unwrap();
        assert!(named::contracts_well_formed(program));
        let mut named_programs = named::Export::new();
        named_programs.push("random", &name, program, &stdlib);
        let input = named_programs.inputs.pop().unwrap();
        named_stream.push(
            input,
            named_programs.tables,
            named_programs.declarations,
            named_programs.coverage,
        );
    }
    let [exported, outside, excluded] = named_stream.counts;
    let total = named_stream.inputs.count;
    assert_eq!(exported + outside + excluded, total);
    assert!(exported > 0, "empty comparison corpus");
    eprintln!(
        "desugar annotations [positions, different from R]: {:?}",
        named_stream.annotations
    );
    named_stream.finish(&output, "named-programs");
    eprintln!(
        "desugar export: {exported} exported, {outside} out of scope, {excluded} excluded (check error); {} inputs; {:.3}s; {}",
        total,
        start.elapsed().as_secs_f64(),
        output.display()
    );
}

// 関門: 独立した非空の入力で、脱糖・型検査・網羅性を同じ出力へ接続する。
// 全件と識別子を分け、六つの正式入口で同じ契約を検査する。
#[test]
fn export_independent_program_exchange() {
    let output = export_directory("independent-program");
    let stdlib = exchange::complete_stdlib();
    let mut independent = CorpusStream::new(&output, "independent-program-");
    // 呼び出しを含まない本体も、名前を保持して比較する（設計書 07-04「証明する性質」）。
    let checked = pipeline::check_text(
        "independent-program",
        b"function identity(x: Integer) -> Integer\n return match x with\n case _ -> x\n end match\nend function\n",
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    independent.export("golden", "independent-program", checked, &stdlib);
    independent.finish(&output, "independent-program");
}

// 関門: 交換形式は Return 直下の ConstRef だけを計算へ置き換える。
// 脱糖の形が変わって値の位置に残った参照を、誤った展開や単なる不一致にしない。
// 型検査済みの入力では現在この形は現れないので、公開のコア出力を変えて境界を検査する。
#[test]
fn export_rejects_constref_in_value_position() {
    use benitoite::ir::core_ir::{CompKind, ValKind, VarId};
    let checked = pipeline::check_text(
        "constant-position.bnt",
        b"const fixed: Integer = 7 + 2\nfunction sample() -> Integer\n return fixed\nend function\n",
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let program = checked.program.unwrap();
    let mut core = pipeline::desugar_checked(&program).unwrap();
    let (definitions, _, _) = exchange::definitions(&program, &core);
    let definition = definitions
        .iter()
        .find(|d| d["name"].as_str().unwrap().starts_with("sample ("))
        .unwrap();
    assert!(definition["scope"].get("inScope").is_some());
    let sample = core.defs.iter_mut().find(|d| d.name == "sample").unwrap();
    let CompKind::Return(value) = &sample.body.kind else {
        panic!("sample constant reference is not Return");
    };
    let original = value.clone();
    sample.body.kind = CompKind::Escape(value.clone());
    let (definitions, _, _) = exchange::definitions(&program, &core);
    let definition = definitions
        .iter()
        .find(|d| d["name"].as_str().unwrap().starts_with("sample ("))
        .unwrap();
    assert_eq!(
        definition["scope"],
        json!({"outOfScope":{"elements":["constant reference outside Return"]}})
    );
    // この理由以外のコアの書き出し漏れは、対象外へ戻して隠さない。
    let sample = core.defs.iter_mut().find(|d| d.name == "sample").unwrap();
    let mut unbound = original;
    unbound.kind = ValKind::Var(VarId(u32::MAX));
    sample.body.kind = CompKind::Return(unbound);
    let (definitions, _, _) = exchange::definitions(&program, &core);
    let definition = definitions
        .iter()
        .find(|d| d["name"].as_str().unwrap().starts_with("sample ("))
        .unwrap();
    assert_eq!(
        definition["scope"]["inScope"]["core"]["body"]["ret"]["value"],
        json!({"unsupported":{"name":"unbound core variable"}})
    );
}

// 関門: Decimal の仮数を交換形式へ精度を失わず整数として書く契約を守る。
// arbitrary_precision を外すと json! が大きい i128 を拒む退行と、Float への丸めを捕まえる。
// 既存の生成例の受理の検査は最終のバイト列を読まず、この契約には届かない。
#[test]
fn export_preserves_decimal_mantissas_as_exact_json_integers() {
    let checked = pipeline::check_text(
        "decimal-mantissas.bnt",
        b"function sample() -> List[Decimal]\n  return [79228162514264337593543950335m, -79228162514264337593543950335m, 1.25m]\nend function\nfunction main() -> Unit\nend function\n",
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let input = export(
        "decimal",
        "decimal-mantissas.bnt",
        checked,
        None,
        &mut Vec::new(),
    );
    let sample = input["definitions"]
        .as_array()
        .unwrap()
        .iter()
        .find(|definition| definition["name"].as_str().unwrap().starts_with("sample ("))
        .unwrap();
    assert!(sample["scope"].get("inScope").is_some());
    let bytes = exchange::to_vec(sample).unwrap();
    let written = String::from_utf8(bytes).unwrap();
    for decimal in [
        r#""decimal":{"mantissa":79228162514264337593543950335,"scale":0}"#,
        r#""decimal":{"mantissa":-79228162514264337593543950335,"scale":0}"#,
        r#""decimal":{"mantissa":125,"scale":2}"#,
    ] {
        assert!(written.contains(decimal), "missing {decimal}: {written}");
    }
    assert!(
        written.contains(r#""negDecimal":{"mantissa":79228162514264337593543950335,"scale":0}"#)
    );
    assert!(!written.contains(r#""mantissa":""#));
}

// 関門: ガード内の handle が自分の継続を再開する生成例は、検査と書き出しの対象に残す。
// 生成器が拒否される入力を作る退行と、書き出しがこの形を対象外にする退行を捕まえる。
// CLI の実行テストでは書き出しの対象範囲を確かめられず、専用の差し込み口は不要。
#[test]
fn export_accepts_generated_guard_local_handler() {
    let generated = generator::generate_formal(0);
    let checked = pipeline::check_text(
        "guard-scope.bnt",
        generated.source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let mut exports = named::Export::new();
    exports.push(
        "random",
        "guard-scope.bnt",
        checked.program.as_ref().unwrap(),
        &exchange::complete_stdlib(),
    );
    let input = exports.inputs.pop().unwrap();
    let definitions = input["definitions"].as_array().unwrap();
    let definition = definitions
        .iter()
        .find(|d| {
            d["name"]
                .as_str()
                .unwrap()
                .starts_with("formalPatternGuardLocal (")
        })
        .unwrap();
    assert!(definition["scope"].get("inScope").is_some(), "{definition}");
}

// spec: 01-02 部分適用のプレースホルダ
// 関門: 新しい生成例を公開の書き出しで inScope に保つ。CLI のゴールデンは
// 差分検査の対象外への退行を捕まえない。既存の生成器と export を使い、差し込み口は不要。
#[test]
fn export_accepts_generated_placeholder_escapes() {
    let generated = generator::generate_formal(0);
    let checked = pipeline::check_text(
        "placeholder-escapes.bnt",
        generated.source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let mut exports = named::Export::new();
    exports.push(
        "random",
        "placeholder-escapes.bnt",
        checked.program.as_ref().unwrap(),
        &exchange::complete_stdlib(),
    );
    let input = exports.inputs.pop().unwrap();
    let definitions = input["definitions"].as_array().unwrap();
    for name in ["formalPlaceholderReturn", "formalPlaceholderTry"] {
        let definition = definitions
            .iter()
            .find(|d| {
                d["name"]
                    .as_str()
                    .unwrap()
                    .starts_with(&format!("{name} ("))
            })
            .unwrap();
        assert!(definition["scope"].get("inScope").is_some(), "{definition}");
    }
}

// 型注釈の出力だけを、独立した新形式の表層・期待コアへ渡す。
// 宣言とラムダの新形式への接続は、契約の出どころを確定した後に行う。
#[test]
fn export_named_types_smoke() {
    let output = export_directory("named-types");
    let source = "type Callback[T] = function(value: T) -> T\nfunction identity(callback: Callback[Integer]) -> Callback[Integer]\n return callback\nend function";
    let checked = pipeline::check_text(
        "named-types.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let scheme = p
        .types
        .decl_types
        .iter()
        .find(|(id, _)| p.resolved.bindings.get(*id).unwrap().name == "identity")
        .unwrap()
        .1;
    let ty = exchange::named_type(&p, &scheme.params[0]);
    let integer = json!({"base":{"name":"Integer"}});
    let expected = json!({"fn":{"names":["value"],"params":[integer],"ret":integer,"eff":[]}});
    assert_eq!(ty, expected);
    assert_eq!(exchange::named_type(&p, &scheme.ret), expected);
    let header = |ty: Value| json!({"tparams":[],"neffs":0,"effParams":[],"names":["callback"],"params":[ty],"ret":ty,"eff":[]});
    let surface = json!({"package":"root","header":header(ty.clone()),"dictParams":[],"body":{"last":{"expr":{"returnE":{"ret":ty,"inner":{"local":{"index":0}}}}}},"implementation":null,"method":null,"supers":[]});
    // この期待コアは脱糖の出力を使わず、独立した型と変数の規則から書く。
    let core = json!({"header":header(expected),"body":{"ret":{"value":{"var":{"index":0}}}},"lambdaEffects":[],"supers":[]});
    // 固定した Lean 入力の版と、Rust の現在の書き出しの版を独立に保つ
    // （設計書 07-04「01-12 との対応」）。
    let mut input = named::input(
        "named-types",
        vec![json!({"name":"identity (fn:1)","scope":{"inScope":{"surface":surface,"core":core}}})],
    );
    let table = exchange::named_builtin_tables(&p, &input, &exchange::complete_stdlib());
    exchange::attach_metadata(&mut input, &table, &mut Value::Null);
    let corpus = json!({"version":13,"operators":exchange::operators(),
        "inputs":[input],"annotations":{"tailMatch":[0,0]}});
    fs::write(
        output.join("named-types-corpus.json"),
        serde_json::to_vec_pretty(&corpus).unwrap(),
    )
    .unwrap();
    named::write_tables(&output, "named-types", &p, &corpus["inputs"][0]);
}

// 型だけを独立入力へ差し込む検査と異なり、宣言・ラムダの表層とコアを両方 Rust から得る。
#[test]
fn export_named_declarations_smoke() {
    let output = export_directory("named-declarations");
    let checked = pipeline::check_text(
        "named-declarations.bnt",
        b"function identity(actual: Integer) -> Integer\n return actual\nend function\nfunction make(captured: Integer) -> function(value: Integer) -> Integer\n return lambda(value) return captured\nend function",
        CheckOptions { require_main: false, deny_warnings: false },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let p = checked.program.unwrap();
    let core = pipeline::desugar_checked(&p).unwrap();
    let definitions = exchange::named_definitions(&p, &core);
    assert_eq!(definitions.len(), 2);
    let identity = &definitions
        .iter()
        .find(|d| d["name"].as_str().unwrap().starts_with("identity ("))
        .unwrap()["scope"]["inScope"];
    assert_eq!(identity["surface"]["header"]["names"], json!(["actual"]));
    assert_eq!(identity["core"]["header"]["names"], json!(["actual"]));
    let make = &definitions
        .iter()
        .find(|d| d["name"].as_str().unwrap().starts_with("make ("))
        .unwrap()["scope"]["inScope"];
    let integer = json!({"base":{"name":"Integer"}});
    assert_eq!(
        make["surface"]["header"]["ret"],
        json!({"fn":{"names":["value"],"params":[integer],"ret":integer,"eff":[]}})
    );
    assert!(contains_json(&make["surface"]["body"], &json!(["value"])));
    assert_eq!(
        make["core"]["body"],
        json!({"ret":{"value":{"lam":{"names":["value"],"params":[integer],"body":{"ret":{"value":{"var":{"index":1}}}}}}}})
    );
    let mut input = named::input("named-declarations", definitions);
    let table = exchange::named_builtin_tables(&p, &input, &exchange::complete_stdlib());
    exchange::attach_metadata(&mut input, &table, &mut Value::Null);
    let corpus = json!({"version":13,"operators":exchange::operators(),
        "inputs":[input],"annotations":{"tailMatch":[0,0]}});
    fs::write(
        output.join("named-declarations-corpus.json"),
        serde_json::to_vec_pretty(&corpus).unwrap(),
    )
    .unwrap();
    named::write_tables(&output, "named-declarations", &p, &corpus["inputs"][0]);
}

// 関門: 実ソースの辞書の全呼び出しを12/4の五形式へ渡す。
// 対象外と空の比較は失敗にし、独立したLeanの六入口が結果を照合する。
#[test]
fn export_batch2_op() {
    let output = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/formal-batch2-op");
    fs::create_dir_all(&output).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut export = named::Export::new();
    for &(name, declarations, expression, expected) in operation_dictionaries::CASES {
        let source = operation_dictionaries::source(declarations, expression, expected)
            + "\nfunction coverage(value: Integer) -> Integer\n return match value with case _ -> 0 end match\nend function\n";
        let checked = pipeline::check_text(
            name,
            source.as_bytes(),
            CheckOptions {
                require_main: true,
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
        export.push("golden", name, program, &stdlib);
        let input = export.inputs.last().unwrap();
        assert_eq!(input["excluded"], json!([]));
        let definitions = input["definitions"].as_array().unwrap();
        assert!(definitions.len() >= 2, "{name}: empty comparison");
        for definition in definitions {
            assert!(
                definition["scope"].get("inScope").is_some(),
                "{name}: {definition}"
            );
        }
        fs::write(output.join(format!("{name}.bnt")), source).unwrap();
    }
    write_batch2(&output, export);
}

// 全域の束縛とサロゲート前後の範囲を、実ソースから六入口へ接続する。
#[test]
fn export_batch2_character() {
    let output = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/formal-batch2-character");
    fs::create_dir_all(&output).unwrap();
    let source = include_str!("../testdata/patterns/p1-character-domain.bnt");
    let checked = pipeline::check_text(
        "character-domain",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let mut export = named::Export::new();
    export.push(
        "golden",
        "character-domain",
        checked.program.as_ref().unwrap(),
        &exchange::complete_stdlib(),
    );
    assert_eq!(export.inputs[0]["excluded"], json!([]));
    let definitions = export.inputs[0]["definitions"].as_array().unwrap();
    assert_eq!(definitions.len(), 4);
    assert_eq!(
        definitions
            .iter()
            .map(|definition| definition["name"]
                .as_str()
                .unwrap()
                .split_once(" (")
                .unwrap()
                .0)
            .collect::<Vec<_>>(),
        vec![
            "classify",
            "correlatedBoolean",
            "correlatedCharacter",
            "main"
        ]
    );
    write_batch2(&output, export);
    // 独立の文字全域の入力と同じ形を、本番の判定 API で書き出す。
    let ty = benitoite::types::Ty::Con(
        benitoite::types::TyCon::Builtin(benitoite::types::builtin::BuiltinTypeId::CHARACTER),
        vec![],
    );
    write_batch2_coverage(&output, &ty, json!({"kind":"character","args":[]}));
    fs::write(output.join("character-domain.bnt"), source).unwrap();
}

fn write_batch2(output: &Path, export: named::Export) {
    let annotations = export_annotations(&export.inputs);
    write_exchange(
        output,
        export.inputs,
        export.tables,
        export.declarations,
        annotations,
    );
    fs::rename(output.join("stdlib-decls.json"), output.join("stdlib.json")).unwrap();
    let coverage = json!({"version":5,"inputs":export.coverage});
    fs::write(
        output.join("coverage-program.json"),
        exchange::to_vec(&coverage).unwrap(),
    )
    .unwrap();
    let ty = benitoite::types::Ty::Con(
        benitoite::types::TyCon::Builtin(benitoite::types::builtin::BuiltinTypeId::INTEGER),
        vec![],
    );
    write_batch2_coverage(output, &ty, json!({"kind":"integer","args":[]}));
}

fn write_batch2_coverage(output: &Path, ty: &benitoite::types::Ty, ty_json: Value) {
    // 単独の網羅性とプログラム内の網羅性は異なる交換形式である。
    use benitoite::typeck::patterns::{
        ArmPats, CoverageView, MatchIssue, Pat, check_binding, check_match,
    };
    use benitoite::types::AdtTable;
    let table = AdtTable::default();
    let view = CoverageView::new();
    let pattern = if ty
        == &benitoite::types::Ty::Con(
            benitoite::types::TyCon::Builtin(benitoite::types::builtin::BuiltinTypeId::CHARACTER),
            vec![],
        ) {
        Pat::CharacterRange('\0', '\u{10ffff}')
    } else {
        Pat::Wild
    };
    let pattern_json = if matches!(pattern, Pat::CharacterRange(..)) {
        json!({"kind":"characterRange","lo":0,"hi":0x10ffff})
    } else {
        json!({"kind":"wild"})
    };
    let checked = check_match(
        ty,
        &[ArmPats {
            alts: vec![pattern.clone()],
            guarded: false,
        }],
        &table,
        &view,
    )
    .unwrap();
    let binding = check_binding(ty, &pattern, &table, &view).unwrap();
    let mut uncovered = None;
    let mut unreachable = Vec::new();
    for issue in checked.issues {
        match issue {
            MatchIssue::NonExhaustive { witness, .. } => uncovered = Some(witness),
            MatchIssue::Unreachable {
                arm,
                alt,
                covered_by,
            } => unreachable.push(json!({"arm":arm,"alt":alt,"coveredBy":covered_by})),
        }
    }
    let cases = [
        json!({"name":"batch2-result-coverage","decls":[],"package":"root","coverageView":[],
        "ty":ty_json,"arms":[{"guarded":false,"alts":[pattern_json.clone()]}],
        "pattern":pattern_json,"expected":{"exhaustive":uncovered.is_none(),"uncovered":uncovered,"unreachable":unreachable},
        "irrefutable":binding.witness.is_none(),"irrefutableWitness":binding.witness}),
    ];
    fs::write(
        output.join("coverage.json"),
        exchange::to_vec(&json!({"version":5,"seedXor":0,"randomCases":0,
        "boundaryCases":cases.len(),"kinds":{},"cases":cases}))
        .unwrap(),
    )
    .unwrap();
}

// 関門: Fail の型・節・署名由来の Q を実ソースから独立の Lean 検査へ渡す。
// VM の成功だけでは交換の欠落を検出できず、既存の書き出しを用いる。
#[test]
fn export_batch2_failure() {
    let output = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/formal-batch2-failure");
    fs::create_dir_all(&output).unwrap();
    let stdlib = exchange::complete_stdlib();
    let mut export = named::Export::new();
    let mut coverage_type = None;
    for (name, source) in [
        (
            "failure-polymorphic",
            r#"import Benitoite.Unofficial.Failure
function raiseValue[T, E](error: E) -> T uses Failure.Fail[E]
  return Failure.raise(error)
end function
function capture[T, E, effect Rest](body: function() -> T uses Failure.Fail[E], Rest) -> Result[T, E] uses Rest
  return Failure.toResult(body: body)
end function
function nested(value: Integer) -> Result[Integer, String]
  return Failure.toResult(body: lambda() return Failure.fromResult(Result.Ok(value)) end lambda)
end function
function coverage(value: function(input: Integer) -> Integer uses Failure.Fail[String]) -> Integer
  return match value with case _ -> 0 end match
end function
"#,
        ),
        (
            "failure-handlers",
            r#"import Benitoite.Unofficial.Failure
function translated() -> Integer uses Failure.Fail[Integer]
  return handle Failure.raise("inner") with
    case Failure.raise(error) -> Failure.raise(String.characterCount(error))
  end handle
end function
function capture[E](body: function() -> Integer uses Failure.Fail[E]) -> Result[Integer, E]
  return handle Result.Ok(body()) with
    case Failure.raise(error) -> Result.Error(error)
  end handle
end function
function latent(body: function() -> Integer uses Failure.Fail[String]) -> function() -> Integer uses Failure.Fail[String]
  return body
end function
function nestedType(body: function() -> Integer uses Failure.Fail[function() -> String uses Failure.Fail[Integer]]) -> Integer uses Failure.Fail[function() -> String uses Failure.Fail[Integer]]
  return body()
end function
"#,
        ),
        (
            "failure-values",
            r#"import Benitoite.Unofficial.Failure
trait Attempt[T]
  function attempt[effect Rest](value: T, body: function() -> Integer uses Failure.Fail[String], Rest) -> Result[Integer, String] uses Rest
end trait
implement Attempt[Integer]
  function attempt[effect Rest](value: Integer, body: function() -> Integer uses Failure.Fail[String], Rest) -> Result[Integer, String] uses Rest
    return Failure.toResult(body: body)
  end function
end implement
function throughMethod[effect Rest](body: function() -> Integer uses Failure.Fail[String], Rest) -> Result[Integer, String] uses Rest
  return Attempt.attempt(value: 0, body: body)
end function
function partial(error: String) -> Integer uses Failure.Fail[String]
  bind fail: function(error: String) -> Integer uses Failure.Fail[String] <- Failure.raise(error: _)
  return error |> fail
end function
function pipe(error: String) -> Integer uses Failure.Fail[String]
  return error |> Failure.raise
end function
"#,
        ),
        (
            "failure-nofail",
            r#"import Benitoite.Unofficial.Failure
function capture[effect Rest](body: function() -> Integer uses Failure.Fail[String], Rest) -> Result[Integer, String] uses Rest
  return Failure.toResult(body: body)
end function
"#,
        ),
    ] {
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
        if name == "failure-polymorphic" {
            let ty = program
                .types
                .decl_types
                .iter()
                .find(|(id, _)| program.resolved.bindings.get(*id).unwrap().name == "coverage")
                .unwrap()
                .1
                .params[0]
                .clone();
            let encoded = exchange::named_type(program, &ty);
            let integer = json!({"kind":"integer","args":[]});
            let function = &encoded["fn"];
            assert_eq!(function["names"], json!(["input"]));
            coverage_type = Some((
                ty,
                json!({"kind":"function","names":function["names"],
                "params":[integer],"ret":integer,"eff":function["eff"]}),
            ));
        }
        export.push("golden", name, program, &stdlib);
        let input = export.inputs.last().unwrap();
        assert_eq!(input["excluded"], json!([]));
        assert!(!input["definitions"].as_array().unwrap().is_empty());
        for definition in input["definitions"].as_array().unwrap() {
            assert!(
                definition["scope"].get("inScope").is_some(),
                "{name}: {definition}"
            );
        }
        fs::write(output.join(format!("{name}.bnt")), source).unwrap();
        if name == "failure-nofail" {
            let rejected_source = source.replace("uses Failure.Fail[String], Rest", "uses Rest");
            let rejected = pipeline::check_text(
                "failure-nofail-rejected",
                rejected_source.as_bytes(),
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            assert_eq!(rejected.error_count(), 1, "{:?}", rejected.diagnostics);
            assert_eq!(
                rejected.diagnostics[0].code,
                Some(benitoite::diag::DiagCode::E0515)
            );
            fs::write(output.join("failure-nofail-rejected.bnt"), rejected_source).unwrap();
        }
    }
    write_batch2(&output, export);
    let (ty, ty_json) = coverage_type.unwrap();
    write_batch2_coverage(&output, &ty, ty_json);
}
