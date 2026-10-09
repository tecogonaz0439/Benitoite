//! フォーマッタと `benitoite fmt`（設計書 06-03、06-01「`fmt` のコマンドライン（初回リリース版）」、
//! ADR 0207・0225〜0228・0247）。整形は字句と改行の印の列を辿って字句の字面を写し、その間に空白・字下げ・
//! 空の行・コメントを置く。AST は字句の役割を決めるためだけに使う。

pub mod print;
pub mod roles;
pub mod verify;

use crate::diag::Diagnostic;

/// 字下げの一段の空白の数（06-03「字下げ」、ADR 0225）。
pub const INDENT_WIDTH: usize = 2;

/// 整形の結果。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Formatted {
    pub text: Vec<u8>,
    /// 整形の結果が元のバイト列と違うか
    pub changed: bool,
}

/// 整形できなかった理由。
#[derive(Clone, PartialEq, Debug)]
pub enum FormatError {
    /// 字句か構文の誤り（06-03「構文の誤りがあるファイル」）。ファイルを書き換えずに診断を書く
    Syntax(Vec<Diagnostic>),
    /// 整形後の検証の失敗（06-03「整形後の検証」）。処理系の不具合であり、文字列は調べるための説明
    Verify(String),
}

/// `fmt` が書く文と、報告の型板に埋める語（ADR 0033）。
pub mod text {
    /// `--check` で、整形で変わるファイル一つの行。`{path}` は表示名
    pub const WOULD_REFORMAT: &str = "would reformat {path}";
    /// 処理系の不具合の報告（10-13 の `internal_diagnostic`）の段の名前
    pub const STAGE_FMT: &str = "fmt";
}

use std::io::{Read, Write};
use std::path::Path;

use super::args::{self, PathArgs};
use crate::base::source::MAX_SOURCE_BYTES;
use crate::base::{FileId, IdGen, Source, SourceKind, SourceTable};
use crate::cli::{CliEnv, DiagFormat};
use crate::diag::render::{TextOptions, render_json_line, render_one_text};
use crate::diag::{DiagBuilder, DiagCode};
use crate::runtime::panic as panic_boundary;
use crate::runtime::report::{FaultThread, internal_diagnostic};
use crate::runtime::run::{EXIT_CHECK, EXIT_FAILURE, EXIT_INTERNAL, EXIT_OK};
use crate::syntax::lexer::lex;
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::parse;

/// 一つのソースを整形する（本章「整形の流れ」）。`kind` が `SourceKind::Prelude` なら、標準ライブラリのソースの構文で解析する
/// （06-03「標準ライブラリのソース」）。`file` は診断の span に使うファイル ID である。
pub fn format_source(
    file: FileId,
    kind: SourceKind,
    text: &[u8],
) -> Result<Formatted, FormatError> {
    // 字句の誤りがあっても構文解析まで進め、両方の診断をこの順につなぐ（本章「整形の流れ」の 1・2）。
    let lexed = lex(file, text);
    let parsed = parse(
        file,
        kind,
        text,
        resolve_newlines(lexed.tokens.clone()),
        lexed.comments.clone(),
        &mut IdGen::new(),
    );
    // 断るのは字句か構文の誤り（E01nn・E02nn）があるときだけで、そのほかの構文解析の診断は捨てる
    // （本章「整形の流れ」の 2、ADR 0333 の決定 1）。
    if lexed.diagnostics.iter().any(is_syntax_error)
        || parsed.diagnostics.iter().any(is_syntax_error)
    {
        let mut diagnostics = lexed.diagnostics;
        diagnostics.extend(parsed.diagnostics);
        return Err(FormatError::Syntax(diagnostics));
    }
    let roles = roles::build_roles(&parsed.module, &lexed.tokens, text);
    let out = print::print(&print::PrintInput {
        text,
        tokens: &lexed.tokens,
        comments: &lexed.comments,
        roles: &roles,
    });
    verify::verify(text, &out, kind).map_err(FormatError::Verify)?;
    let changed = out != text;
    Ok(Formatted { text: out, changed })
}

/// 整形を断る診断（字句の誤り E01nn か構文の誤り E02nn）か。診断コードの表は区分の欄を持たないので、番号の
/// 区間（10-02「番号の付け方」）で判定する。コードのない診断（処理系の不具合）も断る側に入れる。
pub(crate) fn is_syntax_error(diagnostic: &Diagnostic) -> bool {
    diagnostic.code.is_none_or(|code| {
        let id = code.info().id;
        id.starts_with("E01") || id.starts_with("E02")
    })
}

/// `benitoite fmt` を実行し、終了状態を返す（本章「`fmt` の実行」）。
pub fn run_fmt(args: PathArgs, env: CliEnv) -> u8 {
    run_fmt_with(&args, &env, format_user)
}

fn format_user(text: &[u8], file: FileId) -> Result<Formatted, FormatError> {
    format_source(file, SourceKind::User, text)
}

/// 整形の関数を差し替えられる `run_fmt` の本体。検証の失敗と panic の経路をテストから作るために分けた。
fn run_fmt_with(
    args: &PathArgs,
    env: &CliEnv,
    format: fn(&[u8], FileId) -> Result<Formatted, FormatError>,
) -> u8 {
    // 終了状態は当たる場合のうち最大の値（06-01 の表の上の行を優先。3 > 2 > 1 > 0）。
    let mut status = EXIT_OK;
    for given in &args.paths {
        let resolved = env.working_directory.join(given);
        let display = given.to_string_lossy().into_owned();
        // 直接与えたリンクは辿る（ADR 0327）ので、`metadata` で辿った先の種類を見る。
        let is_dir = std::fs::metadata(&resolved).is_ok_and(|m| m.is_dir());
        if !is_dir {
            status = status.max(fmt_file(args, env, format, &resolved, &display));
            continue;
        }
        match args::bnt_files(&resolved) {
            Ok(files) => {
                for file in files {
                    // 表示名は、与えたディレクトリのパスに相対パスを続けたもの（10-17「`fmt` の実行」）
                    let relative = file.strip_prefix(&resolved).unwrap_or(&file);
                    let display = given.join(relative).to_string_lossy().into_owned();
                    status = status.max(fmt_file(args, env, format, &file, &display));
                }
            }
            Err((path, error)) => {
                let relative = path.strip_prefix(&resolved).unwrap_or(&path);
                let display = given.join(relative).to_string_lossy().into_owned();
                write_diag(
                    env,
                    args.diagnostics,
                    &SourceTable::new(),
                    &read_error(&display, &error.to_string()),
                );
                status = status.max(EXIT_CHECK);
            }
        }
    }
    status
}

/// 一つのファイルを整形し、終了状態への寄与を返す（10-17「`fmt` の実行」の表）。
fn fmt_file(
    args: &PathArgs,
    env: &CliEnv,
    format: fn(&[u8], FileId) -> Result<Formatted, FormatError>,
    path: &Path,
    display: &str,
) -> u8 {
    let text = match read_source(path, MAX_SOURCE_BYTES) {
        Ok(text) => text,
        Err(reason) => {
            write_diag(
                env,
                args.diagnostics,
                &SourceTable::new(),
                &read_error(display, &reason),
            );
            return EXIT_CHECK;
        }
    };
    // 診断の位置のために、このファイルだけを入れた表を作る（10-17「`fmt` の実行」）。
    let mut sources = SourceTable::new();
    let file = sources.add(Source::new(
        display.to_owned(),
        SourceKind::User,
        text.clone(),
    ));
    let formatted = match panic_boundary::catch(|| format(&text, file)) {
        Ok(Ok(formatted)) => formatted,
        Ok(Err(FormatError::Syntax(diagnostics))) => {
            for diag in &diagnostics {
                write_diag(env, args.diagnostics, &sources, diag);
            }
            return EXIT_CHECK;
        }
        Ok(Err(FormatError::Verify(message))) => {
            let diag = internal_diagnostic(text::STAGE_FMT, &message, None, FaultThread::Stage);
            write_diag(env, args.diagnostics, &sources, &diag);
            return EXIT_INTERNAL;
        }
        Err(panic) => {
            let diag = internal_diagnostic(
                text::STAGE_FMT,
                &panic.message,
                Some(&panic),
                FaultThread::Stage,
            );
            write_diag(env, args.diagnostics, &sources, &diag);
            return EXIT_INTERNAL;
        }
    };
    if !formatted.changed {
        return EXIT_OK;
    }
    if args.check {
        let line = format!("{}\n", text::WOULD_REFORMAT.replace("{path}", display));
        let _result = env.stderr.write_bytes(line.as_bytes());
        return EXIT_FAILURE;
    }
    match replace_file(path, display, &formatted.text) {
        Ok(()) => EXIT_OK,
        Err(diag) => {
            write_diag(env, args.diagnostics, &sources, &diag);
            EXIT_CHECK
        }
    }
}

/// ソースを `limit` バイトまで読む。超えたら、大きさの上限の理由の文を返す（作業 D03 の手順 3）。
fn read_source(path: &Path, limit: usize) -> Result<Vec<u8>, String> {
    let mut file = std::fs::File::open(path).map_err(|e| e.to_string())?;
    // 上限より 1 バイト多く読めたら、上限を超えたと分かる。
    let cap = u64::try_from(limit)
        .ok()
        .and_then(|n| n.checked_add(1))
        .unwrap_or(u64::MAX);
    let mut text = Vec::new();
    (&mut file)
        .take(cap)
        .read_to_end(&mut text)
        .map_err(|e| e.to_string())?;
    if text.len() > limit {
        return Err(source_text::SOURCE_TOO_LARGE.to_owned());
    }
    Ok(text)
}

/// 読めないファイルとディレクトリの E0101（`modules::load` の `read_error` と同じ形。span はない）。
fn read_error(display: &str, reason: &str) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0101)
        .arg("path", display)
        .arg("reason", reason)
        .note("reason")
        .build()
}

/// 診断を一件、`--diagnostics` の形式で `env.stderr` に書く（10-17「`fmt` の実行」）。
fn write_diag(env: &CliEnv, format: DiagFormat, sources: &SourceTable, diag: &Diagnostic) {
    let message = match format {
        DiagFormat::Text => render_one_text(diag, sources, TextOptions { color: env.color }),
        DiagFormat::Json => format!("{}\n", render_json_line(diag, sources)),
    };
    let _result = env.stderr.write_bytes(message.as_bytes());
}

/// 理由の文（ADR 0033）。文は `modules::text::SOURCE_TOO_LARGE` と同じで、そちらが `pub(super)` なので写す。
mod source_text {
    pub(super) const SOURCE_TOO_LARGE: &str = "the source file exceeds the size limit of 256 MiB";
}

/// 整形の結果でファイルを置き換える（06-01「`fmt` のコマンドライン」、ADR 0207・0247）。同じディレクトリの一時ファイルに書き、
/// 元のファイルの許可の設定を写してから、名前の変更で置き換える。失敗したら元のファイルを変えずに残し、一時ファイルを消して、
/// E0125 の診断を返す（`display` は診断に書く表示名）。
pub fn replace_file(path: &Path, display: &str, content: &[u8]) -> Result<(), Box<Diagnostic>> {
    let write_error = |error: &std::io::Error| {
        DiagBuilder::new(DiagCode::E0125)
            .arg("path", display)
            .arg("reason", error.to_string())
            .note("reason")
    };
    // 直接与えたリンクは辿った先のファイルを置き換え、リンクそのものは変えない（ADR 0327 の決定 1）。
    let is_link = std::fs::symlink_metadata(path).is_ok_and(|m| m.file_type().is_symlink());
    let target = if is_link {
        std::fs::canonicalize(path).map_err(|e| Box::new(write_error(&e).build()))?
    } else {
        path.to_path_buf()
    };
    let Some(name) = target.file_name() else {
        let error = std::io::Error::from(std::io::ErrorKind::InvalidInput);
        return Err(Box::new(write_error(&error).build()));
    };
    let mut temp_name = std::ffi::OsString::from(".");
    temp_name.push(name);
    temp_name.push(format!(".fmt-{}", std::process::id()));
    let temp = target.with_file_name(temp_name);
    // 既にあるファイルは他者のものかもしれないので、作れなければ消さずに失敗とする（create_new）。
    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temp)
        .map_err(|e| Box::new(write_error(&e).build()))?;
    let result = file
        .write_all(content)
        .and_then(|()| file.sync_all())
        .and_then(|()| std::fs::metadata(&target))
        // 実行の許可を整形で失わないよう、元の許可の設定を写す（10-17「`fmt` の実行」）。
        .and_then(|metadata| std::fs::set_permissions(&temp, metadata.permissions()));
    drop(file);
    let result = result.and_then(|()| std::fs::rename(&temp, &target));
    let Err(error) = result else {
        return Ok(());
    };
    let mut builder = write_error(&error);
    if std::fs::remove_file(&temp).is_err() {
        builder = builder
            .arg("temp", temp.to_string_lossy().into_owned())
            .note("temp_left");
    }
    Err(Box::new(builder.build()))
}

#[cfg(test)]
mod tests;
