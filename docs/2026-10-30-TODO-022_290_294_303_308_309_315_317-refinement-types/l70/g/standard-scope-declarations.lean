import Benitoite.Exchange.CheckInput
/-! 標準表の Scope.ScopeError と、その構成子の引数から届く data の宣言（名前・構成子・引数の型・要約）を、交換の形の
JSON で書き出す。範囲の固定入力 `formal/tests/range-exchange/standard-scope-declarations.json` の `declarations` を作る。
使い方: `(cd formal && lake env lean -M 12288 --run <この台本>)`。 -/
open Lean Benitoite.Release.Refinement
/-- 型に現れる data の名前。 -/
partial def dataIn : Ty → List String
  | .data d as => d :: as.flatMap dataIn
  | .list a | .set a | .reference a | .lazy a | .refined a _ => dataIn a
  | .map k v => dataIn k ++ dataIn v
  | .fn _ ps r _ => ps.flatMap dataIn ++ dataIn r
  | _ => []
def leaf (n : String) : String := (n.splitOn ".").getLast!
def main : IO Unit := do
  let decls := StandardModel.declarations
  let mut names : List String := ["Scope.ScopeError"]
  for _ in List.range 40 do
    let more := (decls.filter (names.contains ·.name)).flatMap fun d => d.constructors.flatMap fun c => c.2.flatMap dataIn
    names := (names ++ more.filter (fun n => decls.any (·.name == n))).eraseDups
  let S := Benitoite.Release.dataSummaries (decls.map StandardKeyTyping.DataDecl.summaryInput)
  let mut out : Array Json := #[]
  for n in names do
    let some d := decls.find? (·.name == n) | continue
    let ctors ← d.constructors.mapM fun c => do
      let args ← IO.ofExcept (c.2.mapM (Benitoite.Exchange.fromTy []))
      pure (Json.mkObj [("name", toJson c.1), ("constructorName", toJson (leaf c.1)), ("args", toJson args), ("fields", Json.null)])
    let s := S.find? (·.name == n)
    out := out.push (Json.mkObj [("name", toJson n), ("ntys", toJson d.ntys), ("ctors", Json.arr ctors.toArray),
      ("summary", match s with
        | some s => Json.mkObj [("eq", Json.mkObj [("always", toJson s.eq.always), ("dependsOn", toJson s.eq.dependsOn)]),
                                ("key", Json.mkObj [("always", toJson s.key.always), ("dependsOn", toJson s.key.dependsOn)])]
        | none => Json.null)])
  IO.println (Json.arr out).compress
