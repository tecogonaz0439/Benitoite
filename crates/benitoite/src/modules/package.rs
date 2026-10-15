//! 先頭の部分の置き場所と、宣言した言語の版を検査する
//! （設計書 01-03「依存の記述と `package.bnt`」、06-09「設定ファイルの検査」）。

use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::ast::{HeaderBlock, HeaderItem, LanguageDecl, Module};
use crate::syntax::version::{Version, parse_version};

use super::{ModuleFs, ModuleKind, hash, text};

/// ディレクトリの照合と入口の除外で共有する設定ファイルの名前。
pub(crate) const CONFIG_NAME: &str = "package.bnt";

/// 記述全体を保持し、読み込み時の検査が path・hash とその位置を参照できるようにする。
pub(super) struct Dependency {
    pub declaration: HeaderBlock,
    pub root: std::path::PathBuf,
    pub display_root: String,
    pub package_name: String,
    /// 依存の設定ファイルの ID。取り込んだモジュールが属するパッケージの識別にも使う。
    pub config: crate::base::ModuleId,
}

/// 記述に hash がある場合だけ計算し、値の位置とパッケージの名前を診断に添える。
pub(super) fn check_hash(dependency: &Dependency, fs: &dyn ModuleFs) -> Option<Diagnostic> {
    let field = dependency
        .declaration
        .fields
        .iter()
        .find(|field| field.name.text == text::HASH)?;
    // 書式の誤りは構文解析器が報告済みなので、計算の失敗や不一致を重ねない。
    if !crate::syntax::header::valid_hash(&field.value.value) {
        return None;
    }
    let builder = |code| {
        DiagBuilder::new(code)
            .arg("alias", &dependency.declaration.name.text)
            .arg("package", &dependency.package_name)
            .primary(field.value.span)
    };
    match hash::package_hash(fs, &dependency.root, hash::HashLimits::default()) {
        Ok(computed) => {
            if computed == field.value.value {
                None
            } else {
                Some(
                    builder(DiagCode::E0919)
                        .arg("expected", &field.value.value)
                        .arg("computed", computed)
                        .note("expected")
                        .note("computed")
                        .note("package")
                        .note("update")
                        .build(),
                )
            }
        }
        Err(error) => Some(hash_diagnostic(builder(DiagCode::E0920), error)),
    }
}

/// コマンドと読み込みで同じ規則のハッシュを計算する。
pub(crate) fn compute_hash(
    fs: &dyn ModuleFs,
    root: &std::path::Path,
) -> Result<String, hash::HashError> {
    hash::package_hash(fs, root, hash::HashLimits::default())
}

/// 公開宣言を読む対象を、ハッシュの走査と一致させる。
pub(crate) fn source_files(
    fs: &dyn ModuleFs,
    root: &std::path::Path,
) -> Result<Vec<std::path::PathBuf>, hash::HashError> {
    Ok(hash::package_files(fs, root, hash::HashLimits::default())?
        .into_iter()
        .filter(|(name, _)| {
            name.ends_with(".bnt") && name != CONFIG_NAME && !name.starts_with("wasm/")
        })
        .map(|(_, path)| path)
        .collect())
}

/// 計算できない理由を、値の位置がないコマンドでも同じ診断にする。
pub(crate) fn hash_diagnostic(diagnostic: DiagBuilder, error: hash::HashError) -> Diagnostic {
    let diagnostic = match error {
        hash::HashError::Symlink { path } => diagnostic.arg("path", path).note("symlink"),
        hash::HashError::Case { path, other } => diagnostic
            .arg("path", path)
            .arg("other", other)
            .note("case"),
        hash::HashError::Name { path } => diagnostic.arg("path", path).note("name"),
        hash::HashError::TooMany { limit } => {
            diagnostic.arg("limit", limit.to_string()).note("too_many")
        }
        hash::HashError::TooManyEntries { limit } => diagnostic
            .arg("limit", limit.to_string())
            .note("too_many_entries"),
        hash::HashError::TooLarge { limit } => {
            diagnostic.arg("limit", limit.to_string()).note("too_large")
        }
        hash::HashError::Read { path, reason } => diagnostic
            .arg("path", path)
            .arg("reason", reason.to_string())
            .note("read"),
    };
    diagnostic.note("package").build()
}

/// 依存の読み込みと外部の関数の照合で共有する、根と表示名の解決。
pub(crate) fn dependency_location(
    entry: &super::EntrySpec,
    fs: &dyn ModuleFs,
    block: &HeaderBlock,
) -> Option<std::io::Result<(std::path::PathBuf, String)>> {
    let path = block
        .fields
        .iter()
        .find(|field| field.name.text == text::PATH)?;
    let display_root = std::path::Path::new(&super::find::display_root(entry))
        .join(&path.value.value)
        .display()
        .to_string();
    Some(
        fs.canonicalize(&entry.root.join(&path.value.value))
            .map(|root| (root, display_root)),
    )
}

/// 検査済みの入口と設定の構文木から、依存の別名と根の表を作り直す。
pub(crate) fn dependency_roots(
    entry: &super::EntrySpec,
    fs: &dyn ModuleFs,
    modules: &super::ModuleTable,
    asts: &[Module],
) -> std::io::Result<std::collections::BTreeMap<String, (std::path::PathBuf, String)>> {
    let mut roots = std::collections::BTreeMap::new();
    for module in modules
        .iter()
        .filter(|module| matches!(module.kind, ModuleKind::Entry | ModuleKind::Config))
    {
        let ast = asts
            .get(usize::try_from(module.id.0).map_err(std::io::Error::other)?)
            .ok_or_else(|| std::io::Error::from(std::io::ErrorKind::InvalidInput))?;
        for item in &ast.header {
            if let HeaderItem::Dependency(block) = item {
                // path の欠落は構文解析器が報告するので、I/O の失敗を重ねない。
                if let Some(location) = dependency_location(entry, fs, block) {
                    roots.insert(block.name.text.clone(), location?);
                }
            }
        }
    }
    Ok(roots)
}

struct BreakingChange {
    version: Version,
    summary: &'static str,
}

// 今まで誤りだった書き方を加える変更は、既存のコードの互換性を壊さない。
const BREAKING_CHANGES: &[BreakingChange] = &[BreakingChange {
    version: Version(0, 0, 5),
    summary: text::NAMED_ARGUMENTS_CHANGE,
}];

pub(crate) use crate::syntax::header::keyword;

/// 根として読む場合と依存として読む場合で、設定ファイルの規則を共有する。
pub(crate) fn check_header(module: &Module, kind: ModuleKind) -> Vec<Diagnostic> {
    let mut diagnostics = Vec::new();
    let Some(current) = parse_version(env!("CARGO_PKG_VERSION")) else {
        diagnostics.push(super::internal_error(format!(
            "invalid interpreter version {:?}",
            env!("CARGO_PKG_VERSION")
        )));
        return diagnostics;
    };
    for item in &module.header {
        let (name, span) = keyword(item);
        if matches!(kind, ModuleKind::User | ModuleKind::Package) {
            diagnostics.push(
                DiagBuilder::new(if matches!(item, HeaderItem::Package(_)) {
                    DiagCode::E0910
                } else {
                    DiagCode::E0909
                })
                .arg("item", name)
                .primary(span)
                .build(),
            );
        } else {
            if let HeaderItem::Package(_) = item
                && !matches!(kind, ModuleKind::Config | ModuleKind::PackageConfig)
            {
                diagnostics.push(DiagBuilder::new(DiagCode::E0910).primary(span).build());
            }
            if let HeaderItem::Language(decl) = item
                && let Some(diagnostic) = check_language(decl, current, BREAKING_CHANGES)
            {
                diagnostics.push(diagnostic);
            }
        }
    }
    if matches!(kind, ModuleKind::Config | ModuleKind::PackageConfig) {
        if let Some(span) = module
            .imports
            .iter()
            .map(|item| item.span)
            .chain(module.decls.iter().map(|decl| decl.span))
            .min_by_key(|span| span.start)
        {
            diagnostics.push(DiagBuilder::new(DiagCode::E0912).primary(span).build());
        }
        if let Some(block) = module.header.iter().find_map(|item| match item {
            HeaderItem::Package(block) => Some(block),
            HeaderItem::Language(_) | HeaderItem::Dependency(_) => None,
        }) {
            if !module
                .header
                .iter()
                .any(|item| matches!(item, HeaderItem::Language(_)))
            {
                diagnostics.push(
                    DiagBuilder::new(DiagCode::E0914)
                        .arg("package", &block.name.text)
                        .primary(block.name.span)
                        .build(),
                );
            }
            for item in &module.header {
                if matches!(item, HeaderItem::Dependency(_)) {
                    diagnostics.push(
                        DiagBuilder::new(DiagCode::E0915)
                            .arg("package", &block.name.text)
                            .primary(keyword(item).1)
                            .secondary(block.name.span, "package")
                            .build(),
                    );
                }
            }
        }
    }
    diagnostics
}

/// 同じ種類の設定を入口と設定ファイルの両方に書いた位置を示す。
pub(crate) fn check_overlap(entry: &Module, config: &Module, display: &str) -> Vec<Diagnostic> {
    let mut diagnostics = Vec::new();
    for name in [text::LANGUAGE, text::DEPENDENCY] {
        let first = entry.header.iter().find(|item| keyword(item).0 == name);
        let other = config.header.iter().find(|item| keyword(item).0 == name);
        if let (Some(first), Some(other)) = (first, other) {
            diagnostics.push(
                DiagBuilder::new(DiagCode::E0911)
                    .arg("what", format!("`{name}`"))
                    .arg("file", display)
                    .primary(keyword(first).1)
                    .secondary(keyword(other).1, "other")
                    .build(),
            );
        }
    }
    diagnostics
}

fn check_language(
    decl: &LanguageDecl,
    current: Version,
    changes: &[BreakingChange],
) -> Option<Diagnostic> {
    // 書式の誤りは構文解析器が報告するので、ここでは重ねて報告しない。
    let version = parse_version(&decl.version.value)?;
    if version > current {
        return Some(
            DiagBuilder::new(DiagCode::E0907)
                .arg("version", version.to_string())
                .arg("current", current.to_string())
                .primary(decl.version.span)
                .build(),
        );
    }
    let change = changes
        .iter()
        .filter(|change| version < change.version && change.version <= current)
        .min_by_key(|change| change.version)?;
    Some(
        DiagBuilder::new(DiagCode::E0908)
            .arg("version", version.to_string())
            .arg("changed", change.version.to_string())
            .arg("summary", change.summary)
            .primary(decl.version.span)
            .note("change")
            .help("migrate")
            .build(),
    )
}

#[cfg(test)]
// 互換性の表の並びに依存しない比較を確かめるため、比較が受け取る表だけを差し替える。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::SourceKind;
    use crate::syntax::parser::test_support::parse_source;

    // 処理系の版の契約が壊れたリリースを、配布する前に検出する。
    #[test]
    fn interpreter_version_has_three_numbers() {
        assert!(parse_version(env!("CARGO_PKG_VERSION")).is_some());
    }

    #[test]
    fn version_format_and_order() {
        for value in ["0.0.0", "0.0.3", "1.10.2", "18446744073709551615.0.0"] {
            assert!(parse_version(value).is_some(), "{value}");
        }
        for value in [
            "",
            "1.2",
            "1.2.3.4",
            "01.2.3",
            "1.02.3",
            "1.2.03",
            "-1.0.0",
            "1.2.3-beta",
            "1.2.３",
            "1..3",
            "1.2.3 ",
            "18446744073709551616.0.0",
        ] {
            assert!(parse_version(value).is_none(), "{value}");
        }
        assert!(parse_version("1.10.0") > parse_version("1.2.99"));
        assert!(parse_version("2.0.0") > parse_version("1.99.99"));
    }

    #[test]
    fn version_check_reports_the_earliest_applicable_change() {
        let (out, _) = parse_source("language \"0.0.3\"", SourceKind::User);
        let HeaderItem::Language(decl) = &out.module.header[0] else {
            panic!()
        };
        let changes = [
            BreakingChange {
                version: Version(0, 0, 6),
                summary: "later change",
            },
            BreakingChange {
                version: Version(0, 0, 4),
                summary: "first change",
            },
            BreakingChange {
                version: Version(0, 0, 9),
                summary: "future change",
            },
            BreakingChange {
                version: Version(0, 0, 3),
                summary: "already included",
            },
        ];
        assert!(check_language(decl, Version(0, 0, 3), &changes).is_none());
        assert!(check_language(decl, Version(0, 0, 8), &[]).is_none());
        let diag = check_language(decl, Version(0, 0, 8), &changes).unwrap();
        assert_eq!(diag.code, Some(DiagCode::E0908));
        assert!(diag.message.contains("in 0.0.4"));
        assert_eq!(diag.notes, vec!["first change"]);
        assert_eq!(
            diag.helps[0].message,
            "see docs/reference/benitoite.md for named arguments and named function types"
        );
        assert!(diag.helps[0].edits.is_empty());
        assert_eq!(diag.primary.unwrap().span, decl.version.span);
        assert_eq!(
            check_language(decl, Version(0, 0, 2), &changes)
                .unwrap()
                .code,
            Some(DiagCode::E0907)
        );
    }
}
