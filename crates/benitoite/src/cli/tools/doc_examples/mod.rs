//! 文書例の共通の抽出と期待値。実行と権限の照合は呼び出し側が行う
//! （設計書 01-02「ドキュメントコメント（初回リリース版）」、02-02「docの位置対応」）。

use std::ops::Range;

use crate::diag::DiagCode;

pub use source::{DocExample, Extraction, SourceMap, extract, extract_comment};

mod input;
mod source;
pub use input::VirtualInput;
#[cfg(test)]
mod tests;
mod text;

/// フェンスの本文。範囲は入力のUTF-8バイト位置である。
#[derive(Clone, Debug, PartialEq)]
pub struct Block {
    pub info: String,
    /// 開きの行（1始まり）。
    pub line: usize,
    /// 開きから閉じまでの範囲。
    pub range: Range<usize>,
    /// フェンスを含まない本文の範囲。
    pub content: Range<usize>,
    /// 改行をLFにそろえた本文。最後の内容行の改行も含む。
    pub body: String,
}

/// 抽出時の形式不良。docでは元位置へ戻してE0260にする。
#[derive(Clone, Debug, PartialEq)]
pub struct ExtractError {
    pub range: Range<usize>,
    pub reason: String,
}

impl ExtractError {
    fn new(range: Range<usize>, reason: &str) -> Self {
        Self {
            range,
            reason: reason.to_string(),
        }
    }
}

/// 行頭の空白に続く三連バッククォートを読み取る。本文の字下げは保存する。
pub fn blocks(text: &str) -> Result<Vec<Block>, ExtractError> {
    let mut result = Vec::new();
    let mut open: Option<Block> = None;
    let mut offset = 0_usize;
    for (index, raw) in text.split_inclusive('\n').enumerate() {
        let line = raw.strip_suffix('\n').unwrap_or(raw);
        let line = line.strip_suffix('\r').unwrap_or(line);
        let fence = line.trim_start();
        let end = offset.saturating_add(raw.len());
        if let Some(block) = open.as_mut() {
            if fence == "```" {
                block.content.end = offset;
                block.range.end = end;
                if let Some(block) = open.take() {
                    result.push(block);
                }
            } else {
                block.body.push_str(line);
                if raw.ends_with('\n') {
                    block.body.push('\n');
                }
            }
        } else if let Some(info) = fence.strip_prefix("```") {
            // 三連以外のフェンスを実行用の印として読まない。
            if !info.starts_with('`') {
                open = Some(Block {
                    info: info.trim().to_string(),
                    line: index.saturating_add(1),
                    range: offset..end,
                    content: end..end,
                    body: String::new(),
                });
            }
        }
        offset = end;
    }
    if let Some(block) = open {
        return Err(ExtractError::new(block.range, text::UNCLOSED));
    }
    Ok(result)
}

/// 実行・検査の期待値。Markdown固有の終了状態も同じ型で保持する。
#[derive(Clone, Debug, PartialEq)]
pub enum Expectation {
    Run {
        stdout: String,
        stderr: String,
        exit: u8,
    },
    Static,
    Test,
    Error {
        lines: Vec<String>,
    },
}

impl Expectation {
    /// errorの各非空行を、順序を問わず報告全体に含むか。
    pub fn matches_diagnostics(&self, report: &str) -> bool {
        matches!(self, Self::Error { lines } if lines.iter().all(|line| report.contains(line)))
    }

    /// error例で必須にする、実在するEコードだけの行。
    pub fn diagnostic_codes(&self) -> Vec<DiagCode> {
        match self {
            Self::Error { lines } => lines.iter().filter_map(|line| error_code(line)).collect(),
            Self::Run { .. } | Self::Static | Self::Test => Vec::new(),
        }
    }
}

fn error_code(line: &str) -> Option<DiagCode> {
    let id = line.trim();
    id.starts_with('E').then(|| DiagCode::from_id(id)).flatten()
}

/// コメントとリポジトリのMarkdownで異なる入力契約。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Format {
    Comment,
    Markdown,
}

/// 共通の抽出結果。期待ブロックまで含む範囲と、コード本文の範囲を区別する。
#[derive(Clone, Debug, PartialEq)]
pub struct Example {
    pub line: usize,
    pub range: Range<usize>,
    pub content: Range<usize>,
    pub source: String,
    pub expectation: Expectation,
}

/// `index`のブロックと直後の期待を読み、例と次の未消費の位置を返す。
/// 対象外のブロックはNone。filesはMarkdownの入力アダプタで処理する。
pub fn example(
    blocks: &[Block],
    index: usize,
    format: Format,
) -> Result<Option<(Example, usize)>, ExtractError> {
    let Some(block) = blocks.get(index) else {
        return Ok(None);
    };
    let mut next = index.saturating_add(1);
    let expectation = match block.info.as_str() {
        "benitoite test" => Expectation::Test,
        "benitoite check" => Expectation::Static,
        "benitoite error" => {
            let diagnostic = required(blocks, next, "diagnostic", block, text::DIAGNOSTIC)?;
            next = next.saturating_add(1);
            let expectation = Expectation::Error {
                lines: diagnostic
                    .body
                    .lines()
                    .filter(|line| !line.trim().is_empty())
                    .map(str::to_string)
                    .collect(),
            };
            if format == Format::Comment && expectation.diagnostic_codes().is_empty() {
                return Err(ExtractError::new(
                    diagnostic.range.clone(),
                    text::ERROR_CODE,
                ));
            }
            expectation
        }
        "benitoite" => {
            let output = required(blocks, next, "output", block, text::OUTPUT)?;
            next = next.saturating_add(1);
            let mut lines: Vec<&str> = output.body.lines().collect();
            let code = lines
                .last()
                .and_then(|line| line.strip_prefix("exit "))
                .and_then(|code| code.parse::<u8>().ok());
            if code.is_some() {
                lines.pop();
            }
            let exit = code.unwrap_or(0);
            if format == Format::Comment && exit != 0 {
                return Err(ExtractError::new(output.range.clone(), text::EXIT));
            }
            let stdout = lines.iter().map(|line| format!("{line}\n")).collect();
            let stderr = if let Some(stderr) = blocks.get(next).filter(|b| b.info == "stderr") {
                next = next.saturating_add(1);
                stderr.body.clone()
            } else {
                String::new()
            };
            Expectation::Run {
                stdout,
                stderr,
                exit,
            }
        }
        "files" if format == Format::Comment => {
            return Err(ExtractError::new(block.range.clone(), text::FILES));
        }
        "output" | "stderr" | "diagnostic" => {
            return Err(ExtractError::new(block.range.clone(), text::ORPHAN));
        }
        info if info.starts_with("benitoite") => {
            return Err(ExtractError::new(block.range.clone(), text::UNKNOWN));
        }
        _ => return Ok(None),
    };
    let last = blocks.get(next.saturating_sub(1)).unwrap_or(block);
    Ok(Some((
        Example {
            line: block.line,
            range: block.range.start..last.range.end,
            content: block.content.clone(),
            source: block.body.clone(),
            expectation,
        },
        next,
    )))
}

fn required<'a>(
    blocks: &'a [Block],
    index: usize,
    info: &str,
    owner: &Block,
    reason: &str,
) -> Result<&'a Block, ExtractError> {
    blocks
        .get(index)
        .filter(|block| block.info == info)
        .ok_or_else(|| ExtractError::new(owner.range.clone(), reason))
}
