import Benitoite.Exchange.Builtins

/-! E2a-1 の交換の境界と、宣言から求めた Lean の要約を検査する。
既存の脱糖の比較と report.json は変更しない。 -/
open Lean Benitoite.Exchange

/-- 表層・コアの交換形式の参照を辿る。型の data 名は構成子名と混同しない。 -/
partial def namesAt (tags : List String) : Json → List String
  | .arr xs => xs.toList.flatMap (namesAt tags)
  | j@(.obj xs) =>
      (tags.filterMap (fun tag => (j.getObjVal? tag >>= (·.getObjVal? "name") >>= fromJson?).toOption)) ++
        xs.toArray.toList.flatMap (fun (_, v) => namesAt tags v)
  | _ => []

/-- 不一致の例は、型ごと・等値と鍵ごとに両方の要約を残す。 -/
structure SummaryMismatch where
  dataName : String
  bound : String
  computed : TypeSummary
  exported : TypeSummary
  deriving ToJson

structure InputReport where
  group : String
  name : String
  prims : Nat
  converted : Nat
  dataDecls : Nat
  constructors : Nat
  missingPrims : List String
  missingConstructors : List String
  unconvertible : List String
  typeclassExcluded : List String
  statePure : List String
  summaryComparisons : Nat
  summaryMismatches : List SummaryMismatch
  summariesConverged : Bool
  errors : List String
  deriving ToJson

def duplicateNames (xs : List String) : Bool := xs.eraseDups.length != xs.length

/-- 処理系は always が真でも依存を残す。真のときは依存を比較しない。
偽のときは昇順で重複のない集合として比較する。 -/
def summaryMatches (s : Benitoite.Release.BoundSummary) (e : TypeSummary) : Bool :=
  s.always == e.always && (s.always || s.dependsOn == e.dependsOn.mergeSort.eraseDups)

def summaryForReport (s : Benitoite.Release.BoundSummary) : TypeSummary :=
  ⟨s.always, s.dependsOn⟩

def validate (input : Input) (b : BuiltinInput) : InputReport := Id.run do
  let mut errors : List String := []
  let mut converted := 0
  let mut unconvertible : List String := []
  let mut typeclassExcluded : List String := []
  let mut ds : List DataMaterial := []
  if duplicateNames (b.prims.map BuiltinEntry.name) then errors := errors ++ ["duplicate prim"]
  if duplicateNames (b.effects.map EffectEntry.name) then errors := errors ++ ["duplicate effect"]
  if duplicateNames (b.dataDecls.map DataEntry.name) then errors := errors ++ ["duplicate data type"]
  if duplicateNames (b.dataDecls.flatMap (fun d => d.ctors.map DataCtorEntry.name)) then
    errors := errors ++ ["duplicate constructor"]
  if b.effectOps "State" != some [] then errors := errors ++ ["State must have no operations"]
  for p in b.prims do
    match (p.params ++ [p.ret]).forM (Ty.checkDataNames b.dataDecls) with
    | .error e => errors := errors ++ [s!"{p.name}: {e}"]
    | .ok _ => pure ()
    match p.hasOpaqueArguments with
    | .error e => errors := errors ++ [s!"{p.name}: {e}"]
    | .ok opaqueArgs =>
      if opaqueArgs != !p.unconvertibleTypes.isEmpty then
        errors := errors ++ [s!"{p.name}: incorrect opaque arguments flag"]
      if opaqueArgs then unconvertible := unconvertible ++ [p.name]
      if !p.classConstraints.isEmpty then typeclassExcluded := typeclassExcluded ++ [p.name]
      if !opaqueArgs && p.classConstraints.isEmpty then
        match p.toMaterial with
        | .ok _ => converted := converted + 1
        | .error e => errors := errors ++ [s!"{p.name}: {e}"]
    match primKind p.kind with
    | .error e => errors := errors ++ [e]
    | .ok k =>
      if (k == .io || k == .exit) != p.opEff.isSome then
        errors := errors ++ [s!"{p.name}: kind/opEff mismatch"]
    if let some l := p.opEff then
      if p.eff != [.name l] || p.neffs != 0 ||
          !((b.effectOps l).getD []).contains p.name then
        errors := errors ++ [s!"{p.name}: invalid operation effect"]
  for e in b.effects do
    if duplicateNames e.ops then errors := errors ++ [s!"{e.name}: duplicate operation"]
    for name in e.ops do
      if !(b.prims.any (fun p => p.name == name && p.opEff == some e.name)) then
        errors := errors ++ [s!"{e.name}: missing operation {name}"]
  -- 使用されない操作も、既存 corpus の節のシグネチャ表と対応させる。
  for op in input.primOps do
    match b.prims.find? (fun p => p.name == op.name) with
    | none => errors := errors ++ [s!"missing builtin operation: {op.name}"]
    | some p =>
      if p.opEff.isNone || p.params.length != op.arity || p.tparams.length != op.ntys then
        errors := errors ++ [s!"{op.name}: operation signature mismatch"]
  if duplicateNames b.statePure ||
      b.statePure.any (fun n => !b.prims.any (fun p => p.name == n && p.kind == "pure")) then
    errors := errors ++ ["invalid State/pure function list"]
  for d in b.dataDecls do
    match (d.ctors.flatMap DataCtorEntry.args).forM (Ty.checkDataNames b.dataDecls) with
    | .error e => errors := errors ++ [s!"{d.name}: {e}"]
    | .ok _ => pure ()
    match d.toMaterial with
    | .ok m => ds := ds ++ [m]
    | .error e => errors := errors ++ [s!"{d.name}: {e}"]
  if duplicateNames (b.summaries.map DataSummary.name) ||
      (b.summaries.map DataSummary.name) != (b.dataDecls.map DataEntry.name) then
    errors := errors ++ ["summary/data declaration mismatch"]
  for s in b.summaries do
    let n := ((b.dataDecls.find? (fun d => d.name == s.name)).map DataEntry.ntys).getD 0
    if (s.eq.dependsOn ++ s.key.dependsOn).any (· >= n) then
      errors := errors ++ [s!"{s.name}: summary parameter outside declaration"]
  let decls := ds.map DataMaterial.toBuiltinDataDecl
  let S := Benitoite.Release.dataSummaries decls
  let converged := Benitoite.Release.summariesConverged decls S
  let mut comparisons := 0
  let mut mismatches : List SummaryMismatch := []
  for e in b.summaries do
    match S.find? (fun s => s.name == e.name) with
    | none => errors := errors ++ [s!"{e.name}: missing computed summary"]
    | some s =>
      for (bound, computed, exported) in [("eq", s.eq, e.eq), ("key", s.key, e.key)] do
        comparisons := comparisons + 1
        if !summaryMatches computed exported then
          mismatches := mismatches ++ [⟨e.name, bound, summaryForReport computed, exported⟩]
  match mkBuiltins b with
  | .error e => errors := errors ++ [s!"mkBuiltins: {e}"]
  | .ok _ => pure ()
  let raw := toJson input
  let used := (namesAt ["prim", "primName"] raw).eraseDups
  let cons := (namesAt ["con", "conValue", "conCall", "record", "recordUpdate"] raw).eraseDups
  -- accessor は con を構造体の欄として持つ（タグの内部の name ではない）。
  let accessors := input.definitions.filterMap (fun d => match d.scope with
    | .accessor _ con _ _ _ => some con | _ => none)
  let missingPrims := used.filter (fun n => !b.prims.any (fun p => p.name == n))
  let missingConstructors := (cons ++ accessors).eraseDups.filter (fun n => (constructorDecl ds n).isNone)
  return {
    group := input.group, name := input.name, prims := b.prims.length,
    converted := converted, dataDecls := ds.length, constructors := (ds.flatMap DataMaterial.ctors).length,
    missingPrims := missingPrims, missingConstructors := missingConstructors,
    unconvertible := unconvertible, typeclassExcluded := typeclassExcluded,
    statePure := b.statePure, summaryComparisons := comparisons, summaryMismatches := mismatches,
    summariesConverged := converged, errors := errors }

def run (args : List String) : IO UInt32 := do
  let [corpusFile, tableFile, reportFile] := args |
    throw (IO.userError "usage: builtinCheck corpus.json builtins.json builtin-report.json")
  let corpus ← IO.ofExcept ((Json.parse (← IO.FS.readFile corpusFile)) >>= fromJson? : Except String Corpus)
  let tables ← IO.ofExcept ((Json.parse (← IO.FS.readFile tableFile)) >>= fromJson? : Except String BuiltinCorpus)
  if corpus.version != 7 || tables.version != 1 then throw (IO.userError "unsupported exchange version")
  if duplicateNames (tables.inputs.map (fun b => s!"{b.group}/{b.name}")) then
    throw (IO.userError "duplicate input table")
  let checked := corpus.inputs.filter (fun i => i.excluded.isEmpty)
  if tables.inputs.length != checked.length then throw (IO.userError "input table count mismatch")
  let mut reports : List InputReport := []
  for input in checked do
    let some b := tables.inputs.find? (fun b => b.group == input.group && b.name == input.name) |
      throw (IO.userError s!"missing input table: {input.group}/{input.name}")
    reports := reports ++ [validate input b]
  let missing := (reports.flatMap InputReport.missingPrims).eraseDups
  let missingCons := (reports.flatMap InputReport.missingConstructors).eraseDups
  let unconvertible := (reports.flatMap InputReport.unconvertible).eraseDups
  let excluded := (reports.flatMap InputReport.typeclassExcluded).eraseDups
  let statePure := (reports.flatMap InputReport.statePure).eraseDups
  let errors := reports.flatMap (fun r => r.errors.map (fun e => s!"{r.group}/{r.name}: {e}"))
  let comparisons := (reports.map InputReport.summaryComparisons).foldl (· + ·) 0
  let mismatchCount := (reports.map (fun r => r.summaryMismatches.length)).foldl (· + ·) 0
  let nonconverged := reports.filter (fun r => !r.summariesConverged)
  let mismatchExamples := reports.flatMap (fun r => r.summaryMismatches.map (fun m =>
    Json.mkObj [("group", toJson r.group), ("name", toJson r.name), ("mismatch", toJson m)]))
  IO.FS.writeFile reportFile ((Json.mkObj [
    ("inputs", toJson reports), ("checkedInputs", toJson reports.length),
    ("missingPrims", toJson missing), ("missingConstructors", toJson missingCons),
    ("unconvertible", toJson unconvertible), ("typeclassExcluded", toJson excluded),
    ("statePure", toJson statePure), ("summaryComparisons", toJson comparisons),
    ("summaryMismatchCount", toJson mismatchCount), ("summaryMismatchExamples", toJson (mismatchExamples.take 10)),
    ("nonconvergedCount", toJson nonconverged.length),
    ("nonconvergedInputs", toJson (nonconverged.map (fun r => s!"{r.group}/{r.name}"))),
    ("errors", toJson errors)]).pretty ++ "\n")
  IO.println s!"builtinCheck: inputs={reports.length}, prim entries={(reports.map InputReport.prims).foldl (· + ·) 0}, converted={(reports.map InputReport.converted).foldl (· + ·) 0}"
  IO.println s!"missing prims: {toJson missing}; missing constructors: {toJson missingCons}"
  IO.println s!"unconvertible opaque arguments: {toJson unconvertible}"
  IO.println s!"typeclass constraints (excluded): {toJson excluded}"
  IO.println s!"State functions represented as pure: {toJson statePure}"
  IO.println s!"summary comparisons: {comparisons}; mismatches: {mismatchCount}; nonconverged inputs: {nonconverged.length}"
  for e in mismatchExamples.take 10 do IO.println s!"summary mismatch: {e.compress}"
  for r in nonconverged do IO.println s!"summary did not converge: {r.group}/{r.name}"
  for e in errors do IO.println s!"error: {e}"
  return if missing.isEmpty && missingCons.isEmpty && errors.isEmpty &&
      mismatchCount == 0 && nonconverged.isEmpty then 0 else 1

def main (args : List String) : IO UInt32 := do
  try run args catch e =>
    (← IO.getStderr).putStrLn s!"builtinCheck: {e}"
    return 2
