//! バイトコードとコード生成（設計書 02-07）。
//! instr.rs: 命令の符号化、program.rs: コンパイル済みプログラム、liveness.rs: 生存の情報、
//! codegen.rs: コード生成、disasm.rs: 逆アセンブラ、verify.rs: 読み込みのときの検証器（設計書 02-08「実行の手順」）、
//! asm.rs: テスト用のバイトコードの組み立て（10-07「第 1 段で実行するプログラム」）。

#[cfg(test)]
pub(crate) mod asm;
pub mod codegen;
pub mod disasm;
pub mod instr;
pub mod liveness;
pub mod program;
pub mod verify;
