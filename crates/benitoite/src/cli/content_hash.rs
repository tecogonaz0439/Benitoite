//! JSON の検査報告・同梱文書に共通する本文の識別（設計書 06-01「main の非実行の検査報告」、
//! 06-06「同梱文書の取得」）。

use serde_json::{Value, json};
use sha2::{Digest, Sha256};

/// 受け取った全バイト列の SHA-256 を小文字の十六進文字列で返す。
pub(super) fn value(bytes: &[u8]) -> Value {
    let value = Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect::<String>();
    json!({ "algorithm": "sha256", "value": value })
}
