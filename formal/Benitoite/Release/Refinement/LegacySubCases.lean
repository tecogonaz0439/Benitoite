import Benitoite.Release.Refinement.LegacyCallInputs

namespace Benitoite.Release.Refinement
noncomputable section

namespace LegacyValueCases

theorem super_case {K P0 B0 B κ Ψ Q C Γ v cl a cd s}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.super v s) (.dict s a)))
    (lookup : P0.classes cl = some cd) (member : s ∈ cd.supers)
    (ih : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v (.dict cl a))) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.super v s) (.dict s a)) := by
  intro Φ
  exact .V_Super (ih Φ) (embedProgramWithKinds_class lookup) member (legacy_value_annotation reg).declared

theorem sub_case {K P0 B0 B κ Ψ Q C Γ v a b}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v b))
    (sub : Benitoite.Release.Ty.Le a b)
    (ih : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v b) := by
  intro Φ
  have ha := legacy_value_annotation reg
  exact .V_Sub (ih Φ) (embedLe sub) ha.wf ha.sorted ha.declared

end LegacyValueCases

end
end Benitoite.Release.Refinement
