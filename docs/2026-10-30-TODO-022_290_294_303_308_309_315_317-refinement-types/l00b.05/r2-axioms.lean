import Lean
import Benitoite

#check Benitoite.Release.Refinement.Builtins.ExternalAssumptions.received_value
#check Benitoite.Release.Refinement.Builtins.ExternalAssumptions.receive_no_exit

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let mod := `Benitoite.Release.Refinement.ExternalConnection
  let some idx := env.getModuleIdx? mod | throwError "module not imported: {mod}"
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == some idx then some name else none).mergeSort (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
