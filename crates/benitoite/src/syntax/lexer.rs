//! 字句の切り出し（設計書 02-03「処理の流れ」の工程 1、「字句」「コメント」）。
//!
//! ソースのバイト列を先頭から読み、字句と改行の印（`LineBreak`）の列、コメントの一覧、
//! 字句の誤りの診断を作る。字句の規則は設計書 01-01「字句構造」に従う。
//! 改行の印を NEWLINE にするか捨てるかは、次の工程（newline.rs）が決める。
//!
//! 誤りを報告した後も読み続け、一つのソースで見つけられる字句の誤りをできるだけ多く報告する
//! （02-03「字句」の最後の段落）。許されない文字と字句に使えない記号は 1 文字を読み飛ばし、
//! 閉じていないリテラルは行の終わりで閉じたものとして扱う。予約語と、誤りを含むリテラルは
//! 誤りの字句（`TokenKind::Error`）にして、構文解析器が重ねて構文エラーを出さないようにする。

use super::token::{Comment, Token, TokenKind, TokenValue};
use crate::base::{BytePos, FileId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};

/// 字句の切り出しの結果。
#[derive(Debug)]
pub struct LexOutput {
    /// 字句と改行の印（`LineBreak`）の列。最後は必ず `Eof`
    pub tokens: Vec<Token>,
    pub comments: Vec<Comment>,
    pub diagnostics: Vec<Diagnostic>,
}

/// ソースのバイト列（`Source::text()`）を先頭から読み、字句と改行の印の列を作る（02-03「処理の流れ」の 1）。
/// span のファイル ID には `file` を使う。誤りを報告した後も続ける（02-03「字句」の最後の段落）。
/// ソースの表に依存しない形にして、T04 を待たずに実装とテストができるようにしてある。
pub fn lex(file: FileId, text: &[u8]) -> LexOutput {
    let mut lexer = Lexer {
        file,
        text,
        tokens: Vec::new(),
        comments: Vec::new(),
        diagnostics: Vec::new(),
    };
    lexer.run();
    LexOutput {
        tokens: lexer.tokens,
        comments: lexer.comments,
        diagnostics: lexer.diagnostics,
    }
}

/// ファイルの先頭のバイト順マーク（U+FEFF の UTF-8 の符号化）。
const BOM: &[u8] = &[0xEF, 0xBB, 0xBF];

/// リテラルの種類。エスケープの規則と、誤りの注記の鍵が変わる（01-01「文字リテラル」）。
#[derive(Clone, Copy, PartialEq, Eq)]
enum Quote {
    /// 文字列リテラル `"..."`
    Double,
    /// 文字リテラル `'...'`
    Single,
}

impl Quote {
    /// 正しくないエスケープ（E0110）に付ける注記の鍵（10-02 の E0110 の extras）。
    fn valid_escapes_key(self) -> &'static str {
        match self {
            Quote::Double => "valid_string",
            Quote::Single => "valid_char",
        }
    }
}

/// 字句を切り出す途中の状態。検査ごとに作り、大域の状態を持たない（ADR 0015）。
struct Lexer<'a> {
    file: FileId,
    text: &'a [u8],
    tokens: Vec<Token>,
    comments: Vec<Comment>,
    diagnostics: Vec<Diagnostic>,
}

impl Lexer<'_> {
    fn run(&mut self) {
        // 先頭の BOM は字句にも誤りにもしない。位置は BOM を含めて数える（01-01、02-02「span」）。
        let mut i = if self.text.starts_with(BOM) {
            BOM.len()
        } else {
            0
        };
        while let Some(b) = self.byte(i) {
            i = match b {
                b' ' | b'\t' => add(i, 1),
                b'\n' => {
                    self.push(TokenKind::LineBreak, i, add(i, 1), TokenValue::None);
                    add(i, 1)
                }
                b'\r' => {
                    if self.byte(add(i, 1)) == Some(b'\n') {
                        // CR LF は一つの改行。印の span は 2 バイトを覆う（01-01「改行」）
                        self.push(TokenKind::LineBreak, i, add(i, 2), TokenValue::None);
                        add(i, 2)
                    } else {
                        // LF を伴わない CR は誤りとし、改行の印にしない
                        self.report(
                            DiagBuilder::new(DiagCode::E0107).primary(self.span(i, add(i, 1))),
                        );
                        add(i, 1)
                    }
                }
                b'a'..=b'z' | b'A'..=b'Z' | b'_' => self.ident(i),
                b'0'..=b'9' => self.number(i),
                b'"' => self.string(i),
                b'\'' => self.char_lit(i),
                b'/' if self.byte(add(i, 1)) == Some(b'/') => self.comment(i),
                0x21..=0x7E => self.symbol(i, b),
                0x00..=0x7F => {
                    // タブ・LF・CR 以外の ASCII の制御文字は、リテラルとコメントの外に置けない
                    self.report_not_allowed(i, 1, char::from(b));
                    add(i, 1)
                }
                _ => self.non_ascii_outside(i),
            };
        }
        let end = self.text.len();
        self.push(TokenKind::Eof, end, end, TokenValue::None);
    }

    // ---- 補助 ----

    fn byte(&self, i: usize) -> Option<u8> {
        self.text.get(i).copied()
    }

    fn slice(&self, start: usize, end: usize) -> &[u8] {
        self.text.get(start..end).unwrap_or(&[])
    }

    fn lossy(&self, start: usize, end: usize) -> String {
        String::from_utf8_lossy(self.slice(start, end)).into_owned()
    }

    fn span(&self, start: usize, end: usize) -> Span {
        Span {
            file: self.file,
            start: byte_pos(start),
            end: byte_pos(end),
        }
    }

    fn push(&mut self, kind: TokenKind, start: usize, end: usize, value: TokenValue) {
        let span = self.span(start, end);
        self.tokens.push(Token { kind, span, value });
    }

    fn report(&mut self, builder: DiagBuilder) {
        self.diagnostics.push(builder.build());
    }

    /// リテラル全体に付く診断を、そのリテラルの中の誤りより前に置く。
    /// 診断の列をソースの位置の順に保つため（リテラルの開始はその中の誤りより前にある）。
    fn report_at(&mut self, index: usize, builder: DiagBuilder) {
        let index = index.min(self.diagnostics.len());
        self.diagnostics.insert(index, builder.build());
    }

    /// `from` を含む行の終わりの位置。改行（LF、または CR LF の CR）の位置か、ソースの終わり。
    /// 文字列リテラル・文字リテラル・コメントは、この位置を越えない（01-01）。
    fn line_end(&self, from: usize) -> usize {
        let rest = self.text.get(from..).unwrap_or(&[]);
        match rest.iter().position(|b| *b == b'\n') {
            Some(offset) => {
                let lf = add(from, offset);
                let before = lf.saturating_sub(1);
                if lf > from && self.byte(before) == Some(b'\r') {
                    before
                } else {
                    lf
                }
            }
            None => self.text.len(),
        }
    }

    // ---- 文字集合の誤り（01-01「ソースファイルと文字集合」） ----

    /// 正しい UTF-8 の並びの先頭にならないバイトから、次に正しく読めるバイトの手前までを
    /// 一つの誤り（E0102）にする。連続する正しくないバイトごとに診断を出すと数が膨らむため。
    /// 戻り値は読み飛ばした後の位置で、必ず `start` より後ろになる。
    fn invalid_utf8(&mut self, start: usize, limit: usize) -> usize {
        let mut j = add(start, 1);
        while j < limit && decode(self.text, j).is_none() {
            j = add(j, 1);
        }
        self.report(DiagBuilder::new(DiagCode::E0102).primary(self.span(start, j)));
        j
    }

    /// 双方向の制御文字と先頭以外の U+FEFF（E0104）。場所によらず誤りにする（ADR 0051）。
    /// `escape_help` が真なら、値に含めるときのエスケープを修正案として示す。修正案を示すのは
    /// 文字列リテラルと文字リテラルの中だけで、コメントの中と字句の間では示さない（02-03「字句」）。
    fn report_invisible(&mut self, start: usize, len: usize, c: char, escape_help: bool) {
        let span = self.span(start, add(start, len));
        let builder = DiagBuilder::new(DiagCode::E0104)
            .arg("char", code_point(c))
            .arg("escape", unicode_escape_text(c))
            .primary(span);
        let builder = if escape_help {
            builder.help("escape")
        } else {
            builder
        };
        self.report(builder);
    }

    /// リテラルとコメントの外の許されない文字（E0103）。
    fn report_not_allowed(&mut self, start: usize, len: usize, c: char) {
        let span = self.span(start, add(start, len));
        self.report(
            DiagBuilder::new(DiagCode::E0103)
                .arg("char", code_point(c))
                .primary(span)
                .note("allowed"),
        );
    }

    /// リテラルとコメントの外の、ASCII でない文字。どれも字句にならないので、誤りを報告して読み飛ばす。
    fn non_ascii_outside(&mut self, i: usize) -> usize {
        match decode(self.text, i) {
            None => self.invalid_utf8(i, self.text.len()),
            Some((c, len)) => {
                if is_invisible(c) {
                    self.report_invisible(i, len, c, false);
                } else {
                    self.report_not_allowed(i, len, c);
                }
                add(i, len)
            }
        }
    }

    /// 字句を作らずに読み進める範囲（コメントの本文）で、
    /// 場所によらない誤りだけを報告する: 正しくない UTF-8（E0102）、双方向の制御文字と
    /// U+FEFF（E0104）、LF を伴わない CR（E0107）。
    fn scan_raw(&mut self, from: usize, limit: usize) {
        let mut j = from;
        while j < limit {
            let Some(b) = self.byte(j) else {
                break;
            };
            j = if b == b'\r' {
                // `limit` は CR LF の CR の位置なので、ここに来る CR は LF を伴わない
                self.report(DiagBuilder::new(DiagCode::E0107).primary(self.span(j, add(j, 1))));
                add(j, 1)
            } else if b.is_ascii() {
                add(j, 1)
            } else {
                match decode(self.text, j) {
                    None => self.invalid_utf8(j, limit),
                    Some((c, len)) => {
                        if is_invisible(c) {
                            self.report_invisible(j, len, c, false);
                        }
                        add(j, len)
                    }
                }
            };
        }
    }

    // ---- コメント（01-01「コメント」、02-03「コメント」） ----

    /// `//` から行末までを一つのコメントにする。本文は `//` の後から行末まで（CR LF の CR を含めない）。
    /// コメントは字句の列に入れず、別の一覧に集める（ADR 0021）。
    fn comment(&mut self, start: usize) -> usize {
        let limit = self.line_end(start);
        let body = add(start, 2);
        self.scan_raw(body, limit);
        let comment = Comment {
            span: self.span(start, limit),
            text: self.lossy(body, limit),
        };
        self.comments.push(comment);
        limit
    }

    // ---- 識別子とキーワード（01-01「識別子」「キーワード」） ----

    fn ident(&mut self, start: usize) -> usize {
        let mut end = start;
        while self.byte(end).is_some_and(is_ident_byte) {
            end = add(end, 1);
        }
        let word = self.lossy(start, end);
        if word == "_" {
            self.push(TokenKind::Underscore, start, end, TokenValue::None);
        } else if let Some(kind) = keyword(&word) {
            self.push(kind, start, end, TokenValue::None);
        } else if let Some(hint) = reserved_hint(&word) {
            // 予約語は最小実行版では意味を持たないので、どの位置でも誤りにする（02-03「字句」）
            let span = self.span(start, end);
            self.report(
                DiagBuilder::new(DiagCode::E0117)
                    .arg("word", word)
                    .primary(span)
                    .help(hint),
            );
            self.push(TokenKind::Error, start, end, TokenValue::None);
        } else {
            let kind = if word.starts_with(|c: char| c.is_ascii_uppercase()) {
                TokenKind::UpperIdent
            } else {
                TokenKind::LowerIdent
            };
            self.push(kind, start, end, TokenValue::Ident(word));
        }
        end
    }

    // ---- 数値リテラル（01-01「整数リテラル」「浮動小数リテラル」「数値リテラルの直後の文字」） ----

    /// 数字で始まる「数値の塊」を切り出し、一つの字句にする。
    /// 塊を先に切り出してから形を調べるのは、`12abc` や `1.5.2` を二つの字句に分けず、
    /// 一つの誤りとして報告するためである（ADR 0051）。
    fn number(&mut self, start: usize) -> usize {
        let end = self.number_chunk_end(start);
        let chunk = self.slice(start, end);
        match classify_number(chunk) {
            Ok((kind, value)) => self.push(kind, start, end, value),
            Err((code, key)) => {
                let text = self.lossy(start, end);
                let span = self.span(start, end);
                self.report(
                    DiagBuilder::new(code)
                        .arg("text", text)
                        .primary_label(span, key),
                );
                self.push(TokenKind::Error, start, end, TokenValue::None);
            }
        }
        end
    }

    /// 数値の塊の終わり。塊は、英字・数字・`_` と、`.` の直後に数字が続く部分と、
    /// 10 進の指数部の符号（`e`・`E` の直後の `+`・`-`）を、続く限り含める。
    fn number_chunk_end(&self, start: usize) -> usize {
        // 接頭辞付き（`0x` など）の塊では、`e` は 16 進の数字であり指数部ではない。
        // `0x1e+2` を `0x1e` と `+` と `2` に分けるため、符号を含めない。
        let prefixed = self.byte(start) == Some(b'0')
            && matches!(
                self.byte(add(start, 1)),
                Some(b'x' | b'X' | b'o' | b'O' | b'b' | b'B')
            );
        let mut j = start;
        while let Some(b) = self.byte(j) {
            if is_ident_byte(b) {
                j = add(j, 1);
                if !prefixed
                    && matches!(b, b'e' | b'E')
                    && matches!(self.byte(j), Some(b'+' | b'-'))
                {
                    j = add(j, 1);
                }
            } else if b == b'.' {
                match self.byte(add(j, 1)) {
                    Some(n) if n.is_ascii_digit() => j = add(j, 2),
                    // `1.foo` は `1` と `.` と `foo`。構文解析器がドット記法の誤りを報告する
                    Some(n) if is_ident_byte(n) => break,
                    // `1.` の後が空白・括弧・行の終わりなら `.` を含め、E0116 として報告する（本プランの決定）
                    Some(_) | None => {
                        j = add(j, 1);
                        break;
                    }
                }
            } else {
                break;
            }
        }
        j
    }

    // ---- 文字列リテラル（01-01「文字列リテラル」） ----

    fn string(&mut self, start: usize) -> usize {
        let limit = self.line_end(start);
        let mark = self.diagnostics.len();
        let mut value = String::new();
        let mut ok = true;
        let mut j = add(start, 1);
        loop {
            if j >= limit {
                // 行の終わりで閉じたものとして扱う（02-03「字句」の最後の段落）
                let span = self.span(start, limit);
                self.report_at(
                    mark,
                    DiagBuilder::new(DiagCode::E0108)
                        .primary(span)
                        .help("one_line"),
                );
                self.push(TokenKind::Error, start, limit, TokenValue::None);
                return limit;
            }
            match self.byte(j) {
                Some(b'"') => break,
                Some(b'$') if self.byte(add(j, 1)) == Some(b'{') => {
                    // `${` は v1 の文字列補間のために予約する（01-01「文字列リテラル」）
                    let span = self.span(j, add(j, 2));
                    self.report(
                        DiagBuilder::new(DiagCode::E0111)
                            .primary(span)
                            .help("escape"),
                    );
                    ok = false;
                    j = add(j, 2);
                }
                Some(_) | None => {
                    let (next, unit) = self.literal_unit(j, limit, Quote::Double);
                    match unit {
                        Some(c) => value.push(c),
                        None => ok = false,
                    }
                    j = next;
                }
            }
        }
        let end = add(j, 1);
        if ok {
            self.push(TokenKind::StringLit, start, end, TokenValue::Str(value));
        } else {
            // 誤りを含むリテラルは誤りの字句にする。構文解析器が派生した構文エラーを出さないため
            self.push(TokenKind::Error, start, end, TokenValue::None);
        }
        end
    }

    // ---- 文字リテラル（01-01「文字リテラル」） ----

    fn char_lit(&mut self, start: usize) -> usize {
        let limit = self.line_end(start);
        let body = add(start, 1);
        let Some(close) = self.find_char_close(body, limit) else {
            // 閉じの `'` が同じ行にない。行の終わりまでを誤りの字句にする。
            // 中身の誤り（正しくないエスケープ、制御文字など）も、閉じたリテラルと同じ規則で報告する。
            // 一度の検査で見つけられる誤りをできるだけ多く報告するため（02-03「字句」の最後の段落）
            let mark = self.diagnostics.len();
            let mut j = body;
            while j < limit {
                let (next, _) = self.literal_unit(j, limit, Quote::Single);
                j = next;
            }
            let span = self.span(start, limit);
            self.report_at(mark, DiagBuilder::new(DiagCode::E0109).primary(span));
            self.push(TokenKind::Error, start, limit, TokenValue::None);
            return limit;
        };
        let mark = self.diagnostics.len();
        let mut units = 0usize;
        let mut value = None;
        let mut ok = true;
        let mut j = body;
        while j < close {
            let (next, unit) = self.literal_unit(j, close, Quote::Single);
            units = add(units, 1);
            match unit {
                Some(c) => {
                    if value.is_none() {
                        value = Some(c);
                    }
                }
                None => ok = false,
            }
            j = next;
        }
        let end = add(close, 1);
        let span = self.span(start, end);
        if units == 0 {
            self.report_at(mark, DiagBuilder::new(DiagCode::E0112).primary(span));
            ok = false;
        } else if units >= 2 {
            // 結合文字を含む文字など、見た目の 1 文字が複数のスカラー値からなる場合もここに当たる
            self.report_at(
                mark,
                DiagBuilder::new(DiagCode::E0113)
                    .primary(span)
                    .help("use_string"),
            );
            ok = false;
        }
        match value {
            Some(c) if ok => self.push(TokenKind::CharLit, start, end, TokenValue::Char(c)),
            Some(_) | None => self.push(TokenKind::Error, start, end, TokenValue::None),
        }
        end
    }

    /// 文字リテラルの閉じの `'` の位置。`\` の次の 1 バイトは読み飛ばす（`'\''` の中の `'` で閉じないため）。
    fn find_char_close(&self, from: usize, limit: usize) -> Option<usize> {
        let mut k = from;
        while k < limit {
            match self.byte(k) {
                Some(b'\'') => return Some(k),
                Some(b'\\') => k = add(k, 2),
                Some(_) | None => k = add(k, 1),
            }
        }
        None
    }

    // ---- リテラルの中身 ----

    /// リテラルの中身を 1 単位（文字一つかエスケープ一つ）読む。戻り値は次の位置と、
    /// 読めた文字（誤りのときは `None`。誤りは報告済み）。`limit` を越えて読まない。
    fn literal_unit(&mut self, j: usize, limit: usize, quote: Quote) -> (usize, Option<char>) {
        let Some(b) = self.byte(j) else {
            return (limit, None);
        };
        match b {
            b'\\' => self.escape(j, limit, quote),
            b'\t' => (add(j, 1), Some('\t')),
            0x00..=0x1F | 0x7F => {
                // タブ以外の制御文字は直接書けない（01-01「文字列リテラル」）
                let c = char::from(b);
                let span = self.span(j, add(j, 1));
                self.report(
                    DiagBuilder::new(DiagCode::E0114)
                        .arg("char", code_point(c))
                        .arg("escape", control_escape_text(c))
                        .primary(span)
                        .help("escape"),
                );
                (add(j, 1), None)
            }
            0x20..=0x7E => (add(j, 1), Some(char::from(b))),
            _ => match decode(self.text, j) {
                None => (self.invalid_utf8(j, limit), None),
                Some((c, len)) if is_invisible(c) => {
                    self.report_invisible(j, len, c, true);
                    (add(j, len), None)
                }
                Some((c, len)) => (add(j, len), Some(c)),
            },
        }
    }

    /// `\` で始まるエスケープを読む（01-01「文字列リテラル」「文字リテラル」のエスケープの表）。
    fn escape(&mut self, j: usize, limit: usize, quote: Quote) -> (usize, Option<char>) {
        let next = add(j, 1);
        let Some(n) = self.byte(next).filter(|_| next < limit) else {
            // 行の終わりの直前の `\`。リテラルが閉じていないことを、囲むリテラルの誤りとして報告する
            return (next, None);
        };
        let simple = match n {
            b'n' => Some('\n'),
            b'r' => Some('\r'),
            b't' => Some('\t'),
            b'\\' => Some('\\'),
            b'"' => Some('"'),
            b'$' => Some('$'),
            // `\'` は文字リテラルでだけ使える。文字列リテラルでは誤り（01-01「文字リテラル」）
            b'\'' if quote == Quote::Single => Some('\''),
            _ => None,
        };
        if let Some(c) = simple {
            return (add(j, 2), Some(c));
        }
        if n == b'u' {
            return self.unicode_escape(j, limit, quote);
        }
        // 表にない後続。後続が印字できる文字なら、`\` と合わせて誤りのエスケープの字面にする。
        // 制御文字・見えない文字・正しくない UTF-8 は字面に入れず、`\` だけを誤りとして、
        // 後続はその文字自身の規則で報告させる
        let (end, text) = match decode(self.text, next) {
            Some((c, len)) if !c.is_control() && !is_invisible(c) => {
                let end = add(next, len);
                (end, self.lossy(j, end))
            }
            Some(_) | None => (next, "\\".to_string()),
        };
        let span = self.span(j, end);
        self.report(
            DiagBuilder::new(DiagCode::E0110)
                .arg("escape", text)
                .primary(span)
                .note(quote.valid_escapes_key()),
        );
        (end, None)
    }

    /// `\u{H}` を読む。H は 1〜6 桁の 16 進数で、Unicode のスカラー値（サロゲートと U+10FFFF を
    /// 超える値を除く）でなければならない。`j` は `\` の位置。
    fn unicode_escape(&mut self, j: usize, limit: usize, quote: Quote) -> (usize, Option<char>) {
        let mut k = add(j, 2);
        if k < limit && self.byte(k) == Some(b'{') {
            k = add(k, 1);
            let digits_start = k;
            // 閉じの `}` かリテラルの終わりまでを一つのエスケープとし、誤りの字面と span に全体を含める
            // （`\u{1_2}` を `\u{1` で切らない）。閉じの引用符と次のエスケープの `\` では止める。
            // 印字できない文字でも止め、その文字はそれ自身の規則（E0114・E0104・E0102）で報告させる
            while k < limit && self.byte(k).is_some_and(|b| is_escape_body_byte(b, quote)) {
                k = add(k, 1);
            }
            let digits_end = k;
            if k < limit && self.byte(k) == Some(b'}') {
                k = add(k, 1);
                if let Some(c) = scalar_from_hex(self.slice(digits_start, digits_end)) {
                    return (k, Some(c));
                }
            }
        }
        let text = self.lossy(j, k);
        let span = self.span(j, k);
        self.report(
            DiagBuilder::new(DiagCode::E0110)
                .arg("escape", text)
                .primary(span)
                .note("unicode"),
        );
        (k, None)
    }

    // ---- 演算子と区切り記号（01-01「演算子と区切り記号」） ----

    /// ASCII の印字可能文字のうち、識別子・数値・リテラル・コメントの始まりでないもの。
    /// 2 文字の記号を 1 文字の記号より先に調べ、最も長く一致するものを取る。
    fn symbol(&mut self, i: usize, b: u8) -> usize {
        let next = self.byte(add(i, 1));
        let (kind, len) = match (b, next) {
            (b'|', Some(b'>')) => (TokenKind::PipeGt, 2),
            (b'|', Some(b'|')) => (TokenKind::OrOr, 2),
            (b'-', Some(b'>')) => (TokenKind::Arrow, 2),
            (b'=', Some(b'>')) => (TokenKind::FatArrow, 2),
            (b'=', Some(b'=')) => (TokenKind::EqEq, 2),
            (b'!', Some(b'=')) => (TokenKind::BangEq, 2),
            (b'<', Some(b'=')) => (TokenKind::Le, 2),
            (b'>', Some(b'=')) => (TokenKind::Ge, 2),
            (b'&', Some(b'&')) => (TokenKind::AndAnd, 2),
            (b'+', _) => (TokenKind::Plus, 1),
            (b'-', _) => (TokenKind::Minus, 1),
            (b'*', _) => (TokenKind::Star, 1),
            (b'/', _) => (TokenKind::Slash, 1),
            (b'%', _) => (TokenKind::Percent, 1),
            (b'<', _) => (TokenKind::Lt, 1),
            (b'>', _) => (TokenKind::Gt, 1),
            (b'!', _) => (TokenKind::Bang, 1),
            (b'=', _) => (TokenKind::Eq, 1),
            (b':', _) => (TokenKind::Colon, 1),
            (b',', _) => (TokenKind::Comma, 1),
            (b'.', _) => (TokenKind::Dot, 1),
            (b'(', _) => (TokenKind::LParen, 1),
            (b')', _) => (TokenKind::RParen, 1),
            (b'[', _) => (TokenKind::LBracket, 1),
            (b']', _) => (TokenKind::RBracket, 1),
            (b'{', _) => (TokenKind::LBrace, 1),
            (b'}', _) => (TokenKind::RBrace, 1),
            (b';', _) => {
                // `;` を書いた書き手は文を区切るつもりなので、改行の印を置く。
                // 構文解析器が派生した誤りを出さないようにするため（本プランの決定。T02）
                let span = self.span(i, add(i, 1));
                self.report(
                    DiagBuilder::new(DiagCode::E0106)
                        .primary(span)
                        .help("newline"),
                );
                self.push(TokenKind::LineBreak, i, add(i, 1), TokenValue::None);
                return add(i, 1);
            }
            _ => {
                // 一覧にない記号（`|` 単独、`&` 単独、`@`、`#`、`$` など）。
                // 誤りの字句を置き、構文解析器がその位置で新たな誤りを報告しないようにする
                let span = self.span(i, add(i, 1));
                self.report(
                    DiagBuilder::new(DiagCode::E0105)
                        .arg("symbol", char::from(b).to_string())
                        .primary(span),
                );
                self.push(TokenKind::Error, i, add(i, 1), TokenValue::None);
                return add(i, 1);
            }
        };
        let end = add(i, len);
        self.push(kind, i, end, TokenValue::None);
        end
    }
}

// ---- 位置と文字の補助 ----

/// 位置の足し算。ソースの大きさには上限（`MAX_SOURCE_BYTES`）があり溢れないが、
/// lint（arithmetic_side_effects）に従い、溢れる計算を書かない。
fn add(a: usize, b: usize) -> usize {
    a.saturating_add(b)
}

/// バイトの位置を span の位置にする。ソースの大きさの上限（256 MiB）により u32 に収まる。
/// 上限を超える入力はパイプラインが読み込みの段で拒む（02-02）ので、ここでは飽和させるだけにする。
fn byte_pos(i: usize) -> BytePos {
    BytePos(u32::try_from(i).unwrap_or(u32::MAX))
}

/// 位置 `i` から UTF-8 の文字を一つ読み、文字とバイト数を返す。正しい並びの先頭でなければ `None`。
/// 過長の符号化とサロゲートは `str::from_utf8` が拒む。
fn decode(text: &[u8], i: usize) -> Option<(char, usize)> {
    let b = *text.get(i)?;
    let len = match b {
        0x00..=0x7F => 1,
        0xC2..=0xDF => 2,
        0xE0..=0xEF => 3,
        0xF0..=0xF4 => 4,
        _ => return None,
    };
    let bytes = text.get(i..i.checked_add(len)?)?;
    let c = std::str::from_utf8(bytes).ok()?.chars().next()?;
    Some((c, len))
}

/// 双方向の制御文字と U+FEFF（01-01「ソースファイルと文字集合」、ADR 0051）。
/// 先頭の BOM は `run` が先に読み飛ばすので、ここに来る U+FEFF は先頭以外にある。
fn is_invisible(c: char) -> bool {
    matches!(
        c,
        '\u{061C}'
            | '\u{200E}'
            | '\u{200F}'
            | '\u{202A}'..='\u{202E}'
            | '\u{2066}'..='\u{2069}'
            | '\u{FEFF}'
    )
}

/// `\u{...}` の中身として読み進めるバイト。ASCII の印字可能文字のうち、閉じの `}`、
/// そのリテラルの閉じの引用符、`\` を除いたもの。
fn is_escape_body_byte(b: u8, quote: Quote) -> bool {
    let closing_quote = match quote {
        Quote::Double => b'"',
        Quote::Single => b'\'',
    };
    (0x20..=0x7E).contains(&b) && b != b'}' && b != b'\\' && b != closing_quote
}

fn is_ident_byte(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b == b'_'
}

/// 診断の `char` の値。`U+` と 4 桁以上の大文字の 16 進数にする（本プランの決定。T02）。
/// 文字そのものを表示しないのは、見えない文字や端末で崩れる文字があるからである。
fn code_point(c: char) -> String {
    format!("U+{:04X}", u32::from(c))
}

/// その文字を値に含めるときに書くエスケープ `\u{H}`（H は大文字の 16 進数）。
fn unicode_escape_text(c: char) -> String {
    format!("\\u{{{:X}}}", u32::from(c))
}

/// 制御文字を書くためのエスケープ。短いエスケープがある文字はその形にする。
fn control_escape_text(c: char) -> String {
    match c {
        '\n' => "\\n".to_string(),
        '\r' => "\\r".to_string(),
        '\t' => "\\t".to_string(),
        _ => unicode_escape_text(c),
    }
}

/// `\u{...}` の中身をスカラー値にする。1〜6 桁の 16 進数で、サロゲートと U+10FFFF を超える値でないこと。
fn scalar_from_hex(digits: &[u8]) -> Option<char> {
    if digits.is_empty() || digits.len() > 6 || !digits.iter().all(u8::is_ascii_hexdigit) {
        return None;
    }
    let text = std::str::from_utf8(digits).ok()?;
    let value = u32::from_str_radix(text, 16).ok()?;
    // char::from_u32 はサロゲートと U+10FFFF を超える値を拒む
    char::from_u32(value)
}

// ---- キーワードと予約語（01-01「キーワード」） ----

fn keyword(word: &str) -> Option<TokenKind> {
    let kind = match word {
        "effect" => TokenKind::KwEffect,
        "else" => TokenKind::KwElse,
        "false" => TokenKind::KwFalse,
        "fn" => TokenKind::KwFn,
        "if" => TokenKind::KwIf,
        "let" => TokenKind::KwLet,
        "match" => TokenKind::KwMatch,
        "true" => TokenKind::KwTrue,
        "type" => TokenKind::KwType,
        "uses" => TokenKind::KwUses,
        _ => return None,
    };
    Some(kind)
}

/// 予約語なら、E0117 の修正案の鍵を返す（02-03「字句」の予約語の表）。
/// 他の言語の制御構文に当たる語には、この言語での書き方を示す修正案を選ぶ。
fn reserved_hint(word: &str) -> Option<&'static str> {
    let hint = match word {
        "for" | "while" | "loop" => "loop",
        "break" | "continue" => "break",
        "return" => "return",
        "as" | "class" | "derive" | "handle" | "impl" | "import" | "instance" | "lazy"
        | "module" | "mut" | "pub" | "resume" | "trait" | "var" | "where" => "other",
        _ => return None,
    };
    Some(hint)
}

// ---- 数値の塊の分類 ----

/// 数値の誤り: 診断コード（E0115 か E0116）と、ラベルの鍵。
type NumberError = (DiagCode, &'static str);

/// 数値の塊を、整数リテラルか浮動小数リテラルとして読む。読めなければ誤りの種類を返す。
/// 一つの塊に複数の誤りがあるときは、T02 の表の上の行から最初に当たったものだけを返す。
fn classify_number(chunk: &[u8]) -> Result<(TokenKind, TokenValue), NumberError> {
    match chunk {
        [
            b'0',
            p @ (b'x' | b'X' | b'o' | b'O' | b'b' | b'B'),
            body @ ..,
        ] => classify_prefixed(*p, body),
        _ => classify_decimal(chunk),
    }
}

/// 接頭辞（`0x`・`0o`・`0b`。大文字の誤りを含む）を持つ整数リテラル。
fn classify_prefixed(prefix: u8, body: &[u8]) -> Result<(TokenKind, TokenValue), NumberError> {
    const CODE: DiagCode = DiagCode::E0115;
    let radix: u32 = match prefix.to_ascii_lowercase() {
        b'x' => 16,
        b'o' => 8,
        _ => 2,
    };
    // 数字の並びとみなす部分: 10 進の数字（基数に合わないものを含む）、16 進では英字の数字、`_`。
    // `0b102` の `2` を「基数に合わない数字」、`0xfg` の `g` を「直後の文字」と分けるため
    let digit_like =
        |b: u8| b == b'_' || b.is_ascii_digit() || (radix == 16 && b.is_ascii_hexdigit());
    let main_len = body.iter().take_while(|b| digit_like(**b)).count();
    let (main, rest) = body.split_at_checked(main_len).unwrap_or((body, &[]));
    // `_` の規則は塊全体に当てる。表の優先順では `suffix` より先なので、接尾辞の側の `_`（`0xff_g`）も
    // `underscore` として報告する。接頭辞の直後の `_`（`0x_ff`）は前に数字がないので誤り
    let is_digit = |b: u8| b.is_ascii_digit() || (radix == 16 && b.is_ascii_hexdigit());
    if !underscores_between_digits(body, is_digit) {
        return Err((CODE, "underscore"));
    }
    if main
        .iter()
        .any(|b| *b != b'_' && char::from(*b).to_digit(radix).is_none())
    {
        return Err((CODE, "digit"));
    }
    if !has_digit(main) {
        return Err((CODE, "no_digits"));
    }
    if prefix.is_ascii_uppercase() {
        return Err((CODE, "prefix"));
    }
    if !rest.is_empty() {
        return Err((CODE, "suffix"));
    }
    Ok((
        TokenKind::IntLit,
        TokenValue::Int {
            radix,
            digits: without_underscores(main),
        },
    ))
}

/// 10 進の整数リテラルと浮動小数リテラル。
fn classify_decimal(chunk: &[u8]) -> Result<(TokenKind, TokenValue), NumberError> {
    // `.` か `e`・`E` を含む 10 進の塊は浮動小数の形とみなし、誤りを E0116 で報告する
    let float_form = chunk.iter().any(|b| matches!(b, b'.' | b'e' | b'E'));
    let code = if float_form {
        DiagCode::E0116
    } else {
        DiagCode::E0115
    };

    // 整数部、小数部、指数部に分け、残りを「直後の文字」とする
    let int_part = digit_run(chunk, 0);
    let mut k = int_part.len();
    let mut frac = None;
    if chunk.get(k) == Some(&b'.') {
        let f = digit_run(chunk, add(k, 1));
        k = add(k, add(1, f.len()));
        frac = Some(f);
    }
    let mut exp = None;
    if matches!(chunk.get(k), Some(b'e' | b'E')) {
        k = add(k, 1);
        if matches!(chunk.get(k), Some(b'+' | b'-')) {
            k = add(k, 1);
        }
        let x = digit_run(chunk, k);
        k = add(k, x.len());
        exp = Some(x);
    }
    let rest = chunk.get(k..).unwrap_or(&[]);

    let int_digits = without_underscores(int_part);
    // 8 進数と誤読されることを避けるため、`0` 以外は `0` で始めない（01-01「整数リテラル」）
    if int_digits.len() > 1 && int_digits.starts_with('0') {
        return Err((code, "leading_zero"));
    }
    // `_` の規則は、整数部・小数部・指数部に限らず塊全体に当てる（`12abc_`、`1_e5` も `underscore`）
    if !underscores_between_digits(chunk, |b| b.is_ascii_digit()) {
        return Err((code, "underscore"));
    }
    if frac.is_some_and(|f| !has_digit(f)) {
        return Err((code, "missing_digits"));
    }
    if exp.is_some_and(|x| !has_digit(x)) {
        return Err((code, "exponent"));
    }
    if rest.contains(&b'.') {
        return Err((code, "second_dot"));
    }
    if !rest.is_empty() {
        return Err((code, "suffix"));
    }
    if float_form {
        Ok((
            TokenKind::FloatLit,
            TokenValue::Float(without_underscores(chunk)),
        ))
    } else {
        Ok((
            TokenKind::IntLit,
            TokenValue::Int {
                radix: 10,
                digits: int_digits,
            },
        ))
    }
}

/// `from` から続く、10 進の数字と `_` の並び。
fn digit_run(chunk: &[u8], from: usize) -> &[u8] {
    let tail = chunk.get(from..).unwrap_or(&[]);
    let len = tail
        .iter()
        .take_while(|b| b.is_ascii_digit() || **b == b'_')
        .count();
    tail.get(..len).unwrap_or(&[])
}

fn has_digit(group: &[u8]) -> bool {
    group.iter().any(|b| *b != b'_')
}

/// すべての `_` が二つの数字のあいだにあるか（01-01「整数リテラル」）。
/// 先頭・末尾・連続の `_` と、数字でない文字（接頭辞、`.`、`e`、接尾辞の英字）に隣る `_` を拒む。
fn underscores_between_digits(bytes: &[u8], is_digit: impl Fn(u8) -> bool) -> bool {
    bytes.iter().enumerate().all(|(i, b)| {
        *b != b'_'
            || (i
                .checked_sub(1)
                .and_then(|p| bytes.get(p))
                .is_some_and(|p| is_digit(*p))
                && i.checked_add(1)
                    .and_then(|n| bytes.get(n))
                    .is_some_and(|n| is_digit(*n)))
    })
}

fn without_underscores(bytes: &[u8]) -> String {
    bytes
        .iter()
        .filter(|b| **b != b'_')
        .map(|b| char::from(*b))
        .collect()
}

#[cfg(test)]
// テストの失敗は panic で表す（00-02「`#[allow]` を書いてよい箇所」）
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use TokenKind as K;

    const F: FileId = FileId(7);

    fn lex_bytes(src: &[u8]) -> LexOutput {
        lex(F, src)
    }

    fn lex_str(src: &str) -> LexOutput {
        lex_bytes(src.as_bytes())
    }

    fn kinds(out: &LexOutput) -> Vec<TokenKind> {
        out.tokens.iter().map(|t| t.kind).collect()
    }

    fn sp(start: u32, end: u32) -> Span {
        Span {
            file: F,
            start: BytePos(start),
            end: BytePos(end),
        }
    }

    fn len32(s: &str) -> u32 {
        u32::try_from(s.len()).unwrap()
    }

    /// 誤りのない入力の字句の種類を確かめる。
    fn assert_clean_kinds(src: &str, expected: &[TokenKind]) {
        let out = lex_str(src);
        assert_eq!(out.diagnostics, vec![], "src: {src:?}");
        assert_eq!(kinds(&out), expected, "src: {src:?}");
    }

    #[test]
    fn token_kinds() {
        let cases: &[(&str, &[TokenKind])] = &[
            (
                "fn main() -> Unit uses IO { }",
                &[
                    K::KwFn,
                    K::LowerIdent,
                    K::LParen,
                    K::RParen,
                    K::Arrow,
                    K::UpperIdent,
                    K::KwUses,
                    K::UpperIdent,
                    K::LBrace,
                    K::RBrace,
                    K::Eof,
                ],
            ),
            // 最長一致
            ("a|>b", &[K::LowerIdent, K::PipeGt, K::LowerIdent, K::Eof]),
            ("a<=b", &[K::LowerIdent, K::Le, K::LowerIdent, K::Eof]),
            ("x->y", &[K::LowerIdent, K::Arrow, K::LowerIdent, K::Eof]),
            (
                "+ - * / % == != < <= > >= && || ! |> -> => = : , . ( ) [ ] { } _",
                &[
                    K::Plus,
                    K::Minus,
                    K::Star,
                    K::Slash,
                    K::Percent,
                    K::EqEq,
                    K::BangEq,
                    K::Lt,
                    K::Le,
                    K::Gt,
                    K::Ge,
                    K::AndAnd,
                    K::OrOr,
                    K::Bang,
                    K::PipeGt,
                    K::Arrow,
                    K::FatArrow,
                    K::Eq,
                    K::Colon,
                    K::Comma,
                    K::Dot,
                    K::LParen,
                    K::RParen,
                    K::LBracket,
                    K::RBracket,
                    K::LBrace,
                    K::RBrace,
                    K::Underscore,
                    K::Eof,
                ],
            ),
            (
                "effect else false fn if let match true type uses",
                &[
                    K::KwEffect,
                    K::KwElse,
                    K::KwFalse,
                    K::KwFn,
                    K::KwIf,
                    K::KwLet,
                    K::KwMatch,
                    K::KwTrue,
                    K::KwType,
                    K::KwUses,
                    K::Eof,
                ],
            ),
            // v1 で初めてキーワードになる語で、最小実行版で予約していないもの
            (
                "permissions with record from",
                &[
                    K::LowerIdent,
                    K::LowerIdent,
                    K::LowerIdent,
                    K::LowerIdent,
                    K::Eof,
                ],
            ),
            // `1.foo` はドット記法の形のまま字句に分け、誤りは構文解析器に任せる
            ("1.foo", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
            // 16 進の `e` は指数部ではないので、後の `+` を塊に含めない
            ("0x1e+2", &[K::IntLit, K::Plus, K::IntLit, K::Eof]),
            ("1e5-2", &[K::FloatLit, K::Minus, K::IntLit, K::Eof]),
            ("", &[K::Eof]),
        ];
        for (src, expected) in cases {
            assert_clean_kinds(src, expected);
        }
    }

    #[test]
    fn identifier_values() {
        let cases = [
            ("_", K::Underscore, TokenValue::None),
            ("_x", K::LowerIdent, TokenValue::Ident("_x".to_string())),
            (
                "foo_1",
                K::LowerIdent,
                TokenValue::Ident("foo_1".to_string()),
            ),
            ("Foo", K::UpperIdent, TokenValue::Ident("Foo".to_string())),
            ("iff", K::LowerIdent, TokenValue::Ident("iff".to_string())),
        ];
        for (src, kind, value) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, vec![], "src: {src:?}");
            let expected = Token {
                kind,
                span: sp(0, len32(src)),
                value,
            };
            assert_eq!(out.tokens[0], expected, "src: {src:?}");
        }
    }

    #[test]
    fn integer_literals() {
        let cases = [
            ("0", 10, "0"),
            ("42", 10, "42"),
            ("1_000_000", 10, "1000000"),
            ("0xFF_FF", 16, "FFFF"),
            ("0xff", 16, "ff"),
            ("0o755", 8, "755"),
            ("0b1010_0101", 2, "10100101"),
            // 値の範囲は型検査器が判定する（02-03「字句」）
            ("99999999999999999999999", 10, "99999999999999999999999"),
        ];
        for (src, radix, digits) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, vec![], "src: {src:?}");
            let expected = Token {
                kind: K::IntLit,
                span: sp(0, len32(src)),
                value: TokenValue::Int {
                    radix,
                    digits: digits.to_string(),
                },
            };
            assert_eq!(out.tokens, vec![expected, eof(len32(src))], "src: {src:?}");
        }
    }

    fn eof(at: u32) -> Token {
        Token {
            kind: K::Eof,
            span: sp(at, at),
            value: TokenValue::None,
        }
    }

    #[test]
    fn float_literals() {
        let cases = [
            ("1.5", "1.5"),
            ("0.5", "0.5"),
            ("1e10", "1e10"),
            ("0e5", "0e5"),
            ("0E5", "0E5"),
            ("1.05", "1.05"),
            ("1e05", "1e05"),
            ("1_000.5", "1000.5"),
            ("2.5e-3", "2.5e-3"),
            ("1E+4", "1E+4"),
        ];
        for (src, text) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, vec![], "src: {src:?}");
            let expected = Token {
                kind: K::FloatLit,
                span: sp(0, len32(src)),
                value: TokenValue::Float(text.to_string()),
            };
            assert_eq!(out.tokens, vec![expected, eof(len32(src))], "src: {src:?}");
        }
    }

    #[test]
    fn malformed_numbers() {
        use DiagCode::{E0115, E0116};
        // (ソース, 塊の字面, コード, ラベルの鍵)。塊は先頭から始まり、一つの誤りの字句になる
        let cases = [
            ("007", "007", E0115, "leading_zero"),
            ("00.5", "00.5", E0116, "leading_zero"),
            ("01e5", "01e5", E0116, "leading_zero"),
            ("1__0", "1__0", E0115, "underscore"),
            ("0x_ff", "0x_ff", E0115, "underscore"),
            ("1_", "1_", E0115, "underscore"),
            ("1_.5", "1_.5", E0116, "underscore"),
            ("0b102", "0b102", E0115, "digit"),
            ("0o8", "0o8", E0115, "digit"),
            ("0x", "0x", E0115, "no_digits"),
            ("0X1F", "0X1F", E0115, "prefix"),
            ("0B1", "0B1", E0115, "prefix"),
            ("0O7", "0O7", E0115, "prefix"),
            ("1. ", "1.", E0116, "missing_digits"),
            ("1.)", "1.", E0116, "missing_digits"),
            ("1.", "1.", E0116, "missing_digits"),
            ("1e", "1e", E0116, "exponent"),
            ("1e+", "1e+", E0116, "exponent"),
            ("1.5.2", "1.5.2", E0116, "second_dot"),
            ("12abc", "12abc", E0115, "suffix"),
            ("0xfg", "0xfg", E0115, "suffix"),
            ("1.5x", "1.5x", E0116, "suffix"),
            ("0b1a", "0b1a", E0115, "suffix"),
            // 複数の誤りは、表の上の行の一つだけを報告する
            ("007abc", "007abc", E0115, "leading_zero"),
            ("12abc_", "12abc_", E0115, "underscore"),
            ("12_abc", "12_abc", E0115, "underscore"),
            ("0xff_g", "0xff_g", E0115, "underscore"),
            ("0b1_2", "0b1_2", E0115, "digit"),
            ("1_e5", "1_e5", E0116, "underscore"),
            ("1.5_x", "1.5_x", E0116, "underscore"),
        ];
        for (src, text, code, key) in cases {
            let out = lex_str(src);
            let span = sp(0, len32(text));
            let expected = DiagBuilder::new(code)
                .arg("text", text)
                .primary_label(span, key)
                .build();
            assert_eq!(out.diagnostics, vec![expected], "src: {src:?}");
            let first = &out.tokens[0];
            assert_eq!((first.kind, first.span), (K::Error, span), "src: {src:?}");
        }
        // 塊の後の字句は読み続ける
        assert_eq!(kinds(&lex_str("1.)")), vec![K::Error, K::RParen, K::Eof]);
    }

    #[test]
    fn string_literals() {
        let cases = [
            (r#""a\n\"b\$""#, "a\n\"b$"),
            (r#""\u{1F600}""#, "\u{1F600}"),
            (r#""\r\t\\""#, "\r\t\\"),
            (r#""$x""#, "$x"),
            (r#""$""#, "$"),
            ("\"a\tb\"", "a\tb"),
            // 右から左に書く文字そのものは書ける（01-01）
            ("\"שלום あ\"", "שלום あ"),
            // 双方向の制御文字もエスケープでなら値に含められる
            (r#""\u{202E}""#, "\u{202E}"),
            (r#""it's // not a comment""#, "it's // not a comment"),
            (r#""""#, ""),
        ];
        for (src, value) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, vec![], "src: {src:?}");
            assert_eq!(out.comments, vec![], "src: {src:?}");
            let expected = Token {
                kind: K::StringLit,
                span: sp(0, len32(src)),
                value: TokenValue::Str(value.to_string()),
            };
            assert_eq!(out.tokens, vec![expected, eof(len32(src))], "src: {src:?}");
        }
    }

    #[test]
    fn string_errors() {
        let e0110 = |escape: &str, start, end, key| {
            DiagBuilder::new(DiagCode::E0110)
                .arg("escape", escape)
                .primary(sp(start, end))
                .note(key)
                .build()
        };
        let cases = [
            (r#""\q""#, vec![e0110(r"\q", 1, 3, "valid_string")]),
            (r#""\'""#, vec![e0110(r"\'", 1, 3, "valid_string")]),
            (r#""\u{D800}""#, vec![e0110(r"\u{D800}", 1, 9, "unicode")]),
            (
                r#""\u{110000}""#,
                vec![e0110(r"\u{110000}", 1, 11, "unicode")],
            ),
            (r#""\u{}""#, vec![e0110(r"\u{}", 1, 5, "unicode")]),
            (
                r#""\u{1234567}""#,
                vec![e0110(r"\u{1234567}", 1, 12, "unicode")],
            ),
            (r#""\u{12""#, vec![e0110(r"\u{12", 1, 6, "unicode")]),
            // 16 進数でない文字を含んでも、閉じの `}` までを一つの誤りのエスケープにする
            (r#""\u{1_2}""#, vec![e0110(r"\u{1_2}", 1, 8, "unicode")]),
            (r#""\u{12 x}""#, vec![e0110(r"\u{12 x}", 1, 9, "unicode")]),
            (r#""\u41""#, vec![e0110(r"\u", 1, 3, "unicode")]),
            (
                r#""a${x}""#,
                vec![
                    DiagBuilder::new(DiagCode::E0111)
                        .primary(sp(2, 4))
                        .help("escape")
                        .build(),
                ],
            ),
            (
                "\"a\u{1}b\"",
                vec![
                    DiagBuilder::new(DiagCode::E0114)
                        .arg("char", "U+0001")
                        .arg("escape", r"\u{1}")
                        .primary(sp(2, 3))
                        .help("escape")
                        .build(),
                ],
            ),
            (
                "\"a\rb\"",
                vec![
                    DiagBuilder::new(DiagCode::E0114)
                        .arg("char", "U+000D")
                        .arg("escape", r"\r")
                        .primary(sp(2, 3))
                        .help("escape")
                        .build(),
                ],
            ),
            (
                "\"a\u{202E}b\"",
                vec![
                    DiagBuilder::new(DiagCode::E0104)
                        .arg("char", "U+202E")
                        .arg("escape", r"\u{202E}")
                        .primary(sp(2, 5))
                        .help("escape")
                        .build(),
                ],
            ),
            // 誤りのエスケープの後も読み続け、二つ目の誤りも報告する
            (
                r#""\q\z""#,
                vec![
                    e0110(r"\q", 1, 3, "valid_string"),
                    e0110(r"\z", 3, 5, "valid_string"),
                ],
            ),
        ];
        for (src, expected) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, expected, "src: {src:?}");
            let expected_tokens = vec![
                Token {
                    kind: K::Error,
                    span: sp(0, len32(src)),
                    value: TokenValue::None,
                },
                eof(len32(src)),
            ];
            assert_eq!(out.tokens, expected_tokens, "src: {src:?}");
        }
    }

    #[test]
    fn unterminated_string_recovers_on_next_line() {
        let e0108 = |end| {
            DiagBuilder::new(DiagCode::E0108)
                .primary(sp(0, end))
                .help("one_line")
                .build()
        };
        let out = lex_str("\"abc\nx");
        assert_eq!(out.diagnostics, vec![e0108(4)]);
        assert_eq!(
            kinds(&out),
            vec![K::Error, K::LineBreak, K::LowerIdent, K::Eof]
        );
        assert_eq!(out.tokens[0].span, sp(0, 4));

        // CR LF の CR は行の終わりに含めない。中の誤りは E0108 の後に位置の順で並ぶ
        let out = lex_str("\"\\q\r\nx");
        let codes: Vec<_> = out.diagnostics.iter().map(|d| d.code).collect();
        assert_eq!(codes, vec![Some(DiagCode::E0108), Some(DiagCode::E0110)]);
        assert_eq!(out.diagnostics[0], e0108(3));
        assert_eq!(
            kinds(&out),
            vec![K::Error, K::LineBreak, K::LowerIdent, K::Eof]
        );

        // 行末の `\` は、閉じていない文字列の誤りだけにする
        let out = lex_str("\"a\\");
        assert_eq!(out.diagnostics, vec![e0108(3)]);
    }

    #[test]
    fn char_literals() {
        let cases = [
            ("'a'", 'a'),
            ("'あ'", 'あ'),
            (r"'\n'", '\n'),
            (r"'\''", '\''),
            (r#"'"'"#, '"'),
            (r#"'\"'"#, '"'),
            (r"'\$'", '$'),
            (r"'\u{41}'", 'A'),
            ("'\t'", '\t'),
        ];
        for (src, c) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, vec![], "src: {src:?}");
            let expected = Token {
                kind: K::CharLit,
                span: sp(0, len32(src)),
                value: TokenValue::Char(c),
            };
            assert_eq!(out.tokens, vec![expected, eof(len32(src))], "src: {src:?}");
        }
    }

    #[test]
    fn char_errors() {
        let cases = [
            (
                "''",
                vec![DiagBuilder::new(DiagCode::E0112).primary(sp(0, 2)).build()],
            ),
            (
                "'ab'",
                vec![
                    DiagBuilder::new(DiagCode::E0113)
                        .primary(sp(0, 4))
                        .help("use_string")
                        .build(),
                ],
            ),
            // 結合文字を含む見た目の 1 文字は、スカラー値が二つある
            (
                "'e\u{301}'",
                vec![
                    DiagBuilder::new(DiagCode::E0113)
                        .primary(sp(0, 5))
                        .help("use_string")
                        .build(),
                ],
            ),
            (
                r"'\q'",
                vec![
                    DiagBuilder::new(DiagCode::E0110)
                        .arg("escape", r"\q")
                        .primary(sp(1, 3))
                        .note("valid_char")
                        .build(),
                ],
            ),
            (
                r"'\u{D800}'",
                vec![
                    DiagBuilder::new(DiagCode::E0110)
                        .arg("escape", r"\u{D800}")
                        .primary(sp(1, 9))
                        .note("unicode")
                        .build(),
                ],
            ),
            (
                "'\u{1B}'",
                vec![
                    DiagBuilder::new(DiagCode::E0114)
                        .arg("char", "U+001B")
                        .arg("escape", r"\u{1B}")
                        .primary(sp(1, 2))
                        .help("escape")
                        .build(),
                ],
            ),
            (
                "'\u{200F}'",
                vec![
                    DiagBuilder::new(DiagCode::E0104)
                        .arg("char", "U+200F")
                        .arg("escape", r"\u{200F}")
                        .primary(sp(1, 4))
                        .help("escape")
                        .build(),
                ],
            ),
        ];
        for (src, expected) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, expected, "src: {src:?}");
            assert_eq!(kinds(&out), vec![K::Error, K::Eof], "src: {src:?}");
            assert_eq!(out.tokens[0].span, sp(0, len32(src)), "src: {src:?}");
        }
    }

    #[test]
    fn unterminated_char_literal() {
        let e0109 = |end| {
            DiagBuilder::new(DiagCode::E0109)
                .primary(sp(0, end))
                .build()
        };
        // 閉じの `'` が同じ行にない。行の終わりまでを誤りの字句にし、次の行は読める
        for src in ["'a\nb", "'abc\nb", "'\\'\nb"] {
            let out = lex_str(src);
            let line = len32(src.split('\n').next().unwrap());
            assert_eq!(out.diagnostics, vec![e0109(line)], "src: {src:?}");
            assert_eq!(
                kinds(&out),
                vec![K::Error, K::LineBreak, K::LowerIdent, K::Eof],
                "src: {src:?}"
            );
            assert_eq!(out.tokens[0].span, sp(0, line), "src: {src:?}");
        }
        // 閉じていなくても中身を検査し、E0109 の後に中身の誤りを位置の順に並べる
        let out = lex_str("'\\q\nb");
        let e0110 = DiagBuilder::new(DiagCode::E0110)
            .arg("escape", r"\q")
            .primary(sp(1, 3))
            .note("valid_char")
            .build();
        assert_eq!(out.diagnostics, vec![e0109(3), e0110]);
        let out = lex_str("'a\u{1}\nb");
        let e0114 = DiagBuilder::new(DiagCode::E0114)
            .arg("char", "U+0001")
            .arg("escape", r"\u{1}")
            .primary(sp(2, 3))
            .help("escape")
            .build();
        assert_eq!(out.diagnostics, vec![e0109(3), e0114]);
        assert_eq!(
            kinds(&out),
            vec![K::Error, K::LineBreak, K::LowerIdent, K::Eof]
        );
        // 双方向の制御文字も報告する
        let out = lex_str("'x \u{202E}");
        let codes: Vec<_> = out.diagnostics.iter().map(|d| d.code).collect();
        assert_eq!(codes, vec![Some(DiagCode::E0109), Some(DiagCode::E0104)]);
    }

    #[test]
    fn reserved_words() {
        let cases = [
            ("return", "return"),
            ("while", "loop"),
            ("for", "loop"),
            ("loop", "loop"),
            ("continue", "break"),
            ("break", "break"),
            ("class", "other"),
            ("where", "other"),
        ];
        for (word, hint) in cases {
            let out = lex_str(word);
            let span = sp(0, len32(word));
            let expected = DiagBuilder::new(DiagCode::E0117)
                .arg("word", word)
                .primary(span)
                .help(hint)
                .build();
            assert_eq!(out.diagnostics, vec![expected], "word: {word}");
            assert_eq!(kinds(&out), vec![K::Error, K::Eof], "word: {word}");
        }
    }

    #[test]
    fn semicolon_becomes_line_break() {
        let out = lex_str("a; b");
        let expected = DiagBuilder::new(DiagCode::E0106)
            .primary(sp(1, 2))
            .help("newline")
            .build();
        assert_eq!(out.diagnostics, vec![expected]);
        assert_eq!(
            kinds(&out),
            vec![K::LowerIdent, K::LineBreak, K::LowerIdent, K::Eof]
        );
        assert_eq!(out.tokens[1].span, sp(1, 2));
    }

    #[test]
    fn unknown_symbols() {
        for symbol in ["@", "|", "&", "#", "$", "?", "~", "^", "`", "\\"] {
            let src = format!("a {symbol} b");
            let out = lex_str(&src);
            let expected = DiagBuilder::new(DiagCode::E0105)
                .arg("symbol", symbol)
                .primary(sp(2, 3))
                .build();
            assert_eq!(out.diagnostics, vec![expected], "src: {src:?}");
            assert_eq!(
                kinds(&out),
                vec![K::LowerIdent, K::Error, K::LowerIdent, K::Eof],
                "src: {src:?}"
            );
        }
    }

    #[test]
    fn disallowed_characters() {
        let e0103 = |c: &str, start, end| {
            DiagBuilder::new(DiagCode::E0103)
                .arg("char", c)
                .primary(sp(start, end))
                .note("allowed")
                .build()
        };
        // リテラルの外（コメントの中と字句の間）の E0104 には、エスケープの修正案を付けない
        // （02-03「字句」）。リテラルの中の修正案は string_errors と char_errors で確かめる
        let e0104 = |c: &str, escape: &str, start, end| {
            DiagBuilder::new(DiagCode::E0104)
                .arg("char", c)
                .arg("escape", escape)
                .primary(sp(start, end))
                .build()
        };
        // (ソース, 診断, 字句の種類)
        let cases = [
            (
                "a\u{3000}b",
                vec![e0103("U+3000", 1, 4)],
                vec![K::LowerIdent, K::LowerIdent, K::Eof],
            ),
            (
                "a\u{A0}b",
                vec![e0103("U+00A0", 1, 3)],
                vec![K::LowerIdent, K::LowerIdent, K::Eof],
            ),
            (
                "a \u{1F600}",
                vec![e0103("U+1F600", 2, 6)],
                vec![K::LowerIdent, K::Eof],
            ),
            (
                "a\u{1}b",
                vec![e0103("U+0001", 1, 2)],
                vec![K::LowerIdent, K::LowerIdent, K::Eof],
            ),
            // コメントの中の全角空白は誤りでない
            ("a // \u{3000}", vec![], vec![K::LowerIdent, K::Eof]),
            // 双方向の制御文字は、コメントの中でも誤り
            (
                "a // \u{202E}",
                vec![e0104("U+202E", r"\u{202E}", 5, 8)],
                vec![K::LowerIdent, K::Eof],
            ),
            (
                "a // x\u{FEFF}y",
                vec![e0104("U+FEFF", r"\u{FEFF}", 6, 9)],
                vec![K::LowerIdent, K::Eof],
            ),
            (
                "a\u{2066}b",
                vec![e0104("U+2066", r"\u{2066}", 1, 4)],
                vec![K::LowerIdent, K::LowerIdent, K::Eof],
            ),
            (
                "a\u{61C}b",
                vec![e0104("U+061C", r"\u{61C}", 1, 3)],
                vec![K::LowerIdent, K::LowerIdent, K::Eof],
            ),
            // 先頭の BOM は無視し、2 行目の先頭の U+FEFF は誤り
            (
                "\u{FEFF}a\n\u{FEFF}b",
                vec![e0104("U+FEFF", r"\u{FEFF}", 5, 8)],
                vec![K::LowerIdent, K::LineBreak, K::LowerIdent, K::Eof],
            ),
        ];
        for (src, diags, token_kinds) in cases {
            let out = lex_str(src);
            assert_eq!(out.diagnostics, diags, "src: {src:?}");
            assert_eq!(kinds(&out), token_kinds, "src: {src:?}");
        }
        // BOM の分も位置に数える（02-02「span」）
        assert_eq!(lex_str("\u{FEFF}a").tokens[0].span, sp(3, 4));
    }

    #[test]
    fn invalid_utf8() {
        let e0102 = |start, end| {
            DiagBuilder::new(DiagCode::E0102)
                .primary(sp(start, end))
                .build()
        };
        // 連続する正しくないバイトは一つの診断にまとめ、その後の字句は読める
        let out = lex_bytes(b"a \xFF\xFE b\nc");
        assert_eq!(out.diagnostics, vec![e0102(2, 4)]);
        assert_eq!(
            kinds(&out),
            vec![
                K::LowerIdent,
                K::LowerIdent,
                K::LineBreak,
                K::LowerIdent,
                K::Eof
            ]
        );
        // 途中で切れた並び（`あ` の先頭 2 バイト）
        let out = lex_bytes(b"a\xE3\x81 b");
        assert_eq!(out.diagnostics, vec![e0102(1, 3)]);
        // 文字列とコメントの中でも誤り
        let out = lex_bytes(b"\"a\xFFb\"");
        assert_eq!(out.diagnostics, vec![e0102(2, 3)]);
        assert_eq!(kinds(&out), vec![K::Error, K::Eof]);
        let out = lex_bytes(b"// \xFF\nx");
        assert_eq!(out.diagnostics, vec![e0102(3, 4)]);
        assert_eq!(kinds(&out), vec![K::LineBreak, K::LowerIdent, K::Eof]);
    }

    #[test]
    fn line_breaks() {
        let out = lex_str("a\nb\r\nc");
        assert_eq!(out.diagnostics, vec![]);
        assert_eq!(
            kinds(&out),
            vec![
                K::LowerIdent,
                K::LineBreak,
                K::LowerIdent,
                K::LineBreak,
                K::LowerIdent,
                K::Eof
            ]
        );
        assert_eq!(out.tokens[1].span, sp(1, 2));
        assert_eq!(out.tokens[3].span, sp(3, 5));

        // LF を伴わない CR は誤りで、改行の印にしない
        let out = lex_str("a\rb");
        let expected = DiagBuilder::new(DiagCode::E0107).primary(sp(1, 2)).build();
        assert_eq!(out.diagnostics, vec![expected]);
        assert_eq!(kinds(&out), vec![K::LowerIdent, K::LowerIdent, K::Eof]);
        // コメントの中の CR も同じ（コメントは CR で終わらない）
        let out = lex_str("// a\rb");
        let expected = DiagBuilder::new(DiagCode::E0107).primary(sp(4, 5)).build();
        assert_eq!(out.diagnostics, vec![expected]);
        assert_eq!(out.comments.len(), 1);

        // コメントだけの行と空の行の改行も、それぞれ改行の印にする（まとめるのは改行の判定）
        assert_clean_kinds(
            "a\n// c\n\nb",
            &[
                K::LowerIdent,
                K::LineBreak,
                K::LineBreak,
                K::LineBreak,
                K::LowerIdent,
                K::Eof,
            ],
        );
    }

    #[test]
    fn comments() {
        let out = lex_str("x // hi\ny");
        assert_eq!(out.diagnostics, vec![]);
        assert_eq!(
            kinds(&out),
            vec![K::LowerIdent, K::LineBreak, K::LowerIdent, K::Eof]
        );
        let expected = Comment {
            span: sp(2, 7),
            text: " hi".to_string(),
        };
        assert_eq!(out.comments, vec![expected.clone()]);

        // CR LF の CR はコメントの本文に含めない
        let out = lex_str("x // hi\r\ny");
        assert_eq!(out.comments, vec![expected]);
        assert_eq!(out.tokens[1].span, sp(7, 9));

        // ファイルの終わりで終わるコメントと、`/` 一つの演算子
        let out = lex_str("a / b //");
        assert_eq!(
            kinds(&out),
            vec![K::LowerIdent, K::Slash, K::LowerIdent, K::Eof]
        );
        assert_eq!(
            out.comments,
            vec![Comment {
                span: sp(6, 8),
                text: String::new(),
            }]
        );
    }

    #[test]
    fn diagnostics_follow_source_order_after_recovery() {
        let out = lex_str("let a\u{3000}= \"\\q\"\nreturn b\n\"x\\z");
        let codes: Vec<_> = out.diagnostics.iter().map(|d| d.code).collect();
        assert_eq!(
            codes,
            vec![
                Some(DiagCode::E0103),
                Some(DiagCode::E0110),
                Some(DiagCode::E0117),
                Some(DiagCode::E0108),
                Some(DiagCode::E0110),
            ]
        );
        let starts: Vec<_> = out
            .diagnostics
            .iter()
            .map(|d| d.primary.as_ref().unwrap().span.start)
            .collect();
        assert!(starts.is_sorted(), "starts: {starts:?}");
        assert_eq!(
            kinds(&out),
            vec![
                K::KwLet,
                K::LowerIdent,
                K::Eq,
                K::Error,
                K::LineBreak,
                K::Error,
                K::LowerIdent,
                K::LineBreak,
                K::Error,
                K::Eof,
            ]
        );
    }

    #[test]
    fn spans_stay_in_source_and_end_with_empty_eof() {
        let sources: &[&[u8]] = &[
            b"",
            b"fn main() -> Unit uses IO {\r\n  let x = 1.5e3 // c\n}\n",
            b"\xEF\xBB\xBF'a' \"s\\n\" 0x1F 1_0",
            b"\"abc",
            b"'",
            b"1.",
            b"\"\\u{",
            b"a\xF0\x9F\x98",
            b"\r",
            b"x;y@z 007 12abc return",
        ];
        for src in sources {
            let out = lex_bytes(src);
            let len = u32::try_from(src.len()).unwrap();
            let mut previous_end = 0;
            for token in &out.tokens {
                let Span { file, start, end } = token.span;
                assert_eq!(file, F);
                assert!(start.0 <= end.0 && end.0 <= len, "src: {src:?}, {token:?}");
                assert!(previous_end <= start.0, "overlap in {src:?}: {token:?}");
                previous_end = end.0;
            }
            assert_eq!(out.tokens.last().unwrap(), &eof(len), "src: {src:?}");
            let eof_count = out.tokens.iter().filter(|t| t.kind == K::Eof).count();
            assert_eq!(eof_count, 1, "src: {src:?}");
            for d in &out.diagnostics {
                let span = d.primary.as_ref().unwrap().span;
                assert!(
                    span.start.0 < span.end.0 && span.end.0 <= len,
                    "src: {src:?}, {d:?}"
                );
            }
        }
    }
}
