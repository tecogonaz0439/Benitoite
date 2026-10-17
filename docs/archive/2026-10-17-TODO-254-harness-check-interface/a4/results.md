# A4 検査後の変更と同じ成果物の最終照合

## 目的と変更

報告の expanded を実行時の許す集合に戻し、報告後の main・import 先・テストの変更を実行前に拒否することを確認した。同じエフェクト集合では操作内容を固定できない限界も比較し、`--version=json` の `formats.effectLimit=[1]` を宣言した。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/mod.rs` | 提供済みの形式に effectLimit の1を追加 |
| `crates/benitoite/tests/cli_process.rs` | 報告後の入口・依存の変更、同じ集合での書き込み先の変更を実ファイルで比較。既存の制御フローの表を使い、die・Exit・完全なハンドラ・宣言に残した Exit・裸の try・or return の報告から上限付き run へ接続。version JSON の全体の厳密な期待値に一キーだけ追加 |
| `crates/benitoite/tests/test_command.rs` | 古い報告の集合による全体拒否、Assert.Check の不足、余分な許可、die と Exit の報告・包含・実行結果の対照を追加 |
| `docs/design/06-tooling/06-01-cli.md`・`07-quality/07-01-security-model.md` | 形式の宣言、同じ成果物の保持、報告と実行の間の変更、同じ集合内での内容の変更とスナップショットの限界を明記 |
| `decisions.md`・`harness-response.md` | import 先だけの変更を E0501 で拒否する R25 と、effectLimit の提供状態を反映 |
| 本書 | 共通の関門 K、所有のレビュー、検査と申し送り |

公開の型・シグネチャ、E0512 と既存の診断、test/testSummary の欄・型、形式1の契約は変更していない。実行時の照合と所有は A1〜A3 の本番の経路をそのまま使う。新しい本番の処理は、接続済みの能力の宣言だけである。

## テストの作成時の関門

守る観測可能な契約は、報告後に許す集合の外へ契約を広げれば実行前に拒否すること、Assert.Check も比較から外さないこと、余分な許可は受理すること、許可後も die の終了状態1・code:null・test.failure.die と Process.exit の指定値を維持することである。現実的な退行は、古い検査結果の流用、検査失敗を E0512 に置き換えること、テストの集合から Assert.Check を落とすこと、ハンドラで消した Exit を AST から付け直すこと、uses に残した Exit を無視することである。

主となる境界は CLI の報告・診断・結果行・終了状態と実ファイルである。既存の固定した許可の表と非実行の報告の表だけでは、報告から許す集合を組み立て、ソース変更後の実行へ渡す接続を確認できない。main の制御フローは既存の表と全体の報告の比較を残して拡張し、別の層へ同じ試験を加えていない。import 先だけの変更は既存の規則で E0501 を生じるため、R25 に従ってその診断と非実行を確認する。

拒否した run は出力なし・目印の内容に変更なし、拒否した test は testSummary 一行だけ・成功数と失敗数0・filesNotRun が全入口数・目印なしを確認する。成功した同じ集合での依存の書き込み先の変更は、元の目印を保ち、別のファイルに実際に書き込む。die の code はキーの存在も確かめ、欠落を null と取り違えない。

既存の assert・負の入力は維持し、テストの削除・期待値の緩和・ignore の追加はない。新しい本番 API・テストフック・大域の可変状態・時間待ちによる競合試験は加えていない。Rust の本番コードは2行追加・1行削除（差し引き1行増）、テストは427行追加・4行削除（差し引き423行増）である。

## 所有と呼び出し元のレビュー

| 経路 | 確認した所有と開始条件 |
|---|---|
| run: `prepare_script` → `execute_script` | 段の中の一回の pipeline::check が持つ同じ CheckedProgram を inspect_main・effect_limit::check・desugar_checked・compile へ渡す。拒否時は compilation を作らず、AST とコア IR は段のスタックで破棄する。呼び出し元は返された CompiledProgram を run_program_with_externals に渡し、ソースの再読や再検査を挟まない |
| test: `run_test_with_externals` → `Runner::run_limited` | select_test_entries は最初に一度だけ呼び、選択した全入口を prepare・validate_prepared する。成功した EntrySpec と Prepared の組だけを ready が所有し、通常の拒否が一件でもあれば全体を開始しない |
| test: `prepare` → `compile_tests` | 同じ CheckedProgram から collect_tests・function_contract・effect_limit::check・AssertTable・脱糖・コンパイルを行う。RunInput と各テストの原型も全入口の開始前に確認する。Prepared.result.program は None であり、AST を段の外へ持ち出さない |
| test: `execute_prepared` | ready を順に消費し、保持した CompiledProgram・テストと原型の組・AssertTable・RunInput を使う。テストごとの新しい RunEnv だけを作り、探索・検査・コンパイルを繰り返さない |

既存の `limited_tests_consume_the_prepared_artifacts_in_order` は、先頭のテストが後の入口を不正な内容に変えても、保持した元の成果物を実行することを待ちなしで確認している。この契約の試験は重ねず、上の所有と呼び出し元を確認した。複数入口の準備の間に依存が変われば異なる内容を保持しうるため、全対象の一時点のスナップショットとは扱わない。

## 検査

出力の整理に rtk を使った。依頼に従い scripts/check.sh は dry-run も含め実行せず、gc-stress も実行していない。計画のもう一方の all-targets は gc-stress ではなく gc-mark-sweep,heap-verify であり、別に確認した。

| コマンド | 構成と結果 |
|---|---|
| `cargo test -p benitoite --lib` | 既定の gc-mark-sweep。1195 passed、0 failed、既存の21 ignored（78.39秒） |
| `cargo test -p benitoite --test cli_process --test test_command --test golden` | 既定の構成。59 passed、0 failed（3 suites、71.20秒）。cli_process 22件、test_command 35件、golden 2件 |
| `cargo test --workspace --all-targets` | 既定の構成。2621 passed、0 failed、既存の49 ignored（48 suites、430.47秒） |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | gc-mark-sweep,heap-verify。2635 passed、0 failed、既存の49 ignored（48 suites、556.28秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した文書の相対リンクの確認 | 5文書の64件で参照先の存在を確認 |
| `git diff --check` | 終了状態0 |

effectLimit の本番の宣言を加える前に、更新した version JSON の厳密な比較がその一キーの不足で失敗することを確認した（cli_process は21 passed・1 failed）。接続後の関連する統合テストは全件成功した。その後、die の code:null は欠落と区別するキーの存在確認も加えた。最終の Rust コードは両構成の all-targets で確認した。表の秒数は rtk が集計したテストの実行時間であり、コンパイルを含む待ち時間とは区別する。

## 計画との差と申し送り

import 先だけに操作と宣言上限を追加した場合は、main の既存の宣言への違反 E0501 が優先される。この対照の扱いを [R25](../decisions.md#r25-import-先だけにエフェクトを加えた場合の拒否をどう確かめるか) に記録した。main とテストの宣言上限を広げた対照では、計画どおり古い expanded を渡して E0512 と非実行を確認する。実行時の照合の規則を変えるずれはない。

scripts/check.sh の段末の `--only rust,default_lib,skill`、gc-stress、G4 のレビューと san_benito への取り込みはオーケストレータへ引き継ぐ。本書は A4 の個別作業の記録であり、段3全体の完了や G4 の実施済みを示さない。

次の実装は E1 の明示したローダ変数の拒否である。今回の formats の追加は effectLimit だけであり、E1 は loaderEnvironment の宣言とポリシーを本番の拒否と同時に接続する。

formal/・構文・型の規則・脱糖の規則は変更していない。R4 に従い 07-04 の対応表と Lean の変更、lake build は不要である。診断表・標準ライブラリのソース・Skill の生成元は変えていないため gen_skill も不要である。docs/todo/ は変更せず、コミットは作成していない。
