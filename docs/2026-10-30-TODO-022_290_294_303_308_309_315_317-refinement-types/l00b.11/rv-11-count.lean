import Lean
import Benitoite
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for n in [`Benitoite.Release.Refinement.HasTypeVQ,`Benitoite.Release.Refinement.HasTypeCQ,`Benitoite.Release.Refinement.ImageOk,`Benitoite.Release.Refinement.Ty.LeQ,`Benitoite.Release.Refinement.LocalRef.HasKind,`Benitoite.Release.Refinement.ProperApply,`Benitoite.Release.Refinement.TelLe,`Benitoite.Release.Refinement.TelClosure] do
    match env.find? n with
    | some (.inductInfo i) => logInfo m!"{n}: {i.ctors.length} {i.all.length}"
    | _ => logInfo m!"{n}: none"
