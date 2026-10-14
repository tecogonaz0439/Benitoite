//! 読み込みの診断に埋め込む理由（設計書 02-02「ソースの大きさの上限」、AGENTS.md「実装の規約」の「文言」）。

pub(super) const SOURCE_TOO_LARGE: &str = "the source file exceeds the size limit of 256 MiB";
pub(super) const TOTAL_TOO_LARGE: &str =
    "the total size of all sources exceeds the size limit of 512 MiB";

pub(super) use crate::syntax::header::{DEPENDENCY, HASH, LANGUAGE, PATH};

pub(super) const ROOT_DIRECTORY: &str = "the root directory";
pub(super) const PACKAGE_ROOT: &str = "the package root";
pub(super) const IO_NOT_FOUND: &str = "the path does not exist";
pub(super) const IO_PERMISSION_DENIED: &str = "permission denied";
pub(super) const IO_NOT_DIRECTORY: &str = "the path is not a directory";
pub(super) const IO_IS_DIRECTORY: &str = "the path is a directory";
pub(super) const IO_INVALID_INPUT: &str = "invalid file or path";
pub(super) const IO_INVALID_DATA: &str = "invalid file data";
pub(super) const IO_INTERRUPTED: &str = "the operation was interrupted";
pub(super) const IO_OTHER: &str = "file system operation failed";

pub(super) const IO_REASONS: &[(std::io::ErrorKind, &str)] = &[
    (std::io::ErrorKind::NotFound, IO_NOT_FOUND),
    (std::io::ErrorKind::PermissionDenied, IO_PERMISSION_DENIED),
    (std::io::ErrorKind::NotADirectory, IO_NOT_DIRECTORY),
    (std::io::ErrorKind::IsADirectory, IO_IS_DIRECTORY),
    (std::io::ErrorKind::InvalidInput, IO_INVALID_INPUT),
    (std::io::ErrorKind::InvalidData, IO_INVALID_DATA),
    (std::io::ErrorKind::Interrupted, IO_INTERRUPTED),
];
