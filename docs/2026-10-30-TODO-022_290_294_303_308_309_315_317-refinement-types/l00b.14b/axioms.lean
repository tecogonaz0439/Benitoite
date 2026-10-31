import Lean
import Benitoite

set_option maxHeartbeats 2000000
set_option pp.universes true
set_option pp.fullNames true

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [`Benitoite.Release.Refinement.Adequate,
      `Benitoite.Release.Refinement.Admissible,
      `Benitoite.Release.Refinement.AdmissibleMap,
      `Benitoite.Release.Refinement.ApproxAdapter,
      `Benitoite.Release.Refinement.AtContracts,
      `Benitoite.Release.Refinement.AtInput,
      `Benitoite.Release.Refinement.AtPatterns,
      `Benitoite.Release.Refinement.AtPrepare,
      `Benitoite.Release.Refinement.AtSound,
      `Benitoite.Release.Refinement.AtTyping,
      `Benitoite.Release.Refinement.AtomOrder,
      `Benitoite.Release.Refinement.Atoms,
      `Benitoite.Release.Refinement.Basic,
      `Benitoite.Release.Refinement.Bind,
      `Benitoite.Release.Refinement.BindCongr,
      `Benitoite.Release.Refinement.BindingShift,
      `Benitoite.Release.Refinement.BuilderExec,
      `Benitoite.Release.Refinement.BuiltinResponse,
      `Benitoite.Release.Refinement.Canonical,
      `Benitoite.Release.Refinement.Capture,
      `Benitoite.Release.Refinement.CapturedFacts,
      `Benitoite.Release.Refinement.Carrier,
      `Benitoite.Release.Refinement.Certificate,
      `Benitoite.Release.Refinement.ClosedDecidable,
      `Benitoite.Release.Refinement.ClosedEvaluation,
      `Benitoite.Release.Refinement.ClosedKeys,
      `Benitoite.Release.Refinement.ClosureTyping,
      `Benitoite.Release.Refinement.Codes,
      `Benitoite.Release.Refinement.Conjunction,
      `Benitoite.Release.Refinement.ConstraintAssumptions,
      `Benitoite.Release.Refinement.Context.Capture,
      `Benitoite.Release.Refinement.Context.Declarations,
      `Benitoite.Release.Refinement.Context.Facts,
      `Benitoite.Release.Refinement.Context.WF,
      `Benitoite.Release.Refinement.Context,
      `Benitoite.Release.Refinement.ContextFacts,
      `Benitoite.Release.Refinement.ContextMap,
      `Benitoite.Release.Refinement.Declared,
      `Benitoite.Release.Refinement.DeclaredTransport,
      `Benitoite.Release.Refinement.DependentBeta,
      `Benitoite.Release.Refinement.EffectCover,
      `Benitoite.Release.Refinement.Embedding,
      `Benitoite.Release.Refinement.Exchange,
      `Benitoite.Release.Refinement.External,
      `Benitoite.Release.Refinement.ExternalCheck,
      `Benitoite.Release.Refinement.ExternalConnection,
      `Benitoite.Release.Refinement.ExternalObservation,
      `Benitoite.Release.Refinement.ExternalResponse,
      `Benitoite.Release.Refinement.FunctionNormalForm,
      `Benitoite.Release.Refinement.Ground,
      `Benitoite.Release.Refinement.HandlerAlgebra,
      `Benitoite.Release.Refinement.HandlerContracts,
      `Benitoite.Release.Refinement.HandlerTyping,
      `Benitoite.Release.Refinement.HeldValues,
      `Benitoite.Release.Refinement.InversionCore,
      `Benitoite.Release.Refinement.KindInference,
      `Benitoite.Release.Refinement.KindValues,
      `Benitoite.Release.Refinement.Kinds,
      `Benitoite.Release.Refinement.Le,
      `Benitoite.Release.Refinement.LocalResolve,
      `Benitoite.Release.Refinement.LocalResolveLemmas,
      `Benitoite.Release.Refinement.LocalTransport,
      `Benitoite.Release.Refinement.Logic,
      `Benitoite.Release.Refinement.LogicSound,
      `Benitoite.Release.Refinement.MethodArguments,
      `Benitoite.Release.Refinement.ModelHttp,
      `Benitoite.Release.Refinement.Narrowing,
      `Benitoite.Release.Refinement.NarrowingObstruction,
      `Benitoite.Release.Refinement.NormalWellFormed,
      `Benitoite.Release.Refinement.NormalizationLogic,
      `Benitoite.Release.Refinement.Normalize,
      `Benitoite.Release.Refinement.NormalizedApplication,
      `Benitoite.Release.Refinement.Observation,
      `Benitoite.Release.Refinement.OpenSubstitution,
      `Benitoite.Release.Refinement.Order,
      `Benitoite.Release.Refinement.PathResolution,
      `Benitoite.Release.Refinement.PatternSemantics,
      `Benitoite.Release.Refinement.PatternTransport,
      `Benitoite.Release.Refinement.PatternTypeShift,
      `Benitoite.Release.Refinement.Patterns,
      `Benitoite.Release.Refinement.Preparation,
      `Benitoite.Release.Refinement.RangeExchange,
      `Benitoite.Release.Refinement.RangeSubst,
      `Benitoite.Release.Refinement.RawBindingShift,
      `Benitoite.Release.Refinement.RefinementNormalForm,
      `Benitoite.Release.Refinement.RuntimeMatch,
      `Benitoite.Release.Refinement.RuntimeSyntax,
      `Benitoite.Release.Refinement.ScopeSyntax,
      `Benitoite.Release.Refinement.Semantics,
      `Benitoite.Release.Refinement.Shift,
      `Benitoite.Release.Refinement.ShiftCancellation,
      `Benitoite.Release.Refinement.ShiftOrder,
      `Benitoite.Release.Refinement.Source,
      `Benitoite.Release.Refinement.StateTyping,
      `Benitoite.Release.Refinement.Step,
      `Benitoite.Release.Refinement.StoreTransport,
      `Benitoite.Release.Refinement.Subst,
      `Benitoite.Release.Refinement.SubstTyping,
      `Benitoite.Release.Refinement.SubstTypingObstruction,
      `Benitoite.Release.Refinement.SubstitutionContracts,
      `Benitoite.Release.Refinement.Syntax,
      `Benitoite.Release.Refinement.TargetTable,
      `Benitoite.Release.Refinement.TelArguments,
      `Benitoite.Release.Refinement.TelTyping,
      `Benitoite.Release.Refinement.Telescope,
      `Benitoite.Release.Refinement.TermSyntax,
      `Benitoite.Release.Refinement.Transport,
      `Benitoite.Release.Refinement.TypeRenaming,
      `Benitoite.Release.Refinement.TypeShiftAlgebra,
      `Benitoite.Release.Refinement.TypeShiftContext,
      `Benitoite.Release.Refinement.TypeShiftContracts,
      `Benitoite.Release.Refinement.TypeShiftExchange,
      `Benitoite.Release.Refinement.TypeShiftKinds,
      `Benitoite.Release.Refinement.TypeShiftOrder,
      `Benitoite.Release.Refinement.TypeShiftSyntax,
      `Benitoite.Release.Refinement.TypeShiftTyping,
      `Benitoite.Release.Refinement.TypeSubst,
      `Benitoite.Release.Refinement.TypedFacts,
      `Benitoite.Release.Refinement.Types,
      `Benitoite.Release.Refinement.Typing,
      `Benitoite.Release.Refinement.TypingDeclared,
      `Benitoite.Release.Refinement.TypingShift,
      `Benitoite.Release.Refinement.TypingStore,
      `Benitoite.Release.Refinement.ValueBinding,
      `Benitoite.Release.Refinement.ValueClosed,
      `Benitoite.Release.Refinement.ValueExchange,
      `Benitoite.Release.Refinement.ValueFacts,
      `Benitoite.Release.Refinement.ValueInstantiation,
      `Benitoite.Release.Refinement.ValueReferences,
      `Benitoite.Release.Refinement.ValueRegularity,
      `Benitoite.Release.Refinement.ValueRenameAlgebra,
      `Benitoite.Release.Refinement.ValueRenamingSyntax,
      `Benitoite.Release.Refinement.ValueShiftOrder,
      `Benitoite.Release.Refinement.ValueShiftSyntax,
      `Benitoite.Release.Refinement.ValueSubst,
      `Benitoite] do
    match env.getModuleIdx? mod with
    | none => throwError "AUDIT_UNAVAILABLE {mod}"
    | some idx =>
      logInfo m!"AUDIT_MODULE {mod}"
      let names := (env.constants.toList.filterMap fun (name, _) =>
        if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
          (fun a b => a.toString < b.toString)
      for name in names do
        elabCommand (← `(#print axioms $(mkIdent name)))

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let expected := [(`Benitoite.Release.Refinement.Ty,21),
    (`Benitoite.Release.Refinement.Ty.LeQ,13),
    (`Benitoite.Release.Refinement.TelLe,2), (`Benitoite.Release.Refinement.TelClosure,2),
    (`Benitoite.Release.Refinement.HasTypeVQ,29), (`Benitoite.Release.Refinement.HasTypeCQ,24),
    (`Benitoite.Release.Refinement.ImageOk,4), (`Benitoite.Release.Refinement.LocalRef.HasKind,3),
    (`Benitoite.Release.Refinement.ProperApply,7), (`Benitoite.Release.Refinement.Step,76),
    (`Benitoite.Release.Refinement.ContTy,10), (`Benitoite.Release.Refinement.Frame,7)]
  for (name,n) in expected do
    let some (.inductInfo info) := env.find? name | throwError "not inductive: {name}"
    unless info.ctors.length == n do throwError "case count changed: {name}"
    logInfo m!"cases {name}: {info.ctors.length}"
  let mut total := 0
  for name in [`Benitoite.Release.Refinement.HasTypeVQ, `Benitoite.Release.Refinement.HasTypeCQ,
      `Benitoite.Release.Refinement.HasTypeVsQ, `Benitoite.Release.Refinement.HasTypeEachQ,
      `Benitoite.Release.Refinement.HasTypeArmsQ, `Benitoite.Release.Refinement.HasTypeClausesQ,
      `Benitoite.Release.Refinement.HasFailureClause, `Benitoite.Release.Refinement.HasTypeTelArgsQ,
      `Benitoite.Release.Refinement.TelBodyTy, `Benitoite.Release.Refinement.CaptureOk,
      `Benitoite.Release.Refinement.ClosureTy, `Benitoite.Release.Refinement.DependentClosureTy,
      `Benitoite.Release.Refinement.CheckedWitness, `Benitoite.Release.Refinement.ImageOk] do
    let some (.inductInfo info) := env.find? name | throwError "not inductive: {name}"
    total := total + info.ctors.length
  unless total == 76 do throwError "three-family case count: {total}"
  logInfo m!"THREE_FAMILY_CASES {total} (71 + 5)"

#print axioms Benitoite.Release.Model.assumptions
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.Ty.le_iff_leOld
#print axioms Benitoite.Release.Ty.wf_iff_old
#print axioms Benitoite.Release.Ty.varsIn_iff_old
#print axioms Benitoite.Release.Eff.covers_iff_sub_old
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for name in [`Benitoite.Release.Ty, `Benitoite.Release.Val,
      `Benitoite.Release.Refinement.Const, `Benitoite.Release.Refinement.RangeIx,
      `Benitoite.Release.Refinement.HasTypeEachQ, `Benitoite.Release.Refinement.HasTypeVsQ,
      `Benitoite.Release.Refinement.CheckedWitness] do
    let some (.inductInfo info) := env.find? name | throwError "not inductive: {name}"
    logInfo m!"cases {name}: {info.ctors.length}"
