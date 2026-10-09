//! 呼び出しの回数の予算（設計書 02-08「タスクの切り替え」、ADR 0263 の決定 3）と、
//! 呼び出しの入れ子の上限の計数（02-08「呼び出しの入れ子の上限」、ADR 0030）。

use super::{FRAME_COST, REG_COST};

/// 遅い経路の終わりに、タスクを切り替えるか。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SlowPathEnd {
    /// 要求を処理しただけなので、同じタスクを続ける
    Continue,
    /// 予算を使い切ったので、実行中のタスクを待ち行列の末尾に移して切り替える
    Switch,
}

/// タスクごとの呼び出しの回数の予算。取り消しと回収の要求を知らせる手段も兼ねる。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Budget {
    remaining: u32,
    /// 要求で 0 にする前の残り（1 以上のときだけ持つ）
    saved: Option<u32>,
}

impl Budget {
    pub const fn new(initial: u32) -> Budget {
        Budget {
            remaining: initial,
            saved: None,
        }
    }

    /// 切り替えの位置の手順 2。予算が 0 でなければ一つ減らして `true`（速い経路）を返す。
    /// 0 なら減らさずに `false`（遅い経路に入る）を返す。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn tick(&mut self) -> bool {
        match self.remaining.checked_sub(1) {
            Some(rest) => {
                self.remaining = rest;
                true
            }
            None => false,
        }
    }

    /// 取り消しか回収の要求を知らせる。残りが 1 以上なら退避してから 0 にする。
    /// すでに退避した残りがあれば、それを保つ。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn interrupt(&mut self) {
        if self.remaining > 0 {
            self.saved = Some(self.remaining);
            self.remaining = 0;
        }
    }

    /// 遅い経路の手順 3.4。退避した残りがあれば、そこから 1 を引いた値を予算に戻して `Continue`、
    /// なければ予算を `initial` に戻して `Switch` を返す。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn finish_slow(&mut self, initial: u32) -> SlowPathEnd {
        match self.saved.take() {
            Some(rest) => {
                self.remaining = rest.saturating_sub(1);
                SlowPathEnd::Continue
            }
            None => {
                self.remaining = initial;
                SlowPathEnd::Switch
            }
        }
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn remaining(&self) -> u32 {
        self.remaining
    }
}

/// 呼び出しの入れ子の大きさの計数（実行全体で一つ）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct StackMeter {
    frames: u64,
    regs: u64,
    limit_bytes: u64,
}

impl StackMeter {
    pub fn new(limit_bytes: u64) -> StackMeter {
        StackMeter {
            frames: 0,
            regs: 0,
            limit_bytes,
        }
    }

    /// 枠を `frames` 個、レジスタを `regs` 個増やしても上限を超えないか。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn fits(&self, frames: u64, regs: u64) -> bool {
        let f = self.frames.checked_add(frames);
        let r = self.regs.checked_add(regs);
        match (f, r) {
            (Some(f), Some(r)) => Self::bytes_of(f, r).is_some_and(|b| b <= self.limit_bytes),
            _ => false,
        }
    }

    /// 増やす。`fits` で確かめてから呼ぶ。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn grow(&mut self, frames: u64, regs: u64) {
        self.frames = self.frames.saturating_add(frames);
        self.regs = self.regs.saturating_add(regs);
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn shrink(&mut self, frames: u64, regs: u64) {
        self.frames = self.frames.saturating_sub(frames);
        self.regs = self.regs.saturating_sub(regs);
    }

    /// 資源の不足の報告に使う枠の数。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn frames(&self) -> u64 {
        self.frames
    }

    pub fn bytes(&self) -> u64 {
        Self::bytes_of(self.frames, self.regs).unwrap_or(u64::MAX)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    fn bytes_of(frames: u64, regs: u64) -> Option<u64> {
        frames
            .checked_mul(FRAME_COST)?
            .checked_add(regs.checked_mul(REG_COST)?)
    }
}
