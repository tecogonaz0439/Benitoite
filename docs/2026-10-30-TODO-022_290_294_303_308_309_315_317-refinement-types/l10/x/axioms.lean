import Lean
import Benitoite
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite,
    `Benitoite.Release.Refinement.AtPatterns,
    `Benitoite.Release.Refinement.CoverageRefinement,
    `Benitoite.Release.Refinement.MatchFacts,
    `Benitoite.Release.Refinement.ObservationInterpretation,
    `Benitoite.Release.Refinement.ObservationOrder,
    `Benitoite.Release.Refinement.ObservationSubstitution,
    `Benitoite.Release.Refinement.PatternNormalForm,
    `Benitoite.Release.Refinement.PatternSemantics,
    `Benitoite.Release.Refinement.PatternTransport,
    `Benitoite.Release.Refinement.PatternTypeShift,
    `Benitoite.Release.Refinement.Patterns,
    `Benitoite.Release.Refinement.RefinementObservation,
    `Benitoite.Release.Refinement.ValueMeaning,
    `Benitoite.Release.Refinement.ValueMeaningInhabits] do
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


open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (label, names, expected) in [
    ("INHABITS", [`Benitoite.Release.Refinement.Inhabits, `Benitoite.Release.Refinement.InhabitsAll,
       `Benitoite.Release.Refinement.InhabitsEach], 28),
    ("PATTERN", [`Benitoite.Release.Refinement.PatTy, `Benitoite.Release.Refinement.PatTys], 11),
    ("SCOPED_VALUE", [`Benitoite.Release.Refinement.ScopedValue], 3),
    ("MEANING", [`Benitoite.Release.Refinement.ValueMeaning, `Benitoite.Release.Refinement.ValueShapeMeaning,
       `Benitoite.Release.Refinement.ValueMeanings, `Benitoite.Release.Refinement.ValueMeaningEach], 28),
    ("OBSERVATION_ORDER", [`Benitoite.Release.Refinement.Observation.InfoLE, `Benitoite.Release.Refinement.Observation.OptionInfoLE,
       `Benitoite.Release.Refinement.Observation.SlotsInfoLE], 9),
    ("TERM", [`Benitoite.Release.Refinement.Term], 20),
    ("PREDICATE", [`Benitoite.Release.Refinement.Pred], 14),
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
      for ctor in info.ctors do logInfo m!"CASE {label} {name} {ctor}"
    unless count == expected do throwError "BAD_CASES {label}: {count}, expected {expected}"
    logInfo m!"CASE_TOTAL {label} {count}"
