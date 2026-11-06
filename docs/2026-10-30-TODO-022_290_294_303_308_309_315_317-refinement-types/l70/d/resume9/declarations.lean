import Lean
import Benitoite
set_option pp.fullNames true
set_option pp.proofs true
set_option pp.maxSteps 1000000
set_option pp.deepTerms.threshold 1000000

/-! 公理依存を取得済みの全対象から、宣言の所属・依存先・必須名の記録だけを補完する。
対象は環境変数が指す一時ファイルから読み、公理依存の出力と最終照合で完全一致を検査する。
`#print axioms` は実行しない。元の監査と同じ既定の環境を使い、具体値を評価しない。 -/
open Lean Elab Command in
run_cmd do
  let records := "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/d/resume9/"
  let loadNames := fun (file : String) => do
    let raw ← IO.FS.readFile (records ++ file)
    let json ← ofExcept (Json.parse raw)
    ofExcept (fromJson? json : Except String (List String))
  let owned ← loadNames "audit-modules.json"
  let env ← getEnv
  let requested := env.header.moduleNames.toList.filterMap fun n =>
    if n.toString.startsWith "Benitoite" then some n.toString else none
  let required ← loadNames "required-names.json"
  let some targetFile ← IO.getEnv "BENITOITE_AUDIT_TARGETS" | throwError "MISSING_TARGET_FILE"
  let raw ← IO.FS.readFile targetFile
  let targetsJson ← ofExcept (Json.parse raw)
  let names ← ofExcept (fromJson? targetsJson : Except String (List String))
  let byName := env.constants.toList.foldl (fun (table : Std.HashMap String Name) pair =>
    table.insert pair.1.toString pair.1) {}
  let targets ← names.toArray.mapM fun name => do
    let some target := byName[name]? | throwError "AUDIT_NAME_MISSING {name}"
    pure target
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
    if owned.contains module then
      let mut used := ci.type.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
      if let some value := ci.value? (allowOpaque := true) then
        used := value.foldConsts used fun c cs => cs.insert c
      for dependency in used.toList.mergeSort (fun a b => a.toString < b.toString) do
        logInfo m!"AUDIT_DEP {name} {dependency}"

    if required.contains name.toString then
      logInfo m!"SIGNATURE_BEGIN {module} {name} {line}"
      logInfo m!"{ci.type}"
      logInfo m!"SIGNATURE_END {name}"
  for module in owned do
    let some idx := env.getModuleIdx? module.toName | throwError "OWN_MODULE_MISSING {module}"
    let names := targets.filter fun n => env.getModuleIdxFor? n == some idx
    logInfo m!"OWN_MODULE {module} {names.size}"

  logInfo m!"AUDIT_COUNT {targets.size}"
