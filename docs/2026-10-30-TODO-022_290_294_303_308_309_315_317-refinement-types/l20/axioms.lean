import Lean
import Benitoite
set_option maxHeartbeats 4000000

-- formal/ から実行する。固定の新旧 import を保持して環境から対象を列挙する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let constants := env.constants.toList
  let mut targets : List Name := []
  for mod in env.header.moduleNames do
    let n := mod.toString
    if n.startsWith "Benitoite.Release.Refinement." || n.startsWith "Benitoite.Shared." then
      let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
      let names := constants.filterMap fun (name, _) =>
        if env.getModuleIdxFor? name == some idx then some name else none
      targets := names ++ targets
  targets := targets ++ [``Benitoite.Release.progress, ``Benitoite.Release.preservation,
    ``Benitoite.Release.step_sound, ``Benitoite.Release.effect_soundness,
    ``Benitoite.Release.effect_soundness_noLamNames, ``Benitoite.Release.Model.assumptions,
    ``Benitoite.Release.ModelTargets.assumptions, ``Benitoite.Release.ModelHttp.assumptions]
  let ordered := targets.mergeSort (fun a b => a.toString < b.toString)
  let mut seen : Std.HashSet Name := {}
  for name in ordered do
    if seen.contains name then throwError "AUDIT_DUPLICATE {name}"
    seen := seen.insert name
    let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
    if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
    elabCommand (← `(#print axioms $(mkIdent name)))
  if let some output ← IO.getEnv "L20_AUDIT_TARGETS" then
    IO.FS.writeFile output (String.intercalate "\n" (ordered.map Name.toString) ++ "\n")
