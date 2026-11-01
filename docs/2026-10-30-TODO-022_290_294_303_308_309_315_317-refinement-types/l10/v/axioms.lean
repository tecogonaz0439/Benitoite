import Lean
import Benitoite

set_option maxHeartbeats 4000000

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
      `Benitoite.Release.Refinement.Canonical,
      `Benitoite.Release.Refinement.ContextMap,
      `Benitoite.Release.Refinement.Declared,
      `Benitoite.Release.Refinement.DeclaredTransport,
      `Benitoite.Release.Refinement.DependentBeta,
      `Benitoite.Release.Refinement.Embedding,
      `Benitoite.Release.Refinement.ExternalCheck,
      `Benitoite.Release.Refinement.HandlerCalls,
      `Benitoite.Release.Refinement.HandlerContinuation,
      `Benitoite.Release.Refinement.HandlerPreservation,
      `Benitoite.Release.Refinement.HeldValues,
      `Benitoite.Release.Refinement.InversionCore,
      `Benitoite.Release.Refinement.LazyInversion,
      `Benitoite.Release.Refinement.LazyPreservation,
      `Benitoite.Release.Refinement.LazyStore,
      `Benitoite.Release.Refinement.Le,
      `Benitoite.Release.Refinement.MatchFacts,
      `Benitoite.Release.Refinement.MatchPaths,
      `Benitoite.Release.Refinement.Narrowing,
      `Benitoite.Release.Refinement.NarrowingObstruction,
      `Benitoite.Release.Refinement.ObservationType,
      `Benitoite.Release.Refinement.OpenSubstitution,
      `Benitoite.Release.Refinement.PathConditions,
      `Benitoite.Release.Refinement.RangeSubst,
      `Benitoite.Release.Refinement.ReferenceCalls,
      `Benitoite.Release.Refinement.Shift,
      `Benitoite.Release.Refinement.StateTyping,
      `Benitoite.Release.Refinement.SubstTypingObstruction,
      `Benitoite.Release.Refinement.Syntax,
      `Benitoite.Release.Refinement.Telescope,
      `Benitoite.Release.Refinement.Transport,
      `Benitoite.Release.Refinement.TypeFormation,
      `Benitoite.Release.Refinement.TypeShiftContext,
      `Benitoite.Release.Refinement.TypeShiftContracts,
      `Benitoite.Release.Refinement.TypeSubst,
      `Benitoite.Release.Refinement.TypedFacts,
      `Benitoite.Release.Refinement.Typing,
      `Benitoite.Release.Refinement.TypingDeclared,
      `Benitoite.Release.Refinement.TypingShift,
      `Benitoite.Release.Refinement.ValueFacts,
      `Benitoite.Release.Refinement.ValueSubst,
      `Benitoite.Release.Refinement.VarianceFormation,
      `Benitoite.Release.Refinement.VarianceSyntax,
      `Benitoite.Release.Refinement.VarianceTransport,
      `Benitoite.Release.Refinement.VarianceValidation,
      `Benitoite,
      `Benitoite.Release.Refinement.TypeShiftTyping,
      `Benitoite.Release.Refinement.SubstTyping] do
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
  let names := [`Benitoite.Release.Refinement.Ty.LeQ, `Benitoite.Release.Refinement.TelLe,
    `Benitoite.Release.Refinement.TelClosure, `Benitoite.Release.Refinement.TypeArgsLe]
  let mut total := 0
  for name in names do
    let some (.inductInfo info) := env.find? name | throwError "NOT_INDUCTIVE {name}"
    total := total + info.ctors.length
    logInfo m!"SUBTYPE_CASES {name} {info.ctors.length}"
    for ctor in info.ctors do logInfo m!"SUBTYPE_CTOR {ctor}"
  unless total == 22 do throwError "BAD_SUBTYPE_TOTAL {total}"
  logInfo m!"SUBTYPE_TOTAL {total}"
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
