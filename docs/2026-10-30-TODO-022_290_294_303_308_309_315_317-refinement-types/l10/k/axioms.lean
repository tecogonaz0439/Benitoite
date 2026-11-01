import Lean
import Benitoite
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [`Benitoite, `Benitoite.Release.Refinement.LegacyKinds, `Benitoite.Release.Refinement.LegacyDeclarations, `Benitoite.Release.Refinement.LegacyInput, `Benitoite.Release.Refinement.LegacyRegularity, `Benitoite.Release.Refinement.LegacyTables, `Benitoite.Release.Refinement.LegacyTableFacts, `Benitoite.Release.Refinement.LegacyValues] do
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do
      elabCommand (← `(#print axioms $(mkIdent name)))

#print axioms Benitoite.Release.Model.assumptions
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeVQ.narrow
#print axioms Benitoite.Release.Refinement.HasTypeCQ.narrow

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (label, names, expected) in [
      ("OLD_TYPING", [`Benitoite.Release.HasTypeVQ, `Benitoite.Release.HasTypeVsQ,
        `Benitoite.Release.HasTypeEachQ, `Benitoite.Release.HasTypeCQ, `Benitoite.Release.HasTypeArmsQ,
        `Benitoite.Release.HasTypeClausesQ, `Benitoite.Release.HasFailureClause], 46),
      ("LEGACY_RULES", [`Benitoite.Release.Refinement.LegacyRule], 46),
      ("LEGACY_JUDGMENTS", [`Benitoite.Release.Refinement.LegacyJudgment], 7),
      ("OLD_SYNTAX", [`Benitoite.Release.Val, `Benitoite.Release.Comp,
        `Benitoite.Release.Arm, `Benitoite.Release.Clause], 33),
      ("SUBTYPE", [`Benitoite.Release.Refinement.Ty.LeQ, `Benitoite.Release.Refinement.TelLe,
        `Benitoite.Release.Refinement.TelClosure, `Benitoite.Release.Refinement.TypeArgsLe], 22),
      ("TYPING", [`Benitoite.Release.Refinement.HasTypeVQ, `Benitoite.Release.Refinement.HasTypeCQ,
        `Benitoite.Release.Refinement.HasTypeVsQ, `Benitoite.Release.Refinement.HasTypeEachQ,
        `Benitoite.Release.Refinement.HasTypeArmsQ, `Benitoite.Release.Refinement.HasTypeClausesQ,
        `Benitoite.Release.Refinement.HasFailureClause, `Benitoite.Release.Refinement.HasTypeTelArgsQ,
        `Benitoite.Release.Refinement.TelBodyTy, `Benitoite.Release.Refinement.CaptureOk,
        `Benitoite.Release.Refinement.ClosureTy, `Benitoite.Release.Refinement.DependentClosureTy,
        `Benitoite.Release.Refinement.CheckedWitness, `Benitoite.Release.Refinement.ImageOk], 76)] do
    let mut count := 0
    for name in names do
      let some (.inductInfo info) := env.find? name | throwError "NOT_INDUCTIVE {name}"
      count := count + info.ctors.length
      logInfo m!"CASES {label} {name} {info.ctors.length}"
    unless count == expected do throwError "BAD_CASES {label}: {count}, expected {expected}"
    logInfo m!"CASE_TOTAL {label} {count}"
