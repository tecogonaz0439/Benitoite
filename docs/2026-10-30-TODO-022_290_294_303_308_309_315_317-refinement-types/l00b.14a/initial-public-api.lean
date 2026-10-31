import Lean
import Benitoite
set_option pp.universes true
set_option pp.fullNames true
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let some idx := env.getModuleIdx? `Benitoite.Release.Refinement.DependentBeta
    | throwError "new module is not in default imports"
  let names := [`Benitoite.Release.Refinement.HasTypeCQ.open_one,
    `Benitoite.Release.Refinement.Capture.empty_closeTel,
    `Benitoite.Release.Refinement.Capture.instantiate_one,
    `Benitoite.Release.Refinement.HasTypeTelArgsQ.one,
    `Benitoite.Release.Refinement.ClosureTy.dependent_one,
    `Benitoite.Release.Refinement.ContTy.markPush,
    `Benitoite.Release.Refinement.StateTyE.dependent_beta_one,
    `Benitoite.Release.Refinement.StateTy.dependent_beta_one,
    `Benitoite.Release.Refinement.HasTypeCQ.ret_value,
    `Benitoite.Release.Refinement.Builtins.ExternalAssumptions.received_facts]
  for name in names do
    unless env.getModuleIdxFor? name == some idx do
      throwError "public declaration unavailable: {name}"
  logInfo m!"PUBLIC_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#check $(mkIdent name)))
