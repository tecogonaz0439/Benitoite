//! 通常の検査と同じ入力から、区間解析の消費を記録する検査補助
//! （設計書 02-05「区間解析の駆動と予算」、07-03「テストの設計の原則」）。
//! 型の誤りがある検査でも、有効な本体の消費を未取得にしない。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use serde_json::{Value, json};
use std::io::Write;

fn usage(summary: crate::typeck::IntervalAnalysis) -> Value {
    let stops = |s: crate::typeck::IntervalBudgetStops| {
        json!({"bodyOperations":s.body_operations,"bodyItems":s.body_items,
            "wholeOperations":s.whole_operations,"wholeItems":s.whole_items})
    };
    json!({"coverage":format!("{:?}",summary.coverage),
        "inputDefinitions":summary.input_definitions,
        "bodyBudgetExceeded":summary.body_budget_exceeded,
        "wholeBudgetSkipped":summary.whole_budget_skipped,
        "unidentifiedBodies":summary.unidentified_bodies,
        "phaseStops":{"exceeded":stops(summary.phase_stops.exceeded),
            "unidentified":stops(summary.phase_stops.unidentified),
            "depth":summary.phase_stops.depth,"other":summary.phase_stops.other},
        "operations":summary.usage.operations,"peakItems":summary.usage.peak_items,
        "savedItems":summary.usage.saved_items,
        "maxBodyOperations":summary.usage.max_body_operations,
        "maxBodyItems":summary.usage.max_body_items})
}

fn observe(entry: &EntrySpec, fs: &dyn ModuleFs, require_main: bool) -> Value {
    let checked = check_stages(
        entry,
        fs,
        CheckOptions {
            require_main,
            deny_warnings: false,
        },
    );
    let mut ids = crate::base::IdGen::new();
    let mut loaded = crate::modules::load_program(entry, crate::prelude::STDLIB, fs, &mut ids);
    let mut observed = Vec::new();
    let mut stage = "load";
    let mut summary = crate::typeck::IntervalAnalysis::default();
    if !loaded.diagnostics.iter().any(Diagnostic::is_error) {
        stage = "resolve";
        let mut resolved =
            crate::resolve::resolve(&loaded.modules, &loaded.asts, &loaded.sources, &mut ids);
        if !resolved.diagnostics.iter().any(Diagnostic::is_error) {
            stage = "typecheck";
            // 位置の式も通常の型検査と同じ展開を通す。診断が出ても型検査は行う。
            source_location::expand(
                &loaded.modules,
                &mut loaded.asts,
                &loaded.sources,
                &mut resolved,
                &mut ids,
                None,
            );
            let (types, _, records) = crate::typeck::typecheck_with_interval_observations(
                &loaded.modules,
                &loaded.asts,
                &loaded.sources,
                &resolved,
                require_main,
            );
            summary = types.interval_analysis();
            observed = records;
        }
    }
    // 有効な本体の部分結果も含め、観測あり・なしで消費と停止が一致する契約を守る。
    assert_eq!(summary, checked.interval_analysis, "{}", entry.display_name);
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap();
    json!({"target":entry.display_name.replace(&root.display().to_string(), "<repo>"),"stage":stage,
        "accepted":checked.program.is_some(),"errors":checked.error_count(),
        "summary":usage(summary),"observed":observed})
}

// 関門: 成功したプログラムしか持たない既存の交換では、型検査拒否時の
// 有効な別の定義の消費が抜ける。通常の pipeline と実際の記録付き型検査を比べる。
// 任意の固定一覧を同じ補助へ渡せるが、利用者のプログラムやテストは実行しない。
#[test]
fn interval_inventory_matches_pipeline() {
    // 本番の段と同じスタックで check_stages を呼ぶため、共通の入口を使う
    // （設計書 02-01「関数の呼び出しと処理系のスタック」）。
    super::on_large_stack(run).unwrap();
}

fn run() {
    let Some(request) = std::env::var_os("BENITOITE_INTERVAL_INVENTORY") else {
        for (source, stage, has_bodies) in [
            (
                "const n: Integer = 7\nfunction f() -> Integer\n return n + n\nend function",
                "typecheck",
                true,
            ),
            (
                "const bad: Integer = true\nfunction good() -> Integer\n return 7\nend function",
                "typecheck",
                true,
            ),
            ("function broken(", "load", false),
        ] {
            let (entry, fs) = memory_entry(&[("main.bnt", source.as_bytes())]);
            let row = observe(&entry, &fs, false);
            assert_eq!(row["stage"], stage);
            assert_eq!(!row["observed"].as_array().unwrap().is_empty(), has_bodies);
            if has_bodies {
                assert!(row["summary"]["operations"].as_u64().unwrap() > 0);
            }
        }
        return;
    };
    let requests: Value = serde_json::from_slice(&std::fs::read(request).unwrap()).unwrap();
    let output = std::env::var_os("BENITOITE_INTERVAL_RECORDS").expect("record destination");
    let mut output = std::io::BufWriter::new(std::fs::File::create(output).unwrap());
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap();
    for input in requests["inputs"].as_array().unwrap() {
        let path = root.join(input["path"].as_str().unwrap());
        let require_main = input["command"] == "check";
        let entries = if require_main {
            vec![entry_spec(&path).unwrap()]
        } else {
            crate::cli::tools::test_runner::test_entries(&[path]).unwrap()
        };
        let targets: Vec<_> = entries
            .iter()
            .map(|entry| observe(entry, &crate::modules::RealFs, require_main))
            .collect();
        serde_json::to_writer(&mut output, &json!({"id":input["id"],"targets":targets})).unwrap();
        writeln!(output).unwrap();
        output.flush().unwrap();
    }
}
