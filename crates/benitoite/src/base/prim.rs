//! 中身は作業で書く（10-interfaces の sig=src/base/prim.rs を参照）。

//! 値の表現によらない基本型の計算（設計書 02-05「定数の検査と評価」、01-04「型の変換」、
//! 03-06「Map と Set（初回リリース版）」の鍵の順序）。
//! 定数の評価器（typeck）と組み込みの関数（builtins）が共有し、同じ式の値を一致させる。

use std::cmp::Ordering;

use super::decimal::Decimal;

/// `Float.toString` の表記（01-04「型の変換」の `Float.toString` の規則）。文字列補間の `Float` の変換も同じ表記を使う。
pub fn float_to_text(value: f64) -> String {
    if value.is_nan() {
        return text::NAN.into();
    }
    if value == f64::INFINITY {
        return text::INFINITY.into();
    }
    if value == f64::NEG_INFINITY {
        return format!("-{}", text::INFINITY);
    }

    // LowerExp が作る最短の仮数を使い、仕様の指数の境界で表記を切り替える
    // （設計書 01-04「型の変換」）。有限値の指数は必ず i32 に収まる。
    let scientific = format!("{:e}", value.abs());
    let (mantissa, exponent) = scientific.split_once('e').unwrap_or((&scientific, "0"));
    let exponent = exponent.parse::<i32>().unwrap_or(0);
    let mut result = String::new();
    if value.is_sign_negative() {
        result.push('-');
    }
    if !(-5..21).contains(&exponent) {
        result.push_str(mantissa);
        if !mantissa.contains('.') {
            result.push_str(".0");
        }
        result.push('e');
        if exponent >= 0 {
            result.push('+');
        }
        result.push_str(&exponent.to_string());
        return result;
    }
    let digits = mantissa
        .chars()
        .filter(char::is_ascii_digit)
        .collect::<String>();
    if exponent < 0 {
        result.push_str("0.");
        for _ in 1..exponent.unsigned_abs() {
            result.push('0');
        }
        result.push_str(&digits);
    } else {
        let position = exponent.saturating_add(1);
        for (index, digit) in digits.chars().enumerate() {
            if i32::try_from(index).ok() == Some(position) {
                result.push('.');
            }
            result.push(digit);
        }
        let length = i32::try_from(digits.len()).unwrap_or(i32::MAX);
        if length <= position {
            for _ in length..position {
                result.push('0');
            }
            result.push_str(".0");
        }
    }
    result
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
}

/// 同じ型の二つの葉を、03-06 の鍵の順序で比べる（`Decimal` は小数の桁数によらず数の大小。`String` はスカラー値の列の
/// 辞書式、`Bytes` は辞書式で短いほうが先）。型の違う葉は型検査を通ったプログラムでは比べないので `None` を返し、
/// 呼び出し側が処理系の不具合（`InternalError` か `Stop::Internal`）にする。
pub fn cmp_key_atom(a: KeyAtom<'_>, b: KeyAtom<'_>) -> Option<Ordering> {
    match (a, b) {
        (KeyAtom::Unit, KeyAtom::Unit) => Some(Ordering::Equal),
        (KeyAtom::Boolean(a), KeyAtom::Boolean(b)) => Some(a.cmp(&b)),
        (KeyAtom::Integer(a), KeyAtom::Integer(b)) => Some(a.cmp(&b)),
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
