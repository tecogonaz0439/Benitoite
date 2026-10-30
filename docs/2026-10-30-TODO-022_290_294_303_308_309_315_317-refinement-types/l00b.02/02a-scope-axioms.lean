import Lean
import Benitoite.Release.Refinement.ScopeSyntax

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let some moduleIdx := env.getModuleIdx? `Benitoite.Release.Refinement.ScopeSyntax
    | throwError "ScopeSyntax module not found"
  let names := env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == some moduleIdx then some name else none
  let names := names.mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"scope declarations: {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
