//! 文字列の位置・分割・構築（設計書 01-04「String」、03-06「String」）。
//! 仮の本体は、後の作業が本体と Rust の引数型だけを書き換える。
//! 名前・権限・引数の数・DECLS の中の位置は変えない（実装プラン 10-12「まだ書かない項目の仮の本体」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::MAX_STRING_BYTES;
use crate::runtime::ResourceError;
use crate::runtime::SizeUnit;
use crate::runtime::Stop;
use crate::runtime::heap::CheckedLen;
use crate::runtime::heap::StrBuf;
use crate::runtime::heap::Value;

builtin! {
    /// `String.byteLength` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.byteLength",
    pure fn byte_length(ctx, s: &'c str) -> i64 {
        let _ = ctx;
        super::integer_count(s.len())
    }
}

builtin! {
    /// `String.characterCount` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.characterCount",
    pure fn character_count(ctx, s: &'c str) -> i64 {
        let _ = ctx;
        super::integer_count(s.chars().count())
    }
}

builtin! {
    /// `String.byteSlice` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.byteSlice",
    pure fn byte_slice(ctx, s: &'c str, start: i64, end: i64) -> Value<'e> {
        let value = match (usize::try_from(start), usize::try_from(end)) {
            (Ok(start), Ok(end)) => s
                .get(start..end)
                .map(|s| ctx.alloc_str(s, "String.byteSlice"))
                .transpose()?,
            _ => None,
        };
        super::option(&ctx, value)
    }
}

builtin! {
    /// `String.characterSlice` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.characterSlice",
    pure fn character_slice(ctx, s: &'c str, start: i64, end: i64) -> Value<'e> {
        let (Ok(start), Ok(end)) = (usize::try_from(start), usize::try_from(end)) else {
            return super::option(&ctx, None);
        };
        if end < start || end > s.chars().count() {
            return super::option(&ctx, None);
        }
        let offset = |i| {
            s.char_indices()
                .nth(i)
                .map_or(s.len(), |(offset, _)| offset)
        };
        let slice = s
            .get(offset(start)..offset(end))
            .ok_or_else(|| Stop::Internal("validated character slice out of bounds".into()))?;
        super::option(&ctx, Some(ctx.alloc_str(slice, "String.characterSlice")?))
    }
}

builtin! {
    /// `String.characterAt` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.characterAt",
    pure fn character_at(ctx, s: &'c str, i: i64) -> Value<'e> {
        super::option(
            &ctx,
            usize::try_from(i)
                .ok()
                .and_then(|i| s.chars().nth(i))
                .map(Value::Char),
        )
    }
}

builtin! {
    /// `String.isEmpty` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.isEmpty",
    pure fn is_empty(ctx, s: &'c str) -> bool {
        let _ = ctx;
        Ok(s.is_empty())
    }
}

builtin! {
    /// `String.contains` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.contains",
    pure fn contains(ctx, s: &'c str, sub: &'c str) -> bool {
        let _ = ctx;
        Ok(s.contains(sub))
    }
}

builtin! {
    /// `String.startsWith` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.startsWith",
    pure fn starts_with(ctx, s: &'c str, sub: &'c str) -> bool {
        let _ = ctx;
        Ok(s.starts_with(sub))
    }
}

builtin! {
    /// `String.endsWith` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.endsWith",
    pure fn ends_with(ctx, s: &'c str, sub: &'c str) -> bool {
        let _ = ctx;
        Ok(s.ends_with(sub))
    }
}

builtin! {
    /// `String.byteIndexOf` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.byteIndexOf",
    pure fn byte_index_of(ctx, s: &'c str, sub: &'c str) -> Value<'e> {
        let i = s.find(sub).map(super::integer_count).transpose()?;
        super::option(&ctx, i.map(Value::Int))
    }
}

builtin! {
    /// `String.split` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.split",
    pure fn split(ctx, s: &'c str, sep: &'c str) -> Value<'e> {
        let n = if sep.is_empty() {
            s.chars().count()
        } else {
            s.split(sep).count()
        };
        CheckedLen::elements(super::count(n)?, "String.split")?;
        let mut items = Vec::with_capacity(n);
        if sep.is_empty() {
            for c in s.chars() {
                let mut buf = [0; 4];
                items.push(ctx.alloc_str(c.encode_utf8(&mut buf), "String.split")?);
            }
        } else {
            for part in s.split(sep) {
                items.push(ctx.alloc_str(part, "String.split")?);
            }
        }
        crate::runtime::list::from_values(&ctx, &items, "String.split")
    }
}

builtin! {
    /// `String.lines` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.lines",
    pure fn lines(ctx, s: &'c str) -> Value<'e> {
        let n = line_parts(s).count();
        CheckedLen::elements(super::count(n)?, "String.lines")?;
        let mut items = Vec::with_capacity(n);
        for part in line_parts(s) {
            items.push(ctx.alloc_str(part, "String.lines")?);
        }
        crate::runtime::list::from_values(&ctx, &items, "String.lines")
    }
}

// Console も同じ区切り規則を使い、末尾の LF と単独の CR の扱いを揃える
// （設計書 03-07「共通の規則」）。
pub(super) fn line_parts(s: &str) -> impl Iterator<Item = &str> {
    s.split_terminator('\n')
        .map(|part| part.strip_suffix('\r').unwrap_or(part))
}

builtin! {
    /// `String.join` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.join",
    pure fn join(ctx, xs: Value<'e>, sep: &'c str) -> Value<'e> {
        let items = crate::runtime::list::to_vec(&ctx, xs)?;
        let mut size = 0u64;
        for item in &items {
            let s = ctx
                .str(*item)
                .ok_or_else(|| Stop::Internal("String.join expected String elements".into()))?;
            size = size
                .checked_add(super::count(s.len())?)
                .ok_or_else(|| too_large("String.join"))?;
        }
        let separators = super::count(items.len().saturating_sub(1))?
            .checked_mul(super::count(sep.len())?)
            .ok_or_else(|| too_large("String.join"))?;
        let size = size
            .checked_add(separators)
            .ok_or_else(|| too_large("String.join"))?;
        CheckedLen::bytes(size, "String.join")?;
        let mut buf = StrBuf::new("String.join");
        for (i, item) in items.into_iter().enumerate() {
            if i != 0 {
                buf.push_str(sep)?;
            }
            buf.push_str(
                ctx.str(item)
                    .ok_or_else(|| Stop::Internal("String.join expected String elements".into()))?,
            )?;
        }
        ctx.alloc_str_buf(buf)
    }
}

builtin! {
    /// `String.trim` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.trim",
    pure fn trim(ctx, s: &'c str) -> Value<'e> {
        ctx.alloc_str(s.trim_matches(super::ascii_whitespace), "String.trim")
    }
}

builtin! {
    /// `String.replace` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.replace",
    pure fn replace(ctx, s: &'c str, old: &'c str, new: &'c str) -> Value<'e> {
        if old.is_empty() {
            return ctx.alloc_str(s, "String.replace");
        }
        // 出現を数えてから結果の大きさを確かめる（設計書 02-09「一つの操作で作る値の大きさの上限」）。
        let n = super::count(s.matches(old).count())?;
        let removed = n
            .checked_mul(super::count(old.len())?)
            .ok_or_else(|| too_large("String.replace"))?;
        let added = n
            .checked_mul(super::count(new.len())?)
            .ok_or_else(|| too_large("String.replace"))?;
        let size = super::count(s.len())?
            .checked_sub(removed)
            .and_then(|n| n.checked_add(added))
            .ok_or_else(|| too_large("String.replace"))?;
        CheckedLen::bytes(size, "String.replace")?;
        ctx.alloc_str(&s.replace(old, new), "String.replace")
    }
}

builtin! {
    /// `String.repeat` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.repeat",
    pure fn repeat(ctx, s: &'c str, n: i64) -> Value<'e> {
        if n <= 0 || s.is_empty() {
            return ctx.alloc_str("", "String.repeat");
        }
        let n = u64::try_from(n)
            .map_err(|_| Stop::Internal("positive repeat count out of bounds".into()))?;
        let size = super::count(s.len())?
            .checked_mul(n)
            .ok_or_else(|| too_large("String.repeat"))?;
        CheckedLen::bytes(size, "String.repeat")?;
        let n =
            usize::try_from(n).map_err(|_| Stop::Internal("repeat count does not fit usize".into()))?;
        ctx.alloc_str(&s.repeat(n), "String.repeat")
    }
}

builtin! {
    /// `String.characters` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.characters",
    pure fn characters(ctx, s: &'c str) -> Value<'e> {
        CheckedLen::elements(super::count(s.chars().count())?, "String.characters")?;
        let items = s.chars().map(Value::Char).collect::<Vec<_>>();
        crate::runtime::list::from_values(&ctx, &items, "String.characters")
    }
}

builtin! {
    /// `String.fromCharacters` の本体（実装プラン 10-12「項目の一覧」）。
    name = "String.fromCharacters",
    pure fn from_characters(ctx, xs: Value<'e>) -> Value<'e> {
        let items = crate::runtime::list::to_vec(&ctx, xs)?;
        let mut size = 0u64;
        for item in &items {
            let Value::Char(c) = item else {
                return Err(Stop::Internal(
                    "String.fromCharacters expected Character elements".into(),
                ));
            };
            size = size
                .checked_add(super::count(c.len_utf8())?)
                .ok_or_else(|| too_large("String.fromCharacters"))?;
        }
        CheckedLen::bytes(size, "String.fromCharacters")?;
        let mut buf = StrBuf::new("String.fromCharacters");
        for item in items {
            let Value::Char(c) = item else {
                return Err(Stop::Internal(
                    "String.fromCharacters expected Character elements".into(),
                ));
            };
            buf.push_char(c)?;
        }
        ctx.alloc_str_buf(buf)
    }
}

fn too_large(function: &'static str) -> Stop {
    Stop::Resource(ResourceError::ValueTooLarge {
        function,
        size: u64::MAX,
        unit: SizeUnit::Bytes,
        limit: MAX_STRING_BYTES,
    })
}
/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    byte_length::DECL,
    character_count::DECL,
    byte_slice::DECL,
    character_slice::DECL,
    character_at::DECL,
    is_empty::DECL,
    contains::DECL,
    starts_with::DECL,
    ends_with::DECL,
    byte_index_of::DECL,
    split::DECL,
    lines::DECL,
    join::DECL,
    trim::DECL,
    replace::DECL,
    repeat::DECL,
    characters::DECL,
    from_characters::DECL,
];

builtin! {
    /// `String.toUppercase` の本体。各文字の地域に依らない大文字への対応を連結する（設計書 03-06「String」）。
    name = "String.toUppercase",
    pure fn to_uppercase(ctx, s: &'c str) -> Value<'e> {
        checked_case_len(
            s.chars().flat_map(char::to_uppercase).map(char::len_utf8),
            "String.toUppercase",
        )?;
        let mut buf = StrBuf::new("String.toUppercase");
        for c in s.chars().flat_map(char::to_uppercase) {
            buf.push_char(c)?;
        }
        ctx.alloc_str_buf(buf)
    }
}

builtin! {
    /// `String.toLowercase` の本体。`str::to_lowercase` で語末のシグマも変換する（設計書 03-06「String」）。
    name = "String.toLowercase",
    pure fn to_lowercase(ctx, s: &'c str) -> Value<'e> {
        // 語末の判定は Rust に任せ、言語の値を確保する前に結果のバイト数を確かめる（実装プラン L01「手順の要点」）。
        let lower = s.to_lowercase();
        checked_case_len([lower.len()], "String.toLowercase")?;
        let mut buf = StrBuf::new("String.toLowercase");
        buf.push_str(&lower)?;
        ctx.alloc_str_buf(buf)
    }
}

// 複数文字への展開後の UTF-8 のバイト数を合計してから構築する（設計書 02-09「一つの操作で作る値の大きさの上限」）。
fn checked_case_len(
    lengths: impl IntoIterator<Item = usize>,
    function: &'static str,
) -> Result<CheckedLen, Stop> {
    let size = lengths.into_iter().try_fold(0u64, |size, len| {
        size.checked_add(super::count(len)?)
            .ok_or_else(|| too_large(function))
    })?;
    CheckedLen::bytes(size, function)
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const UNICODE_DECLS: &[BuiltinDecl] = &[to_uppercase::DECL, to_lowercase::DECL];

builtin! {
    /// `String.toUTF8` の本体（実装プラン 10-15「項目の一覧」）。
    name = "String.toUTF8",
    pure fn to_u_t_f8(ctx, s: &'c str) -> Value<'e> {
        ctx.alloc_bytes(s.as_bytes(), "String.toUTF8")
    }
}

builtin! {
    /// `String.fromUTF8` の本体（実装プラン 10-15「項目の一覧」）。
    name = "String.fromUTF8",
    pure fn from_u_t_f8(ctx, b: &'c [u8]) -> Value<'e> {
        // UTF-8 の検査を公開 API に集め、BOM もそのまま残す（設計書 03-06「Bytes と ByteOrder」）。
        super::option(&ctx, ctx.alloc_str_utf8(b, "String.fromUTF8")?)
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const UTF8_DECLS: &[BuiltinDecl] = &[to_u_t_f8::DECL, from_u_t_f8::DECL];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used)]
    // 関門: 文字列の変換結果を守る。複数文字への展開と語末シグマの欠落を捕まえ、
    // 既存の位置・分割のテストとは重ならない。長さ計算の直接のテストは L01 の個別指示に従う。
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::runtime::heap::{Heap, HeapConfig};

    #[test]
    fn unicode_string_case_mappings() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (s, upper, lower) in [
                ("", "", ""),
                ("aB1", "AB1", "ab1"),
                ("straße", "STRASSE", "straße"),
                ("İ", "İ", "i\u{307}"),
                ("ΣΑΣ", "ΣΑΣ", "σας"),
                ("ΑΣ ΑΣΑ", "ΑΣ ΑΣΑ", "ας ασα"),
                ("éΩ中", "ÉΩ中", "éω中"),
            ] {
                let value = direct!(ctx, to_uppercase, s).unwrap();
                assert_eq!(ctx.str(value), Some(upper));
                let value = direct!(ctx, to_lowercase, s).unwrap();
                assert_eq!(ctx.str(value), Some(lower));
            }
        });
    }

    #[test]
    fn unicode_case_lengths_check_byte_limit_without_large_allocations() {
        let limit = usize::try_from(MAX_STRING_BYTES).unwrap();
        for function in ["String.toUppercase", "String.toLowercase"] {
            assert_eq!(checked_case_len([0], function).unwrap().get(), 0);
            assert_eq!(checked_case_len([1, 2, 4], function).unwrap().get(), 7);
            assert_eq!(
                u64::from(checked_case_len([limit], function).unwrap().get()),
                MAX_STRING_BYTES
            );
            assert!(matches!(
                checked_case_len([limit, 1], function),
                Err(Stop::Resource(ResourceError::ValueTooLarge { .. }))
            ));
            assert!(checked_case_len([usize::MAX, 1], function).is_err());
        }
    }

    // 関門: UTF-8 の本体での変換・None・BOM の保存を守る。ヒープのテストは
    // この組み込みの返す Option と文字列の接続を通らない。公開範囲は増やさない。
    #[test]
    fn utf8_conversion_preserves_bytes_and_bom_and_rejects_invalid_input() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let call = crate::builtins::iface::CallCtx::new(ctx, None, None, None);
            let pure = call.pure_ctx();
            let ctx = pure.values();
            for (text, bytes) in [
                ("", &[][..]),
                ("a", &[0x61][..]),
                ("é", &[0xc3, 0xa9][..]),
                ("\u{feff}é", &[0xef, 0xbb, 0xbf, 0xc3, 0xa9][..]),
                ("中😀", &[0xe4, 0xb8, 0xad, 0xf0, 0x9f, 0x98, 0x80][..]),
            ] {
                let value = to_u_t_f8(pure, text).unwrap();
                assert_eq!(ctx.bytes(value), Some(bytes));
                let option = from_u_t_f8(pure, ctx.bytes(value).unwrap()).unwrap();
                assert_eq!(
                    ctx.fields_header(option),
                    Some((
                        crate::runtime::heap::FieldsKind::Ctor,
                        crate::builtins::table::tags::OPTION_SOME
                    ))
                );
                assert_eq!(ctx.str(ctx.field(option, 0).unwrap()), Some(text));
            }
            for bytes in [
                &[0xff][..],
                &[0xc3][..],
                &[0xe4, 0xb8][..],
                &[0xf0, 0x9f, 0x98][..],
                &[0xc0, 0x80][..],
                &[0xed, 0xa0, 0x80][..],
                &[0x80][..],
            ] {
                assert!(matches!(
                    from_u_t_f8(pure, bytes).unwrap(),
                    Value::Tag(crate::runtime::heap::CtorTag(
                        crate::builtins::table::tags::OPTION_NONE
                    ))
                ));
            }
            let long = "é".repeat(4096);
            let bytes = to_u_t_f8(pure, long.as_str()).unwrap();
            assert_eq!(ctx.bytes(bytes).unwrap().len(), 8192);
            let option = from_u_t_f8(pure, ctx.bytes(bytes).unwrap()).unwrap();
            assert_eq!(ctx.str(ctx.field(option, 0).unwrap()), Some(long.as_str()));
        });
    }
}
