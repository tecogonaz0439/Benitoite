//! 読み込みの診断に埋め込む理由（設計書 02-02「ソースの大きさの上限」、AGENTS.md「実装の規約」の「文言」）。

pub(super) const NAMED_ARGUMENTS_CHANGE: &str = "calls with two or more parameters require named arguments; function types and higher-order contracts require parameter names, and function values must match those names in order";
pub(super) const NAMED_ARGUMENTS_MIGRATION: &str =
    "see the 0.0.5 section of CHANGELOG.md for named arguments and named function types";
pub(super) const LANGUAGE_CHANGE: &str = "{version}: {summary}";

pub(super) const KEYWORDS_OPEN_TYPES_TRY_CHANGE: &str = "`die` is reserved; IOErrorKind, NetworkErrorKind, Json.ParseError, and Csv.ParseError are @extensible; return values must start on the same physical line as `return`";
pub(super) const KEYWORDS_OPEN_TYPES_TRY_MIGRATION: &str = "rename user-defined names spelled `die`; outside the defining package, add an unguarded `case other` or `case _` to cover future @extensible values in matches, and use a variable or `_` instead of destructuring them in bindings; record `..` covers only declared fields, while construction, updates, and getters keep their declared field contracts; start each return value on the same physical line as `return` (the value may continue across lines after it starts); use `try value or return`, `try value or die`, or `try value or die(message)` to make the failure action explicit; bare `try value` still returns failure from the innermost function or lambda; see CHANGELOG.md for migration details";

pub(super) const LOADER_ENVIRONMENT_CHANGE: &str = "Command.environment rejects names starting with DYLD_ or LD_ (ASCII case-insensitive), including build-tool variables such as LD_RUN_PATH";
pub(super) const LOADER_ENVIRONMENT_MIGRATION: &str = "review explicit settings of DYLD_ and LD_ variables, including LD_RUN_PATH used by build tools; run and runAttached return IOErrorKind.InvalidInput before starting a child; inherited variables are unchanged; update the language declaration to the current version after reviewing the script, update dependency hashes, and see CHANGELOG.md for migration details";

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
