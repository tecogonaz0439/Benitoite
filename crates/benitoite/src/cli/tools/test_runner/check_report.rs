//! テスト入口の検査と部分結果を単一 JSON へまとめる（設計書 06-04「テストの非実行の検査」、
//! 06-01「テストの非実行の検査報告」）。

use std::collections::BTreeSet;
use std::path::PathBuf;

use serde_json::{Value, json};

use super::*;
use crate::cli::check_report::{diagnostic_value, source_id, sources};
use crate::cli::inspection::{ShellReference, effect_name};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Status {
    Ok,
    CheckError,
    InternalError,
    Interrupted,
}

impl Status {
    fn as_str(self) -> &'static str {
        match self {
            Self::Ok => "ok",
            Self::CheckError => "checkError",
            Self::InternalError => "internalError",
            Self::Interrupted => "interrupted",
        }
    }

    fn exit(self) -> u8 {
        match self {
            Self::Ok => EXIT_OK,
            Self::CheckError => EXIT_CHECK,
            Self::InternalError => EXIT_INTERNAL,
            Self::Interrupted => EXIT_INTERRUPTED,
        }
    }
}

struct Target {
    selected: SelectedEntry,
    source_id: Option<String>,
    source_ids: Vec<String>,
    sources: Vec<Value>,
    diagnostics: Vec<Value>,
    tests: Value,
    shell: ShellReference,
    status: Option<Status>,
    effects: BTreeSet<String>,
    docs: Option<docs::Batch>,
}

struct Context<'a> {
    paths: &'a [PathBuf],
    targets: Vec<Target>,
    targets_complete: bool,
    diagnostics: Vec<Diagnostic>,
    status: Status,
    active: Option<usize>,
    doc: bool,
}

fn report_error(error: InternalError) -> Box<Diagnostic> {
    Box::new(runtime_report::internal_diagnostic(
        error.stage,
        &error.message,
        None,
        FaultThread::Stage,
    ))
}

fn requested(paths: &[PathBuf]) -> Vec<Value> {
    paths
        .iter()
        .enumerate()
        .map(|(index, path)| {
            json!({
                "requestIndex": index, "path": path.display().to_string()
            })
        })
        .collect()
}

/// 認識済みの test の報告モードで使い方の誤りを返す。
pub(in crate::cli::tools) fn usage_error(
    env: &CliEnv,
    paths: &[PathBuf],
    detail: &str,
    doc: bool,
) -> u8 {
    let value = json!({
        "schemaVersion": if doc { 2 } else { 1 }, "kind": "testCheckReport", "producer": crate::cli::build_info::producer(),
        "status": "usageError", "complete": false, "targetsComplete": false, "executed": false,
        "requestedTargets": requested(paths), "targets": [], "sources": [], "sourceSets": [],
        "aggregateEffects": null,
        "diagnostics": [{ "kind": "check", "severity": "error", "code": null, "message": detail,
            "primary": null, "secondary": [], "notes": [], "helps": [] }],
        "diagnosticTargets": [{ "diagnosticIndex": 0, "targetId": null }]
    });
    write(env, &format!("{value}\n"), EXIT_CHECK)
}

fn internal(message: &str) -> InternalError {
    InternalError {
        stage: text::STAGE_TEST,
        message: message.into(),
    }
}

pub(super) fn inspect_value(
    inspected: TestInspection,
    checked: &CheckResult,
) -> Result<(Value, ShellReference, BTreeSet<String>), InternalError> {
    let TestInspection {
        program: inspection,
        tests: selected,
    } = inspected;
    let mut tests = Vec::new();
    let mut aggregate = BTreeSet::new();
    if inspection.tests.len() != selected.len() {
        return Err(internal("test contract count differs from selected tests"));
    }
    for (contract, test) in inspection.tests.into_iter().zip(selected) {
        // 束縛と位置を持つ契約だけを報告し、欠落をテストなしに補わない。
        if contract.binding != test.binding || checked.sources.get(contract.location.file).is_none()
        {
            return Err(internal(
                "test contract binding differs or test location source missing",
            ));
        }
        let location: Value = serde_json::from_str(&render::json_location(
            contract.location,
            "",
            &checked.sources,
        ))
        .map_err(|error| internal(&format!("invalid test location JSON: {error}")))?;
        let effects = contract
            .effects
            .into_iter()
            .map(effect_name)
            .collect::<Result<Vec<_>, _>>()?;
        aggregate.extend(effects.iter().cloned());
        tests.push(json!({ "function": contract.name, "description": test.description, "location": location,
            "effects": { "basis": "declaredUpperBound", "expanded": effects } }));
    }
    Ok((
        Value::Array(tests),
        inspection.process_shell_reference,
        aggregate,
    ))
}

fn diagnose(context: &mut Context<'_>, diagnostic: Diagnostic) -> Result<(), InternalError> {
    context.status = Status::InternalError;
    if let Some(target) = context
        .active
        .and_then(|index| context.targets.get_mut(index))
    {
        target.status = Some(Status::InternalError);
        target.tests = Value::Null;
        target.shell = ShellReference::Unknown;
        target
            .diagnostics
            .push(diagnostic_value(&diagnostic, &SourceTable::new())?);
    } else {
        context.diagnostics.push(diagnostic);
    }
    Ok(())
}

fn prepare_all(
    context: &mut Context<'_>,
    args: &PathArgs,
    env: &mut CliEnv,
) -> Result<(), Box<Diagnostic>> {
    let selection = select_test_entries(&args.paths);
    context.targets_complete = selection.completion.is_ok();
    context.targets = selection
        .entries
        .into_iter()
        .map(|selected| Target {
            selected,
            source_id: None,
            source_ids: Vec::new(),
            sources: Vec::new(),
            diagnostics: Vec::new(),
            tests: Value::Null,
            shell: ShellReference::Unknown,
            status: None,
            effects: BTreeSet::new(),
            docs: None,
        })
        .collect();
    if let Err(failure) = selection.completion {
        // 指定番号も探索結果の一部として照合する。失敗したディレクトリ内の部分一覧は作らない。
        if context.paths.get(failure.request_index).is_none() {
            return Err(Box::new(runtime_report::internal_diagnostic(
                text::STAGE_TEST,
                "selection failure request missing",
                None,
                FaultThread::Main,
            )));
        }
        context.diagnostics.push(
            DiagBuilder::new(DiagCode::E0101)
                .arg("path", failure.path.display().to_string())
                .arg("reason", failure.error.to_string())
                .note("reason")
                .build(),
        );
        context.status = Status::CheckError;
        for target in &mut context.targets {
            target.status = Some(Status::CheckError);
        }
        return Ok(());
    }
    let interrupt = match env.interrupt.take() {
        Some(interrupt) => interrupt,
        None => run::process_interrupt().map_err(|error| {
            Box::new(runtime_report::internal_diagnostic(
                text::STAGE_TEST,
                &error.to_string(),
                None,
                FaultThread::Main,
            ))
        })?,
    };
    context.status = Status::Ok;
    for (index, target) in context.targets.iter_mut().enumerate() {
        context.active = Some(index);
        // 通常の test と同じ、各ファイルを始める前の確認点だけを使う。
        if interrupt.requested() {
            context.status = Status::Interrupted;
            break;
        }
        let prepared = if args.doc {
            let (prepared, batch) = docs::prepare(
                &target.selected.entry,
                args.deny_warnings,
                PrepareMode::Inspect,
                &env.working_directory,
            )?;
            target.docs = Some(batch);
            prepared
        } else {
            prepare_entry(
                &target.selected.entry,
                args.deny_warnings,
                PrepareMode::Inspect,
                &env.working_directory,
            )?
        };
        let mut checked = prepared.result;
        if let Some(error) = prelude_error(&checked) {
            let message =
                render::render_one_text(error, &checked.sources, TextOptions { color: false });
            checked.diagnostics = vec![runtime_report::internal_diagnostic(
                "check",
                &message,
                None,
                FaultThread::Stage,
            )];
        }
        // ソース本文と行表はこの入口だけが所有し、次の入口へ進む前に捨てる。
        // 部分結果には識別情報と描画済みの診断だけを残す（設計書 06-01「テストの非実行の検査報告」）。
        let id = format!("t{index}");
        target.source_id = checked.entry.map(|file| source_id(&id, file));
        target.source_ids = checked
            .sources
            .iter()
            .map(|(file, _)| source_id(&id, file))
            .collect();
        target.sources = sources(&checked.sources, &id);
        target.diagnostics = checked
            .diagnostics
            .iter()
            .map(|diagnostic| diagnostic_value(diagnostic, &checked.sources))
            .collect::<Result<_, _>>()
            .map_err(report_error)?;
        if checked
            .diagnostics
            .iter()
            .any(|diag| diag.kind == crate::diag::ReportKind::Internal)
        {
            target.status = Some(Status::InternalError);
            context.status = Status::InternalError;
            break;
        }
        if checked.diagnostics.iter().any(Diagnostic::is_error) {
            target.status = Some(Status::CheckError);
            context.status = Status::CheckError;
            continue;
        }
        let inspection = prepared
            .inspection
            .ok_or_else(|| {
                Box::new(runtime_report::internal_diagnostic(
                    text::STAGE_TEST,
                    "inspection result missing",
                    None,
                    FaultThread::Stage,
                ))
            })?
            .map_err(report_error)?;
        let (tests, shell, effects) = inspect_value(inspection, &checked).map_err(report_error)?;
        target.tests = tests;
        target.shell = shell;
        target.effects = effects;
        target.status = Some(Status::Ok);
        if let Some(batch) = &target.docs {
            for example in &batch.examples {
                target.effects.extend(example.execution_effects().cloned());
                if !example.complete() {
                    let status = if example
                        .checked
                        .diagnostics
                        .iter()
                        .any(|d| d.kind == crate::diag::ReportKind::Internal)
                    {
                        Status::InternalError
                    } else {
                        Status::CheckError
                    };
                    target.status = Some(status);
                    context.status = status;
                    if status == Status::InternalError {
                        break;
                    }
                }
            }
        }
        if context.status == Status::InternalError {
            break;
        }
    }
    context.active = None;
    Ok(())
}

fn value(context: &Context<'_>) -> Result<Value, InternalError> {
    let mut targets = Vec::new();
    let mut all_sources = Vec::new();
    let mut source_sets = Vec::new();
    let mut diagnostics = Vec::new();
    let mut diagnostic_targets = Vec::new();
    let mut aggregate = BTreeSet::new();
    for (index, target) in context.targets.iter().enumerate() {
        let id = format!("t{index}");
        let status = target.status.unwrap_or(context.status);
        let shell = match target.shell {
            ShellReference::Present => "present",
            ShellReference::Absent => "absent",
            ShellReference::Unknown => "unknown",
        };
        targets.push(json!({
            "targetId": id, "requestIndex": target.selected.request_index,
            "entry": target.selected.entry.display_name, "root": target.selected.entry.root.display().to_string(),
            "sourceId": target.source_id, "kind": "tests",
            "status": status.as_str(), "complete": target.status == Some(Status::Ok), "tests": target.tests,
            "processShellReference": shell, "shellReferenceScope": "checkedProgram"
        }));
        all_sources.extend(target.sources.iter().cloned());
        let mut ids = target.source_ids.clone();
        if context.doc
            && let Some(target_value) = targets.last_mut()
        {
            target_value["docExamples"] = Value::Null;
            target_value["ignoredDocBlocks"] = Value::Null;
        }
        if let Some(batch) = &target.docs {
            let mut examples = Vec::new();
            for (doc_index, example) in batch.examples.iter().enumerate() {
                examples.push(example.check_value(&id, doc_index)?);
                let doc_sources = example.source_values(&id, doc_index);
                ids.extend(
                    doc_sources
                        .iter()
                        .filter_map(|source| source["sourceId"].as_str().map(str::to_owned)),
                );
                all_sources.extend(doc_sources);
                if !matches!(
                    example.example.expectation,
                    super::super::doc_examples::Expectation::Error { .. }
                ) {
                    for diagnostic in &example.checked.diagnostics {
                        diagnostic_targets.push(json!({"diagnosticIndex": diagnostics.len(), "targetId": id, "docExampleId": example.id}));
                        diagnostics.push(diagnostic_value(diagnostic, &example.checked.sources)?);
                    }
                }
            }
            if let Some(target_value) = targets.last_mut()
                && batch.complete
            {
                target_value["docExamples"] = Value::Array(examples);
                target_value["ignoredDocBlocks"] = json!(batch.ignored);
            }
        }
        source_sets.push(json!({ "targetId": id, "sourceIds": ids }));
        for diagnostic in &target.diagnostics {
            diagnostic_targets.push(json!({"diagnosticIndex": diagnostics.len(), "targetId": id}));
            diagnostics.push(diagnostic.clone());
        }
        aggregate.extend(target.effects.iter().cloned());
    }
    for diagnostic in &context.diagnostics {
        diagnostic_targets.push(json!({"diagnosticIndex": diagnostics.len(), "targetId": null}));
        diagnostics.push(diagnostic_value(diagnostic, &SourceTable::new())?);
    }
    Ok(json!({
        "schemaVersion": if context.doc { 2 } else { 1 }, "kind": "testCheckReport", "producer": crate::cli::build_info::producer(),
        "status": context.status.as_str(), "complete": context.status == Status::Ok, "targetsComplete": context.targets_complete, "executed": false,
        "requestedTargets": requested(context.paths), "targets": targets, "sources": all_sources, "sourceSets": source_sets,
        "aggregateEffects": if context.status == Status::Ok { json!({"basis": "declaredUpperBound", "expanded": aggregate}) } else { Value::Null },
        "diagnostics": diagnostics, "diagnosticTargets": diagnostic_targets
    }))
}

fn write(env: &CliEnv, message: &str, code: u8) -> u8 {
    let written = crate::cli::write_plain(&env.stdout, message);
    if written == EXIT_OK { code } else { written }
}

/// 一回の探索と非実行の準備から、部分結果を保持して単一報告を返す。
pub(super) fn run(args: PathArgs, mut env: CliEnv) -> u8 {
    let mut context = Context {
        paths: &args.paths,
        targets: Vec::new(),
        targets_complete: false,
        diagnostics: Vec::new(),
        status: Status::InternalError,
        active: None,
        doc: args.doc,
    };
    let response = panic_boundary::catch(|| {
        if env.dev_panic == crate::cli::DevPanic::Tool {
            crate::cli::development_tool_panic();
        }
        prepare_all(&mut context, &args, &mut env)?;
        value(&context)
            .map(|value| format!("{value}\n"))
            .map_err(|error| {
                Box::new(runtime_report::internal_diagnostic(
                    error.stage,
                    &error.message,
                    None,
                    FaultThread::Main,
                ))
            })
    });
    let result = match response {
        Ok(result) => result,
        Err(panic) => Err(Box::new(runtime_report::internal_diagnostic(
            text::STAGE_TEST,
            &panic.message,
            Some(&panic),
            FaultThread::Main,
        ))),
    };
    let message = match result {
        Ok(message) => message,
        Err(diagnostic) => {
            match diagnose(&mut context, *diagnostic).and_then(|()| value(&context)) {
                Ok(value) => format!("{value}\n"),
                Err(error) => {
                    return write_internal(
                        &env,
                        args.diagnostics,
                        &SourceTable::new(),
                        error.stage,
                        &error.message,
                        None,
                        FaultThread::Main,
                    );
                }
            }
        }
    };
    write(&env, &message, context.status.exit())
}
