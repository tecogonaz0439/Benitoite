import Benitoite
open Lean Elab Command
def count (n : Name) : CommandElabM Unit := do
  let env ← getEnv
  match env.find? n with
  | some (.inductInfo i) => logInfo m!"{n} {i.ctors.length}"
  | _ => logInfo m!"{n} ?"
open Benitoite.Release.Refinement in
run_cmd do
  for n in [``HasTypeVQ,``HasTypeCQ,``HasTypeVsQ,``HasTypeEachQ,``HasTypeTelArgsQ,``HasTypeArmsQ,``HasTypeClausesQ,``HasFailureClause,``CheckedWitness,``ImageOk,``TelBodyTy,``CaptureOk,``ClosureTy,``DependentClosureTy,``ContTy,``Benitoite.Release.Refinement.Step,``Frame,``Cell,``Benitoite.Release.Refinement.State,``LocTy,``Val,``Comp,``AtCallAdmissible] do
    count n
