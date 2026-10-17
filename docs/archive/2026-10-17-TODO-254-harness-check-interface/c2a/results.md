# C2a オプションの範囲と報告する使い方の誤り

## 目的と変更ファイル

check のスクリプトより前のオプションの範囲を、最初の誤りの後も走査する。有効な `--report=json` があれば、引数の順序によらず使い方の誤りを単一の checkReport に収め、終了状態2を返す。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/mod.rs` | CliParseError・ReportKind::Check・共通の parse_invocation、最初の誤りと指定パスの保持、分離値の消費、invoke の報告への接続、run の report 拒否の文言 |
| `crates/benitoite/src/cli/check_report.rs` | usageError の必須欄、指定パスと null、ディレクトリに main.bnt がない場合の接続 |
| `crates/benitoite/tests/cli_process.rs` | 解析の順序と範囲を対照する、CLI 境界の一つの受け入れ表 |
| `docs/design/02-impl/02-10-diagnostics.md` | 報告内だけの kind:check・code:null と、文章による使い方の誤りの例外 |
| `docs/design/06-tooling/06-01-cli.md` | 走査の範囲、分離値、usageError の形式と出力先・終了状態 |
| `design.md`・`decisions.md` | R13 の分離値の扱いと、内部の CliParseError が保持する指定パス |
| 本書 | 共通の関門 K、検査結果、後続作業への受け渡し |

## 型・契約と所有

公開の `parse_args(Vec<OsString>) -> Result<Command, String>` は保ち、共通の内部解析のエラーから detail だけを返す。プロセスの入口 invoke は同じ解析の report と script を使い、使い方の誤りを報告へ包む。Options・Command・既存の診断の型と公開シグネチャは変更していない。ReportKind は読む本番処理のある Check だけで、Test は追加していない。

解析は最初の誤りを保持し、スクリプトより前で有効な report を一つでも認識すれば usageError の形式を選ぶ。重複や未知値のエラーでも走査を続ける。併用条件は走査後に検査し、明示 diagnostics=text と、省略時の既定値を seen で区別する。パス以後の字面や、既知のオプションの分離値は report として読まない。分離した値の指定は従来どおり拒否する（R13）。既存の `--` の解釈は拡張していない。

使い方の誤りでは complete・targetsComplete・executed は false、targets・sources・sourceSets は空配列、aggregateEffects は null とする。指定パスが分かれば requestedTargets に残し、パスがなければ空配列にする。位置とコードを持たない一件の説明を diagnostics に収め、diagnosticTargets の targetId は null とする。ディレクトリに main.bnt がない場合も同じ経路を使う。標準エラー出力へ診断を重ねて書かない。報告の書き込みに失敗すれば既存の write_plain の終了状態1を返す。

kind:check・code:null の組み合わせは、checkReport の usageError 内だけに追加した。既存の診断の JSON Lines と形式1は変更していない。ソースを読む前の誤りを扱い、検査の再実行やソースの再読、型とエフェクトの受理規則の変更はない。

## test-audit の作成時の関門

- 守る契約は、誤りと有効な report の順序に依存しない単一報告、最初の誤りの選択、スクリプトと分離値による範囲、usageError の全必須欄、出力先・終了状態である。
- 現実的な退行は、最初の誤りで解析を止めて報告を文章へ変えること、全引数の字面だけで report を選ぶこと、分離値を新たな report 指定と取り違えること、未確定の対象を成功した空集合へ補うことである。
- 既存の成功・検査失敗の表では、解析で停止する誤りを捕まえられない。CLI 境界の一つの表へ、diagnostics=text と未知オプションの正逆順、複数の誤り、重複、未知値、パスなし、main.bnt なし、report のない誤り、スクリプト以後と分離値の対照をまとめた。報告は JSON 全体、文章は二行の全文を比較する。run のスクリプト引数に同じ字面があっても通常の実行になることも確認する。
- 実プロセスと実ファイルを使い、テスト専用の本番 API・フラグ・大域の状態を追加していない。変更前の本番コードで新しい表を走らせ、最初の diagnostics=text/report のケースが、文章を標準エラー出力へ返すために失敗することを確認した。変更後は同じ表が通る。

既存の assert・期待値・ignore は変更せず、テストを削除していない。本番コードは167行追加・47行削除（差し引き120行増）、テストは284行追加・削除なしである。

## 検査

実行には rtk を使った。依頼に従い scripts/check.sh は dry-run も含めて実行していない。classify を読み、Rust の変更は crates/* により rust、設計書と作業記録は追加の検査なしに分類されることを確認した。check.sh と gc-stress の最終検査はオーケストレータへ渡す。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1194 passed、0 failed、21 ignored（既存の指定、87.39秒） |
| `cargo test -p benitoite --test cli_process --test test_command --test fmt_command --test package_command` | 58 passed、0 failed（4 suites、7.92秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、lint の診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `git diff --check` | 終了状態0 |
| 変更した文書内のローカルリンク | 148件の参照先が存在 |

最終の差分確認は、作業記録の確定後にも実施した。

変更前の新しい表の実行は、意図した理由で失敗した（終了状態101）。この失敗は退行の検出を確かめるものであり、変更後の検査の失敗ではない。

## 計画との差と申し送り

R13 に、分離した値の指定を受理せずに消費する解釈と、内部の CliParseError に script を加える最小の変更を推す案として記録した。公開 API と harness-response.md の合意済みの契約は変更していない。構文・型の規則・脱糖・formal/ は変更せず、R4 の判定を保つ。診断コードの表・標準ソース・Skill の生成元も変更していないため、gen_skill は不要である。docs/todo には触れず、コミットしていない。

C2b は、報告モードの確定後の panic 境界と書き込み失敗、prelude_error・deny_warnings の分類の検証を担当する。報告途中の内部エラーをすべて単一報告へ包む処理は今回の完了に含めない。C3 の受け入れ表と formats.checkReport=[1] の宣言も残る。T2b は ReportKind::Test と test の内部解析・非実行の報告を、読む本番処理と同時に加える。G2 のレビュー・段末検査、scripts/check.sh、gc-stress はオーケストレータの作業として残る。
