# H2の実装結果

基準のコミット: `e82ab03ba9af665944f37482378d4847b21cfdb6`。2026-10-18、Codex。コミットとdocs/todoの変更は行っていない。

## 変更

- CLI引数・help・formatsへ--docと版2を追加した。--docなしの検査報告とJSON Linesの版1、既存オプションの拒否は保持した。
- doc_examplesのVirtualInputとSourceMapの補助、test_runner/docsとprepare/executeを追加した。四モードを一度発見し、同じ一覧を検査・効果報告・許可照合・実行へ渡す。全入口・全実行例を準備し、許可上限を最初の実行より前に照合する。通常テストの準備・Assertの実行は共通部を使う。
- 例ごとに独立した仮想モジュールと実行状態を作る。元のlanguage/dependency・根・設定は継承し、import・私有宣言・usesは補わない。公開/opaque境界と実行入口へのimport禁止を通す。仮想ソースの診断・履歴を元コメントへ戻す。
- 期待した拒否をobservedDiagnosticsへ別記し、check/error例を実行権限へ足さない。未確定のnull、成功した空、complete、例単位の結果とmode別件数を区別する。--checkはmainもAssertも実行せず、期待出力を測定しない。
- 06-01・06-04・06-06・07-04、英語リファレンス、手書きSkillの案内を更新した。gen_skillを実行し、生成文書とbundleに追加差分がないことを作業末にも確認した。

test-auditの作成時の関門に従い、test_commandへdoc固有の8件、cli_processへ実CLIの配線を守る1件を加えた。既存のassertの削除・緩和・ignore化はない。cli_processの版問い合わせの厳密な期待値は、R109で決定したtestResults/testCheckReportの[1,2]に更新した。PathArgsの既存テストにはdoc:falseを明記した。

本番Rustの行数は追加1203・削除72、テストRustは追加506・削除1（版問い合わせの期待値の置換を含む）である。

## 検査

各workは同じ基準と指定の--dry-runで選択を確認した（終了0、外側の時間は未計測）。通常のworkはfmt・lint_default・lib_default・tests_related（全39統合ターゲット）・source_rules・skill_generated・spec_tallyを選んだ。停止後の補完は計画の追加行に従い、古くなった検査と未実施の検査だけを実行した。

| コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base e82ab03ba9af665944f37482378d4847b21cfdb6 --test '*'` | 1 | 5.981秒 |
| `scripts/check.sh --level work --base e82ab03ba9af665944f37482378d4847b21cfdb6 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` | 0 | 367.574秒 |
| `cargo test -p benitoite --test test_command doc_text_reports_escape_control_characters` | 101 | 3.422秒 |
| `scripts/check.sh --level work --base e82ab03ba9af665944f37482378d4847b21cfdb6 --only fmt,lint_default,tests_related --test test_command` | 0 | 13.974秒 |
| `cargo clippy --all-targets` | 0 | 4.927秒 |

初回workはfmt成功後、新規の版2報告の入れ子のifをclippyが拒否して停止した。条件を連ねて修正した補完workは成功した。libは1217件成功（既存のignored 21件）、全39統合ターゲットは305件成功（既存のignored 8件）である。reference_examples・skill_docs・skill_examples・spec_examples・cli_processを含む。spec_tallyは成功し、既存の仕様節の参照のない項目の一覧と、完了条件の未記入なしを出した。

全単位の成功後の差分の確認で、docの失敗詳細・非実行の期待不一致の説明のIDだけに端末制御文字が残ることを見つけた。公開CLIで失敗する新規テストを一度確認し、両方のIDを既存のescape_terminal_controlsで表示するよう修正した。古くなるfmt/lintとtest_commandだけを補完し、46件すべて成功した。成功済みのlib全件と他の統合ターゲットは重ねていない。最後のcargo clippy --all-targetsも成功した。

途中はcargo check -p benitoite --lib、cargo test -p benitoite --test test_command doc_、cargo test -p benitoite --test test_command doc_examples_use_public_imports、cargo test -p benitoite --test cli_process test_doc_を対象だけで実行した。新規テストの初期入力にあった非公式IOモジュールのimport名・実際の診断コード・ExecModeの名前などを直し、対象が成功することを確かめた。これらの外側の時間は未計測である。cargo run -p benitoite --example gen_skillは成功した。git diff --checkも成功した。

## 計画からの具体化と申し送り

R177に開始版・元入口のヘッダの継承・仮想パス・元位置の対応・期待不一致の終了状態・版2のnullと件数の意味を記録した。範囲を削っていない。追加clippyと、二つの修正後に失効・未実施の検査だけを補完する指定をplan.mdに追記した。

H3は標準docの代表例とFail案内を担当する。共通部はcli/tools/doc_examplesとtest_runner/docs（prepare.rs・execute.rs）にある。H2では利用者の入口から標準docやimport先のdocを再帰収集しない。標準docの新しい統合ターゲットはまだ追加していない。

訳と公開候補の版・同梱物の最終照合はV1・取りまとめへ渡す。formal/・GC・安全点を越える値の保持を変えていないため、lake build・heap/stress・改造全体の検査はこの作業で先取りしていない。
