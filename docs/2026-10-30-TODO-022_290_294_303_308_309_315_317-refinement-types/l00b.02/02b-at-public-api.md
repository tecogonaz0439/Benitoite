# `.02b-at` で追加した公開の宣言

2026-10-31。共通接頭辞は `Benitoite.Release.Refinement.` である。手で付けた名前を列挙し、構成子・射影・等式定理・recursor・derivingの生成物・非公開の補助は重ねない。既存のembedPrimKindはSyntaxへ移したものであり、新規へ数えない。実際の全宣言は77モジュールのA-Lで照合する。

| モジュール | 新しく公開した定義・補題 |
|---|---|
| [Adequate](../../../formal/Benitoite/Release/Refinement/Adequate.lean) | `SnapshotAdequate`、`Val.Adequate`、`adequateVals`、`Comp.Adequate`、`adequateArms`、`adequateClauses`、`Capture.Adequate`、`adequateCaptureSlots`、`Closure.Adequate`、`Frame.Adequate`、`Cont.Adequate`、`Cell.Adequate`、`Store.Adequate`、`Outcome.Adequate`、`AdequateResult`、`SnapshotMem.kind`、`SnapshotMem.current`、`Val.adequate_pathBases`、`Val.adequate_checkedAt_current` |
| [AtContracts](../../../formal/Benitoite/Release/Refinement/AtContracts.lean) | `Eff.single`、`atErrorType`、`atErrorFields`、`ResultShape.StandardError`、`ResultShape.Declared`、`ResultShape.Declared.errorType_eq`、`ResultShape.Declared.errorType_declared`、`ResultShape.Declared.error_data`、`ResultShape.Declared.error_observation_declared` |
| [AtInput](../../../formal/Benitoite/Release/Refinement/AtInput.lean) | `parseUrlTarget`、`Val.reqTarget`、`Val.target?`、`parseAtInput`、`parseAtPattern` |
| [AtPrepare](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean) | `groundTy`、`groundTys`、`groundVal`、`groundVals`、`groundTy_wf`、`groundTys_wf`、`groundVal_ground`、`groundVals_closed`、`AtRequest`、`AtPrepare`、`AtPrepared`、`AtPrepared.fixed_index`、`AtPrepare.fixed_index`、`AtPrepare.no_staticIndex` |
| [AtSound](../../../formal/Benitoite/Release/Refinement/AtSound.lean) | `checkAt.sound` |
| [AtTyping](../../../formal/Benitoite/Release/Refinement/AtTyping.lean) | `AtError.values_typed`、`CheckedWitness.kind`、`CheckedWitness.membership`、`HasTypeVQ.checked_opaque`、`HasTypeVQ.checkedRequest_opaque`、`CheckedWitness.absolute_plain`、`CheckedWitness.absolute_request`、`HasTypeVQ.checkedAt_subst`、`AtCallAdmissible.fixed_index`、`AtCallAdmissible.no_staticIndex`、`Pred.member_bind`、`Term.targetValue_wf`、`Val.checkedAt_snapshot_subst` |
| [BuiltinResponse](../../../formal/Benitoite/Release/Refinement/BuiltinResponse.lean) | `BuiltinArgs`、`Builtins.ResponseAssumptions`、`PrimSig.shapeAt`、`Builtins.TargetAgreement` |
| [ConstraintAssumptions](../../../formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean) | `Builtins.CoreAssumptions.responses` |
| [PathResolution](../../../formal/Benitoite/Release/Refinement/PathResolution.lean) | `PathEnv.Valid`、`PathEnv.lookup`、`PathEnv.Binds`、`PathPattern.atBase`、`RangeExpr.resolve`、`TargetInput.resolve`、`RangeExpr.Mem`、`SnapshotMem`、`AtError.Closed`、`AtResult`、`RangeExpr.base?`、`TargetInput.base?`、`resolveSnapshot`、`resolveTargetSnapshot`、`atDetail`、`checkAt` |
| [Preparation](../../../formal/Benitoite/Release/Refinement/Preparation.lean) | `PathRequirement`、`PreparationNode`、`PreparationNode.Child`、`PreparationNode.Reachable`、`PathEnv.Required`、`PathEnv.Ready`、`InitialPrepared`、`InitialPrepared.ready` |
| [ScopeSyntax](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean) | `AtError.textFields` |
| [Source](../../../formal/Benitoite/Release/Refinement/Source.lean) | `Val.Source`、`sourceVals`、`Comp.Source`、`sourceArms`、`sourceClauses` |
| [SubstTyping](../../../formal/Benitoite/Release/Refinement/SubstTyping.lean) | `Eff.subst_values_empty`、`Eff.subst_values_single` |
| [Syntax](../../../formal/Benitoite/Release/Refinement/Syntax.lean) | `ResultShape`、`PrimKind`、`processEnvironmentEff`、`AtError.values` |
| [Typing](../../../formal/Benitoite/Release/Refinement/Typing.lean) | `CheckedWitness`、`AtCallAdmissible` |
| [TypingShift](../../../formal/Benitoite/Release/Refinement/TypingShift.lean) | `Eff.shiftV_single`、`CheckedWitness.shift_store`、`AtCallAdmissible.shift_values` |

手で付けた新規名は **107名** である。HasTypeVQ/CQ/Vs/Each/TelArgsの既存入口の改訂、三族・TypedFacts・hide/None版・Declaredの正則性はresultsの表に別記する。
