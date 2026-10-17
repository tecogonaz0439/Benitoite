# Z3 G3 のレビューの指摘の修正

## 変更

G3 の軽微な指摘1・2・3・5・6を修正した。指摘4は申し送りに従い、A1 までの暫定の扱いを R21 に記録し、実装は変えていない。[レビューの全文](../reviews/G3.md)は依頼に添付された本文をそのまま保存した。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/test_runner/check_report.rs` | 各入口の準備直後にソースの識別情報とハッシュ・診断・テストを JSON にし、次の入口へ進む前に SourceTable を解放する。Target には CheckResult を保持しない。状態は非公開の enum にし、報告の文字列と終了状態を網羅する match で求める。panic の結果を一度 Result へ写し、未到達の成功分岐を除く |
| `crates/benitoite/src/cli/tools/args.rs` | 公開の `parse_path_args(PathTool::Test, …)` は wasm の全四オプションを未知のオプションとして拒否する。CLI は同じ内部解析の wasm を受ける経路を使う。fmt の到達しない Test の分岐と、本番から呼ばれなくなった内部ラッパーを除く |
| `crates/benitoite/src/cli/tools/args/tests.rs`・`src/cli/mod.rs` | 既存の引数テストへ公開入口での拒否の対照例を加え、既存の wasm の検査は CLI が使う解析入口へ接続する |
| `crates/benitoite/tests/test_command.rs` | 空ディレクトリ・テストなし・ないパスの確認を対象選択の表へ移す。部分失敗のテストは、検査失敗後の成功の保持と診断の添字に絞る。非実行のテストは、Console とファイル書き込みを伴う二入口を報告でも対照する |
| `docs/design/02-impl/02-11-embedding.md`・`../design.md` | 報告で保持する情報とソースの解放の時期を実装に合わせる |
| `../decisions.md` | R18 に文章の誤りの選択順の変更を補足し、R21 に A1 までの暫定の扱い、R22 に公開の解析入口で拒否する判断を記録する |
| `../reviews/G3.md`・本書 | レビューの全文と修正・検査・申し送りを保存する |

公開の型・シグネチャと JSON の必須欄・状態・終了状態は変えていない。ソースの再読・再検査・再コンパイルは加えていない。構文・型の規則・脱糖・formal/・Skill の生成元には触れていない。

## テストの作成時の関門と移動した確認

追加した対照例が守る契約は、WasmOptions を返さない公開入口が指定を受理して捨てないことである。CLI の wasm のテストは WasmOptions を返す別の入口を通るため、この退行を捕まえない。既存の公開入口の引数テストへ四オプションの拒否を加え、本番の公開範囲やテスト用の差し込み口は増やしていない。

修正前のコードで `path_arguments_accept_check_and_reject_usage_errors` を実行し、`--wasm-memory=64MiB` が Err ではなく Ok になるため失敗することを確認した。修正後の結果は下表に記す。ソース保持と状態の内部表現の変更には、実装を写すテストを加えず、既存の CLI 境界の成功・失敗・中断・panic・ソースの識別のテストを通す。

指摘6の移動元は `check_does_not_run_user_code_or_write_result_lines` と旧 `check_report_keeps_partial_failures_and_empty_successes_distinct`、移動先は `check_report_and_execution_select_the_same_entries_and_functions` である。いずれも T2b・T3 で同じ報告契約を重ねたもので、呼び出し先は本番の test の CLI である。空ディレクトリの targets と空の aggregateEffects、テストなしの tests:[]、ないパスの tests:null・sourceId:null を、実行・非実行・報告の同じ対象選択の表で確かめる。既存の assert は移動し、期待値を緩めず、ignore も加えていない。部分失敗の対象数は、テストなしの入口を表へ移した準備に合わせて4から3へ変更し、診断の所属の期待値は保った。

移動後も test_command.rs の assert_eq! は237件、assert! は49件、テストは29件であり、変更前と同数である。cli/mod.rs の既存の assert もすべて保持した。移動のためだけの本番コードや補助関数は加えていない。

## 検査

既定の構成で実施した。依頼に従い、scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib cli::tools::args::tests::path_arguments_accept_check_and_reject_usage_errors`（修正前） | 想定した拒否の差で失敗（0 passed、1 failed、終了状態101）。上記の退行の再現 |
| `cargo test -p benitoite --lib --test test_command --test cli_process --test fmt_command` | 1259 passed、0 failed、既存の21 ignored（4 suites、88.39秒）。公開入口の拒否の対照例も成功 |
| `cargo clippy --workspace --all-targets` | 終了状態0、診断なし |
| `cargo fmt --all --check` | 終了状態0 |
| `target/debug/benitoite test --bogus --wasm-fuel=0 a.bnt` | 終了状態2。標準エラー出力で先頭の `--bogus` を未知のオプションとして報告。R18 の記録と一致 |
| `git diff --check` | 終了状態0 |

本番の Rust は123行追加・116行削除（差し引き7行増）、テストは57行追加・51行削除（差し引き6行増）である。`src/cli/mod.rs` の変更はテストのモジュールだけなので、テストに数えた。

最初の本実装の検査は、`parse_test_args` の本番の呼び出し元がなくなったため未使用コードの診断でビルドが止まった。同じ診断で clippy も止まった。不要になった内部ラッパーを除き、既存の wasm のテストを CLI の解析入口へ接続してから、検査をやり直した。

## 計画との差と申し送り

- R21: `--allow-effects` の分離値の消費と test --check での拒否は、A1 までの暫定の扱いとして保つ。A1 で上限の解析・受理条件と06-01のオプションの表を同時に正式に導入すること。
- R22: 指摘3で許された二案から、公開シグネチャを保って Test で wasm を拒否する案を選んだ。本番から呼ばれなくなった内部ラッパーも除いた。作業範囲を超える変更はない。
- 指摘5は R18 の記録の補足だけであり、誤りの選択順の実装は変えていない。
- 段末の scripts/check.sh と gc-stress、最終レビュー・取り込み・コミットはオーケストレータへ渡す。Z2 の標準ソース内の誤りの専用テストは、G3 の判断どおり追加していない。

docs/todo/ は変更せず、コミットは作成していない。
