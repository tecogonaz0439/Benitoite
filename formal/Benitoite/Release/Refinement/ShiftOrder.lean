import Benitoite.Release.Refinement.Basic

/-!
# 値の移動と正規形

Nat/cutoff の単調な移動は述語と型の辞書式比較を保つ。
-/
namespace Benitoite.Release.Refinement
open Std Order

private theorem node_compare (a b : Label) (as bs : List (Tree Label)) :
    treeCompare labelCompare (.node a as) (.node b bs) = (labelCompare a b).then (treesCompare labelCompare as bs) := rfl

private theorem shiftIndex_lt (k c i j : Nat) : shiftIndex k c i < shiftIndex k c j ↔ i < j := by
  unfold shiftIndex
  split <;> split <;> omega

private theorem termTree_shift_compare (k c : Nat) (a b : Term) :
    treeCompare labelCompare (termTree (termBind (fun i => .var (shiftIndex k c i)) a))
      (termTree (termBind (fun i => .var (shiftIndex k c i)) b)) =
      treeCompare labelCompare (termTree a) (termTree b) := by
  cases a <;> cases b <;>
    simp [termBind, termTree, node_compare, treesCompare, labelCompare,
      termTree_shift_compare, Nat.compare_eq_ite_lt, shiftIndex_lt]

private theorem predTree_shift_compare (k c : Nat) (a b : Pred) :
    treeCompare labelCompare (predTree (predBind (fun i => .var (shiftIndex k c i)) a))
      (predTree (predBind (fun i => .var (shiftIndex k c i)) b)) =
      treeCompare labelCompare (predTree a) (predTree b) := by
  cases a <;> cases b <;>
    simp [predBind, predTree, node_compare, treesCompare, labelCompare,
      termTree_shift_compare, predTree_shift_compare, Nat.compare_eq_ite_lt]

mutual
  theorem Ty.tree_shiftV_compare (k c : Nat) (a b : Ty) :
      treeCompare labelCompare (a.shiftV k c).toTree (b.shiftV k c).toTree =
        treeCompare labelCompare a.toTree b.toTree := by
    cases a <;> cases b <;>
      simp [Ty.shiftV, Ty.toTree, node_compare, treesCompare, labelCompare,
        Ty.tree_shiftV_compare, Ty.trees_shiftV_compare, Eff.tree_shiftV_compare,
        show (fun i => Term.var (if i < c+1 then i else i+k)) =
          (fun i => Term.var (shiftIndex k (c+1) i)) from rfl,
        predTree_shift_compare, Nat.compare_eq_ite_lt]
  theorem Ty.trees_shiftV_compare (k c : Nat) (as bs : List Ty) :
      treesCompare labelCompare (Ty.toTrees (shiftVTys k c as)) (Ty.toTrees (shiftVTys k c bs)) =
        treesCompare labelCompare (Ty.toTrees as) (Ty.toTrees bs) := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs =>
        simp only [shiftVTys, Ty.toTrees, treesCompare, Ty.tree_shiftV_compare, Ty.trees_shiftV_compare]
  theorem Eff.tree_shiftV_compare (k c : Nat) (e f : Eff) :
      treeCompare labelCompare (Eff.toTree (Eff.shiftV k c e)) (Eff.toTree (Eff.shiftV k c f)) =
        treeCompare labelCompare (Eff.toTree e) (Eff.toTree f) := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs => simp only [Eff.shiftV, Eff.toTree, treeCompare, Ty.trees_shiftV_compare]
end

theorem Ty.shiftV_compare (k c : Nat) (a b : Ty) :
    tyCompare (a.shiftV k c) (b.shiftV k c) = tyCompare a b :=
  Ty.tree_shiftV_compare k c a b

@[simp] theorem shiftVTys_eq_map (k c : Nat) (as : List Ty) :
    shiftVTys k c as = as.map (Ty.shiftV k c) := by
  induction as <;> simp_all [shiftVTys]

mutual
  theorem Ty.norm_shiftV (a : Ty) (k c : Nat) :
      (a.shiftV k c).norm = a.norm.shiftV k c := by
    cases a <;> simp only [Ty.shiftV, Ty.norm, Ty.norm_shiftV, Ty.normTys_shiftV, Eff.norm_shiftV]
  theorem Ty.normTys_shiftV (as : List Ty) (k c : Nat) :
      Ty.normTys (shiftVTys k c as) = shiftVTys k c (Ty.normTys as) := by
    cases as <;> simp only [shiftVTys, Ty.normTys, Ty.norm_shiftV, Ty.normTys_shiftV]
  theorem Eff.norm_shiftV (e : Eff) (k c : Nat) :
      (Eff.shiftV k c e).norm = Eff.shiftV k c e.norm := by
    cases e with
    | mk a fs =>
      simp only [Eff.shiftV, Eff.norm]
      rw [Ty.normTys_shiftV]
      simp only [shiftVTys_eq_map]
      rw [sortUnique_map tyCompare tyCompare (Ty.shiftV k c) (Ty.shiftV_compare k c)]
end

mutual
  theorem Ty.wf_shiftV {nr nt nv : Nat} {a : Ty} (h : a.WF nr nt nv) (k c : Nat) :
      (a.shiftV k c).WF nr nt (nv+k) := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.shiftV, Ty.WF]
    all_goals first | exact h | exact Ty.wf_shiftV h k c | exact Ty.wfList_shiftV h k c | skip
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, shiftVTys_eq_map, List.length_map] using h.1,
        Ty.wfList_shiftV h.2.1 k c, Ty.wf_shiftV h.2.2.1 k c,
        Eff.wf_shiftV h.2.2.2.1 k c, by
          unfold Eff.Canonical
          rw [Eff.norm_shiftV, h.2.2.2.2]⟩
    case cont b t e =>
      exact ⟨Ty.wf_shiftV h.1 k c, Ty.wf_shiftV h.2.1 k c, Eff.wf_shiftV h.2.2.1 k c,
        by unfold Eff.Canonical; rw [Eff.norm_shiftV, h.2.2.2]⟩
    case map a b => exact ⟨Ty.wf_shiftV h.1 k c, Ty.wf_shiftV h.2 k c⟩
    case tapp i as => exact ⟨h.1, Ty.wfList_shiftV h.2 k c⟩
    case refined a p =>
      refine ⟨Ty.wf_shiftV h.1 k c, ?_, (Ty.notContCore_shiftV _ _ _).mpr h.2.2⟩
      have hp := Pred.wf_shiftV h.2.1 k (c+1)
      simpa only [Pred.shiftV, shiftIndex, Nat.add_right_comm nv k 1] using hp
  theorem Ty.wfList_shiftV {nr nt nv : Nat} {as : List Ty} (h : Ty.WFList nr nt nv as) (k c : Nat) :
      Ty.WFList nr nt (nv+k) (shiftVTys k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_shiftV h.1 k c, Ty.wfList_shiftV h.2 k c⟩
  theorem Eff.wf_shiftV {nr nt nv : Nat} {e : Eff} (h : e.WF nr nt nv) (k c : Nat) :
      (Eff.shiftV k c e).WF nr nt (nv+k) := by
    cases e
    exact Ty.wfList_shiftV h k c
end

end Benitoite.Release.Refinement
