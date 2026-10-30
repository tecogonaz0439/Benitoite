import Lean
import Benitoite.Release.Refinement.ValueRegularity

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [`Benitoite.Release.Refinement.ScopeSyntax,
      `Benitoite.Release.Refinement.Context,
      `Benitoite.Release.Refinement.ValueRegularity] do
    let some moduleIdx := env.getModuleIdx? mod
      | throwError "module not found: {mod}"
    let names := env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some moduleIdx then some name else none
    let names := names.mergeSort (fun a b => a.toString < b.toString)
    logInfo m!"module: {mod}, declarations: {names.length}"
    for name in names do
      elabCommand (← `(#print axioms $(mkIdent name)))
