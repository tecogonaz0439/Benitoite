import Lean
import Benitoite
open Lean Elab Command Meta
namespace Benitoite.Release.Refinement
elab "#ctorcount " ids:ident* : command => do
  let env ← getEnv
  let mut total := 0
  for i in ids do
    let n := `Benitoite.Release.Refinement ++ i.getId
    match env.find? n with
    | some (.inductInfo v) =>
      logInfo m!"{i.getId}: {v.ctors.length} ctors, mutual={v.all.length}"
      total := total + v.ctors.length
    | _ => logInfo m!"{i.getId}: not found"
  logInfo m!"total={total}"
#ctorcount HasTypeVQ HasTypeVsQ HasTypeEachQ HasTypeCQ HasTypeTelArgsQ TelBodyTy CaptureOk DependentClosureTy CheckedWitness AtCallAdmissible HasTypeArmsQ HasTypeClausesQ HasFailureClause ImageOk
#ctorcount ClosureTy
#ctorcount ContTy Step Frame Cell LocTy State
#check @ClosureTy.mk
end Benitoite.Release.Refinement
