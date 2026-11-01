import Benitoite
/-! 旧の網羅性は値の空な型で空虚に成り立ち、新の Inhabits は checkedAt を含む。
C_Match の埋め込みには旧→新の網羅性の補題が要り、範囲変数なしの入力を使う。 -/
namespace RVLTenF
open Benitoite.Release.Refinement
abbrev OTy := Benitoite.Release.Ty

def rangeOpaque : OTy := .opaque "o" (.rvar 0)

/-- 旧: 範囲変数の不透明型には Inhabits の値がないので、空の腕でも網羅的である。 -/
theorem old_exhaustive (P0 : Benitoite.Release.Program) :
    Benitoite.Release.Exhaustive P0 rangeOpaque [] := by
  intro v hv
  exfalso
  generalize he : rangeOpaque = a at hv
  cases hv with
  | const =>
    rename_i c
    cases c <;> simp [Benitoite.Release.Const.type, rangeOpaque, Benitoite.Release.Ty.opaqueTop] at he
  | _ => simp [rangeOpaque] at he

/-- 新: 同じ型の像に checkedAt が属するので、空の腕は網羅的でない。 -/
theorem new_not_exhaustive (P : Program) (r : RangeExpr) (s : Option PathEnv)
    (t : Benitoite.Scope.Domain.Target) (q : Option Val) :
    ¬ Exhaustive P (embedTy rangeOpaque) [] := by
  intro h
  have hn : (embedTy rangeOpaque).norm = .opaque "o" (.rvar 0) := by
    simp [rangeOpaque, embedTy, embedIx, Ty.norm]
  have hi : Inhabits P (embedTy rangeOpaque).norm (.checkedAt r s t q) := by
    rw [hn]; exact Inhabits.checkedAtOpaque
  obtain ⟨p, hp, _⟩ := h _ hi
  simp at hp

/-- 旧入力は範囲の深さ0でこの型を拒む。 -/
theorem input_rejects (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ C nv) : ¬ LegacyTypeInput K P0 ⟨κ, C, 0, nv⟩ rangeOpaque .value := by
  intro h
  have := h.2.1
  simp [rangeOpaque, embedTy, embedIx, Ty.WF, RangeIx.WF] at this

end RVLTenF

#print axioms RVLTenF.new_not_exhaustive
