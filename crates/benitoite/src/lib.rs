//! Benitoite の処理系（初回リリース版）。
//! 段の並びと段の間のデータは設計書 02-01 パイプラインで定める。

// 作業の途中では、後の作業が使う型の欄が読まれないので dead_code の警告が出る。
// C01 がこの指定を置き、U1・U2 を終えた後に外す
// （実装プラン 90-after-completion「移行の締めの残り」）。
#![allow(dead_code)]

pub mod base;
pub mod builtins;
pub mod bytecode;
pub mod cli;
pub mod diag;
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
