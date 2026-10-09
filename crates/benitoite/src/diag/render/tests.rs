//! 引き継いだ診断描画の出力契約を、新しい診断の型で確かめる（設計書 02-10、実装プラン F16）。

// テストの失敗は assert で表し、準備データには必要な添字と算術を使う。
#![allow(
    clippy::arithmetic_side_effects,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::unwrap_used
)]
use crate::base::{BytePos, FileId, Source, SourceKind, SourceTable, Span};

use super::{TextOptions, Verb, render_check_text, render_json_line, render_one_text};
use crate::diag::codes::DiagCode;
use crate::diag::{CallTrace, Diagnostic, FrameName, Label, ReportKind, Severity, TraceFrame};

fn add_source(table: &mut SourceTable, bytes: &[u8]) -> FileId {
    table.add(Source::new(
        "count.bnt".to_owned(),
        SourceKind::User,
        bytes.to_vec(),
    ))
}

fn find_bytes(haystack: &[u8], needle: &[u8]) -> usize {
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
        .unwrap_or(0)
}

pub(super) fn span(file: FileId, start: usize, length: usize) -> Span {
    Span {
        file,
        start: BytePos(u32::try_from(start).unwrap_or(u32::MAX)),
        end: BytePos(u32::try_from(start.saturating_add(length)).unwrap_or(u32::MAX)),
    }
}

pub(super) fn check_diag(message: &str) -> Diagnostic {
    Diagnostic {
        kind: ReportKind::Check,
        severity: Severity::Error,
        code: Some(DiagCode::E0401),
        message: message.to_owned(),
        primary: None,
        secondary: Vec::new(),
        notes: Vec::new(),
        helps: Vec::new(),
        trace: None,
        task_origins: Vec::new(),
        waiting: Vec::new(),
        backtrace: None,
    }
}

fn type_diagnostic(file: FileId, source: &[u8]) -> Diagnostic {
    let primary_start = find_bytes(source, b"\"a\"");
    let declared_start = find_bytes(source, b"Int");
    let mut diag = check_diag("mismatched types");
    diag.primary = Some(Label {
        span: span(file, primary_start, 3),
        text: "expected `Int`, found `String`".to_owned(),
    });
    diag.secondary.push(Label {
        span: span(file, declared_start, 3),
        text: "declared here".to_owned(),
    });
    diag
}

fn line_column_offset(bytes: &[u8], line: usize, column: usize) -> usize {
    let line_start = bytes
        .split_inclusive(|byte| *byte == b'\n')
        .take(line.saturating_sub(1))
        .map(<[u8]>::len)
        .sum::<usize>();
    line_start.saturating_add(column.saturating_sub(1))
}

fn runtime_trace_diagnostic(file: FileId, bytes: &[u8]) -> Diagnostic {
    let primary_start = line_column_offset(bytes, 10, 11);
    let ratio_call = line_column_offset(bytes, 22, 33);
    let lambda_start = line_column_offset(bytes, 22, 25);
    let list_call = line_column_offset(bytes, 22, 12);
    Diagnostic {
        kind: ReportKind::Runtime,
        severity: Severity::Error,
        code: Some(DiagCode::R0101),
        message: "division by zero".to_owned(),
        primary: Some(Label {
            span: span(file, primary_start, 5),
            text: String::new(),
        }),
        secondary: Vec::new(),
        notes: vec![crate::diag::codes::text::TRACE_TAIL_NOTE.to_owned()],
        helps: Vec::new(),
        trace: Some(CallTrace {
            frames: vec![
                TraceFrame {
                    name: FrameName::Named("ratio".to_owned()),
                    call_site: Some(span(file, ratio_call, 0)),
                },
                TraceFrame {
                    name: FrameName::Lambda(span(file, lambda_start, 0)),
                    call_site: None,
                },
                TraceFrame {
                    name: FrameName::Named("List.map".to_owned()),
                    call_site: Some(span(file, list_call, 0)),
                },
                TraceFrame {
                    name: FrameName::Named("main".to_owned()),
                    call_site: None,
                },
            ],
            omitted: 0,
        }),
        task_origins: Vec::new(),
        waiting: Vec::new(),
        backtrace: None,
    }
}

#[test]
fn type_error_text_matches_the_rust_style_example() {
    let bytes = b"fn f(x: Int) -> Int {\n  x\n}\nfn g() -> Unit {\n  let n: Int = \"a\"\n}\n";
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, bytes);
    let diag = type_diagnostic(file, bytes);

    let actual = render_one_text(&diag, &sources, TextOptions { color: false });
    let expected = concat!(
        "error[E0401]: mismatched types\n",
        "  --> count.bnt:5:16\n",
        "   |\n",
        " 5 |   let n: Int = \"a\"\n",
        "   |                ^^^ expected `Int`, found `String`\n",
        "   |\n",
        "  ::: count.bnt:1:9\n",
        "   |\n",
        " 1 | fn f(x: Int) -> Int {\n",
        "   |         --- declared here\n",
    );
    assert_eq!(actual, expected);
}

#[test]
fn runtime_error_text_includes_the_call_trace_and_tail_note() {
    let mut lines = vec!["x".to_owned(); 22];
    lines[9] = "  let q = a / b".to_owned();
    lines[21] = "x".repeat(40);
    let bytes = lines.join("\n").into_bytes();
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, &bytes);
    let diag = runtime_trace_diagnostic(file, &bytes);

    let actual = render_one_text(&diag, &sources, TextOptions { color: false });
    let expected = concat!(
        "runtime error[R0101]: division by zero\n",
        "  --> count.bnt:10:11\n",
        "   |\n",
        "10 |   let q = a / b\n",
        "   |           ^^^^^\n",
        "   |\n",
        "   = note: call trace (innermost first):\n",
        "             ratio                    at count.bnt:22:33\n",
        "             <lambda count.bnt:22:25>\n",
        "             List.map                 at count.bnt:22:12\n",
        "             main\n",
        "   = note: functions left by tail calls are not shown\n",
    );
    assert_eq!(actual, expected);
}

#[test]
fn positionless_runtime_error_text_shows_only_its_note() {
    let sources = SourceTable::new();
    let diag = Diagnostic {
        kind: ReportKind::Runtime,
        severity: Severity::Error,
        code: Some(DiagCode::R0201),
        message: "failed to write to standard output".to_owned(),
        primary: None,
        secondary: Vec::new(),
        notes: vec!["broken pipe".to_owned()],
        helps: Vec::new(),
        trace: None,
        task_origins: Vec::new(),
        waiting: Vec::new(),
        backtrace: None,
    };

    assert_eq!(
        render_one_text(&diag, &sources, TextOptions { color: false }),
        concat!(
            "runtime error[R0201]: failed to write to standard output\n",
            "   = note: broken pipe\n",
        )
    );
}

#[test]
fn omitted_trace_frames_are_written_between_visible_groups() {
    let sources = SourceTable::new();
    let mut diag = check_diag("trace test");
    diag.trace = Some(CallTrace {
        frames: (0..25)
            .map(|index| TraceFrame {
                name: FrameName::Named(format!("frame{index}")),
                call_site: None,
            })
            .collect(),
        omitted: 5,
    });

    let output = render_one_text(&diag, &sources, TextOptions { color: false });
    let lines = output.lines().collect::<Vec<_>>();
    let omitted = lines
        .iter()
        .position(|line| line.ends_with("... 5 frames omitted ..."))
        .unwrap_or(0);
    assert!(
        lines
            .get(omitted.saturating_sub(1))
            .is_some_and(|line| line.ends_with("frame9"))
    );
    assert!(
        lines
            .get(omitted.saturating_add(1))
            .is_some_and(|line| line.ends_with("frame10"))
    );
}

#[test]
fn check_text_reports_empty_single_and_multiple_error_lists() {
    let sources = SourceTable::new();
    let opts = TextOptions { color: false };

    assert_eq!(
        render_check_text(&[], &sources, Verb::Run, "count.bnt", opts),
        ""
    );

    let one = vec![check_diag("one")];
    assert!(
        render_check_text(&one, &sources, Verb::Run, "count.bnt", opts)
            .ends_with("error: could not run count.bnt due to 1 previous error\n")
    );

    let three = vec![check_diag("one"), check_diag("two"), check_diag("three")];
    assert!(
        render_check_text(&three, &sources, Verb::Run, "count.bnt", opts)
            .ends_with("error: could not run count.bnt due to 3 previous errors\n")
    );
}

#[test]
fn check_text_shows_at_most_fifty_diagnostics_and_reports_the_counts() {
    let sources = SourceTable::new();
    let diagnostics = (0..53)
        .map(|index| check_diag(&format!("diagnostic {index}")))
        .collect::<Vec<_>>();

    let output = render_check_text(
        &diagnostics,
        &sources,
        Verb::Run,
        "count.bnt",
        TextOptions { color: false },
    );
    assert_eq!(output.matches("error[E0401]").count(), 50);
    assert!(output.contains("error: 3 more diagnostics not shown\n\n"));
    assert!(output.ends_with("error: could not run count.bnt due to 53 previous errors\n"));
}

#[test]
fn tab_expansion_keeps_the_marker_under_the_selected_character() {
    let bytes = b"\tlet x = y";
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, bytes);
    let start = find_bytes(bytes, b"y");
    let mut diag = check_diag("selected value");
    diag.primary = Some(Label {
        span: span(file, start, 1),
        text: String::new(),
    });

    let output = render_one_text(&diag, &sources, TextOptions { color: false });
    assert!(output.contains(" 1 |     let x = y\n"));
    assert!(output.contains("   |             ^\n"));
}

#[test]
fn multiline_and_empty_spans_get_visible_markers() {
    let bytes = b"abc\ndef";
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, bytes);
    let mut multiline = check_diag("multiline");
    multiline.primary = Some(Label {
        span: span(file, 1, 4),
        text: String::new(),
    });
    let output = render_one_text(&multiline, &sources, TextOptions { color: false });
    assert!(output.contains(" 1 | abc\n   |  ^^\n"));

    let mut empty = check_diag("empty");
    empty.primary = Some(Label {
        span: span(file, 1, 0),
        text: String::new(),
    });
    let output = render_one_text(&empty, &sources, TextOptions { color: false });
    assert!(output.contains("   |  ^\n"));
}

#[test]
fn same_line_secondary_markers_are_ordered_by_column() {
    let bytes = b"abcdef";
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, bytes);
    let mut diag = check_diag("multiple labels");
    diag.primary = Some(Label {
        span: span(file, 0, 1),
        text: "primary".to_owned(),
    });
    diag.secondary = vec![
        Label {
            span: span(file, 4, 1),
            text: "later".to_owned(),
        },
        Label {
            span: span(file, 2, 1),
            text: "earlier".to_owned(),
        },
    ];

    let output = render_one_text(&diag, &sources, TextOptions { color: false });
    let primary = output.find("^ primary").unwrap_or(usize::MAX);
    let earlier = output.find("- earlier").unwrap_or(usize::MAX);
    let later = output.find("- later").unwrap_or(usize::MAX);
    assert!(primary < earlier);
    assert!(earlier < later);
}

#[test]
fn invalid_utf8_bytes_are_rendered_as_single_replacement_characters() {
    let bytes = b"a\xFFb";
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, bytes);
    let mut diag = check_diag("invalid source");
    diag.primary = Some(Label {
        span: span(file, 2, 1),
        text: String::new(),
    });

    let output = render_one_text(&diag, &sources, TextOptions { color: false });
    assert!(output.contains(" 1 | a\u{FFFD}b\n"));
    assert!(output.contains("   |   ^\n"));
}

#[test]
fn json_line_has_stable_field_order_and_byte_offsets() {
    let bytes = b"fn f(x: Int) -> Int {\n  x\n}\nfn g() -> Unit {\n  let n: Int = \"a\"\n}\n";
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, bytes);
    let diag = type_diagnostic(file, bytes);
    let primary = find_bytes(bytes, b"\"a\"");

    let actual = render_json_line(&diag, &sources);
    let expected = format!(
        concat!(
            "{{\"kind\":\"check\",\"severity\":\"error\",\"code\":\"E0401\",",
            "\"message\":\"mismatched types\",\"primary\":{{\"file\":\"count.bnt\",",
            "\"start\":{{\"line\":5,\"column\":16,\"offset\":{}}},",
            "\"end\":{{\"line\":5,\"column\":19,\"offset\":{}}},",
            "\"label\":\"expected `Int`, found `String`\"}},\"secondary\":[",
            "{{\"file\":\"count.bnt\",\"start\":{{\"line\":1,\"column\":9,\"offset\":8}},",
            "\"end\":{{\"line\":1,\"column\":12,\"offset\":11}},",
            "\"label\":\"declared here\"}}],\"notes\":[],\"helps\":[]}}"
        ),
        primary,
        primary.saturating_add(3),
    );
    assert_eq!(actual, expected);
}

#[test]
fn runtime_json_contains_named_trace_frames_and_omitted_count() {
    let mut lines = vec!["x".to_owned(); 22];
    lines[9] = "  let q = a / b".to_owned();
    lines[21] = "x".repeat(40);
    let bytes = lines.join("\n").into_bytes();
    let mut sources = SourceTable::new();
    let file = add_source(&mut sources, &bytes);
    let diag = runtime_trace_diagnostic(file, &bytes);

    let output = render_json_line(&diag, &sources);
    assert!(output.contains("\"kind\":\"runtime\""));
    assert!(output.contains("\"function\":\"ratio\",\"location\":{\"file\":\"count.bnt\""));
    assert!(output.contains("\"function\":\"<lambda count.bnt:22:25>\",\"location\":null"));
    assert!(output.contains("\"traceOmitted\":0"));
}

#[test]
fn internal_reports_have_no_code_and_put_backtrace_last_in_json() {
    let sources = SourceTable::new();
    let diag = Diagnostic {
        kind: ReportKind::Internal,
        severity: Severity::Error,
        code: None,
        message: "compiler invariant failed".to_owned(),
        primary: None,
        secondary: Vec::new(),
        notes: Vec::new(),
        helps: Vec::new(),
        trace: None,
        task_origins: Vec::new(),
        waiting: Vec::new(),
        backtrace: Some("frame one\nframe two".to_owned()),
    };

    let text = render_one_text(&diag, &sources, TextOptions { color: false });
    assert!(text.starts_with("internal error: compiler invariant failed\n"));
    let json = render_json_line(&diag, &sources);
    assert!(json.contains("\"kind\":\"internal\""));
    assert!(json.contains("\"code\":null"));
    assert!(json.ends_with(",\"backtrace\":\"frame one\\nframe two\"}"));
}

#[test]
fn json_escapes_quotes_slashes_newlines_and_other_control_characters() {
    let sources = SourceTable::new();
    let mut diag = check_diag("quote \" slash \\ line\ncontrol \u{1B}");
    diag.notes.push("note\r\t\u{1}".to_owned());

    let output = render_json_line(&diag, &sources);
    assert_eq!(
        output,
        concat!(
            "{\"kind\":\"check\",\"severity\":\"error\",\"code\":\"E0401\",",
            "\"message\":\"quote \\\" slash \\\\ line\\ncontrol \\u001b\",",
            "\"primary\":null,\"secondary\":[],\"notes\":[\"note\\r\\t\\u0001\"],\"helps\":[]}"
        )
    );
    assert!(!output.contains('\n'));
}

#[test]
fn color_is_applied_only_when_requested() {
    let sources = SourceTable::new();
    let diag = check_diag("mismatched types");
    let colored = render_one_text(&diag, &sources, TextOptions { color: true });
    let plain = render_one_text(&diag, &sources, TextOptions { color: false });

    assert!(colored.starts_with("\x1b[1;31merror[E0401]\x1b[0m: mismatched types\n"));
    assert!(!plain.contains('\x1b'));
}
