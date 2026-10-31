import Benitoite.Release.Refinement.TypeRenaming

namespace Benitoite.Release.Refinement
open Std Order

private theorem node_compare (a b : Label) (as bs : List (Tree Label)) :
    treeCompare labelCompare (.node a as) (.node b bs) =
      (labelCompare a b).then (treesCompare labelCompare as bs) := rfl

private theorem shiftIndex_lt (k c i j : Nat) : (if i<c then i else i+k) < (if j<c then j else j+k) ↔ i < j := by
  split <;> split <;> omega

mutual
  theorem Ty.tree_shiftTypes_compare (k c : Nat) (a b : Ty) :
      treeCompare labelCompare (shiftTypes k c a).toTree (shiftTypes k c b).toTree =
        treeCompare labelCompare a.toTree b.toTree := by
    cases a <;> cases b <;>
      simp [shiftTypes, Ty.toTree, node_compare, treesCompare, labelCompare,
        Ty.tree_shiftTypes_compare, Ty.trees_shiftTypes_compare, Eff.tree_shiftTypes_compare, Tel.tree_shiftTypes_compare,
        Nat.compare_eq_ite_lt, shiftIndex_lt]
  termination_by structural a
  theorem Tel.tree_shiftTypes_compare (k c : Nat) (a b : Tel) :
      treeCompare labelCompare (Tel.toTree (shiftTelTypes k c a)) (Tel.toTree (shiftTelTypes k c b)) =
        treeCompare labelCompare (Tel.toTree a) (Tel.toTree b) := by
    cases a <;> cases b <;> simp [shiftTelTypes, Tel.toTree, node_compare, treesCompare,
      labelCompare, Ty.tree_shiftTypes_compare, Eff.tree_shiftTypes_compare, Tel.tree_shiftTypes_compare, Nat.compare_eq_ite_lt]
  termination_by structural a
  theorem Ty.trees_shiftTypes_compare (k c : Nat) (as bs : List Ty) :
      treesCompare labelCompare (Ty.toTrees (shiftTypesList k c as)) (Ty.toTrees (shiftTypesList k c bs)) =
        treesCompare labelCompare (Ty.toTrees as) (Ty.toTrees bs) := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs =>
        simp only [shiftTypesList, Ty.toTrees, treesCompare, Ty.tree_shiftTypes_compare, Ty.trees_shiftTypes_compare]
  termination_by structural as
  theorem Eff.tree_shiftTypes_compare (k c : Nat) (e f : Eff) :
      treeCompare labelCompare (Eff.toTree (shiftRowsTypes k c e)) (Eff.toTree (shiftRowsTypes k c f)) =
        treeCompare labelCompare (Eff.toTree e) (Eff.toTree f) := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs => simp only [shiftRowsTypes, Eff.toTree, treeCompare, Ty.trees_shiftTypes_compare]
  termination_by structural e
end

theorem Ty.shiftTypes_compare (k c : Nat) (a b : Ty) :
    tyCompare (shiftTypes k c a) (shiftTypes k c b) = tyCompare a b :=
  Ty.tree_shiftTypes_compare k c a b

@[simp] theorem shiftTypesList_eq_map (k c : Nat) (as : List Ty) :
    shiftTypesList k c as = as.map (shiftTypes k c) := by
  induction as <;> simp_all [shiftTypesList]

mutual
  theorem Ty.norm_shiftTypes (a : Ty) (k c : Nat) :
      (shiftTypes k c a).norm = shiftTypes k c a.norm := by
    cases a <;> simp only [shiftTypes, Ty.norm, Ty.norm_shiftTypes, Ty.normTys_shiftTypes, Eff.norm_shiftTypes, Tel.norm_shiftTypes]
  theorem Tel.norm_shiftTypes (t : Tel) (k c : Nat) :
      Tel.norm (shiftTelTypes k c t) = shiftTelTypes k c (Tel.norm t) := by
    cases t <;> simp only [Tel.norm, shiftTelTypes, Ty.norm_shiftTypes, Eff.norm_shiftTypes, Tel.norm_shiftTypes]
  theorem Ty.normTys_shiftTypes (as : List Ty) (k c : Nat) :
      Ty.normTys (shiftTypesList k c as) = shiftTypesList k c (Ty.normTys as) := by
    cases as <;> simp only [shiftTypesList, Ty.normTys, Ty.norm_shiftTypes, Ty.normTys_shiftTypes]
  theorem Eff.norm_shiftTypes (e : Eff) (k c : Nat) :
      (shiftRowsTypes k c e).norm = shiftRowsTypes k c e.norm := by
    cases e with
    | mk a fs =>
      simp only [shiftRowsTypes, Eff.norm]
      rw [Ty.normTys_shiftTypes]
      simp only [shiftTypesList_eq_map]
      rw [sortUnique_map tyCompare tyCompare (shiftTypes k c) (Ty.shiftTypes_compare k c)]
end


end Benitoite.Release.Refinement
