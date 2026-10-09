//! 修正案を当てた行と、挿入した文字の印を組み立てる（設計書 02-10「文章の形式」、実装プラン F16）。

use crate::base::{FileId, Source, SourceTable};
use crate::diag::Edit;

use super::{byte_offset, line_start_offset, visit_source_units};

pub(super) struct EditedRow {
    pub number: u32,
    pub text: String,
    pub markers: String,
}

pub(super) struct EditedFile {
    pub file: FileId,
    pub name: String,
    pub line: u32,
    pub column: u32,
    pub rows: Vec<EditedRow>,
}

pub(super) fn prepare_edits(edits: &[Edit], sources: &SourceTable) -> Vec<EditedFile> {
    // ファイルは修正案に現れた順、各ファイルの置き換えは元のソース上の順で当てる。
    let mut files = Vec::new();
    for edit in edits {
        if !files.contains(&edit.span.file) {
            files.push(edit.span.file);
        }
    }
    files
        .into_iter()
        .filter_map(|file| {
            let source = sources.get(file)?;
            let mut edits = edits
                .iter()
                .filter(|edit| edit.span.file == file)
                .collect::<Vec<_>>();
            edits.sort_by_key(|edit| edit.span.start);
            prepare_file(file, source, &edits)
        })
        .collect()
}

fn prepare_file(file: FileId, source: &Source, edits: &[&Edit]) -> Option<EditedFile> {
    let first = edits.first()?;
    let last = edits.last()?;
    let bytes = source.text();
    let location = source.line_col(first.span.start);
    let range_start = line_start_offset(bytes, byte_offset(bytes, first.span.start));
    let last_end = byte_offset(bytes, last.span.end);
    let range_end = bytes
        .get(last_end..)?
        .iter()
        .position(|byte| *byte == b'\n')
        .map_or(bytes.len(), |length| last_end.saturating_add(length));
    let mut pieces = Vec::new();
    let mut cursor = range_start;
    for edit in edits {
        let start = byte_offset(bytes, edit.span.start);
        let end = byte_offset(bytes, edit.span.end);
        // 重ならない範囲は診断の契約。不正な範囲が届いてもソースを取り違えて示さない。
        if start < cursor || end < start || end > range_end {
            return None;
        }
        pieces.push((bytes.get(cursor..start)?, false));
        pieces.push((edit.replacement.as_bytes(), true));
        cursor = end;
    }
    pieces.push((bytes.get(cursor..range_end)?, false));
    let mut rows = Vec::new();
    let mut text = String::new();
    let mut markers = String::new();
    let mut number = location.line;
    for (bytes, inserted) in pieces {
        visit_source_units(bytes, |character, width| {
            if character == '\n' {
                finish_row(&mut rows, number, &mut text, &mut markers);
                number = number.saturating_add(1);
            } else {
                if character == '\t' {
                    text.push_str("    ");
                } else {
                    text.push(character);
                }
                markers.extend(std::iter::repeat_n(if inserted { '~' } else { ' ' }, width));
            }
        });
    }
    finish_row(&mut rows, number, &mut text, &mut markers);
    Some(EditedFile {
        file,
        name: source.name().to_owned(),
        line: location.line,
        column: location.column,
        rows,
    })
}

fn finish_row(rows: &mut Vec<EditedRow>, number: u32, text: &mut String, markers: &mut String) {
    // CR LF の CR は抜粋には出さない（Source::line_text と同じ扱い）。
    if text.ends_with('\r') {
        text.pop();
        markers.pop();
    }
    let trimmed = markers.trim_end_matches(' ').to_owned();
    rows.push(EditedRow {
        number,
        text: std::mem::take(text),
        markers: trimmed,
    });
    markers.clear();
}
