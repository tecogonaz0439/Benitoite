//! 六幅の正常値成分を必要なときだけ保持する
//! （設計書 02-05「区間解析の閉区間の領域」）。

use super::{IntKind, Interval};

#[cfg(test)]
mod tests;

/// Lean の BaseApprox.widths の有限な六成分。Top と全 Bottom は確保しない。
#[derive(Clone, Debug, Default)]
pub(super) enum Widths {
    #[default]
    Empty,
    Top,
    Known(Box<[Interval; 6]>),
}

impl Widths {
    /// 指定した一種類だけに正常値を置き、他の五成分を Bottom にする。
    pub fn single(kind: IntKind, range: Interval) -> Self {
        if range.is_bottom() {
            return Self::Empty;
        }
        let mut ranges = Box::new([Interval::bottom(); 6]);
        for (stored, slot) in IntKind::WIDTHS.into_iter().zip(ranges.iter_mut()) {
            if stored == kind {
                *slot = range;
            }
        }
        Self::Known(ranges)
    }

    /// 値の種類を取り違えず、要求された幅の成分を読む。
    pub fn range(&self, kind: IntKind) -> Interval {
        match self {
            Self::Empty => Interval::bottom(),
            Self::Top => Interval::top_kind(kind),
            Self::Known(ranges) => IntKind::WIDTHS
                .into_iter()
                .zip(ranges.iter())
                .find_map(|(stored, range)| (stored == kind).then_some(*range))
                .unwrap_or_else(Interval::bottom),
        }
    }

    /// 同じ種類どうしを凸に合流する。空の側と未知の側では配列を作らない。
    pub fn join(&mut self, other: &Self) {
        match (&mut *self, other) {
            (Self::Top, _) | (_, Self::Empty) => {}
            (_, Self::Top) => *self = Self::Top,
            (Self::Empty, _) => *self = other.clone(),
            (Self::Known(left), Self::Known(right)) => {
                for (left, right) in left.iter_mut().zip(right.iter()) {
                    *left = left.join(*right);
                }
            }
        }
    }
}
