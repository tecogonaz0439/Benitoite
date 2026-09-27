//! 種類の合わない名前（E0304）の `{found_kind}` と `{expected_kind}` に埋める種類の呼び名
//! （実装プラン 00-02「文言」）。診断の型板そのものは `diag::codes` の表にある。

pub(super) const TYPE: &str = "a type";
pub(super) const MODULE: &str = "a module";
pub(super) const EFFECT: &str = "an effect";
pub(super) const CONSTRUCTOR: &str = "a constructor";
pub(super) const VALUE: &str = "a value";
pub(super) const TYPE_PARAMETER: &str = "a type parameter";
pub(super) const EFFECT_VARIABLE: &str = "an effect variable";
