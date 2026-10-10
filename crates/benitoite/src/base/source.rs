//! ソースと行の表、および行と列の変換（設計書 02-02「ソースとファイル ID」「行と列」）。

use super::{BytePos, FileId};

/// 読み込むソースファイルの大きさの上限（256 MiB）。超えたら読み込みの誤り E0101 とする。
/// ノード番号と束縛の番号を u32 に収めるための処理系の制限である。
pub const MAX_SOURCE_BYTES: usize = 256 * 1024 * 1024;

/// ソースの種類。構文解析器は prelude のソースでだけ修飾した関数の宣言を受け付ける（02-03）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SourceKind {
    User,
    Prelude,
}

/// 1 から数える行と列。列はコードポイントの数（02-02「行と列」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct LineCol {
    pub line: u32,
    pub column: u32,
}

/// 読み込んだソース一つ。読み込みの後は変更しない。
#[derive(Debug)]
pub struct Source {
    name: String,
    kind: SourceKind,
    text: Vec<u8>,
    /// 各行の先頭のバイトの位置。0 番目は常に 0。
    line_starts: Vec<BytePos>,
}

/// ソースの表。ファイル ID からソースを引く。読み込みを終えた後は変更しない（02-02）。
#[derive(Debug, Default)]
pub struct SourceTable {
    sources: Vec<Source>,
}

impl Source {
    /// 内容から行の表を作ってソースを作る。行は LF の直後から始まる（CR LF の CR は前の行に含む）。
    pub fn new(name: String, kind: SourceKind, text: Vec<u8>) -> Source {
        let mut line_starts = vec![BytePos(0)];

        for (index, byte) in text.iter().enumerate() {
            if *byte == b'\n' {
                let Some(start) = index.checked_add(1) else {
                    continue;
                };
                let start = u32::try_from(start).unwrap_or(u32::MAX);
                line_starts.push(BytePos(start));
            }
        }

        Source {
            name,
            kind,
            text,
            line_starts,
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn kind(&self) -> SourceKind {
        self.kind
    }

    pub fn text(&self) -> &[u8] {
        &self.text
    }

    /// バイトの位置を行と列に変換する。ファイルの先頭の BOM は 1 行目の列に数えない。
    /// 位置が内容の長さを超えるときは、最後の行の末尾の行と列を返す。
    pub fn line_col(&self, pos: BytePos) -> LineCol {
        let requested_pos = usize::try_from(pos.0).unwrap_or(usize::MAX);
        let clamped_pos = requested_pos.min(self.text.len());
        let position = u32::try_from(clamped_pos).unwrap_or(u32::MAX);
        let line_index = self
            .line_starts
            .partition_point(|start| start.0 <= position)
            .saturating_sub(1);
        let line_start = self
            .line_starts
            .get(line_index)
            .map(|start| usize::try_from(start.0).unwrap_or(usize::MAX))
            .unwrap_or(0);

        let mut count_start = line_start;
        if line_index == 0 && self.text.starts_with(b"\xEF\xBB\xBF") {
            count_start = count_start.max(b"\xEF\xBB\xBF".len().min(clamped_pos));
        }

        let column_count = if clamped_pos > count_start {
            count_code_points(&self.text, count_start, clamped_pos)
        } else {
            0
        };

        LineCol {
            line: u32::try_from(line_index)
                .unwrap_or(u32::MAX)
                .saturating_add(1),
            column: column_count.saturating_add(1),
        }
    }

    /// 1 から数えた行番号の行の内容。改行（LF と、CR LF の CR）を含まない。
    pub fn line_text(&self, line: u32) -> Option<&[u8]> {
        let line_index = usize::try_from(line.checked_sub(1)?).ok()?;
        let start = usize::try_from(self.line_starts.get(line_index)?.0).ok()?;
        let mut end = self
            .line_starts
            .get(line_index.checked_add(1)?)
            .and_then(|position| usize::try_from(position.0).ok())
            .unwrap_or(self.text.len());

        if end > start && self.text.get(end.checked_sub(1)?) == Some(&b'\n') {
            end = end.checked_sub(1)?;
            if end > start && self.text.get(end.checked_sub(1)?) == Some(&b'\r') {
                end = end.checked_sub(1)?;
            }
        }

        self.text.get(start..end)
    }

    pub fn line_count(&self) -> u32 {
        u32::try_from(self.line_starts.len()).unwrap_or(u32::MAX)
    }
}

impl SourceTable {
    pub fn new() -> SourceTable {
        SourceTable::default()
    }

    /// ソースを加えてファイル ID を振る。ID は加えた順に 0 から振る。
    pub fn add(&mut self, source: Source) -> FileId {
        let id = FileId(u32::try_from(self.sources.len()).unwrap_or(u32::MAX));
        self.sources.push(source);
        id
    }

    pub fn get(&self, id: FileId) -> Option<&Source> {
        let index = usize::try_from(id.0).ok()?;
        self.sources.get(index)
    }

    pub fn iter(&self) -> impl Iterator<Item = (FileId, &Source)> {
        self.sources
            .iter()
            .enumerate()
            .filter_map(|(index, source)| {
                let id = FileId(u32::try_from(index).ok()?);
                Some((id, source))
            })
    }
}

// 位置が UTF-8 の文字途中でも列に加えず、不正 UTF-8 は先頭の 1 バイトごとに数える（設計書 02-02「行と列」）。
fn count_code_points(text: &[u8], start: usize, end: usize) -> u32 {
    let mut offset = start;
    let mut count = 0_u32;

    while offset < end {
        let Some(remaining) = text.get(offset..) else {
            break;
        };
        let Some(bytes_to_position) = end.checked_sub(offset) else {
            break;
        };

        match std::str::from_utf8(remaining) {
            Ok(_) => {
                if let Some(prefix) = text.get(offset..end) {
                    count = count.saturating_add(count_complete_code_points(prefix));
                }
                break;
            }
            Err(error) if error.valid_up_to() >= bytes_to_position => {
                if let Some(prefix) = text.get(offset..end) {
                    count = count.saturating_add(count_complete_code_points(prefix));
                }
                break;
            }
            Err(error) => {
                let Some(invalid_start) = offset.checked_add(error.valid_up_to()) else {
                    break;
                };
                let Some(valid_prefix) = text.get(offset..invalid_start) else {
                    break;
                };
                count = count.saturating_add(count_complete_code_points(valid_prefix));
                count = count.saturating_add(1);
                let Some(next_offset) = invalid_start.checked_add(1) else {
                    break;
                };
                offset = next_offset;
            }
        }
    }

    count
}

fn count_complete_code_points(bytes: &[u8]) -> u32 {
    let count = match std::str::from_utf8(bytes) {
        Ok(valid) => valid.chars().count(),
        Err(error) => {
            let valid_bytes = bytes.get(..error.valid_up_to()).unwrap_or_default();
            std::str::from_utf8(valid_bytes)
                .map(|valid| valid.chars().count())
                .unwrap_or(0)
        }
    };

    u32::try_from(count).unwrap_or(u32::MAX)
}

#[cfg(test)]
#[allow(
    clippy::arithmetic_side_effects,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::unwrap_used
)]
// テストの失敗は assert で表し、準備データには必要な添字と算術を使う。
mod tests {
    use super::{BytePos, FileId, LineCol, Source, SourceKind, SourceTable};

    #[test]
    fn source_accessors_and_line_col_use_byte_positions_and_code_points() {
        let source = Source::new(
            "sample.bnt".to_owned(),
            SourceKind::User,
            b"ab\ncd".to_vec(),
        );

        assert_eq!(source.name(), "sample.bnt");
        assert_eq!(source.kind(), SourceKind::User);
        assert_eq!(source.text(), b"ab\ncd");
        assert_eq!(source.line_col(BytePos(0)), LineCol { line: 1, column: 1 });
        assert_eq!(source.line_col(BytePos(3)), LineCol { line: 2, column: 1 });
        assert_eq!(source.line_col(BytePos(5)), LineCol { line: 2, column: 3 });

        let unicode = Source::new(
            "unicode.bnt".to_owned(),
            SourceKind::User,
            "あいう".as_bytes().to_vec(),
        );
        assert_eq!(unicode.line_col(BytePos(4)), LineCol { line: 1, column: 2 });
        assert_eq!(unicode.line_col(BytePos(3)), LineCol { line: 1, column: 2 });
        assert_eq!(unicode.line_col(BytePos(6)), LineCol { line: 1, column: 3 });

        let bom = Source::new(
            "bom.bnt".to_owned(),
            SourceKind::User,
            "\u{FEFF}x".as_bytes().to_vec(),
        );
        assert_eq!(bom.line_col(BytePos(3)), LineCol { line: 1, column: 1 });

        let empty = Source::new(String::new(), SourceKind::User, Vec::new());
        assert_eq!(empty.line_count(), 1);
        assert_eq!(empty.line_col(BytePos(0)), LineCol { line: 1, column: 1 });
        assert_eq!(
            source.line_col(BytePos(100)),
            LineCol { line: 2, column: 3 }
        );
    }

    #[test]
    fn line_col_counts_invalid_utf8_bytes_and_crlf_belongs_to_the_previous_line() {
        let invalid = Source::new(
            "invalid.bnt".to_owned(),
            SourceKind::User,
            b"a\xFFb".to_vec(),
        );
        assert_eq!(invalid.line_col(BytePos(2)), LineCol { line: 1, column: 3 });

        let incomplete = Source::new(
            "incomplete.bnt".to_owned(),
            SourceKind::User,
            b"\xE3\x81".to_vec(),
        );
        assert_eq!(
            incomplete.line_col(BytePos(2)),
            LineCol { line: 1, column: 3 }
        );

        let crlf = Source::new("crlf.bnt".to_owned(), SourceKind::User, b"a\r\nb".to_vec());
        assert_eq!(crlf.line_col(BytePos(1)), LineCol { line: 1, column: 2 });
        assert_eq!(crlf.line_col(BytePos(3)), LineCol { line: 2, column: 1 });
        assert_eq!(crlf.line_text(1), Some(b"a".as_slice()));
    }

    #[test]
    fn line_text_excludes_only_lf_and_its_preceding_cr() {
        let source = Source::new(
            "lines.bnt".to_owned(),
            SourceKind::User,
            b"a\r\nb\rc\n".to_vec(),
        );

        assert_eq!(source.line_count(), 3);
        assert_eq!(source.line_text(1), Some(b"a".as_slice()));
        assert_eq!(source.line_text(2), Some(b"b\rc".as_slice()));
        assert_eq!(source.line_text(3), Some(b"".as_slice()));
        assert_eq!(source.line_text(0), None);
        assert_eq!(source.line_text(4), None);
    }

    #[test]
    fn source_table_assigns_ids_and_supports_lookup_and_iteration() {
        let mut table = SourceTable::new();
        let first = Source::new("first".to_owned(), SourceKind::User, b"one".to_vec());
        let second = Source::new("second".to_owned(), SourceKind::Prelude, b"two".to_vec());

        assert_eq!(table.add(first), FileId(0));
        assert_eq!(table.add(second), FileId(1));
        assert_eq!(table.get(FileId(0)).map(Source::name), Some("first"));
        assert_eq!(table.get(FileId(1)).map(Source::name), Some("second"));
        assert!(table.get(FileId(2)).is_none());
        assert_eq!(
            table
                .iter()
                .map(|(id, source)| (id, source.name()))
                .collect::<Vec<_>>(),
            vec![(FileId(0), "first"), (FileId(1), "second")]
        );
    }
}
