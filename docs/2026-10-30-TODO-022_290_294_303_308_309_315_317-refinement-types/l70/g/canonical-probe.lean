import Benitoite.Exchange.CanonicalNames
open Lean Benitoite.Exchange

def main : IO UInt32 := do
  let input ← IO.getStdin
  let output ← IO.getStdout
  let mut failed := false
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    let result : Except String Json := do
      let record ← Json.parse line
      let source ← record.getObjValAs? Input "input"
      let builtin ← record.getObjVal? "builtin"
      let names ← CanonicalNames.ofInputs source builtin
      return Json.mkObj [("data", toJson names.dataNames), ("constructors", toJson names.constructorNames),
        ("opaque", toJson names.opaqueNames)]
    match result with
    | .ok record => output.putStrLn (Json.compress (Json.mkObj [("ok", toJson true), ("mapping", record)]))
    | .error reason =>
      failed := true
      output.putStrLn (Json.compress (Json.mkObj [("ok", toJson false), ("reason", toJson reason)]))
  return if failed then 1 else 0
