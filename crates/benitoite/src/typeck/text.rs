//! 型検査の診断に埋める固定の文言（設計書 02-10「文言の言語」）。

pub(super) const INTEGER_OVERFLOW: &str = "integer overflow";
pub(super) const DECIMAL_OVERFLOW: &str = "Decimal overflow";
pub(super) const DIVISION_BY_ZERO: &str = "division by zero";
pub(super) const INTEGER_TO_STRING: &str = "Integer.toString";
pub(super) const FLOAT_TO_STRING: &str = "Float.toString";
pub(super) const CHARACTER_TO_STRING: &str = "Character.toString";
pub(super) const TYPE_DEPTH: &str = " levels in a type";
pub(super) const TYPE_NODES: &str = " nodes in a type";
