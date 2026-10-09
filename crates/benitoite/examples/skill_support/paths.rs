//! 埋め込みの一覧に並べる Skill のパスの決め方（実装プラン D20「手順の要点」の 6）。
//! 生成の道具（`examples/gen_skill.rs`）と古くないことのテスト（`tests/skill_docs.rs`）が `#[path]` で読み、
//! 両方が同じ並びと同じ判定を使う。

use std::path::Path;

use benitoite::cli::tools::skill::generate::GeneratedFile;

/// 手で書く文書（D21）。生成物とあわせて埋め込みの一覧に並べる。
pub const HAND_WRITTEN: &[&str] = &[
    "SKILL.md",
    "references/common-mistakes.md",
    "references/idioms.md",
    "references/language-comparison.md",
];
/// ライセンス文（リポジトリの根）。両方があるときだけ一覧に加える。
pub const LICENSES: &[&str] = &["LICENSE-MIT", "LICENSE-APACHE"];

/// `SKILL.md`、`references/` の辞書順、ライセンス文の順の並びを作る。`repo` はリポジトリの根である。
pub fn bundle_paths(generated: &[GeneratedFile], repo: &Path) -> Vec<String> {
    let mut references: Vec<String> = HAND_WRITTEN
        .iter()
        .filter(|p| p.starts_with("references/"))
        .map(|p| p.to_string())
        .chain(generated.iter().map(|g| g.path.clone()))
        .collect();
    references.sort();
    let mut paths = vec!["SKILL.md".to_string()];
    paths.extend(references);
    if LICENSES.iter().all(|l| repo.join(l).is_file()) {
        paths.extend(LICENSES.iter().map(|l| l.to_string()));
    }
    paths
}

/// `.DS_Store` などの隠しファイル。生成物の比較と削除の対象にしない。
pub fn is_hidden(name: &str) -> bool {
    name.starts_with('.')
}
