import Benitoite.Release.Refinement.HandlerOperation

/-! 継続の変数を閉包・thunk へ持ち出せないこと。-/
namespace Benitoite.Release.Refinement
noncomputable section

abbrev U : Ty := .base .unit
abbrev κ : Ty := .cont U U Eff.empty
abbrev Γc : Ctx := [some κ]

theorem hide_removes : (hideConts Γc)[0]? = some none := by
  simp [hideConts,Γc,κ]

/-- 関数の本体と thunk の本体が読む文脈では、番号 0 の継続を C_Resume で読めない。 -/
theorem no_cont_after_hide {b t e} : (hideConts Γc)[0]? ≠ some (some (.cont b t e)) := by
  rw [hide_removes]; simp

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.no_cont_after_hide
