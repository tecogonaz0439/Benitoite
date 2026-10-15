import Benitoite.Exchange.CheckInput

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
open Lean Benitoite.Exchange Benitoite.Exchange.CheckInput Benitoite.Surface.CheckTables

def errorJson (e : Benitoite.Surface.Check.Error) : Json :=
  Json.mkObj [("path", toJson e.path), ("reason", toJson e.reason)]

def resultJson : Benitoite.Surface.Check.Result Unit → Json
  | .ok _ => Json.mkObj [("ok", toJson true)]
  | .error e => Json.mkObj [("ok", toJson false), ("error", errorJson e)]

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
@[noinline] def timedCheck (q : Benitoite.Surface.Check.Input)
    (m : Materials) (names : Names) (selected : Option String) :
    IO (Benitoite.Surface.Check.Result Unit × Nat) := do
  let start ← IO.monoNanosNow
  let outcome ← match selected with
    | none => pure (checkProgram q m names)
    | some name =>
      let some d := m.program.defs name | throw (IO.userError s!"not an ordinary definition: {name}")
      pure (Benitoite.Surface.Check.checkDef q [] d)
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
  let corpus ← readJson corpusFile
  let version ← IO.ofExcept (corpus.getObjValAs? Nat "version")
  if version != 8 then throw (IO.userError "unsupported corpus version")
  let inputJson ← IO.ofExcept (selectInput corpus group name)
  let input ← IO.ofExcept (fromJson? inputJson : Except String Input)
  let operators ← IO.ofExcept (corpus.getObjValAs? (List OperatorEntry) "operators")
  let bj ← readJson builtinFile
  let sj ← readJson stdlibFile
  if (← IO.ofExcept (bj.getObjValAs? Nat "version")) != 2 ||
      (← IO.ofExcept (sj.getObjValAs? Nat "version")) != 2 then
    throw (IO.userError "unsupported sidecar version")
  let b ← IO.ofExcept ((selectInput bj group name).bind (fromJson? · : Json → Except String BuiltinInput))
  let s ← IO.ofExcept ((selectInput sj group name).bind (fromJson? · : Json → Except String StdlibInput))
  if !input.excluded.isEmpty then throw (IO.userError s!"Rust check excluded input: {input.excluded}")
  let prepared ← IO.ofExcept (prepare input b s operators)
  if !prepared.outside.isEmpty then throw (IO.userError s!"out of scope definitions: {prepared.outside}")
  if !prepared.constructors || !prepared.records || !prepared.implNames then
    throw (IO.userError s!"table checks: constructors={prepared.constructors} records={prepared.records} implNames={prepared.implNames}")
  let ready ← IO.monoNanosNow
  let mut times : List Nat := []
  let mut result : Benitoite.Surface.Check.Result Unit := .ok ()
  for _ in List.range repetitions do
    let (outcome, ns) ← timedCheck prepared.input prepared.materials prepared.materials.names selected
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
  return if result.isOk then 0 else 1

def main (args : List String) : IO UInt32 := do
  try run args catch e =>
    (← IO.getStderr).putStrLn s!"surfaceCheck: {e}"
    return 2
