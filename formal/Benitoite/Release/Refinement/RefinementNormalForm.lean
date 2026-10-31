import Benitoite.Release.Refinement.FunctionNormalForm
import Benitoite.Release.Refinement.Conjunction

namespace Benitoite.Release.Refinement

@[simp] def Ty.core : Ty → Ty
  | .refined a _ => a.core
  | a => a

def Ty.refinementPredicates : Ty → List Pred
  | .refined a p => a.refinementPredicates ++ p.conjuncts
  | _ => []

def Ty.packRefinements (a : Ty) : List Pred → Ty
  | [] => a
  | ps@(_ :: _) => .refined a (Pred.ofConjuncts ps)

def Ty.refineNorm (a : Ty) (p : Pred) : Ty :=
  Ty.packRefinements a.core (a.refinementPredicates ++ p.conjuncts)

@[simp] theorem Ty.core_idem (a : Ty) : a.core.core = a.core := by
  cases a with
  | refined a _ => exact Ty.core_idem a
  | _ => rfl

@[simp] theorem Ty.predicates_core (a : Ty) : a.core.refinementPredicates = [] := by
  cases a with
  | refined a _ => exact Ty.predicates_core a
  | _ => rfl

theorem Ty.core_not_refined (a : Ty) : ∀ b p, a.core ≠ .refined b p := by
  cases a with
  | refined a _ => exact Ty.core_not_refined a
  | _ => intros; intro h; cases h

theorem Ty.refinementPredicates_atoms (a : Ty) : ∀ p ∈ a.refinementPredicates, p.ConjAtom := by
  cases a with
  | refined a q =>
    intro p hp
    rcases List.mem_append.mp hp with hp | hp
    · exact Ty.refinementPredicates_atoms a p hp
    · exact Pred.conjuncts_atoms q p hp
  | _ => intro p hp; cases hp

theorem Ty.core_packRefinements (a : Ty) (ps : List Pred) :
    (Ty.packRefinements a ps).core = a.core := by
  cases ps <;> rfl

theorem Ty.predicates_packRefinements {a : Ty} {ps : List Pred}
    (ha : a.refinementPredicates = []) (hp : ∀ p ∈ ps, p.ConjAtom) :
    (Ty.packRefinements a ps).refinementPredicates = ps := by
  cases ps with
  | nil => exact ha
  | cons p ps =>
    simp only [Ty.packRefinements, Ty.refinementPredicates, ha, List.nil_append,
      Pred.conjuncts_ofConjuncts hp]

@[simp] theorem Ty.core_refineNorm (a : Ty) (p : Pred) :
    (Ty.refineNorm a p).core = a.core := by
  simp only [Ty.refineNorm, Ty.core_packRefinements, Ty.core_idem]

theorem Ty.predicates_refineNorm (a : Ty) (p : Pred) :
    (Ty.refineNorm a p).refinementPredicates = a.refinementPredicates ++ p.conjuncts := by
  apply Ty.predicates_packRefinements (Ty.predicates_core a)
  intro q hq
  rcases List.mem_append.mp hq with hq | hq
  · exact Ty.refinementPredicates_atoms a q hq
  · exact Pred.conjuncts_atoms p q hq

theorem Ty.refineNorm_assoc (a : Ty) (p q : Pred) :
    Ty.refineNorm (Ty.refineNorm a p) q = Ty.refineNorm a (.and p q) := by
  change Ty.packRefinements (Ty.refineNorm a p).core
    ((Ty.refineNorm a p).refinementPredicates ++ q.conjuncts) =
    Ty.packRefinements a.core (a.refinementPredicates ++ (Pred.and p q).conjuncts)
  rw [Ty.core_refineNorm, Ty.predicates_refineNorm]
  simp only [Pred.conjuncts, List.append_assoc]

theorem Ty.refineNorm_refined (a : Ty) (p q : Pred) :
    Ty.refineNorm (.refined a p) q = Ty.refineNorm a (.and p q) := by
  simp only [Ty.refineNorm, Ty.core, Ty.refinementPredicates, Pred.conjuncts, List.append_assoc]

theorem Ty.core_foldFn (t : Tel) : (Ty.foldFn t).core = Ty.foldFn t := by
  unfold Ty.foldFn
  split <;> rfl

theorem Ty.predicates_foldFn (t : Tel) : (Ty.foldFn t).refinementPredicates = [] := by
  unfold Ty.foldFn
  split <;> rfl

theorem Ty.core_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).core = a.core.shiftV k c := by
  cases a with
  | refined a _ => exact Ty.core_shiftV a k c
  | _ => rfl

theorem Ty.predicates_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).refinementPredicates = a.refinementPredicates.map (Pred.shiftV k (c+1)) := by
  cases a <;> simp only [Ty.shiftV, Ty.refinementPredicates, List.map_nil]
  case refined a p =>
    simp only [Ty.predicates_shiftV, List.map_append, Pred.conjuncts_bind]
    rfl

theorem Ty.packRefinements_shiftV (a : Ty) (ps : List Pred) (k c : Nat) :
    (Ty.packRefinements a ps).shiftV k c =
      Ty.packRefinements (a.shiftV k c) (ps.map (Pred.shiftV k (c+1))) := by
  cases ps with
  | nil => rfl
  | cons p ps =>
    simp only [Ty.packRefinements, List.map_cons, Ty.shiftV, Pred.shiftV, shiftIndex,
      Pred.ofConjuncts_bind]
    rfl

theorem Ty.refineNorm_shiftV (a : Ty) (p : Pred) (k c : Nat) :
    (Ty.refineNorm a p).shiftV k c =
      Ty.refineNorm (a.shiftV k c) (p.shiftV k (c+1)) := by
  simp only [Ty.refineNorm, Ty.core_shiftV, Ty.predicates_shiftV,
    Ty.packRefinements_shiftV, List.map_append, Pred.shiftV, Pred.conjuncts_bind, shiftIndex]
  rfl

end Benitoite.Release.Refinement
