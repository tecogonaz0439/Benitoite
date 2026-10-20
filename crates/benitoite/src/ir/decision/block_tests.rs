//! ブロック内のガードを共有判定と行照合で実行する（設計書 02-06「判定の木への変換」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」）。
#![allow(clippy::unwrap_used, clippy::indexing_slicing)]
use super::*;
use crate::builtins::funcs::fixed_io::FixedIo;
use crate::pipeline::{self, CheckOptions};
use crate::runtime::heap::HeapConfig;
use crate::runtime::io::services::RunInput;
use crate::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use crate::vm::{ExecMode, MainOutcome, VmConfig};
use std::sync::{Arc, Mutex};

// 関門: 同一の実ソースを二経路で命令へ移し、VM と独立参照評価の結果を
// 固定した期待値と比較する。予算の入口は私有の既存欄だけを使い、公開 API を増やさない。
#[test]
fn block_guard_order_survives_shared_decisions_and_row_fallback() {
    check_paths(
        include_str!("../../../tests/desugar_export/batch4/block-guards.bnt"),
        "guarded",
        "gh/ghi/i",
    );
}

// 関門: 小さいリストでも私有の予算を使い切り、guard の代替と tail の束縛を
// 行照合から VM まで渡す。共有経路だけでは切替時の束縛漏れを捕まえられない。
#[test]
fn row_fallback_preserves_guard_alternatives_and_list_bindings() {
    check_paths(
        "function pick(xs: List[Integer]) -> Integer\n return match xs with\n case [x, 0, _, _], [_, _, 0, x] if x > 1 -> 10\n case [_, ..tail] -> List.length(tail)\n case [] -> -2\n end match\nend function\nfunction main() -> Result[Unit, String]\n return Result.Error(Integer.toString(pick([1, 0, 0, 2])) + \"/\" + Integer.toString(pick([])))\nend function\n",
        "pick",
        "3/-2",
    );
}

fn check_paths(source: &str, selected_name: &str, expected: &str) {
    let checked = pipeline::check_text(
        "decision-paths.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    assert!(crate::ir::check::check_program(&core).is_empty());
    let selected = core
        .defs
        .iter()
        .position(|d| d.name == selected_name)
        .unwrap();
    let def = &core.defs[selected];
    let input = RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    };
    let mut fixed = FixedIo::new(input.clone());
    assert_eq!(
        crate::refinterp::run(&core, &mut fixed),
        crate::refinterp::RefOutcome::Finished(MainOutcome::Error(expected.into()))
    );
    for rows in [false, true] {
        let mut lower = lower_program(&core).unwrap();
        let mut ctx = Lowerer::new(
            &core.adts,
            def.var_count,
            &mut lower.body_count,
            &def.name,
            def.span,
        );
        if rows {
            // 定義の試行予算を使い切った状態なら、最初の行列で Limit になり
            // match_comp が保存状態へ戻した後に row_match へ進む。
            ctx.def_tree_work = MAX_DEF_TREE_WORK;
        }
        let body = ctx.comp(&def.body, false).unwrap();
        if rows {
            assert_eq!(ctx.def_tree_work, MAX_DEF_TREE_WORK);
        } else {
            assert!(ctx.def_tree_work > 0 && ctx.def_tree_work < MAX_DEF_TREE_WORK);
        }
        lower.defs[selected].body = body;
        lower.defs[selected].var_count = ctx.var_count;
        let program =
            crate::bytecode::codegen::codegen(&lower, Arc::clone(&checked.sources)).unwrap();
        crate::bytecode::verify::verify(&program).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let end = run::run_program(
                &program,
                RunEnv {
                    input: input.clone(),
                    stdin: StdinSource::Empty,
                    stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                    interrupt: Box::new(NoInterrupt),
                    parts: None,
                    mode,
                    vm: VmConfig {
                        call_budget: 1,
                        ..VmConfig::default()
                    },
                    heap: HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                    dev_panic_after_first_write: false,
                },
            );
            assert_eq!(
                end.main_error.as_deref(),
                Some(expected),
                "rows={rows}/{mode:?}: {end:?}"
            );
            assert_eq!(end.exit_code, 1);
            assert!(end.reports.is_empty(), "{end:?}");
        }
    }
}
