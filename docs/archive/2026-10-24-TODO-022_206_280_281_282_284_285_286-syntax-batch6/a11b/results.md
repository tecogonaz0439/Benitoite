# A11b の結果

2026-10-25。基準 B_WORK と HEAD は `2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283`、作業ブランチは取りまとめが用意した `mod012/A11b` である。対象は plan.md「計画の変更（2026-10-25、A11 の停止を受けて）」の A11b だけである。private/ とそれを指すスキルを読まず、git の変更操作、docs/todo の更新、コミット・取り込み・公開は行っていない。

## 修正と Lean 先行の区切り

`BudgetWhole.modules` の分類が成功した状態を `finishBody` で閉じてから `definitions` へ渡す。操作数・全体の保存数・最大同時保持は引き継ぎ、先頭の元定義の本体消費へモジュールの分類を持ち込まない。分類中の停止と、全体の事前停止の分岐は変えない。本体上限0でモジュールの分類自体を拒否する既存の扱いも保つ。

本体操作上限10・11・12の独立例を `BudgetWholeExamples` の既定 import に追加し、上限11で先頭だけ候補が消える退行を確認した。既存の本体上限7の例は、先頭の元定義も二つ目以降と同じ番号未取得になるため、件数の期待値を `(3,0,2,0,1)` から `(3,0,0,0,3)` へ更新した。上限・入力・ignore は変更していない。

01-12「区間解析の検査全体の駆動」と07-04「区間解析の別本体の発見の対応」に写しと独立例の範囲を反映した。この状態で既定の `lake build`（`-M 12288`）・仕様例7件・仕様集計を通し、[既定上限の境界例](unrelated-boundary.lean)も単体検査した後に Rust へ進んだ。Lean はすべて直列で実行した。

Lean 全差分は [lean-diff.patch](lean-diff.patch) に保存した。差分の対象は `BudgetWhole.lean` と `BudgetWholeExamples.lean` の2ファイルだけである。`NormalSoundness`・`WarningSoundness`（`Interval/Eval.lean`）の本文、公理（`Builtins.Assumptions` を含む）、既存の主定理の言明は **変更していない**。`finish_operations`・`finish_saved`・`finish_peak` などの既存の予算補題もそのまま適用でき、証明の修正を要しなかった。新しい公理・sorry は追加していない。既定ビルドと check.sh の sorry の検査が成功している。

Rust の `AnalysisState::analyze` でも、モジュールの分類が成功した後に `finish_body` を呼ぶ。同じ変更を02-05「区間解析の駆動と予算」へ反映した。式の解析・番号・発見・待ち行列・由来・言語の規則・実行時の検査は変更していない。

## 既定上限の境界とテストの関門

A11 と同じ、Integer 引数、0 の束縛、引数の別名440個、Unit の破棄102個、括弧付き Unit の破棄2個、末尾の `return 1 div z` を使った。D16 の上限を変えず、公開の型検査を通して診断と本体の報告を比較した。

| 定義の並び | 親の解析 | W0401 | 本体 operations / saved / peak | 全体 operations / saved / peak（Lean） |
|---|---|---:|---|---|
| 対象関数だけ | 完走 | 1 | 100,000 / 555 / 1,988 | 100,001 / 555 / 1,988 |
| 空の unrelated、対象関数 | 完走 | 1 | 100,000 / 555 / 1,988 | 100,010 / 557 / 1,990 |

両方とも全体上限未満である。Lean の [実行記録](lean-boundary.log) と、公開の型検査の既存テストに加えた行で、同じ本体消費と候補を確認した。診断は先頭へ足した文字数だけ一次・補助位置を元へ戻し、診断全体（ラベル・注記を含む）を照合した。元からあった通常入力と末尾への関数追加の例は、同じ入力を保った。

テストの作成時の関門は次のとおりである。

- 守る契約は、全体上限未満では先頭への無関係な関数の追加が元本体の診断・本体消費を変えないことである。
- 想定する退行は、モジュールの分類一操作を最初の元定義へ残し、ちょうどの本体上限で最後の候補を失うことである。Lean の独立例は修正前の定義で失敗し、Rust の既存テストに追加した境界行も本番修正前に警告0件で失敗した。修正後は成功した。
- 既存の末尾追加の通常例は先頭の本体の残量を動かさず、この退行を検出できなかった。同じテストへ境界行を足し、別の Rust テスト関数は作っていない。Lean の例は実行定義そのもの、Rust はその実装への写しと公開の型検査からの診断を守る。
- 本番の公開範囲・フラグ・テスト用の入口は増やしていない。名前解決・型検査・入力収集は本物を使用した。テストの削除はない。

全体操作数を本体操作数の和と等しいとしていた既存の source_order の検査は、2モジュールの分類を全体だけへ数える契約に合わせて `2 + 本体の和` へ直した。入力・順序・保存数の検査は変えていない。

## 固定表の再生成

A11 の `budget-reference.lean` は変更せず、修正後の Lean の全体入口から固定値を生成した。保存済みの [Lean 出力](lean-reference.log) に対して [regenerate-reference.py](regenerate-reference.py) を適用した。

```text
python3 docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11b/regenerate-reference.py docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11b/lean-reference.log
```

27種類×4資源×201上限の21,708行を読み、本体は停止しなくなる最小上限の一つ後まで、全体は上限200の要約（cap を除く全列）と一致する最小上限の一つ後までを残す。A11 と同じ選択規則である。本体表は2,346件で内容も変更なし、全体表は633件（旧636件）、合計2,979件となった。全体表で収録する上限の範囲が変わったのは本体操作上限の3群であり、最大 cap は lazy で41→40、handler で63→62、captured で68→67となる。保持上限と全体上限の範囲は変えていない。Rust の結果で上限・期待値を選んでいない。再生成器の初回実行では列数を12/15と誤記して0グループの検査で停止した。実際の11/14列へ訂正して再生成した。

全体表の末尾タブは14列目の空値を表すため保持する。その他の変更に対する `git diff --check` は成功した（[記録](diff-check.log)）。

## 検査

Rust 1.98.1、Cargo 1.98.1、Lean v4.34.1、rtk 0.49.0を使用した。固定版の情報は [toolchains.log](toolchains.log) に置く。すべての検査は `/usr/bin/time -l` で包み、検査本体の終了状態を別に保存した。サンドボックスが `sysctl kern.clockrate` を拒否するため、**Lean のプロセスの最大常駐量は取得できなかった**。time 自身の終了1はこの取得不能であり、検査本体の終了0とは区別する。表の時間は Python の外側で測った経過時間である。

| コマンド・範囲 | 終了状態・外側の時間・結果 | 生ログ |
|---|---|---|
| `(cd formal && lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11/unrelated-boundary.lean)` | 検査本体 0、0.839秒。旧定義の既定上限の境界再現。先頭だけ候補0件 | [lean-boundary-before.log](lean-boundary-before.log) |
| `(cd formal && lake env lean -M 12288 Benitoite/Interval/BudgetWholeExamples.lean)` | 検査本体 1、0.426秒。修正前の小予算の独立例が意図した理由で失敗 | [lean-regression-before.log](lean-regression-before.log) |
| `scripts/check.sh --level work --base 2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283 --only formal_build,spec_examples,spec_tally --dry-run` | 検査本体 0、0.029秒。Lean区切りの指定と選択の確認 | [lean-work-dry-run.log](lean-work-dry-run.log) |
| `scripts/check.sh --level work --base 2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283 --only formal_build,spec_examples,spec_tally` | 検査本体 1、8.055秒。仕様例・仕様集計は成功。既存の本体上限7の期待値で失敗 | [lean-work-initial.log](lean-work-initial.log) |
| `scripts/check.sh --level work --base 2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283 --only formal_build,spec_examples,spec_tally` | 検査本体 0、7.800秒。期待値修正後の仕様集計・仕様例7件・既定ビルド・sorry検査が成功 | [lean-work.log](lean-work.log) |
| `(cd formal && lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11b/unrelated-boundary.lean)` | 検査本体 0、2.328秒。既定上限で先頭への追加の前後が一致 | [lean-boundary.log](lean-boundary.log) |
| `(cd formal && lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11/budget-reference.lean)` | 検査本体 0、4.198秒。独立期待値21,708行を生成 | [lean-reference.log](lean-reference.log) |
| `cargo test -p benitoite --lib unrelated_function_preserves_diagnostics_below_whole_limits -- --nocapture` | 検査本体 101、12.288秒。Rust修正前に既定上限の境界行が警告0件で失敗 | [rust-regression-before.log](rust-regression-before.log) |
| `cargo test -p benitoite --lib budget_reference -- --nocapture` | 検査本体 0、9.817秒。修正後3テスト成功、2,979ケースと診断・本体消費の不変 | [rust-local-reference.log](rust-local-reference.log) |
| `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --exact --nocapture` | 検査本体 0、13.837秒。20,000定数、442,591,133バイト、上限536,870,912バイト | [allocations-chain.log](allocations-chain.log) |
| `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --exact --nocapture` | 検査本体 0、1.372秒。5,000定数・1,000診断、254,825,388バイト、上限268,435,456バイト | [allocations-origins.log](allocations-origins.log) |
| `cargo test -p benitoite --lib typeck::interval::tests -- --nocapture` | 検査本体 101、1.704秒。17成功・1失敗。モジュール分類2操作を本体和に含める旧期待値を修正 | [interval-initial.log](interval-initial.log) |
| `scripts/check.sh --level work --base 2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283 --dry-run` | 検査本体 0、0.098秒。B_WORKの全差分から自動選択を確認 | [work-dry-run.log](work-dry-run.log) |
| `scripts/check.sh --level work --base 2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated --test '*' --dry-run` | 検査本体 0、0.032秒。引用分を除くworkと全統合の明示指定の確認 | [rust-work-dry-run.log](rust-work-dry-run.log) |
| `scripts/check.sh --level work --base 2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated --test '*'` | **検査本体0、418.654秒。全選択単位が成功** | [rust-work.log](rust-work.log)・[実行情報](rust-work.json) |

最終 work の lib は1,298件成功・失敗0・ignored 21（69.88秒）、全統合は40ターゲット・382件成功・失敗0・ignored 10である。fmt・examples込み lint（6.74秒）・source_rules・skill_generated も成功した。割り当て量の3件も全統合内で通した。対象別の件数は [work-counts.json](work-counts.json) に置く。最終 work の開始後に Rust・テスト・固定表・Lean・設計書は変更していない。

## 検査結果の引用と状態の照合

自動 work の [dry-run](work-dry-run.log) は、fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally・formal_build を選択し、spec_examples の個別単位は全統合による包含で省いた。ユーザーの「後者が前者の単位を選ぶ場合は重ねない」という指示と07-03「結果の保存と引用」に従い、Lean 区切りで成功済みの **formal_build・spec_tally を引用**した。残りを `--only` で指定し、明示した tests_related が要求する `--test '*'` で同じ全統合を実行した。新しい機能を含む Rust の検査として、spec_examples は全統合の中で通している。独立した追加の spec_examples は実行していない。

引用する状態は基準・HEADともに `2b415cac2ee1ae95fc1a8c5ca44f1d94c9fbb283` で、未コミット差分ありである。Lean 検査の以後に変えた関係ファイルは、Rust のモジュール入口、既存テスト2ファイル、whole.tsv、02-05の説明であり、Lean と01-12・07-04は変えていない。最終 work 後の変更は本結果と検査記録だけである。

| 引用する検査 | 元の記録・構成と件数 | 以後の変更が影響しない根拠 |
|---|---|---|
| formal_build | [lean-work.log](lean-work.log)・[実行情報](lean-work.json)。既定の `lake build` と sorry の拒否、終了0、外側7.800秒（同時に実行した仕様例・仕様集計を含む）。Lean v4.34.1、`-M 12288` | [lean-input-sha256.txt](lean-input-sha256.txt) の全 Lean ソース・設定・01-12・07-04が一致。Lean 差分は [lean-diff.patch](lean-diff.patch) のまま。Rust と02-05は Lean ビルドの入力ではない |
| spec_tally | 同じ [lean-work.log](lean-work.log)。`spec_coverage.py --self-test` と仕様・受け入れ条件の集計が成功、未記入条件 none。正確な共通コマンドと外側時間は上表 | [spec-tally-input-sha256.txt](spec-tally-input-sha256.txt) の道具、01-spec、ロードマップ、受け入れの索引と `.bnt` 入力は同じ。Rust と whole.tsv、02-05をこの集計は読まない。01-12は検査後に変更なし |

入力のハッシュは [input-sha256.txt](input-sha256.txt)、未コミットの実装差分の SHA-256 は [implementation-diff.sha256](implementation-diff.sha256) に保存した。未追跡の境界例と再生成器も入力のハッシュへ含めた。変更入力の一覧は [changed-inputs.txt](changed-inputs.txt) と、この記録が挙げた追加の期待値・仕様例・索引である。対象の版・コマンド・ツールチェーン・件数・時間・環境制限・初回の失敗はこの記録と各生ログ・JSONに残す。引用の判断者は A11b 実装担当、判断日は2026-10-25である。自動キャッシュによる省略ではない。

## 計画からのずれと申し送り

- **A11b の実装と割り当てられた検査は完了した。** A11a から残った、モジュール分類の先頭本体への引き継ぎと既定の本体上限の境界での診断の変化を閉じた。取りまとめによる独立レビューと受け入れは別である。
- 検査の範囲は計画の work と同じである。成功済みの Lean・仕様集計を再実行しないため、最後だけ `--only` と全統合を表す `--test '*'` を使った。言語の規則、中心命題・公理・既存主定理の言明を変える停止事項はなかった。
- A12 は、モジュール分類を本体の消費へ足さず、全体だけへ残す。全体操作数は元定義の本体操作数の和だけとは一致しない。`Report.remaining_modules`・入口未着手・発見・待ち行列・別本体の停止の扱いは A11a のままである。
- X02 は新しい633件の全体表と、変更なしの2,346件の本体表を利用できる。これらの成功を全構文・任意深さ・全関係定義の比較完了と扱わない。Rust/Lean の全比較は X02〜X05・K1、最終の関係状態の `check-formal.sh` は計画の X05a/K1 と Z01b/K2の担当・時期へ残す。stage・change・release・性能測定は本枝で先取りしていない。
- VM値・ヒープの不変条件・安全点を越える保持は変更していない。追加のheap/stressは対象外である。割り当て量の二件は A11a から各16バイト増で、元の上限未満である。上限・入力・期待値・ignoreを緩めていない。
- 本番 Rust は3行追加・削除0（コメントを含む）、テスト Rust は68行追加・27行削除である。テスト関数の削除はなく、既存のテストへ境界行を追加し、合計の期待値を更新した。Lean は駆動が3行追加・2行削除、既定の独立例が17行追加・1行削除である。補助の再生成器と、改造の独立例・生ログ・ハッシュを a11b に保存した。
- 最大常駐量の取得不能を成功した測定とは扱わない。保存した生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。コミット・取り込み・docs/todo の更新・保管・公開と独立レビューは取りまとめへ渡す。

## 取りまとめのレビュー（2026-10-25）

Lean の変更は `BudgetWhole.modules` で分類の後の状態を `finishBody` で閉じる一行と、その独立例・写しの更新だけで、`Eval.lean`（中心二命題の本文）と公理に差分はない。全体の固定例が636件から633件になったのは、本体の消費から分類の一操作が抜け、本体操作の上限の三群で収録する最小の上限が一つ下がったためである。先頭に空の関数を置いても、境界の入力で W0401 の一件と本体の消費（100,000操作・保存555項・最大同時保持1,988項）が一致することを確かめた。受け入れる。
