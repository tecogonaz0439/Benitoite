# Z1: G1 の指摘の修正結果

G1 の【中】1・2 と【軽】3〜7 をすべて修正した。レビュー本文は [reviews/G1.md](../reviews/G1.md) に依頼の全文を保存した。コミット、docs/todo/ の変更、`scripts/check.sh`（dry-run を含む）、gc-stress の検査は行っていない。

## 変更したファイル

| ファイル | 変更 |
|---|---|
| `crates/benitoite/build.rs` | 監視登録の成否を確認する。管理場所や ref のパスを解決できない場合、HEAD の監視を登録できない場合、symbolic HEAD の ref と packed-refs のどちらも監視できない場合は commit を不明・由来 `unknown` とする。common-dir に `reftable` がある場合も採取しない。存在する `<git-dir>/logs/HEAD` を監視に加える |
| `crates/benitoite/tests/build_info.rs` | 既存の五群を独立した long テストへ分ける。監視失敗・reftable の管理場所・gc 後のコミットと update-ref・reflog がない unborn ブランチの最初のコミットを確認する |
| `crates/benitoite/tests/cli_process.rs` | 既存の JSON 全体の比較に加え、commit の桁数と小文字十六進表記、由来の値域、由来 `git` なら commit が null でないことを、埋め込み値から独立して確認する |
| `docs/design/05-platform/05-01-distribution.md` | 再採取の条件、監視できない場合の不明値、reftable の扱い、検知の限界を更新。HEAD の管理場所を `--git-dir` の側と記す |
| `docs/design/06-tooling/06-01-cli.md` | 版問い合わせの欄の順序を契約に含めないことを明記 |
| 改造ディレクトリの `design.md`・`harness-response.md` | 監視条件と限界を 05-01 と揃える |
| 改造ディレクトリの `decisions.md`、`p1/inputs.md`・`p1/results.md`、`p2/acceptance.md`・`p2/results.md` | 指定された監視の補足を R11 として記録。既存の P1 の R11 を R12 に改番し、参照を更新 |
| 改造ディレクトリの `reviews/G1.md`・本書 | レビュー全文と修正・検査結果を記録 |

本番コードは 17 行追加・12 行削除（5 行増）、テストは合計 146 行追加・12 行削除（134 行増）である。既存の assert を削除せず、期待値を緩めていない。四つの補助関数を long テストとして独立させたが、元から ignore のテスト内で実行していた群であり、通常の検査から新たに外したテストはない。

## test-audit の作成時の関門

- 守る契約は、監視を成立させられない Git 採取を不明として返すこと、既存の HEAD の reflog の変化で再採取すること、公開 JSON の commit と由来の値域である。
- 現実的な退行は、旧 Git 相当の複数行出力・パス解決の失敗・非 UTF-8 の出力・監視対象の不在を無視して commit を埋め込むこと、gc 後のコミットの再採取漏れ、JSON の不正な値である。
- 既存のビルド用 fixture と正常・失敗の表を拡張した。reftable は common-dir の管理場所を用意して採取を拒むことを確認する。packed-only からの新設を検知しない既存の観測は、HEAD の reflog がない条件で保持し、明示入力の変更と clean build による回復も残した。
- 本番の公開 API やテスト専用の差し込み口は加えていない。本番 build.rs を写した一時クレートの実ビルドと、実 CLI プロセスの出力を境界にする。Git の失敗は既存の PATH による外部コマンドの代用で作る。削除候補のテストや、それに伴う本番コードの整理はない。

修正前の build.rs で `git_states`・`git_failures`・`packed_ref_refresh` を走らせ、reftable の管理場所、旧 Git 相当の応答、gc 後の最初のコミットについて、期待どおりに失敗することを確認した。前二群は `cargo test -p benitoite --test build_info git_ -- --include-ignored`、後者は `cargo test -p benitoite --test build_info packed_ref_refresh -- --include-ignored` で実行した。

## 検査

実行前に対象と見込みの時間を報告し、次の検査を実施した。コマンドは rtk を介して実行した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test build_info --test cli_process -- --include-ignored` | 成功。build_info 5 件、cli_process 10 件の計 15 passed、0 failed。合計 35.12 秒 |
| `cargo test -p benitoite --lib` | 成功。1194 passed、0 failed、21 ignored（既存の指定）。83.55 秒 |
| `cargo clippy --all-targets` | 終了状態 0、lint の診断なし |
| `cargo fmt --check` | 終了状態 0 |
| `git diff --check` | 終了状態 0 |
| 文書と差分の確認 | Markdown 11 ファイルのローカルリンク 77 件、R 番号の一意性、末尾改行を確認。既存の assert の個数を保ち、差分でも削除・期待値の緩和がないことを確認 |

修正後の最初の build_info 全群の実行は 4 passed・1 failed であった。loose ref の群の後片付けに使っていた `git reset --hard HEAD` が HEAD の reflog を更新し、再採取を起こしたためである。ソースの編集だけでは再採取しないという既存の期待値を保ち、後片付けを `git restore --source=HEAD --staged --worktree .` へ改めた。上表はこの修正後の結果である。

## 計画との差と申し送り

再採取条件の追加と reftable の `unknown` は、オーケストレータが指定した修正方針どおりである。実態との食い違いは R11 の番号が既存の P1 の補足と衝突した点であり、既存の内容を R12 に移して参照を揃えた。R11 にその理由も記した。構文・型の規則・脱糖は変えず、formal/ は変更していないため、lake build は実施していない。

オーケストレータは取り込み前に、段末の `check.sh --dry-run`・`--only rust,default_lib,skill` と gc-stress の検査を実施する必要がある。今回の通常構成の成功を、その検査の成功とは扱わない。後続の移行では、固定ハッシュの補足を旧 R11 ではなく R12 として参照する。
