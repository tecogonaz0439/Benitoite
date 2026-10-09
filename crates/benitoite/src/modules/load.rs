//! FIFO の作業一覧と、読み終えた名前からの辺の確定（設計書 02-02「ソースとファイル ID」、02-04）。

use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::path::PathBuf;

use crate::base::source::MAX_SOURCE_BYTES;
use crate::base::{IdGen, Source, SourceKind, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::{lexer, newline, parser};

use super::{
    EntrySpec, ImportLink, LoadOutput, MAX_TOTAL_SOURCE_BYTES, ModuleFs, ModuleInfo, ModuleKind,
    ModulePath, StdlibModuleSource, cycle, find, text,
};

pub(super) enum Content {
    File(PathBuf),
    Embedded(&'static str),
}

pub(super) struct Pending {
    pub name: ModulePath,
    pub kind: ModuleKind,
    pub display: String,
    pub content: Content,
}

impl Pending {
    pub fn stdlib(source: &StdlibModuleSource) -> Pending {
        Pending {
            name: ModulePath(
                std::iter::once(String::from("Benitoite"))
                    .chain(source.path.iter().map(|part| String::from(*part)))
                    .collect(),
            ),
            kind: if source.prelude {
                ModuleKind::Prelude
            } else {
                ModuleKind::Stdlib
            },
            display: format!("<benitoite>/{}.bnt", source.path.join("/")),
            content: Content::Embedded(source.text),
        }
    }
}

struct Requested {
    span: Span,
    decl: crate::base::NodeId,
    target: Result<ModulePath, Box<Diagnostic>>,
}

// 上限を超えたソースは ID を持たないので、読めた名前と失敗の理由を別々に保持する
// （設計書 02-02「ソースの大きさの上限」、実装プラン F05「作業の一覧とファイル ID」）。
pub(super) fn load(
    entry: &EntrySpec,
    stdlib: &[StdlibModuleSource],
    fs: &dyn ModuleFs,
    ids: &mut IdGen,
) -> LoadOutput {
    load_with_limits(
        entry,
        stdlib,
        fs,
        ids,
        MAX_SOURCE_BYTES,
        MAX_TOTAL_SOURCE_BYTES,
    )
}

pub(super) fn load_with_limits(
    entry: &EntrySpec,
    stdlib: &[StdlibModuleSource],
    fs: &dyn ModuleFs,
    ids: &mut IdGen,
    file_limit: usize,
    total_limit: usize,
) -> LoadOutput {
    let mut output = LoadOutput::default();
    let mut queue = VecDeque::from([Pending {
        name: ModulePath(Vec::new()),
        kind: ModuleKind::Entry,
        display: entry.display_name.clone(),
        content: Content::File(entry.path.clone()),
    }]);
    let mut scheduled = BTreeSet::from([ModulePath(Vec::new())]);
    for source in stdlib.iter().filter(|source| source.prelude) {
        let pending = Pending::stdlib(source);
        if scheduled.insert(pending.name.clone()) {
            queue.push_back(pending);
        }
    }
    let finder = find::Finder::new(entry, stdlib, fs);
    let mut loaded = BTreeMap::new();
    let mut failed = BTreeMap::new();
    let mut file_diagnostics = Vec::new();
    let mut requests = Vec::new();
    let mut total = 0usize;

    while let Some(pending) = queue.pop_front() {
        let bytes = match &pending.content {
            Content::File(path) => fs.read_file(path).map_err(|error| error.to_string()),
            Content::Embedded(text) => Ok(text.as_bytes().to_vec()),
        };
        let bytes = bytes.and_then(|bytes| {
            let next = check_size(bytes.len(), total, file_limit, total_limit)?;
            total = next;
            Ok(bytes)
        });
        let bytes = match bytes {
            Ok(bytes) => bytes,
            Err(reason) => {
                if matches!(pending.kind, ModuleKind::Entry | ModuleKind::Prelude) {
                    output
                        .diagnostics
                        .push(read_error(&pending.display, &reason, None));
                }
                failed.insert(pending.name, (pending.display, reason));
                continue;
            }
        };
        let kind = if matches!(pending.kind, ModuleKind::Prelude | ModuleKind::Stdlib) {
            SourceKind::Prelude
        } else {
            SourceKind::User
        };
        let source = Source::new(pending.display, kind, bytes);
        let file = output.sources.add(source);
        let id = super::ModuleId::of_file(file);
        // add の直後の ID は必ず表にある（設計書 02-02「ソースとファイル ID」）。
        let Some(source) = output.sources.get(file) else {
            continue;
        };
        let lexed = lexer::lex(file, source.text());
        let tokens = newline::resolve_newlines(lexed.tokens);
        let parsed = parser::parse(file, kind, source.text(), tokens, lexed.comments, ids);
        let mut diagnostics = lexed.diagnostics;
        diagnostics.extend(parsed.diagnostics);
        let mut imports = Vec::new();
        for import in &parsed.module.imports {
            let span = find::import_span(import);
            let target = finder.find(import).map(|pending| {
                let name = pending.name.clone();
                if scheduled.insert(name.clone()) {
                    queue.push_back(pending);
                }
                name
            });
            imports.push(Requested {
                span,
                decl: import.id,
                target,
            });
        }
        loaded.insert(pending.name.clone(), id);
        output.modules.modules.push(ModuleInfo {
            id,
            name: pending.name,
            kind: pending.kind,
            imports: Vec::new(),
        });
        output.asts.push(parsed.module);
        output.comments.push(parsed.comments);
        file_diagnostics.push(diagnostics);
        requests.push(imports);
    }

    // ID は読めたソースにだけ振る。辺の確定と読めない import の診断を後に行えば、
    // 読む順と診断の順の両方を守れる（実装プラン F05「診断の順序」）。
    for ((module, mut diagnostics), imports) in output
        .modules
        .modules
        .iter_mut()
        .zip(file_diagnostics)
        .zip(requests)
    {
        for request in imports {
            let target = match request.target {
                Err(diagnostic) => {
                    diagnostics.push(*diagnostic);
                    None
                }
                Ok(name) => {
                    if let Some((display, reason)) = failed.get(&name) {
                        diagnostics.push(read_error(display, reason, Some(request.span)));
                    }
                    loaded.get(&name).copied()
                }
            };
            module.imports.push(ImportLink {
                decl: request.decl,
                target,
            });
        }
        output.diagnostics.extend(diagnostics);
    }
    output
        .diagnostics
        .extend(cycle::detect(&output.modules, &output.asts));
    output
}

fn check_size(
    size: usize,
    total: usize,
    file_limit: usize,
    total_limit: usize,
) -> Result<usize, String> {
    if size > file_limit {
        return Err(String::from(text::SOURCE_TOO_LARGE));
    }
    total
        .checked_add(size)
        .filter(|next| *next <= total_limit)
        .ok_or_else(|| String::from(text::TOTAL_TOO_LARGE))
}

fn read_error(path: &str, reason: &str, span: Option<Span>) -> Diagnostic {
    let mut builder = DiagBuilder::new(DiagCode::E0101)
        .arg("path", path)
        .arg("reason", reason)
        .note("reason");
    if let Some(span) = span {
        builder = builder.primary_label(span, "imported");
    }
    builder.build()
}
