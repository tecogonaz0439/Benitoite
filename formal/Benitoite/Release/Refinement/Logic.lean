import Benitoite.Release.Refinement.ClosedEvaluation

namespace Benitoite.Release.Refinement

/-- 有限の仮定からの構文による含意。 -/
inductive Entails : List Pred → Pred → Prop where
  | hyp {Ξ p} : p ∈ Ξ → Entails Ξ p
  | truth {Ξ} : Entails Ξ .truth
  | false_elim {Ξ p} : Entails Ξ .falsity → Entails Ξ p
  | and_intro {Ξ p q} : Entails Ξ p → Entails Ξ q → Entails Ξ (.and p q)
  | and_left {Ξ p q} : Entails Ξ (.and p q) → Entails Ξ p
  | and_right {Ξ p q} : Entails Ξ (.and p q) → Entails Ξ q
  | or_left {Ξ p q} : Entails Ξ p → Entails Ξ (.or p q)
  | or_right {Ξ p q} : Entails Ξ q → Entails Ξ (.or p q)
  | or_elim {Ξ p q r} : Entails Ξ (.or p q) → Entails (p::Ξ) r →
      Entails (q::Ξ) r → Entails Ξ r
  | not_intro {Ξ p} : Entails (p::Ξ) .falsity → Entails Ξ (.not p)
  | not_elim {Ξ p} : Entails Ξ p → Entails Ξ (.not p) → Entails Ξ .falsity
  | not_not_elim {Ξ p} : Entails Ξ (.not (.not p)) → Entails Ξ p
  | eq_refl {Ξ t} : Entails Ξ (.eq t t)
  | le_refl {Ξ t} : Entails Ξ (.le t t)
  | integer_eq {Ξ n m} : n = m → Entails Ξ (.eq (.integer n) (.integer m))
  | integer_le {Ξ n m} : n ≤ m → Entails Ξ (.le (.integer n) (.integer m))
  | integer_lt {Ξ n m} : n < m → Entails Ξ (.lt (.integer n) (.integer m))
  | closed {Ξ p} : p.WF 0 → p.Sorted [] none → p.evalClosed = some true → Entails Ξ p

/-- 閉じた計算の成功から、仮定を使わず導く。 -/
theorem Entails.ground {p : Pred} (hw : p.WF 0) (hs : p.Sorted [] none)
    (he : p.evalClosed = some true) : Entails [] p := .closed hw hs he


/-- 仮定の包含に沿う弱化。 -/
theorem Entails.weaken {Ξ p} (h : Entails Ξ p) {Δ} (hm : ∀ q ∈ Ξ, q ∈ Δ) :
    Entails Δ p := by
  induction h generalizing Δ with
  | hyp h => exact .hyp (hm _ h)
  | truth => exact .truth
  | false_elim _ ih => exact .false_elim (ih hm)
  | and_intro _ _ ih₁ ih₂ => exact .and_intro (ih₁ hm) (ih₂ hm)
  | and_left _ ih => exact .and_left (ih hm)
  | and_right _ ih => exact .and_right (ih hm)
  | or_left _ ih => exact .or_left (ih hm)
  | or_right _ ih => exact .or_right (ih hm)
  | or_elim _ _ _ ih₀ ih₁ ih₂ =>
    exact .or_elim (ih₀ hm)
      (ih₁ (fun _ h => by rcases List.mem_cons.mp h with rfl | h; exact List.mem_cons_self; exact List.mem_cons_of_mem _ (hm _ h)))
      (ih₂ (fun _ h => by rcases List.mem_cons.mp h with rfl | h; exact List.mem_cons_self; exact List.mem_cons_of_mem _ (hm _ h)))
  | not_intro _ ih =>
    exact .not_intro (ih (fun _ h => by
      rcases List.mem_cons.mp h with rfl | h
      exact List.mem_cons_self
      exact List.mem_cons_of_mem _ (hm _ h)))
  | not_elim _ _ ih₁ ih₂ => exact .not_elim (ih₁ hm) (ih₂ hm)
  | not_not_elim _ ih => exact .not_not_elim (ih hm)
  | eq_refl => exact .eq_refl
  | le_refl => exact .le_refl
  | integer_eq h => exact .integer_eq h
  | integer_le h => exact .integer_le h
  | integer_lt h => exact .integer_lt h
  | closed hw hs he => exact .closed hw hs he

private theorem consTransport {Ξ Δ : List Pred} (hm : ∀ q ∈ Ξ, Entails Δ q) (p : Pred) :
    ∀ q ∈ p::Ξ, Entails (p::Δ) q := by
  intro q h
  rcases List.mem_cons.mp h with rfl | h
  · exact .hyp List.mem_cons_self
  · exact (hm q h).weaken (fun _ => List.mem_cons_of_mem p)

/-- 各仮定の導出を代入する cut。仮定を増やす論理規則も含む。 -/
theorem Entails.cut {Ξ p} (h : Entails Ξ p) {Δ} (hm : ∀ q ∈ Ξ, Entails Δ q) :
    Entails Δ p := by
  induction h generalizing Δ with
  | hyp h => exact hm _ h
  | truth => exact .truth
  | false_elim _ ih => exact .false_elim (ih hm)
  | and_intro _ _ ih₁ ih₂ => exact .and_intro (ih₁ hm) (ih₂ hm)
  | and_left _ ih => exact .and_left (ih hm)
  | and_right _ ih => exact .and_right (ih hm)
  | or_left _ ih => exact .or_left (ih hm)
  | or_right _ ih => exact .or_right (ih hm)
  | or_elim _ _ _ ih₀ ih₁ ih₂ =>
    exact .or_elim (ih₀ hm) (ih₁ (consTransport hm _)) (ih₂ (consTransport hm _))
  | not_intro _ ih => exact .not_intro (ih (consTransport hm _))
  | not_elim _ _ ih₁ ih₂ => exact .not_elim (ih₁ hm) (ih₂ hm)
  | not_not_elim _ ih => exact .not_not_elim (ih hm)
  | eq_refl => exact .eq_refl
  | le_refl => exact .le_refl
  | integer_eq h => exact .integer_eq h
  | integer_le h => exact .integer_le h
  | integer_lt h => exact .integer_lt h
  | closed hw hs he => exact .closed hw hs he

end Benitoite.Release.Refinement
