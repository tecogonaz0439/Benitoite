import Lean
import Benitoite
set_option maxHeartbeats 20000000

-- 既定の新旧全モジュールを保持し、private・生成宣言も所属モジュールから列挙する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let constants := env.constants.toList
  let mut targets : List Name := []
  for mod in env.header.moduleNames do
    if mod.toString.startsWith "Benitoite" then
      let some idx := env.getModuleIdx? mod | throwError "AUDIT_MODULE_MISSING {mod}"
      let names := constants.filterMap fun (name, _) =>
        if env.getModuleIdxFor? name == some idx then some name else none
      logInfo m!"AUDIT_MODULE {mod} {names.length}"
      targets := names ++ targets
  let required := [``Benitoite.Release.progress, ``Benitoite.Release.preservation,
    ``Benitoite.Release.step_sound, ``Benitoite.Release.effect_soundness,
    ``Benitoite.Release.effect_soundness_noLamNames, ``Benitoite.Release.Model.assumptions,
    ``Benitoite.Release.ModelTargets.assumptions, ``Benitoite.Release.ModelHttp.assumptions,
    ``Benitoite.Release.Refinement.HasTypeVQ.subst,
    ``Benitoite.Release.Refinement.HasTypeVQ.subst_under_none,
    ``Benitoite.Release.Refinement.HasTypeVQ.shift_values,
    ``Benitoite.Release.Refinement.HasTypeVQ.shift_types,
    ``Benitoite.Release.Refinement.HasTypeVQ.narrow,
    ``Benitoite.Release.Refinement.HasTypeCQ.subst,
    ``Benitoite.Release.Refinement.HasTypeCQ.subst_under_none,
    ``Benitoite.Release.Refinement.HasTypeCQ.shift_values,
    ``Benitoite.Release.Refinement.HasTypeCQ.shift_types,
    ``Benitoite.Release.Refinement.HasTypeCQ.narrow]
  for name in required do
    unless targets.contains name do throwError "AUDIT_REQUIRED_MISSING {name}"
  let ordered := targets.mergeSort (fun a b => a.toString < b.toString)
  let mut seen : Std.HashSet Name := {}
  let inventoryOnly := (← IO.getEnv "L30_INVENTORY_ONLY") == some "1"
  for name in ordered do
    if seen.contains name then throwError "AUDIT_DUPLICATE {name}"
    seen := seen.insert name
    let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
    if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
    logInfo m!"AUDIT_TARGET {name}"
    unless inventoryOnly do elabCommand (← `(#print axioms $(mkIdent name)))
  if let some output ← IO.getEnv "L30_AUDIT_TARGETS" then
    IO.FS.writeFile output (String.intercalate "\n" (ordered.map Name.toString) ++ "\n")
