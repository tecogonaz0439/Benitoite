import Benitoite
import Lean.Util.CollectAxioms

/-! N16 のレビュー用の公理依存の一覧。formal/ で lake env lean にこのファイルを渡す。
全宣言（私的な定義・partial def の不透明な定数・自動生成されたものを含む）を
環境から列挙し、私的な補題への依存も辿る。
定理の言明・定義・対象範囲のレビューは G4-report.md に記す。 -/

open Lean Elab Command

run_cmd do
  let env ← getEnv
  let mut total : Nat := 0
  let mut theorems : Nat := 0
  let mut definitions : Nat := 0
  let mut opaques : Nat := 0
  let mut generated : Nat := 0
  let mut changed : Nat := 0
  let constants := env.constants.toList.mergeSort (fun a b => a.1.toString ≤ b.1.toString)
  for (name, ci) in constants do
    let spelling := name.toString
    let userSpelling := (privateToUserName name).toString
    if userSpelling.startsWith "Benitoite.NamedRelease." ||
        userSpelling.startsWith "Benitoite.NamedSurface." ||
        userSpelling.startsWith "Benitoite.NamedExchange." then
      let kind := match ci with
        | .thmInfo _ => "theorem"
        | .defnInfo _ => "definition"
        | .opaqueInfo _ => "opaque"
        | _ => "generated"
      let axs ← collectAxioms name
      for ax in axs do
        unless [``propext, ``Classical.choice, ``Quot.sound].contains ax do
          throwError "unexpected axiom in {name}: {ax}"
      let oldName := (spelling.replace "Benitoite.NamedRelease." "Benitoite.Release."
        |>.replace "Benitoite.NamedSurface." "Benitoite.Surface."
        |>.replace "Benitoite.NamedExchange." "Benitoite.Exchange.").toName
      let oldAxs ← if env.contains oldName then collectAxioms oldName else pure #[]
      logInfo (Json.mkObj [("name", toJson spelling),
        ("kind", toJson kind),
        ("axioms", toJson (axs.toList.map Name.toString)),
        ("old", if env.contains oldName then toJson oldName.toString else Json.null),
        ("oldAxioms", toJson (oldAxs.toList.map Name.toString))]).compress
      total := total + 1
      match ci with
      | .thmInfo _ => theorems := theorems + 1
      | .defnInfo _ => definitions := definitions + 1
      | .opaqueInfo _ => opaques := opaques + 1
      | _ => generated := generated + 1
      if env.contains oldName && axs.toList.mergeSort (·.toString ≤ ·.toString) !=
          oldAxs.toList.mergeSort (·.toString ≤ ·.toString) then changed := changed + 1
  logInfo m!"audited={total} theorems={theorems} definitions={definitions} opaques={opaques} generated={generated} changedAxioms={changed}"
