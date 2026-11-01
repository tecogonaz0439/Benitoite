import Lean
import Benitoite
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.HandlerContracts,
    `Benitoite.Release.Refinement.HandlerAlgebra,
    `Benitoite.Release.Refinement.HandlerTyping,
    `Benitoite.Release.Refinement.HandlerOperation,
    `Benitoite.Release.Refinement.Context.Declarations,
    `Benitoite.Release.Refinement.LegacyTables,
    `Benitoite.Release.Refinement.CurrentSignatureRows,
    `Benitoite.Release.Refinement.TypeSubstRowObstruction,
    `Benitoite.Release.Refinement.External,
    `Benitoite.Release.Refinement.Typing,
    `Benitoite.Release.Refinement.TypingShift,
    `Benitoite.Release.Refinement.TypeShiftTyping,
    `Benitoite.Release.Refinement.SubstTyping,
    `Benitoite.Release.Refinement.TargetTable,
    `Benitoite.Release.Refinement.TypeSubstContracts,
    `Benitoite.Release.Refinement.TypeSubstFormation,
    `Benitoite.Release.Refinement.TypeSubstCalls,
    `Benitoite.Release.Refinement.TypeSubstGateExamples,
    `Benitoite.Release.Refinement.NestedContinuation
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
