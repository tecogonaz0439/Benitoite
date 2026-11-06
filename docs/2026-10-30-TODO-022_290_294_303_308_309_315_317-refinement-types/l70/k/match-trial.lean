import Benitoite.Release.Refinement.LegacyEmbedding

namespace Benitoite.Release.Refinement
noncomputable section

/-- 旧照合の値の正則性は、全ての照合の型について宣言を供給する。 -/
theorem legacy_match_declared_trial {K P0 B0 B κ Ψ Q C Γ v a}
    (input : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a)) :
    Ty.Declared (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      (Γ.map (Option.map embedTy)) (embedTy a) := by
  have h := input.2.2.2 a (by simp)
  exact (h.annotation_at rfl input.1.2.2.1 (Γ.map (Option.map embedTy))).declared

#print axioms legacy_match_declared_trial

end
end Benitoite.Release.Refinement
