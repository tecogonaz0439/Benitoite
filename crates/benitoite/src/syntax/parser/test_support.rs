//! 構文解析のテストの準備（設計書 07-03「テストの設計の原則」の持ち主の境界）。
use super::{ParseOutput, parse};
use crate::base::{BytePos, FileId, IdGen, SourceKind};
use crate::diag::{DiagCode, Diagnostic};
use crate::syntax::{lexer::lex, newline::resolve_newlines};
/// 本物の字句解析・改行判定・構文解析をつなぎ、両段の診断を別に返す。
pub(crate) fn parse_source(src: &str, kind: SourceKind) -> (ParseOutput, Vec<Diagnostic>) {
    let lexed = lex(FileId(0), src.as_bytes());
    let tokens = resolve_newlines(lexed.tokens);
    (
        parse(
            FileId(0),
            kind,
            src.as_bytes(),
            tokens,
            lexed.comments,
            &mut IdGen::new(),
        ),
        lexed.diagnostics,
    )
}
/// 構文解析の診断のコードを順に返す。
pub(crate) fn codes(output: &ParseOutput) -> Vec<DiagCode> {
    output.diagnostics.iter().filter_map(|d| d.code).collect()
}
/// ソースの中の最初の文字列のバイトの位置。
pub(crate) fn position(src: &str, needle: &str) -> Option<BytePos> {
    src.find(needle)
        .and_then(|n| u32::try_from(n).ok())
        .map(BytePos)
}

/// 宣言か完全な関数に続けた宣言が、誤りからの回復の後も AST に残ることを確かめる。
/// 仮の本体のテストは各フックのファイルに置き、中身を書く作業がそこで期待する診断を改める。
pub(crate) fn assert_recovers(src: &str, expected: &[DiagCode]) {
    let src = format!("{src}\nfunction after() -> Unit\n()\nend function");
    let (output, lexical) = parse_source(&src, SourceKind::User);
    assert!(lexical.is_empty(), "{src}: {lexical:?}");
    assert_eq!(codes(&output), expected, "{src}: {:?}", output.diagnostics);
    assert!(matches!(output.module.decls.last().map(|d| &d.item),
        Some(crate::syntax::ast::Item::Fn(f)) if f.name.text == "after"));
}
