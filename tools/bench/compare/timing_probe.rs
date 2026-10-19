//! Separate timing executable, using the same public stages as T1/probe.rs.
use benitoite::{base::IdGen, diag, modules, pipeline, prelude, resolve, syntax, typeck};
use std::{error::Error, path::Path, time::Instant};
fn main() -> Result<(), Box<dyn Error>> {
    let input = std::env::args().nth(1).ok_or("input required")?;
    let entry = pipeline::entry_spec(Path::new(&input)).map_err(|e| format!("{e:?}"))?;
    let mut ids = IdGen::new();
    let start = Instant::now();
    let loaded = modules::load_program(&entry, prelude::STDLIB, &modules::RealFs, &mut ids);
    let load = start.elapsed().as_secs_f64();
    if loaded.diagnostics.iter().any(diag::Diagnostic::is_error) {
        return Err(format!("load errors: {:?}", loaded.diagnostics).into());
    }
    let start = Instant::now();
    let resolved = resolve::resolve(&loaded.modules, &loaded.asts, &loaded.sources, &mut ids);
    let resolve = start.elapsed().as_secs_f64();
    if resolved.diagnostics.iter().any(diag::Diagnostic::is_error) {
        return Err(format!("resolve errors: {:?}", resolved.diagnostics).into());
    }
    let start = Instant::now();
    let (types, diagnostics) = typeck::typecheck(&loaded.modules, &loaded.asts, &loaded.sources, &resolved, true);
    let typeck = start.elapsed().as_secs_f64();
    std::hint::black_box(&types);
    let errors = diagnostics.iter().filter(|d| d.is_error()).count();
    let mut parse_ids = IdGen::new();
    let start = Instant::now();
    for (file, source) in loaded.sources.iter() {
        let lexed = syntax::lexer::lex(file, source.text());
        let tokens = syntax::newline::resolve_newlines(lexed.tokens);
        let parsed = syntax::parser::parse(file, source.kind(), source.text(), tokens, lexed.comments, &mut parse_ids);
        std::hint::black_box(parsed);
    }
    let reparse = start.elapsed().as_secs_f64();
    println!("{{\"load_parse\":{load},\"reparse\":{reparse},\"resolve\":{resolve},\"typeck\":{typeck},\"errors\":{errors}}}");
    Ok(())
}
