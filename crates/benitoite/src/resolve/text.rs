//! 名前の種類と公開の段階の呼び名を診断の型板へ渡す（設計書 02-10「文言の言語」）。
//! 診断の型板そのものは `diag::codes` の表にある。

pub(super) const PUBLIC: &str = "public";
pub(super) const PACKAGE: &str = "public(package)";
pub(super) const PACKAGE_LEVEL: &str = "`public(package)`";
pub(super) const NON_PUBLIC: &str = "non-public";

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

// 注記では冠詞を型板が持つため、種類の名だけを渡す（設計書 02-04「名前の引き方」）。
pub(super) const MODULE_NAME: &str = "module";
pub(super) const NAMESPACE_NAME: &str = "namespace";
pub(super) const CONSTRUCTOR_NAME: &str = "constructor";
pub(super) const TYPE_PARAMETER_NAME: &str = "type parameter";
pub(super) const EFFECT_VARIABLE_NAME: &str = "effect variable";
pub(super) const VALUE_NAME: &str = "value";
