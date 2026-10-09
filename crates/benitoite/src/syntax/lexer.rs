//! 字句の切り出し（設計書 01-01、02-03「処理の流れ」の工程 1）。
//! 文字列の文脈は局所の積み重ねで扱い、改行の判定は次の工程に委ねる。

mod string;

use super::token::{Comment, CommentKind, Token, TokenKind, TokenValue};
use crate::base::{BytePos, FileId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, Edit};

/// 字句の切り出しの結果。
#[derive(Debug)]
pub struct LexOutput {
    /// 字句と改行の印（`LineBreak`）の列。最後は必ず `Eof`。
    /// フォーマッタ（U4）は、この列を改行の位置を知るために使う（02-03「用途」）
    pub tokens: Vec<Token>,
    /// ドキュメントコメントを含むすべてのコメント。ソースの順
    pub comments: Vec<Comment>,
    pub diagnostics: Vec<Diagnostic>,
}

/// ソースのバイト列（`Source::text()`）を先頭から読み、字句と改行の印の列を作る（02-03「処理の流れ」の 1）。
/// span のファイル ID には `file` を使う。誤りを報告した後も続ける（02-03「字句の誤り」）。
/// ファイルの先頭（先頭の U+FEFF があればその直後）の `#!` から改行の直前までは、シェバンの行として
/// 読み飛ばし、改行の印は残す。
pub fn lex(file: FileId, text: &[u8]) -> LexOutput {
    let mut lexer = Lexer {
        file,
        text,
        tokens: Vec::new(),
        comments: Vec::new(),
        diagnostics: Vec::new(),
        line_limit: None,
    };
    lexer.run();
    lexer
        .diagnostics
        .sort_by_key(|d| d.primary.as_ref().map(|label| label.span.start));
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
    line_limit: Option<(usize, usize)>,
}

impl Lexer<'_> {
    fn run(&mut self) {
        // 先頭の BOM は字句にも誤りにもしない。位置は BOM を含めて数える（01-01、02-02「span」）。
        let mut i = if self.text.starts_with(BOM) {
            BOM.len()
        } else {
            0
        };
        if self.slice(i, add(i, 2)) == b"#!" {
            let end = self.line_end(i);
            self.scan_raw(i, end);
            i = end;
        }
        while self.byte(i).is_some() {
            i = self.step(i);
        }
        let end = self.text.len();
        self.push(TokenKind::Eof, end, end, TokenValue::None);
    }

    /// 通常の字句を一つ読む。補間の式も同じ規則を使う（設計書 02-03「文字列補間」）。
    fn step(&mut self, i: usize) -> usize {
        match self.byte(i) {
            Some(b' ' | b'\t') => add(i, 1),
            Some(b'\n') => {
                self.push(TokenKind::LineBreak, i, add(i, 1), TokenValue::None);
                add(i, 1)
            }
            Some(b'\r') => {
                if self.byte(add(i, 1)) == Some(b'\n') {
                    self.push(TokenKind::LineBreak, i, add(i, 2), TokenValue::None);
                    add(i, 2)
                } else {
                    self.report(DiagBuilder::new(DiagCode::E0107).primary(self.span(i, add(i, 1))));
                    add(i, 1)
                }
            }
            Some(b'r') if self.byte(add(i, 1)) == Some(b'"') => self.string(i, true),
            Some(b'a'..=b'z' | b'A'..=b'Z' | b'_') => self.ident(i),
            Some(b'0'..=b'9') => self.number(i),
            Some(b'"') => self.string(i, false),
            Some(b'\'') => self.char_lit(i),
            Some(b'/') if self.byte(add(i, 1)) == Some(b'/') => self.comment(i),
            Some(b @ 0x21..=0x7E) => self.symbol(i, b),
            Some(b @ 0x00..=0x7F) => {
                self.report_not_allowed(i, 1, char::from(b));
                add(i, 1)
            }
            Some(_) => self.non_ascii_outside(i),
            None => i,
        }
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
    fn line_end(&mut self, from: usize) -> usize {
        // 読み進める同じ行で終端を探し直さず、長いリテラルでも一度だけ走査する。
        if let Some((begin, end)) = self.line_limit
            && begin <= from
            && from <= end
        {
            return end;
        }
        let rest = self.text.get(from..).unwrap_or(&[]);
        let end = match rest.iter().position(|b| *b == b'\n') {
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
        };
        self.line_limit = Some((from, end));
        end
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

    /// 字句を作らずに読み進める範囲（コメントとシェバンの行）で、
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
        let (kind, width) = match (self.byte(add(start, 2)), self.byte(add(start, 3))) {
            (Some(b'!'), _) => (CommentKind::ModuleDoc, 3),
            (Some(b'/'), next) if next != Some(b'/') => (CommentKind::Doc, 3),
            _ => (CommentKind::Plain, 2),
        };
        let body = add(start, width);
        self.scan_raw(body, limit);
        let comment = Comment {
            kind,
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
                let mut builder = DiagBuilder::new(code)
                    .arg("text", text)
                    .primary_label(span, key);
                if code == DiagCode::E0124 && key == "suffix_case" {
                    builder = builder.help_edits(
                        "suffix_case",
                        vec![Edit {
                            span: self.span(end.saturating_sub(1), end),
                            replacement: String::from("m"),
                        }],
                    );
                }
                self.report(builder);
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
                    Some(b'.') => break,
                    Some(b'm') if !self.byte(add(j, 2)).is_some_and(is_ident_byte) => {
                        j = add(j, 2);
                        break;
                    }
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
                DiagBuilder::new(DiagCode::E0113).primary(span).help_edits(
                    "use_string",
                    vec![Edit {
                        span,
                        replacement: char_to_string(&self.lossy(body, close)),
                    }],
                ),
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
            (b'-', Some(b'>')) => (TokenKind::Arrow, 2),
            (b'<', Some(b'-')) => (TokenKind::LeftArrow, 2),
            (b'<', Some(b'>')) => (TokenKind::NotEq, 2),
            (b'<', Some(b'=')) => (TokenKind::Le, 2),
            (b'>', Some(b'=')) => (TokenKind::Ge, 2),
            (b'.', Some(b'.')) => (TokenKind::DotDot, 2),
            (b'=' | b'!', Some(b'='))
            | (b'=', Some(b'>'))
            | (b'&', Some(b'&'))
            | (b'|', Some(b'|')) => (TokenKind::BadSymbol, 2),
            (b'+', _) => (TokenKind::Plus, 1),
            (b'-', _) => (TokenKind::Minus, 1),
            (b'*', _) => (TokenKind::Star, 1),
            (b'/', _) => (TokenKind::Slash, 1),
            (b'<', _) => (TokenKind::Lt, 1),
            (b'>', _) => (TokenKind::Gt, 1),
            (b'=', _) => (TokenKind::Eq, 1),
            (b':', _) => (TokenKind::Colon, 1),
            (b',', _) => (TokenKind::Comma, 1),
            (b'.', _) => (TokenKind::Dot, 1),
            (b'&', _) => (TokenKind::Amp, 1),
            (b'@', _) => (TokenKind::At, 1),
            (b'(', _) => (TokenKind::LParen, 1),
            (b')', _) => (TokenKind::RParen, 1),
            (b'[', _) => (TokenKind::LBracket, 1),
            (b']', _) => (TokenKind::RBracket, 1),
            _ => (TokenKind::BadSymbol, 1),
        };
        let end = add(i, len);
        let value = if kind == TokenKind::BadSymbol {
            TokenValue::Symbol(self.lossy(i, end))
        } else {
            TokenValue::None
        };
        self.push(kind, i, end, value);
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

/// 診断の `char` の値。`U+` と 4 桁以上の大文字の 16 進数にする（F01「字句の誤り」）。
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

// ---- キーワード（01-01「キーワード」） ----

fn keyword(word: &str) -> Option<TokenKind> {
    Some(match word {
        "and" => TokenKind::KwAnd,
        "bind" => TokenKind::KwBind,
        "case" => TokenKind::KwCase,
        "const" => TokenKind::KwConst,
        "data" => TokenKind::KwData,
        "div" => TokenKind::KwDiv,
        "do" => TokenKind::KwDo,
        "effect" => TokenKind::KwEffect,
        "else" => TokenKind::KwElse,
        "end" => TokenKind::KwEnd,
        "false" => TokenKind::KwFalse,
        "function" => TokenKind::KwFunction,
        "handle" => TokenKind::KwHandle,
        "if" => TokenKind::KwIf,
        "implement" => TokenKind::KwImplement,
        "import" => TokenKind::KwImport,
        "lambda" => TokenKind::KwLambda,
        "lazy" => TokenKind::KwLazy,
        "match" => TokenKind::KwMatch,
        "mod" => TokenKind::KwMod,
        "not" => TokenKind::KwNot,
        "or" => TokenKind::KwOr,
        "public" => TokenKind::KwPublic,
        "record" => TokenKind::KwRecord,
        "resume" => TokenKind::KwResume,
        "return" => TokenKind::KwReturn,
        "shadow" => TokenKind::KwShadow,
        "then" => TokenKind::KwThen,
        "trait" => TokenKind::KwTrait,
        "true" => TokenKind::KwTrue,
        "try" => TokenKind::KwTry,
        "type" => TokenKind::KwType,
        "uses" => TokenKind::KwUses,
        "with" => TokenKind::KwWith,
        _ => return None,
    })
}

// ---- 数値の塊の分類 ----

/// 数値の誤り: 診断コード（E0115・E0116・E0124）と、ラベルの鍵。
type NumberError = (DiagCode, &'static str);

/// 数値の塊を、整数リテラルか浮動小数リテラルとして読む。読めなければ誤りの種類を返す。
/// 一つの塊に複数の誤りがあるときは、F01 が引き継ぐ形の誤りの優先順で最初に当たったものだけを返す。
fn classify_number(chunk: &[u8]) -> Result<(TokenKind, TokenValue), NumberError> {
    if let Some(result) = classify_decimal_literal(chunk) {
        return result;
    }
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

    // 直後の識別子の `e` は指数部ではないため、数値部分で読んだ小数点と指数部だけで分類する
    // （設計書 01-01「数値リテラルの直後の文字」）。
    let float_form = frac.is_some() || exp.is_some();
    let code = if float_form {
        DiagCode::E0116
    } else {
        DiagCode::E0115
    };

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

/// 接尾辞の位置までを数値の形として調べる。形の優先順は F01「Decimal の形の誤り」に従う。
fn classify_decimal_literal(chunk: &[u8]) -> Option<Result<(TokenKind, TokenValue), NumberError>> {
    let prefixed = matches!(
        chunk.get(..2),
        Some([b'0', b'x' | b'X' | b'o' | b'O' | b'b' | b'B'])
    );
    let suffix = if prefixed {
        chunk
            .last()
            .filter(|b| matches!(b, b'm' | b'M'))
            .map(|_| chunk.len().saturating_sub(1))
    } else {
        // 数値部分の直後だけを接尾辞とみなし、識別子の途中の `m` は拾わない
        // （設計書 01-01「数値リテラルの直後の文字」）。
        let mut end = digit_run(chunk, 0).len();
        if chunk.get(end) == Some(&b'.') {
            end = add(end, 1);
            end = add(end, digit_run(chunk, end).len());
        }
        if matches!(chunk.get(end), Some(b'e' | b'E')) {
            end = add(end, 1);
            if matches!(chunk.get(end), Some(b'+' | b'-')) {
                end = add(end, 1);
            }
            end = add(end, digit_run(chunk, end).len());
        }
        chunk
            .get(end)
            .filter(|b| matches!(b, b'm' | b'M'))
            .map(|_| end)
    }?;
    let body = chunk.get(..suffix).unwrap_or(&[]);
    let code = DiagCode::E0124;
    let err = |key| Some(Err((code, key)));
    if prefixed {
        return err("base");
    }
    if body.iter().any(|b| matches!(b, b'e' | b'E')) {
        return err("exponent");
    }
    let parsed = classify_decimal(body);
    if chunk.get(suffix) == Some(&b'M') && add(suffix, 1) == chunk.len() && parsed.is_ok() {
        return err("suffix_case");
    }
    if matches!(parsed, Err((_, "leading_zero"))) {
        return err("leading_zero");
    }
    if !underscores_between_digits(chunk, |b| b.is_ascii_digit()) {
        return err("underscore");
    }
    if matches!(parsed, Err((_, "missing_digits"))) {
        return err("missing_digits");
    }
    if parsed.is_err() || add(suffix, 1) != chunk.len() || chunk.get(suffix) != Some(&b'm') {
        return err("suffix");
    }
    Some(Ok((
        TokenKind::DecimalLit,
        TokenValue::Decimal(without_underscores(body)),
    )))
}

/// 元のエスケープを保って引用符を変える。補間の開始もエスケープし、同じ文字の並びを保つ。
fn char_to_string(body: &str) -> String {
    let mut result = String::from("\"");
    let mut chars = body.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '\\' => match chars.next() {
                Some('\'') => result.push('\''),
                Some(c) => {
                    result.push('\\');
                    result.push(c);
                }
                None => result.push_str("\\\\"),
            },
            '"' => result.push_str("\\\""),
            '$' if chars.peek() == Some(&'{') => result.push_str("\\$"),
            c => result.push(c),
        }
    }
    result.push('"');
    result
}

#[cfg(test)]
mod tests;
