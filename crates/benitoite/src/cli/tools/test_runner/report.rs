//! テストの結果の報告の文章の形と JSON Lines の形（設計書 06-04「結果の報告」）。

use super::{Failure, Summary, TestFn, TestResult, text};
use crate::base::SourceTable;
use crate::diag::codes::{self, fill_template};
use crate::diag::render::{self, TextOptions};
use crate::runtime::assert::{AssertOp, quoted};

/// テストの名前（説明を文字列リテラルの形にしたものか、関数の名前）。
pub fn test_name(test: &TestFn) -> String {
    match &test.description {
        // `Trait.showString` と同じ形の文字列リテラルにする（10-18「文章の形」）。
        Some(description) => quoted(description.chars(), '"'),
        None => test.function.clone(),
    }
}

/// テストごとの一行（改行で終える）。`file` はファイルの表示名。
pub fn text_line(file: &str, result: &TestResult) -> String {
    let outcome = if result.failure.is_some() {
        text::OUTCOME_FAILED
    } else {
        text::OUTCOME_OK
    };
    // 埋めた値の中の `{…}` を型板の名前として読まないよう、型板を一度だけ走査して埋める。
    let mut line = fill_template(
        text::TEST_LINE,
        &[
            ("file", file.to_owned()),
            ("name", test_name(&result.test)),
            ("outcome", outcome.to_owned()),
        ],
    );
    line.push('\n');
    line
}

/// 失敗したテスト一つの詳細（`----` の見出しから、捕らえた出力まで）。成功なら空の文字列。
pub fn text_failure(
    file: &str,
    result: &TestResult,
    sources: &SourceTable,
    opts: TextOptions,
) -> String {
    let Some(failure) = result.failure.as_ref() else {
        return String::new();
    };
    let mut output = fill_template(
        text::FAILURE_HEADER,
        &[("file", file.to_owned()), ("name", test_name(&result.test))],
    );
    output.push('\n');
    match failure {
        Failure::Assert {
            op,
            message,
            left,
            right,
            primary,
            trace,
            task_origins,
            notes,
        } => {
            push_line(
                &mut output,
                &fill_template(text::ASSERT_FAILED, &[("operation", op.name().to_owned())]),
            );
            match op {
                AssertOp::Equal | AssertOp::NotEqual => {
                    if let Some(left) = left {
                        push_line(
                            &mut output,
                            &fill_template(text::LEFT, &[("value", left.clone())]),
                        );
                    }
                    if let Some(right) = right {
                        push_line(
                            &mut output,
                            &fill_template(text::RIGHT, &[("value", right.clone())]),
                        );
                    }
                }
                AssertOp::IsTrue | AssertOp::Fail => {
                    push_line(
                        &mut output,
                        &fill_template(text::MESSAGE, &[("value", message.clone())]),
                    );
                }
            }
            output.push_str(&render::render_trace_text_with_notes(
                *primary,
                trace,
                task_origins,
                notes,
                sources,
                opts,
            ));
        }
        Failure::Error { message } => {
            push_line(
                &mut output,
                &fill_template(text::RETURNED_ERROR, &[("message", message.clone())]),
            );
        }
        Failure::Runtime { report } => {
            output.push_str(&render::render_one_text(report, sources, opts));
        }
        Failure::Exit { code, reports } => {
            push_line(
                &mut output,
                &fill_template(text::EXITED, &[("code", code.to_string())]),
            );
            for report in reports {
                output.push_str(&render::render_one_text(report, sources, opts));
            }
        }
    }
    for (header, bytes) in [
        (text::CAPTURED_STDOUT, &result.stdout),
        (text::CAPTURED_STDERR, &result.stderr),
    ] {
        if bytes.is_empty() {
            continue;
        }
        push_line(&mut output, header);
        // 正しくない UTF-8 は U+FFFD に置き換える（実装プラン D11「手順の要点」の 6）。
        output.push_str(&String::from_utf8_lossy(bytes));
        if !output.ends_with('\n') {
            output.push('\n');
        }
    }
    output
}

/// 集計の行（改行で終える）。
pub fn text_summary(summary: &Summary) -> String {
    let mut line = fill_template(
        text::RESULT,
        &[
            ("outcome", outcome(summary).to_owned()),
            ("passed", summary.passed.to_string()),
            ("failed", summary.failed.to_string()),
        ],
    );
    if summary.files_not_run > 0 {
        line.push_str(&fill_template(
            text::FILES_NOT_RUN,
            &[("count", summary.files_not_run.to_string())],
        ));
    }
    if summary.interrupted {
        line.push_str(text::INTERRUPTED);
    }
    line.push('\n');
    line
}

/// テストごとの JSON の一行（末尾に改行を付けない）。
pub fn json_test(file: &str, result: &TestResult, sources: &SourceTable) -> String {
    let test = &result.test;
    let mut output = String::from("{\"kind\":\"test\",\"file\":");
    output.push_str(&render::json_string(file));
    output.push_str(",\"name\":");
    // JSON の `name` は引用符を付けない説明か関数の名前（10-18「JSON Lines の形」）。
    output.push_str(&render::json_string(
        test.description.as_deref().unwrap_or(&test.function),
    ));
    output.push_str(",\"function\":");
    output.push_str(&render::json_string(&test.function));
    output.push_str(",\"location\":");
    output.push_str(&render::json_location(test.location, "", sources));
    output.push_str(",\"outcome\":");
    output.push_str(if result.failure.is_some() {
        "\"failed\""
    } else {
        "\"passed\""
    });
    output.push_str(",\"failure\":");
    match result.failure.as_ref() {
        None => output.push_str("null"),
        Some(failure) => output.push_str(&json_failure(failure, sources)),
    }
    output.push_str(",\"stdout\":");
    output.push_str(&render::json_string(&String::from_utf8_lossy(
        &result.stdout,
    )));
    output.push_str(",\"stderr\":");
    output.push_str(&render::json_string(&String::from_utf8_lossy(
        &result.stderr,
    )));
    output.push('}');
    output
}

/// 集計の JSON の一行（末尾に改行を付けない）。
pub fn json_summary(summary: &Summary) -> String {
    format!(
        "{{\"kind\":\"testSummary\",\"passed\":{},\"failed\":{},\"filesNotRun\":{},\"interrupted\":{}}}",
        summary.passed, summary.failed, summary.files_not_run, summary.interrupted
    )
}

// 終了状態が 0 になるときだけ `ok`（10-18「文章の形」）。
fn outcome(summary: &Summary) -> &'static str {
    if summary.failed == 0 && summary.files_not_run == 0 && !summary.interrupted {
        text::OUTCOME_OK
    } else {
        text::OUTCOME_FAILED
    }
}

fn push_line(output: &mut String, line: &str) {
    output.push_str(line);
    output.push('\n');
}

// `failure` の項目（06-04「結果の報告」、10-18「JSON Lines の形」）。
fn json_failure(failure: &Failure, sources: &SourceTable) -> String {
    match failure {
        Failure::Assert {
            op,
            message,
            left,
            right,
            primary,
            trace,
            task_origins,
            notes,
        } => {
            let mut output = String::from("{\"reason\":\"assert\",\"message\":");
            output.push_str(&render::json_string(message));
            output.push_str(",\"primary\":");
            match primary {
                Some(span) => output.push_str(&render::json_location(*span, "", sources)),
                None => output.push_str("null"),
            }
            // 解放の注記を末尾呼び出しの注記の前に置く（文章の形と同じ並び。06-04「結果の報告」）。
            output.push_str(",\"notes\":");
            let tail = codes::text::TRACE_TAIL_NOTE.to_owned();
            output.push_str(&json_strings(notes.iter().chain(std::iter::once(&tail))));
            output.push(',');
            output.push_str(&render::json_trace_fields(trace, task_origins, sources));
            if matches!(op, AssertOp::Equal | AssertOp::NotEqual) {
                for (key, value) in [("left", left), ("right", right)] {
                    output.push_str(",\"");
                    output.push_str(key);
                    output.push_str("\":");
                    match value {
                        Some(value) => output.push_str(&render::json_string(value)),
                        None => output.push_str("null"),
                    }
                }
            }
            output.push('}');
            output
        }
        Failure::Error { message } => format!(
            "{{\"reason\":\"error\",\"message\":{}}}",
            render::json_string(message)
        ),
        Failure::Exit { code, reports } => {
            // 解放の失敗の報告ごとに、RELEASE_WHILE_STOPPING と同じ文を作る（10-18「JSON Lines の形」）。
            let notes: Vec<String> = reports
                .iter()
                .map(|report| {
                    let reason = report.notes.first().map_or("", String::as_str);
                    format!(
                        "{}{}{}{reason}",
                        text::RELEASE_STOPPING_PREFIX,
                        report.message,
                        text::RELEASE_STOPPING_REASON_SEPARATOR
                    )
                })
                .collect();
            format!(
                "{{\"reason\":\"exit\",\"message\":{},\"exitCode\":{code},\"notes\":{}}}",
                render::json_string(&fill_template(text::EXITED, &[("code", code.to_string())])),
                json_strings(notes.iter())
            )
        }
        Failure::Runtime { report } => {
            let line = render::render_json_line(report, sources);
            let rest = line.strip_prefix('{').unwrap_or(&line);
            format!("{{\"reason\":\"runtime\",{rest}")
        }
    }
}

// 文字列の JSON の配列。
fn json_strings<'a>(items: impl Iterator<Item = &'a String>) -> String {
    let mut output = String::from("[");
    for (index, item) in items.enumerate() {
        if index > 0 {
            output.push(',');
        }
        output.push_str(&render::json_string(item));
    }
    output.push(']');
    output
}

#[cfg(test)]
mod tests;
