import Lean
import Benitoite

/-! 群 B の読者の照合。主な定理の型と証明の定数の推移閉包（private の宣言を含む）に、義務の表が名指す葉が含まれるかを数える。
読む名前の組は `readers.json`（`{"根": [...], "葉": [...]}`）から読む。具体値の評価をしない。 -/
open Lean Elab Command in
run_cmd do
  let records := "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/b/"
  let raw ← IO.FS.readFile (records ++ "readers.json")
  let json ← ofExcept (Json.parse raw)
  let roots ← ofExcept (json.getObjValAs? (List String) "roots")
  let leaves ← ofExcept (json.getObjValAs? (List String) "leaves")
  let env ← getEnv
  for root in roots do
    let mut seen : Std.HashSet Name := {}
    let mut todo : Array Name := #[root.toName]
    while h : todo.size > 0 do
      let n := todo.back
      todo := todo.pop
      if seen.contains n then continue
      seen := seen.insert n
      let some ci := env.find? n | throwError "READER_MISSING {n}"
      let used := ci.type.getUsedConstants ++ ((ci.value? (allowOpaque := true)).map (·.getUsedConstants) |>.getD #[])
      for m in used do
        if (`Benitoite).isPrefixOf ((privateToUserName? m).getD m) && !seen.contains m then todo := todo.push m
    logInfo m!"READER_CLOSURE {root} {seen.size}"
    for leaf in leaves do
      logInfo m!"READER {root} {leaf} {seen.contains leaf.toName}"
