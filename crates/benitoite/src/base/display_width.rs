//! 表示の幅と、不足する U+0020 の個数・出力サイズの計算（設計書 03-06「String」）。
//! 確保と実行時の予算検査は呼び出し側で行い、言語の値や実行器に依存しない。

use unicode_width::UnicodeWidthStr;

/// 表示の幅に用いる Unicode の版。Character の分類の版とは独立している。
pub const UNICODE_VERSION: (u8, u8, u8) = unicode_width::UNICODE_VERSION;

/// 固定した文字列の幅の算法の選択。環境や端末の状態を参照しない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WidthMode {
    /// 曖昧な幅の文字を原則 1 とする通常の算法。
    Default,
    /// 文字列の例外も含む `unicode-width` の CJK の算法。
    Cjk,
}

/// 空白を片側に加えるための個数と、確保前に検査する出力のバイト数。
/// `spaces == 0` なら呼び出し側は元の値をそのまま返せる。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SpacePadding {
    /// 先頭または末尾へ加える U+0020 の個数。
    pub spaces: u64,
    /// 元の UTF-8 バイト数と空白の個数の和。
    pub byte_len: u64,
}

/// 制御文字を幅 0 の境界とし、境界間の文字列全体の幅を checked に合計する。
/// 整数の変換または集計であふれた場合は `None` を返す。
pub fn width(s: &str, mode: WidthMode) -> Option<u64> {
    s.split(is_boundary).try_fold(0_u64, |total, part| {
        let part_width = match mode {
            WidthMode::Default => UnicodeWidthStr::width(part),
            WidthMode::Cjk => UnicodeWidthStr::width_cjk(part),
        };
        total.checked_add(u64::try_from(part_width).ok()?)
    })
}

/// 目標の幅に不足する空白の個数と出力サイズを、確保せずに計算する。
/// 目標が 0 以下または現在の幅以下なら空白は 0 個。計算のあふれは `None`。
/// 呼び出し側は論理上限・予算を検査した後に `usize` へ検査付きで変換する。
pub fn space_padding(s: &str, target: i64, mode: WidthMode) -> Option<SpacePadding> {
    let byte_len = u64::try_from(s.len()).ok()?;
    let spaces = if target <= 0 {
        0
    } else {
        let target = u64::try_from(target).ok()?;
        let current = width(s, mode)?;
        if target > current {
            target.checked_sub(current)?
        } else {
            0
        }
    };
    Some(SpacePadding {
        spaces,
        byte_len: byte_len.checked_add(spaces)?,
    })
}

fn is_boundary(c: char) -> bool {
    matches!(c, '\u{0000}'..='\u{001f}' | '\u{007f}'..='\u{009f}' | '\u{2028}' | '\u{2029}')
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::arithmetic_side_effects)] // テストの失敗は panic で表す（AGENTS.md「#[allow] を書いてよい箇所」）。
mod tests {
    use super::{SpacePadding, WidthMode, space_padding, width};

    // 期待値は固定版の規則から独立に定める（設計書 03-06「String」）。
    // 幅 3 の例も置き、スカラー値や書記素の個数の和への置換を捕まえる。
    const CASES: &[(&str, u64, u64)] = &[
        ("", 0, 0),
        ("abc", 3, 3),
        ("猫", 2, 2),
        ("ｶﾅ", 2, 2),
        ("e\u{301}", 1, 1),
        ("\u{301}", 0, 0),
        ("\u{301}a", 1, 1),
        ("\u{200d}", 0, 0),
        ("\u{fe0f}", 0, 0),
        ("a\u{200d}", 1, 1),
        ("👩\u{200d}", 2, 2),
        ("👩‍👩‍👧‍👦", 2, 2),
        ("👍🏽", 2, 2),
        ("🇯🇵", 2, 2),
        ("1\u{fe0f}\u{20e3}", 2, 2),
        ("❤\u{fe0f}", 2, 2),
        ("⌚\u{fe0e}", 1, 2),
        ("·", 1, 2),
        ("=\u{338}", 1, 2),
        ("لا", 1, 1),
        ("\u{17d8}", 3, 3),
        ("\u{1faea}", 2, 2), // Unicode 17.0 の distorted face。
        ("\r\n", 0, 0),
        ("a\nb\tc", 3, 3),
        ("\u{1b}[31m", 4, 4),
        ("ل\0ا", 2, 2),
        ("👩\u{200d}\n👩", 4, 4),
    ];

    #[test]
    fn fixed_widths_and_spaces_at_both_ends() {
        for &(s, default, cjk) in CASES {
            for (mode, expected) in [(WidthMode::Default, default), (WidthMode::Cjk, cjk)] {
                for before in 0..=3_usize {
                    for after in 0..=3_usize {
                        let padded = format!("{}{s}{}", " ".repeat(before), " ".repeat(after));
                        let expected = expected
                            + u64::try_from(before).unwrap()
                            + u64::try_from(after).unwrap();
                        assert_eq!(width(&padded, mode), Some(expected), "{padded:?} {mode:?}");
                    }
                }
            }
        }
    }

    #[test]
    fn every_control_boundary_separates_ligatures() {
        let boundaries = (0..=0x1f).chain(0x7f..=0x9f).chain([0x2028, 0x2029]);
        for c in boundaries.map(|n| char::from_u32(n).unwrap()) {
            for mode in [WidthMode::Default, WidthMode::Cjk] {
                let s = format!("ل{c}ا");
                assert_eq!(width(&s, mode), Some(2), "{s:?} {mode:?}");
                assert_eq!(width(&format!(" {s}  "), mode), Some(5));
            }
        }
        for c in ['\u{20}', '\u{a0}'] {
            assert_eq!(width(&c.to_string(), WidthMode::Default), Some(1));
        }
    }

    #[test]
    fn general_concatenation_is_not_additive() {
        for mode in [WidthMode::Default, WidthMode::Cjk] {
            assert_eq!(width("ل", mode), Some(1));
            assert_eq!(width("ا", mode), Some(1));
            assert_eq!(width("لا", mode), Some(1));
            assert_eq!(width("👩\u{200d}", mode), Some(2));
            assert_eq!(width("👩", mode), Some(2));
            assert_eq!(width("👩‍👩", mode), Some(2));
        }
    }

    #[test]
    fn padding_counts_spaces_and_output_bytes() {
        let cases = [
            ("", 0, 0, 0, 0, 0),
            ("", 3, 3, 3, 3, 3),
            ("猫", i64::MIN, 0, 3, 0, 3),
            ("猫", -1, 0, 3, 0, 3),
            ("猫", 0, 0, 3, 0, 3),
            ("猫", 1, 0, 3, 0, 3),
            ("猫", 2, 0, 3, 0, 3),
            ("猫", 7, 5, 8, 5, 8),
            ("猫", 65535, 65533, 65536, 65533, 65536),
            ("·", 2, 1, 3, 0, 2),
            ("e\u{301}", 3, 2, 5, 2, 5),
            ("\u{301}", 1, 1, 3, 1, 3),
            ("a\nb", 4, 2, 5, 2, 5),
        ];
        for (s, target, default_spaces, default_bytes, cjk_spaces, cjk_bytes) in cases {
            for (mode, spaces, byte_len) in [
                (WidthMode::Default, default_spaces, default_bytes),
                (WidthMode::Cjk, cjk_spaces, cjk_bytes),
            ] {
                assert_eq!(
                    space_padding(s, target, mode),
                    Some(SpacePadding { spaces, byte_len }),
                    "{s:?} {target} {mode:?}"
                );
            }
        }
        // 表示の幅と UTF-8 バイト数を混同せず、32 bit の usize へ先に縮めない。
        for mode in [WidthMode::Default, WidthMode::Cjk] {
            assert_eq!(
                space_padding("猫", i64::MAX, mode),
                Some(SpacePadding {
                    spaces: 9_223_372_036_854_775_805,
                    byte_len: 9_223_372_036_854_775_808,
                })
            );
        }
    }
}
