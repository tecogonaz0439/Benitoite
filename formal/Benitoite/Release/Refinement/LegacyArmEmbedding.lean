import Benitoite.Release.Refinement.LegacyHandlerEmbedding

namespace Benitoite.Release.Refinement
noncomputable section
namespace LegacyArmCases

theorem nil_case {K P0 B0 B κ Ψ Q C Γ R a b e L}
    (reg : LegacyNodeRegular K P0 B0 B (.arms κ Ψ Q C Γ R [] a b e L)) :
    LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R [] a b e L) := by
  intro Φ
  exact .nil (reg.2.2.1.annotation (by simp) reg.1.2.2.1 _)

theorem plain_case {K P0 B0 B κ Ψ Q C Γ R alts m arms a b e δ L}
    (tables : LegacyTables K P0 B0 B)
    (pat : Benitoite.Release.AltsTy P0 alts a δ)
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C
      (Benitoite.Release.binds δ ++ Γ) R m b e (Benitoite.Release.LocalCtx.extend δ.length L)))
    (tail : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R (.mk alts none m :: arms) a b e L) := by
  intro Φ
  have count : (embedTys δ).length = δ.length := by simp [embedTys_eq_map]
  apply HasTypeArmsQ.plainEmpty (embedAltsTy tables pat) (by simp [FactsWF,pathFacts]) _
    (by simpa only [pathFacts,List.nil_append] using tail Φ)
  simpa only [pathFacts,List.nil_append,legacy_bindParams,legacy_shiftVR,legacy_shiftV,
    legacy_shiftVEff,count] using
    legacy_local_zero (body (liftMany δ.length Φ))

theorem guarded_case {K P0 B0 B κ Ψ Q C Γ R alts g m arms a b e δ L}
    (tables : LegacyTables K P0 B0 B)
    (pat : Benitoite.Release.AltsTy P0 alts a δ)
    (guard : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C
      (Benitoite.Release.hideConts (Benitoite.Release.binds δ ++ Γ)) none g (.base .boolean)
      Benitoite.Release.Eff.empty (Benitoite.Release.LocalCtx.extend δ.length L)))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C
      (Benitoite.Release.binds δ ++ Γ) R m b e (Benitoite.Release.LocalCtx.extend δ.length L)))
    (tail : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R (.mk alts (some g) m :: arms) a b e L) := by
  intro Φ
  have count : (embedTys δ).length = δ.length := by simp [embedTys_eq_map]
  have ha : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      (hideConts (bindParams (Γ.map (Option.map embedTy)) (embedTys δ)))
      (.refined (.base .boolean) .truth) :=
    by
      refine ⟨⟨trivial,trivial,?_⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
      simp [Ty.NotContCore,Ty.core]
  apply HasTypeArmsQ.guardedEmpty (p := .truth) (embedAltsTy tables pat)
    (by simp [FactsWF,pathFacts]) ha _ _ (tail Φ)
  · apply HasTypeCQ.C_Sub _ (.introduce (p := .truth) trivial .truth) (Eff.Covers.refl _ _ _)
      ha.wf ha.sorted ha.declared
    simpa only [pathFacts,List.nil_append,legacy_bindParams,legacy_hideConts,
      count,legacy_empty,Option.map_none,embedTy] using
      legacy_local_zero (guard (liftMany δ.length Φ))
  · simpa only [pathFacts,List.nil_append,legacy_bindParams,legacy_shiftVR,legacy_shiftV,
      legacy_shiftVEff,count] using
      legacy_local_zero (body (Pred.open .truth (.boolean true) :: liftMany δ.length Φ))

end LegacyArmCases
end
end Benitoite.Release.Refinement
