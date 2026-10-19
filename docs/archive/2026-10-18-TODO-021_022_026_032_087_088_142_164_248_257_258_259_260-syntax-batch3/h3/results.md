# H3の実装結果

基準のコミット: `e08c10fcc8dba4d5dc515eac727dd019fa5c5dfb`。2026-10-18、Codex。HEADは開始版のままであり、コミットとdocs/todoの変更は行っていない。

## 変更

- 標準ソースのList・Option・Result・String・Failure・Property・Scope・Range・IOへ代表例を追加した。新規のstdlib_doc_examplesはSTDLIBの元ソースの全docを共通の抽出部へ渡し、9モジュール、test 9件・run 1件・check 1件・error 4件の計15例を固定して検査する。
- 統合テストの入力アダプタは元コメントのバイト位置・行・列を保ち、同じtest --docの準備・許可照合・実行部へ渡す。Scope/Rangeの公開API・opaque構築拒否、Scopeの定数拒否、Rangeの定数Errorの受理、IOの明示handleと許可付き出力を含む。本番のテスト専用APIや元のimport・私有宣言を補っていない。
- E0506は標準Failの解決済みIDに一致するときだけ、既存のhandleのhelpへFailure.toResultのhelpを追加する。実CLIでmain/@test、import別名、利用者の同名Fail・Logを確認した。test_commandには版1の非実行報告のhelp、捕捉後の実行成功、標準docを利用者のtestへ再帰収集しないことの確認を加えた。
- 英日リファレンス11節を導入→Logとoutput→制約付き操作→組み込み操作の順に移した。開始版との段落・コード・出力の照合で内容を保ったことを確認した。両言語の18節へFailの拒否と捕捉後の成功を追加し、import・入口usesから受け止めたFailを除くこと・ほかの効果を残すことを示した。
- 02-10・06-04・06-06と手書きSkillの案内を更新し、gen_skillでdiagnosticsと標準docの生成物を更新した。Listのdoc追加で移動した非公開関数へのゴールデンの補助位置だけを更新した。

## テストの作成時の関門

標準docのテストは、例の実行結果・拒否・公開境界と元位置を契約とする。抽出漏れの0件、モードの誤分類、暗黙のimport、出力や期待診断の不一致で失敗する。既存の生成物照合だけでは例を実行しないため、この境界へ新しい主テストを置いた。内部の差し込み口は足していない。

実CLIの表は、標準Failだけへ変換を案内する契約を守る。綴りによる判定、別名の見落とし、mainと@testの配線の差で失敗する。既存の拒否テストはhelpを確認していなかった。実装前に追加helpの欠落で失敗し、実装後に成功することを確認した。test_commandの拡張は非実行の単一報告と通常testの収集範囲という別の接続を確認する。

既存のassertの削除・緩和とignoreの追加はない。本番Rustは追加14行・削除10行、テストRustは追加329行・削除0行である。標準.bntの変更はdocだけであり、9ソースの宣言・シグネチャ・本体が開始版と一致することを照合した。

## 検査

`B_WORK=e08c10fcc8dba4d5dc515eac727dd019fa5c5dfb`。各workは同じ基準・指定のdry-runで選択を確認した。初回workはfmt・lint_default・lib_default・tests_related（全40統合ターゲット）・source_rules・skill_generated・spec_tallyを選んだ。reference_examples等はtests_relatedに含むため別に重ねていない。

| コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base "$B_WORK" --test '*' --dry-run` | 0 | 未計測 |
| `scripts/check.sh --level work --base "$B_WORK" --test '*'` | 1 | 98.630秒 |
| `cargo test -p benitoite --test call_allocations -- --nocapture` | 0 | 8.348秒 |
| 下記の38対象を指定した補完workのdry-run | 0 | 0.014秒 |
| `scripts/check.sh --level work --base "$B_WORK" --only tests_related,source_rules,skill_generated,spec_tally "${H3_ARGS_38[@]}"` | 1 | 86.298秒 |
| `cargo test -p benitoite --test golden golden_suite` | 0 | 52.850秒 |
| 下記の30対象を指定した補完workのdry-run | 0 | 0.014秒 |
| `scripts/check.sh --level work --base "$B_WORK" --only tests_related,source_rules,skill_generated,spec_tally "${H3_ARGS_30[@]}"` | 0 | 217.137秒 |
| `cargo clippy --all-targets` | 0 | 5.377秒 |

補完の対象は次のとおりである。実行時はPythonで同じ引数列を組み立てた。表は対応するシェルの配列による表記である。dry-runは各補完workへ `--dry-run` を足した同一の指定である。

```bash
H3_PENDING_38=(
  checked_args cli_process coverage_export declarations desugar_export external_signals fmt_command
  golden http_descriptor_exhaustion http_exchange_release interrupt_process io_modes
  l10_console_clock_process l13_external_commands l21_json l23_csv l24_time l30_http_server
  l31_http_serve_and_helpers l32_http_client named_arguments network_faults open_062 open_062_http
  package_command property_library random_programs reference_examples runtime_builtins skill_docs
  skill_examples spec_examples stdlib_doc_examples test_command verify vm_handlers vm_lazy
  vm_reference_cells
)
H3_PENDING_30=(
  http_descriptor_exhaustion http_exchange_release interrupt_process io_modes
  l10_console_clock_process l13_external_commands l21_json l23_csv l24_time l30_http_server
  l31_http_serve_and_helpers l32_http_client named_arguments network_faults open_062 open_062_http
  package_command property_library random_programs reference_examples runtime_builtins skill_docs
  skill_examples spec_examples stdlib_doc_examples test_command verify vm_handlers vm_lazy
  vm_reference_cells
)
H3_ARGS_38=()
for h3_target in "${H3_PENDING_38[@]}"; do H3_ARGS_38+=(--test "$h3_target"); done
H3_ARGS_30=()
for h3_target in "${H3_PENDING_30[@]}"; do H3_ARGS_30+=(--test "$h3_target"); done
```

初回workは、既存のcall_allocationsの定数連鎖の時間が11.144秒となり、既存の上限10秒を超えて停止した。確保量は333,709,803バイトで512 MiBの上限内だった。同じターゲットのもう1件は共有ロックのpoisonによる失敗だった。コード・assert・上限を変えずにターゲットを再実行すると2件とも成功し、定数連鎖は7.833秒・333,709,731バイトとなった。時間差の原因は確定していない。

38対象の補完は7ターゲットの成功後、goldenのList.mapFromへの補助位置だけで停止した。モジュールdocの追加で宣言が64行・2336〜2343バイトから71行・2558〜2565バイトへ移ったためである。診断の意味は変わっていない。列10〜17、E0330・文言・主位置・非公開の拒否を保ち、補助位置の行とバイト位置だけを更新した（R179）。修正後に失敗したgolden_suiteだけを実行し、残る30対象と未実施の検査単位を補完した。成功済みのlib全件・fmt/lint・統合7対象・call_allocationsを繰り返していない。

最終的にlibは1217件成功・既存のignore 21件、全40統合ターゲットは308件成功・既存のignore 8件である。goldenの部品検査は最初の実行で成功、suiteは位置修正後の実行で成功している。stdlib_doc_examplesの内訳はtest 9・run 1・check 1・error 4であり、全例の元コメントのバイト位置・行・列も一致した。clippy・fmt・source_rules・生成物照合・仕様集計は成功した。spec_tallyは既存の未参照節の一覧を示し、完了条件の未記入はなかった。

途中は `cargo test -p benitoite --test cli_process failure_entry_help_uses_resolved_standard_effect`、`cargo test -p benitoite --test stdlib_doc_examples`、`cargo test -p benitoite --test test_command failure_entry_contracts_are_checked_before_test_execution` だけを対象に実行した。実CLIのhelp欠落による失敗を確認した後、実装して成功した。新規テストの初期の入力とアダプタには、writeの引数型・非公開のスタック補助の利用・CLIの相対パス・IOErrorを含むResultの等値・末尾改行の位置の誤りがあり、対象の境界を保って修正した。IOの例はResultを分岐し、成功時のOptionを厳密に比較し、ErrorならAssert.failとした。これらの局所検査の外側の時間は未計測である。

`cargo run -p benitoite --example gen_skill`、編集時の `cargo fmt`、`git diff --check` も成功した。通常のworkを一度実行し、停止後は失敗した対象と未実施の検査だけを補完した。

## 計画からの具体化と申し送り

R178へ開始版とdoc用入力アダプタ、追加clippyを記録した。R179へゴールデンの補助位置の更新を記録した。停止後の補完指定はplanのH3の検査表へ追記した。公開シグネチャ、受理・拒否の規則、評価順、形式化の言明・仮定、GCは変えていない。

R130の交換件数について、H3は標準ソースへdocだけを足し、交換対象の構成子・関数・実装や既存の交換入力を増減していない。定義と照合入力の増減は0であり、新しいdoc用の15例はstdlib_doc_examplesが検査する。二つの交換manifestの最終再集計は予定どおりV1後の取りまとめへ渡す。

版・残る英日訳・移行案内・同梱物の最終照合はV1、改造全体のchange・全形式化比較・本測定・releaseは取りまとめへ渡す。formal/と安全点を越える値を変えていないため、この作業ではlake build・heap/stressや段6末のstageを追加していない。
