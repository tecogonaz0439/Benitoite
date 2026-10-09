//! 字句解析の公開の入口で、値・診断・回復・位置を確かめる（設計書 07-03）。
// テストの失敗は panic で表す（00-02「`#[allow]` を書いてよい箇所」）
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use TokenKind as K;

const F: FileId = FileId(7);

fn lex_bytes(src: &[u8]) -> LexOutput {
    let out = lex(F, src);
    let len = u32::try_from(src.len()).unwrap();
    let check_span = |span: Span| {
        assert_eq!(span.file, F);
        assert!(
            span.start.0 <= span.end.0 && span.end.0 <= len,
            "{src:?}: {span:?}"
        );
    };
    let mut end = 0;
    for token in &out.tokens {
        check_span(token.span);
        assert!(end <= token.span.start.0, "{src:?}: {token:?}");
        end = token.span.end.0;
    }
    assert_eq!(out.tokens.last().unwrap(), &eof(len));
    for comment in &out.comments {
        check_span(comment.span);
    }
    for d in &out.diagnostics {
        if let Some(primary) = &d.primary {
            check_span(primary.span);
        }
        for label in &d.secondary {
            check_span(label.span);
        }
        for help in &d.helps {
            for edit in &help.edits {
                check_span(edit.span);
            }
        }
    }
    out
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
        ("3items", "3items", E0115, "suffix"),
        ("12abm", "12abm", E0115, "suffix"),
        ("12abcM", "12abcM", E0115, "suffix"),
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
            .help("multi_line")
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
                    .help_edits(
                        "use_string",
                        vec![Edit {
                            span: sp(0, 4),
                            replacement: String::from("\"ab\""),
                        }],
                    )
                    .build(),
            ],
        ),
        // 結合文字を含む見た目の 1 文字は、スカラー値が二つある
        (
            "'e\u{301}'",
            vec![
                DiagBuilder::new(DiagCode::E0113)
                    .primary(sp(0, 5))
                    .help_edits(
                        "use_string",
                        vec![Edit {
                            span: sp(0, 5),
                            replacement: String::from("\"e\u{301}\""),
                        }],
                    )
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
        kind: CommentKind::Plain,
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
            kind: CommentKind::Plain,
            text: String::new(),
        }]
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

#[test]
fn first_release_keywords_and_identifiers() {
    let cases = [
        ("and", K::KwAnd),
        ("bind", K::KwBind),
        ("case", K::KwCase),
        ("const", K::KwConst),
        ("data", K::KwData),
        ("div", K::KwDiv),
        ("do", K::KwDo),
        ("effect", K::KwEffect),
        ("else", K::KwElse),
        ("end", K::KwEnd),
        ("false", K::KwFalse),
        ("function", K::KwFunction),
        ("handle", K::KwHandle),
        ("if", K::KwIf),
        ("implement", K::KwImplement),
        ("import", K::KwImport),
        ("lambda", K::KwLambda),
        ("lazy", K::KwLazy),
        ("match", K::KwMatch),
        ("mod", K::KwMod),
        ("not", K::KwNot),
        ("or", K::KwOr),
        ("public", K::KwPublic),
        ("record", K::KwRecord),
        ("resume", K::KwResume),
        ("return", K::KwReturn),
        ("shadow", K::KwShadow),
        ("then", K::KwThen),
        ("trait", K::KwTrait),
        ("true", K::KwTrue),
        ("try", K::KwTry),
        ("type", K::KwType),
        ("uses", K::KwUses),
        ("with", K::KwWith),
    ];
    for (word, kind) in cases {
        let src = format!("{word}\n");
        assert_clean_kinds(&src, &[kind, K::LineBreak, K::Eof]);
        assert_clean_kinds(&format!("{word}x"), &[K::LowerIdent, K::Eof]);
    }
    for word in [
        "as",
        "equality",
        "key",
        "ordered",
        "let",
        "of",
        "when",
        "fn",
        "switch",
        "default",
        "break",
        "alias",
        "typealias",
        "from",
        "for",
        "while",
        "loop",
        "continue",
        "class",
        "where",
    ] {
        assert_clean_kinds(word, &[K::LowerIdent, K::Eof]);
    }
}

#[test]
fn symbols_and_number_boundaries() {
    let cases: &[(&str, &[K])] = &[
        ("a<-1", &[K::LowerIdent, K::LeftArrow, K::IntLit, K::Eof]),
        ("a<>b", &[K::LowerIdent, K::NotEq, K::LowerIdent, K::Eof]),
        ("x..y", &[K::LowerIdent, K::DotDot, K::LowerIdent, K::Eof]),
        ("1..5", &[K::IntLit, K::DotDot, K::IntLit, K::Eof]),
        ("a|>b", &[K::LowerIdent, K::PipeGt, K::LowerIdent, K::Eof]),
        (
            "T: A & B",
            &[
                K::UpperIdent,
                K::Colon,
                K::UpperIdent,
                K::Amp,
                K::UpperIdent,
                K::Eof,
            ],
        ),
        ("@test", &[K::At, K::LowerIdent, K::Eof]),
        ("...xs", &[K::DotDot, K::Dot, K::LowerIdent, K::Eof]),
        ("1.foo", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
        ("1.max", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
        ("1.m_", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
        ("0x1e+2", &[K::IntLit, K::Plus, K::IntLit, K::Eof]),
        ("1e5-2", &[K::FloatLit, K::Minus, K::IntLit, K::Eof]),
    ];
    for (src, expected) in cases {
        assert_clean_kinds(src, expected);
    }
    for symbol in [
        "==", "!=", "&&", "||", "!", "%", "?", "=>", ";", "{", "}", "#", "|", "~", "^", "`", "$",
        "\\",
    ] {
        let src = format!("a {symbol} b");
        let out = lex_str(&src);
        assert_eq!(out.diagnostics, [], "{src}");
        assert_eq!(
            kinds(&out),
            [K::LowerIdent, K::BadSymbol, K::LowerIdent, K::Eof]
        );
        assert_eq!(out.tokens[1].value, TokenValue::Symbol(symbol.into()));
        assert_eq!(out.tokens[1].span, sp(2, 2 + len32(symbol)));
    }
}

#[test]
fn decimal_literals_and_errors() {
    for (src, value) in [
        ("12m", "12"),
        ("1.25m", "1.25"),
        ("1_000.50m", "1000.50"),
        ("0.5m", "0.5"),
    ] {
        let out = lex_str(src);
        assert_eq!(out.diagnostics, []);
        assert_eq!(
            out.tokens,
            [
                Token {
                    kind: K::DecimalLit,
                    span: sp(0, len32(src)),
                    value: TokenValue::Decimal(value.into())
                },
                eof(len32(src))
            ]
        );
    }
    for (src, key) in [
        ("0x1Fm", "base"),
        ("0o7M", "base"),
        ("1e3m", "exponent"),
        ("1.5M", "suffix_case"),
        ("01.5m", "leading_zero"),
        ("1__0m", "underscore"),
        ("1_.5m", "underscore"),
        ("1.5m_", "underscore"),
        ("1.m", "missing_digits"),
        ("1.5mm", "suffix"),
        ("2mod", "suffix"),
        ("1max", "suffix"),
        ("01__0e3m", "exponent"),
        ("01__0m", "leading_zero"),
    ] {
        let out = lex_str(src);
        assert_eq!(kinds(&out), [K::Error, K::Eof], "{src}");
        assert_eq!(out.diagnostics.len(), 1, "{src}");
        let d = &out.diagnostics[0];
        assert_eq!(d.code, Some(DiagCode::E0124));
        assert_eq!(d.primary.as_ref().unwrap().span, sp(0, len32(src)));
        let expected = DiagCode::E0124
            .info()
            .extras
            .iter()
            .find(|(k, _)| *k == key)
            .unwrap()
            .1;
        assert_eq!(d.primary.as_ref().unwrap().text, expected);
        if key == "suffix_case" {
            assert_eq!(
                d.helps[0].edits,
                [Edit {
                    span: sp(len32(src) - 1, len32(src)),
                    replacement: "m".into()
                }]
            );
        }
    }
}

#[test]
fn interpolation_values_and_spans() {
    let src = r#""a${x}b${y + 1}c""#;
    let out = lex_str(src);
    assert_eq!(out.diagnostics, []);
    assert_eq!(
        kinds(&out),
        [
            K::StrStart,
            K::LowerIdent,
            K::StrMid,
            K::LowerIdent,
            K::Plus,
            K::IntLit,
            K::StrEnd,
            K::Eof
        ]
    );
    for (index, value, start, end) in [(0, "a", 0, 4), (2, "b", 5, 9), (6, "c", 14, 17)] {
        assert_eq!(out.tokens[index].value, TokenValue::Str(value.into()));
        assert_eq!(out.tokens[index].span, sp(start, end));
    }
    let out = lex_str(r#""a${f("b${x}c")}d""#);
    assert_eq!(out.diagnostics, []);
    assert_eq!(
        kinds(&out),
        [
            K::StrStart,
            K::LowerIdent,
            K::LParen,
            K::StrStart,
            K::LowerIdent,
            K::StrEnd,
            K::RParen,
            K::StrEnd,
            K::Eof
        ]
    );
    assert_eq!(out.tokens[7].value, TokenValue::Str("d".into()));
    let out = lex_str(r#""${f('}', "}")}""#);
    assert_eq!(out.diagnostics, []);
    assert_eq!(
        kinds(&out),
        [
            K::StrStart,
            K::LowerIdent,
            K::LParen,
            K::CharLit,
            K::Comma,
            K::StringLit,
            K::RParen,
            K::StrEnd,
            K::Eof
        ]
    );
}

#[test]
fn interpolation_errors_discard_literal_and_recover() {
    for (src, code, start, end) in [
        (r#""${}""#, DiagCode::E0118, 1, 4),
        (r#""${   }""#, DiagCode::E0118, 1, 7),
        (r#""${x // c}""#, DiagCode::E0120, 5, 7),
        (r#""${"#, DiagCode::E0119, 1, 3),
        (r#""a${x}b\q""#, DiagCode::E0110, 7, 9),
    ] {
        let out = lex_str(src);
        assert_eq!(kinds(&out), [K::Error, K::Eof], "{src}");
        assert_eq!(out.diagnostics.len(), 1, "{src}");
        assert_eq!(out.diagnostics[0].code, Some(code));
        assert_eq!(
            out.diagnostics[0].primary.as_ref().unwrap().span,
            sp(start, end)
        );
        assert_eq!(out.tokens[0].span, sp(0, len32(src)));
        assert_eq!(out.comments, []);
    }
    for src in ["\"a${x\nnext", "\"a${x\"\nnext", "\"${\r\nnext"] {
        let out = lex_str(src);
        assert!(
            out.diagnostics
                .iter()
                .any(|d| d.code == Some(DiagCode::E0119)),
            "{out:?}"
        );
        assert_eq!(kinds(&out), [K::Error, K::LineBreak, K::LowerIdent, K::Eof]);
        assert_eq!(out.tokens[2].value, TokenValue::Ident("next".into()));
    }
    // 入れ子の複数行リテラルの開きでも、補間の式を物理的な改行の先へ進めない。
    for src in ["\"${\"\"\"\nnext", "\"${r\"\"\"\nnext"] {
        let out = lex_str(src);
        assert_eq!(kinds(&out), [K::Error, K::LineBreak, K::LowerIdent, K::Eof]);
        assert!(
            out.diagnostics
                .iter()
                .any(|d| d.code == Some(DiagCode::E0119))
        );
    }
    // 式の中の数値の誤りと入れ子の文字列の誤りは、それぞれの字句だけに帰属する。
    for src in [r#""${007}""#, r#""${"\q"}""#] {
        let out = lex_str(src);
        assert_eq!(
            kinds(&out),
            [K::StrStart, K::Error, K::StrEnd, K::Eof],
            "{src}"
        );
    }
    let out = lex_str(r#""\$""#);
    assert_eq!(out.diagnostics, []);
    assert_eq!(out.tokens[0].value, TokenValue::Str("$".into()));
}

#[test]
fn multiline_and_raw_values() {
    let cases = [
        (
            "\"\"\"\n    <html>\n      <p>Hello</p>\n    </html>\n    \"\"\"",
            "<html>\n  <p>Hello</p>\n</html>\n",
        ),
        ("\"\"\"\r\n  a\r\n  b\r\n  \"\"\"", "a\nb\n"),
        ("\"\"\"\n  a\\\n  b\n  \"\"\"", "ab\n"),
        ("\"\"\"\n  \\\"\"\"\n  \"\"\"", "\"\"\"\n"),
        ("\"\"\"\n  \" and \"\"\n  \"\"\"", "\" and \"\"\n"),
        ("\"\"\"\n  a\n \t \n  b\n  \"\"\"", "a\n\nb\n"),
        ("\"\"\"\n\"\"\"", ""),
        (r#"r"\d+""#, r"\d+"),
        (r#"r"${x}""#, "${x}"),
        ("r\"\"\"\n\t\\d+\\\n\t${x}\n\t\"\"\"", "\\d+\\\n${x}\n"),
    ];
    for (src, value) in cases {
        let out = lex_str(src);
        assert_eq!(out.diagnostics, [], "{src:?}");
        assert_eq!(
            out.tokens,
            [
                Token {
                    kind: K::StringLit,
                    span: sp(0, len32(src)),
                    value: TokenValue::Str(value.into())
                },
                eof(len32(src))
            ]
        );
    }
    let page = "\"\"\"\n    <html>\n      <p>Hello, ${name}</p>\n    </html>\n    \"\"\"";
    let out = lex_str(page);
    assert_eq!(out.diagnostics, []);
    assert_eq!(kinds(&out), [K::StrStart, K::LowerIdent, K::StrEnd, K::Eof]);
    assert_eq!(
        out.tokens[0].value,
        TokenValue::Str("<html>\n  <p>Hello, ".into())
    );
    assert_eq!(out.tokens[1].value, TokenValue::Ident("name".into()));
    assert_eq!(
        out.tokens[2].value,
        TokenValue::Str("</p>\n</html>\n".into())
    );
    assert_clean_kinds(r#"r "a""#, &[K::LowerIdent, K::StringLit, K::Eof]);
    let out = lex_str("\"\"\"\n  a${f(\"b${x}c\")}d\n  \"\"\")");
    assert_eq!(out.diagnostics, []);
    assert_eq!(out.tokens[0].value, TokenValue::Str("a".into()));
    assert_eq!(out.tokens[7].value, TokenValue::Str("d\n".into()));
    assert_eq!(out.tokens[8].kind, K::RParen);
    // 補間の中のエスケープした引用符は外側の閉じにしない。
    let out = lex_str("\"\"\"\n  ${\"\\\"\\\"\\\"\"}\n  end\n  \"\"\"");
    assert_eq!(out.diagnostics, []);
}

#[test]
fn multiline_errors_keep_original_positions() {
    let cases = [
        ("\"\"\"text\n  ok\n  \"\"\"", DiagCode::E0121, 3, 7),
        ("\"\"\"\n x\n  \"\"\"", DiagCode::E0122, 4, 6),
        ("\"\"\"\n  x\n\t\"\"\"", DiagCode::E0122, 4, 5),
        ("\"\"\"\n  x", DiagCode::E0123, 0, 3),
        ("r\"\"\"\n  x", DiagCode::E0123, 0, 4),
        ("\"\"\"\n  a\\q\n  \"\"\"", DiagCode::E0110, 7, 9),
    ];
    for (src, code, start, end) in cases {
        let out = lex_str(src);
        assert_eq!(kinds(&out), [K::Error, K::Eof], "{out:?}");
        assert_eq!(out.diagnostics.len(), 1, "{out:?}");
        let d = &out.diagnostics[0];
        assert_eq!(d.code, Some(code));
        assert_eq!(d.primary.as_ref().unwrap().span, sp(start, end));
        assert_eq!(out.tokens[0].span, sp(0, len32(src)));
        if code == DiagCode::E0121 {
            assert_eq!(
                d.helps[0].edits,
                [Edit {
                    span: sp(3, 3),
                    replacement: "\n".into()
                }]
            );
        }
        if code == DiagCode::E0122 {
            let close = len32(src) - 3;
            assert_eq!(d.secondary[0].span, sp(close, close + 3));
        }
    }
    for src in ["r\"\u{202E}\"", "r\"\u{1}\"", "r\"\nnext"] {
        let out = lex_str(src);
        assert_eq!(out.tokens[0].kind, K::Error);
        assert_eq!(out.diagnostics.len(), 1);
    }
}

#[test]
fn char_to_string_edits_preserve_text() {
    for (src, replacement) in [
        ("'ab'", "\"ab\""),
        (r#"'a\'b"'"#, r#""a'b\"""#),
        ("'${x}'", r#""\${x}""#),
    ] {
        let out = lex_str(src);
        assert_eq!(out.diagnostics[0].code, Some(DiagCode::E0113));
        let edits = &out.diagnostics[0].helps[0].edits;
        assert_eq!(
            edits,
            &[Edit {
                span: sp(0, len32(src)),
                replacement: replacement.into()
            }]
        );
        assert_eq!(lex_str(replacement).diagnostics, []);
    }
}

#[test]
fn doc_comments_and_shebang() {
    let src = "// a\n/// b\r\n//! c\n//// d";
    let out = lex_str(src);
    assert_eq!(out.diagnostics, []);
    assert_eq!(
        out.comments
            .iter()
            .map(|c| (c.kind, c.text.as_str()))
            .collect::<Vec<_>>(),
        [
            (CommentKind::Plain, " a"),
            (CommentKind::Doc, " b"),
            (CommentKind::ModuleDoc, " c"),
            (CommentKind::Plain, "// d")
        ]
    );
    for prefix in ["", "\u{FEFF}"] {
        let src = format!("{prefix}#!/usr/bin/env benitoite\nfunction");
        let out = lex_str(&src);
        assert_eq!(out.diagnostics, []);
        assert_eq!(out.comments, []);
        assert_eq!(kinds(&out), [K::LineBreak, K::KwFunction, K::Eof]);
        assert_eq!(out.tokens[1].span.end.0, len32(&src));
    }
    assert_clean_kinds("\n#!", &[K::LineBreak, K::BadSymbol, K::BadSymbol, K::Eof]);
    for (src, code) in [
        (b"#!\xFF\n".as_slice(), DiagCode::E0102),
        ("#!\u{FEFF}\n".as_bytes(), DiagCode::E0104),
        ("#!\u{202E}\n".as_bytes(), DiagCode::E0104),
    ] {
        let out = lex_bytes(src);
        assert_eq!(out.diagnostics[0].code, Some(code));
        assert_eq!(kinds(&out), [K::LineBreak, K::Eof]);
    }
}

#[test]
fn deep_interpolation_uses_no_rust_recursion() {
    let depth = 10_000;
    let src = format!("{}x{}", "\"${".repeat(depth), "}\"".repeat(depth));
    let out = lex_str(&src);
    assert_eq!(out.diagnostics, []);
    assert_eq!(out.tokens.len(), depth * 2 + 2);
    assert_eq!(out.tokens[depth].value, TokenValue::Ident("x".into()));
    let out = lex_str(&format!("{}\nnext", "\"${".repeat(depth)));
    assert_eq!(kinds(&out), [K::Error, K::LineBreak, K::LowerIdent, K::Eof]);
    assert_eq!(out.diagnostics.len(), depth);
}
