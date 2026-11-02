import Benitoite.Release.Refinement.LegacyValueEmbedding

namespace Benitoite.Release.Refinement
noncomputable section

theorem LegacyRule.embed_values {K P0 B0 B κ Ψ Q C Γ vs ts children}
    (rule : LegacyRule K P0 B0 (.values κ Ψ Q C Γ vs ts) children)
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.values κ Ψ Q C Γ vs ts) := by
  cases rule with
  | Vs_nil => intro Φ; exact .nil
  | @Vs_cons _ _ _ _ _ v vs a as =>
    intro Φ
    exact .cons (ih (.value κ Ψ Q C Γ v a) (by simp) Φ)
      (ih (.values κ Ψ Q C Γ vs as) (by simp) Φ)

theorem LegacyRule.embed_each {K P0 B0 B κ Ψ Q C Γ vs a children}
    (rule : LegacyRule K P0 B0 (.each κ Ψ Q C Γ vs a) children)
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.each κ Ψ Q C Γ vs a) := by
  cases rule with
  | Each_nil => intro Φ; exact .nil
  | @Each_cons _ _ _ _ _ v vs =>
    intro Φ
    exact .cons (ih (.value κ Ψ Q C Γ v a) (by simp) Φ)
      (ih (.each κ Ψ Q C Γ vs a) (by simp) Φ)

end
end Benitoite.Release.Refinement
