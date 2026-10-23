//! 基本型の演算（設計書 01-04「Integer」「Float」）。

//! 値の表現によらない基本型の計算（設計書 02-05「定数の検査と評価」、01-04「型の変換」、
//! 03-06「Map と Set（初回リリース版）」の鍵の順序）。
//! 定数の評価器（typeck）と組み込みの関数（builtins）が共有し、同じ式の値を一致させる。

use std::cmp::Ordering;
use std::fmt::{self, Write};

use super::decimal::Decimal;

pub(crate) mod numeric;

/// f64 の最大有限値の整数部309桁 + 小数点 + 精度28桁を収める。
/// 数値の中間文字列はヒープに確保しない。fmt::Write は範囲外へ書かない。
pub(crate) struct NumberText {
    bytes: [u8; 384],
    len: usize,
}
impl NumberText {
    /// 空の領域をスタックに作る。
    pub(crate) fn new() -> Self {
        Self {
            bytes: [0; 384],
            len: 0,
        }
    }
    /// 書き込み済みの範囲を UTF-8 として借りる。
    pub(crate) fn as_str(&self) -> Result<&str, fmt::Error> {
        let bytes = self.bytes.get(..self.len).ok_or(fmt::Error)?;
        std::str::from_utf8(bytes).map_err(|_| fmt::Error)
    }
}
impl Write for NumberText {
    fn write_str(&mut self, text: &str) -> fmt::Result {
        let end = self.len.checked_add(text.len()).ok_or(fmt::Error)?;
        self.bytes
            .get_mut(self.len..end)
            .ok_or(fmt::Error)?
            .copy_from_slice(text.as_bytes());
        self.len = end;
        Ok(())
    }
}

/// `Float.toString` の表記（01-04「型の変換」の `Float.toString` の規則）。文字列補間の `Float` の変換も同じ表記を使う。
pub fn float_to_text(value: f64) -> String {
    let mut result = String::new();
    // 有限値の最短仮数・指数は384バイト以内に収まり、String の fmt::Write は失敗しない。
    let _written = write_float_to_text(&mut result, value);
    result
}

/// 最短表記を呼び出し側の領域へ書く。整形本体は上限付きのスタック領域を渡す。
pub(crate) fn write_float_to_text(out: &mut impl std::fmt::Write, value: f64) -> std::fmt::Result {
    if value.is_nan() {
        return out.write_str(text::NAN);
    }
    if value == f64::INFINITY {
        return out.write_str(text::INFINITY);
    }
    if value == f64::NEG_INFINITY {
        return write!(out, "-{}", text::INFINITY);
    }
    let mut scientific = NumberText::new();
    write!(scientific, "{:e}", value.abs())?;
    finite_float_to_text(out, scientific.as_str()?, value.is_sign_negative())
}

/// Float32 の最短の仮数を、Float と同じ指数・零・特殊値の表記で示す。
pub(crate) fn float32_to_text(value: f32) -> String {
    let mut result = String::new();
    let _written = write_float32_to_text(&mut result, value);
    result
}

/// f64 への拡大や最短表記の再解析を挟まず、binary32 自身から書く。
pub(crate) fn write_float32_to_text(
    out: &mut impl std::fmt::Write,
    value: f32,
) -> std::fmt::Result {
    if value.is_nan() {
        return out.write_str(text::NAN);
    }
    if value == f32::INFINITY {
        return out.write_str(text::INFINITY);
    }
    if value == f32::NEG_INFINITY {
        return write!(out, "-{}", text::INFINITY);
    }
    let mut scientific = NumberText::new();
    write!(scientific, "{:e}", value.abs())?;
    finite_float_to_text(out, scientific.as_str()?, value.is_sign_negative())
}

fn finite_float_to_text(
    out: &mut impl std::fmt::Write,
    scientific: &str,
    negative: bool,
) -> std::fmt::Result {
    let (mantissa, exponent) = scientific.split_once('e').unwrap_or((scientific, "0"));
    let exponent = exponent.parse::<i32>().unwrap_or(0);
    if negative {
        out.write_char('-')?;
    }
    if !(-5..21).contains(&exponent) {
        out.write_str(mantissa)?;
        if !mantissa.contains('.') {
            out.write_str(".0")?;
        }
        out.write_char('e')?;
        if exponent >= 0 {
            out.write_char('+')?;
        }
        return write!(out, "{exponent}");
    }
    let digits = mantissa.chars().filter(char::is_ascii_digit);
    if exponent < 0 {
        out.write_str("0.")?;
        for _ in 1..exponent.unsigned_abs() {
            out.write_char('0')?;
        }
        for digit in digits {
            out.write_char(digit)?;
        }
    } else {
        let position = exponent.saturating_add(1);
        let mut length = 0_i32;
        for (index, digit) in digits.enumerate() {
            if i32::try_from(index).ok() == Some(position) {
                out.write_char('.')?;
            }
            out.write_char(digit)?;
            length = length.saturating_add(1);
        }
        if length <= position {
            for _ in length..position {
                out.write_char('0')?;
            }
            out.write_str(".0")?;
        }
    }
    Ok(())
}

mod text {
    pub const NAN: &str = "NaN";
    pub const INFINITY: &str = "Infinity";
}

/// 鍵の順序の葉（基本型と `Bytes` の値）。構成子・リスト・集合・マップは、それぞれの値の表現の側で辿る。
#[derive(Clone, Copy, Debug)]
pub enum KeyAtom<'a> {
    Unit,
    Boolean(bool),
    Integer(i64),
    Byte(u8),
    Character(char),
    Decimal(Decimal),
    String(&'a str),
    Bytes(&'a [u8]),
    Integer8(i8),
    Integer16(i16),
    Integer32(i32),
    UnsignedInteger16(u16),
    UnsignedInteger32(u32),
    UnsignedInteger64(u64),
}

/// 同じ型の二つの葉を、03-06 の鍵の順序で比べる（`Decimal` は小数の桁数によらず数の大小。`String` はスカラー値の列の
/// 辞書式、`Bytes` は辞書式で短いほうが先）。型の違う葉は型検査を通ったプログラムでは比べないので `None` を返し、
/// 呼び出し側が処理系の不具合（`InternalError` か `Stop::Internal`）にする。
pub fn cmp_key_atom(a: KeyAtom<'_>, b: KeyAtom<'_>) -> Option<Ordering> {
    match (a, b) {
        (KeyAtom::Unit, KeyAtom::Unit) => Some(Ordering::Equal),
        (KeyAtom::Boolean(a), KeyAtom::Boolean(b)) => Some(a.cmp(&b)),
        (KeyAtom::Integer(a), KeyAtom::Integer(b)) => Some(a.cmp(&b)),
        (KeyAtom::Integer8(a), KeyAtom::Integer8(b)) => Some(a.cmp(&b)),
        (KeyAtom::Integer16(a), KeyAtom::Integer16(b)) => Some(a.cmp(&b)),
        (KeyAtom::Integer32(a), KeyAtom::Integer32(b)) => Some(a.cmp(&b)),
        (KeyAtom::UnsignedInteger16(a), KeyAtom::UnsignedInteger16(b)) => Some(a.cmp(&b)),
        (KeyAtom::UnsignedInteger32(a), KeyAtom::UnsignedInteger32(b)) => Some(a.cmp(&b)),
        (KeyAtom::UnsignedInteger64(a), KeyAtom::UnsignedInteger64(b)) => Some(a.cmp(&b)),
        (KeyAtom::Byte(a), KeyAtom::Byte(b)) => Some(a.cmp(&b)),
        (KeyAtom::Character(a), KeyAtom::Character(b)) => Some(a.cmp(&b)),
        (KeyAtom::Decimal(a), KeyAtom::Decimal(b)) => Some(a.cmp_num(b)),
        (KeyAtom::String(a), KeyAtom::String(b)) => Some(a.chars().cmp(b.chars())),
        (KeyAtom::Bytes(a), KeyAtom::Bytes(b)) => Some(a.cmp(b)),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::{KeyAtom as K, cmp_key_atom};
    use crate::base::decimal::Decimal;
    use std::cmp::Ordering::{Equal, Greater, Less};
    #[test]
    fn float32_text_uses_binary32_precision_and_float_notation() {
        // f64 への拡大と表示用の桁の丸めを区別し、各表示先で共有する規則を確かめる。
        for (value, expected) in [
            (0.1_f32, "0.1"),
            (1.0_f32, "1.0"),
            (-0.0_f32, "-0.0"),
            (1e-5_f32, "0.00001"),
            (1e-6_f32, "1.0e-6"),
            (1e20_f32, "100000000000000000000.0"),
            (1e21_f32, "1.0e+21"),
            (f32::MAX, "3.4028235e+38"),
            (f32::INFINITY, "Infinity"),
            (f32::NEG_INFINITY, "-Infinity"),
            (f32::NAN, "NaN"),
        ] {
            assert_eq!(super::float32_to_text(value), expected);
        }
    }
    #[test]
    fn key_leaf_order_and_type_boundary() {
        assert_eq!(cmp_key_atom(K::Integer(-1), K::Integer(0)), Some(Less));
        assert_eq!(cmp_key_atom(K::String("a"), K::String("aa")), Some(Less));
        assert_eq!(cmp_key_atom(K::String("あ"), K::String("é")), Some(Greater));
        assert_eq!(
            cmp_key_atom(K::Bytes(&[1, 2]), K::Bytes(&[1, 3])),
            Some(Less)
        );
        assert_eq!(cmp_key_atom(K::Bytes(&[1]), K::Bytes(&[1, 0])), Some(Less));
        assert_eq!(cmp_key_atom(K::Unit, K::Unit), Some(Equal));
        assert_eq!(
            cmp_key_atom(K::Boolean(false), K::Boolean(true)),
            Some(Less)
        );
        assert_eq!(cmp_key_atom(K::Byte(255), K::Byte(0)), Some(Greater));
        assert_eq!(
            cmp_key_atom(K::Character('a'), K::Character('b')),
            Some(Less)
        );
        let order = Decimal::parse_literal("1.0")
            .zip(Decimal::parse_literal("1.00"))
            .and_then(|(a, b)| cmp_key_atom(K::Decimal(a), K::Decimal(b)));
        assert_eq!(order, Some(Equal));
        assert_eq!(cmp_key_atom(K::Integer(1), K::Byte(1)), None);
        assert_eq!(cmp_key_atom(K::String("a"), K::Bytes(b"a")), None);
    }
}
