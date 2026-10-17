# A2a 実行の入力と全テストの原型の事前準備

## 目的と変更

通常の test の入口ごとの準備で、RunInput の作成と全 TestFn の束縛に対応する原型の確認まで終える。run_prepared は、入力と原型を保持した同じ成果物を消費する。入力の作成に失敗した場合や原型が欠けた場合は、その入口のテストを一つも始めず、既存の処理系の不具合の診断と終了状態3を返す。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | Compiled に RunInput と PreparedTest（TestFn と原型の組）の一覧を保持する。段の準備中に入力の作成と全件の原型の検索を済ませ、実行中の作成・検索を除く |
| `crates/benitoite/src/cli/tools/test_runner/check_report.rs` | 共通の非公開 prepare_entry に作業ディレクトリを渡す。Inspect は入力や実行用の成果物を作らない |
| `crates/benitoite/tests/test_command.rs` | 既存の成果物共有テストに、後のテストが空の引数・スクリプトのディレクトリ・作業ディレクトリを使う確認を追加 |
| `docs/design/02-impl/02-11-embedding.md` | 準備の範囲、返す所有データ、入力と原型の再利用を明記 |
| `docs/design/06-tooling/06-04-test-runner.md` | 準備に失敗した入口の非実行と終了状態3を明記 |
| 本書 | 共通の関門 K、検査と申し送り |

公開の型とシグネチャ、CLI のオプションと出力形式は変更していない。内部の prepare_entry・prepare・compile_tests に作業ディレクトリの参照を渡す。欄と型は通常の本番の準備・実行と同時に接続し、将来の作業のためだけの API は置いていない。

AST・型表・コア IR は従来どおり段の大きなスタックで破棄する。RunEnv と RuntimeParts はテストごとに新しく作り、入口ごとの成果物の共有で実行状態を共有しない。通常の test は一つの入口の実行後に次の入口を準備する。test の上限指定は追加していない。

## テストの作成時の関門

守る契約は、同じ入口の全テストが準備済みのプログラム・原型・実行の入力を使い、ソースの再読をせず、次の入口は現在の入口の実行後に準備することである。現実的な退行は、移した入力の渡し忘れや誤ったディレクトリの設定、原型とテストの取り違え、ソースの再読や全入口の先行準備である。

主となる境界は CLI の実行・出力・ファイル状態とした。既存の prepared_sources_are_reused_and_the_next_file_is_prepared_after_execution は、先のテストで入口と依存を書き換え、次の入口を有効なソースへ直すことで、成果物の再利用と逐次の準備を確かめている。このテストには実行の入力の確認がなかったため、後のテストから Process.arguments・scriptDirectory・workingDirectory を読み、独立した期待値と比較する確認を加えた。新しいテスト関数や同じ契約の別の層のテストは追加していない。

全原型の確認が終わる前に実行を始める経路がないことは、Compiled の構築と消費も読んで確認した。全件の検索が Result<Vec<PreparedTest>, PrepareError> として成功した場合だけ Compiled を構築し、run_prepared はその一覧だけを順に消費する。正しいソースから作れない検査済み成果物の欠落のために、本番のフックや段の差し替えは追加していない。

既存の assert・期待する出力・負の入力は保持した。削除、期待値の緩和、ignore の追加はない。入力の確認で IOError を伝えられるように、このテスト入力の後の関数を Unit から Result[Unit, String] へ変えた。テストの成功条件と期待する出力は変わらない。

Rust の本番コードは63行追加・25行削除（差し引き38行増）、テストは8行追加・1行削除（差し引き7行増）である。テストの削除1行は、この戻り値とエフェクトの宣言の置き換えであり、assert の削除ではない。

## 検査

既定の構成（gc-mark-sweep）で実行した。コマンド出力の整理には rtk を使った。依頼に従い scripts/check.sh は dry-run も含め実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test test_command` | 29 passed、0 failed（2.68秒） |
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、既存の21 ignored（76.99秒） |
| `cargo test -p benitoite --test cli_process --test interrupt_process` | 30 passed、0 failed（2 suites、16.61秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した設計書の相対リンクの確認 | 2文書の相対リンク56件で参照先の存在を確認 |
| `git diff --check` | 終了状態0 |

## 計画との差と申し送り

作業の範囲と実装順のずれはない。check_report.rs の変更は、共通の非公開の準備関数へ新たに渡す作業ディレクトリの受け渡しだけである。新しい設計判断を要する食い違いはなく、decisions.md への R の追加はない。

A2b は、各入口の Prepared が入力と全テストの原型まで保持できる状態を使い、test の上限の解析・全入口の保持・全体の開始条件へ接続できる。A2a では PathArgs.allow_effects と PrepareMode::ExecuteLimited は加えていない。

scripts/check.sh、gc-stress の構成、段末の検査、G4 のレビューと san_benito への取り込みはオーケストレータへ引き継ぐ。本書は A2a 個別作業の記録であり、段3全体を完了扱いにしない。formal/・構文・型の規則・脱糖は変更していないため、lake build は不要である。docs/todo/ は変更せず、コミットは作成していない。
