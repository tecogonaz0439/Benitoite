//! 文書例の抽出時の文言（設計書 02-10「文言の言語」）。
pub(super) const UNCLOSED: &str = "unclosed code fence";
pub(super) const DIAGNOSTIC: &str =
    "a `benitoite error` example requires a following `diagnostic` block";
pub(super) const OUTPUT: &str =
    "a `benitoite` example requires a following `output` block (or use `benitoite check`)";
pub(super) const ERROR_CODE: &str =
    "a diagnostic block requires an existing E-code on its own line";
pub(super) const EXIT: &str = "nonzero exit expectations are not supported in comments";
pub(super) const FILES: &str = "files blocks are not supported in comments";
pub(super) const ORPHAN: &str = "an expectation block requires a preceding example";
pub(super) const UNKNOWN: &str = "unknown benitoite example mode";
