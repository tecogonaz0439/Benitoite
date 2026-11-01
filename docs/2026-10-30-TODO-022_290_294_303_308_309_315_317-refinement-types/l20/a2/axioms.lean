import Lean
import Benitoite

/-! A2 の全対象宣言・private・生成宣言、旧主定理/三モデル、十の移送を監査する。 -/
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.CaptureRegularity,
    `Benitoite.Release.Refinement.Typing,
    `Benitoite.Release.Refinement.StateTyping,
    `Benitoite.Release.Refinement.ClosureTyping,
    `Benitoite.Release.Refinement.TypeRegularity,
    `Benitoite.Release.Refinement.ValueRegularity,
    `Benitoite.Release.Refinement.DeclaredTransport,
    `Benitoite.Release.Refinement.Context.Capture,
    `Benitoite.Release.Refinement.Admissible,
    `Benitoite.Release.Refinement.EffectCover,
    `Benitoite.Release.Refinement.SubstTyping,
    `Benitoite.Release.Refinement.TypingShift,
    `Benitoite.Release.Refinement.Narrowing,
    `Benitoite.Release.Refinement.TypeShiftTyping
  ] do
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    unless names.length > 0 do throwError "AUDIT_EMPTY {mod}"
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do elabCommand (← `(#print axioms $(mkIdent name)))

#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeVQ.narrow
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeCQ.narrow
#print axioms Benitoite.Release.Model.assumptions
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
