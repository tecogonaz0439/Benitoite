import Benitoite.Exchange.Builtins
import Benitoite.Release.CoverageShow
import Lean

/-! E1c-2: 型検査を通った入力の表層の照合を、Lean の網羅性判定で検査する。
try とレコードの更新が脱糖で作る照合は含めない。 -/
open Lean Benitoite.Release
namespace CoverageProgramDiff
open Benitoite.Exchange

structure RawArm where
  alts : List Pattern
  guarded : Bool
  deriving FromJson, ToJson
structure RawMatch where
  node : Nat
  scrutineeTy : Benitoite.Exchange.Ty
  arms : List RawArm
  deriving FromJson, ToJson
structure RawBinding where
  node : Nat
  kind : String
  ty : Benitoite.Exchange.Ty
  pattern : Pattern
  deriving FromJson, ToJson
structure Input where
  group : String
  name : String
  «matches» : List RawMatch
  bindings : List RawBinding
  deriving FromJson, ToJson
structure Corpus where
  version : Nat
  inputs : List Input
  deriving FromJson

def program (ds : List DataMaterial) : Program :=
  { defs := fun _ => none, cons := constructorDecl ds,
    ops := fun _ => none, effects := fun _ => none, classes := fun _ => none,
    impls := fun _ => none }

def pattern (p : Pattern) : Except String Pat := do
  return (← p.toSurface).toCore

def arms (as : List RawArm) : Except String (List Benitoite.Release.Arm) :=
  as.mapM fun a => do
    if a.alts.isEmpty then throw "empty alternatives"
    let ps ← a.alts.mapM pattern
    return .mk (ps.map (fun p => ⟨p, []⟩))
      (if a.guarded then some (.ret (.const (.boolean true))) else none) (.ret (.const .unit))

-- E1c-1 と同じ分割。ガードなし分岐の先行選択肢は保持する。
def splitGuarded (as : List Benitoite.Release.Arm) : List Benitoite.Release.Arm × List (Nat × Option Nat) :=
  let entries := as.zipIdx.flatMap fun (a, i) =>
    match a with
    | .mk ps guard body =>
        if guard.isSome then ps.zipIdx.map (fun (p,j) => (.mk [p] guard body, (i, some j)))
        else [(a, (i, none))]
  (entries.map Prod.fst, entries.map Prod.snd)

structure Result where
  exhaustive : Bool
  uncovered : Option String
  unreachable : List (Nat × Nat)
  coveredBy : List ((Nat × Nat) × List Nat)
  deriving ToJson, BEq

def result (r : MatchCoverage) : Result :=
  ⟨r.exhaustive, r.uncovered.map (CoverageWitness.show (fun _ => none)),
    r.unreachable, r.coveredBy⟩

def restore (r : Result) (mapping : List (Nat × Option Nat)) : Result :=
  let position := fun (i,j) =>
    let (k,l) := (mapping[i]?).getD (i, none)
    (k, l.getD j)
  { r with
    unreachable := r.unreachable.map position
    coveredBy := r.coveredBy.map fun (pos, ks) =>
      let pos := position pos
      (pos, ((ks.map fun k => ((mapping[k]?).getD (k, none)).1).filter (· != pos.1)).eraseDups) }

def accepted : Result := ⟨true, none, [], []⟩

structure Counts where
  cases : Nat := 0
  matched : Nat := 0
  knownQ3 : Nat := 0
  mismatched : Nat := 0
  outOfScope : Nat := 0
  fuelExhausted : Nat := 0
  deriving ToJson

structure Outcome where
  classification : String
  fuelExhausted : Nat := 0
  detail : Json := .null
  deriving ToJson

def compareMatch (P : Program) (ctors : DataName → List ConName) (m : RawMatch) :
    Except String Outcome := do
  let t ← match m.scrutineeTy.toRelease with
    | .error e => return ⟨"outOfScope", 0, toJson e⟩
    | .ok t => pure t
  let as ← arms m.arms
  let r := checkMatch P ctors t as
  let original := result r
  let fuel := if r.fuelExhausted then 1 else 0
  if original == accepted then return ⟨"matched", fuel, toJson original⟩
  if !r.unreachable.isEmpty then
    let (split, mapping) := splitGuarded as
    let retry := checkMatch P ctors t split
    let restored := restore (result retry) mapping
    let fuel := fuel + if retry.fuelExhausted then 1 else 0
    return ⟨if restored == accepted then "knownQ3" else "mismatched", fuel,
      Json.mkObj [("original",toJson original),("restored",toJson restored)]⟩
  return ⟨"mismatched", fuel, toJson original⟩

def compareBinding (P : Program) (ctors : DataName → List ConName) (b : RawBinding) :
    Except String Outcome := do
  let t ← match b.ty.toRelease with
    | .error e => return ⟨"outOfScope", 0, toJson e⟩
    | .ok t => pure t
  let p ← pattern b.pattern
  let r := usefulReport P ctors [t] [[p]] [.wild]
  let ok := irrefutable P ctors t p
  return ⟨if ok then "matched" else "mismatched", if r.fuelExhausted then 1 else 0,
    Json.mkObj [("irrefutable",toJson ok),
      ("uncovered",toJson (r.witness.map (fun ws =>
        CoverageWitness.show (fun _ => none) (ws.headD .wild))))]⟩

def Counts.add (c : Counts) (o : Outcome) : Counts :=
  { cases := c.cases + 1
    matched := c.matched + if o.classification == "matched" then 1 else 0
    knownQ3 := c.knownQ3 + if o.classification == "knownQ3" then 1 else 0
    mismatched := c.mismatched + if o.classification == "mismatched" then 1 else 0
    outOfScope := c.outOfScope + if o.classification == "outOfScope" then 1 else 0
    fuelExhausted := c.fuelExhausted + o.fuelExhausted }

def read [FromJson α] (file : String) : IO α := do
  let j ← IO.ofExcept (Json.parse (← IO.FS.readFile file))
  IO.ofExcept (fromJson? j)

def run (args : List String) : IO UInt32 := do
  let [corpusFile, builtinFile, reportFile] := args
    | throw (IO.userError "usage: coverageProgramDiff coverage-matches.json builtins.json report.json")
  let corpus : Corpus ← read corpusFile
  let builtins : BuiltinCorpus ← read builtinFile
  if corpus.version != 1 || builtins.version != 1 then throw (IO.userError "unsupported version")
  if corpus.inputs.length != builtins.inputs.length then throw (IO.userError "input count mismatch")
  let mut matchCounts : Counts := {}
  let mut bindings : Counts := {}
  let mut mismatches : Array Json := #[]
  let mut knownExamples : Array Json := #[]
  let mut outsideExamples : Array Json := #[]
  let mut fuelExamples : Array Json := #[]
  for (input, builtin) in corpus.inputs.zip builtins.inputs do
    if input.group != builtin.group || input.name != builtin.name then
      throw (IO.userError s!"input identity mismatch: {input.group}/{input.name}")
    let ds ← IO.ofExcept (builtin.dataDecls.mapM DataEntry.toMaterial)
    let P := program ds
    let ctors := dataConstructors ds
    let tasks := (input.«matches».map fun m => ("match", m.node, toJson m, compareMatch P ctors m)) ++
      (input.bindings.map fun b => (b.kind, b.node, toJson b, compareBinding P ctors b))
    for (kind, node, raw, task) in tasks do
      let o ← IO.ofExcept (task.mapError fun e => s!"{input.group}/{input.name}:{node}: {e}")
      if kind == "match" then matchCounts := matchCounts.add o else bindings := bindings.add o
      let entry := Json.mkObj [("group",toJson input.group),("name",toJson input.name),
        ("kind",toJson kind),("node",toJson node),("input",raw),("outcome",toJson o)]
      match o.classification with
      | "mismatched" => mismatches := mismatches.push entry
      | "knownQ3" => if knownExamples.size < 12 then knownExamples := knownExamples.push entry
      | "outOfScope" => if outsideExamples.size < 12 then outsideExamples := outsideExamples.push entry
      | _ => pure ()
      if o.fuelExhausted > 0 then fuelExamples := fuelExamples.push entry
  let total := matchCounts.cases + bindings.cases
  let matched := matchCounts.matched + bindings.matched
  let known := matchCounts.knownQ3 + bindings.knownQ3
  let outside := matchCounts.outOfScope + bindings.outOfScope
  let fuel := matchCounts.fuelExhausted + bindings.fuelExhausted
  IO.FS.writeFile reportFile ((Json.mkObj [
    ("inputs",toJson corpus.inputs.length),("cases",toJson total),
    ("matched",toJson matched),("knownQ3",toJson known),("mismatched",toJson mismatches.size),
    ("outOfScope",toJson outside),("fuelExhausted",toJson fuel),
    ("matches",toJson matchCounts),("bindings",toJson bindings),
    ("knownExamples",.arr knownExamples),("mismatches",.arr mismatches),
    ("outOfScopeExamples",.arr outsideExamples),("fuelExamples",.arr fuelExamples)]).pretty ++ "\n")
  IO.println s!"coverageProgramDiff: inputs={corpus.inputs.length} matches={matchCounts.cases} bindings={bindings.cases} matched={matched} knownQ3={known} mismatched={mismatches.size} outOfScope={outside} fuelExhausted={fuel}"
  return if mismatches.isEmpty && fuel == 0 && total > 0 then 0 else 1

end CoverageProgramDiff

def main (args : List String) : IO UInt32 := do
  try CoverageProgramDiff.run args catch e =>
    (← IO.getStderr).putStrLn s!"coverageProgramDiff: {e}"
    return 2
