//! 検査を通ったスクリプトの脱糖とコード生成を確かめる（設計書 07-03「fuzzing」）。
#![no_main]

mod common;

use benitoite::pipeline;
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let result = pipeline::check_text(
        "fuzz-compile.bnt",
        data,
        pipeline::CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    common::assert_properties(&result, true);
});
