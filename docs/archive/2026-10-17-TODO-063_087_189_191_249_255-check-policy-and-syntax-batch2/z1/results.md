# Z1 R1 の指摘修正の結果

基準: `d281836fdaea44c1bee31b7eba36495b3a8b62f8`。コミットしない。

| 作業末の検査 | 結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base d281836fdaea44c1bee31b7eba36495b3a8b62f8 --only policy_selftest --dry-run` | 0。policy_selftest のみ | 0.01秒未満 |
| 同じ指定から `--dry-run` を外して一度実行 | 0。20件成功（三つのシェルの構文・旧指定の互換性も含む） | 11.879秒 |
| `python3 -B /tmp/z1-check-links.py` | 0。変更 Markdown 11ファイル、ローカルリンク146件 | 0.061秒 |
| `git diff --check` | 0 | 0.018秒 |

途中の局所検査: `python3 -B scripts/check/test_policy.py PolicyTests.test_stop_guidance_preserves_units_base_and_targets PolicyTests.test_empty_work_reports_no_changed_files PolicyTests.test_default_switches_to_work_and_stops_with_three PolicyTests.test_argument_errors_are_two_without_execution IgnoredTests` は9件成功（3.264秒）。`rustc --test /tmp/z1-libtest.rs -o /tmp/z1-libtest` と `/tmp/z1-libtest --ignored --skip export_coverage --skip export_desugar_corpus` は0（計0.228秒）。独立した最小入力で長い対象1件のみ成功し、通常対象と形式化の書き出しを除外できた。ソースも読み、スタック対象10件と書き出しの二つの名前を確認した。

`python3 -B /tmp/z1-regression.py` では修正前の入口を一時リポジトリに置き、停止案内・heap の文書テスト・誤指定の理由・新規パスの分類・変更0件の表示の五つが意図した理由で失敗することを確認した。修正後は作業末の20件で成功した。作業末の検査に初回の失敗はない。

計画からのずれ: 申し送りの案 (A) を適用し、旧一覧・列挙・個別実行を廃止した（decisions.md の R5）。その機能専用の自己検査の assert は、一括実行・件数・失敗伝播の検査へ置き換えた。Rust と Lean は変更していない。

申し送り: R1 の全文は reviews/R1.md。段1の集約と取り込みはオーケストレータが行う。長いテスト本体・release_stack 本体・改造全体の change と release は本作業では実行しない。W1 の一覧の列挙を新方式の証拠として引用しない。
