//! 非実行の検査結果を単一の JSON にする（設計書 06-01「main の非実行の検査報告」、
//! 02-02「検査報告のソース識別」）。

use std::path::{Path, PathBuf};
use std::sync::Arc;

use serde_json::{Value, json};

use crate::base::{FileId, SourceKind, SourceTable};
use crate::diag::{Diagnostic, ReportKind, render};
use crate::ir::InternalError;
use crate::modules::EntrySpec;
use crate::pipeline::CheckResult;
use crate::runtime::panic as panic_boundary;
use crate::runtime::report::{self, FaultThread};
use crate::runtime::run::{EXIT_CHECK, EXIT_INTERNAL, EXIT_OK};

use super::inspection::{ProgramInspection, ShellReference, effect_name};
use super::{CliEnv, DevPanic, Options, build_info, pipeline, prelude_error};

// 入口とソースを報告の境界で保持し、失敗しても読み直して補わない
// （設計書 06-01「main の非実行の検査報告」）。深い AST は保持しない。
struct ReportContext<'a> {
    script: &'a Path,
    entry: Option<EntrySpec>,
    checked: CheckResult,
}

pub(super) fn source_id(target_id: &str, file: FileId) -> String {
    format!("{target_id}:s{}", file.0)
}

/// 元のソースの全バイト列を識別する。表示のための改行・UTF-8 の変換を挟まない。
pub(super) fn sources(sources: &SourceTable, target_id: &str) -> Vec<Value> {
    sources.iter().map(|(file, source)| json!({
        "sourceId": source_id(target_id, file),
        "displayPath": source.name(),
        "kind": match source.kind() { SourceKind::User => "user", SourceKind::Prelude => "prelude" },
        "contentHash": super::content_hash::value(source.text())
    })).collect()
}

/// 既存の renderer を使い、診断の二つ目の形式を作らない。
pub(super) fn diagnostic_value(
    diag: &Diagnostic,
    sources: &SourceTable,
) -> Result<Value, InternalError> {
    serde_json::from_str(&render::render_json_line(diag, sources)).map_err(|error| InternalError {
        stage: "check",
        message: format!("invalid rendered diagnostic JSON: {error}"),
    })
}

fn main_value(
    inspection: &ProgramInspection,
    sources: &SourceTable,
) -> Result<Value, InternalError> {
    let main = inspection.main.as_ref().ok_or_else(|| InternalError {
        stage: "check",
        message: "main contract missing from successful inspection".into(),
    })?;
    if sources.get(main.location.file).is_none() {
        return Err(InternalError {
            stage: "check",
            message: "main location source missing".into(),
        });
    }
    let location: Value = serde_json::from_str(&render::json_location(main.location, "", sources))
        .map_err(|error| InternalError {
            stage: "check",
            message: format!("invalid rendered location JSON: {error}"),
        })?;
    let expanded = main
        .effects
        .iter()
        .map(|id| effect_name(*id))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(json!({
        "symbol": main.name, "location": location,
        "effects": { "basis": "declaredUpperBound", "expanded": expanded },
        "processShellReference": match inspection.process_shell_reference {
            ShellReference::Present => "present", ShellReference::Absent => "absent",
            ShellReference::Unknown => "unknown",
        },
        "shellReferenceScope": "checkedProgram"
    }))
}

fn value(
    context: &ReportContext<'_>,
    inspection: Option<Result<ProgramInspection, InternalError>>,
) -> Result<(Value, u8), InternalError> {
    let checked = &context.checked;
    let prelude_failure = prelude_error(checked).map(|error| {
        render::render_one_text(
            error,
            &checked.sources,
            render::TextOptions { color: false },
        )
    });
    let mut diagnostics = checked.diagnostics.clone();
    let mut main = Value::Null;
    let mut status = "checkError";
    let mut code = EXIT_CHECK;
    if let Some(message) = prelude_failure {
        diagnostics = vec![report::internal_diagnostic(
            "check",
            &message,
            None,
            FaultThread::Stage,
        )];
    }
    if diagnostics
        .iter()
        .any(|diag| diag.kind == ReportKind::Internal)
    {
        status = "internalError";
        code = EXIT_INTERNAL;
    } else if !diagnostics.iter().any(Diagnostic::is_error) {
        let inspected = inspection
            .ok_or_else(|| InternalError {
                stage: "check",
                message: "inspection result missing".into(),
            })
            .and_then(|inspection| inspection)
            .and_then(|inspection| main_value(&inspection, &checked.sources));
        match inspected {
            Ok(value) => {
                main = value;
                status = "ok";
                code = EXIT_OK;
            }
            Err(error) => {
                diagnostics.push(report::internal_diagnostic(
                    error.stage,
                    &error.message,
                    None,
                    FaultThread::Stage,
                ));
                status = "internalError";
                code = EXIT_INTERNAL;
            }
        }
    }
    let diagnostics = diagnostics
        .iter()
        .map(|diag| diagnostic_value(diag, &checked.sources))
        .collect::<Result<Vec<_>, _>>()?;
    let sources = sources(&checked.sources, "t0");
    let source_ids = checked
        .sources
        .iter()
        .map(|(file, _)| source_id("t0", file))
        .collect::<Vec<_>>();
    let diagnostic_targets = diagnostics
        .iter()
        .enumerate()
        .map(|(index, _)| {
            json!({ "diagnosticIndex": index,
            "targetId": context.entry.as_ref().map(|_| "t0") })
        })
        .collect::<Vec<_>>();
    let aggregate = main.get("effects").cloned().unwrap_or(Value::Null);
    let targets = context.entry.iter().map(|entry| json!({
        "targetId": "t0", "requestIndex": 0, "entry": entry.display_name,
        "root": entry.root.display().to_string(), "sourceId": checked.entry.map(|file| source_id("t0", file)),
        "kind": "main", "status": status, "complete": code == EXIT_OK, "main": main
    })).collect::<Vec<_>>();
    let source_sets = context
        .entry
        .iter()
        .map(|_| {
            json!({
                "targetId": "t0", "sourceIds": source_ids
            })
        })
        .collect::<Vec<_>>();
    Ok((
        json!({
            "schemaVersion": 1, "kind": "checkReport", "producer": build_info::producer(),
            "status": status, "complete": code == EXIT_OK, "targetsComplete": context.entry.is_some(), "executed": false,
            "requestedTargets": [{ "requestIndex": 0, "path": context.script.display().to_string() }],
            "targets": targets,
            "sources": sources, "sourceSets": source_sets,
            "aggregateEffects": aggregate, "diagnostics": diagnostics, "diagnosticTargets": diagnostic_targets
        }),
        code,
    ))
}

/// 入口を確定できない使い方の誤りも、認識済みの報告の共通欄で返す。
pub(super) fn usage_error(env: &CliEnv, script: Option<&Path>, detail: &str) -> u8 {
    let value = usage_value(script, detail);
    write_message(env, &format!("{value}\n"), EXIT_CHECK)
}

fn usage_value(script: Option<&Path>, detail: &str) -> Value {
    let requested_targets = script
        .map(|path| json!({ "requestIndex": 0, "path": path.display().to_string() }))
        .into_iter()
        .collect::<Vec<_>>();
    // kind:check・code:null は報告内の使い方の誤りだけに用いる。
    // 既存の診断ストリームへは追加しない（設計書 02-10「JSON の形式」）。
    json!({
        "schemaVersion": 1, "kind": "checkReport", "producer": build_info::producer(),
        "status": "usageError", "complete": false, "targetsComplete": false, "executed": false,
        "requestedTargets": requested_targets, "targets": [], "sources": [], "sourceSets": [],
        "aggregateEffects": null,
        "diagnostics": [{ "kind": "check", "severity": "error", "code": null,
            "message": detail, "primary": null, "secondary": [], "notes": [], "helps": [] }],
        "diagnosticTargets": [{ "diagnosticIndex": 0, "targetId": null }]
    })
}

fn write_message(env: &CliEnv, message: &str, code: u8) -> u8 {
    let written = super::write_plain(&env.stdout, message);
    if written == EXIT_OK { code } else { written }
}

fn prepare_value(
    context: &mut ReportContext<'_>,
    options: &Options,
    dev_panic: DevPanic,
) -> Result<(Value, u8), Box<Diagnostic>> {
    let entry = match pipeline::entry_spec(context.script) {
        Ok(entry) => entry,
        Err(pipeline::EntryError::NoMainFile { dir }) => {
            return Ok((
                usage_value(
                    Some(context.script),
                    &super::text::NO_MAIN_FILE.replace("{dir}", &dir.display().to_string()),
                ),
                EXIT_CHECK,
            ));
        }
    };
    context.entry = Some(entry);
    let entry = context.entry.as_ref().ok_or_else(|| {
        Box::new(report::internal_diagnostic(
            "check",
            "selected entry missing",
            None,
            FaultThread::Main,
        ))
    })?;
    let prepared =
        super::prepare_script(entry, options.deny_warnings, false, true, None, dev_panic)?;
    context.checked = prepared.checked;
    value(context, prepared.inspection).map_err(|error| {
        Box::new(report::internal_diagnostic(
            error.stage,
            &error.message,
            None,
            FaultThread::Main,
        ))
    })
}

/// main を必須として一度検査し、利用者の関数を実行せずに報告する。
pub(super) fn run_check(options: Options, script: PathBuf, env: CliEnv) -> u8 {
    let mut context = ReportContext {
        script: &script,
        entry: None,
        checked: CheckResult {
            sources: Arc::new(SourceTable::new()),
            entry: None,
            diagnostics: Vec::new(),
            program: None,
        },
    };
    // JSON の直列化までを捕捉し、書き始めた後は再報告しない。部分的な出力に
    // 二つ目の JSON を継ぎ足さないためである（設計書 06-01「main の非実行の検査報告」）。
    let response = panic_boundary::catch(|| {
        prepare_value(&mut context, &options, env.dev_panic)
            .map(|(value, code)| (format!("{value}\n"), code))
    });
    let result = match response {
        Ok(Ok(response)) => Ok(response),
        Ok(Err(diagnostic)) => Err(diagnostic),
        Err(panic) => Err(Box::new(report::internal_diagnostic(
            "check",
            &panic.message,
            Some(&panic),
            FaultThread::Main,
        ))),
    };
    let (message, code) = match result {
        Ok(response) => response,
        Err(diagnostic) => {
            // 失敗した組立の途中の診断は再利用せず、確定した入口とソースだけを残す。
            context.checked.diagnostics = vec![*diagnostic];
            match value(&context, None) {
                Ok((value, code)) => (format!("{value}\n"), code),
                Err(error) => {
                    return super::write_internal(
                        &env,
                        options.diagnostics,
                        &context.checked.sources,
                        error.stage,
                        &error.message,
                        None,
                        FaultThread::Main,
                    );
                }
            }
        }
    };
    write_message(&env, &message, code)
}
