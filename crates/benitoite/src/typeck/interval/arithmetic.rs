//! 整数の種類を保った加減算・定数倍・負号・整数除算・剰余の正常区間と失敗候補
//! （設計書 02-05「区間解析のInteger64算術」）。

use super::domain::{IntKind, Interval};
use super::identity::Origin;
use super::origins::Provenance;
use crate::base::Span;
use crate::syntax::ast::BinOp;
use std::fmt;

/// 型域との交差前の端点。最大 u64 の二乗も診断まで正確に保つ。
pub(super) enum ResultBounds {
    Signed(i128, i128),
    Unsigned(u128, u128),
}

impl fmt::Display for ResultBounds {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Signed(lo, hi) => write!(f, "[{lo},{hi}]"),
            Self::Unsigned(lo, hi) => write!(f, "[{lo},{hi}]"),
        }
    }
}

/// 正常な二引数を得た位置での拒否原因。may_fail からは生成しない。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub(in crate::typeck) enum Cause {
    Overflow,
    ZeroDivisor,
    OutsideDomain,
}

/// 候補の元の演算。単項の負号を二項の減算と区別する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum TargetOperation {
    Binary(BinOp),
    Neg,
    Standard {
        declaration: crate::base::BindingId,
        contract: &'static super::fixed_domain::Contract,
    },
}

impl TargetOperation {
    /// 型域との交差前の結果区間。診断も解析と同じ端点の順序で示す。
    pub(super) fn result_bounds(
        self,
        kind: IntKind,
        left: Interval,
        right: Interval,
    ) -> Option<ResultBounds> {
        match self {
            Self::Standard { .. } => None,
            Self::Binary(op) => Operation::from_binary(op)?.result_bounds(kind, left, right),
            Self::Neg => {
                let (lo, hi) = left.bounds()?;
                Some(ResultBounds::Signed(
                    hi.saturating_neg(),
                    lo.saturating_neg(),
                ))
            }
        }
    }
}

/// 条件付きの失敗候補。本体名は所有する本体の報告から得る。
#[derive(Debug)]
pub(in crate::typeck) struct Candidate {
    pub preorder: u64,
    pub origin: Origin,
    pub primary: Span,
    pub operation: TargetOperation,
    pub cause: Cause,
    pub kind: IntKind,
    pub left: Interval,
    pub right: Interval,
    pub origins: Provenance,
}

/// 型検査済みの二項演算のうち、正常区間を合成する演算。
#[derive(Clone, Copy)]
pub(super) enum Operation {
    Add,
    Sub,
    Mul,
    IntDiv,
    Mod,
}

impl Operation {
    /// 二項演算子を、対応する算術の種類へ分類する。
    pub fn from_binary(op: BinOp) -> Option<Self> {
        match op {
            BinOp::Add => Some(Self::Add),
            BinOp::Sub => Some(Self::Sub),
            BinOp::Mul => Some(Self::Mul),
            BinOp::IntDiv => Some(Self::IntDiv),
            BinOp::Mod => Some(Self::Mod),
            BinOp::Div
            | BinOp::Eq
            | BinOp::Ne
            | BinOp::Lt
            | BinOp::Le
            | BinOp::Gt
            | BinOp::Ge
            | BinOp::And
            | BinOp::Or => None,
        }
    }

    fn result_bounds(self, kind: IntKind, left: Interval, right: Interval) -> Option<ResultBounds> {
        let ((lo, hi), (other_lo, other_hi)) = (left.bounds()?, right.bounds()?);
        // 全端点の和・差と、UnsignedInteger64 以外の積は i128 に収まる。
        match self {
            Self::Add => Some(ResultBounds::Signed(
                lo.saturating_add(other_lo),
                hi.saturating_add(other_hi),
            )),
            Self::Sub => Some(ResultBounds::Signed(
                lo.saturating_sub(other_hi),
                hi.saturating_sub(other_lo),
            )),
            Self::Mul => {
                // Lean の mulBounds と同じく、両辺一点なら左を定数にする。
                let (constant, low, high) = if lo == hi {
                    (lo, other_lo, other_hi)
                } else if other_lo == other_hi {
                    (other_lo, lo, hi)
                } else {
                    return None;
                };
                if kind == IntKind::UnsignedInteger64 {
                    // 端点は対象型の値域内なので各値は u64 に収まる。最大値同士の
                    // 積も u128 に収まり、型域と比べる前に i128 へ戻さない
                    // （設計書 02-05「区間解析のInteger64算術」）。
                    let constant = u128::from(u64::try_from(constant).ok()?);
                    let low = u128::from(u64::try_from(low).ok()?);
                    let high = u128::from(u64::try_from(high).ok()?);
                    return Some(ResultBounds::Unsigned(
                        constant.saturating_mul(low),
                        constant.saturating_mul(high),
                    ));
                }
                let (low, high) = if constant < 0 {
                    (high, low)
                } else {
                    (low, high)
                };
                Some(ResultBounds::Signed(
                    constant.saturating_mul(low),
                    constant.saturating_mul(high),
                ))
            }
            Self::IntDiv | Self::Mod => None,
        }
    }

    /// 子の失敗は呼び出し側が左から合成し、ここでは演算自身だけを判定する。
    pub fn evaluate(self, kind: IntKind, left: Interval, right: Interval) -> Evaluation {
        let (Some(_), Some((other_lo, other_hi))) = (left.bounds(), right.bounds()) else {
            return Evaluation {
                normal: Interval::bottom(),
                may_fail: false,
                cause: None,
            };
        };
        match self {
            Self::Add | Self::Sub | Self::Mul => match self.result_bounds(kind, left, right) {
                Some(bounds) => Evaluation::bounded(kind, bounds),
                // 両辺が複数値の積は、親で解析しても結果は Top に保つ。
                None => Evaluation {
                    normal: Interval::top_kind(kind),
                    may_fail: true,
                    cause: None,
                },
            },
            Self::IntDiv | Self::Mod => Evaluation {
                normal: Interval::top_kind(kind),
                may_fail: true,
                cause: (other_lo == 0 && other_hi == 0).then_some(Cause::ZeroDivisor),
            },
        }
    }
}

/// 正常値と失敗可能性、条件付きで確実な拒否原因を分離する。
pub(super) struct Evaluation {
    pub normal: Interval,
    pub may_fail: bool,
    pub cause: Option<Cause>,
}

impl Evaluation {
    fn bounded(kind: IntKind, bounds: ResultBounds) -> Self {
        match bounds {
            ResultBounds::Signed(low, high) => Self {
                normal: Interval::normalize_kind(kind, low, high),
                may_fail: low < kind.min() || kind.max() < high,
                cause: (high < kind.min() || kind.max() < low).then_some(Cause::Overflow),
            },
            ResultBounds::Unsigned(low, high) => {
                let max = u128::from(u64::MAX);
                Self {
                    normal: if low > max {
                        Interval::bottom()
                    } else {
                        // 比較と切り詰めの後は両端点が u64 の値域内である。
                        Interval::normalize_kind(kind, low as i128, high.min(max) as i128)
                    },
                    may_fail: high > max,
                    cause: (low > max).then_some(Cause::Overflow),
                }
            }
        }
    }
}

/// 負号は端点を反転し、子に正常値がなければ親の候補を作らない。
pub(super) fn negate(kind: IntKind, child: Interval) -> Evaluation {
    match TargetOperation::Neg.result_bounds(kind, child, Interval::bottom()) {
        Some(bounds) => Evaluation::bounded(kind, bounds),
        None => Evaluation {
            normal: Interval::bottom(),
            may_fail: false,
            cause: None,
        },
    }
}
