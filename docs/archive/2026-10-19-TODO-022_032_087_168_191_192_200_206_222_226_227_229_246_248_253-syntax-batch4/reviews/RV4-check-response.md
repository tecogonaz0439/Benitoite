# RV4の指摘の直し（Z3）の確認への対応

対象は[RV4-check.md](RV4-check.md)の軽5件である。重・中の指摘はない。判断は[decisions.md](../decisions.md)のR202〜R206、検査の結果は[z4/results.md](../z4/results.md)に記す。

| 指摘 | 対応 | 確認するテスト・資料 |
|---|---|---|
| 軽1 RecordDeclの改行 | 01-02の二か所に `[ NL ]` を加え、01-01から宣言の構文解析という処理方式の記述を除いた | spec_examplesと生成grammarの一致 |
| 軽2 E0467の後の診断 | 誤りの式にE0433を重ねず、その式を含む関数のW0501を抑える。別の定数のE0433と別の関数のW0501は残す。束縛後のE0401は既存の回復として02-04を修正した | pipelineの既存の表へhere_const・here_const2・here_effect・here_chain2の入力を追加し、診断の列とCheckedProgramがないことを確認。独立した関数の警告の位置も確認 |
| 軽3 宣言の欄名record | recordの次がコロンなら欄名の誤りとして一件を報告し、行を読み飛ばす | record_is_rejected_as_a_field_nameへ最初・二番目の宣言の欄を追加 |
| 軽4 利用者のLogの取り込み | Logが隠されるとき、W0501の置換とE0501のhelpはBenitoite.Logを使う | log_effect_fixes_resolve_when_a_user_module_shadows_log。通常の取り込みと別名の両方、修正後の再検査を含む |
| 軽5 包みの鍵 | 三つの包みの鍵の可否と欄の比較順を03-06・Range/NonEmptyListの標準ソース・生成Skillへ反映 | opaque-wrapper-keyのgoldenでMap.keys・Set.toListの昇順とMap.getを実行。既存の鍵の実装は変更しない |

新しい機能や形式化の変更はない。M1へ進む際にはこの対応表と結果を引き継ぐ。オーケストレータが置いたRV4-check.mdも取り込み対象に含める。
