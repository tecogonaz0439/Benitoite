//! テストの収集で検査済みの表の欠落を見逃さないことを確かめる（設計書 06-04「テストの実行」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used)]

use super::collect_tests;
use crate::pipeline::{self, CheckOptions};

#[test]
fn collecting_tests_rejects_missing_checked_metadata() {
    enum Missing {
        Module,
        Binding,
        Type,
    }

    // 検査成功後の不整合は通常のソースから作れないため、本物の検査結果から該当する表だけを除く。
    // AST の走査と破棄も本番と同じ段のスタック内で行う。
    pipeline::on_large_stack(|| {
        let mut actual = Vec::new();
        let mut expected = Vec::new();
        for (missing, message) in [
            (
                Missing::Module,
                "test entry module missing from checked program",
            ),
            (
                Missing::Binding,
                "test function binding missing from checked program",
            ),
            (
                Missing::Type,
                "test function scheme missing from checked program",
            ),
        ] {
            let mut result = pipeline::check_text_on_current_thread(
                "tests.bnt",
                b"@test\nfunction example() -> Unit\n  return ()\nend function\n",
                CheckOptions {
                    require_main: false,
                    deny_warnings: false,
                },
            );
            assert_eq!(result.error_count(), 0, "{:?}", result.diagnostics);
            let entry = result.entry.unwrap();
            let checked = result.program.as_mut().unwrap();
            match missing {
                Missing::Module => checked.asts.retain(|module| module.file != entry),
                Missing::Binding => checked.resolved.decls = Default::default(),
                Missing::Type => checked.types.decl_types = Default::default(),
            }

            actual.push(collect_tests(checked, entry));
            expected.push(Err(crate::ir::InternalError {
                stage: "test",
                message: message.into(),
            }));
        }
        assert_eq!(actual, expected);
    })
    .unwrap();
}
