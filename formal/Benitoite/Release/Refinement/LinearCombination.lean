import Benitoite.Release.Refinement.LogicNormalization

/-! # 先行する線形の事実の非負結合 -/
namespace Benitoite.Release.Refinement

inductive LinearStep where
  | combine (terms : List (Nat × Int)) (expected : Linear)
  | round (source : Nat) (divisor : Int) (expected : Linear)

def NNF.linear? : NNF → Option Linear
  | .linear l => some l
  | _ => none

/-- 空和は鍵の数だけ零係数を持つ。参照は現在のfactsだけに対する位置である。 -/
def linearCombination (n : Nat) (facts : List NNF) : List (Nat × Int) → Option Linear
  | [] => some ⟨List.replicate n 0, 0⟩
  | (i,k)::terms => do
    let q ← facts[i]?
    let l ← q.linear?
    let r ← linearCombination n facts terms
    if 0 ≤ k ∧ l.coefficients.length = n ∧ r.coefficients.length = n then
      some ⟨List.zipWith (·+·) (l.coefficients.map (k * ·)) r.coefficients, k*l.bound+r.bound⟩
    else none

theorem linearCombination_sound {n facts terms l}
    (h : linearCombination n facts terms = some l) (ρ : Nat → Int)
    (hf : ∀ q ∈ facts, ∀ a, q = .linear a → a.Holds ρ) : l.Holds ρ := by
  induction terms generalizing l with
  | nil =>
    simp only [linearCombination, Option.some.injEq] at h
    subst l
    simp [Linear.Holds, Linear.eval, linearDot_zero]
  | cons term terms ih =>
    rcases term with ⟨i,k⟩
    simp only [linearCombination, bind, Option.bind_eq_some_iff] at h
    obtain ⟨q,hq,a,ha,r,hr,h⟩ := h
    split at h
    · rename_i hc
      cases h
      have hs : a.Holds ρ := by
        have hm := List.mem_of_getElem? hq
        cases q <;> simp only [NNF.linear?, Option.some.injEq, reduceCtorEq] at ha
        subst a
        exact hf _ hm _ rfl
      have ht := ih hr
      unfold Linear.Holds Linear.eval at hs ht ⊢
      rw [linearDot_add (by simpa only [List.length_map] using hc.2.1.trans hc.2.2.symm), linearDot_scale]
      exact Int.add_le_add (Int.mul_le_mul_of_nonneg_left hs hc.1) ht
    · cases h

def LinearStep.result : LinearStep → Linear
  | .combine _ l | .round _ _ l => l

def LinearStep.check (n : Nat) (facts : List NNF) : LinearStep → Bool
  | .combine terms expected => decide (linearCombination n facts terms = some expected)
  | .round i d expected => match facts[i]? with
    | some (.linear source) => decide (0 < d ∧
        source.coefficients = expected.coefficients.map (d * ·) ∧
        expected.bound = source.bound / d ∧ expected.coefficients.length = n)
    | _ => false

theorem LinearStep.sound {n : Nat} {facts : List NNF} {step : LinearStep} (h : step.check n facts = true) (ρ : Nat → Int)
    (hf : ∀ q ∈ facts, ∀ a, q = .linear a → a.Holds ρ) : step.result.Holds ρ := by
  cases step with
  | combine terms expected =>
    exact linearCombination_sound (of_decide_eq_true h) ρ hf
  | round i d expected =>
    simp only [check] at h
    split at h
    · rename_i source hlookup
      have hc := of_decide_eq_true h
      exact Linear.round_sound d ρ hc.1 hc.2.1 hc.2.2.1
        (hf _ (List.mem_of_getElem? hlookup) _ rfl)
    · cases h

end Benitoite.Release.Refinement
