//! 診断で説明する束縛・比較の位置を最大8件に制限する。
//! 正常値・候補・停止の判定に使わず、解析予算の外で扱う
//! （設計書 02-05「警告」）。

use crate::base::{BytePos, FileId, Span};

const MAX_POSITIONS: usize = 8;

/// 値・整数の局所位置・候補がそれぞれ所有する固定長の由来。
/// 別名は参照時の列をコピーし、後の絞り込みを遡って反映しない。
/// 空の列は確保せず、非空の配列はヒープへ置いて再帰する解析の枠を増やさない。
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(in crate::typeck) struct Provenance(Option<Box<Positions>>);

#[derive(Clone, Debug, PartialEq, Eq)]
struct Positions {
    spans: [Span; MAX_POSITIONS],
    len: u8,
}

impl Default for Positions {
    fn default() -> Self {
        Self {
            // 有効な接頭辞だけを公開する。未使用の要素はソース上の位置を表さない。
            spans: [Span {
                file: FileId(0),
                start: BytePos(0),
                end: BytePos(0),
            }; MAX_POSITIONS],
            len: 0,
        }
    }
}

impl Provenance {
    /// 新しい束縛・比較を先頭にし、既存の位置を順に最大8件残す。
    pub fn with_position(&self, span: Span) -> Self {
        let mut positions = Positions::default();
        positions.push(span);
        positions.extend(self.as_slice());
        Self(Some(Box::new(positions)))
    }

    /// 左の列、右の列の順に合成し、同じ span は最初の出現だけを残す。
    pub fn combine(&self, right: &Self) -> Self {
        let Some(left) = self.0.as_deref() else {
            return right.clone();
        };
        if right.0.is_none() || self == right {
            return self.clone();
        }
        let mut positions = left.clone();
        positions.extend(right.as_slice());
        Self(Some(Box::new(positions)))
    }

    /// 補助位置は候補・診断へ同じ順序で渡す。
    pub fn as_slice(&self) -> &[Span] {
        self.0.as_deref().map_or(&[], Positions::as_slice)
    }
}

impl Positions {
    fn as_slice(&self) -> &[Span] {
        self.spans.get(..usize::from(self.len)).unwrap_or(&[])
    }

    fn extend(&mut self, spans: &[Span]) {
        for span in spans {
            if usize::from(self.len) == MAX_POSITIONS {
                break;
            }
            self.push(*span);
        }
    }

    fn push(&mut self, span: Span) {
        if !self.as_slice().contains(&span)
            && let Some(target) = self.spans.get_mut(usize::from(self.len))
        {
            *target = span;
            self.len = self.len.saturating_add(1);
        }
    }
}
