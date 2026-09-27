//! 診断を文章と JSON Lines の形へ書き出す（設計書 02-10）。

use crate::base::{BytePos, Source, SourceTable, Span};

use super::codes;
use super::{CallTrace, Diagnostic, FrameName, Label, ReportKind, Severity, TraceFrame};

const RED_BOLD: &str = "\x1b[1;31m";
const BLUE_BOLD: &str = "\x1b[1;34m";
const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";

/// 文章の形式の選択肢。
#[derive(Clone, Copy, Debug)]
pub struct TextOptions {
    /// 色を付けるか。CLI が、標準エラー出力が端末で `NO_COLOR` がないときに true にする
    pub color: bool,
}

/// 検査の誤りの一覧を、文章の形式にする。段の順・位置の順に並べ替えずに、渡された順に書く
/// （並べるのは呼び出し側。10-09 の `check`）。50 件を超えた分は書かずに件数を示し、
/// 最後に誤りの件数の行を書く。`verb` は `"run"` か `"check"`、`file` はスクリプトの表示名。
pub fn render_check_text(
    diags: &[Diagnostic],
    sources: &SourceTable,
    verb: &str,
    file: &str,
    opts: TextOptions,
) -> String {
    if diags.is_empty() {
        return String::new();
    }

    let mut output = String::new();
    let shown = diags.len().min(50);
    for diag in diags.iter().take(shown) {
        output.push_str(&render_one_text(diag, sources, opts));
        output.push('\n');
    }

    if diags.len() > 50 {
        let omitted = diags.len().saturating_sub(50).to_string();
        let message = codes::fill_template(codes::text::TOO_MANY, &[("count", omitted)]);
        append_summary_line(&mut output, &message, opts);
        output.push('\n');
    }

    let message = if diags.len() == 1 {
        codes::fill_template(
            codes::text::SUMMARY_ONE,
            &[("verb", verb.to_owned()), ("file", file.to_owned())],
        )
    } else {
        codes::fill_template(
            codes::text::SUMMARY_MANY,
            &[
                ("verb", verb.to_owned()),
                ("file", file.to_owned()),
                ("count", diags.len().to_string()),
            ],
        )
    };
    append_summary_line(&mut output, &message, opts);
    output
}

/// 一件の診断・報告を文章の形式にする（末尾に空行を含めない改行で終える）。
/// 実行時エラー、資源の不足、処理系の不具合、処理系の制限、コマンドライン引数の誤りに使う。
pub fn render_one_text(diag: &Diagnostic, sources: &SourceTable, opts: TextOptions) -> String {
    let primary = diag
        .primary
        .as_ref()
        .and_then(|label| prepare_label(label, sources));
    let mut secondary = if primary.is_some() {
        diag.secondary
            .iter()
            .filter_map(|label| prepare_label(label, sources))
            .collect::<Vec<_>>()
    } else {
        Vec::new()
    };

    let gutter_width = primary
        .iter()
        .chain(secondary.iter())
        .map(|label| label.line.to_string().len())
        .max()
        .unwrap_or(2)
        .max(2);

    let mut output = String::new();
    append_header(&mut output, diag, opts);
    output.push('\n');

    if let Some(primary) = primary.as_ref() {
        append_primary_excerpt(&mut output, primary, gutter_width, opts);
    }

    let same_line_end = primary.as_ref().map(|main| (main.source, main.line));
    let mut same_line = Vec::new();
    let mut other_lines = Vec::new();
    for label in secondary.drain(..) {
        match same_line_end {
            Some((source, line)) if std::ptr::eq(source, label.source) && line == label.line => {
                same_line.push(label);
            }
            _ => other_lines.push(label),
        }
    }
    same_line.sort_by_key(|label| label.span.start.0);

    for label in &same_line {
        append_marker_line(&mut output, label, gutter_width, false, opts);
    }
    for label in &other_lines {
        append_secondary_excerpt(&mut output, label, gutter_width, opts);
    }

    let has_trailing = diag.trace.is_some()
        || !diag.notes.is_empty()
        || !diag.helps.is_empty()
        || diag.backtrace.is_some();
    if has_trailing && (primary.is_some() || !other_lines.is_empty()) {
        append_vertical_line(&mut output, gutter_width, opts);
    }

    if let Some(trace) = diag.trace.as_ref() {
        append_trace(&mut output, trace, sources, gutter_width, opts);
    }
    for note in &diag.notes {
        append_tagged_line(&mut output, "note", note, gutter_width, opts);
    }
    for help in &diag.helps {
        append_tagged_line(&mut output, "help", help, gutter_width, opts);
    }
    if let Some(backtrace) = diag.backtrace.as_deref() {
        append_backtrace(&mut output, backtrace, gutter_width, opts);
    }

    output
}

/// 一件の診断・報告を、JSON のオブジェクト一つの一行にする（末尾に改行を付けない）。
pub fn render_json_line(diag: &Diagnostic, sources: &SourceTable) -> String {
    let mut output = String::new();
    output.push_str("{\"kind\":");
    push_json_string(&mut output, kind_name(diag.kind));
    output.push_str(",\"severity\":");
    push_json_string(
        &mut output,
        match diag.severity {
            Severity::Error => "error",
            Severity::Warning => "warning",
        },
    );
    output.push_str(",\"code\":");
    if diag.kind == ReportKind::Internal {
        output.push_str("null");
    } else if let Some(code) = diag.code {
        push_json_string(&mut output, code.info().id);
    } else {
        output.push_str("null");
    }
    output.push_str(",\"message\":");
    push_json_string(&mut output, &diag.message);
    output.push_str(",\"primary\":");
    match diag.primary.as_ref() {
        Some(label) => append_json_label(&mut output, label, sources),
        None => output.push_str("null"),
    }
    output.push_str(",\"secondary\":[");
    for (index, label) in diag.secondary.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        append_json_label(&mut output, label, sources);
    }
    output.push_str("],\"notes\":");
    append_json_strings(&mut output, &diag.notes);
    output.push_str(",\"helps\":");
    append_json_strings(&mut output, &diag.helps);

    if let Some(trace) = diag.trace.as_ref() {
        output.push_str(",\"trace\":[");
        for (index, frame) in trace.frames.iter().enumerate() {
            if index > 0 {
                output.push(',');
            }
            output.push_str("{\"function\":");
            push_json_string(&mut output, &trace_frame_name(frame, sources));
            output.push_str(",\"location\":");
            match frame.call_site {
                Some(span) => append_json_span(&mut output, span, "", sources),
                None => output.push_str("null"),
            }
            output.push('}');
        }
        output.push_str("],\"traceOmitted\":");
        output.push_str(&trace.omitted.to_string());
    }

    if let Some(backtrace) = diag.backtrace.as_deref() {
        output.push_str(",\"backtrace\":");
        push_json_string(&mut output, backtrace);
    }
    output.push('}');
    output
}

struct PreparedLabel<'a> {
    span: Span,
    text: &'a str,
    source: &'a Source,
    line: u32,
    column: u32,
    line_text: &'a [u8],
    indent: usize,
    marker_width: usize,
}

#[derive(Clone, Copy)]
struct SourceLocation<'a> {
    file: &'a str,
    line: u32,
    column: u32,
}

fn prepare_label<'a>(label: &'a Label, sources: &'a SourceTable) -> Option<PreparedLabel<'a>> {
    let source = sources.get(label.span.file)?;
    let start_location = source.line_col(label.span.start);
    let line_text = source.line_text(start_location.line)?;
    let source_bytes = source.text();
    let start_offset = byte_offset(source_bytes, label.span.start);
    let line_start = line_start_offset(source_bytes, start_offset);
    let start_in_line = start_offset.saturating_sub(line_start).min(line_text.len());
    let end_offset = byte_offset(source_bytes, label.span.end);
    let end_location = source.line_col(label.span.end);

    let marker_end = if label.span.end < label.span.start {
        start_in_line
    } else if end_location.line == start_location.line {
        end_offset
            .saturating_sub(line_start)
            .min(line_text.len())
            .max(start_in_line)
    } else {
        line_text.len()
    };
    let marker_bytes = line_text.get(start_in_line..marker_end).unwrap_or_default();

    Some(PreparedLabel {
        span: label.span,
        text: &label.text,
        source,
        line: start_location.line,
        column: start_location.column,
        line_text,
        indent: display_width(line_text.get(..start_in_line).unwrap_or_default()),
        marker_width: display_width(marker_bytes).max(1),
    })
}

fn source_location<'a>(span: Span, sources: &'a SourceTable) -> Option<SourceLocation<'a>> {
    let source = sources.get(span.file)?;
    let position = source.line_col(span.start);
    Some(SourceLocation {
        file: source.name(),
        line: position.line,
        column: position.column,
    })
}

fn byte_offset(source: &[u8], position: BytePos) -> usize {
    usize::try_from(position.0)
        .unwrap_or(usize::MAX)
        .min(source.len())
}

fn line_start_offset(source: &[u8], offset: usize) -> usize {
    source
        .get(..offset)
        .unwrap_or_default()
        .iter()
        .rposition(|byte| *byte == b'\n')
        .map_or(0, |newline| newline.saturating_add(1))
}

fn visit_source_units(bytes: &[u8], mut visit: impl FnMut(char, usize)) {
    let mut offset = 0_usize;
    while offset < bytes.len() {
        let remaining = bytes.get(offset..).unwrap_or_default();
        match std::str::from_utf8(remaining) {
            Ok(valid) => {
                for character in valid.chars() {
                    visit(character, if character == '\t' { 4 } else { 1 });
                }
                break;
            }
            Err(error) => {
                let valid_len = error.valid_up_to();
                let valid_prefix = remaining.get(..valid_len).unwrap_or_default();
                if let Ok(valid) = std::str::from_utf8(valid_prefix) {
                    for character in valid.chars() {
                        visit(character, if character == '\t' { 4 } else { 1 });
                    }
                }
                offset = offset.saturating_add(valid_len);
                let invalid_len = error
                    .error_len()
                    .unwrap_or_else(|| remaining.len().saturating_sub(valid_len))
                    .max(1);
                for _ in 0..invalid_len {
                    visit('\u{FFFD}', 1);
                    offset = offset.saturating_add(1);
                }
            }
        }
    }
}

fn display_width(bytes: &[u8]) -> usize {
    let mut width = 0_usize;
    visit_source_units(bytes, |_character, unit_width| {
        width = width.saturating_add(unit_width);
    });
    width
}

fn render_source_line(bytes: &[u8]) -> String {
    let mut output = String::new();
    visit_source_units(bytes, |character, _unit_width| {
        if character == '\t' {
            output.push_str("    ");
        } else {
            output.push(character);
        }
    });
    output
}

fn append_header(output: &mut String, diag: &Diagnostic, opts: TextOptions) {
    let prefix = match diag.kind {
        ReportKind::Internal => "internal error".to_owned(),
        ReportKind::Runtime | ReportKind::Resource => code_prefix("runtime error", diag),
        ReportKind::Check | ReportKind::Limit | ReportKind::Args => {
            let severity = match diag.severity {
                Severity::Error => "error",
                Severity::Warning => "warning",
            };
            code_prefix(severity, diag)
        }
    };
    push_colored(output, &prefix, RED_BOLD, opts.color);
    output.push_str(": ");
    output.push_str(&diag.message);
}

fn code_prefix(severity: &str, diag: &Diagnostic) -> String {
    match diag.code {
        Some(code) => format!("{severity}[{}]", code.info().id),
        None => severity.to_owned(),
    }
}

fn append_primary_excerpt(
    output: &mut String,
    label: &PreparedLabel<'_>,
    gutter_width: usize,
    opts: TextOptions,
) {
    push_spaces(output, gutter_width);
    push_colored(output, "-->", BLUE_BOLD, opts.color);
    output.push(' ');
    append_location(output, label.source.name(), label.line, label.column);
    output.push('\n');
    append_vertical_line(output, gutter_width, opts);
    append_source_row(output, label.line, label.line_text, gutter_width, opts);
    append_marker_line(output, label, gutter_width, true, opts);
}

fn append_secondary_excerpt(
    output: &mut String,
    label: &PreparedLabel<'_>,
    gutter_width: usize,
    opts: TextOptions,
) {
    append_vertical_line(output, gutter_width, opts);
    push_spaces(output, gutter_width);
    push_colored(output, ":::", BLUE_BOLD, opts.color);
    output.push(' ');
    append_location(output, label.source.name(), label.line, label.column);
    output.push('\n');
    append_vertical_line(output, gutter_width, opts);
    append_source_row(output, label.line, label.line_text, gutter_width, opts);
    append_marker_line(output, label, gutter_width, false, opts);
}

fn append_location(output: &mut String, file: &str, line: u32, column: u32) {
    output.push_str(file);
    output.push(':');
    output.push_str(&line.to_string());
    output.push(':');
    output.push_str(&column.to_string());
}

fn append_vertical_line(output: &mut String, gutter_width: usize, opts: TextOptions) {
    push_spaces(output, gutter_width.saturating_add(1));
    push_colored(output, "|", BLUE_BOLD, opts.color);
    output.push('\n');
}

fn append_source_row(
    output: &mut String,
    line: u32,
    line_text: &[u8],
    gutter_width: usize,
    opts: TextOptions,
) {
    let line_number = line.to_string();
    let mut number_field = String::new();
    push_spaces(
        &mut number_field,
        gutter_width.saturating_sub(line_number.len()),
    );
    number_field.push_str(&line_number);
    push_colored(output, &number_field, BLUE_BOLD, opts.color);
    output.push(' ');
    push_colored(output, "|", BLUE_BOLD, opts.color);
    output.push(' ');
    output.push_str(&render_source_line(line_text));
    output.push('\n');
}

fn append_marker_line(
    output: &mut String,
    label: &PreparedLabel<'_>,
    gutter_width: usize,
    primary: bool,
    opts: TextOptions,
) {
    push_spaces(output, gutter_width.saturating_add(1));
    push_colored(output, "|", BLUE_BOLD, opts.color);
    output.push(' ');
    push_spaces(output, label.indent);
    let marker = if primary { "^" } else { "-" };
    let marker_color = if primary { RED_BOLD } else { BLUE_BOLD };
    for _ in 0..label.marker_width {
        push_colored(output, marker, marker_color, opts.color);
    }
    if !label.text.is_empty() {
        output.push(' ');
        output.push_str(label.text);
    }
    output.push('\n');
}

fn append_tagged_line(
    output: &mut String,
    tag: &str,
    message: &str,
    gutter_width: usize,
    opts: TextOptions,
) {
    push_spaces(output, gutter_width.saturating_add(1));
    push_colored(output, "=", BLUE_BOLD, opts.color);
    output.push(' ');
    push_colored(output, tag, BOLD, opts.color);
    output.push_str(": ");
    output.push_str(message);
    output.push('\n');
}

fn append_trace(
    output: &mut String,
    trace: &CallTrace,
    sources: &SourceTable,
    gutter_width: usize,
    opts: TextOptions,
) {
    append_tagged_line(
        output,
        "note",
        codes::text::TRACE_HEADER,
        gutter_width,
        opts,
    );
    let names = trace
        .frames
        .iter()
        .map(|frame| trace_frame_name(frame, sources))
        .collect::<Vec<_>>();
    let name_width = names
        .iter()
        .map(|name| name.chars().count())
        .max()
        .unwrap_or(0);
    let indent = gutter_width.saturating_add(11);

    for (index, (frame, name)) in trace.frames.iter().zip(names.iter()).enumerate() {
        if trace.omitted > 0 && index == 10 {
            append_omitted_frames(output, trace.omitted, indent);
        }
        push_spaces(output, indent);
        output.push_str(name);
        if let Some(location) = frame
            .call_site
            .and_then(|span| source_location(span, sources))
        {
            let name_length = name.chars().count();
            push_spaces(output, name_width.saturating_sub(name_length));
            output.push_str(" at ");
            append_location(output, location.file, location.line, location.column);
        }
        output.push('\n');
    }

    if trace.omitted > 0 && trace.frames.len() <= 10 {
        append_omitted_frames(output, trace.omitted, indent);
    }
}

fn append_omitted_frames(output: &mut String, omitted: u32, indent: usize) {
    let message = codes::fill_template(
        codes::text::TRACE_OMITTED,
        &[("count", omitted.to_string())],
    );
    push_spaces(output, indent);
    output.push_str(&message);
    output.push('\n');
}

fn trace_frame_name(frame: &TraceFrame, sources: &SourceTable) -> String {
    match &frame.name {
        FrameName::Named(name) => name.clone(),
        FrameName::Lambda(span) => match source_location(*span, sources) {
            Some(location) => format!(
                "<lambda {}:{}:{}>",
                location.file, location.line, location.column
            ),
            None => "<lambda>".to_owned(),
        },
    }
}

fn append_backtrace(output: &mut String, backtrace: &str, gutter_width: usize, opts: TextOptions) {
    push_spaces(output, gutter_width.saturating_add(1));
    push_colored(output, "=", BLUE_BOLD, opts.color);
    output.push_str(" backtrace:\n");
    for line in backtrace.lines() {
        push_spaces(output, gutter_width.saturating_add(3));
        output.push_str(line);
        output.push('\n');
    }
}

fn append_summary_line(output: &mut String, message: &str, opts: TextOptions) {
    push_colored(output, "error", RED_BOLD, opts.color);
    output.push_str(": ");
    output.push_str(message);
    output.push('\n');
}

fn push_spaces(output: &mut String, count: usize) {
    for _ in 0..count {
        output.push(' ');
    }
}

fn push_colored(output: &mut String, value: &str, color: &str, enabled: bool) {
    if enabled {
        output.push_str(color);
        output.push_str(value);
        output.push_str(RESET);
    } else {
        output.push_str(value);
    }
}

fn kind_name(kind: ReportKind) -> &'static str {
    match kind {
        ReportKind::Check => "check",
        ReportKind::Limit => "limit",
        ReportKind::Runtime => "runtime",
        ReportKind::Resource => "resource",
        ReportKind::Args => "args",
        ReportKind::Internal => "internal",
    }
}

fn append_json_label(output: &mut String, label: &Label, sources: &SourceTable) {
    append_json_span(output, label.span, &label.text, sources);
}

fn append_json_span(output: &mut String, span: Span, label: &str, sources: &SourceTable) {
    let Some(source) = sources.get(span.file) else {
        output.push_str("null");
        return;
    };

    output.push_str("{\"file\":");
    push_json_string(output, source.name());
    output.push_str(",\"start\":");
    append_json_position(output, source, span.start);
    output.push_str(",\"end\":");
    append_json_position(output, source, span.end);
    output.push_str(",\"label\":");
    push_json_string(output, label);
    output.push('}');
}

fn append_json_position(output: &mut String, source: &Source, offset: BytePos) {
    let position = source.line_col(offset);
    output.push_str("{\"line\":");
    output.push_str(&position.line.to_string());
    output.push_str(",\"column\":");
    output.push_str(&position.column.to_string());
    output.push_str(",\"offset\":");
    output.push_str(&offset.0.to_string());
    output.push('}');
}

fn append_json_strings(output: &mut String, values: &[String]) {
    output.push('[');
    for (index, value) in values.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        push_json_string(output, value);
    }
    output.push(']');
}

fn push_json_string(output: &mut String, value: &str) {
    output.push('"');
    for character in value.chars() {
        match character {
            '"' => output.push_str("\\\""),
            '\\' => output.push_str("\\\\"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            '\u{0}'..='\u{1F}' => {
                output.push_str(&format!("\\u{:04x}", u32::from(character)));
            }
            _ => output.push(character),
        }
    }
    output.push('"');
}

#[cfg(test)]
#[allow(
    clippy::arithmetic_side_effects,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::unwrap_used
)]
// テストの失敗は assert で表し、準備データには必要な添字と算術を使う。
mod tests {
    use crate::base::{BytePos, FileId, Source, SourceKind, SourceTable, Span};

    use super::{TextOptions, render_check_text, render_json_line, render_one_text};
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

    fn span(file: FileId, start: usize, length: usize) -> Span {
        Span {
            file,
            start: BytePos(u32::try_from(start).unwrap_or(u32::MAX)),
            end: BytePos(u32::try_from(start.saturating_add(length)).unwrap_or(u32::MAX)),
        }
    }

    fn check_diag(message: &str) -> Diagnostic {
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
            render_check_text(&[], &sources, "run", "count.bnt", opts),
            ""
        );

        let one = vec![check_diag("one")];
        assert!(
            render_check_text(&one, &sources, "run", "count.bnt", opts)
                .ends_with("error: could not run count.bnt due to 1 previous error\n")
        );

        let three = vec![check_diag("one"), check_diag("two"), check_diag("three")];
        assert!(
            render_check_text(&three, &sources, "run", "count.bnt", opts)
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
            "run",
            "count.bnt",
            TextOptions { color: false },
        );
        assert_eq!(output.matches("error[E0401]").count(), 50);
        assert!(output.contains("error: 3 more errors not shown\n\n"));
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
}
