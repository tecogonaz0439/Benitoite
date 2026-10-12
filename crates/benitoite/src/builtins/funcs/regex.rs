//! 正規表現の組み立てと照合（設計書 03-08「Regex」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::{CheckedLen, FieldsKind, OpaqueData, Value, ValueCtx};
use std::collections::BTreeMap;
use std::rc::Rc;

#[derive(Debug)]
struct Pattern {
    regex: ::regex::Regex,
    names: Rc<BTreeMap<String, usize>>,
}
impl OpaqueData for Pattern {}

// 入力の全文を保持しないよう一致の部分だけを所有する。名前の表は Pattern と共有し、
// 別領域の容量には含めない（設計書 03-08「Regex」、02-09「メモリの管理」）。
#[derive(Debug)]
struct Match {
    text: Box<str>,
    start: usize,
    groups: Box<[Option<(usize, usize)>]>,
    names: Rc<BTreeMap<String, usize>>,
}
impl OpaqueData for Match {
    fn heap_bytes(&self) -> usize {
        self.text.len().saturating_add(
            self.groups
                .len()
                .saturating_mul(std::mem::size_of::<Option<(usize, usize)>>()),
        )
    }
}

fn string<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c str, Stop> {
    ctx.str(value)
        .ok_or_else(|| Stop::Internal("Regex expected String".into()))
}

fn pattern<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c Pattern, Stop> {
    ctx.opaque::<Pattern>(value)
        .ok_or_else(|| Stop::Internal("Regex expected Pattern".into()))
}

fn matched<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c Match, Stop> {
    ctx.opaque(value)
        .ok_or_else(|| Stop::Internal("Regex expected Match".into()))
}

fn names(pattern: &::regex::Regex) -> Rc<BTreeMap<String, usize>> {
    Rc::new(
        pattern
            .capture_names()
            .enumerate()
            .filter_map(|(i, name)| name.map(|name| (name.to_owned(), i)))
            .collect(),
    )
}

fn match_value<'e>(
    ctx: &ValueCtx<'e>,
    names: &Rc<BTreeMap<String, usize>>,
    captures: ::regex::Captures<'_>,
) -> Result<Value<'e>, Stop> {
    let whole = captures
        .get(0)
        .ok_or_else(|| Stop::Internal("Regex match without group zero".into()))?;
    let start = whole.start();
    let groups = captures
        .iter()
        .map(|m| {
            m.map(|m| {
                let relative_start = m.start().checked_sub(start);
                let relative_end = m.end().checked_sub(start);
                match (relative_start, relative_end) {
                    (Some(s), Some(e)) if s <= e && m.end() <= whole.end() => Ok((s, e)),
                    _ => Err(Stop::Internal("Regex group outside the match".into())),
                }
            })
            .transpose()
        })
        .collect::<Result<Box<[_]>, Stop>>()?;
    Ok(ctx.alloc_opaque(Match {
        text: whole.as_str().into(),
        start,
        groups,
        names: Rc::clone(names),
    }))
}

fn whole(m: &Match) -> Result<(usize, usize), Stop> {
    let end = m
        .start
        .checked_add(m.text.len())
        .ok_or_else(|| Stop::Internal("Regex match byte end overflow".into()))?;
    Ok((m.start, end))
}

fn group_value<'e>(
    ctx: &ValueCtx<'e>,
    m: &Match,
    index: Option<usize>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let range = index.and_then(|i| m.groups.get(i)).copied().flatten();
    let value = range
        .map(|(start, end)| {
            let text = m
                .text
                .get(start..end)
                .ok_or_else(|| Stop::Internal("Regex group outside UTF-8 text".into()))?;
            ctx.alloc_str(text, function)
        })
        .transpose()?;
    super::option(ctx, value)
}

mod text {
    pub const ERROR_LIMIT: usize = 4096;
    pub const ERROR_HEADER: &str = "regex parse error:\n";
    pub const ERROR_OMITTED: &str = "(pattern omitted; error message truncated)\n";
}

// 正規表現の全文と位置の表示を省き、誤りの種類を UTF-8 の境目で残す。
// 一時の表示用文字列は上限の対象外である（設計書 03-08「Regex」）。
fn compile_error(error: ::regex::Error) -> String {
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

builtin! {
    /// `Regex.compile` の本体。既定の設定で組み立て、長い誤りの表示を切り詰める
    /// （設計書 03-08「Regex」「共通の規則」）。
    name = "Regex.compile",
    pure fn compile(ctx, arg0: Value<'e>) -> Value<'e> {
        let source = string(&ctx, arg0)?;
        let (tag, value) = match ::regex::RegexBuilder::new(source).build() {
            Ok(regex) => {
                let names = names(&regex);
                (tags::RESULT_OK, ctx.alloc_opaque(Pattern { regex, names }))
            },
            Err(error) => (tags::RESULT_ERROR, ctx.alloc_str(&compile_error(error), "Regex.compile")?),
        };
        ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
    }
}

builtin! {
    /// `Regex.isMatch` の本体（設計書 03-08「Regex」）。
    name = "Regex.isMatch",
    pure fn is_match(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        Ok(Value::Bool(pattern(&ctx, arg0)?.regex.is_match(string(&ctx, arg1)?)))
    }
}

builtin! {
    /// `Regex.find` の本体（設計書 03-08「Regex」）。
    name = "Regex.find",
    pure fn find(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let pattern = pattern(&ctx, arg0)?;
        let text = string(&ctx, arg1)?;
        let value = pattern.regex.captures(text)
            .map(|captures| match_value(&ctx, &pattern.names, captures))
            .transpose()?;
        super::option(&ctx, value)
    }
}

builtin! {
    /// `Regex.matchText` の本体（設計書 03-08「Regex」）。
    name = "Regex.matchText",
    pure fn match_text(ctx, arg0: Value<'e>) -> Value<'e> {
        let m = matched(&ctx, arg0)?;
        ctx.alloc_str(&m.text, "Regex.matchText")
    }
}

builtin! {
    /// `Regex.matchByteStart` の本体。位置はバイトで数える（設計書 03-08「Regex」）。
    name = "Regex.matchByteStart",
    pure fn match_byte_start(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(super::integer_count(whole(matched(&ctx, arg0)?)?.0)?))
    }
}

builtin! {
    /// `Regex.matchByteEnd` の本体。半開区間の終端を返す（設計書 03-08「Regex」）。
    name = "Regex.matchByteEnd",
    pure fn match_byte_end(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(super::integer_count(whole(matched(&ctx, arg0)?)?.1)?))
    }
}

builtin! {
    /// `Regex.group` の本体。負の番号と存在しない番号も `None` を返す（設計書 03-08「Regex」）。
    name = "Regex.group",
    pure fn group(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let index = arg1.as_int().ok_or_else(|| Stop::Internal("Regex.group expected Integer".into()))?;
        group_value(&ctx, matched(&ctx, arg0)?, usize::try_from(index).ok(), "Regex.group")
    }
}

builtin! {
    /// `Regex.namedGroup` の本体（設計書 03-08「Regex」）。
    name = "Regex.namedGroup",
    pure fn named_group(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let m = matched(&ctx, arg0)?;
        let index = m.names.get(string(&ctx, arg1)?).copied();
        group_value(&ctx, m, index, "Regex.namedGroup")
    }
}

// 全件の探索と展開を避け、先頭の一致だけを置き換える長さを先に確かめる。
// 結果の確保より先に上限を検査する（設計書 03-08「Regex」、
// 02-09「一つの操作で作る値の大きさの上限」）。
fn replace<'e>(
    ctx: &ValueCtx<'e>,
    pattern: &::regex::Regex,
    text: &str,
    replacement: &str,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut removed = 0u64;
    let mut count = 0u64;
    let matches = pattern.find_iter(text).take(1);
    for m in matches {
        removed = removed.saturating_add(super::count(m.len())?);
        count = count.saturating_add(1);
    }
    let remaining = super::count(text.len())?
        .checked_sub(removed)
        .ok_or_else(|| Stop::Internal("Regex matches overlap".into()))?;
    let len = remaining.saturating_add(count.saturating_mul(super::count(replacement.len())?));
    CheckedLen::bytes(len, function)?;
    let result = pattern.replacen(text, 1, ::regex::NoExpand(replacement));
    ctx.alloc_str(&result, function)
}

builtin! {
    /// `Regex.replaceFirst` の本体。置換の文字列を展開しない（設計書 03-08「Regex」）。
    name = "Regex.replaceFirst",
    pure fn replace_first(ctx, arg0: Value<'e>, arg1: Value<'e>, arg2: Value<'e>) -> Value<'e> {
        replace(&ctx, &pattern(&ctx, arg0)?.regex, string(&ctx, arg1)?, string(&ctx, arg2)?, "Regex.replaceFirst")
    }
}

// 入力を切らずに探すため、呼び出し側のバイト位置だけを先に確かめる。
// 不正な位置は標準ライブラリの誤りである（設計書 03-08「Regex」）。
fn search_start(text: &str, start: i64) -> Result<usize, Stop> {
    let start = usize::try_from(start)
        .ok()
        .filter(|&start| start <= text.len() && text.is_char_boundary(start))
        .ok_or_else(|| Stop::Internal("Regex search start outside UTF-8 text".into()))?;
    Ok(start)
}

// 直前の一致の終わりと重なる空の一致を捨て、次の文字の境目から探す。
// 入力の終わりなら探し直さない（設計書 03-08「Regex」）。
fn retry_start(
    text: &str,
    start: usize,
    after_match: bool,
    range: Option<(usize, usize)>,
) -> Option<usize> {
    if after_match && range == Some((start, start)) {
        text.get(start..)?
            .chars()
            .next()
            .map(|c| start.saturating_add(c.len_utf8()))
    } else {
        Some(start)
    }
}

builtin! {
    /// 位置から一つの一致を求め、捕獲を残す（設計書 03-08「Regex」）。
    name = "Regex.findAt",
    pure fn find_at(ctx, arg0: Value<'e>, arg1: Value<'e>, start: i64, after_match: bool) -> Value<'e> {
        let pattern = pattern(&ctx, arg0)?;
        let text = string(&ctx, arg1)?;
        let start = search_start(text, start)?;
        let captures = pattern.regex.captures_at(text, start);
        let range = captures.as_ref().and_then(|c| c.get(0)).map(|m| (m.start(), m.end()));
        let Some(next) = retry_start(text, start, after_match, range) else {
            return super::option(&ctx, None);
        };
        let captures = if next == start { captures } else { pattern.regex.captures_at(text, next) };
        let value = captures.map(|c| match_value(&ctx, &pattern.names, c)).transpose()?;
        super::option(&ctx, value)
    }
}

builtin! {
    /// 捕獲を作らずに位置から一つの範囲を求める（設計書 03-08「Regex」）。
    name = "Regex.spanAt",
    pure fn span_at(ctx, arg0: Value<'e>, arg1: Value<'e>, start: i64, after_match: bool) -> Value<'e> {
        let pattern = pattern(&ctx, arg0)?;
        let text = string(&ctx, arg1)?;
        let start = search_start(text, start)?;
        let found = pattern.regex.find_at(text, start);
        let range = found.map(|m| (m.start(), m.end()));
        let Some(next) = retry_start(text, start, after_match, range) else {
            return super::option(&ctx, None);
        };
        let found = if next == start { found } else { pattern.regex.find_at(text, next) };
        let value = found.map(|m| {
            ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[
                Value::Int(super::integer_count(m.start())?),
                Value::Int(super::integer_count(m.end())?),
            ])
        }).transpose()?;
        super::option(&ctx, value)
    }
}

builtin! {
    /// 文字列の値の上限（バイト）を返す。`Regex.bnt` の結合の判定が使う（設計書 03-08「Regex」）。
    name = "Regex.maxStringBytes",
    pure fn max_string_bytes(ctx) -> i64 {
        let _ = ctx;
        i64::try_from(crate::runtime::MAX_STRING_BYTES)
            .map_err(|_| Stop::Internal("string limit does not fit Integer".into()))
    }
}

/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[
    compile::DECL,
    is_match::DECL,
    find::DECL,
    match_text::DECL,
    match_byte_start::DECL,
    match_byte_end::DECL,
    group::DECL,
    named_group::DECL,
    replace_first::DECL,
    find_at::DECL,
    span_at::DECL,
    max_string_bytes::DECL,
];

#[cfg(test)]
mod tests;
