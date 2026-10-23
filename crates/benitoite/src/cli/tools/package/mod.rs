//! 依存の追加・更新と入口の先頭の移動（設計書 06-01「`package` のコマンドライン」、06-09「`benitoite package`」）。

mod edit;
mod effects;
#[cfg(test)]
mod tests;
mod write;

use crate::base::{IdGen, Source, SourceKind, SourceTable};
use crate::cli::{CliEnv, DiagFormat};
use crate::diag::render::{
    TextOptions, escape_terminal_controls, render_json_line, render_one_text,
};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, Severity};
use crate::modules::package::{CONFIG_NAME, compute_hash, hash_diagnostic, source_files};
use crate::modules::{EntrySpec, ModuleFs, ModuleKind, RealFs};
use crate::syntax::header::{EFFECTS, HASH};
use crate::syntax::{
    ast::{HeaderBlock, HeaderItem, Module},
    lexer::lex,
    newline::resolve_newlines,
    parser::parse,
};
use std::collections::{BTreeMap, BTreeSet};
use std::ffi::OsString;
use std::path::{Path, PathBuf};

pub(super) mod text {
    pub const STAGE_PACKAGE: &str = "package";
    pub const ACTION: &str = "expected `add`, `update`, or `move`";
    pub const ADD_ARGS: &str = "expected <alias> --path <directory> [<root or entry>]";
    pub const UPDATE_ARGS: &str = "expected [<alias>] [<root or entry>]";
    pub const MOVE_ARGS: &str = "expected one entry path: a file, not a directory";
    pub const MISSING_PATH: &str = "missing value for `--path`";
    pub const UTF8: &str = "package aliases and --path values must be valid UTF-8";
    pub const ALIAS: &str =
        "invalid dependency alias `{alias}`; use an uppercase identifier other than Benitoite";
    pub const PATH_ONLY_ADD: &str = "`--path` is only accepted by `package add`";
    pub const DEPENDENCY: &str =
        "dependency {alias}\n  path {path}\n  hash {hash}\n  effects {effects}\nend dependency\n";
    pub const PROTOTYPE: &str = "{header}\ndependency {alias}\npath {path}\nend dependency\n";
    pub const PROPOSED: &str = "proposed edit, not written";
    pub const NO_UPDATES: &str = "no dependencies with hash to update\n";
    pub const ADDED: &str = "added dependency {alias} (package {package}) to {file}\n  hash: {hash}\n  effects: {effects}\n  components: {components}\n";
    pub const UPDATED: &str = "updated dependency {alias} (package {package}) in {file}\n  hash: {hash_change}\n  effects: {effects}\n  components: {components}\n";
    pub const UNCHANGED: &str = "unchanged dependency {alias} (package {package}) in {file}\n";
    pub const MOVED: &str = "moved {items} from {entry} to {config}\n";
    pub const NONE: &str = "(none)";
    pub const UNKNOWN: &str = "(not recorded)";
    pub const NO_CHANGES: &str = "(unchanged)";
    pub const COMPONENT_OK: &str = "{path} (no imports)";
    pub const COMPONENT_ERROR: &str = "{path}: {reason}";
    pub const NOT_WASM: &str = "not a WebAssembly component";
    pub const CORE: &str = "a core WebAssembly module, not a component";
    pub const IMPORTS: &str = "component has imports ({count}): {names}";
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Action {
    Add,
    Update,
    Move,
}

pub(super) struct Args {
    pub diagnostics: DiagFormat,
    action: Action,
    alias: Option<String>,
    path: Option<String>,
    target: Option<PathBuf>,
}

fn alias_identifier(value: &str) -> bool {
    value.as_bytes().first().is_some_and(u8::is_ascii_uppercase)
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_')
}
fn valid_alias(value: &str) -> bool {
    alias_identifier(value) && value != "Benitoite"
}

pub(super) fn parse_args(args: Vec<OsString>) -> Result<Args, String> {
    let mut positional = Vec::new();
    let mut path = None;
    let mut diagnostics = DiagFormat::Text;
    let mut seen = BTreeSet::new();
    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        let value = arg.to_string_lossy();
        if !value.starts_with('-') {
            positional.push(arg);
            continue;
        }
        let (name, setting) = value
            .split_once('=')
            .map_or((value.as_ref(), None), |(n, v)| (n, Some(v)));
        if !matches!(name, "--path" | "--diagnostics") {
            return Err(crate::cli::text::UNKNOWN_OPTION.replace("{name}", &value));
        }
        if !seen.insert(name.to_owned()) {
            return Err(crate::cli::text::DUPLICATE_OPTION.replace("{name}", name));
        }
        let setting = match setting {
            Some(value) => value.to_owned(),
            None if name == "--path" => args
                .next()
                .ok_or(text::MISSING_PATH)?
                .into_string()
                .map_err(|_| text::UTF8)?,
            None => {
                return Err(crate::cli::text::BAD_VALUE
                    .replace("{name}", name)
                    .replace("{value}", ""));
            }
        };
        if arg.to_str().is_none() {
            return Err(text::UTF8.into());
        }
        match name {
            "--path" => path = Some(setting),
            "--diagnostics" => {
                diagnostics = match setting.as_str() {
                    "text" => DiagFormat::Text,
                    "json" => DiagFormat::Json,
                    _ => {
                        return Err(crate::cli::text::BAD_VALUE
                            .replace("{name}", name)
                            .replace("{value}", &setting));
                    }
                }
            }
            _ => return Err(text::ACTION.into()),
        }
    }
    let action = match positional.first().and_then(|s| s.to_str()) {
        Some("add") => Action::Add,
        Some("update") => Action::Update,
        Some("move") => Action::Move,
        _ => return Err(text::ACTION.into()),
    };
    let values: Vec<_> = positional.into_iter().skip(1).collect();
    let (alias, target) = match action {
        Action::Add => {
            if path.as_ref().is_none_or(|p| p.is_empty()) || !(1..=2).contains(&values.len()) {
                return Err(text::ADD_ARGS.into());
            }
            let alias = values
                .first()
                .and_then(|s| s.to_str())
                .ok_or(text::UTF8)?
                .to_owned();
            (Some(alias), values.get(1).map(PathBuf::from))
        }
        Action::Update => {
            if path.is_some() {
                return Err(text::PATH_ONLY_ADD.into());
            }
            match values.len() {
                0 => (None, None),
                1 => {
                    if values
                        .first()
                        .and_then(|s| s.to_str())
                        .is_some_and(alias_identifier)
                    {
                        (
                            values.first().and_then(|s| s.to_str()).map(str::to_owned),
                            None,
                        )
                    } else {
                        (None, values.first().map(PathBuf::from))
                    }
                }
                2 => (
                    Some(
                        values
                            .first()
                            .and_then(|s| s.to_str())
                            .ok_or(text::UTF8)?
                            .to_owned(),
                    ),
                    values.get(1).map(PathBuf::from),
                ),
                _ => return Err(text::UPDATE_ARGS.into()),
            }
        }
        Action::Move => {
            if path.is_some() {
                return Err(text::PATH_ONLY_ADD.into());
            }
            if values.len() != 1 {
                return Err(text::MOVE_ARGS.into());
            }
            (None, values.first().map(PathBuf::from))
        }
    };
    if let Some(alias) = &alias
        && !valid_alias(alias)
    {
        return Err(text::ALIAS.replace("{alias}", alias));
    }
    Ok(Args {
        diagnostics,
        action,
        alias,
        path,
        target,
    })
}

struct Document {
    path: PathBuf,
    text: String,
    module: Module,
}
struct Environment {
    stdout: crate::runtime::run::OutputTarget,
    stderr: crate::runtime::run::OutputTarget,
    working_directory: PathBuf,
    color: bool,
}

struct Context<'a> {
    env: &'a Environment,
    format: DiagFormat,
    sources: SourceTable,
    internal: bool,
}
impl Context<'_> {
    fn report(&self, sources: &SourceTable, diagnostic: &Diagnostic) {
        let message = match self.format {
            DiagFormat::Text => render_one_text(
                diagnostic,
                sources,
                TextOptions {
                    color: self.env.color,
                },
            ),
            DiagFormat::Json => format!("{}\n", render_json_line(diagnostic, sources)),
        };
        let _result = self.env.stderr.write_bytes(message.as_bytes());
    }
    fn fail<T>(&self, diagnostic: Diagnostic) -> Result<T, ()> {
        self.report(&self.sources, &diagnostic);
        Err(())
    }
    fn bug<T>(&mut self, message: &str) -> Result<T, ()> {
        self.internal = true;
        self.fail(crate::runtime::report::internal_diagnostic(
            text::STAGE_PACKAGE,
            message,
            None,
            crate::runtime::report::FaultThread::Stage,
        ))
    }
    fn read(&mut self, path: &Path) -> Result<Document, ()> {
        let bytes = match RealFs.read_file(path) {
            Ok(bytes) => bytes,
            Err(error) => return self.fail(read_error(path, &error)),
        };
        self.document(path, bytes)
    }
    fn document(&mut self, path: &Path, bytes: Vec<u8>) -> Result<Document, ()> {
        let file = self.sources.add(Source::new(
            path.display().to_string(),
            SourceKind::User,
            bytes.clone(),
        ));
        let lexed = lex(file, &bytes);
        let parsed = parse(
            file,
            SourceKind::User,
            &bytes,
            resolve_newlines(lexed.tokens),
            lexed.comments,
            lexed.pending,
            &mut IdGen::new(),
        );
        let diagnostics: Vec<_> = lexed
            .diagnostics
            .into_iter()
            .chain(parsed.diagnostics)
            .filter(super::formatter::is_syntax_error)
            .collect();
        if !diagnostics.is_empty() {
            for diagnostic in diagnostics {
                if diagnostic.kind == crate::diag::ReportKind::Internal {
                    self.internal = true;
                }
                self.report(&self.sources, &diagnostic);
            }
            return Err(());
        }
        let text = match String::from_utf8(bytes) {
            Ok(text) => text,
            Err(error) => return self.bug(&error.to_string()),
        };
        Ok(Document {
            path: path.to_owned(),
            text,
            module: parsed.module,
        })
    }
    fn edited(&mut self, original: &Document, header: &str) -> Result<Document, ()> {
        let text = match edit::splice(
            &original.text,
            edit::range(&original.text, &original.module),
            header,
            original.module.file,
        ) {
            Ok(text) => text,
            Err(error) => return self.bug(&error),
        };
        self.document(&original.path, text.into_bytes())
    }
    fn replace(&self, document: &Document) -> Result<(), ()> {
        super::formatter::replace_file_with(
            &document.path,
            &document.path.display().to_string(),
            document.text.as_bytes(),
            DiagCode::E0126,
            "package",
        )
        .map_err(|diagnostic| self.report(&self.sources, &diagnostic))
    }
}
fn read_error(path: &Path, error: &std::io::Error) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0101)
        .arg("path", path.display().to_string())
        .arg("reason", error.to_string())
        .note("reason")
        .build()
}

pub(super) fn run(args: Args, env: CliEnv) -> u8 {
    let stderr = env.stderr.clone();
    let color = env.color;
    let format = args.diagnostics;
    let env = Environment {
        stdout: env.stdout,
        stderr: env.stderr,
        working_directory: env.working_directory,
        color: env.color,
    };
    match crate::pipeline::on_large_stack(|| crate::runtime::panic::catch(|| run_inner(args, env)))
    {
        Ok(Ok(code)) => code,
        Ok(Err(panic)) => {
            crate::cli::write_tool_panic(&stderr, color, format, text::STAGE_PACKAGE, &panic)
        }
        Err(error) => {
            let diagnostic = crate::runtime::report::internal_diagnostic(
                text::STAGE_PACKAGE,
                &error.to_string(),
                None,
                crate::runtime::report::FaultThread::Stage,
            );
            let message = match format {
                DiagFormat::Text => {
                    render_one_text(&diagnostic, &SourceTable::default(), TextOptions { color })
                }
                DiagFormat::Json => format!(
                    "{}\n",
                    render_json_line(&diagnostic, &SourceTable::default())
                ),
            };
            let _result = stderr.write_bytes(message.as_bytes());
            3
        }
    }
}

fn run_inner(args: Args, env: Environment) -> u8 {
    let mut context = Context {
        env: &env,
        format: args.diagnostics,
        sources: SourceTable::default(),
        internal: false,
    };
    let result = execute(&args, &mut context);
    match result {
        Ok(output) => crate::cli::write_plain(&env.stdout, &output),
        Err(()) => {
            if context.internal {
                3
            } else {
                2
            }
        }
    }
}

struct Project {
    entry: EntrySpec,
    document: Option<Document>,
    config: Option<Document>,
}
fn project(args: &Args, context: &mut Context<'_>) -> Result<Project, ()> {
    let target = args.target.as_ref().map_or_else(
        || context.env.working_directory.clone(),
        |p| context.env.working_directory.join(p),
    );
    if args.action == Action::Move && target.file_name().is_some_and(|s| s == CONFIG_NAME) {
        return context.fail(DiagBuilder::new(DiagCode::E0928).build());
    }
    if args.action == Action::Move && target.is_dir() {
        let output = format!(
            "{}\n{}\n",
            crate::cli::text::USAGE_ERROR.replace("{detail}", text::MOVE_ARGS),
            crate::cli::text::SEE_HELP
        );
        let _result = context.env.stderr.write_bytes(output.as_bytes());
        return Err(());
    }
    if target.file_name().is_some_and(|s| s == CONFIG_NAME)
        && let Err(error) = std::fs::metadata(&target)
    {
        return context.fail(read_error(&target, &error));
    }
    let is_root = target.is_dir() || target.file_name().is_some_and(|s| s == CONFIG_NAME);
    let root = if target.is_dir() {
        target.clone()
    } else {
        target.parent().unwrap_or(Path::new(".")).to_owned()
    };
    let root = match RealFs.canonicalize(&root) {
        Ok(root) => root,
        Err(error) => return context.fail(read_error(&root, &error)),
    };
    let entry_path = if is_root {
        root.join(crate::pipeline::ENTRY_FILE_NAME)
    } else {
        target
    };
    let document = if !is_root || entry_path.exists() {
        Some(context.read(&entry_path)?)
    } else {
        None
    };
    let config_path = root.join(CONFIG_NAME);
    let config = match std::fs::symlink_metadata(&config_path) {
        Ok(_) => Some(context.read(&config_path)?),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => None,
        Err(error) => return context.fail(read_error(&config_path, &error)),
    };
    let path = document
        .as_ref()
        .map_or_else(|| synthetic_entry(&root), |d| d.path.clone());
    let entry = EntrySpec {
        display_name: path.display().to_string(),
        path,
        root,
    };
    Ok(Project {
        entry,
        document,
        config,
    })
}

fn synthetic_entry(root: &Path) -> PathBuf {
    let mut suffix = String::new();
    loop {
        let path = root.join(format!(".benitoite-package-entry{suffix}.bnt"));
        if std::fs::symlink_metadata(&path).is_err() {
            return path;
        }
        suffix.push('_');
    }
}

fn dependencies(document: &Document) -> impl Iterator<Item = &HeaderBlock> {
    document.module.header.iter().filter_map(|item| {
        if let HeaderItem::Dependency(block) = item {
            Some(block)
        } else {
            None
        }
    })
}
fn field<'a>(block: &'a HeaderBlock, name: &str) -> Option<&'a str> {
    block
        .fields
        .iter()
        .find(|field| field.name.text == name)
        .map(|field| field.value.value.as_str())
}
fn destination(project: &Project) -> Option<&Document> {
    project
        .document
        .as_ref()
        .filter(|d| dependencies(d).next().is_some())
        .or_else(|| {
            project
                .config
                .as_ref()
                .filter(|d| dependencies(d).next().is_some())
        })
        .or(project.config.as_ref())
        .or(project.document.as_ref())
}
fn execute(args: &Args, context: &mut Context<'_>) -> Result<String, ()> {
    let project = project(args, context)?;
    if args.action == Action::Move {
        return move_header(project, context);
    }
    let Some(original) = destination(&project) else {
        return context.fail(DiagBuilder::new(DiagCode::E0927).note("entry").build());
    };
    if args.action == Action::Add {
        return add(args, &project, original, context);
    }
    update(args, &project, original, context)
}

// 書き込み前の中身だけを上書きし、依存の検査を読み込みと共有する。
struct Overlay {
    files: BTreeMap<PathBuf, Vec<u8>>,
}
impl ModuleFs for Overlay {
    fn read_file(&self, path: &Path) -> std::io::Result<Vec<u8>> {
        self.files
            .get(path)
            .cloned()
            .map_or_else(|| RealFs.read_file(path), Ok)
    }
    fn canonicalize(&self, path: &Path) -> std::io::Result<PathBuf> {
        if self.files.contains_key(path) {
            Ok(path.to_owned())
        } else {
            RealFs.canonicalize(path)
        }
    }
    fn list_dir(&self, path: &Path) -> std::io::Result<Vec<crate::modules::DirEntryName>> {
        RealFs.list_dir(path)
    }
}
fn validate(
    project: &Project,
    documents: &[&Document],
    aliases: &BTreeSet<String>,
    context: &mut Context<'_>,
) -> Result<(), ()> {
    let mut files = BTreeMap::new();
    for document in documents {
        files.insert(document.path.clone(), document.text.as_bytes().to_vec());
        if let Ok(canonical) = RealFs.canonicalize(&document.path) {
            files.insert(canonical, document.text.as_bytes().to_vec());
        }
    }
    if project.document.is_none() {
        files.insert(project.entry.path.clone(), Vec::new());
    }
    let loaded = crate::modules::load_program(
        &project.entry,
        crate::prelude::STDLIB,
        &Overlay { files },
        &mut IdGen::new(),
    );
    let dependency_configs: BTreeSet<_> = loaded
        .asts
        .iter()
        .flat_map(|ast| &ast.header)
        .filter_map(|item| match item {
            HeaderItem::Dependency(block) if aliases.contains(&block.name.text) => {
                crate::modules::package::dependency_location(&project.entry, &RealFs, block)
                    .and_then(Result::ok)
                    // 診断のソース名も表示の根を使うため、正規化で変わる綴りを保つ。
                    .map(|(_, display_root)| {
                        Path::new(&display_root)
                            .join(CONFIG_NAME)
                            .display()
                            .to_string()
                    })
            }
            HeaderItem::Language(_) | HeaderItem::Dependency(_) | HeaderItem::Package(_) => None,
        })
        .collect();
    let mut failed = false;
    for diagnostic in &loaded.diagnostics {
        if diagnostic.severity != Severity::Error {
            continue;
        }
        let relevant = diagnostic.primary.as_ref().is_none_or(|primary| {
            let Some(source) = loaded.sources.get(primary.span.file) else { return true; };
            let is_document = documents.iter().any(|d| d.path.display().to_string() == source.name());
            let dependency_config = dependency_configs.contains(source.name());
            let target_block = loaded.asts.iter().filter(|ast| ast.file == primary.span.file).flat_map(|ast| &ast.header).any(|item| {
                matches!(item, HeaderItem::Dependency(block) if aliases.contains(&block.name.text) && block.span.start <= primary.span.start && primary.span.start <= block.span.end)
            });
            dependency_config || (is_document && (target_block || aliases.is_empty()))
                || matches!(diagnostic.code, Some(DiagCode::E0911))
        });
        if relevant {
            if diagnostic.kind == crate::diag::ReportKind::Internal {
                context.internal = true;
            }
            let mut diagnostic = diagnostic.clone();
            if diagnostic
                .primary
                .as_ref()
                .and_then(|p| loaded.sources.get(p.span.file))
                .is_some_and(|source| {
                    documents
                        .iter()
                        .any(|d| d.path.display().to_string() == source.name())
                })
            {
                diagnostic.notes.push(text::PROPOSED.into());
            }
            context.report(&loaded.sources, &diagnostic);
            failed = true;
        }
    }
    if failed { Err(()) } else { Ok(()) }
}

struct PackageReport {
    name: String,
    hash: String,
    summary: effects::Summary,
    components: String,
}
fn package_report(
    project: &Project,
    block: &HeaderBlock,
    context: &mut Context<'_>,
) -> Result<PackageReport, ()> {
    let Some(location) =
        crate::modules::package::dependency_location(&project.entry, &RealFs, block)
    else {
        return context.bug("missing dependency path after validation");
    };
    let root = match location {
        Ok((root, _)) => root,
        Err(error) => return context.fail(read_error(&project.entry.root, &error)),
    };
    let config = context.read(&root.join(CONFIG_NAME))?;
    let name = config
        .module
        .header
        .iter()
        .find_map(|item| {
            if let HeaderItem::Package(block) = item {
                Some(block.name.text.clone())
            } else {
                None
            }
        })
        .unwrap_or_default();
    let builder = || {
        let builder = DiagBuilder::new(DiagCode::E0920)
            .arg("alias", &block.name.text)
            .arg("package", &name);
        if let Some(field) = block.fields.iter().find(|field| field.name.text == HASH) {
            builder.primary(field.value.span)
        } else {
            builder
        }
    };
    let hash = match compute_hash(&RealFs, &root) {
        Ok(hash) => hash,
        Err(error) => return context.fail(hash_diagnostic(builder(), error)),
    };
    let files = match source_files(&RealFs, &root) {
        Ok(files) => files,
        Err(error) => return context.fail(hash_diagnostic(builder(), error)),
    };
    let mut summary = effects::Summary::default();
    for file in files {
        summary.collect(&context.read(&file)?.module);
    }
    let mut components = Vec::new();
    if !summary.components.is_empty() {
        let engine = match wasmtime::Engine::new(&crate::external::engine_config()) {
            Ok(engine) => engine,
            Err(error) => return context.bug(&error.to_string()),
        };
        for path in summary.components.values() {
            let result = crate::external::path::resolve_path(&RealFs, &root, path, Some(&name))
                .map_err(|d| d.message)
                .and_then(|resolved| RealFs.read_file(&resolved).map_err(|e| e.to_string()))
                .and_then(|bytes| {
                    crate::external::check_component(&engine, &bytes)
                        .map(|_| ())
                        .map_err(component_reason)
                });
            components.push(match result {
                Ok(()) => render(text::COMPONENT_OK, &[("path", &path.value)]),
                Err(reason) => render(
                    text::COMPONENT_ERROR,
                    &[("path", &path.value), ("reason", &reason)],
                ),
            });
        }
    }
    Ok(PackageReport {
        name,
        hash,
        summary,
        components: if components.is_empty() {
            text::NONE.into()
        } else {
            components.join("\n              ")
        },
    })
}
fn component_reason(error: crate::external::check::ComponentError) -> String {
    use crate::external::check::ComponentError;
    match error {
        ComponentError::NotWasm => text::NOT_WASM.into(),
        ComponentError::Core => text::CORE.into(),
        ComponentError::Invalid(reason) => reason,
        ComponentError::Imports {
            count,
            names,
            wasi: _,
        } => text::IMPORTS
            .replace("{count}", &count.to_string())
            .replace("{names}", &names.join(", ")),
    }
}
fn effect_list(effects: &BTreeSet<String>) -> String {
    effects.iter().cloned().collect::<Vec<_>>().join(", ")
}
fn render(template: &str, values: &[(&'static str, &str)]) -> String {
    let values: Vec<_> = values
        .iter()
        .map(|(key, value)| {
            (
                *key,
                if matches!(*key, EFFECTS | "components") {
                    (*value).to_owned()
                } else {
                    escape_terminal_controls(value)
                },
            )
        })
        .collect();
    crate::diag::codes::fill_template(template, &values)
}

fn add(
    args: &Args,
    project: &Project,
    original: &Document,
    context: &mut Context<'_>,
) -> Result<String, ()> {
    let Some(alias) = &args.alias else {
        return context.bug("missing add alias");
    };
    for document in project.document.iter().chain(&project.config) {
        if let Some(block) = dependencies(document).find(|block| &block.name.text == alias) {
            return context.fail(
                DiagBuilder::new(DiagCode::E0923)
                    .arg("alias", alias)
                    .primary(block.name.span)
                    .build(),
            );
        }
    }
    let Some(path) = &args.path else {
        return context.bug("missing add path");
    };
    let bounds = edit::range(&original.text, &original.module);
    let header = crate::diag::codes::fill_template(
        text::PROTOTYPE,
        &[
            ("header", original.text.get(bounds).unwrap_or("").to_owned()),
            ("alias", alias.clone()),
            ("path", edit::quote(path)),
        ],
    );
    let prototype = context.edited(original, &header)?;
    let aliases = BTreeSet::from([alias.clone()]);
    validate(project, &[&prototype], &aliases, context)?;
    let Some(block) = dependencies(&prototype).find(|block| &block.name.text == alias) else {
        return context.bug("added dependency missing after parsing");
    };
    let report = package_report(project, block, context)?;
    let recorded = effect_list(&report.summary.effects);
    let header = format!(
        "{}\n{}",
        original
            .text
            .get(edit::range(&original.text, &original.module))
            .unwrap_or(""),
        edit::dependency(alias, path, &report.hash, &recorded)
    );
    let edited = context.edited(original, &header)?;
    verify_fields(&edited, alias, &report.hash, &recorded, context)?;
    validate(project, &[&edited], &aliases, context)?;
    context.replace(&edited)?;
    Ok(render(
        text::ADDED,
        &[
            ("alias", alias),
            ("package", &report.name),
            ("file", &original.path.display().to_string()),
            (HASH, &report.hash),
            (
                EFFECTS,
                if recorded.is_empty() {
                    text::NONE
                } else {
                    &recorded
                },
            ),
            ("components", &report.components),
        ],
    ))
}
fn verify_fields(
    document: &Document,
    alias: &str,
    hash: &str,
    effects: &str,
    context: &mut Context<'_>,
) -> Result<(), ()> {
    if dependencies(document)
        .filter(|b| {
            b.name.text == alias
                && field(b, HASH) == Some(hash)
                && field(b, EFFECTS) == Some(effects)
        })
        .count()
        != 1
    {
        return context.bug("package fields did not survive editing");
    }
    Ok(())
}
fn update(
    args: &Args,
    project: &Project,
    original: &Document,
    context: &mut Context<'_>,
) -> Result<String, ()> {
    let blocks: Vec<_> = dependencies(original)
        .filter(|block| {
            args.alias.as_ref().map_or_else(
                || field(block, HASH).is_some(),
                |alias| &block.name.text == alias,
            )
        })
        .cloned()
        .collect();
    if let Some(alias) = &args.alias
        && blocks.is_empty()
    {
        return context.fail(
            DiagBuilder::new(DiagCode::E0924)
                .arg("alias", alias)
                .build(),
        );
    }
    if blocks.is_empty() {
        return Ok(text::NO_UPDATES.into());
    }
    let mut current = context.document(&original.path, original.text.as_bytes().to_vec())?;
    let mut output = String::new();
    let aliases: BTreeSet<_> = blocks.iter().map(|b| b.name.text.clone()).collect();
    let mut expected = Vec::new();
    for block in blocks {
        // 古い記録を検証から外し、誤った欄も更新で修正できるようにする。
        let bounds = edit::range(&current.text, &current.module);
        let Some(current_block) = dependencies(&current)
            .find(|b| b.name.text == block.name.text)
            .cloned()
        else {
            return context.bug("dependency disappeared during update");
        };
        let mut header = current.text.get(bounds.clone()).unwrap_or("").to_owned();
        for hash_field in current_block
            .fields
            .iter()
            .filter(|f| f.name.text == HASH || f.name.text == EFFECTS)
            .rev()
        {
            let start = usize::try_from(hash_field.span.start.0)
                .unwrap_or(0)
                .saturating_sub(bounds.start);
            let end = usize::try_from(hash_field.span.end.0)
                .unwrap_or(0)
                .saturating_sub(bounds.start);
            if header.get(start..end).is_none() {
                return context.bug("invalid hash range");
            }
            header.replace_range(start..end, "");
        }
        let prototype = context.edited(&current, &header)?;
        validate(
            project,
            &[&prototype],
            &BTreeSet::from([block.name.text.clone()]),
            context,
        )?;
        let report = package_report(project, &block, context)?;
        let recorded = effect_list(&report.summary.effects);
        let old = field(&block, EFFECTS)
            .filter(|s| crate::syntax::header::valid_effects(s))
            .map(|s| {
                s.split(',')
                    .map(str::trim)
                    .filter(|s| !s.is_empty())
                    .map(str::to_owned)
                    .collect::<BTreeSet<_>>()
            });
        let delta = if let Some(old) = old {
            let mut changes: Vec<_> = report
                .summary
                .effects
                .difference(&old)
                .map(|s| format!("+ {s}"))
                .collect();
            changes.extend(
                old.difference(&report.summary.effects)
                    .map(|s| format!("- {s}")),
            );
            if changes.is_empty() {
                text::NO_CHANGES.into()
            } else {
                changes.join("\n           ")
            }
        } else {
            format!(
                "{} -> {}",
                text::UNKNOWN,
                if recorded.is_empty() {
                    text::NONE
                } else {
                    &recorded
                }
            )
        };
        let unchanged = field(&block, HASH) == Some(report.hash.as_str())
            && field(&block, EFFECTS) == Some(recorded.as_str());
        if unchanged {
            output.push_str(&render(
                text::UNCHANGED,
                &[
                    ("alias", &block.name.text),
                    ("package", &report.name),
                    ("file", &original.path.display().to_string()),
                ],
            ));
            continue;
        }
        let header = match edit::update(
            &current.text,
            &bounds,
            &current_block,
            &report.hash,
            &recorded,
        ) {
            Ok(header) => header,
            Err(error) => return context.bug(&error),
        };
        current = context.edited(&current, &header)?;
        verify_fields(&current, &block.name.text, &report.hash, &recorded, context)?;
        output.push_str(&render(
            if unchanged {
                text::UNCHANGED
            } else {
                text::UPDATED
            },
            &[
                ("alias", &block.name.text),
                ("package", &report.name),
                ("file", &original.path.display().to_string()),
                (
                    "hash_change",
                    &if field(&block, HASH) == Some(report.hash.as_str()) {
                        report.hash.clone()
                    } else {
                        format!(
                            "{} -> {}",
                            field(&block, HASH).unwrap_or(text::NONE),
                            report.hash
                        )
                    },
                ),
                (EFFECTS, &delta),
                ("components", &report.components),
            ],
        ));
        expected.push((block.name.text, report.hash, recorded));
    }
    for (alias, hash, effects) in expected {
        verify_fields(&current, &alias, &hash, &effects, context)?;
    }
    validate(project, &[&current], &aliases, context)?;
    if current.text != original.text {
        context.replace(&current)?;
    }
    Ok(output)
}

fn move_header(project: Project, context: &mut Context<'_>) -> Result<String, ()> {
    let Some(entry) = &project.document else {
        return context.fail(DiagBuilder::new(DiagCode::E0927).note("entry").build());
    };
    if entry.module.header.is_empty() {
        return context.fail(DiagBuilder::new(DiagCode::E0925).build());
    }
    let entry_bounds = edit::range(&entry.text, &entry.module);
    let header = entry.text.get(entry_bounds).unwrap_or("");
    let config = if let Some(config) = &project.config {
        if let Some(item) = config
            .module
            .header
            .iter()
            .find(|item| matches!(item, HeaderItem::Language(_) | HeaderItem::Dependency(_)))
        {
            return context.fail(
                DiagBuilder::new(DiagCode::E0926)
                    .arg("path", config.path.display().to_string())
                    .primary(crate::syntax::header::keyword(item).1)
                    .build(),
            );
        }
        let combined = format!(
            "{}\n{header}",
            config
                .text
                .get(edit::range(&config.text, &config.module))
                .unwrap_or("")
        );
        // 項目がない設定のコメントも、範囲外のバイト列として保持する。
        if config.module.header.is_empty() {
            let text = match edit::splice(
                &config.text,
                edit::config_insertion(&config.text),
                header,
                config.module.file,
            ) {
                Ok(text) => text,
                Err(error) => return context.bug(&error),
            };
            context.document(&config.path, text.into_bytes())?
        } else {
            context.edited(config, &combined)?
        }
    } else {
        let path = project.entry.root.join(CONFIG_NAME);
        let empty = context.document(&path, Vec::new())?;
        context.edited(&empty, header)?
    };
    let emptied = context.edited(entry, "")?;
    let diagnostics = crate::modules::package::check_header(&config.module, ModuleKind::Config);
    if !diagnostics.is_empty() {
        for diagnostic in diagnostics {
            context.report(&context.sources, &diagnostic);
        }
        return Err(());
    }
    if !emptied.module.header.is_empty()
        || config.module.header.len()
            != entry
                .module
                .header
                .len()
                .saturating_add(project.config.as_ref().map_or(0, |d| d.module.header.len()))
    {
        return context.bug("moved header failed verification");
    }
    if project.config.is_some() {
        context.replace(&config)?;
    } else if let Err(diagnostic) = write::create(&config.path, &entry.path, config.text.as_bytes())
    {
        return context.fail(*diagnostic);
    }
    if let Err(mut diagnostic) = super::formatter::replace_file_with(
        &emptied.path,
        &emptied.path.display().to_string(),
        emptied.text.as_bytes(),
        DiagCode::E0126,
        "package",
    ) {
        let restored = if let Some(original) = &project.config {
            super::formatter::replace_file_with(
                &original.path,
                &original.path.display().to_string(),
                original.text.as_bytes(),
                DiagCode::E0126,
                "package",
            )
            .map_err(|d| d.message)
        } else {
            std::fs::remove_file(&config.path).map_err(|e| e.to_string())
        };
        if let Err(reason) = restored {
            diagnostic.notes.push(render(
                DiagCode::E0126
                    .info()
                    .extras
                    .iter()
                    .find(|(key, _)| *key == "rollback")
                    .map_or("", |(_, value)| *value),
                &[
                    ("config", &config.path.display().to_string()),
                    ("rollback_reason", &reason),
                ],
            ));
        }
        return context.fail(*diagnostic);
    }
    let items = entry
        .module
        .header
        .iter()
        .map(|item| match item {
            HeaderItem::Language(_) => "language".into(),
            HeaderItem::Dependency(block) => format!("dependency {}", block.name.text),
            HeaderItem::Package(block) => format!("package {}", block.name.text),
        })
        .collect::<Vec<_>>()
        .join(", ");
    Ok(render(
        text::MOVED,
        &[
            ("items", &items),
            ("entry", &entry.path.display().to_string()),
            ("config", &config.path.display().to_string()),
        ],
    ))
}
