//! 文字列と補間の切り出し（設計書 01-01「文字列リテラル」「複数行の文字列と raw 文字列（初回リリース版）」、02-03）。
//! 字下げを先に調べ、読み進める位置は元のソースのバイト位置のまま保つ。

use super::*;

struct Layout {
    begin: usize,
    closing_line: usize,
    close: usize,
    indent: Vec<u8>,
}

#[derive(Clone, Copy)]
enum Mode {
    Content,
    Expr { start: usize, mark: usize },
}

struct Frame {
    start: usize,
    part: usize,
    mark: usize,
    diag_mark: usize,
    raw: bool,
    layout: Option<Layout>,
    interpolated: bool,
    ok: bool,
    mode: Mode,
    value: String,
}

impl Lexer<'_> {
    /// 文脈を積んで進める。入れ子の文字列からこの関数を呼ばない（設計書 02-03「文字列補間と複数行の文字列の切り出し」）。
    pub(super) fn string(&mut self, start: usize, raw: bool) -> usize {
        let (frame, mut i) = self.open_string(start, raw);
        let mut stack = vec![frame];
        while let Some(mut frame) = stack.pop() {
            match frame.mode {
                Mode::Expr { start: expr, mark } => {
                    if self.byte(i).is_none() || self.is_newline(i) {
                        self.report(
                            DiagBuilder::new(DiagCode::E0119)
                                .primary(self.span(expr, add(expr, 2)))
                                .help("one_line"),
                        );
                        frame.ok = false;
                        self.finish_string(frame, i);
                        // 外側の式も同じ行で閉じられなかった。改行は通常の工程で印にする。
                        continue;
                    }
                    match self.byte(i) {
                        Some(b'}') => {
                            if self.tokens.len() == mark {
                                self.report(
                                    DiagBuilder::new(DiagCode::E0118)
                                        .primary(self.span(expr, add(i, 1)))
                                        .help("escape"),
                                );
                                frame.ok = false;
                            }
                            frame.part = i;
                            frame.mode = Mode::Content;
                            i = add(i, 1);
                            stack.push(frame);
                        }
                        Some(b'"') => {
                            i = self.open_nested_string(&mut stack, frame, i, false, expr);
                        }
                        Some(b'r') if self.byte(add(i, 1)) == Some(b'"') => {
                            i = self.open_nested_string(&mut stack, frame, i, true, expr);
                        }
                        Some(b'/') if self.byte(add(i, 1)) == Some(b'/') => {
                            self.report(
                                DiagBuilder::new(DiagCode::E0120)
                                    .primary(self.span(i, add(i, 2)))
                                    .help("move"),
                            );
                            frame.ok = false;
                            i = add(i, 2);
                            stack.push(frame);
                        }
                        Some(_) => {
                            i = self.step(i);
                            stack.push(frame);
                        }
                        None => {}
                    }
                }
                Mode::Content => {
                    let multiline = frame.layout.is_some();
                    let close = frame.layout.as_ref().map(|layout| layout.close);
                    if (close == Some(i) && self.byte(i).is_some())
                        || (!multiline && self.byte(i) == Some(b'"'))
                    {
                        let end = add(i, if multiline { 3 } else { 1 });
                        self.finish_string(frame, end);
                        i = end;
                        continue;
                    }
                    if self.byte(i).is_none() || (!multiline && self.is_newline(i)) {
                        let code = if multiline {
                            DiagCode::E0123
                        } else {
                            DiagCode::E0108
                        };
                        let mut builder = DiagBuilder::new(code).primary(self.span(frame.start, i));
                        if multiline {
                            builder = builder
                                .primary(self.span(
                                    frame.start,
                                    add(frame.start, if frame.raw { 4 } else { 3 }),
                                ))
                                .help("close");
                        } else {
                            builder = builder.help("one_line").help("multi_line");
                        }
                        self.report_at(frame.diag_mark, builder);
                        frame.ok = false;
                        self.finish_string(frame, i);
                        continue;
                    }
                    if let Some(layout) = &frame.layout {
                        if i == layout.closing_line {
                            i = layout.close;
                            stack.push(frame);
                            continue;
                        }
                        if i == layout.begin || self.byte(i.saturating_sub(1)) == Some(b'\n') {
                            let line_end = self.line_end(i);
                            let blank = self
                                .slice(i, line_end)
                                .iter()
                                .all(|b| matches!(b, b' ' | b'\t'));
                            if blank {
                                i = line_end;
                            } else if self.slice(i, add(i, layout.indent.len())) == layout.indent {
                                i = add(i, layout.indent.len());
                            } else {
                                self.report(
                                    DiagBuilder::new(DiagCode::E0122)
                                        .primary(
                                            self.span(i, add(i, layout.indent.len()).min(line_end)),
                                        )
                                        .secondary(
                                            self.span(layout.close, add(layout.close, 3)),
                                            "closing",
                                        )
                                        .note("same_chars"),
                                );
                                frame.ok = false;
                            }
                            // 字下げを除いた位置が行頭と等しい場合も、同じ行を再処理しない。
                        }
                    }
                    if multiline && self.is_newline(i) {
                        frame.value.push('\n');
                        i = self.after_newline(i);
                    } else if !frame.raw
                        && self.byte(i) == Some(b'$')
                        && self.byte(add(i, 1)) == Some(b'{')
                    {
                        let kind = if frame.interpolated {
                            TokenKind::StrMid
                        } else {
                            TokenKind::StrStart
                        };
                        self.push(
                            kind,
                            frame.part,
                            add(i, 2),
                            TokenValue::Str(std::mem::take(&mut frame.value)),
                        );
                        frame.interpolated = true;
                        frame.mode = Mode::Expr {
                            start: i,
                            mark: self.tokens.len(),
                        };
                        i = add(i, 2);
                    } else if !frame.raw
                        && multiline
                        && self.byte(i) == Some(b'\\')
                        && self.is_newline(add(i, 1))
                    {
                        i = self.after_newline(add(i, 1));
                    } else {
                        let limit = self.line_end(i).min(close.unwrap_or(self.text.len()));
                        let (next, unit) = if frame.raw && self.byte(i) == Some(b'\\') {
                            (add(i, 1), Some('\\'))
                        } else {
                            self.literal_unit(i, limit, Quote::Double)
                        };
                        match unit {
                            Some(c) => frame.value.push(c),
                            None => frame.ok = false,
                        }
                        i = next;
                    }
                    stack.push(frame);
                }
            }
        }
        i
    }

    /// 入れ子の開きが改行を含んでも、補間の式はその改行の手前で終える（設計書 01-01「文字列リテラル」）。
    fn open_nested_string(
        &mut self,
        stack: &mut Vec<Frame>,
        mut frame: Frame,
        i: usize,
        raw: bool,
        expr: usize,
    ) -> usize {
        let limit = self.line_end(i);
        let (nested, next) = self.open_string(i, raw);
        if next > limit {
            self.report(
                DiagBuilder::new(DiagCode::E0119)
                    .primary(self.span(expr, add(expr, 2)))
                    .help("one_line"),
            );
            frame.ok = false;
            self.finish_string(frame, limit);
            limit
        } else {
            stack.push(frame);
            stack.push(nested);
            next
        }
    }

    fn open_string(&mut self, start: usize, raw: bool) -> (Frame, usize) {
        let diag_mark = self.diagnostics.len();
        let quote = add(start, usize::from(raw));
        let multi = self.slice(quote, add(quote, 3)) == b"\"\"\"";
        let mut begin = add(quote, if multi { 3 } else { 1 });
        let mut ok = true;
        let layout = if multi {
            let end = self.line_end(begin);
            if begin != end {
                self.report(
                    DiagBuilder::new(DiagCode::E0121)
                        .primary(self.span(begin, end))
                        .help_edits(
                            "newline",
                            vec![Edit {
                                span: self.span(begin, begin),
                                replacement: String::from("\n"),
                            }],
                        ),
                );
                ok = false;
            }
            // 開きの行は内容に含めず、場所によらない文字集合の制限だけを検査する。
            self.scan_raw(begin, end);
            let content = if self.is_newline(end) {
                self.after_newline(end)
            } else {
                begin
            };
            let (closing_line, close) = self
                .find_multiline_close(content, raw)
                .unwrap_or((self.text.len(), self.text.len()));
            let indent = self.slice(closing_line, close).to_vec();
            begin = content;
            Some(Layout {
                begin,
                closing_line,
                close,
                indent,
            })
        } else {
            None
        };
        (
            Frame {
                start,
                part: start,
                mark: self.tokens.len(),
                diag_mark,
                raw,
                layout,
                interpolated: false,
                ok,
                mode: Mode::Content,
                value: String::new(),
            },
            begin,
        )
    }

    fn finish_string(&mut self, frame: Frame, end: usize) {
        if !frame.ok {
            self.tokens.truncate(frame.mark);
            self.push(TokenKind::Error, frame.start, end, TokenValue::None);
        } else {
            let kind = if frame.interpolated {
                TokenKind::StrEnd
            } else {
                TokenKind::StringLit
            };
            self.push(kind, frame.part, end, TokenValue::Str(frame.value));
        }
    }

    fn is_newline(&self, i: usize) -> bool {
        self.byte(i) == Some(b'\n')
            || (self.byte(i) == Some(b'\r') && self.byte(add(i, 1)) == Some(b'\n'))
    }

    fn after_newline(&self, i: usize) -> usize {
        add(i, if self.byte(i) == Some(b'\r') { 2 } else { 1 })
    }

    /// 閉じを探す間も文脈を積む。補間の中の引用符を外側の閉じと取り違えないため。
    fn find_multiline_close(&self, begin: usize, raw: bool) -> Option<(usize, usize)> {
        #[derive(Clone, Copy)]
        enum Scan {
            Content { raw: bool, multi: bool },
            Expr,
            Char,
        }
        let mut stack = vec![Scan::Content { raw, multi: true }];
        let mut i = begin;
        let mut line = begin;
        while let Some(mode) = stack.last().copied() {
            let b = self.byte(i)?;
            match mode {
                Scan::Content { raw, multi } => {
                    if multi
                        && self
                            .slice(line, i)
                            .iter()
                            .all(|b| matches!(b, b' ' | b'\t'))
                        && self.slice(i, add(i, 3)) == b"\"\"\""
                    {
                        if stack.len() == 1 {
                            return Some((line, i));
                        }
                        stack.pop();
                        i = add(i, 3);
                    } else if !multi && b == b'"' {
                        stack.pop();
                        i = add(i, 1);
                    } else if !raw && b == b'\\' {
                        i = add(i, 1);
                        if !self.is_newline(i) {
                            i = add(i, 1);
                        }
                    } else if !raw && b == b'$' && self.byte(add(i, 1)) == Some(b'{') {
                        stack.push(Scan::Expr);
                        i = add(i, 2);
                    } else if self.is_newline(i) {
                        if !multi {
                            stack.pop();
                        }
                        i = self.after_newline(i);
                        line = i;
                    } else {
                        i = add(i, 1);
                    }
                }
                Scan::Expr => {
                    if b == b'}' {
                        stack.pop();
                        i = add(i, 1);
                    } else if b == b'"' || (b == b'r' && self.byte(add(i, 1)) == Some(b'"')) {
                        let raw = b == b'r';
                        let q = add(i, usize::from(raw));
                        let multi = self.slice(q, add(q, 3)) == b"\"\"\"";
                        stack.push(Scan::Content { raw, multi });
                        i = add(q, if multi { 3 } else { 1 });
                    } else if b == b'\'' {
                        stack.push(Scan::Char);
                        i = add(i, 1);
                    } else if self.is_newline(i) {
                        stack.pop();
                    } else {
                        i = add(i, 1);
                    }
                }
                Scan::Char => {
                    if b == b'\'' {
                        stack.pop();
                        i = add(i, 1);
                    } else if b == b'\\' {
                        i = add(i, 2);
                    } else if self.is_newline(i) {
                        stack.pop();
                    } else {
                        i = add(i, 1);
                    }
                }
            }
        }
        None
    }
}
