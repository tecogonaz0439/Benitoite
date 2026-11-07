import Benitoite
import Lean

/-! 既定環境と確認用入力の全宣言を、印字が実体化する生成宣言も含めて監査する。 -/
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let modules := env.header.moduleNames.toList.filter fun n => n.toString.startsWith "Benitoite"
  let mut seen : Std.HashSet Name := {}
  let mut targets : Array Name := #[]
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      let selected := match env.getModuleIdxFor? name with
        | some idx => modules.contains env.header.moduleNames[idx.toNat]!
        | none => true
      if selected && !seen.contains name then some name else none
    if pending.isEmpty then break
    if rounds > 20 then throwError "AUDIT_FIXED_POINT_LIMIT"
    for name in pending.mergeSort (fun a b => a.toString < b.toString) do
      let env ← getEnv
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
      seen := seen.insert name
      targets := targets.push name
      let module := match env.getModuleIdxFor? name with
        | some idx => env.header.moduleNames[idx.toNat]!.toString
        | none => "local_input"
      logInfo m!"AUDIT_TARGET {module} {name}"
      elabCommand (← `(#print axioms $(mkIdent name)))
  let env ← getEnv
  for module in modules do
    let some idx := env.getModuleIdx? module | throwError "AUDIT_MODULE_MISSING {module}"
    let names := targets.filter fun n => env.getModuleIdxFor? n == some idx
    logInfo m!"AUDIT_MODULE {module} {names.size}"
  let localNames := targets.filter fun n => (env.getModuleIdxFor? n).isNone
  for name in localNames do
    let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
    let kind := match ci with
      | .thmInfo _ => "theorem" | .defnInfo _ => "definition" | .opaqueInfo _ => "opaque"
      | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor" | .recInfo _ => "recursor"
      | .quotInfo _ => "quotient" | .axiomInfo _ => "axiom"
    logInfo m!"OWN_DECL {kind} {name}"
  logInfo m!"OWN_COUNT {localNames.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_COUNT {targets.size}"
