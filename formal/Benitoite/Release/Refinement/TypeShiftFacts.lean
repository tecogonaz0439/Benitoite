import Benitoite.Release.Refinement.TypeRegularity

/-! 生の型移動と正規化した移動の比較・正規形。
設計書01-12「コア計算と脱糖」の型移動を包装する。 -/
namespace Benitoite.Release.Refinement
open Std Order

theorem shiftIndex_compare (k c i j : Nat) :
    compare (shiftIndex k c i) (shiftIndex k c j) = compare i j := by
  have hlt : ∀ i j, shiftIndex k c i < shiftIndex k c j ↔ i < j := by
    intro i j
    unfold shiftIndex
    split <;> split <;> omega
  simp only [Nat.compare_eq_ite_lt, hlt]

theorem Ty.rawShift_canonical (k c : Nat) {a : Ty} (h : a.Canonical) :
    (shiftTypes k c a).Canonical := by
  unfold Ty.Canonical at h ⊢
  rw [Ty.norm_shiftTypes, h]

theorem Eff.rawShift_canonical (k c : Nat) {e : Eff} (h : e.Canonical) :
    (shiftRowsTypes k c e).Canonical := by
  unfold Eff.Canonical at h ⊢
  rw [Eff.norm_shiftTypes, h]

theorem Ty.shift_canonical (k c : Nat) (a : Ty) : (a.shift k c).Canonical :=
  Ty.norm_idem _

theorem Eff.shift_canonical (k c : Nat) (e : Eff) : (Eff.shift k c e).Canonical :=
  Eff.norm_idem _

theorem Ty.shift_zero_norm (c : Nat) (a : Ty) : a.shift 0 c = a.norm := by
  rw [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes, shiftTypes_zero]

theorem Eff.shift_zero_norm (c : Nat) (e : Eff) : Eff.shift 0 c e = e.norm := by
  rw [Eff.shift, Eff.bind, Eff.rawBind_shiftTypes, shiftRowsTypes_zero]

theorem Ty.shift_compare_norm (k c : Nat) (a b : Ty) :
    tyCompare (a.shift k c) (b.shift k c) = tyCompare a.norm b.norm := by
  simp only [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes, Ty.norm_shiftTypes, Ty.shiftTypes_compare]

theorem Ty.shift_compare (k c : Nat) (a b : Ty) (ha : a.Canonical) (hb : b.Canonical) :
    tyCompare (a.shift k c) (b.shift k c) = tyCompare a b := by
  rw [Ty.shift_compare_norm, ha, hb]

theorem shift_map (k c : Nat) (as : List Ty) (ha : ∀ a ∈ as, a.Canonical) :
    as.map (Ty.shift k c) = as.map (shiftTypes k c) := by
  apply List.map_congr_left
  intro a hi
  rw [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes, Ty.norm_shiftTypes, ha a hi]

theorem Ty.shift_compareList (k c : Nat) (as bs : List Ty)
    (ha : ∀ a ∈ as, a.Canonical) (hb : ∀ b ∈ bs, b.Canonical) :
    treesCompare labelCompare (Ty.toTrees (as.map (Ty.shift k c)))
      (Ty.toTrees (bs.map (Ty.shift k c))) =
    treesCompare labelCompare (Ty.toTrees as) (Ty.toTrees bs) := by
  rw [shift_map k c as ha, shift_map k c bs hb]
  simpa only [← shiftTypesList_eq_map] using Ty.trees_shiftTypes_compare k c as bs

theorem Ty.sortUnique_shift (k c : Nat) (as : List Ty) (ha : ∀ a ∈ as, a.Canonical) :
    sortUnique tyCompare (as.map (Ty.shift k c)) = (sortUnique tyCompare as).map (Ty.shift k c) := by
  rw [shift_map k c as ha, sortUnique_map tyCompare tyCompare (shiftTypes k c) (Ty.shiftTypes_compare k c)]
  exact (shift_map k c _ (fun a ha' => ha a (mem_sortUnique.mp ha'))).symm

end Benitoite.Release.Refinement
