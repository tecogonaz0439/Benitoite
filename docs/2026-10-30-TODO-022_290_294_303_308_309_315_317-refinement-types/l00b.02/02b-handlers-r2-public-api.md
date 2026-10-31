# .02b-handlers の公開宣言の一覧

再開後の新規・変更モジュールを対象とする。各行は、そのモジュールの公開の手書き宣言をソース上の表記で列挙する。変更しなかった既存宣言も含む。帰納型の構成子と生成されたrecursor・等式補題は、axiomsの環境からの全件列挙に含める。完全な型は本番とrowsの#checkを正とする。

## AtPatterns.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/AtPatterns.lean)

`atErrorConstructors`（7行）、`Program.StandardErrorComplete`（10行）、`atErrorPattern`（13行）、`InhabitsAll.length`（15行）、`PatTys.variables`（20行）、`matchList_variables`（26行）、`atErrorPattern_typed`（36行）、`AtError.match_pattern`（45行）、`AtError.match_pattern_typed`（51行）、`Exhaustive.atError`（76行）

## Capture.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/Capture.lean)

`Capture.env`（7行）、`Capture.closeTy`（8行）、`Capture.closeEff`（9行）、`Capture.closeR`（10行）、`Capture.closeTyAt`（11行）、`Capture.closeEffAt`（12行）、`Capture.closeRAt`（13行）、`Capture.closeTel`（14行）、`Capture.extend`（16行）、`Capture.extendNone`（17行）、`Capture.extendMany`（18行）、`Closure.pure`（20行）、`Closure.apply`（21行）、`lambdaShape`（24行）、`closeVal`（27行）、`closeVals`（53行）、`Closure.view`（59行）、`closeVals_length`（79行）、`Capture.extend_values`（82行）、`Capture.extend_env_zero`（83行）、`Capture.extend_env_succ`（84行）、`Capture.extendNone_env_succ`（85行）、`builderValueSubst`（87行）、`Comp.substTy`（91行）、`Val.substTy`（92行）、`Val.instantiate`（95行）、`Clause.body`（97行）、`Arm.alts`（102行）、`Arm.guard`（105行）、`Arm.body`（108行）

## ConstraintAssumptions.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean)

`TypedValueImages`（15行）、`Builtins.ValueAssumptions`（20行）、`Builtins.TypeAssumptions`（35行）、`Builtins.SubstitutionAssumptions`（51行）、`Builtins.TypeAssumptions.sat_shiftTypes`（55行）、`Builtins.TypeAssumptions.admits_shiftTypes`（64行）、`Builtins.TypeAssumptions.sat_local`（76行）、`Builtins.TypeAssumptions.admits_local`（83行）、`SatAll.map`（95行）、`PrimSig.PathBasesShape`（104行）、`PrimSig.StoreShape`（114行）、`Builtins.CoreAssumptions`（134行）、`Builtins.CoreAssumptions.values`（148行）、`Builtins.CoreAssumptions.substitutions`（152行）、`Builtins.CoreAssumptions.responses`（156行）、`Builtins.CoreAssumptions.issuePathBases_typed`（160行）、`Builtins.CoreAssumptions.pathBases_empty_arguments`（167行）、`Builtins.CoreAssumptions.pathBases_empty_values`（181行）、`Builtins.CoreAssumptions.pathBases_apply_destination`（193行）

## HandlerAlgebra.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/HandlerAlgebra.lean)

`Ty.shiftV_fixed_before`（6行）、`Ty.subst_up_fixed`（13行）、`binderRenames`（19行）、`binderRenames_length`（23行）、`binderRenames_fixed`（27行）、`binderImages_fixed`（37行）、`Ty.shiftTypes_fixed_before`（45行）、`BinderTypes.LocalWF.shiftTypes_fixed`（51行）、`Ty.rawRenameTypes_comp`（58行）、`rawRenameTypesList_comp`（62行）、`rawRenameRowsTypes_comp`（65行）、`rawRenameTelTypes_comp`（68行）、`shiftTypes_comm`（79行）、`shiftRowsTypes_comm`（83行）、`Eff.shiftV_union`（87行）、`Eff.shiftTypes_union`（92行）、`ClauseSig.same_atoms`（97行）、`ClauseSig.shift_values`（105行）、`ClauseSig.shift_types`（108行）、`substEffValues_atoms`（111行）、`ClauseSig.subst_values`（115行）、`handles_rename`（118行）、`handles_subst`（124行）、`handles_shiftEAt`（130行）、`handled_rename`（136行）、`handled_subst`（139行）、`handled_shiftEAt`（142行）、`handled_shift_values`（145行）、`handled_shift_types`（147行）、`HasTypeVQ.shift_types_var`（172行）、`substEffValues_union`（177行）、`TypeCtxMap.prefix`（197行）、`OpSig.continuation_shift_types`（213行）、`TypeCtxMap.clause`（220行）、`TypeCtxMap.failure`（228行）、`OpSig.continuation_subst_values`（233行）、`handled_subst_values`（241行）

## HandlerContracts.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/HandlerContracts.lean)

`Ty.instTarget`（7行）、`OpSig`（12行）、`opSigAt`（19行）、`opSig`（27行）、`Eff.ClauseRangeIs`（30行）、`ClauseIxOk`（34行）、`ClauseSig`（37行）、`ClauseSig.ne_fail`（40行）、`ClauseSig.of_opSig`（45行）、`effOps`（48行）、`Clause.op`（53行）、`handles`（57行）、`handled`（59行）、`BinderTypes.LocalWF`（66行）、`OpSig.WF`（70行）、`OpSig.continuation`（73行）、`OpSig.context`（77行）、`failureContext`（80行）

## HandlerTyping.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/HandlerTyping.lean)

`Builtins.CoreAssumptions.pathBases_clause_signature`（7行）、`HasTypeCQ.resume_location_contract`（31行）

## LocalTransport.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/LocalTransport.lean)

`renameKind_shift`（6行）、`renameKind_comm`（11行）、`substKind_shift`（16行）、`renameKind_closed`（21行）、`substKind_closed`（30行）、`LocalCtx.Shift.empty`（36行）、`LocalCtx.Shift.refl`（39行）、`LocalCtx.Shift.extend`（47行）、`LocalCtx.Shift.localExtend`（73行）、`LocalRef.HasKind.shift`（79行）、`LocalRef.HasKind.lift`（87行）、`LocalSubstOk.empty`（94行）、`LocalSubstOk.extend`（97行）、`LocalRef.HasKind.subst`（123行）、`BuilderKind.contents_rename`（130行）、`BuilderKind.contents_subst`（134行）、`BuilderOp.parameters_rename`（137行）、`BuilderOp.resultType_rename`（141行）、`BuilderOp.parameters_subst`（145行）、`BuilderOp.resultType_subst`（149行）

## Narrowing.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/Narrowing.lean)

`Ctx.ContMap`（12行）、`Ctx.ContMap.params`（15行）、`Ctx.ContMap.none`（33行）、`Ctx.Narrows`（491行）、`Ctx.Narrows.conditions`（499行）、`HasTypeVQ.narrow`（547行）、`HasTypeVsQ.narrow`（552行）、`HasTypeEachQ.narrow`（557行）、`HasTypeCQ.narrow`（562行）、`HasTypeTelArgsQ.narrow`（567行）、`HasTypeArmsQ.narrow`（574行）、`HasTypeClausesQ.narrow`（581行）、`HasFailureClause.narrow`（586行）、`ImageOk.narrow`（591行）

## PatternSemantics.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/PatternSemantics.lean)

`Inhabits.of_subst_values`（6行）、`InhabitsAll.of_subst_values`（86行）、`InhabitsEach.of_subst_values`（97行）、`Inhabits.of_shift_values`（104行）、`InhabitsAll.of_shift_values`（176行）、`InhabitsEach.of_shift_values`（187行）、`Exhaustive.subst_values`（194行）、`Exhaustive.shift_values`（198行）、`unguardedPats_rename`（202行）、`unguardedPats_subst`（209行）

## PatternTransport.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/PatternTransport.lean)

`restTys_map`（6行）、`PatTy.shift_values`（13行）、`PatTys.shift_values`（38行）、`PatTy.subst_values`（47行）、`PatTys.subst_values`（72行）、`AltsTy.map`（80行）、`AltsTy.shift_values`（88行）、`AltsTy.subst_values`（92行）

## PatternTypeShift.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/PatternTypeShift.lean)

`PatTy.shift_types`（7行）、`PatTys.shift_types`（32行）、`Inhabits.of_shiftTypes`（40行）、`InhabitsAll.of_shiftTypes`（113行）、`InhabitsEach.of_shiftTypes`（124行）、`AltsTy.shift_types`（132行）、`Exhaustive.shift_types`（136行）

## Patterns.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/Patterns.lean)

`unguardedPats`（8行）、`restTys`（13行）、`PatTy`（17行）、`PatTys`（34行）、`Inhabits`（42行）、`InhabitsAll`（71行）、`InhabitsEach`（74行）、`Exhaustive`（79行）、`AltsTy`（82行）、`AltsTy.witness`（88行）

## RuntimeMatch.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/RuntimeMatch.lean)

`patternMatches`（5行）、`patternRange`（13行）、`matchVal`（19行）、`matchList`（41行）、`selectSlots`（51行）、`selectSlots_map`（58行）、`selectSlots_mem`（67行）、`firstAlt`（88行）

## Semantics.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/Semantics.lean)

`Event.Covered`（10行）、`Event.covered_pathBases`（17行）、`markPush`（20行）、`releases`（24行）、`findClause`（30行）、`NoHandler`（32行）、`UnhandledOp`（35行）、`SplitAt`（42行）、`Val.superStep`（45行）、`rResume`（53行）、`MatchPrefix`（55行）、`Step`（58行）、`Steps`（355行）

## Subst.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/Subst.lean)

`renEnv`（11行）、`renEnv_up`（13行）、`renameTy`（19行）、`renameEff`（20行）、`renameKind`（21行）、`telBinders`（26行）、`Val.rename`（32行）、`Val.renameList`（59行）、`Comp.rename`（63行）、`Arm.renameList`（82行）、`Clause.renameList`（90行）、`valEnv`（97行）、`substTyValues`（99行）、`substEffValues`（100行）、`substKind`（101行）、`upSubst`（106行）、`shiftTypes`（110行）、`shiftTelTypes`（132行）、`shiftTypesList`（135行）、`shiftRowsTypes`（138行）、`shiftKindE`（142行）、`Val.shiftEAt`（148行）、`Val.shiftEListAt`（175行）、`Comp.shiftEAt`（179行）、`Arm.shiftEListAt`（198行）、`Clause.shiftEListAt`（206行）、`Val.subst`（214行）、`Val.substList`（242行）、`Comp.subst`（247行）、`Arm.substList`（267行）、`Clause.substList`（276行）、`typeEnvAt`（285行）、`substTypeAt`（289行）、`substRowAt`（291行）、`Val.substTyAt`（300行）、`Val.substTyAtList`（327行）、`Comp.substTyAt`（331行）、`Arm.substTyAtList`（352行）、`Clause.substTyAtList`（360行）

## SubstTyping.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/SubstTyping.lean)

`ClosedTy`（16行）、`SubstOk`（20行）、`SubstOk.observations`（80行）、`SubstOk.references`（84行）、`SubstOk.declaration`（88行）、`SubstOk.transport`（93行）、`Ty.ordinary_bind_values`（98行）、`predBind_upSubst_shift`（147行）、`SubstOk.observation`（177行）、`Const.type_bind_values`（186行）、`substEffValues_empty`（190行）、`Val.substList_length`（261行）、`Eff.bind_singleFail`（265行）、`substEffValues_singleFail`（271行）、`Eff.subst_values_empty`（306行）、`Eff.subst_values_single`（310行）、`Ctx.extendOption`（316行）、`Ctx.extendOption_length`（320行）、`ShiftMap.outerOption`（324行）、`SubstOk.hide`（330行）、`ImageOk.lift`（343行）、`SubstOk.extendNone`（377行）、`SubstOk.wf`（394行）、`SubstOk.upValue`（401行）、`SubstOk.up`（432行）、`SubstOk.upN`（441行）、`SubstOk.upNValue`（470行）、`SubstOk.store`（487行）、`Transport.many_values`（501行）、`ImageOk.liftParams`（521行）、`SubstOk.params`（557行）、`ImageOk.shiftEAt`（592行）、`SubstOk.shiftEAt`（621行）、`SubstOk.shiftE`（637行）、`SubstOk.clause`（646行）、`SubstOk.clauseValue`（666行）、`Transport.clause_values`（683行）、`SubstOk.poly`（700行）、`shifted_values_facts`（711行）、`SubstOk.handler_clause`（719行）、`SubstOk.handler_conditions`（733行）、`SubstOk.handler_failure`（748行）、`SubstOk.failure_conditions`（759行）、`LocalSubstOk.localExtend`（771行）、`HasTypeVQ.subst`（1143行）、`HasTypeVsQ.subst`（1153行）、`HasTypeEachQ.subst`（1163行）、`HasTypeCQ.subst`（1173行）、`HasTypeTelArgsQ.subst`（1183行）、`HasTypeArmsQ.subst`（1193行）、`HasTypeClausesQ.subst`（1204行）、`HasFailureClause.subst`（1214行）、`SubstOk.transport_extendNone`（1224行）、`HasTypeVQ.subst_under_none`（1232行）、`HasTypeVsQ.subst_under_none`（1244行）、`HasTypeEachQ.subst_under_none`（1256行）、`HasTypeCQ.subst_under_none`（1268行）、`HasTypeTelArgsQ.subst_under_none`（1284行）、`HasTypeArmsQ.subst_under_none`（1296行）、`HasTypeClausesQ.subst_under_none`（1310行）、`HasFailureClause.subst_under_none`（1325行）

## SubstTypingObstruction.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean)

`HasTypeVQ.lam_annotations_wf`（30行）、`HasTypeCQ.return_value_typable`（46行）、`refinedInt`（52行）、`Γ`（53行）、`Δ`（54行）、`path`（55行）、`Φ`（56行）、`σ`（57行）、`failure`（58行）、`latent`（59行）、`sourceTy`（60行）、`failure_compare`（62行）、`failure_norm`（67行）、`latent_canonical`（69行）、`source_wf`（73行）、`source_sorted`（78行）、`image_type`（82行）、`images_typed`（84行）、`images_typed_bind`（94行）、`context_facts`（103行）、`transport`（106行）、`latent_image`（130行）、`latent_image_not_canonical`（136行）、`substituted_not_wf`（145行）、`sourceVal`（149行）、`valueTy`（150行）、`resultTy`（151行）、`value_wf`（153行）、`value_sorted`（156行）、`path_lift_sorted`（158行）、`path_lift_wf`（162行）、`source_le`（166行）、`lambda_typed`（171行）、`result_declared`（182行）、`source_v_sub`（187行）、`source_c_sub`（192行）、`rawSourceVal`（197行）、`raw_lambda_untypable`（200行）、`raw_return_untypable`（206行）、`subst_ok`（212行）、`conditions_image`（222行）、`substituted_lambda_typed`（227行）、`substituted_return_typed`（231行）、`normalized_image_canonical`（236行）、`swapIndex`（238行）、`swapσ`（239行）、`swap_involutive`（241行）、`swap_injective`（248行）、`swap_latent_image`（253行）、`swap_not_canonical`（259行）、`substituted_lambda_under_none`（272行）、`substituted_return_under_none`（283行）、`outer`（300行）、`Φ`（301行）、`narrowTy`（302行）、`source`（303行）、`target`（304行）、`result`（305行）、`original_wf`（307行）、`original_sorted`（310行）、`narrows`（313行）、`source_le`（317行）、`result_wf`（325行）、`result_sorted`（329行）、`result_declared`（333行）、`source_value`（338行）、`narrowed_value`（341行）、`source_comp`（344行）、`narrowed_comp`（349行）、`narrowed_under_none`（353行）

## TypeRenaming.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeRenaming.lean)

`Ty.rawRenameTypes`（7行）、`rawRenameTelTypes`（29行）、`rawRenameTypesList`（32行）、`rawRenameRowsTypes`（35行）、`Ty.renameTypes`（40行）、`TParam.Contains`（43行）、`TypeParamRenaming`（46行）、`TypeParamRenaming.id`（49行）、`TypeParamRenaming.prefix`（52行）、`TypeParamRenaming.under`（60行）、`TypeParamRenaming.suffix`（72行）、`TypeParamRenaming.insert`（80行）、`Ty.rawRenameTypes_id`（92行）、`rawRenameTypesList_id`（95行）、`rawRenameRowsTypes_id`（97行）、`rawRenameTelTypes_id`（99行）、`Ty.rawRenameTypes_shift`（104行）、`rawRenameTypesList_shift`（108行）、`rawRenameRowsTypes_shift`（111行）、`rawRenameTelTypes_shift`（114行）、`Ty.renameTypes_id_eq_norm`（120行）、`Ty.renameTypes_shift`（123行）

## TypeShiftAlgebra.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftAlgebra.lean)

`SubstEnv.mapTypeIndices`（6行）、`SubstEnv.mapTypeIndices_up`（9行）、`shiftTypes_rawApply`（15行）、`substAtoms_mapTypeIndices`（23行）、`rowFails_mapTypeIndices`（34行）、`shiftTypesList_append`（43行）、`Ty.shiftTypes_rawBind`（48行）、`Tel.shiftTypes_rawBind`（54行）、`shiftTypesList_rawBind`（59行）、`Eff.shiftTypes_rawBind`（63行）、`Ty.shiftTypes_bind`（71行）、`SubstEnv.AgreesBelow`（76行）、`SubstEnv.AgreesBelow.up`（82行）、`Ty.rawBind_agrees`（87行）、`Tel.rawBind_agrees`（104行）、`rawBindTys_agrees`（109行）、`Eff.rawBind_agrees`（114行）、`Ty.subst_shiftTypes`（120行）

## TypeShiftContext.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftContext.lean)

`Ctx.WF`（7行）、`TypeCtxMap`（10行）、`TypeCtxMap.shiftEAt`（14行）、`TypeCtxMap.cons`（17行）、`TypeCtxMap.extend`（26行）、`Ty.hasSort_shiftTypes`（48行）、`Ty.ordinary_shiftTypes`（53行）、`TypeCtxMap.images`（57行）、`TypeCtxMap.references`（62行）、`Pred.sorted_shiftTypes`（68行）、`Ty.sorted_shiftTypes`（75行）、`Tel.sorted_shiftTypes`（83行）、`sortedTys_shiftTypes`（88行）、`sortedEff_shiftTypes`（93行）、`Ty.core_shiftTypes`（98行）、`Term.HasData.shiftTypes`（103行）、`FieldRef.Declared.shiftTypes`（120行）、`Term.Declared.shiftTypes`（130行）、`declaredSlot_shiftTypes`（139行）、`declaredSlots_shiftTypes`（144行）、`Pred.Declared.shiftTypes`（151行）、`Ty.Declared.shiftTypes`（174行）、`Tel.Declared.shiftTypes`（192行）、`declaredTys_shiftTypes`（197行）、`declaredEff_shiftTypes`（202行）、`Ty.wf_shiftTypes`（207行）、`Eff.wf_shiftTypes`（212行）、`TypeCtxMap.annotation`（219行）

## TypeShiftContracts.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftContracts.lean)

`Ty.shiftTypes_of_wf_zero`（7行）、`Eff.shiftTypes_of_wf_zero`（13行）、`Ty.renameTypes_shift_of_wf`（21行）、`Builtins.TypeAssumptions.sat_shiftTypes_raw`（26行）、`Builtins.TypeAssumptions.admits_shiftTypes_raw`（33行）、`TypeCtxMap.annotations`（42行）、`TypeCtxMap.rows`（49行）、`SatAll.shiftTypes`（56行）、`TypeCtxMap.signature`（66行）、`NoFail.shiftTypes`（76行）、`TypeCtxMap.admissible`（80行）、`TypeCtxMap.primitive`（95行）、`TypeCtxMap.params`（111行）、`TypeCtxMap.none`（137行）、`TypeCtxMap.hide`（165行）、`TypeCtxMap.many`（173行）、`Ty.assume_shiftTypes`（179行）、`TypeCtxMap.facts`（184行）、`TypeCtxMap.transport`（188行）、`Ty.LeQ.shiftTypes`（198行）、`Eff.Covers.shiftTypes`（202行）、`instantiatedTel_shiftTypes`（208行）、`SignatureInstance.shiftTel`（214行）、`ExternalCallAdmissible.shiftTypes`（220行）、`TypeCtxMap.entails`（228行）、`LocalCtx.shiftEAt`（235行）、`LocalCtx.shiftEAt_extend`（237行）、`LocalCtx.shiftEAt_localExtend`（246行）、`LocalRef.HasKind.shiftTypes`（252行）

## TypeShiftExchange.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftExchange.lean)

`Val.toTerm_shiftEAt`（8行）、`Val.toTermSlots_shiftEAt`（12行）、`shiftTypes_renameTy`（17行）、`shiftRowsTypes_renameEff`（21行）、`shiftTelTypes_rename`（25行）、`telBinders_shiftTypes`（29行）、`shiftKindE_rename`（32行）、`Val.shiftEAt_rename`（37行）、`Val.shiftEListAt_rename`（42行）、`Comp.shiftEAt_rename`（45行）、`Arm.shiftEListAt_rename`（53行）、`Clause.shiftEListAt_rename`（60行）、`upSubst_shiftEAt`（68行）、`substTyValues_shiftEAt`（74行）、`substEffValues_shiftEAt`（79行）、`shiftKindE_contents`（84行）、`shiftKindE_result`（87行）、`shiftKindE_parameters`（91行）、`TypeCtxMap.methodRows`（95行）、`unguardedPats_shiftEAt`（105行）、`Tel.open_shiftTypes`（112行）、`Tel.arguments_typeShift`（118行）、`Tel.arguments_shiftTypes`（135行）

## TypeShiftKinds.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftKinds.lean)

`KindRenaming`（25行）、`rawRenameTypesList_length`（28行）、`Ty.notContCore_rawRenameTypes`（32行）、`Ty.HasKind.renameTypes`（38行）、`kindsList_renameTypes`（56行）、`kindsTel_renameTypes`（61行）、`kindsEff_renameTypes`（66行）、`TypeArgsKinded.shiftTypes`（71行）

## TypeShiftOrder.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftOrder.lean)

`Ty.tree_shiftTypes_compare`（14行）、`Tel.tree_shiftTypes_compare`（22行）、`Ty.trees_shiftTypes_compare`（28行）、`Eff.tree_shiftTypes_compare`（39行）、`Ty.shiftTypes_compare`（49行）、`shiftTypesList_eq_map`（53行）、`Ty.norm_shiftTypes`（58行）、`Tel.norm_shiftTypes`（61行）、`Ty.normTys_shiftTypes`（64行）、`Eff.norm_shiftTypes`（67行）

## TypeShiftSyntax.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftSyntax.lean)

`Ctx.shiftEAt`（6行）、`Ctx.shiftE`（7行）、`Ctx.extendMany`（9行）、`binderImages`（13行）、`BinderTypes.WF`（17行）、`BinderTypes.Sorted`（21行）、`binderImages_length`（25行）、`Ctx.extendMany_length`（29行）、`Val.shiftEListAt_length`（35行）、`Val.shiftE`（39行）

## TypeShiftTyping.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypeShiftTyping.lean)

`HasTypeVQ.shift_types`（12行）、`HasTypeVsQ.shift_types`（111行）、`HasTypeEachQ.shift_types`（121行）、`HasTypeCQ.shift_types`（131行）、`HasTypeArmsQ.shift_types`（221行）、`HasTypeClausesQ.shift_types`（243行）、`HasFailureClause.shift_types`（261行）、`HasTypeTelArgsQ.shift_types`（280行）、`AtCallAdmissible.shift_types`（294行）

## Typing.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/Typing.lean)

`hideConts`（18行）、`hideBuilders`（22行）、`StoreTy.WF.hide`（26行）、`StoreTy.PreservesNormals.hide`（34行）、`StoreTy.preserves_hide`（43行）、`bindParams`（48行）、`liftMany`（52行）、`BuilderKind.contents`（55行）、`BuilderKind.item`（60行）、`BuilderOp.parameters`（65行）、`BuilderOp.resultType`（70行）、`LocalCtx.extend`（75行）、`localExtend`（78行）、`LocalRef.HasKind`（82行）、`LocalCtx.Shift`（86行）、`LocalSubstOk`（90行）、`HasTypeVQ`（96行）、`HasTypeVsQ`（193行）、`HasTypeEachQ`（199行）、`HasTypeCQ`（205行）、`HasTypeTelArgsQ`（291行）、`CheckedWitness`（300行）、`AtCallAdmissible`（311行）、`HasTypeArmsQ`（324行）、`HasTypeClausesQ`（344行）、`HasFailureClause`（358行）、`ImageOk`（368行）、`HasTypeVQ.refine_integer`（383行）、`HasTypeTelArgs`（390行）、`HasTypeV`（392行）、`HasTypeVs`（393行）、`HasTypeEach`（394行）、`HasTypeC`（395行）、`HasTypeArms`（396行）、`HasTypeClauses`（397行）、`HasTypeCL`（398行）

## TypingDeclared.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypingDeclared.lean)

`Ctx.Declared`（11行）、`HasTypeVQ.declared`（14行）、`HasTypeVsQ.declared`（39行）、`HasTypeTelArgsQ.result_annotation`（46行）、`HasTypeTelArgsQ.declared`（52行）、`HasTypeArmsQ.declared`（56行）、`HasTypeCQ.declared`（62行）、`Ctx.Narrows.of_value`（87行）

## TypingShift.lean（変更）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypingShift.lean)

`Ty.IntegerCarrier.ordinary`（14行）、`Ty.assume_ordinary`（16行）、`Ty.NotContCore.ordinary`（19行）、`Ty.notContCore_of_wf_ordinary`（22行）、`Ty.LeQ.notContCore`（27行）、`ShiftMap`（36行）、`renameTy_shiftIndex`（41行）、`renameEff_shiftIndex`（44行）、`ShiftMap.declarationRenaming`（47行）、`ShiftMap.declared`（53行）、`ShiftMap.predDeclared`（58行）、`ShiftMap.values`（64行）、`ShiftMap.references`（72行）、`ShiftMap.facts`（78行）、`ShiftMap.transport`（87行）、`hideConts_lookup`（96行）、`ShiftMap.hide`（106行）、`ShiftMap.underParams`（114行）、`ShiftMap.underNone`（150行）、`ShiftMap.outer`（168行）、`ShiftMap.outerNone`（177行）、`Entails.under_none`（184行）、`liftMany_eq`（193行）、`liftMany_one`（214行）、`liftMany_shiftV`（216行）、`Entails.under_params`（228行）、`ShiftMap.conditions_params`（237行）、`Ctx.mem_facts_hide`（254行）、`Entails.hideConts`（263行）、`Transport.entails`（271行）、`ShiftMap.sorted`（278行）、`ShiftMap.wf`（283行）、`Ty.shiftV_of_wf_zero`（288行）、`ShiftMap.annotation`（292行）、`Val.renameList_length`（296行）、`Eff.shiftV_singleFail`（300行）、`shiftIndex_strict`（304行）、`ShiftMap.typeAnnotations`（307行）、`ShiftMap.rowAnnotations`（311行）、`ShiftMap.signature`（315行）、`ShiftMap.admissible`（324行）、`ShiftMap.primitive`（338行）、`ShiftMap.methodRows`（350行）、`Eff.shiftV_single`（363行）、`FullShiftMap`（367行）、`FullShiftMap.values`（371行）、`ShiftMap.hideFull`（374行）、`FullShiftMap.underParams`（378行）、`FullShiftMap.underNone`（414行）、`FullShiftMap.outer`（432行）、`FullShiftMap.outerNone`（441行）、`FullShiftMap.hide`（448行）、`Eff.shiftV_of_wf_zero`（452行）、`liftMany_add`（456行）、`bindParams_single`（460行）、`FullShiftMap.underMany`（462行）、`FullShiftMap.shiftEAt`（470行）、`FullShiftMap.conditions_many`（486行）、`OpSig.continuation_shift_values`（502行）、`FullShiftMap.clause`（507行）、`FullShiftMap.conditions_clause`（517行）、`FullShiftMap.failure`（533行）、`FullShiftMap.conditions_failure`（540行）、`HasTypeVQ.shift_values`（553行）、`HasTypeVsQ.shift_values`（685行）、`HasTypeEachQ.shift_values`（697行）、`HasTypeCQ.shift_values`（709行）、`HasTypeArmsQ.shift_values`（832行）、`HasTypeClausesQ.shift_values`（861行）、`HasFailureClause.shift_values`（879行）、`HasTypeTelArgsQ.shift_values`（896行）、`CheckedWitness.shift_store`（911行）、`AtCallAdmissible.shift_values`（925行）

## TypingStore.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/TypingStore.lean)

`shiftIndex_zero`（5行）、`shiftIndex_add`（8行）、`Ty.shiftV_zero`（11行）、`Eff.shiftV_zero`（14行）、`Pred.shiftV_zero`（17行）、`Tel.shiftV_zero`（21行）、`HasTypeVQ.hide_context`（25行）、`HasTypeTelArgsQ.hide_context`（38行）、`HasTypeVQ.weaken_empty`（52行）、`HasTypeCQ.weaken_empty`（60行）

## ValueRenameAlgebra.lean（新規）

[本番のソース](../../../formal/Benitoite/Release/Refinement/ValueRenameAlgebra.lean)

`renameTy_comp`（5行）、`renameEff_comp`（9行）、`upRen_compose`（13行）、`telBinders_rawBind`（20行）、`Tel.rawBind_ren_comp`（23行）、`renameKind_comp`（30行）、`LocalRef.rename_compose`（34行）、`Val.rename_compose`（38行）、`Val.renameList_compose`（43行）、`Comp.rename_compose`（46行）、`Arm.renameList_compose`（54行）、`Clause.renameList_compose`（62行）、`upSubst_add`（70行）、`upLocalSubst_zero`（82行）、`upLocalSubst_add`（85行）、`Ty.shiftV_add`（97行）、`Pred.shiftV_add`（104行）

## Benitoite.lean（変更）

[本番のソース](../../../formal/Benitoite.lean)

importのみを更新。公開宣言の追加はない。

