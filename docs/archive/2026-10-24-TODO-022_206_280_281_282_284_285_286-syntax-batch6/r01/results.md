# R01 の結果

2026-10-24。作業ブランチは `mod012/R01` である。

## 基準と変更

work の基準 B_WORK は `f76f32234a55bd952c53aeda0685bd9dfef5a2b2` とした。計画の B0 は `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` であるが、その後に計画の文書だけを追加したコミットを取り込んでいる。両コミットの差分は本改造のディレクトリの文書だけであることを確認した。

新水準の `lint_default` に `--examples` を追加した。既存の自己検査の期待コマンドを更新し、work の分類表へ src と examples の行を追加した。07-03 と docs/workflow の二雛形も、examples のコンパイル・lint と、change が受け持つ全ターゲットのテストを分けて説明するよう更新した。

## 実行した検査

以下のシェルコマンドはリポジトリの根で実行した。退行確認ではスクリプトを直す前に自己検査の期待値だけを更新した。作業末の検査には `/usr/bin/time -p` を付け、外側の実時間を採った。`rtk proxy` は出力をそのまま通す指定である。

| 検査 | コマンド | 終了状態・結果 | 外側の実時間 |
|---|---|---|---|
| 旧実装での退行確認 | `rtk proxy python3 -B scripts/check/test_policy.py PolicyTests.test_default_switches_to_work_and_stops_with_three PolicyTests.test_work_mapping_and_all_integration_containment PolicyTests.test_change_execution_configurations_and_containment` | 1。3テスト中、work の src・heap の2ケースと change の1ケースが `--examples` の欠落を理由に失敗。分類表の検査は成功 | 未計測。unittest の実測は2.326秒 |
| work の選択確認 | `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base f76f32234a55bd952c53aeda0685bd9dfef5a2b2 --only policy_selftest --dry-run` | 0。名指しの `policy_selftest` だけを選択 | 0.01秒 |
| 作業末の work | `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base f76f32234a55bd952c53aeda0685bd9dfef5a2b2 --only policy_selftest` | 0。22テスト成功。unittest の実測は14.478秒 | 14.53秒 |

初回の失敗は、更新した期待値に旧実装が適合しないことを確認するためのものである。新水準の `lint_default` に `--examples` を追加した後、作業末の自己検査で同じ観点を含む全件が成功した。

自己検査は本物の check.sh の入口で、work/change の実行コマンド、src と examples の分類、失敗伝播、三つのシェルの構文、旧 only/full の固定記録との一致、release の自動選択が `release_stack` だけであることを確認する。外部の Cargo 等は既存の代用を使う。Rust のコンパイル・Clippy 本体や全 lib は、R01 の検査割り当てどおり実行していない。

差分確認の `rtk git diff --check` と、`git diff --exit-code f76f32234a55bd952c53aeda0685bd9dfef5a2b2 -- scripts/check/fixtures/legacy-commands.json` は、ともに終了0であった（外側の時間は未計測）。旧経路と固定記録には変更がない。

## 計画からのずれと申し送り

実装範囲と検査指定に変更はない。旧実装での退行確認と差分確認の外側の時間だけは未計測である。D13 の決定に従い、examples の追加費用は再測定していない。言語の規則・Lean・処理系の Rust コードは変更していない。

自己検査は既存の表と期待コマンドの更新だけであり、新しいテスト関数や本番の差し込み口は追加していない。守る契約は新水準での対象選択であり、src だけの変更で examples の lint が抜ける退行を本物の入口で検出する。

独立レビューと受け入れは取りまとめの担当である。stage S-R1 の実行または引用の判断も取りまとめに委ねる。本記録は通常の work の結果であり、別の状態へ引用するための証拠欄は作成していない。コミット・取り込み・docs/todo の更新・公開は行っていない。リポジトリへの git の変更操作と private/ の読み取りも行っていない。
