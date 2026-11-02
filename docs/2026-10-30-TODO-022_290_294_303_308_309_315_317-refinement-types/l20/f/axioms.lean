import Lean
import Benitoite
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.CloseTyping,
    `Benitoite.Release.Refinement.ClosureViewTyping,
    `Benitoite.Release.Refinement.CaptureApplicationAlgebra,
    `Benitoite.Release.Refinement.ClosureApply,
    `Benitoite.Release.Refinement.CloseApplication,
    `Benitoite.Release.Refinement.ClosureCallInputs,
    `Benitoite.Release.Refinement.ClosureStateLeaves,
    `Benitoite.Release.Refinement.CallBodyScope,
    `Benitoite.Release.Refinement.MethodTypeComposition,
    `Benitoite.Release.Refinement.MethodClosure,
    `Benitoite.Release.Refinement.SuperClosure,
    `Benitoite.Release.Refinement.ReferenceCalls,
    `Benitoite.Release.Refinement.HandlerPreservation,
    `Benitoite.Release.Refinement.TypeSubstFormation,
    `Benitoite.Release.Refinement.TypeSubstBindings,
    `Benitoite.Release.Refinement.SubstTyping
  ] do
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    unless names.length > 0 do throwError "AUDIT_EMPTY {mod}"
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do elabCommand (← `(#print axioms $(mkIdent name)))

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
