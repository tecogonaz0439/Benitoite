//! `Decimal` の値の表現と算術（設計書 01-04「Decimal（初回リリース版）」、ADR 0114）。
//! 算術はクレートを使わずにこのファイルの中で行う（ADR 0275、実装プラン 10-05「`Decimal` の算術」）。

/// 小数の桁数の上限（01-04）。
pub const MAX_SCALE: u8 = 28;

/// 仮数の絶対値の上限（2^96 − 1。01-04）。
pub const MAX_MANTISSA: i128 = (1_i128 << 96) - 1;

/// `mantissa / 10^scale` の形の 10 進の数。|mantissa| ≤ MAX_MANTISSA、scale ≤ MAX_SCALE を保つ。
/// 数の等しさと表現の等しさが違うので、`PartialEq` を導出しない（`cmp_num`・`same_repr` を使う）。
#[derive(Clone, Copy, Debug)]
pub struct Decimal {
    mantissa: i128,
    scale: u8,
}

/// 丸め方。prelude の型 `RoundingMode` の構成子と一対一に対応する（01-04「Decimal（初回リリース版）」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DecimalRounding {
    HalfToEven,
    HalfAwayFromZero,
    TowardZero,
    TowardNegativeInfinity,
    TowardPositiveInfinity,
}

/// 算術の失敗。どれも言語の実行時エラーの条件（01-04）であり、呼び出し側が `Stop` か型検査の誤りにする。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DecimalError {
    /// 丸めても仮数が範囲に収まらない
    Overflow,
    /// 0 による除算
    DivisionByZero,
    /// `Decimal.round` の桁数が 0 以上 28 以下でない
    InvalidPlaces,
}

impl Decimal {
    /// 0（仮数 0、小数の桁数 0）。
    pub const ZERO: Decimal = Decimal {
        mantissa: 0,
        scale: 0,
    };

    /// 仮数と小数の桁数から作る。範囲の外なら `None`。
    pub fn new(mantissa: i128, scale: u8) -> Option<Decimal> {
        if scale > MAX_SCALE || !(-MAX_MANTISSA..=MAX_MANTISSA).contains(&mantissa) {
            return None;
        }
        Some(Decimal { mantissa, scale })
    }

    pub fn mantissa(self) -> i128 {
        self.mantissa
    }

    pub fn scale(self) -> u8 {
        self.scale
    }

    /// 仮数と小数の桁数がともに等しいか（表現の比較）。数の比較には `cmp_num` を使う。
    pub fn same_repr(self, other: Decimal) -> bool {
        self.mantissa == other.mantissa && self.scale == other.scale
    }
}

use std::cmp::Ordering;

impl Decimal {
    /// リテラルの字面から作る。`digits` は `_` と接尾辞 `m` を除いた 10 進の字面（`"1000.50"`、`"12"`）。
    /// 小数点の後の桁の数が小数の桁数になる。小数点の後が 29 桁以上か、値が範囲を超えれば `None`
    /// （型検査の誤りにする。丸めない。01-04）。符号は含まない。
    pub fn parse_literal(digits: &str) -> Option<Decimal> {
        let (whole, fraction) = digits.split_once('.').unwrap_or((digits, ""));
        if whole.is_empty() || (digits.contains('.') && fraction.is_empty()) {
            return None;
        }
        let scale = u8::try_from(fraction.len()).ok()?;
        let mut mantissa = 0_i128;
        for c in whole.chars().chain(fraction.chars()) {
            if !c.is_ascii_digit() {
                return None;
            }
            mantissa = mantissa
                .checked_mul(10)?
                .checked_add(i128::from(c.to_digit(10)?))?;
        }
        Decimal::new(mantissa, scale)
    }
    /// 整数から作る。小数の桁数は 0。
    pub fn from_integer(value: i64) -> Decimal {
        Decimal {
            mantissa: i128::from(value),
            scale: 0,
        }
    }
    pub fn checked_add(self, other: Decimal) -> Result<Decimal, DecimalError> {
        self.add_signed(other, false)
    }
    pub fn checked_sub(self, other: Decimal) -> Result<Decimal, DecimalError> {
        self.add_signed(other, true)
    }
    pub fn checked_mul(self, other: Decimal) -> Result<Decimal, DecimalError> {
        let magnitude = Wide::from(self.mantissa.unsigned_abs())
            .mul(Wide::from(other.mantissa.unsigned_abs()))
            .ok_or(DecimalError::Overflow)?;
        fit(
            magnitude,
            u32::from(self.scale).saturating_add(u32::from(other.scale)),
            (self.mantissa < 0) != (other.mantissa < 0),
        )
    }
    pub fn checked_div(self, other: Decimal) -> Result<Decimal, DecimalError> {
        if other.mantissa == 0 {
            return Err(DecimalError::DivisionByZero);
        }
        let negative = (self.mantissa < 0) != (other.mantissa < 0);
        let mut numerator = Wide::from(self.mantissa.unsigned_abs());
        let mut denominator = Wide::from(other.mantissa.unsigned_abs());
        if other.scale >= self.scale {
            numerator = numerator
                .times_ten(u32::from(other.scale.saturating_sub(self.scale)))
                .ok_or(DecimalError::Overflow)?;
        } else {
            denominator = denominator
                .times_ten(u32::from(self.scale.saturating_sub(other.scale)))
                .ok_or(DecimalError::Overflow)?;
        }
        let (mut quotient, mut remainder) = numerator
            .div_rem(denominator)
            .ok_or(DecimalError::DivisionByZero)?;
        let minimum = self.scale.saturating_sub(other.scale);
        let mut rounded = None;
        // 余りから一桁ずつ求める。仮数に収まる候補だけを保持し、282 bit になりうる
        // 分子の一括の拡大を避ける（設計書 01-04「Decimal（初回リリース版）」）。
        for scale in 0..=MAX_SCALE {
            if quotient > Wide::LIMIT {
                break;
            }
            if remainder == Wide::ZERO && scale >= minimum {
                return make(quotient, scale, negative);
            }
            if let Some(candidate) = round_magnitude(
                quotient,
                remainder,
                denominator,
                negative,
                DecimalRounding::HalfToEven,
            ) && candidate <= Wide::LIMIT
            {
                rounded = Some(make(candidate, scale, negative)?);
            }
            let expanded = remainder.times_ten(1).ok_or(DecimalError::Overflow)?;
            let (digit, rest) = expanded
                .div_rem(denominator)
                .ok_or(DecimalError::DivisionByZero)?;
            quotient = quotient
                .times_ten(1)
                .and_then(|q| q.add(digit))
                .ok_or(DecimalError::Overflow)?;
            remainder = rest;
        }
        rounded.ok_or(DecimalError::Overflow)
    }
    /// 符号を反転する。仮数が 0 の値は符号を持たない（`-0.0m` は `0.0m`）。
    pub fn negate(self) -> Decimal {
        Decimal {
            mantissa: self.mantissa.checked_neg().unwrap_or(0),
            scale: self.scale,
        }
    }
    /// 絶対値。小数の桁数は変えない。
    pub fn abs(self) -> Decimal {
        if self.mantissa < 0 {
            self.negate()
        } else {
            self
        }
    }
    /// 数の大小で比べる。小数の桁数は比べない（`1.0m` と `1.00m` は `Equal`）。
    pub fn cmp_num(self, other: Decimal) -> Ordering {
        if (self.mantissa < 0) != (other.mantissa < 0) {
            return self.mantissa.cmp(&other.mantissa);
        }
        let scale = self.scale.max(other.scale);
        // 有効な Decimal の整列は 190 bit 未満であり、Wide の範囲に収まる。
        let a = Wide::from(self.mantissa.unsigned_abs())
            .times_ten(u32::from(scale.saturating_sub(self.scale)))
            .unwrap_or(Wide::ZERO);
        let b = Wide::from(other.mantissa.unsigned_abs())
            .times_ten(u32::from(scale.saturating_sub(other.scale)))
            .unwrap_or(Wide::ZERO);
        if self.mantissa < 0 {
            b.cmp(&a)
        } else {
            a.cmp(&b)
        }
    }
    /// 小数の桁数 `places` に丸める（`Decimal.round`）。桁が足りなければ末尾に 0 を補う。
    pub fn round(self, places: i64, mode: DecimalRounding) -> Result<Decimal, DecimalError> {
        let places = u8::try_from(places)
            .ok()
            .filter(|p| *p <= MAX_SCALE)
            .ok_or(DecimalError::InvalidPlaces)?;
        let magnitude = Wide::from(self.mantissa.unsigned_abs());
        if places >= self.scale {
            let expanded = magnitude
                .times_ten(u32::from(places.saturating_sub(self.scale)))
                .ok_or(DecimalError::Overflow)?;
            return make(expanded, places, self.mantissa < 0);
        }
        let divisor = Wide::ONE
            .times_ten(u32::from(self.scale.saturating_sub(places)))
            .ok_or(DecimalError::Overflow)?;
        let (quotient, remainder) = magnitude.div_rem(divisor).ok_or(DecimalError::Overflow)?;
        let rounded = round_magnitude(quotient, remainder, divisor, self.mantissa < 0, mode)
            .ok_or(DecimalError::Overflow)?;
        make(rounded, places, self.mantissa < 0)
    }
    /// 小数の桁数どおりに書いた文字列（`1.00m` は `"1.00"`、`-0.5m` は `"-0.5"`）。
    /// `Decimal.toString` と文字列補間が使う。
    pub fn to_text(self) -> String {
        let digits = self.mantissa.unsigned_abs().to_string();
        let scale = usize::from(self.scale);
        let mut out = String::new();
        if self.mantissa < 0 {
            out.push('-');
        }
        if scale == 0 {
            out.push_str(&digits);
        } else if digits.len() <= scale {
            out.push_str("0.");
            for _ in digits.len()..scale {
                out.push('0');
            }
            out.push_str(&digits);
        } else {
            let split = digits.len().saturating_sub(scale);
            for (i, c) in digits.chars().enumerate() {
                if i == split {
                    out.push('.');
                }
                out.push(c);
            }
        }
        out
    }
}

impl Decimal {
    fn add_signed(self, other: Decimal, subtract: bool) -> Result<Decimal, DecimalError> {
        let scale = self.scale.max(other.scale);
        let a = Wide::from(self.mantissa.unsigned_abs())
            .times_ten(u32::from(scale.saturating_sub(self.scale)))
            .ok_or(DecimalError::Overflow)?;
        let b = Wide::from(other.mantissa.unsigned_abs())
            .times_ten(u32::from(scale.saturating_sub(other.scale)))
            .ok_or(DecimalError::Overflow)?;
        let a_negative = self.mantissa < 0;
        let b_negative = (other.mantissa < 0) != subtract;
        let (magnitude, negative) = if a_negative == b_negative {
            (a.add(b).ok_or(DecimalError::Overflow)?, a_negative)
        } else if a >= b {
            (a.sub(b).ok_or(DecimalError::Overflow)?, a_negative)
        } else {
            (b.sub(a).ok_or(DecimalError::Overflow)?, b_negative)
        };
        fit(magnitude, u32::from(scale), negative)
    }
}

// 算術の中間値だけに使う符号なし 256 bit。公開の Decimal の不変条件は make で検査する
// （設計書 01-04「Decimal（初回リリース版）」、実装プラン 10-05「Decimal の算術」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
struct Wide {
    hi: u128,
    lo: u128,
}

impl From<u128> for Wide {
    fn from(lo: u128) -> Self {
        Wide { hi: 0, lo }
    }
}

impl Wide {
    const ZERO: Self = Self { hi: 0, lo: 0 };
    const ONE: Self = Self { hi: 0, lo: 1 };
    const LIMIT: Self = Self {
        hi: 0,
        lo: (1_u128 << 96) - 1,
    };

    fn add(self, other: Self) -> Option<Self> {
        let (lo, carry) = self.lo.overflowing_add(other.lo);
        let hi = self
            .hi
            .checked_add(other.hi)?
            .checked_add(u128::from(carry))?;
        Some(Self { hi, lo })
    }
    fn sub(self, other: Self) -> Option<Self> {
        let (lo, borrow) = self.lo.overflowing_sub(other.lo);
        let hi = self
            .hi
            .checked_sub(other.hi)?
            .checked_sub(u128::from(borrow))?;
        Some(Self { hi, lo })
    }
    fn shift(self) -> Option<Self> {
        if self.hi >> 127 != 0 {
            return None;
        }
        Some(Self {
            hi: (self.hi << 1) | (self.lo >> 127),
            lo: self.lo << 1,
        })
    }
    fn mul(self, other: Self) -> Option<Self> {
        let mut result = Self::ZERO;
        let mut factor = self;
        let mut bits = other;
        while bits != Self::ZERO {
            if bits.lo & 1 != 0 {
                result = result.add(factor)?;
            }
            bits = Self {
                hi: bits.hi >> 1,
                lo: (bits.lo >> 1) | (bits.hi << 127),
            };
            if bits != Self::ZERO {
                factor = factor.shift()?;
            }
        }
        Some(result)
    }
    fn times_ten(mut self, places: u32) -> Option<Self> {
        for _ in 0..places {
            self = self.mul(Self::from(10))?;
        }
        Some(self)
    }
    fn div_rem(self, divisor: Self) -> Option<(Self, Self)> {
        if divisor == Self::ZERO {
            return None;
        }
        let mut quotient = Self::ZERO;
        let mut remainder = Self::ZERO;
        // 各桁で余りを倍にする前の最上位の桁を分離する。割る数が 256 bit でも
        // 一時的な 257 bit の余りを切り捨てない（設計書 01-04 の溢れの規則）。
        for bit in (0..256_u32).rev() {
            let high = remainder.hi >> 127 != 0;
            remainder = Self {
                hi: (remainder.hi << 1) | (remainder.lo >> 127),
                lo: remainder.lo << 1,
            };
            let digit = if bit >= 128 {
                (self.hi >> bit.saturating_sub(128)) & 1
            } else {
                (self.lo >> bit) & 1
            };
            remainder.lo |= digit;
            if high || remainder >= divisor {
                let (lo, borrow) = remainder.lo.overflowing_sub(divisor.lo);
                let hi = remainder
                    .hi
                    .wrapping_sub(divisor.hi)
                    .wrapping_sub(u128::from(borrow));
                remainder = Self { hi, lo };
                if bit >= 128 {
                    quotient.hi |= 1_u128 << bit.saturating_sub(128);
                } else {
                    quotient.lo |= 1_u128 << bit;
                }
            }
        }
        Some((quotient, remainder))
    }
}

fn make(magnitude: Wide, scale: u8, negative: bool) -> Result<Decimal, DecimalError> {
    if magnitude > Wide::LIMIT {
        return Err(DecimalError::Overflow);
    }
    let mantissa = i128::try_from(magnitude.lo).map_err(|_| DecimalError::Overflow)?;
    let mantissa = if negative {
        mantissa.checked_neg().ok_or(DecimalError::Overflow)?
    } else {
        mantissa
    };
    Decimal::new(mantissa, scale).ok_or(DecimalError::Overflow)
}

fn round_magnitude(
    quotient: Wide,
    remainder: Wide,
    divisor: Wide,
    negative: bool,
    mode: DecimalRounding,
) -> Option<Wide> {
    if remainder == Wide::ZERO {
        return Some(quotient);
    }
    let half = remainder.cmp(&divisor.sub(remainder)?);
    let increment = match mode {
        DecimalRounding::HalfToEven => {
            half == Ordering::Greater || (half == Ordering::Equal && quotient.lo & 1 != 0)
        }
        DecimalRounding::HalfAwayFromZero => half != Ordering::Less,
        DecimalRounding::TowardZero => false,
        DecimalRounding::TowardNegativeInfinity => negative,
        DecimalRounding::TowardPositiveInfinity => !negative,
    };
    if increment {
        quotient.add(Wide::ONE)
    } else {
        Some(quotient)
    }
}

fn fit(magnitude: Wide, original_scale: u32, negative: bool) -> Result<Decimal, DecimalError> {
    // 候補ごとに元の値から丸め直し、二重丸めを避ける（設計書 01-04）。
    for scale in (0..=original_scale.min(u32::from(MAX_SCALE))).rev() {
        let divisor = Wide::ONE
            .times_ten(original_scale.saturating_sub(scale))
            .ok_or(DecimalError::Overflow)?;
        let (quotient, remainder) = magnitude.div_rem(divisor).ok_or(DecimalError::Overflow)?;
        let rounded = round_magnitude(
            quotient,
            remainder,
            divisor,
            negative,
            DecimalRounding::HalfToEven,
        )
        .ok_or(DecimalError::Overflow)?;
        if rounded <= Wide::LIMIT {
            return make(
                rounded,
                u8::try_from(scale).map_err(|_| DecimalError::Overflow)?,
                negative,
            );
        }
    }
    Err(DecimalError::Overflow)
}

#[cfg(test)]
// テストの失敗を panic で表し、数値の仕様の期待値を直接記す（実装プラン F07）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::{Decimal as D, DecimalError as E, DecimalRounding as R, MAX_MANTISSA};
    fn d(s: &str) -> D {
        D::parse_literal(s).unwrap()
    }
    #[test]
    fn scale_preservation_division_and_representation() {
        for (a, b, result) in [
            ("1.00", "4", "0.25"),
            ("6.0", "2", "3.0"),
            ("6", "2.0", "3"),
            ("1", "3", "0.3333333333333333333333333333"),
            ("1", "6", "0.1666666666666666666666666667"),
            (
                "0.0000000000000000000000000001",
                "2",
                "0.0000000000000000000000000000",
            ),
        ] {
            assert!(
                d(a).checked_div(d(b)).unwrap().same_repr(d(result)),
                "{a} / {b}"
            );
        }
        assert!(
            d("1.0")
                .checked_add(d("2.00"))
                .unwrap()
                .same_repr(d("3.00"))
        );
        assert!(
            d("1.0")
                .checked_sub(d("2.00"))
                .unwrap()
                .same_repr(d("1.00").negate())
        );
        assert!(
            d("1.20")
                .checked_mul(d("2.0"))
                .unwrap()
                .same_repr(d("2.400"))
        );
        assert_eq!(d("1.0").cmp_num(d("1.00")), std::cmp::Ordering::Equal);
        assert!(!d("1.0").same_repr(d("1.00")));
        assert_eq!(d("0.0").negate().to_text(), "0.0");
        assert_eq!(d("0.05").negate().to_text(), "-0.05");
        assert_eq!(d("0.05").negate().abs().to_text(), "0.05");
    }
    #[test]
    fn rounding_modes_and_mantissa_boundaries() {
        for (mode, positive, negative) in [
            (R::HalfToEven, "2", "2"),
            (R::HalfAwayFromZero, "3", "3"),
            (R::TowardZero, "2", "2"),
            (R::TowardNegativeInfinity, "2", "3"),
            (R::TowardPositiveInfinity, "3", "2"),
        ] {
            assert!(d("2.5").round(0, mode).unwrap().same_repr(d(positive)));
            assert!(
                d("2.5")
                    .negate()
                    .round(0, mode)
                    .unwrap()
                    .same_repr(d(negative).negate())
            );
        }
        assert_eq!(d("3.5").round(0, R::HalfToEven).unwrap().to_text(), "4");
        assert_eq!(d("1.2").round(3, R::HalfToEven).unwrap().to_text(), "1.200");
        let max = D::new(MAX_MANTISSA, 0).unwrap();
        assert!(matches!(
            max.checked_add(D::from_integer(1)),
            Err(E::Overflow)
        ));
        assert!(matches!(max.checked_mul(max), Err(E::Overflow)));
        assert!(matches!(max.checked_div(D::ZERO), Err(E::DivisionByZero)));
        assert!(matches!(max.round(1, R::TowardZero), Err(E::Overflow)));
        let near = D::new(MAX_MANTISSA, 1).unwrap();
        assert!(near.checked_add(d("0.04")).unwrap().same_repr(near));
        assert_eq!(
            near.checked_add(d("0.05")).unwrap().to_text(),
            "7922816251426433759354395034"
        );
        assert!(near.checked_mul(d("1.0")).unwrap().same_repr(near));
        assert_eq!(
            d("0.0000000000000000000000000001")
                .checked_mul(d("0.0000000000000000000000000001"))
                .unwrap()
                .to_text(),
            "0.0000000000000000000000000000"
        );
        assert!(matches!(
            d("1").round(-1, R::HalfToEven),
            Err(E::InvalidPlaces)
        ));
        assert!(matches!(
            d("1").round(29, R::HalfToEven),
            Err(E::InvalidPlaces)
        ));
        assert!(D::parse_literal("0.1234567890123456789012345678").is_some());
        assert!(D::parse_literal("0.12345678901234567890123456789").is_none());
        assert!(D::parse_literal("79228162514264337593543950336").is_none());
    }
}
