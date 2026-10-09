//! 組み込みの関数（設計書 02-08「組み込みの関数の呼び出し」、02-09「組み込みの操作とハンドラ表」、03-01）。
//! iface.rs: 型付きの形（実装プラン 10-11）、table.rs: 組み込みの表（10-11・10-12）、
//! funcs: 組み込みの関数の本体（子のモジュールは組み込みの関数を書く作業が加える）。

pub mod funcs;
pub mod iface;
pub mod table;

pub use table::{builtin_decl, lookup_builtin};

/// 組み込みの関数の番号（組み込みの表の中の位置）。組み込みの関数は 65536 個に満たない。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinId(pub u16);
