//! 準備したdoc一例を実行し、元コメントの位置で結果を報告する
//! （設計書 06-04「docの例」「結果の報告」）。

use super::*;

fn map_result(example: &Example, result: &mut TestResult) {
    let Some(file) = example.checked.entry else {
        return;
    };
    let map = &example.example.source_map;
    result.test.location = map.map_span(file, result.test.location);
    match &mut result.failure {
        Some(Failure::Assert {
            primary,
            trace,
            task_origins,
            ..
        }) => {
            let mut diagnostic = DiagBuilder::new(DiagCode::R0101).build();
            diagnostic.primary = primary.map(|span| crate::diag::Label {
                span,
                text: String::new(),
            });
            diagnostic.trace = Some(trace.clone());
            diagnostic.task_origins = task_origins.clone();
            map.map_diagnostic(file, &mut diagnostic);
            *primary = diagnostic.primary.map(|label| label.span);
            if let Some(mapped) = diagnostic.trace {
                *trace = mapped
            }
            *task_origins = diagnostic.task_origins;
        }
        Some(Failure::Runtime { report }) => map.map_diagnostic(file, report),
        Some(Failure::Exit { reports, .. }) => {
            for diagnostic in reports {
                map.map_diagnostic(file, diagnostic);
            }
        }
        Some(Failure::Error { .. }) | None => {}
    }
}

pub(super) fn execute_example(runner: &mut Runner<'_>, mut example: Example) -> Flow {
    let mut tests = Vec::new();
    let mut stdout = Vec::new();
    let mut stderr = Vec::new();
    let mut failure = None;
    match &example.example.expectation {
        Expectation::Static => {}
        Expectation::Error { .. } => {
            if !example.expectation_matched {
                let observed = example
                    .checked
                    .diagnostics
                    .iter()
                    .map(|d| diagnostic_value(d, &example.checked.sources))
                    .collect::<Result<Vec<_>, _>>();
                let observed = match observed {
                    Ok(observed) => observed,
                    Err(error) => {
                        return runner.internal(
                            &example.checked.sources,
                            error.stage,
                            &error.message,
                        );
                    }
                };
                let expected = match &example.example.expectation {
                    Expectation::Error { lines } => lines.clone(),
                    Expectation::Static | Expectation::Test | Expectation::Run { .. } => Vec::new(),
                };
                failure = Some(
                    json!({"reason": "diagnosticMismatch", "message": text::EXPECTATION,
                    "expected": expected, "observedDiagnostics": observed}),
                );
            }
        }
        Expectation::Test => {
            let Some(mut compiled) = example.compiled.take() else {
                return runner.internal(
                    &example.checked.sources,
                    text_stage(),
                    "doc test compilation missing",
                );
            };
            for PreparedTest { test, proto } in std::mem::take(&mut compiled.tests) {
                if runner.interrupt.requested() {
                    return Flow::Interrupted;
                }
                let mut result =
                    match runner.execute_test(&compiled, test, proto, &example.checked.sources) {
                        Ok(result) => result,
                        Err(flow) => return flow,
                    };
                map_result(&example, &mut result);
                stdout.extend_from_slice(&result.stdout);
                stderr.extend_from_slice(&result.stderr);
                let value: Value = match serde_json::from_str(&report::json_test(
                    &example.id,
                    &result,
                    &example.checked.sources,
                )) {
                    Ok(value) => value,
                    Err(error) => {
                        return runner.internal(
                            &example.checked.sources,
                            text_stage(),
                            &error.to_string(),
                        );
                    }
                };
                if result.failure.is_some() {
                    failure = Some(json!({"reason": "testFailure"}));
                    if runner.format == DiagFormat::Text {
                        runner.failures.push(report::text_failure(
                            &example.id,
                            &result,
                            &example.checked.sources,
                            runner.stdout_options(),
                        ));
                    }
                }
                tests.push(value);
            }
        }
        Expectation::Run {
            stdout: expected_stdout,
            stderr: expected_stderr,
            exit,
        } => {
            let Some(compiled) = example.compiled.take() else {
                return runner.internal(
                    &example.checked.sources,
                    text_stage(),
                    "doc main compilation missing",
                );
            };
            let out = Arc::new(Mutex::new(Vec::new()));
            let err = Arc::new(Mutex::new(Vec::new()));
            let mut end = run::run_program_with_externals(
                &compiled.program,
                RunEnv {
                    input: compiled.input,
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(Arc::clone(&out)),
                    stderr: OutputTarget::Capture(Arc::clone(&err)),
                    interrupt: Box::new(runner.interrupt.clone()),
                    parts: None,
                    mode: runner.env.mode,
                    heap: runner.env.heap,
                    vm: crate::vm::VmConfig {
                        max_call_stack_bytes: runner.max_call_stack,
                        ..Default::default()
                    },
                    dev_panic_after_first_write: false,
                },
                runner.externals.clone(),
            );
            if let Some(file) = example.checked.entry {
                for diagnostic in &mut end.reports {
                    example.example.source_map.map_diagnostic(file, diagnostic);
                }
            }
            if matches!(end.end, EndKind::Interrupted | EndKind::Internal) {
                for diagnostic in &end.reports {
                    write_report(
                        &runner.env,
                        runner.format,
                        &example.checked.sources,
                        diagnostic,
                    );
                }
                return if end.end == EndKind::Interrupted {
                    Flow::Interrupted
                } else {
                    Flow::Exit(EXIT_INTERNAL)
                };
            }
            stdout = take_bytes(&out);
            stderr = take_bytes(&err);
            if end.exit_code != *exit
                || stdout != expected_stdout.as_bytes()
                || stderr != expected_stderr.as_bytes()
            {
                let diagnostics = end
                    .reports
                    .iter()
                    .map(|d| diagnostic_value(d, &example.checked.sources))
                    .collect::<Result<Vec<_>, _>>();
                let diagnostics = match diagnostics {
                    Ok(diagnostics) => diagnostics,
                    Err(error) => {
                        return runner.internal(
                            &example.checked.sources,
                            error.stage,
                            &error.message,
                        );
                    }
                };
                failure = Some(json!({"reason": "outputMismatch", "message": text::OUTPUT,
                    "expectedStdout": expected_stdout, "expectedStderr": expected_stderr,
                    "exit": end.exit_code, "mainError": end.main_error, "diagnostics": diagnostics}));
            }
        }
    }
    let failed = failure.is_some();
    let count = if failed {
        &mut runner.summary.failed
    } else {
        &mut runner.summary.passed
    };
    let Some(next) = count.checked_add(1) else {
        return runner.internal(
            &example.checked.sources,
            text_stage(),
            "doc count exceeds u32",
        );
    };
    *count = next;
    let location = match location(example.example.span, &example.checked.sources) {
        Ok(value) => value,
        Err(error) => {
            return runner.internal(&example.checked.sources, error.stage, &error.message);
        }
    };
    let value = json!({
        "kind": "docExample", "id": example.id, "mode": mode(&example.example.expectation),
        "location": location, "outcome": if failed { "failed" } else { "ok" },
        "stdout": String::from_utf8_lossy(&stdout), "stderr": String::from_utf8_lossy(&stderr),
        "failure": failure, "tests": tests,
    });
    let output = match runner.format {
        DiagFormat::Json => format!("{value}\n"),
        DiagFormat::Text => {
            if failed {
                runner.failures.push(format!(
                    "{}\n{}\n",
                    render::escape_terminal_controls(&example.id),
                    value
                ));
            }
            crate::diag::codes::fill_template(
                text::RESULT,
                &[
                    ("id", render::escape_terminal_controls(&example.id)),
                    ("mode", mode(&example.example.expectation).into()),
                    (
                        "outcome",
                        if failed {
                            super::super::text::OUTCOME_FAILED
                        } else {
                            super::super::text::OUTCOME_OK
                        }
                        .into(),
                    ),
                ],
            )
        }
    };
    runner.wrote_test_line = true;
    let _result = runner.env.stdout.write_bytes(output.as_bytes());
    Flow::Continue
}
