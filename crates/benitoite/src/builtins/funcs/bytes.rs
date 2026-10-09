//! 変更できないバイト列の構築・変換・整数の読み書き（設計書 03-06「Bytes と ByteOrder（初回リリース版）」）。

use crate::builtins::iface::{BuiltinDecl, PureCtx, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, CtorTag, StrBuf, Value};
use crate::runtime::{Stop, list};

builtin! {
    /// 空のバイト列を作る（実装プラン 10-15「Bytes」）。
    name = "Bytes.empty",
    pure fn empty(ctx) -> Value<'e> {
        ctx.alloc_bytes(&[], "Bytes.empty")
    }
}

builtin! {
    /// Byte のリストをバイト列にする（実装プラン 10-15「Bytes」）。
    name = "Bytes.fromList",
    pure fn from_list(ctx, xs: Value<'e>) -> Value<'e> {
        CheckedLen::bytes(u64::from(list::len(&ctx, xs)?), "Bytes.fromList")?;
        let bytes = list::to_vec(&ctx, xs)?.into_iter().map(|v| {
            v.as_byte().ok_or_else(|| Stop::Internal("Bytes.fromList expected Byte elements".into()))
        }).collect::<Result<Vec<_>, _>>()?;
        ctx.alloc_bytes(&bytes, "Bytes.fromList")
    }
}

builtin! {
    /// Integer の各要素が Byte の範囲に収まればバイト列にする（実装プラン 10-15「Bytes」）。
    name = "Bytes.fromIntegers",
    pure fn from_integers(ctx, xs: Value<'e>) -> Value<'e> {
        let len = list::len(&ctx, xs)?;
        CheckedLen::bytes(u64::from(len), "Bytes.fromIntegers")?;
        let items = list::to_vec(&ctx, xs)?;
        let mut bytes = Vec::with_capacity(items.len());
        for value in items {
            let n = value.as_int().ok_or_else(|| Stop::Internal("Bytes.fromIntegers expected Integer elements".into()))?;
            let Ok(byte) = u8::try_from(n) else {
                return super::option(&ctx, None);
            };
            bytes.push(byte);
        }
        super::option(&ctx, Some(ctx.alloc_bytes(&bytes, "Bytes.fromIntegers")?))
    }
}

builtin! {
    /// 区切りを除いた 16 進数をバイト列にする（実装プラン 10-15「Bytes」）。
    name = "Bytes.fromHex",
    pure fn from_hex(ctx, s: &'c str) -> Value<'e> {
        parse_digits(ctx, s, 4, 2, "Bytes.fromHex")
    }
}

builtin! {
    /// 区切りを除いた 2 進数をバイト列にする（実装プラン 10-15「Bytes」）。
    name = "Bytes.fromBinary",
    pure fn from_binary(ctx, s: &'c str) -> Value<'e> {
        parse_digits(ctx, s, 1, 8, "Bytes.fromBinary")
    }
}

builtin! {
    /// バイト列を Byte のリストにする（実装プラン 10-15「Bytes」）。
    name = "Bytes.toList",
    pure fn to_list(ctx, b: &'c [u8]) -> Value<'e> {
        CheckedLen::elements(super::count(b.len())?, "Bytes.toList")?;
        let items = b.iter().copied().map(Value::Byte).collect::<Vec<_>>();
        list::from_values(&ctx, &items, "Bytes.toList")
    }
}

builtin! {
    /// 各バイトを小文字の 16 進 2 桁で表す（実装プラン 10-15「Bytes」）。
    name = "Bytes.toHex",
    pure fn to_hex(ctx, b: &'c [u8]) -> Value<'e> {
        checked_encoded_len(super::count(b.len())?, 2, "Bytes.toHex")?;
        let mut buf = StrBuf::new("Bytes.toHex");
        for byte in b {
            for digit in [byte >> 4, byte & 0x0f] {
                let c = char::from(if digit < 10 { b'0'.saturating_add(digit) } else { b'a'.saturating_add(digit.saturating_sub(10)) });
                buf.push_char(c)?;
            }
        }
        ctx.alloc_str_buf(buf)
    }
}

builtin! {
    /// 各バイトを 2 進 8 桁で表す（実装プラン 10-15「Bytes」）。
    name = "Bytes.toBinary",
    pure fn to_binary(ctx, b: &'c [u8]) -> Value<'e> {
        checked_encoded_len(super::count(b.len())?, 8, "Bytes.toBinary")?;
        let mut buf = StrBuf::new("Bytes.toBinary");
        for byte in b {
            for shift in (0..8).rev() {
                buf.push_char(if (byte >> shift) & 1 == 0 { '0' } else { '1' })?;
            }
        }
        ctx.alloc_str_buf(buf)
    }
}

builtin! {
    /// バイト数を返す（実装プラン 10-15「Bytes」）。
    name = "Bytes.length",
    pure fn length(ctx, b: &'c [u8]) -> i64 {
        let _ = ctx;
        super::integer_count(b.len())
    }
}

builtin! {
    /// 範囲内の位置の Byte を返す（実装プラン 10-15「Bytes」）。
    name = "Bytes.get",
    pure fn get(ctx, b: &'c [u8], i: i64) -> Value<'e> {
        super::option(&ctx, usize::try_from(i).ok().and_then(|i| b.get(i)).copied().map(Value::Byte))
    }
}

builtin! {
    /// 正しい範囲なら部分のバイト列を写して作る（実装プラン 10-15「Bytes」の表現の例外）。
    name = "Bytes.slice",
    pure fn slice(ctx, b: &'c [u8], start: i64, stop: i64) -> Value<'e> {
        let bytes = match (usize::try_from(start), usize::try_from(stop)) {
            (Ok(start), Ok(stop)) => b.get(start..stop),
            _ => None,
        };
        super::option(&ctx, bytes.map(|b| ctx.alloc_bytes(b, "Bytes.slice")).transpose()?)
    }
}

builtin! {
    /// 合計の大きさを確かめてから二つのバイト列を連結する（実装プラン 10-15「Bytes」）。
    name = "Bytes.concatenate",
    pure fn concatenate(ctx, a: &'c [u8], b: &'c [u8]) -> Value<'e> {
        let len = checked_concat_len(super::count(a.len())?, super::count(b.len())?)?;
        ctx.alloc_bytes_with(len, |out| {
            for (dst, src) in out.iter_mut().zip(a.iter().chain(b)) {
                *dst = *src;
            }
        })
    }
}

builtin! {
    /// 範囲内のバイト列を符号なしの Integer として読む（実装プラン 10-15「Bytes」）。
    name = "Bytes.readUnsigned",
    pure fn read_unsigned(ctx, b: &'c [u8], offset: i64, count: i64, order: Value<'e>) -> Value<'e> {
        let big = big_endian(order)?;
        let n = read_integer(b, offset, count, big, false).and_then(|n| i64::try_from(u64::from_be_bytes(n)).ok());
        super::option(&ctx, n.map(Value::Int))
    }
}

builtin! {
    /// 範囲内のバイト列を 2 の補数の Integer として読む（実装プラン 10-15「Bytes」）。
    name = "Bytes.readSigned",
    pure fn read_signed(ctx, b: &'c [u8], offset: i64, count: i64, order: Value<'e>) -> Value<'e> {
        let big = big_endian(order)?;
        let n = read_integer(b, offset, count, big, true).map(i64::from_be_bytes);
        super::option(&ctx, n.map(Value::Int))
    }
}

builtin! {
    /// 非負の Integer が指定した幅に収まればバイト列にする（実装プラン 10-15「Bytes」）。
    name = "Bytes.fromUnsigned",
    pure fn from_unsigned(ctx, n: i64, count: i64, order: Value<'e>) -> Value<'e> {
        write_integer(ctx, n, count, order, false, "Bytes.fromUnsigned")
    }
}

builtin! {
    /// Integer が指定した符号付きの幅に収まればバイト列にする（実装プラン 10-15「Bytes」）。
    name = "Bytes.fromSigned",
    pure fn from_signed(ctx, n: i64, count: i64, order: Value<'e>) -> Value<'e> {
        write_integer(ctx, n, count, order, true, "Bytes.fromSigned")
    }
}

// L03 の個別指示に従い、巨大な値を確保せず長さの計算を確かめられる形にする。
fn checked_encoded_len(len: u64, width: u64, function: &'static str) -> Result<CheckedLen, Stop> {
    CheckedLen::bytes(len.saturating_mul(width), function)
}

fn checked_concat_len(a: u64, b: u64) -> Result<CheckedLen, Stop> {
    CheckedLen::bytes(a.saturating_add(b), "Bytes.concatenate")
}

fn separator(b: u8) -> bool {
    matches!(b, b'_' | b' ')
}

fn digit(b: u8, bits: u32) -> Option<u8> {
    match b {
        b'0'..=b'1' => Some(b.saturating_sub(b'0')),
        b'2'..=b'9' if bits == 4 => Some(b.saturating_sub(b'0')),
        b'a'..=b'f' if bits == 4 => Some(b.saturating_sub(b'a').saturating_add(10)),
        b'A'..=b'F' if bits == 4 => Some(b.saturating_sub(b'A').saturating_add(10)),
        _ => None,
    }
}

fn parse_digits<'e>(
    ctx: PureCtx<'_, 'e>,
    s: &str,
    bits: u32,
    width: usize,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut count = 0u64;
    for b in s.bytes().filter(|b| !separator(*b)) {
        if digit(b, bits).is_none() {
            return super::option(&ctx, None);
        }
        count = count
            .checked_add(1)
            .ok_or_else(|| Stop::Internal("digit count does not fit u64".into()))?;
    }
    let width_u64 = super::count(width)?;
    if !count.is_multiple_of(width_u64) {
        return super::option(&ctx, None);
    }
    let len = count
        .checked_div(width_u64)
        .ok_or_else(|| Stop::Internal("zero digit width".into()))?;
    let len = CheckedLen::bytes(len, function)?;
    // 入力と桁数を先に検査したため、確保後は失敗せず順に書ける（設計書 03-06「Bytes と ByteOrder」）。
    let value = ctx.alloc_bytes_with(len, |out| {
        let mut digits = s.bytes().filter_map(|b| digit(b, bits));
        for byte in out {
            *byte = digits
                .by_ref()
                .take(width)
                .fold(0u8, |acc, d| acc.wrapping_shl(bits) | d);
        }
    })?;
    super::option(&ctx, Some(value))
}

fn big_endian(order: Value<'_>) -> Result<bool, Stop> {
    match order {
        Value::Tag(CtorTag(tags::BYTE_ORDER_BIG_ENDIAN)) => Ok(true),
        Value::Tag(CtorTag(tags::BYTE_ORDER_LITTLE_ENDIAN)) => Ok(false),
        Value::Tag(_)
        | Value::Int(_)
        | Value::Float(_)
        | Value::Byte(_)
        | Value::Bool(_)
        | Value::Char(_)
        | Value::Unit
        | Value::Resource(_)
        | Value::EmptyList
        | Value::EmptyMap
        | Value::EmptySet
        | Value::Obj(_) => Err(Stop::Internal("expected ByteOrder constructor".into())),
    }
}

fn byte_count(count: i64) -> Option<usize> {
    (1..=8)
        .contains(&count)
        .then(|| usize::try_from(count).ok())
        .flatten()
}

// 常に上位のバイトが先の 8 バイトに揃える。符号付きでは最上位のビットで埋める。
fn read_integer(b: &[u8], offset: i64, count: i64, big: bool, signed: bool) -> Option<[u8; 8]> {
    let count = byte_count(count)?;
    let start = usize::try_from(offset).ok()?;
    let bytes = b.get(start..start.checked_add(count)?)?;
    let high = if big { bytes.first()? } else { bytes.last()? };
    let mut out = [if signed && high & 0x80 != 0 { 0xff } else { 0 }; 8];
    if big {
        for (dst, src) in out.iter_mut().rev().zip(bytes.iter().rev()) {
            *dst = *src;
        }
    } else {
        for (dst, src) in out.iter_mut().rev().zip(bytes) {
            *dst = *src;
        }
    }
    Some(out)
}

fn write_integer<'e>(
    ctx: PureCtx<'_, 'e>,
    n: i64,
    count: i64,
    order: Value<'e>,
    signed: bool,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let big = big_endian(order)?;
    let Some(count) = byte_count(count) else {
        return super::option(&ctx, None);
    };
    let bytes = n.to_be_bytes();
    let start = 8usize
        .checked_sub(count)
        .ok_or_else(|| Stop::Internal("integer byte count exceeds eight".into()))?;
    let bytes = bytes
        .get(start..)
        .ok_or_else(|| Stop::Internal("integer byte range missing".into()))?;
    // 読み直して値の一致を確かめることで、8 バイトの幅でもシフトの溢れを起こさない。
    let read_back = read_integer(
        bytes,
        0,
        i64::try_from(count)
            .map_err(|_| Stop::Internal("byte count does not fit Integer".into()))?,
        true,
        signed,
    )
    .ok_or_else(|| Stop::Internal("validated integer bytes cannot be read".into()))?;
    if (!signed && n < 0) || i64::from_be_bytes(read_back) != n {
        return super::option(&ctx, None);
    }
    let len = CheckedLen::bytes(super::count(count)?, function)?;
    let value = ctx.alloc_bytes_with(len, |out| {
        if big {
            out.copy_from_slice(bytes);
        } else {
            for (dst, src) in out.iter_mut().zip(bytes.iter().rev()) {
                *dst = *src;
            }
        }
    })?;
    super::option(&ctx, Some(value))
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    empty::DECL,
    from_list::DECL,
    from_integers::DECL,
    from_hex::DECL,
    from_binary::DECL,
    to_list::DECL,
    to_hex::DECL,
    to_binary::DECL,
    length::DECL,
    get::DECL,
    slice::DECL,
    concatenate::DECL,
    read_unsigned::DECL,
    read_signed::DECL,
    from_unsigned::DECL,
    from_signed::DECL,
];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    // 関門: 各本体の返す値・None・符号とバイト順を守る。ヒープや整数のテストは
    // この変換の配線を通らない。直接の呼び出しは ADR 0276、長さの直接検査は L03 の指示。
    // 似た境界は表にまとめ、本番の公開範囲や差し込み口を増やさない。
    use super::*;
    use crate::builtins::iface::CallCtx;
    use crate::runtime::heap::{FieldsKind, Heap, HeapConfig, ValueCtx};
    use crate::runtime::{MAX_STRING_BYTES, ResourceError, SizeUnit};

    macro_rules! call {
        ($ctx:expr, $function:path $(, $arg:expr)* $(,)?) => {
            $function($ctx $(, $arg)*)
        };
    }

    fn option_value<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Option<Value<'e>> {
        if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
            None
        } else {
            assert_eq!(
                ctx.fields_header(value),
                Some((FieldsKind::Ctor, tags::OPTION_SOME))
            );
            assert_eq!(ctx.fields_len(value), Some(1));
            Some(ctx.field(value, 0).unwrap())
        }
    }

    fn bytes_list<'e>(ctx: &ValueCtx<'e>, bytes: &[u8], integer: bool) -> Value<'e> {
        list::from_values(
            ctx,
            &bytes
                .iter()
                .copied()
                .map(|b| {
                    if integer {
                        Value::Int(i64::from(b))
                    } else {
                        Value::Byte(b)
                    }
                })
                .collect::<Vec<_>>(),
            "test",
        )
        .unwrap()
    }

    #[test]
    fn byte_list_construction_and_conversion() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let call = CallCtx::new(ctx, None, None, None);
            let pure = call.pure_ctx();
            let ctx = pure.values();
            assert_eq!(ctx.bytes(call!(pure, empty).unwrap()), Some(&[][..]));
            let long = (0..4096).map(|i| (i % 256) as u8).collect::<Vec<_>>();
            for bytes in [&[][..], &[255][..], &[0, 255][..], &long] {
                let value = call!(pure, from_list, bytes_list(ctx, bytes, false)).unwrap();
                assert_eq!(ctx.bytes(value), Some(bytes));
                assert_eq!(
                    call!(pure, length, ctx.bytes(value).unwrap()).unwrap(),
                    bytes.len() as i64
                );
                let integer_value = option_value(
                    ctx,
                    call!(pure, from_integers, bytes_list(ctx, bytes, true)).unwrap(),
                )
                .unwrap();
                assert_eq!(ctx.bytes(integer_value), Some(bytes));
                let values = list::to_vec(
                    ctx,
                    call!(pure, to_list, ctx.bytes(value).unwrap()).unwrap(),
                )
                .unwrap();
                assert_eq!(
                    values
                        .iter()
                        .map(|v| v.as_byte().unwrap())
                        .collect::<Vec<_>>(),
                    bytes
                );
            }
            for ns in [
                vec![256],
                vec![-1],
                vec![0, 255, 256],
                vec![i64::MIN],
                vec![i64::MAX],
            ] {
                let xs = list::from_values(
                    ctx,
                    &ns.into_iter().map(Value::Int).collect::<Vec<_>>(),
                    "test",
                )
                .unwrap();
                assert!(option_value(ctx, call!(pure, from_integers, xs).unwrap()).is_none());
            }
        });
    }

    #[test]
    fn hex_and_binary_parse_format_and_round_trip() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let call = CallCtx::new(ctx, None, None, None);
            let pure = call.pure_ctx();
            let ctx = pure.values();
            for (s, expected) in [
                ("", &[][..]),
                ("_ __ ", &[][..]),
                ("00", &[0][..]),
                ("DE ad_BE ef", &[0xde, 0xad, 0xbe, 0xef][..]),
                ("f_f", &[255][..]),
            ] {
                let value = option_value(ctx, call!(pure, from_hex, s).unwrap()).unwrap();
                assert_eq!(ctx.bytes(value), Some(expected));
            }
            for (s, expected) in [
                ("", &[][..]),
                ("_ ", &[][..]),
                ("0000_0001 11111111", &[1, 255][..]),
                ("1_1_1_1_1_1_1_1", &[255][..]),
            ] {
                let value = option_value(ctx, call!(pure, from_binary, s).unwrap()).unwrap();
                assert_eq!(ctx.bytes(value), Some(expected));
            }
            for s in [
                "abc", "zz", "0", "0x12", "00\t", "00\n", "ＦＦ", "１２", "é",
            ] {
                assert!(
                    option_value(ctx, call!(pure, from_hex, s).unwrap()).is_none(),
                    "{s:?}"
                );
            }
            for s in [
                "0000000",
                "000000000",
                "00000002",
                "00000000\t",
                "００００００００",
                "11111111\r",
            ] {
                assert!(
                    option_value(ctx, call!(pure, from_binary, s).unwrap()).is_none(),
                    "{s:?}"
                );
            }
            for (bytes, hex, binary) in [
                (&[][..], "", ""),
                (&[0][..], "00", "00000000"),
                (&[1, 255][..], "01ff", "0000000111111111"),
                (
                    &[0xde, 0xad, 0xbe, 0xef][..],
                    "deadbeef",
                    "11011110101011011011111011101111",
                ),
            ] {
                assert_eq!(ctx.str(call!(pure, to_hex, bytes).unwrap()), Some(hex));
                assert_eq!(
                    ctx.str(call!(pure, to_binary, bytes).unwrap()),
                    Some(binary)
                );
            }
            let bytes = (0..4096).map(|i| (i % 256) as u8).collect::<Vec<_>>();
            let hex = call!(pure, to_hex, bytes.as_slice()).unwrap();
            let binary = call!(pure, to_binary, bytes.as_slice()).unwrap();
            // 片方だけが同じ誤りをしても往復で通らないよう、標準の書式とも照合する。
            assert_eq!(
                ctx.str(hex).unwrap(),
                bytes.iter().map(|b| format!("{b:02x}")).collect::<String>()
            );
            assert_eq!(
                ctx.str(binary).unwrap(),
                bytes.iter().map(|b| format!("{b:08b}")).collect::<String>()
            );
            for value in [
                option_value(ctx, call!(pure, from_hex, ctx.str(hex).unwrap()).unwrap()).unwrap(),
                option_value(
                    ctx,
                    call!(pure, from_binary, ctx.str(binary).unwrap()).unwrap(),
                )
                .unwrap(),
            ] {
                assert_eq!(ctx.bytes(value).unwrap(), bytes);
            }
        });
    }

    #[test]
    fn get_slice_boundaries_and_concatenation() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let call = CallCtx::new(ctx, None, None, None);
            let pure = call.pure_ctx();
            let ctx = pure.values();
            for bytes in [&[][..], &[255][..], &[0, 255][..]] {
                let len = bytes.len() as i64;
                for (i, expected) in [
                    (-1, None),
                    (0, bytes.first().copied()),
                    (len - 1, bytes.last().copied()),
                    (len, None),
                    (len + 1, None),
                    (i64::MAX, None),
                ] {
                    let result = option_value(ctx, call!(pure, get, bytes, i).unwrap())
                        .map(|v| v.as_byte().unwrap());
                    assert_eq!(result, expected);
                }
                for (start, stop, expected) in [
                    (0, 0, Some(&[][..])),
                    (0, len, Some(bytes)),
                    (len, len, Some(&[][..])),
                    (-1, len, None),
                    (0, -1, None),
                    (1, 0, None),
                    (0, len + 1, None),
                    (len + 1, len + 1, None),
                    (0, i64::MAX, None),
                ] {
                    let result = option_value(ctx, call!(pure, slice, bytes, start, stop).unwrap());
                    assert_eq!(result.map(|v| ctx.bytes(v).unwrap()), expected);
                }
            }
            let long = vec![0x5a; 4096];
            let suffix = vec![0xff; 4096];
            let joined = call!(pure, concatenate, long.as_slice(), suffix.as_slice()).unwrap();
            let expected = long.iter().chain(&suffix).copied().collect::<Vec<_>>();
            assert_eq!(ctx.bytes(joined).unwrap(), expected);
            let part = option_value(
                ctx,
                call!(pure, slice, ctx.bytes(joined).unwrap(), 4096, 8192).unwrap(),
            )
            .unwrap();
            assert_eq!(ctx.bytes(part).unwrap(), suffix);
            assert_eq!(
                option_value(
                    ctx,
                    call!(pure, get, ctx.bytes(joined).unwrap(), 8191).unwrap()
                )
                .unwrap()
                .as_byte(),
                Some(0xff)
            );
            let source = [0, 1, 2, 255];
            let part = option_value(ctx, call!(pure, slice, &source[..], 1, 3).unwrap()).unwrap();
            assert_eq!(ctx.bytes(part), Some(&[1, 2][..]));
            for (a, b, expected) in [
                (&[][..], &[][..], &[][..]),
                (&[][..], &[1][..], &[1][..]),
                (&[1][..], &[][..], &[1][..]),
                (&[0, 255][..], &[1, 2][..], &[0, 255, 1, 2][..]),
            ] {
                assert_eq!(
                    ctx.bytes(call!(pure, concatenate, a, b).unwrap()),
                    Some(expected)
                );
            }
        });
    }

    #[test]
    fn integers_all_widths_orders_and_limits() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let call = CallCtx::new(ctx, None, None, None);
            let pure = call.pure_ctx();
            let ctx = pure.values();
            for order in [
                Value::Tag(CtorTag(tags::BYTE_ORDER_BIG_ENDIAN)),
                Value::Tag(CtorTag(tags::BYTE_ORDER_LITTLE_ENDIAN)),
            ] {
                let big = matches!(order, Value::Tag(CtorTag(tags::BYTE_ORDER_BIG_ENDIAN)));
                for count in 1..=8i64 {
                    let bits = count * 8;
                    let unsigned_max = if count == 8 {
                        i64::MAX
                    } else {
                        ((1i128 << bits) - 1) as i64
                    };
                    for n in [0, 1, unsigned_max] {
                        let value =
                            option_value(ctx, call!(pure, from_unsigned, n, count, order).unwrap())
                                .unwrap();
                        let bytes = ctx.bytes(value).unwrap();
                        let full = if big {
                            n.to_be_bytes()
                        } else {
                            n.to_le_bytes()
                        };
                        let expected = if big {
                            &full[8 - count as usize..]
                        } else {
                            &full[..count as usize]
                        };
                        assert_eq!(bytes, expected);
                        let got = option_value(
                            ctx,
                            call!(pure, read_unsigned, bytes, 0, count, order).unwrap(),
                        )
                        .unwrap();
                        assert_eq!(got.as_int(), Some(n));
                        let mut padded = vec![99];
                        padded.extend_from_slice(bytes);
                        padded.push(99);
                        let got = option_value(
                            ctx,
                            call!(pure, read_unsigned, padded.as_slice(), 1, count, order).unwrap(),
                        )
                        .unwrap();
                        assert_eq!(got.as_int(), Some(n));
                    }
                    assert!(
                        option_value(ctx, call!(pure, from_unsigned, -1, count, order).unwrap())
                            .is_none()
                    );
                    if count < 8 {
                        assert!(
                            option_value(
                                ctx,
                                call!(pure, from_unsigned, unsigned_max + 1, count, order).unwrap()
                            )
                            .is_none()
                        );
                    }
                    let signed_min = (-(1i128 << (bits - 1))) as i64;
                    let signed_max = ((1i128 << (bits - 1)) - 1) as i64;
                    for n in [signed_min, -1, 0, 1, signed_max] {
                        let value =
                            option_value(ctx, call!(pure, from_signed, n, count, order).unwrap())
                                .unwrap();
                        let bytes = ctx.bytes(value).unwrap();
                        let full = if big {
                            n.to_be_bytes()
                        } else {
                            n.to_le_bytes()
                        };
                        let expected = if big {
                            &full[8 - count as usize..]
                        } else {
                            &full[..count as usize]
                        };
                        assert_eq!(bytes, expected);
                        let got = option_value(
                            ctx,
                            call!(pure, read_signed, bytes, 0, count, order).unwrap(),
                        )
                        .unwrap();
                        assert_eq!(got.as_int(), Some(n));
                    }
                    if count < 8 {
                        for n in [signed_min - 1, signed_max + 1] {
                            assert!(
                                option_value(
                                    ctx,
                                    call!(pure, from_signed, n, count, order).unwrap()
                                )
                                .is_none()
                            );
                        }
                    }
                }
                for count in [i64::MIN, -1, 0, 9, i64::MAX] {
                    assert!(
                        option_value(ctx, call!(pure, from_unsigned, 0, count, order).unwrap())
                            .is_none()
                    );
                    assert!(
                        option_value(ctx, call!(pure, from_signed, 0, count, order).unwrap())
                            .is_none()
                    );
                    assert!(
                        option_value(
                            ctx,
                            call!(pure, read_unsigned, &[0; 8][..], 0, count, order).unwrap()
                        )
                        .is_none()
                    );
                    assert!(
                        option_value(
                            ctx,
                            call!(pure, read_signed, &[0; 8][..], 0, count, order).unwrap()
                        )
                        .is_none()
                    );
                }
                for (offset, count) in [(-1, 1), (8, 1), (9, 1), (1, 8), (i64::MAX, 8)] {
                    assert!(
                        option_value(
                            ctx,
                            call!(pure, read_unsigned, &[0; 8][..], offset, count, order).unwrap()
                        )
                        .is_none()
                    );
                    assert!(
                        option_value(
                            ctx,
                            call!(pure, read_signed, &[0; 8][..], offset, count, order).unwrap()
                        )
                        .is_none()
                    );
                }
                let high = if big {
                    [0x80, 0, 0, 0, 0, 0, 0, 0]
                } else {
                    [0, 0, 0, 0, 0, 0, 0, 0x80]
                };
                assert!(
                    option_value(
                        ctx,
                        call!(pure, read_unsigned, &high[..], 0, 8, order).unwrap()
                    )
                    .is_none()
                );
                assert!(
                    option_value(
                        ctx,
                        call!(pure, read_unsigned, &[255; 8][..], 0, 8, order).unwrap()
                    )
                    .is_none()
                );
                assert_eq!(
                    option_value(
                        ctx,
                        call!(pure, read_signed, &high[..], 0, 8, order).unwrap()
                    )
                    .unwrap()
                    .as_int(),
                    Some(i64::MIN)
                );
                let bytes = if big {
                    &[1, 2, 3, 4][..]
                } else {
                    &[4, 3, 2, 1][..]
                };
                assert_eq!(
                    option_value(ctx, call!(pure, read_unsigned, bytes, 0, 4, order).unwrap())
                        .unwrap()
                        .as_int(),
                    Some(0x01020304)
                );
                assert_eq!(
                    option_value(ctx, call!(pure, read_signed, bytes, 0, 4, order).unwrap())
                        .unwrap()
                        .as_int(),
                    Some(0x01020304)
                );
            }
        });
    }

    #[test]
    fn encoded_and_concatenated_lengths_reject_large_results() {
        for (function, result, size) in [
            (
                "Bytes.concatenate",
                checked_concat_len(MAX_STRING_BYTES, 1),
                MAX_STRING_BYTES + 1,
            ),
            (
                "Bytes.toHex",
                checked_encoded_len(MAX_STRING_BYTES, 2, "Bytes.toHex"),
                MAX_STRING_BYTES * 2,
            ),
            (
                "Bytes.toBinary",
                checked_encoded_len(MAX_STRING_BYTES, 8, "Bytes.toBinary"),
                MAX_STRING_BYTES * 8,
            ),
            (
                "Bytes.concatenate",
                checked_concat_len(u64::MAX, 1),
                u64::MAX,
            ),
            (
                "Bytes.toHex",
                checked_encoded_len(u64::MAX, 2, "Bytes.toHex"),
                u64::MAX,
            ),
        ] {
            assert_eq!(
                result.unwrap_err(),
                Stop::Resource(ResourceError::ValueTooLarge {
                    function,
                    size,
                    unit: SizeUnit::Bytes,
                    limit: MAX_STRING_BYTES,
                })
            );
        }
        assert_eq!(checked_concat_len(2, 3).unwrap().get(), 5);
        assert_eq!(checked_encoded_len(3, 2, "Bytes.toHex").unwrap().get(), 6);
        assert_eq!(
            checked_encoded_len(3, 8, "Bytes.toBinary").unwrap().get(),
            24
        );
    }
}
