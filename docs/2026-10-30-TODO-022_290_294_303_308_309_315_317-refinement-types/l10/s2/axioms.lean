import Lean
import Benitoite
set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite,
    `Benitoite.Release.Refinement.Admissible,
    `Benitoite.Release.Refinement.AdmissibleMap,
    `Benitoite.Release.Refinement.ClosedCapture,
    `Benitoite.Release.Refinement.Context.Declarations,
    `Benitoite.Release.Refinement.EffectFacts,
    `Benitoite.Release.Refinement.HandlerAlgebra,
    `Benitoite.Release.Refinement.HandlerCalls,
    `Benitoite.Release.Refinement.HandlerOperation,
    `Benitoite.Release.Refinement.KindValues,
    `Benitoite.Release.Refinement.LazyPreservation,
    `Benitoite.Release.Refinement.LegacyDeclarations,
    `Benitoite.Release.Refinement.LegacyInput,
    `Benitoite.Release.Refinement.LegacyValues,
    `Benitoite.Release.Refinement.Narrowing,
    `Benitoite.Release.Refinement.NarrowingObstruction,
    `Benitoite.Release.Refinement.ReferencePreservation,
    `Benitoite.Release.Refinement.SubstTyping,
    `Benitoite.Release.Refinement.SubstTypingObstruction,
    `Benitoite.Release.Refinement.TypeArgumentRegularity,
    `Benitoite.Release.Refinement.TypeBounds,
    `Benitoite.Release.Refinement.TypeRegularity,
    `Benitoite.Release.Refinement.TypeRows,
    `Benitoite.Release.Refinement.TypeShiftFacts,
    `Benitoite.Release.Refinement.TypeShiftKinds,
    `Benitoite.Release.Refinement.TypeShiftTyping,
    `Benitoite.Release.Refinement.TypeVariables,
    `Benitoite.Release.Refinement.TypedFacts,
    `Benitoite.Release.Refinement.Typing,
    `Benitoite.Release.Refinement.TypingDeclared,
    `Benitoite.Release.Refinement.TypingShift,
    `Benitoite.Release.Refinement.ValueFacts
  ] do
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
  let mut single : Nat := 0
  let mut paired : Nat := 0
  for (name, expected) in [(`Benitoite.Release.Refinement.Ty, 21),
      (`List, 2), (`Benitoite.Release.Refinement.EffR, 1), (`Benitoite.Release.Refinement.Tel, 2)] do
    let some (.inductInfo info) := env.find? name | throwError "NOT_INDUCTIVE {name}"
    unless info.ctors.length == expected do throwError "BAD_CASES {name}"
    single := single + info.ctors.length
    paired := paired + info.ctors.length * info.ctors.length
    logInfo m!"CASES {name} {info.ctors.length}"
  logInfo m!"CASE_TOTAL_SINGLE {single}"
  logInfo m!"CASE_TOTAL_PAIR {paired}"

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let judgments := [`Benitoite.Release.Refinement.HasTypeVQ, `Benitoite.Release.Refinement.HasTypeCQ,
    `Benitoite.Release.Refinement.HasTypeVsQ, `Benitoite.Release.Refinement.HasTypeEachQ,
    `Benitoite.Release.Refinement.HasTypeArmsQ, `Benitoite.Release.Refinement.HasTypeClausesQ,
    `Benitoite.Release.Refinement.HasFailureClause, `Benitoite.Release.Refinement.HasTypeTelArgsQ,
    `Benitoite.Release.Refinement.TelBodyTy, `Benitoite.Release.Refinement.CaptureOk,
    `Benitoite.Release.Refinement.ClosureTy, `Benitoite.Release.Refinement.DependentClosureTy,
    `Benitoite.Release.Refinement.CheckedWitness, `Benitoite.Release.Refinement.ImageOk]
  let mut sum := 0
  for name in judgments do
    let some (.inductInfo info) := env.find? name | throwError "NOT_INDUCTIVE {name}"
    sum := sum + info.ctors.length
    logInfo m!"TYPING_CASES {name} {info.ctors.length}"
    for ctor in info.ctors do logInfo m!"TYPING_CTOR {ctor}"
  unless sum == 76 do throwError "BAD_TYPING_TOTAL {sum}"
  logInfo m!"TYPING_TOTAL {sum}"
  logInfo m!"TYPING_JUDGMENTS {judgments.length}"
