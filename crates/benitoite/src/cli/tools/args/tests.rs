//! `test`・`fmt` のコマンドラインの解釈と `.bnt` の列挙のテスト（設計書 06-01「ディレクトリの指定（初回リリース版）」
//! 「`fmt` のコマンドライン（初回リリース版）」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;

fn os(args: &[&str]) -> Vec<OsString> {
    args.iter().map(OsString::from).collect()
}

#[test]
fn reads_options_before_and_after_the_name_alike() {
    // `Command::Tool` は名前の前のオプションと後の引数を並べて渡すので、並びの位置に依らず同じに読む。
    let front = parse_path_args(
        PathTool::Test,
        os(&["--max-call-stack=2GiB", "--deny-warnings", "a.bnt", "dir"]),
    )
    .unwrap();
    let back = parse_path_args(
        PathTool::Test,
        os(&["a.bnt", "--deny-warnings", "dir", "--max-call-stack=2GiB"]),
    )
    .unwrap();
    assert_eq!(front, back);
    assert_eq!(front.max_call_stack, Some(2 * 1024 * 1024 * 1024));
    assert!(front.deny_warnings);
    assert!(!front.check);
    assert_eq!(
        front.paths,
        vec![PathBuf::from("a.bnt"), PathBuf::from("dir")]
    );

    let fmt = parse_path_args(
        PathTool::Fmt,
        os(&["--diagnostics=json", "a.bnt", "--check"]),
    )
    .unwrap();
    assert!(fmt.check);
    assert_eq!(fmt.diagnostics, DiagFormat::Json);
    assert_eq!(fmt.max_call_stack, None);
}

#[test]
fn path_arguments_accept_check_and_reject_usage_errors() {
    let cases: [(PathTool, &[&str], Result<PathArgs, String>); 9] = [
        (PathTool::Fmt, &[], Err(text::MISSING_PATH.to_owned())),
        (
            PathTool::Fmt,
            &["--check"],
            Err(text::MISSING_PATH.to_owned()),
        ),
        (
            PathTool::Fmt,
            &["--deny-warnings", "a.bnt"],
            Err(text::OPTION_NOT_FOR_COMMAND
                .replace("{name}", "--deny-warnings")
                .replace("{command}", "fmt")),
        ),
        (
            PathTool::Test,
            &["--check", "a.bnt"],
            Ok(PathArgs {
                report: None,
                allow_effects: None,
                diagnostics: DiagFormat::Text,
                max_call_stack: None,
                deny_warnings: false,
                check: true,
                paths: vec![PathBuf::from("a.bnt")],
            }),
        ),
        (
            PathTool::Fmt,
            &["--report=json", "a.bnt"],
            Err("option `--report` is not accepted by `fmt`".into()),
        ),
        (
            PathTool::Fmt,
            &["--allow-effects=", "a.bnt"],
            Err("option `--allow-effects` is not accepted by `fmt`".into()),
        ),
        (
            PathTool::Fmt,
            &["--frobnicate", "a.bnt"],
            Err(cli_text::UNKNOWN_OPTION.replace("{name}", "--frobnicate")),
        ),
        (
            PathTool::Fmt,
            &["--diagnostics=xml", "a.bnt"],
            Err(cli_text::BAD_VALUE
                .replace("{name}", "--diagnostics")
                .replace("{value}", "xml")),
        ),
        (
            PathTool::Fmt,
            &["--check", "--check", "a.bnt"],
            Err(cli_text::DUPLICATE_OPTION.replace("{name}", "--check")),
        ),
    ];
    for (tool, args, expected) in cases {
        assert_eq!(parse_path_args(tool, os(args)), expected, "{args:?}");
    }
    // WasmOptions を返さない公開入口では、指定を黙って失わず未知のオプションとして返す。
    for option in [
        "--wasm-memory=64MiB",
        "--wasm-fuel=1",
        "--wasm-transfer=256MiB",
        "--wasm-stats",
    ] {
        assert_eq!(
            parse_path_args(PathTool::Test, os(&[option, "a.bnt"])),
            Err(cli_text::UNKNOWN_OPTION.replace("{name}", option)),
            "{option}"
        );
    }
}

struct Scratch(PathBuf);

impl Scratch {
    fn new(tag: &str) -> Scratch {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_nanos());
        let path = std::env::temp_dir().join(format!(
            "benitoite-args-{tag}-{}-{nanos}",
            std::process::id()
        ));
        std::fs::create_dir(&path).unwrap();
        Scratch(path)
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _result = std::fs::remove_dir_all(&self.0);
    }
}

#[test]
fn bnt_files_collects_sorted_regular_bnt_files_and_skips_links() {
    let dir = Scratch::new("walk");
    let root = &dir.0;
    std::fs::create_dir_all(root.join("b/deep/deeper")).unwrap();
    std::fs::create_dir(root.join("a")).unwrap();
    for name in [
        "z.bnt",
        "a/y.bnt",
        "b/deep/deeper/x.bnt",
        "b/m.bnt",
        "notes.txt",
        "b/bnt",
    ] {
        std::fs::write(root.join(name), "").unwrap();
    }
    // 拡張子が .bnt のディレクトリは集めない
    std::fs::create_dir(root.join("dir.bnt")).unwrap();
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(root.join("z.bnt"), root.join("link.bnt")).unwrap();
        // 輪を作るリンク。辿ると止まらないので、辿らないことも確かめる
        std::os::unix::fs::symlink(root, root.join("b/loop")).unwrap();
    }
    let files = bnt_files(root).unwrap();
    let expected: Vec<PathBuf> = ["a/y.bnt", "b/deep/deeper/x.bnt", "b/m.bnt", "z.bnt"]
        .iter()
        .map(|n| root.join(n))
        .collect();
    assert_eq!(files, expected);
}

#[test]
fn bnt_files_reports_a_missing_directory() {
    let dir = Scratch::new("missing");
    let missing = dir.0.join("nope");
    let (path, _error) = bnt_files(&missing).unwrap_err();
    assert_eq!(path, missing);
}
