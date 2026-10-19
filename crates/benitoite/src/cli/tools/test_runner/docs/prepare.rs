//! 検査済みの元本文からdocを抽出し、独立した入口の準備を行う
//! （設計書 06-04「docの例」）。

use super::*;
use crate::base::{IdGen, Source, SourceKind};
use crate::cli::inspection::main_contract;
use crate::cli::tools::doc_examples::{self, VirtualInput};
use crate::syntax::{lexer, newline, parser};

pub(super) fn prepare_examples(
    entry: &EntrySpec,
    ordinary: &mut CheckResult,
    deny_warnings: bool,
    prepare_mode: PrepareMode<'_>,
    working_directory: &Path,
) -> Result<Batch, InternalError> {
    let Some(file) = ordinary.entry else {
        return Ok(Batch::default());
    };
    let source = ordinary
        .sources
        .get(file)
        .ok_or_else(|| internal("entry source missing"))?;
    // 検査した本文だけから抽出する。型検査の失敗でもdocの形式不良を報告できる。
    let lexed = lexer::lex(file, source.text());
    let module = parser::parse(
        file,
        SourceKind::User,
        source.text(),
        newline::resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut IdGen::default(),
    )
    .module;
    let extraction = match doc_examples::extract(&module) {
        Ok(extraction) => extraction,
        Err(errors) => {
            ordinary.diagnostics.extend(errors);
            return Ok(Batch::default());
        }
    };
    let mut header = Vec::new();
    for item in &module.header {
        let span = match item {
            crate::syntax::ast::HeaderItem::Language(declaration) => declaration.span,
            crate::syntax::ast::HeaderItem::Dependency(block) => block.span,
            crate::syntax::ast::HeaderItem::Package(_) => continue,
        };
        let start = usize::try_from(span.start.0).map_err(|error| internal(error.to_string()))?;
        let end = usize::try_from(span.end.0).map_err(|error| internal(error.to_string()))?;
        header.extend_from_slice(
            source
                .text()
                .get(start..end)
                .ok_or_else(|| internal("header source range missing"))?,
        );
        header.push(b'\n');
    }
    let mut batch = Batch {
        examples: Vec::new(),
        ignored: extraction.ignored_blocks,
        complete: true,
    };
    for (index, example) in extraction.examples.into_iter().enumerate() {
        let line = source.line_col(example.span.start).line;
        let id = format!(
            "{}:{line}:doc:{}",
            entry.display_name,
            index.saturating_add(1)
        );
        let mut virtual_source = header.clone();
        virtual_source.extend_from_slice(example.source.as_bytes());
        let execution_module = module.decls.iter().any(|decl| {
            matches!(&decl.item,
            Item::Fn(function) if function.name.text == "main")
        });
        let input = VirtualInput::new(
            entry,
            source.text(),
            &virtual_source,
            id.clone(),
            execution_module,
        );
        let require_main = matches!(example.expectation, Expectation::Run { .. });
        let mut checked = pipeline::check(
            &input.entry,
            &input,
            CheckOptions {
                require_main,
                deny_warnings,
            },
        );
        // 元コメントもソース表に保持し、仮想入力はハッシュと位置の両方で識別可能にする。
        let original = checked.sources.iter().find_map(|(file, candidate)| {
            (candidate.name() == source.name() && candidate.text() == source.text()).then_some(file)
        });
        let original = match original {
            Some(file) => file,
            None => Arc::get_mut(&mut checked.sources)
                .ok_or_else(|| internal("doc sources shared before preparation"))?
                .add(Source::new(
                    source.name().to_string(),
                    source.kind(),
                    source.text().to_vec(),
                )),
        };
        let source_map = example
            .source_map
            .with_prefix(header.len())
            .with_original_file(original);
        let virtual_file = checked.entry;
        if let Some(virtual_file) = virtual_file {
            for diagnostic in &mut checked.diagnostics {
                source_map.map_diagnostic(virtual_file, diagnostic);
            }
        }
        let has_internal = checked
            .diagnostics
            .iter()
            .any(|d| d.kind == crate::diag::ReportKind::Internal)
            || prelude_error(&checked).is_some();
        let rejected = checked.diagnostics.iter().any(Diagnostic::is_error);
        let rendered = checked
            .diagnostics
            .iter()
            .map(|diagnostic| {
                render::render_one_text(diagnostic, &checked.sources, TextOptions { color: false })
            })
            .collect::<String>();
        // IO・制限・内部エラーや警告だけによる拒否を、期待した静的なEコードの成功にしない。
        let static_error = checked
            .diagnostics
            .iter()
            .any(|d| d.is_error() && d.code.is_some_and(|code| code.info().id.starts_with('E')));
        let is_error = matches!(example.expectation, Expectation::Error { .. });
        let expectation_matched = is_error
            && static_error
            && example.expectation.matches_diagnostics(&rendered)
            && !has_internal;
        let accepted = !has_internal && (is_error || !rejected);
        let mut tests = Value::Null;
        let mut effects = None;
        let mut compiled = None;
        if let Some(program) = &checked.program {
            let selected = if require_main {
                let contract = main_contract(program)?;
                let scheme = program
                    .types
                    .decl_types
                    .get(contract.binding)
                    .ok_or_else(|| internal("doc main scheme missing"))?;
                let kind = if scheme.ret == Ty::Con(TyCon::Builtin(BuiltinTy::UNIT), vec![]) {
                    MainKind::Unit
                } else {
                    MainKind::Result
                };
                vec![TestFn {
                    function: contract.name,
                    description: None,
                    location: contract.location,
                    binding: contract.binding,
                    kind,
                }]
            } else if matches!(example.expectation, Expectation::Test) {
                collect_tests(
                    program,
                    checked.entry.ok_or_else(|| internal("doc entry missing"))?,
                )?
            } else {
                Vec::new()
            };
            let mut reported = selected.clone();
            if let Some(file) = virtual_file {
                for test in &mut reported {
                    test.location = source_map.map_span(file, test.location);
                }
            }
            let inspection = crate::cli::inspection::inspect_tests(program, &reported)?;
            let (value, _, expanded) = check_report::inspect_value(
                TestInspection {
                    program: inspection,
                    tests: reported,
                },
                &checked,
            )?;
            tests = if require_main { json!([]) } else { value };
            effects = Some(expanded);
            if prepare_mode != PrepareMode::Inspect && executable(&example.expectation) && !is_error
            {
                match compile_selected(
                    program,
                    selected,
                    &checked.sources,
                    entry,
                    working_directory,
                    match prepare_mode {
                        PrepareMode::ExecuteLimited(allowed) => Some(allowed),
                        PrepareMode::Inspect | PrepareMode::Execute => None,
                    },
                ) {
                    Ok(value) => compiled = Some(value),
                    Err(PrepareError::Limit(mut errors)) => {
                        if let Some(file) = virtual_file {
                            for diagnostic in &mut errors {
                                source_map.map_diagnostic(file, diagnostic);
                            }
                        }
                        checked.diagnostics.extend(errors);
                    }
                    Err(PrepareError::Internal { stage, message }) => {
                        return Err(InternalError { stage, message });
                    }
                }
            }
        } else if expectation_matched {
            tests = json!([]);
            effects = Some(BTreeSet::new());
        }
        // 検査したASTは段のスレッド内で破棄し、実行用の成果物だけを渡す。
        checked.program = None;
        let mut mapped_example = example;
        mapped_example.span.file = original;
        mapped_example.source_map = source_map;
        let accepted = accepted
            && (prepare_mode == PrepareMode::Inspect
                || !executable(&mapped_example.expectation)
                || compiled.is_some());
        batch.examples.push(Example {
            id,
            example: mapped_example,
            checked,
            tests,
            effects,
            accepted,
            expectation_matched,
            compiled,
        });
    }
    Ok(batch)
}
