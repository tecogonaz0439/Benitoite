//! import の名前の照合と修正案（設計書 02-04「モジュールの探し方」）。

use std::path::PathBuf;

use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, Edit};
use crate::syntax::ast::ImportDecl;

use super::load::{Content, Pending};
use super::{DirEntryName, EntrySpec, ModuleFs, ModuleKind, ModulePath, StdlibModuleSource};

pub(super) struct Finder<'a> {
    entry: &'a EntrySpec,
    stdlib: &'a [StdlibModuleSource],
    fs: &'a dyn ModuleFs,
    root: Option<PathBuf>,
    entry_path: Option<PathBuf>,
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
        }
    }

    pub fn find(&self, import: &ImportDecl) -> Result<Pending, Box<Diagnostic>> {
        let path = ModulePath(import.path.iter().map(|name| name.text.clone()).collect());
        let span = import_span(import);
        if path.0.first().is_some_and(|name| name == "Benitoite") {
            return self.stdlib(&path, span);
        }
        let relative = format!("{}.bnt", path.0.join("/"));
        let missing = || {
            DiagBuilder::new(DiagCode::E0318)
                .arg("module", path.dotted())
                .arg("path", relative.clone())
                .primary(span)
        };
        let Some(root) = &self.root else {
            return Err(Box::new(missing().build()));
        };
        let mut selected = self.entry.root.clone();
        for (index, part) in path.0.iter().enumerate() {
            let is_dir = index.saturating_add(1) < path.0.len();
            let wanted = if is_dir {
                part.clone()
            } else {
                format!("{part}.bnt")
            };
            let entries = self
                .fs
                .list_dir(&selected)
                .map_err(|_| Box::new(missing().build()))?;
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
                let candidates = user_candidates(&entries, &wanted, is_dir, &path, index);
                if !candidates.is_empty() {
                    diagnostic = diagnostic
                        .arg("candidates", candidates.join(", "))
                        .note("similar");
                }
            }
            return Err(Box::new(diagnostic.build()));
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
        if !resolved.starts_with(root) {
            return Err(Box::new(
                DiagBuilder::new(DiagCode::E0319)
                    .arg("module", path.dotted())
                    .arg("path", relative)
                    .arg("target", resolved.display().to_string())
                    .arg("root", root.display().to_string())
                    .primary(span)
                    .note("resolved")
                    .build(),
            ));
        }
        if self.entry_path.as_ref() == Some(&resolved) {
            return Err(Box::new(
                DiagBuilder::new(DiagCode::E0320)
                    .arg("module", path.dotted())
                    .primary(span)
                    .note("entry")
                    .build(),
            ));
        }
        let prefix = self
            .entry
            .display_name
            .rfind('/')
            .and_then(|end| self.entry.display_name.get(..end.saturating_add(1)))
            .unwrap_or("");
        Ok(Pending {
            name: path,
            kind: ModuleKind::User,
            display: format!("{prefix}{relative}"),
            content: Content::File(selected),
        })
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
            let candidates: Vec<_> = ranked_candidates(
                &path.dotted(),
                self.stdlib.iter().map(import_name).collect(),
            )
            .into_iter()
            .take(3)
            .collect();
            if !candidates.is_empty() {
                diagnostic = diagnostic.arg("candidates", candidates.join(", "));
                if let [candidate] = candidates.as_slice() {
                    diagnostic = diagnostic.help_edits(
                        "similar",
                        vec![Edit {
                            span,
                            replacement: candidate.clone(),
                        }],
                    );
                } else {
                    diagnostic = diagnostic.note("similar");
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
            if !segment
                .as_bytes()
                .first()
                .is_some_and(u8::is_ascii_uppercase)
                || !segment
                    .bytes()
                    .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_')
            {
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
