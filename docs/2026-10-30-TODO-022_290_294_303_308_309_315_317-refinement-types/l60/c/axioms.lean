import Lean
import Benitoite
set_option pp.fullNames true
set_option pp.proofs true
set_option pp.maxSteps 1000000
set_option pp.deepTerms.threshold 1000000

/-! 既定 import の全プロジェクト宣言を、所属モジュールから監査する。
宣言名の接頭辞では絞らず、private と印字時に実体化する生成宣言も含める。
標準ライブラリの使用定義への依存は、各 #print axioms が再帰的に調べる。 -/
open Lean Elab Command in
run_cmd do
  let records := "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l60/c/"
  let loadNames := fun (file : String) => do
    let raw ← IO.FS.readFile (records ++ file)
    let json ← ofExcept (Json.parse raw)
    ofExcept (fromJson? json : Except String (List String))
  let requested ← loadNames "requested-modules.json"
  let required ← loadNames "required-names.json"
  let referenced ← loadNames "referenced-names.json"
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
        | none => (name.toString.splitOn "Benitoite.").length > 1
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
  for module in env.header.moduleNames do
    if owned module.toString then
      let some idx := env.getModuleIdx? module | throwError "AUDIT_MODULE_MISSING {module}"
      let names := targets.filter fun n => env.getModuleIdxFor? n == some idx
      logInfo m!"AUDIT_MODULE {module} {names.size}"
  for module in requested do
    unless env.header.moduleNames.any (·.toString == module) do
      throwError "AUDIT_MODULE_MISSING {module}"
  for name in required do
    unless targets.any (·.toString == name) do throwError "AUDIT_REQUIRED_MISSING {name}"
  for name in referenced do
    if targets.any (·.toString == name) then logInfo m!"REFERENCE_FOUND {name}"
    else logInfo m!"REFERENCE_NONDECLARATION {name}"
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
      if requested.contains module then
        logInfo m!"AUDIT_DECL {module} {kind} {line} {name}"
        let mut used := ci.type.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
        if let some value := ci.value? (allowOpaque := true) then
          used := value.foldConsts used fun c cs => cs.insert c
        for dependency in used.toList.mergeSort (fun a b => a.toString < b.toString) do
          logInfo m!"DEPENDENCY {name} {dependency}"
      if required.contains name.toString || requested.contains module then
        logInfo m!"SIGNATURE_BEGIN {module} {name} {line}"
        logInfo m!"{ci.type}"
        logInfo m!"SIGNATURE_END {name}"
  -- 定義本体・構造体の欄は、署名の型印字と別に保存する。具体値の評価をしない。
  let definitions := [``Benitoite.Release.Refinement.ExternalModel.response,
    ``Benitoite.Release.Refinement.ExternalModel.builtins,
    ``Benitoite.Release.Refinement.ExternalModelExamples.filtered,
    ``Benitoite.Release.Refinement.ExternalModelExamples.Shape.type,
    ``Benitoite.Release.Refinement.ExternalModelExamples.handleSignature,
    ``Benitoite.Release.Refinement.ExternalModels.ModelCase.Declarations]
  for name in definitions do
    logInfo m!"DEFINITION_BEGIN {name}"
    elabCommand (← `(#print $(mkIdent name)))
    logInfo m!"DEFINITION_END {name}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_COUNT {targets.size}"
