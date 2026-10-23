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

pub(super) const CHARACTER_COVERAGE_CHANGE: &str = "Character ranges covering all Unicode scalar values are exhaustive; a following catch-all is unreachable";
pub(super) const CHARACTER_COVERAGE_MIGRATION: &str = "review full-domain Character matches and remove unreachable branches or move their work into reachable branches; keep catch-alls for guarded Character ranges and Integer ranges; update E0601 character witness snapshots, language declarations to the current version, and dependency hashes; see the 0.0.8 section of CHANGELOG.md";

pub(super) const CONSTANT_REGEX_CHANGE: &str = "direct Regex.compile calls reject invalid constant sources with E0457 or E0458; direct Scope checks reject invalid known arguments with E0459 through E0462";
pub(super) const CONSTANT_REGEX_MIGRATION: &str = "to test Result.Error, pass the pattern to a normal function whose parameters are used by Regex.compile or Scope checks; review constant patterns, language declarations and dependency hashes; see the 0.0.9 section of CHANGELOG.md";

pub(super) const SYNTAX_BATCH4_CHANGE: &str = "`block` is reserved; Integer ranges covering the full signed 64-bit domain are exhaustive and a following catch-all is unreachable";
pub(super) const SYNTAX_BATCH4_MIGRATION: &str = "rename identifiers spelled `block`; review full-domain Integer matches and remove unreachable branches or correct their intervals; keep catch-alls for guarded or incomplete ranges; review Log and SourceLocation prelude names, explicit Log permissions, width-specific numeric warnings under --deny-warnings, and derive version 3 records; update language declarations to the current version and dependency hashes after reviewing the source; see the 0.0.10 section of CHANGELOG.md";

pub(super) const SYNTAX_BATCH5_CHANGE: &str = "derive uses inventory 3 and generator 3.1.0; try-actions uses inventory and manifest 2; package effect records now recognize prelude Log and file-level declarations";
pub(super) const SYNTAX_BATCH5_MIGRATION: &str = "recheck old derive records with a fresh preview that verifies source bodies and hashes, apply with its reviewed manifest hash, then check; regenerate and review old try-actions manifests; review Log records and package update effect additions and removals; update language declarations and dependency hashes after reviewing the source; see the 0.0.11 section of CHANGELOG.md";
