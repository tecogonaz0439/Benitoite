import Benitoite
import SurfaceCheck.Validation
import BuiltinCheck.Main

/-!
# L00.06 の母集団の分類のための依存の書き出し（既定のビルドに含めない道具）

`formal` の既定の対象の環境から、`Benitoite`・`SurfaceCheck`・`BuiltinCheck` のモジュールの各定数について、
種類・モジュール・宣言の行・言明（型）が直接使う定数・本体（値）が直接使う定数を JSON 行で書き出す。
字句の検索と違い、構成子名を書かない `cases` や `simp` が生む項の定数も数える。書き出すのは直接の
参照だけであり、推移的な依存は読み手（`classify.py`）が計算する。環境変数 `DEPS_OUT` に出力先を与える。
-/

open Lean Meta Elab Command

private def kindOf : ConstantInfo → String
  | .axiomInfo _ => "axiom"
  | .defnInfo _ => "def"
  | .thmInfo _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quot"
  | .inductInfo _ => "inductive"
  | .ctorInfo _ => "ctor"
  | .recInfo _ => "rec"

private def valueOf? : ConstantInfo → Option Expr
  | .defnInfo d => some d.value
  | .thmInfo t => some t.value
  | .opaqueInfo o => some o.value
  | _ => none

private def inScope (m : Name) : Bool :=
  let r := m.getRoot
  r == `Benitoite || r == `SurfaceCheck || r == `BuiltinCheck

private def jsonNames (ns : Array Name) : Json :=
  Json.arr (ns.qsort (fun a b => a.toString < b.toString) |>.map (fun n => Json.str n.toString))

#eval show CommandElabM Unit from do
  let out ← match (← IO.getEnv "DEPS_OUT") with
    | some p => pure p
    | none => throwError "DEPS_OUT is not set"
  let env ← getEnv
  let h ← IO.FS.Handle.mk out IO.FS.Mode.write
  let mut count := 0
  for (n, ci) in env.constants.map₁.toList do
    let some idx := env.getModuleIdxFor? n | continue
    let m := env.header.moduleNames[idx.toNat]!
    if !inScope m then continue
    let line ← liftCoreM do
      match (← findDeclarationRanges? n) with
      | some r => pure (toJson r.selectionRange.pos.line, toJson r.range.pos.line)
      | none => pure (Json.null, Json.null)
    let tyConsts := ci.type.getUsedConstants
    let valConsts := (valueOf? ci).map (·.getUsedConstants) |>.getD #[]
    let extra : List (String × Json) := match ci with
      | .ctorInfo c => [("induct", Json.str c.induct.toString)]
      | .inductInfo i => [("ctors", Json.arr (i.ctors.toArray.map (fun c => Json.str c.toString)))]
      | _ => []
    let j := Json.mkObj ([("name", Json.str n.toString), ("kind", Json.str (kindOf ci)),
      ("module", Json.str m.toString), ("line", line.1), ("start", line.2), ("type", jsonNames tyConsts),
      ("value", jsonNames valConsts)] ++ extra)
    h.putStrLn j.compress
    count := count + 1
  logInfo m!"written {count} constants"
