import Lean
import Benitoite
open Lean Elab Command Term Meta
open Benitoite.Release.Refinement
run_cmd do
  let raw ← IO.FS.readFile "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l60/a/def-sources.json"
  let json ← ofExcept (Json.parse raw)
  let rows ← ofExcept json.getArr?
  let mut seen : Array (String × String × Expr) := #[]
  for row in rows do
    let field : String → CommandElabM String := fun k => ofExcept ((row.getObjVal? k).bind Json.getStr?)
    let name ← field "lean_name"
    let source ← field "id"
    let expression ← field "original_def"
    let d ← liftTermElabM do
      let stx ← ofExcept (Parser.runParserCategory (← getEnv) `term ("(" ++ expression ++ " : Option Def)"))
      let e ← elabTerm stx none
      synthesizeSyntheticMVarsNoPostponing
      instantiateMVars e
    for (otherName, otherSource, other) in seen do
      if name == otherName then
        let same ← liftTermElabM <| isDefEq d other
        let compareField := fun (projection : Name) => liftTermElabM do
          let x ← mkAppM ``Option.map #[mkConst projection, d]
          let y ← mkAppM ``Option.map #[mkConst projection, other]
          isDefEq x y
        let body ← compareField ``Def.body
        let inputs ← compareField ``Def.params
        logInfo m!"COMPARE {source} {otherSource} {same} {body} {inputs}"
    seen := seen.push (name, source, d)
