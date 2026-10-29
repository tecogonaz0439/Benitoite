//! 番号付けの資源上限と取得済みの接頭辞
//! （設計書 02-05「Scope の必須判定の入力」）。
#![allow(clippy::unwrap_used, clippy::arithmetic_side_effects)]

use super::*;

// 関門: 公開の入力取得境界で番号イベントの累積と失敗時の非計上を守る。
// 既存の共有定数の例は大きな展開だけを使い、ちょうど上限での受理を捕まえない。
// 本番のパイプラインと番号付けを使い、内部のイベント列を準備しない。
#[test]
fn numbering_budget_preserves_prefix_and_counts_only_admitted_events() {
    let checked = crate::pipeline::check_text(
        "numbering-budget.bnt",
        b"function sample() -> Unit\n ()\nend function\n",
        crate::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let types = checked.program.unwrap().types;
    let input = types
        .scope_inputs
        .bodies
        .iter()
        .find(|input| input.body_key.definition == ".sample")
        .unwrap();

    // 深さ1への移動、文の開始、Unit の式の三イベント。一つの出現は番号0である。
    for (limit, previous, expected_ops, stopped, statements, occurrences) in [
        (0, 0, 0, true, 0, 0),
        (2, 0, 2, true, 1, 0),
        (1, 0, 1, true, 0, 0),
        (4, 2, 2, true, 1, 0),
        (3, 0, 3, false, 1, 1),
    ] {
        let mut budget = ScopeNumberingBudget {
            operations: previous,
        };
        let numbered = input.numbered_with_budget(limit, &mut budget);
        assert_eq!(numbered.numbering_operations, expected_ops);
        assert_eq!(budget.operations, previous + expected_ops);
        assert_eq!(numbered.statements.len(), statements);
        assert_eq!(numbered.occurrences.len(), occurrences);
        assert_eq!(
            numbered.stopped,
            stopped.then_some(ScopeInputStop::NumberingLimit {
                max_operations: limit
            })
        );
        assert!(numbered.occurrences.iter().all(|o| o.preorder == 0));
    }
}
