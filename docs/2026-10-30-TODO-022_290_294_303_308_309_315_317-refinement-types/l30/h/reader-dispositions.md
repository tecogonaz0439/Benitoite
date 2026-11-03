# 読者の処分と事実の供給元

元の在庫は[群Aの在庫](../a/inventory.md)である。字句の出現行を宣言の意味上の依存と数えない。以下の元表の宣言名は、群Aの検索が行の直前の宣言へ対応させた名前である。変更したファイルの全宣言を一律に変更済みと扱わず、本番の変更は source-changes.json と完全署名を参照する。保持の判定は、型域を含む新しい判断の下での既定ビルドを根拠とする。

## 直接構成する12宣言

| ファイル・宣言 | 新しい事実の供給元と処分 |
|---|---|
| Typing: CaptureOk.empty | 空文脈の事実は空。保持 |
| Context/Capture: CaptureOk.extend | CaptureOk.facts_extend → Capture.facts_extend → 型付き像の HasTypeVQ.assume_optional と Ty.assume_bind。V_Const の型域を共通供給元で追加。構成子の欄・本文は保持 |
| Context/Capture: CaptureOk.extendHidden | None は新しい事実を持たず、mem_facts_extendNone と bind_extend_lift で既存の事実を移す。保持 |
| Context/Capture: CaptureOk.extendCont | cont の assume は空。外側の事実を lift する。保持 |
| ContextTransport: CaptureOk.q_fixed | 同じΓ・Φ・capの事実の証拠をそのまま渡す。保持 |
| TypeSubstTyping: case_Capture_mk | ΦとΓの事実の既存の欄をそのまま渡す。型置換の相互76場合の捕捉成分。保持 |
| CaptureTransport: CaptureOk.normConts | Ctx.NormEq.facts が、carrierFacts_norm を含む事実列の等号を供給。保持 |
| CapturedFacts: CaptureOk.addEntailed | Γ.facts の既存証拠を保存し、Φに明示した新しい述語だけを加える。保持 |
| ClosureApply: CaptureOk.mapReturn | Rだけを写し、Γ.factsの証拠を保存する。保持 |
| DependentBeta: CaptureOk.hideConts_any | mem_facts_hideで通常値の事実の包含を得る。contの事実を導く前提は足さない。保持 |
| HandlerGeneral: capture_normal | norm_context_eq の facts の等号で元の証拠を再使用する。保持 |
| TypingShift: CaptureOk.store | ストアだけを写す。Γ・Φ・capの事実は同じ。保持 |

直接12構成のソース本文は開始版と同じである。共通の型付き供給、正規化と事実の移送を直したことで、新しいfactsの欄を満たす。前提を追加した構成は0。

## 間接構成・供給の25宣言

次の25宣言を供給鎖として個別に照合した。これを、字句の出現がある全宣言の数と混同しない。

| ファイル・宣言 | 構成・供給先と処分 |
|---|---|
| Context/Capture: CaptureOk.extendTel | 各paramでextend、contはextendCont。本文と入力を保持し、新判断の既定ビルドで確認 |
| CaptureApplicationAlgebra: CaptureOk.bindParams | 依存引数の列をextendで追加。本文と入力を保持し、新判断の既定ビルドで確認 |
| CapturedFacts: CaptureOk.addEvaluated | 評価の真からaddEntailed。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchPaths: CaptureOk.addEvaluatedFacts | 評価した経路条件をaddEvaluatedで追加。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchPaths: CaptureOk.paths_evaluate | 追加する経路条件の真を供給。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchStateLeaves: CaptureOk.match_extend | パターン束縛をextendTelで追加。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchStateLeaves: CaptureOk.matched_facts | 成功した経路をaddEvaluatedFactsへ。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchStateLeaves: CaptureOk.excluded_facts | 失敗した経路をaddEvaluatedFactsへ。本文と入力を保持し、新判断の既定ビルドで確認 |
| CaptureTransport: CaptureOk.hideBuilders_hideConts | ストアとcontの非観測を既存の移送で保つ。本文と入力を保持し、新判断の既定ビルドで確認 |
| SuperClosure: CaptureOk.closed_arguments | 閉じた型付き実引数をbindParamsへ。本文と入力を保持し、新判断の既定ビルドで確認 |
| TypeSubstTyping: deriveCapture | case_Capture_mkを相互導出へ接続。本文と入力を保持し、新判断の既定ビルドで確認 |
| CaptureReadBoundary: unread_capture_ok | 空の捕捉を使う境界。本文と入力を保持し、新判断の既定ビルドで確認 |
| ReferenceStore: CaptureOk.reference_write_snapshot | 同じ事実をストアの移送で保存。本文と入力を保持し、新判断の既定ビルドで確認 |
| HandlerTelescope: capture_tel | 操作署名の実引数からextendTel。本文と入力を保持し、新判断の既定ビルドで確認 |
| CaptureReadBoundary: primitive_reads_hidden_capture | 非読取りの像をunread_capture_okへ。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchPaths: HasTypeArmsQ.capture_plain | 腕の束縛と経路の事実を追加。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchStateLeaves: HasTypeArmsQ.capture_plain_success | 通常の腕の成功に同じ捕捉を供給。本文と入力を保持し、新判断の既定ビルドで確認 |
| MatchStateLeaves: HasTypeArmsQ.capture_guard_success | guardが成功した条件だけを供給。本文と入力を保持し、新判断の既定ビルドで確認 |
| LegacyStateTyping: embedContTy | 旧継続の保持値と捕捉を埋め込む。本文と入力を保持し、新判断の既定ビルドで確認 |
| LegacyStateTyping: embedStateTyE | 旧状態の保持値と捕捉を埋め込む。本文と入力を保持し、新判断の既定ビルドで確認 |
| LegacyHeldTyping: held_lambda | 旧保持lambdaを空の捕捉で閉じる。本文と入力を保持し、新判断の既定ビルドで確認 |
| HandlerStoreExamples: saved_typed | 保存した継続の具体例。本文と入力を保持し、新判断の既定ビルドで確認 |
| NestedContinuation: CaptureOk.list_cont_empty | 継続を含む保持Listの既存境界。本文と入力を保持し、新判断の既定ビルドで確認 |
| HiddenCaptureBoundary: hidden_state_typed | Noneを持つ状態の既存境界。本文と入力を保持し、新判断の既定ビルドで確認 |
| LogicKernelExamples: captured_integer8 | 実際の二つのInteger8の四事実をextendで供給。本文と入力を保持し、新判断の既定ビルドで確認 |

新規の captured_decimal は同じ具体のP・BでDecimalの事実をextendへ供給する。typed_integer8_upper と closed_integer8_upper も、独立の意味の仮定を受けない。

## 最初の16読者（再開1で補題名を統合）

| 番号 | 本来の入口 | 切替後の処分 |
|---:|---|---|
| 1 | Ty.assume_norm | carrierFacts_normを追加。互換入口は同じ証明を読む |
| 2 | Ty.assume_refined | carrierと明示述語を分け、appendの結合を合わせる |
| 3 | Ty.assume_shiftV | 自己0を保つcarrierFacts_shiftVを読む。証明は一つ |
| 4 | Ctx.mem_facts | 番号とopenを保持。新入口の等号はS01の向き |
| 5 | Ctx.mem_facts_extend | 型域と外側の事実を分けて供給。証明は一つ |
| 6 | Ctx.mem_facts_extendNone | unitのcarrierも空であることを明示 |
| 7 | Ty.assume_bind | carrierFacts_bindとpredicates_rawBindの包含を合成。証明は一つ |
| 8 | Transport.assumptions | 既存Transportのfactsから一般の四置換補題へ供給 |
| 9 | Ty.assume_of_norm_eq | normの事実列の等号を使用 |
| 10 | Ctx.facts_map_norm | carrierFacts_normを含むassume_norm。証明は一つ |
| 11 | Ctx.NormEq.facts | 同じ正規形の文脈から事実列の等号。証明は一つ |
| 12 | Ty.LeQ.assume | 既存四族22規則を保ち、型域と明示述語を読む。一つの部分型の帰納 |
| 13 | Ty.assume_of_wf | 結論をcarrierFacts ++ refinementPredicatesへ変更 |
| 14 | Ty.entails_assume_iff | carrierFactsと明示述語の二条件へ変更 |
| 15 | Ctx.TypeMap.norm | ソース変更不要。assume_normにより新factsへ追随。移植実績には加算しない |
| 16 | Ctx.TypeMap.facts | ソース変更不要。lookupの事実包含とmem_factsの契約で追随。移植実績には加算しない |

14読者の補助と供給を変更し、2読者は既存の一般の契約を保持した。補助ができた時点と呼び手の切替を区別し、並置中の既定ビルドと切替後の既定ビルドを別に記録する。

## ValueMeaningの9ファイル

| ファイル | 処分 |
|---|---|
| ValueMeaning | mkに第三条件、norm_iffでcarrierFacts_norm、scopedの空の列、ValueMeaning.assumeで型域と明示述語を別に供給 |
| ValueMeaningInhabits | mkの第三条件を受け取る。所属の判断と前提は保持 |
| PatternNormalForm | mkの直接読者ではない。Inhabitsと正規形の契約を保持し、ソース変更不要 |
| CoverageRefinement | refined_iffが型域の真を保存。refineの事実供給はValueMeaning.assume。公開署名は保持 |
| MeaningTransport | assumptions_meaningが新事実を供給。再構成に型域の空列を加え、辞書式帰納とvalueMeaning_subの署名を保持 |
| MeaningTransportObstruction | contとdataの空列を供給。Ordinaryを無条件に得られない反例は保持 |
| TypedCoverage | 型付きの閉じた意味からの供給を保持。ソース変更不要 |
| TypedMeaning | NumericRepresentedを定数の意味へ供給。V_ConstはConstOK.representedを使用。全33場合と公開入口の量化・結論を保持 |
| TypedMeaningExamples | Month・空篩・非空List・unknown・依存捕捉を同じ導出で維持。ソース変更不要 |

## 定義の展開16ファイルと全字句在庫

各表の行の宣言名は元の在庫のままである。「本文変更あり」はファイル全体の状態であり、その行の全宣言を変更したという意味ではない。主要な変更は上の表と次節で特定する。

## `assume`

| ファイル（R/以下） | 元表の宣言と一致行 | 処分 |
|---|---|---|
| Context/Facts.lean | `assume_subset` 21,22,24; `refined_map` 30; `Ty.assume_wellFormed` 66,67,68,70,73; `Ctx.Regular.facts` 91,93; `Capture.bind_extend_assume` 136; `Capture.facts_extend` 161,162 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Context.lean | `Ty.assume` 152; `Ty.assume_eq_predicates` 156,157; `Ty.assume_ordinary` 161,162; `Ty.assume_eq_nil` 170,171,177,180,181; `Ty.assume_refined` 183,184,185; `Ctx.facts` 193 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextFacts.lean | `Ty.assume_shiftV` 17,18,19; `Ctx.mem_facts` 25; `Ctx.mem_facts_extend` 55,63,77,83,87; `Ctx.mem_facts_extendNone` 116,118 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextMap.lean | `Ctx.TypeMap` 11; `Ctx.TypeMap.of_map` 19; `Ctx.TypeMap.norm` 27; `Ctx.TypeMap.extend` 59,63,66,71 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ContextNormEq.lean | `Ctx.facts_map_norm` 96 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| CoverageRefinement.lean | `valueMeaning_refine` 54,55 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| DependentBeta.lean | `Builtins.ExternalAssumptions.received_facts` 318 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HeldValues.lean | `HasTypeVQ.checkedRequest_facts` 121,123 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Le.lean | `assumptions` 22; `Ty.LeQ.assume` 118,119,123,125,126,139,143,144,151,152,153,175 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| MatchPaths.lean | `GuardBodyTy.of_true` 146 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MeaningTransport.lean | `assumptions_meaning` 124,125 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Narrowing.lean | `ContextMap.facts` 186 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| NormalWellFormed.lean | `Ty.assume_of_wf` 6,7,9 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| NormalizationLogic.lean | `Ty.entails_assume_iff_predicates` 24,25,26; `Ty.assume_of_norm_eq` 28,29,30,31,32 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| OpenSubstitution.lean | `transport` 80 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| RangeFormation.lean | `pred_sorted_ranges` 162 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| RangeSubst.lean | `Eff.norm_rawMapRanges` 161,162,163; `sorted_mapRanges` 204 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ReferenceCalls.lean | `narrow_transport` 38 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Shift.lean | `Ctx.facts_shiftV` 38 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| SubstTyping.lean | `TypedImages.transport` 67,68,69; `Transport.up_norm` 857,858 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| SubstTypingObstruction.lean | `source_le` 329 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Transport.lean | `Ty.assume_bind` 75,76,78,79,80; `Transport.assumptions` 105; `Transport.extend` 115; `Transport.up` 187; `Transport.up_raw` 197; `Ty.LeQ.rawBind` 279,289 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes` 206,207,208; `TypeCtxMap.facts` 214 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypeSubst.lean | `Ctx.facts_bindTypes` 24 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypedFacts.lean | `HasTypeVQ.assume` 208,210,216,226,229,234,241,243; `HasTypeVQ.assume_optional` 249,251,257,267,270,275,284,286 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypingShift.lean | `ShiftMap.facts` 72,73; `Ctx.mem_facts_hide` 251 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ValueFacts.lean | `(先頭)` 8; `HasTypeVQ.facts` 17,18; `HasTypeVQ.subtype_facts` 23,25; `HasTypeVQ.integer_facts` 77; `HasTypeVQ.list_facts` 104; `HasTypeVQ.field_facts` 153; `HasTypeVQ.list_element_facts` 162; `HasTypeVQ.field_facts_by_type` 237 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ValueReferences.lean | `Tel.References.norm` 187 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ValueRegularity.lean | `Tel.sorted_norm` 288 | 本文保持。新しい事実の契約で既定ビルドを確認 |

## `\bCaptureOk\b`

| ファイル（R/以下） | 元表の宣言と一致行 | 処分 |
|---|---|---|
| AtStateInputs.lean | `at_source` 21; `ClosureTy.at_inputs` 45; `AtCallAdmissible.closed_input` 68 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| BuilderStateLeaves.lean | `close_builder_operation` 147 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CaptureApplicationAlgebra.lean | `CaptureOk.closed` 43,44; `CaptureOk.bindParams` 123,124,127,147 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CaptureReadBoundary.lean | `unread_capture_ok` 185,187; `argument_typed` 192; `primitive_reads_hidden_capture` 280,281 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CaptureRegularity.lean | `CaptureOk.contextRegular` 86; `capture_value_annotation` 282; `capture_comp_annotation` 288; `capture_failure_body_annotation` 369; `CaptureOk.continuation_annotation` 380,381; `CaptureOk.continuation_result_effect` 394,395; `capture_let_effect_annotations` 405; `capture_tel_annotation` 420; `capture_function_result_effect` 425; `HasFailureClause.capture_result_effect` 432; `e_handle_supply` 496; `split_fail_annotated` 653 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CaptureTransport.lean | `CaptureOk.normConts` 98,99; `capture_normConts_value_annotation` 128; `capture_normConts_comp_annotation` 135; `CaptureOk.hideBuilders_hideConts` 141,142,143; `capture_value_annotation_via_normConts` 173; `capture_comp_annotation_via_normConts` 180 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CapturedFacts.lean | `CaptureOk.evaluated_fact` 13; `CaptureOk.addEntailed` 22,23,26; `CaptureOk.addEvaluated` 41,42,45,46; `CaptureOk.close_entails` 49,50; `HasTypeTelArgsQ.captured_one` 60; `StateTyE.captured_beta_one` 84,112,113; `StateTy.captured_beta_one` 146 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CloseApplication.lean | `HasTypeTelArgsQ.close_typed` 28; `HasTypeCQ.close_app_aux` 48; `HasTypeCQ.close_method_aux` 137 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CloseTyping.lean | `close_dependent_lambda` 40; `close_lambda` 63; `CaptureOk.close_sat` 98,99; `close_value_aux` 117; `close_values_aux` 226; `close_each_aux` 245; `close_value_typed` 266; `close_values_typed` 276; `close_each_typed` 286 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ClosedCapture.lean | `CaptureOk.close_annotations` 66,67; `HasTypeVQ.close_ground` 76; `HasTypeVsQ.close_ground` 130; `HasTypeEachQ.close_ground` 139 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ClosureApply.lean | `TelBodyTy.capture_all` 12; `CaptureOk.mapReturn` 57,58,60; `ClosureTy.apply_all` 124 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ClosureCallInputs.lean | `HasTypeCQ.fun_apply_all` 115 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ClosureTyping.lean | `CaptureOk.substOk` 147; `CaptureOk.conditions` 152; `CaptureOk.transport` 157; `CaptureOk.wf` 275; `CaptureOk.declared` 278; `CaptureOk.wf_ordinary` 294; `CaptureOk.continuation_image_wf` 298,300; `ClosureTy.pure` 390; `ClosureTy.capture_resolved` 399; `ClosureTy.capture` 430 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ClosureViewTyping.lean | `ClosureViewTy` 106 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Context/Capture.lean | `CaptureOk.extend` 58,60,67; `CaptureOk.extendHidden` 132,133,137; `CaptureOk.extendCont` 198,205,209; `CaptureOk.extendTel` 283,287,301 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Context/Facts.lean | `CaptureOk.facts_extend` 169 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextTransport.lean | `CaptureOk.q_fixed` 183,184,186 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ControlLeafSelection.lean | `other_control_for_model` 81 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CoverageRefinement.lean | `CaptureOk.variable_coverage` 239,240 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| DependentBeta.lean | `ClosureTy.dependent_one` 76; `CaptureOk.hideConts_any` 136,137; `ClosureTy.closure_one` 192,198,200 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ExternalStateLeaves.lean | `close_external` 15 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| FunctionViewGeneral.lean | `CaptureOk.termBind_success` 20,21; `HasTypeVQ.captured_observation` 31 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerContinuation.lean | `HandlerFrameTy` 13 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerFailure.lean | `ContTy.fail_input` 26 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerGeneral.lean | `capture_normal` 184,185; `operation_capture` 355,415; `close_resume_aux` 700; `close_escape_all` 1568 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerStoreExamples.lean | `saved_typed` 192 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerTelescope.lean | `capture_tel` 27,30 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HiddenCaptureBoundary.lean | `hidden_state_typed` 21,22 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| IntervalConnectionExamples.lean | `view_observation_model` 386 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| LegacyHeldTyping.lean | `held_lambda` 28 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| LegacyStateTyping.lean | `legacy_pure_let` 55; `embedContTy` 224,258,281,292; `legacy_cont_closed` 357; `embedStateTyE` 467 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| LocalInvariant.lean | `Closure.LocalRefs` 11; `Frame.LocalRefs` 46,51 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MatchPaths.lean | `ClosureTy.capture_resolved_closed` 87; `ClosureTy.open_zero` 357; `CaptureOk.addEvaluatedFacts` 466,467,469; `CaptureOk.paths_evaluate` 477,478; `HasTypeArmsQ.capture_plain` 499,504; `ClosureTy.match_source` 570 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MatchStateLeaves.lean | `CaptureOk.match_extend` 12,13,17; `CaptureOk.paths_wellFormed` 27,28; `CaptureOk.matched_facts` 44,45,50; `CaptureOk.excluded_facts` 60,61,67; `HasTypeArmsQ.capture_plain_success` 85,91; `HasTypeArmsQ.capture_guard_success` 216,222 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MethodClosure.lean | `HasTypeCQ.method_apply_all` 68,81 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| NestedContinuation.lean | `CaptureOk.list_cont_empty` 67,68 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| PathBasesLeaves.lean | `issue_source` 56 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| PathConditions.lean | `CaptureOk.boolCond_evaluates` 66,67; `ClosureTy.branch` 80; `Comp.isIte_resolve` 101 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| PatternBindingExamples.lean | `(先頭)` 4; `month_variable_coverage` 52 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| PatternMatchAnnotations.lean | `annotations_aux` 31; `annotations_list_aux` 169; `PatTy.bindings_annotation` 200; `AltsTy.bindings_annotation` 209 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ReadLocalRefs.lean | `Val.LocalRefs` 28; `DependentClosureTy.localRefs` 266; `CaptureOk.localRefs` 270 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ReferencePreservation.lean | `ClosureTy.pure_return` 181; `pure_replace` 399 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ReferenceStore.lean | `CaptureOk.reference_write_snapshot` 192,194,197 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| StateTyping.lean | `GuardBodyTy` 54; `ContTy` 84,93,104 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| SuperClosure.lean | `CaptureOk.closed_arguments` 7,10,16; `HasTypeVQ.super_dictionary` 60 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypeSubstContracts.lean | `S02_Capture` 78 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypeSubstTyping.lean | `case_Capture_mk` 975,977; `case_Closure_mk` 981,985; `deriveCapture` 1391,1392,1394 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypedCoverage.lean | `(先頭)` 4; `CaptureOk.typed_variable_coverage` 14,15 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Typing.lean | `CaptureOk` 390,400; `DependentClosureTy` 404; `ClosureTy` 506; `CaptureOk.empty` 536,537 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypingShift.lean | `CaptureOk.store` 1043,1045; `DependentClosureTy.store` 1073; `ClosureTy.store` 1131 | 本文保持。新しい事実の契約で既定ビルドを確認 |

## `\b(simp|simpa|unfold|dsimp)\b[^\n]*(Ctx\.facts\b|Ty\.assume\b)`

| ファイル（R/以下） | 元表の宣言と一致行 | 処分 |
|---|---|---|
| Context/Facts.lean | `Ty.assume_wellFormed` 68 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Context.lean | `Ty.assume_eq_predicates` 157; `Ty.assume_ordinary` 162; `Ty.assume_eq_nil` 171 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextFacts.lean | `Ty.assume_shiftV` 19; `Ctx.mem_facts` 26; `Ctx.mem_facts_extendNone` 115,118 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextNormEq.lean | `Ctx.facts_map_norm` 92 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| CoverageRefinement.lean | `CaptureOk.variable_coverage` 249 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| HandlerCalls.lean | `ClosureTy.pure_operation` 267 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| LazyPreservation.lean | `pure_ret` 236 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MatchStateExamples.lean | `reject_false_fact_to_tail` 180 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MeaningTransportObstruction.lean | `ordinary_supply_counterexample` 111 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| OpenSubstitution.lean | `transport` 80 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| RangeSubst.lean | `Eff.norm_rawMapRanges` 163; `Ctx.mapRanges` 185,193 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ReferenceCalls.lean | `ClosureTy.pure_primitive` 354 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes` 208 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypedFacts.lean | `HasTypeVQ.assume` 216; `HasTypeVQ.assume_optional` 257 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypedMeaning.lean | `typed_meaning_aux` 134,141 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypedMeaningExamples.lean | `typed_entries` 25 | 本文保持。新しい事実の契約で既定ビルドを確認 |

## `facts|assume`

| ファイル（R/以下） | 元表の宣言と一致行 | 処分 |
|---|---|---|
| CaptureApplicationAlgebra.lean | `Capture.close_facts_apply_all` 175 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CaptureTransport.lean | `CaptureOk.normConts` 104,123,124; `HasTypeVQ.normConts` 168 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| CapturedFacts.lean | `CaptureOk.close_entails` 51 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ClosureTyping.lean | `CaptureOk.conditions` 153; `HasTypeCQ.builderBody_image` 573 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Context/Capture.lean | `(先頭)` 7; `CaptureOk.extend` 62; `CaptureOk.extendHidden` 190; `CaptureOk.extendCont` 275 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Context/Facts.lean | `assume_subset` 21,22,24; `refined_map` 30; `Ty.assume_wellFormed` 66,67,68,70,73; `Ctx.Regular.facts` 85,86,88,91,93; `Ctx.facts_entails_extend` 113,114,119; `Ctx.facts_entails_extendNone` 122,123,128; `Capture.bind_extend_assume` 136; `Capture.facts_extend` 153,154,156,160,161,162; `CaptureOk.facts_extend` 169,171,174 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Context.lean | `Ty.assume` 152; `Ty.assume_eq_predicates` 156,157; `Ty.assume_ordinary` 161,162; `Ty.assume_eq_nil` 170,171,177,180,181; `Ty.assume_refined` 183,184,185; `Ctx.facts` 189,193 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextFacts.lean | `Ty.assume_shiftV` 17,18,19; `Ctx.mem_facts` 24,25,26; `Ctx.mem_facts_extend` 54,55,58,63,77,79,82,83,84,85,87; `Ctx.mem_facts_extendNone` 112,113,114,115,116,117,118 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ContextMap.lean | `Ctx.TypeMap` 11; `Ctx.TypeMap.of_map` 19; `Ctx.TypeMap.norm` 27; `Ctx.TypeMap.facts` 42,43,45; `Ctx.TypeMap.transport` 54; `Ctx.TypeMap.extend` 59,63,66,71 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ContextNormEq.lean | `Ctx.facts_map_norm` 91,92,96; `Ctx.NormEq.facts` 98,99; `Ctx.NormEq.comp` 175; `Ctx.NormEq.lambda` 209 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| CoverageRefinement.lean | `valueMeaning_refine` 42,54,55,58; `HasTypeVQ.sub_refine_representative` 67,70; `HasTypeVQ.nonempty_from_entails` 226; `CaptureOk.variable_coverage` 249 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| DependentBeta.lean | `CaptureOk.hideConts_any` 169; `Builtins.ExternalAssumptions.received_facts` 310,318,320 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerCalls.lean | `ClosureTy.pure_operation` 267 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HandlerGeneral.lean | `capture_normal` 189,229,230 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| HeldValues.lean | `HasTypeVQ.checkedRequest_facts` 117,121,123 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| LazyPreservation.lean | `pure_ret` 236 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Le.lean | `assumptions` 22; `Ty.LeQ.assume` 118,119,123,125,126,139,143,144,151,152,153,175 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| MatchPaths.lean | `HasTypeArmsQ.weaken_conditions` 15; `GuardBodyTy.of_true` 145,146 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MatchStateExamples.lean | `reject_false_fact_to_tail` 180 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MatchStateLeaves.lean | `CaptureOk.matched_facts` 44; `CaptureOk.excluded_facts` 60; `HasTypeArmsQ.capture_plain_success` 101,105; `HasTypeArmsQ.capture_guard_success` 237,244 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| MeaningTransport.lean | `MOrder` 14; `fields_meaning` 29,41; `data_shape_meaning` 46,56; `each_meaning` 76,82,83; `list_shape_meaning` 86,99; `assumptions_meaning` 115,124,125,128; `order_trans` 133,134; `order_refine` 140,141; `order_data` 147,150; `order_step` 158,163,166,167,168,169,170,171,173,174,176,177; `meaning_order_sound` 193,195; `valueMeaning_field_mono` 200,202; `valueMeaning_sub` 210,212 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| MeaningTransportObstruction.lean | `ordinary_supply_counterexample` 105,111 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Narrowing.lean | `ContextMap.facts` 182,183,184,185,186; `ContextMap.transport` 190,199; `ContextMap.conditions_params` 280,281; `ContextMap.conditions_many` 375,376,382; `ContextMap.conditions_clause` 399,400,402; `ContextMap.conditions_failure` 420,421,423; `context_value` 435; `context_values` 491; `context_each` 499; `context_comp` 507; `context_arms` 575; `context_clauses` 607; `context_failure` 617; `context_telArgs` 627; `context_telBody` 639; `context_at_call` 651 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| NarrowingObstruction.lean | `context_facts` 49; `facts_preserved` 51,53 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| NormalWellFormed.lean | `Ty.assume_of_wf` 6,7,9 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| NormalizationLogic.lean | `Ty.entails_assume_iff_predicates` 24,25,26; `Ty.assume_of_norm_eq` 28,29,30,31,32 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| OpenSubstitution.lean | `context_facts` 44,45; `target_path_from_facts` 50,51; `target_conditions_from_facts` 53,57; `transport` 80,83; `all_open_covers` 107; `source_introduce` 112,114; `introduce_bind_shape` 127 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| PathConditions.lean | `Ty.LeQ.weaken_conditions` 11 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| PathFacts.lean | `Entails.extend_conditions` 225,226 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| RangeFormation.lean | `pred_sorted_ranges` 162 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| RangeSubst.lean | `Eff.norm_rawMapRanges` 161,162,163; `Ctx.mapRanges` 183,184,185,191,192,193; `sorted_mapRanges` 204 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| ReferenceCalls.lean | `narrow_transport` 37,38,41,44,46; `ClosureTy.pure_primitive` 354 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ReferenceStore.lean | `CaptureOk.reference_write_snapshot` 194 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Shift.lean | `Ctx.facts_shiftV` 33,34,35,36,38,43; `Transport.shiftV` 58 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| SubstTyping.lean | `TypedImages.transport` 61,66,67,68,69; `SubstOk.transport` 90; `TypedImages.conditions_params` 149,151; `SubstOk.up` 523; `SubstOk.upN` 532,546,550; `SubstOk.clause` 757; `shifted_values_facts` 820,821,822; `Transport.up_norm` 857,858; `SubstOk.handler_conditions` 896,898,903,909; `SubstOk.failure_conditions` 927,928,930,932; `subst_value` 1006; `subst_values` 1134; `subst_each` 1142; `subst_comp` 1151,1163; `subst_arms` 1363; `subst_clauses` 1418; `subst_failure` 1437; `subst_telArgs` 1454; `subst_telBody` 1470,1482; `subst_at_call` 1492; `HasTypeVQ.subst` 1523; `HasTypeVsQ.subst` 1533; `HasTypeEachQ.subst` 1543; `HasTypeCQ.subst` 1553; `HasTypeTelArgsQ.subst` 1562; `HasTypeArmsQ.subst` 1572; `TelBodyTy.subst` 1582; `HasTypeClausesQ.subst` 1593; `HasFailureClause.subst` 1603; `SubstOk.transport_extendNone` 1611; `HasTypeVQ.subst_under_none` 1622,1627; `HasTypeVsQ.subst_under_none` 1634,1639; `HasTypeEachQ.subst_under_none` 1646,1651; `HasTypeCQ.subst_under_none` 1657,1666; `HasTypeTelArgsQ.subst_under_none` 1673,1679; `HasTypeArmsQ.subst_under_none` 1685,1693; `HasTypeClausesQ.subst_under_none` 1700,1708; `HasFailureClause.subst_under_none` 1715,1722 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| SubstTypingObstruction.lean | `context_facts` 109,110; `transport` 127,134; `source_le` 175,328,329; `conditions_image` 228,230,232; `swap_not_canonical` 277 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| Transport.lean | `Ty.assume_bind` 75,76,78,79,80; `Transport` 88; `Transport.assumptions` 105,108; `Transport.extend` 115,162,163,169,174,175,178,181; `Transport.up` 187; `Transport.up_raw` 197; `Transport.extendNone` 238,239,245,250,252,255; `Ty.LeQ.rawBind` 279,289 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes` 206,207,208; `TypeCtxMap.facts` 212,213,214; `TypeCtxMap.transport` 223; `TypeCtxMap.entails` 258,261 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypeSubst.lean | `Ctx.facts_bindTypes` 18,19,20,21,24; `Transport.types` 45 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypeSubstTyping.lean | `case_V_Refine` 416,423; `case_Capture_mk` 974 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypedFacts.lean | `HasTypeVQ.assume` 208,210,214,216,226,229,234,241,243; `HasTypeVQ.assume_optional` 249,251,255,257,267,270,275,284,286 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypedMeaning.lean | `typed_meaning_aux` 134,141 | 本文変更あり。型域・構成/分解・簡約を追随し、既定ビルドで確認 |
| TypedMeaningExamples.lean | `typed_entries` 25 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| Typing.lean | `Entails.conditions_cons` 133,134,135; `HasTypeVQ` 250; `CaptureOk` 399; `HasTypeVQ.refine_integer` 523 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| TypingShift.lean | `ShiftMap.facts` 68,69,70,71,72,73; `ShiftMap.transport` 78,83; `Entails.under_none` 174,175,180; `Entails.under_params` 218,219,224; `ShiftMap.conditions_params` 228,230; `Ctx.mem_facts_hide` 244,247,248,250,251; `Entails.hideConts` 253,254,258; `Transport.entails` 262,266; `FullShiftMap.conditions_many` 493,495,498,503; `FullShiftMap.conditions_clause` 524,526,529; `FullShiftMap.conditions_failure` 547,548,550; `HasTypeVQ.shift_values` 586; `HasTypeVsQ.shift_values` 729; `HasTypeEachQ.shift_values` 741; `HasTypeCQ.shift_values` 754; `HasTypeArmsQ.shift_values` 933; `HasTypeClausesQ.shift_values` 976; `HasFailureClause.shift_values` 994; `HasTypeTelArgsQ.shift_values` 1011; `TelBodyTy.shift_values` 1026; `AtCallAdmissible.shift_values` 1097; `HasTypeVQ.weaken_conditions` 1145; `HasTypeCQ.weaken_conditions` 1155; `ImageOk.weaken_conditions` 1166 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ValueFacts.lean | `(先頭)` 8; `HasTypeVQ.facts` 15,17,18; `HasTypeVQ.subtype_facts` 20,23,25,30; `HasTypeVQ.integer_facts` 74,77,78; `HasTypeVQ.list_facts` 100,104,107; `HasTypeVQ.field_facts` 149,153,158; `HasTypeVQ.list_element_facts` 160,162,163,166; `HasTypeVQ.field_facts_by_type` 231,237,242 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ValueReferences.lean | `Tel.References.norm` 187 | 本文保持。新しい事実の契約で既定ビルドを確認 |
| ValueRegularity.lean | `Tel.sorted_norm` 288 | 本文保持。新しい事実の契約で既定ビルドを確認 |

## 既定ビルドで見つかった簡約の読者

- OpenSubstitution.context_facts・transport: 等式だけの列を、型域と等式を含む列へ変更。像は加算なので、既存の等式から値7への検査済みの限定書換えで上下限を供給した。外部の仮定は追加しない。
- SubstTypingObstruction.context_facts・transport: 二変数の上下限を残し、同じ変数へ写る像で全事実を再使用する。source_leの先頭要素への依存を所属へ直した。
- ContextFacts.mem_facts_extendNone: unitのcarrierFactsが空であることを展開へ加えた。
- Context/Facts.assume_wellFormed: baseの空列を仮定した枝を、七整数型と Byte・Decimalの整形式の証明へ変更した。
- TypedFacts.assume・assume_optional: 定数の空列を仮定した枝を、ConstOK.representedからの型域の証明へ変更した。

これらの既存読者は、群Aの広い `facts|assume` の在庫には含まれていた。狭い定義展開の検索だけではOpenSubstitution.context_facts等を拾えない。広い元在庫の外で新たに壊れた既存読者は0。今回の補助で追加した型付き意味の空文脈の簡約も修正済みであり、既存読者の追加発見数に混ぜない。

字句検索の現在の件数と生一覧の大きさ・SHA-256は inventory-summary.json に置く。全出現を再生成する台本は records.py。匿名.mkや簡約に依存する読者の完了は、この検索だけでなく全既定ビルドの成功を根拠とする。

## 再開1での別名の処分

切替後の別名16組を本来の入口に統合した。実際の読者は同じ入口へ移し、並置補題の別名は残していない。assumptionsWithCarrierは読者を移した後に削除した。固有の補題二つも言明に合わせて改名した。

| 取り除いた名前 | 現在の入口 |
|---|---|
| `Ty.assumeWithCarrier_eq_carrier_append` | `Ty.assume_eq_carrier_append` |
| `Ty.assumeWithCarrier_norm` | `Ty.assume_norm` |
| `Ty.assumeWithCarrier_refined` | `Ty.assume_refined` |
| `Ty.assumeWithCarrier_of_wf` | `Ty.assume_of_wf` |
| `Ty.assumeWithCarrier_shiftV` | `Ty.assume_shiftV` |
| `Ctx.mem_factsWithCarrier_extend` | `Ctx.mem_facts_extend` |
| `Ctx.mem_factsWithCarrier` | `Ctx.mem_facts` |
| `Ctx.mem_factsWithCarrier_extendNone` | `Ctx.mem_facts_extendNone` |
| `Ctx.factsWithCarrier_map_norm` | `Ctx.facts_map_norm` |
| `Ctx.NormEq.factsWithCarrier` | `Ctx.NormEq.facts` |
| `Ty.LeQ.assumeWithCarrier` | `Ty.LeQ.assume` |
| `Ty.assumeWithCarrier_of_norm_eq` | `Ty.assume_of_norm_eq` |
| `Ty.assumeWithCarrier_bind` | `Ty.assume_bind` |
| `assumptionsWithCarrier_bind` | `Transport.assumptions` |
| `Ty.assumeWithCarrier_rawMapRanges` | `Ty.assume_rawMapRanges` |
| `Ty.assumeWithCarrier_shiftTypes` | `Ty.assume_shiftTypes` |
| `Ty.entails_assumeWithCarrier_iff` | `Ty.entails_assume_iff` |
| `Ty.carrierFacts_subset_assumeWithCarrier` | `Ty.carrierFacts_subset_assume` |

`Ty.assumeWithCarrier` と `Ctx.factsWithCarrier` の略記自体は、既存のLogicKernelExamplesと写しが読むため保持する。略記についての補題を別名で二重に提供しない。
