//! HTTP の経路を分割し、要素ごとに復号する（設計書 03-09「応答を作る関数と、要求を調べる関数」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::{CheckedLen, Value};

builtin! {
    /// 経路の空の要素を除き、パーセント符号化を戻す（設計書 03-09）。
    /// UTF-8 に戻せない要素と、`%` の後が 16 進の 2 桁でない要素は、
    /// 要素全体をそのまま残す。`+` は空白に変えない（実装プラン L31）。
    name = "Network.Http.pathSegments",
    pure fn path_segments(ctx, path: &'c str) -> Value<'e> {
        let parts = || path.split('/').filter(|part| !part.is_empty());
        CheckedLen::elements(super::count(parts().count())?, "Http.pathSegments")?;
        let mut values = Vec::new();
        for part in parts() {
            let decoded = decode_segment(part);
            values.push(ctx.alloc_str(decoded.as_deref().unwrap_or(part), "Http.pathSegments")?);
        }
        crate::runtime::list::from_values(&ctx, &values, "Http.pathSegments")
    }
}

// 分割してから復号するので、%2F は一つの要素の中の文字になる。
// 一部だけの復号は避け、どこか一か所でも戻せなければ元の要素を保つ（実装プラン L31）。
fn decode_segment(segment: &str) -> Option<String> {
    if !segment.contains('%') {
        return None;
    }
    let mut input = segment.bytes();
    let mut decoded = Vec::with_capacity(segment.len());
    while let Some(byte) = input.next() {
        if byte == b'%' {
            let high = char::from(input.next()?).to_digit(16)?;
            let low = char::from(input.next()?).to_digit(16)?;
            decoded.push(u8::try_from((high << 4) | low).ok()?);
        } else {
            decoded.push(byte);
        }
    }
    String::from_utf8(decoded).ok()
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[path_segments::DECL];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used)]
    // 関門: 分割と要素全体の復号という返す値の契約を守る。空の要素、
    // 不正な UTF-8、不完全な % の復号の退行を捕まえる。既存の表のテストは
    // 本体を呼ばない。差し込み口を足さず、10-15 の指示どおり本体を呼ぶ。
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::runtime::heap::{Heap, HeapConfig};

    #[test]
    fn segments_decode_valid_utf8_and_preserve_entire_invalid_segments() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (input, expected) in [
                ("/", &[][..]),
                ("", &[][..]),
                ("/items/42", &["items", "42"][..]),
                ("//a//b/", &["a", "b"][..]),
                ("/a%20b", &["a b"][..]),
                ("/%E3%81%82", &["あ"][..]),
                ("/%FF", &["%FF"][..]),
                ("/%G0", &["%G0"][..]),
                ("/a+b", &["a+b"][..]),
                ("/%/x%2", &["%", "x%2"][..]),
                ("/a%20%FF/b%20%G0", &["a%20%FF", "b%20%G0"][..]),
                ("/%2f/%2520/あ%20い", &["/", "%20", "あ い"][..]),
            ] {
                let value = direct!(ctx, path_segments, input).unwrap();
                let actual = crate::runtime::list::to_vec(ctx, value).unwrap();
                let actual = actual
                    .iter()
                    .map(|v| ctx.str(*v).unwrap())
                    .collect::<Vec<_>>();
                assert_eq!(actual, expected, "path {input:?}");
            }
        });
    }
}
