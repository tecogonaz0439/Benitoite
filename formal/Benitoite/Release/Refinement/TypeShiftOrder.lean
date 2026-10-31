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

private def undoTypeShift (k c : Nat) : SubstEnv :=
  ⟨fun i => .tvar (unshiftValue k c i), [], [], fun i => some (.var i)⟩

private theorem undoTypeShift_up (k c : Nat) : (undoTypeShift k c).up = undoTypeShift k c := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  exact upValues_id

private theorem undo_typeIndex (k c i : Nat) :
    unshiftValue k c (if i < c then i else i+k) = i :=
  congrFun (unshiftValue_shift k c) i

mutual
  private theorem undo_shiftTypes (a : Ty) (k c : Nat) :
      (shiftTypes k c a).rawBind (undoTypeShift k c) = a := by
    cases a <;> simp only [shiftTypes, Ty.rawBind, undo_shiftTypes,
      undo_shiftTypeList, undo_shiftTelTypes, undo_shiftRowsTypes]
    all_goals simp [undoTypeShift, rawApply, RangeIx.inst_nil, upValues_id,
      predBind_id, undo_typeIndex]
  private theorem undo_shiftTypeList (as : List Ty) (k c : Nat) :
      rawBindTys (undoTypeShift k c) (shiftTypesList k c as) = as := by
    cases as <;> simp only [shiftTypesList, rawBindTys, undo_shiftTypes, undo_shiftTypeList]
  private theorem undo_shiftTelTypes (t : Tel) (k c : Nat) :
      Tel.rawBind (undoTypeShift k c) (shiftTelTypes k c t) = t := by
    cases t <;> simp only [shiftTelTypes, Tel.rawBind, undoTypeShift_up,
      undo_shiftTypes, undo_shiftRowsTypes, undo_shiftTelTypes]
  private theorem undo_shiftRowsTypes (e : Eff) (k c : Nat) :
      Eff.rawBind (undoTypeShift k c) (shiftRowsTypes k c e) = e := by
    cases e
    simp only [shiftRowsTypes, Eff.rawBind, undo_shiftTypeList]
    simp only [undoTypeShift, instAtoms_nil, substAtoms_nil, rowFails, List.length_nil, List.range_zero,
      List.filter_nil, List.flatMap_nil, List.append_nil]
end

theorem Ty.foldFn_shiftTypes (t : Tel) (k c : Nat) :
    Ty.foldFn (shiftTelTypes k c t) = shiftTypes k c (Ty.foldFn t) := by
  classical
  by_cases h : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := h
    rw [←Tel.rawBind_shiftTypes, ←FnView.toTel_rawBind, Ty.foldFn_toTel, Ty.foldFn_toTel]
    simp only [FnView.rawBind, Ty.rawBind_shiftTypes, Eff.rawBind_shiftTypes, rawBindTys_shiftTypes, shiftTypes]
  · have hs : ¬ ∃ f : FnView, f.toTel = shiftTelTypes k c t := by
      rintro ⟨f, hf⟩
      apply h
      refine ⟨f.rawBind (undoTypeShift k c), ?_⟩
      rw [FnView.toTel_rawBind, hf, undo_shiftTelTypes]
    rw [Ty.foldFn_no_view h, Ty.foldFn_no_view hs]
    rfl

@[simp] theorem Ty.core_shiftTypes (a : Ty) (k c : Nat) :
    (shiftTypes k c a).core = shiftTypes k c a.core := by
  cases a with
  | refined a p => exact Ty.core_shiftTypes a k c
  | _ => rfl

@[simp] theorem Ty.predicates_shiftTypes (a : Ty) (k c : Nat) :
    (shiftTypes k c a).refinementPredicates = a.refinementPredicates := by
  cases a with
  | refined a p => simp only [shiftTypes, Ty.refinementPredicates, Ty.predicates_shiftTypes]
  | _ => rfl

theorem Ty.refineNorm_shiftTypes (a : Ty) (p : Pred) (k c : Nat) :
    (shiftTypes k c a).refineNorm p = shiftTypes k c (a.refineNorm p) := by
  unfold Ty.refineNorm
  rw [Ty.core_shiftTypes, Ty.predicates_shiftTypes]
  unfold Ty.packRefinements
  split <;> rfl

mutual
  theorem Ty.norm_shiftTypes (a : Ty) (k c : Nat) :
      (shiftTypes k c a).norm = shiftTypes k c a.norm := by
    cases a <;> simp only [shiftTypes, Ty.norm, Ty.norm_shiftTypes, Ty.normTys_shiftTypes, Eff.norm_shiftTypes, Tel.norm_shiftTypes, Ty.refineNorm_shiftTypes, Ty.foldFn_shiftTypes]
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
