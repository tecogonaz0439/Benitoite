# T1c report なしの test --check

## 目的と変更

`test --check <パス>...` を接続した。通常の `test` と同じ探索とファイルごとの準備処理を使い、`main` を要求せず読み込みから型検査まで行う。成功時も標準出力は空であり、診断は既存の形式で標準エラー出力へ出す。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/args.rs` と `args/tests.rs` | 既存の `PathArgs.check` を test でも受理する。明示された `--max-call-stack` と全 `--wasm-*` は、既定値と同じ値でも `--check` との併用を拒否する。Wasm の抽出時に使う既存の集合を併用の判定にも使う |
| `crates/benitoite/src/cli/tools.rs` | 非実行では Wasm の実行設定と統計の生成・報告へ進まない分岐を接続する |
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | `PrepareMode::Inspect/Execute` を追加し、非実行では型検査と診断の出力だけを行う。通常の検査の誤りなら次の入口へ進む。結果と集計は出さない |
| `crates/benitoite/src/cli/mod.rs` | 実装した `test --check` をヘルプに反映する |
| `crates/benitoite/tests/test_command.rs` | 非実行、診断の継続、警告の扱い、明示した実行用オプションの拒否、中断の確認位置を CLI の境界で確かめる |
| `docs/design/06-tooling/06-01-cli.md`・`06-04-test-runner.md`・`docs/design/02-impl/02-11-embedding.md` | 実装した範囲、出力、終了状態、所有と破棄、中断の限界を反映する |
| 本書 | 共通の関門 K の検査と受け渡しを記録する |

公開の型の欄と関数のシグネチャは変えていない。既存の `PathArgs.check` の受理範囲を広げ、非公開の `prepare` に計画どおりモードを渡す。`Inspect` は `compile_tests` へ入らないため、AssertTable・脱糖・コンパイルを行わない。診断を出した後は実行用の入力・VM・RuntimeParts を作る前に戻る。AST と型表は段のスタック内で破棄し、検査を再実行したりソースを開き直したりしない。中断は R8 の入口の開始前だけで確認する。

## テストの作成時の関門

守る契約は、型検査が成功しても利用者コードを実行せず結果と集計を出さないこと、通常の検査の誤りの後も次の入口を検査すること、警告と `--deny-warnings` の扱い、実行用オプションの明示の保持、中断の確認位置である。実行への誤った接続、最初の誤りでの終了、既定値と明示値の混同、ファイルの後や最後の追加の中断確認があれば失敗する。

既存の CLI テストは通常の実行を対象とし、この非実行の契約を確かめていない。実行の失敗・Process.exit・出力を含む既存の MIXED 入力を再利用し、実ファイルへの書き込みも確認する。テストのないファイルと空ディレクトリも同じ表で確かめる。診断は文章と JSON Lines の双方で確認し、二つの誤った入口を与えた場合の結果を各入口の結果と比較する。中断は既存の外部依存 `InterruptSource` を使い、確認回数と終了状態を対照にする。本番の段は本物をつなぎ、テスト専用の本番 API・フラグ・差し込み口は加えていない。

意図した契約変更として、既存の「test は --check を拒否する」ケースを、受理と非実行の成功ケースへ変更した。引数のテストは同じ `--check a.bnt` の入力を保ち、従来の Err から、全欄を比較する Ok へ変えた。CLI のテストは実在する入口に常に失敗する Assert を書き、従来の使い方の誤り・終了状態2・二行の stderr から、終了状態0・stdout/stderr とも空へ変えた。assert の削除・期待値の緩和・ignore の追加は行っていない。ほかの既存の負の入力と、その拒否理由は変えていない。

## 検査

既定の機能（`gc-mark-sweep`）で実行した。実行には rtk を使用した。依頼に従い `scripts/check.sh` は dry-run も含めて実行せず、gc-stress も指定していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、21 ignored（既存の指定）、78.10秒 |
| `cargo test -p benitoite --test test_command --test fmt_command` | 38 passed（2 suites）、0 failed、2.12秒 |
| `cargo test -p benitoite --test cli_process --test interrupt_process` | 28 passed（2 suites）、0 failed、16.55秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |

追加した二つの相対リンクは、参照先ファイルと見出しの存在を確認した。言語仕様・文法の生成元・診断の表・標準ライブラリのソース・`formal/` は変更していないため、仕様例の検査、Skill の再生成、Lean の検査は本作業の対象ではない。

本番の Rust は70行追加・21行削除（差し引き49行増）、テストは174行追加・24行削除（差し引き150行増）である。削除行は表の期待値と報告処理の移動・整形に伴うものであり、テストと assert を削除していない。

## 計画との差と申し送り

計画と異なる設計判断はない。計画の列挙したファイルに加え、既存のヘルプが fmt だけを案内していたため、同じ契約の反映として `cli/mod.rs` の文言を更新した。R の追加は不要である。harness-response.md の公開契約は変えていない。

T2a は探索結果の共通化、T2b は `inspection` と report の接続を行うこと。`PathArgs.report`・`allow_effects`・`ExecuteLimited` は追加していない。形式の宣言も増やしていない。`formal/`・`docs/todo/` を変更せず、コミットは作成しない。`scripts/check.sh` と gc-stress の構成、段末の検査と取り込みはオーケストレータへ渡す。
