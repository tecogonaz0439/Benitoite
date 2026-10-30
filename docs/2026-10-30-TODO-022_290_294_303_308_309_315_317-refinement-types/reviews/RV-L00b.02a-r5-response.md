# RV-L00b.02a への対応（再開5）

2026-10-31。取りまとめの案(i)と各所見の送り先に従って修正した。詳細は [resultsのレビュー対応](../l00b.02/results.md#レビューの所見の対応rv-l00b02a2026-10-31再開5)、契約は [signatures第2.2節・第19節・第20節](../l00b.02/signatures.md)に置く。本書は担当の応答であり、再レビュー・受け入れ済みの記録ではない。

| 所見 | 対応と確認 |
|---|---|
| 重1 | TParamDecl.kindとClassDecl.argumentKindを追加。Dictの引数をクラスのkindで検査し、Def.kindsを宣言と注釈の照合へ変更。旧の制約の射影を保存。案(ii)は採らない。map[F[_]:Functor,A]とDict[Functor,Option]を受け入れ、Functor[Integer]・arityの不一致を拒否することを境界入力で確認 |
| 中1 | `.02b-values`でV_Lam/V_List等の注釈にDeclaredを追加し、正則性からnarrowingへ供給する義務を、起動表と義務対応表に固定。今回は本番を変えない |
| 中2 | `.11`でdataCore_sourceとDataImages等の依存する判断・補題を、型引数の等号から欄の具体化に必要な関係へ弱める義務を追加 |
| 軽1 | 依頼の新規16ファイルの一覧にValueReferences.leanを含めた |
| 軽2 | `.13`で複数構成子の欄と受け手の構成子の一致、観測がnoneになる場合の意味を照合する義務を追加 |
| 軽3 | resultsの説明を「型変数の像がOrdinary」に修正。本番のtypeImagesは変更なし |

検査は [r5-validation](../l00b.02/02a-r5-validation.json) に保存した。既定ビルドは終了0（619 jobs）、新しい境界21定理と既存の10項目の境界も終了0である。全46モジュールの6,276宣言の公理依存はpropext / Quot.sound / Classical.choiceだけであり、sorry・独自公理はない。単独検査と既定ビルドのLeanは-M 12288。workは実行していない。

今回の差分は [r5-production.patch](../l00b.02/02a-r5-production.patch) であり、前の担当の未コミット差分を含む今回開始時からの差分である。git、処理系、現行設計書、planの操作・編集は行わず、次の群にも進んでいない。
