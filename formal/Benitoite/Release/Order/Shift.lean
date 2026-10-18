import Benitoite.Release.Subst

/-!
# 型変数の移動と型の順序

生の移動は任意の型の比較を保つ。公開する移動は正規化も行うので、
元の比較との一致には正規形を要求する（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release

open Std Order

/-- 公開する移動は、正規化した入力の比較を保つ。 -/
theorem Ty.shift_compare_norm (k c : Nat) (a b : Ty) :
    tyCompare (a.shift k c) (b.shift k c) = tyCompare a.norm b.norm := by
  simp only [Ty.shift_eq_norm_rawShift, Ty.norm_rawShift, Ty.rawShift_compare]

/-- 正規形の型では、移動前後の比較が一致する。 -/
theorem Ty.shift_compare (k c : Nat) (a b : Ty) (ha : a.Canonical) (hb : b.Canonical) :
    tyCompare (a.shift k c) (b.shift k c) = tyCompare a b := by
  rw [Ty.shift_compare_norm, ha, hb]

private theorem shift_map (k c : Nat) (as : List Ty) (ha : ∀ a ∈ as, a.Canonical) :
    as.map (Ty.shift k c) = as.map (Ty.rawShift k c) := by
  apply List.map_congr_left
  intro a hi
  rw [Ty.shift_eq_norm_rawShift, Ty.norm_rawShift, ha a hi]

/-- 正規形の型列の比較も移動で保たれる。 -/
theorem Ty.shift_compareList (k c : Nat) (as bs : List Ty)
    (ha : ∀ a ∈ as, a.Canonical) (hb : ∀ b ∈ bs, b.Canonical) :
    tysCompare (as.map (Ty.shift k c)) (bs.map (Ty.shift k c)) = tysCompare as bs := by
  rw [shift_map k c as ha, shift_map k c bs hb]
  simpa only [← Ty.rawShiftTys_eq_map] using Ty.rawShiftTys_compare k c as bs

/-- 正規形の型列では、移動と整列・重複除去が可換である。 -/
theorem Ty.sortUnique_shift (k c : Nat) (as : List Ty) (ha : ∀ a ∈ as, a.Canonical) :
    sortUnique tyCompare (as.map (Ty.shift k c)) = (sortUnique tyCompare as).map (Ty.shift k c) := by
  rw [shift_map k c as ha, sortUnique_map tyCompare tyCompare (Ty.rawShift k c) (Ty.rawShift_compare k c)]
  exact (shift_map k c _ (fun a hi => ha a (mem_sortUnique.mp hi))).symm

end Benitoite.Release
