import Benitoite.Exchange.Convert
import Benitoite.Exchange.Version
import Benitoite.Surface.Check
import Benitoite.Release.Examples

/-! 穴のLetとblockの独立した交換入力。設計書01-12「表層のブロック式」に対応する。
本番Rustの書き出しや旧corpusの移行は、この局所比較の範囲に含めない。 -/
open Lean Benitoite.Exchange

private def versioned (version : Nat) (payload : Json) : Json :=
  Json.mkObj [("version", toJson version), ("payload", payload)]

private def q : Benitoite.Surface.Check.Input :=
  { D := { funs := fun _ => none, cons := fun _ => none },
    B := Benitoite.Release.Examples.builtins, satDec := fun _ _ _ => true,
    admitsDec := fun _ _ _ => true, opPrim := fun _ _ => none, ctors := fun _ => [], atoms := [] }

private def checkCore (j : Json) : Except String Unit := do
  let raw ← j.getObjVal? "surface"
  let expr ← (← decodeExpr raw).toSurface []
  let pos ← j.getObjValAs? String "position"
  let core := Benitoite.Surface.desugarExpr (fun _ _ => none) (if pos == "tail" then .tail else .other) expr
  let actual := encodeComp (← fromComp [] (fun _ => 0) core)
  let expected ← j.getObjVal? "expected"
  if actual != expected then throw s!"core mismatch: {actual.compress} != {expected.compress}"
  let _ ← exchangeJson "corpus" (versioned 13 raw)
  if (rejectFields ["block"] raw).isOk then return
  for version in [8, 9, 10, 11, 12] do
    if (exchangeJson "corpus" (versioned version raw)).isOk then
      throw s!"old corpus {version} accepted block"
  for version in [2, 3, 4, 5] do
    if (exchangeJson "stdlib" (versioned version raw)).isOk then
      throw s!"sidecar {version} accepted block"

private def checkRejection (j : Json) : Except String Unit := do
  let expr ← (← decodeExpr (← j.getObjVal? "surface")).toSurface []
  let expected ← j.getObjVal? "error"
  for mode in [Benitoite.Surface.Check.ResumeMode.strict, .relaxed] do
    match Benitoite.Surface.Check.checkExpr q mode [] [] none .other [] expr with
    | .ok _ => throw "accepted escaping builder"
    | .error e =>
      let actual := Json.mkObj [("path", toJson e.path), ("reason", toJson e.reason)]
      if actual != expected then throw s!"rejection mismatch: {actual.compress} != {expected.compress}"

def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "expected exchange-cases.json")
  let j ← IO.ofExcept (Json.parse (← IO.FS.readFile path))
  let cases ← IO.ofExcept ((← IO.ofExcept (j.getObjVal? "cases")).getArr?)
  let rejects ← IO.ofExcept ((← IO.ofExcept (j.getObjVal? "rejections")).getArr?)
  for c in cases do
    let name ← IO.ofExcept (c.getObjValAs? String "name")
    IO.ofExcept ((checkCore c).mapError (fun e => s!"{name}: {e}"))
  for c in rejects do
    let name ← IO.ofExcept (c.getObjValAs? String "name")
    IO.ofExcept ((checkRejection c).mapError (fun e => s!"{name}: {e}"))
  for raw in ["{\"block\":{\"body\":\"empty\",\"extra\":0}}",
      "{\"block\":{\"extra\":\"empty\"}}",
      "{\"block\":{\"body\":\"empty\"},\"unit\":null}"] do
    if (decodeExpr (← IO.ofExcept (Json.parse raw))).isOk then
      throw (IO.userError "accepted malformed block")
  IO.println s!"{cases.size} exact cores, {rejects.size} rejections in strict/relaxed, old versions and 3 malformed blocks: ok"
