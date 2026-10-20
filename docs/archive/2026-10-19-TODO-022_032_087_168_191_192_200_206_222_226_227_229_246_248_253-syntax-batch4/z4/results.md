# Z4 RV4-checkの指摘の修正の結果

基準B_WORKと開始時のHEADは `aed9c6fe35e28b54f05da5543f844fc58fa1af11`（`git merge-base HEAD san_benito`）である。実行日は2026-10-20。コミットは作らない。対応は[RV4-check-response.md](../reviews/RV4-check-response.md)、判断は[decisions.md](../decisions.md)のR202〜R206に記す。

## 変更

- 構文: 01-02のRecordDeclの二か所に省略可能なNLを記載し、01-01の説明を文法への参照に直した。宣言の最初と後続の欄名recordを、E0201一件で拒否してその行から回復する。
- 診断: 定数の誤りの式にE0433を重ねず、その式を含む関数のW0501を抑える。独立したE0433と別の関数のW0501は残す。Logが利用者の取り込みに隠される場合、W0501とE0501の修正案はBenitoite.Logを使う。
- 文書と契約: 02-04に束縛後の既存の型回復の限界を明記し、02-05の警告の条件も実装に揃えた。03-06・Range/NonEmptyListの標準ソース・生成Skillに、包みの鍵の可否と欄の比較順を記載した。生成grammarも更新した。
- テスト: 既存のpipelineとparserの表を拡充し、Logの修正後の再検査と、三つの包みを使うMap/Setのgoldenを加えた。

## 検査

作業末のコマンドWは次のとおりである。開始版を固定し、指定の7単位・5統合ターゲットを選んだ。lib・統合・fmtはこの入口とは別に重ねていない。

```sh
scripts/check.sh --level work --base aed9c6fe35e28b54f05da5543f844fc58fa1af11 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test golden --test spec_examples --test reference_examples --test random_programs --test desugar_export
```

| 検査 | 終了状態 | 外側の時間 | 結果・修正 |
|---|---|---|---|
| `cargo test -p benitoite --lib -- source_location_errors_do_not_hide_independent_type_errors record_is_rejected_as_a_field_name log_effect_fixes_resolve_when_a_user_module_shadows_log`（rtk経由、修正前） | 101 | 未計測 | 3件とも意図した診断の差で失敗。E0433の重なり、宣言の欄名の二件の診断、Logの誤ったhelpを再現した。 |
| 同じ局所テスト（本番修正後） | 0 | 未計測（テスト本体0.48秒） | 3件成功。 |
| `BENITOITE_GOLDEN_FILTER=opaque-wrapper-key cargo test -p benitoite --test golden`（rtk経由、初回） | 101 | 未計測 | 新規fixtureのMap.getのラベルmap/keyが実際のm/kと違い、stdoutもJSON形式になっていなかった。新規入力と期待ファイルを訂正した。 |
| 同じ局所golden（fixture訂正後） | 0 | 0.451秒 | 2件成功。包みの鍵の受理、昇順、検索と重複するSet要素の除去を確認した。 |
| `cargo run -p benitoite --example gen_skill`（rtk経由） | 0 | 未計測 | grammar・Range・NonEmptyListの生成参照を更新。最終のskill_generatedでも一致した。 |
| `cargo test -p benitoite --lib -- source_location_errors_do_not_hide_independent_type_errors io_all_warning_uses_the_canonical_log_name`（rtk経由） | 101 | 未計測 | 1件成功、独立した警告を確かめる新規入力にmainがなくE0414も出た。brokenをmainに直した。期待する診断の列は変えず、最終のlib全件で成功を確認した。 |
| `W --dry-run` | 0 | 0.040秒 | 7単位・5統合ターゲット、選択理由--onlyを確認。 |
| W（初回） | 1 | 15.528秒 | fmt成功後、lint_defaultで新規のwildcard_enum_match_armが失敗。分岐をif letに直した。lib・統合・残る単位は未実行。 |
| `W --dry-run`（lint修正後） | 0 | 0.015秒 | 同じ選択を確認。 |
| W（lint修正後） | 0 | 282.166秒 | 古くなったfmt、失敗したlintと未実行の残りを実行し、全選択単位が成功。 |
| `cargo clippy --all-targets` | 0 | 8.297秒 | R206の補完。全ターゲットのlintが成功。 |
| `git diff --check` | 0 | 未計測 | 空白の誤りなし。 |

時間は、明記したもの以外は未計測である。Wと全ターゲットのclippyは、プロセスの起動前後を単調時計で計測した。局所goldenの時間は実行器が返した外側の時間である。未計測のものを計測するための再実行はしていない。

作業末の件数は次のとおりである。

| 対象 | 成功 | 失敗 | 既存のignore |
|---|---:|---:|---:|
| lib_default | 1,252 | 0 | 21 |
| desugar_export | 29 | 0 | 1 |
| golden | 2 | 0 | 0 |
| random_programs | 7 | 0 | 0 |
| reference_examples | 1 | 0 | 0 |
| spec_examples | 7 | 0 | 0 |

source_rules・skill_generated・spec_tallyも成功し、初回リリースの完了条件の未記入はnoneだった。仕様の参照がない節の一覧は、集計の報告として出ている。

## 計画との差と申し送り

依頼末尾のworkを維持し、lint_defaultがlibとtestsだけを対象とすることから、依頼冒頭のcargo clippy --all-targetsをR206で補完してplanのZ4行へ追記した。失敗後は、古くなった検査・失敗した検査・未実行の検査だけを実行した。

軽2の離れた位置のE0401は、既にITy::Errorである式の型だけを変えても抑えられない。束縛と単一化の回復全体へ範囲を広げず、依頼の選択肢に従って02-04の説明を実態に合わせた（R202）。独立したList.lengthの定数のE0433と、別の関数のW0501は残している。これらはテストの緩和ではない。

test-auditの作成時の関門は、診断と修正後の受理を本物のpipeline/typecheckで、欄名をparserの公開入口で、鍵の観察可能な順序と検索をCLIのgoldenで守る形で通した。既存の表とfixtureの準備を使い、テスト用の公開API・差し込み口は加えていない。新しい鍵のgoldenは既存の振る舞いを固定する契約テストであり、鍵の実装は変えない。テストの削除、既存assertの削除、期待値の緩和、ignoreの追加はない。本番Rustは71行追加・10行削除、Rustのテストは131行追加・7行削除（既存の表の入力と変数名の置換）である。新規goldenは入力43行と指定・期待4行、標準ソースの説明は2行追加した。

RV4-checkの軽5件は対応済みであり、M1へ進める。オーケストレータが置いた未追跡のreviews/RV4-check.mdも、新規golden・対応表・本結果とともに取り込み対象に含める。docs/todo・formalは変更していない。版全体のchange/release・gc-stress・全ターゲットのtest・lake buildは実行していない。
