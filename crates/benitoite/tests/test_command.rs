//! `benitoite test` の CLI のテスト（設計書 06-01「`test` のコマンドライン（初回リリース版）」、06-04「テストの実行」
//! 「結果の報告」、10-18「結果の報告」、02-10「実行時エラーと資源の不足の報告」、実装プラン D11「受け入れテスト」）。
// テストの失敗は panic で表す（00-02「`#[allow]` を書いてよい箇所」）
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
  Assert.equal(1 + 2, 3)
end function

@test
function sumOfEmpty() -> Unit uses Assert.Check, Console.Write
  Console.writeLine("out line")
  Console.writeErrorLine("err line")
  Assert.equal(3, 4)
end function

@test
function truth() -> Unit uses Assert.Check
  Assert.isTrue(false, "should hold")
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

// 関門: 成功と失敗の混じったファイルの文章の形の全体（06-04「結果の報告」、10-18「文章の形」）。
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

// 関門: JSON Lines の項目と順（06-04「結果の報告」、10-18「JSON Lines の形」）。`"runtime"` は実行時エラーの報告の
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
            loc(13, 3, 21, offset("Assert.equal(3, 4)"))
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
        "@test\nfunction one() -> Unit uses Assert.Check\n  Assert.notEqual(1, 2)\nend function\n\n@test(\"second\")\nfunction two() -> Result[Unit, String]\n  return Result.Ok(())\nend function\n",
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
        "import Lib.Text\n\n@test\nfunction usesLib() -> Unit uses Assert.Check\n  Assert.equal(Text.message(), \"hello\")\nend function\n",
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
        "import Lib.Text\n\n@test\nfunction usesLib() -> Unit uses Assert.Check\n  Assert.equal(Text.message(), \"hello\")\nend function\n",
    );
    let out = run(&dir, &[&main]);
    assert_eq!(out.exit, 0, "{}", out.stderr);
    assert_eq!(
        out.stdout,
        "test <dir>/main_test.bnt: usesLib ... ok\n\ntest result: ok. 1 passed; 0 failed\n"
    );
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
        "test <dir>/good.bnt: fine ... ok\n\ntest result: FAILED. 1 passed; 0 failed; 1 files not run due to errors\n"
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
        "test result: FAILED. 0 passed; 0 failed; 1 files not run due to errors\n"
    );
}

#[test]
fn max_call_stack_limits_each_test() {
    let dir = Directory::new("stack");
    let file = dir.write(
        "deep.bnt",
        "function depth(n: Integer) -> Integer\n  if n = 0 then\n    return 0\n  end if\n  return 1 + depth(n - 1)\nend function\n\n@test\nfunction deep() -> Unit uses Assert.Check\n  Assert.equal(depth(1000), 1000)\nend function\n",
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
        "function awaitSaved(cell: Reference[Option[Task[Integer]]]) -> Integer uses State\n  return match Reference.get(cell) with\n    case Option.None -> awaitSaved(cell)\n    case Option.Some(task) -> Task.await(task)\n  end match\nend function\n\n@test\nfunction stuck() -> Unit uses State\n  bind saved: Reference[Option[Task[Integer]]] <- Reference.new(Option.None)\n  with group = TaskGroup.open() do\n    bind task <- TaskGroup.spawn(group, lambda() return awaitSaved(saved) end lambda)\n    Reference.set(saved, Option.Some(task))\n  end with\nend function\n",
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
}

#[test]
fn usage_errors_write_two_lines_and_exit_two() {
    let dir = Directory::new("usage");
    for (args, detail) in [
        (vec![], "missing path"),
        (
            vec!["--check", "a.bnt"],
            "option `--check` is not accepted by `test`",
        ),
    ] {
        let out = run(&dir, &args);
        assert_eq!(out.exit, 2);
        assert_eq!(out.stdout, "");
        assert_eq!(
            out.stderr,
            format!(
                "{}\n{}\n",
                cli::text::USAGE_ERROR.replace("{detail}", detail),
                cli::text::SEE_HELP
            )
        );
    }
}

// 関門: 読めないディレクトリはテストを一つも実行せず、E0101 を書いて終了状態 2（10-18「ファイルごとの手順」の 1）。
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
