//! 同梱の Agent Skill の生成物が古くないことのテストと、生成物の形の確かめ
//! （実装プラン 10-19「生成の道具と、生成物が古くないことのテスト」、設計書 06-06「同梱の Agent Skill の構成」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing
)]

use std::fs;
use std::path::{Path, PathBuf};

use benitoite::cli::tools::skill::files;
use benitoite::cli::tools::skill::generate::{GeneratedFile, bundle_source, generate_references};
use benitoite::diag::codes::{ALL, RETIRED};
use benitoite::prelude::STDLIB;

const RERUN: &str =
    "the generated Skill documents are stale; run `cargo run -p benitoite --example gen_skill`";
#[path = "../examples/skill_support/paths.rs"]
mod paths;

fn crate_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn chapter() -> String {
    fs::read_to_string(crate_dir().join("../../docs/design/01-spec/01-02-syntax.md")).unwrap()
}

fn generated() -> Vec<GeneratedFile> {
    generate_references(&chapter()).unwrap()
}

fn find<'a>(files: &'a [GeneratedFile], path: &str) -> &'a str {
    &files.iter().find(|f| f.path == path).unwrap().text
}

fn bundle_paths(generated: &[GeneratedFile]) -> Vec<String> {
    paths::bundle_paths(generated, &crate_dir().join("../.."))
}

fn read(path: &Path) -> String {
    fs::read_to_string(path).unwrap_or_else(|e| panic!("{RERUN} ({}: {e})", path.display()))
}

#[test]
fn generated_documents_are_up_to_date() {
    let skill = crate_dir().join("skill");
    let generated = generated();
    for file in &generated {
        assert!(
            read(&skill.join(&file.path)) == file.text,
            "{RERUN} ({} differs)",
            file.path
        );
    }
    for entry in fs::read_dir(skill.join("references/stdlib")).unwrap() {
        let name = entry.unwrap().file_name().to_string_lossy().into_owned();
        if paths::is_hidden(&name) {
            continue;
        }
        let path = format!("references/stdlib/{name}");
        assert!(
            generated.iter().any(|g| g.path == path),
            "{RERUN} ({path} is not generated)"
        );
    }
    let bundle = read(&crate_dir().join("src/cli/tools/skill/bundle.rs"));
    assert!(
        bundle == bundle_source(&bundle_paths(&generated)),
        "{RERUN} (src/cli/tools/skill/bundle.rs differs)"
    );
}

#[test]
fn grammar_has_no_japanese_notes_and_keeps_every_rule() {
    let chapter = chapter();
    let grammar = find(&generated(), "references/grammar.md").to_string();
    assert!(!grammar.contains("(*"));
    assert!(
        !grammar
            .chars()
            .any(|c| ('\u{3040}'..='\u{30ff}').contains(&c)
                || ('\u{4e00}'..='\u{9fff}').contains(&c))
    );
    let start = chapter.find("### 初回リリース版の文法の全体").unwrap();
    let section = &chapter[start..];
    let block_start = section.find("```text\n").unwrap() + 8;
    let block = &section[block_start..block_start + section[block_start..].find("```").unwrap()];
    let count = |s: &str| {
        s.lines()
            .filter(|l| {
                let head = l.split('=').next().unwrap_or("");
                l.contains('=')
                    && !head.is_empty()
                    && head.trim().chars().all(|c| c.is_ascii_alphabetic())
                    && !l.starts_with(' ')
            })
            .count()
    };
    assert!(count(block) > 50);
    assert_eq!(count(&grammar), count(block));
}

#[test]
fn each_module_has_a_file_with_its_import_name() {
    let generated = generated();
    let modules: Vec<&GeneratedFile> = generated
        .iter()
        .filter(|g| {
            g.path.starts_with("references/stdlib/") && g.path != "references/stdlib/index.md"
        })
        .collect();
    assert_eq!(modules.len(), STDLIB.len());
    assert!(
        find(&generated, "references/stdlib/IO.Console.md")
            .contains("import Benitoite.Unofficial.IO.Console")
    );
    assert!(find(&generated, "references/stdlib/Trait.md").contains("import Benitoite.Trait"));
    assert!(find(&generated, "references/stdlib/List.md").contains("without `import`"));
    assert!(
        find(&generated, "references/stdlib/List.md")
            .contains("Refer to its declarations as `List.<name>`, for example `List.length`.")
    );
    assert!(
        find(&generated, "references/stdlib/IO.Console.md").contains(
            "Refer to its declarations as `Console.<name>`, for example `Console.Write`."
        )
    );
    let index = find(&generated, "references/stdlib/index.md");
    for module in STDLIB {
        assert!(index.contains(&format!("[{0}]({0}.md)", module.path.join("."))));
    }
}

#[test]
fn declarations_omit_attributes_bodies_and_private_functions() {
    let generated = generated();
    for file in generated
        .iter()
        .filter(|f| f.path.starts_with("references/stdlib/"))
    {
        assert!(!file.text.contains("@builtin"), "{}", file.path);
    }
    // Option.map は本体を持つ公開の関数。本体の `match` は写さない。
    let option = find(&generated, "references/stdlib/Option.md");
    assert!(option.contains("public function map[T, U, effect E]("));
    assert!(!option.contains("return match"));
    // 公開でない宣言（`public` のない行で始まる関数）は、どのモジュールのファイルにも現れない。
    for module in STDLIB {
        let name = module.path.join(".");
        let text = find(&generated, &format!("references/stdlib/{name}.md"));
        for line in module.text.lines() {
            if let Some(rest) = line.strip_prefix("function ") {
                let decl = format!("function {}", rest.split('(').next().unwrap());
                assert!(!text.contains(&format!("\n{decl}(")), "{name}: {decl}");
                assert!(!text.contains(&format!("public {decl}(")), "{name}: {decl}");
            }
        }
    }
}

#[test]
fn diagnostics_list_every_code_and_no_retired_code() {
    let diagnostics = find(&generated(), "references/diagnostics.md").to_string();
    for code in ALL {
        assert!(diagnostics.contains(&format!("\n## {}\n", code.info().id)));
    }
    for retired in RETIRED {
        assert!(!diagnostics.contains(&format!("## {retired}\n")));
    }
}

#[test]
fn embedded_files_cover_every_skill_file() {
    let embedded: Vec<&str> = files().iter().map(|f| f.path).collect();
    assert_eq!(embedded, bundle_paths(&generated()));
    let skill_md = files().iter().find(|f| f.path == "SKILL.md").unwrap();
    assert!(skill_md.text.starts_with("---\n"));
    assert!(
        skill_md
            .text
            .contains("\n  benitoite-version: \"{{benitoite-version}}\"\n")
    );
}

#[test]
fn syntax_chapter_without_the_heading_is_rejected() {
    assert!(generate_references("# Syntax\n\n```text\nA = B .\n```\n").is_err());
}

/// `skill/` の下の、隠しファイルでないすべてのファイルが埋め込まれている（手で書く文書の一覧の書き忘れを見つける）。
#[test]
fn every_file_under_skill_is_embedded() {
    let root = crate_dir().join("skill");
    let mut stack = vec![root.clone()];
    let mut found = Vec::new();
    while let Some(dir) = stack.pop() {
        for entry in fs::read_dir(&dir).unwrap() {
            let entry = entry.unwrap();
            if paths::is_hidden(&entry.file_name().to_string_lossy()) {
                continue;
            }
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else {
                found.push(
                    path.strip_prefix(&root)
                        .unwrap()
                        .to_string_lossy()
                        .replace('\\', "/"),
                );
            }
        }
    }
    let embedded: Vec<&str> = files().iter().map(|f| f.path).collect();
    for path in &found {
        assert!(
            embedded.contains(&path.as_str()),
            "{RERUN} ({path} is not embedded)"
        );
    }
}
