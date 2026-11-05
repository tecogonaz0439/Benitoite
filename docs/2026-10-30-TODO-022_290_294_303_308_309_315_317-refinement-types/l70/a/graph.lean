import Benitoite
import Lean

/- 既定環境の Benitoite の宣言ごとに、型と値に現れる定数・種類・ソース位置を書き出す（棚卸しの入力）。 -/
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (n, ci) in env.constants.toList.mergeSort (fun a b => a.1.toString < b.1.toString) do
    let some idx := env.getModuleIdxFor? n | continue
    let mod := env.header.moduleNames[idx.toNat]!.toString
    unless mod.startsWith "Benitoite" do continue
    let typeDeps := ci.type.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
    let valueDeps := match ci.value? (allowOpaque := true) with
      | some value => value.foldConsts ({} : Std.HashSet Name) fun c cs => cs.insert c
      | none => {}
    let kind := match ci with
      | .thmInfo _ => "theorem" | .defnInfo _ => "def" | .opaqueInfo _ => "opaque"
      | .axiomInfo _ => "axiom" | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor"
      | .recInfo _ => "recursor" | .quotInfo _ => "quot"
    let range ← findDeclarationRanges? n
    let line := range.map (fun r => r.range.pos.line) |>.getD 0
    let sort (s : Std.HashSet Name) := s.toList.map Name.toString |>.mergeSort (· < ·)
    logInfo m!"NODE {Json.compress <| Json.arr #[toJson n.toString, toJson mod, toJson kind, toJson line, toJson (sort typeDeps), toJson (sort valueDeps)]}"
