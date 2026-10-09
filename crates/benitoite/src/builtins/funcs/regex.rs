//! 正規表現の組み立てと照合（設計書 03-08「Regex」、ADR 0168・0248・0316）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, FieldsKind, OpaqueData, Value, ValueCtx};
use crate::runtime::{Stop, list};
use std::collections::BTreeMap;
use std::rc::Rc;

#[derive(Debug)]
struct Pattern(::regex::Regex);
impl OpaqueData for Pattern {}

// 言語の値を保持せず、元の文字列と名前の対応を一致どうしで共有する
// （実装プラン L22「手順の要点」、10-08「OpaqueData」）。
#[derive(Debug)]
struct Match {
    text: Rc<String>,
    groups: Vec<Option<(usize, usize)>>,
    names: Rc<BTreeMap<String, usize>>,
}
impl OpaqueData for Match {}

fn string<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c str, Stop> {
    ctx.str(value)
        .ok_or_else(|| Stop::Internal("Regex expected String".into()))
}

fn pattern<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c ::regex::Regex, Stop> {
    ctx.opaque::<Pattern>(value)
        .map(|p| &p.0)
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
    text: &Rc<String>,
    names: &Rc<BTreeMap<String, usize>>,
    captures: ::regex::Captures<'_>,
) -> Value<'e> {
    ctx.alloc_opaque(Match {
        text: Rc::clone(text),
        groups: captures
            .iter()
            .map(|m| m.map(|m| (m.start(), m.end())))
            .collect(),
        names: Rc::clone(names),
    })
}

fn whole(m: &Match) -> Result<(usize, usize), Stop> {
    m.groups
        .first()
        .copied()
        .flatten()
        .ok_or_else(|| Stop::Internal("Regex match without group zero".into()))
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

builtin! {
    /// `Regex.compile` の本体。既定の設定で組み立て、誤りの表示をそのまま返す
    /// （設計書 03-08「Regex」「共通の規則」、ADR 0316）。
    name = "Regex.compile",
    pure fn compile(ctx, arg0: Value<'e>) -> Value<'e> {
        let source = string(&ctx, arg0)?;
        let (tag, value) = match ::regex::RegexBuilder::new(source).build() {
            Ok(regex) => (tags::RESULT_OK, ctx.alloc_opaque(Pattern(regex))),
            Err(error) => (tags::RESULT_ERROR, ctx.alloc_str(&error.to_string(), "Regex.compile")?),
        };
        ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
    }
}

builtin! {
    /// `Regex.isMatch` の本体（設計書 03-08「Regex」）。
    name = "Regex.isMatch",
    pure fn is_match(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        Ok(Value::Bool(pattern(&ctx, arg0)?.is_match(string(&ctx, arg1)?)))
    }
}

builtin! {
    /// `Regex.find` の本体（設計書 03-08「Regex」）。
    name = "Regex.find",
    pure fn find(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let pattern = pattern(&ctx, arg0)?;
        let text = string(&ctx, arg1)?;
        let value = pattern.captures(text).map(|captures| {
            match_value(&ctx, &Rc::new(text.to_owned()), &names(pattern), captures)
        });
        super::option(&ctx, value)
    }
}

builtin! {
    /// `Regex.findAll` の本体。空の一致で増える要素も、作る前に数える
    /// （設計書 03-08「Regex」、実装プラン L22「手順の要点」）。
    name = "Regex.findAll",
    pure fn find_all(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let pattern = pattern(&ctx, arg0)?;
        let text = string(&ctx, arg1)?;
        let len = CheckedLen::elements(super::count(pattern.find_iter(text).count())?, "Regex.findAll")?;
        if len.get() == 0 {
            return list::from_values(&ctx, &[], "Regex.findAll");
        }
        let text = Rc::new(text.to_owned());
        let names = names(pattern);
        let mut values = Vec::new();
        for captures in pattern.captures_iter(&text) {
            values.push(match_value(&ctx, &text, &names, captures));
        }
        list::from_values(&ctx, &values, "Regex.findAll")
    }
}

builtin! {
    /// `Regex.matchText` の本体（設計書 03-08「Regex」）。
    name = "Regex.matchText",
    pure fn match_text(ctx, arg0: Value<'e>) -> Value<'e> {
        let m = matched(&ctx, arg0)?;
        let (start, end) = whole(m)?;
        let text = m.text.get(start..end)
            .ok_or_else(|| Stop::Internal("Regex match outside UTF-8 text".into()))?;
        ctx.alloc_str(text, "Regex.matchText")
    }
}

builtin! {
    /// `Regex.matchByteStart` の本体。位置はバイトで数える（設計書 03-08「Regex」、ADR 0248）。
    name = "Regex.matchByteStart",
    pure fn match_byte_start(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(super::integer_count(whole(matched(&ctx, arg0)?)?.0)?))
    }
}

builtin! {
    /// `Regex.matchByteEnd` の本体。半開区間の終端を返す（設計書 03-08「Regex」、ADR 0248）。
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

// 途中の長さではなく最終の長さを確かめ、縮む置換と伸びる置換の混在も扱う。
// 出力を組み立てる前に、置き換える総バイト数と回数を求める
// （実装プラン L22「手順の要点」、設計書 02-09「一つの操作で作る値の大きさの上限」）。
fn replace<'e>(
    ctx: &ValueCtx<'e>,
    pattern: &::regex::Regex,
    text: &str,
    replacement: &str,
    limit: usize,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut removed = 0u64;
    let mut count = 0u64;
    let matches = pattern
        .find_iter(text)
        .take(if limit == 0 { usize::MAX } else { limit });
    for m in matches {
        removed = removed.saturating_add(super::count(m.len())?);
        count = count.saturating_add(1);
    }
    let remaining = super::count(text.len())?
        .checked_sub(removed)
        .ok_or_else(|| Stop::Internal("Regex matches overlap".into()))?;
    let len = remaining.saturating_add(count.saturating_mul(super::count(replacement.len())?));
    CheckedLen::bytes(len, function)?;
    let result = pattern.replacen(text, limit, ::regex::NoExpand(replacement));
    ctx.alloc_str(&result, function)
}

builtin! {
    /// `Regex.replaceFirst` の本体。置換の文字列を展開しない（設計書 03-08「Regex」）。
    name = "Regex.replaceFirst",
    pure fn replace_first(ctx, arg0: Value<'e>, arg1: Value<'e>, arg2: Value<'e>) -> Value<'e> {
        replace(&ctx, pattern(&ctx, arg0)?, string(&ctx, arg1)?, string(&ctx, arg2)?, 1, "Regex.replaceFirst")
    }
}

builtin! {
    /// `Regex.replaceAll` の本体。置換の文字列を展開しない（設計書 03-08「Regex」）。
    name = "Regex.replaceAll",
    pure fn replace_all(ctx, arg0: Value<'e>, arg1: Value<'e>, arg2: Value<'e>) -> Value<'e> {
        replace(&ctx, pattern(&ctx, arg0)?, string(&ctx, arg1)?, string(&ctx, arg2)?, 0, "Regex.replaceAll")
    }
}

builtin! {
    /// `Regex.split` の本体。空の入力に一致しなければ `[""]`、先頭・末尾の区切りは
    /// 空の部分を残す。空の正規表現は UTF-8 の文字の境目（両端を含む）で分け、
    /// 空の入力なら `["", ""]` を返す。非空の一致に隣接する空の一致は省く
    /// （設計書 03-08「Regex」、regex 1.13.1 の `Regex::split`）。
    name = "Regex.split",
    pure fn split(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let pattern = pattern(&ctx, arg0)?;
        let text = string(&ctx, arg1)?;
        CheckedLen::elements(super::count(pattern.split(text).count())?, "Regex.split")?;
        let mut values = Vec::new();
        for part in pattern.split(text) {
            values.push(ctx.alloc_str(part, "Regex.split")?);
        }
        list::from_values(&ctx, &values, "Regex.split")
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    compile::DECL,
    is_match::DECL,
    find::DECL,
    find_all::DECL,
    match_text::DECL,
    match_byte_start::DECL,
    match_byte_end::DECL,
    group::DECL,
    named_group::DECL,
    replace_first::DECL,
    replace_all::DECL,
    split::DECL,
];

#[cfg(test)]
mod tests;
