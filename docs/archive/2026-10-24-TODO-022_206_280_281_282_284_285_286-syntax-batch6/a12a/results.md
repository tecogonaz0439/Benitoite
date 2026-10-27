# A12a の結果

2026-10-25。基準 B_WORK と作業開始時の HEAD は `38153d1852a9afd09d99c6c1791be03ee0a98905`。取りまとめが用意した `mod012/A12a` で作業した。git の変更操作、private/ とそれを指すスキルの参照は行っていない。

**A12a の実装と割り当てられた検査は完了した。** 独立レビューと受け入れは取りまとめへ引き渡す。

## 変更

`TypeckOutput::interval_analysis` から `CheckResult.interval_analysis` へ集計を渡し、main と test の準備が AST を破棄するときも保持するようにした。型検査前失敗と未着手を none、正常な空の探索を all とし、未対応・本体停止・段停止・発見や待ち行列の未完・残る元入力を some に反映する。型検査で全本体が無効な対象は none とする。`--deny-warnings` で program が None になっても集計を失わない。

報告全体と各 Target へ `intervalAnalysis` を追加した。basis、coverage、型検査成功の元定義数、未対応、本体予算超過、全体予算による未解析、番号未取得を返す。本体停止と別に段停止の資源別内訳を返し、実消費も返す。元定義・別本体・発見済み未解析の数を重ねず、未発見の別本体数は推測しない。test の報告全体は Target の和とし、重複した入口も別検査として数える。doc test は通常の入口と各生成例を同じ Target へ加える。main/通常 test の形式番号1と doc test の2、既存の必須欄・complete・受け入れ規則は変えていない。

`BodyReport.coverage`・usage を本番で読み、Report の停止・残る元入力・実消費を集計へ接続した。重複する unsupported_bodies、導出できる first_incomplete、入口停止だけの重複した件数・最初の位置、利用者向け報告で使わない別本体の種類別件数と BoundaryKind、DefinitionPhases.order は削除した。根の本体出力との対応はインデックスで保持し、定義名の字面から分類しない。allow 属性は追加していない。直接対応する内部設計を 02-05 に反映した。

## 検査

Rust は `rustc 1.98.1 (48a229cea 2026-09-01)`、Cargo は `1.98.1 (797e8a9bc 2026-08-05)`、Lean の参照実行は formal/ の固定版 v4.34.1、rtk は0.49.0である。具体的なコマンド・終了状態・外側の時間は各 JSON と生ログに保存した。

| コマンド・範囲 | 結果・外側の時間 | 記録 |
|---|---|---|
| `cargo test -p benitoite --lib typeck::interval -- --nocapture` | 26件成功、終了0、15.451秒 | [local-interval.log](local-interval.log) |
| formal/ 内で `lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a12a/summary-reference.lean` | 終了0、3.538秒。全2,412行から既存 whole.tsv と同じ633キーを選択 | [summary-reference.lean](summary-reference.lean)、[summary-reference.log](summary-reference.log) |
| `cargo test -p benitoite --lib typeck::interval::tests::budget_reference -- --nocapture` | 3件成功、終了0、17.488秒。既存の本体2,346ケース・全体633ケースに集計の独立期待値を追加 | [local-summary.log](local-summary.log) |
| `cargo test -p benitoite --test cli_process check_report -- --nocapture` | 修正後8件成功、終了0、10.461秒 | [local-cli-fixed.log](local-cli-fixed.log) |
| `cargo test -p benitoite --test test_command check_report -- --nocapture` | 7件成功、終了0、10.361秒 | [local-test-report.log](local-test-report.log) |
| `cargo test -p benitoite --test cli_process interval_reports -- --nocapture` | 最終表1件成功、終了0、8.320秒。六入力×main/test×通常/denyの24報告 | [local-report-final.log](local-report-final.log) |
| `cargo test -p benitoite --test cli_process test_doc_uses_version_two_and_keeps_check_nonexecuting -- --exact --nocapture` | 1件成功、終了0、1.226秒 | [local-doc-report.log](local-doc-report.log) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 2件成功、終了0、11.087秒。下表の元の上限を維持 | [allocations.log](allocations.log) |
| `scripts/check.sh --level work --base 38153d1852a9afd09d99c6c1791be03ee0a98905 --dry-run` | 終了0、0.076秒。fmt・examples込みlint・lib全件・全統合・source_rules・skill_generated・spec_tally | [work-dry-run.log](work-dry-run.log) |
| `/usr/bin/time -l` で包んだ同じ work | **検査本体は終了0**、外側437.168秒。time は437.16 real / 1322.53 user / 54.87 sys、自身は終了1 | [work.log](work.log)、[work.json](work.json) |
| work 内の全 lib | 1,298件成功・失敗0・ignored 21、テスト70.53秒 | 同上 |
| work 内の全統合 | 全40ターゲット、計382件成功・失敗0・ignored 10。割り当て量3件も成功 | 同上 |
| work 内の fmt・examples込みlint・source_rules・skill_generated・spec_tally | 全選択単位が成功。lint は13.33秒。仕様集計の未記入条件 none、生成物に差分なし | 同上 |

| 割り当て量の検査 | バイト数 | 上限 |
|---|---:|---:|
| 20,000定数の連鎖 | 442,640,261 | 536,870,912（512 MiB） |
| 5,000定数・1,000診断 | 254,874,516 | 268,435,456（256 MiB） |

最大常駐量は、サンドボックスが `sysctl kern.clockrate` を `Operation not permitted` とするため取得できなかった。time の終了1と、別に保存した検査本体の終了0を区別した。

割り当て量は本作業の集計を接続した途中の実測であり、上限・入力・期待値・ignore は緩めていない。前作業 A11b の記録からは各49,128バイト増えた。

### 初回の失敗と修正

接続途中の cargo check は、不要になった order/kind の未使用警告と、整理途中での構造体の区切りの誤りで失敗した。不要な欄を削除し、区切りを修復した後、cargo check --tests は成功した。最初の局所26件では、削除した body_entry_stops の期待値を段停止へ置き換える際、モジュール自身の保持上限停止を入口停止と混同した一箇所が失敗した。モジュール段停止一件の期待へ直し、26件すべて成功した。

既存 main 報告の完全一致比較は、intervalAnalysis の追加で初回8件中6件が失敗した（[local-cli.log](local-cli.log)）。既存必須欄の比較を保ったまま、追加欄の存在を確認してその一欄だけ比較対象から取り除く補助を共用した。追加欄の値は別の表で独立に確認する。既存読者の受け入れ規則を変更する修正ではない。

Lean の参照実行は、最初の二回が作業ディレクトリに対する相対パスの誤りで失敗し、次の一回は formal/ 外で選ばれた Lean と既存 olean の版の不一致で失敗した。formal/ を作業ディレクトリとして固定版を使い、`-M 12288` を付けた上表の実行で成功した。Lean のビルドを並行して走らせていない。

## テストの整理と作成時の関門

RV-A07 の軽7に対応し、CLI の局所警告テストを、集計の保存と通常/denyの受け入れの独立性を守る表へ置き換えた。診断の一次・補助位置・注記の同じ確認を重ねる部分は削除し、declarations と golden の担当に保った。新しい表は all/some/none、四種類の件数、programを捨てるmain/testの両経路を実際の入力から守る。既存の診断テストだけでは報告欄の欠落・取り違えを検出できない。専用の差し込み口・本番フラグを追加していない。

既存の全体小予算表に、BudgetWhole の五射影と段停止の内訳の独立期待値を加えた。公開の型検査の準備と既存の任意予算入口を使い、件数をRustの結果から作っていない。超過・番号未取得を重ねる退行と、入口・発見・待ち行列・未解析参照の取りこぼしを守る。633ケースでは coverage が some であることも確認する。型検査・CLIの同じ条件を層ごとに繰り返すテストは加えていない。

別本体の kind の字面だけを読む比較は、本番の未使用欄とともに削除した。別本体の開始・終端、所有する元番号、節順、診断・忘却の境界は既存テストに残した。テスト関数の総数は増やしていない。

## 計画からのずれと申し送り

- A12a の接続に必要なため、指定のファイルに加え、ASTを破棄する cli/mod.rs と test_runner/mod.rs、CheckResult を作る宣言収集、集計の子モジュール、不要欄の提供側とその既存テストを変更した。言語の規則、Lean の実行定義・中心定理・主定理・前提・結論・公理、VM値とヒープの不変条件は変更していない。
- A12b は 06-01・06-04・02-10・06-06・手書き inspection.md・SKILL.md を担当する。本枝はこれらを編集していない。追加欄の正確な形は cli/check_report.rs の interval_value と 02-05「区間解析の報告の集計」を参照する。四件数と coverage に加え、inputDefinitions、phaseStops（exceeded/unidentified の各資源別内訳、depth/other）、usage（operations/savedItems/peakItems/maxBodyOperations/maxBodyItems）を返す。coverage を受け入れ規則や安全性の判定に使わないこと、全体の件数はTargetの和であることを文書へそろえる。
- X02/U01 は本体停止と段停止の内訳、残る有効な元定義の件数、集計を利用できる。BudgetWhole の全構文・任意深さとの全比較を本枝の633ケースの成功で完了と扱わない。maxBody の値は本体出力の保存できた本体だけの最大値であり、出力のない段停止の消費は検査全体の usage に残る。
- 独立レビュー・受け入れ・A12後のstageは取りまとめが担当する。change/release、Rust/Leanの全比較、heap/stress、性能の比較測定は先取りしていない。判定が要る言語規則や主要定理の変更は発生していない。

本番 Rust は追加414行・削除76行、テスト Rust は追加228行・削除56行である（新しい summary.rs を含む）。作業末の work は一度で全選択単位を通り、その開始後に Rust・テスト・固定表・02-05 を変更していない。検査後の変更はこの結果の確定とログの保存だけである。`git diff --check` と結果記録の相対リンクの確認も成功した。保存した生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。

A12a が受け持つ未実施・不合格の検査と、判断待ちは残っていない。最大常駐量の取得不能を成功した測定として扱わず、独立レビュー・受け入れと後続の検査は上記の担当へ引き渡す。

## 取りまとめのレビュー（2026-10-25）

実 CLI の `check --report=json` で、報告全体に `intervalAnalysis`（`basis: localIntervals`、`coverage`、`inputDefinitions`、各停止の件数、段停止の内訳、`usage`）が加わり、`schemaVersion` 1・`complete`・既存の欄が変わらないこと、テキストの報告が変わらないことを確かめた。受け入れる。
