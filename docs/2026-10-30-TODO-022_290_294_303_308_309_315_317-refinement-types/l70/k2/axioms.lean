/-! run_check.py が最終入力へ接続する全環境の公理監査。
既定 import の全 Benitoite モジュールと反例の全宣言を、private・生成宣言も含めて調べる。
具体値の評価は行わない。 -/
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  let mut targets : Array Name := #[]
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      let selected := match env.getModuleIdxFor? name with
        | some idx => env.header.moduleNames[idx.toNat]!.toString.startsWith "Benitoite"
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
      logInfo m!"AUDIT_TARGET {name}"
      elabCommand (← `(#print axioms $(mkIdent name)))
  let env ← getEnv
  let modules := env.header.moduleNames.filter (·.toString.startsWith "Benitoite")
  for module in modules do
    let some idx := env.getModuleIdx? module | throwError "AUDIT_MODULE_MISSING {module}"
    let names := targets.filter fun n => env.getModuleIdxFor? n == some idx
    logInfo m!"AUDIT_MODULE {module} {names.size}"
    if auditChangedModules.contains module.toString then
      for name in names do
        logInfo m!"AUDIT_SCOPE {module} {name}"
        if auditNewModules.contains module.toString then
          let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
          logInfo m!"SIGNATURE_BEGIN {name}\n{ci.type}\nSIGNATURE_END {name}"
  for name in targets do
    if (env.getModuleIdxFor? name).isNone then
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      logInfo m!"AUDIT_LOCAL {name}"
      logInfo m!"SIGNATURE_BEGIN {name}\n{ci.type}\nSIGNATURE_END {name}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_COUNT {targets.size}"
