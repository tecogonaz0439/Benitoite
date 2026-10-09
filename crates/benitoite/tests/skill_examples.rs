//! 同梱の Agent Skill の手で書く文書に載せたコードの例の検査と、`SKILL.md` の形の確かめ
//! （設計書 06-06「同梱の Agent Skill の構成」、ADR 0229 の決定 4、実装プラン D21）。
//! 例の書き方と検査の仕組みは、`tests/reference_examples.rs` と共有する `doc_examples` に置く。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

mod doc_examples;

use std::fs;
use std::path::PathBuf;

use doc_examples::{check_documents, check_example, examples};

/// 例を検査する手で書く文書（`skill/` からの相対パス）。
const DOCUMENTS: &[&str] = &[
    "SKILL.md",
    "references/idioms.md",
    "references/common-mistakes.md",
    "references/language-comparison.md",
];

fn skill_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("skill")
}

#[test]
fn code_examples_in_hand_written_documents_behave_as_written() {
    let (count, failures) = check_documents(&skill_dir(), DOCUMENTS, "skill/");
    assert!(
        failures.is_empty(),
        "{} of {count} examples failed:\n{}",
        failures.len(),
        failures.join("\n")
    );
    assert!(count > 0);
}

/// `SKILL.md` に並べる参照の文書の一覧を取り出す（`` `references/....md` `` の形。型板の `<…>` を含むものは除く）。
fn listed_references(skill: &str) -> Vec<String> {
    skill
        .split('`')
        .skip(1)
        .step_by(2)
        .filter(|s| s.starts_with("references/") && s.ends_with(".md") && !s.contains('<'))
        .map(str::to_string)
        .collect()
}

#[test]
fn skill_md_is_short_and_lists_every_reference_document() {
    let skill = fs::read_to_string(skill_dir().join("SKILL.md")).unwrap();
    assert!(
        skill.lines().count() < 500,
        "SKILL.md must be shorter than 500 lines"
    );
    assert!(
        skill.starts_with("---\n"),
        "SKILL.md must start with its front matter"
    );
    let listed = listed_references(&skill);
    for path in &listed {
        assert!(
            skill_dir().join(path).is_file(),
            "SKILL.md lists {path}, which does not exist"
        );
    }
    let mut expected = vec!["references/stdlib/index.md".to_string()];
    for entry in fs::read_dir(skill_dir().join("references")).unwrap() {
        let entry = entry.unwrap();
        let name = entry.file_name().to_string_lossy().into_owned();
        if entry.file_type().unwrap().is_file() && !name.starts_with('.') {
            expected.push(format!("references/{name}"));
        }
    }
    for path in &expected {
        assert!(listed.contains(path), "SKILL.md does not list {path}");
    }
    assert!(
        skill.contains("references/stdlib/<Module>.md"),
        "SKILL.md states the per-module file name rule"
    );
    for needle in [
        "benitoite --version",
        "benitoite skill install",
        "benitoite check",
        "benitoite run",
        "benitoite test",
    ] {
        assert!(skill.contains(needle), "SKILL.md mentions `{needle}`");
    }
}

#[test]
fn example_checker_reports_document_and_line_of_a_wrong_output() {
    // 出力を 1 文字変えた例が、文書と行番号つきで失敗として報告されることを確かめる。
    let text = "intro\n```benitoite\nimport Benitoite.Unofficial.IO.Console\n\nfunction main() -> Unit uses Console.Write\n  return Console.writeLine(\"hi\")\nend function\n```\n\n```output\nhj\n```\n";
    let examples = examples("doc.md", text).unwrap();
    assert_eq!(examples.len(), 1);
    assert_eq!(examples[0].line, 2);
    let problem = check_example(&examples[0]).unwrap();
    assert!(
        problem.contains("\"hj\\n\"") && problem.contains("\"hi\\n\""),
        "{problem}"
    );
}
