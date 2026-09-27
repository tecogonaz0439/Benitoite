//! Benitoite の処理系（最小実行版）。
//! 段の並びと段の間のデータは設計書 02-01 パイプラインで定める。

pub mod base;
pub mod builtins;
pub mod bytecode;
pub mod cli;
pub mod diag;
pub mod ir;
pub mod pipeline;
pub mod prelude;
pub mod refinterp;
pub mod resolve;
pub mod runtime;
pub mod syntax;
pub mod typeck;
pub mod types;
pub mod vm;
