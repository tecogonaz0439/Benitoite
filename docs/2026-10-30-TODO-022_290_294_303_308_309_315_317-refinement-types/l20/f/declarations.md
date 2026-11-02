# 追加した宣言

名前空間は `Benitoite.Release.Refinement`。完全署名は [signatures.md](signatures.md) を参照する。生成宣言は [axioms.lean](axioms.lean) がモジュール単位で列挙する。

| モジュール | 宣言 |
|---|---|
| `CloseTyping` | `Ty.Annotation.toTel`、`hideConts_idempotent`、`close_dependent_lambda`、`close_lambda`、`CaptureOk.close_sat`、`close_value_aux`、`close_values_aux`、`close_each_aux`、`close_value_typed`、`close_values_typed`、`close_each_typed` |
| `ClosureViewTyping` | `Comp.readValues`、`HasTypeVsQ.read_values`、`HasTypeTelArgsQ.read_values`、`HasTypeCQ.read_values`、`closeVals_eq_map`、`Val.resolveLocalsList_eq_map`、`Comp.readValues_resolve`、`Closure.readValues_view`、`ClosureViewTy`、`ClosureTy.view_typed`、`Val.ClosedList.member`、`Comp.ClosedAt.read_values`、`Closure.view_adequate`、`ClosureTy.view_read_ground`、`ClosureTy.view_read_typed` |
| `CaptureApplicationAlgebra` | `Val.observation_wf`、`Val.observation_slots_wf`、`Term.bind_closed`、`CaptureOk.closed`、`Capture.extendMany_values`、`Capture.extendMany_env_outer`、`Capture.extendMany_env_inner`、`Capture.apply_observations`、`Capture.closeTyAt_apply_all`、`Eff.norm_rawSubstV`、`Capture.closeEffAt_apply_all`、`CaptureOk.bindParams`、`Capture.Closed.extendMany`、`Capture.Adequate.extendMany`、`Capture.close_pred_apply_all`、`Capture.close_facts_apply_all` |
| `ClosureApply` | `TelBodyTy.capture_all`、`DependentClosureTy.apply_all`、`CaptureOk.mapReturn`、`CaptureLocals.apply_all`、`ClosureTy.apply_all` |
| `CloseApplication` | `Tel.arguments_observations`、`HasTypeTelArgsQ.close_typed`、`HasTypeCQ.close_app_aux`、`ClosureTy.app_view_typed`、`ClosureTy.ret_view_typed`、`HasTypeCQ.close_method_aux`、`ClosureTy.method_view_typed` |
| `ClosureCallInputs` | `HasTypeCQ.call_inputs`、`HasTypeCQ.closure_inputs`、`HasTypeVQ.fun_origin`、`HasTypeCQ.fun_apply_all` |
| `ClosureStateLeaves` | `Closure.Adequate.apply`、`Closure.ClosedAt.apply`、`StateTyE.dependent_beta_all`、`StateTy.dependent_beta_all`、`ContTy.let_inv`、`StateTyE.let_step`、`ContTy.apply_let`、`StateTyE.return_step`、`StateTyE.mark_step`、`StateTyE.fun_step`、`StateTyE.method_step`、`StateTyE.super_step`、`StateTy.let_step`、`StateTy.return_step`、`StateTy.mark_step`、`StateTy.fun_step`、`StateTy.method_step`、`StateTy.super_step` |
| `CallBodyScope` | `type_image_value_wf`、`row_image_value_wf`、`source_type_inst_wf`、`source_row_inst_wf`、`source_types_inst_wf`、`source_rows_inst_wf`、`Val.SourceScoped.runtime_inst`、`scopedValues_runtime_inst`、`Comp.SourceScoped.runtime_inst`、`scopedArms_runtime_inst`、`scopedClauses_runtime_inst` |
| `MethodTypeComposition` | `SubstEnv.afterTypes`、`SubstEnv.afterTypes_up`、`Ty.rawBind_after_types`、`rawBindTys_after_types`、`Eff.rawBind_after_types`、`Tel.rawBind_after_types`、`Tel.bind_after_types`、`Ty.bind_sameTypes_below`、`Tel.bind_sameTypes_below`、`Tel.shiftV_of_wf_zero`、`tel_substAt_shiftV_closed`、`Ty.subst_shift_prefix`、`methodTel_comp`、`method_dictionary_context`、`dependent_result_close` |
| `MethodClosure` | `HasTypeCQ.method_apply_all` |
| `SuperClosure` | `CaptureOk.closed_arguments`、`HasTypeVQ.super_dictionary`、`Val.superStep_source`、`HasTypeVQ.super_step_aux`、`HasTypeCQ.method_super_aux` |
| `ReferenceCalls` | `HasTypeVsQ.toTel_normal` |
| `HandlerPreservation` | `ContTy.normal_return_tail`、`ClosureTy.result_normal` |
| `TypeSubstFormation` | `rawApply_rawBind` |
| `TypeSubstBindings` | `Ty.rawBind_shift_source` |
| `SubstTyping` | `SubstOk.signature`、`SubstOk.methodRows` |

手書きの追加宣言は115件（定理112件、定義2件、判断1件）である。既存の `HandlerPreservation` の private な `normal_return_tail` は `normal_return_tail_base` へ改名し、同じ本体を公開入口から呼ぶ。定理の言明は変えていない。
