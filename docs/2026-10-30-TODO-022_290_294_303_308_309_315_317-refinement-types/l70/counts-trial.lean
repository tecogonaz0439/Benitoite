import Benitoite
open Lean Meta Elab Command

def ctorCount (n : Name) : CommandElabM Unit := do
  let env ← getEnv
  match env.find? n with
  | some (.inductInfo i) => logInfo m!"{n}: {i.ctors.length}"
  | _ => logInfo m!"{n}: not inductive"

run_cmd do
  for n in [``Benitoite.Release.Refinement.Step, ``Benitoite.Release.Refinement.HasTypeVQ,
      ``Benitoite.Release.Refinement.HasTypeVsQ, ``Benitoite.Release.Refinement.HasTypeEachQ,
      ``Benitoite.Release.Refinement.HasTypeCQ, ``Benitoite.Release.Refinement.HasTypeTelArgsQ,
      ``Benitoite.Release.Refinement.TelBodyTy, ``Benitoite.Release.Refinement.CaptureOk,
      ``Benitoite.Release.Refinement.DependentClosureTy, ``Benitoite.Release.Refinement.CheckedWitness,
      ``Benitoite.Release.Refinement.AtCallAdmissible, ``Benitoite.Release.Refinement.HasTypeArmsQ,
      ``Benitoite.Release.Refinement.HasTypeClausesQ, ``Benitoite.Release.Refinement.HasFailureClause,
      ``Benitoite.Release.Refinement.ImageOk, ``Benitoite.Release.Refinement.ContTy,
      ``Benitoite.Release.Refinement.Ty, ``Benitoite.Release.Refinement.Val, ``Benitoite.Release.Refinement.Comp,
      ``Benitoite.Release.Refinement.Term, ``Benitoite.Release.Refinement.Pred,
      ``Benitoite.Release.Refinement.Frame, ``Benitoite.Release.Refinement.State,
      ``Benitoite.Release.Refinement.Ty.LeQ, ``Benitoite.Release.Refinement.Eff.Covers,
      ``Benitoite.Release.Refinement.PatTy, ``Benitoite.Release.Refinement.Inhabits,
      ``Benitoite.Surface.Expr, ``Benitoite.Surface.Exprs, ``Benitoite.Surface.HoleArgs,
      ``Benitoite.Surface.Arms, ``Benitoite.Surface.Clauses, ``Benitoite.Surface.Block,
      ``Benitoite.Surface.Literal, ``Benitoite.Surface.Pattern,
      ``Benitoite.Surface.HasTypeQ, ``Benitoite.Surface.HasTypesQ, ``Benitoite.Surface.HasEachQ,
      ``Benitoite.Surface.HasHoleArgsQ, ``Benitoite.Surface.HasArmsQ, ``Benitoite.Surface.HasClausesQ,
      ``Benitoite.Surface.HasBlockQ, ``Benitoite.Surface.DictEv.HasType,
      ``Benitoite.Release.Step, ``Benitoite.Release.CoverageWitness,
      ``Benitoite.Exchange.Expr, ``Benitoite.Exchange.Ty, ``Benitoite.Exchange.Comp, ``Benitoite.Exchange.Val] do
    ctorCount n
