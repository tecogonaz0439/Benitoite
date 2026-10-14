//! 先頭の部分だけを整形し、範囲外の字句を保つ（設計書 06-09「`benitoite package`」）。

use super::super::formatter::format_source;
use crate::base::{FileId, SourceKind};
use crate::syntax::ast::{HeaderBlock, Module};
use crate::syntax::header::{EFFECTS, HASH, keyword};
use std::ops::Range;

pub(super) fn range(source: &str, module: &Module) -> Range<usize> {
    let Some(first) = module.header.first() else {
        let mut position = if source.starts_with('\u{feff}') { 3 } else { 0 };
        if source.get(position..).is_some_and(|s| s.starts_with("#!")) {
            position = line_end(source, position);
        }
        if let Some(doc) = &module.doc {
            position = line_end(
                source,
                usize::try_from(doc.span.end.0).unwrap_or(source.len()),
            );
        }
        while let Some(rest) = source.get(position..) {
            let end = line_end(source, position);
            if rest.is_empty()
                || !source
                    .get(position..end)
                    .is_some_and(|line| line.trim().is_empty())
            {
                break;
            }
            position = end;
        }
        return position..position;
    };
    let span = keyword(first).1;
    let mut start = line_start(source, usize::try_from(span.start.0).unwrap_or(0));
    // 直前の説明だけを移す。モジュールの説明とシェバンは入口に残す。
    while start > 0 {
        let previous = line_start(source, start.saturating_sub(1));
        let line = source
            .get(previous..start)
            .unwrap_or("")
            .trim_start_matches('\u{feff}')
            .trim();
        if !line.starts_with("//") || line.starts_with("//!") {
            break;
        }
        start = previous;
    }
    let end = module
        .header
        .last()
        .map(|item| match item {
            crate::syntax::ast::HeaderItem::Language(decl) => decl.span.end.0,
            crate::syntax::ast::HeaderItem::Dependency(block)
            | crate::syntax::ast::HeaderItem::Package(block) => block.span.end.0,
        })
        .and_then(|end| usize::try_from(end).ok())
        .unwrap_or(start);
    if start == 0 && source.starts_with('\u{feff}') {
        start = 3;
    }
    start..line_end(source, end)
}

// 項目がない設定では既存のコメントを前に残し、末尾の空行だけを置き換える。
pub(super) fn config_insertion(source: &str) -> Range<usize> {
    let position = before_content(source).len();
    position..source.len()
}

fn line_start(source: &str, at: usize) -> usize {
    source
        .get(..at)
        .and_then(|prefix| prefix.rfind('\n'))
        .map_or(0, |pos| pos.saturating_add(1))
}
fn line_end(source: &str, at: usize) -> usize {
    source
        .get(at..)
        .and_then(|tail| tail.find('\n'))
        .map_or(source.len(), |pos| at.saturating_add(pos).saturating_add(1))
}

pub(super) fn quote(value: &str) -> String {
    crate::base::literal::quoted(value.chars(), '"')
}

pub(super) fn dependency(alias: &str, path: &str, hash: &str, effects: &str) -> String {
    crate::diag::codes::fill_template(
        super::text::DEPENDENCY,
        &[
            ("alias", alias.to_owned()),
            ("path", quote(path)),
            ("hash", quote(hash)),
            ("effects", quote(effects)),
        ],
    )
}

pub(super) fn update(
    source: &str,
    bounds: &Range<usize>,
    block: &HeaderBlock,
    hash: &str,
    effects: &str,
) -> Result<String, String> {
    let mut changes = Vec::new();
    let mut missing = String::new();
    for (name, value) in [(HASH, hash), (EFFECTS, effects)] {
        if let Some(field) = block.fields.iter().find(|field| field.name.text == name) {
            let start = usize::try_from(field.value.span.start.0).map_err(|e| e.to_string())?;
            let end = usize::try_from(field.value.span.end.0).map_err(|e| e.to_string())?;
            changes.push((start..end, quote(value)));
        } else {
            missing.push_str(&format!("  {name} {}\n", quote(value)));
        }
    }
    if !missing.is_empty() {
        let end = usize::try_from(block.span.end.0).map_err(|e| e.to_string())?;
        let position = line_start(source, end);
        changes.push((position..position, missing));
    }
    changes.sort_by_key(|(range, _)| std::cmp::Reverse(range.start));
    let mut header = source
        .get(bounds.clone())
        .ok_or("invalid header range")?
        .to_owned();
    for (range, replacement) in changes {
        let start = range
            .start
            .checked_sub(bounds.start)
            .ok_or("field before header")?;
        let end = range
            .end
            .checked_sub(bounds.start)
            .ok_or("field before header")?;
        if header.get(start..end).is_none() {
            return Err("invalid field range".into());
        }
        header.replace_range(start..end, &replacement);
    }
    Ok(header)
}

fn before_content(source: &str) -> &str {
    let mut end = source.len();
    while end > 0 {
        let line_end = source
            .get(..end)
            .unwrap_or("")
            .trim_end_matches(['\r', '\n'])
            .len();
        let start = line_start(source, line_end);
        if !source
            .get(start..line_end)
            .is_some_and(|line| line.trim().is_empty())
        {
            return source.get(..line_end).unwrap_or("");
        }
        end = start;
    }
    ""
}
fn after_content(source: &str) -> &str {
    let mut start = 0;
    while start < source.len() {
        let end = line_end(source, start);
        if !source
            .get(start..end)
            .is_some_and(|line| line.trim().is_empty())
        {
            break;
        }
        start = end;
    }
    source.get(start..).unwrap_or("")
}

pub(super) fn splice(
    source: &str,
    bounds: Range<usize>,
    header: &str,
    file: FileId,
) -> Result<String, String> {
    let formatted = format_source(file, SourceKind::User, header.as_bytes())
        .map_err(|e| format!("cannot format package header: {e:?}"))?;
    let formatted = String::from_utf8(formatted.text).map_err(|e| e.to_string())?;
    let before = source.get(..bounds.start).ok_or("invalid header start")?;
    let after = source.get(bounds.end..).ok_or("invalid header end")?;
    let newline = before
        .find('\n')
        .map(|pos| before.get(..pos).is_some_and(|s| s.ends_with('\r')))
        .or_else(|| {
            after
                .find('\n')
                .map(|pos| after.get(..pos).is_some_and(|s| s.ends_with('\r')))
        })
        .unwrap_or_else(|| source.contains("\r\n"));
    let nl = if newline { "\r\n" } else { "\n" };
    let body = formatted.trim_end_matches(['\r', '\n']);
    let body = if newline {
        body.replace('\n', "\r\n")
    } else {
        body.to_owned()
    };
    let mut out = before_content(before).to_owned();
    let tail = after_content(after);
    let has_prefix = !out.trim_start_matches('\u{feff}').is_empty();
    if !body.is_empty() {
        if has_prefix {
            out.push_str(nl);
            out.push_str(nl);
        }
        out.push_str(&body);
        out.push_str(nl);
        if !tail.is_empty() {
            out.push_str(nl);
        }
    } else if has_prefix {
        out.push_str(nl);
        if !tail.is_empty() {
            out.push_str(nl);
        }
    }
    out.push_str(tail);
    Ok(out)
}
