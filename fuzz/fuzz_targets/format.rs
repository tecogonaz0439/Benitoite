//! 任意のバイト列を一つのファイルとして整形し、フォーマッタの性質を確かめる（設計書 07-03「fuzzing」、06-03「テスト」）。
//! 処理系の不具合（panic、整形後の検証の失敗）が起きず、構文の誤りがなければ、整形が冪等で、整形の前後で
//! `check_text` の診断のコードと文言の並びが変わらない。
#![no_main]

use benitoite::base::{FileId, SourceKind};
use benitoite::cli::tools::formatter::{FormatError, format_source};
use benitoite::pipeline::{self, CheckOptions, CheckResult};
use libfuzzer_sys::fuzz_target;

fn diagnostics(result: &CheckResult) -> Vec<(String, String)> {
    result
        .diagnostics
        .iter()
        .map(|d| (format!("{:?}", d.code), d.message.clone()))
        .collect()
}

fuzz_target!(|data: &[u8]| {
    let once = match format_source(FileId(0), SourceKind::User, data) {
        Ok(once) => once,
        Err(FormatError::Syntax(_)) => return,
        Err(FormatError::Verify(message)) => panic!("整形後の検証が失敗した: {message}"),
    };
    let again = format_source(FileId(0), SourceKind::User, &once.text)
        .unwrap_or_else(|error| panic!("整形の結果を整形できない: {error:?}"));
    assert!(!again.changed, "整形が冪等でない");
    let options = CheckOptions {
        require_main: true,
        deny_warnings: false,
    };
    let before = diagnostics(&pipeline::check_text("fuzz.bnt", data, options));
    let after = diagnostics(&pipeline::check_text("fuzz.bnt", &once.text, options));
    assert_eq!(before, after, "整形の前後で検査の診断が変わった");
});
