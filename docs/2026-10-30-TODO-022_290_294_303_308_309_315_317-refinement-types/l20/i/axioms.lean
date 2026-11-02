import Lean
import Benitoite

-- formal/ で lake env lean -M 12288 により実行する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.TypedMeaning,
    `Benitoite.Release.Refinement.TypedCoverage,
    `Benitoite.Release.Refinement.TypedMeaningExamples,
    `Benitoite.Release.Refinement.PatternBindingSupport,
    `Benitoite.Release.Refinement.PatternBindings,
    `Benitoite.Release.Refinement.PatternBindingsGround,
    `Benitoite.Release.Refinement.PatternBindingExamples
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

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for name in [``Benitoite.Release.Refinement.HasTypeVQ, ``Benitoite.Release.Refinement.HasTypeVsQ,
      ``Benitoite.Release.Refinement.HasTypeEachQ, ``Benitoite.Release.Refinement.PatTy,
      ``Benitoite.Release.Refinement.PatTys] do
    match env.find? name with
    | some (.inductInfo info) => logInfo m!"AUDIT_CONSTRUCTORS {name} {info.ctors.length}"
    | _ => throwError "AUDIT_NOT_INDUCTIVE {name}"

-- 具体の適用と受理・拒否の対照の存在も名指しで確認する。
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.cap_month
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.dependent_capture_entries
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.nonempty_capture_coverage
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.reject_top
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.reject_list
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknown_entries
#print axioms Benitoite.Release.Refinement.TypedMeaningExamples.unknown_not_excluded
#print axioms Benitoite.Release.Refinement.month_variable_coverage
