import SurfaceCheck.Validation

def main (args : List String) : IO UInt32 := do
  try SurfaceCheck.Batch.run args catch e =>
    (← IO.getStderr).putStrLn s!"surfaceCheckAll: {e}"
    if let some (report : String) := args[3]? then
      let output := Lean.Json.mkObj [("counts",Lean.Json.mkObj [("preparationFailure",Lean.toJson (1 : Nat))]),
        ("preparationErrors",Lean.toJson [e.toString])]
      IO.FS.writeFile (System.FilePath.mk report) (output.pretty ++ "\n")
    return 2
