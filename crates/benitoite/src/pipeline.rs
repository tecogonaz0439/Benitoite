//! 段をつなぐ公開の関数（設計書 02-01「段と段の間のデータ」「検査と実行の経路」「誤りが見つかったときの段の進め方」
//! 「関数の呼び出しと処理系のスタック」、02-11「実行を始めるファイルとプログラムの読み込み」、ADR 0019・0087・0156・0166）。

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

/// 検査・脱糖・コンパイルの段を動かすスレッドのスタックの大きさ（64 MiB。02-01、ADR 0087）。
pub const STAGE_STACK_BYTES: usize = 64 * 1024 * 1024;

/// ディレクトリを指定したときに実行を始めるファイルの名前（06-01「ディレクトリの指定」、ADR 0127）。
pub const ENTRY_FILE_NAME: &str = "main.bnt";

/// 検査の選択肢。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct CheckOptions {
    /// `main` の有無と形を検査する。`check`・`run` で真、`test` で偽（10-05 の `typecheck`）
    pub require_main: bool,
    /// `--deny-warnings`（02-01「誤りが見つかったときの段の進め方」、ADR 0166）
    pub deny_warnings: bool,
}

/// 型検査までを誤りなく通ったプログラム。
#[derive(Debug)]
pub struct CheckedProgram {
    pub modules: ModuleTable,
    /// モジュールごとの AST。添字はモジュールの ID の値（10-04 の `LoadOutput::asts`）
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

/// 実行を始めるファイルを決められない（CLI の使い方の誤り。終了状態 2。06-01「ディレクトリの指定」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum EntryError {
    /// 指定したディレクトリに `main.bnt` がない
    NoMainFile { dir: PathBuf },
}

use std::path::Path;

use crate::bytecode::program::CompiledProgram;
use crate::ir::core_ir::CoreProgram;
use crate::modules::{EntrySpec, ModuleFs};

/// コマンドラインで与えたパスから、実行を始めるファイルを決める（06-01「ディレクトリの指定」、02-02「ソースとファイル ID」の表示名）。
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
/// （02-01「検査と実行の経路」の `check`）。標準ライブラリのソースは 10-14 の表から読み込みの段に渡す。
/// 段の中身は `STAGE_STACK_BYTES` のスタックを持つスレッドで行う（ADR 0087）。そのスレッドの panic は段のスレッドの
/// 中で捕らえ、報告の種類が `Internal` の診断（段は `check`、スレッドは `Stage`）にして `diagnostics` に入れて返す。
pub fn check(entry: &EntrySpec, fs: &(dyn ModuleFs + Sync), opts: CheckOptions) -> CheckResult {
    match on_large_stack(|| crate::runtime::panic::catch(|| check_stages(entry, fs, opts))) {
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
            program: None,
        },
    }
}

/// `entry_spec` と本番のファイルシステム（`RealFs`）で `check` を行う。
pub fn check_path(path: &Path, opts: CheckOptions) -> Result<CheckResult, EntryError> {
    Ok(check(&entry_spec(path)?, &crate::modules::RealFs, opts))
}

/// ファイルシステムを使わずに検査する（テストで使う）。`files` はパスと内容の組で、最初の要素が実行を始めるファイルである。
/// パスは仮の根のディレクトリからの相対パス（`main.bnt`、`Lib/Text.bnt`）で、表示名はそのパスとする。
pub fn check_files(files: &[(&str, &[u8])], opts: CheckOptions) -> CheckResult {
    let root = PathBuf::from("/root");
    let fs = MemoryFs {
        files: files
            .iter()
            .map(|(path, bytes)| (root.join(path), bytes.to_vec()))
            .collect(),
    };
    let name = files.first().map_or("main.bnt", |(name, _)| *name);
    check(
        &EntrySpec {
            path: root.join(name),
            display_name: name.to_owned(),
            root,
        },
        &fs,
        opts,
    )
}

/// 一つのファイルだけからなるプログラムを検査する（`check_files` の略記。テストで使う）。`name` は表示名。
pub fn check_text(name: &str, text: &[u8], opts: CheckOptions) -> CheckResult {
    check_files(&[(name, text)], opts)
}

/// 脱糖してコア IR を作る（10-06 の `desugar`）。`STAGE_STACK_BYTES` のスタックを持つスレッドで行う。
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

/// 判定の木への変換（10-06 の `lower_program`）とコード生成（10-07 の `codegen`）を行う。
/// `STAGE_STACK_BYTES` のスタックを持つスレッドで行う。
pub fn compile(
    core: &CoreProgram,
    sources: Arc<SourceTable>,
) -> Result<CompiledProgram, CompileError> {
    on_large_stack(|| {
        let lower = crate::ir::decision::lower_program(core).map_err(CompileError::Internal)?;
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
    let mut ids = crate::base::IdGen::new();
    let loaded = crate::modules::load_program(entry, crate::prelude::STDLIB, fs, &mut ids);
    let sources = Arc::new(loaded.sources);
    let entry_file = sources
        .get(FileId(0))
        .filter(|s| s.kind() == crate::base::SourceKind::User)
        .map(|_| FileId(0));
    let mut result = CheckResult {
        sources,
        entry: entry_file,
        diagnostics: Vec::new(),
        program: None,
    };
    append_stage(&mut result, loaded.diagnostics);
    if !result.diagnostics.iter().any(Diagnostic::is_error) {
        let mut resolved =
            crate::resolve::resolve(&loaded.modules, &loaded.asts, &result.sources, &mut ids);
        append_stage(&mut result, std::mem::take(&mut resolved.diagnostics));
        if !result.diagnostics.iter().any(Diagnostic::is_error) {
            let (types, diagnostics) = crate::typeck::typecheck(
                &loaded.modules,
                &loaded.asts,
                &result.sources,
                &resolved,
                opts.require_main,
            );
            append_stage(&mut result, diagnostics);
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
    // 標準ライブラリの警告を除いた後に deny を適用する（設計書 02-10「警告の扱い」）。
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

fn append_stage(result: &mut CheckResult, mut diagnostics: Vec<Diagnostic>) {
    diagnostics.retain(|diag| {
        !diag.is_warning()
            || !diag.primary.as_ref().is_some_and(|label| {
                result
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

// 公開の check_files はテスト用モジュールに依存できないため、ファイルだけを持つ実装を置く（実装プラン F18）。
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
mod tests {
    // 関門: 公開の検査の入口が段の順、警告の扱い、深い入力への対応を守る。
    // 各段の単独のテストは段の接続と deny の適用順を確かめない（設計書 07-03）。
    // テストの失敗は panic で表す（実装プラン 00-02）。
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
    #[test]
    fn u3_sources_import_names_and_record_tags_pass_check() {
        // 関門: 公開の検査で U3 の各モジュールを実際に読み、利用者から見える型と取り込み名を
        // 守る。ソースと Rust の表の照合は、型検査や Clock の別名の取り込みには届かない
        // （実装プラン L00「標準ライブラリのソースの検査」「取り込みの名前」）。
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
        let positions: Vec<_> = result
            .diagnostics
            .iter()
            .map(|d| {
                let label = d.primary.as_ref().unwrap();
                (label.span.file, label.span.start)
            })
            .collect();
        assert!(positions.windows(2).all(|p| p[0] <= p[1]));
        assert_eq!(positions[0].0, FileId(0));
        assert!(positions[2].0 > positions[1].0);
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
    #[test]
    fn deep_if_and_else_if_check_on_the_default_calling_stack() {
        // if の then の中に次の if を置き、else if の分岐も含める（実装プラン F18「大きなスタック」）。
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
}
