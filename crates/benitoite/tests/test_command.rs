//! `benitoite test` の CLI のテスト（設計書 06-01「`test` のコマンドライン（初回リリース版）」、06-04「テストの実行」
//! 「結果の報告」、02-10「実行時エラーと資源の不足の報告」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::ffi::OsString;
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use benitoite::cli::{self, CliEnv, Command, DevPanic, ToolCommand};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::InterruptSource;
use benitoite::runtime::run::{NoInterrupt, OutputTarget, StdinSource};
use benitoite::vm::ExecMode;

struct Directory(PathBuf);

impl Directory {
    fn new(tag: &str) -> Directory {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "benitoite-test-command-{tag}-{}-{stamp}",
            std::process::id()
        ));
        fs::create_dir(&path).unwrap();
        Directory(path.canonicalize().unwrap())
    }

    fn write(&self, name: &str, contents: &str) -> String {
        let path = self.0.join(name);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(&path, contents).unwrap();
        path.display().to_string()
    }

    fn path(&self, name: &str) -> String {
        self.0.join(name).display().to_string()
    }
}

impl Drop for Directory {
    fn drop(&mut self) {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let locked = self.0.join("locked");
            let _result = fs::set_permissions(&locked, fs::Permissions::from_mode(0o755));
        }
        let _result = fs::remove_dir_all(&self.0);
    }
}

#[derive(Debug)]
struct AlwaysInterrupted;

impl InterruptSource for AlwaysInterrupted {
    fn requested(&self) -> bool {
        true
    }
}

struct Outcome {
    exit: u8,
    stdout: String,
    stderr: String,
}

// `cli::execute` を捕らえる出力先で呼ぶ。出力の中の作業ディレクトリのパスは `<dir>` に置き換える。
fn run_with(
    dir: &Directory,
    args: &[&str],
    interrupt: Box<dyn InterruptSource>,
    mode: ExecMode,
) -> Outcome {
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let env = CliEnv {
        stdout: OutputTarget::Capture(Arc::clone(&stdout)),
        stderr: OutputTarget::Capture(Arc::clone(&stderr)),
        stdin: StdinSource::Empty,
        working_directory: dir.0.clone(),
        color: false,
        mode,
        interrupt: Some(interrupt),
        parts: None,
        heap: HeapConfig::default(),
        dev_panic: DevPanic::None,
        dev_alloc_stats: false,
    };
    let command = Command::Tool {
        tool: ToolCommand::Test,
        args: args.iter().map(OsString::from).collect(),
    };
    let exit = cli::execute(command, env);
    let prefix = format!("{}/", dir.0.display());
    let text = |bytes: &Arc<Mutex<Vec<u8>>>| {
        String::from_utf8(bytes.lock().unwrap().clone())
            .unwrap()
            .replace(&prefix, "<dir>/")
    };
    Outcome {
        exit,
        stdout: text(&stdout),
        stderr: text(&stderr),
    }
}

fn run(dir: &Directory, args: &[&str]) -> Outcome {
    run_with(dir, args, Box::new(NoInterrupt), ExecMode::Direct)
}

const MIXED: &str = r#"import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process

@test("adds \"two\" numbers")
function adds() -> Unit uses Assert.Check
  Assert.equal(actual: 1 + 2, expected: 3)
end function

@test
function sumOfEmpty() -> Unit uses Assert.Check, Console.Write
  Console.writeLine("out line")
  Console.writeErrorLine("err line")
  Assert.equal(actual: 3, expected: 4)
end function

@test
function truth() -> Unit uses Assert.Check
  Assert.isTrue(condition: false, message: "should hold")
end function

@test
function returnsError() -> Result[Unit, String]
  return Result.Error("bad input")
end function

@test
function crashes() -> Unit
  bind n <- 0
  bind _ <- 1 div n
  return ()
end function

@test
function exits() -> Unit uses Process.Exit
  return Process.exit(4)
end function

@test
function passesQuietly() -> Unit uses Console.Write
  Console.writeLine("not shown")
end function
"#;

// 関門: 成功と失敗の混じったファイルの文章の形の全体（設計書 06-04「結果の報告」）。
// 説明の有無、理由ごとの詳細、捕らえた出力の節、成功したテストの出力を示さないこと、空の行の置き方を一度に確かめる。
#[test]
fn mixed_results_are_reported_in_the_text_form() {
    let dir = Directory::new("mixed");
    let file = dir.write("sum.bnt", MIXED);
    let out = run(&dir, &[&file]);
    assert_eq!(out.exit, 1, "{}", out.stderr);
    assert_eq!(out.stderr, "");
    let expected = r#"test <dir>/sum.bnt: "adds \"two\" numbers" ... ok
test <dir>/sum.bnt: sumOfEmpty ... FAILED
test <dir>/sum.bnt: truth ... FAILED
test <dir>/sum.bnt: returnsError ... FAILED
test <dir>/sum.bnt: crashes ... FAILED
test <dir>/sum.bnt: exits ... FAILED
test <dir>/sum.bnt: passesQuietly ... ok

failures:

---- <dir>/sum.bnt: sumOfEmpty ----
assertion failed: Assert.equal
  left:  3
  right: 4
  --> <dir>/sum.bnt:13:3
   = note: call trace (innermost first):
             sumOfEmpty
   = note: functions left by tail calls are not shown
---- captured stdout ----
out line
---- captured stderr ----
err line

---- <dir>/sum.bnt: truth ----
assertion failed: Assert.isTrue
  message: should hold
  --> <dir>/sum.bnt:18:3
   = note: call trace (innermost first):
             truth
   = note: functions left by tail calls are not shown

---- <dir>/sum.bnt: returnsError ----
returned `Result.Error`: bad input

---- <dir>/sum.bnt: crashes ----
runtime error[R0101]: division by zero
  --> <dir>/sum.bnt:29:13
   |
29 |   bind _ <- 1 div n
   |             ^^^^^^^
   |
   = note: call trace (innermost first):
             crashes
   = note: functions left by tail calls are not shown

---- <dir>/sum.bnt: exits ----
called `Process.exit` with status 4

test result: FAILED. 2 passed; 5 failed
"#;
    assert_eq!(out.stdout, expected);
}

// 関門: JSON Lines の項目と順（設計書 06-04「結果の報告」）。`"runtime"` は実行時エラーの報告の
// JSON の項目をそのまま持つ。
#[test]
fn json_lines_have_the_fields_in_order() {
    let dir = Directory::new("json");
    let file = dir.write("sum.bnt", MIXED);
    let out = run(&dir, &["--diagnostics=json", &file]);
    assert_eq!(out.exit, 1, "{}", out.stderr);
    let lines: Vec<&str> = out.stdout.lines().collect();
    assert_eq!(lines.len(), 8, "{}", out.stdout);
    let loc = |line: u32, start: u32, end: u32, offset: u32| {
        format!(
            "{{\"file\":\"<dir>/sum.bnt\",\"start\":{{\"line\":{line},\"column\":{start},\"offset\":{offset}}},\"end\":{{\"line\":{line},\"column\":{end},\"offset\":{}}},\"label\":\"\"}}",
            offset + end - start
        )
    };
    let offset = |needle: &str| MIXED.find(needle).unwrap() as u32;
    assert_eq!(
        lines[0],
        format!(
            "{{\"kind\":\"test\",\"file\":\"<dir>/sum.bnt\",\"name\":\"adds \\\"two\\\" numbers\",\"function\":\"adds\",\"location\":{},\"outcome\":\"passed\",\"failure\":null,\"stdout\":\"\",\"stderr\":\"\"}}",
            loc(5, 10, 14, offset("adds()"))
        )
    );
    assert_eq!(
        lines[1],
        format!(
            "{{\"kind\":\"test\",\"file\":\"<dir>/sum.bnt\",\"name\":\"sumOfEmpty\",\"function\":\"sumOfEmpty\",\"location\":{},\"outcome\":\"failed\",\"failure\":{{\"reason\":\"assert\",\"message\":\"assertion failed: Assert.equal\",\"primary\":{},\"notes\":[\"functions left by tail calls are not shown\"],\"trace\":[{{\"function\":\"sumOfEmpty\",\"location\":null}}],\"traceOmitted\":0,\"taskOrigins\":[],\"left\":\"3\",\"right\":\"4\"}},\"stdout\":\"out line\\n\",\"stderr\":\"err line\\n\"}}",
            loc(10, 10, 20, offset("sumOfEmpty()")),
            loc(13, 3, 39, offset("Assert.equal(actual: 3, expected: 4)"))
        )
    );
    assert!(
        lines[2].contains(
            "\"failure\":{\"reason\":\"assert\",\"message\":\"should hold\",\"primary\":{"
        ),
        "{}",
        lines[2]
    );
    assert!(!lines[2].contains("\"left\""), "{}", lines[2]);
    assert!(
        lines[3].contains("\"failure\":{\"reason\":\"error\",\"message\":\"bad input\"},"),
        "{}",
        lines[3]
    );
    assert!(
        lines[4].contains(
            "\"failure\":{\"reason\":\"runtime\",\"kind\":\"runtime\",\"severity\":\"error\",\"code\":\"R0101\",\"message\":\"division by zero\",\"primary\":{"
        ),
        "{}",
        lines[4]
    );
    assert!(
        lines[4].contains("\"trace\":[{\"function\":\"crashes\",\"location\":null}],\"traceOmitted\":0,\"taskOrigins\":[]}"),
        "{}",
        lines[4]
    );
    assert!(
        lines[5].contains(
            "\"failure\":{\"reason\":\"exit\",\"message\":\"called `Process.exit` with status 4\",\"exitCode\":4,\"notes\":[]},"
        ),
        "{}",
        lines[5]
    );
    assert!(lines[6].ends_with(
        "\"outcome\":\"passed\",\"failure\":null,\"stdout\":\"not shown\\n\",\"stderr\":\"\"}"
    ));
    assert_eq!(
        lines[7],
        "{\"kind\":\"testSummary\",\"passed\":2,\"failed\":5,\"filesNotRun\":0,\"interrupted\":false}"
    );
}

#[test]
fn all_passing_tests_end_with_ok_and_no_failures_section() {
    let dir = Directory::new("ok");
    let file = dir.write(
        "ok.bnt",
        "@test\nfunction one() -> Unit uses Assert.Check\n  Assert.notEqual(actual: 1, expected: 2)\nend function\n\n@test(\"second\")\nfunction two() -> Result[Unit, String]\n  return Result.Ok(())\nend function\n",
    );
    let out = run(&dir, &[&file]);
    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert_eq!(
        out.stdout,
        "test <dir>/ok.bnt: one ... ok\ntest <dir>/ok.bnt: \"second\" ... ok\n\ntest result: ok. 2 passed; 0 failed\n"
    );
}

#[test]
fn a_file_without_tests_writes_only_the_summary() {
    let dir = Directory::new("empty");
    let file = dir.write(
        "none.bnt",
        "function helper() -> Integer\n  return 1\nend function\n",
    );
    let out = run(&dir, &[&file]);
    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert_eq!(out.stdout, "test result: ok. 0 passed; 0 failed\n");
    fs::create_dir(dir.0.join("empty")).unwrap();
    for target in [&file, &dir.path("empty")] {
        for limit in [vec![], vec!["--allow-effects="]] {
            let mut args = limit;
            args.push(target);
            let text = run(&dir, &args);
            assert_eq!(text.exit, 0, "{}", text.stderr);
            assert_eq!(text.stderr, "");
            assert_eq!(text.stdout, "test result: ok. 0 passed; 0 failed\n");
            args.push("--diagnostics=json");
            let json = run(&dir, &args);
            assert_eq!(json.exit, 0, "{}", json.stderr);
            assert_eq!(json.stderr, "");
            assert_eq!(
                json.stdout,
                "{\"kind\":\"testSummary\",\"passed\":0,\"failed\":0,\"filesNotRun\":0,\"interrupted\":false}\n"
            );
        }
    }
}

// 関門: ディレクトリの下をパスの辞書順に扱い、根を指定したディレクトリにする（設計書 06-01「ディレクトリの指定（初回リリース版）」）。
// 下の階層のファイルが、指定したディレクトリからの名前でモジュールを取り込める。
#[test]
fn a_directory_is_expanded_in_path_order_with_itself_as_the_root() {
    let dir = Directory::new("tree");
    dir.write(
        "suite/Lib/Text.bnt",
        "public function message() -> String\n  return \"hello\"\nend function\n\n@test\nfunction libTest() -> Unit\n  return ()\nend function\n",
    );
    dir.write(
        "suite/b/second.bnt",
        "import Lib.Text\n\n@test\nfunction usesLib() -> Unit uses Assert.Check\n  Assert.equal(actual: Text.message(), expected: \"hello\")\nend function\n",
    );
    dir.write(
        "suite/a.bnt",
        "@test\nfunction first() -> Unit\n  return ()\nend function\n",
    );
    dir.write("suite/notes.txt", "not a script\n");
    let out = run(&dir, &[&dir.path("suite")]);
    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert_eq!(
        out.stdout,
        "test <dir>/suite/Lib/Text.bnt: libTest ... ok\ntest <dir>/suite/a.bnt: first ... ok\ntest <dir>/suite/b/second.bnt: usesLib ... ok\n\ntest result: ok. 3 passed; 0 failed\n"
    );

    // 公開入口では根も返す。直接指定とディレクトリ経由が混在しても、指定順と重複を保つ。
    let library = dir.0.join("suite/Lib/Text.bnt");
    let suite = dir.0.join("suite");
    let paths = vec![library.clone(), suite.clone(), library.clone()];
    let entries = cli::tools::test_runner::test_entries(&paths).unwrap();
    let expected = [
        (library.clone(), dir.0.join("suite/Lib")),
        (library.clone(), suite.clone()),
        (dir.0.join("suite/a.bnt"), suite.clone()),
        (dir.0.join("suite/b/second.bnt"), suite),
        (library, dir.0.join("suite/Lib")),
    ];
    assert_eq!(entries.len(), expected.len());
    for (entry, (path, root)) in entries.iter().zip(expected) {
        assert_eq!(entry.path, path);
        assert_eq!(entry.root, root);
        assert_eq!(entry.display_name, path.display().to_string());
    }
    let args: Vec<_> = paths.iter().map(|path| path.to_str().unwrap()).collect();
    let repeated = run(&dir, &args);
    assert_eq!(repeated.exit, 0, "{}", repeated.stderr);
    assert_eq!(repeated.stderr, "");
    assert_eq!(
        repeated.stdout,
        "test <dir>/suite/Lib/Text.bnt: libTest ... ok\ntest <dir>/suite/Lib/Text.bnt: libTest ... ok\ntest <dir>/suite/a.bnt: first ... ok\ntest <dir>/suite/b/second.bnt: usesLib ... ok\ntest <dir>/suite/Lib/Text.bnt: libTest ... ok\n\ntest result: ok. 5 passed; 0 failed\n"
    );
    let mut args = args;
    args.push("--check");
    let inspected = run(&dir, &args);
    assert_eq!(inspected.exit, 0, "{}", inspected.stderr);
    assert_eq!(inspected.stdout, "");
    assert_eq!(inspected.stderr, "");
}

#[test]
fn tests_of_imported_modules_run_only_when_their_file_is_given() {
    let dir = Directory::new("imported");
    dir.write(
        "Lib/Text.bnt",
        "public function message() -> String\n  return \"hello\"\nend function\n\n@test\nfunction libTest() -> Unit\n  return ()\nend function\n",
    );
    let main = dir.write(
        "main_test.bnt",
        "import Lib.Text\n\n@test\nfunction usesLib() -> Unit uses Assert.Check\n  Assert.equal(actual: Text.message(), expected: \"hello\")\nend function\n",
    );
    let out = run(&dir, &[&main]);
    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert_eq!(
        out.stdout,
        "test <dir>/main_test.bnt: usesLib ... ok\n\ntest result: ok. 1 passed; 0 failed\n"
    );
}

// 関門: 同じ入口のテストは準備済みの成果物を共有し、次の入口は実行後に準備する
// （設計書 02-11「テストの実行」）。入口・依存の再読や全入口の先行準備を出力で検出する。
#[test]
fn prepared_sources_are_reused_and_the_next_file_is_prepared_after_execution() {
    let dir = Directory::new("prepared");
    const NEXT: &str = "@test\nfunction updated() -> Unit\n  return ()\nend function\n";
    let next = dir.write(
        "next.bnt",
        "@test\nfunction invalid() -> Unit\n  return 1\nend function\n",
    );
    dir.write(
        "Lib/Text.bnt",
        "public function message() -> String\n  return \"original\"\nend function\n",
    );
    let first = dir.write(
        "first.bnt",
        &format!(
            r#"import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process
import Lib.Text

@test
function rewriteSources() -> Result[Unit, String] uses File.Write
  bind _ <- try File.writeText(path: "first.bnt", text: "invalid source") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  bind _ <- try File.writeText(path: "Lib/Text.bnt", text: "invalid source") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  bind _ <- try File.writeText(path: "next.bnt", text: {next_source}) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(())
end function

@test
function usesPreparedDependency() -> Result[Unit, String] uses Assert.Check, Process.Environment
  Assert.equal(actual: Text.message(), expected: "original")
  Assert.equal(actual: Process.arguments(), expected: [])
  Assert.equal(actual: Process.scriptDirectory(), expected: {directory})
  bind working <- try Process.workingDirectory() |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  Assert.equal(actual: working, expected: {directory})
  return Result.Ok(())
end function
"#,
            next_source = serde_json::to_string(NEXT).unwrap(),
            directory = serde_json::to_string(&dir.0).unwrap(),
        ),
    );

    let out = run(&dir, &[&first, &next]);

    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert_eq!(out.stderr, "");
    assert_eq!(
        out.stdout,
        "test <dir>/first.bnt: rewriteSources ... ok\ntest <dir>/first.bnt: usesPreparedDependency ... ok\ntest <dir>/next.bnt: updated ... ok\n\ntest result: ok. 3 passed; 0 failed\n"
    );
    assert_eq!(fs::read_to_string(&first).unwrap(), "invalid source");
    assert_eq!(
        fs::read_to_string(dir.0.join("Lib/Text.bnt")).unwrap(),
        "invalid source"
    );
    assert_eq!(fs::read_to_string(&next).unwrap(), NEXT);
}

// 関門: 上限付きだけ全入口の開始をまとめて判断する。後の拒否までに書き込む退行と、
// 最初の拒否で検査を打ち切る退行を CLI の診断・集計・ファイル状態で検出する。
#[test]
fn limited_tests_reject_every_entry_before_any_execution() {
    use serde_json::{Value, json};
    let dir = Directory::new("limited-rejection");
    let first = dir.write("first.bnt", r#"import Benitoite.Unofficial.IO.File
@test
function writeMarker() -> Result[Unit, String] uses File.Write
  bind _ <- try File.writeText(path: "marker", text: "started") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(())
end function
"#);
    let after = dir.write(
        "after.bnt",
        "@test\nfunction after() -> Unit uses State\nend function\n",
    );
    let empty = dir.write("empty.bnt", "function helper() -> Unit end function\n");
    for (source, expected_codes, expected_functions) in [
        (
            "import Benitoite.Unofficial.IO.Console\nimport Benitoite.Unofficial.IO.Process\n@test\nfunction firstMissing() -> Unit uses Console.Write, Assert.Check\nend function\n@test\nfunction secondMissing() -> Unit uses Process.Exit\nend function\n",
            vec!["E0512", "E0512", "E0512"],
            vec!["firstMissing", "secondMissing", "after"],
        ),
        (
            "@test\nfunction wrongType() -> Unit\n  return 1\nend function\n",
            vec!["E0401", "E0512"],
            vec!["after"],
        ),
        (
            include_str!("../testdata/patterns/todo195-decision-tree-budget.bnt"),
            vec!["L0112", "E0512"],
            vec!["after"],
        ),
    ] {
        let last = dir.write("last.bnt", source);
        let out = run(
            &dir,
            &[
                "--diagnostics=json",
                "--allow-effects=File.Write",
                &first,
                &last,
                &after,
                &empty,
                &empty,
            ],
        );
        assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
        assert_eq!(
            serde_json::from_str::<Value>(&out.stdout).unwrap(),
            json!({"kind":"testSummary","passed":0,"failed":0,"filesNotRun":5,"interrupted":false})
        );
        let text = run(
            &dir,
            &[
                "--allow-effects=File.Write",
                &first,
                &last,
                &after,
                &empty,
                &empty,
            ],
        );
        assert_eq!(text.exit, 2, "{}", text.stderr);
        assert_eq!(
            text.stdout,
            "test result: FAILED. 0 passed; 0 failed; 5 files not run\n"
        );
        assert!(!dir.0.join("marker").exists());
        let diagnostics: Vec<Value> = out
            .stderr
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        let codes: Vec<_> = diagnostics
            .iter()
            .map(|diag| diag["code"].as_str().unwrap())
            .collect();
        assert_eq!(codes, expected_codes, "{}", out.stderr);
        let limited: Vec<_> = diagnostics
            .iter()
            .filter(|diag| diag["code"] == "E0512")
            .collect();
        for (diag, function) in limited.iter().zip(&expected_functions) {
            assert_eq!(diag["kind"], "check");
            assert_eq!(
                diag["message"],
                format!("effects of `{function}` exceed `--allow-effects`")
            );
            assert_eq!(
                diag["primary"]["label"],
                "effect limit checked for this function"
            );
            assert_eq!(diag["notes"][1], "allowed effects: File.Write");
        }
        if expected_codes.len() == 3 {
            assert_eq!(limited[0]["primary"]["file"], "<dir>/last.bnt");
            assert_eq!(limited[0]["primary"]["start"]["line"], 4);
            assert_eq!(
                limited[0]["notes"][0],
                "effects not allowed: Assert.Check, Console.Write"
            );
            assert_eq!(limited[1]["primary"]["start"]["line"], 7);
            assert_eq!(limited[1]["notes"][0], "effects not allowed: Process.Exit");
            assert_eq!(limited[2]["primary"]["file"], "<dir>/after.bnt");
        }
    }
}

// 関門: 報告の Assert.Check を落とした場合と、報告後の契約追加を全体の非実行として拒否する。
// 既存の固定した許可の表では、報告から実行へ集合を戻す接続を確認できない。
#[test]
fn limited_tests_recheck_reported_contracts_after_changes() {
    use serde_json::{Value, json};
    let dir = Directory::new("limited-report-changes");
    let first = dir.write("first.bnt", "import Benitoite.Unofficial.IO.File\n@test\nfunction writeMarker() -> Result[Unit, String] uses File.Write\n  return File.writeText(path: \"marker\", text: \"started\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)\nend function\n");
    const LAST: &str = "@test\nfunction verifies() -> Unit uses Assert.Check\n  Assert.equal(actual: 1, expected: 1)\nend function\n";
    let last = dir.write("last.bnt", LAST);
    let out = run(&dir, &["--check", "--report=json", &first, &last]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let report: Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["complete"], true);
    assert_eq!(report["executed"], false);
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        json!(["Assert.Check", "File.Write"])
    );
    let allowed = report["aggregateEffects"]["expanded"]
        .as_array()
        .unwrap()
        .iter()
        .map(|name| name.as_str().unwrap())
        .collect::<Vec<_>>()
        .join(",");
    assert!(!dir.0.join("marker").exists());
    for (change, limit, missing) in [
        (false, "File.Write".to_owned(), "Assert.Check"),
        (true, allowed.clone(), "State"),
    ] {
        dir.write(
            "last.bnt",
            &LAST.replace(
                "uses Assert.Check",
                if change {
                    "uses Assert.Check, State"
                } else {
                    "uses Assert.Check"
                },
            ),
        );
        let out = run(
            &dir,
            &[
                "--diagnostics=json",
                &format!("--allow-effects={limit}"),
                &first,
                &last,
            ],
        );
        assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
        assert_eq!(
            serde_json::from_str::<Value>(&out.stdout).unwrap(),
            json!({"kind":"testSummary","passed":0,"failed":0,"filesNotRun":2,"interrupted":false})
        );
        assert!(!dir.0.join("marker").exists());
        let diagnostic: Value = serde_json::from_str(&out.stderr).unwrap();
        assert_eq!(diagnostic["code"], "E0512");
        assert_eq!(
            diagnostic["message"],
            "effects of `verifies` exceed `--allow-effects`"
        );
        assert_eq!(diagnostic["primary"]["file"], "<dir>/last.bnt");
        assert_eq!(
            diagnostic["notes"][0],
            format!("effects not allowed: {missing}")
        );
    }
    // 余分な許可は受理し、全入口の準備が成功したときだけ先頭の書き込みも行う。
    dir.write("last.bnt", LAST);
    let out = run(
        &dir,
        &[
            "--diagnostics=json",
            &format!("--allow-effects={allowed},Console.Read"),
            &first,
            &last,
        ],
    );
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let lines: Vec<Value> = out
        .stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 3);
    assert_eq!(lines[0]["function"], "writeMarker");
    assert_eq!(lines[0]["outcome"], "passed");
    assert_eq!(lines[1]["function"], "verifies");
    assert_eq!(lines[1]["outcome"], "passed");
    assert_eq!(
        lines[2],
        json!({"kind":"testSummary","passed":2,"failed":0,"filesNotRun":0,"interrupted":false})
    );
    assert_eq!(fs::read_to_string(dir.0.join("marker")).unwrap(), "started");
}

// 関門: die と Exit のハンドラで処理した集合も報告から許可へ戻せること、
// 許可後は既存の failure.die と明示した終了値を保つことを CLI 境界で確認する。
#[test]
fn limited_test_control_flow_matches_reported_effects() {
    use serde_json::{Value, json};
    let dir = Directory::new("limited-control-flow");
    let mut source = "import Benitoite.Unofficial.IO.Process\n".to_owned();
    for (name, declaration, body) in [
        (
            "dies",
            " uses Process.Exit",
            "bind value: Unit <- try Option.None or die(\"test context\")",
        ),
        ("exits", " uses Process.Exit", "Process.exit(7)"),
        (
            "handledDie",
            "",
            "bind value <- handle\n try Option.None or die\nwith\n case Process.exit(code) -> ()\nend handle",
        ),
        (
            "declaredDie",
            " uses Process.Exit",
            "bind value <- handle\n try Option.None or die\nwith\n case Process.exit(code) -> ()\nend handle",
        ),
        (
            "handledExit",
            "",
            "bind value <- handle\n Process.exit(7)\nwith\n case Process.exit(code) -> ()\nend handle",
        ),
        (
            "declaredExit",
            " uses Process.Exit",
            "bind value <- handle\n Process.exit(7)\nwith\n case Process.exit(code) -> ()\nend handle",
        ),
    ] {
        source.push_str(&format!(
            "@test\nfunction {name}() -> Unit{declaration}\n {body}\nend function\n"
        ));
    }
    let file = dir.write("flow.bnt", &source);
    let out = run(&dir, &["--check", "--report=json", &file]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let report: Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["complete"], true);
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        json!(["Process.Exit"])
    );
    let tests = report["targets"][0]["tests"].as_array().unwrap();
    assert_eq!(tests.len(), 6);
    for (index, expected) in [true, true, false, true, false, true]
        .into_iter()
        .enumerate()
    {
        assert_eq!(
            tests[index]["effects"]["expanded"],
            if expected {
                json!(["Process.Exit"])
            } else {
                json!([])
            }
        );
    }
    let rejected = run(&dir, &["--diagnostics=json", "--allow-effects=", &file]);
    assert_eq!(rejected.exit, 2, "{} {}", rejected.stdout, rejected.stderr);
    assert_eq!(
        serde_json::from_str::<Value>(&rejected.stdout).unwrap(),
        json!({"kind":"testSummary","passed":0,"failed":0,"filesNotRun":1,"interrupted":false})
    );
    let diagnostics: Vec<Value> = rejected
        .stderr
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(diagnostics.len(), 4);
    for (diagnostic, function) in
        diagnostics
            .iter()
            .zip(["dies", "exits", "declaredDie", "declaredExit"])
    {
        assert_eq!(diagnostic["code"], "E0512");
        assert_eq!(
            diagnostic["message"],
            format!("effects of `{function}` exceed `--allow-effects`")
        );
        assert_eq!(diagnostic["notes"][0], "effects not allowed: Process.Exit");
    }
    let allowed = report["aggregateEffects"]["expanded"]
        .as_array()
        .unwrap()
        .iter()
        .map(|name| name.as_str().unwrap())
        .collect::<Vec<_>>()
        .join(",");
    let out = run(
        &dir,
        &[
            "--diagnostics=json",
            &format!("--allow-effects={allowed}"),
            &file,
        ],
    );
    assert_eq!(out.exit, 1, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let lines: Vec<Value> = out
        .stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 7);
    assert_eq!(lines[0]["failure"]["exitCode"], 1);
    assert_eq!(lines[0]["failure"]["die"]["kind"], "die");
    assert!(
        lines[0]["failure"]["die"]
            .as_object()
            .unwrap()
            .contains_key("code")
    );
    assert_eq!(lines[0]["failure"]["die"]["code"], Value::Null);
    assert_eq!(
        lines[0]["failure"]["die"]["notes"],
        json!([
            "message: test context",
            "cause: expected a value, got Option.None"
        ])
    );
    assert_eq!(lines[1]["failure"]["exitCode"], 7);
    assert_eq!(lines[1]["failure"]["die"], Value::Null);
    for line in &lines[2..6] {
        assert_eq!(line["outcome"], "passed");
    }
    assert_eq!(
        lines[6],
        json!({"kind":"testSummary","passed":4,"failed":2,"filesNotRun":0,"interrupted":false})
    );
}

// 関門: test の引数解析でも run と同じ集合を受理し、分離値をパスや報告指定にしない。
#[test]
fn limited_test_options_reject_invalid_or_check_only_invocations() {
    let dir = Directory::new("limited-usage");
    for (args, message) in [
        (
            vec!["--allow-effects"],
            "missing value for `--allow-effects`",
        ),
        (
            vec!["--allow-effects=", "--allow-effects=", "missing.bnt"],
            "option `--allow-effects` may only be specified once",
        ),
        (
            vec!["--allow-effects=State,State", "missing.bnt"],
            "duplicate effect name `State` in `--allow-effects`",
        ),
        (
            vec!["--allow-effects=State,", "missing.bnt"],
            "empty effect name in `--allow-effects`",
        ),
        (
            vec!["--allow-effects", "IO.All", "missing.bnt"],
            "invalid effect name `IO.All` in `--allow-effects`; use atomic names from `expanded`",
        ),
        (
            vec!["--allow-effects=console.write", "missing.bnt"],
            "invalid effect name `console.write` in `--allow-effects`; use atomic names from `expanded`",
        ),
        (
            vec!["--allow-effects= State", "missing.bnt"],
            "invalid effect name ` State` in `--allow-effects`; use atomic names from `expanded`",
        ),
        (
            vec!["--allow-effects", "--report=json", "missing.bnt"],
            "invalid effect name `--report=json` in `--allow-effects`; use atomic names from `expanded`",
        ),
        (
            vec!["--allow-effects=", "--check", "missing.bnt"],
            "option `--allow-effects` is not accepted with `test --check`",
        ),
    ] {
        let out = run(&dir, &args);
        assert_eq!(out.exit, 2, "{args:?}: {}", out.stderr);
        assert_eq!(out.stdout, "");
        assert_eq!(
            out.stderr,
            format!("error: {message}\nrun `benitoite --help` for usage\n"),
            "{args:?}"
        );
    }
}

// 関門: 全入口が成功したときの順と結果を通常実行と比較する。先頭の実行で後の入口を
// 書き換えても、全保持した比較済み成果物を使うことを、待ちや本番フックなしで確認する。
#[test]
fn limited_tests_consume_the_prepared_artifacts_in_order() {
    let dir = Directory::new("limited-prepared");
    let first = dir.write("first.bnt", r#"import Benitoite.Unofficial.IO.File
@test
function rewriteNext() -> Result[Unit, String] uses File.Write
  bind _ <- try File.writeText(path: "next.bnt", text: "invalid source") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(())
end function
@test
function second() -> Unit uses Assert.Check
  Assert.equal(actual: 1, expected: 1)
end function
"#);
    const NEXT: &str = "@test\nfunction original() -> Unit uses Assert.Check\n  Assert.equal(actual: 2, expected: 2)\nend function\n";
    let next = dir.write("next.bnt", NEXT);
    let baseline = run(&dir, &[&first]);
    assert_eq!(baseline.exit, 0, "{}", baseline.stderr);
    assert_eq!(baseline.stderr, "");
    dir.write("next.bnt", NEXT);
    let next_baseline = run(&dir, &[&next]);
    assert_eq!(next_baseline.exit, 0, "{}", next_baseline.stderr);
    assert_eq!(next_baseline.stderr, "");
    let limited = run(
        &dir,
        &[
            &first,
            "--allow-effects",
            "Assert.Check,File.Write,Console.Read",
            &next,
        ],
    );
    assert_eq!(limited.exit, 0, "{}", limited.stderr);
    assert_eq!(limited.stderr, "");
    assert_eq!(
        limited.stdout,
        "test <dir>/first.bnt: rewriteNext ... ok\ntest <dir>/first.bnt: second ... ok\ntest <dir>/next.bnt: original ... ok\n\ntest result: ok. 3 passed; 0 failed\n"
    );
    assert!(
        limited
            .stdout
            .starts_with(baseline.stdout.split("\n\n").next().unwrap())
    );
    assert!(
        limited
            .stdout
            .contains(next_baseline.stdout.split("\n\n").next().unwrap())
    );
    assert_eq!(fs::read_to_string(&next).unwrap(), "invalid source");
    let pure = dir.write("pure.bnt", "@test\nfunction pure() -> Unit end function\n");
    for options in [vec!["--allow-effects="], vec!["--allow-effects", ""]] {
        let mut args = options;
        args.push(&pure);
        let limited = run(&dir, &args);
        let normal = run(&dir, &[&pure]);
        assert_eq!(
            (limited.exit, limited.stdout, limited.stderr),
            (normal.exit, normal.stdout, normal.stderr)
        );
    }
}

// 関門: 検査の誤りのファイルはテストを実行せず、ほかのファイルは実行する。失敗がなくても集計は FAILED、終了状態 2。
#[test]
fn a_file_with_check_errors_is_not_run_but_others_are() {
    let dir = Directory::new("broken");
    let broken = dir.write(
        "broken.bnt",
        "@test\nfunction bad() -> Unit\n  return 1\nend function\n",
    );
    let good = dir.write(
        "good.bnt",
        "@test\nfunction fine() -> Unit\n  return ()\nend function\n",
    );
    let out = run(&dir, &[&broken, &good]);
    assert_eq!(out.exit, 2);
    assert!(out.stderr.contains("error["), "{}", out.stderr);
    assert!(
        out.stderr.contains("could not test <dir>/broken.bnt"),
        "{}",
        out.stderr
    );
    assert_eq!(
        out.stdout,
        "test <dir>/good.bnt: fine ... ok\n\ntest result: FAILED. 1 passed; 0 failed; 1 files not run\n"
    );
    let json = run(&dir, &["--diagnostics=json", &broken]);
    assert_eq!(json.exit, 2);
    assert!(
        json.stderr.starts_with("{\"kind\":\"check\""),
        "{}",
        json.stderr
    );
    assert_eq!(
        json.stdout,
        "{\"kind\":\"testSummary\",\"passed\":0,\"failed\":0,\"filesNotRun\":1,\"interrupted\":false}\n"
    );
}

#[test]
fn deny_warnings_skips_a_file_with_warnings() {
    let dir = Directory::new("warn");
    let file = dir.write(
        "warn.bnt",
        "@test\nfunction warns() -> Result[Unit, String]\n  bind _ <- 1 div 0\n  return Result.Ok(())\nend function\n",
    );
    let plain = run(&dir, &[&file]);
    assert_eq!(plain.exit, 1, "{}", plain.stderr);
    assert!(plain.stderr.contains("warning["), "{}", plain.stderr);
    let denied = run(&dir, &["--deny-warnings", &file]);
    assert_eq!(denied.exit, 2, "{}", denied.stdout);
    assert_eq!(
        denied.stdout,
        "test result: FAILED. 0 passed; 0 failed; 1 files not run\n"
    );
}

// 関門: 終了状態は集計の成功数だけで決めず、検査拒否をテスト失敗より、
// 実行環境の不具合をその両方より優先する（設計書 06-01「`test` のコマンドライン（初回リリース版）」）。
#[test]
fn exit_status_prioritizes_internal_and_check_errors_over_test_failures() {
    use benitoite::runtime::io::event::{InterruptGuard, Wakeup};
    use serde_json::{Value, json};

    #[derive(Debug)]
    struct FailedAttach(std::cell::Cell<usize>);

    impl InterruptSource for FailedAttach {
        fn requested(&self) -> bool {
            false
        }

        fn attach(&self, _: &Wakeup) -> std::io::Result<Option<InterruptGuard>> {
            // 最初のテストは完了させ、次の実行の OS の通知登録が失敗する場合を作る。
            let remaining = self.0.get();
            if remaining == 0 {
                Err(std::io::Error::other("test interrupt registration failed"))
            } else {
                self.0.set(remaining - 1);
                Ok(None)
            }
        }
    }

    let dir = Directory::new("exit-priority");
    let failed = dir.write("failed.bnt", "@test\nfunction failed() -> Unit uses Assert.Check\n  Assert.fail(\"expected failure\")\nend function\n");
    let broken = dir.write(
        "broken.bnt",
        "@test\nfunction broken() -> Unit\n  return 1\nend function\n",
    );
    let good = dir.write("good.bnt", "@test\nfunction good() -> Unit\nend function\n");
    for (paths, fail_attach, exit, not_run) in [
        (vec![&failed], false, 1, 0),
        (vec![&failed, &broken], false, 2, 1),
        (vec![&failed, &broken, &good], true, 3, 1),
    ] {
        let mut args = vec!["--diagnostics=json"];
        args.extend(paths.iter().map(|path| path.as_str()));
        let interrupt: Box<dyn InterruptSource> = if fail_attach {
            Box::new(FailedAttach(std::cell::Cell::new(1)))
        } else {
            Box::new(NoInterrupt)
        };
        let out = run_with(&dir, &args, interrupt, ExecMode::Direct);
        assert_eq!(out.exit, exit, "{} {}", out.stdout, out.stderr);
        let lines: Vec<Value> = out
            .stdout
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(lines[0]["kind"], "test");
        assert_eq!(lines[0]["function"], "failed");
        assert_eq!(lines[0]["outcome"], "failed");
        if fail_attach {
            // 実行開始後の不具合は、未完了の実行を 0/0 の集計へ置き換えない。
            assert_eq!(lines.len(), 1);
        } else {
            assert_eq!(lines.len(), 2);
            assert_eq!(
                lines[1],
                json!({"kind":"testSummary","passed":0,"failed":1,"filesNotRun":not_run,"interrupted":false})
            );
        }
        let diagnostics: Vec<Value> = out
            .stderr
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        if not_run > 0 {
            assert_eq!(diagnostics[0]["code"], "E0401");
        } else {
            assert_eq!(diagnostics, Vec::<Value>::new());
        }
        assert_eq!(
            diagnostics.len(),
            usize::from(not_run > 0) + usize::from(fail_attach)
        );
        if fail_attach {
            assert_eq!(diagnostics.len(), 2);
            assert_eq!(diagnostics[1]["kind"], "internal");
            assert_eq!(diagnostics[1]["code"], Value::Null);
            assert_eq!(
                diagnostics[1]["notes"][2],
                "cannot attach interrupt: test interrupt registration failed"
            );
        }
    }
}

#[test]
fn max_call_stack_limits_each_test() {
    let dir = Directory::new("stack");
    let file = dir.write(
        "deep.bnt",
        "function depth(n: Integer) -> Integer\n  if n = 0 then\n    return 0\n  end if\n  return 1 + depth(n - 1)\nend function\n\n@test\nfunction deep() -> Unit uses Assert.Check\n  Assert.equal(actual: depth(1000), expected: 1000)\nend function\n",
    );
    let roomy = run(&dir, &[&file]);
    assert_eq!(roomy.exit, 0, "{}{}", roomy.stdout, roomy.stderr);
    let small = run(&dir, &["--max-call-stack=64KiB", &file]);
    assert_eq!(small.exit, 1, "{}", small.stderr);
    assert!(
        small
            .stdout
            .contains("test <dir>/deep.bnt: deep ... FAILED"),
        "{}",
        small.stdout
    );
    assert!(
        small.stdout.contains("runtime error[R0901]"),
        "{}",
        small.stdout
    );
}

// 関門: 起動したタスクの中の失敗では、起動の履歴の最後の段がテストの関数の名前になる（設計書 02-10「実行時エラーと資源の不足の報告」）。
// テストの関数のタスクで起きたときは空の配列。`run` の経路は `main` のまま。
#[test]
fn task_origins_end_at_the_test_function() {
    let dir = Directory::new("tasks");
    let file = dir.write(
        "tasks.bnt",
        "function divide(n: Integer) -> Integer\n  return 10 div n\nend function\n\n@test\nfunction runtimeInTask() -> Unit\n  bind _ <- Task.all([lambda() return divide(0) end lambda])\nend function\n\nfunction check() -> Unit uses Assert.Check\n  Assert.fail(\"in task\")\nend function\n\n@test\nfunction assertInTask() -> Unit uses Assert.Check\n  bind _ <- Task.all([lambda() return check() end lambda])\nend function\n\n@test\nfunction assertHere() -> Unit uses Assert.Check\n  Assert.fail(\"here\")\nend function\n",
    );
    let out = run(&dir, &["--diagnostics=json", &file]);
    assert_eq!(out.exit, 1, "{}", out.stderr);
    let lines: Vec<&str> = out.stdout.lines().collect();
    assert!(
        lines[0].contains("\"taskOrigins\":[{\"function\":\"Task.all\",\"location\":{")
            && lines[0].contains("},{\"function\":\"runtimeInTask\",\"location\":null}]"),
        "{}",
        lines[0]
    );
    assert!(lines[1].contains("\"reason\":\"assert\""), "{}", lines[1]);
    assert!(
        lines[1].contains("},{\"function\":\"assertInTask\",\"location\":null}]"),
        "{}",
        lines[1]
    );
    assert!(
        !out.stdout.contains("\"function\":\"main\""),
        "{}",
        out.stdout
    );
    assert!(lines[2].contains("\"taskOrigins\":[]"), "{}", lines[2]);

    let text = run(&dir, &[&file]);
    assert!(
        text.stdout
            .contains("   = note: in a task started by (innermost first):\n"),
        "{}",
        text.stdout
    );
    assert!(
        text.stdout.contains("             assertInTask\n"),
        "{}",
        text.stdout
    );
    assert!(!text.stdout.contains(" main\n"), "{}", text.stdout);

    // `run` の経路の最後の段は `main` のまま。
    let script = dir.write(
        "main.bnt",
        "function divide(n: Integer) -> Integer\n  return 10 div n\nend function\n\nfunction main() -> Unit\n  bind _ <- Task.all([lambda() return divide(0) end lambda])\nend function\n",
    );
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let env = CliEnv {
        stdout: OutputTarget::Capture(Arc::clone(&stdout)),
        stderr: OutputTarget::Capture(Arc::clone(&stderr)),
        stdin: StdinSource::Empty,
        working_directory: dir.0.clone(),
        color: false,
        mode: ExecMode::Direct,
        interrupt: Some(Box::new(NoInterrupt)),
        parts: None,
        heap: HeapConfig::default(),
        dev_panic: DevPanic::None,
        dev_alloc_stats: false,
    };
    let command = cli::parse_args(vec![
        OsString::from("run"),
        OsString::from("--diagnostics=json"),
        OsString::from(script),
    ])
    .unwrap();
    assert_eq!(cli::execute(command, env), 1);
    let err = String::from_utf8(stderr.lock().unwrap().clone()).unwrap();
    assert!(
        err.contains("{\"function\":\"main\",\"location\":null}]"),
        "{err}"
    );
}

// 関門: 行き詰まりの報告で、待つ最初のタスクをテストの関数の名前で示す（設計書 02-10「実行時エラーと資源の不足の報告」）。
#[test]
fn deadlock_reports_name_the_first_task_after_the_test_function() {
    let dir = Directory::new("deadlock");
    let file = dir.write(
        "deadlock.bnt",
        "function awaitSaved(cell: Reference[Option[Task[Integer]]]) -> Integer uses State\n  return match Reference.get(cell) with\n    case Option.None -> awaitSaved(cell)\n    case Option.Some(task) -> Task.await(task)\n  end match\nend function\n\n@test\nfunction stuck() -> Unit uses State\n  bind saved: Reference[Option[Task[Integer]]] <- Reference.new(Option.None)\n  with group = TaskGroup.open() do\n    bind task <- TaskGroup.spawn(group: group, action: lambda() return awaitSaved(saved) end lambda)\n    Reference.set(reference: saved, value: Option.Some(task))\n  end with\nend function\n",
    );
    let out = run(&dir, &[&file]);
    assert_eq!(out.exit, 1, "{}", out.stderr);
    assert!(
        out.stdout.contains("runtime error[R1001]"),
        "{}",
        out.stdout
    );
    assert!(
        out.stdout.contains("\n             stuck  ") && !out.stdout.contains(" main "),
        "{}",
        out.stdout
    );
    let json = run(&dir, &["--diagnostics=json", &file]);
    assert!(
        json.stdout
            .contains("\"waitingTasks\":[{\"task\":{\"function\":\"stuck\",\"location\":null}"),
        "{}",
        json.stdout
    );
}

#[test]
fn an_interrupt_request_ends_with_the_interrupted_summary() {
    let dir = Directory::new("interrupt");
    let file = dir.write(
        "one.bnt",
        "@test\nfunction one() -> Unit\n  return ()\nend function\n",
    );
    let out = run_with(
        &dir,
        &[&file],
        Box::new(AlwaysInterrupted),
        ExecMode::Direct,
    );
    assert_eq!(out.exit, 130);
    assert_eq!(
        out.stdout,
        "test result: FAILED. 0 passed; 0 failed; interrupted\n"
    );
    let json = run_with(
        &dir,
        &["--diagnostics=json", &file],
        Box::new(AlwaysInterrupted),
        ExecMode::Request,
    );
    assert_eq!(json.exit, 130);
    assert_eq!(
        json.stdout,
        "{\"kind\":\"testSummary\",\"passed\":0,\"failed\":0,\"filesNotRun\":0,\"interrupted\":true}\n"
    );
    // 上限付きでは、実行前に全体を止めた既知の全入口（重複を含む）を数える。
    let limited = run_with(
        &dir,
        &["--diagnostics=json", "--allow-effects=", &file, &file],
        Box::new(AlwaysInterrupted),
        ExecMode::Direct,
    );
    assert_eq!(limited.exit, 130);
    assert_eq!(limited.stderr, "");
    assert_eq!(
        limited.stdout,
        "{\"kind\":\"testSummary\",\"passed\":0,\"failed\":0,\"filesNotRun\":2,\"interrupted\":true}\n"
    );
    let rejected = dir.write(
        "rejected.bnt",
        "@test\nfunction rejected() -> Unit uses Assert.Check\nend function\n",
    );
    for diagnostics in ["--diagnostics=text", "--diagnostics=json"] {
        let out = run_with(
            &dir,
            &[diagnostics, "--allow-effects=", &rejected, &file, &file],
            Box::new(InterruptAfterReads {
                reads: Arc::new(std::sync::atomic::AtomicUsize::new(0)),
                before: 1,
            }),
            ExecMode::Direct,
        );
        assert_eq!(out.exit, 130, "{}", out.stderr);
        assert!(out.stderr.contains("E0512"), "{}", out.stderr);
        assert_eq!(
            out.stdout,
            if diagnostics == "--diagnostics=text" {
                "test result: FAILED. 0 passed; 0 failed; 3 files not run; interrupted\n"
            } else {
                "{\"kind\":\"testSummary\",\"passed\":0,\"failed\":0,\"filesNotRun\":3,\"interrupted\":true}\n"
            }
        );
    }
}

#[test]
fn check_is_accepted_and_missing_paths_still_report_usage_errors() {
    let dir = Directory::new("usage");
    let file = dir.write("a.bnt", "@test\nfunction example() -> Unit uses Assert.Check\n  Assert.fail(\"must not run\")\nend function\n");
    for (args, exit, stderr) in [
        (
            vec![],
            2,
            format!(
                "{}\n{}\n",
                cli::text::USAGE_ERROR.replace("{detail}", "missing path"),
                cli::text::SEE_HELP
            ),
        ),
        (vec!["--check", &file], 0, String::new()),
    ] {
        let out = run(&dir, &args);
        assert_eq!(out.exit, exit);
        assert_eq!(out.stdout, "");
        assert_eq!(out.stderr, stderr);
    }
}

#[test]
fn check_does_not_run_user_code_or_write_result_lines() {
    let dir = Directory::new("check-only");
    let file = dir.write("mixed.bnt", MIXED);
    let writes = dir.write(
        "writes.bnt",
        "import Benitoite.Unofficial.IO.File\n@test\nfunction writes() -> Unit uses File.Write\n  bind _ <- File.writeText(path: \"marker.txt\", text: \"executed\")\n  return ()\nend function\n",
    );
    let helper = dir.write(
        "helper.bnt",
        "function helper() -> Integer\n  return 1\nend function\n",
    );
    fs::create_dir(dir.0.join("empty")).unwrap();
    for diagnostics in ["--diagnostics=text", "--diagnostics=json"] {
        for target in [&file, &writes, &helper, &dir.path("empty")] {
            let out = run(&dir, &[diagnostics, target, "--check"]);
            assert_eq!(out.exit, 0, "{}", out.stderr);
            assert_eq!(out.stdout, "");
            assert_eq!(out.stderr, "");
            assert!(!dir.0.join("marker.txt").exists());
        }
    }
    for target in [&file, &writes] {
        let out = run(&dir, &["--check", "--report=json", target]);
        assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
        assert_eq!(out.stderr, "");
        let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
        assert_eq!(report["kind"], "testCheckReport");
        assert_eq!(report["status"], "ok");
        assert_eq!(report["complete"], true);
        assert_eq!(report["executed"], false);
        assert!(!dir.0.join("marker.txt").exists());
        if target == &file {
            assert_eq!(
                report["targets"][0]["tests"][0]["effects"]["expanded"],
                serde_json::json!(["Assert.Check"])
            );
            assert_eq!(
                report["aggregateEffects"]["expanded"],
                serde_json::json!(["Assert.Check", "Console.Write", "Process.Exit"])
            );
        }
    }
    // 同じ入口を実行すると Console の両出力とファイルの変更が観測できる。
    // 非実行を時間待ちや、実行しても何もしない関数で判定しない。
    let executed = run(&dir, &["--diagnostics=json", &file, &writes]);
    assert_eq!(executed.exit, 1, "{} {}", executed.stdout, executed.stderr);
    assert_eq!(executed.stderr, "");
    let lines: Vec<serde_json::Value> = executed
        .stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines[1]["function"], "sumOfEmpty");
    assert_eq!(lines[1]["stdout"], "out line\n");
    assert_eq!(lines[1]["stderr"], "err line\n");
    assert_eq!(lines[7]["function"], "writes");
    assert_eq!(lines[7]["outcome"], "passed");
    assert_eq!(
        lines[8],
        serde_json::json!({"kind":"testSummary", "passed":3, "failed":5, "filesNotRun":0, "interrupted":false})
    );
    assert_eq!(
        fs::read_to_string(dir.0.join("marker.txt")).unwrap(),
        "executed"
    );
}

// 作成時の関門: 報告と実行の対象が分かれる退行を、同じ実ファイルと独立した期待表で捕まえる。
// 従来の探索入口だけの検査では、報告への写しと関数の選択を比較できない。本番 API は加えない。
#[test]
fn check_report_and_execution_select_the_same_entries_and_functions() {
    use serde_json::{Value, json};
    let dir = Directory::new("selection-parity");
    dir.write("suite/package.bnt", "language \"0.0.9\"\n");
    dir.write("suite/Lib/Text.bnt", "public function message() -> String\n  return \"hello\"\nend function\n@test\nfunction libTest() -> Unit\nend function\n");
    dir.write("suite/tests.bnt", "import Lib.Text\n@test\nfunction usesLib() -> Unit uses Assert.Check\n  Assert.equal(actual: Text.message(), expected: \"hello\")\nend function\n");
    dir.write(
        "suite/none.bnt",
        "function helper() -> Unit\nend function\n",
    );
    dir.write("suite/deps/package.bnt", "language \"0.0.9\"\n");
    dir.write(
        "suite/deps/tests.bnt",
        "@test\nfunction packageTest() -> Unit\nend function\n",
    );
    dir.write("suite/notes.txt", "not a script\n");
    fs::create_dir(dir.0.join("empty")).unwrap();
    // 入口ごとに指定番号・表示パス・根・関数列を固定する。表示パスだけでは重複を識別しない。
    let lib_direct = json!([
        0,
        "<dir>/suite/Lib/Text.bnt",
        "<dir>/suite/Lib",
        ["libTest"]
    ]);
    let lib_walked = json!([1, "<dir>/suite/Lib/Text.bnt", "<dir>/suite", ["libTest"]]);
    let mut cases = vec![
        (vec!["suite/Lib/Text.bnt"], json!([lib_direct]), 0),
        (
            vec!["suite/tests.bnt"],
            json!([[0, "<dir>/suite/tests.bnt", "<dir>/suite", ["usesLib"]]]),
            0,
        ),
        (
            vec!["suite/Lib/Text.bnt", "suite", "suite/Lib/Text.bnt"],
            json!([
                lib_direct,
                lib_walked,
                [1, "<dir>/suite/none.bnt", "<dir>/suite", []],
                [1, "<dir>/suite/tests.bnt", "<dir>/suite", ["usesLib"]],
                [
                    2,
                    "<dir>/suite/Lib/Text.bnt",
                    "<dir>/suite/Lib",
                    ["libTest"]
                ]
            ]),
            0,
        ),
        (
            vec!["suite/deps"],
            json!([[
                0,
                "<dir>/suite/deps/tests.bnt",
                "<dir>/suite/deps",
                ["packageTest"]
            ]]),
            0,
        ),
        (vec!["empty"], json!([]), 0),
        (
            vec!["suite/none.bnt"],
            json!([[0, "<dir>/suite/none.bnt", "<dir>/suite", []]]),
            0,
        ),
        (
            vec!["suite/missing.bnt", "suite/tests.bnt"],
            json!([
                [0, "<dir>/suite/missing.bnt", "<dir>/suite", null],
                [1, "<dir>/suite/tests.bnt", "<dir>/suite", ["usesLib"]]
            ]),
            2,
        ),
    ];
    #[cfg(unix)]
    {
        use std::os::unix::fs::symlink;
        // 走査はファイルとディレクトリのリンクを除外する。明示したリンクは従来どおり扱う。
        symlink(
            dir.0.join("suite/Lib/Text.bnt"),
            dir.0.join("suite/alias.bnt"),
        )
        .unwrap();
        symlink(dir.0.join("suite/Lib"), dir.0.join("suite/linked")).unwrap();
        symlink(dir.0.join("missing.bnt"), dir.0.join("suite/dangling.bnt")).unwrap();
        cases.push((
            vec!["suite/alias.bnt"],
            json!([[0, "<dir>/suite/alias.bnt", "<dir>/suite", ["libTest"]]]),
            0,
        ));
        cases.push((
            vec!["suite/linked"],
            json!([[
                0,
                "<dir>/suite/linked/Text.bnt",
                "<dir>/suite/linked",
                ["libTest"]
            ]]),
            0,
        ));
    }
    for (paths, expected, exit) in cases {
        let paths: Vec<_> = paths.iter().map(|path| dir.path(path)).collect();
        let mut args: Vec<_> = paths.iter().map(String::as_str).collect();
        args.extend(["--check", "--report=json"]);
        let out = run(&dir, &args);
        assert_eq!(out.exit, exit, "{paths:?}: {} {}", out.stdout, out.stderr);
        assert_eq!(out.stderr, "");
        let report: Value = serde_json::from_str(&out.stdout).unwrap();
        assert_eq!(report["kind"], "testCheckReport");
        assert_eq!(
            report["status"],
            if exit == 0 { "ok" } else { "checkError" }
        );
        assert_eq!(report["complete"], exit == 0);
        assert_eq!(report["targetsComplete"], true);
        assert_eq!(report["executed"], false);
        let targets = report["targets"].as_array().unwrap();
        let actual: Vec<_> = targets
            .iter()
            .map(|t| {
                let functions = t["tests"].as_array().map(|tests| {
                    tests
                        .iter()
                        .map(|test| test["function"].clone())
                        .collect::<Vec<_>>()
                });
                json!([t["requestIndex"], t["entry"], t["root"], functions])
            })
            .collect();
        assert_eq!(json!(actual), expected, "{paths:?}");
        for (index, target) in targets.iter().enumerate() {
            assert_eq!(target["targetId"], format!("t{index}"));
            if expected[index][3].is_null() {
                assert_eq!(target["tests"], Value::Null);
                assert_eq!(target["sourceId"], Value::Null);
            } else if expected[index][3] == json!([]) {
                assert_eq!(target["tests"], json!([]));
            }
            let set = &report["sourceSets"][index];
            assert_eq!(set["targetId"], target["targetId"]);
            for source in set["sourceIds"].as_array().unwrap() {
                assert!(source.as_str().unwrap().starts_with(&format!("t{index}:")));
            }
        }
        let expected_tests: Vec<_> = expected
            .as_array()
            .unwrap()
            .iter()
            .flat_map(|row| {
                row[3]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .map(|function| json!([row[1], function]))
            })
            .collect();
        if exit == 0 && expected_tests.is_empty() {
            for target in targets {
                assert_eq!(target["tests"], json!([]));
            }
            assert_eq!(report["aggregateEffects"]["expanded"], json!([]));
        }
        args.truncate(paths.len());
        args.push("--diagnostics=json");
        let executed = run(&dir, &args);
        assert_eq!(
            executed.exit, exit,
            "{} {}",
            executed.stdout, executed.stderr
        );
        let mut lines: Vec<Value> = executed
            .stdout
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(
            lines.pop().unwrap(),
            json!({"kind":"testSummary", "passed":expected_tests.len(), "failed":0, "filesNotRun":usize::from(exit != 0), "interrupted":false})
        );
        let actual_tests: Vec<_> = lines
            .iter()
            .map(|test| {
                assert_eq!(test["kind"], "test");
                assert_eq!(test["outcome"], "passed");
                json!([test["file"], test["function"]])
            })
            .collect();
        assert_eq!(actual_tests, expected_tests, "{paths:?}");
        args.push("--check");
        let checked = run(&dir, &args);
        assert_eq!(checked.exit, exit);
        assert_eq!(checked.stdout, "");
        assert_eq!(checked.stderr, executed.stderr);
    }
}

#[test]
fn check_keeps_diagnostics_and_checks_files_after_errors() {
    let dir = Directory::new("check-diagnostics");
    let first = dir.write(
        "first.bnt",
        "@test\nfunction first() -> Unit\n  return 1\nend function\n",
    );
    let second = dir.write(
        "second.bnt",
        "@test\nfunction second() -> Unit\n  return true\nend function\n",
    );
    for diagnostics in ["--diagnostics=text", "--diagnostics=json"] {
        let out = run(&dir, &["--check", diagnostics, &first, &second]);
        assert_eq!(out.exit, 2);
        assert_eq!(out.stdout, "");
        let individually = [&first, &second].map(|file| run(&dir, &["--check", diagnostics, file]));
        for result in &individually {
            assert_eq!(result.exit, 2);
            assert_eq!(result.stdout, "");
            assert!(result.stderr.contains("E0401"), "{}", result.stderr);
        }
        assert_eq!(
            out.stderr,
            format!("{}{}", individually[0].stderr, individually[1].stderr)
        );
    }
    let warning = dir.write(
        "warning.bnt",
        "@test\nfunction warns() -> Unit\n  bind _ <- 1 div 0\n  return ()\nend function\n",
    );
    for (deny, exit) in [(false, 0), (true, 2)] {
        let mut args = vec!["--check", "--diagnostics=json", &warning];
        if deny {
            args.push("--deny-warnings");
        }
        let out = run(&dir, &args);
        assert_eq!(out.exit, exit, "{}", out.stderr);
        assert_eq!(out.stdout, "");
        let diagnostics: Vec<serde_json::Value> = out
            .stderr
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(diagnostics.len(), 1, "{}", out.stderr);
        assert_eq!(diagnostics[0]["kind"], "check");
        assert_eq!(diagnostics[0]["code"], "W0401");
        assert_eq!(
            diagnostics[0]["severity"],
            if deny { "error" } else { "warning" }
        );
    }
}

#[test]
fn check_rejects_explicit_execution_options_even_at_their_defaults() {
    let dir = Directory::new("check-options");
    for (option, name) in [
        ("--max-call-stack=1GiB", "--max-call-stack"),
        ("--wasm-memory=64MiB", "--wasm-memory"),
        ("--wasm-fuel=10000000000", "--wasm-fuel"),
        ("--wasm-transfer=256MiB", "--wasm-transfer"),
        ("--wasm-stats", "--wasm-stats"),
    ] {
        for options in [["--check", option], [option, "--check"]] {
            let out = run(&dir, &[options[0], "missing.bnt", options[1]]);
            assert_eq!(out.exit, 2);
            assert_eq!(out.stdout, "");
            assert_eq!(
                out.stderr,
                format!(
                    "error: option `{name}` is not accepted with `test --check`\nrun `benitoite --help` for usage\n"
                )
            );
        }
    }
}

#[derive(Debug)]
struct InterruptAfterReads {
    reads: Arc<std::sync::atomic::AtomicUsize>,
    before: usize,
}

impl InterruptSource for InterruptAfterReads {
    fn requested(&self) -> bool {
        self.reads
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            >= self.before
    }
}

#[test]
fn check_observes_interrupts_only_before_each_file() {
    let dir = Directory::new("check-interrupt");
    let file = dir.write(
        "one.bnt",
        "@test\nfunction one() -> Unit\n  return ()\nend function\n",
    );
    for (before, exit, expected_reads) in [(0, 130, 1), (1, 130, 2), (2, 0, 2)] {
        let reads = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let out = run_with(
            &dir,
            &["--check", &file, &file],
            Box::new(InterruptAfterReads {
                reads: Arc::clone(&reads),
                before,
            }),
            ExecMode::Direct,
        );
        assert_eq!(out.exit, exit, "{}", out.stderr);
        assert_eq!(out.stdout, "");
        assert_eq!(out.stderr, "");
        assert_eq!(
            reads.load(std::sync::atomic::Ordering::Relaxed),
            expected_reads
        );
    }
}

// 関門: 読めないディレクトリはテストを一つも実行せず、E0101 を書いて終了状態 2。
#[cfg(unix)]
#[test]
fn an_unreadable_directory_runs_no_tests() {
    use std::os::unix::fs::PermissionsExt;
    let dir = Directory::new("unreadable");
    let good = dir.write(
        "good.bnt",
        "@test\nfunction fine() -> Unit\n  return ()\nend function\n",
    );
    dir.write(
        "locked/inner.bnt",
        "@test\nfunction hidden() -> Unit\n  return ()\nend function\n",
    );
    fs::set_permissions(dir.0.join("locked"), fs::Permissions::from_mode(0o000)).unwrap();
    if fs::read_dir(dir.0.join("locked")).is_ok() {
        // 権限を無視する利用者（root）では確かめられない。
        return;
    }
    let out = run(&dir, &[&good, &dir.path("locked")]);
    assert_eq!(out.exit, 2);
    assert_eq!(out.stdout, "");
    assert!(out.stderr.starts_with("error[E0101]"), "{}", out.stderr);
    assert!(out.stderr.contains("<dir>/locked"), "{}", out.stderr);
    for diagnostics in ["--diagnostics=text", "--diagnostics=json"] {
        let limited = run(
            &dir,
            &[diagnostics, "--allow-effects=", &good, &dir.path("locked")],
        );
        assert_eq!(limited.exit, 2, "{}", limited.stderr);
        assert_eq!(limited.stdout, "");
        assert!(limited.stderr.contains("E0101"), "{}", limited.stderr);
    }
    let unchecked = dir.write("unchecked.bnt", "invalid source\n");
    let inspected = run(&dir, &["--check", &unchecked, &good, &dir.path("locked")]);
    assert_eq!(inspected.exit, 2);
    assert_eq!(inspected.stdout, "");
    assert_eq!(inspected.stderr, out.stderr);
    let report = run(
        &dir,
        &[
            "--check",
            "--report=json",
            &unchecked,
            &good,
            &dir.path("locked"),
        ],
    );
    assert_eq!(report.exit, 2);
    assert_eq!(report.stderr, "");
    let report: serde_json::Value = serde_json::from_str(&report.stdout).unwrap();
    assert_eq!(report["status"], "checkError");
    assert_eq!(report["complete"], false);
    assert_eq!(report["targetsComplete"], false);
    assert_eq!(report["targets"].as_array().unwrap().len(), 2);
    assert_eq!(report["diagnostics"][0]["code"], "E0101");
    assert_eq!(
        report["diagnosticTargets"],
        serde_json::json!([{"diagnosticIndex":0,"targetId":null}])
    );
    assert_eq!(report["sources"], serde_json::json!([]));
    for target in report["targets"].as_array().unwrap() {
        assert_eq!(target["complete"], false);
        assert_eq!(target["tests"], serde_json::Value::Null);
        assert_eq!(target["processShellReference"], "unknown");
    }
    let (path, error) =
        cli::tools::test_runner::test_entries(&[PathBuf::from(good), dir.0.join("locked")])
            .unwrap_err();
    assert_eq!(path, dir.0.join("locked"));
    assert_eq!(error.kind(), std::io::ErrorKind::PermissionDenied);
}

/// 別のプロセスでの中断の要求（07-03「中断の要求のテスト（初回リリース版）」の最後の段落）。
#[cfg(unix)]
mod process_interrupt {
    use std::io::Read;
    use std::process::{Command, Stdio};
    use std::sync::mpsc;
    use std::thread;
    use std::time::{Duration, Instant};

    use super::Directory;

    const LIMIT: Duration = Duration::from_secs(30);

    // 前のテストの結果の行を準備の合図にし、次のテストが待つ間に SIGINT を送る。実時間の待ちで合図を作らない。
    #[test]
    fn sigint_stops_the_runner_with_the_interrupted_summary() {
        let dir = Directory::new("sigint");
        let file = dir.write(
            "wait.bnt",
            "import Benitoite.Unofficial.IO.Clock\n\n@test\nfunction first() -> Unit\n  return ()\nend function\n\n@test\nfunction waits() -> Unit uses Clock.Time\n  Clock.sleep(60000)\nend function\n\n@test\nfunction never() -> Unit\n  return ()\nend function\n",
        );
        for mode in ["direct", "request"] {
            let mut child = Command::new(env!("CARGO_BIN_EXE_benitoite"))
                .arg("test")
                .arg(&file)
                .current_dir(&dir.0)
                .env("BENITOITE_DEV_IO_MODE", mode)
                .env_remove("BENITOITE_DEV_PANIC")
                .env("NO_COLOR", "1")
                .stdin(Stdio::null())
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .unwrap();
            let mut out = child.stdout.take().unwrap();
            let (ready_send, ready) = mpsc::channel();
            let reader = thread::spawn(move || {
                let mut line = Vec::new();
                let mut byte = [0_u8; 1];
                while out.read(&mut byte).unwrap_or(0) != 0 {
                    line.extend_from_slice(&byte);
                    if byte[0] == b'\n' {
                        break;
                    }
                }
                let _sent = ready_send.send(line.clone());
                let mut rest = Vec::new();
                let _read = out.read_to_end(&mut rest);
                line.extend(rest);
                line
            });
            let first = ready.recv_timeout(LIMIT);
            let first = match first {
                Ok(line) => line,
                Err(error) => {
                    let _killed = child.kill();
                    panic!("{mode}: readiness did not arrive: {error}");
                }
            };
            assert_eq!(
                String::from_utf8_lossy(&first),
                format!("test {file}: first ... ok\n"),
                "{mode}"
            );
            let sent = Command::new("kill")
                .args(["-INT", &child.id().to_string()])
                .output()
                .unwrap();
            assert!(sent.status.success(), "{sent:?}");
            let started = Instant::now();
            let status = loop {
                if let Some(status) = child.try_wait().unwrap() {
                    break status;
                }
                if started.elapsed() > LIMIT {
                    let _killed = child.kill();
                    panic!("{mode}: runner did not stop after SIGINT");
                }
                thread::sleep(Duration::from_millis(2));
            };
            let stdout = String::from_utf8(reader.join().unwrap()).unwrap();
            let mut stderr = String::new();
            let _read = child.stderr.take().unwrap().read_to_string(&mut stderr);
            assert_eq!(status.code(), Some(130), "{mode}: {stderr}");
            assert_eq!(
                stdout,
                format!(
                    "test {file}: first ... ok\n\ntest result: FAILED. 1 passed; 0 failed; interrupted\n"
                ),
                "{mode}"
            );
        }
    }
}

// 関門: テスト行と失敗の見出しはパスを逃がす。JSON の file は元のパスを保つ。
#[cfg(unix)]
#[test]
fn result_lines_escape_file_names_only_in_text_output() {
    let dir = Directory::new("escaped-name");
    let file = dir.write("test\u{1b}[2J.bnt", "@test\nfunction fails() -> Result[Unit, String]\n  return Result.Error(\"failed\")\nend function\n");
    let out = run(&dir, &[&file]);
    assert_eq!(out.exit, 1, "{}", out.stderr);
    assert!(!out.stdout.contains('\u{1b}'), "{}", out.stdout);
    assert!(
        out.stdout
            .starts_with("test <dir>/test\\u{1B}[2J.bnt: fails ... FAILED\n"),
        "{}",
        out.stdout
    );
    assert!(
        out.stdout
            .contains("---- <dir>/test\\u{1B}[2J.bnt: fails ----\n"),
        "{}",
        out.stdout
    );
    let out = run(&dir, &["--diagnostics=json", &file]);
    assert_eq!(out.exit, 1, "{}", out.stderr);
    let test: serde_json::Value = serde_json::from_str(out.stdout.lines().next().unwrap()).unwrap();
    assert_eq!(test["file"], "<dir>/test\u{1b}[2J.bnt");
}

#[test]
fn directory_walk_skips_settings_and_nested_package_roots() {
    let dir = Directory::new("package-roots");
    dir.write("package.bnt", "language \"0.0.9\"\n");
    dir.write(
        "tests.bnt",
        "@test\nfunction rootTest() -> Unit\n()\nend function\n",
    );
    dir.write(
        "ordinary/checks.bnt",
        "@test\nfunction nestedTest() -> Unit\n()\nend function\n",
    );
    dir.write(
        "deps/textkit/package.bnt",
        "language \"0.0.9\"\npackage Textkit\nend package\n",
    );
    dir.write(
        "deps/textkit/tests.bnt",
        "@test\nfunction packageTest() -> Unit\n()\nend function\n",
    );
    dir.write("deps/textkit/deeper/Broken.bnt", "invalid source\n");
    let out = run(&dir, &[&dir.0.display().to_string()]);
    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert!(out.stderr.is_empty());
    assert!(out.stdout.contains("2 passed; 0 failed"), "{}", out.stdout);
    assert!(out.stdout.contains("rootTest"));
    assert!(out.stdout.contains("nestedTest"));
    assert!(!out.stdout.contains("packageTest"));
    let out = run(&dir, &[&dir.path("deps/textkit")]);
    assert_eq!(out.exit, 2);
    assert!(out.stdout.contains("packageTest"));
    assert!(out.stderr.contains("Broken.bnt"));
}

// 作成時の関門: test runner がソースの die を一件の失敗とし、次のテストを実行する。
// CLI run の検査では test の分類と捕捉出力の二重化に届かない。本物の入口だけを使う。
#[test]
fn die_source_fails_one_test_and_keeps_running() {
    let dir = Directory::new("die-source");
    let file = dir.write("die.bnt", "import Benitoite.Unofficial.IO.Process\n@test\nfunction dies() -> Unit uses Process.Exit\n bind value: Option[Unit] <- Option.None\n try value or die(\"test context\")\nend function\n@test\nfunction after() -> Unit\n ()\nend function\n");
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for json in [false, true] {
            let args = if json {
                vec!["--diagnostics=json", file.as_str()]
            } else {
                vec![file.as_str()]
            };
            let out = run_with(&dir, &args, Box::new(NoInterrupt), mode);
            assert_eq!(out.exit, 1, "{}\n{}", out.stdout, out.stderr);
            assert!(out.stderr.is_empty(), "{}", out.stderr);
            if json {
                let lines: Vec<serde_json::Value> = out
                    .stdout
                    .lines()
                    .map(|l| serde_json::from_str(l).unwrap())
                    .collect();
                assert_eq!(lines.len(), 3, "{}", out.stdout);
                assert_eq!(lines[0]["failure"]["reason"], "exit");
                assert_eq!(lines[0]["failure"]["exitCode"], 1);
                assert_eq!(lines[0]["failure"]["die"]["kind"], "die");
                assert_eq!(
                    lines[0]["failure"]["die"]["notes"],
                    serde_json::json!([
                        "message: test context",
                        "cause: expected a value, got Option.None"
                    ])
                );
                assert_eq!(lines[0]["stdout"], "");
                assert_eq!(lines[0]["stderr"], "");
                assert_eq!(lines[1]["function"], "after");
                assert_eq!(lines[1]["outcome"], "passed");
            } else {
                assert_eq!(
                    out.stdout.matches("error: explicit failure exit").count(),
                    1,
                    "{}",
                    out.stdout
                );
                assert!(
                    out.stdout.contains("message: test context"),
                    "{}",
                    out.stdout
                );
                assert!(
                    out.stdout
                        .contains("cause: expected a value, got Option.None"),
                    "{}",
                    out.stdout
                );
                assert!(out.stdout.contains("after ... ok"), "{}", out.stdout);
                assert!(
                    !out.stdout.contains("called `Process.exit`"),
                    "{}",
                    out.stdout
                );
            }
        }
    }
}

// 作成時の関門: 通常の test と文章の --check では観測できない、単一報告の
// 対象・契約・ソース・部分結果の対応を CLI 境界で守る。本番の差し込み口は加えない。
#[test]
fn check_report_preserves_contracts_descriptions_locations_and_source_identity() {
    use serde_json::json;
    let dir = Directory::new("report-contracts");
    let source = "@test\nfunction omitted() -> Unit uses Assert.Check\n  Assert.fail(\"must not run\")\nend function\n@test(\"\")\nfunction empty() -> Unit\nend function\n@test(\"description\")\nfunction described() -> Unit uses IO.All\nend function\n";
    let file = dir.write("tests.bnt", source);
    let out = run(
        &dir,
        &[
            "--check",
            "--report=json",
            "--diagnostics=json",
            &file,
            &file,
        ],
    );
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["schemaVersion"], 1);
    assert_eq!(report["kind"], "testCheckReport");
    assert_eq!(report["status"], "ok");
    assert_eq!(report["complete"], true);
    assert_eq!(report["targetsComplete"], true);
    assert_eq!(report["executed"], false);
    assert_eq!(report["targets"].as_array().unwrap().len(), 2);
    for index in 0..2 {
        let target = &report["targets"][index];
        assert_eq!(target["targetId"], format!("t{index}"));
        assert_eq!(target["requestIndex"], index);
        assert_eq!(target["kind"], "tests");
        assert_eq!(target["status"], "ok");
        assert_eq!(target["complete"], true);
        assert!(target.get("main").is_none());
        assert_eq!(target["processShellReference"], "absent");
        assert_eq!(target["shellReferenceScope"], "checkedProgram");
        let tests = target["tests"].as_array().unwrap();
        assert_eq!(tests.len(), 3);
        assert_eq!(tests[0]["function"], "omitted");
        assert_eq!(tests[0]["description"], serde_json::Value::Null);
        assert_eq!(tests[1]["description"], "");
        assert_eq!(tests[2]["description"], "description");
        assert_eq!(
            tests[0]["effects"],
            json!({"basis":"declaredUpperBound","expanded":["Assert.Check"]})
        );
        assert_eq!(tests[1]["effects"]["expanded"], json!([]));
        assert_eq!(
            tests[0]["location"],
            json!({"file":"<dir>/tests.bnt", "start":{"line":2,"column":10,"offset":15}, "end":{"line":2,"column":17,"offset":22}, "label":""})
        );
        let set = &report["sourceSets"][index];
        assert_eq!(set["targetId"], format!("t{index}"));
        let sources = report["sources"].as_array().unwrap();
        let entry_source = sources
            .iter()
            .find(|s| s["sourceId"] == target["sourceId"])
            .unwrap();
        assert_eq!(entry_source["contentHash"]["algorithm"], "sha256");
        assert_eq!(
            entry_source["contentHash"]["value"],
            "14c52fc2838594adb45ee1ec151457617d8e5ed2347dbb1ba70d6570ced86307"
        );
        assert!(
            set["sourceIds"]
                .as_array()
                .unwrap()
                .contains(&target["sourceId"])
        );
    }
    assert_eq!(
        report["aggregateEffects"],
        json!({"basis":"declaredUpperBound","expanded":["Assert.Check","Clock.Time","Console.Read","Console.Write","File.Read","File.Write","Process.Environment","Process.Exit","Process.Run","Random.Generate","State"]})
    );
    assert_eq!(report["diagnostics"].as_array().unwrap().len(), 2);
    for diagnostic in report["diagnostics"].as_array().unwrap() {
        assert_eq!(diagnostic["code"], "W0501");
        assert_eq!(diagnostic["severity"], "warning");
    }
    assert_eq!(
        report["diagnosticTargets"],
        json!([{"diagnosticIndex":0,"targetId":"t0"},{"diagnosticIndex":1,"targetId":"t1"}])
    );
}

#[test]
fn check_report_keeps_success_after_errors_and_diagnostic_indices() {
    use serde_json::json;
    let dir = Directory::new("report-partial");
    let bad = dir.write(
        "bad.bnt",
        "@test\nfunction bad() -> Unit\n  return 1\nend function\n",
    );
    let good = dir.write(
        "good.bnt",
        "@test\nfunction good() -> Unit uses Assert.Check\nend function\n",
    );
    let missing = dir.path("missing.bnt");
    let out = run(&dir, &["--check", "--report=json", &bad, &good, &missing]);
    assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["status"], "checkError");
    assert_eq!(report["targetsComplete"], true);
    assert_eq!(report["complete"], false);
    let targets = report["targets"].as_array().unwrap();
    assert_eq!(targets.len(), 3);
    assert_eq!(targets[0]["tests"], serde_json::Value::Null);
    assert_eq!(targets[0]["processShellReference"], "unknown");
    assert_eq!(targets[1]["tests"][0]["function"], "good");
    assert_eq!(targets[1]["complete"], true);
    assert_eq!(report["aggregateEffects"], serde_json::Value::Null);
    assert_eq!(report["diagnostics"][0]["code"], "E0401");
    assert_eq!(report["diagnostics"][1]["code"], "E0101");
    assert_eq!(
        report["diagnosticTargets"],
        json!([{"diagnosticIndex":0,"targetId":"t0"},{"diagnosticIndex":1,"targetId":"t2"}])
    );
}

#[test]
fn check_report_usage_errors_scan_options_in_both_orders() {
    let dir = Directory::new("report-usage");
    for (options, detail, json) in [
        (
            vec!["--report=json"],
            "`--report=json` requires `test --check`",
            true,
        ),
        (
            vec!["--check", "--diagnostics=text", "--report=json"],
            "`--report=json` cannot be combined with `--diagnostics=text`",
            true,
        ),
        (
            vec!["--check", "--report=json", "--diagnostics=text"],
            "`--report=json` cannot be combined with `--diagnostics=text`",
            true,
        ),
        (
            vec!["--bogus", "--report=json", "--check"],
            "unknown option `--bogus`",
            true,
        ),
        (
            vec!["--report=json", "--bogus", "--check"],
            "unknown option `--bogus`",
            true,
        ),
        (
            vec!["--report=json", "--check", "--report=json"],
            "option `--report` may only be specified once",
            true,
        ),
        (
            vec!["--check", "--report=text", "--report=json"],
            "invalid value `text` for `--report`",
            true,
        ),
        (
            vec!["--check", "--diagnostics", "--report=json"],
            "invalid value `` for `--diagnostics`",
            false,
        ),
        (
            vec!["--check", "--report", "--report=json"],
            "invalid value `` for `--report`",
            false,
        ),
        (
            vec!["--check", "--report=json", "--allow-effects="],
            "option `--allow-effects` is not accepted with `test --check`",
            true,
        ),
    ] {
        let mut args = options;
        args.push("missing.bnt");
        let out = run(&dir, &args);
        assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
        if json {
            assert_eq!(out.stderr, "");
            let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
            assert_eq!(report["kind"], "testCheckReport");
            assert_eq!(report["status"], "usageError");
            assert_eq!(report["targetsComplete"], false);
            assert_eq!(report["targets"], serde_json::json!([]));
            assert_eq!(
                report["requestedTargets"],
                serde_json::json!([{"requestIndex":0,"path":"missing.bnt"}])
            );
            assert_eq!(report["diagnostics"][0]["message"], detail);
            assert_eq!(report["diagnostics"][0]["code"], serde_json::Value::Null);
            assert_eq!(
                report["diagnosticTargets"],
                serde_json::json!([{"diagnosticIndex":0,"targetId":null}])
            );
        } else {
            assert_eq!(out.stdout, "");
            assert_eq!(
                out.stderr,
                format!("error: {detail}\nrun `benitoite --help` for usage\n")
            );
        }
    }
}

#[test]
fn check_report_keeps_completed_and_unstarted_targets_on_interrupt() {
    let dir = Directory::new("report-interrupt");
    let file = dir.write("one.bnt", "@test\nfunction one() -> Unit\nend function\n");
    for (before, exit, status, expected_reads) in [
        (0, 130, "interrupted", 1),
        (1, 130, "interrupted", 2),
        (2, 0, "ok", 2),
    ] {
        let reads = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let out = run_with(
            &dir,
            &["--check", "--report=json", &file, &file],
            Box::new(InterruptAfterReads {
                reads: Arc::clone(&reads),
                before,
            }),
            ExecMode::Direct,
        );
        assert_eq!(out.exit, exit, "{} {}", out.stdout, out.stderr);
        assert_eq!(out.stderr, "");
        assert_eq!(
            reads.load(std::sync::atomic::Ordering::Relaxed),
            expected_reads
        );
        let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
        assert_eq!(report["status"], status);
        assert_eq!(report["targetsComplete"], true);
        assert_eq!(report["complete"], exit == 0);
        assert_eq!(report["targets"].as_array().unwrap().len(), 2);
        for index in 0..2 {
            let target = &report["targets"][index];
            assert_eq!(target["complete"], index < before);
            assert_eq!(
                target["status"],
                if index < before { "ok" } else { "interrupted" }
            );
            if index < before {
                assert_eq!(target["tests"][0]["function"], "one");
            } else {
                assert_eq!(target["tests"], serde_json::Value::Null);
                assert_eq!(target["sourceId"], serde_json::Value::Null);
                assert_eq!(target["processShellReference"], "unknown");
                assert_eq!(
                    report["sourceSets"][index]["sourceIds"],
                    serde_json::json!([])
                );
            }
        }
        if exit == 130 {
            assert_eq!(report["aggregateEffects"], serde_json::Value::Null);
        }
    }
}

#[test]
fn check_report_preserves_warning_promotion_and_program_shell_scope() {
    let dir = Directory::new("report-warnings-shell");
    let warning = dir.write(
        "warning.bnt",
        "@test\nfunction warns() -> Unit\n  bind _ <- 1 div 0\nend function\n",
    );
    for (deny, exit, status, severity) in [
        (false, 0, "ok", "warning"),
        (true, 2, "checkError", "error"),
    ] {
        let mut args = vec!["--check", "--report=json", &warning];
        if deny {
            args.push("--deny-warnings");
        }
        let out = run(&dir, &args);
        assert_eq!(out.exit, exit, "{} {}", out.stdout, out.stderr);
        assert_eq!(out.stderr, "");
        let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
        assert_eq!(report["status"], status);
        assert_eq!(report["complete"], !deny);
        assert_eq!(report["diagnostics"].as_array().unwrap().len(), 1);
        assert_eq!(report["diagnostics"][0]["code"], "W0401");
        assert_eq!(report["diagnostics"][0]["severity"], severity);
        assert_eq!(report["targets"][0]["tests"].is_null(), deny);
        assert_eq!(report["aggregateEffects"].is_null(), deny);
    }
    let shell = dir.write("shell.bnt", "import Benitoite.Unofficial.IO.Process\nfunction unused() -> Result[Process.Output, IOError] uses Process.Run\n  return Process.shell(\"must not execute\")\nend function\n@test\nfunction pure() -> Unit\nend function\n");
    let out = run(&dir, &["--check", &shell, "--report=json"]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["targets"][0]["processShellReference"], "present");
    assert_eq!(
        report["targets"][0]["tests"][0]["effects"]["expanded"],
        serde_json::json!([])
    );
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        serde_json::json!([])
    );
}

// 関門: @test の未処理の Fail と、処理済みの非実行報告を CLI で区別する。
// 既存の IO の表は型付き Fail の脱落を検出せず、本番の差し込み口は不要である。
#[test]
fn failure_entry_contracts_are_checked_before_test_execution() {
    use serde_json::{Value, json};
    let dir = Directory::new("failure-entry");
    let rejected = dir.write("unhandled.bnt", "import Benitoite.Unofficial.Failure\n@test\nfunction unhandled() -> Unit uses Failure.Fail[String]\n  Failure.raise(\"stop\")\nend function\n");
    for options in [vec!["--diagnostics=json"], vec!["--check", "--report=json"]] {
        let mut args = options.clone();
        args.push(&rejected);
        let out = run(&dir, &args);
        assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
        if options.contains(&"--check") {
            let report: Value = serde_json::from_str(&out.stdout).unwrap();
            assert_eq!(report["schemaVersion"], 1);
            assert_eq!(report["kind"], "testCheckReport");
            assert_eq!(report["status"], "checkError");
            assert_eq!(report["executed"], false);
            assert_eq!(report["aggregateEffects"], Value::Null);
            assert_eq!(report["diagnostics"][0]["code"], "E0506");
            assert_eq!(
                report["diagnostics"][0]["helps"][1]["message"],
                "or convert the failure with Failure.toResult inside `unhandled`"
            );
            assert_eq!(out.stderr, "");
        } else {
            let summary: Value = serde_json::from_str(&out.stdout).unwrap();
            assert_eq!(summary["kind"], "testSummary");
            assert_eq!(summary["filesNotRun"], 1);
            assert_eq!(summary["passed"], 0);
            assert_eq!(summary["failed"], 0);
            let diagnostic: Value = serde_json::from_str(&out.stderr).unwrap();
            assert_eq!(diagnostic["code"], "E0506");
            assert_eq!(
                diagnostic["helps"][1]["message"],
                "or convert the failure with Failure.toResult inside `unhandled`"
            );
        }
    }
    let accepted = dir.write("handled.bnt", "import Benitoite.Unofficial.Failure\n@test\nfunction handled() -> Unit uses Assert.Check\n  bind result: Result[Unit, String] <- Failure.toResult(body: lambda() return Failure.raise(\"stop\") end lambda)\n  Assert.fail(\"must not execute\")\nend function\n");
    let out = run(&dir, &["--check", "--report=json", &accepted]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(out.stderr, "");
    let report: Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["schemaVersion"], 1);
    assert_eq!(report["kind"], "testCheckReport");
    assert_eq!(report["executed"], false);
    assert_eq!(
        report["targets"][0]["tests"][0]["effects"]["expanded"],
        json!(["Assert.Check"])
    );
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        json!(["Assert.Check"])
    );
    // 標準Failureのdocが増えても、利用者のtestへ再帰的に追加しない。
    let success = dir.write("handled-success.bnt", "import Benitoite.Unofficial.Failure\n@test\nfunction handled() -> Unit uses Assert.Check\n  bind result: Result[Unit, String] <- Failure.toResult(body: lambda() return Failure.raise(\"stop\") end lambda)\n  Assert.equal(actual: result, expected: Result.Error(\"stop\"))\nend function\n");
    let out = run(
        &dir,
        &[
            "--doc",
            "--diagnostics=json",
            "--allow-effects=Assert.Check",
            &success,
        ],
    );
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert!(out.stderr.is_empty(), "{}", out.stderr);
    let rows: Vec<Value> = out
        .stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(rows.len(), 3);
    assert_eq!(rows[0]["kind"], "test");
    assert_eq!(
        rows[1],
        json!({"kind": "docSummary", "test": 0, "run": 0, "check": 0, "error": 0, "ignoredBlocks": 0})
    );
    assert_eq!(rows[2]["kind"], "testSummary");
    assert_eq!(rows[2]["passed"], 1);
    assert_eq!(rows[2]["failed"], 0);
}

// 作成時の関門: property_library が守る入力と候補の規則と分け、
// 新しい通常のソースが @test 一件の結果と非実行の検査へ接続することを守る。
#[test]
fn property_results_use_ordinary_test_reports_and_check_never_runs_callbacks() {
    use serde_json::{Value, json};
    let dir = Directory::new("property");
    let file = dir.write(
        "property.bnt",
        r#"
import Benitoite.Unofficial.Test.Property
@test
function falsified() -> Result[Unit, String]
  bind result <- Property.check(config: Property.Config(seed: 17, trials: 1, size: 0, maxShrinks: 0, maxShrinkWork: 10000), gen: Property.constant(8), shrinker: Property.shrinkInteger(), property: lambda(value) return Result.Error("bad:" + Integer.toString(value)) end lambda)
  return match result with
    case Result.Ok(_) -> Result.Ok(())
    case Result.Error(failure) -> Result.Error(Property.formatFailure(failure: failure, show: lambda(value) return Integer.toString(value) end lambda))
  end match
end function
@test
function crashes() -> Unit
  bind result <- Property.check(config: Property.Config(seed: 0, trials: 1, size: 0, maxShrinks: 1, maxShrinkWork: 10000), gen: Property.Gen(run: lambda(generator, size) return Pair(1 div size, generator) end lambda), shrinker: Property.shrinkInteger(), property: lambda(value) return Result.Error("not reached") end lambda)
  return ()
end function
"#,
    );
    let inspected = run(&dir, &["--check", "--diagnostics=json", &file]);
    assert_eq!(inspected.exit, 0, "{}", inspected.stderr);
    assert!(inspected.stdout.is_empty());
    assert!(inspected.stderr.is_empty());
    let executed = run(&dir, &["--diagnostics=json", &file]);
    assert_eq!(executed.exit, 1, "{}", executed.stderr);
    assert!(executed.stderr.is_empty(), "{}", executed.stderr);
    let lines: Vec<Value> = executed
        .stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(lines.len(), 3, "{}", executed.stdout);
    assert_eq!(lines[0]["outcome"], "failed");
    assert_eq!(lines[0]["failure"]["reason"], "error");
    assert!(
        lines[0]["failure"]["message"]
            .as_str()
            .unwrap()
            .contains("original: 8\noriginal message: bad:8\nreduced: 8\nmessage: bad:8")
    );
    assert_eq!(lines[1]["outcome"], "failed");
    assert_eq!(lines[1]["failure"]["reason"], "runtime");
    assert_eq!(lines[1]["failure"]["code"], "R0101");
    assert_eq!(
        lines[2],
        json!({"kind":"testSummary","passed":0,"failed":2,"filesNotRun":0,"interrupted":false})
    );
}

#[test]
fn ordinary_test_does_not_parse_documentation_examples() {
    let dir = Directory::new("doc-not-selected");
    let path = dir.write("main.bnt", "/// ```benitoite unknown\n/// no closing fence or expectation\n@test\nfunction ordinary() -> Unit uses Assert.Check\n  Assert.equal(actual: 1, expected: 1)\nend function\n");
    let result = run(&dir, &[&path]);
    assert_eq!(result.exit, 0, "{}", result.stderr);
    assert!(result.stderr.is_empty(), "{}", result.stderr);
    assert!(
        result.stdout.contains("test result: ok. 1 passed"),
        "{}",
        result.stdout
    );
}

// 作成時の関門: 公開CLIで発見・検査・実行・報告の同じ一覧と独立した公開境界を守る。
// 通常testの試験ではdocを発見せず、抽出単体では実行抑止・許可・報告の退行を捕まえられない。
fn documentation(mode: &str, code: &str, expectation: Option<(&str, &str)>) -> String {
    let fence = "\x60\x60\x60";
    let mut body = format!("{fence}benitoite{mode}\n{code}{fence}\n");
    if let Some((kind, value)) = expectation {
        body.push_str(&format!("{fence}{kind}\n{value}{fence}\n"));
    }
    body.lines().map(|line| format!("//! {line}\n")).collect()
}

fn json_lines(out: &Outcome) -> Vec<serde_json::Value> {
    out.stdout
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect()
}

#[test]
fn doc_modes_share_discovery_and_version_two_reports() {
    let dir = Directory::new("doc-modes");
    let mut source = documentation(
        " test",
        "@test\nfunction first() -> Unit uses Assert.Check\n  Assert.equal(actual: 2, expected: 2)\nend function\n@test\nfunction second() -> Unit\n  return ()\nend function\n",
        None,
    );
    source.push_str(&documentation(" check",
        "import Benitoite.Unofficial.IO.Console\nfunction unused() -> Unit uses Console.Read\n  bind _ <- Console.readLine()\n  return ()\nend function\n", None));
    source.push_str(&documentation(
        " error",
        "function bad() -> Integer\n  return \"日本語\"\nend function\n",
        Some(("diagnostic", "E0401\n")),
    ));
    source.push_str(&documentation("",
        "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n  Console.writeLine(\"hello\")\nend function\n", Some(("output", "hello\n"))));
    source.push_str("//! \x60\x60\x60text\n//! skipped\n//! \x60\x60\x60\n");
    source.push_str("@test\nfunction ordinary() -> Unit\n  return ()\nend function\n");
    let file = dir.write("Docs.bnt", &source);
    let checked = run(&dir, &["--doc", "--check", "--report=json", &file]);
    assert_eq!(checked.exit, 0, "{} {}", checked.stdout, checked.stderr);
    assert_eq!(checked.stderr, "");
    let report: serde_json::Value = serde_json::from_str(&checked.stdout).unwrap();
    assert_eq!(report["schemaVersion"], 2);
    assert_eq!(report["complete"], true);
    assert_eq!(report["executed"], false);
    assert_eq!(
        report["aggregateEffects"]["expanded"],
        serde_json::json!(["Assert.Check", "Console.Write"])
    );
    assert_eq!(report["diagnostics"], serde_json::json!([]));
    let target = &report["targets"][0];
    assert_eq!(target["tests"].as_array().unwrap().len(), 1);
    assert_eq!(target["ignoredDocBlocks"], 1);
    let examples = target["docExamples"].as_array().unwrap();
    assert_eq!(
        examples
            .iter()
            .map(|e| e["mode"].as_str().unwrap())
            .collect::<Vec<_>>(),
        ["test", "check", "error", "run"]
    );
    assert_eq!(examples[0]["tests"].as_array().unwrap().len(), 2);
    assert_eq!(
        examples[0]["tests"][0]["location"]["file"],
        "<dir>/Docs.bnt"
    );
    assert_eq!(examples[2]["status"], "ok");
    assert_eq!(
        examples[2]["expectedDiagnosticCodes"],
        serde_json::json!(["E0401"])
    );
    assert!(
        examples[2]["observedDiagnostics"]
            .as_array()
            .unwrap()
            .iter()
            .any(|d| d["code"] == "E0401")
    );
    for example in examples {
        assert_eq!(example["complete"], true);
        assert!(
            report["sources"]
                .as_array()
                .unwrap()
                .iter()
                .any(|s| s["sourceId"] == example["sourceId"])
        );
    }
    let executed = run(
        &dir,
        &[
            "--doc",
            "--diagnostics=json",
            "--allow-effects=Assert.Check,Console.Write",
            &file,
        ],
    );
    assert_eq!(executed.exit, 0, "{} {}", executed.stdout, executed.stderr);
    assert_eq!(executed.stderr, "");
    let lines = json_lines(&executed);
    assert_eq!(
        lines
            .iter()
            .map(|line| line["kind"].as_str().unwrap())
            .collect::<Vec<_>>(),
        [
            "test",
            "docExample",
            "docExample",
            "docExample",
            "docExample",
            "docSummary",
            "testSummary"
        ]
    );
    assert_eq!(lines[1]["tests"].as_array().unwrap().len(), 2);
    assert_eq!(lines[4]["stdout"], "hello\n");
    assert_eq!(lines[4]["stderr"], "");
    assert_eq!(
        lines[5],
        serde_json::json!({"kind":"docSummary", "test":1, "run":1, "check":1, "error":1, "ignoredBlocks":1})
    );
    assert_eq!(lines[6]["passed"], 5);
    assert_eq!(lines[6]["failed"], 0);

    let ordinary = run(&dir, &["--check", "--report=json", &file]);
    let old: serde_json::Value = serde_json::from_str(&ordinary.stdout).unwrap();
    assert_eq!(old["schemaVersion"], 1);
    assert!(old["targets"][0].get("docExamples").is_none());
}

#[test]
fn doc_prepares_all_entries_and_limits_before_any_execution() {
    let dir = Directory::new("doc-preflight");
    let writes = "import Benitoite.Unofficial.IO.File\nfunction main() -> Unit uses File.Write\n  bind _ <- File.writeText(path: \"marker.txt\", text: \"ran\")\n  return ()\nend function\n";
    let good = dir.write(
        "First.bnt",
        &documentation("", writes, Some(("output", ""))),
    );
    let mut source = documentation("", writes, Some(("output", "")));
    source.push_str(&documentation("",
        "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n  Console.writeLine(\"late\")\nend function\n", Some(("output", "late\n"))));
    let late = dir.write("Later.bnt", &source);
    for args in [
        vec!["--doc", "--check", &good, &late],
        vec!["--doc", "--check", "--report=json", &good, &late],
    ] {
        let out = run(&dir, &args);
        assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
        assert!(!dir.0.join("marker.txt").exists());
        assert!(!out.stdout.contains("\"kind\":\"docExample\""));
        assert!(!out.stdout.contains("\"kind\":\"testSummary\""));
    }
    let denied = run(
        &dir,
        &[
            "--doc",
            "--allow-effects=File.Write",
            "--diagnostics=json",
            &good,
            &late,
        ],
    );
    assert_eq!(denied.exit, 2, "{} {}", denied.stdout, denied.stderr);
    assert!(denied.stderr.contains("E0512"), "{}", denied.stderr);
    assert!(denied.stderr.contains("Later.bnt"));
    assert!(!dir.0.join("marker.txt").exists());
    let lines = json_lines(&denied);
    assert_eq!(lines.len(), 1);
    assert_eq!(lines[0]["filesNotRun"], 2);
    assert_eq!(lines[0]["passed"], 0);

    let allowed = run(
        &dir,
        &[
            "--doc",
            "--allow-effects=File.Write,Console.Write",
            &good,
            &late,
        ],
    );
    assert_eq!(allowed.exit, 0, "{} {}", allowed.stdout, allowed.stderr);
    assert_eq!(fs::read_to_string(dir.0.join("marker.txt")).unwrap(), "ran");
}

#[test]
fn doc_examples_use_public_imports_without_inheriting_private_names() {
    let dir = Directory::new("doc-public");
    let declarations = "import Benitoite.Unofficial.IO.Console\n@opaque\npublic record Secret\n  value: Integer\nend record\nfunction hidden() -> Integer\n  return 3\nend function\npublic function visible() -> Integer\n  return hidden()\nend function\n";
    for (code, diagnostic) in [
        (
            "function f() -> Integer\n  return hidden()\nend function\n",
            "E0301",
        ),
        (
            "import Docs\nfunction f() -> Docs.Secret\n  return Docs.Secret(value: 1)\nend function\n",
            "E0340",
        ),
        (
            "function main() -> Unit uses Console.Write\n  Console.writeLine(\"no import\")\nend function\n",
            "E0332",
        ),
        (
            "import Docs\nfunction f() -> Integer\n  return Docs.hidden()\nend function\n",
            "E0330",
        ),
    ] {
        let file = dir.write(
            "Docs.bnt",
            &(documentation(
                " error",
                code,
                Some(("diagnostic", &format!("{diagnostic}\n"))),
            ) + declarations),
        );
        let out = run(&dir, &["--doc", "--diagnostics=json", &file]);
        assert_eq!(
            out.exit, 0,
            "{} {} for {diagnostic}",
            out.stdout, out.stderr
        );
        assert_eq!(json_lines(&out).last().unwrap()["passed"], 1);
    }
    let source = documentation(
        " test",
        "import Docs\n@test\nfunction api() -> Unit uses Assert.Check\n  Assert.equal(actual: Docs.visible(), expected: 3)\nend function\n",
        None,
    ) + declarations;
    let file = dir.write("Docs.bnt", &source);
    let out = run(&dir, &["--doc", &file]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
}

#[test]
fn doc_expectations_fail_per_example_and_keep_running() {
    let dir = Directory::new("doc-failures");
    let mut source = documentation(
        " error",
        "function bad() -> Integer\n  return \"wrong\"\nend function\n",
        Some(("diagnostic", "E0402\n")),
    );
    source.push_str(&documentation(" test", "@test\nfunction fails() -> Unit uses Assert.Check\n  Assert.fail(\"失敗\")\nend function\n", None));
    source.push_str(&documentation("", "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n  Console.writeLine(\"newline\")\nend function\n", Some(("output", ""))));
    source.push_str(&documentation(
        " check",
        "function good() -> Unit\n  return ()\nend function\n",
        None,
    ));
    let file = dir.write("Docs.bnt", &source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let out = run_with(
            &dir,
            &["--doc", "--diagnostics=json", &file],
            Box::new(NoInterrupt),
            mode,
        );
        assert_eq!(out.exit, 1, "{} {}", out.stdout, out.stderr);
        assert_eq!(out.stderr, "");
        let lines = json_lines(&out);
        assert_eq!(lines[0]["failure"]["reason"], "diagnosticMismatch");
        assert_eq!(
            lines[1]["tests"][0]["failure"]["primary"]["file"],
            "<dir>/Docs.bnt"
        );
        assert_eq!(lines[2]["failure"]["reason"], "outputMismatch");
        assert_eq!(lines[3]["outcome"], "ok");
        assert_eq!(lines.last().unwrap()["failed"], 3);
        assert_eq!(lines.last().unwrap()["passed"], 1);
    }
}

#[test]
fn doc_report_preserves_partial_unknowns_and_option_rejections() {
    let dir = Directory::new("doc-partial");
    let source = documentation(
        " check",
        "function bad() -> Integer\n  return \"wrong\"\nend function\n",
        None,
    ) + &documentation(
        " check",
        "function good() -> Unit\n  return ()\nend function\n",
        None,
    );
    let file = dir.write("Docs.bnt", &source);
    let out = run(&dir, &["--doc", "--check", "--report=json", &file]);
    assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
    let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["complete"], false);
    assert_eq!(report["aggregateEffects"], serde_json::Value::Null);
    assert_eq!(
        report["targets"][0]["docExamples"][0]["effects"],
        serde_json::Value::Null
    );
    assert_eq!(
        report["targets"][0]["docExamples"][0]["tests"],
        serde_json::Value::Null
    );
    assert_eq!(
        report["targets"][0]["docExamples"][1]["effects"]["expanded"],
        serde_json::json!([])
    );
    assert_eq!(
        report["targets"][0]["docExamples"][1]["tests"],
        serde_json::json!([])
    );
    assert_eq!(
        report["diagnosticTargets"][0]["docExampleId"],
        report["targets"][0]["docExamples"][0]["id"]
    );
    assert_eq!(
        report["diagnostics"][0]["primary"]["file"],
        "<dir>/Docs.bnt"
    );
    for args in [
        vec!["--doc", "--report=json", &file],
        vec![
            "--doc",
            "--check",
            "--report=json",
            "--allow-effects=",
            &file,
        ],
        vec!["--doc", "--doc", "--check", "--report=json", &file],
        vec![
            "--doc",
            "--check",
            "--report=json",
            "--max-call-stack=1MiB",
            &file,
        ],
    ] {
        let out = run(&dir, &args);
        assert_eq!(out.exit, 2);
        let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
        assert_eq!(report["schemaVersion"], 2);
        assert_eq!(report["status"], "usageError");
        assert_eq!(report["executed"], false);
    }
    let malformed = dir.write("Malformed.bnt", "//! \x60\x60\x60benitoite\n//! function main() -> Unit\n//!   return ()\n//! end function\n//! \x60\x60\x60\n");
    let out = run(&dir, &["--doc", "--check", "--report=json", &malformed]);
    assert_eq!(out.exit, 2);
    let report: serde_json::Value = serde_json::from_str(&out.stdout).unwrap();
    assert_eq!(report["diagnostics"][0]["code"], "E0260");
    assert_eq!(report["targets"][0]["docExamples"], serde_json::Value::Null);
}

// 元入口の環境だけを継承し、通常のimport境界・収集範囲・実行入口の制限を保つ。
#[test]
fn doc_inherits_headers_and_directory_root_without_recursing_into_imported_docs() {
    let dir = Directory::new("doc-environment");
    dir.write(
        "deps/words/package.bnt",
        "language \"0.0.9\"\npackage Words\nend package\n",
    );
    let imported_doc = documentation(
        " test",
        "@test\nfunction never() -> Unit uses Assert.Check\n  Assert.fail(\"imported docs must not run\")\nend function\n",
        None,
    );
    dir.write(
        "deps/words/Word.bnt",
        &(imported_doc.clone() + "public function number() -> Integer\n  return 7\nend function\n"),
    );
    let source = documentation(
        " test",
        "import Words.Word\n@test\nfunction number() -> Unit uses Assert.Check\n  Assert.equal(actual: Word.number(), expected: 7)\nend function\n",
        None,
    ) + "language \"0.0.9\"\ndependency Words\n  path \"deps/words\"\nend dependency\n";
    let file = dir.write("Docs.bnt", &source);
    let out = run(&dir, &["--doc", "--diagnostics=json", &file]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(json_lines(&out).last().unwrap()["passed"], 1);

    // ディレクトリ選択の共通の根とpackage.bntの依存も引き継ぐ。
    dir.write(
        "package.bnt",
        "language \"0.0.9\"\ndependency Words\n  path \"deps/words\"\nend dependency\n",
    );
    fs::remove_file(&file).unwrap();
    dir.write("nested/Docs.bnt", &documentation(" test", "import Words.Word\n@test\nfunction number() -> Unit uses Assert.Check\n  Assert.equal(actual: Word.number(), expected: 7)\nend function\n", None));
    let out = run(
        &dir,
        &["--doc", "--diagnostics=json", &dir.0.display().to_string()],
    );
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(json_lines(&out).last().unwrap()["passed"], 1);

    let source = documentation(" error", "import Entry\n", Some(("diagnostic", "E0320\n")))
        + "function main() -> Unit\n  return ()\nend function\n";
    let file = dir.write("Entry.bnt", &source);
    let out = run(&dir, &["--doc", "--diagnostics=json", &file]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(json_lines(&out).last().unwrap()["passed"], 1);
}

// runにも通常入口の効果制限を適用し、stderr省略を空という期待として扱う。
#[test]
fn doc_run_checks_unhandled_effects_and_exact_stderr() {
    let dir = Directory::new("doc-run-contract");
    let code = "import Benitoite.Unofficial.Failure\nfunction main() -> Unit uses Failure.Fail[String]\n  Failure.raise(\"unhandled\")\nend function\n";
    let file = dir.write("Docs.bnt", &documentation("", code, Some(("output", ""))));
    for options in [
        vec!["--doc", "--diagnostics=json", &file],
        vec!["--doc", "--check", "--report=json", &file],
    ] {
        let out = run(&dir, &options);
        assert_eq!(out.exit, 2, "{} {}", out.stdout, out.stderr);
        assert!(format!("{}{}", out.stdout, out.stderr).contains("E0506"));
    }
    let code = "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Console.Write\n  Console.writeErrorLine(\"diagnostic output\")\nend function\n";
    let source = documentation("", code, Some(("output", "")));
    let file = dir.write("Docs.bnt", &source);
    let out = run(&dir, &["--doc", "--diagnostics=json", &file]);
    assert_eq!(out.exit, 1);
    assert_eq!(json_lines(&out)[0]["stderr"], "diagnostic output\n");
    let source = source + "//! \x60\x60\x60stderr\n//! diagnostic output\n//! \x60\x60\x60\n";
    let file = dir.write("Docs.bnt", &source);
    let out = run(&dir, &["--doc", "--diagnostics=json", &file]);
    assert_eq!(out.exit, 0, "{} {}", out.stdout, out.stderr);
    assert_eq!(json_lines(&out)[0]["stderr"], "diagnostic output\n");
    assert_eq!(out.stderr, "");
}

// 作成時の関門: doc固有の失敗詳細・期待不一致の説明にも端末制御文字を出さない。
// 通常testの名前のエスケープのテストではdocの独立した報告経路に届かない。
#[test]
fn doc_text_reports_escape_control_characters_in_example_ids() {
    let dir = Directory::new("doc-terminal");
    let source = documentation(
        " error",
        "function bad() -> Integer\n  return \"wrong\"\nend function\n",
        Some(("diagnostic", "E0402\n")),
    );
    let file = dir.write("doc\u{1b}[2J.bnt", &source);
    for options in [vec!["--doc", &file], vec!["--doc", "--check", &file]] {
        let out = run(&dir, &options);
        assert_ne!(out.exit, 0);
        assert!(
            !out.stdout.contains('\u{1b}'),
            "{}",
            out.stdout.escape_debug()
        );
        assert!(
            !out.stderr.contains('\u{1b}'),
            "{}",
            out.stderr.escape_debug()
        );
        assert!(format!("{}{}", out.stdout, out.stderr).contains("doc\\u{1B}[2J.bnt"));
    }
}
