//! 同梱の Agent Skill の参照の文書の生成の道具（実装プラン 10-19「生成の道具と、生成物が古くないことのテスト」、
//! 設計書 06-06「同梱の Agent Skill の構成」）。`cargo run -p benitoite --example gen_skill` で、`skill/references/` の生成物と
//! `src/cli/tools/skill/bundle.rs` を書き直し、書いたファイルの一覧を標準出力に書く。

use std::error::Error;
use std::fs;
use std::path::Path;

use benitoite::cli::tools::skill::generate::{bundle_source, generate_references};

#[path = "skill_support/paths.rs"]
mod paths;

fn main() -> Result<(), Box<dyn Error>> {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let repo_dir = crate_dir.join("../..");
    let chapter = fs::read_to_string(repo_dir.join("docs/design/01-spec/01-02-syntax.md"))?;
    let generated = generate_references(&chapter)?;
    let skill_dir = crate_dir.join("skill");

    // 生成しなくなったモジュールのファイルを残さない。
    let stdlib_dir = skill_dir.join("references/stdlib");
    fs::create_dir_all(&stdlib_dir)?;
    for entry in fs::read_dir(&stdlib_dir)? {
        let entry = entry?;
        if paths::is_hidden(&entry.file_name().to_string_lossy()) {
            continue;
        }
        let path = entry.path();
        let rel = path
            .strip_prefix(&skill_dir)?
            .to_string_lossy()
            .replace('\\', "/");
        if !generated.iter().any(|g| g.path == rel) {
            fs::remove_file(&path)?;
            println!("removed {}", path.display());
        }
    }
    for file in &generated {
        let path = skill_dir.join(&file.path);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&path, &file.text)?;
        println!("wrote {}", path.display());
    }

    let paths = paths::bundle_paths(&generated, &repo_dir);
    let bundle = crate_dir.join("src/cli/tools/skill/bundle.rs");
    fs::write(&bundle, bundle_source(&paths))?;
    println!("wrote {}", bundle.display());
    Ok(())
}
