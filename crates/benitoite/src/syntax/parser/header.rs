//! ファイルの先頭の部分を読む。ファイルの種類に依る制約は読み込みの段に任せる
//! （設計書 01-02「ファイルの先頭の部分」、02-03「構文の規則に伴う診断」）。

use std::collections::BTreeMap;

use super::{PResult, Parser, Recovery, is_decl_start, text};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, code_list};
use crate::syntax::ast::{HeaderBlock, HeaderField, HeaderItem, LanguageDecl, StrArg};
use crate::syntax::token::{TokenKind, TokenValue};
use crate::syntax::version::parse_version;

pub(super) fn header_ahead(p: &Parser) -> bool {
    (p.word(text::LANGUAGE) && p.peek_nth_kind(1) == TokenKind::StringLit)
        || ((p.word(text::DEPENDENCY) || p.word(text::PACKAGE))
            && p.peek_nth_kind(1) == TokenKind::UpperIdent)
}

pub(super) fn parse_header(p: &mut Parser) -> Vec<HeaderItem> {
    let mut items = Vec::new();
    let mut seen = BTreeMap::new();
    while (p.word(text::LANGUAGE) || p.word(text::DEPENDENCY) || p.word(text::PACKAGE))
        && !p.aborted
    {
        if let Some(item) = parse_one_recover(p) {
            let (key, span) = match &item {
                HeaderItem::Language(_) => (
                    text::LANGUAGE.to_owned(),
                    crate::syntax::header::keyword(&item).1,
                ),
                HeaderItem::Package(_) => (
                    text::PACKAGE.to_owned(),
                    crate::syntax::header::keyword(&item).1,
                ),
                HeaderItem::Dependency(block) => (
                    format!("{} {}", text::DEPENDENCY, block.name.text),
                    block.name.span,
                ),
            };
            if let Some(first) = seen.get(&key) {
                duplicate(p, &format!("`{key}`"), span, *first);
            } else {
                seen.insert(key, span);
            }
            items.push(item);
        }
        p.skip_newlines();
    }
    items
}

pub(super) fn report_late(p: &mut Parser, first: Option<Span>) {
    let mut builder = DiagBuilder::new(DiagCode::E0252)
        .arg("item", p.snippet(p.peek().span))
        .primary(p.peek().span);
    if let Some(first) = first {
        builder = builder.secondary(first, "first");
    }
    p.report(builder.build());
}

pub(super) fn parse_one_recover(p: &mut Parser) -> Option<HeaderItem> {
    let start = p.pos;
    let result = parse_one(p);
    if result.is_err() {
        p.recover(start, Recovery::Line);
    }
    if p.pos == start && !p.at(TokenKind::Eof) {
        p.advance();
    }
    if !p.at(TokenKind::Newline) && !p.at(TokenKind::Eof) && !p.at_line_start() {
        p.unexpected(text::NEWLINE_OR_END);
        p.recover(p.pos, Recovery::Line);
    }
    result.ok()
}

fn parse_one(p: &mut Parser) -> PResult<HeaderItem> {
    let start = p.pos;
    let language = p.word(text::LANGUAGE);
    let dependency = p.word(text::DEPENDENCY);
    let opened = p.bump().span;
    if language {
        let version = string(p, text::VERSION_STRING)?;
        if parse_version(&version.value).is_none() {
            p.report(
                DiagBuilder::new(DiagCode::E0905)
                    .arg("version", &version.value)
                    .primary(version.span)
                    .note("form")
                    .build(),
            );
        }
        return Ok(HeaderItem::Language(LanguageDecl {
            id: p.node_id(),
            span: p.span_from(start),
            version,
        }));
    }
    let construct = if dependency {
        text::DEPENDENCY
    } else {
        text::PACKAGE
    };
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    if dependency && name.text == text::BENITOITE {
        p.report(
            DiagBuilder::new(DiagCode::E0325)
                .primary(name.span)
                .note("dependency")
                .build(),
        );
    }
    p.expect(TokenKind::Newline)?;
    p.skip_newlines();
    let mut fields = Vec::new();
    let mut seen = BTreeMap::new();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.aborted {
        // 次の宣言まで飲み込まない。閉じ忘れの後もトップレベルの解析を続ける。
        if is_decl_start(p.peek_kind()) || next_header_starts(p) {
            break;
        }
        let from = p.pos;
        match field(p) {
            Ok(field) => {
                if let Some(first) = seen.get(&field.name.text) {
                    duplicate(
                        p,
                        &format!("`{}`", field.name.text),
                        field.name.span,
                        *first,
                    );
                } else {
                    seen.insert(field.name.text.clone(), field.name.span);
                }
                check_field(p, &field, construct, dependency);
                fields.push(field);
            }
            Err(_) => p.recover(from, Recovery::Line),
        }
        if p.pos == from {
            p.advance();
        }
        if !p.at(TokenKind::Newline) && !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) {
            p.unexpected(text::NEWLINE_OR_END);
            p.recover(p.pos, Recovery::Line);
        }
        p.skip_newlines();
    }
    close(p, opened, construct);
    if dependency && !seen.contains_key(text::PATH) {
        p.report(
            DiagBuilder::new(DiagCode::E0904)
                .arg("alias", &name.text)
                .primary(name.span)
                .help("path")
                .build(),
        );
    }
    let block = HeaderBlock {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        fields,
    };
    Ok(if dependency {
        HeaderItem::Dependency(block)
    } else {
        HeaderItem::Package(block)
    })
}

fn next_header_starts(p: &Parser) -> bool {
    if !header_ahead(p) {
        return false;
    }
    if !p.word(text::LANGUAGE) {
        return true;
    }
    // ブロック内の language は未知の欄として扱う。閉じ忘れの場合だけ次の項目へ回復する
    // （設計書 02-03「誤りからの回復」）。先読みでは解析器の状態を変えない。
    let mut line_start = false;
    let mut tokens = p.tokens.iter().skip(p.pos.saturating_add(2)).peekable();
    while let Some(token) = tokens.next() {
        if token.kind == TokenKind::KwEnd {
            return false;
        }
        if token.kind == TokenKind::Eof || is_decl_start(token.kind) {
            return true;
        }
        if line_start
            && matches!(&token.value, TokenValue::Ident(name) if name == text::DEPENDENCY || name == text::PACKAGE)
            && tokens
                .peek()
                .is_some_and(|next| next.kind == TokenKind::UpperIdent)
        {
            return true;
        }
        line_start = token.kind == TokenKind::Newline;
    }
    true
}

fn string(p: &mut Parser, expected: &str) -> PResult<StrArg> {
    if !p.at(TokenKind::StringLit) {
        return Err(p.unexpected(expected));
    }
    let token = p.bump();
    let value = if let TokenValue::Str(value) = token.value {
        value
    } else {
        String::new()
    };
    Ok(StrArg {
        span: token.span,
        value,
    })
}

fn field(p: &mut Parser) -> PResult<HeaderField> {
    let start = p.pos;
    let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
    let value = string(p, text::FIELD_STRING)?;
    Ok(HeaderField {
        span: p.span_from(start),
        name,
        value,
    })
}

fn check_field(p: &mut Parser, field: &HeaderField, block: &str, dependency: bool) {
    let fields = if dependency {
        text::DEPENDENCY_FIELDS
    } else {
        text::PACKAGE_FIELDS
    };
    let name = field.name.text.as_str();
    if dependency && text::UNAVAILABLE_FIELDS.contains(&name) {
        p.report(
            DiagBuilder::new(DiagCode::E0903)
                .arg("field", name)
                .primary(field.name.span)
                .note("local")
                .build(),
        );
    } else if !fields.contains(&name) {
        p.report(
            DiagBuilder::new(DiagCode::E0901)
                .arg("field", name)
                .arg("block", block)
                .arg("fields", code_list(fields.iter().copied()))
                .primary(field.name.span)
                .note("fields")
                .build(),
        );
    } else if dependency
        && name == text::HASH
        && !crate::syntax::header::valid_hash(&field.value.value)
    {
        p.report(
            DiagBuilder::new(DiagCode::E0906)
                .arg("hash", &field.value.value)
                .primary(field.value.span)
                .note("form")
                .build(),
        );
    } else if dependency
        && name == crate::syntax::header::EFFECTS
        && !crate::syntax::header::valid_effects(&field.value.value)
    {
        p.report(
            DiagBuilder::new(DiagCode::E0929)
                .primary(field.value.span)
                .build(),
        );
    }
}

fn duplicate(p: &mut Parser, what: &str, span: Span, first: Span) {
    p.report(
        DiagBuilder::new(DiagCode::E0902)
            .arg("what", what)
            .primary(span)
            .secondary(first, "first")
            .build(),
    );
}

fn close(p: &mut Parser, opened: Span, construct: &str) {
    if p.aborted {
        return;
    }
    let at = p.peek().span;
    if p.eat(TokenKind::KwEnd) {
        if p.word(construct) {
            p.bump();
        } else {
            let found = p.snippet(p.peek().span);
            let last = if !p.at(TokenKind::Eof) && !p.at(TokenKind::Newline) {
                p.bump().span
            } else {
                p.empty_span()
            };
            p.report(
                DiagBuilder::new(DiagCode::E0213)
                    .arg("found", found)
                    .arg("expected", construct)
                    .primary(at.to(last))
                    .secondary(opened, "opened")
                    .help_edits(
                        "replace",
                        vec![crate::diag::Edit {
                            span: last,
                            replacement: construct.to_owned(),
                        }],
                    )
                    .build(),
            );
        }
    } else {
        p.report(
            DiagBuilder::new(DiagCode::E0214)
                .arg("construct", construct)
                .primary(at)
                .secondary(opened, "opened")
                .build(),
        );
    }
}

#[cfg(test)]
// 先頭の部分の AST、診断の位置、回復を parse の境界で確かめる。読み込みの規則はここに重ねない。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::SourceKind;
    use crate::syntax::parser::test_support::{assert_recovers, codes, parse_source};

    #[test]
    fn header_preserves_order_names_and_values() {
        let hash = format!("sha256:{}", "0123456789abcdef".repeat(4));
        let source = format!(
            "//! module\nlanguage \"0.0.3\"\ndependency Textkit\nhash \"{hash}\"\npath \"../textkit\"\nend dependency\npackage Textkit\nlicense \"\"\nend package\n"
        );
        let (out, lex) = parse_source(&source, SourceKind::User);
        assert!(lex.is_empty());
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        assert!(out.module.doc.is_some());
        assert_eq!(out.module.header.len(), 3);
        let HeaderItem::Language(language) = &out.module.header[0] else {
            panic!()
        };
        assert_eq!(language.version.value, "0.0.3");
        let HeaderItem::Dependency(block) = &out.module.header[1] else {
            panic!()
        };
        assert_eq!(block.name.text, "Textkit");
        assert_eq!(
            block
                .fields
                .iter()
                .map(|f| (&*f.name.text, &*f.value.value))
                .collect::<Vec<_>>(),
            vec![("hash", &*hash), ("path", "../textkit")]
        );
        let HeaderItem::Package(block) = &out.module.header[2] else {
            panic!()
        };
        assert_eq!(block.fields[0].value.value, "");
        let (out, _) = parse_source("package Empty\nend package", SourceKind::User);
        assert!(codes(&out).is_empty());
        assert!(
            matches!(&out.module.header[0], HeaderItem::Package(block) if block.fields.is_empty())
        );
    }

    // spec: 01-02 ファイルの先頭の部分
    #[test]
    fn malformed_headers_report_and_recover() {
        for (source, expected) in [
            (
                "dependency A\nunknown \"x\"\npath \"a\"\nend dependency",
                vec![DiagCode::E0901],
            ),
            (
                "dependency A\npath \"a\"\npath \"b\"\nend dependency",
                vec![DiagCode::E0902],
            ),
            (
                "language \"0.0.3\"\nlanguage \"0.0.2\"",
                vec![DiagCode::E0902],
            ),
            (
                "package A\nend package\npackage B\nend package",
                vec![DiagCode::E0902],
            ),
            (
                "dependency A\npath \"a\"\nend dependency\ndependency A\npath \"b\"\nend dependency",
                vec![DiagCode::E0902],
            ),
            (
                "dependency A\nsource \"a\"\nversion \"1\"\ncommit \"x\"\nend dependency",
                vec![
                    DiagCode::E0903,
                    DiagCode::E0903,
                    DiagCode::E0903,
                    DiagCode::E0904,
                ],
            ),
            ("dependency A\nend dependency", vec![DiagCode::E0904]),
            ("language \"01.2.3\"", vec![DiagCode::E0905]),
            (
                "dependency A\npath \"a\"\nhash \"sha256:ABC\"\nend dependency",
                vec![DiagCode::E0906],
            ),
            (
                "dependency A\npath \"a\"\neffects \"File.Read,\"\nend dependency",
                vec![DiagCode::E0929],
            ),
            (
                "dependency Benitoite\npath \"a\"\nend dependency",
                vec![DiagCode::E0325],
            ),
            ("package A\nend dependency", vec![DiagCode::E0213]),
            ("package A", vec![DiagCode::E0214]),
            (
                "package A\nlanguage \"0.0.3\"\nend package",
                vec![DiagCode::E0901],
            ),
            (
                "dependency A\npath \"a\"\nlanguage \"0.0.3\"\nend dependency",
                vec![DiagCode::E0901],
            ),
            ("language 1", vec![DiagCode::E0201]),
            ("language \"${1}\"", vec![DiagCode::E0201]),
            (
                "dependency A\npath \"a\"\ndependency B\npath \"b\"\nend dependency",
                vec![DiagCode::E0214],
            ),
            (
                "dependency A\npath \"a\"\nlanguage \"0.0.3\"",
                vec![DiagCode::E0214],
            ),
        ] {
            assert_recovers(source, &expected);
        }
        for hash in [
            format!("SHA256:{}", "a".repeat(64)),
            format!("sha256:{}", "A".repeat(64)),
            format!("sha256:{}", "g".repeat(64)),
            format!("sha256:{}", "a".repeat(63)),
            format!("sha256:{}", "a".repeat(65)),
        ] {
            assert_recovers(
                &format!("dependency A\npath \"a\"\nhash \"{hash}\"\nend dependency"),
                &[DiagCode::E0906],
            );
        }
        let (out, lexical) = parse_source("package A\n", SourceKind::User);
        assert!(lexical.is_empty());
        assert_eq!(codes(&out), [DiagCode::E0214]);
    }

    // 関門: 閉じ忘れの後の項目を AST に残す契約を、parse の結果で確かめる。
    // 診断だけの検査では、次の項目を読み捨てる退行を捕まえられない。
    #[test]
    fn missing_header_end_preserves_the_next_item() {
        for (next, headers, declarations) in [
            ("dependency B\npath \"b\"\nend dependency", 2, 0),
            ("package B\nend package", 2, 0),
            ("language \"0.0.3\"", 2, 0),
            (
                "language \"0.0.3\"\nfunction after() -> Unit\n()\nend function",
                2,
                1,
            ),
            (
                "language \"0.0.3\"\ndependency B\npath \"b\"\nend dependency",
                3,
                0,
            ),
        ] {
            let source = format!("dependency A\npath \"a\"\n{next}");
            let (out, lex) = parse_source(&source, SourceKind::User);
            assert!(lex.is_empty());
            assert_eq!(codes(&out), [DiagCode::E0214], "{source}");
            assert_eq!(out.module.header.len(), headers);
            let item = &out.module.header[1];
            let actual = match item {
                HeaderItem::Dependency(block) => format!("dependency {}", block.name.text),
                HeaderItem::Package(block) => format!("package {}", block.name.text),
                HeaderItem::Language(decl) => format!("language \"{}\"", decl.version.value),
            };
            assert_eq!(actual, next.lines().next().unwrap());
            assert_eq!(out.module.decls.len(), declarations);
        }
    }

    #[test]
    fn unknown_header_fields_list_usable_fields() {
        for (source, note) in [
            (
                "dependency A\nunknown \"x\"\npath \"a\"\nend dependency",
                "the fields of `dependency` are `path`, `hash`, `effects`",
            ),
            (
                "package A\nlanguage \"0.0.3\"\nend package",
                "the fields of `package` are `license`",
            ),
        ] {
            let (out, _) = parse_source(source, SourceKind::User);
            assert_eq!(codes(&out), [DiagCode::E0901]);
            assert_eq!(out.diagnostics[0].notes, [note]);
        }
    }

    #[test]
    fn duplicate_header_items_point_at_the_keyword() {
        for (source, word) in [
            ("language \"0.0.3\"\nlanguage \"0.0.2\"", "language"),
            ("package A\nend package\npackage B\nend package", "package"),
        ] {
            let (out, _) = parse_source(source, SourceKind::User);
            assert_eq!(codes(&out), [DiagCode::E0902]);
            let span = out.diagnostics[0].primary.as_ref().unwrap().span;
            assert_eq!(&source[span.start.0 as usize..span.end.0 as usize], word);
        }
    }

    #[test]
    fn misplaced_headers_are_discarded_and_do_not_hide_the_next_declaration() {
        for first in [
            "import Benitoite.String",
            "function before() -> Unit\n()\nend function",
        ] {
            for item in [
                "language \"0.0.3\"",
                "dependency A\npath \"a\"\nend dependency",
                "package A\nend package",
            ] {
                let source = format!("{first}\n{item}\nfunction after() -> Unit\n()\nend function");
                let (out, _) = parse_source(&source, SourceKind::User);
                assert_eq!(codes(&out), vec![DiagCode::E0252]);
                assert!(out.module.header.is_empty());
                assert_eq!(
                    out.diagnostics[0].primary.as_ref().unwrap().span.start.0 as usize,
                    first.len() + 1
                );
                assert_eq!(out.diagnostics[0].secondary[0].span.start.0, 0);
                assert!(
                    matches!(&out.module.decls.last().unwrap().item, crate::syntax::ast::Item::Fn(f) if f.name.text == "after")
                );
            }
        }
    }
}
