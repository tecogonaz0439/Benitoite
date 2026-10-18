# W2b の実装と検査の記録

## 対象の状態と変更

実施日は2026-10-17、担当はCodexである。基準と対象HEADは、W2aを取り込んだ `19d193b1fc76ab08ea7a6f112650d6146741e5c8`、作業ブランチは `mod255/W2b` である。開始時の作業ツリーに差分はなかった。リポジトリのコミットと docs/todo/ の変更は行っていない。自己検査の一時Gitリポジトリには検査用のコミットを作る。

完了時の差分は次の3ファイルである。

- `scripts/check.sh`: change/releaseを受理し、changeの全構成・doc・stress・lintと条件付きの検査を接続した。新水準のlong_onlyとrelease_stackはW1の実行器を使う。同一構成の文書例を包含し、固定の見込み時間とreleaseの手動照合の案内を表示する。
- `scripts/check/test_policy.py`: 4テストを追加し、引数と差分の既存テストを拡張した。長い対象の混在入力を共有し、本物のcheck.shから本物の実行器へ接続する。
- `w2b/results.md`: 本記録。

Rust・Lean・現行設計・長い対象の一覧と実行器・旧指定の固定記録は変更していない。既存のassertは保持した。W2aで未対応としていたchange/releaseの引数ケースは、計画に従って受理・実行の検査へ置き換えた。期待値の緩和とignoreの追加は行っていない。スクリプトは62行追加・11行削除、自己検査は273行追加・26行削除である。

## test-audit の作成時の四問

1. 守る契約は、changeの構成・条件付き検査の選択、同一構成の包含、releaseの分類省略と手動照合の案内、長い対象への接続と失敗伝播である。本物のcheck.shの標準出力・終了状態と外部プロセスの引数・順序を観察する。
2. 捕まえる退行は、既定とheapのall-targets・doc・stressの漏れ、異なる構成の誤った包含、条件付き検査の取りこぼし、releaseでの不要な分類、長い対象以外の実行、失敗後の継続である。
3. W1の固定記録とW2aの入口テストは保持する。四水準の追加契約は既存のSandboxと表形式のケースで補い、実行器単体の契約を重複して写さず、check.shから本物の実行器への接続を確かめる。
4. 本番の差し込み口は増やさない。代用するのはcargo・lake・check-heap.shだけとし、Git・Python・実行器と他の道具は本物を使う。長い対象の混在入力は既存テストと共有し、policy_selftest自体は再帰実行しない。

## 検査

環境のbashは `3.2.57(1)-release`、Pythonは `3.9.6` である。コマンドはrtk proxyを経由して起動した。通常のCargoテストの件数解析や、新しい分類用の道具は加えていない。

途中の局所検査は次のとおりである。時間はPythonのunittestが示す実測値である。

| 対象 | 結果 | 終了状態 | 時間 |
|---|---|---:|---:|
| 引数、changeの対応・実行・部分選択、releaseと実行器の接続の5テスト | 4件成功、1件失敗。合成した一覧を変更に含め、policy_selftestを再帰選択してしまった | 1 | 17.707秒 |
| changeの実行・包含の1テスト | 合成した一覧を一時リポジトリの基準側へ置く修正後に成功 | 0 | 1.064秒 |

```sh
python3 -B scripts/check/test_policy.py PolicyTests.test_argument_errors_are_two_without_execution PolicyTests.test_change_mapping_conditional_checks_and_stops PolicyTests.test_change_execution_configurations_and_containment PolicyTests.test_change_partial_selection_preserves_configurations_and_failures PolicyTests.test_release_and_long_runner_connections
python3 -B scripts/check/test_policy.py PolicyTests.test_change_execution_configurations_and_containment
```

作業末はplan.mdのW2b行に従い、次のdry-runを確認してから自己検査を実行した。

```sh
scripts/check.sh --level work --base 19d193b1fc76ab08ea7a6f112650d6146741e5c8 --only policy_selftest --dry-run
scripts/check.sh --level work --base 19d193b1fc76ab08ea7a6f112650d6146741e5c8 --only policy_selftest
```

| 作業末の検査 | 結果 | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| dry-run | 分類せず、policy_selftestだけを選択。検査本体を起動しない | 0 | 0.273秒 |
| policy_selftestの初回 | 17件成功、差分テストの1件失敗 | 1 | 13.673秒 |
| 失敗した差分テストのみの再検査 | 1件成功 | 0 | 0.444秒 |
| 修正後のpolicy_selftest | 18件すべて成功 | 0 | 14.119秒 |

初回の差分テストは、changeの全件テストへ包含した文書例について、個別の選択理由の表示を期待していた。workの既存assertを保持し、追加したchangeの場合は包含の表示を検査するよう修正した。本番のコードの変更は不要であった。失敗したテストのみを次のコマンドで確認した後、入口の終了0を確認するため、失敗した検査単位policy_selftestを一度再実行した。

```sh
python3 -B scripts/check/test_policy.py PolicyTests.test_work_diff_range_includes_staged_untracked_deleted_and_renamed
```

再実行前のdry-runは、選択・実行コマンドが変わらないため最初の結果を引用した。最後の自己検査本体は14.075秒であった。旧only13名とfullの実行・dry-runの28ケース、work/stageとchange/releaseの選択・非実行・引数・停止・失敗伝播、長い対象の実行器、三つのシェルのbash -nを含む。changeの既定・heapのall-targetsとdoc・stressの保持、条件付き検査、文書例の包含と特殊構成での非包含、基準の切り替え・ステージ済み・未追跡・削除・改名も確認した。

検査では、本物のGit・Python・スクリプトを使い、cargo・lake・check-heap.shだけを代用した。実際のRust・Leanのテスト本体、Miri、full・gc-stress・all-targets、check-heap.shとcheck-formal.shの本体は実行していない。代用による成功をそれらの実検査の成功とは数えない。`git diff --check` も成功した。

## 計画からのずれと申し送り

実装範囲と仕様に計画からのずれはない。「共通の関門 K」は既存のR1に従い、段1の六つの共通条件として扱った。新しいRの判断は不要であった。テストの準備と新しい期待値の誤りによる二度の失敗・修正を上に記録した。

旧only/fullの実行集合・順序はW1の固定記録に一致した。新水準のrelease_stackだけをW1の実行器へ切り替え、旧release_stackと旧fullの実行部は保持した。W1の一覧・実行器・Rustの対象と構成は不変なので、実Cargoの四構成の列挙はW1の記録を引用し、繰り返していない。

W3でAGENTS.md・07-03・07-04と依頼文・雛形等を実装へそろえる。R1のレビュー完了までは一般の作業へ新方針を適用しない。改造全体のchange、必要なheap/formal、実際の候補のreleaseと手動照合は、計画どおり後の担当に残す。releaseの終了0は受け入れ完了を表さない。

## 後の状態で引用するための入力の記録

最後の成功時の入力と、HEADからの二つのスクリプトの未コミット差分を記録する。本記録は検査の入力ではない。一覧・実行器・固定記録のハッシュはW1・W2aの記録と一致する。

| 入力 | SHA-256 |
|---|---|
| `scripts/check.sh` | `980ff99f5a01e57051ffcc4c96183d37793242e9526680ac991cf3efc6860b85` |
| `scripts/check/test_policy.py` | `0cfa4a5bd4bc1deb51f128a1fd7dd2613270e440ab580c967b4b004ed4d53e6f` |
| `scripts/check/run_ignored.py` | `6608f713c532a30c4220c6ed2f3736bf3b1f51ee044a31ab0e5f68ecf942d04e` |
| `scripts/check/ignored-tests.json` | `6cce3a7de7ce82478eeee8a107b3a066c121a94806dc1208b00bd0cce49257a9` |
| `scripts/check/fixtures/legacy-commands.json` | `88c79cc690e7dfbeb718ba7ec73eeb732d3206cc9bfada2f720321fcc1993db5` |
| `git diff --binary HEAD -- scripts/check.sh scripts/check/test_policy.py` | `19ad009d0b46dcea842b7a4775b12c43775a488a383a9d6f3ffe0e42bf67270f` |
