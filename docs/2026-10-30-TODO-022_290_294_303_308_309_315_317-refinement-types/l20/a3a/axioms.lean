import Lean
import Benitoite

/-! 変更した全モジュールのprivate・生成宣言を含む公理依存を照合する。 -/
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.Admissible,
    `Benitoite.Release.Refinement.AdmissibleMap,
    `Benitoite.Release.Refinement.CaptureRegularity,
    `Benitoite.Release.Refinement.ClosedCapture,
    `Benitoite.Release.Refinement.ConstraintAssumptions,
    `Benitoite.Release.Refinement.Context.Declarations,
    `Benitoite.Release.Refinement.Context.Facts,
    `Benitoite.Release.Refinement.Context.WF,
    `Benitoite.Release.Refinement.Declared,
    `Benitoite.Release.Refinement.DeclaredTransport,
    `Benitoite.Release.Refinement.External,
    `Benitoite.Release.Refinement.HandlerAlgebra,
    `Benitoite.Release.Refinement.HandlerContracts,
    `Benitoite.Release.Refinement.HandlerOperation,
    `Benitoite.Release.Refinement.KindValues,
    `Benitoite.Release.Refinement.LazyPreservation,
    `Benitoite.Release.Refinement.LegacyDeclarations,
    `Benitoite.Release.Refinement.LegacyInput,
    `Benitoite.Release.Refinement.LegacyKinds,
    `Benitoite.Release.Refinement.LegacyTables,
    `Benitoite.Release.Refinement.LegacyValues,
    `Benitoite.Release.Refinement.Narrowing,
    `Benitoite.Release.Refinement.PathFacts,
    `Benitoite.Release.Refinement.ProgramTyping,
    `Benitoite.Release.Refinement.ProgramWellFormed,
    `Benitoite.Release.Refinement.ReferencePreservation,
    `Benitoite.Release.Refinement.StateTyping,
    `Benitoite.Release.Refinement.SubstTyping,
    `Benitoite.Release.Refinement.SubstitutionContracts,
    `Benitoite.Release.Refinement.TypeArgumentRegularity,
    `Benitoite.Release.Refinement.TypeFormation,
    `Benitoite.Release.Refinement.TypeRenaming,
    `Benitoite.Release.Refinement.TypeShiftContext,
    `Benitoite.Release.Refinement.TypeShiftContracts,
    `Benitoite.Release.Refinement.TypeShiftExchange,
    `Benitoite.Release.Refinement.TypeShiftKinds,
    `Benitoite.Release.Refinement.TypeShiftTyping,
    `Benitoite.Release.Refinement.TypeSubstContracts,
    `Benitoite.Release.Refinement.Types,
    `Benitoite.Release.Refinement.Typing,
    `Benitoite.Release.Refinement.TypingDeclared,
    `Benitoite.Release.Refinement.TypingShift,
    `Benitoite.Release.Refinement.VarianceValidation
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
