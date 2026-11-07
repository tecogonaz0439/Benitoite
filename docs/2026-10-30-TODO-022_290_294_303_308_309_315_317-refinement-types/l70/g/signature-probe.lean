import Benitoite.Exchange.CheckInput
open Lean Benitoite.Exchange
def tj (atoms : Eff) (t : Benitoite.Release.Refinement.Ty) : String :=
  match fromTy atoms t with | .ok x => (toJson x).compress | .error e => "ERR " ++ e
def show1 (atoms : Eff) (s : Benitoite.Release.Refinement.PrimSig) : String :=
  s!"names={s.names} neffs={s.neffs} opEff={s.opEff} ntp={s.tparams.length} params={s.params.map (tj atoms)} ret={tj atoms s.ret} rows={s.eff.fails.length}"
def main : IO Unit := do
  let F := "<tmp>/fixture-candidates/test_range_exchange-fixtures-"
  let c ← IO.ofExcept (Json.parse (← IO.FS.readFile (F ++ "corpus.json")))
  let b ← IO.ofExcept (Json.parse (← IO.FS.readFile (F ++ "builtins.json")))
  let bj ← IO.ofExcept ((b.getObjValAs? (Array Json) "inputs").map (·[0]!))
  let ij ← IO.ofExcept ((c.getObjValAs? (Array Json) "inputs").map (·[0]!))
  let input : Input ← IO.ofExcept (fromJson? ij)
  let bi : BuiltinInput ← IO.ofExcept (fromJson? bj)
  let names ← IO.ofExcept (CanonicalNames.ofInputs input (toJson bi))
  IO.println s!"opaque={names.opaqueNames}"
  let bc : BuiltinInput ← IO.ofExcept (fromJson? (names.json (toJson bi)))
  for p in bc.prims do
    if p.name == "File.writeTextIn" || p.name == "Scope.checkPathIn" then
      let m ← IO.ofExcept p.toMaterial
      let aa := collectAtoms (toJson bc)
      IO.println s!"{p.name} exchange ret={tj aa m.ret} params={m.params.map (tj aa)} opEff={m.opEff} names={m.names}"
      match BuiltinAgreement.standardSig p.name with
      | some s => IO.println ("standard " ++ show1 (collectAtoms (toJson bc)) s)
      | none => IO.println "no standard"
