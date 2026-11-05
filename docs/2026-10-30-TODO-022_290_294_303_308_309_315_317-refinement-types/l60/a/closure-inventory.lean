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


private def ordinaryContext : Program := {StandardOrdinaryCoreProgram.program with
  defs := fun n => if n = "List.filter" then (StandardBodies.listHigherRow true).definition
    else if n = "List.filterFrom" then some (StandardBodies.listFromDefinition true)
    else StandardOrdinaryCoreProgram.program.defs n}

private unsafe def readDefinition (expression : String) : TermElabM Expr := do
  let stx ← ofExcept (Parser.runParserCategory (← getEnv) `term ("(" ++ expression ++ " : Option Def)"))
  let e ← elabTerm stx none
  synthesizeSyntheticMVarsNoPostponing
  let e ← whnf (← instantiateMVars e)
  unless e.isAppOf ``Option.some do throwError "missing definition: {expression}"
  return e.getAppArgs[1]!

run_cmd do
  let raw ← IO.FS.readFile "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l60/a/resume3-closure-seeds.json"
  let seeds ← ofExcept ((Json.parse raw).bind Json.getArr?)
  let mut queue : Array (String × String × String × String) := #[]
  for row in seeds do
    let field : String → CommandElabM String := fun k => ofExcept ((row.getObjVal? k).bind Json.getStr?)
    queue := queue.push (← field "id", ← field "lean_name", ← field "original_def", ← field "context")
  let mut cursor := 0
  let mut nodes : Array (String × Expr × String) := #[]
  let mut looked : Std.HashSet (String × String) := {}
  while cursor < queue.size do
    let (source, name, expression, context) := queue[cursor]!
    cursor := cursor + 1
    let (key, fresh, refs) ← liftTermElabM do
      let e ← readDefinition expression
      let mut key := ""
      for (oldName, oldDef, oldKey) in nodes do
        if oldName == name && (← isDefEq e oldDef) then
          key := oldKey
          break
      let fresh := key.isEmpty
      if fresh then key := s!"D{nodes.size + 1}"
      let body ← whnf (mkApp (mkConst ``Def.body) e)
      return (key, fresh, ← functionReferences body)
    if fresh then
      let e ← liftTermElabM (readDefinition expression)
      nodes := nodes.push (name, e, key)
    let record := Json.mkObj [("source",toJson source),("name",toJson name),
      ("expression",toJson expression),("context",toJson context),("key",toJson key),
      ("references",toJson refs),("fresh",toJson fresh)]
    logInfo m!"CLOSURE {record.compress}"
    for ref in refs do
      if !looked.contains (context, ref) then
        looked := looked.insert (context,ref)
        queue := queue.push ("helper:" ++ context ++ ":" ++ ref, ref,
          context ++ ".defs " ++ (toJson ref).compress, context)

open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let names := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if names.isEmpty then break
    for n in names do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      let deps ← Lean.collectAxioms n
      logInfo m!"'{n}' depends on axioms: [{String.intercalate ", " (deps.toList.map Name.toString)}]"
