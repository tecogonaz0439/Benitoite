//! 符号付きの幅ごとの算術を、型付きの組み込み呼び出しで実行する
//! （設計書 01-04「Integer」、02-08「組み込みの関数の呼び出し」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::{RuntimeError, Stop};

// 検査付きの演算を各幅で行い、商のあふれと除数 0 の停止理由を揃える。
macro_rules! signed_operators {
    ($module:ident, $ty:ty, $add:literal, $sub:literal, $mul:literal,
     $div:literal, $mod:literal, $neg:literal) => {
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
                /// 同じ幅の差を返し、あふれたら停止する。
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
                /// 0 の方向へ切り捨てた商を返す。
                name = $div,
                pure fn divide(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    if b == 0 {
                        return Err(Stop::Runtime(RuntimeError::DivisionByZero));
                    }
                    a.checked_div(b).ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
                }
            }
            builtin! {
                /// 左辺と同符号の剰余を返す。最小値 mod -1 の剰余は 0 である。
                name = $mod,
                pure fn modulo(ctx, a: $ty, b: $ty) -> $ty {
                    let _ = ctx;
                    if b == 0 {
                        return Err(Stop::Runtime(RuntimeError::DivisionByZero));
                    }
                    Ok(a.checked_rem(b).unwrap_or(0))
                }
            }
            builtin! {
                /// 符号を反転し、最小値なら停止する。
                name = $neg,
                pure fn negate(ctx, a: $ty) -> $ty {
                    let _ = ctx;
                    a.checked_neg().ok_or(Stop::Runtime(RuntimeError::IntegerOverflow))
                }
            }
        }
    };
}

signed_operators!(
    integer8,
    i8,
    "%Integer8.add",
    "%Integer8.subtract",
    "%Integer8.multiply",
    "%Integer8.div",
    "%Integer8.mod",
    "%Integer8.negate"
);
signed_operators!(
    integer16,
    i16,
    "%Integer16.add",
    "%Integer16.subtract",
    "%Integer16.multiply",
    "%Integer16.div",
    "%Integer16.mod",
    "%Integer16.negate"
);
signed_operators!(
    integer32,
    i32,
    "%Integer32.add",
    "%Integer32.subtract",
    "%Integer32.multiply",
    "%Integer32.div",
    "%Integer32.mod",
    "%Integer32.negate"
);

/// 既存の関数の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    integer8::add::DECL,
    integer8::subtract::DECL,
    integer8::multiply::DECL,
    integer8::divide::DECL,
    integer8::modulo::DECL,
    integer8::negate::DECL,
    integer16::add::DECL,
    integer16::subtract::DECL,
    integer16::multiply::DECL,
    integer16::divide::DECL,
    integer16::modulo::DECL,
    integer16::negate::DECL,
    integer32::add::DECL,
    integer32::subtract::DECL,
    integer32::multiply::DECL,
    integer32::divide::DECL,
    integer32::modulo::DECL,
    integer32::negate::DECL,
];
