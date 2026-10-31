import Lean
import Benitoite
open Lean Benitoite.Release.Refinement
run_cmd do
  let env ← getEnv
  for n in [`HasTypeVQ,`HasTypeCQ,`HasTypeVsQ,`HasTypeEachQ,`HasTypeTelArgsQ,`HasTypeArmsQ,`HasTypeClausesQ,`HasFailureClause,`CheckedWitness,`ImageOk,`TelBodyTy,`CaptureOk,`ClosureTy,`DependentClosureTy,`OpenCodeTy,`OpenArmsTy,`AtCallAdmissible,`ContTy,`Step,`Frame,`Cell,`State,`LocTy,`Comp,`Val] do
    let full := `Benitoite.Release.Refinement ++ n
    match env.find? full with
    | some (.inductInfo i) => logInfo m!"{n} {i.ctors.length} all={i.all.length}"
    | _ => logInfo m!"{n} ?"
