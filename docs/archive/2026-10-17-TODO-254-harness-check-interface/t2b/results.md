# T2b testCheckReport と部分結果の接続

## 目的と変更

`test --check --report=json` を接続し、一回の探索・型検査・テストの収集から、実行せずにテストの宣言上限と部分結果を単一の JSON にする。通常の検査失敗後もほかの入口を検査し、全体の完全性と各入口の成功を区別する。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/args.rs`・`tools.rs` | `PathArgs.report` と内部の `parse_test_invocation` を接続。途中の誤りの後もオプションの範囲を走査し、全指定パスを使い方の誤りの報告に残す |
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | `SelectedEntry`・`SelectionFailure` に指定番号を保持。通常実行と報告が同じ準備の panic 境界を使い、非実行の準備で所有するテスト一覧と契約を返す |
| `crates/benitoite/src/cli/tools/test_runner/check_report.rs`（新規） | 成功・検査失敗・探索失敗・内部エラー・中断の単一報告。ソース・診断とその添字・未着手の入口を保持。直列化後に一度だけ出力 |
| `crates/benitoite/src/cli/inspection.rs`・`check_report.rs` | テスト契約と binding を照合し、main と shell の判定・ソース識別・診断の描画を共用。失敗した入口の shell は Unknown とする |
| `crates/benitoite/src/cli/mod.rs` | help の report の適用範囲と、既知の分離値を消費する名前を更新 |
| `crates/benitoite/tests/test_command.rs`・`cli_process.rs` | 契約と説明・位置・固定ハッシュ、重複、部分失敗と後続成功、空の成功、探索失敗、中断、誤りの順序、警告昇格、shell の範囲、tool の panic を CLI 境界で検証 |
| `crates/benitoite/src/cli/tools/args/tests.rs`・`formatter/tests.rs` | 既存の PathArgs の期待値・準備に report:None を追加 |
| `docs/design/06-tooling/06-01-cli.md`・`06-04-test-runner.md`・`02-impl/02-11-embedding.md` | 実装した報告、部分結果、準備の受け渡しを反映 |
| `design.md`・`decisions.md`・`harness-response.md` | R18〜R20 の内部の型と探索失敗の状態を照合し、外部へ渡す説明も揃える |
| 本書 | 共通の関門 K の検査と受け渡しの記録 |

公開の型の変更は計画どおり `PathArgs.report: Option<ReportFormat>` の追加である。公開の解析関数・test_entries・collect_tests のシグネチャ、TestFn、通常の実行結果と集計の形式は保つ。description の省略は null、明示した空は空文字列、成功したテストなしは []、未確定の tests と不完全な全体の aggregateEffects は null とする。契約の宣言上限には Assert.Check を残す。shell はプログラム全体の式の参照であり、各テストからの到達性は示さない。

AST と型表の走査・破棄は段の大きなスタック内で終え、外へは所有データだけを返す。検査・コンパイルの再実行や、ソースの再読は加えていない。非実行の準備は確認の表・脱糖・コンパイル・VM・RuntimeParts を作らず、利用者の関数と外部関数を実行しない。中断の読み口も各ファイルの開始前だけである。

## テストの作成時の関門

守る契約は、新しい報告の種類・必須欄、宣言上限、説明と位置、元のソースの識別、部分結果の完全性、診断の所属、終了状態と非実行である。現実的な退行として、Assert.Check の除去、説明の省略と空の同一視、重複対象の統合、検査失敗後の停止、未確定を空集合に補う処理、誤りの前後関係で変わる出力形式、診断の stderr への重複、中断時の未着手対象の消失を捕まえる。

通常の test と従来の test --check はこれらの JSON 欄を出さないため、既存のテストだけでは新しい対応の退行を検出できない。CLI の実ファイル・既存の捕らえる出力先・既存の中断の読み口を使い、本番の段は本物を接続した。探索失敗は既存の実ファイルの準備と権限の対照を拡張した。tool の panic は既存の BENITOITE_DEV_PANIC=tool を使う。テスト専用の本番 API・フラグ・公開範囲は加えない。

既存の assert と期待値、負の入力を保持した。削除・期待値の緩和・ignore の追加はない。既存の構造体の期待値には新しい欄 report:None だけを追加した。追加したテストの初回ではハッシュ出力の型のコンパイルエラーと IO.All の余剰宣言による W0501 の見落としがあり、新しいテストの固定ハッシュと警告二件の厳密な期待値を修正した。

## 検査

既定の機能（gc-mark-sweep）で実行した。実行には rtk を使用した。依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、21 ignored（既存の指定）、77.44秒。最終ツリーでは下記の一括コマンドでも再確認 |
| `cargo test -p benitoite --test test_command --test cli_process --test fmt_command` | 63 passed（3 suites）、0 failed、8.24秒。最終ツリーでは下記でも再確認 |
| `cargo test -p benitoite --lib --test test_command --test cli_process --test fmt_command` | 最終ツリーで1258 passed（lib 1195、統合63）、0 failed、既存の21 ignored、86.10秒 |
| `cargo clippy --workspace --all-targets` | 最終ツリーで終了状態0、診断なし |
| `cargo fmt --all --check` | 最終ツリーで終了状態0 |
| 変更した Markdown の相対リンクのファイルの存在確認 | 6ファイルの107件で成功。コード内の型の記法を除外 |
| `git diff --check` | 終了状態0 |

言語仕様・文法の生成元・診断の表・標準ソース・Skill の生成物・formal/ は変更していない。構文・型の規則・脱糖も変えていないため、R4 に従い形式化の対応表を変えず、Lean の検査と Skill の再生成は不要である。

本番の Rust は761行追加・74行削除（差し引き687行増）、テストは394行追加・削除なしである。

## 計画との差と申し送り

- R18: test の全指定パスを残すため、内部の TestParseError を使う。報告の種類は test の分岐で確定し、main 用の ReportKind::Test は追加しない。
- R19: Prepared.inspection は抽出の失敗も持つ Result とし、同じ collect_tests の TestFn 一覧を ProgramInspection と一緒に所有する。報告時の再検査・再収集を避け、説明を保つ。
- R20: 探索失敗で残す未検査の Target は checkError・complete:false とし、探索全体の E0101 の targetId は null と明記した。

T3 では、対象の一致と非実行を通常実行との同じ fixture の対照で広げ、最後に formats.testCheckReport=[1] を宣言すること。この作業ではその能力宣言を先置きしていない。引数の allow-effects は test --check との併用を拒否するだけで、実行用の上限解析・保持は A1 以降へ渡す。

scripts/check.sh と gc-stress の構成、段末の検査・レビュー・san_benito への取り込みはオーケストレータへ渡す。本書は T2b 個別作業の記録であり、段 2b 全体の完了ではない。docs/todo/ は変更せず、コミットは作成していない。
