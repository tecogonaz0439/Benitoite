# 76葉への開始入力の供給

2026-11-03、再開1。継承69＋追加7、Stepを返す60＋到達型だけ16を維持する。構成子は76のままで、E_Lamの前提だけを承認どおり広げた。LeafInputsの読者は同じ実開始と既存の保存葉が返す行先へState.Inputsを適用する。runは元コードのComp.Inputs・CaptureOk・CaptureContextRegular・CaptureLocals、matchRunは同じ照合値/観測/腕/Exhaustive、error/exitは同じストアと継続を保持する。以下は供給側の対応であり、応答条件の存在と進行/保存の主定理の閉鎖は含めない。

| 葉 | 既存の読者 | 今回の供給・後段の境界 |
|---|---|---|
| `E_BuilderNew` | `BuilderStateLeaves`：`StateTyE.builder_new` | 供給側完了。builderLet/builderOpのComp.Inputsとbuilder_cell、既存保存葉の同じ開始/行先の入力の読者。L70が全分配 |
| `E_BuilderOp` | `BuilderStateLeaves`：`StateTyE.builder_operation` | 供給側完了。builderLet/builderOpのComp.Inputsとbuilder_cell、既存保存葉の同じ開始/行先の入力の読者。L70が全分配 |
| `E_BuilderErr` | `BuilderStateLeaves`：`StateTyE.builder_error` | 供給側完了。builderLet/builderOpのComp.Inputsとbuilder_cell、既存保存葉の同じ開始/行先の入力の読者。L70が全分配 |
| `E_Let` | `ClosureStateLeaves`：`StateTyE.let_step` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_Return` | `ClosureStateLeaves`：`StateTyE.return_step` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_Lam` | `ClosureStateLeaves`：`StateTyE.lambda_beta_all` | 供給側完了。lambda_inputsが元の型付き実引数列から個数を導き、通常/依存lambdaとclosureへStepと同じ行先入力を供給。従来のclosureの到達先を維持。L70が全分配 |
| `E_ExternalApply` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_ExternalApply` | 供給側完了。externalRef_contract_inputs/inv_externalRefとexternalのComp.Inputs、store_replyの開始/行先の読者。L60が外部応答、L70が全分配 |
| `E_External` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_External` | 供給側完了。externalRef_contract_inputs/inv_externalRefとexternalのComp.Inputs、store_replyの開始/行先の読者。L60が外部応答、L70が全分配 |
| `E_ExternalErr` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_ExternalErr` | 供給側完了。externalRef_contract_inputs/inv_externalRefとexternalのComp.Inputs、store_replyの開始/行先の読者。L60が外部応答、L70が全分配 |
| `E_PathBasesApply` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_PathBasesApply` | 供給側完了。primitive_contract_inputs・inv_pathBases/inv_scopePattern・checkAt/issuePathBasesのComp.Inputs。atError専用逆転。store_replyの開始/行先の読者。L50が全σ/対象、L60が応答 |
| `E_IssuePathBases` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_IssuePathBases` | 供給側完了。primitive_contract_inputs・inv_pathBases/inv_scopePattern・checkAt/issuePathBasesのComp.Inputs。atError専用逆転。store_replyの開始/行先の読者。L50が全σ/対象、L60が応答 |
| `E_AtOk` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_AtOk` | 供給側完了。primitive_contract_inputs・inv_pathBases/inv_scopePattern・checkAt/issuePathBasesのComp.Inputs。atError専用逆転。store_replyの開始/行先の読者。L50が全σ/対象、L60が応答 |
| `E_AtError` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_AtError` | 供給側完了。primitive_contract_inputs・inv_pathBases/inv_scopePattern・checkAt/issuePathBasesのComp.Inputs。atError専用逆転。store_replyの開始/行先の読者。L50が全σ/対象、L60が応答 |
| `E_AtPrepareError` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_AtPrepareError` | 供給側完了。primitive_contract_inputs・inv_pathBases/inv_scopePattern・checkAt/issuePathBasesのComp.Inputs。atError専用逆転。store_replyの開始/行先の読者。L50が全σ/対象、L60が応答 |
| `E_Fun` | `ClosureStateLeaves`：`StateTyE.fun_step` | 供給側完了。fnRef_contract_inputs/Def.WellTyped.inputs又はinv_meth/method_inputs。既存保存葉後の同じ本体の入力と次appの形成。L70が全宣言/具体化の合成 |
| `E_Meth` | `ClosureStateLeaves`：`StateTyE.method_step` | 供給側完了。fnRef_contract_inputs/Def.WellTyped.inputs又はinv_meth/method_inputs。既存保存葉後の同じ本体の入力と次appの形成。L70が全宣言/具体化の合成 |
| `E_Super` | `ClosureStateLeaves`：`StateTyE.super_step` | 供給側完了。fnRef_contract_inputs/Def.WellTyped.inputs又はinv_meth/method_inputs。既存保存葉後の同じ本体の入力と次appの形成。L70が全宣言/具体化の合成 |
| `E_IfT` | `PathConditions`：`StateTyE.if_true` | 供給側完了。if_inputsが実際のBooleanと選択先のState.Inputsを供給。L40.20が標準facts、L70が全分配 |
| `E_IfF` | `PathConditions`：`StateTyE.if_false` | 供給側完了。if_inputsが実際のBooleanと選択先のState.Inputsを供給。L40.20が標準facts、L70が全分配 |
| `E_Match` | `MatchPaths`：`StateTyE.match_start` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_MatchSkip` | `MatchPaths`：`StateTyE.match_skip` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_MatchBody` | `MatchStateLeaves`：`StateTyE.match_body` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_MatchGuard` | `MatchStateLeaves`：`StateTyE.match_guard` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_GuardT` | `MatchPaths`：`StateTyE.guard_true` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_GuardF` | `MatchPaths`：`StateTyE.guard_false` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_ErrPopGuard` | `MatchStateLeaves`：`StateTyE.err_pop_guard` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_ExitPopGuard` | `MatchStateLeaves`：`StateTyE.exit_pop_guard` | 供給側完了。match_inputsが同じ照合値・obs条件/sort・HasTypeArmsQ・Exhaustiveを供給。既存の選択/真偽/pop後にもinputsの読者。guard_op_inputsは元操作列の空行Covers。L40.20/L70が全合成 |
| `E_Prim` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_Prim` | 供給側完了。primitive_contract_inputsで同じ元署名・実引数列、store_replyで同じ開始/行先の入力。L40.16〜.29が具体δ、L50/L60が全σ/応答、L70が全分配 |
| `E_Err` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_Err` | 供給側完了。primitive_contract_inputsで同じ元署名・実引数列、store_replyで同じ開始/行先の入力。L40.16〜.29が具体δ、L50/L60が全σ/応答、L70が全分配 |
| `E_IO` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_IO` | 供給側完了。primitive_contract_inputsで同じ元署名・実引数列、store_replyで同じ開始/行先の入力。L40.16〜.29が具体δ、L50/L60が全σ/応答、L70が全分配 |
| `E_IOErr` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_IOErr` | 供給側完了。primitive_contract_inputsで同じ元署名・実引数列、store_replyで同じ開始/行先の入力。L40.16〜.29が具体δ、L50/L60が全σ/応答、L70が全分配 |
| `E_Exit` | `StoreReplyLeaves`：`StateTyE.store_reply / StoreReplyInputs.E_Exit` | 供給側完了。primitive_contract_inputsで同じ元署名・実引数列、store_replyで同じ開始/行先の入力。L40.16〜.29が具体δ、L50/L60が全σ/応答、L70が全分配 |
| `E_RefNew` | `StateLeaves`：`StateTyE.reference_new_all` | 供給側完了。元appのprimitive_contract_inputs、canonical_ref/inv_loc/ref_cell/reference_cell_inputs、既存保存葉後の入力の読者。L70が全分配 |
| `E_RefGet` | `StateLeaves`：`StateTyE.reference_get_all` | 供給側完了。元appのprimitive_contract_inputs、canonical_ref/inv_loc/ref_cell/reference_cell_inputs、既存保存葉後の入力の読者。L70が全分配 |
| `E_RefSet` | `StateLeaves`：`StateTyE.reference_set_all` | 供給側完了。元appのprimitive_contract_inputs、canonical_ref/inv_loc/ref_cell/reference_cell_inputs、既存保存葉後の入力の読者。L70が全分配 |
| `E_RefUpdate` | `StateLeaves`：`StateTyE.reference_update_all` | 供給側完了。元appのprimitive_contract_inputs、canonical_ref/inv_loc/ref_cell/reference_cell_inputs、既存保存葉後の入力の読者。L70が全分配 |
| `E_Lazy` | `LazyPreservation`：`StateTyE.lazy_transition` | 供給側完了。lazyのComp.Inputs・primitive_contract_inputs・canonical_lazy/inv_loc/lazy_cell。thunk/done/書戻しの同じ開始/行先の入力。L70が全分配 |
| `E_ForceDone` | `StateLeaves`：`StateTyE.force_done_all` | 供給側完了。lazyのComp.Inputs・primitive_contract_inputs・canonical_lazy/inv_loc/lazy_cell。thunk/done/書戻しの同じ開始/行先の入力。L70が全分配 |
| `E_Force` | `StateLeaves`：`StateTyE.force_thunk_all` | 供給側完了。lazyのComp.Inputs・primitive_contract_inputs・canonical_lazy/inv_loc/lazy_cell。thunk/done/書戻しの同じ開始/行先の入力。L70が全分配 |
| `E_Update` | `StateLeaves`：`StateTyE.lazy_update_all` | 供給側完了。lazyのComp.Inputs・primitive_contract_inputs・canonical_lazy/inv_loc/lazy_cell。thunk/done/書戻しの同じ開始/行先の入力。L70が全分配 |
| `E_Mark` | `ClosureStateLeaves`：`StateTyE.mark_step` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_EscLet` | `StateLeaves`：`StateTyE.escape_let` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_EscHandle` | `StateLeaves`：`StateTyE.escape_handler` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_EscMark` | `StateLeaves`：`StateTyE.escape_mark` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_Use` | `HandlerGeneral`：`StateTyE.use_all` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_Release` | `HandlerGeneral`：`StateTyE.return_release` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_RelErr` | `HandlerGeneral`：`StateTyE.return_release_failure` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_EscRel` | `HandlerGeneral`：`StateTyE.escape_release` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_EscRelErr` | `HandlerGeneral`：`StateTyE.escape_release_failure` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ErrPopLet` | `StateLeaves`：`StateTyE.error_let` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_ErrPopMark` | `StateLeaves`：`StateTyE.error_mark` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_ErrPopUpdate` | `LazyPreservation`：`StateTyE.lazy_update_pop_error` | 供給側完了。lazyのComp.Inputs・primitive_contract_inputs・canonical_lazy/inv_loc/lazy_cell。thunk/done/書戻しの同じ開始/行先の入力。L70が全分配 |
| `E_ErrPopHandle` | `HandlerGeneral`：`StateTyE.error_handler` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_ErrRel` | `HandlerGeneral`：`StateTyE.error_release` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ErrRelErr` | `HandlerGeneral`：`StateTyE.error_release_failure` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ExitPopLet` | `StateLeaves`：`StateTyE.exit_let` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_ExitPopMark` | `StateLeaves`：`StateTyE.exit_mark` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_ExitPopUpdate` | `LazyPreservation`：`StateTyE.lazy_update_pop_exit` | 供給側完了。lazyのComp.Inputs・primitive_contract_inputs・canonical_lazy/inv_loc/lazy_cell。thunk/done/書戻しの同じ開始/行先の入力。L70が全分配 |
| `E_ExitPopHandle` | `HandlerGeneral`：`StateTyE.exit_handler` | 供給側完了。同じStateTyEからClosure/Comp.Inputsと保存継続を供給。既存保存葉の同じ開始/選択行先の入力の読者。L70が全分配 |
| `E_ExitRel` | `HandlerGeneral`：`StateTyE.exit_release` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ExitRelErr` | `HandlerGeneral`：`StateTyE.exit_release_failure` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_Handle` | `HandlerGeneral`：`StateTyE.handle_step` | 供給側完了。handleの通常/FailのComp.Inputsとop/raise/primitiveの元契約。既存保存葉の選択節と行先入力の読者。L60が実表/応答、L70が全分配 |
| `E_HRet` | `HandlerGeneral`：`StateTyE.handler_return` | 供給側完了。handleの通常/FailのComp.Inputsとop/raise/primitiveの元契約。既存保存葉の選択節と行先入力の読者。L60が実表/応答、L70が全分配 |
| `E_Op` | `HandlerGeneral`：`StateTyE.operation_all` | 供給側完了。handleの通常/FailのComp.Inputsとop/raise/primitiveの元契約。既存保存葉の選択節と行先入力の読者。L60が実表/応答、L70が全分配 |
| `E_OpFail` | `HandlerGeneral`：`StateTyE.operation_failure` | 供給側完了。handleの通常/FailのComp.Inputsとop/raise/primitiveの元契約。既存保存葉の選択節と行先入力の読者。L60が実表/応答、L70が全分配 |
| `E_OpPrim` | `HandlerGeneral`：`StateTyE.operation_primitive` | 供給側完了。handleの通常/FailのComp.Inputsとop/raise/primitiveの元契約。既存保存葉の選択節と行先入力の読者。L60が実表/応答、L70が全分配 |
| `E_Resume` | `HandlerGeneral`：`StateTyE.resume_all` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ResumeErr` | `HandlerPreservation`：`StateTyE.resume_used` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_Drop` | `HandlerGeneral`：`StateTyE.drop_used_all` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_DropRel` | `HandlerGeneral`：`StateTyE.drop_release_all` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_EscDrop` | `HandlerGeneral`：`StateTyE.escape_drop_used` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_EscDropRel` | `HandlerGeneral`：`StateTyE.escape_drop_release` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ErrDrop` | `HandlerGeneral`：`StateTyE.error_drop` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ErrDropRel` | `HandlerPreservation`：`StateTyE.err_drop_rel` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ExitDrop` | `HandlerGeneral`：`StateTyE.exit_drop` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |
| `E_ExitDropRel` | `HandlerPreservation`：`StateTyE.exit_drop_rel` | 供給側完了。use/resumeのComp.Inputsとcont_cellのcont/used・保存ContTy。既存保存葉の同じ開始/選択行先の入力の読者。L60が解放応答、L70が全分配 |

76行、重複0。StoreReplyInputsの各構成子への分配は既存store_replyを継承し、同じ開始と行先の入力を一つの読者で受ける。残る葉にもLeafInputs内の同名の読者を置き、E_Lamはlambda_inputs、ifの両側はif_selected/if_inputsで供給する。全76葉の保存の主定理を新たに閉じたという判定はしない。
