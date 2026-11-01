import Lean
import Benitoite.Release.Refinement.HandlerOperation
open Lean Elab Command
run_cmd do
  let env ← getEnv
  for n in [`Benitoite.Release.Refinement.ContTy,`Benitoite.Release.Refinement.HasTypeVQ,`Benitoite.Release.Refinement.HasTypeCQ,`Benitoite.Release.Refinement.HasTypeArmsQ,`Benitoite.Release.Refinement.HasTypeClausesQ,`Benitoite.Release.Refinement.HasTypeTelArgsQ,`Benitoite.Release.Refinement.Step,`Benitoite.Release.Refinement.GuardBodyTy] do
    match env.find? n with
    | some (.inductInfo i) => logInfo m!"{n} {i.ctors.length} all={i.all.length}"
    | _ => logInfo m!"{n} ?"
