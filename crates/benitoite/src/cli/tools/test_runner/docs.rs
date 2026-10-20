//! docの同じ発見一覧を準備・許可照合・報告・実行へ渡す
//! （設計書 06-04「テストの実行」「テストの非実行の検査」「結果の報告」）。

use std::collections::BTreeSet;

use serde_json::{Value, json};

use super::*;
use crate::cli::check_report::{diagnostic_value, source_id, sources};
use crate::cli::tools::doc_examples::{DocExample, Expectation};

mod execute;
mod prepare;
use execute::execute_example;
use prepare::prepare_examples;

mod text {
    pub const EXPECTATION: &str = "expected a static error containing all diagnostic lines";
    pub const OUTPUT: &str = "documentation example output or exit status did not match";
    pub const RESULT: &str = "doc {id} ({mode}) ... {outcome}\n";
    pub const COUNTS: &str = "doc examples: {test} test; {run} run; {check} check; {error} error; {ignored} ignored blocks\n";
}

/// 検査に成功した空と未確定の情報を区別して保持する。
pub(super) struct Example {
    pub id: String,
    pub example: DocExample,
    pub checked: CheckResult,
    pub tests: Value,
    pub effects: Option<BTreeSet<String>>,
    pub accepted: bool,
    pub expectation_matched: bool,
    compiled: Option<Compiled>,
}

#[derive(Default)]
pub(super) struct Batch {
    pub examples: Vec<Example>,
    pub ignored: usize,
    pub complete: bool,
    declaration_compilations: u64,
}

fn internal(message: impl Into<String>) -> InternalError {
    InternalError {
        stage: text_stage(),
        message: message.into(),
    }
}

fn text_stage() -> &'static str {
    super::text::STAGE_TEST
}

pub(super) fn mode(expectation: &Expectation) -> &'static str {
    match expectation {
        Expectation::Test => "test",
        Expectation::Static => "check",
        Expectation::Error { .. } => "error",
        Expectation::Run { .. } => "run",
    }
}

fn executable(expectation: &Expectation) -> bool {
    matches!(expectation, Expectation::Test | Expectation::Run { .. })
}

fn location(span: Span, table: &SourceTable) -> Result<Value, InternalError> {
    serde_json::from_str(&render::json_location(span, "", table))
        .map_err(|error| internal(error.to_string()))
}

// 通常の準備と同じpanic境界を使い、ASTは段のスタックで捨てる。
pub(super) fn prepare(
    entry: &EntrySpec,
    deny_warnings: bool,
    prepare_mode: PrepareMode<'_>,
    working_directory: &Path,
) -> Result<(Prepared, Batch), Box<Diagnostic>> {
    let mut ordinary = prepare_entry(entry, deny_warnings, prepare_mode, working_directory)?;
    let result = pipeline::on_large_stack(|| {
        panic_boundary::catch(|| {
            prepare_examples(
                entry,
                &mut ordinary.result,
                deny_warnings,
                prepare_mode,
                working_directory,
            )
        })
    });
    let batch = match result {
        Ok(Ok(Ok(batch))) => batch,
        Ok(Ok(Err(error))) => {
            return Err(Box::new(runtime_report::internal_diagnostic(
                error.stage,
                &error.message,
                None,
                FaultThread::Stage,
            )));
        }
        Ok(Err(panic)) => {
            return Err(Box::new(runtime_report::internal_diagnostic(
                text_stage(),
                &panic.message,
                Some(&panic),
                FaultThread::Stage,
            )));
        }
        Err(error) => {
            return Err(Box::new(runtime_report::internal_diagnostic(
                text_stage(),
                &error.to_string(),
                None,
                FaultThread::Stage,
            )));
        }
    };
    Ok((ordinary, batch))
}

impl Example {
    pub(super) fn complete(&self) -> bool {
        self.accepted
            && (!matches!(self.example.expectation, Expectation::Error { .. })
                || self.expectation_matched)
    }

    pub(super) fn check_value(&self, target: &str, index: usize) -> Result<Value, InternalError> {
        let source_prefix = format!("{target}:d{index}");
        let observed = self
            .checked
            .diagnostics
            .iter()
            .map(|d| diagnostic_value(d, &self.checked.sources))
            .collect::<Result<Vec<_>, _>>()?;
        let internal = self
            .checked
            .diagnostics
            .iter()
            .any(|d| d.kind == crate::diag::ReportKind::Internal);
        Ok(json!({
            "id": self.id, "mode": mode(&self.example.expectation),
            "location": location(self.example.span, &self.checked.sources)?,
            "sourceId": self.checked.entry.map(|file| source_id(&source_prefix, file)),
            "status": if internal { "internalError" } else if self.complete() { "ok" } else { "checkError" },
            "complete": self.complete(),
            "effects": self.effects.as_ref().map(|expanded| json!({"basis": "declaredUpperBound", "expanded": expanded})),
            "tests": self.tests,
            "expectedDiagnosticCodes": self.example.expectation.diagnostic_codes().iter().map(|code| code.info().id).collect::<Vec<_>>(),
            "observedDiagnostics": observed,
        }))
    }

    pub(super) fn source_values(&self, target: &str, index: usize) -> Vec<Value> {
        sources(&self.checked.sources, &format!("{target}:d{index}"))
    }

    pub(super) fn execution_effects(&self) -> impl Iterator<Item = &String> {
        executable(&self.example.expectation)
            .then_some(self.effects.as_ref())
            .flatten()
            .into_iter()
            .flatten()
    }
}

// 実行は全入口の準備と上限照合を終えてから開始する。
pub(super) fn run(
    args: PathArgs,
    mut env: CliEnv,
    externals: crate::external::stats::ExecutionOptions,
) -> u8 {
    if args.report.is_some() {
        return check_report::run(args, env);
    }
    let selection = select_test_entries(&args.paths);
    let entries = match selection.completion {
        Ok(()) => selection.entries,
        Err(failure) => {
            let diagnostic = DiagBuilder::new(DiagCode::E0101)
                .arg("path", failure.path.display().to_string())
                .arg("reason", failure.error.to_string())
                .note("reason")
                .build();
            write_report(&env, args.diagnostics, &SourceTable::new(), &diagnostic);
            return EXIT_CHECK;
        }
    };
    let interrupt = match env
        .interrupt
        .take()
        .map(Ok)
        .unwrap_or_else(run::process_interrupt)
    {
        Ok(interrupt) => interrupt,
        Err(error) => {
            return write_internal(
                &env,
                args.diagnostics,
                &SourceTable::new(),
                text_stage(),
                &error.to_string(),
                None,
                FaultThread::Stage,
            );
        }
    };
    let mut externals = externals;
    externals.session = Some(Rc::new(crate::external::ExternalSession::new(
        interrupt.shared_flag(),
    )));
    let mut runner = Runner {
        env,
        format: args.diagnostics,
        max_call_stack: args.max_call_stack.unwrap_or(DEFAULT_MAX_CALL_STACK),
        deny_warnings: args.deny_warnings,
        mode: if args.check {
            PrepareMode::Inspect
        } else if let Some(allowed) = &args.allow_effects {
            PrepareMode::ExecuteLimited(allowed)
        } else {
            PrepareMode::Execute
        },
        interrupt: SharedInterrupt(Rc::new(interrupt)),
        summary: Summary::default(),
        failures: Vec::new(),
        wrote_test_line: false,
        externals,
    };
    let total = match u32::try_from(entries.len()) {
        Ok(total) => total,
        Err(_) => {
            return write_internal(
                &runner.env,
                runner.format,
                &SourceTable::new(),
                text_stage(),
                "doc entry count exceeds u32",
                None,
                FaultThread::Stage,
            );
        }
    };
    let mut ready = Vec::new();
    let mut rejected = false;
    let mut counts = Counts::default();
    for selected in entries {
        if runner.interrupt.requested() {
            return reject(runner, total, EXIT_INTERRUPTED);
        }
        let (ordinary, batch) = match prepare(
            &selected.entry,
            args.deny_warnings,
            runner.mode,
            &runner.env.working_directory,
        ) {
            Ok(prepared) => prepared,
            Err(diagnostic) => {
                write_report(&runner.env, runner.format, &SourceTable::new(), &diagnostic);
                return reject(runner, total, EXIT_INTERNAL);
            }
        };
        if let Some(stats) = &runner.externals.stats {
            stats.declarations_compiled(batch.declaration_compilations);
        }
        match runner.validate_prepared(&selected.entry, &ordinary) {
            Ok(valid) => rejected |= !valid,
            Err(code) => return reject(runner, total, code),
        }
        counts.ignored = counts.ignored.saturating_add(batch.ignored);
        for example in &batch.examples {
            counts.add(example);
            let internal = example
                .checked
                .diagnostics
                .iter()
                .any(|d| d.kind == crate::diag::ReportKind::Internal);
            if internal || prelude_error(&example.checked).is_some() {
                for diagnostic in &example.checked.diagnostics {
                    write_report(
                        &runner.env,
                        runner.format,
                        &example.checked.sources,
                        diagnostic,
                    );
                }
                return reject(runner, total, EXIT_INTERNAL);
            }
            if !example.accepted || (args.check && !example.complete()) {
                rejected = true;
                for diagnostic in &example.checked.diagnostics {
                    write_report(
                        &runner.env,
                        runner.format,
                        &example.checked.sources,
                        diagnostic,
                    );
                }
                if matches!(example.example.expectation, Expectation::Error { .. })
                    && !example.expectation_matched
                {
                    let _result = runner.env.stderr.write_bytes(
                        format!(
                            "{}: {}\n",
                            render::escape_terminal_controls(&example.id),
                            text::EXPECTATION
                        )
                        .as_bytes(),
                    );
                }
            } else if !matches!(example.example.expectation, Expectation::Error { .. }) {
                for diagnostic in &example.checked.diagnostics {
                    write_report(
                        &runner.env,
                        runner.format,
                        &example.checked.sources,
                        diagnostic,
                    );
                }
            }
        }
        ready.push((selected.entry, ordinary, batch));
    }
    if args.check {
        return if rejected {
            reject(runner, total, EXIT_CHECK)
        } else {
            runner.finish()
        };
    }
    if runner.interrupt.requested() {
        return reject(runner, total, EXIT_INTERRUPTED);
    }
    if rejected {
        return reject(runner, total, EXIT_CHECK);
    }
    for (entry, ordinary, batch) in ready {
        match runner.execute_prepared(&entry, ordinary) {
            Flow::Continue => {}
            Flow::Interrupted => {
                runner.summary.interrupted = true;
                break;
            }
            Flow::Exit(code) => return code,
        }
        for example in batch.examples {
            if runner.interrupt.requested() {
                runner.summary.interrupted = true;
                write_counts(&runner, &counts);
                return runner.finish();
            }
            match execute_example(&mut runner, example) {
                Flow::Continue => {}
                Flow::Interrupted => {
                    runner.summary.interrupted = true;
                    write_counts(&runner, &counts);
                    return runner.finish();
                }
                Flow::Exit(code) => return code,
            }
        }
    }
    write_counts(&runner, &counts);
    runner.finish()
}

#[derive(Default)]
struct Counts {
    test: usize,
    run: usize,
    check: usize,
    error: usize,
    ignored: usize,
}

impl Counts {
    fn add(&mut self, example: &Example) {
        let count = match example.example.expectation {
            Expectation::Test => &mut self.test,
            Expectation::Run { .. } => &mut self.run,
            Expectation::Static => &mut self.check,
            Expectation::Error { .. } => &mut self.error,
        };
        *count = count.saturating_add(1);
    }
}

fn write_counts(runner: &Runner<'_>, counts: &Counts) {
    let output = match runner.format {
        DiagFormat::Json => format!(
            "{}\n",
            json!({
                "kind": "docSummary", "test": counts.test, "run": counts.run,
                "check": counts.check, "error": counts.error, "ignoredBlocks": counts.ignored,
            })
        ),
        DiagFormat::Text => crate::diag::codes::fill_template(
            text::COUNTS,
            &[
                ("test", counts.test.to_string()),
                ("run", counts.run.to_string()),
                ("check", counts.check.to_string()),
                ("error", counts.error.to_string()),
                ("ignored", counts.ignored.to_string()),
            ],
        ),
    };
    let _result = runner.env.stdout.write_bytes(output.as_bytes());
}

fn reject(mut runner: Runner<'_>, count: u32, code: u8) -> u8 {
    runner.summary.files_not_run = count;
    runner.summary.interrupted = code == EXIT_INTERRUPTED;
    if runner.mode != PrepareMode::Inspect {
        runner.write_summary();
    }
    code
}
