import Benitoite.Exchange.CheckInput

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
open Lean Benitoite.Exchange Benitoite.Exchange.CheckInput Benitoite.Surface.CheckTables

def errorJson (e : Benitoite.Surface.Check.Error) : Json :=
  Json.mkObj [("path", toJson e.path), ("reason", toJson e.reason)]

/-- 型付けの誤りは従来の形（`error`）、必須の判定の拒否は出現の鍵と DET-05 の理由（`cover`）で書く。 -/
def resultJson : Except Benitoite.Surface.CheckAccept.EntryError Unit → Json
  | .ok _ => Json.mkObj [("ok", toJson true)]
  | .error (.typing e) => Json.mkObj [("ok", toJson false), ("error", errorJson e)]
  | .error (.cover k f) => Json.mkObj [("ok", toJson false),
      ("cover", Json.mkObj [("key", encodeKey k), ("reason", encodeCoverFailure f)])]

def readJson (file : String) : IO Json := do
  IO.ofExcept (Json.parse (← IO.FS.readFile file))

def selectInput (j : Json) (group name : String) : Except String Json := do
  let xs ← (← j.getObjVal? "inputs").getArr?
  let some input := xs.find? fun x =>
    (x.getObjValAs? String "group").toOption == some group &&
    (x.getObjValAs? String "name").toOption == some name
    | throw s!"missing input: {group}/{name}"
  return input

/-- IO を挟んで計算し、同じ純粋な検査結果の共有を計測に混ぜない。 -/
@[noinline] def timedCheck (q : Benitoite.Surface.Check.Input) (A : Benitoite.Surface.CheckAccept.AcceptInput)
    (m : Materials) (names : Names) (selected : Option String) :
    IO (Except Benitoite.Surface.CheckAccept.EntryError Unit × Nat) := do
  let start ← IO.monoNanosNow
  -- 型検査器の入口は型付けの検査に必須の判定の受理を組み込む（`CheckAccept.checkProgramAccepted`）。
  let outcome ← match selected with
    | none => pure (Benitoite.Surface.CheckAccept.checkProgramAccepted q A m names)
    | some name =>
      let some d := m.program.defs name | throw (IO.userError s!"not an ordinary definition: {name}")
      pure <| match Benitoite.Surface.Check.checkDef { q with D := q.D.withView (m.functionViews name) } [] d with
        | .error e => .error (.typing e)
        | .ok () => match Benitoite.Surface.CheckAccept.acceptDef A name d with
          | .error (k, f) => .error (.cover k f)
          | .ok () => .ok ()
  -- 結果のタグを評価してから時計を読む。
  let encoded := (resultJson outcome).compress
  if encoded.isEmpty then throw (IO.userError "empty result")
  let stop ← IO.monoNanosNow
  return (outcome, (stop - start))

def run (args : List String) : IO UInt32 := do
  let corpusFile :: builtinFile :: stdlibFile :: group :: name :: report :: rest := args
    | throw (IO.userError "usage: surfaceCheck corpus.json builtins.json stdlib-decls.json group input report.json [fn:ID [repetitions]]")
  let (selected, repetitions) ← match rest with
    | [] => pure (none, 1)
    | [key] => pure (some key, 1)
    | [key, count] => match count.toNat? with
      | some n => if n == 0 then throw (IO.userError "repetitions must be positive") else pure (some key, n)
      | none => throw (IO.userError "invalid repetition count")
    | _ => throw (IO.userError "unexpected arguments")
  let start ← IO.monoNanosNow
  let rawCorpus ← readJson corpusFile
  let _ ← IO.ofExcept (readCorpus rawCorpus)
  let corpus ← IO.ofExcept (exchangeJson "corpus" rawCorpus)
  let version ← IO.ofExcept (corpus.getObjValAs? Nat "version")
  let inputJson ← IO.ofExcept (selectInput corpus group name)
  let input ← IO.ofExcept (fromJson? inputJson : Except String Input)
  let operators ← IO.ofExcept (corpus.getObjValAs? (List OperatorEntry) "operators")
  let rawB ← readJson builtinFile
  let _ ← IO.ofExcept (readBuiltins rawB)
  let bj ← IO.ofExcept (exchangeJson "builtins" rawB)
  let sj ← IO.ofExcept (exchangeJson "stdlib" (← readJson stdlibFile))
  let expected := sidecarVersion version
  if (← IO.ofExcept (bj.getObjValAs? Nat "version")) != expected ||
      (← IO.ofExcept (sj.getObjValAs? Nat "version")) != expected then
    throw (IO.userError "exchange version pair mismatch")
  let b ← IO.ofExcept ((selectInput bj group name).bind (fromJson? · : Json → Except String BuiltinInput))
  let s ← IO.ofExcept ((selectInput sj group name).bind (fromJson? · : Json → Except String StdlibInput))
  if version >= 9 && input.dataTypes != b.dataDecls.map DataEntry.info then
    throw (IO.userError "corpus/builtin data type metadata mismatch")
  if !input.excluded.isEmpty then throw (IO.userError s!"Rust check excluded input: {input.excluded}")
  let prepared ← IO.ofExcept (prepare input b s operators)
  if !prepared.outside.isEmpty then throw (IO.userError s!"out of scope definitions: {prepared.outside}")
  if !prepared.constructors || !prepared.records || !prepared.implNames then
    throw (IO.userError s!"table checks: constructors={prepared.constructors} records={prepared.records} implNames={prepared.implNames}")
  let ready ← IO.monoNanosNow
  let mut times : List Nat := []
  let mut result : Except Benitoite.Surface.CheckAccept.EntryError Unit := .ok ()
  for _ in List.range repetitions do
    let (outcome, ns) ← timedCheck prepared.input prepared.accept prepared.materials prepared.materials.names selected
    result := outcome
    times := times ++ [ns]
  let output := Json.mkObj [
    ("group", toJson group), ("input", toJson name), ("definition", toJson selected),
    ("preparationNanos", toJson (ready - start)), ("checkNanos", toJson times),
    ("atoms", toJson (atomsFor input b s operators)),
    ("definitions", toJson prepared.materials.defs.length),
    ("implementations", toJson prepared.materials.impls.length),
    ("trustedFunctions", toJson prepared.materials.trustedFuns.length),
    ("trustedImplementations", toJson prepared.materials.trustedImpls.length),
    ("constructorsOk", toJson prepared.constructors), ("recordsOk", toJson prepared.records),
    ("implNamesOk", toJson prepared.implNames), ("result", resultJson result)]
  IO.FS.writeFile report (output.pretty ++ "\n")
  IO.println output.compress
  return if result matches .ok _ then 0 else 1

def main (args : List String) : IO UInt32 := do
  try run args catch e =>
    (← IO.getStderr).putStrLn s!"surfaceCheck: {e}"
    return 2
