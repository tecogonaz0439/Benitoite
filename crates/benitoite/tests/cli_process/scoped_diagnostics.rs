//! 関門: CLI の範囲診断に、拒否理由・注釈の位置と実行できる修正案を残す。
//! 規則の単体検査では届かない英文の退行と JSON 化の欠落を守り、案内を当てた
//! ソースも呼び出し元を含めて同じ CLI で受理する。引数だけの空の例では
//! 型不変性による呼び出し元の失敗を捕まえられない。本番の差し込み口は加えない。

use super::{TestDirectory, command, exit_code};
use serde_json::Value;

const MAIN: &str = "\nfunction main() -> Unit\nend function\n";

fn check(directory: &TestDirectory, name: &str, source: &str, code: Option<&str>) -> Vec<Value> {
    let script = directory.write(&format!("{name}.bnt"), &format!("{source}{MAIN}"));
    let output = command()
        .args(["check", "--diagnostics=json"])
        .arg(script)
        .output()
        .unwrap();
    assert_eq!(
        exit_code(&output),
        if code.is_some() { 2 } else { 0 },
        "{name}: {output:?}"
    );
    assert!(output.stdout.is_empty(), "{name}: {output:?}");
    let diagnostics: Vec<Value> = String::from_utf8(output.stderr)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    let errors: Vec<_> = diagnostics
        .iter()
        .filter(|d| d["severity"] == "error")
        .collect();
    if let Some(code) = code {
        assert_eq!(errors.len(), 1, "{name}: {diagnostics:?}");
        assert_eq!(errors[0]["code"], code, "{name}: {diagnostics:?}");
    } else {
        assert!(diagnostics.is_empty(), "{name}: {diagnostics:?}");
    }
    diagnostics
}

fn primary<'a>(source: &'a str, diagnostic: &Value) -> &'a str {
    labelled_source(source, &diagnostic["primary"])
}

fn labelled_source<'a>(source: &'a str, label: &Value) -> &'a str {
    let start = label["start"]["offset"].as_u64().unwrap() as usize;
    let end = label["end"]["offset"].as_u64().unwrap() as usize;
    &source[start..end]
}

#[test]
fn scoped_diagnostic_fields_and_effect_repairs_reach_cli() {
    let directory = TestDirectory::new();
    for (name, source, code, message) in [
        (
            "effect-arguments",
            "effect Ask\n function ask() -> Unit\nend effect\nfunction sample() -> Unit uses Ask[\"/a\"]\nend function\n",
            "E0513",
            "invalid type or scope arguments for effect `Ask` (expected type argument count: 0; scope arguments are not allowed)",
        ),
        (
            "type-scope-count",
            "import Benitoite.Unofficial.Scope\nfunction sample(path: Scope.PathIn[\"/data/**\", \"/x\"]) -> Unit\nend function\n",
            "E0520",
            "invalid scope arguments for `Scope.PathIn` (expected exactly one path string literal)",
        ),
    ] {
        let diagnostics = check(&directory, name, source, Some(code));
        assert_eq!(diagnostics[0]["message"], message);
        if code == "E0520" {
            assert_eq!(diagnostics[0]["notes"][0], "found: [\"/data/**\", \"/x\"]");
            assert_eq!(primary(source, &diagnostics[0]), "[\"/data/**\", \"/x\"]");
        } else {
            assert_eq!(primary(source, &diagnostics[0]), "Ask[\"/a\"]");
        }
    }
    let result_source = "import Benitoite.Unofficial.Scope\nfunction sample(raw: String) -> Unit\n bind value: Result[Integer, Scope.ScopeError] <- Scope.checkPathIn(pattern: \"/data/**\", path: raw)\nend function\n";
    let result_diagnostic =
        check(&directory, "scope-result", result_source, Some("E0401")).remove(0);
    assert_eq!(
        primary(result_source, &result_diagnostic),
        "Scope.checkPathIn"
    );
    assert_eq!(
        result_diagnostic["primary"]["label"],
        "expected `Integer`, found `Scope.PathIn[\"/data/**\"]`"
    );
    assert_eq!(
        result_diagnostic["notes"],
        serde_json::json!([
            "the result of this scope check or widening must match its annotated or inferred type"
        ])
    );
    // 戻り先が既に誤った型で注釈されていても、範囲の拡大先の型を案内する。
    // 通常の未確定型のテストでは、単なる注釈の追加が修正にならない退行を捕まえない。
    for (name, imports, input, operation, argument, wrong, correct) in [
        (
            "path",
            "import Benitoite.Unofficial.Scope",
            "Scope.PathIn",
            "Scope.widenPathIn",
            "path",
            "String",
            "Scope.PathIn",
        ),
        (
            "request",
            "import Benitoite.Unofficial.Network.Http",
            "Http.RequestIn",
            "Http.widenRequestIn",
            "request",
            "Http.ClientRequest",
            "Http.RequestIn",
        ),
    ] {
        let source = format!(
            "{imports}\nfunction sample(raw: {input}) -> Unit\n bind value: {wrong} <- {operation}({argument}: raw)\nend function\n"
        );
        let diagnostic = check(
            &directory,
            &format!("{name}-widen-wrong-result"),
            &source,
            Some("E0407"),
        )
        .remove(0);
        let help = diagnostic["helps"][0]["message"].as_str().unwrap();
        assert!(help.contains("existing annotation"), "{diagnostic}");
        assert!(help.contains(correct), "{diagnostic}");
        let other = if name == "path" {
            "Http.RequestIn"
        } else {
            "Scope.PathIn"
        };
        assert!(!help.contains(other), "{diagnostic}");
        check(
            &directory,
            &format!("{name}-widen-correct-result"),
            &source.replace(&format!("value: {wrong}"), &format!("value: {correct}")),
            None,
        );
    }
    let imports = "import Benitoite.Unofficial.IO.File\n";
    let old = format!(
        "{imports}function sample() -> Result[String, IOError] uses File.Read[\"/**\"]\n return File.readText(path: \"/data/a\")\nend function\n"
    );
    let diagnostic = check(&directory, "top-effect", &old, Some("E0519")).remove(0);
    assert!(
        diagnostic["message"]
            .as_str()
            .unwrap()
            .contains("unknownSource")
    );
    assert_eq!(
        primary(&old, &diagnostic),
        "File.readText(path: \"/data/a\")"
    );
    let guidance = diagnostic["helps"].to_string();
    assert!(guidance.contains("File.readTextIn"), "{diagnostic}");
    assert!(guidance.contains("annotation"), "{diagnostic}");
    assert!(guidance.contains("callee's `uses`"), "{diagnostic}");
    assert!(
        diagnostic["notes"][0]
            .as_str()
            .unwrap()
            .contains("incoming scope (knownUpperBound) is Top"),
        "{diagnostic}"
    );
    // 契約を維持する検査と In 入口、および契約を Top に広げる修正を別々に通す。
    let bounded = format!(
        "{imports}import Benitoite.Unofficial.Scope\nfunction sample(path: String) -> Result[String, IOError] uses File.Read[\"/**\"]\n bind checked: Result[Scope.PathIn[\"/**\"], Scope.ScopeError] <- Scope.checkPathIn(pattern: \"/**\", path: path)\n return match checked with\n case Result.Ok(checkedPath) -> File.readTextIn(path: checkedPath)\n case Result.Error(_) -> Result.Ok(\"failed check\")\n end match\nend function\n"
    );
    check(&directory, "bounded-effect-repair", &bounded, None);
    check(
        &directory,
        "top-effect-repair",
        &old.replace("File.Read[\"/**\"]", "File.Read"),
        None,
    );
    for (name, surrounding, reason) in [
        ("one-atom", "File.Read[\"/data/**\"]", "notCovered"),
        (
            "two-atoms",
            "File.Read[\"/data/**\", \"/backup/**\"]",
            "atomicCoverOnly",
        ),
    ] {
        let source = format!(
            "{imports}function callee() -> Unit uses File.Read[\"/**\"]\nend function\nfunction sample() -> Unit uses {surrounding}\n callee()\nend function\n"
        );
        let diagnostic = check(&directory, name, &source, Some("E0519")).remove(0);
        assert!(
            diagnostic["message"].as_str().unwrap().contains(reason),
            "{diagnostic}"
        );
        assert_eq!(primary(&source, &diagnostic), "callee()");
        for field in ["requiredUpperBound:", "knownUpperBound:", "uncoveredAtom:"] {
            assert!(
                diagnostic["notes"].to_string().contains(field),
                "{diagnostic}"
            );
        }
        let secondary = diagnostic["secondary"].as_array().unwrap();
        assert_eq!(secondary.len(), 1, "{diagnostic}");
        assert_eq!(labelled_source(&source, &secondary[0]), surrounding);
        assert_eq!(secondary[0]["label"], "declared here");
    }
    let known_source = "import Benitoite.Unofficial.Scope\nfunction sample(raw: String) -> Unit\n bind checked: Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError] <- Scope.checkPathIn(pattern: \"/data/**\", path: raw)\n match checked with\n case Result.Ok(value) ->\n  bind extracted: Scope.PathIn[\"/data/a\"] <- Scope.widenPathIn(path: value)\n  ()\n case Result.Error(_) -> ()\n end match\nend function\n";
    let diagnostic = check(&directory, "known-source", known_source, Some("E0519")).remove(0);
    assert!(
        diagnostic["message"]
            .as_str()
            .unwrap()
            .contains("scope arguments of the annotated contract"),
        "{diagnostic}"
    );
    assert!(
        diagnostic["message"]
            .as_str()
            .unwrap()
            .contains("notCovered"),
        "{diagnostic}"
    );
    let notes = diagnostic["notes"].as_array().unwrap();
    assert!(
        notes
            .iter()
            .any(|note| note
                == "requiredUpperBound: source [\"/data/**\"]; destination [\"/data/a\"]"),
        "{diagnostic}"
    );
    assert!(
        notes
            .iter()
            .any(|note| note == "knownUpperBound: [\"/data/**\"]"),
        "{diagnostic}"
    );
    assert!(
        notes.iter().any(|note| note
            .as_str()
            .unwrap()
            .starts_with("source: successful check in ")),
        "{diagnostic}"
    );
    let secondary = diagnostic["secondary"].as_array().unwrap();
    assert_eq!(secondary.len(), 2, "{diagnostic}");
    assert_eq!(
        labelled_source(known_source, &secondary[0]),
        "Scope.PathIn[\"/data/a\"]"
    );
    assert_eq!(
        secondary[0]["label"],
        "the scope contract is required by this annotation"
    );
    assert_eq!(
        labelled_source(known_source, &secondary[1]),
        "Scope.checkPathIn(pattern: \"/data/**\", path: raw)"
    );
    assert_eq!(
        secondary[1]["label"],
        "the same successful checked value originates here"
    );
    let returned = "import Benitoite.Unofficial.Scope\nfunction sample(path: String) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n return Scope.checkPathIn(pattern: path, path: path)\nend function\n";
    let diagnostic = check(&directory, "returned-contract", returned, Some("E0519")).remove(0);
    assert!(
        diagnostic["message"]
            .as_str()
            .unwrap()
            .contains("unknownSource"),
        "{diagnostic}"
    );
    let secondary = diagnostic["secondary"].as_array().unwrap();
    assert_eq!(secondary.len(), 1, "{diagnostic}");
    assert_eq!(
        labelled_source(returned, &secondary[0]),
        "Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]"
    );
    assert_eq!(
        secondary[0]["label"],
        "the scope contract is required by this annotation"
    );
    let mut source = String::from(
        "import Benitoite.Unofficial.Scope\nfunction sample(path: String) -> Result[Scope.PathIn[\"/data/**\"], Scope.ScopeError]\n",
    );
    for index in 0..513 {
        source.push_str(&format!(
            " bind kept{index} <- Scope.checkPathIn(pattern: \"/data/**\", path: path)\n"
        ));
    }
    source.push_str(" return Scope.checkPathIn(pattern: path, path: path)\nend function\n");
    let diagnostic = check(&directory, "local-budget", &source, Some("E0519")).remove(0);
    assert!(
        diagnostic["message"]
            .as_str()
            .unwrap()
            .contains("budgetExceeded"),
        "{diagnostic}"
    );
    let notes = diagnostic["notes"].to_string();
    assert!(
        notes.contains("body") && notes.contains("items"),
        "{diagnostic}"
    );
    assert!(notes.contains("literal"), "{diagnostic}");
    assert!(!notes.contains("numbering"), "{diagnostic}");
    assert!(notes.contains("the final pass of local Scope analysis"));
    assert!(
        diagnostic["helps"][0]["message"]
            .as_str()
            .unwrap()
            .contains("only if the check conditions or checked values are statically known"),
        "{diagnostic}"
    );
    check(
        &directory,
        "local-budget-top-repair",
        &source.replace("Scope.PathIn[\"/data/**\"]", "Scope.PathIn"),
        None,
    );
}

// 関門: 範囲付きの入口から worker 内の資源停止まで、実際の操作名を残す。
// 巨大な sparse file は metadata の検査で止まり、内容を読み込まない。
#[test]
fn scoped_file_input_limit_reports_the_called_operation() {
    let directory = TestDirectory::new();
    let path = directory.path().join("large");
    std::fs::File::create(&path)
        .unwrap()
        .set_len(benitoite::runtime::MAX_STRING_BYTES + 1)
        .unwrap();
    let source = format!(
        "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.IO.File\nfunction main() -> Unit uses File.Read[\"/**\"]\n bind checked: Result[Scope.PathIn[\"/**\"], Scope.ScopeError] <- Scope.checkPathIn(pattern: \"/**\", path: \"{}\")\n match checked with\n case Result.Ok(path) ->\n  bind _ <- File.readBytesIn(path: path)\n  ()\n case Result.Error(_) -> ()\n end match\nend function\n",
        path.display()
    );
    // test の失敗報告も同じ主文を持つことを、本物の worker の metadata 停止で守る。
    let source = format!(
        "{source}\n@test\nfunction upper() -> Unit uses File.Read[\"/**\"]\n main()\nend function\n"
    );
    let script = directory.write("resource.bnt", &source);
    let output = command()
        .args(["run", "--diagnostics=json"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 1, "{output:?}");
    assert!(output.stdout.is_empty(), "{output:?}");
    let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
    assert_eq!(diagnostic["code"], "R0903", "{diagnostic}");
    assert!(
        diagnostic["message"]
            .as_str()
            .unwrap()
            .contains("`Benitoite.IO.File.readBytesIn`"),
        "{diagnostic}"
    );
    let output = command()
        .args(["test", "--diagnostics=json"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 1, "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
    let rows = String::from_utf8(output.stdout).unwrap();
    let rows: Vec<Value> = rows
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert_eq!(rows[0]["failure"]["code"], "R0903");
    assert_eq!(rows[0]["failure"]["message"], diagnostic["message"]);
    assert_eq!(rows[1]["failed"], 1);
}

// 関門: 名前全体を処理するには旧操作・範囲付き操作の全節が必要であり、
// どの一節を欠いても同じ名前が残る。CLI の所有契約・報告と名前による照合まで
// 通すことで、型検査だけのハンドラのテストでは届かない名前の消失を捕まえる。
#[test]
fn complete_handler_names_and_every_missing_clause_reach_reports_and_limits() {
    let directory = TestDirectory::new();
    let reads = [
        "File.readText(path)",
        "File.readTextIn(path)",
        "File.openReader(path)",
        "File.readLine(reader)",
        "File.readBytes(path)",
        "File.readBytesIn(path)",
        "File.readLines(path)",
        "File.exists(path)",
        "File.info(path)",
        "File.listDirectory(path)",
        "File.walk(path)",
        "File.canonicalize(path)",
        "File.readChunk(reader, maximumBytes)",
    ];
    let writes = [
        "File.writeText(path, text)",
        "File.writeTextIn(path, text)",
        "File.appendText(path, text)",
        "File.appendTextIn(path, text)",
        "File.writeBytes(path, content)",
        "File.writeBytesIn(path, content)",
        "File.appendBytes(path, content)",
        "File.appendBytesIn(path, content)",
        "File.createDirectory(path)",
        "File.remove(path)",
        "File.removeTree(path)",
        "File.rename(from, to)",
        "File.openWriter(path, mode)",
        "File.write(writer, text)",
        "File.writeLine(writer, text)",
        "File.writeChunk(writer, content)",
    ];
    let connects = ["Http.send(request)", "Http.sendIn(request)"];
    for (effect, scope, clauses) in [
        ("File.Read", "[\"/data/**\"]", reads.as_slice()),
        ("File.Write", "[\"/data/**\"]", writes.as_slice()),
        (
            "Http.Connect",
            "[\"api.example\", 443]",
            connects.as_slice(),
        ),
    ] {
        let source = |omitted: Option<usize>, upper: &str| {
            let clauses = clauses
                .iter()
                .enumerate()
                .filter(|(index, _)| Some(*index) != omitted)
                .map(|(_, clause)| format!(" case {clause} -> 0\n"))
                .collect::<String>();
            format!(
                "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Network.Http\nfunction protected() -> Integer uses {effect}{scope}\n return 1\nend function\nfunction main() -> Unit{upper}\n bind _ <- handle protected() with\n{clauses} end handle\n return ()\nend function\n"
            )
        };
        for omitted in std::iter::once(None).chain((0..clauses.len()).map(Some)) {
            let name = format!("handler-{effect}-{}", omitted.unwrap_or(99));
            let upper = if omitted.is_some() {
                format!(" uses {effect}{scope}")
            } else {
                String::new()
            };
            let source = source(omitted, &upper);
            let script = directory.write(&format!("{name}.bnt"), &source);
            let test_script = directory.write(
                &format!("{name}-test.bnt"),
                &source.replace("function main()", "@test\nfunction upper()"),
            );
            let expected_names = if omitted.is_some() {
                serde_json::json!([effect])
            } else {
                serde_json::json!([])
            };
            let expected_bounds = if omitted.is_some() {
                let scope = if effect == "Http.Connect" {
                    serde_json::json!({
                        "kind":"endpoint",
                        "host":{"kind":"exact","name":"api.example"},
                        "ports":{"minimum":443,"maximum":443}
                    })
                } else {
                    serde_json::json!({"kind":"pathTree","path":"/data"})
                };
                serde_json::json!([{"name":effect,"scope":scope}])
            } else {
                serde_json::json!([])
            };
            let expected = serde_json::json!({
                "basis":"declaredUpperBound",
                "expanded":expected_names,
                "bounds":expected_bounds
            });
            for (path, options) in [
                (&script, vec!["check", "--report=json"]),
                (&test_script, vec!["test", "--check", "--report=json"]),
            ] {
                let output = command().args(&options).arg(path).output().unwrap();
                assert_eq!(exit_code(&output), 0, "{name}: {options:?}: {output:?}");
                assert!(output.stderr.is_empty(), "{name}: {output:?}");
                let report: Value = serde_json::from_slice(&output.stdout).unwrap();
                let effects = if options[0] == "check" {
                    &report["targets"][0]["main"]["effects"]
                } else {
                    &report["targets"][0]["tests"][0]["effects"]
                };
                assert_eq!(effects, &expected, "{name}: {options:?}: {report}");
                assert_eq!(report["aggregateEffects"], expected, "{name}: {report}");
            }
            if omitted.is_some() {
                let unbounded = directory.write(
                    &format!("{name}-missing.bnt"),
                    &source.replace(
                        &format!("function main() -> Unit{upper}"),
                        "function main() -> Unit",
                    ),
                );
                let output = command()
                    .args(["check", "--diagnostics=json"])
                    .arg(unbounded)
                    .output()
                    .unwrap();
                assert_eq!(exit_code(&output), 2, "{name}: {output:?}");
                let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
                assert_eq!(diagnostic["code"], "E0501", "{name}: {diagnostic}");
            }
            for (mode, path) in [("run", &script), ("test", &test_script)] {
                for (allowed, exit) in [(effect, 0), ("", if omitted.is_some() { 2 } else { 0 })] {
                    let output = command()
                        .args([mode, &format!("--allow-effects={allowed}")])
                        .arg(path)
                        .output()
                        .unwrap();
                    assert_eq!(
                        exit_code(&output),
                        exit,
                        "{name}: {mode}: {allowed}: {output:?}"
                    );
                    if exit == 0 {
                        assert!(output.stderr.is_empty(), "{name}: {output:?}");
                        if mode == "test" {
                            assert!(
                                output
                                    .stdout
                                    .ends_with(b"test result: ok. 1 passed; 0 failed\n")
                            );
                        } else {
                            assert!(output.stdout.is_empty(), "{name}: {output:?}");
                        }
                    } else {
                        if mode == "run" {
                            assert!(output.stdout.is_empty(), "{name}: {output:?}");
                        } else {
                            assert!(
                                output.stdout.ends_with(b"1 files not run\n"),
                                "{name}: {output:?}"
                            );
                        }
                        assert!(String::from_utf8_lossy(&output.stderr).contains("E0512"));
                    }
                }
            }
        }
    }
}

#[test]
fn scoped_projection_and_widening_guidance_repairs_are_accepted() {
    let directory = TestDirectory::new();
    for path in [true, false] {
        let (
            prefix,
            imports,
            ty,
            narrow,
            wide,
            raw,
            error,
            check_call,
            argument,
            io,
            effect,
            result,
            success,
        ) = if path {
            (
                "path",
                "import Benitoite.Unofficial.Scope\nimport Benitoite.Unofficial.IO.File\n",
                "Scope.PathIn",
                "[\"/data/a\"]",
                "[\"/data/**\"]",
                "String",
                "Scope.ScopeError",
                "Scope.checkPathIn(pattern: \"/data/a\", path: raw)",
                "path",
                "File.readTextIn",
                "File.Read",
                "Result[String, IOError]",
                "Result.Ok(\"handled\")",
            )
        } else {
            (
                "request",
                "import Benitoite.Unofficial.Network.Http\n",
                "Http.RequestIn",
                "[\"api.example\", 443]",
                "[\"**.example\", 400..500]",
                "Http.ClientRequest",
                "Http.RequestCheckError",
                "Http.checkRequestIn(hostPattern: \"api.example\", minimumPort: 443, maximumPort: 443, request: raw)",
                "request",
                "Http.sendIn",
                "Http.Connect",
                "Result[Http.Response, NetworkError]",
                "Result.Ok(Http.text(status: 200, s: \"handled\"))",
            )
        };
        for widening in [false, true] {
            let operation = match (path, widening) {
                (true, false) => "Scope.pathInValue",
                (true, true) => "Scope.widenPathIn",
                (false, false) => "Http.requestInValue",
                (false, true) => "Http.widenRequestIn",
            };
            let output_type = if widening {
                format!("{ty}{wide}")
            } else {
                raw.to_owned()
            };
            let call = format!("{operation}({argument}: value)");
            let source = format!(
                "{imports}function consume(value: {output_type}) -> Unit\nend function\nfunction sample(raw: {raw}) -> Unit\n bind checked: Result[{ty}{narrow}, {error}] <- {check_call}\n match checked with\n case Result.Ok(value) -> consume(value: {call})\n case Result.Error(_) -> ()\n end match\nend function\n"
            );
            let diagnostic = check(
                &directory,
                &format!("{prefix}-{widening}-nested"),
                &source,
                Some("E0519"),
            )
            .remove(0);
            assert!(
                diagnostic["message"]
                    .as_str()
                    .unwrap()
                    .contains("unknownSource"),
                "{diagnostic}"
            );
            let help = diagnostic["helps"].to_string();
            assert!(help.contains("bind"), "{diagnostic}");
            assert!(help.contains("widen it in the caller"), "{diagnostic}");
            let repaired = source.replace(
                &format!("consume(value: {call})"),
                &format!("bind extracted: {output_type} <- {call}\n consume(value: extracted)"),
            );
            check(
                &directory,
                &format!("{prefix}-{widening}-bind"),
                &repaired,
                None,
            );
            // 注釈だけを持つ関数引数は bind に移しても由来を得ない。
            let parameter = format!(
                "{imports}function sample(value: {ty}{narrow}) -> {output_type}\n bind extracted: {output_type} <- {call}\n return extracted\nend function\n"
            );
            let diagnostic = check(
                &directory,
                &format!("{prefix}-{widening}-parameter"),
                &parameter,
                Some("E0519"),
            )
            .remove(0);
            let help = diagnostic["helps"].to_string();
            assert!(help.contains("without scope arguments"), "{diagnostic}");
            let repaired = parameter.replace(&format!("{ty}{narrow}"), ty);
            let repaired = if widening {
                repaired.replace(&output_type, ty)
            } else {
                repaired
            };
            check(
                &directory,
                &format!("{prefix}-{widening}-bare-parameter"),
                &repaired,
                None,
            );
            // 裸の仮引数に変えるだけでは、狭い実引数は不変性により渡せない。
            let caller = format!(
                "function caller(raw: {raw}) -> Unit\n bind checked: Result[{ty}{narrow}, {error}] <- {check_call}\n match checked with\n case Result.Ok(value) ->\n  bind _ <- sample(value: value)\n  ()\n case Result.Error(_) -> ()\n end match\nend function\n"
            );
            check(
                &directory,
                &format!("{prefix}-{widening}-caller-bare"),
                &format!("{repaired}{caller}"),
                Some("E0401"),
            );
            let widen_operation = if path {
                "Scope.widenPathIn"
            } else {
                "Http.widenRequestIn"
            };
            let caller = caller.replace(
                "bind _ <- sample(value: value)",
                &format!("bind wideValue: {ty} <- {widen_operation}({argument}: value)\n  bind _ <- sample(value: wideValue)"),
            );
            check(
                &directory,
                &format!("{prefix}-{widening}-caller-bare-widen"),
                &format!("{repaired}{caller}"),
                None,
            );
            let clause_call = call.replace(": value)", ": captured)");
            let clause = format!(
                "{imports}function sample({argument}: {ty}{narrow}) -> {result} uses {effect}{narrow}\n return handle {io}({argument}: {argument}) with\n case {io}(captured) ->\n bind extracted: {output_type} <- {clause_call}\n resume({success})\n end handle\nend function\n"
            );
            let diagnostic = check(
                &directory,
                &format!("{prefix}-{widening}-clause"),
                &clause,
                Some("E0519"),
            )
            .remove(0);
            assert!(
                diagnostic["message"]
                    .as_str()
                    .unwrap()
                    .contains("unknownSource"),
                "{diagnostic}"
            );
            let help = diagnostic["helps"].to_string();
            assert!(
                help.contains("clause") && help.contains("pass it unchanged to a scoped entry"),
                "{diagnostic}"
            );
            let repaired = clause.replace(narrow, "");
            // 保護本体を Top にするため、引数と IO の uses も広げる契約変更である。
            let repaired = if widening {
                repaired.replace(&output_type, ty)
            } else {
                repaired
            };
            check(
                &directory,
                &format!("{prefix}-{widening}-bare-clause"),
                &repaired,
                None,
            );
        }
        let caller = format!(
            "function caller(raw: {raw}) -> {result} uses {effect}{narrow}\n bind checked: Result[{ty}{narrow}, {error}] <- {check_call}\n return match checked with\n case Result.Ok(value) -> sample({argument}: value)\n case Result.Error(_) -> {success}\n end match\nend function\n"
        );
        let projection = if path {
            "Scope.pathInValue"
        } else {
            "Http.requestInValue"
        };
        // 転送先で射影すると由来を得られず再び拒否される。範囲付き IO への
        // 直接の転送なら、関数・節の引数とも狭い契約と呼び出し元を保てる。
        for (name, accept_body, sample_body, code) in [
            (
                "forward-project",
                format!(
                    "bind extracted: {raw} <- {projection}({argument}: value)\n return {success}"
                ),
                format!(
                    "return handle {io}({argument}: {argument}) with\n case {io}(captured) -> resume(accept(value: captured))\n end handle"
                ),
                Some("E0519"),
            ),
            (
                "param-forward-io",
                format!("return {io}({argument}: value)"),
                format!("return accept(value: {argument})"),
                None,
            ),
            (
                "clause-forward-io",
                format!("return {io}({argument}: value)"),
                format!(
                    "return handle {io}({argument}: {argument}) with\n case {io}(captured) -> resume(accept(value: captured))\n end handle"
                ),
                None,
            ),
        ] {
            let source = format!(
                "{imports}function accept(value: {ty}{narrow}) -> {result} uses {effect}{narrow}\n {accept_body}\nend function\nfunction sample({argument}: {ty}{narrow}) -> {result} uses {effect}{narrow}\n {sample_body}\nend function\n{caller}"
            );
            check(&directory, &format!("{prefix}-{name}"), &source, code);
        }
    }
}
