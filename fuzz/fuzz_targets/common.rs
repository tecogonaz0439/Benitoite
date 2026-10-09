//! fuzzing の性質の検査を共有する（設計書 07-03「fuzzing」）。

use std::sync::Arc;

use benitoite::base::{SourceTable, Span};
use benitoite::diag::{Diagnostic, ReportKind};
use benitoite::ir::check::check_program;
use benitoite::pipeline::{self, CheckResult, CompileError};

/// 検査の診断と、指定されたときは脱糖・コード生成の性質を確かめる。
pub(crate) fn assert_properties(result: &CheckResult, check_compilation: bool) {
    assert_no_internal_reports(&result.diagnostics);
    assert_diagnostic_spans(&result.sources, &result.diagnostics);
    if !check_compilation {
        return;
    }

    if result.diagnostics.iter().any(Diagnostic::is_error) {
        return;
    }

    let Some(checked) = result.program.as_ref() else {
        panic!("誤りのない検査結果に CheckedProgram がない");
    };
    let core = pipeline::desugar_checked(checked)
        .unwrap_or_else(|error| panic!("脱糖が処理系の不具合を返した: {error:?}"));
    let core_errors = check_program(&core);
    assert!(
        core_errors.is_empty(),
        "脱糖の結果に型の付かない箇所がある: {core_errors:?}"
    );

    match pipeline::compile(&core, Arc::clone(&result.sources)) {
        Ok(_) => {}
        Err(CompileError::Limit(diagnostics)) => {
            assert_no_internal_reports(&diagnostics);
            assert_diagnostic_spans(&result.sources, &diagnostics);
        }
        Err(CompileError::Internal(error)) => {
            panic!("コード生成が処理系の不具合を返した: {error:?}");
        }
    }
}

fn assert_no_internal_reports(diagnostics: &[Diagnostic]) {
    for diagnostic in diagnostics {
        assert_ne!(
            diagnostic.kind,
            ReportKind::Internal,
            "検査段が処理系の不具合を報告した: {diagnostic:?}"
        );
    }
}

fn assert_diagnostic_spans(sources: &SourceTable, diagnostics: &[Diagnostic]) {
    for diagnostic in diagnostics {
        if let Some(primary) = diagnostic.primary.as_ref() {
            assert_span(sources, primary.span);
        }
        for secondary in &diagnostic.secondary {
            assert_span(sources, secondary.span);
        }
    }
}

fn assert_span(sources: &SourceTable, span: Span) {
    let Some(source) = sources.get(span.file) else {
        panic!("診断の span が存在しないファイルを指している: {span:?}");
    };
    let start = usize::try_from(span.start.0).unwrap_or(usize::MAX);
    let end = usize::try_from(span.end.0).unwrap_or(usize::MAX);
    assert!(
        start <= end && end <= source.text().len(),
        "診断の span がソースの範囲外である: {span:?}, ソース長 {}",
        source.text().len()
    );
}
