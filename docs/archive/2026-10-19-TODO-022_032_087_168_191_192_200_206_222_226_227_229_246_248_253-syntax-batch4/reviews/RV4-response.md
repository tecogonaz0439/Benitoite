# RV4の指摘への対応（Z3）

対象は[RV4.md](RV4.md)の中1件・軽5件である。判断は[decisions.md](../decisions.md)のR198〜R201、検査と時間は[z3/results.md](../z3/results.md)に記す。RV4.mdはオーケストレータが置いた本文を変更せず、この作業の取り込み対象に含める。

| 指摘 | 対応 | 変更と確認 |
|---|---|---|
| 中1 | recordの後の改行を値の文区切りとして残す | newlineの継続字句からrecordを外し、宣言のparserでだけ直後のNEWLINEを読み飛ばす。bindとreturnの次行がConsoleで始まる入力を、二つの文と値のASTまで固定した。public・注釈・publicの後の改行を含む宣言も検査する。01-01の規則2を更新した（R198）。 |
| 軽1 | W0501の正規名をLogに揃える | 組み込みエフェクトの名前がモジュールの末尾と同じなら名前だけを返す。W0501のhelpをwrite `uses Log`、編集範囲をIO.All、置換をLogへ固定した。 |
| 軽2 | recordを欄名として拒否する | 01-01に宣言・構築・更新・パターンの欄名では使えないことを追記した。構築の先読みでは欄の並びに分類し、共通の欄名の検査でE0201を出す。構築・更新・後続の欄・パターンの診断を固定した（R198）。 |
| 軽3 | E0467を誤りの式へ置換して型検査を続ける | pipelineの事前展開から型検査への早期終了を除き、外部の照合・実行への誤りの検査は保つ。RV4のhere5とhere3を公開checkの診断テストへ追加し、E0467とE0401・E0402・E0451の全件を固定した。02-04に回復の規則、02-01に一般の停止規則の例外を追記した（R199）。 |
| 軽4 | 構造の等値と内部の欄の表示を明記する | 03-06とRange/NonEmptyListの標準ソースの説明を更新し、gen_skillで二つの参照を再生成した。opaque-wrapper-equalityのgoldenで、三種類の等値と保存した欄の違い、Assert失敗の内部表示、成功1件・失敗3件・終了1を固定した（R200）。 |
| 軽5 | 現役READMEから改造のディレクトリへのリンクを除く | tools/source-migrate/README.mdを、0.0.10の改造のディレクトリ（終了後はdocs/archive/の下）のhistorical-tools/named-arguments-migrateという文字の参照にした。docs/design・docs/reference・tools・scripts・crates・AGENTS.mdの検索で、ほかの同ディレクトリへのリンクはなかった。 |

既存assertの削除、期待値の緩和、ignoreの追加はない。コミットとdocs/todoの変更、formalの変更は行わない。版全体のchange/releaseの検査は取りまとめの割り当てに残す。
