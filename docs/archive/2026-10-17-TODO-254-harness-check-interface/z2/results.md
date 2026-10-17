# Z2 G2 の指摘の修正

## 変更

[G2 の全文](../reviews/G2.md)を保存し、指摘1〜7を修正した。`notes/Z2.md` は作業ディレクトリに存在しなかったため、依頼に添付されたレビュー本文をそのまま保存した。

| 指摘 | 変更ファイルと結果 |
|---|---|
| 1 | `docs/design/02-impl/02-01-pipeline.md` に `types.expr_types` との照合、ハンドラの操作名の除外、本体の式を含める規則を追記した |
| 2 | `harness-response.md` の BH-022 と `design.md` の段2で、checkReport の検査失敗は `main: null`、`unknown` は testCheckReport の Target の値、と区別した |
| 3 | `cli/check_report.rs` で標準ソース内の誤りを内部エラーの診断一件へ置き換えた。06-01・design・harness-response にも記した |
| 4 | `types/builtin.rs` の `effect_name` に正規名への変換を集約し、`types/mod.rs` の型表示と `cli/inspection.rs` の報告用の検証から呼ぶ。A1 を待たずに実施した |
| 5 | `tests/cli_process.rs` の既存のコンパイル制限のテストに check --report=json を追加し、終了状態0・status ok・空の診断・L0112 なしを確認する |
| 6 | 同ファイルの35件を契約・検査失敗・警告・制御フロー・shell・ソースの六つの #[test] に分割し、確認処理を共用した |
| 7 | 06-01 の分離値の段落に、消費規則がコマンドの語を選ぶ走査にも及ぶと一文追記した。design・harness-response も合わせた。引数解析の実装は変更していない |

Rust のパスは `crates/benitoite/` からの相対パスである。コミットは作成せず、docs/todo/ と formal/ は変更していない。

## テストの作成時の関門と所要時間

追加した観測は、報告モードの check も脱糖・コンパイルへ進まず、通常の check と同じ入力で成功するという CLI の契約である。報告経路を誤ってコンパイルにつないだ場合は L0112 が現れ、終了状態・status・診断の比較が失敗する。既存の通常 check/run/test の比較は報告モードを通らないため、この分岐の退行を捕まえない。同じテストの入力を共有し、本番の差し込み口・公開 API・フラグは追加していない。既存実装の不足していた観測を追加したものであり、この点の本番コードの修正はない。

35件の元の入力行がすべて変更後にも同一の字面で残り、共通の確認ループが変更前と完全一致することを独立に照合した。既存の assert・期待値・入力は削除せず、ignore も追加していない。群の一つが失敗しても、ほかの群は独立したテストとして実行できる。

分割前は `cargo test -p benitoite --test cli_process main_check_reports_contracts_sources_and_failures_without_execution -- --exact` を実行し、成功した。テスト本体6.32秒、`/usr/bin/time -p` の実時間11.82秒（ビルドなどを含む）だった。

分割後は `cargo test -p benitoite --test cli_process --no-run` で作ったテスト実行ファイルを、各群の `--exact main_check_reports_<群>_without_execution` で順に起動し、Python の `time.monotonic()` でプロセス全体を測った。ライブラリテストと同時に実行しており、測定値はこの環境での一回の観測である。

| 群 | 入力数 | 実時間 | 結果 |
|---|---:|---:|---|
| `contracts` | 6 | 3.291 秒 | 成功 |
| `failures` | 7 | 0.608 秒 | 成功 |
| `warnings` | 2 | 0.346 秒 | 成功 |
| `control_flow` | 7 | 2.708 秒 | 成功 |
| `shell` | 9 | 2.061 秒 | 成功 |
| `sources` | 4 | 0.769 秒 | 成功 |

六群とも10秒未満であり、大きさそのものを確かめるテストでもない。AGENTS.md の基準で長いテストの印は不要と判断し、通常の検査で実行する。

## 検査

実行には rtk を使用した。依頼の指定に従い、scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定）、100.86秒 |
| `cargo test -p benitoite --test cli_process --test test_command --test golden` | 39 passed、0 failed（3 suites）、72.77秒 |
| `cargo clippy --all-targets` | 終了状態0、診断なし |
| `cargo fmt --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |
| 35件の入力・共通の確認ループの照合 | すべて維持 |

本番の Rust は26行追加・26行削除（差し引き0）、テストは74行追加・26行削除（差し引き48行増）である。テストの削除行は群への再配置と共通の確認処理への移動であり、ケースや assert の削除はない。

## 計画との差と申し送り

R16 に、共通の名前変換では型表示の `IO.All` を保ち、報告側が未展開の `IO.All` を拒否する最小の判断を推す案として記録した。正規名の共通化を今回行うこと自体はオーケストレータの指定どおりである。型・公開シグネチャ・報告の形式は変更していない。

A1 の上限の解析は `types::builtin::effect_name` を使い、`IO.All` を受理しないこと。test 側の報告でも shell はハンドラの操作名を除き、本体の式を含めること。scripts/check.sh と gc-stress を含む最終検査、取り込みとコミットはオーケストレータに委ねる。
