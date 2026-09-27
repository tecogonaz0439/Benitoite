//! prelude のソース（設計書 02-04「prelude」）。`include_str!` で処理系に埋め込む。

/// prelude のソースのファイルの名前と内容。ファイルの名前の順に並べる。
/// 読み込みの段は、表示名を `<prelude>/` にファイルの名前を続けたものとしてソースの表に加える。
pub const SOURCES: [(&str, &str); 3] = [
    ("list.bnt", include_str!("list.bnt")),
    ("option.bnt", include_str!("option.bnt")),
    ("result.bnt", include_str!("result.bnt")),
];

/// 表示名の接頭辞。
pub const DISPLAY_PREFIX: &str = "<prelude>/";
