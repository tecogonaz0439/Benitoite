//! 中間表現（設計書 02-06）。
//! core_ir.rs: コア IR、lower_ir.rs: 下位 IR、desugar.rs: 脱糖、decision.rs: 判定の木への変換、
//! check.rs: コア IR の検査器。型の形は実装プラン 10-06 で定める。

pub mod check;
pub mod core_ir;
pub mod decision;
pub mod desugar;
pub mod lower_ir;

/// 脱糖・判定の木への変換・コード生成で処理を続けられないときの報告（処理系の不具合。02-01）。
#[derive(Clone, PartialEq, Debug)]
pub struct InternalError {
    /// 段の名前（`"desugar"`、`"decision"`、`"codegen"`）
    pub stage: &'static str,
    pub message: String,
}
