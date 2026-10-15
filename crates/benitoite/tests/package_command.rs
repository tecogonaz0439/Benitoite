//! パッケージの CLI の出力・終了状態・書き換えの結果（設計書 06-01「`package` のコマンドライン」、06-09「`benitoite package`」）。
// 関門: 実際のファイルとプロセスで命令の契約を確かめる。既存の fmt の検査は依存の検証を扱わない。
// 固定のハッシュは sha256sum と同じ要約を Python の hashlib で独立して計算した。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
const CONFIG: &str = "language \"0.0.5\"\n\npackage Words\nend package\n";
const MAIN: &str = "function main() -> Unit\n  ()\nend function\n";
const READ: &str = "import Benitoite.Unofficial.IO.File\n\npublic function read() -> Unit uses File.Read\n  ()\nend function\n";
struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = Path::new(env!("CARGO_TARGET_TMPDIR"));
        fs::create_dir_all(root).unwrap();
        // 同時に始まったテストの時刻が同じでも、作成済みのディレクトリを共有しない。
        for attempt in 0..100 {
            let path = root.join(format!(
                "package-command-{}-{stamp}-{attempt}",
                std::process::id()
            ));
            match fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => panic!("cannot create test directory: {error}"),
            }
        }
        panic!("cannot find an unused test directory")
    }
    fn write(&self, path: &str, source: &str) {
        let path = self.0.join(path);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, source).unwrap();
    }
    fn read(&self, path: &str) -> String {
        fs::read_to_string(self.0.join(path)).unwrap()
    }
    fn command(&self, args: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_benitoite"))
            .current_dir(&self.0)
            .env_remove("BENITOITE_DEV_PANIC")
            .env_remove("BENITOITE_DEV_IO_MODE")
            .args(args)
            .output()
            .unwrap()
    }
    fn package(&self, args: &[&str]) -> Output {
        let mut full = vec!["package"];
        full.extend(args);
        self.command(&full)
    }
    fn fixture(&self) {
        self.write("main.bnt", MAIN);
        self.write("deps/words/package.bnt", CONFIG);
        self.write("deps/words/Value.bnt", READ);
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _result = fs::remove_dir_all(&self.0);
    }
}
fn success(output: &Output) {
    assert_eq!(
        output.status.code(),
        Some(0),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(
        output.stderr.is_empty(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
}
fn error(output: &Output, code: &str) {
    assert_eq!(
        output.status.code(),
        Some(2),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(
        String::from_utf8_lossy(&output.stderr).contains(code),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(output.stdout.is_empty());
}
fn stdout(output: &Output) -> String {
    String::from_utf8(output.stdout.clone()).unwrap()
}
// spec: 06-09 `benitoite package`
#[test]
fn add_and_update_record_hashes_effect_deltas_and_unchanged_state() {
    let dir = Directory::new();
    dir.fixture();
    let add = dir.package(&["add", "Text", "--path", "deps/words"]);
    success(&add);
    let hash = "sha256:eee08f30ef130c609237874eefd93d59e3338d58438294fb47dc24ec917cef4e";
    assert!(stdout(&add).starts_with("added dependency Text (package Words) to "));
    assert!(stdout(&add).ends_with(&format!(
        "  hash: {hash}\n  effects: File.Read\n  components: (none)\n"
    )));
    assert_eq!(
        dir.read("main.bnt"),
        format!(
            "dependency Text\n  path \"deps/words\"\n  hash \"{hash}\"\n  effects \"File.Read\"\nend dependency\n\n{MAIN}"
        )
    );
    let modified_before = fs::metadata(dir.0.join("main.bnt"))
        .unwrap()
        .modified()
        .unwrap();
    let unchanged = dir.package(&["update"]);
    success(&unchanged);
    assert!(stdout(&unchanged).starts_with("unchanged dependency Text"));
    assert_eq!(
        fs::metadata(dir.0.join("main.bnt"))
            .unwrap()
            .modified()
            .unwrap(),
        modified_before
    );
    let modified = READ.replace("File.Read", "File.Write");
    dir.write("deps/words/Value.bnt", &modified);
    let update = dir.package(&["update", "Text"]);
    success(&update);
    assert!(stdout(&update).contains("  effects: + File.Write\n           - File.Read\n"));
    assert!(dir.read("main.bnt").contains("effects \"File.Write\""));
    success(&dir.command(&["check", "main.bnt"]));
}

// spec: 06-09 `benitoite package`
#[test]
fn config_destination_root_only_and_unhashed_dependencies() {
    for entry in [false, true] {
        let dir = Directory::new();
        dir.fixture();
        if !entry {
            fs::remove_file(dir.0.join("main.bnt")).unwrap();
        }
        dir.write("package.bnt", "// config\n");
        let absolute = dir.0.join("deps/words");
        let path = if entry {
            absolute.to_str().unwrap()
        } else {
            "deps/words"
        };
        let output = dir.package(&["add", "Text", "--path", path, "package.bnt"]);
        success(&output);
        assert!(dir.read("package.bnt").contains("dependency Text"));
        if entry {
            assert_eq!(dir.read("main.bnt"), MAIN);
        }
    }
    let dir = Directory::new();
    dir.fixture();
    let source = format!("dependency Text\n  path \"deps/words\"\nend dependency\n\n{MAIN}");
    dir.write("main.bnt", &source);
    let output = dir.package(&["update"]);
    success(&output);
    assert_eq!(stdout(&output), "no dependencies with hash to update\n");
    assert_eq!(dir.read("main.bnt"), source);
    let output = dir.package(&["update", "Text"]);
    success(&output);
    assert!(stdout(&output).contains("(not recorded) -> File.Read"));
    assert!(dir.read("main.bnt").contains("  hash \"sha256:"));
}

// spec: 06-09 `benitoite package`
#[test]
fn move_preserves_check_results_and_rolls_back_when_entry_is_read_only() {
    use std::os::unix::fs::PermissionsExt;
    let dir = Directory::new();
    dir.fixture();
    let source = format!(
        "//! main\n\n// version\nlanguage \"0.0.5\" // keep\n\ndependency Text\n  path \"deps/words\"\nend dependency\n\n{MAIN}"
    );
    dir.write("main.bnt", &source);
    success(&dir.command(&["check", "main.bnt"]));
    fs::set_permissions(dir.0.join("main.bnt"), fs::Permissions::from_mode(0o755)).unwrap();
    let output = dir.package(&["move", "main.bnt"]);
    success(&output);
    assert!(stdout(&output).contains("moved language, dependency Text from "));
    assert_eq!(
        fs::metadata(dir.0.join("package.bnt"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o644
    );
    assert_eq!(
        fs::metadata(dir.0.join("main.bnt"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o755
    );
    assert_eq!(dir.read("main.bnt"), format!("//! main\n\n{MAIN}"));
    assert_eq!(
        dir.read("package.bnt"),
        "// version\nlanguage \"0.0.5\" // keep\n\ndependency Text\n  path \"deps/words\"\nend dependency\n"
    );
    success(&dir.command(&["check", "main.bnt"]));
    for existing in [false, true] {
        dir.write("main.bnt", &source);
        fs::remove_file(dir.0.join("package.bnt")).unwrap();
        if existing {
            dir.write("package.bnt", "// existing\n");
        }
        fs::set_permissions(dir.0.join("main.bnt"), fs::Permissions::from_mode(0o444)).unwrap();
        error(&dir.package(&["move", "main.bnt"]), "E0126");
        assert_eq!(dir.read("main.bnt"), source);
        if existing {
            assert_eq!(dir.read("package.bnt"), "// existing\n");
        } else {
            assert!(!dir.0.join("package.bnt").exists());
            dir.write("package.bnt", "");
        }
        fs::set_permissions(dir.0.join("main.bnt"), fs::Permissions::from_mode(0o644)).unwrap();
    }
}

// spec: 06-09 `benitoite package`
#[test]
fn rejected_commands_do_not_write_files_and_support_json_diagnostics() {
    for (command, source, config, expected) in [
        (
            vec!["add", "Text", "--path=deps/words"],
            format!("dependency Text\npath \"deps/words\"\nend dependency\n{MAIN}"),
            None,
            "E0923",
        ),
        (
            vec!["add", "Text", "--path=missing"],
            MAIN.into(),
            None,
            "E0916",
        ),
        (
            vec!["add", "Text", "--path=empty"],
            MAIN.into(),
            None,
            "E0917",
        ),
        (vec!["add", "Text", "--path=."], MAIN.into(), None, "E0922"),
        (
            vec!["add", "Text", "--path=deps/words"],
            "function main( -> Unit\nend function\n".into(),
            None,
            "E0201",
        ),
        (vec!["update", "Absent"], MAIN.into(), None, "E0924"),
        (vec!["move", "main.bnt"], MAIN.into(), None, "E0925"),
        (
            vec!["move", "main.bnt"],
            format!("language \"0.0.5\"\n{MAIN}"),
            Some("language \"0.0.5\"\n"),
            "E0926",
        ),
    ] {
        let dir = Directory::new();
        dir.fixture();
        fs::create_dir(dir.0.join("empty")).unwrap();
        dir.write("main.bnt", &source);
        if let Some(config) = config {
            dir.write("package.bnt", config);
        }
        let mut args = command;
        args.push("--diagnostics=json");
        let output = dir.package(&args);
        error(&output, expected);
        for line in String::from_utf8_lossy(&output.stderr).lines() {
            let _: serde_json::Value = serde_json::from_str(line).unwrap();
        }
        assert_eq!(dir.read("main.bnt"), source);
        if let Some(config) = config {
            assert_eq!(dir.read("package.bnt"), config);
        }
    }
}

// spec: 06-09 `benitoite package`
#[test]
fn components_are_reported_and_invalid_components_do_not_prevent_add() {
    let dir = Directory::new();
    dir.fixture();
    dir.write("deps/words/Value.bnt", "@external(\"wasm\", \"wasm/fuzzy.wasm\", \"distance\")\npublic function distance(a: String, b: String) -> Integer\n");
    fs::create_dir_all(dir.0.join("deps/words/wasm")).unwrap();
    fs::write(
        dir.0.join("deps/words/wasm/fuzzy.wasm"),
        include_bytes!("../testdata/packages/libraries.files/fuzzy/wasm/fuzzy.wasm"),
    )
    .unwrap();
    let output = dir.package(&["add", "Text", "--path=deps/words"]);
    success(&output);
    assert!(
        stdout(&output).contains("  effects: (none)\n  components: wasm/fuzzy.wasm (no imports)\n")
    );
    dir.write("deps/words/wasm/fuzzy.wasm", "broken");
    let output = dir.package(&["update"]);
    success(&output);
    assert!(stdout(&output).contains("wasm/fuzzy.wasm: not a WebAssembly component"));
}

// spec: 06-09 `benitoite package`
#[test]
fn package_syntax_errors_and_hash_errors_abort_updates_atomically() {
    let dir = Directory::new();
    dir.fixture();
    success(&dir.package(&["add", "Text", "--path=deps/words"]));
    let before = dir.read("main.bnt");
    dir.write(
        "deps/words/Unimported.bnt",
        "function broken( -> Unit\nend function\n",
    );
    error(&dir.package(&["update"]), "E0201");
    assert_eq!(dir.read("main.bnt"), before);
    fs::remove_file(dir.0.join("deps/words/Unimported.bnt")).unwrap();
    std::os::unix::fs::symlink("Value.bnt", dir.0.join("deps/words/ignored.txt")).unwrap();
    error(&dir.package(&["update"]), "E0920");
    assert_eq!(dir.read("main.bnt"), before);
}

// spec: 06-09 `benitoite package`
#[test]
fn adding_to_existing_headers_ignores_unrelated_import_errors_and_bulk_updates_are_atomic() {
    let dir = Directory::new();
    dir.fixture();
    dir.write(
        "main.bnt",
        &format!("//! script\n\nimport Absent\n\n{MAIN}"),
    );
    success(&dir.package(&["add", "Text", "--path=deps/words"]));
    dir.write("deps/other/package.bnt", CONFIG);
    dir.write("deps/other/Value.bnt", READ);
    let output = dir.package(&["add", "Extra", "--path=deps/other", "./main.bnt"]);
    success(&output);
    let before = dir.read("main.bnt");
    assert!(before.ends_with(&format!("import Absent\n\n{MAIN}")));
    assert_eq!(before.matches("dependency Text").count(), 1);
    assert_eq!(before.matches("dependency Extra").count(), 1);
    error(
        &dir.package(&["add", "Overlap", "--path=deps/words"]),
        "E0922",
    );
    dir.write(
        "deps/words/Value.bnt",
        &READ.replace("File.Read", "File.Write"),
    );
    dir.write(
        "deps/other/Broken.bnt",
        "function broken( -> Unit\nend function\n",
    );
    error(&dir.package(&["update"]), "E0201");
    assert_eq!(dir.read("main.bnt"), before);
    fs::remove_file(dir.0.join("deps/other/Broken.bnt")).unwrap();
    success(&dir.package(&["update", "./main.bnt"]));
    assert!(dir.read("main.bnt").contains("effects \"File.Write\""));
}

// spec: 06-09 `benitoite package`
#[test]
fn command_preconditions_reject_unwritable_or_missing_destinations_and_package_dependencies() {
    use std::os::unix::fs::PermissionsExt;
    let dir = Directory::new();
    dir.fixture();
    fs::set_permissions(dir.0.join("main.bnt"), fs::Permissions::from_mode(0o444)).unwrap();
    error(&dir.package(&["add", "Text", "--path=deps/words"]), "E0126");
    assert_eq!(dir.read("main.bnt"), MAIN);
    fs::set_permissions(dir.0.join("main.bnt"), fs::Permissions::from_mode(0o644)).unwrap();
    fs::remove_file(dir.0.join("main.bnt")).unwrap();
    error(&dir.package(&["add", "Text", "--path=deps/words"]), "E0927");
    dir.write("package.bnt", CONFIG);
    dir.write("main.bnt", MAIN);
    error(&dir.package(&["add", "Text", "--path=deps/words"]), "E0915");
    assert_eq!(dir.read("package.bnt"), CONFIG);
    error(&dir.package(&["move", "package.bnt"]), "E0928");
    dir.write("package.bnt", "package Words\nend package\n");
    dir.write(
        "main.bnt",
        &format!(
            "language \"0.0.5\"\n\ndependency Text\n  path \"deps/words\"\nend dependency\n\n{MAIN}"
        ),
    );
    error(&dir.package(&["move", "main.bnt"]), "E0915");
    assert_eq!(dir.read("package.bnt"), "package Words\nend package\n");
    dir.write("main.bnt", &format!("language \"0.0.5\"\n\n{MAIN}"));
    success(&dir.package(&["move", "main.bnt"]));
    assert!(dir.read("package.bnt").contains("language \"0.0.5\""));
}

// spec: 06-01 `package` のコマンドライン
#[test]
fn usage_errors_and_terminal_controls_do_not_change_other_files() {
    let dir = Directory::new();
    dir.fixture();
    for args in [
        vec!["add", "Text"],
        vec!["move"],
        vec!["update", "Text", "one", "two"],
        vec!["add", "Text", "--path"],
        vec!["update", "--unknown"],
    ] {
        let output = dir.package(&args);
        error(&output, "run `benitoite --help` for usage");
        assert_eq!(dir.read("main.bnt"), MAIN);
    }
    use std::os::unix::ffi::OsStringExt;
    let output = Command::new(env!("CARGO_BIN_EXE_benitoite"))
        .current_dir(&dir.0)
        .args(["package", "add", "Text", "--path"])
        .arg(std::ffi::OsString::from_vec(vec![255]))
        .output()
        .unwrap();
    error(&output, "valid UTF-8");
    assert_eq!(dir.read("main.bnt"), MAIN);
    dir.write("odd\n.bnt", MAIN);
    let output = dir.package(&["add", "Text", "--path=deps/words", "odd\n.bnt"]);
    success(&output);
    assert_eq!(stdout(&output).lines().count(), 4);
    assert_eq!(dir.read("main.bnt"), MAIN);
}

// 関門: コメントだけの設定への移動は既存の設定ありの経路と異なるため、バイト列を確かめる。
// spec: 06-09 `benitoite package`
#[test]
fn move_appends_to_comment_only_config_without_reformatting_comments() {
    for comments in [
        "\u{feff}  // first  \r\n\t// second\r\n",
        "// no final newline  ",
    ] {
        let dir = Directory::new();
        dir.fixture();
        dir.write("main.bnt", &format!("language \"0.0.5\"\n\n{MAIN}"));
        dir.write("package.bnt", comments);
        success(&dir.package(&["move", "main.bnt"]));
        let nl = if comments.contains("\r\n") {
            "\r\n"
        } else {
            "\n"
        };
        assert_eq!(
            dir.read("package.bnt"),
            format!(
                "{}{nl}{nl}language \"0.0.5\"{nl}",
                comments.trim_end_matches(['\r', '\n'])
            )
        );
        assert_eq!(dir.read("main.bnt"), MAIN);
        success(&dir.command(&["check", "main.bnt"]));
    }
}

// 関門: 欄の形を拒否する通常の検査を通しつつ、更新では修正して書ける契約を守る。
// spec: 06-09 `benitoite package`
#[test]
fn update_repairs_malformed_effects_and_reports_unknown_previous_contract() {
    let dir = Directory::new();
    dir.fixture();
    dir.write("main.bnt", &format!("dependency Text\n  path \"deps/words\"\n  effects \"file.read\"\nend dependency\n\n{MAIN}"));
    error(&dir.command(&["check", "main.bnt"]), "E0929");
    let result = dir.package(&["update", "Text"]);
    success(&result);
    assert!(stdout(&result).contains("(not recorded) -> File.Read"));
    assert!(dir.read("main.bnt").contains("effects \"File.Read\""));
    success(&dir.command(&["check", "main.bnt"]));
}

// 関門: 対象外の設定の失敗は追加を止めず、対象の設定の誤りは仮の編集として報告する。
// spec: 06-09 `benitoite package`
#[test]
fn add_validates_only_the_target_dependency_config_and_marks_proposed_locations() {
    let dir = Directory::new();
    dir.fixture();
    dir.write("deps/other/package.bnt", "package Other\nend package\n");
    dir.write(
        "main.bnt",
        &format!("dependency Other\n  path \"deps/other\"\nend dependency\n\n{MAIN}"),
    );
    success(&dir.package(&["add", "Text", "--path", "deps/words"]));
    let before = dir.read("main.bnt");
    let output = dir.package(&["add", "Missing", "--path", "missing"]);
    error(&output, "E0916");
    assert!(String::from_utf8_lossy(&output.stderr).contains("proposed edit, not written"));
    assert_eq!(dir.read("main.bnt"), before);

    // 同じ依存でもパスの綴りで設定の診断を見落とすため、追加と更新の両方を確かめる。
    let absolute = dir.0.join("deps/words");
    std::os::unix::fs::symlink("deps/words", dir.0.join("words-link")).unwrap();
    dir.write("deps/words/package.bnt", "package Words\nend package\n");
    for path in [
        "deps/words",
        "./deps/../deps/words",
        absolute.to_str().unwrap(),
        "words-link",
    ] {
        dir.write("main.bnt", MAIN);
        error(&dir.package(&["add", "Text", "--path", path]), "E0914");
        assert_eq!(dir.read("main.bnt"), MAIN);
        let source = format!("dependency Text\n  path \"{path}\"\nend dependency\n\n{MAIN}");
        dir.write("main.bnt", &source);
        error(&dir.package(&["update", "Text"]), "E0914");
        assert_eq!(dir.read("main.bnt"), source);
    }
}

// 関門: 明示した設定がない場合に別のファイルを書かず、ディレクトリの move は使い方を示す。
// spec: 06-01 `package` のコマンドライン
#[test]
fn explicit_missing_config_and_directory_move_do_not_edit_the_entry() {
    let dir = Directory::new();
    dir.fixture();
    let missing = dir.package(&["add", "Text", "--path", "deps/words", "package.bnt"]);
    error(&missing, "E0101");
    let reason = fs::metadata(dir.0.join("package.bnt"))
        .unwrap_err()
        .to_string();
    assert!(String::from_utf8_lossy(&missing.stderr).contains(&format!("note: {reason}")));
    let output = dir.package(&["move", "."]);
    assert_eq!(output.status.code(), Some(2));
    assert!(String::from_utf8_lossy(&output.stderr).contains("a file, not a directory"));
    assert_eq!(dir.read("main.bnt"), MAIN);
    assert!(!dir.0.join("package.bnt").exists());
}
