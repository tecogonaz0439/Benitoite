# RV3の指摘への対応（Z2）

対象は[RV3](RV3.md)の中2件・軽10件である。判断は[decisions.md](../decisions.md)のR180〜R184、検査と時間の記録は[z2/results.md](../z2/results.md)に集める。RV3.mdはオーケストレータが置いた本文をそのまま残す。

| 指摘 | 対応 | 主な変更・確認 |
|---|---|---|
| 中1 | 宣言からの回復後も矛盾する使用の診断を残す | solve/provenanceとsolve_pairで、成功した使用も元の制約を保持し、回復した本体の、元の型でも失敗した使用の内側だけを再確認する。`gl([s, "x"])`はreturnの不一致と文字列要素の不一致の2件、`gl(["y"])`の対照も2件を、位置と文面まで固定した。宣言の型で成功する使用の対照を追加し、既存の宣言由来だけの使用も1件のままである（R180）。 |
| 中2 | 成功する制約で全域の探索をしない | 依存の連結成分の根へ宣言の理由と確定の有無を要約し、空の回復情報は探索しない。release CLIの比較と全標本をz2へ保存し、M1へ同じ入力のcompare追加を割り当てた（R181）。 |
| 軽1 | L0112の見出しを定義全般に一般化 | diag/codesと生成Skillを更新し、命令上限の位置を02-10に追記した。 |
| 軽2 | 最終的に出ない注記を削除 | limit/definitionとcopies of guardsを診断表・生成Skillから除いた。試行の仕事量超過は内部で捕捉するnodesのLimitとして行照合へ切り替える（R182）。 |
| 軽3 | 最終出力の予約も試行に含める | 作業表とreserve_outputのLimitでも状態を戻して行照合へ切り替える。共有判定は作れるが最終出力の予約で失敗する局所テストを追加し、予算・実際の照合結果を確認する。02-06も更新した（R182）。 |
| 軽4 | 行照合を通ったことを確認する版を追加 | decision/block_testsで同じ小さい実ソースを通常予算と消費済み予算へ渡し、共有経路・巻き戻し後の予算をassertする。ガードの選択肢とtailの束縛を、実codegen・verify・Direct/Request VMと独立参照評価で比較する。元のrandom_programsのassertと入力は保ち、stressの小さい入力は共有経路になる旨を記した。 |
| 軽5 | 深さの入力を元の大きさへ戻す | pattern_extの450/900等、decisionの64/4096、IR検査の1000を構成によらず保つ。planのKもGCを伴う実行と型検査等を区別した。heap-verifyとheap-verify+gc-stressで各件を個別実行し、テスト本体の時間を記録する。 |
| 軽6 | 注記一つを厳密にassertする | final_decision_budgetのnotes全体を、64 MiBの作業表超過の注記一つへ固定した。 |
| 軽7 | 補正を明示した末尾returnだけに限定 | b3の独立表層の4箇所を位置の並びで指定した。returnの頭の型・返す値・コア全体と、それ以外のreturnEは書き換えず比較する。六入口の局所交換を再実行する。Leanは変更しない。 |
| 軽8 | 文言の定数をtextへ移す | contextのmain/Benitoiteをtypeck::textのMAIN_MODULE/STANDARD_PACKAGEへ移した。 |
| 軽9 | 作業IDを除く | builder_testsのB1を設計02-07の節に替え、patternsの失敗文のT1をcoverageへ替えた。src/testsを検索し、ほかに0.0.10の作業名の引用はなかった。既存のtraitsのフック名、ヒープの不変条件名、入力の構成子名は作業IDではないため保った。 |
| 軽10 | 不要欄を削除し、親の対応と種類を検証 | verifyのannotation欄ごと除いた。Protoにbuilder_parentを記録し、Closureの生成元と照合する。親の種類の不一致・親メタデータの不一致・同じ局所欄を持つ別の親でのClosure生成を変異へ追加した。親の照合を外すと変異テストが失敗することも確認した（R183）。 |

既存assertの削除、期待値の緩和、ignoreの追加はない。コミットとdocs/todoの変更は行わない。版全体のchange/release・形式化全体の比較とM1の共通compareへの入力追加は後続の割り当てに残す。
