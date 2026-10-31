import Benitoite.Release.Refinement.ValueShiftSyntax

namespace Benitoite.Release.Refinement
open Std Order

private theorem node_compare (a b : Label) (as bs : List (Tree Label)) :
    treeCompare labelCompare (.node a as) (.node b bs) = (labelCompare a b).then (treesCompare labelCompare as bs) := rfl

private theorem shiftIndex_lt (k c i j : Nat) : shiftIndex k c i < shiftIndex k c j ↔ i < j := by
  unfold shiftIndex
  split <;> split <;> omega

set_option maxRecDepth 4096 in
mutual
  private theorem termTree_shift_compare (k c : Nat) (a b : Term) :
      treeCompare labelCompare (termTree (termBind (fun i => some (.var (shiftIndex k c i))) a))
        (termTree (termBind (fun i => some (.var (shiftIndex k c i))) b)) =
        treeCompare labelCompare (termTree a) (termTree b) := by
    cases a <;> cases b <;>
      simp [termTree, node_compare, treesCompare, labelCompare,
        termTree_shift_compare, slotTrees_shift_compare, Nat.compare_eq_ite_lt, shiftIndex_lt]
  private theorem slotTree_shift_compare (k c : Nat) (a b : Option Term) :
      treeCompare labelCompare (slotTree (slotBind (fun i => some (.var (shiftIndex k c i))) a))
        (slotTree (slotBind (fun i => some (.var (shiftIndex k c i))) b)) =
        treeCompare labelCompare (slotTree a) (slotTree b) := by
    cases a <;> cases b <;>
      simp [slotBind, termBind?_renaming, slotTree, node_compare, treesCompare,
        labelCompare, termTree_shift_compare]
  private theorem slotTrees_shift_compare (k c : Nat) (as bs : List (Option Term)) :
      treesCompare labelCompare (slotTrees (bindSlots (fun i => some (.var (shiftIndex k c i))) as))
        (slotTrees (bindSlots (fun i => some (.var (shiftIndex k c i))) bs)) =
        treesCompare labelCompare (slotTrees as) (slotTrees bs) := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs => simp only [bindSlots, slotTrees, treesCompare,
          slotTree_shift_compare, slotTrees_shift_compare]
end

private theorem predTree_shift_compare (k c : Nat) (a b : Pred) :
    treeCompare labelCompare (predTree (predBind (fun i => some (.var (shiftIndex k c i))) a))
      (predTree (predBind (fun i => some (.var (shiftIndex k c i))) b)) =
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
        Ty.tree_shiftV_compare, Ty.trees_shiftV_compare, Eff.tree_shiftV_compare, Tel.tree_shiftV_compare,
        show (fun i => some (Term.var (if i < c+1 then i else i+k))) =
          (fun i => some (Term.var (shiftIndex k (c+1) i))) from rfl,
        predTree_shift_compare, Nat.compare_eq_ite_lt]
  termination_by structural a
  theorem Tel.tree_shiftV_compare (k c : Nat) (a b : Tel) :
      treeCompare labelCompare (Tel.toTree (Tel.shiftV k c a)) (Tel.toTree (Tel.shiftV k c b)) =
        treeCompare labelCompare (Tel.toTree a) (Tel.toTree b) := by
    cases a <;> cases b <;> simp [Tel.shiftV, Tel.toTree, node_compare, treesCompare,
      labelCompare, Ty.tree_shiftV_compare, Eff.tree_shiftV_compare, Tel.tree_shiftV_compare, Nat.compare_eq_ite_lt]
  termination_by structural a
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
  termination_by structural as
  theorem Eff.tree_shiftV_compare (k c : Nat) (e f : Eff) :
      treeCompare labelCompare (Eff.toTree (Eff.shiftV k c e)) (Eff.toTree (Eff.shiftV k c f)) =
        treeCompare labelCompare (Eff.toTree e) (Eff.toTree f) := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs => simp only [Eff.shiftV, Eff.toTree, treeCompare, Ty.trees_shiftV_compare]
  termination_by structural e
end

theorem Ty.shiftV_compare (k c : Nat) (a b : Ty) :
    tyCompare (a.shiftV k c) (b.shiftV k c) = tyCompare a b :=
  Ty.tree_shiftV_compare k c a b

@[simp] theorem shiftVTys_eq_map (k c : Nat) (as : List Ty) :
    shiftVTys k c as = as.map (Ty.shiftV k c) := by
  induction as <;> simp_all [shiftVTys]

theorem Pred.shiftV_comm_at (p : Pred) (n d k c : Nat) (hd : d ≤ c) :
    (p.shiftV n d).shiftV k (c+n) = (p.shiftV k c).shiftV n d := by
  simp only [Pred.shiftV, predBind_comp]
  congr 1
  funext i
  simp only [Option.bind_some, termBind?]
  unfold shiftIndex
  repeat' split
  all_goals congr 2 <;> omega

mutual
  theorem Ty.shiftV_comm_at (a : Ty) (n d k c : Nat) (hd : d ≤ c) :
      (a.shiftV n d).shiftV k (c+n) = (a.shiftV k c).shiftV n d := by
    cases a <;> simp only [Ty.shiftV, Ty.shiftV_comm_at, shiftVTys_comm_at, Eff.shiftV_comm_at,
      Tel.shiftV_comm_at, hd]
    case refined a p =>
      congr 1
      simpa only [Pred.shiftV, shiftIndex, Nat.add_right_comm c n 1] using
        Pred.shiftV_comm_at p n (d+1) k (c+1) (by omega)
  theorem Tel.shiftV_comm_at (t : Tel) (n d k c : Nat) (hd : d ≤ c) :
      Tel.shiftV k (c+n) (Tel.shiftV n d t) = Tel.shiftV n d (Tel.shiftV k c t) := by
    cases t with
    | done r e => simp only [Tel.shiftV, Ty.shiftV_comm_at r n d k c hd, Eff.shiftV_comm_at e n d k c hd]
    | param name a t =>
      simp only [Tel.shiftV, Ty.shiftV_comm_at a n d k c hd]
      congr 1
      simpa only [Nat.add_right_comm c n 1] using Tel.shiftV_comm_at t n (d+1) k (c+1) (by omega)
  theorem shiftVTys_comm_at (as : List Ty) (n d k c : Nat) (hd : d ≤ c) :
      shiftVTys k (c+n) (shiftVTys n d as) = shiftVTys n d (shiftVTys k c as) := by
    cases as <;> simp only [shiftVTys, Ty.shiftV_comm_at, shiftVTys_comm_at, hd]
  theorem Eff.shiftV_comm_at (e : Eff) (n d k c : Nat) (hd : d ≤ c) :
      Eff.shiftV k (c+n) (Eff.shiftV n d e) = Eff.shiftV n d (Eff.shiftV k c e) := by
    cases e; simp only [Eff.shiftV, shiftVTys_comm_at _ n d k c hd]
end

theorem Ty.shiftV_comm (a : Ty) (n k c : Nat) :
    (a.shiftV n 0).shiftV k (c+n) = (a.shiftV k c).shiftV n 0 :=
  Ty.shiftV_comm_at a n 0 k c (Nat.zero_le c)
theorem Eff.shiftV_comm (e : Eff) (n k c : Nat) :
    Eff.shiftV k (c+n) (Eff.shiftV n 0 e) = Eff.shiftV n 0 (Eff.shiftV k c e) :=
  Eff.shiftV_comm_at e n 0 k c (Nat.zero_le c)



theorem Tel.shiftV_toTel (ns ps r e) (k c : Nat) :
    Tel.shiftV k c (Ty.toTel ns ps r e) =
      Ty.toTel ns (shiftVTys k c ps) (r.shiftV k c) (Eff.shiftV k c e) := by
  induction ns generalizing ps r e c with
  | nil => rfl
  | cons n ns ih =>
    cases ps with
    | nil => rfl
    | cons a ps =>
      simp only [Ty.toTel, shiftVTys, Tel.shiftV, ih, Ty.shiftV_comm, Eff.shiftV_comm,
        shiftVTys_eq_map, List.map_map]
      congr 2
      congr 1
      funext a
      exact Ty.shiftV_comm a 1 k c

end Benitoite.Release.Refinement
