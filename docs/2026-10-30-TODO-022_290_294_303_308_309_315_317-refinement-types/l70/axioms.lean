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
定義と opaque は本体（値）の構造のハッシュ（`Expr.hash`。束縛子の名前と種類を含まない）も書く。本体は共有された部分式を
持つので、印字すると大きさが指数的に増えうるためである。定理の証明は比べない。帰納型は構成子の列、構造体は欄の列も書く
（信頼条件の構造体の欄と構成子の比較の入力）。
必須の名前（主定理と主な言明）は型を印字する。必須の名前の定義は本体も印字し、必須の名前の定理は、型に現れる主な言明
（必須の名前のうち値が命題の定義）を一段展開した型も印字する（言明の名前だけでなく中身を固定するため）。7入口の実行ファイルの根はどれも `main` を持つので一つの環境に読めない。
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
      let valueHash : String := match ci with
        | .defnInfo v => toString (hash v.value)
        | .opaqueInfo v => toString (hash v.value)
        | _ => ""
      let ctors : List Name := match ci with
        | .inductInfo v => v.ctors
        | _ => []
      let fields : List Name := if isStructure env name then (getStructureFields env name).toList else []
      let nodeText : String := Json.compress <| Json.arr #[toJson name.toString, toJson modName, toJson kind, toJson line,
        toJson typeHash, toJson name.hasMacroScopes, toJson (sort typeDeps), toJson (sort valueDeps), toJson valueHash,
        toJson (ctors.map Name.toString), toJson (fields.map Name.toString)]
      logInfo m!"NODE {nodeText}"
  let env ← getEnv
  -- 主な言明: 必須の名前のうち、値を持ち型の結論が命題である定義。
  let statements : List Name := required.filter fun n => match env.find? n with
    | some (.defnInfo v) => v.type.getForallBody == .sort .zero
    | _ => false
  for name in required do
    let some ci := env.find? name | throwError "AUDIT_REQUIRED_MISSING {name}"
    logInfo m!"SIGNATURE_BEGIN {name}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {name}"
    match ci with
    | .defnInfo v =>
      logInfo m!"VALUE_BEGIN {name}"
      logInfo m!"{v.value}"
      logInfo m!"VALUE_END {name}"
    | .thmInfo _ =>
      let unfolded ← liftCoreM <| Meta.deltaExpand ci.type statements.contains
      logInfo m!"UNFOLDED_BEGIN {name}"
      logInfo m!"{unfolded}"
      logInfo m!"UNFOLDED_END {name}"
    | _ => pure ()
  for module in env.header.moduleNames do
    if selected module.toString then
      logInfo m!"AUDIT_MODULE {module}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_MACRO_COUNT {macroCount}"
  logInfo m!"AUDIT_COUNT {count}"
