import Benitoite.Exchange.CheckInput
open Lean Benitoite.Exchange Benitoite.Exchange.CheckInput

/-! 表層の一括検査（`SurfaceCheck.Batch.run`）の準備の段だけを、同じ順と同じ判定で各入力に当てて一行ずつ書く。
検査の本体は流さない。閉包の data を、構成子の引数だけを辿る前の段（`oldStep`）と今の段（`dataStep`）の両方で
作り、違いを書く。 -/

/-- 構成子の引数だけを辿る前の段。 -/
def oldStep (b : BuiltinInput) (names : List String) : List String :=
  let reached := (b.dataDecls.filter fun d => names.contains d.name).flatMap fun d => jsonStrings (toJson d.ctors)
  (names ++ dataNamed b (Std.HashSet.ofList reached)).eraseDups

/-- `closureOf` の data の部分を、段の関数を引数にして作る（`closureOf` と同じ式）。 -/
def closureData (step : BuiltinInput → List String → List String)
    (input : Input) (b : BuiltinInput) (s : StdlibInput) (operators : List OperatorEntry) : List String :=
  let (values0, keys) := surfaceWords (#[], #[]) (toJson { input with impls := [] })
  let named := Std.HashSet.ofArray values0
  let trusted := Std.HashSet.ofList (s.impls.map (·.signature.name))
  let values := values0 ++ (jsonStrings (toJson (input.impls.filter fun i =>
    !trusted.contains i.name || named.contains i.name))).toArray
  let used := Std.HashSet.ofArray values
  let words := Std.HashSet.ofArray (values ++ keys)
  let funs := s.functions.filter fun f => used.contains f.name
  let opPrims := Std.HashSet.ofList ((operators.filter fun o => words.contains o.op).map (·.name))
  let prims := b.prims.filter fun p => used.contains p.name || opPrims.contains p.name
  let typed := Std.HashSet.ofList (values.toList ++ jsonStrings (toJson (funs.map (·.header))) ++
    jsonStrings (toJson prims))
  (List.range (b.dataDecls.length + 1)).foldl (fun names _ => step b names) (dataNamed b typed).eraseDups

partial def hasKey (key : String) : Json → Bool
  | .arr xs => xs.any (hasKey key)
  | .obj xs => xs.toArray.any fun (k, v) => k == key || hasKey key v
  | _ => false

def main (args : List String) : IO UInt32 := do
  let [doc, cf, bf, sf] := args | throw (IO.userError "usage: doc corpus builtins stdlib")
  let read (f : String) : IO Json := do IO.ofExcept (Json.parse (← IO.FS.readFile f))
  let line (fields : List (String × Json)) : IO Unit :=
    IO.println (Json.compress (Json.mkObj (("doc", toJson doc) :: fields)))
  let raw ← read cf
  let rawB ← read bf
  let rawS ← read sf
  let pre : Except String (Array Json × Array Json × Array Json × List OperatorEntry) := do
    let c ← readCorpus raw
    let corpus ← exchangeJson "corpus" raw
    let bc ← readBuiltins rawB
    let bj ← exchangeJson "builtins" rawB
    let sj ← exchangeJson "stdlib" rawS
    let expected := sidecarVersion
    if bc.version != expected || (← sj.getObjValAs? Nat "version") != expected then
      throw "exchange version pair mismatch"
    for i in c.inputs.filter (fun i => i.excluded.isEmpty) do
      let some bi := bc.inputs.find? (fun bi => bi.group == i.group && bi.name == i.name)
        | throw "missing builtin input"
      if i.dataTypes != bi.dataDecls.map DataEntry.info then
        throw "corpus/builtin data type metadata mismatch"
    return (← (corpus.getObjVal? "inputs").bind Json.getArr?, ← (bj.getObjVal? "inputs").bind Json.getArr?,
      ← (sj.getObjVal? "inputs").bind Json.getArr?, ← corpus.getObjValAs? (List OperatorEntry) "operators")
  match pre with
  | .error e => line [("document", toJson e)]; return 0
  | .ok (inputs, bs, ss, ops) =>
  let mut eligible := 0
  for j in inputs do
    let excluded ← IO.ofExcept (j.getObjValAs? (List String) "excluded")
    if !excluded.isEmpty then continue
    let parsed : Except String (Input × BuiltinInput × StdlibInput) := do
      let input ← (fromJson? j : Except String Input)
      let some bj := bs[eligible]? | throw "missing builtin input"
      let some sj := ss[eligible]? | throw "missing stdlib input"
      return (input, ← (fromJson? bj : Except String BuiltinInput), ← (fromJson? sj : Except String StdlibInput))
    -- 閉包の data の新旧（`prepareParts` と同じく、名前を写した表の上で作る）。
    let diff : Option (List String × List String) := (do
      let (input, b, s) ← parsed
      let names ← CanonicalNames.ofInputs input (toJson b)
      let bc : BuiltinInput ← fromJson? (names.json (toJson b))
      let inputC : Input ← fromJson? (names.json (toJson input))
      let sC : StdlibInput ← fromJson? (names.json (toJson s))
      let operatorsC : List OperatorEntry ← fromJson? (names.json (toJson ops))
      let new := closureData dataStep inputC bc sC operatorsC
      let old := closureData oldStep inputC bc sC operatorsC
      return (new.filter (!old.contains ·), old.filter (!new.contains ·)) : Except String _).toOption
    let r : Except String Unit := do
      let (input, b, s) ← parsed
      let p ← prepare input b s ops
      if !p.constructors || !p.records || !p.implNames then throw "invalid declaration tables"
      if p.materials.effects.any (fun (n,_) => (p.input.B.effects n).isSome) then
        throw "effect name overlaps a builtin effect"
    let refined := hasKey "predicate" (bs[eligible]?.getD Json.null)
    eligible := eligible + 1
    let g := (j.getObjValAs? String "group").toOption.getD ""
    let n := (j.getObjValAs? String "name").toOption.getD ""
    let error := match r with | .ok () => Json.null | .error e => toJson e
    line [("group", toJson g), ("name", toJson n), ("error", error),
      ("added", toJson (diff.map (·.1))), ("removed", toJson (diff.map (·.2))), ("builtinPredicate", toJson refined)]
  if bs.size != eligible || ss.size != eligible then line [("document", toJson "sidecar input count mismatch")]
  return 0
