//! import の名前の照合と修正案（設計書 02-04「モジュールの探し方」）。

use std::path::{Path, PathBuf};

use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, Edit};
use crate::syntax::ast::ImportDecl;

use super::load::{Content, Pending};
use super::package::Dependency;
use super::{DirEntryName, EntrySpec, ModuleFs, ModuleKind, ModulePath, StdlibModuleSource};

pub(super) struct Finder<'a> {
    entry: &'a EntrySpec,
    stdlib: &'a [StdlibModuleSource],
    fs: &'a dyn ModuleFs,
    root: Option<PathBuf>,
    entry_path: Option<PathBuf>,
    pub dependencies: Vec<Dependency>,
    pub failed_aliases: std::collections::BTreeSet<String>,
}

impl<'a> Finder<'a> {
    pub fn new(
        entry: &'a EntrySpec,
        stdlib: &'a [StdlibModuleSource],
        fs: &'a dyn ModuleFs,
    ) -> Self {
        Self {
            entry,
            stdlib,
            fs,
            root: fs.canonicalize(&entry.root).ok(),
            entry_path: fs.canonicalize(&entry.path).ok(),
            dependencies: Vec::new(),
            failed_aliases: std::collections::BTreeSet::new(),
        }
    }

    pub fn find(
        &self,
        import: &ImportDecl,
        from: Option<crate::base::ModuleId>,
    ) -> Result<Option<Pending>, Box<Diagnostic>> {
        // 読めなかった依存へ根からの探索を重ねず、原因の診断だけを残す。
        if from.is_none()
            && import
                .path
                .first()
                .is_some_and(|name| self.failed_aliases.contains(&name.text))
        {
            return Ok(None);
        }
        self.find_module(import, from).map(Some)
    }

    fn find_module(
        &self,
        import: &ImportDecl,
        from: Option<crate::base::ModuleId>,
    ) -> Result<Pending, Box<Diagnostic>> {
        let path = ModulePath(import.path.iter().map(|name| name.text.clone()).collect());
        let span = import_span(import);
        if path.0.first().is_some_and(|name| name == "Benitoite") {
            return self.stdlib(&path, span);
        }
        if let Some(config) = from {
            let dependency = self
                .dependencies
                .iter()
                .find(|dependency| dependency.config == config)
                .ok_or_else(|| {
                    Box::new(super::internal_error(format!(
                        "missing package config {config:?}"
                    )))
                })?;
            return self
                .package_file(&path, span, dependency, &path)
                .and_then(Lookup::required);
        }
        let root = self.root_file(&path, span)?;
        let Some(dependency) = self
            .dependencies
            .iter()
            .find(|dependency| path.0.first() == Some(&dependency.declaration.name.text))
        else {
            return self.require_root(root, span);
        };
        let tail = ModulePath(path.0.get(1..).unwrap_or(&[]).to_vec());
        let package = self.package_file(&tail, span, dependency, &path)?;
        match (root, package) {
            (Lookup::Found(root, root_path, _), Lookup::Found(package, package_path, _)) => {
                let same = root_path == package_path;
                if same {
                    Ok(package)
                } else {
                    Err(Box::new(
                        DiagBuilder::new(DiagCode::E0918)
                            .arg("module", path.dotted())
                            .arg("alias", &dependency.declaration.name.text)
                            .arg("package", &dependency.package_name)
                            .arg("root_path", root.display)
                            .arg("package_path", package.display)
                            .primary(span)
                            .note("root_file")
                            .note("package_file")
                            .note("rename")
                            .build(),
                    ))
                }
            }
            (root @ Lookup::Found(_, _, _), Lookup::Missing(_)) => self.require_root(root, span),
            (Lookup::Missing(_), package) => package.required(),
        }
    }

    fn require_root(&self, root: Lookup, span: Span) -> Result<Pending, Box<Diagnostic>> {
        if let Lookup::Found(pending, path, _) = &root
            && let Some(dependency) = self
                .dependencies
                .iter()
                .find(|dependency| path.starts_with(&dependency.root))
        {
            let relative = path.strip_prefix(&dependency.root).map_err(|error| {
                Box::new(super::internal_error(format!(
                    "missing package-relative path: {error}"
                )))
            })?;
            let tail = relative.with_extension("");
            let parts = tail
                .iter()
                .map(|part| part.to_str())
                .collect::<Option<Vec<_>>>();
            let mut diagnostic = DiagBuilder::new(DiagCode::E0921)
                .arg("path", &pending.display)
                .arg("alias", &dependency.declaration.name.text)
                .arg("package", &dependency.package_name)
                .primary(span)
                .note("package");
            if let Some(parts) = parts.filter(|parts| parts.iter().all(|part| module_segment(part)))
            {
                let suggestion = std::iter::once(dependency.declaration.name.text.as_str())
                    .chain(parts)
                    .collect::<Vec<_>>()
                    .join(".");
                diagnostic = diagnostic.arg("suggestion", &suggestion).help_edits(
                    "import",
                    vec![Edit {
                        span,
                        replacement: suggestion,
                    }],
                );
            }
            return Err(Box::new(diagnostic.build()));
        }
        root.required()
    }

    fn root_file(&self, path: &ModulePath, span: Span) -> Result<Lookup, Box<Diagnostic>> {
        let prefix = self
            .entry
            .display_name
            .rfind('/')
            .and_then(|end| self.entry.display_name.get(..end.saturating_add(1)))
            .unwrap_or("");
        self.file(
            path,
            span,
            FileRoot {
                directory: &self.entry.root,
                canonical: self.root.as_deref(),
                display: prefix,
                package: None,
                requested: path,
            },
        )
    }

    fn package_file(
        &self,
        path: &ModulePath,
        span: Span,
        dependency: &Dependency,
        requested: &ModulePath,
    ) -> Result<Lookup, Box<Diagnostic>> {
        self.file(
            path,
            span,
            FileRoot {
                directory: &dependency.root,
                canonical: Some(&dependency.root),
                display: &dependency.display_root,
                package: Some(dependency),
                requested,
            },
        )
    }

    fn file(
        &self,
        path: &ModulePath,
        span: Span,
        scope: FileRoot<'_>,
    ) -> Result<Lookup, Box<Diagnostic>> {
        let FileRoot {
            directory,
            canonical: root,
            display: prefix,
            package,
            requested,
        } = scope;
        let relative = format!("{}.bnt", path.0.join("/"));
        let missing = || {
            let builder = DiagBuilder::new(DiagCode::E0318)
                .arg("module", requested.dotted())
                .arg(
                    "path",
                    if path.0.is_empty() {
                        format!("{}.bnt", requested.0.join("/"))
                    } else {
                        relative.clone()
                    },
                )
                .arg(
                    "where",
                    if package.is_some() {
                        super::text::PACKAGE_ROOT
                    } else {
                        super::text::ROOT_DIRECTORY
                    },
                )
                .primary(span);
            if let Some(dependency) = package {
                builder
                    .arg("package", &dependency.package_name)
                    .arg("root", &dependency.display_root)
                    .note("package")
            } else {
                builder
            }
        };
        let Some(root) = root else {
            return Ok(Lookup::Missing(Box::new(missing().build())));
        };
        if path.0.is_empty() {
            return Ok(Lookup::Missing(Box::new(missing().build())));
        }
        let mut selected = directory.to_path_buf();
        for (index, part) in path.0.iter().enumerate() {
            let is_dir = index.saturating_add(1) < path.0.len();
            let wanted = if is_dir {
                part.clone()
            } else {
                format!("{part}.bnt")
            };
            let Ok(entries) = self.fs.list_dir(&selected) else {
                return Ok(Lookup::Missing(Box::new(missing().build())));
            };
            if entries
                .iter()
                .any(|entry| entry.name == wanted && entry.is_dir == is_dir)
            {
                selected.push(&wanted);
                continue;
            }
            let mut diagnostic = missing();
            // 診断の候補もファイルシステムの項目の順に依存させない（設計書 02-02）。
            let actual = entries
                .iter()
                .filter(|entry| {
                    entry.is_dir == is_dir
                        && entry.name != wanted
                        && entry.name.eq_ignore_ascii_case(&wanted)
                })
                .map(|entry| &entry.name)
                .min();
            if let Some(actual) = actual {
                diagnostic = diagnostic.arg("actual", actual.clone()).note("case_only");
            } else {
                let candidates = user_candidates(
                    &entries,
                    &wanted,
                    is_dir,
                    requested,
                    index.saturating_add(requested.0.len().saturating_sub(path.0.len())),
                );
                if !candidates.is_empty() {
                    diagnostic = diagnostic
                        .arg("candidates", candidates.join(", "))
                        .note("similar");
                }
            }
            return Ok(Lookup::Missing(Box::new(diagnostic.build())));
        }
        let resolved = self.fs.canonicalize(&selected).map_err(|error| {
            Box::new(
                DiagBuilder::new(DiagCode::E0101)
                    .arg("path", selected.display().to_string())
                    .arg("reason", error.to_string())
                    .primary_label(span, "imported")
                    .note("reason")
                    .build(),
            )
        })?;
        let outside = if !resolved.starts_with(root) {
            let diagnostic = Box::new(
                DiagBuilder::new(DiagCode::E0319)
                    .arg("module", requested.dotted())
                    .arg(
                        "where",
                        if package.is_some() {
                            super::text::PACKAGE_ROOT
                        } else {
                            super::text::ROOT_DIRECTORY
                        },
                    )
                    .arg("path", relative.clone())
                    .arg("target", resolved.display().to_string())
                    .arg("root", root.display().to_string())
                    .primary(span)
                    .note("resolved")
                    .build(),
            );
            if package.is_some() {
                return Err(diagnostic);
            }
            // 根のリンクが依存と同じファイルを指すなら、依存の根を境界として読む。
            // 根として選んだときだけ、根の外の誤りを報告する（設計書 01-03「依存のパッケージの取り込み」）。
            Some(diagnostic)
        } else {
            None
        };
        if self.entry_path.as_ref() == Some(&resolved) {
            return Err(Box::new(
                DiagBuilder::new(DiagCode::E0320)
                    .arg("module", requested.dotted())
                    .primary(span)
                    .note("entry")
                    .build(),
            ));
        }
        let name = if let Some(dependency) = package {
            ModulePath(
                std::iter::once(dependency.declaration.name.text.clone())
                    .chain(path.0.iter().cloned())
                    .collect(),
            )
        } else {
            path.clone()
        };
        Ok(Lookup::Found(
            Pending {
                name,
                kind: if package.is_some() {
                    ModuleKind::Package
                } else {
                    ModuleKind::User
                },
                display: Path::new(prefix).join(relative).display().to_string(),
                content: Content::File(selected),
                package: package.map(|dependency| dependency.config),
            },
            resolved,
            outside,
        ))
    }

    fn stdlib(&self, path: &ModulePath, span: Span) -> Result<Pending, Box<Diagnostic>> {
        let unofficial = path.0.get(1).is_some_and(|name| name == "Unofficial");
        let tail = path
            .0
            .get(if unofficial { 2.. } else { 1.. })
            .unwrap_or(&[]);
        let matched = self.stdlib.iter().find(|source| {
            source
                .path
                .iter()
                .copied()
                .eq(tail.iter().map(String::as_str))
        });
        if let Some(source) = matched.filter(|source| source.unofficial == unofficial) {
            return Ok(Pending::stdlib(source));
        }
        let mut diagnostic = DiagBuilder::new(DiagCode::E0321)
            .arg("module", path.dotted())
            .primary(span);
        if let Some(source) = matched {
            let suggestion = import_name(source);
            let key = if source.unofficial {
                "unofficial"
            } else {
                "standard"
            };
            diagnostic = diagnostic.arg("suggestion", suggestion.clone()).help_edits(
                key,
                vec![Edit {
                    span,
                    replacement: suggestion,
                }],
            );
        } else {
            let mut candidates: Vec<_> = self
                .stdlib
                .iter()
                .filter(|source| {
                    path.0
                        .last()
                        .zip(source.path.last())
                        .is_some_and(|(wanted, actual)| wanted.eq_ignore_ascii_case(actual))
                })
                .map(import_name)
                .collect();
            candidates.sort();
            candidates.dedup();
            let key = if candidates.is_empty() {
                candidates = ranked_candidates(
                    &path.dotted(),
                    self.stdlib.iter().map(import_name).collect(),
                )
                .into_iter()
                .take(3)
                .collect();
                "similar"
            } else {
                "last_segment"
            };
            if !candidates.is_empty() {
                diagnostic = diagnostic.arg(
                    "candidates",
                    candidates
                        .iter()
                        .map(|n| format!("`{n}`"))
                        .collect::<Vec<_>>()
                        .join(", "),
                );
                if let [candidate] = candidates.as_slice() {
                    diagnostic = diagnostic.help_edits(
                        key,
                        vec![Edit {
                            span,
                            replacement: candidate.clone(),
                        }],
                    );
                } else {
                    diagnostic = diagnostic.help(key);
                }
            }
        }
        if self
            .fs
            .list_dir(&self.entry.root)
            .is_ok_and(|entries| entries.iter().any(|entry| entry.name == "Benitoite"))
        {
            diagnostic = diagnostic
                .arg(
                    "path",
                    self.entry.root.join("Benitoite").display().to_string(),
                )
                .note("root_file");
        }
        Err(Box::new(diagnostic.build()))
    }
}

struct FileRoot<'a> {
    directory: &'a Path,
    canonical: Option<&'a Path>,
    display: &'a str,
    package: Option<&'a Dependency>,
    requested: &'a ModulePath,
}

enum Lookup {
    Found(Pending, PathBuf, Option<Box<Diagnostic>>),
    Missing(Box<Diagnostic>),
}

impl Lookup {
    fn required(self) -> Result<Pending, Box<Diagnostic>> {
        match self {
            Self::Found(pending, _, None) => Ok(pending),
            Self::Found(_, _, Some(diagnostic)) => Err(diagnostic),
            Self::Missing(diagnostic) => Err(diagnostic),
        }
    }
}

/// test の入口が根の下にある場合も、設定と依存の表示名を根から組み立てる。
pub(super) fn display_root(entry: &EntrySpec) -> String {
    let relative_parts = entry
        .path
        .strip_prefix(&entry.root)
        .map_or(1, |path| path.components().count());
    Path::new(&entry.display_name)
        .ancestors()
        .nth(relative_parts)
        .unwrap_or_else(|| Path::new(""))
        .display()
        .to_string()
}

pub(super) fn import_span(import: &ImportDecl) -> Span {
    match (import.path.first(), import.path.last()) {
        (Some(first), Some(last)) => first.span.to(last.span),
        _ => import.span,
    }
}

pub(super) fn import_name(source: &StdlibModuleSource) -> String {
    let prefix = if source.unofficial {
        "Benitoite.Unofficial."
    } else {
        "Benitoite."
    };
    format!("{prefix}{}", source.path.join("."))
}

fn user_candidates(
    entries: &[DirEntryName],
    wanted: &str,
    is_dir: bool,
    path: &ModulePath,
    index: usize,
) -> Vec<String> {
    let names = entries
        .iter()
        .filter(|entry| entry.is_dir == is_dir)
        .filter_map(|entry| {
            let segment = if is_dir {
                Some(entry.name.as_str())
            } else {
                entry.name.strip_suffix(".bnt")
            }?;
            if !module_segment(segment) {
                return None;
            }
            Some(entry.name.clone())
        })
        .collect();
    ranked_candidates(wanted, names)
        .into_iter()
        .map(|candidate| {
            let mut name = path.clone();
            if let Some(part) = name.0.get_mut(index) {
                *part = if is_dir {
                    candidate
                } else {
                    candidate
                        .strip_suffix(".bnt")
                        .unwrap_or(&candidate)
                        .to_owned()
                };
            }
            name.dotted()
        })
        .collect()
}

fn module_segment(segment: &str) -> bool {
    segment
        .as_bytes()
        .first()
        .is_some_and(u8::is_ascii_uppercase)
        && segment
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_')
}

fn ranked_candidates(wanted: &str, names: Vec<String>) -> Vec<String> {
    let mut ranked: Vec<_> = names
        .into_iter()
        .filter_map(|name| {
            let distance = edit_distance(wanted, &name);
            (distance <= 2).then_some((distance, name))
        })
        .collect();
    ranked.sort();
    ranked.dedup();
    ranked.into_iter().map(|(_, name)| name).collect()
}

fn edit_distance(left: &str, right: &str) -> usize {
    let mut previous: Vec<_> = (0..=right.len()).collect();
    let mut current = Vec::with_capacity(previous.len());
    for (row, a) in left.bytes().enumerate() {
        current.clear();
        current.push(row.saturating_add(1));
        for (column, b) in right.bytes().enumerate() {
            let above = previous
                .get(column.saturating_add(1))
                .copied()
                .unwrap_or(usize::MAX);
            let diagonal = previous.get(column).copied().unwrap_or(usize::MAX);
            let before = current.last().copied().unwrap_or(usize::MAX);
            current.push(
                above
                    .saturating_add(1)
                    .min(before.saturating_add(1))
                    .min(diagonal.saturating_add(usize::from(a != b))),
            );
        }
        std::mem::swap(&mut previous, &mut current);
    }
    previous.last().copied().unwrap_or(left.len())
}
