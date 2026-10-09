//! 診断の文章と JSON の公開の出力契約を確かめる（設計書 02-10、実装プラン F16）。
// テストの失敗は panic で表し、位置と期待値の準備には添字と算術を使う。
#![allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::tests::{check_diag, span};
use super::{TextOptions, Verb, render_check_text, render_json_line, render_one_text};
use crate::base::{FileId, Source, SourceKind, SourceTable};
use crate::diag::{
    CallTrace, DiagCode, Edit, FrameName, Help, Label, ReportKind, Severity, TraceFrame,
    WaitingTask, codes,
};

const PLAIN: TextOptions = TextOptions { color: false };

fn source(table: &mut SourceTable, name: &str, text: &str) -> FileId {
    table.add(Source::new(
        name.into(),
        SourceKind::User,
        text.as_bytes().to_vec(),
    ))
}

fn label(file: FileId, start: usize, length: usize, text: &str) -> Label {
    Label {
        span: span(file, start, length),
        text: text.into(),
    }
}

fn frame(name: &str, file: FileId, offset: Option<usize>) -> TraceFrame {
    TraceFrame {
        name: FrameName::Named(name.into()),
        call_site: offset.map(|offset| span(file, offset, 0)),
    }
}

#[test]
fn specification_type_excerpt_and_other_files() {
    let mut sources = SourceTable::new();
    let file = source(
        &mut sources,
        "count.bnt",
        "function f(x: Integer) -> Integer\nend function\n  bind n: Integer <- \"a\"\n",
    );
    let mut diag = check_diag("mismatched types");
    let bytes = sources.get(file).unwrap().text();
    let start = bytes
        .windows(3)
        .position(|bytes| bytes == b"\"a\"")
        .unwrap();
    diag.primary = Some(label(file, start, 3, "expected `Integer`, found `String`"));
    diag.secondary.push(label(file, 9, 3, "declared here"));
    diag.notes.push("...".into());
    diag.helps.push(Help {
        message: "...".into(),
        edits: vec![],
    });
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "error[E0401]: mismatched types\n",
            "  --> count.bnt:3:22\n   |\n",
            " 3 |   bind n: Integer <- \"a\"\n",
            "   |                      ^^^ expected `Integer`, found `String`\n   |\n",
            "  ::: count.bnt:1:10\n   |\n",
            " 1 | function f(x: Integer) -> Integer\n",
            "   |          --- declared here\n   |\n",
            "   = note: ...\n   = help: ...\n"
        )
    );

    for name in ["Lib/Text.bnt", "<benitoite>/List.bnt"] {
        let other = source(&mut sources, name, "function f(x: Integer) -> Integer\n");
        diag.secondary = vec![label(other, 9, 3, "declared here")];
        let expected = format!(
            concat!(
                "error[E0401]: mismatched types\n  --> count.bnt:3:22\n   |\n",
                " 3 |   bind n: Integer <- \"a\"\n",
                "   |                      ^^^ expected `Integer`, found `String`\n   |\n",
                "  ::: {}:1:10\n   |\n 1 | function f(x: Integer) -> Integer\n",
                "   |          --- declared here\n   |\n   = note: ...\n   = help: ...\n"
            ),
            name
        );
        assert_eq!(render_one_text(&diag, &sources, PLAIN), expected);
    }
}

#[test]
fn specification_uses_io_edit_and_json() {
    let mut sources = SourceTable::new();
    let file = source(
        &mut sources,
        "report.bnt",
        "\n\n\nfunction main() -> Unit uses IO\n",
    );
    let mut diag = check_diag("`IO` is a module, not an effect");
    diag.code = Some(DiagCode::E0333);
    diag.primary = Some(label(file, 32, 2, "expected an effect"));
    diag.helps.push(Help {
        message: "use `IO.All` to allow every effect in `Benitoite.IO`".into(),
        edits: vec![Edit {
            span: span(file, 32, 2),
            replacement: "IO.All".into(),
        }],
    });
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "error[E0333]: `IO` is a module, not an effect\n",
            "  --> report.bnt:4:30\n   |\n 4 | function main() -> Unit uses IO\n",
            "   |                              ^^ expected an effect\n   |\n",
            "   = help: use `IO.All` to allow every effect in `Benitoite.IO`\n   |\n",
            " 4 | function main() -> Unit uses IO.All\n   |                              ~~~~~~\n"
        )
    );
    assert_eq!(
        render_json_line(&diag, &sources),
        concat!(
            "{\"kind\":\"check\",\"severity\":\"error\",\"code\":\"E0333\",",
            "\"message\":\"`IO` is a module, not an effect\",",
            "\"primary\":{\"file\":\"report.bnt\",\"start\":{\"line\":4,\"column\":30,\"offset\":32},",
            "\"end\":{\"line\":4,\"column\":32,\"offset\":34},\"label\":\"expected an effect\"},",
            "\"secondary\":[],\"notes\":[],\"helps\":[{\"message\":",
            "\"use `IO.All` to allow every effect in `Benitoite.IO`\",\"edits\":[{",
            "\"file\":\"report.bnt\",\"start\":{\"line\":4,\"column\":30,\"offset\":32},",
            "\"end\":{\"line\":4,\"column\":32,\"offset\":34},\"replacement\":\"IO.All\"}]}]}"
        )
    );
}

#[test]
fn edit_shapes_expand_lines_mark_insertions_and_separate_helps() {
    // 同じ契約の境界（挿入・削除・改行・複数の範囲・タブ・Unicode）を表の行で確かめる。
    let cases = [
        (
            "abc",
            vec![(0, 0, "import Lib\n")],
            " 1 | import Lib\n   | ~~~~~~~~~~\n 2 | abc\n",
        ),
        ("a;b", vec![(1, 1, "")], " 1 | ab\n"),
        ("a;b", vec![(1, 1, "\n")], " 1 | a\n 2 | b\n"),
        (
            "ab\ncd\nef",
            vec![(1, 6, "X\nY")],
            " 1 | aX\n   |  ~\n 2 | Yf\n   | ~\n",
        ),
        (
            "uses IO, Integer",
            vec![(0, 0, "("), (7, 0, ")")],
            " 1 | (uses IO), Integer\n   | ~       ~\n",
        ),
        (
            "\tx",
            vec![(1, 1, "\tあ")],
            " 1 |         あ\n   |     ~~~~~\n",
        ),
        ("あx", vec![(3, 1, "日本")], " 1 | あ日本\n   |  ~~\n"),
        ("a\r\nb", vec![(0, 1, "x")], " 1 | x\n   | ~\n"),
        ("", vec![(0, 0, "x\n")], " 1 | x\n   | ~\n 2 | \n"),
    ];
    for (text, edits, rows) in cases {
        let mut sources = SourceTable::new();
        let file = source(&mut sources, "f.bnt", text);
        let mut diag = check_diag("edit");
        let column = text[..edits[0].0].chars().count() + 1;
        diag.helps.push(Help {
            message: "first".into(),
            edits: edits
                .into_iter()
                .map(|(start, len, replacement)| Edit {
                    span: span(file, start, len),
                    replacement: replacement.into(),
                })
                .collect(),
        });
        diag.helps.push(Help {
            message: "second".into(),
            edits: vec![],
        });
        assert_eq!(
            render_one_text(&diag, &sources, PLAIN),
            format!(
                "error[E0401]: edit\n   = help: first\n   |\n  ::: f.bnt:1:{column}\n   |\n{rows}   |\n   = help: second\n"
            )
        );
    }
}

#[test]
fn edits_in_other_files_are_grouped_sorted_and_use_the_largest_line_number() {
    let mut sources = SourceTable::new();
    let file = source(&mut sources, "f.bnt", "\n".repeat(98).as_str());
    let other = source(&mut sources, "Lib/Text.bnt", "ab");
    let mut diag = check_diag("edit");
    diag.primary = Some(label(file, 98, 0, ""));
    diag.helps.push(Help {
        message: "replace".into(),
        edits: vec![
            Edit {
                span: span(file, 98, 0),
                replacement: "x\ny".into(),
            },
            Edit {
                span: span(other, 1, 1),
                replacement: "B".into(),
            },
            Edit {
                span: span(other, 0, 1),
                replacement: "A".into(),
            },
        ],
    });
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "error[E0401]: edit\n   --> f.bnt:99:1\n    |\n 99 | \n    | ^\n    |\n",
            "    = help: replace\n    |\n 99 | x\n    | ~\n100 | y\n    | ~\n    |\n",
            "   ::: Lib/Text.bnt:1:1\n    |\n  1 | AB\n    | ~~\n"
        )
    );
}

#[test]
fn warnings_counts_deny_and_truncation_follow_severity() {
    let sources = SourceTable::new();
    let mut warning = check_diag("hidden name");
    warning.code = Some(DiagCode::W0301);
    warning.severity = Severity::Warning;
    assert_eq!(
        render_check_text(&[warning.clone()], &sources, Verb::Run, "main.bnt", PLAIN),
        "warning[W0301]: hidden name\n\nwarning: 1 warning emitted\n"
    );
    let error = check_diag("bad type");
    let mixed = vec![
        error.clone(),
        warning.clone(),
        error.clone(),
        warning.clone(),
        error.clone(),
    ];
    assert_eq!(
        render_check_text(&mixed, &sources, Verb::Check, "main.bnt", PLAIN),
        concat!(
            "error[E0401]: bad type\n\nwarning[W0301]: hidden name\n\n",
            "error[E0401]: bad type\n\nwarning[W0301]: hidden name\n\nerror[E0401]: bad type\n\n",
            "error: could not check main.bnt due to 3 previous errors; 2 warnings emitted\n"
        )
    );
    let mut denied = warning.clone();
    denied.deny_warning();
    assert_eq!(
        render_check_text(&[denied], &sources, Verb::Test, "main.bnt", PLAIN),
        concat!(
            "error[W0301]: hidden name\n   = note: treated as an error because of `--deny-warnings`\n\n",
            "error: could not test main.bnt due to 1 previous error\n"
        )
    );
    for (items, expected) in [
        (
            vec![warning.clone(); 51],
            format!(
                "{}warning: 1 more diagnostics not shown\n\nwarning: 51 warnings emitted\n",
                "warning[W0301]: hidden name\n\n".repeat(50)
            ),
        ),
        (
            {
                let mut items = vec![warning; 50];
                items.push(error);
                items
            },
            format!(
                "{}error: 1 more diagnostics not shown\n\nerror: could not check main.bnt due to 1 previous error; 50 warnings emitted\n",
                "warning[W0301]: hidden name\n\n".repeat(50)
            ),
        ),
    ] {
        assert_eq!(
            render_check_text(&items, &sources, Verb::Check, "main.bnt", PLAIN),
            expected
        );
    }
}

#[test]
fn specification_runtime_and_task_origins_align_together_and_keep_notes_in_order() {
    for (name, frames, origins, expected) in [
        (
            "count.bnt",
            vec![
                ("ratio", Some((22, 44))),
                ("lambda", None),
                ("List.map", Some((22, 14))),
                ("main", None),
            ],
            vec![],
            concat!(
                "runtime error[R0101]: division by zero\n  --> count.bnt:10:13\n   |\n",
                "10 |   bind q <- a div b\n   |             ^^^^^^^\n   |\n",
                "   = note: call trace (innermost first):\n",
                "             ratio                    at count.bnt:22:44\n",
                "             <lambda count.bnt:22:27>\n",
                "             List.map                 at count.bnt:22:14\n             main\n",
                "   = note: functions left by tail calls are not shown\n"
            ),
        ),
        (
            "server.bnt",
            vec![("ratio", Some((18, 9))), ("route", None)],
            vec![("Http.serve", Some((25, 10))), ("main", None)],
            concat!(
                "runtime error[R0101]: division by zero\n  --> server.bnt:10:13\n   |\n",
                "10 |   bind q <- a div b\n   |             ^^^^^^^\n   |\n",
                "   = note: call trace (innermost first):\n             ratio      at server.bnt:18:9\n             route\n",
                "   = note: in a task started by (innermost first):\n             Http.serve at server.bnt:25:10\n             main\n",
                "   = note: functions left by tail calls are not shown\n"
            ),
        ),
    ] {
        let mut sources = SourceTable::new();
        let mut lines = vec!["x".repeat(50); 25];
        lines[9] = "  bind q <- a div b".into();
        let file = source(&mut sources, name, &lines.join("\n"));
        let offset = |line: usize, col: usize| {
            lines
                .iter()
                .take(line - 1)
                .map(|line| line.len() + 1)
                .sum::<usize>()
                + col
                - 1
        };
        let make = |(name, pos): (&str, Option<(usize, usize)>)| {
            let mut value = frame(name, file, pos.map(|(line, col)| offset(line, col)));
            if name == "lambda" {
                value.name = FrameName::Lambda(span(file, offset(22, 27), 0));
            }
            value
        };
        let mut diag = check_diag("division by zero");
        diag.kind = ReportKind::Runtime;
        diag.code = Some(DiagCode::R0101);
        diag.primary = Some(label(file, offset(10, 13), 7, ""));
        diag.trace = Some(CallTrace {
            frames: frames.into_iter().map(make).collect(),
            omitted: 0,
        });
        diag.task_origins = origins.into_iter().map(make).collect();
        diag.notes
            .push("functions left by tail calls are not shown".into());
        assert_eq!(render_one_text(&diag, &sources, PLAIN), expected);
    }
}

#[test]
fn new_frame_names_and_runtime_json_have_stable_order() {
    let mut sources = SourceTable::new();
    let file = source(&mut sources, "f.bnt", "a\nb\n    c\n  d\ne\nf\ng\n    h");
    let mut diag = check_diag("failure");
    diag.kind = ReportKind::Runtime;
    diag.code = Some(DiagCode::R0101);
    diag.trace = Some(CallTrace {
        frames: vec![
            TraceFrame {
                name: FrameName::Handle(span(file, 8, 0)),
                call_site: None,
            },
            TraceFrame {
                name: FrameName::Case {
                    operation: "Log.write".into(),
                    span: span(file, 24, 0),
                },
                call_site: None,
            },
            TraceFrame {
                name: FrameName::Lazy(span(file, 12, 0)),
                call_site: None,
            },
        ],
        omitted: 0,
    });
    diag.task_origins = vec![frame("main", file, None)];
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "runtime error[R0101]: failure\n   = note: call trace (innermost first):\n",
            "             <handle f.bnt:3:5>\n             <case Log.write f.bnt:8:5>\n             <lazy f.bnt:4:3>\n",
            "   = note: in a task started by (innermost first):\n             main\n"
        )
    );
    assert_eq!(
        render_json_line(&diag, &sources),
        concat!(
            "{\"kind\":\"runtime\",\"severity\":\"error\",\"code\":\"R0101\",\"message\":\"failure\",",
            "\"primary\":null,\"secondary\":[],\"notes\":[],\"helps\":[],\"trace\":[",
            "{\"function\":\"<handle f.bnt:3:5>\",\"location\":null},",
            "{\"function\":\"<case Log.write f.bnt:8:5>\",\"location\":null},",
            "{\"function\":\"<lazy f.bnt:4:3>\",\"location\":null}],\"traceOmitted\":0,",
            "\"taskOrigins\":[{\"function\":\"main\",\"location\":null}]}"
        )
    );
}

#[test]
fn specification_deadlock_and_absent_wait_location() {
    let mut sources = SourceTable::new();
    let file = source(
        &mut sources,
        "pair.bnt",
        &vec!["x".repeat(20); 11].join("\n"),
    );
    let mut diag = check_diag("no task can proceed because tasks are waiting for each other");
    diag.kind = ReportKind::Runtime;
    diag.code = Some(DiagCode::R1001);
    diag.trace = Some(CallTrace {
        frames: vec![],
        omitted: 0,
    });
    diag.waiting = vec![
        WaitingTask {
            task: frame("main", file, None),
            waits_for: "TaskGroup release".into(),
            location: Some(span(file, 65, 0)),
        },
        WaitingTask {
            task: frame("TaskGroup.spawn", file, Some(117)),
            waits_for: "Task.await".into(),
            location: Some(span(file, 130, 0)),
        },
        WaitingTask {
            task: frame("TaskGroup.spawn", file, Some(201)),
            waits_for: "Task.await".into(),
            location: Some(span(file, 214, 0)),
        },
    ];
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "runtime error[R1001]: no task can proceed because tasks are waiting for each other\n",
            "   = note: waiting tasks:\n",
            "             main                              waits for TaskGroup release at pair.bnt:4:3\n",
            "             TaskGroup.spawn at pair.bnt:6:13  waits for Task.await        at pair.bnt:7:5\n",
            "             TaskGroup.spawn at pair.bnt:10:13 waits for Task.await        at pair.bnt:11:5\n"
        )
    );
    diag.waiting.truncate(1);
    diag.waiting[0].location = None;
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "runtime error[R1001]: no task can proceed because tasks are waiting for each other\n",
            "   = note: waiting tasks:\n             main waits for TaskGroup release\n"
        )
    );
    assert_eq!(
        render_json_line(&diag, &sources),
        concat!(
            "{\"kind\":\"runtime\",\"severity\":\"error\",\"code\":\"R1001\",",
            "\"message\":\"no task can proceed because tasks are waiting for each other\",",
            "\"primary\":null,\"secondary\":[],\"notes\":[],\"helps\":[],",
            "\"trace\":[],\"traceOmitted\":0,\"taskOrigins\":[],\"waitingTasks\":[",
            "{\"task\":{\"function\":\"main\",\"location\":null},\"waitsFor\":\"TaskGroup release\",\"location\":null}]}"
        )
    );
}

#[test]
fn specification_release_failure_and_other_report_kinds() {
    let sources = SourceTable::new();
    let mut diag = check_diag("failed to release `File.Writer` opened at count.bnt:5:8");
    diag.code = Some(DiagCode::R0401);
    diag.kind = ReportKind::Release;
    diag.notes = vec![
        "no space left on device".into(),
        "the program was exiting by `Process.exit(2)`; the exit status is not changed".into(),
    ];
    assert_eq!(
        render_one_text(&diag, &sources, PLAIN),
        concat!(
            "error[R0401]: failed to release `File.Writer` opened at count.bnt:5:8\n",
            "   = note: no space left on device\n",
            "   = note: the program was exiting by `Process.exit(2)`; the exit status is not changed\n"
        )
    );
    assert_eq!(
        render_json_line(&diag, &sources),
        concat!(
            "{\"kind\":\"release\",\"severity\":\"error\",\"code\":\"R0401\",",
            "\"message\":\"failed to release `File.Writer` opened at count.bnt:5:8\",\"primary\":null,\"secondary\":[],",
            "\"notes\":[\"no space left on device\",\"the program was exiting by `Process.exit(2)`; the exit status is not changed\"],\"helps\":[]}"
        )
    );
    for (kind, json_kind, severity) in [
        (ReportKind::Resource, "resource", "runtime error"),
        (ReportKind::Args, "args", "error"),
        (ReportKind::Limit, "limit", "error"),
    ] {
        diag.kind = kind;
        diag.message = "failure".into();
        diag.notes.clear();
        assert_eq!(
            render_one_text(&diag, &sources, PLAIN),
            format!("{severity}[R0401]: failure\n")
        );
        assert_eq!(
            render_json_line(&diag, &sources),
            format!(
                "{{\"kind\":\"{json_kind}\",\"severity\":\"error\",\"code\":\"R0401\",\"message\":\"failure\",\"primary\":null,\"secondary\":[],\"notes\":[],\"helps\":[]}}"
            )
        );
    }
}

#[test]
fn warning_and_edit_colors_follow_their_roles() {
    let mut sources = SourceTable::new();
    let file = source(&mut sources, "f.bnt", "\tx");
    let mut diag = check_diag("warning");
    diag.code = Some(DiagCode::W0301);
    diag.severity = Severity::Warning;
    diag.primary = Some(label(file, 1, 1, ""));
    diag.helps = vec![Help {
        message: "change".into(),
        edits: vec![Edit {
            span: span(file, 1, 1),
            replacement: "y".into(),
        }],
    }];
    assert_eq!(
        render_check_text(
            &[diag],
            &sources,
            Verb::Run,
            "f.bnt",
            TextOptions { color: true }
        ),
        concat!(
            "\x1b[1;33mwarning[W0301]\x1b[0m: warning\n",
            "  \x1b[1;34m-->\x1b[0m f.bnt:1:2\n   \x1b[1;34m|\x1b[0m\n",
            "\x1b[1;34m 1\x1b[0m \x1b[1;34m|\x1b[0m     x\n   \x1b[1;34m|\x1b[0m     \x1b[1;33m^\x1b[0m\n",
            "   \x1b[1;34m|\x1b[0m\n   \x1b[1;34m=\x1b[0m \x1b[1mhelp\x1b[0m: change\n",
            "   \x1b[1;34m|\x1b[0m\n\x1b[1;34m 1\x1b[0m \x1b[1;34m|\x1b[0m     y\n",
            "   \x1b[1;34m|\x1b[0m \x1b[1;34m    ~\x1b[0m\n\n\x1b[1;33mwarning\x1b[0m: 1 warning emitted\n"
        )
    );
}

#[test]
fn diagnostic_table_preserves_ids_keys_and_literal_braces() {
    let mut ids = std::collections::BTreeSet::new();
    for code in codes::ALL {
        let info = code.info();
        assert!(ids.insert(info.id));
        assert!(!codes::RETIRED.contains(&info.id));
        assert_eq!(info.id.len(), 5);
        assert!(info.id.as_bytes()[0].is_ascii_uppercase());
        assert!(info.id.as_bytes()[1..].iter().all(u8::is_ascii_digit));
        let kind = if info.id.starts_with(['E', 'W']) {
            ReportKind::Check
        } else if info.id.starts_with('L') {
            ReportKind::Limit
        } else if info.id.starts_with("R09") {
            ReportKind::Resource
        } else if info.id.starts_with("R03") {
            ReportKind::Args
        } else {
            assert!(info.id.starts_with('R'));
            ReportKind::Runtime
        };
        assert_eq!(info.kind, kind);
        assert_eq!(
            info.severity,
            if info.id.starts_with('W') {
                Severity::Warning
            } else {
                Severity::Error
            }
        );
        let keys = info
            .extras
            .iter()
            .map(|(key, _)| *key)
            .collect::<std::collections::BTreeSet<_>>();
        assert_eq!(keys.len(), info.extras.len());
        assert!(info.fixes.iter().all(|key| keys.contains(key)));
        for template in [info.message, info.label]
            .into_iter()
            .chain(info.extras.iter().map(|(_, text)| *text))
        {
            let chars = template.chars().collect::<Vec<_>>();
            let mut i = 0;
            let mut code_literal = false;
            while i < chars.len() {
                if chars[i] == '`' {
                    code_literal = !code_literal;
                }
                if chars[i] == '{' {
                    let mut end = i + 1;
                    while end < chars.len()
                        && (chars[end].is_ascii_alphanumeric() || chars[end] == '_')
                    {
                        end += 1;
                    }
                    if end > i + 1 && chars.get(end) == Some(&'}') {
                        i = end + 1;
                        continue;
                    }
                    assert!(code_literal, "{}: {template}", info.id);
                } else if chars[i] == '}' {
                    assert!(code_literal, "{}: {template}", info.id);
                }
                i += 1;
            }
        }
    }
}
