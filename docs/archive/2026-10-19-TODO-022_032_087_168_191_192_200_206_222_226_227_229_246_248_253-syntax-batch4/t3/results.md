# T3の実装結果

基準は `ad9fa1e2067e0e4ca8678d1a991267b05165e5fb`（開始時の `git merge-base HEAD san_benito`）である。コミットとdocs/todoの変更は行わない。

共通の関門Kの入力は、既存の深さ64を既定64/stress16、長いリストを既定4096/stress64、実ソースのリストを既定400/stress64とする。n=13/16/24は共有合成の深さではなく独立したcaseの個数であり、各値は48欄以下のレコードである。最終の予算の拒否だけは固定長1,048,576のWildを含むIRを両構成で使う。閾値そのものを越える契約を確認するため縮小できず、実行時のリストやヒープは作らず下位化の公開入口へ直接渡す。

## 実装と期待の変更

私有arenaと正規化した行列の表で判定を共有し、既存Join/Jumpへ一度だけ書き出す。試行の超過時は当該matchの番号と予算だけを戻し、ソース順の照合へ切り替える。最終の節・辺・表・定義ごとの命令の上限を保つ。現行設計と07-04の対象外の行、診断と生成Skillを揃える。

旧い下位化の三つの拒否例とn=13のgolden・CLIは、今回の受理の契約により成功を期待する。独立照合器との比較とn=13/16/24の実ソースの実行を追加し、最終予算の拒否も別の入力で維持する。test_commandの同入力はL0112が消え、後続のE0512だけを引き続き厳密に照合する。assertの緩和とignoreの追加は行わない。

## 途中の検査

- `cargo check -p benitoite --lib`：型の修正中に失敗し、局所テストのビルドで修正を確認した。
- `cargo test -p benitoite --lib ir::decision::tests -- --nocapture`：旧L0112期待だけが失敗した後、受理の期待と最終予算の拒否を分けて16件成功した。
- `cargo test -p benitoite --test random_programs shared_decisions_execute_previous_exponential_cases -- --nocapture`：開始版のdecision.rsでL0112の失敗を確認し、新版で成功した。最初のテスト案はmainのAssert.Check禁止で失敗したため、実行可能なConsole出力へ直してから開始版のL0112を再現した。
- `cargo test -p benitoite --test random_programs row_fallback_preserves_guard_alternatives_and_list_bindings -- --nocapture`：初期の入力案はE0208とE0608で拒否されたため、400要素の到達可能な二つの選択肢へ修正した。T3末尾のCaseLengthの失敗先の不足を再現し、R164の修正後に成功した。

途中の局所検査の外側の時間は計測していない。作業末の検査の時間は下へ記録する。

## 作業末の検査

同じ指定のdry-runは終了0で、名指しした7単位と関連7統合ターゲットを確認した。作業末のworkは一度実行した。

```sh
scripts/check.sh --level work --base ad9fa1e2067e0e4ca8678d1a991267b05165e5fb \
  --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack \
  --test golden --test verify --test random_programs --test vm_handlers \
  --test cli_process --test test_command --test desugar_export
```

終了0、外側381.272秒。結果は次のとおりである。

| 検査 | 結果 |
|---|---|
| fmt | 成功 |
| lib_default | 1,225成功、失敗0、既存の長いテスト21件は既定の対象外 |
| tests_related | cli_process 29、desugar_export 26、golden 2、random_programs 6、test_command 46、verify 2、vm_handlers 2が成功。合計113成功、失敗0。desugar_exportの既存の書き出し用1件は対象外 |
| source_rules | 成功 |
| skill_generated | gen_skillの前後で追跡する生成物の差分が増えず成功 |
| spec_tally | 自己検査と集計が成功。初回リリース版の未記入の完了条件なし |
| release_stack | 最適化した構成で10成功、失敗0、除外0。テスト部分25.31秒 |

同じ作業末の枠で `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を実行した。初回は終了101、外側10.648秒で、新しいenumのワイルドカード分岐3件が規約に反した。既存の全variantを明示する修正だけを行い、再実行は終了0、外側12.866秒で成功した。各variantの処理は変えていないので、成功済みのlib・統合テストは繰り返していない。release_stackはこの修正後のソースでビルドした。

この修正後の `cargo fmt --all --check` は終了0、外側2.782秒で成功した。`git diff --check` も終了0である。Rustの差分は本番コード1,183行追加・177行削除、テスト113行追加・46行削除である（新規arena/rowsを含み、生成参照とgoldenの付随ファイルは含めない）。

検査後の追記は本記録だけである。

## 計画からのずれと申し送り

R162〜R164に判断と理由を記した。cli_process・test_command・desugar_exportを同じgolden入力の読者として追加し、clippyはR163のall-targetsを一度実行する。Core Matchとformal/は変更していない。B3の純粋な構築器を使うガードの実観測と、改造末の全形式化比較・性能測定は、計画どおり後続作業へ渡す。
