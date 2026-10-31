# RV-L00b.11 所見対応後のレビュー依頼

2026-11-01。RV-L00b.11（条件付き可、重なし・中2・軽6）の取りまとめの判断を適用した差分の確認を依頼する。L00b.11 の本体と今回の中2件の実装・正例は完了し、L00b.13 は未着手である。B_WORK は `5fd3664ed92b4eb20de0ba422e9e55c825019aff`、指定ブランチは `m014/l00b.11`。git 操作、処理系・設計書・plan・レビューの記録の変更、work は行っていない。

## 今回の対応で確認すること

[結果のRV対応の節](../l00b.11/results.md#rv-l00b11-の対応2026-11-01)、[完全署名と義務](../l00b.11/signatures.md)、[検査の台本](../l00b.11/verify.py)、[検査結果](../l00b.11/verification.json)、[公理依存](../l00b.11/axioms-summary.json) を照合する。元の所見と採った判断は [RV-L00b.11](RV-L00b.11.md) の取りまとめの追記を正とする。レビューの原記録と rv-11-* は編集していない。

1. 中1: Semantics の delta 2規則と ioResponse 3規則、Step の delta と IO oracle が、型引数は normTys、行引数は map Eff.norm を読むこと。項の raw の型・行引数、rs、BuiltinArgs の Canonical、Builtins/ResponseAssumptions の欄、Val.subst/Val.shiftEAt は保つこと。
2. instantiatedTel_norm_images と BuiltinArgs.normalized の一般補題を確認すること。PrimitiveAdmissible/SignatureInstance の正規化も元の契約だけから作ること。review-builtins-boundary は元の delta=none の表でも正規化した BuiltinArgs を作る。delta_typed/io_exists の正例は、成立する応答仮定の全欄を構成した表を使い、同じ raw の値の Step と step の結果を導くこと。非空の行引数の具体化の正例も確認すること。
3. step_prim_val/step_prim_err/step_io_val/step_io_err/step_io_exit と NoHandler.splitHandler_none により、影響を受ける5場合の step と Step の対応が閉じていること。Refinement 全体の step_sound を先取りしたことにはしない。
4. 中2: CellOk.val だけが値を a.norm で読むこと。StoreOk に Sorted/Normal を足さず、done/thunk/cont/used と実行時のセルを保つこと。CellOk.val_write/val_read/StoreOk.reference_read が、元の値と lookup に加えて canonical_ref の正規化後の等号と値の型の Normal だけで使えること。Unit{true} の StoreOk と同じ参照の canonical_ref から使う review-store-boundary を確認すること。
5. 軽1: ContTy.end_normal と resume_raw_return を本番へ置いたこと。Capture.closeRAt_normal/ClosureTy.return_normal と合わせ、StoreOk の下で生の R の等号を導いて連結に使えること。
6. 軽3: review-lambda-boundary の一引数の閉包の正例と inv_closure、DependentClosureTy.normal を確認すること。結論の型付けを仮定していないこと。
7. 軽5: 全29場合、Ty.Normal が Canonical の別名であること、実差分の数を照合すること。レビューの既存56・新規14を基準とし、差分のない BindCongr を候補から外した。今回、既存の BuiltinResponse/Semantics/Step/StateTyping の4件が増え、現在は既存60・新規14である。
8. 軽2・軽6: L00b.15 の制約・導出・遷移の入力・CellOk の新旧対照、L60 の正規形の上での sat/admits、L20 の fnView? の決定手続きと Lean の存在の定義との一致を義務にしたこと。軽4の全面ビルドの時間は取りまとめが work で確認する。
9. 全18検査の終了、公理依存の許可3種類と sorryAx の不在、入力のハッシュを確認すること。[review-contracts.json](../l00b.11/review-contracts.json) も照合すること。

## L00b.11 本体の確認範囲

D07 の篩の平坦化・truth の除去・順序/重複/falsity の保持、fn/dependentFn、無制限の rawApply_norm/subst_norm_images、O001 の構文の逆転と TelClosure/names_eq、O007 の Reference/Fail の構造等号は維持した。値29・計算24・ImageOk4、三族76、LocalRef.HasKind3、LeQ13、Step76に増減はない。新規則の必要性、偽の補助補題の訂正と反例は signatures/results に残している。

公理監査は差分をすべて含む Refinement 全129モジュールと集約モジュールの全宣言を対象とする。私有・生成宣言も省略しない。公開する全宣言の完全署名は public-api の出力にある。大きい記録は `<tmp>` に置き、large-records の表で照合する。

## 新しい本番ファイル（14ファイル、今回の所見対応で追加なし）

- `formal/Benitoite/Release/Refinement/Canonical.lean`
- `formal/Benitoite/Release/Refinement/Conjunction.lean`
- `formal/Benitoite/Release/Refinement/FunctionNormalForm.lean`
- `formal/Benitoite/Release/Refinement/InversionCore.lean`
- `formal/Benitoite/Release/Refinement/NormalWellFormed.lean`
- `formal/Benitoite/Release/Refinement/NormalizationLogic.lean`
- `formal/Benitoite/Release/Refinement/NormalizedApplication.lean`
- `formal/Benitoite/Release/Refinement/RawBindingShift.lean`
- `formal/Benitoite/Release/Refinement/RefinementNormalForm.lean`
- `formal/Benitoite/Release/Refinement/ShiftCancellation.lean`
- `formal/Benitoite/Release/Refinement/SubstitutionContracts.lean`
- `formal/Benitoite/Release/Refinement/ValueRenamingSyntax.lean`
- `formal/Benitoite/Release/Refinement/ValueShiftOrder.lean`
- `formal/Benitoite/Release/Refinement/ValueShiftSyntax.lean`

## 変更した既存の本番ファイル（60ファイル）

- `formal/Benitoite.lean`
- `formal/Benitoite/Release/Refinement/Admissible.lean`
- `formal/Benitoite/Release/Refinement/AdmissibleMap.lean`
- `formal/Benitoite/Release/Refinement/AtTyping.lean`
- `formal/Benitoite/Release/Refinement/Basic.lean`
- `formal/Benitoite/Release/Refinement/Bind.lean`
- `formal/Benitoite/Release/Refinement/BindingShift.lean`
- `formal/Benitoite/Release/Refinement/BuiltinResponse.lean`
- `formal/Benitoite/Release/Refinement/ClosedDecidable.lean`
- `formal/Benitoite/Release/Refinement/ClosureTyping.lean`
- `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean`
- `formal/Benitoite/Release/Refinement/Context.lean`
- `formal/Benitoite/Release/Refinement/Context/Capture.lean`
- `formal/Benitoite/Release/Refinement/Context/Declarations.lean`
- `formal/Benitoite/Release/Refinement/Context/Facts.lean`
- `formal/Benitoite/Release/Refinement/Context/WF.lean`
- `formal/Benitoite/Release/Refinement/ContextFacts.lean`
- `formal/Benitoite/Release/Refinement/DeclaredTransport.lean`
- `formal/Benitoite/Release/Refinement/ExternalCheck.lean`
- `formal/Benitoite/Release/Refinement/HandlerAlgebra.lean`
- `formal/Benitoite/Release/Refinement/HandlerTyping.lean`
- `formal/Benitoite/Release/Refinement/KindValues.lean`
- `formal/Benitoite/Release/Refinement/Kinds.lean`
- `formal/Benitoite/Release/Refinement/Le.lean`
- `formal/Benitoite/Release/Refinement/LocalResolveLemmas.lean`
- `formal/Benitoite/Release/Refinement/LocalTransport.lean`
- `formal/Benitoite/Release/Refinement/Narrowing.lean`
- `formal/Benitoite/Release/Refinement/NarrowingObstruction.lean`
- `formal/Benitoite/Release/Refinement/Normalize.lean`
- `formal/Benitoite/Release/Refinement/OpenSubstitution.lean`
- `formal/Benitoite/Release/Refinement/PatternSemantics.lean`
- `formal/Benitoite/Release/Refinement/RangeExchange.lean`
- `formal/Benitoite/Release/Refinement/RangeSubst.lean`
- `formal/Benitoite/Release/Refinement/Semantics.lean`
- `formal/Benitoite/Release/Refinement/ShiftOrder.lean`
- `formal/Benitoite/Release/Refinement/StateTyping.lean`
- `formal/Benitoite/Release/Refinement/Step.lean`
- `formal/Benitoite/Release/Refinement/SubstTyping.lean`
- `formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean`
- `formal/Benitoite/Release/Refinement/Syntax.lean`
- `formal/Benitoite/Release/Refinement/TelTyping.lean`
- `formal/Benitoite/Release/Refinement/Telescope.lean`
- `formal/Benitoite/Release/Refinement/Transport.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftAlgebra.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftContext.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftContracts.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftOrder.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean`
- `formal/Benitoite/Release/Refinement/TypeSubst.lean`
- `formal/Benitoite/Release/Refinement/TypedFacts.lean`
- `formal/Benitoite/Release/Refinement/Typing.lean`
- `formal/Benitoite/Release/Refinement/TypingDeclared.lean`
- `formal/Benitoite/Release/Refinement/TypingShift.lean`
- `formal/Benitoite/Release/Refinement/ValueBinding.lean`
- `formal/Benitoite/Release/Refinement/ValueClosed.lean`
- `formal/Benitoite/Release/Refinement/ValueExchange.lean`
- `formal/Benitoite/Release/Refinement/ValueInstantiation.lean`
- `formal/Benitoite/Release/Refinement/ValueReferences.lean`
- `formal/Benitoite/Release/Refinement/ValueRegularity.lean`
- `formal/Benitoite/Release/Refinement/ValueSubst.lean`

以前の控えが OS 再起動後に残っていなかった一部の以前の SHA-256 は null のままとし、B_WORK との正式な照合は取りまとめへ残す。今回の所見対応前のハッシュは review-before-sha256.json にある。基準版の実差分数はレビューの照合を引き継ぎ、担当は git を使っていない。

## 作業文書・入力・記録の全一覧

新規ファイルの漏れを防ぐため、既存の境界・文書と読み取り専用の rv-11-* も含めて l00b.11 の全ファイルを列挙する。

- [axiom-targets.txt](../l00b.11/axiom-targets.txt)
- [axioms-summary.json](../l00b.11/axioms-summary.json)
- [axioms.lean](../l00b.11/axioms.lean)
- [axioms.log](../l00b.11/axioms.log)
- [boundary.lean](../l00b.11/boundary.lean)
- [boundary.log](../l00b.11/boundary.log)
- [build.log](../l00b.11/build.log)
- [inputs-sha256.json](../l00b.11/inputs-sha256.json)
- [large-records.md](../l00b.11/large-records.md)
- [local-build.log](../l00b.11/local-build.log)
- [normalization-boundary.lean](../l00b.11/normalization-boundary.lean)
- [normalization-boundary.log](../l00b.11/normalization-boundary.log)
- [normalization-contract-obstruction.lean](../l00b.11/normalization-contract-obstruction.lean)
- [normalization-contract-obstruction.log](../l00b.11/normalization-contract-obstruction.log)
- [normalization-obstruction.lean](../l00b.11/normalization-obstruction.lean)
- [normalization-obstruction.log](../l00b.11/normalization-obstruction.log)
- [normalization-retractions.lean](../l00b.11/normalization-retractions.lean)
- [normalization-retractions.log](../l00b.11/normalization-retractions.log)
- [normalized-rules-boundary.lean](../l00b.11/normalized-rules-boundary.lean)
- [normalized-rules-boundary.log](../l00b.11/normalized-rules-boundary.log)
- [public-api.lean](../l00b.11/public-api.lean)
- [public-api.log](../l00b.11/public-api.log)
- [results.md](../l00b.11/results.md)
- [resume-return-contract-obstruction.lean](../l00b.11/resume-return-contract-obstruction.lean)
- [resume-return-contract-obstruction.log](../l00b.11/resume-return-contract-obstruction.log)
- [review-before-sha256.json](../l00b.11/review-before-sha256.json)
- [review-builtins-boundary.lean](../l00b.11/review-builtins-boundary.lean)
- [review-builtins-boundary.log](../l00b.11/review-builtins-boundary.log)
- [review-contracts.json](../l00b.11/review-contracts.json)
- [review-lambda-boundary.lean](../l00b.11/review-lambda-boundary.lean)
- [review-lambda-boundary.log](../l00b.11/review-lambda-boundary.log)
- [review-store-boundary.lean](../l00b.11/review-store-boundary.lean)
- [review-store-boundary.log](../l00b.11/review-store-boundary.log)
- [rv-11-count.lean](../l00b.11/rv-11-count.lean)
- [rv-11-count.log](../l00b.11/rv-11-count.log)
- [rv-11-lam.lean](../l00b.11/rv-11-lam.lean)
- [rv-11-primraw.lean](../l00b.11/rv-11-primraw.lean)
- [rv-11-primraw.log](../l00b.11/rv-11-primraw.log)
- [rv-11-ret.lean](../l00b.11/rv-11-ret.lean)
- [rv-11-sigdiff.py](../l00b.11/rv-11-sigdiff.py)
- [signatures.md](../l00b.11/signatures.md)
- [source-delta.json](../l00b.11/source-delta.json)
- [source-kind-contract.md](../l00b.11/source-kind-contract.md)
- [time-wrapper.log](../l00b.11/time-wrapper.log)
- [type-shift-contract.md](../l00b.11/type-shift-contract.md)
- [type-shift-normalization-obstruction.lean](../l00b.11/type-shift-normalization-obstruction.lean)
- [type-shift-normalization-obstruction.log](../l00b.11/type-shift-normalization-obstruction.log)
- [typing-normalization-obstruction.lean](../l00b.11/typing-normalization-obstruction.lean)
- [typing-normalization-obstruction.log](../l00b.11/typing-normalization-obstruction.log)
- [verification.json](../l00b.11/verification.json)
- [verify.py](../l00b.11/verify.py)

このほか、許可された l00a.06a/contracts.md の rawApply_norm の記述は前回の対応のままである。今回の所見対応では変更していない。

| 残る手順 | 担当と範囲 | 見込み |
|---|---|---|
| 再レビューと受け入れ | 中2件の本番接続・正例、軽の処置、記録を照合する | 不明 |
| work・全面ビルドの時間の確認・取り込み | 取りまとめ。担当は実行しない | 不明 |
| L00b.13 以降 | 受け入れ後に別途起動する。本作業では進めない | 不明 |
