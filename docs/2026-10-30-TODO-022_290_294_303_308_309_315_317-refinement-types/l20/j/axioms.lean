import Lean
import Benitoite

-- formal/ で lake env lean -M 12288 により実行する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.PatternMatchAnnotations,
    `Benitoite.Release.Refinement.PatternBindingsAdequate,
    `Benitoite.Release.Refinement.MatchStateLeaves,
    `Benitoite.Release.Refinement.HandlerGeneral,
    `Benitoite.Release.Refinement.MatchStateExamples,
    `Benitoite.Release.Refinement.RuntimeTypeSubst,
    `Benitoite.Release.Refinement.OperationStateExamples,
    `Benitoite.Release.Refinement.HandlerCalls,
    `Benitoite.Release.Refinement.ReferenceCalls,
    `Benitoite.Release.Refinement.HandlerContinuation,
    `Benitoite.Release.Refinement.CaptureRegularity,
    `Benitoite.Release.Refinement.HandlerOperation
  ] do
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    unless names.length > 0 do throwError "AUDIT_EMPTY {mod}"
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      if ci.isUnsafe || ci.isPartial then throwError "AUDIT_UNSAFE {name}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
      logInfo m!"AUDIT_TYPE {name} : {ci.type}"
      elabCommand (← `(#print axioms $(mkIdent name)))

#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeVQ.narrow
#print axioms Benitoite.Release.Refinement.HasTypeCQ.narrow

#print axioms Benitoite.Release.Model.assumptions
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames

#print axioms Benitoite.Release.Refinement.HasTypeVsQ.toTel_normal
#print axioms Benitoite.Release.Refinement.ContTy.normal_return_tail
#print axioms Benitoite.Release.Refinement.ClosureTy.result_normal
#print axioms Benitoite.Release.Refinement.rawApply_rawBind
#print axioms Benitoite.Release.Refinement.Ty.rawBind_shift_source
#print axioms Benitoite.Release.Refinement.SubstOk.signature
#print axioms Benitoite.Release.Refinement.SubstOk.methodRows
#print axioms Benitoite.Release.Refinement.CaptureOk
#print axioms Benitoite.Release.Refinement.DependentClosureTy
#print axioms Benitoite.Release.Refinement.ClosureTy
#print axioms Benitoite.Release.Refinement.ClosureViewTy
#print axioms Benitoite.Release.Refinement.StoreOk
#print axioms Benitoite.Release.Refinement.StateTyE
#print axioms Benitoite.Release.Refinement.StateTy
#print axioms Benitoite.Release.Refinement.HasTypeVQ
#print axioms Benitoite.Release.Refinement.HasTypeVsQ
#print axioms Benitoite.Release.Refinement.HasTypeEachQ
#print axioms Benitoite.Release.Refinement.HasTypeCQ
#print axioms Benitoite.Release.Refinement.HasTypeTelArgsQ
#print axioms Benitoite.Release.Refinement.TelBodyTy
#print axioms Benitoite.Release.Refinement.closeVal
#print axioms Benitoite.Release.Refinement.Closure.view
#print axioms Benitoite.Release.Refinement.Closure.apply
#print axioms Benitoite.Release.Refinement.Val.superStep
#print axioms Benitoite.Release.Refinement.ValueMeaning
#print axioms Benitoite.Release.Refinement.Builtins.CoreAssumptions
#print axioms Benitoite.Release.Refinement.Capture.closeTyAt_typeSubst
#print axioms Benitoite.Release.Refinement.Capture.closeEffAt_typeSubst
#print axioms Benitoite.Release.Refinement.Capture.closeTel_typeSubst
#print axioms Benitoite.Release.Refinement.Capture.closeRAt_typeSubst

#print axioms Benitoite.Release.Refinement.ValueMeaning
#print axioms Benitoite.Release.Refinement.PatTy
#print axioms Benitoite.Release.Refinement.PatTys
#print axioms Benitoite.Release.Refinement.AltsTy
#print axioms Benitoite.Release.Refinement.Inhabits
#print axioms Benitoite.Release.Refinement.Exhaustive
#print axioms Benitoite.Release.Refinement.Capture.meaning_coverage
#print axioms Benitoite.Release.Refinement.CaptureOk.variable_coverage

#print axioms Benitoite.Release.Refinement.valueMeaning_sub
#print axioms Benitoite.Release.Refinement.valueMeaning_inhabits_normal
#print axioms Benitoite.Release.Refinement.Inhabits.norm_all_iff


-- 強化した入口と、各全状態の具体読者も明示する。
#print axioms Benitoite.Release.Refinement.ContTy.split_handle
#print axioms Benitoite.Release.Refinement.split_fail_annotated
#print axioms Benitoite.Release.Refinement.HasTypeCQ.operation_call_all
#print axioms Benitoite.Release.Refinement.HasTypeCQ.failure_call
#print axioms Benitoite.Release.Refinement.HasTypeVQ.primitive_inputs
#print axioms Benitoite.Release.Refinement.StateTyE.operation_all
#print axioms Benitoite.Release.Refinement.StateTyE.operation_primitive
#print axioms Benitoite.Release.Refinement.StateTyE.operation_failure
#print axioms Benitoite.Release.Refinement.StateTyE.resume_all
#print axioms Benitoite.Release.Refinement.OperationStateExamples.row_handle_operation_resume
#print axioms Benitoite.Release.Refinement.OperationStateExamples.noFail_cutoff_accept
#print axioms Benitoite.Release.Refinement.OperationStateExamples.noFail_cutoff_reject
#print axioms Benitoite.Release.Refinement.OperationStateExamples.failure_state
#print axioms Benitoite.Release.Refinement.OperationStateExamples.primitive_pathBases

#print axioms Benitoite.Release.Refinement.OperationStateExamples.row_concrete_model
#print axioms Benitoite.Release.Refinement.MatchStateExamples.reject_guard_unknown_elimination
#print axioms Benitoite.Release.Refinement.MatchStateExamples.reject_false_fact_to_tail
#print axioms Benitoite.Release.Refinement.PatTy.bindings_annotation
#print axioms Benitoite.Release.Refinement.AltsTy.bindings_annotation
