import Lean
import Benitoite
set_option pp.fullNames true
set_option pp.proofs true
set_option pp.maxSteps 1000000
set_option pp.deepTerms.threshold 1000000

/-! 群 C の公理監査。群で足したモジュールと、群で変えたモジュールの全宣言（private と、
印字時に実体化する生成宣言を含む）を所属モジュールから数え、`#print axioms` で調べる。
対象のモジュールは `audit-modules.json`（`verify.py` が git の差分から作り直して照合する）から読む。
必須の名前は `required-names.json` から読む。具体値の評価をしない。 -/
open Lean Elab Command in
run_cmd do
  let records := "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/c/"
  let loadNames := fun (file : String) => do
    let raw ← IO.FS.readFile (records ++ file)
    let json ← ofExcept (Json.parse raw)
    ofExcept (fromJson? json : Except String (List String))
  let requested ← loadNames "audit-modules.json"
  let required ← loadNames "required-names.json"
  let mut seen : Std.HashSet Name := {}
  let mut targets : Array Name := #[]
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      let selected := match env.getModuleIdxFor? name with
        | some idx => requested.contains env.header.moduleNames[idx.toNat]!.toString
        | none => false
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
  for module in requested do
    let some idx := env.getModuleIdx? module.toName | throwError "AUDIT_MODULE_MISSING {module}"
    let names := targets.filter fun n => env.getModuleIdxFor? n == some idx
    logInfo m!"AUDIT_MODULE {module} {names.size}"
  for name in required do
    unless targets.any (·.toString == name) do throwError "AUDIT_REQUIRED_MISSING {name}"
  for name in targets do
    let env ← getEnv
    let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
    let module := match env.getModuleIdxFor? name with
      | some idx => env.header.moduleNames[idx.toNat]!.toString
      | none => "local_records"
    let kind := match ci with
      | .thmInfo _ => "theorem" | .defnInfo _ => "definition" | .opaqueInfo _ => "opaque"
      | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor" | .recInfo _ => "recursor"
      | .quotInfo _ => "quotient" | .axiomInfo _ => "axiom"
    let range ← findDeclarationRanges? name
    let line := range.map (fun r => r.range.pos.line) |>.getD 0
    logInfo m!"AUDIT_DECL {module} {kind} {line} {name}"
    if required.contains name.toString then
      logInfo m!"SIGNATURE_BEGIN {module} {name} {line}"
      logInfo m!"{ci.type}"
      logInfo m!"SIGNATURE_END {name}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_COUNT {targets.size}"
