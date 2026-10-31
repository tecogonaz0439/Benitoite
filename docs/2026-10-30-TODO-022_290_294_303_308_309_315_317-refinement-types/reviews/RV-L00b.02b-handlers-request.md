# RV-L00b.02b-handlers：群末のレビュー依頼

独立レビューの所見への修正は、[resultsの「レビューの所見の対応」](../l00b.02/results.md)と[修正後の公開署名](../l00b.02/02b-handlers-r3-public-api.md)を参照する。以下は初回提出時の依頼の記録であり、guardの旧文脈とAtだけの一覧は修正済みである。
2026-10-31。停止点の案Aを取りまとめが一般の型改名へ広げて承認したため再開し、14導出と三族、群末の検査を終えた。**完成後の独立レビューを依頼する。** B_WORKは `5a602b7a2adc40e487f60c8ffc738d2f4595289c`、指定ブランチは `m014/l00b.02b-handlers`。gitの操作・切替・作成・コミットは行っていない。閉包・状態の次群には進んでいない。

## 読む順序

1. planの「計画の変更と取りまとめへの確認点」の2026-10-31の先頭の判断と、[停止点の契約の再開追記](../l00b.02/02b-handlers-contract.md)。planは変更していない。
2. [signatures第29節](../l00b.02/signatures.md)の信頼条件・補助契約・義務の完了と送り先。第28節は停止時点の記録である。
3. [resultsの再開後の完成の節](../l00b.02/results.md)、[公開宣言一覧](../l00b.02/02b-handlers-r2-public-api.md)、[変更32ファイルとハッシュ](../l00b.02/02b-handlers-r2-source-changes.json)。
4. 下記の新規本番19ファイルと変更13ファイル。旧Releaseは読み取り対象として残し、変更していない。
5. [二反例の現行API用の補助](../l00b.02/02b-handlers-r2-boundary.lean)、[行の境界](../l00b.02/02b-handlers-r2-rows.lean)、[検査全体](../l00b.02/02b-handlers-r2-validation.json)。

## 確認してほしい点

1. D28の意味の変更が取りまとめの承認の範囲にあること。CoreAssumptionsはSubstitutionAssumptionsを含み、TypeAssumptionsは制約を改名先の位置へ保つ一般のρとAnnotationを前提とする。型・型列のsat/admitsの保存を要求し、旧sat_subst/admits_substを同じ変更で移し、sat_local/admits_localを恒等改名から導いている。Leanの公理にはしていない。新三モデルの充足はL50の義務である。
2. 元の二反例を保管し、現行API用の写しではPriorCoreAssumptionsとして旧条件の充足を確認した上で、closed_table_excluded/open_table_excludedにより現行のTypeAssumptionsを満たせないことを示していること。旧反例を現行の条件に対する反例と誤記していないか。
3. Cの5、Arms3、Clauses2、Failure1、ImageOk3の14導出と、三族の63被覆義務を閉じていること。CheckedWitnessの閉じた証拠の再利用とImageOkの補助の3場合を、相互matchの件数と混同していないか。AtCallの補助1は別記している。
4. CQ/Arms/Clauses/FailureのSubstOkのR0が結論のRの像に拘束され、None版も親Rの一束縛の移動と交換していること。contVar/contLoc、SubstOk.hide/up/upN/extendNone/shiftE/clauseを一緒に確認してほしい。ResumeLは部分型・効果拡大の下でも場所のRを保つ。
5. 通常節の型パラメータ、宣言順の全入力、最後の継続、Failの型パラメータ1/error/Noneの番号が一致すること。Clause.substListで置換像の型パラメータも移動し、入力間の依存を保っていること。全Φ/R/結果/行の移動と、guardのhideBuilders/hideConts・R=none・空の局所文脈を確認してほしい。
6. CQの移動のFullShiftMapと、値だけのShiftMapの使い分け。Ctx.Narrows.hereの元・先の型のWF、継続のlookupの保持、ResumeのDeclaredの前提が、担当に委ねられた補助契約の具体化として妥当であること。主な定理への未承認の前提や利用者の書ける形の制限を導入していないか。
7. PatTy7/PatTys2/AltsTy、Inhabits23/All2/Each2/Exhaustiveと移動・置換を全形で処理していること。篩はcarrierからの保守的な形で、一般の篩の網羅性の接続を完成と数えていない。
8. 標準エラーの七欄をvalues/values_typedで照合し、P.consの現在の構成子一覧と内部一覧の一致をProgram.StandardErrorCompleteで明示してExhaustiveへ接続していること。StandardErrorの存在条件だけから一覧の完全性を推測していないか。U02の公開形と文言の最終照合をL50/L70に残したことも確認してほしい。
9. PathBasesの署名をClauseSig・空の入力・結果・OpSig.WFへ接続し、前群の専用発行の遷移を保ったこと。全handle/resume/drop/issueの状態保存はL20/L70へ残している。
10. importの分割、Ground/Capture/Sourceと全構文操作・Declaredの該当場合の整合。新規のVal/Comp構成子を加えておらず、既存の構文の場合を欠落させていないこと。次群の8導出・StoreOk・TelArgsの逆向き接続を実装したとは数えていないこと。

## 場合数・検査

- 追加 **14/14**。累計はV26/C20/Vs2/Each2/TelArgs2/CheckedWitness2/Arms3/Clauses2/Failure1/ImageOk3の **63被覆義務**。PatTy7/PatTys2、Inhabits23/All2/Each2、AtCall補助1を別記する。Val25/Comp16/Arm1/Clause2/Step76は不変である。
- `cd formal && lake build`：**終了0、669 jobs、33.363秒**。最終変更後の関係モジュールを再ビルドした。既存のInterval等のlint警告は残る。
- 二反例と現条件による除外：**終了0、69宣言、1.410秒**。
- 行の境界：**終了0、31宣言、0.828秒**。R0の拒否とResumeの置換、多相束縛の型移動、Noneの位置、非空の全Φ、標準エラー、PathBases、公開署名の#checkを含む。
- A-L：本番Refinementの**96モジュールと旧指定7宣言、10,307宣言**、終了0、9.558秒。一意な件数・モジュール別件数+7を照合した。両境界を含め、依存は**propext・Quot.sound・Classical.choiceのみ**である。許可外公理・sorryAx・独自公理・本番Refinementの禁止トークンは0件。
- Lean4.34.1、全Leanプロセスは**-M 12288**。旧Release・固定版・lakefileは不変。検査中の全426本番入力の変更は0件。
- 生のA-Lの全出力**1,070,864バイト**は`<tmp>`へ置き、[large-records](../l00b.02/large-records.md)へサイズ・SHA-256を記録した。
- [再実行の台本](../l00b.02/02b-handlers-r2-validate.py)はgitを使わず、既定ビルド・両境界・A-L・版・禁止トークン・入力の同一性を検査する。workは取りまとめへ残した。RSSは未取得（計画上の非採取）。

## 新規の本番ファイルの全一覧

- [AtPatterns.lean](../../../formal/Benitoite/Release/Refinement/AtPatterns.lean)
- [HandlerAlgebra.lean](../../../formal/Benitoite/Release/Refinement/HandlerAlgebra.lean)
- [HandlerContracts.lean](../../../formal/Benitoite/Release/Refinement/HandlerContracts.lean)
- [HandlerTyping.lean](../../../formal/Benitoite/Release/Refinement/HandlerTyping.lean)
- [PatternSemantics.lean](../../../formal/Benitoite/Release/Refinement/PatternSemantics.lean)
- [PatternTransport.lean](../../../formal/Benitoite/Release/Refinement/PatternTransport.lean)
- [PatternTypeShift.lean](../../../formal/Benitoite/Release/Refinement/PatternTypeShift.lean)
- [Patterns.lean](../../../formal/Benitoite/Release/Refinement/Patterns.lean)
- [TypeRenaming.lean](../../../formal/Benitoite/Release/Refinement/TypeRenaming.lean)
- [TypeShiftAlgebra.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftAlgebra.lean)
- [TypeShiftContext.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftContext.lean)
- [TypeShiftContracts.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftContracts.lean)
- [TypeShiftExchange.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftExchange.lean)
- [TypeShiftKinds.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftKinds.lean)
- [TypeShiftOrder.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftOrder.lean)
- [TypeShiftSyntax.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftSyntax.lean)
- [TypeShiftTyping.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftTyping.lean)
- [TypingStore.lean](../../../formal/Benitoite/Release/Refinement/TypingStore.lean)
- [ValueRenameAlgebra.lean](../../../formal/Benitoite/Release/Refinement/ValueRenameAlgebra.lean)

## 変更した本番ファイルの全一覧

- [formal/Benitoite.lean](../../../formal/Benitoite.lean)
- [formal/Benitoite/Release/Refinement/Capture.lean](../../../formal/Benitoite/Release/Refinement/Capture.lean)
- [formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean](../../../formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean)
- [formal/Benitoite/Release/Refinement/LocalTransport.lean](../../../formal/Benitoite/Release/Refinement/LocalTransport.lean)
- [formal/Benitoite/Release/Refinement/Narrowing.lean](../../../formal/Benitoite/Release/Refinement/Narrowing.lean)
- [formal/Benitoite/Release/Refinement/RuntimeMatch.lean](../../../formal/Benitoite/Release/Refinement/RuntimeMatch.lean)
- [formal/Benitoite/Release/Refinement/Semantics.lean](../../../formal/Benitoite/Release/Refinement/Semantics.lean)
- [formal/Benitoite/Release/Refinement/Subst.lean](../../../formal/Benitoite/Release/Refinement/Subst.lean)
- [formal/Benitoite/Release/Refinement/SubstTyping.lean](../../../formal/Benitoite/Release/Refinement/SubstTyping.lean)
- [formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean](../../../formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean)
- [formal/Benitoite/Release/Refinement/Typing.lean](../../../formal/Benitoite/Release/Refinement/Typing.lean)
- [formal/Benitoite/Release/Refinement/TypingDeclared.lean](../../../formal/Benitoite/Release/Refinement/TypingDeclared.lean)
- [formal/Benitoite/Release/Refinement/TypingShift.lean](../../../formal/Benitoite/Release/Refinement/TypingShift.lean)

## 改造文書の新規ファイルの全一覧

停止時点に置いた記録も含む。公理依存の100 KBを超える生の出力はlarge-recordsの表だけに記録する。

- [02b-handlers-artifact-inputs.json](../l00b.02/02b-handlers-artifact-inputs.json)
- [02b-handlers-axioms-summary.json](../l00b.02/02b-handlers-axioms-summary.json)
- [02b-handlers-build.log](../l00b.02/02b-handlers-build.log)
- [02b-handlers-commands.json](../l00b.02/02b-handlers-commands.json)
- [02b-handlers-contract-boundary.lean](../l00b.02/02b-handlers-contract-boundary.lean)
- [02b-handlers-contract-boundary.log](../l00b.02/02b-handlers-contract-boundary.log)
- [02b-handlers-contract.md](../l00b.02/02b-handlers-contract.md)
- [02b-handlers-delivery.json](../l00b.02/02b-handlers-delivery.json)
- [02b-handlers-inputs-final.json](../l00b.02/02b-handlers-inputs-final.json)
- [02b-handlers-lean-version.log](../l00b.02/02b-handlers-lean-version.log)
- [02b-handlers-r2-artifact-inputs.json](../l00b.02/02b-handlers-r2-artifact-inputs.json)
- [02b-handlers-r2-axioms-summary.json](../l00b.02/02b-handlers-r2-axioms-summary.json)
- [02b-handlers-r2-axioms.lean](../l00b.02/02b-handlers-r2-axioms.lean)
- [02b-handlers-r2-boundary.lean](../l00b.02/02b-handlers-r2-boundary.lean)
- [02b-handlers-r2-boundary.log](../l00b.02/02b-handlers-r2-boundary.log)
- [02b-handlers-r2-build.log](../l00b.02/02b-handlers-r2-build.log)
- [02b-handlers-r2-case-inventory.json](../l00b.02/02b-handlers-r2-case-inventory.json)
- [02b-handlers-r2-commands.json](../l00b.02/02b-handlers-r2-commands.json)
- [02b-handlers-r2-delivery.json](../l00b.02/02b-handlers-r2-delivery.json)
- [02b-handlers-r2-final-check.json](../l00b.02/02b-handlers-r2-final-check.json)
- [02b-handlers-r2-inputs-final.json](../l00b.02/02b-handlers-r2-inputs-final.json)
- [02b-handlers-r2-lean-version.log](../l00b.02/02b-handlers-r2-lean-version.log)
- [02b-handlers-r2-public-api.md](../l00b.02/02b-handlers-r2-public-api.md)
- [02b-handlers-r2-rows.lean](../l00b.02/02b-handlers-r2-rows.lean)
- [02b-handlers-r2-rows.log](../l00b.02/02b-handlers-r2-rows.log)
- [02b-handlers-r2-source-changes.json](../l00b.02/02b-handlers-r2-source-changes.json)
- [02b-handlers-r2-start.json](../l00b.02/02b-handlers-r2-start.json)
- [02b-handlers-r2-validate.py](../l00b.02/02b-handlers-r2-validate.py)
- [02b-handlers-r2-validation.json](../l00b.02/02b-handlers-r2-validation.json)
- [02b-handlers-start.json](../l00b.02/02b-handlers-start.json)
- [02b-handlers-validate.py](../l00b.02/02b-handlers-validate.py)
- [02b-handlers-validation.json](../l00b.02/02b-handlers-validation.json)


- reviews/RV-L00b.02b-handlers-request.md（本書）

本依頼ファイルは停止点の依頼から群末の依頼へ更新した。既存の追記・更新はl00b.02/signatures.md（第24・28・29節）、results.md（再開後の完成）、large-records.mdである。停止点の契約の追記も上記の一覧に含む。

## 残りと受け入れ

今回の群の実装の残りはない。次の閉包・状態の8導出、捕捉したΓ/Φと依存β、場所のDeclared、外部TelArgsの逆向き接続は次群へ渡す。型改名の三モデルはL50、全状態保存はL20/L70、標準エラーの公開形・文言はL50/L70、D28の対照と設計者への報告は.15・取りまとめである。一般のパターンの移動・置換や継続のupをL10/L20へ再び割り当てない。

再開の開始10:03:24 JSTから最終検査11:28:14 JSTまでの外側は5,090.43秒（約84.84分）である。文書の仕上げと提出時の照合を含む時間は[受け渡し](../l00b.02/02b-handlers-r2-delivery.json)を参照する。能動時間と待ちは分離していない。12時間の停止条件には達していない。

| 残る手順 | 担当・内容 | 見込み時間 |
|---|---|---|
| 独立レビュー | レビュー担当。上記の契約・全ファイル・記録を照合する | 不明 |
| 作業末のwork | 取りまとめ。形式化のビルドと禁止宣言の検査を共通入口で実行する | 不明 |
| 所見への対応・受け入れ | 取りまとめ・設計者。D28の報告と次群への義務を確認する | 不明 |
| 次群の起動 | 取りまとめ。閉包・状態の群を別途起動する | 既定の3〜6時間 |
