//! SHA-256 のハッシュ値（設計書 03-08「Hash」）。

use sha2::{Digest, Sha256};

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

builtin! {
    /// SHA-256 の 32 バイトのハッシュ値を返す（設計書 03-08「Hash」）。
    name = "Hash.sha256",
    pure fn sha256(ctx, data: &'c [u8]) -> Value<'e> {
        ctx.alloc_bytes(Sha256::digest(data).as_slice(), "Hash.sha256")
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[sha256::DECL];

#[cfg(test)]
mod tests {
    // 既知の値との比較で、別のハッシュ算法や表記文字列を返す退行を捕まえる。
    // Hash の本体を確かめる既存のテストはない。包みを通し、差し込み口を加えない
    // （test-audit の作成時の関門）。テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used, clippy::panic)]

    use super::*;
    use crate::builtins::iface::Reply;
    use crate::builtins::table::call_builtin;
    use crate::runtime::heap::{Heap, HeapConfig};

    #[test]
    fn sha256_empty_and_abc_match_known_digests() {
        // 算法: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf
        // abc の値は次の NIST の例の Message Digest と照合した。
        // https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/SHA256.pdf
        // 空の入力と abc の値は、作業中に printf '' / printf 'abc' をそれぞれ
        // shasum -a 256 に渡して確認した（実装プラン L25「受け入れテスト」）。
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (input, expected) in [
                (
                    &b""[..],
                    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                ),
                (
                    &b"abc"[..],
                    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                ),
            ] {
                let arg = ctx.alloc_bytes(input, "test").unwrap();
                let Reply::Done(value) =
                    call_builtin(&sha256::DECL, ctx, None, None, None, &[arg]).unwrap()
                else {
                    panic!("expected pure result");
                };
                let bytes = ctx.bytes(value).unwrap();
                assert_eq!(bytes.len(), 32);
                let hex = bytes.iter().map(|b| format!("{b:02x}")).collect::<String>();
                assert_eq!(hex, expected);
            }
        });
    }
}
