//! 宣言と属性、説明の結び付け（設計書 01-02、02-03「文脈の制限」）。
use super::{PResult, Parser, Recovery, child, exprs, foreign, text, types};
use crate::base::{BytePos, SourceKind, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic, Edit};
use crate::syntax::{
    ast::*,
    token::{Comment, CommentKind, Token, TokenKind, TokenValue},
};

pub(super) struct DocStore<'a> {
    pub(super) text: &'a [u8],
    pub(super) comments: &'a [Comment],
    used: Vec<bool>,
}
impl<'a> DocStore<'a> {
    pub(super) fn new(text: &'a [u8], comments: &'a [Comment]) -> Self {
        Self {
            text,
            comments,
            used: vec![false; comments.len()],
        }
    }
    fn bytes(&self, start: BytePos, end: BytePos) -> &[u8] {
        usize::try_from(start.0)
            .ok()
            .zip(usize::try_from(end.0).ok())
            .and_then(|(start, end)| self.text.get(start..end))
            .unwrap_or_default()
    }
    fn adjacent(&self, end: BytePos, start: BytePos) -> bool {
        let gap = self.bytes(end, start);
        gap.iter().all(u8::is_ascii_whitespace) && gap.iter().filter(|b| **b == b'\n').count() == 1
    }
    fn own_line(&self, start: BytePos) -> bool {
        // 先頭の BOM は字句解析で読み飛ばすため、説明の前のコードとは数えない
        // （設計書 01-01「ソースファイルと文字集合」）。
        let offset = if self.text.starts_with(&[0xef, 0xbb, 0xbf]) {
            BytePos(3)
        } else {
            BytePos(0)
        };
        self.bytes(offset, start)
            .iter()
            .rev()
            .take_while(|b| **b != b'\n')
            .all(|b| matches!(b, b' ' | b'\t' | b'\r'))
    }
    fn collect(&mut self, first: usize, end: usize) -> Option<DocComment> {
        let lines = self.comments.get(first..end)?;
        let span = lines.first()?.span.to(lines.last()?.span);
        let text = lines
            .iter()
            .map(|c| c.text.as_str())
            .collect::<Vec<_>>()
            .join("\n");
        if let Some(used) = self.used.get_mut(first..end) {
            used.fill(true);
        }
        Some(DocComment { span, text })
    }
    pub(super) fn take_for(
        &mut self,
        start: Span,
        _diagnostics: &mut Vec<Diagnostic>,
    ) -> Option<DocComment> {
        let end = self.comments.partition_point(|c| c.span.end <= start.start);
        let mut first = end;
        let mut next = start.start;
        while let Some(index) = first.checked_sub(1) {
            let comment = self.comments.get(index)?;
            if comment.kind != CommentKind::Doc
                || self.used.get(index).copied().unwrap_or(true)
                || !self.adjacent(comment.span.end, next)
                || !self.own_line(comment.span.start)
            {
                break;
            }
            first = index;
            next = comment.span.start;
        }
        if first == end {
            None
        } else {
            self.collect(first, end)
        }
    }
    pub(super) fn module_doc(&mut self, _diagnostics: &mut Vec<Diagnostic>) -> Option<DocComment> {
        let mut offset = if self.text.starts_with(&[0xef, 0xbb, 0xbf]) {
            3
        } else {
            0
        };
        if self
            .text
            .get(offset..)
            .is_some_and(|s| s.starts_with(b"#!"))
        {
            offset = self
                .text
                .iter()
                .enumerate()
                .skip(offset)
                .find(|(_, b)| **b == b'\n')
                .map_or(self.text.len(), |(i, _)| i.saturating_add(1));
        }
        let first = self.comments.first()?;
        let prefix = self
            .text
            .get(offset..usize::try_from(first.span.start.0).ok()?)?;
        if first.kind != CommentKind::ModuleDoc || !prefix.iter().all(|b| matches!(b, b' ' | b'\t'))
        {
            return None;
        }
        let mut end = 1_usize;
        let mut previous = first.span.end;
        for c in self.comments.iter().skip(1) {
            if c.kind != CommentKind::ModuleDoc || !self.adjacent(previous, c.span.start) {
                break;
            }
            end = end.saturating_add(1);
            previous = c.span.end;
        }
        self.collect(0, end)
    }
    pub(super) fn finish(&mut self, diagnostics: &mut Vec<Diagnostic>) {
        for (i, comment) in self.comments.iter().enumerate() {
            if self.used.get(i).copied().unwrap_or(false) || comment.kind == CommentKind::Plain {
                continue;
            }
            let code = if comment.kind == CommentKind::Doc {
                DiagCode::E0228
            } else {
                DiagCode::E0229
            };
            let prefix = Span {
                end: BytePos(comment.span.start.0.saturating_add(3)),
                ..comment.span
            };
            diagnostics.push(
                DiagBuilder::new(code)
                    .primary(comment.span)
                    .help_edits(
                        "plain",
                        vec![Edit {
                            span: prefix,
                            replacement: "//".to_owned(),
                        }],
                    )
                    .build(),
            );
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum BodyRule {
    Required,
    Omitted,
}
pub(super) fn body_rule(attrs: &[Attribute], _kind: SourceKind) -> BodyRule {
    if attrs.iter().any(|a| a.name.text == "builtin") {
        BodyRule::Omitted
    } else {
        BodyRule::Required
    }
}
pub(super) fn check_decl_header(p: &mut Parser, decl: &TopDecl) {
    let (function, allowed, what) = match &decl.item {
        Item::Fn(_) => (true, true, text::FUNCTION),
        Item::Const(_) => (false, true, text::CONSTANT),
        Item::Data(_) => (false, true, text::DATA),
        Item::Alias(_) => (false, true, text::ALIAS),
        Item::Record(_) => (false, true, text::RECORD),
        Item::Trait(_) => (false, true, text::TRAIT),
        Item::Effect(_) => (false, true, text::EFFECT),
        Item::Impl(_) => (false, false, text::IMPLEMENT),
        // F04 の仮の本体でも、実装の頭に付けた属性は検査できるようにする。
        Item::Error(e) => {
            if p.tokens
                .iter()
                .any(|t| t.span.start == e.span.start && t.kind == TokenKind::KwImplement)
            {
                (false, false, text::IMPLEMENT)
            } else {
                return;
            }
        }
    };
    for attr in &decl.attrs {
        if attribute_reported(p, attr.span) {
            continue;
        }
        let accepted = match attr.name.text.as_str() {
            "test" | "builtin" => function,
            "deprecated" => allowed,
            _ => true,
        };
        if !accepted {
            p.suppressed = false;
            p.report(
                DiagBuilder::new(DiagCode::E0802)
                    .arg("name", &attr.name.text)
                    .arg("what", what)
                    .primary(attr.span)
                    .build(),
            );
        }
    }
}
fn attribute_reported(p: &Parser, span: Span) -> bool {
    p.diagnostics.iter().any(|d| {
        d.primary
            .as_ref()
            .is_some_and(|s| s.span.start >= span.start && s.span.end <= span.end)
    })
}
pub(super) fn reject_public(p: &mut Parser, span: Span) {
    let what = if p.at(TokenKind::KwImplement) {
        text::IMPLEMENT
    } else {
        text::FUNCTION
    };
    let removal = Span {
        end: p.peek().span.start,
        ..span
    };
    p.report(
        DiagBuilder::new(DiagCode::E0221)
            .arg("what", what)
            .primary(span)
            .help_edits(
                "remove",
                vec![Edit {
                    span: removal,
                    replacement: String::new(),
                }],
            )
            .help("implement")
            .build(),
    );
}
pub(super) fn parse_public(p: &mut Parser) -> Option<Span> {
    if !p.at(TokenKind::KwPublic) {
        return None;
    }
    let span = p.bump().span;
    if p.at(TokenKind::KwImplement) {
        reject_public(p, span);
    }
    Some(span)
}
pub(super) fn report_missing_body(p: &mut Parser, name: &Name, _attrs: &[Attribute]) {
    p.report(
        DiagBuilder::new(DiagCode::E0808)
            .arg("name", &name.text)
            .primary(name.span)
            .help("body")
            .build(),
    );
}
pub(super) fn parse_import(
    p: &mut Parser,
    first_decl: Option<Span>,
    depth: u32,
) -> PResult<ImportDecl> {
    p.enter(depth)?;
    let start = p.pos;
    let keyword = p.expect(TokenKind::KwImport)?.span;
    if let Some(first) = first_decl {
        p.report(
            DiagBuilder::new(DiagCode::E0219)
                .primary(keyword)
                .secondary(first, "first")
                .build(),
        );
    }
    if p.at(TokenKind::StringLit) {
        return path_import(p, start, String::new());
    }
    let path = p.qual_name(true)?;
    if p.word("from") {
        let module = path
            .iter()
            .map(|n| n.text.as_str())
            .collect::<Vec<_>>()
            .join(".");
        return path_import(p, start, module);
    }
    let alias = if p.word("as") {
        p.bump();
        Some(p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?)
    } else {
        None
    };
    Ok(ImportDecl {
        id: p.node_id(),
        span: p.span_from(start),
        path,
        alias,
    })
}
fn path_import(p: &mut Parser, _start: usize, mut module: String) -> PResult<ImportDecl> {
    let at = p.peek().span;
    while !matches!(p.peek_kind(), TokenKind::Newline | TokenKind::Eof) && !p.aborted {
        if let TokenValue::Str(path) = &p.peek().value {
            let path = path.strip_prefix("./").unwrap_or(path);
            let path = path.strip_suffix(".bnt").unwrap_or(path);
            module = path
                .split('/')
                .map(|part| {
                    let mut chars = part.chars();
                    chars
                        .next()
                        .map_or(String::new(), |c| c.to_uppercase().chain(chars).collect())
                })
                .collect::<Vec<_>>()
                .join(".");
        }
        p.advance();
    }
    p.suppressed = false;
    p.report(
        DiagBuilder::new(DiagCode::E0244)
            .arg("module", module)
            .primary(at)
            .help("by_name")
            .build(),
    );
    Err(super::Fail)
}

pub(super) fn parse_attributes(p: &mut Parser) -> Vec<Attribute> {
    let mut attrs: Vec<Attribute> = Vec::new();
    loop {
        if foreign_attribute(p) {
            p.skip_newlines();
            continue;
        }
        if !p.at(TokenKind::At) || p.aborted {
            break;
        }
        let start = p.pos;
        p.bump();
        let name = if matches!(p.peek_kind(), TokenKind::LowerIdent | TokenKind::UpperIdent) {
            super::name_of(&p.bump())
        } else {
            p.unexpected(text::ATTRIBUTE);
            p.recover(p.pos, Recovery::Line);
            p.skip_newlines();
            continue;
        };
        let name_error = attribute_name_error(p, &name);
        let duplicate = attrs
            .iter()
            .find(|a| a.name.text == name.text)
            .map(|a| a.span);
        let mut args = Vec::new();
        let mut invalid = None;
        if p.eat(TokenKind::LParen) {
            while !matches!(
                p.peek_kind(),
                TokenKind::RParen | TokenKind::Eof | TokenKind::Newline
            ) && !p.aborted
            {
                if p.at(TokenKind::StringLit) {
                    let token = p.bump();
                    if let TokenValue::Str(value) = token.value {
                        args.push(StrArg {
                            span: token.span,
                            value,
                        });
                    }
                } else {
                    invalid.get_or_insert(p.peek().span);
                    skip_attribute_arg(p);
                }
                if !p.eat(TokenKind::Comma) {
                    break;
                }
            }
            if !p.eat(TokenKind::RParen)
                && name_error.is_none()
                && duplicate.is_none()
                && invalid.is_none()
            {
                p.unexpected(text::RPAREN);
            }
        }
        let attr = Attribute {
            id: p.node_id(),
            span: p.span_from(start),
            name,
            args,
        };
        let diagnostic = if let Some(d) = name_error {
            Some(d)
        } else if let Some(first) = duplicate {
            Some(
                DiagBuilder::new(DiagCode::E0803)
                    .arg("name", &attr.name.text)
                    .primary(attr.span)
                    .secondary(first, "first")
                    .help_edits(
                        "remove",
                        vec![Edit {
                            span: attr.span,
                            replacement: String::new(),
                        }],
                    )
                    .build(),
            )
        } else if let Some(at) = invalid {
            Some(
                DiagBuilder::new(DiagCode::E0220)
                    .primary(at)
                    .help("plain")
                    .build(),
            )
        } else {
            attribute_args_error(p, &attr)
        };
        if let Some(d) = diagnostic {
            p.suppressed = false;
            p.report(d);
        }
        attrs.push(attr);
        p.skip_newlines();
    }
    attrs
}
fn attribute_name_error(p: &Parser, name: &Name) -> Option<Diagnostic> {
    if name.text.chars().next().is_some_and(char::is_uppercase) {
        let d = DiagBuilder::new(DiagCode::E0247).primary(name.span);
        return Some(
            if name.text == "Test" {
                d.help_edits(
                    "test",
                    vec![Edit {
                        span: name.span,
                        replacement: name.text.to_lowercase(),
                    }],
                )
            } else {
                d.help("other")
            }
            .build(),
        );
    }
    match name.text.as_str() {
        "doc" => Some(
            DiagBuilder::new(DiagCode::E0249)
                .primary(name.span)
                .help("doc")
                .build(),
        ),
        "builtin" if p.kind != SourceKind::Prelude => Some(
            DiagBuilder::new(DiagCode::E0807)
                .primary(name.span)
                .help("remove")
                .build(),
        ),
        "test" | "deprecated" | "builtin" => None,
        _ => Some(
            DiagBuilder::new(DiagCode::E0801)
                .arg("name", &name.text)
                .primary(name.span)
                .help("allowed")
                .build(),
        ),
    }
}
fn attribute_args_error(p: &Parser, attr: &Attribute) -> Option<Diagnostic> {
    let d = match attr.name.text.as_str() {
        "test" if attr.args.len() > 1 => DiagBuilder::new(DiagCode::E0805),
        "deprecated"
            if attr.args.len() != 1 || attr.args.first().is_some_and(|a| a.value.is_empty()) =>
        {
            DiagBuilder::new(DiagCode::E0804).help("message")
        }
        "builtin" if attr.args.len() != 1 => DiagBuilder::new(DiagCode::E0201)
            .arg("expected", text::token_name(TokenKind::StringLit))
            .arg("found", text::describe(p.peek())),
        _ => return None,
    };
    Some(d.primary(attr.span).build())
}
fn skip_attribute_arg(p: &mut Parser) {
    // 補間を式として解析すると F04 の診断が重なる。属性では引数全体を読み飛ばす
    // （設計書 02-03「文脈の制限」）。
    let mut nesting = Vec::new();
    let mut interpolation = 0_u32;
    loop {
        if p.at(TokenKind::Eof) || p.aborted {
            break;
        }
        if nesting.is_empty()
            && interpolation == 0
            && matches!(
                p.peek_kind(),
                TokenKind::Comma | TokenKind::RParen | TokenKind::Newline
            )
        {
            break;
        }
        let kind = p.peek_kind();
        if kind == TokenKind::StrStart {
            interpolation = interpolation.saturating_add(1);
        }
        if kind == TokenKind::StrEnd {
            interpolation = interpolation.saturating_sub(1);
        }
        if matches!(kind, TokenKind::LParen | TokenKind::LBracket) {
            nesting.push(kind);
        } else if matches!(kind, TokenKind::RParen | TokenKind::RBracket) {
            nesting.pop();
        }
        p.advance();
    }
}

pub(super) fn try_foreign_decl_start(p: &mut Parser, depth: u32) -> Option<PResult<Item>> {
    if p.word("typealias") {
        return Some(parse_alias_decl(p, depth));
    }
    let close = if p.at(TokenKind::Slash)
        && p.peek_nth_kind(1) == TokenKind::Star
        && p.peek_nth_kind(2) == TokenKind::Star
    {
        "*/"
    } else if p.symbol("{")
        && p.peek_nth_kind(1) == TokenKind::Minus
        && p.tokens
            .get(p.pos.saturating_add(2))
            .is_some_and(|t| matches!(&t.value, TokenValue::Symbol(s) if s == "|"))
    {
        "-}"
    } else if p.at(TokenKind::LParen)
        && p.peek_nth_kind(1) == TokenKind::Star
        && p.peek_nth_kind(2) == TokenKind::Star
    {
        "*)"
    } else {
        if foreign_attribute(p) {
            return Some(Ok(Item::Error(p.error_node_from(p.pos))));
        }
        return None;
    };
    let start = p.pos;
    let at = p.peek().span;
    // 外国語のコメントの中は Benitoite の記号として報告しない（設計書 02-03）。
    for _ in 0..3 {
        claim_advance(p);
    }
    while !p.at(TokenKind::Eof) && !p.aborted {
        if (p.at_line_start() || line_gap(p).is_some()) && super::is_decl_start(p.peek_kind()) {
            break;
        }
        let first = p.snippet(p.peek().span);
        let next = p
            .tokens
            .get(p.pos.saturating_add(1))
            .map(|t| p.snippet(t.span))
            .unwrap_or_default();
        let joined = format!("{first}{next}");
        if joined == close {
            claim_advance(p);
            claim_advance(p);
            break;
        }
        claim_advance(p);
    }
    p.suppressed = false;
    p.report(
        DiagBuilder::new(DiagCode::E0249)
            .primary(at)
            .help("doc")
            .build(),
    );
    restore_newline(p);
    Some(Ok(Item::Error(p.error_node_from(start))))
}
fn claim_advance(p: &mut Parser) {
    if p.at(TokenKind::BadSymbol) {
        p.reported_symbols.insert(p.pos);
    }
    p.advance();
}
fn foreign_attribute(p: &mut Parser) -> bool {
    let rust = p.symbol("#") && p.peek_nth_kind(1) == TokenKind::LBracket;
    let fsharp = p.at(TokenKind::LBracket) && p.peek_nth_kind(1) == TokenKind::Lt;
    if !rust && !fsharp {
        return false;
    }
    let start = p.pos;
    claim_advance(p);
    while !p.at(TokenKind::Eof) && !p.aborted {
        if (p.at_line_start() || line_gap(p).is_some()) && super::is_decl_start(p.peek_kind()) {
            break;
        }
        let closing = p.at(TokenKind::RBracket);
        claim_advance(p);
        if closing {
            break;
        }
    }
    p.suppressed = false;
    p.report(
        DiagBuilder::new(DiagCode::E0247)
            .primary(p.span_from(start))
            .help_edits(
                "test",
                vec![Edit {
                    span: p.span_from(start),
                    replacement: "@test".to_owned(),
                }],
            )
            .build(),
    );
    true
}

fn line_gap(p: &Parser) -> Option<Span> {
    let previous = p.pos.checked_sub(1).and_then(|i| p.tokens.get(i))?;
    let start = usize::try_from(previous.span.end.0).ok()?;
    let end = usize::try_from(p.peek().span.start.0).ok()?;
    let offset = p.text.get(start..end)?.iter().position(|b| *b == b'\n')?;
    let at = BytePos(u32::try_from(start.checked_add(offset)?).ok()?);
    Some(Span {
        file: p.file,
        start: at,
        end: BytePos(at.0.saturating_add(1)),
    })
}
fn restore_newline(p: &mut Parser) {
    // 外国語の `*/` の末尾の `/` と閉じていない括弧のために、改行判定が区切りを消すことがある。
    // 読み飛ばした形式の直後の物理的な改行を戻し、次の宣言を回復点として残す（設計書 02-03）。
    if p.at(TokenKind::Newline) || p.at(TokenKind::Eof) {
        return;
    }
    if let Some(span) = line_gap(p) {
        p.tokens.insert(
            p.pos,
            Token {
                kind: TokenKind::Newline,
                span,
                value: TokenValue::None,
            },
        );
    }
}

pub(super) fn stub_decl(
    p: &mut Parser,
    depth: u32,
    expected: &str,
    end: Option<TokenKind>,
) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    p.unexpected(expected);
    p.advance();
    if let Some(end) = end {
        let mut nested = Vec::new();
        let mut previous = TokenKind::Eof;
        while !p.at(TokenKind::Eof) {
            if p.at(TokenKind::KwEnd) && p.peek_nth_kind(1) == end {
                p.advance();
                p.advance();
                break;
            }
            if nested.is_empty()
                && p.at_line_start()
                && super::is_decl_start(p.peek_kind())
                // trait と effect のシグネチャ、implement の関数は宣言の内側にある。
                // 仮の本体の段階でも、それを次のトップレベルの宣言として残さない（F02 のフック）。
                && !(matches!(end, TokenKind::KwImplement | TokenKind::KwTrait | TokenKind::KwEffect)
                    && p.at(TokenKind::KwFunction))
            {
                break;
            }
            let kind = p.peek_kind();
            if kind == TokenKind::KwFunction
                && previous != TokenKind::KwEnd
                && end == TokenKind::KwImplement
            {
                nested.push(kind);
            } else {
                super::recovery_nesting(&mut nested, kind, previous);
            }
            previous = kind;
            p.advance();
        }
    } else {
        p.recover(start, Recovery::TopLevel);
    }
    Ok(Item::Error(p.error_node_from(start)))
}
pub(super) fn parse_record_decl(p: &mut Parser, depth: u32) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    let keyword = p.expect(TokenKind::KwRecord)?.span;
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    let type_params = types::parse_type_params(p, depth, false)?;
    p.open_block(TokenKind::KwRecord, keyword);
    let mut fields = Vec::new();
    let mut attempted = false;
    p.skip_newlines();
    while !matches!(p.peek_kind(), TokenKind::KwEnd | TokenKind::Eof)
        && !p.aborted
        && !p.symbol("}")
    {
        if super::is_decl_start(p.peek_kind()) {
            break;
        }
        attempted = true;
        let from = p.pos;
        if push_field(p, child(depth), &mut fields).is_err() {
            p.recover(from, Recovery::Line);
        }
        if p.pos == from {
            p.advance();
        }
        if !matches!(
            p.peek_kind(),
            TokenKind::Newline | TokenKind::KwEnd | TokenKind::Eof
        ) {
            p.unexpected(text::NEWLINE_OR_END);
            p.recover(p.pos, Recovery::Line);
        }
        p.skip_newlines();
    }
    if fields.is_empty() && !attempted && !p.aborted {
        p.unexpected(text::FIELD);
    }
    p.close_block(TokenKind::KwRecord);
    Ok(Item::Record(RecordDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        type_params,
        fields,
    }))
}
fn push_field(p: &mut Parser, depth: u32, out: &mut Vec<FieldDecl>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let doc = p.docs.take_for(p.peek().span, &mut p.diagnostics);
    let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
    p.expect(TokenKind::Colon)?;
    let ty = *types::parse_type(p, child(depth))?;
    out.push(FieldDecl {
        id: p.node_id(),
        span: p.span_from(start),
        doc,
        name,
        ty,
    });
    Ok(())
}
pub(super) fn parse_alias_decl(p: &mut Parser, depth: u32) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    let foreign = if p.word("typealias") {
        Some(p.bump().span)
    } else {
        p.expect(TokenKind::KwType)?;
        if p.word("alias") {
            Some(p.bump().span)
        } else {
            None
        }
    };
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    if let Some(at) = foreign {
        p.report(
            DiagBuilder::new(DiagCode::E0248)
                .arg("name", &name.text)
                .primary(at)
                .help("alias")
                .build(),
        );
    }
    let type_params = types::parse_type_params(p, depth, false)?;
    p.expect(TokenKind::Eq)?;
    let ty = *types::parse_type(p, child(depth))?;
    if p.symbol("|") {
        foreign::report_symbol(
            p,
            DiagBuilder::new(DiagCode::E0237)
                .primary(p.peek().span)
                .help("data")
                .build(),
        );
        while !matches!(p.peek_kind(), TokenKind::Newline | TokenKind::Eof) && !p.aborted {
            // 一つの構成子の並びについて一つだけ報告する。
            if p.symbol("|") {
                p.reported_symbols.insert(p.pos);
            }
            p.advance();
        }
    }
    Ok(Item::Alias(AliasDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        type_params,
        ty,
    }))
}
pub(super) fn parse_const_decl(p: &mut Parser, depth: u32) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    p.expect(TokenKind::KwConst)?;
    let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
    p.expect(TokenKind::Colon)?;
    let ty = *types::parse_type(p, child(depth))?;
    p.expect(TokenKind::Eq)?;
    let value = exprs::parse_expr(p, child(depth))?;
    Ok(finish_const(p, start, name, ty, *value))
}
fn finish_const(p: &mut Parser, start: usize, name: Name, ty: TypeExpr, value: Expr) -> Item {
    Item::Const(ConstDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        ty,
        value,
    })
}

/// 開き括弧の位置から、対応する閉じ括弧も含めて飛ばす。仮のフックの回復で共有する。
pub(super) fn skip_delimited(p: &mut Parser) {
    let mut nested = Vec::new();
    let mut previous = TokenKind::Eof;
    loop {
        if p.at(TokenKind::Eof) {
            return;
        }
        let kind = p.peek_kind();
        super::recovery_nesting(&mut nested, kind, previous);
        previous = kind;
        p.advance();
        if nested.is_empty() {
            return;
        }
    }
}

#[cfg(test)]
// 公開の parse の AST・診断・回復を契約として確かめる。F02 の仮の本体のテストを置き換え、
// 各規則の境界の場合を表にまとめる。内部のフックを直接呼ばず、本物の字句解析と改行判定を使う
// （test-audit の作成時の関門、設計書 07-03「テストの設計の原則」）。失敗は panic で表す（00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::syntax::parser::{
        ParseOutput,
        test_support::{assert_recovers, codes, parse_source, position},
    };
    fn user(src: &str) -> ParseOutput {
        let (out, lex) = parse_source(src, SourceKind::User);
        assert!(lex.is_empty(), "{src}: {lex:?}");
        out
    }
    const FUNCTION: &str = "function f() -> Unit\n()\nend function";

    #[test]
    fn imports_preserve_names_aliases_and_report_order_and_paths() {
        let src =
            format!("import Lib.Text\nimport Benitoite.IO.Console as C\n{FUNCTION}\nimport Lib.A");
        let out = user(&src);
        assert_eq!(codes(&out), [DiagCode::E0219]);
        assert_eq!(out.module.imports.len(), 3);
        assert_eq!(
            out.module.imports[0]
                .path
                .iter()
                .map(|n| n.text.as_str())
                .collect::<Vec<_>>(),
            ["Lib", "Text"]
        );
        assert_eq!(out.module.imports[1].path.len(), 3);
        assert_eq!(out.module.imports[1].alias.as_ref().unwrap().text, "C");
        let d = &out.diagnostics[0];
        assert_eq!(
            d.primary.as_ref().unwrap().span.start,
            position(&src, "import Lib.A").unwrap()
        );
        assert_eq!(
            d.secondary[0].span.start,
            position(&src, "function f").unwrap()
        );
        for (src, name) in [
            ("import \"./lib/text.bnt\"", "Lib.Text"),
            ("import Text from \"./text.bnt\"", "Text"),
            ("import Lib.Text from", "Lib.Text"),
        ] {
            let full = format!("{src}\n{FUNCTION}");
            let out = user(&full);
            assert_eq!(codes(&out), [DiagCode::E0244]);
            assert!(
                out.diagnostics[0].helps[0]
                    .message
                    .contains(&format!("import {name}"))
            );
            assert!(matches!(&out.module.decls[0].item, Item::Fn(f) if f.name.text == "f"));
        }
    }

    #[test]
    fn public_and_attributes_are_attached_to_the_declaration() {
        let src = format!(
            "@test\npublic {FUNCTION}\n@test(\"adds\") {FUNCTION}\n@deprecated(\"use g\") {FUNCTION}"
        );
        let out = user(&src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        assert!(out.module.decls[0].public.is_some());
        let attrs: Vec<_> = out
            .module
            .decls
            .iter()
            .map(|d| {
                (
                    &d.attrs[0].name.text,
                    d.attrs[0]
                        .args
                        .iter()
                        .map(|a| a.value.as_str())
                        .collect::<Vec<_>>(),
                )
            })
            .collect();
        assert_eq!(
            attrs,
            [
                (&"test".to_owned(), vec![]),
                (&"test".to_owned(), vec!["adds"]),
                (&"deprecated".to_owned(), vec!["use g"])
            ]
        );
        let src =
            "public implement Show[T]\nend implement\nfunction after() -> Unit\n()\nend function";
        let out = user(src);
        assert_eq!(codes(&out), [DiagCode::E0221]);
        let edit = &out.diagnostics[0].helps[0].edits[0];
        assert_eq!(edit.span.start, BytePos(0));
        assert_eq!(edit.span.end, position(src, "implement").unwrap());
        assert!(edit.replacement.is_empty());
        assert!(
            matches!(out.module.decls.last().map(|d| &d.item), Some(Item::Fn(f)) if f.name.text == "after")
        );
    }

    #[test]
    fn invalid_attributes_report_one_diagnostic_per_attribute() {
        for (attr, code) in [
            ("@Test", DiagCode::E0247),
            ("@Other(1)", DiagCode::E0247),
            ("@doc", DiagCode::E0249),
            ("@inline(x)", DiagCode::E0801),
            ("@test(\"a\", \"b\")", DiagCode::E0805),
            ("@deprecated", DiagCode::E0804),
            ("@deprecated(\"\")", DiagCode::E0804),
            ("@deprecated(\"a\", \"b\")", DiagCode::E0804),
            ("@test @test", DiagCode::E0803),
            ("@deprecated(x)", DiagCode::E0220),
            ("@deprecated(\"a${x}\")", DiagCode::E0220),
            ("@Test(\"a${x}\")", DiagCode::E0247),
        ] {
            let src = format!("{attr}\n{FUNCTION}");
            let out = user(&src);
            assert_eq!(codes(&out), [code], "{src}: {:?}", out.diagnostics);
            let d = &out.diagnostics[0];
            if attr == "@Test" {
                let edit = &d.helps[0].edits[0];
                assert_eq!(edit.span.start, BytePos(1));
                assert_eq!(edit.span.end, BytePos(5));
                assert_eq!(edit.replacement, "test");
            }
            if code == DiagCode::E0803 {
                assert_eq!(d.secondary[0].span.start, BytePos(0));
                assert_eq!(d.primary.as_ref().unwrap().span.start, BytePos(6));
                assert_eq!(d.helps[0].edits[0].span.start, BytePos(6));
                assert!(d.helps[0].edits[0].replacement.is_empty());
            }
            if code == DiagCode::E0220 {
                let needle = if attr.contains("${") {
                    "\"a${x}\""
                } else {
                    "x"
                };
                assert_eq!(
                    d.primary.as_ref().unwrap().span.start,
                    position(&src, needle).unwrap()
                );
            }
        }
        assert_recovers("@test\ndata D\nC\nend data", &[DiagCode::E0802]);
        // F04 の実装の仮の本体による E0201 と、属性の位置の E0802 は別の誤りである。
        let out = user("@deprecated(\"x\")\nimplement Show[T]\nend implement");
        assert_eq!(
            codes(&out)
                .into_iter()
                .filter(|c| *c != DiagCode::E0201)
                .collect::<Vec<_>>(),
            [DiagCode::E0802]
        );
        for decl in [
            "const n: Integer = 1",
            "type N = Integer",
            "record R\nx: Integer\nend record",
            "data D\nC\nend data",
        ] {
            let out = user(&format!("@deprecated(\"use another\")\n{decl}"));
            assert!(out.diagnostics.is_empty(), "{decl}: {:?}", out.diagnostics);
        }
    }

    #[test]
    fn builtin_signatures_and_missing_bodies_preserve_the_next_function() {
        let src = format!(
            "@builtin(\"Integer.add\")\nfunction add(a: Integer, b: Integer) -> Integer\n{FUNCTION}"
        );
        for (kind, expected) in [
            (SourceKind::Prelude, vec![]),
            (SourceKind::User, vec![DiagCode::E0807]),
        ] {
            let (out, lex) = parse_source(&src, kind);
            assert!(lex.is_empty());
            assert_eq!(codes(&out), expected);
            assert!(matches!(&out.module.decls[0].item, Item::Fn(f) if f.body.is_none()));
            assert!(matches!(&out.module.decls[1].item, Item::Fn(f) if f.body.is_some()));
        }
        let out = user(&format!("function missing() -> Unit\n{FUNCTION}"));
        assert_eq!(codes(&out), [DiagCode::E0808]);
        assert!(out.diagnostics[0].message.contains("missing"));
        assert!(matches!(&out.module.decls[0].item, Item::Fn(f) if f.body.is_none()));
        assert!(matches!(&out.module.decls[1].item, Item::Fn(f) if f.name.text == "f"));
        for attr in ["@builtin", "@builtin(\"a\", \"b\")"] {
            let (out, _) = parse_source(
                &format!("{attr}\nfunction native() -> Unit"),
                SourceKind::Prelude,
            );
            assert_eq!(codes(&out), [DiagCode::E0201]);
        }
    }

    #[test]
    fn aliases_constants_and_record_declarations_build_their_ast() {
        let src = "type UserId = Integer\ntype Validator[T] = function(T) -> Result[T, String]\nrecord Person\nname: String\nage: Integer\nend record";
        let out = user(src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        assert!(
            matches!(&out.module.decls[0].item, Item::Alias(a) if a.name.text == "UserId" && matches!(a.ty, TypeExpr::Named(_)))
        );
        assert!(
            matches!(&out.module.decls[1].item, Item::Alias(a) if a.type_params.len() == 1 && matches!(a.ty, TypeExpr::Fn(_)))
        );
        let Item::Record(r) = &out.module.decls[2].item else {
            panic!()
        };
        assert_eq!(
            r.fields
                .iter()
                .map(|f| f.name.text.as_str())
                .collect::<Vec<_>>(),
            ["name", "age"]
        );
        for (src, code) in [
            ("type T = A | B | C", DiagCode::E0237),
            ("type alias X = Integer", DiagCode::E0248),
            ("typealias X = Integer", DiagCode::E0248),
            ("const x = 1", DiagCode::E0201),
            ("record Empty\nend record", DiagCode::E0201),
        ] {
            assert_recovers(src, &[code]);
            if code != DiagCode::E0201 {
                let out = user(src);
                assert!(matches!(&out.module.decls[0].item, Item::Alias(_)));
            }
        }
        let src = "const maxRetries: Integer = 3\npublic const defaultPort: Integer = 8000 + 80\nconst greeting: String = \"hello, ${defaultPort}\"\nconst primaryColors: List[Color] = [Color.Red, Color.Green, Color.Blue]\nconst statusNames: Map[Integer, String] = Map.fromList([Pair(200, \"OK\"), Pair(404, \"Not Found\")])";
        let out = user(src);
        // 定数の式を読むのは F03、補間の本体を読むのは F04 である。
        assert!(codes(&out).iter().all(|c| *c == DiagCode::E0201));
        assert_eq!(out.module.decls.len(), 5);
        assert!(
            out.module
                .decls
                .iter()
                .all(|d| matches!(d.item, Item::Const(_)))
        );
        assert!(
            matches!(&out.module.decls[4].item, Item::Const(c) if matches!(c.value, Expr::Call(_)))
        );
    }

    #[test]
    fn documentation_is_attached_and_also_preserved_as_comments() {
        let src = "\u{feff}#!/usr/bin/env benitoite\r\n//! Module.\r\n//! More.\r\n\r\nimport Lib.Text\r\n/// First.\r\n/// Second.\r\n@test\r\npublic function f() -> Unit\r\n()\r\nend function\r\nrecord R\r\n  /// Field.\r\n  value: Integer\r\nend record\r\ndata D\r\n  /// Constructor.\r\n  C\r\nend data";
        let out = user(src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        assert_eq!(out.module.doc.as_ref().unwrap().text, " Module.\n More.");
        assert_eq!(
            out.module.decls[0].doc.as_ref().unwrap().text,
            " First.\n Second."
        );
        let doc = out.module.decls[0].doc.as_ref().unwrap();
        assert_eq!(doc.span.start, position(src, "/// First.").unwrap());
        assert_eq!(doc.span.end.0, position(src, "/// Second.").unwrap().0 + 11);
        assert!(
            matches!(&out.module.decls[1].item, Item::Record(r) if r.fields[0].doc.as_ref().unwrap().text == " Field.")
        );
        assert!(
            matches!(&out.module.decls[2].item, Item::Data(d) if d.variants[0].doc.as_ref().unwrap().text == " Constructor.")
        );
        assert_eq!(out.comments.len(), 6);
        let out = user("//! Only docs.");
        assert!(out.diagnostics.is_empty());
        assert!(out.module.decls.is_empty());
        assert_eq!(out.module.doc.unwrap().text, " Only docs.");
        // 字句解析が先頭の BOM を読み飛ばしても、宣言の説明は先頭の行に書ける。
        for prefix in ["", "\u{feff}"] {
            let src = format!("{prefix}/// First declaration.\n{FUNCTION}");
            let out = user(&src);
            assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
            assert_eq!(
                out.module.decls[0].doc.as_ref().unwrap().text,
                " First declaration."
            );
        }
    }

    #[test]
    fn misplaced_docs_and_foreign_forms_report_repairs_and_recover() {
        for (src, code, marker) in [
            (
                "function f() -> Unit\n/// inner\n()\nend function",
                DiagCode::E0228,
                "///",
            ),
            (
                "/// detached\n\nfunction f() -> Unit\n()\nend function",
                DiagCode::E0228,
                "///",
            ),
            (
                "/// detached\n// normal\nfunction f() -> Unit\n()\nend function",
                DiagCode::E0228,
                "///",
            ),
            ("import Lib.A\n//! misplaced", DiagCode::E0229, "//!"),
            ("\n//! misplaced", DiagCode::E0229, "//!"),
            ("const x: Integer = 0 /// inline", DiagCode::E0228, "///"),
            ("/** doc */", DiagCode::E0249, "/**"),
            ("{-| doc -}", DiagCode::E0249, "{-|"),
            ("(** doc *)", DiagCode::E0249, "(**"),
        ] {
            let full = format!("{src}\n{FUNCTION}");
            let out = user(&full);
            assert_eq!(codes(&out), [code], "{full}: {:?}", out.diagnostics);
            assert_eq!(
                out.diagnostics[0].primary.as_ref().unwrap().span.start,
                position(&full, marker).unwrap()
            );
            if matches!(code, DiagCode::E0228 | DiagCode::E0229) {
                let edit = &out.diagnostics[0].helps[0].edits[0];
                assert_eq!(edit.replacement, "//");
                assert_eq!(edit.span.end.0 - edit.span.start.0, 3);
            }
            assert!(
                matches!(out.module.decls.last().map(|d| &d.item), Some(Item::Fn(_))),
                "{full}: {:?}",
                out.module.decls
            );
        }
        for src in ["#[test]", "[<Test>]"] {
            assert_recovers(src, &[DiagCode::E0247]);
            let out = user(&format!("{src}\n{FUNCTION}"));
            assert_eq!(out.diagnostics[0].helps[0].edits[0].replacement, "@test");
        }
        let trailing = user("/// trailing");
        assert_eq!(codes(&trailing), [DiagCode::E0228]);
        let out = user(&format!("/// detached\n\n/// attached\n{FUNCTION}"));
        assert_eq!(codes(&out), [DiagCode::E0228]);
        assert_eq!(out.module.decls[0].doc.as_ref().unwrap().text, " attached");
    }

    #[test]
    fn stdlib_modules_without_f04_syntax_parse_as_prelude() {
        for (name, src) in [
            ("Integer", include_str!("../../prelude/stdlib/Integer.bnt")),
            ("Option", include_str!("../../prelude/stdlib/Option.bnt")),
            ("List", include_str!("../../prelude/stdlib/List.bnt")),
            ("Result", include_str!("../../prelude/stdlib/Result.bnt")),
            ("Pair", include_str!("../../prelude/stdlib/Pair.bnt")),
            ("Triple", include_str!("../../prelude/stdlib/Triple.bnt")),
            ("Boolean", include_str!("../../prelude/stdlib/Boolean.bnt")),
            (
                "Character",
                include_str!("../../prelude/stdlib/Character.bnt"),
            ),
            ("Byte", include_str!("../../prelude/stdlib/Byte.bnt")),
            ("Float", include_str!("../../prelude/stdlib/Float.bnt")),
            ("String", include_str!("../../prelude/stdlib/String.bnt")),
            (
                "Reference",
                include_str!("../../prelude/stdlib/Reference.bnt"),
            ),
            ("Lazy", include_str!("../../prelude/stdlib/Lazy.bnt")),
            (
                "RoundingMode",
                include_str!("../../prelude/stdlib/RoundingMode.bnt"),
            ),
            ("IOError", include_str!("../../prelude/stdlib/IOError.bnt")),
            (
                "IOErrorKind",
                include_str!("../../prelude/stdlib/IOErrorKind.bnt"),
            ),
        ] {
            let (out, lex) = parse_source(src, SourceKind::Prelude);
            assert!(lex.is_empty(), "{name}: {lex:?}");
            assert!(out.diagnostics.is_empty(), "{name}: {:?}", out.diagnostics);
            assert!(out.module.doc.is_some(), "{name}");
        }
    }
}
