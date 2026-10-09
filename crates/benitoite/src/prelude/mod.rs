//! 標準ライブラリのソース（設計書 02-04「標準ライブラリのソースの持ち方」、03-06「標準ライブラリのソースの書き方」、
//! ADR 0128・0157）。`stdlib/` の下のソースを `include_str!` で処理系に埋め込む。
//! 表示名 `<benitoite>/X/Y.bnt` は、読み込みの段が `path` から組み立てる（実装プラン 10-04「読み込みの段」）。

use crate::modules::StdlibModuleSource;

/// 処理系に埋め込んだ標準ライブラリのモジュール（実装プラン 10-14「モジュールの一覧」）。
/// 読み込みの段は、prelude のモジュールをこの順にソースの表に置く。項目は末尾にだけ加える。
pub const STDLIB: &[StdlibModuleSource] = &[
    StdlibModuleSource {
        path: &["Integer"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Integer.bnt"),
    },
    StdlibModuleSource {
        path: &["Float"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Float.bnt"),
    },
    StdlibModuleSource {
        path: &["Decimal"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Decimal.bnt"),
    },
    StdlibModuleSource {
        path: &["RoundingMode"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/RoundingMode.bnt"),
    },
    StdlibModuleSource {
        path: &["Byte"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Byte.bnt"),
    },
    StdlibModuleSource {
        path: &["Character"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Character.bnt"),
    },
    StdlibModuleSource {
        path: &["String"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/String.bnt"),
    },
    StdlibModuleSource {
        path: &["Boolean"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Boolean.bnt"),
    },
    StdlibModuleSource {
        path: &["List"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/List.bnt"),
    },
    StdlibModuleSource {
        path: &["Map"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Map.bnt"),
    },
    StdlibModuleSource {
        path: &["Set"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Set.bnt"),
    },
    StdlibModuleSource {
        path: &["Option"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Option.bnt"),
    },
    StdlibModuleSource {
        path: &["Result"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Result.bnt"),
    },
    StdlibModuleSource {
        path: &["Pair"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Pair.bnt"),
    },
    StdlibModuleSource {
        path: &["Triple"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Triple.bnt"),
    },
    StdlibModuleSource {
        path: &["IOError"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/IOError.bnt"),
    },
    StdlibModuleSource {
        path: &["IOErrorKind"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/IOErrorKind.bnt"),
    },
    StdlibModuleSource {
        path: &["Reference"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Reference.bnt"),
    },
    StdlibModuleSource {
        path: &["Lazy"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Lazy.bnt"),
    },
    StdlibModuleSource {
        path: &["Task"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Task.bnt"),
    },
    StdlibModuleSource {
        path: &["TaskGroup"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/TaskGroup.bnt"),
    },
    StdlibModuleSource {
        path: &["IO"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/IO.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Clock"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Clock.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Console"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Console.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "File"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/File.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Process"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Process.bnt"),
    },
    StdlibModuleSource {
        path: &["Trait"],
        prelude: false,
        unofficial: false,
        text: include_str!("stdlib/Trait.bnt"),
    },
    StdlibModuleSource {
        path: &["Assert"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Assert.bnt"),
    },
    StdlibModuleSource {
        path: &["Bytes"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Bytes.bnt"),
    },
    StdlibModuleSource {
        path: &["ByteOrder"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/ByteOrder.bnt"),
    },
    StdlibModuleSource {
        path: &["NetworkError"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/NetworkError.bnt"),
    },
    StdlibModuleSource {
        path: &["NetworkErrorKind"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/NetworkErrorKind.bnt"),
    },
    StdlibModuleSource {
        path: &["Time"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Time.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Random"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Random.bnt"),
    },
    StdlibModuleSource {
        path: &["Path"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Path.bnt"),
    },
    StdlibModuleSource {
        path: &["Json"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Json.bnt"),
    },
    StdlibModuleSource {
        path: &["Regex"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Regex.bnt"),
    },
    StdlibModuleSource {
        path: &["Csv"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Csv.bnt"),
    },
    StdlibModuleSource {
        path: &["Encoding"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Encoding.bnt"),
    },
    StdlibModuleSource {
        path: &["Hash"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Hash.bnt"),
    },
    StdlibModuleSource {
        path: &["Network", "Http"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Network/Http.bnt"),
    },
];
