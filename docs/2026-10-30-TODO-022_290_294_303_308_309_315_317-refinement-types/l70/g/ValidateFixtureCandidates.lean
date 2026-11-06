import Benitoite.Exchange.Convert
import Benitoite.Exchange.Builtins
import Benitoite.Exchange.Version
import Benitoite.Interval.Exchange
open Lean Benitoite.Exchange
partial def validateHeaders : Json → Except String Unit
  | .arr xs => xs.toList.forM validateHeaders
  | j@(.obj xs) => do
      if xs.contains "effParams" && xs.contains "tparams" && !xs.contains "rkinds" then
        let h : Header ← fromJson? j
        h.validateNoFail
      xs.toArray.toList.forM (fun (_,v) => validateHeaders v)
  | _ => pure ()
def main (args : List String) : IO UInt32 := do
  let manifest ← IO.FS.readFile args[0]!
  let .ok entries := (Json.parse manifest >>= fromJson? (α := List (List String)))
    | throw (IO.userError "manifest")
  let mut errors := 0
  for row in entries do
    let [label,kind,path] := row | throw (IO.userError "row")
    let raw ← IO.FS.readFile path
    let result := if kind == "interval" then do
      let _ ← Benitoite.Interval.Exchange.readCorpus raw
      pure ()
    else do
      let j ← Json.parse raw
      let _ ← exchangeJson kind j
      if kind == "corpus" then
        let _ ← readCorpus j
        pure ()
      if kind == "builtins" then
        let _ ← readBuiltins j
        pure ()
      validateHeaders j
    let expectedRefusal := label == "tests/batch3-exchange/corpus.json"
    match result with
    | .ok () =>
      if expectedRefusal then
        errors := errors + 1
        IO.println s!"{label}: unexpected acceptance"
      else IO.println s!"{label}: ok"
    | .error e =>
      if expectedRefusal && e == "unsupported exchange field: refs" then
        IO.println s!"{label}: expected refusal ({e})"
      else
        errors := errors + 1
        IO.println s!"{label}: {e}"
  IO.println s!"entries={entries.length}, errors={errors}"
  return if errors == 0 then 0 else 1
