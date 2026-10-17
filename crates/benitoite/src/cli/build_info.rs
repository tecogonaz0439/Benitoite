//! ビルド時に検証・採取した情報を JSON へ写す（設計書 05-01「ソースからのビルド」、
//! 06-01「版と対応する形式の問い合わせ」）。

use serde_json::{Value, json};

/// 各報告に埋め込む処理系の識別情報を返す。
pub(super) fn producer() -> Value {
    json!({ "name": "benitoite", "version": env!("CARGO_PKG_VERSION"), "build": value() })
}

/// 不明値を null とし、値ごとの由来を付けたビルド情報を返す。
pub(super) fn value() -> Value {
    // 実行時の環境や Git の状態は、埋め込んだ自己申告の根拠にはしない。
    let commit = env!("BENITOITE_EMBEDDED_BUILD_COMMIT");
    let dirty = match env!("BENITOITE_EMBEDDED_BUILD_DIRTY") {
        "true" => Some(true),
        "false" => Some(false),
        _ => None,
    };
    json!({
        "commit": (!commit.is_empty()).then_some(commit),
        "dirty": dirty,
        "target": env!("BENITOITE_EMBEDDED_BUILD_TARGET"),
        "provenance": {
            "commit": env!("BENITOITE_EMBEDDED_COMMIT_PROVENANCE"),
            "dirty": env!("BENITOITE_EMBEDDED_DIRTY_PROVENANCE")
        }
    })
}
