import Benitoite.Exchange.Convert
import Benitoite.Exchange.Builtins
import Benitoite.Exchange.Version
import Benitoite.Interval.Exchange
open Lean Benitoite.Exchange

/-! 処理系の書き出しを、交換の版16/8の Lean の読者と表層への変換で読む検査の台本。

既定ビルドに含めない。`formal/` から `lake env lean -M 12288 --run <この台本> <manifest>` で実行する。
manifest は `prepare.py` が作る `[種類, パス]` の列である。入口の構造（stdlib・網羅性）は入口の定義と同じ欄を写す。 -/

structure FunEntryV where
  name : String
  header : Header
  dictParams : List (String × Nat)
  deriving ToJson, FromJson
structure TrustedImplV where
  signature : ImplEntry
  methods : List String
  supers : List String
  deriving ToJson, FromJson
structure StdlibInputV where
  group : String
  name : String
  functions : List FunEntryV
  impls : List TrustedImplV
  deriving ToJson, FromJson
structure StdlibCorpusV where
  version : Nat
  inputs : List StdlibInputV
  deriving ToJson, FromJson

structure RawArmP where
  alts : List Pattern
  guarded : Bool
  deriving FromJson, ToJson
structure RawMatchP where
  package : String
  coverageView : List String
  node : Nat
  scrutineeTy : Benitoite.Exchange.Ty
  arms : List RawArmP
  deriving FromJson, ToJson
structure RawBindingP where
  package : String
  coverageView : List String
  node : Nat
  kind : String
  ty : Benitoite.Exchange.Ty
  pattern : Pattern
  deriving FromJson, ToJson
structure InputP where
  group : String
  name : String
  «matches» : List RawMatchP
  bindings : List RawBindingP
  deriving FromJson, ToJson
structure CorpusP where
  version : Nat
  inputs : List InputP
  deriving FromJson

structure RawCtorC where
  name : String
  constructorName : String
  tag : Nat
  args : List Json
  deriving FromJson, ToJson
structure RawDeclC where
  builtin : Benitoite.Exchange.BuiltinData
  package : String
  extensible : Bool
  isRecord : Bool
  name : String
  typeName : String
  ntys : Nat
  fields : Option (List String)
  ctors : List RawCtorC
  deriving FromJson, ToJson
structure RawArmC where
  guarded : Bool
  alts : List Json
  deriving FromJson, ToJson
structure UnreachableC where
  arm : Nat
  alt : Nat
  coveredBy : List Nat
  deriving FromJson, ToJson
structure ResultC where
  exhaustive : Bool
  uncovered : Option String
  unreachable : List UnreachableC
  deriving FromJson, ToJson
structure InputC where
  package : String
  coverageView : List String
  name : String
  decls : List RawDeclC
  ty : Json
  arms : List RawArmC
  pattern : Json
  expected : ResultC
  irrefutable : Bool
  irrefutableWitness : Option String
  deriving FromJson, ToJson
structure CorpusC where
  version : Nat
  seedXor : Nat
  randomCases : Nat
  boundaryCases : Nat
  kinds : Json
  cases : List InputC
  deriving FromJson, ToJson

partial def firstDiff (path : String) (a b : Json) : Option String :=
  match a, b with
  | .obj xs, .obj ys =>
      let ks := (xs.toArray.map (·.1)).toList
      let ls := (ys.toArray.map (·.1)).toList
      match ks.find? (fun k => !ls.contains k) with
      | some k => some s!"{path}/{k}: only in written"
      | none => match ls.find? (fun k => !ks.contains k) with
        | some k => some s!"{path}/{k}: only in input"
        | none => ks.findSome? (fun k => firstDiff s!"{path}/{k}" ((a.getObjVal? k).toOption.getD .null) ((b.getObjVal? k).toOption.getD .null))
  | .arr xs, .arr ys =>
      if xs.size != ys.size then some s!"{path}: length {xs.size} vs {ys.size}"
      else (List.range xs.size).findSome? (fun i => firstDiff s!"{path}[{i}]" xs[i]! ys[i]!)
  | x, y => if x == y then none else some s!"{path}: {x.compress.take 200} vs {y.compress.take 200}"

def explainInputs (j : Json) : Except String Unit := do
  for x in (← (← j.getObjVal? "inputs").getArr?) do
    let i : Input ← fromJson? x
    if let some d := firstDiff "" (toJson i) x then
      throw s!"{(x.getObjValAs? String "name").toOption.getD "?"}: {d}"

/-- 種類の列のうち構成子の種類の個数と、その型引数の数の和。 -/
def constructorKinds (ks : List Benitoite.Release.Refinement.TyKind) : Nat × Nat :=
  ks.foldl (fun (n, a) k => match k with | .constructor m => (n + 1, a + m) | .value => (n, a)) (0, 0)

/-- 範囲内の定義の数と、表層へ変換した頭部の型パラメータ・型クラスの引数の構成子の種類の集計
（`kinds=個数:型引数の数の和 classes=個数:型引数の数の和`）。 -/
def checkCorpus (j : Json) : Except String (Nat × String) := do
  match readCorpus j with
  | .error e => if e == "unexpected input syntax fields" then explainInputs j; throw e else throw e
  | .ok _ => pure ()
  let c ← readCorpus j
  let mut n := 0
  let mut kinds := (0, 0)
  let mut classes := (0, 0)
  for input in c.inputs do
    if !input.excluded.isEmpty then
      if !input.definitions.isEmpty then throw s!"{input.name}: excluded input has definitions"
      continue
    let _ ← (input.operationProgram).mapError (fun e => s!"{input.name}: operationProgram: {e}")
    let (cn, ca) := constructorKinds (input.classes.map (·.argumentKind))
    classes := (classes.1 + cn, classes.2 + ca)
    let constants ← (input.constantCache).mapError (fun e => s!"{input.name}: constants: {e}")
    for d in input.definitions do
      match d.scope with
      | .inScope s _ =>
          let sd ← (s.toSurface constants).mapError (fun e => s!"{input.name}: {d.name}: {e}")
          let (kn, ka) := constructorKinds (sd.tparams.map (·.kind))
          kinds := (kinds.1 + kn, kinds.2 + ka)
          n := n + 1
      | _ => pure ()
  return (n, s!"kinds={kinds.1}:{kinds.2} classes={classes.1}:{classes.2}")

def checkBuiltins (j : Json) : Except String Nat := do
  let c ← readBuiltins j
  let mut n := 0
  for i in c.inputs do
    -- builtinCheck と同じく、不透明型の引数と型クラスの制約を持つ項目は材料にしない（印の一致だけを見る）。
    for p in i.prims do
      let opaqueArgs ← (p.hasOpaqueArguments).mapError (fun e => s!"{i.name}: {p.name}: {e}")
      if opaqueArgs != !p.unconvertibleTypes.isEmpty then throw s!"{i.name}: {p.name}: incorrect opaque arguments flag"
      if !opaqueArgs && p.classConstraints.isEmpty then
        let _ ← (p.toMaterial).mapError (fun e => s!"{i.name}: {p.name}: {e}")
        n := n + 1
    for d in i.dataDecls do
      let _ ← (d.toMaterial).mapError (fun e => s!"{i.name}: {d.name}: {e}")
  return n

def checkStdlib (j : Json) : Except String Nat := do
  let raw ← exchangeJson "stdlib" j
  let c : StdlibCorpusV ← fromJson? raw
  if toJson c != raw then throw "unexpected stdlib fields"
  let mut n := 0
  for i in c.inputs do
    for f in i.functions do
      f.header.validateNoFail
      n := n + 1
  return n

def checkCoverageProgram (j : Json) : Except String Nat := do
  let raw ← exchangeJson "coverage-program" j
  let c : CorpusP ← fromJson? raw
  let mut n := 0
  for i in c.inputs do
    for m in i.matches do
      let _ ← m.scrutineeTy.toRelease
      for a in m.arms do
        for p in a.alts do let _ ← p.toSurface
      n := n + 1
    for b in i.bindings do
      let _ ← b.ty.toRelease
      let _ ← b.pattern.toSurface
      n := n + 1
  return n

def checkCoverage (j : Json) : Except String Nat := do
  let raw ← exchangeJson "coverage" j
  let c : CorpusC ← fromJson? raw
  return c.cases.length

def main (args : List String) : IO UInt32 := do
  let [manifest] := args | throw (IO.userError "usage: Validate manifest.json")
  let .ok (entries : List (List String)) := (Json.parse (← IO.FS.readFile manifest) >>= fromJson?)
    | throw (IO.userError "manifest")
  let mut errors := 0
  for row in entries do
    let [kind, path] := row | throw (IO.userError "row")
    let raw ← IO.FS.readFile path
    let result : Except String (Nat × String) := if kind == "interval" then do
        let c ← Benitoite.Interval.Exchange.readCorpus raw
        pure (c.inputs.length, "")
      else do
        let j ← Json.parse raw
        match kind with
        | "corpus" => checkCorpus j
        | "builtins" => return (← checkBuiltins j, "")
        | "stdlib" => return (← checkStdlib j, "")
        | "coverage-program" => return (← checkCoverageProgram j, "")
        | "coverage" => return (← checkCoverage j, "")
        | k => throw s!"unknown kind {k}"
    match result with
    | .ok (n, extra) => IO.println s!"ok {kind} {n} {path} {extra}"
    | .error e =>
        errors := errors + 1
        IO.println s!"ERROR {kind} {path}: {e.take 600}"
  IO.println s!"entries={entries.length}, errors={errors}"
  return if errors == 0 then 0 else 1
