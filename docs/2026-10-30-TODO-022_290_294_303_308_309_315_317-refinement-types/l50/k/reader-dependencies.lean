import Benitoite
import Lean

/- 型と値に現れる定数の辺を、既定環境から抽出する。 -/
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (n, ci) in env.constants.toList.mergeSort (fun a b => a.1.toString < b.1.toString) do
    let some idx := env.getModuleIdxFor? n | continue
    let mod := env.header.moduleNames[idx.toNat]!.toString
    unless mod.startsWith "Benitoite" do continue
    let mut deps := ci.type.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
    if let some value := ci.value? (allowOpaque := true) then
      deps := value.foldConsts deps fun c cs => cs.insert c
    let names := deps.toList.map Name.toString |>.mergeSort (· < ·)
    let range ← findDeclarationRanges? n
    let line := range.map (fun r => r.range.pos.line) |>.getD 0
    let namedReader : Bool := match ci with
      | .thmInfo _ | .defnInfo _ | .opaqueInfo _ => decide (line > 0)
      | _ => false
    logInfo m!"READER_NODE {Json.compress <| Json.arr #[toJson n.toString, toJson mod, toJson line, toJson namedReader, toJson names]}"
