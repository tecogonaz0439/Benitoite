//! 種類の合わない名前（E0304）の `{found_kind}` と `{expected_kind}` に埋める種類の呼び名
//! （実装プラン 00-02「文言」）。診断の型板そのものは `diag::codes` の表にある。

pub(super) const TYPE: &str = "a type";
pub(super) const MODULE: &str = "a module";
pub(super) const EFFECT: &str = "an effect";
pub(super) const CONSTRUCTOR: &str = "a constructor";
pub(super) const VALUE: &str = "a value";
pub(super) const TYPE_PARAMETER: &str = "a type parameter";
pub(super) const EFFECT_VARIABLE: &str = "an effect variable";
pub(super) const TRAIT: &str = "a trait";
pub(super) const RECORD: &str = "a record";
pub(super) const FUNCTION: &str = "function";
pub(super) const CONSTANT: &str = "constant";
pub(super) const DATA: &str = "type";
pub(super) const ALIAS: &str = "type alias";
pub(super) const RECORD_DECL: &str = "record";
pub(super) const TRAIT_DECL: &str = "trait";
pub(super) const EFFECT_DECL: &str = "effect";
pub(super) const LAMBDA_PARAM: &str = "lambda parameter";
pub(super) const PATTERN_VAR: &str = "pattern variable";
pub(super) const CLAUSE_PARAM: &str = "handler clause parameter";
pub(super) const WITH_VAR: &str = "with binding";
pub(super) const NAMESPACE: &str = "a namespace";
