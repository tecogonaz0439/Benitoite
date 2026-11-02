# 入口の読者の在庫

## 検索の限界と切替時の照合

この在庫は字句の検索であり、意味上の依存を列挙したものではない。`Ctx.facts` や `Ty.assume` を書かずに、具体の文脈を `simp`・`rfl`・`decide` で簡約する証明、仮定列の先頭を位置で読む `.hyp`、匿名の `.mk` の構成と分解は取りこぼし得る。型の字面を含むファイル数を変更する証明の数と数えない。.51の既定ビルドで簡約に頼る読者も確定し、.54で修正又は保持した理由を宣言ごとに記す。ExternalCheckの `closedTrue_entails` の弱化のような空列の使用も、検索の不一致だけで対象外にしない。

## ValueMeaning.mkの読者（群Iの入力）

`ValueMeaning|valueMeaning` をR/以下の全Leanへ検索した9ファイルである。構成子の直接の使用に加え、その意味を受け渡す読者も含める。二条件の構成子のパターンを三条件へ直す箇所と、新しい型域の条件を供給する箇所を分けて照合する。

| R/以下のファイル | 主な宣言・使用 | .51〜.54での処分 |
|---|---|---|
| ValueMeaning.lean | ValueMeaning.mk、norm_iff、of_scoped、scoped_inv、scoped_forget | 構成子へ型域の真を追加。正規化不変性で新条件を運び、型域が空の形では空列を示す。分解の第三条件も明示 |
| ValueMeaningInhabits.lean | valueMeaning_inhabits_normal、valueShapeMeaning_inhabits、valueMeanings_inhabit、valueMeaningEach_inhabit | mkの第三条件を受け、所属が読む形と明示篩を保持。使わない条件を新しい定理の前提へ増やさない |
| PatternNormalForm.lean | import ValueMeaningが一致。Inhabitsのcore/述語/正規形の補題 | ValueMeaning.mkの直接の構成/分解はない。所属の定義を変えないので保持候補とし、.51のビルドと.54で確認 |
| CoverageRefinement.lean | ValueMeaning.refined_iff、valueMeaning_refine、Capture.meaning_coverage | 篩の構成/分解で芯の型域の真を保持し、網羅性への意味の供給を追随。主な公開署名は維持 |
| MeaningTransport.lean | dependentFn_meaning、assumptions_meaning、MOrder、意味の移送の各枝、valueMeaning_sub | 明示篩とcarrierFactsを別に新assumptionsへ供給。空の型域と保存する型域を区別し、mk再構成とrefine/introduceを追随。辞書式の帰納を維持 |
| MeaningTransportObstruction.lean | continuation_meaning、source_argument_meaning、source_meaning、ordinary_supply_counterexample | cont/dataの空の型域を供給し、Ordinaryを無条件に供給できない反例を保つ |
| TypedCoverage.lean | Capture.typed_meaning、typed_coverage、CaptureOk.typed_variable_coverage | 閉じた型付けから新意味を供給する鎖を照合。CaptureOkの新しい事実を独立の仮定にしない |
| TypedMeaning.lean | constructor_meaning、const_meaning、typed_meaning_auxの値29場合、列/各要素の4場合 | 定数にはNumericRepresented.carrierFactsを供給し、他の形のmk再構成を追随。V_ConstではConstOK.representedを使う |
| TypedMeaningExamples.lean | typed_entries、Month/空篩/非空List/unknown、dependent_capture_entries、cap_monthなど | 強めた意味を同じ型付けから得て各具体例へ適用。位置で仮定を読む箇所と暗黙の簡約も既定ビルドで確認 |

再現コマンドは `rg -l 'ValueMeaning|valueMeaning' formal/Benitoite/Release/Refinement -g '*.lean'`。四つの元の検索の記録は次節以降に残す。

対象は変更前の `formal/Benitoite/Release/Refinement/**/*.lean`。コメントと例を除外せず、一致物理行を検索ごとに数えた。宣言名は行の直前の宣言を取る近似であり、構成・分解の区別は本文を読む。既存の詳しい在庫は [前段の記録](../results.md#r1-読者の在庫) と一致した。

## `assume`

29ファイル・141行。

| ファイル（R/以下） | 宣言と一致行 |
|---|---|
| Context/Facts.lean | `assume_subset` 21,22,24; `refined_map` 30; `Ty.assume_wellFormed` 66,67,68,70,73; `Ctx.Regular.facts` 91,93; `Capture.bind_extend_assume` 136; `Capture.facts_extend` 161,162 |
| Context.lean | `Ty.assume` 152; `Ty.assume_eq_predicates` 156,157; `Ty.assume_ordinary` 161,162; `Ty.assume_eq_nil` 170,171,177,180,181; `Ty.assume_refined` 183,184,185; `Ctx.facts` 193 |
| ContextFacts.lean | `Ty.assume_shiftV` 17,18,19; `Ctx.mem_facts` 25; `Ctx.mem_facts_extend` 55,63,77,83,87; `Ctx.mem_facts_extendNone` 116,118 |
| ContextMap.lean | `Ctx.TypeMap` 11; `Ctx.TypeMap.of_map` 19; `Ctx.TypeMap.norm` 27; `Ctx.TypeMap.extend` 59,63,66,71 |
| ContextNormEq.lean | `Ctx.facts_map_norm` 96 |
| CoverageRefinement.lean | `valueMeaning_refine` 54,55 |
| DependentBeta.lean | `Builtins.ExternalAssumptions.received_facts` 318 |
| HeldValues.lean | `HasTypeVQ.checkedRequest_facts` 121,123 |
| Le.lean | `assumptions` 22; `Ty.LeQ.assume` 118,119,123,125,126,139,143,144,151,152,153,175 |
| MatchPaths.lean | `GuardBodyTy.of_true` 146 |
| MeaningTransport.lean | `assumptions_meaning` 124,125 |
| Narrowing.lean | `ContextMap.facts` 186 |
| NormalWellFormed.lean | `Ty.assume_of_wf` 6,7,9 |
| NormalizationLogic.lean | `Ty.entails_assume_iff_predicates` 24,25,26; `Ty.assume_of_norm_eq` 28,29,30,31,32 |
| OpenSubstitution.lean | `transport` 80 |
| RangeFormation.lean | `pred_sorted_ranges` 162 |
| RangeSubst.lean | `Eff.norm_rawMapRanges` 161,162,163; `sorted_mapRanges` 204 |
| ReferenceCalls.lean | `narrow_transport` 38 |
| Shift.lean | `Ctx.facts_shiftV` 38 |
| SubstTyping.lean | `TypedImages.transport` 67,68,69; `Transport.up_norm` 857,858 |
| SubstTypingObstruction.lean | `source_le` 329 |
| Transport.lean | `Ty.assume_bind` 75,76,78,79,80; `Transport.assumptions` 105; `Transport.extend` 115; `Transport.up` 187; `Transport.up_raw` 197; `Ty.LeQ.rawBind` 279,289 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes` 206,207,208; `TypeCtxMap.facts` 214 |
| TypeSubst.lean | `Ctx.facts_bindTypes` 24 |
| TypedFacts.lean | `HasTypeVQ.assume` 208,210,216,226,229,234,241,243; `HasTypeVQ.assume_optional` 249,251,257,267,270,275,284,286 |
| TypingShift.lean | `ShiftMap.facts` 72,73; `Ctx.mem_facts_hide` 251 |
| ValueFacts.lean | `(先頭)` 8; `HasTypeVQ.facts` 17,18; `HasTypeVQ.subtype_facts` 23,25; `HasTypeVQ.integer_facts` 77; `HasTypeVQ.list_facts` 104; `HasTypeVQ.field_facts` 153; `HasTypeVQ.list_element_facts` 162; `HasTypeVQ.field_facts_by_type` 237 |
| ValueReferences.lean | `Tel.References.norm` 187 |
| ValueRegularity.lean | `Tel.sorted_norm` 288 |

## `\bCaptureOk\b`

50ファイル・220行。

| ファイル（R/以下） | 宣言と一致行 |
|---|---|
| AtStateInputs.lean | `at_source` 21; `ClosureTy.at_inputs` 45; `AtCallAdmissible.closed_input` 68 |
| BuilderStateLeaves.lean | `close_builder_operation` 147 |
| CaptureApplicationAlgebra.lean | `CaptureOk.closed` 43,44; `CaptureOk.bindParams` 123,124,127,147 |
| CaptureReadBoundary.lean | `unread_capture_ok` 185,187; `argument_typed` 192; `primitive_reads_hidden_capture` 280,281 |
| CaptureRegularity.lean | `CaptureOk.contextRegular` 86; `capture_value_annotation` 282; `capture_comp_annotation` 288; `capture_failure_body_annotation` 369; `CaptureOk.continuation_annotation` 380,381; `CaptureOk.continuation_result_effect` 394,395; `capture_let_effect_annotations` 405; `capture_tel_annotation` 420; `capture_function_result_effect` 425; `HasFailureClause.capture_result_effect` 432; `e_handle_supply` 496; `split_fail_annotated` 653 |
| CaptureTransport.lean | `CaptureOk.normConts` 98,99; `capture_normConts_value_annotation` 128; `capture_normConts_comp_annotation` 135; `CaptureOk.hideBuilders_hideConts` 141,142,143; `capture_value_annotation_via_normConts` 173; `capture_comp_annotation_via_normConts` 180 |
| CapturedFacts.lean | `CaptureOk.evaluated_fact` 13; `CaptureOk.addEntailed` 22,23,26; `CaptureOk.addEvaluated` 41,42,45,46; `CaptureOk.close_entails` 49,50; `HasTypeTelArgsQ.captured_one` 60; `StateTyE.captured_beta_one` 84,112,113; `StateTy.captured_beta_one` 146 |
| CloseApplication.lean | `HasTypeTelArgsQ.close_typed` 28; `HasTypeCQ.close_app_aux` 48; `HasTypeCQ.close_method_aux` 137 |
| CloseTyping.lean | `close_dependent_lambda` 40; `close_lambda` 63; `CaptureOk.close_sat` 98,99; `close_value_aux` 117; `close_values_aux` 226; `close_each_aux` 245; `close_value_typed` 266; `close_values_typed` 276; `close_each_typed` 286 |
| ClosedCapture.lean | `CaptureOk.close_annotations` 66,67; `HasTypeVQ.close_ground` 76; `HasTypeVsQ.close_ground` 130; `HasTypeEachQ.close_ground` 139 |
| ClosureApply.lean | `TelBodyTy.capture_all` 12; `CaptureOk.mapReturn` 57,58,60; `ClosureTy.apply_all` 124 |
| ClosureCallInputs.lean | `HasTypeCQ.fun_apply_all` 115 |
| ClosureTyping.lean | `CaptureOk.substOk` 147; `CaptureOk.conditions` 152; `CaptureOk.transport` 157; `CaptureOk.wf` 275; `CaptureOk.declared` 278; `CaptureOk.wf_ordinary` 294; `CaptureOk.continuation_image_wf` 298,300; `ClosureTy.pure` 390; `ClosureTy.capture_resolved` 399; `ClosureTy.capture` 430 |
| ClosureViewTyping.lean | `ClosureViewTy` 106 |
| Context/Capture.lean | `CaptureOk.extend` 58,60,67; `CaptureOk.extendHidden` 132,133,137; `CaptureOk.extendCont` 198,205,209; `CaptureOk.extendTel` 283,287,301 |
| Context/Facts.lean | `CaptureOk.facts_extend` 169 |
| ContextTransport.lean | `CaptureOk.q_fixed` 183,184,186 |
| ControlLeafSelection.lean | `other_control_for_model` 81 |
| CoverageRefinement.lean | `CaptureOk.variable_coverage` 239,240 |
| DependentBeta.lean | `ClosureTy.dependent_one` 76; `CaptureOk.hideConts_any` 136,137; `ClosureTy.closure_one` 192,198,200 |
| ExternalStateLeaves.lean | `close_external` 15 |
| FunctionViewGeneral.lean | `CaptureOk.termBind_success` 20,21; `HasTypeVQ.captured_observation` 31 |
| HandlerContinuation.lean | `HandlerFrameTy` 13 |
| HandlerFailure.lean | `ContTy.fail_input` 26 |
| HandlerGeneral.lean | `capture_normal` 184,185; `operation_capture` 355,415; `close_resume_aux` 700; `close_escape_all` 1568 |
| HandlerStoreExamples.lean | `saved_typed` 192 |
| HandlerTelescope.lean | `capture_tel` 27,30 |
| HiddenCaptureBoundary.lean | `hidden_state_typed` 21,22 |
| IntervalConnectionExamples.lean | `view_observation_model` 386 |
| LegacyHeldTyping.lean | `held_lambda` 28 |
| LegacyStateTyping.lean | `legacy_pure_let` 55; `embedContTy` 224,258,281,292; `legacy_cont_closed` 357; `embedStateTyE` 467 |
| LocalInvariant.lean | `Closure.LocalRefs` 11; `Frame.LocalRefs` 46,51 |
| MatchPaths.lean | `ClosureTy.capture_resolved_closed` 87; `ClosureTy.open_zero` 357; `CaptureOk.addEvaluatedFacts` 466,467,469; `CaptureOk.paths_evaluate` 477,478; `HasTypeArmsQ.capture_plain` 499,504; `ClosureTy.match_source` 570 |
| MatchStateLeaves.lean | `CaptureOk.match_extend` 12,13,17; `CaptureOk.paths_wellFormed` 27,28; `CaptureOk.matched_facts` 44,45,50; `CaptureOk.excluded_facts` 60,61,67; `HasTypeArmsQ.capture_plain_success` 85,91; `HasTypeArmsQ.capture_guard_success` 216,222 |
| MethodClosure.lean | `HasTypeCQ.method_apply_all` 68,81 |
| NestedContinuation.lean | `CaptureOk.list_cont_empty` 67,68 |
| PathBasesLeaves.lean | `issue_source` 56 |
| PathConditions.lean | `CaptureOk.boolCond_evaluates` 66,67; `ClosureTy.branch` 80; `Comp.isIte_resolve` 101 |
| PatternBindingExamples.lean | `(先頭)` 4; `month_variable_coverage` 52 |
| PatternMatchAnnotations.lean | `annotations_aux` 31; `annotations_list_aux` 169; `PatTy.bindings_annotation` 200; `AltsTy.bindings_annotation` 209 |
| ReadLocalRefs.lean | `Val.LocalRefs` 28; `DependentClosureTy.localRefs` 266; `CaptureOk.localRefs` 270 |
| ReferencePreservation.lean | `ClosureTy.pure_return` 181; `pure_replace` 399 |
| ReferenceStore.lean | `CaptureOk.reference_write_snapshot` 192,194,197 |
| StateTyping.lean | `GuardBodyTy` 54; `ContTy` 84,93,104 |
| SuperClosure.lean | `CaptureOk.closed_arguments` 7,10,16; `HasTypeVQ.super_dictionary` 60 |
| TypeSubstContracts.lean | `S02_Capture` 78 |
| TypeSubstTyping.lean | `case_Capture_mk` 975,977; `case_Closure_mk` 981,985; `deriveCapture` 1391,1392,1394 |
| TypedCoverage.lean | `(先頭)` 4; `CaptureOk.typed_variable_coverage` 14,15 |
| Typing.lean | `CaptureOk` 390,400; `DependentClosureTy` 404; `ClosureTy` 506; `CaptureOk.empty` 536,537 |
| TypingShift.lean | `CaptureOk.store` 1043,1045; `DependentClosureTy.store` 1073; `ClosureTy.store` 1131 |

## `\b(simp|simpa|unfold|dsimp)\b[^\n]*(Ctx\.facts\b|Ty\.assume\b)`

16ファイル・25行。

| ファイル（R/以下） | 宣言と一致行 |
|---|---|
| Context/Facts.lean | `Ty.assume_wellFormed` 68 |
| Context.lean | `Ty.assume_eq_predicates` 157; `Ty.assume_ordinary` 162; `Ty.assume_eq_nil` 171 |
| ContextFacts.lean | `Ty.assume_shiftV` 19; `Ctx.mem_facts` 26; `Ctx.mem_facts_extendNone` 115,118 |
| ContextNormEq.lean | `Ctx.facts_map_norm` 92 |
| CoverageRefinement.lean | `CaptureOk.variable_coverage` 249 |
| HandlerCalls.lean | `ClosureTy.pure_operation` 267 |
| LazyPreservation.lean | `pure_ret` 236 |
| MatchStateExamples.lean | `reject_false_fact_to_tail` 180 |
| MeaningTransportObstruction.lean | `ordinary_supply_counterexample` 111 |
| OpenSubstitution.lean | `transport` 80 |
| RangeSubst.lean | `Eff.norm_rawMapRanges` 163; `Ctx.mapRanges` 185,193 |
| ReferenceCalls.lean | `ClosureTy.pure_primitive` 354 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes` 208 |
| TypedFacts.lean | `HasTypeVQ.assume` 216; `HasTypeVQ.assume_optional` 257 |
| TypedMeaning.lean | `typed_meaning_aux` 134,141 |
| TypedMeaningExamples.lean | `typed_entries` 25 |

## `facts|assume`

48ファイル・485行。

| ファイル（R/以下） | 宣言と一致行 |
|---|---|
| CaptureApplicationAlgebra.lean | `Capture.close_facts_apply_all` 175 |
| CaptureTransport.lean | `CaptureOk.normConts` 104,123,124; `HasTypeVQ.normConts` 168 |
| CapturedFacts.lean | `CaptureOk.close_entails` 51 |
| ClosureTyping.lean | `CaptureOk.conditions` 153; `HasTypeCQ.builderBody_image` 573 |
| Context/Capture.lean | `(先頭)` 7; `CaptureOk.extend` 62; `CaptureOk.extendHidden` 190; `CaptureOk.extendCont` 275 |
| Context/Facts.lean | `assume_subset` 21,22,24; `refined_map` 30; `Ty.assume_wellFormed` 66,67,68,70,73; `Ctx.Regular.facts` 85,86,88,91,93; `Ctx.facts_entails_extend` 113,114,119; `Ctx.facts_entails_extendNone` 122,123,128; `Capture.bind_extend_assume` 136; `Capture.facts_extend` 153,154,156,160,161,162; `CaptureOk.facts_extend` 169,171,174 |
| Context.lean | `Ty.assume` 152; `Ty.assume_eq_predicates` 156,157; `Ty.assume_ordinary` 161,162; `Ty.assume_eq_nil` 170,171,177,180,181; `Ty.assume_refined` 183,184,185; `Ctx.facts` 189,193 |
| ContextFacts.lean | `Ty.assume_shiftV` 17,18,19; `Ctx.mem_facts` 24,25,26; `Ctx.mem_facts_extend` 54,55,58,63,77,79,82,83,84,85,87; `Ctx.mem_facts_extendNone` 112,113,114,115,116,117,118 |
| ContextMap.lean | `Ctx.TypeMap` 11; `Ctx.TypeMap.of_map` 19; `Ctx.TypeMap.norm` 27; `Ctx.TypeMap.facts` 42,43,45; `Ctx.TypeMap.transport` 54; `Ctx.TypeMap.extend` 59,63,66,71 |
| ContextNormEq.lean | `Ctx.facts_map_norm` 91,92,96; `Ctx.NormEq.facts` 98,99; `Ctx.NormEq.comp` 175; `Ctx.NormEq.lambda` 209 |
| CoverageRefinement.lean | `valueMeaning_refine` 42,54,55,58; `HasTypeVQ.sub_refine_representative` 67,70; `HasTypeVQ.nonempty_from_entails` 226; `CaptureOk.variable_coverage` 249 |
| DependentBeta.lean | `CaptureOk.hideConts_any` 169; `Builtins.ExternalAssumptions.received_facts` 310,318,320 |
| HandlerCalls.lean | `ClosureTy.pure_operation` 267 |
| HandlerGeneral.lean | `capture_normal` 189,229,230 |
| HeldValues.lean | `HasTypeVQ.checkedRequest_facts` 117,121,123 |
| LazyPreservation.lean | `pure_ret` 236 |
| Le.lean | `assumptions` 22; `Ty.LeQ.assume` 118,119,123,125,126,139,143,144,151,152,153,175 |
| MatchPaths.lean | `HasTypeArmsQ.weaken_conditions` 15; `GuardBodyTy.of_true` 145,146 |
| MatchStateExamples.lean | `reject_false_fact_to_tail` 180 |
| MatchStateLeaves.lean | `CaptureOk.matched_facts` 44; `CaptureOk.excluded_facts` 60; `HasTypeArmsQ.capture_plain_success` 101,105; `HasTypeArmsQ.capture_guard_success` 237,244 |
| MeaningTransport.lean | `MOrder` 14; `fields_meaning` 29,41; `data_shape_meaning` 46,56; `each_meaning` 76,82,83; `list_shape_meaning` 86,99; `assumptions_meaning` 115,124,125,128; `order_trans` 133,134; `order_refine` 140,141; `order_data` 147,150; `order_step` 158,163,166,167,168,169,170,171,173,174,176,177; `meaning_order_sound` 193,195; `valueMeaning_field_mono` 200,202; `valueMeaning_sub` 210,212 |
| MeaningTransportObstruction.lean | `ordinary_supply_counterexample` 105,111 |
| Narrowing.lean | `ContextMap.facts` 182,183,184,185,186; `ContextMap.transport` 190,199; `ContextMap.conditions_params` 280,281; `ContextMap.conditions_many` 375,376,382; `ContextMap.conditions_clause` 399,400,402; `ContextMap.conditions_failure` 420,421,423; `context_value` 435; `context_values` 491; `context_each` 499; `context_comp` 507; `context_arms` 575; `context_clauses` 607; `context_failure` 617; `context_telArgs` 627; `context_telBody` 639; `context_at_call` 651 |
| NarrowingObstruction.lean | `context_facts` 49; `facts_preserved` 51,53 |
| NormalWellFormed.lean | `Ty.assume_of_wf` 6,7,9 |
| NormalizationLogic.lean | `Ty.entails_assume_iff_predicates` 24,25,26; `Ty.assume_of_norm_eq` 28,29,30,31,32 |
| OpenSubstitution.lean | `context_facts` 44,45; `target_path_from_facts` 50,51; `target_conditions_from_facts` 53,57; `transport` 80,83; `all_open_covers` 107; `source_introduce` 112,114; `introduce_bind_shape` 127 |
| PathConditions.lean | `Ty.LeQ.weaken_conditions` 11 |
| PathFacts.lean | `Entails.extend_conditions` 225,226 |
| RangeFormation.lean | `pred_sorted_ranges` 162 |
| RangeSubst.lean | `Eff.norm_rawMapRanges` 161,162,163; `Ctx.mapRanges` 183,184,185,191,192,193; `sorted_mapRanges` 204 |
| ReferenceCalls.lean | `narrow_transport` 37,38,41,44,46; `ClosureTy.pure_primitive` 354 |
| ReferenceStore.lean | `CaptureOk.reference_write_snapshot` 194 |
| Shift.lean | `Ctx.facts_shiftV` 33,34,35,36,38,43; `Transport.shiftV` 58 |
| SubstTyping.lean | `TypedImages.transport` 61,66,67,68,69; `SubstOk.transport` 90; `TypedImages.conditions_params` 149,151; `SubstOk.up` 523; `SubstOk.upN` 532,546,550; `SubstOk.clause` 757; `shifted_values_facts` 820,821,822; `Transport.up_norm` 857,858; `SubstOk.handler_conditions` 896,898,903,909; `SubstOk.failure_conditions` 927,928,930,932; `subst_value` 1006; `subst_values` 1134; `subst_each` 1142; `subst_comp` 1151,1163; `subst_arms` 1363; `subst_clauses` 1418; `subst_failure` 1437; `subst_telArgs` 1454; `subst_telBody` 1470,1482; `subst_at_call` 1492; `HasTypeVQ.subst` 1523; `HasTypeVsQ.subst` 1533; `HasTypeEachQ.subst` 1543; `HasTypeCQ.subst` 1553; `HasTypeTelArgsQ.subst` 1562; `HasTypeArmsQ.subst` 1572; `TelBodyTy.subst` 1582; `HasTypeClausesQ.subst` 1593; `HasFailureClause.subst` 1603; `SubstOk.transport_extendNone` 1611; `HasTypeVQ.subst_under_none` 1622,1627; `HasTypeVsQ.subst_under_none` 1634,1639; `HasTypeEachQ.subst_under_none` 1646,1651; `HasTypeCQ.subst_under_none` 1657,1666; `HasTypeTelArgsQ.subst_under_none` 1673,1679; `HasTypeArmsQ.subst_under_none` 1685,1693; `HasTypeClausesQ.subst_under_none` 1700,1708; `HasFailureClause.subst_under_none` 1715,1722 |
| SubstTypingObstruction.lean | `context_facts` 109,110; `transport` 127,134; `source_le` 175,328,329; `conditions_image` 228,230,232; `swap_not_canonical` 277 |
| Transport.lean | `Ty.assume_bind` 75,76,78,79,80; `Transport` 88; `Transport.assumptions` 105,108; `Transport.extend` 115,162,163,169,174,175,178,181; `Transport.up` 187; `Transport.up_raw` 197; `Transport.extendNone` 238,239,245,250,252,255; `Ty.LeQ.rawBind` 279,289 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes` 206,207,208; `TypeCtxMap.facts` 212,213,214; `TypeCtxMap.transport` 223; `TypeCtxMap.entails` 258,261 |
| TypeSubst.lean | `Ctx.facts_bindTypes` 18,19,20,21,24; `Transport.types` 45 |
| TypeSubstTyping.lean | `case_V_Refine` 416,423; `case_Capture_mk` 974 |
| TypedFacts.lean | `HasTypeVQ.assume` 208,210,214,216,226,229,234,241,243; `HasTypeVQ.assume_optional` 249,251,255,257,267,270,275,284,286 |
| TypedMeaning.lean | `typed_meaning_aux` 134,141 |
| TypedMeaningExamples.lean | `typed_entries` 25 |
| Typing.lean | `Entails.conditions_cons` 133,134,135; `HasTypeVQ` 250; `CaptureOk` 399; `HasTypeVQ.refine_integer` 523 |
| TypingShift.lean | `ShiftMap.facts` 68,69,70,71,72,73; `ShiftMap.transport` 78,83; `Entails.under_none` 174,175,180; `Entails.under_params` 218,219,224; `ShiftMap.conditions_params` 228,230; `Ctx.mem_facts_hide` 244,247,248,250,251; `Entails.hideConts` 253,254,258; `Transport.entails` 262,266; `FullShiftMap.conditions_many` 493,495,498,503; `FullShiftMap.conditions_clause` 524,526,529; `FullShiftMap.conditions_failure` 547,548,550; `HasTypeVQ.shift_values` 586; `HasTypeVsQ.shift_values` 729; `HasTypeEachQ.shift_values` 741; `HasTypeCQ.shift_values` 754; `HasTypeArmsQ.shift_values` 933; `HasTypeClausesQ.shift_values` 976; `HasFailureClause.shift_values` 994; `HasTypeTelArgsQ.shift_values` 1011; `TelBodyTy.shift_values` 1026; `AtCallAdmissible.shift_values` 1097; `HasTypeVQ.weaken_conditions` 1145; `HasTypeCQ.weaken_conditions` 1155; `ImageOk.weaken_conditions` 1166 |
| ValueFacts.lean | `(先頭)` 8; `HasTypeVQ.facts` 15,17,18; `HasTypeVQ.subtype_facts` 20,23,25,30; `HasTypeVQ.integer_facts` 74,77,78; `HasTypeVQ.list_facts` 100,104,107; `HasTypeVQ.field_facts` 149,153,158; `HasTypeVQ.list_element_facts` 160,162,163,166; `HasTypeVQ.field_facts_by_type` 231,237,242 |
| ValueReferences.lean | `Tel.References.norm` 187 |
| ValueRegularity.lean | `Tel.sorted_norm` 288 |

