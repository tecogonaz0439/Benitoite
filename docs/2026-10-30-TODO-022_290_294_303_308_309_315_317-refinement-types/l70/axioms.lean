import Benitoite
import Lean
set_option pp.fullNames true
set_option pp.proofs true
set_option pp.maxSteps 1000000
set_option pp.deepTerms.threshold 1000000

/-! 段末の公理監査と宣言の書き出し。既定 import の閉包の全宣言を所属モジュールで選び、private・生成宣言・構造体の欄・
マクロのスコープを持つ名前を含めて監査する。印字が実体化する生成宣言（所属モジュールなし）も不動点まで含める。
マクロのスコープを持つ名前は `#print axioms` の識別子として解決できないので、同じ関数 `collectAxioms` で直接調べる。
各宣言の種類・行・型の印字のハッシュ・型と値に現れる定数を `NODE` の行に書く（読者の照合と開始版との比較の入力）。
必須の名前（主定理と主な言明）は型を印字する。7入口の実行ファイルの根はどれも `main` を持つので一つの環境に読めない。
台本（`h/stage.py`）が根ごとに import と選ぶモジュールの行を差し替えた入力を一時領域に作る。具体値の評価をしない。 -/
open Lean Elab Command in
run_cmd do
  -- SELECT（台本が差し替える行）
  let selected : String → Bool := fun s => s.startsWith "Benitoite"
  -- AUDIT（開始版の書き出しでは台本が false に差し替える）
  let audit : Bool := true
  -- REQUIRED（台本が必須の名前の一覧に差し替える）
  let required : List Name := []
  let mut seen : Std.HashSet Name := {}
  let mut count : Nat := 0
  let mut macroCount : Nat := 0
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      let chosen := match env.getModuleIdxFor? name with
        | some idx => selected env.header.moduleNames[idx.toNat]!.toString
        | none => audit
      if chosen && !seen.contains name then some name else none
    if pending.isEmpty then break
    if rounds > 20 then throwError "AUDIT_FIXED_POINT_LIMIT"
    for name in pending.mergeSort (fun a b => a.toString < b.toString) do
      let env ← getEnv
      let some ci := env.find? name | do
        seen := seen.insert name
        logInfo m!"AUDIT_UNRESOLVED {name}"
        continue
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
      seen := seen.insert name
      count := count + 1
      let modName : String := match env.getModuleIdxFor? name with
        | some idx => env.header.moduleNames[idx.toNat]!.toString
        | none => "local"
      if audit then
        if name.hasMacroScopes then
          macroCount := macroCount + 1
          let axioms ← Lean.collectAxioms name
          let nameText : String := Json.compress (toJson name.toString)
          let axiomText : String := Json.compress (toJson (axioms.toList.map Name.toString))
          logInfo m!"AUDIT_MACRO {modName} {nameText} {axiomText}"
        else
          logInfo m!"AUDIT_TARGET {modName} {name}"
          elabCommand (← `(#print axioms $(mkIdent name)))
      let kind : String := match ci with
        | .thmInfo _ => "theorem" | .defnInfo _ => "definition" | .opaqueInfo _ => "opaque"
        | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor" | .recInfo _ => "recursor"
        | .quotInfo _ => "quotient" | .axiomInfo _ => "axiom"
      let range ← findDeclarationRanges? name
      let line := range.map (fun r => r.range.pos.line) |>.getD 0
      let typeDeps := ci.type.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
      let valueDeps := match ci.value? (allowOpaque := true) with
        | some value => value.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
        | none => {}
      let sort (s : Std.HashSet Name) := s.toList.map Name.toString |>.mergeSort (· < ·)
      let typeHash := toString (hash (toString ci.type))
      let nodeText : String := Json.compress <| Json.arr #[toJson name.toString, toJson modName, toJson kind, toJson line,
        toJson typeHash, toJson name.hasMacroScopes, toJson (sort typeDeps), toJson (sort valueDeps)]
      logInfo m!"NODE {nodeText}"
  let env ← getEnv
  for name in required do
    let some ci := env.find? name | throwError "AUDIT_REQUIRED_MISSING {name}"
    logInfo m!"SIGNATURE_BEGIN {name}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {name}"
  for module in env.header.moduleNames do
    if selected module.toString then
      logInfo m!"AUDIT_MODULE {module}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_MACRO_COUNT {macroCount}"
  logInfo m!"AUDIT_COUNT {count}"
