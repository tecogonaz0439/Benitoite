//! 正規表現の WASM の検証用実装（設計書 03-08「Regex」、03-10「外部の関数」）。

wit_bindgen::generate!({ world: "regex", path: "../wit" });
use exports::bnt::regex::re::{Found, Guest, GuestPattern, Pattern};

struct Component;
struct Compiled(regex::Regex);

mod text {
    pub const ERROR_LIMIT: usize = 4096;
    pub const ERROR_HEADER: &str = "regex parse error:\n";
    pub const ERROR_OMITTED: &str = "(pattern omitted; error message truncated)\n";
}

// src/builtins/funcs/regex.rs の compile_error を写し、誤りの表示を揃える。
fn compile_error(error: regex::Error) -> String {
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

fn build(source: &str) -> Result<regex::Regex, String> {
    regex::RegexBuilder::new(source)
        .build()
        .map_err(compile_error)
}

// 32 ビットのゲストでは位置と要素数が s64 に必ず収まる。
fn count(n: usize) -> i64 {
    i64::try_from(n).unwrap_or(i64::MAX)
}

fn found(m: regex::Match<'_>) -> Found {
    Found {
        text: m.as_str().to_owned(),
        byte_start: count(m.start()),
        byte_end: count(m.end()),
    }
}

// src/builtins/funcs/regex.rs の retry_start と span_at、および
// src/prelude/stdlib/Regex.bnt の findAllFrom の手順を写す。
// 直前の終端と重なる空の一致を捨て、次の文字の境目から探し直す。
fn matches<'a>(pattern: &regex::Regex, text: &'a str, mut accept: impl FnMut(regex::Match<'a>)) {
    let mut start = 0;
    let mut after_match = false;
    loop {
        let mut next = pattern.find_at(text, start);
        if after_match && next.as_ref().map(|m| (m.start(), m.end())) == Some((start, start)) {
            let Some(c) = text.get(start..).and_then(|s| s.chars().next()) else {
                break;
            };
            next = pattern.find_at(text, start.saturating_add(c.len_utf8()));
        }
        let Some(m) = next else {
            break;
        };
        start = m.end();
        after_match = true;
        accept(m);
    }
}

fn find_all(pattern: &regex::Regex, text: &str) -> Vec<Found> {
    let mut result = Vec::new();
    matches(pattern, text, |m| result.push(found(m)));
    result
}

fn count_all(pattern: &regex::Regex, text: &str) -> i64 {
    let mut total = 0i64;
    matches(pattern, text, |_| total = total.saturating_add(1));
    total
}

// src/prelude/stdlib/Regex.bnt の replaceAllFrom と同じ一致の選び方で、
// NoExpand の置換の文字列を文字どおりに書く。
fn replace_all(pattern: &regex::Regex, text: &str, replacement: regex::NoExpand<'_>) -> String {
    let mut result = String::new();
    let mut start = 0;
    matches(pattern, text, |m| {
        if let Some(prefix) = text.get(start..m.start()) {
            result.push_str(prefix);
        }
        result.push_str(replacement.0);
        start = m.end();
    });
    if let Some(tail) = text.get(start..) {
        result.push_str(tail);
    }
    result
}

impl GuestPattern for Compiled {
    fn compile(source: String) -> Result<Pattern, String> {
        build(&source).map(|r| Pattern::new(Compiled(r)))
    }
    fn is_match(&self, text: String) -> bool {
        self.0.is_match(&text)
    }
    fn find(&self, text: String) -> Option<Found> {
        self.0.find(&text).map(found)
    }
    fn find_all(&self, text: String) -> Vec<Found> {
        find_all(&self.0, &text)
    }
    fn count(&self, text: String) -> i64 {
        count_all(&self.0, &text)
    }
    fn replace_all(&self, text: String, replacement: String) -> String {
        replace_all(&self.0, &text, regex::NoExpand(&replacement))
    }
}
impl Guest for Component {
    type Pattern = Compiled;
    fn is_match_once(source: String, text: String) -> Result<bool, String> {
        Ok(build(&source)?.is_match(&text))
    }
    fn find_all_once(source: String, text: String) -> Result<Vec<Found>, String> {
        Ok(find_all(&build(&source)?, &text))
    }
    fn count_once(source: String, text: String) -> Result<i64, String> {
        Ok(count_all(&build(&source)?, &text))
    }
}
export!(Component);
