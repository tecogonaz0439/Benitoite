# Z3 RV4の指摘の修正の結果

作業日は2026-10-20。基準は `git merge-base HEAD san_benito` の `e9de51fced4c04668cd92b73f0838246efb3418c` であり、開始時のHEADも同じである。コミットは作らない。指摘ごとの対応は[RV4-response.md](../reviews/RV4-response.md)、判断は[decisions.md](../decisions.md)のR198〜R201に記す。

作業末のコマンドWは次のとおりである。指定の5ターゲットにspec_examplesを含め、01-01の検査もこの入口で実行した。

```sh
scripts/check.sh --level work --base e9de51fced4c04668cd92b73f0838246efb3418c --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test golden --test spec_examples --test reference_examples --test random_programs --test desugar_export
```

| 検査 | 終了状態 | 外側の時間 | 結果・修正 |
|---|---|---|---|
| `cargo test -p benitoite --lib rv4 -- --nocapture`（修正前。rtk経由） | 101 | 未計測（テスト本体0.10秒） | 新規5件が失敗。値のrecordの文区切り、欄名の拒否、Logのhelp、E0467後の型診断の退行を再現した。宣言の新規入力にも別の誤りがあったため、次行で修正する。 |
| 同じ局所テスト（本番修正後） | 101 | 約9.470秒 | 4件成功。残る宣言テストの非公開 `@opaque record` はE0820になる入力だった。公開宣言のpublicの後に改行を置く入力へ直し、全assertを保った。 |
| 同じ局所テスト（入力修正後） | 0 | 約5.620秒 | 5件成功。作業名の接頭辞rv4は後でテスト名から外し、最終のlib全件でも実行した。 |
| `cargo test -p benitoite --test checked_args source_location_requires -- --nocapture` | 0 | 約8.368秒 | 既存のhereの直接呼び出し・値化・パイプ・通常の引数診断・別名等の1件が成功。 |
| `BENITOITE_GOLDEN_FILTER=opaque-wrapper-equality BENITOITE_BLESS=1 cargo test -p benitoite --test golden -- --nocapture` | 0 | 約4.188秒 | 新規1ケース。出力を確認し、独立に作った値の構造の等値と三種類のAssert失敗の欄名・値に一致することを確認した。期待は成功1件・失敗3件・終了1。最終のgolden全体ではBLESSなしで照合した。 |
| `cargo run -p benitoite --example gen_skill` | 0 | 未計測 | 標準ソースの説明を直した後に再生成した。変更はRange/NonEmptyListの参照だけ。最終のskill_generatedでも一致を確認した。 |
| `W --dry-run` | 0 | 約0.020秒 | 7単位と5統合ターゲット、選択理由--onlyを確認。修正後の再実行前にも同じ指定のdry-runを実行し終了0。 |
| W（初回） | 1 | 7.365秒 | fmtの後、lint_defaultで新規parserテストのwildcard_enum_match_armに失敗。残りの単位は未実行。残るStmtの列挙子を明示した。assert・期待値は変更しない。 |
| W（上記修正後） | 0 | 258.618秒 | 全選択単位が成功。古くなったfmt・失敗したlint・未実行の残りの検査を実行した。 |
| `cargo clippy --all-targets` | 0 | 14.034秒 | 依頼冒頭の全ターゲットのlintを補完。 |
| `git diff --check` | 0 | 未計測 | 空白の誤りなし。 |

局所テストの概算時間は、当該実行のログの作成から最後の更新までである。Wと全ターゲットのclippyは、プロセスの起動前後を単調時計で計測した。最初の失敗再現と再生成の外側の時間は未計測であり、計測のための再実行はしない。

作業末のlibは1,251件成功・失敗0件・既存ignore21件である。統合はdesugar_export 29件（既存ignore1件）、golden 2件、random_programs 7件、reference_examples 1件、spec_examples 7件が成功した。source_rules、skill_generated、spec_tallyも成功し、初回リリースの完了条件の未記入はnoneだった。仕様の参照がない節の一覧は集計の報告として残る。

計画の補完は、02-04の回復の規則に合わせた02-01の一般の停止規則への例外の追記（R199）と、指定のworkを維持した全ターゲットのlint（R201）である。検査の再実行は、新規テストの入力修正とlintの修正で古くなった対象に限る。新しい言語機能、等値の制限、コア項は加えない。

既存assertの削除・期待値の緩和・ignoreの追加はない。テストの削除はなく、退行テストと等値・表示の契約テストだけを追加した。本番Rustは12行追加・7行削除（コメントを含む）、Rustのテストは145行追加・削除0行である。新規goldenは入力42行と期待値・実行指定7行である。標準ソースの説明2行と、対応する生成Skillの説明2行も追加した。

申し送り: RV4の中1件・軽5件は対応済みであり、M1への依存を閉じられる。オーケストレータが置いた未追跡のreviews/RV4.mdも、新規golden・対応表・本結果とともに取り込み対象に含める。版全体のchange/releaseの検査は取りまとめで行う。docs/todoとformalには変更がなく、gc-stress・cargo test --all-targets・lake buildは実行していない。
