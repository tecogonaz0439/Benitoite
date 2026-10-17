# C1a run/check の段の準備処理の共有

## 目的と変更ファイル

`execute_script` 内の検査・任意のコンパイル・AST と中間表現の破棄・panic 境界を、非公開の `prepare_script` へ移した。既存の `run` と `check` はともにこの準備関数を使う。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/mod.rs` | `PreparedScript` と `prepare_script` を追加し、既存の実行へ接続 |
| `crates/benitoite/tests/cli_process.rs` | 既存の表へ `run` のコンパイル制限、`check` の text/JSON の panic の対照を追加 |
| `docs/design/02-impl/02-01-pipeline.md` | 共有する準備処理、所有する結果、破棄と panic の扱いを記載 |
| 本書 | 共通の関門 K、検査結果、後続作業への受け渡し |

## 型・契約と所有

公開の型と関数のシグネチャは変更していない。非公開の `PreparedScript` は、従来の組で返していた `CheckResult`・任意のコンパイル結果・`Verb` だけを持つ。`CheckResult.program` は常に `None` として返し、AST と型表を外へ保持しない。report/inspection の型・欄・関数は追加していない。

ソースの読み込みと検査は従来どおり一度だけ行う。`require_main: true`、`deny_warnings` の伝達、標準ライブラリの誤りによるコンパイルの抑止、検査の診断を先に報告する順序を保った。AST と中間表現の走査・破棄は従来と同じ段のスレッド内で行う。`CliEnv` は準備関数へ渡さず、診断の描画と実行は呼び出し側で行う。

準備の外側・段の内側・コンパイルの panic 境界を維持した。準備自体の失敗は既存の `internal_diagnostic` で所有する診断へ変換し、呼び出し側が空のソース表と既存の renderer で出力して状態3を返す。段と呼び出し側のスレッドの区別を保ち、コンパイルの panic・制限・内部エラーも従来のコンパイル結果として返す。

## test-audit の作成時の関門

- 守る契約は、`check` がコンパイルせず標準出力も空であること、`run` がコンパイル制限を検査の失敗として返すこと、`check` の準備中の panic が text/JSON とも状態3・段のスレッドの不具合となることである。
- 現実的な退行は、共有化により `check` でも脱糖・コード生成すること、逆に `run` がコンパイルしないこと、`check` が共通の panic 境界を迂回してプロセスを異常終了させたり既定の hook の出力を混ぜたりすることである。
- 既存の段の選択の表は `check` と `test` だけ、既存の検査の panic の表は `run` だけを確かめていた。同じ CLI 境界の表に不足する対照を追加した。新しい単体テストは作らず、警告・`main`・位置・深い型・標準ソースの誤りは既存テストを利用する。
- テスト専用の本番 API やフラグは追加していない。実プロセス・実ファイル・既存の開発用 panic 指定を使う。既存の assert と比較の厳密さは保ち、ignore は追加していない。不具合修正ではなく振る舞いを保つ作り直しであり、追加の対照も従来の契約を確認するものである。

本番コードは86行追加・69行削除（差し引き17行増）、テストは46行追加・37行削除（差し引き9行増）である。削除したテストはない。

## 検査

実行には `rtk` を使用した。依頼の指定に従い、`scripts/check.sh` は dry-run も含めて実行していない。`classify` を読み、変更した Rust ファイルは `crates/*` により rust、文書は追加の検査なしに分類されることを確認した。gc-stress と `check.sh` の最終検査はオーケストレータへ渡す。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test cli_process --test interrupt_process` | 19 passed、0 failed（2 suites、16.19秒） |
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定、80.07秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、lint の診断なし |
| `cargo fmt --all --check` | 終了状態0。初回の整形差分は `cargo fmt --all` で修正して再検査 |
| `git diff --check` | 終了状態0 |
| 変更した現行設計書内のローカルリンク | 76件の参照先が存在することを確認 |

## 計画との差と申し送り

実装の範囲と公開契約に計画からの変更はなく、新しい R の判断は不要であった。構文・型の規則・脱糖・formal/ は変更していない。診断表・生成元・生成物・harness-response.md・docs/todo は変更せず、コミットも行っていない。

C1b では `prepare_script` の段の内側で、検査済みプログラムが存在する間に契約を抽出する。検査のやり直しやソースの再読を加えず、抽出した所有データだけを `PreparedScript` に追加する。深い AST の破棄を呼び出し側へ移さない。

本作業の検査は C1a の範囲だけを対象とする。G2 のレビューと段末の検査、gc-stress、`scripts/check.sh` の実行はオーケストレータの作業として残る。
