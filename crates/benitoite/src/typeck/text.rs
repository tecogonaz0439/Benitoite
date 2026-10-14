//! 型検査の診断に埋める固定の文言（設計書 02-10「文言の言語」）。

pub(super) const INTEGER_OVERFLOW: &str = "integer overflow";
pub(super) const DECIMAL_OVERFLOW: &str = "Decimal overflow";
pub(super) const DIVISION_BY_ZERO: &str = "division by zero";
pub(super) const INTEGER_TO_STRING: &str = "Integer.toString";
pub(super) const FLOAT_TO_STRING: &str = "Float.toString";
pub(super) const CHARACTER_TO_STRING: &str = "Character.toString";
pub(super) const COVERAGE_MATCH: &str = "this `match` covers every value";
pub(super) const COVERAGE_PATTERN: &str = "this pattern matches every value";
pub(super) const TYPE_DEPTH: &str = " levels in a type";
pub(super) const TYPE_NODES: &str = " nodes in a type";

pub(super) fn numeric_suffix(ty: crate::types::builtin::BuiltinTypeId) -> Option<&'static str> {
    use crate::types::builtin::BuiltinTypeId as B;
    match ty {
        B::INTEGER => Some("s64"),
        B::FLOAT => Some("f64"),
        B::BYTE => Some("u8"),
        B::INTEGER8 => Some("s8"),
        B::INTEGER16 => Some("s16"),
        B::INTEGER32 => Some("s32"),
        B::UNSIGNED_INTEGER16 => Some("u16"),
        B::UNSIGNED_INTEGER32 => Some("u32"),
        B::UNSIGNED_INTEGER64 => Some("u64"),
        B::FLOAT32 => Some("f32"),
        _ => None,
    }
}

pub(super) fn const_string_limit(limit: u64) -> String {
    format!("the string would exceed the limit of {limit} bytes")
}
pub(super) fn const_list_limit(limit: u64) -> String {
    format!("the list would exceed the limit of {limit} elements")
}
pub(super) fn const_budget_limit(limit: usize) -> String {
    format!("the constants would exceed the budget of {limit} bytes")
}

/// 演算子の診断に示す綴り。理由の種類と既定値は呼ぶ側で決める。
pub(super) fn operator_spelling(op: super::infer::OpName) -> &'static str {
    use super::infer::OpName;
    use crate::syntax::ast::{BinOp, UnOp};
    match op {
        OpName::Un(UnOp::Neg) => "-",
        OpName::Un(UnOp::Not) => "not",
        OpName::Bin(b) => match b {
            BinOp::Add => "+",
            BinOp::Sub => "-",
            BinOp::Mul => "*",
            BinOp::Div => "/",
            BinOp::IntDiv => "div",
            BinOp::Mod => "mod",
            BinOp::Eq => "=",
            BinOp::Ne => "<>",
            BinOp::Lt => "<",
            BinOp::Le => "<=",
            BinOp::Gt => ">",
            BinOp::Ge => ">=",
            BinOp::And => "and",
            BinOp::Or => "or",
        },
    }
}
/// 戻り値の修正案に示す関数の呼び方。
pub(super) const FUNCTION: &str = "function";
/// 戻り値の修正案に示すラムダの呼び方。
pub(super) const LAMBDA: &str = "lambda";

pub(super) const USES_STATE: &str = " uses State";
