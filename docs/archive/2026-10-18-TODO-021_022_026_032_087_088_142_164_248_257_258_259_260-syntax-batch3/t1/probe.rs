//! T1〜T3 の局所比較。公開の段を実行し、全体番号を含む型・診断・コアを保存する。
use benitoite::{base::IdGen, diag, ir, modules, pipeline, prelude, resolve, typeck};
use std::{error::Error, fmt::Write, fs, path::Path, time::Instant};

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = std::env::args().collect();
    let input = Path::new(args.get(1).ok_or("input path required")?);
    let output = Path::new(args.get(2).ok_or("output directory required")?);
    fs::create_dir_all(output)?;
    let entry = pipeline::entry_spec(input).map_err(|e| format!("{e:?}"))?;
    let mut ids = IdGen::new();
    let loaded = modules::load_program(&entry, prelude::STDLIB, &modules::RealFs, &mut ids);
    assert!(
        !loaded.diagnostics.iter().any(diag::Diagnostic::is_error),
        "{:?}",
        loaded.diagnostics
    );
    let resolved = resolve::resolve(&loaded.modules, &loaded.asts, &loaded.sources, &mut ids);
    assert!(
        !resolved.diagnostics.iter().any(diag::Diagnostic::is_error),
        "{:?}",
        resolved.diagnostics
    );
    let start = Instant::now();
    let (types, diagnostics) = typeck::typecheck(
        &loaded.modules,
        &loaded.asts,
        &loaded.sources,
        &resolved,
        true,
    );
    let elapsed = start.elapsed();
    // 出力の整形・ファイルへの書き込みを型検査時間に含めない。
    fs::write(output.join("types.txt"), format!("{types:?}\n"))?;
    fs::write(output.join("diagnostics.txt"), format!("{diagnostics:?}\n"))?;
    let mut cli = String::new();
    let checked = pipeline::check_path(
        input,
        pipeline::CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
    .map_err(|e| format!("{e:?}"))?;
    for d in &checked.diagnostics {
        writeln!(
            &mut cli,
            "{}",
            diag::render::render_json_line(d, &checked.sources)
        )?;
    }
    fs::write(output.join("cli.jsonl"), cli)?;
    let errors: Vec<_> = diagnostics.iter().filter(|d| d.is_error()).collect();
    let error_codes: Vec<_> = errors.iter().map(|d| format!("{:?}", d.code)).collect();
    if errors.is_empty() {
        let program = pipeline::CheckedProgram {
            modules: loaded.modules,
            asts: loaded.asts,
            comments: loaded.comments,
            resolved,
            types,
        };
        let core = pipeline::desugar_checked(&program).map_err(|e| format!("{e:?}"))?;
        assert!(ir::check::check_program(&core).is_empty());
        fs::write(output.join("core.txt"), format!("{core:?}\n"))?;
        assert!(checked.program.is_some());
    } else {
        assert!(checked.program.is_none());
    }
    println!(
        "nodes={} bindings={} errors={} codes={error_codes:?} typecheck_ns={}",
        ids.node_count(),
        ids.binding_count(),
        errors.len(),
        elapsed.as_nanos()
    );
    Ok(())
}
