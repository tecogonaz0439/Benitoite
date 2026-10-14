//! SHA-256 の WASM の検証用実装（設計書 03-08「Hash」、03-10「外部の関数」）。

wit_bindgen::generate!({ world: "hash", path: "../wit" });
use sha2::{Digest, Sha256};
struct C;
impl Guest for C {
    fn sha256(data: Vec<u8>) -> Vec<u8> {
        Sha256::digest(&data).to_vec()
    }
    fn sha256_hex(data: Vec<u8>) -> String {
        let d = Sha256::digest(&data);
        let mut s = String::with_capacity(64);
        for b in d {
            s.push_str(&format!("{b:02x}"));
        }
        s
    }
}
export!(C);
