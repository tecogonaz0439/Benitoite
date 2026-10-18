# W2a の実装と検査の記録

## 対象の状態と変更

実施日は2026-10-17、担当はCodexである。基準と対象HEADは、W1を取り込んだ `05261121920f92ddd1b579569f9700b6c09b29ce`、作業ブランチは `mod255/W2a` である。開始時の作業ツリーに差分はなかった。リポジトリのコミットと docs/todo/ の変更は行っていない。

完了時の差分は次の4ファイルである。

- `scripts/check.sh`: 引数なしをworkへ切り替え、work/stageの単位、繰り返せるtest、引数の値・競合・重複の検査、対象の包含、計画の表示と実行を追加した。旧only/fullの実行集合と分類は保持した。差分取得にno-renamesを加え、分類不能・基準不明はdry-runでも終了3とした。
- `scripts/check/test_policy.py`: 新しい入口の契約を検査する6テストを追加した。旧only13名/fullと各dry-runの28ケースはW1の固定記録と比較し、自動選択の10ケースはworkの独立した期待値で確認する。
- `decisions.md`: Skill再生成でCargoの失敗を返す修正をR4に記録した。
- `w2a/results.md`: 本記録。

Rust・Lean・現行設計・長い対象の一覧と実行器・固定記録は変更していない。既存のassertは削除していない。自動選択の期待値は計画どおり変更し、check-heap.shのdry-runは終了0から3、check-formal.shの選択名はformalからformal_buildへ更新した。期待値の緩和とignoreの追加は行っていない。

## test-audit の作成時の四問

1. 守る契約は、入口の選択・引数・終了状態・dry-runの非実行、作業末の重複排除と外部失敗の伝播である。標準出力・終了状態・外部プロセスの引数と順序を観察する。
2. 捕まえる退行は、旧指定の実行集合の変更、stageや局所検査の対象欠落、不要なtestの受理、改名の旧パスや未追跡入力の分類漏れ、文書例の重複、特殊構成の誤った包含、外部失敗後の継続である。
3. W1の互換性テストを保持し、意図して変更する自動選択だけを別の期待値で検査する。新しいwork/stageの契約はW1の対象に含まれないため、同じSandboxと表形式のケースで補う。内部関数やソースの字面を契約にはしない。
4. 本番用のテストフラグと選択専用のPythonは加えない。一時Gitリポジトリに本物の道具を写し、代用するのはcargo・lake・check-heap.shだけとする。policy_selftestの再帰実行は行わない。

## 検査

環境のbashは `3.2.57(1)-release`、Pythonは `3.9.6` である。bash 3.2とset -uの下で、test未指定と分類結果が空の配列も検査した。通常のCargoテストの件数解析とcargo metadataは追加していない。実在しないターゲットもdry-runでは受理し、Cargoの失敗は終了1として返す。

途中の局所検査は次のとおりである。時間はPythonのunittestが示した実測値である。

| 対象 | 結果 | 終了状態 | 時間 |
|---|---|---:|---:|
| 自動work、指定の誤り、名指しと包含、差分の範囲、失敗伝播の5テスト | 5件成功 | 0 | 2.215秒 |
| 分類の対応と全統合の包含、再生成を含む失敗伝播の2テスト | 2件成功 | 0 | 2.057秒 |
| Skill再生成の失敗の再現 | 一時コピーで修正前は終了0・成功表示あり、修正後は終了1・成功表示なし | 再現の検証は0 | 約0.2秒 |

途中検査のコマンドは次のとおりである。

```sh
python3 -B scripts/check/test_policy.py PolicyTests.test_default_switches_to_work_and_stops_with_three PolicyTests.test_argument_errors_are_two_without_execution PolicyTests.test_named_targets_partial_selection_and_containment PolicyTests.test_work_diff_range_includes_staged_untracked_deleted_and_renamed PolicyTests.test_work_failures_at_first_middle_and_last_command
python3 -B scripts/check/test_policy.py PolicyTests.test_work_mapping_and_all_integration_containment PolicyTests.test_work_failures_at_first_middle_and_last_command
```

作業末はplan.mdのW2a行に従い、次のdry-runを確認してから自己検査を一度実行する。

```sh
scripts/check.sh --level work --base 05261121920f92ddd1b579569f9700b6c09b29ce --only policy_selftest --dry-run
scripts/check.sh --level work --base 05261121920f92ddd1b579569f9700b6c09b29ce --only policy_selftest
```

| 作業末の検査 | 結果 | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| dry-run | 分類せず、policy_selftestだけを選択。検査本体を起動しない | 0 | 0.192秒 |
| policy_selftest | 14テスト成功。旧only/fullの28ケース、workへの切り替えの10ケース、新しい引数・差分・包含・失敗伝播、長い対象の実行器、三つのbash -nを含む | 0 | 10.298秒 |

自己検査本体の時間は10.242秒であった。作業末の検査は一度実行し、失敗はなかった。先行する局所検査にも失敗はなく、R4の再現は意図してCargoを失敗させた観察である。

## 計画からのずれと申し送り

「共通の関門 K」は既存のR1に従い、段1の六つの共通条件として扱った。実装中に見つけたSkill再生成の失敗伝播はR4に従って修正し、修正前後の終了状態を確認した。旧only/fullの集合と順序は変更していない。

change/releaseは未対応の水準として終了2にする。W2bで両水準とlong_onlyを実装し、新水準のrelease_stackをW1の実行器へ接続する。W2aのworkで名指しできるrelease_stackは既存のCargoコマンドを使い、旧指定も同じ実行部を保つ。AGENTS.md・07-03・07-04等の説明はW3でそろえ、R1のレビュー完了までは一般の作業へ新方針を適用しない。

W1の一覧・実行器・Rustの対象と構成に変更はなく、実Cargoの四構成の列挙を繰り返していない。Rustの全lib・clippy・fmt、full・gc-stress・all-targets、Miri、check-heap.shとcheck-formal.shの本体も実行していない。本作業の自己検査では外部の重い処理を代用し、実際のテスト本体の成功としては数えない。

## 後の状態で引用するための入力の記録

HEADだけで同一としないため、検査時の入力と、HEADからの二つのスクリプトの未コミット差分を記録する。decisions.mdと本記録は検査の入力ではない。一覧・実行器・固定記録のハッシュはW1の記録と一致する。

| 入力 | SHA-256 |
|---|---|
| `scripts/check.sh` | `a72cb8b035a5727f65e8f2f52978f035a37764a7894c7d36942a0d2818576e09` |
| `scripts/check/test_policy.py` | `803170796428f26deac46ab15dce2a199e3cfd69c3d40ed0870c4857474109f0` |
| `scripts/check/run_ignored.py` | `6608f713c532a30c4220c6ed2f3736bf3b1f51ee044a31ab0e5f68ecf942d04e` |
| `scripts/check/ignored-tests.json` | `6cce3a7de7ce82478eeee8a107b3a066c121a94806dc1208b00bd0cce49257a9` |
| `scripts/check/fixtures/legacy-commands.json` | `88c79cc690e7dfbeb718ba7ec73eeb732d3206cc9bfada2f720321fcc1993db5` |
| `git diff --binary HEAD -- scripts/check.sh scripts/check/test_policy.py` | `ff9cb74601e78ba939211f27a9960974eccc2790a31e4c0d10c714a75b56f825` |

