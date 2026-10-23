//! 検査済み書式の型別の書式化（設計書 02-06「書式化の内部頭」）。
//! 言語の値と実行器に依存せず、出力の各片と全長を確保前に求める。

use super::prim::NumberText;
use std::fmt::Write;

use super::{
    Decimal,
    display_width::{self, WidthMode},
    prim,
};

/// 固定定数から復元した書式（設計書 02-06「書式化の内部頭」）。
/// 欄は decode で検査し、その後は変更しない。
#[derive(Clone, Copy, Debug)]
pub struct FormatSpec {
    kind: i64,
    align: i64,
    plus: bool,
    alternate: bool,
    zero: bool,
    width: u16,
    precision: Option<u8>,
}

/// 書式化する値。整数の幅の違いは、符号を保って拡大した後は表示に影響しない。
#[derive(Clone, Copy, Debug)]
pub enum FormatValue<'a> {
    Signed(i64),
    Unsigned(u64),
    Float(f64),
    Float32(f32),
    Decimal(Decimal),
    String(&'a str),
    Character(char),
    Boolean(bool),
}

/// 不正な内部引数とサイズのあふれを区別する。利用者の書式エラーはこの入口より前で断る。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FormatError {
    InvalidSpec,
    IncompatibleType,
    SizeOverflow,
    BufferOverflow,
}

impl FormatSpec {
    /// 生の書式文字列は受け取らない。省略は kind/align/sign/width が 0、precision が -1。
    pub fn decode(
        kind: i64,
        align: i64,
        sign: i64,
        alternate: bool,
        zero: bool,
        width: i64,
        precision: i64,
    ) -> Result<Self, FormatError> {
        if !(0..=8).contains(&kind)
            || !(0..=3).contains(&align)
            || !(0..=1).contains(&sign)
            || !(0..=65535).contains(&width)
            || !(-1..=28).contains(&precision)
            || (precision >= 0 && kind != 6)
            || (align != 0 && width == 0)
            || (zero && (width == 0 || align != 0))
            || (alternate && !(2..=5).contains(&kind))
            || (kind == 0
                && align == 0
                && sign == 0
                && !alternate
                && !zero
                && width == 0
                && precision == -1)
        {
            return Err(FormatError::InvalidSpec);
        }
        Ok(Self {
            kind,
            align,
            plus: sign == 1,
            alternate,
            zero,
            width: u16::try_from(width).map_err(|_| FormatError::InvalidSpec)?,
            precision: if precision == -1 {
                None
            } else {
                Some(u8::try_from(precision).map_err(|_| FormatError::InvalidSpec)?)
            },
        })
    }

    /// 型との適合を防御的に確認し、数字列・符号・接頭辞・埋める個数を求める。
    pub fn prepare(self, value: FormatValue<'_>) -> Result<Formatted<'_>, FormatError> {
        let integer = matches!(value, FormatValue::Signed(_) | FormatValue::Unsigned(_));
        let fractional = matches!(
            value,
            FormatValue::Float(_) | FormatValue::Float32(_) | FormatValue::Decimal(_)
        );
        let numeric = integer || fractional;
        let compatible = match self.kind {
            0 => true,
            1..=5 => integer,
            6 => fractional,
            7 => matches!(value, FormatValue::String(_)),
            8 => matches!(value, FormatValue::Character(_)),
            _ => false,
        };
        if !compatible || ((self.plus || self.zero) && !numeric) {
            return Err(FormatError::IncompatibleType);
        }
        let mut buffer = NumberText::new();
        let mut negative = false;
        let mut nan = false;
        let mut finite = true;
        let body = match value {
            FormatValue::String(s) => Body::borrowed(s),
            FormatValue::Boolean(b) => Body::borrowed(if b { "true" } else { "false" }),
            FormatValue::Character(c) => {
                buffer
                    .write_char(c)
                    .map_err(|_| FormatError::BufferOverflow)?;
                Body::number(buffer)
            }
            FormatValue::Signed(n) => {
                negative = n < 0;
                self.integer_digits(n.unsigned_abs(), &mut buffer)?;
                Body::number(buffer)
            }
            FormatValue::Unsigned(n) => {
                self.integer_digits(n, &mut buffer)?;
                Body::number(buffer)
            }
            FormatValue::Decimal(n) => {
                let precision = if self.kind == 6 {
                    self.precision.unwrap_or(n.scale())
                } else {
                    n.scale()
                };
                negative = decimal_digits(n, precision, &mut buffer)?;
                Body::number(buffer)
            }
            FormatValue::Float(n) => {
                nan = n.is_nan();
                finite = n.is_finite();
                negative = !nan && n.is_sign_negative();
                if self.kind == 6 && finite {
                    // binary64 の値を直接丸める。最短表記の十進数を再び丸めない。
                    write!(
                        buffer,
                        "{:.*}",
                        usize::from(self.precision.unwrap_or(6)),
                        n.abs()
                    )
                } else {
                    prim::write_float_to_text(&mut buffer, n.abs())
                }
                .map_err(|_| FormatError::BufferOverflow)?;
                Body::number(buffer)
            }
            FormatValue::Float32(n) => {
                nan = n.is_nan();
                finite = n.is_finite();
                negative = !nan && n.is_sign_negative();
                if self.kind == 6 && finite {
                    // f32 自身の値を書式化し、最短表記の再解析や表示桁の再丸めを挟まない。
                    write!(
                        buffer,
                        "{:.*}",
                        usize::from(self.precision.unwrap_or(6)),
                        n.abs()
                    )
                } else {
                    prim::write_float32_to_text(&mut buffer, n.abs())
                }
                .map_err(|_| FormatError::BufferOverflow)?;
                Body::number(buffer)
            }
        };
        let sign = if negative {
            "-"
        } else if self.plus && !nan {
            "+"
        } else {
            ""
        };
        let prefix = if self.alternate {
            match self.kind {
                2 => "0b",
                3 => "0o",
                4 => "0x",
                5 => "0X",
                _ => return Err(FormatError::InvalidSpec),
            }
        } else {
            ""
        };
        let measured = display_width::width(body.as_str()?, WidthMode::Default)
            .and_then(|n| n.checked_add(u64::try_from(sign.len()).ok()?))
            .and_then(|n| n.checked_add(u64::try_from(prefix.len()).ok()?))
            .ok_or(FormatError::SizeOverflow)?;
        let padding = u64::from(self.width).saturating_sub(measured);
        let (before, zeros, after) = if self.zero && finite {
            (0, padding, 0)
        } else {
            let align = if self.align == 0 {
                if numeric { 2 } else { 1 }
            } else {
                self.align
            };
            match align {
                1 => (0, 0, padding),
                2 => (padding, 0, 0),
                3 => (padding / 2, 0, padding.saturating_sub(padding / 2)),
                _ => return Err(FormatError::InvalidSpec),
            }
        };
        let byte_len = u64::try_from(body.as_str()?.len())
            .ok()
            .and_then(|n| n.checked_add(u64::try_from(sign.len()).ok()?))
            .and_then(|n| n.checked_add(u64::try_from(prefix.len()).ok()?))
            .and_then(|n| n.checked_add(padding))
            .ok_or(FormatError::SizeOverflow)?;
        Ok(Formatted {
            body,
            sign,
            prefix,
            before,
            zeros,
            after,
            byte_len,
        })
    }

    fn integer_digits(self, n: u64, buffer: &mut NumberText) -> Result<(), FormatError> {
        match self.kind {
            2 => write!(buffer, "{n:b}"),
            3 => write!(buffer, "{n:o}"),
            4 => write!(buffer, "{n:x}"),
            5 => write!(buffer, "{n:X}"),
            _ => write!(buffer, "{n}"),
        }
        .map_err(|_| FormatError::BufferOverflow)
    }
}

struct Body<'a> {
    borrowed: Option<&'a str>,
    number: NumberText,
}
impl<'a> Body<'a> {
    fn borrowed(s: &'a str) -> Self {
        Self {
            borrowed: Some(s),
            number: NumberText::new(),
        }
    }
    fn number(number: NumberText) -> Self {
        Self {
            borrowed: None,
            number,
        }
    }
    fn as_str(&self) -> Result<&str, FormatError> {
        match self.borrowed {
            Some(s) => Ok(s),
            None => self
                .number
                .as_str()
                .map_err(|_| FormatError::BufferOverflow),
        }
    }
}

/// 予算検査と確保へ渡す書式化した各片。元の String は借りたまま保持する。
pub struct Formatted<'a> {
    body: Body<'a>,
    sign: &'static str,
    prefix: &'static str,
    before: u64,
    zeros: u64,
    after: u64,
    byte_len: u64,
}
impl Formatted<'_> {
    /// 論理上限と予算の検査に用いる UTF-8 の全長。
    pub fn byte_len(&self) -> u64 {
        self.byte_len
    }

    /// 前空白、符号、基数接頭辞、零、本文、後空白の順。
    /// 固定した不変の ASCII 領域を借り、幅に比例する一時文字列を作らない。
    pub fn parts(&self) -> Result<[&str; 6], FormatError> {
        Ok([
            fill(SPACES, self.before)?,
            self.sign,
            self.prefix,
            fill(ZEROS, self.zeros)?,
            self.body.as_str()?,
            fill(SPACES, self.after)?,
        ])
    }
}

// 書式の幅の静的上限までを共有する。実行ごとの確保・可変状態は持たない。
const SPACES: &str = match std::str::from_utf8(&[b' '; 65535]) {
    Ok(s) => s,
    Err(_) => "",
};
const ZEROS: &str = match std::str::from_utf8(&[b'0'; 65535]) {
    Ok(s) => s,
    Err(_) => "",
};
fn fill(text: &str, count: u64) -> Result<&str, FormatError> {
    let count = usize::try_from(count).map_err(|_| FormatError::SizeOverflow)?;
    text.get(..count).ok_or(FormatError::SizeOverflow)
}

// 表示のために有界 Decimal を作り直さない。減らす桁だけを整数で偶数丸めし、
// 増やす桁は数字列に零を付ける。返り値は丸め後に残す負号である。
fn decimal_digits(n: Decimal, precision: u8, output: &mut NumberText) -> Result<bool, FormatError> {
    let mut magnitude = n.mantissa().unsigned_abs();
    let scale = n.scale();
    if precision < scale {
        let divisor = 10_u128
            .checked_pow(u32::from(scale.saturating_sub(precision)))
            .ok_or(FormatError::BufferOverflow)?;
        let quotient = magnitude
            .checked_div(divisor)
            .ok_or(FormatError::BufferOverflow)?;
        let remainder = magnitude
            .checked_rem(divisor)
            .ok_or(FormatError::BufferOverflow)?;
        let half = divisor / 2;
        let increment = remainder > half || (remainder == half && quotient % 2 == 1);
        magnitude = quotient
            .checked_add(u128::from(increment))
            .ok_or(FormatError::BufferOverflow)?;
    }
    let mut digits = NumberText::new();
    write!(digits, "{magnitude}").map_err(|_| FormatError::BufferOverflow)?;
    let digits = digits.as_str().map_err(|_| FormatError::BufferOverflow)?;
    let digit_scale = usize::from(precision.min(scale));
    if digits.len() <= digit_scale {
        output
            .write_str("0.")
            .map_err(|_| FormatError::BufferOverflow)?;
        for _ in digits.len()..digit_scale {
            output
                .write_char('0')
                .map_err(|_| FormatError::BufferOverflow)?;
        }
        output
            .write_str(digits)
            .map_err(|_| FormatError::BufferOverflow)?;
    } else {
        let split = digits
            .len()
            .checked_sub(digit_scale)
            .ok_or(FormatError::BufferOverflow)?;
        output
            .write_str(digits.get(..split).ok_or(FormatError::BufferOverflow)?)
            .map_err(|_| FormatError::BufferOverflow)?;
        if digit_scale != 0 {
            output
                .write_char('.')
                .map_err(|_| FormatError::BufferOverflow)?;
            output
                .write_str(digits.get(split..).ok_or(FormatError::BufferOverflow)?)
                .map_err(|_| FormatError::BufferOverflow)?;
        }
    }
    if precision > scale {
        if scale == 0 {
            output
                .write_char('.')
                .map_err(|_| FormatError::BufferOverflow)?;
        }
        for _ in scale..precision {
            output
                .write_char('0')
                .map_err(|_| FormatError::BufferOverflow)?;
        }
    }
    Ok(n.mantissa() < 0 && magnitude != 0)
}
