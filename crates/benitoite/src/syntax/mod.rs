//! 字句解析と構文解析（設計書 02-03）。
//! 処理の流れ: lexer（字句の切り出し）→ newline（改行の判定）→ parser（構文解析）。

pub mod ast;
pub mod lexer;
pub mod newline;
pub mod parser;
pub mod token;
