//! ヒープに依存しない正規表現の組み立てと失敗表示（設計書 03-08「Regex」）。

/// 静的検査と実行時で同じ既定設定を使う。
pub(crate) fn compile(source: &str) -> Result<::regex::Regex, ::regex::Error> {
    ::regex::RegexBuilder::new(source).build()
}

mod text {
    pub const ERROR_LIMIT: usize = 4096;
    pub const ERROR_HEADER: &str = "regex parse error:\n";
    pub const ERROR_OMITTED: &str = "(pattern omitted; error message truncated)\n";
}

// 正規表現の全文と位置の表示を省き、誤りの種類を UTF-8 の境目で残す。
// 一時の表示用文字列は上限の対象外である（設計書 03-08「Regex」）。
pub(crate) fn compile_error(error: ::regex::Error) -> String {
    let message = error.to_string();
    if message.len() <= text::ERROR_LIMIT {
        return message;
    }
    let reason = message.lines().next_back().unwrap_or_default();
    let mut result = String::from(text::ERROR_HEADER);
    result.push_str(text::ERROR_OMITTED);
    let mut end = text::ERROR_LIMIT
        .saturating_sub(result.len())
        .min(reason.len());
    while !reason.is_char_boundary(end) {
        end = end.saturating_sub(1);
    }
    if let Some(reason) = reason.get(..end) {
        result.push_str(reason);
    }
    result
}
