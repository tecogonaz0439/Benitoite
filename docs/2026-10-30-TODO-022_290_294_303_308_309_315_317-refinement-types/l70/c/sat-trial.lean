import Benitoite.Release.Refinement.StandardModelCompletion

/-! L70 群 C の所見3の根拠（results.md）。`formal/` から `lake env lean -M 12288 <このファイル>` で検査する。
既定ビルドには含めない。 -/

namespace Benitoite.Release.Refinement
noncomputable section

/-- 利用者の data 型 `User.T` は、合成表の制約で等値の型にならない（要約の表に名前が無い）。 -/
example : ¬ StandardModel.baseBuiltins.sat [] (.data "User.T" []) {equality := true} := by
  intro h
  change Benitoite.Release.satB _ [] (StandardKeyTyping.carrier (.data "User.T" [])) _ = true at h
  revert h
  decide

/-- 同じ表で、合成プログラムの data 型 `Pair` に Integer を入れたものは等値の型である（対照）。 -/
example : StandardModel.baseBuiltins.sat [] (.data "Pair" [.base .integer, .base .integer]) {equality := true} := by
  change Benitoite.Release.satB _ [] (StandardKeyTyping.carrier _) _ = true
  decide

end
end Benitoite.Release.Refinement
