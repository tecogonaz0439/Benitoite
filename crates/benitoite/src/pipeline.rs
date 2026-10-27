//! 段をつなぐ公開の関数（設計書 02-01「段と段の間のデータ」「検査と実行の経路」「誤りが見つかったときの段の進め方」
//! 「関数の呼び出しと処理系のスタック」、02-11「実行を始めるファイルとプログラムの読み込み」）。

use std::path::PathBuf;
use std::sync::Arc;

use crate::base::{FileId, SourceTable};
use crate::diag::Diagnostic;
use crate::ir::InternalError;
use crate::modules::ModuleTable;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Module;
use crate::syntax::token::Comment;
use crate::typeck::TypeckOutput;

/// 本体を検査せず、生成道具へ宣言を渡す入口。
#[path = "pipeline/declarations.rs"]
pub mod declarations;
#[path = "pipeline/source_location.rs"]
pub(crate) mod source_location;

/// 検査・脱糖・コンパイルの段を動かすスレッドのスタックの大きさ（64 MiB。02-01「関数の呼び出しと処理系のスタック」）。
pub const STAGE_STACK_BYTES: usize = 64 * 1024 * 1024;

/// ディレクトリを指定したときに実行を始めるファイルの名前（06-01「ディレクトリの指定（初回リリース版）」）。
pub const ENTRY_FILE_NAME: &str = "main.bnt";

/// 検査の選択肢。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct CheckOptions {
    /// `main` の有無と形を検査する。`check`・`run` で真、`test` で偽（設計書 02-01「検査と実行の経路」）
    pub require_main: bool,
    /// `--deny-warnings`（02-01「誤りが見つかったときの段の進め方」）
    pub deny_warnings: bool,
}

/// 型検査までを誤りなく通ったプログラム。
#[derive(Debug)]
pub struct CheckedProgram {
    pub modules: ModuleTable,
    /// モジュールごとの AST。添字はモジュールの ID の値（設計書 02-04「モジュールの表」）
    pub asts: Vec<Module>,
    /// モジュールごとのコメントの一覧（フォーマッタは使わない。フォーマッタは `lex` と `parse` を直接呼ぶ）
    pub comments: Vec<Vec<Comment>>,
    pub resolved: ResolveOutput,
    pub types: TypeckOutput,
}

/// 検査の結果。
#[derive(Debug)]
pub struct CheckResult {
    pub sources: Arc<SourceTable>,
    /// 実行を始めるファイルのファイル ID。読めなかったときは `None`
    pub entry: Option<FileId>,
    /// 誤りと警告。段の順に、同じ段の中ではファイル ID の順に、同じファイルの中ではソース上の位置の順に並べる
    /// （02-10「文章の形式」）。標準ライブラリのソースの中の警告は含めない（02-10「警告の扱い」）
    pub diagnostics: Vec<Diagnostic>,
    /// 誤りがなければ `Some`。`deny_warnings` のときは、警告もなければ `Some`
    pub program: Option<CheckedProgram>,
    /// 区間解析の範囲と件数。警告を誤りに昇格しても保持する。
    pub interval_analysis: crate::typeck::IntervalAnalysis,
}

impl CheckResult {
    /// 誤りの数（`--deny-warnings` で誤りにした警告を含む）。
    pub fn error_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.is_error()).count()
    }

    pub fn warning_count(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.is_warning()).count()
    }
}

/// コンパイルの失敗。
#[derive(Debug)]
pub enum CompileError {
    /// 処理系の制限（`L` のコード）。`run` は終了状態 2 で終える
    Limit(Vec<Diagnostic>),
    /// 処理系の不具合。`run` は終了状態 3 で終える
    Internal(InternalError),
}

/// 実行を始めるファイルを決められない（CLI の使い方の誤り。終了状態 2。06-01「ディレクトリの指定（初回リリース版）」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum EntryError {
    /// 指定したディレクトリに `main.bnt` がない
    NoMainFile { dir: PathBuf },
}

use std::path::Path;

use crate::bytecode::program::CompiledProgram;
use crate::ir::core_ir::CoreProgram;
use crate::modules::{EntrySpec, ModuleFs};

/// コマンドラインで与えたパスから、実行を始めるファイルを決める（06-01「ディレクトリの指定（初回リリース版）」、02-02「ソースとファイル ID」の表示名）。
/// ディレクトリなら、その下の `main.bnt` を読むファイルとし、表示名をディレクトリのパスに `main.bnt` を続けた名前にする。
/// ディレクトリに `main.bnt` がなければ `EntryError::NoMainFile`。ファイル（と、存在しないパス）はそのまま読むファイルとし、
/// 表示名はパスの文字列（`Path::display`）とする。存在しないパスの誤りは、読み込みの段が E0101 にする。
/// 根のディレクトリは、読むファイルのあるディレクトリ（パスに親がなければ `.`）とする。
pub fn entry_spec(path: &Path) -> Result<EntrySpec, EntryError> {
    let path = if path.is_dir() {
        let main = path.join(ENTRY_FILE_NAME);
        if !main.is_file() {
            return Err(EntryError::NoMainFile {
                dir: path.to_path_buf(),
            });
        }
        main
    } else {
        path.to_path_buf()
    };
    let root = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."))
        .to_path_buf();
    Ok(EntrySpec {
        display_name: path.display().to_string(),
        path,
        root,
    })
}

/// 実行を始めるファイルから、読み込み・字句解析・構文解析・名前解決・型検査（定数の評価を含む）を行う
/// （02-01「検査と実行の経路」の `check`）。標準ライブラリのソースは `prelude::STDLIB` から読み込みの段に渡す。
/// 段の中身は `STAGE_STACK_BYTES` のスタックを持つスレッドで行う（02-01「関数の呼び出しと処理系のスタック」）。そのスレッドの panic は段のスレッドの
/// 中で捕らえ、報告の種類が `Internal` の診断（段は `check`、スレッドは `Stage`）にして `diagnostics` に入れて返す。
pub fn check(entry: &EntrySpec, fs: &(dyn ModuleFs + Sync), opts: CheckOptions) -> CheckResult {
    check_with_external_compilation_count(entry, fs, opts).0
}

/// test の静的な外部照合のコンパイル数を、実行用コンパイルと分ける。
pub(crate) fn check_with_external_compilation_count(
    entry: &EntrySpec,
    fs: &(dyn ModuleFs + Sync),
    opts: CheckOptions,
) -> (CheckResult, u64) {
    check_with_source_origin(entry, fs, opts, None)
}

// docの位置対応は型検査・定数評価より前に使う。実行用の値を後から修正しない
// （設計書 02-04「位置の式の事前展開」）。
pub(crate) fn check_with_source_origin(
    entry: &EntrySpec,
    fs: &(dyn ModuleFs + Sync),
    opts: CheckOptions,
    origin: Option<source_location::DocOrigin<'_>>,
) -> (CheckResult, u64) {
    let mut compilations = 0;
    let result = match on_large_stack(|| {
        crate::runtime::panic::catch(|| {
            check_stages_counted(entry, fs, opts, &mut compilations, origin)
        })
    }) {
        Ok(Ok(result)) => result,
        Ok(Err(panic)) => CheckResult {
            sources: Arc::new(SourceTable::new()),
            entry: None,
            diagnostics: vec![crate::runtime::report::internal_diagnostic(
                "check",
                &panic.message,
                Some(&panic),
                crate::runtime::report::FaultThread::Stage,
            )],
            interval_analysis: Default::default(),
            program: None,
        },
        Err(error) => CheckResult {
            sources: Arc::new(SourceTable::new()),
            entry: None,
            diagnostics: vec![crate::runtime::report::internal_diagnostic(
                "check",
                &error.to_string(),
                None,
                crate::runtime::report::FaultThread::Stage,
            )],
            interval_analysis: Default::default(),
            program: None,
        },
    };
    (result, compilations)
}

/// `entry_spec` と本番のファイルシステム（`RealFs`）で `check` を行う。
pub fn check_path(path: &Path, opts: CheckOptions) -> Result<CheckResult, EntryError> {
    Ok(check(&entry_spec(path)?, &crate::modules::RealFs, opts))
}

/// ファイルシステムを使わずに検査する（テストで使う）。`files` はパスと内容の組で、最初の要素が実行を始めるファイルである。
/// パスは仮の根のディレクトリからの相対パス（`main.bnt`、`Lib/Text.bnt`）で、表示名はそのパスとする。
pub fn check_files(files: &[(&str, &[u8])], opts: CheckOptions) -> CheckResult {
    let (entry, fs) = memory_entry(files);
    check(&entry, &fs, opts)
}

fn memory_entry(files: &[(&str, &[u8])]) -> (EntrySpec, MemoryFs) {
    let root = PathBuf::from("/root");
    let fs = MemoryFs {
        files: files
            .iter()
            .map(|(path, bytes)| (root.join(path), bytes.to_vec()))
            .collect(),
    };
    let name = files.first().map_or("main.bnt", |(name, _)| *name);
    (
        EntrySpec {
            path: root.join(name),
            display_name: name.to_owned(),
            root,
        },
        fs,
    )
}

/// 段のスレッドを使わずに、呼んだスレッドで `check` の段を行う。スタックの消費を測る開発用の例
/// （`examples/stack_probe.rs`）のための入口で、本番の経路は `check` を使う（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[doc(hidden)]
pub fn check_text_on_current_thread(name: &str, text: &[u8], opts: CheckOptions) -> CheckResult {
    let (entry, fs) = memory_entry(&[(name, text)]);
    check_stages(&entry, &fs, opts)
}

/// 一つのファイルだけからなるプログラムを検査する（`check_files` の略記。テストで使う）。`name` は表示名。
pub fn check_text(name: &str, text: &[u8], opts: CheckOptions) -> CheckResult {
    check_files(&[(name, text)], opts)
}

/// 脱糖してコア IR を作る（設計書 02-06「脱糖」）。`STAGE_STACK_BYTES` のスタックを持つスレッドで行う。
pub fn desugar_checked(checked: &CheckedProgram) -> Result<CoreProgram, InternalError> {
    on_large_stack(|| {
        crate::ir::desugar::desugar(
            &checked.modules,
            &checked.asts,
            &checked.resolved,
            &checked.types,
        )
    })
    .map_err(|error| InternalError {
        stage: "desugar",
        message: error.to_string(),
    })?
}

/// 判定の木への変換（設計書 02-06「判定の木への変換」）とコード生成（設計書 02-07「コード生成」）を行う。
/// `STAGE_STACK_BYTES` のスタックを持つスレッドで行う。
pub fn compile(
    core: &CoreProgram,
    sources: Arc<SourceTable>,
) -> Result<CompiledProgram, CompileError> {
    on_large_stack(|| {
        let lower = crate::ir::decision::lower_program(core).map_err(|error| match error {
            crate::ir::decision::LowerError::Limit(diags) => CompileError::Limit(diags),
            crate::ir::decision::LowerError::Internal(error) => CompileError::Internal(error),
        })?;
        crate::bytecode::codegen::codegen(&lower, sources).map_err(|error| match error {
            crate::bytecode::codegen::CodegenError::Limit(diags) => CompileError::Limit(diags),
            crate::bytecode::codegen::CodegenError::Internal(error) => {
                CompileError::Internal(error)
            }
        })
    })
    .map_err(|error| {
        CompileError::Internal(InternalError {
            stage: "codegen",
            message: error.to_string(),
        })
    })?
}

// 借用したファイルシステムも段に渡せるよう scoped thread を使う（設計書 02-01「関数の呼び出しと処理系のスタック」）。
pub(super) fn on_large_stack<T: Send>(f: impl FnOnce() -> T + Send) -> std::io::Result<T> {
    std::thread::scope(|scope| {
        let handle = std::thread::Builder::new()
            .stack_size(STAGE_STACK_BYTES)
            .spawn_scoped(scope, f)?;
        match handle.join() {
            Ok(value) => Ok(value),
            Err(payload) => std::panic::resume_unwind(payload),
        }
    })
}

fn check_stages(entry: &EntrySpec, fs: &dyn ModuleFs, opts: CheckOptions) -> CheckResult {
    check_stages_counted(entry, fs, opts, &mut 0, None)
}

fn check_stages_counted(
    entry: &EntrySpec,
    fs: &dyn ModuleFs,
    opts: CheckOptions,
    compilations: &mut u64,
    origin: Option<source_location::DocOrigin<'_>>,
) -> CheckResult {
    let mut ids = crate::base::IdGen::new();
    let mut loaded = crate::modules::load_program(entry, crate::prelude::STDLIB, fs, &mut ids);
    let hidden_warnings: std::collections::BTreeSet<_> = loaded
        .modules
        .iter()
        .filter(|module| {
            matches!(
                module.kind,
                crate::modules::ModuleKind::Package | crate::modules::ModuleKind::PackageConfig
            )
        })
        .map(|module| module.id.file())
        .collect();
    let sources = Arc::new(loaded.sources);
    let entry_file = sources
        .get(FileId(0))
        .filter(|s| s.kind() == crate::base::SourceKind::User)
        .map(|_| FileId(0));
    let mut result = CheckResult {
        sources,
        entry: entry_file,
        diagnostics: Vec::new(),
        interval_analysis: Default::default(),
        program: None,
    };
    append_stage(&mut result, loaded.diagnostics, &hidden_warnings);
    if !result.diagnostics.iter().any(Diagnostic::is_error) {
        let mut resolved =
            crate::resolve::resolve(&loaded.modules, &loaded.asts, &result.sources, &mut ids);
        append_stage(
            &mut result,
            std::mem::take(&mut resolved.diagnostics),
            &hidden_warnings,
        );
        if !result.diagnostics.iter().any(Diagnostic::is_error) {
            let diagnostics = source_location::expand(
                &loaded.modules,
                &mut loaded.asts,
                &result.sources,
                &mut resolved,
                &mut ids,
                origin,
            );
            append_stage(&mut result, diagnostics, &hidden_warnings);
            // 位置の式の誤りはErrorへ置換済みなので、独立した型の誤りも報告する。
            let (types, diagnostics) = crate::typeck::typecheck(
                &loaded.modules,
                &loaded.asts,
                &result.sources,
                &resolved,
                opts.require_main,
            );
            result.interval_analysis = types.interval_analysis();
            append_stage(&mut result, diagnostics, &hidden_warnings);
            if !result.diagnostics.iter().any(Diagnostic::is_error) {
                let (diagnostics, count) = crate::external::check::check_externals_counted(
                    entry,
                    fs,
                    &loaded.modules,
                    &loaded.asts,
                    &result.sources,
                    &mut resolved,
                    &types,
                );
                *compilations = compilations.saturating_add(count);
                append_stage(&mut result, diagnostics, &hidden_warnings);
            }
            if !result.diagnostics.iter().any(Diagnostic::is_error) {
                result.program = Some(CheckedProgram {
                    modules: loaded.modules,
                    asts: loaded.asts,
                    comments: loaded.comments,
                    resolved,
                    types,
                });
            }
        }
    }
    // 標準ライブラリと依存の警告を除いた後に deny を適用する（設計書 02-10「警告の扱い」）。
    if opts.deny_warnings {
        for diag in &mut result.diagnostics {
            if diag.is_warning() {
                diag.deny_warning();
            }
        }
        if result.error_count() > 0 {
            result.program = None;
        }
    }
    result
}

fn append_stage(
    result: &mut CheckResult,
    mut diagnostics: Vec<Diagnostic>,
    hidden_warnings: &std::collections::BTreeSet<FileId>,
) {
    diagnostics.retain(|diag| {
        !diag.is_warning()
            || !diag.primary.as_ref().is_some_and(|label| {
                hidden_warnings.contains(&label.span.file)
                    || result
                        .sources
                        .get(label.span.file)
                        .is_some_and(|s| s.kind() == crate::base::SourceKind::Prelude)
            })
    });
    diagnostics.sort_by_key(|diag| {
        diag.primary
            .as_ref()
            .map(|label| (label.span.file, label.span.start))
            .map_or(
                (true, FileId(0), crate::base::BytePos(0)),
                |(file, start)| (false, file, start),
            )
    });
    result.diagnostics.extend(diagnostics);
}

// 公開の check_files はテスト用モジュールに依存できないため、ファイルだけを持つ実装を置く。
struct MemoryFs {
    files: std::collections::BTreeMap<PathBuf, Vec<u8>>,
}
impl ModuleFs for MemoryFs {
    fn read_file(&self, path: &Path) -> std::io::Result<Vec<u8>> {
        self.files
            .get(path)
            .cloned()
            .ok_or_else(|| std::io::ErrorKind::NotFound.into())
    }
    fn canonicalize(&self, path: &Path) -> std::io::Result<PathBuf> {
        Ok(path.to_path_buf())
    }
    fn list_dir(&self, dir: &Path) -> std::io::Result<Vec<crate::modules::DirEntryName>> {
        let mut entries = std::collections::BTreeMap::new();
        for path in self.files.keys() {
            if let Ok(relative) = path.strip_prefix(dir) {
                let mut components = relative.components();
                if let Some(name) = components.next().and_then(|c| c.as_os_str().to_str()) {
                    entries.insert(name.to_owned(), components.next().is_some());
                }
            }
        }
        Ok(entries
            .into_iter()
            .map(|(name, is_dir)| crate::modules::DirEntryName { name, is_dir })
            .collect())
    }
}

#[cfg(test)]
#[path = "../examples/stack_probe/support.rs"]
mod stack_test_inputs;

#[cfg(test)]
#[path = "pipeline/interval_inventory.rs"]
mod interval_inventory;

#[cfg(test)]
mod tests {

    // 関門: 公開の検査の入口が段の順、警告の扱い、深い入力への対応を守る。
    // 各段の単独のテストは段の接続と deny の適用順を確かめない（設計書 07-03）。
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    use crate::diag::DiagCode;
    fn opts(deny_warnings: bool) -> CheckOptions {
        CheckOptions {
            require_main: true,
            deny_warnings,
        }
    }
    // 明示した上限で全段をつなぎ、診断による早期終了を成功と取り違えない。
    // 既存の段のスレッドのテストでは、各段の枠が大きくなる退行を捕まえられない
    // （設計書 02-01「関数の呼び出しと処理系のスタック」、07-03「テストの設計の原則」）。
    const MEASURED_STACK_BYTES: usize = 16 * 1024 * 1024;

    fn assert_stages_fit_measured_stack(shapes: &[&'static str]) {
        for &shape in shapes {
            let depth = stack_test_inputs::limit(shape, crate::syntax::parser::MAX_DEPTH).unwrap();
            let source = stack_test_inputs::source(shape, depth).unwrap();
            std::thread::Builder::new()
                .stack_size(MEASURED_STACK_BYTES)
                .spawn(move || {
                    let result = check_text_on_current_thread(
                        "deep.bnt",
                        source.as_bytes(),
                        CheckOptions {
                            require_main: false,
                            deny_warnings: false,
                        },
                    );
                    assert!(
                        result.diagnostics.is_empty(),
                        "{shape}: {:?}",
                        result.diagnostics
                    );
                    let program = result
                        .program
                        .as_ref()
                        .expect("check must produce a program");
                    let core = crate::ir::desugar::desugar(
                        &program.modules,
                        &program.asts,
                        &program.resolved,
                        &program.types,
                    )
                    .expect("desugaring must succeed");
                    let lower =
                        crate::ir::decision::lower_program(&core).expect("lowering must succeed");
                    let compiled =
                        crate::bytecode::codegen::codegen(&lower, Arc::clone(&result.sources))
                            .expect("code generation must succeed");
                    // AST と IR をスレッドの外へ返さず、破棄の退行も同じ上限の中で捕まえる
                    // （設計書 02-03「入れ子の深さ」）。
                    drop((compiled, lower, core, result));
                })
                .expect("measured-stack thread must start")
                .join()
                .expect("stages must finish on the measured stack");
        }
    }

    #[test]
    fn stages_fit_the_measured_stack_for_statement_sequences() {
        assert_stages_fit_measured_stack(&["statements"]);
    }

    #[test]
    #[ignore = "long: wide expressions require repeated type and liveness traversal"]
    fn stages_fit_the_measured_stack_for_flat_sequences() {
        assert_stages_fit_measured_stack(&["list", "arguments", "fields"]);
    }

    #[test]
    fn stages_fit_the_measured_stack_through_deep_branches() {
        assert_stages_fit_measured_stack(&[
            "if",
            "else-if",
            "match-body",
            "match-subject",
            "if-comparison",
            "else-if-comparison",
            "match-integer-body",
            "match-integer-subject",
        ]);
    }

    #[test]
    fn stages_fit_the_measured_stack_through_guard_fallbacks() {
        assert_stages_fit_measured_stack(&["guards"]);
    }

    #[test]
    fn stages_fit_the_measured_stack_through_deep_operators() {
        assert_stages_fit_measured_stack(&[
            "call",
            "binary-right",
            "binary-left",
            "pipe",
            "unary",
            "parentheses",
        ]);
    }

    #[test]
    #[ignore = "long: nested record types require repeated traversal"]
    fn stages_fit_the_measured_stack_through_deep_records() {
        assert_stages_fit_measured_stack(&["record", "record-base"]);
    }

    #[test]
    #[ignore = "long: nested Lazy types require repeated traversal"]
    fn stages_fit_the_measured_stack_through_deep_blocks() {
        assert_stages_fit_measured_stack(&["lambda", "with", "lazy", "handle", "try"]);
    }

    #[test]
    fn stages_fit_the_measured_stack_through_recursive_types() {
        assert_stages_fit_measured_stack(&["list-type", "function-type"]);
    }

    #[test]
    #[ignore = "long: nested pattern coverage is expensive"]
    fn stages_fit_the_measured_stack_through_nested_patterns() {
        assert_stages_fit_measured_stack(&["constructor-pattern", "list-pattern"]);
    }

    #[test]
    #[ignore = "long: nested list types and pattern coverage are expensive"]
    fn stages_fit_the_measured_stack_through_nested_lists() {
        assert_stages_fit_measured_stack(&["nested-list"]);
    }

    #[test]
    fn u3_sources_import_names_and_record_tags_pass_check() {
        // 関門: 公開の検査で標準ライブラリの各モジュールを実際に読み、利用者から見える型と取り込み名を
        // 守る。ソースと Rust の表の照合は、型検査や Clock の別名の取り込みには届かない。
        let main = "function main() -> Unit\nend function\n";
        let mut source = String::new();
        for module in crate::prelude::STDLIB.iter().filter(|m| !m.prelude) {
            let import = format!(
                "import Benitoite.{}{}\n",
                if module.unofficial { "Unofficial." } else { "" },
                module.path.join(".")
            );
            let alone = check_files(
                &[("main.bnt", (import.clone() + main).as_bytes())],
                opts(false),
            );
            assert_eq!(
                alone.error_count(),
                0,
                "{}: {:#?}",
                module.path.join("."),
                alone.diagnostics
            );
            assert!(alone.program.is_some());
            source.push_str(&import);
        }
        source.push_str(main);
        let result = check_files(&[("main.bnt", source.as_bytes())], opts(false));
        assert_eq!(result.error_count(), 0, "{:#?}", result.diagnostics);
        let program = result.program.unwrap();
        assert_eq!(
            program.modules.iter().count(),
            crate::prelude::STDLIB.len() + 1
        );
        for name in [
            "IO.File.Info",
            "IO.Process.Command",
            "IO.Process.Output",
            "Json.ParseError",
            "Csv.ParseError",
            "Time.Instant",
            "Time.DateTime",
            "Network.Http.Request",
            "Network.Http.Response",
            "Network.Http.ClientRequest",
        ] {
            let id = program
                .resolved
                .stdlib(&format!("Benitoite.{name}"))
                .unwrap();
            let record = program.types.adts.get(id).unwrap();
            assert!(record.record.is_some(), "{name}");
            assert_eq!(record.ctors.len(), 1, "{name}");
            assert_eq!(
                record.ctors[0].tag,
                crate::builtins::table::tags::RECORD,
                "{name}"
            );
        }
        for name in [
            "Time",
            "IO.Random",
            "Path",
            "Json",
            "Regex",
            "Csv",
            "Encoding",
            "Hash",
            "Network.Http",
        ] {
            let wrong = format!("import Benitoite.{name}\n{main}");
            let result = check_files(&[("main.bnt", wrong.as_bytes())], opts(false));
            assert_eq!(result.error_count(), 1, "{name}: {:#?}", result.diagnostics);
            assert_eq!(result.diagnostics[0].code, Some(DiagCode::E0321));
        }
        let prelude = r#"
function bytes() -> Bytes
  return Bytes.empty()
end function
function order() -> ByteOrder
  return ByteOrder.LittleEndian
end function
function kind(error: NetworkError) -> NetworkErrorKind
  return NetworkError.kind(error)
end function
function main() -> Unit
end function
"#;
        let result = check_files(&[("main.bnt", prelude.as_bytes())], opts(false));
        assert_eq!(result.error_count(), 0, "{:#?}", result.diagnostics);
        assert!(result.program.is_some());
        let clock = r#"
import Benitoite.Unofficial.IO.Clock
import Benitoite.Unofficial.Time
function now() -> Time.Instant uses Clock.Time
  return Clock.now()
end function
function main() -> Unit
end function
"#;
        let result = check_files(&[("main.bnt", clock.as_bytes())], opts(false));
        assert_eq!(result.error_count(), 0, "{:#?}", result.diagnostics);
        assert!(result.program.is_some());
    }
    #[test]
    fn checking_sorts_each_stage_and_stops_before_later_errors() {
        let positions_of = |result: &CheckResult| {
            result
                .diagnostics
                .iter()
                .map(|d| {
                    let span = d.primary.as_ref().unwrap().span;
                    (span.file, span.start)
                })
                .collect::<Vec<_>>()
        };
        let result = check_files(&[
            ("main.bnt", b"import Lib.Text\nfunction main() -> Unit\n bind _ <- missing1\n bind _ <- missing2\nend function\n"),
            ("Lib/Text.bnt", b"public function text() -> Unit\n bind _ <- missing3\n bind _ <- missing4\nend function\n"),
        ], opts(false));
        assert!(result.program.is_none());
        assert_eq!(result.diagnostics.len(), 4, "{:?}", result.diagnostics);
        assert!(
            result
                .diagnostics
                .iter()
                .all(|d| d.code == Some(DiagCode::E0301))
        );
        let positions = positions_of(&result);
        assert!(positions.windows(2).all(|p| p[0] <= p[1]));
        assert_eq!(positions[0].0, FileId(0));
        assert!(positions[2].0 > positions[1].0);
        // 関数の前後に誤りのある定数を置き、定数と関数のどちらを先に検査しても、
        // 並べ替えがなければ位置の順にならないようにする。
        // 名前解決の例だけでは、ソース上の順に並べ直さない退行を捕まえない。
        let result = check_files(
            &[("main.bnt", b"const a: Integer = \"x\"\nfunction main() -> Unit\n bind n: Integer <- \"function\"\nend function\nconst b: Integer = \"y\"\n")],
            opts(false),
        );
        assert!(result.program.is_none());
        assert_eq!(result.diagnostics.len(), 3, "{:?}", result.diagnostics);
        assert!(
            result
                .diagnostics
                .iter()
                .all(|d| d.code == Some(DiagCode::E0401))
        );
        let positions = positions_of(&result);
        assert!(positions.windows(2).all(|p| p[0] <= p[1]), "{positions:?}");
        let result = check_files(
            &[
                (
                    "main.bnt",
                    b"import Lib.Text\nfunction main() -> Unit\n bind <-\nend function\n",
                ),
                (
                    "Lib/Text.bnt",
                    b"public function text() -> Integer\n return \"bad\"\nend function\n",
                ),
            ],
            opts(false),
        );
        assert!(result.error_count() > 0);
        assert!(
            result
                .diagnostics
                .iter()
                .all(|d| d.code != Some(DiagCode::E0401))
        );
    }
    #[test]
    fn warnings_are_kept_until_the_last_reached_stage_and_prelude_warnings_are_removed() {
        let source = b"@deprecated(\"old\")\nfunction old() -> Integer\n return 1\nend function\nfunction main() -> Unit\n bind _ <- old()\nend function\n";
        for deny in [false, true] {
            let result = check_text("main.bnt", source, opts(deny));
            assert_eq!(result.diagnostics.len(), 1, "{:?}", result.diagnostics);
            assert_eq!(result.diagnostics[0].code, Some(DiagCode::W0301));
            assert_eq!(result.program.is_some(), !deny);
            assert_eq!(result.error_count(), usize::from(deny));
            assert_eq!(result.warning_count(), usize::from(!deny));
            assert!(
                result
                    .diagnostics
                    .iter()
                    .filter(|d| d.is_warning())
                    .all(|d| result
                        .sources
                        .get(d.primary.as_ref().unwrap().span.file)
                        .unwrap()
                        .kind()
                        != crate::base::SourceKind::Prelude)
            );
        }
        let name_error = String::from_utf8(source.to_vec())
            .unwrap()
            .replace("bind _ <- old()", "bind _ <- old()\n bind _ <- missing");
        let type_error = String::from_utf8(source.to_vec())
            .unwrap()
            .replace("bind _ <- old()", "bind _: String <- old()");
        for source in [name_error, type_error] {
            let result = check_text("main.bnt", source.as_bytes(), opts(true));
            assert!(result.program.is_none());
            assert!(result.diagnostics.iter().all(|d| !d.is_warning()));
            assert!(
                result
                    .diagnostics
                    .iter()
                    .any(|d| d.code == Some(DiagCode::W0301) && d.is_error())
            );
            assert_eq!(result.error_count(), 2, "{:?}", result.diagnostics);
        }
    }
    #[test]
    fn missing_entry_does_not_assign_a_prelude_id_and_main_is_optional() {
        let result = check_files(&[], opts(false));
        assert!(result.entry.is_none());
        assert!(result.program.is_none());
        assert_eq!(result.diagnostics[0].code, Some(DiagCode::E0101));
        let result = check_text(
            "Lib/Text.bnt",
            b"public function value() -> Integer\n return 1\nend function",
            CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert!(result.program.is_some(), "{:?}", result.diagnostics);
        assert_eq!(
            result.sources.get(result.entry.unwrap()).unwrap().name(),
            "Lib/Text.bnt"
        );
    }
    fn check_depth_boundary(
        name: &str,
        max: usize,
        options: CheckOptions,
        source: impl Fn(usize) -> String,
    ) {
        for depth in [max, max + 1] {
            let source = source(depth);
            let result = check_text("deep.bnt", source.as_bytes(), options);
            if depth == max {
                assert!(
                    result.diagnostics.is_empty(),
                    "{name} at {depth}: {:?}",
                    result.diagnostics
                );
                assert!(result.program.is_some(), "{name} at {depth}");
            } else {
                assert!(result.program.is_none(), "{name} at {depth}");
                assert!(
                    result
                        .diagnostics
                        .iter()
                        .any(|d| d.code == Some(DiagCode::E0208)),
                    "{name} at {depth}: {:?}",
                    result.diagnostics
                );
            }
        }
    }
    #[test]
    fn deep_expressions_check_at_the_parser_depth_limit() {
        // spec: 02-03 入れ子の深さ
        // 関門: 段のスレッドで、構文の上限まで型検査できる契約を守る。型検査だけの
        // 既定のスレッドのテストは上限より浅く、構文解析との接続を確かめない。
        // 外側は関数(1)、ブロック(2)、bind(3)、値の式(4)。各形の最深部は k * n + c。
        for (name, prefix, leaf, suffix, k, c) in [
            // 括弧と二項演算の右辺で二段ずつ増え、葉は 4 + 2n。
            ("binary", "(1 + ", "1", ")", 2, 4),
            // 括弧一つで一段増え、葉は 4 + n。
            ("parentheses", "(", "1", ")", 1, 4),
            // ラムダのブロック、bind、その値で三段増え、葉は 4 + 3n。
            (
                "lambda",
                "lambda()\n bind _ <- ",
                "()",
                "\nend lambda",
                3,
                4,
            ),
            // if のブロックと最初の文で二段増え、葉は 4 + 2n。
            ("if", "if true then ", "1", " else 0 end if", 2, 4),
            // 最初の分岐、ブロック、文で三段増える。最後の match は深さ
            // 4 + 3(n - 1)、二番目の分岐の値はさらに四段下なので 3n + 5。
            (
                "match-body",
                "match true with\n case true -> ",
                "1",
                "\n case false -> 0\n end match",
                3,
                5,
            ),
            // 対象で一段増える。最後の match は 4 + (n - 1)、
            // 二番目の分岐の値がさらに四段下なので n + 7。
            (
                "match-scrutinee",
                "match ",
                "true",
                " with\n case true -> true\n case false -> false\n end match",
                1,
                7,
            ),
        ] {
            let max = (usize::try_from(crate::syntax::parser::MAX_DEPTH).unwrap() - c) / k;
            check_depth_boundary(name, max, opts(false), |depth| {
                let nested = format!("{}{leaf}{}", prefix.repeat(depth), suffix.repeat(depth));
                format!("function main() -> Unit\n bind _ <- {nested}\nend function\n")
            });
        }
    }
    #[test]
    #[ignore = "long: 構文の上限直前のリストと構成子のパターンを検査する（約26秒）"]
    fn deep_patterns_check_at_the_parser_depth_limit() {
        // spec: 02-03 入れ子の深さ
        // spec: 01-05 網羅性の検査
        // 関門: 深いパターンの網羅性の判定まで、段のスレッドで上限内の入力を検査する。
        // 関数(1)、ブロック(2)、match の式文(3)。パターンは節ごとに一段を数える。
        // リストは n 個のリスト、葉の _、次の分岐の _ の合計 n + 2 節で k=1, c=5。
        // 構成子は n 個の構成子と葉の _ の n + 1 節で k=1, c=4。
        for (name, k, c) in [("list", 1, 5), ("constructor", 1, 4)] {
            let max = (usize::try_from(crate::syntax::parser::MAX_DEPTH).unwrap() - c) / k;
            check_depth_boundary(
                name,
                max,
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
                |depth| {
                    if name == "list" {
                        // 引数の型は深さ 3 + n なので、パターンのほうが先に上限に達する。
                        let ty = format!("{}Integer{}", "List[".repeat(depth), "]".repeat(depth));
                        let pat = format!("{}_{}", "[".repeat(depth), "]".repeat(depth));
                        format!(
                            "function f(n: {ty}) -> Unit\n match n with\n case {pat} -> ()\n case _ -> ()\n end match\nend function\n"
                        )
                    } else {
                        let pat = format!("{}_{}", "L.Mk(".repeat(depth), ")".repeat(depth));
                        format!(
                            "data L\n Mk(L)\nend data\nfunction f(n: L) -> Unit\n match n with\n case {pat} -> ()\n end match\nend function\n"
                        )
                    }
                },
            );
        }
    }
    #[test]
    fn long_list_patterns_and_boolean_matrix_check_near_the_depth_limit() {
        // spec: 02-03 入れ子の深さ
        // spec: 01-05 網羅性の検査
        // 関門: 入れ子が浅くても節の多いパターンで、有用性の判定がスタックを溢れさせず
        // 検査を終える契約を守る。深いパターンだけでは長い列と多数の行の組合せに届かない。
        let limit = usize::try_from(crate::syntax::parser::MAX_DEPTH).unwrap();
        let match_depth = 3; // 関数(1)、ブロック(2)、match の式文(3)。
        // リスト自身一節、要素の節、次の分岐の _ 一節を、match の深さに加える。
        let elements = limit - match_depth - 2;
        let flat = format!(" case [{}] -> ()\n", vec!["_"; elements].join(", "));
        // 正方形の行列で、行ごとにリスト自身一節と列の節を数え、最後に _ 一節を置く。
        let mut side = 1;
        while match_depth + (side + 1) * (side + 2) < limit {
            side += 1;
        }
        let mut matrix = String::new();
        let significant_bits = usize::try_from(usize::BITS - (side - 1).leading_zeros()).unwrap();
        for row in 0..side {
            // 行番号を真偽値の列として表し、互いに覆われない行を作る。
            let values = (0..side)
                .map(|column| {
                    if column >= significant_bits {
                        "_"
                    } else if row & (1 << column) == 0 {
                        "false"
                    } else {
                        "true"
                    }
                })
                .collect::<Vec<_>>();
            matrix.push_str(&format!(" case [{}] -> ()\n", values.join(", ")));
        }
        for (ty, arms) in [("Integer", flat), ("Boolean", matrix)] {
            let source = format!(
                "function f(n: List[{ty}]) -> Unit\n match n with\n{arms} case _ -> ()\n end match\nend function\n"
            );
            let result = check_text(
                "long.bnt",
                source.as_bytes(),
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            assert!(
                result.diagnostics.is_empty(),
                "{ty}: {:?}",
                result.diagnostics
            );
            assert!(result.program.is_some(), "{ty}");
        }
    }
    #[test]
    fn deep_if_and_else_if_check_on_the_stage_stack() {
        // if の then の中に次の if を置き、else if の分岐も含める。
        // 構文解析器は if の式とその文の二段を数えるため、490 個で上限 1000 の近くになる。
        let depth = 490;
        let mut source = String::from("function main() -> Unit\n");
        source.push_str(&" if true then\n".repeat(depth));
        source.push_str(" ()\n");
        source.push_str(&" else if false then\n ()\n else\n ()\n end if\n".repeat(depth));
        source.push_str("end function\n");
        let result = check_text("deep.bnt", source.as_bytes(), opts(false));
        assert!(result.program.is_some(), "{:?}", result.diagnostics);
    }
    // 関門: 値化・パイプ・不正な引数を混ぜた入力で、位置の式の拒否後も独立した型診断を一度に返す。
    // 展開単体では、パイプラインが型検査を止める退行を捉えられない。
    #[test]
    fn source_location_errors_do_not_hide_independent_type_errors() {
        use crate::diag::DiagCode as C;
        for (source, expected) in [
            (
                r#"function main() -> Unit
  bind f <- SourceLocation.here
  bind x: Integer <- "not an integer"
end function
"#,
                vec![C::E0467, C::E0401],
            ),
            (
                r#"import Benitoite.Unofficial.IO.Console

function apply(f: function() -> SourceLocation.Location) -> SourceLocation.Location
  return f()
end function

function main() -> Unit uses Console.Write
  bind f <- SourceLocation.here
  bind g <- apply(SourceLocation.here)
  bind h <- () |> SourceLocation.here
  bind i <- () |> SourceLocation.here()
  bind j <- SourceLocation.here(1)
  bind k <- SourceLocation.here(x: 1)
  bind m <- SourceLocation.here(_)
end function
"#,
                vec![
                    C::E0467,
                    C::E0467,
                    C::E0467,
                    C::E0467,
                    C::E0402,
                    C::E0451,
                    C::E0402,
                ],
            ),
            (
                r#"const loc: function() -> SourceLocation.Location = SourceLocation.here

function main() -> Unit
  return ()
end function
"#,
                vec![C::E0467],
            ),
            (
                r#"import Benitoite.Unofficial.IO.Console

const locs: List[function() -> SourceLocation.Location] = [SourceLocation.here]
const count: Integer = List.length(locs)
const again: List[function() -> SourceLocation.Location] = locs

function main() -> Unit uses Console.Write
  Console.writeLine(Integer.toString(List.length(again)))
end function
"#,
                vec![C::E0467, C::E0433],
            ),
            (
                r#"import Benitoite.Unofficial.IO.Console

function noisy() -> Integer uses Console.Write
  Console.writeLine("x")
  return 1
end function

function main() -> Unit uses IO.All
  bind h <- () |> SourceLocation.here(noisy())
end function
"#,
                vec![C::E0467],
            ),
            (
                r#"import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind f <- SourceLocation.here
  bind n: Integer <- f
  match f with
    case Option.Some(v) -> Console.writeLine(v)
    case _ -> ()
  end match
end function
"#,
                // 後の注釈で決まった仮の型を根拠に、パターンの不一致を重ねない。
                vec![C::E0467],
            ),
        ] {
            let result = check_text("main.bnt", source.as_bytes(), opts(false));
            let codes: Vec<_> = result
                .diagnostics
                .iter()
                .filter(|d| d.is_error())
                .filter_map(|d| d.code)
                .collect();
            assert_eq!(codes, expected, "{:?}", result.diagnostics);
            assert!(
                !result.diagnostics.iter().any(|d| d.code == Some(C::W0501)),
                "{:?}",
                result.diagnostics
            );
            assert!(result.program.is_none());
        }
        // 同じファイルの独立した関数の警告は抑えない。
        let source = "function main() -> Unit uses IO.All\n bind f <- SourceLocation.here\nend function\nfunction independent() -> Unit uses IO.All\n ()\nend function\n";
        let result = check_text("main.bnt", source.as_bytes(), opts(false));
        assert_eq!(
            result
                .diagnostics
                .iter()
                .filter_map(|d| d.code)
                .collect::<Vec<_>>(),
            [C::E0467, C::W0501],
            "{:?}",
            result.diagnostics
        );
        let warning = result
            .diagnostics
            .iter()
            .find(|d| d.code == Some(C::W0501))
            .unwrap();
        assert_eq!(
            warning.primary.as_ref().unwrap().span.start.0 as usize,
            source.rfind("IO.All").unwrap()
        );
        assert!(result.program.is_none());
    }
}
