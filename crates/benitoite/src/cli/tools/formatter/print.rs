//! 整形の結果の書き出し（設計書 06-03「字句の間の空白」「字下げ」「コメント」「空の行」「行末と文字」
//! 「複数行の文字列」）。字句の字面は元のソースから写し、AST を出力し直さない（06-03「整形の考え方」）。

use super::roles::RoleTable;
use crate::syntax::token::{Comment, Token};

/// 書き出しの入力。
#[derive(Clone, Copy, Debug)]
pub struct PrintInput<'a> {
    /// 元のソースのバイト列
    pub text: &'a [u8],
    /// `lex` の字句と改行の印の列
    pub tokens: &'a [Token],
    /// `lex` のコメントの一覧（ソースの順）
    pub comments: &'a [Comment],
    pub roles: &'a RoleTable,
}

use super::INDENT_WIDTH;
use super::roles::{BlankBefore, TopKind, TopRange};
use crate::syntax::token::{CommentKind, TokenKind};

/// 整形の結果のバイト列を作る（本章「書き出し」）。
pub fn print(input: &PrintInput<'_>) -> Vec<u8> {
    // 書き手の改行の位置は保つ（06-03「整形の考え方」）ので、改行の印で区切った論理の行を単位に、行の種類（シェバン・空・
    // コメントだけ・コード）を決め、空の行の数と字下げを行ごとに決めてから書き出す（06-03「空の行」「コメント」）。
    let text = input.text;
    let lines = split_lines(input);
    let groups = string_groups(input.tokens, text);
    let tables = Tables::new(input, &lines);
    let mut printer = Printer {
        input,
        lines: &lines,
        groups,
        tables,
        out: Vec::with_capacity(text.len()),
    };
    if text.starts_with(BOM) {
        // 先頭の U+FEFF は残す（06-03「行末と文字」）。
        printer.out.extend_from_slice(BOM);
    }
    let mut previous: Option<usize> = None;
    let mut pending_blanks = 0usize;
    for (index, line) in lines.iter().enumerate() {
        if line.kind == LineKind::Blank {
            pending_blanks = pending_blanks.saturating_add(1);
            continue;
        }
        let blanks = match printer.blank_rule(previous, index) {
            BlankRule::Zero => 0,
            BlankRule::KeepOne => pending_blanks.min(1),
            BlankRule::ExactlyOne => 1,
        };
        for _ in 0..blanks {
            printer.out.push(b'\n');
        }
        printer.write_line(index);
        previous = Some(index);
        pending_blanks = 0;
    }
    // ファイルの終わりの空の行は書かない（後に行がない）。最後の行は `write_line` が改行で終える。
    printer.out
}

/// ファイルの先頭のバイト順マーク（06-03「行末と文字」）。
const BOM: &[u8] = "\u{feff}".as_bytes();

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum LineKind {
    /// ファイルの先頭のシェバンの行（字句解析器が読み飛ばした部分）
    Shebang,
    /// 空白とタブだけの行と、何もない行
    Blank,
    /// コメントだけの行
    Comment,
    /// 字句を含む行
    Code,
}

/// 改行の印で区切った行一つ。複数行の文字列の字句は一つの行の中に収まる。
#[derive(Clone, Debug)]
struct Line {
    kind: LineKind,
    /// 行の字句（改行の印と `Eof` を除く）の添字の範囲
    first: usize,
    end: usize,
    /// 行のコメントの添字
    comment: Option<usize>,
    /// 行の始まりのバイトの位置
    start: usize,
}

/// 空の行の扱い（06-03「空の行」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum BlankRule {
    Zero,
    KeepOne,
    ExactlyOne,
}

/// 文字列の字句の組（補間を含む文字列は開始から終わりまで）。複数行の文字列の内容の行を動かす量を共有する。
#[derive(Clone, Debug)]
struct StringGroup {
    first: usize,
    last: usize,
    /// 組のどれかの字句が改行を含むか（複数行の文字列か）。`StrStart` に改行がなく後の `StrMid` に改行がある組があるので、
    /// 字句の単位でなく組の単位で決める
    multiline: bool,
    /// 開きの `"""` を含む行の字下げの変化の量（06-03「複数行の文字列」の `b - a`）。組の最初の字句を書くときに決める
    delta: Option<isize>,
}

struct Printer<'p, 'a> {
    input: &'p PrintInput<'a>,
    lines: &'p [Line],
    /// 字句の添字ごとの、文字列の字句の組の添字
    groups: Groups,
    tables: Tables,
    out: Vec<u8>,
}

/// 行と宣言を引く表。行ごと・字句ごとに前もって作り、行の数×宣言の数の線形探索を避ける（D02 の確認の直し）。
struct Tables {
    /// 行の添字ごとの、その行から後（その行を含む）の最初のコードの行
    next_code: Vec<Option<usize>>,
    /// 字句の添字ごとの、その字句を含むコードの行
    line_of_token: Vec<Option<usize>>,
    /// 行の添字ごとの、その行に最後の字句があるトップレベルの宣言の並びの位置（最初のもの）
    top_ending: Vec<Option<usize>>,
}

impl Tables {
    fn new(input: &PrintInput<'_>, lines: &[Line]) -> Tables {
        let mut next_code = vec![None; lines.len()];
        let mut following = None;
        for (index, line) in lines.iter().enumerate().rev() {
            if line.kind == LineKind::Code {
                following = Some(index);
            }
            if let Some(slot) = next_code.get_mut(index) {
                *slot = following;
            }
        }
        let mut line_of_token = vec![None; input.tokens.len()];
        for (index, line) in lines.iter().enumerate() {
            if line.kind != LineKind::Code {
                continue;
            }
            for slot in line_of_token.iter_mut().take(line.end).skip(line.first) {
                *slot = Some(index);
            }
        }
        let mut top_ending = vec![None; lines.len()];
        for (pos, top) in input.roles.top.iter().enumerate() {
            let line = line_of_token.get(top.last).copied().flatten();
            if let Some(slot) = line.and_then(|l| top_ending.get_mut(l))
                && slot.is_none()
            {
                *slot = Some(pos);
            }
        }
        Tables {
            next_code,
            line_of_token,
            top_ending,
        }
    }
}

struct Groups {
    of_token: Vec<Option<usize>>,
    list: Vec<StringGroup>,
}

fn split_lines(input: &PrintInput<'_>) -> Vec<Line> {
    let text = input.text;
    let mut lines = Vec::new();
    let mut comment_cursor = 0usize;
    let mut line_start = 0usize;
    let mut first = 0usize;
    for (index, token) in input.tokens.iter().enumerate() {
        if !matches!(token.kind, TokenKind::LineBreak | TokenKind::Eof) {
            continue;
        }
        let boundary = span_start(token);
        let mut comment = None;
        while let Some(c) = input.comments.get(comment_cursor) {
            if usize::try_from(c.span.start.0).unwrap_or(usize::MAX) >= boundary {
                break;
            }
            comment = Some(comment_cursor);
            comment_cursor = comment_cursor.saturating_add(1);
        }
        let kind = if first < index {
            LineKind::Code
        } else if comment.is_some() {
            LineKind::Comment
        } else if lines.is_empty() && is_shebang(text) {
            LineKind::Shebang
        } else {
            LineKind::Blank
        };
        // `Eof` の前に何もない最後の行は、ファイルの終わりが改行で終わったことを示すだけで、行ではない。
        let trailing_empty = token.kind == TokenKind::Eof
            && kind == LineKind::Blank
            && text.get(line_start..boundary).is_none_or(<[u8]>::is_empty);
        if !trailing_empty {
            lines.push(Line {
                kind,
                first,
                end: index,
                comment,
                start: line_start,
            });
        }
        line_start = span_end(token);
        first = index.saturating_add(1);
    }
    lines
}

/// ファイルの先頭（U+FEFF の後）が `#!` で始まるか（01-01「シェバンの行（初回リリース版）」）。
fn is_shebang(text: &[u8]) -> bool {
    text.strip_prefix(BOM).unwrap_or(text).starts_with(b"#!")
}

fn string_groups(tokens: &[Token], text: &[u8]) -> Groups {
    let mut of_token = vec![None; tokens.len()];
    let mut list: Vec<StringGroup> = Vec::new();
    let mut stack: Vec<usize> = Vec::new();
    for (index, token) in tokens.iter().enumerate() {
        let group = if token.kind == TokenKind::StringLit || token.kind == TokenKind::StrStart {
            list.push(StringGroup {
                first: index,
                last: index,
                multiline: false,
                delta: None,
            });
            let id = list.len().saturating_sub(1);
            if token.kind == TokenKind::StrStart {
                stack.push(id);
            }
            Some(id)
        } else if token.kind == TokenKind::StrMid {
            stack.last().copied()
        } else if token.kind == TokenKind::StrEnd {
            stack.pop()
        } else {
            None
        };
        if let Some(id) = group {
            let has_newline = text
                .get(span_start(token)..span_end(token))
                .is_some_and(|raw| raw.contains(&b'\n'));
            if let Some(g) = list.get_mut(id) {
                g.last = index;
                g.multiline |= has_newline;
            }
            if let Some(slot) = of_token.get_mut(index) {
                *slot = Some(id);
            }
        }
    }
    Groups { of_token, list }
}

impl Printer<'_, '_> {
    fn line(&self, index: usize) -> Option<&Line> {
        self.lines.get(index)
    }

    fn role(&self, token: usize) -> super::roles::TokenRole {
        self.input
            .roles
            .roles
            .get(token)
            .copied()
            .unwrap_or_default()
    }

    /// `from` から後（`from` を含む）の最初のコードの行。
    fn next_code(&self, from: usize) -> Option<usize> {
        self.tables.next_code.get(from).copied().flatten()
    }

    /// 字句の添字を含む行の添字。
    fn line_of_token(&self, token: usize) -> Option<usize> {
        self.tables.line_of_token.get(token).copied().flatten()
    }

    /// 行 `index` の前の空の行の扱い。`previous` は前の空でない行（06-03「空の行」）。
    fn blank_rule(&self, previous: Option<usize>, index: usize) -> BlankRule {
        let Some(prev_index) = previous else {
            return BlankRule::Zero;
        };
        let (Some(prev), Some(_line)) = (self.line(prev_index), self.line(index)) else {
            return BlankRule::Zero;
        };
        // シェバンの行と `//!` の行の後は一つまで。
        if prev.kind == LineKind::Shebang || self.is_module_doc(prev) {
            return BlankRule::KeepOne;
        }
        // トップレベルの宣言の最後の行（行末のコメントを含む）の後。
        if let Some((pos, top)) = self.top_ending_at(prev_index) {
            let next_top = self.input.roles.top.get(pos.saturating_add(1));
            let next_code = self.next_code(index);
            let same_kind = next_top.is_some_and(|n| {
                n.kind == top.kind
                    && matches!(top.kind, TopKind::Import | TopKind::Const)
                    && next_code.is_some()
                    && next_code == self.line_of_token(n.first)
            });
            return if same_kind {
                BlankRule::KeepOne
            } else {
                BlankRule::ExactlyOne
            };
        }
        let Some(code_index) = self.next_code(index) else {
            return BlankRule::KeepOne;
        };
        let Some(code) = self.line(code_index) else {
            return BlankRule::KeepOne;
        };
        let role = self.role(code.first);
        if role.blank_before == BlankBefore::KeepOne {
            return BlankRule::KeepOne;
        }
        // `Remove` の行の前にコメントだけの行があるときは、最初の字句の種類で除く位置を分ける
        // （D02「手順の要点」の 2 の近似。凍結した `BlankBefore` は除く理由を持たない）。
        let closing = role.inner_level.is_some()
            || self
                .input
                .tokens
                .get(code.first)
                .is_some_and(|t| matches!(t.kind, TokenKind::KwElse | TokenKind::KwWith));
        if closing {
            // 閉じの字句・`else`・`with` の直前の空の行だけを除く。
            if index == code_index {
                BlankRule::Zero
            } else {
                BlankRule::KeepOne
            }
        } else if prev.kind == LineKind::Comment {
            BlankRule::KeepOne
        } else {
            // 前のコードの行と、コメントだけの行か字句の行との間の空の行を除く。
            BlankRule::Zero
        }
    }

    fn is_module_doc(&self, line: &Line) -> bool {
        line.kind == LineKind::Comment
            && line
                .comment
                .and_then(|c| self.input.comments.get(c))
                .is_some_and(|c| c.kind == CommentKind::ModuleDoc)
    }

    /// 行が最後の字句を含むトップレベルの宣言と、その並びの位置。
    fn top_ending_at(&self, line: usize) -> Option<(usize, TopRange)> {
        let pos = self.tables.top_ending.get(line).copied().flatten()?;
        self.input.roles.top.get(pos).map(|t| (pos, *t))
    }

    fn write_line(&mut self, index: usize) {
        let Some(line) = self.line(index).cloned() else {
            return;
        };
        let text = self.input.text;
        match line.kind {
            LineKind::Blank => {}
            LineKind::Shebang => {
                // シェバンの行は行末の空白も含めてそのまま残す。CR LF の CR は改行の一部として除く。
                let start = if line.start == 0 && text.starts_with(BOM) {
                    BOM.len()
                } else {
                    line.start
                };
                let end = self
                    .input
                    .tokens
                    .get(line.end)
                    .map_or(text.len(), span_start);
                let raw = text.get(start..end).unwrap_or(&[]);
                self.out.extend_from_slice(raw);
            }
            LineKind::Comment => {
                // コメントだけの行は、後の最初のコードの行の段（閉じの字句なら閉じる構文の中の段）に置く。
                let level = self
                    .next_code(index)
                    .and_then(|i| self.line(i))
                    .map_or(0, |code| {
                        let role = self.role(code.first);
                        role.inner_level.unwrap_or(role.level)
                    });
                self.indent(level);
                self.write_comment(line.comment);
            }
            LineKind::Code => {
                for token_index in line.first..line.end {
                    let role = self.role(token_index);
                    if token_index == line.first {
                        self.indent(role.level);
                    } else if role.space_before {
                        // 同じ行の字句の間の空白とタブは、空白一つか何もなしに置き換える（06-03「字句の間の空白」）。
                        self.out.push(b' ');
                    }
                    self.write_token(token_index);
                }
                if line.comment.is_some() {
                    // 行末のコメントの前は空白一つ（06-03「コメント」）。
                    self.out.push(b' ');
                    self.write_comment(line.comment);
                }
            }
        }
        self.out.push(b'\n');
    }

    fn indent(&mut self, level: u32) {
        let width = usize::try_from(level).map_or(0, |level| level.saturating_mul(INDENT_WIDTH));
        self.out.resize(self.out.len().saturating_add(width), b' ');
    }

    /// コメントを、行末の空白とタブを除いて写す（06-03「コメント」「行末と文字」）。
    fn write_comment(&mut self, comment: Option<usize>) {
        let Some(c) = comment.and_then(|c| self.input.comments.get(c)) else {
            return;
        };
        let start = usize::try_from(c.span.start.0).unwrap_or(usize::MAX);
        let end = usize::try_from(c.span.end.0).unwrap_or(usize::MAX);
        let raw = self.input.text.get(start..end).unwrap_or(&[]);
        self.out.extend_from_slice(trim_end_blank(raw));
    }

    /// 字句の字面を写す。複数行の文字列の字句は、内容の行と閉じの行を開きの行の字下げの変化だけ動かす
    /// （06-03「複数行の文字列」）。
    fn write_token(&mut self, index: usize) {
        let Some(token) = self.input.tokens.get(index) else {
            return;
        };
        let text = self.input.text;
        let start = span_start(token);
        let raw = text.get(start..span_end(token)).unwrap_or(&[]);
        let group = self.groups.of_token.get(index).copied().flatten();
        if let Some(id) = group {
            // 字下げの差は複数行の文字列の組でだけ要る。1 行の文字列ごとに行の頭まで後ろへ走査すると、1 行に文字列が
            // 多いときに時間が二乗で増える（D02 の確認の直し）。
            let is_first = self
                .groups
                .list
                .get(id)
                .is_some_and(|g| g.first == index && g.multiline);
            if is_first {
                // 開きの行の整形の前の字下げ `a` と後の字下げ `b`。
                let before = leading_blank(text, line_start_of(text, start));
                let after = leading_blank(&self.out, out_line_start(&self.out));
                let delta = isize::try_from(after)
                    .unwrap_or(0)
                    .saturating_sub(isize::try_from(before).unwrap_or(0));
                if let Some(g) = self.groups.list.get_mut(id) {
                    g.delta = Some(delta);
                }
            }
        }
        if !raw.contains(&b'\n') {
            self.out.extend_from_slice(raw);
            return;
        }
        let (delta, closing) =
            group
                .and_then(|id| self.groups.list.get(id))
                .map_or((0, Vec::new()), |g| {
                    let closing = self.input.tokens.get(g.last).map_or(Vec::new(), |last| {
                        let end = span_end(last).saturating_sub(1);
                        let line = line_start_of(text, end);
                        let n = leading_blank(text, line);
                        text.get(line..line.saturating_add(n))
                            .unwrap_or(&[])
                            .to_vec()
                    });
                    (g.delta.unwrap_or(0), closing)
                });
        let fill = closing.first().copied().unwrap_or(b' ');
        let mut pieces = raw.split(|&b| b == b'\n').peekable();
        let mut first = true;
        while let Some(piece) = pieces.next() {
            let is_last = pieces.peek().is_none();
            // CR LF は LF にする（06-03「行末と文字」）。
            let piece = if is_last {
                piece
            } else {
                piece.strip_suffix(b"\r").unwrap_or(piece)
            };
            if first {
                self.out.extend_from_slice(piece);
                first = false;
                continue;
            }
            self.out.push(b'\n');
            if !is_last && piece.iter().all(|&b| b == b' ' || b == b'\t') {
                // 内容の空の行は何もない行にする。
                continue;
            }
            if delta >= 0 {
                let add = usize::try_from(delta).unwrap_or(0);
                self.out.resize(self.out.len().saturating_add(add), fill);
                self.out.extend_from_slice(piece);
            } else {
                let remove = delta
                    .unsigned_abs()
                    .min(closing.len())
                    .min(leading_blank(piece, 0));
                self.out
                    .extend_from_slice(piece.get(remove..).unwrap_or(&[]));
            }
        }
    }
}

/// 行末の空白とタブを除く。
fn trim_end_blank(bytes: &[u8]) -> &[u8] {
    let mut end = bytes.len();
    while end > 0 && matches!(bytes.get(end.saturating_sub(1)), Some(b' ' | b'\t')) {
        end = end.saturating_sub(1);
    }
    bytes.get(..end).unwrap_or(&[])
}

/// 位置 `pos` を含む物理の行の始まり（行 0 では U+FEFF の後）。
fn line_start_of(text: &[u8], pos: usize) -> usize {
    let before = text.get(..pos).unwrap_or(text);
    match before.iter().rposition(|&b| b == b'\n') {
        Some(i) => i.saturating_add(1),
        None if text.starts_with(BOM) => BOM.len(),
        None => 0,
    }
}

/// 書き出し中の最後の行の始まり。
fn out_line_start(out: &[u8]) -> usize {
    line_start_of(out, out.len())
}

/// `from` から続く空白とタブの数（06-03「複数行の文字列」の字下げの文字数）。
fn leading_blank(bytes: &[u8], from: usize) -> usize {
    bytes
        .get(from..)
        .unwrap_or(&[])
        .iter()
        .take_while(|&&b| b == b' ' || b == b'\t')
        .count()
}

fn span_start(token: &Token) -> usize {
    usize::try_from(token.span.start.0).unwrap_or(usize::MAX)
}

fn span_end(token: &Token) -> usize {
    usize::try_from(token.span.end.0).unwrap_or(usize::MAX)
}

#[cfg(test)]
mod tests;
