//! Base64 の符号化と復号（設計書 03-08「Encoding」）。

use base64::Engine;
use base64::engine::general_purpose::{GeneralPurpose, STANDARD, URL_SAFE_NO_PAD};

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::{CheckedLen, FieldsKind, StrBuf, Value, ValueCtx};

builtin! {
    /// 標準の文字の表で詰め物付きの Base64 にする（設計書 03-08「Encoding」）。
    name = "Encoding.base64Encode",
    pure fn base64_encode(ctx, data: &'c [u8]) -> Value<'e> {
        encode(&ctx, data, &STANDARD, true, "Encoding.base64Encode")
    }
}

builtin! {
    /// 標準の文字の表と正しい詰め物の Base64 を読む（設計書 03-08「Encoding」）。
    name = "Encoding.base64Decode",
    pure fn base64_decode(ctx, source: &'c str) -> Value<'e> {
        decode(&ctx, source, &STANDARD, "Encoding.base64Decode")
    }
}

builtin! {
    /// URL 用の文字の表で詰め物なしの Base64 にする（設計書 03-08「Encoding」）。
    name = "Encoding.base64UrlEncode",
    pure fn base64_url_encode(ctx, data: &'c [u8]) -> Value<'e> {
        encode(&ctx, data, &URL_SAFE_NO_PAD, false, "Encoding.base64UrlEncode")
    }
}

builtin! {
    /// URL 用の文字の表で詰め物なしの Base64 を読む（設計書 03-08「Encoding」）。
    name = "Encoding.base64UrlDecode",
    pure fn base64_url_decode(ctx, source: &'c str) -> Value<'e> {
        decode(&ctx, source, &URL_SAFE_NO_PAD, "Encoding.base64UrlDecode")
    }
}

fn encode<'e>(
    ctx: &ValueCtx<'e>,
    data: &[u8],
    engine: &GeneralPurpose,
    padding: bool,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let len = base64::encoded_len(data.len(), padding)
        .map(super::count)
        .transpose()?
        .unwrap_or(u64::MAX);
    CheckedLen::bytes(len, function)?;
    let mut buf = StrBuf::new(function);
    let mut chunk = [0u8; 1024];
    // 3 バイト境界で分け、途中に詰め物が入らないようにする。全体の長さを確かめた後、
    // 固定の作業領域から上限付きの構築器へ書く（実装プラン L25「手順の要点」）。
    for bytes in data.chunks(768) {
        let written = engine
            .encode_slice(bytes, &mut chunk)
            .map_err(|e| Stop::Internal(format!("Base64 chunk does not fit buffer: {e}")))?;
        let encoded = chunk
            .get(..written)
            .ok_or_else(|| Stop::Internal("Base64 output length exceeds buffer".into()))?;
        let encoded = std::str::from_utf8(encoded)
            .map_err(|e| Stop::Internal(format!("Base64 output is not UTF-8: {e}")))?;
        buf.push_str(encoded)?;
    }
    ctx.alloc_str_buf(buf)
}

fn decode<'e>(
    ctx: &ValueCtx<'e>,
    source: &str,
    engine: &GeneralPurpose,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    // 復号した値は入力より短く、alloc_bytes が上限を確かめる
    // （実装プラン L25「手順の要点」）。
    let (tag, value) = match engine.decode(source) {
        Ok(bytes) => (tags::RESULT_OK, ctx.alloc_bytes(&bytes, function)?),
        Err(_) => (
            tags::RESULT_ERROR,
            ctx.alloc_str(text::INVALID_BASE64, function)?,
        ),
    };
    ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
}

mod text {
    pub(super) const INVALID_BASE64: &str = "invalid Base64 encoding";
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    base64_encode::DECL,
    base64_decode::DECL,
    base64_url_encode::DECL,
    base64_url_decode::DECL,
];

#[cfg(test)]
mod tests {
    // L25 の契約を登録済みの包みから確かめる。表と詰め物の取り違え、入力を寛容に読む
    // 変更、途中に詰め物を入れる退行を捕まえる。既存のテストに Encoding の振る舞いはない。
    // テストの失敗は panic で表す（実装プラン 00-02、test-audit の作成時の関門）。
    #![allow(clippy::unwrap_used, clippy::panic)]

    use super::*;
    use crate::builtins::iface::Reply;
    use crate::builtins::table::call_builtin;
    use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx};

    fn invoke<'e>(ctx: &mut NoGcCtx<'e>, decl: BuiltinDecl, arg: Value<'e>) -> Value<'e> {
        let Reply::Done(value) = call_builtin(&decl, ctx, None, None, None, &[arg]).unwrap() else {
            panic!("expected pure result");
        };
        value
    }

    fn payload<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, tag: u32) -> Value<'e> {
        assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, tag)));
        assert_eq!(ctx.fields_len(value), Some(1));
        ctx.field(value, 0).unwrap()
    }

    #[test]
    fn rfc4648_vectors_and_url_alphabet() {
        // https://www.rfc-editor.org/rfc/rfc4648.html#section-10 を作業中に確認した。
        // URL 用の最後の例は、同文書の 4・5 節の表で 62・63 の文字を確認した。
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (bytes, standard, url) in [
                (&b""[..], "", ""),
                (&b"f"[..], "Zg==", "Zg"),
                (&b"fo"[..], "Zm8=", "Zm8"),
                (&b"foo"[..], "Zm9v", "Zm9v"),
                (&b"foob"[..], "Zm9vYg==", "Zm9vYg"),
                (&b"fooba"[..], "Zm9vYmE=", "Zm9vYmE"),
                (&b"foobar"[..], "Zm9vYmFy", "Zm9vYmFy"),
                (&[0xfb, 0xff][..], "+/8=", "-_8"),
            ] {
                for (encoder, decoder, expected) in [
                    (base64_encode::DECL, base64_decode::DECL, standard),
                    (base64_url_encode::DECL, base64_url_decode::DECL, url),
                ] {
                    let arg = ctx.alloc_bytes(bytes, "test").unwrap();
                    let encoded = invoke(ctx, encoder, arg);
                    assert_eq!(ctx.str(encoded), Some(expected));
                    // 復号の期待値を符号化器から作らず、独立した試験値を渡す。
                    let arg = ctx.alloc_str(expected, "test").unwrap();
                    let decoded = invoke(ctx, decoder, arg);
                    let decoded = payload(ctx, decoded, tags::RESULT_OK);
                    assert_eq!(ctx.bytes(decoded), Some(bytes));
                }
            }
        });
    }

    #[test]
    fn decoding_rejects_padding_whitespace_alphabet_and_length_errors() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (decoder, inputs) in [
                (
                    base64_decode::DECL,
                    &[
                        "Zg", "Zm8", "Zg=", "Zg===", "=Zg=", "Z g==", " Zg==", "Zg==\n", "Zm\t9v",
                        "Zm9v\r\n", "????", "-_8=", "Z", "Zm9vA", "Zh==", "é",
                    ][..],
                ),
                (
                    base64_url_decode::DECL,
                    &[
                        "Zg==", "Zm8=", "-_8=", "+/8", "Z g", "Zg\n", "????", "Z", "Zh", "é",
                    ][..],
                ),
            ] {
                for source in inputs {
                    let arg = ctx.alloc_str(source, "test").unwrap();
                    let result = invoke(ctx, decoder, arg);
                    let reason = payload(ctx, result, tags::RESULT_ERROR);
                    assert!(ctx.str(reason).is_some_and(|s| !s.is_empty()), "{source:?}");
                }
            }
        });
    }

    #[test]
    fn encoding_long_inputs_keeps_only_final_padding() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for tail in ["", "a", "aa"] {
                let input = format!("{}{tail}", "aaa".repeat(1024));
                for (encoder, decoder, suffix) in [
                    (
                        base64_encode::DECL,
                        base64_decode::DECL,
                        match tail {
                            "a" => "YQ==",
                            "aa" => "YWE=",
                            _ => "",
                        },
                    ),
                    (
                        base64_url_encode::DECL,
                        base64_url_decode::DECL,
                        match tail {
                            "a" => "YQ",
                            "aa" => "YWE",
                            _ => "",
                        },
                    ),
                ] {
                    let arg = ctx.alloc_bytes(input.as_bytes(), "test").unwrap();
                    let encoded = invoke(ctx, encoder, arg);
                    let expected = format!("{}{suffix}", "YWFh".repeat(1024));
                    assert_eq!(ctx.str(encoded), Some(expected.as_str()));
                    let decoded = invoke(ctx, decoder, encoded);
                    let decoded = payload(ctx, decoded, tags::RESULT_OK);
                    assert_eq!(ctx.bytes(decoded), Some(input.as_bytes()));
                }
            }
        });
    }
}
