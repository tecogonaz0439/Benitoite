import Benitoite.Release.Refinement.Logic

namespace Benitoite.Release.Refinement

theorem Entails.conjuncts {Ξ p} (h : Entails Ξ p) : ∀ q ∈ p.conjuncts, Entails Ξ q := by
  cases p with
  | truth => intro q hq; cases hq
  | and p q =>
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact Entails.conjuncts (.and_left h) r hr
    · exact Entails.conjuncts (.and_right h) r hr
  | _ => intro q hq; cases List.mem_singleton.mp hq; exact h

theorem Entails.of_conjuncts {Ξ p} (h : ∀ q ∈ p.conjuncts, Entails Ξ q) : Entails Ξ p := by
  cases p with
  | truth => exact .truth
  | and p q =>
    exact .and_intro
      (Entails.of_conjuncts (fun r hr => h r (List.mem_append_left _ hr)))
      (Entails.of_conjuncts (fun r hr => h r (List.mem_append_right _ hr)))
  | _ => exact h _ List.mem_cons_self

theorem Ty.entails_assume_iff_predicates (Ξ : List Pred) (a : Ty) (ho : a.Ordinary) :
    (∀ p ∈ a.assume, Entails Ξ p) ↔ (∀ p ∈ a.refinementPredicates, Entails Ξ p) := by
  rw [Ty.assume_eq_predicates ho]

theorem Ty.assume_of_norm_eq {a b : Ty} (he : a.norm = b.norm) (Ξ : List Pred)
    (ha : ∀ p ∈ a.assume, Entails Ξ p) : ∀ p ∈ b.assume, Entails Ξ p := by
  have hassume : a.assume = b.assume := by
    rw [← Ty.assume_norm a, he, Ty.assume_norm]
  rwa [hassume] at ha

end Benitoite.Release.Refinement
