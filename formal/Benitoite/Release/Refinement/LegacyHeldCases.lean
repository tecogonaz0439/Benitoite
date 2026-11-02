import Benitoite.Release.Refinement.LegacyCallInputs

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_singleFail (a : Benitoite.Release.Ty) :
    embedEff (Benitoite.Release.Eff.singleFail a) = Eff.singleFail (embedTy a) := by
  simp only [Benitoite.Release.Eff.singleFail,embedEff,embedTys,embedTy_norm,Eff.singleFail]
  congr 1
  funext x
  unfold embedAtoms
  cases x.toOld? <;> rfl

namespace LegacyValueCases

theorem locRef_case {K P0 B0 B κ Ψ Q C Γ l a}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.loc l) (.reference a)))
    (lookup : Ψ l = some (.ref a)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.loc l) (.reference a)) := by
  intro Φ
  exact .V_LocRef (by simp only [embedStoreTy,lookup,Option.map_some,embedLocTy])
    (legacy_value_annotation reg).declared

theorem locLazy_case {K P0 B0 B κ Ψ Q C Γ l a}
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ (.loc l) (.lazy a)))
    (lookup : Ψ l = some (.lazy a)) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.loc l) (.lazy a)) := by
  intro Φ
  exact .V_LocLazy (by simp only [embedStoreTy,lookup,Option.map_some,embedLocTy])
    (legacy_value_annotation reg).declared

theorem checked_case {K P0 B0 B κ Ψ Q C Γ target o range}
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.checked target) (.opaque o (.fixed range)))) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.checked target) (.opaque o (.fixed range))) := by
  intro Φ
  obtain ⟨o',range',eq,_,kind,content,member⟩ := reg.2.2.1
  cases eq
  exact embed_checked_opaque kind content member

theorem checkedRequest_case {K P0 B0 B κ Ψ Q C Γ target req o range T}
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.checkedRequest target req) (.opaque o (.fixed range))))
    (content : B0.valContent o = some T)
    (ih : LegacyJudgment.Embedded K P0 B (.value [] Ψ Benitoite.Release.Qempty [] [] req T)) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.checkedRequest target req) (.opaque o (.fixed range))) := by
  intro Φ
  obtain ⟨o',range',T',eq,_,kind,oldContent,newContent,member⟩ := reg.2.2.1
  cases eq
  have ht : T' = T := Option.some.inj (oldContent.symm.trans content)
  subst T'
  exact embed_checkedRequest_opaque kind newContent (.V_Normal (ih [])) reg.2.1.2.1 reg.2.1.2.2.1 member

theorem raise_case {K P0 B0 B κ Ψ Q C Γ T E}
    (reg : LegacyNodeRegular K P0 B0 B
      (.value κ Ψ Q C Γ (.raise T E) (.fn ["error"] [E] T (Benitoite.Release.Eff.singleFail E)))) :
    LegacyJudgment.Embedded K P0 B
      (.value κ Ψ Q C Γ (.raise T E) (.fn ["error"] [E] T (Benitoite.Release.Eff.singleFail E))) := by
  intro Φ
  have ha := legacy_value_annotation reg
  simp only [embedTy,embedTys,legacy_singleFail,embedVal] at ha ⊢
  apply HasTypeVQ.V_Raise ha reg.2.1.1.2 reg.2.1.2.2
  rw [legacyTypeCtx_kinds reg.1.2.2.1]
  exact reg.2.1.1.1.1

end LegacyValueCases

end
end Benitoite.Release.Refinement
