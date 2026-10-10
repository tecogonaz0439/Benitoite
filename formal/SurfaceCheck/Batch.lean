import SurfaceCheck.Walk

/-! 全入力の宣言を一度準備し、定義と実装ごとの検査結果を保持する。 -/
namespace SurfaceCheck.Batch
open Lean Benitoite.Release Benitoite.Surface Benitoite.Surface.CheckTools
open Benitoite.Exchange.CheckInput Benitoite.Surface.CheckTables

structure Counts where
  matched : Nat := 0
  q11 : Nat := 0
  knownDifference : Nat := 0
  outOfScope : Nat := 0
  lazyRestriction : Nat := 0
  mismatched : Nat := 0
  preparationFailure : Nat := 0
  deriving ToJson
structure Report where
  counts : Counts := {}
  inputs : Nat := 0
  excluded : Nat := 0
  fullyCheckedInputs : Nat := 0
  definitions : Nat := 0
  implementations : Nat := 0
  replacements : Nat := 0
  nonUnitReplacements : Nat := 0
  tailMatches : Nat := 0
  outcomes : Array Json := #[]
  preparationErrors : Array Json := #[]

def bump (c : Counts) (category : String) : Counts :=
  match category with
  | "matched" => { c with matched := c.matched + 1 }
  | "q11" => { c with q11 := c.q11 + 1 }
  | "knownDifference" => { c with knownDifference := c.knownDifference + 1 }
  | "outOfScope" => { c with outOfScope := c.outOfScope + 1 }
  | "lazyRestriction" => { c with lazyRestriction := c.lazyRestriction + 1 }
  | _ => { c with mismatched := c.mismatched + 1 }

def tag : Benitoite.Surface.Expr → String
  | .lazyE _ => "lazyE"
  | .returnE _ _ => "returnE"
  | .resume _ _ => "resume"
  | .constE _ _ => "constE"
  | .lam _ _ _ _ => "lam"
  | .methName _ _ _ _ _ _ => "methName"
  | .funDicts _ _ _ _ _ => "funDicts"
  | .partialCall _ _ _ _ => "partialCall"
  | .matchE _ _ _ => "matchE"
  | .call _ _ => "call"
  | _ => "other"

def ancestors (w : WalkState) (path : List Nat) : Array Node :=
  w.nodes.filter fun n => n.path.isPrefixOf path

/-- Lazy の内部の関数だけが異なる場合に限る。診断用の再検査が失敗したら除外しない。 -/
def lazyDifference (q : Benitoite.Surface.Check.Input) (w : WalkState)
    (e : Benitoite.Surface.Check.Error) : Bool := Id.run do
  if e.reason != "type is not included in the expected type" then return false
  let some n := (ancestors w e.path).back? | return false
  if n.path != e.path then return false
  let .lazyE body := n.expr | return false
  let some (.lazy (.fn ps r eff)) := n.expected | return false
  let .ok (.fn ps' r' eff', _) := Benitoite.Surface.Check.checkBlock q .strict [] [] none .other [] body
    | return false
  return tysEq q.atoms ps ps' && tyEq q.atoms r r' && !effEq q.atoms eff eff'

def category (q : Benitoite.Surface.Check.Input) (w : WalkState) (marks : List String) (badPrims : List String)
    (result : Benitoite.Surface.Check.Result Unit) : String :=
  if w.prims.any badPrims.contains then "outOfScope" else
  match result with
  | .ok _ => if w.changes.isEmpty then "matched" else "q11"
  | .error e =>
    if !w.partialReturns.isEmpty then "mismatched" else
    if marks.contains "ガードの中の resume（TODO-190）" &&
        e.reason == "continuation is missing or hidden" &&
        w.guards.any (fun p => p.isPrefixOf e.path) then "knownDifference"
    else if lazyDifference q w e then "lazyRestriction" else "mismatched"

def outcomeJson (group input name kind cat : String) (w : WalkState)
    (result : Benitoite.Surface.Check.Result Unit) : Json :=
  let error := match result with
    | .ok _ => Json.null
    | .error e => Json.mkObj [("path",toJson e.path),("reason",toJson e.reason),
        ("ancestors",toJson ((ancestors w e.path).map fun n =>
          Json.mkObj [("path",toJson n.path),("tag",toJson (tag n.expr))]))]
  Json.mkObj [("group",toJson group),("input",toJson input),("definition",toJson name),
    ("kind",toJson kind),("category",toJson cat),("error",error),
    ("q11Paths",toJson w.changes),("nonUnitReplacements",toJson w.nonUnit),
    ("partialReturnPaths",toJson w.partialReturns),
    ("diagnosis",toJson (if cat != "mismatched" then "classified" else
      if !w.partialReturns.isEmpty then "rustTypecheckerCandidate" else "requiresReview"))]

def record (q : Benitoite.Surface.Check.Input) (r : Report) (group input name kind : String) (w : WalkState)
    (marks badPrims : List String) (result : Benitoite.Surface.Check.Result Unit) : Report :=
  let cat := category q w marks badPrims result
  { r with tailMatches := r.tailMatches + w.tailMatches, counts := bump r.counts cat, replacements := r.replacements + w.changes.size, nonUnitReplacements := r.nonUnitReplacements + w.nonUnit, outcomes := r.outcomes.push (match outcomeJson group input name kind cat w result with
      | .obj fields => Json.mkObj (fields.toArray.toList ++ [("unconvertiblePrims",toJson (w.prims.filter badPrims.contains).eraseDups)])
      | j => j) }

def normalize (p : Prepared) : Materials × List (String × WalkState) := Id.run do
  let defs := p.materials.defs.map fun (n,d) =>
    let (body,w) := (walkBlock p.input (some d.ret) .tail [0] false (some d.ret) d.body).run {}
    ((n,{ d with body }), (n,w))
  let walks := defs.map Prod.snd
  let impls := p.materials.impls.map fun (n,i) => Id.run do
    let (methods,w) := (i.methods.mapM fun (method,body) => do
      let ms : Option MethSig := (p.input.D.classes i.signature.cls).bind (fun c => c.methods method)
      let result := ms.map fun (m : MethSig) => substTyAt m.tparams.length [i.signature.target] [] m.ret
      let index := p.materials.names.methods.idxOf method
      let body' ← walkBlock p.input result .tail [0,index] false result body
      pure (method,body')).run {}
    return ((n,{ i with methods }), (n,w))
  return ({ p.materials with defs := defs.map Prod.fst, impls := impls.map Prod.fst }, walks ++ impls.map Prod.snd)

def checkInput (r : Report) (input : Benitoite.Exchange.Input)
    (b : Benitoite.Exchange.BuiltinInput) (p : Prepared) : Report := Id.run do
  let before := r.counts
  let (m,ws) := normalize p
  -- 型の宣言は補正で変わらない。検査は補正後の各本体を直接受け取る。
  let q := { p.input with D := m.declarations }
  let bad := (b.prims.filter fun x => !x.unconvertibleTypes.isEmpty).map (·.name)
  let mut r := { r with inputs := r.inputs + 1, definitions := r.definitions + m.defs.length, implementations := r.implementations + m.impls.length }
  for (n,d) in m.defs do
    let w := (Benitoite.Surface.CheckTables.lookup ws n).getD {}
    let marks := input.definitions.filterMap fun d =>
      if (functionKey d.name).toOption == some n then some d.knownDifferences else none
    let result := Benitoite.Surface.Check.checkDef q [] d
    r := record q r input.group input.name n "definition" w marks.flatten bad result
    if !w.changes.isEmpty then
      let before := (Benitoite.Surface.CheckTables.lookup p.materials.defs n).map
        (Benitoite.Surface.Check.checkDef p.input [])
      let originalError := match before with
        | some (.error e) => Json.mkObj [("path",toJson e.path),("reason",toJson e.reason)]
        | _ => Json.null
      r := { r with outcomes := r.outcomes.modify (r.outcomes.size - 1) fun j =>
        match j with
        | .obj fields => Json.mkObj (fields.toArray.toList ++ [("q11OriginalError",originalError)])
        | _ => j }
  for (n,i) in m.impls do
    let w := (Benitoite.Surface.CheckTables.lookup ws n).getD {}
    let result := Benitoite.Surface.Check.checkImpl q m.names.methods m.names.supers [] i.decl
    let failedMethod := match result with
      | .error ⟨0 :: index :: _, _⟩ => m.names.methods[index]?
      | _ => none
    let marks := input.definitions.flatMap fun d => match d.scope with
      | .inScope s _ => if s.implementation == some n && s.method == failedMethod then d.knownDifferences else []
      | _ => []
    r := record q r input.group input.name n "implementation" w marks bad result
  for (n,reasons) in p.outside do
    r := { r with counts := bump r.counts "outOfScope", outcomes := r.outcomes.push (Json.mkObj [("group",toJson input.group),("input",toJson input.name),("definition",toJson n),
        ("kind",toJson "unconverted"),("category",toJson "outOfScope"),("reasons",toJson reasons)]) }
  let allChecked := r.counts.knownDifference == before.knownDifference &&
    r.counts.outOfScope == before.outOfScope && r.counts.lazyRestriction == before.lazyRestriction &&
    r.counts.mismatched == before.mismatched
  return { r with fullyCheckedInputs := r.fullyCheckedInputs + if allChecked then 1 else 0 }

def readJson (file : String) : IO Json := do
  IO.ofExcept (Json.parse (← IO.FS.readFile file))

def run (args : List String) : IO UInt32 := do
  let corpusFile :: builtinFile :: stdlibFile :: reportFile :: [] := args
    | throw (IO.userError "usage: surfaceCheckAll corpus.json builtins.json stdlib-decls.json report.json")
  let start ← IO.monoNanosNow
  let corpus ← readJson corpusFile
  let bj ← readJson builtinFile
  let sj ← readJson stdlibFile
  for (j,v) in [(corpus,7),(bj,1),(sj,1)] do
    if (← IO.ofExcept (j.getObjValAs? Nat "version")) != v then throw (IO.userError "unsupported version")
  let inputs ← IO.ofExcept ((corpus.getObjVal? "inputs").bind Json.getArr?)
  let bs ← IO.ofExcept ((bj.getObjVal? "inputs").bind Json.getArr?)
  let ss ← IO.ofExcept ((sj.getObjVal? "inputs").bind Json.getArr?)
  let ops ← IO.ofExcept (corpus.getObjValAs? (List Benitoite.Exchange.OperatorEntry) "operators")
  let mut r : Report := {}
  let mut eligible := 0
  for j in inputs do
    let excluded ← IO.ofExcept (j.getObjValAs? (List String) "excluded")
    if !excluded.isEmpty then
      r := { r with excluded := r.excluded + 1 }
      continue
    let preparation : Except String (Benitoite.Exchange.Input × Benitoite.Exchange.BuiltinInput × Prepared) := do
      let input ← (fromJson? j : Except String Benitoite.Exchange.Input)
      let some bj := bs[eligible]? | throw "missing builtin input"
      let some sj := ss[eligible]? | throw "missing stdlib input"
      let b ← (fromJson? bj : Except String Benitoite.Exchange.BuiltinInput)
      let s ← (fromJson? sj : Except String StdlibInput)
      let p ← prepare input b s ops
      if !p.constructors || !p.records || !p.implNames then throw "invalid declaration tables"
      if p.materials.effects.any (fun (n,_) => (p.input.B.effects n).isSome) then
        throw "effect name overlaps a builtin effect"
      return (input,b,p)
    eligible := eligible + 1
    match preparation with
    | .error e =>
      r := { r with counts := { r.counts with preparationFailure := r.counts.preparationFailure + 1 }, preparationErrors := r.preparationErrors.push (Json.mkObj [
        ("group",toJson ((j.getObjValAs? String "group").toOption)),
        ("input",toJson ((j.getObjValAs? String "name").toOption)),("reason",toJson e)]) }
    | .ok (input,b,p) => r := checkInput r input b p
    if eligible % 100 == 0 then IO.println s!"surfaceCheckAll: inputs={eligible} mismatches={r.counts.mismatched}"
  if bs.size != eligible || ss.size != eligible then
    r := { r with counts := { r.counts with preparationFailure := r.counts.preparationFailure + 1 }, preparationErrors := r.preparationErrors.push (Json.mkObj [("reason",toJson "sidecar input count mismatch")]) }
  let expectedTail ← IO.ofExcept ((corpus.getObjVal? "annotations").bind
    (fun j => j.getObjValAs? (List Nat) "tailMatch"))
  let q11Agrees := expectedTail == [r.tailMatches, r.replacements]
  let stop ← IO.monoNanosNow
  let counts := toJson r.counts
  let mismatches := r.outcomes.filter fun j =>
    (j.getObjValAs? String "category").toOption == some "mismatched"
  let candidates := mismatches.filter fun j =>
    (j.getObjValAs? String "diagnosis").toOption == some "rustTypecheckerCandidate"
  let output := Json.mkObj [("mismatchClasses",Json.mkObj [
    ("rustTypecheckerCandidates",toJson candidates.size),("leanFalseRejection",toJson (0 : Nat)),
    ("exporter",toJson (0 : Nat)),("requiresReview",toJson (mismatches.size - candidates.size))]),("q11Agrees",toJson q11Agrees),("expectedTailMatch",toJson expectedTail),("version",toJson (1 : Nat)),("counts",counts),
    ("inputs",toJson r.inputs),("excludedInputs",toJson r.excluded),("fullyCheckedInputs",toJson r.fullyCheckedInputs),
    ("definitions",toJson r.definitions),("implementations",toJson r.implementations),
    ("tailMatches",toJson r.tailMatches),("replacements",toJson r.replacements),("nonUnitReplacements",toJson r.nonUnitReplacements),
    ("mismatchExamples",toJson (r.outcomes.filter fun j =>
      (j.getObjValAs? String "category").toOption == some "mismatched")),
    ("elapsedNanos",toJson (stop-start)),("outcomes",toJson r.outcomes),("preparationErrors",toJson r.preparationErrors)]
  IO.FS.writeFile reportFile (output.pretty ++ "\n")
  IO.println counts.compress
  if r.counts.preparationFailure > 0 then return 2
  if r.inputs == 0 then return 1
  return if r.counts.mismatched == 0 && q11Agrees then 0 else 1
end SurfaceCheck.Batch
