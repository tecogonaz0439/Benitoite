//! 英語の言語リファレンス `docs/reference/benitoite.md` に載せたコードの例の検査
//! （設計書 06-06「言語の文書と日本語の訳」、実装プラン D33）。例の書き方と検査の規則は、
//! 同梱の Skill の文書（`tests/skill_examples.rs`）と同じであり、共有する `doc_examples` に置く。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

mod doc_examples;

use std::path::PathBuf;

use doc_examples::check_documents;

/// 例を検査する文書（リポジトリの根の `docs/reference/` からの相対パス）。
const DOCUMENTS: &[&str] = &["benitoite.md"];

fn reference_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../docs/reference")
}

#[test]
fn code_examples_in_the_language_reference_behave_as_written() {
    let (count, failures) = check_documents(&reference_dir(), DOCUMENTS, "docs/reference/");
    assert!(
        failures.is_empty(),
        "{} of {count} examples failed:\n{}",
        failures.len(),
        failures.join("\n")
    );
    assert!(count > 0);
}
