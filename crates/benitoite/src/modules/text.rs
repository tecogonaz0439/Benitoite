//! 読み込みの診断に埋め込む理由（設計書 02-02「ソースの大きさの上限」、実装プラン 00-02「文言」）。

pub(super) const SOURCE_TOO_LARGE: &str = "the source file exceeds the size limit of 256 MiB";
pub(super) const TOTAL_TOO_LARGE: &str =
    "the total size of all sources exceeds the size limit of 512 MiB";
