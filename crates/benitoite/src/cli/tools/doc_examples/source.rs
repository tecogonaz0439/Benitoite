//! docの本文・仮想入力と元ソースのUTF-8位置の対応
//! （設計書 02-02「docの位置対応」、07-04「01-12 との対応」）。

use std::ops::Range;

use crate::base::{BytePos, FileId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, FrameName, TraceFrame};
use crate::syntax::ast::{DocComment, Item, Module};

use super::{Expectation, Format, blocks, example};

#[derive(Clone, Debug)]
struct Fragment {
    range: Range<usize>,
    span: Span,
}

impl Fragment {
    fn point(&self, point: usize) -> Option<BytePos> {
        if point < self.range.start || point > self.range.end {
            return None;
        }
        if point == self.range.end {
            return Some(self.span.end);
        }
        let offset = u32::try_from(point.checked_sub(self.range.start)?).ok()?;
        Some(BytePos(self.span.start.0.checked_add(offset)?))
    }
}

/// 仮想入力の範囲を元コメントへ戻す表。対応しない合成範囲は例全体へ戻す。
#[derive(Clone, Debug)]
pub struct SourceMap {
    fragments: Vec<Fragment>,
    length: usize,
    fallback: Span,
}

impl SourceMap {
    /// 環境を引き継ぐ合成ヘッダの後へ本文の対応を移す。合成部は例全体を示す。
    pub fn with_prefix(&self, bytes: usize) -> Self {
        let mut mapped = self.clone();
        mapped.length = mapped.length.saturating_add(bytes);
        for fragment in &mut mapped.fragments {
            fragment.range.start = fragment.range.start.saturating_add(bytes);
            fragment.range.end = fragment.range.end.saturating_add(bytes);
        }
        mapped
    }

    /// 独立したソース表へ元ファイルを加えた後、その番号へ対応を移す。
    pub fn with_original_file(&self, file: FileId) -> Self {
        let mut mapped = self.clone();
        mapped.fallback.file = file;
        for fragment in &mut mapped.fragments {
            fragment.span.file = file;
        }
        mapped
    }

    fn point(&self, point: usize, end: bool) -> Option<BytePos> {
        let index = if end {
            self.fragments
                .partition_point(|fragment| fragment.range.start < point)
                .checked_sub(1)?
        } else {
            self.fragments
                .partition_point(|fragment| fragment.range.end <= point)
        };
        let fragment = self.fragments.get(index).or_else(|| {
            self.fragments
                .last()
                .filter(|fragment| point == self.length && point == fragment.range.end)
        })?;
        fragment.point(point)
    }

    /// 一次・補助位置を元ソースへ戻す。別のファイルの位置はそのまま保つ。
    pub fn map_span(&self, virtual_file: FileId, span: Span) -> Span {
        if span.file != virtual_file {
            return span;
        }
        let Some(start) = usize::try_from(span.start.0).ok() else {
            return self.fallback;
        };
        let Some(end) = usize::try_from(span.end.0).ok() else {
            return self.fallback;
        };
        if start > end || end > self.length {
            return self.fallback;
        }
        let Some(start_pos) = self.point(start, false) else {
            return self.fallback;
        };
        let Some(end_pos) = self.point(end, start != end) else {
            return self.fallback;
        };
        Span {
            file: self.fallback.file,
            start: start_pos,
            end: end_pos,
        }
    }

    fn range(&self, range: Range<usize>) -> Span {
        // 正規化した本文にも専用の番号を必要とせず、同じ表を使う。
        self.map_span(
            self.fallback.file,
            Span {
                file: self.fallback.file,
                start: BytePos(u32::try_from(range.start).unwrap_or(u32::MAX)),
                end: BytePos(u32::try_from(range.end).unwrap_or(u32::MAX)),
            },
        )
    }

    fn slice(&self, range: Range<usize>, fallback: Span) -> Self {
        let mut fragments = Vec::new();
        for fragment in &self.fragments {
            let start = range.start.max(fragment.range.start);
            let end = range.end.min(fragment.range.end);
            if start > end || (start == end && !fragment.range.is_empty()) {
                continue;
            }
            let Some(start_pos) = fragment.point(start) else {
                continue;
            };
            let Some(end_pos) = fragment.point(end) else {
                continue;
            };
            let span = Span {
                file: fragment.span.file,
                start: start_pos,
                end: end_pos,
            };
            fragments.push(Fragment {
                range: start.saturating_sub(range.start)..end.saturating_sub(range.start),
                span,
            });
        }
        Self {
            fragments,
            length: range.end.saturating_sub(range.start),
            fallback,
        }
    }

    /// 診断の位置をまとめて戻す。コメントを壊す可能性のある自動編集は説明だけを保つ。
    pub fn map_diagnostic(&self, virtual_file: FileId, diagnostic: &mut Diagnostic) {
        if let Some(label) = &mut diagnostic.primary {
            label.span = self.map_span(virtual_file, label.span);
        }
        for label in &mut diagnostic.secondary {
            label.span = self.map_span(virtual_file, label.span);
        }
        for help in &mut diagnostic.helps {
            if help.edits.iter().any(|edit| edit.span.file == virtual_file) {
                // 複数編集の一部分だけを出すと修正の意味が変わるため、案全体を説明に戻す。
                help.edits.clear();
            }
        }
        if let Some(trace) = &mut diagnostic.trace {
            for frame in &mut trace.frames {
                self.map_frame(virtual_file, frame);
            }
        }
        for frame in &mut diagnostic.task_origins {
            self.map_frame(virtual_file, frame);
        }
        for waiting in &mut diagnostic.waiting {
            self.map_frame(virtual_file, &mut waiting.task);
            waiting.location = waiting
                .location
                .map(|span| self.map_span(virtual_file, span));
        }
    }

    fn map_frame(&self, virtual_file: FileId, frame: &mut TraceFrame) {
        match &mut frame.name {
            FrameName::Lambda(span)
            | FrameName::Handle(span)
            | FrameName::Lazy(span)
            | FrameName::Case { span, .. } => *span = self.map_span(virtual_file, *span),
            FrameName::Named(_) => {}
        }
        frame.call_site = frame
            .call_site
            .map(|span| self.map_span(virtual_file, span));
    }
}

/// 独立した仮想モジュールへそのまま渡せる例。importや宣言を暗黙に補わない。
#[derive(Clone, Debug)]
pub struct DocExample {
    pub source: String,
    pub expectation: Expectation,
    /// フェンスと期待を含む、元ソースの例全体。
    pub span: Span,
    pub source_map: SourceMap,
}

/// 同じ発見一覧を後の検査・実行・報告へ渡すための読み取り結果。
#[derive(Clone, Debug, Default)]
pub struct Extraction {
    pub examples: Vec<DocExample>,
    pub ignored_blocks: usize,
}

fn normalized(doc: &DocComment) -> (String, SourceMap) {
    let mut text = String::new();
    let mut fragments = Vec::new();
    for (index, line) in doc.lines.iter().enumerate() {
        let raw = doc.text.get(line.text.clone()).unwrap_or_default();
        let body = raw.strip_prefix(' ').unwrap_or(raw);
        let skipped = u32::from(raw.starts_with(' '));
        let start = text.len();
        text.push_str(body);
        fragments.push(Fragment {
            range: start..text.len(),
            span: Span {
                start: BytePos(line.content.start.0.saturating_add(skipped)),
                ..line.content
            },
        });
        if index.saturating_add(1) < doc.lines.len() {
            let start = text.len();
            text.push('\n');
            fragments.push(Fragment {
                range: start..text.len(),
                span: Span {
                    start: line.content.end,
                    end: line.span.end,
                    file: line.span.file,
                },
            });
        }
    }
    let length = text.len();
    (
        text,
        SourceMap {
            fragments,
            length,
            fallback: doc.span,
        },
    )
}

/// 一つのコメントを明示的に実行用として抽出する。通常の構文解析からは呼ばない。
pub fn extract_comment(doc: &DocComment) -> Result<Extraction, Vec<Diagnostic>> {
    let (text, source_map) = normalized(doc);
    let diagnostic = |error: super::ExtractError| {
        vec![
            DiagBuilder::new(DiagCode::E0260)
                .arg("reason", error.reason)
                .primary(source_map.range(error.range))
                .help("syntax")
                .build(),
        ]
    };
    let blocks = blocks(&text).map_err(diagnostic)?;
    let mut extraction = Extraction::default();
    let mut index = 0_usize;
    while index < blocks.len() {
        match example(&blocks, index, Format::Comment).map_err(diagnostic)? {
            Some((example, next)) => {
                let span = source_map.range(example.range);
                extraction.examples.push(DocExample {
                    source: example.source,
                    expectation: example.expectation,
                    span,
                    source_map: source_map.slice(example.content, span),
                });
                index = next;
            }
            None => {
                extraction.ignored_blocks = extraction.ignored_blocks.saturating_add(1);
                index = index.saturating_add(1);
            }
        }
    }
    Ok(extraction)
}

/// モジュール・公開/非公開の宣言・構成子・欄・メソッド・操作のdocを元位置順に集める。
/// import先は辿らず、抽出はこの入口を呼んだときだけ行う。
pub fn extract(module: &Module) -> Result<Extraction, Vec<Diagnostic>> {
    let mut docs = Vec::new();
    docs.extend(module.doc.iter());
    for decl in &module.decls {
        docs.extend(decl.doc.iter());
        match &decl.item {
            Item::Data(data) => {
                for variant in &data.variants {
                    docs.extend(variant.doc.iter());
                }
            }
            Item::Record(record) => {
                for field in &record.fields {
                    docs.extend(field.doc.iter());
                }
            }
            Item::Trait(class) => {
                for method in &class.methods {
                    docs.extend(method.doc.iter());
                }
            }
            Item::Impl(implementation) => {
                for function in &implementation.fns {
                    docs.extend(function.doc.iter());
                }
            }
            Item::Effect(effect) => {
                for operation in &effect.ops {
                    docs.extend(operation.doc.iter());
                }
            }
            Item::Fn(_)
            | Item::Const(_)
            | Item::Alias(_)
            | Item::ExternalType(_)
            | Item::Error(_) => {}
        }
    }
    docs.sort_by_key(|doc| doc.span.start.0);
    let mut extraction = Extraction::default();
    let mut diagnostics = Vec::new();
    for doc in docs {
        match extract_comment(doc) {
            Ok(mut found) => {
                extraction.examples.append(&mut found.examples);
                extraction.ignored_blocks = extraction
                    .ignored_blocks
                    .saturating_add(found.ignored_blocks);
            }
            Err(mut errors) => diagnostics.append(&mut errors),
        }
    }
    if diagnostics.is_empty() {
        Ok(extraction)
    } else {
        Err(diagnostics)
    }
}
