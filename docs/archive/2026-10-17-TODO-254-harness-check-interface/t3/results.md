# T3 対象の一致と非実行の検証

## 目的と変更

同じ実ファイルを通常の `test`、`test --check`、`test --check --report=json` へ渡し、入口と関数の選択が一致することを確認した。Console の両出力と目印ファイルへの書き込みを、同じ入口の通常実行との対照で検証した。確認した報告形式を `formats.testCheckReport=[1]` で宣言する。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/tests/test_command.rs` | 共有 fixture と独立した期待表による対象比較を追加。既存の非実行の検査に JSON 報告と通常実行の対照を追加 |
| `crates/benitoite/src/cli/mod.rs` | version JSON の `formats` に `testCheckReport: [1]` を追加 |
| `crates/benitoite/tests/cli_process.rs` | version JSON 全体の厳密な期待値に、提供する形式を追加 |
| `docs/design/06-tooling/06-01-cli.md` | 提供する五つの形式と契約を記載 |
| `docs/design/06-tooling/06-04-test-runner.md` | 重複と異なる根、リンクの直接指定、Assert.Check の保持、形式の問い合わせを明記 |
| 本書 | 共通の関門 K と G3 の対象・検査の対応、引き継ぎを記録 |

公開の型とシグネチャは変えていない。公開契約の変更は、計画どおり、提供済みの報告形式を version JSON に追加したことである。harness-response.md の予定する形式1と一致し、契約の変更はない。対象選択・検査・実行の本体を変えず、大域の状態・本番 API・フラグ・unsafe・追加の検査やソースの再読を加えていない。

## テストの作成時の関門

守る観測可能な契約は、報告と通常実行の対象の順序・重複・根・関数の一致、非実行モードでの副作用の不在、Assert.Check の保持、利用可能な形式の自己申告である。現実的な退行として、報告時だけの重複排除、requestIndex のずれ、同名の表示パスによる入口の統合、下位パッケージや import 先のテストの混入、リンクの走査、非実行モードからの実行、確認用のエフェクトの除去を捕まえる。

従来の個別の探索・報告テストには、同じ fixture を三つのモードで比較する対照がなく、Console と目印ファイルを通常実行した場合との差も確認していなかった。主となる境界を実際の CLI の入口と出力・ファイル状態に置き、同じ入力を使う表へまとめた。テストのための本番 API・公開範囲の拡大・差し替えは不要である。

既存の assert と負の入力をすべて保持した。削除、期待値の緩和、ignore の追加はない。version JSON の期待値は、変更前の四形式から変更後の五形式へ変え、オブジェクト全体の等値比較を保った。新しい表の初回実行では、一時ディレクトリ自身の表示名が既存の出力正規化の対象外だったため失敗した。存在しない入力の役割を変えず、同じ fixture 内の suite/missing.bnt で E0101 と後続の成功を比較した。

## G3 の対象と結果の対応

| 対象・契約 | 主な検査 |
|---|---|
| 直接指定、ディレクトリ経由、指定順と重複、同じ表示パスで異なる根 | `check_report_and_execution_select_the_same_entries_and_functions`。指定番号・入口・根・関数列を独立した期待表と比較し、通常実行の関数列・集計とも照合 |
| 下位パッケージの除外と、その根を直接指定した場合の採用 | 同じ表の suite と suite/deps。package.bnt と非ソースのファイルも入口から除外 |
| ファイル・ディレクトリ・切れたリンクの走査からの除外 | Unix の同じ fixture にリンクを配置し、suite の期待列が増えないことを確認 |
| 明示したファイルとディレクトリのリンク | Unix の同じ表に直接指定の二行を追加し、入口の表示名と根、実行関数列を比較 |
| ないパス、空ディレクトリ、テストなしのファイル | 同じ表で E0101 と後続の成功、targets=[] と tests=[] の違い、通常実行の集計、報告なしの診断を比較 |
| import 先の @test | suite/tests.bnt の直接指定は usesLib だけ、suite の走査では Lib/Text.bnt 自身も入口として libTest を含む |
| 非実行と通常実行の副作用 | `check_does_not_run_user_code_or_write_result_lines`。非実行の両モードでは出力・変更なし、通常実行では Console の stdout/stderr と marker.txt の内容を確認 |
| Assert.Check を各テストと和から除去しない | 同じ非実行の対照と既存の `check_report_preserves_contracts_descriptions_locations_and_source_identity`。省略する本番処理の追加なし |
| 部分失敗・警告昇格・中断・説明・ソース識別・tool の panic | T2b の既存の test_command / cli_process の検査を変更せず再実行 |
| formats の提供済み能力だけの宣言 | cli_process の version JSON 全体の比較。testCheckReport=[1] を追加し、未提供の能力は引き続き出さない |
| 共有探索の fmt への影響 | fmt_command 全体 |

## 検査

既定の機能（gc-mark-sweep）で実行し、rtk を使用した。依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test test_command --test fmt_command` | 対象の表と非実行の対照の追加後、44 passed、0 failed（2 suites、3.55秒） |
| `cargo test -p benitoite --lib --test test_command --test fmt_command --test cli_process` | 能力宣言を含む最終の Rust のツリーで1259 passed、0 failed、既存の21 ignored（4 suites、90.23秒） |
| `cargo clippy --workspace --all-targets` | 最終の Rust のツリーで終了状態0、診断なし |
| `cargo fmt --all --check` | 最終の Rust のツリーで終了状態0 |
| 変更した Markdown の相対リンクのファイルの存在確認 | 3ファイル、61件で成功 |
| `git diff --check` | 終了状態0 |

本番の Rust は2行追加・1行削除（差し引き1行増）、テストは232行追加・1行削除（差し引き231行増）である。削除した1行は version JSON の全体比較の期待値の置き換えであり、assert の削除ではない。

## 計画との差と申し送り

計画からのずれはなく、新しい R の判断は不要である。言語仕様・構文・型の規則・脱糖・formal/・診断表・標準ソース・Skill の生成元と生成物は変更していない。Lean の検査と Skill の再生成は不要である。

scripts/check.sh と gc-stress の構成、T3 の段末検査、G3 のレビュー、san_benito への取り込みはオーケストレータへ渡す。本書は T3 個別作業の記録であり、段 2b 全体の完了ではない。A1 以降のエフェクト上限の実装は加えていない。docs/todo/ は変更せず、コミットは作成していない。
