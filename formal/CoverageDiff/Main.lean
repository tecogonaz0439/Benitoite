import Benitoite.Release.CoverageShow
import Lean

/-!
E1c-1: 型から作ったパターンについて、処理系の公開 API と網羅性の手順を比較する。
前提: ctors は各データ型の構成子を宣言順にちょうど含む（欠け・余分・重複なし）。
交換形式の検査でこの前提と、型引数・構成子の引数数・文字の符号位置を確認する。
-/
open Lean Benitoite.Release
namespace CoverageDiff

structure RawCtor where
  name : String
  constructorName : String
  tag : Nat
  args : List Json
  deriving FromJson, ToJson
structure RawDecl where
  name : String
  typeName : String
  ntys : Nat
  fields : Option (List String)
  ctors : List RawCtor
  deriving FromJson, ToJson
structure RawArm where
  guarded : Bool
  alts : List Json
  deriving FromJson, ToJson
structure Unreachable where
  arm : Nat
  alt : Nat
  coveredBy : List Nat
  deriving FromJson, ToJson, BEq
structure Result where
  exhaustive : Bool
  uncovered : Option String
  unreachable : List Unreachable
  deriving FromJson, ToJson, BEq
structure Input where
  name : String
  decls : List RawDecl
  ty : Json
  arms : List RawArm
  pattern : Json
  expected : Result
  irrefutable : Bool
  irrefutableWitness : Option String
  deriving FromJson, ToJson
structure Corpus where
  version : Nat
  seedXor : Nat
  randomCases : Nat
  boundaryCases : Nat
  kinds : Json
  cases : List Input
  deriving FromJson, ToJson

def field (j : Json) (k : String) : Except String Json := j.getObjVal? k
def get [FromJson α] (j : Json) (k : String) : Except String α := field j k >>= fromJson?
def array (j : Json) (k : String) : Except String (List Json) := get j k

def readInt (j : Json) : Except String Int := do
  let n : Int ← fromJson? j
  if n < -9223372036854775808 || n > 9223372036854775807 then throw "integer outside i64"
  return n

def readChar (j : Json) : Except String Char := do
  let n : Nat ← fromJson? j
  if !decide (Nat.isValidChar n) then throw s!"invalid character code point: {n}"
  return Char.ofNat n

partial def readTy (ds : List RawDecl) (params : Nat) (j : Json) : Except String Ty := do
  let k : String ← get j "kind"
  match k with
  | "param" =>
      let i : Nat ← get j "index"
      if i >= params then throw "parameter outside declaration"
      return .tvar i
  | "data" =>
      let name : String ← get j "name"
      let some d := ds.find? (fun d => d.name == name) | throw s!"unknown data type: {name}"
      let args ← (← array j "args").mapM (readTy ds params)
      if args.length != d.ntys then throw "data type argument count"
      return .data name args
  | "list" =>
      let [a] ← (← array j "args").mapM (readTy ds params) | throw "list arity"
      return .list a
  | _ =>
      if !(← array j "args").isEmpty then throw "base type arity"
      match k with
      | "integer" => return .base .integer
      | "character" => return .base .character
      | "string" => return .base .string
      | "boolean" => return .base .boolean
      | "unit" => return .base .unit
      | _ => throw s!"unknown type: {k}"

partial def readPat (j : Json) : Except String Pat := do
  let k : String ← get j "kind"
  match k with
  | "wild" => return .wild
  | "con" => return .con (← get j "name") (← (← array j "args").mapM readPat)
  | "integer" => return .const (.integer (← readInt (← field j "value")))
  | "character" => return .const (.character (← readChar (← field j "value")))
  | "string" => return .const (.string (← get j "value"))
  | "boolean" => return .const (.boolean (← get j "value"))
  | "unit" => return .const .unit
  | "integerRange" =>
      let lo ← readInt (← field j "lo")
      let hi ← readInt (← field j "hi")
      if lo > hi then throw "reversed integer range"
      return .range (.integer lo) (.integer hi)
  | "characterRange" =>
      let lo ← readChar (← field j "lo")
      let hi ← readChar (← field j "hi")
      if lo.toNat > hi.toNat then throw "reversed character range"
      return .range (.character lo) (.character hi)
  | "list" =>
      let before ← (← array j "before").mapM readPat
      let after ← (← array j "after").mapM readPat
      return .list before (if (← get j "rest" : Bool) then some .skip else none) after
  | _ => throw s!"unknown pattern: {k}"

structure Material where
  cons : List (ConName × ConDecl)
  ctors : List (DataName × List ConName)
  displays : List (ConName × CoverageDisplay)

def duplicate (xs : List String) : Bool := xs.eraseDups.length != xs.length

def material (ds : List RawDecl) : Except String Material := do
  if duplicate (ds.map RawDecl.name) || duplicate (ds.flatMap fun d => d.ctors.map RawCtor.name) then
    throw "duplicate data/constructor name"
  let mut cs := []
  let mut displays := []
  for d in ds do
    if d.ctors.isEmpty then throw "empty data declaration"
    if d.fields.isSome && d.ctors.length != 1 then throw "record constructor count"
    for (c, tag) in d.ctors.zipIdx do
      if c.tag != tag then throw "constructor order"
      let args ← c.args.mapM (readTy ds d.ntys)
      if d.fields.any (fun fs => fs.length != args.length || duplicate fs) then throw "record fields"
      cs := cs ++ [(c.name, ⟨d.name, d.ntys, args⟩)]
      displays := displays ++ [(c.name, ⟨d.typeName, c.constructorName,
        d.typeName == c.constructorName, d.fields⟩)]
  return ⟨cs, ds.map (fun d => (d.name, d.ctors.map RawCtor.name)), displays⟩

def Material.program (m : Material) : Program :=
  { defs := fun _ => none, cons := fun c => (m.cons.find? (·.1 == c)).map Prod.snd,
    ops := fun _ => none, effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def Material.constructors (m : Material) (d : DataName) : List ConName :=
  ((m.ctors.find? (·.1 == d)).map Prod.snd).getD []
def Material.display (m : Material) (c : ConName) : Option CoverageDisplay :=
  (m.displays.find? (·.1 == c)).map Prod.snd

-- この検査は表層の型検査ではなく、生成器の前提の確認である。
partial def typedPat (m : Material) (t : Ty) (p : Pat) : Bool :=
  Coverage.compatible m.program t p &&
    match t, p with
    | .data d ts, .con c ps =>
        ((Coverage.conFields m.program d ts c).map fun fields =>
          fields.length == ps.length && (fields.zip ps).all (fun (t,p) => typedPat m t p)).getD false
    | .list a, .list before _ after => (before ++ after).all (typedPat m a)
    | _, _ => true

def readArms (m : Material) (t : Ty) (arms : List RawArm) : Except String (List Arm) := do
  if arms.length > 6 then throw "too many arms"
  arms.mapM fun a => do
    if a.alts.isEmpty || a.alts.length > 3 then throw "alternative count"
    let ps ← a.alts.mapM readPat
    if !(ps.all (typedPat m t)) then throw "ill-typed alternative"
    return .mk (ps.map (fun p => ⟨p, []⟩))
      (if a.guarded then some (.ret (.const (.boolean true))) else none) (.ret (.const .unit))

def result (m : Material) (r : MatchCoverage) : Result :=
  ⟨r.exhaustive, r.uncovered.map (CoverageWitness.show m.display),
    r.unreachable.map (fun (i,j) => ⟨i,j, ((r.coveredBy.find? (·.1 == (i,j))).map Prod.snd).getD []⟩)⟩

-- ガード付き分岐だけを分割する。ガードなし分岐の中の先行選択肢は保持する。
def splitGuarded (arms : List Arm) : List Arm × List (Nat × Option Nat) :=
  let entries := arms.zipIdx.flatMap fun (arm, i) =>
    match arm with
    | .mk alts guard body =>
        if guard.isSome then alts.zipIdx.map (fun (alt,j) => (.mk [alt] guard body, (i, some j)))
        else [(arm, (i, none))]
  (entries.map Prod.fst, entries.map Prod.snd)

def restore (r : Result) (mapping : List (Nat × Option Nat)) : Result :=
  { r with unreachable := r.unreachable.map fun u =>
      let (i, j) := (mapping[u.arm]?).getD (u.arm, none)
      let covered := ((u.coveredBy.map fun k => ((mapping[k]?).getD (k, none)).1).filter (· != i)).eraseDups
      ⟨i, j.getD u.alt, covered⟩ }

structure FuelCounts where
  matchChecks : Nat := 0
  coveringSingletons : Nat := 0
  coveringPrefixes : Nat := 0
  overlaps : Nat := 0
  irrefutable : Nat := 0
  deriving ToJson

def FuelCounts.total (f : FuelCounts) : Nat :=
  f.matchChecks + f.coveringSingletons + f.coveringPrefixes + f.overlaps + f.irrefutable

def FuelCounts.add (a b : FuelCounts) : FuelCounts :=
  ⟨a.matchChecks + b.matchChecks, a.coveringSingletons + b.coveringSingletons,
    a.coveringPrefixes + b.coveringPrefixes, a.overlaps + b.overlaps, a.irrefutable + b.irrefutable⟩

-- overlapsFuel と同じ引数・短絡評価で、0 に到達した呼び出しを記録する。
def auditOverlap (P : Program) (ctors : DataName → List ConName) :
    Nat → Ty → Pat → Pat → Bool × Nat
  | 0, _, _, _ => (false, 1)
  | fuel+1, t, a, b => Id.run do
      if Coverage.isWild a || Coverage.isWild b then return (true,0)
      let mut exhausted := 0
      for s in Coverage.shapes P ctors t [a,b] do
        match Coverage.specialize a s, Coverage.specialize b s with
        | some xs, some ys =>
            if xs.length == ys.length then
              let mut ok := true
              for (t,x,y) in s.fields.zip (xs.zip ys) do
                if ok then
                  let (v,n) := auditOverlap P ctors fuel t x y
                  exhausted := exhausted + n
                  ok := v
              if ok then return (true,exhausted)
        | _, _ => pure ()
      return (false,exhausted)

-- MatchCoverage の欄に含まれない coveringAlternatives の呼び出しも監査する。
-- 単独の行・各接頭辞は実際の手順と同じ引数で usefulReport を呼ぶ。
def auditMatch (m : Material) (t : Ty) (arms : List Arm) (r : MatchCoverage) : Except String FuelCounts := do
  let mut f : FuelCounts := {}
  let count := fun rows q => if (usefulReport m.program m.constructors [t] rows [q]).fuelExhausted then 1 else 0
  f := { f with matchChecks := count ((unguardedPats arms).map (fun p => [p])) .wild }
  for (arm,i) in arms.zipIdx do
    for (alt,j) in arm.alts.zipIdx do
      f := { f with matchChecks := f.matchChecks + count ((precedingPats arms i j).map (fun p => [p])) alt.pat }
  for (i,j) in r.unreachable do
    let some target := (arms[i]?).bind (fun a => (a.alts[j]?).map Alt.pat) |
      throw "unreachable position outside arms"
    let prev := precedingAlternatives arms i j
    for (_,p) in prev do
      f := { f with coveringSingletons := f.coveringSingletons + count [[p]] target }
    for (_,k) in prev.zipIdx do
      f := { f with coveringPrefixes := f.coveringPrefixes + count ((prev.take (k+1)).map (fun (_,p) => [p])) target }
    for (_,p) in prev do
      let (v,n) := auditOverlap m.program m.constructors
        (Coverage.nodes p + Coverage.nodes target + 1) t p target
      if v != overlaps m.program m.constructors t p target then throw "overlap audit disagrees"
      f := { f with overlaps := f.overlaps + n }
  if r.fuelExhausted && f.matchChecks == 0 then f := { f with matchChecks := 1 }
  return f

structure CaseReport where
  name : String
  classification : String
  expected : Result
  lean : Result
  adjusted : Result
  expectedIrrefutable : Bool
  leanIrrefutable : Bool
  expectedIrrefutableWitness : Option String
  leanIrrefutableWitness : Option String
  extraUnreachable : List Unreachable
  changedCoveredBy : List Unreachable
  fuel : FuelCounts
  deriving ToJson

def compare (input : Input) : Except String CaseReport := do
  let m ← material input.decls
  let t ← readTy input.decls 0 input.ty
  let arms ← readArms m t input.arms
  let p ← readPat input.pattern
  if !typedPat m t p then throw "ill-typed irrefutable pattern"
  let r := checkMatch m.program m.constructors t arms
  let original := result m r
  let (split, mapping) := splitGuarded arms
  let sr := checkMatch m.program m.constructors t split
  let adjusted := restore (result m sr) mapping
  let ir := irrefutable m.program m.constructors t p
  let iw := (checkMatch m.program m.constructors t [.mk [⟨p,[]⟩] none (.ret (.const .unit))]).uncovered.map (CoverageWitness.show m.display)
  let irFuel := usefulReport m.program m.constructors [t] [[p]] [.wild]
  let sameIr := ir == input.irrefutable && iw == input.irrefutableWitness
  let equal := original == input.expected && sameIr
  -- Q3 で除外できる差は位置と coveredBy に限る。処理系だけの位置は常に不一致。
  let rustOnly := input.expected.unreachable.any fun u =>
    !(original.unreachable.any fun v => u.arm == v.arm && u.alt == v.alt)
  let known := !equal && sameIr && !rustOnly && original.exhaustive == input.expected.exhaustive &&
    original.uncovered == input.expected.uncovered && adjusted == input.expected
  let originalFuel ← auditMatch m t arms r
  let adjustedFuel ← auditMatch m t split sr
  let fuel := originalFuel.add adjustedFuel
  let fuel := { fuel with irrefutable := if irFuel.fuelExhausted then 1 else 0 }
  return {
    name := input.name, classification := (if equal then "matched" else if known then "knownQ3" else "mismatched"),
    expected := input.expected, lean := original, adjusted := adjusted,
    expectedIrrefutable := input.irrefutable, leanIrrefutable := ir,
    expectedIrrefutableWitness := input.irrefutableWitness, leanIrrefutableWitness := iw,
    extraUnreachable := original.unreachable.filter (fun v => !(input.expected.unreachable.any fun u => u.arm == v.arm && u.alt == v.alt)),
    changedCoveredBy := original.unreachable.filter (fun v => input.expected.unreachable.any fun u => u.arm == v.arm && u.alt == v.alt && u.coveredBy != v.coveredBy), fuel := fuel }

def run (args : List String) : IO UInt32 := do
  let [corpusFile, reportFile] := args | throw (IO.userError "usage: coverageDiff corpus.json report.json")
  -- Lean の JSON でも i64 の両端を数として往復できることを確かめる。
  for n in [-9223372036854775808, 9223372036854775807] do
    let v ← IO.ofExcept (Json.parse ((toJson (n : Int)).compress) >>= readInt)
    if v != n then throw (IO.userError "i64 JSON roundtrip")
  let corpus ← IO.ofExcept ((Json.parse (← IO.FS.readFile corpusFile)) >>= fromJson? : Except String Corpus)
  if corpus.version != 1 then throw (IO.userError "unsupported coverage version")
  if corpus.cases.length != corpus.randomCases + corpus.boundaryCases || duplicate (corpus.cases.map Input.name) then
    throw (IO.userError "case count/names")
  let mut matched := 0
  let mut known := 0
  let mut mismatches : Array Json := #[]
  let mut knownExamples : Array Json := #[]
  let mut fuel : FuelCounts := {}
  let mut fuelExamples : Array Json := #[]
  let mut extraCases := 0
  let mut changedCases := 0
  let mut extraPositions := 0
  let mut changedPositions := 0
  let mut boundary : Array Json := #[]
  for input in corpus.cases do
    let report ← IO.ofExcept ((compare input).mapError (fun e => s!"{input.name}: {e}"))
    fuel := fuel.add report.fuel
    if report.fuel.total > 0 then fuelExamples := fuelExamples.push (toJson report)
    if !input.name.startsWith "random/" then boundary := boundary.push (toJson report)
    match report.classification with
    | "matched" => matched := matched + 1
    | "knownQ3" =>
        known := known + 1
        if !report.extraUnreachable.isEmpty then extraCases := extraCases + 1
        if !report.changedCoveredBy.isEmpty then changedCases := changedCases + 1
        extraPositions := extraPositions + report.extraUnreachable.length
        changedPositions := changedPositions + report.changedCoveredBy.length
        if knownExamples.size < 12 then knownExamples := knownExamples.push (toJson report)
    | _ => mismatches := mismatches.push (Json.mkObj [("input",toJson input), ("report",toJson report)])
  IO.FS.writeFile reportFile ((Json.mkObj [
    ("cases",toJson corpus.cases.length),("randomCases",toJson corpus.randomCases),("boundaryCases",toJson corpus.boundaryCases),
    ("matched",toJson matched),("knownQ3",toJson known),("mismatched",toJson mismatches.size),
    ("fuelExhausted",toJson fuel.total),("fuel",toJson fuel),
    ("q3ExtraPositionCases",toJson extraCases),("q3ChangedCoveredByCases",toJson changedCases),
    ("q3ExtraPositions",toJson extraPositions),("q3ChangedCoveredByPositions",toJson changedPositions),
    ("knownExamples",.arr knownExamples),("mismatches",.arr mismatches),("fuelExamples",.arr fuelExamples),
    ("boundaryResults",.arr boundary),("kinds",corpus.kinds)]).pretty ++ "\n")
  IO.println s!"coverageDiff: cases={corpus.cases.length} matched={matched} knownQ3={known} mismatched={mismatches.size} fuelExhausted={fuel.total}"
  return if mismatches.isEmpty && fuel.total == 0 then 0 else 1

end CoverageDiff

def main (args : List String) : IO UInt32 := do
  try CoverageDiff.run args catch e =>
    (← IO.getStderr).putStrLn s!"coverageDiff: {e}"
    return 2
