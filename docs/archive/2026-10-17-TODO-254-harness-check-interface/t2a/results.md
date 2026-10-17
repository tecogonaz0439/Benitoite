# T2a 通常 test と非実行で共有する探索結果

## 目的と変更

通常の `test`、`test --check`、公開の `test_entries` を、内部の `select_test_entries` へ接続した。一回の探索で入口一覧と完了・失敗を返し、失敗より前の指定パスについて選び終えた入口を保持する。今回の呼び出し元は、探索失敗時には部分一覧を捨て、検査も実行も始めない。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | 非公開の `EntrySelection` と `select_test_entries` を追加。通常実行と非実行の共通入口は失敗を E0101・終了状態2へ、公開入口は既存の Err へ写す |
| `crates/benitoite/tests/test_command.rs` | 既存のディレクトリのテストに直接指定との混在・重複・根と表示名の比較を追加。既存の探索失敗のテストに非実行と公開入口の対照を追加 |
| `docs/design/06-tooling/06-04-test-runner.md` | 共有する探索、順序・重複、部分結果と探索失敗時の扱いを反映 |
| `design.md`・`decisions.md` | 完了と失敗の表現を R17 として記録し、設計案の型を実装に合わせる |
| 本書 | 共通の関門 K の検査と受け渡しを記録 |

公開の型・シグネチャは変えていない。内部の `completion: Result<(), (PathBuf, std::io::Error)>` が完了と失敗を表す。直接指定の親を根とする規則、ディレクトリ指定の根、下位パッケージの除外、辞書順、指定順と重複、リンクと存在しないパスの扱いは変えていない。共有のディレクトリ走査を変更せず、fmt の呼び出し元も保つ。探索の再実行、ソースの再読、AST の走査・破棄の変更はない。

## テストの作成時の関門

守る契約は、公開入口が返すパス・根・表示名と指定順・重複、CLI が実際に実行する入口の一致、探索失敗時にどの入口も開始しないこと、失敗のパス・IO の種類と既存診断の維持である。重複の除去、全体の並べ替え、直接指定の根の変更、探索が終わる前の実行・検査、失敗を空の成功へ変える退行で失敗する。

既存のディレクトリのテストは単一指定の通常実行を、既存の探索失敗のテストは通常実行だけを確認していた。同じ実ファイルの準備を使い、公開入口では値として返す根・表示名を、CLI では実行対象の出力全文と非実行の結果を比較する。探索失敗の非実行では、先に誤ったソースを指定し、その診断も出ないことから検査開始前の停止を確かめる。公開入口では Err のパスと `PermissionDenied` を確認する。外部のファイルだけを実物で用意し、本番の段は本物を接続する。テスト専用の本番 API・フラグは不要である。

既存の assert・期待値・負の入力はすべて保った。テストと assert の削除、期待値の緩和、ignore の追加はない。

## 検査

既定の機能（`gc-mark-sweep`）で実行した。実行には rtk を使用した。依頼に従い `scripts/check.sh` は dry-run も含めて実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、21 ignored（既存の指定）、76.68秒 |
| `cargo test -p benitoite --test test_command --test fmt_command` | 38 passed（2 suites）、0 failed、2.16秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |

言語仕様、文法の生成元、診断の表、標準ライブラリのソース、Skill の埋め込み、`formal/` は変更していない。仕様例の検査、Skill の再生成、Lean の検査は本作業の対象ではない。

本番の Rust は34行追加・5行削除（差し引き29行増）、テストは43行追加・削除なしである。

## 計画との差と申し送り

R17 の小さな変更として、設計案の `complete: bool` と `failure: Option<_>` を `completion: Result<(), _>` にまとめた。矛盾した状態を型で除き、報告用の完了値はこの結果から求める。公開契約の変更はなく、harness-response.md は変更していない。

T2b では `entries` を `SelectedEntry`、失敗を `SelectionFailure` に変え、指定番号と報告へ接続すること。探索失敗で保持した一覧は参考の部分結果であり、検査・実行を開始してはならない。report、request_index、inspection、形式の機能宣言は追加していない。

`docs/todo/` を変更せず、コミットは作成しない。`scripts/check.sh` と gc-stress の構成、段末の検査と取り込みはオーケストレータへ渡す。本書は T2a 個別作業の記録であり、段 2b 全体を完了とするものではない。
