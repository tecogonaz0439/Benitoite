//! `benitoite --licenses` の表示（設計書 05-01「ライセンスの表示」、06-01「コマンドラインの形」、ADR 0235）。
//! 第三者のライセンスの表示は、リリースのスクリプトが生成し、機能 `bundled-licenses` のビルドでだけ埋め込む。

/// 表示の文（ADR 0033）。
pub mod text {
    /// 処理系自身のライセンス（ADR 0003）
    pub const OWN_LICENSE: &str = "benitoite is licensed under either of the MIT License or the Apache License, Version 2.0, at your option.\n";
    /// リリースのスクリプトを通さないビルドの文（05-01「ライセンスの表示」）
    pub const NOT_BUNDLED: &str = "This build does not include the list of third-party licenses.\nThe release archives built by scripts/release.sh include it.\n";
    /// 第三者のライセンスの表示の前に置く見出し
    pub const THIRD_PARTY_HEADER: &str = "\nThird-party licenses:\n\n";
}

/// 埋め込んだ `THIRD_PARTY_LICENSES`。機能 `bundled-licenses` のないビルドでは `None`。
pub fn third_party_licenses() -> Option<&'static str> {
    // 生成したファイルはリリースのスクリプトだけが置くので、機能のあるビルドでだけ読む（10-19「第三者のライセンスの表示」）
    #[cfg(feature = "bundled-licenses")]
    {
        Some(include_str!("../../../licenses/THIRD_PARTY_LICENSES"))
    }
    #[cfg(not(feature = "bundled-licenses"))]
    {
        None
    }
}
