//! コンポーネントの相対パスと正規化した境界を検査する（設計書 03-10「コンポーネントのパス」）。

use super::text;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::modules::ModuleFs;
use crate::syntax::ast::StrArg;
use std::path::{Path, PathBuf};

/// パッケージの境界は wasm の下、根のモジュールの境界は根全体とする。
pub(crate) fn resolve_path(
    fs: &dyn ModuleFs,
    root: &Path,
    path: &StrArg,
    package: Option<&str>,
) -> Result<PathBuf, Box<Diagnostic>> {
    let parts: Vec<_> = path.value.split('/').collect();
    let malformed = path.value.is_empty()
        || path.value.starts_with('/')
        || path.value.contains('\\')
        || parts
            .iter()
            .any(|part| part.is_empty() || matches!(*part, "." | ".."))
        || !path.value.ends_with(".wasm");
    let hidden = parts.iter().any(|part| part.starts_with('.'));
    if malformed || hidden {
        let mut diagnostic = builder(path, DiagCode::E1002).help("form");
        if hidden && !malformed {
            diagnostic = diagnostic.note("hidden");
        }
        return Err(Box::new(diagnostic.build()));
    }
    let outside = || {
        let diagnostic = builder(path, DiagCode::E1003).arg(
            "base",
            if package.is_some() {
                text::PACKAGE
            } else {
                text::ROOT
            },
        );
        Box::new(
            if let Some(package) = package {
                diagnostic.arg("package", package).note("package")
            } else {
                diagnostic.note("root")
            }
            .build(),
        )
    };
    if package.is_some() && parts.first() != Some(&"wasm") {
        return Err(outside());
    }
    let boundary = if package.is_some() {
        root.join("wasm")
    } else {
        root.to_path_buf()
    };
    let mut current = root.to_path_buf();
    for (index, part) in parts.iter().enumerate() {
        let directory = index.saturating_add(1) < parts.len();
        let entries = fs
            .list_dir(&current)
            .map_err(|error| read_error(path, text::io_reason(&error)))?;
        if !entries
            .iter()
            .any(|entry| entry.name == *part && entry.is_dir == directory)
        {
            return Err(read_error(path, text::MISSING));
        }
        current.push(part);
    }
    let canonical = fs
        .canonicalize(&current)
        .map_err(|error| read_error(path, text::io_reason(&error)))?;
    if !canonical.starts_with(boundary) {
        return Err(outside());
    }
    Ok(canonical)
}

pub(super) fn builder(path: &StrArg, code: DiagCode) -> DiagBuilder {
    DiagBuilder::new(code)
        .arg("path", &path.value)
        .primary(path.span)
}
pub(super) fn read_error(path: &StrArg, reason: &str) -> Box<Diagnostic> {
    Box::new(
        builder(path, DiagCode::E1001)
            .arg("reason", reason)
            .note("reason")
            .build(),
    )
}
