//! テスト用スクリプトを変形して検査し、検査段が不具合を起こさないことを確かめる（設計書 07-03「fuzzing」）。
#![no_main]

mod common;

use benitoite::pipeline;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let result = pipeline::check_text(
        "fuzz-mutated.bnt",
        data,
        pipeline::CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    common::assert_properties(&result, false);
});
