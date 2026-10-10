// テストの失敗は panic で表す（実装プラン 00-02「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::base::{BindingId, BytePos, Source, SourceKind, Span};
use crate::bytecode::program::MainKind;
use crate::diag::{CallTrace, FrameName, TraceFrame, codes};

fn sources() -> (SourceTable, Span, Span) {
    let mut text = String::new();
    for _ in 0..119 {
        text.push_str("--\n");
    }
    let site = text.len() as u32;
    text.push_str("  Assert.fail(\"x\")\n");
    let mut table = SourceTable::new();
    let file = table.add(Source::new(
        "t.bnt".to_owned(),
        SourceKind::User,
        text.into_bytes(),
    ));
    let call = Span {
        file,
        start: BytePos(site + 2),
        end: BytePos(site + 18),
    };
    let name = Span {
        file,
        start: BytePos(0),
        end: BytePos(2),
    };
    (table, call, name)
}

fn test_fn(description: Option<&str>, location: Span) -> TestFn {
    TestFn {
        function: "check".to_owned(),
        description: description.map(str::to_owned),
        location,
        binding: BindingId(0),
        kind: MainKind::Unit,
    }
}

// 関門: `"assert"` の詳細の注記の並び（解放の注記を末尾呼び出しの注記の前に置く）と、位置の行の字下げが溝の幅
// （行番号の桁数）に従うこと、起動の履歴の節が履歴の名前の欄と揃うこと（10-18「文章の形」、実装プラン D11）。
#[test]
fn assert_details_put_release_notes_before_the_tail_note() {
    let (table, call, name) = sources();
    let result = TestResult {
        test: test_fn(None, name),
        failure: Some(Failure::Assert {
            op: AssertOp::Fail,
            message: "x".to_owned(),
            left: None,
            right: None,
            primary: Some(call),
            trace: CallTrace {
                frames: vec![TraceFrame {
                    name: FrameName::Named("helper".to_owned()),
                    call_site: None,
                }],
                omitted: 0,
            },
            task_origins: vec![TraceFrame {
                name: FrameName::Named("check".to_owned()),
                call_site: None,
            }],
            notes: vec!["release note".to_owned()],
        }),
        stdout: Vec::new(),
        stderr: vec![b'a', 0xff, b'\n'],
    };
    let text = text_failure("t.bnt", &result, &table, TextOptions { color: false });
    assert_eq!(
        text,
        format!(
            "---- t.bnt: check ----\nassertion failed: Assert.fail\n  message: x\n   --> t.bnt:120:3\n    = note: {}\n              helper\n    = note: {}\n              check\n    = note: release note\n    = note: {}\n---- captured stderr ----\na\u{FFFD}\n",
            codes::text::TRACE_HEADER,
            codes::text::TASK_ORIGINS_HEADER,
            codes::text::TRACE_TAIL_NOTE
        )
    );
    // JSON の出力も正しくない UTF-8 を U+FFFD に置き換える。
    let json = json_test("t.bnt", &result, &table);
    assert!(
        json.ends_with(",\"stdout\":\"\",\"stderr\":\"a\u{FFFD}\\n\"}"),
        "{json}"
    );
    assert!(
        json.contains("\"taskOrigins\":[{\"function\":\"check\",\"location\":null}]}"),
        "{json}"
    );
    // JSON の notes も、解放の注記の後に末尾呼び出しの注記を置く（06-04「結果の報告」）。
    assert!(
        json.contains(&format!(
            "\"notes\":[\"release note\",\"{}\"],\"trace\":",
            codes::text::TRACE_TAIL_NOTE
        )),
        "{json}"
    );
}

fn exit_json(reports: Vec<crate::diag::Diagnostic>) -> String {
    let (table, _, name) = sources();
    let result = TestResult {
        test: test_fn(None, name),
        failure: Some(Failure::Exit { code: 4, reports }),
        stdout: Vec::new(),
        stderr: Vec::new(),
    };
    json_test("t.bnt", &result, &table)
}

// 関門: `"exit"` の notes が解放の失敗の報告ごとに RELEASE_WHILE_STOPPING と同じ文を並べ、報告がなければ空の配列に
// なること（10-18「JSON Lines の形」、06-04「結果の報告」）。
#[test]
fn exit_json_notes_list_release_failures() {
    let mut report = crate::diag::DiagBuilder::new(crate::diag::DiagCode::R0401).build();
    report.message = "failed to release `File` opened at t.bnt:3:5".to_owned();
    report.notes = vec!["disk full".to_owned(), "second".to_owned()];
    let expected = codes::fill_template(
        codes::text::RELEASE_WHILE_STOPPING,
        &[
            ("resource", "File".to_owned()),
            ("location", "t.bnt:3:5".to_owned()),
            ("reason", "disk full".to_owned()),
        ],
    );
    let json = exit_json(vec![report.clone(), report]);
    assert!(
        json.contains(&format!(
            "\"exitCode\":4,\"notes\":[\"{expected}\",\"{expected}\"]}}"
        )),
        "{json}"
    );
    let json = exit_json(Vec::new());
    assert!(json.contains("\"exitCode\":4,\"notes\":[]}"), "{json}");
}

#[test]
fn a_passing_test_has_no_failure_details() {
    let (table, _, name) = sources();
    let result = TestResult {
        test: test_fn(Some("a $b\n"), name),
        failure: None,
        stdout: b"shown only on failure".to_vec(),
        stderr: Vec::new(),
    };
    assert_eq!(
        text_failure("t.bnt", &result, &table, TextOptions { color: false }),
        ""
    );
    // 説明は `Trait.showString` と同じ形の文字列リテラルにする。
    assert_eq!(
        text_line("t.bnt", &result),
        "test t.bnt: \"a \\$b\\n\" ... ok\n"
    );
}

// 関門: 集計の `ok` は、失敗も実行しなかったファイルも中断もないときだけ（10-18「文章の形」）。
#[test]
fn summary_is_ok_only_when_the_exit_status_is_zero() {
    let cases = [
        (
            Summary {
                passed: 3,
                ..Summary::default()
            },
            "test result: ok. 3 passed; 0 failed\n",
        ),
        (
            Summary {
                passed: 1,
                failed: 2,
                ..Summary::default()
            },
            "test result: FAILED. 1 passed; 2 failed\n",
        ),
        (
            Summary {
                files_not_run: 2,
                ..Summary::default()
            },
            "test result: FAILED. 0 passed; 0 failed; 2 files not run due to errors\n",
        ),
        (
            Summary {
                passed: 1,
                interrupted: true,
                ..Summary::default()
            },
            "test result: FAILED. 1 passed; 0 failed; interrupted\n",
        ),
    ];
    for (summary, expected) in cases {
        assert_eq!(text_summary(&summary), expected);
    }
}

// 関門: 説明やファイルの名前に型板の名前（`{outcome}`・`{name}`）を含んでも、その部分を埋めない。
#[test]
fn template_names_inside_values_are_kept_verbatim() {
    let (table, _, name) = sources();
    let result = TestResult {
        test: test_fn(Some("shows {outcome} and {name}"), name),
        failure: Some(Failure::Error {
            message: "{message}".to_owned(),
        }),
        stdout: Vec::new(),
        stderr: Vec::new(),
    };
    assert_eq!(
        text_line("{name}.bnt", &result),
        "test {name}.bnt: \"shows {outcome} and {name}\" ... FAILED\n"
    );
    assert_eq!(
        text_failure("{name}.bnt", &result, &table, TextOptions { color: false }),
        "---- {name}.bnt: \"shows {outcome} and {name}\" ----\nreturned `Result.Error`: {message}\n"
    );
}
