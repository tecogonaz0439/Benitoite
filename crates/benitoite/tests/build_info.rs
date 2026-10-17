//! 実際の Cargo ビルドで埋め込み値と入力の拒否を確かめる（設計書 05-01「ソースからのビルド」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::{
    ffi::{OsStr, OsString},
    fs,
    path::{Path, PathBuf},
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};

const COMMIT: &str = "BENITOITE_BUILD_COMMIT";
const DIRTY: &str = "BENITOITE_BUILD_DIRTY";
const HEX40: &str = "ABCDEF0123456789ABCDEF0123456789ABCDEF01";
const LOWER40: &str = "abcdef0123456789abcdef0123456789abcdef01";
const HEX64: &str = "ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789";
const LOWER64: &str = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
const MAIN: &str = r#"fn main() {
    println!("{}\n{}\n{}\n{}\n{}",
        env!("BENITOITE_EMBEDDED_BUILD_COMMIT"),
        env!("BENITOITE_EMBEDDED_BUILD_DIRTY"),
        env!("BENITOITE_EMBEDDED_BUILD_TARGET"),
        env!("BENITOITE_EMBEDDED_COMMIT_PROVENANCE"),
        env!("BENITOITE_EMBEDDED_DIRTY_PROVENANCE"));
}
"#;

struct Fixture {
    root: PathBuf,
    cargo: PathBuf,
    rustc: PathBuf,
    target: String,
    path: Option<OsString>,
}

impl Fixture {
    fn new() -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let mut root = None;
        for attempt in 0..100 {
            let candidate = std::env::temp_dir().join(format!(
                "benitoite-build-info-{}-{stamp}-{attempt}",
                std::process::id()
            ));
            match fs::create_dir(&candidate) {
                Ok(()) => {
                    root = Some(candidate.canonicalize().unwrap());
                    break;
                }
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => panic!("cannot create fixture: {error}"),
            }
        }
        let root = root.expect("unused temporary directory");
        // rustup の代理実行ファイルを子へ渡さず、現在選択されている実体を固定する。
        let sysroot = successful(
            Command::new("rustc")
                .args(["--print", "sysroot"])
                .output()
                .unwrap(),
        );
        let bin = Path::new(sysroot.trim()).join("bin");
        let rustc = bin.join(format!("rustc{}", std::env::consts::EXE_SUFFIX));
        let cargo = bin.join(format!("cargo{}", std::env::consts::EXE_SUFFIX));
        let version = successful(Command::new(&rustc).arg("-vV").output().unwrap());
        let target = version
            .lines()
            .find_map(|line| line.strip_prefix("host: "))
            .unwrap()
            .to_owned();
        let fixture = Self {
            root,
            cargo,
            rustc,
            target,
            path: None,
        };
        fixture.write(
            "Cargo.toml",
            "[workspace]\nmembers = [\"crates/benitoite\"]\nresolver = \"3\"\n",
        );
        fixture.write(
            "crates/benitoite/Cargo.toml",
            "[package]\nname = \"build-info-probe\"\nversion = \"0.0.0\"\nedition = \"2024\"\n",
        );
        fixture.write("crates/benitoite/src/main.rs", MAIN);
        fixture.write("crates/benitoite/build.rs", include_str!("../build.rs"));
        fixture.git(&["init", "--initial-branch=main"]);
        for (key, value) in [
            ("user.name", "Build Info Test"),
            ("user.email", "build-info@example.invalid"),
            ("commit.gpgsign", "false"),
            ("core.hooksPath", "/dev/null"),
            ("core.fsmonitor", "false"),
            ("core.autocrlf", "false"),
        ] {
            fixture.git(&["config", "--local", key, value]);
        }
        fixture.git(&["add", "Cargo.toml", "crates"]);
        fixture.git(&["commit", "-m", "fixture"]);
        fixture
    }

    fn write(&self, path: &str, value: &str) {
        let path = self.root.join(path);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, value).unwrap();
    }

    fn environment(&self, command: &mut Command) {
        command
            .current_dir(&self.root)
            .env("GIT_CONFIG_GLOBAL", "/dev/null")
            .env("GIT_CONFIG_NOSYSTEM", "1");
        for name in [
            "GIT_DIR",
            "GIT_WORK_TREE",
            "GIT_COMMON_DIR",
            "GIT_INDEX_FILE",
            "GIT_OBJECT_DIRECTORY",
            "GIT_ALTERNATE_OBJECT_DIRECTORIES",
            "GIT_CONFIG_COUNT",
            "GIT_CONFIG_PARAMETERS",
            "GIT_TRACE",
        ] {
            command.env_remove(name);
        }
    }

    fn git(&self, args: &[&str]) -> String {
        let mut command = Command::new("git");
        self.environment(&mut command);
        successful(
            command
                .args(["--no-optional-locks", "-c", "core.fsmonitor=false"])
                .args(args)
                .output()
                .unwrap(),
        )
    }

    fn build(&self, commit: Option<&OsStr>, dirty: Option<&OsStr>) -> Output {
        let mut command = Command::new(&self.cargo);
        self.environment(&mut command);
        command
            .env_remove("CARGO_TARGET_DIR")
            .env_remove(COMMIT)
            .env_remove(DIRTY)
            .env("RUSTC", &self.rustc)
            .env("GIT_TRACE", self.root.join("git-trace"))
            .args(["run", "--offline", "-v", "--target-dir"])
            .arg(self.root.join("target"))
            .args(["--target", &self.target, "-p", "build-info-probe"]);
        if let Some(value) = commit {
            command.env(COMMIT, value);
        }
        if let Some(value) = dirty {
            command.env(DIRTY, value);
        }
        if let Some(path) = &self.path {
            command.env("PATH", path);
        }
        command.output().unwrap()
    }

    fn at(&self, root: PathBuf) -> Self {
        Self {
            root: root.canonicalize().unwrap(),
            cargo: self.cargo.clone(),
            rustc: self.rustc.clone(),
            target: self.target.clone(),
            path: None,
        }
    }

    fn commit_object(&self, message: &str) -> String {
        let tree = self.git(&["rev-parse", "HEAD^{tree}"]);
        let parent = self.git(&["rev-parse", "HEAD"]);
        self.git(&[
            "commit-tree",
            tree.trim(),
            "-p",
            parent.trim(),
            "-m",
            message,
        ])
        .trim()
        .to_owned()
    }

    fn check(
        &self,
        commit: Option<&str>,
        dirty: Option<&str>,
        expected: [&str; 4],
        recollected: bool,
    ) -> String {
        self.clear_trace();
        let output = self.build(commit.map(OsStr::new), dirty.map(OsStr::new));
        let stderr = String::from_utf8(output.stderr.clone()).unwrap();
        assert_eq!(
            successful(output),
            format!(
                "{}\n{}\n{}\n{}\n{}\n",
                expected[0], expected[1], self.target, expected[2], expected[3]
            ),
            "{stderr}"
        );
        // Cargo が実際に起動したコマンドを見て、Rust の再コンパイルと採取を区別する。
        let ran_script = stderr.lines().any(|line| {
            line.trim_start().starts_with("Running `") && line.contains("/build-script-build")
        });
        assert_eq!(ran_script, recollected, "{stderr}");
        let trace = self.trace();
        if recollected && expected[2] == "git" {
            assert!(
                trace.contains("rev-parse --verify 'HEAD^{commit}'"),
                "{trace}"
            );
        } else if commit.is_some() || !recollected {
            assert_eq!(trace, "");
        }
        assert!(!trace.contains(" status"), "{trace}");
        stderr
    }

    fn check_watches(&self, paths: &[PathBuf]) {
        let mut expected = vec![
            "cargo::rerun-if-changed=build.rs".to_owned(),
            format!("cargo::rerun-if-env-changed={COMMIT}"),
            format!("cargo::rerun-if-env-changed={DIRTY}"),
        ];
        expected.extend(paths.iter().map(|path| {
            assert!(path.is_file(), "{}", path.display());
            format!("cargo::rerun-if-changed={}", path.display())
        }));
        let mut actual: Vec<_> = self
            .directives()
            .lines()
            .filter(|line| line.starts_with("cargo::rerun-"))
            .map(str::to_owned)
            .collect();
        expected.sort();
        actual.sort();
        assert_eq!(actual, expected);
    }

    #[cfg(unix)]
    fn git_stub(&mut self, body: &str) {
        use std::os::unix::fs::PermissionsExt;

        let calls = self.root.join("git-stub-calls");
        let calls = calls.to_str().unwrap().replace('\'', "'\\''");
        self.write(
            "git-bin/git",
            &format!("#!/bin/sh\nprintf 'called\\n' >> '{calls}'\n{body}\n"),
        );
        fs::set_permissions(
            self.root.join("git-bin/git"),
            fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        let mut paths = vec![self.root.join("git-bin")];
        // Git だけを差し替え、リンカ・SDK などは元の PATH から引けるようにする。
        paths.extend(std::env::split_paths(&std::env::var_os("PATH").unwrap()));
        self.path = Some(std::env::join_paths(paths).unwrap());
    }

    fn directives(&self) -> String {
        let build = self
            .root
            .join("target")
            .join(&self.target)
            .join("debug/build");
        let outputs: Vec<_> = fs::read_dir(build)
            .unwrap()
            .map(|entry| entry.unwrap().path().join("output"))
            .filter(|path| path.is_file())
            .collect();
        assert_eq!(outputs.len(), 1);
        fs::read_to_string(&outputs[0]).unwrap()
    }

    fn trace(&self) -> String {
        fs::read_to_string(self.root.join("git-trace")).unwrap_or_default()
    }

    fn clear_trace(&self) {
        match fs::remove_file(self.root.join("git-trace")) {
            Ok(()) => (),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => (),
            Err(error) => panic!("cannot remove trace: {error}"),
        }
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _result = fs::remove_dir_all(&self.root);
    }
}

fn successful(output: Output) -> String {
    assert_eq!(
        output.status.code(),
        Some(0),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout).unwrap()
}

#[test]
#[ignore = "long: builds a temporary crate for the build input and Git acceptance table"]
fn build_inputs_and_git_collection() {
    let fixture = Fixture::new();
    let git_commit = fixture.git(&["rev-parse", "--verify", "HEAD^{commit}"]);
    let git_commit = git_commit.trim();
    // 一つの表で由来も比較する。値だけでは明示 unknown と未採取を区別できない。
    for (commit, dirty, expected_commit, expected_dirty, commit_origin, dirty_origin) in [
        (None, None, git_commit, "unknown", "git", "notCollected"),
        (None, Some("true"), git_commit, "true", "git", "environment"),
        (
            None,
            Some("false"),
            git_commit,
            "false",
            "git",
            "environment",
        ),
        (
            None,
            Some("unknown"),
            git_commit,
            "unknown",
            "git",
            "environment",
        ),
        (
            Some(HEX40),
            None,
            LOWER40,
            "unknown",
            "environment",
            "notCollected",
        ),
        (
            Some(LOWER40),
            Some("true"),
            LOWER40,
            "true",
            "environment",
            "environment",
        ),
        (
            Some(HEX64),
            Some("false"),
            LOWER64,
            "false",
            "environment",
            "environment",
        ),
        (
            Some(LOWER64),
            Some("unknown"),
            LOWER64,
            "unknown",
            "environment",
            "environment",
        ),
        (
            Some("unknown"),
            None,
            "",
            "unknown",
            "environment",
            "notCollected",
        ),
        (
            Some("unknown"),
            Some("false"),
            "",
            "false",
            "environment",
            "environment",
        ),
    ] {
        fixture.clear_trace();
        let output = fixture.build(commit.map(OsStr::new), dirty.map(OsStr::new));
        let values = successful(output);
        assert_eq!(
            values,
            format!(
                "{expected_commit}\n{expected_dirty}\n{}\n{commit_origin}\n{dirty_origin}\n",
                fixture.target
            )
        );
        let mut watches: Vec<_> = fixture
            .directives()
            .lines()
            .filter(|line| line.starts_with("cargo::rerun-"))
            .map(str::to_owned)
            .collect();
        let mut expected = vec![
            "cargo::rerun-if-changed=build.rs".to_owned(),
            format!("cargo::rerun-if-env-changed={COMMIT}"),
            format!("cargo::rerun-if-env-changed={DIRTY}"),
        ];
        if commit.is_none() {
            expected.push(format!(
                "cargo::rerun-if-changed={}/.git/HEAD",
                fixture.root.display()
            ));
            expected.push(format!(
                "cargo::rerun-if-changed={}/.git/logs/HEAD",
                fixture.root.display()
            ));
            expected.push(format!(
                "cargo::rerun-if-changed={}/.git/refs/heads/main",
                fixture.root.display()
            ));
            let trace = fixture.trace();
            assert!(
                trace.contains("rev-parse --verify 'HEAD^{commit}'"),
                "{trace}"
            );
            assert!(!trace.contains(" status"), "{trace}");
        } else {
            assert_eq!(fixture.trace(), "");
        }
        watches.sort();
        expected.sort();
        assert_eq!(watches, expected);
    }
    let mut invalid: Vec<(&str, OsString)> = [
        "",
        " abcdef0123456789abcdef0123456789abcdef01",
        "abcdef0123456789abcdef0123456789abcdef01 ",
        "abcdef0",
        "unknown\n",
        "UNKNOWN",
        "gggggggggggggggggggggggggggggggggggggggg",
        "abcdef0123456789abcdef0123456789abcdef0",
        "éééééééééééééééééééé",
        "unknown\ncargo::rustc-env=INJECTED=true",
    ]
    .into_iter()
    .map(|value| (COMMIT, OsString::from(value)))
    .collect();
    invalid.extend(
        [
            "",
            "true ",
            " false",
            "TRUE",
            "0",
            "1",
            "unknown\n",
            "unknown\ncargo::rustc-env=INJECTED=true",
        ]
        .into_iter()
        .map(|value| (DIRTY, OsString::from(value))),
    );
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStringExt;
        for name in [COMMIT, DIRTY] {
            invalid.push((name, OsString::from_vec(vec![0xff])));
        }
    }
    for (name, value) in invalid {
        fixture.clear_trace();
        let (commit, dirty) = if name == COMMIT {
            (Some(value.as_os_str()), None)
        } else {
            (None, Some(value.as_os_str()))
        };
        let output = fixture.build(commit, dirty);
        // Cargo の終了状態101とは別に、本番 build.rs 自体の終了状態1を確認する。
        assert_eq!(output.status.code(), Some(101), "{name}: {value:?}");
        assert!(output.stdout.is_empty());
        let error = String::from_utf8(output.stderr).unwrap();
        let syntax = if name == COMMIT {
            "expected 40 or 64 ASCII hexadecimal digits, or unknown"
        } else {
            "expected true, false, or unknown"
        };
        assert!(
            error.contains(&format!("invalid build input: {name}: {syntax}")),
            "{error}"
        );
        assert!(error.contains("exit status: 1"), "{error}");
        assert_eq!(fixture.trace(), "");
    }
}

#[test]
#[ignore = "long: builds temporary crates to check Git state and recollection"]
fn git_states() {
    for state in [
        "detached",
        "worktree",
        "packed",
        "archive",
        "unborn",
        "unborn-without-reflog",
        "reftable",
    ] {
        let fixture = Fixture::new();
        let commit = fixture.git(&["rev-parse", "HEAD"]);
        let mut probe = None;
        let mut watches = vec![
            fixture.root.join(".git/HEAD"),
            fixture.root.join(".git/logs/HEAD"),
        ];
        let expected = match state {
            "detached" => {
                fixture.git(&["checkout", "--detach", commit.trim()]);
                commit.trim()
            }
            "worktree" => {
                let linked = fixture.root.join("linked");
                fixture.git(&["worktree", "add", "-b", "linked", linked.to_str().unwrap()]);
                probe = Some(fixture.at(linked));
                // 期待する管理場所は準備した worktree の配置から独立に定める。
                watches = vec![
                    fixture.root.join(".git/worktrees/linked/HEAD"),
                    fixture.root.join(".git/worktrees/linked/logs/HEAD"),
                    fixture.root.join(".git/refs/heads/linked"),
                ];
                commit.trim()
            }
            "packed" => {
                fixture.git(&["pack-refs", "--all", "--prune"]);
                assert!(!fixture.root.join(".git/refs/heads/main").exists());
                watches.push(fixture.root.join(".git/packed-refs"));
                commit.trim()
            }
            "archive" => {
                let archive = fixture.root.join("archive");
                fs::create_dir(&archive).unwrap();
                let archive = fixture.at(archive);
                for path in [
                    "Cargo.toml",
                    "crates/benitoite/Cargo.toml",
                    "crates/benitoite/build.rs",
                    "crates/benitoite/src/main.rs",
                ] {
                    archive.write(path, &fs::read_to_string(fixture.root.join(path)).unwrap());
                }
                assert!(!archive.root.join(".git").exists());
                assert_eq!(archive.git(&["rev-parse", "HEAD"]), commit);
                probe = Some(archive);
                watches.clear();
                ""
            }
            "reftable" => {
                // reftable の管理場所があれば、採取可能な HEAD でも不明として扱う。
                fs::create_dir(fixture.root.join(".git/reftable")).unwrap();
                watches.clear();
                ""
            }
            "unborn" | "unborn-without-reflog" => {
                fixture.git(&["checkout", "--orphan", "unborn"]);
                assert!(!fixture.root.join(".git/refs/heads/unborn").exists());
                if state == "unborn-without-reflog" {
                    fs::remove_file(fixture.root.join(".git/logs/HEAD")).unwrap();
                    watches = vec![fixture.root.join(".git/HEAD")];
                }
                ""
            }
            _ => unreachable!(),
        };
        let probe = probe.as_ref().unwrap_or(&fixture);
        let origin = if expected.is_empty() {
            "unknown"
        } else {
            "git"
        };
        probe.check(
            None,
            None,
            [expected, "unknown", origin, "notCollected"],
            true,
        );
        probe.check_watches(&watches);
        let stderr = probe.check(
            None,
            None,
            [expected, "unknown", origin, "notCollected"],
            false,
        );
        assert!(
            !stderr.contains("Compiling build-info-probe"),
            "{state}: {stderr}"
        );
        if state == "unborn-without-reflog" {
            let head = fs::read(fixture.root.join(".git/HEAD")).unwrap();
            fixture.git(&["commit", "-m", "first unborn commit"]);
            assert_eq!(fs::read(fixture.root.join(".git/HEAD")).unwrap(), head);
            assert!(fixture.root.join(".git/logs/HEAD").is_file());
            probe.check(
                None,
                None,
                ["", "unknown", "unknown", "notCollected"],
                false,
            );
        }
        if state == "worktree" {
            // 共通側の packed-refs も既存の場合に監視する。
            fixture.git(&["pack-refs", "--all", "--prune"]);
            probe.check(
                None,
                Some("false"),
                [expected, "false", "git", "environment"],
                true,
            );
            probe.check_watches(&[
                fixture.root.join(".git/worktrees/linked/HEAD"),
                fixture.root.join(".git/worktrees/linked/logs/HEAD"),
                fixture.root.join(".git/packed-refs"),
            ]);
        }
    }
}

#[test]
#[ignore = "long: builds temporary crates to check Git state and recollection"]
fn loose_ref_refresh() {
    let fixture = Fixture::new();
    fixture.write("notes.txt", "tracked\n");
    fixture.write(".gitignore", "/ignored/\n/target/\n/git-trace\n");
    fixture.git(&["add", "notes.txt", ".gitignore"]);
    fixture.git(&["commit", "-m", "tracked files"]);
    let initial = fixture.git(&["rev-parse", "HEAD"]);
    let initial = initial.trim();
    let next = fixture.commit_object("next loose commit");
    fixture.check(
        None,
        None,
        [initial, "unknown", "git", "notCollected"],
        true,
    );
    let unchanged = fixture.check(
        None,
        None,
        [initial, "unknown", "git", "notCollected"],
        false,
    );
    assert!(
        !unchanged.contains("Compiling build-info-probe"),
        "{unchanged}"
    );

    for edit in ["tracked", "staged", "untracked", "ignored", "rust"] {
        match edit {
            "tracked" => fixture.write("notes.txt", "edited\n"),
            "staged" => {
                fixture.write("notes.txt", "staged\n");
                fixture.git(&["add", "notes.txt"]);
            }
            "untracked" => fixture.write("untracked.txt", "untracked\n"),
            "ignored" => fixture.write("ignored/notes.txt", "ignored\n"),
            "rust" => fixture.write("crates/benitoite/src/main.rs", &format!("{MAIN}\n")),
            _ => unreachable!(),
        }
        let stderr = fixture.check(
            None,
            None,
            [initial, "unknown", "git", "notCollected"],
            false,
        );
        assert_eq!(
            stderr.contains("Compiling build-info-probe"),
            edit == "rust",
            "{edit}: {stderr}"
        );
    }
    // 後の checkout で準備用の編集を持ち越さない。
    // HEAD の reflog を変えず、ソースの編集だけを戻す。
    fixture.git(&["restore", "--source=HEAD", "--staged", "--worktree", "."]);
    fixture.check(
        None,
        None,
        [initial, "unknown", "git", "notCollected"],
        false,
    );
    fixture.git(&["update-ref", "refs/heads/main", &next]);
    fixture.check(None, None, [&next, "unknown", "git", "notCollected"], true);
    fixture.git(&["checkout", "--detach", initial]);
    fixture.check(
        None,
        None,
        [initial, "unknown", "git", "notCollected"],
        true,
    );
    fixture.check_watches(&[
        fixture.root.join(".git/HEAD"),
        fixture.root.join(".git/logs/HEAD"),
    ]);

    for (commit, dirty, values) in [
        (
            None,
            Some("false"),
            [initial, "false", "git", "environment"],
        ),
        (None, Some("true"), [initial, "true", "git", "environment"]),
        (None, None, [initial, "unknown", "git", "notCollected"]),
        (
            Some(HEX40),
            None,
            [LOWER40, "unknown", "environment", "notCollected"],
        ),
        (
            Some(HEX64),
            None,
            [LOWER64, "unknown", "environment", "notCollected"],
        ),
        (
            Some("unknown"),
            Some("false"),
            ["", "false", "environment", "environment"],
        ),
        (None, None, [initial, "unknown", "git", "notCollected"]),
    ] {
        fixture.check(commit, dirty, values, true);
        if commit.is_some() {
            fixture.check_watches(&[]);
        }
    }
}

#[test]
#[ignore = "long: builds temporary crates to check Git state and recollection"]
fn packed_ref_refresh() {
    let fixture = Fixture::new();
    let initial = fixture.git(&["rev-parse", "HEAD"]);
    let initial = initial.trim();
    let next = fixture.commit_object("next packed commit");
    fixture.git(&["pack-refs", "--all", "--prune"]);
    fixture.check(
        None,
        None,
        [initial, "unknown", "git", "notCollected"],
        true,
    );
    let unchanged = fixture.check(
        None,
        None,
        [initial, "unknown", "git", "notCollected"],
        false,
    );
    assert!(
        !unchanged.contains("Compiling build-info-probe"),
        "{unchanged}"
    );
    fixture.git(&["update-ref", "refs/heads/main", &next]);
    fixture.git(&["pack-refs", "--all", "--prune"]);
    fixture.check(None, None, [&next, "unknown", "git", "notCollected"], true);
    let watches = [
        fixture.root.join(".git/HEAD"),
        fixture.root.join(".git/packed-refs"),
        fixture.root.join(".git/logs/HEAD"),
    ];
    fixture.check_watches(&watches);

    // gc 後のコミットと update-ref は、既存の HEAD の reflog で検知する。
    for update in ["commit", "update-ref"] {
        fixture.git(&["gc"]);
        fixture.check(None, None, [&next, "unknown", "git", "notCollected"], true);
        assert!(!fixture.root.join(".git/refs/heads/main").exists());
        match update {
            "commit" => {
                fixture.git(&["commit", "--allow-empty", "-m", "after gc"]);
            }
            "update-ref" => {
                fixture.git(&["update-ref", "refs/heads/main", initial]);
            }
            _ => unreachable!(),
        }
        let updated = fixture.git(&["rev-parse", "HEAD"]);
        fixture.check(
            None,
            None,
            [updated.trim(), "unknown", "git", "notCollected"],
            true,
        );
        fixture.git(&["update-ref", "refs/heads/main", &next]);
        fixture.git(&["pack-refs", "--all", "--prune"]);
        fixture.check(None, None, [&next, "unknown", "git", "notCollected"], true);
    }
    // reflog がない場合の既存の限界と、二つの回復手順も引き続き確かめる。
    fixture.git(&["config", "core.logAllRefUpdates", "false"]);
    fs::remove_file(fixture.root.join(".git/logs/HEAD")).unwrap();
    let watches = [watches[0].clone(), watches[1].clone()];
    fixture.check(None, None, [&next, "unknown", "git", "notCollected"], true);
    fixture.check_watches(&watches);
    // 新しい loose ref が作られても、登録済みのファイルに変化がなければ検知しない。
    for recovery in ["environment", "clean"] {
        let head = fs::read(&watches[0]).unwrap();
        let packed = fs::read(&watches[1]).unwrap();
        fixture.git(&["update-ref", "refs/heads/main", initial]);
        assert!(fixture.root.join(".git/refs/heads/main").is_file());
        assert_eq!(fs::read(&watches[0]).unwrap(), head);
        assert_eq!(fs::read(&watches[1]).unwrap(), packed);
        assert_eq!(fixture.git(&["rev-parse", "HEAD"]).trim(), initial);
        fixture.check(None, None, [&next, "unknown", "git", "notCollected"], false);
        if recovery == "environment" {
            fixture.check(
                None,
                Some("false"),
                [initial, "false", "git", "environment"],
                true,
            );
        } else {
            let mut clean = Command::new(&fixture.cargo);
            fixture.environment(&mut clean);
            successful(
                clean
                    .args([
                        "clean",
                        "--offline",
                        "-p",
                        "build-info-probe",
                        "--target-dir",
                    ])
                    .arg(fixture.root.join("target"))
                    .args(["--target", &fixture.target])
                    .output()
                    .unwrap(),
            );
            fixture.check(
                None,
                None,
                [initial, "unknown", "git", "notCollected"],
                true,
            );
        }
        fixture.check_watches(&[
            watches[0].clone(),
            watches[1].clone(),
            fixture.root.join(".git/refs/heads/main"),
        ]);
        if recovery == "environment" {
            fixture.git(&["update-ref", "refs/heads/main", &next]);
            fixture.git(&["pack-refs", "--all", "--prune"]);
            fixture.check(None, None, [&next, "unknown", "git", "notCollected"], true);
            fixture.check_watches(&watches);
        }
    }
}

#[cfg(unix)]
#[test]
#[ignore = "long: builds temporary crates to check Git collection failures"]
fn git_failures() {
    for failure in [
        "unavailable",
        "wrong-root",
        "invalid-commit",
        "old-git",
        "git-path",
        "non-utf8-path",
        "missing-head",
        "missing-ref",
    ] {
        let mut fixture = Fixture::new();
        let real_git = std::env::split_paths(&std::env::var_os("PATH").unwrap())
            .map(|path| path.join("git"))
            .find(|path| path.is_file())
            .unwrap()
            .canonicalize()
            .unwrap();
        // 絶対パスの Git を使う委譲だけシェルを通す。空白や単一引用符も保つ。
        let real_git = format!("'{}'", real_git.to_str().unwrap().replace('\'', "'\\''"));
        let body = match failure {
            "unavailable" => "exit 127".to_owned(),
            "wrong-root" => "printf '/\\n'".to_owned(),
            "invalid-commit" => format!(
                "case \"$*\" in\n  *'--verify HEAD^{{commit}}') printf 'invalid-object-id\\n';;\n  *) exec {real_git} \"$@\";;\nesac"
            ),
            "old-git" => format!(
                "case \"$*\" in\n  *'--path-format=absolute'*) printf '%s\\n%s\\n' '--path-format=absolute' '.git';;\n  *) exec {real_git} \"$@\";;\nesac"
            ),
            "git-path" => format!(
                "case \"$*\" in\n  *'--git-path'*) exit 1;;\n  *) exec {real_git} \"$@\";;\nesac"
            ),
            "non-utf8-path" => format!(
                "case \"$*\" in\n  *'--git-dir') printf '\\377\\n';;\n  *) exec {real_git} \"$@\";;\nesac"
            ),
            "missing-head" => {
                fs::create_dir(fixture.root.join("empty-git-dir")).unwrap();
                format!(
                    "case \"$*\" in\n  *'--git-dir') printf '%s/empty-git-dir\\n' \"$PWD\";;\n  *) exec {real_git} \"$@\";;\nesac"
                )
            }
            "missing-ref" => format!(
                "case \"$*\" in\n  *'--git-path'*) printf '%s/missing-ref\\n' \"$PWD\";;\n  *) exec {real_git} \"$@\";;\nesac"
            ),
            _ => unreachable!(),
        };
        fixture.git_stub(&body);
        for (commit, dirty, expected) in [
            (None, None, ["", "unknown", "unknown", "notCollected"]),
            (None, Some("false"), ["", "false", "unknown", "environment"]),
            (
                Some(HEX40),
                Some("true"),
                [LOWER40, "true", "environment", "environment"],
            ),
            (
                Some("unknown"),
                None,
                ["", "unknown", "environment", "notCollected"],
            ),
        ] {
            let calls = fixture.root.join("git-stub-calls");
            if calls.exists() {
                fs::remove_file(&calls).unwrap();
            }
            fixture.check(commit, dirty, expected, true);
            assert_eq!(calls.exists(), commit.is_none(), "{failure}");
            if matches!(failure, "unavailable" | "wrong-root") || commit.is_some() {
                fixture.check_watches(&[]);
            }
        }
    }
}
