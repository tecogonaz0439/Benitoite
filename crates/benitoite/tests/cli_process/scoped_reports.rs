//! 関門: 検査済みの宣言上限を CLI の所有データへ写す際の範囲の欠落と、
//! 通常・test・doc・集約での意味の差を検出する。型検査の試験では届かない
//! JSON の任意欄と名前だけの旧読者の契約を、実 CLI の出力と終了状態で守る
//! （設計書 06-01「main の非実行の検査報告」、06-04「テストの非実行の検査」）。

use super::{TestDirectory, command, exit_code};
use serde_json::{Value, json};

fn report(directory: &TestDirectory, name: &str, source: &str, options: &[&str]) -> Value {
    let script = directory.write(name, source);
    let output = command().args(options).arg(script).output().unwrap();
    assert_eq!(exit_code(&output), 0, "{name}: {output:?}");
    assert!(output.stderr.is_empty(), "{name}: {output:?}");
    // from_slice は二つ目の JSON や診断の混入も拒否する。
    let value: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["status"], "ok", "{value}");
    assert_eq!(value["complete"], true, "{value}");
    assert_eq!(value["executed"], false, "{value}");
    value
}

#[test]
fn declared_bounds_preserve_normal_forms_in_all_report_readers() {
    let directory = TestDirectory::new();
    let cases = [
        ("pure", "", json!([]), json!([])),
        ("handled-user", "", json!([]), json!([])),
        (
            "all",
            " uses File.Read",
            json!(["File.Read"]),
            json!([
                {"name":"File.Read","scope":{"kind":"all"}}
            ]),
        ),
        (
            "root",
            " uses File.Read[\"/**\"]",
            json!(["File.Read"]),
            json!([
                {"name":"File.Read","scope":{"kind":"pathTree","path":"/"}}
            ]),
        ),
        (
            "redundant",
            " uses File.Read, File.Read[\"/data/**\"], File.Read[\"/data/a\"]",
            json!(["File.Read"]),
            json!([
                {"name":"File.Read","scope":{"kind":"all"}},
                {"name":"File.Read","scope":{"kind":"pathExact","path":"/data/a"}},
                {"name":"File.Read","scope":{"kind":"pathTree","path":"/data"}}
            ]),
        ),
        (
            "name",
            " uses Http.Connect[\"API.Example.com\", 443]",
            json!(["Http.Connect"]),
            json!([
                {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"exact","name":"api.example.com"},"ports":{"minimum":443,"maximum":443}}}
            ]),
        ),
        (
            "one",
            " uses Http.Connect[\"*.example.com\", 0..65535]",
            json!(["Http.Connect"]),
            json!([
                {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"one","name":"example.com"},"ports":{"minimum":0,"maximum":65535}}}
            ]),
        ),
        (
            "many",
            " uses Http.Connect[\"**.example.com\", 80..443]",
            json!(["Http.Connect"]),
            json!([
                {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"many","name":"example.com"},"ports":{"minimum":80,"maximum":443}}}
            ]),
        ),
        (
            "v4",
            " uses Http.Connect[\"192.0.2.1/32\", 80]",
            json!(["Http.Connect"]),
            json!([
                {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"exact","family":"v4","address":"192.0.2.1"},"ports":{"minimum":80,"maximum":80}}}
            ]),
        ),
        (
            "v6",
            " uses Http.Connect[\"2001:db8::1/128\", 443]",
            json!(["Http.Connect"]),
            json!([
                {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"exact","family":"v6","address":"2001:db8::1"},"ports":{"minimum":443,"maximum":443}}}
            ]),
        ),
        (
            "v6-cidr",
            " uses Http.Connect[\"2001:db8::/32\", 443..445]",
            json!(["Http.Connect"]),
            json!([
                {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"cidr","family":"v6","address":"2001:db8::","prefixLength":32},"ports":{"minimum":443,"maximum":445}}}
            ]),
        ),
    ];
    for (name, annotation, expanded, bounds) in cases {
        // 本体は純粋であり、宣言の上限を推論した効果へ置換するとこの期待値に反する。
        let (declarations, body) = if name == "handled-user" {
            (
                "effect Ask\n function ask() -> Unit\nend effect\n",
                " handle ask() with\n  case ask() -> resume(())\n end handle\n",
            )
        } else {
            ("", "")
        };
        let source = format!(
            "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Network.Http\n{declarations}function main() -> Unit{annotation}\n{body}end function\n@test\nfunction upper() -> Unit{annotation}\n{body}end function\n"
        );
        let expected = json!({"basis":"declaredUpperBound","expanded":expanded,"bounds":bounds});
        for options in [
            vec!["check", "--report=json"],
            vec!["test", "--check", "--report=json"],
        ] {
            let value = report(&directory, &format!("{name}.bnt"), &source, &options);
            assert_eq!(value["schemaVersion"], 1);
            assert_eq!(value["aggregateEffects"], expected, "{name}: {value}");
            let contract = if options[0] == "check" {
                &value["targets"][0]["main"]["effects"]
            } else {
                &value["targets"][0]["tests"][0]["effects"]
            };
            assert_eq!(contract, &expected, "{name}");
            // 旧読者は任意 bounds を無視し、各名前の全対象という保守的な上限を得る。
            let allowed = expanded
                .as_array()
                .unwrap()
                .iter()
                .map(|name| name.as_str().unwrap())
                .collect::<Vec<_>>()
                .join(",");
            let script = directory.path.join(format!("{name}.bnt"));
            let executed = command()
                .args([
                    if options[0] == "check" { "run" } else { "test" },
                    &format!("--allow-effects={allowed}"),
                ])
                .arg(script)
                .output()
                .unwrap();
            assert_eq!(exit_code(&executed), 0, "{name}: {executed:?}");
            assert!(executed.stderr.is_empty(), "{name}: {executed:?}");
        }
        let fence = "\x60\x60\x60";
        let doc_source = format!(
            "//! {fence}benitoite test\n{}//! {fence}\nfunction helper() -> Unit\nend function\n",
            source
                .lines()
                .map(|line| format!("//! {line}\n"))
                .collect::<String>()
        );
        let doc = report(
            &directory,
            &format!("{name}-doc.bnt"),
            &doc_source,
            &["test", "--doc", "--check", "--report=json"],
        );
        assert_eq!(doc["schemaVersion"], 2);
        assert_eq!(
            doc["targets"][0]["docExamples"][0]["effects"], expected,
            "{name}: {doc}"
        );
        assert_eq!(doc["aggregateEffects"], expected, "{name}: {doc}");
    }
}

#[test]
fn aggregate_bounds_union_contracts_and_omit_unfinished_results() {
    let directory = TestDirectory::new();
    let first = directory.write("first.bnt", "import Benitoite.Unofficial.IO.File\n@test\nfunction first() -> Unit uses File.Read[\"/data/**\"]\nend function\n");
    let second = directory.write("second.bnt", "import Benitoite.Unofficial.IO.File\n@test\nfunction second() -> Unit uses File.Read[\"/data/a\"], File.Write\nend function\n");
    let output = command()
        .args(["test", "--check", "--report=json"])
        .arg(&first)
        .arg(&second)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    let value: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(
        value["aggregateEffects"],
        json!({"basis":"declaredUpperBound","expanded":["File.Read","File.Write"],"bounds":[
            {"name":"File.Read","scope":{"kind":"pathExact","path":"/data/a"}},
            {"name":"File.Read","scope":{"kind":"pathTree","path":"/data"}},
            {"name":"File.Write","scope":{"kind":"all"}}
        ]})
    );
    let bad = directory.write(
        "bad.bnt",
        "@test\nfunction bad() -> Integer\n return \"bad\"\nend function\n",
    );
    for options in [
        vec!["check", "--report=json"],
        vec!["test", "--check", "--report=json"],
    ] {
        let output = command().args(&options).arg(&bad).output().unwrap();
        assert_eq!(exit_code(&output), 2, "{output:?}");
        assert!(output.stderr.is_empty(), "{output:?}");
        let value: Value = serde_json::from_slice(&output.stdout).unwrap();
        assert_eq!(value["complete"], false);
        assert_eq!(value["aggregateEffects"], Value::Null);
        assert!(
            !String::from_utf8(output.stdout)
                .unwrap()
                .contains("\"bounds\"")
        );
    }
}

// 関門: 固定範囲の値引数を持つ利用者操作の節から実際の標準 IO へ渡す契約を守る。
// 純粋な再開だけの既存例では、節の File.Write の消失や Report の復活を捕まえない。
// 本物の非実行 CLI を使い、本番の差し込み口や外部ファイルの書込みを加えない。
#[test]
fn handled_user_value_preserves_only_the_scoped_io_contract() {
    let directory = TestDirectory::new();
    let source = include_str!("fixtures/handled-scoped-write.bnt");
    let expected = json!({
        "basis":"declaredUpperBound", "expanded":["File.Write"],
        "bounds":[{"name":"File.Write","scope":{"kind":"pathTree","path":"/data/reports"}}]
    });
    for options in [
        vec!["check", "--report=json"],
        vec!["test", "--check", "--report=json"],
    ] {
        let value = report(&directory, "handled-scoped-write.bnt", source, &options);
        let effects = if options[0] == "check" {
            &value["targets"][0]["main"]["effects"]
        } else {
            &value["targets"][0]["tests"][0]["effects"]
        };
        assert_eq!(effects, &expected, "{value}");
        assert_eq!(value["aggregateEffects"], expected, "{value}");
    }
    let pure = directory.write("pure.bnt", "@test\nfunction pure() -> Unit\nend function\n");
    let output = command()
        .args(["test", "--check", "--report=json"])
        .arg(directory.path.join("handled-scoped-write.bnt"))
        .arg(pure)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
    let value: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["targets"].as_array().unwrap().len(), 2);
    assert_eq!(value["targets"][0]["tests"][0]["effects"], expected);
    assert_eq!(
        value["targets"][1]["tests"][0]["effects"]["expanded"],
        json!([])
    );
    assert_eq!(value["aggregateEffects"], expected, "{value}");
}

#[test]
fn scoped_allow_effect_arguments_are_usage_errors_before_execution() {
    let directory = TestDirectory::new();
    let script = directory.write(
        "never.bnt",
        "function main() -> Unit\nend function\n@test\nfunction upper() -> Unit\nend function\n",
    );
    for mode in ["run", "test"] {
        for allowed in [
            "File.Read[\"/data/**\"]",
            "File.Write[\"/data\"]",
            "Http.Connect[\"example.com\",443]",
        ] {
            let output = command()
                .args([mode, &format!("--allow-effects={allowed}")])
                .arg(&script)
                .output()
                .unwrap();
            assert_eq!(exit_code(&output), 2, "{mode} {allowed}: {output:?}");
            assert!(output.stdout.is_empty(), "{output:?}");
            assert!(
                String::from_utf8(output.stderr)
                    .unwrap()
                    .contains("invalid effect name")
            );
        }
    }
}
