# T1a テストの収集で欠落を内部エラーにする

## 目的と変更

検査成功後に束縛・型が欠けていてもテストの収集を続ける挙動を改め、処理系の不具合として返す。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | `collect_tests` を `Result<Vec<TestFn>, InternalError>` に変更した。入口の AST、テストの束縛・型の欠落を段名 `test` の内部エラーにする。唯一の本番呼び出し元の `compile_tests` は、失敗を既存の `PrepareError::Internal` へ写し、終了状態3の報告へ伝える |
| `crates/benitoite/src/cli/tools/test_runner/tests.rs` | 公開の `collect_tests` の欠落時の契約を表形式で確かめるテストを追加した |
| `docs/design/06-tooling/06-04-test-runner.md` | 「テストの実行」に、検査済みの情報が欠けた場合の報告と終了状態を追記した |
| 本書 | 共通の関門 K の検査と受け渡しを記録する |

公開関数の戻り値の変更は計画どおりである。正常時の対象選択・宣言順、`TestFn` の欄、`Unit` と `Result[Unit, String]` の分類、実行結果の形式は保つ。報告専用の型・欄は追加していない。AST の走査・破棄は既存の段のスタック内で行う。

## テストの作成時の関門

守る契約は、検査済みの情報の欠落を空の対象や推測した戻り値へ変換せず、内部エラーとして返すことである。束縛の表を引けないときの `continue` や、型の表を引けないときの `Result` への補完が復活すると失敗する。既存の CLI テストは正常な検査結果だけを受け取るため、この不整合には届かない。

本物の検査を通した後、入口の AST・束縛の表・型の表のうち一つだけを取り除き、公開関数の戻り値を比較する。新しい本番 API・差し込み口・フラグは不要である。正常時の選択・順序・戻り値の分類は既存の `test_command` のテストで確かめ、重複した正常系のテストは追加しない。既存の assert・期待値・ignore は変更していない。

修正前の確認では、戻り値の型と呼び出し元だけを先に更新して欠落時の旧処理を残し、次の名指しのテストを実行した。

```sh
cargo test -p benitoite --lib collecting_tests_rejects_missing_checked_metadata -- --exact cli::tools::test_runner::tests::collecting_tests_rejects_missing_checked_metadata
```

終了状態101で、三つの入力に対して `Ok([])`・`Ok([])`・`Ok([TestFn { kind: Result, ... }])` を返すことを確認した。期待する三つの内部エラーとの比較が意図した理由で失敗した。

## 検査

実行には rtk を使用した。構成は既定の機能（`gc-mark-sweep`）であり、gc-stress を指定していない。依頼の指定に従い、`scripts/check.sh` は dry-run も含めて実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、21 ignored（既存の指定）、80.68秒。追加した欠落3ケースのテストも成功 |
| `cargo test -p benitoite --test test_command` | 18 passed、0 failed、2.22秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |

本番の Rust は43行追加・15行削除（差し引き28行増）、テストは新規61行である。既存テストの削除・変更はない。

## 計画との差と申し送り

実装の計画との差はない。検査の省略は依頼で指定された `scripts/check.sh` と gc-stress の構成だけであり、オーケストレータが最後に実施する。`formal/`・`docs/todo/` は変更せず、コミットは作成しない。

T1b はこの `Result` の失敗の伝達を保ったまま準備と実行を分離すること。未実装の `Prepared.inspection` や非実行モードは追加していない。段末の共通検査と取り込みはオーケストレータへ渡す。
