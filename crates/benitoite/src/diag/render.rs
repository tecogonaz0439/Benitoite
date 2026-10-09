//! 診断を文章と JSON Lines の形へ書き出す（設計書 02-10）。

use crate::base::{BytePos, Source, SourceTable, Span};

use super::codes;
mod excerpt;
use super::{CallTrace, Diagnostic, Edit, FrameName, Label, ReportKind, Severity, TraceFrame};
use excerpt::prepare_edits;

const RED_BOLD: &str = "\x1b[1;31m";
const YELLOW_BOLD: &str = "\x1b[1;33m";
const BLUE_BOLD: &str = "\x1b[1;34m";
const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";

/// 文章の形式の選択肢。
#[derive(Clone, Copy, Debug)]
pub struct TextOptions {
    /// 色を付けるか。CLI が、標準エラー出力が端末で `NO_COLOR` がないときに true にする
    pub color: bool,
}

/// 件数の行の動詞（02-10「文章の形式」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Verb {
    Run,
    Check,
    Test,
}

/// 検査の診断（誤りと警告）の一覧を、文章の形式にする。渡された順に書き（並べるのは呼び出し側。
/// 10-13 の `pipeline::check`）、誤りと警告を合わせて 50 件を超えた分は書かずに件数を示し、
/// 最後に件数の行を書く（誤りも警告もなければ書かない）。`file` は実行を始めるファイルの表示名。
pub fn render_check_text(
    diags: &[Diagnostic],
    sources: &SourceTable,
    verb: Verb,
    file: &str,
    opts: TextOptions,
) -> String {
    if diags.is_empty() {
        return String::new();
    }
    let errors = diags.iter().filter(|diag| diag.is_error()).count();
    let warnings = diags.len().saturating_sub(errors);
    let warning_only = errors == 0;
    let mut output = String::new();
    for diag in diags.iter().take(50) {
        output.push_str(&render_one_text(diag, sources, opts));
        output.push('\n');
    }
    if diags.len() > 50 {
        let message = codes::fill_template(
            codes::text::TOO_MANY,
            &[("count", diags.len().saturating_sub(50).to_string())],
        );
        append_summary_line(&mut output, &message, warning_only, opts);
        output.push('\n');
    }
    let verb = match verb {
        Verb::Run => "run",
        Verb::Check => "check",
        Verb::Test => "test",
    };
    let mut message = if warning_only {
        codes::fill_template(
            if warnings == 1 {
                codes::text::WARNINGS_ONLY_ONE
            } else {
                codes::text::WARNINGS_ONLY_MANY
            },
            &[("count", warnings.to_string())],
        )
    } else {
        codes::fill_template(
            if errors == 1 {
                codes::text::SUMMARY_ONE
            } else {
                codes::text::SUMMARY_MANY
            },
            &[
                ("verb", verb.to_owned()),
                ("file", file.to_owned()),
                ("count", errors.to_string()),
            ],
        )
    };
    if errors > 0 && warnings > 0 {
        message.push_str(&codes::fill_template(
            if warnings == 1 {
                codes::text::SUMMARY_WARNINGS_ONE
            } else {
                codes::text::SUMMARY_WARNINGS_MANY
            },
            &[("count", warnings.to_string())],
        ));
    }
    append_summary_line(&mut output, &message, warning_only, opts);
    output
}

/// 一件の診断・報告を文章の形式にする（末尾に空行を含めない改行で終える）。
/// 実行時エラー、資源の不足、解放の失敗、処理系の不具合、処理系の制限、コマンドライン引数の誤りに使う。
pub fn render_one_text(diag: &Diagnostic, sources: &SourceTable, opts: TextOptions) -> String {
    let primary = diag
        .primary
        .as_ref()
        .filter(|_| diag.waiting.is_empty())
        .and_then(|label| prepare_label(label, sources));
    let mut secondary = if primary.is_some() {
        diag.secondary
            .iter()
            .filter_map(|label| prepare_label(label, sources))
            .collect::<Vec<_>>()
    } else {
        Vec::new()
    };

    let edited = diag
        .helps
        .iter()
        .map(|help| prepare_edits(&help.edits, sources))
        .collect::<Vec<_>>();
    let gutter_width = primary
        .iter()
        .chain(secondary.iter())
        .map(|label| label.line.to_string().len())
        .chain(
            edited
                .iter()
                .flatten()
                .flat_map(|group| group.rows.iter().map(|row| row.number.to_string().len())),
        )
        .max()
        .unwrap_or(2)
        .max(2);

    let mut output = String::new();
    append_header(&mut output, diag, opts);
    output.push('\n');

    let primary_opts = MarkerOptions {
        text: opts,
        warning: diag.is_warning(),
    };
    if let Some(primary) = primary.as_ref() {
        append_primary_excerpt(&mut output, primary, gutter_width, primary_opts);
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
        append_marker_line(
            &mut output,
            label,
            gutter_width,
            false,
            MarkerOptions {
                text: opts,
                warning: false,
            },
        );
    }
    for label in &other_lines {
        append_secondary_excerpt(&mut output, label, gutter_width, opts);
    }

    let has_trailing = diag.trace.is_some()
        || !diag.task_origins.is_empty()
        || !diag.waiting.is_empty()
        || !diag.notes.is_empty()
        || !diag.helps.is_empty()
        || diag.backtrace.is_some();
    if has_trailing && (primary.is_some() || !other_lines.is_empty()) {
        append_vertical_line(&mut output, gutter_width, opts);
    }

    if diag.waiting.is_empty() {
        append_trace_sections(
            &mut output,
            diag.trace.as_ref(),
            &diag.task_origins,
            sources,
            gutter_width,
            opts,
        );
    } else {
        append_waiting(&mut output, diag, sources, gutter_width, opts);
    }
    for note in &diag.notes {
        append_tagged_line(&mut output, "note", note, gutter_width, opts);
    }
    for (index, (help, groups)) in diag.helps.iter().zip(&edited).enumerate() {
        append_tagged_line(&mut output, "help", &help.message, gutter_width, opts);
        for group in groups {
            append_vertical_line(&mut output, gutter_width, opts);
            if diag
                .primary
                .as_ref()
                .is_none_or(|label| label.span.file != group.file)
            {
                push_spaces(&mut output, gutter_width);
                push_colored(&mut output, ":::", BLUE_BOLD, opts.color);
                output.push(' ');
                append_location(&mut output, &group.name, group.line, group.column);
                output.push('\n');
                append_vertical_line(&mut output, gutter_width, opts);
            }
            for row in &group.rows {
                append_source_row(
                    &mut output,
                    row.number,
                    row.text.as_bytes(),
                    gutter_width,
                    opts,
                );
                if !row.markers.is_empty() {
                    push_spaces(&mut output, gutter_width.saturating_add(1));
                    push_colored(&mut output, "|", BLUE_BOLD, opts.color);
                    output.push(' ');
                    push_colored(&mut output, &row.markers, BLUE_BOLD, opts.color);
                    output.push('\n');
                }
            }
        }
        if !groups.is_empty()
            && (index.saturating_add(1) < diag.helps.len() || diag.backtrace.is_some())
        {
            append_vertical_line(&mut output, gutter_width, opts);
        }
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
    output.push_str(",\"helps\":[");
    for (index, help) in diag.helps.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        output.push_str("{\"message\":");
        push_json_string(&mut output, &help.message);
        output.push_str(",\"edits\":[");
        for (index, edit) in help.edits.iter().enumerate() {
            if index > 0 {
                output.push(',');
            }
            append_json_edit(&mut output, edit, sources);
        }
        output.push_str("]}");
    }
    output.push(']');
    if let Some(trace) = diag.trace.as_ref() {
        output.push(',');
        output.push_str(&json_trace_fields(trace, &diag.task_origins, sources));
    }
    if !diag.waiting.is_empty() {
        output.push_str(",\"waitingTasks\":[");
        for (index, task) in diag.waiting.iter().enumerate() {
            if index > 0 {
                output.push(',');
            }
            output.push_str("{\"task\":");
            append_json_frame(&mut output, &task.task, sources);
            output.push_str(",\"waitsFor\":");
            push_json_string(&mut output, &task.waits_for);
            output.push_str(",\"location\":");
            append_json_optional_span(&mut output, task.location, sources);
            output.push('}');
        }
        output.push(']');
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
        ReportKind::Check | ReportKind::Limit | ReportKind::Args | ReportKind::Release => {
            let severity = match diag.severity {
                Severity::Error => "error",
                Severity::Warning => "warning",
            };
            code_prefix(severity, diag)
        }
    };
    push_colored(
        output,
        &prefix,
        if diag.is_warning() {
            YELLOW_BOLD
        } else {
            RED_BOLD
        },
        opts.color,
    );
    output.push_str(": ");
    output.push_str(&diag.message);
}

fn code_prefix(severity: &str, diag: &Diagnostic) -> String {
    match diag.code {
        Some(code) => format!("{severity}[{}]", code.info().id),
        None => severity.to_owned(),
    }
}

#[derive(Clone, Copy)]
struct MarkerOptions {
    text: TextOptions,
    warning: bool,
}

fn append_primary_excerpt(
    output: &mut String,
    label: &PreparedLabel<'_>,
    gutter_width: usize,
    marker_opts: MarkerOptions,
) {
    let opts = marker_opts.text;
    push_spaces(output, gutter_width);
    push_colored(output, "-->", BLUE_BOLD, opts.color);
    output.push(' ');
    append_location(output, label.source.name(), label.line, label.column);
    output.push('\n');
    append_vertical_line(output, gutter_width, opts);
    append_source_row(output, label.line, label.line_text, gutter_width, opts);
    append_marker_line(output, label, gutter_width, true, marker_opts);
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
    append_marker_line(
        output,
        label,
        gutter_width,
        false,
        MarkerOptions {
            text: opts,
            warning: false,
        },
    );
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
    marker_opts: MarkerOptions,
) {
    let opts = marker_opts.text;
    push_spaces(output, gutter_width.saturating_add(1));
    push_colored(output, "|", BLUE_BOLD, opts.color);
    output.push(' ');
    push_spaces(output, label.indent);
    let marker = if primary { "^" } else { "-" };
    let marker_color = if !primary {
        BLUE_BOLD
    } else if marker_opts.warning {
        YELLOW_BOLD
    } else {
        RED_BOLD
    };
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

// 呼び出しの履歴とタスクの起動の履歴の節を書く。名前の欄の幅は二つの節で揃える（02-10「実行時エラーと資源の不足の報告」）。
// `render_one_text` と `render_trace_text` の共通の部分（実装プラン D11「作るもの」）。
fn append_trace_sections(
    output: &mut String,
    trace: Option<&CallTrace>,
    task_origins: &[TraceFrame],
    sources: &SourceTable,
    gutter_width: usize,
    opts: TextOptions,
) {
    let name_width = trace
        .iter()
        .flat_map(|trace| &trace.frames)
        .chain(task_origins)
        .map(|frame| trace_frame_name(frame, sources).chars().count())
        .max()
        .unwrap_or(0);
    if let Some(trace) = trace {
        append_trace(output, trace, sources, gutter_width, name_width, opts);
    }
    if !task_origins.is_empty() {
        append_tagged_line(
            output,
            "note",
            codes::text::TASK_ORIGINS_HEADER,
            gutter_width,
            opts,
        );
        append_frames(output, task_origins, 0, sources, gutter_width, name_width);
    }
}

fn append_trace(
    output: &mut String,
    trace: &CallTrace,
    sources: &SourceTable,
    gutter_width: usize,
    name_width: usize,
    opts: TextOptions,
) {
    if trace.frames.is_empty() && trace.omitted == 0 {
        return;
    }
    append_tagged_line(
        output,
        "note",
        codes::text::TRACE_HEADER,
        gutter_width,
        opts,
    );
    append_frames(
        output,
        &trace.frames,
        trace.omitted,
        sources,
        gutter_width,
        name_width,
    );
}

fn append_frames(
    output: &mut String,
    frames: &[TraceFrame],
    omitted: u32,
    sources: &SourceTable,
    gutter_width: usize,
    name_width: usize,
) {
    let indent = gutter_width.saturating_add(11);
    for (index, frame) in frames.iter().enumerate() {
        if omitted > 0 && index == 10 {
            append_omitted_frames(output, omitted, indent);
        }
        let name = trace_frame_name(frame, sources);
        push_spaces(output, indent);
        output.push_str(&name);
        if let Some(location) = frame
            .call_site
            .and_then(|span| source_location(span, sources))
        {
            push_spaces(output, name_width.saturating_sub(name.chars().count()));
            output.push_str(" at ");
            append_location(output, location.file, location.line, location.column);
        }
        output.push('\n');
    }
    if omitted > 0 && frames.len() <= 10 {
        append_omitted_frames(output, omitted, indent);
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
        FrameName::Lambda(span) => anonymous_name("lambda", *span, sources),
        FrameName::Handle(span) => anonymous_name("handle", *span, sources),
        FrameName::Lazy(span) => anonymous_name("lazy", *span, sources),
        FrameName::Case { operation, span } => {
            anonymous_name(&format!("case {operation}"), *span, sources)
        }
    }
}

fn anonymous_name(name: &str, span: Span, sources: &SourceTable) -> String {
    match source_location(span, sources) {
        Some(location) => format!(
            "<{name} {}:{}:{}>",
            location.file, location.line, location.column
        ),
        None => format!("<{name}>"),
    }
}

fn append_waiting(
    output: &mut String,
    diag: &Diagnostic,
    sources: &SourceTable,
    gutter_width: usize,
    opts: TextOptions,
) {
    append_tagged_line(
        output,
        "note",
        codes::text::WAITING_HEADER,
        gutter_width,
        opts,
    );
    let rows = diag
        .waiting
        .iter()
        .map(|task| {
            let mut name = trace_frame_name(&task.task, sources);
            if let Some(location) = task
                .task
                .call_site
                .and_then(|span| source_location(span, sources))
            {
                name.push_str(" at ");
                append_location(&mut name, location.file, location.line, location.column);
            }
            let kind =
                codes::fill_template(codes::text::WAITS_FOR, &[("kind", task.waits_for.clone())]);
            (
                name,
                kind,
                task.location
                    .and_then(|span| source_location(span, sources)),
            )
        })
        .collect::<Vec<_>>();
    let task_width = rows
        .iter()
        .map(|(name, _, _)| name.chars().count())
        .max()
        .unwrap_or(0);
    let kind_width = rows
        .iter()
        .map(|(_, kind, _)| kind.chars().count())
        .max()
        .unwrap_or(0);
    for (name, kind, location) in rows {
        push_spaces(output, gutter_width.saturating_add(11));
        output.push_str(&name);
        push_spaces(
            output,
            task_width
                .saturating_sub(name.chars().count())
                .saturating_add(1),
        );
        output.push_str(&kind);
        if let Some(location) = location {
            push_spaces(output, kind_width.saturating_sub(kind.chars().count()));
            output.push_str(" at ");
            append_location(output, location.file, location.line, location.column);
        }
        output.push('\n');
    }
}

fn append_json_frames(output: &mut String, frames: &[TraceFrame], sources: &SourceTable) {
    output.push('[');
    for (index, frame) in frames.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        append_json_frame(output, frame, sources);
    }
    output.push(']');
}

fn append_json_frame(output: &mut String, frame: &TraceFrame, sources: &SourceTable) {
    output.push_str("{\"function\":");
    push_json_string(output, &trace_frame_name(frame, sources));
    output.push_str(",\"location\":");
    append_json_optional_span(output, frame.call_site, sources);
    output.push('}');
}

fn append_json_optional_span(output: &mut String, span: Option<Span>, sources: &SourceTable) {
    match span {
        Some(span) => append_json_span(output, span, "", sources),
        None => output.push_str("null"),
    }
}

fn append_json_edit(output: &mut String, edit: &Edit, sources: &SourceTable) {
    let Some(source) = sources.get(edit.span.file) else {
        output.push_str("null");
        return;
    };
    output.push_str("{\"file\":");
    push_json_string(output, source.name());
    output.push_str(",\"start\":");
    append_json_position(output, source, edit.span.start);
    output.push_str(",\"end\":");
    append_json_position(output, source, edit.span.end);
    output.push_str(",\"replacement\":");
    push_json_string(output, &edit.replacement);
    output.push('}');
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

fn append_summary_line(output: &mut String, message: &str, warning: bool, opts: TextOptions) {
    push_colored(
        output,
        if warning { "warning" } else { "error" },
        if warning { YELLOW_BOLD } else { RED_BOLD },
        opts.color,
    );
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
        ReportKind::Release => "release",
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
mod tests;

#[cfg(test)]
mod acceptance_tests;

#[cfg(test)]
mod help_tests;

/// 位置の行（主な位置があれば ` --> ファイル:行:列`。抜粋は書かない）と、呼び出しの履歴・タスクの起動の履歴・末尾呼び出しの
/// 注記の行を、`render_one_text` の同じ部分と同じ形で書く（02-10「実行時エラーと資源の不足の報告」）。
pub fn render_trace_text(
    primary: Option<crate::base::Span>,
    trace: &super::CallTrace,
    task_origins: &[super::TraceFrame],
    sources: &SourceTable,
    opts: TextOptions,
) -> String {
    render_trace_text_with_notes(primary, trace, task_origins, &[], sources, opts)
}

/// `render_trace_text` に、末尾呼び出しの注記の前に置く注記の並び（止める途中の解放の失敗）を加えたもの。
/// 実行時エラーの報告と同じく、解放の注記を末尾呼び出しの注記の前に置く（実装プラン D11「作るもの」）。
pub(crate) fn render_trace_text_with_notes(
    primary: Option<Span>,
    trace: &CallTrace,
    task_origins: &[TraceFrame],
    notes: &[String],
    sources: &SourceTable,
    opts: TextOptions,
) -> String {
    let location = primary.and_then(|span| source_location(span, sources));
    // 溝の幅は `render_one_text` と同じく、主な位置の行番号の桁数（最小 2）。
    let gutter_width = location
        .map_or(2, |location| location.line.to_string().len())
        .max(2);
    let mut output = String::new();
    if let Some(location) = location {
        push_spaces(&mut output, gutter_width);
        push_colored(&mut output, "-->", BLUE_BOLD, opts.color);
        output.push(' ');
        append_location(&mut output, location.file, location.line, location.column);
        output.push('\n');
    }
    append_trace_sections(
        &mut output,
        Some(trace),
        task_origins,
        sources,
        gutter_width,
        opts,
    );
    for note in notes {
        append_tagged_line(&mut output, "note", note, gutter_width, opts);
    }
    append_tagged_line(
        &mut output,
        "note",
        codes::text::TRACE_TAIL_NOTE,
        gutter_width,
        opts,
    );
    output
}

/// 位置を JSON の位置の形（`file`・`start`・`end`・`label`）のオブジェクトにする。
pub fn json_location(span: crate::base::Span, label: &str, sources: &SourceTable) -> String {
    let mut output = String::new();
    append_json_span(&mut output, span, label, sources);
    output
}

/// 呼び出しの履歴を、JSON の `"trace":[…],"traceOmitted":n,"taskOrigins":[…]` の項目の並びにする（前後の `{`・`}` と
/// 先頭の `,` を含めない）。
pub fn json_trace_fields(
    trace: &super::CallTrace,
    task_origins: &[super::TraceFrame],
    sources: &SourceTable,
) -> String {
    let mut output = String::from("\"trace\":");
    append_json_frames(&mut output, &trace.frames, sources);
    output.push_str(",\"traceOmitted\":");
    output.push_str(&trace.omitted.to_string());
    output.push_str(",\"taskOrigins\":");
    append_json_frames(&mut output, task_origins, sources);
    output
}

/// 文字列を JSON の文字列（引用符を含む）にする。
pub fn json_string(text: &str) -> String {
    let mut output = String::new();
    push_json_string(&mut output, text);
    output
}
