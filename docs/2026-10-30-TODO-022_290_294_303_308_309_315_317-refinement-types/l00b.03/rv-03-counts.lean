import Lean
import Benitoite.Release.Refinement.Context.Capture
open Lean in
run_cmd do
  let env ← getEnv
  for n in [`Benitoite.Release.Refinement.Pred, `Benitoite.Release.Refinement.Ty, `Benitoite.Release.Refinement.Tel, `Benitoite.Release.Refinement.Step, `Benitoite.Release.Refinement.ImageOk, `Benitoite.Release.Refinement.CaptureOk] do
    if let some (.inductInfo i) := env.find? n then
      logInfo m!"{n} {i.ctors.length}"
