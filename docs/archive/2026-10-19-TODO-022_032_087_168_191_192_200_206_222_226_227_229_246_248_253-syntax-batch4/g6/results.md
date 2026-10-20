# G6 の実装と検査

基準B_WORK: `b72e4bf4a2f23b26b2c96612bfa2b7f3e9f05fa7`（開始時のHEADと `git merge-base HEAD san_benito` が一致）。開始時の未コミット差分はなかった。コミットとdocs/todoの変更は行っていない。

## 変更と判断

tools/named-arguments-migrateの4ファイルと、専用Rust helper・indexの2ファイルを、[historical-tools/named-arguments-migrate](../historical-tools/named-arguments-migrate/README.md)へ元の相対パス構造で移した。元のREADMEとテストも内容を変えていない。移動前に保存した[manifest.json](../historical-tools/named-arguments-migrate/manifest.json)に、開始版・元のパス・保管先・個々のSHA-256を記した。移動後の全6ファイルが移動前のhashと開始版のGitオブジェクトに一致することを確認した（[integrity.log](integrity.log)）。復元手順は保管READMEに分け、現行parserと欠けたN1入力のままで旧自己検査が通るとはしていない。

AGENTSの現役一覧、source-migrateの案内、try-actions-migrateの除外一覧、check.shのPython glob・分類・dry-run表示を更新した。07-03の検査対象と07-04の対象外の行をそろえ、改造文書の調査から移動したファイルへのリンクも直した。仕様構文・標準ソース・診断表とformal/は変えていない。Skill生成参照の再生成一致はworkで確認した。workflowの雛形には旧道具の参照がなく、変更は不要だった。

計画との差はR196に記した。git mvが.git/index.lockの作成を環境の制限で拒否されたため、通常のファイル移動を使い、Gitインデックスへの反映は取りまとめに委ねる。07-04に指定の行がなかったため新設した。作業末のlint_defaultは依頼の全ターゲットclippyに置き換えて重複を避け、planのG6行も同じ指定へ直した。

## 途中の局所検査

`python3 -B scripts/check/test_policy.py PolicyTests.test_python_syntax_excludes_historical_tools` で、旧globが消えたディレクトリを指してFileNotFoundErrorとなる失敗を再現した。check.shの修正後は同じテストが成功した。現役のPython構文エラーを拒否し、保管Pythonを収集しない実際のシェル入口が契約の持ち主である。既存の分類テーブルにも保管したPythonとRustの行を追加し、work/changeの分類が検査を選ばないことを確認する。外部プロセス以外の内部処理は代用せず、テスト専用の本番入口は追加していない。

途中では上記と、`python3 -B scripts/check/test_policy.py PolicyTests.test_python_syntax_excludes_historical_tools PolicyTests.test_work_mapping_and_all_integration_containment PolicyTests.test_change_mapping_conditional_checks_and_stops` だけを局所テストとして実行した。後者はglob修正前で新テスト1件が同じ理由で失敗し、既存の分類2件は成功した。局所検査の外側時間は個別計測していない。既存assertの削除・期待値の緩和・ignoreの追加はなく、保管した旧テスト208行も同一である。現役のテストは20行追加、既存行の削除は0行である。本番Rustの本文と、現役移行器の候補生成・適用・共有APIは変えず、現役Pythonの除外一覧を1行更新した。

## 作業末の検査

planのG6行を同じ基準・指定のdry-runで確認した後、workを一度実行し、全ターゲットclippyと補完のexamples確認を各一度実行した。全コマンドの引数・終了状態・外側時間は[commands.jsonl](commands.jsonl)に記す。作業末の失敗・再実行はない。

| 検査 | 結果 | 外側時間 |
|---|---|---:|
| [G6 workのdry-run](dry-run.log) | 9単位とskill_docsを選択。Pythonの表示も現役のglobと一致 | 0.020秒 |
| [G6 work](work.log) | 終了0。lib 1246成功・既存ignore21件、skill_docs 8成功、source-migrate 6成功、try-actions-migrate 6成功、policy_selftest 22成功。fmt・source_rules・Skill再生成一致・spec_tally・Python構文も成功 | 129.123秒 |
| [全ターゲットclippy](clippy.log) | `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep`、終了0 | 5.555秒 |
| [examples確認](examples.log) | `cargo check -p benitoite --examples`、終了0 | 9.737秒 |

静的な照合では `cargo metadata --no-deps --format-version 1` の現役example 10件に旧helperが含まれないことを確認した。現役のAGENTS・README・tools・scripts・workflow・cratesを対象に `git grep -n -E 'named-arguments-migrate|named_arguments_inventory|named_inventory'` で検索し、残る参照は保管パスを使うテスト入力と保管READMEへのリンクだけだった（[references.log](references.log)）。既存docs/archiveの変更はない。これらの照合の外側時間は個別計測していない。

保管案内・結果・移動先へ更新した調査のリンク21件が存在し、`git diff --check`も終了0だった（[static.log](static.log)）。元のREADME内の相対リンクは元の配置を保った履歴であり、移動先に合わせて書き換えていない。

## 後の作業への申し送り

G6の完了条件を満たした。通常のファイル移動のため、取り込み時は削除と保管先の未追跡ファイルを一緒にステージし、同一内容の移動として確認する。改造ディレクトリを最後にdocs/archiveへ移す際は、tools/source-migrate/README.mdの保管リンクも更新する。保管ファイルの本文は引き続き変更しない。

検査後の追加は本結果の記録と静的な照合の記録だけである。stage/change/releaseと特殊構成の全件は後の担当へ渡す。形式化した規則・主定理・公理・Builtins.Assumptionsと共有インターフェースに変更はなく、lake buildや形式化全比較は追加していない。
