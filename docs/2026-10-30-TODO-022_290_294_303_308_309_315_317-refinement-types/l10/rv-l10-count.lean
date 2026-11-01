import Benitoite
open Lean Elab Command Benitoite.Release.Refinement
def cnt (n : Name) : CommandElabM Nat := do
  let env ← getEnv
  match env.find? n with
  | some (.inductInfo i) => return i.ctors.length
  | _ => return 0
elab "#cnt " ids:ident* : command => do
  for i in ids do
    let n ← liftCoreM (realizeGlobalConstNoOverloadWithInfo i)
    logInfo m!"{n}: {← cnt n}"
open Benitoite.Release.Refinement in
#cnt Ty EffR Tel HasTypeVQ HasTypeVsQ HasTypeEachQ HasTypeCQ HasTypeArmsQ HasTypeClausesQ Ty.LeQ TelLe TelClosure Step ContTy CellOk Inhabits
