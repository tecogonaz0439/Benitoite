//! 算術を持つ整数七種の正常値の閉区間
//! （設計書 02-05「区間解析の閉区間の領域」）。

use crate::types::builtin::BuiltinTypeId as B;
use crate::types::{Ty, TyCon};

/// 言語の算術を持つ整数の種類。解決済みの64ビットの別名を重ねて持たない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum IntKind {
    Integer8,
    Integer16,
    Integer32,
    Integer64,
    UnsignedInteger16,
    UnsignedInteger32,
    UnsignedInteger64,
}

impl IntKind {
    /// 診断の型名は既存の組み込み型の表示規則へ合わせる。
    pub fn builtin(self) -> B {
        match self {
            Self::Integer8 => B::INTEGER8,
            Self::Integer16 => B::INTEGER16,
            Self::Integer32 => B::INTEGER32,
            Self::Integer64 => B::INTEGER,
            Self::UnsignedInteger16 => B::UNSIGNED_INTEGER16,
            Self::UnsignedInteger32 => B::UNSIGNED_INTEGER32,
            Self::UnsignedInteger64 => B::UNSIGNED_INTEGER64,
        }
    }

    /// Integer64 とは別の正常値成分に保存する六幅。
    pub const WIDTHS: [Self; 6] = [
        Self::Integer8,
        Self::Integer16,
        Self::Integer32,
        Self::UnsignedInteger16,
        Self::UnsignedInteger32,
        Self::UnsignedInteger64,
    ];

    /// Byte と型引数を持つ型を除き、解決済みの型だけを認定する。
    pub fn of_type(ty: &Ty) -> Option<Self> {
        let Ty::Con(TyCon::Builtin(id), args) = ty else {
            return None;
        };
        if !args.is_empty() {
            return None;
        }
        Some(match *id {
            B::INTEGER8 => Self::Integer8,
            B::INTEGER16 => Self::Integer16,
            B::INTEGER32 => Self::Integer32,
            B::INTEGER => Self::Integer64,
            B::UNSIGNED_INTEGER16 => Self::UnsignedInteger16,
            B::UNSIGNED_INTEGER32 => Self::UnsignedInteger32,
            B::UNSIGNED_INTEGER64 => Self::UnsignedInteger64,
            _ => return None,
        })
    }

    /// 数学的な端点の比較に使う、ホスト幅に依存しない下限。
    pub const fn min(self) -> i128 {
        match self {
            Self::Integer8 => i8::MIN as i128,
            Self::Integer16 => i16::MIN as i128,
            Self::Integer32 => i32::MIN as i128,
            Self::Integer64 => Interval::MIN,
            Self::UnsignedInteger16 | Self::UnsignedInteger32 | Self::UnsignedInteger64 => 0,
        }
    }

    /// 最大 u64 も符号付きの i128 の端点に収まる。
    pub const fn max(self) -> i128 {
        match self {
            Self::Integer8 => i8::MAX as i128,
            Self::Integer16 => i16::MAX as i128,
            Self::Integer32 => i32::MAX as i128,
            Self::Integer64 => Interval::MAX,
            Self::UnsignedInteger16 => u16::MAX as i128,
            Self::UnsignedInteger32 => u32::MAX as i128,
            Self::UnsignedInteger64 => u64::MAX as i128,
        }
    }
}

/// 空集合（Bottom）、または呼び出し側が指定した整数の値域内の非空の閉区間。
/// Top は全値域の閉区間であり、失敗可能性はこの型に含めない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) struct Interval {
    // 外から不正な端点を作れないようにし、正規化を構築の入口にする。
    bounds: Option<(i128, i128)>,
}

impl Interval {
    /// Integer64 の最小値。言語の幅とは別に、中間の比較に i128 を使う。
    pub const MIN: i128 = i64::MIN as i128;
    /// Integer64 の最大値。
    pub const MAX: i128 = i64::MAX as i128;

    /// 正常値を持たない空集合。
    pub const fn bottom() -> Self {
        Self { bounds: None }
    }

    /// 未知の正常値を表す Integer64 の全値域。
    pub const fn top() -> Self {
        Self::top_kind(IntKind::Integer64)
    }

    /// 指定した整数型の全値域。種類は近似の成分と局所位置が保持する。
    pub const fn top_kind(kind: IntKind) -> Self {
        Self {
            bounds: Some((kind.min(), kind.max())),
        }
    }

    /// 入力の閉区間を Integer64 の値域と交差し、空なら Bottom にする。
    pub fn normalize(lo: i128, hi: i128) -> Self {
        Self::normalize_kind(IntKind::Integer64, lo, hi)
    }

    /// 指定した整数型の値域と交差する。値域外のリテラルの認定には使わない。
    pub fn normalize_kind(kind: IntKind, lo: i128, hi: i128) -> Self {
        let lo = lo.max(kind.min());
        let hi = hi.min(kind.max());
        Self {
            bounds: (lo <= hi).then_some((lo, hi)),
        }
    }

    /// 非空なら両端を返す。Top も有限の端点を持つ。
    pub fn bounds(self) -> Option<(i128, i128)> {
        self.bounds
    }

    /// 正常値を持たないかどうか。
    pub fn is_bottom(self) -> bool {
        self.bounds.is_none()
    }

    /// 両方の正常値の集合の交差。
    pub fn meet(self, other: Self) -> Self {
        match (self.bounds, other.bounds) {
            (Some((lo, hi)), Some((other_lo, other_hi))) => {
                let bounds = (lo.max(other_lo), hi.min(other_hi));
                Self {
                    bounds: (bounds.0 <= bounds.1).then_some(bounds),
                }
            }
            (None, _) | (_, None) => Self::bottom(),
        }
    }

    /// 両方を包含する最小の閉区間。離れた区間の間の穴は失う。
    pub fn join(self, other: Self) -> Self {
        match (self.bounds, other.bounds) {
            (None, _) => other,
            (_, None) => self,
            (Some((lo, hi)), Some((other_lo, other_hi))) => {
                // 同じ種類の成分どうしなので、凸包も構築時の型域内にある。
                Self {
                    bounds: Some((lo.min(other_lo), hi.max(other_hi))),
                }
            }
        }
    }
}
