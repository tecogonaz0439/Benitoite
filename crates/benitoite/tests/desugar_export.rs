//! Lean の脱糖との差分検査用の書き出し。比較は scripts/check-formal.sh が行う。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
#[path = "desugar_export/exchange.rs"]
mod exchange;
#[path = "random_programs/generator.rs"]
pub mod generator;

use benitoite::pipeline::{self, CheckOptions};
use serde_json::{Value, json};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

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
        return json!({"group":group,"name":name,"excluded":errors,"definitions":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[],"constants":[]});
    };
    let core = pipeline::desugar_checked(&program).unwrap_or_else(|e| panic!("{name}: {e:?}"));
    let tables = exchange::operation_tables(&program, &core);
    let classes = exchange::class_tables(&program, &core);
    let (definitions, constants, coverage) = exchange::definitions(&program, &core);
    coverage_inputs.push(json!({"group":group,"name":name,
        "matches":coverage.matches,"bindings":coverage.bindings}));
    let input = json!({"group":group,"name":name,"excluded":[],
        "ops":tables["ops"],"effects":tables["effects"],"primOps":tables["primOps"],
        "classes":classes["classes"],"impls":classes["impls"],
        "definitions":definitions,"constants":constants});
    if let Some((inputs, declarations, stdlib)) = builtin_inputs {
        declarations.push(exchange::stdlib_declarations(&program, &core, &input));
        inputs.push(exchange::builtin_tables(&program, &input, stdlib));
    }
    input
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
    let repo = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .unwrap();
    let output = std::env::var_os("BENITOITE_DESUGAR_DIFF_DIR").map_or_else(
        || repo.join(format!("target/desugar-diff/export-{}", std::process::id())),
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
    let mut inputs = Vec::new();
    let mut builtin_inputs = Vec::new();
    let mut stdlib_inputs = Vec::new();
    let mut coverage_inputs = Vec::new();
    let stdlib = exchange::complete_stdlib();
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
            Ok(checked) => inputs.push(export(
                "golden", &relative.display().to_string(), checked, Some((&mut builtin_inputs, &mut stdlib_inputs, &stdlib)), &mut coverage_inputs,
            )),
            Err(error) => inputs.push(
                json!({"group":"golden","name":relative.display().to_string(),
                "excluded":[format!("entry: {error:?}")],"definitions":[],"ops":[],"effects":[],"primOps":[],"classes":[],"impls":[],"constants":[]}),
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
        inputs.push(export(
            "random",
            &name,
            checked,
            Some((&mut builtin_inputs, &mut stdlib_inputs, &stdlib)),
            &mut coverage_inputs,
        ));
    }
    let mut exported = 0;
    let mut outside = 0;
    let mut excluded = 0;
    for input in &inputs {
        if !input["excluded"].as_array().unwrap().is_empty() {
            excluded += 1;
        } else if input["definitions"]
            .as_array()
            .unwrap()
            .iter()
            .any(|d| d["scope"].get("inScope").is_some() || d["scope"].get("accessor").is_some())
        {
            exported += 1;
        } else {
            outside += 1;
        }
    }
    assert_eq!(exported + outside + excluded, inputs.len());
    assert!(exported > 0, "empty comparison corpus");
    let mut annotations = std::collections::BTreeMap::<String, [usize; 2]>::new();
    for input in &inputs {
        for definition in input["definitions"].as_array().unwrap() {
            for (kind, counts) in definition["annotations"].as_object().unwrap() {
                let total = annotations.entry(kind.clone()).or_default();
                total[0] += usize::try_from(counts[0].as_u64().unwrap()).unwrap();
                total[1] += usize::try_from(counts[1].as_u64().unwrap()).unwrap();
            }
        }
    }
    eprintln!("desugar annotations [positions, different from R]: {annotations:?}");
    let corpus = json!({"version":7,"operators":exchange::operators(),"inputs":inputs,"annotations":annotations});
    fs::write(
        output.join("corpus.json"),
        serde_json::to_vec(&corpus).unwrap(),
    )
    .unwrap();
    // corpus の原子の収集に新しい表を混ぜず、版 7 のバイト列を保存する。
    fs::write(
        output.join("builtins.json"),
        serde_json::to_vec(&json!({"version":1,"inputs":builtin_inputs})).unwrap(),
    )
    .unwrap();
    fs::write(
        output.join("stdlib-decls.json"),
        serde_json::to_vec(&json!({"version":1,"inputs":stdlib_inputs})).unwrap(),
    )
    .unwrap();
    // 同じ型検査済み AST の走査で得た照合だけを別のファイルへ書く。
    fs::write(
        output.join("coverage-matches.json"),
        serde_json::to_vec(&json!({"version":1,"inputs":coverage_inputs})).unwrap(),
    )
    .unwrap();
    eprintln!(
        "desugar export: {exported} exported, {outside} out of scope, {excluded} excluded (check error); {} inputs; {:.3}s; {}",
        corpus["inputs"].as_array().unwrap().len(),
        start.elapsed().as_secs_f64(),
        output.display()
    );
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

// 関門: TODO-190 の印はガードの外の継続を指す resume だけに付ける。
// ガード内の handle が自分の節で resume する形は、既知の差として除外してはならない。
// 比較器の失敗扱いがこの印で変わるので、通常の差分比較とは独立した境界の契約である。
#[test]
fn export_distinguishes_guard_continuation_scope() {
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
    let input = export("random", "guard-scope.bnt", checked, None, &mut Vec::new());
    let definitions = input["definitions"].as_array().unwrap();
    for (name, expected) in [
        (
            "formalPatternGuardResume (",
            vec!["ガードの中の resume（TODO-190）"],
        ),
        ("formalPatternGuardLocal (", vec![]),
    ] {
        let definition = definitions
            .iter()
            .find(|d| d["name"].as_str().unwrap().starts_with(name))
            .unwrap();
        assert!(definition["scope"].get("inScope").is_some(), "{definition}");
        assert_eq!(definition["knownDifferences"], json!(expected));
    }
    // 開発中にも同じ公開の書き出しを Lean と突き合わせられる小さなコーパスを保持する。
    let output = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/c7c");
    fs::create_dir_all(&output).unwrap();
    fs::write(
        output.join("smoke.json"),
        serde_json::to_vec(&json!({
            "version":7,"operators":exchange::operators(),"inputs":[input]
        }))
        .unwrap(),
    )
    .unwrap();
}
