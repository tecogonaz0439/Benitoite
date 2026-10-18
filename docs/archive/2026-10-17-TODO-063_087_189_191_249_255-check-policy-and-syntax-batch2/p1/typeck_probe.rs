//! 制約の多い本体の型検査だけを短く測る（設計書 07-02「測定の結果の使い方」）。
use benitoite::pipeline::{self, CheckOptions};
use std::time::Instant;
fn main() -> Result<(), Box<dyn std::error::Error>> {
    for failure in [false, true] {
        for n in [100_usize, 300, 900] {
            let mut source = if failure { "import Benitoite.Unofficial.Failure\n".to_owned() } else { String::new() };
            source.push_str("function apply(f: function(value: Integer) -> Integer, value: Integer) -> Integer\n return f(value)\nend function\nfunction workload() -> Integer\n");
            for i in 0..n { source.push_str(&format!(" bind v{i} <- apply(f: lambda(value) return value + 1 end lambda, value: {i})\n")); }
            source.push_str(&format!(" return v{}\nend function\n", n.saturating_sub(1)));
            let checked = pipeline::check_text("probe.bnt", source.as_bytes(), CheckOptions { require_main: false, deny_warnings: false });
            if checked.error_count() != 0 { return Err(format!("{:?}", checked.diagnostics).into()); }
            let p = checked.program.ok_or("missing program")?;
            for trial in 0..4 {
                let start = Instant::now();
                let (_, diagnostics) = benitoite::typeck::typecheck(&p.modules, &p.asts, &checked.sources, &p.resolved, false);
                let ns = start.elapsed().as_nanos();
                if diagnostics.iter().any(benitoite::diag::Diagnostic::is_error) { return Err(format!("{diagnostics:?}").into()); }
                println!("{failure},{n},{trial},{ns}");
            }
        }
    }
    Ok(())
}
