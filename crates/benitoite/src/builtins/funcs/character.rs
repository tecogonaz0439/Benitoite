//! 文字の変換と ASCII・Unicode の判定（設計書 01-04「Character」、03-06「Character」）。
//! 仮の本体は、後の作業が本体と Rust の引数型だけを書き換える。
//! 名前・権限・引数の数・DECLS の中の位置は変えない（実装プラン 10-12「まだ書かない項目の仮の本体」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::{CheckedLen, StrBuf, Value};

builtin! {
    /// `Character.toInteger` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Character.toInteger",
    pure fn to_integer(ctx, c: char) -> i64 {
        let _ = ctx;
        Ok(i64::from(u32::from(c)))
    }
}

builtin! {
    /// `Character.fromInteger` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Character.fromInteger",
    pure fn from_integer(ctx, n: i64) -> Value<'e> {
        super::option(
            &ctx,
            u32::try_from(n)
                .ok()
                .and_then(char::from_u32)
                .map(Value::Char),
        )
    }
}

builtin! {
    /// `Character.toString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Character.toString",
    pure fn to_string(ctx, c: char) -> Value<'e> {
        let mut buf = [0; 4];
        ctx.alloc_str(c.encode_utf8(&mut buf), "Character.toString")
    }
}

builtin! {
    /// `Character.isASCIIDigit` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Character.isASCIIDigit",
    pure fn is_a_s_c_i_i_digit(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(c.is_ascii_digit())
    }
}

builtin! {
    /// `Character.isASCIIWhitespace` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Character.isASCIIWhitespace",
    pure fn is_a_s_c_i_i_whitespace(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(super::ascii_whitespace(c))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    to_integer::DECL,
    from_integer::DECL,
    to_string::DECL,
    is_a_s_c_i_i_digit::DECL,
    is_a_s_c_i_i_whitespace::DECL,
];

builtin! {
    /// `Character.isAlphabetic` の本体。`char::is_alphabetic` で Unicode の Alphabetic を判定する（設計書 03-06「Character」）。
    name = "Character.isAlphabetic",
    pure fn is_alphabetic(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(c.is_alphabetic())
    }
}

builtin! {
    /// `Character.isNumeric` の本体。`char::is_numeric` で Unicode の一般カテゴリ Nd・Nl・No を判定する（設計書 03-06「Character」）。
    name = "Character.isNumeric",
    pure fn is_numeric(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(c.is_numeric())
    }
}

builtin! {
    /// `Character.isWhitespace` の本体。`char::is_whitespace` で Unicode の White_Space を判定する（設計書 03-06「Character」）。
    name = "Character.isWhitespace",
    pure fn is_whitespace(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(c.is_whitespace())
    }
}

builtin! {
    /// `Character.isUppercase` の本体。`char::is_uppercase` で Unicode の Uppercase を判定する（設計書 03-06「Character」）。
    name = "Character.isUppercase",
    pure fn is_uppercase(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(c.is_uppercase())
    }
}

builtin! {
    /// `Character.isLowercase` の本体。`char::is_lowercase` で Unicode の Lowercase を判定する（設計書 03-06「Character」）。
    name = "Character.isLowercase",
    pure fn is_lowercase(ctx, c: char) -> bool {
        let _ = ctx;
        Ok(c.is_lowercase())
    }
}

builtin! {
    /// `Character.toUppercase` の本体。地域に依らない大文字への対応を連結する（設計書 03-06「Character」）。
    name = "Character.toUppercase",
    pure fn to_uppercase(ctx, c: char) -> Value<'e> {
        ctx.alloc_str_buf(case_buf(c.to_uppercase(), "Character.toUppercase")?)
    }
}

builtin! {
    /// `Character.toLowercase` の本体。地域に依らない小文字への対応を連結する（設計書 03-06「Character」）。
    name = "Character.toLowercase",
    pure fn to_lowercase(ctx, c: char) -> Value<'e> {
        ctx.alloc_str_buf(case_buf(c.to_lowercase(), "Character.toLowercase")?)
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const UNICODE_DECLS: &[BuiltinDecl] = &[
    is_alphabetic::DECL,
    is_numeric::DECL,
    is_whitespace::DECL,
    is_uppercase::DECL,
    is_lowercase::DECL,
    to_uppercase::DECL,
    to_lowercase::DECL,
];

// 文字数ではなく UTF-8 のバイト数で、構築を始める前に確かめる（設計書 02-09「一つの操作で作る値の大きさの上限」）。
fn case_buf(
    chars: impl Iterator<Item = char> + Clone,
    function: &'static str,
) -> Result<StrBuf, Stop> {
    let size = chars.clone().try_fold(0u64, |size, c| {
        Ok::<_, Stop>(size.saturating_add(super::count(c.len_utf8())?))
    })?;
    CheckedLen::bytes(size, function)?;
    let mut buf = StrBuf::new(function);
    for c in chars {
        buf.push_char(c)?;
    }
    Ok(buf)
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used)]
    // 関門: Unicode の分類と複数文字への変換を守る。ASCII 関数への取り違えや
    // 一文字への切り詰めを捕まえ、既存の ASCII のテストとは重ならず、公開の口を加えない。
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::runtime::heap::{Heap, HeapConfig};

    #[test]
    fn unicode_character_properties() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (c, alphabetic, numeric, whitespace, uppercase, lowercase) in [
                ('A', true, false, false, true, false),
                ('a', true, false, false, false, true),
                ('3', false, true, false, false, false),
                (' ', false, false, true, false, false),
                ('\t', false, false, true, false, false),
                ('!', false, false, false, false, false),
                ('é', true, false, false, false, true),
                ('Ω', true, false, false, true, false),
                ('中', true, false, false, false, false),
                ('٣', false, true, false, false, false),
                ('Ⅻ', true, true, false, true, false),
                ('½', false, true, false, false, false),
                ('\u{3000}', false, false, true, false, false),
                ('\u{a0}', false, false, true, false, false),
            ] {
                assert_eq!(
                    direct!(ctx, is_alphabetic, c).unwrap(),
                    alphabetic,
                    "Alphabetic: {c:?}"
                );
                assert_eq!(
                    direct!(ctx, is_numeric, c).unwrap(),
                    numeric,
                    "numeric: {c:?}"
                );
                assert_eq!(
                    direct!(ctx, is_whitespace, c).unwrap(),
                    whitespace,
                    "White_Space: {c:?}"
                );
                assert_eq!(
                    direct!(ctx, is_uppercase, c).unwrap(),
                    uppercase,
                    "Uppercase: {c:?}"
                );
                assert_eq!(
                    direct!(ctx, is_lowercase, c).unwrap(),
                    lowercase,
                    "Lowercase: {c:?}"
                );
            }
        });
    }

    #[test]
    fn unicode_character_case_mappings() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (c, upper, lower) in [
                ('a', "A", "a"),
                ('A', "A", "a"),
                ('ß', "SS", "ß"),
                ('İ', "İ", "i\u{307}"),
                ('Σ', "Σ", "σ"),
                ('é', "É", "é"),
                ('中', "中", "中"),
                ('1', "1", "1"),
            ] {
                let value = direct!(ctx, to_uppercase, c).unwrap();
                assert_eq!(ctx.str(value), Some(upper));
                let value = direct!(ctx, to_lowercase, c).unwrap();
                assert_eq!(ctx.str(value), Some(lower));
            }
        });
    }
}
