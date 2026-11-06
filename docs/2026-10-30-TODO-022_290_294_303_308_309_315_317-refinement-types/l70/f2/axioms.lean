/-! run_check.py が監査する証拠の後ろへ連結して監査入力を作る。
既定環境のプロジェクトの全宣言と再現の全宣言を、private・生成宣言を含めて列挙する。 -/
open Lean Elab Command in
run_cmd do
  let owned := fun (s : String) => s.startsWith "Benitoite" ||
    #["DesugarDiff", "BuiltinCheck", "CoverageDiff", "CoverageProgramDiff", "SurfaceCheck", "IntervalDiff"].any
      (s.startsWith ·)
  let mut seen : Std.HashSet Name := {}
  let mut targets : Array Name := #[]
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      let selected := match env.getModuleIdxFor? name with
        | some idx => owned env.header.moduleNames[idx.toNat]!.toString
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
  for module in env.header.moduleNames.toList.map Name.toString |>.filter owned do
    let some idx := env.getModuleIdx? module.toName | throwError "AUDIT_MODULE_MISSING {module}"
    let names := targets.filter fun n => env.getModuleIdxFor? n == some idx
    logInfo m!"AUDIT_MODULE {module} {names.size}"
  for name in targets do
    if (env.getModuleIdxFor? name).isNone then
      logInfo m!"AUDIT_LOCAL {name}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_COUNT {targets.size}"
