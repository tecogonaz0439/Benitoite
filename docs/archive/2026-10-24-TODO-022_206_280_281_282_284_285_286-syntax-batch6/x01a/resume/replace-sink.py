from pathlib import Path

p=Path('crates/benitoite/src/typeck/interval/observation.rs')
s=p.read_text();start=s.index('fn candidate(');s=s[start:]
s=s.replace('pub(super) fn record(identity: &IdentityMap<\'_>, report: &BodyReport) {\n    SINK.with(|sink| {\n        let mut sink = sink.borrow_mut();\n        let Some(records) = sink.as_mut() else { return };', '''pub(super) fn record(
    sink: Option<&mut Vec<Value>>,
    identity: &IdentityMap<'_>,
    report: &BodyReport,
) {
    let Some(records) = sink else { return };''')
assert s.endswith('    });\n}\n');s=s[:-len('    });\n}\n')]+'}\n'
p.write_text('''//! 検査ごとに渡す独立交換の任意の記録先
//! （設計書 02-05「区間解析の式の識別」）。
//! 解析済みの対応だけを読み、無効時は複写・確保も予算操作も行わない。

use super::{BodyReport, arithmetic::Candidate, identity::IdentityMap};
use serde_json::{Value, json};

fn span(s: crate::base::Span) -> Value {
    json!([s.file.0, s.start.0, s.end.0])
}

'''+s)
p=Path('crates/benitoite/src/typeck/interval/mod.rs');s=p.read_text().replace('#[doc(hidden)]\npub use observation::observe_intervals;\n\n','')
needle='''    pub fn analyze(
        &mut self,
        tables: &InputTables<'_>,
        fuel: u32,
        diagnostics: &mut Vec<crate::diag::Diagnostic>,
    ) -> Report {
'''
assert needle in s
s=s.replace(needle,needle+'''        self.analyze_recorded(tables, fuel, diagnostics, None)
    }

    /// 任意の記録先は検査ごとに借用し、大域状態や解析予算に加えない。
    pub fn analyze_recorded(
        &mut self,
        tables: &InputTables<'_>,
        fuel: u32,
        diagnostics: &mut Vec<crate::diag::Diagnostic>,
        mut observations: Option<&mut Vec<serde_json::Value>>,
    ) -> Report {
''')
s=s.replace('observation::record(identity, &body_report);','observation::record(observations.as_deref_mut(), identity, &body_report);')
s=s.replace('observation::record(&identity, &body);','observation::record(observations.as_deref_mut(), &identity, &body);')
p.write_text(s)
p=Path('crates/benitoite/src/typeck/mod.rs');s=p.read_text().replace('    observe_intervals,\n','')
needle='''    decls::check(modules, asts, sources, resolved, require_main)
}
'''
assert needle in s
s=s.replace(needle,needle+'''
/// 独立交換の照合用に、呼び出しごとの区間解析の記録も返す内部用入口。
/// 通常の型検査と同じ処理を使い、記録先がない呼び出しの確保と予算を増やさない。
#[doc(hidden)]
pub fn typecheck_with_interval_observations(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
    require_main: bool,
) -> (TypeckOutput, Vec<Diagnostic>, Vec<serde_json::Value>) {
    let mut observations = Vec::new();
    let (output, diagnostics) = decls::check_recorded(
        modules, asts, sources, resolved, require_main, Some(&mut observations),
    );
    (output, diagnostics, observations)
}
''')
p.write_text(s)
p=Path('crates/benitoite/src/typeck/decls.rs');s=p.read_text();needle='''pub(super) fn check(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
    require_main: bool,
) -> (TypeckOutput, Vec<Diagnostic>) {
''';assert needle in s
s=s.replace(needle,needle+'''    check_recorded(modules, asts, sources, resolved, require_main, None)
}

/// 検査の寿命内だけ記録先を借用し、既存の型検査の出力と診断の組を保つ。
pub(super) fn check_recorded(
    modules: &ModuleTable,
    asts: &[Module],
    sources: &SourceTable,
    resolved: &ResolveOutput,
    require_main: bool,
    observations: Option<&mut Vec<serde_json::Value>>,
) -> (TypeckOutput, Vec<Diagnostic>) {
''')
start=s.index('    d.out.interval = d.interval.analyze(');end=s.index('    if d.diagnostics.iter().any(Diagnostic::is_error)',start)
s=s[:start]+'''    let tables = super::interval::input::InputTables {
        resolved,
        constants: &d.out.consts,
        literals: &d.out.lit_values,
        range_bounds: &d.out.range_bounds,
        schemes: &d.out.decl_types,
    };
    d.out.interval = match observations {
        Some(sink) => d.interval.analyze_recorded(&tables, INTERVAL_ANALYSIS_FUEL, &mut d.diagnostics, Some(sink)),
        None => d.interval.analyze(&tables, INTERVAL_ANALYSIS_FUEL, &mut d.diagnostics),
    };
''' +s[end:]
p.write_text(s)
p=Path('crates/benitoite/tests/desugar_export/interval.rs');s=p.read_text();start=s.index('        let (checked, observed) = benitoite::typeck::observe_intervals(');end=s.index('        assert_eq!(',start)
s=s[:start]+'''        let checked = pipeline::check_text(
            label,
            text.as_bytes(),
            CheckOptions { require_main: false, deny_warnings: false },
        );
''' +s[end:]
needle='''        let p = checked.program.as_ref().unwrap();
        let core = pipeline::desugar_checked(p).unwrap();
        let definitions = exchange::definitions_recorded(p, &core, true).0;'''
assert needle in s;s=s.replace(needle,'''        let p = checked.program.as_ref().unwrap();
        // 同じ AST を本物の型検査へ再度渡す。記録先はこの検査の中だけで所有する。
        let (_, diagnostics, observed) = benitoite::typeck::typecheck_with_interval_observations(
            &p.modules, &p.asts, &checked.sources, &p.resolved, false,
        );
        assert!(!diagnostics.iter().any(benitoite::diag::Diagnostic::is_error), "{label}: {diagnostics:?}");
        let core = pipeline::desugar_checked(p).unwrap();
        let definitions = exchange::definitions_recorded(p, &core, true).0;''')
p.write_text(s)
