import Benitoite.Release.Refinement.LegacyCallInputs

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_hideConts (Γ : List (Option Benitoite.Release.Ty)) :
    hideConts (Γ.map (Option.map embedTy)) = (Benitoite.Release.hideConts Γ).map (Option.map embedTy) := by
  simp only [hideConts,Benitoite.Release.hideConts,List.map_map,Function.comp_def]
  apply List.map_congr_left
  intro a _
  cases a with
  | none => rfl
  | some a => cases a <;> rfl

theorem legacy_bindParams (Γ : List (Option Benitoite.Release.Ty)) (ps : List Benitoite.Release.Ty) :
    bindParams (Γ.map (Option.map embedTy)) (embedTys ps) =
      (Benitoite.Release.binds ps ++ Γ).map (Option.map embedTy) := by
  simp only [bindParams,Benitoite.Release.binds,embedTys_eq_map,←List.map_reverse,List.length_map,
    List.map_map,Function.comp_def,legacy_shiftV,List.map_append]
  congr 1
  apply List.map_congr_left
  intro a _
  cases a <;> simp only [Option.map_none,Option.map_some,legacy_shiftV]

theorem legacy_hideBuilders (Ψ : Benitoite.Release.StoreTy) :
    hideBuilders (embedStoreTy Ψ) = embedStoreTy Ψ.hideBuilders := by
  funext l
  simp only [hideBuilders,embedStoreTy,Benitoite.Release.StoreTy.hideBuilders]
  cases h : Ψ l with
  | none => rfl
  | some lt => cases lt <;> rfl

namespace LegacyValueCases

theorem lam_case {K P0 B0 B κ Ψ Q C Γ ns ps body r e}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.lam ns ps body) (.fn ns ps r e)))
    (names : Benitoite.Release.NamesWF ns ps)
    (ih : LegacyJudgment.Embedded K P0 B (.comp κ Ψ.hideBuilders Q C
      (Benitoite.Release.binds ps ++ Benitoite.Release.hideConts Γ) (some r) body r e [])) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.lam ns ps body) (.fn ns ps r e)) := by
  intro Φ
  have ha := legacy_value_annotation reg
  apply HasTypeVQ.V_Lam
    (by simpa only [NamesWF,Benitoite.Release.NamesWF,embedTys_eq_map,List.length_map] using names)
    ha.wf ha.sorted _ ha.declared
  simpa only [legacy_hideBuilders,legacy_bindParams,legacy_hideConts,
    legacy_shiftV,legacy_shiftVEff,List.map_nil,Option.map_some] using ih (liftMany (embedTys ps).length Φ)

end LegacyValueCases

end
end Benitoite.Release.Refinement
