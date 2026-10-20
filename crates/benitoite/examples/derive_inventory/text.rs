//! 生成宣言の読み取り用 example の文言（設計書 02-10「文言の言語」）。
pub const CUSTOM_FUNCTIONS_MUST_HAVE_QUALIFIED_NAMES: &str =
    "custom functions must have qualified names";
pub const CUSTOM_FUNCTION_IS_NOT_PUBLIC: &str = "custom function is not public";
pub const DECODEMISSING_REQUIRES_DECODE: &str = "decodeMissing requires decode";
pub const DUPLICATE_JSON_FIELD_KEY: &str = "duplicate JSON field key";
pub const DUPLICATE_TARGET_OR_REGION: &str = "duplicate target or region";
pub const EXPECTED_AN_OBJECT: &str = "expected an object";
pub const EXPECTED_AN_OBJECT_OF_STRINGS: &str = "expected an object of strings";
pub const EXPECTED_CUSTOM_FUNCTION_NAME: &str = "expected custom function name";
pub const EXPECTED_FIELDS_OBJECT: &str = "expected fields object";
pub const EXPECTED_FIELD_MAPPING: &str = "expected field mapping";
pub const EXPECTED_FIELD_OBJECT: &str = "expected field object";
pub const EXPECTED_FIELD_SETTINGS: &str = "expected field settings";
pub const EXPECTED_FUNCTION_NAME: &str = "expected function name";
pub const EXPECTED_STRING_VALUES: &str = "expected string values";
pub const EXPECTED_TARGETS: &str = "expected targets";
pub const EXPECTED_TARGETS_ARRAY: &str = "expected targets array";
pub const INVALID_MODULE_NAME: &str = "invalid module name";
pub const INVALID_REGION_NAME: &str = "invalid region name";
pub const JSON_WITHOUT_DUPLICATE_KEYS: &str = "JSON without duplicate keys";
pub const MISSING_FIELDS: &str = "missing fields";
pub const MISSING_FUNCTION_BINDING: &str = "missing function binding";
pub const MISSING_FUNCTION_SIGNATURE: &str = "missing function signature";
pub const MISSING_RECORD_BINDING: &str = "missing record binding";
pub const MISSING_RECORD_CONSTRUCTOR: &str = "missing record constructor";
pub const MISSING_RECORD_SIGNATURE: &str = "missing record signature";
pub const MISSING_RECORD_TYPE: &str = "missing record type";
pub const MISSING_SOURCE: &str = "missing source";
pub const SOURCE_ESCAPES_ROOT: &str = "source escapes root";
pub const SOURCE_MUST_BE_RELATIVE_TO_ROOT: &str = "source must be relative to root";
pub const TARGET_SOURCE_DOES_NOT_MATCH_DECLARATION: &str =
    "target source does not match declaration";
pub const TYPE_MUST_INCLUDE_ITS_MODULE_NAME: &str = "type must include its module name";
pub const UNSUPPORTED_CONFIG_VERSION: &str = "unsupported config version";

pub fn duplicate_key(k: &str) -> String {
    format!("duplicate key: {k}")
}
pub fn unknown_key(k: &str) -> String {
    format!("unknown key: {k}")
}
pub fn expected_string(k: &str) -> String {
    format!("expected nonempty string: {k}")
}
pub fn expected_boolean(k: &str) -> String {
    format!("expected boolean: {k}")
}
pub fn required_pair(a: &str, b: &str) -> String {
    format!("{a} and {b} must be specified together")
}
pub fn not_record(name: &str) -> String {
    format!("target is not a record: {name}")
}
pub fn unknown_field(name: &str) -> String {
    format!("unknown field: {name}")
}
pub fn unknown_function(name: &str) -> String {
    format!("unknown custom function: {name}")
}
pub fn declaration_failure(d: &[benitoite::diag::Diagnostic]) -> String {
    format!("declaration collection failed: {d:?}")
}

pub const MISSING_ENTRY_MODULE: &str = "missing inventory entry module";
pub const MISSING_IMPORTED_MODULE: &str = "missing imported module";

pub const INVALID_SCHEMA: &str = "invalid declaration inventory type, kind, or signature";
pub const OPAQUE_TARGET: &str =
    "derive.opaque_target: opaque type requires handwritten checked construction";
