import Lean
import Benitoite

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, expected) in [
      (`Benitoite.Release.Refinement.«Sort», 14),
      (`Benitoite.Release.Refinement.Term, 20),
      (`Benitoite.Release.Refinement.Pred, 14),
      (`Benitoite.Release.Refinement.Ty, 21),
      (`Benitoite.Release.Refinement.Tel, 2),
      (`Benitoite.Release.Refinement.Atom, 2),
      (`Benitoite.Release.Refinement.RangeExpr, 3),
      (`Benitoite.Release.Refinement.RangeIx, 2),
      (`Benitoite.Release.Refinement.Const, 16),
      (`Benitoite.Release.Refinement.PathBase, 5),
      (`Benitoite.Release.Refinement.PathEnv, 1),
      (`Benitoite.Release.Refinement.TargetInput, 2),
      (`Benitoite.Release.Refinement.AtFailure, 7),
      (`Benitoite.Release.Refinement.AtError, 1),
      (`Benitoite.Release.Refinement.ExternalId, 1),
      (`Benitoite.Release.Refinement.ComponentId, 1),
      (`Benitoite.Release.Refinement.ExternalFunctionId, 1),
      (`Benitoite.Release.Refinement.FieldRef, 1),
      (`Benitoite.Release.Refinement.Measure, 7),
      (`Benitoite.Release.Refinement.Comparison, 6),
      (`Benitoite.Release.Refinement.FloatClass, 6),
      (`Benitoite.Release.Refinement.FloatWidth, 2),
      (`Benitoite.Release.Refinement.TyKind, 2),
      (`Benitoite.Release.Refinement.ProperApply, 7),
      (`Benitoite.Release.Refinement.Term.HasData, 3),
      (`Benitoite.Release.Refinement.Ty.LeQ, 12),
      (`Benitoite.Release.Refinement.TelLe, 2),
      (`Benitoite.Release.Refinement.TelClosure, 2),
      (`Benitoite.Release.Refinement.HasTypeVQ, 6),
      (`Benitoite.Release.Refinement.HasTypeCQ, 5),
      (`Benitoite.Release.Refinement.HasTypeVsQ, 2),
      (`Benitoite.Release.Refinement.HasTypeEachQ, 2),
      (`Benitoite.Release.Refinement.Val, 17),
      (`Benitoite.Release.Refinement.Comp, 13),
      (`Benitoite.Release.Refinement.Arm, 1),
      (`Benitoite.Release.Refinement.Clause, 2)] do
    let some (.inductInfo info) := env.find? name
      | throwError "not an inductive type: {name}"
    unless info.ctors.length == expected do
      throwError "constructor count mismatch: {name}, expected {expected}, actual {info.ctors.length}"
    logInfo m!"CONSTRUCTORS {name}: {info.ctors.length}: {info.ctors}"
  for mod in [
      `Benitoite.Release.Refinement.AtomOrder,
      `Benitoite.Release.Refinement.Atoms,
      `Benitoite.Release.Refinement.Basic,
      `Benitoite.Release.Refinement.Bind,
      `Benitoite.Release.Refinement.BindCongr,
      `Benitoite.Release.Refinement.BindingShift,
      `Benitoite.Release.Refinement.Codes,
      `Benitoite.Release.Refinement.Context,
      `Benitoite.Release.Refinement.ContextFacts,
      `Benitoite.Release.Refinement.ContextMap,
      `Benitoite.Release.Refinement.Declared,
      `Benitoite.Release.Refinement.DeclaredTransport,
      `Benitoite.Release.Refinement.EffectCover,
      `Benitoite.Release.Refinement.Exchange,
      `Benitoite.Release.Refinement.KindInference,
      `Benitoite.Release.Refinement.Kinds,
      `Benitoite.Release.Refinement.Le,
      `Benitoite.Release.Refinement.Logic,
      `Benitoite.Release.Refinement.Narrowing,
      `Benitoite.Release.Refinement.NarrowingObstruction,
      `Benitoite.Release.Refinement.Normalize,
      `Benitoite.Release.Refinement.OpenSubstitution,
      `Benitoite.Release.Refinement.Order,
      `Benitoite.Release.Refinement.RangeExchange,
      `Benitoite.Release.Refinement.RangeSubst,
      `Benitoite.Release.Refinement.ScopeSyntax,
      `Benitoite.Release.Refinement.Shift,
      `Benitoite.Release.Refinement.ShiftOrder,
      `Benitoite.Release.Refinement.Subst,
      `Benitoite.Release.Refinement.SubstTyping,
      `Benitoite.Release.Refinement.SubstTypingObstruction,
      `Benitoite.Release.Refinement.Syntax,
      `Benitoite.Release.Refinement.Telescope,
      `Benitoite.Release.Refinement.TermSyntax,
      `Benitoite.Release.Refinement.Transport,
      `Benitoite.Release.Refinement.TypeSubst,
      `Benitoite.Release.Refinement.TypedFacts,
      `Benitoite.Release.Refinement.Types,
      `Benitoite.Release.Refinement.Typing,
      `Benitoite.Release.Refinement.TypingShift,
      `Benitoite.Release.Refinement.ValueBinding,
      `Benitoite.Release.Refinement.ValueClosed,
      `Benitoite.Release.Refinement.ValueExchange,
      `Benitoite.Release.Refinement.ValueReferences,
      `Benitoite.Release.Refinement.ValueRegularity,
      `Benitoite.Release.Refinement.ValueSubst] do
    let some moduleIdx := env.getModuleIdx? mod
      | throwError "module not imported by default: {mod}"
    let names := env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some moduleIdx then some name else none
    let names := names.mergeSort (fun a b => a.toString < b.toString)
    logInfo m!"MODULE {mod}: {names.length}"
    for name in names do
      elabCommand (← `(#print axioms $(mkIdent name)))
