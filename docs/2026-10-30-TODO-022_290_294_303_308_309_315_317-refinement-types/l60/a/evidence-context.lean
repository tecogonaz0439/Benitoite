import Lean
import Benitoite
open Lean Elab Command Term Meta
open Benitoite.Release.Refinement

private def ordinaryContext : Program := {StandardOrdinaryCoreProgram.program with
  defs := fun n => if n = "List.filter" then (StandardBodies.listHigherRow true).definition
    else if n = "List.filterFrom" then some (StandardBodies.listFromDefinition true)
    else StandardOrdinaryCoreProgram.program.defs n}

private def term (s : String) : TermElabM Expr := do
  let stx ← ofExcept (Parser.runParserCategory (← getEnv) `term s)
  let e ← elabTerm stx none
  synthesizeSyntheticMVarsNoPostponing
  instantiateMVars e

private unsafe def functionReferences (e : Expr) : MetaM (Array String) := do
  let e ← whnf e
  let name := e.getAppFn.constName?.getD .anonymous
  let args := e.getAppArgs
  if name == ``Val.fnRef then
    return #[← evalExpr String (Lean.mkConst ``String) args[0]!]
  if name == ``Val.prim || name == ``Val.const || name == ``Val.var then return #[]
  let label := name.toString
  if !(label.startsWith "Benitoite.Release.Refinement.Val." ||
       label.startsWith "Benitoite.Release.Refinement.Comp." ||
       label.startsWith "Benitoite.Release.Refinement.Arm." ||
       label.startsWith "Benitoite.Release.Refinement.Closure." ||
       label.startsWith "Benitoite.Release.Refinement.Capture." ||
       label.startsWith "Benitoite.Release.Refinement.Clause." ||
       label.endsWith ".Detail.mk" ||
       label.startsWith "Option." || label.startsWith "List.") then return #[]
  let mut out := #[]
  for arg in args do out := out ++ (← functionReferences arg)
  return out

/-- 引数のない有限列挙型だけを展開し、列や数の具体値は作らない。 -/
private def alternatives (ty : Expr) : MetaM (Array Expr) := do
  let ty ← whnf ty
  let .const n _ := ty | return #[]
  let some (.inductInfo info) := (← getEnv).find? n | return #[]
  if info.numParams != 0 || info.numIndices != 0 || info.ctors.isEmpty then return #[]
  let mut out := #[]
  for c in info.ctors do
    let some (.ctorInfo ci) := (← getEnv).find? c | return #[]
    if ci.numFields != 0 then return #[]
    out := out.push (Lean.mkConst c)
  return out

private partial def specialize (ty original : Expr) : MetaM (Option (Array Expr × Expr)) := do
  if ty.isForall then
    let domain ← instantiateMVars ty.bindingDomain!
    let choices ← alternatives domain
    if !choices.isEmpty then
      for x in choices do
        let state ← saveState
        if let some (xs, target) ← specialize (ty.bindingBody!.instantiate1 x) original then
          return some (#[x] ++ xs, target)
        state.restore
      return none
    else
      let x ← mkFreshExprMVar domain
      let result ← specialize (ty.bindingBody!.instantiate1 x) original
      return result.map fun (xs,target) => (#[x] ++ xs,target)
  let args := ty.getAppArgs
  let n := ty.getAppFn.constName?.getD .anonymous
  let d ← if n == ``Def.WellTyped then pure args[2]!
    else if n == ``StandardContracts.Row.BodyTyped then do
      let opt ← whnf (mkApp (Lean.mkConst ``StandardContracts.Row.definition) args[0]!)
      unless opt.isAppOf ``Option.some do return none
      pure opt.getAppArgs[1]!
    else return none
  if ← isDefEq d original then return some (#[],ty)
  return none

/-- 構造体の前提も射影し、全称の有限添字の下の defs 等式を読む。 -/
private partial def lookups (ty : Expr) (label : String) : MetaM (Array (String × Expr × Expr)) := do
  let ty ← instantiateMVars ty
  if ty.isForall then
    let choices ← alternatives ty.bindingDomain!
    if !choices.isEmpty then
      let mut out := #[]
      for x in choices do
        out := out ++ (← lookups (ty.bindingBody!.instantiate1 x) (label ++ "/" ++ (← ppExpr x).pretty))
      return out
    -- 前提の命題の下も走査する。偽の含意でも要求された lookup 自体を照合する。
    return ← withLocalDeclD ty.bindingName! ty.bindingDomain! fun x =>
      lookups (ty.bindingBody!.instantiate1 x) (label ++ "/" ++ ty.bindingName!.toString)
  if ty.isAppOf ``Eq then
    let args := ty.getAppArgs
    let lhs := args[1]!
    if lhs.getAppFn.constName?.getD .anonymous == ``Program.defs then
      return #[(label,lhs.getAppArgs[1]!,args[2]!)]
    return #[]
  let n := ty.getAppFn.constName?.getD .anonymous
  if n == ``StandardOrdinaryListBodies.Inputs || n == ``StandardHeadTail.Inputs then
    let some info := getStructureInfo? (← getEnv) n | throwError "not a structure: {n}"
    let witness ← mkFreshExprMVar ty
    let mut out := #[]
    for field in info.fieldNames do
      let projection ← mkProjection witness field
      out := out ++ (← lookups (← inferType projection) (label ++ "." ++ field.toString))
    return out
  return #[]

run_cmd do
  let dir := "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l60/a/"
  let bodies ← ofExcept ((Json.parse (← IO.FS.readFile (dir ++ "resume3-body-sources.json"))).bind Json.getArr?)
  let rows ← ofExcept ((Json.parse (← IO.FS.readFile (dir ++ "resume3-body-classification.json"))).bind Json.getArr?)
  for row in rows do
    let field (r : Json) (k : String) : CommandElabM String := ofExcept ((r.getObjVal? k).bind Json.getStr?)
    let id ← field row "body"
    let kind ← field row "kind"
    let some body := bodies.find? (fun b => (b.getObjValAs? String "constructor").toOption == some id)
      | throwError "body missing: {id}"
    let proof ← field row "proof"
    let some ci := (← getEnv).find? proof.toName | throwError "missing proof {proof}"
    let expression ← field body "expression"
    let context ← field body "context"
    let refs : Array Json ← ofExcept ((body.getObjVal? "references").bind Json.getArr?)
    liftTermElabM do
      let opt ← whnf (← term ("(" ++ expression ++ " : Option Def)"))
      unless opt.isAppOf ``Option.some do throwError "original missing {id}"
      let actualRefs ← functionReferences (← whnf (mkApp (Lean.mkConst ``Def.body) opt.getAppArgs[1]!))
      let storedRefs ← refs.mapM fun (r : Json) => Lean.ofExcept r.getStr?
      unless actualRefs == storedRefs do throwError "reference inventory differs: {id}"
      if actualRefs.any (·.startsWith "%") then throwError "internal source reference: {id}"
      logInfo m!"SOURCE_REFERENCES {(Json.mkObj [("body",toJson id),("references",toJson actualRefs)]).compress}"
      if kind == "任意のP/B" then return
      let some (xs,target) ← specialize ci.type opt.getAppArgs[1]! | throwError "specialization failed {id} {proof}"
      let args := target.getAppArgs
      let p := if target.isAppOf ``Def.WellTyped then args[0]! else args[1]!
      let ctx ← term context
      let mut entries := #[]
      let mut premiseNames := #[]
      if kind == "固定のP/B" then
        if p.hasMVar then throwError "P not fixed: {id}"
        for ref in refs do
          let name ← ofExcept ref.getStr?
          let lhs := mkApp2 (Lean.mkConst ``Program.defs) p (toExpr name)
          let rhs := mkApp2 (Lean.mkConst ``Program.defs) ctx (toExpr name)
          let equal ← isDefEq lhs rhs
          entries := entries.push (Json.mkObj [("premise",toJson "fixed P"),("name",toJson name),("equal",toJson equal)])
          unless equal do throwError "fixed context mismatch: {id} {name}"
      else
        for x in xs do
          for (label,name,expected) in ← lookups (← inferType x) "premise" do
            let lookup := mkApp2 (Lean.mkConst ``Program.defs) ctx name
            let equal ← isDefEq lookup expected
            premiseNames := premiseNames.push name
            entries := entries.push (Json.mkObj [("premise",toJson label),("name",toJson (← ppExpr name).pretty),
              ("normalized_name",toJson (← ppExpr (← whnf name)).pretty),
              ("expected",toJson (← ppExpr expected).pretty),("equal",toJson equal)])
            unless equal do throwError "premise context mismatch: {id} {label} {← ppExpr name}"
        for ref in actualRefs do
          let mut found := false
          for name in premiseNames do
            if ← isDefEq name (toExpr ref) then found := true
          unless found do throwError "uncovered body reference: {id} {ref}"
      logInfo m!"CONTEXT {(Json.mkObj [("body",toJson id),("kind",toJson kind),("proof",toJson proof),
        ("context",toJson context),("fixed_program",toJson (← ppExpr p).pretty),("lookups",toJson entries)]).compress}"

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
