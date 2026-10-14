//! 符号なしの幅ごとの算術を、型付きの組み込み呼び出しで実行する
//! （設計書 01-04「Integer」、02-08「組み込みの関数の呼び出し」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::{RuntimeError, Stop};

// 各幅の検査付き演算で、あふれと負の結果を同じ停止理由に揃える。
macro_rules! unsigned_operators {
    ($module:ident, $ty:ty, $add:literal, $sub:literal, $mul:literal,
     $div:literal, $mod:literal) => {
        mod $module {
            use super::*;

            builtin! {
                /// 同じ幅の和を返し、あふれたら停止する。
                name = $add,
                pure fn add(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    a.checked_add(b).ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
                }
            }
            builtin! {
                /// 同じ幅の差を返し、負の結果なら停止する。
                name = $sub,
                pure fn subtract(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    a.checked_sub(b).ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
                }
            }
            builtin! {
                /// 同じ幅の積を返し、あふれたら停止する。
                name = $mul,
                pure fn multiply(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    a.checked_mul(b).ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
                }
            }
            builtin! {
                /// 整数の商を返し、除数が 0 なら停止する。
                name = $div,
                pure fn divide(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    a.checked_div(b).ok_or(Stop::Runtime(RuntimeError::DivisionByZero))
                }
            }
            builtin! {
                /// 剰余を返し、除数が 0 なら停止する。
                name = $mod,
                pure fn modulo(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    a.checked_rem(b).ok_or(Stop::Runtime(RuntimeError::DivisionByZero))
                }
            }
        }
    };
}

unsigned_operators!(
    unsigned_integer16,
    u16,
    "%UnsignedInteger16.add",
    "%UnsignedInteger16.subtract",
    "%UnsignedInteger16.multiply",
    "%UnsignedInteger16.div",
    "%UnsignedInteger16.mod"
);
unsigned_operators!(
    unsigned_integer32,
    u32,
    "%UnsignedInteger32.add",
    "%UnsignedInteger32.subtract",
    "%UnsignedInteger32.multiply",
    "%UnsignedInteger32.div",
    "%UnsignedInteger32.mod"
);
unsigned_operators!(
    unsigned_integer64,
    u64,
    "%UnsignedInteger64.add",
    "%UnsignedInteger64.subtract",
    "%UnsignedInteger64.multiply",
    "%UnsignedInteger64.div",
    "%UnsignedInteger64.mod"
);

/// 既存の関数の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    unsigned_integer16::add::DECL,
    unsigned_integer16::subtract::DECL,
    unsigned_integer16::multiply::DECL,
    unsigned_integer16::divide::DECL,
    unsigned_integer16::modulo::DECL,
    unsigned_integer32::add::DECL,
    unsigned_integer32::subtract::DECL,
    unsigned_integer32::multiply::DECL,
    unsigned_integer32::divide::DECL,
    unsigned_integer32::modulo::DECL,
    unsigned_integer64::add::DECL,
    unsigned_integer64::subtract::DECL,
    unsigned_integer64::multiply::DECL,
    unsigned_integer64::divide::DECL,
    unsigned_integer64::modulo::DECL,
];
