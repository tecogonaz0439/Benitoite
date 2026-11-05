import Lean
import Benitoite
open Lean Elab Command Term Meta
open Benitoite.Release.Refinement

private unsafe def functionReferences (e : Expr) : MetaM (Array String) := do
  let e ← whnf e
  let name := e.getAppFn.constName?.getD .anonymous
  let args := e.getAppArgs
  if name == ``Val.fnRef then
    return #[← evalExpr String (mkConst ``String) args[0]!]
  if name == ``Val.prim || name == ``Val.const || name == ``Val.var then return #[]
  let label := name.toString
  if !(label.startsWith "Benitoite.Release.Refinement.Val." ||
       label.startsWith "Benitoite.Release.Refinement.Comp." ||
       label.startsWith "Benitoite.Release.Refinement.Arm." ||
       label.startsWith "Benitoite.Release.Refinement.Closure." ||
       label.startsWith "Benitoite.Release.Refinement.Capture." ||
       label.startsWith "Benitoite.Release.Refinement.Clause." ||
       label.startsWith "Option." || label.startsWith "List.") then return #[]
  let mut out := #[]
  for arg in args do out := out ++ (← functionReferences arg)
  return out

run_cmd do
  let raw ← IO.FS.readFile "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l60/a/def-sources.json"
  let rows ← ofExcept ((Json.parse raw).bind Json.getArr?)
  for row in rows do
    let field : String → CommandElabM String := fun k => ofExcept ((row.getObjVal? k).bind Json.getStr?)
    let source ← field "id"
    let expression ← field "original_def"
    let refs ← liftTermElabM do
      let stx ← ofExcept (Parser.runParserCategory (← getEnv) `term
        ("Option.map Def.body (" ++ expression ++ " : Option Def)"))
      let e ← elabTerm stx none
      synthesizeSyntheticMVarsNoPostponing
      functionReferences (← instantiateMVars e)
    logInfo m!"REFERENCES {source} {Json.compress (toJson refs)}"


/- private・生成宣言も含む、この再現入力の全宣言の公理依存。 -/
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let localNames := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if localNames.isEmpty then break
    for n in localNames do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      elabCommand (← `(#print axioms $(mkIdent n)))
