//! 段をつなぐ公開の関数（設計書 02-01「段と段の間のデータ」「検査と実行の経路」）。

use std::io::Read;
use std::path::Path;
use std::sync::Arc;
use std::{io, panic, thread};

use crate::base::source::MAX_SOURCE_BYTES;
use crate::base::{BytePos, FileId, IdGen, Source, SourceKind, SourceTable};
use crate::bytecode::codegen::{self, CodegenError};
use crate::bytecode::program::CompiledProgram;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::ir::InternalError;
use crate::ir::core_ir::CoreProgram;
use crate::ir::decision;
use crate::ir::desugar;
use crate::resolve::{self, ResolveOutput};
use crate::runtime::report::internal_diagnostic;
use crate::syntax::ast::Program;
use crate::syntax::lexer::lex;
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::{self, ParseOutput};
use crate::syntax::token::Comment;
use crate::typeck::{self, TypeckOutput};

/// 型検査までを誤りなく通ったプログラム。
#[derive(Debug)]
pub struct CheckedProgram {
    /// prelude のソースの AST（ファイルの名前の順）
    pub prelude: Vec<Program>,
    pub user: Program,
    /// 利用者のソースのコメントの一覧（v1 のフォーマッタが使う。最小実行版では使わない）
    pub comments: Vec<Comment>,
    pub resolved: ResolveOutput,
    pub types: TypeckOutput,
}

/// 検査の結果。
#[derive(Debug)]
pub struct CheckResult {
    pub sources: Arc<SourceTable>,
    /// 利用者のソースのファイル ID。読み込みに失敗したときは `None`
    pub user_file: Option<FileId>,
    /// 誤りがあった段の診断。段の中ではソース上の位置（ファイル ID、開始の位置）の順に並べる
    pub diagnostics: Vec<Diagnostic>,
    /// 誤りがなければ `Some`
    pub program: Option<CheckedProgram>,
}

/// コンパイルの失敗。
#[derive(Debug)]
pub enum CompileError {
    /// 処理系の制限（`L` のコード）。`run` は終了状態 2 で終える
    Limit(Vec<Diagnostic>),
    /// 処理系の不具合。`run` は終了状態 3 で終える
    Internal(InternalError),
}

/// ソース読み込みで使う表示文。
pub mod text {
    pub const FILE_TOO_LARGE: &str = "file is larger than 256 MiB";
}

/// AST と中間表現を辿る段のために確保するスタック（ADR 0087）。
const STACK_BYTES: usize = 64 * 1024 * 1024;
/// ソース上限まで読み、上限を超えたか判定するための 1 バイトも読む。
const SOURCE_READ_LIMIT: u64 = 256 * 1024 * 1024 + 1;

/// 借用した入力を保ったまま処理段を大きなスタックで動かす（ADR 0087）。
fn on_large_stack<T: Send>(f: impl FnOnce() -> T + Send) -> Result<T, io::Error> {
    thread::scope(|scope| {
        let handle = thread::Builder::new()
            .stack_size(STACK_BYTES)
            .spawn_scoped(scope, f)?;
        match handle.join() {
            Ok(value) => Ok(value),
            Err(payload) => panic::resume_unwind(payload),
        }
    })
}

/// prelude のソースをファイル名の順にソース表へ加える。
fn add_prelude(sources: &mut SourceTable) -> Vec<FileId> {
    crate::prelude::SOURCES
        .iter()
        .map(|(name, text)| {
            sources.add(Source::new(
                format!("{}{name}", crate::prelude::DISPLAY_PREFIX),
                SourceKind::Prelude,
                text.as_bytes().to_vec(),
            ))
        })
        .collect()
}

/// ファイルを上限より 1 バイト多いところまで読み、過大な入力を拒む。
fn read_user_source(path: &Path) -> Result<Vec<u8>, String> {
    let file = std::fs::File::open(path).map_err(|error| error.to_string())?;
    let mut bytes = Vec::new();
    file.take(SOURCE_READ_LIMIT)
        .read_to_end(&mut bytes)
        .map_err(|error| error.to_string())?;
    if bytes.len() > MAX_SOURCE_BYTES {
        return Err(String::from(text::FILE_TOO_LARGE));
    }
    Ok(bytes)
}

fn read_error(path: &Path, reason: String) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0101)
        .arg("path", path.display().to_string())
        .arg("reason", reason)
        .note("reason")
        .build()
}

fn internal_check(
    sources: Arc<SourceTable>,
    user_file: Option<FileId>,
    message: String,
) -> CheckResult {
    CheckResult {
        sources,
        user_file,
        diagnostics: vec![internal_diagnostic("pipeline", &message, None)],
        program: None,
    }
}

/// 利用者のソースファイルを読み、読み込みから型検査までの段を行う（02-01「検査と実行の経路」の `check`）。
/// 読み込みの誤り（ファイルがない、読めない、MAX_SOURCE_BYTES を超える）は E0101 の診断にする。
/// 表示名はコマンドラインで与えたパスの文字列（`Path::display`）とする。
pub fn check_path(path: &Path) -> CheckResult {
    let mut table = SourceTable::new();
    let prelude_files = add_prelude(&mut table);
    let path_name = path.display().to_string();
    let bytes = match read_user_source(path) {
        Ok(bytes) => bytes,
        Err(reason) => {
            let sources = Arc::new(table);
            return CheckResult {
                sources,
                user_file: None,
                diagnostics: vec![read_error(path, reason)],
                program: None,
            };
        }
    };
    let user_file = table.add(Source::new(path_name, SourceKind::User, bytes));
    let sources = Arc::new(table);
    let thread_sources = Arc::clone(&sources);
    match on_large_stack(move || check_sources(thread_sources, prelude_files, user_file)) {
        Ok(result) => result,
        Err(error) => internal_check(
            sources,
            Some(user_file),
            format!("could not create the pipeline thread: {error}"),
        ),
    }
}

/// ソースの内容を与えて検査する（テストで使う）。`name` は表示名。
pub fn check_text(name: &str, text: &[u8]) -> CheckResult {
    let mut table = SourceTable::new();
    let prelude_files = add_prelude(&mut table);
    let user_file = table.add(Source::new(
        String::from(name),
        SourceKind::User,
        text.to_vec(),
    ));
    let sources = Arc::new(table);
    let thread_sources = Arc::clone(&sources);
    match on_large_stack(move || check_sources(thread_sources, prelude_files, user_file)) {
        Ok(result) => result,
        Err(error) => internal_check(
            sources,
            Some(user_file),
            format!("could not create the pipeline thread: {error}"),
        ),
    }
}

fn check_sources(
    sources: Arc<SourceTable>,
    prelude_files: Vec<FileId>,
    user_file: FileId,
) -> CheckResult {
    let mut ids = IdGen::new();
    let mut prelude = Vec::with_capacity(prelude_files.len());
    let mut diagnostics = Vec::new();

    for file in prelude_files {
        let Some(source) = sources.get(file) else {
            return internal_check(
                sources,
                Some(user_file),
                format!("prelude source {} is missing", file.0),
            );
        };
        let parsed = parse_source(file, source, &mut ids);
        prelude.push(parsed.program);
        diagnostics.extend(parsed.diagnostics);
    }
    let Some(source) = sources.get(user_file) else {
        return internal_check(
            sources,
            Some(user_file),
            format!("user source {} is missing", user_file.0),
        );
    };
    let user = parse_source(user_file, source, &mut ids);
    if !user.diagnostics.is_empty() {
        diagnostics.extend(user.diagnostics);
    }
    if has_errors(&diagnostics) {
        return CheckResult {
            sources,
            user_file: Some(user_file),
            diagnostics,
            program: None,
        };
    }

    let mut resolved = resolve::resolve(&prelude, &user.program, &mut ids);
    sort_diagnostics(&mut resolved.diagnostics);
    diagnostics.append(&mut resolved.diagnostics);
    if has_errors(&diagnostics) {
        return CheckResult {
            sources,
            user_file: Some(user_file),
            diagnostics,
            program: None,
        };
    }

    let (types, mut type_diagnostics) = typeck::typecheck(&prelude, &user.program, &resolved);
    sort_diagnostics(&mut type_diagnostics);
    diagnostics.append(&mut type_diagnostics);
    if has_errors(&diagnostics) {
        return CheckResult {
            sources,
            user_file: Some(user_file),
            diagnostics,
            program: None,
        };
    }

    CheckResult {
        sources,
        user_file: Some(user_file),
        diagnostics,
        program: Some(CheckedProgram {
            prelude,
            user: user.program,
            comments: user.comments,
            resolved,
            types,
        }),
    }
}

fn has_errors(diagnostics: &[Diagnostic]) -> bool {
    diagnostics.iter().any(Diagnostic::is_error)
}

fn sort_diagnostics(diagnostics: &mut [Diagnostic]) {
    diagnostics.sort_by_key(|diagnostic| match diagnostic.primary.as_ref() {
        Some(label) => (true, label.span.file, label.span.start),
        None => (false, FileId(0), BytePos(0)),
    });
}

/// 字句の切り出し（`lex(file, source.text())`）、改行の判定、構文解析を続けて行う。診断は字句の誤りを先に、構文の誤りを後に並べる。
pub fn parse_source(file: FileId, source: &Source, ids: &mut IdGen) -> ParseOutput {
    let lexed = lex(file, source.text());
    let mut lexical_diagnostics = lexed.diagnostics;
    sort_diagnostics(&mut lexical_diagnostics);
    let parsed = parser::parse(
        file,
        source.kind(),
        resolve_newlines(lexed.tokens),
        lexed.comments,
        ids,
    );
    let mut syntax_diagnostics = parsed.diagnostics;
    sort_diagnostics(&mut syntax_diagnostics);
    let mut diagnostics = lexical_diagnostics;
    diagnostics.extend(syntax_diagnostics);
    ParseOutput {
        program: parsed.program,
        comments: parsed.comments,
        diagnostics,
    }
}

/// 脱糖してコア IR を作る。
pub fn desugar_checked(checked: &CheckedProgram) -> Result<CoreProgram, InternalError> {
    match on_large_stack(|| {
        desugar::desugar(
            &checked.prelude,
            &checked.user,
            &checked.resolved,
            &checked.types,
        )
    }) {
        Ok(result) => result,
        Err(error) => Err(InternalError {
            stage: "pipeline",
            message: format!("could not create the pipeline thread: {error}"),
        }),
    }
}

/// 判定の木への変換とコード生成を行う。
pub fn compile(
    core: &CoreProgram,
    sources: Arc<SourceTable>,
) -> Result<CompiledProgram, CompileError> {
    let thread_sources = Arc::clone(&sources);
    match on_large_stack(move || {
        let lower = decision::lower_program(core).map_err(CompileError::Internal)?;
        codegen::codegen(&lower, thread_sources).map_err(|error| match error {
            CodegenError::Limit(diagnostics) => CompileError::Limit(diagnostics),
            CodegenError::Internal(error) => CompileError::Internal(error),
        })
    }) {
        Ok(result) => result,
        Err(error) => Err(CompileError::Internal(InternalError {
            stage: "pipeline",
            message: format!("could not create the pipeline thread: {error}"),
        })),
    }
}

#[cfg(test)]
// テストの失敗は panic で表す（07-03）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::{CheckResult, check_path, check_text, compile, desugar_checked, on_large_stack};
    use crate::diag::{DiagCode, ReportKind};
    use crate::runtime::executor::{ExecMode, ExecOptions};
    use crate::runtime::run::run_with;
    use crate::runtime::test_io::TestIo;
    use crate::syntax::parser::MAX_DEPTH;
    use std::sync::Arc;

    fn codes(result: &CheckResult) -> Vec<Option<DiagCode>> {
        result.diagnostics.iter().map(|diag| diag.code).collect()
    }

    fn checked_program(source: &str) -> (CheckResult, crate::ir::core_ir::CoreProgram) {
        let checked = check_text("pipeline-test.bnt", source.as_bytes());
        assert!(checked.diagnostics.is_empty(), "{:#?}", checked.diagnostics);
        let Some(program) = checked.program.as_ref() else {
            panic!("successful check has no program");
        };
        let core = desugar_checked(program).unwrap();
        (checked, core)
    }

    #[test]
    fn check_text_runs_all_check_stages_and_stops_after_errors() {
        let valid = check_text(
            "hello.bnt",
            b"fn main() -> Unit uses IO { Console.println(\"hi\") }",
        );
        assert!(valid.diagnostics.is_empty());
        assert!(valid.program.is_some());
        assert_eq!(
            valid
                .sources
                .get(valid.user_file.unwrap())
                .map(|source| source.name()),
            Some("hello.bnt")
        );

        let type_error = check_text("bad.bnt", b"fn main() -> Unit { \"wrong\" }");
        assert_eq!(codes(&type_error), vec![Some(DiagCode::E0401)]);
        assert!(type_error.program.is_none());

        let name_error = check_text(
            "name.bnt",
            b"fn main() -> Unit { let value = missing\n  1 }",
        );
        assert!(
            name_error
                .diagnostics
                .iter()
                .any(|diag| diag.code == Some(DiagCode::E0301))
        );
        assert!(
            !name_error
                .diagnostics
                .iter()
                .any(|diag| diag.code == Some(DiagCode::E0401))
        );
        assert!(name_error.program.is_none());
    }

    #[test]
    fn parse_source_orders_lexical_diagnostics_before_syntax_diagnostics() {
        let result = check_text("mixed.bnt", b"fn main() -> Unit { let = 1\n @\n}");
        let lexical = result
            .diagnostics
            .iter()
            .position(|diag| diag.code == Some(DiagCode::E0105));
        let syntax = result.diagnostics.iter().position(|diag| {
            diag.code
                .is_some_and(|code| matches!(code, DiagCode::E0201))
        });
        assert!(lexical.is_some(), "{:#?}", result.diagnostics);
        assert!(syntax.is_some(), "{:#?}", result.diagnostics);
        assert!(lexical < syntax, "{:#?}", result.diagnostics);
    }

    #[test]
    fn check_path_reports_missing_file_without_a_user_file_id() {
        let path = std::env::current_dir()
            .unwrap()
            .join("target")
            .join(format!("t24-missing-{}.bnt", std::process::id()));
        let result = check_path(&path);
        assert_eq!(codes(&result), vec![Some(DiagCode::E0101)]);
        assert!(result.user_file.is_none());
        assert!(result.program.is_none());
        assert_eq!(result.diagnostics[0].kind, ReportKind::Check);
        assert!(result.diagnostics[0].primary.is_none());
        assert_eq!(result.diagnostics[0].notes.len(), 1);
    }

    #[test]
    fn pipeline_compiles_and_runs_a_script() {
        let (checked, core) =
            checked_program("fn main() -> Unit uses IO { Console.println(\"hi\") }");
        let compiled = compile(&core, Arc::clone(&checked.sources)).unwrap();
        let mut io = TestIo::default();
        let result = run_with(
            &compiled,
            &mut io,
            ExecOptions {
                mode: ExecMode::Direct,
                max_call_stack_bytes: crate::vm::DEFAULT_MAX_CALL_STACK,
            },
        );
        assert_eq!(io.stdout, "hi\n");
        assert_eq!(result.exit_code, 0);
        assert!(result.reports.is_empty());
    }

    #[test]
    fn full_pipeline_accepts_deep_ast_and_type_nesting_on_default_test_stack() {
        let depth = usize::try_from(MAX_DEPTH).unwrap();
        let linear_depth = depth.saturating_sub(3);
        let paired_depth = depth.saturating_sub(3) / 2;
        let pattern_depth = depth.saturating_sub(5);
        let mut source = String::new();

        source.push_str(&format!(
            "fn deep_parens() -> Int {{ {}1{} }}\n",
            "(".repeat(linear_depth),
            ")".repeat(linear_depth)
        ));
        source.push_str("fn deep_blocks() -> Int {\n");
        source.push_str(&"{\n".repeat(paired_depth));
        source.push_str("1\n");
        source.push_str(&"}\n".repeat(paired_depth));
        source.push_str("}\n");

        source.push_str(&format!(
            "fn deep_matches() -> Int {{ {}1{} }}\n",
            "match true { _ => ".repeat(paired_depth),
            " }".repeat(paired_depth)
        ));
        source.push_str(&format!(
            "fn deep_pattern(value: {}Int{}) -> Int {{\n  match value {{\n    {}item{} => item\n    _ => 0\n  }}\n}}\n",
            "Option[".repeat(pattern_depth),
            "]".repeat(pattern_depth),
            "Some(".repeat(pattern_depth),
            ")".repeat(pattern_depth)
        ));
        source.push_str("fn main() -> Unit { () }\n");

        let (checked, core) = checked_program(&source);
        compile(&core, Arc::clone(&checked.sources)).unwrap();
    }

    #[test]
    fn deep_mismatched_pattern_reports_one_type_error() {
        let layers = usize::try_from(MAX_DEPTH).unwrap().saturating_sub(5);
        let source = format!(
            "fn main() -> Unit {{\n  match 0 {{\n    {}_{} => ()\n    _ => ()\n  }}\n}}\n",
            "Some(".repeat(layers),
            ")".repeat(layers)
        );
        let result = check_text("deep-mismatch.bnt", source.as_bytes());
        assert_eq!(codes(&result), vec![Some(DiagCode::E0401)]);
        assert!(result.program.is_none());
    }

    #[test]
    fn worker_panic_is_resumed_on_the_calling_thread() {
        let result = std::panic::catch_unwind(|| {
            drop(on_large_stack(|| panic!("worker panic")));
        });
        assert!(result.is_err());
    }
}
