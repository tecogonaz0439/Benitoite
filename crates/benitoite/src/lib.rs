//! Benitoite の処理系（初回リリース版）。
//! 段の並びと段の間のデータは設計書 02-01 パイプラインで定める。

pub mod base;
pub mod builtins;
pub mod bytecode;
pub mod cli;
pub mod diag;
pub mod external;
pub mod ir;
pub mod modules;
pub mod pipeline;
pub mod prelude;
pub mod refinterp;
pub mod resolve;
pub mod runtime;
pub mod syntax;
pub mod typeck;
pub mod types;
pub mod vm;

// 統合検査と同じ交換器を、未公開構文のクレート内部の入口からも検査する。
#[cfg(test)]
extern crate self as benitoite;
#[cfg(test)]
#[path = "../tests/desugar_export/lib.rs"]
mod exchange_tests;
