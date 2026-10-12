//! File の組み込みの操作（設計書 03-07「File」、02-09「一つの操作で作る値の大きさの上限」）。

use crate::builtins::iface::IoCtx;
use crate::builtins::iface::IoReply;
use crate::builtins::iface::IoWait;
use crate::builtins::iface::WorkerWait;
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::iface::{CloseStep, StateReply};
use crate::builtins::iface::{Lend, Lent, OsResource};
use crate::builtins::table::tags;
use crate::runtime::MAX_STRING_BYTES;
use crate::runtime::ResourceError;
use crate::runtime::ResourceKind;
use crate::runtime::SizeUnit;
use crate::runtime::Stop;
use crate::runtime::heap::FieldsKind;
use crate::runtime::heap::{CtorTag, ResourceId, Value};

builtin! {
    /// `Benitoite.IO.File.readText` の本体。
    name = "Benitoite.IO.File.readText",
    io fn read_text(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_lent| read_limited(&path),
            read_text_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.writeText` の本体。
    name = "Benitoite.IO.File.writeText",
    io fn write_text(ctx, path: &'c str, text: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        let text = text.to_owned();
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| {
                let mut file = OpenOptions::new().write(true).create(true)
                    .append(false).truncate(true).open(path)?;
                file.write_all(text.as_bytes()).map_err(IoFailure::from)
            },
            write_text_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.appendText` の本体。
    name = "Benitoite.IO.File.appendText",
    io fn append_text(ctx, path: &'c str, text: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        let text = text.to_owned();
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| {
                let mut file = OpenOptions::new().create(true)
                    .append(true).open(path)?;
                file.write_all(text.as_bytes()).map_err(IoFailure::from)
            },
            append_text_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.openReader` の本体。
    name = "Benitoite.IO.File.openReader",
    io fn open_reader(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| File::open(path).map_err(IoFailure::from),
            open_reader_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.readLine` の本体。
    name = "Benitoite.IO.File.readLine",
    io fn read_line(ctx, reader: ResourceId) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Resource(reader),
            |lent| {
                let Lent::Resource(resource) = lent else {
                    return Err(Stop::Internal("File.readLine requires a lent resource".into()));
                };
                let reader = resource.as_any_mut().downcast_mut::<FileReader>()
                    .ok_or_else(|| Stop::Internal("File.readLine requires File.Reader".into()))?;
                Ok(read_line_limited(&mut reader.0, MAX_STRING_BYTES))
            },
            read_line_done,
        ))))
    }
}

builtin! {
    /// `IO.File.closeReader` の本体。
    name = "IO.File.closeReader",
    state fn close_reader(ctx, reader: ResourceId) -> StateReply<'e> {
        let mut ctx = ctx;
        match ctx.services().begin_release(reader)? {
            Some(wait) => Ok(StateReply::Wait(wait)),
            None => Ok(StateReply::Done(ctx.alloc_fields(
                FieldsKind::Ctor, tags::RESULT_OK, &[Value::Unit],
            )?)),
        }
    }
}

use crate::runtime::MAX_LIST_LEN;
use crate::runtime::heap::CheckedLen;
use std::fs::{File, OpenOptions};
use std::io::{self, BufRead, BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};

mod tree;

#[cfg(test)]
#[derive(Clone, Copy, PartialEq, Eq)]
enum TreeVisit {
    BeforeOpen,
    AfterOpen,
}

mod text {
    pub const INVALID_UTF8: &str = "input is not valid UTF-8";
    pub const MODIFIED_OUT_OF_RANGE: &str =
        "file modification time does not fit Integer nanoseconds";
    pub const SIZE_OUT_OF_RANGE: &str = "file size does not fit Integer bytes";
    pub const NOT_DIRECTORY: &str = "path is not a directory";
    pub const DIRECTORY_CHANGED: &str = "directory changed during traversal";
    pub const WRITER_BUFFER_MISSING: &str = "File.Writer buffer missing during release";
}

#[derive(Clone, Debug)]
pub(super) struct IoFailure {
    kind: u32,
    reason: String,
}

impl From<io::Error> for IoFailure {
    fn from(error: io::Error) -> Self {
        let kind = [
            (io::ErrorKind::NotFound, tags::IO_ERROR_KIND_NOT_FOUND),
            (
                io::ErrorKind::PermissionDenied,
                tags::IO_ERROR_KIND_PERMISSION_DENIED,
            ),
            (
                io::ErrorKind::AlreadyExists,
                tags::IO_ERROR_KIND_ALREADY_EXISTS,
            ),
            (
                io::ErrorKind::IsADirectory,
                tags::IO_ERROR_KIND_IS_DIRECTORY,
            ),
            (
                io::ErrorKind::NotADirectory,
                tags::IO_ERROR_KIND_NOT_DIRECTORY,
            ),
            (
                io::ErrorKind::DirectoryNotEmpty,
                tags::IO_ERROR_KIND_DIRECTORY_NOT_EMPTY,
            ),
            (
                io::ErrorKind::InvalidInput,
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
            (io::ErrorKind::InvalidData, tags::IO_ERROR_KIND_INVALID_UTF8),
        ]
        .into_iter()
        .find_map(|(kind, tag)| (error.kind() == kind).then_some(tag))
        .unwrap_or(tags::IO_ERROR_KIND_OTHER);
        Self {
            kind,
            reason: error.to_string(),
        }
    }
}

#[derive(Debug)]
struct FileReader(BufReader<File>);

impl OsResource for FileReader {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }

    fn release(self: Box<Self>) -> Result<(), String> {
        // File は drop で閉じ、閉じる失敗は返さない（設計書 03-07「File」）。
        drop(self);
        Ok(())
    }
}

fn read_limited(path: &Path) -> Result<Vec<u8>, IoFailure> {
    read_all_limited(&mut File::open(path)?, MAX_STRING_BYTES)
}

pub(super) fn read_all_limited(
    reader: &mut (impl Read + ?Sized),
    limit: u64,
) -> Result<Vec<u8>, IoFailure> {
    let mut bytes = Vec::new();
    // 上限より 1 バイト多い分まで読み、VM 側で値を作る前に判定する
    // （設計書 02-09「一つの操作で作る値の大きさの上限」）。
    reader
        .take(limit.saturating_add(1))
        .read_to_end(&mut bytes)?;
    Ok(bytes)
}

pub(super) fn read_line_limited(
    reader: &mut dyn BufRead,
    limit: u64,
) -> Result<Option<Vec<u8>>, IoFailure> {
    let mut bytes = Vec::new();
    // 行末の CRLF は値に含めないので、内容の上限に 2 バイトを加えて読む
    // （設計書 02-09「一つの操作で作る値の大きさの上限」）。
    let count = reader
        .take(limit.saturating_add(2))
        .read_until(b'\n', &mut bytes)?;
    Ok((count != 0).then_some(bytes))
}

pub(super) fn result_error<'c, 'e>(
    ctx: &IoCtx<'c, 'e>,
    failure: IoFailure,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let reason = ctx.alloc_str(&failure.reason, function)?;
    let error = ctx.alloc_fields(FieldsKind::IoError, failure.kind, &[reason])?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])
}

/// 外部入力の大きさの超過を、値を作る操作の超過と区別する
/// （設計書 02-09「一つの操作で作る値の大きさの上限」）。
pub(super) fn check_input_size(
    len: usize,
    limit: u64,
    unit: SizeUnit,
    function: &'static str,
) -> Result<(), Stop> {
    if super::count(len)? > limit {
        return Err(input_too_large(function, unit, limit));
    }
    Ok(())
}

fn check_input(bytes: &[u8], function: &'static str, limit: u64) -> Result<(), Stop> {
    check_input_size(bytes.len(), limit, SizeUnit::Bytes, function)
}

pub(super) fn complete_text<'c, 'e>(
    ctx: &IoCtx<'c, 'e>,
    output: Result<Vec<u8>, IoFailure>,
    function: &'static str,
    limit: u64,
) -> Result<Value<'e>, Stop> {
    let bytes = match output {
        Ok(bytes) => bytes,
        Err(failure) => return result_error(ctx, failure, function),
    };
    check_input(&bytes, function, limit)?;
    match ctx.alloc_str_utf8(&bytes, function)? {
        Some(value) => ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value]),
        None => result_error(
            ctx,
            IoFailure::from(io::Error::new(
                io::ErrorKind::InvalidData,
                text::INVALID_UTF8,
            )),
            function,
        ),
    }
}

pub(super) fn complete_line<'c, 'e>(
    ctx: &IoCtx<'c, 'e>,
    output: Result<Option<Vec<u8>>, IoFailure>,
    function: &'static str,
    limit: u64,
) -> Result<Value<'e>, Stop> {
    let mut bytes = match output {
        Ok(Some(bytes)) => bytes,
        Ok(None) => {
            return ctx.alloc_fields(
                FieldsKind::Ctor,
                tags::RESULT_OK,
                &[Value::Tag(CtorTag(tags::OPTION_NONE))],
            );
        }
        Err(failure) => return result_error(ctx, failure, function),
    };
    // LF がなくても末尾の CR を一つ除く（設計書 03-07「共通の規則」）。
    if bytes.last() == Some(&b'\n') {
        bytes.pop();
    }
    if bytes.last() == Some(&b'\r') {
        bytes.pop();
    }
    check_input(&bytes, function, limit)?;
    match ctx.alloc_str_utf8(&bytes, function)? {
        Some(value) => {
            let line = ctx.alloc_fields(FieldsKind::Ctor, tags::OPTION_SOME, &[value])?;
            ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[line])
        }
        None => result_error(
            ctx,
            IoFailure::from(io::Error::new(
                io::ErrorKind::InvalidData,
                text::INVALID_UTF8,
            )),
            function,
        ),
    }
}

fn read_text_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Vec<u8>, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete_text(ctx, output, "Benitoite.IO.File.readText", MAX_STRING_BYTES)
}
fn read_line_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Result<Option<Vec<u8>>, IoFailure>, Stop>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete_line(ctx, output?, "Benitoite.IO.File.readLine", MAX_STRING_BYTES)
}
fn write_done<'c, 'e>(
    ctx: &IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    match output {
        Ok(()) => ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::Unit]),
        Err(failure) => result_error(ctx, failure, function),
    }
}
fn write_text_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.writeText")
}
fn append_text_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.appendText")
}
fn open_reader_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<File, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    match output {
        Ok(file) => {
            let site = ctx.site();
            let reader = ctx.services().register_resource(
                ResourceKind::FileReader,
                Box::new(FileReader(BufReader::new(file))),
                site,
            );
            ctx.alloc_fields(
                FieldsKind::Ctor,
                tags::RESULT_OK,
                &[Value::Resource(reader)],
            )
        }
        Err(failure) => result_error(ctx, failure, "Benitoite.IO.File.openReader"),
    }
}

/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[
    read_text::DECL,
    write_text::DECL,
    append_text::DECL,
    open_reader::DECL,
    read_line::DECL,
    close_reader::DECL,
];

#[cfg(test)]
mod path_tests;
#[cfg(test)]
mod resource_tests;
#[cfg(test)]
mod tests;

builtin! {
    /// `Benitoite.IO.File.readBytes` の本体。
    name = "Benitoite.IO.File.readBytes",
    io fn read_bytes(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| read_bytes_job(&path),
            read_bytes_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.readLines` の本体。
    name = "Benitoite.IO.File.readLines",
    io fn read_lines(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| read_limited(&path),
            read_lines_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.exists` の本体。
    /// 壊れたシンボリックリンクも、リンクそのものがあるので true を返す（設計書 03-07「File」）。
    name = "Benitoite.IO.File.exists",
    io fn exists(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| match std::fs::symlink_metadata(no_follow_path(&path)) {
                Ok(_) => Ok(true),
                Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(false),
                Err(e) => Err(IoFailure::from(e)),
            },
            exists_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.info` の本体。
    name = "Benitoite.IO.File.info",
    io fn info(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| info_job(&path),
            info_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.listDirectory` の本体。
    name = "Benitoite.IO.File.listDirectory",
    io fn list_directory(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| directory_job(&path, false, "Benitoite.IO.File.listDirectory"),
            list_directory_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.walk` の本体。
    name = "Benitoite.IO.File.walk",
    io fn walk(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| directory_job(&path, true, "Benitoite.IO.File.walk"),
            walk_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.canonicalize` の本体。
    name = "Benitoite.IO.File.canonicalize",
    io fn canonicalize(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| std::fs::canonicalize(path).map_err(IoFailure::from),
            canonicalize_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.writeBytes` の本体。
    name = "Benitoite.IO.File.writeBytes",
    io fn write_bytes(ctx, path: &'c str, content: &'c [u8]) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        let content = content.to_owned();
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| write_bytes_job(&path, &content, false),
            write_bytes_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.appendBytes` の本体。
    name = "Benitoite.IO.File.appendBytes",
    io fn append_bytes(ctx, path: &'c str, content: &'c [u8]) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        let content = content.to_owned();
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| write_bytes_job(&path, &content, true),
            append_bytes_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.createDirectory` の本体。
    name = "Benitoite.IO.File.createDirectory",
    io fn create_directory(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| create_directory_job(&path),
            create_directory_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.remove` の本体。
    name = "Benitoite.IO.File.remove",
    io fn remove(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| remove_job(&path),
            remove_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.removeTree` の本体。
    name = "Benitoite.IO.File.removeTree",
    io fn remove_tree(ctx, path: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| remove_tree_job(&path, #[cfg(test)] &mut |_, _| {}),
            remove_tree_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.rename` の本体。
    name = "Benitoite.IO.File.rename",
    io fn rename(ctx, from: &'c str, to: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        let from = ctx.services().working_directory().join(from);
        let to = ctx.services().working_directory().join(to);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| rename_job(&from, &to),
            rename_done,
        ))))
    }
}

// 仕事は Rust の値だけを返し、資源の不足も VM の共通の停止手順へ返す（設計書 02-09）。
type PathInput<T> = Result<Result<T, IoFailure>, Stop>;

fn read_bytes_job(path: &Path) -> PathInput<Vec<u8>> {
    let mut file = match File::open(path) {
        Ok(file) => file,
        Err(e) => return Ok(Err(e.into())),
    };
    let metadata = match file.metadata() {
        Ok(metadata) => metadata,
        Err(e) => return Ok(Err(e.into())),
    };
    if metadata.len() > MAX_STRING_BYTES {
        return Err(input_too_large(
            "Benitoite.IO.File.readBytes",
            SizeUnit::Bytes,
            MAX_STRING_BYTES,
        ));
    }
    // 読む間にファイルが増える場合にも、上限より 1 バイト多い分までに留める。
    Ok(read_all_limited(&mut file, MAX_STRING_BYTES))
}

fn input_too_large(function: &'static str, unit: SizeUnit, limit: u64) -> Stop {
    Stop::Resource(ResourceError::InputTooLarge {
        function,
        unit,
        limit,
    })
}

struct FileInfo {
    kind: u32,
    size: i64,
    modified: i64,
}

fn no_follow_path(path: &Path) -> &Path {
    // 末尾の / と /. によるリンク先の参照を防ぐ（設計書 03-07「File」）。
    // 構成要素を集め直さず、途中の . と .. は OS が元の順に解決できるよう残す。
    path.components().as_path()
}

fn info_job(path: &Path) -> Result<FileInfo, IoFailure> {
    let metadata = std::fs::symlink_metadata(no_follow_path(path))?;
    let kind = if metadata.is_file() {
        tags::FILE_ENTRY_KIND_REGULAR_FILE
    } else if metadata.is_dir() {
        tags::FILE_ENTRY_KIND_DIRECTORY
    } else if metadata.file_type().is_symlink() {
        tags::FILE_ENTRY_KIND_SYMBOLIC_LINK
    } else {
        tags::FILE_ENTRY_KIND_OTHER
    };
    let size = i64::try_from(metadata.len()).map_err(|_| IoFailure {
        kind: tags::IO_ERROR_KIND_OTHER,
        reason: text::SIZE_OUT_OF_RANGE.into(),
    })?;
    let modified = modified_nanoseconds(metadata.modified()?)?;
    Ok(FileInfo {
        kind,
        size,
        modified,
    })
}

fn modified_nanoseconds(time: std::time::SystemTime) -> Result<i64, IoFailure> {
    // epoch より前の時刻も符号付きナノ秒で表す。i128 を介して i64::MIN も扱う。
    let nanos = match time.duration_since(std::time::UNIX_EPOCH) {
        Ok(duration) => i128::try_from(duration.as_nanos()).ok(),
        Err(e) => i128::try_from(e.duration().as_nanos())
            .ok()
            .and_then(i128::checked_neg),
    };
    nanos
        .and_then(|n| i64::try_from(n).ok())
        .ok_or_else(|| IoFailure {
            kind: tags::IO_ERROR_KIND_OTHER,
            reason: text::MODIFIED_OUT_OF_RANGE.into(),
        })
}

fn directory_job(path: &Path, recursive: bool, function: &'static str) -> PathInput<Vec<PathBuf>> {
    Ok(directory_paths(
        path,
        recursive,
        function,
        #[cfg(test)]
        &mut |_, _| {},
    )?
    .map(|mut paths| {
        // Path の Ord は構成要素ごとの比較なので、相対パス全体の UTF-8 バイト列を比べる
        // （設計書 03-07「共通の規則」「File」）。UTF-8 は列挙するときに検査済み。
        paths.sort_by(|a, b| {
            a.to_str()
                .map(str::as_bytes)
                .cmp(&b.to_str().map(str::as_bytes))
        });
        paths
    }))
}

fn directory_paths(
    path: &Path,
    recursive: bool,
    function: &'static str,
    #[cfg(test)] hook: &mut dyn FnMut(TreeVisit, &Path),
) -> PathInput<Vec<PathBuf>> {
    use rustix::fs::{self, AtFlags, Mode, OFlags};
    // 根のリンクは列挙の起点として辿り、開いた後はその記述子を固定する。
    // 子はすべて NOFOLLOW で開く（設計書 03-07「File」）。
    let root = match fs::open(
        path,
        OFlags::RDONLY | OFlags::DIRECTORY | OFlags::CLOEXEC,
        Mode::empty(),
    ) {
        Ok(root) => root,
        Err(e) => return Ok(Err(io::Error::from(e).into())),
    };
    let mut directories = match tree::DirectoryStack::new(root) {
        Ok(directories) => directories,
        Err(e) => return Ok(Err(e.into())),
    };
    let mut relative = PathBuf::new();
    let mut paths = Vec::new();
    loop {
        let Some(name) = directories.next_name() else {
            match directories.pop(false) {
                Ok(false) => break,
                Ok(true) => {
                    relative.pop();
                }
                Err(e) => return Ok(Err(e.into())),
            }
            continue;
        };
        let entry_path = relative.join(&name);
        if entry_path.to_str().is_none() {
            return Ok(Err(io::Error::new(
                io::ErrorKind::InvalidData,
                text::INVALID_UTF8,
            )
            .into()));
        }
        if super::count(paths.len())? >= MAX_LIST_LEN {
            return Err(input_too_large(function, SizeUnit::Elements, MAX_LIST_LEN));
        }
        paths.push(entry_path.clone());
        if recursive {
            let stat = match directories
                .fd()
                .and_then(|fd| Ok(fs::statat(fd, &name, AtFlags::SYMLINK_NOFOLLOW)?))
            {
                Ok(stat) => stat,
                Err(e) => return Ok(Err(e.into())),
            };
            if tree::is_directory(&stat) {
                #[cfg(test)]
                hook(TreeVisit::BeforeOpen, &entry_path);
                if let Err(e) = directories.push(name, stat) {
                    return Ok(Err(e.into()));
                }
                relative = entry_path;
                #[cfg(test)]
                hook(TreeVisit::AfterOpen, &relative);
            }
        }
    }
    Ok(Ok(paths))
}

fn write_bytes_job(path: &Path, content: &[u8], append: bool) -> Result<(), IoFailure> {
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .append(append)
        .truncate(!append)
        .open(path)?;
    file.write_all(content).map_err(IoFailure::from)
}

fn create_directory_job(path: &Path) -> Result<(), IoFailure> {
    std::fs::create_dir_all(path).map_err(|e| {
        // 最後の構成要素が普通のファイルなら AlreadyExists（設計書 03-07「File」）。
        // OS の分類が異なるときだけ補正し、途中のファイルの NotDirectory は保つ。
        if e.kind() != io::ErrorKind::AlreadyExists
            && std::fs::symlink_metadata(path).is_ok_and(|m| m.is_file())
        {
            IoFailure {
                kind: tags::IO_ERROR_KIND_ALREADY_EXISTS,
                reason: e.to_string(),
            }
        } else {
            e.into()
        }
    })
}

fn remove_job(path: &Path) -> Result<(), IoFailure> {
    let path = no_follow_path(path);
    let metadata = std::fs::symlink_metadata(path)?;
    if metadata.is_dir() {
        std::fs::remove_dir(path).map_err(IoFailure::from)
    } else {
        std::fs::remove_file(path).map_err(IoFailure::from)
    }
}

fn remove_tree_job(
    path: &Path,
    #[cfg(test)] hook: &mut dyn FnMut(TreeVisit, &Path),
) -> Result<(), IoFailure> {
    use rustix::fd::AsFd;
    use rustix::fs::{self, AtFlags};
    let (parent, name, identity, root) = tree::open_remove_root(no_follow_path(path))?;
    let mut directories = tree::DirectoryStack::new(root)?;
    #[cfg(test)]
    let mut relative = PathBuf::new();
    loop {
        let Some(name) = directories.next_name() else {
            if !directories.pop(true)? {
                break;
            }
            #[cfg(test)]
            relative.pop();
            continue;
        };
        let fd = directories.fd()?;
        let stat = fs::statat(fd, &name, AtFlags::SYMLINK_NOFOLLOW).map_err(io::Error::from)?;
        if tree::is_directory(&stat) {
            #[cfg(test)]
            hook(TreeVisit::BeforeOpen, &relative.join(&name));
            #[cfg(test)]
            relative.push(&name);
            directories.push(name, stat)?;
            #[cfg(test)]
            hook(TreeVisit::AfterOpen, &relative);
        } else {
            fs::unlinkat(fd, &name, AtFlags::empty()).map_err(io::Error::from)?;
        }
    }
    tree::unlink_directory(parent.as_fd(), &name, &identity).map_err(IoFailure::from)
}

fn rename_job(from: &Path, to: &Path) -> Result<(), IoFailure> {
    std::fs::rename(from, to).map_err(|e| {
        // from がファイル、to がディレクトリの失敗は IsDirectory（設計書 03-07）。
        if e.kind() != io::ErrorKind::IsADirectory
            && std::fs::metadata(from).is_ok_and(|m| m.is_file())
            && std::fs::metadata(to).is_ok_and(|m| m.is_dir())
        {
            IoFailure {
                kind: tags::IO_ERROR_KIND_IS_DIRECTORY,
                reason: e.to_string(),
            }
        } else {
            e.into()
        }
    })
}

fn read_bytes_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: PathInput<Vec<u8>>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.File.readBytes";
    let bytes = match output? {
        Ok(bytes) => bytes,
        Err(e) => return result_error(ctx, e, FUNCTION),
    };
    check_input(&bytes, FUNCTION, MAX_STRING_BYTES)?;
    let value = ctx.alloc_bytes(&bytes, FUNCTION)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

fn read_lines_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Vec<u8>, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.File.readLines";
    let bytes = match output {
        Ok(bytes) => bytes,
        Err(e) => return result_error(ctx, e, FUNCTION),
    };
    check_input(&bytes, FUNCTION, MAX_STRING_BYTES)?;
    let s = match std::str::from_utf8(&bytes) {
        Ok(s) => s,
        Err(_) => {
            return result_error(
                ctx,
                io::Error::new(io::ErrorKind::InvalidData, text::INVALID_UTF8).into(),
                FUNCTION,
            );
        }
    };
    let count = super::string::line_parts(s).count();
    check_input_size(count, MAX_LIST_LEN, SizeUnit::Elements, FUNCTION)?;
    let mut lines = Vec::with_capacity(count);
    for part in super::string::line_parts(s) {
        lines.push(
            ctx.alloc_str_utf8(part.as_bytes(), FUNCTION)?
                .ok_or_else(|| Stop::Internal("validated line is not UTF-8".into()))?,
        );
    }
    let value = crate::runtime::list::from_values(ctx, &lines, FUNCTION)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

fn exists_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<bool, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    match output {
        Ok(exists) => ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::Bool(exists)]),
        Err(e) => result_error(ctx, e, "Benitoite.IO.File.exists"),
    }
}

fn info_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<FileInfo, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let info = match output {
        Ok(info) => info,
        Err(e) => return result_error(ctx, e, "Benitoite.IO.File.info"),
    };
    let modified =
        ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[Value::Int(info.modified)])?;
    // File.Info の宣言の順は kind, size, modified（設計書 02-06「脱糖」）。
    let info = ctx.alloc_fields(
        FieldsKind::Ctor,
        tags::RECORD,
        &[
            Value::Tag(CtorTag(info.kind)),
            Value::Int(info.size),
            modified,
        ],
    )?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[info])
}

fn complete_paths<'c, 'e>(
    ctx: &IoCtx<'c, 'e>,
    output: PathInput<Vec<PathBuf>>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let paths = match output? {
        Ok(paths) => paths,
        Err(e) => return result_error(ctx, e, function),
    };
    CheckedLen::elements(super::count(paths.len())?, function)?;
    let mut values = Vec::with_capacity(paths.len());
    for path in &paths {
        let Some(path) = path.to_str() else {
            return result_error(
                ctx,
                io::Error::new(io::ErrorKind::InvalidData, text::INVALID_UTF8).into(),
                function,
            );
        };
        values.push(
            ctx.alloc_str_utf8(path.as_bytes(), function)?
                .ok_or_else(|| Stop::Internal("validated path is not UTF-8".into()))?,
        );
    }
    let value = crate::runtime::list::from_values(ctx, &values, function)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

fn list_directory_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: PathInput<Vec<PathBuf>>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete_paths(ctx, output, "Benitoite.IO.File.listDirectory")
}
fn walk_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: PathInput<Vec<PathBuf>>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete_paths(ctx, output, "Benitoite.IO.File.walk")
}
fn canonicalize_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<PathBuf, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.File.canonicalize";
    let path = match output {
        Ok(path) => path,
        Err(e) => return result_error(ctx, e, FUNCTION),
    };
    let Some(path) = path.to_str() else {
        return result_error(
            ctx,
            io::Error::new(io::ErrorKind::InvalidData, text::INVALID_UTF8).into(),
            FUNCTION,
        );
    };
    let value = ctx
        .alloc_str_utf8(path.as_bytes(), FUNCTION)?
        .ok_or_else(|| Stop::Internal("validated canonical path is not UTF-8".into()))?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

fn write_bytes_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.writeBytes")
}

fn append_bytes_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.appendBytes")
}

fn create_directory_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.createDirectory")
}

fn remove_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.remove")
}

fn remove_tree_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.removeTree")
}

fn rename_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<(), IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output, "Benitoite.IO.File.rename")
}

/// 後から加えた部分の項目。既存の部分の途中に入れると後ろの番号がずれるので、
/// 別の部分にした。末尾以外には加えない。
pub const PATH_DECLS: &[BuiltinDecl] = &[
    read_bytes::DECL,
    read_lines::DECL,
    exists::DECL,
    info::DECL,
    list_directory::DECL,
    walk::DECL,
    canonicalize::DECL,
    write_bytes::DECL,
    append_bytes::DECL,
    create_directory::DECL,
    remove::DECL,
    remove_tree::DECL,
    rename::DECL,
];

builtin! {
    /// `Benitoite.IO.File.readChunk` の本体。
    name = "Benitoite.IO.File.readChunk",
    io fn read_chunk(ctx, reader: ResourceId, maximum_bytes: i64) -> IoReply<'e> {
        let _ = ctx;
        let maximum = u64::try_from(maximum_bytes).ok().filter(|n| *n != 0)
            .ok_or(Stop::Runtime(crate::runtime::RuntimeError::ArgumentOutOfDomain {
                function: "Benitoite.IO.File.readChunk", argument: 1,
            }))?.min(MAX_STRING_BYTES);
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Resource(reader),
            move |lent| {
                let Lent::Resource(resource) = lent else {
                    return Err(Stop::Internal("File.readChunk requires a lent resource".into()));
                };
                let reader = resource.as_any_mut().downcast_mut::<FileReader>()
                    .ok_or_else(|| Stop::Internal("File.readChunk requires File.Reader".into()))?;
                // 小さく返る read でも続け、必要な分だけ確保する。readLine の読みかけも使う
                // （設計書 03-07「File」、02-09「一つの操作で作る値の大きさの上限」）。
                let mut bytes = Vec::new();
                Ok((&mut reader.0).take(maximum).read_to_end(&mut bytes)
                    .map(|_| bytes).map_err(IoFailure::from))
            },
            read_chunk_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.openWriter` の本体。
    name = "Benitoite.IO.File.openWriter",
    io fn open_writer(ctx, path: &'c str, mode: Value<'e>) -> IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().working_directory().join(path);
        let Value::Tag(mode) = mode else {
            return Err(Stop::Internal("File.openWriter requires WriteMode".into()));
        };
        let append = match mode.0 {
            tags::FILE_WRITE_MODE_REPLACE => false,
            tags::FILE_WRITE_MODE_APPEND => true,
            _ => return Err(Stop::Internal("File.openWriter requires WriteMode".into())),
        };
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing,
            move |_| OpenOptions::new().write(true).create(true)
                .append(append).truncate(!append).open(path).map_err(IoFailure::from),
            open_writer_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.File.write` の本体。
    name = "Benitoite.IO.File.write",
    io fn write(ctx, writer: ResourceId, text: &'c str) -> IoReply<'e> {
        let _ = ctx;
        writer_work(writer, text.as_bytes().to_vec(), false, "Benitoite.IO.File.write", write_resource_done)
    }
}

builtin! {
    /// `Benitoite.IO.File.writeLine` の本体。
    name = "Benitoite.IO.File.writeLine",
    io fn write_line(ctx, writer: ResourceId, text: &'c str) -> IoReply<'e> {
        let _ = ctx;
        writer_work(writer, text.as_bytes().to_vec(), true, "Benitoite.IO.File.writeLine", write_line_resource_done)
    }
}

builtin! {
    /// `Benitoite.IO.File.writeChunk` の本体。
    name = "Benitoite.IO.File.writeChunk",
    io fn write_chunk(ctx, writer: ResourceId, data: &'c [u8]) -> IoReply<'e> {
        let _ = ctx;
        writer_work(writer, data.to_vec(), false, "Benitoite.IO.File.writeChunk", write_chunk_resource_done)
    }
}

builtin! {
    /// `IO.File.closeWriter` の本体。
    name = "IO.File.closeWriter",
    state fn close_writer(ctx, writer: ResourceId) -> StateReply<'e> {
        let mut ctx = ctx;
        match ctx.services().begin_close(writer)? {
            CloseStep::Wait(wait) => Ok(StateReply::Wait(wait)),
            CloseStep::Done(reason) => {
                let value = match reason {
                    None => ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::Unit])?,
                    Some(reason) => {
                        let reason = ctx.alloc_str(&reason, "IO.File.closeWriter")?;
                        let error = ctx.alloc_fields(FieldsKind::IoError, tags::IO_ERROR_KIND_OTHER, &[reason])?;
                        ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])?
                    }
                };
                Ok(StateReply::Done(value))
            }
        }
    }
}

#[derive(Debug)]
struct FileWriter {
    writer: Option<BufWriter<File>>,
    failure: Option<IoFailure>,
}

impl FileWriter {
    fn new(file: File) -> Self {
        Self {
            writer: Some(BufWriter::new(file)),
            failure: None,
        }
    }

    fn write(&mut self, bytes: &[u8], newline: bool, function: &str) -> WriteOutput {
        if let Some(failure) = &self.failure {
            return Ok(Err(failure.clone()));
        }
        let writer = self
            .writer
            .as_mut()
            .ok_or_else(|| Stop::Internal(format!("{function} requires File.Writer")))?;
        let result = writer.write_all(bytes).and_then(|()| {
            if newline {
                writer.write_all(b"\n")
            } else {
                Ok(())
            }
        });
        if let Err(error) = result {
            // どこまで書けたかが分からないため、残りを再試行しない
            // （設計書 03-07「File」）。BufWriter の drop による書き出しも防ぐ。
            if let Some(writer) = self.writer.take() {
                drop(writer.into_parts());
            }
            let failure = IoFailure::from(error);
            self.failure = Some(failure.clone());
            return Ok(Err(failure));
        }
        Ok(Ok(()))
    }
}

impl OsResource for FileWriter {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }

    /// 開いた状態なら書き出して閉じ、失敗の状態なら記録した失敗を返す。
    /// ディスクへの同期は要求しないので `sync_all` は呼ばず、失敗した書き出しを
    /// drop で再試行しない（設計書 03-07「File」）。
    fn release(mut self: Box<Self>) -> Result<(), String> {
        if let Some(failure) = self.failure.take() {
            return Err(failure.reason);
        }
        let mut writer = self
            .writer
            .take()
            .ok_or_else(|| text::WRITER_BUFFER_MISSING.to_owned())?;
        let result = writer.flush().map_err(|e| e.to_string());
        drop(writer.into_parts());
        result
    }
}

impl Drop for FileWriter {
    fn drop(&mut self) {
        // 束縛の文の未解放の Writer は、実行を捨てるときに書き出さない
        // （設計書 02-09「リソースの追跡」）。BufWriter の drop に任せない。
        if let Some(writer) = self.writer.take() {
            drop(writer.into_parts());
        }
    }
}

type WriteOutput = Result<Result<(), IoFailure>, Stop>;

fn writer_work<'e>(
    writer: ResourceId,
    bytes: Vec<u8>,
    newline: bool,
    function: &'static str,
    complete: crate::builtins::iface::CompleteFn<WriteOutput>,
) -> Result<IoReply<'e>, Stop> {
    Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
        Lend::Resource(writer),
        move |lent| {
            let Lent::Resource(resource) = lent else {
                return Err(Stop::Internal(format!(
                    "{function} requires a lent resource"
                )));
            };
            let writer = resource
                .as_any_mut()
                .downcast_mut::<FileWriter>()
                .ok_or_else(|| Stop::Internal(format!("{function} requires File.Writer")))?;
            writer.write(&bytes, newline, function)
        },
        complete,
    ))))
}

fn read_chunk_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Result<Vec<u8>, IoFailure>, Stop>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.File.readChunk";
    let bytes = match output? {
        Ok(bytes) => bytes,
        Err(failure) => return result_error(ctx, failure, FUNCTION),
    };
    let option = if bytes.is_empty() {
        Value::Tag(CtorTag(tags::OPTION_NONE))
    } else {
        let bytes = ctx.alloc_bytes(&bytes, FUNCTION)?;
        ctx.alloc_fields(FieldsKind::Ctor, tags::OPTION_SOME, &[bytes])?
    };
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[option])
}

fn open_writer_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<File, IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    match output {
        Ok(file) => {
            let site = ctx.site();
            let writer = ctx.services().register_resource(
                ResourceKind::FileWriter,
                Box::new(FileWriter::new(file)),
                site,
            );
            ctx.alloc_fields(
                FieldsKind::Ctor,
                tags::RESULT_OK,
                &[Value::Resource(writer)],
            )
        }
        Err(failure) => result_error(ctx, failure, "Benitoite.IO.File.openWriter"),
    }
}

fn write_resource_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: WriteOutput,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output?, "Benitoite.IO.File.write")
}

fn write_line_resource_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: WriteOutput,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output?, "Benitoite.IO.File.writeLine")
}

fn write_chunk_resource_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: WriteOutput,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    write_done(ctx, output?, "Benitoite.IO.File.writeChunk")
}

/// 後から加えた部分の項目。既存の部分の途中に入れると後ろの番号がずれるので、
/// 別の部分にした。末尾以外には加えない。
pub const RESOURCE_DECLS: &[BuiltinDecl] = &[
    read_chunk::DECL,
    open_writer::DECL,
    write::DECL,
    write_line::DECL,
    write_chunk::DECL,
    close_writer::DECL,
];
