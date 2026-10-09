//! 複数のファイルを検査し、モジュールの読み込みからコード生成までを確かめる（設計書 07-03「fuzzing」）。
#![no_main]

mod common;

use benitoite::pipeline;
use libfuzzer_sys::fuzz_target;

const PATHS: [&str; 6] = [
    "main.bnt",
    "Lib/Text.bnt",
    "Lib/Geometry/Shape.bnt",
    "Util.bnt",
    "Lib/Deep/Inner.bnt",
    "util.bnt",
];

fuzz_target!(|data: &[u8]| {
    // 空の補助ファイルは置かず、欠落した import も試す（実装プラン C15「対象」）。
    let files: Vec<_> = PATHS
        .iter()
        .zip(data.split(|byte| *byte == 0))
        .enumerate()
        .filter(|(index, (_, text))| *index == 0 || !text.is_empty())
        .map(|(_, (path, text))| (*path, text))
        .collect();
    let result = pipeline::check_files(
        &files,
        pipeline::CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    common::assert_properties(&result, true);
});
