//! FIFO の作業一覧と、読み終えた名前からの辺の確定（設計書 02-02「ソースとファイル ID」、02-04）。

use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::path::PathBuf;

use crate::base::source::MAX_SOURCE_BYTES;
use crate::base::{IdGen, Source, SourceKind, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::{lexer, newline, parser};

use super::{
    EntrySpec, ImportLink, LoadOutput, MAX_TOTAL_SOURCE_BYTES, ModuleFs, ModuleInfo, ModuleKind,
    ModulePath, StdlibModuleSource, cycle, find, package, text,
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
    /// パッケージのモジュールでは、依存の設定ファイルの ID を保持する。
    pub package: Option<crate::base::ModuleId>,
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
            package: None,
        }
    }
}

struct Requested {
    span: Span,
    decl: crate::base::NodeId,
    target: Result<Option<ModulePath>, Box<Diagnostic>>,
}

// 上限を超えたソースは ID を持たないので、読めた名前と失敗の理由を別々に保持する
// （設計書 02-02「ソースの大きさの上限」）。
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
    if entry
        .path
        .file_name()
        .is_some_and(|name| name == package::CONFIG_NAME)
    {
        output.diagnostics.push(
            DiagBuilder::new(DiagCode::E0913)
                .arg("path", &entry.display_name)
                .build(),
        );
        return output;
    }
    let mut queue = VecDeque::from([Pending {
        name: ModulePath(Vec::new()),
        kind: ModuleKind::Entry,
        display: entry.display_name.clone(),
        content: Content::File(entry.path.clone()),
        package: None,
    }]);
    let mut scheduled = BTreeSet::from([ModulePath(Vec::new())]);
    for source in stdlib.iter().filter(|source| source.prelude) {
        let pending = Pending::stdlib(source);
        if scheduled.insert(pending.name.clone()) {
            queue.push_back(pending);
        }
    }
    let mut finder = find::Finder::new(entry, stdlib, fs);
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
        diagnostics.extend(package::check_header(&parsed.module, pending.kind));
        // 入口を表に入れてから設定ファイルを読み、import の解決より前に設定を揃える。
        // 設定ファイルにもモジュールの ID を振り、ファイルの ID と一致させる（設計書 02-02）。
        loaded.insert(pending.name.clone(), id);
        output.modules.modules.push(ModuleInfo {
            id,
            name: pending.name,
            kind: pending.kind,
            imports: Vec::new(),
        });
        let mut configs = Vec::new();
        let config = if pending.kind == ModuleKind::Entry {
            read_config(
                entry,
                fs,
                ids,
                &mut output,
                &mut total,
                (file_limit, total_limit),
                None,
            )
        } else {
            None
        };
        if let Some(config) = &config {
            diagnostics.extend(package::check_overlap(
                &parsed.module,
                &config.module,
                &entry.display_name,
            ));
        }
        let mut hashes_valid = true;
        if pending.kind == ModuleKind::Entry {
            // 二か所への記述を報告した場合は入口だけを辿り、根の重なりを重ねて報告しない。
            // language の二か所への記述だけなら、設定ファイルの依存は引き続き読む。
            let entry_dependencies = parsed
                .module
                .header
                .iter()
                .any(|item| matches!(item, crate::syntax::ast::HeaderItem::Dependency(_)));
            let headers = std::iter::once(&parsed.module).chain(
                config
                    .as_ref()
                    .filter(|_| !entry_dependencies)
                    .map(|config| &config.module),
            );
            let mut aliases = BTreeSet::new();
            let mut roots: BTreeMap<PathBuf, &crate::syntax::ast::HeaderBlock> = BTreeMap::new();
            for module in headers {
                // パッケージの依存は先頭の部分の検査で拒否するので、再帰して読まない。
                if module
                    .header
                    .iter()
                    .any(|item| matches!(item, crate::syntax::ast::HeaderItem::Package(_)))
                {
                    continue;
                }
                for item in &module.header {
                    let crate::syntax::ast::HeaderItem::Dependency(block) = item else {
                        continue;
                    };
                    if !aliases.insert(block.name.text.clone()) {
                        continue;
                    }
                    finder.failed_aliases.insert(block.name.text.clone());
                    // path の欠落は E0904 で報告済みなので、読み込みの失敗を重ねない。
                    let Some(location) = package::dependency_location(entry, fs, block) else {
                        continue;
                    };
                    let (root, display_root) = match location {
                        Ok(location) => location,
                        Err(reason) => {
                            diagnostics.push(dependency_error(block, super::io_reason(&reason)));
                            continue;
                        }
                    };
                    if fs
                        .canonicalize(&entry.root)
                        .is_ok_and(|entry_root| entry_root.starts_with(&root))
                    {
                        diagnostics.push(
                            dependency_builder(block, DiagCode::E0922)
                                .note("root")
                                .build(),
                        );
                        continue;
                    }
                    if let Some((_, other)) = roots.iter().find(|(other_root, _)| {
                        root.starts_with(other_root) || other_root.starts_with(&root)
                    }) {
                        diagnostics.push(
                            dependency_builder(block, DiagCode::E0922)
                                .arg("other", &other.name.text)
                                .secondary(other.name.span, "other")
                                .note("dependency")
                                .build(),
                        );
                        continue;
                    }
                    // 設定やハッシュの成否に依らず、正規化できた根どうしの重なりを検査する。
                    roots.insert(root.clone(), block);
                    if let Some(config) = read_config(
                        entry,
                        fs,
                        ids,
                        &mut output,
                        &mut total,
                        (file_limit, total_limit),
                        Some((block, &root, &display_root)),
                    ) {
                        if let Some(package) =
                            config.module.header.iter().find_map(|item| match item {
                                crate::syntax::ast::HeaderItem::Package(package) => Some(package),
                                crate::syntax::ast::HeaderItem::Language(_)
                                | crate::syntax::ast::HeaderItem::Dependency(_) => None,
                            })
                        {
                            let dependency = package::Dependency {
                                declaration: block.clone(),
                                root,
                                display_root,
                                package_name: package.name.text.clone(),
                                config: crate::base::ModuleId::of_file(config.module.file),
                            };
                            if !config.diagnostics.iter().any(Diagnostic::is_error)
                                && let Some(diagnostic) = package::check_hash(&dependency, fs)
                            {
                                diagnostics.push(diagnostic);
                                hashes_valid = false;
                            } else {
                                finder.failed_aliases.remove(&block.name.text);
                                finder.dependencies.push(dependency);
                            }
                        } else if !config.diagnostics.iter().any(Diagnostic::is_error) {
                            diagnostics.push(not_package(block, "no_block"));
                        }
                        configs.push(config);
                    }
                }
            }
        }
        let mut imports = Vec::new();
        // ハッシュの誤りがあれば名前解決へ進めない。未照合のモジュールを読まず、追加の誤りも避ける。
        for import in parsed.module.imports.iter().filter(|_| hashes_valid) {
            let span = find::import_span(import);
            let target = finder.find(import, pending.package).map(|pending| {
                pending.map(|pending| {
                    let name = pending.name.clone();
                    if scheduled.insert(name.clone()) {
                        queue.push_back(pending);
                    }
                    name
                })
            });
            imports.push(Requested {
                span,
                decl: import.id,
                target,
            });
        }
        output.asts.push(parsed.module);
        output.comments.push(parsed.comments);
        file_diagnostics.push(diagnostics);
        requests.push(imports);
        for config in config.into_iter().chain(configs) {
            output.asts.push(config.module);
            output.comments.push(config.comments);
            file_diagnostics.push(config.diagnostics);
            requests.push(Vec::new());
        }
    }

    // ID は読めたソースにだけ振る。辺の確定と読めない import の診断を後に行えば、
    // 読む順と診断の順の両方を守れる。
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
                Ok(None) => None,
                Ok(Some(name)) => {
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

fn read_config(
    entry: &EntrySpec,
    fs: &dyn ModuleFs,
    ids: &mut IdGen,
    output: &mut LoadOutput,
    total: &mut usize,
    limits: (usize, usize),
    dependency: Option<(&crate::syntax::ast::HeaderBlock, &std::path::Path, &str)>,
) -> Option<parser::ParseOutput> {
    let root = dependency.map_or(entry.root.as_path(), |(_, root, _)| root);
    let entries = match fs.list_dir(root) {
        Ok(entries) => entries,
        Err(reason) => {
            output
                .diagnostics
                .push(if let Some((block, _, _)) = dependency {
                    dependency_error(block, super::io_reason(&reason))
                } else {
                    read_error(&root.display().to_string(), &reason.to_string(), None)
                });
            return None;
        }
    };
    if !entries
        .iter()
        .any(|item| item.name == package::CONFIG_NAME && !item.is_dir)
    {
        if let Some((block, _, _)) = dependency {
            output.diagnostics.push(not_package(block, "no_config"));
        }
        return None;
    }
    let path = root.join(package::CONFIG_NAME);
    let display_root = dependency.map_or_else(
        || find::display_root(entry),
        |(_, _, display)| display.to_owned(),
    );
    let display = std::path::Path::new(&display_root)
        .join(package::CONFIG_NAME)
        .display()
        .to_string();
    let bytes = fs
        .read_file(&path)
        .map_err(|reason| {
            if dependency.is_some() {
                super::io_reason(&reason).to_owned()
            } else {
                reason.to_string()
            }
        })
        .and_then(|bytes| {
            *total = check_size(bytes.len(), *total, limits.0, limits.1)?;
            Ok(bytes)
        });
    let bytes = match bytes {
        Ok(bytes) => bytes,
        Err(reason) => {
            output
                .diagnostics
                .push(if let Some((block, _, _)) = dependency {
                    dependency_error(block, &reason)
                } else {
                    read_error(&display, &reason, None)
                });
            return None;
        }
    };
    let file = output
        .sources
        .add(Source::new(display, SourceKind::User, bytes));
    let id = super::ModuleId::of_file(file);
    let source = output.sources.get(file)?;
    let lexed = lexer::lex(file, source.text());
    let mut parsed = parser::parse(
        file,
        SourceKind::User,
        source.text(),
        newline::resolve_newlines(lexed.tokens),
        lexed.comments,
        ids,
    );
    let mut diagnostics = lexed.diagnostics;
    diagnostics.extend(parsed.diagnostics);
    diagnostics.extend(package::check_header(
        &parsed.module,
        if dependency.is_some() {
            ModuleKind::PackageConfig
        } else {
            ModuleKind::Config
        },
    ));
    // 設定ファイルは宣言を持たない。誤りは上で報告したので、後の段へは先頭の部分だけを渡す。
    parsed.module.imports.clear();
    parsed.module.decls.clear();
    output.modules.modules.push(ModuleInfo {
        id,
        name: ModulePath(
            dependency
                .into_iter()
                .map(|(block, _, _)| block.name.text.clone())
                .chain(std::iter::once(package::CONFIG_NAME.into()))
                .collect(),
        ),
        kind: if dependency.is_some() {
            ModuleKind::PackageConfig
        } else {
            ModuleKind::Config
        },
        imports: Vec::new(),
    });
    parsed.diagnostics = diagnostics;
    Some(parsed)
}

fn dependency_error(block: &crate::syntax::ast::HeaderBlock, reason: &str) -> Diagnostic {
    dependency_builder(block, DiagCode::E0916)
        .arg("reason", reason)
        .note("reason")
        .build()
}

fn not_package(block: &crate::syntax::ast::HeaderBlock, note: &'static str) -> Diagnostic {
    dependency_builder(block, DiagCode::E0917)
        .note(note)
        .build()
}

fn dependency_builder(block: &crate::syntax::ast::HeaderBlock, code: DiagCode) -> DiagBuilder {
    let path = block
        .fields
        .iter()
        .find(|field| field.name.text == text::PATH);
    DiagBuilder::new(code)
        .arg("alias", &block.name.text)
        .arg("path", path.map_or("", |field| field.value.value.as_str()))
        .primary(path.map_or(block.name.span, |field| field.value.span))
}
