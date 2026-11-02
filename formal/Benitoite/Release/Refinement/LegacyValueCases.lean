import Benitoite.Release.Refinement.LegacyTyping
import Benitoite.Release.Refinement.LegacyPatternCoverage
import Benitoite.Release.Refinement.TypeArgumentRegularity

namespace Benitoite.Release.Refinement
noncomputable section

namespace LegacyValueCases

theorem var_case {K P0 B κ Ψ Q C Γ i a}
    (lookup : Γ[i]? = some (some a)) (ordinary : ∀ b t e, a ≠ .cont b t e) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.var i) a) := by
  intro Φ
  exact .V_Var (by simp only [List.getElem?_map,lookup,Option.map_some]) (legacy_ordinary a ordinary)

theorem const_case {K P0 B κ Ψ Q C Γ} (c : Benitoite.Release.Const)
    (input : ConstOK B (embedConst c)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.const c) c.type) := by
  intro Φ
  exact embed_const c input

theorem bytes_case {K P0 B κ Ψ Q C Γ} (bs : List Nat)
    (input : ∀ b ∈ bs, b ≤ 255) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.bytesV bs) .bytes) := by
  intro Φ
  exact embed_bytes bs input

end LegacyValueCases

end
end Benitoite.Release.Refinement
