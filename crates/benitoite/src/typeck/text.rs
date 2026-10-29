//! 型検査の診断に埋める固定の文言（設計書 02-10「文言の言語」）。

pub(super) const NOT_COVERED: &str = "notCovered";
pub(super) const ATOMIC_COVER_ONLY: &str = "atomicCoverOnly";
pub(super) const UNKNOWN_SOURCE: &str = "unknownSource";

pub(super) const MAIN_MODULE: &str = "main";
pub(super) const STANDARD_PACKAGE: &str = "Benitoite";
pub(super) const INTEGER_OVERFLOW: &str = "integer overflow";
pub(super) const DECIMAL_OVERFLOW: &str = "Decimal overflow";
pub(super) const DIVISION_BY_ZERO: &str = "division by zero";
pub(super) const INTEGER_TO_STRING: &str = "Integer.toString";
pub(super) const FLOAT_TO_STRING: &str = "Float.toString";
pub(super) const CHARACTER_TO_STRING: &str = "Character.toString";
pub(super) const FORMAT_EMPTY_TYPES: &str =
    "no types (sign and zero padding require a numeric type)";
pub(super) const COVERAGE_MATCH: &str = "this `match` covers every value";
pub(super) const COVERAGE_PATTERN: &str = "this pattern matches every value";
pub(super) fn type_declaration(name: &str, file: &str, line: u32, column: u32) -> String {
    format!("`{name}` is declared at {file}:{line}:{column}")
}
pub(super) fn future_shape(name: &str, record: bool) -> String {
    if record {
        format!("<future shape of {name}>")
    } else {
        format!("<future constructor of {name}>")
    }
}
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

/// 契約の宣言順を、診断の名前の一覧でも維持する。
pub(super) fn parameter_names(names: &[String]) -> String {
    names
        .iter()
        .map(|n| format!("`{n}`"))
        .collect::<Vec<_>>()
        .join(", ")
}

/// E0609 は探索・列挙・記憶のいずれの上限でも同じ拒否を示す。
pub(super) fn coverage_limits() -> String {
    use super::limits::{
        MAX_COVERAGE_ENUM_WORK, MAX_COVERAGE_KEY_BYTES, MAX_COVERAGE_MEMO_CELLS, MAX_COVERAGE_WORK,
    };
    format!(
        "{MAX_COVERAGE_WORK} search cells, {MAX_COVERAGE_ENUM_WORK} enumeration/key steps, {MAX_COVERAGE_MEMO_CELLS} memo cells, {MAX_COVERAGE_KEY_BYTES} key bytes"
    )
}

/// 必須判定の予算の超過と、確定した呼び出しの鍵。
pub(super) const BUDGET_EXCEEDED: &str = "budgetExceeded";
pub(super) const SCOPE_BUDGET_BODY: &str = "body";
pub(super) const SCOPE_BUDGET_WHOLE: &str = "whole";
pub(super) const SCOPE_BUDGET_OPERATIONS: &str = "operations";
pub(super) const SCOPE_BUDGET_ITEMS: &str = "items";
pub(super) const SCOPE_RULE_CONTRACT: &str = "the annotated scope contract (requiredUpperBound)";
pub(super) fn scope_key(definition: &str, preorder: Option<u64>) -> String {
    match preorder {
        Some(preorder) => format!("scope call: {definition} at surface preorder {preorder}"),
        None => format!("scope call: {definition}; budget exceeded; surface preorder unavailable"),
    }
}

/// 番号付けの実装固有の上限。局所解析の四上限と区別して表示する。
pub(super) fn scope_numbering_limit(limit: u64) -> String {
    limit.to_string()
}

/// 範囲の診断の補足欄。JSON の構造を増やさず notes でも同じ鍵を示す。
pub(super) const SCOPE_REQUIRED_UPPER_BOUND: &str = "requiredUpperBound";
pub(super) const SCOPE_KNOWN_UPPER_BOUND: &str = "knownUpperBound";
pub(super) const SCOPE_UNCOVERED_ATOM: &str = "uncoveredAtom";
pub(super) const SCOPE_SOURCE: &str = "source";
pub(super) const SCOPE_REASON: &str = "reason";
pub(super) const SCOPE_CONTRACT_ANNOTATION: &str =
    "the scope contract is required by this annotation";
pub(super) const SCOPE_SUCCESS_CHECK: &str = "the same successful checked value originates here";
pub(super) const SCOPE_LITERAL_SOURCE: &str = "literal check conditions";
pub(super) const SCOPE_UNKNOWN_CONDITIONS: &str =
    "the check conditions are not statically known at this call";
pub(super) const SCOPE_UNKNOWN_SOURCE: &str =
    "no local provenance for the same successful checked value at this call";
pub(super) const SCOPE_NUMBERING_SOURCE: &str =
    "numbering stopped; every Scope rule in this definition requires Top";
pub(super) const SCOPE_BUDGET_SOURCE: &str = "the final pass of local Scope analysis remains over budget; checked-value provenance was forgotten";
pub(super) const SCOPE_EFFECT_SOURCE: &str = "the effect flowing from this call or expression";

pub(super) fn scope_field(name: &str, value: &str) -> String {
    format!("{name}: {value}")
}
pub(super) fn scope_range(range: &crate::types::scope::Range) -> String {
    match range {
        crate::types::scope::Range::Top => "Top (all targets)".into(),
        crate::types::scope::Range::Path(_)
        | crate::types::scope::Range::Host(_)
        | crate::types::scope::Range::Endpoint(_) => range.suffix(),
    }
}
pub(super) fn scope_success_source(definition: &str, preorder: u64) -> String {
    format!("successful check in {definition} at surface preorder {preorder}")
}

/// 拡大の二つの範囲は元と行き先を区別し、配列の順を読者に推測させない。
pub(super) fn scope_widen_contract(ranges: &[crate::types::scope::Range]) -> String {
    match ranges {
        [source, destination] => format!(
            "source {}; destination {}",
            scope_range(source),
            scope_range(destination)
        ),
        _ => ranges
            .iter()
            .map(scope_range)
            .collect::<Vec<_>>()
            .join(", "),
    }
}
