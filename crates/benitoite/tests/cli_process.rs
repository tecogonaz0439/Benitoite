#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
//! CLI を別プロセスで起動し、終了状態と標準入出力を確かめる
//! （設計書 07-03「前提」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。

#[path = "cli_process/scoped_diagnostics.rs"]
mod scoped_diagnostics;
#[path = "cli_process/scoped_reports.rs"]
mod scoped_reports;

use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

// 作成時の関門: run のゴールデンでは届かない check と test を含む、旧予算超過入力の受理を守る。
// 公開の CLI と実ファイルを使い、時刻や本番の差し込み口には依存しない。
#[test]
fn shared_decisions_are_accepted_by_all_cli_modes() {
    let directory = TestDirectory::new();
    let script = directory.write(
        "tree-budget.bnt",
        include_str!("../testdata/patterns/todo195-decision-tree-budget.bnt"),
    );
    let output = command()
        .args(["check", "--report=json"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
    let report: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(report["status"], "ok", "{report}");
    assert!(
        report["diagnostics"].as_array().unwrap().is_empty(),
        "{report}"
    );
    assert!(!String::from_utf8_lossy(&output.stdout).contains("L0112"));
    for (mode, expected) in [("check", 0), ("run", 0), ("test", 0)] {
        let output = command().arg(mode).arg(&script).output().unwrap();
        assert_eq!(exit_code(&output), expected, "{mode}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.is_empty(), "{stderr}");
        if mode == "test" {
            assert_eq!(output.stdout, b"test result: ok. 0 passed; 0 failed\n");
        } else {
            assert!(output.stdout.is_empty(), "{output:?}");
        }
    }
}

// 関門: 合併済みのmain契約を報告と実行前の照合へ渡し、不足分のファイル位置だけを示す。
// 型検査の入口だけでは、所有データへの抽出時に由来が失われる退行を捕まえない。
#[test]
fn file_effects_reach_main_reports_and_limit_origins() {
    use serde_json::{Value, json};
    let directory = TestDirectory::new();
    let source = "import Benitoite.Unofficial.IO.Console\nuses Console.Write, Log\nfunction main() -> Unit uses Log\nend function\n";
    let script = directory.write("file-effects.bnt", source);
    let plain = command().arg("check").arg(&script).output().unwrap();
    assert_eq!(exit_code(&plain), 0, "{plain:?}");
    assert!(plain.stdout.is_empty());
    assert!(plain.stderr.is_empty());
    let output = command()
        .args(["check", "--report=json"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert!(output.stderr.is_empty());
    let report: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(report["status"], "ok");
    assert_eq!(report["complete"], true);
    assert_eq!(
        report["targets"][0]["main"]["effects"],
        json!({"basis":"declaredUpperBound", "expanded":["Console.Write","Log"], "bounds":[{"name":"Console.Write","scope":{"kind":"all"}},{"name":"Log","scope":{"kind":"all"}}]})
    );
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        json!(["Console.Write", "Log"])
    );
    for (allowed, missing, origins) in [
        ("", "Console.Write, Log", vec!["Console.Write", "Log"]),
        ("Log", "Console.Write", vec!["Console.Write"]),
        ("Console.Write", "Log", vec!["Log"]),
        ("Console.Write,Log", "", vec![]),
    ] {
        let output = command()
            .args([
                "run",
                "--diagnostics=json",
                &format!("--allow-effects={allowed}"),
            ])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(
            exit_code(&output),
            if missing.is_empty() { 0 } else { 2 },
            "{output:?}"
        );
        assert!(output.stdout.is_empty());
        if missing.is_empty() {
            assert!(output.stderr.is_empty());
            continue;
        }
        let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
        assert_eq!(diagnostic["code"], "E0512");
        assert_eq!(
            diagnostic["notes"][0],
            format!("effects not allowed: {missing}")
        );
        assert_eq!(
            diagnostic["primary"]["start"]["offset"],
            source.find("main").unwrap()
        );
        let secondary = diagnostic["secondary"].as_array().unwrap();
        assert_eq!(secondary.len(), origins.len(), "{diagnostic}");
        for (position, origin) in secondary.iter().zip(origins) {
            let start = position["start"]["offset"].as_u64().unwrap() as usize;
            let end = position["end"]["offset"].as_u64().unwrap() as usize;
            assert_eq!(&source[start..end], origin);
            assert!(start < source.find("function").unwrap());
        }
    }
    let source = "uses IO.All\nfunction main() -> Unit\nend function\n";
    let script = directory.write("shared-all.bnt", source);
    let output = command()
        .args(["run", "--diagnostics=json", "--allow-effects="])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2, "{output:?}");
    let diagnostics: Vec<Value> = String::from_utf8(output.stderr)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(
        diagnostics
            .iter()
            .map(|d| d["code"].as_str().unwrap())
            .collect::<Vec<_>>(),
        ["W0501", "E0512"]
    );
    let origins = diagnostics[1]["secondary"].as_array().unwrap();
    assert_eq!(origins.len(), 1);
    assert_eq!(origins[0]["start"]["offset"], 5);
    assert_eq!(origins[0]["end"]["offset"], 11);
}

// 関門: 範囲付きの宣言をCLIの所有する契約へ写す際に内部エラーにしない。
// 型検査だけでは届かない報告・名前だけの上限の照合を、通常のCLIで対にする。
#[test]
fn scoped_contracts_reach_reports_and_name_limits() {
    use serde_json::{Value, json};
    for file in [false, true] {
        let directory = TestDirectory::new();
        let uses = "uses File.Write[\"/data/**\", \"/backup/**\"], Http.Connect[\"192.168.1.0/24\", 443..445]";
        let source = format!(
            "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Network.Http\n{}function main() -> Unit{}\nend function\n@test\nfunction verifies() -> Unit{}\nend function\n",
            if file {
                format!("{uses}\n")
            } else {
                String::new()
            },
            if file {
                String::new()
            } else {
                format!(" {uses}")
            },
            if file {
                String::new()
            } else {
                format!(" {uses}")
            },
        );
        let script = directory.write("scoped-contracts.bnt", &source);
        let expected = json!({"basis":"declaredUpperBound", "expanded":["File.Write", "Http.Connect"],
        "bounds": [
            {"name":"File.Write","scope":{"kind":"pathTree","path":"/backup"}},
            {"name":"File.Write","scope":{"kind":"pathTree","path":"/data"}},
            {"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"cidr","family":"v4","address":"192.168.1.0","prefixLength":24},"ports":{"minimum":443,"maximum":445}}}
        ]});
        for options in [
            vec!["check", "--report=json"],
            vec!["test", "--check", "--report=json"],
        ] {
            let output = command().args(&options).arg(&script).output().unwrap();
            assert_eq!(exit_code(&output), 0, "{options:?}: {output:?}");
            assert!(output.stderr.is_empty(), "{output:?}");
            let report: Value = serde_json::from_slice(&output.stdout).unwrap();
            assert_eq!(report["status"], "ok");
            assert_eq!(report["aggregateEffects"], expected);
            let contract = if options[0] == "check" {
                &report["targets"][0]["main"]["effects"]
            } else {
                &report["targets"][0]["tests"][0]["effects"]
            };
            assert_eq!(contract, &expected);
        }
        for mode in ["check", "run", "test"] {
            let output = command().arg(mode).arg(&script).output().unwrap();
            assert_eq!(exit_code(&output), 0, "{mode}: {output:?}");
            assert!(output.stderr.is_empty(), "{output:?}");
        }
        for mode in ["run", "test"] {
            for (allowed, expected_exit) in [("File.Write,Http.Connect", 0), ("Http.Connect", 2)] {
                let output = command()
                    .args([
                        mode,
                        "--diagnostics=json",
                        &format!("--allow-effects={allowed}"),
                    ])
                    .arg(&script)
                    .output()
                    .unwrap();
                assert_eq!(exit_code(&output), expected_exit, "{mode}: {output:?}");
                if expected_exit == 0 {
                    assert!(output.stderr.is_empty(), "{output:?}");
                } else {
                    let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
                    assert_eq!(diagnostic["code"], "E0512");
                    assert_eq!(diagnostic["notes"][0], "effects not allowed: File.Write");
                    assert_eq!(
                        !diagnostic["secondary"].as_array().unwrap().is_empty(),
                        file
                    );
                }
            }
        }
    }
}

// 作成時の関門: 宣言上限の包含と拒否時の非実行を、本物の CLI・ファイル・出力で守る。
// 既存の検査報告は実行を始めないため、照合とコンパイルの接続の退行を捕まえない。
// 診断の集合表示と入力の両構文も同じ表で確かめ、テスト専用の本番 API は加えない。
#[test]
fn run_effect_limits_check_declared_contracts_before_execution() {
    use serde_json::{Value, json};
    let directory = TestDirectory::new();
    let all = "State,Console.Write,Console.Read,File.Read,File.Write,Process.Run,Process.Exit,Process.Environment,Clock.Time,Random.Generate,Http.Listen,Http.Connect,Assert.Check";
    let io = "Clock.Time,Console.Read,Console.Write,File.Read,File.Write,Process.Environment,Process.Exit,Process.Run,Random.Generate,State";
    for (name, source, allowed, missing, expected_out) in [
        (
            "pure",
            "function main() -> Unit\nend function\n",
            "",
            None,
            "",
        ),
        (
            "extra",
            "function main() -> Unit\nend function\n",
            all,
            None,
            "",
        ),
        (
            "console",
            "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n    Console.writeLine(\"started\")\nend function\n",
            "Console.Write",
            None,
            "started\n",
        ),
        (
            "declared",
            "import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\nfunction main() -> Unit uses State, Process.Exit, Console.Write\nend function\n",
            "File.Write,File.Read",
            Some("Console.Write, Process.Exit, State"),
            "",
        ),
        (
            "empty",
            "function main() -> Unit uses State\nend function\n",
            "",
            Some("State"),
            "",
        ),
        (
            "expanded",
            "function main() -> Unit uses IO.All\nend function\n",
            io,
            None,
            "",
        ),
        (
            "expanded-missing",
            "function main() -> Unit uses IO.All\nend function\n",
            "State,Console.Write",
            Some(
                "Clock.Time, Console.Read, File.Read, File.Write, Process.Environment, Process.Exit, Process.Run, Random.Generate",
            ),
            "",
        ),
    ] {
        let script = directory.write(&format!("{name}.bnt"), source);
        // 書式の同値性は成功と拒否の一例ずつで守り、他の包含の例は基本の書式で比較する。
        let forms = if matches!(name, "console" | "empty") {
            4
        } else {
            1
        };
        for form in 0..forms {
            let mut invocation = command();
            match form {
                0 => {
                    invocation.args(["run", &format!("--allow-effects={allowed}")]);
                }
                1 => {
                    invocation.args(["run", "--allow-effects", allowed]);
                }
                2 => {
                    invocation.args(["--allow-effects", allowed, "run"]);
                }
                _ => {
                    invocation.arg(format!("--allow-effects={allowed}"));
                }
            }
            let output = invocation
                .arg("--diagnostics=json")
                .arg(&script)
                .output()
                .unwrap();
            assert_eq!(
                exit_code(&output),
                if missing.is_some() { 2 } else { 0 },
                "{name}/{form}: {output:?}"
            );
            assert_eq!(output.stdout, expected_out.as_bytes(), "{name}/{form}");
            let diagnostics: Vec<Value> = String::from_utf8(output.stderr.clone())
                .unwrap()
                .lines()
                .map(|line| serde_json::from_str(line).unwrap())
                .collect();
            let expanded = name.starts_with("expanded");
            let expected_codes: &[&str] = match (expanded, missing.is_some()) {
                (true, true) => &["W0501", "E0512"],
                (true, false) => &["W0501"],
                (false, true) => &["E0512"],
                (false, false) => &[],
            };
            assert_eq!(
                diagnostics
                    .iter()
                    .map(|diagnostic| diagnostic["code"].as_str().unwrap())
                    .collect::<Vec<_>>(),
                expected_codes,
                "{name}/{form}"
            );
            if let Some(missing) = missing {
                let diagnostic = diagnostics.last().unwrap();
                let start = source.find("main()").unwrap();
                let line = source[..start]
                    .bytes()
                    .filter(|byte| *byte == b'\n')
                    .count()
                    + 1;
                let allowed_display = if allowed.is_empty() {
                    "(none)"
                } else if name == "declared" {
                    "File.Read, File.Write"
                } else {
                    "Console.Write, State"
                };
                assert_eq!(
                    diagnostic,
                    &json!({
                        "kind":"check", "severity":"error", "code":"E0512",
                        "message":"effects of `main` exceed `--allow-effects`",
                        "primary": { "file":script.display().to_string(),
                            "start":{"line":line,"column":10,"offset":start},
                            "end":{"line":line,"column":14,"offset":start+4},
                            "label":"effect limit checked for this function" },
                        "secondary":[], "notes":[format!("effects not allowed: {missing}"),format!("allowed effects: {allowed_display}")],
                        "helps":[{"message":"review the required effects before changing --allow-effects","edits":[]}]
                    }),
                    "{name}/{form}"
                );
            } else if !expanded {
                assert!(output.stderr.is_empty(), "{name}/{form}: {output:?}");
            }
        }
    }

    let script = directory.write("write.bnt", "import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.File\nfunction main() -> Result[Unit, String] uses File.Write, Console.Write\n    Console.writeLine(\"started\")\n    return File.writeText(path: \"marker\", text: \"changed\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)\nend function\n");
    let marker = directory.write("marker", "original");
    for diagnostics in ["text", "json"] {
        let output = command()
            .current_dir(&directory.path)
            .args([
                "run",
                &format!("--diagnostics={diagnostics}"),
                "--allow-effects=Console.Write",
            ])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 2, "{output:?}");
        assert!(output.stdout.is_empty(), "{output:?}");
        assert!(
            String::from_utf8_lossy(&output.stderr).contains("E0512"),
            "{output:?}"
        );
        assert_eq!(fs::read_to_string(&marker).unwrap(), "original");
    }
    let output = command()
        .current_dir(&directory.path)
        .args(["run", "--allow-effects=File.Write,Console.Write"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert_eq!(output.stdout, b"started\n");
    assert!(output.stderr.is_empty(), "{output:?}");
    assert_eq!(fs::read_to_string(marker).unwrap(), "changed");

    // 照合の費用が大きい入力でも、実行前に権限を照合する。
    let tree = directory.write(
        "tree.bnt",
        &include_str!("../testdata/patterns/todo195-decision-tree-budget.bnt").replace(
            "function main() -> Unit",
            "function main() -> Unit uses State",
        ),
    );
    let output = command()
        .args(["run", "--allow-effects=", "--diagnostics=json"])
        .arg(tree)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2, "{output:?}");
    assert!(output.stdout.is_empty());
    let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
    assert_eq!(diagnostic["code"], "E0512");

    for (name, source, code, deny) in [
        (
            "no-main",
            "function helper() -> Unit\nend function\n",
            "E0414",
            false,
        ),
        (
            "bad-type",
            "function main() -> Unit\n    bind value: Integer <- \"wrong\"\nend function\n",
            "E0401",
            false,
        ),
        (
            "denied-warning",
            "@deprecated(\"use current instead\")\nfunction old() -> Unit\nend function\nfunction main() -> Unit uses State\n    old()\nend function\n",
            "W0301",
            true,
        ),
    ] {
        let script = directory.write(&format!("{name}.bnt"), source);
        let mut invocation = command();
        invocation.args(["run", "--allow-effects=", "--diagnostics=json"]);
        if deny {
            invocation.arg("--deny-warnings");
        }
        let output = invocation.arg(script).output().unwrap();
        assert_eq!(exit_code(&output), 2, "{name}: {output:?}");
        assert!(output.stdout.is_empty());
        let diagnostics: Vec<Value> = String::from_utf8(output.stderr)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert!(
            diagnostics
                .iter()
                .any(|diagnostic| diagnostic["code"] == code),
            "{name}: {diagnostics:?}"
        );
        assert!(
            diagnostics
                .iter()
                .all(|diagnostic| diagnostic["code"] != "E0512")
        );
    }
    let output = command()
        .args(["run", "--allow-effects=", "--diagnostics=json"])
        .env("BENITOITE_DEV_PANIC", "check")
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 3, "{output:?}");
    assert!(output.stdout.is_empty());
    let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
    assert_eq!(diagnostic["kind"], "internal");
}

// 関門: 報告後に入口・依存が変わっても、実行時の検査と古い許可集合で拒否する。
// 同じ種類の書き込み先だけの変更は許されるという限界も、実ファイルで比較する。
#[test]
fn run_effect_limits_recheck_changed_sources() {
    use serde_json::{Value, json};
    const MAIN: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\nimport Helper\nfunction main() -> Result[Unit, String] uses Console.Write, File.Write\n    Console.writeLine(\"started\")\n    return Helper.save()\nend function\n";
    const HELPER: &str = "import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.IO.Process\npublic function save() -> Result[Unit, String] uses File.Write\n    return File.writeText(path: \"marker\", text: \"changed\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)\nend function\n";
    for (change, expected_code) in [
        ("main", Some("E0512")),
        ("import", Some("E0501")),
        ("destination", None),
    ] {
        let directory = TestDirectory::new();
        let script = directory.write("main.bnt", MAIN);
        let helper = directory.write("Helper.bnt", HELPER);
        let marker = directory.write("marker", "original");
        let output = command()
            .current_dir(&directory.path)
            .args(["check", "--report=json"])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 0, "{change}: {output:?}");
        assert!(output.stderr.is_empty(), "{output:?}");
        let report: Value = serde_json::from_slice(&output.stdout).unwrap();
        assert_eq!(report["complete"], true);
        assert_eq!(report["executed"], false);
        assert_eq!(
            report["aggregateEffects"]["expanded"],
            json!(["Console.Write", "File.Write"])
        );
        assert_eq!(fs::read_to_string(&marker).unwrap(), "original");
        let allowed = report["aggregateEffects"]["expanded"]
            .as_array()
            .unwrap()
            .iter()
            .map(|name| name.as_str().unwrap())
            .collect::<Vec<_>>()
            .join(",");
        match change {
            "main" => fs::write(
                &script,
                MAIN.replace(
                    "uses Console.Write, File.Write",
                    "uses Console.Write, File.Write, Process.Environment",
                )
                .replace(
                    "    Console.writeLine",
                    "    bind _ <- Process.arguments()\n    Console.writeLine",
                ),
            )
            .unwrap(),
            "import" => fs::write(
                &helper,
                HELPER
                    .replace("uses File.Write", "uses File.Write, Process.Environment")
                    .replace(
                        "    return File.writeText",
                        "    bind _ <- Process.arguments()\n    return File.writeText",
                    ),
            )
            .unwrap(),
            _ => fs::write(&helper, HELPER.replace("\"marker\"", "\"other-marker\"")).unwrap(),
        }
        let changed = command()
            .current_dir(&directory.path)
            .args(["check", "--report=json"])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(
            exit_code(&changed),
            if change == "import" { 2 } else { 0 },
            "{change}: {changed:?}"
        );
        assert!(changed.stderr.is_empty(), "{changed:?}");
        let changed: Value = serde_json::from_slice(&changed.stdout).unwrap();
        if change == "main" {
            assert_eq!(
                changed["aggregateEffects"]["expanded"],
                json!(["Console.Write", "File.Write", "Process.Environment"])
            );
        } else if change == "import" {
            assert_eq!(changed["aggregateEffects"], Value::Null);
            assert_eq!(changed["diagnostics"][0]["code"], "E0501");
        } else {
            assert_eq!(changed["aggregateEffects"], report["aggregateEffects"]);
        }
        let output = command()
            .current_dir(&directory.path)
            .args([
                "run",
                "--diagnostics=json",
                &format!("--allow-effects={allowed}"),
            ])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(
            exit_code(&output),
            if expected_code.is_some() { 2 } else { 0 },
            "{change}: {output:?}"
        );
        assert_eq!(fs::read_to_string(&marker).unwrap(), "original");
        if let Some(code) = expected_code {
            assert!(output.stdout.is_empty(), "{output:?}");
            assert!(!directory.path.join("other-marker").exists());
            let diagnostic: Value = serde_json::from_slice(&output.stderr).unwrap();
            assert_eq!(diagnostic["kind"], "check");
            assert_eq!(diagnostic["code"], code, "{change}: {diagnostic}");
            if code == "E0512" {
                assert_eq!(
                    diagnostic["notes"],
                    json!([
                        "effects not allowed: Process.Environment",
                        "allowed effects: Console.Write, File.Write"
                    ])
                );
            }
        } else {
            assert!(output.stderr.is_empty(), "{output:?}");
            assert_eq!(output.stdout, b"started\n");
            assert_eq!(
                fs::read_to_string(directory.path.join("other-marker")).unwrap(),
                "changed"
            );
        }
    }
}

// 関門: run の許可上限で未処理の Fail を隠さず、処理済みなら実行できることを守る。
// 検査報告だけでは実行前の照合とコンパイルへの接続を確かめられない。
#[test]
fn run_failure_contracts_are_checked_before_effect_limits() {
    let directory = TestDirectory::new();
    for (name, source, expected) in [
        (
            "unhandled",
            "import Benitoite.Unofficial.Failure\nfunction main() -> Unit uses Failure.Fail[String]\n  Failure.raise(\"stop\")\nend function\n",
            2,
        ),
        (
            "handled",
            "import Benitoite.Unofficial.Failure\nfunction main() -> Unit\n  bind result: Result[Unit, String] <- Failure.toResult(body: lambda() return Failure.raise(\"stop\") end lambda)\nend function\n",
            0,
        ),
    ] {
        let script = directory.write(&format!("{name}.bnt"), source);
        let output = command()
            .args(["run", "--allow-effects=", "--diagnostics=json"])
            .arg(script)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), expected, "{output:?}");
        assert!(output.stdout.is_empty(), "{output:?}");
        if expected == 2 {
            let diagnostic: serde_json::Value = serde_json::from_slice(&output.stderr).unwrap();
            assert_eq!(diagnostic["code"], "E0506");
        } else {
            assert!(output.stderr.is_empty(), "{output:?}");
        }
    }
}

// 関門: 標準Failの解決先だけに実行可能な対処を案内する契約を実CLIで守る。
// 既存の拒否テストはhelpを検査せず、同名の利用者エフェクトへの誤案内を捕まえない。
#[test]
fn failure_entry_help_uses_resolved_standard_effect() {
    let directory = TestDirectory::new();
    for (import, effect, operation, standard) in [
        (
            "import Benitoite.Unofficial.Failure\n",
            "Failure.Fail[String]",
            "Failure.raise(\"bad\")",
            true,
        ),
        (
            "import Benitoite.Unofficial.Failure as F\n",
            "F.Fail[String]",
            "F.raise(\"bad\")",
            true,
        ),
        (
            "effect Fail\n  function raise(message: String) -> Unit\nend effect\n",
            "Fail",
            "raise(\"bad\")",
            false,
        ),
        (
            "effect Log\n  function write(message: String) -> Unit\nend effect\n",
            "Log",
            "write(\"bad\")",
            false,
        ),
    ] {
        for (attribute, name, subcommand) in [("", "main", "check"), ("@test\n", "example", "test")]
        {
            let source = format!(
                "{import}{attribute}function {name}() -> Unit uses {effect}\n  {operation}\nend function\n"
            );
            let script = directory.write("help.bnt", &source);
            let mut invocation = command();
            invocation.args([subcommand, "--diagnostics=json"]);
            if subcommand == "test" {
                invocation.arg("--check");
            }
            let output = invocation.arg(script).output().unwrap();
            assert_eq!(exit_code(&output), 2, "{output:?}");
            let diagnostic: serde_json::Value = serde_json::from_slice(&output.stderr).unwrap();
            assert_eq!(diagnostic["code"], "E0506");
            let expected_effect = effect.strip_suffix("[String]").unwrap_or(effect);
            let mut expected = vec![serde_json::json!({
                "message": format!("handle `{expected_effect}` with `handle ... with` inside `{name}`"),
                "edits": [],
            })];
            if standard {
                expected.push(serde_json::json!({
                    "message": format!("or convert the failure with Failure.toResult inside `{name}`"),
                    "edits": [],
                }));
            }
            assert_eq!(diagnostic["helps"], serde_json::json!(expected));
        }
    }
}

// 作成時の関門: 単一報告の完全性・契約・元ソース・診断を CLI の境界で守る。
// 既存の check は成功時に情報を出さないため、誤った空集合や再描画の退行を捕まえない。
// 実ファイルと既存の CLI を使い、内部の表やテスト用の API には依存しない。
type CheckReportCase<'a> = (
    &'a str,
    Option<&'a [u8]>,
    Option<&'a [&'a str]>,
    &'a str,
    Option<&'a str>,
    bool,
    &'a [(&'a str, &'a [u8])],
);

#[test]
fn main_check_reports_contracts_without_execution() {
    check_main_reports(&[
        ("handled-failure", Some(b"import Benitoite.Unofficial.Failure\nfunction main() -> Unit\n  bind result: Result[Unit, String] <- Failure.toResult(body: lambda() return Failure.raise(\"stop\") end lambda)\nend function\n"), Some(&[]), "absent", None, false, &[]),
        ("pure", Some(b"function main() -> Unit\nend function\n"), Some(&[]), "absent", None, false, &[]),
        ("declared", Some("\u{feff}// 日本語\r\nimport Benitoite.Unofficial.IO.Console\r\nimport Benitoite.Unofficial.IO.Process\r\nfunction main() -> Unit uses Process.Exit, State, Console.Write\r\n    Console.writeLine(\"must not execute\")\r\nend function\r\n".as_bytes()), Some(&["Console.Write", "Process.Exit", "State"]), "absent", None, true, &[]),
        ("io-all", Some(b"function main() -> Unit uses IO.All\nend function\n"), Some(&["Clock.Time", "Console.Read", "Console.Write", "File.Read", "File.Write", "Process.Environment", "Process.Exit", "Process.Run", "Random.Generate", "State"]), "absent", None, false, &[]),
        ("non-io-effects", Some(b"import Benitoite.Unofficial.Network.Http\nfunction main() -> Unit uses Http.Listen, Http.Connect\nend function\n"), Some(&["Http.Connect", "Http.Listen"]), "absent", None, false, &[]),
        ("uses-text", Some(b"// uses IO.All, Process.Exit; Process.shell(\"ignored\")\nfunction main() -> Unit\n    bind text <- \"uses Console.Write; Process.shell\"\nend function\n"), Some(&[]), "absent", None, false, &[]),
        ("user-alias", Some(b"import Benitoite.Unofficial.IO.Console\nimport Helper as P\nfunction main() -> Unit uses Console.Write\n    P.write()\nend function\n"), Some(&["Console.Write"]), "absent", None, false, &[("Helper.bnt", b"import Benitoite.Unofficial.IO.Console\npublic function write() -> Unit uses Console.Write\n    Console.writeLine(\"must not execute\")\nend function\n")]),
    ]);
}

#[test]
fn main_check_reports_failures_without_execution() {
    check_main_reports(&[
        ("unhandled-failure", Some(b"import Benitoite.Unofficial.Failure\nfunction main() -> Unit uses Failure.Fail[String]\n  Failure.raise(\"stop\")\nend function\n"), None, "unknown", Some("E0506"), false, &[]),
        ("no-main", Some(b"function helper() -> Unit\nend function\n"), None, "unknown", Some("E0414"), false, &[]),
        ("syntax", Some(b"function main( -> Unit\nend function\n"), None, "unknown", None, false, &[]),
        ("invalid-utf8", Some(b"// \xff\nfunction main() -> Unit\nend function\n"), None, "unknown", None, false, &[]),
        ("unreadable", None, None, "unknown", Some("E0101"), false, &[]),
        ("assert-main-rejected", Some(b"function main() -> Unit uses Assert.Check\nend function\n"), None, "unknown", Some("E0415"), false, &[]),
        ("builtin-alias", Some(b"import Benitoite.Unofficial.IO.File as Console\nfunction main() -> Result[Unit, String] uses Console.Write\n    return Console.writeText(path: \"must-not-exist\", text: \"hello\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)\nend function\n"), None, "unknown", Some("E0339"), false, &[]),
        ("missing-import", Some(b"import Missing\nfunction main() -> Unit\nend function\n"), None, "unknown", Some("E0318"), false, &[]),
    ]);
}

#[test]
fn main_check_reports_warnings_without_execution() {
    check_main_reports(&[
        ("warning", Some(b"import Benitoite.Unofficial.IO.Process\n@deprecated(\"use current instead\")\nfunction old() -> Unit\nend function\nfunction main() -> Unit\n    old()\nend function\n"), Some(&[]), "absent", Some("W0301"), true, &[]),
        ("warning-denied", Some(b"import Benitoite.Unofficial.IO.Process\n@deprecated(\"use current instead\")\nfunction old() -> Unit\nend function\nfunction main() -> Unit\n    old()\nend function\n"), None, "unknown", Some("W0301"), true, &[]),
    ]);
}

#[test]
fn main_control_flow_reports_match_effect_limits() {
    let cases: &[CheckReportCase<'_>] = &[
        ("exit", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit uses Process.Exit\n    Process.exit(7)\nend function\n"), Some(&["Process.Exit"]), "absent", None, true, &[]),
        ("die", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit uses Process.Exit\n    bind value: Unit <- try Option.None or die(\"must not execute\")\nend function\n"), Some(&["Process.Exit"]), "absent", None, true, &[]),
        ("die-handled", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit\n    bind value <- handle\n        try Option.None or die\n    with\n        case Process.exit(code) -> ()\n    end handle\nend function\n"), Some(&[]), "absent", None, true, &[]),
        ("die-handled-declared", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit uses Process.Exit\n    bind value <- handle\n        try Option.None or die\n    with\n        case Process.exit(code) -> ()\n    end handle\nend function\n"), Some(&["Process.Exit"]), "absent", None, true, &[]),
        ("exit-handled", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit\n    bind value <- handle\n        Process.exit(7)\n    with\n        case Process.exit(code) -> ()\n    end handle\nend function\n"), Some(&[]), "absent", None, true, &[]),
        ("exit-handled-declared", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit uses Process.Exit\n    bind value <- handle\n        Process.exit(7)\n    with\n        case Process.exit(code) -> ()\n    end handle\nend function\n"), Some(&["Process.Exit"]), "absent", None, true, &[]),
        ("try-bare", Some(b"function main() -> Result[Unit, String]\n    bind value <- try Result.Error(\"must not execute\")\n    return Result.Ok(())\nend function\n"), Some(&[]), "absent", None, false, &[]),
        ("try-return", Some(b"function main() -> Result[Unit, String]\n    bind value <- try Result.Error(\"must not execute\") or return\n    return Result.Ok(())\nend function\n"), Some(&[]), "absent", None, false, &[]),
    ];
    check_main_reports(cases);
    for &(name, bytes, _, _, _, _, _) in cases {
        let directory = TestDirectory::new();
        let script = directory.path.join("main.bnt");
        fs::write(&script, bytes.unwrap()).unwrap();
        let report = command()
            .args(["check", "--report=json"])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(exit_code(&report), 0, "{name}: {report:?}");
        let report: serde_json::Value = serde_json::from_slice(&report.stdout).unwrap();
        let effects = report["aggregateEffects"]["expanded"].as_array().unwrap();
        let allowed = effects
            .iter()
            .map(|name| name.as_str().unwrap())
            .collect::<Vec<_>>()
            .join(",");
        let output = command()
            .args([
                "run",
                "--diagnostics=json",
                &format!("--allow-effects={allowed}"),
            ])
            .arg(&script)
            .output()
            .unwrap();
        let expected_exit = match name {
            "exit" => 7,
            "die" | "try-bare" | "try-return" => 1,
            _ => 0,
        };
        assert_eq!(exit_code(&output), expected_exit, "{name}: {output:?}");
        assert!(output.stdout.is_empty(), "{name}: {output:?}");
        if name == "die" {
            let diagnostic: serde_json::Value = serde_json::from_slice(&output.stderr).unwrap();
            assert_eq!(diagnostic["kind"], "die");
            assert!(diagnostic.as_object().unwrap().contains_key("code"));
            assert_eq!(diagnostic["code"], serde_json::Value::Null);
        } else if expected_exit != 1 {
            assert!(output.stderr.is_empty(), "{name}: {output:?}");
        }
        if !effects.is_empty() {
            let rejected = command()
                .args(["run", "--diagnostics=json", "--allow-effects="])
                .arg(&script)
                .output()
                .unwrap();
            assert_eq!(exit_code(&rejected), 2, "{name}: {rejected:?}");
            assert!(rejected.stdout.is_empty());
            let diagnostic: serde_json::Value = serde_json::from_slice(&rejected.stderr).unwrap();
            assert_eq!(diagnostic["code"], "E0512");
            assert_eq!(diagnostic["notes"][0], "effects not allowed: Process.Exit");
        }
    }
}

#[test]
fn main_check_reports_shell_without_execution() {
    check_main_reports(&[
        ("process-import", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit\nend function\n"), Some(&[]), "absent", None, true, &[]),
        ("shell-reference", Some(b"import Benitoite.Unofficial.IO.Process\nfunction unused() -> Result[Process.Output, IOError] uses Process.Run\n    return Process.shell(\"must not execute\")\nend function\nfunction main() -> Unit\nend function\n"), Some(&[]), "present", None, true, &[]),
        ("shell-direct", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit uses Process.Run\n    bind output <- Process.shell(\"touch must-not-exist\")\nend function\n"), Some(&["Process.Run"]), "present", None, true, &[]),
        ("shell-value", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit\n    bind action <- Process.shell\nend function\n"), Some(&[]), "present", None, true, &[]),
        ("shell-helper", Some(b"import Helper as P\nfunction main() -> Unit\nend function\n"), Some(&[]), "present", None, true, &[("Helper.bnt", b"import Benitoite.Unofficial.IO.Process\npublic function unused() -> Unit\n    bind action <- Process.shell\nend function\n")]),
        ("shell-user", Some(b"import Benitoite.Unofficial.IO.Process\nfunction shell() -> Unit\nend function\nfunction main() -> Unit\n    shell()\n    bind text <- \"Process.shell\"\nend function\n"), Some(&[]), "absent", None, true, &[]),
        ("process-handler", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit\n    bind value <- handle\n        ()\n    with\n        case Process.shell(commandLine) -> ()\n        case Process.run(command) -> ()\n        case Process.runAttached(command) -> ()\n    end handle\nend function\n"), Some(&[]), "absent", None, true, &[]),
        ("process-handler-body", Some(b"import Benitoite.Unofficial.IO.Process\nfunction main() -> Unit\n    bind value <- handle\n        ()\n    with\n        case Process.shell(commandLine) ->\n            bind action <- Process.shell\n            ()\n        case Process.run(command) -> ()\n        case Process.runAttached(command) -> ()\n    end handle\nend function\n"), Some(&[]), "present", None, true, &[]),
        ("die-implicit-process", Some(b"function unused() -> Unit uses IO.All\n    bind value: Unit <- try Option.None or die\nend function\nfunction main() -> Unit\nend function\n"), Some(&[]), "absent", None, true, &[]),
    ]);
}

#[test]
fn main_check_reports_sources_without_execution() {
    check_main_reports(&[
        ("lf", Some(b"// source\nfunction main() -> Unit\nend function\n"), Some(&[]), "absent", None, false, &[]),
        ("crlf", Some(b"// source\r\nfunction main() -> Unit\r\nend function\r\n"), Some(&[]), "absent", None, false, &[]),
        ("bom", Some(b"\xef\xbb\xbf// source\nfunction main() -> Unit\nend function\n"), Some(&[]), "absent", None, false, &[]),
        ("dependency-package", Some(b"import Tk.Helper\nfunction main() -> Unit\nend function\n"), Some(&[]), "present", None, true, &[
            ("package.bnt", b"// root config\ndependency Tk\n    path \"deps/kit\"\nend dependency\n"),
            ("deps/kit/package.bnt", b"language \"0.0.13\"\npackage Kit\nend package\n"),
            ("deps/kit/Helper.bnt", b"import Benitoite.Unofficial.IO.Process\npublic function unused() -> Unit\n    bind action <- Process.shell\nend function\n"),
        ]),
    ]);
}

// 既存必須欄の厳密な比較は保ち、追加欄の値は報告の集計の表で検査する。
fn report_without_interval_extension(report: &serde_json::Value) -> serde_json::Value {
    fn strip_bounds(value: &mut serde_json::Value) {
        match value {
            serde_json::Value::Object(fields) => {
                fields.remove("bounds");
                for value in fields.values_mut() {
                    strip_bounds(value);
                }
            }
            serde_json::Value::Array(values) => {
                for value in values {
                    strip_bounds(value);
                }
            }
            serde_json::Value::Null
            | serde_json::Value::Bool(_)
            | serde_json::Value::Number(_)
            | serde_json::Value::String(_) => {}
        }
    }
    let mut legacy = report.clone();
    // 任意欄を読まない旧受け手の必須欄の契約を保つ。bounds は専用の表で確かめる。
    strip_bounds(&mut legacy);
    assert!(
        legacy
            .as_object_mut()
            .unwrap()
            .remove("intervalAnalysis")
            .is_some()
    );
    for target in legacy["targets"].as_array_mut().unwrap() {
        assert!(
            target
                .as_object_mut()
                .unwrap()
                .remove("intervalAnalysis")
                .is_some()
        );
    }
    legacy
}

fn check_main_reports(cases: &[CheckReportCase<'_>]) {
    use serde_json::{Value, json};
    use sha2::{Digest, Sha256};

    let version: Value =
        serde_json::from_slice(&command().arg("--version=json").output().unwrap().stdout).unwrap();
    for &(name, bytes, effects, shell, diagnostic_code, process_loaded, files) in cases {
        let directory = TestDirectory::new();
        for (path, contents) in files {
            let path = directory.path.join(path);
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            fs::write(path, contents).unwrap();
        }
        let script = directory.path.join(format!("{name}.bnt"));
        if let Some(bytes) = bytes {
            fs::write(&script, bytes).unwrap();
        }
        let mut invocation = command();
        invocation.current_dir(&directory.path);
        invocation.args(["check", "--report=json"]);
        if name != "pure" {
            invocation.arg("--diagnostics=json");
        }
        if name == "warning-denied" {
            invocation.arg("--deny-warnings");
        }
        let output = invocation.arg(&script).output().unwrap();
        let success = effects.is_some();
        assert_eq!(
            exit_code(&output),
            if success { 0 } else { 2 },
            "{name}: {output:?}"
        );
        assert!(output.stderr.is_empty(), "{name}: {output:?}");
        assert!(output.stdout.ends_with(b"\n"));
        // from_slice は、後ろに別の JSON や利用者の出力が混ざった場合も失敗する。
        let report: Value = serde_json::from_slice(&output.stdout).unwrap();
        let mut ordinary = command();
        ordinary.current_dir(&directory.path);
        ordinary.args(["check", "--diagnostics=json"]);
        if name == "warning-denied" {
            ordinary.arg("--deny-warnings");
        }
        let ordinary = ordinary.arg(&script).output().unwrap();
        assert_eq!(exit_code(&ordinary), exit_code(&output));
        assert!(ordinary.stdout.is_empty());
        assert!(
            !directory.path.join("must-not-exist").exists(),
            "{name}: executed user code"
        );
        let diagnostics: Vec<Value> = String::from_utf8(ordinary.stderr)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        if let Some(code) = diagnostic_code {
            assert!(
                diagnostics.iter().any(|diag| diag["code"] == code),
                "{name}: {report}"
            );
        }
        if matches!(name, "warning" | "warning-denied") {
            assert_eq!(diagnostics.len(), 1);
            assert_eq!(diagnostics[0]["kind"], "check");
            assert_eq!(
                diagnostics[0]["severity"],
                if success { "warning" } else { "error" }
            );
        }
        let sources = report["sources"].as_array().unwrap();
        let mut source_ids = Vec::new();
        let mut entry_source = Value::Null;
        for (index, source) in sources.iter().enumerate() {
            let id = format!("t0:s{index}");
            let path = source["displayPath"].as_str().unwrap();
            let (original, kind) = if let Some(relative) = path.strip_prefix("<benitoite>/") {
                (
                    Path::new(env!("CARGO_MANIFEST_DIR"))
                        .join("src/prelude/stdlib")
                        .join(relative),
                    "prelude",
                )
            } else if path == script.to_str().unwrap() || files.is_empty() {
                assert_eq!(path, script.to_str().unwrap());
                entry_source = json!(id);
                (script.clone(), "user")
            } else {
                let (relative, _) = files
                    .iter()
                    .find(|(relative, _)| directory.path.join(relative) == Path::new(path))
                    .unwrap_or_else(|| panic!("{name}: unexpected source {path}"));
                (directory.path.join(relative), "user")
            };
            let digest = Sha256::digest(fs::read(original).unwrap());
            let hash = digest
                .iter()
                .map(|byte| format!("{byte:02x}"))
                .collect::<String>();
            assert_eq!(
                *source,
                json!({
                    "sourceId": id, "displayPath": path, "kind": kind,
                    "contentHash": { "algorithm": "sha256", "value": hash }
                })
            );
            source_ids.push(id);
        }
        if bytes.is_some() {
            assert!(!entry_source.is_null(), "{name}: {report}");
        } else {
            assert!(entry_source.is_null(), "{name}: {report}");
        }
        for (relative, _) in files {
            let path = directory.path.join(relative).display().to_string();
            assert!(
                sources.iter().any(|source| source["displayPath"] == path),
                "{name}: missing {path}"
            );
        }
        if success {
            assert!(sources.iter().any(|source| source["kind"] == "prelude"));
            assert_eq!(
                sources
                    .iter()
                    .any(|source| source["displayPath"] == "<benitoite>/IO/Process.bnt"),
                process_loaded,
                "{name}"
            );
        }
        let main = if let Some(effects) = effects {
            let bytes = bytes.unwrap();
            let offset = bytes.windows(4).position(|bytes| bytes == b"main").unwrap();
            let line = bytes[..offset]
                .iter()
                .filter(|byte| **byte == b'\n')
                .count()
                + 1;
            json!({
                "symbol": "main", "location": { "file": script.display().to_string(),
                    "start": { "line": line, "column": 10, "offset": offset },
                    "end": { "line": line, "column": 14, "offset": offset + 4 }, "label": "" },
                "effects": { "basis": "declaredUpperBound", "expanded": effects },
                "processShellReference": shell, "shellReferenceScope": "checkedProgram"
            })
        } else {
            Value::Null
        };
        let diagnostic_targets = diagnostics
            .iter()
            .enumerate()
            .map(|(index, _)| json!({ "diagnosticIndex": index, "targetId": "t0" }))
            .collect::<Vec<_>>();
        let status = if success { "ok" } else { "checkError" };
        assert_eq!(
            report_without_interval_extension(&report),
            json!({
                "schemaVersion": 1, "kind": "checkReport",
                "producer": { "name": "benitoite", "version": env!("CARGO_PKG_VERSION"), "build": version["build"] },
                "status": status, "complete": success, "targetsComplete": true, "executed": false,
                "requestedTargets": [{ "requestIndex": 0, "path": script.display().to_string() }],
                "targets": [{ "targetId": "t0", "requestIndex": 0, "entry": script.display().to_string(),
                    "root": directory.path.display().to_string(), "sourceId": entry_source,
                    "kind": "main", "status": status, "complete": success, "main": main }],
                "sources": sources, "sourceSets": [{ "targetId": "t0", "sourceIds": source_ids }],
                "aggregateEffects": effects.map(|expanded| json!({ "basis": "declaredUpperBound", "expanded": expanded })),
                "diagnostics": diagnostics, "diagnosticTargets": diagnostic_targets
            }),
            "{name}"
        );
    }
}

// 作成時の関門: 報告認識後の panic は不明の契約を持つ単一の internalError になる。
// 通常の check の stderr の試験では、報告モードだけの取りこぼしを捕まえられない。
// 既存の開発用 panic と実プロセスだけを使う。
#[test]
fn check_report_panics_preserve_failure_and_single_output() {
    use serde_json::{Value, json};

    let directory = TestDirectory::new();
    let script = directory.write("main.bnt", "function main() -> Unit\nend function\n");
    let version: Value =
        serde_json::from_slice(&command().arg("--version=json").output().unwrap().stdout).unwrap();
    for json_diagnostics in [false, true] {
        let mut invocation = command();
        invocation.args(["check", "--report=json"]);
        if json_diagnostics {
            invocation.arg("--diagnostics=json");
        }
        let output = invocation
            .arg(&script)
            .env("BENITOITE_DEV_PANIC", "check")
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 3, "{output:?}");
        assert!(output.stderr.is_empty(), "{output:?}");
        assert!(output.stdout.ends_with(b"\n"));
        let report: Value = serde_json::from_slice(&output.stdout).unwrap();
        let diagnostics = report["diagnostics"].as_array().unwrap();
        assert_eq!(diagnostics.len(), 1);
        let diagnostic = &diagnostics[0];
        assert_eq!(diagnostic["kind"], "internal");
        assert_eq!(diagnostic["severity"], "error");
        assert_eq!(diagnostic["code"], Value::Null);
        assert_eq!(diagnostic["primary"], Value::Null);
        let notes = diagnostic["notes"].as_array().unwrap();
        for note in [
            "in the check stage",
            "the panic occurred in the compiler thread",
            "BENITOITE_DEV_PANIC=check",
        ] {
            assert!(
                notes
                    .iter()
                    .any(|value| value.as_str().unwrap().contains(note)),
                "{report}"
            );
        }
        assert!(!String::from_utf8_lossy(&output.stdout).contains("panicked at"));
        assert_eq!(
            report_without_interval_extension(&report),
            json!({
                "schemaVersion": 1, "kind": "checkReport",
                "producer": { "name": "benitoite", "version": env!("CARGO_PKG_VERSION"), "build": version["build"] },
                "status": "internalError", "complete": false, "targetsComplete": true, "executed": false,
                "requestedTargets": [{"requestIndex": 0, "path": script.display().to_string()}],
                "targets": [{"targetId": "t0", "requestIndex": 0, "entry": script.display().to_string(),
                    "root": directory.path.display().to_string(), "sourceId": null,
                    "kind": "main", "status": "internalError", "complete": false, "main": null}],
                "sources": [], "sourceSets": [{"targetId": "t0", "sourceIds": []}],
                "aggregateEffects": null, "diagnostics": diagnostics,
                "diagnosticTargets": [{"diagnosticIndex": 0, "targetId": "t0"}]
            })
        );
    }
    // 環境の初期化は report の認識より前に行うため、完成した報告は返さない。
    let output = command()
        .args(["check", "--report=json"])
        .arg(&script)
        .env("BENITOITE_DEV_IO_MODE", "invalid")
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2);
    assert!(output.stdout.is_empty());
    assert_eq!(
        String::from_utf8(output.stderr).unwrap(),
        "error: invalid value `invalid` for `BENITOITE_DEV_IO_MODE`\nrun `benitoite --help` for usage\n"
    );
}

// 作成時の関門: 成功・検査失敗・使い方の誤り・内部エラーでも出力失敗は1を返す。
// run のパイプ失敗は別の実行時の経路なので、報告の経路を実際の閉じたパイプで確かめる。
#[test]
fn check_report_write_failures_exit_once_without_stderr_fallback() {
    let directory = TestDirectory::new();
    let script = directory.write("main.bnt", "function main() -> Unit\nend function\n");
    let empty = directory.path.join("empty");
    fs::create_dir(&empty).unwrap();
    for (extra, path, panic) in [
        (None, Some(script.clone()), false),
        (None, Some(directory.path.join("missing.bnt")), false),
        (Some("--bogus"), Some(script.clone()), false),
        (None, None, false),
        (None, Some(empty), false),
        (None, Some(script.clone()), true),
    ] {
        let mut invocation = command();
        invocation.args(["check", "--report=json"]);
        if let Some(extra) = extra {
            invocation.arg(extra);
        }
        if let Some(path) = path {
            invocation.arg(path);
        }
        if panic {
            invocation.env("BENITOITE_DEV_PANIC", "check");
        }
        let (reader, writer) = std::io::pipe().unwrap();
        drop(reader);
        let output = invocation.stdout(writer).output().unwrap();
        assert_eq!(
            exit_code(&output),
            1,
            "{extra:?}, panic={panic}: {output:?}"
        );
        assert!(output.stderr.is_empty(), "{output:?}");
        assert!(output.stdout.is_empty(), "{output:?}");
    }
}

// 作成時の関門: 誤りと有効な report の順序、スクリプト・分離値との境界を守る。
// 成功報告の表では解析の途中の停止を捕まえない。実プロセスの全出力を比較し、
// 報告だけの code:null が従来の診断ストリームへ混ざる退行も検出する。
#[test]
fn check_usage_reports_respect_option_scope_and_argument_order() {
    use serde_json::{Value, json};

    let directory = TestDirectory::new();
    let script = directory.write("main.bnt", "function main() -> Unit\nend function\n");
    let empty = directory.path.join("empty");
    fs::create_dir(&empty).unwrap();
    let version: Value =
        serde_json::from_slice(&command().arg("--version=json").output().unwrap().stdout).unwrap();
    type Case<'a> = (&'a [&'a str], &'a str, bool, Option<&'a str>);
    let cases: &[Case<'_>] = &[
        (
            &[
                "check",
                "--allow-effects",
                "State",
                "--report=json",
                "SCRIPT",
            ],
            "option `--allow-effects` is not accepted by `check`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--allow-effects", "--report=json", "SCRIPT"],
            "option `--allow-effects` is not accepted by `check`",
            false,
            None,
        ),
        (
            &["check", "--report=json", "--allow-effects=", "SCRIPT"],
            "option `--allow-effects` is not accepted by `check`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--diagnostics=text", "--report=json", "SCRIPT"],
            "`--report=json` cannot be combined with `--diagnostics=text`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=json", "--diagnostics=text", "SCRIPT"],
            "`--report=json` cannot be combined with `--diagnostics=text`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--bogus", "--report=json", "SCRIPT"],
            "unknown option `--bogus`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=json", "--bogus", "SCRIPT"],
            "unknown option `--bogus`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["--bogus", "--report=json", "check", "SCRIPT"],
            "unknown option `--bogus`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--bogus", "--second", "--report=json", "SCRIPT"],
            "unknown option `--bogus`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=json", "--report=json", "SCRIPT"],
            "option `--report` may only be specified once",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=xml", "--report=json", "SCRIPT"],
            "invalid value `xml` for `--report`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=json", "--report=xml", "SCRIPT"],
            "option `--report` may only be specified once",
            true,
            Some("SCRIPT"),
        ),
        (
            &[
                "check",
                "--deny-warnings",
                "--deny-warnings",
                "--report=json",
                "SCRIPT",
            ],
            "option `--deny-warnings` may only be specified once",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--diagnostics=invalid", "--report=json", "SCRIPT"],
            "invalid value `invalid` for `--diagnostics`",
            true,
            Some("SCRIPT"),
        ),
        (
            &[
                "check",
                "--report=json",
                "--max-call-stack=invalid",
                "SCRIPT",
            ],
            "invalid value `invalid` for `--max-call-stack`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=json"],
            "missing script path",
            true,
            None,
        ),
        (
            &["check", "--report=json", "SCRIPT", "extra"],
            "unexpected argument `extra`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report=json", "EMPTY"],
            "NO_MAIN",
            true,
            Some("EMPTY"),
        ),
        (
            &["check", "--bogus", "SCRIPT"],
            "unknown option `--bogus`",
            false,
            None,
        ),
        (
            &["check", "--diagnostics=json", "--bogus", "SCRIPT"],
            "unknown option `--bogus`",
            false,
            None,
        ),
        (
            &["check", "--report=xml", "SCRIPT"],
            "invalid value `xml` for `--report`",
            false,
            None,
        ),
        (
            &["check", "--report", "json", "SCRIPT"],
            "invalid value `` for `--report`",
            false,
            None,
        ),
        (
            &["check", "--report"],
            "invalid value `` for `--report`",
            false,
            None,
        ),
        (
            &["check", "SCRIPT", "--report=json"],
            "unexpected argument `--report=json`",
            false,
            None,
        ),
        (
            &["check", "--bogus", "SCRIPT", "--report=json"],
            "unknown option `--bogus`",
            false,
            None,
        ),
        (
            &["check", "--diagnostics", "--report=json", "SCRIPT"],
            "invalid value `` for `--diagnostics`",
            false,
            None,
        ),
        (
            &["check", "--max-call-stack", "--report=json", "SCRIPT"],
            "invalid value `` for `--max-call-stack`",
            false,
            None,
        ),
        (
            &["check", "--report", "--report=json", "SCRIPT"],
            "invalid value `` for `--report`",
            false,
            None,
        ),
        (
            &["check", "--wasm-fuel", "--report=json", "SCRIPT"],
            "unknown option `--wasm-fuel`",
            false,
            None,
        ),
        (
            &["check", "--diagnostics=--report=json", "SCRIPT"],
            "invalid value `--report=json` for `--diagnostics`",
            false,
            None,
        ),
        (
            &["check", "--diagnostics", "text", "--report=json", "SCRIPT"],
            "invalid value `` for `--diagnostics`",
            true,
            Some("SCRIPT"),
        ),
        (
            &[
                "check",
                "--diagnostics",
                "--report=json",
                "--report=json",
                "SCRIPT",
            ],
            "invalid value `` for `--diagnostics`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["check", "--report", "json", "--report=json", "SCRIPT"],
            "invalid value `` for `--report`",
            true,
            Some("SCRIPT"),
        ),
        (
            &["run", "--report=json", "SCRIPT"],
            "option `--report` is not accepted by `run`",
            false,
            None,
        ),
        (
            &["--report=json", "SCRIPT"],
            "option `--report` is not accepted by `run`",
            false,
            None,
        ),
    ];
    for &(args, detail, reported, requested) in cases {
        let path = |value: &str| match value {
            "SCRIPT" => script.as_os_str().to_owned(),
            "EMPTY" => empty.as_os_str().to_owned(),
            value => value.into(),
        };
        let output = command()
            .args(args.iter().map(|arg| path(arg)))
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 2, "{args:?}: {output:?}");
        let detail = if detail == "NO_MAIN" {
            format!("directory `{}` has no `main.bnt`", empty.display())
        } else {
            detail.to_owned()
        };
        if reported {
            assert!(output.stderr.is_empty(), "{args:?}: {output:?}");
            assert!(output.stdout.ends_with(b"\n"), "{args:?}: {output:?}");
            let report: Value = serde_json::from_slice(&output.stdout).unwrap();
            let requested_targets = requested
                .map(|value| json!({"requestIndex": 0, "path": path(value).to_str().unwrap()}))
                .into_iter()
                .collect::<Vec<_>>();
            assert_eq!(
                report_without_interval_extension(&report),
                json!({
                    "schemaVersion": 1, "kind": "checkReport",
                    "producer": {"name": "benitoite", "version": env!("CARGO_PKG_VERSION"), "build": version["build"]},
                    "status": "usageError", "complete": false, "targetsComplete": false, "executed": false,
                    "requestedTargets": requested_targets, "targets": [], "sources": [], "sourceSets": [],
                    "aggregateEffects": null,
                    "diagnostics": [{"kind": "check", "severity": "error", "code": null,
                        "message": detail, "primary": null, "secondary": [], "notes": [], "helps": []}],
                    "diagnosticTargets": [{"diagnosticIndex": 0, "targetId": null}]
                }),
                "{args:?}"
            );
        } else {
            assert!(output.stdout.is_empty(), "{args:?}: {output:?}");
            assert_eq!(
                String::from_utf8(output.stderr).unwrap(),
                format!("error: {detail}\nrun `benitoite --help` for usage\n"),
                "{args:?}"
            );
        }
    }
    // run のスクリプト引数は、report と同じ字面でも処理系のオプションにしない。
    let output = command()
        .arg("run")
        .arg(&script)
        .arg("--report=json")
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert!(output.stdout.is_empty(), "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
}

#[test]
fn cli_process_contracts() {
    let directory = TestDirectory::new();
    let hello = directory.write(
        "hello.bnt",
        "import Benitoite.Unofficial.IO.Console\n\nfunction main() -> Unit uses Console.Write\n    Console.writeLine(\"hello\")\nend function\n",
    );

    // 版問い合わせの受理位置と値は CLI の契約である。実行時の入力だけで確かめ、
    // ビルド情報の採取そのものは build_info の実ビルドの表へ委ねる。
    let usage_cases: &[(&str, &[&str])] = &[
        ("missing subcommand", &[]),
        ("unknown option", &["run", "--unknown"]),
        ("missing script path", &["run"]),
        ("invalid value `text` for `--version`", &["--version=text"]),
        ("invalid value `` for `--version`", &["--version="]),
        ("unexpected argument `extra`", &["--version=json", "extra"]),
        (
            "unexpected argument `--help`",
            &["--version=json", "--help"],
        ),
        (
            "unexpected argument `--version=json`",
            &["--version=json", "--version=json"],
        ),
        (
            "unknown option `--version=json`",
            &["run", "--version=json"],
        ),
        (
            "unknown option `--version=json`",
            &["--diagnostics=json", "--version=json"],
        ),
        (
            "unknown option `--version=json`",
            &["test", "--version=json"],
        ),
        (
            "missing value for `--allow-effects`",
            &["run", "--allow-effects"],
        ),
        (
            "option `--allow-effects` may only be specified once",
            &["run", "--allow-effects=", "--allow-effects=State", "a.bnt"],
        ),
        (
            "duplicate effect name `State` in `--allow-effects`",
            &["run", "--allow-effects=State,State", "a.bnt"],
        ),
        (
            "empty effect name in `--allow-effects`",
            &["run", "--allow-effects=State,", "a.bnt"],
        ),
        (
            "empty effect name in `--allow-effects`",
            &["run", "--allow-effects=,State", "a.bnt"],
        ),
        (
            "empty effect name in `--allow-effects`",
            &["run", "--allow-effects=State,,Console.Write", "a.bnt"],
        ),
        (
            "invalid effect name `Failure.Fail[String]` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=Failure.Fail[String]", "a.bnt"],
        ),
        (
            "invalid effect name `IO.All` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=IO.All", "a.bnt"],
        ),
        (
            "invalid effect name `IO.Console.Write` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=IO.Console.Write", "a.bnt"],
        ),
        (
            "invalid effect name `Console.Unknown` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=Console.Unknown", "a.bnt"],
        ),
        (
            "invalid effect name `console.write` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=console.write", "a.bnt"],
        ),
        (
            "invalid effect name `Custom` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=Custom", "a.bnt"],
        ),
        (
            "invalid effect name `P.Run` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=P.Run", "a.bnt"],
        ),
        (
            "invalid effect name `*` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=*", "a.bnt"],
        ),
        (
            "invalid effect name ` State` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects= State", "a.bnt"],
        ),
        (
            "invalid effect name `State ` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=State ", "a.bnt"],
        ),
        (
            "invalid effect name `State\t` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects=State\t", "a.bnt"],
        ),
        (
            "invalid effect name `--report=json` in `--allow-effects`; use atomic names from `expanded`",
            &["run", "--allow-effects", "--report=json", "a.bnt"],
        ),
        (
            "invalid effect name `test` in `--allow-effects`; use atomic names from `expanded`",
            &["--allow-effects", "test", "a.bnt"],
        ),
        (
            "option `--allow-effects` is not accepted by `check`",
            &["check", "--allow-effects=", "a.bnt"],
        ),
    ];
    for &(name, args) in usage_cases {
        let output = command().args(args).output().unwrap_or_else(|error| {
            panic!("could not run CLI for {name}: {error}");
        });
        assert_eq!(exit_code(&output), 2, "{name}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.contains("error:"), "{name}: {stderr}");
        assert!(stderr.contains("--help"), "{name}: {stderr}");
        assert!(output.stdout.is_empty(), "{name}: {output:?}");
        if args
            .iter()
            .any(|arg| arg.starts_with("--version=") || arg.starts_with("--allow-effects"))
        {
            assert_eq!(
                stderr,
                format!("error: {name}\nrun `benitoite --help` for usage\n")
            );
        }
    }

    let version = command()
        .arg("--version")
        .output()
        .unwrap_or_else(|error| panic!("could not run --version: {error}"));
    assert_eq!(exit_code(&version), 0);
    let (major, minor, patch) = char::UNICODE_VERSION;
    assert_eq!(
        String::from_utf8_lossy(&version.stdout),
        format!(
            "benitoite {}\nUnicode {major}.{minor}.{patch}\n",
            env!("CARGO_PKG_VERSION")
        )
    );
    assert!(version.stderr.is_empty());
    let version_with_extra = command().args(["--version", "extra"]).output().unwrap();
    assert_eq!(exit_code(&version_with_extra), 0);
    assert_eq!(version_with_extra.stdout, version.stdout);
    assert!(version_with_extra.stderr.is_empty());

    let version_json = command()
        .arg("--version=json")
        // 実行時の環境をビルド時の自己申告に混ぜないことも確認する。
        .env("BENITOITE_BUILD_COMMIT", "invalid-runtime-commit")
        .env("BENITOITE_BUILD_DIRTY", "invalid-runtime-dirty")
        .env("BENITOITE_EMBEDDED_BUILD_TARGET", "runtime-target")
        .output()
        .unwrap();
    assert_eq!(exit_code(&version_json), 0);
    assert!(version_json.stderr.is_empty());
    let json_text = String::from_utf8(version_json.stdout).unwrap();
    assert!(json_text.ends_with('\n'));
    assert_eq!(json_text.lines().count(), 1);
    let value: serde_json::Value = serde_json::from_str(&json_text).unwrap();
    // 埋め込み値との一致とは別に、公開 JSON の値域と由来の契約を確かめる。
    let build = &value["build"];
    assert!(
        build["commit"].is_null()
            || build["commit"].as_str().is_some_and(|commit| {
                matches!(commit.len(), 40 | 64)
                    && commit
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
            }),
        "{json_text}"
    );
    assert!(
        matches!(
            build["provenance"]["commit"].as_str(),
            Some("environment" | "git" | "unknown")
        ),
        "{json_text}"
    );
    assert!(
        matches!(
            build["provenance"]["dirty"].as_str(),
            Some("environment" | "notCollected")
        ),
        "{json_text}"
    );
    if build["provenance"]["commit"] == "git" {
        assert!(!build["commit"].is_null(), "{json_text}");
    }
    let commit = env!("BENITOITE_EMBEDDED_BUILD_COMMIT");
    let dirty = match env!("BENITOITE_EMBEDDED_BUILD_DIRTY") {
        "true" => Some(true),
        "false" => Some(false),
        "unknown" => None,
        other => panic!("unexpected embedded dirty value: {other}"),
    };
    assert_eq!(
        value,
        serde_json::json!({
            "schemaVersion": 1,
            "kind": "version",
            "name": "benitoite",
            "version": env!("CARGO_PKG_VERSION"),
            "unicodeVersion": format!("{major}.{minor}.{patch}"),
            "displayWidthUnicodeVersion": "17.0.0",
            "build": {
                "commit": if commit.is_empty() { None } else { Some(commit) },
                "dirty": dirty,
                "target": env!("BENITOITE_EMBEDDED_BUILD_TARGET"),
                "provenance": {
                    "commit": env!("BENITOITE_EMBEDDED_COMMIT_PROVENANCE"),
                    "dirty": env!("BENITOITE_EMBEDDED_DIRTY_PROVENANCE")
                }
            },
            "formats": { "version": [1], "diagnostics": [1], "testResults": [1, 2], "checkReport": [1], "testCheckReport": [1, 2], "effectLimit": [1], "loaderEnvironment": [1], "skillList": [1], "skillDocument": [1] },
            "loaderEnvironment": {
                "schemaVersion": 1,
                "mode": "always",
                "deniedPrefixes": ["DYLD_", "LD_"],
                "nameComparison": "asciiCaseInsensitive",
                "inherited": "unchanged",
                "errorKind": "InvalidInput"
            }
        })
    );

    #[cfg(unix)]
    for mode in ["--version", "--version=json"] {
        use std::os::{fd::OwnedFd, unix::net::UnixStream};
        let (writer, reader) = UnixStream::pair().unwrap();
        drop(reader);
        let output = command()
            .arg(mode)
            .stdout(Stdio::from(OwnedFd::from(writer)))
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 1, "{mode}: {output:?}");
        assert!(output.stderr.is_empty(), "{mode}: {output:?}");
    }

    let help = command()
        .arg("--help")
        .output()
        .unwrap_or_else(|error| panic!("could not run --help: {error}"));
    assert_eq!(exit_code(&help), 0);
    assert!(String::from_utf8_lossy(&help.stdout).starts_with("Usage:"));

    let run = command()
        .arg("run")
        .arg(&hello)
        .output()
        .unwrap_or_else(|error| panic!("could not run hello script: {error}"));
    assert_eq!(exit_code(&run), 0);
    assert_eq!(run.stdout, b"hello\n");
    assert!(run.stderr.is_empty());

    let missing = directory.path().join("missing.bnt");
    let missing_check = command()
        .arg("check")
        .arg(&missing)
        .output()
        .unwrap_or_else(|error| panic!("could not check missing script: {error}"));
    assert_eq!(exit_code(&missing_check), 2);
    let missing_stderr = String::from_utf8_lossy(&missing_check.stderr);
    assert!(missing_stderr.contains("E0101"), "{missing_stderr}");
    assert!(
        missing_stderr.contains(&missing.display().to_string()),
        "{missing_stderr}"
    );

    // run だけの対照では、check が共通の段の panic 境界を迂回する退行を捕まえない。
    for mode in ["run", "check"] {
        let panic_check = command()
            .arg(mode)
            .arg(&hello)
            .env("BENITOITE_DEV_PANIC", "check")
            .output()
            .unwrap_or_else(|error| panic!("could not exercise check panic: {error}"));
        assert_eq!(exit_code(&panic_check), 3);
        assert!(panic_check.stdout.is_empty());
        assert_internal_report(&panic_check.stderr);
        let text = String::from_utf8_lossy(&panic_check.stderr);
        assert!(
            text.contains("the panic occurred in the compiler thread"),
            "{text}"
        );
        assert_eq!(
            text.matches("BENITOITE_DEV_PANIC=check").count(),
            1,
            "{text}"
        );
    }

    let panic_run = command()
        .arg("run")
        .arg(&hello)
        .env("BENITOITE_DEV_PANIC", "run")
        .output()
        .unwrap_or_else(|error| panic!("could not exercise run panic: {error}"));
    assert_eq!(exit_code(&panic_run), 3);
    assert_eq!(panic_run.stdout, b"hello\n");
    assert_internal_report(&panic_run.stderr);

    for mode in ["run", "check"] {
        let panic_json = command()
            .args([mode, "--diagnostics=json"])
            .arg(&hello)
            .env("BENITOITE_DEV_PANIC", "check")
            .output()
            .unwrap_or_else(|error| panic!("could not exercise JSON internal report: {error}"));
        assert_eq!(exit_code(&panic_json), 3);
        assert!(panic_json.stdout.is_empty());
        let json_stderr = String::from_utf8_lossy(&panic_json.stderr);
        assert!(
            json_stderr.starts_with("{\"kind\":\"internal\",\"severity\":\"error\",\"code\":null,"),
            "{json_stderr}"
        );
        assert_eq!(json_stderr.lines().count(), 1, "{json_stderr}");
    }

    #[cfg(unix)]
    broken_pipe_is_a_runtime_error(&directory);

    #[cfg(unix)]
    invalid_utf8_argument_stops_before_main(&hello);
}

fn command() -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_benitoite"));
    command
        .env_remove("BENITOITE_DEV_PANIC")
        .env_remove("BENITOITE_DEV_IO_MODE")
        .env_remove("NO_COLOR");
    command
}

// 作成時の関門: 実際の CLI から、一覧の完全性と導入時と同じ本文・版・改行を守る。
// 既存の生成物の検査では、コマンドの接続、HOME への依存、インストール先の誤読を捕まえない。
// 外部のプロセスと一時ディレクトリだけを使い、本番の差し込み口は増やさない。
// JSON は取得した UTF-8 本文から独立に計算した長さ・SHA-256 と全欄を比較する。
// text の既存例だけでは、置換前のハッシュや文字数を byteLength とする退行を捕まえない。
#[test]
fn skill_documents_match_the_embedded_bundle_and_installed_bytes() {
    use benitoite::cli::tools::skill::{VERSION_PLACEHOLDER, files};
    use serde_json::{Value, json};
    use sha2::{Digest, Sha256};
    let directory = TestDirectory::new();
    let version = command().arg("--version=json").output().unwrap();
    assert_eq!(exit_code(&version), 0, "{version:?}");
    let version: Value = serde_json::from_slice(&version.stdout).unwrap();
    let producer = json!({
        "name": "benitoite", "version": env!("CARGO_PKG_VERSION"), "build": version["build"]
    });
    let mut names: Vec<_> = files().iter().map(|file| file.path).collect();
    names.sort_unstable();
    let expected_list = format!("{}\n", names.join("\n"));
    for home in [None, Some(directory.path().join("missing-home"))] {
        let mut invocation = command();
        invocation
            .current_dir(directory.path())
            .args(["skill", "list"]);
        if let Some(home) = home {
            invocation.env("HOME", home);
        } else {
            invocation.env_remove("HOME");
        }
        let output = invocation.output().unwrap();
        assert_eq!(exit_code(&output), 0, "{output:?}");
        assert!(output.stderr.is_empty(), "{output:?}");
        assert_eq!(output.stdout, expected_list.as_bytes());
    }
    assert_eq!(fs::read_dir(directory.path()).unwrap().count(), 0);
    let explicit_text = command()
        .current_dir(directory.path())
        .env_remove("HOME")
        .args(["skill", "list", "--format=text"])
        .output()
        .unwrap();
    assert_eq!(exit_code(&explicit_text), 0, "{explicit_text:?}");
    assert!(explicit_text.stderr.is_empty());
    assert_eq!(explicit_text.stdout, expected_list.as_bytes());

    let output = command()
        .current_dir(directory.path())
        .env_remove("HOME")
        .args(["skill", "install", "--project", "--agent=codex"])
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
    let installed = fs::canonicalize(directory.path())
        .unwrap()
        .join(".agents/skills/benitoite");
    assert_eq!(
        output.stdout,
        format!("installed {}\n", installed.display()).as_bytes()
    );
    let mut metadata = Vec::new();
    let mut saw_non_ascii = false;
    for file in files() {
        let path = installed.join(file.path);
        let expected = fs::read(&path).unwrap();
        if file.path == "SKILL.md" {
            assert_eq!(
                expected,
                file.text
                    .replace(VERSION_PLACEHOLDER, env!("CARGO_PKG_VERSION"))
                    .as_bytes()
            );
            let text = std::str::from_utf8(&expected).unwrap();
            assert!(!text.contains(VERSION_PLACEHOLDER));
            assert!(text.contains(&format!(
                "benitoite-version: \"{}\"",
                env!("CARGO_PKG_VERSION")
            )));
        } else {
            assert_eq!(expected, file.text.as_bytes(), "{}", file.path);
        }
        // 作業ディレクトリのインストール済み文書に同じ名前があっても、埋め込みから取得する。
        fs::write(&path, "local document; do not read").unwrap();
        let output = command()
            .current_dir(directory.path())
            .env_remove("HOME")
            .args(["skill", "show", file.path])
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 0, "{}: {output:?}", file.path);
        assert!(output.stderr.is_empty(), "{}: {output:?}", file.path);
        assert_eq!(output.stdout, expected, "{}", file.path);
        let text = std::str::from_utf8(&output.stdout).unwrap();
        saw_non_ascii |= !text.is_ascii();
        let content_hash = json!({
            "algorithm": "sha256", "value": Sha256::digest(&output.stdout)
                .iter().map(|byte| format!("{byte:02x}")).collect::<String>()
        });
        metadata.push(json!({
            "name": file.path, "byteLength": output.stdout.len(), "contentHash": content_hash
        }));
        let args = if file.path == "SKILL.md" {
            vec!["skill", "show", "--format=json", file.path]
        } else {
            vec!["skill", "show", file.path, "--format=json"]
        };
        let shown = command()
            .current_dir(directory.path())
            .env_remove("HOME")
            .args(args)
            .output()
            .unwrap();
        assert_eq!(exit_code(&shown), 0, "{}: {shown:?}", file.path);
        assert!(shown.stderr.is_empty(), "{}: {shown:?}", file.path);
        assert_eq!(shown.stdout.last(), Some(&b'\n'));
        assert_eq!(
            shown.stdout.iter().filter(|byte| **byte == b'\n').count(),
            1
        );
        let shown: Value = serde_json::from_slice(&shown.stdout).unwrap();
        assert_eq!(
            shown,
            json!({
                "schemaVersion": 1, "kind": "skillDocument", "producer": producer,
                "name": file.path, "byteLength": output.stdout.len(),
                "contentHash": content_hash, "text": text
            }),
            "{}",
            file.path
        );
        if file.path == "SKILL.md" {
            let explicit_text = command()
                .env_remove("HOME")
                .args(["skill", "show", file.path, "--format=text"])
                .output()
                .unwrap();
            assert_eq!(exit_code(&explicit_text), 0, "{explicit_text:?}");
            assert!(explicit_text.stderr.is_empty());
            assert_eq!(explicit_text.stdout, output.stdout);
        }
        assert_eq!(
            fs::read_to_string(path).unwrap(),
            "local document; do not read"
        );
    }
    assert!(saw_non_ascii, "UTF-8 byteLength needs a non-ASCII document");
    metadata.sort_by(|left, right| left["name"].as_str().cmp(&right["name"].as_str()));
    for home in [None, Some(directory.path().join("missing-home"))] {
        let mut invocation = command();
        invocation
            .current_dir(directory.path())
            .args(["skill", "list", "--format=json"]);
        if let Some(home) = home {
            invocation.env("HOME", home);
        } else {
            invocation.env_remove("HOME");
        }
        let output = invocation.output().unwrap();
        assert_eq!(exit_code(&output), 0, "{output:?}");
        assert!(output.stderr.is_empty(), "{output:?}");
        assert_eq!(output.stdout.last(), Some(&b'\n'));
        assert_eq!(
            output.stdout.iter().filter(|byte| **byte == b'\n').count(),
            1
        );
        let list: Value = serde_json::from_slice(&output.stdout).unwrap();
        assert_eq!(
            list,
            json!({
                "schemaVersion": 1, "kind": "skillList", "producer": producer,
                "documents": metadata
            })
        );
    }
}

// 作成時の関門: 不正名・未知名・別の動詞用のオプションを、空の stdout と使い方の誤りで返す。
// 導入の既存の表には論理名の入力がなく、OS パスからの誤取得を捕まえない。
#[test]
fn skill_document_usage_errors_do_not_open_paths_or_write_documents() {
    let directory = TestDirectory::new();
    let outside = directory.write("outside.md", "must not be returned");
    let mut cases: Vec<(Vec<String>, String)> = Vec::new();
    for name in [
        "",
        "/SKILL.md",
        "../SKILL.md",
        "./SKILL.md",
        "references//grammar.md",
        "references/../SKILL.md",
        "references/./grammar.md",
        "references/",
        "references\\grammar.md",
        "C:SKILL.md",
        "C:/SKILL.md",
        outside.to_str().unwrap(),
    ] {
        cases.push((
            vec!["show".into(), name.into()],
            format!("invalid Skill document name `{name}`"),
        ));
    }
    for name in ["skill.md", "SKILL", "outside.md", "missing.md", "install"] {
        cases.push((
            vec!["show".into(), name.into()],
            format!("unknown Skill document `{name}`; use `benitoite skill list`"),
        ));
    }
    for (args, detail) in [
        (vec!["show"], "missing Skill document name"),
        (vec!["list", "SKILL.md"], "unexpected argument `SKILL.md`"),
        (
            vec!["show", "SKILL.md", "LICENSE-MIT"],
            "unexpected argument `LICENSE-MIT`",
        ),
        (vec!["list", "--user"], "unknown option `--user`"),
        (vec!["--project", "list"], "unknown option `--project`"),
        (
            vec!["show", "SKILL.md", "--agent=codex"],
            "unknown option `--agent`",
        ),
        (
            vec!["show", "--agent", "SKILL.md"],
            "unknown agent `SKILL.md`; expected `claude-code`, `codex`, or `opencode`",
        ),
        (
            vec!["show", "--project", "SKILL.md"],
            "unknown option `--project`",
        ),
        (
            vec!["list", "--diagnostics=json"],
            "unknown option `--diagnostics=json`",
        ),
        (
            vec!["install", "--format=text"],
            "unknown option `--format=text`",
        ),
        (
            vec!["uninstall", "SKILL.md"],
            "unexpected argument `SKILL.md`",
        ),
        (
            vec!["list", "--format=xml"],
            "invalid value `xml` for `--format`",
        ),
        (
            vec!["show", "--format=", "SKILL.md"],
            "invalid value `` for `--format`",
        ),
        (
            vec!["list", "--format=JSON"],
            "invalid value `JSON` for `--format`",
        ),
        (
            vec!["list", "--format", "json"],
            "unknown option `--format`",
        ),
        (
            vec!["list", "--format=json", "--format=json"],
            "option `--format` may only be specified once",
        ),
        (
            vec!["show", "--format=text", "SKILL.md", "--format=json"],
            "option `--format` may only be specified once",
        ),
        (
            vec!["uninstall", "--format=json"],
            "unknown option `--format=json`",
        ),
        (
            vec!["export", "--format=json"],
            "unexpected argument `export`",
        ),
    ] {
        cases.push((args.into_iter().map(str::to_owned).collect(), detail.into()));
    }
    let json_cases: Vec<_> = cases
        .iter()
        .filter(|(args, _)| {
            matches!(args.first().map(String::as_str), Some("list" | "show"))
                && !args.iter().any(|arg| arg.starts_with("--format"))
        })
        .map(|(args, detail)| {
            let mut args = args.clone();
            args.insert(1, "--format=json".into());
            (args, detail.clone())
        })
        .collect();
    cases.extend(json_cases);
    for (args, detail) in cases {
        let output = command()
            .current_dir(directory.path())
            .env_remove("HOME")
            .arg("skill")
            .args(&args)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 2, "{args:?}: {output:?}");
        assert!(output.stdout.is_empty(), "{args:?}: {output:?}");
        assert_eq!(
            String::from_utf8(output.stderr).unwrap(),
            format!("error: {detail}\nrun `benitoite --help` for usage\n"),
            "{args:?}"
        );
    }
    assert_eq!(fs::read_to_string(outside).unwrap(), "must not be returned");
    assert_eq!(fs::read_dir(directory.path()).unwrap().count(), 1);
}

// 作成時の関門: 読み取り専用の作業場所と不正な HOME でも取得でき、導入先を作らない。
#[cfg(unix)]
#[test]
fn skill_documents_need_no_writable_directory() {
    use std::os::unix::fs::PermissionsExt;
    let directory = TestDirectory::new();
    let home = directory.write("home-is-a-file", "keep");
    let permissions = fs::metadata(directory.path()).unwrap().permissions();
    fs::set_permissions(directory.path(), fs::Permissions::from_mode(0o555)).unwrap();
    let outputs: Vec<_> = [
        vec!["skill", "list"],
        vec!["skill", "show", "LICENSE-MIT"],
        vec!["skill", "list", "--format=json"],
        vec!["skill", "show", "LICENSE-MIT", "--format=json"],
    ]
    .into_iter()
    .map(|args| {
        command()
            .current_dir(directory.path())
            .env("HOME", &home)
            .args(args)
            .output()
    })
    .collect();
    fs::set_permissions(directory.path(), permissions).unwrap();
    for output in outputs {
        let output = output.unwrap();
        assert_eq!(exit_code(&output), 0, "{output:?}");
        assert!(output.stderr.is_empty(), "{output:?}");
        assert!(!output.stdout.is_empty());
    }
    assert_eq!(fs::read_dir(directory.path()).unwrap().count(), 1);
    assert_eq!(fs::read_to_string(home).unwrap(), "keep");
}

// 作成時の関門: 取得時の出力失敗を成功や不具合へ変えず、終了状態1で返す。
// 閉じた相手へのソケットを標準出力に渡し、出力との競合なしで実際の書き込みを失敗させる。
#[cfg(unix)]
#[test]
fn skill_document_output_failures_exit_one() {
    use std::os::fd::OwnedFd;
    use std::os::unix::net::UnixStream;
    for args in [
        vec!["skill", "list"],
        vec!["skill", "show", "SKILL.md"],
        vec!["skill", "list", "--format=json"],
        vec!["skill", "show", "--format=json", "SKILL.md"],
    ] {
        let (reader, writer) = UnixStream::pair().unwrap();
        drop(reader);
        let output = command()
            .env_remove("HOME")
            .args(&args)
            .stdout(Stdio::from(OwnedFd::from(writer)))
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 1, "{args:?}: {output:?}");
        assert!(output.stdout.is_empty());
        assert!(output.stderr.is_empty(), "{args:?}: {output:?}");
    }
}

// 関門: 道具の本体の外側の panic を、終了状態・段・診断形式まで確かめる。
// run/check の既存の例ではこの境界と JSON への hook 出力の混入を捕まえられない。
// 設計書 07-03 が指定する開発用の panic を使い、CLI を本物のプロセスで起動する。
#[test]
fn tool_panics_are_internal_reports() {
    let directory = TestDirectory::new();
    for (stage, args, json) in [
        ("skill", vec!["skill", "install", "--project"], false),
        ("test", vec!["test", "missing.bnt"], false),
        (
            "test",
            vec!["test", "--allow-effects=", "missing.bnt"],
            false,
        ),
        (
            "test",
            vec![
                "test",
                "--allow-effects=",
                "--diagnostics=json",
                "missing.bnt",
            ],
            true,
        ),
        ("fmt", vec!["fmt", "missing.bnt"], false),
        ("package", vec!["package", "update"], false),
        (
            "package",
            vec!["package", "update", "--diagnostics=json"],
            true,
        ),
        (
            "test",
            vec!["test", "--diagnostics=json", "missing.bnt"],
            true,
        ),
        (
            "fmt",
            vec!["fmt", "--diagnostics=json", "missing.bnt"],
            true,
        ),
    ] {
        let output = command()
            .args(args)
            .current_dir(directory.path())
            .env("HOME", directory.path())
            .env("BENITOITE_DEV_PANIC", "tool")
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 3, "{stage}: {output:?}");
        assert!(output.stdout.is_empty(), "{stage}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        if json {
            assert_eq!(stderr.lines().count(), 1, "{stderr}");
            let report: serde_json::Value = serde_json::from_str(&stderr).unwrap();
            assert_eq!(report["kind"], "internal", "{stderr}");
        } else {
            assert_internal_report(&output.stderr);
            assert!(
                stderr.contains("the panic occurred in the main thread"),
                "{stderr}"
            );
        }
        assert!(
            stderr.contains(&format!("in the {stage} stage")),
            "{stderr}"
        );
        assert!(stderr.contains("BENITOITE_DEV_PANIC=tool"), "{stderr}");
        assert!(!stderr.contains("panicked at"), "{stderr}");
    }
    assert!(!directory.path().join(".claude").exists());
}

fn exit_code(output: &Output) -> i32 {
    output.status.code().unwrap_or(-1)
}

// 関門: 宣言をまたぐ型の増大を、CLI の診断と終了状態まで確かめる。既存の構文の
// 深さのテストでは、別名の展開や型変数の解決による増大を捕まえられない。
// プロセスで確かめるので、スタックの溢れによる abort もテストの失敗になる。
// 本番の上限を下げる差し込み口は作らない（設計書 07-03「テストの設計の原則」）。
#[test]
fn expanded_type_limits() {
    let directory = TestDirectory::new();
    let cases = [
        ("depth", alias_chain(2, 500)),
        ("depth-40", alias_chain(40, 990)),
        ("depth-100", alias_chain(100, 990)),
        ("alias-doubling", doubled_aliases(30)),
        (
            "nodes-one-over",
            format!("{}type Over = List[List[T13]]\n", doubled_aliases(13)),
        ),
        ("alias-chain", alias_chain(10_000, 1)),
        ("forward-chain", forward_alias_chain(10_000)),
        ("parameter-doubling", doubled_parameter_aliases(14)),
        ("function-alias", doubled_function_aliases(14)),
        (
            "signature",
            large_signature("function wide(a: T12, b: T12, c: T12) -> Unit\nend function\n"),
        ),
        (
            "constructor",
            large_signature("data Wide\n Wide(T12, T12, T12)\nend data\n"),
        ),
        (
            "record",
            large_signature("record Wide\n a: T12\n b: T12\n c: T12\nend record\n"),
        ),
        (
            "temporary-function",
            large_signature(
                "function take[T](x: T, y: T12) -> T12\n return y\nend function\nfunction mismatch(x: T12) -> Integer\n return take(x: x, y: x)\nend function\n",
            ),
        ),
        ("inferred-doubling", doubled_bindings(18)),
    ];
    for (name, source) in cases {
        let path = directory.write(&format!("{name}.bnt"), &source);
        let output = command().arg("check").arg(path).output().unwrap();
        assert_eq!(exit_code(&output), 2, "{name}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.contains("E0208"), "{name}: {stderr}");
        assert!(
            stderr.contains("levels in a type") || stderr.contains("nodes in a type"),
            "the type checker must reject this, {name}: {stderr}"
        );
        assert!(!stderr.contains("overflowed its stack"), "{name}: {stderr}");
    }
}

// 関門: 上限ちょうどの型を拒否する退行と、検査後の単一化・最終化・表示・
// コード生成・破棄でのスタックの溢れを捕まえる。拒否のテストだけでは確認できない。
#[test]
fn expanded_types_at_the_limits_are_usable() {
    let directory = TestDirectory::new();
    let mut nodes = doubled_aliases(13); // T13 は 16,383 ノード。
    nodes.push_str("type AtLimit = List[T13]\n");
    // consume の関数型は 16,383 ノードで、そのリストの型は 16,384 ノード。
    nodes = nodes.replace(
        "function main() -> Unit\nend function",
        "function main() -> Unit\n  bind fs <- [consume]\nend function",
    );
    nodes.push_str("function consume(x: T12) -> T12\n  return x\nend function\n");
    // A2 は 999 段であり、その型を引数・戻り値に持つ関数型は 1000 段になる。
    let mut function = alias_chain(2, 499).replace(
        "function main() -> Unit\nend function",
        "function main() -> Unit\n  bind f <- identity\nend function",
    );
    function.push_str("function identity(x: A2) -> A2\n  return x\nend function\n");
    for (name, source) in [
        ("depth", alias_chain(3, 333)),
        ("forward-depth", forward_alias_chain(999)),
        ("nodes", nodes),
        ("function", function.clone()),
        ("inferred", doubled_bindings(12)),
    ] {
        let path = directory.write(&format!("{name}.bnt"), &source);
        for subcommand in ["check", "run"] {
            let output = command().arg(subcommand).arg(&path).output().unwrap();
            assert_eq!(exit_code(&output), 0, "{name} {subcommand}: {output:?}");
            assert!(output.stderr.is_empty(), "{name}: {output:?}");
        }
    }
    // 型の不一致の診断では、境界の深さの型を表示する。
    function.push_str("function mismatch(x: A2) -> Integer\n  return x\nend function\n");
    let path = directory.write("display.bnt", &function);
    let output = command().arg("check").arg(path).output().unwrap();
    assert_eq!(exit_code(&output), 2, "{output:?}");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("E0401"), "{stderr}");
    assert!(!stderr.contains("E0208"), "{stderr}");
}

fn forward_alias_chain(count: usize) -> String {
    let mut source = String::new();
    for i in 0..count {
        source.push_str(&format!("type A{i} = List[A{}]\n", i + 1));
    }
    source.push_str(&format!("type A{count} = Integer\n"));
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_parameter_aliases(count: usize) -> String {
    let mut source = String::from("type Double[T] = Pair[T, T]\ntype T0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!("type T{i} = Double[T{}]\n", i - 1));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_function_aliases(count: usize) -> String {
    let mut source = String::from("type T0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!(
            "type T{i} = function(value: T{}) -> T{}\n",
            i - 1,
            i - 1
        ));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn large_signature(declaration: &str) -> String {
    let mut source = doubled_aliases(12);
    source.push_str(declaration);
    source
}

fn alias_chain(count: usize, wrappers: usize) -> String {
    let mut source = String::from("type A0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!(
            "type A{i} = {}A{}{}\n",
            "List[".repeat(wrappers),
            i - 1,
            "]".repeat(wrappers)
        ));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_aliases(count: usize) -> String {
    let mut source = String::from("type T0 = Integer\n");
    for i in 1..=count {
        source.push_str(&format!("type T{i} = Pair[T{}, T{}]\n", i - 1, i - 1));
    }
    source.push_str("function main() -> Unit\nend function\n");
    source
}

fn doubled_bindings(count: usize) -> String {
    let mut source = String::from("function main() -> Unit\n  bind a0 <- 0\n");
    for i in 1..=count {
        source.push_str(&format!("  bind a{i} <- Pair(a{}, a{})\n", i - 1, i - 1));
    }
    source.push_str("end function\n");
    source
}

fn assert_internal_report(stderr: &[u8]) {
    let text = String::from_utf8_lossy(stderr);
    assert!(text.starts_with("internal error"), "{text}");
    assert!(text.to_ascii_lowercase().contains("internal"), "{text}");
    assert!(
        !text.contains("panicked at"),
        "panic hook output preceded the report: {text}"
    );
}

#[cfg(unix)]
fn broken_pipe_is_a_runtime_error(directory: &TestDirectory) {
    let payload = "x".repeat(80 * 1024);
    for (ending, expected_status) in [("", 1), ("Process.exit(3)", 3)] {
        let script = directory.write(
            "broken-pipe.bnt",
            &format!("import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\n\nfunction main() -> Unit uses Console.Write, Process.Exit\n    Console.write(\"{payload}\")\n    {ending}\nend function\n"),
        );
        let mut child: Child = command()
            .arg("run")
            .arg(&script)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap_or_else(|error| panic!("could not start broken-pipe child: {error}"));
        let Some(reader) = child.stdout.take() else {
            panic!("child stdout was not piped");
        };
        drop(reader);
        let output = child
            .wait_with_output()
            .unwrap_or_else(|error| panic!("could not wait for broken-pipe child: {error}"));
        assert_eq!(exit_code(&output), expected_status, "{ending}: {output:?}");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(stderr.contains("R0201"), "{stderr}");
    }
}

#[cfg(unix)]
fn invalid_utf8_argument_stops_before_main(script: &Path) {
    use std::os::unix::ffi::OsStrExt;

    let invalid = OsStr::from_bytes(b"\xff");
    let output = command()
        .arg("run")
        .arg(script)
        .arg(invalid)
        .output()
        .unwrap_or_else(|error| panic!("could not pass invalid UTF-8 argument: {error}"));
    assert_eq!(exit_code(&output), 1);
    assert!(output.stdout.is_empty());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("R0301"), "{stderr}");
}

struct TestDirectory {
    path: PathBuf,
}

impl TestDirectory {
    fn new() -> TestDirectory {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |duration| duration.as_nanos());
        // macOS の時計はマイクロ秒の精度なので、並行するテストが同じ時刻を得ても名前が重ならないよう番号を足す。
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let serial = NEXT.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!(
            "benitoite-cli-process-{}-{timestamp}-{serial}",
            std::process::id()
        ));
        fs::create_dir(&path).unwrap_or_else(|error| {
            panic!(
                "could not create CLI test directory {}: {error}",
                path.display()
            );
        });
        TestDirectory { path }
    }

    fn path(&self) -> &Path {
        &self.path
    }

    fn write(&self, name: &str, contents: &str) -> PathBuf {
        let path = self.path.join(name);
        fs::write(&path, contents).unwrap_or_else(|error| {
            panic!(
                "could not write CLI test script {}: {error}",
                path.display()
            );
        });
        path
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        match fs::remove_dir_all(&self.path) {
            Ok(()) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(_) => {}
        }
    }
}

// 関門: 管から渡した入口も普通のファイルに限り、E0101・終了状態 2 で拒む。
// import 用の FIFO のテストでは、入口だけ管を許してしまう退行を捕まえられない。
#[cfg(unix)]
#[test]
fn check_rejects_a_script_piped_to_dev_stdin() {
    let dir = TestDirectory::new();
    let script = dir.write("main.bnt", "function main() -> Unit\nend function\n");
    let mut cat = Command::new("cat")
        .arg(&script)
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let pipe = cat.stdout.take().unwrap();
    // 小さな入力は管の容量に収まる。先に cat を終えて、check の拒否による SIGPIPE を避ける。
    assert!(cat.wait().unwrap().success());
    let output = command()
        .args(["check", "/dev/stdin"])
        .stdin(Stdio::from(pipe))
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2);
    let err = String::from_utf8_lossy(&output.stderr);
    assert!(err.contains("E0101") && err.contains("/dev/stdin"), "{err}");
    assert!(err.contains("not a regular file"), "{err}");
    assert!(output.stdout.is_empty());
}

// 関門: 実際の FIFO を import しても、check が読めない理由を報告して終了する。
#[cfg(unix)]
#[test]
fn check_rejects_a_fifo_module_without_blocking() {
    use std::time::{Duration, Instant};
    let dir = TestDirectory::new();
    let fifo = dir.path().join("Pipe.bnt");
    assert!(
        Command::new("mkfifo")
            .arg(&fifo)
            .status()
            .unwrap()
            .success()
    );
    let entry = dir.write(
        "main.bnt",
        "import Pipe\nfunction main() -> Unit\n  ()\nend function\n",
    );
    let mut child = command()
        .arg("check")
        .arg(entry)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let started = Instant::now();
    while child.try_wait().unwrap().is_none() {
        if started.elapsed() >= Duration::from_secs(5) {
            child.kill().unwrap();
            child.wait().unwrap();
            panic!("check blocked while opening a FIFO module");
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    let output = child.wait_with_output().unwrap();
    assert_eq!(exit_code(&output), 2);
    let err = String::from_utf8_lossy(&output.stderr);
    assert!(err.contains("E0101") && err.contains("Pipe.bnt"), "{err}");
    assert!(output.stdout.is_empty());
}

// 関門: 読み込みに失敗したパスが見出しから端末の制御列を実行させない。
#[test]
fn unreadable_path_controls_are_escaped_in_the_header() {
    let directory = TestDirectory::new();
    let output = command()
        .arg("check")
        .arg(directory.path().join("missing\u{1B}[31m.bnt"))
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 2);
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("error[E0101]: cannot read file `"),
        "{stderr}"
    );
    assert!(
        stderr
            .lines()
            .next()
            .unwrap()
            .contains("missing\\u{1B}[31m.bnt"),
        "{stderr}"
    );
    assert!(!stderr.contains('\u{1B}'), "{stderr}");
}

// 作成時の関門: CLI の本物の入力から終了報告までを守る。構造化した結果を直接
// 描画する lib の検査では、受理と実行の接続漏れを捕まえられない。差し込み口は不要。
#[test]
fn die_source_reports_cause_message_and_location_once() {
    let directory = TestDirectory::new();
    for (name, source, cause, message) in [
        (
            "result",
            include_str!("../testdata/eval/todo250-die-result.bnt"),
            "\"bad input\"",
            Some("loading input"),
        ),
        (
            "option",
            include_str!("../testdata/eval/todo250-die-option.bnt"),
            "expected a value, got Option.None",
            None,
        ),
    ] {
        let script = directory.write(&format!("{name}.bnt"), source);
        for json in [false, true] {
            let mut cmd = command();
            cmd.arg("run");
            if json {
                cmd.arg("--diagnostics=json");
            }
            let output = cmd.arg(&script).output().unwrap();
            assert_eq!(exit_code(&output), 1, "{output:?}");
            assert!(output.stdout.is_empty(), "{output:?}");
            let stderr = String::from_utf8(output.stderr).unwrap();
            if json {
                let lines: Vec<serde_json::Value> = stderr
                    .lines()
                    .map(|s| serde_json::from_str(s).unwrap())
                    .collect();
                assert_eq!(lines.len(), 1, "{stderr}");
                let d = &lines[0];
                assert_eq!(d["kind"], "die");
                assert!(d["code"].is_null());
                assert_eq!(d["message"], "explicit failure exit");
                let mut notes = Vec::new();
                if let Some(message) = message {
                    notes.push(format!("message: {message}"));
                }
                notes.push(format!("cause: {cause}"));
                assert_eq!(d["notes"], serde_json::json!(notes));
                assert_eq!(d["primary"]["start"]["line"], 4);
                assert_eq!(d["primary"]["file"], script.display().to_string());
            } else {
                assert_eq!(
                    stderr.matches("error: explicit failure exit").count(),
                    1,
                    "{stderr}"
                );
                assert!(stderr.contains(&format!("cause: {cause}")), "{stderr}");
                assert_eq!(stderr.contains("message: "), message.is_some(), "{stderr}");
                if let Some(message) = message {
                    assert!(stderr.contains(&format!("message: {message}")), "{stderr}");
                }
                assert!(
                    stderr.contains(&format!("{}:4:", script.display())),
                    "{stderr}"
                );
            }
        }
    }
}

// 関門: 本物の die の後に、内側からの解放と最後の出力の転送の失敗を報告する。
// 子プロセスだけのファイルサイズ制限と閉じたソケットを使い、本番に差し込み口を増やさない。
// 構造化した RunEnd の描画検査だけでは、停止・解放・転送の接続の欠落を捕まえない。
#[cfg(unix)]
#[test]
fn die_reports_precede_real_release_and_flush_failures() {
    use std::os::fd::OwnedFd;
    use std::os::unix::net::UnixStream;
    let directory = TestDirectory::new();
    let script = directory.write(
        "die-cleanup.bnt",
        r#"import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Console
@test
function dies() -> Unit uses File.Write, State, Console.Write, Process.Exit
 Console.write("captured before die")
 Console.writeError("captured stderr before die\n")
 with first = try File.openWriter(path: "first", mode: File.WriteMode.Replace) or die,
      second = try File.openWriter(path: "second", mode: File.WriteMode.Replace) or die do
  bind _ <- try File.write(writer: first, text: "first buffered") or die
  bind _ <- try File.write(writer: second, text: "second buffered") or die
  bind missing: Option[Unit] <- Option.None
  try missing or die("during work")
 end with
end function
@test
function after() -> Unit uses Console.Write
 Console.write("after succeeded")
end function
function main() -> Unit uses File.Write, State, Console.Write, Process.Exit
 dies()
end function
"#,
    );
    for mode in ["direct", "request"] {
        for json in [false, true] {
            for tool in ["run", "test"] {
                let mut cmd = Command::new("/bin/sh");
                // 制限の設定に失敗したまま処理系を起動しない。SIGXFSZ は IO の失敗として返させる。
                cmd.args([
                    "-c",
                    "ulimit -f 0 || exit 125; trap '' XFSZ; exec \"$@\"",
                    "b12",
                ])
                .arg(env!("CARGO_BIN_EXE_benitoite"))
                .arg(tool)
                .current_dir(directory.path())
                .env_remove("BENITOITE_DEV_PANIC")
                .env("BENITOITE_DEV_IO_MODE", mode)
                .env("NO_COLOR", "1");
                if json {
                    cmd.arg("--diagnostics=json");
                }
                cmd.arg(&script);
                if tool == "run" {
                    let (writer, reader) = UnixStream::pair().unwrap();
                    drop(reader);
                    cmd.stdout(Stdio::from(OwnedFd::from(writer)));
                }
                let output = cmd.output().unwrap();
                assert_eq!(exit_code(&output), 1, "{mode}/{json}/{tool}: {output:?}");
                // 二つの書き込みは with の解放までバッファに残っていた。
                assert_eq!(fs::read(directory.path().join("first")).unwrap(), b"");
                assert_eq!(fs::read(directory.path().join("second")).unwrap(), b"");
                let stdout = String::from_utf8(output.stdout).unwrap();
                let stderr = String::from_utf8(output.stderr).unwrap();
                if tool == "run" {
                    assert!(stdout.is_empty());
                    assert!(
                        stderr.starts_with("captured stderr before die\n"),
                        "{stderr}"
                    );
                    let reports = stderr.strip_prefix("captured stderr before die\n").unwrap();
                    if json {
                        let lines: Vec<serde_json::Value> = reports
                            .lines()
                            .map(|line| serde_json::from_str(line).unwrap())
                            .collect();
                        assert_eq!(lines.len(), 4, "{reports}");
                        assert_eq!(lines[0]["kind"], "die");
                        assert_eq!(
                            lines[0]["notes"],
                            serde_json::json!([
                                "message: during work",
                                "cause: expected a value, got Option.None"
                            ])
                        );
                        assert_eq!(lines[0]["primary"]["start"]["line"], 13);
                        for (line, opened_line) in [(&lines[1], 9), (&lines[2], 8)] {
                            assert_eq!(line["kind"], "release");
                            assert_eq!(line["code"], "R0401");
                            assert!(
                                line["message"]
                                    .as_str()
                                    .unwrap()
                                    .contains(&format!("{}:{opened_line}:", script.display())),
                                "{line}"
                            );
                        }
                        assert_eq!(lines[3]["kind"], "runtime");
                        assert_eq!(lines[3]["code"], "R0201");
                    } else {
                        assert_eq!(
                            reports.matches("error: explicit failure exit").count(),
                            1,
                            "{reports}"
                        );
                        assert_eq!(reports.matches("error[R0401]").count(), 2, "{reports}");
                        assert!(
                            reports
                                .find("cause: expected a value, got Option.None")
                                .unwrap()
                                < reports.find("R0401").unwrap()
                        );
                        assert!(reports.rfind("R0401").unwrap() < reports.find("R0201").unwrap());
                        let second = reports.find(&format!("{}:9:", script.display())).unwrap();
                        let first = reports.find(&format!("{}:8:", script.display())).unwrap();
                        assert!(second < first, "{reports}");
                    }
                } else {
                    assert!(stderr.is_empty(), "{stderr}");
                    if json {
                        let lines: Vec<serde_json::Value> = stdout
                            .lines()
                            .map(|line| serde_json::from_str(line).unwrap())
                            .collect();
                        assert_eq!(lines.len(), 3, "{stdout}");
                        let failed = &lines[0];
                        assert_eq!(failed["failure"]["reason"], "exit");
                        assert_eq!(
                            failed["failure"]["message"],
                            "called `Process.exit` with status 1"
                        );
                        assert_eq!(failed["failure"]["exitCode"], 1);
                        assert_eq!(failed["failure"]["die"]["kind"], "die");
                        assert_eq!(
                            failed["failure"]["die"]["notes"],
                            serde_json::json!([
                                "message: during work",
                                "cause: expected a value, got Option.None"
                            ])
                        );
                        let notes = failed["failure"]["notes"].as_array().unwrap();
                        assert_eq!(notes.len(), 2);
                        assert!(
                            notes[0]
                                .as_str()
                                .unwrap()
                                .contains(&format!("{}:9:", script.display())),
                            "{notes:?}"
                        );
                        assert!(
                            notes[1]
                                .as_str()
                                .unwrap()
                                .contains(&format!("{}:8:", script.display())),
                            "{notes:?}"
                        );
                        assert_eq!(failed["stdout"], "captured before die");
                        assert_eq!(failed["stderr"], "captured stderr before die\n");
                        assert_eq!(lines[1]["function"], "after");
                        assert_eq!(lines[1]["outcome"], "passed");
                        assert_eq!(lines[1]["stdout"], "after succeeded");
                        assert_eq!(lines[2]["kind"], "testSummary");
                        assert_eq!(lines[2]["passed"], 1);
                        assert_eq!(lines[2]["failed"], 1);
                        assert_eq!(lines[2]["interrupted"], false);
                    } else {
                        assert_eq!(
                            stdout.matches("error: explicit failure exit").count(),
                            1,
                            "{stdout}"
                        );
                        assert!(!stdout.contains("called `Process.exit`"), "{stdout}");
                        assert_eq!(stdout.matches("error[R0401]").count(), 2, "{stdout}");
                        assert!(
                            stdout.find(&format!("{}:9:", script.display())).unwrap()
                                < stdout.find(&format!("{}:8:", script.display())).unwrap()
                        );
                        assert!(
                            stdout
                                .find("cause: expected a value, got Option.None")
                                .unwrap()
                                < stdout.find("R0401").unwrap()
                        );
                        assert!(
                            stdout.rfind("R0401").unwrap()
                                < stdout.find("---- captured stdout ----").unwrap()
                        );
                        assert!(
                            stdout.contains("---- captured stdout ----\ncaptured before die\n"),
                            "{stdout}"
                        );
                        assert!(
                            stdout.contains(
                                "---- captured stderr ----\ncaptured stderr before die\n"
                            ),
                            "{stdout}"
                        );
                        assert!(stdout.contains("after ... ok"), "{stdout}");
                        assert!(
                            stdout.contains("test result: FAILED. 1 passed; 1 failed"),
                            "{stdout}"
                        );
                    }
                }
            }
        }
    }
}

#[test]
fn test_check_report_catches_tool_panics_as_a_single_report() {
    let directory = TestDirectory::new();
    let output = command()
        .args(["test", "--check", "--report=json", "missing.bnt"])
        .current_dir(directory.path())
        .env("BENITOITE_DEV_PANIC", "tool")
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 3, "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
    assert_eq!(output.stdout.iter().filter(|b| **b == b'\n').count(), 1);
    let report: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(report["kind"], "testCheckReport");
    assert_eq!(report["status"], "internalError");
    assert_eq!(report["complete"], false);
    assert_eq!(report["targetsComplete"], false);
    assert_eq!(report["executed"], false);
    assert_eq!(
        report["requestedTargets"],
        serde_json::json!([{"requestIndex":0,"path":"missing.bnt"}])
    );
    assert_eq!(report["targets"], serde_json::json!([]));
    assert_eq!(report["aggregateEffects"], serde_json::Value::Null);
    let diagnostic = &report["diagnostics"][0];
    assert_eq!(diagnostic["kind"], "internal");
    assert!(diagnostic.to_string().contains("BENITOITE_DEV_PANIC=tool"));
    assert_eq!(
        report["diagnosticTargets"],
        serde_json::json!([{"diagnosticIndex":0,"targetId":null}])
    );
}

// 作成時の関門: プロセスの引数解釈・埋め込みbundle・報告の接続を守る。
// test_commandの直接呼び出しだけでは実CLIの配線漏れを捕まえられない。
#[test]
fn test_doc_uses_version_two_and_keeps_check_nonexecuting() {
    let directory = TestDirectory::new();
    let fence = "\x60\x60\x60";
    let source = format!(
        "//! {fence}benitoite\n//! import Benitoite.Unofficial.IO.Console\n//! function main() -> Unit uses Console.Write\n//!   Console.writeLine(\"doc output\")\n//! end function\n//! {fence}\n//! {fence}output\n//! doc output\n//! {fence}\n"
    );
    let script = directory.write("Docs.bnt", &source);
    let checked = command()
        .args(["test", "--doc", "--check", "--report=json"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&checked), 0, "{checked:?}");
    assert!(checked.stderr.is_empty());
    let report: serde_json::Value = serde_json::from_slice(&checked.stdout).unwrap();
    assert_eq!(report["schemaVersion"], 2);
    assert_eq!(report["executed"], false);
    assert_eq!(report["targets"][0]["docExamples"][0]["mode"], "run");
    assert_eq!(
        report["intervalAnalysis"],
        report["targets"][0]["intervalAnalysis"]
    );
    assert_eq!(report["intervalAnalysis"]["coverage"], "some");
    assert_eq!(report["intervalAnalysis"]["inputDefinitions"], 1);
    assert_eq!(report["intervalAnalysis"]["unsupportedBodies"], 1);
    let executed = command()
        .args([
            "test",
            "--doc",
            "--diagnostics=json",
            "--allow-effects=Console.Write",
        ])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&executed), 0, "{executed:?}");
    assert!(executed.stderr.is_empty());
    let lines = String::from_utf8(executed.stdout)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str::<serde_json::Value>(line).unwrap())
        .collect::<Vec<_>>();
    assert_eq!(lines.len(), 3);
    assert_eq!(lines[0]["kind"], "docExample");
    assert_eq!(lines[0]["stdout"], "doc output\n");
    assert_eq!(lines[1]["kind"], "docSummary");
    assert_eq!(lines[2]["kind"], "testSummary");
    let rejected = command()
        .args(["fmt", "--doc"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&rejected), 2);
    assert!(String::from_utf8_lossy(&rejected.stderr).contains("not accepted by"));
}

// 関門: 実CLIのmain報告でschemaと正規名を保ち、Logの許可だけで宣言上限を通す。
#[test]
fn log_main_report_and_effect_limits_keep_schema_one() {
    let directory = TestDirectory::new();
    let script = directory.write(
        "log.bnt",
        "function main() -> Unit uses Log\n ()\nend function\n",
    );
    let output = command()
        .args(["check", "--report=json"])
        .arg(&script)
        .output()
        .unwrap();
    assert_eq!(exit_code(&output), 0, "{output:?}");
    assert!(output.stderr.is_empty(), "{output:?}");
    let report: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(report["schemaVersion"], 1);
    assert_eq!(report["aggregateEffects"]["basis"], "declaredUpperBound");
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        serde_json::json!(["Log"])
    );
    for (limit, expected) in [("Log", 0), ("", 2)] {
        let output = command()
            .args(["run", &format!("--allow-effects={limit}")])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), expected, "{output:?}");
        assert!(output.stdout.is_empty(), "{output:?}");
        if expected == 2 {
            assert!(String::from_utf8_lossy(&output.stderr).contains("E0512"));
        } else {
            assert!(output.stderr.is_empty(), "{output:?}");
        }
    }
}

// 関門: 実CLIからLogだけの許可で既定stderrへ出し、本文のstdoutと終了状態を保つ。
#[test]
fn log_default_output_runs_through_the_real_cli_in_both_modes() {
    let directory = TestDirectory::new();
    let file = directory.write("log-output.bnt", "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Log, Console.Write\n Log.info(message: \"done\", attributes: [Log.attribute(key: \"n\", value: 3)], location: SourceLocation.Location(file: \"app\", line: 1, column: 2))\n Console.writeLine(\"result\")\nend function\n");
    for mode in ["direct", "request"] {
        let output = command()
            .env("BENITOITE_DEV_IO_MODE", mode)
            .args(["run", "--allow-effects=Log,Console.Write"])
            .arg(&file)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 0, "{output:?}");
        assert_eq!(output.stdout, b"result\n");
        assert_eq!(
            output.stderr,
            b"level=INFO source=\"app:1:2\" message=\"done\" attr.\"n\"=3\n"
        );
    }
}

// 関門: program を捨てる main/test の両経路と deny-warnings 後も、追加解析の
// 範囲と件数が残ることを守る。診断の位置・注記は declarations と golden が守る。
// 本物の入力と CLI を使い、内部の予算の検査を重ねない。
#[test]
fn interval_reports_keep_coverage_and_counts_independent_of_acceptance() {
    let directory = TestDirectory::new();
    let suffix =
        "\nfunction main() -> Unit end function\n@test\nfunction checks() -> Unit end function\n";
    let mut bounded = String::from("function risky(x: Integer) -> Integer\n bind z <- 0\n");
    for i in 0..460 {
        bounded.push_str(&format!(" bind a{i} <- x\n"));
    }
    bounded.push_str(" return 1 div z\nend function\n");
    // 大きい一式の番号付け停止と、複数本体による全体上限を区別する。
    let mut expression = String::from("1");
    for _ in 0..15 {
        expression = format!("({expression} + {expression})");
    }
    let unidentified =
        format!("function risky() -> Integer\n bind _ <- ()\n return {expression}\nend function\n");
    let whole = (0..15)
        .map(|index| bounded.replace("risky(", &format!("risky{index}(")))
        .collect::<String>();
    let cases = [
        (
            "all",
            "function risky(x: Integer) -> Integer\n return if x = 0 then 10 div x else 1 end if\nend function\n",
            "all",
            0,
            0,
            0,
            0,
            true,
        ),
        (
            "unsupported",
            "function risky(x: Byte) -> Boolean return x < x end function\n",
            "some",
            1,
            0,
            0,
            0,
            false,
        ),
        ("budget", bounded.as_str(), "some", 0, 1, 0, 0, false),
        (
            "unidentified",
            unidentified.as_str(),
            "some",
            0,
            0,
            0,
            1,
            false,
        ),
        ("whole", whole.as_str(), "some", 0, 9, 8, 0, false),
        (
            "syntax",
            "function broken( -> Unit\nend function\n",
            "none",
            0,
            0,
            0,
            0,
            false,
        ),
    ];
    for (name, body, coverage, unsupported, exceeded, skipped, unnumbered, warns) in cases {
        let script = directory.write(&format!("{name}.bnt"), &format!("{body}{suffix}"));
        for test in [false, true] {
            let mut ordinary = None;
            for denied in [false, true] {
                let mut invocation = command();
                invocation.args(if test {
                    vec!["test", "--check", "--report=json"]
                } else {
                    vec!["check", "--report=json"]
                });
                if denied {
                    invocation.arg("--deny-warnings");
                }
                let output = invocation.arg(&script).output().unwrap();
                let success = name != "syntax" && !(denied && warns);
                assert_eq!(
                    exit_code(&output),
                    if success { 0 } else { 2 },
                    "{name}: {output:?}"
                );
                assert!(output.stderr.is_empty(), "{name}: {output:?}");
                let report: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
                assert_eq!(report["schemaVersion"], 1);
                assert_eq!(report["complete"], success);
                assert_eq!(report["executed"], false);
                let interval = &report["intervalAnalysis"];
                assert_eq!(*interval, report["targets"][0]["intervalAnalysis"]);
                assert_eq!(interval["basis"], "localIntervals");
                assert_eq!(interval["coverage"], coverage, "{name}: {report}");
                assert_eq!(
                    interval["unsupportedBodies"], unsupported,
                    "{name}: {report}"
                );
                assert_eq!(interval["bodyBudgetExceeded"], exceeded, "{name}: {report}");
                assert_eq!(interval["wholeBudgetSkipped"], skipped);
                assert_eq!(interval["unidentifiedBodies"], unnumbered);
                if denied {
                    assert_eq!(ordinary.as_ref(), Some(interval));
                } else {
                    ordinary = Some(interval.clone());
                }
            }
        }
    }
}

// 関門: 七種の診断の直列化は golden が守り、ここでは実 CLI の通常/strict の
// 終了状態と、run が警告による拒否の前にスクリプトを実行しないことを守る。
// 同じ入力を共有し、数学上の境界・元位置の表を重ねない。
#[test]
fn width_interval_warnings_preserve_cli_acceptance_and_prevent_denied_execution() {
    use serde_json::Value;
    let directory = TestDirectory::new();
    let script = directory.write(
        "width-intervals.bnt",
        include_str!("../testdata/warnings/local-width-intervals.bnt"),
    );
    for mode in ["check", "run"] {
        for format in ["json", "text"] {
            let mut ordinary = None;
            for denied in [false, true] {
                let mut invocation = command();
                invocation.arg(mode).arg(format!("--diagnostics={format}"));
                if mode == "run" {
                    invocation.arg("--allow-effects=Console.Write");
                }
                if denied {
                    invocation.arg("--deny-warnings");
                }
                let output = invocation.arg(&script).output().unwrap();
                assert_eq!(
                    exit_code(&output),
                    if denied { 2 } else { 0 },
                    "{mode}/{format}: {output:?}"
                );
                assert_eq!(
                    output.stdout,
                    if mode == "run" && !denied {
                        b"ran\n".as_slice()
                    } else {
                        b"".as_slice()
                    }
                );
                let stderr = String::from_utf8(output.stderr).unwrap();
                if format == "json" {
                    let diagnostics: Vec<Value> = stderr
                        .lines()
                        .map(|s| serde_json::from_str(s).unwrap())
                        .collect();
                    assert_eq!(diagnostics.len(), 8, "{stderr}");
                    assert_eq!(
                        diagnostics.iter().filter(|d| d["code"] == "W0402").count(),
                        7
                    );
                    assert_eq!(
                        diagnostics.iter().filter(|d| d["code"] == "W0401").count(),
                        1
                    );
                    for diagnostic in &diagnostics {
                        assert_eq!(
                            diagnostic["severity"],
                            if denied { "error" } else { "warning" }
                        );
                    }
                    if denied {
                        let mut expected: Vec<Value> = ordinary.take().unwrap();
                        for diagnostic in &mut expected {
                            diagnostic["severity"] = "error".into();
                            diagnostic["notes"]
                                .as_array_mut()
                                .unwrap()
                                .push("treated as an error because of `--deny-warnings`".into());
                        }
                        assert_eq!(diagnostics, expected);
                    } else {
                        ordinary = Some(diagnostics);
                    }
                } else {
                    assert_eq!(stderr.matches("W0402").count(), 7, "{stderr}");
                    assert_eq!(stderr.matches("W0401").count(), 1, "{stderr}");
                    assert_eq!(
                        stderr
                            .matches("treated as an error because of `--deny-warnings`")
                            .count(),
                        if denied { 8 } else { 0 }
                    );
                }
            }
        }
    }
}

// 関門: 内部候補の検査では届かない、実 CLI の W0404 の発行・位置・由来・
// text/JSON・strict を守る。認定漏れや過剰な発行、補助位置の欠落で失敗する。
// 既存の算術診断テストと準備を重ねず、固定域の入力を同じ表で比較する。
#[test]
fn shift_domain_warnings_reach_cli_renderers_only_for_disjoint_arguments() {
    use serde_json::Value;
    let directory = TestDirectory::new();
    let chain = (0..10)
        .map(|i| {
            if i == 0 {
                "  bind n0 <- 64\n".to_owned()
            } else {
                format!("  bind n{i} <- n{}\n", i - 1)
            }
        })
        .collect::<String>();
    let chain_origins = (2..10)
        .rev()
        .map(|i| format!("bind n{i} <- n{}", i - 1))
        .collect::<Vec<_>>();
    // (本体、推定域、正常域、一次位置、補助位置)。None は W0404 なし。
    for (name, imports, result, body, expected) in [
        ("primitive", "", "Integer", "  return Integer.shiftLeft(a: 1, n: 64)\n".into(), Some(("Integer.shiftLeft", "[64,64]", "[0,63]", "64", vec![]))),
        ("wrapper", "import Benitoite.Integer64 as I\n", "Integer", "  bind amount <- if flag then 64 else 65 end if\n  return I.shiftLeft(n: amount, a: 1)\n".into(), Some(("Integer64.shiftLeft", "[64,65]", "[0,63]", "amount", vec!["bind amount <- if flag then 64 else 65 end if".into()]))),
        ("byte", "import Benitoite.Byte\n", "Byte", "  return Byte.shiftLeft(a: 1u8, n: 8)\n".into(), Some(("Byte.shiftLeft", "[8,8]", "[0,7]", "8", vec![]))),
        ("negative", "", "Integer", "  bind amount <- if flag then -2 else -1 end if\n  return Integer.shiftRight(a: 1, n: amount)\n".into(), Some(("Integer.shiftRight", "[-2,-1]", "[0,63]", "amount", vec!["bind amount <- if flag then -2 else -1 end if".into()]))),
        ("comparison", "", "Integer", "  if x >= 64 then\n    return Integer.shiftLeft(a: 1, n: x)\n  end if\n  return 1\n".into(), Some(("Integer.shiftLeft", "[64,9223372036854775807]", "[0,63]", "x", vec!["x >= 64".into()]))),
        ("bounded_origins", "", "Integer", format!("{chain}  return Integer.shiftLeft(a: 1, n: n9)\n"), Some(("Integer.shiftLeft", "[64,64]", "[0,63]", "n9", chain_origins))),
        ("independent", "", "Integer", "  return Integer.absolute(Integer.absolute(Integer.shiftLeft(a: 1, n: 64)))\n".into(), Some(("Integer.shiftLeft", "[64,64]", "[0,63]", "64", vec![]))),
        ("inside", "import Benitoite.Integer64 as I\nimport Benitoite.Byte\n", "Unit", "  bind _ <- Integer.shiftLeft(a: 1, n: 63)\n  bind _ <- I.shiftLeft(a: 1, n: 0)\n  bind _ <- Byte.shiftLeft(a: 1u8, n: 7)\n".into(), None),
        ("intersect", "import Benitoite.Integer64 as I\nimport Benitoite.Byte\n", "Unit", "  bind amount <- if flag then 63 else 64 end if\n  bind _ <- Integer.shiftLeft(a: 1, n: amount)\n  bind _ <- I.shiftLeft(a: 1, n: amount)\n  bind small <- if flag then 7 else 8 end if\n  bind _ <- Byte.shiftLeft(a: 1u8, n: small)\n".into(), None),
        ("top", "import Benitoite.Integer64 as I\nimport Benitoite.Byte\n", "Unit", "  bind _ <- Integer.shiftLeft(a: 1, n: x)\n  bind _ <- I.shiftLeft(a: 1, n: x)\n  bind _ <- Byte.shiftLeft(a: 1u8, n: x)\n".into(), None),
        ("unreachable", "", "Unit", "  bind amount <- 64\n  if amount < 64 then\n    bind _ <- Integer.shiftLeft(a: 1, n: amount)\n  end if\n".into(), None),
        ("returned_child", "", "Unit", "  bind _ <- Integer.shiftLeft(n: 64, a: block return () end block)\n".into(), None),
    ] {
        let source = format!("{imports}function sample(x: Integer, flag: Boolean) -> {result}\n{body}end function\nfunction main() -> Unit\nend function\n");
        let script = directory.write(&format!("{name}.bnt"), &source);
        for format in ["json", "text"] {
            for denied in [false, true] {
                let mut invocation = command();
                invocation.args(["check", &format!("--diagnostics={format}")]);
                if denied {
                    invocation.arg("--deny-warnings");
                }
                let output = invocation.arg(&script).output().unwrap();
                assert_eq!(exit_code(&output), if denied && expected.is_some() { 2 } else { 0 }, "{name}/{format}: {output:?}");
                assert!(output.stdout.is_empty(), "{output:?}");
                let stderr = String::from_utf8(output.stderr).unwrap();
                let Some((function, inferred, allowed, primary, origins)) = &expected else {
                    assert!(stderr.is_empty(), "{name}: {stderr}");
                    continue;
                };
                let message = format!("argument `n` to `{function}` is always out of range");
                let notes = [format!("the inferred interval is {inferred}"), format!("the allowed range is {allowed}"), "this local analysis applies only if execution reaches this call and all arguments are evaluated successfully".into()];
                if format == "json" {
                    let diagnostics = stderr.lines().map(|s| serde_json::from_str::<Value>(s).unwrap()).collect::<Vec<_>>();
                    assert_eq!(diagnostics.len(), 1, "{name}: {stderr}");
                    let diagnostic = &diagnostics[0];
                    assert_eq!(diagnostic["code"], "W0404");
                    assert_eq!(diagnostic["kind"], "check");
                    assert_eq!(diagnostic["severity"], if denied { "error" } else { "warning" });
                    assert_eq!(diagnostic["message"], message);
                    assert_eq!(diagnostic["primary"]["label"], "always out of range");
                    let primary_start = diagnostic["primary"]["start"]["offset"].as_u64().unwrap() as usize;
                    let primary_end = diagnostic["primary"]["end"]["offset"].as_u64().unwrap() as usize;
                    assert_eq!(&source[primary_start..primary_end], *primary);
                    assert_eq!(primary_start, source.rfind(&format!("n: {primary}")).unwrap() + 3);
                    let secondary = diagnostic["secondary"].as_array().unwrap();
                    assert_eq!(secondary.len(), origins.len());
                    for (position, origin) in secondary.iter().zip(origins) {
                        let start = position["start"]["offset"].as_u64().unwrap() as usize;
                        let end = position["end"]["offset"].as_u64().unwrap() as usize;
                        assert_eq!(&source[start..end], origin);
                        assert_eq!(position["label"], "this binding or comparison contributes to the inferred interval");
                    }
                    let mut expected_notes = notes.to_vec();
                    if denied {
                        expected_notes.push("treated as an error because of `--deny-warnings`".into());
                    }
                    assert_eq!(diagnostic["notes"], serde_json::json!(expected_notes));
                    assert_eq!(diagnostic["helps"], serde_json::json!([]));
                } else {
                    assert_eq!(stderr.matches("W0404").count(), 1, "{stderr}");
                    assert!(stderr.contains(&message), "{stderr}");
                    assert_eq!(stderr.matches("this binding or comparison contributes to the inferred interval").count(), origins.len());
                    for note in notes {
                        assert!(stderr.contains(&note), "{stderr}");
                    }
                }
            }
        }
    }
}

// 関門: 子の正常値が Bottom のとき、引数の並びにかかわらず W0404 を重ねない。
// 内部候補の検査と異なり、旧定数警告と新診断の統合後の出力を確かめる。
#[test]
fn shift_domain_warning_does_not_duplicate_a_child_overflow() {
    use serde_json::Value;
    let directory = TestDirectory::new();
    for arguments in [
        "a: 127s8 + 1s8, n: 8",
        "n: 8, a: 127s8 + 1s8",
        "a: 1s8, n: 9223372036854775807 + 1",
    ] {
        let source = format!(
            "import Benitoite.Integer8\nfunction sample() -> Integer8\n  return Integer8.shiftLeft({arguments})\nend function\nfunction main() -> Unit\nend function\n"
        );
        let script = directory.write("child-bottom.bnt", &source);
        let output = command()
            .args(["check", "--diagnostics=json"])
            .arg(&script)
            .output()
            .unwrap();
        assert_eq!(exit_code(&output), 0, "{output:?}");
        let diagnostics = String::from_utf8(output.stderr)
            .unwrap()
            .lines()
            .map(|s| serde_json::from_str::<Value>(s).unwrap())
            .collect::<Vec<_>>();
        assert_eq!(diagnostics.len(), 1, "{arguments}: {diagnostics:?}");
        assert_eq!(diagnostics[0]["code"], "W0402");
    }
}

// 関門: 操作の既定実装だけを固定域と見なす退行を、実際のハンドラと CLI で防ぐ。
// 候補や純粋なシフトのテストでは、Process.exit を差し替えた実行まで届かない。
#[test]
fn handled_process_exit_outside_default_range_has_no_domain_warning() {
    let directory = TestDirectory::new();
    let script = directory.write("handled-exit.bnt", "import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\nfunction finish() -> Integer uses Process.Exit\n  return Process.exit(300)\nend function\nfunction main() -> Unit uses Console.Write\n  bind code <- handle finish() with\n    case Process.exit(c) -> c\n  end handle\n  Console.writeLine(\"handled ${Integer.toString(code)}\")\nend function\n");
    for mode in ["check", "run"] {
        for format in ["text", "json"] {
            let mut invocation = command();
            invocation.args([mode, &format!("--diagnostics={format}"), "--deny-warnings"]);
            if mode == "run" {
                invocation.arg("--allow-effects=Console.Write");
            }
            let output = invocation.arg(&script).output().unwrap();
            assert_eq!(exit_code(&output), 0, "{mode}/{format}: {output:?}");
            assert!(output.stderr.is_empty(), "{output:?}");
            assert_eq!(
                output.stdout,
                if mode == "run" {
                    b"handled 300\n".as_slice()
                } else {
                    b"".as_slice()
                }
            );
        }
    }
}
