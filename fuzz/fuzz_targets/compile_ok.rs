//! 検査を通ったスクリプトの脱糖とコード生成を確かめる（設計書 07-03「fuzzing」）。
#![no_main]

use std::sync::Arc;

use benitoite::base::{SourceTable, Span};
use benitoite::diag::{Diagnostic, ReportKind};
use benitoite::ir::check::check_program;
use benitoite::pipeline::{self, CompileError};
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let result = pipeline::check_text("fuzz-compile.bnt", data);
    assert_no_internal_reports(&result.diagnostics);
    assert_diagnostic_spans(&result.sources, &result.diagnostics);

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
});

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
