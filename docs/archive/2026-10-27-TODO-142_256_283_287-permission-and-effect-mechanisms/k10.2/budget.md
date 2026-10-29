# 番号付け停止・最後の Run・内側の超過からの回復

B_WORK は `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。実ソース2本と3ケースの [独立期待値](independent-budget/expected.json)・[SHA-256の一覧](independent-budget/manifest.json)を、Rust の局所比較の前に固定した。実行後も値は変更していない。実装側の入力は `crates/benitoite/tests/desugar_export/range-budget/` の同名ファイルであり、記録の写しとバイト一致する。

作成時の関門では、独立した契約を「停止の種類を区別し、同じ規則の出現の鍵と Required の添字・理由を保つこと」とした。最後の Run が回復した後の内側 Top を budgetExceeded とする退行と、番号付け停止の後も取得済みの接頭辞の番号を診断へ使う退行を検出する。既存の局所解析の単体検査は交換の同じ出現の鍵まで照合しないため、公開 pipeline と `ScopeBodyInput::analyze`・`required_ranges`・`accept_call` を使って書き出す。差し込み口は追加しない。

`range_budget::export_range_budget_sources` は、通常ソースを既定の型検査で受理した上で、公開の構造入力を小さい明示上限で解析する。局所解析の上限を本番の型検査器へ注入した実行ではない。通常の型検査の成功と、明示上限の公開の受理判定の拒否を区別する。同じソースを通常の named の交換へ書き、`scopeAcceptance.limits` に同じ四つの上限を置いて Lean と比べる。番号付けの上限だけは Lean にないため、この比較へ載せない。

| 入力 | 固定した上限 | Rustの独立期待値と結果 | Leanとの対応 |
|---|---|---|---|
| numbering-stop | 番号付け0、本体/全体は操作100・保持100 | `recovered.bnt` の全raw規則6件が Required=Top、理由budgetExceeded、拒否の先行順番号なし。Topの契約は受理。出現の接頭辞へ対象を狭めない | Rust独自の資源制限として明示し、直接一致の対象にしない |
| last-run-exceeded | 番号付け200000、本体操作4・保持100、全体操作100・保持100 | 検査0のRequiredは `/data/**` のまま。射影6はTopかつbudgetExceeded。最後のRunは本体操作の超過を保持 | 同じ定義 `fn:43`・先行順6・budgetExceededで `surfaceCheck.result.cover` が一致 |
| inner-exceeded-outer-recovered | 番号付け200000、本体操作5・保持100、全体操作100・保持100 | 内側の三つ目の検査13で超過するが、最後のRunに超過はない。内側の射影19はTopかつunknownSource、外側の射影27は `/outer/**` を保つ。検査0/5/9/13のリテラルの範囲も保つ | 同じ定義 `fn:43`・先行順19・unknownSourceで `surfaceCheck.result.cover` が一致 |

## 固定した補助期待の誤り

初回のRust検査は、主契約に加えて期待した補助欄 `firstStopPreorder` の比較で失敗した。last-run-exceeded の手書き値は6であったが、`metrics.stops` は超過を生じたmatch文の記録4を指す。拒否される射影のキー6とは異なる。内側の超過の入力の補助値13は観測とも一致する。

この補助期待の誤りは、初回の期待値を成功へ書き換えず保持する、という親担当の判断で処理した。Rustの書き出しとPythonのsummaryに、補助期待不一致1件（expected6・actual4）を明記した。Requiredの全14規則の添字・理由と、番号付け完了時の全キーは省かず、別に検査した。`summary.success=true` の対象はこれらの主契約であり、補助期待まで全一致したことを表さない。補助欄の誤りをLeanやRustの規則の不具合とは扱わない。

## 局所比較の結果

[Pythonの台本](../../../../formal/tests/test_range_budget_sources.py)は同じ実ソースの書き出しを読み、同じ宣言の交換名へRustの定義名を対応させて先行順番号を直接比較する。`candidates` を除いた corpus を両入口へ渡し、範囲の2群それぞれに `nonTopRanges>0` を要求する。空の表だけの一致、深さなどの対象外、型付けの失敗をRequiredの同じ理由へ読み替える処理、失敗を無視するcatch-allは置かない。

| 入口 | last-run-exceeded | inner-exceeded-outer-recovered |
|---|---|---|
| surfaceCheck | 終了1、cover=`fn:43/6, budgetExceeded` | 終了1、cover=`fn:43/19, unknownSource` |
| surfaceCheckAll | 終了1、1定義の意図した拒否文に `required check is not covered:` とbudgetExceededを含む | 終了1、1定義の意図した拒否文に `required check is not covered:` とunknownSourceを含む |
| desugarDiff | 終了0、1定義一致・不一致/対象外/除外0 | 終了0、1定義一致・不一致/対象外/除外0 |
| builtinCheck | 終了0、1入力・errors空 | 終了0、1入力・errors空 |
| candidatesを除くnonTopRanges | 5（desugarDiffとsurfaceCheckAllの両方） | 16（同左） |

補助不一致の件数を受け入れ条件に固定するassertを除いた台本を、[再確認](budget-compare-confirmed.log)・[計時](budget-compare-confirmed.json)で実行し、終了0（time real0.24秒）を確認した。各補助値を比較して全不一致を残す処理は保つ。台本の最後の変更はsummaryのsuccessScopeの説明を日本語へそろえたものであり、検査条件は変わらない。

正確な入力とRust観測は [budget-output/range-budget](budget-output/range-budget/manifest.json)、各Leanの報告は [budget-compare-final](budget-compare-final/summary.json)にある。summaryはRust独自の1ケースとLean比較の2ケース、理由の直接比較2件、主契約の成功と補助期待の不一致を別々に載せる。

| 実行 | 終了 | 外側秒 | time-p real/user/sys秒 | 補助最大常駐量 |
|---|---:|---:|---|---|
| [初回Rust](budget-export.log)・[計時](budget-export.json) | 101 | 計時JSON参照 | 2.33/1.85/0.63 | 計時JSON参照 |
| [補助期待の観測を分離したRust](budget-export-followup.log)・[計時](budget-export-followup.json) | 0 | 2.901288291 | 2.89/2.75/0.69 | 706,707,456 bytes = 673.96875 MiB |
| [初回Python](budget-compare.log)・[計時](budget-compare.json) | 1 | 計時JSON参照 | 0.15/0.10/0.03 | 計時JSON参照 |
| [引数を修正したPython](budget-compare-final.log)・[計時](budget-compare-final.json) | 0 | 0.250233875 | 0.24/0.18/0.04 | 42,221,568 bytes = 40.265625 MiB |

Rustの初回失敗は前述の補助期待の誤りであり、期待値は変更していない。局所実行の前に一度行った `cargo fmt --check --package benitoite` は、並行して作成中だった別担当の `range_sources.rs` の整形差で終了1となった。本担当は同ファイルを変更せず、追加した `range_budget.rs` だけをrustfmtで整形した。全体のfmtの確認はW-Kへ含める。Pythonの初回失敗は `builtinCheck` にcorpus引数を渡さなかった台本の誤りで、Leanの終了2を無視せず台本全体が失敗した。引数を直して両ケースを再実行し、初回のログと途中の報告も保持した。成功したRustは1試験成功・失敗0・無視0・除外48である。全体のW-Kは親担当が一度実行し、この局所実行を代用としない。

K10.3の全比較は既存のRust全書き出しがこの新しい試験を含み、`formal/tests/test_range_budget_sources.py --rust-dir <output>/range-budget --output-dir <output>/range-budget-comparison` を接続する。manifestへは3ケース・Rust全14規則・Lean2ケースと各群の非Top件数、補助期待の全不一致を観測値として残す。不一致の件数1は今回の記録であり、全比較の受け入れ条件へ固定しない。主契約の両ケースは現存の規則で一致し、LeanやRustの規則の変更を要しない。追加のLeanビルドや全比較はこの担当では実行していない。既存targetを使い、新しいCARGO_TARGET_DIRやtarget外の一時ビルドは作っていない。
